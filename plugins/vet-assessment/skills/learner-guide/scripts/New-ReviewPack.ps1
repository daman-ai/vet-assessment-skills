<#
    New-ReviewPack.ps1 - cut ONE review pack per topic, plus the cross-document
    pack(s), from a finished build's clean-room extracts.

        & "$SkillDir\scripts\New-ReviewPack.ps1" -BuildDir $out -OutDir $out\cleanroom\review

    WHY THE AUDIT IS SPLIT. The single clean-room reviewer's input - the guide
    extract (about 900 KB), the deck extract (about 210 KB), the pack (about
    540 KB), the checklist and the evidence - is roughly 350K tokens, beyond
    one context window. So "one reviewer with everything" was always a hidden
    chain of partial reads: whatever the reader happened to hold when it
    judged was the review, which is exactly why six rounds on one build each
    found a different defect class, and why each round took 35 to 42 minutes.
    Reviewers who cannot see each other are harder to anchor than one, every
    one of them reads the whole of its input, and the wave clock becomes the
    slowest agent.

    WHY A TOPIC REVIEWER DOES NOT GET THE WHOLE PACK. The first cut of this
    script handed every reviewer every pack extract, on the argument that a
    Topic 3 answer grid can be mirrored in Topic 5. Measured on the reference
    build, the four extracts alone were 135K tokens, so the material every
    reviewer shared came to 165K tokens before a line of its own topic, and
    no topic split could bring any pack under budget. The argument was also
    wrong about who does that job: cross-topic mirroring is found
    mechanically by the mirror gate over the whole spine, not by a reader
    holding forty benchmarks it will never use. So, by default, a topic
    reviewer holds:
      the two LEARNER-facing tools in full - they are what the learner
        holds, and every cross-reference target must resolve in them;
      from each ASSESSOR guide, only the regions for the tasks its topic
        prepares - which contract.json's questionMap already assigns per
        sub-section - cut at the document's own task headings, each region
        bannered with its heading and source line range. A region is the
        text between two headings, where the headings are the body lines
        that equal a Contents entry (the extract's PAGEREF lines), so the
        benchmarks under a task travel with it and an observation checklist
        that is its own section is picked up by its own heading;
      its slice of the guide (with the shared front and back matter), its
        slides (with the shared orientation and briefing slides), its
        figure-sheet slots, the independent unit extract, the Stage 3d
        allow-list, and a SCOPE.md.
    -FullPack keeps the everything-to-everyone mode for a small unit.

    THE CROSS-DOCUMENT PACK holds the learner tools only (its job is
    guide-versus-deck-versus-pack agreement, and the assessor guides are not
    learner-held), the claims digest with term-only sentences dropped and
    counted, the full figure sheet, figures.json, the unit extract and the
    allow-list. Where that would still exceed the budget, the cutter splits
    it into crossdoc-values (numbers, temperatures, quantities, the scenario
    clock, adoption language) and crossdoc-refs (instrument citations,
    locked terms and their variants, question references, adoption
    language), each with its own SCOPE.md and its own filtered digest, and
    manifest.json tells the merger to expect both.

    THE BUDGET IS A GATE, NOT A NOTE. Every pack's size is printed in KB and
    as an estimated token count (chars / 4), split into what every reviewer
    shares and what is the pack's own, and the run FAILS when any pack
    exceeds -MaxTokens. A reader handed more than it can hold truncates
    silently and reports on what it kept - the defect this split exists to
    end - so an over-large pack is split on purpose, or the budget raised on
    purpose, and never trimmed by the reader.

    NOTHING HERE IS SUMMARISED. Every file is a verbatim slice or a copy.
    Slide numbers, figure slot numbers, sub-section numbers, task headings
    and figure captions survive the cut unchanged; guide and assessor line
    numbers do not, so every slice states the source line range it was cut
    from, and the SCOPE.md tells the reviewer to anchor by heading and
    quoted phrase.

    NO unit code, brand or build path is hard-coded. Every input is resolved
    from -BuildDir, overridable by parameter, and printed. Structure is read
    from the artefacts themselves: topic headings from the guide extract,
    slide-to-topic from deckplan.json, slot-to-topic from the figure sheet,
    task-to-topic from the contract's questionMap, reference kinds and their
    documents from the contract's referenceConvention, learner-versus-
    assessor from the same classifier the gates use (Get-GateCorpusDocs). A
    mismatch between them is a FAIL, because a slide or a task assigned to
    no pack is one nobody reviews.

    TRUSTED ONLY AFTER PASSING ON A SYNTHETIC BUILD. -SelfTest builds a tiny
    two-topic build in a temp directory, cuts it in every mode, and asserts
    every rule above - including that the budget gate fires, that the
    structural mismatches are refused, and that a build with no questionMap
    is refused in the default mode and pointed at -FullPack.

    PS 5.1. ASCII only in this file. Lists are returned with .ToArray(),
    never wrapped in @(): @($list) on a List[object] throws "Argument types
    do not match" from the engine's array binder on this PowerShell.
    Exit 0 written within budget, 1 a pack exceeds the budget, 2 a usage or
    structure error, 4 the self-test failed.
#>

[CmdletBinding()]
param(
    [string] $BuildDir,
    [string] $OutDir,
    #  Overrides. Every one defaults from -BuildDir and the resolution is printed.
    [string] $GuideExtract,
    [string] $DeckExtract,
    [string] $PackDir,
    #  Which pack extracts are considered at all. Default: every .txt.
    [string[]] $PackInclude = @('*.txt'),
    [string] $FigureSheet,
    [string] $DeckPlan,
    [string] $UnitExtract,
    [string] $FiguresJson,
    [string] $Contract,
    #  Hand every reviewer every pack extract whole. For a small unit only;
    #  the default hands a topic reviewer the learner tools whole and the
    #  assessor guides sliced to the tasks its topic prepares.
    [switch] $FullPack,
    #  Auto: one crossdoc pack, split into crossdoc-values and crossdoc-refs
    #  only if the single pack exceeds the budget. Always / Never force it.
    [ValidateSet('Auto', 'Always', 'Never')][string] $CrossdocSplit = 'Auto',
    [int] $MaxTokens = 180000,
    [switch] $SelfTest,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

$GATE = 'REVIEW PACK'
$script:ValuesCategories = @('num', 'clock', 'attrib')
$script:RefsCategories = @('instr', 'term', 'variant', 'question', 'attrib')

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

function Write-Utf8File {
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][AllowEmptyString()][string] $Content)
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($true)))
}

function Join-TextLines {
    param([AllowEmptyCollection()][string[]] $Lines)
    if ($null -eq $Lines -or $Lines.Count -eq 0) { return '' }
    return (($Lines -join "`r`n") + "`r`n")
}

function Format-NumberList {
    <# 1,2,3,5,6 -> "1-3, 5-6" so a SCOPE.md stays readable for 30 slides. #>
    param([int[]] $Numbers)
    $n = @($Numbers | Sort-Object -Unique)
    if ($n.Count -eq 0) { return '(none)' }
    $parts = New-Object System.Collections.Generic.List[string]
    $start = $n[0]; $prev = $n[0]
    for ($i = 1; $i -le $n.Count; $i++) {
        $cur = if ($i -lt $n.Count) { $n[$i] } else { $null }
        if ($null -ne $cur -and $cur -eq ($prev + 1)) { $prev = $cur; continue }
        if ($start -eq $prev) { $parts.Add("$start") } else { $parts.Add(("{0}-{1}" -f $start, $prev)) }
        if ($null -ne $cur) { $start = $cur; $prev = $cur }
    }
    return ($parts -join ', ')
}

function New-EmptyDir {
    param([string] $Dir)
    if (-not (Test-Path -LiteralPath $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }
    else { Get-ChildItem -LiteralPath $Dir -File | Remove-Item -Force }
}

# ---------------------------------------------------------------------------
# 1. Resolve every input from the build, or from an override, and say which
# ---------------------------------------------------------------------------

function Resolve-ReviewInput {
    param([string] $BuildDir, [hashtable] $Given)

    $paths = [ordered]@{}
    $how = New-Object System.Collections.Generic.List[string]
    $cleanroom = Join-Path $BuildDir 'cleanroom'

    foreach ($stem in @('guide', 'deck')) {
        $key = $stem + 'Extract'
        if ($Given[$key]) { $paths[$key] = $Given[$key]; $how.Add(("{0}: {1} (given)" -f $key, $Given[$key])); continue }
        $pick = $null
        if (Test-Path -LiteralPath $cleanroom) {
            $cands = @(Get-ChildItem -LiteralPath $cleanroom -File | Where-Object { $_.Name -match ('^' + $stem + '_r(\d+)\.txt$') } |
                       Sort-Object { [int]([regex]::Match($_.Name, '_r(\d+)\.txt$').Groups[1].Value) } -Descending)
            if ($cands.Count -gt 0) {
                $pick = $cands[0].FullName
                $how.Add(("{0}: {1} (newest of {2} round extract(s) in cleanroom)" -f $key, $pick, $cands.Count))
            }
        }
        if (-not $pick) {
            $g = Join-Path $BuildDir ($stem + '_gate.txt')
            if (Test-Path -LiteralPath $g) { $pick = $g; $how.Add(("{0}: {1} (no cleanroom round extract; using the gate extract)" -f $key, $g)) }
        }
        if (-not $pick) { $how.Add(("{0}: NOT FOUND - looked for cleanroom\{1}_r*.txt and {1}_gate.txt" -f $key, $stem)) }
        $paths[$key] = $pick
    }

    if ($Given['packDir']) { $paths['packDir'] = $Given['packDir']; $how.Add(("packDir: {0} (given)" -f $Given['packDir'])) }
    else {
        $pick = $null
        foreach ($cand in @((Join-Path $cleanroom 'pack'), (Join-Path $BuildDir 'packtext'))) {
            if (Test-Path -LiteralPath $cand) { $pick = $cand; break }
        }
        $paths['packDir'] = $pick
        if ($pick) { $how.Add(("packDir: {0}" -f $pick)) } else { $how.Add('packDir: NOT FOUND - looked for cleanroom\pack and packtext') }
    }

    foreach ($pair in @(@('figureSheet', 'figure-sheet.txt'), @('deckPlan', 'deckplan.json'), @('unitExtract', 'unit_extract.md'), @('figuresJson', 'figures.json'), @('contract', 'contract.json'))) {
        $key = $pair[0]; $leaf = $pair[1]
        if ($Given[$key]) { $paths[$key] = $Given[$key]; $how.Add(("{0}: {1} (given)" -f $key, $Given[$key])); continue }
        $cand = Join-Path $BuildDir $leaf
        if (Test-Path -LiteralPath $cand) { $paths[$key] = $cand; $how.Add(("{0}: {1}" -f $key, $cand)) }
        else { $paths[$key] = $null; $how.Add(("{0}: not present ({1})" -f $key, $cand)) }
    }

    return [pscustomobject]@{ Paths = $paths; How = $how }
}

# ---------------------------------------------------------------------------
# 2. Read the structure out of the artefacts themselves
# ---------------------------------------------------------------------------

function Split-GuideExtract {
    <#  Front matter | Topic 1 .. Topic N | back matter, cut at the body's
        "Topic N - Title" heading lines. Contents lines carry PAGEREF and are
        ignored. Back matter starts at the first Appendix/Glossary/=== line
        after the last topic heading; without one, the last topic runs to the
        end and the reason is recorded.  #>
    param([AllowEmptyString()][string] $Text)

    $lines = @($Text -split "`r?`n")
    $heads = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $ln = $lines[$i]
        if ($ln -match 'PAGEREF') { continue }
        $m = [regex]::Match($ln, '^Topic (\d+) - (.+?)\s*$')
        if ($m.Success) { $heads.Add([pscustomobject]@{ Index = $i; Number = [int]$m.Groups[1].Value; Title = $m.Groups[2].Value }) }
    }

    $errors = New-Object System.Collections.Generic.List[string]
    if ($heads.Count -eq 0) {
        $errors.Add('no "Topic N - Title" heading line in the guide extract (Contents lines carrying PAGEREF are ignored). The slicer cannot cut a guide whose topics it cannot see.')
    }
    $seen = @{}
    foreach ($h in $heads) {
        if ($seen.ContainsKey($h.Number)) {
            $errors.Add(("Topic {0} heading appears twice, at lines {1} and {2}. The slicer cannot tell a heading from a prose line that starts the same way, and guessing would put content in the wrong pack." -f $h.Number, ($seen[$h.Number] + 1), ($h.Index + 1)))
        }
        else { $seen[$h.Number] = $h.Index }
    }
    for ($k = 0; $k -lt $heads.Count; $k++) {
        if ($heads[$k].Number -ne ($k + 1)) { $errors.Add(("topic headings are not 1..N in order: heading {0} is Topic {1} (line {2})" -f ($k + 1), $heads[$k].Number, ($heads[$k].Index + 1))); break }
    }
    if ($errors.Count -gt 0) { return [pscustomobject]@{ Ok = $false; Errors = $errors.ToArray() } }

    $first = $heads[0].Index
    $last = $heads[$heads.Count - 1].Index
    $backStart = -1
    $backReason = 'no Appendix, Glossary or === line after the last topic heading: the last topic runs to the end of the extract'
    for ($j = $last + 1; $j -lt $lines.Count; $j++) {
        if ($lines[$j] -match '^(Appendix \d+\b|Appendices\b|Glossary\b|=== )') { $backStart = $j; $backReason = ("line {0}: {1}" -f ($j + 1), $lines[$j].Trim()); break }
    }

    $topics = New-Object System.Collections.Generic.List[object]
    for ($k = 0; $k -lt $heads.Count; $k++) {
        $start = $heads[$k].Index
        $end = if ($k + 1 -lt $heads.Count) { $heads[$k + 1].Index - 1 } elseif ($backStart -ge 0) { $backStart - 1 } else { $lines.Count - 1 }
        $slice = @($lines[$start..$end])
        $subs = New-Object System.Collections.Generic.List[string]
        foreach ($s in $slice) {
            $mm = [regex]::Match($s, '^(\d+\.\d+)\s{2,}\S')
            if ($mm.Success -and $subs -notcontains $mm.Groups[1].Value) { $subs.Add($mm.Groups[1].Value) }
        }
        $topics.Add([pscustomobject]@{
            Number = $heads[$k].Number; Title = $heads[$k].Title
            StartLine = $start + 1; EndLine = $end + 1
            Lines = $slice; SubSections = $subs.ToArray()
        })
    }

    $front = if ($first -gt 0) { @($lines[0..($first - 1)]) } else { @() }
    $back = if ($backStart -ge 0) { @($lines[$backStart..($lines.Count - 1)]) } else { @() }
    return [pscustomobject]@{
        Ok = $true; Errors = @(); LineCount = $lines.Count
        Front = $front; FrontEndLine = $first
        Topics = $topics.ToArray()
        Back = $back; BackStartLine = $(if ($backStart -ge 0) { $backStart + 1 } else { 0 }); BackReason = $backReason
    }
}

function Split-DeckExtract {
    <# One block per "=== SLIDE N ===" marker, notes included; lines before the first marker are a preamble every slice keeps. #>
    param([AllowEmptyString()][string] $Text)

    $lines = @($Text -split "`r?`n")
    $pre = New-Object System.Collections.Generic.List[string]
    $slides = New-Object System.Collections.Generic.List[object]
    $cur = $null
    foreach ($ln in $lines) {
        $m = [regex]::Match($ln, '^=== SLIDE (\d+) ===\s*$')
        if ($m.Success) {
            if ($null -ne $cur) { $slides.Add($cur) }
            $cur = [pscustomobject]@{ Number = [int]$m.Groups[1].Value; Lines = (New-Object System.Collections.Generic.List[string]) }
        }
        if ($null -ne $cur) { $cur.Lines.Add($ln) } else { $pre.Add($ln) }
    }
    if ($null -ne $cur) { $slides.Add($cur) }

    $errors = New-Object System.Collections.Generic.List[string]
    if ($slides.Count -eq 0) { $errors.Add('no "=== SLIDE N ===" marker in the deck extract') }
    for ($k = 0; $k -lt $slides.Count; $k++) {
        if ($slides[$k].Number -ne ($k + 1)) { $errors.Add(("slide markers are not 1..N in order: block {0} is SLIDE {1}" -f ($k + 1), $slides[$k].Number)); break }
    }
    return [pscustomobject]@{ Ok = ($errors.Count -eq 0); Errors = $errors.ToArray(); Preamble = $pre.ToArray(); Slides = $slides.ToArray() }
}

function Split-FigureSheet {
    <# The header before the first separator, then one block per separator; the slot's leading integer is its topic. #>
    param([AllowEmptyString()][string] $Text)

    $lines = @($Text -split "`r?`n")
    $header = New-Object System.Collections.Generic.List[string]
    $blocks = New-Object System.Collections.Generic.List[object]
    $cur = $null
    foreach ($ln in $lines) {
        if ($ln -match '^-{10,}\s*$') {
            if ($null -ne $cur) { $blocks.Add($cur) }
            $cur = [pscustomobject]@{ Slot = ''; Topic = 0; Lines = (New-Object System.Collections.Generic.List[string]) }
            $cur.Lines.Add($ln)
            continue
        }
        if ($null -eq $cur) { $header.Add($ln); continue }
        $cur.Lines.Add($ln)
        if (-not $cur.Slot) {
            $m = [regex]::Match($ln, '^SLOT\s+(\S+)')
            if ($m.Success) {
                $cur.Slot = $m.Groups[1].Value
                $t = [regex]::Match($cur.Slot, '^(\d+)\.')
                if ($t.Success) { $cur.Topic = [int]$t.Groups[1].Value }
            }
        }
    }
    if ($null -ne $cur) { $blocks.Add($cur) }
    return [pscustomobject]@{ Header = $header.ToArray(); Blocks = $blocks.ToArray() }
}

function Get-DocRegions {
    <#  A pack extract cut into regions at its own headings.

        A heading is a body line equal to one of the document's Contents
        entries (the lines carrying PAGEREF), in document order - so the
        regions are exactly the document's own sections, nothing is typed
        here, and a task's benchmarks travel with the task while an
        observation checklist that is its own section is its own region.
        Without a Contents block, every line that starts "Task N" or
        "Observation N" is a heading (the mirror gate's looser rule), and the
        result says so.  #>
    param([AllowEmptyString()][string] $Text)

    $lines = @($Text -split "`r?`n")
    $toc = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    $tocLast = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -notmatch 'PAGEREF') { continue }
        $txt = $lines[$i] -replace '^\s*TOC\s+(?:\\[a-z]\s*(?:"[^"]*"\s*)?)+', ''
        $txt = ($txt -replace '\s+PAGEREF.*$', '').Trim()
        if ($txt) { [void]$toc.Add($txt) }
        $tocLast = $i
    }

    $heads = New-Object System.Collections.Generic.List[object]
    if ($toc.Count -gt 0) {
        for ($i = $tocLast + 1; $i -lt $lines.Count; $i++) {
            $t = $lines[$i].Trim()
            if ($t -and $toc.Contains($t)) { $heads.Add([pscustomobject]@{ Index = $i; Heading = $t }) }
        }
    }
    else {
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^(?i)(Task|Observation)\s*\d+(?!\d)') { $heads.Add([pscustomobject]@{ Index = $i; Heading = $lines[$i].Trim() }) }
        }
    }

    $regions = New-Object System.Collections.Generic.List[object]
    for ($k = 0; $k -lt $heads.Count; $k++) {
        $start = $heads[$k].Index
        $end = if ($k + 1 -lt $heads.Count) { $heads[$k + 1].Index - 1 } else { $lines.Count - 1 }
        $regions.Add([pscustomobject]@{ Heading = $heads[$k].Heading; Start = $start; End = $end; Lines = @($lines[$start..$end]) })
    }
    return [pscustomobject]@{ LineCount = $lines.Count; Regions = $regions.ToArray(); FromToc = ($toc.Count -gt 0); TocEntries = $toc.Count }
}

# ---------------------------------------------------------------------------
# 3. Which task is whose - from the contract, never typed
# ---------------------------------------------------------------------------

function Get-ReferenceKind {
    <#  Every reference kind the contract's referenceConvention declares:
        its prefix ("Knowledge Task"), the heading label it cuts at (the
        prefix's last word), and the learner document it means - named as a
        .docx in <kind>Means, or matched by the tokens of a learner document's
        name appearing in that text.  #>
    param($ContractObj, [object[]] $LearnerDocs)

    $kinds = New-Object System.Collections.Generic.List[object]
    if ($null -eq $ContractObj -or @($ContractObj.PSObject.Properties.Name) -notcontains 'referenceConvention' -or $null -eq $ContractObj.referenceConvention) { return $kinds.ToArray() }
    $rc = $ContractObj.referenceConvention
    $names = @($rc.PSObject.Properties.Name)
    foreach ($p in $rc.PSObject.Properties) {
        if ($p.Name -like '_*' -or $p.Name -like '*Means' -or $p.Name -in @('questionPattern', 'statedInGuideAt')) { continue }
        $template = [string]$p.Value
        if ($template -notmatch '\{n\}') { continue }
        $prefix = ($template -split '\{n\}')[0].Trim()
        if (-not $prefix) { continue }
        $label = @($prefix -split '\s+')[-1]
        $meansName = $p.Name + 'Means'
        $means = if ($names -contains $meansName) { [string]$rc.$meansName } else { '' }
        $stem = $null; $how = 'no ' + $meansName + ' in the contract'
        $m = [regex]::Match($means, '([A-Za-z0-9_\-]+)\.docx')
        if ($m.Success) {
            $stem = $m.Groups[1].Value
            $how = 'named in ' + $meansName
            if (@($LearnerDocs | Where-Object { $_.Name -eq $stem }).Count -eq 0) { $how = ("{0} names {1}.docx, which is not a learner extract in the pack" -f $meansName, $stem); $stem = $null }
        }
        elseif ($means) {
            foreach ($d in $LearnerDocs) {
                $tokens = @(($d.Name -split '_') | Select-Object -Skip 1 | Where-Object { $_ })
                if ($tokens.Count -eq 0) { continue }
                $missing = @($tokens | Where-Object { $means -notmatch ('(?i)\b' + [regex]::Escape($_) + '\b') })
                if ($missing.Count -eq 0) { $stem = $d.Name; $how = ("matched by the name tokens of {0} in {1}" -f $d.Name, $meansName); break }
            }
            if (-not $stem) { $how = ("{0} names no .docx and matches no learner extract by name" -f $meansName) }
        }
        $kinds.Add([pscustomobject]@{ Kind = $p.Name; Prefix = $prefix; Label = $label; DocStem = $stem; How = $how })
    }
    return $kinds.ToArray()
}

function Resolve-TaskReference {
    param([string] $Ref, [object[]] $Kinds)
    foreach ($k in ($Kinds | Sort-Object { -$_.Prefix.Length })) {
        $m = [regex]::Match($Ref.Trim(), '^' + [regex]::Escape($k.Prefix) + '\s*(\d+)')
        if ($m.Success) { return [pscustomobject]@{ Kind = $k.Kind; Number = [int]$m.Groups[1].Value; Label = $k.Label; DocStem = $k.DocStem; Ref = $Ref.Trim() } }
    }
    return $null
}

function New-AssessorSliceText {
    <# The regions of one assessor document that a topic's tasks point at, verbatim, each bannered. #>
    param($Doc, $Regions, [object[]] $Wanted, [int] $TopicNumber, [string] $LearnerStem)

    $picked = New-Object System.Collections.Generic.List[object]
    $missing = New-Object System.Collections.Generic.List[string]
    $refsByStart = @{}
    foreach ($w in ($Wanted | Sort-Object Number)) {
        $rx = '^' + [regex]::Escape($w.Label) + '\s*' + $w.Number + '(?!\d)'
        $hits = @($Regions.Regions | Where-Object { $_.Heading -match $rx })
        if ($hits.Count -eq 0) { $missing.Add(("{0} {1}" -f $w.Label, $w.Number)); continue }
        foreach ($h in $hits) {
            if (-not $refsByStart.ContainsKey($h.Start)) { $refsByStart[$h.Start] = New-Object System.Collections.Generic.List[string]; $picked.Add($h) }
            if ($refsByStart[$h.Start] -notcontains $w.Ref) { $refsByStart[$h.Start].Add($w.Ref) }
        }
    }
    $ordered = @($picked | Sort-Object Start)

    $o = New-Object System.Collections.Generic.List[string]
    $o.Add(("==== REVIEW PACK: {0}, sliced to the tasks Topic {1} prepares ====" -f $Doc.Name, $TopicNumber))
    $o.Add(("==== SOURCE: {0} ({1} lines; {2} region(s) cut at {3}) ====" -f (Split-Path $Doc.Path -Leaf), $Regions.LineCount, $Regions.Regions.Count, $(if ($Regions.FromToc) { ("the {0} Contents headings" -f $Regions.TocEntries) } else { 'every Task/Observation line - no Contents block' })))
    $o.Add(("==== This is the assessor guide for {0}, which you hold in full. Only the regions below are here: the benchmarks and checklists for your own topic's tasks. ====" -f $LearnerStem))
    $o.Add('==== Every other region belongs to another topic and is NOT here. Cross-topic mirroring is checked by the mirror gate over the whole spine, not by you. ====')
    foreach ($ms in $missing) { $o.Add(("==== NOT FOUND: no heading in this document matches {0}. The reference exists in the contract; the region does not. Report it. ====" -f $ms)) }
    $o.Add('')
    foreach ($r in $ordered) {
        $o.Add(("==== {0}: source lines {1}-{2} (for {3}) ====" -f $r.Heading, ($r.Start + 1), ($r.End + 1), ($refsByStart[$r.Start] -join ', ')))
        foreach ($ln in $r.Lines) { $o.Add($ln) }
        $o.Add('')
    }
    $lineTotal = 0; foreach ($r in $ordered) { $lineTotal += $r.Lines.Count }
    return [pscustomobject]@{ Text = (Join-TextLines -Lines $o.ToArray()); Regions = @($ordered | ForEach-Object { [ordered]@{ heading = $_.Heading; lines = @(($_.Start + 1), ($_.End + 1)); refs = @($refsByStart[$_.Start]) } }); Missing = $missing.ToArray(); LineCount = $lineTotal }
}

# ---------------------------------------------------------------------------
# 4. The files this script WRITES rather than slices: SCOPE.md and
#    allow-list.txt. ASCII templates filled from the build; no build reasoning.
# ---------------------------------------------------------------------------

function New-AllowListText {
    param([hashtable] $Mirror, [hashtable] $Leak, [string] $Scope, [int] $TopicNumber, [string] $Source)

    $o = New-Object System.Collections.Generic.List[string]
    $o.Add('ALLOW-LIST - every gate hit a builder cleared at Stage 3d, with the written reason')
    $o.Add(("SOURCE: {0} (keys mirrorAllow and leakageAllow - the same entries the mirror and leakage gates read)" -f $Source))
    $o.Add(("SCOPE OF THIS FILE: {0}" -f $Scope))
    $o.Add('')
    $o.Add('Each entry is a CLAIM to verify against the task text in the pack, not a settled matter.')
    $o.Add('An allow-list nobody re-reads is a way of turning a gate off. Where the reason does not')
    $o.Add('survive your read of the task, report a finding of class leak and quote the reason.')
    $o.Add('')

    $mk = @($Mirror.Keys | Sort-Object)
    if ($TopicNumber -gt 0) { $mk = @($mk | Where-Object { $_ -match ('^' + $TopicNumber + '\.') }) }
    $o.Add(("MIRROR CLEARANCES (slot: reason) - {0} shown of {1} in the registry" -f $mk.Count, $Mirror.Count))
    if ($mk.Count -eq 0) { $o.Add('  (none)') }
    foreach ($k in $mk) { $o.Add(("  {0}: {1}" -f $k, $Mirror[$k])) }
    $o.Add('')
    $lk = @($Leak.Keys | Sort-Object)
    $o.Add(("LEAKAGE CLEARANCES (phrase: reason) - {0}, every one, because a phrase can occur in any topic" -f $lk.Count))
    if ($lk.Count -eq 0) { $o.Add('  (none)') }
    foreach ($k in $lk) { $o.Add(("  {0}: {1}" -f $k, $Leak[$k])) }
    $o.Add('')
    if ($Mirror.Count -eq 0 -and $Leak.Count -eq 0) {
        $o.Add('NO ALLOW-LIST ENTRIES IN THE REGISTRY. Either no mirror or leakage hit was cleared at Stage 3d,')
        $o.Add('or the registry was not supplied. Either way nothing was waived: every gate hit still stands')
        $o.Add('as a candidate, and a figure that reproduces an assessed grid has no clearance to hide behind.')
    }
    return (Join-TextLines -Lines $o.ToArray())
}

function New-TopicScopeText {
    param($Topic, [int] $TopicCount, [string] $Dir, [int[]] $Slides, [int[]] $SharedSlides, [string[]] $Slots, [int] $UnassignedSlots, [string[]] $LearnerNames, [string[]] $AssessorNames, [string[]] $AssignedRefs, [bool] $FullPackMode, [string] $GuideLineRange)

    $n = $Topic.Number
    $subs = if ($Topic.SubSections.Count) { $Topic.SubSections -join ', ' } else { '(no N.N sub-section headings found in the slice)' }
    $refs = if ($AssignedRefs.Count) { $AssignedRefs -join ', ' } else { '(none assigned by the question map)' }
    $o = New-Object System.Collections.Generic.List[string]
    $o.Add(("# SCOPE - Topic {0} reviewer ({0} of {1})" -f $n, $TopicCount))
    $o.Add('')
    $o.Add(("This directory is your whole world. You are one of {0} topic reviewers plus the cross-document" -f $TopicCount))
    $o.Add('reviewer(s), all cut from the same finished build. None of you can see another reviewer''s pack or')
    $o.Add('output. The findings are merged by a script (Merge-AuditFindings.ps1) that never summarises or')
    $o.Add('rewords a finding. Nothing you write here is read by another reviewer.')
    $o.Add('')
    $o.Add('## Paste this block into the reviewer prompt')
    $o.Add('')
    $o.Add('```')
    $o.Add(("SCOPE: Topic {0} - {1}" -f $n, $Topic.Title))
    $o.Add(("PACK DIRECTORY: {0}" -f $Dir))
    $o.Add(("YOU OWN: the Topic {0} slice of the Learner Guide (sub-sections {1}); deck slides {2}; figure slots {3}. Every check in the checklist, on that material: provenance of every figure, the figure read, assessed-grid leakage, coverage depth, usability and pitch, and guide-versus-deck agreement inside the topic." -f $n, $subs, (Format-NumberList -Numbers $Slides), $(if ($Slots.Count) { $Slots -join ', ' } else { '(none)' })))
    if ($FullPackMode) {
        $o.Add(("YOU ALSO HOLD, SHARED WITH EVERY REVIEWER: the guide's front matter (the cross-reference table and the assessment overview) and back matter (appendices, glossary, alt text); the shared orientation and briefing slides {0}; the FULL assessment pack, learner tools and assessor guides alike; the independent unit extract; the Stage 3d allow-list." -f (Format-NumberList -Numbers $SharedSlides)))
        $o.Add('YOU DO NOT HAVE: any other topic''s prose. Do not go looking for it and do not infer it. A pack task your topic does not prepare is still in your pack so that you can recognise its answer grid if your topic mirrors it.')
    }
    else {
        $o.Add(("YOU ALSO HOLD, SHARED WITH EVERY REVIEWER: the guide's front matter (the cross-reference table and the assessment overview) and back matter (appendices, glossary, alt text); the shared orientation and briefing slides {0}; the learner-facing assessment tools IN FULL ({1}) - they are what the learner holds, and every cross-reference target must resolve in them; the independent unit extract; the Stage 3d allow-list." -f (Format-NumberList -Numbers $SharedSlides), ($LearnerNames -join ', ')))
        $o.Add(("FROM THE ASSESSOR GUIDES YOU HOLD ONLY: the regions for the tasks Topic {0} prepares - {1} - cut at the documents' own task headings and bannered with the source line range ({2}). They are the benchmarks and checklists you need to judge leakage inside your own topic. No other task's benchmark is here." -f $n, $refs, ($AssessorNames -join ', ')))
        $o.Add('YOU DO NOT HAVE: any other topic''s prose, or the assessor-guide regions of any other topic''s tasks. Cross-topic mirroring - a Topic 3 grid answered in Topic 5 - is checked mechanically by the mirror gate over the whole spine; it is not your job to hunt for it, and you could not from here. Do not go looking for it and do not infer it.')
    }
    $o.Add('YOU STILL REPORT, IF YOU SEE IT: another topic''s assessed task answered in your slice (class leak, naming the task - the learner tools you hold in full are enough to recognise one); a pack defect (upstream, listed separately, never as a guide defect); a defect in the front or back matter your topic relies on; an allow-list entry whose reason does not survive your read of the task text (class leak, quoting the reason).')
    $o.Add('THE CROSS-DOCUMENT REVIEWER OWNS: agreement across topics, scope statements, adoption relationships and the scenario clock. A disagreement inside your topic, or between your slides and your prose, is yours.')
    $o.Add(("COVERAGE IS LOAD-BEARING: in findings.json coverage[], claim every KE and PE item - sub-points included, each on its own - that Topic {0} teaches, with anchors. The merger raises a High finding for any item no reviewer claims. Claim only what you found taught on the page; a heading is not coverage." -f $n))
    $o.Add(("OUTPUT: write your report file in this directory FIRST and append as you go; then write findings.json beside it, per the checklist's structured output contract, with reviewer ""topic{0}"" and scope ""Topic {0} - {1}""." -f $n, $Topic.Title))
    $o.Add('```')
    $o.Add('')
    $o.Add('## Files in this pack')
    $o.Add('')
    $o.Add('| File | What it is |')
    $o.Add('|---|---|')
    $o.Add(("| guide.txt | Front matter, then Topic {0} (full-extract lines {1}), then back matter. Verbatim slices. |" -f $n, $GuideLineRange))
    $o.Add(("| deck.txt | Shared slides {0} and Topic {1} slides {2}, whole blocks with speaker notes. |" -f (Format-NumberList -Numbers $SharedSlides), $n, (Format-NumberList -Numbers $Slides)))
    $o.Add(("| figure-sheet.txt | Figure content for slots {0}{1}. Read it as content: rows, caption, alt text. |" -f $(if ($Slots.Count) { $Slots -join ', ' } else { '(none)' }), $(if ($UnassignedSlots -gt 0) { (" plus {0} block(s) that declare no slot" -f $UnassignedSlots) } else { '' })))
    foreach ($p in $LearnerNames) { $o.Add(("| {0} | Learner-facing assessment tool, complete. The pack is the authority; the guide is derived from it. |" -f $p)) }
    foreach ($p in $AssessorNames) {
        if ($FullPackMode) { $o.Add(("| {0} | Assessor guide, complete (-FullPack mode). Benchmark source for the leakage check; never a guide source. |" -f $p)) }
        else { $o.Add(("| {0} | Assessor guide, SLICED to the regions for {1}. Benchmark source for the leakage check; never a guide source. |" -f $p, $refs)) }
    }
    $o.Add('| unit_extract.md | The unit, extracted independently of the build. Re-verify only the currency on the day. |')
    $o.Add('| allow-list.txt | Stage 3d clearances with reasons - claims to verify, not verdicts. |')
    $o.Add('| SCOPE.md | This file. |')
    $o.Add('')
    $o.Add('## Locators')
    $o.Add('')
    $o.Add('Slide numbers, figure slot numbers, sub-section numbers, task headings and "Figure N.N.N -" captions')
    $o.Add('survive the cut unchanged: anchor every finding to one of them plus a quoted phrase. guide.txt and')
    $o.Add('the assessor slices are cut from larger files, so a line number inside them is not a line number in')
    $o.Add('the source; every banner states the source line range. Cite heading and quoted phrase, never slice')
    $o.Add('line numbers.')
    $o.Add('')
    return (Join-TextLines -Lines $o.ToArray())
}

function New-CrossdocScopeText {
    param([int] $TopicCount, [string] $Dir, [string] $Variant, [string[]] $PackNames, [bool] $HasFiguresJson, [bool] $FullPackMode, [int] $TermOnlyDropped)

    $o = New-Object System.Collections.Generic.List[string]
    $title = switch ($Variant) { 'values' { 'cross-document reviewer - VALUES' } 'refs' { 'cross-document reviewer - REFERENCES' } default { 'cross-document reviewer' } }
    $o.Add(("# SCOPE - {0}" -f $title))
    $o.Add('')
    $o.Add(("This directory is your whole world. {0} topic reviewers each hold one topic's prose; you hold none of" -f $TopicCount))
    $o.Add('it. You hold every checkable claim from both artefacts, with its location, so that agreement can')
    $o.Add('be judged without reading 1.1 MB. None of you can see another reviewer''s pack or output; a script')
    $o.Add('merges the findings and never rewords one.')
    if ($Variant -ne 'single') {
        $o.Add('')
        $o.Add('The cross-document work is split in two because one pack exceeded the budget: VALUES (numbers,')
        $o.Add('temperatures, quantities, the scenario clock, adoption language) and REFERENCES (instrument')
        $o.Add('citations, locked terms and their forbidden variants, question references, adoption language).')
        $o.Add('Adoption language is in both digests, because a venue-versus-Code statement is both a value')
        $o.Add('and a citation. You are one half; the other half is another reviewer you cannot see.')
    }
    $o.Add('')
    $o.Add('## Paste this block into the reviewer prompt')
    $o.Add('')
    $o.Add('```')
    switch ($Variant) {
        'values' {
            $o.Add(("SCOPE: cross-document agreement - VALUES: numbers, temperatures, quantities, the scenario clock and adoption language, across all {0} topics" -f $TopicCount))
            $o.Add(("PACK DIRECTORY: {0}" -f $Dir))
            $o.Add('YOU OWN: guide-versus-deck-versus-pack agreement on every value - every temperature, time, duration, weight, volume, count and percentage that appears in more than one place must agree everywhere, and a value both artefacts carry must be identical in both; the scenario clock (dates, days, times and the production run, against the pack''s own order form); adoption relationships (what the venue has adopted against what the Code requires, stated the same way in every place that states it, and the figure attached to each).')
            $o.Add('NOT YOURS: instrument citations, locked terminology and question references - the REFERENCES reviewer holds those. Any topic''s prose for truth, depth, pitch or leakage - the topic reviewers hold that. A figure-sheet value that disagrees with the digest is yours; whether the figure is true is theirs.')
        }
        'refs' {
            $o.Add(("SCOPE: cross-document agreement - REFERENCES: instrument citations, locked terms and their forbidden variants, question references, and adoption language, across all {0} topics" -f $TopicCount))
            $o.Add(("PACK DIRECTORY: {0}" -f $Dir))
            $o.Add('YOU OWN: guide-versus-deck-versus-pack agreement on every reference - the same duty cited to the same standard, clause and jurisdiction everywhere; locked terminology, one word per concept everywhere, every forbidden variant reported; question references (every cited item exists in the learner tools under that number, and the cross-reference table agrees with the chips and the assessment-link slides); scope statements (a duty stated two incompatible ways); adoption relationships as citations (which instrument each stated figure is attributed to, the same way everywhere).')
            $o.Add('NOT YOURS: whether two temperatures, times or quantities agree - the VALUES reviewer holds those. Any topic''s prose for truth, depth, pitch or leakage - the topic reviewers hold that.')
        }
        default {
            $o.Add(("SCOPE: cross-document agreement across all {0} topics" -f $TopicCount))
            $o.Add(("PACK DIRECTORY: {0}" -f $Dir))
            $o.Add('YOU OWN: guide-versus-deck-versus-pack agreement across topics - every value, term, clause, question reference and scenario fact that appears in more than one place must agree everywhere, and a value both artefacts carry must be identical in both; scope statements (a duty stated two incompatible ways); adoption relationships (what the venue has adopted against what the Code requires, stated the same way in every place that states it); the scenario clock (dates, days, times and the production run, against the pack''s own order form); question references (every cited item exists in the learner tools under that number, and the cross-reference table agrees with the chips and the assessment-link slides); locked terminology and its forbidden variants, everywhere.')
            $o.Add('YOU DO NOT REVIEW: any topic''s prose for truth, depth, pitch or leakage. You do not have the prose; the topic reviewers own it. A figure-sheet value that disagrees with the digest is yours; whether the figure is true is theirs.')
        }
    }
    $packLine = if ($FullPackMode) { 'the full assessment pack' } else { ("the LEARNER-facing tools only ({0}) - agreement is between what the learner holds and what the guide and deck say, and the assessor guides are not learner-held" -f ($PackNames -join ', ')) }
    $o.Add(("YOUR INPUTS: claims-digest.txt - every sentence in the guide and the deck that carries {0}, each with its location, exact repeats collapsed with a count, and a values index showing where each distinct value occurs; sentences whose only claim is a correctly used locked term are dropped from the sentence list and counted ({1} on this build), because they carry no value to compare and the values index already counts every term per topic; figure-sheet.txt in full; {2}; {3}; the unit extract; the full Stage 3d allow-list." -f $(switch ($Variant) { 'values' { 'a numeral with a unit, a scenario time or day, or adoption language' } 'refs' { 'an instrument citation, a locked term or its forbidden variant, a question reference, or adoption language' } default { 'a numeral with a unit, a locked term or its forbidden variant, an instrument citation, a question reference, a scenario time or day, or adoption language' } }), $TermOnlyDropped, $(if ($HasFiguresJson) { 'figures.json, the registry - the classes and locators the build CLAIMS, which you verify against the pack and never accept' } else { 'no figures.json - the build has no registry, so no figure is classed by anybody; say so' }), $packLine))
    $o.Add('YOU STILL REPORT, IF YOU SEE IT: a pack defect (upstream, listed separately); an allow-list entry whose reason does not survive your read of the task text (class leak, quoting the reason).')
    $o.Add('COVERAGE: you teach nothing. Write coverage as an empty list and say so in the report.')
    $o.Add(("OUTPUT: write your report file in this directory FIRST and append as you go; then write findings.json beside it, per the checklist's structured output contract, with reviewer ""{0}"" and scope ""{1}""." -f $(switch ($Variant) { 'values' { 'crossdoc-values' } 'refs' { 'crossdoc-refs' } default { 'crossdoc' } }), $(switch ($Variant) { 'values' { 'cross-document agreement - values' } 'refs' { 'cross-document agreement - references' } default { 'cross-document agreement' } })))
    $o.Add('```')
    $o.Add('')
    $o.Add('## Files in this pack')
    $o.Add('')
    $o.Add('| File | What it is |')
    $o.Add('|---|---|')
    $o.Add('| claims-digest.txt | Every claim-bearing sentence from both artefacts with locators (G:L<line> T<topic>/<sub> <channel>; D:S<slide> T<topic> <channel>), deduplicated with counts, plus a values index. A transcript; it claims nothing is correct. Its header states what was dropped or filtered. |')
    $o.Add('| figure-sheet.txt | Every planned figure as content, all topics. |')
    if ($HasFiguresJson) { $o.Add('| figures.json | The figure registry: each registered figure with the authority class and locator the build claims. Verify; do not accept. |') }
    else { $o.Add('| (figures.json) | NOT SUPPLIED - the build has no registry, so no figure is classed by anybody. Say so in your report. |') }
    foreach ($p in $PackNames) { $o.Add(("| {0} | {1}, complete. The pack is the authority. |" -f $p, $(if ($FullPackMode) { 'Assessment pack extract' } else { 'Learner-facing assessment tool' }))) }
    $o.Add('| unit_extract.md | The unit, extracted independently of the build. |')
    $o.Add('| allow-list.txt | Every Stage 3d clearance with its reason - claims to verify. |')
    $o.Add('| SCOPE.md | This file. |')
    $o.Add('')
    $o.Add('## Locators')
    $o.Add('')
    $o.Add('Use the digest''s locators as they stand: G:L<line> is a line of the full guide extract, D:S<n> a')
    $o.Add('slide number. Both are what the remediation works from.')
    $o.Add('')
    return (Join-TextLines -Lines $o.ToArray())
}

# ---------------------------------------------------------------------------
# 5. Measure a pack the way the reader will experience it
# ---------------------------------------------------------------------------

function Measure-ReviewPack {
    param([string] $Dir)
    $files = @(Get-ChildItem -LiteralPath $Dir -File | Sort-Object Name)
    $rows = New-Object System.Collections.Generic.List[object]
    $bytes = [long]0; $chars = [long]0
    foreach ($f in $files) {
        $t = Get-GateFileText -Path $f.FullName
        $c = [long]$t.Length
        $rows.Add([pscustomobject]@{ Name = $f.Name; Bytes = [long]$f.Length; Chars = $c; Tokens = [int][math]::Ceiling($c / 4) })
        $bytes += $f.Length; $chars += $c
    }
    return [pscustomobject]@{ Files = $rows.ToArray(); Bytes = $bytes; Chars = $chars; KB = [math]::Round($bytes / 1024, 1); Tokens = [int][math]::Ceiling($chars / 4) }
}

function New-PackRow {
    param([string] $Name, [string] $Dir, [string[]] $SharedFileNames, [long] $SharedExtraChars, [int] $MaxTokens, [hashtable] $Extra)
    $m = Measure-ReviewPack -Dir $Dir
    $sharedChars = [long]$SharedExtraChars
    foreach ($row in $m.Files) { if ($SharedFileNames -contains $row.Name) { $sharedChars += $row.Chars } }
    $sharedTokens = [int][math]::Ceiling($sharedChars / 4)
    $row = [ordered]@{
        Name = $Name; Dir = $Dir; Files = $m.Files; KB = $m.KB; Chars = $m.Chars; Tokens = $m.Tokens
        SharedChars = $sharedChars; SharedTokens = $sharedTokens; SpecificChars = ($m.Chars - $sharedChars); SpecificTokens = ($m.Tokens - $sharedTokens)
        WithinBudget = ($m.Tokens -le $MaxTokens)
    }
    if ($null -ne $Extra) { foreach ($k in $Extra.Keys) { $row[$k] = $Extra[$k] } }
    return [pscustomobject]$row
}

# ---------------------------------------------------------------------------
# 6. The run
# ---------------------------------------------------------------------------

function Invoke-ReviewPack {
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [Parameter(Mandatory)][string] $OutDir,
        [hashtable] $Given,
        [string[]] $PackInclude,
        [int] $MaxTokens,
        [switch] $FullPack,
        [string] $CrossdocSplit = 'Auto',
        [switch] $Quiet
    )

    $result = [pscustomobject]@{ ExitCode = 0; Errors = (New-Object System.Collections.Generic.List[string]); Packs = @(); OverBudget = @(); Manifest = $null; Notes = (New-Object System.Collections.Generic.List[string]) }
    if ($null -eq $Given) { $Given = @{} }

    if (-not (Test-Path -LiteralPath $BuildDir)) { $result.Errors.Add("no build directory at $BuildDir"); $result.ExitCode = 2; return $result }
    $in = Resolve-ReviewInput -BuildDir $BuildDir -Given $Given
    $p = $in.Paths

    if (-not $Quiet) {
        Write-Host ''
        Write-Host ("$GATE - one pack per topic, plus crossdoc ({0})" -f $(if ($FullPack) { 'FULL-PACK mode: every extract to every reviewer' } else { 'default mode: learner tools whole, assessor guides sliced to each topic''s tasks' })) -ForegroundColor Cyan
        foreach ($h in $in.How) { Write-Host ("  {0}" -f $h) -ForegroundColor DarkGray }
    }

    foreach ($req in @('guideExtract', 'deckExtract', 'packDir', 'figureSheet', 'deckPlan', 'unitExtract')) {
        if (-not $p[$req] -or -not (Test-Path -LiteralPath $p[$req])) {
            $result.Errors.Add(("required input '{0}' is missing. A pack cut without it would hand the reviewer less than the checklist requires and say nothing." -f $req))
        }
    }
    if ($result.Errors.Count -gt 0) { $result.ExitCode = 2; return $result }

    # --- the guide
    $guide = Split-GuideExtract -Text (Get-GateFileText -Path $p['guideExtract'])
    if (-not $guide.Ok) { foreach ($e in $guide.Errors) { $result.Errors.Add("guide extract: $e") }; $result.ExitCode = 2; return $result }
    $topicCount = $guide.Topics.Count

    # --- the contract
    $contractObj = $null
    if ($p['contract'] -and (Test-Path -LiteralPath $p['contract'])) {
        $contractObj = Get-GateJson -Path $p['contract']
        if ($null -ne $contractObj -and @($contractObj.PSObject.Properties.Name) -contains 'topics') {
            $ct = @($contractObj.topics).Count
            if ($ct -ne $topicCount) {
                $result.Errors.Add(("the contract declares {0} topic(s) but the guide extract carries {1} 'Topic N - ' headings. The rendered guide and the contract disagree; cut nothing until they agree." -f $ct, $topicCount))
            }
        }
    }

    # --- the deck and its plan
    $deck = Split-DeckExtract -Text (Get-GateFileText -Path $p['deckExtract'])
    if (-not $deck.Ok) { foreach ($e in $deck.Errors) { $result.Errors.Add("deck extract: $e") } }
    $plan = @()
    try { $plan = @(Get-GateJson -Path $p['deckPlan']) } catch { $result.Errors.Add(("deckplan.json did not parse: {0}" -f $_.Exception.Message)) }
    if ($deck.Ok -and $plan.Count -ne $deck.Slides.Count) {
        $result.Errors.Add(("deckplan.json has {0} entries but the deck extract has {1} slides. Slides are mapped to topics by position, so a count mismatch would silently put slides in the wrong pack." -f $plan.Count, $deck.Slides.Count))
    }
    if ($result.Errors.Count -gt 0) { $result.ExitCode = 2; return $result }

    $topicSlides = @{}
    foreach ($t in $guide.Topics) { $topicSlides[$t.Number] = New-Object System.Collections.Generic.List[int] }
    $sharedSlides = New-Object System.Collections.Generic.List[int]
    for ($i = 0; $i -lt $plan.Count; $i++) {
        $e = $plan[$i]
        $tn = 0
        if ($null -ne $e -and @($e.PSObject.Properties.Name) -contains 'Topic' -and $null -ne $e.Topic -and "$($e.Topic)" -ne '') { $tn = [int]$e.Topic }
        if ($tn -gt 0) {
            if (-not $topicSlides.ContainsKey($tn)) { $result.Errors.Add(("deckplan.json entry {0} ('{1}') belongs to Topic {2}, which the guide extract does not have. That slide would land in no pack." -f ($i + 1), $e.Tag, $tn)); continue }
            $topicSlides[$tn].Add($i + 1)
        }
        else { $sharedSlides.Add($i + 1) }
    }
    if ($result.Errors.Count -gt 0) { $result.ExitCode = 2; return $result }

    # --- the figure sheet
    $sheet = Split-FigureSheet -Text (Get-GateFileText -Path $p['figureSheet'])
    $unassigned = @($sheet.Blocks | Where-Object { $_.Topic -eq 0 })

    # --- the pack, classified the way the gates classify it
    $corpus = Get-GateCorpusDocs -CorpusDir $p['packDir'] -BuildDir $BuildDir
    $packDocs = @($corpus.Documents | Where-Object { $d = $_; @($PackInclude | Where-Object { ($d.Name + '.txt') -like $_ }).Count -gt 0 } | Sort-Object Name)
    if ($packDocs.Count -eq 0) { $result.Errors.Add(("no pack extract in {0} matches -PackInclude {1}. Every reviewer needs the learner tools; a pack with none reviews nothing." -f $p['packDir'], ($PackInclude -join ', '))); $result.ExitCode = 2; return $result }
    $learnerDocs = @($packDocs | Where-Object { $_.Audience -eq 'learner' })
    $assessorDocs = @($packDocs | Where-Object { $_.Audience -eq 'assessor' })
    if ($learnerDocs.Count -eq 0) { $result.Errors.Add(("no LEARNER-facing extract in {0} (classified from {1}). The learner tools are what every reviewer must hold in full." -f $p['packDir'], $corpus.ClassifiedFrom)); $result.ExitCode = 2; return $result }

    # --- task-to-topic, from the contract, unless -FullPack
    $kinds = @()
    $topicRefs = @{}
    $assessorRegions = @{}
    if (-not $FullPack) {
        $kinds = @(Get-ReferenceKind -ContractObj $contractObj -LearnerDocs $learnerDocs)
        $hasMap = ($null -ne $contractObj -and @($contractObj.PSObject.Properties.Name) -contains 'questionMap' -and $null -ne $contractObj.questionMap)
        if ($kinds.Count -eq 0 -or -not $hasMap) {
            $result.Errors.Add('the default mode slices the assessor guides to each topic''s tasks, which needs contract.json referenceConvention (with <kind>Means naming the learner document) and questionMap. This build has ' + $(if ($kinds.Count -eq 0) { 'no usable referenceConvention' } else { 'a referenceConvention' }) + ' and ' + $(if ($hasMap) { 'a questionMap' } else { 'no questionMap' }) + '. Supply them, or pass -FullPack for a small unit and accept the size.')
            $result.ExitCode = 2; return $result
        }
        foreach ($k in $kinds) { if (-not $k.DocStem) { $result.Notes.Add(("reference kind '{0}' ({1} N) maps to no learner document: {2}. Its references cannot be sliced and are reported as NOT FOUND in the banners." -f $k.Kind, $k.Prefix, $k.How)) } }
        foreach ($t in $guide.Topics) {
            $pcs = @($t.SubSections)
            if (@($contractObj.PSObject.Properties.Name) -contains 'topics') {
                $ct = @($contractObj.topics | Where-Object { [int](Get-GateProp -Object $_ -Names @('n', 'number') -Default 0) -eq $t.Number }) | Select-Object -First 1
                if ($null -ne $ct -and @($ct.PSObject.Properties.Name) -contains 'pcs') { $pcs = @($ct.pcs | ForEach-Object { "$_" }) }
            }
            $refs = New-Object System.Collections.Generic.List[object]
            foreach ($pc in $pcs) {
                if (@($contractObj.questionMap.PSObject.Properties.Name) -notcontains $pc) { continue }
                foreach ($r in @($contractObj.questionMap.$pc)) {
                    $res = Resolve-TaskReference -Ref "$r" -Kinds $kinds
                    if ($null -eq $res) { $result.Notes.Add(("Topic {0}: question map reference '{1}' matches no reference kind prefix and is ignored" -f $t.Number, $r)); continue }
                    if (@($refs | Where-Object { $_.Kind -eq $res.Kind -and $_.Number -eq $res.Number }).Count -eq 0) { $refs.Add($res) }
                }
            }
            $topicRefs[$t.Number] = $refs.ToArray()
        }
        foreach ($ad in $assessorDocs) { $assessorRegions[$ad.Name] = Get-DocRegions -Text $ad.Text }
    }

    # --- the allow-list, read exactly as the gates read it
    $registry = $null
    if ($p['figuresJson'] -and (Test-Path -LiteralPath $p['figuresJson'])) { $registry = Get-GateJson -Path $p['figuresJson'] }
    $mirrorAllow = @{}; $leakAllow = @{}
    try {
        $mirrorAllow = Get-GateAllowList -Registry $registry -Key 'mirrorAllow' -IdField @('slot', 'id', 'figure') -GateName $GATE
        $leakAllow = Get-GateAllowList -Registry $registry -Key 'leakageAllow' -IdField @('phrase', 'text', 'id') -GateName $GATE
    }
    catch { $result.Errors.Add(("allow-list: {0}" -f $_.Exception.Message)); $result.ExitCode = 2; return $result }
    $allowSource = if ($null -ne $registry) { $p['figuresJson'] } else { '(no figures.json supplied)' }

    if (-not $Quiet) {
        Write-GateCheckSet -What 'topic(s)' -Count $topicCount -DerivedFrom 'the "Topic N - " heading lines of the guide extract'
        Write-GateCheckSet -What 'slide(s)' -Count $deck.Slides.Count -DerivedFrom ("deckplan.json entries, {0} shared and the rest by Topic" -f $sharedSlides.Count)
        Write-GateCheckSet -What 'figure block(s)' -Count $sheet.Blocks.Count -DerivedFrom ("the figure sheet's SLOT lines, {0} with no slot" -f $unassigned.Count)
        Write-GateCheckSet -What 'pack extract(s)' -Count $packDocs.Count -DerivedFrom ("{0} filtered by {1}; {2} learner, {3} assessor, classified from {4}" -f $p['packDir'], ($PackInclude -join ', '), $learnerDocs.Count, $assessorDocs.Count, $corpus.ClassifiedFrom)
        if (-not $FullPack) {
            Write-GateCheckSet -What 'reference kind(s)' -Count $kinds.Count -DerivedFrom 'contract.json referenceConvention'
            foreach ($k in $kinds) { Write-Host ("    {0}: '{1} N' -> {2} ({3})" -f $k.Kind, $k.Prefix, $(if ($k.DocStem) { $k.DocStem } else { 'UNMAPPED' }), $k.How) -ForegroundColor DarkGray }
            foreach ($ad in $assessorDocs) { Write-Host ("    {0}: {1} region(s) cut at {2}" -f $ad.Name, $assessorRegions[$ad.Name].Regions.Count, $(if ($assessorRegions[$ad.Name].FromToc) { ("{0} Contents headings" -f $assessorRegions[$ad.Name].TocEntries) } else { 'every Task/Observation line (no Contents block)' })) -ForegroundColor DarkGray }
        }
        Write-GateCheckSet -What 'allow-list entries' -Count ($mirrorAllow.Count + $leakAllow.Count) -DerivedFrom 'figures.json mirrorAllow and leakageAllow'
        Write-Host ("  back matter: {0}" -f $guide.BackReason) -ForegroundColor DarkGray
        foreach ($n in $result.Notes) { Write-Host ("  note: {0}" -f $n) -ForegroundColor Yellow }
    }

    # --- write
    if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
    $unitLeaf = Split-Path $p['unitExtract'] -Leaf
    $learnerNames = @($learnerDocs | ForEach-Object { $_.Name + '.txt' })
    $assessorNames = @($assessorDocs | ForEach-Object { $_.Name + '.txt' })
    $allPackNames = @($packDocs | ForEach-Object { $_.Name + '.txt' })
    $frontText = Join-TextLines -Lines $guide.Front
    $backText = Join-TextLines -Lines $guide.Back
    $sharedDeckLines = New-Object System.Collections.Generic.List[string]
    foreach ($ln in $deck.Preamble) { $sharedDeckLines.Add($ln) }
    foreach ($s in $sharedSlides) { foreach ($ln in $deck.Slides[$s - 1].Lines) { $sharedDeckLines.Add($ln) } }
    $sharedDeckText = Join-TextLines -Lines $sharedDeckLines.ToArray()
    $sheetHeaderText = Join-TextLines -Lines $sheet.Header
    $unassignedText = ''
    foreach ($b in $unassigned) { $unassignedText += (Join-TextLines -Lines $b.Lines.ToArray()) }
    $sharedFileNames = @($unitLeaf, 'allow-list.txt') + $(if ($FullPack) { $allPackNames } else { $learnerNames })

    $manifestTopics = New-Object System.Collections.Generic.List[object]
    $packRows = New-Object System.Collections.Generic.List[object]

    foreach ($t in $guide.Topics) {
        $n = $t.Number
        $dir = Join-Path $OutDir ("topic{0}" -f $n)
        New-EmptyDir -Dir $dir

        $slides = @($topicSlides[$n])
        $slots = @($sheet.Blocks | Where-Object { $_.Topic -eq $n } | ForEach-Object { $_.Slot })
        $lineRange = ("{0}-{1}" -f $t.StartLine, $t.EndLine)

        # guide.txt
        $g = New-Object System.Collections.Generic.List[string]
        $g.Add(("==== REVIEW PACK: Learner Guide extract, sliced for Topic {0} of {1} ====" -f $n, $topicCount))
        $g.Add(("==== SOURCE: {0} ({1} lines) ====" -f (Split-Path $p['guideExtract'] -Leaf), $guide.LineCount))
        $g.Add(("==== FRONT MATTER (shared by every reviewer): full-extract lines 1-{0} ====" -f $guide.FrontEndLine))
        $gt = (Join-TextLines -Lines $g.ToArray()) + $frontText
        $gt += (Join-TextLines -Lines @('', ("==== TOPIC {0} BODY: full-extract lines {1} ====" -f $n, $lineRange)))
        $gt += (Join-TextLines -Lines $t.Lines)
        if ($guide.Back.Count -gt 0) {
            $gt += (Join-TextLines -Lines @('', ("==== BACK MATTER (shared by every reviewer): full-extract lines {0}-{1} ====" -f $guide.BackStartLine, $guide.LineCount)))
            $gt += $backText
        }
        Write-Utf8File -Path (Join-Path $dir 'guide.txt') -Content $gt

        # deck.txt
        $d = New-Object System.Collections.Generic.List[string]
        $d.Add(("==== REVIEW PACK: Delivery deck extract, sliced for Topic {0} of {1} ====" -f $n, $topicCount))
        $d.Add(("==== SOURCE: {0} ({1} slides) - shared slides {2}; Topic {0} slides {3} ====" -f (Split-Path $p['deckExtract'] -Leaf), $deck.Slides.Count, (Format-NumberList -Numbers $sharedSlides.ToArray()), (Format-NumberList -Numbers $slides)))
        $d.Add('==== Slide numbers are the deck''s own and survive the cut. Blocks are whole, notes included. ====')
        $dt = (Join-TextLines -Lines $d.ToArray()) + $sharedDeckText
        foreach ($s in $slides) { $dt += (Join-TextLines -Lines $deck.Slides[$s - 1].Lines.ToArray()) }
        Write-Utf8File -Path (Join-Path $dir 'deck.txt') -Content $dt

        # figure-sheet.txt
        $ft = $sheetHeaderText
        $ft += (Join-TextLines -Lines @(("==== SLICE: Topic {0} - {1} of {2} slot block(s){3} ====" -f $n, $slots.Count, $sheet.Blocks.Count, $(if ($unassigned.Count) { (", plus {0} with no slot declared" -f $unassigned.Count) } else { '' })), ''))
        foreach ($b in ($sheet.Blocks | Where-Object { $_.Topic -eq $n })) { $ft += (Join-TextLines -Lines $b.Lines.ToArray()) }
        $ft += $unassignedText
        Write-Utf8File -Path (Join-Path $dir 'figure-sheet.txt') -Content $ft

        # the pack: learner tools whole; assessor guides whole (-FullPack) or sliced to this topic's tasks
        foreach ($ld in $learnerDocs) { Copy-Item -LiteralPath $ld.Path -Destination (Join-Path $dir ($ld.Name + '.txt')) -Force }
        $assignedRefs = @()
        $assessorManifest = New-Object System.Collections.Generic.List[object]
        if ($FullPack) {
            foreach ($ad in $assessorDocs) { Copy-Item -LiteralPath $ad.Path -Destination (Join-Path $dir ($ad.Name + '.txt')) -Force }
        }
        else {
            $refs = @($topicRefs[$n])
            $assignedRefs = @($refs | Sort-Object Kind, Number | ForEach-Object { ($_.Ref -replace '\s*\([a-z0-9]+\)\s*$', '').Trim() } | Select-Object -Unique)
            foreach ($ad in $assessorDocs) {
                $learnerStem = $null
                foreach ($ld in $learnerDocs) { if ($ad.Name -like ('*' + $ld.Name + '*')) { $learnerStem = $ld.Name; break } }
                $wanted = @($refs | Where-Object { $_.DocStem -and $learnerStem -and $_.DocStem -eq $learnerStem })
                if (-not $learnerStem) { $result.Notes.Add(("{0}: assessor extract matches no learner extract by name, so no task can be assigned to it; it is sliced to nothing" -f $ad.Name)) }
                $slice = New-AssessorSliceText -Doc $ad -Regions $assessorRegions[$ad.Name] -Wanted $wanted -TopicNumber $n -LearnerStem $(if ($learnerStem) { $learnerStem + '.txt' } else { '(no learner document matched by name)' })
                Write-Utf8File -Path (Join-Path $dir ($ad.Name + '.txt')) -Content $slice.Text
                $assessorManifest.Add([ordered]@{ doc = $ad.Name + '.txt'; learner = $learnerStem; regions = $slice.Regions; missing = $slice.Missing; lines = $slice.LineCount })
                foreach ($ms in $slice.Missing) { $result.Notes.Add(("Topic {0}: {1} has no heading for {2}; the reference is in the question map but the region was not found" -f $n, $ad.Name, $ms)) }
            }
        }
        Copy-Item -LiteralPath $p['unitExtract'] -Destination (Join-Path $dir $unitLeaf) -Force
        Write-Utf8File -Path (Join-Path $dir 'allow-list.txt') -Content (New-AllowListText -Mirror $mirrorAllow -Leak $leakAllow -Scope ("Topic {0}: mirror clearances for slots {0}.*, and every leakage clearance" -f $n) -TopicNumber $n -Source $allowSource)
        Write-Utf8File -Path (Join-Path $dir 'SCOPE.md') -Content (New-TopicScopeText -Topic $t -TopicCount $topicCount -Dir $dir -Slides $slides -SharedSlides $sharedSlides.ToArray() -Slots $slots -UnassignedSlots $unassigned.Count -LearnerNames $learnerNames -AssessorNames $assessorNames -AssignedRefs $assignedRefs -FullPackMode ([bool]$FullPack) -GuideLineRange $lineRange)

        $packRows.Add((New-PackRow -Name ("topic{0}" -f $n) -Dir $dir -SharedFileNames $sharedFileNames -SharedExtraChars ([long]($frontText.Length + $backText.Length + $sharedDeckText.Length + $sheetHeaderText.Length + $unassignedText.Length)) -MaxTokens $MaxTokens -Extra @{}))
        $manifestTopics.Add([ordered]@{ n = $n; title = $t.Title; subSections = $t.SubSections; guideLines = @($t.StartLine, $t.EndLine); slides = $slides; slots = $slots; tasks = $assignedRefs; assessorSlices = $assessorManifest.ToArray() })
    }

    # --- crossdoc: one pack, or two by category
    $digestScript = Join-Path $PSScriptRoot 'Get-ClaimsDigest.ps1'
    $hasReg = ($null -ne $registry)
    $crossPackDocs = if ($FullPack) { $packDocs } else { $learnerDocs }
    $crossPackNames = @($crossPackDocs | ForEach-Object { $_.Name + '.txt' })
    $crossShared = @($unitLeaf, 'allow-list.txt') + $crossPackNames

    $buildCross = {
        param([string] $Name, [string] $Variant, [string[]] $Categories)
        $cdir = Join-Path $OutDir $Name
        New-EmptyDir -Dir $cdir
        $dargs = @{ BuildDir = $BuildDir; GuideExtract = $p['guideExtract']; DeckExtract = $p['deckExtract']; OutPath = (Join-Path $cdir 'claims-digest.txt'); Quiet = $true }
        if ($p['contract']) { $dargs['Contract'] = $p['contract'] }
        if ($p['deckPlan']) { $dargs['DeckPlan'] = $p['deckPlan'] }
        if ($null -ne $Categories -and $Categories.Count -gt 0) { $dargs['Categories'] = $Categories }
        $global:LASTEXITCODE = 0
        & $digestScript @dargs
        if ($LASTEXITCODE -ne 0) { throw ("Get-ClaimsDigest.ps1 exited {0} for {1}; the pack would have no digest and the reviewer nothing to read." -f $LASTEXITCODE, $Name) }
        $dropped = 0
        $dm = [regex]::Match((Get-GateFileText -Path (Join-Path $cdir 'claims-digest.txt')), 'TERM-ONLY SENTENCES DROPPED FROM PART B: (\d+)')
        if ($dm.Success) { $dropped = [int]$dm.Groups[1].Value }
        Copy-Item -LiteralPath $p['figureSheet'] -Destination (Join-Path $cdir 'figure-sheet.txt') -Force
        if ($hasReg) { Copy-Item -LiteralPath $p['figuresJson'] -Destination (Join-Path $cdir 'figures.json') -Force }
        foreach ($pd in $crossPackDocs) { Copy-Item -LiteralPath $pd.Path -Destination (Join-Path $cdir ($pd.Name + '.txt')) -Force }
        Copy-Item -LiteralPath $p['unitExtract'] -Destination (Join-Path $cdir $unitLeaf) -Force
        Write-Utf8File -Path (Join-Path $cdir 'allow-list.txt') -Content (New-AllowListText -Mirror $mirrorAllow -Leak $leakAllow -Scope 'every clearance, all topics' -TopicNumber 0 -Source $allowSource)
        Write-Utf8File -Path (Join-Path $cdir 'SCOPE.md') -Content (New-CrossdocScopeText -TopicCount $topicCount -Dir $cdir -Variant $Variant -PackNames $crossPackNames -HasFiguresJson $hasReg -FullPackMode ([bool]$FullPack) -TermOnlyDropped $dropped)
        return (New-PackRow -Name $Name -Dir $cdir -SharedFileNames $crossShared -SharedExtraChars 0 -MaxTokens $MaxTokens -Extra @{ Categories = $Categories; TermOnlyDropped = $dropped })
    }

    $crossRows = New-Object System.Collections.Generic.List[object]
    $splitReason = ''
    try {
        if ($CrossdocSplit -eq 'Always') {
            $splitReason = '-CrossdocSplit Always'
        }
        else {
            $single = & $buildCross 'crossdoc' 'single' @()
            if ($CrossdocSplit -eq 'Auto' -and -not $single.WithinBudget) {
                $splitReason = ("the single crossdoc pack is {0:N0} tokens against {1:N0}" -f $single.Tokens, $MaxTokens)
                Remove-Item -LiteralPath $single.Dir -Recurse -Force
            }
            else { $crossRows.Add($single) }
        }
        if ($splitReason) {
            $crossRows.Add((& $buildCross 'crossdoc-values' 'values' $script:ValuesCategories))
            $crossRows.Add((& $buildCross 'crossdoc-refs' 'refs' $script:RefsCategories))
        }
    }
    catch { $result.Errors.Add($_.Exception.Message); $result.ExitCode = 2; return $result }
    foreach ($r in $crossRows) { $packRows.Add($r) }

    # --- report
    $over = New-Object System.Collections.Generic.List[string]
    foreach ($r in $packRows) { if (-not $r.WithinBudget) { $over.Add($r.Name) } }
    if (-not $Quiet) {
        Write-Host ''
        if ($splitReason) { Write-Host ("  crossdoc split into crossdoc-values and crossdoc-refs: {0}" -f $splitReason) -ForegroundColor Yellow }
        Write-Host ("  {0,-16} {1,9} {2,10} {3,10} {4,10}  {5}" -f 'pack', 'KB', 'tokens', 'shared', 'specific', ("budget {0}" -f $MaxTokens)) -ForegroundColor Cyan
        foreach ($r in $packRows) {
            $verdict = if ($r.WithinBudget) { 'ok' } else { 'X OVER BUDGET' }
            $colour = if ($r.WithinBudget) { 'Green' } else { 'Red' }
            Write-Host ("  {0,-16} {1,9:N1} {2,10:N0} {3,10:N0} {4,10:N0}  {5}" -f $r.Name, $r.KB, $r.Tokens, $r.SharedTokens, $r.SpecificTokens, $verdict) -ForegroundColor $colour
        }
        Write-Host '  tokens are estimated as characters / 4. "shared" is what every reviewer receives regardless of' -ForegroundColor DarkGray
        Write-Host ("  pack ({0}, unit extract, front and back matter, shared slides, allow-list); ""specific"" is the pack's own." -f $(if ($FullPack) { 'the full pack' } else { 'the learner tools' })) -ForegroundColor DarkGray
    }

    # --- manifest, for the merger and for the record
    $manifest = [ordered]@{
        generated = (Get-Date).ToUniversalTime().ToString('o')
        buildDir = $BuildDir
        outDir = $OutDir
        packMode = $(if ($FullPack) { 'full-pack' } else { 'task-scoped' })
        crossdocSplit = [bool]$splitReason
        crossdocSplitReason = $splitReason
        maxTokens = $MaxTokens
        packInclude = $PackInclude
        inputs = $p
        packDocs = @($packDocs | ForEach-Object { [ordered]@{ name = $_.Name + '.txt'; audience = $_.Audience } })
        classifiedFrom = $corpus.ClassifiedFrom
        referenceKinds = @($kinds | ForEach-Object { [ordered]@{ kind = $_.Kind; prefix = $_.Prefix; label = $_.Label; doc = $_.DocStem; how = $_.How } })
        topicCount = $topicCount
        sharedSlides = $sharedSlides.ToArray()
        backMatter = $guide.BackReason
        topics = $manifestTopics.ToArray()
        packs = @($packRows | ForEach-Object { [ordered]@{ name = $_.Name; dir = $_.Dir; kb = $_.KB; chars = $_.Chars; tokens = $_.Tokens; sharedTokens = $_.SharedTokens; specificTokens = $_.SpecificTokens; withinBudget = $_.WithinBudget; files = @($_.Files | ForEach-Object { [ordered]@{ name = $_.Name; bytes = $_.Bytes; chars = $_.Chars; tokens = $_.Tokens } }) } })
        overBudget = $over.ToArray()
        notes = $result.Notes.ToArray()
        expectedReviewers = @(@($packRows | ForEach-Object { $_.Name }))
    }
    Write-Utf8File -Path (Join-Path $OutDir 'manifest.json') -Content (($manifest | ConvertTo-Json -Depth 14) + "`r`n")

    $result.Packs = $packRows.ToArray()
    $result.OverBudget = $over.ToArray()
    $result.Manifest = $manifest
    if ($over.Count -gt 0) {
        $result.ExitCode = 1
        foreach ($name in $over) {
            $r = $packRows | Where-Object { $_.Name -eq $name } | Select-Object -First 1
            $hint = if ($r.SharedTokens -gt $MaxTokens) { ("the SHARED material alone is {0:N0} tokens, so splitting the topic cannot fix it: narrow -PackInclude on purpose, or raise -MaxTokens on purpose" -f $r.SharedTokens) } elseif ($name -like 'crossdoc*') { 'raise -MaxTokens on purpose, or narrow what the cross-document reviewer is handed' } else { 'split the topic, or raise -MaxTokens on purpose' }
            $result.Errors.Add(("{0} is {1:N0} tokens against a budget of {2:N0} - {3}." -f $name, $r.Tokens, $MaxTokens, $hint))
        }
    }
    return $result
}

# ---------------------------------------------------------------------------
# 7. Self-test: a synthetic two-topic build, cut in every mode and asserted
# ---------------------------------------------------------------------------

function Invoke-ReviewPackSelfTest {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("reviewpack-selftest-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $b = Join-Path $root 'build'
    $cr = Join-Path $b 'cleanroom'
    New-Item -ItemType Directory -Path (Join-Path $cr 'pack') -Force | Out-Null
    $fails = New-Object System.Collections.Generic.List[string]
    function Assert-True { param([bool] $Cond, [string] $What) if ($Cond) { Write-Host ("  PASS  {0}" -f $What) -ForegroundColor Green } else { Write-Host ("  FAIL  {0}" -f $What) -ForegroundColor Red; $fails.Add($What) } }

    try {
        $guideLines = @(
            '', 'LEARNER GUIDE', 'Contents',
            'Topic 1 - Alpha PAGEREF _Toc1 \h 5',
            'Topic 2 - Beta PAGEREF _Toc2 \h 9',
            'Assessment overview',
            'Knowledge Task 1(a) is prepared in 1.1',
            'Topic 1 - Alpha',
            'Learning outcomes',
            '1.1  First thing',
            'Hold at 4 degrees C for 2 hours. Hold at 4 degrees C for 2 hours.',
            'Figure 1.1.1 - A caption for the first figure',
            'Topic 2 - Beta',
            '2.1  Second thing',
            'Freeze at minus 18 degrees C under Standard 3.2.2 clause 7.',
            'Where to find your self-check answers - Topic 2',
            'Appendix 1 - Legislation',
            'Food Act 2001 applies on Thursday at 12 noon.',
            '=== FIGURE ALT TEXT ===',
            '* alt one with 350 Gms'
        )
        Write-Utf8File -Path (Join-Path $cr 'guide_r1.txt') -Content (Join-TextLines -Lines $guideLines)
        Write-Utf8File -Path (Join-Path $cr 'guide_r0.txt') -Content (Join-TextLines -Lines @('OLD ROUND - must not be picked', 'Topic 1 - Old'))
        $deckLines = @(
            '=== SLIDE 1 ===', 'TITLE', '1', '',
            '=== SLIDE 2 ===', 'TOPIC 1', 'Alpha', '2', '',
            '=== SLIDE 3 ===', '1.1 FIRST THING', 'Hold at 4 degrees C.', '3', '', 'Prepares you for: Knowledge Task 1(a)', '--- notes ---', 'The venue has adopted 4 degrees C; the Code allows 5 degrees C.', '', '3', '',
            '=== SLIDE 4 ===', 'TOPIC 2', 'Beta', '4', '',
            '=== SLIDE 5 ===', '2.1 SECOND THING', 'Freeze at minus 18 degrees C.', '5', '',
            '=== SLIDE 6 ===', 'ASSESSMENT BRIEFING', 'Ten portions of 350 Gms.', '6', ''
        )
        Write-Utf8File -Path (Join-Path $cr 'deck_r1.txt') -Content (Join-TextLines -Lines $deckLines)
        $plan = @(
            [ordered]@{ LayoutSlide = 1; Tag = 'title'; Kind = 'title' },
            [ordered]@{ LayoutSlide = 3; Topic = 1; Tag = 'T1 divider'; Kind = 'divider' },
            [ordered]@{ LayoutSlide = 4; Topic = 1; Tag = '1.1 slide 1'; Kind = 'teaching' },
            [ordered]@{ LayoutSlide = 3; Topic = 2; Tag = 'T2 divider'; Kind = 'divider' },
            [ordered]@{ LayoutSlide = 4; Topic = 2; Tag = '2.1 slide 1'; Kind = 'teaching' },
            [ordered]@{ LayoutSlide = 4; Tag = 'briefing'; Kind = 'teaching' }
        )
        Write-Utf8File -Path (Join-Path $b 'deckplan.json') -Content (($plan | ConvertTo-Json -Depth 5) + "`r`n")
        $sheetLines = @(
            'FIGURE SHEET - every planned visual on the spine, as plain text', 'SPINE-FINGERPRINT: abc', 'SLOTS: 3', '',
            '-------------------------------------------------------------------', 'SLOT 1.1.1   kind: Image   spine file: t1_1.1.json', '', '  caption: first', '',
            '-------------------------------------------------------------------', 'SLOT 2.1.1   kind: Diagram   spine file: t2_2.1.json', '', '  caption: second', '',
            '-------------------------------------------------------------------', 'SLOT (no slot declared)   kind: Image   spine file: front.json', '', '  caption: orphan', ''
        )
        Write-Utf8File -Path (Join-Path $b 'figure-sheet.txt') -Content (Join-TextLines -Lines $sheetLines)

        #  Two learner tools with a Contents block, and their assessor guides, whose task
        #  regions carry distinct benchmark markers so a slice can be proved right.
        $dash = [string][char]0x2014
        $toolLines = @('UNIT Knowledge tool', ('TOC \o "1-2" \h \z \u Instructions PAGEREF _T1 \h 2'), ("Task 1 $dash Terms PAGEREF _T2 \h 4"), ("Task 2 $dash Uses PAGEREF _T3 \h 6"), 'Instructions', 'Answer every task.', ("Task 1 $dash Terms"), '(a)  Define the term. LEARNER TASK ONE', ("Task 2 $dash Uses"), '(a)  Describe the use. LEARNER TASK TWO')
        Write-Utf8File -Path (Join-Path $cr 'pack\UNIT_Knowledge.txt') -Content (Join-TextLines -Lines $toolLines)
        $agToolLines = @('UNIT Knowledge assessor guide', ('TOC \o "1-2" \h \z \u Marking PAGEREF _A1 \h 2'), ("Task 1 $dash Terms PAGEREF _A2 \h 4"), ("Task 2 $dash Uses PAGEREF _A3 \h 6"), 'Appendix C - Oral questioning PAGEREF _A4 \h 9', 'Marking', 'Mark to the benchmark.', ("Task 1 $dash Terms"), '(a)  Define the term.', 'Assessor benchmark', 'BENCHMARK ONE', ("Task 2 $dash Uses"), '(a)  Describe the use.', 'Assessor benchmark', 'BENCHMARK TWO', 'Appendix C - Oral questioning', 'ORAL RECORD')
        Write-Utf8File -Path (Join-Path $cr 'pack\Assessor_Guide_UNIT_Knowledge.txt') -Content (Join-TextLines -Lines $agToolLines)
        $bookLines = @('UNIT Workbook', ('TOC \o "1-2" \h \z \u Workbook tasks PAGEREF _B1 \h 2'), ("Task 1 $dash Select PAGEREF _B2 \h 4"), ("Task 2 $dash Equipment PAGEREF _B3 \h 6"), 'Workbook tasks', ("Task 1 $dash Select"), '(a)  List the documents. LEARNER BOOK ONE', ("Task 2 $dash Equipment"), '(b)  Name the machine. LEARNER BOOK TWO')
        Write-Utf8File -Path (Join-Path $cr 'pack\UNIT_Workbook.txt') -Content (Join-TextLines -Lines $bookLines)
        $agBookLines = @('UNIT Workbook assessor guide', ('TOC \o "1-2" \h \z \u Workbook tasks PAGEREF _C1 \h 2'), ("Task 1 $dash Select PAGEREF _C2 \h 4"), ("Task 2 $dash Equipment PAGEREF _C3 \h 6"), 'Observation 1Select PAGEREF _C4 \h 8', 'Observation 2Equipment PAGEREF _C5 \h 9', 'Assessor records PAGEREF _C6 \h 10', 'Workbook tasks', ("Task 1 $dash Select"), '(a)  List the documents.', 'Assessor benchmark', 'BOOK BENCHMARK ONE', ("Task 2 $dash Equipment"), '(b)  Name the machine.', 'Assessor benchmark', 'BOOK BENCHMARK TWO', 'Observation 1Select', 'CHECKLIST ONE', 'Observation 2Equipment', 'CHECKLIST TWO', 'Assessor records', 'RECORDS')
        Write-Utf8File -Path (Join-Path $cr 'pack\Assessor_Guide_UNIT_Workbook.txt') -Content (Join-TextLines -Lines $agBookLines)
        Write-Utf8File -Path (Join-Path $cr 'pack\ignore.md') -Content 'not a pack extract'
        Write-Utf8File -Path (Join-Path $b 'unit_extract.md') -Content (Join-TextLines -Lines @('# unit', '- **KE1** first point', '- **KE2** second point', '  - KE2a sub'))
        $contract = [ordered]@{
            topics = @([ordered]@{ n = 1; title = 'Alpha'; pcs = @('1.1') }, [ordered]@{ n = 2; title = 'Beta'; pcs = @('2.1') })
            terminology = [ordered]@{ '_rule' = 'one word'; 'cook-chill' = 'cook-chill (hyphenated)'; 'chill' = "chill (bring down); never 'cool down' or 'refrigerate' as a synonym"; 'grams' = 'Gms - never g, G or gms' }
            referenceConvention = [ordered]@{
                knowledge = 'Knowledge Task {n}({part})'; knowledgeMeans = 'Task {n} in UNIT_Knowledge.docx'
                workbook = 'Workbook Task {n}({part})'; workbookMeans = 'Task {n} in UNIT_Workbook.docx'
                observation = 'Observation {n}'; observationMeans = 'Observation checklist {n} in the Workbook assessor guide'
                questionPattern = '\b(?:Knowledge Task|Workbook Task|Observation)\s?(\d+)\s?(\([a-z]\))?'
            }
            questionMap = [ordered]@{ '1.1' = @('Knowledge Task 1(a)', 'Workbook Task 1(a)', 'Observation 1'); '2.1' = @('Knowledge Task 2(a)', 'Workbook Task 2(b)', 'Observation 2') }
        }
        Write-Utf8File -Path (Join-Path $b 'contract.json') -Content (($contract | ConvertTo-Json -Depth 6) + "`r`n")
        $figs = [ordered]@{ figures = @(); mirrorAllow = @([ordered]@{ slot = '1.1.4'; reason = 'the single worked exemplar row, cleared on reading Knowledge Task 1' }); leakageAllow = @([ordered]@{ phrase = 'the recipe of record'; reason = 'a phrase the pack itself uses in its own instructions to the learner' }) }
        Write-Utf8File -Path (Join-Path $b 'figures.json') -Content (($figs | ConvertTo-Json -Depth 6) + "`r`n")

        Write-Host ''
        Write-Host "$GATE self-test - synthetic two-topic build at $root" -ForegroundColor Cyan

        # --- default mode
        $o1 = Join-Path $root 'out1'
        $r = Invoke-ReviewPack -BuildDir $b -OutDir $o1 -Given @{} -PackInclude @('*.txt') -MaxTokens 180000 -Quiet
        Assert-True ($r.ExitCode -eq 0) ("default mode cuts within budget (exit {0}; {1})" -f $r.ExitCode, ($r.Errors -join ' | '))
        Assert-True ((Test-Path (Join-Path $o1 'topic1')) -and (Test-Path (Join-Path $o1 'topic2')) -and (Test-Path (Join-Path $o1 'crossdoc'))) 'topic1, topic2 and crossdoc directories exist'
        $g1 = Get-GateFileText -Path (Join-Path $o1 'topic1\guide.txt')
        Assert-True ($g1.Contains('Hold at 4 degrees C') -and $g1.Contains('Assessment overview') -and $g1.Contains('Appendix 1 - Legislation') -and $g1.Contains('=== FIGURE ALT TEXT ===')) 'topic1 guide carries its body, the front matter, the back matter and the alt block'
        Assert-True (-not $g1.Contains('Freeze at minus 18')) 'topic1 guide does NOT carry Topic 2 body'
        Assert-True ($g1.Contains('full-extract lines 8-12') -and -not $g1.Contains('OLD ROUND')) 'the banner states the source line range, and the newest round extract was picked'
        $d2 = Get-GateFileText -Path (Join-Path $o1 'topic2\deck.txt')
        Assert-True ($d2.Contains('=== SLIDE 1 ===') -and $d2.Contains('=== SLIDE 6 ===') -and $d2.Contains('=== SLIDE 4 ===') -and $d2.Contains('=== SLIDE 5 ===') -and -not $d2.Contains('=== SLIDE 3 ===')) 'topic2 deck carries the shared slides and its own, not a Topic 1 slide'
        $d1 = Get-GateFileText -Path (Join-Path $o1 'topic1\deck.txt')
        Assert-True ($d1.Contains('--- notes ---') -and $d1.Contains('The venue has adopted')) 'slide blocks travel whole, speaker notes included'
        $f1 = Get-GateFileText -Path (Join-Path $o1 'topic1\figure-sheet.txt')
        Assert-True ($f1.Contains('SLOT 1.1.1') -and -not $f1.Contains('SLOT 2.1.1') -and $f1.Contains('no slot declared') -and $f1.Contains('SPINE-FINGERPRINT')) 'topic1 figure sheet carries its own slots, the slot-less block and the header'
        $have1 = @(Get-ChildItem -LiteralPath (Join-Path $o1 'topic1') -File | ForEach-Object { $_.Name })
        Assert-True (($have1 -contains 'UNIT_Knowledge.txt') -and ($have1 -contains 'UNIT_Workbook.txt') -and (-not ($have1 -contains 'ignore.md'))) 'topic1 carries both learner tools, filtered by -PackInclude'
        $lt = Get-GateFileText -Path (Join-Path $o1 'topic1\UNIT_Knowledge.txt')
        Assert-True ($lt.Contains('LEARNER TASK ONE') -and $lt.Contains('LEARNER TASK TWO')) 'a learner tool travels WHOLE, every task, in a topic pack'
        $ag1 = Get-GateFileText -Path (Join-Path $o1 'topic1\Assessor_Guide_UNIT_Knowledge.txt')
        Assert-True ($ag1.Contains('BENCHMARK ONE') -and -not $ag1.Contains('BENCHMARK TWO') -and -not $ag1.Contains('ORAL RECORD')) 'the knowledge assessor guide is SLICED to the task Topic 1 prepares - its benchmark in, Task 2''s and the appendix out'
        Assert-True ($ag1 -match '==== Task 1 . Terms: source lines 8-11 \(for Knowledge Task 1\(a\)\) ====') 'the region banner carries the heading, the source line range and the reference'
        $ag1b = Get-GateFileText -Path (Join-Path $o1 'topic1\Assessor_Guide_UNIT_Workbook.txt')
        Assert-True ($ag1b.Contains('BOOK BENCHMARK ONE') -and $ag1b.Contains('CHECKLIST ONE') -and -not $ag1b.Contains('BOOK BENCHMARK TWO') -and -not $ag1b.Contains('CHECKLIST TWO') -and -not $ag1b.Contains('RECORDS')) 'the workbook assessor guide is sliced to Task 1 AND its Observation 1 region, nothing else'
        $ag2 = Get-GateFileText -Path (Join-Path $o1 'topic2\Assessor_Guide_UNIT_Knowledge.txt')
        Assert-True ($ag2.Contains('BENCHMARK TWO') -and -not $ag2.Contains('BENCHMARK ONE')) 'topic2 gets Task 2''s benchmark and not Task 1''s'
        Assert-True ($ag1.Contains('mirror gate over the whole spine')) 'the assessor slice banner says cross-topic mirroring is the mirror gate''s job'
        $s1 = Get-GateFileText -Path (Join-Path $o1 'topic1\SCOPE.md')
        Assert-True ($s1.Contains('SCOPE: Topic 1 - Alpha') -and $s1.Contains('sub-sections 1.1') -and $s1.Contains('deck slides 2-3') -and $s1.Contains('figure slots 1.1.1')) 'SCOPE.md names the topic, its sub-sections, slides and slots'
        Assert-True ($s1.Contains('Knowledge Task 1, Observation 1, Workbook Task 1') -and $s1.Contains('FROM THE ASSESSOR GUIDES YOU HOLD ONLY') -and $s1.Contains('mirror gate') -and $s1.Contains('class leak')) 'SCOPE.md names the assigned tasks, says the assessor guides are sliced, says mirroring is the gate''s job, and still requires a seen leak to be reported'
        Assert-True (($have1 -contains 'unit_extract.md') -and ($have1 -contains 'allow-list.txt')) 'topic1 carries the unit extract and allow-list.txt'
        $a1 = Get-GateFileText -Path (Join-Path $o1 'topic1\allow-list.txt')
        $a2 = Get-GateFileText -Path (Join-Path $o1 'topic2\allow-list.txt')
        Assert-True ($a1.Contains('1.1.4: the single worked exemplar') -and $a1.Contains('the recipe of record:') -and (-not $a2.Contains('1.1.4:')) -and $a2.Contains('the recipe of record:')) 'allow-lists: mirror clearances by topic, every leakage clearance everywhere'
        $haveC = @(Get-ChildItem -LiteralPath (Join-Path $o1 'crossdoc') -File | ForEach-Object { $_.Name })
        Assert-True (($haveC -contains 'UNIT_Knowledge.txt') -and ($haveC -contains 'UNIT_Workbook.txt') -and (@($haveC | Where-Object { $_ -like 'Assessor_*' }).Count -eq 0)) 'crossdoc carries the learner tools and NO assessor guide'
        $cd = Get-GateFileText -Path (Join-Path $o1 'crossdoc\claims-digest.txt')
        Assert-True ($cd.Contains('4 degrees c') -and ($cd -match 'TERM-ONLY SENTENCES DROPPED FROM PART B: \d+')) 'crossdoc carries a digest that saw the guide and counts the term-only sentences it dropped'
        $cf = Get-GateFileText -Path (Join-Path $o1 'crossdoc\figure-sheet.txt')
        Assert-True ($cf.Contains('SLOT 1.1.1') -and $cf.Contains('SLOT 2.1.1') -and (Test-Path (Join-Path $o1 'crossdoc\figures.json'))) 'crossdoc carries the FULL figure sheet and figures.json'
        $mf = Get-GateJson -Path (Join-Path $o1 'manifest.json')
        Assert-True (@($mf.expectedReviewers).Count -eq 3 -and $mf.packMode -eq 'task-scoped' -and -not $mf.crossdocSplit) 'manifest names three expected reviewers, task-scoped mode, no split'
        Assert-True (@($mf.topics[0].tasks) -contains 'Workbook Task 1' -and @($mf.topics[0].assessorSlices).Count -eq 2) 'manifest records each topic''s assigned tasks and assessor slices'

        # --- -FullPack mode
        $o2 = Join-Path $root 'out2'
        $r2 = Invoke-ReviewPack -BuildDir $b -OutDir $o2 -Given @{} -PackInclude @('*.txt') -MaxTokens 180000 -FullPack -Quiet
        $agF = Get-GateFileText -Path (Join-Path $o2 'topic1\Assessor_Guide_UNIT_Knowledge.txt')
        Assert-True ($r2.ExitCode -eq 0 -and $agF.Contains('BENCHMARK ONE') -and $agF.Contains('BENCHMARK TWO') -and $agF.Contains('ORAL RECORD')) '-FullPack hands the assessor guide whole'
        $haveC2 = @(Get-ChildItem -LiteralPath (Join-Path $o2 'crossdoc') -File | ForEach-Object { $_.Name })
        Assert-True (@($haveC2 | Where-Object { $_ -like 'Assessor_*' }).Count -eq 2 -and (Get-GateJson -Path (Join-Path $o2 'manifest.json')).packMode -eq 'full-pack') '-FullPack crossdoc carries the assessor guides too, and the manifest says full-pack'

        # --- forced crossdoc split
        $o3 = Join-Path $root 'out3'
        $r3 = Invoke-ReviewPack -BuildDir $b -OutDir $o3 -Given @{} -PackInclude @('*.txt') -MaxTokens 180000 -CrossdocSplit Always -Quiet
        $mf3 = Get-GateJson -Path (Join-Path $o3 'manifest.json')
        Assert-True ($r3.ExitCode -eq 0 -and (Test-Path (Join-Path $o3 'crossdoc-values')) -and (Test-Path (Join-Path $o3 'crossdoc-refs')) -and -not (Test-Path (Join-Path $o3 'crossdoc'))) '-CrossdocSplit Always cuts crossdoc-values and crossdoc-refs and no single crossdoc'
        Assert-True ((@($mf3.expectedReviewers) -contains 'crossdoc-values') -and (@($mf3.expectedReviewers) -contains 'crossdoc-refs') -and -not (@($mf3.expectedReviewers) -contains 'crossdoc') -and $mf3.crossdocSplit) 'the manifest expects both halves and not the single pack'
        $dv = Get-GateFileText -Path (Join-Path $o3 'crossdoc-values\claims-digest.txt')
        $dr = Get-GateFileText -Path (Join-Path $o3 'crossdoc-refs\claims-digest.txt')
        Assert-True ($dv.Contains('-- num (') -and -not $dv.Contains('-- instr (') -and $dr.Contains('-- instr (') -and -not $dr.Contains('-- num (')) 'the values digest indexes numbers and not citations; the refs digest the reverse'
        Assert-True ($dv.Contains('-- attrib (') -and $dr.Contains('-- attrib (')) 'adoption language is in both digests'
        $sv = Get-GateFileText -Path (Join-Path $o3 'crossdoc-values\SCOPE.md')
        $sr = Get-GateFileText -Path (Join-Path $o3 'crossdoc-refs\SCOPE.md')
        Assert-True ($sv.Contains('SCOPE: cross-document agreement - VALUES') -and $sv.Contains('reviewer "crossdoc-values"') -and $sr.Contains('SCOPE: cross-document agreement - REFERENCES') -and $sr.Contains('reviewer "crossdoc-refs"')) 'each half''s SCOPE.md says which half it is and which reviewer name to write'

        # --- automatic split when the single pack is over budget, and the budget gate
        $single = @($r.Packs | Where-Object { $_.Name -eq 'crossdoc' })[0]
        $o4 = Join-Path $root 'out4'
        $r4 = Invoke-ReviewPack -BuildDir $b -OutDir $o4 -Given @{} -PackInclude @('*.txt') -MaxTokens ($single.Tokens - 1) -Quiet
        Assert-True ((Test-Path (Join-Path $o4 'crossdoc-values')) -and -not (Test-Path (Join-Path $o4 'crossdoc'))) 'Auto splits crossdoc when the single pack exceeds the budget'
        $r5 = Invoke-ReviewPack -BuildDir $b -OutDir (Join-Path $root 'out5') -Given @{} -PackInclude @('*.txt') -MaxTokens 10 -Quiet
        Assert-True ($r5.ExitCode -eq 1 -and @($r5.OverBudget).Count -ge 3) ("the budget gate FAILS on an over-large pack (exit {0}, {1} over)" -f $r5.ExitCode, @($r5.OverBudget).Count)
        Assert-True (@($r5.Errors | Where-Object { $_ -match 'SHARED material alone' }).Count -gt 0) 'and says when the shared material alone exceeds the budget'

        # --- refusals
        $badPlan = Join-Path $root 'badplan.json'
        Write-Utf8File -Path $badPlan -Content ((@($plan[0..4]) | ConvertTo-Json -Depth 5) + "`r`n")
        $r6 = Invoke-ReviewPack -BuildDir $b -OutDir (Join-Path $root 'out6') -Given @{ deckPlan = $badPlan } -PackInclude @('*.txt') -MaxTokens 180000 -Quiet
        Assert-True ($r6.ExitCode -eq 2 -and @($r6.Errors | Where-Object { $_ -match 'entries but the deck extract has' }).Count -gt 0) 'a deckplan whose count differs from the extract is REFUSED'
        $badGuide = Join-Path $root 'badguide.txt'
        Write-Utf8File -Path $badGuide -Content (Join-TextLines -Lines ($guideLines + @('Topic 1 - Alpha again')))
        $r7 = Invoke-ReviewPack -BuildDir $b -OutDir (Join-Path $root 'out7') -Given @{ guideExtract = $badGuide } -PackInclude @('*.txt') -MaxTokens 180000 -Quiet
        Assert-True ($r7.ExitCode -eq 2 -and @($r7.Errors | Where-Object { $_ -match 'appears twice' }).Count -gt 0) 'a guide with a duplicated Topic heading is REFUSED'
        $badFigs = Join-Path $root 'badfigs.json'
        Write-Utf8File -Path $badFigs -Content (([ordered]@{ figures = @(); mirrorAllow = @([ordered]@{ slot = '1.1.4' }) } | ConvertTo-Json -Depth 6) + "`r`n")
        $r8 = Invoke-ReviewPack -BuildDir $b -OutDir (Join-Path $root 'out8') -Given @{ figuresJson = $badFigs } -PackInclude @('*.txt') -MaxTokens 180000 -Quiet
        Assert-True ($r8.ExitCode -eq 2 -and @($r8.Errors | Where-Object { $_ -match 'allow-list' }).Count -gt 0) 'an allow-list entry with no written reason is REFUSED, as the gates refuse it'
        $noMap = Join-Path $root 'nomap.json'
        $c2 = [ordered]@{ topics = $contract.topics; terminology = $contract.terminology; referenceConvention = $contract.referenceConvention }
        Write-Utf8File -Path $noMap -Content (($c2 | ConvertTo-Json -Depth 6) + "`r`n")
        $r9 = Invoke-ReviewPack -BuildDir $b -OutDir (Join-Path $root 'out9') -Given @{ contract = $noMap } -PackInclude @('*.txt') -MaxTokens 180000 -Quiet
        Assert-True ($r9.ExitCode -eq 2 -and @($r9.Errors | Where-Object { $_ -match 'no questionMap' -and $_ -match '-FullPack' }).Count -gt 0) 'a contract with no questionMap is REFUSED in the default mode and pointed at -FullPack'
        $r10 = Invoke-ReviewPack -BuildDir $b -OutDir (Join-Path $root 'out10') -Given @{ contract = $noMap } -PackInclude @('*.txt') -MaxTokens 180000 -FullPack -Quiet
        Assert-True ($r10.ExitCode -eq 0) 'and -FullPack cuts it anyway'
    }
    finally {
        if ($root -and (Test-Path -LiteralPath $root) -and $root.Length -gt 12) { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    Write-Host ''
    if ($fails.Count -gt 0) { Write-Host ("  X self-test: {0} assertion(s) failed" -f $fails.Count) -ForegroundColor Red; return 4 }
    Write-Host '  self-test: every assertion held. This cutter can refuse.' -ForegroundColor Green
    return 0
}

# ---------------------------------------------------------------------------
# Entry
# ---------------------------------------------------------------------------

if ($SelfTest) { exit (Invoke-ReviewPackSelfTest) }

if (-not $BuildDir) {
    Write-Host "$GATE`: usage: New-ReviewPack.ps1 -BuildDir <build> [-OutDir <dir>] [-MaxTokens 180000] [-FullPack] [-CrossdocSplit Auto|Always|Never] [-PackInclude *.txt] [overrides] | -SelfTest" -ForegroundColor Red
    exit 2
}
if (-not $OutDir) { $OutDir = Join-Path $BuildDir 'cleanroom\review' }

$overrides = @{ guideExtract = $GuideExtract; deckExtract = $DeckExtract; packDir = $PackDir; figureSheet = $FigureSheet; deckPlan = $DeckPlan; unitExtract = $UnitExtract; figuresJson = $FiguresJson; contract = $Contract }
$run = Invoke-ReviewPack -BuildDir $BuildDir -OutDir $OutDir -Given $overrides -PackInclude $PackInclude -MaxTokens $MaxTokens -FullPack:$FullPack -CrossdocSplit $CrossdocSplit -Quiet:$Quiet

foreach ($e in $run.Errors) { Write-Host ("  X {0}" -f $e) -ForegroundColor Red }
if ($run.ExitCode -eq 0) {
    Write-Host ("  {0} pack(s) written to {1}, every one within {2:N0} tokens" -f @($run.Packs).Count, $OutDir, $MaxTokens) -ForegroundColor Green
}
elseif ($run.ExitCode -eq 1) {
    Write-Host ("  X {0} pack(s) exceed the budget. Nothing was truncated - the packs are complete and the decision is yours." -f @($run.OverBudget).Count) -ForegroundColor Red
}
exit $run.ExitCode
