# Docx-ImageLib.ps1
# Shared OpenXML helpers for finding prompt placeholders in a .docx and
# replacing them with real inline pictures.
#
# Dot-source this file. It defines functions only; it runs nothing.
#
# Same approach as the assessment skill's Build-FromTemplate.ps1: a .docx is a
# zip, so extract it, edit word/document.xml as XML, and rezip. No Word, no
# OpenXML SDK, no Python. Word is used only later, for the PDF.

Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# A function, not a script-scoped variable. When this file is dot-sourced,
# $script: resolves against the calling script, which makes the value
# unreliable once one library function calls another. A function always works.
function Get-DocxNSMap {
  return @{
    w   = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
    r   = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
    wp  = 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing'
    a   = 'http://schemas.openxmlformats.org/drawingml/2006/main'
    pic = 'http://schemas.openxmlformats.org/drawingml/2006/picture'
    ct  = 'http://schemas.openxmlformats.org/package/2006/content-types'
    rel = 'http://schemas.openxmlformats.org/package/2006/relationships'
  }
}

# 914400 EMU to the inch, 1440 twips to the inch, so 635 EMU to the twip,
# and 360000 EMU to the centimetre. Both appear inline below.

function New-NsMgr {
  param([xml]$Doc)
  $m = New-Object System.Xml.XmlNamespaceManager $Doc.NameTable
  $map = Get-DocxNSMap
  foreach ($k in $map.Keys) { $m.AddNamespace($k, $map[$k]) }
  # XmlNamespaceManager is enumerable, so a bare return unrolls it into its
  # prefix strings. The comma keeps the object whole.
  return ,$m
}

function Expand-Docx {
  # Extracts a .docx into a working directory and returns that directory.
  param(
    [Parameter(Mandatory)][string]$Path,
    [string]$Dest
  )
  if (-not (Test-Path -LiteralPath $Path)) { throw "Document not found: $Path" }
  if (-not $Dest) {
    $Dest = Join-Path ([System.IO.Path]::GetTempPath()) ("docximg_" + [guid]::NewGuid().ToString('N'))
  }
  if (Test-Path -LiteralPath $Dest) { Remove-Item -LiteralPath $Dest -Recurse -Force }
  New-Item -ItemType Directory -Path $Dest -Force | Out-Null
  [System.IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path -LiteralPath $Path).Path, $Dest)
  return $Dest
}

function Compress-Docx {
  # Rezips a working directory back into a .docx, overwriting the target.
  param(
    [Parameter(Mandatory)][string]$Source,
    [Parameter(Mandatory)][string]$Path
  )
  $full = [System.IO.Path]::GetFullPath($Path)
  $dir  = Split-Path -Parent $full
  if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  if (Test-Path -LiteralPath $full) { Remove-Item -LiteralPath $full -Force }
  [System.IO.Compression.ZipFile]::CreateFromDirectory(
    (Resolve-Path -LiteralPath $Source).Path, $full,
    [System.IO.Compression.CompressionLevel]::Optimal, $false)
  return $full
}

function Get-ParagraphText {
  # Word splits a sentence across many runs. Read the paragraph, not the run.
  param([Parameter(Mandatory)][System.Xml.XmlNode]$Paragraph)
  $sb = New-Object System.Text.StringBuilder
  foreach ($n in $Paragraph.SelectNodes('.//*')) {
    switch ($n.LocalName) {
      't'   { [void]$sb.Append($n.InnerText) }
      'tab' { [void]$sb.Append(' ') }
      'br'  { [void]$sb.Append(' ') }
    }
  }
  # Word smart quotes and dashes defeat plain regex. Normalise for matching.
  $s = $sb.ToString()
  $s = $s -replace ([char]0x2018), "'"
  $s = $s -replace ([char]0x2019), "'"
  $s = $s -replace ([char]0x201C), '"'
  $s = $s -replace ([char]0x201D), '"'
  $s = $s -replace ([char]0x00A0), ' '
  return ($s -replace '\s+', ' ').Trim()
}

function Get-PngSize {
  <#  Width and height, straight out of the file header. No System.Drawing.

      PNG AND JPEG. It was PNG-only, which made the whole pipeline PNG-only -
      and this skill generates PHOTOGRAPHS, which are the one thing PNG is a
      poor container for. Seven generated PNGs made a 12 MB Word document that
      Word could not repaginate; the same pictures as JPEG come to 0.8 MB.
      Refusing JPEG forced the caller to ship the bloated file or hand-patch
      the library, so the format belongs here.  #>
  param([Parameter(Mandatory)][string]$Path)
  $b = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path).Path)
  if ($b.Length -lt 24) { throw "Not a readable image: $Path" }

  if ($b[0] -eq 0x89 -and $b[1] -eq 0x50 -and $b[2] -eq 0x4E -and $b[3] -eq 0x47) {
    $w = ([int]$b[16] -shl 24) -bor ([int]$b[17] -shl 16) -bor ([int]$b[18] -shl 8) -bor [int]$b[19]
    $h = ([int]$b[20] -shl 24) -bor ([int]$b[21] -shl 16) -bor ([int]$b[22] -shl 8) -bor [int]$b[23]
    return [pscustomobject]@{ Width = $w; Height = $h }
  }

  if ($b[0] -eq 0xFF -and $b[1] -eq 0xD8) {
    # Walk the marker segments to the first Start Of Frame, which carries the
    # dimensions. SOF0-SOF15 except the four that are not frame headers.
    $i = 2
    while ($i -lt ($b.Length - 9)) {
      if ($b[$i] -ne 0xFF) { $i++; continue }
      $marker = $b[$i + 1]
      if ($marker -eq 0xFF) { $i++; continue }
      if ($marker -eq 0xD8 -or $marker -eq 0x01 -or ($marker -ge 0xD0 -and $marker -le 0xD7)) { $i += 2; continue }
      $len = ([int]$b[$i + 2] -shl 8) -bor [int]$b[$i + 3]
      if (($marker -ge 0xC0 -and $marker -le 0xCF) -and
          $marker -ne 0xC4 -and $marker -ne 0xC8 -and $marker -ne 0xCC) {
        $h = ([int]$b[$i + 5] -shl 8) -bor [int]$b[$i + 6]
        $w = ([int]$b[$i + 7] -shl 8) -bor [int]$b[$i + 8]
        return [pscustomobject]@{ Width = $w; Height = $h }
      }
      $i += 2 + $len
    }
    throw "JPEG carries no Start Of Frame, so its size cannot be read: $Path"
  }

  throw "Only PNG and JPEG are supported here, and this file is neither: $Path"
}

function Get-PlacementWidthEmu {
  <#  The width a picture or diagram may occupy AT THE POINT IT IS PLACED.

      Section width is the right answer only in body prose. Inside a table cell
      it is wrong, and wrong in the direction that breaks the document: the
      assessment skill's recipe card puts its photo in a 4338 dxa cell inside a
      9638 dxa column, so sizing to the section makes the picture two and a half
      times its cell and bursts the table open in Word.

      Falls back to the section width whenever the cell cannot be resolved
      safely - a percentage or auto-width cell, or one with no tcW - because
      a guess here is a broken page, not a slightly wrong margin.  #>
  param(
    [Parameter(Mandatory)] $Paragraph,
    [Parameter(Mandatory)] $NsMgr,
    [Parameter(Mandatory)][int] $DefaultEmu
  )
  $wNs = (Get-DocxNSMap).w
  $n = $Paragraph.ParentNode
  while ($null -ne $n -and $n.LocalName -ne 'tc') { $n = $n.ParentNode }
  if ($null -eq $n) { return $DefaultEmu }

  $tcW = $n.SelectSingleNode('w:tcPr/w:tcW', $NsMgr)
  if ($null -eq $tcW) { return $DefaultEmu }
  $type = $tcW.GetAttribute('type', $wNs)
  if ($type -and $type -ne 'dxa') { return $DefaultEmu }
  $raw = $tcW.GetAttribute('w', $wNs)
  $dxa = 0
  if (-not [int]::TryParse($raw, [ref]$dxa) -or $dxa -le 0) { return $DefaultEmu }

  # Word's default cell margin is 108 dxa a side. Taking it off keeps the
  # picture inside the cell padding rather than flush against the rule.
  $dxa = $dxa - 216
  if ($dxa -lt 288) { return $DefaultEmu }   # implausibly narrow - do not trust it
  $emu = [int]($dxa * 635)
  if ($emu -gt $DefaultEmu) { return $DefaultEmu }
  return $emu
}

function Get-ContentWidthEmu {
  # Usable text width of the section: page width less both margins.
  # An image sized to this can never push the page sideways.
  param([Parameter(Mandatory)][xml]$DocXml)
  $ns = New-NsMgr $DocXml
  $sect = $DocXml.SelectSingleNode('//w:sectPr', $ns)
  $pgW = 11906; $mL = 1440; $mR = 1440   # A4 portrait, 1 inch margins, if the section is silent
  if ($sect) {
    $sz = $sect.SelectSingleNode('w:pgSz', $ns)
    $mg = $sect.SelectSingleNode('w:pgMar', $ns)
    if ($sz) {
      $v = $sz.GetAttribute('w', (Get-DocxNSMap).w); if ($v) { $pgW = [int]$v }
    }
    if ($mg) {
      $v = $mg.GetAttribute('left',  (Get-DocxNSMap).w); if ($v) { $mL = [int]$v }
      $v = $mg.GetAttribute('right', (Get-DocxNSMap).w); if ($v) { $mR = [int]$v }
    }
  }
  return ([int](($pgW - $mL - $mR) * 635))
}

function Add-DocxImagePart {
  # Copies the PNG into word/media, registers the relationship and the content
  # type, and hands back the r:embed id to point a drawing at.
  param(
    [Parameter(Mandatory)][string]$WorkDir,
    [Parameter(Mandatory)][string]$ImagePath
  )
  $mediaDir = Join-Path $WorkDir 'word\media'
  if (-not (Test-Path -LiteralPath $mediaDir)) { New-Item -ItemType Directory -Path $mediaDir -Force | Out-Null }

  # KEEP THE SOURCE FILE'S OWN EXTENSION. Naming every part .png regardless of
  # what it actually is writes JPEG bytes into a file Word is told is a PNG,
  # and Word reports the document as corrupt.
  $ext = ([System.IO.Path]::GetExtension($ImagePath)).ToLower()
  if ($ext -eq '.jpeg') { $ext = '.jpg' }
  if ($ext -notin @('.png', '.jpg')) { throw "Only PNG and JPEG can be embedded: $ImagePath" }
  $name = 'genimg_' + [guid]::NewGuid().ToString('N').Substring(0,12) + $ext
  Copy-Item -LiteralPath $ImagePath -Destination (Join-Path $mediaDir $name) -Force

  # [Content_Types].xml must know the extension or Word calls the file corrupt.
  $extBare = $ext.TrimStart('.')
  $mime    = $(if ($extBare -eq 'jpg') { 'image/jpeg' } else { 'image/png' })
  $ctPath = Join-Path $WorkDir '[Content_Types].xml'
  [xml]$ct = Get-Content -LiteralPath $ctPath -Raw -Encoding UTF8
  $has = $false
  foreach ($d in $ct.DocumentElement.ChildNodes) {
    if ($d.LocalName -eq 'Default' -and $d.GetAttribute('Extension') -eq $extBare) { $has = $true }
  }
  if (-not $has) {
    $d = $ct.CreateElement('Default', (Get-DocxNSMap).ct)
    $d.SetAttribute('Extension', $extBare)
    $d.SetAttribute('ContentType', $mime)
    [void]$ct.DocumentElement.AppendChild($d)
    $ct.Save($ctPath)
  }

  $relPath = Join-Path $WorkDir 'word\_rels\document.xml.rels'
  [xml]$rels = Get-Content -LiteralPath $relPath -Raw -Encoding UTF8
  $max = 0
  foreach ($x in $rels.DocumentElement.ChildNodes) {
    $id = $x.GetAttribute('Id')
    if ($id -match '^rId(\d+)$' -and [int]$Matches[1] -gt $max) { $max = [int]$Matches[1] }
  }
  $rid = 'rId' + ($max + 1)
  $e = $rels.CreateElement('Relationship', (Get-DocxNSMap).rel)
  $e.SetAttribute('Id', $rid)
  $e.SetAttribute('Type', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image')
  $e.SetAttribute('Target', "media/$name")
  [void]$rels.DocumentElement.AppendChild($e)
  $rels.Save($relPath)

  return [pscustomobject]@{ RelId = $rid; MediaName = $name }
}

function Get-NextDrawingId {
  # wp:docPr ids must be unique across the document or Word repairs the file.
  param([Parameter(Mandatory)][xml]$DocXml)
  $max = 0
  foreach ($n in $DocXml.SelectNodes('//*')) {
    if ($n.LocalName -eq 'docPr' -or $n.LocalName -eq 'cNvPr') {
      $v = $n.GetAttribute('id')
      if ($v -and $v -match '^\d+$' -and [int]$v -gt $max) { $max = [int]$v }
    }
  }
  return ($max + 1)
}

function ConvertTo-XmlText {
  param([string]$Text)
  if ($null -eq $Text) { return '' }
  $t = $Text -replace '&', '&amp;'
  $t = $t -replace '<', '&lt;'
  $t = $t -replace '>', '&gt;'
  $t = $t -replace '"', '&quot;'
  return $t
}

function New-InlinePictureParagraphXml {
  # One centred paragraph holding one inline picture, alt text attached.
  # Namespaces are declared on the paragraph itself so the fragment parses
  # standalone and the document root never has to be touched.
  param(
    [Parameter(Mandatory)][string]$RelId,
    [Parameter(Mandatory)][int]$Cx,
    [Parameter(Mandatory)][int]$Cy,
    [Parameter(Mandatory)][int]$Id,
    [string]$Alt = '',
    [string]$Name = 'Picture'
  )
  $altX  = ConvertTo-XmlText $Alt
  $nameX = ConvertTo-XmlText $Name
  $map = Get-DocxNSMap
  $xw = $map.w; $xr = $map.r; $xwp = $map.wp; $xa = $map.a; $xpic = $map.pic
  return @"
<w:p xmlns:w="$xw" xmlns:r="$xr" xmlns:wp="$xwp" xmlns:a="$xa" xmlns:pic="$xpic">
  <w:pPr><w:spacing w:before="120" w:after="120"/><w:jc w:val="center"/></w:pPr>
  <w:r>
    <w:drawing>
      <wp:inline distT="0" distB="0" distL="0" distR="0">
        <wp:extent cx="$Cx" cy="$Cy"/>
        <wp:effectExtent l="0" t="0" r="0" b="0"/>
        <wp:docPr id="$Id" name="$nameX" descr="$altX"/>
        <wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/></wp:cNvGraphicFramePr>
        <a:graphic>
          <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
            <pic:pic>
              <pic:nvPicPr>
                <pic:cNvPr id="$Id" name="$nameX" descr="$altX"/>
                <pic:cNvPicPr><a:picLocks noChangeAspect="1" noChangeArrowheads="1"/></pic:cNvPicPr>
              </pic:nvPicPr>
              <pic:blipFill>
                <a:blip r:embed="$RelId"/>
                <a:stretch><a:fillRect/></a:stretch>
              </pic:blipFill>
              <pic:spPr bwMode="auto">
                <a:xfrm><a:off x="0" y="0"/><a:ext cx="$Cx" cy="$Cy"/></a:xfrm>
                <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
              </pic:spPr>
            </pic:pic>
          </a:graphicData>
        </a:graphic>
      </wp:inline>
    </w:drawing>
  </w:r>
</w:p>
"@
}

function New-CaptionParagraphXml {
  # House style requires a caption or adjacent explanation on every
  # instructional image. This is that caption.
  param(
    [Parameter(Mandatory)][string]$Text,
    # 20 half-points = 10 pt. NOT 18. A 9 pt caption is below the accessibility
    # floor the calling house standards adopt, and a caption is instructional
    # text, not decoration - the assessment skill's FontFloor check blocks a
    # document over it.
    [int]$SizeHalfPt = 20
  )
  $t = ConvertTo-XmlText $Text
  $xw = (Get-DocxNSMap).w
  # CT_PPr CHILD ORDER IS FIXED BY THE SCHEMA: pStyle, keepNext, keepLines,
  # pageBreakBefore, numPr, spacing, ind, jc, outlineLvl. SPACING BEFORE JC.
  # Word tolerates the wrong order silently, so this shipped inverted and only
  # surfaced when a house-rules gate read the placed document.
  return @"
<w:p xmlns:w="$xw">
  <w:pPr><w:spacing w:before="0" w:after="180"/><w:jc w:val="center"/></w:pPr>
  <w:r>
    <w:rPr><w:i/><w:sz w:val="$SizeHalfPt"/><w:szCs w:val="$SizeHalfPt"/></w:rPr>
    <w:t xml:space="preserve">$t</w:t>
  </w:r>
</w:p>
"@
}

function Get-FittedExtent {
  # Scale the image to the column, never past it, and cap the height so a
  # single picture cannot eat a whole page.
  param(
    [Parameter(Mandatory)][int]$PixelWidth,
    [Parameter(Mandatory)][int]$PixelHeight,
    [Parameter(Mandatory)][int]$MaxWidthEmu,
    [double]$MaxHeightCm = 10.0,
    [double]$WidthFraction = 1.0
  )
  $targetW = [int]($MaxWidthEmu * $WidthFraction)
  $ratio   = $PixelHeight / [double]$PixelWidth
  $cx = $targetW
  $cy = [int]($cx * $ratio)
  $maxH = [int]($MaxHeightCm * 360000)
  if ($cy -gt $maxH) {
    $cy = $maxH
    $cx = [int]($cy / $ratio)
  }
  return [pscustomobject]@{ Cx = $cx; Cy = $cy }
}

function Set-XmlFragmentInPlace {
  # Replaces $Target with one or more sibling nodes built from XML strings.
  param(
    [Parameter(Mandatory)][xml]$Doc,
    [Parameter(Mandatory)][System.Xml.XmlNode]$Target,
    [Parameter(Mandatory)][string[]]$XmlFragments
  )
  $parent = $Target.ParentNode
  $anchor = $Target
  foreach ($frag in $XmlFragments) {
    $f = $Doc.CreateDocumentFragment()
    $f.InnerXml = $frag
    $nodes = @()
    foreach ($n in $f.ChildNodes) { $nodes += $n }
    foreach ($n in $nodes) {
      [void]$parent.InsertAfter($n, $anchor)
      $anchor = $n
    }
  }
  [void]$parent.RemoveChild($Target)
}
