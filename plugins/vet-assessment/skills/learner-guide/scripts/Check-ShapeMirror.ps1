<#
    Check-ShapeMirror.ps1 - is the prose written to the SHAPE of the assessor's
    model answer, with no verbatim run left to catch?

    Runs at Stage 3c on the spine, in the content loop on each sub-section file
    as it lands, and again before every Stage 7 re-render. Exit 1 on a BLOCK
    arm, 2 on a usage error, 0 otherwise.

    THE DEFECT THIS LOOKS FOR. Six clean-room audit rounds on one build found
    the same leak in a new place each time. Round 4 counted answered rows in
    TABLES; the remediation withheld the tables, and round 5 found the same
    grids answered in full in the running prose beside them - Task 11(a) seven
    of seven, Task 9(a) six of six, Task 6(a) six of six, Task 4(a)/(b) six of
    six - "in the assessor guide's own words, in the assessor's own order",
    with sentence stems ("Its essential function is ...", "Its essential
    features are ...") that ARE the task's column headings. The verbatim
    sweep beside this gate (Check-FigureLeakage) looks for shared word RUNS,
    and a paraphrase that keeps every content word and drops every function
    word carries no run to find. The table mirror (Check-FigureMirror) looks
    for rows of cells, and prose has none. What survived both gates was the
    SHAPE: the assessed row named, then that row's model bullets delivered in
    the model's own content words, cell by cell, row after row in the task's
    own order. That shape is what this gate scores.

    WHAT IT SCORES, AND WHY EACH RULE IS THERE.

      Content words. Every model bullet reduces to a content-word set (from
      assessor-cells.json, gate-only): normalised, crude-stemmed, stopwords
      out, every word the LEARNER already holds in the task's own text out
      (permitted ground - the learner has the headings and the row labels, so
      matching on them is matching on nothing), and every word that occurs in
      more than a quarter of all bullets out (document frequency - a word the
      whole pack says is not evidence of copying). The derivation is verified
      against the file's own wordPipeline block and any step the file did not
      declare is applied here, never by editing the register.

      Row anchoring. A sentence is scored against row R ONLY when it, or one
      of the two preceding sentences in the same paragraph array, names R -
      its label or an alias (head noun, singular fold, the "and" split, from
      the register). An unanchored sentence is never scored, so a paragraph
      about fish cannot score against a meat row however many spoilage words
      it shares. This is the rule that separates "the guide teaches what
      spoilage looks like" from "the guide fills in the meat row".

      Hit. A bullet hits when one anchored sentence carries at least 2 of its
      content words AND at least half of the set. A cell is ANSWERED when
      distinct hit bullets reach the benchmark minimum the register gives for
      the task, else ceil(K/2) of its K hittable bullets. A row is FULL when
      every assessed cell is answered, PARTIAL when at least one is.

    BLOCK arms, against the sub-section's OWN grids only:
      - FULL rows beyond the register's allowance (0 where the task leaves
        unassessed subjects to work an example on, 1 otherwise).
      - ROW ORDER: the rows a channel anchors, taken in first-anchor order and
        counting only rows with a cell answered, contain the task's own row
        order as a subsequence of length min(4, row count). The model's order
        is the assessor's composition, not the unit's, and prose that follows
        it row by row was written from the model.
    REPORT arms (printed, never blocking - read at Stage 3d):
      - PARTIAL rows; BULLET ORDER (3 or more hit bullets of one cell in the
        model's order inside one paragraph); any hit against ANOTHER
        sub-section's grid, because the audit found Task 11(a) rows in 5.1
        and 6.3 as well as in 2.3.

    NEVER PRINTS A MODEL BULLET. Anchors are reported as path + ROW LABEL +
    column heading + arm. The row labels are printed in the learner's own
    tool, so they leak nothing; the bullets are the thing this gate exists to
    keep off the page, and a gate that quotes them into a log is the leak
    the previous build's audit reports turned out to be.

    CALIBRATION (recorded so the numbers can be argued with, not trusted).
    Corpus A - spine_backup_pre_round4, the spine as it stood when round 5
    found the leak. Required to BLOCK on t2_2.3 (Task 11(a)), t1_1.4
    (4(a)/(b)), t5_5.4 (9(a)) and t3_3.1 (6(a)). Result: 4 of 4 BLOCK.
      11(a) 7 of 7 rows FULL, every one assembled in underpinningKnowledge
            (audit: 7 of 7); ROW ORDER fires in four channels (LCS 5-6 of 7).
      4(a)  3 of 3 FULL, 4(b) 3 of 3 FULL (audit: 6 of 6); ROW ORDER 3 of 3.
      9(a)  5 FULL + 1 PARTIAL (audit: 6 of 6 - Chillers has both cells
            answered, but in two different channels); ROW ORDER 6 of 6 in
            underpinningKnowledge and workedExample.
      6(a)  5 FULL + 1 PARTIAL (audit: 6 of 6); Workbook 3(a) 2 FULL over
            allowance 1 (audit: 6 of 6 - a numbered grid is anchored by row
            position and the guide interleaved two extra steps).
      Whole backup spine: 17 grid pairs BLOCK, 186 at report level, 13,604
      sentences. Recall on the four required files: 25 of 25 audited rows
      answered at least partially, 23 FULL.
    Corpus B - the current spine, which round 6 recorded CLEAN for 1.1, 2.3,
    3.1 (activity table), 5.4 and 5.2. Result: SILENT at BLOCK level on all
    five (1.1: 3 partial rows, 2.3: 3 partial rows, 5.4: 2 partial, 5.2: one
    FULL row inside allowance 1; 3.1 Workbook 3(a): 1 partial). Whole spine:
    4 grid pairs BLOCK, 198 at report level, 13,989 sentences, and each of
    the four is a REAL residual, not a false positive, adjudicated from the
    guide sentences themselves: t1_1.4 still carries 4(a) and 4(b) 3 of 3
    FULL in underpinningKnowledge (the round 6 HIGH finding 4.11, verbatim
    "On meat, contamination shows as ..." sentences, not remediated);
    t3_3.1 assembles 6(a) row "Set up containers, lids, labels and date
    codes" (what + why) in underpinningKnowledge under allowance 0; t4_4.3
    works Workbook 4(e) row "Deep fryer" (what + why) in underpinningKnowledge
    under allowance 0. False positives at BLOCK level: 0 of 35 files.
    Two rules were ADDED during calibration, each for a recorded reason:
      - a row is FULL only when one channel answers every cell. Before it,
        2.3 "Blast freezer" read FULL from a temperature standard in a
        practical table, a common-error line and a slide bullet - three
        channels, none of which writes the row; the audit standard is a row
        assembled in one place, and every corpus A leak was.
      - an alias equal to the grid subject class ("equipment") never
        anchors: it tied every generic safety sentence in 2.3 to the vacuum
        sealer row. A numeric label anchors only a table label cell or a
        list number; numbered grids anchor on the register subjects.
    Tried and NOT adopted: DF ceiling 0.02 (strips batch, degree, clean,
    probe, pack, product, tray, seal, check). It left every corpus A block
    standing and 3.1 still blocking, so it bought nothing; 0.25 is kept,
    inert on this pack (highest bullet DF 3.6 per cent).
    Settings: anchor window 2 sentences (crossing paragraph boundaries
    inside one array - the 11(a) feature sentences open with "Its ..."); hit
    floor 2 words and 50 per cent; row order LCS >= min(4, rows); bullet
    order 3; ambient alias ceiling 10 per cent of a file (204 suppressions
    across the current spine, e.g. "food" in 5.2, "recipes" in 1.1); the
    name part of a qualified label ("Vegetable stock - 1.1 L (...)") anchors.

    PS 5.1. ASCII only in this file. Nothing here names a unit, a brand or a
    build path: the grids, the aliases, the allowances and the benchmark
    minima are all read from the register the build derived.

    LIBRARY USE. Check-RowCoverage.ps1 dot-sources the block between the
    SM-LIB markers below (as a scriptblock, so this file's param block never
    rebinds the caller's variables). This file is canonical for the
    anchoring and scoring rules; the coverage gate must classify a sentence
    with exactly the same code, or the floor and the ceiling could be
    satisfied by the same sentence.

    REPORT STAMP (P0-08). The report carries spineFingerprint (v2, over the
    spine directory it enumerated), generated (UTC, round-trip 'o'), mode
    ('whole' for a directory run, 'file' for -SpineFile) and the file list it
    read, so Test-GridDisposition can refuse a report from another spine,
    another mode or an earlier run instead of disposing grids on it. Every
    OWN grid is recorded in the report even when no row is answered, because
    "examined and clean" and "never examined" used to look identical to the
    disposition, which read both as zero.

    ARMS (P0-09). full-rows and row-order BLOCK; partial-rows, bullet-order
    and cross-grid report. spine-files BLOCKS: an empty, whitespace-only or
    unparseable spine file is a named finding, never a silent skip. Every arm
    is registered before it runs and completed after, and the roster is
    printed as one ARMS: line and written to the report. A blocking arm whose
    check-set is empty is a refusal (exit 2), never a pass.

    SELF-TEST:  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Check-ShapeMirror.ps1 -SelfTest
    Builds a synthetic build in the temp directory, plants each defect this
    file claims to catch, proves the plant landed, and exits 0 only when the
    gate failed on every plant and passed the negative control.
#>

# GATE: stages=3c; requires=BuildDir

[CmdletBinding()]
param(
    [string] $BuildDir,
    [string] $SpineFile,
    [string] $SpineDir,
    [string] $Register,
    [string] $Cells,
    [switch] $OwnOnly,
    [string] $ReportPath,
    #  The path the RUNNER expects this gate to produce. Accepted so a runner
    #  can thread one value to producer and consumer. With no -ReportPath it IS
    #  the report path; given beside a different -ReportPath it is a refusal,
    #  because a runner reading one file while the gate writes another is the
    #  stale-report defect the stamp exists to catch.
    [string] $Produces,
    [switch] $SelfTest,
    [switch] $Quiet,
    #  Calibration - see the header before changing any of these.
    [int]    $AnchorWindow = 2,
    [int]    $MinHitWords = 2,
    [double] $MinHitShare = 0.5,
    [double] $DfCeiling = 0.25,
    [double] $AliasAmbientCeiling = 0.10,
    [int]    $RowOrderCap = 4,
    [int]    $BulletOrderMin = 3,
    [switch] $AsLibrary
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

# === SM-LIB BEGIN ===
#  Shared anchoring and scoring code. CANONICAL HERE. Check-RowCoverage.ps1
#  loads this block by reading this file and dot-sourcing the text between
#  the markers as a scriptblock. Nothing in the block reads a script-level
#  parameter; everything is passed in.

#  The stopword list is a COPY of New-WithholdRegister.ps1's (canonical there):
#  the two must agree or a bullet's precomputed set and a sentence's set would
#  be built by different rules. Function words only; domain words are removed
#  by the document-frequency ceiling, which is derived, not typed.
$script:SmStopwords = @(
    'a','about','above','after','again','against','all','also','am','an','and','any','are','as','at',
    'be','because','been','before','being','below','between','both','but','by',
    'can','cannot','could','did','do','does','doing','down','during',
    'each','either','else','ever','every','few','for','from','further',
    'had','has','have','having','he','her','here','hers','him','his','how',
    'i','if','in','into','is','it','its','itself','just',
    'let','may','me','might','more','most','much','must','my','myself',
    'neither','never','no','nor','not','now','of','off','on','once','one','only','onto','or','other','ought','our','ours','out','over','own',
    'per','rather','same','shall','she','should','so','some','still','such',
    'than','that','the','their','theirs','them','then','there','these','they','this','those','through','to','too','toward','towards',
    'under','until','up','upon','us','use','used','using','very','via',
    'was','we','were','what','when','where','whether','which','while','who','whom','whose','why','will','with','within','without','would',
    'yes','yet','you','your','yours','yourself',
    'across','along','among','around','away','back','get','gets','got','give','given','go','goes','keep','make','makes','made','put','take','takes','taken'
)

function Get-SmStem {
    <# Crude suffix stem, identical to the register's: ing / ed / es / s. #>
    param([string] $Word)
    $w = $Word
    if ($w.Length -gt 5 -and $w.EndsWith('ing')) { return $w.Substring(0, $w.Length - 3) }
    if ($w.Length -gt 4 -and $w.EndsWith('ed'))  { return $w.Substring(0, $w.Length - 2) }
    if ($w.Length -gt 4 -and $w -match '(ss|sh|ch|x|z)es$') { return $w.Substring(0, $w.Length - 2) }
    if ($w.Length -gt 3 -and $w.EndsWith('s') -and -not $w.EndsWith('ss')) { return $w.Substring(0, $w.Length - 1) }
    return $w
}

function Get-SmFold {
    <#  Comparison fold applied to BOTH sides after the stem: a trailing e is
        dropped from words longer than four letters. The crude stem maps
        "sanitise" to "sanitise" and "sanitised" to "sanitis", and the
        register's bullets carry one form while the prose carries the other.
        The fold is symmetric so it can only add recall, never precision.  #>
    param([string] $Word)
    if ($Word.Length -gt 4 -and $Word.EndsWith('e')) { return $Word.Substring(0, $Word.Length - 1) }
    return $Word
}

$script:SmStopSet = @{}
foreach ($sw in $script:SmStopwords) { $script:SmStopSet[$sw] = $true; $script:SmStopSet[(Get-SmStem $sw)] = $true }

function Get-SmTokens {
    <# Every token of a string, normalised, stemmed and folded, in order, stopwords kept (for phrase anchors). #>
    param([string] $Text)
    $out = New-Object System.Collections.Generic.List[string]
    if (-not $Text) { return $out }
    foreach ($tok in ((ConvertTo-GateNormal $Text) -split ' ')) {
        if ($tok) { $out.Add((Get-SmFold (Get-SmStem $tok))) }
    }
    return $out
}

function Get-SmWords {
    <# Content words of a string: the register's Get-Words with numbers kept, plus the fold. #>
    param([string] $Text)
    $out = New-Object System.Collections.Generic.List[string]
    if (-not $Text) { return $out }
    foreach ($tok in ((ConvertTo-GateNormal $Text) -split ' ')) {
        if (-not $tok -or $tok.Length -lt 2) { continue }
        $s = Get-SmStem $tok
        if ($script:SmStopSet.ContainsKey($s) -or $script:SmStopSet.ContainsKey($tok)) { continue }
        $f = Get-SmFold $s
        if (-not $out.Contains($f)) { $out.Add($f) }
    }
    return $out
}

function Split-SmSentences {
    <# Sentences of a spine string: a line break always ends one; otherwise . ! ? followed by space and a capital, digit, quote or bracket. "3.5 L" and "2.3" do not split. #>
    param([string] $Text)
    $out = New-Object System.Collections.Generic.List[string]
    if (-not $Text) { return $out }
    foreach ($line in ($Text -split "\r?\n")) {
        $l = $line.Trim()
        if (-not $l) { continue }
        foreach ($s in [regex]::Split($l, '(?<=[.!?])\s+(?=[A-Z0-9"''(\[])')) {
            $t = $s.Trim()
            if ($t) { $out.Add($t) }
        }
    }
    return $out
}

function Get-SmGridSet {
    <#  Every assessed grid as the scorer needs it: rows in the task's order,
        each row's anchors (label + register aliases), each assessed cell's
        bullets as content-word sets, the allowance and the benchmark minimum.

        The word pipeline is VERIFIED against the file's own declaration and
        any missing step is applied here. Always applied regardless: the
        stopword filter and the fold (both idempotent) and the DF ceiling,
        recomputed over every bullet in the file.  #>
    param(
        [Parameter(Mandatory)] $RegisterDoc,
        [Parameter(Mandatory)] $CellsDoc,
        [double] $DfCeiling = 0.25,
        [int] $MinHitWords = 2
    )

    $pipe = Get-GateProp -Object $CellsDoc -Names @('wordPipeline') -Default $null
    $hasStop = $false; $hasStem = $false; $hasLearner = $false; $declaredDf = $null
    if ($null -ne $pipe) {
        $sc = Get-GateProp -Object $pipe -Names @('stopwords') -Default 0
        if ($sc -is [string]) { $hasStop = ($sc -ne '') } else { $hasStop = ([int]$sc -gt 0) }
        $hasStem    = [bool](Get-GateProp -Object $pipe -Names @('stem') -Default '')
        $hasLearner = [bool](Get-GateProp -Object $pipe -Names @('stripLearnerWords', 'learnerWords') -Default '')
        $declaredDf = Get-GateProp -Object $pipe -Names @('dfCeiling') -Default $null
    }
    $complete = ($hasStop -and $hasStem -and $hasLearner)
    $applied = New-Object System.Collections.Generic.List[string]
    if (-not $hasStop)    { $applied.Add('stopwords (file did not declare them)') }
    if (-not $hasStem)    { $applied.Add('crude stem (file did not declare it)') }
    if (-not $hasLearner) { $applied.Add('learner-word strip, PROXY from the register headers, items and ref (file did not declare it; the task text itself is not available to a gate)') }
    if ($null -eq $declaredDf -or [double]$declaredDf -gt $DfCeiling) { $applied.Add(("document-frequency ceiling {0} (file declared {1})" -f $DfCeiling, $(if ($null -eq $declaredDf) { 'none' } else { $declaredDf }))) }
    $applied.Add('comparison fold (trailing e) - gate-side, both sides')

    # the register, indexed
    $subs = Get-GateProp -Object $RegisterDoc -Names @('subSections') -Default $null
    if ($null -eq $subs) { throw 'the withhold register carries no subSections block - New-WithholdRegister.ps1 writes one per mapped sub-section' }
    $regById = @{}; $regByRef = @{}
    foreach ($p in $subs.PSObject.Properties) {
        if ($p.Name -like '_*') { continue }
        foreach ($t in @(Get-GateProp -Object $p.Value -Names @('tasks', 'grids') -Default @())) {
            if ($null -eq $t) { continue }
            $rec = [pscustomobject]@{ SubSection = $p.Name; Task = $t }
            $id  = [string](Get-GateProp -Object $t -Names @('id') -Default '')
            $ref = [string](Get-GateProp -Object $t -Names @('ref') -Default '')
            if ($id)  { $regById[$id] = $rec }
            if ($ref) { $regByRef[$ref] = $rec }
        }
    }

    $allSets = New-Object System.Collections.Generic.List[object]
    $grids   = New-Object System.Collections.Generic.List[object]

    function Convert-SmBulletWords {
        param($Bullet, [bool] $Complete, [hashtable] $Proxy)
        $words = @()
        $txt = [string](Get-GateProp -Object $Bullet -Names @('text') -Default '')
        if ($Complete -or -not $txt) {
            $words = @(Get-GateProp -Object $Bullet -Names @('words') -Default @()) | ForEach-Object { [string]$_ }
        }
        else { $words = @(Get-SmWords $txt) }
        $ws = New-Object System.Collections.Generic.List[string]
        foreach ($w in $words) {
            $n = (ConvertTo-GateNormal ([string]$w)) -replace ' ', ''
            if (-not $n -or $n.Length -lt 2) { continue }
            if ($script:SmStopSet.ContainsKey($n)) { continue }
            $f = Get-SmFold $n
            if ($Proxy.ContainsKey($f)) { continue }
            if (-not $ws.Contains($f)) { $ws.Add($f) }
        }
        return $ws
    }

    foreach ($g in @(Get-GateProp -Object $CellsDoc -Names @('grids') -Default @())) {
        if ($null -eq $g) { continue }
        $id  = [string](Get-GateProp -Object $g -Names @('id') -Default '')
        $ref = [string](Get-GateProp -Object $g -Names @('ref') -Default '')
        $rec = $null
        if ($id -and $regById.ContainsKey($id)) { $rec = $regById[$id] } elseif ($ref -and $regByRef.ContainsKey($ref)) { $rec = $regByRef[$ref] }
        $sub = [string](Get-GateProp -Object $g -Names @('subSection') -Default '')
        if (-not $sub -and $null -ne $rec) { $sub = $rec.SubSection }
        $task = $null; if ($null -ne $rec) { $task = $rec.Task }
        $kind = [string](Get-GateProp -Object $g -Names @('kind') -Default '')
        if (-not $kind -and $null -ne $task) { $kind = [string](Get-GateProp -Object $task -Names @('kind') -Default '') }
        $items = @(); $aliases = $null; $allowance = 0; $bench = 0; $wgMin = 0; $subjects = @(); $classStem = ''
        if ($null -ne $task) {
            $items     = @(Get-GateProp -Object $task -Names @('items') -Default @()) | ForEach-Object { [string]$_ }
            $aliases   = Get-GateProp -Object $task -Names @('aliases') -Default $null
            $subjects  = @(Get-GateProp -Object $task -Names @('subjects') -Default @()) | ForEach-Object { [string]$_ }
            #  An alias equal to the grid's SUBJECT CLASS ("equipment" for a
            #  grid of equipment items) names the class, not a row: it anchored
            #  every generic safety sentence in a sub-section to the one row
            #  whose label ends in that word. Never an anchor.
            $cls = [string](Get-GateProp -Object $task -Names @('subjectClass', 'class') -Default '')
            if ($cls) { $classStem = ' ' + (@(Get-SmTokens $cls) -join ' ') + ' ' }
            $allowance = [int](Get-GateProp -Object $task -Names @('allowance') -Default 0)
            $shape     = Get-GateProp -Object $task -Names @('shape') -Default $null
            if ($null -ne $shape) {
                $bench = [int](Get-GateProp -Object $shape -Names @('benchmarkMinimum') -Default 0)
                $wg = Get-GateProp -Object $shape -Names @('wordGuide') -Default $null
                if ($null -ne $wg) { $wgMin = [int](Get-GateProp -Object $wg -Names @('min') -Default 0) }
            }
        }
        $headers      = @(Get-GateProp -Object $g -Names @('headers') -Default @()) | ForEach-Object { [string]$_ }
        $assessedCols = @(Get-GateProp -Object $g -Names @('assessedHeaders') -Default @()) | ForEach-Object { [int]$_ }
        $proxy = @{}
        if (-not $hasLearner) { foreach ($w in (Get-SmWords ((@($headers) + @($items) + @($ref)) -join ' '))) { $proxy[$w] = $true } }

        $rows = New-Object System.Collections.Generic.List[object]
        $ri = 0
        $cellRows = @(Get-GateProp -Object $g -Names @('rows') -Default @())
        #  A records or lookup grid can carry NO model rows (the cells are the
        #  learner's own readings). Its rows still have to be TAUGHT, so they
        #  are synthesised from the register's items with no cells: anchorable
        #  for the coverage floor, never scoreable for the mirror.
        if ($cellRows.Count -eq 0 -and $items.Count -gt 0) { $cellRows = @($items | ForEach-Object { [pscustomobject]@{ item = $_; assessed = $true; cells = @() } }) }
        foreach ($r in $cellRows) {
            if ($null -eq $r) { continue }
            $assessedRow = Get-GateProp -Object $r -Names @('assessed') -Default $true
            $label = [string](Get-GateProp -Object $r -Names @('item', 'label') -Default '')
            if (-not $label) { continue }
            $anchorTexts = New-Object System.Collections.Generic.List[string]
            #  A NUMERIC label ("1", "2") is a row position, not a name: in
            #  running prose "Outlet 1" and "Observation 1" would anchor row 1
            #  of every numbered task. It anchors only where it IS a row label
            #  (a table's first cell, or a sentence opening "1." / "1)"), and
            #  the register's subjects - the learner-held names the model
            #  draws on, in row order - carry the anchoring for those rows.
            $numeric = ((ConvertTo-GateNormal $label) -match '^\d+$')
            if (-not $numeric) {
                $anchorTexts.Add($label)
                #  THE NAME PART of a qualified label. "Vegetable stock - 1.1 L
                #  (wet bulk, measured)" is never written out in prose, and the
                #  register's own aliases of it ("vegetable stock 1 1 l") cannot
                #  be either, so the row could not be anchored and read as
                #  untaught. The part before the first dash, colon or bracket is
                #  the name the prose uses.
                #  (the dash family is written as \u escapes: this file is ASCII)
                $namePart = ($label -split '\s-\s|\s--\s|[\u2013\u2014:(]')[0]
                $namePartNorm = ConvertTo-GateNormal $namePart
                if ($namePartNorm -and $namePartNorm -ne (ConvertTo-GateNormal $label) -and (@($namePartNorm -split ' ' | Where-Object { $_.Length -ge 3 }).Count -ge 1)) { $anchorTexts.Add("$namePart".Trim()) }
            }
            if ($null -ne $aliases) {
                $al = Get-GateProp -Object $aliases -Names @($label) -Default @()
                foreach ($a in @($al)) { if ("$a".Trim()) { $anchorTexts.Add([string]$a) } }
            }
            if ($subjects.Count -gt 0 -and $ri -lt $subjects.Count -and $numeric) {
                $subj = $subjects[$ri]
                $head = ($subj -split '\(|,|\bwith\b|\bwith\b')[0]
                if ("$head".Trim()) { $anchorTexts.Add("$head".Trim()) }
                foreach ($piece in ($head -split '(?i)\s+(?:and|or)\s+|/|&')) {
                    $pn = "$piece".Trim()
                    if ($pn -and (@((ConvertTo-GateNormal $pn) -split ' ' | Where-Object { $_ }).Count -ge 2)) { $anchorTexts.Add($pn) }
                }
                foreach ($m in [regex]::Matches($subj, '\b\d{3,}\b')) { $anchorTexts.Add($m.Value) }
            }
            $anchors = New-Object System.Collections.Generic.List[object]
            foreach ($a in $anchorTexts) {
                $toks = @(Get-SmTokens $a)
                if ($toks.Count -eq 0) { continue }
                $stem = ' ' + ($toks -join ' ') + ' '
                $isLabel = ($a -eq $label)
                if (-not $isLabel -and $classStem -and $stem -eq $classStem) { continue }
                $dup = $false
                foreach ($x in $anchors) { if ($x.Stem -eq $stem) { $dup = $true; break } }
                if ($dup) { continue }
                $anchors.Add([pscustomobject]@{ Text = $a; Stem = $stem; Single = $(if ($toks.Count -eq 1) { $toks[0] } else { '' }); IsLabel = $isLabel })
            }
            if ($numeric) {
                $anchors.Add([pscustomobject]@{ Text = $label; Stem = ''; Single = ''; IsLabel = $true; Numeric = (ConvertTo-GateNormal $label) })
            }
            $cells = New-Object System.Collections.Generic.List[object]
            foreach ($c in @(Get-GateProp -Object $r -Names @('cells') -Default @())) {
                if ($null -eq $c) { continue }
                $col = [int](Get-GateProp -Object $c -Names @('col') -Default -1)
                if ($assessedCols.Count -gt 0 -and $assessedCols -notcontains $col) { continue }
                $state = [string](Get-GateProp -Object $c -Names @('state') -Default 'answered')
                $bullets = New-Object System.Collections.Generic.List[object]
                $bi = 0
                foreach ($b in @(Get-GateProp -Object $c -Names @('bullets') -Default @())) {
                    if ($null -eq $b) { continue }
                    $ws = Convert-SmBulletWords -Bullet $b -Complete $complete -Proxy $proxy
                    $bullets.Add([pscustomobject]@{ Index = $bi; Words = $ws; Size = 0; Hittable = $false })
                    $allSets.Add($ws)
                    $bi++
                }
                $hdr = ''
                if ($col -ge 0 -and $col -lt $headers.Count) { $hdr = $headers[$col] } else { $hdr = [string](Get-GateProp -Object $c -Names @('header') -Default ("column {0}" -f $col)) }
                $cells.Add([pscustomobject]@{ Col = $col; Header = $hdr; State = $state; Bullets = $bullets; Need = 0; Scoreable = $false })
            }
            $rows.Add([pscustomobject]@{ Index = $ri; Label = $label; Assessed = [bool]$assessedRow; Anchors = $anchors; Cells = $cells })
            $ri++
        }
        # the task's own row order: the register's items where they are given, else the rows as read
        $order = @()
        if ($items.Count -gt 0) { $order = $items } else { $order = @($rows | ForEach-Object { $_.Label }) }
        foreach ($row in $rows) {
            $pos = -1
            for ($k = 0; $k -lt $order.Count; $k++) { if ((ConvertTo-GateNormal $order[$k]) -eq (ConvertTo-GateNormal $row.Label)) { $pos = $k; break } }
            if ($pos -lt 0) { $pos = $row.Index }
            $row | Add-Member -NotePropertyName Order -NotePropertyValue $pos
        }
        $grids.Add([pscustomobject]@{
            Key = ("{0}|{1}" -f $sub, $id); SubSection = $sub; Ref = $ref; Id = $id; Kind = $kind
            Allowance = $allowance; BenchmarkMin = $bench; WordGuideMin = $wgMin
            Headers = $headers; AssessedCols = $assessedCols
            ItemCount = @($rows | Where-Object { $_.Assessed }).Count
            Rows = $rows
        })
    }
    # every other bullet in the file counts toward document frequency too
    foreach ($ft in @(Get-GateProp -Object $CellsDoc -Names @('freeText') -Default @())) {
        if ($null -eq $ft) { continue }
        foreach ($b in @(Get-GateProp -Object $ft -Names @('bullets') -Default @())) { if ($null -ne $b) { $allSets.Add((Convert-SmBulletWords -Bullet $b -Complete $complete -Proxy @{})) } }
    }
    foreach ($tl in @(Get-GateProp -Object $CellsDoc -Names @('taskLevel') -Default @())) {
        if ($null -eq $tl) { continue }
        foreach ($b in @(Get-GateProp -Object $tl -Names @('strings') -Default @())) { if ($null -ne $b) { $allSets.Add((Convert-SmBulletWords -Bullet $b -Complete $complete -Proxy @{})) } }
    }

    $df = @{}
    foreach ($ws in $allSets) { foreach ($w in $ws) { if ($df.ContainsKey($w)) { $df[$w]++ } else { $df[$w] = 1 } } }
    $common = @{}
    $total = $allSets.Count
    if ($total -gt 0) { foreach ($w in @($df.Keys)) { if (($df[$w] / [double]$total) -gt $DfCeiling) { $common[$w] = $true } } }

    foreach ($g in $grids) {
        foreach ($row in $g.Rows) {
            foreach ($c in $row.Cells) {
                $hittable = 0
                foreach ($b in $c.Bullets) {
                    if ($common.Count -gt 0) {
                        $kept = New-Object System.Collections.Generic.List[string]
                        foreach ($w in $b.Words) { if (-not $common.ContainsKey($w)) { $kept.Add($w) } }
                        $b.Words = $kept
                    }
                    $b.Size = $b.Words.Count
                    $b.Hittable = ($b.Size -ge $MinHitWords)
                    if ($b.Hittable) { $hittable++ }
                }
                $need = $g.BenchmarkMin
                if ($need -le 0) { $need = [int][math]::Ceiling($hittable / 2.0) }
                if ($need -gt $hittable) { $need = $hittable }
                $c.Need = $need
                $c.Scoreable = ($hittable -ge 1 -and ($c.State -eq '' -or $c.State -eq 'answered'))
            }
        }
    }

    return [pscustomobject]@{
        Grids = $grids.ToArray()
        BulletCount = $total
        CommonWords = @($common.Keys | Sort-Object)
        Applied = $applied.ToArray()
        Declared = [pscustomobject]@{ Stopwords = $hasStop; Stem = $hasStem; LearnerStrip = $hasLearner; DfCeiling = $declaredDf }
    }
}

function Get-SmFileSubSection {
    <# Which register sub-section a spine file belongs to, from its own ref. Empty for a topic or front file. #>
    param($Json, $RegisterDoc)
    $ref = [string](Get-GateProp -Object $Json -Names @('ref', 'pc', 'subSection') -Default '')
    if (-not $ref) { return '' }
    $subs = Get-GateProp -Object $RegisterDoc -Names @('subSections') -Default $null
    if ($null -eq $subs) { return '' }
    if (@($subs.PSObject.Properties.Name) -contains $ref) { return $ref }
    return ''
}

function Get-SmSentences {
    <#  Every sentence a file will put in front of a reader, in reading order,
        with the paragraph array it sits in (Group), the channel it hangs
        under, and - for a table cell - the row it belongs to. Identifiers and
        build metadata are skipped (Lib-GateCommon -ForSweep); nothing that
        carries prose is.  #>
    param($Json, [string] $File, [hashtable] $Skip)
    $out = New-Object System.Collections.Generic.List[object]
    $i = 0
    foreach ($cell in @(Get-GateSpineCells -Node $Json -File $File -Path '' -Channel '' -Slot '' -Skip $Skip)) {
        if ($null -eq $cell) { continue }
        $group = $cell.Path; $isTable = $false; $tableRow = ''; $cellIdx = -1
        $m = [regex]::Match($cell.Path, '(?i)^(.*rows\[\d+\])\[(\d+)\]$')
        if ($m.Success) { $isTable = $true; $tableRow = $m.Groups[1].Value; $cellIdx = [int]$m.Groups[2].Value; $group = $tableRow }
        else {
            $k = $cell.Path.LastIndexOf('[')
            if ($k -gt 0) { $group = $cell.Path.Substring(0, $k) }
        }
        $pos = 0
        foreach ($s in (Split-SmSentences $cell.Text)) {
            $hs = New-Object 'System.Collections.Generic.HashSet[string]'
            foreach ($w in (Get-SmWords $s)) { [void]$hs.Add($w) }
            $toks = @(Get-SmTokens $s)
            $ts = New-Object 'System.Collections.Generic.HashSet[string]'
            foreach ($t in $toks) { [void]$ts.Add($t) }
            $out.Add([pscustomobject]@{
                Index = $i; File = $File; Path = $cell.Path; Channel = $cell.Channel; Slot = $cell.Slot
                Group = $group; IsTable = $isTable; TableRow = $tableRow; CellIdx = $cellIdx; Pos = $pos
                Text = $s; Words = $hs; TokSet = $ts; StemStr = (' ' + ($toks -join ' ') + ' ')
                Direct = @{}; Anchored = @{}; Hits = (New-Object System.Collections.Generic.List[object])
            })
            $i++; $pos++
        }
    }
    return $out
}

function Invoke-SmScan {
    <#  Anchor and score one file's sentences against a set of grids.

        A sentence is classified EXACTLY ONCE per anchored row: it either hit a
        bullet of that row (answering) or it did not (teaching). The coverage
        gate reads the same objects, so the floor and the ceiling can never be
        satisfied by the same text.  #>
    param(
        [Parameter(Mandatory)] $Sentences,
        [Parameter(Mandatory)] $Grids,
        [int] $AnchorWindow = 2,
        [int] $MinHitWords = 2,
        [double] $MinHitShare = 0.5,
        [double] $AliasAmbientCeiling = 0.10
    )

    $sents = @($Sentences)
    $n = $sents.Count
    $ambient = New-Object System.Collections.Generic.List[string]

    # 1. direct anchors
    foreach ($g in $Grids) {
        foreach ($row in $g.Rows) {
            $key = "{0}|{1}" -f $g.Key, $row.Index
            foreach ($a in $row.Anchors) {
                if (@($a.PSObject.Properties.Name) -contains 'Numeric') {
                    #  a numeric label anchors a table's label cell, or a sentence that opens with it as a list number
                    $rx = '^' + [regex]::Escape($a.Numeric) + '[.):]\s'
                    foreach ($s in $sents) {
                        if ($s.IsTable -and $s.CellIdx -eq 0) { if ((ConvertTo-GateNormal $s.Text) -eq $a.Numeric) { $s.Direct[$key] = $true } }
                        elseif ($s.Text -match $rx) { $s.Direct[$key] = $true }
                    }
                    continue
                }
                if ($a.Single) {
                    #  AMBIENT VOCABULARY: a one-word alias that a tenth of the
                    #  file's sentences carry names the subject of the section,
                    #  not a row of the task. The full label still anchors.
                    $hitCount = 0
                    foreach ($s in $sents) { if ($s.TokSet.Contains($a.Single)) { $hitCount++ } }
                    if (-not $a.IsLabel -and $n -ge 20 -and ($hitCount / [double]$n) -gt $AliasAmbientCeiling) {
                        $ambient.Add(("{0} / {1}: alias '{2}' ({3} of {4} sentences)" -f $g.Ref, $row.Label, $a.Text, $hitCount, $n))
                        continue
                    }
                    if ($hitCount -eq 0) { continue }
                    foreach ($s in $sents) { if ($s.TokSet.Contains($a.Single)) { $s.Direct[$key] = $true } }
                }
                else {
                    foreach ($s in $sents) { if ($s.StemStr.Contains($a.Stem)) { $s.Direct[$key] = $true } }
                }
            }
        }
    }

    # 2. effective anchors: self, the window back inside the same paragraph array, the label cell of a table row
    $labelCells = @{}
    foreach ($s in $sents) { if ($s.IsTable -and $s.CellIdx -eq 0 -and $s.Direct.Count -gt 0) { if (-not $labelCells.ContainsKey($s.TableRow)) { $labelCells[$s.TableRow] = @{} }; foreach ($k in $s.Direct.Keys) { $labelCells[$s.TableRow][$k] = $true } } }
    for ($i = 0; $i -lt $n; $i++) {
        $s = $sents[$i]
        foreach ($k in $s.Direct.Keys) { $s.Anchored[$k] = $true }
        $back = 0
        for ($j = $i - 1; $j -ge 0 -and $back -lt $AnchorWindow; $j--) {
            if ($sents[$j].Group -ne $s.Group) { break }
            foreach ($k in $sents[$j].Direct.Keys) { $s.Anchored[$k] = $true }
            $back++
        }
        if ($s.IsTable -and $labelCells.ContainsKey($s.TableRow)) { foreach ($k in $labelCells[$s.TableRow].Keys) { $s.Anchored[$k] = $true } }
    }

    # 3. hits
    $gridByKey = @{}
    foreach ($g in $Grids) { $gridByKey[$g.Key] = $g }
    $hits = New-Object System.Collections.Generic.List[object]
    foreach ($s in $sents) {
        if ($s.Anchored.Count -eq 0) { continue }
        foreach ($k in @($s.Anchored.Keys)) {
            $bar = $k.LastIndexOf('|')
            $gk = $k.Substring(0, $bar); $ri = [int]$k.Substring($bar + 1)
            if (-not $gridByKey.ContainsKey($gk)) { continue }
            $g = $gridByKey[$gk]
            $row = $g.Rows[$ri]
            foreach ($c in $row.Cells) {
                if (-not $c.Scoreable) { continue }
                foreach ($b in $c.Bullets) {
                    if (-not $b.Hittable) { continue }
                    $common = 0
                    foreach ($w in $b.Words) { if ($s.Words.Contains($w)) { $common++ } }
                    if ($common -ge $MinHitWords -and $common -ge ($MinHitShare * $b.Size)) {
                        $h = [pscustomobject]@{ Sentence = $s.Index; GridKey = $gk; Row = $ri; Col = $c.Col; Bullet = $b.Index; Common = $common; Size = $b.Size }
                        $hits.Add($h); $s.Hits.Add($h)
                    }
                }
            }
        }
    }

    return [pscustomobject]@{ Sentences = $sents; Hits = $hits.ToArray(); Ambient = $ambient.ToArray() }
}

function Get-SmMatrix {
    <#  Per row, per assessed cell: distinct bullets hit, need, answered; row
        FULL / PARTIAL; and per-row teaching / answering sentence counts.

        A ROW IS FULL ONLY WHEN IT IS ASSEMBLED IN ONE PLACE. A cell is
        answered where its hits reach the benchmark inside ONE channel (the
        top-level spine field: underpinningKnowledge, workedExample, slides
        ...), and a row is FULL when some one channel answers every assessed
        cell. Calibration on the remediated spine showed a row "answered" out
        of a temperature standard in a practical table, a common-error line
        and a slide bullet - three channels, none of which writes the row. The
        audit's own standard was whether any one place assembles function,
        feature and safe practice for an item as a completed row, and the
        leaks it found were each inside one channel. PARTIAL still counts a
        cell answered anywhere, so nothing is hidden - it is reported.  #>
    param([Parameter(Mandatory)] $Grid, [Parameter(Mandatory)] $Scan)
    $rowsOut = New-Object System.Collections.Generic.List[object]
    foreach ($row in $Grid.Rows) {
        $key = "{0}|{1}" -f $Grid.Key, $row.Index
        $cellsOut = New-Object System.Collections.Generic.List[object]
        $answeredCells = 0; $scoreable = 0
        $fullChannels = $null
        foreach ($c in $row.Cells) {
            $set = @{}; $byChan = @{}
            foreach ($h in $Scan.Hits) {
                if ($h.GridKey -eq $Grid.Key -and $h.Row -eq $row.Index -and $h.Col -eq $c.Col) {
                    $set[$h.Bullet] = $true
                    $ch = [string]$Scan.Sentences[$h.Sentence].Channel
                    if (-not $byChan.ContainsKey($ch)) { $byChan[$ch] = @{} }
                    $byChan[$ch][$h.Bullet] = $true
                }
            }
            $ans = ($c.Scoreable -and $set.Count -ge $c.Need -and $c.Need -gt 0)
            $ansIn = @()
            if ($ans) { $ansIn = @($byChan.Keys | Where-Object { $byChan[$_].Count -ge $c.Need }) }
            if ($c.Scoreable) {
                $scoreable++
                if ($null -eq $fullChannels) { $fullChannels = @($ansIn) } else { $fullChannels = @($fullChannels | Where-Object { $ansIn -contains $_ }) }
            }
            if ($ans) { $answeredCells++ }
            $cellsOut.Add([pscustomobject]@{ Col = $c.Col; Header = $c.Header; Hits = $set.Count; Need = $c.Need; Scoreable = $c.Scoreable; Answered = $ans; AnsweredIn = $ansIn })
        }
        $teaching = 0; $answering = 0
        foreach ($s in $Scan.Sentences) {
            if (-not $s.Anchored.ContainsKey($key)) { continue }
            $hitRow = $false
            foreach ($h in $s.Hits) { if ($h.GridKey -eq $Grid.Key -and $h.Row -eq $row.Index) { $hitRow = $true; break } }
            if ($hitRow) { $answering++ } else { $teaching++ }
        }
        $full = ($scoreable -gt 0 -and $answeredCells -eq $scoreable -and $null -ne $fullChannels -and @($fullChannels).Count -gt 0)
        $partial = ($answeredCells -gt 0 -and -not $full)
        $rowsOut.Add([pscustomobject]@{ Index = $row.Index; Label = $row.Label; Order = $row.Order; Assessed = $row.Assessed; Cells = $cellsOut.ToArray(); AnsweredCells = $answeredCells; Scoreable = $scoreable; Full = $full; FullIn = $(if ($full) { @($fullChannels) } else { @() }); Partial = $partial; Teaching = $teaching; Answering = $answering })
    }
    return $rowsOut.ToArray()
}

function Get-SmLisLength {
    <# Longest strictly increasing subsequence of a sequence of integers (= LCS against the sorted order for distinct items). #>
    param([int[]] $Seq)
    $s = @($Seq)
    if ($s.Count -eq 0) { return 0 }
    $best = New-Object int[] $s.Count
    $max = 0
    for ($i = 0; $i -lt $s.Count; $i++) {
        $best[$i] = 1
        for ($j = 0; $j -lt $i; $j++) { if ($s[$j] -lt $s[$i] -and $best[$j] + 1 -gt $best[$i]) { $best[$i] = $best[$j] + 1 } }
        if ($best[$i] -gt $max) { $max = $best[$i] }
    }
    return $max
}

function Get-SmInputs {
    <# Resolve register, cells and spine files the same way for every caller. #>
    param([string] $BuildDir, [string] $SpineFile, [string] $SpineDir, [string] $Register, [string] $Cells, [string] $Gate)
    if (-not $BuildDir) { throw ("{0}: -BuildDir is required (the build directory that holds withhold-register.json and assessor-cells.json)." -f $Gate) }
    if (-not (Test-Path -LiteralPath $BuildDir)) { throw ("{0}: build directory not found: {1}" -f $Gate, $BuildDir) }
    if (-not $Register) { $Register = Join-Path $BuildDir 'withhold-register.json' }
    if (-not $Cells)    { $Cells    = Join-Path $BuildDir 'assessor-cells.json' }
    $reg = Get-GateJson -Path $Register
    if ($null -eq $reg) { throw ("{0}: no withhold register at {1}. New-WithholdRegister.ps1 derives it from the pack; a shape sweep with no grids passes by having nothing to check." -f $Gate, $Register) }
    $cel = Get-GateJson -Path $Cells
    if ($null -eq $cel) { throw ("{0}: no assessor cells file at {1}. It is GATE-ONLY output of New-WithholdRegister.ps1; without the model bullets there is no shape to score against." -f $Gate, $Cells) }
    $files = @()
    if ($SpineFile) {
        if (-not (Test-Path -LiteralPath $SpineFile)) { throw ("{0}: -SpineFile not found: {1}" -f $Gate, $SpineFile) }
        $files = @(Get-Item -LiteralPath $SpineFile)
    }
    else { $files = @(Get-GateSpineFiles -BuildDir $BuildDir -SpineDir $SpineDir) }
    return [pscustomobject]@{ Register = $reg; Cells = $cel; RegisterPath = $Register; CellsPath = $Cells; Files = $files }
}

function Write-SmJson {
    param([Parameter(Mandatory)] $Object, [Parameter(Mandatory)][string] $Path)
    $json = $Object | ConvertTo-Json -Depth 14
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($true)))
}
# === SM-LIB END ===

if ($AsLibrary) { return }

$GATE = 'Check-ShapeMirror'

# ---------------------------------------------------------------------------
# SELF-TEST. Synthetic build in the temp directory; every string invented.
# The gate is invoked as a child of this process on each plant, the plant is
# read back from the fixture before the verdict is trusted, and the run ends
# SELF-TEST PASS (exit 0) or SELF-TEST FAIL (exit 4).
# ---------------------------------------------------------------------------
if ($SelfTest) {
    Write-Host ''
    Write-Host ("  {0} SELF-TEST - a clean result is not believed until the gate has failed on a planted defect" -f $GATE) -ForegroundColor Cyan
    $script:SmSelfTestFailed = 0
    $self = $MyInvocation.MyCommand.Path
    $fx = Join-Path ([System.IO.Path]::GetTempPath()) ('sm-selftest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path (Join-Path $fx 'spine') | Out-Null

    function Test-SmSelf { param([bool] $Ok, [string] $What) if ($Ok) { Write-Host ("    ok   {0}" -f $What) -ForegroundColor Green } else { Write-Host ("    X    {0}" -f $What) -ForegroundColor Red; $script:SmSelfTestFailed++ } }
    function Write-SmFixture { param([string] $Path, $Object) [System.IO.File]::WriteAllText($Path, ($Object | ConvertTo-Json -Depth 14), (New-Object System.Text.UTF8Encoding($true))) }
    function Invoke-SmSelf {
        param([hashtable] $Arguments)
        $text = ''; $rc = -1
        try { $lines = @(& $self @Arguments *>&1 | ForEach-Object { "$_" }); $rc = $LASTEXITCODE; $text = ($lines -join "`n") }
        catch { $text = "EXCEPTION: " + $_.Exception.Message; $rc = -1 }
        return [pscustomobject]@{ Rc = $rc; Text = $text }
    }
    function Read-SmReport { param([string] $Path) if (Test-Path -LiteralPath $Path) { return (Get-GateJson -Path $Path) } return $null }

    try {
        #  One labelled grid, 3 rows x 2 assessed columns, model bullets in a
        #  GATE-ONLY cells file. Hand-stemmed to the register's rule so the
        #  fixture's truth does not come from the gate's own tokeniser.
        Write-SmFixture -Path (Join-Path $fx 'withhold-register.json') -Object @{
            subSections = @{ '1.1' = @{ subSection = '1.1'; refs = @('Task 1(a)'); tasks = @(
                @{ ref = 'Task 1(a)'; id = 'TEST_Tool Task 1(a)'; document = 'TEST_Tool'; kind = 'labelled'
                   headers = @('Widget', 'Purpose', 'Care'); assessedHeaders = @(1, 2)
                   items = @('Widget A', 'Widget B', 'Widget C'); aliases = @{ 'Widget A' = @(); 'Widget B' = @(); 'Widget C' = @() }
                   subjectClass = 'widget'; subjects = @(); unassessedSubjects = @('Widget D'); allowance = 1
                   shape = @{ rows = 3; assessedColumns = 2; bulletsPerCell = @{ min = 1; max = 2 }; wordGuide = @{ min = 10; max = 20 }; benchmarkMinimum = 1 } } ); freeText = @() } }
        }
        Write-SmFixture -Path (Join-Path $fx 'assessor-cells.json') -Object @{
            _WARNING = 'GATE-ONLY synthetic cells for the self-test'
            wordPipeline = @{ stopwords = 176; stem = 'crude suffix strip: ing, ed, es, s'; stripLearnerWords = 'headers and items'; dfCeiling = 0.25 }
            grids = @(@{ ref = 'Task 1(a)'; id = 'TEST_Tool Task 1(a)'; subSection = '1.1'; kind = 'labelled'; document = 'TEST_Tool'
                         headers = @('Widget', 'Purpose', 'Care'); assessedHeaders = @(1, 2)
                         rows = @(
                            @{ item = 'Widget A'; assessed = $true; cells = @(
                                @{ col = 1; header = 'Purpose'; state = 'answered'; bullets = @(@{ text = 'turns the main spindle'; words = @('turn', 'main', 'spindle') }, @{ text = 'holds the spindle under tension'; words = @('hold', 'spindle', 'tension') }) },
                                @{ col = 2; header = 'Care'; state = 'answered'; bullets = @(@{ text = 'oil the bearing weekly'; words = @('oil', 'bear', 'weekly') }, @{ text = 'check the belt for fraying'; words = @('check', 'belt', 'fray') }) }) },
                            @{ item = 'Widget B'; assessed = $true; cells = @(
                                @{ col = 1; header = 'Purpose'; state = 'answered'; bullets = @(@{ text = 'feeds the hopper evenly'; words = @('feed', 'hopper', 'evenly') }) },
                                @{ col = 2; header = 'Care'; state = 'answered'; bullets = @(@{ text = 'clear the chute after every run'; words = @('clear', 'chute', 'run') }, @{ text = 'grease the pivot monthly'; words = @('grease', 'pivot', 'monthly') }) }) },
                            @{ item = 'Widget C'; assessed = $true; cells = @(
                                @{ col = 1; header = 'Purpose'; state = 'answered'; bullets = @(@{ text = 'holds the jig square'; words = @('hold', 'jig', 'square') }) },
                                @{ col = 2; header = 'Care'; state = 'answered'; bullets = @(@{ text = 'inspect the clamp face'; words = @('inspect', 'clamp', 'face') }, @{ text = 'replace a worn pad at once'; words = @('replace', 'worn', 'pad') }) }) }
                         ) })
            freeText = @(); taskLevel = @()
        }
        $spinePath = Join-Path $fx 'spine\t1_1.1.json'
        $reportPath = Join-Path $fx 'shape-mirror-report.json'

        # ---- plant 1: prose answering all three rows in the task's order -> BLOCK, and the report is stamped
        Write-SmFixture -Path $spinePath -Object @{
            ref = '1.1'; title = 'Widgets'
            underpinningKnowledge = @(
                'Widget A turns the main spindle and holds the spindle under tension. Oil the bearing weekly and check the belt for fraying.',
                'Widget B feeds the hopper evenly. Clear the chute after every run and grease the pivot monthly.',
                'Widget C holds the jig square. Inspect the clamp face and replace a worn pad at once.')
        }
        $planted = Get-GateFileText -Path $spinePath
        Test-SmSelf -Ok ($planted.IndexOf('Widget A turns the main spindle', [System.StringComparison]::Ordinal) -ge 0 -and $planted.IndexOf('Widget C holds the jig square', [System.StringComparison]::Ordinal) -ge 0) -What 'plant 1 landed: the spine file carries the three answered rows'
        $r1 = Invoke-SmSelf -Arguments @{ BuildDir = $fx; Quiet = $true }
        $rep1 = Read-SmReport -Path $reportPath
        Test-SmSelf -Ok ($r1.Rc -eq 1) -What ("plant 1: prose answering every row in order exits 1 (rc={0})" -f $r1.Rc)
        $fpNow = Get-SpineFingerprint -BuildDir $fx -Quiet
        $stamp = if ($null -ne $rep1) { [string](Get-GateProp -Object $rep1 -Names @('spineFingerprint') -Default '') } else { '' }
        Test-SmSelf -Ok ($stamp -like 'v2:*' -and $stamp -eq $fpNow) -What ("report stamps spineFingerprint v2 equal to the current spine ({0})" -f $stamp)
        $gen = if ($null -ne $rep1) { [string](Get-GateProp -Object $rep1 -Names @('generated') -Default '') } else { '' }
        $genOk = $false
        try { $dto = [System.DateTimeOffset]::Parse($gen, [System.Globalization.CultureInfo]::InvariantCulture); $genOk = ($gen -match 'Z$' -and ([System.DateTimeOffset]::UtcNow - $dto).TotalMinutes -lt 10) } catch { $genOk = $false }
        Test-SmSelf -Ok $genOk -What ("report stamps generated as UTC round-trip time ({0})" -f $gen)
        Test-SmSelf -Ok ($null -ne $rep1 -and [string](Get-GateProp -Object $rep1 -Names @('mode') -Default '') -eq 'whole') -What 'report stamps mode whole for a directory run'
        $files1 = if ($null -ne $rep1) { @(Get-GateProp -Object $rep1 -Names @('spineFiles') -Default @()) } else { @() }
        Test-SmSelf -Ok ($files1 -contains 't1_1.1.json') -What 'report lists the spine files it read (spineFiles)'
        Test-SmSelf -Ok ($r1.Text -match '(?m)^ARMS: .*full-rows\|true\|ran\|\d+\|1' -and $r1.Text -match 'row-order\|true\|ran\|') -What 'the ARMS: roster line prints with full-rows and row-order ran'
        $armsRep = if ($null -ne $rep1) { @(Get-GateProp -Object $rep1 -Names @('arms') -Default @()) } else { @() }
        Test-SmSelf -Ok (@($armsRep | Where-Object { $_.name -eq 'full-rows' -and $_.state -eq 'ran' -and $_.findings -eq 1 }).Count -eq 1) -What 'the roster is written to the report'
        Test-SmSelf -Ok ($r1.Text -notmatch 'turns the main spindle' -and $r1.Text -notmatch 'grease the pivot monthly') -What 'no model bullet reaches the console'

        # ---- plant 2: negative control - the same facts as mechanism, no row named -> exit 0, own grid still RECORDED as examined
        Write-SmFixture -Path $spinePath -Object @{
            ref = '1.1'; title = 'Widgets'
            underpinningKnowledge = @(
                'A spindle is held under tension so the belt cannot slip. Bearings are oiled weekly because a dry bearing seizes.',
                'A hopper feeds evenly when its chute is cleared after every run. A jig stays square only while the clamp face is true, so inspect it and replace a worn pad at once.')
        }
        $planted = Get-GateFileText -Path $spinePath
        Test-SmSelf -Ok ($planted.IndexOf('dry bearing seizes', [System.StringComparison]::Ordinal) -ge 0 -and $planted -notmatch 'Widget [ABC]') -What 'plant 2 landed: mechanism prose, no row named'
        $r2 = Invoke-SmSelf -Arguments @{ BuildDir = $fx; Quiet = $true }
        $rep2 = Read-SmReport -Path $reportPath
        Test-SmSelf -Ok ($r2.Rc -eq 0) -What ("negative control: unanchored mechanism prose exits 0 (rc={0})" -f $r2.Rc)
        $ownRec = @()
        if ($null -ne $rep2) { foreach ($fr in @($rep2.files)) { foreach ($g in @($fr.Grids)) { if ($g.Own -and $g.Id -eq 'TEST_Tool Task 1(a)') { $ownRec += $g } } } }
        Test-SmSelf -Ok ($ownRec.Count -eq 1 -and $ownRec[0].FullRows -eq 0 -and $ownRec[0].Examined) -What 'a clean own grid is still recorded in the report (FullRows 0, Examined) so the disposition can tell examined from absent'
        Test-SmSelf -Ok ($r2.Text -match '(?m)^ARMS: .*full-rows\|true\|ran\|\d+\|0') -What 'the roster prints full-rows ran with 0 findings on the clean run'

        # ---- plant 3: an empty spine file is a NAMED finding, not a silent skip
        $emptyPath = Join-Path $fx 'spine\t1_1.2.json'
        [System.IO.File]::WriteAllText($emptyPath, "   `r`n", (New-Object System.Text.UTF8Encoding($true)))
        Test-SmSelf -Ok ((Test-Path -LiteralPath $emptyPath) -and -not (Get-GateFileText -Path $emptyPath).Trim()) -What 'plant 3 landed: t1_1.2.json exists and is whitespace-only'
        $r3 = Invoke-SmSelf -Arguments @{ BuildDir = $fx; Quiet = $true }
        $rep3 = Read-SmReport -Path $reportPath
        $emptyRep = if ($null -ne $rep3) { @(Get-GateProp -Object $rep3 -Names @('emptyFiles') -Default @()) } else { @() }
        Test-SmSelf -Ok ($r3.Rc -eq 1 -and $r3.Text -match 't1_1\.2\.json' -and $r3.Text -match '(?i)empty' -and @($emptyRep | Where-Object { $_ -match 't1_1\.2\.json' }).Count -eq 1) -What ("an empty spine file exits 1 naming the file, and the report lists it (rc={0})" -f $r3.Rc)
        Test-SmSelf -Ok ($r3.Text -match '(?m)^ARMS: .*spine-files\|true\|ran\|1\|1') -What 'the spine-files arm records 1 file read and 1 finding'
        Remove-Item -LiteralPath $emptyPath -Force

        # ---- plant 4: -SpineFile stamps mode file
        $r4 = Invoke-SmSelf -Arguments @{ BuildDir = $fx; SpineFile = $spinePath; Quiet = $true }
        $rep4 = Read-SmReport -Path $reportPath
        Test-SmSelf -Ok ($r4.Rc -eq 0 -and $null -ne $rep4 -and [string](Get-GateProp -Object $rep4 -Names @('mode') -Default '') -eq 'file') -What ("-SpineFile stamps mode file (rc={0})" -f $r4.Rc)

        # ---- plant 5: -Produces threads the report path; a conflicting -ReportPath is refused naming both
        $pPath = Join-Path $fx 'produced.json'
        $r5 = Invoke-SmSelf -Arguments @{ BuildDir = $fx; Produces = $pPath; Quiet = $true }
        Test-SmSelf -Ok ($r5.Rc -eq 0 -and (Test-Path -LiteralPath $pPath)) -What '-Produces alone is the report path'
        $r6 = Invoke-SmSelf -Arguments @{ BuildDir = $fx; Produces = $pPath; ReportPath = (Join-Path $fx 'other.json'); Quiet = $true }
        Test-SmSelf -Ok ($r6.Rc -eq 2 -and $r6.Text -match 'produced\.json' -and $r6.Text -match 'other\.json') -What ("-Produces beside a different -ReportPath is refused naming both (rc={0})" -f $r6.Rc)
    }
    finally {
        try { Remove-Item -LiteralPath $fx -Recurse -Force -ErrorAction SilentlyContinue } catch { }
    }

    Write-Host ''
    if ($script:SmSelfTestFailed -gt 0) {
        Write-Host ("  SELF-TEST FAIL: {0} check(s) failed - no result from this gate may be believed until they pass" -f $script:SmSelfTestFailed) -ForegroundColor Red
        exit 4
    }
    Write-Host '  SELF-TEST PASS: the gate failed on every planted defect, passed the negative control, stamped its report and printed its roster' -ForegroundColor Green
    exit 0
}

try {

$mode = if ($SpineFile) { 'file' } else { 'whole' }
if ($Produces) {
    if (-not $ReportPath) { $ReportPath = $Produces }
    elseif ([System.IO.Path]::GetFullPath($ReportPath).ToLowerInvariant() -ne [System.IO.Path]::GetFullPath($Produces).ToLowerInvariant()) {
        Write-Host ("  X {0}: -Produces {1} names a different file from -ReportPath {2}. A runner that reads one path while the gate writes another is reading a stale report; pass one path." -f $GATE, $Produces, $ReportPath) -ForegroundColor Red
        exit 2
    }
}

try { $in = Get-SmInputs -BuildDir $BuildDir -SpineFile $SpineFile -SpineDir $SpineDir -Register $Register -Cells $Cells -Gate $GATE }
catch { Write-Host ("  X {0}" -f $_.Exception.Message) -ForegroundColor Red; exit 2 }

$set = Get-SmGridSet -RegisterDoc $in.Register -CellsDoc $in.Cells -DfCeiling $DfCeiling -MinHitWords $MinHitWords
$grids = @($set.Grids)
$subCount = @($grids | ForEach-Object { $_.SubSection } | Where-Object { $_ } | Select-Object -Unique).Count
if (-not $Quiet) {
    Write-Host ''
    Write-Host 'SHAPE MIRROR - prose written to the shape of the model answer' -ForegroundColor Cyan
}
#  BLOCKING: a cells file with no grid is an empty check-set, and an empty
#  check-set is a refusal (exit 2 through the catch below), never a pass.
Write-GateCheckSet -What 'assessed grids' -Count $grids.Count -DerivedFrom ("{0} ({1} sub-sections) with cells from {2} ({3} bullets)" -f (Split-Path $in.RegisterPath -Leaf), $subCount, (Split-Path $in.CellsPath -Leaf), $set.BulletCount) -Blocking -Input 'assessor-cells.json grids'
$skip = Get-GateUnrenderedFields -BuildDir $BuildDir -ForSweep
$skipTable = @{}
foreach ($k in $skip.Keys) { $skipTable[$k] = $true }
if (-not $ReportPath) { $ReportPath = Join-Path $BuildDir 'shape-mirror-report.json' }

#  Every arm, declared before any of them runs. A blocking arm left not-run,
#  or ended empty, cannot pass this gate.
Register-GateArm -Name 'spine-files' -Blocking
Register-GateArm -Name 'full-rows' -Blocking
Register-GateArm -Name 'row-order' -Blocking
Register-GateArm -Name 'partial-rows'
Register-GateArm -Name 'bullet-order'
Register-GateArm -Name 'cross-grid'

if (-not $Quiet) {
    Write-Host ("  word pipeline declared by the cells file: stopwords={0} stem={1} learner-strip={2} dfCeiling={3}" -f $set.Declared.Stopwords, $set.Declared.Stem, $set.Declared.LearnerStrip, $(if ($null -eq $set.Declared.DfCeiling) { 'none' } else { $set.Declared.DfCeiling })) -ForegroundColor DarkGray
    foreach ($a in $set.Applied) { Write-Host ("  applied here: {0}" -f $a) -ForegroundColor DarkGray }
    Write-Host ("  DF ceiling {0}: {1} word(s) stripped{2}" -f $DfCeiling, @($set.CommonWords).Count, $(if (@($set.CommonWords).Count) { ' (' + (@($set.CommonWords) -join ', ') + ')' } else { '' })) -ForegroundColor DarkGray
    Write-Host ("  calibration: anchor window {0}; hit = {1}+ words and {2:P0} of the set; row order LCS >= min({3}, rows); bullet order {4}+ in one paragraph; ambient alias ceiling {5:P0}" -f $AnchorWindow, $MinHitWords, $MinHitShare, $RowOrderCap, $BulletOrderMin, $AliasAmbientCeiling) -ForegroundColor DarkGray
    Write-Host ("  spine: {0} file(s){1}" -f $in.Files.Count, $(if ($OwnOnly) { ' - own grids only (-OwnOnly)' } else { '' })) -ForegroundColor DarkGray
}

$blockTotal = 0; $reportTotal = 0
$fileReports = New-Object System.Collections.Generic.List[object]
$totalSentences = 0
#  Arm bookkeeping: what each arm examined (its check-set) and what it found.
$emptyFiles = New-Object System.Collections.Generic.List[string]
$filesRead = 0; $pairsScanned = 0; $crossPairs = 0
$fullRowsFindings = 0; $rowOrderFindings = 0; $partialFindings = 0; $bulletOrderFindings = 0; $crossFindings = 0

foreach ($f in $in.Files) {
    #  A FILE THE SWEEP CANNOT READ IS A FINDING, NOT A SKIP. An empty,
    #  whitespace-only or unparseable spine file used to fall through this
    #  loop in silence, and a sub-section that had lost its content passed
    #  the ceiling by having no prose to answer anything.
    $json = $null; $readError = ''
    try { $json = Get-GateJson -Path $f.FullName } catch { $readError = $_.Exception.Message }
    if ($null -eq $json) {
        $why = if ($readError) { 'unparseable (' + $readError + ')' } else { 'empty or whitespace-only' }
        $emptyFiles.Add(("{0}: {1}" -f $f.Name, $why))
        Write-Host ("  X {0}: spine file {1} is {2} - a file the sweep cannot read is a finding, not a skip" -f $GATE, $f.Name, $why) -ForegroundColor Red
        continue
    }
    $filesRead++
    $sub = Get-SmFileSubSection -Json $json -RegisterDoc $in.Register
    $own = @($grids | Where-Object { $sub -and $_.SubSection -eq $sub })
    $ownKeys = @{}
    foreach ($g in $own) { $ownKeys[$g.Key] = $true }
    $toScan = if ($OwnOnly) { $own } else { $grids }
    if (@($toScan).Count -eq 0) { continue }
    $pairsScanned += @($toScan).Count
    $crossPairs += (@($toScan).Count - $own.Count)

    $sentences = Get-SmSentences -Json $json -File $f.Name -Skip $skipTable
    $totalSentences += $sentences.Count
    $scan = Invoke-SmScan -Sentences $sentences -Grids $toScan -AnchorWindow $AnchorWindow -MinHitWords $MinHitWords -MinHitShare $MinHitShare -AliasAmbientCeiling $AliasAmbientCeiling

    $fileBlock = 0; $fileReport = 0
    $gridReports = New-Object System.Collections.Generic.List[object]
    $lines = New-Object System.Collections.Generic.List[string]

    foreach ($g in $toScan) {
        $isOwn = $ownKeys.ContainsKey($g.Key)
        $rows = @(Get-SmMatrix -Grid $g -Scan $scan)
        $full = @($rows | Where-Object { $_.Full })
        $partial = @($rows | Where-Object { $_.Partial })
        if ($full.Count -eq 0 -and $partial.Count -eq 0) {
            #  A clean OWN grid is still RECORDED. Test-GridDisposition reads
            #  this report by grid, and "examined, nothing answered" and "never
            #  examined" used to be the same absence, read as zero. The record
            #  carries the matrix and no arm, and counts toward no total.
            if ($isOwn) {
                $gridReports.Add([pscustomobject]@{
                    SubSection = $g.SubSection; Ref = $g.Ref; Id = $g.Id; Kind = $g.Kind; Own = $true; Examined = $true
                    Allowance = $g.Allowance; ItemCount = $g.ItemCount
                    FullRows = 0; PartialRows = 0; Block = $false
                    Arms = @(); Rows = $rows; Anchors = @()
                })
            }
            continue
        }

        $arms = New-Object System.Collections.Generic.List[string]
        $anchors = New-Object System.Collections.Generic.List[object]
        $block = $false

        # anchors: every sentence that answered a cell, as path + row label + column heading
        foreach ($s in $scan.Sentences) {
            $seen = @{}
            foreach ($h in $s.Hits) {
                if ($h.GridKey -ne $g.Key) { continue }
                $row = $g.Rows[$h.Row]
                $hdr = ''
                foreach ($c in $row.Cells) { if ($c.Col -eq $h.Col) { $hdr = $c.Header } }
                $ak = "{0}|{1}" -f $h.Row, $h.Col
                if ($seen.ContainsKey($ak)) { continue }
                $seen[$ak] = $true
                $anchors.Add([pscustomobject]@{ Path = $s.Path; Sentence = $s.Index; Channel = $s.Channel; Slot = $s.Slot; Row = $row.Label; Column = $hdr })
            }
        }

        if ($isOwn) {
            if ($full.Count -gt $g.Allowance) {
                $block = $true
                $arms.Add(("FULL ROWS: {0} answered in full, allowance {1}" -f $full.Count, $g.Allowance))
            }
            #  ROW ORDER, per channel
            if ($g.ItemCount -ge 3) {
                $answeredRows = @{}
                foreach ($r in $rows) { if ($r.AnsweredCells -gt 0) { $answeredRows[$r.Index] = $true } }
                $byChannel = @{}
                foreach ($s in $scan.Sentences) {
                    foreach ($k in $s.Anchored.Keys) {
                        if (-not $k.StartsWith($g.Key + '|')) { continue }
                        $ri = [int]$k.Substring($k.LastIndexOf('|') + 1)
                        if (-not $answeredRows.ContainsKey($ri)) { continue }
                        if (-not $byChannel.ContainsKey($s.Channel)) { $byChannel[$s.Channel] = New-Object System.Collections.Generic.List[int] }
                        if (-not $byChannel[$s.Channel].Contains($ri)) { $byChannel[$s.Channel].Add($ri) }
                    }
                }
                $needLcs = [math]::Min($RowOrderCap, $g.ItemCount)
                foreach ($ch in ($byChannel.Keys | Sort-Object)) {
                    $seq = @($byChannel[$ch] | ForEach-Object { [int]$g.Rows[$_].Order })
                    $lcs = Get-SmLisLength -Seq $seq
                    if ($lcs -ge $needLcs) {
                        $block = $true
                        $arms.Add(("ROW ORDER: channel '{0}' anchors {1} answered row(s) and {2} follow the task's own order (threshold {3})" -f $ch, $seq.Count, $lcs, $needLcs))
                    }
                }
            }
        }
        else {
            $arms.Add(("CROSS-GRID (report): {0} full, {1} partial row(s) of another sub-section's grid ({2})" -f $full.Count, $partial.Count, $g.SubSection))
        }
        if ($partial.Count -gt 0) { $arms.Add(("PARTIAL (report): {0} row(s) with at least one cell answered: {1}" -f $partial.Count, (($partial | ForEach-Object { $_.Label }) -join '; '))) }

        #  BULLET ORDER, per paragraph per cell
        $byPara = @{}
        foreach ($h in $scan.Hits) {
            if ($h.GridKey -ne $g.Key) { continue }
            $s = $scan.Sentences[$h.Sentence]
            $pk = "{0}|{1}|{2}" -f $s.Path, $h.Row, $h.Col
            if (-not $byPara.ContainsKey($pk)) { $byPara[$pk] = New-Object System.Collections.Generic.List[object] }
            $byPara[$pk].Add($h)
        }
        foreach ($pk in ($byPara.Keys | Sort-Object)) {
            $hs = @($byPara[$pk] | Sort-Object Sentence, Bullet)
            $seq = New-Object System.Collections.Generic.List[int]
            $seenB = @{}
            foreach ($h in $hs) { if (-not $seenB.ContainsKey($h.Bullet)) { $seenB[$h.Bullet] = $true; $seq.Add([int]$h.Bullet) } }
            if ($seq.Count -lt $BulletOrderMin) { continue }
            $lis = Get-SmLisLength -Seq $seq.ToArray()
            if ($lis -ge $BulletOrderMin) {
                $parts = $pk -split '\|'
                $row = $g.Rows[[int]$parts[1]]
                $hdr = ''
                foreach ($c in $row.Cells) { if ($c.Col -eq [int]$parts[2]) { $hdr = $c.Header } }
                $arms.Add(("BULLET ORDER (report): {0} - {1} / {2}: {3} bullets in the model's order" -f $parts[0], $row.Label, $hdr, $lis))
            }
        }

        if ($block) { $fileBlock++ } else { $fileReport++ }
        #  per-arm findings, for the roster
        if ($isOwn) {
            if (@($arms | Where-Object { $_ -like 'FULL ROWS:*' }).Count -gt 0) { $fullRowsFindings++ }
            if (@($arms | Where-Object { $_ -like 'ROW ORDER:*' }).Count -gt 0) { $rowOrderFindings++ }
        }
        else { $crossFindings++ }
        if ($partial.Count -gt 0) { $partialFindings++ }
        $bulletOrderFindings += @($arms | Where-Object { $_ -like 'BULLET ORDER*' }).Count
        $gridReports.Add([pscustomobject]@{
            SubSection = $g.SubSection; Ref = $g.Ref; Id = $g.Id; Kind = $g.Kind; Own = $isOwn; Examined = $true
            Allowance = $g.Allowance; ItemCount = $g.ItemCount
            FullRows = $full.Count; PartialRows = $partial.Count; Block = $block
            Arms = $arms.ToArray(); Rows = $rows; Anchors = $anchors.ToArray()
        })

        # console
        if (-not $Quiet) {
            $tag = if ($block) { 'BLOCK' } else { 'report' }
            $colour = if ($block) { 'Red' } elseif ($isOwn) { 'Yellow' } else { 'DarkGray' }
            $lines.Add(("  {0} {1}  vs {2} [{3}, {4} rows, allowance {5}{6}]  FULL {7}  PARTIAL {8}" -f $(if ($block) { 'X' } else { '~' }), $f.Name, $g.Ref, $g.Kind, $g.ItemCount, $g.Allowance, $(if ($isOwn) { '' } else { ', other sub-section ' + $g.SubSection }), $full.Count, $partial.Count))
            $hdrs = @($g.Rows[0].Cells | ForEach-Object { $_.Header })
            $lines.Add(("       {0,-34} | {1}" -f 'row', (($hdrs | ForEach-Object { if ($_.Length -gt 22) { $_.Substring(0, 22) } else { $_ } }) -join ' | ')))
            foreach ($r in $rows) {
                $cellTxt = @($r.Cells | ForEach-Object { if (-not $_.Scoreable) { '   -    ' } else { ("{0}/{1}{2}" -f $_.Hits, $_.Need, $(if ($_.Answered) { ' *' } else { '  ' })).PadRight(8) } })
                $state = if ($r.Full) { 'FULL in ' + (@($r.FullIn) -join ',') } elseif ($r.Partial) { 'partial' } else { '' }
                $lab = if ($r.Label.Length -gt 34) { $r.Label.Substring(0, 34) } else { $r.Label }
                $lines.Add(("       {0,-34} | {1}  {2}" -f $lab, ($cellTxt -join ' | '), $state))
            }
            foreach ($a in $arms) { $lines.Add(("       -> {0}" -f $a)) }
            foreach ($a in ($anchors | Select-Object -First 12)) { $lines.Add(("       at {0} s{1}: {2} / {3}" -f $a.Path, $a.Sentence, $a.Row, $a.Column)) }
            if ($anchors.Count -gt 12) { $lines.Add(("       ... {0} more anchor(s) in the report file" -f ($anchors.Count - 12))) }
            $lines.Add(("       tag:{0}" -f $tag))
        }
    }

    $blockTotal += $fileBlock; $reportTotal += $fileReport
    $fileReports.Add([pscustomobject]@{ File = $f.Name; SubSection = $sub; Sentences = $sentences.Count; OwnGrids = $own.Count; Block = $fileBlock; Report = $fileReport; Ambient = $scan.Ambient; Grids = $gridReports.ToArray() })

    if (-not $Quiet -and ($lines.Count -gt 0 -or $scan.Ambient.Count -gt 0)) {
        Write-Host ''
        Write-Host ("  {0}  (sub-section {1}; {2} sentences; {3} own grid(s))" -f $f.Name, $(if ($sub) { $sub } else { 'none - topic or front matter' }), $sentences.Count, $own.Count) -ForegroundColor Cyan
        foreach ($am in $scan.Ambient) { Write-Host ("    ambient alias not used as an anchor in this file: {0}" -f $am) -ForegroundColor DarkGray }
        foreach ($l in $lines) {
            if ($l -match '^\s+tag:(\w+)$') { continue }
            $c = 'DarkGray'
            if ($l -match '^\s+X ') { $c = 'Red' } elseif ($l -match '^\s+~ ') { $c = 'Yellow' } elseif ($l -match '^\s+-> (FULL|ROW)') { $c = 'Red' } elseif ($l -match '^\s+-> ') { $c = 'Yellow' }
            Write-Host $l -ForegroundColor $c
        }
    }
}

# ---------------------------------------------------------------------------
# Arms: every declared arm ends ran, empty or declared-n-a. The check-set of
# the scoring arms is the (file, grid) pairs actually scored; a spine that
# yields none is a refusal, never a pass.
# ---------------------------------------------------------------------------
Write-Host ''
Write-GateCheckSet -What 'file x grid pairs scored' -Count $pairsScanned -DerivedFrom ("{0} spine file(s) read x {1} grid(s){2}" -f $filesRead, $grids.Count, $(if ($OwnOnly) { ' (own grids only)' } else { '' })) -Blocking -Input 'the spine files Get-GateSpineFiles enumerated'
if ($filesRead -gt 0) { Complete-GateArm -Name 'spine-files' -State ran -Size $filesRead -Findings $emptyFiles.Count } else { Complete-GateArm -Name 'spine-files' -State empty }
if ($pairsScanned -gt 0) {
    Complete-GateArm -Name 'full-rows' -State ran -Size $pairsScanned -Findings $fullRowsFindings
    Complete-GateArm -Name 'row-order' -State ran -Size $pairsScanned -Findings $rowOrderFindings
    Complete-GateArm -Name 'partial-rows' -State ran -Size $pairsScanned -Findings $partialFindings
    Complete-GateArm -Name 'bullet-order' -State ran -Size $pairsScanned -Findings $bulletOrderFindings
}
else {
    foreach ($armName in @('full-rows', 'row-order', 'partial-rows', 'bullet-order')) { Complete-GateArm -Name $armName -State empty }
}
if ($crossPairs -gt 0) { Complete-GateArm -Name 'cross-grid' -State ran -Size $crossPairs -Findings $crossFindings } else { Complete-GateArm -Name 'cross-grid' -State empty }
$roster = Write-GateArmRoster
Assert-GateArmsComplete

#  THE STAMP. Fingerprint of the spine directory this run enumerated, the
#  UTC time it was generated, the mode and the file list - what
#  Test-GridDisposition checks before it believes a single number in here.
$fingerprint = Get-SpineFingerprint -BuildDir $BuildDir -SpineDir $SpineDir -Quiet
#  'files' keeps its historical meaning for every reader of this report (the
#  per-file grid matrices); the stamp's file list is 'spineFiles'.
$report = [pscustomobject]@{
    gate = $GATE
    generated = (Get-Date).ToUniversalTime().ToString('o')
    spineFingerprint = $fingerprint
    mode = $mode
    spineFiles = @($in.Files | ForEach-Object { $_.Name })
    buildDir = $BuildDir
    spineDir = $(if ($SpineDir) { $SpineDir } else { Join-Path $BuildDir 'spine' })
    register = $in.RegisterPath
    cells = $in.CellsPath
    calibration = [pscustomobject]@{ anchorWindow = $AnchorWindow; minHitWords = $MinHitWords; minHitShare = $MinHitShare; dfCeiling = $DfCeiling; aliasAmbientCeiling = $AliasAmbientCeiling; rowOrderCap = $RowOrderCap; bulletOrderMin = $BulletOrderMin; ownOnly = [bool]$OwnOnly }
    pipelineApplied = $set.Applied
    commonWordsStripped = $set.CommonWords
    emptyFiles = $emptyFiles.ToArray()
    arms = @($roster)
    files = $fileReports.ToArray()
    summary = [pscustomobject]@{ files = $in.Files.Count; filesRead = $filesRead; emptyFiles = $emptyFiles.Count; pairsScanned = $pairsScanned; sentences = $totalSentences; blockGrids = $blockTotal; reportGrids = $reportTotal }
}
Write-SmJson -Object $report -Path $ReportPath

Write-Host ''
if (-not $Quiet) { Write-Host ("  report written to {0}  ({1} sentences scored; stamped {2}, mode {3})" -f $ReportPath, $totalSentences, $fingerprint, $mode) -ForegroundColor DarkGray }
if ($emptyFiles.Count -gt 0) {
    Write-Host ("  X {0} spine file(s) could not be read - a finding, not a skip: {1}" -f $emptyFiles.Count, ($emptyFiles.ToArray() -join '; ')) -ForegroundColor Red
}
if ($blockTotal -eq 0 -and $emptyFiles.Count -eq 0) {
    if ($reportTotal -gt 0) { Write-Host ("  {0} grid(s) at REPORT level only - read at Stage 3d; no BLOCK arm fired" -f $reportTotal) -ForegroundColor Yellow }
    Write-Host '  no sub-section writes its own assessed grid into the prose beyond the allowance' -ForegroundColor Green
    exit 0
}
if ($blockTotal -gt 0) { Write-Host ("  {0} sub-section/grid pair(s) BLOCK; {1} more at report level" -f $blockTotal, $reportTotal) -ForegroundColor Red }
Write-Host '  This gate reports the anchor and does not decide. Rewrite the anchored sentences as mechanism' -ForegroundColor Yellow
Write-Host '  (what happens and why) without naming the assessed row beside its answer, or set the example' -ForegroundColor Yellow
Write-Host '  on an unassessed subject from the register. Clearance is a Stage 3d decision recorded in' -ForegroundColor Yellow
Write-Host '  figures.json "mirrorAllow" with a written reason - never a change to this gate.' -ForegroundColor Yellow
exit 1

}
catch {
    #  The two typed refusals Lib-GateCommon throws - an empty blocking
    #  check-set, or a blocking arm that never finished - are exit 2, and the
    #  roster is printed so a runner can see which arm starved. Anything else
    #  is a gate defect and is re-thrown as one.
    $m = $_.Exception.Message
    if ($m -match '^(CHECK-SET EMPTY|ARMS INCOMPLETE)') {
        Write-Host ("  X {0}: {1}" -f $GATE, $m) -ForegroundColor Red
        try { [void](Write-GateArmRoster) } catch { }
        exit 2
    }
    throw
}
