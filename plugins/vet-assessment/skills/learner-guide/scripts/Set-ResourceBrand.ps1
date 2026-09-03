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
function Set-GuideBrand {
    <#  Brand a rendered Learner Guide .docx in place. No-op for MVC.

        RUNS ON A FRESH RENDER, BEFORE ARTWORK - always. At that point the
        only images in the package are the template's own marks, which is the
        precondition Set-BrandLogo's one-logo-per-part rule needs. After the
        artwork pass the document carries dozens of placed figures and the
        sweep rightly refuses to guess; re-prove the mark then with
        Assert-GuideBrand instead of re-swapping.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [ValidateSet('MVC','ACI')][string] $Brand = 'MVC',
        [string] $Variant,
        [Parameter(Mandatory)][string] $UnitCode
    )
    if ($Brand -eq 'MVC') { return [pscustomobject]@{ Brand = 'MVC'; Swapped = $false } }

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
    # The guide's own border hex, which the assessment role map does not carry.
    $extra = Get-BrandPalettePairs -Palette $pal
    $doc = Get-DocxPart -WorkDir $w -Part 'word/document.xml'
    $n = ([regex]::Matches($doc, 'C7D0DD')).Count
    if ($n -gt 0) {
        $doc = $doc.Replace('C7D0DD', [string]$extra['C7D0DD'])
        Set-DocxPart -WorkDir $w -Part 'word/document.xml' -Content $doc
    }
    $ir = Set-BrandIdentity -WorkDir $w -Branding $b -Variant $Variant

    $logoDir = Join-Path $script:SkillRoot 'assets\logos'
    $assets = @(); if (Test-Path $logoDir) { $assets = @(Get-ChildItem -LiteralPath $logoDir -File | ForEach-Object { $_.FullName }) }
    $oldH = @(); if ($lr.PSObject.Properties.Name -contains 'OldHashes') { $oldH = @($lr.OldHashes) }
    $null = Assert-BrandLogo -WorkDir $w -ExpectedLogoPath $logo -ForbiddenLogoPaths $assets -ForbiddenHashes $oldH

    Compress-Docx -WorkDir $w -Path $Path | Out-Null
    [pscustomobject]@{ Brand = $Brand; Variant = $Variant; Swapped = $true
                       Logo = $lr.Replaced; PaletteRefs = $pr.Total + $n; IdentityRefs = $ir.Total }
}

function Assert-GuideBrand {
    <#  Re-prove the mark on a FINISHED guide - after artwork, at delivery.
        Headers must carry the resolved variant's mark; no media part may be
        any other known mark. Safe on a document full of placed figures.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [ValidateSet('MVC','ACI')][string] $Brand = 'MVC',
        [string] $Variant,
        [Parameter(Mandatory)][string] $UnitCode
    )
    $w = Expand-Docx -Path $Path
    $logoDir = Join-Path $script:SkillRoot 'assets\logos'
    $assets = @(); if (Test-Path $logoDir) { $assets = @(Get-ChildItem -LiteralPath $logoDir -File | ForEach-Object { $_.FullName }) }
    if ($Brand -eq 'MVC') {
        if ($assets.Count -gt 0) { $null = Assert-BrandLogo -WorkDir $w -ForbiddenLogoPaths $assets }
        return [pscustomobject]@{ Ok = $true; Brand = 'MVC' }
    }
    $b = Get-Branding -Brand $Brand
    $Variant = Resolve-BrandVariant -Branding $b -UnitCode $UnitCode -Variant $Variant
    $logo = Join-Path $script:SkillRoot $b.variants.$Variant.logo.path
    $null = Assert-BrandLogo -WorkDir $w -ExpectedLogoPath $logo -ForbiddenLogoPaths $assets
    [pscustomobject]@{ Ok = $true; Brand = $Brand; Variant = $Variant }
}

function Set-DeckBrand {
    <#  Brand a rendered Delivery PowerPoint .pptx in place. No-op for MVC.

        The deck template draws the MVC mark from ppt/media/image1.png on
        nearly every slide, and carries "Adelaide Construction Institute" in
        its docProps (the template's own ancestry - it prints nowhere). This:
        1. verifies the logo part IS the known MVC deck mark (refuses to
           guess), then writes the brand variant's mark over it,
        2. rewrites the drawing extents of every shape that draws it, holding
           width, so the 3.53:1 culinary mark is never stretched to 2.46:1,
        3. remaps the palette by role across every slide, master, layout,
           theme and notes part,
        4. swaps the identity (docProps and every text part, rels included),
        5. gates the result byte-level: the logo part must BE the variant's
           mark, no media part may match any other known mark, and no MVC hex
           or identity token may survive anywhere.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [ValidateSet('MVC','ACI')][string] $Brand = 'MVC',
        [string] $Variant,
        [Parameter(Mandatory)][string] $UnitCode,
        [string] $LogoMediaName = 'image1.png'
    )
    if ($Brand -eq 'MVC') { return [pscustomobject]@{ Brand = 'MVC'; Swapped = $false } }

    $b = Get-Branding -Brand $Brand
    $Variant = Resolve-BrandVariant -Branding $b -UnitCode $UnitCode -Variant $Variant
    $pal = Set-HousePalette -Brand $Brand -Variant $Variant
    $logo = Join-Path $script:SkillRoot $b.variants.$Variant.logo.path
    if (-not (Test-Path $logo)) { throw "Brand logo not found: $logo" }
    $logoPx = Get-PngPixelSize -Path $logo

    $w = Expand-Docx -Path $Path
    $logoPart = Join-Path $w ("ppt\media\" + $LogoMediaName)
    if (-not (Test-Path $logoPart)) { throw "Deck logo part not found: ppt/media/$LogoMediaName" }
    $srcMd5 = Get-FileMd5 -Path $logoPart
    $newMd5 = Get-FileMd5 -Path $logo
    if ($srcMd5 -ne $script:DECK_MVC_LOGO_MD5 -and $srcMd5 -ne $newMd5) {
        throw ("ppt/media/$LogoMediaName is neither the known MVC deck mark nor the target mark " +
               "(md5 $srcMd5). Refusing to overwrite an image I cannot identify.")
    }

    # 1. the mark
    Copy-Item -LiteralPath $logo -Destination $logoPart -Force

    # 2. extents, width held, in every part that draws it
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $partsWithLogo = 0
    $xmlDirs = @('ppt\slides', 'ppt\slideMasters', 'ppt\slideLayouts')
    foreach ($dir in $xmlDirs) {
        $full = Join-Path $w $dir
        if (-not (Test-Path $full)) { continue }
        foreach ($xmlFile in Get-ChildItem -LiteralPath $full -Filter *.xml -File) {
            $rp = Join-Path $full ('_rels\' + $xmlFile.Name + '.rels')
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

    # 3. palette, by role, everywhere colours can live
    $pairs = Get-BrandPalettePairs -Palette $pal
    $recolored = 0
    foreach ($dir in ($xmlDirs + @('ppt\theme', 'ppt\notesSlides', 'ppt\notesMasters'))) {
        $full = Join-Path $w $dir
        if (-not (Test-Path $full)) { continue }
        foreach ($xmlFile in Get-ChildItem -LiteralPath $full -Filter *.xml -File) {
            $xml = [System.IO.File]::ReadAllText($xmlFile.FullName, [System.Text.Encoding]::UTF8)
            $orig = $xml
            foreach ($from in $pairs.Keys) {
                $to = [string]$pairs[$from]
                if ($to -eq $from) { continue }
                $xml = [regex]::Replace($xml, [regex]::Escape($from), $to, 'IgnoreCase')
            }
            if ($xml -ne $orig) {
                [System.IO.File]::WriteAllText($xmlFile.FullName, $xml, $utf8)
                $recolored++
            }
        }
    }

    # 4. identity - docProps and every text-bearing part, rels included
    $idParts = @('docProps/app.xml', 'docProps/core.xml')
    foreach ($dir in ($xmlDirs + @('ppt\notesSlides'))) {
        $full = Join-Path $w $dir
        if (-not (Test-Path $full)) { continue }
        foreach ($xmlFile in Get-ChildItem -LiteralPath $full -Filter *.xml -File) {
            $idParts += ($dir -replace '\\', '/') + '/' + $xmlFile.Name
        }
    }
    $ir = Set-BrandIdentity -WorkDir $w -Branding $b -Variant $Variant -Parts $idParts
    # The deck template's own ancestry: it carries the OTHER trading name in
    # docProps. Swap it to this build's variant explicitly - Set-BrandIdentity
    # maps MVC strings only.
    foreach ($dp in @('docProps/app.xml', 'docProps/core.xml')) {
        $p = Join-Path $w ($dp -replace '/', '\')
        if (-not (Test-Path $p)) { continue }
        $t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
        $trading = [string]$b.variants.$Variant.tradingName
        $o = $t
        foreach ($other in @($b.variants.PSObject.Properties.Name)) {
            if ($other -eq 'default' -or $other -like '_*' -or $other -eq $Variant) { continue }
            $t = $t.Replace([string]$b.variants.$other.tradingName, $trading)
        }
        if ($t -ne $o) { [System.IO.File]::WriteAllText($p, $t, $utf8) }
    }

    # 5. the gate - blocking, byte-level
    $bad = @()
    if ((Get-FileMd5 -Path $logoPart) -ne $newMd5) { $bad += "ppt/media/$LogoMediaName is not the $Variant mark after the swap" }
    $logoDir = Join-Path $script:SkillRoot 'assets\logos'
    $forbidden = @{ $script:DECK_MVC_LOGO_MD5 = 'MVC deck mark' }
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
            if ($forbidden.ContainsKey($h)) { $bad += "ppt/media/$($mf.Name) is the WRONG mark: $($forbidden[$h])" }
        }
    }
    foreach ($dir in ($xmlDirs + @('ppt\theme', 'docProps'))) {
        $full = Join-Path $w $dir
        if (-not (Test-Path $full)) { continue }
        foreach ($xmlFile in Get-ChildItem -LiteralPath $full -Filter *.xml -File) {
            $t = [System.IO.File]::ReadAllText($xmlFile.FullName, [System.Text.Encoding]::UTF8)
            foreach ($tok in @('Meridian Vocational', '234B8C', 'F09C0C', 'mvc.edu.au')) {
                if ($t -match [regex]::Escape($tok)) { $bad += "$dir/$($xmlFile.Name) still carries '$tok'" }
            }
            foreach ($other in @($b.variants.PSObject.Properties.Name)) {
                if ($other -eq 'default' -or $other -like '_*' -or $other -eq $Variant) { continue }
                $otherName = [string]$b.variants.$other.tradingName
                if ($t -match [regex]::Escape($otherName)) { $bad += "$dir/$($xmlFile.Name) names the other trading name '$otherName'" }
            }
        }
    }
    if ($bad.Count -gt 0) {
        throw ("Deck brand gate FAILED - the deck would ship with the wrong brand:`n  - " + (@($bad | Select-Object -Unique) -join "`n  - "))
    }

    Compress-Docx -WorkDir $w -Path $Path | Out-Null
    [pscustomobject]@{ Brand = $Brand; Variant = $Variant; Swapped = $true
                       LogoPartsResized = $partsWithLogo; PartsRecolored = $recolored; IdentityRefs = $ir.Total }
}

Write-Verbose 'Set-ResourceBrand.ps1 loaded.'
