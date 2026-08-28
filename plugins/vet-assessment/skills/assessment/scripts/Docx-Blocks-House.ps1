# Docx-Blocks-House.ps1 - block builders that reproduce the MVC house format
# measured from the RTO own approved artefacts. See assets/MVC_HOUSE_STANDARD.md.
#
# Differences from the generic builder, all deliberate and all measured:
#   * docDefaults CARRIES w:sz 22, so unsized body runs render at 11 pt. The
#     artefacts left it unset and fell back to 10 pt, below the accessibility
#     floor; the RTO chose to meet the floor on 21 Aug 2026. Set by
#     scripts/Patch-TemplateFontFloor.ps1, not here.
#   * Cell and table text is 10 pt (w:sz 20) - the accessibility floor. The
#     artefacts measured 9.5 pt; the RTO chose to meet the floor on 21 Aug 2026.
#     docDefaults now carries w:sz 22, so unsized body runs render at 11 pt
#     rather than falling back to 10.
#   * Line spacing is 240 (single) or 360 (1.5) only. Never 276.
#   * No cantSplit anywhere. The house documents use none.
#   * Banners carry outlineLvl and every document carries a table of contents.
#     RTO decision, 21 Aug 2026 - this OVERRIDES the measurement, because the
#     RTO artefacts have neither. A TOC field indexes paragraphs with an outline
#     level, so the two go together: drop the outline level and the TOC ships
#     empty. See HBanner and HTableOfContents.
#   * Bullets in body prose are real Word list items: pStyle ListParagraph +
#     numPr numId 2, spacing line 360 - not a literal glyph and a tab. See HBullet.
#     THE EXCEPTION, which gets "fixed" by mistake: inside a table cell or an
#     assessor panel, use a literal bullet glyph + tab + hanging indent, because
#     the house numbering style indents wrongly in a cell. See HPanelBullet and
#     the answer-grid branch of HTable. Also in house-style.md section D,
#     template-build.md and house-profile.mvc.json - deliberately, all four.
#   * Writing-cell rows default to 1050 DXA.
#
# ASCII ONLY in this file. Content strings arrive from JSON already carrying
# degree symbols and en dashes; those pass through untouched.

# No Set-StrictMode here. This file is dot-sourced, so a strict mode set at its
# top leaks into the caller's whole session - it turned an empty-array .Count in
# Test-HouseRules.ps1 into a terminating error. The other two dot-sourced files
# carry the same note for the same reason.

# THE PALETTE IS BRAND-DEPENDENT. These are the MVC defaults; Set-HousePalette
# overwrites them from branding.<brand>.json before a build. Leave them hardcoded
# and every ACI document ships in MVC navy - a crossover the text sweep WOULD
# catch, but only after the whole pack had been built.
$script:NAVY   = '234B8C'
$script:ACCENT = '2F60B4'
$script:RULE   = 'F09C0C'
$script:GREY   = '606060'
$script:FILL   = 'F0F2F7'
$script:BORD   = 'C9CFDD'
$script:PLACE  = '999999'
$script:MODEL  = 'E43C30'
$script:BRAND_VARIANT = $null
# The brand whose HOUSE PROFILE the builders read - Get-HouseSpacing and
# HRenderProse pass it to Get-HouseProfile. Left at the default, an ACI build
# would build to MVC's readability figures while Test-Readability -Brand ACI
# gated against ACI's: builder and gate must move together.
#
# NAMED HOUSE_BRAND, NEVER BRAND. This file is DOT-SOURCED, so "$script:" here
# is the CALLING build script's scope, and PowerShell variable names are
# case-insensitive - "$script:BRAND = 'MVC'" silently overwrote the caller's
# own $Brand = 'ACI' parameter at dot-source time. Every document of the
# SITHCCC036 build then went out MVC-branded while reporting success, because
# Write-PackDocument received the clobbered value. Renamed 28 August 2026.
# The same trap class is documented in template-build.md: variable names that
# differ only by case are the same variable.
$script:HOUSE_BRAND = 'MVC'

function Set-HousePalette {
    <#  Point the block builders at a brand's colours.

        MVC carries one palette on the profile root. ACI carries one PER VARIANT,
        because the culinary mark is coral and the construction mark is navy, and
        the RTO's decision is that the two must not look alike.

        Call this ONCE, before building any block. Every H* function reads these
        script-scope values at call time, so a late call silently colours half a
        document one way and half the other.  #>
    [CmdletBinding()]
    param(
        [ValidateSet('MVC','ACI')][string] $Brand = 'MVC',
        [string] $Variant
    )

    $b = Get-Branding -Brand $Brand
    $pal = $null

    if ($b.PSObject.Properties.Name -contains 'variants' -and $b.variants) {
        if (-not $Variant) { $Variant = $b.variants.default }
        if (-not $Variant) { throw "Brand '$Brand' carries variants but none was named and no default is set." }
        if ($b.variants.PSObject.Properties.Name -notcontains $Variant) {
            $known = @($b.variants.PSObject.Properties.Name | Where-Object { $_ -ne 'default' -and $_ -notlike '_*' }) -join ', '
            throw "Brand '$Brand' has no variant '$Variant'. Known variants: $known."
        }
        # A variant MAY override the palette; it usually does not. ACI's two
        # trading names share one locked palette and differ only by logo and
        # identity, so the brand-level palette is the normal case and a
        # variant-level one is the exception. Treating these as either/or -
        # which this did until 27 August 2026 - makes a brand with variants
        # unable to carry a shared palette at all.
        $pal = $null
        if ($b.variants.$Variant.PSObject.Properties.Name -contains 'palette') {
            $pal = $b.variants.$Variant.palette
        }
        if (-not $pal) { $pal = $b.palette }
        $script:BRAND_VARIANT = $Variant
    } else {
        $pal = $b.palette
        $script:BRAND_VARIANT = $null
    }
    if (-not $pal) { throw "No palette found for brand '$Brand'." }

    # Point the profile-reading builders at this brand too, and drop the cached
    # spacing - a two-brand session must not serve brand A's spacing to brand B.
    $script:HOUSE_BRAND = $Brand
    $script:SP_CACHE = $null

    function Pick2 { param($o,$n,$d) if (($o.PSObject.Properties.Name -contains $n) -and $o.$n) { return [string]$o.$n } return $d }
    $script:NAVY   = Pick2 $pal 'dark'        $script:NAVY
    $script:ACCENT = Pick2 $pal 'accent'      $script:ACCENT
    $script:RULE   = Pick2 $pal 'rule'        $script:RULE
    $script:GREY   = Pick2 $pal 'grey'        $script:GREY
    $script:FILL   = Pick2 $pal 'lightFill'   $script:FILL
    $script:BORD   = Pick2 $pal 'border'      $script:BORD
    $script:PLACE  = Pick2 $pal 'placeholder' $script:PLACE
    $script:MODEL  = Pick2 $pal 'modelAnswer' $script:MODEL

    [pscustomobject]@{
        Brand = $Brand; Variant = $script:BRAND_VARIANT
        Dark = $script:NAVY; Accent = $script:ACCENT; Rule = $script:RULE
        Grey = $script:GREY; Fill = $script:FILL; Border = $script:BORD
        Placeholder = $script:PLACE; ModelAnswer = $script:MODEL
    }
}
$script:CW     = 9638          # every table, every document

$script:SZ_CELL   = 20         # 10 pt - the accessibility floor for table and cell text. Was 19 (9.5 pt); raised 21 Aug 2026.
$script:SZ_BODY   = 22         # 11 pt where a run is explicitly sized
$script:SZ_BANNER = 26         # 13 pt banner headings
$script:SZ_SMALL  = 20         # 10 pt - assessor panel labels. Was 18 (9 pt); these sit in table cells, so the same floor applies. Bold navy still carries the hierarchy.
$script:LN_SINGLE = 240
$script:LN_ONEHALF= 360
$script:ROW_WRITE = 1050       # default writing-cell height
$script:BULLET_NUMID = 2       # the numId the house documents use

function HX {
    param([string]$s)
    if ($null -eq $s) { return '' }
    $s = $s -replace '&','&amp;'
    $s = $s -replace '<','&lt;'
    $s = $s -replace '>','&gt;'
    $s = $s -replace '"','&quot;'
    return $s
}

# ---------- runs ----------
function HRun {
    param([string]$Text,[switch]$Bold,[switch]$Italic,[string]$Color,[int]$Size = 0)
    $rpr = ''
    if ($Bold)   { $rpr += '<w:b/><w:bCs/>' }
    if ($Italic) { $rpr += '<w:i/><w:iCs/>' }
    if ($Color)  { $rpr += "<w:color w:val=`"$Color`"/>" }
    if ($Size -gt 0) { $rpr += "<w:sz w:val=`"$Size`"/><w:szCs w:val=`"$Size`"/>" }
    if ($rpr) { $rpr = "<w:rPr>$rpr</w:rPr>" }
    "<w:r>$rpr<w:t xml:space=`"preserve`">$(HX $Text)</w:t></w:r>"
}

# CT_PPr child order: pStyle, keepNext, keepLines, pageBreakBefore, numPr,
# spacing, ind, jc. Anything out of order and Word rejects the file.
function HPara {
    param(
        [string]$Runs = '',
        [switch]$KeepNext,
        [switch]$PageBreakBefore,
        [int]$Before = 0,
        [int]$After = 0,
        [int]$Line = 0,
        [string]$Align,
        [switch]$Bullet,
        [int]$IndLeft = 0,
        [int]$IndHang = 0
    )
    $ppr = ''
    if ($Bullet)  { $ppr += '<w:pStyle w:val="ListParagraph"/>' }
    if ($KeepNext){ $ppr += '<w:keepNext/>' }
    if ($PageBreakBefore) { $ppr += '<w:pageBreakBefore/>' }
    if ($Bullet)  { $ppr += "<w:numPr><w:ilvl w:val=`"0`"/><w:numId w:val=`"$script:BULLET_NUMID`"/></w:numPr>" }
    # CT_PPr order: ... numPr, spacing, ind, jc
    $sp = ''
    if ($Before -gt 0) { $sp += " w:before=`"$Before`"" }
    if ($After  -gt 0) { $sp += " w:after=`"$After`"" }
    if ($Line   -gt 0) { $sp += " w:line=`"$Line`" w:lineRule=`"auto`"" }
    if ($sp) { $ppr += "<w:spacing$sp/>" }
    if ($IndLeft -gt 0 -or $IndHang -gt 0) { $ppr += "<w:ind w:left=`"$IndLeft`" w:hanging=`"$IndHang`"/>" }
    if ($Align) { $ppr += "<w:jc w:val=`"$Align`"/>" }
    if ($ppr) { $ppr = "<w:pPr>$ppr</w:pPr>" }
    "<w:p>$ppr$Runs</w:p>"
}

# A numbered method step. The wrapped second and later lines align under the
# TEXT, not back at the margin - left 460, hanging 460, which is the house list
# indent. Without the hanging indent a three-line step reads as three steps.
function HNumStep {
    param([int]$N,[string]$Text)
    $runs  = HRun -Text "$N." -Bold -Color $script:NAVY
    $runs += '<w:r><w:tab/></w:r>'
    $runs += HRun -Text $Text
    HPara -Runs $runs -After 100 -Line $script:LN_ONEHALF -IndLeft 460 -IndHang 460
}

# Remove an entire table row containing the given text. Used to drop the
# "Administration: Rec'd / Date:" row from the recipe cover sheet.
function Remove-RowContaining {
    param([string]$Xml,[string]$Text)
    $i = $Xml.IndexOf($Text)
    if ($i -lt 0) { return $Xml }
    # Must match the row element itself. Searching for '<w:tr' also hits
    # '<w:trPr' and '<w:trHeight', which cuts the row open mid-way and produces
    # XML Word refuses to load.
    $a = $Xml.LastIndexOf('<w:tr>', $i)
    $b = $Xml.LastIndexOf('<w:tr ', $i)
    $trStart = [Math]::Max($a, $b)
    $trEnd   = $Xml.IndexOf('</w:tr>', $i)
    if ($trStart -lt 0 -or $trEnd -lt 0) { return $Xml }
    $Xml.Substring(0,$trStart) + $Xml.Substring($trEnd + 7)
}

# Readability spacing. RTO decision, 26 August 2026 - references/readability.md.
# w:line is a blocking check and admits 240 or 360 only, so readability is bought
# with space AFTER, never with leading. Bullets shipped at after=0 and a list whose
# items sit flush against each other is unreadable.
# -KeepNext binds a paragraph to whatever follows it. A lead-in ending in a colon
# MUST carry it, or the line that introduces a list strands at the foot of a page
# while its list starts the next one. references/readability.md rule 5.
# SPACING COMES FROM THE PROFILE, not from these defaults.
# house-profile.<brand>.json -> readability.spacing is the authority. The gate
# reads it too, so a value changed there moves the builder and the check together.
# Hardcoding it here is the drift house-standard.md warns about: the check would
# start failing every bullet the builder emits.
$script:SP_CACHE = $null
function Get-HouseSpacing {
    if ($null -ne $script:SP_CACHE) { return $script:SP_CACHE }
    $d = @{ bodyAfter = 160; bulletAfter = 80; panelBulletAfter = 40; tableCellAfter = 60 }
    if (Get-Command Get-HouseProfile -ErrorAction SilentlyContinue) {
        try {
            $s = (Get-HouseProfile -Brand $script:HOUSE_BRAND).readability.spacing
            if ($s) { foreach ($k in @($d.Keys)) { if (($s.PSObject.Properties.Name -contains $k) -and $s.$k) { $d[$k] = [int]$s.$k } } }
        } catch { }
    }
    $script:SP_CACHE = $d
    return $d
}

function HBody   { param([string]$Text,[int]$After = 0,[switch]$KeepNext)
    if ($After -le 0) { $After = (Get-HouseSpacing).bodyAfter }
    HPara -Runs (HRun -Text $Text) -After $After -Line $script:LN_ONEHALF -KeepNext:$KeepNext }
function HBullet { param([string]$Text,[int]$After = 0)
    if ($After -le 0) { $After = (Get-HouseSpacing).bulletAfter }
    HPara -Runs (HRun -Text $Text) -Bullet -Line $script:LN_ONEHALF -After $After }
function HSpacer { param([int]$H = 120) HPara -After $H }

$script:BUL = [char]0x2022

# ---------- prose and lists, from one agent string ----------
# The three-line cap in characters. house-profile.<brand>.json -> readability
# .paragraphMaxChars is the authority; this is the fallback when no profile is
# loaded. HRenderProse re-reads it from the profile on each call where it can.
$script:RD_CAP = 300

function HRenderProse {
    <#  Turns an agent's multi-line string into real blocks. THIS IS THE FUNCTION
        THAT DECIDES LIST OR PROSE, and it is the only thing that decides.

        A line marked "- " is a LIST ITEM and gets a real Word bullet.

        Every other line is PROSE, and consecutive prose lines are JOINED back
        into one paragraph, greedily, up to the three-line cap.

        WHY THE JOINING MATTERS. A readability editor writes one sentence per
        line. Rendered one-paragraph-per-line, eleven consecutive sentences look
        exactly like a bulleted list that has lost its bullets - which is the
        first thing a reader notices and the complaint that actually arrives.
        Prose must look like prose and a list must look like a list.

        A line ending in a colon introduces what follows, so it closes its
        paragraph AND carries keepNext, binding it to the first bullet beneath
        it. Without that the lead-in strands at a page foot while its list opens
        the next page. references/readability.md rules 2b and 5.  #>
    param([string]$Text,[int]$After = 160,[int]$MaxChars = 0)

    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    if ($MaxChars -le 0) {
        $MaxChars = $script:RD_CAP
        if (Get-Command Get-HouseProfile -ErrorAction SilentlyContinue) {
            try {
                $v = (Get-HouseProfile -Brand $script:HOUSE_BRAND).readability.paragraphMaxChars
                if ($v) { $MaxChars = [int]$v }
            } catch { }
        }
    }

    $out = New-Object System.Text.StringBuilder
    $buf = ''
    $bulletPattern = '^[-' + $script:BUL + ']\s+(.+)$'

    foreach ($ln in ($Text -split "`r?`n")) {
        $s = $ln.Trim()
        if (-not $s) { continue }

        if ($s -match $bulletPattern) {
            if ($buf) { [void]$out.Append((HBody -Text $buf -After $After)); $buf = '' }
            [void]$out.Append((HBullet -Text $Matches[1].Trim()))
            continue
        }

        $cand = if ($buf) { "$buf $s" } else { $s }
        if ($buf -and $cand.Length -gt $MaxChars) {
            [void]$out.Append((HBody -Text $buf -After $After))
            $buf = $s
        } else {
            $buf = $cand
        }
        if ($buf.EndsWith(':')) { [void]$out.Append((HBody -Text $buf -After $After -KeepNext)); $buf = '' }
    }
    if ($buf) { [void]$out.Append((HBody -Text $buf -After $After)) }
    $out.ToString()
}

# ---------- headings ----------
function HBanner {
    <#  A navy section banner.

        -OutlineLevel puts the banner in the table of contents: 0 for a section
        banner, 1 for a sub-banner, -1 to keep it out.

        WHY A BANNER CARRIES AN OUTLINE LEVEL. A Word TOC field indexes
        paragraphs carrying an outline level or a heading style. These banners
        are neither - they are bold white runs inside a one-cell table. Without
        w:outlineLvl the TOC field renders EMPTY. The outline level is invisible
        on the page and changes no formatting; it exists only so the field has
        something to index.

        CT_PPr order puts outlineLvl LATE - after spacing and jc - so it is
        emitted last here. Out of order, Word rejects the file.  #>
    param(
        [string]$Text,
        [int]$Size = 0,
        [switch]$PageBreakBefore,
        [int]$OutlineLevel = 0
    )
    if ($Size -le 0) { $Size = $script:SZ_BANNER }
    $brk = ''
    if ($PageBreakBefore) { $brk = '<w:pageBreakBefore/>' }
    $olv = ''
    if ($OutlineLevel -ge 0) { $olv = "<w:outlineLvl w:val=`"$OutlineLevel`"/>" }
    @"
<w:tbl><w:tblPr><w:tblW w:w="$script:CW" w:type="dxa"/><w:tblBorders>
<w:top w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/><w:left w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/>
<w:bottom w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/><w:right w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/></w:tblBorders>
<w:tblCellMar><w:left w:w="10" w:type="dxa"/><w:right w:w="10" w:type="dxa"/></w:tblCellMar>
<w:tblLook w:val="04A0" w:firstRow="1" w:lastRow="0" w:firstColumn="1" w:lastColumn="0" w:noHBand="0" w:noVBand="1"/></w:tblPr>
<w:tblGrid><w:gridCol w:w="$script:CW"/></w:tblGrid>
<w:tr><w:tc><w:tcPr><w:tcW w:w="$script:CW" w:type="dxa"/>
<w:shd w:val="clear" w:color="auto" w:fill="$script:NAVY"/>
<w:tcMar><w:top w:w="90" w:type="dxa"/><w:left w:w="160" w:type="dxa"/><w:bottom w:w="90" w:type="dxa"/><w:right w:w="160" w:type="dxa"/></w:tcMar></w:tcPr>
<w:p><w:pPr><w:keepNext/>$brk$olv</w:pPr><w:r><w:rPr><w:b/><w:bCs/><w:color w:val="FFFFFF"/><w:sz w:val="$Size"/><w:szCs w:val="$Size"/></w:rPr><w:t xml:space="preserve">$(HX $Text)</w:t></w:r></w:p>
</w:tc></w:tr></w:tbl>
"@
}

# ---------- table of contents ----------
# Every document carries one, immediately after the title page. RTO decision,
# 21 August 2026. This OVERRIDES the measurement - the RTO's own artefacts have
# none - and it is why HBanner emits an outline level.
#
# The field ships with placeholder text between 'separate' and 'end'. That text
# is what a reader sees until the field is updated, so Update-Fields in
# Verify-Document.ps1 MUST run before delivery, or the document ships showing
# the placeholder instead of a contents list. w:dirty="true" also asks Word to
# rebuild the field on open, which covers a reader opening the .docx directly.
function HTableOfContents {
    param(
        [string]$Title = 'Contents',
        [string]$Field = ' TOC \o "1-2" \h \z \u ',
        [switch]$PageBreakBefore
    )
    $t = HPara -Runs (HRun -Text $Title -Bold -Color $script:NAVY -Size $script:SZ_BANNER) `
               -KeepNext -PageBreakBefore:$PageBreakBefore -Before 200 -After 120
    $t += @"
<w:p><w:pPr><w:spacing w:after="60" w:line="$script:LN_SINGLE" w:lineRule="auto"/></w:pPr>
<w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r>
<w:r><w:instrText xml:space="preserve">$(HX $Field)</w:instrText></w:r>
<w:r><w:fldChar w:fldCharType="separate"/></w:r>
<w:r><w:rPr><w:i/><w:iCs/><w:color w:val="$script:PLACE"/><w:sz w:val="$script:SZ_CELL"/></w:rPr><w:t xml:space="preserve">Right-click and choose Update Field to build the contents list.</w:t></w:r>
<w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>
"@
    $t
}

function HHead {
    param([string]$Text,[int]$Size = 0,[switch]$PageBreakBefore,[int]$Before = 200,[int]$After = 60)
    if ($Size -le 0) { $Size = $script:SZ_BODY }
    HPara -Runs (HRun -Text $Text -Bold -Color $script:NAVY -Size $Size) `
          -KeepNext -PageBreakBefore:$PageBreakBefore -Before $Before -After $After
}

function HSubHead {
    param([string]$Text,[int]$Before = 160,[int]$After = 40)
    HPara -Runs (HRun -Text $Text -Bold -Color $script:NAVY -Size $script:SZ_BODY) -KeepNext -Before $Before -After $After
}

# ---------- boxes ----------
function HMapsBox {
    param([string]$MapsTo,[string]$WordGuide)
    $inner  = HPara -Runs (HRun -Text 'Maps to' -Bold -Color $script:NAVY -Size $script:SZ_CELL) -After 20 -KeepNext
    $inner += HPara -Runs (HRun -Text $MapsTo -Size $script:SZ_CELL) -Line $script:LN_SINGLE -After 40
    if ($WordGuide) {
        $inner += HPara -Runs ((HRun -Text 'Word guide: ' -Bold -Color $script:NAVY -Size $script:SZ_CELL) + (HRun -Text $WordGuide -Size $script:SZ_CELL)) -Line $script:LN_SINGLE
    }
    @"
<w:tbl><w:tblPr><w:tblW w:w="$script:CW" w:type="dxa"/><w:tblBorders>
<w:top w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/><w:left w:val="single" w:sz="24" w:space="0" w:color="$script:RULE"/>
<w:bottom w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/><w:right w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/></w:tblBorders>
<w:tblCellMar><w:left w:w="10" w:type="dxa"/><w:right w:w="10" w:type="dxa"/></w:tblCellMar>
<w:tblLook w:val="04A0" w:firstRow="1" w:lastRow="0" w:firstColumn="1" w:lastColumn="0" w:noHBand="0" w:noVBand="1"/></w:tblPr>
<w:tblGrid><w:gridCol w:w="$script:CW"/></w:tblGrid>
<w:tr><w:tc><w:tcPr><w:tcW w:w="$script:CW" w:type="dxa"/>
<w:tcBorders><w:left w:val="single" w:sz="24" w:space="0" w:color="$script:RULE"/></w:tcBorders>
<w:shd w:val="clear" w:color="auto" w:fill="$script:FILL"/>
<w:tcMar><w:top w:w="80" w:type="dxa"/><w:left w:w="160" w:type="dxa"/><w:bottom w:w="80" w:type="dxa"/><w:right w:w="160" w:type="dxa"/></w:tcMar></w:tcPr>
$inner
</w:tc></w:tr></w:tbl>
"@
}

function HCallout {
    param([string]$Title,[string[]]$Lines,[string]$Fill = '',[string]$RuleColor = '')
    if (-not $Fill) { $Fill = $script:FILL }
    $lb = "<w:left w:val=`"single`" w:sz=`"4`" w:space=`"0`" w:color=`"$script:BORD`"/>"
    $tb = ''
    if ($RuleColor) {
        $lb = "<w:left w:val=`"single`" w:sz=`"24`" w:space=`"0`" w:color=`"$RuleColor`"/>"
        $tb = "<w:tcBorders><w:left w:val=`"single`" w:sz=`"24`" w:space=`"0`" w:color=`"$RuleColor`"/></w:tcBorders>"
    }
    $inner = ''
    if ($Title) { $inner += HPara -Runs (HRun -Text $Title -Bold -Color $script:NAVY -Size $script:SZ_CELL) -After 40 -KeepNext }
    foreach ($l in $Lines) {
        if ($null -eq $l -or $l -eq '') { continue }
        $inner += HPara -Runs (HRun -Text $l -Size $script:SZ_CELL) -After 60 -Line $script:LN_ONEHALF
    }
    @"
<w:tbl><w:tblPr><w:tblW w:w="$script:CW" w:type="dxa"/><w:tblBorders>
<w:top w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/>$lb
<w:bottom w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/><w:right w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/></w:tblBorders>
<w:tblCellMar><w:left w:w="10" w:type="dxa"/><w:right w:w="10" w:type="dxa"/></w:tblCellMar>
<w:tblLook w:val="04A0" w:firstRow="1" w:lastRow="0" w:firstColumn="1" w:lastColumn="0" w:noHBand="0" w:noVBand="1"/></w:tblPr>
<w:tblGrid><w:gridCol w:w="$script:CW"/></w:tblGrid>
<w:tr><w:tc><w:tcPr><w:tcW w:w="$script:CW" w:type="dxa"/>$tb
<w:shd w:val="clear" w:color="auto" w:fill="$Fill"/>
<w:tcMar><w:top w:w="90" w:type="dxa"/><w:left w:w="160" w:type="dxa"/><w:bottom w:w="90" w:type="dxa"/><w:right w:w="160" w:type="dxa"/></w:tcMar></w:tcPr>
$inner
</w:tc></w:tr></w:tbl>
"@
}

# A single writing cell. ModelAnswer, where given, prints in red in place of the
# placeholder - which is exactly how the house assessor guides do it.
function HAnswerBox {
    param([string]$Placeholder,[int]$Height = 0,[string]$ModelAnswer = '')
    if ($Height -le 0) { $Height = 2200 }
    if ($ModelAnswer) {
        # Points, not prose. A trainer marks against a list, not a paragraph.
        $inner = HModelAnswerLines -Model $ModelAnswer
        if (-not $inner) { $inner = '<w:p/>' }
        $Height = 0
    } else {
        $inner = HPara -Runs (HRun -Text $Placeholder -Italic -Color $script:PLACE -Size $script:SZ_CELL) -Line $script:LN_ONEHALF
    }
    $tr = ''
    if ($Height -gt 0) { $tr = "<w:trPr><w:trHeight w:val=`"$Height`"/></w:trPr>" }
    @"
<w:tbl><w:tblPr><w:tblW w:w="$script:CW" w:type="dxa"/><w:tblBorders>
<w:top w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/><w:left w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/>
<w:bottom w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/><w:right w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/></w:tblBorders>
<w:tblCellMar><w:left w:w="10" w:type="dxa"/><w:right w:w="10" w:type="dxa"/></w:tblCellMar>
<w:tblLook w:val="04A0" w:firstRow="1" w:lastRow="0" w:firstColumn="1" w:lastColumn="0" w:noHBand="0" w:noVBand="1"/></w:tblPr>
<w:tblGrid><w:gridCol w:w="$script:CW"/></w:tblGrid>
<w:tr>$tr<w:tc><w:tcPr><w:tcW w:w="$script:CW" w:type="dxa"/>
<w:tcMar><w:top w:w="100" w:type="dxa"/><w:left w:w="160" w:type="dxa"/><w:bottom w:w="100" w:type="dxa"/><w:right w:w="160" w:type="dxa"/></w:tcMar></w:tcPr>
$inner
</w:tc></w:tr></w:tbl>
"@
}

# ---------- tables ----------
# $Rows: array of string[] (cell text) or hashtable @{cells=@(); height=n}
function HTable {
    param(
        [string[]]$Headers,
        [int[]]$Widths,
        [array]$Rows,
        [int]$FontSize = 0,
        [int]$RowHeight = 0,
        [switch]$ShadeFirstCol,
        [string]$Placeholder = '',
        [switch]$NoHeaderFill,
        # Model answers written into an answer grid print in the model colour,
        # matching the red used in the open response boxes.
        [string]$AnswerColor = ''
    )
    if ($FontSize -le 0) { $FontSize = $script:SZ_CELL }
    $grid = ''
    foreach ($w in $Widths) { $grid += "<w:gridCol w:w=`"$w`"/>" }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append(@"
<w:tbl><w:tblPr><w:tblW w:w="$script:CW" w:type="dxa"/><w:tblBorders>
<w:top w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/><w:left w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/>
<w:bottom w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/><w:right w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/>
<w:insideH w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/><w:insideV w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/></w:tblBorders>
<w:tblLayout w:type="fixed"/>
<w:tblCellMar><w:left w:w="10" w:type="dxa"/><w:right w:w="10" w:type="dxa"/></w:tblCellMar>
<w:tblLook w:val="04A0" w:firstRow="1" w:lastRow="0" w:firstColumn="1" w:lastColumn="0" w:noHBand="0" w:noVBand="1"/></w:tblPr>
<w:tblGrid>$grid</w:tblGrid>
"@)
    if ($Headers -and $Headers.Count -gt 0) {
        [void]$sb.Append('<w:tr><w:trPr><w:tblHeader/></w:trPr>')
        for ($i = 0; $i -lt $Headers.Count; $i++) {
            $fill = $script:NAVY; $col = 'FFFFFF'
            if ($NoHeaderFill) { $fill = $script:FILL; $col = $script:NAVY }
            $p = HPara -Runs (HRun -Text $Headers[$i] -Bold -Color $col -Size $FontSize) -KeepNext -Before 20 -After 20 -Line $script:LN_SINGLE
            [void]$sb.Append(@"
<w:tc><w:tcPr><w:tcW w:w="$($Widths[$i])" w:type="dxa"/><w:shd w:val="clear" w:color="auto" w:fill="$fill"/>
<w:tcMar><w:top w:w="60" w:type="dxa"/><w:left w:w="120" w:type="dxa"/><w:bottom w:w="60" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar>
<w:vAlign w:val="center"/></w:tcPr>$p</w:tc>
"@)
        }
        [void]$sb.Append('</w:tr>')
    }
    foreach ($row in $Rows) {
        # A row arriving as a scalar string has .Count = 1 and $cells[0] is its
        # FIRST CHARACTER. One-column tables, and any -Rows a pipeline collapsed
        # to a single item, rendered one letter and dropped the rest, silently.
        $cells = @($row); $h = $RowHeight
        if ($row -is [hashtable]) { $cells = $row['cells']; if ($row.ContainsKey('height')) { $h = $row['height'] } }
        $trPr = ''
        if ($h -gt 0) { $trPr = "<w:trPr><w:trHeight w:val=`"$h`"/></w:trPr>" }
        [void]$sb.Append("<w:tr>$trPr")
        for ($i = 0; $i -lt $Widths.Count; $i++) {
            $txt = ''
            if ($i -lt $cells.Count) { $txt = [string]$cells[$i] }
            $shade = ''; $bold = $false; $va = ''; $cellCol = ''
            if ($AnswerColor -and $i -gt 0) { $cellCol = $AnswerColor }
            if ($ShadeFirstCol -and $i -eq 0) {
                $shade = "<w:shd w:val=`"clear`" w:color=`"auto`" w:fill=`"$script:FILL`"/>"
                $bold = $true; $va = '<w:vAlign w:val="center"/>'
            }
            $inner = ''
            if ($txt -eq '' -and $Placeholder -and -not ($ShadeFirstCol -and $i -eq 0)) {
                $inner = HPara -Runs (HRun -Text $Placeholder -Italic -Color $script:PLACE -Size $FontSize) -Line $script:LN_SINGLE
            } elseif ($txt -eq '') {
                $inner = '<w:p/>'
            } else {
                foreach ($ln in ($txt -split '\|\|')) {
                    $s = $ln.Trim()
                    if (-not $s) { continue }
                    if ($cellCol) {
                        # Answer-grid cells read as points, not prose. Bullet and
                        # tab, hanging so the wrap lines up under the text.
                        $runs  = HRun -Text $script:BUL -Color $cellCol -Size $FontSize
                        $runs += '<w:r><w:tab/></w:r>'
                        $runs += HRun -Text $s -Size $FontSize -Color $cellCol
                        $inner += HPara -Runs $runs -After 40 -Line $script:LN_SINGLE -IndLeft 200 -IndHang 200
                    } else {
                        $inner += HPara -Runs (HRun -Text $s -Size $FontSize -Bold:$bold) -After (Get-HouseSpacing).tableCellAfter -Line $script:LN_SINGLE
                    }
                }
                if (-not $inner) { $inner = '<w:p/>' }
            }
            [void]$sb.Append(@"
<w:tc><w:tcPr><w:tcW w:w="$($Widths[$i])" w:type="dxa"/>$shade
<w:tcMar><w:top w:w="60" w:type="dxa"/><w:left w:w="120" w:type="dxa"/><w:bottom w:w="60" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar>$va</w:tcPr>$inner</w:tc>
"@)
        }
        [void]$sb.Append('</w:tr>')
    }
    [void]$sb.Append('</w:tbl>')
    $sb.ToString()
}

function HSplitWidth {
    param([int]$Cols,[int[]]$Weights)
    if (-not $Weights) { $Weights = @(); for ($i=0;$i -lt $Cols;$i++) { $Weights += 1 } }
    $tot = 0; foreach ($w in $Weights) { $tot += $w }
    $out = @(); $acc = 0
    for ($i = 0; $i -lt $Cols; $i++) {
        if ($i -eq $Cols - 1) { $out += ($script:CW - $acc) }
        else { $v = [int][math]::Floor($script:CW * $Weights[$i] / $tot); $out += $v; $acc += $v }
    }
    ,$out
}

# ---------- assessor layer ----------
# The house assessor guides lead with this banner, before the cover sheet.
function HAssessorBanner {
    $t  = HPara -Runs (HRun -Text 'ASSESSOR VERSION - CONTAINS BENCHMARK ANSWERS' -Bold -Color $script:MODEL -Size 24) -After 40 -Align 'center'
    $t += HPara -Runs (HRun -Text 'Model answers are shown in red in the student response spaces. Do not issue this document to students.' -Size $script:SZ_CELL) -After 200 -Align 'center' -Line $script:LN_SINGLE
    $t
}

function HBenchmark {
    param([string]$Satisfactory,[string]$Minimum,[string]$Critical)
    $lines = @()
    if ($Satisfactory) { $lines += "What Satisfactory looks like: $Satisfactory" }
    if ($Minimum)      { $lines += "Minimum acceptable response: $Minimum" }
    if ($Critical)     { $lines += "Critical errors that force Not Satisfactory: $Critical" }
    if ($lines.Count -eq 0) { return '' }
    HCallout -Title 'Assessor benchmark' -Lines $lines -Fill 'FFF2CC' -RuleColor $script:RULE
}

# ---------- title page colour band - WITHDRAWN, DO NOT CALL ----------
# Four cells at 1927 DXA: F09C0C, F5C800, E45418, 606060.
#
# The band IS present in the RTO's older artefact, which is why an earlier note
# said to keep it. That was WITHDRAWN by the RTO on 21 August 2026: the band
# appears on none of the four documents. Kept here only so a future reader who
# measures the old artefact and finds a band does not re-derive this and
# reinstate it. ColourBand is a blocking verification check.
#
# Note it is a TABLE, not an image - searching for pictures does not find it.
function HColourBand {
    $cells = ''
    foreach ($c in @('F09C0C','F5C800','E45418','606060')) {
        $cells += "<w:tc><w:tcPr><w:tcW w:w=`"1927`" w:type=`"dxa`"/><w:shd w:val=`"clear`" w:color=`"auto`" w:fill=`"$c`"/></w:tcPr><w:p/></w:tc>"
    }
    @"
<w:tbl><w:tblPr><w:tblW w:w="7708" w:type="dxa"/><w:jc w:val="center"/>
<w:tblCellMar><w:left w:w="0" w:type="dxa"/><w:right w:w="0" w:type="dxa"/></w:tblCellMar>
<w:tblLook w:val="04A0" w:firstRow="0" w:lastRow="0" w:firstColumn="0" w:lastColumn="0" w:noHBand="0" w:noVBand="1"/></w:tblPr>
<w:tblGrid><w:gridCol w:w="1927"/><w:gridCol w:w="1927"/><w:gridCol w:w="1927"/><w:gridCol w:w="1927"/></w:tblGrid>
<w:tr><w:trPr><w:trHeight w:val="170"/><w:jc w:val="center"/></w:trPr>$cells</w:tr></w:tbl>
"@
}

function HPageBreakPara { '<w:p><w:r><w:br w:type="page"/></w:r></w:p>' }

# ---------- assessor panels that can actually be marked from ----------
# $script:BUL is declared once, above HRenderProse, which also needs it.

# One compact bullet line inside an assessor panel or a table cell. Tight
# leading and a hanging indent, so a six-point list stays scannable.
function HPanelBullet {
    param([string]$Text,[string]$Color = '',[int]$Size = 0)
    if ($Size -le 0) { $Size = $script:SZ_CELL }
    $runs  = "<w:r><w:rPr><w:b/><w:color w:val=`"$script:RULE`"/><w:sz w:val=`"$Size`"/></w:rPr><w:t>$script:BUL</w:t></w:r>"
    $runs += '<w:r><w:tab/></w:r>'
    $runs += HRun -Text $Text -Color $Color -Size $Size
    HPara -Runs $runs -After 40 -Line $script:LN_SINGLE -IndLeft 260 -IndHang 260
}

# An assessor panel built from labelled sections. Each section is
#   @{ label = 'Critical errors'; items = @('...','...') }   -> label + bullets
#   @{ label = 'Example comment'; text  = '...' }            -> label + one line
function HPanel {
    param([string]$Title,[array]$Sections,[string]$Fill = 'FFF2CC',[string]$RuleColor = '')
    if (-not $RuleColor) { $RuleColor = $script:RULE }
    $inner = ''
    if ($Title) { $inner += HPara -Runs (HRun -Text $Title -Bold -Color $script:NAVY -Size $script:SZ_CELL) -After 60 -KeepNext }
    foreach ($s in $Sections) {
        if ($null -eq $s) { continue }
        $lbl = $s['label']; $items = $s['items']; $txt = $s['text']
        if ($lbl) { $inner += HPara -Runs (HRun -Text $lbl -Bold -Color $script:NAVY -Size $script:SZ_SMALL) -Before 80 -After 30 -KeepNext -Line $script:LN_SINGLE }
        foreach ($it in @($items)) { if ($it) { $inner += HPanelBullet -Text ([string]$it) } }
        if ($txt) { $inner += HPara -Runs (HRun -Text ([string]$txt) -Size $script:SZ_CELL) -After 40 -Line $script:LN_SINGLE -IndLeft 260 }
    }
    @"
<w:tbl><w:tblPr><w:tblW w:w="$script:CW" w:type="dxa"/><w:tblBorders>
<w:top w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/><w:left w:val="single" w:sz="24" w:space="0" w:color="$RuleColor"/>
<w:bottom w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/><w:right w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/></w:tblBorders>
<w:tblCellMar><w:left w:w="10" w:type="dxa"/><w:right w:w="10" w:type="dxa"/></w:tblCellMar>
<w:tblLook w:val="04A0" w:firstRow="1" w:lastRow="0" w:firstColumn="1" w:lastColumn="0" w:noHBand="0" w:noVBand="1"/></w:tblPr>
<w:tblGrid><w:gridCol w:w="$script:CW"/></w:tblGrid>
<w:tr><w:tc><w:tcPr><w:tcW w:w="$script:CW" w:type="dxa"/>
<w:tcBorders><w:left w:val="single" w:sz="24" w:space="0" w:color="$RuleColor"/></w:tcBorders>
<w:shd w:val="clear" w:color="auto" w:fill="$Fill"/>
<w:tcMar><w:top w:w="90" w:type="dxa"/><w:left w:w="160" w:type="dxa"/><w:bottom w:w="90" w:type="dxa"/><w:right w:w="160" w:type="dxa"/></w:tcMar></w:tcPr>
$inner
</w:tc></w:tr></w:tbl>
"@
}

# Observation indicators as a side-by-side table. An assessor at the bench reads
# down one column, not through a paragraph.
function HIndicatorTable {
    param([string[]]$Satisfactory,[string[]]$NotSatisfactory)
    $wA = 4819; $wB = $script:CW - $wA
    function Cell2 { param([string[]]$items,[int]$width)
        $inner = ''
        foreach ($i in @($items)) { if ($i) { $inner += HPanelBullet -Text ([string]$i) } }
        if (-not $inner) { $inner = '<w:p/>' }
        "<w:tc><w:tcPr><w:tcW w:w=`"$width`" w:type=`"dxa`"/><w:tcMar><w:top w:w=`"70`" w:type=`"dxa`"/><w:left w:w=`"120`" w:type=`"dxa`"/><w:bottom w:w=`"70`" w:type=`"dxa`"/><w:right w:w=`"120`" w:type=`"dxa`"/></w:tcMar></w:tcPr>$inner</w:tc>"
    }
    $hA = HPara -Runs (HRun -Text 'Mark S when' -Bold -Color 'FFFFFF' -Size $script:SZ_CELL) -KeepNext -Before 20 -After 20 -Line $script:LN_SINGLE
    $hB = HPara -Runs (HRun -Text 'Mark NS when' -Bold -Color 'FFFFFF' -Size $script:SZ_CELL) -KeepNext -Before 20 -After 20 -Line $script:LN_SINGLE
    @"
<w:tbl><w:tblPr><w:tblW w:w="$script:CW" w:type="dxa"/><w:tblLayout w:type="fixed"/><w:tblBorders>
<w:top w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/><w:left w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/>
<w:bottom w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/><w:right w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/>
<w:insideH w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/><w:insideV w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/></w:tblBorders>
<w:tblCellMar><w:left w:w="10" w:type="dxa"/><w:right w:w="10" w:type="dxa"/></w:tblCellMar>
<w:tblLook w:val="04A0" w:firstRow="1" w:lastRow="0" w:firstColumn="0" w:lastColumn="0" w:noHBand="0" w:noVBand="1"/></w:tblPr>
<w:tblGrid><w:gridCol w:w="$wA"/><w:gridCol w:w="$wB"/></w:tblGrid>
<w:tr><w:trPr><w:tblHeader/></w:trPr>
<w:tc><w:tcPr><w:tcW w:w="$wA" w:type="dxa"/><w:shd w:val="clear" w:color="auto" w:fill="$script:NAVY"/><w:tcMar><w:top w:w="60" w:type="dxa"/><w:left w:w="120" w:type="dxa"/><w:bottom w:w="60" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar></w:tcPr>$hA</w:tc>
<w:tc><w:tcPr><w:tcW w:w="$wB" w:type="dxa"/><w:shd w:val="clear" w:color="auto" w:fill="$script:NAVY"/><w:tcMar><w:top w:w="60" w:type="dxa"/><w:left w:w="120" w:type="dxa"/><w:bottom w:w="60" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar></w:tcPr>$hB</w:tc>
</w:tr>
<w:tr>$(Cell2 $Satisfactory $wA)$(Cell2 $NotSatisfactory $wB)</w:tr></w:tbl>
"@
}

# Model answers print as points, in red, in the space the student would use.
function HModelAnswerLines {
    param([string]$Model)
    $out = ''
    foreach ($ln in ($Model -split "`n")) {
        $s = $ln.Trim()
        if (-not $s) { continue }
        $out += HPanelBullet -Text $s -Color $script:MODEL
    }
    $out
}
