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

    THE SPINE INCLUDES ITS FRONT MATTER (P0-11). Get-GateSpineFiles excludes
    front.json, cover.json and deckframe.json by default, and that default was
    left in place here for a year: deckframe.json's frame slides - the deck's
    opening, section and closing furniture, authored by the same hand as every
    other slide - have never been swept by any text gate, and neither had
    front.json. Both are swept now. cover.json is the ONE exclusion, because
    Assert-PromptLint owns the cover, and the exclusion is printed beside the
    check-set so a reader can see what this gate chose not to sweep without
    opening it.

    A SPINE FILE THE SWEEP CANNOT READ IS A FINDING, NOT A SKIP. An empty,
    whitespace-only or unparseable file used to fall through the loop in
    silence, and a file that had lost its content swept clean by having no
    text in it.

    ARMS (P0-09). spine-channels and blocking-runs BLOCK; marking-vocabulary,
    reported-runs and rendered-extracts report. Every arm is registered before
    it runs and completed before the verdict, the roster is printed as one
    ARMS: line, and a blocking arm whose check-set is empty is a refusal
    (exit 2), never a pass.

    SELF-TEST:  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Check-FigureLeakage.ps1 -SelfTest

    PS 5.1. ASCII only in this file. Exit 1 on a blocking hit, 2 on a refusal.
#>

#  4 and 7c are named because Run-Gates PLANS this gate in both bands (the
#  'leakage' entry, once before artwork and once after). A header that said 3c
#  alone claimed the rendered sweep ran nowhere, and no rule checked that
#  direction, so the two could disagree in silence.
# GATE: stages=3c,4,7c; requires=BuildDir,ExcludeText; 7c: DocText

[CmdletBinding()]
param(
    #  NOT [Parameter(Mandatory)]. A mandatory parameter PROMPTS, and a gate
    #  that prompts inside a runner's job hangs instead of failing; an absent
    #  input is a refusal that names itself (exit 2), below.
    [string] $BuildDir,
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
    [switch] $SelfTest,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

$GATE = 'Check-FigureLeakage'

#  cover.json and ONLY cover.json. Named once, printed with the check-set,
#  and passed to the enumerator, so the exclusion is one fact in one place.
$script:FlExclude = @('cover.json')

# ---------------------------------------------------------------------------
# SELF-TEST. Synthetic build in the temp directory; every string invented.
# The gate is invoked as a child of this process on each plant, the plant is
# read back from the fixture before the verdict is trusted, and the run ends
# SELF-TEST PASS (exit 0) or SELF-TEST FAIL (exit 4).
# ---------------------------------------------------------------------------
if ($SelfTest) {
    Write-Host ''
    Write-Host ("  {0} SELF-TEST - a clean result is not believed until the gate has failed on a planted defect" -f $GATE) -ForegroundColor Cyan
    $script:FlSelfTestFailed = 0
    $self = $MyInvocation.MyCommand.Path
    $fx = Join-Path ([System.IO.Path]::GetTempPath()) ('fl-selftest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path (Join-Path $fx 'spine'), (Join-Path $fx 'corpus') | Out-Null

    function Test-FlSelf { param([bool] $Ok, [string] $What) if ($Ok) { Write-Host ("    ok   {0}" -f $What) -ForegroundColor Green } else { Write-Host ("    X    {0}" -f $What) -ForegroundColor Red; $script:FlSelfTestFailed++ } }
    function Write-FlFixture { param([string] $Path, $Object) [System.IO.File]::WriteAllText($Path, ($Object | ConvertTo-Json -Depth 14), (New-Object System.Text.UTF8Encoding($true))) }
    function Write-FlText { param([string] $Path, [string] $Text) [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($true))) }
    function Invoke-FlSelf {
        param([hashtable] $Arguments)
        $text = ''; $rc = -1
        try { $lines = @(& $self @Arguments *>&1 | ForEach-Object { "$_" }); $rc = $LASTEXITCODE; $text = ($lines -join "`n") }
        catch { $text = "EXCEPTION: " + $_.Exception.Message; $rc = -1 }
        return [pscustomobject]@{ Rc = $rc; Text = $text }
    }

    #  One assessor-only run of more than 15 words, one that the unit also
    #  carries (class U, never leakage), and one repeated structural label.
    $LEAK  = 'A satisfactory answer covers the spindle tension check, the bearing oil interval and the belt fray inspection in that order.'
    $UNITQ = 'The candidate must demonstrate the safe assembly of the guard, the interlock and the emergency stop before any production run.'
    $CLEAN = 'A dry bearing seizes because the oil film that carries the load has been squeezed out of the running clearance entirely.'

    $spineDir  = Join-Path $fx 'spine'
    $subPath   = Join-Path $spineDir 't1_1.1.json'
    $frontPath = Join-Path $spineDir 'front.json'
    $coverPath = Join-Path $spineDir 'cover.json'
    $deckPath  = Join-Path $spineDir 'deckframe.json'
    $assessorTxt = Join-Path $fx 'corpus\Assessor_Guide_TEST.txt'

    function Reset-FlSpine {
        <# A spine whose every string is the guide teaching mechanism: the negative control, rebuilt before each plant. #>
        Write-FlFixture -Path $subPath   -Object @{ ref = '1.1'; title = 'Widgets'; underpinningKnowledge = @($CLEAN) }
        Write-FlFixture -Path $frontPath -Object @{ title = 'Learner Guide'; blurb = 'This guide prepares you for the assessment tasks in the workbook.' }
        Write-FlFixture -Path $coverPath -Object @{ title = 'Learner Guide'; subtitle = 'Widgets and their care' }
        Write-FlFixture -Path $deckPath  -Object @{ frames = @(@{ id = 'opening'; heading = 'Welcome'; body = 'We will work through the mechanism first and the practice afterwards.' }) }
    }

    try {
        #  The corpus: one learner-facing document, one assessor guide whose
        #  structural label repeats, so the marking vocabulary is DERIVED.
        Write-FlText -Path (Join-Path $fx 'corpus\Learner_Workbook_TEST.txt') -Text @"
Task 1(a)
Complete the table below in your own words.
Widget
Purpose
Care
Write here.
A dry bearing seizes because the oil film that carries the load has been squeezed out of the running clearance entirely.
"@
        Write-FlText -Path $assessorTxt -Text @"
Assessor benchmark
$LEAK
Assessor benchmark
$UNITQ
Mark NS when the response omits the interval
Mark NS when the response omits the interval
"@
        Write-FlText -Path (Join-Path $fx 'unit_extract.md') -Text @"
# Performance Evidence

$UNITQ
"@
        $unit = Join-Path $fx 'unit_extract.md'
        Reset-FlSpine

        # ---- plant 1: THE ASSESSOR LITERAL IN deckframe.json. Front matter was
        #      excluded by the enumerator's default, so this cell was swept by
        #      nobody; cover.json is the one file that stays out.
        $deck = @{ frames = @(@{ id = 'opening'; heading = 'Welcome'; body = 'We will work through the mechanism first and the practice afterwards.' },
                              @{ id = 'closing'; heading = 'Before you finish'; notes = $LEAK }) }
        Write-FlFixture -Path $deckPath -Object $deck
        Test-FlSelf -Ok ((Get-GateFileText -Path $deckPath).IndexOf('belt fray inspection', [System.StringComparison]::Ordinal) -ge 0 -and (Get-GateFileText -Path $subPath) -notmatch 'belt fray') -What 'plant 1 landed: the assessor literal sits in deckframe.json and nowhere else on the spine'
        $r1 = Invoke-FlSelf -Arguments @{ BuildDir = $fx; ExcludeText = @($unit); Quiet = $true }
        Test-FlSelf -Ok ($r1.Rc -eq 1 -and $r1.Text -match 'deckframe\.json' -and $r1.Text -match 'belt fray inspection') -What ("an assessor literal planted in deckframe.json is reported, naming the file and the run (rc={0})" -f $r1.Rc)
        Test-FlSelf -Ok ($r1.Text -match '(?m)^ARMS: .*spine-channels\|true\|ran\|\d+\|0' -and $r1.Text -match 'blocking-runs\|true\|ran\|\d+\|1') -What 'the roster prints spine-channels and blocking-runs ran, with the one blocking finding'
        Test-FlSelf -Ok ($r1.Text -match 'excluded 1: cover\.json') -What 'the check-set line prints cover.json as the ONE excluded spine file'
        Reset-FlSpine

        # ---- plant 2: the same literal in front.json is swept too
        Write-FlFixture -Path $frontPath -Object @{ title = 'Learner Guide'; blurb = $LEAK }
        $r2 = Invoke-FlSelf -Arguments @{ BuildDir = $fx; ExcludeText = @($unit); Quiet = $true }
        Test-FlSelf -Ok ($r2.Rc -eq 1 -and $r2.Text -match 'front\.json') -What ("front.json is swept: the same literal there is reported naming the file (rc={0})" -f $r2.Rc)
        Reset-FlSpine

        # ---- plant 3: cover.json is the ONE exclusion - PromptLint owns it
        Write-FlFixture -Path $coverPath -Object @{ title = 'Learner Guide'; subtitle = $LEAK }
        Test-FlSelf -Ok ((Get-GateFileText -Path $coverPath).IndexOf('belt fray inspection', [System.StringComparison]::Ordinal) -ge 0) -What 'plant 3 landed: the literal is in cover.json'
        $r3 = Invoke-FlSelf -Arguments @{ BuildDir = $fx; ExcludeText = @($unit); Quiet = $true }
        Test-FlSelf -Ok ($r3.Rc -eq 0 -and $r3.Text -notmatch 'cover\.json\]') -What ("cover.json is not swept - it is Assert-PromptLint's file (rc={0})" -f $r3.Rc)
        Reset-FlSpine

        # ---- plant 4: negative control - mechanism prose the learner document also carries
        $r4 = Invoke-FlSelf -Arguments @{ BuildDir = $fx; ExcludeText = @($unit); Quiet = $true }
        Test-FlSelf -Ok ($r4.Rc -eq 0 -and $r4.Text -match 'no channel carries assessor-only wording') -What ("negative control: a spine of mechanism prose exits 0 (rc={0})" -f $r4.Rc)
        Test-FlSelf -Ok ($r4.Text -match '(?m)^ARMS: .*blocking-runs\|true\|ran\|\d+\|0' -and $r4.Text -match 'marking-vocabulary\|false\|ran\|') -What 'on the clean run every registered arm ends ran, the blocking one with 0 findings'

        # ---- plant 5: the UNIT's own wording is class U, never leakage
        Write-FlFixture -Path $subPath -Object @{ ref = '1.1'; title = 'Widgets'; underpinningKnowledge = @($CLEAN, $UNITQ) }
        Test-FlSelf -Ok ((Get-GateFileText -Path $subPath).IndexOf('emergency stop before any production run', [System.StringComparison]::Ordinal) -ge 0) -What 'plant 5 landed: the spine quotes the unit, and the assessor guide quotes it too'
        $r5 = Invoke-FlSelf -Arguments @{ BuildDir = $fx; ExcludeText = @($unit); Quiet = $true }
        Test-FlSelf -Ok ($r5.Rc -eq 0) -What ("a run the UNIT also carries is a quotation, not a leak (rc={0})" -f $r5.Rc)
        Reset-FlSpine

        # ---- plant 6: a derived marking phrase in a learner channel
        Write-FlFixture -Path $subPath -Object @{ ref = '1.1'; title = 'Widgets'; underpinningKnowledge = @($CLEAN); activity = 'Assessor benchmark for this task' }
        $r6 = Invoke-FlSelf -Arguments @{ BuildDir = $fx; ExcludeText = @($unit); Quiet = $true }
        Test-FlSelf -Ok ($r6.Rc -eq 1 -and $r6.Text -match '(?i)assessor benchmark' -and $r6.Text -match 't1_1\.1\.json') -What ("a marking phrase derived from the assessor guide's own repeated labels is reported naming the file (rc={0})" -f $r6.Rc)
        Reset-FlSpine

        # ---- plant 7: an empty spine file is a NAMED finding, not a silent skip
        $emptyPath = Join-Path $spineDir 't1_1.2.json'
        [System.IO.File]::WriteAllText($emptyPath, "   `r`n", (New-Object System.Text.UTF8Encoding($true)))
        Test-FlSelf -Ok ((Test-Path -LiteralPath $emptyPath) -and -not (Get-GateFileText -Path $emptyPath).Trim()) -What 'plant 7 landed: t1_1.2.json exists and is whitespace-only'
        $r7 = Invoke-FlSelf -Arguments @{ BuildDir = $fx; ExcludeText = @($unit); Quiet = $true }
        Test-FlSelf -Ok ($r7.Rc -eq 1 -and $r7.Text -match 't1_1\.2\.json' -and $r7.Text -match '(?i)empty') -What ("an unreadable spine file exits 1 naming the file (rc={0})" -f $r7.Rc)
        Remove-Item -LiteralPath $emptyPath -Force

        # ---- plant 8: -ExcludeText naming a file that is not there is a refusal
        $r8 = Invoke-FlSelf -Arguments @{ BuildDir = $fx; ExcludeText = @((Join-Path $fx 'no_such_unit.md')); Quiet = $true }
        Test-FlSelf -Ok ($r8.Rc -eq 2 -and $r8.Text -match 'no_such_unit\.md') -What ("-ExcludeText naming a missing file is a refusal by name (rc={0})" -f $r8.Rc)

        # ---- plant 9: a corpus with no assessor guide is an empty check-set
        $stash = Join-Path $fx 'Assessor_Guide_TEST.stash'
        Move-Item -LiteralPath $assessorTxt -Destination $stash -Force
        Test-FlSelf -Ok (-not (Test-Path -LiteralPath $assessorTxt)) -What 'plant 9 landed: the corpus holds no assessor-only document'
        $r9 = Invoke-FlSelf -Arguments @{ BuildDir = $fx; ExcludeText = @($unit); Quiet = $true }
        Test-FlSelf -Ok ($r9.Rc -eq 2 -and $r9.Text -match 'CHECK-SET EMPTY' -and $r9.Text -match '(?i)assessor-only documents') -What ("a corpus with no assessor guide is a refusal naming the input, never a green sweep (rc={0})" -f $r9.Rc)
        Move-Item -LiteralPath $stash -Destination $assessorTxt -Force
    }
    finally {
        try { Remove-Item -LiteralPath $fx -Recurse -Force -ErrorAction SilentlyContinue } catch { }
    }

    Write-Host ''
    if ($script:FlSelfTestFailed -gt 0) {
        Write-Host ("  SELF-TEST FAIL: {0} check(s) failed - no result from this gate may be believed until they pass" -f $script:FlSelfTestFailed) -ForegroundColor Red
        exit 4
    }
    Write-Host '  SELF-TEST PASS: the gate reported the literal planted in deckframe.json and in front.json, left cover.json to PromptLint, refused an empty check-set by name and passed the negative control' -ForegroundColor Green
    exit 0
}

#  Stamped before the run so the catch can tell THIS run's report on disk from
#  one an earlier run left in the same place.
$script:FlRunStart = (Get-Date).ToUniversalTime().AddSeconds(-2)
$script:FlVerdictFromReport = $null

try {

# ---------------------------------------------------------------------------
# 0. Arms, declared before any of them runs
# ---------------------------------------------------------------------------

if (-not $BuildDir) {
    Write-Host ("  X {0}: -BuildDir is required - it is where the corpus, the spine and the registry are found." -f $GATE) -ForegroundColor Red
    exit 2
}

Register-GateArm -Name 'spine-channels' -Blocking
Register-GateArm -Name 'blocking-runs' -Blocking
Register-GateArm -Name 'marking-vocabulary'
Register-GateArm -Name 'reported-runs'
Register-GateArm -Name 'rendered-extracts'

# ---------------------------------------------------------------------------
# 1. The corpus, split by audience, plus the legitimately shared text
# ---------------------------------------------------------------------------

$corpusDirResolved = Get-GateCorpusDir -BuildDir $BuildDir -CorpusDir $CorpusDir
$corpus = Get-GateCorpusDocs -CorpusDir $corpusDirResolved -BuildDir $BuildDir

#  BOTH SIDES OF THE COMPARISON ARE BLOCKING CHECK-SETS. With no assessor
#  guide the sweep passes by having nothing to check - precisely how a
#  benchmark leak survived to the last audit round; with no learner-facing
#  document every assessor phrase looks unique and the whole pack reports as
#  leakage. Either way the refusal names the corpus, and the runner sees
#  exit 2 rather than a green line or a stack trace.
$assessorCount = [int](@($corpus.Assessor).Count)
$learnerCount  = [int](@($corpus.Learner).Count)
Write-GateCheckSet -What 'assessor-only documents' -Count $assessorCount `
    -DerivedFrom ("the Stage 1 corpus at {0}, classified from the {1}" -f (Split-Path $corpusDirResolved -Leaf), $corpus.ClassifiedFrom) `
    -Blocking -Input ("assessor-only documents in {0} (Stage 1 extracts EVERY pack document, learner-facing and assessor-only, exactly once)" -f $corpusDirResolved)
Write-GateCheckSet -What 'learner-facing documents' -Count $learnerCount `
    -DerivedFrom ("the Stage 1 corpus at {0}, classified from the {1}" -f (Split-Path $corpusDirResolved -Leaf), $corpus.ClassifiedFrom) `
    -Blocking -Input ("learner-facing documents in {0}" -f $corpusDirResolved)

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
    if (-not (Test-Path -LiteralPath $x)) {
        Write-Host ("  X {0}: -ExcludeText names a file that does not exist: {1}. The unit corpus is an input, not an option; without it every unit line the guide teaches is misreported as assessor-only." -f $GATE, $x) -ForegroundColor Red
        try { [void](Write-GateArmRoster) } catch { }
        exit 2
    }
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
}
#  BLOCKING, AND OUTSIDE THE -Quiet GUARD. An empty blocking check-set is a
#  sweep with nothing in it, which passes by having nothing to check; the
#  typed refusal reaches exit 2 through the catch at the end of this file.
#  Printing it only when the console is verbose made the blocking rule an
#  effect of a display switch.
Write-GateCheckSet -What ("blocking {0}-word phrases" -f $BlockShingle) -Count $blockSet.Count `
    -DerivedFrom 'the WHOLE assessor text, minus every learner-facing document and every excluded source' `
    -Blocking -Input ("runs of {0} words in the assessor-only documents of {1}" -f $BlockShingle, $corpusDirResolved)
Write-GateCheckSet -What ("reported {0}-word phrases" -f $Shingle) -Count $reportSet.Count -DerivedFrom 'the whole assessor text, minus every learner-facing document and every excluded source'

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
Write-GateCheckSet -What 'assessor-only marking phrases' -Count $vocab.Count -DerivedFrom ("the assessor guides' own repeated structural labels ({0}+ occurrences), absent from every learner-facing document" -f $MinVocabRepeats)
if (-not $Quiet) {
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
$emptyFiles = New-Object System.Collections.Generic.List[string]
$figs = 0
#  -IncludeFrontMatter with an explicit -Exclude: front.json and
#  deckframe.json's frame slides ARE authored text and are swept; cover.json
#  is Assert-PromptLint's and is the one exclusion (P0-11).
$spineFiles = @(Get-GateSpineFiles -BuildDir $BuildDir -SpineDir $SpineDir -IncludeFrontMatter -Exclude $script:FlExclude)
$filesRead = 0
foreach ($f in $spineFiles) {
    $j = $null; $readError = ''
    try { $j = Get-GateJson -Path $f.FullName } catch { $readError = $_.Exception.Message }
    if ($null -eq $j) {
        $why = if ($readError) { 'unparseable (' + $readError + ')' } else { 'empty or whitespace-only' }
        $emptyFiles.Add(("{0}: {1}" -f $f.Name, $why))
        Write-Host ("  X {0}: spine file {1} is {2} - a file the sweep cannot read is a finding, not a skip" -f $GATE, $f.Name, $why) -ForegroundColor Red
        continue
    }
    $filesRead++
    if (@($j.PSObject.Properties.Name) -contains 'visuals') { $figs += @(@($j.visuals) | Where-Object { $null -ne $_ -and @($_.PSObject.Properties.Name) -contains 'spec' -and $null -ne $_.spec }).Count }
    foreach ($c in (Get-GateSpineCells -Node $j -File $f.Name -Path '' -Channel '' -Slot '' -Skip $skip)) { $cells.Add($c) }
}
$spineCells = $cells.Count
Write-GateCheckSet -What 'spine strings' -Count $spineCells `
    -DerivedFrom ("{0} of {1} spine file(s), front matter included" -f $filesRead, $spineFiles.Count) `
    -Blocking -Input 'the spine files Get-GateSpineFiles enumerated' -Excluded $script:FlExclude

$renderedIn = @($DocText | Where-Object { $_ })
foreach ($d in $renderedIn) {
    if (-not (Test-Path -LiteralPath $d)) {
        Write-Host ("  X {0}: -DocText names a rendered extract that does not exist: {1}. A rendered arm handed a path it cannot read did not run." -f $GATE, $d) -ForegroundColor Red
        try { [void](Write-GateArmRoster) } catch { }
        exit 2
    }
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

# ---------------------------------------------------------------------------
# Arms: every declared arm ends ran, empty or declared-n-a. The blocking arms
# examined the spine strings and the assessor's own blocking runs; a spine
# that yields neither is a refusal, never a pass.
# ---------------------------------------------------------------------------
Complete-GateArm -Name 'spine-channels' -State ran -Size $spineCells -Findings $emptyFiles.Count
Complete-GateArm -Name 'blocking-runs' -State ran -Size $blockSet.Count -Findings $live.Count
#  TEMPORARIES, DELIBERATELY. `@(...)` in a named-parameter argument position
#  is read as a splat and throws "Argument types do not match" - a PS 5.1 trap
#  that parses clean and fails only at run time. Every count below is computed
#  into a variable first.
$vocabFindings = [int]$vocabHits.Count
$renderedCells = [int]($cells.Count - $spineCells)
$renderedFindings = [int](@($live | Where-Object { $_.Cell.Channel -eq 'rendered' }).Count)
if ($vocab.Count -gt 0) { Complete-GateArm -Name 'marking-vocabulary' -State ran -Size $vocab.Count -Findings $vocabFindings } else { Complete-GateArm -Name 'marking-vocabulary' -State empty }
Complete-GateArm -Name 'reported-runs' -State ran -Size $reportSet.Count -Findings $reported.Count
if ($renderedIn.Count -gt 0) { Complete-GateArm -Name 'rendered-extracts' -State ran -Size $renderedCells -Findings $renderedFindings }
else { Complete-GateArm -Name 'rendered-extracts' -State empty }
$roster = Write-GateArmRoster
Assert-GateArmsComplete

if ($ReportPath) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("ASSESSOR-ONLY LEAKAGE SWEEP - complete hit list")
    [void]$sb.AppendLine(("generated {0}" -f (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')))
    [void]$sb.AppendLine(("unit extract / shared text: {0}" -f $unitLine))
    [void]$sb.AppendLine(("blocking {0}-word phrases: {1}   reported {2}-word phrases: {3}   marking phrases: {4}" -f $BlockShingle, $blockSet.Count, $Shingle, $reportSet.Count, $vocab.Count))
    [void]$sb.AppendLine(("channels swept: {0}" -f ($channels -join ', ')))
    [void]$sb.AppendLine(("spine files swept: {0} of {1} read (front matter in; excluded {2}){3}" -f $filesRead, $spineFiles.Count, ($script:FlExclude -join ', '), $(if ($emptyFiles.Count -gt 0) { '; unreadable: ' + ($emptyFiles.ToArray() -join '; ') } else { '' })))
    [void]$sb.AppendLine(("arms: {0}" -f (@($roster | ForEach-Object { '{0}={1}/{2}' -f $_.name, $_.state, $_.findings }) -join ' ')))
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('BLOCKING')
    foreach ($h in $live) { [void]$sb.AppendLine(("  [{0}] {1}  slot={2}  channel={3}`n    cell:  {4}`n    match: {5}" -f $h.Cell.File, $h.Cell.Path, $h.Cell.Slot, $h.Cell.Channel, $h.Cell.Text, $h.Phrase)) }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('CLEARED (figures.json leakageAllow, with the reason)')
    foreach ($c in $cleared) { [void]$sb.AppendLine(("  [{0}] {1}  by {2}`n    match:  {3}`n    reason: {4}" -f $c.Hit.Cell.File, $c.Hit.Cell.Path, $c.By, $c.Hit.Phrase, $c.Why)) }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine(("REPORTED (not blocking - shorter shared runs of {0} words, for the Stage 3d and review-band read)" -f $Shingle))
    foreach ($h in $reported) { [void]$sb.AppendLine(("  [{0}] {1}  slot={2}  channel={3}`n    cell:  {4}`n    match: {5}" -f $h.Cell.File, $h.Cell.Path, $h.Cell.Slot, $h.Cell.Channel, $h.Cell.Text, $h.Phrase)) }
    #  THE LAST LINE IS THE VERDICT, IN ONE MACHINE-READABLE FORM. It is written
    #  by the code that decided it, so the console verdict and the report cannot
    #  disagree, and it is what the catch below reads when this run completes and
    #  then throws on its way out. A report without this line is not complete and
    #  is not believed.
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine(("VERDICT: blocking={0} unreadable={1}" -f $live.Count, $emptyFiles.Count))
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

if ($emptyFiles.Count -gt 0) {
    Write-Host ("  X {0} spine file(s) could not be read - a finding, not a skip: {1}" -f $emptyFiles.Count, ($emptyFiles.ToArray() -join '; ')) -ForegroundColor Red
}

if ($live.Count -eq 0 -and $emptyFiles.Count -eq 0) {
    if ($cleared.Count -gt 0) { Write-Host ("  no channel carries assessor-only wording beyond the {0} allow-listed entr(ies) above" -f $cleared.Count) -ForegroundColor Green }
    else { Write-Host '  no channel carries assessor-only wording' -ForegroundColor Green }
    exit 0
}
if ($live.Count -eq 0) { exit 1 }

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

}
catch {
    $m = $_.Exception.Message

    #  ASK THE FILESYSTEM BEFORE BELIEVING THE THROW. The sweep writes its
    #  complete hit list, ending in a VERDICT line, and only then formats the
    #  same finding for the console, so a throw raised after that write says
    #  nothing about whether any channel carries assessor-only wording. The
    #  recorded incident is the same shape: Word finished a 383-page PDF and
    #  then died at COM teardown, and the caller reported FAILED over a correct
    #  file on disk. So the report is read back: it must exist, carry bytes,
    #  have been written by THIS run, and end in a well-formed VERDICT line.
    #  Everything before that write - CHECK-SET EMPTY, ARMS INCOMPLETE, an
    #  unreadable spine - throws with no such report and is unaffected, and a
    #  run given no -ReportPath has no artefact to read and falls through.
    $verdictLine = ''
    if ($ReportPath -and (Test-Path -LiteralPath $ReportPath)) {
        $rfi = Get-Item -LiteralPath $ReportPath -ErrorAction SilentlyContinue
        if ($null -ne $rfi -and $rfi.Length -gt 0 -and $rfi.LastWriteTimeUtc -ge $script:FlRunStart) {
            $rtext = ''
            try { $rtext = [System.IO.File]::ReadAllText($ReportPath) } catch { $rtext = '' }
            $vm = [regex]::Match($rtext, '(?m)^VERDICT: blocking=(\d+) unreadable=(\d+)\s*$')
            if ($vm.Success -and $rtext -match '(?m)^ASSESSOR-ONLY LEAKAGE SWEEP') { $verdictLine = $vm.Value.Trim() }
        }
    }
    if ($verdictLine) {
        $vparts = [regex]::Match($verdictLine, 'blocking=(\d+) unreadable=(\d+)')
        $vBlocking = [int]$vparts.Groups[1].Value
        $vUnreadable = [int]$vparts.Groups[2].Value
        Write-Host ("  ! {0}: the sweep completed and wrote {1}, then threw: {2}" -f $GATE, $ReportPath, $m) -ForegroundColor Yellow
        Write-Host ("  ! the verdict below is read from that report, not from the exception - {0}" -f $verdictLine) -ForegroundColor Yellow
        if ($vBlocking -eq 0 -and $vUnreadable -eq 0) { $script:FlVerdictFromReport = 0 } else { $script:FlVerdictFromReport = 1 }
    }
    else {
        #  The typed refusals Lib-GateCommon throws - an empty blocking check-set,
        #  or a blocking arm that never finished - are exit 2, with the roster
        #  printed so a runner can see which arm starved. Anything else is a gate
        #  defect and is re-thrown as one.
        if ($m -match '^(CHECK-SET EMPTY|ARMS INCOMPLETE)') {
            Write-Host ("  X {0}: {1}" -f $GATE, $m) -ForegroundColor Red
            try { [void](Write-GateArmRoster) } catch { }
            exit 2
        }
        throw
    }
}

#  Reached only through the catch above, when the report on disk carried the
#  verdict the exception was about to hide.
exit ([int]$script:FlVerdictFromReport)
