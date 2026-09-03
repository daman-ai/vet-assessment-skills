<#
.SYNOPSIS
  Generates one image per pending manifest entry with the OpenAI image model.

.DESCRIPTION
  Reads the manifest written by Find-DocxImagePrompts.ps1 or
  New-ManifestFromSpine.ps1, wraps each prompt taken from the document in the
  house rules for its kind, calls the images endpoint, and writes the image
  into -ImageDir in the configured format. The manifest is updated in place
  after every image, so an interrupted run resumes where it stopped.

  COST. Quality is billed per image and is set in config/defaults.json, with a
  per-entry QUALITY: field on the prompt block overriding it. Generate at the
  quality the PAGE needs - never at the maximum and then shrink, which pays for
  detail that is discarded before anyone sees it. Run -WhatIfCost first: it
  prints the per-entry quality and a count by tier.

  The API key is never stored in this skill. It is read, in order, from:
    1. -ApiKey
    2. $env:OPENAI_API_KEY
    3. the file named by $env:OPENAI_API_KEY_FILE
    4. %USERPROFILE%\.openai-key
  It is never printed and never placed on a command line. A worker resolves
  it for itself; an explicit -ApiKey reaches workers only through the process
  environment, which child processes inherit.

  -Parallel N. One image takes about 21 seconds, so 57 images in a single
  serial foreach was ~20 minutes of wall time on the critical path of every
  guide build. Each entry is independent - its own prompt, size, quality and
  output file - so N workers can run at once. The ONE piece of shared state
  was the manifest: the serial loop rewrote the WHOLE 500 KB file after every
  image from its own in-memory snapshot, and N processes doing that is
  last-writer-wins on the entire document, with a torn file whenever two
  writes overlap. So each worker owns a SHARD (manifest.worker<n>.json, a copy
  of the manifest filtered to its ids) and saves only that after every image.
  The parent merges the shards back by id - status, imageFile, attempts and
  note only - writes the master ONCE, and deletes the shards. A heartbeat file
  per worker, touched after every image and before every wait, lets the parent
  tell a dead or hung worker from a slow one within seconds and report it
  instead of hanging.

  -Parallel 1 (the default) is the original serial path, unchanged.

  429s. The old loop treated every 429 alike: a fixed 4/10/25/60 s backoff with
  no jitter. That has two failure modes once there are N workers. A quota 429
  (insufficient_quota / credit_balance_exhausted, no Retry-After) is not a
  rate limit - the account has no credit - and retrying it costs an hour of
  backoff per worker for nothing while the build waits; the last build sat
  55 minutes on exactly that. So a worker that sees one stops at once, and the
  parent stops every other worker and says "add credit", exit code 2. A rate
  limit 429 (Retry-After present) is honoured as given, plus 0-3 s of random
  jitter and a slower pace for that worker, because N workers that all sleep
  the same fixed 4 seconds all come back in the same instant and collide
  again. 400/401/403 are never retried: a 400 is the prompt itself.

  -DryRun replaces the HTTP call with a stub that sleeps 1-2 s and returns a
  1x1 PNG, so the parallel machinery, shard merge, heartbeats and both 429
  paths can be exercised without spending money. -DryRunQuotaAtWorker <n>
  makes worker n's second image raise a quota 429 (in serial mode, n = 1 means
    this process); -DryRunRateLimitFirst
  makes every worker's first attempt raise a rate-limit 429 with Retry-After.

  Execution policy. Workers are started with Start-Job as a scriptblock built
  from this file's text, not as a script file: on a machine whose effective
  policy is Restricted a job cannot load a .ps1 at all, and this one is.

.EXAMPLE
  .\New-DocImages.ps1 -ManifestPath .\images\manifest.json -ImageDir .\images

.EXAMPLE
  .\New-DocImages.ps1 -ManifestPath .\images\manifest.json -ImageDir .\images -Parallel 6
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$ManifestPath,
  [Parameter(Mandatory)][string]$ImageDir,
  [string]$ConfigPath,
  [string]$ApiKey,
  [string[]]$Only,
  [switch]$Force,
  [switch]$WhatIfCost,

  # 1 = the original serial loop. N > 1 = N worker jobs, one shard each.
  [ValidateRange(1, 32)][int]$Parallel = 1,
  # How often the parent re-checks jobs and heartbeats while waiting.
  [ValidateRange(1, 60)][int]$PollSeconds = 3,
  # A worker whose heartbeat is older than this is treated as hung and stopped.
  # 0 = the config request timeout plus two minutes.
  [int]$StaleSeconds = 0,
  # Hard ceiling on the whole parallel run. 0 = none (heartbeats guard hangs).
  [int]$MaxMinutes = 0,

  # Test-only. No API call is made; see the header.
  [switch]$DryRun,
  [int]$DryRunQuotaAtWorker = 0,
  [switch]$DryRunRateLimitFirst,

  # Set by the parent when it starts a worker. Not for callers.
  [int]$WorkerIndex = 0,
  [string]$HeartbeatPath
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$isWorker = ($WorkerIndex -gt 0)

if (-not $ConfigPath) {
  if (-not $PSScriptRoot) { throw 'ConfigPath is required when this script runs as a worker scriptblock; the parent passes it.' }
  $ConfigPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'config\defaults.json'
}
$ConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
$cfg = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

# A real 1x1 PNG (RGBA) for -DryRun, so Get-PngSize can still read what the
# stub wrote.
$script:OnePixelPngB64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='
$script:dryRateLimited = $false
$script:paceSeconds    = 0
$ok = 0; $failed = 0

function Resolve-ApiKey {
  param([string]$Explicit)
  if ($Explicit) { return $Explicit }
  if ($env:OPENAI_API_KEY) { return $env:OPENAI_API_KEY }
  if ($env:OPENAI_API_KEY_FILE -and (Test-Path -LiteralPath $env:OPENAI_API_KEY_FILE)) {
    return (Get-Content -LiteralPath $env:OPENAI_API_KEY_FILE -Raw).Trim()
  }
  $fallback = Join-Path $env:USERPROFILE '.openai-key'
  if (Test-Path -LiteralPath $fallback) { return (Get-Content -LiteralPath $fallback -Raw).Trim() }
  throw "No OpenAI API key found. Set `$env:OPENAI_API_KEY, or put the key in $fallback, or pass -ApiKey."
}

function Build-FullPrompt {
  param(
    [Parameter(Mandatory)][string]$DocumentPrompt,
    [Parameter(Mandatory)][string]$Kind
  )
  $rules = $cfg.houseRules.$Kind
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine($rules.preamble)
  [void]$sb.AppendLine()
  [void]$sb.AppendLine('Subject:')
  [void]$sb.AppendLine($DocumentPrompt)
  [void]$sb.AppendLine()
  [void]$sb.AppendLine('Hard constraints:')
  foreach ($c in $rules.constraints) { [void]$sb.AppendLine("- $c") }
  return $sb.ToString().Trim()
}

function Write-Heartbeat {
  # One small file per worker, rewritten whole. The parent reads its
  # timestamp to tell a hung worker from a slow one, and its state to learn
  # that a worker stopped on quota - a job's exit code never reaches the
  # parent, so this is the channel.
  param([string]$State, [string]$Current = '', $ExitCode = $null)
  if (-not $HeartbeatPath) { return }
  $o = [ordered]@{
    worker   = $WorkerIndex
    pid      = $PID
    utc      = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    state    = $State
    current  = $Current
    done     = $script:ok
    failed   = $script:failed
    exitCode = $ExitCode
  }
  try { $o | ConvertTo-Json -Compress | Set-Content -LiteralPath $HeartbeatPath -Encoding ASCII } catch { }
}

function Get-RetryAfterSeconds {
  # Retry-After is either delta-seconds or an HTTP date. Clamped to 1..300 so
  # a malformed header cannot park a worker for an hour.
  param($Raw)
  if ($null -eq $Raw) { return $null }
  $s = "$Raw".Trim()
  if (-not $s) { return $null }
  $n = 0.0
  if ([double]::TryParse($s, [ref]$n)) { return [int][Math]::Min(300, [Math]::Max(1, [Math]::Ceiling($n))) }
  $d = [datetime]::MinValue
  if ([datetime]::TryParse($s, [ref]$d)) {
    $secs = ($d.ToUniversalTime() - (Get-Date).ToUniversalTime()).TotalSeconds
    return [int][Math]::Min(300, [Math]::Max(1, [Math]::Ceiling($secs)))
  }
  return $null
}

function Get-RequestFailure {
  # Normalises a failed request - a real WebException, or the dry-run stub's
  # exception carrying status/body/retryAfter in .Data - into one object.
  # The status and detail rules are the original ones: the body's
  # error.message if it parses, else the raw body, else the exception text.
  param([Parameter(Mandatory)]$ErrorRecord)
  $ex = $ErrorRecord.Exception
  $status = 0; $detail = $ex.Message; $code = ''; $raw = ''; $retryAfter = $null
  if ($ex.Data -and $ex.Data.Contains('status')) {
    $status = [int]$ex.Data['status']
    $raw    = [string]$ex.Data['body']
    if ($ex.Data.Contains('retryAfter')) { $retryAfter = $ex.Data['retryAfter'] }
  }
  elseif ($ex.Response) {
    try { $status = [int]$ex.Response.StatusCode } catch { $status = 0 }
    try {
      $sr = New-Object System.IO.StreamReader($ex.Response.GetResponseStream())
      $raw = $sr.ReadToEnd(); $sr.Close()
    } catch { }
    try { $retryAfter = $ex.Response.Headers['Retry-After'] } catch { $retryAfter = $null }
  }
  if ($raw) {
    try {
      $j = $raw | ConvertFrom-Json
      if ($j.error) {
        if ($j.error.message) { $detail = $j.error.message }
        $code = ("{0} {1}" -f $j.error.code, $j.error.type).Trim()
      } else { $detail = $raw }
    } catch { $detail = $raw }
  }
  $isQuota = $false
  if ($status -eq 429 -and ("$code $detail $raw" -match 'insufficient_quota|credit_balance_exhausted|billing_hard_limit')) {
    $isQuota = $true
  }
  return [pscustomobject]@{
    Status            = $status
    Detail            = $detail
    Code              = $code
    RetryAfterSeconds = (Get-RetryAfterSeconds $retryAfter)
    IsQuota           = $isQuota
  }
}

function Invoke-DryRunRequest {
  # Stands in for Invoke-RestMethod. Sleeps 1-2 s and returns the shape the
  # API returns, or raises the failure the switches ask for so the SAME retry
  # loop and classification run as they would against the real endpoint.
  param([int]$Sequence)
  if ($DryRunRateLimitFirst -and $Sequence -eq 1 -and -not $script:dryRateLimited) {
    $script:dryRateLimited = $true
    $e = New-Object System.Exception 'simulated rate limit'
    $e.Data['status']     = 429
    $e.Data['body']       = '{"error":{"message":"Rate limit reached for images per min.","type":"requests","code":"rate_limit_exceeded"}}'
    $e.Data['retryAfter'] = '2'
    throw $e
  }
  if ($DryRunQuotaAtWorker -gt 0 -and $Sequence -ge 2 -and (($WorkerIndex -eq $DryRunQuotaAtWorker) -or ($Parallel -le 1 -and $WorkerIndex -eq 0 -and $DryRunQuotaAtWorker -eq 1))) {   # serial mode is worker 1
    $e = New-Object System.Exception 'simulated quota'
    $e.Data['status'] = 429
    $e.Data['body']   = '{"error":{"message":"You exceeded your current quota, please check your plan and billing details.","type":"insufficient_quota","code":"insufficient_quota"}}'
    throw $e
  }
  Start-Sleep -Milliseconds (Get-Random -Minimum 1000 -Maximum 2001)
  return [pscustomobject]@{ data = @([pscustomobject]@{ b64_json = $script:OnePixelPngB64 }) }
}

function Invoke-ImageGeneration {
  param(
    [Parameter(Mandatory)][string]$Prompt,
    [Parameter(Mandatory)][string]$Size,
    [Parameter(Mandatory)][string]$Key,
    [string]$Quality,
    [int]$Sequence = 0
  )
  # Per-entry quality wins over the config default. The scanner already reads a
  # QUALITY: field off the prompt block and validates it; without this the
  # override was written into the manifest and then silently ignored, so every
  # image billed at the file-level setting no matter what the page asked for.
  if (-not $Quality) { $Quality = [string]$cfg.generation.quality }
  $body = @{
    model          = $cfg.generation.model
    prompt         = $Prompt
    size           = $Size
    quality        = $Quality
    n              = 1
    output_format  = $cfg.generation.outputFormat
    background     = $cfg.generation.background
  }
  # output_compression is accepted for jpeg and webp only. Sending it with png
  # is rejected, so it is added conditionally rather than always.
  $fmt = "$($cfg.generation.outputFormat)".ToLower()
  if ($fmt -in @('jpeg', 'jpg', 'webp') -and $null -ne $cfg.generation.outputCompression) {
    $body.output_compression = [int]$cfg.generation.outputCompression
  }
  $json  = $body | ConvertTo-Json -Depth 5 -Compress
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  $headers = @{ Authorization = "Bearer $Key" }

  $maxTry = [int]$cfg.generation.maxRetries
  for ($try = 1; $try -le $maxTry; $try++) {
    try {
      if ($DryRun) {
        $resp = Invoke-DryRunRequest -Sequence $Sequence
      }
      else {
        $resp = Invoke-RestMethod -Method Post -Uri $cfg.generation.endpoint `
                  -Headers $headers -ContentType 'application/json' `
                  -Body $bytes -TimeoutSec ([int]$cfg.generation.timeoutSeconds)
      }
      if (-not $resp.data -or $resp.data.Count -lt 1) { throw 'The API returned no image data.' }
      $b64 = $resp.data[0].b64_json
      if (-not $b64) {
        # Some deployments return a URL instead of base64. Follow it.
        $url = $resp.data[0].url
        if (-not $url) { throw 'The API response carried neither b64_json nor url.' }
        $tmp = [System.IO.Path]::GetTempFileName()
        Invoke-WebRequest -Uri $url -OutFile $tmp -TimeoutSec 120 | Out-Null
        $b64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($tmp))
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
      }
      return $b64
    }
    catch {
      $f      = Get-RequestFailure -ErrorRecord $_
      $status = $f.Status
      $detail = $f.Detail

      # 400 is almost always the prompt itself. Retrying an identical prompt
      # cannot help, so surface it and let the caller rewrite it.
      if ($status -eq 400 -or $status -eq 401 -or $status -eq 403) {
        throw "HTTP $status - $detail"
      }

      # A quota 429 is not a rate limit: the account has no credit. Retrying
      # burns an hour of backoff for nothing. In a worker, stop now and let the
      # parent stop everyone. On the serial path the loop below saves the manifest
      # (resumable), prints the add-credit message and exits 2 on the FIRST quota
      # hit, instead of failing 57 images one at a time through four retries each -
      # which is how one build lost 55 minutes.
      if ($f.IsQuota) {
        $qe = New-Object System.Exception ("HTTP 429 - {0} (account credit exhausted; not retried)" -f $detail)
        $qe.Data['quota'] = $true
        throw $qe
      }

      if ($try -ge $maxTry) { throw "HTTP $status after $maxTry attempts - $detail" }
      $waitList = @($cfg.generation.retryBackoffSeconds)
      $wait = $waitList[[Math]::Min($try - 1, $waitList.Count - 1)]

      if (-not $isWorker) {
        Write-Host ("    retry {0}/{1} in {2}s (HTTP {3}: {4})" -f $try, $maxTry, $wait, $status, $detail) -ForegroundColor DarkYellow
        Start-Sleep -Seconds $wait
      }
      else {
        # Honour Retry-After when the server gives one, and slow this worker
        # down for the next few images. Either way add 0-3 s of jitter so N
        # workers that were refused together do not return together.
        $why = 'backoff'
        if ($status -eq 429 -and $null -ne $f.RetryAfterSeconds) {
          $wait = [int]$f.RetryAfterSeconds
          $why  = 'Retry-After'
          $script:paceSeconds = [int][Math]::Min(60, [Math]::Max(5, $script:paceSeconds * 2))
        }
        $jitterMs = Get-Random -Minimum 0 -Maximum 3001
        $totalMs  = ([int]$wait * 1000) + $jitterMs
        Write-Host ("    retry {0}/{1} in {2:n1}s ({3} + jitter; HTTP {4}: {5})" -f $try, $maxTry, ($totalMs / 1000.0), $why, $status, $detail) -ForegroundColor DarkYellow
        Write-Heartbeat -State 'retry-wait' -Current ("attempt {0} of {1}, {2:n1}s" -f $try, $maxTry, ($totalMs / 1000.0))
        Start-Sleep -Milliseconds $totalMs
      }
    }
  }
}

# ---------------------------------------------------------------- parallel machinery (parent only)

function Set-EntryField {
  param($Entry, [string]$Name, $Value)
  if ($Entry.PSObject.Properties[$Name]) { $Entry.$Name = $Value }
  else { $Entry | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}

function Read-Heartbeat {
  param([string]$Path)
  $r = [pscustomobject]@{ Exists = $false; AgeSeconds = -1; State = ''; Current = ''; Done = 0; Failed = 0; ExitCode = $null }
  if (-not (Test-Path -LiteralPath $Path)) { return $r }
  $fi = Get-Item -LiteralPath $Path
  $r.Exists = $true
  # The timestamp is the liveness signal; a torn read of the body still counts.
  $r.AgeSeconds = [int]((Get-Date).ToUniversalTime() - $fi.LastWriteTimeUtc).TotalSeconds
  try {
    $j = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    $r.State = [string]$j.state; $r.Current = [string]$j.current
    $r.Done = [int]$j.done; $r.Failed = [int]$j.failed; $r.ExitCode = $j.exitCode
  } catch { }
  return $r
}

function Write-WorkerOutput {
  # Relays a worker's Write-Host lines and errors, prefixed, as they arrive.
  param($W)
  $cj = $W.Job.ChildJobs[0]
  while ($W.InfoIdx -lt $cj.Information.Count) {
    $rec = $cj.Information[$W.InfoIdx]
    $fg  = $null
    try { if ($rec.MessageData.PSObject.Properties['ForegroundColor']) { $fg = $rec.MessageData.ForegroundColor } } catch { }
    if ($fg) { Write-Host ("  [w{0}] {1}" -f $W.Index, $rec.MessageData) -ForegroundColor $fg }
    else     { Write-Host ("  [w{0}] {1}" -f $W.Index, $rec.MessageData) }
    $W.InfoIdx++
  }
  while ($W.ErrIdx -lt $cj.Error.Count) {
    Write-Host ("  [w{0}] ERROR {1}" -f $W.Index, $cj.Error[$W.ErrIdx]) -ForegroundColor Red
    $W.ErrIdx++
  }
}

function Merge-Shard {
  # Copies status, imageFile, attempts and note from one shard onto the
  # master, by id, for the ids that shard owned. Nothing else on the master is
  # touched. A shard that will not parse (the worker was killed mid-write) is
  # recovered from disk: an entry counts as generated only when both its image
  # and its .prompt.txt sidecar exist from this run, because the sidecar is
  # written last and so proves the image write completed.
  param([string]$ShardPath, [string[]]$Ids, [hashtable]$ById, [datetime]$Since, [string]$Ext)
  $shard = $null
  try { $shard = Get-Content -LiteralPath $ShardPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $shard = $null }
  if ($null -eq $shard -or -not $shard.PSObject.Properties['placeholders']) {
    Write-Host ("  shard unreadable, recovering its entries from disk: {0}" -f (Split-Path -Leaf $ShardPath)) -ForegroundColor Yellow
    foreach ($id in $Ids) {
      $m = $ById[$id]
      if ($null -eq $m) { continue }
      $file = Join-Path $ImageDirFull ("{0}_{1}.{2}" -f $id, $m.kind, $Ext)
      $side = [System.IO.Path]::ChangeExtension($file, '.prompt.txt')
      if ((Test-Path -LiteralPath $file) -and (Test-Path -LiteralPath $side) -and
          (Get-Item -LiteralPath $file).Length -gt 0 -and
          (Get-Item -LiteralPath $file).LastWriteTime -ge $Since -and
          (Get-Item -LiteralPath $side).LastWriteTime -ge $Since) {
        Set-EntryField $m 'imageFile' $file
        Set-EntryField $m 'status'    'generated'
        Set-EntryField $m 'attempts'  ([int]$m.attempts + 1)
        Set-EntryField $m 'note'      'recovered from disk: the worker shard was unreadable'
      }
    }
    return
  }
  foreach ($s in @($shard.placeholders)) {
    if ($null -eq $s) { continue }
    $id = [string]$s.id
    if ($Ids -notcontains $id) { continue }
    $m = $ById[$id]
    if ($null -eq $m) { continue }
    foreach ($fld in @('status', 'imageFile', 'attempts', 'note')) {
      if ($s.PSObject.Properties[$fld]) { Set-EntryField $m $fld $s.$fld }
    }
  }
}

function Save-MasterManifest {
  # Written to a temp file and moved into place, so a parent killed mid-write
  # cannot leave a torn master.
  param([string]$Path)
  $tmp = $Path + '.tmp'
  $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $tmp -Encoding UTF8
  Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function Invoke-ParallelRun {
  $mFull = [System.IO.Path]::GetFullPath($ManifestPath)
  $mDir  = Split-Path -Parent $mFull
  $mBase = [System.IO.Path]::GetFileNameWithoutExtension($mFull)
  $ext   = switch ("$($cfg.generation.outputFormat)".ToLower()) {
             'jpeg'  { 'jpg' }
             'jpg'   { 'jpg' }
             'webp'  { 'webp' }
             default { 'png' }
           }
  $byId = @{}
  foreach ($p in $manifest.placeholders) { $byId[[string]$p.id] = $p }

  $n = [Math]::Min($Parallel, $targets.Count)
  $batches = @{}
  for ($i = 0; $i -lt $targets.Count; $i++) {
    $w = ($i % $n) + 1
    if (-not $batches.ContainsKey($w)) { $batches[$w] = New-Object System.Collections.Generic.List[string] }
    $batches[$w].Add([string]$targets[$i].id)
  }

  # An explicit key reaches the workers through the environment they inherit,
  # never through a command line and never through a file. The previous value
  # is put back when the run ends so the calling session does not keep it.
  $prevEnvKey = $env:OPENAI_API_KEY
  if ($ApiKey) { $env:OPENAI_API_KEY = $ApiKey }

  $scriptText = Get-Content -LiteralPath $PSCommandPath -Raw
  $stale = if ($StaleSeconds -gt 0) { $StaleSeconds } else { [int]$cfg.generation.timeoutSeconds + 120 }
  $runStart = Get-Date
  $deadline = $null
  if ($MaxMinutes -gt 0) { $deadline = $runStart.AddMinutes($MaxMinutes) }

  Write-Host ("Starting {0} worker(s); heartbeat stale after {1}s; poll every {2}s." -f $n, $stale, $PollSeconds) -ForegroundColor Cyan
  $workers = @()
  for ($w = 1; $w -le $n; $w++) {
    $ids       = @($batches[$w])
    $shardPath = Join-Path $mDir ("{0}.worker{1}.json" -f $mBase, $w)
    $hbPath    = Join-Path $mDir ("{0}.worker{1}.heartbeat.json" -f $mBase, $w)

    $shard = [ordered]@{}
    foreach ($p in $manifest.PSObject.Properties) { if ($p.Name -ne 'placeholders') { $shard[$p.Name] = $p.Value } }
    $shard['placeholders'] = @($manifest.placeholders | Where-Object { $ids -contains [string]$_.id })
    $shard | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $shardPath -Encoding UTF8
    if (Test-Path -LiteralPath $hbPath) { Remove-Item -LiteralPath $hbPath -Force }

    $splat = @{
      ManifestPath  = $shardPath
      ImageDir      = $ImageDirFull
      ConfigPath    = $ConfigPath
      Only          = $ids
      WorkerIndex   = $w
      HeartbeatPath = $hbPath
      Parallel      = 1
    }
    if ($Force)  { $splat['Force']  = $true }
    if ($DryRun) {
      $splat['DryRun'] = $true
      $splat['DryRunQuotaAtWorker'] = $DryRunQuotaAtWorker
      if ($DryRunRateLimitFirst) { $splat['DryRunRateLimitFirst'] = $true }
    }

    $job = Start-Job -Name ("docximg-w{0}" -f $w) -ScriptBlock {
      param($Text, $Splat)
      $sb = [scriptblock]::Create($Text)
      $a = @{}
      foreach ($k in $Splat.Keys) { $a[$k] = $Splat[$k] }
      & $sb @a
    } -ArgumentList $scriptText, $splat

    $workers += [pscustomobject]@{
      Index = $w; Job = $job; Shard = $shardPath; Heartbeat = $hbPath; Ids = $ids
      Dead = $false; Reason = ''; InfoIdx = 0; ErrIdx = 0; Quota = $false
    }
    Write-Host ("  worker {0}: {1} image(s)  {2}" -f $w, $ids.Count, ($ids -join ' '))
  }

  $quotaHit = $false
  try {
    while ($true) {
      $live = @($workers | Where-Object { -not $_.Dead -and $_.Job.State -in @('NotStarted', 'Running') })
      if ($live.Count -eq 0) { break }
      $null = Wait-Job -Job @($live | ForEach-Object { $_.Job }) -Any -Timeout $PollSeconds
      foreach ($w in $workers) { Write-WorkerOutput $w }

      foreach ($w in $live) {
        $st = $w.Job.State
        $hb = Read-Heartbeat $w.Heartbeat
        if ($hb.State -eq 'quota') { $w.Quota = $true; $quotaHit = $true }
        if ($st -eq 'Completed') { continue }
        if ($st -ne 'Running' -and $st -ne 'NotStarted') {
          $err = ''
          try { if ($w.Job.ChildJobs[0].Error.Count -gt 0) { $err = [string]$w.Job.ChildJobs[0].Error[0] } } catch { }
          $w.Dead = $true
          $w.Reason = ("job ended in state {0}{1}" -f $st, $(if ($err) { ": $err" } else { '' }))
          Write-Host ("  worker {0} DIED - {1}" -f $w.Index, $w.Reason) -ForegroundColor Red
          continue
        }
        $age = $hb.AgeSeconds
        if (-not $hb.Exists) { $age = [int]((Get-Date) - $w.Job.PSBeginTime).TotalSeconds }
        if ($age -gt $stale) {
          Stop-Job -Job $w.Job -ErrorAction SilentlyContinue
          $w.Dead = $true
          $w.Reason = ("no heartbeat for {0}s (limit {1}s); stopped. Last state: {2} {3}" -f $age, $stale, $hb.State, $hb.Current)
          Write-Host ("  worker {0} HUNG - {1}" -f $w.Index, $w.Reason) -ForegroundColor Red
        }
      }

      if ($quotaHit) {
        foreach ($w in $workers) {
          if ($w.Job.State -in @('NotStarted', 'Running')) { Stop-Job -Job $w.Job -ErrorAction SilentlyContinue }
        }
        break
      }
      if ($deadline -and (Get-Date) -gt $deadline) {
        foreach ($w in $workers) {
          if ($w.Job.State -in @('NotStarted', 'Running')) {
            Stop-Job -Job $w.Job -ErrorAction SilentlyContinue
            $w.Dead = $true; $w.Reason = "stopped at the -MaxMinutes $MaxMinutes ceiling"
            Write-Host ("  worker {0} STOPPED - {1}" -f $w.Index, $w.Reason) -ForegroundColor Red
          }
        }
        break
      }
    }
  }
  finally {
    # Ctrl+C lands here too: never leave six powershell.exe processes billing
    # the account with nobody to merge their work.
    foreach ($w in $workers) {
      if ($w.Job.State -in @('NotStarted', 'Running')) { Stop-Job -Job $w.Job -ErrorAction SilentlyContinue }
    }
    if ($ApiKey) { $env:OPENAI_API_KEY = $prevEnvKey }
  }
  foreach ($w in $workers) {
    Write-WorkerOutput $w
    $hb = Read-Heartbeat $w.Heartbeat
    if ($hb.State -eq 'quota') { $w.Quota = $true; $quotaHit = $true }
  }

  # ---- merge: shard -> master by id, then ONE write of the master.
  Write-Host 'Merging worker shards into the manifest...' -ForegroundColor Cyan
  foreach ($w in $workers) {
    Merge-Shard -ShardPath $w.Shard -Ids $w.Ids -ById $byId -Since $runStart -Ext $ext
    if ($w.Dead) {
      foreach ($id in $w.Ids) {
        $m = $byId[$id]
        if ($null -ne $m -and [string]$m.status -ne 'generated') {
          Set-EntryField $m 'note' ("not attempted: worker {0} {1}" -f $w.Index, $w.Reason)
        }
      }
    }
  }
  Save-MasterManifest -Path $mFull
  foreach ($w in $workers) {
    Remove-Item -LiteralPath $w.Shard -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $w.Heartbeat -Force -ErrorAction SilentlyContinue
    Remove-Job -Job $w.Job -Force -ErrorAction SilentlyContinue
  }

  $gen  = 0; $bad = 0; $left = 0
  foreach ($t in $targets) {
    $m = $byId[[string]$t.id]
    switch ([string]$m.status) {
      'generated' { $gen++ }
      'failed'    { $bad++ }
      default     { $left++ }
    }
  }
  $secs = [int]((Get-Date) - $runStart).TotalSeconds
  Write-Host ("Done. {0} generated, {1} failed, {2} not attempted, in {3}s across {4} worker(s)." -f $gen, $bad, $left, $secs, $n)
  $dead = @($workers | Where-Object { $_.Dead })
  foreach ($w in $dead) { Write-Host ("  worker {0}: {1}" -f $w.Index, $w.Reason) -ForegroundColor Red }

  if ($quotaHit) {
    Write-Host ''
    Write-Host 'STOPPED: the OpenAI account has no credit left (HTTP 429 insufficient_quota).' -ForegroundColor Red
    Write-Host 'Nothing more can be generated until credit is added to the account at platform.openai.com (Settings > Billing).' -ForegroundColor Red
    Write-Host ("Progress is saved: {0} image(s) generated this run are in the manifest. Re-run the same command after adding credit and it resumes." -f $gen) -ForegroundColor Red
    return 2
  }
  if ($bad -gt 0 -or $left -gt 0 -or $dead.Count -gt 0) { return 4 }
  return 0
}

# ---------------------------------------------------------------- main

$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not (Test-Path -LiteralPath $ImageDir)) { New-Item -ItemType Directory -Path $ImageDir -Force | Out-Null }
$ImageDirFull = (Resolve-Path -LiteralPath $ImageDir).Path

# Shards left behind by a parallel run that was killed hold finished, paid-for
# work the master never saw. Fold them in before deciding what is pending, or
# the re-run bills those images again.
if ($Parallel -gt 1 -and -not $isWorker) {
  $mFull0 = [System.IO.Path]::GetFullPath($ManifestPath)
  $mBase0 = [System.IO.Path]::GetFileNameWithoutExtension($mFull0)
  $leftover = @(Get-ChildItem -LiteralPath (Split-Path -Parent $mFull0) -Filter ("{0}.worker*.json" -f $mBase0) -File |
                Where-Object { $_.Name -notlike '*.heartbeat.json' })
  if ($leftover.Count -gt 0) {
    Write-Host ("Found {0} shard(s) from an interrupted parallel run; merging them first." -f $leftover.Count) -ForegroundColor Yellow
    $byId0 = @{}
    foreach ($p in $manifest.placeholders) { $byId0[[string]$p.id] = $p }
    $ext0 = switch ("$($cfg.generation.outputFormat)".ToLower()) { 'jpeg' { 'jpg' } 'jpg' { 'jpg' } 'webp' { 'webp' } default { 'png' } }
    # Disk recovery for a torn shard is guarded by the master's own mtime: an
    # image from the killed run is newer than the master, while a picture the
    # user rejected by setting its entry back to pending is older than the
    # master that edit re-saved, so it cannot be resurrected here.
    $since0 = (Get-Item -LiteralPath $mFull0).LastWriteTime
    foreach ($sh in $leftover) {
      $ids0 = @()
      $text0 = Get-Content -LiteralPath $sh.FullName -Raw -Encoding UTF8
      try { $ids0 = @(($text0 | ConvertFrom-Json).placeholders | ForEach-Object { [string]$_.id }) }
      catch {
        # Torn JSON still carries the ids it had written; take them by pattern.
        $ids0 = @([regex]::Matches($text0, '"id"\s*:\s*"(IMG-\d+)"') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
      }
      Merge-Shard -ShardPath $sh.FullName -Ids $ids0 -ById $byId0 -Since $since0 -Ext $ext0
      Remove-Item -LiteralPath $sh.FullName -Force -ErrorAction SilentlyContinue
      Remove-Item -LiteralPath ([System.IO.Path]::ChangeExtension($sh.FullName, '.heartbeat.json')) -Force -ErrorAction SilentlyContinue
    }
    Save-MasterManifest -Path $mFull0
  }
}

# Diagrams are built as native Word objects and never reach this endpoint.
$diagrams = @($manifest.placeholders | Where-Object { $_.kind -eq 'diagram' })
if ($diagrams.Count -gt 0) {
  Write-Host ("Skipping {0} diagram(s) - those are built natively, not generated." -f $diagrams.Count) -ForegroundColor DarkCyan
}

$targets = @($manifest.placeholders | Where-Object {
  $_.kind -ne 'diagram' -and
  ($Force -or $_.status -ne 'generated') -and (-not $Only -or $Only -contains $_.id)
})

if ($WhatIfCost) {
  Write-Host ("{0} image(s) would be generated at model {1}, default quality {2}, format {3}." -f `
    $targets.Count, $cfg.generation.model, $cfg.generation.quality, $cfg.generation.outputFormat)
  # Quality is per entry and is what drives the bill, so it is shown per entry
  # and totalled by tier. A run that is mostly 'high' should be questioned
  # before it is paid for.
  foreach ($t in $targets) {
    $q = if ($t.quality) { [string]$t.quality } else { [string]$cfg.generation.quality }
    Write-Host ("  {0}  {1,-12} {2,-10} quality {3}" -f $t.id, $t.kind, $t.size, $q)
  }
  $byTier = $targets | Group-Object { if ($_.quality) { [string]$_.quality } else { [string]$cfg.generation.quality } }
  Write-Host ("by quality: {0}" -f (($byTier | ForEach-Object { "$($_.Count) x $($_.Name)" }) -join ', '))
  if ($Parallel -gt 1 -and $targets.Count -gt 1) {
    $nPlan = [Math]::Min($Parallel, $targets.Count)
    $per   = [Math]::Ceiling($targets.Count / $nPlan)
    # ~21 s an image was measured at gpt-image-1, medium, 1536x1024.
    Write-Host ("with -Parallel {0}: {0} worker(s), at most {1} image(s) each - about {2} min of wall time instead of {3} at ~21 s an image." -f `
      $nPlan, $per, [Math]::Ceiling($per * 21 / 60), [Math]::Ceiling($targets.Count * 21 / 60))
  }
  exit 0
}

if ($targets.Count -eq 0) { Write-Host 'Nothing pending. All images already generated.'; exit 0 }

$key = if ($DryRun) { 'dry-run' } else { Resolve-ApiKey -Explicit $ApiKey }
Write-Host ("Generating {0} image(s) into {1}" -f $targets.Count, $ImageDirFull)
if ($DryRun) { Write-Host 'DRY RUN - no API call is made; each image is a 1x1 placeholder after a 1-2 s sleep.' -ForegroundColor Magenta }

if ($Parallel -gt 1 -and -not $isWorker -and $targets.Count -gt 1) {
  $code = Invoke-ParallelRun
  exit $code
}

Write-Heartbeat -State 'starting'
$seq = 0
foreach ($ph in $targets) {
  $seq++
  $full = Build-FullPrompt -DocumentPrompt $ph.prompt -Kind $ph.kind
  # Extension follows the CONFIGURED output format. Hard-coding .png here wrote
  # JPEG bytes into a .png file, and the placer then declares image/png for
  # them in [Content_Types].xml on the strength of the extension.
  $ext  = switch ("$($cfg.generation.outputFormat)".ToLower()) {
            'jpeg'  { 'jpg' }
            'jpg'   { 'jpg' }
            'webp'  { 'webp' }
            default { 'png' }
          }
  $file = Join-Path $ImageDirFull ("{0}_{1}.{2}" -f $ph.id, $ph.kind, $ext)
  Write-Host ("  {0}  {1,-12} {2}" -f $ph.id, $ph.kind, $ph.size)
  Write-Heartbeat -State 'generating' -Current ([string]$ph.id)

  $quotaStop = $false
  try {
    $b64 = Invoke-ImageGeneration -Prompt $full -Size $ph.size -Key $key -Quality ([string]$ph.quality) -Sequence $seq
    [System.IO.File]::WriteAllBytes($file, [Convert]::FromBase64String($b64))
    $ph.imageFile = $file
    $ph.status    = 'generated'
    $ph.attempts  = [int]$ph.attempts + 1
    $ph.note      = ''
    $ok++
    Write-Host ("    saved {0}" -f (Split-Path -Leaf $file)) -ForegroundColor Green
  }
  catch {
    $ph.status   = 'failed'
    $ph.attempts = [int]$ph.attempts + 1
    $ph.note     = $_.Exception.Message
    $failed++
    Write-Host ("    FAILED {0}" -f $_.Exception.Message) -ForegroundColor Red
    try { if ($_.Exception.Data -and $_.Exception.Data.Contains('quota')) { $quotaStop = $true } } catch { }
  }

  # Save after every image so an interrupted run resumes rather than restarts.
  # In a worker this is the shard, never the shared manifest.
  $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8

  # Keep the prompt that was actually sent, beside the image, for the record.
  $sidecar = [System.IO.Path]::ChangeExtension($file, '.prompt.txt')
  Set-Content -LiteralPath $sidecar -Value $full -Encoding UTF8

  if ($quotaStop) {
    Write-Heartbeat -State 'quota' -Current ([string]$ph.id) -ExitCode 2
    Write-Host 'Account credit exhausted - this worker stops here.' -ForegroundColor Red
    exit 2
  }
  Write-Heartbeat -State 'running'

  # A worker that was rate-limited eases off for a few images, then recovers.
  if ($isWorker -and $script:paceSeconds -gt 0) {
    Start-Sleep -Seconds $script:paceSeconds
    $script:paceSeconds = [int][Math]::Floor($script:paceSeconds / 2)
  }
}

Write-Host ("Done. {0} generated, {1} failed." -f $ok, $failed)
Write-Heartbeat -State 'done' -ExitCode $(if ($failed -gt 0) { 4 } else { 0 })
if ($failed -gt 0) { exit 4 }
