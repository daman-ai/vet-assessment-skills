# Docx-DiagramLib.ps1
# Builds diagrams as NATIVE Word objects, never as pictures.
#
# Two renderers:
#   * canvas - a Word drawing canvas of real shapes and connectors. Every box
#     is clickable, every label is live text an assessor can retype.
#   * table  - a real Word table. Clickable, editable, searchable, and read
#     correctly by a screen reader. Preferred wherever the shape is a grid.
#
# Nothing here is rasterised and nothing here calls an API. A diagram costs
# nothing to make and nothing to fix.
#
# Dot-source this file. It defines functions only.

Set-StrictMode -Version Latest

function Get-DiagramNSMap {
  return @{
    w   = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
    r   = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
    wp  = 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing'
    a   = 'http://schemas.openxmlformats.org/drawingml/2006/main'
    wpc = 'http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas'
    wps = 'http://schemas.microsoft.com/office/word/2010/wordprocessingShape'
  }
}

function Get-Prop {
  # StrictMode makes a missing property fatal. This keeps a partial spec usable.
  param($Object, [string]$Name, $Default = $null)
  if ($null -eq $Object) { return $Default }
  if ($Object -is [hashtable]) {
    if ($Object.ContainsKey($Name)) { return $Object[$Name] }
    return $Default
  }
  $p = $Object.PSObject.Properties[$Name]
  if ($p -and $null -ne $p.Value -and "$($p.Value)" -ne '') { return $p.Value }
  return $Default
}

function Get-DiagramPalette {
  param($Config)
  $p = Get-Prop $Config 'palette' $null
  return @{
    navy   = (Get-Prop $p 'navy'   '234B8C')
    accent = (Get-Prop $p 'accent' '2F60B4')
    rule   = (Get-Prop $p 'rule'   'F09C0C')
    grey   = (Get-Prop $p 'grey'   '606060')
    light  = (Get-Prop $p 'light'  'F0F2F7')
    border = (Get-Prop $p 'border' 'C9CFDD')
    white  = 'FFFFFF'
  }
}

function Get-FillStyle {
  # Named fills, so a spec never carries a raw hex the house style did not sanction.
  param([string]$Name, $Palette)
  switch ("$Name".ToLower()) {
    'navy'   { return @{ Fill = $Palette.navy;   Line = $Palette.navy;   Text = $Palette.white; Bold = $true  } }
    'accent' { return @{ Fill = $Palette.accent; Line = $Palette.accent; Text = $Palette.white; Bold = $true  } }
    'orange' { return @{ Fill = $Palette.rule;   Line = $Palette.rule;   Text = $Palette.white; Bold = $true  } }
    'grey'   { return @{ Fill = $Palette.light;  Line = $Palette.grey;   Text = $Palette.grey;  Bold = $false } }
    'white'  { return @{ Fill = $Palette.white;  Line = $Palette.accent; Text = $Palette.navy;  Bold = $false } }
    default  { return @{ Fill = $Palette.light;  Line = $Palette.border; Text = $Palette.navy;  Bold = $false } }
  }
}

function Get-AutoFontHalfPt {
  # Long labels in a fixed box come out cramped. Step the size down instead of
  # letting Word clip. Floor is 8 pt, which is the house accessibility floor.
  param([string]$Text, [int]$BaseHalfPt = 20)
  $len = "$Text".Length
  if ($len -gt 60) { return [Math]::Max(16, $BaseHalfPt - 4) }
  if ($len -gt 38) { return [Math]::Max(16, $BaseHalfPt - 2) }
  return $BaseHalfPt
}

function ConvertTo-DiagramXmlText {
  param([string]$Text)
  if ($null -eq $Text) { return '' }
  $t = $Text -replace '&', '&amp;'
  $t = $t -replace '<', '&lt;'
  $t = $t -replace '>', '&gt;'
  $t = $t -replace '"', '&quot;'
  return $t
}

function New-ShapeTextXml {
  # The paragraph content of a shape's text box. A note line renders smaller
  # and lighter under the label.
  param(
    [string]$Text,
    [string]$Note,
    [string]$Colour,
    [bool]$Bold,
    [int]$HalfPt,
    [string]$Font = 'Arial'
  )
  $b = if ($Bold) { '<w:b/>' } else { '' }
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append('<w:p><w:pPr><w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/><w:jc w:val="center"/></w:pPr>')
  [void]$sb.Append('<w:r><w:rPr><w:rFonts w:ascii="' + $Font + '" w:hAnsi="' + $Font + '"/>' + $b)
  [void]$sb.Append('<w:color w:val="' + $Colour + '"/><w:sz w:val="' + $HalfPt + '"/><w:szCs w:val="' + $HalfPt + '"/></w:rPr>')
  [void]$sb.Append('<w:t xml:space="preserve">' + (ConvertTo-DiagramXmlText $Text) + '</w:t></w:r></w:p>')
  if ($Note) {
    $nHalf = [Math]::Max(16, $HalfPt - 4)
    [void]$sb.Append('<w:p><w:pPr><w:spacing w:before="20" w:after="0" w:line="240" w:lineRule="auto"/><w:jc w:val="center"/></w:pPr>')
    [void]$sb.Append('<w:r><w:rPr><w:rFonts w:ascii="' + $Font + '" w:hAnsi="' + $Font + '"/><w:i/>')
    [void]$sb.Append('<w:color w:val="' + $Colour + '"/><w:sz w:val="' + $nHalf + '"/><w:szCs w:val="' + $nHalf + '"/></w:rPr>')
    [void]$sb.Append('<w:t xml:space="preserve">' + (ConvertTo-DiagramXmlText $Note) + '</w:t></w:r></w:p>')
  }
  return $sb.ToString()
}

function New-BoxShapeXml {
  param(
    [Parameter(Mandatory)][int]$Id,
    [Parameter(Mandatory)][int]$X,
    [Parameter(Mandatory)][int]$Y,
    [Parameter(Mandatory)][int]$Cx,
    [Parameter(Mandatory)][int]$Cy,
    [string]$Text = '',
    [string]$Note = '',
    [string]$Geom = 'roundRect',
    [Parameter(Mandatory)]$Style,
    [int]$HalfPt = 20,
    [string]$Font = 'Arial'
  )
  $inner = New-ShapeTextXml -Text $Text -Note $Note -Colour $Style.Text -Bold $Style.Bold -HalfPt $HalfPt -Font $Font
  $nm = ConvertTo-DiagramXmlText ("Box {0}" -f $Id)
  return @"
<wps:wsp>
  <wps:cNvPr id="$Id" name="$nm"/>
  <wps:cNvSpPr/>
  <wps:spPr>
    <a:xfrm><a:off x="$X" y="$Y"/><a:ext cx="$Cx" cy="$Cy"/></a:xfrm>
    <a:prstGeom prst="$Geom"><a:avLst/></a:prstGeom>
    <a:solidFill><a:srgbClr val="$($Style.Fill)"/></a:solidFill>
    <a:ln w="12700"><a:solidFill><a:srgbClr val="$($Style.Line)"/></a:solidFill></a:ln>
  </wps:spPr>
  <wps:txbx><w:txbxContent>$inner</w:txbxContent></wps:txbx>
  <wps:bodyPr rot="0" spcFirstLastPara="0" vert="horz" wrap="square" lIns="72000" tIns="36000" rIns="72000" bIns="36000" anchor="ctr" anchorCtr="0">
    <a:noAutofit/>
  </wps:bodyPr>
</wps:wsp>
"@
}

function New-ConnectorXml {
  # Straight or elbow arrow between two points, anywhere on the canvas.
  # DrawingML stores a positive extent plus flip flags rather than a negative
  # one, so work out the box first and set the flips from the direction.
  param(
    [Parameter(Mandatory)][int]$Id,
    [Parameter(Mandatory)][int]$X1,
    [Parameter(Mandatory)][int]$Y1,
    [Parameter(Mandatory)][int]$X2,
    [Parameter(Mandatory)][int]$Y2,
    [string]$Colour = '606060',
    [string]$Geom = 'straightConnector1',
    [int]$Width = 19050
  )
  $x = [Math]::Min($X1, $X2)
  $y = [Math]::Min($Y1, $Y2)
  $cx = [Math]::Abs($X2 - $X1)
  $cy = [Math]::Abs($Y2 - $Y1)
  $flip = ''
  if ($X2 -lt $X1) { $flip += ' flipH="1"' }
  if ($Y2 -lt $Y1) { $flip += ' flipV="1"' }
  $nm = ConvertTo-DiagramXmlText ("Connector {0}" -f $Id)
  return @"
<wps:wsp>
  <wps:cNvPr id="$Id" name="$nm"/>
  <wps:cNvCnPr/>
  <wps:spPr>
    <a:xfrm$flip><a:off x="$x" y="$y"/><a:ext cx="$cx" cy="$cy"/></a:xfrm>
    <a:prstGeom prst="$Geom"><a:avLst/></a:prstGeom>
    <a:ln w="$Width">
      <a:solidFill><a:srgbClr val="$Colour"/></a:solidFill>
      <a:tailEnd type="triangle" w="med" len="med"/>
    </a:ln>
  </wps:spPr>
  <wps:bodyPr/>
</wps:wsp>
"@
}

function New-EdgeLabelXml {
  # A caption sitting on a connector: no fill, no outline, just the words.
  param(
    [Parameter(Mandatory)][int]$Id,
    [Parameter(Mandatory)][int]$X,
    [Parameter(Mandatory)][int]$Y,
    [Parameter(Mandatory)][int]$Cx,
    [Parameter(Mandatory)][int]$Cy,
    [Parameter(Mandatory)][string]$Text,
    [string]$Colour = '606060',
    [string]$Font = 'Arial'
  )
  $inner = New-ShapeTextXml -Text $Text -Note '' -Colour $Colour -Bold $false -HalfPt 16 -Font $Font
  $nm = ConvertTo-DiagramXmlText ("Label {0}" -f $Id)
  return @"
<wps:wsp>
  <wps:cNvPr id="$Id" name="$nm"/>
  <wps:cNvSpPr txBox="1"/>
  <wps:spPr>
    <a:xfrm><a:off x="$X" y="$Y"/><a:ext cx="$Cx" cy="$Cy"/></a:xfrm>
    <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
    <a:noFill/>
    <a:ln><a:noFill/></a:ln>
  </wps:spPr>
  <wps:txbx><w:txbxContent>$inner</w:txbxContent></wps:txbx>
  <wps:bodyPr rot="0" wrap="square" lIns="0" tIns="0" rIns="0" bIns="0" anchor="ctr" anchorCtr="0">
    <a:noAutofit/>
  </wps:bodyPr>
</wps:wsp>
"@
}

# ------------------------------------------------------------------ layouts
# Each returns a list of placed nodes, a list of {X1,Y1,X2,Y2,Geom,Label}
# connectors, and the canvas height. Everything is EMU.

function Get-ProcessLayout {
  param($Nodes, [int]$W, [string]$Orientation, [int]$Gap = 250000)
  $n = $Nodes.Count
  $placed = @(); $conns = @()
  if ($Orientation -eq 'vertical') {
    $boxW = [int]($W * 0.62)
    $boxH = 640000
    $x = [int](($W - $boxW) / 2)
    for ($i = 0; $i -lt $n; $i++) {
      $y = $i * ($boxH + $Gap)
      $placed += @{ Node = $Nodes[$i]; X = $x; Y = $y; Cx = $boxW; Cy = $boxH }
      if ($i -lt $n - 1) {
        $conns += @{ X1 = [int]($x + $boxW/2); Y1 = $y + $boxH; X2 = [int]($x + $boxW/2); Y2 = $y + $boxH + $Gap; Geom = 'straightConnector1' }
      }
    }
    $height = $n * $boxH + ($n - 1) * $Gap
  }
  else {
    # Floor the division and give the rounding remainder to the last box, or
    # [int] rounds up and the final box overhangs the column by a few EMU.
    $boxW = [int][Math]::Floor((($W - ($n - 1) * $Gap) / [double]$n))
    $boxH = 900000
    for ($i = 0; $i -lt $n; $i++) {
      $x = $i * ($boxW + $Gap)
      $cx = if ($i -eq $n - 1) { $W - $x } else { $boxW }
      $placed += @{ Node = $Nodes[$i]; X = $x; Y = 0; Cx = $cx; Cy = $boxH }
      if ($i -lt $n - 1) {
        $conns += @{ X1 = $x + $boxW; Y1 = [int]($boxH/2); X2 = $x + $boxW + $Gap; Y2 = [int]($boxH/2); Geom = 'straightConnector1' }
      }
    }
    $height = $boxH
  }
  return @{ Nodes = $placed; Connectors = $conns; Height = $height }
}

function Get-BandsLayout {
  # A single bar split into touching bands. No arrows: the bar is the message.
  param($Nodes, [int]$W)
  $n = $Nodes.Count
  $boxH = 900000
  $placed = @()
  $x = 0
  for ($i = 0; $i -lt $n; $i++) {
    $cx = [int]($W / $n)
    if ($i -eq $n - 1) { $cx = $W - $x }   # absorb the rounding into the last band
    $placed += @{ Node = $Nodes[$i]; X = $x; Y = 0; Cx = $cx; Cy = $boxH; Geom = 'rect' }
    $x += $cx
  }
  return @{ Nodes = $placed; Connectors = @(); Height = $boxH }
}

function Get-CycleLayout {
  param($Nodes, [int]$W)
  $n = $Nodes.Count
  $boxW = [int]($W * 0.26)
  $boxH = 640000
  # Cap the ring at 9.5 cm. Left to scale with the column it comes out over
  # 10 cm on A4 and pushes whatever follows onto the next page.
  $height = [Math]::Min([int]($W * 0.62), 3420000)
  $rx = [int](($W - $boxW) / 2)
  $ry = [int](($height - $boxH) / 2)
  $ccx = [int]($W / 2); $ccy = [int]($height / 2)
  $placed = @(); $centres = @()
  for ($i = 0; $i -lt $n; $i++) {
    $ang = (-[Math]::PI / 2) + (2 * [Math]::PI * $i / $n)   # start at twelve o'clock
    $cx = $ccx + [int]($rx * [Math]::Cos($ang))
    $cy = $ccy + [int]($ry * [Math]::Sin($ang))
    $placed += @{ Node = $Nodes[$i]; X = [int]($cx - $boxW/2); Y = [int]($cy - $boxH/2); Cx = $boxW; Cy = $boxH }
    $centres += @{ X = $cx; Y = $cy }
  }
  # Arrows run centre to centre, but start and stop where the line actually
  # leaves each box. Insetting by a flat distance instead leaves the arrows
  # floating in the middle, well short of the boxes they connect.
  $conns = @()
  $hw = $boxW / 2.0; $hh = $boxH / 2.0
  $margin = 80000
  for ($i = 0; $i -lt $n; $i++) {
    $a = $centres[$i]; $b = $centres[($i + 1) % $n]
    $dx = $b.X - $a.X; $dy = $b.Y - $a.Y
    $len = [Math]::Sqrt([double]($dx * $dx + $dy * $dy))
    if ($len -lt 1) { continue }
    $ux = $dx / $len; $uy = $dy / $len
    # Distance from centre to the rectangle edge along this direction.
    $tx = if ([Math]::Abs($ux) -gt 1e-9) { $hw / [Math]::Abs($ux) } else { [double]::MaxValue }
    $ty = if ([Math]::Abs($uy) -gt 1e-9) { $hh / [Math]::Abs($uy) } else { [double]::MaxValue }
    $t  = [Math]::Min($tx, $ty) + $margin
    if ($t * 2 -ge $len) { $t = $len / 2.5 }   # boxes almost touching
    $conns += @{
      X1 = [int]($a.X + $ux * $t); Y1 = [int]($a.Y + $uy * $t)
      X2 = [int]($b.X - $ux * $t); Y2 = [int]($b.Y - $uy * $t)
      Geom = 'straightConnector1'
    }
  }
  return @{ Nodes = $placed; Connectors = $conns; Height = $height }
}

function Get-HierarchyLayout {
  # Root on top, everything else in one row beneath it, elbow connectors down.
  param($Nodes, [int]$W, [int]$Gap = 200000)
  $root = $Nodes[0]
  $kids = @($Nodes | Select-Object -Skip 1)
  $k = [Math]::Max(1, $kids.Count)
  $boxH = 640000
  $vGap = 560000
  $rootW = [int]($W * 0.42)
  $rootX = [int](($W - $rootW) / 2)
  # Floor, then let the last child absorb the remainder, so the row ends
  # exactly on the column edge instead of a few EMU past it.
  $kidW  = [int][Math]::Floor((($W - ($k - 1) * $Gap) / [double]$k))

  $placed = @(@{ Node = $root; X = $rootX; Y = 0; Cx = $rootW; Cy = $boxH })
  $conns = @()
  $rootBottomX = [int]($rootX + $rootW / 2)
  for ($i = 0; $i -lt $kids.Count; $i++) {
    $x = $i * ($kidW + $Gap)
    $y = $boxH + $vGap
    $cxKid = if ($i -eq $kids.Count - 1) { $W - $x } else { $kidW }
    $placed += @{ Node = $kids[$i]; X = $x; Y = $y; Cx = $cxKid; Cy = $boxH }
    $conns += @{
      X1 = $rootBottomX; Y1 = $boxH
      X2 = [int]($x + $cxKid / 2); Y2 = $y
      Geom = 'bentConnector3'
    }
  }
  return @{ Nodes = $placed; Connectors = $conns; Height = ($boxH * 2 + $vGap) }
}

# ------------------------------------------------------------------ canvas

function New-DiagramCanvasXml {
  <#
    Renders a spec as a Word drawing canvas. Returns the <w:p> XML and the
    next free drawing id.
  #>
  param(
    [Parameter(Mandatory)]$Spec,
    [Parameter(Mandatory)][int]$WidthEmu,
    [Parameter(Mandatory)][int]$StartId,
    [string]$Alt = '',
    $Config = $null
  )
  $pal  = Get-DiagramPalette $Config
  $font = Get-Prop (Get-Prop $Config 'typography' $null) 'font' 'Arial'

  $nodes = @(Get-Prop $Spec 'nodes' @())
  if ($nodes.Count -lt 1) { throw 'A canvas diagram needs at least one node.' }
  $layout = "$(Get-Prop $Spec 'layout' 'process')".ToLower()
  $orient = "$(Get-Prop $Spec 'orientation' 'horizontal')".ToLower()

  switch ($layout) {
    'bands'     { $L = Get-BandsLayout     -Nodes $nodes -W $WidthEmu }
    'cycle'     { $L = Get-CycleLayout     -Nodes $nodes -W $WidthEmu }
    'hierarchy' { $L = Get-HierarchyLayout -Nodes $nodes -W $WidthEmu }
    default     { $L = Get-ProcessLayout   -Nodes $nodes -W $WidthEmu -Orientation $orient }
  }

  $id = $StartId
  $canvasId = $id; $id++

  $shapes = New-Object System.Text.StringBuilder

  # Connectors first, so the boxes sit on top of the arrow tails.
  foreach ($c in $L.Connectors) {
    [void]$shapes.Append((New-ConnectorXml -Id $id -X1 $c.X1 -Y1 $c.Y1 -X2 $c.X2 -Y2 $c.Y2 `
      -Colour $pal.grey -Geom $c.Geom))
    $id++
  }

  foreach ($p in $L.Nodes) {
    $node  = $p.Node
    $text  = "$(Get-Prop $node 'text' '')"
    $note  = "$(Get-Prop $node 'note' '')"
    $style = Get-FillStyle -Name (Get-Prop $node 'fill' 'light') -Palette $pal
    $geom  = if ($p.ContainsKey('Geom')) { $p.Geom } else { "$(Get-Prop $node 'shape' 'roundRect')" }
    $half  = Get-AutoFontHalfPt -Text ($text + $note)
    [void]$shapes.Append((New-BoxShapeXml -Id $id -X $p.X -Y $p.Y -Cx $p.Cx -Cy $p.Cy `
      -Text $text -Note $note -Geom $geom -Style $style -HalfPt $half -Font $font))
    $id++
  }

  # Edge labels, positioned at the midpoint of the connector they belong to.
  $edges = @(Get-Prop $Spec 'edges' @())
  $labelled = @($edges | Where-Object { (Get-Prop $_ 'label' '') })
  for ($e = 0; $e -lt $labelled.Count -and $e -lt $L.Connectors.Count; $e++) {
    $c = $L.Connectors[$e]
    $lw = 900000; $lh = 260000
    $mx = [int](($c.X1 + $c.X2) / 2 - $lw / 2)
    $my = [int](($c.Y1 + $c.Y2) / 2 - $lh)
    [void]$shapes.Append((New-EdgeLabelXml -Id $id -X $mx -Y $my -Cx $lw -Cy $lh `
      -Text "$(Get-Prop $labelled[$e] 'label' '')" -Colour $pal.grey -Font $font))
    $id++
  }

  $height = [int]$L.Height
  $altX   = ConvertTo-DiagramXmlText $Alt
  $ns     = Get-DiagramNSMap

  $xml = @"
<w:p xmlns:w="$($ns.w)" xmlns:r="$($ns.r)" xmlns:wp="$($ns.wp)" xmlns:a="$($ns.a)" xmlns:wpc="$($ns.wpc)" xmlns:wps="$($ns.wps)">
  <w:pPr><w:spacing w:before="120" w:after="120"/><w:jc w:val="center"/></w:pPr>
  <w:r>
    <w:drawing>
      <wp:inline distT="0" distB="0" distL="0" distR="0">
        <wp:extent cx="$WidthEmu" cy="$height"/>
        <wp:effectExtent l="0" t="0" r="0" b="0"/>
        <wp:docPr id="$canvasId" name="Diagram $canvasId" descr="$altX"/>
        <wp:cNvGraphicFramePr/>
        <a:graphic>
          <a:graphicData uri="$($ns.wpc)">
            <wpc:wpc>
              <wpc:bg/>
              <wpc:whole/>
              $($shapes.ToString())
            </wpc:wpc>
          </a:graphicData>
        </a:graphic>
      </wp:inline>
    </w:drawing>
  </w:r>
</w:p>
"@

  return @{ Xml = $xml; NextId = $id }
}

# ------------------------------------------------------------------- table

function New-DiagramTableXml {
  <#
    Renders a spec as a real Word table. The most robust diagram there is:
    editable, searchable, and read correctly by a screen reader. Use it for
    anything that is really a grid.
  #>
  param(
    [Parameter(Mandatory)]$Spec,
    [Parameter(Mandatory)][int]$WidthEmu,
    $Config = $null
  )
  $pal  = Get-DiagramPalette $Config
  $font = Get-Prop (Get-Prop $Config 'typography' $null) 'font' 'Arial'
  $half = [int](Get-Prop (Get-Prop $Config 'typography' $null) 'tableHalfPt' 20)

  $rows = @(Get-Prop $Spec 'rows' @())
  if ($rows.Count -lt 1) { throw 'A table diagram needs at least one row.' }
  $hasHeader = [bool](Get-Prop $Spec 'headerRow' $true)

  $cols = 0
  foreach ($r in $rows) { $cols = [Math]::Max($cols, @($r).Count) }
  if ($cols -lt 1) { throw 'A table diagram needs at least one column.' }

  # Word tables are laid out in twips, not EMU.
  $totalTw = [int]($WidthEmu / 635)
  $colTw   = [int]($totalTw / $cols)

  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append('<w:tbl xmlns:w="' + (Get-DiagramNSMap).w + '">')
  [void]$sb.Append('<w:tblPr><w:tblW w:w="' + $totalTw + '" w:type="dxa"/><w:jc w:val="center"/>')
  [void]$sb.Append('<w:tblBorders>')
  foreach ($side in @('top','left','bottom','right','insideH','insideV')) {
    [void]$sb.Append('<w:' + $side + ' w:val="single" w:sz="6" w:space="0" w:color="' + $pal.border + '"/>')
  }
  [void]$sb.Append('</w:tblBorders>')
  [void]$sb.Append('<w:tblCellMar><w:top w:w="80" w:type="dxa"/><w:left w:w="108" w:type="dxa"/><w:bottom w:w="80" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tblCellMar>')
  [void]$sb.Append('</w:tblPr><w:tblGrid>')
  for ($c = 0; $c -lt $cols; $c++) { [void]$sb.Append('<w:gridCol w:w="' + $colTw + '"/>') }
  [void]$sb.Append('</w:tblGrid>')

  for ($i = 0; $i -lt $rows.Count; $i++) {
    $cells = @($rows[$i])
    $isHeader = ($hasHeader -and $i -eq 0)
    [void]$sb.Append('<w:tr>')
    if ($isHeader) { [void]$sb.Append('<w:trPr><w:tblHeader/></w:trPr>') }
    for ($c = 0; $c -lt $cols; $c++) {
      $txt = if ($c -lt $cells.Count) { "$($cells[$c])" } else { '' }
      $shade = if ($isHeader) { $pal.navy } elseif ($i % 2 -eq 0) { $pal.light } else { 'FFFFFF' }
      $colour = if ($isHeader) { 'FFFFFF' } else { '000000' }
      $bold   = if ($isHeader) { '<w:b/>' } else { '' }
      [void]$sb.Append('<w:tc><w:tcPr><w:tcW w:w="' + $colTw + '" w:type="dxa"/>')
      [void]$sb.Append('<w:shd w:val="clear" w:color="auto" w:fill="' + $shade + '"/>')
      [void]$sb.Append('<w:vAlign w:val="center"/></w:tcPr>')
      [void]$sb.Append('<w:p><w:pPr><w:spacing w:before="20" w:after="20"/></w:pPr>')
      [void]$sb.Append('<w:r><w:rPr><w:rFonts w:ascii="' + $font + '" w:hAnsi="' + $font + '"/>' + $bold)
      [void]$sb.Append('<w:color w:val="' + $colour + '"/><w:sz w:val="' + $half + '"/><w:szCs w:val="' + $half + '"/></w:rPr>')
      [void]$sb.Append('<w:t xml:space="preserve">' + (ConvertTo-DiagramXmlText $txt) + '</w:t></w:r></w:p></w:tc>')
    }
    [void]$sb.Append('</w:tr>')
  }
  [void]$sb.Append('</w:tbl>')
  # A table cannot be the last thing before another table, and Word wants a
  # paragraph after one. Give it one.
  [void]$sb.Append('<w:p xmlns:w="' + (Get-DiagramNSMap).w + '"><w:pPr><w:spacing w:before="0" w:after="60"/></w:pPr></w:p>')
  return $sb.ToString()
}

function New-DiagramXml {
  <#
    Front door. Picks the renderer from the spec's layout and returns the
    fragments to drop in, plus the next free drawing id.
  #>
  param(
    [Parameter(Mandatory)]$Spec,
    [Parameter(Mandatory)][int]$WidthEmu,
    [Parameter(Mandatory)][int]$StartId,
    [string]$Alt = '',
    $Config = $null
  )
  $layout = "$(Get-Prop $Spec 'layout' 'process')".ToLower()
  if ($layout -in @('table','matrix','comparison')) {
    return @{ Xml = (New-DiagramTableXml -Spec $Spec -WidthEmu $WidthEmu -Config $Config); NextId = $StartId }
  }
  return (New-DiagramCanvasXml -Spec $Spec -WidthEmu $WidthEmu -StartId $StartId -Alt $Alt -Config $Config)
}
