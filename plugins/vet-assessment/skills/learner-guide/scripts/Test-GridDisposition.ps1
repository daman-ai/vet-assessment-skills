<#
    Test-GridDisposition.ps1 - ONE verdict per (sub-section, assessed grid).

    Runs at Stage 3c after Check-ShapeMirror.ps1 (over the spine),
    Check-RowCoverage.ps1 -Whole and Check-FigureMirror.ps1, and consumes
    their three report files. Writes grid-disposition.json beside them.
    Exit 1 on any grid not disposed or not proven, 2 on a refusal, 0 when
    every grid is disposed.

    WHY ONE VERDICT. The build had a ceiling gate (no answered rows) and, now,
    a floor gate (every row taught), a table mirror and a prose mirror, each
    with its own report. Four green lines are not a disposition: a grid can
    pass the mirror by being withheld and pass nothing else by not being
    taught, and nobody reads four reports against each other for 35 grids.
    So this script reads them BY CONTRACT (the report files' fields, never
    their console text) and states, per grid:

        disposed   answered <= allowance  AND  taught == item count
        cleared    not disposed, but a Stage 3d decision in figures.json
                   "mirrorAllow" (read through Lib-GateCommon's
                   Get-GateAllowList, which refuses an entry with no reason)
                   names this grid and says why
        NOT PROVEN no channel examined this grid at all - exit 1
        NOT DISPOSED   anything else - exit 1

    "answered" is the LARGER of the shape mirror's FULL rows for the grid in
    its own sub-section file and the table mirror's filled rows: a row
    answered in a table and a row answered in prose are the same leak.
    "taught" is the number of assessed rows at or above the whole-spine
    teaching floor, from the coverage report's -Whole run.

    THIS RUN'S REPORTS, AND ONLY THIS RUN'S (P0-08). Every number below comes
    from a file some other process wrote, and a file on disk says nothing
    about when it was written or what it was written from. Run-Gates used to
    start this gate BESIDE the producers it reads, so every verdict was cut
    from last round's reports; and an absent key was read as zero, which
    disposed grids on no evidence at all. Both are refusals now. Each of the
    three reports must be present and must carry:

        spineFingerprint   v2, equal to the spine's fingerprint right now
        generated          UTC ISO 8601, at or after -NotBefore
        mode               'whole' - a per-file run scores one file's prose
                           against every grid and cannot dispose anything

    Any report absent, unstamped, cut from another spine, cut in file mode or
    cut before -NotBefore is exit 2 NAMING THE FILE. The mirror report is no
    longer optional: "no table mirror ran" and "the table mirror found
    nothing" were the same silence, and the second is the only one that
    disposes a grid.

    -NotBefore is the runner's start time. It is required, because without it
    the staleness rule has no input, and a blocking rule with an absent input
    cannot pass. Stand-alone, pass the time you started the producers.

    A GRID NO CHANNEL EXAMINED IS NOT PROVEN. The three reports each record
    every grid they examined - the shape mirror records an own grid even when
    nothing was answered, the coverage gate records every grid it scored, the
    table mirror lists every grid in its check-set. A grid named by the
    register and absent from all three was examined by nobody, and reading
    that absence as "answered 0" is how a grid gets disposed on no evidence.
    Its verdict is NOT PROVEN, it names the channels that are silent about
    it, and a Stage 3d clearance cannot clear it: a written reason can
    adjudicate a leak, not the fact that nobody looked.

    UNMATCHED ENTRIES ARE LISTED, NEVER DROPPED. An entry in any of the three
    reports that does not resolve to a register grid is recorded in
    unmatched[] with its channel and printed, because evidence the
    disposition could not attribute is evidence it did not use.

    THE CLEARANCE KEY. mirrorAllow entries are keyed on a figure slot or on
    "file|grid id" (Check-FigureMirror's convention). This script accepts
    that key, the bare grid id, "subSection|grid id" and the task ref, so one
    written decision clears the grid in every gate that reads the registry.

    NEVER PRINTS A MODEL BULLET - it never reads one; the reports carry none.

    ARMS (P0-09). report-freshness, grid-disposition and channel-coverage
    BLOCK; clearances and unmatched-entries report. Every arm is registered
    before anything runs and completed before the verdict, the roster is
    printed as one ARMS: line on every path including a refusal, and it is
    written into the disposition file.

    SELF-TEST:  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Test-GridDisposition.ps1 -SelfTest
    Builds a synthetic build in the temp directory, drives the real
    Check-ShapeMirror to prove the stamp this gate reads is the stamp that
    gate writes, plants each defect this file claims to catch, and exits 0
    only when the gate refused or failed on every plant and passed the
    negative control.

    PS 5.1. ASCII only in this file. Nothing here names a unit, a brand or a
    build path.
#>

# GATE: stages=3c; requires=BuildDir,ShapeReport,CoverageReport,MirrorReport,NotBefore

[CmdletBinding()]
param(
    [string] $BuildDir,
    [string] $Register,
    [string] $ShapeReport,
    [string] $CoverageReport,
    [string] $MirrorReport,
    [string] $RulesPath,
    [string] $OutPath,
    #  The runner's start time, ISO 8601 UTC. A report generated before it is
    #  a previous round's and is refused by name.
    [string] $NotBefore,
    [switch] $SelfTest,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

$GATE = 'Test-GridDisposition'

#  The three channels, named once. Every message that names a channel names
#  one of these, and the NOT PROVEN verdict lists the ones that are silent.
$script:GdChannels = @('shape-mirror', 'row-coverage', 'table-mirror')

function Fail-Usage {
    param([string] $Message)
    Write-Host ("  X {0}: {1}" -f $GATE, $Message) -ForegroundColor Red
    #  The roster prints on the refusal path too: a runner that sees exit 2
    #  should be able to read which arm never got its input.
    try { [void](Write-GateArmRoster) } catch { }
    exit 2
}

function Read-GdStampedReport {
    <#  Read one producer report and prove it belongs to THIS run. Returns the
        parsed document, or calls Fail-Usage naming the file and the reason.
        -Channel is one of $script:GdChannels and is printed, so the refusal
        says which channel is missing as well as which file.  #>
    param(
        [string] $Path,
        [string] $Channel,
        [string] $Producer,
        [string] $Current,
        $Floor
    )
    if (-not $Path) { Fail-Usage ("no path for the {0} report - the runner must thread it." -f $Channel) }
    if (-not (Test-Path -LiteralPath $Path)) {
        Fail-Usage ("no {0} report at {1}. Run {2} over the spine first; a disposition missing a channel would dispose grids on the channels that did run, which is how a grid gets disposed on no evidence." -f $Channel, $Path, $Producer)
    }
    $doc = $null
    try { $doc = Get-GateJson -Path $Path } catch { $doc = $null }
    if ($null -eq $doc) {
        Fail-Usage ("the {0} report at {1} is empty or unparseable. A report this gate cannot read is a channel that did not run." -f $Channel, $Path)
    }

    $stamp = [string](Get-GateProp -Object $doc -Names @('spineFingerprint') -Default '')
    if (-not $stamp.Trim()) {
        Fail-Usage ("the {0} report at {1} carries no spineFingerprint stamp, so nothing can say which spine it was cut from. Re-run {2}; an unstamped report is not evidence." -f $Channel, $Path, $Producer)
    }
    $verdict = ''
    try { $verdict = Test-GateFingerprintVersion -Stamp $stamp -Current $Current }
    catch { Fail-Usage ("the {0} report at {1} could not be compared with the spine: {2}" -f $Channel, $Path, $_.Exception.Message) }
    if ($verdict -ne 'match') {
        Fail-Usage ("the {0} report at {1} was cut from a different spine ({2}): stamped {3}, the spine is {4} now. Re-run {5}, then this gate." -f $Channel, $Path, $verdict, $stamp, $Current, $Producer)
    }

    $mode = [string](Get-GateProp -Object $doc -Names @('mode') -Default '')
    if (-not $mode.Trim()) {
        Fail-Usage ("the {0} report at {1} carries no mode stamp. A per-file run and a whole-spine run write the same file name and only the stamp tells them apart; re-run {2}." -f $Channel, $Path, $Producer)
    }
    if ($mode -ne 'whole') {
        Fail-Usage ("the {0} report at {1} is from a '{2}' run. A per-file run scores one file against the whole grid set and cannot dispose a grid; re-run {3} over the whole spine." -f $Channel, $Path, $mode, $Producer)
    }

    $gen = [string](Get-GateProp -Object $doc -Names @('generated') -Default '')
    if (-not $gen.Trim()) {
        Fail-Usage ("the {0} report at {1} carries no generated time, so nothing can say it belongs to this run. Re-run {2}." -f $Channel, $Path, $Producer)
    }
    $genAt = $null
    try { $genAt = [System.DateTimeOffset]::Parse($gen, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind) }
    catch { Fail-Usage ("the {0} report at {1} stamps generated '{2}', which is not an ISO 8601 time. Re-run {3}." -f $Channel, $Path, $gen, $Producer) }
    if ($genAt.UtcDateTime -lt $Floor.UtcDateTime) {
        Fail-Usage ("the {0} report at {1} was generated {2}, before this run started ({3}). It is a previous round's report; re-run {4}, then this gate. Disposing grids on a stale report is how every verdict on the last build was last round's." -f $Channel, $Path, $genAt.UtcDateTime.ToString('o'), $Floor.UtcDateTime.ToString('o'), $Producer)
    }

    return [pscustomobject]@{ Doc = $doc; Path = $Path; Channel = $Channel; Stamp = $stamp; Mode = $mode; Generated = $genAt }
}

# ---------------------------------------------------------------------------
# SELF-TEST. Synthetic build in the temp directory; every string invented.
# The gate is invoked as a child of this process on each plant, the plant is
# read back from the fixture before the verdict is trusted, and the run ends
# SELF-TEST PASS (exit 0) or SELF-TEST FAIL (exit 4).
# ---------------------------------------------------------------------------
if ($SelfTest) {
    Write-Host ''
    Write-Host ("  {0} SELF-TEST - a clean result is not believed until the gate has failed on a planted defect" -f $GATE) -ForegroundColor Cyan
    $script:GdSelfTestFailed = 0
    $self = $MyInvocation.MyCommand.Path
    $fx = Join-Path ([System.IO.Path]::GetTempPath()) ('gd-selftest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path (Join-Path $fx 'spine') | Out-Null

    function Test-GdSelf { param([bool] $Ok, [string] $What) if ($Ok) { Write-Host ("    ok   {0}" -f $What) -ForegroundColor Green } else { Write-Host ("    X    {0}" -f $What) -ForegroundColor Red; $script:GdSelfTestFailed++ } }
    function Write-GdFixture { param([string] $Path, $Object) [System.IO.File]::WriteAllText($Path, ($Object | ConvertTo-Json -Depth 20), (New-Object System.Text.UTF8Encoding($true))) }
    function Invoke-GdSelf {
        param([hashtable] $Arguments)
        $text = ''; $rc = -1
        try { $lines = @(& $self @Arguments *>&1 | ForEach-Object { "$_" }); $rc = $LASTEXITCODE; $text = ($lines -join "`n") }
        catch { $text = "EXCEPTION: " + $_.Exception.Message; $rc = -1 }
        return [pscustomobject]@{ Rc = $rc; Text = $text }
    }

    $shapePath = Join-Path $fx 'shape-mirror-report.json'
    $covPath   = Join-Path $fx 'row-coverage-report.json'
    $mirPath   = Join-Path $fx 'figure-mirror-report.json'
    $outPath   = Join-Path $fx 'grid-disposition.json'
    $GRID      = 'TEST_Tool Task 1(a)'
    $GRID2     = 'TEST_Tool Task 2(a)'

    #  Written fresh for each plant so a stamp is never accidentally reused.
    function New-GdReports {
        param([int] $FullRows = 0, [int] $Taught = 3, [string] $Mode = 'whole', [string] $Fingerprint, [string] $Generated,
              [switch] $NoStamp, [switch] $OmitGrid, [switch] $Unmatched)
        Write-GdFixture -Path $shapePath -Object @{
            gate = 'Check-ShapeMirror'; generated = $Generated; spineFingerprint = $(if ($NoStamp) { '' } else { $Fingerprint }); mode = $Mode
            spineFiles = @('t1_1.1.json')
            files = @(@{ File = 't1_1.1.json'; SubSection = '1.1'; Grids = @(
                $(if ($OmitGrid) { $null } else { @{ SubSection = '1.1'; Ref = 'Task 1(a)'; Id = $GRID; Kind = 'labelled'; Own = $true; Examined = $true; FullRows = $FullRows; PartialRows = 0; Block = ($FullRows -gt 1) } }),
                $(if ($Unmatched) { @{ SubSection = '1.1'; Ref = 'Task 9(z)'; Id = 'TEST_Tool Task 9(z)'; Kind = 'labelled'; Own = $true; Examined = $true; FullRows = 0; PartialRows = 0 } } else { $null })
            ) })
            arms = @(); summary = @{ files = 1 }
        }
        Write-GdFixture -Path $covPath -Object @{
            gate = 'Check-RowCoverage'; generated = $Generated; spineFingerprint = $Fingerprint; mode = $Mode
            spineFiles = @('t1_1.1.json'); floors = @{ minTeachWhole = 3 }
            grids = @($(if ($OmitGrid) { $null } else { @{ SubSection = '1.1'; Ref = 'Task 1(a)'; Id = $GRID; Kind = 'labelled'; ItemCount = 3; TaughtRows = $Taught } }))
            arms = @()
        }
        Write-GdFixture -Path $mirPath -Object @{
            gate = 'Check-FigureMirror'; generated = $Generated; spineFingerprint = $Fingerprint; mode = $Mode
            spineFiles = @('t1_1.1.json'); grids = @($(if ($OmitGrid) { 'TEST_Tool Task 0(a)' } else { $GRID }))
            pairs = @(); arms = @()
        }
    }

    try {
        Write-GdFixture -Path (Join-Path $fx 'spine\t1_1.1.json') -Object @{
            ref = '1.1'; title = 'Widgets'
            underpinningKnowledge = @('A spindle is held under tension so the belt cannot slip.')
        }
        #  The register is shaped so the REAL Check-ShapeMirror can read it too
        #  (plant 12); the disposition itself needs only ref, id, items and
        #  allowance.
        Write-GdFixture -Path (Join-Path $fx 'withhold-register.json') -Object @{
            subSections = @{ '1.1' = @{ subSection = '1.1'; refs = @('Task 1(a)'); tasks = @(
                @{ ref = 'Task 1(a)'; id = $GRID; document = 'TEST_Tool'; kind = 'labelled'
                   headers = @('Widget', 'Purpose', 'Care'); assessedHeaders = @(1, 2)
                   items = @('Widget A', 'Widget B', 'Widget C'); aliases = @{ 'Widget A' = @(); 'Widget B' = @(); 'Widget C' = @() }
                   subjectClass = 'widget'; subjects = @(); unassessedSubjects = @('Widget D'); allowance = 1
                   shape = @{ rows = 3; assessedColumns = 2; bulletsPerCell = @{ min = 1; max = 2 }; wordGuide = @{ min = 10; max = 20 }; benchmarkMinimum = 1 } } ); freeText = @() } }
        }
        $fpNow = Get-SpineFingerprint -BuildDir $fx -Quiet
        $now = [System.DateTimeOffset]::UtcNow
        $runStart = $now.AddMinutes(-1).UtcDateTime.ToString('o')
        $fresh = $now.UtcDateTime.ToString('o')

        # ---- plant 1: PRIOR-RUN reports (older generated, a different fingerprint) beside a planted shape leak
        $stale = $now.AddHours(-3).UtcDateTime.ToString('o')
        New-GdReports -FullRows 2 -Taught 3 -Fingerprint 'v2:0000000000000000000000000000dead' -Generated $stale
        $sd = Get-GateJson -Path $shapePath
        Test-GdSelf -Ok ([string]$sd.spineFingerprint -eq 'v2:0000000000000000000000000000dead' -and [string]$sd.spineFingerprint -ne $fpNow -and @($sd.files[0].Grids | Where-Object { $_.Id -eq $GRID -and $_.FullRows -eq 2 }).Count -eq 1) -What 'plant 1 landed: the shape report on disk is stamped to another spine and records the planted leak (2 full rows over an allowance of 1)'
        $r1 = Invoke-GdSelf -Arguments @{ BuildDir = $fx; NotBefore = $runStart; Quiet = $true }
        Test-GdSelf -Ok ($r1.Rc -eq 2 -and $r1.Text -match 'shape-mirror-report\.json' -and $r1.Text -match '(?i)different spine') -What ("prior-run reports are refused naming the stale report, not read (rc={0})" -f $r1.Rc)
        Test-GdSelf -Ok ($r1.Text -match '(?m)^ARMS: ') -What 'the roster prints on the refusal path'
        Test-GdSelf -Ok (-not (Test-Path -LiteralPath $outPath)) -What 'a refused run writes no disposition file'

        # ---- plant 2: the same leak in reports that ARE this run's -> exit 1 naming the grid
        New-GdReports -FullRows 2 -Taught 3 -Fingerprint $fpNow -Generated $fresh
        $r2 = Invoke-GdSelf -Arguments @{ BuildDir = $fx; NotBefore = $runStart; Quiet = $true }
        Test-GdSelf -Ok ($r2.Rc -eq 1 -and $r2.Text -match ([regex]::Escape($GRID)) -and $r2.Text -match 'NOT DISPOSED') -What ("this run's reports carrying the shape leak fail naming the grid (rc={0})" -f $r2.Rc)
        $disp = Get-GateJson -Path $outPath
        Test-GdSelf -Ok (@($disp.grids | Where-Object { $_.id -eq $GRID -and $_.verdict -eq 'NOT DISPOSED' -and $_.answered -eq 2 }).Count -eq 1) -What 'the disposition file records the grid NOT DISPOSED with answered 2'

        # ---- plant 3: negative control - answered within allowance, every row taught
        New-GdReports -FullRows 1 -Taught 3 -Fingerprint $fpNow -Generated $fresh
        $r3 = Invoke-GdSelf -Arguments @{ BuildDir = $fx; NotBefore = $runStart; Quiet = $true }
        Test-GdSelf -Ok ($r3.Rc -eq 0 -and $r3.Text -match '(?m)^ARMS: .*report-freshness\|true\|ran\|3\|0' -and $r3.Text -match 'grid-disposition\|true\|ran\|1\|0' -and $r3.Text -match 'channel-coverage\|true\|ran\|1\|0') -What ("negative control: every grid disposed, exit 0, every blocking arm ran (rc={0})" -f $r3.Rc)

        # ---- plant 4: a missing shape report -> exit 2 naming the file
        Remove-Item -LiteralPath $shapePath -Force
        Test-GdSelf -Ok (-not (Test-Path -LiteralPath $shapePath)) -What 'plant 4 landed: shape-mirror-report.json is gone'
        $r4 = Invoke-GdSelf -Arguments @{ BuildDir = $fx; NotBefore = $runStart; Quiet = $true }
        Test-GdSelf -Ok ($r4.Rc -eq 2 -and $r4.Text -match 'shape-mirror-report\.json' -and $r4.Text -match 'Check-ShapeMirror') -What ("a missing shape report exits 2 naming the file and its producer (rc={0})" -f $r4.Rc)

        # ---- plant 5: a missing MIRROR report is a refusal too (it is no longer optional)
        New-GdReports -FullRows 1 -Taught 3 -Fingerprint $fpNow -Generated $fresh
        Remove-Item -LiteralPath $mirPath -Force
        $r5 = Invoke-GdSelf -Arguments @{ BuildDir = $fx; NotBefore = $runStart; Quiet = $true }
        Test-GdSelf -Ok ($r5.Rc -eq 2 -and $r5.Text -match 'figure-mirror-report\.json' -and $r5.Text -match 'table-mirror') -What ("a missing table-mirror report exits 2 naming the file - the mirror report is no longer optional (rc={0})" -f $r5.Rc)

        # ---- plant 6: mode file is refused naming the file and the mode
        New-GdReports -FullRows 1 -Taught 3 -Mode 'file' -Fingerprint $fpNow -Generated $fresh
        Test-GdSelf -Ok ([string](Get-GateJson -Path $shapePath).mode -eq 'file') -What 'plant 6 landed: the shape report is stamped mode file'
        $r6 = Invoke-GdSelf -Arguments @{ BuildDir = $fx; NotBefore = $runStart; Quiet = $true }
        Test-GdSelf -Ok ($r6.Rc -eq 2 -and $r6.Text -match 'shape-mirror-report\.json' -and $r6.Text -match "'file' run") -What ("a report written under mode file is refused naming the file and the mode (rc={0})" -f $r6.Rc)

        # ---- plant 7: an unstamped report is refused by name
        New-GdReports -FullRows 1 -Taught 3 -Fingerprint $fpNow -Generated $fresh -NoStamp
        $r7 = Invoke-GdSelf -Arguments @{ BuildDir = $fx; NotBefore = $runStart; Quiet = $true }
        Test-GdSelf -Ok ($r7.Rc -eq 2 -and $r7.Text -match 'shape-mirror-report\.json' -and $r7.Text -match 'no spineFingerprint stamp') -What ("an unstamped report is refused naming the file and the missing stamp (rc={0})" -f $r7.Rc)

        # ---- plant 8: a report older than -NotBefore is refused, stamp and mode notwithstanding
        New-GdReports -FullRows 1 -Taught 3 -Fingerprint $fpNow -Generated $now.AddHours(-2).UtcDateTime.ToString('o')
        $r8 = Invoke-GdSelf -Arguments @{ BuildDir = $fx; NotBefore = $runStart; Quiet = $true }
        Test-GdSelf -Ok ($r8.Rc -eq 2 -and $r8.Text -match 'shape-mirror-report\.json' -and $r8.Text -match 'before this run started') -What ("a correctly stamped report generated before -NotBefore is refused by name (rc={0})" -f $r8.Rc)

        # ---- plant 9: no -NotBefore at all is a refusal naming the parameter
        New-GdReports -FullRows 1 -Taught 3 -Fingerprint $fpNow -Generated $fresh
        $r9 = Invoke-GdSelf -Arguments @{ BuildDir = $fx; Quiet = $true }
        Test-GdSelf -Ok ($r9.Rc -eq 2 -and $r9.Text -match '\-NotBefore') -What ("no -NotBefore is a refusal naming the parameter, never a run without the staleness rule (rc={0})" -f $r9.Rc)
        $r9b = Invoke-GdSelf -Arguments @{ BuildDir = $fx; NotBefore = 'last Tuesday'; Quiet = $true }
        Test-GdSelf -Ok ($r9b.Rc -eq 2 -and $r9b.Text -match '\-NotBefore' -and $r9b.Text -match 'last Tuesday') -What ("an unparseable -NotBefore is a refusal naming the value (rc={0})" -f $r9b.Rc)

        # ---- plant 10: a grid no channel examined is NOT PROVEN naming the channels
        New-GdReports -FullRows 0 -Taught 3 -Fingerprint $fpNow -Generated $fresh -OmitGrid
        $sd2 = Get-GateJson -Path $shapePath
        Test-GdSelf -Ok (@($sd2.files[0].Grids | Where-Object { $null -ne $_ -and $_.Id -eq $GRID }).Count -eq 0) -What 'plant 10 landed: no channel report names the register grid'
        $r10 = Invoke-GdSelf -Arguments @{ BuildDir = $fx; NotBefore = $runStart; Quiet = $true }
        Test-GdSelf -Ok ($r10.Rc -eq 1 -and $r10.Text -match 'NOT PROVEN' -and $r10.Text -match ([regex]::Escape($GRID)) -and $r10.Text -match 'shape-mirror' -and $r10.Text -match 'row-coverage' -and $r10.Text -match 'table-mirror') -What ("a grid absent from every channel is NOT PROVEN naming all three channels (rc={0})" -f $r10.Rc)
        Test-GdSelf -Ok ($r10.Text -match 'channel-coverage\|true\|ran\|1\|1') -What 'the channel-coverage arm records the finding'
        #  a written clearance cannot clear "nobody looked"
        Write-GdFixture -Path (Join-Path $fx 'figures.json') -Object @{ mirrorAllow = @(@{ id = $GRID; reason = 'A written Stage 3d decision that must not clear an unexamined grid.' }) }
        $r10b = Invoke-GdSelf -Arguments @{ BuildDir = $fx; NotBefore = $runStart; Quiet = $true }
        Test-GdSelf -Ok ($r10b.Rc -eq 1 -and $r10b.Text -match 'NOT PROVEN') -What ("a mirrorAllow entry does not clear a NOT PROVEN grid (rc={0})" -f $r10b.Rc)
        Remove-Item -LiteralPath (Join-Path $fx 'figures.json') -Force

        # ---- plant 11: an unmatched entry is listed, never dropped
        New-GdReports -FullRows 1 -Taught 3 -Fingerprint $fpNow -Generated $fresh -Unmatched
        $r11 = Invoke-GdSelf -Arguments @{ BuildDir = $fx; NotBefore = $runStart }
        $disp11 = Get-GateJson -Path $outPath
        Test-GdSelf -Ok ($r11.Rc -eq 0 -and @($disp11.unmatched | Where-Object { $_.channel -eq 'shape-mirror' -and $_.id -eq 'TEST_Tool Task 9(z)' }).Count -eq 1 -and $r11.Text -match 'Task 9\(z\)') -What ("a report entry that resolves to no register grid is listed as unmatched and printed (rc={0})" -f $r11.Rc)

        # ---- plant 12: the stamp this gate READS is the stamp Check-ShapeMirror WRITES
        $realShape = Join-Path $PSScriptRoot 'Check-ShapeMirror.ps1'
        if (Test-Path -LiteralPath $realShape) {
            Write-GdFixture -Path (Join-Path $fx 'assessor-cells.json') -Object @{
                _WARNING = 'GATE-ONLY synthetic cells for the self-test'
                wordPipeline = @{ stopwords = 176; stem = 'crude suffix strip'; stripLearnerWords = 'headers and items'; dfCeiling = 0.25 }
                grids = @(@{ ref = 'Task 1(a)'; id = $GRID; subSection = '1.1'; kind = 'labelled'; document = 'TEST_Tool'
                             headers = @('Widget', 'Purpose', 'Care'); assessedHeaders = @(1, 2)
                             rows = @(
                                @{ item = 'Widget A'; assessed = $true; cells = @(
                                    @{ col = 1; header = 'Purpose'; state = 'answered'; bullets = @(@{ text = 'turns the main spindle'; words = @('turn', 'main', 'spindle') }) },
                                    @{ col = 2; header = 'Care'; state = 'answered'; bullets = @(@{ text = 'oil the bearing weekly'; words = @('oil', 'bear', 'weekly') }) }) },
                                @{ item = 'Widget B'; assessed = $true; cells = @(
                                    @{ col = 1; header = 'Purpose'; state = 'answered'; bullets = @(@{ text = 'feeds the hopper evenly'; words = @('feed', 'hopper', 'evenly') }) },
                                    @{ col = 2; header = 'Care'; state = 'answered'; bullets = @(@{ text = 'clear the chute after every run'; words = @('clear', 'chute', 'run') }) }) },
                                @{ item = 'Widget C'; assessed = $true; cells = @(
                                    @{ col = 1; header = 'Purpose'; state = 'answered'; bullets = @(@{ text = 'holds the jig square'; words = @('hold', 'jig', 'square') }) },
                                    @{ col = 2; header = 'Care'; state = 'answered'; bullets = @(@{ text = 'inspect the clamp face'; words = @('inspect', 'clamp', 'face') }) }) }) })
                freeText = @(); taskLevel = @()
            }
            $genShape = Join-Path $fx 'genuine-shape.json'
            $null = & $realShape -BuildDir $fx -ReportPath $genShape -Quiet *>&1
            $gd = Get-GateJson -Path $genShape
            $ok = ($null -ne $gd -and [string]$gd.spineFingerprint -eq $fpNow -and [string]$gd.mode -eq 'whole')
            Test-GdSelf -Ok $ok -What 'plant 12 landed: the real Check-ShapeMirror wrote a report stamped with this spine, mode whole'
            if ($ok) {
                New-GdReports -FullRows 1 -Taught 3 -Fingerprint $fpNow -Generated $fresh
                $r12 = Invoke-GdSelf -Arguments @{ BuildDir = $fx; ShapeReport = $genShape; NotBefore = $runStart; Quiet = $true }
                Test-GdSelf -Ok ($r12.Rc -eq 0) -What ("a report written by the real Check-ShapeMirror passes this gate's freshness rule - the field names agree (rc={0})" -f $r12.Rc)
            }
        }
        else { Test-GdSelf -Ok $false -What ('Check-ShapeMirror.ps1 is not beside this gate at {0} - the cross-producer stamp proof could not run' -f $realShape) }
    }
    finally {
        try { Remove-Item -LiteralPath $fx -Recurse -Force -ErrorAction SilentlyContinue } catch { }
    }

    Write-Host ''
    if ($script:GdSelfTestFailed -gt 0) {
        Write-Host ("  SELF-TEST FAIL: {0} check(s) failed - no result from this gate may be believed until they pass" -f $script:GdSelfTestFailed) -ForegroundColor Red
        exit 4
    }
    Write-Host '  SELF-TEST PASS: the gate refused every stale, unstamped, file-mode and absent report by name, gave an unexamined grid NOT PROVEN, and passed the negative control' -ForegroundColor Green
    exit 0
}

#  Stamped before the run so the catch can tell THIS run's report on disk from
#  one an earlier run left in the same place.
$script:GdRunStart = (Get-Date).ToUniversalTime().AddSeconds(-2)
$script:GdVerdictFromReport = $null

try {

# ---------------------------------------------------------------------------
# 0. Arms, declared before anything runs
# ---------------------------------------------------------------------------

Register-GateArm -Name 'report-freshness' -Blocking
Register-GateArm -Name 'grid-disposition' -Blocking
Register-GateArm -Name 'channel-coverage' -Blocking
Register-GateArm -Name 'clearances'
Register-GateArm -Name 'unmatched-entries'

if (-not $BuildDir) { Fail-Usage '-BuildDir is required.' }
if (-not (Test-Path -LiteralPath $BuildDir)) { Fail-Usage ("build directory not found: {0}" -f $BuildDir) }
if (-not $Register)       { $Register       = Join-Path $BuildDir 'withhold-register.json' }
if (-not $ShapeReport)    { $ShapeReport    = Join-Path $BuildDir 'shape-mirror-report.json' }
if (-not $CoverageReport) { $CoverageReport = Join-Path $BuildDir 'row-coverage-report.json' }
if (-not $MirrorReport)   { $MirrorReport   = Join-Path $BuildDir 'figure-mirror-report.json' }
if (-not $OutPath)        { $OutPath        = Join-Path $BuildDir 'grid-disposition.json' }

# ---------------------------------------------------------------------------
# 1. THIS RUN'S REPORTS. Nothing below is read until all three have proved
#    they were cut from this spine, in whole mode, since the runner started.
# ---------------------------------------------------------------------------

if (-not "$NotBefore".Trim()) {
    Fail-Usage '-NotBefore is required: it is the time this run started, and without it nothing can tell a report this run produced from a report the last round left on disk. The runner threads its own start time; stand-alone, pass the UTC time you started the producers (for example 2026-01-01T00:00:00Z).'
}
$floor = $null
try { $floor = [System.DateTimeOffset]::Parse($NotBefore, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind) }
catch { Fail-Usage ("-NotBefore '{0}' is not an ISO 8601 time. Pass the run's start time in UTC, for example 2026-01-01T00:00:00Z." -f $NotBefore) }

$current = ''
try { $current = Get-SpineFingerprint -BuildDir $BuildDir -Quiet } catch { $current = '' }
if (-not "$current".Trim()) {
    Fail-Usage ("no spine to fingerprint under {0}. Every report below claims to describe a spine; with no spine there is nothing to check them against." -f $BuildDir)
}

$shapeIn = Read-GdStampedReport -Path $ShapeReport    -Channel 'shape-mirror'  -Producer 'Check-ShapeMirror.ps1'  -Current $current -Floor $floor
$covIn   = Read-GdStampedReport -Path $CoverageReport -Channel 'row-coverage'  -Producer 'Check-RowCoverage.ps1 -Whole' -Current $current -Floor $floor
$mirIn   = Read-GdStampedReport -Path $MirrorReport   -Channel 'table-mirror'  -Producer 'Check-FigureMirror.ps1' -Current $current -Floor $floor
Complete-GateArm -Name 'report-freshness' -State ran -Size 3 -Findings 0

$shape = $shapeIn.Doc
$cov   = $covIn.Doc
$mirror = $mirIn.Doc

if (-not $Quiet) {
    Write-Host ''
    Write-Host 'GRID DISPOSITION - one verdict per (sub-section, grid)' -ForegroundColor Cyan
    Write-Host ("  spine fingerprint now: {0}; every report below is stamped to it, mode whole, generated at or after {1}" -f $current, $floor.UtcDateTime.ToString('o')) -ForegroundColor DarkGray
    foreach ($rin in @($shapeIn, $covIn, $mirIn)) {
        Write-Host ("    {0,-13} {1}  generated {2}" -f $rin.Channel, (Split-Path $rin.Path -Leaf), $rin.Generated.UtcDateTime.ToString('o')) -ForegroundColor DarkGray
    }
}

# ---------------------------------------------------------------------------
# 2. The grids, from the register
# ---------------------------------------------------------------------------

$reg = Get-GateJson -Path $Register
if ($null -eq $reg) { Fail-Usage ("no withhold register at {0} - there is no list of grids to dispose." -f $Register) }
$subs = Get-GateProp -Object $reg -Names @('subSections') -Default $null
if ($null -eq $subs) { Fail-Usage 'the register carries no subSections block.' }
$gridList = New-Object System.Collections.Generic.List[object]
foreach ($p in $subs.PSObject.Properties) {
    if ($p.Name -like '_*') { continue }
    foreach ($t in @(Get-GateProp -Object $p.Value -Names @('tasks', 'grids') -Default @())) {
        if ($null -eq $t) { continue }
        $gridList.Add([pscustomobject]@{
            SubSection = $p.Name
            Ref  = [string](Get-GateProp -Object $t -Names @('ref') -Default '')
            Id   = [string](Get-GateProp -Object $t -Names @('id') -Default '')
            Kind = [string](Get-GateProp -Object $t -Names @('kind') -Default '')
            Allowance = [int](Get-GateProp -Object $t -Names @('allowance') -Default 0)
            ItemCount = @(Get-GateProp -Object $t -Names @('items') -Default @()).Count
        })
    }
}
#  BLOCKING: a register with no grid is an empty check-set, and an empty
#  check-set is a refusal (exit 2 through the catch below), never a pass.
Write-GateCheckSet -What 'assessed grids' -Count $gridList.Count -DerivedFrom (Split-Path $Register -Leaf) -Blocking -Input 'withhold-register.json subSections[].tasks'

#  One resolver for every channel: an entry names a grid by id, by
#  "subSection|id" or by task ref. Anything it cannot resolve is unmatched.
$unmatched = New-Object System.Collections.Generic.List[object]
$entriesRead = 0
function Resolve-GdGrid {
    param([string] $Id, [string] $SubSection)
    if (-not $Id) { return @() }
    $byKey = @($gridList | Where-Object { ("{0}|{1}" -f $_.SubSection, $_.Id) -eq $Id })
    if ($byKey.Count -gt 0) { return $byKey }
    $byId = @($gridList | Where-Object { $_.Id -eq $Id })
    if ($byId.Count -gt 0) {
        if ($SubSection) {
            $narrow = @($byId | Where-Object { $_.SubSection -eq $SubSection })
            if ($narrow.Count -gt 0) { return $narrow }
        }
        return $byId
    }
    return @($gridList | Where-Object { $_.Ref -and $_.Ref -eq $Id })
}

# ---------------------------------------------------------------------------
# 3. answered: the shape mirror's FULL rows in the grid's own sub-section
#    file(s), and the table mirror's filled rows. Every channel also records
#    WHICH grids it examined, because absence is not zero.
# ---------------------------------------------------------------------------

$shapeAnswered = @{}   # "sub|id" -> max full rows across own files
$shapePartial  = @{}
$shapeFiles    = @{}
$shapeSeen     = @{}
foreach ($fr in @(Get-GateProp -Object $shape -Names @('files') -Default @())) {
    if ($null -eq $fr) { continue }
    $fSub = [string](Get-GateProp -Object $fr -Names @('SubSection', 'subSection') -Default '')
    $fName = [string](Get-GateProp -Object $fr -Names @('File', 'file') -Default '')
    foreach ($g in @(Get-GateProp -Object $fr -Names @('Grids', 'grids') -Default @())) {
        if ($null -eq $g) { continue }
        $own = Get-GateProp -Object $g -Names @('Own', 'own') -Default $false
        if (-not $own) { continue }
        $entriesRead++
        $gSub = [string](Get-GateProp -Object $g -Names @('SubSection', 'subSection') -Default $fSub)
        $gId  = [string](Get-GateProp -Object $g -Names @('Id', 'id') -Default '')
        $match = @(Resolve-GdGrid -Id $gId -SubSection $gSub)
        if ($match.Count -eq 0) { $unmatched.Add([pscustomobject]@{ channel = 'shape-mirror'; id = $gId; where = $fName }); continue }
        $full = [int](Get-GateProp -Object $g -Names @('FullRows', 'fullRows') -Default 0)
        $part = [int](Get-GateProp -Object $g -Names @('PartialRows', 'partialRows') -Default 0)
        foreach ($m in $match) {
            $key = "{0}|{1}" -f $m.SubSection, $m.Id
            $shapeSeen[$key] = $true
            if (-not $shapeAnswered.ContainsKey($key) -or $shapeAnswered[$key] -lt $full) { $shapeAnswered[$key] = $full }
            if (-not $shapePartial.ContainsKey($key) -or $shapePartial[$key] -lt $part) { $shapePartial[$key] = $part }
            $shapeFiles[$key] = $fName
        }
    }
}

$mirrorAnswered = @{}
$mirrorSeen = @{}
$mirrorEntries = 0
#  The mirror's check-set: every grid it considered, over-limit or not. A
#  grid in this list was examined by the table channel even where no pair was
#  written for it.
foreach ($gid in @(Get-GateProp -Object $mirror -Names @('grids') -Default @())) {
    if ($null -eq $gid) { continue }
    $entriesRead++
    $match = @(Resolve-GdGrid -Id ([string]$gid) -SubSection '')
    if ($match.Count -eq 0) { $unmatched.Add([pscustomobject]@{ channel = 'table-mirror'; id = [string]$gid; where = 'check-set' }); continue }
    foreach ($m in $match) { $mirrorSeen[("{0}|{1}" -f $m.SubSection, $m.Id)] = $true }
}
$mirrorPairs = @(Get-GateProp -Object $mirror -Names @('pairs', 'hits', 'grids2', 'entries', 'results', 'findings') -Default @())
foreach ($e in $mirrorPairs) {
    if ($null -eq $e) { continue }
    $mirrorEntries++; $entriesRead++
    $file = [string](Get-GateProp -Object $e -Names @('file', 'File') -Default '')
    $gid  = [string](Get-GateProp -Object $e -Names @('grid', 'Grid', 'id', 'Id', 'gridId') -Default '')
    $filled = [int](Get-GateProp -Object $e -Names @('filled', 'Filled', 'answered', 'Answered', 'rows', 'Rows') -Default 0)
    $match = @(Resolve-GdGrid -Id $gid -SubSection '')
    if ($match.Count -eq 0) { $unmatched.Add([pscustomobject]@{ channel = 'table-mirror'; id = $gid; where = $file }); continue }
    foreach ($m in $match) {
        $key = "{0}|{1}" -f $m.SubSection, $m.Id
        $mirrorSeen[$key] = $true
        if (-not $mirrorAnswered.ContainsKey($key) -or $mirrorAnswered[$key] -lt $filled) { $mirrorAnswered[$key] = $filled }
    }
}

# ---------------------------------------------------------------------------
# 4. taught: rows at or above the whole-spine floor, from the coverage report
# ---------------------------------------------------------------------------

$taught = @{}
$covSeen = @{}
$floorRows = 0
$floors = Get-GateProp -Object $cov -Names @('floors') -Default $null
if ($null -ne $floors) { $floorRows = [int](Get-GateProp -Object $floors -Names @('minTeachWhole') -Default 0) }
foreach ($g in @(Get-GateProp -Object $cov -Names @('grids') -Default @())) {
    if ($null -eq $g) { continue }
    $entriesRead++
    $gSub = [string](Get-GateProp -Object $g -Names @('SubSection', 'subSection') -Default '')
    $gId  = [string](Get-GateProp -Object $g -Names @('Id', 'id') -Default '')
    $match = @(Resolve-GdGrid -Id $gId -SubSection $gSub)
    if ($match.Count -eq 0) { $unmatched.Add([pscustomobject]@{ channel = 'row-coverage'; id = $gId; where = 'grids' }); continue }
    foreach ($m in $match) {
        $key = "{0}|{1}" -f $m.SubSection, $m.Id
        $covSeen[$key] = $true
        $taught[$key] = [int](Get-GateProp -Object $g -Names @('TaughtRows', 'taughtRows') -Default 0)
    }
}

if ($unmatched.Count -gt 0) { Complete-GateArm -Name 'unmatched-entries' -State ran -Size $entriesRead -Findings $unmatched.Count }
elseif ($entriesRead -gt 0) { Complete-GateArm -Name 'unmatched-entries' -State ran -Size $entriesRead -Findings 0 }
else { Complete-GateArm -Name 'unmatched-entries' -State empty }

# ---------------------------------------------------------------------------
# 5. the allow-list, with reasons
# ---------------------------------------------------------------------------

$registry = Get-GateRegistry -BuildDir $BuildDir -RulesPath $RulesPath
$allow = Get-GateAllowList -Registry $registry -Key 'mirrorAllow' -IdField @('slot', 'id', 'key', 'figure', 'grid') -GateName $GATE

# ---------------------------------------------------------------------------
# 6. verdicts
# ---------------------------------------------------------------------------

$verdicts = New-Object System.Collections.Generic.List[object]
$notDisposed = 0; $cleared = 0; $disposed = 0; $notProven = 0
foreach ($g in $gridList) {
    $key = "{0}|{1}" -f $g.SubSection, $g.Id
    $absentList = New-Object System.Collections.Generic.List[string]
    if (-not $shapeSeen.ContainsKey($key))  { $absentList.Add('shape-mirror') }
    if (-not $covSeen.ContainsKey($key))    { $absentList.Add('row-coverage') }
    if (-not $mirrorSeen.ContainsKey($key)) { $absentList.Add('table-mirror') }
    $absent = @($absentList.ToArray())

    $sa = 0; if ($shapeAnswered.ContainsKey($key)) { $sa = $shapeAnswered[$key] }
    $sp = 0; if ($shapePartial.ContainsKey($key)) { $sp = $shapePartial[$key] }
    $ma = 0; if ($mirrorAnswered.ContainsKey($key)) { $ma = $mirrorAnswered[$key] }
    $answered = [math]::Max($sa, $ma)
    $t = 0; if ($taught.ContainsKey($key)) { $t = $taught[$key] }

    #  NOT PROVEN FIRST, AND IT CANNOT BE CLEARED. A grid no channel examined
    #  has no evidence either way, and a written Stage 3d reason adjudicates a
    #  leak someone read - it cannot stand in for a channel that never looked.
    if ($absent.Count -eq $script:GdChannels.Count) {
        $notProven++
        $verdicts.Add([pscustomobject]@{
            subSection = $g.SubSection; ref = $g.Ref; id = $g.Id; kind = $g.Kind
            itemCount = $g.ItemCount; allowance = $g.Allowance
            answered = 0; answeredBy = [pscustomobject]@{ shapeFull = 0; shapePartial = 0; tableMirror = 0 }
            taught = 0; floor = $floorRows
            examinedBy = @(); absentFrom = $absent
            verdict = 'NOT PROVEN'
            reason = ("no channel examined this grid - absent from {0}. Reading that absence as 'answered 0' disposes a grid on no evidence; re-run the producers over a spine that carries this sub-section, or correct the register entry." -f ($absent -join ', '))
            allowKey = ''
        })
        continue
    }

    $ok = ($answered -le $g.Allowance -and $t -eq $g.ItemCount -and $g.ItemCount -gt 0)
    $why = New-Object System.Collections.Generic.List[string]
    if ($answered -gt $g.Allowance) { $why.Add(("answered {0} > allowance {1}" -f $answered, $g.Allowance)) }
    if ($t -ne $g.ItemCount) { $why.Add(("taught {0} of {1} rows to the whole-spine floor of {2}" -f $t, $g.ItemCount, $floorRows)) }
    if ($g.ItemCount -eq 0) { $why.Add('the register lists no items for this grid') }
    if ($absent.Count -gt 0) { $why.Add(("no record in {0}" -f ($absent -join ', '))) }

    $verdict = 'NOT DISPOSED'; $reason = ($why -join '; '); $allowKey = ''
    if ($ok) { $verdict = 'disposed'; $reason = ("answered {0} <= allowance {1}; taught {2} of {2}" -f $answered, $g.Allowance, $g.ItemCount); $disposed++ }
    else {
        $file = ''; if ($shapeFiles.ContainsKey($key)) { $file = $shapeFiles[$key] }
        $cands = @(("{0}|{1}" -f $file, $g.Id), $g.Id, $key, $g.Ref) | Where-Object { $_ -and $_ -ne ('|' + $g.Id) }
        foreach ($c in $cands) {
            if ($allow.ContainsKey($c)) { $allowKey = $c; break }
        }
        if (-not $allowKey) {
            #  A "file|grid" key written for the table mirror names the file the
            #  TABLE sat in, which need not be the sub-section that prepares the
            #  task. The decision is about the grid; any key ending in this grid's
            #  id is that decision.
            foreach ($k in $allow.Keys) {
                $bar = $k.LastIndexOf('|')
                if ($bar -ge 0 -and $k.Substring($bar + 1) -eq $g.Id) { $allowKey = $k; break }
            }
        }
        if ($allowKey) { $verdict = 'cleared'; $reason = ("{0} -- cleared at Stage 3d on '{1}': {2}" -f $reason, $allowKey, $allow[$allowKey]); $cleared++ }
        else { $notDisposed++ }
    }
    $verdicts.Add([pscustomobject]@{
        subSection = $g.SubSection; ref = $g.Ref; id = $g.Id; kind = $g.Kind
        itemCount = $g.ItemCount; allowance = $g.Allowance
        answered = $answered; answeredBy = [pscustomobject]@{ shapeFull = $sa; shapePartial = $sp; tableMirror = $ma }
        taught = $t; floor = $floorRows
        examinedBy = @($script:GdChannels | Where-Object { $absent -notcontains $_ })
        absentFrom = $absent
        verdict = $verdict; reason = $reason; allowKey = $allowKey
    })
}

Complete-GateArm -Name 'grid-disposition' -State ran -Size $gridList.Count -Findings $notDisposed
Complete-GateArm -Name 'channel-coverage' -State ran -Size $gridList.Count -Findings $notProven
if ($allow.Count -gt 0) { Complete-GateArm -Name 'clearances' -State ran -Size $allow.Count -Findings $cleared }
else { Complete-GateArm -Name 'clearances' -State empty }
$roster = Write-GateArmRoster
Assert-GateArmsComplete

$out = [pscustomobject]@{
    gate = $GATE
    generated = (Get-Date).ToUniversalTime().ToString('o')
    notBefore = $floor.UtcDateTime.ToString('o')
    spineFingerprint = $current
    buildDir = $BuildDir
    inputs = [pscustomobject]@{
        register = $Register
        shapeReport = [pscustomobject]@{ path = $ShapeReport; generated = $shapeIn.Generated.UtcDateTime.ToString('o'); mode = $shapeIn.Mode; spineFingerprint = $shapeIn.Stamp }
        coverageReport = [pscustomobject]@{ path = $CoverageReport; generated = $covIn.Generated.UtcDateTime.ToString('o'); mode = $covIn.Mode; spineFingerprint = $covIn.Stamp }
        mirrorReport = [pscustomobject]@{ path = $MirrorReport; generated = $mirIn.Generated.UtcDateTime.ToString('o'); mode = $mirIn.Mode; spineFingerprint = $mirIn.Stamp; pairs = $mirrorEntries }
    }
    channels = @($script:GdChannels)
    unmatched = $unmatched.ToArray()
    arms = @($roster)
    rule = 'disposed when answered <= allowance AND taught == item count; NOT PROVEN when no channel examined the grid, which no clearance can clear; cleared only through figures.json mirrorAllow with a written reason'
    grids = $verdicts.ToArray()
    summary = [pscustomobject]@{ grids = $gridList.Count; disposed = $disposed; cleared = $cleared; notDisposed = $notDisposed; notProven = $notProven; unmatched = $unmatched.Count }
}
$json = $out | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($OutPath, $json, (New-Object System.Text.UTF8Encoding($true)))

foreach ($u in $unmatched) { Write-Host ("  ! {0} entry did not resolve to a register grid: {1} (in {2})" -f $u.channel, $u.id, $u.where) -ForegroundColor Yellow }

if (-not $Quiet) {
    Write-Host ("  whole-spine teaching floor {0}; table mirror {1} pair(s)" -f $floorRows, $mirrorEntries) -ForegroundColor DarkGray
    if ($allow.Count -gt 0) { Write-Host ("  allow-list (figures.json mirrorAllow): {0} entr(ies) with written reasons" -f $allow.Count) -ForegroundColor DarkGray }
    Write-Host ''
    Write-Host ("  {0,-6} {1,-22} {2,-9} {3,4} {4,5} {5,8} {6,7}  verdict" -f 'sub', 'grid', 'kind', 'rows', 'allow', 'answered', 'taught') -ForegroundColor DarkGray
    foreach ($v in $verdicts) {
        $c = switch ($v.verdict) { 'disposed' { 'Green' } 'cleared' { 'DarkGray' } default { 'Red' } }
        Write-Host ("  {0,-6} {1,-22} {2,-9} {3,4} {4,5} {5,8} {6,7}  {7}" -f $v.subSection, $(if ($v.ref.Length -gt 22) { $v.ref.Substring(0, 22) } else { $v.ref }), $v.kind, $v.itemCount, $v.allowance, $v.answered, $v.taught, $v.verdict) -ForegroundColor $c
        if ($v.verdict -ne 'disposed') { Write-Host ("         {0}  [{1}]" -f $v.reason, $v.id) -ForegroundColor $c }
    }
    Write-Host ''
    Write-Host ("  written to {0}" -f $OutPath) -ForegroundColor DarkGray
}

if ($notProven -gt 0) {
    Write-Host ("  X {0} grid(s) NOT PROVEN - no channel examined them:" -f $notProven) -ForegroundColor Red
    foreach ($v in @($verdicts | Where-Object { $_.verdict -eq 'NOT PROVEN' })) {
        Write-Host ("    [{0}] {1} - absent from {2}" -f $v.subSection, $v.id, ($v.absentFrom -join ', ')) -ForegroundColor Red
    }
}

#  NAMED WHATEVER -Quiet SAYS. -Quiet suppresses the per-grid table, and for
#  one round that meant a failing run printed a count and no anchor: a runner
#  capturing this gate's output had a red line it could not act on. The
#  failing grids are named here, outside the -Quiet guard.
if ($notDisposed -gt 0) {
    Write-Host ("  X {0} grid(s) NOT DISPOSED:" -f $notDisposed) -ForegroundColor Red
    foreach ($v in @($verdicts | Where-Object { $_.verdict -eq 'NOT DISPOSED' })) {
        Write-Host ("    [{0}] {1} - {2}" -f $v.subSection, $v.id, $v.reason) -ForegroundColor Red
    }
}

if ($notDisposed -eq 0 -and $notProven -eq 0) {
    Write-Host ("  every grid is disposed: {0} disposed, {1} cleared at Stage 3d" -f $disposed, $cleared) -ForegroundColor Green
    exit 0
}
Write-Host ("  {0} of {1} grid(s) NOT DISPOSED and {2} NOT PROVEN ({3} disposed, {4} cleared)" -f $notDisposed, $gridList.Count, $notProven, $disposed, $cleared) -ForegroundColor Red
Write-Host '  A grid is disposed by teaching every row to the floor and answering none beyond the allowance,' -ForegroundColor Yellow
Write-Host '  or cleared by a written reason in figures.json "mirrorAllow" - never by editing a gate. A grid' -ForegroundColor Yellow
Write-Host '  NOT PROVEN is not cleared by a reason: run the channel that never examined it.' -ForegroundColor Yellow
exit 1

}
catch {
    $m = $_.Exception.Message

    #  ASK THE FILESYSTEM BEFORE BELIEVING THE THROW. This gate writes its whole
    #  verdict to -OutPath and only then formats it for the console, so a throw
    #  raised after that write - a formatting slip, an object dying on its way
    #  out - says nothing about whether the grids are disposed. The recorded
    #  incident is the same shape: Word finished a 383-page PDF and then died at
    #  COM teardown, and the caller reported FAILED over a correct file on disk.
    #  So the report is read back: it must exist, carry bytes, parse, be this
    #  gate's own, and have been generated by THIS run. When it is all of those,
    #  the verdict comes from the file and the exception is printed beside it.
    #  Everything before the write - CHECK-SET EMPTY, ARMS INCOMPLETE, a stale
    #  or unstamped input - throws with no report on disk and is unaffected.
    $done = $null
    if ($OutPath -and (Test-Path -LiteralPath $OutPath)) {
        $ofi = Get-Item -LiteralPath $OutPath -ErrorAction SilentlyContinue
        if ($null -ne $ofi -and $ofi.Length -gt 0) {
            try { $done = Get-Content -LiteralPath $OutPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $done = $null }
        }
    }
    $fresh = $false
    if ($null -ne $done -and "$($done.gate)" -eq $GATE -and $null -ne $done.summary) {
        try {
            $gen = [System.DateTimeOffset]::Parse("$($done.generated)", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
            $fresh = ($gen.UtcDateTime -ge $script:GdRunStart)
        }
        catch { $fresh = $false }
    }
    if ($fresh) {
        Write-Host ("  ! {0}: the sweep completed and wrote {1}, then threw: {2}" -f $GATE, $OutPath, $m) -ForegroundColor Yellow
        Write-Host ("  ! the verdict below is read from that report, not from the exception: {0} grid(s), {1} disposed, {2} cleared, {3} NOT DISPOSED, {4} NOT PROVEN" -f `
            $done.summary.grids, $done.summary.disposed, $done.summary.cleared, $done.summary.notDisposed, $done.summary.notProven) -ForegroundColor Yellow
        if ([int]$done.summary.notDisposed -eq 0 -and [int]$done.summary.notProven -eq 0) { $script:GdVerdictFromReport = 0 }
        else { $script:GdVerdictFromReport = 1 }
    }
    else {
        #  The two typed refusals Lib-GateCommon throws - an empty blocking
        #  check-set, or a blocking arm that never finished - are exit 2, and the
        #  roster is printed so a runner can see which arm starved. Anything else
        #  is a gate defect and is re-thrown as one.
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
exit ([int]$script:GdVerdictFromReport)
