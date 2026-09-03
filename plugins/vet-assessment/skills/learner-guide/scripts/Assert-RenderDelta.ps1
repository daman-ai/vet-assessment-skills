<#
    Assert-RenderDelta.ps1 - which TOPICS actually changed in this render.

    WHY IT EXISTS. The ledger's staleness rule for the reading stages (4b
    readability, 5 personas, 6 clean-room audit) compared timestamps: any
    record older than the newest render was stale, whole. On one build a
    one-word fix in Topic 3 therefore invalidated every reader's record for
    all seven topics and forced a full re-review wave - 35 to 45 minutes -
    after every one of six rounds. The personas were never re-run after round
    1, because a rule that demands seven re-reads for one word is a rule
    nobody meets, and a blocking rule nobody meets is a rule that gets waived.

    A per-topic content hash makes the rule both satisfiable and honest. A
    topic whose rendered text, slides and figure content did not change keeps
    its review record; a topic that changed re-queues every reading stage for
    that topic and no other. The ledger (Stage-Ledger.ps1) reads what this
    writes; this file dot-sources the ledger so both use ONE definition of
    "this topic moved".

    WHAT IS HASHED, PER TOPIC. Three arms, each a SHA256 over normalised text:
      guide    the topic's slice of the guide extract, cut at the body's
               "Topic N - Title" heading lines exactly as New-ReviewPack cuts
               a reviewer's pack (Contents lines carrying PAGEREF are not
               headings). Front matter and back matter are topic 0.
      deck     the topic's slides, mapped by POSITION from deckplan.json - the
               plan must have one entry per slide or the run is refused, as
               the review pack refuses it, because a count mismatch would
               silently hash slides against the wrong topic. Slides with no
               Topic in the plan (title, agenda, briefing, thanks) are topic 0.
               Every divider slide the plan declares is checked to carry its
               own topic number, so a shifted plan cannot pass unnoticed.
      figures  the topic's slot blocks of figure-sheet.txt (the slot's leading
               integer is its topic); the sheet's preamble is topic 0.

    THE ALT-TEXT BLOCK IS ATTRIBUTED, NOT LUMPED. Get-DocText appends every
    drawing's alt text after the body, so a plain cut would put every figure's
    alt text into the last topic and a changed Topic 4 alt text would report
    as Topic 7. Each alt line is matched to the figure sheet's own alt text
    and credited to that slot's topic; a line matching no slot (the mark, a
    cover image) is topic 0; a line matching slots in more than one topic is
    credited to every one of them, so a change can only over-queue, never
    under-queue. The counts are printed so the attribution is visible.

    THREE NORMALISATIONS, AND NO MORE. Trailing whitespace; Word's TOC
    bookmark ids (_Toc123456789), which no reader can see and which change on
    every render; and the extract's own provenance stamp plus the figure
    sheet's SPINE-FINGERPRINT, GENERATED and SOURCE lines, which describe the
    extract and the sheet, not the document. Page numbers in the Contents are
    visible and are KEPT, so topic 0 reports changed when pagination moves.
    That is honest, and it is cheap: topic 0 is the smallest slice.

    OUTPUT. render-delta.json in the build directory:
      { renderedAt, guide, deck, figureSheet, deckPlan,
        guideSha, deckSha, figureSheetSha, guideStamp, deckStamp,
        topics: { "0": { guide, deck, figures, words: {guide, deck, figures},
                         guideLines, slides, slots }, "1": {...}, ... },
        previous: null | { path, sha, changed: [..], unchanged: [..], removed: [..], why: {..} },
        notes: [..] }
    Every delta is also archived as render-deltas\<sha256 of the file>.json,
    and the sha is printed: it is what a review record carries as -DeltaSha,
    and it is what lets the ledger diff a record against the exact render it
    was issued against, however many renders later.

    TRUSTED ONLY AFTER FAILING ON A PLANTED DEFECT. -SelfTest recomputes the
    delta from the same inputs and requires no change, then plants one
    altered word in one topic of a COPY of the guide, of the deck and of the
    figure sheet in turn, verifies each plant landed, and requires exactly
    that one topic to report changed on exactly that arm. It runs BEFORE the
    delta is written, so a failed self-test leaves nothing for the ledger to
    trust.

    Usage:
      Assert-RenderDelta -BuildDir <build>
          reads <build>\guide_gate.txt and deck_gate.txt (what Run-Gates
          extracts), figure-sheet.txt and deckplan.json; writes render-delta.json
      Assert-RenderDelta -BuildDir <build> -Current g.txt,d.txt -Previous render-delta.json
      Assert-RenderDelta -BuildDir <build> -Current g6.txt,d6.txt -Previous g5.txt,d5.txt [-PreviousFigureSheet fs5.txt]
      Assert-RenderDelta -BuildDir <build> -OutPath <delta.json>   (archive goes beside it)
      Assert-RenderDelta -BuildDir <build> -SelfTest

    Exit 0 written, 2 an input could not be read or cut, 4 the self-test failed.
    PS 5.1. ASCII only in this file.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $BuildDir,
    #  The guide extract, then the deck extract. Both, always: a delta with no
    #  deck arm would declare every slide unchanged by never having looked.
    [string[]] $Current,
    #  A render-delta.json, or a previous guide extract and deck extract.
    [string[]] $Previous,
    [string] $PreviousFigureSheet,
    [string] $FigureSheet,
    [string] $DeckPlan,
    [string] $OutPath,
    [switch] $SelfTest,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
#  Passing -BuildDir through is deliberate: dot-sourcing a script that has a
#  param block binds ITS parameters in THIS scope, so an unqualified dot-source
#  would blank $BuildDir.
. (Join-Path $PSScriptRoot 'Stage-Ledger.ps1') -BuildDir $BuildDir

$GATE = 'Assert-RenderDelta'

# ---------------------------------------------------------------------------
# 1. Inputs, resolved and named
# ---------------------------------------------------------------------------

function Resolve-DeltaInput {
    param([string] $Given, [string] $Default, [string] $What)
    $p = if ($Given) { $Given } else { $Default }
    if (-not (Test-Path -LiteralPath $p)) {
        throw ("{0}: {1} not found at {2}. Run the extract (Get-DocText) and the figure sheet (New-FigureSheet) first; a delta cannot be cut from files that do not exist." -f $GATE, $What, $p)
    }
    return (Resolve-Path -LiteralPath $p).Path
}

$cur = @($Current | Where-Object { $_ })
if ($cur.Count -eq 0) {
    $cur = @((Join-Path $BuildDir 'guide_gate.txt'), (Join-Path $BuildDir 'deck_gate.txt'))
}
if ($cur.Count -ne 2) { Write-Host ("  X {0}: -Current takes exactly two files, the guide extract then the deck extract." -f $GATE) -ForegroundColor Red; exit 2 }

try {
    $guidePath = Resolve-DeltaInput -Given $cur[0] -Default '' -What 'guide extract'
    $deckPath  = Resolve-DeltaInput -Given $cur[1] -Default '' -What 'deck extract'
    $sheetPath = Resolve-DeltaInput -Given $FigureSheet -Default (Join-Path $BuildDir 'figure-sheet.txt') -What 'figure sheet'
    $planPath  = Resolve-DeltaInput -Given $DeckPlan -Default (Join-Path $BuildDir 'deckplan.json') -What 'deck plan'
}
catch { Write-Host ("  X " + $_.Exception.Message) -ForegroundColor Red; exit 2 }

if (-not $OutPath) { $OutPath = Join-Path $BuildDir $script:LedgerDeltaFile }
$outDir = Split-Path -Parent $OutPath
if (-not $outDir) { $outDir = '.' }
$archiveDir = Join-Path $outDir $script:LedgerDeltaArchive

# ---------------------------------------------------------------------------
# 2. Reading and cutting
# ---------------------------------------------------------------------------

function Read-TextLines {
    param([Parameter(Mandatory)][string] $Path)
    $t = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8).TrimStart([char]0xFEFF)
    return @($t -split "\r?\n")
}

function Get-TextSha {
    param([AllowEmptyString()][string] $Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes("$Text"))).Replace('-', '').ToLower() }
    finally { $sha.Dispose() }
}

function ConvertTo-HashText {
    # The whole normalisation: trailing whitespace and TOC bookmark ids. See the header.
    param([string[]] $Lines)
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($l in @($Lines)) { $out.Add(([regex]::Replace("$l".TrimEnd(), '_Toc\d+', '_Toc'))) }
    return ($out -join "`n")
}

function Measure-Words {
    param([string[]] $Lines)
    if (-not @($Lines).Count) { return 0 }
    return ([regex]::Matches((@($Lines) -join ' '), '\S+')).Count
}

function ConvertTo-AltKey {
    param([string] $Text)
    return (("$Text" -replace '\s+', ' ').Trim().ToLowerInvariant())
}

function Add-TopicLine {
    param([hashtable] $Map, [hashtable] $Where, [string] $Topic, [string] $Line, [int] $LineNo)
    if (-not $Map.ContainsKey($Topic)) { $Map[$Topic] = New-Object System.Collections.Generic.List[string]; $Where[$Topic] = New-Object System.Collections.Generic.List[int] }
    $Map[$Topic].Add($Line)
    if ($LineNo -gt 0) { $Where[$Topic].Add($LineNo) }
}

function Format-LineRanges {
    param([int[]] $Numbers, [int] $MaxRanges = 12)
    $n = @($Numbers | Sort-Object -Unique)
    if (-not $n.Count) { return '' }
    $ranges = New-Object System.Collections.Generic.List[string]
    $start = $n[0]; $prev = $n[0]
    for ($i = 1; $i -le $n.Count; $i++) {
        $isEnd = ($i -eq $n.Count)
        if ($isEnd -or $n[$i] -ne $prev + 1) {
            if ($start -eq $prev) { $ranges.Add("$start") } else { $ranges.Add("$start-$prev") }
            if (-not $isEnd) { $start = $n[$i] }
        }
        if (-not $isEnd) { $prev = $n[$i] }
    }
    if ($ranges.Count -gt $MaxRanges) { return ((@($ranges)[0..($MaxRanges - 1)] -join ', ') + (", ... ({0} ranges)" -f $ranges.Count)) }
    return ($ranges -join ', ')
}

function Read-Extract {
    <# Body lines with the Get-DocText stamp cut off and parsed; Offset is how many full-extract lines precede the body. #>
    param([Parameter(Mandatory)][string] $Path)
    $all = Read-TextLines -Path $Path
    $stamp = $null
    $start = 0
    if ($all.Count -and $all[0] -match '^FIGURES: (\d+) placed drawings, (\d+) unresolved artwork prompt blocks') {
        $stamp = [ordered]@{ placed = [int]$Matches[1]; prompts = [int]$Matches[2]; channels = ''; file = ''; sha256 = ''; extracted = '' }
        $i = 1
        while ($i -lt $all.Count -and $all[$i].Trim() -ne '') {
            if ($all[$i] -match '^CHANNELS:\s*(.*)$') { $stamp.channels = $Matches[1].Trim() }
            elseif ($all[$i] -match '^SOURCE:\s*(.+?)\s{2,}SHA256:\s*([0-9A-Fa-f-]+)\s{2,}EXTRACTED:\s*(\S+)') {
                $stamp.file = $Matches[1].Trim(); $stamp.sha256 = $Matches[2].Replace('-', '').ToLower(); $stamp.extracted = $Matches[3]
            }
            $i++
        }
        $start = [Math]::Min($i + 1, $all.Count)
    }
    $body = if ($start -lt $all.Count) { @($all[$start..($all.Count - 1)]) } else { @() }
    [pscustomobject]@{ Path = $Path; Leaf = (Split-Path $Path -Leaf); Lines = $body; Stamp = $stamp; Offset = $start; LineCount = $all.Count }
}

function Split-Sheet {
    <# Preamble (minus the sheet's own provenance lines), one block per separator, and alt text -> topics. Mirrors New-ReviewPack's Split-FigureSheet. #>
    param([Parameter(Mandatory)][string] $Path)
    $lines = Read-TextLines -Path $Path
    $header = New-Object System.Collections.Generic.List[string]
    $blocks = New-Object System.Collections.Generic.List[object]
    $altMap = @{}
    $cur = $null
    foreach ($ln in $lines) {
        if ($ln -match '^-{10,}\s*$') {
            if ($null -ne $cur) { $blocks.Add($cur) }
            $cur = [pscustomobject]@{ Slot = ''; Topic = '0'; Lines = (New-Object System.Collections.Generic.List[string]) }
            $cur.Lines.Add($ln)
            continue
        }
        if ($null -eq $cur) {
            if ($ln -notmatch '^(SPINE-FINGERPRINT|GENERATED|SOURCE):') { $header.Add($ln) }
            continue
        }
        $cur.Lines.Add($ln)
        if (-not $cur.Slot) {
            $m = [regex]::Match($ln, '^SLOT\s+(\S+)')
            if ($m.Success) {
                $cur.Slot = $m.Groups[1].Value
                $t = [regex]::Match($cur.Slot, '^(\d+)\.')
                if ($t.Success) { $cur.Topic = [string][int]$t.Groups[1].Value }
            }
        }
        $a = [regex]::Match($ln, '^\s*alt:\s*(.+?)\s*$')
        if ($a.Success) {
            $k = ConvertTo-AltKey -Text $a.Groups[1].Value
            if ($k) {
                if (-not $altMap.ContainsKey($k)) { $altMap[$k] = New-Object System.Collections.Generic.List[string] }
                if ($altMap[$k] -notcontains $cur.Topic) { $altMap[$k].Add($cur.Topic) }
            }
        }
    }
    if ($null -ne $cur) { $blocks.Add($cur) }
    [pscustomobject]@{ Path = $Path; Leaf = (Split-Path $Path -Leaf); Header = @($header); Blocks = $blocks; AltMap = $altMap; Lines = $lines }
}

function Split-Guide {
    <# Front | Topic 1..N | back, cut exactly as New-ReviewPack's Split-GuideExtract; the alt-text block attributed per slot. #>
    param([Parameter(Mandatory)] $Extract, [Parameter(Mandatory)] $Sheet)
    $lines = @($Extract.Lines)
    $heads = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $ln = $lines[$i]
        if ($ln -match 'PAGEREF') { continue }
        $m = [regex]::Match($ln, '^Topic (\d+) - (.+?)\s*$')
        if ($m.Success) { $heads.Add([pscustomobject]@{ Index = $i; Number = [int]$m.Groups[1].Value; Title = $m.Groups[2].Value }) }
    }
    if ($heads.Count -eq 0) { throw ("{0}: no ""Topic N - Title"" heading line in {1} (Contents lines carrying PAGEREF are ignored). A guide whose topics cannot be seen cannot be cut." -f $GATE, $Extract.Leaf) }
    $seen = @{}
    foreach ($h in $heads) {
        if ($seen.ContainsKey($h.Number)) { throw ("{0}: Topic {1} heading appears twice in {2}, at lines {3} and {4}. A heading cannot be told from a prose line that starts the same way, and guessing would hash content under the wrong topic." -f $GATE, $h.Number, $Extract.Leaf, ($seen[$h.Number] + $Extract.Offset + 1), ($h.Index + $Extract.Offset + 1)) }
        $seen[$h.Number] = $h.Index
    }
    for ($k = 0; $k -lt $heads.Count; $k++) {
        if ($heads[$k].Number -ne ($k + 1)) { throw ("{0}: topic headings in {1} are not 1..N in order: heading {2} is Topic {3}." -f $GATE, $Extract.Leaf, ($k + 1), $heads[$k].Number) }
    }

    $first = $heads[0].Index
    $last = $heads[$heads.Count - 1].Index
    $backStart = -1
    for ($j = $last + 1; $j -lt $lines.Count; $j++) {
        if ($lines[$j] -match '^(Appendix \d+\b|Appendices\b|Glossary\b|=== )') { $backStart = $j; break }
    }

    $map = @{}
    $where = @{}
    $off = $Extract.Offset + 1
    for ($i = 0; $i -lt $first; $i++) { Add-TopicLine -Map $map -Where $where -Topic '0' -Line $lines[$i] -LineNo ($i + $off) }
    for ($k = 0; $k -lt $heads.Count; $k++) {
        $start = $heads[$k].Index
        $end = if ($k + 1 -lt $heads.Count) { $heads[$k + 1].Index - 1 } elseif ($backStart -ge 0) { $backStart - 1 } else { $lines.Count - 1 }
        $t = [string]$heads[$k].Number
        for ($i = $start; $i -le $end; $i++) { Add-TopicLine -Map $map -Where $where -Topic $t -Line $lines[$i] -LineNo ($i + $off) }
        if (-not $map.ContainsKey($t)) { Add-TopicLine -Map $map -Where $where -Topic $t -Line '' -LineNo 0 }
    }

    $altAttributed = 0; $altUnmatched = 0; $altShared = 0
    if ($backStart -ge 0) {
        $inAlt = $false
        for ($i = $backStart; $i -lt $lines.Count; $i++) {
            $ln = $lines[$i]
            if ($ln -match '^=== FIGURE ALT TEXT ===') { $inAlt = $true; Add-TopicLine -Map $map -Where $where -Topic '0' -Line $ln -LineNo ($i + $off); continue }
            if ($inAlt -and $ln.StartsWith('* ')) {
                $k = ConvertTo-AltKey -Text $ln.Substring(2)
                if ($Sheet.AltMap.ContainsKey($k)) {
                    $owners = @($Sheet.AltMap[$k])
                    if ($owners.Count -gt 1) { $altShared++ }
                    foreach ($o in $owners) { Add-TopicLine -Map $map -Where $where -Topic $o -Line $ln -LineNo ($i + $off) }
                    $altAttributed++
                }
                else { Add-TopicLine -Map $map -Where $where -Topic '0' -Line $ln -LineNo ($i + $off); $altUnmatched++ }
                continue
            }
            Add-TopicLine -Map $map -Where $where -Topic '0' -Line $ln -LineNo ($i + $off)
        }
    }
    if (-not $map.ContainsKey('0')) { Add-TopicLine -Map $map -Where $where -Topic '0' -Line '' -LineNo 0 }

    [pscustomobject]@{
        Map = $map; Where = $where; Heads = $heads
        FrontLines = $first; BackStart = $backStart
        AltAttributed = $altAttributed; AltUnmatched = $altUnmatched; AltShared = $altShared
    }
}

function Split-Deck {
    <# One block per slide; topic by plan position; dividers verified. Mirrors New-ReviewPack's Split-DeckExtract and its refusal rule. #>
    param([Parameter(Mandatory)] $Extract, [Parameter(Mandatory)][string] $PlanPath)
    $lines = @($Extract.Lines)
    $pre = New-Object System.Collections.Generic.List[string]
    $slides = New-Object System.Collections.Generic.List[object]
    $cur = $null
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $ln = $lines[$i]
        $m = [regex]::Match($ln, '^=== SLIDE (\d+) ===\s*$')
        if ($m.Success) {
            if ($null -ne $cur) { $slides.Add($cur) }
            $cur = [pscustomobject]@{ Number = [int]$m.Groups[1].Value; Lines = (New-Object System.Collections.Generic.List[string]); FirstLine = ($i + $Extract.Offset + 1) }
        }
        if ($null -ne $cur) { $cur.Lines.Add($ln) } else { $pre.Add($ln) }
    }
    if ($null -ne $cur) { $slides.Add($cur) }
    if ($slides.Count -eq 0) { throw ("{0}: no ""=== SLIDE N ==="" marker in {1}." -f $GATE, $Extract.Leaf) }
    for ($k = 0; $k -lt $slides.Count; $k++) {
        if ($slides[$k].Number -ne ($k + 1)) { throw ("{0}: slide markers in {1} are not 1..N in order: block {2} is SLIDE {3}." -f $GATE, $Extract.Leaf, ($k + 1), $slides[$k].Number) }
    }

    $plan = @(Read-LedgerJson -Path $PlanPath)
    if ($plan.Count -ne $slides.Count) {
        throw ("{0}: {1} has {2} entries but {3} has {4} slides. Slides are mapped to topics by position, so a count mismatch would silently hash slides against the wrong topic - the same rule New-ReviewPack applies. Pass the plan the deck was rendered from." -f $GATE, (Split-Path $PlanPath -Leaf), $plan.Count, $Extract.Leaf, $slides.Count)
    }

    $map = @{}
    $where = @{}
    $byTopic = @{}
    foreach ($ln in $pre) { Add-TopicLine -Map $map -Where $where -Topic '0' -Line $ln -LineNo 0 }
    $dividersChecked = 0
    $misaligned = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $plan.Count; $i++) {
        $e = $plan[$i]
        $t = '0'
        if ($null -ne $e -and @($e.PSObject.Properties.Name) -contains 'Topic' -and $null -ne $e.Topic -and "$($e.Topic)" -ne '') { $t = [string][int]$e.Topic }
        $s = $slides[$i]
        foreach ($ln in $s.Lines) { Add-TopicLine -Map $map -Where $where -Topic $t -Line $ln -LineNo 0 }
        if (-not $byTopic.ContainsKey($t)) { $byTopic[$t] = New-Object System.Collections.Generic.List[int] }
        $byTopic[$t].Add($s.Number)
        if ($null -ne $e -and "$($e.Kind)" -eq 'divider' -and $t -ne '0') {
            $dividersChecked++
            $text = $s.Lines -join "`n"
            if ($text -notmatch ('(?i)\bTOPIC\s+0*' + $t + '\b')) { $misaligned.Add(("slide {0} is planned as the Topic {1} divider ('{2}') but its text does not say TOPIC {1}" -f $s.Number, $t, $e.Tag)) }
        }
    }
    if ($misaligned.Count) {
        throw ("{0}: {1} does not line up with {2}: {3}. A plan that is off by one hashes every slide under a neighbouring topic." -f $GATE, (Split-Path $PlanPath -Leaf), $Extract.Leaf, ($misaligned -join '; '))
    }
    [pscustomobject]@{ Map = $map; Where = $where; SlideCount = $slides.Count; PlanCount = $plan.Count; DividersChecked = $dividersChecked; ByTopic = $byTopic }
}

function New-RenderDelta {
    <# The delta object for one set of inputs, plus the cuts it was made from. #>
    param(
        [Parameter(Mandatory)][string] $GuidePath,
        [Parameter(Mandatory)][string] $DeckPath,
        [Parameter(Mandatory)][string] $SheetPath,
        [Parameter(Mandatory)][string] $PlanPath
    )
    $g = Read-Extract -Path $GuidePath
    $d = Read-Extract -Path $DeckPath
    $sheet = Split-Sheet -Path $SheetPath
    $gs = Split-Guide -Extract $g -Sheet $sheet
    $ds = Split-Deck -Extract $d -PlanPath $PlanPath

    $fmap = @{}
    $fwhere = @{}
    $slotsByTopic = @{}
    foreach ($ln in $sheet.Header) { Add-TopicLine -Map $fmap -Where $fwhere -Topic '0' -Line $ln -LineNo 0 }
    foreach ($b in $sheet.Blocks) {
        foreach ($ln in $b.Lines) { Add-TopicLine -Map $fmap -Where $fwhere -Topic $b.Topic -Line $ln -LineNo 0 }
        if ($b.Slot) {
            if (-not $slotsByTopic.ContainsKey($b.Topic)) { $slotsByTopic[$b.Topic] = 0 }
            $slotsByTopic[$b.Topic]++
        }
    }

    $universe = @(@($gs.Map.Keys) + @($ds.Map.Keys) + @($fmap.Keys) | Sort-Object -Unique | Sort-Object { [int]$_ })
    $topics = [ordered]@{}
    foreach ($t in $universe) {
        $gl = @(); $dl = @(); $fl = @()
        if ($gs.Map.ContainsKey($t)) { $gl = $gs.Map[$t].ToArray() }
        if ($ds.Map.ContainsKey($t)) { $dl = $ds.Map[$t].ToArray() }
        if ($fmap.ContainsKey($t))   { $fl = $fmap[$t].ToArray() }
        $entry = [ordered]@{
            guide   = (Get-TextSha -Text (ConvertTo-HashText -Lines $gl))
            deck    = (Get-TextSha -Text (ConvertTo-HashText -Lines $dl))
            figures = (Get-TextSha -Text (ConvertTo-HashText -Lines $fl))
            words   = [ordered]@{ guide = (Measure-Words -Lines $gl); deck = (Measure-Words -Lines $dl); figures = (Measure-Words -Lines $fl) }
            guideLines = $(if ($gs.Where.ContainsKey($t)) { Format-LineRanges -Numbers $gs.Where[$t].ToArray() } else { '' })
            slides  = $(if ($ds.ByTopic.ContainsKey($t)) { Format-LineRanges -Numbers $ds.ByTopic[$t].ToArray() } else { '' })
            slots   = $(if ($slotsByTopic.ContainsKey($t)) { [int]$slotsByTopic[$t] } else { 0 })
        }
        $topics[$t] = $entry
    }

    $notes = New-Object System.Collections.Generic.List[string]
    $notes.Add(("guide cut at {0} topic heading(s); front matter {1} line(s); back matter {2}" -f $gs.Heads.Count, $gs.FrontLines, $(if ($gs.BackStart -ge 0) { "from body line $($gs.BackStart + $g.Offset + 1)" } else { 'none - the last topic runs to the end' })))
    $notes.Add(("alt-text block: {0} line(s) attributed to a slot's topic by the figure sheet ({1} shared by more than one topic), {2} matched no slot and count as topic 0" -f $gs.AltAttributed, $gs.AltShared, $gs.AltUnmatched))
    $notes.Add(("deck: {0} slide(s) mapped by position from {1} plan entries; {2} divider slide(s) verified to carry their own topic number" -f $ds.SlideCount, $ds.PlanCount, $ds.DividersChecked))
    $notes.Add(("figure sheet: {0} slot block(s); its SPINE-FINGERPRINT, GENERATED and SOURCE lines are not hashed" -f $sheet.Blocks.Count))
    $notes.Add('normalisation: trailing whitespace, Word TOC bookmark ids (_Toc<digits>), the extract stamp; Contents page numbers are kept')

    $delta = [ordered]@{
        renderedAt     = (Get-Date).ToUniversalTime().ToString('o')
        guide          = $g.Leaf
        deck           = $d.Leaf
        figureSheet    = $sheet.Leaf
        deckPlan       = (Split-Path $PlanPath -Leaf)
        guideSha       = (Get-TextSha -Text (ConvertTo-HashText -Lines $g.Lines))
        deckSha        = (Get-TextSha -Text (ConvertTo-HashText -Lines $d.Lines))
        figureSheetSha = (Get-TextSha -Text (ConvertTo-HashText -Lines $sheet.Lines))
        guideStamp     = $g.Stamp
        deckStamp      = $d.Stamp
        topics         = $topics
        previous       = $null
        notes          = $notes.ToArray()
    }
    [pscustomobject]@{ Delta = $delta; Guide = $g; Deck = $d; Sheet = $sheet; GuideSplit = $gs; DeckSplit = $ds }
}

# ---------------------------------------------------------------------------
# 3. The self-test: a planted word in one topic must move exactly that topic
# ---------------------------------------------------------------------------

function Invoke-DeltaSelfTest {
    param([Parameter(Mandatory)] $Base, [string] $PlanPath)
    $fails = 0
    $tmp = Join-Path $env:TEMP ("rd_" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        Write-Host ''
        Write-Host 'SELF-TEST - the delta must be stable, and a planted word must move one topic' -ForegroundColor Cyan

        # 1. stability
        $again = New-RenderDelta -GuidePath $Base.Guide.Path -DeckPath $Base.Deck.Path -SheetPath $Base.Sheet.Path -PlanPath $PlanPath
        $cmp = Compare-RenderDeltaTopics -From $Base.Delta -To $again.Delta
        if ($cmp.Changed.Count -eq 0 -and $cmp.Removed.Count -eq 0) { Write-Host '  recomputed from the same inputs: no topic moved' -ForegroundColor Green }
        else { Write-Host ("  X recomputed from the same inputs and topics {0} moved. The hash is not deterministic." -f ($cmp.Changed -join ', ')) -ForegroundColor Red; $fails++ }

        $numeric = @($Base.Delta.topics.Keys | Where-Object { $_ -ne '0' })
        if (-not $numeric.Count) { Write-Host '  X no numbered topic to plant into' -ForegroundColor Red; return ($fails + 1) }

        # a copy of a text file with one word altered on one full-extract line
        $plant = {
            param([string] $SourcePath, [int] $LineNo, [string] $DestPath)
            $all = [System.IO.File]::ReadAllText($SourcePath, [System.Text.Encoding]::UTF8).TrimStart([char]0xFEFF) -split "\r?\n"
            $line = $all[$LineNo - 1]
            $m = [regex]::Match($line, '[A-Za-z]{3,}')
            if (-not $m.Success) { return $false }
            $all[$LineNo - 1] = $line.Substring(0, $m.Index) + $m.Value + 'x' + $line.Substring($m.Index + $m.Length)
            [System.IO.File]::WriteAllText($DestPath, ($all -join "`n"), (New-Object System.Text.UTF8Encoding($false)))
            $before = [System.IO.File]::ReadAllText($SourcePath, [System.Text.Encoding]::UTF8).TrimStart([char]0xFEFF) -split "\r?\n"
            $after  = [System.IO.File]::ReadAllText($DestPath, [System.Text.Encoding]::UTF8) -split "\r?\n"
            if ($before.Count -ne $after.Count) { return $false }
            $diff = 0
            for ($i = 0; $i -lt $before.Count; $i++) { if ($before[$i] -ne $after[$i]) { $diff++ } }
            return ($diff -eq 1)
        }

        $assertOne = {
            param([string] $Arm, [string] $Topic, $Cmp)
            $ok = ($Cmp.Changed.Count -eq 1 -and $Cmp.Changed[0] -eq $Topic -and $Cmp.Why[$Topic] -eq $Arm)
            if ($ok) { Write-Host ("  planted one word in the {0} of Topic {1}: exactly Topic {1} moved, on the {0} arm only" -f $Arm, $Topic) -ForegroundColor Green; return 0 }
            Write-Host ("  X planted one word in the {0} of Topic {1} and the delta reported changed = [{2}] with arms [{3}]" -f $Arm, $Topic, ($Cmp.Changed -join ', '), (@($Cmp.Changed | ForEach-Object { $Cmp.Why[$_] }) -join ', ')) -ForegroundColor Red
            return 1
        }

        # 2. guide: the topic with the most words, a prose line of six or more words inside it
        $gt = @($numeric | Sort-Object { [int]$Base.Delta.topics[$_].words.guide } -Descending)[0]
        $gLine = 0
        foreach ($n in $Base.GuideSplit.Where[$gt]) {
            $txt = (Read-TextLines -Path $Base.Guide.Path)[$n - 1]
            if ($txt -match '^(Topic \d+ - |=== |\* |\d+\.\d+\s)' -or $txt -match 'PAGEREF') { continue }
            if ((Measure-Words -Lines @($txt)) -ge 6) { $gLine = $n; break }
        }
        $gCopy = Join-Path $tmp 'guide.txt'
        if ($gLine -eq 0 -or -not (& $plant $Base.Guide.Path $gLine $gCopy)) { Write-Host '  X guide plant did not land, so this proves nothing.' -ForegroundColor Red; $fails++ }
        else {
            $c = New-RenderDelta -GuidePath $gCopy -DeckPath $Base.Deck.Path -SheetPath $Base.Sheet.Path -PlanPath $PlanPath
            $fails += (& $assertOne 'guide' $gt (Compare-RenderDeltaTopics -From $Base.Delta -To $c.Delta))
        }

        # 3. deck: a topic with slides, a prose line of four or more words in one of them
        $dt = @($numeric | Where-Object { $Base.DeckSplit.ByTopic.ContainsKey($_) } | Sort-Object { [int]$Base.Delta.topics[$_].words.deck } -Descending)[0]
        $dLine = 0
        if ($dt) {
            $deckLines = Read-TextLines -Path $Base.Deck.Path
            $firstSlide = @($Base.DeckSplit.ByTopic[$dt])[0]
            $inSlide = $false
            for ($i = 0; $i -lt $deckLines.Count; $i++) {
                $m = [regex]::Match($deckLines[$i], '^=== SLIDE (\d+) ===\s*$')
                if ($m.Success) { $inSlide = ([int]$m.Groups[1].Value -eq $firstSlide); continue }
                if ($inSlide -and $deckLines[$i] -notmatch '^---' -and (Measure-Words -Lines @($deckLines[$i])) -ge 4) { $dLine = $i + 1; break }
            }
        }
        $dCopy = Join-Path $tmp 'deck.txt'
        if ($dLine -eq 0 -or -not (& $plant $Base.Deck.Path $dLine $dCopy)) { Write-Host '  X deck plant did not land, so this proves nothing.' -ForegroundColor Red; $fails++ }
        else {
            $c = New-RenderDelta -GuidePath $Base.Guide.Path -DeckPath $dCopy -SheetPath $Base.Sheet.Path -PlanPath $PlanPath
            $fails += (& $assertOne 'deck' $dt (Compare-RenderDeltaTopics -From $Base.Delta -To $c.Delta))
        }

        # 4. figure sheet: a caption line inside a slot block
        $ft = ''; $fLine = 0
        $sheetLines = $Base.Sheet.Lines
        $curTopic = '0'
        for ($i = 0; $i -lt $sheetLines.Count; $i++) {
            $m = [regex]::Match($sheetLines[$i], '^SLOT\s+(\d+)\.')
            if ($m.Success) { $curTopic = [string][int]$m.Groups[1].Value; continue }
            if ($curTopic -ne '0' -and $sheetLines[$i] -match '^\s*caption:\s*\S') { $ft = $curTopic; $fLine = $i + 1; break }
        }
        $fCopy = Join-Path $tmp 'figure-sheet.txt'
        if ($fLine -eq 0 -or -not (& $plant $Base.Sheet.Path $fLine $fCopy)) { Write-Host '  X figure-sheet plant did not land, so this proves nothing.' -ForegroundColor Red; $fails++ }
        else {
            $c = New-RenderDelta -GuidePath $Base.Guide.Path -DeckPath $Base.Deck.Path -SheetPath $fCopy -PlanPath $PlanPath
            $fails += (& $assertOne 'figures' $ft (Compare-RenderDeltaTopics -From $Base.Delta -To $c.Delta))
        }
    }
    finally {
        if ($tmp -and (Test-Path -LiteralPath $tmp) -and $tmp.Length -gt 12) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }
    return $fails
}

# ---------------------------------------------------------------------------
# 4. Run
# ---------------------------------------------------------------------------

try {
    $base = New-RenderDelta -GuidePath $guidePath -DeckPath $deckPath -SheetPath $sheetPath -PlanPath $planPath
}
catch { Write-Host ("  X " + $_.Exception.Message) -ForegroundColor Red; exit 2 }

$cmp = $null
$prevInfo = $null
$prev = @($Previous | Where-Object { $_ })
if ($prev.Count) {
    try {
        if ($prev.Count -eq 1 -and $prev[0] -match '(?i)\.json$') {
            $pp = (Resolve-Path -LiteralPath $prev[0]).Path
            $prevDelta = Read-LedgerJson -Path $pp
            if ($null -eq $prevDelta -or @($prevDelta.PSObject.Properties.Name) -notcontains 'topics') { throw ("{0}: -Previous {1} is not a render delta (no topics)." -f $GATE, $prev[0]) }
            $prevInfo = [ordered]@{ path = (Split-Path $pp -Leaf); sha = (Get-RenderDeltaSha -Path $pp) }
        }
        elseif ($prev.Count -eq 2) {
            $pg = Resolve-DeltaInput -Given $prev[0] -Default '' -What 'previous guide extract'
            $pd = Resolve-DeltaInput -Given $prev[1] -Default '' -What 'previous deck extract'
            $ps = if ($PreviousFigureSheet) { Resolve-DeltaInput -Given $PreviousFigureSheet -Default '' -What 'previous figure sheet' } else { $sheetPath }
            $prevDelta = (New-RenderDelta -GuidePath $pg -DeckPath $pd -SheetPath $ps -PlanPath $planPath).Delta
            $prevInfo = [ordered]@{ path = ((Split-Path $pg -Leaf) + ' + ' + (Split-Path $pd -Leaf) + $(if ($PreviousFigureSheet) { ' + ' + (Split-Path $ps -Leaf) } else { ' (current figure sheet)' })); sha = '' }
        }
        else { throw ("{0}: -Previous takes one render-delta.json, or a previous guide extract and deck extract." -f $GATE) }
        $cmp = Compare-RenderDeltaTopics -From $prevDelta -To $base.Delta
        $prevInfo.changed   = @($cmp.Changed)
        $prevInfo.unchanged = @($cmp.Unchanged)
        $prevInfo.removed   = @($cmp.Removed)
        $prevInfo.why       = $cmp.Why
        $base.Delta.previous = $prevInfo
    }
    catch { Write-Host ("  X " + $_.Exception.Message) -ForegroundColor Red; exit 2 }
}

if ($SelfTest) {
    $failed = Invoke-DeltaSelfTest -Base $base -PlanPath $planPath
    if ($failed -gt 0) {
        Write-Host ("  X self-test failed ({0}); no delta written." -f $failed) -ForegroundColor Red
        exit 4
    }
}

# ---- write, hash, archive
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
$json = ($base.Delta | ConvertTo-Json -Depth 8) + "`r`n"
[System.IO.File]::WriteAllText($OutPath, $json, (New-Object System.Text.UTF8Encoding($false)))
$deltaSha = Get-RenderDeltaSha -Path $OutPath
if (-not (Test-Path -LiteralPath $archiveDir)) { New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null }
$archivePath = Join-Path $archiveDir ($deltaSha + '.json')
Copy-Item -LiteralPath $OutPath -Destination $archivePath -Force

# ---- report
if (-not $Quiet) {
    Write-Host ''
    Write-Host 'RENDER DELTA - per-topic content hashes' -ForegroundColor Cyan
    $gStampNote = if ($base.Guide.Stamp) { ("stamp FIGURES {0} placed / {1} prompts" -f $base.Guide.Stamp.placed, $base.Guide.Stamp.prompts) } else { 'no stamp (pre-stamp extract)' }
    $dStampNote = if ($base.Deck.Stamp) { ("stamp FIGURES {0} placed / {1} prompts" -f $base.Deck.Stamp.placed, $base.Deck.Stamp.prompts) } else { 'no stamp (pre-stamp extract)' }
    Write-Host ("  guide: {0}  {1} line(s)  {2}" -f $base.Guide.Leaf, $base.Guide.LineCount, $gStampNote) -ForegroundColor DarkGray
    Write-Host ("  deck:  {0}  {1} slide(s)  {2}" -f $base.Deck.Leaf, $base.DeckSplit.SlideCount, $dStampNote) -ForegroundColor DarkGray
    foreach ($n in $base.Delta.notes) { Write-Host ("  " + $n) -ForegroundColor DarkGray }
    Write-Host ''
    Write-Host ("  {0,-6} {1,8} {2,8} {3,8}   {4,-10} {5,-10} {6,-10} {7}" -f 'topic', 'g-words', 'd-words', 'f-words', 'guide', 'deck', 'figures', $(if ($cmp) { 'vs previous' } else { '' }))
    foreach ($t in $base.Delta.topics.Keys) {
        $e = $base.Delta.topics[$t]
        $status = ''
        $col = 'Gray'
        if ($cmp) {
            if ($cmp.Changed -contains $t) { $status = ("CHANGED ({0})" -f $cmp.Why[$t]); $col = 'Yellow' }
            else { $status = 'unchanged'; $col = 'Green' }
        }
        Write-Host ("  {0,-6} {1,8} {2,8} {3,8}   {4,-10} {5,-10} {6,-10} {7}" -f $t, $e.words.guide, $e.words.deck, $e.words.figures, $e.guide.Substring(0, 8), $e.deck.Substring(0, 8), $e.figures.Substring(0, 8), $status) -ForegroundColor $col
    }
    if ($cmp) {
        Write-Host ''
        Write-Host ("  previous: {0}{1}" -f $prevInfo.path, $(if ($prevInfo.sha) { "  sha " + $prevInfo.sha.Substring(0, 8) } else { '' })) -ForegroundColor DarkGray
        Write-Host ("  changed:   {0}" -f $(if ($cmp.Changed.Count) { $cmp.Changed -join ', ' } else { 'none' })) -ForegroundColor $(if ($cmp.Changed.Count) { 'Yellow' } else { 'Green' })
        Write-Host ("  unchanged: {0}" -f $(if ($cmp.Unchanged.Count) { $cmp.Unchanged -join ', ' } else { 'none' })) -ForegroundColor Green
        if ($cmp.Removed.Count) { Write-Host ("  removed since previous: {0}" -f ($cmp.Removed -join ', ')) -ForegroundColor Yellow }
    }
    Write-Host ''
    Write-Host ("  written {0}" -f $OutPath) -ForegroundColor DarkGray
    Write-Host ("  delta sha {0}  (archived as {1}\{2}.json)" -f $deltaSha, $script:LedgerDeltaArchive, $deltaSha.Substring(0, 8)) -ForegroundColor Green
}
exit 0
