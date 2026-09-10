#requires -Version 5.1
<#
    Restyle-Deck.ps1

    Takes the deck Invoke-Render just wrote and restyles it into the delivered
    visual language: flat pastel grounds that change slide to slide, hand-drawn
    wobbly outlined containers, the template's own two typefaces, one guide
    photograph or one scene illustration per slide, and figures set on the line
    of the words they lead.

    Every container is redrawn. Every word is kept: the text runs, the tables
    and the speaker notes come through untouched, because a delivery deck's
    content has been through the pack's gates and must not move. Test-DeckStyle
    reads the finished file back and fails the build if a run changed.

    The wobble is real geometry, not a picture - each container is a custGeom
    path whose anchors and control points are nudged by a seeded pseudo-random
    offset, so the outline reads as hand-drawn but rebuilds identically.

    Nothing here knows the unit. The only contract with the renderer is
    deckplan.json (Topic, Tag, Kind per slide) and the generator-constant slot
    geometry every deck this skill builds shares.

    Usage
      .\Restyle-Deck.ps1 -In build\out\XXX_Delivery_PowerPoint.pptx `
                        -PlanJson build\deckplan.json `
                        -GuideImgDir build\images -DoodleDir build\doodles
#>

[CmdletBinding()]
param(
    # The deck Invoke-Render just wrote, and where the restyled copy goes.
    # In place by default: the rendered deck is an intermediate, and the
    # restyled one is what is delivered.
    [Parameter(Mandatory = $true)][string] $In,
    [string] $Out,

    # deckplan.json exactly as Invoke-Render writes it - one entry per slide
    # carrying Topic, Tag and Kind. This is the whole contract between the
    # renderer and the restyle.
    [Parameter(Mandatory = $true)][string] $PlanJson,

    # The guide's photographs, from the docx-images stage. All of them are
    # staged into the package; which slide gets which comes from -PicturePlan.
    [string] $GuideImgDir,

    # picture-plan.json from New-DeckPicturePlan.ps1 - the per-slide decision of
    # photograph, illustration or nothing, made after counting each slide's
    # cards. Without it, no photograph is placed.
    [string] $PicturePlan,

    # Scene illustrations named DOODLE-<slide>-<name>.png, one per slide that
    # carries no photograph. New-DeckDoodles.ps1 writes them.
    [string] $DoodleDir,

    # Lines the build may delete from the cover, matched whole and trimmed.
    # Empty by default: the deck's content is audited and a general build does
    # not quietly drop a line. Pass the exact string to authorise one, and
    # Test-DeckStyle must be given the same list or it will fail the build.
    [string[]] $DropCoverLines = @(),

    [int] $Slides = 0                       # 0 = every slide in the deck
)

if (-not $Out) { $Out = $In }

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem

# ===========================================================================
#  Palette and grid
# ===========================================================================
$SLIDE_W = 12192000
$SLIDE_H = 6858000
$MARGIN  = 685800
$BAND_R  = $SLIDE_W - $MARGIN

# Read off the template's own Resource Page, not approximated: #C3DBFD,
# #FACAD3, #FA984C, #C4D682, #F6EBA5, on the cream its slides actually use.
$BLUE   = 'C3DBFD'
$PINK   = 'FACAD3'
$ORANGE = 'FA984C'
$SAGE   = 'C4D682'                 # the template's green - not the C4D6B2 guessed before
$YELLOW = 'F6EBA5'
$CREAM  = 'FFFCEB'                 # ditto: its ground is FFFCEB, not FDF6E3
$INK    = '000000'                 # and its outlines and type are true black

# The five pastels sit between 0.62 and 0.83 relative luminance; the accent
# orange sits at 0.43, well below the band. Used as a card fill it made one
# card in every row noticeably darker than its neighbours and dropped the
# body copy inside it to roughly half the contrast the other cards gave. The
# orange keeps its job as the accent - headings, connectors, the divider
# ground, where it is meant to be the loudest thing on the slide - and a tint
# of the same hue carries the card, at 0.69, in the middle of the band.
$PEACH  = 'FDD1AE'

$CARD_CYCLE = @($BLUE, $PINK, $PEACH, $SAGE, $YELLOW)

# Background per slide role, so the rhythm reads rather than merely rotating.
$BG_BY_KIND = @{
    'title'                  = $SAGE
    'agenda'                 = $CREAM
    'assessment-orientation' = $BLUE
    'divider'                = $ORANGE
    'outcomes'               = $YELLOW
    'teaching'               = $CREAM
    'figures'                = $BLUE
    'process'                = $CREAM
    'case-study'             = $PINK
    'table'                  = $BLUE
    'recap'                  = $SAGE
    'thanks'                 = $SAGE
}
$BG_ROTATE = @($CREAM, $BLUE, $SAGE, $YELLOW, $CREAM, $PINK)

# ---------------------------------------------------------------------------
#  Slide-role groupings - SELECTED from the one kind vocabulary, never retyped
#
#  Three role decisions below key off the slide kind: which kinds the cards
#  fill (so no picture is placed), which put their picture on the left, and
#  which carry the logo as a lockup. Each was a literal array typed into the
#  code at the point it was used, three separate lists free to name a kind this
#  file knows nothing about - and a kind misspelt in one of them fails SILENTLY,
#  because a kind that matches nothing simply keeps the default behaviour and
#  nothing is reported.
#
#  BG_BY_KIND above is this script's one kind vocabulary. Every grouping is now
#  selected from it BY NAME and refused if the name is not a member, and each
#  prints its size and the map it came from. deck-layouts.mvc.json is NOT read
#  here on purpose: this script's only contract with the renderer is
#  deckplan.json (see the header), and it knows neither the unit nor the RTO
#  profile.
function Select-DeckKind {
    param(
        [Parameter(Mandatory)][string] $What,
        [Parameter(Mandatory)][string[]] $Names
    )
    $unknown = @($Names | Where-Object { -not $BG_BY_KIND.ContainsKey($_) })
    if ($unknown.Count -gt 0) {
        throw ("Unknown slide kind(s) in the {0} set: {1}. Every role grouping is selected from BG_BY_KIND, this file's one kind vocabulary ({2} kind(s)); a grouping that names a kind the vocabulary does not carry matches nothing and reports nothing." -f $What, ($unknown -join ', '), $BG_BY_KIND.Count)
    }
    $set = @($Names)
    Write-Host ("  check-set: {0} {1}, derived from BG_BY_KIND ({2} kind(s))" -f $set.Count, $What, $BG_BY_KIND.Count) -ForegroundColor DarkGray
    return , $set
}

# The cards fill these layouts, so no picture is placed on them.
$KINDS_CARD_FILLED  = Select-DeckKind -What 'card-filled kind(s)'  -Names 'agenda', 'table', 'figures', 'process'
# The quote slides and the cover put their picture on the left.
$KINDS_PICTURE_LEFT = Select-DeckKind -What 'picture-left kind(s)' -Names 'case-study', 'title', 'thanks'
# The cover and closing slides carry the logo as a large lockup.
$KINDS_LOGO_LOCKUP  = Select-DeckKind -What 'logo-lockup kind(s)'  -Names 'title', 'thanks'

# The only text this build may delete, and only what the caller names. Empty by
# default. Whatever is passed must also be passed to Test-DeckStyle, so the
# check stays exact - measured against what was authorised, never switched off.
$COVER_DROP = @($DropCoverLines)

# The template's own two faces, named on its Resource Page: Sawarabi Mincho for
# titles, Questrial for body text. Neither is installed on this machine and
# neither needs to be - both travel inside the deck as embedded font parts,
# lifted from the template package itself, so the file carries its typography
# wherever it is opened.
# The template's own two faces, named on its Resource Page. Both are now
# installed on this machine from their official Google Fonts releases, so the
# deck is set in the literal typefaces rather than in stand-ins, and PowerPoint
# embeds them itself on save - which is what finally made the title face bind.
# Carrying them as the template's own EOT parts did not: the parts were in the
# package, correctly declared, and PowerPoint silently fell back for the Mincho.
$FONT_DISPLAY = 'Sawarabi Mincho'
$FONT_BODY    = 'Questrial'
$FONT_NUM     = 'Questrial'        # its figures are lining and even

# The template sets both faces regular - neither ships a bold - so nothing here
# is emboldened. Asking Windows to synthesise a weight over an embedded regular
# is what makes a carried font look wrong on someone else's machine.
function Get-BoldFor ([string] $Face) { return 0 }
function Get-MeasureStyle ([string] $Face) { return [System.Drawing.FontStyle]::Regular }

# Layout is measured with GDI, which cannot see a font it has not got, and
# silently substitutes one with quite different metrics. Each carried face is
# measured against its closest installed twin instead: Questrial is a geometric
# sans of Century Gothic's proportions, and Sawarabi Mincho's Latin is a
# transitional serif close to Book Antiqua. Both twins run slightly wide, which
# is the safe direction - it buys air rather than overflow.
# Empty now that both faces are installed: layout is measured in the same type
# it is set in. Keep the hook - a face that is named but not installed measures
# as a silent substitute with quite different metrics, and nothing errors.
$MEASURE_FACE = @{}
function Get-MeasureFace ([string] $Face) {
    if ($MEASURE_FACE.ContainsKey($Face)) { return $MEASURE_FACE[$Face] }
    return $Face
}

$STROKE_W   = 34925                # 2.75 pt, the template's outline weight

# One measurement each for the pieces of furniture that repeat slide to slide.
# Letting these be derived per slide is what put the same badge at five
# different sizes and the same chip at five different heights across twenty
# slides, which reads as a slip rather than as a rhythm.
$BADGE_D    = 640080               # every step badge is this circle
$BADGE_SZ   = 2000                 # and this numeral inside it

# A step number on a card-shaped card is set the way the statistics slides set
# theirs: large, in ink, across the full width of the card it belongs to, with
# no disc behind it. 58 pt is what the source uses for a figure on the
# temperatures slide, so the two read as the same thing done the same way.
# The disc survives on the agenda, where the number is a marker at the head of a
# wide bar and has nothing holding it once the disc goes.
$STEPNUM_SZ = 5800

# A figure and the words that name it share a line - and the figure is set in
# the SAME face and the SAME size as those words, so it reads as the first thing
# in the sentence rather than as a number the sentence is hanging off. At
# Daman's direction: the words take precedence, the figure does not get a size
# of its own. It stays a separate shape only because the gate compares text
# shape by shape and the source drew them apart.
$FIG_GAP       = 0                 # the two boxes' own insets are the word space
$CARD_PAD_X    = 182880            # and inside the card's left and right edges

# A free-standing section number - the "01" on a divider - is set from the
# source at 130 pt, which fills a quarter of the slide. It is a marker, not the
# content.
$SECTION_NUM_SZ = 7200
$CARD_FLOOR = 5486400              # no filled card reaches past this line
$CHIP_Y     = 5715000              # the assessment chip sits on this baseline
$FOOTER_Y   = 6263640              # and the footer on this one, 6.85 in

# The card row is fitted to its own copy and then centred in the band between
# the title and whatever stands below it, so a row of four short cards stops
# leaving the bottom third of the slide empty and a row of three deep ones
# stops leaving a pool of flat colour under the last line.
$CARD_PAD   = 274320               # 0.3 in of air inside a card, top and bottom
$CARD_MINH  = 1188720              # and no card is shorter than 1.3 in

# How wide a photograph runs, and the gutter between it and the copy beside it.
# The text column is derived from these rather than set to its own constant:
# holding the column at a width measured for the narrower drawings put the last
# word of every second line underneath the picture.
$ART_W       = 4297680             # 4.7 in
$ART_W_TITLE = 4663440             # the cover carries a larger one
$ART_GAP     = 274320

$NS = @{
    p   = 'http://schemas.openxmlformats.org/presentationml/2006/main'
    a   = 'http://schemas.openxmlformats.org/drawingml/2006/main'
    r   = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
    rel = 'http://schemas.openxmlformats.org/package/2006/relationships'
    ct  = 'http://schemas.openxmlformats.org/package/2006/content-types'
}
$XD = 'xmlns:a="' + $NS.a + '" xmlns:p="' + $NS.p + '" xmlns:r="' + $NS.r + '"'

# ===========================================================================
#  Helpers
# ===========================================================================
function New-Nsm ([xml] $Doc) {
    $m = New-Object System.Xml.XmlNamespaceManager($Doc.NameTable)
    foreach ($k in $NS.Keys) { $m.AddNamespace($k, $NS[$k]) }
    return , $m                      # XmlNamespaceManager enumerates; keep it whole
}

function Save-Xml ([xml] $Doc, [string] $Path) {
    $s = New-Object System.Xml.XmlWriterSettings
    $s.Encoding = New-Object System.Text.UTF8Encoding($false)
    $s.Indent   = $false
    $w = [System.Xml.XmlWriter]::Create($Path, $s)
    try { $Doc.Save($w) } finally { $w.Close() }
}

function Add-Frag ([xml] $Doc, [string] $Xml) {
    $f = $Doc.CreateDocumentFragment(); $f.InnerXml = $Xml; return $f.FirstChild
}

function Get-Attr ($Node, [string] $Name) {
    if ($null -eq $Node) { return $null }
    $v = $Node.GetAttribute($Name)
    if ([string]::IsNullOrEmpty($v)) { return $null }
    return $v
}

function Get-Box ($Node, $Nsm) {
    $xf = $Node.SelectSingleNode('./p:spPr/a:xfrm', $Nsm)
    if (-not $xf) { $xf = $Node.SelectSingleNode('./p:xfrm', $Nsm) }
    if (-not $xf) { $xf = $Node.SelectSingleNode('.//a:xfrm', $Nsm) }
    if (-not $xf) { return $null }
    $o = $xf.SelectSingleNode('a:off', $Nsm); $e = $xf.SelectSingleNode('a:ext', $Nsm)
    if (-not $o -or -not $e) { return $null }
    [pscustomobject]@{
        X = [int64](Get-Attr $o 'x'); Y = [int64](Get-Attr $o 'y')
        CX = [int64](Get-Attr $e 'cx'); CY = [int64](Get-Attr $e 'cy'); Xfrm = $xf
    }
}

function Set-Box ($Box, [int64] $X, [int64] $Y, [int64] $CX, [int64] $CY) {
    $o = $Box.Xfrm.SelectSingleNode('*[local-name()="off"]')
    $e = $Box.Xfrm.SelectSingleNode('*[local-name()="ext"]')
    $o.SetAttribute('x', [string]$X); $o.SetAttribute('y', [string]$Y)
    $e.SetAttribute('cx', [string]$CX); $e.SetAttribute('cy', [string]$CY)
}

function Get-Name ($Node, $Nsm) {
    $nv = $Node.SelectSingleNode('.//p:cNvPr', $Nsm)
    if (-not $nv) { return '' }
    return [string](Get-Attr $nv 'name')
}

function Set-ArtMargin {
    <#  Re-frames an illustration so it never touches the canvas edge.

        The image model will not reliably leave a margin however firmly it is
        asked: a wide subject fills the frame left-to-right, and re-prompting it
        upright just moves the clipping to the top and bottom. So the framing is
        normalised here instead - measure the alpha bounding box, crop to it,
        then re-canvas with an even border. Deterministic, and it fixes every
        illustration at once rather than one prompt at a time.  #>
    param([string] $Path, [double] $MarginPct = 0.06)
    $src = New-Object System.Drawing.Bitmap($Path)
    $w = $src.Width; $h = $src.Height
    $minX = $w; $maxX = -1; $minY = $h; $maxY = -1
    $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
    $bd = $src.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
                        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $len = $bd.Stride * $h
    $buf = New-Object byte[] $len
    [System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $buf, 0, $len)
    $src.UnlockBits($bd)
    for ($y = 0; $y -lt $h; $y++) {
        $row = $y * $bd.Stride
        for ($x = 0; $x -lt $w; $x++) {
            if ($buf[$row + ($x * 4) + 3] -gt 20) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    if ($maxX -lt 0) { $src.Dispose(); return }
    $cw = $maxX - $minX + 1; $ch = $maxY - $minY + 1
    $pad = [int][math]::Round([math]::Max($cw, $ch) * $MarginPct)
    $nw = $cw + (2 * $pad); $nh = $ch + (2 * $pad)
    $out = New-Object System.Drawing.Bitmap($nw, $nh, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($out)
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($src, (New-Object System.Drawing.Rectangle($pad, $pad, $cw, $ch)),
                       (New-Object System.Drawing.Rectangle($minX, $minY, $cw, $ch)),
                       [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose(); $src.Dispose()
    $out.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $out.Dispose()
}

function Get-TableHeight ($Node, $Nsm) {
    # A table's frame carries a placeholder height; what it actually occupies
    # is the sum of its row heights.
    $h = 0
    foreach ($r in $Node.SelectNodes('.//a:tr', $Nsm)) { $h += [int64](Get-Attr $r 'h') }
    return [int64]$h
}

function Set-Name ($Node, $Nsm, [string] $Name) {
    $nv = $Node.SelectSingleNode('.//p:cNvPr', $Nsm)
    if ($nv) { $nv.SetAttribute('name', $Name) }
}

function Get-Text ($Node, $Nsm) {
    $t = $Node.SelectNodes('.//a:t', $Nsm)
    if ($t.Count -eq 0) { return '' }
    return (($t | ForEach-Object { $_.InnerText }) -join ' ').Trim()
}

function Measure-TextH {
    <#  How deep a text box actually is once its copy has wrapped.

        Fitting a card to the box the source drew is what left three inches of
        flat colour under three lines of copy on one slide and half a slide of
        empty ground under a row of four on the next: the source boxes were
        sized for a different template. Measuring the copy itself is the only
        way to size the container to it, and the faces used here are installed,
        so GDI+ measures the same text PowerPoint will lay out.

        Deliberately generous - a short measurement makes copy overflow its
        card, a long one only adds air - so the graphics unit is points, the
        wrap width is the box's own, and the total carries ten per cent over.  #>
    param($Node, $Nsm, [int64] $WidthEmu, [string] $Face = '', [int] $SizeOverride = 0)

    if (-not $script:MeasureG) {
        $script:MeasureBmp = New-Object System.Drawing.Bitmap(8, 8)
        $script:MeasureG   = [System.Drawing.Graphics]::FromImage($script:MeasureBmp)
        $script:MeasureG.PageUnit = [System.Drawing.GraphicsUnit]::Point
    }
    $wPt = [single]([double]$WidthEmu / 12700.0)
    if ($wPt -lt 36) { $wPt = 36 }

    $total = 0.0
    foreach ($p in $Node.SelectNodes('.//a:p', $Nsm)) {
        $txt = ''
        foreach ($t in $p.SelectNodes('.//a:t', $Nsm)) { $txt += $t.InnerText }
        $sz = $SizeOverride
        if ($sz -le 0) {
            $rp = $p.SelectSingleNode('.//a:rPr', $Nsm)
            if ($rp) { $v = Get-Attr $rp 'sz'; if ($v) { $sz = [int]$v } }
        }
        if ($sz -le 0) { $sz = 1400 }
        $pt = $sz / 100.0
        if ($txt.Trim() -eq '') { $total += $pt * 0.7; continue }
        # NOT $face: PowerShell variable names are case-insensitive, so that
        # would overwrite the parameter on the first paragraph and every later
        # one would be measured in whatever the first happened to resolve to.
        $useFace = if ($Face) { $Face } else { $FONT_BODY }
        $font = New-Object System.Drawing.Font((Get-MeasureFace $useFace), [single]$pt, (Get-MeasureStyle $useFace))
        $s = $script:MeasureG.MeasureString($txt, $font, $wPt)
        $font.Dispose()
        $total += [double]$s.Height
    }
    if ($total -le 0) { $total = 14.0 }
    return [int64]([math]::Ceiling($total * 1.10 * 12700))
}

function Measure-TextW {
    <#  How wide the longest line would be if nothing wrapped it. Used to fit
        the title blob to its heading rather than to a per-character guess: the
        guess was calibrated against one face, and swapping the display face for
        a much wider one turned nine of twenty headings into a full line plus an
        orphan word. Measuring makes the fit survive the next font change too. #>
    param($Node, $Nsm, [string] $Face = '', [int] $SizeOverride = 0)

    if (-not $script:MeasureG) {
        $script:MeasureBmp = New-Object System.Drawing.Bitmap(8, 8)
        $script:MeasureG   = [System.Drawing.Graphics]::FromImage($script:MeasureBmp)
        $script:MeasureG.PageUnit = [System.Drawing.GraphicsUnit]::Point
    }
    $widest = 0.0
    foreach ($p in $Node.SelectNodes('.//a:p', $Nsm)) {
        $txt = ''
        foreach ($t in $p.SelectNodes('.//a:t', $Nsm)) { $txt += $t.InnerText }
        if ($txt.Trim() -eq '') { continue }
        $sz = $SizeOverride
        if ($sz -le 0) {
            $rp = $p.SelectSingleNode('.//a:rPr', $Nsm)
            if ($rp) { $v = Get-Attr $rp 'sz'; if ($v) { $sz = [int]$v } }
        }
        if ($sz -le 0) { $sz = 1400 }
        $useFace = if ($Face) { $Face } else { $FONT_BODY }
        $font = New-Object System.Drawing.Font((Get-MeasureFace $useFace), [single]($sz / 100.0), (Get-MeasureStyle $useFace))
        $s = $script:MeasureG.MeasureString($txt, $font)
        $font.Dispose()
        if ([double]$s.Width -gt $widest) { $widest = [double]$s.Width }
    }
    return [int64]([math]::Ceiling($widest * 12700))
}

function Test-IsFigure ($Item, $Nsm) {
    <#  Is this card's lead text a figure?

        Digits only was too narrow. The ordering-window slide leads its cards
        with "Thu 17", "Mon 14 + Wed 16" and "2:00 pm" - figures with a day or a
        meridiem attached - so they failed the test, kept the source's 58 pt and
        were printed straight over their own captions. A short piece of display
        type carrying a digit is a figure whatever else is in it.  #>
    if ($Item.Node.IsBadgeText) { return $true }
    $sz = 0
    $rp = $Item.Node.SelectSingleNode('.//a:rPr', $Nsm)
    if ($rp) { $v = Get-Attr $rp 'sz'; if ($v) { $sz = [int]$v } }
    if ($sz -lt 2400) { return $false }
    $t = [string]$Item.Text
    return ($t.Length -le 20 -and $t -match '\d')
}

function Get-InlineSz ($Item, $Nsm) {
    <#  The size a figure takes when it leads a line: whatever its own words are
        set at. The figure gets no size of its own.  #>
    $rp = $Item.Node.SelectSingleNode('.//a:rPr', $Nsm)
    if ($rp) { $v = Get-Attr $rp 'sz'; if ($v -and [int]$v -gt 0) { return [int]$v } }
    return 1400
}

function Get-BodyY {
    <#  Where a piece of free-standing copy ends up. Shared with the card
        balancer, which has to know what will be standing under the cards
        before it decides how far down they may run.  #>
    param([int64] $Y, [int64] $H, [bool] $HasChip)
    $newY = $Y
    if ($Y -lt 2011680 -and $Y -gt 1000000) { $newY = 2103120 }          # the lead-in
    elseif ($Y -ge 2011680 -and $Y -lt 6000000) { $newY = $Y + 640080 }
    if (($newY + $H) -gt 6172200) { $newY = [int64]([math]::Max(2103120, 6172200 - $H)) }
    # A note in the bottom band has to stop above the assessment chip. The
    # source's small print runs the full column width, so on the temperatures
    # slide the pill landed squarely on the end of the last line and took a
    # clause of it out.
    if ($HasChip -and $newY -gt 4114800) {
        $ceiling = [int64]($CHIP_Y - 320040 - $H)
        if ($newY -gt $ceiling) { $newY = [int64]([math]::Max(4114800, $ceiling)) }
    }
    return [int64]$newY
}

# ---------------------------------------------------------------------------
#  Wobbly geometry
# ---------------------------------------------------------------------------
$script:Rnd = 0
function Set-Seed ([int] $S) { $script:Rnd = [int](($S * 2654435761) % 2147483647) }
function Next-Jit ([int] $Amp) {
    # Small deterministic LCG. A blob must wobble the same way on every rebuild,
    # or a re-run silently reshuffles every outline in the deck.
    $script:Rnd = [int]((($script:Rnd * 1103515245) + 12345) % 2147483647)
    if ($script:Rnd -lt 0) { $script:Rnd = -$script:Rnd }
    return (($script:Rnd % (2 * $Amp + 1)) - $Amp)
}

function Get-BlobPath {
    <#  A rounded rectangle drawn as eight cubic segments in a 21600 grid, with
        every anchor and control point nudged so the outline reads as drawn by
        hand.

        The path grid is stretched to the shape's own box, so a corner radius
        and a jitter expressed in grid units come out five times wider than
        they are tall on a wide pill - which is what made the first pass lump
        at both ends. Both are therefore worked out in EMU and converted per
        axis. RadiusPct is of the SHORT side; 50 gives a true pill.  #>
    param([int] $Seed, [int64] $CX, [int64] $CY, [int] $RadiusPct = 24, [int64] $JitEmu = 40000)
    Set-Seed $Seed
    $G = 21600
    if ($CX -lt 1) { $CX = 1 }; if ($CY -lt 1) { $CY = 1 }

    $rEmu = [int64]([math]::Min($CX, $CY) * ($RadiusPct / 100.0))
    $rx = [int]([math]::Min($G / 2, [math]::Round($rEmu * $G / [double]$CX)))
    $ry = [int]([math]::Min($G / 2, [math]::Round($rEmu * $G / [double]$CY)))
    $ax = [int][math]::Max(40, [math]::Round($JitEmu * $G / [double]$CX))
    $ay = [int][math]::Max(40, [math]::Round($JitEmu * $G / [double]$CY))

    $pts = @(
        @{ X = $rx;      Y = 0 },        @{ X = $G - $rx; Y = 0 },
        @{ X = $G;       Y = $ry },      @{ X = $G;       Y = $G - $ry },
        @{ X = $G - $rx; Y = $G },       @{ X = $rx;      Y = $G },
        @{ X = 0;        Y = $G - $ry }, @{ X = 0;        Y = $ry }
    )
    $corners = @(
        @{ X = $G; Y = 0 }, @{ X = $G; Y = $G }, @{ X = 0; Y = $G }, @{ X = 0; Y = 0 }
    )

    $j = @()
    foreach ($p in $pts) { $j += @{ X = $p.X + (Next-Jit $ax); Y = $p.Y + (Next-Jit $ay) } }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append(('<a:moveTo><a:pt x="{0}" y="{1}"/></a:moveTo>' -f $j[0].X, $j[0].Y))

    for ($i = 0; $i -lt 8; $i++) {
        $from = $j[$i]
        $to   = $j[($i + 1) % 8]
        if ($i % 2 -eq 0) {
            # a straight edge, bowed slightly
            $c1x = $from.X + [int](($to.X - $from.X) / 3.0) + (Next-Jit $ax)
            $c1y = $from.Y + [int](($to.Y - $from.Y) / 3.0) + (Next-Jit $ay)
            $c2x = $from.X + [int](2 * ($to.X - $from.X) / 3.0) + (Next-Jit $ax)
            $c2y = $from.Y + [int](2 * ($to.Y - $from.Y) / 3.0) + (Next-Jit $ay)
        } else {
            $cn = $corners[[int](($i - 1) / 2)]
            $c1x = $cn.X + (Next-Jit ([int]($ax / 2)))
            $c1y = $cn.Y + (Next-Jit ([int]($ay / 2)))
            $c2x = $c1x + (Next-Jit ([int]($ax / 2)))
            $c2y = $c1y + (Next-Jit ([int]($ay / 2)))
        }
        [void]$sb.Append(('<a:cubicBezTo><a:pt x="{0}" y="{1}"/><a:pt x="{2}" y="{3}"/><a:pt x="{4}" y="{5}"/></a:cubicBezTo>' -f `
            $c1x, $c1y, $c2x, $c2y, $to.X, $to.Y))
    }
    [void]$sb.Append('<a:close/>')

    return ('<a:custGeom><a:avLst/><a:gdLst/><a:ahLst/><a:cxnLst/><a:rect l="0" t="0" r="21600" b="21600"/>' +
            '<a:pathLst><a:path w="21600" h="21600">' + $sb.ToString() + '</a:path></a:pathLst></a:custGeom>')
}

function Xml-Blob {
    param([int] $Id, [string] $Name, [int64] $X, [int64] $Y, [int64] $CX, [int64] $CY,
          [string] $Fill, [int] $Seed, [int] $CornerPct = 24, [int64] $Jit = 40000,
          [switch] $OutlineOnly, [string] $RId = '')
    $geom = Get-BlobPath -Seed $Seed -CX $CX -CY $CY -RadiusPct $CornerPct -JitEmu $Jit
    # A photograph fills the blob rather than sitting in a box of its own, so
    # the drawn path clips it and the picture picks up the same wobbly edge and
    # ink outline every other container on the slide has.
    $fillXml = if ($OutlineOnly) { '<a:noFill/>' }
               elseif ($RId) { ('<a:blipFill><a:blip r:embed="{0}"/><a:stretch><a:fillRect/></a:stretch></a:blipFill>' -f $RId) }
               else { ('<a:solidFill><a:srgbClr val="{0}"/></a:solidFill>' -f $Fill) }
    @"
<p:sp $XD>
<p:nvSpPr><p:cNvPr id="$Id" name="$Name"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
<p:spPr><a:xfrm><a:off x="$X" y="$Y"/><a:ext cx="$CX" cy="$CY"/></a:xfrm>$geom
$fillXml
<a:ln w="$STROKE_W" cap="rnd"><a:solidFill><a:srgbClr val="$INK"/></a:solidFill><a:round/></a:ln></p:spPr>
<p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody>
</p:sp>
"@
}

function Add-Blob {
    <#  Inserts ONE container: a single solid blob carrying a single ink
        outline. What makes it read as drawn by hand is the wobble in its own
        seeded Bezier path, not a doubled edge.

        An offset "ghost" outline was tried and is wrong. The template draws
        every container once; against the real thing the doubled edge reads
        heavier and busier than the design is, and where the shape it doubled
        already sat against a slide edge the ghost hung off the canvas, which
        Test-DeckStyle fails as a shape running past the slide. #>
    param($Doc, $Tree, $After, [ref] $NextId, [string] $Name,
          [int64] $X, [int64] $Y, [int64] $CX, [int64] $CY,
          [string] $Fill, [int] $Seed, [int] $CornerPct = 24, [int64] $Jit = 40000,
          [string] $RId = '')

    $node = $After

    $solid = Add-Frag $Doc (Xml-Blob -Id $NextId.Value -Name $Name `
                -X $X -Y $Y -CX $CX -CY $CY -Fill $Fill -Seed $Seed `
                -CornerPct $CornerPct -Jit $Jit -RId $RId)
    $NextId.Value++
    return $Tree.InsertAfter($solid, $node)
}

function Xml-Transition {
    # Morph, with a fade for builds that do not know it. Shapes named with a
    # "!!" prefix are force-matched between slides, so the title blob, the
    # eyebrow, the logo and the footer glide from one slide to the next
    # instead of blinking.
    @'
<mc:AlternateContent xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006">
<mc:Choice xmlns:p159="http://schemas.microsoft.com/office/powerpoint/2015/09/main" Requires="p159">
<p:transition xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:p14="http://schemas.microsoft.com/office/powerpoint/2010/main" spd="slow" p14:dur="900"><p159:morph option="byObject"/></p:transition>
</mc:Choice>
<mc:Fallback>
<p:transition xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" spd="slow"><p:fade/></p:transition>
</mc:Fallback>
</mc:AlternateContent>
'@
}

function Xml-Rect {
    param([int] $Id, [string] $Name, [int64] $X, [int64] $Y, [int64] $CX, [int64] $CY, [string] $Fill)
    @"
<p:sp $XD>
<p:nvSpPr><p:cNvPr id="$Id" name="$Name"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
<p:spPr><a:xfrm><a:off x="$X" y="$Y"/><a:ext cx="$CX" cy="$CY"/></a:xfrm>
<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
<a:solidFill><a:srgbClr val="$Fill"/></a:solidFill><a:ln><a:noFill/></a:ln></p:spPr>
<p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody>
</p:sp>
"@
}

function Xml-Pic {
    param([int] $Id, [string] $Name, [string] $RId,
          [int64] $X, [int64] $Y, [int64] $CX, [int64] $CY, [string] $Descr = 'Illustration')
    @"
<p:pic $XD>
<p:nvPicPr><p:cNvPr id="$Id" name="$Name" descr="$Descr"/><p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr>
<p:blipFill><a:blip r:embed="$RId"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>
<p:spPr><a:xfrm><a:off x="$X" y="$Y"/><a:ext cx="$CX" cy="$CY"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:ln><a:noFill/></a:ln></p:spPr>
</p:pic>
"@
}

# ---------------------------------------------------------------------------
#  Text restyling
# ---------------------------------------------------------------------------
function Set-RunStyle {
    param($Node, $Nsm, [xml] $Doc, [string] $Face, [string] $Colour,
          [int] $Size = 0, [int] $Bold = -1, [int] $Spc = -9999)
    # -Bold left off means "whatever this face wants": 1 for Arial, 0 for a face
    # that is already heavy. Decided here rather than at each of the eleven call
    # sites, several of which pick their face at run time from the run's size.
    $wantBold = if ($Bold -ge 0) { $Bold } else { Get-BoldFor $Face }
    foreach ($rPr in $Node.SelectNodes('.//a:rPr | .//a:defRPr | .//a:endParaRPr', $Nsm)) {
        if ($Size -gt 0) { $rPr.SetAttribute('sz', [string]$Size) }
        $rPr.SetAttribute('b', [string]$wantBold)
        if ($Spc -ne -9999) { $rPr.SetAttribute('spc', [string]$Spc) }
        foreach ($old in @($rPr.SelectNodes('a:solidFill', $Nsm))) { [void]$rPr.RemoveChild($old) }
        [void]$rPr.PrependChild((Add-Frag $Doc ('<a:solidFill xmlns:a="' + $NS.a + '"><a:srgbClr val="' + $Colour + '"/></a:solidFill>')))
        foreach ($tag in @('latin', 'ea', 'cs')) {
            $el = $rPr.SelectSingleNode("a:$tag", $Nsm)
            if (-not $el) { $el = $Doc.CreateElement('a', $tag, $NS.a); [void]$rPr.AppendChild($el) }
            $el.SetAttribute('typeface', $Face)
        }
    }
}

function Set-Centred ($Node, $Nsm, [switch] $Middle) {
    foreach ($pPr in $Node.SelectNodes('.//a:pPr', $Nsm)) { $pPr.SetAttribute('algn', 'ctr') }
    foreach ($p in $Node.SelectNodes('.//a:p', $Nsm)) {
        if (-not $p.SelectSingleNode('a:pPr', $Nsm)) {
            $pPr = $Node.OwnerDocument.CreateElement('a', 'pPr', $NS.a)
            $pPr.SetAttribute('algn', 'ctr')
            [void]$p.PrependChild($pPr)
        }
    }
    if ($Middle) {
        $bp = $Node.SelectSingleNode('.//a:bodyPr', $Nsm)
        if ($bp) { $bp.SetAttribute('anchor', 'ctr') }
    }
}

function Set-Align ($Node, $Nsm, [string] $Algn = 'l', [string] $Anchor = 't') {
    foreach ($p in $Node.SelectNodes('.//a:p', $Nsm)) {
        $pPr = $p.SelectSingleNode('a:pPr', $Nsm)
        if (-not $pPr) {
            $pPr = $Node.OwnerDocument.CreateElement('a', 'pPr', $NS.a)
            [void]$p.PrependChild($pPr)
        }
        $pPr.SetAttribute('algn', $Algn)
    }
    $bp = $Node.SelectSingleNode('.//a:bodyPr', $Nsm)
    if ($bp) { $bp.SetAttribute('anchor', $Anchor) }
}

function Remove-Bullets ($Node, $Nsm) {
    foreach ($pPr in $Node.SelectNodes('.//a:pPr', $Nsm)) {
        foreach ($b in @($pPr.SelectNodes('a:buChar | a:buAutoNum | a:buFont | a:buNone', $Nsm))) {
            [void]$pPr.RemoveChild($b)
        }
        [void]$pPr.AppendChild($Node.OwnerDocument.CreateElement('a', 'buNone', $NS.a))
        $pPr.SetAttribute('marL', '0'); $pPr.SetAttribute('indent', '0')
    }
}

# ===========================================================================
#  Plan
# ===========================================================================
$plan = @()
$plan += (Get-Content $PlanJson -Raw -Encoding UTF8 | ConvertFrom-Json)
if ($plan.Count -lt 2) { throw "deck-plan.json did not load as a list" }

function Get-Kind ([int] $I) {
    if ($I -lt 1 -or $I -gt $plan.Count) { return 'teaching' }
    return [string]$plan[$I - 1].Kind
}

# ---------------------------------------------------------------------------
#  Which picture each slide carries
# ---------------------------------------------------------------------------
#  Decided by New-DeckPicturePlan, not here. Whether a slide can hold a picture
#  depends on how many cards the renderer put on it, which is only knowable by
#  reading the slide XML - and deciding without that assigns photographs to
#  slides that turn out to be full, where they are then dropped with nothing
#  reported. The plan is computed once, published, and read by both this script
#  and the doodle authoring, so the two cannot disagree.
$PhotoPlan     = @{}
$DoodleBySlide = @{}

if ($PicturePlan) {
    $pp = @()
    $pp += (Get-Content -LiteralPath $PicturePlan -Raw -Encoding UTF8 | ConvertFrom-Json)
    foreach ($row in $pp) {
        if ([string]$row.kind -eq 'photo' -and $row.file) { $PhotoPlan[[int]$row.slide] = [string]$row.file }
    }
}

# Scene illustrations name the slide they were drawn for, so each is placed
# there rather than handed out in order. That is what keeps the drawing on the
# material it illustrates.
if ($DoodleDir) {
    foreach ($f in (Get-ChildItem $DoodleDir -Filter 'DOODLE-*.png' -ErrorAction SilentlyContinue)) {
        $m = [regex]::Match($f.BaseName, '^DOODLE-(\d+)-')
        if ($m.Success) { $DoodleBySlide[[int]$m.Groups[1].Value] = $f.BaseName }
    }
}
$ArtPlan = @{}
for ($q = 1; $q -le $plan.Count; $q++) {
    $row   = $plan[$q - 1]
    $kind  = [string]$row.Kind
    if ($kind -in $KINDS_CARD_FILLED) { continue }   # the cards fill these

    # The quote slides and the cover put their picture on the left, so the words
    # are not always in the same place for ninety-eight slides running.
    $side = if ($kind -in $KINDS_PICTURE_LEFT) { 'left' } else { 'right' }

    if ($PhotoPlan.ContainsKey($q)) {
        $ArtPlan[$q] = @{ File = $PhotoPlan[$q]; Side = $side; Kind = 'photo' }
    }
    elseif ($DoodleBySlide.ContainsKey($q)) {
        $ArtPlan[$q] = @{ File = $DoodleBySlide[$q]; Side = $side; Kind = 'doodle' }
    }
}

# ===========================================================================
#  Unpack, and trim only if a sample length was asked for
# ===========================================================================
# -Slides exists to render a short sample for review without waiting on the
# whole deck. Left at 0 - which is the delivered case - every slide is kept.
if ($Slides -le 0) { $Slides = [int]::MaxValue }
$work = Join-Path ([System.IO.Path]::GetTempPath()) ('deckstyle_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
[System.IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path $In).Path, $work)
Write-Host ("unpacked -> {0}" -f $work)

# Drop slides past the sample length from presentation.xml and its rels.
$presPath = Join-Path $work 'ppt\presentation.xml'
[xml]$pres = [System.IO.File]::ReadAllText($presPath)
$pnsm = New-Nsm $pres
$sldIdLst = $pres.SelectSingleNode('//p:sldIdLst', $pnsm)
$ids = @($sldIdLst.ChildNodes)
$keepRIds = @()
for ($i = 0; $i -lt $ids.Count; $i++) {
    if ($i -lt $Slides) { $keepRIds += [string]$ids[$i].GetAttribute('id', $NS.r) }
    else { [void]$sldIdLst.RemoveChild($ids[$i]) }
}
Save-Xml $pres $presPath

$presRelPath = Join-Path $work 'ppt\_rels\presentation.xml.rels'
[xml]$presRels = [System.IO.File]::ReadAllText($presRelPath)
$slideTargets = @{}
foreach ($rel in @($presRels.Relationships.Relationship)) {
    if ($rel.Type -notlike '*relationships/slide') { continue }
    if ($keepRIds -contains $rel.Id) { $slideTargets[$rel.Id] = $rel.Target }
    else { [void]$presRels.Relationships.RemoveChild($rel) }
}
Save-Xml $presRels $presRelPath

$keepFiles = @()
foreach ($rid in $keepRIds) { $keepFiles += (Split-Path $slideTargets[$rid] -Leaf) }

# remove the slide parts we are not shipping, plus their notes
$ctPath = Join-Path $work '[Content_Types].xml'
[xml]$ct = [System.IO.File]::ReadAllText($ctPath)
foreach ($f in (Get-ChildItem (Join-Path $work 'ppt\slides') -Filter 'slide*.xml')) {
    if ($keepFiles -contains $f.Name) { continue }
    $relF = Join-Path (Join-Path $work 'ppt\slides\_rels') ($f.Name + '.rels')
    if (Test-Path $relF) {
        [xml]$rr = [System.IO.File]::ReadAllText($relF)
        foreach ($rel in @($rr.Relationships.Relationship)) {
            if ($rel.Type -like '*notesSlide') {
                $nf = Join-Path (Join-Path $work 'ppt\slides') $rel.Target
                $nf = [System.IO.Path]::GetFullPath($nf)
                if (Test-Path $nf) {
                    $nrel = Join-Path (Join-Path (Split-Path $nf) '_rels') ((Split-Path $nf -Leaf) + '.rels')
                    Remove-Item $nf -Force
                    if (Test-Path $nrel) { Remove-Item $nrel -Force }
                }
            }
        }
        Remove-Item $relF -Force
    }
    Remove-Item $f.FullName -Force
}
# strip the Override entries for parts that no longer exist
foreach ($ov in @($ct.Types.ChildNodes)) {
    if ($ov.LocalName -ne 'Override') { continue }
    $pn = [string]$ov.PartName
    $local = Join-Path $work ($pn.TrimStart('/') -replace '/', '\')
    if (-not (Test-Path $local)) { [void]$ct.Types.RemoveChild($ov) }
}
foreach ($pair in @(@('png', 'image/png'), @('jpg', 'image/jpeg'), @('jpeg', 'image/jpeg'))) {
    $have = $false
    foreach ($d in $ct.Types.ChildNodes) {
        if ($d.LocalName -eq 'Default' -and $d.Extension -eq $pair[0]) { $have = $true }
    }
    if ($have) { continue }
    $el = $ct.CreateElement('Default', $NS.ct)
    $el.SetAttribute('Extension', $pair[0]); $el.SetAttribute('ContentType', $pair[1])
    [void]$ct.Types.PrependChild($el)
}
Save-Xml $ct $ctPath

# ---------------------------------------------------------------------------
#  Stage the photographs
# ---------------------------------------------------------------------------
#  The deck takes the learner guide's OWN photographs, so a learner meets the
#  same picture on the screen and on the page - which is the point of building
#  the two resources from one spine. Each is set inside a hand-drawn container
#  further down rather than floating on the ground: a bare rectangular
#  photograph dropped on a flat pastel slide reads as pasted on.
$mediaDir = Join-Path $work 'ppt\media'
$ArtMedia = @{}
$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
             Where-Object { $_.MimeType -eq 'image/jpeg' } | Select-Object -First 1
foreach ($f in (Get-ChildItem $GuideImgDir -Filter 'IMG-*.jpg' -ErrorAction SilentlyContinue | Sort-Object Name)) {
    $key    = ($f.BaseName -split '_')[0]          # IMG-007_illustration -> IMG-007
    $target = 'guide-' + $key + '.jpg'
    $dest   = Join-Path $mediaDir $target
    # Placed about 3.5 in wide, 1200 px is already ~340 dpi. The guide's own
    # 1536 px masters would add nothing on a projector and a megabyte a slide.
    $img = [System.Drawing.Image]::FromFile($f.FullName)
    $w = $img.Width; $h = $img.Height
    $scale = [math]::Min(1.0, 1200.0 / [math]::Max($w, $h))
    $nw = [int]([math]::Round($w * $scale)); $nh = [int]([math]::Round($h * $scale))
    $bmp = New-Object System.Drawing.Bitmap($nw, $nh, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle(0, 0, $nw, $nh)))
    $g.Dispose(); $img.Dispose()
    # Photographs stay JPEG. Re-encoded as PNG - which is what the vector
    # illustrations needed for their transparency - these came out several times
    # the size for no gain, because there is no flat colour in them to pack.
    $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
                       [System.Drawing.Imaging.Encoder]::Quality, [int64]84)
    $bmp.Save($dest, $jpegCodec, $ep)
    $ep.Dispose(); $bmp.Dispose()
    $ArtMedia[$key] = [pscustomobject]@{ File = $target; W = $nw; H = $nh }
}
Write-Host ("staged {0} guide photograph(s)" -f $ArtMedia.Count)

# The scene illustrations. Flat artwork on transparency, so PNG with its alpha
# kept - but the generator returns them at about 1.5 MB each, which would put
# 53 MB into a deck for no visible gain. Resampled to the size they are placed
# at and posterised to 16 levels a channel, they lose nothing: the fills were
# flat to begin with, and the only thing sixteen levels cannot hold is a
# gradient there isn't one of.
$nDood = 0
foreach ($f in (Get-ChildItem $DoodleDir -Filter 'DOODLE-*.png' -ErrorAction SilentlyContinue)) {
    $target = 'doodle-' + $f.BaseName + '.png'
    $dest   = Join-Path $mediaDir $target

    $img = [System.Drawing.Image]::FromFile($f.FullName)
    $sc  = [math]::Min(1.0, 900.0 / [math]::Max($img.Width, $img.Height))
    $nw  = [int]([math]::Round($img.Width * $sc)); $nh = [int]([math]::Round($img.Height * $sc))
    $bmp = New-Object System.Drawing.Bitmap($nw, $nh, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle(0, 0, $nw, $nh)))
    $g.Dispose(); $img.Dispose()

    $rect = New-Object System.Drawing.Rectangle(0, 0, $nw, $nh)
    $bd = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, $bmp.PixelFormat)
    $len = [math]::Abs($bd.Stride) * $nh
    $buf = New-Object byte[] $len
    [Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $buf, 0, $len)
    for ($p = 0; $p -lt $len; $p += 4) {
        # BGRA. Alpha snaps to fully on or fully off, so the cut-out edge stays
        # crisp instead of carrying a halo of the ground it was drawn against.
        if ($buf[$p + 3] -lt 128) { $buf[$p] = 0; $buf[$p+1] = 0; $buf[$p+2] = 0; $buf[$p+3] = 0; continue }
        $buf[$p + 3] = 255
        $buf[$p]     = [byte](($buf[$p]     -band 0xF0) -bor (($buf[$p]     -shr 4) -band 0x0F))
        $buf[$p + 1] = [byte](($buf[$p + 1] -band 0xF0) -bor (($buf[$p + 1] -shr 4) -band 0x0F))
        $buf[$p + 2] = [byte](($buf[$p + 2] -band 0xF0) -bor (($buf[$p + 2] -shr 4) -band 0x0F))
    }
    [Runtime.InteropServices.Marshal]::Copy($buf, 0, $bd.Scan0, $len)
    $bmp.UnlockBits($bd)
    $bmp.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()

    $ArtMedia[$f.BaseName] = [pscustomobject]@{ File = $target; W = $nw; H = $nh }
    $nDood++
}
Write-Host ("staged {0} scene doodle(s)" -f $nDood)

# ---------------------------------------------------------------------------
#  Theme fonts
# ---------------------------------------------------------------------------
foreach ($tf in (Get-ChildItem (Join-Path $work 'ppt\theme') -Filter 'theme*.xml')) {
    $t = [System.IO.File]::ReadAllText($tf.FullName)
    $t = [regex]::Replace($t, '(<a:majorFont>\s*<a:latin typeface=")[^"]*(")', ('${1}' + $FONT_DISPLAY + '${2}'))
    $t = [regex]::Replace($t, '(<a:minorFont>\s*<a:latin typeface=")[^"]*(")', ('${1}' + $FONT_BODY + '${2}'))
    [System.IO.File]::WriteAllText($tf.FullName, $t, (New-Object System.Text.UTF8Encoding($false)))
}

# ===========================================================================
#  Rebuild each slide
# ===========================================================================
$slideFiles = @()
foreach ($f in $keepFiles) { $slideFiles += (Get-Item (Join-Path (Join-Path $work 'ppt\slides') $f)) }

$report = @()

for ($n = 0; $n -lt $slideFiles.Count; $n++) {
    $sf   = $slideFiles[$n]
    $idx  = $n + 1
    $kind = Get-Kind $idx

    [xml]$doc = [System.IO.File]::ReadAllText($sf.FullName)
    $nsm  = New-Nsm $doc
    $tree = $doc.SelectSingleNode('/p:sld/p:cSld/p:spTree', $nsm)

    $maxId = 1
    foreach ($nv in $doc.SelectNodes('//p:cNvPr', $nsm)) {
        $v = [int](Get-Attr $nv 'id'); if ($v -gt $maxId) { $maxId = $v }
    }
    $nextId = $maxId + 1

    $bg = $BG_BY_KIND[$kind]
    if (-not $bg) { $bg = $BG_ROTATE[$idx % $BG_ROTATE.Count] }
    $isDivider = ($kind -eq 'divider')

    # ---- inventory ----------------------------------------------------
    $furn  = @{}
    $fills = @()      # decorative filled shapes, to become blobs
    $texts = @()
    $others = @()
    $emptyRowYs = @()
    $script:cardTextSeq = 0
    $script:arrowSeq    = 0

    foreach ($node in @($tree.ChildNodes)) {
        if ($node.LocalName -in @('nvGrpSpPr', 'grpSpPr')) { continue }
        $name = Get-Name $node $nsm
        $box  = Get-Box $node $nsm
        $txt  = Get-Text $node $nsm

        if ($name -eq 'LG Assessment Link Chip') { $furn['chip'] = $node; continue }
        if ($name -eq 'LG Assessment Link Rule') { [void]$tree.RemoveChild($node); continue }

        # the cover and closing slides carry the logo as a large lockup
        if ($node.LocalName -eq 'pic' -and $kind -in $KINDS_LOGO_LOCKUP) {
            $furn['logo'] = $node; continue
        }

        if ($box) {
            if ($box.Y -eq 457200  -and $box.CX -eq 603504  -and $node.LocalName -eq 'sp')  { [void]$tree.RemoveChild($node); continue }
            if ($box.Y -eq 541691  -and $node.LocalName -eq 'pic')                          { [void]$tree.RemoveChild($node); continue }
            if ($box.Y -eq 420624  -and $box.X -eq 1280160)  { $furn['eyebrow'] = $node; continue }
            if ($box.Y -eq 676656  -and $box.X -eq 1280160)  { $furn['title']   = $node; continue }
            if ($box.Y -eq 292608  -and $box.X -eq 9933127)  { [void]$tree.RemoveChild($node); continue }
            if ($box.Y -eq 384048  -and $box.X -eq 10042855) { $furn['logo']    = $node; continue }
            if ($box.Y -eq 5188662 -and $node.LocalName -eq 'sp')  { [void]$tree.RemoveChild($node); continue }
            if ($box.Y -eq 5280102 -and $node.LocalName -eq 'pic') { $furn['logo'] = $node; continue }
            if ($box.Y -eq 6355080)                          { [void]$tree.RemoveChild($node); continue }
            if ($box.Y -eq 6400800 -and $box.X -eq 502920)   { $furn['brand']  = $node; continue }
            if ($box.Y -eq $FOOTER_Y -and $box.X -eq 841248)   { $furn['brand']  = $node; continue }
            if ($box.Y -eq 6400800 -and $box.X -eq 11231575) { $furn['pageNo'] = $node; continue }
        }

        if ($node.LocalName -eq 'sp') {
            $hasFill = $null -ne $node.SelectSingleNode('./p:spPr/a:solidFill', $nsm)
            if ($txt -eq '' -and $hasFill -and $box) {
                # thin accent stripes and full-bleed bars go; real cards become blobs
                if ($box.CY -le 200000 -or $box.CX -le 400000 -or $box.CX -ge ($SLIDE_W - 1)) {
                    [void]$tree.RemoveChild($node); continue
                }
                $fills += [pscustomobject]@{ Node = $node; Box = $box }
                continue
            }
            if ($txt -eq '' -and $box -and $box.Y -gt 1000000) {
                # an unfilled row - the agenda ships two of them
                $emptyRowYs += [int64]$box.Y
                [void]$tree.RemoveChild($node); continue
            }
            # The source sets a small arrow between process steps. At this size
            # it renders as a speck between the cards; the numbered badges
            # already carry the sequence, so it goes.
            # The connector arrows between process steps render as specks at
            # the source's size. Tag them here and set them properly below
            # rather than deleting them - they are still content, and the gate
            # is right to fail a build that quietly drops a run.
            #
            # Written as escapes, not as the glyphs themselves: this file is
            # UTF-8 without a BOM, so PowerShell 5.1 reads any literal arrow as
            # ANSI and the character class comes out reversed and unparseable.
            if ($txt -match '^[\u2190-\u21FF\u2794-\u27BF>\-=\s]+$') {
                $node | Add-Member -NotePropertyName IsArrow -NotePropertyValue $true -Force
            }
            if ($txt -ne '') { $texts += [pscustomobject]@{ Node = $node; Box = $box; Text = $txt }; continue }
        }
        $others += [pscustomobject]@{ Node = $node; Box = $box }
    }

    # A fill that shared its row with an empty text box was decorating nothing.
    $live = @()
    foreach ($fl in $fills) {
        $orphan = $false
        foreach ($y in $emptyRowYs) { if ([int64]$y -eq [int64]$fl.Box.Y) { $orphan = $true } }
        if ($orphan) { [void]$tree.RemoveChild($fl.Node) } else { $live += $fl }
    }
    $fills = $live

    # The closing slide carried a row of five blank pastel cards - a palette
    # swatch, which is what a template ships to show its colours, not something
    # a delivery deck closes on. They go, and the college mark takes the space.
    if ($kind -eq 'thanks') {
        foreach ($fl in $fills) { [void]$tree.RemoveChild($fl.Node) }
        $fills = @()
    }

    # The cover is laid out from scratch, so its decoration goes entirely.
    if ($kind -eq 'title') {
        foreach ($fl in $fills) { [void]$tree.RemoveChild($fl.Node) }
        $fills = @()

        # and the declared drop comes off it, by paragraph
        foreach ($t in $texts) {
            foreach ($pp in @($t.Node.SelectNodes('.//a:p', $nsm))) {
                $ptxt = ''
                foreach ($tt in $pp.SelectNodes('.//a:t', $nsm)) { $ptxt += $tt.InnerText }
                if ($COVER_DROP -contains $ptxt.Trim()) { [void]$pp.ParentNode.RemoveChild($pp) }
            }
        }
        $live = @()
        foreach ($t in $texts) {
            if ((Get-Text $t.Node $nsm) -eq '') { [void]$tree.RemoveChild($t.Node); continue }
            $live += $t
        }
        $texts = $live
    }

    # Where the content starts, so the title blob can be sized to the gap above it.
    $contentTop = $SLIDE_H
    foreach ($c in ($fills + $texts + $others)) {
        if (-not $c.Box) { continue }
        if ($c.Box.Y -lt 900000 -or $c.Box.Y -gt 6000000) { continue }
        if ($c.Box.Y -lt $contentTop) { $contentTop = $c.Box.Y }
    }
    if ($contentTop -ge $SLIDE_H) { $contentTop = 2286000 }

    # ---- background ---------------------------------------------------
    $bgNode = $doc.SelectSingleNode('/p:sld/p:cSld/p:bg', $nsm)
    if ($bgNode) {
        $f = $bgNode.SelectSingleNode('.//a:solidFill/a:srgbClr', $nsm)
        if ($f) { $f.SetAttribute('val', $bg) }
    } else {
        $b = Add-Frag $doc ('<p:bg xmlns:p="' + $NS.p + '" xmlns:a="' + $NS.a + '"><p:bgPr><a:solidFill><a:srgbClr val="' + $bg + '"/></a:solidFill><a:effectLst/></p:bgPr></p:bg>')
        [void]$doc.SelectSingleNode('/p:sld/p:cSld', $nsm).PrependChild($b)
    }

    $anchor = $tree.SelectSingleNode('./p:grpSpPr', $nsm)
    $last = $anchor
    $seed = $idx * 1000

    # ---- decorative cards become wobbly blobs -------------------------
    # The source deck sets a white glyph in a coloured disc on each card. This
    # template has no icons of that sort, and a white PNG cannot be recoloured
    # to suit a pastel ground, so the disc and its glyph both go. A small round
    # fill that holds TEXT is different - that is a step number, and it stays.
    $live = @()
    foreach ($fl in $fills) {
        $isRound = ([math]::Abs($fl.Box.CX - $fl.Box.CY) -lt 60000)
        if (-not ($isRound -and $fl.Box.CX -lt 1100000)) { $live += $fl; continue }
        $holdsText = $false
        foreach ($t in $texts) {
            if (-not $t.Box) { continue }
            $cx = $t.Box.X + [int64]($t.Box.CX / 2); $cy = $t.Box.Y + [int64]($t.Box.CY / 2)
            if ($cx -ge $fl.Box.X -and $cx -le ($fl.Box.X + $fl.Box.CX) -and
                $cy -ge $fl.Box.Y -and $cy -le ($fl.Box.Y + $fl.Box.CY)) { $holdsText = $true }
        }
        if ($holdsText) { $live += $fl; continue }
        foreach ($o in @($others)) {
            if ($o.Node.LocalName -ne 'pic' -or -not $o.Box) { continue }
            if ($o.Box.X -ge ($fl.Box.X - 45720) -and $o.Box.Y -ge ($fl.Box.Y - 45720) -and
                ($o.Box.X + $o.Box.CX) -le ($fl.Box.X + $fl.Box.CX + 45720)) {
                [void]$tree.RemoveChild($o.Node)
            }
        }
        [void]$tree.RemoveChild($fl.Node)
    }
    $fills = $live

    # Cards are numbered left to right, then top to bottom, so the pop-in
    # sequence added afterwards reads in the order a person would.
    $ordered = @($fills | Sort-Object { [int64]$_.Box.Y * 20 + [int64]$_.Box.X })

    # A shape small enough to be a badge and holding nothing but a figure is a
    # step number, not a card. Those get one consistent treatment across the
    # deck - a true ink circle with the numeral reversed out of it - instead of
    # taking the next colour off the card cycle and reading as a box in a box.
    foreach ($fl in $ordered) {
        $fl | Add-Member -NotePropertyName IsBadge -NotePropertyValue $false -Force
        if ($fl.Box.CX -gt 1200000 -or $fl.Box.CY -gt 1200000) { continue }
        foreach ($t in $texts) {
            if (-not $t.Box) { continue }
            $cx = $t.Box.X + [int64]($t.Box.CX / 2); $cy = $t.Box.Y + [int64]($t.Box.CY / 2)
            if ($cx -ge $fl.Box.X -and $cx -le ($fl.Box.X + $fl.Box.CX) -and
                $cy -ge $fl.Box.Y -and $cy -le ($fl.Box.Y + $fl.Box.CY) -and
                $t.Text -match '^\s*\d{1,2}\s*$') {
                $fl.IsBadge = $true
                $t.Node | Add-Member -NotePropertyName IsBadgeText -NotePropertyValue $true -Force
            }
        }
    }

    # The agenda was drawn for five rows and ships with three, so the block
    # sits in the top half with a third of the slide empty under it. Space the
    # rows it actually has across the content area instead.
    if ($kind -eq 'agenda') {
        $rowYs = @()
        foreach ($fl in $fills) {
            if ($fl.Box.CX -lt 8000000) { continue }
            if ($rowYs -notcontains [int64]$fl.Box.Y) { $rowYs += [int64]$fl.Box.Y }
        }
        $rowYs = @($rowYs | Sort-Object)
        if ($rowYs.Count -ge 2) {
            $top = 1600200; $bottom = 5334000
            $rowH = 0
            foreach ($fl in $fills) { if ($fl.Box.CX -ge 8000000 -and $fl.Box.CY -gt $rowH) { $rowH = $fl.Box.CY } }
            $gap = [int64](($bottom - $top - ($rowH * $rowYs.Count)) / [math]::Max(1, $rowYs.Count - 1))
            $map = @{}
            for ($q = 0; $q -lt $rowYs.Count; $q++) { $map[[string]$rowYs[$q]] = [int64]($top + $q * ($rowH + $gap)) }
            foreach ($item in ($fills + $texts)) {
                if (-not $item.Box) { continue }
                foreach ($oy in $rowYs) {
                    if ([math]::Abs([int64]$item.Box.Y - $oy) -le 60000) {
                        $delta = $map[[string]$oy] - $oy
                        Set-Box $item.Box $item.Box.X ($item.Box.Y + $delta) $item.Box.CX $item.Box.CY
                        $item.Box.Y = $item.Box.Y + $delta
                        break
                    }
                }
            }
        }
    }

    # Badges are drawn last so they sit ON their card. On the agenda the number
    # block and its row share an origin, so without this the sort order is
    # arbitrary and the bar paints straight over the badge - leaving a cream
    # numeral on a pastel ground with nothing behind it.
    $ordered = @($ordered | Sort-Object @{ Expression = { [int]$_.IsBadge } },
                                        @{ Expression = { [int64]$_.Box.Y * 20 + [int64]$_.Box.X } })

    # ---- the column, decided before anything is drawn in it -------------
    # Both the title blob and the card row have to be sized to the column they
    # sit in, and the card row has to be sized to the gap the title leaves, so
    # the three decisions are made here in order and drawn later.
    # A slide that already carries two or more cards is full; a picture dropped
    # on top of it would only collide.
    $cardCount = 0
    foreach ($fl in $fills) { if ($fl.Box.CX -ge 1100000) { $cardCount++ } }

    $side = 'none'
    $artInfo = $ArtPlan[$idx]
    if ($artInfo -and $cardCount -lt 2 -and $artInfo.File -and $ArtMedia.ContainsKey($artInfo.File)) {
        $side = $artInfo.Side
    }

    $textLeft  = $MARGIN
    $textWidth = $SLIDE_W - (2 * $MARGIN)
    if ($side -eq 'right') { $textWidth = $SLIDE_W - (2 * $MARGIN) - $ART_W - $ART_GAP }
    if ($side -eq 'left')  {
        $textLeft  = $MARGIN + $ART_W + $ART_GAP
        $textWidth = $SLIDE_W - $textLeft - $MARGIN
    }

    # ---- title blob, sized here and drawn further down -------------------
    $titleBlobY = [int64]640080
    $titleBlobW = [int64]0
    $titleBlobH = [int64]0
    $titleSz    = 2000
    if ($furn.ContainsKey('title')) {
        $tTxt = Get-Text $furn['title'] $nsm

        # Fit the blob to the gap above the content rather than to a guess: pick
        # the largest size whose wrapped lines still clear the first card. The
        # first pass sized by character count alone and pushed the title blob
        # straight through the top of every three-card slide.
        $roomH = [int64]($contentTop - $titleBlobY - 114300)
        if ($roomH -lt 731520)  { $roomH = 731520 }
        if ($roomH -gt 1600200) { $roomH = 1600200 }

        # A two-step ladder, not a five-step one. Fitting each title to its own
        # blob let the longest headings take the largest size - 24 pt over two
        # lines on the process slides against 18 pt on one line next door - so
        # the same role read at four sizes and the ranking ran backwards, the
        # wordiest heading set biggest. 20 pt where the room allows, 18 pt where
        # it does not, and 16 pt only if a title turns up that neither will hold.
        #
        # The blob is fitted to the measured heading rather than to a per
        # character allowance. The allowance was calibrated against one display
        # face; a wider one turned nine of twenty headings into a full line plus
        # an orphan word, inside a pill that still had inches of room to give.
        foreach ($try in @(2000, 1800, 1600)) {
            $titleSz = $try
            $wNeed = [int64](Measure-TextW $furn['title'] $nsm $FONT_DISPLAY $try) + 411480
            $titleBlobW = [int64]([math]::Min($textWidth, [math]::Max(3657600, $wNeed)))
            $need = [int64](Measure-TextH $furn['title'] $nsm ($titleBlobW - 411480) $FONT_DISPLAY $try) + 320040
            if ($need -le $roomH) { $titleBlobH = $need; break }
            $titleBlobH = $roomH
        }
        if ($titleBlobH -lt 731520) { $titleBlobH = [int64]731520 }
    }

    # ---- box layout: fit the card row to its copy, then centre it --------
    # Cards inherited the depth the source drew, which was sized for a denser
    # template. That left a row of four short cards floating in the top half
    # with the bottom third of the slide empty, and a row of three deep ones
    # with three inches of flat colour under three lines of copy. Measure the
    # copy, give every card in the row the one depth its deepest member needs,
    # and centre the row in the band between the title and whatever stands
    # below it.
    $hasChip   = $furn.ContainsKey('chip')
    $cardsOnly = @($ordered | Where-Object { -not $_.IsBadge })
    foreach ($t in $texts) { $t | Add-Member -NotePropertyName Owner -NotePropertyValue (-1) -Force }
    foreach ($fl in $ordered) { $fl | Add-Member -NotePropertyName Owner -NotePropertyValue (-1) -Force }

    $doBalance = ($kind -ne 'title') -and ($kind -ne 'agenda') -and ($cardsOnly.Count -ge 2)
    if ($doBalance) {
        $ys = @($cardsOnly | ForEach-Object { [int64]$_.Box.Y })
        $spread = ($ys | Measure-Object -Maximum).Maximum - ($ys | Measure-Object -Minimum).Minimum
        # more than one row of cards already fills the slide on its own
        if ($spread -gt 120000) { $doBalance = $false }
    }

    if ($doBalance) {
        # Who owns what. The gutter between two cards is under 0.2 in, which is
        # inside the tolerance the body pass uses to decide whether copy sits in
        # a card, so "the first card that matches" can hand a card's heading to
        # its neighbour. Nearest centre, among the cards the copy overlaps.
        for ($q = 0; $q -lt $texts.Count; $q++) {
            $b = $texts[$q].Box
            if (-not $b -or $texts[$q].Node.IsArrow) { continue }
            $tc = $b.X + [int64]($b.CX / 2)
            $bestI = -1; $bestD = [int64]::MaxValue
            for ($c = 0; $c -lt $cardsOnly.Count; $c++) {
                $cb = $cardsOnly[$c].Box
                if (($b.X + $b.CX) -lt ($cb.X - 200000) -or $b.X -gt ($cb.X + $cb.CX + 200000)) { continue }
                if ($b.Y -lt ($cb.Y - 200000) -or $b.Y -gt ($cb.Y + $cb.CY + 200000)) { continue }
                $d = [int64][math]::Abs($tc - ($cb.X + [int64]($cb.CX / 2)))
                if ($d -lt $bestD) { $bestD = $d; $bestI = $c }
            }
            $texts[$q].Owner = $bestI
        }
        foreach ($bd in $ordered) {
            if (-not $bd.IsBadge) { continue }
            $bc = $bd.Box.X + [int64]($bd.Box.CX / 2)
            for ($c = 0; $c -lt $cardsOnly.Count; $c++) {
                $cb = $cardsOnly[$c].Box
                if ($bc -ge $cb.X -and $bc -le ($cb.X + $cb.CX)) { $bd.Owner = $c; break }
            }
        }

        # The step number takes the statistics treatment: no disc, set large and
        # in ink across the full width of its card, so a process slide and a
        # figures slide set a number the same way. Only on a card-shaped card -
        # a wide bar keeps its disc, because there the number is a marker at the
        # head of the bar rather than the thing the card is about.
        foreach ($bd in $ordered) {
            if (-not $bd.IsBadge -or $bd.Owner -lt 0) { continue }
            $cb = $cardsOnly[$bd.Owner].Box
            if ($cb.CY -le 0 -or ($cb.CX / [double]$cb.CY) -gt 4.0) { continue }
            $bd | Add-Member -NotePropertyName IsStepNum -NotePropertyValue $true -Force
            foreach ($t in $texts) {
                if (-not $t.Box -or -not $t.Node.IsBadgeText -or $t.Owner -ne $bd.Owner) { continue }
                $t.Node | Add-Member -NotePropertyName IsStepNumText -NotePropertyValue $true -Force
                $h = Measure-TextH $t.Node $nsm ($cb.CX - 182880) $FONT_NUM $STEPNUM_SZ
                Set-Box $t.Box $cb.X $t.Box.Y $cb.CX $h
                $t.Box.X = $cb.X; $t.Box.CX = $cb.CX; $t.Box.CY = [int64]$h
            }
        }

        # The band the row may use: under the title, above the assessment chip,
        # and above any free-standing copy that will land below the cards.
        $bandTop = if ($titleBlobH -gt 0) { [int64]($titleBlobY + $titleBlobH + 320040) } else { [int64]1554480 }
        $bandBot = [int64]$CARD_FLOOR
        if ($hasChip -and ($CHIP_Y - 274320) -lt $bandBot) { $bandBot = [int64]($CHIP_Y - 274320) }
        $srcTop = ($cardsOnly | ForEach-Object { [int64]$_.Box.Y } | Measure-Object -Minimum).Minimum
        foreach ($t in $texts) {
            if (-not $t.Box -or $t.Owner -ge 0 -or $t.Node.IsArrow) { continue }
            $ny = Get-BodyY $t.Box.Y $t.Box.CY $hasChip
            if ($ny -lt $srcTop) { continue }        # a lead-in: it sits above the row
            if (($ny - 274320) -lt $bandBot) { $bandBot = [int64]($ny - 274320) }
        }
        if ($bandBot -lt ($bandTop + $CARD_MINH)) { $bandBot = [int64]($bandTop + $CARD_MINH) }

        # ---- a figure and its words share a line ------------------------
        # Daman asked for "90  A la carte covers, Wed-Sat" and "1  Collect":
        # the number at the head of the line the words are on, not a block
        # standing over them. The two are separate shapes and have to stay
        # separate - the gate compares text shape by shape - so they are laid
        # out as a row instead: the figure in a column of its own width, the
        # words in the rest of the card beside it, wrapping where they must.
        # Anything below the pair drops under the whole row at full width.
        # One figure column for the whole row, wide enough for its widest
        # member. Sized card by card, "120" pushed its words further right than
        # "90" did next door and the labels stopped lining up across the row.
        $figColW = [int64]0
        $figMinW = [int64]::MaxValue
        for ($c = 0; $c -lt $cardsOnly.Count; $c++) {
            $own = @($texts | Where-Object { $_.Owner -eq $c -and $_.Box } | Sort-Object { [int64]$_.Box.Y })
            if ($own.Count -lt 2) { continue }
            $fig = $own[0]
            if (-not (Test-IsFigure $fig $nsm)) { continue }
            $w = [int64](Measure-TextW $fig.Node $nsm $FONT_BODY (Get-InlineSz $own[1] $nsm)) + 45720
            if ($w -gt $figColW) { $figColW = $w }
            if ($w -lt $figMinW) { $figMinW = $w }
        }
        # One column across the row lines the labels up, which is right when the
        # figures are of a size - 90, 40, 80, 120. It is wrong when one of them
        # is "Mon 14 + Wed 16": that card set the column for all four and left
        # "Thu 17" trailing an inch and a half of white before its words. Past
        # a spread of about two to one, each card takes its own width.
        $figShared = ($figMinW -ne [int64]::MaxValue -and $figColW -le ($figMinW * 1.8))

        for ($c = 0; $c -lt $cardsOnly.Count; $c++) {
            $cb  = $cardsOnly[$c].Box
            $own = @($texts | Where-Object { $_.Owner -eq $c -and $_.Box } | Sort-Object { [int64]$_.Box.Y })
            if ($own.Count -lt 2) { continue }
            $fig = $own[0]
            if (-not (Test-IsFigure $fig $nsm)) { continue }

            $rowX = [int64]($cb.X + $CARD_PAD_X)
            $fw   = if ($figShared) { $figColW } `
                    else { [int64](Measure-TextW $fig.Node $nsm $FONT_BODY (Get-InlineSz $own[1] $nsm)) + 45720 }
            $lw   = [int64]($cb.X + $cb.CX - $CARD_PAD_X - $rowX - $fw - $FIG_GAP)
            # A card too narrow to hold both leaves them stacked rather than
            # squeezing the words into a column they cannot wrap in.
            if ($lw -lt 731520) { continue }

            $lbl = $own[1]
            $inSz = Get-InlineSz $lbl $nsm
            $fh  = [int64](Measure-TextH $fig.Node $nsm $fw $FONT_BODY $inSz)
            $lh  = [int64](Measure-TextH $lbl.Node $nsm ($lw - 182880))
            $rh  = [int64][math]::Max($fh, $lh)
            $rowY = [int64]$fig.Box.Y

            # Both set from the top, not centred against each other: the figure
            # belongs on the FIRST line of the words, the way a number reads at
            # the head of a sentence. Centred, it drifted to the middle of a
            # caption that wrapped to three lines.
            $fy = $rowY
            Set-Box $fig.Box $rowX $fy $fw $fh
            $fig.Box.X = $rowX; $fig.Box.Y = $fy; $fig.Box.CX = $fw; $fig.Box.CY = $fh
            $fig | Add-Member -NotePropertyName FixedH -NotePropertyValue $fh -Force
            $fig.Node | Add-Member -NotePropertyName InlineFig -NotePropertyValue $true -Force
            $fig.Node | Add-Member -NotePropertyName InlineSz -NotePropertyValue $inSz -Force

            $lx = [int64]($rowX + $fw + $FIG_GAP)
            $ly = $rowY
            Set-Box $lbl.Box $lx $ly $lw $lh
            $lbl.Box.X = $lx; $lbl.Box.Y = $ly; $lbl.Box.CX = $lw; $lbl.Box.CY = $lh
            $lbl | Add-Member -NotePropertyName FixedH -NotePropertyValue $lh -Force
            $lbl.Node | Add-Member -NotePropertyName InlineLbl -NotePropertyValue $true -Force

            $ny = [int64]($rowY + $rh + 137160)
            $bw = [int64]($cb.CX - (2 * $CARD_PAD_X))
            for ($k = 2; $k -lt $own.Count; $k++) {
                $t  = $own[$k]
                $bh = [int64](Measure-TextH $t.Node $nsm ($bw - 182880))
                Set-Box $t.Box $rowX $ny $bw $bh
                $t.Box.X = $rowX; $t.Box.Y = $ny; $t.Box.CX = $bw; $t.Box.CY = $bh
                $t | Add-Member -NotePropertyName FixedH -NotePropertyValue $bh -Force
                $t.Node | Add-Member -NotePropertyName InlineBody -NotePropertyValue $true -Force
                $ny = [int64]($ny + $bh + 137160)
            }
        }

        # How deep each card's own content is, measured rather than inherited.
        $need = [int64]0
        for ($c = 0; $c -lt $cardsOnly.Count; $c++) {
            $gTop = [int64]::MaxValue; $gBot = [int64]0
            foreach ($bd in $ordered) {
                if (-not $bd.IsBadge -or $bd.Owner -ne $c) { continue }
                if ($bd.IsStepNum) { continue }         # no disc drawn: its figure is measured below
                $byT = [int64]($bd.Box.Y + (($bd.Box.CY - $BADGE_D) / 2))
                if ($byT -lt $gTop) { $gTop = $byT }
                if (($byT + $BADGE_D) -gt $gBot) { $gBot = [int64]($byT + $BADGE_D) }
            }
            foreach ($t in $texts) {
                if ($t.Owner -ne $c) { continue }
                # The row pass above has already measured what it laid out, at
                # the size it will actually be set in; re-measuring here would
                # read the source's 58 pt off the figure's run properties.
                $h = if ($t.PSObject.Properties['FixedH']) { [int64]$t.FixedH } `
                     elseif ($t.Node.IsBadgeText) { [int64]$t.Box.CY } `
                     else { Measure-TextH $t.Node $nsm ($t.Box.CX - 182880) }
                $t | Add-Member -NotePropertyName MeasH -NotePropertyValue $h -Force
                # A numeral inside a disc is already counted with the disc; a
                # step number set as a figure on the card is counted here.
                if ($t.Node.IsBadgeText -and -not $t.Node.IsStepNumText -and -not $t.Node.InlineFig) { continue }
                if ($t.Box.Y -lt $gTop) { $gTop = [int64]$t.Box.Y }
                if (($t.Box.Y + $h) -gt $gBot) { $gBot = [int64]($t.Box.Y + $h) }
            }
            if ($gTop -eq [int64]::MaxValue) {
                $gTop = [int64]$cardsOnly[$c].Box.Y
                $gBot = [int64]($gTop + $CARD_MINH - (2 * $CARD_PAD))
            }
            $cardsOnly[$c] | Add-Member -NotePropertyName GTop -NotePropertyValue $gTop -Force
            $cardsOnly[$c] | Add-Member -NotePropertyName GH -NotePropertyValue ([int64]($gBot - $gTop)) -Force
            if (($gBot - $gTop + (2 * $CARD_PAD)) -gt $need) { $need = [int64]($gBot - $gTop + (2 * $CARD_PAD)) }
        }

        # The row takes the band, rather than the depth its copy happens to
        # need. Sizing it to the copy only moved the problem: four cards holding
        # a figure and a caption shrank to a third of the slide and left the
        # emptiness above them as well as below. A card in this template is a
        # poster, not a label. The one limit is aspect - a narrow card allowed
        # to fill a tall band becomes a tower - so no card runs deeper than
        # 1.3 times its own width, and the row centres in whatever is left.
        $bandH = [int64]($bandBot - $bandTop)
        $wid = ($cardsOnly | ForEach-Object { [int64]$_.Box.CX } | Measure-Object -Maximum).Maximum
        $cap = [int64][math]::Min(3900000, [math]::Max($CARD_MINH, $wid * 1.30))
        $rowH = $bandH
        if ($rowH -gt $cap)  { $rowH = $cap }
        # With the figure now on the same line as its words a stat card holds
        # perhaps an inch of content, and given the whole band it became three
        # inches of flat colour around one line. No card runs more than a bit
        # over twice the depth its own content asks for.
        if ($rowH -gt ($need * 1.7)) { $rowH = [int64]($need * 1.7) }
        if ($rowH -lt $need) { $rowH = [int64]$need }
        if ($rowH -gt $bandH) { $rowH = $bandH }
        if ($rowH -lt $CARD_MINH) { $rowH = [int64]$CARD_MINH }
        $rowY = [int64]($bandTop + [math]::Floor(($bandH - $rowH) / 2))

        for ($c = 0; $c -lt $cardsOnly.Count; $c++) {
            $fl = $cardsOnly[$c]
            # 0.45, not 0.5: a card's content is top-weighted - a badge or a
            # heading first, small print last - and set on the geometric centre
            # it reads as having sunk. The optical centre sits slightly high.
            $dy = [int64]($rowY + [math]::Floor(($rowH - $fl.GH) * 0.45) - $fl.GTop)
            Set-Box $fl.Box $fl.Box.X $rowY $fl.Box.CX $rowH
            $fl.Box.Y = $rowY; $fl.Box.CY = $rowH
            foreach ($bd in $ordered) {
                if (-not $bd.IsBadge -or $bd.Owner -ne $c) { continue }
                $bd.Box.Y = [int64]($bd.Box.Y + $dy)
            }
            foreach ($t in $texts) {
                if ($t.Owner -ne $c) { continue }
                $ny = [int64]($t.Box.Y + $dy)
                if ($t.Node.IsBadgeText) {
                    # the numeral is centred in its circle by the body pass, so
                    # its box travels with the badge and keeps its own height
                    Set-Box $t.Box $t.Box.X $ny $t.Box.CX $t.Box.CY
                    $t.Box.Y = $ny
                    continue
                }
                # anchored to the top and sized to the copy it holds, so where
                # the box goes is where the words appear
                $bp = $t.Node.SelectSingleNode('.//a:bodyPr', $nsm)
                if ($bp) { $bp.SetAttribute('anchor', 't') }
                Set-Box $t.Box $t.Box.X $ny $t.Box.CX $t.MeasH
                $t.Box.Y = $ny; $t.Box.CY = [int64]$t.MeasH
            }
        }
    }

    # Number the real cards first, so a badge can take the name of the card it
    # sits in and the two arrive together.
    $ci = 0; $cardNo = 0
    foreach ($fl in $ordered) {
        if ($fl.IsBadge) { continue }
        $cardNo++
        $fl | Add-Member -NotePropertyName CardName -NotePropertyValue ('Card {0:D2}' -f $cardNo) -Force
    }
    foreach ($fl in $ordered) {
        if (-not $fl.IsBadge) { continue }
        $owner = $null
        foreach ($c in $ordered) {
            if ($c.IsBadge -or -not $c.CardName) { continue }
            if ($fl.Box.X -ge $c.Box.X -and $fl.Box.Y -ge $c.Box.Y -and
                ($fl.Box.X + $fl.Box.CX) -le ($c.Box.X + $c.Box.CX) -and
                ($fl.Box.Y + $fl.Box.CY) -le ($c.Box.Y + $c.Box.CY)) { $owner = $c.CardName }
        }
        if (-not $owner) { $owner = 'Card 01' }
        $fl | Add-Member -NotePropertyName CardName -NotePropertyValue $owner -Force
    }

    $ci = 0
    foreach ($fl in $ordered) {
        $seed++
        if ($fl.IsBadge) {
            # A step number set as a figure carries itself. Dropping the fill
            # without drawing anything in its place is the whole change: the
            # numeral is a text shape of its own and is restyled below.
            if ($fl.IsStepNum) { [void]$tree.RemoveChild($fl.Node); continue }

            # One diameter for every badge in the deck, centred on the box the
            # source drew. Taking the source measurement gave the process slides
            # a 0.95 inch disc around a 16 pt figure - the numeral filled a fifth
            # of it and the badge read as a black blob dropped on the card - and
            # gave the agenda a disc exactly as tall as its bar, so the circle
            # broke the bar's outline at the top and bottom.
            $d  = $BADGE_D
            $bx = $fl.Box.X + [int64](($fl.Box.CX - $d) / 2)
            $by = $fl.Box.Y + [int64](($fl.Box.CY - $d) / 2)
            $badge = Add-Frag $doc (Xml-Blob -Id $nextId -Name ($fl.CardName + ' badge') `
                        -X $bx -Y $by -CX $d -CY $d -Fill $INK -Seed $seed -CornerPct 50 -Jit 16000)
            $nextId++
            $last = $tree.InsertAfter($badge, $last)
            [void]$tree.RemoveChild($fl.Node)
            continue
        }
        $col = $CARD_CYCLE[$ci % $CARD_CYCLE.Count]
        if ($col -eq $bg) { $ci++; $col = $CARD_CYCLE[$ci % $CARD_CYCLE.Count] }
        $ci++
        $isRound = ([math]::Abs($fl.Box.CX - $fl.Box.CY) -lt 60000)
        $corner = if ($isRound) { 50 } else { 22 }
        $jit    = if ($isRound) { 46000 } else { 38000 }
        $cardName = $fl.CardName
        # No filled card runs past the content line. Two of the source's cards
        # are drawn far deeper than the copy inside them, which left a pool of
        # flat colour under the last line and pushed the card down onto the
        # assessment chip. The text boxes are separate shapes, so trimming the
        # blob cannot clip a word.
        $cardH = $fl.Box.CY
        if (($fl.Box.Y + $cardH) -gt $CARD_FLOOR) {
            $trim = [int64]($CARD_FLOOR - $fl.Box.Y)
            if ($trim -ge 914400) { $cardH = $trim }
        }
        $last = Add-Blob $doc $tree $last ([ref]$nextId) $cardName `
                    $fl.Box.X $fl.Box.Y $fl.Box.CX $cardH $col $seed $corner $jit
        [void]$tree.RemoveChild($fl.Node)
    }

    # ---- illustration --------------------------------------------------
    $artBottom = [int64]0
    if ($side -ne 'none') {
        $a = $ArtMedia[$artInfo.File]
        $relPath = Join-Path (Join-Path $work 'ppt\slides\_rels') ($sf.Name + '.rels')
        [xml]$rels = [System.IO.File]::ReadAllText($relPath)
        $used = @($rels.Relationships.Relationship | ForEach-Object { $_.Id })
        $k = 1; while ($used -contains "rIdArt$k") { $k++ }
        $rid = "rIdArt$k"
        $rel = $rels.CreateElement('Relationship', $NS.rel)
        $rel.SetAttribute('Id', $rid)
        $rel.SetAttribute('Type', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image')
        $rel.SetAttribute('Target', '../media/' + $a.File)
        [void]$rels.Relationships.AppendChild($rel)
        Save-Xml $rels $relPath

        $isDoodle = ($artInfo.Kind -eq 'doodle')

        # The guide's photographs are 3:2 landscape, where the drawings this
        # replaced were square, so the same width buys a third less height. They
        # take a wider column to keep the same presence on the slide. A doodle
        # is a loose drawn element rather than a picture: it is smaller, and it
        # is fitted inside a box instead of being set to a width, because they
        # come in every proportion from a wide tray to a tall carrot.
        if ($isDoodle) {
            $boxW = 3017520; $boxH = 2743200
            $sc = [math]::Min($boxW / [double]$a.W, $boxH / [double]$a.H)
            $aw = [int64]([math]::Round($a.W * $sc))
            $ah = [int64]([math]::Round($a.H * $sc))
        } else {
            $aw = if ($kind -eq 'title') { $ART_W_TITLE } else { $ART_W }
            $ah = [int64]([math]::Round($aw * $a.H / [double]$a.W))
        }

        # A doodle centres in the column a photograph would fill, so a narrow
        # one does not sit hard against the edge of the slide.
        $colW = if ($kind -eq 'title') { $ART_W_TITLE } else { $ART_W }
        $colX = if ($side -eq 'left') { $MARGIN } else { $SLIDE_W - $MARGIN - $colW }
        $ax = [int64]($colX + [math]::Floor(($colW - $aw) / 2))

        # Centred in the same band the cards use, rather than pinned to a fixed
        # line. A landscape photograph pinned where a square drawing started
        # finished halfway down the slide with its own height of empty ground
        # underneath it.
        if ($kind -eq 'title') {
            $ay = [int64](($SLIDE_H - $ah) / 2)
        } else {
            $aTop = if ($titleBlobH -gt 0) { [int64]($titleBlobY + $titleBlobH + 320040) } else { [int64]1554480 }
            $aBot = if ($furn.ContainsKey('chip')) { [int64]($CHIP_Y - $ART_GAP) } else { [int64]6035040 }
            $ay = [int64]($aTop + [math]::Floor((($aBot - $aTop) - $ah) / 2))
            if ($ay -lt $aTop) { $ay = $aTop }
        }

        # Keep the picture clear of the assessment chip. Both sit bottom-right,
        # and a tall illustration will otherwise sit across the pill.
        $floor = if ($furn.ContainsKey('chip') -and $kind -ne 'title') { 5600700 } else { 6172200 }
        if (($ay + $ah) -gt $floor) {
            if (($floor - $ay) -lt 1828800) {
                # too short to simply move up: scale it down instead of squashing
                $ah = [int64]([math]::Max(1828800, $floor - $ay))
                $aw = [int64]([math]::Round($ah * $a.W / [double]$a.H))
                $ax = if ($side -eq 'left') { $MARGIN } else { $SLIDE_W - $MARGIN - $aw }
            } else {
                $ay = $floor - $ah
            }
        }
        if ($ay -lt 1005840) { $ay = 1005840 }

        if ($isDoodle) {
            # Loose on the ground, the way the template places its elements: no
            # frame, no outline. The drawing already has its own black line.
            $pic = Add-Frag $doc (Xml-Pic -Id $nextId -Name '!!art' -RId $rid `
                        -X $ax -Y $ay -CX $aw -CY $ah -Descr ('Element: ' + $artInfo.File))
            $nextId++
            $last = $tree.InsertAfter($pic, $last)
        } else {
            # A photograph is drawn as a blob filled with it, not as a picture in
            # a box: the wobbly path clips it and the ink outline sits round it,
            # so it belongs to the same drawn world as the cards. A softer corner
            # than a card's, because a photograph cropped hard at 22 per cent
            # loses whatever is standing in its corners.
            $seed++
            $last = Add-Blob $doc $tree $last ([ref]$nextId) '!!art' `
                        $ax $ay $aw $ah $CREAM $seed 9 30000 $rid
        }
        $artBottom = [int64]($ay + $ah)
    }

    # ---- the closing slide: the mark, then the words ---------------------
    # The college mark runs the full width of the content area, and the closing
    # lines are stacked and centred under it. Small in the corner where every
    # other slide carries it, it read as furniture on a slide that has nothing
    # else to say.
    if ($kind -eq 'thanks' -and $furn.ContainsKey('logo')) {
        $lb = Get-Box $furn['logo'] $nsm
        $contentW = [int64]($SLIDE_W - (2 * $MARGIN))          # 10820400, 11.83 in

        # Measure the closing lines BEFORE the mark is sized. The template's
        # mark is 2.46:1, so at the full content width it is 4.8 inches deep;
        # sized blind it pushed the last closing line through the footer, which
        # the gate now fails as a shape running past the slide. Full width
        # where the block fits, scaled to the band it actually has where it
        # does not - the mark still runs edge to edge of the content area at
        # every width this produces.
        $closing  = @($texts | Where-Object { $_.Box } | Sort-Object { [int64]$_.Box.Y })
        $measured = @()
        $closeH   = [int64]0
        foreach ($t in $closing) {
            $sz = 0
            $rp = $t.Node.SelectSingleNode('.//a:rPr', $nsm)
            if ($rp) { $v = Get-Attr $rp 'sz'; if ($v) { $sz = [int]$v } }
            $face = if ($sz -ge 3000) { $FONT_DISPLAY } else { $FONT_BODY }
            $h = [int64](Measure-TextH $t.Node $nsm ($contentW - 182880) $face)
            $measured += ,@($t, $face, $h)
            $closeH = [int64]($closeH + $h + 228600)
        }
        if ($closeH -gt 0) { $closeH = [int64]($closeH - 228600) }

        $ly   = [int64]822960
        $room = [int64]($FOOTER_Y - 228600 - $ly - 502920 - $closeH)
        $lw   = $contentW
        $lh   = [int64]([math]::Round($lw * $lb.CY / [double]$lb.CX))
        if ($room -gt 0 -and $lh -gt $room) {
            $lh = $room
            $lw = [int64]([math]::Round($lh * $lb.CX / [double]$lb.CY))
        }

        Set-Box $lb ([int64](($SLIDE_W - $lw) / 2)) $ly $lw $lh
        Set-Name $furn['logo'] $nsm '!!logo'
        [void]$tree.AppendChild($furn['logo'])
        $furn.Remove('logo')          # so the corner placement below leaves it alone

        $y = [int64]($ly + $lh + 502920)
        foreach ($m in $measured) {
            $t = $m[0]; $face = $m[1]; $h = $m[2]
            Set-Box $t.Box $MARGIN $y $contentW $h
            $t.Box.X = $MARGIN; $t.Box.Y = $y; $t.Box.CX = $contentW; $t.Box.CY = $h
            Set-RunStyle $t.Node $nsm $doc $face $INK
            Set-Centred $t.Node $nsm
            Remove-Bullets $t.Node $nsm
            [void]$tree.AppendChild($t.Node)
            $y = [int64]($y + $h + 228600)
        }
        $texts = @()
    }

    # ---- the cover is laid out on its own terms --------------------------
    if ($kind -eq 'title') {
        $textLeft  = $MARGIN + $ART_W_TITLE + (2 * $ART_GAP)
        $textWidth = $SLIDE_W - $textLeft - $MARGIN

        $ordered = @($texts | Sort-Object { [int64]$_.Box.Y })
        $titleNode = $null; $best = 0
        foreach ($t in $ordered) {
            foreach ($rp in $t.Node.SelectNodes('.//a:rPr', $nsm)) {
                $v = Get-Attr $rp 'sz'
                if ($v -and [int]$v -gt $best) { $best = [int]$v; $titleNode = $t.Node }
            }
        }

        $y = 1554480
        if ($titleNode) {
            $tTxt  = Get-Text $titleNode $nsm
            $per   = [math]::Max(8, [int](($textWidth - 411480) / (28.0 * 12700 * 0.50)))
            $lines = [math]::Max(1, [math]::Ceiling($tTxt.Length / [double]$per))
            $blobH = [int64]($lines * 28.0 * 12700 * 1.28) + 365760
            $seed++
            $last = Add-Blob $doc $tree $last ([ref]$nextId) '!!titleblob' `
                        $textLeft $y $textWidth $blobH $CREAM $seed 48 42000
            $b = Get-Box $titleNode $nsm
            Set-Box $b ($textLeft + 182880) ($y + 91440) ($textWidth - 365760) ($blobH - 182880)
            Set-RunStyle $titleNode $nsm $doc $FONT_DISPLAY $INK -Size 2800 -Spc 0
            Set-Centred $titleNode $nsm -Middle
            Remove-Bullets $titleNode $nsm
            [void]$tree.AppendChild($titleNode)
            $y += $blobH + 320040
        }

        foreach ($t in $ordered) {
            if ($t.Node -eq $titleNode) { continue }
            $sz = 1400
            $rp = $t.Node.SelectSingleNode('.//a:rPr', $nsm)
            if ($rp) { $v = Get-Attr $rp 'sz'; if ($v) { $sz = [math]::Min(1500, [int]$v) } }
            $h = [int64]($t.Node.SelectNodes('.//a:p', $nsm).Count * ($sz / 100.0) * 12700 * 1.5) + 91440
            $b = Get-Box $t.Node $nsm
            Set-Box $b $textLeft $y $textWidth $h
            Set-RunStyle $t.Node $nsm $doc $FONT_BODY $INK -Size $sz
            Set-Centred $t.Node $nsm
            [void]$tree.AppendChild($t.Node)
            $y += $h + 137160
        }
        $texts = @()
    }

    if ($furn.ContainsKey('title')) {
        $tNode = $furn['title']
        $blobY = $titleBlobY
        $blobW = $titleBlobW
        $blobH = $titleBlobH
        $sz    = $titleSz
        $seed++
        $last = Add-Blob $doc $tree $last ([ref]$nextId) '!!titleblob' `
                    $textLeft $blobY $blobW $blobH $ORANGE $seed 48 42000
        if ($bg -eq $ORANGE) {
            # the divider's own ground is orange, so its blob takes the cream
            $solid = $last
            $f = $solid.SelectSingleNode('./p:spPr/a:solidFill/a:srgbClr', $nsm)
            if ($f) { $f.SetAttribute('val', $CREAM) }
        }
        $b = Get-Box $tNode $nsm
        Set-Box $b ($textLeft + 182880) ($blobY + 91440) ($blobW - 365760) ($blobH - 182880)
        Set-RunStyle $tNode $nsm $doc $FONT_DISPLAY $INK -Size $sz -Spc 0
        Set-Centred $tNode $nsm -Middle
        Remove-Bullets $tNode $nsm
        Set-Name $tNode $nsm '!!title'
        [void]$tree.AppendChild($tNode)
    }

    if ($furn.ContainsKey('eyebrow')) {
        $eNode = $furn['eyebrow']
        $b = Get-Box $eNode $nsm
        Set-Box $b ($textLeft + 45720) 274320 6858000 274320
        Set-RunStyle $eNode $nsm $doc $FONT_BODY $INK -Size 900 -Spc 260
        Set-Name $eNode $nsm '!!eyebrow'
        [void]$tree.AppendChild($eNode)
    }

    # ---- body text ------------------------------------------------------
    # A connector belongs on the line of the things it connects. The badges are
    # that line on a process slide, so find their centre once.
    # Where a step number's own line is. On the slides that now set it as a
    # figure the disc is gone, so the arrow takes the figure's midline; where a
    # disc is still drawn it takes the disc's.
    # With the figure on the line its words are on it sits at the head of the
    # card rather than at its centre, so an arrow lined up on the figure would
    # sit high against the card it joins. The card's own middle is the line.
    $badgeMidY = 0
    foreach ($fl in $ordered) {
        if ($fl.IsBadge -or -not $fl.Box) { continue }
        $badgeMidY = [int64]($fl.Box.Y + ($fl.Box.CY / 2)); break
    }
    if ($badgeMidY -eq 0) {
        foreach ($t in $texts) {
            if ($t.Box -and $t.Node.IsStepNumText) { $badgeMidY = [int64]($t.Box.Y + ($t.Box.CY / 2)); break }
        }
    }
    if ($badgeMidY -eq 0) {
        foreach ($fl in $ordered) {
            if ($fl.IsBadge) { $badgeMidY = [int64]($fl.Box.Y + ($fl.Box.CY / 2)); break }
        }
    }

    $flow = @()
    foreach ($t in $texts) {
        $node = $t.Node; $b = $t.Box
        if (-not $b) { continue }
        if ($node.IsArrow) {
            # A proper connector, in the accent colour, sized to the gutter it
            # has to live in. The gap between two process cards is 0.17 inch; a
            # 20 pt arrow is wider than that, so both ends disappeared behind the
            # cards and what showed read as a speck of orange rather than a mark.
            $cxm = $b.X + [int64]($b.CX / 2)
            $cym = if ($badgeMidY -gt 0) { $badgeMidY } else { $b.Y + [int64]($b.CY / 2) }
            $d = 457200
            Set-Box $b ($cxm - [int64]($d / 2)) ($cym - [int64]($d / 2)) $d $d
            Set-RunStyle $node $nsm $doc $FONT_BODY $ORANGE -Size 1800
            Set-Centred $node $nsm -Middle
            # Named with the furniture prefix so the animation pass leaves it
            # standing. A connector is not a step: brought in after the four
            # cards it joins, three of these blink on at the end of the sequence
            # and read as an afterthought.
            $script:arrowSeq = if ($script:arrowSeq) { $script:arrowSeq + 1 } else { 1 }
            Set-Name $node $nsm ('!!arrow{0}' -f $script:arrowSeq)
            [void]$tree.AppendChild($node)
            continue
        }
        $inCard = $false
        $ownerCard = $null
        foreach ($fl in $fills) {
            if ($b.X -ge ($fl.Box.X - 200000) -and ($b.X + $b.CX) -le ($fl.Box.X + $fl.Box.CX + 200000) -and
                $b.Y -ge ($fl.Box.Y - 200000) -and $b.Y -le ($fl.Box.Y + $fl.Box.CY + 200000)) {
                $inCard = $true
                if ($fl.CardName -and -not $ownerCard) { $ownerCard = $fl.CardName }
            }
        }
        # Naming a card's copy after the card is what lets the animation pass
        # bring them in together. Without it the blob flies in behind text that
        # is already sitting on the slide, which reads as a fault.
        if ($ownerCard) {
            $script:cardTextSeq = if ($script:cardTextSeq) { $script:cardTextSeq + 1 } else { 1 }
            Set-Name $node $nsm ("{0} text {1}" -f $ownerCard, $script:cardTextSeq)
        }

        $sz = 0
        $rp = $node.SelectSingleNode('.//a:rPr', $nsm)
        if ($rp) { $v = Get-Attr $rp 'sz'; if ($v) { $sz = [int]$v } }

        if ($inCard) {
            # A figure sharing a line with its words: left of them, larger than
            # them, and both set from the top so they sit on one line.
            if ($node.InlineFig) {
                # Same face, same size, same colour as the words it leads.
                Set-RunStyle $node $nsm $doc $FONT_BODY $INK -Size ([int]$node.InlineSz)
                Set-Align $node $nsm 'l' 't'
                Remove-Bullets $node $nsm
                continue
            }
            if ($node.InlineLbl -or $node.InlineBody) {
                Set-RunStyle $node $nsm $doc $FONT_BODY $INK
                Set-Align $node $nsm 'l' 't'
                continue
            }
            if ($node.IsBadgeText) {
                if ($node.IsStepNumText) {
                    # The statistics treatment: the figure IS the mark, at the
                    # size the temperatures slide sets its numbers, in ink on
                    # the card. Reversed small out of a disc it read as a black
                    # blob with something faint on it.
                    Set-RunStyle $node $nsm $doc $FONT_NUM $INK -Size $STEPNUM_SZ
                } else {
                    # Still a marker at the head of a bar, reversed out of the
                    # ink disc drawn under it.
                    Set-RunStyle $node $nsm $doc $FONT_NUM $CREAM -Size $BADGE_SZ
                }
                Set-Centred $node $nsm -Middle
                continue
            }
            # A statistic is set in the figure face. At 60 pt Century Gothic's
            # numerals are hairline-thin and its hyphen a short mid-height tick,
            # so "5-60" and "-18" read as a slip; the caption underneath keeps
            # the body face, which is what makes the figure the headline.
            $isCardFig = ($t.Text -match '^[\s\d\-+:.,/]+$')
            $face = if ($isCardFig -and $sz -ge 2400) { $FONT_NUM } else { $FONT_BODY }
            Set-RunStyle $node $nsm $doc $face $INK
            continue
        }

        # free-standing copy moves into the text column
        $newX = $textLeft
        $newW = $textWidth
        # The divider used to force its own column width, from before it carried
        # a picture. Held at that width its assessment line ran under the
        # photograph; the column computed for the slide already clears it.
        if ($isDivider) { $newX = $MARGIN }
        # One rule, shared with the card balancer, which had to know where this
        # copy would land before it could decide how far down the cards may run.
        $newY = Get-BodyY $b.Y $b.CY $hasChip

        # The case-study quote is set from the foot of its block, not the head,
        # so a two-line quote and a three-line quote finish on the same rule and
        # the attribution keeps one gap under both. Anchored at the top, the two
        # quote slides left voids of 172 px and 100 px under the same pair of
        # elements, which reads as a gap rather than as a relationship.
        if ($kind -eq 'case-study') {
            if ($sz -ge 3000) {
                $newY = [int64](4297680 - $b.CY)
                $bp = $node.SelectSingleNode('.//a:bodyPr', $nsm)
                if ($bp) { $bp.SetAttribute('anchor', 'b') }
            } else {
                $newY = 4572000
            }
        }

        Set-Box $b $newX $newY $newW $b.CY
        # Keep the inventory copy in step with the XML. Without this the
        # overlap sweep below reads the position the source drew rather than
        # the one this pass just wrote, and pushes blocks onto each other.
        $b.X = $newX; $b.Y = $newY; $b.CX = $newW
        # Same rule as inside a card: a figure standing on its own - the section
        # number on a divider, a statistic - is set in the figure face; words at
        # display size get the serif; everything else is body copy.
        $isFigure = ($t.Text -match '^[\s\d\-+:.,/]+$')
        $face = if ($isFigure -and $sz -ge 2400) { $FONT_NUM } elseif ($sz -ge 3000) { $FONT_DISPLAY } else { $FONT_BODY }
        $bodySz = 0
        if ($sz -ge 1400 -and $sz -lt 3000 -and $side -ne 'none') { $bodySz = $sz - 100 }
        # The section number on a divider comes off the source at 130 pt and
        # fills a quarter of the slide. It marks the section; it is not what
        # the slide is about.
        if ($isFigure -and $sz -gt $SECTION_NUM_SZ) { $bodySz = $SECTION_NUM_SZ }
        Set-RunStyle $node $nsm $doc $face $INK -Size $bodySz
        # Measured after restyling, so the height is the height of the copy as
        # it will actually be set rather than as the source left it.
        $flow += [pscustomobject]@{
            Box     = $b
            Node    = $node
            Face    = $face
            NarrowW = [int64]$newW
            H       = [int64][math]::Max(182880, (Measure-TextH $node $nsm ($newW - 182880) $face))
        }
    }

    # ---- free-standing copy must not sit on the block above it -----------
    # The only vertical spacing this deck inherits is the source's boxes, and
    # those were measured for a different face at a different width. Book
    # Antiqua runs wider than the face it replaced, so a section heading that
    # used to fit on one line now takes two - and the line under it stayed
    # where the source put it, straight through the second line. Sort what is
    # standing in the column and drop anything that has been overrun clear of
    # the block above it. The case-study slides set their quote from its foot
    # by design and are left alone.
    if ($kind -ne 'case-study' -and $flow.Count -gt 1) {
        # 6035040 leaves a quarter inch clear of the footer rule. At 6172200 the
        # divider's assessment line finished a tenth of an inch above the RTO
        # line and the two read as one block.
        $ceilAll = if ($hasChip) { [int64]($CHIP_Y - 274320) } else { [int64]6035040 }
        $items = @($flow | Sort-Object { [int64]$_.Box.Y })

        # A divider carries no title pill, so its block is stacked from the top
        # of the content area rather than nudged out of the source's own
        # spacing. Its section number alone is two and a half inches deep;
        # started where a body paragraph starts, the block finished below the
        # slide and the heading ran through the line under it.
        $top = if ($isDivider) { [int64]1005840 } else { [int64]$items[0].Box.Y }

        # If the column will not hold the blocks at a full gap, close the gaps
        # rather than let one block sit on the next. Clamping the last block up
        # to the bottom margin, which is what this did first, produces exactly
        # the overlap it was meant to prevent.
        $gap = [int64]137160
        $sum = [int64]0
        foreach ($fw in $items) { $sum += [int64]$fw.H }
        $room = [int64]($ceilAll - $top)
        if (($sum + ($gap * ($items.Count - 1))) -gt $room) {
            $gap = [int64][math]::Max(0, [math]::Floor(($room - $sum) / [double]($items.Count - 1)))
        }

        $prevBot = $top
        foreach ($fw in $items) {
            $y = [int64]$fw.Box.Y
            if ($isDivider -or $y -lt $prevBot) { $y = $prevBot }

            # The column is narrowed to clear the picture, but copy that ends up
            # BELOW the picture has the whole slide to itself. Decided here,
            # against where the block actually lands, rather than before this
            # sweep runs: judged on its pre-sweep position, the divider's
            # assessment line was given the full width and then stacked back up
            # beside the photograph, where it ran under it.
            if ($artBottom -gt 0) {
                $wantW = if ($y -ge $artBottom) { [int64]($SLIDE_W - $fw.Box.X - $MARGIN) } else { [int64]$fw.NarrowW }
                if ($wantW -ne [int64]$fw.Box.CX) {
                    $fw.Box.CX = $wantW
                    $fw.H = [int64][math]::Max(182880, (Measure-TextH $fw.Node $nsm ($wantW - 182880) $fw.Face))
                }
            }

            Set-Box $fw.Box $fw.Box.X $y $fw.Box.CX $fw.Box.CY
            $fw.Box.Y = $y
            $prevBot = [int64]($y + $fw.H + $gap)
        }
    }

    # ---- tables ---------------------------------------------------------
    foreach ($o in $others) {
        if ($o.Node.LocalName -ne 'graphicFrame') { continue }

        # A table is furniture like a card row and sits in the same band. Left
        # where the source drew it, the three-row comparison table finished
        # halfway down and left the bottom third of the slide empty under it.
        # The frame carries a placeholder depth, so the height it actually
        # occupies is the sum of its rows.
        if ($o.Box) {
            $th = Get-TableHeight $o.Node $nsm
            if ($th -le 0) { $th = [int64]$o.Box.CY }
            $tTop = if ($titleBlobH -gt 0) { [int64]($titleBlobY + $titleBlobH + 320040) } else { [int64]1554480 }
            $tBot = if ($hasChip) { [int64]($CHIP_Y - 274320) } else { [int64]6172200 }
            $ty = [int64]($tTop + [math]::Floor((($tBot - $tTop) - $th) / 2))
            if ($ty -lt $tTop) { $ty = $tTop }
            Set-Box $o.Box $o.Box.X $ty $o.Box.CX $th
            $o.Box.Y = $ty; $o.Box.CY = $th
        }

        # The header is a row, not three cells that happen to be shaded. Mapping
        # each source colour on its own gave the head of the table two cells in
        # sage and a third in orange, because the source highlights one column -
        # so the emphasis inside the body leaked up into the header and the row
        # stopped reading as one thing. The header takes one fill, chosen to sit
        # off the slide's own ground, and the body takes cream under it.
        $headFill = if ($bg -eq $BLUE) { $SAGE } else { $BLUE }
        $rows = @($o.Node.SelectNodes('.//a:tr', $nsm))
        for ($ri = 0; $ri -lt $rows.Count; $ri++) {
            $isHead = ($ri -eq 0)
            foreach ($cell in $rows[$ri].SelectNodes('.//a:tcPr', $nsm)) {
                foreach ($ln in $cell.SelectNodes('a:lnL | a:lnR | a:lnT | a:lnB', $nsm)) {
                    $c = $ln.SelectSingleNode('a:solidFill/a:srgbClr', $nsm)
                    if ($c) { $c.SetAttribute('val', $INK) }
                    $ln.SetAttribute('w', '12700')
                }
                $f = $cell.SelectSingleNode('a:solidFill/a:srgbClr', $nsm)
                if ($f) {
                    if ($isHead) { $f.SetAttribute('val', $headFill) } else { $f.SetAttribute('val', $CREAM) }
                }
            }
            # The header takes the display face, the body the copy face. With
            # the whole deck set bold, a bold header row in the same face as the
            # rows under it is not a header at all.
            $rowFace = if ($isHead) { $FONT_DISPLAY } else { $FONT_BODY }
            $rowBold = Get-BoldFor $rowFace
            foreach ($rPr in $rows[$ri].SelectNodes('.//a:rPr | .//a:defRPr | .//a:endParaRPr', $nsm)) {
                foreach ($old in @($rPr.SelectNodes('a:solidFill', $nsm))) { [void]$rPr.RemoveChild($old) }
                [void]$rPr.PrependChild((Add-Frag $doc ('<a:solidFill xmlns:a="' + $NS.a + '"><a:srgbClr val="' + $INK + '"/></a:solidFill>')))
                $rPr.SetAttribute('b', [string]$rowBold)
                foreach ($tag in @('latin', 'ea', 'cs')) {
                    $el = $rPr.SelectSingleNode("a:$tag", $nsm)
                    if (-not $el) { $el = $doc.CreateElement('a', $tag, $NS.a); [void]$rPr.AppendChild($el) }
                    $el.SetAttribute('typeface', $rowFace)
                }
            }
        }
    }

    # ---- assessment chip -------------------------------------------------
    if ($furn.ContainsKey('chip')) {
        $chip = $furn['chip']
        $cw = 3657600; $cx = $SLIDE_W - $MARGIN - $cw
        # One baseline, deck-wide. Sizing the chip to each slide's own content
        # was meant to close up the short slides, but it put the same pill at
        # five different heights over twenty slides - 600 px, 618 px, 690 px,
        # 750 px, 756 px - and a piece of standing furniture that moves every
        # few slides reads as a slip. It sits with the page number now, on the
        # line the footer already establishes.
        $cy = $CHIP_Y
        # The chip was always butter yellow, which on the cream and yellow
        # grounds left it separated from the slide by its outline alone - a pale
        # pill on a pale ground, carrying the one line on the slide that tells a
        # learner which assessment task this prepares them for. It takes the
        # colour that stands off the ground it is actually sitting on.
        $chipFill = if ($bg -eq $YELLOW -or $bg -eq $CREAM) { $BLUE } else { $YELLOW }
        $seed++
        $last2 = Add-Blob $doc $tree $tree.LastChild ([ref]$nextId) '!!chipblob' `
                    $cx $cy $cw 411480 $chipFill $seed 50 30000
        $b = Get-Box $chip $nsm
        Set-Box $b ($cx + 137160) ($cy + 45720) ($cw - 274320) 320040
        foreach ($f in @($chip.SelectNodes('./p:spPr/a:solidFill', $nsm))) { [void]$chip.SelectSingleNode('./p:spPr', $nsm).RemoveChild($f) }
        Set-RunStyle $chip $nsm $doc $FONT_BODY $INK -Size 1000
        Set-Centred $chip $nsm -Middle
        Set-Name $chip $nsm '!!chip'
        [void]$tree.AppendChild($chip)
    }

    # ---- logo and footer --------------------------------------------------
    if ($furn.ContainsKey('logo')) {
        $b = Get-Box $furn['logo'] $nsm
        Set-Box $b ($SLIDE_W - $MARGIN - 1005840) 274320 1005840 408939
        Set-Name $furn['logo'] $nsm '!!logo'
        [void]$tree.AppendChild($furn['logo'])
    }
    if ($furn.ContainsKey('brand')) {
        $b = Get-Box $furn['brand'] $nsm
        Set-Box $b $MARGIN $FOOTER_Y 7315200 320040
        # 8 pt Century Gothic is below the size at which this face holds its
        # stroke on screen: the footer rendered as a grey smudge on every
        # background in the deck even though it was set in full ink.
        Set-RunStyle $furn['brand'] $nsm $doc $FONT_BODY $INK -Size 950
        Set-Name $furn['brand'] $nsm '!!brand'
        [void]$tree.AppendChild($furn['brand'])
    }
    if ($furn.ContainsKey('pageNo')) {
        # The page number gets the same ink circle as the step badges, so the
        # deck has one way of setting a number rather than three.
        $pd = 411480
        $px = $SLIDE_W - $MARGIN - $pd
        $py = 6217920
        $seed++
        $pill = Add-Frag $doc (Xml-Blob -Id $nextId -Name '!!pagedot' -X $px -Y $py `
                    -CX $pd -CY $pd -Fill $INK -Seed $seed -CornerPct 50 -Jit 22000)
        $nextId++
        [void]$tree.AppendChild($pill)
        $b = Get-Box $furn['pageNo'] $nsm
        Set-Box $b $px $py $pd $pd
        Set-RunStyle $furn['pageNo'] $nsm $doc $FONT_NUM $CREAM -Size 1000
        Set-Centred $furn['pageNo'] $nsm -Middle
        Set-Name $furn['pageNo'] $nsm '!!pageno'
        [void]$tree.AppendChild($furn['pageNo'])
    }

    # ---- transition ------------------------------------------------------
    $sld = $doc.DocumentElement
    foreach ($old in @($sld.SelectNodes('./p:transition', $nsm))) { [void]$sld.RemoveChild($old) }
    $clr = $sld.SelectSingleNode('./p:clrMapOvr', $nsm)
    $tr  = Add-Frag $doc (Xml-Transition)
    if ($clr) { [void]$sld.InsertAfter($tr, $clr) } else { [void]$sld.AppendChild($tr) }

    Save-Xml $doc $sf.FullName

    $report += [pscustomobject]@{
        Slide = $idx; Kind = $kind; Background = $bg
        Blobs = $fills.Count; Art = $(if ($side -ne 'none') { $artInfo.File } else { '' })
    }
}

# ===========================================================================
#  Repack
# ===========================================================================
if (Test-Path $Out) { Remove-Item $Out -Force }
[System.IO.Compression.ZipFile]::CreateFromDirectory($work, $Out,
    [System.IO.Compression.CompressionLevel]::Optimal, $false)

$report | Format-Table -AutoSize | Out-String -Width 120 | Write-Host
Write-Host ("wrote {0}  ({1:N1} MB, {2} slides)" -f $Out, ((Get-Item $Out).Length / 1MB), $report.Count)
