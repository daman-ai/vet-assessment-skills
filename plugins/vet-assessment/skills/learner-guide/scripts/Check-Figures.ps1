<#
    Check-Figures.ps1 - the PLACED artwork, checked mechanically, on the
    finished file.

    Implements the placement arm of the gate the design calls
    Assert-FullRegateAfterMutation. Run it at Stage 7c, after placement, as part
    of the COMPLETE gate set - never on its own.

    WHY IT MATTERS THAT THIS RUNS AFTER PLACEMENT AND SO DOES EVERYTHING ELSE.
    Placement is the last mutation of both artefacts and on the pipeline this
    was promoted from it was followed by exactly one of five gates. The figure
    registry's variant-aware sweep therefore never once ran against a document
    that actually contained figure rows. Standing rule: any stage that changes
    what is on the page is followed by the whole gate set, never a subset.

    -AfterArtwork IS THE SWITCH THAT MAKES THIS A GATE. Before placement a
    guide legitimately carries prompt blocks and no captions, and a deck
    carries the template's media and no figure, so every arm below is
    ADVISORY without the switch: counts are printed, nothing blocks, and the
    runner records the member as not-applicable-before-artwork. With the
    switch every arm blocks. A gate that blocked on a pre-placement document
    would be a false fail on every build; one that stayed advisory after
    placement would be the false green this file was rewritten to remove.

    WHAT IT CHECKS, read-only, straight from the zip, by the predicates
    Lib-GateCommon declares once (Get-GateDrawingCounts,
    Get-GatePromptMarkerRegex, Test-GateCaptionParagraph):

      - PLACED FIGURES ARE COUNTED BY ONE RULE. On a guide every w:drawing in
        the body of word/document.xml is a placed figure whatever it is
        called - the artwork sub-skill names what it places ('IMG-012
        illustration'), never this skill's prefix - and the header's brand
        mark is excluded. On a deck the placed figures are the p:pic shapes
        this skill's Set-SlidePicture names with the shape prefix; the
        template's media ('Image 0..4') sits on every slide and is reported
        beside them, never counted as a figure. The version this replaces
        filtered deck pictures on a name pattern the renderer never writes,
        examined zero drawings and printed green.
      - every placed figure carries non-empty alt text (docPr/cNvPr descr or
        title); house rule is that everything placed is described
      - after artwork, ZERO placed figures against a spine that plans some is
        a FAILURE naming the filter and what was on the page, never a green
        line over nothing
      - CAPTIONS ARE COUNTED PER NUMBER WITH NO DE-DUPLICATION, matched on the
        caption PARAGRAPH (prefix as a whole word, or the caption style), so
        an in-prose cross-reference ("see Figure 2.3.4") cannot count
      - figure numbers run 1..N inside each sub-section with no gap
      - CAPTION-TO-SLOT RECONCILIATION against the spine: every planned visual
        slot has exactly one caption, no caption exists for an unplanned
        slot. -BuildDir is REQUIRED (exit 2 without it); a supplied build
        whose spine yields no captioned, slotted visual is a failure that
        prints what was dropped and why, never a line blaming a parameter
        that was in fact supplied
      - no artwork prompt text survived placement, tested on each paragraph's
        JOINED text (Word splits a paragraph across w:t runs at will), in the
        body and in every header, footer, slide and notes part

    Exit 0 pass, 1 on any failure, 2 refused (input absent or unusable, named),
    4 self-test failed. PS 5.1. ASCII only in this file.
#>
# GATE: stages=7c; requires=Path,BuildDir

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][string[]] $Path,
    #  REQUIRED for the gate: the caption count is reconciled against the
    #  planned slots. Without it the gate refuses (exit 2), because a
    #  reconciliation with nothing to reconcile against is not a check.
    [string] $BuildDir,
    [string] $SpineDir,
    [string] $CaptionPrefix = 'Figure',
    [string] $CaptionStyleRx = '(?i)caption',
    #  The artwork sub-skill's prompt markers. Defaults to the vocabulary
    #  Lib-GateCommon declares; an explicit EMPTY override is refused.
    [string[]] $PromptToken,
    #  Every arm blocks only after placement. See the header.
    [switch] $AfterArtwork,
    [switch] $Quiet,
    [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$GATE = 'Check-Figures'

function Get-ZipPartText {
    <# name -> XML text for every part matching -Match, from the zip. #>
    param([Parameter(Mandatory)][string] $File, [Parameter(Mandatory)][string] $Match)
    $out = [ordered]@{}
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $File).Path)
    try {
        foreach ($e in $zip.Entries) {
            if ($e.FullName -notmatch $Match) { continue }
            $sr = New-Object System.IO.StreamReader($e.Open())
            $out[$e.FullName] = $sr.ReadToEnd()
            $sr.Dispose()
        }
    }
    finally { $zip.Dispose() }
    return $out
}

function Get-ParagraphText {
    <#  Every paragraph's JOINED run text, one string each. -Tag is w:p or a:p;
        -RunTag w:t or a:t. Word splits one sentence across runs at will, so a
        token test on raw XML misses what a reader sees.  #>
    param([Parameter(Mandatory)][string] $Xml, [Parameter(Mandatory)][string] $Tag, [Parameter(Mandatory)][string] $RunTag)
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($pm in [regex]::Matches($Xml, ('<' + $Tag + '\b[^>]*>.*?</' + $Tag + '>'), 'Singleline')) {
        $t = -join ([regex]::Matches($pm.Value, ('<' + $RunTag + '(?:\s[^>]*)?>([^<]*)</' + $RunTag + '>')) | ForEach-Object { $_.Groups[1].Value })
        $out.Add([System.Net.WebUtility]::HtmlDecode($t))
    }
    return $out.ToArray()
}

function Invoke-CheckFigures {
    param(
        [string[]] $Path, [string] $BuildDir, [string] $SpineDir, [string] $CaptionPrefix, [string] $CaptionStyleRx,
        [string[]] $PromptToken, [bool] $PromptTokenBound, [bool] $AfterArtwork
    )
    $failures = 0

    # ---- inputs. A refusal names what is missing; nothing is defaulted away.
    if (-not $Path -or @($Path).Count -eq 0) { throw (New-Object System.InvalidOperationException ("CHECK-SET EMPTY: -Path yielded nothing. Name the rendered guide and deck.")) }
    if (-not $BuildDir) {
        throw (New-Object System.InvalidOperationException ("CHECK-SET EMPTY: -BuildDir yielded nothing. The caption-to-slot reconciliation input is absent - at Stage 7c it must be supplied so the counts have something to be checked against."))
    }
    if ($PromptTokenBound) {
        if (@($PromptToken | Where-Object { "$_".Trim() }).Count -eq 0) {
            throw (New-Object System.InvalidOperationException ("CHECK-SET EMPTY: -PromptToken override yielded nothing. Omit it to use the vocabulary Lib-GateCommon declares (Get-GatePromptMarkerTokens)."))
        }
    }
    else { $PromptToken = @(Get-GatePromptMarkerTokens) }
    $openerRx = Get-GatePromptMarkerRegex -Part any

    #  Arms are registered for the artefacts actually named: captions,
    #  numbering and reconciliation are guide arms and have no check-set on a
    #  deck-only run, so a deck-only invocation must not carry them as
    #  blocking arms that end empty.
    $hasGuide = @($Path | Where-Object { $_ -notmatch '(?i)\.pptx$' }).Count -gt 0
    Reset-GateArmRoster
    $armNames = @('placement-count', 'alt-text', 'prompt-residue')
    if ($hasGuide) { $armNames += @('captions', 'contiguity', 'reconciliation') }
    foreach ($arm in $armNames) {
        if ($AfterArtwork) { Register-GateArm -Name $arm -Blocking } else { Register-GateArm -Name $arm }
    }
    if (-not $AfterArtwork) {
        Write-Host ''
        Write-Host '  REPORT ONLY - -AfterArtwork not passed: a pre-placement document carries prompt blocks and no figures by design, so every arm below reports and none blocks.' -ForegroundColor Yellow
    }

    # ---- the planned slots, from the spine (front matter included: the cover is a slot)
    $visuals = @(Get-GateSpineVisuals -BuildDir $BuildDir -SpineDir $SpineDir -IncludeFrontMatter)
    $noCaption = @($visuals | Where-Object { $_.Slot -and -not "$($_.Caption)".Trim() })
    $noSlot    = @($visuals | Where-Object { -not "$($_.Slot)".Trim() })
    $plannedSlots = @($visuals | Where-Object { "$($_.Slot)".Trim() -and "$($_.Caption)".Trim() } | ForEach-Object { [string]$_.Slot } | Sort-Object -Unique)
    #  Slot 0.1 is the cover: decorative, no caption on the title page by house
    #  rule, so it is planned but never reconciled against a caption.
    $reconcileSlots = @($plannedSlots | Where-Object { $_ -ne '0.1' })
    Write-GateCheckSet -What 'planned visual slot(s) on the spine' -Count $visuals.Count -DerivedFrom 'Get-GateSpineVisuals -IncludeFrontMatter'

    $totalPlaced = 0
    $totalPrompts = 0
    $captionsSeen = 0
    $reconciled = 0
    $contigSections = 0
    $altExamined = 0
    $altWithText = 0

    foreach ($file in $Path) {
        if (-not (Test-Path -LiteralPath $file)) { throw (New-Object System.IO.FileNotFoundException ("{0}: not found: {1}" -f $GATE, $file)) }
        $leaf = Split-Path $file -Leaf
        $isDeck = ($file -match '(?i)\.pptx$')
        $kind = if ($isDeck) { 'deck' } else { 'guide' }

        Write-Host ''
        Write-Host ("PLACED ARTWORK - {0}" -f $leaf) -ForegroundColor Cyan

        # --- 1. placed figures, by the one shared rule; every one described
        $dc = Get-GateDrawingCounts -PackageDir $file -Kind $kind
        $placed = [int]$dc.bodyDrawings
        $noAlt  = $placed - [int]$dc.bodyWithAlt
        $totalPlaced += $placed
        $altExamined += $placed
        $altWithText += [int]$dc.bodyWithAlt
        if ($isDeck) {
            Write-Host ("  placed figures (prefixed p:pic): {0}   template media on slides: {1}   media parts: {2}" -f $placed, $dc.unprefixed, $dc.mediaParts) -ForegroundColor DarkGray
        }
        else {
            Write-Host ("  placed figures (body w:drawing): {0}   drawings incl. headers/footers: {1}   media parts: {2}" -f $placed, $dc.total, $dc.mediaParts) -ForegroundColor DarkGray
        }
        if ($placed -eq 0) {
            $namesText = if (@($dc.names).Count -gt 0) { (@($dc.names) -join ', ') } else { '(no drawing objects at all)' }
            Write-Host ("  on the page: {0}" -f $namesText) -ForegroundColor DarkGray
            if ($AfterArtwork -and $reconcileSlots.Count -gt 0) {
                Write-Host ("  X zero placed figures after artwork against {0} planned slot(s). Filter: {1}" -f $reconcileSlots.Count, $dc.filter) -ForegroundColor Red
                $failures++
            }
        }
        if ($placed -gt 0) {
            if ($noAlt -eq 0) { Write-Host '  every placed figure carries alt text' -ForegroundColor Green }
            else { Write-Host ("  X {0} placed figure(s) with no alt text" -f $noAlt) -ForegroundColor Red; if ($AfterArtwork) { $failures++ } }
        }

        # --- prompt residue, on each paragraph's JOINED text, every part swept
        $partMatch = if ($isDeck) { '(?i)^ppt/(slides|notesSlides)/[^/]+\.xml$' } else { '(?i)^word/(document|header\d+|footer\d+)\.xml$' }
        $parts = Get-ZipPartText -File $file -Match $partMatch
        $paraTag = if ($isDeck) { 'a:p' } else { 'w:p' }
        $runTag  = if ($isDeck) { 'a:t' } else { 'w:t' }
        $leftover = 0
        $hitTokens = @{}
        foreach ($k in $parts.Keys) {
            foreach ($ptxt in (Get-ParagraphText -Xml $parts[$k] -Tag $paraTag -RunTag $runTag)) {
                $trim = $ptxt.Trim()
                if (-not $trim) { continue }
                $hit = $false
                if ($PromptTokenBound) {
                    foreach ($tok in $PromptToken) { if ($trim.IndexOf($tok, [System.StringComparison]::Ordinal) -ge 0) { $hit = $true; $hitTokens[$tok] = 1 + [int]$hitTokens[$tok] } }
                }
                elseif ($trim -cmatch $openerRx) { $hit = $true; $hitTokens[($trim.Substring(0, [Math]::Min(24, $trim.Length)))] = 1 + [int]$hitTokens[($trim.Substring(0, [Math]::Min(24, $trim.Length)))] }
                if ($hit) { $leftover++ }
            }
        }
        $totalPrompts += $leftover
        if ($leftover -eq 0) { Write-Host ("  no prompt text in any of the {0} part(s) swept" -f @($parts.Keys).Count) -ForegroundColor Green }
        else {
            $sample = (@($hitTokens.Keys | Select-Object -First 4) -join ' | ')
            if ($AfterArtwork) { Write-Host ("  X prompt text survived placement: {0} paragraph(s), e.g. {1}" -f $leftover, $sample) -ForegroundColor Red; $failures++ }
            else { Write-Host ("  prompt block paragraph(s) awaiting artwork: {0}, e.g. {1}" -f $leftover, $sample) -ForegroundColor DarkGray }
        }

        if ($isDeck) { continue }   # captions and figure numbering are a guide concern

        # --- 2. captions, per number, NO de-duplication, matched on the paragraph
        $doc = $parts['word/document.xml']
        $numRx = '^\s*' + [regex]::Escape($CaptionPrefix) + '\s+(\d+(?:\.\d+)+)'
        $counts = @{}
        $rejected = 0
        foreach ($pm in [regex]::Matches($doc, '<w:p\b[^>]*>.*?</w:p>', 'Singleline')) {
            $p = $pm.Value
            $text = -join ([regex]::Matches($p, '<w:t(?:\s[^>]*)?>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value })
            $text = [System.Net.WebUtility]::HtmlDecode($text)
            $m = [regex]::Match($text, $numRx)
            if (-not $m.Success) { continue }
            if (-not (Test-GateCaptionParagraph -ParagraphXml $p -CaptionPrefix $CaptionPrefix -CaptionStyleRx $CaptionStyleRx)) { $rejected++; continue }
            #  A caption paragraph is one that is ONLY the caption line, centred
            #  or captioned by style - prose that merely begins 'Figure 2.3.4
            #  shows' is a cross-reference. The shared predicate settles the
            #  prefix; centring or a caption style settles the paragraph shape.
            $style = [regex]::Match($p, '<w:pStyle w:val="([^"]*)"').Groups[1].Value
            $shaped = ($style -and $style -match $CaptionStyleRx) -or ($p -match '<w:jc w:val="center"\s*/>') -or ($p -match '<w:i\s*/>' -and $text.Trim().Length -le 200)
            if (-not $shaped) { $rejected++; continue }
            $num = $m.Groups[1].Value
            if ($counts.ContainsKey($num)) { $counts[$num]++ } else { $counts[$num] = 1 }
        }
        $captionsSeen += $counts.Count
        Write-Host ("  caption paragraphs: {0} distinct number(s); {1} in-prose reference(s) correctly not counted" -f $counts.Count, $rejected) -ForegroundColor DarkGray
        $dupes = @($counts.Keys | Where-Object { $counts[$_] -gt 1 } | Sort-Object)
        if ($dupes.Count -gt 0) {
            foreach ($d in $dupes) { Write-Host ("  X {0} {1} has {2} captions - every cross-reference to it is now ambiguous" -f $CaptionPrefix, $d, $counts[$d]) -ForegroundColor Red }
            if ($AfterArtwork) { $failures++ }
        }
        elseif ($counts.Count -gt 0) { Write-Host '  no figure number carries more than one caption' -ForegroundColor Green }

        # --- 3. contiguous inside each sub-section
        $bySection = @{}
        foreach ($num in $counts.Keys) {
            $bits = $num -split '\.'
            $sec = ($bits[0..($bits.Count - 2)]) -join '.'
            $n = [int]$bits[-1]
            if (-not $bySection.ContainsKey($sec)) { $bySection[$sec] = New-Object System.Collections.Generic.List[int] }
            $bySection[$sec].Add($n)
        }
        $contigSections += $bySection.Count
        $bad = 0
        foreach ($sec in ($bySection.Keys | Sort-Object)) {
            $ns = @($bySection[$sec] | Sort-Object)
            $gaps = @((1..$ns[-1]) | Where-Object { $ns -notcontains $_ })
            if ($gaps.Count -gt 0) {
                Write-Host ("  X sub-section {0}: figure number(s) {1} missing from 1..{2}" -f $sec, ($gaps -join ', '), $ns[-1]) -ForegroundColor Red
                $bad++
            }
        }
        if ($bySection.Count -gt 0) {
            if ($bad -eq 0) { Write-Host ("  figure numbering is contiguous in all {0} sub-section(s)" -f $bySection.Count) -ForegroundColor Green }
            elseif ($AfterArtwork) { $failures++ }
        }

        # --- 4. caption-to-slot reconciliation, counts from the spine
        if ($reconcileSlots.Count -eq 0) {
            Write-Host ("  X the spine under -BuildDir yields no captioned, slotted visual to reconcile against: {0} visual(s) dropped for lacking a caption, {1} for lacking a slot" -f $noCaption.Count, $noSlot.Count) -ForegroundColor Red
            foreach ($v in @($noCaption | Select-Object -First 5)) { Write-Host ("      no caption: {0} slot {1}" -f $v.File, $v.Slot) -ForegroundColor DarkGray }
            foreach ($v in @($noSlot | Select-Object -First 5))    { Write-Host ("      no slot:    {0} kind {1}" -f $v.File, $v.Kind) -ForegroundColor DarkGray }
            if ($AfterArtwork) { $failures++ }
        }
        else {
            $missingSlots = @($reconcileSlots | Where-Object { -not $counts.ContainsKey($_) })
            $strays = @($counts.Keys | Where-Object { $reconcileSlots -notcontains $_ } | Sort-Object)
            $reconciled += $reconcileSlots.Count
            Write-Host ("  spine plans {0} captioned slot(s) (cover 0.1 decorative, not reconciled); the document carries {1}" -f $reconcileSlots.Count, $counts.Count) -ForegroundColor DarkGray
            if ($missingSlots.Count -gt 0) {
                Write-Host ("  X planned slot(s) with no caption in the document: {0}" -f (($missingSlots | Select-Object -First 12) -join ', ')) -ForegroundColor Red
                if ($AfterArtwork) { $failures++ }
            }
            if ($strays.Count -gt 0) {
                Write-Host ("  X caption(s) for slot(s) the spine does not plan: {0}" -f ($strays -join ', ')) -ForegroundColor Red
                if ($AfterArtwork) { $failures++ }
            }
            if ($missingSlots.Count -eq 0 -and $strays.Count -eq 0) { Write-Host '  every planned slot has exactly one caption, and no caption is unplanned' -ForegroundColor Green }
        }
    }

    # ---- arms. Sizes are what each arm examined; an arm that examined
    #      nothing after artwork is a refusal, never a pass.
    $sizeOrEmpty = {
        param([string] $Name, [int] $Size, [int] $Findings)
        if ($Size -gt 0) { Complete-GateArm -Name $Name -State ran -Size $Size -Findings $Findings }
        else { Complete-GateArm -Name $Name -State empty -Size 0 -Findings $Findings }
    }
    & $sizeOrEmpty 'placement-count' $reconcileSlots.Count ($(if ($totalPlaced -eq 0 -and $reconcileSlots.Count -gt 0) { 1 } else { 0 }))
    #  alt-text examined every placed figure; with none placed after artwork
    #  the placement-count arm already carries the finding, so the alt arm is
    #  reported on the figures it saw rather than refused a second time.
    Complete-GateArm -Name 'alt-text' -State ran -Size ([Math]::Max(1, $altExamined)) -Findings ($altExamined - $altWithText)
    if ($hasGuide) {
        & $sizeOrEmpty 'captions' $captionsSeen 0
        & $sizeOrEmpty 'contiguity' $contigSections 0
        & $sizeOrEmpty 'reconciliation' $reconciled 0
    }
    & $sizeOrEmpty 'prompt-residue' (@($Path).Count) $totalPrompts
    $roster = Write-GateArmRoster
    Assert-GateArmsComplete

    Write-Host ''
    if ($failures -eq 0) {
        if ($AfterArtwork) { Write-Host ("  placed artwork is sound across {0} artefact(s)" -f @($Path).Count) -ForegroundColor Green }
        else { Write-Host ("  reported {0} artefact(s); nothing blocked (pre-placement)" -f @($Path).Count) -ForegroundColor Yellow }
        return 0
    }
    Write-Host ("  X {0} placed-artwork failure(s)" -f $failures) -ForegroundColor Red
    Write-Host '  Remediate, re-render, re-place, and re-run the WHOLE gate set - not this one.' -ForegroundColor Yellow
    return 1
}

# ---------------------------------------------------------------------------
# Self-test: minimal packages written from strings, every plant read back
# before it is believed.
# ---------------------------------------------------------------------------
function New-CfZip {
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][hashtable] $Parts)
    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Force }
    $zip = [System.IO.Compression.ZipFile]::Open($Path, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($k in $Parts.Keys) {
            $e = $zip.CreateEntry($k)
            $sw = New-Object System.IO.StreamWriter($e.Open(), (New-Object System.Text.UTF8Encoding($false)))
            $sw.Write([string]$Parts[$k]); $sw.Dispose()
        }
    }
    finally { $zip.Dispose() }
}

function Invoke-CheckFiguresSelfTest {
    $failed = 0
    $ok = { param([bool] $c, [string] $msg) if ($c) { Write-Host ("  ok   {0}" -f $msg) -ForegroundColor Green } else { Write-Host ("  FAIL {0}" -f $msg) -ForegroundColor Red; $script:cfFailed++ } }
    $script:cfFailed = 0
    $tmp = Join-Path $env:TEMP ('cfselftest_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path (Join-Path $tmp 'spine') | Out-Null
    try {
        # a spine with one sub-section carrying two captioned slots, and a cover
        $sub = @{ ref = 'PC 1.1'; visuals = @(
            @{ slot = '1.1.1'; kind = 'image'; caption = 'Figure 1.1.1 - a bench'; alt = 'a bench'; prompt = 'x' },
            @{ slot = '1.1.2'; kind = 'image'; caption = 'Figure 1.1.2 - a probe'; alt = 'a probe'; prompt = 'y' }) }
        [IO.File]::WriteAllText((Join-Path $tmp 'spine\t1_1.1.json'), ($sub | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
        [IO.File]::WriteAllText((Join-Path $tmp 'spine\cover.json'), (@{ visual = @{ slot = '0.1'; kind = 'image'; caption = ''; alt = 'cover'; prompt = 'c' } } | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
        [IO.File]::WriteAllText((Join-Path $tmp 'contract.json'), '{ "unit": { "code": "TEST" } }', (New-Object System.Text.UTF8Encoding($false)))

        $wNs = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"'
        $drawing = { param([string] $name, [string] $descr) ('<w:p><w:r><w:drawing><wp:inline><wp:docPr id="1" name="{0}" descr="{1}"/></wp:inline></w:drawing></w:r></w:p>' -f $name, $descr) }
        $cap = { param([string] $t) ('<w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:t>{0}</w:t></w:r></w:p>' -f $t) }
        $goodDoc = ('<?xml version="1.0" encoding="UTF-8"?><w:document {0}><w:body>' -f $wNs) +
            (& $drawing 'IMG-001 illustration' 'A bench') + (& $cap 'Figure 1.1.1 - a bench') +
            (& $drawing 'IMG-002 illustration' 'A probe') + (& $cap 'Figure 1.1.2 - a probe') +
            '<w:p><w:r><w:t>See Figure 1.1.1 for the bench.</w:t></w:r></w:p></w:body></w:document>'
        $header = ('<?xml version="1.0" encoding="UTF-8"?><w:hdr {0}>' -f $wNs) + (& $drawing 'Picture 1' 'brand mark') + '</w:hdr>'
        $ct = '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/></Types>'
        $good = Join-Path $tmp 'good.docx'
        New-CfZip -Path $good -Parts @{ '[Content_Types].xml' = $ct; 'word/document.xml' = $goodDoc; 'word/header1.xml' = $header }
        #  plant 1: a prompt split across two runs, and a figure with no alt
        $badDoc = ('<?xml version="1.0" encoding="UTF-8"?><w:document {0}><w:body>' -f $wNs) +
            (& $drawing 'IMG-001 illustration' '') + (& $cap 'Figure 1.1.1 - a bench') +
            '<w:p><w:r><w:t>[PHO</w:t></w:r><w:r><w:t>TO: a chef at a bench]</w:t></w:r></w:p></w:body></w:document>'
        $bad = Join-Path $tmp 'bad.docx'
        New-CfZip -Path $bad -Parts @{ '[Content_Types].xml' = $ct; 'word/document.xml' = $badDoc }
        #  read the plants back before believing them
        $bz = Get-ZipPartText -File $bad -Match '(?i)^word/document\.xml$'
        & $ok ($bz['word/document.xml'] -match 'descr=""' -and $bz['word/document.xml'] -match '\[PHO</w:t>') 'plants landed in bad.docx (empty descr; prompt split across two runs)'

        #  a deck: one prefixed picture without alt, template media on the slide
        $pNs = 'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"'
        $slide = ('<?xml version="1.0" encoding="UTF-8"?><p:sld {0}><p:cSld><p:spTree>' -f $pNs) +
            '<p:pic><p:nvPicPr><p:cNvPr id="2" name="Image 0" descr=""/></p:nvPicPr></p:pic>' +
            ('<p:pic><p:nvPicPr><p:cNvPr id="3" name="{0}Figure 1" descr=""/></p:nvPicPr></p:pic>' -f (Get-GateShapePrefix)) +
            '</p:spTree></p:cSld></p:sld>'
        $deck = Join-Path $tmp 'deck.pptx'
        New-CfZip -Path $deck -Parts @{ '[Content_Types].xml' = $ct; 'ppt/slides/slide1.xml' = $slide }
        $preDeck = Join-Path $tmp 'predeck.pptx'
        New-CfZip -Path $preDeck -Parts @{ '[Content_Types].xml' = $ct; 'ppt/slides/slide1.xml' = ('<?xml version="1.0" encoding="UTF-8"?><p:sld {0}><p:cSld><p:spTree><p:pic><p:nvPicPr><p:cNvPr id="2" name="Image 0" descr=""/></p:nvPicPr></p:pic></p:spTree></p:cSld></p:sld>' -f $pNs) }

        $run = { param([string[]] $p, [bool] $after, [string[]] $tok, [bool] $tokBound)
            try { return (Invoke-CheckFigures -Path $p -BuildDir $tmp -CaptionPrefix 'Figure' -CaptionStyleRx '(?i)caption' -PromptToken $tok -PromptTokenBound $tokBound -AfterArtwork $after) }
            catch { if ($_.Exception.Message -match '^(CHECK-SET EMPTY|ARMS INCOMPLETE):') { return 2 } ; throw }
        }
        $rc = & $run @($good) $true @() $false
        & $ok ($rc -eq 0) ("clean guide after artwork passes (rc={0})" -f $rc)
        $rc = & $run @($bad) $true @() $false
        & $ok ($rc -eq 1) ("no-alt figure + split prompt + missing slot 1.1.2 fails after artwork (rc={0})" -f $rc)
        $rc = & $run @($bad) $false @() $false
        & $ok ($rc -eq 0) ("the same document before artwork reports only (rc={0})" -f $rc)
        $rc = & $run @($deck) $true @() $false
        & $ok ($rc -eq 1) ("deck with a prefixed picture lacking alt fails after artwork (rc={0})" -f $rc)
        $rc = & $run @($preDeck) $false @() $false
        & $ok ($rc -eq 0) ("pre-placement deck (template media only) reports and passes without -AfterArtwork (rc={0})" -f $rc)
        $rc = & $run @($preDeck) $true @() $false
        & $ok ($rc -eq 1) ("pre-placement deck WITH -AfterArtwork fails: zero figures against planned slots (rc={0})" -f $rc)
        $rc = & $run @($good) $true @() $true
        & $ok ($rc -eq 2) ("an explicit empty -PromptToken is refused (rc={0})" -f $rc)
        $rc = try { Invoke-CheckFigures -Path @($good) -BuildDir '' -CaptionPrefix 'Figure' -CaptionStyleRx '(?i)caption' -PromptToken @() -PromptTokenBound $false -AfterArtwork $true; 0 } catch { if ($_.Exception.Message -match '^CHECK-SET EMPTY: -BuildDir') { 2 } else { 99 } }
        & $ok ($rc -eq 2) ("no -BuildDir is refused naming it (rc={0})" -f $rc)
        #  an empty planned set with -BuildDir supplied is a failure that names what was dropped
        $tmp2 = Join-Path $tmp 'nocap'
        New-Item -ItemType Directory -Force -Path (Join-Path $tmp2 'spine') | Out-Null
        [IO.File]::WriteAllText((Join-Path $tmp2 'spine\t1_1.1.json'), (@{ ref = 'PC 1.1'; visuals = @(@{ slot = '1.1.1'; kind = 'image'; caption = ''; alt = 'x'; prompt = 'x' }) } | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
        [IO.File]::WriteAllText((Join-Path $tmp2 'contract.json'), '{ "unit": { "code": "TEST" } }', (New-Object System.Text.UTF8Encoding($false)))
        $rc = try { Invoke-CheckFigures -Path @($good) -BuildDir $tmp2 -CaptionPrefix 'Figure' -CaptionStyleRx '(?i)caption' -PromptToken @() -PromptTokenBound $false -AfterArtwork $true } catch { if ($_.Exception.Message -match '^(CHECK-SET EMPTY|ARMS INCOMPLETE):') { 2 } else { throw } }
        & $ok ($rc -ne 0) ("a supplied build whose spine yields no captioned slot does not pass (rc={0})" -f $rc)
    }
    finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host ''
    if ($script:cfFailed -eq 0) { Write-Host ("  {0} self-test: all cases passed" -f $GATE) -ForegroundColor Green; return 0 }
    Write-Host ("  {0} self-test: {1} case(s) FAILED" -f $GATE, $script:cfFailed) -ForegroundColor Red
    return 4
}

if ($SelfTest) { exit (Invoke-CheckFiguresSelfTest) }

try {
    $rc = Invoke-CheckFigures -Path $Path -BuildDir $BuildDir -SpineDir $SpineDir -CaptionPrefix $CaptionPrefix -CaptionStyleRx $CaptionStyleRx `
        -PromptToken $PromptToken -PromptTokenBound ($PSBoundParameters.ContainsKey('PromptToken')) -AfterArtwork ([bool]$AfterArtwork)
    exit $rc
}
catch {
    $msg = $_.Exception.Message
    if ($msg -match '^(CHECK-SET EMPTY|ARMS INCOMPLETE):') {
        Write-Host ("  X {0} REFUSED - {1}" -f $GATE, $msg) -ForegroundColor Red
        exit 2
    }
    Write-Host ("  X {0}: {1}" -f $GATE, $msg) -ForegroundColor Red
    exit 1
}
