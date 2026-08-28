<#
    Test-HouseRules.ps1

    The blocking verification gate. Each check FAILS the build and names the
    offending location.

    WHY THESE EXIST. A rule that is only prose gets ignored under pressure. And
    the existing package validation in Build-FromTemplate.ps1 covers
    well-formedness, namespaces, content types, relationships, numId uniqueness
    and control characters - but NOT schema child order, which is the one thing
    that actually corrupts a document. A pageBreakBefore-before-keepNext package
    passes every current gate and fails only when a human opens it in Word.

    Runs on the UNPACKED package, before repacking. No Word required.

        . scripts\Build-FromTemplate.ps1
        . scripts\Test-HouseRules.ps1
        $r = Test-HouseRules -WorkDir $work -Profile (Get-HouseProfile) -Learner
        if (-not $r.Ok) { $r.Failures | Format-Table }

    ASCII only in this file.
#>

# No Set-StrictMode - dot-sourced.

$script:HouseProfileCache = @{}

function Get-HouseProfile {
    <# Load the measured house profile. Explicit UTF-8: PowerShell 5.1 reads a
       BOM-less UTF-8 file as ANSI and mangles every degree symbol in it.

       CACHED, keyed on the file's write time. HRenderProse reads the profile
       once per prose block, so an uncached load re-parsed a 24 KB JSON
       hundreds of times per document. The mtime key means a Stage 0 that
       rewrites the profile mid-session invalidates the cache by itself. #>
    [CmdletBinding()]
    param([ValidateSet('MVC', 'ACI')][string] $Brand = 'MVC')
    $root = Split-Path -Parent $PSScriptRoot
    $path = Join-Path $root "assets\house-profile.$($Brand.ToLower()).json"
    if (-not (Test-Path $path)) { throw "House profile not found: $path. Stage 0 has not been done for this RTO - measure their artefacts first." }
    $stamp = (Get-Item -LiteralPath $path).LastWriteTimeUtc.Ticks
    $hit   = $script:HouseProfileCache[$Brand]
    if ($hit -and $hit.Stamp -eq $stamp) { return $hit.Value }
    $v = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    $script:HouseProfileCache[$Brand] = @{ Stamp = $stamp; Value = $v }
    return $v
}

# --------------------------------------------------------------------------
# CT_PPr and CT_TcPr child order. Out of order, Word rejects the file.
# --------------------------------------------------------------------------

$script:PPR_ORDER = @(
    'pStyle','keepNext','keepLines','pageBreakBefore','framePr','widowControl','numPr',
    'suppressLineNumbers','pBdr','shd','tabs','suppressAutoHyphens','kinsoku','wordWrap',
    'overflowPunct','topLinePunct','autoSpaceDE','autoSpaceDN','bidi','adjustRightInd',
    'snapToGrid','spacing','ind','contextualSpacing','mirrorIndents','suppressOverlap',
    'jc','textDirection','textAlignment','textboxTightWrap','outlineLvl','divId',
    'cnfStyle','rPr','sectPr','pPrChange'
)

$script:TCPR_ORDER = @(
    'cnfStyle','tcW','gridSpan','hMerge','vMerge','tcBorders','shd','noWrap','tcMar',
    'textDirection','tcFitText','vAlign','hideMark','headers','cellIns','cellDel',
    'cellMerge','tcPrChange'
)

function Test-ChildOrder {
    <# Generic child-order check over every occurrence of a wrapper element. #>
    param(
        [Parameter(Mandatory)][string] $Xml,
        [Parameter(Mandatory)][string] $Wrapper,   # 'pPr' | 'tcPr'
        [Parameter(Mandatory)][string[]] $Order
    )
    $bad = New-Object System.Collections.Generic.List[object]
    $rx  = "<w:$Wrapper>(.*?)</w:$Wrapper>"
    $idx = 0
    foreach ($m in [regex]::Matches($Xml, $rx, 'Singleline')) {
        $idx++
        # DIRECT CHILDREN ONLY. A nested container's own children are legal in
        # any order relative to this list - w:shd and w:spacing are also rPr
        # children, w:bidi and w:textDirection also sectPr children - and
        # scanning descendants flagged a schema-valid paragraph as out of
        # order. Collapse each container to a self-closing marker so the
        # container itself keeps its place in the order check while its
        # children drop out of it.
        $scan = [regex]::Replace($m.Groups[1].Value,
            '<w:(rPr|sectPr|numPr|pBdr|tabs|tcBorders|tcMar)(?:\s[^>]*)?>.*?</w:\1>',
            '<w:$1/>', 'Singleline')
        $seen = [regex]::Matches($scan, '<w:([a-zA-Z]+)[ />]') |
                ForEach-Object { $_.Groups[1].Value }
        $last = -1; $lastName = ''
        foreach ($name in $seen) {
            $pos = [array]::IndexOf($Order, $name)
            if ($pos -lt 0) { continue }        # unknown child - not ours to police
            if ($pos -lt $last) {
                $bad.Add([pscustomobject]@{
                    Wrapper  = $Wrapper
                    Instance = $idx
                    Problem  = "<w:$name> follows <w:$lastName> but must precede it"
                    Offset   = $m.Index
                })
                break
            }
            $last = $pos; $lastName = $name
        }
    }
    return $bad.ToArray()
}

# --------------------------------------------------------------------------
# The gate
# --------------------------------------------------------------------------

function Test-HouseRules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $WorkDir,
        [Parameter(Mandatory)] $Profile,
        [switch] $Learner,                       # a learner document: no model-answer colour permitted
        [string[]] $ExpectedBreakTargets,        # optional: PageBreakTargets check
        [string] $Part = 'word/document.xml'
    )

    $xml      = Get-DocxPart -WorkDir $WorkDir -Part $Part
    $failures = New-Object System.Collections.Generic.List[object]
    $warnings = New-Object System.Collections.Generic.List[object]
    $passes   = New-Object System.Collections.Generic.List[string]

    # The GENERATED BODY only, for the checks that police our own output.
    #
    # The template's cover sheet legitimately breaks two of the body rules: it
    # runs w:line="216" (the compressed 8.5 pt leading that holds it to one page)
    # and it uses cantSplit on its field and signature rows. That is approved
    # front matter we do not author and must not "correct". Scoping these two
    # checks to the body is what stops the gate failing a correct document -
    # which is the failure mode that teaches people to ignore a gate.
    # Anchors mark the END of the template front matter and are tried in order,
    # so the first that matches wins. Use LastIndexOf: an anchor that also occurs
    # earlier must resolve to its final occurrence, or part of the front matter
    # is policed as though the build wrote it.
    # Advance to the END of the paragraph the anchor sits in. The anchor text is
    # the last line of the title-page RTO block, so cutting at the character
    # position leaves that paragraph's own trailing runs on the body side - and
    # they are 9 pt front matter, which then reads as a body-floor breach that no
    # amount of searching the builder will explain.
    $bodyXml  = $xml
    $frontXml = ''
    foreach ($anchor in @($Profile.formatting.bodyStartsAfter)) {
        if (-not $anchor) { continue }
        $ai = $xml.LastIndexOf("<w:t>$anchor</w:t>")
        if ($ai -lt 0) { $ai = $xml.LastIndexOf([string]$anchor) }
        if ($ai -le 0) { continue }
        $pEnd = $xml.IndexOf('</w:p>', $ai)
        if ($pEnd -ge 0) { $ai = $pEnd + 6 }
        $bodyXml  = $xml.Substring($ai)
        $frontXml = $xml.Substring(0, $ai)
        break
    }

    # FAIL LOUD, NOT OPEN. If no anchor resolved, $bodyXml is still the WHOLE
    # document, so FontFloor, LineSpacing and NoCantSplit go on to police the
    # RTO's approved cover sheet and fail a correct document - or, on a brand
    # whose identity swap rewrote the anchor, pass one that was never checked.
    # Test-Readability already throws here; this silently carried on, which is
    # why the manual invocation path in template-build.md was wrong for months.
    if (-not $frontXml) {
        throw "Test-HouseRules: no body anchor resolved for this document. Refusing to gate - the generated body cannot be told from the approved front matter. Check formatting.bodyStartsAfter in the house profile, and pass -Profile for the RIGHT brand: an identity swap rewrites the anchor."
    }

    function Fail($check, $detail) { $failures.Add([pscustomobject]@{ Check = $check; Detail = $detail }) }
    # A warning does NOT block. It is for a defect present in the RTO's own
    # source that the standing rule says to reproduce rather than silently
    # correct - flag it and let the RTO decide.
    function Warn($check, $detail) { $warnings.Add([pscustomobject]@{ Check = $check; Detail = $detail }) }
    function Pass($check)          { $passes.Add($check) }

    # ---- 1. PPrChildOrder -------------------------------------------------
    $bad = @(Test-ChildOrder -Xml $xml -Wrapper 'pPr' -Order $script:PPR_ORDER)
    if ($bad.Count) { foreach ($b in $bad | Select-Object -First 8) { Fail 'PPrChildOrder' "pPr #$($b.Instance) at offset $($b.Offset): $($b.Problem)" } }
    else { Pass 'PPrChildOrder' }

    # ---- 2. TcPrChildOrder ------------------------------------------------
    $bad = @(Test-ChildOrder -Xml $xml -Wrapper 'tcPr' -Order $script:TCPR_ORDER)
    if ($bad.Count) { foreach ($b in $bad | Select-Object -First 8) { Fail 'TcPrChildOrder' "tcPr #$($b.Instance) at offset $($b.Offset): $($b.Problem)" } }
    else { Pass 'TcPrChildOrder' }

    # ---- 3. EmptyTableCell ------------------------------------------------
    # Every w:tc must contain at least one block-level element. This includes
    # vMerge continuation cells, which are easy to emit empty.
    $n = 0
    foreach ($m in [regex]::Matches($xml, '<w:tc(?:\s[^>]*)?>(.*?)</w:tc>', 'Singleline')) {
        $inner = $m.Groups[1].Value
        if ($inner -notmatch '<w:p[ />]' -and $inner -notmatch '<w:tbl[ >]') { $n++ }
    }
    if ($n -gt 0) { Fail 'EmptyTableCell' "$n cell(s) contain no block-level child. Fall back to <w:p/>." } else { Pass 'EmptyTableCell' }

    # ---- 4. ColourBand ----------------------------------------------------
    # The band is a four-cell TABLE, not an image. Detect by its cell fills.
    # One lazy pass over the tcPr blocks - the old per-colour tempered-dot scan
    # walked the whole part three times with a per-character lookahead. Same
    # verdicts: a fill counts only inside a tcPr, and tcPr cannot nest.
    $bandFills = @{}
    foreach ($m in [regex]::Matches($xml, '<w:tcPr>.*?</w:tcPr>', 'Singleline')) {
        $blk = $m.Value
        foreach ($c in @('F09C0C', 'F5C800', 'E45418')) {
            if (-not $bandFills.ContainsKey($c) -and $blk.Contains("w:fill=`"$c`"")) { $bandFills[$c] = $true }
        }
    }
    $bandCells = $bandFills.Count
    if ($bandCells -ge 3) { Fail 'ColourBand' 'The four-cell title-page colour band is present. Withdrawn by the RTO on 21 August 2026 - it appears on no document.' }
    else { Pass 'ColourBand' }

    # ---- 5. DayCounts -----------------------------------------------------
    # SCOPED TO THE COVER SHEET, which is what this check has always claimed to
    # police. It read the WHOLE document until 27 August 2026, so any authored
    # sentence using "within N days" failed it - a recipe card saying "use
    # within 3 days" is food shelf life and has nothing to do with the
    # submission policy. A gate that fails correct content teaches people to
    # ignore it. $frontXml is guaranteed non-empty here - the no-anchor case
    # threw above - so this always scopes to the cover sheet.
    $dayScope = $frontXml
    $txt  = [regex]::Replace($dayScope, '<[^>]+>', '')
    $late = [int]$Profile.fixedPositions.lateSubmissionDays
    $res  = [int]$Profile.fixedPositions.resultsWithinDays
    $dayBad = @()
    foreach ($m in [regex]::Matches($txt, 'within (\d+) days')) {
        $v = [int]$m.Groups[1].Value
        if ($v -ne $late -and $v -ne $res) { $dayBad += $v }
    }
    if ($dayBad.Count) { Fail 'DayCounts' "Cover sheet carries day count(s) $($dayBad -join ', '); profile says $late (late) / $res (results)." }
    else { Pass 'DayCounts' }

    # ---- 6. LineSpacing ---------------------------------------------------
    $okLines = @([int]$Profile.formatting.lineSpacing.single, [int]$Profile.formatting.lineSpacing.oneAndAHalf)
    $badLines = @{}
    foreach ($m in [regex]::Matches($bodyXml, '<w:spacing[^>]*w:line="(\d+)"')) {
        $v = [int]$m.Groups[1].Value
        if ($okLines -notcontains $v) { if (-not $badLines.ContainsKey($v)) { $badLines[$v] = 0 }; $badLines[$v]++ }
    }
    if ($badLines.Count) {
        $d = ($badLines.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name) x$($_.Value)" }) -join ', '
        Fail 'LineSpacing' "w:line values outside $($okLines -join '/'): $d. 276 is the usual culprit."
    } else { Pass 'LineSpacing' }

    # ---- 7. TableWidth ----------------------------------------------------
    $want = [int]$Profile.formatting.tableWidthDxa
    $badW = @{}
    foreach ($m in [regex]::Matches($bodyXml, '<w:tblW\s+w:w="(\d+)"\s+w:type="dxa"')) {
        $v = [int]$m.Groups[1].Value
        if ($v -ne $want) { if (-not $badW.ContainsKey($v)) { $badW[$v] = 0 }; $badW[$v]++ }
    }
    if ($badW.Count) {
        $d = ($badW.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name) x$($_.Value)" }) -join ', '
        Fail 'TableWidth' "Generated-body table width(s) other than $want dxa: $d."
    } else { Pass 'TableWidth' }

    # ---- 8. Column widths sum to the table width --------------------------
    $gridBad = 0
    foreach ($m in [regex]::Matches($bodyXml, '<w:tblGrid>(.*?)</w:tblGrid>', 'Singleline')) {
        $sum = 0
        foreach ($g in [regex]::Matches($m.Groups[1].Value, '<w:gridCol w:w="(\d+)"')) { $sum += [int]$g.Groups[1].Value }
        if ($sum -ne $want -and $sum -gt 0) { $gridBad++ }
    }
    if ($gridBad -gt 0) { Fail 'ColumnWidthSum' "$gridBad table(s) whose gridCol widths do not sum to $want. Give the LAST column the remainder rather than flooring every column." }
    else { Pass 'ColumnWidthSum' }

    # ---- 8a. TableOverflowsTextColumn - WARNING, not a failure -------------
    #
    # The house table width and the page's own text column are two different
    # numbers, and on this RTO's documents they disagree: tables are 9638 dxa in
    # a 9026 dxa text column, so every table bleeds 612 twips (about 1.08 cm)
    # past the right margin.
    #
    # This is NOT introduced by the build. The RTO's own approved artefact has 57
    # tables at 9638 in a 9026 column. The standing rule is to match the
    # artefact, so this is reported and NOT corrected - "preserve verbatim
    # defects in the RTO's source rather than silently inventing a correction;
    # flag them and let the RTO decide."
    #
    # Two ways out, both the RTO's call: widen the margins to 1134 each side so
    # the text column becomes 9638 and matches the tables, or narrow the tables
    # to 9026. Widening the margins preserves the look of every existing table.
    $pgW = 0; $mL = 0; $mR = 0
    if ($xml -match '<w:pgSz w:w="(\d+)"')                                        { $pgW = [int]$Matches[1] }
    if ($xml -match '<w:pgMar w:top="\d+" w:right="(\d+)" w:bottom="\d+" w:left="(\d+)"') { $mR = [int]$Matches[1]; $mL = [int]$Matches[2] }
    if ($pgW -gt 0) {
        $textCol = $pgW - $mL - $mR
        if ($want -gt $textCol) {
            $over = $want - $textCol
            $fix  = [int](($pgW - $want) / 2)
            Warn 'TableOverflowsTextColumn' ("Tables are $want dxa in a $textCol dxa text column - every table overflows the right margin by $over twips (~$([math]::Round($over/566.9,2)) cm). Present in the RTO's own artefact; reproduced deliberately, not introduced. RTO decision needed: set margins to $fix each side, or narrow tables to $textCol.")
        }
        else { Pass 'TableFitsTextColumn' }
    }

    # ---- 9. ModelAnswerColour / ModelAnswerInLearnerDoc -------------------
    $modelHex  = [string]$Profile.formatting.modelAnswerColor
    # \s*/> NOT /> . A document that has been through an XmlDocument round-trip -
    # which the artwork sub-skill does when it places pictures - writes every
    # self-closing tag as "<w:color w:val=""E43C30"" />" WITH A SPACE. Matching
    # the tight form made this check false-FAIL a correct assessor guide, and,
    # far worse, made ModelAnswerInLearnerDoc false-PASS: model answers leaking
    # into a learner document would go undetected once artwork had been placed.
    $modelRuns = ([regex]::Matches($xml, "<w:color w:val=`"$modelHex`"\s*/>")).Count
    if ($Learner) {
        if ($modelRuns -gt 0) { Fail 'ModelAnswerInLearnerDoc' "$modelRuns run(s) coloured $modelHex in a LEARNER document. Sweep for the colour, not just for the words 'model answer'." }
        else { Pass 'ModelAnswerInLearnerDoc' }
    }
    else {
        if ($modelRuns -eq 0) { Fail 'ModelAnswerColour' "No run coloured $modelHex in an ASSESSOR document. Model answers must print in the model colour everywhere they appear." }
        else { Pass 'ModelAnswerColour' }
    }

    # ---- 9b. AssessorUnansweredBox ---------------------------------------
    # An assessor document must not still be showing the LEARNER's placeholder.
    # Placeholder runs are italic in the profile's placeholder colour, so any
    # placeholder-coloured run carrying real words in an assessor document is a
    # box nobody filled in. Blank placeholders are exempt: a record table uses a
    # single space to hold a writing cell open, and those are meant to be empty.
    #
    # This exists because 16 of the 26 Parts in a knowledge assessor guide
    # shipped reading "Write your answer here." The model answer had been given
    # to Part 1 only. Nothing caught it - the tables were not empty, the gate
    # passed, and it took a reader to notice.
    if (-not $Learner) {
        $placeHex = [string]$Profile.formatting.placeholderColor
        if (-not $placeHex) { $placeHex = '999999' }
        # A FIELD'S CACHED RESULT IS NOT AN UNANSWERED BOX. The table of
        # contents ships with placeholder text between its 'separate' and 'end'
        # field characters - that is what a reader sees until Update-Fields
        # runs, and it is placeholder-coloured by design. Strip every field
        # result before scanning, or this check fails every document that has a
        # contents list.
        $scan = [regex]::Replace($bodyXml,
            '<w:fldChar[^>]*w:fldCharType="separate"[^>]*/>.*?<w:fldChar[^>]*w:fldCharType="end"[^>]*/>',
            '', 'Singleline')

        $unanswered = @{}
        $rx = "<w:r>\s*<w:rPr>(?:(?!</w:rPr>).)*?<w:color w:val=`"$placeHex`"\s*/>(?:(?!</w:rPr>).)*?</w:rPr>\s*<w:t[^>]*>([^<]*)</w:t>"
        # 'Singleline', like check 10 below. An XmlDocument round-trip (the
        # artwork step) indents the XML, and without Singleline the tempered
        # dots cannot cross the newlines - the check silently PASSES a guide
        # full of unanswered boxes, the exact failure it exists to stop.
        foreach ($m in [regex]::Matches($scan, $rx, 'Singleline')) {
            $t = $m.Groups[1].Value.Trim()
            if (-not $t) { continue }
            if (-not $unanswered.ContainsKey($t)) { $unanswered[$t] = 0 }
            $unanswered[$t]++
        }
        if ($unanswered.Count) {
            $d = ($unanswered.GetEnumerator() | Sort-Object { -$_.Value } | Select-Object -First 3 |
                  ForEach-Object { "'$($_.Name)' x$($_.Value)" }) -join ', '
            Fail 'AssessorUnansweredBox' "Assessor document still shows the learner placeholder: $d. Every response space in an assessor guide carries its model answer - compliance-rules.md section 7."
        } else { Pass 'AssessorUnansweredBox' }
    }

    # ---- 10. ProseModelAnswer --------------------------------------------
    # Model answers are points, not prose. Measure the runs that carry the colour.
    if (-not $Learner) {
        $maxWords = [int]$Profile.assessorLayer.modelAnswers.maxWords
        $long = 0; $worst = ''
        $rx = "<w:r>\s*<w:rPr>(?:(?!</w:rPr>).)*?<w:color w:val=`"$modelHex`"\s*/>(?:(?!</w:rPr>).)*?</w:rPr>\s*<w:t[^>]*>([^<]*)</w:t>"
        foreach ($m in [regex]::Matches($xml, $rx, 'Singleline')) {
            $t  = $m.Groups[1].Value.Trim()
            if ($t.Length -le 1) { continue }                       # the bullet glyph run
            $wc = @($t -split '\s+' | Where-Object { $_ }).Count
            if ($wc -gt $maxWords) { $long++; if ($t.Length -gt $worst.Length) { $worst = $t } }
        }
        if ($long -gt 0) { Fail 'ProseModelAnswer' "$long model-answer line(s) exceed $maxWords words. Longest: '$($worst.Substring(0,[Math]::Min(90,$worst.Length)))...'" }
        else { Pass 'ProseModelAnswer' }
    }

    # ---- 11. SectionBannerAlone ------------------------------------------
    # A banner immediately followed by an unconditional page break leaves the
    # heading alone on its page. The first child must run on under it.
    #
    # The paragraph and run BOTH take attributes - a bare <w:p><w:r> matched
    # nothing, because neither approved template contains a bare <w:p> and Word
    # rewrites every generated paragraph with w14:paraId on save. This check was
    # inert in every build until 26 August 2026.
    $alone = 0
    $bannerBreak = '</w:tbl>\s*<w:p(?:\s[^>]*)?>(?:<w:pPr>(?:(?!</w:pPr>).)*?</w:pPr>)?\s*<w:r(?:\s[^>]*)?>(?:<w:rPr>(?:(?!</w:rPr>).)*?</w:rPr>)?\s*<w:br w:type="page"/>'
    foreach ($m in [regex]::Matches($xml, $bannerBreak, 'Singleline')) { $alone++ }
    if ($alone -gt 0) { Fail 'SectionBannerAlone' "$alone banner(s) immediately followed by an explicit page break. The first child of a section runs on under its heading." }
    else { Pass 'SectionBannerAlone' }

    # ---- 12. TableOfContentsPresent ---------------------------------------
    #
    # UNCONDITIONAL. Every document carries a table of contents. There is no
    # profile switch for this and no document type is exempt - a switch is just
    # a way for a document to ship without one.
    #
    # Two ways to fail, because there are two ways to end up with no contents
    # list. The second is the dangerous one: a TOC field with nothing to index
    # renders as a heading over blank space, and nobody notices until a learner
    # opens it. The field only picks up paragraphs carrying an outline level, and
    # the house banners are table cells with no heading style.
    if ($xml -notmatch 'TOC\s+\\o' -and $xml -notmatch '<w:docPartGallery w:val="Table of Contents"') {
        Fail 'TableOfContentsPresent' 'No table of contents. Every document carries one, after the title page - build it with HTableOfContents.'
    }
    elseif (([regex]::Matches($bodyXml, '<w:outlineLvl\s+w:val="\d+"\s*/>')).Count -eq 0) {
        Fail 'TableOfContentsPresent' 'A TOC field is present but nothing carries an outline level, so it renders EMPTY. Build banners with HBanner -OutlineLevel.'
    }
    else { Pass 'TableOfContentsPresent' }

    # ---- 13. NoCantSplit / OutlineLevelDepth ------------------------------
    if ($Profile.formatting.cantSplit -eq $false) {
        $n = ([regex]::Matches($bodyXml, '<w:cantSplit\s*/>')).Count
        if ($n -gt 0) { Fail 'NoCantSplit' "$n cantSplit element(s) in the generated body. The house documents use none (the template cover sheet is exempt)." } else { Pass 'NoCantSplit' }
    }
    # Outline levels exist so the TOC has something to index - but only on
    # banners. An outline level on ordinary prose puts that prose in the
    # contents list.
    $maxLvl = 1
    if ($Profile.formatting.outlineLevels) { $maxLvl = [int]$Profile.formatting.outlineLevels.subBanner }
    $deep = @([regex]::Matches($bodyXml, '<w:outlineLvl\s+w:val="(\d+)"') |
              ForEach-Object { [int]$_.Groups[1].Value } |
              Where-Object { $_ -gt $maxLvl })
    if ($deep.Count -gt 0) { Fail 'OutlineLevelDepth' "$($deep.Count) paragraph(s) carry an outline level deeper than $maxLvl. Only banners are indexed." }
    else { Pass 'OutlineLevelDepth' }

    # ---- 13a. FontFloor ---------------------------------------------------
    #
    # Accessibility floor: body 11 pt, table and cell text 10 pt. In half-points
    # that is a hard minimum of 20 on any sized run in the generated body, and a
    # docDefaults of 22 so unsized runs land at 11 pt rather than falling back to
    # 10.
    #
    # Scoped to the generated body. The template cover sheet runs 8.5 pt policy
    # prose, compressed to hold the sheet to one page - a separate locked
    # position and not ours to raise here.
    #
    # This exists because the floor is the easiest rule in the skill to breach by
    # accident: one hardcoded w:sz in a here-string bypasses every constant. That
    # is exactly how 15 runs at 9.5 pt survived the first pass of this fix.
    $floor = 20
    if ($Profile.formatting.minimumRunSize) { $floor = [int]$Profile.formatting.minimumRunSize }
    $small = @{}
    foreach ($m in [regex]::Matches($bodyXml, '<w:sz w:val="(\d+)"')) {
        $v = [int]$m.Groups[1].Value
        if ($v -lt $floor) { if (-not $small.ContainsKey($v)) { $small[$v] = 0 }; $small[$v]++ }
    }
    if ($small.Count -gt 0) {
        $d = ($small.GetEnumerator() | Sort-Object { [int]$_.Name } | ForEach-Object { "$($_.Name) ($([int]$_.Name/2) pt) x$($_.Value)" }) -join ', '
        Fail 'FontFloor' "Generated-body runs below the $([int]$floor/2) pt floor: $d. Look for a hardcoded w:sz in a here-string - the constants are SZ_CELL and SZ_BODY."
    }
    else { Pass 'FontFloor' }

    # docDefaults must carry a size, or every unsized run silently falls back to
    # 10 pt and the body breaches the floor without a single w:sz to find.
    $stylesPath = Join-Path $WorkDir 'word\styles.xml'
    if (Test-Path -LiteralPath $stylesPath) {
        $st = Get-DocxPart -WorkDir $WorkDir -Part 'word/styles.xml'
        $dd = 0
        if ($st -match '<w:rPrDefault>\s*<w:rPr>(?:(?!</w:rPr>).)*?<w:sz\s+w:val="(\d+)"') { $dd = [int]$Matches[1] }
        $wantDd = 22
        if ($Profile.formatting.sizes.body) { $wantDd = [int]$Profile.formatting.sizes.body }
        if ($dd -eq 0)          { Fail 'FontFloor' "docDefaults carries no w:sz, so every unsized run falls back to 10 pt - below the 11 pt body floor. Run scripts/Patch-TemplateFontFloor.ps1." }
        elseif ($dd -lt $wantDd) { Fail 'FontFloor' "docDefaults w:sz is $dd ($([int]$dd/2) pt); the body floor is $wantDd ($([int]$wantDd/2) pt)." }
        else { Pass 'DocDefaultFontSize' }
    }

    # ---- 14. PageBreakTargets --------------------------------------------
    # Verify by extracting what each break LANDS ON, not by counting breaks.
    # @() MATTERS: a zero-break document returns an empty array, which unrolls
    # to $null, and Compare-Object below then throws a non-terminating binding
    # error and leaves $diff empty - a silent PASS exactly when every expected
    # break is missing. -Xml skips a second full read of a part already loaded.
    $targets = @(Get-PageBreakTarget -WorkDir $WorkDir -Part $Part -Xml $xml)

    # ALWAYS RUNS. A break landing on an empty paragraph is the blank-page failure
    # mode and is self-evident from the document alone - it needs no expected list.
    # Without this the check was inert in every real build, because nothing passes
    # -ExpectedBreakTargets, while the profile and house-style both call it blocking.
    $emptyBreaks = @($targets | Where-Object { $_ -like '*empty paragraph*' })
    if ($emptyBreaks.Count) {
        Fail 'PageBreakTargets' "$($emptyBreaks.Count) page break(s) land on an empty paragraph - each prints as a blank page. Put the break on the heading, never on a spacer."
    } elseif (-not $ExpectedBreakTargets) {
        Pass 'PageBreakTargets'
    }

    if ($ExpectedBreakTargets) {
        $diff = Compare-Object -ReferenceObject $ExpectedBreakTargets -DifferenceObject $targets
        if ($diff) {
            foreach ($d in $diff | Select-Object -First 10) {
                $side = if ($d.SideIndicator -eq '=>') { 'unexpected break on' } else { 'MISSING break on' }
                Fail 'PageBreakTargets' "$side '$($d.InputObject)'"
            }
        } else { Pass 'PageBreakTargets' }
    }

    [pscustomobject]@{
        Ok           = ($failures.Count -eq 0)
        Failures     = $failures.ToArray()
        Warnings     = $warnings.ToArray()
        Passed       = $passes.ToArray()
        BreakTargets = $targets
    }
}

function Get-PageBreakTarget {
    <#  What each page break actually lands on, as a list.

        A count of 22 tells you nothing. A list of 22 headings tells you
        everything. Catches both mechanisms: pageBreakBefore in a pPr, and an
        explicit <w:br w:type="page"/>.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $WorkDir,
        [string] $Part = 'word/document.xml',
        [string] $Xml            # already-loaded part content; skips the disk read
    )
    if (-not $Xml) { $Xml = Get-DocxPart -WorkDir $WorkDir -Part $Part }
    $out = New-Object System.Collections.Generic.List[string]

    # Match FROM AN OFFSET rather than -match over $Xml.Substring($m.Index):
    # the substring copies the multi-megabyte tail of document.xml once per
    # break, which is hundreds of MB of churn on a document with 20+ breaks.
    $rxT = [regex]'<w:t[^>]*>([^<]*)</w:t>'

    foreach ($m in [regex]::Matches($Xml, '<w:p(?:\s[^>]*)?>\s*<w:pPr>(?:(?!</w:pPr>).)*?<w:pageBreakBefore\s*/>.*?</w:p>', 'Singleline')) {
        $t = (([regex]::Matches($m.Value, '<w:t[^>]*>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value }) -join '').Trim()
        if (-not $t) {
            # The break sits on a banner-table paragraph; the text is the next
            # w:t after it in the package.
            $mm = $rxT.Match($Xml, $m.Index + $m.Length)
            if ($mm.Success) { $t = $mm.Groups[1].Value.Trim() }
        }
        if (-not $t) { $t = '(empty paragraph - this is the blank-page failure mode)' }
        # UNESCAPE. This list is printed verbatim in the build report, and a raw
        # &amp; in "Principles of assessment &amp; rules of evidence" reads as a defect.
        $t = $t -replace '&lt;','<' -replace '&gt;','>' -replace '&quot;','"' -replace '&apos;',"'" -replace '&amp;','&'
        $out.Add($t)
    }
    foreach ($m in [regex]::Matches($Xml, '<w:br w:type="page"\s*/>')) {
        $t = ''
        $mm = $rxT.Match($Xml, $m.Index)
        if ($mm.Success) { $t = $mm.Groups[1].Value.Trim() }
        $out.Add("(explicit br) $t")
    }
    return $out.ToArray()
}

function Write-HouseRuleReport {
    <# Print a gate result. Returns $true when the build may proceed. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Result, [string] $Label = '')

    if ($Label) { Write-Host "`n--- House rules: $Label ---" }
    Write-Host ("  passed: {0}" -f ($Result.Passed -join ', '))
    foreach ($w in $Result.Warnings) { Write-Host ("  WARN [{0}] {1}" -f $w.Check, $w.Detail) }
    if ($Result.Ok) { Write-Host '  GATE: PASS'; return $true }
    Write-Host "  GATE: FAIL - $($Result.Failures.Count) finding(s)"
    foreach ($f in $Result.Failures) { Write-Host ("    [{0}] {1}" -f $f.Check, $f.Detail) }
    return $false
}

Write-Verbose 'Test-HouseRules.ps1 loaded.'
