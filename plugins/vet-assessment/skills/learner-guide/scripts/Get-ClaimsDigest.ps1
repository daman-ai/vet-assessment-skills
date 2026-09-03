<#
    Get-ClaimsDigest.ps1 - every checkable claim in BOTH extracts, one line
    per sentence, with its location, exact repeats collapsed with a count.

        & "$SkillDir\scripts\Get-ClaimsDigest.ps1" -BuildDir $out -OutPath $out\cleanroom\review\crossdoc\claims-digest.txt

    WHY IT EXISTS. The cross-document reviewer's job is agreement: the same
    temperature in Topic 4 and Topic 5, the same clause cited for the same
    duty in the guide and the deck, the same delivery time on the order form,
    the slide and the sub-section it mirrors. That job needs every claim and
    none of the prose around it, and the prose is 1.1 MB. A reader handed the
    whole of it holds part of it, and an inverted scope statement survived
    three audit rounds on one build for exactly that reason - each round found
    it in a different place and fixed that place. This digest is what lets one
    reader see EVERY place at once.

    WHAT COUNTS AS A CLAIM. A sentence, table cell, caption, alt text line,
    chip or speaker note that carries any of:
      num       a numeral with a unit - degrees C, Gms, kg, L, mm, hours,
                minutes, days, per cent, portions, dollar amounts and their
                common variants - including minus values and ranges
      term      a locked term from contract.json terminology, or the
                abbreviation it introduces
      variant   a form the contract says NEVER to use for that term
      instr     an instrument citation - Standard N.N.N, clause N, a named
                Act or Regulations with a year, the Food Standards Code
      question  a question reference, by the contract's own questionPattern
      clock     a scenario time or day - weekday, clock time, date, "week
                ending", "Day N"
      attrib    adoption or attribution language - adopted, house standard,
                stricter than, the Code requires/allows, recommends - the
                sentences where a venue figure and a legal figure meet
    The check-sets are printed, and the term and variant sets are DERIVED
    from the contract, never typed here: a hand-copied term list is a second
    source of truth, and the one that drifts.

    WHAT IT NEVER DOES. It does not judge. It does not decide that two values
    disagree, and it does not drop a sentence because the value looks right.
    Deduplication is on the exact normalised sentence and keeps the count and
    every location, because "this sentence appears 71 times" and "this
    sentence appears once, in a speaker note" are both things the reviewer
    needs to know. One projection, and it is printed in the header: a
    sentence whose ONLY claim is a correctly used locked term is DROPPED
    from Part B and counted, because on the reference build those were
    1,048 sentences and 150 KB carrying no value to compare, while Part A
    already counts every term per topic and artefact. Every forbidden
    variant and every term beside a value is printed in full;
    -FullTermSentences prints everything in full. -Categories restricts
    both parts to the named categories, so the cross-document work can be
    split by category into two reviewers when one pack exceeds the budget;
    the header states the filter and how many sentences it excluded. Part A, the values index, lists each distinct matched
    value with where it occurs, so a lone "minus 20 degrees C" among thirty
    "minus 18 degrees C" is visible in one line.

    LOCATORS. G:L<line> T<topic>/<sub> <channel> for the guide, where line is
    the line of the FULL extract, topic is 'front', a number or 'back', sub is
    the current N.N heading, and channel is body, heading, caption or alt.
    D:S<slide> T<topic> <channel> for the deck, topic from deckplan.json (or
    'shared'), channel body, chip or notes.

    NO unit code, brand or build path is hard-coded.

    PS 5.1. ASCII only in this file.
    Exit 0 written, 2 a usage error, 4 the self-test failed.
#>

[CmdletBinding()]
param(
    [string] $BuildDir,
    [string] $GuideExtract,
    [string] $DeckExtract,
    [string] $Contract,
    [string] $DeckPlan,
    [string] $OutPath,
    #  How many locations a Part B line prints before "+N more". Every
    #  occurrence is still counted.
    [int] $MaxLocations = 12,
    #  Print term-only sentences in full rather than dropping them from Part B.
    [switch] $FullTermSentences,
    #  Restrict the digest to these categories (num term variant instr question
    #  clock attrib). Default: all of them.
    [string[]] $Categories,
    [switch] $SelfTest,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

$GATE = 'CLAIMS DIGEST'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Write-Utf8File {
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][AllowEmptyString()][string] $Content)
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($true)))
}

function New-Rx {
    param([Parameter(Mandatory)][string] $Pattern)
    return (New-Object System.Text.RegularExpressions.Regex($Pattern, [System.Text.RegularExpressions.RegexOptions]::None))
}

function ConvertTo-DigestKey {
    param([AllowEmptyString()][string] $Text)
    return (($Text -replace '\s+', ' ').Trim().TrimEnd('.', ';', ':', ',').ToLowerInvariant())
}

function Split-Sentence {
    param([AllowEmptyString()][string] $Line)
    return @([regex]::Split($Line, '(?<=[.!?])\s+(?=[A-Z0-9("''])') | Where-Object { $_.Trim() })
}

function Resolve-DigestInput {
    param([string] $BuildDir, [string] $Given, [string] $Stem)
    if ($Given) { return $Given }
    if (-not $BuildDir) { return $null }
    $cleanroom = Join-Path $BuildDir 'cleanroom'
    if (Test-Path -LiteralPath $cleanroom) {
        $cands = @(Get-ChildItem -LiteralPath $cleanroom -File | Where-Object { $_.Name -match ('^' + $Stem + '_r(\d+)\.txt$') } |
                   Sort-Object { [int]([regex]::Match($_.Name, '_r(\d+)\.txt$').Groups[1].Value) } -Descending)
        if ($cands.Count -gt 0) { return $cands[0].FullName }
    }
    $g = Join-Path $BuildDir ($Stem + '_gate.txt')
    if (Test-Path -LiteralPath $g) { return $g }
    return $null
}

# ---------------------------------------------------------------------------
# 1. The check-sets - derived from the contract where the contract owns them
# ---------------------------------------------------------------------------

function New-ClaimPatternSet {
    param($ContractObj)

    $notes = New-Object System.Collections.Generic.List[string]
    $deg = [string][char]0xB0
    $enDash = [string][char]0x2013
    $units = 'degrees?\s*C|' + $deg + '\s*C|Gms|gms|grams?|g|kg|kilograms?|mL|ml|millilitres?|L|litres?|mm|cm|m|metres?|hours?|hrs?|h|minutes?|mins?|min|seconds?|secs?|days?|weeks?|months?|years?|per\s?cent|%|portions?|serves?|servings?'
    $numRx = New-Rx ('(?i)(?<![\w.])(?:(?:minus\s+|-)?\d+(?:\.\d+)?(?:\s*(?:to|-|' + $enDash + ')\s*(?:minus\s+)?\d+(?:\.\d+)?)?\s*(?:' + $units + ')(?![A-Za-z])|\$\s?\d[\d,]*(?:\.\d+)?)')

    $instrRx = New-Rx ('(?:\bStandard\s+\d+(?:\.\d+)+[A-Z]?\b|\bclause\s+\d+(?:\.\d+)*\b|\b(?:[A-Z][A-Za-z]+\s+){0,6}(?:Act|Regulations?)\s+\d{4}\b|\bFood Standards Code\b|\bFood Safety Standards?\b|\bStandards for RTOs(?:\s+\d{4})?\b|\bOutcome Standard\s+\d+(?:\.\d+)*\b|\bAS(?:/NZS)?\s+\d{3,5}(?:\.\d+)*\b|\bCode of Practice\b)')

    $clockRx = New-Rx ('(?i)(?:\b(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\b|\b\d{1,2}:\d{2}\s?(?:am|pm)\b|\b\d{1,2}\s?(?:am|pm)\b|\b12\s?noon\b|\bmidnight\b|\b\d{1,2}\s+(?:January|February|March|April|May|June|July|August|September|October|November|December)(?:\s+\d{4})?\b|\bweek ending\b|\bday\s+\d+\b)')

    $attribRx = New-Rx ('(?i)(?:\badopt(?:s|ed|ion)?\b|\bhouse standard\b|\bstricter than\b|\bthe Code (?:requires|allows|sets|says|does not)\b|\brecommend(?:s|ed|ation)?\b|\blegal requirement\b|\bnot the law\b|\bthe law\b|\bcritical limit\b|\bnot required by\b|\bmandat(?:es|ed|ory)\b)')

    $questionRx = $null
    $qp = $null
    if ($null -ne $ContractObj -and @($ContractObj.PSObject.Properties.Name) -contains 'referenceConvention') {
        $qp = [string](Get-GateProp -Object $ContractObj.referenceConvention -Names @('questionPattern') -Default '')
    }
    if ($qp) { $questionRx = New-Rx $qp; $notes.Add('question pattern: from contract.json referenceConvention.questionPattern') }
    else { $questionRx = New-Rx '\b(?:Question|Task|Observation)\s?\d+(?:\s?\([a-z]\))?'; $notes.Add('question pattern: DEFAULT (no contract questionPattern) - Question/Task/Observation N') }

    # --- locked terms and their forbidden variants, from the contract
    $terms = New-Object System.Collections.Generic.List[string]
    $variantWords = New-Object System.Collections.Generic.List[string]
    $variantShort = New-Object System.Collections.Generic.List[string]
    #  A candidate shorter than three characters, or a three-letter all-lower-case
    #  word ("you"), is not a term. "Gms", "CCP" and "FIFO" are.
    function Add-Term { param([string] $T, [switch] $KeepThe) $t = $T.Trim().Trim('"', "'", '.', ',', ';'); if (-not $KeepThe -and $t -match '^the\s+') { $t = $t -replace '^the\s+', '' }; if ($t.Length -lt 3) { return }; if ($t.Length -eq 3 -and $t -cmatch '^[a-z]+$') { return }; if ($terms -notcontains $t) { $terms.Add($t) } }
    if ($null -ne $ContractObj -and @($ContractObj.PSObject.Properties.Name) -contains 'terminology' -and $null -ne $ContractObj.terminology) {
        foreach ($prop in $ContractObj.terminology.PSObject.Properties) {
            if ($prop.Name -like '_*') { continue }
            $val = [string]$prop.Value
            $lead = [regex]::Split($val, '\s\(|\s-\s|;|,')[0].Trim()
            foreach ($piece in ($lead -split '\s+or\s+')) { Add-Term $piece }
            Add-Term $prop.Name -KeepThe
            foreach ($m in [regex]::Matches($val, '\(([A-Z]{2,6})\)')) { Add-Term $m.Groups[1].Value }
            $nm = [regex]::Match($val, '(?i)\bnever\s+(.+)$')
            if ($nm.Success) {
                $clause = $nm.Groups[1].Value
                $quoted = @([regex]::Matches($clause, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
                $cands = if ($quoted.Count -gt 0) { $quoted } else { @([regex]::Split($clause, ',|\s+or\s+') | ForEach-Object { ($_ -replace '\s+as\s+.*$', '').Trim() }) }
                foreach ($c in $cands) {
                    $v = $c.Trim().Trim('"', "'", '.', ';')
                    if (-not $v) { continue }
                    if ($v.Length -le 2) { if ($variantShort -cnotcontains $v) { $variantShort.Add($v) } }
                    elseif ($variantWords -notcontains $v) { $variantWords.Add($v) }
                }
            }
        }
        $notes.Add(("terms: {0} locked term(s) and {1} forbidden variant(s), derived from contract.json terminology" -f $terms.Count, ($variantWords.Count + $variantShort.Count)))
    }
    else { $notes.Add('terms: NONE - no contract.json terminology supplied, so the term and variant categories are empty') }

    $termRx = $null
    if ($terms.Count -gt 0) {
        $alts = @($terms | Sort-Object { $_.Length } -Descending | ForEach-Object { [regex]::Escape($_) })
        $termRx = New-Rx ('(?i)(?<![\w-])(?:' + ($alts -join '|') + ')(?![\w-])')
    }
    $variantRxs = New-Object System.Collections.Generic.List[object]
    #  A variant that is a CASE variant of a locked term (gms against Gms) must match
    #  case-sensitively, or every correct use is reported as the forbidden one.
    $termsLower = @($terms | ForEach-Object { $_.ToLowerInvariant() })
    $vLoose = @($variantWords | Where-Object { $termsLower -notcontains $_.ToLowerInvariant() })
    $vStrict = @($variantWords | Where-Object { $termsLower -contains $_.ToLowerInvariant() })
    if ($vLoose.Count -gt 0) {
        $alts = @($vLoose | Sort-Object { $_.Length } -Descending | ForEach-Object { [regex]::Escape($_) })
        $variantRxs.Add((New-Rx ('(?i)(?<![\w-])(?:' + ($alts -join '|') + ')(?![\w-])')))
    }
    if ($vStrict.Count -gt 0) {
        $alts = @($vStrict | Sort-Object { $_.Length } -Descending | ForEach-Object { [regex]::Escape($_) })
        $variantRxs.Add((New-Rx ('(?<![\w-])(?:' + ($alts -join '|') + ')(?![\w-])')))
    }
    foreach ($s in $variantShort) {
        #  A one- or two-letter variant ("g", "G") only means anything after a numeral; case matters.
        $variantRxs.Add((New-Rx ('(?<=\d\s?)' + [regex]::Escape($s) + '(?![A-Za-z])')))
    }

    $patterns = [ordered]@{
        num = @($numRx)
        term = @($termRx)
        variant = @($variantRxs.ToArray())
        instr = @($instrRx)
        question = @($questionRx)
        clock = @($clockRx)
        attrib = @($attribRx)
    }
    return [pscustomobject]@{ Patterns = $patterns; Terms = @($terms); Variants = @(@($variantWords) + @($variantShort)); Notes = $notes }
}

# ---------------------------------------------------------------------------
# 2. Collect
# ---------------------------------------------------------------------------

function Add-ClaimSentence {
    param($Store, $Index, [string] $Sentence, [string] $Artefact, [string] $Locator, [string] $TopicLabel, $PatternSet)

    $cats = New-Object System.Collections.Generic.List[string]
    $values = @{}
    foreach ($cat in $PatternSet.Patterns.Keys) {
        foreach ($rx in @($PatternSet.Patterns[$cat])) {
            if ($null -eq $rx) { continue }
            $ms = $rx.Matches($Sentence)
            if ($ms.Count -eq 0) { continue }
            if ($cats -notcontains $cat) { $cats.Add($cat); $values[$cat] = New-Object System.Collections.Generic.List[string] }
            foreach ($m in $ms) { $values[$cat].Add($m.Value) }
        }
    }
    if ($cats.Count -eq 0) { return $false }

    $key = ConvertTo-DigestKey -Text $Sentence
    if (-not $Store.ContainsKey($key)) {
        $Store[$key] = [pscustomobject]@{ Text = $Sentence.Trim(); Count = 0; Locations = (New-Object System.Collections.Generic.List[string]); Categories = (New-Object System.Collections.Generic.List[string]); Terms = (New-Object System.Collections.Generic.List[string]); Order = $Store.Count }
    }
    $e = $Store[$key]
    $e.Count++
    $e.Locations.Add($Locator)
    foreach ($c in $cats) { if ($e.Categories -notcontains $c) { $e.Categories.Add($c) } }
    if ($values.ContainsKey('term')) { foreach ($v in $values['term']) { $lv = $v.ToLowerInvariant(); if ($e.Terms -notcontains $lv) { $e.Terms.Add($lv) } } }

    foreach ($cat in $values.Keys) {
        if (-not $Index.ContainsKey($cat)) { $Index[$cat] = @{} }
        foreach ($v in $values[$cat]) {
            $vk = ConvertTo-DigestKey -Text $v
            if (-not $Index[$cat].ContainsKey($vk)) {
                $Index[$cat][$vk] = [pscustomobject]@{ Display = $v.Trim(); Guide = 0; Deck = 0; GuideTopics = (New-Object System.Collections.Generic.List[string]); DeckTopics = (New-Object System.Collections.Generic.List[string]); First = $Locator }
            }
            $ix = $Index[$cat][$vk]
            if ($Artefact -eq 'guide') { $ix.Guide++; if ($ix.GuideTopics -notcontains $TopicLabel) { $ix.GuideTopics.Add($TopicLabel) } }
            else { $ix.Deck++; if ($ix.DeckTopics -notcontains $TopicLabel) { $ix.DeckTopics.Add($TopicLabel) } }
        }
    }
    return $true
}

function Read-GuideClaims {
    param([string] $Text, $Store, $Index, $PatternSet)
    $lines = @($Text -split "`r?`n")
    $topic = 'front'; $sub = '-'; $inAlt = $false
    $stats = [pscustomobject]@{ Lines = $lines.Count; Sentences = 0; Hits = 0; Topics = 0 }
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $ln = $lines[$i]
        if (-not $ln.Trim()) { continue }
        $channel = 'body'
        if ($ln -match '^=== FIGURE ALT TEXT ===') { $inAlt = $true; $topic = 'back'; continue }
        if ($inAlt) { $channel = 'alt'; $ln = $ln -replace '^\*\s*', '' }
        elseif ($ln -notmatch 'PAGEREF') {
            $th = [regex]::Match($ln, '^Topic (\d+) - .+')
            if ($th.Success) { $topic = $th.Groups[1].Value; $sub = '-'; $channel = 'heading'; $stats.Topics++ }
            elseif ($topic -ne 'front' -and $topic -ne 'back' -and $ln -match '^(Appendix \d+\b|Appendices\b|Glossary\b)') { $topic = 'back'; $sub = '-'; $channel = 'heading' }
            else {
                $sh = [regex]::Match($ln, '^(\d+\.\d+)\s{2,}\S')
                if ($sh.Success) { $sub = $sh.Groups[1].Value; $channel = 'heading' }
                elseif ($ln -match '^Figure \d+\.\d+\.\d+\s+-') { $channel = 'caption' }
            }
        }
        foreach ($s in (Split-Sentence -Line $ln)) {
            $stats.Sentences++
            $loc = ("G:L{0} T{1}/{2} {3}" -f ($i + 1), $topic, $sub, $channel)
            if (Add-ClaimSentence -Store $Store -Index $Index -Sentence $s -Artefact 'guide' -Locator $loc -TopicLabel $topic -PatternSet $PatternSet) { $stats.Hits++ }
        }
    }
    return $stats
}

function Read-DeckClaims {
    param([string] $Text, $Store, $Index, $PatternSet, $Plan)
    $lines = @($Text -split "`r?`n")
    $slide = 0; $topic = 'shared'; $inNotes = $false
    $stats = [pscustomobject]@{ Lines = $lines.Count; Sentences = 0; Hits = 0; Slides = 0; PlanMismatch = $false }
    foreach ($ln in $lines) {
        if (-not $ln.Trim()) { continue }
        $m = [regex]::Match($ln, '^=== SLIDE (\d+) ===\s*$')
        if ($m.Success) {
            $slide = [int]$m.Groups[1].Value; $inNotes = $false; $topic = 'shared'; $stats.Slides++
            if ($null -ne $Plan -and $Plan.Count -ge $slide) {
                $e = $Plan[$slide - 1]
                if ($null -ne $e -and @($e.PSObject.Properties.Name) -contains 'Topic' -and $null -ne $e.Topic -and "$($e.Topic)" -ne '') { $topic = "$($e.Topic)" }
            }
            elseif ($null -ne $Plan) { $stats.PlanMismatch = $true }
            continue
        }
        if ($ln -match '^--- notes ---') { $inNotes = $true; continue }
        if ($ln -match '^\d+\s*$') { continue }        # the printed slide number
        $channel = if ($inNotes) { 'notes' } elseif ($ln -match '^Prepares you for:') { 'chip' } else { 'body' }
        foreach ($s in (Split-Sentence -Line $ln)) {
            $stats.Sentences++
            $loc = ("D:S{0} T{1} {2}" -f $slide, $topic, $channel)
            if (Add-ClaimSentence -Store $Store -Index $Index -Sentence $s -Artefact 'deck' -Locator $loc -TopicLabel $topic -PatternSet $PatternSet) { $stats.Hits++ }
        }
    }
    return $stats
}

# ---------------------------------------------------------------------------
# 3. The run
# ---------------------------------------------------------------------------

function Invoke-ClaimsDigest {
    param(
        [Parameter(Mandatory)][string] $GuidePath,
        [Parameter(Mandatory)][string] $DeckPath,
        [string] $ContractPath,
        [string] $PlanPath,
        [Parameter(Mandatory)][string] $OutPath,
        [int] $MaxLocations,
        [switch] $FullTermSentences,
        [string[]] $Categories,
        [switch] $Quiet
    )

    $contractObj = $null
    if ($ContractPath -and (Test-Path -LiteralPath $ContractPath)) { $contractObj = Get-GateJson -Path $ContractPath }
    $plan = $null
    if ($PlanPath -and (Test-Path -LiteralPath $PlanPath)) { $plan = @(Get-GateJson -Path $PlanPath) }

    $ps = New-ClaimPatternSet -ContractObj $contractObj
    $store = @{}
    $index = @{}
    $gs = Read-GuideClaims -Text (Get-GateFileText -Path $GuidePath) -Store $store -Index $index -PatternSet $ps
    $ds = Read-DeckClaims -Text (Get-GateFileText -Path $DeckPath) -Store $store -Index $index -PatternSet $ps -Plan $plan

    # --- counts per category: distinct sentences, occurrences, distinct values
    $counts = [ordered]@{}
    foreach ($cat in $ps.Patterns.Keys) {
        $ents = @($store.Values | Where-Object { $_.Categories -contains $cat })
        $occ = 0; foreach ($e in $ents) { $occ += $e.Count }
        $dv = if ($index.ContainsKey($cat)) { $index[$cat].Count } else { 0 }
        $counts[$cat] = [pscustomobject]@{ Sentences = $ents.Count; Occurrences = $occ; Values = $dv }
    }
    $totalOcc = 0; foreach ($e in $store.Values) { $totalOcc += $e.Count }

    # --- write
    $o = New-Object System.Collections.Generic.List[string]
    $o.Add('CLAIMS DIGEST - every sentence in the guide and the deck that carries a checkable claim')
    $o.Add(("GENERATED: {0}" -f (Get-Date).ToUniversalTime().ToString('o')))
    $o.Add(("GUIDE: {0} ({1} lines, {2} sentences read, {3} with a claim)" -f $GuidePath, $gs.Lines, $gs.Sentences, $gs.Hits))
    $o.Add(("DECK: {0} ({1} slides, {2} sentences read, {3} with a claim{4})" -f $DeckPath, $ds.Slides, $ds.Sentences, $ds.Hits, $(if ($null -eq $plan) { '; no deckplan.json, so every slide is T-shared' } elseif ($ds.PlanMismatch) { '; WARNING deckplan.json has fewer entries than the deck has slides' } else { '' })))
    $o.Add(("CONTRACT: {0}" -f $(if ($null -ne $contractObj) { $ContractPath } else { 'none supplied' })))
    foreach ($n in $ps.Notes) { $o.Add(("  {0}" -f $n)) }
    if ($ps.Terms.Count) { $o.Add(("  locked terms: {0}" -f ($ps.Terms -join ' | '))) }
    if ($ps.Variants.Count) { $o.Add(("  forbidden variants: {0}" -f ($ps.Variants -join ' | '))) }
    $allCats = @($ps.Patterns.Keys)
    $filter = @()
    if ($null -ne $Categories -and $Categories.Count -gt 0) {
        $filter = @($Categories | ForEach-Object { "$_".Trim().ToLowerInvariant() } | Where-Object { $_ })
        $bad = @($filter | Where-Object { $allCats -notcontains $_ })
        if ($bad.Count -gt 0) { throw ("-Categories names {0}, which is not one of {1}" -f ($bad -join ', '), ($allCats -join ', ')) }
    }
    $inFilter = { param($e) if ($filter.Count -eq 0) { return $true }; foreach ($c in $e.Categories) { if ($filter -contains $c) { return $true } }; return $false }
    $termOnlyDropped = 0; $filteredOut = 0; $printed = 0
    foreach ($e in $store.Values) {
        $termOnly = ($e.Categories.Count -eq 1 -and $e.Categories[0] -eq 'term')
        if ($termOnly -and -not $FullTermSentences) { $termOnlyDropped++; continue }
        if (-not (& $inFilter $e)) { $filteredOut++; continue }
        $printed++
    }
    $o.Add(("DEDUPE: {0} distinct sentence(s) from {1} occurrence(s); exact repeats are collapsed and counted" -f $store.Count, $totalOcc))
    if ($filter.Count -gt 0) { $o.Add(("CATEGORY FILTER: {0} - Part A and Part B carry only these; {1} claim-bearing sentence(s) with none of them are not in this digest (term-only sentences are counted separately below)" -f ($filter -join ', '), $filteredOut)) }
    else { $o.Add('CATEGORY FILTER: none - every category is in this digest') }
    if ($FullTermSentences) { $o.Add('TERM-ONLY SENTENCES DROPPED FROM PART B: 0 (-FullTermSentences: every sentence is printed in full)') }
    else { $o.Add(("TERM-ONLY SENTENCES DROPPED FROM PART B: {0} - a sentence whose only claim is a correctly used locked term carries no value to compare; Part A still counts every term per topic and artefact, and every forbidden variant is printed in full" -f $termOnlyDropped)) }
    $o.Add(("PART B SENTENCES PRINTED: {0}" -f $printed))
    $o.Add('CATEGORIES (distinct sentences / occurrences / distinct values):')
    foreach ($cat in $counts.Keys) { $o.Add(("  {0,-9} {1,6} / {2,6} / {3,6}" -f $cat, $counts[$cat].Sentences, $counts[$cat].Occurrences, $counts[$cat].Values)) }
    $o.Add('')
    $o.Add('Read this as a TRANSCRIPT. It claims nothing is correct and decides nothing. A value that')
    $o.Add('appears in one place is not wrong for being alone, and a value that appears in seventy is')
    $o.Add('not right for being repeated. Whether two places agree is the reviewer''s call.')
    $o.Add('')
    $o.Add('LOCATORS: G:L<line> T<topic>/<sub> <channel>  = guide, FULL-extract line, topic (front|N|back), N.N sub-section, channel body|heading|caption|alt')
    $o.Add('          D:S<slide> T<topic> <channel>       = deck, slide number, topic from deckplan.json (or shared), channel body|chip|notes')
    $o.Add('')
    $o.Add('==== PART A - VALUES INDEX: each distinct matched value, and where it occurs ====')
    $o.Add('[category] value  guide:count (topics)  deck:count (topics)  first: locator')
    foreach ($cat in $ps.Patterns.Keys) {
        if (-not $index.ContainsKey($cat)) { continue }
        if ($filter.Count -gt 0 -and $filter -notcontains $cat) { continue }
        $o.Add('')
        $o.Add(("-- {0} ({1} distinct) --" -f $cat, $index[$cat].Count))
        foreach ($vk in ($index[$cat].Keys | Sort-Object { -($index[$cat][$_].Guide + $index[$cat][$_].Deck) }, { $_ })) {
            $ix = $index[$cat][$vk]
            $o.Add(("[{0}] {1}  guide:{2} ({3})  deck:{4} ({5})  first: {6}" -f $cat, $vk, $ix.Guide, $(if ($ix.GuideTopics.Count) { ($ix.GuideTopics | ForEach-Object { 'T' + $_ }) -join ',' } else { '-' }), $ix.Deck, $(if ($ix.DeckTopics.Count) { ($ix.DeckTopics | ForEach-Object { 'T' + $_ }) -join ',' } else { '-' }), $ix.First))
        }
    }
    $o.Add('')
    $o.Add('==== PART B - SENTENCES: in document order, exact repeats collapsed ====')
    $o.Add('x<count> [categories] <locations>')
    $o.Add('    <sentence, verbatim>')
    $o.Add('')
    $termOnlyCount = $termOnlyDropped
    foreach ($e in ($store.Values | Sort-Object Order)) {
        $termOnly = ($e.Categories.Count -eq 1 -and $e.Categories[0] -eq 'term')
        if ($termOnly -and -not $FullTermSentences) { continue }
        if (-not (& $inFilter $e)) { continue }
        $locs = @($e.Locations)
        $shown = if ($locs.Count -gt $MaxLocations) { (@($locs[0..($MaxLocations - 1)]) -join '; ') + ("; +{0} more" -f ($locs.Count - $MaxLocations)) } else { $locs -join '; ' }
        $o.Add(("x{0} [{1}] {2}" -f $e.Count, ($e.Categories -join ','), $shown))
        $o.Add(("    {0}" -f $e.Text))
    }

    $dir = Split-Path -Parent $OutPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Write-Utf8File -Path $OutPath -Content (($o -join "`r`n") + "`r`n")

    if (-not $Quiet) {
        Write-Host ''
        Write-Host "$GATE" -ForegroundColor Cyan
        Write-Host ("  guide: {0}" -f $GuidePath) -ForegroundColor DarkGray
        Write-Host ("  deck:  {0}" -f $DeckPath) -ForegroundColor DarkGray
        foreach ($n in $ps.Notes) { Write-Host ("  {0}" -f $n) -ForegroundColor DarkGray }
        Write-GateCheckSet -What 'locked term(s)' -Count $ps.Terms.Count -DerivedFrom 'contract.json terminology (keys, leading forms and introduced abbreviations)'
        Write-GateCheckSet -What 'forbidden variant(s)' -Count $ps.Variants.Count -DerivedFrom 'the "never ..." clauses of contract.json terminology'
        Write-Host ("  {0,-9} {1,10} {2,12} {3,10}" -f 'category', 'sentences', 'occurrences', 'values') -ForegroundColor Cyan
        foreach ($cat in $counts.Keys) { Write-Host ("  {0,-9} {1,10} {2,12} {3,10}" -f $cat, $counts[$cat].Sentences, $counts[$cat].Occurrences, $counts[$cat].Values) }
        if ($filter.Count -gt 0) { Write-Host ("  category filter: {0} ({1} sentence(s) excluded)" -f ($filter -join ', '), $filteredOut) -ForegroundColor DarkGray }
        Write-Host ("  {0} distinct sentence(s) from {1} occurrence(s); {2} term-only dropped from Part B; {3} printed -> {4}" -f $store.Count, $totalOcc, $termOnlyCount, $printed, $OutPath) -ForegroundColor Green
    }

    return [pscustomobject]@{ ExitCode = 0; Counts = $counts; Distinct = $store.Count; Occurrences = $totalOcc; TermOnly = $termOnlyCount; FilteredOut = $filteredOut; Printed = $printed; OutPath = $OutPath; Guide = $gs; Deck = $ds; PatternSet = $ps }
}

# ---------------------------------------------------------------------------
# 4. Self-test
# ---------------------------------------------------------------------------

function Invoke-ClaimsDigestSelfTest {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("claimsdigest-selftest-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    $fails = New-Object System.Collections.Generic.List[string]
    function Assert-True { param([bool] $Cond, [string] $What) if ($Cond) { Write-Host ("  PASS  {0}" -f $What) -ForegroundColor Green } else { Write-Host ("  FAIL  {0}" -f $What) -ForegroundColor Red; $fails.Add($What) } }

    try {
        $guide = @(
            '', 'LEARNER GUIDE',
            'Topic 1 - Alpha PAGEREF _Toc1 \h 5',
            'Knowledge Task 3(a) is prepared in 1.1',
            'Topic 1 - Alpha',
            '1.1  First thing',
            'Hold at 4 degrees C for 2 hours. This sentence carries nothing.',
            'Hold at 4 degrees C for 2 hours.',
            'Figure 1.1.1 - Chill to 3 degrees C',
            'Cook-chill food is never left to cool down on the bench.',
            'Weigh 350 g of flour.',
            'Apply first in-first out (FIFO) on the shelf.',
            'Topic 2 - Beta',
            '2.1  Second thing',
            'Freeze at minus 18 degrees C under Standard 3.2.2 clause 7 of the Food Act 2001.',
            'The ACI house standard is stricter than the Food Standards Code.',
            'Deliver on Thursday at 12 noon for the week ending 15 March 2026.',
            'Appendix 1 - Legislation',
            'Regulations 2017 apply.',
            '=== FIGURE ALT TEXT ===',
            '* A tray at 0 to 3 degrees C on a shelf.'
        )
        $deck = @(
            '=== SLIDE 1 ===', 'TITLE', '1', '',
            '=== SLIDE 2 ===', 'TOPIC 1', 'Hold at 4 degrees C for 2 hours.', '2', '', 'Prepares you for: Knowledge Task 3(a)', '--- notes ---', 'The venue has adopted 4 degrees C; the Code allows 5 degrees C.', '', '2', '',
            '=== SLIDE 3 ===', 'BRIEFING', 'Ten portions of 350 Gms.', '3', ''
        )
        $plan = @([ordered]@{ Tag = 'title' }, [ordered]@{ Topic = 1; Tag = 'T1' }, [ordered]@{ Tag = 'briefing' })
        $contract = [ordered]@{
            terminology = [ordered]@{ '_rule' = 'x'; 'cook-chill' = 'cook-chill (hyphenated)'; 'chill' = "chill (bring down); never 'cool down' or 'refrigerate' as a synonym"; 'grams' = 'Gms - ACI initial-caps the recipe unit; never g, G or gms'; 'FIFO' = 'first in-first out (FIFO) - expanded at first use'; 'the learner' = 'you' }
            referenceConvention = [ordered]@{ questionPattern = '\b(?:Knowledge Task|Workbook Task|Observation)\s?(\d+)\s?(\([a-z]\))?' }
        }
        $gp = Join-Path $root 'guide.txt'; $dp = Join-Path $root 'deck.txt'; $cp = Join-Path $root 'contract.json'; $pp = Join-Path $root 'deckplan.json'; $op = Join-Path $root 'digest.txt'
        Write-Utf8File -Path $gp -Content (($guide -join "`r`n") + "`r`n")
        Write-Utf8File -Path $dp -Content (($deck -join "`r`n") + "`r`n")
        Write-Utf8File -Path $cp -Content (($contract | ConvertTo-Json -Depth 6) + "`r`n")
        Write-Utf8File -Path $pp -Content (($plan | ConvertTo-Json -Depth 4) + "`r`n")

        Write-Host ''
        Write-Host "$GATE self-test - synthetic extracts at $root" -ForegroundColor Cyan
        $r = Invoke-ClaimsDigest -GuidePath $gp -DeckPath $dp -ContractPath $cp -PlanPath $pp -OutPath $op -MaxLocations 12 -Quiet
        $t = Get-GateFileText -Path $op
        Assert-True ($r.ExitCode -eq 0 -and $t.Length -gt 0) 'digest written'
        Assert-True ($t -match '(?m)^x3 \[num\] G:L7 T1/1\.1 body; G:L8 T1/1\.1 body; D:S2 T1 body') 'exact repeats are collapsed to one line with a count and every location (guide x2 + deck x1)'
        Assert-True (-not $t.Contains('This sentence carries nothing')) 'a sentence with no claim is not in the digest'
        Assert-True ($t -match '(?m)^\[num\] minus 18 degrees c ') 'minus values are indexed as values'
        Assert-True ($t -match '(?m)^\[num\] 0 to 3 degrees c ') 'ranges are indexed as one value'
        Assert-True ($t -match '(?m)^\[instr\] standard 3\.2\.2 ' -and $t -match '(?m)^\[instr\] clause 7 ' -and $t -match '(?m)^\[instr\] food act 2001 ' -and $t -match '(?m)^\[instr\] regulations 2017 ') 'instrument citations are indexed: Standard, clause, a named Act with a year, Regulations with a year'
        Assert-True ($t -match '(?m)^\[question\] knowledge task 3\(a\) .*guide:1 \(Tfront\)  deck:1 \(T1\)') 'question references are indexed by the contract pattern, with locations in the front matter and on the slide chip'
        Assert-True ($t -match '(?m)^\[clock\] thursday ' -and $t -match '(?m)^\[clock\] 12 noon ' -and $t -match '(?m)^\[clock\] 15 march 2026 ') 'scenario days, times and dates are indexed'
        Assert-True ($t -match '(?m)^\[term\] cook-chill ') 'a locked term from the contract is indexed'
        Assert-True ($t -match '(?m)^\[variant\] cool down ') 'a forbidden variant from the contract "never" clause is indexed'
        Assert-True ($t -match '(?m)^\[variant\] g  guide:1') 'a one-letter forbidden variant is caught only after a numeral'
        Assert-True ($t -match '(?m)^\[term\] fifo ') 'an introduced abbreviation is a term'
        Assert-True (-not ($t -match '(?m)^\[term\] you ')) 'a three-letter lower-case lead ("you") is not a term'
        Assert-True ($t -match '(?m)^\[attrib\] adopted ' -and $t -match '(?m)^\[attrib\] stricter than ' -and $t -match '(?m)^\[attrib\] the code allows ') 'adoption and attribution language is indexed'
        Assert-True ($t -match 'D:S2 T1 notes') 'a speaker note carries the notes channel and the topic from deckplan.json'
        Assert-True ($t -match 'D:S2 T1 chip') 'a chip line carries the chip channel'
        Assert-True ($t -match 'D:S3 Tshared body') 'a slide with no Topic in the plan is T-shared'
        Assert-True ($t -match 'G:L9 T1/1\.1 caption') 'a Figure caption carries the caption channel'
        Assert-True ($t -match 'G:L21 Tback/- alt') 'an alt-text line carries the alt channel and Tback'
        Assert-True ($t -match 'G:L19 Tback/- body') 'a line after Appendix 1 is Tback'
        Assert-True ((-not $t.Contains('Apply first in-first out (FIFO) on the shelf.')) -and ($t -match 'TERM-ONLY SENTENCES DROPPED FROM PART B: 1 ')) 'a term-only sentence is dropped from Part B and counted in the header'
        Assert-True ($t -match '(?m)^\[term\] first in-first out ') 'and Part A still indexes the term it carried'
        $rc = Invoke-ClaimsDigest -GuidePath $gp -DeckPath $dp -ContractPath $cp -PlanPath $pp -OutPath (Join-Path $root 'digest-values.txt') -MaxLocations 12 -Categories @('num', 'clock') -Quiet
        $tc = Get-GateFileText -Path (Join-Path $root 'digest-values.txt')
        Assert-True ($tc.Contains('CATEGORY FILTER: num, clock') -and $tc.Contains('-- num (') -and -not $tc.Contains('-- instr (') -and -not $tc.Contains('Regulations 2017 apply.') -and $tc.Contains('Freeze at minus 18 degrees C')) '-Categories num,clock keeps value sentences and drops a citation-only sentence and the citation index'
        Assert-True ($rc.FilteredOut -ge 1 -and $tc -match ('with none of them are not in this digest')) 'the filter reports how many sentences it excluded'
        $threw = $false
        try { Invoke-ClaimsDigest -GuidePath $gp -DeckPath $dp -OutPath (Join-Path $root 'digest-bad.txt') -MaxLocations 12 -Categories @('numbers') -Quiet | Out-Null } catch { $threw = $true }
        Assert-True $threw 'an unknown category name is refused'
        Assert-True ((-not ($t -match '(?m)^\[variant\] gms ')) -and ($t -match '(?m)^\[term\] gms ')) 'a locked term is not reported as its own case variant (Gms is not gms)'
        Assert-True (-not ($t -match '(?m)^\[term\] learner ')) 'a key that starts with "the" keeps it, so "Learner Guide" is not a term hit'
        $rf = Invoke-ClaimsDigest -GuidePath $gp -DeckPath $dp -ContractPath $cp -PlanPath $pp -OutPath (Join-Path $root 'digest-full.txt') -MaxLocations 12 -FullTermSentences -Quiet
        Assert-True ((Get-GateFileText -Path (Join-Path $root 'digest-full.txt')).Contains('    Apply first in-first out (FIFO) on the shelf.')) '-FullTermSentences prints the term-only sentence in full'
        Assert-True ($r.Counts['num'].Sentences -ge 6 -and $r.Counts['question'].Sentences -eq 2) ("category counts are reported (num sentences {0}, question sentences {1})" -f $r.Counts['num'].Sentences, $r.Counts['question'].Sentences)

        $r2 = Invoke-ClaimsDigest -GuidePath $gp -DeckPath $dp -OutPath (Join-Path $root 'digest2.txt') -MaxLocations 12 -Quiet
        $t2 = Get-GateFileText -Path (Join-Path $root 'digest2.txt')
        Assert-True ($t2.Contains('terms: NONE') -and $t2.Contains('question pattern: DEFAULT')) 'without a contract the digest says so instead of inventing a term list'
    }
    finally {
        if ($root -and (Test-Path -LiteralPath $root) -and $root.Length -gt 12) { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    Write-Host ''
    if ($fails.Count -gt 0) { Write-Host ("  X self-test: {0} assertion(s) failed" -f $fails.Count) -ForegroundColor Red; return 4 }
    Write-Host '  self-test: every assertion held.' -ForegroundColor Green
    return 0
}

# ---------------------------------------------------------------------------
# Entry
# ---------------------------------------------------------------------------

if ($SelfTest) { exit (Invoke-ClaimsDigestSelfTest) }

$guidePath = Resolve-DigestInput -BuildDir $BuildDir -Given $GuideExtract -Stem 'guide'
$deckPath = Resolve-DigestInput -BuildDir $BuildDir -Given $DeckExtract -Stem 'deck'
if (-not $guidePath -or -not (Test-Path -LiteralPath $guidePath) -or -not $deckPath -or -not (Test-Path -LiteralPath $deckPath)) {
    Write-Host "$GATE`: usage: Get-ClaimsDigest.ps1 -BuildDir <build> [-GuideExtract <txt>] [-DeckExtract <txt>] [-Contract <json>] [-DeckPlan <json>] -OutPath <file> | -SelfTest" -ForegroundColor Red
    Write-Host ("  guide: {0}" -f $(if ($guidePath) { $guidePath } else { 'NOT FOUND (cleanroom\guide_r*.txt or guide_gate.txt)' })) -ForegroundColor Red
    Write-Host ("  deck:  {0}" -f $(if ($deckPath) { $deckPath } else { 'NOT FOUND (cleanroom\deck_r*.txt or deck_gate.txt)' })) -ForegroundColor Red
    exit 2
}
if (-not $Contract -and $BuildDir) { $c = Join-Path $BuildDir 'contract.json'; if (Test-Path -LiteralPath $c) { $Contract = $c } }
if (-not $DeckPlan -and $BuildDir) { $d = Join-Path $BuildDir 'deckplan.json'; if (Test-Path -LiteralPath $d) { $DeckPlan = $d } }
if (-not $OutPath) {
    if (-not $BuildDir) { Write-Host "$GATE`: -OutPath is required when -BuildDir is not given" -ForegroundColor Red; exit 2 }
    $OutPath = Join-Path $BuildDir 'cleanroom\claims-digest.txt'
}

try {
    $run = Invoke-ClaimsDigest -GuidePath $guidePath -DeckPath $deckPath -ContractPath $Contract -PlanPath $DeckPlan -OutPath $OutPath -MaxLocations $MaxLocations -FullTermSentences:$FullTermSentences -Categories $Categories -Quiet:$Quiet
}
catch { Write-Host ("{0}: {1}" -f $GATE, $_.Exception.Message) -ForegroundColor Red; exit 2 }
exit $run.ExitCode
