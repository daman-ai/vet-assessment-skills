<#
.SYNOPSIS
  Scans a .docx for image prompt placeholders and writes a manifest.

.DESCRIPTION
  In these documents the placeholder IS the prompt: a detailed instruction
  sitting on the page where the picture belongs, marked as an illustration or
  as a diagram. This script finds every one of them, works out which kind it
  is, pulls out any Caption / Alt / Aspect lines, and writes a JSON manifest.

  Nothing is generated and nothing is changed here. Read-only.

.EXAMPLE
  .\Find-DocxImagePrompts.ps1 -Path .\SITHKOP013_UAT.docx -ManifestPath .\images\manifest.json
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Path,
  [Parameter(Mandatory)][string]$ManifestPath,
  [string]$ConfigPath,
  [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Docx-ImageLib.ps1')

if (-not $ConfigPath) { $ConfigPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'config\defaults.json' }
$cfg = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

$work = Expand-Docx -Path $Path
try {
  $docPath = Join-Path $work 'word\document.xml'
  [xml]$doc = Get-Content -LiteralPath $docPath -Raw -Encoding UTF8
  $ns = New-NsMgr $doc

  $paras = @($doc.SelectNodes('//w:p', $ns))
  $texts = @()
  foreach ($p in $paras) { $texts += (Get-ParagraphText -Paragraph $p) }

  $found = @()
  $i = 0
  $seq = 0
  while ($i -lt $texts.Count) {
    $t = $texts[$i]
    $m = $null
    $kindHint = $null
    $body = $null

    foreach ($pat in $cfg.detection.open) {
      $mm = [regex]::Match($t, $pat, 'IgnoreCase')
      if ($mm.Success) {
        $m = $mm
        if ($mm.Groups['kind'].Success) { $kindHint = $mm.Groups['kind'].Value.ToUpper() }
        $body = $mm.Groups['body'].Value
        break
      }
    }

    if (-not $m) { $i++; continue }

    # Collect the block. A prompt that opens a bracket runs until it closes.
    $lines = @()
    if ($body) { $lines += $body }
    $startIdx = $i
    $endIdx   = $i
    $opened   = ([regex]::Matches($t, '\[')).Count
    $closed   = ([regex]::Matches($t, '\]')).Count
    $needsClose = ($t.TrimStart().StartsWith('[')) -and ($closed -lt $opened)

    $j = $i + 1
    $guard = 0
    while ($needsClose -and $j -lt $texts.Count -and $guard -lt $cfg.detection.maxParagraphs) {
      $lt = $texts[$j]
      $isClose = $false
      foreach ($cp in $cfg.detection.close) {
        if ([regex]::IsMatch($lt, $cp, 'IgnoreCase')) { $isClose = $true; break }
      }
      $lines += $lt
      $endIdx = $j
      $opened += ([regex]::Matches($lt, '\[')).Count
      $closed += ([regex]::Matches($lt, '\]')).Count
      if ($isClose -or $closed -ge $opened) { $needsClose = $false }
      $j++; $guard++
    }

    # Pull out the labelled field lines; everything else is prompt body.
    $caption = ''; $alt = ''; $aspect = ''; $kindField = ''; $quality = ''
    $promptLines = @()
    foreach ($ln in $lines) {
      $handled = $false
      foreach ($fname in @('caption','alt','aspect','quality','kind')) {
        $fpat = $cfg.detection.fieldLines.$fname
        $fm = [regex]::Match($ln, $fpat, 'IgnoreCase')
        if ($fm.Success) {
          $v = $fm.Groups['v'].Value.Trim().TrimEnd(']').Trim()
          switch ($fname) {
            'caption' { $caption   = $v }
            'alt'     { $alt       = $v }
            'aspect'  { $aspect    = $v }
            'quality' { $quality   = $v }
            'kind'    { $kindField = $v }
          }
          $handled = $true; break
        }
      }
      if (-not $handled) { $promptLines += $ln }
    }

    $prompt = ($promptLines -join ' ').Trim()
    $prompt = $prompt -replace '\s*\]\s*$', ''
    $prompt = ($prompt -replace '\s+', ' ').Trim()

    # A one-paragraph prompt writes its fields mid-sentence rather than on
    # their own lines. Lift those out too, then take what is left as the body.
    $inline = [regex]::Matches($prompt, $cfg.detection.inlineFields)
    if ($inline.Count -gt 0) {
      foreach ($x in $inline) {
        $f = ($x.Groups['f'].Value.ToLower() -replace '\s+', '')
        $v = $x.Groups['v'].Value.Trim().TrimEnd(']').Trim()
        switch ($f) {
          'caption'     { if (-not $caption)   { $caption   = $v } }
          'alt'         { if (-not $alt)       { $alt       = $v } }
          'alttext'     { if (-not $alt)       { $alt       = $v } }
          'aspect'      { if (-not $aspect)    { $aspect    = $v } }
          'quality'     { if (-not $quality)   { $quality   = $v } }
          'orientation' { if (-not $aspect)    { $aspect    = $v } }
          'type'        { if (-not $kindField) { $kindField = $v } }
          'kind'        { if (-not $kindField) { $kindField = $v } }
        }
      }
      # Cut from the back so the earlier match offsets stay valid.
      for ($z = $inline.Count - 1; $z -ge 0; $z--) {
        $prompt = $prompt.Remove($inline[$z].Index, $inline[$z].Length)
      }
      $prompt = ($prompt -replace '\s+', ' ').Trim()
    }

    if ($prompt.Length -lt [int]$cfg.detection.minPromptChars) { $i = $endIdx + 1; continue }

    # Which kind? The marker if it says, then an explicit Type line, then the words.
    $kind = ''
    $hint = if ($kindField) { $kindField.ToUpper() } elseif ($kindHint) { $kindHint } else { '' }
    if ($hint -match 'DIAGRAM|SCHEMATIC|CHART|FLOW') { $kind = 'diagram' }
    elseif ($hint -match 'ILLUSTRATION|PHOTO|IMAGE|PICTURE|FIGURE') { $kind = 'illustration' }
    if (-not $kind) {
      foreach ($kw in $cfg.kindInference.diagramKeywords) {
        if ($prompt -match [regex]::Escape($kw)) { $kind = 'diagram'; break }
      }
    }
    if (-not $kind) { $kind = $cfg.kindInference.default }
    # A marker that only said IMAGE still becomes a diagram if it describes one.
    if ($kind -eq 'illustration' -and $hint -notmatch 'PHOTO|ILLUSTRATION') {
      foreach ($kw in $cfg.kindInference.diagramKeywords) {
        if ($prompt -match [regex]::Escape($kw)) { $kind = 'diagram'; break }
      }
    }

    # QUALITY IS PER ENTRY, defaulting to the config. The config's own comment
    # said "set it on that entry, not on this file" and there was no way to -
    # every image was billed at the file-wide setting whatever the page needed.
    if (-not $quality) { $quality = [string]$cfg.generation.quality }
    $quality = $quality.ToLower().Trim()
    if ($quality -notin @('low','medium','high','auto')) { $quality = [string]$cfg.generation.quality }

    if (-not $aspect) { $aspect = $cfg.generation.defaultAspect.$kind }
    $aspect = $aspect.ToLower().Trim()
    if ($aspect -notin @('landscape','portrait','square')) { $aspect = 'landscape' }

    $seq++
    # Illustrations go to the image API. Diagrams never do - they are built as
    # native Word objects from a spec, so they start life waiting for one.
    if ($kind -eq 'diagram') {
      $found += [ordered]@{
        id            = ('IMG-{0:d3}' -f $seq)
        kind          = 'diagram'
        aspect        = $aspect
        quality       = $quality
        size          = ''
        paraStart     = $startIdx
        paraEnd       = $endIdx
        markerText    = $t
        prompt        = $prompt
        caption       = $caption
        alt           = $alt
        imageFile     = ''
        spec          = $null
        status        = 'needs-spec'
        attempts      = 0
        note          = 'Native Word diagram. Author a spec into the spec field, then set status to spec-ready.'
      }
    }
    else {
      $found += [ordered]@{
        id            = ('IMG-{0:d3}' -f $seq)
        kind          = 'illustration'
        aspect        = $aspect
        quality       = $quality
        size          = $cfg.generation.sizes.$aspect
        paraStart     = $startIdx
        paraEnd       = $endIdx
        markerText    = $t
        prompt        = $prompt
        caption       = $caption
        alt           = $alt
        imageFile     = ''
        spec          = $null
        status        = 'pending'
        attempts      = 0
        note          = ''
      }
    }

    $i = $endIdx + 1
  }

  $manifest = [ordered]@{
    sourceDocument = (Resolve-Path -LiteralPath $Path).Path
    scannedUtc     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    paragraphCount = $texts.Count
    placeholders   = $found
  }

  $mdir = Split-Path -Parent ([System.IO.Path]::GetFullPath($ManifestPath))
  if ($mdir -and -not (Test-Path -LiteralPath $mdir)) { New-Item -ItemType Directory -Path $mdir -Force | Out-Null }
  $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8

  if (-not $Quiet) {
    $nIll  = @($found | Where-Object { $_.kind -eq 'illustration' }).Count
    $nDiag = @($found | Where-Object { $_.kind -eq 'diagram' }).Count
    Write-Host ("Found {0} prompt(s) in {1}: {2} illustration(s) to generate, {3} diagram(s) to build natively." -f `
      $found.Count, (Split-Path -Leaf $Path), $nIll, $nDiag)
    foreach ($f in $found) {
      $preview = $f.prompt
      if ($preview.Length -gt 84) { $preview = $preview.Substring(0,84) + '...' }
      Write-Host ("  {0}  {1,-12} para {2,-5} {3}" -f $f.id, $f.kind, $f.paraStart, $preview)
    }
    if ($nDiag -gt 0) {
      Write-Host ("{0} diagram(s) need a spec before they can be placed. See references/diagram-specs.md." -f $nDiag) -ForegroundColor Yellow
    }
    Write-Host ("Manifest: {0}" -f ([System.IO.Path]::GetFullPath($ManifestPath)))
  }
  if ($found.Count -eq 0) { exit 3 }
}
finally {
  if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
