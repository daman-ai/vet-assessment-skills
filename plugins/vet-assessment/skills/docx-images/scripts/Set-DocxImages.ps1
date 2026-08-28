<#
.SYNOPSIS
  Replaces each prompt placeholder in a .docx with its generated picture.

.DESCRIPTION
  Reads the manifest, opens the document, and for every entry marked
  'generated' swaps the whole prompt block for a centred inline picture sized
  to the column, followed by an italic caption. Alt text is written onto the
  drawing so the document stays accessible.

  The prompt text is removed, not hidden. What ships carries no instruction
  to a model anywhere in it.

  Writes to -OutPath. The source document is never modified.

.EXAMPLE
  .\Set-DocxImages.ps1 -Path .\SITHKOP013_UAT.docx -ManifestPath .\images\manifest.json -OutPath .\out\SITHKOP013_UAT.docx
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Path,
  [Parameter(Mandatory)][string]$ManifestPath,
  [Parameter(Mandatory)][string]$OutPath,
  [string]$ConfigPath,
  [switch]$NoCaption,
  [switch]$AllowMissing
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Docx-ImageLib.ps1')
. (Join-Path $PSScriptRoot 'Docx-DiagramLib.ps1')

if (-not $ConfigPath) { $ConfigPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'config\defaults.json' }
$cfg = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$dcfg = if ($cfg.PSObject.Properties['diagram']) { $cfg.diagram } else { $null }

# An illustration is ready when its PNG exists. A diagram is ready when it has
# a spec - it is built from that spec here, natively, with no image involved.
$ready = @($manifest.placeholders | Where-Object {
  ($_.kind -ne 'diagram' -and $_.status -eq 'generated' -and $_.imageFile) -or
  ($_.kind -eq 'diagram'  -and $_.status -eq 'spec-ready' -and $_.spec)
})
$readyIds = @($ready | ForEach-Object { $_.id })
$notReady = @($manifest.placeholders | Where-Object { $readyIds -notcontains $_.id })

if ($notReady.Count -gt 0 -and -not $AllowMissing) {
  Write-Host "These placeholders are not ready:" -ForegroundColor Yellow
  foreach ($n in $notReady) { Write-Host ("  {0}  {1,-12} {2}  {3}" -f $n.id, $n.kind, $n.status, $n.note) -ForegroundColor Yellow }
  throw "Refusing to build a document with unfilled prompts still in it. Fix them, or pass -AllowMissing to leave them as text."
}

foreach ($r in $ready) {
  if ($r.kind -ne 'diagram' -and -not (Test-Path -LiteralPath $r.imageFile)) {
    throw "$($r.id): image file missing at $($r.imageFile)"
  }
}

$work = Expand-Docx -Path $Path
try {
  $docPath = Join-Path $work 'word\document.xml'
  [xml]$doc = Get-Content -LiteralPath $docPath -Raw -Encoding UTF8
  $ns = New-NsMgr $doc

  $paras = @($doc.SelectNodes('//w:p', $ns))
  if ($paras.Count -ne [int]$manifest.paragraphCount) {
    Write-Host ("Warning: the document has {0} paragraphs, the manifest was written against {1}. Re-scan if placements look wrong." -f `
      $paras.Count, $manifest.paragraphCount) -ForegroundColor Yellow
  }

  $contentW = Get-ContentWidthEmu -DocXml $doc
  $nextId   = Get-NextDrawingId -DocXml $doc
  $figNo    = 0
  $done     = 0

  foreach ($ph in $ready) {
    $start = [int]$ph.paraStart
    $end   = [int]$ph.paraEnd
    if ($start -lt 0 -or $start -ge $paras.Count) { throw "$($ph.id): paragraph index $start is outside the document." }

    $target = $paras[$start]
    $actual = Get-ParagraphText -Paragraph $target
    if ($actual -ne $ph.markerText) {
      throw "$($ph.id): the document has moved under the manifest. Expected `"$($ph.markerText)`" at paragraph $start but found `"$actual`". Re-run Find-DocxImagePrompts.ps1."
    }

    $alt = $ph.alt
    if (-not $alt) { $alt = $ph.caption }
    if (-not $alt) {
      # Never ship empty alt text on an instructional image. Fall back to the
      # prompt, trimmed, which describes exactly what is pictured.
      $alt = $ph.prompt
      if ($alt.Length -gt 220) { $alt = $alt.Substring(0,217) + '...' }
    }

    # Size against the cell when the prompt sits in one, not the section.
    $placeW = Get-PlacementWidthEmu -Paragraph $target -NsMgr $ns -DefaultEmu $contentW

    $frags = @()
    if ($ph.kind -eq 'diagram') {
      # Native Word objects: a canvas of real shapes, or a real table.
      # Nothing is rasterised, so every label stays editable.
      $built = New-DiagramXml -Spec $ph.spec -WidthEmu $placeW -StartId $nextId -Alt $alt -Config $dcfg
      $frags += $built.Xml
      $nextId = $built.NextId
      $what = "native $("$(if ($ph.spec.PSObject.Properties['layout']) { $ph.spec.layout } else { 'process' })") diagram"
    }
    else {
      $px  = Get-PngSize -Path $ph.imageFile
      $frac = [double]$cfg.placement.widthFraction.($ph.kind)
      $ext = Get-FittedExtent -PixelWidth $px.Width -PixelHeight $px.Height `
               -MaxWidthEmu $placeW -MaxHeightCm ([double]$cfg.placement.maxHeightCm) -WidthFraction $frac
      $part = Add-DocxImagePart -WorkDir $work -ImagePath $ph.imageFile
      $frags += New-InlinePictureParagraphXml -RelId $part.RelId -Cx $ext.Cx -Cy $ext.Cy `
                  -Id $nextId -Alt $alt -Name ("{0} {1}" -f $ph.id, $ph.kind)
      $nextId++
      $what = "$(Split-Path -Leaf $ph.imageFile)  ($($px.Width) x $($px.Height) px)"
    }

    if (-not $NoCaption -and $ph.caption) {
      $figNo++
      $capText = $ph.caption
      if ($cfg.placement.captionPrefix -and $capText -notmatch '^\s*(Figure|Fig\.)\s') {
        $capText = "{0}{1}: {2}" -f $cfg.placement.captionPrefix, $figNo, $capText
      }
      $frags += New-CaptionParagraphXml -Text $capText -SizeHalfPt ([int]$cfg.placement.captionSizeHalfPt)
    }

    Set-XmlFragmentInPlace -Doc $doc -Target $target -XmlFragments $frags

    # Drop the remaining paragraphs of a multi-paragraph prompt block.
    for ($k = $start + 1; $k -le $end -and $k -lt $paras.Count; $k++) {
      $extra = $paras[$k]
      if ($extra.ParentNode) { [void]$extra.ParentNode.RemoveChild($extra) }
    }

    $done++
    Write-Host ("  {0}  placed {1}" -f $ph.id, $what)
  }

  $doc.Save($docPath)
  $out = Compress-Docx -Source $work -Path $OutPath
  Write-Host ("Placed {0} image(s). Wrote {1}" -f $done, $out) -ForegroundColor Green
}
finally {
  if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
