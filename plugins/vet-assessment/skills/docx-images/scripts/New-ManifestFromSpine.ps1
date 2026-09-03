<#
.SYNOPSIS
  Builds the image manifest straight from the content spine, before any
  document has been rendered.

.DESCRIPTION
  WHY THIS EXISTS. Image generation used to be gated on a render it did not
  need. Find-DocxImagePrompts.ps1 reads its prompts out of a finished .docx, so
  the ~20 minutes of API time for a guide's illustrations could not start until
  the guide had been rendered - yet every prompt already existed on the spine
  (visuals[].prompt with slot, kind, aspect, quality, caption and alt) the
  moment authoring finished, about 45 minutes earlier. This script reads the
  spine directly and writes a manifest in exactly the shape the scanner writes,
  so New-DocImages.ps1 can start the moment authoring ends and run while the
  guide is being rendered and gated.

  IDS ARE ASSIGNED IN SLOT ORDER so they are stable across renders: the cover
  visual (slot 0.1, held under cover.json's singular "visual" key) first, then
  every sub-section visual by numeric slot. The scanner assigns the same ids in
  document order, and the guide places its figures in slot order, so the two
  agree. Each entry also carries its slot, which is the identity the placement
  step reconciles on - a build's Carry-GoodImages.ps1 already carries reviewed
  images by slot precisely because ids shift the moment a figure is inserted.

  paraStart and paraEnd are null: no paragraph exists yet. Placement still
  re-scans the rendered document and carries images across by slot.

  promptHash is the SHA256 of the normalised prompt text. When a previous
  manifest exists (the one at -ManifestPath, or -CarryFrom), an illustration is
  carried forward as generated - file, status and attempts - only when the same
  slot was generated before, its prompt hash is unchanged, and the file is still
  in -ImageDir. That is what stops a spine edit to one caption from re-billing
  fifty-seven photographs. Where the id has moved, the file is copied to the
  new id's name so a later generation for the old id cannot overwrite it.

  Kind: a spine kind of "Diagram" is a diagram, anything else an illustration -
  the renderer's own rule. Size follows aspect through the same config mapping
  the scanner uses. Quality is the entry's own, else the config default.
  Illustrations start pending; a diagram with a spec starts spec-ready with the
  spec copied in, and one without starts needs-spec, as the scanner would.

.EXAMPLE
  .\New-ManifestFromSpine.ps1 -SpineDir .\spine -ManifestPath .\images\manifest.json -ImageDir .\images
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$SpineDir,
  [Parameter(Mandatory)][string]$ManifestPath,
  [Parameter(Mandatory)][string]$ImageDir,
  [string]$ConfigPath,
  [string]$CarryFrom,
  [switch]$NoCarry,
  [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

if (-not $ConfigPath) { $ConfigPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'config\defaults.json' }
$cfg = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not (Test-Path -LiteralPath $SpineDir -PathType Container)) { throw "Spine directory not found: $SpineDir" }
$SpineDirFull = (Resolve-Path -LiteralPath $SpineDir).Path
if (-not (Test-Path -LiteralPath $ImageDir)) { New-Item -ItemType Directory -Path $ImageDir -Force | Out-Null }
$ImageDirFull = (Resolve-Path -LiteralPath $ImageDir).Path
$ManifestFull = [System.IO.Path]::GetFullPath($ManifestPath)

# ---------------------------------------------------------------- helpers

function Test-Prop {
  param($Obj, [string]$Name)
  return ($null -ne $Obj -and @($Obj.PSObject.Properties.Name) -contains $Name)
}

function Get-Str {
  param($Obj, [string]$Name)
  if ((Test-Prop $Obj $Name) -and $null -ne $Obj.$Name) { return [string]$Obj.$Name }
  return ''
}

function Get-SlotSortKey {
  # "1.10.2" must sort after "1.9.4", which a plain string sort gets wrong, so
  # every numeric part is zero-padded. A non-numeric part sorts after numbers.
  param([string]$Slot)
  $keys = foreach ($p in ($Slot -split '\.')) {
    $n = 0
    if ([int]::TryParse($p, [ref]$n)) { '{0:d6}' -f $n } else { 'z' + $p }
  }
  return ($keys -join '.')
}

function Get-NormalisedPrompt {
  # Whitespace collapsed the way the scanner collapses it, and the scanner's
  # own artefact removed: it leaves the closing tag's "[/IMAGE" on the end of
  # every prompt it reads, so a prompt compared across the two sources must
  # have that stripped or nothing ever matches.
  param([string]$Text)
  if ($null -eq $Text) { return '' }
  $t = ($Text -replace '\s+', ' ').Trim()
  $t = $t -replace '\s*\[\s*/\s*(IMAGE|ILLUSTRATION|DIAGRAM|PHOTO|FIGURE|PICTURE)\s*\]?\s*$', ''
  return $t.Trim()
}

function Get-Sha256Hex {
  param([string]$Text)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text)) }
  finally { $sha.Dispose() }
  return (($bytes | ForEach-Object { $_.ToString('x2') }) -join '')
}

function ConvertTo-Aspect {
  # The spine says "3:2 landscape" or "2:3 portrait"; the scanner only knows
  # landscape / portrait / square and falls back to landscape for anything
  # else. Reading the word out of the spine string keeps a portrait cover
  # portrait instead of silently landscape.
  param([string]$Raw, [string]$Kind)
  $a = "$Raw".ToLower().Trim()
  if (-not $a) { $a = [string]$cfg.generation.defaultAspect.$Kind }
  if ($a -match 'portrait')  { return 'portrait' }
  if ($a -match 'square')    { return 'square' }
  if ($a -match 'landscape') { return 'landscape' }
  return 'landscape'
}

function ConvertTo-Quality {
  param([string]$Raw)
  $q = "$Raw".ToLower().Trim()
  if (-not $q -or $q -notin @('low', 'medium', 'high', 'auto')) { $q = [string]$cfg.generation.quality }
  return $q
}

function Get-PreviousSlot {
  # The slot of an entry in an older manifest. A manifest built here carries
  # it; a scanned one only has it inside the caption ("Figure 1.1.2 - ...").
  param($Entry)
  $s = (Get-Str $Entry 'slot').Trim()
  if ($s) { return $s }
  $cap = Get-Str $Entry 'caption'
  if ($cap -match 'Figure\s+(\d+(?:\.\d+)+)') { return $Matches[1] }
  return ''
}

# ---------------------------------------------------------------- collect

$files = @(Get-ChildItem -LiteralPath $SpineDirFull -Filter '*.json' -File | Sort-Object Name)
if ($files.Count -eq 0) { throw "No spine files (*.json) in $SpineDirFull" }

$collected = New-Object System.Collections.Generic.List[object]
foreach ($f in $files) {
  $j = $null
  try { $j = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json }
  catch { throw ("Spine file does not parse: {0} - {1}" -f $f.FullName, $_.Exception.Message) }
  if ($null -eq $j) { continue }

  $nodes = @()
  if (Test-Prop $j 'visuals') { $nodes += @($j.visuals | Where-Object { $null -ne $_ }) }
  # cover.json holds one visual under the singular key.
  if ((Test-Prop $j 'visual') -and $null -ne $j.visual) { $nodes += $j.visual }

  foreach ($v in $nodes) {
    $slot = (Get-Str $v 'slot').Trim()
    if (-not $slot) {
      throw ("A visual in {0} has no slot. The slot is the identity every image is carried by; give it one." -f $f.Name)
    }
    $collected.Add([pscustomobject]@{ File = $f.Name; Slot = $slot; Key = (Get-SlotSortKey $slot); Node = $v })
  }
}

$dups = @($collected | Group-Object Slot | Where-Object { $_.Count -gt 1 })
if ($dups.Count -gt 0) {
  $list = ($dups | ForEach-Object { "{0} ({1})" -f $_.Name, (($_.Group | ForEach-Object { $_.File }) -join ', ') }) -join '; '
  throw "Duplicate visual slot(s) on the spine, so ids would not be stable: $list"
}

$ordered = @($collected | Sort-Object Key)

# ---------------------------------------------------------------- previous manifest, for carry

$prevBySlot   = @{}
$prevByPrompt = @{}
$carrySource  = ''
if (-not $NoCarry) {
  if ($CarryFrom) { $carrySource = $CarryFrom }
  elseif (Test-Path -LiteralPath $ManifestFull) { $carrySource = $ManifestFull }
  if ($carrySource) {
    $prev = $null
    try { $prev = Get-Content -LiteralPath $carrySource -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { Write-Warning ("Previous manifest could not be read, so nothing is carried: {0}" -f $carrySource) }
    if ($prev -and (Test-Prop $prev 'placeholders')) {
      foreach ($p in @($prev.placeholders)) {
        if ($null -eq $p) { continue }
        $ps = Get-PreviousSlot $p
        if ($ps -and -not $prevBySlot.ContainsKey($ps)) { $prevBySlot[$ps] = $p }
        # The cover has no caption and a scanned manifest has no slot field, so
        # a prompt-text match is the last resort for finding it.
        $ph = Get-Sha256Hex (Get-NormalisedPrompt (Get-Str $p 'prompt'))
        if (-not $prevByPrompt.ContainsKey($ph)) { $prevByPrompt[$ph] = $p }
      }
    }
  }
}

$ext = switch ("$($cfg.generation.outputFormat)".ToLower()) {
  'jpeg'  { 'jpg' }
  'jpg'   { 'jpg' }
  'webp'  { 'webp' }
  default { 'png' }
}

# ---------------------------------------------------------------- build entries

$found   = @()
$seq     = 0
$carried = 0
$copied  = 0
foreach ($c in $ordered) {
  $v    = $c.Node
  $slot = $c.Slot
  $seq++
  $id = ('IMG-{0:d3}' -f $seq)

  $kindRaw = (Get-Str $v 'kind').Trim()
  $kind    = if ($kindRaw -ieq 'diagram') { 'diagram' } else { 'illustration' }

  $prompt = Get-NormalisedPrompt (Get-Str $v 'prompt')
  if (-not $prompt -and $kind -eq 'illustration') {
    throw ("Slot {0} in {1} is an illustration with no prompt. Nothing can be generated from it." -f $slot, $c.File)
  }
  if (-not $prompt) { Write-Warning ("Slot {0} in {1} is a diagram with no prompt; it is carried on its spec alone." -f $slot, $c.File) }
  $hash = Get-Sha256Hex $prompt

  # The renderer writes "CAPTION: Figure <slot> - <caption>" onto the page,
  # and the scanner records that line verbatim. A cover image (an Image at
  # slot 0.1) is decorative and gets no caption at all - the renderer's rule,
  # kept here so the two manifests agree.
  $capRaw  = (Get-Str $v 'caption').Trim()
  $caption = ''
  if ($capRaw) { $caption = "Figure $slot - $capRaw" }
  elseif (-not ($kind -eq 'illustration' -and $slot -eq '0.1')) { $caption = "Figure $slot" }

  $alt     = (Get-Str $v 'alt').Trim()
  $aspect  = ConvertTo-Aspect -Raw (Get-Str $v 'aspect') -Kind $kind
  $quality = ConvertTo-Quality -Raw (Get-Str $v 'quality')
  $tag     = if ($kind -eq 'diagram') { 'DIAGRAM' } else { 'IMAGE' }

  # The spec is copied as authored, less the spine's own "_"-prefixed
  # commentary keys (_wasFlow, _comment): those are authoring notes, not
  # spec, and the build's spec writer has never carried them either.
  $spec = $null
  if ((Test-Prop $v 'spec') -and $null -ne $v.spec) {
    $clean = [ordered]@{}
    foreach ($p in $v.spec.PSObject.Properties) { if ($p.Name -notlike '_*') { $clean[$p.Name] = $p.Value } }
    $spec = [pscustomobject]$clean
  }

  if ($kind -eq 'diagram') {
    $status = if ($spec) { 'spec-ready' } else { 'needs-spec' }
    $note   = if ($spec) { '' } else { 'Native Word diagram. Author a spec into the spec field, then set status to spec-ready.' }
    $entry = [ordered]@{
      id         = $id
      slot       = $slot
      kind       = 'diagram'
      aspect     = $aspect
      quality    = $quality
      size       = ''
      paraStart  = $null
      paraEnd    = $null
      markerText = "[$tag`: $prompt"
      prompt     = $prompt
      promptHash = $hash
      caption    = $caption
      alt        = $alt
      imageFile  = ''
      spec       = $spec
      status     = $status
      attempts   = 0
      note       = $note
    }
  }
  else {
    $entry = [ordered]@{
      id         = $id
      slot       = $slot
      kind       = 'illustration'
      aspect     = $aspect
      quality    = $quality
      size       = [string]$cfg.generation.sizes.$aspect
      paraStart  = $null
      paraEnd    = $null
      markerText = "[$tag`: $prompt"
      prompt     = $prompt
      promptHash = $hash
      caption    = $caption
      alt        = $alt
      imageFile  = ''
      spec       = $null
      status     = 'pending'
      attempts   = 0
      note       = ''
    }

    # Carry a generated image forward when the prompt has not changed.
    $prev = $null
    if ($prevBySlot.ContainsKey($slot)) { $prev = $prevBySlot[$slot] }
    elseif ($prevByPrompt.ContainsKey($hash)) { $prev = $prevByPrompt[$hash] }
    if ($prev -and (Get-Str $prev 'kind') -eq 'illustration' -and (Get-Str $prev 'status') -eq 'generated') {
      $prevHash = Get-Sha256Hex (Get-NormalisedPrompt (Get-Str $prev 'prompt'))
      $prevFile = Get-Str $prev 'imageFile'
      if ($prevHash -eq $hash -and $prevFile -and (Test-Path -LiteralPath $prevFile)) {
        $prevFull = (Resolve-Path -LiteralPath $prevFile).Path
        $newFile  = Join-Path $ImageDirFull ("{0}_illustration{1}" -f $id, [System.IO.Path]::GetExtension($prevFull))
        if ($prevFull -ieq $newFile) {
          $entry.imageFile = $prevFull
          $entry.note      = ''
        }
        else {
          # The id moved. Copy under the new id so a later generation for the
          # old id cannot overwrite a reviewed picture.
          Copy-Item -LiteralPath $prevFull -Destination $newFile -Force
          $prevSide = [System.IO.Path]::ChangeExtension($prevFull, '.prompt.txt')
          if (Test-Path -LiteralPath $prevSide) {
            Copy-Item -LiteralPath $prevSide -Destination ([System.IO.Path]::ChangeExtension($newFile, '.prompt.txt')) -Force
          }
          $entry.imageFile = $newFile
          $entry.note      = ("carried from {0} by slot {1}; prompt unchanged" -f (Get-Str $prev 'id'), $slot)
          $copied++
        }
        $entry.status   = 'generated'
        $entry.attempts = [int](Get-Str $prev 'attempts')
        $carried++
      }
    }
  }

  $found += $entry
}

# ---------------------------------------------------------------- write

$manifest = [ordered]@{
  sourceDocument = $SpineDirFull
  scannedUtc     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  paragraphCount = 0
  placeholders   = $found
}

$mdir = Split-Path -Parent $ManifestFull
if ($mdir -and -not (Test-Path -LiteralPath $mdir)) { New-Item -ItemType Directory -Path $mdir -Force | Out-Null }
$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ManifestFull -Encoding UTF8

if (-not $Quiet) {
  $nIll  = @($found | Where-Object { $_.kind -eq 'illustration' }).Count
  $nDiag = @($found | Where-Object { $_.kind -eq 'diagram' }).Count
  $nSpec = @($found | Where-Object { $_.kind -eq 'diagram' -and $_.status -eq 'spec-ready' }).Count
  Write-Host ("Built {0} entr{1} from {2} spine file(s): {3} illustration(s), {4} diagram(s) ({5} with a spec)." -f `
    $found.Count, $(if ($found.Count -eq 1) { 'y' } else { 'ies' }), $files.Count, $nIll, $nDiag, $nSpec)
  if ($carrySource) {
    Write-Host ("Carried {0} generated illustration(s) from {1}{2}; {3} still to generate." -f `
      $carried, $carrySource, $(if ($copied) { " ($copied copied to a new id)" } else { '' }), ($nIll - $carried)) -ForegroundColor DarkCyan
  }
  foreach ($e in $found) {
    $preview = $e.prompt
    if ($preview.Length -gt 84) { $preview = $preview.Substring(0, 84) + '...' }
    Write-Host ("  {0}  {1,-7} {2,-12} {3,-10} {4}" -f $e.id, $e.slot, $e.kind, $e.status, $preview)
  }
  if (($nDiag - $nSpec) -gt 0) {
    Write-Host ("{0} diagram(s) need a spec before they can be placed. See references/diagram-specs.md." -f ($nDiag - $nSpec)) -ForegroundColor Yellow
  }
  Write-Host ("Manifest: {0}" -f $ManifestFull)
}
if ($found.Count -eq 0) { exit 3 }
