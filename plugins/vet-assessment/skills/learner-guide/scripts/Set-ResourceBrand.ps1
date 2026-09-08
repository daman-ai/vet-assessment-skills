# Set-ResourceBrand.ps1 - brand a rendered Learner Guide (.docx) and Delivery
# PowerPoint (.pptx) for a non-MVC brand, and PROVE it, byte-level.
#
# THE APPROACH IS THE ASSESSMENT SKILL'S, APPLIED DOWNSTREAM. Both resources
# are rendered from MVC's approved templates with MVC's profile, then the
# brand is swapped on the rendered artefact - logo, palette, identity, rels
# hyperlink targets - and a blocking byte gate proves the mark before the file
# ships. "Everything is as MVC except the logo and the colours" is applied at
# build time, not by forking profiles.
#
# WHY THE GATES ARE NOT OPTIONAL. 29 August 2026: every knowledge document of
# a delivered assessment pack carried the MVC mark in its header with every
# text gate green, because a text sweep cannot see an image. The docx side
# reuses that incident's hardened machinery (Set-BrandLogo sweeps EVERY part
# that draws the mark; Assert-BrandLogo proves it). The pptx side implements
# the same discipline for a package layout Word's functions cannot see.
#
# Requires the assessment skill's Build-FromTemplate.ps1 and
# Docx-Blocks-House.ps1 dot-sourced first (Lib-Resolve.ps1 does this).
#
# ASCII only - PS 5.1 decodes a BOM-less .ps1 as ANSI.

param(
    #  The library's own self-test switch, NAMED so it cannot collide. A
    #  dot-sourced script binds its parameters in the CALLER's scope, so a
    #  parameter called $SelfTest here would set every caller's own -SelfTest
    #  switch to $false the moment it dot-sourced this file. The alias keeps
    #  the documented command line; the odd name keeps every caller's
    #  variables. Same arrangement as Lib-GateCommon.ps1.
    [Alias('SelfTest')]
    [switch] $ResourceBrandSelfTest
)

# The MVC mark as it exists in the DECK template (ppt/media/image1.png,
# 1600 x 650). Byte-different from the docx JPEG of the same mark - which is
# exactly why each container needs its own known-source fingerprint.
$script:DECK_MVC_LOGO_MD5 = '5066c16b2d1655e21b0a3d485b14ff6e'

function Get-FileMd5 {
    param([Parameter(Mandatory)][string] $Path)
    (Get-FileHash -LiteralPath $Path -Algorithm MD5).Hash.ToLower()
}

function Get-PngPixelSize {
    param([Parameter(Mandatory)][string] $Path)
    $b = [System.IO.File]::ReadAllBytes($Path)
    $w = ([int]$b[16] -shl 24) -bor ([int]$b[17] -shl 16) -bor ([int]$b[18] -shl 8) -bor [int]$b[19]
    $h = ([int]$b[20] -shl 24) -bor ([int]$b[21] -shl 16) -bor ([int]$b[22] -shl 8) -bor [int]$b[23]
    [pscustomobject]@{ Width = $w; Height = $h; Ratio = $w / $h }
}

function Get-BrandColourPart {
    <#  EVERY part of an expanded package that can carry a colour: every .xml
        and every .rels, recursively.

        The version this replaces walked three named directories
        (ppt\slides, ppt\slideMasters, ppt\slideLayouts) plus theme and
        notesSlides. ppt\notesMasters was in NEITHER list, so a legacy hex in
        notesMaster1.xml survived the swap AND the gate that was supposed to
        catch it - the gate read the same short list. A part set that is
        enumerated cannot disagree with itself.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $WorkDir)
    return @(Get-ChildItem -LiteralPath $WorkDir -Recurse -File -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -like '*.xml' -or $_.Name -like '*.rels' })
}

#  A colour in OOXML is always an ATTRIBUTE VALUE: a:srgbClr val="234B8C",
#  w:color w:val="234B8C", w:shd w:fill="F0F2F7", a:sysClr lastClr="606060".
#  This is the anchor, and it is not a nicety: the bare-substring replace it
#  replaces rewrote '606060' wherever it appeared, including inside
#  <a:ext cx="606060" cy="..."/>, which is an EMU measurement. A hex is six
#  characters, EMU values are seven to nine digits, and 0-9A-F is a subset of
#  the digits - so a drawing extent is a live collision, not a theoretical one.
$script:BRAND_COLOUR_ATTRS = @('val', 'fill', 'color', 'lastClr', 'srgbClr', 'themeColor', 'bgColor')

function Get-BrandColourRegex {
    <#  The anchored patterns every colour read and every colour write use.

        TWO FORMS, and only two:

          attribute  val="F5C800", w:fill="F5C800", lastClr="F5C800"
          label      <a:t>#F5C800</a:t> - a text run that is WHOLLY a hex

        The label form is not a licence to touch prose. The approved deck
        template carries a palette-swatch slide that draws each brand colour
        AND PRINTS ITS HEX beside it; move the fill and leave the caption and
        the slide now labels a colour it is not. The pattern therefore requires
        the run to contain nothing but the hex (with an optional leading '#'),
        so 'brand hex F5C800 named in prose' does not match, and neither does
        a measurement: cx="606060" is not a colour attribute, and <a:t>606060
        as part of a sentence</a:t> is not a whole run.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Hex, [ValidateSet('attribute', 'label')][string] $Form = 'attribute')
    if ($Form -eq 'label') {
        return ('(?i)(<([aw]):t(?:\s[^>]*)?>#?)(' + [regex]::Escape($Hex) + ')(</\2:t>)')
    }
    return ('(?i)((?:[A-Za-z0-9_]+:)?(?:' + (($script:BRAND_COLOUR_ATTRS | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\s*=\s*")(' + [regex]::Escape($Hex) + ')(")')
}

function Set-BrandColourValue {
    <#  Replace one hex with another, ANCHORED on the colour attribute, case
        insensitively (OOXML writers emit both cases). Returns the new text and
        the number of attribute values changed.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string] $Xml,
        [Parameter(Mandatory)][string] $From,
        [Parameter(Mandatory)][string] $To
    )
    $repl = $Xml
    $hits = 0
    foreach ($form in @('attribute', 'label')) {
        $rx = Get-BrandColourRegex -Hex $From -Form $form
        $n = ([regex]::Matches($repl, $rx)).Count
        if ($n -eq 0) { continue }
        $hits += $n
        if ($form -eq 'label') { $repl = [regex]::Replace($repl, $rx, { param($m) $m.Groups[1].Value + $To + $m.Groups[4].Value }) }
        else                   { $repl = [regex]::Replace($repl, $rx, { param($m) $m.Groups[1].Value + $To + $m.Groups[3].Value }) }
    }
    return [pscustomobject]@{ Xml = $repl; Changed = $hits }
}

function Measure-BrandColour {
    <# How many times this hex appears AS A COLOUR in this text. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Xml, [Parameter(Mandatory)][string] $Hex)
    return ([regex]::Matches($Xml, (Get-BrandColourRegex -Hex $Hex -Form 'attribute'))).Count +
           ([regex]::Matches($Xml, (Get-BrandColourRegex -Hex $Hex -Form 'label'))).Count
}

function Invoke-BrandPaletteSweep {
    <#  Apply the whole role map across every colour-bearing part of an
        expanded package, anchored, and report what moved.

        THIS RUNS ON A SAME-BRAND BUILD TOO, as NORMALISATION. The template
        carries its own legacy hexes (F5C800 where the rule colour is now
        F09C0C, E45418 where the accent is now 2F60B4, C7D0DD beside C9CFDD)
        and a same-brand build used to return a no-op, which is precisely why
        every same-brand build ended with a hand-written repaint script and a
        4c round. A pair that maps to itself is skipped because it is already
        correct - never because the role failed to resolve; an unresolved role
        throws in Get-BrandPalettePairs before this function is reached.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $WorkDir,
        [Parameter(Mandatory)] $Pairs
    )
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $parts = 0
    $values = 0
    $moved = [ordered]@{}
    foreach ($f in (Get-BrandColourPart -WorkDir $WorkDir)) {
        $xml = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
        $orig = $xml
        foreach ($from in @($Pairs.Keys)) {
            $to = [string]$Pairs[$from]
            if ($to -ieq $from) { continue }
            $r = Set-BrandColourValue -Xml $xml -From $from -To $to
            if ($r.Changed -gt 0) {
                $xml = $r.Xml
                $values += $r.Changed
                if (-not $moved.Contains($from)) { $moved[$from] = 0 }
                $moved[$from] = [int]$moved[$from] + $r.Changed
            }
        }
        if ($xml -ne $orig) { [System.IO.File]::WriteAllText($f.FullName, $xml, $utf8); $parts++ }
    }
    [pscustomobject]@{ Parts = $parts; Values = $values; Moved = $moved; PartsInspected = @(Get-BrandColourPart -WorkDir $WorkDir).Count }
}

function Test-BrandPaletteSwept {
    <#  The step-5 palette gate. Its token list is DERIVED FROM $Pairs.KEYS -
        every source hex the map actually moves - and never from a typed list.
        The typed list carried three of the nine hexes and printed "no
        crossover" over 766 live occurrences. A pair that maps to itself is not
        a token: that colour is legitimately still there.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $WorkDir, [Parameter(Mandatory)] $Pairs)
    $bad = New-Object System.Collections.Generic.List[string]
    $tokens = @(@($Pairs.Keys) | Where-Object { "$($Pairs[$_])" -ine "$_" })
    foreach ($f in (Get-BrandColourPart -WorkDir $WorkDir)) {
        $t = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
        foreach ($tok in $tokens) {
            $n = Measure-BrandColour -Xml $t -Hex $tok
            if ($n -gt 0) {
                $rel = $f.FullName.Substring($WorkDir.Length).TrimStart('\', '/') -replace '\\', '/'
                $bad.Add(("{0} still carries the source colour {1} in {2} attribute value(s)" -f $rel, $tok, $n))
            }
        }
    }
    [pscustomobject]@{ Ok = ($bad.Count -eq 0); Problems = @($bad); Tokens = @($tokens) }
}

function Get-BrandProfileDirectory {
    <#  The directory holding branding.<brand>.json, resolved the way the RTO
        profile pack resolves it - not a second search of its own.  #>
    [CmdletBinding()]
    param([string] $BrandingDir)
    if ($BrandingDir) {
        if (-not (Test-Path -LiteralPath $BrandingDir)) { throw "The branding directory '$BrandingDir' does not exist." }
        return (Resolve-Path -LiteralPath $BrandingDir).Path
    }
    if (-not (Get-Command Resolve-RtoBrandingDir -ErrorAction SilentlyContinue)) {
        throw 'Resolve-RtoBrandingDir is not loaded. Dot-source Lib-Resolve.ps1 (which loads Lib-RtoProfile.ps1) before calling the brand swap, or pass -BrandingDir. The ancestry sweep derives its map from the branding profiles on disk and refuses to run against a map it could not build.'
    }
    return (Resolve-RtoBrandingDir -BrandingDir '' -Root (Split-Path -Parent $PSScriptRoot))
}

function Get-BrandAncestryMap {
    <#  THE TEMPLATE'S OWN HISTORY, as a map from every OTHER brand's identity
        value to THIS brand's value for the same field.

        The approved deck template carries a different institute's trading
        name, RTO code and CRICOS code in its docProps - the template's
        ancestry, which prints nowhere and which no reader ever sees until an
        auditor opens File > Properties. The version this replaces walked this
        brand's own VARIANTS, so a brand with no variants (which is every brand
        that has not been forked yet) swapped nothing and, worse, called
        String.Replace with an empty needle and threw.

        The map is DERIVED by reading every branding.*.json beside this one and
        pairing field for field. A field this brand does not carry, or carries
        with the same value, is not in the map: there is nothing to move.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Branding, [string] $Variant, [string] $BrandingDir)
    if (-not (Get-Command Read-RtoJson -ErrorAction SilentlyContinue)) {
        throw 'Read-RtoJson is not loaded. Dot-source Lib-Resolve.ps1 (which loads Lib-RtoProfile.ps1) before calling the brand swap.'
    }
    $dir = Get-BrandProfileDirectory -BrandingDir $BrandingDir
    #  THIS brand's value for a field, variant first then the rto node. One
    #  registered entity can trade under two names, so the trading name lives
    #  on the variant for one brand and on the rto node for another; a map
    #  built from the rto node alone missed 'Adelaide Construction Institute'
    #  in the deck template's docProps entirely.
    $mine = [ordered]@{}
    $collect = {
        param($node)
        if ($null -eq $node) { return }
        foreach ($pr in $node.PSObject.Properties) {
            if ($pr.Name -like '_*') { continue }
            if (-not ($pr.Value -is [string])) { continue }
            $v = "$($pr.Value)".Trim()
            if ($v.Length -lt 4) { continue }
            if (-not $mine.Contains($pr.Name)) { $mine[$pr.Name] = $v }
        }
    }
    if (@($Branding.PSObject.Properties.Name) -contains 'variants' -and $Branding.variants) {
        $vn = $Variant
        if (-not $vn -and (@($Branding.variants.PSObject.Properties.Name) -contains 'default')) { $vn = [string]$Branding.variants.default }
        if ($vn -and (@($Branding.variants.PSObject.Properties.Name) -contains $vn)) { & $collect $Branding.variants.$vn }
    }
    & $collect $Branding.rto

    $map = [ordered]@{}
    $files = @(Get-ChildItem -LiteralPath $dir -Filter 'branding.*.json' -File -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) {
        throw ("No branding profile found in '{0}'. The ancestry map is derived from them, and an empty map reports every template clean." -f $dir)
    }
    foreach ($f in $files) {
        $op = Read-RtoJson -Path $f.FullName
        if ($null -eq $op) { continue }
        if ("$($op.brand)" -ieq "$($Branding.brand)") { continue }
        $theirNodes = New-Object System.Collections.Generic.List[object]
        if ($null -ne $op.rto) { $theirNodes.Add($op.rto) }
        if (@($op.PSObject.Properties.Name) -contains 'variants' -and $op.variants) {
            foreach ($vp in $op.variants.PSObject.Properties) {
                if ($vp.Name -like '_*' -or $vp.Name -eq 'default') { continue }
                if ($null -ne $vp.Value -and -not ($vp.Value -is [string])) { $theirNodes.Add($vp.Value) }
            }
        }
        foreach ($node in $theirNodes) {
            foreach ($pr in $node.PSObject.Properties) {
                if ($pr.Name -like '_*') { continue }
                if (-not ($pr.Value -is [string])) { continue }
                $theirs = "$($pr.Value)".Trim()
                if ($theirs.Length -lt 4) { continue }
                if (-not $mine.Contains($pr.Name)) { continue }
                $ours = "$($mine[$pr.Name])".Trim()
                if (-not $ours -or $ours -ieq $theirs) { continue }
                if (-not $map.Contains($theirs)) { $map[$theirs] = [pscustomobject]@{ To = $ours; Field = $pr.Name; Brand = [string]$op.brand } }
            }
        }
    }
    return $map
}

function Clear-BrandAncestry {
    <# Apply the ancestry map across every colour/text-bearing part. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $WorkDir, [Parameter(Mandatory)] $Map)
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $parts = 0
    $values = 0
    foreach ($f in (Get-BrandColourPart -WorkDir $WorkDir)) {
        $tx = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
        $orig = $tx
        foreach ($from in @($Map.Keys)) {
            if (-not "$from") { continue }
            $n = ([regex]::Matches($tx, [regex]::Escape($from))).Count
            if ($n -eq 0) { continue }
            $tx = $tx.Replace([string]$from, [string]$Map[$from].To)
            $values += $n
        }
        if ($tx -ne $orig) { [System.IO.File]::WriteAllText($f.FullName, $tx, $utf8); $parts++ }
    }
    [pscustomobject]@{ Parts = $parts; Values = $values; MapSize = @($Map.Keys).Count }
}

function Test-BrandAncestryCleared {
    <# The ancestry half of the gate. Its forbidden set IS the map's keys. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $WorkDir, [Parameter(Mandatory)] $Map)
    $bad = New-Object System.Collections.Generic.List[string]
    $keys = @($Map.Keys)
    if ($keys.Count -eq 0) {
        $bad.Add('the ancestry map is EMPTY, so this arm checked nothing. A forbidden set of zero reports every template clean, which is how another institute name shipped in a delivered deck.')
    }
    foreach ($f in (Get-BrandColourPart -WorkDir $WorkDir)) {
        $tx = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
        $rel = $f.FullName.Substring($WorkDir.Length).TrimStart('\', '/') -replace '\\', '/'
        foreach ($k in $keys) {
            if ($tx.IndexOf([string]$k, [System.StringComparison]::Ordinal) -ge 0) {
                $bad.Add(("{0} still carries the template's ancestry: '{1}' ({2} of brand {3})" -f $rel, $k, $Map[$k].Field, $Map[$k].Brand))
            }
        }
    }
    [pscustomobject]@{ Ok = ($bad.Count -eq 0); Problems = @($bad); Tokens = $keys }
}

function Get-BrandPalettePairs {
    <#  MVC hex -> brand hex, by role - the same map Set-BrandPalette applies,
        plus the Learner Guide profile's own border hex (C7D0DD), which the
        assessment map does not carry because no assessment document uses it. #>
    param([Parameter(Mandatory)] $Palette)

    #  TAKE EACH ROLE UNDER EVERY NAME IT IS KNOWN BY, and this is not defensive
    #  padding. Two differently-shaped objects reach this function: a branding
    #  file's own palette, which names the light fill "lightFill", and
    #  Set-HousePalette's return, which names it "Fill". Both callers below pass
    #  the second one. A single-name lookup therefore fell through to its own
    #  default for that one role, so 'F0F2F7' mapped to itself, the loops that
    #  apply these pairs skip a pair that maps to itself, and the light fill was
    #  silently never swapped - in the deck AND in the guide. It shipped 158
    #  un-swapped MVC fills into a deck whose crossover sweep read clean.
    #  The assessment skill's copy of this map already carried the multi-name
    #  lookup; this one did not, which is the whole of the defect.
    #  RESOLVE OR THROW. NEVER FALL BACK TO THE SOURCE HEX.
    #  The multi-name lookup below fixed the case where a role was spelled
    #  differently on the object passed in. It did NOT fix the shape of the
    #  failure: the fallback argument was the other brand's own hex, so a role
    #  matching none of the names still resolved to itself, the apply loop skips
    #  a pair that maps to itself, and the swap silently did nothing for that
    #  role. That is exactly how 766 of the other brand's fills shipped through
    #  a gate that reported no crossover. A missing role is a broken brand file,
    #  and a broken brand file must stop the build rather than quietly produce a
    #  half-branded document.
    function PV {
        param($o, [string[]] $names, $role)
        foreach ($n in $names) {
            if ($o.PSObject.Properties.Name -contains $n -and $o.$n) { return [string]$o.$n }
        }
        throw ("Brand palette does not define the '{0}' role (looked for: {1}). A role that cannot be resolved would map to the source brand's own colour and swap nothing. Add it to the branding file." -f $role, ($names -join ', '))
    }
    [ordered]@{
        '234B8C' = PV $Palette @('dark','Dark')                  'dark'
        '2F60B4' = PV $Palette @('accent','Accent')              'accent'
        'F09C0C' = PV $Palette @('rule','Rule')                  'rule'
        'F5C800' = PV $Palette @('rule','Rule')                  'rule'
        'E45418' = PV $Palette @('accent','Accent')              'accent'
        '606060' = PV $Palette @('grey','Grey')                  'grey'
        'F0F2F7' = PV $Palette @('lightFill','Fill','LightFill') 'lightFill'
        'C9CFDD' = PV $Palette @('border','Border')              'border'
        'C7D0DD' = PV $Palette @('border','Border')              'border'
    }
}

function Set-BrandLogoAltText {
    <#  Describe every undescribed picture in the parts the brand swap touches.

        The template ships its masthead and running-head logos as
        <wp:docPr id=".." name="nclogo06_10"/> with no descr and no title, and
        Set-BrandLogo replaces the image BYTES without touching that element -
        correctly, because the element is the template's. So the two pictures
        every reader meets first were the two a screen reader could not name,
        and a placed-artwork gate that read only document.xml passed the header
        for a whole build. Runs over document.xml and every header and footer.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $WorkDir, [Parameter(Mandatory)][string] $Descr)
    $n = 0
    $parts = @('word/document.xml') + @(Get-ChildItem -LiteralPath (Join-Path $WorkDir 'word') -Filter '*.xml' -File |
        Where-Object { $_.Name -match '^(header|footer)\d*\.xml$' } | ForEach-Object { 'word/' + $_.Name })
    foreach ($part in $parts) {
        $x = Get-DocxPart -WorkDir $WorkDir -Part $part
        if (-not $x) { continue }
        $orig = $x
        $x = [regex]::Replace($x, '<wp:docPr\b([^>]*?)(/?)>', {
            param($m)
            $attrs = $m.Groups[1].Value
            if ($attrs -match '\bdescr="[^"]*[^\s"][^"]*"' -or $attrs -match '\btitle="[^"]*[^\s"][^"]*"') { return $m.Value }
            $script:__altN++
            '<wp:docPr' + $attrs + ' descr="' + [System.Security.SecurityElement]::Escape($Descr) + '"' + $m.Groups[2].Value + '>'
        })
        if ($x -ne $orig) { Set-DocxPart -WorkDir $WorkDir -Part $part -Content $x; $n++ }
    }
    [pscustomobject]@{ PartsChanged = $n; Described = [int]$script:__altN }
}
function Assert-BrandTemplateBrand {
    <#  The SOURCE brand of the templates this pack renders from, declared by
        the pack as templates.brand.

        It replaces the literal 'MVC' that used to stand for it inside this
        file, and it is a BLOCKING input, not a defaulted one: with no value
        there is no way to tell a same-brand build (where the identity strings
        legitimately survive and only the palette is normalised) from a
        cross-brand build (where a surviving identity string is the defect the
        gate exists to catch). So it refuses and names the key.  #>
    [CmdletBinding()]
    param([string] $TemplateBrand)
    if (-not "$TemplateBrand".Trim()) {
        throw "The template brand is not set. Pass -TemplateBrand with the RTO profile pack's templates.brand value (assets\rto-profile.<rto>.json). It declares the brand whose approved templates this artefact was rendered from, and the swap cannot tell a normalisation from a crossover without it - which is why the value was a literal 'MVC' in this file, and why every non-MVC pack was unbuildable."
    }
    return "$TemplateBrand".Trim()
}

function Set-GuideBrand {
    <#  Brand a rendered Learner Guide .docx in place.

        SAME-BRAND IS NOT A NO-OP. When the target brand equals the pack's
        templates.brand the logo and the identity are already right, but the
        palette step still runs, as NORMALISATION: the template's own legacy
        hexes are moved onto the current role colours. The version this
        replaces returned immediately, which guaranteed a hand-written repaint
        script and a 4c round on every same-brand build.

        RUNS ON A FRESH RENDER, BEFORE ARTWORK - always. At that point the
        only images in the package are the template's own marks, which is the
        precondition Set-BrandLogo's one-logo-per-part rule needs. After the
        artwork pass the document carries dozens of placed figures and the
        sweep rightly refuses to guess; re-prove the mark then with
        Assert-GuideBrand instead of re-swapping.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $Brand,
        [string] $Variant,
        [Parameter(Mandatory)][string] $UnitCode,
        [string] $TemplateBrand,
        [string] $BrandingDir
    )
    $TemplateBrand = Assert-BrandTemplateBrand -TemplateBrand $TemplateBrand

    if ($Brand -ieq $TemplateBrand) {
        #  NORMALISATION. No logo, no identity - both are already this brand's.
        #  The palette map still runs across every part, anchored.
        $palN = Set-HousePalette -Brand $Brand -Variant (Resolve-BrandVariant -Branding (Get-Branding -Brand $Brand) -UnitCode $UnitCode -Variant $Variant)
        $pairsN = Get-BrandPalettePairs -Palette $palN
        $wN = Expand-Docx -Path $Path
        $mediaN = Join-Path $wN 'word\media'
        if ((Test-Path $mediaN) -and @(Get-ChildItem -LiteralPath $mediaN -Filter 'genimg_*' -File).Count -gt 0) {
            throw 'This guide already carries placed artwork. Set-GuideBrand runs on a fresh render, before the artwork pass; use Assert-GuideBrand to re-prove the mark on a placed document.'
        }
        $swN = Invoke-BrandPaletteSweep -WorkDir $wN -Pairs $pairsN
        $ancMapN = Get-BrandAncestryMap -Branding (Get-Branding -Brand $Brand) -Variant $Variant -BrandingDir $BrandingDir
        $null = Clear-BrandAncestry -WorkDir $wN -Map $ancMapN
        $gN = Test-BrandPaletteSwept -WorkDir $wN -Pairs $pairsN
        $aN = Test-BrandAncestryCleared -WorkDir $wN -Map $ancMapN
        if (-not $gN.Ok -or -not $aN.Ok) { throw ("Guide palette normalisation gate FAILED:`n  - " + (@(@($gN.Problems) + @($aN.Problems)) -join "`n  - ")) }
        Compress-Docx -WorkDir $wN -Path $Path | Out-Null
        return [pscustomobject]@{ Brand = $Brand; Variant = $Variant; TemplateBrand = $TemplateBrand
                                  Swapped = $false; Normalised = $true
                                  PaletteRefs = $swN.Values; PartsRecolored = $swN.Parts; PartsInspected = $swN.PartsInspected }
    }

    $b = Get-Branding -Brand $Brand
    $Variant = Resolve-BrandVariant -Branding $b -UnitCode $UnitCode -Variant $Variant
    $pal = Set-HousePalette -Brand $Brand -Variant $Variant
    $logo = Join-Path $script:SkillRoot $b.variants.$Variant.logo.path

    $w = Expand-Docx -Path $Path
    $mediaDir = Join-Path $w 'word\media'
    if ((Test-Path $mediaDir) -and @(Get-ChildItem -LiteralPath $mediaDir -Filter 'genimg_*' -File).Count -gt 0) {
        throw 'This guide already carries placed artwork. Set-GuideBrand runs on a fresh render, before the artwork pass; use Assert-GuideBrand to re-prove the mark on a placed document.'
    }
    $lr = Set-BrandLogo -WorkDir $w -LogoPath $logo
    $script:__altN = 0
    $brandName = ''
    $vObj = $null; if ($Variant -and $b.PSObject.Properties.Name -contains 'variants' -and $b.variants.PSObject.Properties.Name -contains $Variant) { $vObj = $b.variants.$Variant }
    foreach ($k in @('tradingName','name','displayName','title')) { if ($vObj -and $vObj.PSObject.Properties.Name -contains $k -and $vObj.$k) { $brandName = [string]$vObj.$k; break } }
    if (-not $brandName -and $b.PSObject.Properties.Name -contains 'brand' -and $b.brand) { $brandName = [string]$b.brand }
    if (-not $brandName -and $b.PSObject.Properties.Name -contains 'rto' -and $b.rto.PSObject.Properties.Name -contains 'shortName') { $brandName = [string]$b.rto.shortName }
    if (-not $brandName) { $brandName = $Brand }
    $ar = Set-BrandLogoAltText -WorkDir $w -Descr ($brandName + ' logo')
    $pr = Set-BrandPalette -WorkDir $w -Palette $pal
    #  The guide's own hexes, which the assessment role map does not carry -
    #  C7D0DD among them. THREE THINGS WERE WRONG WITH THE VERSION THIS
    #  REPLACES, and all three are the same mistake in different clothes:
    #  it read word/document.xml ONLY (headers, footers, styles and numbering
    #  all draw borders too), it matched case-sensitively (OOXML writers emit
    #  both cases), and it replaced a BARE hex rather than a colour attribute.
    #  It is now the same anchored sweep the deck uses, over every part.
    $extra = Get-BrandPalettePairs -Palette $pal
    $sw = Invoke-BrandPaletteSweep -WorkDir $w -Pairs $extra
    $n = $sw.Values
    $ir = Set-BrandIdentity -WorkDir $w -Branding $b -Variant $Variant

    $logoDir = Join-Path $script:SkillRoot 'assets\logos'
    $assets = @(); if (Test-Path $logoDir) { $assets = @(Get-ChildItem -LiteralPath $logoDir -File | ForEach-Object { $_.FullName }) }
    $oldH = @(); if ($lr.PSObject.Properties.Name -contains 'OldHashes') { $oldH = @($lr.OldHashes) }
    $null = Assert-BrandLogo -WorkDir $w -ExpectedLogoPath $logo -ForbiddenLogoPaths $assets -ForbiddenHashes $oldH

    $gg = Test-BrandPaletteSwept -WorkDir $w -Pairs $extra
    if (-not $gg.Ok) { throw ("Guide palette gate FAILED - the guide would ship with the source brand's colours:`n  - " + (@($gg.Problems) -join "`n  - ")) }

    Compress-Docx -WorkDir $w -Path $Path | Out-Null
    [pscustomobject]@{ Brand = $Brand; Variant = $Variant; TemplateBrand = $TemplateBrand
                       Swapped = $true; Normalised = $false
                       Logo = $lr.Replaced; PaletteRefs = $pr.Total + $n; IdentityRefs = $ir.Total }
}

function Assert-GuideBrand {
    <#  Re-prove the mark on a FINISHED guide - after artwork, at delivery.
        Headers must carry the resolved variant's mark; no media part may be
        any other known mark. Safe on a document full of placed figures.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $Brand,
        [string] $Variant,
        [Parameter(Mandatory)][string] $UnitCode,
        [string] $TemplateBrand
    )
    $TemplateBrand = Assert-BrandTemplateBrand -TemplateBrand $TemplateBrand
    $w = Expand-Docx -Path $Path
    $logoDir = Join-Path $script:SkillRoot 'assets\logos'
    $assets = @(); if (Test-Path $logoDir) { $assets = @(Get-ChildItem -LiteralPath $logoDir -File | ForEach-Object { $_.FullName }) }
    if ($Brand -ieq $TemplateBrand) {
        if ($assets.Count -gt 0) { $null = Assert-BrandLogo -WorkDir $w -ForbiddenLogoPaths $assets }
        return [pscustomobject]@{ Ok = $true; Brand = $Brand; TemplateBrand = $TemplateBrand }
    }
    $b = Get-Branding -Brand $Brand
    $Variant = Resolve-BrandVariant -Branding $b -UnitCode $UnitCode -Variant $Variant
    $logo = Join-Path $script:SkillRoot $b.variants.$Variant.logo.path
    $null = Assert-BrandLogo -WorkDir $w -ExpectedLogoPath $logo -ForbiddenLogoPaths $assets
    [pscustomobject]@{ Ok = $true; Brand = $Brand; Variant = $Variant }
}

function Set-DeckBrand {
    <#  Brand a rendered Delivery PowerPoint .pptx in place.

        SAME-BRAND IS NOT A NO-OP - it is NORMALISATION. When the target brand
        equals the pack's templates.brand the mark and the identity strings are
        already this brand's, but the template still carries its OWN legacy
        hexes (F5C800 where the rule colour is now F09C0C, E45418 where the
        accent is now 2F60B4) and the OTHER trading name in its docProps. The
        version this replaces returned at the first line on a same-brand build,
        so every such build ended with a hand-written repaint script and a 4c
        remediation round for a defect knowable at minute one.

        1. verifies the logo part IS the known source mark (refuses to guess),
           then writes the brand variant's mark over it,
        2. rewrites the drawing extents of every shape that draws it, holding
           width, so the 3.53:1 culinary mark is never stretched to 2.46:1,
        3. remaps the palette BY ROLE across EVERY .xml and .rels part in the
           package - notesMasters included, which the three named directories
           of the previous version missed - anchored on the colour attribute,
        4. swaps the identity (docProps and every text part, rels included),
        5. gates the result byte-level: the logo part must BE the variant's
           mark, no media part may match any other known mark, and no source
           colour the map actually moves may survive in any part.

        Steps 1, 2 and the identity half of 4 are skipped on a normalisation
        run; steps 3 and 5 and the docProps ancestry sweep always run.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $Brand,
        [string] $Variant,
        [Parameter(Mandatory)][string] $UnitCode,
        [string] $TemplateBrand,
        [string] $BrandingDir,
        [string] $LogoMediaName = 'image1.png'
    )
    $TemplateBrand = Assert-BrandTemplateBrand -TemplateBrand $TemplateBrand
    $normalise = ($Brand -ieq $TemplateBrand)

    $b = Get-Branding -Brand $Brand
    $Variant = Resolve-BrandVariant -Branding $b -UnitCode $UnitCode -Variant $Variant
    $pal = Set-HousePalette -Brand $Brand -Variant $Variant
    #  Resolves every role or THROWS. On a normalisation run a role that maps
    #  to itself is the expected no-op; on a swap it is an unresolved property
    #  name, and Stage 0's palette check is what tells the two apart.
    $pairs = Get-BrandPalettePairs -Palette $pal

    $w = Expand-Docx -Path $Path
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $partsWithLogo = 0
    $newMd5 = ''
    $logoPart = Join-Path $w ("ppt\media\" + $LogoMediaName)

    if (-not $normalise) {
        $logo = Join-Path $script:SkillRoot $b.variants.$Variant.logo.path
        if (-not (Test-Path $logo)) { throw "Brand logo not found: $logo" }
        $logoPx = Get-PngPixelSize -Path $logo
        if (-not (Test-Path $logoPart)) { throw "Deck logo part not found: ppt/media/$LogoMediaName" }
        $srcMd5 = Get-FileMd5 -Path $logoPart
        $newMd5 = Get-FileMd5 -Path $logo
        if ($srcMd5 -ne $script:DECK_MVC_LOGO_MD5 -and $srcMd5 -ne $newMd5) {
            throw ("ppt/media/$LogoMediaName is neither the known source deck mark nor the target mark " +
                   "(md5 $srcMd5). Refusing to overwrite an image I cannot identify.")
        }

        # 1. the mark
        Copy-Item -LiteralPath $logo -Destination $logoPart -Force

        # 2. extents, width held, in every part that draws it
        foreach ($xmlFile in (Get-BrandColourPart -WorkDir $w | Where-Object { $_.Name -like '*.xml' })) {
            $rp = Join-Path $xmlFile.DirectoryName ('_rels\' + $xmlFile.Name + '.rels')
            if (-not (Test-Path $rp)) { continue }
            $rl = [System.IO.File]::ReadAllText($rp, [System.Text.Encoding]::UTF8)
            $rids = @([regex]::Matches($rl, 'Id="([^"]+)"[^>]*Target="[^"]*media/' + [regex]::Escape($LogoMediaName) + '"') |
                      ForEach-Object { $_.Groups[1].Value })
            # attribute order can vary - second pass with Target first
            $rids += @([regex]::Matches($rl, 'Target="[^"]*media/' + [regex]::Escape($LogoMediaName) + '"[^>]*Id="([^"]+)"') |
                       ForEach-Object { $_.Groups[1].Value })
            $rids = @($rids | Select-Object -Unique)
            if ($rids.Count -eq 0) { continue }
            $xml = [System.IO.File]::ReadAllText($xmlFile.FullName, [System.Text.Encoding]::UTF8)
            $changed = $false
            foreach ($rid in $rids) {
                # every <p:pic> whose blip embeds this rid: hold cx, recompute cy
                $pos = 0
                while ($true) {
                    $pi = $xml.IndexOf('<p:pic>', $pos)
                    $piA = $xml.IndexOf('<p:pic ', $pos)
                    if ($piA -ge 0 -and ($pi -lt 0 -or $piA -lt $pi)) { $pi = $piA }
                    if ($pi -lt 0) { break }
                    $pe = $xml.IndexOf('</p:pic>', $pi)
                    if ($pe -lt 0) { break }
                    $block = $xml.Substring($pi, $pe - $pi)
                    if ($block.Contains('r:embed="' + $rid + '"')) {
                        $m = [regex]::Match($block, '<a:ext cx="(\d+)" cy="(\d+)"/>')
                        if ($m.Success) {
                            $cx = [long]$m.Groups[1].Value
                            $cy = [long][math]::Round($cx / $logoPx.Ratio)
                            $newBlock = $block.Remove($m.Index, $m.Length).Insert($m.Index, "<a:ext cx=""$cx"" cy=""$cy""/>")
                            $xml = $xml.Remove($pi, $pe - $pi).Insert($pi, $newBlock)
                            $pe = $pi + $newBlock.Length
                            $changed = $true
                        }
                    }
                    $pos = $pe
                }
            }
            if ($changed) { [System.IO.File]::WriteAllText($xmlFile.FullName, $xml, $utf8); $partsWithLogo++ }
        }
    }

    # 3. palette, by role, in EVERY part, anchored on the colour attribute
    $sweep = Invoke-BrandPaletteSweep -WorkDir $w -Pairs $pairs

    # 4. identity - every text-bearing part, rels included, enumerated
    $identityRefs = 0
    if (-not $normalise) {
        $idParts = @(Get-BrandColourPart -WorkDir $w |
                     ForEach-Object { $_.FullName.Substring($w.Length).TrimStart('\', '/') -replace '\\', '/' })
        $ir = Set-BrandIdentity -WorkDir $w -Branding $b -Variant $Variant -Parts $idParts
        $identityRefs = $ir.Total
    }
    #  The template's own ancestry: docProps carries the OTHER trading name.
    #  This runs on a NORMALISATION build too - it is the template's history,
    #  not the other brand's, and leaving it is how a same-brand deck shipped
    #  naming a different institute in its file properties.
    $ancestryMap = Get-BrandAncestryMap -Branding $b -Variant $Variant -BrandingDir $BrandingDir
    $anc = Clear-BrandAncestry -WorkDir $w -Map $ancestryMap
    $ancestry = $anc.Values

    # 5. the gate - blocking, byte-level, over the enumerated part set
    $bad = New-Object System.Collections.Generic.List[string]
    if (-not $normalise) {
        if ((Get-FileMd5 -Path $logoPart) -ne $newMd5) { $bad.Add("ppt/media/$LogoMediaName is not the $Variant mark after the swap") }
        $logoDir = Join-Path $script:SkillRoot 'assets\logos'
        $forbidden = @{ $script:DECK_MVC_LOGO_MD5 = 'the source deck mark' }
        if (Test-Path $logoDir) {
            foreach ($f in Get-ChildItem -LiteralPath $logoDir -File) {
                $h = Get-FileMd5 -Path $f.FullName
                if ($h -ne $newMd5) { $forbidden[$h] = $f.Name }
            }
        }
        $mediaDir = Join-Path $w 'ppt\media'
        if (Test-Path $mediaDir) {
            foreach ($mf in Get-ChildItem -LiteralPath $mediaDir -File) {
                $h = Get-FileMd5 -Path $mf.FullName
                if ($forbidden.ContainsKey($h)) { $bad.Add("ppt/media/$($mf.Name) is the WRONG mark: $($forbidden[$h])") }
            }
        }
    }

    #  The colour half of the gate. Its token list is $pairs.Keys minus the
    #  self-mapping pairs, so it can never disagree with the swap that just
    #  ran - the typed list it replaces carried three of nine hexes and printed
    #  "no crossover" over 766 live occurrences.
    $pg = Test-BrandPaletteSwept -WorkDir $w -Pairs $pairs
    foreach ($x in $pg.Problems) { $bad.Add($x) }

    #  The ancestry half, on BOTH paths. It has to be here and not only on a
    #  swap: the template's docProps named a DIFFERENT institute, and a
    #  same-brand build used to return before it ever looked.
    $ag = Test-BrandAncestryCleared -WorkDir $w -Map $ancestryMap
    foreach ($x in $ag.Problems) { $bad.Add($x) }

    #  The identity half. Its forbidden set is DERIVED from the source brand's
    #  own branding profile, never typed, and it applies only to a swap: on a
    #  normalisation run this brand's strings are supposed to be there.
    if (-not $normalise) {
        $forbiddenText = New-Object System.Collections.Generic.List[string]
        $srcBranding = $null
        try { $srcBranding = Get-Branding -Brand $TemplateBrand } catch { }
        if ($null -eq $srcBranding) {
            $bad.Add(("the branding profile for the template brand '{0}' does not load, so the identity half of this gate has no derived forbidden set. A forbidden set of zero is not a clean sweep." -f $TemplateBrand))
        }
        else {
            foreach ($s in (Get-BrandIdentityToken -Branding $srcBranding)) { $forbiddenText.Add($s) }
        }
        foreach ($other in @($b.variants.PSObject.Properties.Name)) {
            if ($other -eq 'default' -or $other -like '_*' -or $other -eq $Variant) { continue }
            $on = [string]$b.variants.$other.tradingName
            if ($on) { $forbiddenText.Add($on) }
        }
        $forbiddenText = @($forbiddenText | Where-Object { "$_".Trim().Length -ge 4 } | Select-Object -Unique)
        if ($forbiddenText.Count -eq 0) {
            $bad.Add('the identity arm of the deck brand gate derived NO forbidden string. A sweep with an empty forbidden set reports clean over anything.')
        }
        foreach ($xmlFile in (Get-BrandColourPart -WorkDir $w)) {
            $tx = [System.IO.File]::ReadAllText($xmlFile.FullName, [System.Text.Encoding]::UTF8)
            $rel = $xmlFile.FullName.Substring($w.Length).TrimStart('\', '/') -replace '\\', '/'
            foreach ($tok in $forbiddenText) {
                if ($tx.IndexOf($tok, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $bad.Add("$rel still carries '$tok'") }
            }
        }
    }

    if ($bad.Count -gt 0) {
        throw (("Deck brand gate FAILED - the deck would ship with the wrong brand ({0} run):`n  - " -f $(if ($normalise) { 'normalisation' } else { 'swap' })) + (@($bad | Select-Object -Unique) -join "`n  - "))
    }

    Compress-Docx -WorkDir $w -Path $Path | Out-Null
    [pscustomobject]@{ Brand = $Brand; Variant = $Variant; TemplateBrand = $TemplateBrand
                       Swapped = (-not $normalise); Normalised = $normalise
                       LogoPartsResized = $partsWithLogo; PartsRecolored = $sweep.Parts
                       PartsInspected = $sweep.PartsInspected; PaletteRefs = $sweep.Values
                       Moved = $sweep.Moved; DocPropsAncestry = $ancestry; IdentityRefs = $identityRefs }
}

function Get-BrandIdentityToken {
    <#  Every identity string a branding profile carries, DERIVED by walking
        the profile rather than typed here.

        The list this replaces was four literals - 'Meridian Vocational',
        '234B8C', 'F09C0C', 'mvc.edu.au' - which is the hand-listed check-set
        this whole file exists to argue against, and which made every non-MVC
        source template unswappable. Anything four characters or longer that
        looks like a name, a domain, a code or a trading name counts.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Branding)
    $out = New-Object System.Collections.Generic.List[string]
    $add = {
        param($node, $depth)
        if ($null -eq $node -or $depth -gt 4) { return }
        if ($node -is [string]) { if ("$node".Trim().Length -ge 4) { $out.Add("$node".Trim()) }; return }
        if ($node -is [System.Collections.IEnumerable] -and -not ($node -is [string])) {
            foreach ($x in $node) { & $add $x ($depth + 1) }
            return
        }
        if ($node.PSObject -and @($node.PSObject.Properties).Count -gt 0) {
            foreach ($p in $node.PSObject.Properties) {
                if ($p.Name -like '_*') { continue }
                #  Palette hexes are handled by the colour half, on the colour
                #  attribute; a bare six-hex here would match EMU digits.
                if ($p.Name -ieq 'palette') { continue }
                & $add $p.Value ($depth + 1)
            }
        }
    }
    foreach ($k in @('rto', 'brand', 'tagline')) {
        if (@($Branding.PSObject.Properties.Name) -contains $k) { & $add $Branding.$k 0 }
    }
    if (@($Branding.PSObject.Properties.Name) -contains 'variants') {
        foreach ($p in $Branding.variants.PSObject.Properties) {
            if ($p.Name -eq 'default' -or $p.Name -like '_*') { continue }
            foreach ($k in @('tradingName', 'name', 'displayName', 'title', 'website', 'email')) {
                if (@($p.Value.PSObject.Properties.Name) -contains $k) { & $add $p.Value.$k 0 }
            }
        }
    }
    #  A path fragment or a file name is not an identity string.
    return @($out | Where-Object { $_ -notmatch '\\' -and $_ -notmatch '\.(png|jpe?g|docx|pptx|json)$' } | Select-Object -Unique)
}
Write-Verbose 'Set-ResourceBrand.ps1 loaded.'

# ---------------------------------------------------------------------------
# Self-test - plants a defect for every rule this file owns, on a fixture cut
# from the RTO pack's own approved deck template. No Office, no network.
#
# It is reached as `& Set-ResourceBrand.ps1 -SelfTest`. A DOT-SOURCE has
# InvocationName '.', and its $ResourceBrandSelfTest is $false, so dot-sourcing
# this file from Lib-Resolve.ps1 never runs it.
# ---------------------------------------------------------------------------

function Invoke-ResourceBrandSelfTest {
    [CmdletBinding()]
    param()
    $script:stPass = 0
    $script:stFail = 0
    #  Declared before anything runs, so a body that dies half way through is
    #  caught by the count rather than by nobody.
    $script:stExpected = 28
    $ok  = { param($m) $script:stPass++; Write-Host "  PASS  $m" -ForegroundColor Green }
    $bad = { param($m) $script:stFail++; Write-Host "  FAIL  $m" -ForegroundColor Red }

    Write-Host ''
    Write-Host 'Set-ResourceBrand self-test - every plant verified to have landed before it is detected' -ForegroundColor Cyan

    #  The shared library, which a direct run has not loaded. Lib-Resolve
    #  dot-sources THIS file again; the guard at the tail keeps that from
    #  recursing.
    . (Join-Path $PSScriptRoot 'Lib-Resolve.ps1')
    . (Join-Path $PSScriptRoot 'Lib-RtoProfile.ps1')

    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('srb_selftest_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        # -------------------------------------------------------------------
        # 1. the template brand is a BLOCKING input, not a default
        # -------------------------------------------------------------------
        $threw = ''
        try { $null = Assert-BrandTemplateBrand -TemplateBrand '' } catch { $threw = $_.Exception.Message }
        if ($threw -match 'templates\.brand') { & $ok 'an absent template brand REFUSES and names templates.brand' }
        else { & $bad "absent template brand did not name the key: $threw" }
        $threw = ''
        try { $null = Set-DeckBrand -Path (Join-Path $tmp 'nope.pptx') -Brand 'MVC' -UnitCode 'X' } catch { $threw = $_.Exception.Message }
        if ($threw -match 'templates\.brand') { & $ok 'Set-DeckBrand with no -TemplateBrand refuses before it opens anything' }
        else { & $bad "Set-DeckBrand without -TemplateBrand: $threw" }
        $threw = ''
        try { $null = Set-GuideBrand -Path (Join-Path $tmp 'nope.docx') -Brand 'MVC' -UnitCode 'X' } catch { $threw = $_.Exception.Message }
        if ($threw -match 'templates\.brand') { & $ok 'Set-GuideBrand with no -TemplateBrand refuses before it opens anything' }
        else { & $bad "Set-GuideBrand without -TemplateBrand: $threw" }

        # -------------------------------------------------------------------
        # 2. the replace is ANCHORED on the colour attribute
        # -------------------------------------------------------------------
        $planted = '<a:srgbClr val="F5C800"/><a:ext cx="606060" cy="171000"/>' +
                   '<a:t>the legacy rule colour F5C800 is named in this sentence</a:t>' +
                   '<w:shd w:fill="F5C800"/><a:t>606060</a:t><p:ph idx="606060"/>'
        if ($planted -match 'cx="606060"' -and $planted -match '<a:t>606060</a:t>') { & $ok 'plant landed: an EMU attribute and a bare hex in prose sit beside two real colour attributes' }
        else { & $bad 'the anchoring plant did not land' }
        $r = Set-BrandColourValue -Xml $planted -From 'F5C800' -To 'F09C0C'
        if ($r.Changed -eq 2) { & $ok 'the anchored replace moves BOTH colour attributes (srgbClr val and w:shd w:fill)' }
        else { & $bad ("anchored replace changed {0} attribute value(s), expected 2" -f $r.Changed) }
        if ($r.Xml -match '<a:t>the legacy rule colour F5C800 is named in this sentence</a:t>') { & $ok 'a bare hex INSIDE TEXT is untouched by the anchored replace' }
        else { & $bad 'the anchored replace rewrote a hex inside prose' }
        $r2 = Set-BrandColourValue -Xml $r.Xml -From '606060' -To 'AABBCC'
        if ($r2.Xml -match 'cx="606060"') { & $ok 'a 606060 inside an EMU extent attribute is untouched (cx is not a colour attribute)' }
        else { & $bad 'the anchored replace rewrote an EMU measurement' }
        if ($r2.Xml -match '<a:t>AABBCC</a:t>') { & $ok 'a 606060 that is a WHOLE text run IS relabelled - a swatch caption must not outlive the colour it names' }
        else { & $bad 'the whole-run label form did not move' }
        if ($r2.Xml -match 'idx="606060"') { & $ok 'and a non-colour attribute carrying the same six characters (p:ph idx) is untouched' }
        else { & $bad 'the replace rewrote a placeholder index' }
        $lbl = Set-BrandColourValue -Xml '<a:t>#F5C800</a:t><a:t>the F5C800 swatch</a:t><w:t>F5C800</w:t>' -From 'F5C800' -To 'F09C0C'
        if ($lbl.Changed -eq 2 -and $lbl.Xml -match '<a:t>#F09C0C</a:t>' -and $lbl.Xml -match '<w:t>F09C0C</w:t>') { & $ok 'a swatch LABEL that is wholly a hex is relabelled, in both a: and w: runs' }
        else { & $bad ('swatch label: changed=' + $lbl.Changed + ' ' + $lbl.Xml) }
        if ($lbl.Xml -match '<a:t>the F5C800 swatch</a:t>') { & $ok 'and a run that merely MENTIONS the hex is still untouched' }
        else { & $bad 'the label form leaked into prose' }
        if ($r2.Changed -eq 1) { & $ok 'and it reports exactly 1 change - the label - not the EMU extent, not the placeholder index' }
        else { & $bad ("606060 replace reported {0} changes, expected 1" -f $r2.Changed) }
        if ((Measure-BrandColour -Xml $planted -Hex '606060') -eq 1) { & $ok 'Measure-BrandColour counts the same two anchored forms the swap moves, so the gate and the swap cannot disagree' }
        else { & $bad ('Measure-BrandColour counted {0} for 606060, expected 1' -f (Measure-BrandColour -Xml $planted -Hex '606060')) }

        # -------------------------------------------------------------------
        # 3. an unresolved role THROWS rather than mapping to itself
        # -------------------------------------------------------------------
        $threw = ''
        try { $null = Get-BrandPalettePairs -Palette ([pscustomobject]@{ Dark = '111111'; Accent = '222222' }) } catch { $threw = $_.Exception.Message }
        if ($threw -match "'rule'") { & $ok 'a palette missing a role THROWS and names the role, never maps it to itself' }
        else { & $bad "missing role did not throw by name: $threw" }

        # -------------------------------------------------------------------
        # 4. NORMALISATION on a real same-brand deck, from the pack's template
        # -------------------------------------------------------------------
        $pack = $null
        try { $pack = Get-RtoProfile -Rto 'MVC' } catch { }
        if ($null -eq $pack -or -not (Test-Path -LiteralPath $pack.DeckTemplate)) {
            & $bad 'no MVC deck template resolved from the RTO pack - the normalisation arm could not run, and a self-test that plants nothing proves nothing'
        }
        else {
            $tplBrand = [string](Get-RtoProp -Object $pack.Raw -Path 'templates.brand')
            if ($tplBrand) { & $ok ("the pack declares templates.brand = {0}, so the swap knows what it is rendering FROM" -f $tplBrand) }
            else { & $bad 'the pack declares no templates.brand' }

            $fx = Join-Path $tmp 'fixture.pptx'
            Copy-Item -LiteralPath $pack.DeckTemplate -Destination $fx -Force

            #  Plant: a legacy hex in notesMaster1.xml (a part the previous
            #  three-directory walk never opened), an EMU attribute carrying
            #  606060, and a bare hex in a notes paragraph.
            $wd = Expand-Docx -Path $fx
            $nm = Join-Path $wd 'ppt\notesMasters\notesMaster1.xml'
            if (-not (Test-Path $nm)) { & $bad 'the deck template has no notesMasters part to plant in' }
            else {
                $x = [System.IO.File]::ReadAllText($nm, [System.Text.Encoding]::UTF8)
                $x = [regex]::Replace($x, '(<p:cSld>)', '$1<!--PLANT--><a:srgbClr val="F5C800"/><a:ext cx="606060" cy="171000"/><a:t>brand hex F5C800 named in prose</a:t>', 1)
                [System.IO.File]::WriteAllText($nm, $x, (New-Object System.Text.UTF8Encoding($false)))
                $back = [System.IO.File]::ReadAllText($nm, [System.Text.Encoding]::UTF8)
                if ($back -match 'val="F5C800"' -and $back -match 'cx="606060"' -and $back -match 'brand hex F5C800 named in prose') { & $ok 'plant landed in ppt/notesMasters/notesMaster1.xml and was read back' }
                else { & $bad 'the notesMaster plant did not land' }
                Compress-Docx -WorkDir $wd -Path $fx | Out-Null

                $parts = @(Get-BrandColourPart -WorkDir (Expand-Docx -Path $fx))
                if (@($parts | Where-Object { $_.Name -eq 'notesMaster1.xml' }).Count -eq 1) { & $ok ('the enumerated part set reaches notesMasters ({0} parts in all)' -f $parts.Count) }
                else { & $bad 'notesMaster1.xml is not in the enumerated part set' }

                $res = $null
                $err = ''
                try { $res = Set-DeckBrand -Path $fx -Brand 'MVC' -UnitCode 'SITXINV007' -TemplateBrand $tplBrand } catch { $err = $_.Exception.Message }
                if ($null -ne $res -and $res.Normalised -and -not $res.Swapped) { & $ok ('a same-brand build NORMALISES rather than no-opping: {0} attribute value(s) moved across {1} part(s) of {2}' -f $res.PaletteRefs, $res.PartsRecolored, $res.PartsInspected) }
                else { & $bad ("normalisation run: " + $err + ($res | Out-String)) }

                if ($null -ne $res -and $res.PaletteRefs -gt 0) { & $ok 'the normalisation moved at least one legacy colour - a no-op here is the defect this change removes' }
                else { & $bad 'the normalisation moved nothing' }

                $wd2 = Expand-Docx -Path $fx
                $nm2 = [System.IO.File]::ReadAllText((Join-Path $wd2 'ppt\notesMasters\notesMaster1.xml'), [System.Text.Encoding]::UTF8)
                if ($nm2 -match 'val="F09C0C"' -and $nm2 -notmatch 'val="F5C800"') { & $ok 'the legacy hex in notesMaster1.xml was moved onto the current rule colour' }
                else { & $bad 'notesMaster1.xml was not normalised' }
                if ($nm2 -match 'cx="606060"') { & $ok 'the EMU extent attribute in the same part is byte-identical' }
                else { & $bad 'the EMU extent attribute was rewritten' }
                if ($nm2 -match 'brand hex F5C800 named in prose') { & $ok 'the hex named in prose in the same part is byte-identical' }
                else { & $bad 'prose naming a hex was rewritten' }

                #  the step-5 gate, on the swept package: clean, then planted
                $pal = Set-HousePalette -Brand 'MVC' -Variant (Resolve-BrandVariant -Branding (Get-Branding -Brand 'MVC') -UnitCode 'SITXINV007' -Variant $null)
                $pairs = Get-BrandPalettePairs -Palette $pal
                $g1 = Test-BrandPaletteSwept -WorkDir $wd2 -Pairs $pairs
                if ($g1.Ok) { & $ok 'the step-5 palette gate passes on the normalised package (the clean control)' }
                else { & $bad ('clean control failed: ' + (@($g1.Problems) -join '; ')) }
                $expected = @(@($pairs.Keys) | Where-Object { "$($pairs[$_])" -ine "$_" })
                if (@($g1.Tokens).Count -eq $expected.Count -and @($g1.Tokens).Count -gt 0) { & $ok ('the gate token list is DERIVED from $pairs.Keys - {0} source colour(s) the map actually moves, self-mapping pairs excluded' -f @($g1.Tokens).Count) }
                else { & $bad ('token list {0}, expected {1}' -f (@($g1.Tokens) -join ','), (@($expected) -join ',')) }

                $nmp = Join-Path $wd2 'ppt\notesMasters\notesMaster1.xml'
                $x2 = [System.IO.File]::ReadAllText($nmp, [System.Text.Encoding]::UTF8)
                $x2 = [regex]::Replace($x2, '(<p:cSld>)', '$1<a:srgbClr val="E45418"/>', 1)
                [System.IO.File]::WriteAllText($nmp, $x2, (New-Object System.Text.UTF8Encoding($false)))
                if (([System.IO.File]::ReadAllText($nmp, [System.Text.Encoding]::UTF8)) -match 'val="E45418"') { & $ok 'plant landed: a legacy accent hex in notesMaster1.xml' }
                else { & $bad 'the step-5 plant did not land' }
                $g2 = Test-BrandPaletteSwept -WorkDir $wd2 -Pairs $pairs
                if (-not $g2.Ok -and (@($g2.Problems) -join ' ') -match 'notesMaster1\.xml' -and (@($g2.Problems) -join ' ') -match 'E45418') { & $ok 'the step-5 gate FAILS on it and names the part and the colour' }
                else { & $bad ('planted gate: ok=' + $g2.Ok + ' ' + (@($g2.Problems) -join '; ')) }

                #  and the crossover gate agrees, with no build-local script.
                #  On a SECOND, UNPLANTED copy: the fixture above deliberately
                #  carries a hex named in prose, which Check-Identity reads as
                #  a bare substring and rightly reports. Proving the gate needs
                #  the artefact a build would actually deliver.
                $ci = Join-Path $PSScriptRoot 'Check-Identity.ps1'
                if (Test-Path $ci) {
                    $clean = Join-Path $tmp 'clean.pptx'
                    Copy-Item -LiteralPath $pack.DeckTemplate -Destination $clean -Force
                    $before = & $ci -Path @($clean) -Brand 'MVC' -SkillDir (Split-Path -Parent $PSScriptRoot) -Quiet 2>&1
                    $rcBefore = $LASTEXITCODE
                    if ($rcBefore -ne 0) { & $ok ('the CONTROL: the approved deck template straight off disk FAILS Check-Identity (exit {0}) - this is the 4c round every same-brand build used to pay for' -f $rcBefore) }
                    else { & $bad 'the unbranded template already passes Check-Identity, so the normalisation arm proves nothing' }
                    $null = Set-DeckBrand -Path $clean -Brand 'MVC' -UnitCode 'SITXINV007' -TemplateBrand $tplBrand
                    $out = & $ci -Path @($clean) -Brand 'MVC' -SkillDir (Split-Path -Parent $PSScriptRoot) -Quiet 2>&1
                    $rc = $LASTEXITCODE
                    if ($rc -eq 0) { & $ok 'and after Set-DeckBrand NORMALISATION the same deck PASSES Check-Identity, with no build-local repaint script' }
                    else { & $bad ("Check-Identity after normalisation, exit {0}: {1}" -f $rc, (($out | Out-String).Trim())) }
                }
                else { & $bad 'Check-Identity.ps1 is not beside this file' }
            }
        }
    }
    catch {
        #  A self-test that dies half way through and exits 0 is the silent
        #  success this whole file argues against. It is a FAILURE.
        & $bad ('the self-test itself threw before it finished: ' + $_.Exception.Message + ' [' + $_.InvocationInfo.ScriptLineNumber + ']')
    }
    finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }

    Write-Host ''
    Write-Host ("  {0} passed, {1} failed" -f $script:stPass, $script:stFail) -ForegroundColor $(if ($script:stFail) { 'Red' } else { 'Green' })
    if ($script:stFail) { return 4 }
    if (($script:stPass + $script:stFail) -lt $script:stExpected) {
        Write-Host ('  FAIL  only {0} of the {1} declared cases ran - a case that never ran cannot pass' -f ($script:stPass + $script:stFail), $script:stExpected) -ForegroundColor Red
        return 4
    }
    return 0
}

#  A dot-source has InvocationName '.', so this never fires from Lib-Resolve.
if ($ResourceBrandSelfTest -and $MyInvocation.InvocationName -ne '.') {
    exit (Invoke-ResourceBrandSelfTest)
}
