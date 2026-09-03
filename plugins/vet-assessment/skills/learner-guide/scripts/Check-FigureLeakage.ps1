<#
    Check-FigureLeakage.ps1 - does anything the resource says come from an
    ASSESSOR-ONLY document?

    Implements the gate the design calls Assert-AssessorLeakage. Derived at
    Stage 1, enforced at Stage 3c over every channel, again at Stage 4, and
    again at 7c against the placed document.

    WHY THIS CHECK DID NOT EXIST UNTIL LATE. The guide is built with artwork
    prompts on the page and the pictures placed at the very end, so the first
    two clean-room audits read a document in which every figure was still a
    prompt block. One of them reported "every figure is missing" and was
    correctly told that was expected at that stage. The consequence nobody drew
    at the time: the figures had never been read by a reviewer at all. That
    matters more than it sounds, because this kind of guide's process diagrams
    are not drawings - they are native tables of steps and values, the same
    shape as the assessment's own answer grids and the assessor's own benchmark
    lists.

    THE TEST. The registry gate already catches a REGISTERED assessor-only
    string. This catches the unregistered case, structurally: an n-gram present
    in an assessor guide and present in NO learner-facing document and NOT in
    the unit is, by definition, content the learner is not meant to have.

    IT SWEEPS EVERY STRING ON THE SPINE, NOT THE FIGURES. The name is
    historical. This started as a figure check, because the leak being chased
    was in figures. An audit that finally counted the RUNNING PROSE found the
    assessed answers had been there all along, in the assessor's own wording -
    four remediation rounds had been fixing the visible copies while this gate
    looked straight past the paragraphs beside them. A leak does not care which
    JSON field it sits in, so neither does this: every string of every spine
    file is swept - body prose, callouts, tables, figure cells, captions, alt
    text, slide bodies, chips and speaker notes - with the channel list
    enumerated from the spine itself, so a channel nobody has invented yet is
    still swept. The only fields passed over are structural identifiers and
    build metadata (provenance, openQuestions) that no renderer reads, and
    that list is declared and printed, never inferred.

    THE UNIT IS CLASS U, NEVER LEAKAGE. An assessor guide QUOTES THE UNIT, so
    unit wording shows up as "assessor-only" against the learner pack alone and
    is reported as a leak - when it is the one authority a learner resource is
    most obliged to teach. Without the unit corpus the gate tells you to delete
    the Performance Evidence from a document whose job is to prepare people for
    it. So the unit extract is a third corpus: an n-gram present in it is a
    quotation, not a leak. It is passed as -ExcludeText, found beside the build
    when it is not passed, and its absence is printed in yellow at the top and
    again beside the verdict; the runner refuses to run this gate without it.

    THE BLOCKING RUN IS 15 WORDS OVER THE WHOLE ASSESSOR TEXT, AND THE NUMBER
    IS MEASURED, NOT GUESSED. On the build this gate was proven on, an 8-word
    run fired on 225 spine cells, nearly all of them the guide legitimately
    TEACHING the content the model answer also states - which it is required
    to do, because the coverage arm demands every assessed row be taught. A
    12-word run over the model-answer regions fired on 5, four of them the
    guide teaching the house cooling standard and a recipe card's oven step.
    A 15-word run over the whole assessor text fired on exactly one cell, and
    that one was a document name plus a production week, cleared by reading
    both sources. The defect the audit had actually found was a verbatim run
    of 9 to 31 words and five consecutive bullets of a model answer reproduced
    in the assessor's own order, and 15 words holds it. So 15 words over the
    whole assessor text BLOCKS, and the shorter 8-word runs are REPORTED with
    their anchors - nothing is discarded, the shorter runs travel to Stage 3d
    and the review band, and the blocking arm keeps the credibility a gate
    needs if it is to be acted on rather than routed round. An earlier promoted
    copy narrowed the blocking set to the assessor guides' model-answer regions
    at 12 words; that arm is retired here because the whole-text 15-word run
    is the one proven on the build, and a narrowed check-set is a narrower
    check.

    A MARKING PHRASE IS A LEAK TOO. The assessor guides' own repeated
    structural labels - "Assessor benchmark", "Mark NS when", "Minimum
    acceptable" - are derived from the documents, not typed here, and a learner
    channel carrying one is telling the learner what it is marked against.

    THIS GATE REPORTS THE ANCHOR AND DOES NOT DECIDE. A hit is cleared BY
    READING THE SOURCES, never by pattern, and the clearance lives in
    figures.json "leakageAllow" beside the registry it weakens, keyed on the
    anchor "file|path" (the build's key) or on the phrase itself, each with a
    written reason that is printed on every run. A rendered extract's copy of
    an anchor-cleared cell is the same sentence and is cleared through the same
    entry, and says so. An allow-list nobody can audit is a gate turned off.

    Runs on the SPINE, because that is where the text is authored and where any
    fix has to land, and over rendered text extracts of both artefacts as well.

    PS 5.1. ASCII only in this file. Exit 1 on a blocking hit, 2 on a usage error.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $BuildDir,
    [string] $CorpusDir,
    [string] $SpineDir,
    [string] $RulesPath,
    #  Rendered extracts to sweep as well as the spine. At 7c these are freshly
    #  regenerated extracts of BOTH artefacts.
    [string[]] $DocText,
    #  Text that is legitimately shared - the unit extract, cited instrument
    #  text. An n-gram present here is not a leak, it is a quotation. When it is
    #  not passed, unit_extract.md is looked for beside the build.
    [string[]] $ExcludeText,
    #  The blocking run, over the whole assessor text. 15 is the measured value
    #  - see the header. A build that lowers it signs that decision in its
    #  runner, where it is printed.
    [int] $BlockShingle = 15,
    #  The reported run. Shorter shared wording travels to Stage 3d with its
    #  anchor; it does not block.
    [int] $Shingle = 8,
    #  Floor for the BLOCKING arm: a cell must hold at least this many words to
    #  be tested for a blocking run. The report arm needs only a full -Shingle,
    #  so raising this floor never hides a shorter run from the report.
    [int] $MinWords = 15,
    [int] $MinVocabRepeats = 2,
    #  Write the COMPLETE hit list - blocking, cleared and reported - to a file,
    #  so a remediation round enumerates before it fixes instead of working from
    #  the 25 lines that fitted on the console. A finding cannot be closed
    #  against a list nobody has.
    [string] $ReportPath,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

$GATE = 'Check-FigureLeakage'

# ---------------------------------------------------------------------------
# 1. The corpus, split by audience, plus the legitimately shared text
# ---------------------------------------------------------------------------

$corpusDirResolved = Get-GateCorpusDir -BuildDir $BuildDir -CorpusDir $CorpusDir
$corpus = Get-GateCorpusDocs -CorpusDir $corpusDirResolved -BuildDir $BuildDir

if (@($corpus.Assessor).Count -eq 0) {
    throw "$GATE`: the corpus at $corpusDirResolved contains no assessor-only document. Stage 1 extracts EVERY pack document - learner-facing and assessor-only - exactly once. A leakage sweep with no assessor guide to sweep against passes by having nothing to check, and that is precisely how a benchmark leak survived to the last audit round."
}
if (@($corpus.Learner).Count -eq 0) {
    throw "$GATE`: the corpus contains no learner-facing document, so every assessor phrase would look unique and the whole pack would report as leakage."
}

$assessorAll = ''
foreach ($d in $corpus.Assessor) { $assessorAll += ' ' + $d.Text }
$learnerAll = ''
foreach ($d in $corpus.Learner) { $learnerAll += ' ' + $d.Text }

#  The unit and any other shared text. Passed, or found beside the build.
$excludeFiles = @($ExcludeText | Where-Object { $_ })
$excludeSource = 'passed as -ExcludeText'
if ($excludeFiles.Count -eq 0) {
    foreach ($cand in @((Join-Path $BuildDir 'unit_extract.md'),
                        (Join-Path $BuildDir 'cleanroom\unit_extract.md'),
                        (Join-Path (Split-Path $BuildDir -Parent) 'unit_extract.md'))) {
        if (Test-Path -LiteralPath $cand) { $excludeFiles = @($cand); $excludeSource = 'found beside the build'; break }
    }
}
$excludeAll = ''
foreach ($x in $excludeFiles) {
    if (-not (Test-Path -LiteralPath $x)) { throw "$GATE`: -ExcludeText does not exist: $x" }
    $excludeAll += ' ' + (Get-GateFileText -Path $x)
}
$unitLoaded = ($excludeAll.Trim().Length -gt 0)

function Get-ShingleSet {
    param([string] $Text, [int] $N)
    $set = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    $words = @((ConvertTo-GateNormal $Text) -split ' ' | Where-Object { $_ })
    #  RETURNED WITH THE COMMA OPERATOR. PowerShell unrolls an IEnumerable on
    #  output, so a bare 'return $set' hands the caller a flat array of strings
    #  and the next .ExceptWith call fails on [System.String].
    if ($words.Count -lt $N) { return ,$set }
    for ($i = 0; $i -le ($words.Count - $N); $i++) {
        [void]$set.Add(($words[$i..($i + $N - 1)] -join ' '))
    }
    return ,$set
}

#  BLOCKING: every run of -BlockShingle words anywhere in an assessor guide,
#  minus every run in a learner-facing document, minus every run in the shared
#  text. REPORTED: the same at -Shingle words.
$blockSet   = Get-ShingleSet -Text $assessorAll -N $BlockShingle
$blockLearn = Get-ShingleSet -Text $learnerAll  -N $BlockShingle
$blockExcl  = Get-ShingleSet -Text $excludeAll  -N $BlockShingle
$blockSet.ExceptWith($blockLearn); $blockSet.ExceptWith($blockExcl)

$reportSet = Get-ShingleSet -Text $assessorAll -N $Shingle
$learnSet  = Get-ShingleSet -Text $learnerAll  -N $Shingle
$exclSet   = Get-ShingleSet -Text $excludeAll  -N $Shingle
$reportSet.ExceptWith($learnSet); $reportSet.ExceptWith($exclSet)

$unitLine = if ($unitLoaded) {
    "loaded, {0:N0} chars, {1} ({2}) - unit wording is class U and never leakage" -f $excludeAll.Length, (($excludeFiles | ForEach-Object { Split-Path $_ -Leaf }) -join ', '), $excludeSource
} else {
    'NOT LOADED - no -ExcludeText and no unit_extract.md beside the build. Unit wording WILL be reported as assessor-only; every hit below is suspect until the unit corpus is in place'
}

if (-not $Quiet) {
    Write-Host ''
    Write-Host 'ASSESSOR-ONLY LEAKAGE SWEEP' -ForegroundColor Cyan
    Write-Host ("  corpus: {0}  ({1} learner-facing, {2} assessor-only, classified from the {3})" -f `
        (Split-Path $corpusDirResolved -Leaf), @($corpus.Learner).Count, @($corpus.Assessor).Count, $corpus.ClassifiedFrom) -ForegroundColor DarkGray
    Write-Host ("  learner-facing text: {0:N0} chars   assessor text: {1:N0} chars" -f $learnerAll.Length, $assessorAll.Length) -ForegroundColor DarkGray
    Write-Host ("  unit extract / shared text: {0}" -f $unitLine) -ForegroundColor $(if ($unitLoaded) { 'DarkGray' } else { 'Yellow' })
    Write-GateCheckSet -What ("blocking {0}-word phrases" -f $BlockShingle) -Count $blockSet.Count -DerivedFrom 'the WHOLE assessor text, minus every learner-facing document and every excluded source'
    Write-GateCheckSet -What ("reported {0}-word phrases" -f $Shingle) -Count $reportSet.Count -DerivedFrom 'the whole assessor text, minus every learner-facing document and every excluded source'
}

if ($blockSet.Count -eq 0) {
    Write-Host ("  X {0}: the blocking check-set is empty. A sweep with nothing in it passes by having nothing to check." -f $GATE) -ForegroundColor Red
    exit 2
}

# ---------------------------------------------------------------------------
# 2. Assessor-only marking vocabulary, derived from the assessor guides' own
#    section headings rather than typed into this gate
# ---------------------------------------------------------------------------

#  A HEADING REPEATS AND A TABLE CELL DOES NOT, and that is the whole
#  discriminator - it is derived from the documents, not typed here. A plain
#  text extract carries no style information, so "short line, no terminal
#  punctuation, absent from every learner-facing document, and occurring at
#  least twice" is what a structural label of the assessor version looks like.
#  Measured on the build this was promoted from: 1643 candidate lines, 34 of
#  them repeated, and the top of that 34 is exactly the marking vocabulary -
#  "Assessor benchmark", "Mark NS when", "Minimum acceptable", "A satisfactory
#  answer covers", "Example comment". A learner document carrying one of those
#  is telling the learner what it is marked against.
$learnerNorm = ConvertTo-GateNormal $learnerAll   # normalised ONCE, not per line
$vocabCount = @{}
$vocabText = @{}
foreach ($doc in $corpus.Assessor) {
    foreach ($raw in ($doc.Text -split "`r?`n")) {
        $ln = "$raw".Trim()
        if (-not $ln -or $ln.Length -gt 80) { continue }
        if ($ln -match '[.!?]$') { continue }
        #  A HEADING IS NOT A BULLET. Model-answer bullets recur too, and they
        #  are long enough for the blocking arm to hold; letting them in here as
        #  short phrases produced the one false-positive class this arm had -
        #  a two-word bullet that is nothing but a recipe number and its name.
        if ($ln -match '^\s*([\u2022\u00B7\u2023\u25CF\u25AA\u25E6\u2043]|[-*]\s|\d+[.)]\s)') { continue }
        $n = ConvertTo-GateNormal $ln
        if ($n.Length -lt 12) { continue }
        if (@($n -split ' ').Count -lt 2) { continue }
        if ($learnerNorm.IndexOf($n, [System.StringComparison]::Ordinal) -ge 0) { continue }
        if ($vocabCount.ContainsKey($n)) { $vocabCount[$n]++ } else { $vocabCount[$n] = 1; $vocabText[$n] = $ln }
    }
}
$vocab = @{}
foreach ($k in $vocabCount.Keys) { if ($vocabCount[$k] -ge $MinVocabRepeats) { $vocab[$k] = $vocabText[$k] } }
$vocabKeys = @($vocab.Keys)
if (-not $Quiet) {
    Write-GateCheckSet -What 'assessor-only marking phrases' -Count $vocab.Count -DerivedFrom ("the assessor guides' own repeated structural labels ({0}+ occurrences), absent from every learner-facing document" -f $MinVocabRepeats)
    foreach ($k in ($vocabKeys | Sort-Object)) { Write-Host ("    marking phrase: {0}" -f $vocab[$k]) -ForegroundColor DarkGray }
}

# ---------------------------------------------------------------------------
# 3. Every channel of the spine, and any rendered extract handed in
# ---------------------------------------------------------------------------

#  -ForSweep, deliberately. Structural identifiers and build metadata are
#  skipped, and that is the ONLY narrowing: a provenance note that quotes the
#  assessor guide as its source is a correct provenance note, not a leak,
#  because it never reaches the page. Everything that can carry prose is swept -
#  including a visual spec, which no document renderer reads and which the
#  artwork pass prints on the page anyway. That is the channel this gate was
#  written for, and skipping it because a renderer does not name it would blind
#  the sweep to its own subject.
$skip = @{}
foreach ($k in (Get-GateUnrenderedFields -BuildDir $BuildDir -ForSweep).Keys) { $skip[$k] = $true }

$cells = New-Object System.Collections.Generic.List[object]
$figs = 0
foreach ($f in (Get-GateSpineFiles -BuildDir $BuildDir -SpineDir $SpineDir)) {
    $j = Get-GateJson -Path $f.FullName
    if ($null -eq $j) { continue }
    if (@($j.PSObject.Properties.Name) -contains 'visuals') { $figs += @(@($j.visuals) | Where-Object { $null -ne $_ -and @($_.PSObject.Properties.Name) -contains 'spec' -and $null -ne $_.spec }).Count }
    foreach ($c in (Get-GateSpineCells -Node $j -File $f.Name -Path '' -Channel '' -Slot '' -Skip $skip)) { $cells.Add($c) }
}
$spineCells = $cells.Count

foreach ($d in @($DocText | Where-Object { $_ })) {
    if (-not (Test-Path -LiteralPath $d)) { throw "$GATE`: -DocText does not exist: $d" }
    $leaf = Split-Path $d -Leaf
    $i = 0
    foreach ($line in ((Get-GateFileText -Path $d) -split "`r?`n")) {
        $i++
        if ("$line".Trim()) {
            $cells.Add([pscustomobject]@{ File = $leaf; Path = ("line {0}" -f $i); Channel = 'rendered'; Slot = ''; Text = $line })
        }
    }
}

$channels = @($cells | ForEach-Object { $_.Channel } | Sort-Object -Unique)
if (-not $Quiet) {
    Write-Host ("  fields passed over as structural or build metadata: {0}" -f (($skip.Keys | Sort-Object) -join ', ')) -ForegroundColor DarkGray
    Write-Host ("  channels swept: {0} - {1}" -f $channels.Count, ($channels -join ', ')) -ForegroundColor DarkGray
    Write-Host ("  figures with a spec: {0}   strings examined: {1} on the spine, {2} in rendered extract(s)" -f $figs, $spineCells, ($cells.Count - $spineCells)) -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# 4. Sweep
# ---------------------------------------------------------------------------

$registry = Get-GateRegistry -BuildDir $BuildDir -RulesPath $RulesPath
$allow = Get-GateAllowList -Registry $registry -Key 'leakageAllow' -IdField @('id', 'key', 'anchor', 'phrase', 'text') -GateName $GATE
#  Two kinds of key. "file|path" is an ANCHOR - one cell, adjudicated by
#  reading it against both sources. Anything else is a PHRASE, matched by
#  containment on the normalised text.
$anchorAllow = @{}
$phraseAllow = @{}
foreach ($k in $allow.Keys) {
    if ($k -match '^[^|]+\.[A-Za-z0-9]+\|.+$') { $anchorAllow[$k] = $allow[$k] } else { $phraseAllow[(ConvertTo-GateNormal $k)] = $allow[$k] }
}

if (-not $Quiet) {
    if ($allow.Count -gt 0) {
        Write-Host ("  allow-list, from figures.json leakageAllow - {0} entr(ies) ({1} anchor, {2} phrase), surfaced to the audit as evidence:" -f $allow.Count, $anchorAllow.Count, $phraseAllow.Count) -ForegroundColor DarkGray
        foreach ($k in ($allow.Keys | Sort-Object)) { Write-Host ("    {0}: {1}" -f $k, $allow[$k]) -ForegroundColor DarkGray }
    }
    else {
        Write-Host '  allow-list, from figures.json leakageAllow: empty - nothing is cleared' -ForegroundColor DarkGray
    }
}

$blocking = New-Object System.Collections.Generic.List[object]
$reported = New-Object System.Collections.Generic.List[object]
$vocabHits = New-Object System.Collections.Generic.List[object]
$blockFloor = [math]::Max($MinWords, $BlockShingle)

foreach ($c in $cells) {
    $n = ConvertTo-GateNormal $c.Text
    if (-not $n) { continue }

    foreach ($v in $vocabKeys) {
        if ($n.Length -ge $v.Length -and $n.IndexOf($v, [System.StringComparison]::Ordinal) -ge 0) {
            $vocabHits.Add([pscustomobject]@{ Cell = $c; Phrase = $vocab[$v]; Norm = $v; Text = $n })
        }
    }

    $words = @($n -split ' ' | Where-Object { $_ })

    $blocked = $false
    if ($words.Count -ge $blockFloor) {
        for ($i = 0; $i -le ($words.Count - $BlockShingle); $i++) {
            $sh = ($words[$i..($i + $BlockShingle - 1)]) -join ' '
            if ($blockSet.Contains($sh)) {
                $blocking.Add([pscustomobject]@{ Cell = $c; Phrase = $sh; Text = $n })
                $blocked = $true
                break   # one hit per cell is enough to raise it
            }
        }
    }
    if ($blocked) { continue }

    if ($words.Count -ge $Shingle) {
        for ($i = 0; $i -le ($words.Count - $Shingle); $i++) {
            $sh = ($words[$i..($i + $Shingle - 1)]) -join ' '
            if ($reportSet.Contains($sh)) {
                $reported.Add([pscustomobject]@{ Cell = $c; Phrase = $sh; Text = $n })
                break
            }
        }
    }
}

# ---- clearance, with the reason and the key printed
$cleared = New-Object System.Collections.Generic.List[object]
$live = New-Object System.Collections.Generic.List[object]
$clearedCellText = New-Object System.Collections.Generic.List[object]   # anchor-cleared spine cells, for their rendered copies

function Find-PhraseClearance {
    param([string] $Phrase, [string] $Text)
    foreach ($k in $phraseAllow.Keys) {
        if ($Phrase.IndexOf($k, [System.StringComparison]::Ordinal) -ge 0 -or $k.IndexOf($Phrase, [System.StringComparison]::Ordinal) -ge 0) { return [pscustomobject]@{ Why = $phraseAllow[$k]; By = "phrase '$k'" } }
        if ($Text -and $Text.IndexOf($k, [System.StringComparison]::Ordinal) -ge 0) { return [pscustomobject]@{ Why = $phraseAllow[$k]; By = "phrase '$k'" } }
    }
    return $null
}

# spine hits first, so an anchor clearance is known before its rendered copy is judged
foreach ($h in @($blocking | Where-Object { $_.Cell.Channel -ne 'rendered' })) {
    $key = "{0}|{1}" -f $h.Cell.File, $h.Cell.Path
    $why = $null; $by = ''
    if ($anchorAllow.ContainsKey($key)) { $why = $anchorAllow[$key]; $by = "anchor $key"; $clearedCellText.Add([pscustomobject]@{ Key = $key; Text = $h.Text; Why = $why }) }
    else { $pc = Find-PhraseClearance -Phrase $h.Phrase -Text $h.Text; if ($pc) { $why = $pc.Why; $by = $pc.By } }
    if ($why) { $cleared.Add([pscustomobject]@{ Hit = $h; Why = $why; By = $by }) } else { $live.Add($h) }
}
foreach ($h in @($blocking | Where-Object { $_.Cell.Channel -eq 'rendered' })) {
    $why = $null; $by = ''
    $pc = Find-PhraseClearance -Phrase $h.Phrase -Text $h.Text
    if ($pc) { $why = $pc.Why; $by = $pc.By }
    if (-not $why) {
        #  The rendered copy of an anchor-cleared cell: the matched run sits
        #  inside the cleared cell's own text, so it is the same sentence.
        foreach ($cc in $clearedCellText) {
            if ($cc.Text.IndexOf($h.Phrase, [System.StringComparison]::Ordinal) -ge 0) { $why = $cc.Why; $by = "the rendered copy of anchor $($cc.Key)"; break }
        }
    }
    if ($why) { $cleared.Add([pscustomobject]@{ Hit = $h; Why = $why; By = $by }) } else { $live.Add($h) }
}
foreach ($h in $vocabHits) {
    $key = "{0}|{1}" -f $h.Cell.File, $h.Cell.Path
    $why = $null; $by = ''
    if ($anchorAllow.ContainsKey($key)) { $why = $anchorAllow[$key]; $by = "anchor $key" }
    else { foreach ($k in $phraseAllow.Keys) { if ($h.Norm -eq $k) { $why = $phraseAllow[$k]; $by = "phrase '$k'" } } }
    if ($why) { $cleared.Add([pscustomobject]@{ Hit = $h; Why = $why; By = $by }) } else { $live.Add($h) }
}

if ($ReportPath) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("ASSESSOR-ONLY LEAKAGE SWEEP - complete hit list")
    [void]$sb.AppendLine(("generated {0}" -f (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')))
    [void]$sb.AppendLine(("unit extract / shared text: {0}" -f $unitLine))
    [void]$sb.AppendLine(("blocking {0}-word phrases: {1}   reported {2}-word phrases: {3}   marking phrases: {4}" -f $BlockShingle, $blockSet.Count, $Shingle, $reportSet.Count, $vocab.Count))
    [void]$sb.AppendLine(("channels swept: {0}" -f ($channels -join ', ')))
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('BLOCKING')
    foreach ($h in $live) { [void]$sb.AppendLine(("  [{0}] {1}  slot={2}  channel={3}`n    cell:  {4}`n    match: {5}" -f $h.Cell.File, $h.Cell.Path, $h.Cell.Slot, $h.Cell.Channel, $h.Cell.Text, $h.Phrase)) }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('CLEARED (figures.json leakageAllow, with the reason)')
    foreach ($c in $cleared) { [void]$sb.AppendLine(("  [{0}] {1}  by {2}`n    match:  {3}`n    reason: {4}" -f $c.Hit.Cell.File, $c.Hit.Cell.Path, $c.By, $c.Hit.Phrase, $c.Why)) }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine(("REPORTED (not blocking - shorter shared runs of {0} words, for the Stage 3d and review-band read)" -f $Shingle))
    foreach ($h in $reported) { [void]$sb.AppendLine(("  [{0}] {1}  slot={2}  channel={3}`n    cell:  {4}`n    match: {5}" -f $h.Cell.File, $h.Cell.Path, $h.Cell.Slot, $h.Cell.Channel, $h.Cell.Text, $h.Phrase)) }
    [System.IO.File]::WriteAllText($ReportPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
    Write-Host ("  complete hit list written to {0}" -f $ReportPath) -ForegroundColor DarkGray
}

Write-Host ''
foreach ($c in $cleared) {
    Write-Host ("  ok [{0}] {1} - cleared on {2}: {3}" -f $c.Hit.Cell.File, $c.Hit.Cell.Path, $c.By, $c.Why) -ForegroundColor DarkGray
    Write-Host ("     match: {0}" -f $c.Hit.Phrase) -ForegroundColor DarkGray
}

if ($reported.Count -gt 0) {
    Write-Host ("  REPORT ONLY - {0} cell(s) share a {1}-word run with an assessor guide that no learner document" -f $reported.Count, $Shingle) -ForegroundColor Yellow
    Write-Host '  or the unit carries. Legal quotations, recipe names, shared boilerplate and the guide teaching' -ForegroundColor Yellow
    Write-Host '  what the model answer also states live here. Read at Stage 3d; the full list is in -ReportPath.' -ForegroundColor Yellow
    foreach ($h in ($reported | Select-Object -First 25)) {
        Write-Host ("    [{0}] {1}{2}" -f $h.Cell.File, $h.Cell.Path, $(if ($h.Cell.Slot) { " (slot $($h.Cell.Slot))" } else { '' })) -ForegroundColor DarkGray
        Write-Host ("      match: {0}" -f $h.Phrase) -ForegroundColor DarkGray
    }
    if ($reported.Count -gt 25) { Write-Host ("    ... and {0} more" -f ($reported.Count - 25)) -ForegroundColor DarkGray }
    Write-Host ''
}

if (-not $unitLoaded) {
    Write-Host '  ! unit extract NOT LOADED - unit wording is being reported as assessor-only. Put unit_extract.md' -ForegroundColor Yellow
    Write-Host '    beside the build or pass -ExcludeText before acting on any hit above.' -ForegroundColor Yellow
}

if ($live.Count -eq 0) {
    if ($cleared.Count -gt 0) { Write-Host ("  no channel carries assessor-only wording beyond the {0} allow-listed entr(ies) above" -f $cleared.Count) -ForegroundColor Green }
    else { Write-Host '  no channel carries assessor-only wording' -ForegroundColor Green }
    exit 0
}

Write-Host ("  X {0} cell(s) carry assessor-only content" -f $live.Count) -ForegroundColor Red
foreach ($h in $live) {
    Write-Host ("    [{0}] {1}{2}  (channel: {3})" -f $h.Cell.File, $h.Cell.Path, $(if ($h.Cell.Slot) { " slot $($h.Cell.Slot)" } else { '' }), $h.Cell.Channel) -ForegroundColor Yellow
    Write-Host ("      cell:  {0}" -f $h.Cell.Text) -ForegroundColor DarkGray
    Write-Host ("      match: {0}" -f $h.Phrase) -ForegroundColor Red
    Write-Host ("      allow key if cleared by reading both sources: {0}|{1}" -f $h.Cell.File, $h.Cell.Path) -ForegroundColor DarkGray
}
Write-Host ''
Write-Host '  Fix on the spine, then re-run: every channel of both artefacts must be clear, not the one' -ForegroundColor Yellow
Write-Host '  the finding named. A phrase legitimately shared is cleared in figures.json "leakageAllow"' -ForegroundColor Yellow
Write-Host '  on its anchor or its phrase, with a written reason, never by narrowing this gate.' -ForegroundColor Yellow
exit 1
