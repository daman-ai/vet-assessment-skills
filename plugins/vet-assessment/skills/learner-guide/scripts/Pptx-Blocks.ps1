<#
    Pptx-Blocks.ps1

    THE DECK BUILDER. Clones slides out of the approved MVC PowerPoint template
    and fills their text, so the master, theme, fonts, logo, footer and every
    layout are INHERITED rather than re-created.

    WHY IT WORKS THIS WAY

    The MVC template is not a set of PowerPoint "layouts". It is a 13-slide
    LAYOUT LIBRARY - one worked exemplar per layout, each already carrying the
    logo, the footer, the accent stripe and the type ramp. The shipped
    SITHPAT018 deck was built exactly this way: its content slides are the
    template's slide 4 with the words swapped, shape for shape, name for name.
    So the build method is clone-and-fill, not generate-from-scratch.

    There is no python-pptx and no Node on this machine, and there does not need
    to be. A .pptx is a zip of XML; Expand-Docx / Compress-Docx from the
    assessment skill are format-agnostic zip operations and are reused as-is.

    ADDRESSING SHAPES

    Template shapes are named generically - "Text 1", "Text 5" - so names carry
    no meaning. Shapes are addressed by their ORDINAL among text-bearing shapes,
    and assets/deck-layouts.mvc.json maps a readable slot name (kicker, headline,
    lead, bullets) onto that ordinal per layout. Change the template and you
    change the map, in one place, rather than hunting through build code.

    FILLING TEXT

    Only the text is replaced. <a:bodyPr> and <a:lstStyle> are kept, and the
    template's own first <a:pPr>/<a:rPr> in that shape is reused as the
    prototype for every new paragraph - which is what makes an authored slide
    inherit the template's size, colour, font and bullet treatment instead of
    falling back to defaults.

    ASCII only in this file.
#>

# No Set-StrictMode - dot-sourced.

$script:PptNs = 'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"'

# Slide geometry, in EMU. 12192000 x 6858000 is 13.333in x 7.5in - the 16:9
# size the template declares in ppt/presentation.xml.
$script:SLIDE_W   = 12192000
$script:SLIDE_H   = 6858000
$script:MARGIN_L  = 502920

# Every shape this build ADDS carries this name prefix, so Get-SlideShape can
# keep it out of the template's text-shape ordinal sequence. See Get-SlideShape.
$script:LG_SHAPE_PREFIX = 'LG '

if (-not $script:Utf8NoBom) { $script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false) }

function ConvertTo-PptText {
    <# Escape for an <a:t> node. Ampersand first or the escapes escape. #>
    param([string] $Text)
    if ($null -eq $Text) { return '' }
    $Text.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
}


# ---------------------------------------------------------------------------
# Package-level: read the deck's own shape
# ---------------------------------------------------------------------------

function Get-DeckSlideOrder {
    <#  Slide part names in PRESENTATION order, not directory order.

        ppt/slides/ on disk sorts slide10 before slide2, and the r:id order in
        <p:sldIdLst> is the only thing that says what the audience actually
        sees. Every ordinal check - not least slide numbering - depends on
        reading it from here.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $WorkDir)

    $pres = Get-DocxPart -WorkDir $WorkDir -Part 'ppt/presentation.xml'
    $rels = Get-DocxPart -WorkDir $WorkDir -Part 'ppt/_rels/presentation.xml.rels'

    $map = @{}
    foreach ($m in [regex]::Matches($rels, 'Id="(rId\d+)"[^>]*Target="slides/(slide\d+\.xml)"')) {
        $map[$m.Groups[1].Value] = $m.Groups[2].Value
    }
    $order = New-Object System.Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($pres, '<p:sldId\s+id="\d+"\s+r:id="(rId\d+)"\s*/>')) {
        $id = $m.Groups[1].Value
        if ($map.ContainsKey($id)) { $order.Add($map[$id]) }
    }
    return $order
}

function Get-SlideShape {
    <#  Every <p:sp> in the slide, in document order, with its text.

        Returns objects carrying Index (position among ALL sp), TextIndex
        (position among text-bearing sp, 1-based, or 0), Start/Length into the
        raw XML, Name and Text. The template has no <p:grpSp> anywhere, so a
        non-greedy match cannot swallow a nested shape - verified across all 13
        template slides before this was written.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $SlideXml)

    $out = New-Object System.Collections.Generic.List[object]
    $i = 0; $t = 0
    foreach ($m in [regex]::Matches($SlideXml, '<p:sp>.*?</p:sp>', 'Singleline')) {
        $i++
        $s = $m.Value
        $name = if ($s -match '<p:cNvPr[^>]*name="([^"]*)"') { $Matches[1] } else { '' }

        # Shapes this build ADDED - the assessment chip and its rule - are
        # excluded from the text-shape ordinal sequence. The slot map in
        # deck-layouts.mvc.json numbers the TEMPLATE's shapes, so an appended
        # text-bearing shape shifts every ordinal after it: the chip became
        # ordinal 7 on the image layout and Set-DeckSlideNumbers duly wrote the
        # page number into the chip, leaving the real footer number stale.
        # Marking build-added shapes by name keeps the declared ordinals stable
        # however many shapes are appended.
        $hasText = ($s -match '<p:txBody>') -and ($name -notlike "$script:LG_SHAPE_PREFIX*")
        if ($hasText) { $t++ }
        $txt = @([regex]::Matches($s, '<a:t>([^<]*)</a:t>') | ForEach-Object { $_.Groups[1].Value })
        $out.Add([pscustomobject]@{
            Index     = $i
            TextIndex = if ($hasText) { $t } else { 0 }
            Start     = $m.Index
            Length    = $m.Length
            Name      = $name
            Text      = $txt
        })
    }
    return $out
}

function Get-SlideAllShape {
    <#  Every <p:sp> AND <p:pic> in document order.

        Get-SlideShape deliberately covers only <p:sp>, because text lives
        there. Picture placement needs a different view: the image placeholder
        is built from a frame, a circle, an icon PICTURE and a caption, and the
        icon is a <p:pic>. Counting only sp would mis-number everything after
        it, so this returns both, in the order PowerPoint draws them.

        Index here is the ALL-SHAPE ordinal used by imagePlaceholder in the
        deck profile.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $SlideXml)

    $out = New-Object System.Collections.Generic.List[object]
    $i = 0
    foreach ($m in [regex]::Matches($SlideXml, '<p:(sp|pic)>.*?</p:\1>', 'Singleline')) {
        $i++
        $name = if ($m.Value -match '<p:cNvPr[^>]*name="([^"]*)"') { $Matches[1] } else { '' }
        $out.Add([pscustomobject]@{
            Index  = $i
            Kind   = $m.Groups[1].Value
            Start  = $m.Index
            Length = $m.Length
            Name   = $name
            Xml    = $m.Value
        })
    }
    return $out
}

function Set-SlideShapeText {
    <#  Replace the text of ONE shape, addressed by its text-shape ordinal.

        -Lines is one paragraph per element. The shape's existing first <a:pPr>
        and first <a:rPr> are reused as the prototype for every emitted
        paragraph, so the result inherits the template's own formatting. A shape
        whose template content is a bullet list therefore stays a bullet list.

        Returns the updated slide XML. Throws if the ordinal does not exist -
        silently doing nothing is how a deck ships with a headline still reading
        "Headline statement for this slide".  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]   $SlideXml,
        [Parameter(Mandatory)][int]      $TextIndex,
        # AllowEmptyString as well as AllowEmptyCollection: clearing a slot is a
        # real instruction, not a mistake. A five-row agenda used for three
        # topics must be able to blank rows four and five, and without this the
        # binder rejects '' outright.
        [Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][string[]] $Lines
    )

    $shapes = Get-SlideShape -SlideXml $SlideXml
    $target = $shapes | Where-Object { $_.TextIndex -eq $TextIndex } | Select-Object -First 1
    if (-not $target) {
        throw "No text shape at ordinal $TextIndex (slide has $(($shapes | Where-Object { $_.TextIndex -gt 0 }).Count))."
    }

    $sp = $SlideXml.Substring($target.Start, $target.Length)

    $bodyStart = $sp.IndexOf('<p:txBody>')
    $bodyEnd   = $sp.IndexOf('</p:txBody>', $bodyStart)
    if ($bodyStart -lt 0 -or $bodyEnd -lt 0) { throw "Shape at ordinal $TextIndex has no txBody." }
    $body = $sp.Substring($bodyStart, $bodyEnd + 11 - $bodyStart)

    # Keep the shape's own bodyPr and lstStyle verbatim, and take the first
    # paragraph's pPr and the first run's rPr as prototypes - that is what makes
    # authored text inherit the template's size, colour, font and bullets.
    # Every one of these can contain children, so all four go through the
    # element scanner rather than a non-greedy regex.
    $bodyPr = Get-XmlFragment -Xml $body -Tag 'a:bodyPr';  if (-not $bodyPr) { $bodyPr = '<a:bodyPr/>' }
    $lstSty = Get-XmlFragment -Xml $body -Tag 'a:lstStyle'; if (-not $lstSty) { $lstSty = '<a:lstStyle/>' }

    $pPr = ''
    $firstP = Get-XmlFragment -Xml $body -Tag 'a:p'
    if ($firstP) { $pPr = Get-XmlFragment -Xml $firstP -Tag 'a:pPr'; if (-not $pPr) { $pPr = '' } }

    $rPr = Get-XmlFragment -Xml $body -Tag 'a:rPr'
    if (-not $rPr) { $rPr = '<a:rPr lang="en-AU" dirty="0"/>' }

    $paras = ''
    foreach ($line in $Lines) {
        $safe = ConvertTo-PptText $line
        if ($safe -eq '') { $paras += "<a:p>$pPr<a:endParaRPr lang=`"en-AU`"/></a:p>"; continue }
        $paras += "<a:p>$pPr<a:r>$rPr<a:t>$safe</a:t></a:r></a:p>"
    }
    if (-not $paras) { $paras = "<a:p>$pPr<a:endParaRPr lang=`"en-AU`"/></a:p>" }

    $newBody = "<p:txBody>$bodyPr$lstSty$paras</p:txBody>"
    $newSp   = $sp.Substring(0, $bodyStart) + $newBody + $sp.Substring($bodyEnd + 11)

    return $SlideXml.Substring(0, $target.Start) + $newSp + $SlideXml.Substring($target.Start + $target.Length)
}

function Set-SlideTableCell {
    <#  Fill a cell of the first <a:tbl> on the slide (the TABLE layout).

        Row and Column are 1-based, the header row being row 1. As with shape
        text, the cell's existing first <a:rPr> is reused so the header row
        keeps its white-on-navy treatment and body rows keep theirs.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $SlideXml,
        [Parameter(Mandatory)][int]    $Row,
        [Parameter(Mandatory)][int]    $Column,
        [Parameter(Mandatory)][AllowEmptyString()][string] $Text
    )

    $tblStart = $SlideXml.IndexOf('<a:tbl>')
    if ($tblStart -lt 0) { throw 'No table on this slide.' }
    $tblEnd = $SlideXml.IndexOf('</a:tbl>', $tblStart)
    $tbl    = $SlideXml.Substring($tblStart, $tblEnd + 8 - $tblStart)

    $rows = [regex]::Matches($tbl, '<a:tr\b.*?</a:tr>', 'Singleline')
    if ($Row -lt 1 -or $Row -gt $rows.Count) { throw "Row $Row out of range (table has $($rows.Count))." }
    $tr = $rows[$Row - 1]

    $cells = [regex]::Matches($tr.Value, '<a:tc\b.*?</a:tc>', 'Singleline')
    if ($Column -lt 1 -or $Column -gt $cells.Count) { throw "Column $Column out of range (row has $($cells.Count))." }
    $tc = $cells[$Column - 1]

    # Same element-scanner rule as Set-SlideShapeText: a cell's rPr carries the
    # header row's white-on-navy fill as a CHILD, so a non-greedy regex would
    # truncate it and corrupt the package.
    $rPr = Get-XmlFragment -Xml $tc.Value -Tag 'a:rPr'
    if (-not $rPr) { $rPr = '<a:rPr lang="en-AU" dirty="0"/>' }
    $pPr = ''
    $firstP = Get-XmlFragment -Xml $tc.Value -Tag 'a:p'
    if ($firstP) { $pPr = Get-XmlFragment -Xml $firstP -Tag 'a:pPr'; if (-not $pPr) { $pPr = '' } }

    $safe = ConvertTo-PptText $Text

    $newTxBody = if ($safe -eq '') {
        "<a:txBody><a:bodyPr/><a:lstStyle/><a:p>$pPr<a:endParaRPr lang=`"en-AU`"/></a:p></a:txBody>"
    } else {
        "<a:txBody><a:bodyPr/><a:lstStyle/><a:p>$pPr<a:r>$rPr<a:t>$safe</a:t></a:r></a:p></a:txBody>"
    }

    $oldBody = Get-XmlFragment -Xml $tc.Value -Tag 'a:txBody'
    if (-not $oldBody) { throw "Cell R$Row C$Column has no txBody." }
    $bi    = $tc.Value.IndexOf($oldBody)
    $tcNew = $tc.Value.Substring(0, $bi) + $newTxBody + $tc.Value.Substring($bi + $oldBody.Length)
    $trNew = $tr.Value.Substring(0, $cells[$Column - 1].Index) + $tcNew + $tr.Value.Substring($cells[$Column - 1].Index + $cells[$Column - 1].Length)
    $tblNew = $tbl.Substring(0, $rows[$Row - 1].Index) + $trNew + $tbl.Substring($rows[$Row - 1].Index + $rows[$Row - 1].Length)

    return $SlideXml.Substring(0, $tblStart) + $tblNew + $SlideXml.Substring($tblEnd + 8)
}

function Remove-SlideTableRow {
    <#  Delete one row from the slide's table, 1-based.

        The TABLE exemplar ships a header and four data rows. A cross-reference
        with two entries that simply fills two of them leaves "Row label three"
        and "Value / description" on the screen, so the spare rows are removed
        rather than left blank. Delete from the BOTTOM up when removing several,
        or the indices shift underneath you.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $SlideXml,
        [Parameter(Mandatory)][int]    $Row
    )

    $tbl = Get-XmlFragment -Xml $SlideXml -Tag 'a:tbl'
    if (-not $tbl) { throw 'No table on this slide.' }
    $ti = $SlideXml.IndexOf($tbl)

    $rows = [regex]::Matches($tbl, '<a:tr\b.*?</a:tr>', 'Singleline')
    if ($Row -lt 1 -or $Row -gt $rows.Count) { throw "Row $Row out of range (table has $($rows.Count))." }
    $r = $rows[$Row - 1]

    $tblNew = $tbl.Substring(0, $r.Index) + $tbl.Substring($r.Index + $r.Length)
    return $SlideXml.Substring(0, $ti) + $tblNew + $SlideXml.Substring($ti + $tbl.Length)
}

function Add-SlideChip {
    <#  The assessment-link chip.

        SECTION 4 of the delivery-PowerPoint spec requires every PC teaching
        slide to carry a visible pointer to the questions it prepares, in an MVC
        accent. The template ships no such shape, so this builds one: an orange
        left rule over a light fill, bottom-right, clear of the footer.

        Deliberately a real shape rather than a line of body text, so a trainer
        editing the slide cannot lose the reference by retyping a bullet.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $SlideXml,
        [Parameter(Mandatory)][string] $Text,
        [string] $Rule = 'F09C0C',
        [string] $Fill = 'F0F2F7',
        [string] $TextColor = '234B8C'
    )

    $w = 4114800          # 4.5in
    $h = 320040
    $x = $script:SLIDE_W - $script:MARGIN_L - $w
    $y = 5943600          # clear of the footer band at 6400800

    $safe = ConvertTo-PptText $Text
    $id   = 900 + ((Get-SlideShape -SlideXml $SlideXml).Count)

    $chip = @"
<p:sp><p:nvSpPr><p:cNvPr id="$id" name="LG Assessment Link Chip"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
<p:spPr><a:xfrm><a:off x="$x" y="$y"/><a:ext cx="$w" cy="$h"/></a:xfrm>
<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
<a:solidFill><a:srgbClr val="$Fill"/></a:solidFill>
<a:ln w="28575" cmpd="sng"><a:noFill/></a:ln></p:spPr>
<p:txBody><a:bodyPr wrap="square" lIns="118872" tIns="0" rIns="91440" bIns="0" rtlCol="0" anchor="ctr"/><a:lstStyle/>
<a:p><a:pPr marL="0" indent="0" algn="l"><a:buNone/></a:pPr>
<a:r><a:rPr lang="en-AU" sz="1100" b="1" dirty="0"><a:solidFill><a:srgbClr val="$TextColor"/></a:solidFill><a:latin typeface="Arial" pitchFamily="34" charset="0"/><a:cs typeface="Arial" pitchFamily="34" charset="0"/></a:rPr><a:t>$safe</a:t></a:r>
<a:endParaRPr lang="en-AU" sz="1100" dirty="0"/></a:p></p:txBody></p:sp>
<p:sp><p:nvSpPr><p:cNvPr id="$($id + 1)" name="LG Assessment Link Rule"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
<p:spPr><a:xfrm><a:off x="$x" y="$y"/><a:ext cx="45720" cy="$h"/></a:xfrm>
<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
<a:solidFill><a:srgbClr val="$Rule"/></a:solidFill><a:ln><a:noFill/></a:ln></p:spPr>
<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:endParaRPr lang="en-AU"/></a:p></p:txBody></p:sp>
"@

    $close = $SlideXml.LastIndexOf('</p:spTree>')
    if ($close -lt 0) { throw 'Malformed slide: no spTree close.' }
    return $SlideXml.Substring(0, $close) + $chip + $SlideXml.Substring($close)
}

# ---------------------------------------------------------------------------
# Deck assembly
# ---------------------------------------------------------------------------

function Set-SlidePicture {
    <#  Replace the IMAGE layout's grey placeholder with a real picture.

        The exemplar carries a rectangle reading "Replace with image". Left
        alone it ships to the classroom saying exactly that - and the deck
        gate's placeholder sweep fails it, correctly. This swaps the picture in
        at the placeholder's own position and size, so the layout is unchanged.

        REUSE THE GUIDE'S ARTWORK. Route A images cost money per generation,
        and a deck figure and its guide figure showing DIFFERENT pictures of the
        same thing is worse than either alone - the learner cannot tell whether
        the difference is meaningful. Point this at the PNG `docx-images`
        already produced for the corresponding guide figure; never generate a
        second one for the deck.

        -Fit 'cover' fills the placeholder and crops the overflow; 'contain'
        fits the whole picture inside it. Cover is right for photographs,
        contain for a diagram whose edges carry labels.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable] $Deck,
        [Parameter(Mandatory)][int]       $SlideNumber,
        [Parameter(Mandatory)][string]    $ImagePath,
        [Parameter(Mandatory)][int]       $FrameShape,      # all-shape ordinal of the grey frame
        [int[]]  $RemoveShapes,                             # all-shape ordinals to delete
        [int]    $CaptionShape = 0,                         # all-shape ordinal of the caption, to move below the frame
        [string] $AltText = '',
        [ValidateSet('cover', 'contain')][string] $Fit = 'cover'
    )

    if (-not (Test-Path -LiteralPath $ImagePath)) { throw "Picture not found: $ImagePath" }

    $part = "ppt/slides/slide$SlideNumber.xml"
    $xml  = Get-DocxPart -WorkDir $Deck.WorkDir -Part $part

    # The placeholder is FOUR shapes, not one: a grey frame, a navy circle, the
    # icon picture inside it, and a "Replace with image" caption. Swapping only
    # the caption leaves the frame and icon on the slide behind the picture, and
    # sizes the picture to the caption's thin strip. So the frame supplies the
    # geometry and every placeholder shape is removed. Ordinals are all-shape
    # (sp AND pic, in document order) and are declared per layout in the deck
    # profile under imagePlaceholder.
    $all = Get-SlideAllShape -SlideXml $xml
    $frame = $all | Where-Object { $_.Index -eq $FrameShape } | Select-Object -First 1
    if (-not $frame) { throw "No shape at ordinal $FrameShape on slide $SlideNumber - is this the image layout?" }

    $xf = [regex]::Match($frame.Xml, '<a:off x="(-?\d+)" y="(-?\d+)"/><a:ext cx="(\d+)" cy="(\d+)"/>')
    if (-not $xf.Success) { throw "Frame shape on slide $SlideNumber has no explicit position." }
    $x  = [int]$xf.Groups[1].Value; $y  = [int]$xf.Groups[2].Value
    $cx = [int]$xf.Groups[3].Value; $cy = [int]$xf.Groups[4].Value

    # Copy the picture into the package and give it a relationship.
    $ext   = [System.IO.Path]::GetExtension($ImagePath).TrimStart('.').ToLower()
    if ($ext -eq 'jpg') { $ext = 'jpeg' }
    $media = Join-Path $Deck.WorkDir 'ppt\media'
    if (-not (Test-Path -LiteralPath $media)) { New-Item -ItemType Directory -Path $media -Force | Out-Null }
    $name = "lgimage$SlideNumber`_$([Guid]::NewGuid().ToString('N').Substring(0,6)).$ext"
    Copy-Item -LiteralPath $ImagePath -Destination (Join-Path $media $name) -Force

    $relPart = "ppt/slides/_rels/slide$SlideNumber.xml.rels"
    $rels    = Get-DocxPart -WorkDir $Deck.WorkDir -Part $relPart
    $used    = @([regex]::Matches($rels, 'Id="rId(\d+)"') | ForEach-Object { [int]$_.Groups[1].Value })
    $rid     = 'rId' + $(if ($used.Count) { (($used | Measure-Object -Maximum).Maximum + 1) } else { 1 })
    $rels    = $rels.Replace('</Relationships>',
        "<Relationship Id=`"$rid`" Type=`"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image`" Target=`"../media/$name`"/></Relationships>")
    Set-DocxPart -WorkDir $Deck.WorkDir -Part $relPart -Content $rels

    # Declare the extension, or PowerPoint offers to repair the file.
    $ct = Get-DocxPart -WorkDir $Deck.WorkDir -Part '[Content_Types].xml'
    if ($ct -notmatch "Extension=`"$ext`"") {
        $mime = switch ($ext) { 'png' { 'image/png' } 'jpeg' { 'image/jpeg' } 'gif' { 'image/gif' } default { "image/$ext" } }
        $ct = $ct.Replace('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
              "<Types xmlns=`"http://schemas.openxmlformats.org/package/2006/content-types`"><Default Extension=`"$ext`" ContentType=`"$mime`"/>")
        Set-DocxPart -WorkDir $Deck.WorkDir -Part '[Content_Types].xml' -Content $ct
    }

    $fill = if ($Fit -eq 'cover') { '<a:srcRect/><a:stretch><a:fillRect/></a:stretch>' }
            else                  { '<a:stretch><a:fillRect/></a:stretch>' }

    $id  = 800 + $SlideNumber
    $alt = ConvertTo-PptText $AltText
    $pic = @"
<p:pic><p:nvPicPr><p:cNvPr id="$id" name="$script:LG_SHAPE_PREFIX`Figure $SlideNumber" descr="$alt"/><p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr>
<p:blipFill><a:blip r:embed="$rid"/>$fill</p:blipFill>
<p:spPr><a:xfrm><a:off x="$x" y="$y"/><a:ext cx="$cx" cy="$cy"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:pic>
"@

    # Delete the placeholder shapes from the BOTTOM UP, so removing one does not
    # shift the offsets of the ones still to go, then drop the picture in at the
    # frame's old position.
    # The template's caption sits INSIDE the grey box, as its "Replace with
    # image" label. Left there it prints on top of the photograph and is
    # unreadable. Move it just below the frame, where a figure caption belongs.
    if ($CaptionShape -gt 0) {
        $cap = $all | Where-Object { $_.Index -eq $CaptionShape } | Select-Object -First 1
        if ($cap) {
            $cxf = [regex]::Match($cap.Xml, '<a:off x="(-?\d+)" y="(-?\d+)"/><a:ext cx="(\d+)" cy="(\d+)"/>')
            if ($cxf.Success) {
                $capY   = $y + $cy + 45720          # a 0.05in gap under the frame
                $newXfm = '<a:off x="' + $x + '" y="' + $capY + '"/><a:ext cx="' + $cx + '" cy="' + $cxf.Groups[4].Value + '"/>'
                $newCap = $cap.Xml.Substring(0, $cxf.Index) + $newXfm +
                          $cap.Xml.Substring($cxf.Index + $cxf.Length)
                $xml = $xml.Substring(0, $cap.Start) + $newCap + $xml.Substring($cap.Start + $cap.Length)
                # Offsets moved, so re-read before deleting anything.
                $all   = Get-SlideAllShape -SlideXml $xml
                $frame = $all | Where-Object { $_.Index -eq $FrameShape } | Select-Object -First 1
            }
        }
    }

    $toRemove = @($RemoveShapes)
    if (-not $toRemove.Count) { $toRemove = @($FrameShape) }
    $targets = @($all | Where-Object { $toRemove -contains $_.Index } | Sort-Object Start -Descending)

    $insertAt = $frame.Start
    foreach ($r in $targets) {
        $xml = $xml.Substring(0, $r.Start) + $xml.Substring($r.Start + $r.Length)
        if ($r.Start -lt $insertAt) { $insertAt -= $r.Length }
    }
    $xml = $xml.Substring(0, $insertAt) + $pic + $xml.Substring($insertAt)

    Set-DocxPart -WorkDir $Deck.WorkDir -Part $part -Content $xml
    return $name
}

function New-Deck {
    <#  Open the template as a deck under construction.

        The 13 template slides are retained on disk as the LAYOUT BANK and are
        removed from <p:sldIdLst>, so the deck starts empty but every exemplar
        is still there to clone. They are deleted from the package only at
        Save-Deck, once nothing else needs them.

        Returns a state hashtable threaded through Add-DeckSlide.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $TemplatePath,
        [string] $WorkDir,
        # Written into docProps at Save-Deck. Leave them unset and the deck goes
        # out still claiming to be whoever's file the template was cloned from -
        # see the document-properties block in Save-Deck.
        [string] $Title,
        [string] $Subject,
        [string] $Owner
    )

    if (-not (Test-Path -LiteralPath $TemplatePath)) { throw "Deck template not found: $TemplatePath" }
    $wd = Expand-Docx -Path $TemplatePath -Destination $WorkDir

    $bank = @{}
    foreach ($n in (Get-DeckSlideOrder -WorkDir $wd)) {
        $idx = [int]([regex]::Match($n, '\d+').Value)
        $bank[$idx] = @{
            Xml  = Get-DocxPart -WorkDir $wd -Part "ppt/slides/$n"
            Rels = Get-DocxPart -WorkDir $wd -Part "ppt/slides/_rels/$n.rels"
        }
    }

    return @{
        WorkDir   = $wd
        Bank      = $bank
        BankParts = @(Get-DeckSlideOrder -WorkDir $wd)
        Slides    = New-Object System.Collections.Generic.List[object]
        NextId    = 1000
        Title     = $Title
        Subject   = $Subject
        Owner     = $Owner
    }
}

function Add-DeckSlide {
    <#  Clone one layout exemplar, fill it, and append it to the deck.

        -Layout is a template slide NUMBER (1-13); the caller resolves a
        readable layout name to that number through deck-layouts.mvc.json.
        -Slots maps text-shape ordinal -> string or string[].

        The clone's notesSlide relationship is always stripped. The template's
        exemplars each carry one, and leaving it attached makes every authored
        slide in the deck point at the same placeholder note.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable] $Deck,
        [Parameter(Mandatory)][int]       $Layout,
        [hashtable] $Slots,
        [string]    $Notes,
        [string]    $Chip,
        [string]    $Tag
    )

    if (-not $Deck.Bank.ContainsKey($Layout)) { throw "No layout exemplar at template slide $Layout." }

    $xml  = $Deck.Bank[$Layout].Xml
    $rels = $Deck.Bank[$Layout].Rels

    if ($Slots) {
        foreach ($k in ($Slots.Keys | Sort-Object { [int]$_ })) {
            $v = $Slots[$k]
            $lines = if ($v -is [array]) { [string[]]$v } else { [string[]]@("$v") }
            $xml = Set-SlideShapeText -SlideXml $xml -TextIndex ([int]$k) -Lines $lines
        }
    }
    if ($Chip) { $xml = Add-SlideChip -SlideXml $xml -Text $Chip }

    # Strip the exemplar's notes relationship; ours is added below if wanted.
    $rels = [regex]::Replace($rels, '<Relationship[^>]*notesSlide[^>]*/>', '')

    $n    = $Deck.Slides.Count + 1
    $part = "slide$n.xml"

    Set-DocxPart -WorkDir $Deck.WorkDir -Part "ppt/slides/$part"            -Content $xml
    Set-DocxPart -WorkDir $Deck.WorkDir -Part "ppt/slides/_rels/$part.rels" -Content $rels

    $Deck.Slides.Add([pscustomobject]@{
        Part   = $part
        Layout = $Layout
        Tag    = $Tag
        Notes  = $Notes
        Chip   = $Chip
    })

    if ($Notes) { Set-SlideNotes -Deck $Deck -SlideNumber $n -Notes $Notes }
    return $n
}

function Set-SlideNotes {
    <#  Write a speaker-notes part for one authored slide and wire it both ways.

        Built from the template's own notesSlide shape - slide-image
        placeholder, body placeholder, slide-number field - so the notes page
        prints the way the template's do.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable] $Deck,
        [Parameter(Mandatory)][int]       $SlideNumber,
        [Parameter(Mandatory)][string]    $Notes
    )

    $paras = ''
    foreach ($line in ($Notes -split "`r?`n")) {
        $safe = ConvertTo-PptText $line
        $paras += "<a:p><a:r><a:rPr lang=`"en-AU`" dirty=`"0`"/><a:t>$safe</a:t></a:r></a:p>"
    }

    $xml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:notes $script:PptNs><p:cSld><p:spTree>
<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
<p:sp><p:nvSpPr><p:cNvPr id="2" name="Slide Image Placeholder 1"/><p:cNvSpPr><a:spLocks noGrp="1" noRot="1" noChangeAspect="1"/></p:cNvSpPr><p:nvPr><p:ph type="sldImg"/></p:nvPr></p:nvSpPr><p:spPr/></p:sp>
<p:sp><p:nvSpPr><p:cNvPr id="3" name="Notes Placeholder 2"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr><p:ph type="body" idx="1"/></p:nvPr></p:nvSpPr><p:spPr/>
<p:txBody><a:bodyPr/><a:lstStyle/>$paras</p:txBody></p:sp>
<p:sp><p:nvSpPr><p:cNvPr id="4" name="Slide Number Placeholder 3"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr><p:ph type="sldNum" sz="quarter" idx="10"/></p:nvPr></p:nvSpPr><p:spPr/>
<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:fld id="{F7021451-1387-4CA6-816F-3879F97B5CBC}" type="slidenum"><a:rPr lang="en-AU"/><a:t>$SlideNumber</a:t></a:fld><a:endParaRPr lang="en-AU"/></a:p></p:txBody></p:sp>
</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:notes>
"@

    $notesPart = "notesSlide$SlideNumber.xml"
    Set-DocxPart -WorkDir $Deck.WorkDir -Part "ppt/notesSlides/$notesPart" -Content $xml
    Set-DocxPart -WorkDir $Deck.WorkDir -Part "ppt/notesSlides/_rels/$notesPart.rels" -Content @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesMaster" Target="../notesMasters/notesMaster1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="../slides/slide$SlideNumber.xml"/></Relationships>
"@

    # Point the slide at its notes, with a relationship id that cannot collide
    # with the ones cloned from the exemplar.
    $sr = Get-DocxPart -WorkDir $Deck.WorkDir -Part "ppt/slides/_rels/slide$SlideNumber.xml.rels"
    if ($sr -notmatch 'notesSlide') {
        $used = @([regex]::Matches($sr, 'Id="rId(\d+)"') | ForEach-Object { [int]$_.Groups[1].Value })
        $next = 1; if ($used.Count) { $next = (($used | Measure-Object -Maximum).Maximum + 1) }
        $sr = $sr.Replace('</Relationships>', "<Relationship Id=`"rId$next`" Type=`"http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesSlide`" Target=`"../notesSlides/$notesPart`"/></Relationships>")
        Set-DocxPart -WorkDir $Deck.WorkDir -Part "ppt/slides/_rels/slide$SlideNumber.xml.rels" -Content $sr
    }
}

function Set-DeckSlideNumbers {
    <#  Print each slide's real deck position in its footer number shape.

        This is not cosmetic. The template's footer number is LITERAL TEXT, not
        a slidenum field, so a cloned slide keeps the exemplar's number: the
        shipped SITHPAT018 deck prints the wrong number on 19 of its 39 slides.
        Cloning without renumbering reproduces that defect exactly.

        Which shape holds the number is declared per layout in
        deck-layouts.mvc.json as numberSlot, because it is not always the last
        text shape and two layouts (title, thank-you) legitimately have none.
        Guessing instead of declaring is what turns a correct thank-you slide
        into a reported defect.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable] $Deck,
        [hashtable] $NumberSlotByLayout
    )

    $changed = 0; $none = 0; $skipped = @()
    for ($i = 0; $i -lt $Deck.Slides.Count; $i++) {
        $n    = $i + 1
        $rec  = $Deck.Slides[$i]
        $part = "ppt/slides/$($rec.Part)"
        $xml  = Get-DocxPart -WorkDir $Deck.WorkDir -Part $part

        $slot = $null
        if ($NumberSlotByLayout -and $NumberSlotByLayout.ContainsKey($rec.Layout)) {
            $slot = [int]$NumberSlotByLayout[$rec.Layout]
        }

        if ($null -eq $slot) {
            # Undeclared layout: fall back to the last text shape, and only when
            # it still looks like a page number.
            $textShapes = @(Get-SlideShape -SlideXml $xml | Where-Object { $_.TextIndex -gt 0 })
            if (-not $textShapes.Count) { continue }
            $last = $textShapes[-1]
            if (($last.Text -join '').Trim() -notmatch '^\d+$') { $skipped += "slide $n ($($rec.Tag))"; continue }
            $slot = $last.TextIndex
        }

        if ($slot -le 0) { $none++; continue }   # layout carries no page number

        # Name the slide in any failure. A bare binder error from deep in this
        # loop gives no clue which of ninety slides is wrong.
        try {
            $xml = Set-SlideShapeText -SlideXml $xml -TextIndex $slot -Lines @("$n")
        }
        catch {
            throw "Numbering slide $n (layout $($rec.Layout), tag '$($rec.Tag)') at slot ${slot}: $($_.Exception.Message)"
        }
        Set-DocxPart -WorkDir $Deck.WorkDir -Part $part -Content $xml
        $changed++
    }
    return [pscustomobject]@{ Numbered = $changed; NoNumberByDesign = $none; Skipped = $skipped }
}

# ---------------------------------------------------------------------------
# Profile-aware layer - readable layout and slot NAMES instead of ordinals
# ---------------------------------------------------------------------------

function Get-DeckProfile {
    <# Load assets/deck-layouts.<brand>.json. #>
    [CmdletBinding()]
    param(
        [string] $SkillDir = $PSScriptRoot,
        [string] $Brand = 'mvc'
    )
    $root = Split-Path -Parent $SkillDir
    $p    = Join-Path $root "assets\deck-layouts.$($Brand.ToLower()).json"
    if (-not (Test-Path -LiteralPath $p)) { throw "No deck profile for brand '$Brand': $p" }
    return (Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Get-DeckNumberSlotMap {
    <# layout template-slide-number -> numberSlot, for Set-DeckSlideNumbers. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Profile)
    $map = @{}
    foreach ($p in $Profile.layouts.PSObject.Properties) {
        $map[[int]$p.Value.slide] = [int]$p.Value.numberSlot
    }
    return $map
}

function New-DeckSlide {
    <#  Add a slide by LAYOUT NAME with NAMED slots.

        This is the function a build should call. It resolves the layout name
        and each slot name through the profile, so build code reads
        'headline' / 'bullets' rather than 4 / 5 and a template change is a
        one-line edit to the profile.

        Unknown slot names throw rather than being ignored - a typo that
        silently leaves 'Headline statement for this slide' on a delivered
        slide is the failure this prevents.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable] $Deck,
        [Parameter(Mandatory)]            $Profile,
        [Parameter(Mandatory)][string]    $Layout,
        [hashtable] $Content,
        [string]    $Notes,
        [string]    $Chip,
        [string]    $Tag
    )

    $lay = $Profile.layouts.PSObject.Properties | Where-Object { $_.Name -eq $Layout } | Select-Object -First 1
    if (-not $lay) { throw "Unknown layout '$Layout'. Known: $(($Profile.layouts.PSObject.Properties | ForEach-Object { $_.Name }) -join ', ')" }
    $def = $lay.Value

    $slots = @{}
    if ($Content) {
        foreach ($k in $Content.Keys) {
            $sp = $def.slots.PSObject.Properties | Where-Object { $_.Name -eq $k } | Select-Object -First 1
            if (-not $sp) { throw "Layout '$Layout' has no slot '$k'. Known: $(($def.slots.PSObject.Properties | ForEach-Object { $_.Name }) -join ', ')" }
            $slots[[int]$sp.Value] = $Content[$k]
        }
    }

    return (Add-DeckSlide -Deck $Deck -Layout ([int]$def.slide) -Slots $slots -Notes $Notes -Chip $Chip -Tag $Tag)
}

function Save-Deck {
    <#  Rewire the package to the authored slides and write the .pptx.

        Rebuilds <p:sldIdLst>, presentation.xml.rels and [Content_Types].xml
        from the authored list, drops every unused layout exemplar and its
        orphaned notes, then repacks.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable] $Deck,
        [Parameter(Mandatory)][string]    $Path,
        [switch] $KeepBrandReference
    )

    if (-not $Deck.Slides.Count) { throw 'Refusing to save a deck with no slides.' }

    $wd = $Deck.WorkDir

    # --- presentation.xml.rels: keep every non-slide relationship, renumber slides
    $rels    = Get-DocxPart -WorkDir $wd -Part 'ppt/_rels/presentation.xml.rels'
    $keep    = @()
    foreach ($m in [regex]::Matches($rels, '<Relationship\b[^>]*/>')) {
        if ($m.Value -notmatch '/relationships/slide"') { $keep += $m.Value }
    }
    # Renumber retained relationships so authored slides can take a clean block.
    $used = @([regex]::Matches(($keep -join ''), 'Id="rId(\d+)"') | ForEach-Object { [int]$_.Groups[1].Value })
    $next = 1; if ($used.Count) { $next = (($used | Measure-Object -Maximum).Maximum + 1) }

    $slideRels = ''; $sldIds = ''; $sldId = 256
    for ($i = 0; $i -lt $Deck.Slides.Count; $i++) {
        $rid = "rId$($next + $i)"
        $slideRels += "<Relationship Id=`"$rid`" Type=`"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide`" Target=`"slides/$($Deck.Slides[$i].Part)`"/>"
        $sldIds    += "<p:sldId id=`"$sldId`" r:id=`"$rid`"/>"
        $sldId++
    }

    Set-DocxPart -WorkDir $wd -Part 'ppt/_rels/presentation.xml.rels' -Content (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
        ($keep -join '') + $slideRels + '</Relationships>')

    # --- presentation.xml: swap the slide id list
    $pres = Get-DocxPart -WorkDir $wd -Part 'ppt/presentation.xml'
    $pres = [regex]::Replace($pres, '(?s)<p:sldIdLst>.*?</p:sldIdLst>', "<p:sldIdLst>$sldIds</p:sldIdLst>")
    Set-DocxPart -WorkDir $wd -Part 'ppt/presentation.xml' -Content $pres

    # --- drop unused exemplars and orphaned notes
    $authored = @($Deck.Slides | ForEach-Object { $_.Part })
    foreach ($p in $Deck.BankParts) {
        if ($authored -contains $p) { continue }
        foreach ($f in @("ppt/slides/$p", "ppt/slides/_rels/$p.rels")) {
            $fp = Join-Path $wd ($f -replace '/', '\')
            if (Test-Path -LiteralPath $fp) { Remove-Item -LiteralPath $fp -Force }
        }
    }
    $liveNotes = @($Deck.Slides | Where-Object { $_.Notes } | ForEach-Object { "notesSlide$($Deck.Slides.IndexOf($_) + 1).xml" })
    Get-ChildItem (Join-Path $wd 'ppt\notesSlides') -Filter *.xml -File -ErrorAction SilentlyContinue | ForEach-Object {
        if ($liveNotes -notcontains $_.Name) {
            Remove-Item $_.FullName -Force
            $r = Join-Path $wd "ppt\notesSlides\_rels\$($_.Name).rels"
            if (Test-Path -LiteralPath $r) { Remove-Item -LiteralPath $r -Force }
        }
    }

    # --- [Content_Types].xml: one override per surviving part
    $ct = Get-DocxPart -WorkDir $wd -Part '[Content_Types].xml'
    $ct = [regex]::Replace($ct, '<Override[^>]*PartName="/ppt/(slides|notesSlides)/[^"]*"[^>]*/>', '')
    $ov = ''
    foreach ($s in $authored) {
        $ov += "<Override PartName=`"/ppt/slides/$s`" ContentType=`"application/vnd.openxmlformats-officedocument.presentationml.slide+xml`"/>"
    }
    foreach ($n in $liveNotes) {
        $ov += "<Override PartName=`"/ppt/notesSlides/$n`" ContentType=`"application/vnd.openxmlformats-officedocument.presentationml.notesSlide+xml`"/>"
    }
    $ct = $ct.Replace('</Types>', $ov + '</Types>')
    Set-DocxPart -WorkDir $wd -Part '[Content_Types].xml' -Content $ct

    # --- document properties
    #
    # THE TEMPLATE IS SOMEBODY ELSE'S FILE UNTIL THIS RUNS. The approved MVC
    # deck template was made by cloning another RTO's, and it still carries that
    # RTO's registered identity in docProps: title "ACI Branded PowerPoint
    # Template", subject "RTO 45797 | CRICOS 03978F", creator "Adelaide
    # Construction Institute". None of it appears on a slide, so every visual
    # check and every structural gate passes - but it shows in File > Info, in
    # Explorer's Details pane, and in the metadata of any PDF exported from it.
    # A student-facing, auditor-facing MVC resource asserting a competitor's RTO
    # and CRICOS number is not defensible, and it shipped once already.
    #
    # app.xml is stamped for the same reason plus a second one: it is cloned
    # from a 13-slide template and goes on claiming 13 slides however many are
    # authored.
    $owner = "$($Deck.Owner)"
    $core  = Get-DocxPart -WorkDir $wd -Part 'docProps/core.xml'
    $meta  = [ordered]@{
        'dc:title'          = $(if ($Deck.Title) { "$($Deck.Title)" } else { 'Delivery PowerPoint' })
        'dc:subject'        = "$($Deck.Subject)"
        'dc:creator'        = $owner
        'cp:lastModifiedBy' = $owner
    }
    foreach ($k in $meta.Keys) {
        $v = ConvertTo-XmlText $meta[$k]
        if ($core -match "<$k>.*?</$k>") {
            $core = [regex]::Replace($core, "<$k>.*?</$k>", "<$k>$v</$k>", 'Singleline')
        } elseif ($v) {
            $core = $core -replace '</cp:coreProperties>', "<$k>$v</$k></cp:coreProperties>"
        }
    }
    Set-DocxPart -WorkDir $wd -Part 'docProps/core.xml' -Content $core

    $app = Get-DocxPart -WorkDir $wd -Part 'docProps/app.xml'
    $app = [regex]::Replace($app, '<Slides>\d+</Slides>', "<Slides>$($Deck.Slides.Count)</Slides>")
    $app = [regex]::Replace($app, '<Notes>\d+</Notes>',   "<Notes>$(@($liveNotes).Count)</Notes>")
    foreach ($t in @('Company', 'Manager')) {
        $app = [regex]::Replace($app, "<$t>.*?</$t>", "<$t>$(ConvertTo-XmlText $owner)</$t>", 'Singleline')
    }
    Set-DocxPart -WorkDir $wd -Part 'docProps/app.xml' -Content $app

    # Gate BEFORE writing. A corrupt package that reaches disk gets opened,
    # refused by PowerPoint, and then debugged from the wrong end.
    $chk = Test-PptxPackage -WorkDir $wd
    if (-not $chk.Ok) {
        throw "Refusing to save a broken deck:`n  " + ($chk.Issues -join "`n  ")
    }

    return (Compress-Docx -WorkDir $wd -Path $Path)
}

function Test-PptxPackage {
    <#  Structural check before anyone opens the file.

        Confirms every part is WELL-FORMED XML, every slide referenced by
        presentation.xml exists, every slide has a rels part naming a layout,
        every notes part is reachable, and that [Content_Types].xml declares
        each one.

        The well-formedness sweep is first and is not optional. Splicing raw
        OOXML as text is the whole build method, and an unbalanced element is
        the failure it produces - PowerPoint reports it only as "the file is
        corrupted and unreadable", which names neither the part nor the tag.
        A missing content-type override is the other common cause of the
        repair prompt.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $WorkDir)

    $issues = New-Object System.Collections.Generic.List[string]

    # Filter by extension explicitly. -Include is silently ignored alongside
    # -LiteralPath in Windows PowerShell 5.1, which drags every PNG in ppt/media
    # into the sweep and reports the whole deck as malformed.
    $xmlParts = Get-ChildItem -LiteralPath $WorkDir -Recurse -File |
                Where-Object { $_.Extension -eq '.xml' -or $_.Extension -eq '.rels' }

    foreach ($f in $xmlParts) {
        $doc = New-Object System.Xml.XmlDocument
        try { $doc.Load($f.FullName) }
        catch {
            $reason = $_.Exception.Message
            if ($_.Exception.InnerException) { $reason = $_.Exception.InnerException.Message }
            $issues.Add("malformed XML in $($f.FullName.Substring($WorkDir.Length + 1)): $reason")
        }
    }

    $order = Get-DeckSlideOrder -WorkDir $WorkDir
    if (-not $order.Count) { $issues.Add('presentation.xml lists no slides.') }

    $ct = Get-DocxPart -WorkDir $WorkDir -Part '[Content_Types].xml'
    foreach ($p in $order) {
        if (-not (Test-Path -LiteralPath (Join-Path $WorkDir "ppt\slides\$p")))            { $issues.Add("missing slide part: $p") }
        if (-not (Test-Path -LiteralPath (Join-Path $WorkDir "ppt\slides\_rels\$p.rels"))) { $issues.Add("missing rels for: $p") }
        if ($ct -notmatch [regex]::Escape("/ppt/slides/$p"))                               { $issues.Add("no content-type override: $p") }
        else {
            $r = Get-DocxPart -WorkDir $WorkDir -Part "ppt/slides/_rels/$p.rels"
            if ($r -notmatch 'slideLayout') { $issues.Add("slide has no layout relationship: $p") }
            foreach ($m in [regex]::Matches($r, 'Target="\.\./(notesSlides/[^"]+)"')) {
                if (-not (Test-Path -LiteralPath (Join-Path $WorkDir ("ppt\" + ($m.Groups[1].Value -replace '/', '\'))))) {
                    $issues.Add("$p points at a missing notes part: $($m.Groups[1].Value)")
                }
            }
        }
    }
    foreach ($f in (Get-ChildItem (Join-Path $WorkDir 'ppt\notesSlides') -Filter *.xml -File -ErrorAction SilentlyContinue)) {
        if ($ct -notmatch [regex]::Escape("/ppt/notesSlides/$($f.Name)")) { $issues.Add("no content-type override: $($f.Name)") }
    }

    return [pscustomobject]@{ Ok = ($issues.Count -eq 0); Issues = $issues; SlideCount = $order.Count }
}
