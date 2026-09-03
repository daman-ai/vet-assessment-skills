<#
    Probe-GenerationEndpoints.ps1 - Stage 0, minute one. ONE minimum-cost image
    request to the generation endpoint the build will use, so a quota refusal
    surfaces before authoring starts instead of three hours in.

    Implements the probe references\gates.md section 30.2 calls
    Probe-GenerationEndpoints. NON-BLOCKING by design: a refusal re-sequences
    the operator's attention; it is not a reason to refuse to author content.
    The orchestrator reads the exit code and carries on.

    WHY IT EXISTS. One build met an OpenAI 429 insufficient_quota only when
    artwork generation started, about three hours in, and then waited 55
    minutes for credit ON THE CRITICAL PATH, with placement, the post-placement
    re-gate and the confirming audit read all idle behind it. The refusal was
    knowable at minute one for the price of one low-quality image. Run here,
    the same wait happens INSIDE the authoring window, where nothing is
    blocked by it.

    WHAT IT DOES.
      - resolves the key exactly as docx-images\scripts\New-DocImages.ps1
        does (-ApiKey, then $env:OPENAI_API_KEY, then the file named by
        $env:OPENAI_API_KEY_FILE, then %USERPROFILE%\.openai-key) and NEVER
        prints it, or any prefix of it - only which of the four places it came
        from; server error text is scrubbed of anything key-shaped before it
        is echoed
      - reads endpoint, model, output format and the size list from
        docx-images\config\defaults.json, never from a literal here
      - sends ONE request, n=1, no retries, at -Quality (default low) and the
        smallest size the config lists
      - reports the HTTP status, whether the body says insufficient_quota /
        credit_balance_exhausted (a credit block) as opposed to a rate limit,
        every x-ratelimit-* header (to size a parallel fan-out later), and
        the elapsed seconds.

    SAFE. Spends at most one low-quality image. With no key it says so and
    exits 3 WITHOUT making any network call.

    PS 5.1. ASCII only in this file.
    Exit 0 the endpoint answered 200; 2 a quota or credit block - add credit
    NOW while authoring runs; 1 anything else (rate limit, auth, transport,
    bad config); 3 no key found, no call made; 4 the self-test failed.
#>

[CmdletBinding()]
param(
    [ValidateSet('low', 'medium', 'high', 'auto')]
    [string] $Quality = 'low',
    [string] $ApiKey,
    #  docx-images\config\defaults.json, resolved beside this skill when not given.
    [string] $ConfigPath,
    [int] $TimeoutSeconds = 120,
    #  Keep the probe image here if you want it. Discarded otherwise.
    [string] $SaveImageTo,
    #  The last place the key is looked for. Defaults to exactly where
    #  New-DocImages looks; the self-test points it at a file that does not exist.
    [string] $KeyFallbackPath,
    [switch] $SelfTest,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

$GATE = 'Probe-GenerationEndpoints'
$script:Log = New-Object System.Collections.Generic.List[string]
$script:Quiet = [bool]$Quiet
$script:ProbePrompt = 'A plain empty stainless steel bench top, evenly lit, nothing on it, no text.'

function Out-Probe {
    <# Every line this script prints goes through here, so the self-test can prove no key ever reached the log. #>
    param([string] $Text, [string] $Color = 'Gray', [switch] $Always)
    $script:Log.Add($Text)
    if ($Always -or -not $script:Quiet) { Write-Host $Text -ForegroundColor $Color }
}

function Protect-Secret {
    <# Scrub the key, and anything key-shaped, out of text that came back from the server. #>
    param([string] $Text, [string] $Key)
    $t = "$Text"
    if ($Key -and $Key.Length -ge 4) { $t = $t.Replace($Key, '[redacted]') }
    $t = [regex]::Replace($t, '(?i)\bsk-[A-Za-z0-9_\-*.]{3,}', '[redacted]')
    return $t
}

# ---------------------------------------------------------------------------
# 1. The key - same four places, same order, as New-DocImages.ps1
# ---------------------------------------------------------------------------

function Resolve-ProbeApiKey {
    <#  Mirrors Resolve-ApiKey in docx-images\scripts\New-DocImages.ps1, in the
        same order. Returns the key and WHERE it came from; only the source
        label is ever printed.  #>
    param([string] $Explicit, [string] $FallbackPath)
    if ($Explicit) { return [pscustomobject]@{ Key = $Explicit; Source = '-ApiKey' } }
    if ($env:OPENAI_API_KEY) { return [pscustomobject]@{ Key = $env:OPENAI_API_KEY; Source = '$env:OPENAI_API_KEY' } }
    if ($env:OPENAI_API_KEY_FILE -and (Test-Path -LiteralPath $env:OPENAI_API_KEY_FILE)) {
        $k = (Get-Content -LiteralPath $env:OPENAI_API_KEY_FILE -Raw).Trim()
        if ($k) { return [pscustomobject]@{ Key = $k; Source = ('$env:OPENAI_API_KEY_FILE (' + $env:OPENAI_API_KEY_FILE + ')') } }
    }
    if (-not $FallbackPath) { $FallbackPath = Join-Path $env:USERPROFILE '.openai-key' }
    if (Test-Path -LiteralPath $FallbackPath) {
        $k = (Get-Content -LiteralPath $FallbackPath -Raw).Trim()
        if ($k) { return [pscustomobject]@{ Key = $k; Source = $FallbackPath } }
    }
    return [pscustomobject]@{ Key = ''; Source = ('none of -ApiKey, $env:OPENAI_API_KEY, $env:OPENAI_API_KEY_FILE, ' + $FallbackPath) }
}

# ---------------------------------------------------------------------------
# 2. The request - endpoint, model, format and the smallest size, from config
# ---------------------------------------------------------------------------

function Resolve-ProbeConfigPath {
    param([string] $ConfigPath)
    if ($ConfigPath) { return $ConfigPath }
    #  scripts\ -> this skill -> the skills root -> docx-images\config\defaults.json
    $skillsRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    return (Join-Path $skillsRoot 'docx-images\config\defaults.json')
}

function Get-SmallestSize {
    <# The WxH with the fewest pixels among generation.sizes. #>
    param($Sizes)
    $best = ''; $px = [long]::MaxValue
    if ($null -eq $Sizes) { return '' }
    foreach ($p in $Sizes.PSObject.Properties) {
        if ($p.Name -like '_*') { continue }
        if ("$($p.Value)" -match '^(\d+)x(\d+)$') {
            $n = [long]$Matches[1] * [long]$Matches[2]
            if ($n -lt $px) { $px = $n; $best = "$($p.Value)" }
        }
    }
    return $best
}

function Get-ProbeRequest {
    param($Cfg, [string] $Quality)
    $gen = Get-GateProp -Object $Cfg -Names @('generation') -Required -What 'generation block in defaults.json'
    $endpoint = "" + (Get-GateProp -Object $gen -Names @('endpoint') -Required -What 'generation.endpoint')
    $model    = "" + (Get-GateProp -Object $gen -Names @('model') -Required -What 'generation.model')
    $size = Get-SmallestSize -Sizes (Get-GateProp -Object $gen -Names @('sizes'))
    if (-not $size) { throw "$GATE`: generation.sizes in defaults.json lists no WxH size, so the smallest cannot be chosen." }
    $fmt = ("" + (Get-GateProp -Object $gen -Names @('outputFormat') -Default 'jpeg')).ToLowerInvariant()

    #  Same body shape as New-DocImages.Invoke-ImageGeneration, so what the
    #  probe proves is what the build will send.
    $body = [ordered]@{
        model         = $model
        prompt        = $script:ProbePrompt
        size          = $size
        quality       = $Quality
        n             = 1
        output_format = $fmt
    }
    $bg = Get-GateProp -Object $gen -Names @('background')
    if ($bg) { $body.background = "$bg" }
    if ($fmt -in @('jpeg', 'jpg', 'webp')) {
        $oc = Get-GateProp -Object $gen -Names @('outputCompression')
        if ($null -ne $oc) { $body.output_compression = [int]$oc }
    }
    return [pscustomobject]@{
        Endpoint = $endpoint; Model = $model; Size = $size; Quality = $Quality; Format = $fmt
        Json = ($body | ConvertTo-Json -Depth 5 -Compress)
    }
}

# ---------------------------------------------------------------------------
# 3. Transport - swapped for a stub by the self-test
# ---------------------------------------------------------------------------

function Invoke-ProbeTransport {
    param([string] $Uri, [string] $Key, [byte[]] $BodyBytes, [int] $TimeoutSec)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $headers = @{ Authorization = ('Bearer ' + $Key) }
    try {
        $r = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $Uri -Headers $headers -ContentType 'application/json' -Body $BodyBytes -TimeoutSec $TimeoutSec
        $h = @{}
        foreach ($k in @($r.Headers.Keys)) { $h[$k] = "" + $r.Headers[$k] }
        return [pscustomobject]@{ Status = [int]$r.StatusCode; Headers = $h; Body = ("" + $r.Content); Error = '' }
    }
    catch [System.Net.WebException] {
        $resp = $_.Exception.Response
        if ($null -eq $resp) { return [pscustomobject]@{ Status = 0; Headers = @{}; Body = ''; Error = $_.Exception.Message } }
        $h = @{}
        try { foreach ($k in @($resp.Headers.AllKeys)) { $h[$k] = "" + $resp.Headers[$k] } } catch { }
        $body = ''
        try {
            $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
            $body = $sr.ReadToEnd()
            $sr.Close()
        } catch { }
        return [pscustomobject]@{ Status = [int]$resp.StatusCode; Headers = $h; Body = $body; Error = $_.Exception.Message }
    }
    catch {
        return [pscustomobject]@{ Status = 0; Headers = @{}; Body = ''; Error = $_.Exception.Message }
    }
}

$script:Transport = { param($Req) Invoke-ProbeTransport -Uri $Req.Uri -Key $Req.Key -BodyBytes $Req.BodyBytes -TimeoutSec $Req.TimeoutSec }

# ---------------------------------------------------------------------------
# 4. The verdict
# ---------------------------------------------------------------------------

function Get-ProbeVerdict {
    param($R, [double] $Elapsed, [string] $Key)
    $rate = [ordered]@{}
    foreach ($k in @($R.Headers.Keys | Sort-Object)) {
        if ($k -match '(?i)^(x-ratelimit-|retry-after)') { $rate[$k] = "" + $R.Headers[$k] }
    }
    $code = ''; $type = ''; $msg = ''; $hasData = $false
    if ($R.Body) {
        try {
            $j = $R.Body | ConvertFrom-Json
            #  Direct property access, not Get-GateProp: that helper tests
            #  "$value" -ne '' and an ARRAY of objects stringifies to '' in PS
            #  5.1, so data:[{b64_json:...}] read as absent and a real HTTP 200
            #  was reported as an empty response.
            $ep = $j.PSObject.Properties['error']
            if ($null -ne $ep -and $null -ne $ep.Value) {
                $e = $ep.Value
                $code = "" + (Get-GateProp -Object $e -Names @('code') -Default '')
                $type = "" + (Get-GateProp -Object $e -Names @('type') -Default '')
                $msg  = "" + (Get-GateProp -Object $e -Names @('message') -Default '')
            }
            $dp = $j.PSObject.Properties['data']
            if ($null -ne $dp -and $null -ne $dp.Value -and @($dp.Value).Count -gt 0) { $hasData = $true }
        }
        catch { $msg = $R.Body }
    }
    if (-not $msg -and $R.Error) { $msg = $R.Error }

    $blob = ("$code $type $msg").ToLowerInvariant()
    $quotaRx = 'insufficient_quota|credit_balance_exhausted|billing_hard_limit|billing_not_active|exceeded your current quota|insufficient credit|no credit|insufficient balance'
    $kind = ''; $exit = 1
    if ($R.Status -eq 200 -and $hasData) { $kind = 'ok'; $exit = 0 }
    elseif ($R.Status -eq 200)           { $kind = 'empty-200'; $exit = 1 }
    elseif ($blob -match $quotaRx)       { $kind = 'quota-block'; $exit = 2 }
    elseif ($R.Status -eq 429)           { $kind = 'rate-limit'; $exit = 1 }
    elseif ($R.Status -in @(401, 403))   { $kind = 'auth'; $exit = 1 }
    elseif ($R.Status -eq 0)             { $kind = 'transport'; $exit = 1 }
    else                                 { $kind = ('http-' + $R.Status); $exit = 1 }

    return [pscustomobject]@{
        ExitCode = $exit; Kind = $kind; Status = $R.Status; Elapsed = [math]::Round($Elapsed, 1)
        ErrorCode = (Protect-Secret -Text $code -Key $Key)
        ErrorType = (Protect-Secret -Text $type -Key $Key)
        Message   = (Protect-Secret -Text $msg -Key $Key)
        Rate = $rate
    }
}

# ---------------------------------------------------------------------------
# 5. The probe
# ---------------------------------------------------------------------------

function Invoke-Probe {
    param([string] $ApiKey, [string] $ConfigPath, [string] $Quality, [int] $TimeoutSeconds, [string] $SaveImageTo, [string] $KeyFallbackPath)

    Out-Probe ''
    Out-Probe 'GENERATION ENDPOINT PROBE - one low-quality image, at minute one' 'Cyan'

    $cfgPath = Resolve-ProbeConfigPath -ConfigPath $ConfigPath
    if (-not (Test-Path -LiteralPath $cfgPath)) {
        Out-Probe ("  X {0}: config not found: {1}" -f $GATE, $cfgPath) 'Red' -Always
        return [pscustomobject]@{ ExitCode = 1; Kind = 'config'; Status = 0; Elapsed = 0; Rate = @{}; Message = 'config not found' }
    }
    $cfg = Get-GateJson -Path $cfgPath
    $req = Get-ProbeRequest -Cfg $cfg -Quality $Quality
    Out-Probe ("  config:   {0}" -f $cfgPath) 'DarkGray'
    Out-Probe ("  endpoint: {0}" -f $req.Endpoint) 'DarkGray'
    Out-Probe ("  model {0}, size {1} (smallest listed), quality {2}, format {3}, n=1, no retries" -f $req.Model, $req.Size, $req.Quality, $req.Format) 'DarkGray'

    $key = Resolve-ProbeApiKey -Explicit $ApiKey -FallbackPath $KeyFallbackPath
    if (-not $key.Key) {
        Out-Probe ("  X no API key: {0}." -f $key.Source) 'Red' -Always
        Out-Probe '    No network call was made. Set the key now - Stage 7b artwork will need it anyway - and re-run this probe.' 'Yellow' -Always
        return [pscustomobject]@{ ExitCode = 3; Kind = 'no-key'; Status = 0; Elapsed = 0; Rate = @{}; Message = 'no key' }
    }
    Out-Probe ("  key:      from {0} (never printed)" -f $key.Source) 'DarkGray'

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($req.Json)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $resp = & $script:Transport ([pscustomobject]@{ Uri = $req.Endpoint; Key = $key.Key; BodyBytes = $bytes; TimeoutSec = $TimeoutSeconds })
    $sw.Stop()
    $v = Get-ProbeVerdict -R $resp -Elapsed $sw.Elapsed.TotalSeconds -Key $key.Key

    Out-Probe ("  HTTP {0} in {1} s" -f $v.Status, $v.Elapsed) 'DarkGray'
    if ($v.ErrorCode -or $v.ErrorType) { Out-Probe ("  error: code '{0}', type '{1}'" -f $v.ErrorCode, $v.ErrorType) 'DarkGray' }
    if ($v.Message -and $v.Kind -ne 'ok') { Out-Probe ("  message: {0}" -f $v.Message) 'DarkGray' }
    if ($v.Rate.Count -gt 0) {
        Out-Probe '  rate-limit headers (size a fan-out from these):' 'DarkGray'
        foreach ($k in $v.Rate.Keys) { Out-Probe ("    {0}: {1}" -f $k, $v.Rate[$k]) 'DarkGray' }
    }
    else { Out-Probe '  rate-limit headers: none returned' 'DarkGray' }

    switch ($v.Kind) {
        'ok' {
            Out-Probe ("  OK - the endpoint generated one {0} image at quality {1}. Artwork can be generated when Stage 7b gets there." -f $req.Size, $req.Quality) 'Green' -Always
            if ($SaveImageTo) {
                try {
                    $j = $resp.Body | ConvertFrom-Json
                    $b64 = "" + $j.data[0].b64_json
                    if ($b64) {
                        [System.IO.File]::WriteAllBytes($SaveImageTo, [Convert]::FromBase64String($b64))
                        Out-Probe ("  probe image kept at {0}" -f $SaveImageTo) 'DarkGray'
                    }
                } catch { Out-Probe ("  (could not save the probe image: {0})" -f (Protect-Secret -Text $_.Exception.Message -Key $key.Key)) 'DarkGray' }
            }
        }
        'quota-block' {
            Out-Probe '  X QUOTA / CREDIT BLOCK. The account cannot generate images right now.' 'Red' -Always
            Out-Probe '    ADD CREDIT NOW, while authoring runs. Every Stage 7b image will be refused until the balance clears,' 'Yellow' -Always
            Out-Probe '    and the wait belongs inside the authoring window, not on the critical path. Re-run this probe after topping up.' 'Yellow' -Always
        }
        'rate-limit' {
            Out-Probe '  X rate limited (not a credit block). Read the retry-after / x-ratelimit-reset headers above and size the fan-out down.' 'Red' -Always
        }
        'auth' {
            Out-Probe ("  X the endpoint rejected the credential (HTTP {0}). Check which key is in {1}." -f $v.Status, $key.Source) 'Red' -Always
        }
        'transport' {
            Out-Probe ("  X no HTTP response: {0}" -f $v.Message) 'Red' -Always
        }
        default {
            Out-Probe ("  X unexpected result ({0}, HTTP {1})" -f $v.Kind, $v.Status) 'Red' -Always
        }
    }
    return $v
}

# ---------------------------------------------------------------------------
# 6. Self-test - key resolution and config read for real, the network stubbed
# ---------------------------------------------------------------------------

function Invoke-StubTransport {
    <#  The stubbed network. Reads $script:Stub and counts calls in
        $script:StubCalls. A plain function, deliberately: a scriptblock
        closed over with GetNewClosure() runs in its own module scope, where
        "$script:StubCalls++" incremented a variable nobody else could see and
        the call counter read zero for every scenario.  #>
    param($Req)
    $script:StubCalls++
    $script:StubSawKey = (("" + $Req.Key).Length -gt 0)
    $s = $script:Stub
    return [pscustomobject]@{ Status = $s.Status; Headers = $s.Headers; Body = $s.Body; Error = $(if ($s.Status -eq 0) { 'The operation has timed out.' } else { '' }) }
}

function Set-StubTransport {
    param([int] $Status, [string] $Body, [hashtable] $Headers = @{})
    $script:Stub = @{ Status = $Status; Body = $Body; Headers = $Headers }
    $script:Transport = { param($Req) Invoke-StubTransport -Req $Req }
}

function Invoke-ProbeSelfTest {
    param([string] $ConfigPath)
    $script:stPass = 0; $script:stFail = 0
    $ok  = { param($m) $script:stPass++; Write-Host "  PASS  $m" -ForegroundColor Green }
    $bad = { param($m) $script:stFail++; Write-Host "  FAIL  $m" -ForegroundColor Red }

    Write-Host ''
    Write-Host "$GATE self-test (network stubbed; no request leaves this machine)" -ForegroundColor Cyan

    $savedKey = $env:OPENAI_API_KEY
    $savedFile = $env:OPENAI_API_KEY_FILE
    $savedQuiet = $script:Quiet
    $savedTransport = $script:Transport
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('pge_selftest_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $missing = Join-Path $tmp 'no-such-key-file'
    $dummy = 'sk-selftest-' + [guid]::NewGuid().ToString('N')
    try {
        $env:OPENAI_API_KEY = $null
        $env:OPENAI_API_KEY_FILE = $null
        $script:Quiet = $true
        $script:Log.Clear()

        # --- config read, for real
        $cfgPath = Resolve-ProbeConfigPath -ConfigPath $ConfigPath
        if (Test-Path -LiteralPath $cfgPath) { & $ok ("config resolves: {0}" -f $cfgPath) } else { & $bad ("config not found at {0}" -f $cfgPath) }
        $cfg = Get-GateJson -Path $cfgPath
        $req = Get-ProbeRequest -Cfg $cfg -Quality 'low'
        if ($req.Endpoint -match '^https?://') { & $ok ("endpoint read from config: {0}" -f $req.Endpoint) } else { & $bad 'endpoint not read from config' }
        if ($req.Model) { & $ok ("model read from config: {0}" -f $req.Model) } else { & $bad 'model not read from config' }
        $sizes = @($cfg.generation.sizes.PSObject.Properties | Where-Object { $_.Name -notlike '_*' } | ForEach-Object { "$($_.Value)" })
        $smallest = @($sizes | Sort-Object { $p = $_ -split 'x'; [long]$p[0] * [long]$p[1] })[0]
        if ($req.Size -eq $smallest) { & $ok ("smallest listed size chosen: {0} of [{1}]" -f $req.Size, ($sizes -join ', ')) } else { & $bad ("size {0} is not the smallest listed ({1})" -f $req.Size, $smallest) }
        if ($req.Json -match '"quality":"low"' -and $req.Json -match '"n":1') { & $ok 'request body: quality low, n=1' } else { & $bad ("request body wrong: {0}" -f $req.Json) }

        # --- key resolution order, labels only
        $r = Resolve-ProbeApiKey -Explicit 'explicit-dummy' -FallbackPath $missing
        if ($r.Source -eq '-ApiKey') { & $ok 'key order 1: -ApiKey wins' } else { & $bad ("key order 1: got {0}" -f $r.Source) }
        $env:OPENAI_API_KEY = $dummy
        $r = Resolve-ProbeApiKey -Explicit '' -FallbackPath $missing
        if ($r.Source -eq '$env:OPENAI_API_KEY' -and $r.Key -eq $dummy) { & $ok 'key order 2: $env:OPENAI_API_KEY' } else { & $bad ("key order 2: got {0}" -f $r.Source) }
        $env:OPENAI_API_KEY = $null
        $kf = Join-Path $tmp 'keyfile.txt'
        [System.IO.File]::WriteAllText($kf, ($dummy + "`r`n"))
        $env:OPENAI_API_KEY_FILE = $kf
        $r = Resolve-ProbeApiKey -Explicit '' -FallbackPath $missing
        if ($r.Source -like '$env:OPENAI_API_KEY_FILE*' -and $r.Key -eq $dummy) { & $ok 'key order 3: $env:OPENAI_API_KEY_FILE (trimmed)' } else { & $bad ("key order 3: got {0}" -f $r.Source) }
        $env:OPENAI_API_KEY_FILE = $null
        $fb = Join-Path $tmp '.openai-key'
        [System.IO.File]::WriteAllText($fb, $dummy)
        $r = Resolve-ProbeApiKey -Explicit '' -FallbackPath $fb
        if ($r.Source -eq $fb -and $r.Key -eq $dummy) { & $ok 'key order 4: the fallback key file' } else { & $bad ("key order 4: got {0}" -f $r.Source) }
        $r = Resolve-ProbeApiKey -Explicit '' -FallbackPath $missing
        if (-not $r.Key) { & $ok 'no key anywhere resolves to empty, with the four places named' } else { & $bad 'a key was resolved from nowhere' }

        # --- exit path 3: no key, and NO transport call
        $script:StubCalls = 0
        Set-StubTransport -Status 200 -Body '{"data":[{"b64_json":"AAAA"}]}'
        $v = Invoke-Probe -ApiKey '' -ConfigPath $ConfigPath -Quality 'low' -TimeoutSeconds 5 -KeyFallbackPath $missing
        if ($v.ExitCode -eq 3 -and $script:StubCalls -eq 0) { & $ok 'exit 3: no key -> says so, exits 3, zero network calls' } else { & $bad ("exit 3 path: exit {0}, transport calls {1}" -f $v.ExitCode, $script:StubCalls) }

        # --- exit path 0: 200 with image data
        $script:StubCalls = 0
        Set-StubTransport -Status 200 -Body '{"created":1,"data":[{"b64_json":"AAAA"}]}' -Headers @{ 'x-ratelimit-limit-images' = '50'; 'x-ratelimit-remaining-images' = '49' }
        $v = Invoke-Probe -ApiKey $dummy -ConfigPath $ConfigPath -Quality 'low' -TimeoutSeconds 5 -KeyFallbackPath $missing
        if ($v.ExitCode -eq 0 -and $v.Kind -eq 'ok' -and $script:StubCalls -eq 1) { & $ok 'exit 0: HTTP 200 with image data -> ok, exactly one call' } else { & $bad ("exit 0 path: exit {0} kind {1} calls {2}" -f $v.ExitCode, $v.Kind, $script:StubCalls) }
        if ($v.Rate.Count -eq 2 -and $v.Rate['x-ratelimit-remaining-images'] -eq '49') { & $ok 'x-ratelimit-* headers reported' } else { & $bad 'x-ratelimit-* headers not reported' }

        # --- exit path 2: 429 insufficient_quota
        Set-StubTransport -Status 429 -Body '{"error":{"message":"You exceeded your current quota, please check your plan and billing details.","type":"insufficient_quota","code":"insufficient_quota"}}'
        $v = Invoke-Probe -ApiKey $dummy -ConfigPath $ConfigPath -Quality 'low' -TimeoutSeconds 5 -KeyFallbackPath $missing
        if ($v.ExitCode -eq 2 -and $v.Kind -eq 'quota-block') { & $ok 'exit 2: 429 insufficient_quota -> quota block, add credit now' } else { & $bad ("quota path: exit {0} kind {1}" -f $v.ExitCode, $v.Kind) }
        Set-StubTransport -Status 400 -Body '{"error":{"message":"Your credit balance is too low.","type":"invalid_request_error","code":"credit_balance_exhausted"}}'
        $v = Invoke-Probe -ApiKey $dummy -ConfigPath $ConfigPath -Quality 'low' -TimeoutSeconds 5 -KeyFallbackPath $missing
        if ($v.ExitCode -eq 2 -and $v.Kind -eq 'quota-block') { & $ok 'exit 2: credit_balance_exhausted on any status -> quota block' } else { & $bad ("credit path: exit {0} kind {1}" -f $v.ExitCode, $v.Kind) }

        # --- exit path 1: rate limit, auth, transport
        Set-StubTransport -Status 429 -Body '{"error":{"message":"Rate limit reached for images per minute. Please try again in 20s.","type":"requests","code":"rate_limit_exceeded"}}' -Headers @{ 'retry-after' = '20'; 'x-ratelimit-remaining-requests' = '0' }
        $v = Invoke-Probe -ApiKey $dummy -ConfigPath $ConfigPath -Quality 'low' -TimeoutSeconds 5 -KeyFallbackPath $missing
        if ($v.ExitCode -eq 1 -and $v.Kind -eq 'rate-limit' -and $v.Rate['retry-after'] -eq '20') { & $ok 'exit 1: 429 rate_limit_exceeded -> rate limit (not quota), retry-after reported' } else { & $bad ("rate-limit path: exit {0} kind {1}" -f $v.ExitCode, $v.Kind) }
        Set-StubTransport -Status 401 -Body ('{"error":{"message":"Incorrect API key provided: ' + $dummy + '. You can find your API key at the dashboard.","type":"invalid_request_error","code":"invalid_api_key"}}')
        $v = Invoke-Probe -ApiKey $dummy -ConfigPath $ConfigPath -Quality 'low' -TimeoutSeconds 5 -KeyFallbackPath $missing
        if ($v.ExitCode -eq 1 -and $v.Kind -eq 'auth') { & $ok 'exit 1: 401 -> auth failure' } else { & $bad ("auth path: exit {0} kind {1}" -f $v.ExitCode, $v.Kind) }
        Set-StubTransport -Status 0 -Body ''
        $v = Invoke-Probe -ApiKey $dummy -ConfigPath $ConfigPath -Quality 'low' -TimeoutSeconds 5 -KeyFallbackPath $missing
        if ($v.ExitCode -eq 1 -and $v.Kind -eq 'transport') { & $ok 'exit 1: no HTTP response -> transport failure' } else { & $bad ("transport path: exit {0} kind {1}" -f $v.ExitCode, $v.Kind) }

        # --- the key never reaches the log, even when the server echoes it back
        $leaked = @($script:Log | Where-Object { $_.Contains($dummy) -or $_ -match '(?i)sk-selftest' })
        if ($leaked.Count -eq 0) { & $ok ("the key appears in none of {0} logged lines, including the 401 body that echoed it" -f $script:Log.Count) } else { & $bad ("the key leaked into {0} logged line(s)" -f $leaked.Count) }
        $redacted = @($script:Log | Where-Object { $_ -match '\[redacted\]' })
        if ($redacted.Count -gt 0) { & $ok 'the echoed key was scrubbed to [redacted]' } else { & $bad 'the 401 message was not scrubbed' }
    }
    finally {
        if ($null -ne $savedKey) { $env:OPENAI_API_KEY = $savedKey } else { $env:OPENAI_API_KEY = $null }
        if ($null -ne $savedFile) { $env:OPENAI_API_KEY_FILE = $savedFile } else { $env:OPENAI_API_KEY_FILE = $null }
        $script:Quiet = $savedQuiet
        $script:Transport = $savedTransport
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host ''
    Write-Host ("  self-test: {0} passed, {1} failed" -f $script:stPass, $script:stFail) -ForegroundColor $(if ($script:stFail) { 'Red' } else { 'Green' })
    return $script:stFail
}

# ---------------------------------------------------------------------------
# Entry
# ---------------------------------------------------------------------------

if ($SelfTest) {
    $failed = Invoke-ProbeSelfTest -ConfigPath $ConfigPath
    if ($failed -gt 0) { exit 4 }
    exit 0
}

$verdict = Invoke-Probe -ApiKey $ApiKey -ConfigPath $ConfigPath -Quality $Quality -TimeoutSeconds $TimeoutSeconds -SaveImageTo $SaveImageTo -KeyFallbackPath $KeyFallbackPath
exit $verdict.ExitCode
