<#
    Build-Pack.ps1

    THE ASSEMBLER. Takes a generated body of OOXML and splices it into an
    approved template, producing a finished document.

    This is the piece that turns block builders into a document. Without it you
    have primitives and rules but nothing that writes a file, and every build
    re-derives the splice from scratch - which is how the splice offsets, the
    cover-sheet prefill and the placeholder pass drift apart between builds.

    WHAT IT DOES, in order:

      1. Unpack a FRESH copy of the pristine template. Always fresh - edits
         compound, and an -Expected count that was right on the template is
         wrong on a document already patched.
      2. Split the template at its own seam into prefix (cover sheet + title
         page) and suffix (the closing section properties).
      3. Drop the generated body between them.
      4. Replace the template's bracketed placeholders with the unit's values.
      5. Pre-fill the cover-sheet fields the template ships blank.
      6. Write document control into docProps AND the cached field results.
      7. Validate the package, then repack.

    Verification is NOT here. Run Test-HouseRules on the work directory before
    repacking, and Invoke-DocumentVerification on the finished file after. See
    references/template-build.md for the delivery gate in order.

    Requires, dot-sourced first: Build-FromTemplate.ps1, Docx-Blocks-House.ps1,
    Test-HouseRules.ps1 (Write-PackDocument gates with it) and Verify-Document.ps1
    (Complete-Pack calls Invoke-DocumentVerification).

    ASCII only in this file.
#>

# No Set-StrictMode - dot-sourced.

function Split-TemplateAtBody {
    <#  Find the seam between the template's front matter and the body it will
        no longer keep.

        The two templates seam differently, and both ways are load-bearing:

        UAT - three sectPr blocks. The cover sheet is section 1, the title page
        section 2, the body section 3. Keep everything up to the close of the
        paragraph holding the SECOND sectPr, and resume at the THIRD. That keeps
        the cover sheet and title page and drops the sample body between them.

        Recipe workbook - one sectPr. Seam on the first body heading instead, and
        resume at the final sectPr so the closing section properties survive.
        Cutting at LastIndexOf('<w:p ') - with the trailing space - matters:
        '<w:p>' without it also matches '<w:pPr', which cuts a paragraph open.

        Returns @{ Prefix; Suffix }. A body goes between them.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $DocumentXml,
        [Parameter(Mandatory)][ValidateSet('uat', 'recipeWorkbook')][string] $Kind,
        [string] $BodyAnchor = 'Instructions to students'
    )

    if ($Kind -eq 'uat') {
        $sec = @(); foreach ($m in [regex]::Matches($DocumentXml, '<w:sectPr')) { $sec += $m.Index }
        if ($sec.Count -lt 3) {
            throw "Expected 3 sectPr blocks in the UAT template, found $($sec.Count). The template has changed shape - re-check the seam before building."
        }
        $close = $DocumentXml.IndexOf('</w:p>', $sec[1])
        return @{
            Prefix = $DocumentXml.Substring(0, $close + 6)
            Suffix = $DocumentXml.Substring($sec[2])
        }
    }

    $anchor = $DocumentXml.IndexOf($BodyAnchor)
    if ($anchor -lt 0) { throw "Body anchor '$BodyAnchor' not found in the template. The seam cannot be located." }
    $pStart = $DocumentXml.LastIndexOf('<w:p ', $anchor)
    if ($pStart -lt 0) { throw "No paragraph start found before the body anchor." }
    return @{
        Prefix = $DocumentXml.Substring(0, $pStart)
        Suffix = $DocumentXml.Substring($DocumentXml.LastIndexOf('<w:sectPr'))
    }
}

function Set-CoverSheetField {
    <#  Fill a cover-sheet value cell the template ships blank.

        Each label sits in its own cell; the value belongs in the NEXT cell
        along, which the template leaves as a bare empty paragraph.

        ONLY fills an EMPTY cell. The recipe template already fills the unit from
        its own [Unit code] [Unit title] placeholder, so writing again printed
        the unit name twice.

        Match the label PRE-ESCAPED - 'Unit Code &amp; Name:', not
        'Unit Code & Name:' - because it is being matched against raw XML.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Xml,
        [Parameter(Mandatory)][string] $Label,
        [Parameter(Mandatory)][string] $Value
    )

    # A MISSING LABEL IS A WARNING, NOT A VERBOSE WHISPER. "A patch that
    # silently matched nothing is the failure mode this catches" - a template
    # revision that splits the label run or renames it would otherwise ship a
    # blank Qualification cell with nothing on screen; Test-CoverSheet at
    # Stage 8 is the backstop, but say so here where the cause is visible.
    $li = $Xml.IndexOf("<w:t>$Label</w:t>")
    if ($li -lt 0) { Write-Warning "Set-CoverSheetField: cover-sheet label not found, cell left blank: $Label"; return $Xml }

    $cellEnd   = $Xml.IndexOf('</w:tc>', $li)
    $nextOpen  = $Xml.IndexOf('<w:tc>', $cellEnd)
    $nextOpenA = $Xml.IndexOf('<w:tc ', $cellEnd)
    if ($nextOpenA -ge 0 -and ($nextOpen -lt 0 -or $nextOpenA -lt $nextOpen)) { $nextOpen = $nextOpenA }
    if ($nextOpen -lt 0) { Write-Warning "Set-CoverSheetField: no value cell follows label, cell left blank: $Label"; return $Xml }

    $nextEnd = $Xml.IndexOf('</w:tc>', $nextOpen)
    $cell    = $Xml.Substring($nextOpen, $nextEnd - $nextOpen)

    $existing = -join ([regex]::Matches($cell, '<w:t[^>]*>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value })
    if ($existing.Trim()) { Write-Verbose "  cover sheet already filled, skipped: $Label"; return $Xml }

    $para    = HPara -Runs (HRun -Text $Value -Size $script:SZ_CELL)
    $newCell = if ($cell -match '<w:p/>') { $cell -replace '<w:p/>', $para } else { $cell + $para }

    Write-Verbose "  cover sheet pre-filled: $Label"
    return $Xml.Substring(0, $nextOpen) + $newCell + $Xml.Substring($nextEnd)
}

function Write-PackDocument {
    <#  Build one finished document.

        -Unit is a hashtable describing the unit, and it is the ONLY place unit
        detail enters the assembler:

            @{
              Code          = 'SITHPAT018'
              Title         = 'Produce chocolate confectionery'
              Qualification = 'SIT40721 Certificate IV in Patisserie'
              Release       = 'Release 1'
              AqfLevel      = 'Certificate IV (AQF Level 4)'
              CoverImagePrompt = 'A close three-quarter view of a chocolatier tempering dark couverture on a marble slab with a palette knife, on a stainless steel commercial kitchen bench under even neutral daylight. Gloved hands, sleeves down, no jewellery. Shallow depth of field. No text, no faces, no logos.'   # optional; recipe workbook only
            }

        -BodyXml is the generated body. Build it with the block builders in
        Docx-Blocks-House.ps1. It should OPEN with a table of contents -
        HTableOfContents - because every document carries one.

        -Assessor prepends the assessor banner and marks the document as the
        assessor version. It does NOT change the learner content: an assessor
        guide mirrors its learner document exactly and adds.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $OutPath,
        [Parameter(Mandatory)][string] $BodyXml,
        [Parameter(Mandatory)][ValidateSet('uat', 'recipeWorkbook')][string] $Kind,
        [Parameter(Mandatory)][hashtable] $Unit,
        [Parameter(Mandatory)][string] $DocName,
        [Parameter(Mandatory)][string] $DocNumber,
        [string] $Revision = '1.0',
        [ValidateSet('MVC', 'ACI')][string] $Brand = 'MVC',
        [string] $Variant,
        [switch] $Assessor,
        [switch] $SkipGate
    )

    $b    = Get-Branding -Brand $Brand
    # THE VARIANT FOLLOWS THE UNIT, ENFORCED HERE PER DOCUMENT. Derived from
    # the unit code's training-package prefix; a contradicting -Variant throws,
    # an unmapped package (BSB) demands an explicit one. This is what stops a
    # construction unit shipping under the culinary mark with every gate green,
    # and a forgotten -Variant on one document of a pack mixing the pack.
    $Variant = Resolve-BrandVariant -Branding $b -UnitCode $Unit.Code -Variant $Variant
    $work = Expand-Docx -Path (Get-TemplatePath -Branding $b -Kind $Kind)

    # ---- brand the template -------------------------------------------------
    # A brand may carry VARIANTS - ACI trades as Adelaide Culinary Institute and
    # as Adelaide Construction Institute, with a different mark and a different
    # palette each. Resolve the variant, point the block builders at its colours,
    # then swap the template's own logo and recolour the front matter it brings
    # with it. Skip any of that and an ACI pack ships MVC-branded: the text sweep
    # would catch the palette eventually, the logo it would never see.
    $pal = Set-HousePalette -Brand $Brand -Variant $Variant
    if ($b.PSObject.Properties.Name -contains 'templates' -and $b.templates) {
        if ($b.templates.PSObject.Properties.Name -contains 'swapLogo' -and $b.templates.swapLogo) {
            $vlogo = $b.variants.($pal.Variant).logo.path
            if ($vlogo) {
                $lp = Join-Path $script:SkillRoot $vlogo
                $lr = Set-BrandLogo -WorkDir $work -LogoPath $lp
                Write-Verbose "  logo: $($lr.Replaced) <- $($lr.From), ratio $($lr.Ratio), resized=$($lr.Resized)"
            }
        }
        if ($b.templates.PSObject.Properties.Name -contains 'swapPalette' -and $b.templates.swapPalette) {
            $pr = Set-BrandPalette -WorkDir $work -Palette $pal
            Write-Verbose "  palette: $($pr.Total) colour reference(s) remapped"
            # The identity moves with the palette. A recoloured document still
            # naming Meridian Vocational College is worse than one that did not
            # try, because it looks branded and is not.
            $ir = Set-BrandIdentity -WorkDir $work -Branding $b -Variant $pal.Variant
            Write-Verbose "  identity: $($ir.Total) reference(s) -> $($ir.TradingName)"
        }
    }

    # THE BRAND LOGO GATE - BLOCKING, EVERY BUILD, EVERY BRAND. The crossover
    # text sweep cannot see an image, and on 29 August 2026 every knowledge
    # document of a delivered ACI pack carried the MVC mark in its header with
    # every gate green. Byte-level, a handful of small files - milliseconds.
    # For a brand that swaps its logo: every header/footer image must BE the
    # resolved variant's mark, and no media part may match ANY other logo in
    # assets/logos (which also catches culinary/construction cross-variant
    # mix-ups) or the bytes the swap just replaced. For a brand that keeps its
    # template's own mark (MVC): no media part may match any assets/logos mark.
    $logoAssetDir = Join-Path $script:SkillRoot 'assets\logos'
    $allLogoAssets = @()
    if (Test-Path $logoAssetDir) { $allLogoAssets = @(Get-ChildItem -LiteralPath $logoAssetDir -File | ForEach-Object { $_.FullName }) }
    $didSwapLogo = ($b.PSObject.Properties.Name -contains 'templates' -and $b.templates -and
                    $b.templates.PSObject.Properties.Name -contains 'swapLogo' -and $b.templates.swapLogo)
    if ($didSwapLogo) {
        $expLogo = Join-Path $script:SkillRoot $b.variants.($pal.Variant).logo.path
        $oldH = @(); if ($lr -and ($lr.PSObject.Properties.Name -contains 'OldHashes')) { $oldH = @($lr.OldHashes) }
        $ag = Assert-BrandLogo -WorkDir $work -ExpectedLogoPath $expLogo -ForbiddenLogoPaths $allLogoAssets -ForbiddenHashes $oldH
        Write-Verbose "  logo gate: headers carry $($ag.Expected); $($ag.ForbiddenChecked) forbidden mark(s) absent"
    } elseif ($allLogoAssets.Count -gt 0) {
        $null = Assert-BrandLogo -WorkDir $work -ForbiddenLogoPaths $allLogoAssets
    }
    $part = 'word/document.xml'
    $doc  = Get-DocxPart -WorkDir $work -Part $part

    # 1-3. seam, then splice
    $seam = Split-TemplateAtBody -DocumentXml $doc -Kind $Kind

    # The Administration / receipting row is an internal field and does not
    # belong on a learner cover sheet.
    $prefix = Remove-RowContaining -Xml $seam.Prefix -Text 'Administration'

    if ($Assessor) { $BodyXml = (HAssessorBanner) + $BodyXml }
    Set-DocxPart -WorkDir $work -Part $part -Content ($prefix + $BodyXml + $seam.Suffix)

    # 4. placeholders. -Expected on every one: a replace that silently matched
    #    nothing is the failure this catches.
    $repl = [ordered]@{
        '[Unit code]'                    = $Unit.Code
        '[Unit title]'                   = $Unit.Title
        '[Qualification code and title]' = $Unit.Qualification
        '[Release / version]'            = $Unit.Release
        '[AQF level]'                    = $Unit.AqfLevel
        'Release [n]'                    = $Unit.Release
    }
    # The cover photo space becomes a PROMPT, not a caption. A caption leaves an
    # empty dashed box with a label under it, which is what shipped before and
    # is not artwork - recipe-workbook.md section 12.1. The artwork pass reads
    # this block, generates from it, and deletes it.
    #
    # ONE PARAGRAPH, so the Caption / Alt / Aspect fields go inline rather than
    # on their own lines: this is a run-level text replacement and cannot add
    # paragraphs. Find-DocxImagePrompts.ps1 lifts inline fields out and strips
    # the closing bracket off the last value, so ASPECT may sit last.
    if ($Unit.ContainsKey('CoverImagePrompt') -and $Unit.CoverImagePrompt) {
        $altTxt = $Unit.CoverImagePrompt
        if ($Unit.ContainsKey('CoverImageAlt') -and $Unit.CoverImageAlt) { $altTxt = $Unit.CoverImageAlt }

        # NO CAPTION FIELD. The cover photograph is DECORATIVE - it is not
        # referred to anywhere, nothing is assessed from it, and a title page is
        # not a figure list. Giving it one printed "Figure 1: ..." under the
        # picture on the front of the workbook. Alt text still goes in, because
        # a reader who cannot see the image still needs to know what is there;
        # that is accessibility, not a caption. Recipe card photographs are the
        # opposite case and DO carry captions - they are instructional.
        $repl['[ Insert photograph here ]'] =
            "[IMAGE: $($Unit.CoverImagePrompt) ALT: $altTxt ASPECT: landscape]"

        # THE TEMPLATE'S PHOTO SPACE IS PLACEHOLDER CHROME, AND ALL OF IT GOES.
        # It draws a DASHED BLUE BOX on a tinted fill and prints an INSTRUCTION
        # under it - "Insert a themed product photograph for the cover". Both say
        # "put a picture here". Once a real picture is in, the box is a border
        # around a photograph and the instruction is a note to the builder
        # printed on the front page of a learner document. Strip both.
        #
        # Read ONCE and write ONCE. Re-reading the part between the two edits
        # silently discarded the first one, because it had not been saved yet.
        $xCov = Get-DocxPart -WorkDir $work -Part $part
        $ipos = $xCov.IndexOf('[ Insert photograph here ]')
        if ($ipos -gt 0) {
            $tcStart = $xCov.LastIndexOf('<w:tc>', $ipos)
            if ($tcStart -ge 0) {
                $prEnd = $xCov.IndexOf('</w:tcPr>', $tcStart)
                if ($prEnd -gt $tcStart -and $prEnd -lt $ipos) {
                    $pr  = $xCov.Substring($tcStart, $prEnd - $tcStart)
                    $pr2 = [regex]::Replace($pr, '<w:tcBorders>.*?</w:tcBorders>', '', 'Singleline')
                    $pr2 = [regex]::Replace($pr2, '<w:shd\b[^>]*/>', '')
                    if ($pr2 -ne $pr) {
                        $xCov = $xCov.Remove($tcStart, $pr.Length).Insert($tcStart, $pr2)
                        Write-Verbose '  cover photo: placeholder box borders and fill removed'
                    }
                }
            }
        }
        # Delete the WHOLE paragraph, not just the words, or an empty line and
        # its spacing are left sitting under the picture.
        foreach ($guide in @('Insert a themed product photograph for the cover',
                             'Insert a themed product photograph',
                             'Insert cover photograph here')) {
            $g = ConvertTo-XmlText $guide
            while ($true) {
                $gi = $xCov.IndexOf($g)
                if ($gi -lt 0) { break }
                $pStart = $xCov.LastIndexOf('<w:p ', $gi)
                $p2     = $xCov.LastIndexOf('<w:p>', $gi)
                if ($p2 -gt $pStart) { $pStart = $p2 }
                $pEnd = $xCov.IndexOf('</w:p>', $gi)
                if ($pStart -lt 0 -or $pEnd -lt 0) { break }
                $xCov = $xCov.Remove($pStart, ($pEnd + 6) - $pStart)
                Write-Verbose "  cover photo: removed the template guidance line '$guide'"
            }
        }
        Set-DocxPart -WorkDir $work -Part $part -Content $xCov
    }
    elseif ($Unit.ContainsKey('PhotoCaption') -and $Unit.PhotoCaption) {
        # Retired 27 August 2026. Fail loudly rather than silently shipping an
        # empty photo box, which is what honouring this would now do.
        throw "PhotoCaption is retired. The cover photo space takes an image PROMPT, not a caption - pass CoverImagePrompt, and optionally CoverImageCaption and CoverImageAlt. See references/recipe-workbook.md section 12."
    }
    # ONE pass for every placeholder, then ONE residual sweep - the per-key
    # Test-then-Replace pair cost twelve full passes over the part. The sweep
    # keeps the old guarantee: a placeholder Word split across runs, or one
    # sitting outside a <w:t>, is still a loud failure rather than a silent
    # skip that surfaces at audit.
    $replActive = [ordered]@{}
    foreach ($k in $repl.Keys) { if ($repl[$k]) { $replActive[$k] = [string]$repl[$k] } }
    if ($replActive.Count -gt 0) {
        Invoke-DocxTextReplaceMany -WorkDir $work -Part $part -Map $replActive | Out-Null
        $after = Get-DocxPart -WorkDir $work -Part $part
        foreach ($k in $replActive.Keys) {
            if ($after.Contains((ConvertTo-XmlText $k))) {
                throw "Placeholder '$k' is still present after replacement. Word split it across runs, or it sits outside a <w:t> - the template may have changed."
            }
        }
    }

    # 5. cover-sheet fields the template ships blank
    $x = Get-DocxPart -WorkDir $work -Part $part
    $x = Set-CoverSheetField -Xml $x -Label 'Qualification:'        -Value $Unit.Qualification
    $x = Set-CoverSheetField -Xml $x -Label 'Unit Code &amp; Name:' -Value "$($Unit.Code) $($Unit.Title)"
    Set-DocxPart -WorkDir $work -Part $part -Content $x

    # 6. document control - docProps AND the cached field results
    Set-DocControl -WorkDir $work -Branding $b -DocNumber $DocNumber -DocName $DocName -Revision $Revision

    # 7. gate, then validate, then repack
    if (-not $SkipGate) {
        $prof = Get-HouseProfile -Brand $Brand
        $gate = Test-HouseRules -WorkDir $work -Profile $prof -Learner:(-not $Assessor)
        if (-not $gate.Ok) {
            $detail = ($gate.Failures | ForEach-Object { "  [$($_.Check)] $($_.Detail)" }) -join "`n"
            throw "House-rules gate FAILED for $DocName - not written:`n$detail"
        }
        foreach ($w in $gate.Warnings) { Write-Host "  WARN [$($w.Check)] $($w.Detail)" }
    }

    Assert-DocxPackage -WorkDir $work | Out-Null
    Compress-Docx -WorkDir $work -Path $OutPath | Out-Null
    Write-Host "  wrote $OutPath"
    return $OutPath
}

function Complete-Pack {
    <#  Finish every document in a pack: update fields, export PDF, run the
        rendered checks.

        Do this for the whole pack in ONE pass at the end, not per document -
        Word COM is fragile, and a session per file multiplies the chance of an
        RPC failure that looks like corruption and is not.

        ONE WORD SESSION FOR THE WHOLE PACK. -KeepWordOpen makes each
        verification close only its document; Open-Document then reuses the
        live instance, so a four-document pack pays one WINWORD start and one
        quit instead of four of each - and the quit-then-relaunch RPC race
        between documents disappears with the relaunches. The finally quits
        exactly once, including on error, so no orphaned WINWORD is left
        holding a lock on the output files.

        This is what populates the table of contents. A document delivered
        without it shows the TOC's placeholder text instead of a contents list.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]] $Paths,
        [ValidateSet('MVC', 'ACI')][string] $Brand = 'MVC',
        [string] $Variant,
        [string[]] $AssessorPaths = @()
    )

    $b       = Get-Branding -Brand $Brand
    $results = @()

    try {
        foreach ($p in $Paths) {
            $isAssessor = ($AssessorPaths -contains $p) -or ((Split-Path $p -Leaf) -like 'Assessor_Guide_*')
            $r = Invoke-DocumentVerification -Path $p -Branding $b -AssessorVersion:$isAssessor -KeepWordOpen
            $results += $r
        }
    }
    finally { Close-Word }

    $bad = @($results | Where-Object { -not $_.Ok })
    Write-Host ("`nPack: {0} document(s), {1} clean, {2} with findings." -f $results.Count, ($results.Count - $bad.Count), $bad.Count)
    return $results
}

Write-Verbose 'Build-Pack.ps1 loaded.'
