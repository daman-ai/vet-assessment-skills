<#
    Build-Guide.ps1

    THE GUIDE ASSEMBLER. Splices authored body OOXML into the approved MVC
    Learner Guide template, the same way the assessment skill splices a UAT into
    its own template: unpack a FRESH copy, cut at the template's seam, drop the
    body in, repack.

    WHAT IS KEPT AND WHAT IS AUTHORED

    The template's front matter is approved and survives untouched - the cover
    lock-up, the Acknowledgement of Country, the Contents field, "How to use
    this guide" and the twelve-row icon legend. Authoring starts at the "Unit
    overview" heading and runs to the closing section properties.

    Everything after the seam in the template - the Topic 1 skeleton, the
    callout box library, the appendix stubs - is SCAFFOLDING. It is there to be
    copied from, not shipped, and the splice drops it.

    CALLOUTS

    A callout is a single full-width shaded cell with a thick coloured LEFT
    border only, opening with the callout's icon in its own run in Noto Color
    Emoji, then a bold coloured title, then the body. The icon font is
    registered in word/fontTable.xml by Register-IconFont; skip that and the
    icons render as tofu boxes wherever Noto is not installed.

    Three neutral types - note, key terms, further reading - carry the navy left
    rule but put icon and title in default body black, exactly as the template's
    own library does.

    Requires Lib-Resolve.ps1 dot-sourced first.

    ASCII only in this file.
#>

# No Set-StrictMode - dot-sourced.

function Get-GuideProfile {
    <# Load assets/guide-profile.<brand>.json. #>
    [CmdletBinding()]
    param(
        [string] $SkillDir = $PSScriptRoot,
        [string] $Brand = 'mvc'
    )
    $root = Split-Path -Parent $SkillDir
    $p    = Join-Path $root "assets\guide-profile.$($Brand.ToLower()).json"
    if (-not (Test-Path -LiteralPath $p)) { throw "No guide profile for brand '$Brand': $p" }
    return (Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Get-GuideTemplatePath {
    [CmdletBinding()]
    param([string] $SkillDir = $PSScriptRoot)
    $root = Split-Path -Parent $SkillDir
    $p = Join-Path $root 'assets\templates\MVC_Learner_Guide_Template.docx'
    if (-not (Test-Path -LiteralPath $p)) { throw "Learner Guide template not found: $p" }
    return $p
}

function Split-GuideTemplate {
    <#  Cut the template into the front matter that is KEPT and the closing
        section properties that must survive.

        The template carries a single sectPr, so - unlike the UAT template,
        which seams on its second of three - the seam is the first body heading.
        Cutting at LastIndexOf('<w:p ') with the TRAILING SPACE matters:
        '<w:p>' without it also matches '<w:pPr', which slices a paragraph open
        and produces a document Word offers to repair.

        Returns @{ Prefix; Suffix }. Authored body goes between them.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $DocumentXml,
        [string] $BodyAnchor = 'Unit overview'
    )

    # The anchor text occurs TWICE: once in the table-of-contents field and once
    # as the real heading. The TOC entry comes first and sits inside the
    # contents control's <w:sdt>/<w:sdtContent>, so cutting there slices that
    # control open and Word refuses the file. Take the occurrence that is (a) in
    # a Heading1 paragraph and (b) not inside an unclosed sdt.
    $pStart = -1
    $from   = 0
    while ($true) {
        $hit = $DocumentXml.IndexOf($BodyAnchor, $from)
        if ($hit -lt 0) { break }
        $from = $hit + $BodyAnchor.Length

        $ps = $DocumentXml.LastIndexOf('<w:p ', $hit)
        $pb = $DocumentXml.LastIndexOf('<w:p>', $hit)
        if ($pb -gt $ps) { $ps = $pb }
        if ($ps -lt 0) { continue }

        $para = Get-XmlFragment -Xml $DocumentXml -Tag 'w:p' -From $ps
        if (-not $para -or $para -notmatch '<w:pStyle w:val="Heading1"') { continue }

        $before = $DocumentXml.Substring(0, $ps)
        $opens  = ([regex]::Matches($before, '<w:sdt>')).Count
        $closes = ([regex]::Matches($before, '</w:sdt>')).Count
        if ($opens -ne $closes) { continue }        # still inside the contents control

        $pStart = $ps
        break
    }

    if ($pStart -lt 0) {
        throw "Body anchor '$BodyAnchor' was not found as a Heading1 outside the contents control. The Learner Guide template has changed shape - re-check the seam before building."
    }

    $sect = $DocumentXml.LastIndexOf('<w:sectPr')
    if ($sect -lt 0) { throw 'No closing section properties found in the template.' }

    return @{
        Prefix = $DocumentXml.Substring(0, $pStart)
        Suffix = $DocumentXml.Substring($sect)
    }
}

function Register-IconFont {
    <#  Add the icon font to word/fontTable.xml.

        Without this the callout icons fall back to whatever the renderer picks
        and show as empty boxes off Windows. Segoe UI Emoji is deliberately NOT
        used for the same reason - it is Windows-only.

        Idempotent.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $WorkDir,
        [string] $FontName = 'Noto Color Emoji'
    )

    $part = 'word/fontTable.xml'
    $p = Join-Path $WorkDir ($part -replace '/', '\')
    if (-not (Test-Path -LiteralPath $p)) {
        Write-Verbose "no $part in the package - icon font not registered"
        return $false
    }

    $xml = Get-DocxPart -WorkDir $WorkDir -Part $part
    if ($xml -match [regex]::Escape("w:name=`"$FontName`"")) { return $true }

    $entry = "<w:font w:name=`"$FontName`"><w:charset w:val=`"00`"/><w:family w:val=`"auto`"/><w:pitch w:val=`"variable`"/></w:font>"
    $xml = $xml -replace '</w:fonts>', ($entry + '</w:fonts>')
    Set-DocxPart -WorkDir $WorkDir -Part $part -Content $xml
    return $true
}

function GIconCallout {
    <#  One icon-prefixed, colour-coded callout box.

        -Type is a key from the profile's callouts map. -Lines is the body, one
        paragraph each. -Bullets, where given, render as literal bulleted lines
        inside the cell, because Word numbering inside a single-cell table is
        where list indentation goes wrong.

        The box is kept whole with cantSplit so it moves to the next page rather
        than stranding two lines at a page foot. Row HEIGHT is never forced -
        callout consistency comes from content length, and a forced trHeight is
        a defect everywhere except a learner answer-space box.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Profile,
        [Parameter(Mandatory)][string] $Type,
        [string]   $TitleSuffix,
        [string[]] $Lines,
        [string[]] $Bullets,
        [switch]   $PageBreakBefore
    )

    $def = $Profile.callouts.PSObject.Properties | Where-Object { $_.Name -eq $Type } | Select-Object -First 1
    if (-not $def) { throw "Unknown callout type '$Type'. Known: $(($Profile.callouts.PSObject.Properties | ForEach-Object { $_.Name }) -join ', ')" }
    $c = $def.Value

    $fam = $Profile.calloutPalette.PSObject.Properties | Where-Object { $_.Name -eq $c.family } | Select-Object -First 1
    if (-not $fam) { throw "Callout '$Type' names an unknown colour family '$($c.family)'." }
    $rule = $fam.Value.rule
    $fill = $fam.Value.fill

    $cw       = [int]$Profile.page.contentWidthDxa
    $iconFont = $Profile.typography.iconFont
    $plain    = [bool]$c.plainTitle

    $title = $c.title
    if ($TitleSuffix) { $title = "$title$TitleSuffix" }

    # Icon in its own run in the icon font; title in the callout colour, or in
    # default body black on the three neutral types.
    $titleColour = if ($plain) { '' } else { " w:val=`"$rule`"" }
    $iconRun = '<w:r><w:rPr><w:rFonts w:ascii="' + $iconFont + '" w:hAnsi="' + $iconFont + '" w:cs="' + $iconFont + '"/><w:b/>' +
               $(if ($plain) { '' } else { "<w:color w:val=`"$rule`"/>" }) +
               '</w:rPr><w:t xml:space="preserve">' + (ConvertTo-XmlText $c.icon) + ' </w:t></w:r>'
    $titleRun = '<w:r><w:rPr><w:b/>' + $(if ($plain) { '' } else { "<w:color w:val=`"$rule`"/>" }) +
                '</w:rPr><w:t xml:space="preserve">' + (ConvertTo-XmlText $title) + '</w:t></w:r>'

    $inner = '<w:p><w:pPr><w:keepNext/><w:spacing w:after="60"/></w:pPr>' + $iconRun + $titleRun + '</w:p>'

    foreach ($l in $Lines) {
        if (-not $l) { continue }
        $inner += '<w:p><w:pPr><w:spacing w:after="60" w:line="360" w:lineRule="auto"/></w:pPr>' +
                  '<w:r><w:t xml:space="preserve">' + (ConvertTo-XmlText $l) + '</w:t></w:r></w:p>'
    }
    foreach ($b in $Bullets) {
        if (-not $b) { continue }
        # spacing BEFORE ind - CT_PPr fixes that order too.
        $inner += '<w:p><w:pPr><w:spacing w:after="60" w:line="276" w:lineRule="auto"/><w:ind w:left="284" w:hanging="284"/></w:pPr>' +
                  '<w:r><w:t xml:space="preserve">' + [char]0x2022 + '   ' + (ConvertTo-XmlText $b) + '</w:t></w:r></w:p>'
    }
    if (-not $Lines -and -not $Bullets) { $inner += '<w:p/>' }

    $brk = if ($PageBreakBefore) { '<w:p><w:pPr><w:pageBreakBefore/></w:pPr></w:p>' } else { '' }

    return $brk + @"
<w:tbl><w:tblPr><w:tblW w:w="$cw" w:type="dxa"/>
<w:tblBorders><w:top w:val="none" w:sz="0" w:space="0" w:color="auto"/>
<w:left w:val="single" w:sz="18" w:space="0" w:color="$rule"/>
<w:bottom w:val="none" w:sz="0" w:space="0" w:color="auto"/>
<w:right w:val="none" w:sz="0" w:space="0" w:color="auto"/></w:tblBorders>
<w:tblCellMar><w:left w:w="160" w:type="dxa"/><w:right w:w="160" w:type="dxa"/></w:tblCellMar>
<w:tblLook w:val="04A0" w:firstRow="1" w:lastRow="0" w:firstColumn="1" w:lastColumn="0" w:noHBand="0" w:noVBand="1"/></w:tblPr>
<w:tblGrid><w:gridCol w:w="$cw"/></w:tblGrid>
<w:tr><w:trPr><w:cantSplit/></w:trPr><w:tc><w:tcPr><w:tcW w:w="$cw" w:type="dxa"/>
<w:tcBorders><w:left w:val="single" w:sz="18" w:space="0" w:color="$rule"/></w:tcBorders>
<w:shd w:val="clear" w:color="auto" w:fill="$fill"/>
<w:tcMar><w:top w:w="100" w:type="dxa"/><w:left w:w="160" w:type="dxa"/><w:bottom w:w="100" w:type="dxa"/><w:right w:w="160" w:type="dxa"/></w:tcMar></w:tcPr>
$inner
</w:tc></w:tr></w:tbl>
<w:p><w:pPr><w:spacing w:after="120"/></w:pPr></w:p>
"@
}

# ---------------------------------------------------------------------------
# Numbered lists - a FRESH numId per list, each restarting at 1
# ---------------------------------------------------------------------------

$script:GUIDE_DECIMAL_ABSTRACT = 100      # a new abstractNumId; the template uses 0 and 1
$script:GUIDE_NUMID_BASE       = 100      # authored numIds start here, clear of the template's 1 and 2

function Reset-GuideNumbering {
    <#  Start a build with no allocated lists.

        Call once before rendering. Numbering state is script-scope, so a second
        build in the same session would otherwise keep allocating on top of the
        first and emit numbering definitions for lists that no longer exist.  #>
    $script:GuideNumIds   = New-Object System.Collections.Generic.List[int]
    $script:GuideNextNumId = $script:GUIDE_NUMID_BASE
}

function New-GuideNumId {
    <#  Allocate a fresh numId for ONE logical numbered list.

        Every separate numbered list needs its own numId with a startOverride,
        or Word runs them on continuously and the second Self-check set starts
        at 5. The delivered reference guide carries 164 distinct numIds across
        857 list references for exactly this reason.

        A logical list is one numbered set even when blank answer-space
        paragraphs sit between its items - those share ONE numId and number
        1, 2, 3, 4. Break to a new one only when a heading, a box or running
        prose separates two sets.  #>
    if ($null -eq $script:GuideNumIds) { Reset-GuideNumbering }
    $id = $script:GuideNextNumId
    $script:GuideNextNumId++
    $script:GuideNumIds.Add($id)
    return $id
}

function GNumList {
    <#  A decimal numbered list on its own fresh numId.

        The marker is supplied by Word numbering, never hard-coded into the
        item text - hard-coding produces "1. 1. item" the moment the paragraph
        also carries numPr, and it cannot restart correctly.

        The hanging indent is set on the level in numbering.xml at 720/360, so
        wrapped lines align under the text rather than under the number.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]] $Items,
        [int] $After = 100
    )
    if (-not $Items -or -not $Items.Count) { return '' }
    $numId = New-GuideNumId
    $xml = ''
    $i = 0
    foreach ($it in $Items) {
        $i++
        # keepNext on the penultimate item so the last two travel together.
        $keep = if ($i -eq ($Items.Count - 1)) { '<w:keepNext/>' } else { '' }
        $xml += '<w:p><w:pPr><w:pStyle w:val="ListParagraph"/>' + $keep +
                "<w:numPr><w:ilvl w:val=`"0`"/><w:numId w:val=`"$numId`"/></w:numPr>" +
                "<w:spacing w:after=`"$After`" w:line=`"276`" w:lineRule=`"auto`"/>" +
                '</w:pPr><w:r><w:t xml:space="preserve">' + (ConvertTo-XmlText $it) + '</w:t></w:r></w:p>'
    }
    return $xml
}

function Set-GuideNumbering {
    <#  Write the allocated lists into word/numbering.xml.

        Adds one decimal abstractNum, then one <w:num> per allocated numId,
        each carrying <w:lvlOverride><w:startOverride w:val="1"/></w:lvlOverride>
        so every list restarts at 1. Without the startOverride the numIds exist
        but Word still numbers the lists continuously.

        Run after the body is rendered and before the package is repacked.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $WorkDir)

    if (-not $script:GuideNumIds -or -not $script:GuideNumIds.Count) { return 0 }

    $part = 'word/numbering.xml'
    $xml  = Get-DocxPart -WorkDir $WorkDir -Part $part
    $a    = $script:GUIDE_DECIMAL_ABSTRACT

    if ($xml -notmatch "w:abstractNumId=`"$a`"") {
        $lvls = ''
        for ($l = 0; $l -lt 3; $l++) {
            $left = 720 + ($l * 720)
            $fmt  = @('decimal', 'lowerLetter', 'lowerRoman')[$l]
            $lvls += "<w:lvl w:ilvl=`"$l`"><w:start w:val=`"1`"/><w:numFmt w:val=`"$fmt`"/>" +
                     "<w:lvlText w:val=`"%$($l + 1).`"/><w:lvlJc w:val=`"left`"/>" +
                     "<w:pPr><w:ind w:left=`"$left`" w:hanging=`"360`"/></w:pPr></w:lvl>"
        }
        $abstract = "<w:abstractNum w:abstractNumId=`"$a`"><w:multiLevelType w:val=`"hybridMultilevel`"/>$lvls</w:abstractNum>"
        # abstractNum elements must precede every num element in the part.
        $first = $xml.IndexOf('<w:num ')
        if ($first -lt 0) { $first = $xml.IndexOf('</w:numbering>') }
        $xml = $xml.Substring(0, $first) + $abstract + $xml.Substring($first)
    }

    $nums = ''
    foreach ($id in $script:GuideNumIds) {
        $nums += "<w:num w:numId=`"$id`"><w:abstractNumId w:val=`"$a`"/>" +
                 '<w:lvlOverride w:ilvl="0"><w:startOverride w:val="1"/></w:lvlOverride>' +
                 '</w:num>'
    }
    $xml = $xml.Replace('</w:numbering>', $nums + '</w:numbering>')
    Set-DocxPart -WorkDir $WorkDir -Part $part -Content $xml
    return $script:GuideNumIds.Count
}

function Add-DrawingNamespace {
    <#  Declare the DrawingML namespaces on the <w:document> root.

        The Learner Guide template ships with no drawings in its body, so its
        root declares neither 'a' (DrawingML main) nor 'pic' (DrawingML
        picture). Every placed figure - a generated illustration or a native
        diagram canvas - uses both.

        Word does not report this as a namespace problem. It refuses the whole
        file with "Word experienced an error trying to open the file" and
        suggests the Text Recovery converter, while every structural check still
        passes, because the package IS well formed - it just uses prefixes
        nothing declares.

        Declared here, at build time, so the document is ready for artwork
        before the artwork stage runs.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $DocumentXml)

    $m = [regex]::Match($DocumentXml, '<w:document\b[^>]*>')
    if (-not $m.Success) { return $DocumentXml }

    $root = $m.Value
    $add = ''
    if ($root -notmatch 'xmlns:a=')   { $add += ' xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"' }
    if ($root -notmatch 'xmlns:pic=') { $add += ' xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"' }
    if (-not $add) { return $DocumentXml }

    $newRoot = $root.Substring(0, $root.Length - 1) + $add + '>'
    return $DocumentXml.Substring(0, $m.Index) + $newRoot + $DocumentXml.Substring($m.Index + $m.Length)
}

function GImagePrompt {
    <#  Emit an artwork PROMPT BLOCK at the exact spot the artwork belongs.

        The guide is built with prompts on the page, not pictures. The
        `docx-images` sub-skill reads each block at Stage 7b, produces the
        artwork, places it back at the same spot with its caption and alt text,
        and deletes the prompt. What ships carries no prompt text anywhere.

        TWO ROUTES, and they are not interchangeable - this mirrors both the
        Visual Placement spec's Route A / Route B and docx-images' own split:

          Route A  -Kind Image    a photographic or illustrative visual,
                                  GENERATED by the image model. Costs money.
          Route B  -Kind Diagram  a flowchart, decision tree, chart, table or
                                  infographic, BUILT AS NATIVE WORD OBJECTS.
                                  Never rasterised, never generated, free.

        Emitting a diagram as -Kind Image is the expensive mistake: it burns a
        generation on a picture whose labels nobody can correct and whose
        spelling nobody can trust, in a document an auditor reads.

        The emitted shape is what docx-images' detector expects - an opening
        [IMAGE:/[DIAGRAM: line, the prompt body, optional CAPTION/ALT/ASPECT
        field lines, then a closing [/IMAGE]/[/DIAGRAM].

        -Prompt for Route A is ONE paragraph of 90-160 words of plain
        descriptive prose, standing entirely on its own: subject and action in
        present tense, setting, people with role/dress/PPE/posture/gaze,
        equipment, composition and camera, lighting, colour direction, style,
        jurisdictional cues, and a closing exclusion clause. Never ask for text
        inside a generated image - generators render lettering unreliably, and
        every label is added afterwards.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('Image', 'Diagram')][string] $Kind,
        [Parameter(Mandatory)][string] $Figure,      # e.g. '1.1.3' or '0.1'
        [Parameter(Mandatory)][string] $Prompt,
        [string] $Caption,
        [string] $Alt,
        [string] $Aspect
    )

    $tag = if ($Kind -eq 'Diagram') { 'DIAGRAM' } else { 'IMAGE' }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("[$tag`: $Prompt")
    if ($Caption) { $lines.Add("CAPTION: Figure $Figure - $Caption") }
    elseif ($Kind -ne 'Image' -or $Figure -ne '0.1') { $lines.Add("CAPTION: Figure $Figure") }
    if ($Alt)    { $lines.Add("ALT: $Alt") }
    if ($Aspect) { $lines.Add("ASPECT: $Aspect") }
    $lines.Add("[/$tag]")

    $xml = ''
    foreach ($l in $lines) {
        $xml += '<w:p><w:pPr><w:spacing w:after="0"/></w:pPr>' +
                '<w:r><w:rPr><w:i/><w:color w:val="999999"/></w:rPr>' +
                '<w:t xml:space="preserve">' + (ConvertTo-XmlText $l) + '</w:t></w:r></w:p>'
    }
    return $xml
}

function Get-GuideImagePrompt {
    <#  Every artwork prompt block still present in a built guide.

        Used two ways. Before Stage 7b it confirms the guide carries the
        visuals it planned. After Stage 7b it must return NOTHING - a prompt
        that survives artwork is a prompt an auditor reads.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)

    $wd = if ((Get-Item -LiteralPath $Path).PSIsContainer) { $Path } else { Expand-Docx -Path $Path }
    $doc = Get-DocxPart -WorkDir $wd -Part 'word/document.xml'

    # A prompt block spans several paragraphs - the opening tag, the prompt
    # body, then CAPTION / ALT / ASPECT lines, then the closing tag. The figure
    # number lives on the CAPTION line, deliberately: it must NOT sit in the
    # prompt body, which has to stand alone when pasted cold into a generator
    # and must carry no reference to the guide. So the whole block is consumed,
    # not just its first paragraph.
    $out    = New-Object System.Collections.Generic.List[object]
    $paras  = @(Get-GuideBodyBlock -DocumentXml $doc | Where-Object { $_.Kind -eq 'para' })
    $i      = 0
    while ($i -lt $paras.Count) {
        $t = $paras[$i].Text.Trim()
        $m = [regex]::Match($t, '^\[\s*(IMAGE|DIAGRAM|ILLUSTRATION|PHOTO|FIGURE|PICTURE)\s*[:\-]')
        if (-not $m.Success) { $i++; continue }

        $kind  = $m.Groups[1].Value.ToUpper()
        $lines = New-Object System.Collections.Generic.List[string]
        $j     = $i
        while ($j -lt $paras.Count -and $j -lt ($i + 12)) {
            $lines.Add($paras[$j].Text.Trim())
            if ($paras[$j].Text.Trim() -match '^\[\s*/') { break }
            $j++
        }
        $blockText = ($lines -join "`n")

        $out.Add([pscustomobject]@{
            Kind    = $kind
            Figure  = [regex]::Match($blockText, 'Figure\s+([0-9]+\.[0-9]+(?:\.[0-9]+)?)').Groups[1].Value
            Caption = [regex]::Match($blockText, '(?m)^CAPTION\s*[:\-]\s*(.+)$').Groups[1].Value
            Alt     = [regex]::Match($blockText, '(?m)^ALT\s*[:\-]\s*(.+)$').Groups[1].Value
            Closed  = ($lines[-1] -match '^\[\s*/')
            Words   = @($lines[0] -split '\s+' | Where-Object { $_ -match '\w' }).Count
            Text    = $blockText
        })
        $i = $j + 1
    }
    return $out
}

function GHeading {
    <#  A heading paragraph.

        keepNext goes on the PARAGRAPH, not only on the style, so a heading
        cannot strand at the foot of a page away from what it introduces.
        pageBreakBefore is how a Topic or a PC sub-section starts a new page -
        more robust than a standalone break paragraph, which lands mid-page
        whenever the preceding content exactly fills the sheet, and which also
        produces a genuinely blank page when it follows a spacer.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateRange(1, 4)][int] $Level,
        [Parameter(Mandatory)][string] $Text,
        [switch] $PageBreakBefore,
        $Profile
    )

    # CT_PPr fixes the ORDER of these children: pStyle, keepNext, keepLines,
    # pageBreakBefore. Emitting pageBreakBefore before keepNext is schema-
    # invalid, and Word's only response is to refuse the entire file with "Word
    # experienced an error trying to open the file" - no part named, no element
    # named. Every structural check still passes, because the XML is perfectly
    # well formed; it is simply in the wrong order.
    $pr = "<w:pStyle w:val=`"Heading$Level`"/>"
    $pr += '<w:keepNext/><w:keepLines/>'
    if ($PageBreakBefore) { $pr += '<w:pageBreakBefore/>' }

    $colour = ''
    if ($Profile -and $Level -eq 4) {
        # The template's Heading4 ships Word's default 2E74B5, which is not a
        # brand colour. Authored H4s are written in navy.
        $colour = "<w:color w:val=`"$($Profile.headings.Heading4)`"/>"
    }

    return "<w:p><w:pPr>$pr</w:pPr><w:r><w:rPr>$colour</w:rPr><w:t xml:space=`"preserve`">" +
           (ConvertTo-XmlText $Text) + '</w:t></w:r></w:p>'
}

function Set-GuideFooter {
    <#  Put LIVE FIELDS in the footer, and this document's own control data.

        The approved template types its footer as literal text - including
        "Page 1 of 103". Word never recalculates a typed string, so every page
        of every guide the template produces prints "Page 1 of 103", and the
        document number, revision date and next-review date are the template's
        rather than this document's. It shipped that way once.

        PAGE and NUMPAGES are proper field runs here: begin / instrText / separate
        / cached result / end. The cached result is what a reader sees before
        fields are updated, so it is set to something honest rather than a stale
        number, and Stage 8's Update-Fields replaces it.

        Unit keys used, all optional: DocNumber, DocVersion, RevisionDate,
        NextReview. Anything absent keeps whatever the template carried, so a
        brand with a different footer is not damaged by running this.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $WorkDir,
        [hashtable] $Unit
    )

    $part = 'word/footer1.xml'
    $p = Join-Path $WorkDir ($part -replace '/', '\')
    if (-not (Test-Path -LiteralPath $p)) { return $false }
    $x = Get-DocxPart -WorkDir $WorkDir -Part $part
    $before = $x

    function Fld ([string] $Instr, [string] $Cached) {
        '<w:r><w:fldChar w:fldCharType="begin"/></w:r>' +
        '<w:r><w:instrText xml:space="preserve"> ' + $Instr + ' </w:instrText></w:r>' +
        '<w:r><w:fldChar w:fldCharType="separate"/></w:r>' +
        '<w:r><w:t>' + $Cached + '</w:t></w:r>' +
        '<w:r><w:fldChar w:fldCharType="end"/></w:r>'
    }

    # "Page N of M" as two live fields, however the template spelt the numbers.
    $x = [regex]::Replace(
            $x,
            '<w:r>(?:(?!</w:r>).)*?<w:t[^>]*>\s*Page\s+\d+\s+of\s+\d+\s*</w:t>\s*</w:r>',
            ('<w:r><w:t xml:space="preserve">Page </w:t></w:r>' + (Fld 'PAGE' '1') +
             '<w:r><w:t xml:space="preserve"> of </w:t></w:r>' + (Fld 'NUMPAGES' '1')),
            'Singleline')

    if ($Unit) {
        # EVERY pattern below is bounded with [^<] so it cannot cross a tag.
        # An unbounded \S+ here matched straight through "</w:t></w:r><w:r>
        # <w:tab/><w:t>Next" and deleted both the markup and the word, which
        # produced a footer reading " Review:" and a run that no longer existed.
        if ($Unit.DocNumber -or $Unit.DocVersion) {
            $n = if ($Unit.DocNumber)  { $Unit.DocNumber }  else { '____' }
            $v = if ($Unit.DocVersion) { $Unit.DocVersion } else { '1.0' }
            $x = [regex]::Replace($x, 'Doc#[^<]*?Ver#[^<]*',
                                  ("Doc#  {0}    Ver#   {1}" -f $n, $v))
        }
        if ($Unit.RevisionDate) {
            $x = [regex]::Replace($x, 'Revision Date:[^<]*',
                                  "Revision Date: $($Unit.RevisionDate)")
        }
        if ($Unit.NextReview) {
            $x = [regex]::Replace($x, 'Next Review:[^<]*',
                                  "Next Review: $($Unit.NextReview)")
        }
    }

    if ($x -ne $before) { Set-DocxPart -WorkDir $WorkDir -Part $part -Content $x; return $true }
    return $false
}

function Write-GuideDocument {
    <#  Build one finished Learner Guide.

        -BodyXml is the authored body, built with GHeading, GIconCallout and the
        shared H* block builders. ALWAYS assembled from a fresh copy of the
        pristine template - edits compound, and a second build on an already
        patched package silently doubles whatever the first one inserted.

        Gating is NOT done here. Run Test-GuideRules on the working directory
        before repacking and Invoke-DocumentVerification on the finished file
        after, per references/gates.md.  #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][hashtable] $Unit,
        [Parameter(Mandatory)][string]    $BodyXml,
        [Parameter(Mandatory)][string]    $OutPath,
        [string] $TemplatePath,
        $Profile,
        [hashtable] $Replacements
    )

    if (-not $Profile)      { $Profile      = Get-GuideProfile -SkillDir $PSScriptRoot }
    if (-not $TemplatePath) { $TemplatePath = Get-GuideTemplatePath -SkillDir $PSScriptRoot }

    if (-not $PSCmdlet.ShouldProcess($OutPath, 'build Learner Guide')) { return }

    $wd = Expand-Docx -Path $TemplatePath
    try {
        $doc   = Get-DocxPart -WorkDir $wd -Part 'word/document.xml'
        $seam  = Split-GuideTemplate -DocumentXml $doc -BodyAnchor $Profile.structure.bodyStartsAt
        $doc   = $seam.Prefix + $BodyXml + $seam.Suffix

        # Cover and running-head placeholders the template ships in brackets.
        #
        # The cover's unit line reads "[Unit code] - [Unit title]" joined by an
        # EM DASH (U+2014, measured from the template). It is deliberately NOT
        # replaced as one combined key: substituting the two halves separately
        # leaves the template's own em dash in place, so the cover keeps the
        # RTO's typography instead of whatever this script would have typed.
        #
        # Order matters and is therefore explicit. A hashtable's iteration order
        # is not guaranteed in PowerShell, so a combined key and its two halves
        # in the same hashtable would resolve differently between builds and the
        # cover would gain or lose its em dash at random.
        $ordered = New-Object System.Collections.Specialized.OrderedDictionary
        $ordered.Add('[Qualification code and title]', $Unit.Qualification)
        $ordered.Add('[Release / version]',            $Unit.Release)
        $ordered.Add('[AQF level]',                    $Unit.AqfLevel)
        $ordered.Add('[Unit code]',                    $Unit.Code)
        $ordered.Add('[Unit title]',                   $Unit.Title)
        if ($Replacements) { foreach ($k in $Replacements.Keys) { $ordered[$k] = $Replacements[$k] } }

        foreach ($k in $ordered.Keys) {
            if ($null -eq $ordered[$k]) { continue }
            $doc = $doc.Replace($k, (ConvertTo-XmlText $ordered[$k]))
        }

        $doc = Add-DrawingNamespace -DocumentXml $doc
        Set-DocxPart -WorkDir $wd -Part 'word/document.xml' -Content $doc
        Register-IconFont -WorkDir $wd -FontName $Profile.typography.iconFont | Out-Null
        Set-GuideNumbering -WorkDir $wd | Out-Null
        Set-GuideFooter   -WorkDir $wd -Unit $Unit | Out-Null

        # Assert-DocxPackage throws listing EVERY problem, rather than the first.
        # It also RETURNS $true on success, which would otherwise ride out on
        # the pipeline ahead of $OutPath and make the caller's path 'True'.
        Assert-DocxPackage -WorkDir $wd | Out-Null

        Compress-Docx -WorkDir $wd -Path $OutPath | Out-Null
        Write-Verbose "built $OutPath"
        return $OutPath
    }
    finally { Remove-Item -LiteralPath $wd -Recurse -Force -ErrorAction SilentlyContinue }
}
