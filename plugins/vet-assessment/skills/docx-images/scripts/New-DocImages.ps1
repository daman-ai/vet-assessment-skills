<#
.SYNOPSIS
  Generates one image per pending manifest entry with the OpenAI image model.

.DESCRIPTION
  Reads the manifest written by Find-DocxImagePrompts.ps1, wraps each prompt
  taken from the document in the house rules for its kind, calls the images
  endpoint, and writes the image into -ImageDir in the configured format. The
  manifest is updated in place after every image, so an interrupted run resumes
  where it stopped.

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

.EXAMPLE
  .\New-DocImages.ps1 -ManifestPath .\images\manifest.json -ImageDir .\images
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$ManifestPath,
  [Parameter(Mandatory)][string]$ImageDir,
  [string]$ConfigPath,
  [string]$ApiKey,
  [string[]]$Only,
  [switch]$Force,
  [switch]$WhatIfCost
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not $ConfigPath) { $ConfigPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'config\defaults.json' }
$cfg = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

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

function Invoke-ImageGeneration {
  param(
    [Parameter(Mandatory)][string]$Prompt,
    [Parameter(Mandatory)][string]$Size,
    [Parameter(Mandatory)][string]$Key,
    [string]$Quality
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
      $resp = Invoke-RestMethod -Method Post -Uri $cfg.generation.endpoint `
                -Headers $headers -ContentType 'application/json' `
                -Body $bytes -TimeoutSec ([int]$cfg.generation.timeoutSeconds)
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
      $status = 0
      $detail = $_.Exception.Message
      if ($_.Exception.Response) {
        try { $status = [int]$_.Exception.Response.StatusCode } catch { $status = 0 }
        try {
          $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
          $raw = $sr.ReadToEnd(); $sr.Close()
          if ($raw) {
            try { $detail = ($raw | ConvertFrom-Json).error.message } catch { $detail = $raw }
          }
        } catch { }
      }

      # 400 is almost always the prompt itself. Retrying an identical prompt
      # cannot help, so surface it and let the caller rewrite it.
      if ($status -eq 400 -or $status -eq 401 -or $status -eq 403) {
        throw "HTTP $status - $detail"
      }
      if ($try -ge $maxTry) { throw "HTTP $status after $maxTry attempts - $detail" }
      $waitList = @($cfg.generation.retryBackoffSeconds)
      $wait = $waitList[[Math]::Min($try - 1, $waitList.Count - 1)]
      Write-Host ("    retry {0}/{1} in {2}s (HTTP {3}: {4})" -f $try, $maxTry, $wait, $status, $detail) -ForegroundColor DarkYellow
      Start-Sleep -Seconds $wait
    }
  }
}

# ---------------------------------------------------------------- main

$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not (Test-Path -LiteralPath $ImageDir)) { New-Item -ItemType Directory -Path $ImageDir -Force | Out-Null }
$ImageDirFull = (Resolve-Path -LiteralPath $ImageDir).Path

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
  exit 0
}

if ($targets.Count -eq 0) { Write-Host 'Nothing pending. All images already generated.'; exit 0 }

$key = Resolve-ApiKey -Explicit $ApiKey
Write-Host ("Generating {0} image(s) into {1}" -f $targets.Count, $ImageDirFull)

$ok = 0; $failed = 0
foreach ($ph in $targets) {
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

  try {
    $b64 = Invoke-ImageGeneration -Prompt $full -Size $ph.size -Key $key -Quality ([string]$ph.quality)
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
  }

  # Save after every image so an interrupted run resumes rather than restarts.
  $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8

  # Keep the prompt that was actually sent, beside the image, for the record.
  $sidecar = [System.IO.Path]::ChangeExtension($file, '.prompt.txt')
  Set-Content -LiteralPath $sidecar -Value $full -Encoding UTF8
}

Write-Host ("Done. {0} generated, {1} failed." -f $ok, $failed)
if ($failed -gt 0) { exit 4 }
