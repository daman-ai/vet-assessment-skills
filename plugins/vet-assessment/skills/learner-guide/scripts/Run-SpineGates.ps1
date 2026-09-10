<#
    Run-SpineGates.ps1 - the Stage 3c spine gate band, from ONE entry point:
    every spine-level gate fanned out as a job, joined, and reported as one
    verdict, so the band's wall clock is the slowest gate plus process start
    and not the sum of eleven scripts run by hand.

    WHY THIS SCRIPT EXISTS. Every check in this band reads only the spine, the
    corpus, the withhold register and the unit extract - data that is complete
    the moment authoring closes, hours before a document is rendered. On the
    last build these checks ran one at a time, after rendering, one defect
    class per audit round, and that ordering is where five of seven hours went:
    figure content that was machine-readable JSON at 01:00 was first read as a
    figure at 05:13, and the fix cost a serial audit-remediate-re-render cycle
    of forty minutes a round for three rounds. gates.md section 12 specifies
    this band and, until now, said the runner did not exist - so the builder
    ran four of its members by hand and the ledger had to list the rest as not
    run. This file is the runner.

    THE BAND. Phase 1 fans out, phase 2 joins on three of its outputs, phase 3
    runs only on a spine that passed:

      1  Test-Spine               whole-spine: floors, both directions of every
                                  cross-reference, prepared-exactly-once,
                                  visuals, slides
      2  Test-SpineRead           fields no renderer reads
      3  Test-FigureConsistency   the registry's SOURCE arm only - the rendered
                                  arm belongs to Run-Gates, where the extracts are
      4  Check-FigureMirror       table / answer-grid mirror over the spine
      5  Check-FigureLeakage      whole-spine assessor-only sweep, with the unit
                                  extract excluded
      6  Assert-PromptLint        Route A prompts against the framing rule
      7  Test-SubSection -All     the in-loop wrapper over every sub-section the
                                  contract names, results OUTSIDE spine\
      8  Check-ShapeMirror        prose written to the model answer's shape
      9  Check-RowCoverage -Whole under-teaching against the whole-spine floor
     10  the ten gates that landed 4 Sep 2026 (FigureCoverage, Provenance,
         WithholdRegister, SpineCounts, Terminology, CitationConsistency,
         ScenarioClock, IdentifierNamespace, SpecRenderable, DeckParity)
     11  Assert-GateVisualCount   planned visuals derived from the contract,
                                  cover included (P0-11)
     12  Assert-GateFixtures      -StaticOnly: the discrimination harness's
                                  static arms, run in every band (P0-13)
         -- join --
     13  Test-GridDisposition     one verdict per grid, from 4, 8 and 9's reports
         -- the interim band verdict is written here (3c-band-verdict.json) --
         -- only when every blocking gate above passed AND the spine did not
            move during the band --
     14  New-FigureSheet          the Stage 3d figure sheet, fingerprinted to the
                                  spine it was cut from and stamped with the
                                  band verdict it was cut under

    REFUSED COUNTS AS A FAILURE. A gate that throws, times out, refuses on a
    missing input, is absent from the scripts directory, or cannot be handed a
    parameter its rule depends on is a FAIL that names the gate and the reason.
    It is never a skip: a band of four scripts recorded as "the spine gate
    band: pass" is the false green gates.md was rewritten against, and a gate
    still being written is "gate unavailable", not "not applicable". Every
    member ends PASS, FAIL, NOT RUN or REFUSED, with its exit code and the
    time it ran, in the results file.

    STAGES 1, 2 AND 3c FROM ONE RUNNER (-Stage, default 3c). Membership per
    stage is DERIVED from one header line in each gate script, exactly:

        # GATE: stages=1,3c; requires=BuildDir; 7c: DocText

    stages is a comma list drawn from 1, 2, 3c, 4, 7c; requires names the
    parameters this runner must thread (a name it cannot supply REFUSES the
    member); a stage-qualified clause ('7c: DocText') adds requirements for
    that stage only. A script with no header yet is treated as stages=3c and
    gets a printed REPORT line 'no GATE header' - never a refusal - so the
    band keeps running while the headers land. A gate in this runner's 3c
    roster whose header omits 3c is REFUSED by name: a member cannot leave
    the band by editing its own header. Stage 1 and 2 runs write
    1-results.json / 2-results.json in the 3c shape with every arm labelled
    'seed'; a seed result never counts as 3c evidence. Stage 1 offers -Stage 1
    to every member; stage 2 offers -Stage 2 and -SeedOnly, plus grids.json
    as -GridsPath when it exists.

    ARM ROSTERS ARE PARSED. Every member's 'ARMS:' line (Write-GateArmRoster)
    is read from its output and recorded; a BLOCKING arm left not-run makes
    that member FAIL with the reason 'arm not run: <name>', whatever its exit
    code said.

    EXIT 4 IS GATE-DEFECT, AND IT IS NOT A CONTENT FAILURE. A member exits 4
    when it cannot re-find one of its own findings at the token boundary it
    declared (Lib-GateCommon: New-GateFinding / Test-GateFindingAnchor). Such a
    member takes the verdict GATE-DEFECT, is listed in defective[] APART FROM
    failed[], and the band refuses to record PASS or to cut the figure sheet
    while defective[] is non-empty. Downstream, Test-StageLedger refuses to
    record a GATE-DEFECT member as a content failure or as a partial. The
    separation is mechanical because it has to be: on the reference build every
    traceable blocking finding was manufactured by a broken harvester, and with
    no way to say so, three remediation rounds were spent editing a document
    that was right.

    FIXTURE PROOF IS PRINTED BESIDE EVERY MEMBER. After the band, the newest
    gate-fixtures.<hash>.json under the build is read and UNPROVEN is printed
    beside each member it did not record as PROVEN; 'no fixtures report' when
    there is none. It is a report, not a verdict.

    THE UNIT EXTRACT IS REQUIRED FOR THE WHOLE RUN. An assessor guide quotes the
    unit, so without the unit corpus every Performance Evidence line the guide
    teaches reads as assessor-only and the leakage gate demands its deletion.
    That cannot degrade quietly into a stream of false leaks under a red line
    nobody reads, so the run is refused before any gate starts.

    PARAMETERS ARE INTROSPECTED, NEVER ASSUMED. Each gate is called by reading
    (Get-Command <script>).Parameters and passing only what that copy declares.
    A parameter the gate's blocking rule depends on that the copy cannot take
    REFUSES the gate rather than running it without the input - a blocking rule
    behind an optional parameter prints a clean pass having checked nothing.
    Every parameter threaded is PRINTED at the end so a reader can see nothing
    was omitted without reading this file.

    THE SUB-SECTION RESULTS LIVE OUTSIDE spine\. Test-SubSection writes a
    gate.json per file; beside the file it would sit in the spine directory,
    where every whole-spine reader globs *.json. So -ResultDir points at
    <build>\3c\subsections, the directory is cleared before the run, and the
    per-file verdicts are collected from there into the band's result.

    THE FIGURE SHEET IS NEVER CUT FROM A SPINE THAT FAILED OR MOVED. It is the
    transcript reviewers read at Stage 3d and it travels with every later
    review pack. Cut from a failing spine it would carry content the
    remediation is about to change, stamped with a fingerprint the ledger will
    reject later - so it runs last, after the join, only on a green band, and
    never in a partial run. After phase 2 the fingerprint is recomputed and
    the interim verdict of phases 1-2 is written to 3c-band-verdict.json
    {spineFingerprint, verdict, exitCode, failed[], partial, ranAt, members};
    that file is handed to New-FigureSheet -BandResults, which refuses the cut
    itself unless it says PASS on the very spine it hashes. A spine that moved
    between the start of the band and the join REFUSES the cut here, naming
    both fingerprints. The figureSheet field in the results is derived from
    the phase-3 job result plus Test-Path on the sheet - never from a note.

    -Only IS A PARTIAL RUN AND CANNOT CLAIM THE BAND. A subset re-run is for
    fixing one gate's findings quickly. It prints a PARTIAL RUN banner, writes
    partial=true into <stage>-results.partial.json and NEVER touches
    <stage>-results.json (the band's evidence), never cuts the sheet, and
    exits 3 even when every selected gate passed - so a subset can never be
    mistaken for the band.

    THE SUB-SECTION WRAPPER IS ONLY AS GOOD AS ITS PER-FILE RESULTS. A wrapper
    that exited 0 while any per-file gate.json it wrote says fail (or is
    unreadable, or was never written) is a FAIL naming the file.

    NEVER PRINTS A MODEL BULLET OF ITS OWN. Gate output is passed through as
    the gate printed it; the gates own that rule.

    Usage
      Run-SpineGates.ps1 -BuildDir <dir> [-Stage 1|2|3c] [-SpineDir <dir>]
                         [-UnitExtract <md>] [-Profile <rto-profile.json>]
                         [-ResultDir <dir>] [-MaxJobs 8] [-TimeoutMinutes 10]
                         [-Serial] [-Only Test-Spine,Assert-PromptLint]
      Run-SpineGates.ps1 -SelfTest        no build, no Office, no API

    THE RESULTS SHAPE IS A CONTRACT, AND THIS FILE IS ITS REFERENCE. Run-Gates
    writes stages 4 and 7c in the same shape, Stage-Ledger reads both by these
    key names, and Test-FigureSheetCurrent and New-FigureSheet read the band
    keys. Add keys; never rename or retype one without changing every reader.

    Writes <build>\<stage>-results.json (3c-results.json for the band):

      runner                 'Run-SpineGates'
      stage                  '1' | '2' | '3c'
      seed                   true for stages 1 and 2 - never 3c evidence
      startedAt, ranAt       UTC ISO 8601, run start and run end
      buildDir, spineDir, resultDir, unitExtract
      spineFingerprint       v2:<32 hex> at entry (the run's fingerprint)
      spineFingerprintAtJoin recomputed after phase 2, before the sheet
      spineFingerprintAfter  recomputed at the end
      spineChangedDuringRun  bool: entry fingerprint != end fingerprint
      partial                true for a -Only run (written to the .partial file)
      only[]                 the -Only names, empty otherwise
      maxJobs, timeoutMinutes
      gates[]                one per planned member, in plan order:
         name, script, phase (1|2|3), stage, params{}, dropped[], must[],
         exitCode, startedAt, ranAt, seconds, gateSeconds,
         verdict PASS|FAIL|GATE-DEFECT|NOT RUN|REFUSED, reason, refused, evidence,
         arms[] {name, blocking, state, size, findings, evidence},
         armLines[], armsBlockingNotRun[], armProblems[],
         fixtureProof, header, headerStages[], headerProblems[], reports[],
         log, summaryLines[]
         (Test-SubSection also carries subSectionResultDir, subSections[],
          subSectionsFailing)
      slowest {name, seconds}, wallClockSeconds, sumOfGateSeconds
      failed[]               member names, plus 'spine-changed-during-run';
                             a GATE-DEFECT member is NEVER in this list
      defective[]            members that exited 4 - they could not re-find
                             their own anchor. Non-empty forbids PASS and
                             forbids the figure-sheet cut.
      fixtures               {report, hash, found, note, unproven[]}
      plantChannel           {scriptsHash, action, reason, started, pid,
                              statePath, waitedFor:false}
      bandVerdictFile, bandVerdictAtJoin
      figureSheet            derived: 'cut', 'not in this run', or a NOT RUN /
                             REFUSED / FAIL sentence; figureSheetPath when cut
      verdict                PASS | FAIL | GATE-DEFECT | PARTIAL |
                             PARTIAL-FAIL | PARTIAL-GATE-DEFECT
      exitCode               the process exit code, written into the file

    plus the per-gate logs under <build>\<stage>\logs; a -Only run writes
    <stage>-results.partial.json instead.

    THE FIXTURES PLANT CHANNEL IS STARTED, NEVER WAITED FOR (P0-13). After the
    band has been judged, the full Assert-GateFixtures plant channel is started
    as a DETACHED process (not a job: this runner exits, and a job would die
    with it), keyed on a hash of every scripts\*.ps1, with a state file at
    <build>\fixtures\plant-channel.json so a second band does not start a
    second channel. Its verdicts reach the band as the UNPROVEN report of a
    LATER run. -NoPlantChannel suppresses the start and nothing else.

    PS 5.1. ASCII only in this file. UTF-8 BOM required on disk.
    Exit 0 every blocking gate passed; 1 a gate failed, was refused, timed out
    or is unavailable, OR a member is GATE-DEFECT (verdict GATE-DEFECT, listed
    in defective[] - a band carrying one is never a pass); 2 a usage error
    (including no unit extract at 3c, or a stage with no member declaring it);
    3 a partial run (-Only) in which every selected gate passed; 4 THE RUNNER'S
    OWN self-test failed. (A MEMBER's exit 4 is GATE-DEFECT; this runner never
    passes a member's 4 through as its own.)
#>

[CmdletBinding()]
param(
    [string] $BuildDir,
    [string] $SkillDir,
    [string] $SpineDir,
    [string] $UnitExtract,
    #  The RTO profile pack for the prompt lint. Left blank, the lint resolves
    #  it from the contract's brand exactly as it does when run by hand.
    [string] $Profile,
    #  Where the band's own outputs go: sub-section gate.json files, per-gate
    #  logs, the leakage report. Default <build>\3c. Must not be under spine\.
    [string] $ResultDir,
    #  Re-run a subset by gate name (Test-Spine, Check-ShapeMirror, ...). A
    #  PARTIAL RUN: banner, partial=true, no figure sheet, exit 3 at best.
    [string[]] $Only,
    #  Which band: 1 and 2 are the seed bands over the corpus, the contract and
    #  the registry (membership from each gate's '# GATE: stages=' header);
    #  3c is the spine band. Each writes <stage>-results.json.
    [ValidateSet('1', '2', '3c')][string] $Stage = '3c',
    [int] $MaxJobs = 8,
    [int] $TimeoutMinutes = 10,
    #  One job at a time, for debugging. The same wrapper, the same rules.
    [switch] $Serial,
    #  Do not START the fixtures plant channel after the band (P0-13). The
    #  channel is a background REPORT and never a verdict: with or without it
    #  the newest report on disk is still read and UNPROVEN is still printed
    #  beside every member it did not prove. Nothing here is a check.
    [switch] $NoPlantChannel,
    [switch] $SelfTest
)

#  $PSScriptRoot is EMPTY inside a PARAMETER DEFAULT when the script is run as
#  `powershell -File`, so a default that called Split-Path on it threw inside
#  the parameter block: the script exited 1 having never run a single check -
#  the same exit code it uses for a real finding, which is why nobody noticed.
#  Resolved here instead, where the automatic variable is populated, with a
#  guarded fallback for the scriptblock case.
if (-not $SkillDir) {
    $__here = $PSScriptRoot
    if (-not $__here -and $MyInvocation.MyCommand.Path) { $__here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if ($__here) { $SkillDir = Split-Path -Parent $__here }
}

$ErrorActionPreference = 'Stop'

function AsArr { param($x) if ($null -eq $x) { return @() } return @($x) }
function HasProp { param($o, [string] $n) if ($null -eq $o) { return $false } return (@($o.PSObject.Properties.Name) -contains $n) }

function Read-JsonFile {
    <# Explicit UTF-8, BOM dropped - PS 5.1 reads a BOM-less file as ANSI. #>
    param([Parameter(Mandatory)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $t = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path, [System.Text.Encoding]::UTF8)
    $t = $t.TrimStart([char]0xFEFF)
    if (-not $t.Trim()) { return $null }
    return ($t | ConvertFrom-Json)
}

function Write-JsonFile {
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)] $Body)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $json = $Body | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($true)))
}

#  The shared gate library, for Get-SpineFingerprint. A plain library: no
#  param block, no side effects, nothing decided.
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

function Get-FileSha256 {
    <# Lower-case hex sha256 of a file's bytes, '' when the file is absent. #>
    param([Parameter(Mandatory)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path).Path))).Replace('-', '').ToLowerInvariant()) }
    finally { $sha.Dispose() }
}

function Get-UtcNow { return (Get-Date).ToUniversalTime().ToString('o') }

# ---------------------------------------------------------------------------
# 0. The three things this runner READS from a member rather than assumes:
#    its GATE header (membership), its ARMS line (rule coverage) and the
#    fixtures harness's verdict on it (discrimination proof)
# ---------------------------------------------------------------------------

#  The stages a GATE HEADER may name. This is the vocabulary of the whole
#  pipeline, not the set of bands THIS runner drives - the two are different
#  and conflating them turned a correct header into a reported problem.
#
#  '0' is a real stage with a real runner: Invoke-Stage0 plans
#  Assert-GateFixtures as a Stage 0 member, so that gate's header rightly
#  declares stages=0,1,2,3c,4,7c. Reading '0' as unknown printed a header
#  problem against a correct declaration on every single band run.
#
#  Run-SpineGates still only ACCEPTS -Stage 1, 2 or 3c; '0' is parsed and
#  understood here so a header can be honest about a band another runner owns.
$script:ValidGateStages = @('0', '1', '2', '3c', '4', '7c')

function Get-GateHeader {
    <#  Parse the one header line a gate script carries, exactly:

            # GATE: stages=1,3c; requires=BuildDir; 7c: DocText

        Returns Found, Raw, Line, Stages[], Requires[], StageRequires (stage -> names)
        and Problems[]. An absent header is Found=false with no problem: the
        caller treats it as stages=3c and prints 'no GATE header'. A present
        header with an unknown stage, an unrecognised clause or no stages=
        clause records each problem by text; the valid parts are still used.
        Nothing here refuses - the caller decides what a problem means.  #>
    param([Parameter(Mandatory)][string] $Path)
    $h = [pscustomobject]@{ Path = $Path; Found = $false; Raw = ''; Line = 0; Stages = @(); Requires = @(); StageRequires = @{}; Problems = @() }
    if (-not (Test-Path -LiteralPath $Path)) { return $h }
    #  WHERE A HEADER IS, EXACTLY: at column 0, outside the <# #> doc block,
    #  ABOVE the param block. Everything below param() is code, and a
    #  '# GATE:' line there belongs to a fixture, a self-test plant or a
    #  quoted example - Assert-GateFixtures writes exactly such a line inside
    #  a here-string. Reading one as this script's header bound a member to a
    #  requires= it is deliberately not handed and REFUSED it, which is a band
    #  failure manufactured out of a string literal.
    $raw = ''
    $lineNo = 0
    $n = 0
    $inBlock = $false
    foreach ($ln in [System.IO.File]::ReadAllLines((Resolve-Path -LiteralPath $Path).Path)) {
        $n++
        if ($inBlock) { if ($ln -match '#>') { $inBlock = $false }; continue }
        if ($ln -match '^\s*<#') { if ($ln -notmatch '#>') { $inBlock = $true }; continue }
        if ($ln -match '^\s*(\[CmdletBinding|param\s*\()') { break }
        if ($ln -match '^#\s*GATE:\s*(.+?)\s*$') { $raw = $Matches[1]; $lineNo = $n; break }
    }
    if (-not $raw) { return $h }
    $h.Found = $true
    $h.Raw = $raw
    $h.Line = $lineNo
    $stages = @(); $req = @(); $sreq = @{}; $problems = @()
    foreach ($clause in ($raw -split ';')) {
        $c = $clause.Trim()
        if (-not $c) { continue }
        if ($c -match '^(?i)stages\s*=\s*(.*)$') {
            foreach ($s in ($Matches[1] -split ',')) {
                $t = $s.Trim().ToLowerInvariant()
                if (-not $t) { continue }
                if ($script:ValidGateStages -contains $t) { if ($stages -notcontains $t) { $stages += $t } }
                else { $problems += ("unknown stage '{0}' in stages= (valid: {1})" -f $t, ($script:ValidGateStages -join ', ')) }
            }
        }
        elseif ($c -match '^(?i)requires\s*=\s*(.*)$') {
            foreach ($n in ($Matches[1] -split ',')) { $t = $n.Trim(); if ($t -and $req -notcontains $t) { $req += $t } }
        }
        elseif ($c -match '^([0-9]+[a-z]?)\s*:\s*(.*)$') {
            $s = $Matches[1].ToLowerInvariant()
            $names = @($Matches[2] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            if ($script:ValidGateStages -notcontains $s) { $problems += ("stage-qualified clause names unknown stage '{0}'" -f $s) }
            elseif ($names.Count -eq 0) { $problems += ("stage-qualified clause '{0}:' names no parameter" -f $s) }
            else { $sreq[$s] = @($names) }
        }
        else { $problems += ("unrecognised clause '{0}'" -f $c) }
    }
    if ($stages.Count -eq 0) { $problems += 'no stages= clause with a valid stage' }
    $h.Stages = @($stages); $h.Requires = @($req); $h.StageRequires = $sreq; $h.Problems = @($problems)
    return $h
}

function Get-HeaderRequirement {
    <# The parameter names a header requires at one stage: requires= plus the stage-qualified clause. #>
    param([Parameter(Mandatory)] $Header, [Parameter(Mandatory)][string] $Stage)
    $out = @()
    if ($null -eq $Header -or -not $Header.Found) { return $out }
    foreach ($n in @($Header.Requires)) { if ($out -notcontains $n) { $out += $n } }
    if ($Header.StageRequires.ContainsKey($Stage)) { foreach ($n in @($Header.StageRequires[$Stage])) { if ($out -notcontains $n) { $out += $n } } }
    return $out
}

function ConvertFrom-ArmRosterText {
    <#  Every 'ARMS:' line in a member's output, parsed by the contract
        Write-GateArmRoster prints:

            ARMS: name|true/false|state|size|findings;name|...      or  ARMS: none

        Returns Lines (the raw lines), Arms[] ({name, blocking, state, size,
        findings, evidence}), BlockingNotRun[] and Problems[] (a cell that does
        not parse is a problem naming the cell, and the arm is kept with state
        'unparsed' so it cannot vanish). -Evidence labels every arm ('seed' for
        a stage 1/2 run, '3c' for the band).  #>
    param([string] $Text, [string] $Evidence = '3c')
    $lines = @(); $arms = @(); $notRun = @(); $problems = @()
    if ($Text) {
        foreach ($ln in ($Text -split "`n")) {
            $t = $ln.TrimEnd()
            #  (?-i) - CASE-SENSITIVE. Write-GateArmRoster prints 'ARMS:' in
            #  capitals; the gates also print a human line 'arms: 4 registered,
            #  2 blocking, all complete', and reading that as a roster reported
            #  'ARMS cell does not parse' against six passing gates on a real
            #  band. -match is case-insensitive by default in PS 5.1.
            if ($t -notmatch '(?-i)^\s*ARMS:\s*(.*)$') { continue }
            $lines += $t.Trim()
            $body = $Matches[1].Trim()
            if (-not $body -or $body -ieq 'none') { continue }
            foreach ($cell in ($body -split ';')) {
                $c = $cell.Trim()
                if (-not $c) { continue }
                $p = @($c -split '\|')
                if ($p.Count -ne 5 -or -not $p[0].Trim() -or $p[1].Trim() -notin @('true', 'false') -or $p[3].Trim() -notmatch '^\d+$' -or $p[4].Trim() -notmatch '^\d+$') {
                    $problems += ("ARMS cell does not parse: '{0}'" -f $c)
                    $arms += [pscustomobject]@{ name = $c; blocking = $true; state = 'unparsed'; size = 0; findings = 0; evidence = $Evidence }
                    continue
                }
                $blocking = ($p[1].Trim() -eq 'true')
                $state = $p[2].Trim().ToLowerInvariant()
                $arms += [pscustomobject]@{ name = $p[0].Trim(); blocking = $blocking; state = $state; size = [int]$p[3].Trim(); findings = [int]$p[4].Trim(); evidence = $Evidence }
                if ($blocking -and $state -eq 'not-run') { if ($notRun -notcontains $p[0].Trim()) { $notRun += $p[0].Trim() } }
            }
        }
    }
    return [pscustomobject]@{ Lines = @($lines); Arms = @($arms); BlockingNotRun = @($notRun); Problems = @($problems) }
}

function Get-FixtureProof {
    <#  The newest gate-fixtures.<hash>.json under the build, read for the
        verdict it recorded per gate. Only the hash-stamped file counts (the
        plant channel's output, P0-13); the un-stamped gate-fixtures.json a
        static run writes is not a proof of discrimination. Found=false with a
        Note when there is none. Nothing here decides a band verdict.  #>
    param([Parameter(Mandatory)][string] $BuildDir)
    $none = [pscustomobject]@{ Found = $false; Path = ''; Hash = ''; RanAt = ''; Map = @{}; Note = ("no fixtures report (no gate-fixtures.<hash>.json under {0})" -f $BuildDir) }
    if (-not (Test-Path -LiteralPath $BuildDir)) { return $none }
    $files = @(Get-ChildItem -LiteralPath $BuildDir -Recurse -File -Filter 'gate-fixtures.*.json' -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match '^gate-fixtures\.([0-9a-fA-F]{6,64})\.json$' } |
               Sort-Object LastWriteTimeUtc -Descending)
    if ($files.Count -eq 0) { return $none }
    $f = $files[0]
    $hash = ''
    if ($f.Name -match '^gate-fixtures\.([0-9a-fA-F]{6,64})\.json$') { $hash = $Matches[1].ToLowerInvariant() }
    $j = $null
    try { $j = Read-JsonFile -Path $f.FullName } catch { $j = $null }
    if ($null -eq $j) { return [pscustomobject]@{ Found = $false; Path = $f.FullName; Hash = $hash; RanAt = ''; Map = @{}; Note = ("fixtures report does not parse: {0}" -f $f.FullName) } }
    $map = @{}
    $rows = Get-GateProp -Object $j -Names @('results', 'gates', 'rows')
    foreach ($r in @($rows)) {
        if ($null -eq $r) { continue }
        $n = [string](Get-GateProp -Object $r -Names @('Gate', 'gate', 'name', 'Name', 'script', 'Script'))
        if (-not $n) { continue }
        $n = [System.IO.Path]::GetFileName($n) -replace '(?i)\.ps1$', ''
        $v = [string](Get-GateProp -Object $r -Names @('Verdict', 'verdict', 'state', 'State'))
        if (-not $v) { $v = '(no verdict recorded)' }
        $map[$n.ToLowerInvariant()] = $v
    }
    $ran = [string](Get-GateProp -Object $j -Names @('checkedAt', 'ranAt', 'generated'))
    return [pscustomobject]@{ Found = $true; Path = $f.FullName; Hash = $hash; RanAt = $ran; Map = $map; Note = ("fixtures report {0} (hash {1}, {2} gate(s) recorded)" -f $f.FullName, $hash, $map.Count) }
}

function Get-SkillScriptsHash {
    <#  A short key over the bytes of every scripts\*.ps1 (name-ordered) plus
        any recipe file beside them. It answers one question: have the scripts
        changed since the last plant channel ran? A plant verdict is about a
        set of scripts, so the key is the set of scripts.

        This is NOT the hash Assert-GateFixtures stamps inside its own report
        (that one includes the recipe scriptblocks it holds in memory). This
        one keys THIS runner's decision to start the channel, and is recorded
        in the channel's own state file so the decision can be read back.  #>
    param([Parameter(Mandatory)][string] $SkillDir)
    $dir = Join-Path $SkillDir 'scripts'
    if (-not (Test-Path -LiteralPath $dir)) { return '' }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $parts = New-Object System.Collections.Generic.List[string]
        foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter '*.ps1' -File -ErrorAction SilentlyContinue | Sort-Object Name)) {
            $parts.Add(("{0}:{1}" -f $f.Name, [BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes($f.FullName))).Replace('-', '')))
        }
        foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter '*recipe*.json' -File -ErrorAction SilentlyContinue | Sort-Object Name)) {
            $parts.Add(("{0}:{1}" -f $f.Name, [BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes($f.FullName))).Replace('-', '')))
        }
        if ($parts.Count -eq 0) { return '' }
        $all = [System.Text.Encoding]::UTF8.GetBytes(($parts -join "`n"))
        return ([BitConverter]::ToString($sha.ComputeHash($all)).Replace('-', '').Substring(0, 8).ToLowerInvariant())
    }
    finally { $sha.Dispose() }
}

function Get-PlantChannelPlan {
    <#  Should the FULL fixtures plant channel start after this band?

        The channel proves discrimination by planting a defect into a lean copy
        of the build and running each gate twice. It costs minutes, it is a
        REPORT and never a verdict, and it must never sit on the band's
        critical path - so it is started detached, after the results are
        written, and this runner never waits for it. Its output is read by the
        NEXT run through Get-FixtureProof.

        Actions: start, current (a report for these very scripts is already on
        disk), running (a channel for this key started recently), suppressed
        (-NoPlantChannel), unavailable (no fixtures gate), no-build, no-hash.
        Nothing here runs anything.  #>
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [Parameter(Mandatory)][string] $SkillDir,
        [string] $Hash,
        [switch] $Suppressed,
        [int] $RunningMinutes = 60
    )
    $fixturesDir = Join-Path $BuildDir 'fixtures'
    $o = [pscustomobject]@{
        Action = ''; Reason = ''; Hash = $Hash; Gate = (Join-Path (Join-Path $SkillDir 'scripts') 'Assert-GateFixtures.ps1')
        ResultDir = $fixturesDir; StatePath = (Join-Path $fixturesDir 'plant-channel.json'); Report = ''
    }
    if ($Suppressed) { $o.Action = 'suppressed'; $o.Reason = '-NoPlantChannel was passed; the newest report on disk is still read and printed'; return $o }
    if (-not $Hash) { $o.Action = 'no-hash'; $o.Reason = 'no scripts to hash under the skill directory'; return $o }
    if (-not (Test-Path -LiteralPath $o.Gate)) { $o.Action = 'unavailable'; $o.Reason = ("no Assert-GateFixtures.ps1 at {0}" -f $o.Gate); return $o }
    if (-not (Test-Path -LiteralPath $BuildDir)) { $o.Action = 'no-build'; $o.Reason = 'no build directory'; return $o }
    $hashed = Join-Path $fixturesDir ("gate-fixtures.{0}.json" -f $Hash)
    if (Test-Path -LiteralPath $hashed) { $o.Action = 'current'; $o.Report = $hashed; $o.Reason = ("a plant report for scripts hash {0} is already on disk" -f $Hash); return $o }
    if (Test-Path -LiteralPath $o.StatePath) {
        $st = $null
        try { $st = Read-JsonFile -Path $o.StatePath } catch { $st = $null }
        if ($null -ne $st -and [string](Get-GateProp -Object $st -Names @('scriptsHash')) -eq $Hash) {
            $started = [string](Get-GateProp -Object $st -Names @('startedAt'))
            $age = $null
            if ($started) { try { $age = ((Get-Date).ToUniversalTime() - ([datetime]$started).ToUniversalTime()).TotalMinutes } catch { $age = $null } }
            if ($null -ne $age -and $age -ge 0 -and $age -lt $RunningMinutes) {
                $o.Action = 'running'
                $o.Reason = ("a channel for scripts hash {0} started {1} minute(s) ago (pid {2}); it is not started twice" -f $Hash, [math]::Round($age, 1), [string](Get-GateProp -Object $st -Names @('pid')))
                return $o
            }
        }
    }
    $o.Action = 'start'
    $o.Reason = ("no plant report for scripts hash {0} under {1}" -f $Hash, $fixturesDir)
    return $o
}

function Start-PlantChannel {
    <#  Launch the full channel DETACHED and return immediately. Detached, not
        Start-Job: this runner exits when the band ends and a job would die
        with it. The state file records what was started, so the next run can
        see a channel is already working on these scripts.  #>
    param([Parameter(Mandatory)] $Plan, [Parameter(Mandatory)][string] $BuildDir, [Parameter(Mandatory)][string] $SkillDir)
    $out = [pscustomobject]@{ Started = $false; Pid = 0; Error = ''; Command = '' }
    try {
        if (-not (Test-Path -LiteralPath $Plan.ResultDir)) { New-Item -ItemType Directory -Force -Path $Plan.ResultDir | Out-Null }
        $args_ = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Plan.Gate, '-SkillDir', $SkillDir, '-BuildDir', $BuildDir, '-ResultDir', $Plan.ResultDir, '-Quiet')
        $out.Command = ('powershell.exe ' + ($args_ -join ' '))
        $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $args_ -WindowStyle Hidden -PassThru
        $out.Started = $true
        $out.Pid = $p.Id
        Write-JsonFile -Path $Plan.StatePath -Body ([pscustomobject]([ordered]@{
            runner = 'Run-SpineGates'; kind = 'fixtures-plant-channel'; scriptsHash = $Plan.Hash
            startedAt = (Get-UtcNow); pid = $p.Id; command = $out.Command; resultDir = $Plan.ResultDir
            note = 'Started detached and NOT waited for. Its verdicts reach the band as the UNPROVEN report of a LATER run.'
        }))
    }
    catch { $out.Error = $_.Exception.Message }
    return $out
}

function Get-MemberProofNote {
    <# 'PROVEN', 'UNPROVEN (<verdict>)', 'UNPROVEN (not in the fixtures report)' or 'no fixtures report'. #>
    param([Parameter(Mandatory)] $Proof, [Parameter(Mandatory)][string] $Name)
    if (-not $Proof.Found) { return 'no fixtures report' }
    $k = $Name.ToLowerInvariant()
    if (-not $Proof.Map.ContainsKey($k)) { return 'UNPROVEN (not in the fixtures report)' }
    $v = [string]$Proof.Map[$k]
    if ($v -eq 'PROVEN') { return 'PROVEN' }
    return ("UNPROVEN ({0})" -f $v)
}

# ---------------------------------------------------------------------------
# 1. Parameter introspection - pass what a gate copy declares, refuse what a
#    rule depends on and the copy cannot take
# ---------------------------------------------------------------------------

function Get-ScriptParameterName {
    <#  The parameter names a script declares, or an empty list when the script
        is absent. A script that exists but cannot be parsed is reported by the
        caller as unavailable - Get-Command throws, and the throw is the reason.  #>
    param([Parameter(Mandatory)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    $c = Get-Command -Name $Path -ErrorAction Stop
    return @($c.Parameters.Keys | Where-Object { $_ -notin [System.Management.Automation.PSCmdlet]::CommonParameters })
}

function New-GateEntry {
    <#  One plan entry. -Want is every argument this runner would like to hand
        the gate; -Must names the ones its blocking rule depends on. Declared
        arguments are threaded, undeclared optional ones are recorded as dropped
        (and printed), an undeclared -Must argument or a missing script REFUSES
        the entry - and a refused entry is a failure in the results.

        -Stage is the band this entry runs in. The gate's own GATE header
        (Get-GateHeader) is read here: its requires= names and the clause for
        this stage are ADDED to -Must, and a -Must name this runner has no
        value for (absent from -Want) refuses the entry naming it - a rule
        that depends on an input nobody supplied cannot pass. -Looked maps a
        parameter name to the file the runner looked for and did not find, so
        that refusal is a work order. A script with no header gets a printed
        REPORT line (Reports[]) and is treated as stages=3c; a header on a
        member of this runner's 3c roster that omits 3c refuses the entry.  #>
    param(
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][string] $Title,
        [Parameter(Mandatory)][string] $Script,
        [Parameter(Mandatory)][int] $Phase,
        [System.Collections.IDictionary] $Want,
        [string[]] $Must,
        [string] $Produces,
        [string] $Refused,
        [string] $Stage = '3c',
        [System.Collections.IDictionary] $Looked,
        [switch] $RosterMember
    )
    if ($null -eq $Want) { $Want = [ordered]@{} }
    if ($null -eq $Must) { $Must = @() }
    if ($null -eq $Looked) { $Looked = @{} }
    $args_ = [ordered]@{}
    $dropped = @()
    $reports = @()
    $header = Get-GateHeader -Path $Script
    $must = @($Must)
    if (-not $Refused) {
        $declared = @()
        try { $declared = @(Get-ScriptParameterName -Path $Script) }
        catch { $Refused = ("gate unavailable - the script could not be read: {0}" -f $_.Exception.Message) }
        if (-not $Refused -and $declared.Count -eq 0) {
            $Refused = ("gate unavailable - script not found: {0}" -f $Script)
        }
        if (-not $Refused) {
            if (-not $header.Found) { $reports += 'no GATE header (treated as stages=3c until the header lands)' }
            else {
                foreach ($p in @($header.Problems)) { $reports += ("GATE header problem: {0} (header: '{1}')" -f $p, $header.Raw) }
                #  TWO statements, never `$x = if (..) { @(..) }`: a one-element
                #  array on the output of an if unrolls to the element itself.
                $headerStages = @()
                if ($null -ne $header.Stages) { $headerStages = @($header.Stages) }
                if ($RosterMember -and $Stage -eq '3c' -and $headerStages.Count -gt 0 -and $headerStages -notcontains '3c') {
                    $Refused = ("GATE header declares stages={0} without 3c, but this runner's 3c roster names it. A member cannot leave the band by editing its own header - reconcile the roster or the header." -f ($headerStages -join ','))
                }
                foreach ($n in (Get-HeaderRequirement -Header $header -Stage $Stage)) { if ($must -notcontains $n) { $must += $n } }
            }
        }
        if (-not $Refused) {
            foreach ($m in $must) {
                if (-not $Want.Contains([string]$m)) {
                    $where = if ($Looked.Contains([string]$m)) { (" (looked for {0}: absent)" -f $Looked[[string]$m]) } else { '' }
                    $Refused = ("the gate requires -{0} at stage {1} and this runner has no value to thread for it{2}" -f $m, $Stage, $where)
                    break
                }
            }
        }
        if (-not $Refused) {
            foreach ($k in $Want.Keys) {
                if ($declared -contains [string]$k) { $args_[[string]$k] = $Want[$k]; continue }
                if ($must -contains [string]$k) {
                    $Refused = ("this copy of the gate does not accept -{0}, which its blocking rule depends on (it takes: {1})" -f $k, ($declared -join ', '))
                    break
                }
                $dropped += [string]$k
            }
        }
    }
    return [pscustomobject]@{
        Name = $Name; Title = $Title; Script = $Script; Phase = $Phase; Stage = $Stage
        Args = $args_; Dropped = @($dropped); Produces = $Produces; Refused = $Refused
        Must = @($must); Header = $header; Reports = @($reports)
    }
}

# ---------------------------------------------------------------------------
# 2. The invocation plan - DATA, built before any gate runs
# ---------------------------------------------------------------------------

#  The 3c roster, in order. The first 21 are the members wired 3-4 Sep 2026
#  and keep their order; Assert-GateVisualCount (P0-11) and Assert-GateFixtures
#  -StaticOnly (P0-13) join phase 1 after them; the sheet stays last.
$script:GateOrder = @(
    'Test-Spine', 'Test-SpineRead', 'Test-FigureConsistency', 'Check-FigureMirror',
    'Check-FigureLeakage', 'Assert-PromptLint', 'Test-SubSection', 'Check-ShapeMirror',
    'Check-RowCoverage', 'Test-GridDisposition',
    #  Landed 4 Sep 2026. Phase 1 like the rest: each reads only the spine, the
    #  corpus, the register and the registry.
    'Assert-FigureCoverage', 'Assert-Provenance', 'Assert-WithholdRegister',
    'Assert-SpineCounts', 'Assert-Terminology', 'Assert-CitationConsistency',
    'Assert-ScenarioClock', 'Assert-IdentifierNamespace', 'Assert-SpecRenderable',
    'Assert-DeckParity',
    'Assert-GateVisualCount', 'Assert-GateFixtures',
    'New-FigureSheet'
)

#  Scripts that are never band members whatever header they carry: the two
#  runners. Everything else under scripts\ is a candidate the header decides.
$script:NotMembers = @('Run-SpineGates', 'Run-Gates')

function Get-StageOffer {
    <#  The arguments this runner OFFERS a member at a stage, over and above
        the build-level inputs: stage 1 and 2 members are told which stage
        they run in, stage 2 members may run their seed arms only. Offered
        means threaded if declared, dropped if not, and required only when the
        gate's header says so.  #>
    param([Parameter(Mandatory)][string] $Stage)
    switch ($Stage) {
        '1'  { return [ordered]@{ Stage = 1 } }
        '2'  { return [ordered]@{ Stage = 2; SeedOnly = $true } }
        default { return [ordered]@{} }
    }
}

function New-GenericWant {
    <#  The build-level inputs offered to a header-declared member this runner
        has no hand-written entry for (every stage 1 and 2 member, and any
        script that declares 3c beyond the roster). One report path is offered
        under the FIRST name the copy declares of ReportPath, ResultPath,
        OutPath, so a gate is never handed the same path twice under two
        names. Every file-backed input is offered only when it exists, and the
        path looked for is recorded in $Looked so a header that requires it
        can be refused naming the absent file.  #>
    param([Parameter(Mandatory)][hashtable] $In, [Parameter(Mandatory)][string] $Name, [Parameter(Mandatory)][string] $Stage, [Parameter(Mandatory)][System.Collections.IDictionary] $Looked)
    $script_ = Join-Path (Join-Path $In.SkillDir 'scripts') ($Name + '.ps1')
    $declared = @()
    try { $declared = @(Get-ScriptParameterName -Path $script_) } catch { $declared = @() }
    $w = [ordered]@{ BuildDir = $In.BuildDir; SkillDir = $In.SkillDir }
    if ($In.SpineDir -and (Test-Path -LiteralPath $In.SpineDir)) { $w['SpineDir'] = $In.SpineDir } else { $Looked['SpineDir'] = [string]$In.SpineDir }
    $reportPath = Join-Path $In.ResultDir ($Name + '.json')
    foreach ($rn in @('ReportPath', 'ResultPath', 'OutPath')) { if ($declared -contains $rn) { $w[$rn] = $reportPath; break } }
    if ($In.Profile) { $w['Profile'] = $In.Profile; $w['ProfilePath'] = $In.Profile } else { $Looked['Profile'] = 'an RTO profile pack (-Profile)'; $Looked['ProfilePath'] = $Looked['Profile'] }
    $fileBacked = [ordered]@{
        Register = $In.Register; RegisterPath = $In.Register
        RulesPath = $In.Rules
        AssessorCells = $In.Cells; AssessorCellsPath = $In.Cells
        UnitExtract = $In.UnitExtract
        ContractPath = (Join-Path $In.BuildDir 'contract.json')
        CorpusDir = (Join-Path $In.BuildDir 'corpus')
        #  The source pack, resolved from the contract by the caller. Offered,
        #  never guessed: Assert-CorpusComplete's header requires -PackDir, and
        #  refusing it for want of a value this runner already holds would be a
        #  gap of the runner's own making.
        PackDir = $(if ($In.ContainsKey('PackDir')) { [string]$In.PackDir } else { '' })
        HazardPath = (Join-Path $In.BuildDir 'pack-hazards.json')
        GridsPath = (Join-Path $In.BuildDir 'grids.json')
        ManifestPath = (Join-Path (Join-Path $In.BuildDir 'corpus') 'manifest.json')
    }
    foreach ($k in $fileBacked.Keys) {
        $p = [string]$fileBacked[$k]
        if ($p -and (Test-Path -LiteralPath $p)) { $w[$k] = $p } else { $Looked[$k] = $(if ($p) { $p } else { '(no path resolved)' }) }
    }
    $offer = Get-StageOffer -Stage $Stage
    foreach ($k in $offer.Keys) { $w[$k] = $offer[$k] }
    return $w
}

function Get-HeaderDeclaredMember {
    <#  Every script under scripts\ whose GATE header declares -Stage, by
        name, in this order: the 3c roster's order for names it knows, then
        the rest alphabetically. The runners are never members. A script with
        no header declares nothing here (the 3c roster covers the transition).  #>
    param([Parameter(Mandatory)][string] $SkillDir, [Parameter(Mandatory)][string] $Stage)
    $scripts = Join-Path $SkillDir 'scripts'
    if (-not (Test-Path -LiteralPath $scripts)) { return @() }
    $declared = @()
    foreach ($f in (Get-ChildItem -LiteralPath $scripts -Filter '*.ps1' -File | Sort-Object Name)) {
        $n = $f.BaseName
        if ($script:NotMembers -contains $n) { continue }
        $h = Get-GateHeader -Path $f.FullName
        if ($h.Found -and @($h.Stages) -contains $Stage) { $declared += $n }
    }
    $ordered = @()
    foreach ($n in $script:GateOrder) { if ($declared -contains $n -and $ordered -notcontains $n) { $ordered += $n } }
    foreach ($n in $declared) { if ($ordered -notcontains $n) { $ordered += $n } }
    return @($ordered)
}

function New-SpineGatePlan {
    <#  Every entry of the band, in order, from one input set. The self-test
        builds this plan from a synthetic build and asserts what it threads.

        $In keys: BuildDir, SkillDir, SpineDir, UnitExtract, ResultDir,
        Profile (optional), Register, Cells, Rules (paths that may not exist -
        an existing one is threaded, an absent one is left to the gate's own
        discovery so its refusal, if any, is the gate's), Stage ('3c' when
        absent).

        Stage 3c: the roster above, hand-wired, each entry's header merged in
        by New-GateEntry, plus any further script whose header declares 3c.
        Stage 1 / 2: only header-declared members, each handed New-GenericWant
        and the stage's offer; nothing runs in phase 2 or 3.  #>
    param([Parameter(Mandatory)][hashtable] $In)

    $stage = if ($In.ContainsKey('Stage') -and $In.Stage) { [string]$In.Stage } else { '3c' }
    $scripts = Join-Path $In.SkillDir 'scripts'
    $plan = New-Object System.Collections.Generic.List[object]
    function S { param([string] $n) return (Join-Path $scripts ($n + '.ps1')) }
    function Existing { param([string] $p) if ($p -and (Test-Path -LiteralPath $p)) { return $p } return $null }

    if ($stage -ne '3c') {
        $seedFixturesDir = Join-Path $In.BuildDir 'fixtures'
        foreach ($n in (Get-HeaderDeclaredMember -SkillDir $In.SkillDir -Stage $stage)) {
            $looked = @{}

            #  THE FIXTURES HARNESS IS WIRED THE SAME WAY IN EVERY BAND.
            #
            #  gates.md's stage table declares it a member of 0, 1, 2, 3c, 4
            #  and 7c, and its own header says so too - but only the 3c plan
            #  below hand-wired the three inputs it needs. A seed band handed
            #  it New-GenericWant and -Must BuildDir instead, which is wrong
            #  twice over: it has no -BuildDir want to give (and must not,
            #  because -BuildDir is what starts the plant channel, a background
            #  job that is never a band member), and it never threaded
            #  -StaticOnly, which the gate requires. So the member was REFUSED
            #  by name and the whole Stage 1 band FAILED on it - over a gate
            #  whose two real members had both just passed.
            #
            #  Same want, same must, same reasoning as the 3c entry: a copy
            #  without -StaticOnly is refused, because a full run inside a band
            #  would enumerate the band again.
            if ($n -eq 'Assert-GateFixtures') {
                $wf = [ordered]@{ SkillDir = $In.SkillDir; StaticOnly = $true; ResultDir = $seedFixturesDir }
                $plan.Add((New-GateEntry -Name $n -Title ("GATE FIXTURES, static arms (stage {0} seed arm)" -f $stage) -Script (S $n) -Phase 1 -Want $wf -Must @('SkillDir', 'StaticOnly', 'ResultDir') -Stage $stage -Looked $looked))
                continue
            }

            $w = New-GenericWant -In $In -Name $n -Stage $stage -Looked $looked
            $plan.Add((New-GateEntry -Name $n -Title ("{0} (stage {1} seed arm)" -f $n.ToUpperInvariant(), $stage) -Script (S $n) -Phase 1 -Want $w -Must @('BuildDir') -Stage $stage -Looked $looked))
        }
        return $plan
    }

    $shapeReport = Join-Path $In.BuildDir 'shape-mirror-report.json'
    $covReport   = Join-Path $In.BuildDir 'row-coverage-report.json'
    $mirrorReport = Join-Path $In.BuildDir 'figure-mirror-report.json'
    $dispOut     = Join-Path $In.BuildDir 'grid-disposition.json'
    $sheetOut    = Join-Path $In.BuildDir 'figure-sheet.txt'
    $subDir      = Join-Path $In.ResultDir 'subsections'
    $bandVerdict = if ($In.ContainsKey('BandVerdictPath') -and $In.BandVerdictPath) { [string]$In.BandVerdictPath } else { Join-Path $In.BuildDir '3c-band-verdict.json' }
    $fixturesDir = Join-Path $In.BuildDir 'fixtures'
    #  Paths the roster offers only when present, named here once so a header
    #  that requires one can be refused naming the file it looked for.
    $looked = @{
        Register = $In.Register; RegisterPath = $In.Register; RulesPath = $In.Rules
        Cells = $In.Cells; AssessorCells = $In.Cells; AssessorCellsPath = $In.Cells
        UnitExtract = $In.UnitExtract; Profile = 'an RTO profile pack (-Profile)'; ProfilePath = 'an RTO profile pack (-Profile)'
        MirrorReport = $mirrorReport
    }

    # ---- 1 whole-spine validator
    $w = [ordered]@{ BuildDir = $In.BuildDir; SpineDir = $In.SpineDir; ResultPath = (Join-Path $In.ResultDir 'test-spine.json') }
    $plan.Add((New-GateEntry -Name 'Test-Spine' -Title 'SPINE (Test-Spine, whole-spine mode)' -Script (S 'Test-Spine') -Phase 1 -Want $w -Must @('BuildDir') -Looked $looked -RosterMember))

    # ---- 2 unread fields
    $w = [ordered]@{ BuildDir = $In.BuildDir; SpineDir = $In.SpineDir; SkillDir = $In.SkillDir }
    $plan.Add((New-GateEntry -Name 'Test-SpineRead' -Title 'UNREAD FIELDS (Test-SpineRead)' -Script (S 'Test-SpineRead') -Phase 1 -Want $w -Must @('BuildDir') -Looked $looked -RosterMember))

    # ---- 3 figure registry, SOURCE arm only. No -DocText on purpose: the
    #      rendered arm needs the extracts and belongs to Run-Gates.
    $w = [ordered]@{ BuildDir = $In.BuildDir }
    $plan.Add((New-GateEntry -Name 'Test-FigureConsistency' -Title 'FIGURE REGISTRY - declared sources (Test-FigureConsistency)' -Script (S 'Test-FigureConsistency') -Phase 1 -Want $w -Must @('BuildDir') -Looked $looked -RosterMember))

    # ---- 4 table / answer-grid mirror. Its report is produced HERE, for the
    #      disposition in phase 2, at the band's default path - and a copy of
    #      the gate that cannot take -ReportPath writes there anyway, so the
    #      -Produces check holds either way.
    $w = [ordered]@{ BuildDir = $In.BuildDir; SpineDir = $In.SpineDir; ReportPath = $mirrorReport }
    if (Existing $In.Register) { $w['RegisterPath'] = $In.Register }
    $plan.Add((New-GateEntry -Name 'Check-FigureMirror' -Title 'ANSWER-GRID MIRROR (Check-FigureMirror)' -Script (S 'Check-FigureMirror') -Phase 1 -Want $w -Must @('BuildDir') -Produces $mirrorReport -Looked $looked -RosterMember))

    # ---- 5 assessor-only leakage, whole spine, unit extract excluded
    if (-not $In.UnitExtract -or -not (Test-Path -LiteralPath $In.UnitExtract)) {
        $plan.Add((New-GateEntry -Name 'Check-FigureLeakage' -Title 'ASSESSOR LEAKAGE (Check-FigureLeakage)' -Script (S 'Check-FigureLeakage') -Phase 1 -Looked $looked -RosterMember `
                   -Refused ("REFUSED: no unit_extract.md (looked for {0}). An assessor guide quotes the unit; without the unit corpus every unit line the guide teaches is misreported as assessor-only." -f $In.UnitExtract)))
    }
    else {
        $w = [ordered]@{ BuildDir = $In.BuildDir; ExcludeText = @($In.UnitExtract); SpineDir = $In.SpineDir; ReportPath = (Join-Path $In.ResultDir 'leakage_report.txt') }
        $plan.Add((New-GateEntry -Name 'Check-FigureLeakage' -Title 'ASSESSOR LEAKAGE (Check-FigureLeakage, whole spine)' -Script (S 'Check-FigureLeakage') -Phase 1 -Want $w -Must @('BuildDir', 'ExcludeText') -Looked $looked -RosterMember))
    }

    # ---- 6 prompt lint; the profile comes from the contract's brand unless given
    $w = [ordered]@{ BuildDir = $In.BuildDir; SpineDir = $In.SpineDir; SkillDir = $In.SkillDir }
    if ($In.Profile) { $w['Profile'] = $In.Profile }
    $plan.Add((New-GateEntry -Name 'Assert-PromptLint' -Title 'PROMPT LINT (Assert-PromptLint)' -Script (S 'Assert-PromptLint') -Phase 1 -Want $w -Must @('BuildDir') -Looked $looked -RosterMember))

    # ---- 7 the in-loop wrapper over every sub-section, results OUTSIDE spine\
    $w = [ordered]@{ All = $true; BuildDir = $In.BuildDir; ResultDir = $subDir; ResultPath = (Join-Path $In.ResultDir 'test-subsection-all.json'); UnitExtract = $In.UnitExtract }
    if (Existing $In.Register) { $w['RegisterPath'] = $In.Register }
    if (Existing $In.Cells)    { $w['AssessorCellsPath'] = $In.Cells }
    $plan.Add((New-GateEntry -Name 'Test-SubSection' -Title 'EVERY SUB-SECTION (Test-SubSection -All)' -Script (S 'Test-SubSection') -Phase 1 -Want $w -Must @('All', 'BuildDir', 'ResultDir') -Looked $looked -RosterMember))

    # ---- 8 prose shape mirror
    $w = [ordered]@{ BuildDir = $In.BuildDir; SpineDir = $In.SpineDir; ReportPath = $shapeReport }
    $plan.Add((New-GateEntry -Name 'Check-ShapeMirror' -Title 'SHAPE MIRROR (Check-ShapeMirror, whole spine)' -Script (S 'Check-ShapeMirror') -Phase 1 -Want $w -Must @('BuildDir', 'SpineDir') -Produces $shapeReport -Looked $looked -RosterMember))

    # ---- 9 row coverage, whole-spine floor
    $w = [ordered]@{ BuildDir = $In.BuildDir; Whole = $true; SpineDir = $In.SpineDir; ReportPath = $covReport; UnitExtract = $In.UnitExtract }
    $plan.Add((New-GateEntry -Name 'Check-RowCoverage' -Title 'ROW COVERAGE (Check-RowCoverage -Whole)' -Script (S 'Check-RowCoverage') -Phase 1 -Want $w -Must @('BuildDir', 'Whole') -Produces $covReport -Looked $looked -RosterMember))

    # ---- 10 one verdict per grid, after 4, 8 and 9 have joined. The mirror
    #      report is threaded unconditionally: phase 1 produces it this run,
    #      and the mirror member fails by -Produces if it did not.
    #  -NotBefore is this run's start: a report generated before it belongs to
    #  an earlier round, and disposing a grid against one is how every 4/7c
    #  verdict on the reference build came to describe the round before it.
    $notBefore = $(if ($In.ContainsKey('NotBefore') -and $In.NotBefore) { [string]$In.NotBefore } else { (Get-Date).ToUniversalTime().ToString('o') })
    $w = [ordered]@{ BuildDir = $In.BuildDir; ShapeReport = $shapeReport; CoverageReport = $covReport; MirrorReport = $mirrorReport; OutPath = $dispOut; NotBefore = $notBefore }
    if (Existing $In.Rules)     { $w['RulesPath'] = $In.Rules }
    if (Existing $In.Register)  { $w['Register'] = $In.Register }
    $plan.Add((New-GateEntry -Name 'Test-GridDisposition' -Title 'GRID DISPOSITION (Test-GridDisposition)' -Script (S 'Test-GridDisposition') -Phase 2 -Want $w -Must @('BuildDir', 'ShapeReport', 'CoverageReport', 'NotBefore') -Produces $dispOut -Looked $looked -RosterMember))

    # ---- 10b the gates that landed 4 Sep 2026. Each reads only the spine, the
    #      corpus, the register and the registry, so each belongs in phase 1
    #      with the rest of the band. -Profile is threaded from this runner's
    #      OWN discovery: three of them refuse rather than guess a profile, and
    #      a gate refusing in a real run for want of a parameter the runner
    #      already resolved is a self-inflicted gap.
    $late = @(
        @{ N = 'Assert-FigureCoverage';       T = 'UNREGISTERED FIGURES (Assert-FigureCoverage)';        M = @('BuildDir') },
        @{ N = 'Assert-Provenance';           T = 'PROVENANCE AND ATTRIBUTION (Assert-Provenance)';      M = @('BuildDir') },
        @{ N = 'Assert-WithholdRegister';     T = 'WITHHOLD REGISTER, build-wide (Assert-WithholdRegister)'; M = @('BuildDir') },
        @{ N = 'Assert-SpineCounts';          T = 'SPINE-MEASURED COUNTS (Assert-SpineCounts)';          M = @('BuildDir') },
        @{ N = 'Assert-Terminology';          T = 'TERMINOLOGY (Assert-Terminology)';                    M = @('BuildDir') },
        @{ N = 'Assert-CitationConsistency';  T = 'CITATION CONSISTENCY (Assert-CitationConsistency)';   M = @('BuildDir') },
        @{ N = 'Assert-ScenarioClock';        T = 'SCENARIO CLOCK (Assert-ScenarioClock)';               M = @('BuildDir') },
        @{ N = 'Assert-IdentifierNamespace';  T = 'IDENTIFIER NAMESPACE (Assert-IdentifierNamespace)';   M = @('BuildDir') },
        @{ N = 'Assert-SpecRenderable';       T = 'SPEC RENDERABILITY (Assert-SpecRenderable)';          M = @('BuildDir') },
        @{ N = 'Assert-DeckParity';           T = 'DECK PARITY, per-surface (Assert-DeckParity)';        M = @('BuildDir') }
    )
    foreach ($g in $late) {
        $w = [ordered]@{ BuildDir = $In.BuildDir; SpineDir = $In.SpineDir; SkillDir = $In.SkillDir }
        $w['ReportPath'] = (Join-Path $In.ResultDir ($g.N + '.json'))
        if ($In.Profile)            { $w['Profile'] = $In.Profile; $w['ProfilePath'] = $In.Profile }
        if (Existing $In.Register)  { $w['Register'] = $In.Register; $w['RegisterPath'] = $In.Register }
        if (Existing $In.Rules)     { $w['RulesPath'] = $In.Rules }
        if (Existing $In.Cells)     { $w['AssessorCells'] = $In.Cells; $w['AssessorCellsPath'] = $In.Cells }
        if ($In.UnitExtract -and (Test-Path -LiteralPath $In.UnitExtract)) { $w['UnitExtract'] = $In.UnitExtract }
        $plan.Add((New-GateEntry -Name $g.N -Title $g.T -Script (S $g.N) -Phase 1 -Want $w -Must $g.M -Looked $looked -RosterMember))
    }

    # ---- 10c the planned-visual count, derived from the contract (P0-11).
    #      The script is being written beside this runner; absent at run time
    #      it is REFUSED by name through New-GateEntry, never skipped.
    $w = [ordered]@{ BuildDir = $In.BuildDir; SpineDir = $In.SpineDir; ReportPath = (Join-Path $In.ResultDir 'Assert-GateVisualCount.json') }
    $plan.Add((New-GateEntry -Name 'Assert-GateVisualCount' -Title 'PLANNED VISUAL COUNT, cover included (Assert-GateVisualCount)' -Script (S 'Assert-GateVisualCount') -Phase 1 -Want $w -Must @('BuildDir') -Looked $looked -RosterMember))

    # ---- 10d the fixtures harness's static arms, in every band (P0-13). No
    #      -BuildDir on purpose: that starts the plant channel, which is a
    #      background job keyed on the scripts hash, not a band member. A copy
    #      without -StaticOnly is REFUSED by name - a full run inside the band
    #      would enumerate the band again.
    $w = [ordered]@{ SkillDir = $In.SkillDir; StaticOnly = $true; ResultDir = $fixturesDir }
    $plan.Add((New-GateEntry -Name 'Assert-GateFixtures' -Title 'GATE FIXTURES, static arms (Assert-GateFixtures -StaticOnly)' -Script (S 'Assert-GateFixtures') -Phase 1 -Want $w -Must @('SkillDir', 'StaticOnly', 'ResultDir') -Looked $looked -RosterMember))

    # ---- 10e any further script whose GATE header declares 3c and that the
    #      roster does not know. Header-declared, so it runs; generic inputs.
    $known = @($plan | ForEach-Object { $_.Name }) + @('New-FigureSheet')
    foreach ($n in (Get-HeaderDeclaredMember -SkillDir $In.SkillDir -Stage '3c')) {
        if ($known -contains $n) { continue }
        $lk = @{}
        $w = New-GenericWant -In $In -Name $n -Stage '3c' -Looked $lk
        $plan.Add((New-GateEntry -Name $n -Title ("{0} (header-declared 3c member)" -f $n.ToUpperInvariant()) -Script (S $n) -Phase 1 -Want $w -Must @('BuildDir') -Stage '3c' -Looked $lk))
    }

    # ---- 11 the figure sheet, last, green band only, handed the interim band
    #      verdict so it can refuse the cut itself. -BandResults is a MUST: a
    #      copy that cannot take it would cut a sheet from any spine.
    $w = [ordered]@{ BuildDir = $In.BuildDir; SpineDir = $In.SpineDir; OutPath = $sheetOut; BandResults = $bandVerdict }
    $plan.Add((New-GateEntry -Name 'New-FigureSheet' -Title 'FIGURE SHEET (New-FigureSheet)' -Script (S 'New-FigureSheet') -Phase 3 -Want $w -Must @('BuildDir', 'BandResults') -Produces $sheetOut -Looked $looked -RosterMember))

    return $plan
}

function Select-PlanByOnly {
    <#  Filter a plan to the -Only names. An unknown name throws with the valid
        list, so a typo cannot silently run nothing. The figure sheet is never
        selected: a partial run cannot cut it.  #>
    param([Parameter(Mandatory)] $Plan, [string[]] $Only)
    if (-not $Only -or @($Only).Count -eq 0) { return @($Plan) }
    $wanted = @()
    foreach ($o in $Only) {
        foreach ($piece in ([string]$o -split ',')) {
            $n = $piece.Trim()
            if (-not $n) { continue }
            $n = $n -replace '(?i)\.ps1$', ''
            $match = @($Plan | Where-Object { $_.Name -ieq $n })
            if ($match.Count -ne 1) { throw ("-Only '{0}' is not a gate of this band. Gates: {1}" -f $n, (($Plan | ForEach-Object { $_.Name }) -join ', ')) }
            if ($match[0].Name -eq 'New-FigureSheet') { throw '-Only cannot select New-FigureSheet: the sheet is cut only by a full band that passed.' }
            if ($wanted -notcontains $match[0].Name) { $wanted += $match[0].Name }
        }
    }
    return @($Plan | Where-Object { $wanted -contains $_.Name })
}

function Format-ArgValue {
    param($v)
    if ($null -eq $v) { return '(null)' }
    if ($v -is [bool] -or $v -is [switch]) { return ([bool]$v).ToString() }
    if ($v -is [hashtable]) { return ("{0} entr(ies)" -f $v.Count) }
    if ($v -is [string]) {
        if ($v -match '^([A-Za-z]:|\\\\)[\\/]' -and $v.Length -gt 40) { return (Split-Path $v -Leaf) }
        if ($v.Length -gt 60) { return ($v.Substring(0, 57) + '...') }
        return $v
    }
    if ($v -is [System.Collections.IEnumerable]) {
        $items = @($v)
        if ($items.Count -le 2 -and @($items | Where-Object { $_ -is [string] }).Count -eq $items.Count) {
            return (($items | ForEach-Object { Format-ArgValue $_ }) -join ', ')
        }
        return ("{0} item(s)" -f $items.Count)
    }
    return [string]$v
}

function Get-ThreadedParameterLine {
    <# One line per gate: "-Name=value -Name=value", plus what was dropped. #>
    param([Parameter(Mandatory)] $Plan)
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($e in $Plan) {
        if ($e.Refused) { $out.Add(("{0}: NOT RUN - {1}" -f $e.Name, $e.Refused)); continue }
        $parts = @()
        foreach ($k in $e.Args.Keys) { $parts += ("-{0}={1}" -f $k, (Format-ArgValue $e.Args[$k])) }
        $line = "{0}: {1}" -f $e.Name, ($parts -join ' ')
        $dropped = @()
        if ($null -ne $e.Dropped) { $dropped = @($e.Dropped) }
        if ($dropped.Count -gt 0) { $line += ("   [not accepted by this copy, dropped: {0}]" -f ($dropped -join ', ')) }
        $out.Add($line)
    }
    return $out
}

# ---------------------------------------------------------------------------
# 3. The job body - self-contained, because a job inherits no function.
#    Dot-sources Lib-Resolve.ps1 and calls the gate by path with &, so it runs
#    under a Restricted execution policy exactly as Run-Gates does.
# ---------------------------------------------------------------------------

$script:GateJobBody = {
    param($Entry, $SkillDir)
    $ErrorActionPreference = 'Stop'
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $startedAt = (Get-Date).ToUniversalTime().ToString('o')
    $lines = New-Object System.Collections.Generic.List[string]
    $ok = $false
    $err = ''
    $code = -1

    function Take { param($stream) foreach ($o in @($stream)) { if ($o -is [System.Management.Automation.InformationRecord]) { $lines.Add([string]$o.MessageData) } elseif ($o -is [string]) { $lines.Add($o) } elseif ($null -ne $o) { $lines.Add([string]$o) } } }

    try {
        . (Join-Path $SkillDir 'scripts\Lib-Resolve.ps1')
        $a = @{}
        foreach ($k in $Entry.Args.Keys) { $a[$k] = $Entry.Args[$k] }
        $LASTEXITCODE = 0
        Take (& $Entry.Script @a 6>&1)
        $code = $LASTEXITCODE
        if ($null -eq $code) { $code = 0 }
        $ok = ($code -eq 0)
        if ($Entry.Produces) {
            if (-not (Test-Path -LiteralPath $Entry.Produces)) { $ok = $false; $lines.Add("X expected output not written: $($Entry.Produces)") }
        }
        if (-not $ok -and $code -ne 0) { $lines.Add("exit code $code") }
    }
    catch {
        $err = $_.Exception.Message
        $ok = $false
    }
    [pscustomobject]@{ Name = $Entry.Name; Ok = $ok; Text = ($lines -join "`n"); Error = $err; ExitCode = $code; Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1); StartedAt = $startedAt; FinishedAt = (Get-Date).ToUniversalTime().ToString('o') }
}

function New-GateResult {
    <#  One member's outcome. StartedAt/RanAt are UTC ISO strings: RanAt is
        when the member finished (or, for a refusal, when the refusal was
        recorded), so every member carries a time whatever its verdict.
        Arms/ArmLines/ArmsBlockingNotRun/ArmProblems are filled by the
        collector from the member's ARMS line(s).  #>
    param([string] $Name, [bool] $Ok, [string] $Text, [string] $Error, $ExitCode, [double] $Seconds, [double] $GateSeconds, [bool] $Refused, [string] $Reason, [bool] $Removed = $true, [string] $StartedAt = '', [string] $RanAt = '')
    if (-not $RanAt) { $RanAt = Get-UtcNow }
    return [pscustomobject]@{
        Name = $Name; Ok = $Ok; Text = $Text; Error = $Error; ExitCode = $ExitCode
        Seconds = [math]::Round($Seconds, 1); GateSeconds = [math]::Round($GateSeconds, 1)
        Refused = $Refused; Reason = $Reason; Removed = $Removed
        StartedAt = $StartedAt; RanAt = $RanAt
        Arms = @(); ArmLines = @(); ArmsBlockingNotRun = @(); ArmProblems = @()
    }
}

function Add-ArmRosterToResult {
    <#  Read the member's ARMS line(s) into its result. A BLOCKING arm in
        state not-run makes the member FAIL with 'arm not run: <name>' -
        appended to any reason it already has, never replacing it.  #>
    param([Parameter(Mandatory)] $Result, [string] $Evidence = '3c')
    $ro = ConvertFrom-ArmRosterText -Text $Result.Text -Evidence $Evidence
    $Result.Arms = @($ro.Arms)
    $Result.ArmLines = @($ro.Lines)
    #  TWO statements, never `$x = if (..) { @(..) }`: a one-element array on
    #  the output of an if unrolls to the element, and this one is written
    #  straight back onto the result, where the shape has to stay a list.
    $blockingNotRun = @()
    if ($null -ne $ro.BlockingNotRun) { $blockingNotRun = @($ro.BlockingNotRun) }
    $Result.ArmsBlockingNotRun = $blockingNotRun
    $Result.ArmProblems = @($ro.Problems)
    if ($blockingNotRun.Count -gt 0) {
        $why = ("arm not run: {0}" -f ($blockingNotRun -join ', '))
        $Result.Ok = $false
        $Result.Reason = $(if ($Result.Reason) { $Result.Reason + '; ' + $why } else { $why })
    }
    return $Result
}

function Invoke-SpineGatePlan {
    <#  Run every runnable entry of a plan as a Start-Job under a concurrency
        cap and a per-job deadline, and return one result per entry - refused
        entries included, as failures. A job past its deadline is stopped AND
        removed, and the result records that it was. Seconds is wall time from
        Start-Job to join (process start included); GateSeconds is the gate's
        own stopwatch inside the child.  #>
    param(
        [Parameter(Mandatory)] $Plan,
        [Parameter(Mandatory)][string] $SkillDir,
        [int] $TimeoutSeconds = 600,
        [int] $MaxJobs = 8,
        [switch] $Serial,
        #  Label every parsed arm ('seed' for a stage 1/2 run, '3c' for the band).
        [string] $Evidence = '3c'
    )
    if ($Serial -or $MaxJobs -lt 1) { $MaxJobs = 1 }
    $results = @{}
    $pending = New-Object System.Collections.Generic.Queue[object]
    foreach ($e in $Plan) {
        if ($e.Refused) {
            $results[$e.Name] = New-GateResult -Name $e.Name -Ok $false -Text '' -Error $e.Refused -ExitCode $null -Seconds 0 -GateSeconds 0 -Refused $true -Reason $e.Refused
            continue
        }
        $pending.Enqueue($e)
    }
    $running = @{}

    function Collect-Job {
        param($Slot, [string] $Why)
        $e = $Slot.Entry
        $j = $Slot.Job
        $wall = ((Get-Date) - $Slot.Started).TotalSeconds
        $startedAt = $Slot.Started.ToUniversalTime().ToString('o')
        $r = $null
        if ($Why) {
            $errText = ''
            if ($j.State -eq 'Running') { Stop-Job -Job $j -ErrorAction SilentlyContinue }
            try { $reason = $j.ChildJobs[0].JobStateInfo.Reason; if ($reason) { $errText = [string]$reason.Message } } catch { }
            if (-not $errText) { try { $null = Receive-Job -Job $j -ErrorAction Stop } catch { $errText = $_.Exception.Message } }
            $r = New-GateResult -Name $e.Name -Ok $false -Text $errText -Error $Why -ExitCode $null -Seconds $wall -GateSeconds 0 -Refused $false -Reason $Why -StartedAt $startedAt
        }
        elseif ($j.State -eq 'Completed') {
            $out = Receive-Job -Job $j -ErrorAction SilentlyContinue
            $out = @($out | Where-Object { $_ -and ($_.PSObject.Properties.Name -contains 'Ok') } | Select-Object -Last 1)
            if ($out.Count -eq 1) {
                $o = $out[0]
                $reason = ''
                if (-not $o.Ok) { $reason = if ($o.Error) { "threw: " + [string]$o.Error } else { "exit code " + [string]$o.ExitCode } }
                $ranAt = ''
                if ($o.PSObject.Properties.Name -contains 'FinishedAt') { $ranAt = [string]$o.FinishedAt }
                $r = New-GateResult -Name $e.Name -Ok ([bool]$o.Ok) -Text ([string]$o.Text) -Error ([string]$o.Error) -ExitCode $o.ExitCode -Seconds $wall -GateSeconds ([double]$o.Seconds) -Refused $false -Reason $reason -StartedAt $startedAt -RanAt $ranAt
                $r = Add-ArmRosterToResult -Result $r -Evidence $Evidence
            }
            else {
                $r = New-GateResult -Name $e.Name -Ok $false -Text '' -Error 'the job returned no result object' -ExitCode $null -Seconds $wall -GateSeconds 0 -Refused $false -Reason 'the job returned no result object' -StartedAt $startedAt
            }
        }
        else {
            $why = "job ended in state $($j.State)"
            $errText = ''
            try { $reason = $j.ChildJobs[0].JobStateInfo.Reason; if ($reason) { $errText = [string]$reason.Message } } catch { }
            if (-not $errText) { try { $null = Receive-Job -Job $j -ErrorAction Stop } catch { $errText = $_.Exception.Message } }
            $r = New-GateResult -Name $e.Name -Ok $false -Text $errText -Error $why -ExitCode $null -Seconds $wall -GateSeconds 0 -Refused $false -Reason $why -StartedAt $startedAt
        }
        $id = $j.Id
        Remove-Job -Job $j -Force -ErrorAction SilentlyContinue
        $r.Removed = ($null -eq (Get-Job -Id $id -ErrorAction SilentlyContinue))
        return $r
    }

    while ($pending.Count -gt 0 -or $running.Count -gt 0) {
        while ($pending.Count -gt 0 -and $running.Count -lt $MaxJobs) {
            $e = $pending.Dequeue()
            $j = Start-Job -ScriptBlock $script:GateJobBody -ArgumentList $e, $SkillDir
            $running[$e.Name] = @{ Job = $j; Entry = $e; Started = (Get-Date) }
        }
        if ($running.Count -eq 0) { continue }
        $null = Wait-Job -Job @($running.Values | ForEach-Object { $_.Job }) -Any -Timeout 1
        foreach ($name in @($running.Keys)) {
            $slot = $running[$name]
            $j = $slot.Job
            $elapsed = ((Get-Date) - $slot.Started).TotalSeconds
            if ($j.State -notin @('Running', 'NotStarted')) {
                $results[$name] = Collect-Job -Slot $slot -Why ''
                $running.Remove($name)
            }
            elseif ($elapsed -gt $TimeoutSeconds) {
                $results[$name] = Collect-Job -Slot $slot -Why ("timed out after {0} s - job stopped and removed" -f $TimeoutSeconds)
                $running.Remove($name)
            }
        }
    }

    $ordered = New-Object System.Collections.Generic.List[object]
    foreach ($e in $Plan) { $ordered.Add($results[$e.Name]) }
    return $ordered
}

# ---------------------------------------------------------------------------
# 4. Reporting helpers
# ---------------------------------------------------------------------------

function Write-GateText {
    param([string] $Text)
    if (-not $Text) { return }
    foreach ($ln in ($Text -split "`n")) {
        $t = $ln.TrimEnd()
        if (-not $t) { continue }
        $col = 'Gray'
        if     ($t -match '^\s*X\s' -or $t -match '^\s*FAIL' -or $t -match '\sX\s+\S') { $col = 'Red' }
        elseif ($t -match '^\s*(PASS|ALL GATES PASS)\b' -or $t -match '^\s*no \w') { $col = 'Green' }
        elseif ($t -match '^\s*(WARN|~|!|NOT|PARTIAL)' -or $t -match 'NOT RUN') { $col = 'Yellow' }
        Write-Host ("    " + $t) -ForegroundColor $col
    }
}

function Get-SummaryLine {
    <#  The lines of a gate's output that carry a verdict or a finding marker,
        plus its last three lines, capped. The full text goes to the log file.  #>
    param([string] $Text, [int] $Cap = 80)
    if (-not $Text) { return @() }
    $all = @($Text -split "`n" | ForEach-Object { $_.TrimEnd() } | Where-Object { $_ })
    $marked = @($all | Where-Object { $_ -match '^\s*(X|FAIL|PASS|REFUSED|NOT RUN|~|!)\b' -or $_ -match '^\s*X\s' -or $_ -match '(?i)\bexit code\b' -or $_ -match '(?i)\b(\d+ of \d+|every one exit 0|files? FAIL)\b' })
    $tail = @($all | Select-Object -Last 3)
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($l in @($marked) + @($tail)) { if (-not $out.Contains($l)) { $out.Add($l) } }
    if ($out.Count -gt $Cap) { $kept = @($out | Select-Object -First ($Cap - 1)); $kept += ("... {0} more line(s) in the log" -f ($out.Count - $Cap + 1)); return $kept }
    return @($out)
}

function Get-SubSectionVerdict {
    <#  The per-file verdicts Test-SubSection wrote, read BY CONTRACT from its
        gate.json files, never from its console text.  #>
    param([string] $Dir)
    $rows = @()
    if (-not $Dir -or -not (Test-Path -LiteralPath $Dir)) { return $rows }
    foreach ($f in (Get-ChildItem -LiteralPath $Dir -Filter '*.gate.json' -File | Sort-Object Name)) {
        $j = $null
        try { $j = Read-JsonFile -Path $f.FullName } catch { }
        if ($null -eq $j) { $rows += [pscustomobject]@{ file = $f.Name; verdict = 'UNREADABLE'; blocks = 0; arms = '' }; continue }
        #  @() again on the call: a one-element array returned from a function
        #  unrolls to its element, whose .Count is empty in PS 5.1.
        $blocks = @()
        if (HasProp $j 'blocks') { $blocks = @(AsArr $j.blocks) }
        $arms = @($blocks | ForEach-Object { if (HasProp $_ 'arm') { [string]$_.arm } } | Where-Object { $_ } | Sort-Object -Unique) -join ', '
        $rows += [pscustomobject]@{ file = ($f.Name -replace '\.gate\.json$', ''); verdict = $(if (HasProp $j 'verdict') { [string]$j.verdict } else { 'NO VERDICT' }); blocks = $blocks.Count; arms = $arms }
    }
    return $rows
}

function Test-ResultIsGateDefect {
    <#  Is this member's outcome a GATE DEFECT rather than a content failure?

        EXIT 4 IS THE TOOLCHAIN'S THIS-GATE-IS-BROKEN CODE. A gate exits 4 when
        it cannot re-find one of its own anchors at the token boundary it
        declared (Lib-GateCommon: New-GateFinding / Test-GateFindingAnchor), so
        it did NOT find a defect in the content - it found a defect in its own
        check-set. Every traceable blocking finding on the reference build was
        manufactured that way, and three remediation rounds were spent editing a
        document that was right, because nothing downstream could tell the two
        apart. Here they are told apart mechanically: the member goes into
        defective[], never into failed[].

        A refusal (exit 2), a timeout and a job that died carry no exit code of
        their own and are NOT this - they are ordinary failures with reasons.  #>
    param($Result)
    if ($null -eq $Result) { return $false }
    if (-not (HasProp $Result 'ExitCode')) { return $false }
    if ($null -eq $Result.ExitCode) { return $false }
    if ((HasProp $Result 'Refused') -and $Result.Refused) { return $false }
    return ("$($Result.ExitCode)".Trim() -eq '4')
}

function Get-GateDefectiveName {
    <# The names of every member that exited 4 - the GATE-DEFECT set. #>
    param($Results)
    #  $Results is PIPED, never wrapped in @(): on PS 5.1 here, @() over a
    #  POPULATED System.Collections.Generic.List[object] throws 'Argument types
    #  do not match' (an ArrayList and an empty List are fine), and the
    #  runner's own result set is exactly that List - so the wrapped form broke
    #  the band at the join while every unit test over pscustomobject arrays
    #  passed. A pipeline enumerates the List, tolerates $null and treats a
    #  lone object as one item.
    if ($null -eq $Results) { return @() }
    return @($Results | Where-Object { Test-ResultIsGateDefect -Result $_ } | ForEach-Object { [string]$_.Name })
}

function Test-SheetMayRun {
    <#  The sheet runs only when every result so far passed, no member is
        GATE-DEFECT, the run is the whole band, and the spine is the one those
        results describe. A refused gate, an unavailable gate or a timeout is a
        failure here like anywhere else; a spine that moved between the start of
        the band and the join REFUSES the cut naming both fingerprints - the
        verdicts describe a spine that no longer exists.

        A GATE-DEFECT member is named as one, NOT as a content failure: a gate
        that could not re-find its own anchor judged nothing, so nothing here
        says the figures are what the document will carry.  #>
    param([Parameter(Mandatory)] $Results, [bool] $Partial, [string] $FingerprintBefore = '', [string] $FingerprintNow = '')
    if ($Partial) { return 'NOT RUN - a partial run (-Only) never cuts the figure sheet' }
    $defective = @(Get-GateDefectiveName -Results $Results)
    if ($defective.Count -gt 0) {
        return ("NOT RUN - a sheet is never cut while a member is GATE-DEFECT ({0}): a gate that cannot re-find its own anchor examined a defect it invented, so the band's verdict on this spine cannot be believed. Fix the gate and re-run; do not edit the pack against its findings." -f ($defective -join ', '))
    }
    $failed = @($Results | Where-Object { -not $_.Ok } | ForEach-Object { $_.Name } | Where-Object { $defective -notcontains $_ })
    if ($failed.Count -gt 0) { return ("NOT RUN - a sheet is never cut from a spine that failed ({0})" -f ($failed -join ', ')) }
    if ($FingerprintBefore -and $FingerprintNow -and $FingerprintBefore -ne $FingerprintNow) {
        return ("REFUSED - the spine moved during the band (fingerprint at start {0}, at the join {1}); every verdict above describes a spine that no longer exists, and a sheet is never cut from one. Re-run the band." -f $FingerprintBefore, $FingerprintNow)
    }
    return ''
}

function Write-BandVerdictFile {
    <#  The interim verdict of phases 1-2, written BEFORE phase 3 so the sheet
        is cut under a verdict that exists on disk and can be stamped. The
        fingerprint is recomputed at the join, not copied from the start.  #>
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)] $Results, [Parameter(Mandatory)] $Entries, [bool] $Partial, [string] $FingerprintBefore, [string] $FingerprintNow, [string] $BuildDir, [string] $Stage = '3c')
    $defective = @(Get-GateDefectiveName -Results $Results)
    $failed = @($Results | Where-Object { -not $_.Ok } | ForEach-Object { $_.Name } | Where-Object { $defective -notcontains $_ })
    $moved = ($FingerprintBefore -and $FingerprintNow -and $FingerprintBefore -ne $FingerprintNow)
    #  A GATE-DEFECT band is not a PASS and it is not a content FAIL either. It
    #  carries its own verdict so that nothing downstream can read it as either
    #  one: not a green band, and not a document to remediate.
    $verdict = 'PASS'
    if ($failed.Count -gt 0 -or $moved) { $verdict = 'FAIL' }
    elseif ($defective.Count -gt 0) { $verdict = 'GATE-DEFECT' }
    $members = @()
    foreach ($e in $Entries) {
        $r = @($Results | Where-Object { $_.Name -eq $e.Name })[0]
        if ($null -eq $r) { continue }
        $v = if ($r.Ok) { 'PASS' } elseif (Test-ResultIsGateDefect -Result $r) { 'GATE-DEFECT' } elseif ($r.Refused) { 'REFUSED' } else { 'FAIL' }
        $members += [pscustomobject]@{ name = $e.Name; phase = $e.Phase; verdict = $v; exitCode = $r.ExitCode; ranAt = $r.RanAt }
    }
    if ($moved) { $failed += 'spine-changed-during-run' }
    $body = [ordered]@{
        runner = 'Run-SpineGates'; stage = $Stage; kind = 'band-verdict'
        ranAt = (Get-UtcNow); buildDir = $BuildDir
        spineFingerprint = $FingerprintNow; spineFingerprintAtStart = $FingerprintBefore; spineMovedDuringBand = [bool]$moved
        verdict = $verdict; exitCode = $(if ($verdict -eq 'PASS') { 0 } else { 1 })
        failed = @($failed); defective = @($defective); partial = [bool]$Partial
        phases = @(1, 2); members = @($members)
    }
    Write-JsonFile -Path $Path -Body ([pscustomobject]$body)
    return [pscustomobject]$body
}

function Get-FigureSheetState {
    <#  The figureSheet field, DERIVED: from the phase-3 note when the cut was
        not attempted, otherwise from the job result plus Test-Path on the
        sheet. 'cut' is said only when the job passed AND the sheet exists.  #>
    param([string] $Note, $Result, [string] $SheetPath, [bool] $Planned)
    if (-not $Planned) { return 'not in this run' }
    if ($Note) { return $Note }
    if ($null -eq $Result) { return ("FAIL - no phase-3 result for the sheet; {0}" -f $(if ($SheetPath -and (Test-Path -LiteralPath $SheetPath)) { 'a figure-sheet.txt from an earlier cut is on disk' } else { 'no sheet on disk' })) }
    $present = ($SheetPath -and (Test-Path -LiteralPath $SheetPath))
    if ($Result.Ok -and $present) { return 'cut' }
    if ($Result.Ok -and -not $present) { return ("FAIL - exit 0 but no sheet at {0}" -f $SheetPath) }
    $code = if ($null -eq $Result.ExitCode) { 'none' } else { [string]$Result.ExitCode }
    return ("FAIL - exit {0}: {1}; {2}" -f $code, $(if ($Result.Reason) { $Result.Reason } else { 'the cut failed' }), $(if ($present) { 'a figure-sheet.txt is on disk - from an EARLIER cut, not this run; the ledger will test its stamp' } else { 'no sheet on disk' }))
}

# ---------------------------------------------------------------------------
# 5. Self-test - no build, no Office, no API
# ---------------------------------------------------------------------------

if ($SelfTest) {
    $pass = 0; $fail = 0
    function Ok  ($m) { $script:pass++; Write-Host "  PASS  $m" -ForegroundColor Green }
    function Bad ($m) { $script:fail++; Write-Host "  FAIL  $m" -ForegroundColor Red }

    Write-Host ''
    Write-Host 'Run-SpineGates self-test' -ForegroundColor Cyan
    $self = $PSCommandPath
    if (-not $self) { $self = $MyInvocation.MyCommand.Path }
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('rsg_selftest_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $build = Join-Path $tmp 'build'
    $spine = Join-Path $build 'spine'
    New-Item -ItemType Directory -Force -Path $spine | Out-Null
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $bom  = New-Object System.Text.UTF8Encoding($true)
    try {
        # ---- a synthetic build: a spine of two files, a unit extract
        [System.IO.File]::WriteAllText((Join-Path $spine 't1_1.1.json'), '{"pc":"1.1"}', $utf8)
        [System.IO.File]::WriteAllText((Join-Path $spine 't1_topic.json'), '{"topic":1}', $utf8)
        $unitX = Join-Path $build 'unit_extract.md'
        [System.IO.File]::WriteAllText($unitX, '# Performance Evidence', $utf8)
        $resultDir = Join-Path $build '3c'

        $fp1 = Get-SpineFingerprint -BuildDir $build -Quiet
        [System.IO.File]::WriteAllText((Join-Path $spine 't1_1.1.json'), '{"pc":"1.1","edited":true}', $utf8)
        $fp2 = Get-SpineFingerprint -BuildDir $build -Quiet
        if ($fp1 -and $fp2 -and $fp1 -ne $fp2 -and $fp1 -match '^v2:[0-9a-f]{32}$') { Ok 'the spine fingerprint is v2-prefixed, content-derived and changes when a spine file is edited' } else { Bad "fingerprint: '$fp1' -> '$fp2'" }

        $in = @{
            BuildDir = $build; SkillDir = $SkillDir; SpineDir = $spine; UnitExtract = $unitX; ResultDir = $resultDir; Profile = ''; Stage = '3c'
            Register = (Join-Path $build 'withhold-register.json'); Cells = (Join-Path $build 'assessor-cells.json'); Rules = (Join-Path $build 'figures.json')
        }
        $plan = @(New-SpineGatePlan -In $in)
        $names = @($plan | ForEach-Object { $_.Name })
        $missingFromPlan = @($script:GateOrder | Where-Object { $names -notcontains $_ })
        $extras = @($names | Where-Object { $script:GateOrder -notcontains $_ })
        if ($missingFromPlan.Count -eq 0 -and $names[-1] -eq 'New-FigureSheet') { Ok ('the plan carries every gate of the roster ({0}), the sheet last{1}' -f $script:GateOrder.Count, $(if ($extras.Count) { '; header-declared extras on this machine: ' + ($extras -join ', ') } else { '' })) } else { Bad ("plan lacks: " + ($missingFromPlan -join ', ') + "; names: " + ($names -join ', ')) }
        $ph = @{}
        foreach ($e in $plan) { $ph[$e.Name] = $e.Phase }
        $p1 = @($plan | Where-Object { $_.Phase -eq 1 }).Count
        if ($ph['Test-GridDisposition'] -eq 2 -and $ph['New-FigureSheet'] -eq 3 -and $p1 -eq ($plan.Count - 2)) { Ok ('{0} gates fan out in phase 1; the disposition joins in phase 2; the sheet is phase 3' -f $p1) } else { Bad ('phase assignment wrong: phase1=' + $p1) }
        $idxVc = [array]::IndexOf($names, 'Assert-GateVisualCount'); $idxFx = [array]::IndexOf($names, 'Assert-GateFixtures'); $idxDp = [array]::IndexOf($names, 'Assert-DeckParity')
        if ($idxVc -gt $idxDp -and $idxFx -gt $idxVc -and $ph['Assert-GateVisualCount'] -eq 1 -and $ph['Assert-GateFixtures'] -eq 1) { Ok 'Assert-GateVisualCount and Assert-GateFixtures join phase 1 after the 21 wired members, in that order' } else { Bad "new members misplaced: vc=$idxVc fx=$idxFx dp=$idxDp" }

        function E { param([string] $n) return @($plan | Where-Object { $_.Name -eq $n })[0] }
        $available = @($plan | Where-Object { -not $_.Refused })
        $unavailable = @($plan | Where-Object { $_.Refused })
        Write-Host ("        (on this machine {0} of {2} planned gate scripts are runnable: {1})" -f $available.Count, (($available | ForEach-Object { $_.Name }) -join ', '), $plan.Count) -ForegroundColor DarkGray
        foreach ($u in $unavailable) { Write-Host ("        refused: {0} -> {1}" -f $u.Name, $u.Refused) -ForegroundColor DarkGray }
        foreach ($e in $plan) { foreach ($rp in @($e.Reports)) { Write-Host ("        report: {0} -> {1}" -f $e.Name, $rp) -ForegroundColor DarkGray } }

        #  Assert-GateFixtures is the one member NOT handed -BuildDir: that
        #  would start its plant channel, which is a background job, not a
        #  band member (P0-13).
        $bad = @()
        foreach ($e in $available) { if ($e.Name -ne 'Assert-GateFixtures' -and -not $e.Args.Contains('BuildDir')) { $bad += $e.Name } }
        if ($bad.Count -eq 0) { Ok 'every available gate is handed -BuildDir (the fixtures harness excepted, by design)' } else { Bad ("no -BuildDir on: " + ($bad -join ', ')) }
        $fx = E 'Assert-GateFixtures'
        if ($fx.Refused -and $fx.Refused -match 'StaticOnly') { Ok 'a fixtures copy without -StaticOnly is REFUSED by name (this machine)' }
        elseif (-not $fx.Refused -and $fx.Args['StaticOnly'] -eq $true -and $fx.Args['ResultDir'] -and -not $fx.Args.Contains('BuildDir')) { Ok 'Assert-GateFixtures is wired -StaticOnly -ResultDir <build>\fixtures with no -BuildDir' }
        else { Bad "fixtures wiring: refused='$($fx.Refused)' args=$(($fx.Args.Keys) -join ',')" }
        $vc = E 'Assert-GateVisualCount'
        if ($vc.Refused -and $vc.Refused -match 'script not found') { Ok 'an absent Assert-GateVisualCount.ps1 is REFUSED by name (this machine)' }
        elseif (-not $vc.Refused -and $vc.Args['BuildDir'] -eq $build) { Ok 'Assert-GateVisualCount is wired with -BuildDir' }
        else { Bad "visual count wiring: refused='$($vc.Refused)'" }
        $lk = E 'Check-FigureLeakage'
        if (-not $lk.Refused -and @($lk.Args['ExcludeText']).Count -eq 1 -and $lk.Args['ExcludeText'][0] -eq $unitX) { Ok 'the unit extract is threaded to the leakage gate as -ExcludeText' } elseif ($lk.Refused) { Bad "leakage refused: $($lk.Refused)" } else { Bad 'unit extract not threaded to the leakage gate' }
        $fc = E 'Test-FigureConsistency'
        if (-not $fc.Refused -and -not $fc.Args.Contains('DocText')) { Ok 'the figure registry runs its SOURCE arm only here (no -DocText)' } elseif ($fc.Refused) { Bad "registry refused: $($fc.Refused)" } else { Bad '-DocText leaked into the 3c registry call' }
        $ss = E 'Test-SubSection'
        if (-not $ss.Refused -and $ss.Args['All'] -eq $true -and $ss.Args['ResultDir'] -and -not ([string]$ss.Args['ResultDir']).StartsWith($spine, [StringComparison]::OrdinalIgnoreCase)) { Ok 'Test-SubSection runs -All with a -ResultDir outside spine\' } elseif ($ss.Refused) { Bad "sub-section wrapper refused: $($ss.Refused)" } else { Bad "sub-section args: ResultDir='$($ss.Args['ResultDir'])' All='$($ss.Args['All'])'" }
        $fm = E 'Check-FigureMirror'
        if ($fm.Refused -or ($fm.Args['ReportPath'] -eq (Join-Path $build 'figure-mirror-report.json') -and $fm.Produces -eq $fm.Args['ReportPath'])) { Ok 'Check-FigureMirror is handed -ReportPath at the band path and must PRODUCE it (or reported unavailable)' } else { Bad "mirror wiring: ReportPath='$($fm.Args['ReportPath'])' Produces='$($fm.Produces)'" }
        $sm = E 'Check-ShapeMirror'
        if ($sm.Refused -or ($sm.Args['SpineDir'] -eq $spine -and $sm.Args['ReportPath'])) { Ok 'Check-ShapeMirror is wired by name with -BuildDir -SpineDir and a report path (or reported unavailable)' } else { Bad 'shape mirror wiring' }
        $rc = E 'Check-RowCoverage'
        if ($rc.Refused -or ($rc.Args['Whole'] -eq $true -and $rc.Args['ReportPath'])) { Ok 'Check-RowCoverage is wired by name with -Whole and a report path (or reported unavailable)' } else { Bad 'row coverage wiring' }
        $gd = E 'Test-GridDisposition'
        if ($gd.Refused -or ($gd.Args['ShapeReport'] -eq $sm.Args['ReportPath'] -and $gd.Args['CoverageReport'] -eq $rc.Args['ReportPath'] -and $gd.Args['MirrorReport'] -eq $fm.Args['ReportPath'])) { Ok 'Test-GridDisposition consumes the very report paths handed to the shape mirror, the coverage gate and the answer-grid mirror' } else { Bad 'disposition report paths do not match' }
        $nbOk = $false
        if (-not $gd.Refused -and $gd.Args['NotBefore']) { try { $null = [datetime]::Parse([string]$gd.Args['NotBefore']); $nbOk = $true } catch { $nbOk = $false } }
        if ($gd.Refused -or ($nbOk -and $gd.Must -contains 'NotBefore')) { Ok 'and it is handed -NotBefore, a parseable UTC stamp taken before any gate ran, as a MUST - a report older than it belongs to an earlier round' } else { Bad ("disposition -NotBefore: '{0}' must={1}" -f $gd.Args['NotBefore'], ($gd.Must -join ',')) }
        $sh = E 'New-FigureSheet'
        if ($sh.Refused -or ($sh.Args['BandResults'] -eq (Join-Path $build '3c-band-verdict.json') -and $sh.Must -contains 'BandResults')) { Ok 'New-FigureSheet is handed -BandResults 3c-band-verdict.json as a MUST' } else { Bad "sheet wiring: BandResults='$($sh.Args['BandResults'])' must=$($sh.Must -join ',')" }
        $lines = Get-ThreadedParameterLine -Plan $plan
        $joined = $lines -join "`n"
        $req = @('BuildDir', 'ExcludeText', 'All', 'ResultDir')
        $missingInPrint = @($req | Where-Object { $joined -notmatch ('-' + [regex]::Escape($_) + '=') })
        if ($missingInPrint.Count -eq 0) { Ok 'the printed threaded-parameter list names BuildDir, ExcludeText, All and ResultDir' } else { Bad ("printed list lacks: " + ($missingInPrint -join ', ')) }

        # ---- without the unit extract the leakage gate is REFUSED by name
        Remove-Item -LiteralPath $unitX -Force
        $plan2 = @(New-SpineGatePlan -In $in)
        $lk2 = @($plan2 | Where-Object { $_.Name -eq 'Check-FigureLeakage' })[0]
        if ($lk2.Refused -and $lk2.Refused -match 'unit_extract\.md') { Ok 'without the unit extract the leakage gate is refused, naming unit_extract.md' } else { Bad "leakage not refused: '$($lk2.Refused)'" }
        [System.IO.File]::WriteAllText($unitX, '# Performance Evidence', $utf8)

        # ---- -Only: a subset, an unknown name, the sheet
        $sub = @(Select-PlanByOnly -Plan $plan -Only @('Test-Spine', 'assert-promptlint.ps1'))
        if ($sub.Count -eq 2 -and $sub[0].Name -eq 'Test-Spine' -and $sub[1].Name -eq 'Assert-PromptLint') { Ok '-Only selects by name, case-insensitively, with or without .ps1' } else { Bad ("-Only selected: " + (($sub | ForEach-Object { $_.Name }) -join ', ')) }
        $threw = ''
        try { $null = Select-PlanByOnly -Plan $plan -Only @('Test-Nothing') } catch { $threw = $_.Exception.Message }
        if ($threw -match 'not a gate of this band') { Ok '-Only with an unknown name is a usage error, never an empty run' } else { Bad "unknown -Only: '$threw'" }
        $threw = ''
        try { $null = Select-PlanByOnly -Plan $plan -Only @('New-FigureSheet') } catch { $threw = $_.Exception.Message }
        if ($threw -match 'full band that passed') { Ok '-Only cannot select the figure sheet' } else { Bad "sheet via -Only: '$threw'" }

        # ---- a missing gate script is "gate unavailable", a FAIL, never a pass
        $ghost = New-GateEntry -Name 'Check-Ghost' -Title 'ghost' -Script (Join-Path $tmp 'Check-Ghost.ps1') -Phase 1 -Want ([ordered]@{ BuildDir = $build }) -Must @('BuildDir')
        if ($ghost.Refused -match 'gate unavailable') { Ok 'a missing gate script is planned as "gate unavailable"' } else { Bad "ghost refused='$($ghost.Refused)'" }
        $gr = @(Invoke-SpineGatePlan -Plan @($ghost) -SkillDir $SkillDir -TimeoutSeconds 5)
        if ($gr.Count -eq 1 -and -not $gr[0].Ok -and $gr[0].Refused -and $gr[0].Reason -match 'gate unavailable' -and $gr[0].RanAt) { Ok 'and in the results it is a REFUSED naming the gate and the reason, with a ranAt - never a pass, never a skip' } else { Bad "ghost result ok=$($gr[0].Ok) reason='$($gr[0].Reason)' ranAt='$($gr[0].RanAt)'" }

        # ---- a copy that cannot take a parameter the rule depends on is refused
        $narrow = Join-Path $tmp 'Narrow-Gate.ps1'
        [System.IO.File]::WriteAllText($narrow, "param([string] `$BuildDir)`r`nexit 0`r`n", $bom)
        $ne = New-GateEntry -Name 'Narrow' -Title 'narrow' -Script $narrow -Phase 1 -Want ([ordered]@{ BuildDir = $build; ExcludeText = @($unitX); Quiet = $true }) -Must @('BuildDir', 'ExcludeText')
        if ($ne.Refused -match 'ExcludeText') { Ok 'a copy that cannot take a parameter the blocking rule depends on is REFUSED, not run without it' } else { Bad "narrow refused='$($ne.Refused)'" }
        $ne2 = New-GateEntry -Name 'Narrow2' -Title 'narrow' -Script $narrow -Phase 1 -Want ([ordered]@{ BuildDir = $build; Quiet = $true }) -Must @('BuildDir')
        if (-not $ne2.Refused -and $ne2.Args.Count -eq 1 -and @($ne2.Dropped) -contains 'Quiet') { Ok 'an optional parameter the copy lacks is dropped and recorded as dropped' } else { Bad "narrow2 refused='$($ne2.Refused)' dropped=$($ne2.Dropped -join ',')" }
        if (@($ne2.Reports) -contains 'no GATE header (treated as stages=3c until the header lands)') { Ok 'a script with no GATE header gets the REPORT line "no GATE header" and is not refused' } else { Bad ("headerless reports: " + (@($ne2.Reports) -join ' | ')) }

        # ---- the GATE header: parsed exactly, merged into MUST, never a refusal on absence
        $hdrGate = Join-Path $tmp 'Header-Gate.ps1'
        [System.IO.File]::WriteAllText($hdrGate, "# GATE: stages=1,3c; requires=BuildDir; 7c: DocText`r`nparam([string] `$BuildDir, [string] `$DocText)`r`nexit 0`r`n", $bom)
        $h = Get-GateHeader -Path $hdrGate
        if ($h.Found -and (@($h.Stages) -join ',') -eq '1,3c' -and (@($h.Requires) -join ',') -eq 'BuildDir' -and $h.StageRequires.ContainsKey('7c') -and (@($h.StageRequires['7c']) -join ',') -eq 'DocText' -and @($h.Problems).Count -eq 0) { Ok "the header '# GATE: stages=1,3c; requires=BuildDir; 7c: DocText' parses to stages 1,3c / requires BuildDir / 7c: DocText" } else { Bad ("header parse: stages=" + (@($h.Stages) -join ',') + " req=" + (@($h.Requires) -join ',') + " problems=" + (@($h.Problems) -join ' | ')) }
        $h0 = Get-GateHeader -Path $narrow
        if (-not $h0.Found -and @($h0.Problems).Count -eq 0) { Ok 'a script with no header is Found=false with no problem' } else { Bad 'headerless script mis-parsed' }
        #  A '# GATE:' line that is NOT a header: one quoted inside the doc
        #  block, one inside a here-string below param(). Assert-GateFixtures
        #  carries exactly the second shape, and reading it bound the fixtures
        #  member to a requires=BuildDir it is deliberately never handed - a
        #  band member refused out of a string literal.
        $fakeHdr = Join-Path $tmp 'Fake-Header.ps1'
        [System.IO.File]::WriteAllText($fakeHdr, "<#`r`n    A gate whose doc quotes the convention:`r`n# GATE: stages=1; requires=DocText`r`n#>`r`nparam([string] `$BuildDir)`r`n`$body = @'`r`n# GATE: stages=7c; requires=Path,BuildDir`r`n'@`r`nexit 0`r`n", $bom)
        $hf = Get-GateHeader -Path $fakeHdr
        if (-not $hf.Found) { Ok "a '# GATE:' line inside the doc comment, or inside a here-string below param(), is NOT read as the header" } else { Bad ("a quoted line was read as the header: '{0}' (line {1})" -f $hf.Raw, $hf.Line) }
        $realHdr = Join-Path $tmp 'Real-Header.ps1'
        [System.IO.File]::WriteAllText($realHdr, "<#`r`n    doc`r`n#>`r`n# GATE: stages=3c; requires=BuildDir`r`n`r`n[CmdletBinding()]`r`nparam([string] `$BuildDir)`r`nexit 0`r`n", $bom)
        $hr2 = Get-GateHeader -Path $realHdr
        if ($hr2.Found -and $hr2.Line -eq 4 -and (@($hr2.Stages) -join ',') -eq '3c') { Ok 'the header in its documented place - column 0, below the doc block, above [CmdletBinding()] - is read, with its line number' } else { Bad ("real header: found={0} line={1} stages={2}" -f $hr2.Found, $hr2.Line, (@($hr2.Stages) -join ',')) }
        #  An inventory, printed: which scripts of THIS skill declare a header
        #  and which do not. A report for the reader, never a verdict here.
        $hdrHave = @(); $hdrNone = @()
        foreach ($f in (Get-ChildItem -LiteralPath (Join-Path $SkillDir 'scripts') -Filter '*.ps1' -File | Sort-Object Name)) {
            if ($script:NotMembers -contains $f.BaseName) { continue }
            if ((Get-GateHeader -Path $f.FullName).Found) { $hdrHave += $f.BaseName } else { $hdrNone += $f.BaseName }
        }
        Write-Host ("        ({0} script(s) carry a GATE header: {1})" -f $hdrHave.Count, ($hdrHave -join ', ')) -ForegroundColor DarkGray
        Write-Host ("        ({0} without one: {1})" -f $hdrNone.Count, ($hdrNone -join ', ')) -ForegroundColor DarkGray
        $badHdr = Join-Path $tmp 'Bad-Header.ps1'
        [System.IO.File]::WriteAllText($badHdr, "# GATE: stages=9,3c; bogus`r`nparam([string] `$BuildDir)`r`nexit 0`r`n", $bom)
        $hb = Get-GateHeader -Path $badHdr
        if ($hb.Found -and (@($hb.Stages) -join ',') -eq '3c' -and @($hb.Problems).Count -eq 2) { Ok 'an unknown stage and an unrecognised clause are each a named problem; the valid stage is still read' } else { Bad ("bad header: stages=" + (@($hb.Stages) -join ',') + " problems=" + (@($hb.Problems) -join ' | ')) }
        $he = New-GateEntry -Name 'Header-Gate' -Title 'h' -Script $hdrGate -Phase 1 -Want ([ordered]@{ BuildDir = $build }) -Must @() -Stage '3c'
        if (-not $he.Refused -and $he.Must -contains 'BuildDir' -and $he.Must -notcontains 'DocText') { Ok 'at 3c the header adds requires=BuildDir to MUST and leaves the 7c-only DocText out' } else { Bad "header must at 3c: refused='$($he.Refused)' must=$($he.Must -join ',')" }
        $he7 = New-GateEntry -Name 'Header-Gate' -Title 'h' -Script $hdrGate -Phase 1 -Want ([ordered]@{ BuildDir = $build }) -Must @() -Stage '7c'
        if ($he7.Refused -and $he7.Refused -match '-DocText' -and $he7.Refused -match 'stage 7c') { Ok 'a header requirement this runner has no value for is REFUSED naming the parameter and the stage' } else { Bad "header must at 7c: refused='$($he7.Refused)'" }
        $rosterHdr = Join-Path $tmp 'Roster-Gate.ps1'
        [System.IO.File]::WriteAllText($rosterHdr, "# GATE: stages=1; requires=BuildDir`r`nparam([string] `$BuildDir)`r`nexit 0`r`n", $bom)
        $hr = New-GateEntry -Name 'Roster-Gate' -Title 'r' -Script $rosterHdr -Phase 1 -Want ([ordered]@{ BuildDir = $build }) -Must @('BuildDir') -Stage '3c' -RosterMember
        if ($hr.Refused -and $hr.Refused -match 'cannot leave the band') { Ok 'a 3c roster member whose header omits 3c is REFUSED - a member cannot leave the band by editing its own header' } else { Bad "roster header: refused='$($hr.Refused)'" }

        # ---- the job wrapper: a stub result is collected with its text and exit code
        $stubFail = Join-Path $tmp 'stub_fail.ps1'
        [System.IO.File]::WriteAllText($stubFail, "param([string] `$BuildDir)`r`nWrite-Host 'X planted failure'`r`nexit 1`r`n", $bom)
        $stubPass = Join-Path $tmp 'stub_pass.ps1'
        [System.IO.File]::WriteAllText($stubPass, "param([string] `$BuildDir)`r`nWrite-Host 'planted pass'`r`nexit 0`r`n", $bom)
        $stubThrow = Join-Path $tmp 'stub_throw.ps1'
        [System.IO.File]::WriteAllText($stubThrow, "param([string] `$BuildDir)`r`nthrow 'planted throw'`r`n", $bom)
        $stubSlow = Join-Path $tmp 'stub_slow.ps1'
        [System.IO.File]::WriteAllText($stubSlow, "param([string] `$BuildDir)`r`nStart-Sleep -Seconds 60`r`nexit 0`r`n", $bom)
        $stubArmNotRun = Join-Path $tmp 'stub_arm_notrun.ps1'
        [System.IO.File]::WriteAllText($stubArmNotRun, "param([string] `$BuildDir)`r`nWrite-Host 'looks fine'`r`nWrite-Host 'ARMS: x|true|not-run|0|0'`r`nexit 0`r`n", $bom)
        $stubArmOk = Join-Path $tmp 'stub_arm_ok.ps1'
        [System.IO.File]::WriteAllText($stubArmOk, "param([string] `$BuildDir)`r`nWrite-Host 'ARMS: a|true|ran|4|1;b|false|not-run|0|0'`r`nexit 0`r`n", $bom)
        #  READ THE PLANT BACK BEFORE ASSERTING ANYTHING ABOUT IT. A stub that
        #  was never written, or written without its marker, makes every check
        #  below prove nothing while still printing PASS - the exact shape that
        #  once recorded a no-op plant as proof of a gate. Cheap, and the only
        #  thing separating a self-test from a decoration.
        $plantOk = $true
        foreach ($pl in @(
            @{ P = $stubFail;  M = 'X planted failure' },
            @{ P = $stubPass;  M = 'planted pass' },
            @{ P = $stubThrow; M = 'planted throw' },
            @{ P = $stubSlow;  M = 'Start-Sleep' },
            @{ P = $stubArmNotRun; M = 'ARMS: x|true|not-run|0|0' },
            @{ P = $stubArmOk; M = 'b|false|not-run|0|0' }
        )) {
            if (-not (Test-Path -LiteralPath $pl.P)) { Bad ("the planted stub was never written: {0}" -f (Split-Path $pl.P -Leaf)); $plantOk = $false; continue }
            $txt = [System.IO.File]::ReadAllText($pl.P)
            if ($txt.IndexOf($pl.M, [System.StringComparison]::Ordinal) -lt 0) { Bad ("the planted stub {0} does not carry its marker" -f (Split-Path $pl.P -Leaf)); $plantOk = $false }
        }
        if ($plantOk) { Ok 'every planted stub was read back and carries its marker, so the checks below prove something' }
        $eFail  = New-GateEntry -Name 'stub-fail'  -Title 'f' -Script $stubFail  -Phase 1 -Want ([ordered]@{ BuildDir = $build }) -Must @('BuildDir')
        $ePass  = New-GateEntry -Name 'stub-pass'  -Title 'p' -Script $stubPass  -Phase 1 -Want ([ordered]@{ BuildDir = $build }) -Must @('BuildDir')
        $eThrow = New-GateEntry -Name 'stub-throw' -Title 't' -Script $stubThrow -Phase 1 -Want ([ordered]@{ BuildDir = $build }) -Must @('BuildDir')
        $eArmNo = New-GateEntry -Name 'stub-arm-notrun' -Title 'a' -Script $stubArmNotRun -Phase 1 -Want ([ordered]@{ BuildDir = $build }) -Must @('BuildDir')
        $eArmOk = New-GateEntry -Name 'stub-arm-ok' -Title 'a' -Script $stubArmOk -Phase 1 -Want ([ordered]@{ BuildDir = $build }) -Must @('BuildDir')
        $swFan = [System.Diagnostics.Stopwatch]::StartNew()
        $rr = @(Invoke-SpineGatePlan -Plan @($eFail, $ePass, $eThrow, $eArmNo, $eArmOk) -SkillDir $SkillDir -TimeoutSeconds 120 -MaxJobs 5 -Evidence 'seed')
        $swFan.Stop()
        $rFail = @($rr | Where-Object { $_.Name -eq 'stub-fail' })[0]
        $rPass = @($rr | Where-Object { $_.Name -eq 'stub-pass' })[0]
        $rThrow = @($rr | Where-Object { $_.Name -eq 'stub-throw' })[0]
        $rArmNo = @($rr | Where-Object { $_.Name -eq 'stub-arm-notrun' })[0]
        $rArmOk = @($rr | Where-Object { $_.Name -eq 'stub-arm-ok' })[0]
        if ($rFail -and -not $rFail.Ok -and $rFail.Text -match 'planted failure' -and $rFail.ExitCode -eq 1) { Ok 'the job wrapper collects a stub''s text and its exit code 1 as a FAIL' } else { Bad ("stub-fail: ok=$($rFail.Ok) code=$($rFail.ExitCode) text='$($rFail.Text)' err='$($rFail.Error)'") }
        if ($rPass -and $rPass.Ok -and $rPass.Text -match 'planted pass' -and $rPass.ExitCode -eq 0 -and $rPass.StartedAt -and $rPass.RanAt) { Ok 'a stub that exits 0 is a PASS with its text captured and startedAt / ranAt recorded' } else { Bad ("stub-pass: ok=$($rPass.Ok) code=$($rPass.ExitCode) err='$($rPass.Error)' started='$($rPass.StartedAt)' ran='$($rPass.RanAt)'") }
        if ($rThrow -and -not $rThrow.Ok -and $rThrow.Error -match 'planted throw' -and $rThrow.Reason -match 'planted throw') { Ok 'a stub that throws is a FAIL reporting the thrown error' } else { Bad ("stub-throw: ok=$($rThrow.Ok) err='$($rThrow.Error)' reason='$($rThrow.Reason)'") }
        if ($rArmNo -and -not $rArmNo.Ok -and $rArmNo.ExitCode -eq 0 -and $rArmNo.Reason -eq 'arm not run: x' -and @($rArmNo.ArmsBlockingNotRun) -contains 'x') { Ok "a member printing 'ARMS: x|true|not-run|0|0' and exiting 0 is FAIL with reason 'arm not run: x'" } else { Bad ("stub-arm-notrun: ok=$($rArmNo.Ok) code=$($rArmNo.ExitCode) reason='$($rArmNo.Reason)'") }
        if ($rArmOk -and $rArmOk.Ok -and @($rArmOk.Arms).Count -eq 2 -and $rArmOk.Arms[0].name -eq 'a' -and $rArmOk.Arms[0].state -eq 'ran' -and $rArmOk.Arms[0].size -eq 4 -and $rArmOk.Arms[0].evidence -eq 'seed' -and @($rArmOk.ArmsBlockingNotRun).Count -eq 0) { Ok 'a roster with a ran blocking arm and an advisory not-run arm is recorded (2 arms, evidence label applied) and passes' } else { Bad ("stub-arm-ok: ok=$($rArmOk.Ok) arms=$(@($rArmOk.Arms).Count) evidence='$($rArmOk.Arms[0].evidence)'") }
        #  The human summary line every gate also prints must NOT be read as a
        #  roster: it was, and six passing gates were reported as printing an
        #  unparseable ARMS cell on a real band run.
        $roCase = ConvertFrom-ArmRosterText -Text "  arms: 4 registered, 2 blocking, all complete`nARMS: a|true|ran|1|0"
        if (@($roCase.Arms).Count -eq 1 -and $roCase.Arms[0].name -eq 'a' -and @($roCase.Problems).Count -eq 0 -and @($roCase.Lines).Count -eq 1) { Ok "the roster line is read case-sensitively: the human 'arms: 4 registered, 2 blocking' line is not a roster" } else { Bad ("case-sensitive ARMS: arms={0} problems={1}" -f @($roCase.Arms).Count, (@($roCase.Problems) -join ' | ')) }
        $ro = ConvertFrom-ArmRosterText -Text "ARMS: good|true|ran|2|0;broken cell`nARMS: none"
        if (@($ro.Problems).Count -eq 1 -and @($ro.Arms).Count -eq 2 -and $ro.Arms[1].state -eq 'unparsed' -and @($ro.Lines).Count -eq 2) { Ok 'a malformed ARMS cell is a named problem kept as an unparsed arm; ARMS: none parses to nothing' } else { Bad ("roster parse: problems=$(@($ro.Problems).Count) arms=$(@($ro.Arms).Count) lines=$(@($ro.Lines).Count)") }
        $sumSec = 0.0; foreach ($x in $rr) { $sumSec += $x.Seconds }
        Write-Host ("        (five stubs fanned out: wall {0}s, sum of gate wall times {1}s)" -f [math]::Round($swFan.Elapsed.TotalSeconds, 1), [math]::Round($sumSec, 1)) -ForegroundColor DarkGray
        if (@($rr | Where-Object { -not $_.Removed }).Count -eq 0) { Ok 'every completed job was removed' } else { Bad 'a completed job was left behind' }

        # ---- a 60 s stub at a 4 s deadline is stopped and removed
        $eSlow = New-GateEntry -Name 'stub-slow' -Title 's' -Script $stubSlow -Phase 1 -Want ([ordered]@{ BuildDir = $build }) -Must @('BuildDir')
        $before = @(Get-Job).Count
        $swSlow = [System.Diagnostics.Stopwatch]::StartNew()
        $rs = @(Invoke-SpineGatePlan -Plan @($eSlow) -SkillDir $SkillDir -TimeoutSeconds 4)
        $swSlow.Stop()
        $after = @(Get-Job).Count
        if ($rs.Count -eq 1 -and -not $rs[0].Ok -and $rs[0].Reason -match 'timed out after 4 s' -and $swSlow.Elapsed.TotalSeconds -lt 30) { Ok ("a 60 s stub at a 4 s deadline is stopped and reported as a FAIL (joined at {0}s)" -f [math]::Round($swSlow.Elapsed.TotalSeconds, 1)) } else { Bad ("timeout: ok=$($rs[0].Ok) reason='$($rs[0].Reason)' after $([math]::Round($swSlow.Elapsed.TotalSeconds,1))s") }
        if ($rs[0].Removed -and $after -le $before) { Ok 'and the timed-out job was removed from the job table' } else { Bad "timed-out job not removed (jobs before $before, after $after)" }

        # ---- the concurrency cap: 3 stubs, MaxJobs 1, run one at a time
        $slowish = Join-Path $tmp 'stub_2s.ps1'
        [System.IO.File]::WriteAllText($slowish, "param([string] `$BuildDir)`r`nStart-Sleep -Seconds 2`r`nexit 0`r`n", $bom)
        $es = @(1..3 | ForEach-Object { New-GateEntry -Name ("cap-{0}" -f $_) -Title 'c' -Script $slowish -Phase 1 -Want ([ordered]@{ BuildDir = $build }) -Must @('BuildDir') })
        $rc1 = @(Invoke-SpineGatePlan -Plan $es -SkillDir $SkillDir -TimeoutSeconds 60 -MaxJobs 1)
        if (@($rc1 | Where-Object { $_.Ok }).Count -eq 3) { Ok '-MaxJobs 1 runs the same plan one job at a time and every result still arrives' } else { Bad 'MaxJobs 1 lost a result' }

        # ---- the figure sheet decision, the band verdict file, the derived sheet state
        $good = @([pscustomobject]@{ Name = 'a'; Ok = $true; Refused = $false; ExitCode = 0; RanAt = 'x' }, [pscustomobject]@{ Name = 'b'; Ok = $true; Refused = $false; ExitCode = 0; RanAt = 'x' })
        $mixed = @([pscustomobject]@{ Name = 'a'; Ok = $true; Refused = $false; ExitCode = 0; RanAt = 'x' }, [pscustomobject]@{ Name = 'b'; Ok = $false; Refused = $false; ExitCode = 1; RanAt = 'x' })
        if (-not (Test-SheetMayRun -Results $good -Partial $false -FingerprintBefore 'v2:aa' -FingerprintNow 'v2:aa')) { Ok 'the sheet runs on a green full band over an unmoved spine' } else { Bad 'sheet blocked on a green band' }
        if ((Test-SheetMayRun -Results $mixed -Partial $false) -match 'never cut from a spine that failed') { Ok 'the sheet is NOT cut when any blocking gate failed' } else { Bad 'sheet ran on a failed band' }
        if ((Test-SheetMayRun -Results $good -Partial $true) -match 'partial') { Ok 'the sheet is NOT cut in a partial run' } else { Bad 'sheet ran in a partial run' }
        $mv = Test-SheetMayRun -Results $good -Partial $false -FingerprintBefore 'v2:aa' -FingerprintNow 'v2:bb'
        if ($mv -like 'REFUSED*' -and $mv -match 'v2:aa' -and $mv -match 'v2:bb') { Ok 'a spine that moved between the start and the join REFUSES the cut naming both fingerprints' } else { Bad "moved spine: '$mv'" }
        $bvPath = Join-Path $build '3c-band-verdict.json'
        $ents = @([pscustomobject]@{ Name = 'a'; Phase = 1 }, [pscustomobject]@{ Name = 'b'; Phase = 1 })
        $bv = Write-BandVerdictFile -Path $bvPath -Results $mixed -Entries $ents -Partial $false -FingerprintBefore 'v2:aa' -FingerprintNow 'v2:aa' -BuildDir $build
        $bvRead = Read-JsonFile -Path $bvPath
        if ($bvRead -and $bvRead.verdict -eq 'FAIL' -and $bvRead.exitCode -eq 1 -and @($bvRead.failed) -contains 'b' -and $bvRead.spineFingerprint -eq 'v2:aa' -and $bvRead.partial -eq $false -and @($bvRead.members).Count -eq 2) { Ok 'the band verdict file records FAIL, exit 1, the failed member, the join fingerprint and every member' } else { Bad "band verdict file: $(Get-Content -LiteralPath $bvPath -Raw)" }
        $bv2 = Write-BandVerdictFile -Path $bvPath -Results $good -Entries $ents -Partial $false -FingerprintBefore 'v2:aa' -FingerprintNow 'v2:bb' -BuildDir $build
        if ($bv2.verdict -eq 'FAIL' -and @($bv2.failed) -contains 'spine-changed-during-run' -and $bv2.spineMovedDuringBand) { Ok 'a green band over a moved spine is a FAIL band verdict naming spine-changed-during-run' } else { Bad "moved band verdict: $($bv2.verdict) $($bv2.failed -join ',')" }

        # ---- the GATE-DEFECT class: exit 4 is never a content failure
        $defRes = @([pscustomobject]@{ Name = 'a'; Ok = $true; Refused = $false; ExitCode = 0; RanAt = 'x' }, [pscustomobject]@{ Name = 'b'; Ok = $false; Refused = $false; ExitCode = 4; RanAt = 'x' })
        $defNames = @(Get-GateDefectiveName -Results $defRes)
        if ($defNames.Count -eq 1 -and $defNames[0] -eq 'b') { Ok 'a member that exited 4 is picked out as GATE-DEFECT by exit code alone' } else { Bad ("defective names: " + ($defNames -join ',')) }
        #  THE SHAPE THE RUNNER ACTUALLY HANDS THESE FUNCTIONS is a
        #  List[object], not an array, and on PS 5.1 here @() over a populated
        #  generic List throws - so the array-only test above would pass while
        #  the band died at the join. Both are exercised.
        $defList = New-Object System.Collections.Generic.List[object]
        foreach ($r in $defRes) { $defList.Add($r) }
        $defListNames = @(Get-GateDefectiveName -Results $defList)
        if ($defListNames.Count -eq 1 -and $defListNames[0] -eq 'b' -and (Test-SheetMayRun -Results $defList -Partial $false) -match 'GATE-DEFECT') { Ok 'and the same answer when the results arrive as the List[object] the runner really passes' } else { Bad ("List[object] results: " + ($defListNames -join ',')) }
        if (@(Get-GateDefectiveName -Results $null).Count -eq 0) { Ok 'a null result set yields no defective member rather than throwing' } else { Bad 'null results' }
        $notDef = @([pscustomobject]@{ Name = 'c'; Ok = $false; Refused = $false; ExitCode = 1; RanAt = 'x' }, [pscustomobject]@{ Name = 'd'; Ok = $false; Refused = $true; ExitCode = $null; RanAt = 'x' }, [pscustomobject]@{ Name = 'e'; Ok = $false; Refused = $true; ExitCode = 4; RanAt = 'x' })
        if (@(Get-GateDefectiveName -Results $notDef).Count -eq 0) { Ok 'CONTROL exit 1, a refusal and a refusal carrying a 4 are ordinary failures, never GATE-DEFECT' } else { Bad ("defective misread: " + ((Get-GateDefectiveName -Results $notDef) -join ',')) }
        $defSheet = Test-SheetMayRun -Results $defRes -Partial $false -FingerprintBefore 'v2:aa' -FingerprintNow 'v2:aa'
        if ($defSheet -match 'GATE-DEFECT \(b\)' -and $defSheet -notmatch 'spine that failed') { Ok 'PLANT the sheet is NOT cut while a member is GATE-DEFECT, and the refusal names it as a gate defect and not as a content failure' } else { Bad "defective sheet note: '$defSheet'" }
        $bv3 = Write-BandVerdictFile -Path $bvPath -Results $defRes -Entries $ents -Partial $false -FingerprintBefore 'v2:aa' -FingerprintNow 'v2:aa' -BuildDir $build
        $bv3Read = Read-JsonFile -Path $bvPath
        if ($bv3.verdict -eq 'GATE-DEFECT' -and $bv3.exitCode -eq 1 -and @($bv3.defective) -contains 'b' -and @($bv3.failed).Count -eq 0 -and @($bv3Read.members | Where-Object { $_.name -eq 'b' })[0].verdict -eq 'GATE-DEFECT') { Ok 'the band verdict file over a GATE-DEFECT member says GATE-DEFECT, exit 1, lists it in defective[] and NOT in failed[], and its member row says GATE-DEFECT' } else { Bad ("gate-defect band verdict: {0} failed=[{1}] defective=[{2}]" -f $bv3.verdict, (@($bv3.failed) -join ','), (@($bv3.defective) -join ',')) }
        $bv4 = Write-BandVerdictFile -Path $bvPath -Results ($defRes + @([pscustomobject]@{ Name = 'f'; Ok = $false; Refused = $false; ExitCode = 1; RanAt = 'x' })) -Entries ($ents + @([pscustomobject]@{ Name = 'f'; Phase = 1 })) -Partial $false -FingerprintBefore 'v2:aa' -FingerprintNow 'v2:aa' -BuildDir $build
        if ($bv4.verdict -eq 'FAIL' -and @($bv4.failed) -contains 'f' -and @($bv4.failed) -notcontains 'b' -and @($bv4.defective) -contains 'b') { Ok 'a band with both a content failure and a gate defect is FAIL, and the two members stay in their own lists' } else { Bad ("mixed band verdict: {0} failed=[{1}] defective=[{2}]" -f $bv4.verdict, (@($bv4.failed) -join ','), (@($bv4.defective) -join ',')) }
        $sheetTmp = Join-Path $build 'figure-sheet.txt'
        if (Test-Path -LiteralPath $sheetTmp) { Remove-Item -LiteralPath $sheetTmp -Force }
        $okRes = [pscustomobject]@{ Ok = $true; ExitCode = 0; Reason = '' }
        $s1 = Get-FigureSheetState -Note '' -Result $okRes -SheetPath $sheetTmp -Planned $true
        [System.IO.File]::WriteAllText($sheetTmp, 'sheet', $bom)
        $s2 = Get-FigureSheetState -Note '' -Result $okRes -SheetPath $sheetTmp -Planned $true
        $s3 = Get-FigureSheetState -Note '' -Result ([pscustomobject]@{ Ok = $false; ExitCode = 2; Reason = 'exit code 2' }) -SheetPath $sheetTmp -Planned $true
        $s4 = Get-FigureSheetState -Note 'NOT RUN - x' -Result $null -SheetPath $sheetTmp -Planned $true
        $s5 = Get-FigureSheetState -Note '' -Result $null -SheetPath $sheetTmp -Planned $false
        if ($s1 -like 'FAIL - exit 0 but no sheet*' -and $s2 -eq 'cut' -and $s3 -like 'FAIL - exit 2*EARLIER cut*' -and $s4 -eq 'NOT RUN - x' -and $s5 -eq 'not in this run') { Ok "figureSheet is derived: 'cut' only when the job passed AND the sheet exists; exit 0 without a sheet is FAIL; a failed cut names the exit and an old sheet on disk" } else { Bad "sheet state: '$s1' / '$s2' / '$s3' / '$s4' / '$s5'" }
        Remove-Item -LiteralPath $sheetTmp -Force

        # ---- sub-section verdicts are read from gate.json by contract
        $sd = Join-Path $resultDir 'subsections'
        New-Item -ItemType Directory -Force -Path $sd | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $sd 't1_1.1.json.gate.json'), '{"verdict":"fail","blocks":[{"arm":"mirror-own","text":"x"}]}', $utf8)
        [System.IO.File]::WriteAllText((Join-Path $sd 't1_1.2.json.gate.json'), '{"verdict":"pass","blocks":[]}', $utf8)
        $sv = @(Get-SubSectionVerdict -Dir $sd)
        if ($sv.Count -eq 2 -and $sv[0].verdict -eq 'fail' -and $sv[0].blocks -eq 1 -and $sv[0].arms -eq 'mirror-own' -and $sv[1].verdict -eq 'pass') { Ok 'per-file sub-section verdicts are collected from gate.json by contract' } else { Bad ("sub-section verdicts: " + (($sv | ForEach-Object { "$($_.file)=$($_.verdict)" }) -join ', ')) }

        # ---- the fixtures proof reader: only a hash-stamped report counts; PROVEN alone is proof
        $fxDir = Join-Path $build 'fixtures'
        New-Item -ItemType Directory -Force -Path $fxDir | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $fxDir 'gate-fixtures.json'), '{"results":[{"Gate":"Test-Spine","Verdict":"PROVEN"}]}', $bom)
        $pr0 = Get-FixtureProof -BuildDir $build
        if (-not $pr0.Found -and (Get-MemberProofNote -Proof $pr0 -Name 'Test-Spine') -eq 'no fixtures report') { Ok 'an un-stamped gate-fixtures.json is NOT a proof: "no fixtures report"' } else { Bad "unstamped report counted: found=$($pr0.Found)" }
        $fxFile = Join-Path $fxDir 'gate-fixtures.0123abcd.json'
        [System.IO.File]::WriteAllText($fxFile, '{"checkedAt":"2026-09-08T00:00:00","results":[{"Gate":"Test-Spine","Verdict":"PROVEN"},{"Gate":"Test-SpineRead","Verdict":"UNPROVEN"},{"Gate":"Check-FigureMirror.ps1","Verdict":"PROVEN-SELFTEST"}]}', $bom)
        if ((Get-Content -LiteralPath $fxFile -Raw) -notmatch '"UNPROVEN"') { Bad 'the planted fixtures report was not written with its UNPROVEN row' }
        $pr = Get-FixtureProof -BuildDir $build
        $n1 = Get-MemberProofNote -Proof $pr -Name 'Test-Spine'; $n2 = Get-MemberProofNote -Proof $pr -Name 'Test-SpineRead'; $n3 = Get-MemberProofNote -Proof $pr -Name 'Check-FigureMirror'; $n4 = Get-MemberProofNote -Proof $pr -Name 'Assert-Terminology'
        $phHash = Get-SkillScriptsHash -SkillDir $SkillDir
        $phSuppressed = Get-PlantChannelPlan -BuildDir $build -SkillDir $SkillDir -Hash $phHash -Suppressed
        $phStart = Get-PlantChannelPlan -BuildDir $build -SkillDir $SkillDir -Hash $phHash
        [System.IO.File]::WriteAllText((Join-Path $fxDir ("gate-fixtures.{0}.json" -f $phHash)), '{"results":[]}', $bom)
        $phCurrent = Get-PlantChannelPlan -BuildDir $build -SkillDir $SkillDir -Hash $phHash
        Remove-Item -LiteralPath (Join-Path $fxDir ("gate-fixtures.{0}.json" -f $phHash)) -Force
        Write-JsonFile -Path (Join-Path $fxDir 'plant-channel.json') -Body ([pscustomobject]@{ scriptsHash = $phHash; startedAt = (Get-UtcNow); pid = 4242 })
        $phRunning = Get-PlantChannelPlan -BuildDir $build -SkillDir $SkillDir -Hash $phHash
        Write-JsonFile -Path (Join-Path $fxDir 'plant-channel.json') -Body ([pscustomobject]@{ scriptsHash = 'deadbeef'; startedAt = (Get-UtcNow); pid = 4242 })
        $phOther = Get-PlantChannelPlan -BuildDir $build -SkillDir $SkillDir -Hash $phHash
        Remove-Item -LiteralPath (Join-Path $fxDir 'plant-channel.json') -Force
        if ($phHash -match '^[0-9a-f]{8}$') { Ok ("the plant channel key is derived from the bytes of every scripts\*.ps1 ({0})" -f $phHash) } else { Bad ("scripts hash '{0}'" -f $phHash) }
        if ($phSuppressed.Action -eq 'suppressed' -and $phStart.Action -eq 'start' -and $phCurrent.Action -eq 'current' -and $phRunning.Action -eq 'running' -and $phOther.Action -eq 'start') { Ok 'the plant channel starts only when no report for THESE scripts is on disk and none is already running; -NoPlantChannel suppresses it; a report for other scripts does not count' } else { Bad ("plant plan: suppressed={0} start={1} current={2} running={3} other={4}" -f $phSuppressed.Action, $phStart.Action, $phCurrent.Action, $phRunning.Action, $phOther.Action) }
        if ($pr.Found -and $pr.Hash -eq '0123abcd' -and $n1 -eq 'PROVEN' -and $n2 -eq 'UNPROVEN (UNPROVEN)' -and $n3 -eq 'UNPROVEN (PROVEN-SELFTEST)' -and $n4 -eq 'UNPROVEN (not in the fixtures report)') { Ok 'the newest gate-fixtures.<hash>.json is read; PROVEN is proof, PROVEN-SELFTEST and an absent row are UNPROVEN by name' } else { Bad "proof notes: found=$($pr.Found) hash=$($pr.Hash) '$n1' '$n2' '$n3' '$n4'" }

        # ===================================================================
        # END TO END: this runner, as a child process, over a fixture skill
        # whose gates are stubs and whose New-FigureSheet and Lib-GateCommon
        # are the real files. Every plant below is read back before the run
        # that depends on it.
        # ===================================================================
        $fxSkill = Join-Path $tmp 'skill'
        $fxScripts = Join-Path $fxSkill 'scripts'
        New-Item -ItemType Directory -Force -Path $fxScripts | Out-Null
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1') -Destination (Join-Path $fxScripts 'Lib-GateCommon.ps1') -Force
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'New-FigureSheet.ps1') -Destination (Join-Path $fxScripts 'New-FigureSheet.ps1') -Force
        [System.IO.File]::WriteAllText((Join-Path $fxScripts 'Lib-Resolve.ps1'), "param([string] `$SharedPath, [switch] `$NoDeck)`r`n# fixture: nothing to load`r`n", $bom)
        $stubParams = 'param([string] $BuildDir, [string] $SpineDir, [string] $SkillDir, [string] $ReportPath, [string] $ResultPath, [string] $ResultDir, [string] $OutPath, [string[]] $ExcludeText, [switch] $All, [switch] $Whole, [string] $ShapeReport, [string] $CoverageReport, [string] $MirrorReport, [switch] $StaticOnly, [string] $UnitExtract, [string] $RegisterPath, [string] $AssessorCellsPath, [string] $Profile, [string] $ProfilePath, [string] $Register, [string] $RulesPath, [string] $AssessorCells, [int] $Stage, [switch] $SeedOnly, [string] $BandResults, [string] $ContractPath, [string] $CorpusDir, [string] $GridsPath, [string] $PackDir, [string] $NotBefore, [switch] $Quiet)'
        $stubBody = @'
$bomEnc = New-Object System.Text.UTF8Encoding($true)
foreach ($p in @($ReportPath, $ResultPath, $OutPath)) { if ($p) { [System.IO.File]::WriteAllText($p, '{"stub":true}', $bomEnc) } }
if ($All -and $ResultDir) {
    if (-not (Test-Path -LiteralPath $ResultDir)) { New-Item -ItemType Directory -Force -Path $ResultDir | Out-Null }
    foreach ($f in (Get-ChildItem -LiteralPath (Join-Path $BuildDir 'spine') -Filter 't*_*.json' -File | Where-Object { $_.Name -notmatch '_topic\.json$' })) {
        [System.IO.File]::WriteAllText((Join-Path $ResultDir ($f.Name + '.gate.json')), '{"verdict":"pass","blocks":[]}', $bomEnc)
    }
}
Write-Host 'stub ran'
Write-Host 'ARMS: main|true|ran|3|0'
exit 0
'@
        $stubBodyFailFile = @'
$bomEnc = New-Object System.Text.UTF8Encoding($true)
if (-not (Test-Path -LiteralPath $ResultDir)) { New-Item -ItemType Directory -Force -Path $ResultDir | Out-Null }
[System.IO.File]::WriteAllText((Join-Path $ResultDir 't1_1.1.json.gate.json'), '{"verdict":"fail","blocks":[{"arm":"mirror-own","text":"PLANTED per-file fail"}]}', $bomEnc)
Write-Host 'every file exit 0 (PLANTED: the wrapper lies)'
Write-Host 'ARMS: main|true|ran|3|0'
exit 0
'@
        $stubBodyArmNotRun = "Write-Host 'every rule ran (PLANTED: it did not)'`r`nWrite-Host 'ARMS: counts|true|ran|5|0;keMap|true|not-run|0|0'`r`nexit 0"
        $stubBodyMoveSpine = @'
[System.IO.File]::AppendAllText((Join-Path $BuildDir 'spine\t1_1.1.json'), ' ')
Write-Host 'PLANTED: spine edited during phase 1'
Write-Host 'ARMS: main|true|ran|3|0'
exit 0
'@
        function Write-Stub {
            param([string] $Name, [string] $Body, [string] $Header = '# GATE: stages=3c; requires=BuildDir')
            [System.IO.File]::WriteAllText((Join-Path $fxScripts ($Name + '.ps1')), ($Header + "`r`n" + $stubParams + "`r`n" + $Body + "`r`n"), $bom)
        }
        foreach ($n in $script:GateOrder) {
            if ($n -eq 'New-FigureSheet') { continue }
            if ($n -eq 'Assert-GateFixtures') { Write-Stub -Name $n -Body $stubBody -Header '# GATE: stages=3c; requires=SkillDir' } else { Write-Stub -Name $n -Body $stubBody }
        }
        $fxBuild = Join-Path $tmp 'fxbuild'
        $fxSpine = Join-Path $fxBuild 'spine'
        New-Item -ItemType Directory -Force -Path $fxSpine | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $fxSpine 't1_1.1.json'), '{"pc":"1.1","visuals":[{"slot":"1.1.1","kind":"photo","caption":"A caption","alt":"An alt"}]}', $utf8)
        [System.IO.File]::WriteAllText((Join-Path $fxSpine 't1_topic.json'), '{"topic":1}', $utf8)
        [System.IO.File]::WriteAllText((Join-Path $fxSpine 'cover.json'), '{"visual":{"slot":"cover","kind":"photo","caption":"Cover caption","alt":"Cover alt"}}', $utf8)
        [System.IO.File]::WriteAllText((Join-Path $fxBuild 'contract.json'), '{"unit":{"code":"TEST001"},"build":{"brand":"mvc"},"topics":[{"n":1,"pcs":["1.1"]}]}', $utf8)
        [System.IO.File]::WriteAllText((Join-Path $fxBuild 'unit_extract.md'), '# Performance Evidence', $utf8)
        $fxOk = $true
        foreach ($n in $script:GateOrder) { if (-not (Test-Path -LiteralPath (Join-Path $fxScripts ($n + '.ps1')))) { $fxOk = $false; Bad "fixture gate not written: $n" } }
        if (-not ((Get-Content -LiteralPath (Join-Path $fxScripts 'Test-Spine.ps1') -Raw) -match 'ARMS: main')) { $fxOk = $false; Bad 'fixture stub lacks its ARMS marker' }
        if (-not ((Get-Content -LiteralPath (Join-Path $fxSpine 'cover.json') -Raw) -match '"visual"')) { $fxOk = $false; Bad 'fixture cover.json lacks its singular visual' }
        if ($fxOk) { Ok ('fixture skill written: {0} stub gates with GATE headers, the real New-FigureSheet and Lib-GateCommon, a 3-file spine with a cover visual' -f ($script:GateOrder.Count - 1)) }

        function Invoke-ChildRunner {
            param([string[]] $Arguments, [string] $LogName)
            $global:LASTEXITCODE = 0
            $out = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $self @Arguments 2>&1 | ForEach-Object { "$_" })
            $code = $LASTEXITCODE
            [System.IO.File]::WriteAllText((Join-Path $tmp $LogName), ($out -join "`r`n"), $bom)
            return [pscustomobject]@{ Code = $code; Text = ($out -join "`n") }
        }
        function Get-SheetStamp { param([string] $Path, [string] $Key) if (-not (Test-Path -LiteralPath $Path)) { return '' }; foreach ($ln in [System.IO.File]::ReadAllLines($Path)) { if ($ln -match ('^' + [regex]::Escape($Key) + ':\s*(.*)$')) { return $Matches[1].Trim() } }; return '' }
        #  -NoPlantChannel on the scripted runs: the channel is a detached
        #  background process and these runs assert on the band, not on it.
        #  One run below is made WITHOUT it, and that one proves it starts.
        $commonPlant = @('-BuildDir', $fxBuild, '-SkillDir', $fxSkill, '-MaxJobs', '8', '-TimeoutMinutes', '2')
        $common = $commonPlant + @('-NoPlantChannel')
        $fxResults = Join-Path $fxBuild '3c-results.json'
        $fxPartial = Join-Path $fxBuild '3c-results.partial.json'
        $fxBand = Join-Path $fxBuild '3c-band-verdict.json'
        $fxSheet = Join-Path $fxBuild 'figure-sheet.txt'

        # ---- (a) a green band: verdict file before the sheet, stamps agree, cover row present
        $swE2E = [System.Diagnostics.Stopwatch]::StartNew()
        $ra = Invoke-ChildRunner -Arguments $common -LogName 'e2e-a-green.log'
        $ja = $null; if (Test-Path -LiteralPath $fxResults) { $ja = Read-JsonFile -Path $fxResults }
        $jb = $null; if (Test-Path -LiteralPath $fxBand) { $jb = Read-JsonFile -Path $fxBand }
        Write-Host ("        (green band over the fixture: exit {0}, {1}s)" -f $ra.Code, [math]::Round($swE2E.Elapsed.TotalSeconds, 1)) -ForegroundColor DarkGray
        if ($ra.Code -eq 0 -and $ja -and $ja.verdict -eq 'PASS' -and $ja.exitCode -eq 0 -and $ja.stage -eq '3c' -and $ja.seed -eq $false) { Ok 'end to end: the fixture band passes, exit 0, 3c-results.json says PASS / stage 3c / seed false' } else { Bad ("green band: exit {0} verdict '{1}' - see {2}" -f $ra.Code, $(if ($ja) { $ja.verdict } else { 'no results file' }), (Join-Path $tmp 'e2e-a-green.log')) }
        if ($ja -and $ja.figureSheet -eq 'cut' -and (Test-Path -LiteralPath $fxSheet)) { Ok "figureSheet is 'cut' and the sheet exists" } else { Bad "figureSheet='$($ja.figureSheet)' sheet exists=$(Test-Path -LiteralPath $fxSheet)" }
        $stampFp = Get-SheetStamp -Path $fxSheet -Key 'SPINE-FINGERPRINT'; $stampBv = Get-SheetStamp -Path $fxSheet -Key 'BAND-VERDICT'; $stampRan = Get-SheetStamp -Path $fxSheet -Key 'BAND-RAN-AT'
        if ($jb -and $jb.verdict -eq 'PASS' -and $jb.partial -eq $false -and $jb.exitCode -eq 0 -and $jb.spineFingerprint -eq $stampFp -and $jb.spineFingerprint -eq $ja.spineFingerprintAtJoin -and $stampBv -eq 'PASS' -and $stampRan -eq $jb.ranAt) { Ok '3c-band-verdict.json existed before the cut: the sheet stamps its fingerprint, PASS and its ranAt exactly' } else { Bad ("band verdict vs sheet: file verdict '{0}' fp '{1}' vs stamp '{2}' bv '{3}' ranAt '{4}' vs '{5}'" -f $(if ($jb) { $jb.verdict } else { 'absent' }), $(if ($jb) { $jb.spineFingerprint } else { '' }), $stampFp, $stampBv, $stampRan, $(if ($jb) { $jb.ranAt } else { '' })) }
        if ((Test-Path -LiteralPath $fxSheet) -and ((Get-Content -LiteralPath $fxSheet -Raw) -match 'spine file: cover\.json')) { Ok 'the sheet enumerates with front matter in: the cover row appears' } else { Bad 'no cover row on the sheet' }
        $vset = @('PASS', 'FAIL', 'NOT RUN', 'REFUSED')
        $badRec = @()
        foreach ($g in @($ja.gates)) {
            if ($vset -notcontains [string]$g.verdict) { $badRec += ("{0}: verdict '{1}'" -f $g.name, $g.verdict); continue }
            if (-not $g.ranAt) { $badRec += ("{0}: no ranAt" -f $g.name) }
            if ($g.verdict -eq 'PASS' -and ($null -eq $g.exitCode -or $g.exitCode -ne 0 -or -not $g.startedAt)) { $badRec += ("{0}: PASS without exitCode 0 / startedAt" -f $g.name) }
            if (-not (HasProp $g 'arms')) { $badRec += ("{0}: no arms" -f $g.name) }
        }
        if ($badRec.Count -eq 0 -and @($ja.gates).Count -eq $script:GateOrder.Count) { Ok ('every one of the {0} members records a verdict from PASS/FAIL/NOT RUN/REFUSED with exitCode, ranAt and an arms roster' -f @($ja.gates).Count) } else { Bad ("member records: " + ($badRec -join '; ') + " count=" + @($ja.gates).Count) }
        $gTs = @($ja.gates | Where-Object { $_.name -eq 'Test-Spine' })[0]
        if ($gTs -and @($gTs.arms).Count -eq 1 -and $gTs.arms[0].name -eq 'main' -and $gTs.arms[0].evidence -eq '3c' -and $gTs.fixtureProof -eq 'no fixtures report') { Ok "a member's ARMS line is recorded in the results (evidence '3c'); with no fixtures report each member says 'no fixtures report'" } else { Bad "Test-Spine record: arms=$(@($gTs.arms).Count) proof='$($gTs.fixtureProof)'" }
        if ((HasProp $ja 'defective') -and @($ja.defective).Count -eq 0 -and (HasProp $ja 'fixtures') -and $ja.bandVerdictFile -eq $fxBand) { Ok "the results carry 'defective' as an empty array, a fixtures block and the band verdict file path" } else { Bad 'results shape: defective / fixtures / bandVerdictFile missing' }

        # ---- (b) -Only: the band's evidence is untouched, the partial file is written
        $shaBefore = Get-FileSha256 -Path $fxResults
        $bandShaBefore = Get-FileSha256 -Path $fxBand
        $rb = Invoke-ChildRunner -Arguments ($common + @('-Only', 'Test-Spine')) -LogName 'e2e-b-only.log'
        $shaAfter = Get-FileSha256 -Path $fxResults
        $jp = $null; if (Test-Path -LiteralPath $fxPartial) { $jp = Read-JsonFile -Path $fxPartial }
        if ($rb.Code -eq 3 -and $shaBefore -and $shaBefore -eq $shaAfter -and $jp -and $jp.partial -eq $true -and $jp.verdict -eq 'PARTIAL' -and @($jp.gates).Count -eq 1) { Ok "-Only leaves 3c-results.json's sha256 unchanged, writes 3c-results.partial.json (partial true, PARTIAL, exit 3)" } else { Bad ("-Only: exit {0} sha same={1} partial file={2} - see {3}" -f $rb.Code, ($shaBefore -eq $shaAfter), ($null -ne $jp), (Join-Path $tmp 'e2e-b-only.log')) }
        if ((Get-FileSha256 -Path $fxBand) -eq $bandShaBefore -and (Test-Path -LiteralPath (Join-Path $fxBuild '3c-band-verdict.partial.json'))) { Ok 'and the band verdict file is untouched too - the partial run wrote 3c-band-verdict.partial.json' } else { Bad 'a partial run touched 3c-band-verdict.json' }

        # ---- (c) the spine moves during phase 1: no sheet, both fingerprints named
        Remove-Item -LiteralPath $fxSheet -Force
        Write-Stub -Name 'Test-Spine' -Body $stubBodyMoveSpine
        if (-not ((Get-Content -LiteralPath (Join-Path $fxScripts 'Test-Spine.ps1') -Raw) -match 'AppendAllText')) { Bad 'the spine-moving stub was not planted' }
        $rcv = Invoke-ChildRunner -Arguments $common -LogName 'e2e-c-moved.log'
        $jc = $null; if (Test-Path -LiteralPath $fxResults) { $jc = Read-JsonFile -Path $fxResults }
        $jcb = $null; if (Test-Path -LiteralPath $fxBand) { $jcb = Read-JsonFile -Path $fxBand }
        $gSheet = if ($jc) { @($jc.gates | Where-Object { $_.name -eq 'New-FigureSheet' })[0] } else { $null }
        if ($rcv.Code -eq 1 -and -not (Test-Path -LiteralPath $fxSheet) -and $jc -and $jc.figureSheet -like 'REFUSED*' -and $jc.spineFingerprint -ne $jc.spineFingerprintAtJoin -and $jc.figureSheet.Contains($jc.spineFingerprint) -and $jc.figureSheet.Contains($jc.spineFingerprintAtJoin) -and $gSheet -and $gSheet.verdict -eq 'REFUSED') { Ok 'a spine edit during phase 1 leaves NO figure-sheet.txt; the cut is REFUSED naming both fingerprints; the band fails' } else { Bad ("moved spine: exit {0} sheet exists={1} figureSheet='{2}' - see {3}" -f $rcv.Code, (Test-Path -LiteralPath $fxSheet), $(if ($jc) { $jc.figureSheet } else { '' }), (Join-Path $tmp 'e2e-c-moved.log')) }
        if ($jcb -and $jcb.verdict -eq 'FAIL' -and $jcb.spineMovedDuringBand -eq $true -and @($jcb.failed) -contains 'spine-changed-during-run') { Ok 'and the band verdict file written at the join says FAIL / spineMovedDuringBand' } else { Bad "band verdict after move: $(if ($jcb) { $jcb.verdict } else { 'absent' })" }
        Write-Stub -Name 'Test-Spine' -Body $stubBody

        # ---- (d) a per-file gate.json says fail while the wrapper exits 0; a fixtures report names UNPROVEN
        Write-Stub -Name 'Test-SubSection' -Body $stubBodyFailFile
        if (-not ((Get-Content -LiteralPath (Join-Path $fxScripts 'Test-SubSection.ps1') -Raw) -match 'PLANTED per-file fail')) { Bad 'the per-file-fail stub was not planted' }
        $fxFixDir = Join-Path $fxBuild 'fixtures'
        New-Item -ItemType Directory -Force -Path $fxFixDir | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $fxFixDir 'gate-fixtures.feedface.json'), '{"results":[{"Gate":"Test-Spine","Verdict":"PROVEN"},{"Gate":"Test-SpineRead","Verdict":"UNPROVEN"}]}', $bom)
        $rd = Invoke-ChildRunner -Arguments $common -LogName 'e2e-d-perfile.log'
        $jd = $null; if (Test-Path -LiteralPath $fxResults) { $jd = Read-JsonFile -Path $fxResults }
        $gSs = if ($jd) { @($jd.gates | Where-Object { $_.name -eq 'Test-SubSection' })[0] } else { $null }
        if ($rd.Code -eq 1 -and $gSs -and $gSs.verdict -eq 'FAIL' -and $gSs.exitCode -eq 0 -and $gSs.reason -match 't1_1\.1\.json=fail' -and @($jd.failed) -contains 'Test-SubSection' -and $jd.figureSheet -like 'NOT RUN*' -and -not (Test-Path -LiteralPath $fxSheet)) { Ok 'a planted per-file fail makes the wrapper entry FAIL naming the file over its exit 0; the band fails; no sheet' } else { Bad ("per-file fail: exit {0} wrapper verdict '{1}' reason '{2}' - see {3}" -f $rd.Code, $(if ($gSs) { $gSs.verdict } else { '' }), $(if ($gSs) { $gSs.reason } else { '' }), (Join-Path $tmp 'e2e-d-perfile.log')) }
        $gTs2 = if ($jd) { @($jd.gates | Where-Object { $_.name -eq 'Test-Spine' })[0] } else { $null }
        $gTr2 = if ($jd) { @($jd.gates | Where-Object { $_.name -eq 'Test-SpineRead' })[0] } else { $null }
        if ($gTs2 -and $gTs2.fixtureProof -eq 'PROVEN' -and $gTr2 -and $gTr2.fixtureProof -like 'UNPROVEN*' -and $jd.fixtures.hash -eq 'feedface' -and @($jd.fixtures.unproven) -contains 'Test-SpineRead' -and $rd.Text -match 'UNPROVEN') { Ok 'with a gate-fixtures.<hash>.json under the build, UNPROVEN is printed and recorded beside every member it did not prove' } else { Bad "fixture proof in results: ts='$($gTs2.fixtureProof)' tsr='$($gTr2.fixtureProof)' hash='$($jd.fixtures.hash)'" }
        Write-Stub -Name 'Test-SubSection' -Body $stubBody

        # ---- (d2) a script the roster never heard of, with a 3c header, is a member
        Write-Stub -Name 'Assert-ScratchMember' -Body $stubBody -Header '# GATE: stages=3c; requires=BuildDir'
        if (-not ((Get-Content -LiteralPath (Join-Path $fxScripts 'Assert-ScratchMember.ps1') -Raw) -match 'GATE: stages=3c')) { Bad 'the scratch member was written without its header' }
        $inDisc = @{ BuildDir = $fxBuild; SkillDir = $fxSkill; SpineDir = $fxSpine; UnitExtract = (Join-Path $fxBuild 'unit_extract.md'); ResultDir = (Join-Path $fxBuild '3c'); Profile = ''; Stage = '3c'; Register = (Join-Path $fxBuild 'withhold-register.json'); Cells = (Join-Path $fxBuild 'assessor-cells.json'); Rules = (Join-Path $fxBuild 'figures.json') }
        $planDisc = @(New-SpineGatePlan -In $inDisc)
        $eDisc = @($planDisc | Where-Object { $_.Name -eq 'Assert-ScratchMember' })[0]
        if ($eDisc -and -not $eDisc.Refused -and $eDisc.Phase -eq 1 -and $eDisc.Args['BuildDir'] -eq $fxBuild -and $script:GateOrder -notcontains 'Assert-ScratchMember') { Ok 'a script the roster has never heard of joins the band from its own "# GATE: stages=3c" header and is handed -BuildDir - membership is derived, never hand-listed' } else { Bad ("scratch member: {0}" -f $(if ($eDisc) { ("refused='{0}' phase={1}" -f $eDisc.Refused, $eDisc.Phase) } else { 'not in the plan' })) }
        $rDisc = Invoke-ChildRunner -Arguments $common -LogName 'e2e-d2-discovered.log'
        $jDisc = $null; if (Test-Path -LiteralPath $fxResults) { $jDisc = Read-JsonFile -Path $fxResults }
        $gDisc = if ($jDisc) { @($jDisc.gates | Where-Object { $_.name -eq 'Assert-ScratchMember' })[0] } else { $null }
        if ($rDisc.Code -eq 0 -and $gDisc -and $gDisc.verdict -eq 'PASS' -and $gDisc.header -match 'stages=3c') { Ok 'and it RAN in the band, with its header recorded in the results' } else { Bad ("discovered member run: exit {0} - see {1}" -f $rDisc.Code, (Join-Path $tmp 'e2e-d2-discovered.log')) }
        Remove-Item -LiteralPath (Join-Path $fxScripts 'Assert-ScratchMember.ps1') -Force

        # ---- (d3) a blocking arm the member never ran: NOT-RUN, band FAIL, both named
        Write-Stub -Name 'Assert-SpineCounts' -Body $stubBodyArmNotRun
        if (-not ((Get-Content -LiteralPath (Join-Path $fxScripts 'Assert-SpineCounts.ps1') -Raw) -match 'keMap\|true\|not-run')) { Bad 'the never-run-arm stub was not planted' }
        #  The green band of (d2) cut a sheet. Remove it, or "no sheet was cut"
        #  would be asserted against an earlier run's file.
        if (Test-Path -LiteralPath $fxSheet) { Remove-Item -LiteralPath $fxSheet -Force }
        $rArm = Invoke-ChildRunner -Arguments $common -LogName 'e2e-d3-armnotrun.log'
        $jArm = $null; if (Test-Path -LiteralPath $fxResults) { $jArm = Read-JsonFile -Path $fxResults }
        $gArm = if ($jArm) { @($jArm.gates | Where-Object { $_.name -eq 'Assert-SpineCounts' })[0] } else { $null }
        if ($rArm.Code -eq 1 -and $gArm -and $gArm.verdict -eq 'FAIL' -and $gArm.exitCode -eq 0 -and $gArm.reason -match 'arm not run: keMap' -and @($gArm.armsBlockingNotRun) -contains 'keMap' -and @($jArm.failed) -contains 'Assert-SpineCounts' -and $rArm.Text -match 'Assert-SpineCounts: blocking arm\(s\) never ran: keMap' -and -not (Test-Path -LiteralPath $fxSheet)) { Ok 'a member that exits 0 with a BLOCKING arm neither ran nor declared is NOT-RUN: the member FAILS, the band FAILS naming member and arm, and no sheet is cut' } else { Bad ("arm not run: exit {0} verdict '{1}' reason '{2}' - see {3}" -f $rArm.Code, $(if ($gArm) { $gArm.verdict } else { '' }), $(if ($gArm) { $gArm.reason } else { '' }), (Join-Path $tmp 'e2e-d3-armnotrun.log')) }
        Write-Stub -Name 'Assert-SpineCounts' -Body $stubBody

        # ---- (d5) a member that exits 4 is GATE-DEFECT: defective[], no PASS,
        #      no sheet - and the same member exiting 1 is an ordinary failure
        $stubBodyGateDefect = @'
Write-Host "  X GATE-DEFECT: Assert-SpineCounts: rule 'spine-ref-not-in-pack': the quote 'Observation 1 item' cannot be re-found at a token boundary in uat.txt"
Write-Host 'ANCHORS: tested 1, anchored 0, unresolved 1'
Write-Host 'ARMS: main|true|ran|3|1'
exit 4
'@
        $stubBodyContentFail = "Write-Host 'X one blocking finding, anchor re-found'`r`nWrite-Host 'ANCHORS: tested 1, anchored 1, unresolved 0'`r`nWrite-Host 'ARMS: main|true|ran|3|1'`r`nexit 1"
        Write-Stub -Name 'Assert-SpineCounts' -Body $stubBodyGateDefect
        if (-not ((Get-Content -LiteralPath (Join-Path $fxScripts 'Assert-SpineCounts.ps1') -Raw) -match 'exit 4')) { Bad 'the GATE-DEFECT stub was not planted' }
        if (Test-Path -LiteralPath $fxSheet) { Remove-Item -LiteralPath $fxSheet -Force }
        $rGd = Invoke-ChildRunner -Arguments $common -LogName 'e2e-d5-gatedefect.log'
        $jGd = $null; if (Test-Path -LiteralPath $fxResults) { $jGd = Read-JsonFile -Path $fxResults }
        $jGdb = $null; if (Test-Path -LiteralPath $fxBand) { $jGdb = Read-JsonFile -Path $fxBand }
        $gGd = if ($jGd) { @($jGd.gates | Where-Object { $_.name -eq 'Assert-SpineCounts' })[0] } else { $null }
        if ($rGd.Code -eq 1 -and $gGd -and $gGd.verdict -eq 'GATE-DEFECT' -and $gGd.exitCode -eq 4 -and @($jGd.defective) -contains 'Assert-SpineCounts' -and @($jGd.failed) -notcontains 'Assert-SpineCounts' -and $jGd.verdict -eq 'GATE-DEFECT') { Ok 'PLANT a member exiting 4 takes the verdict GATE-DEFECT, lands in defective[] and NOT in failed[], and the band verdict is GATE-DEFECT - never PASS' } else { Bad ("gate defect e2e: exit {0} member verdict '{1}' band '{2}' defective=[{3}] failed=[{4}] - see {5}" -f $rGd.Code, $(if ($gGd) { $gGd.verdict } else { '' }), $(if ($jGd) { $jGd.verdict } else { '' }), $(if ($jGd) { (@($jGd.defective) -join ',') } else { '' }), $(if ($jGd) { (@($jGd.failed) -join ',') } else { '' }), (Join-Path $tmp 'e2e-d5-gatedefect.log')) }
        if (-not (Test-Path -LiteralPath $fxSheet) -and $jGd -and $jGd.figureSheet -like 'NOT RUN*' -and $jGd.figureSheet -match 'GATE-DEFECT' -and $jGd.figureSheetPath -eq '') { Ok 'and NO figure sheet is cut: the note names the GATE-DEFECT member, not a failed spine' } else { Bad ("gate defect sheet: exists={0} note='{1}'" -f (Test-Path -LiteralPath $fxSheet), $(if ($jGd) { $jGd.figureSheet } else { '' })) }
        if ($jGdb -and $jGdb.verdict -eq 'GATE-DEFECT' -and @($jGdb.defective) -contains 'Assert-SpineCounts' -and @($jGdb.failed).Count -eq 0) { Ok 'and the band verdict file written at the join says GATE-DEFECT with an empty failed[]' } else { Bad ("gate defect band verdict file: {0}" -f $(if ($jGdb) { $jGdb.verdict } else { 'absent' })) }
        Write-Stub -Name 'Assert-SpineCounts' -Body $stubBodyContentFail
        if (Test-Path -LiteralPath $fxSheet) { Remove-Item -LiteralPath $fxSheet -Force }
        $rCf = Invoke-ChildRunner -Arguments $common -LogName 'e2e-d5b-contentfail.log'
        $jCf = $null; if (Test-Path -LiteralPath $fxResults) { $jCf = Read-JsonFile -Path $fxResults }
        $gCf = if ($jCf) { @($jCf.gates | Where-Object { $_.name -eq 'Assert-SpineCounts' })[0] } else { $null }
        if ($rCf.Code -eq 1 -and $gCf -and $gCf.verdict -eq 'FAIL' -and $gCf.exitCode -eq 1 -and @($jCf.failed) -contains 'Assert-SpineCounts' -and @($jCf.defective).Count -eq 0 -and $jCf.verdict -eq 'FAIL' -and -not (Test-Path -LiteralPath $fxSheet)) { Ok 'CONTROL the same member exiting 1 is an ordinary content failure: FAIL, in failed[], defective[] empty, band FAIL, no sheet' } else { Bad ("content fail e2e: exit {0} verdict '{1}' band '{2}' defective=[{3}] - see {4}" -f $rCf.Code, $(if ($gCf) { $gCf.verdict } else { '' }), $(if ($jCf) { $jCf.verdict } else { '' }), $(if ($jCf) { (@($jCf.defective) -join ',') } else { '' }), (Join-Path $tmp 'e2e-d5b-contentfail.log')) }
        Write-Stub -Name 'Assert-SpineCounts' -Body $stubBody

        # ---- (d4) the plant channel is STARTED and never waited for
        $swPlant = [System.Diagnostics.Stopwatch]::StartNew()
        $rPlant = Invoke-ChildRunner -Arguments $commonPlant -LogName 'e2e-d4-plant.log'
        $swPlant.Stop()
        $jPlant = $null; if (Test-Path -LiteralPath $fxResults) { $jPlant = Read-JsonFile -Path $fxResults }
        $statePath = Join-Path $fxBuild 'fixtures\plant-channel.json'
        if ($rPlant.Code -eq 0 -and $jPlant -and $jPlant.plantChannel.action -eq 'start' -and $jPlant.plantChannel.started -eq $true -and $jPlant.plantChannel.waitedFor -eq $false -and $jPlant.plantChannel.scriptsHash -match '^[0-9a-f]{8}$' -and (Test-Path -LiteralPath $statePath) -and $rPlant.Text -match 'plant channel: STARTED') { Ok ("the full plant channel is started detached after the band, keyed on the scripts hash, and the band did not wait for it (band run {0}s)" -f [math]::Round($swPlant.Elapsed.TotalSeconds, 1)) } else { Bad ("plant channel: exit {0} action '{1}' - see {2}" -f $rPlant.Code, $(if ($jPlant) { $jPlant.plantChannel.action } else { 'no results' }), (Join-Path $tmp 'e2e-d4-plant.log')) }
        $rPlant2 = Invoke-ChildRunner -Arguments $commonPlant -LogName 'e2e-d5-plant2.log'
        $jPlant2 = $null; if (Test-Path -LiteralPath $fxResults) { $jPlant2 = Read-JsonFile -Path $fxResults }
        if ($rPlant2.Code -eq 0 -and $jPlant2 -and $jPlant2.plantChannel.action -eq 'running') { Ok 'a second band over the same scripts does not start a second channel' } else { Bad ("second plant decision: {0} - see {1}" -f $(if ($jPlant2) { $jPlant2.plantChannel.action } else { 'no results' }), (Join-Path $tmp 'e2e-d5-plant2.log')) }
        Remove-Item -LiteralPath $statePath -Force -ErrorAction SilentlyContinue

        # ---- (e) stages 1 and 2 from headers: empty is a refusal, declared members run as seed
        $re0 = Invoke-ChildRunner -Arguments ($common + @('-Stage', '1')) -LogName 'e2e-e0-stage1-empty.log'
        $j10 = $null; if (Test-Path -LiteralPath (Join-Path $fxBuild '1-results.json')) { $j10 = Read-JsonFile -Path (Join-Path $fxBuild '1-results.json') }
        if ($re0.Code -eq 2 -and $j10 -and $j10.verdict -eq 'FAIL' -and $j10.exitCode -eq 2 -and @($j10.gates).Count -eq 0 -and @($j10.failed) -contains 'no-member-declared') { Ok '-Stage 1 with no script declaring stages=1 is REFUSED (exit 2) and 1-results.json records FAIL with no member - never a pass' } else { Bad ("empty stage 1: exit {0} - see {1}" -f $re0.Code, (Join-Path $tmp 'e2e-e0-stage1-empty.log')) }
        Write-Stub -Name 'Assert-CorpusComplete' -Body $stubBody -Header '# GATE: stages=1; requires=BuildDir'
        Write-Stub -Name 'Assert-PackSelfConsistency' -Body $stubBody -Header '# GATE: stages=1,2; requires=BuildDir; 1: Stage; 2: Stage'
        Write-Stub -Name 'Assert-IdentifierNamespace' -Body $stubBody -Header '# GATE: stages=2,3c; requires=BuildDir; 2: SeedOnly'
        $members1 = @(Get-HeaderDeclaredMember -SkillDir $fxSkill -Stage '1')
        $members2 = @(Get-HeaderDeclaredMember -SkillDir $fxSkill -Stage '2')
        if (($members1 -join ',') -eq 'Assert-CorpusComplete,Assert-PackSelfConsistency' -and ($members2 -join ',') -eq 'Assert-IdentifierNamespace,Assert-PackSelfConsistency') { Ok 'stage membership is derived from the headers: stage 1 = CorpusComplete, PackSelfConsistency; stage 2 = IdentifierNamespace (roster order first), PackSelfConsistency' } else { Bad ("stage members: 1=[{0}] 2=[{1}]" -f ($members1 -join ','), ($members2 -join ',')) }
        $needs = Join-Path $fxScripts 'Assert-NeedsDocText.ps1'
        [System.IO.File]::WriteAllText($needs, "# GATE: stages=1; requires=BuildDir,DocText`r`nparam([string] `$BuildDir, [string] `$DocText)`r`nexit 0`r`n", $bom)
        $in1 = @{ BuildDir = $fxBuild; SkillDir = $fxSkill; SpineDir = $fxSpine; UnitExtract = (Join-Path $fxBuild 'unit_extract.md'); ResultDir = (Join-Path $fxBuild '1'); Profile = ''; Stage = '1'; Register = (Join-Path $fxBuild 'withhold-register.json'); Cells = (Join-Path $fxBuild 'assessor-cells.json'); Rules = (Join-Path $fxBuild 'figures.json') }
        $plan1 = @(New-SpineGatePlan -In $in1)
        $eNeeds = @($plan1 | Where-Object { $_.Name -eq 'Assert-NeedsDocText' })[0]
        $ePsc = @($plan1 | Where-Object { $_.Name -eq 'Assert-PackSelfConsistency' })[0]
        if ($eNeeds -and $eNeeds.Refused -match '-DocText' -and $ePsc -and -not $ePsc.Refused -and $ePsc.Args['Stage'] -eq 1 -and $ePsc.Must -contains 'Stage' -and @($plan1 | Where-Object { $_.Phase -ne 1 }).Count -eq 0) { Ok 'a stage 1 plan refuses a header that requires -DocText by name, threads -Stage 1 as a MUST to PackSelfConsistency, and has no phase 2 or 3' } else { Bad ("stage 1 plan: needs refused='{0}' psc refused='{1}' stage={2}" -f $(if ($eNeeds) { $eNeeds.Refused } else { 'absent' }), $(if ($ePsc) { $ePsc.Refused } else { 'absent' }), $(if ($ePsc) { $ePsc.Args['Stage'] } else { '' })) }
        Remove-Item -LiteralPath $needs -Force
        $re1 = Invoke-ChildRunner -Arguments ($common + @('-Stage', '1')) -LogName 'e2e-e1-stage1.log'
        $j1 = $null; if (Test-Path -LiteralPath (Join-Path $fxBuild '1-results.json')) { $j1 = Read-JsonFile -Path (Join-Path $fxBuild '1-results.json') }
        $g1 = if ($j1) { @($j1.gates | Where-Object { $_.name -eq 'Assert-PackSelfConsistency' })[0] } else { $null }
        if ($re1.Code -eq 0 -and $j1 -and $j1.stage -eq '1' -and $j1.seed -eq $true -and $j1.verdict -eq 'PASS' -and @($j1.gates).Count -eq 2 -and $g1 -and $g1.evidence -eq 'seed' -and $g1.arms[0].evidence -eq 'seed' -and $g1.params.Stage -eq 1 -and $j1.figureSheet -eq 'not in this run') { Ok "-Stage 1 on the fixture writes 1-results.json: stage '1', seed true, 2 members, every arm labelled 'seed', -Stage 1 threaded, no sheet" } else { Bad ("stage 1 run: exit {0} - see {1}" -f $re1.Code, (Join-Path $tmp 'e2e-e1-stage1.log')) }
        $re2 = Invoke-ChildRunner -Arguments ($common + @('-Stage', '2')) -LogName 'e2e-e2-stage2.log'
        $j2 = $null; if (Test-Path -LiteralPath (Join-Path $fxBuild '2-results.json')) { $j2 = Read-JsonFile -Path (Join-Path $fxBuild '2-results.json') }
        $g2 = if ($j2) { @($j2.gates | Where-Object { $_.name -eq 'Assert-IdentifierNamespace' })[0] } else { $null }
        if ($re2.Code -eq 0 -and $j2 -and $j2.stage -eq '2' -and $j2.seed -eq $true -and @($j2.gates).Count -eq 2 -and $g2 -and $g2.params.SeedOnly -eq $true -and $g2.params.Stage -eq 2 -and (Test-Path -LiteralPath $fxResults)) { Ok "-Stage 2 writes 2-results.json with -SeedOnly and -Stage 2 threaded; 3c-results.json is untouched by a seed run" } else { Bad ("stage 2 run: exit {0} - see {1}" -f $re2.Code, (Join-Path $tmp 'e2e-e2-stage2.log')) }
        Write-Host ("        (end to end: {0}s for six child runs)" -f [math]::Round($swE2E.Elapsed.TotalSeconds, 1)) -ForegroundColor DarkGray
    }
    finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }

    Write-Host ''
    Write-Host ("  {0} passed, {1} failed" -f $pass, $fail) -ForegroundColor $(if ($fail) { 'Red' } else { 'Green' })
    if ($fail) { exit 4 }
    exit 0
}

# ---------------------------------------------------------------------------
# 6. Resolve every input
# ---------------------------------------------------------------------------

if (-not $BuildDir) { Write-Host 'Run-SpineGates: -BuildDir is required (or -SelfTest).' -ForegroundColor Red; exit 2 }
if (-not (Test-Path -LiteralPath $BuildDir)) { Write-Host "Run-SpineGates: build directory not found: $BuildDir" -ForegroundColor Red; exit 2 }
$BuildDir = (Resolve-Path -LiteralPath $BuildDir).Path
$SkillDir = (Resolve-Path -LiteralPath $SkillDir).Path
if ($MaxJobs -lt 1) { Write-Host 'Run-SpineGates: -MaxJobs must be at least 1.' -ForegroundColor Red; exit 2 }
if ($TimeoutMinutes -lt 1) { Write-Host 'Run-SpineGates: -TimeoutMinutes must be at least 1.' -ForegroundColor Red; exit 2 }
$isBand = ($Stage -eq '3c')
$evidence = if ($isBand) { '3c' } else { 'seed' }

$derived = New-Object System.Collections.Generic.List[string]

#  The spine is REQUIRED at 3c and OPTIONAL at stages 1 and 2, which run
#  before authoring opens: the seed bands read the corpus, the contract and
#  the registry, and the spine, when one exists from an earlier round, is
#  fingerprinted so the record says which spine was on disk.
if (-not $SpineDir) { $SpineDir = Join-Path $BuildDir 'spine'; $derived.Add("SpineDir spine\ under the build") }
$spineFiles = @()
if (Test-Path -LiteralPath $SpineDir) {
    $SpineDir = (Resolve-Path -LiteralPath $SpineDir).Path
    $spineFiles = @(Get-ChildItem -LiteralPath $SpineDir -Filter '*.json' -File)
}
if ($isBand) {
    if (-not (Test-Path -LiteralPath $SpineDir)) { Write-Host "Run-SpineGates: no spine at $SpineDir - there is nothing to gate. The band runs after authoring closes." -ForegroundColor Red; exit 2 }
    if ($spineFiles.Count -eq 0) { Write-Host "Run-SpineGates: the spine directory holds no JSON: $SpineDir" -ForegroundColor Red; exit 2 }
}
elseif (-not (Test-Path -LiteralPath $SpineDir)) { $derived.Add(("no spine at {0} - expected before authoring; stage {1} gates the corpus, the contract and the registry" -f $SpineDir, $Stage)) }

#  contract.json is REQUIRED at 3c (every member reads it) and read when
#  present at stages 1 and 2 - Stage 2 is where it is locked.
$contractPath = Join-Path $BuildDir 'contract.json'
$contract = $null
if (Test-Path -LiteralPath $contractPath) {
    try { $contract = Read-JsonFile -Path $contractPath } catch { Write-Host ("Run-SpineGates: contract.json does not parse: {0}" -f $_.Exception.Message) -ForegroundColor Red; exit 2 }
}
elseif ($isBand) { Write-Host "Run-SpineGates: no contract.json in $BuildDir - every gate in the band reads it." -ForegroundColor Red; exit 2 }
else { $derived.Add("no contract.json yet (Stage 2 locks it) - stage $Stage members that need it refuse by name") }
$unitCode = ''; $brand = ''
if ($contract -and (HasProp $contract 'unit') -and (HasProp $contract.unit 'code')) { $unitCode = [string]$contract.unit.code }
if ($contract -and (HasProp $contract 'build') -and (HasProp $contract.build 'brand')) { $brand = [string]$contract.build.brand }

if (-not $UnitExtract) { $UnitExtract = Join-Path $BuildDir 'unit_extract.md'; $derived.Add("UnitExtract unit_extract.md beside the build") }
if (-not (Test-Path -LiteralPath $UnitExtract)) {
    if ($isBand) {
        Write-Host ''
        Write-Host ("Run-SpineGates: REFUSED - no unit extract at {0}." -f $UnitExtract) -ForegroundColor Red
        Write-Host '  An assessor guide quotes the unit. Without the unit corpus the leakage sweep reports every unit line' -ForegroundColor Red
        Write-Host '  the guide teaches as assessor-only, and the row-coverage KE floor has no points to cover. Put the' -ForegroundColor Red
        Write-Host '  extract in place (Stage 1 writes it) and re-run. Nothing ran.' -ForegroundColor Red
        exit 2
    }
    $derived.Add(("no unit extract at {0} - offered to no stage {1} member; one whose header requires it refuses by name" -f $UnitExtract, $Stage))
}
else { $UnitExtract = (Resolve-Path -LiteralPath $UnitExtract).Path }

if ($Profile) {
    if (-not (Test-Path -LiteralPath $Profile)) { Write-Host "Run-SpineGates: -Profile not found: $Profile" -ForegroundColor Red; exit 2 }
    $Profile = (Resolve-Path -LiteralPath $Profile).Path
}
else {
    #  The lint resolves assets\rto-profile.<brand>.json itself. But the brand
    #  is the BUILD brand, and a profile pack belongs to the RTO whose approved
    #  templates the render used - so when no pack carries the brand's name and
    #  exactly one pack exists, that one is threaded, discovered the way
    #  Run-Gates discovers its template RTO, and printed. Two or more packs
    #  and none named for the brand is a decision the caller signs with -Profile.
    $assets = Join-Path $SkillDir 'assets'
    $packs = @(Get-ChildItem -LiteralPath $assets -Filter 'rto-profile.*.json' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '(?i)schema' })
    $byBrand = @($packs | Where-Object { $brand -and $_.Name -ieq ('rto-profile.' + $brand + '.json') })
    if ($byBrand.Count -eq 1) { $derived.Add("Profile: the prompt lint resolves $($byBrand[0].Name) from contract build.brand '$brand'") }
    elseif ($packs.Count -eq 1) { $Profile = $packs[0].FullName; $derived.Add("Profile '$($packs[0].Name)' - the one RTO profile pack in assets (no pack is named for brand '$brand')") }
    else { $derived.Add(("Profile: none given, {0} pack(s) in assets and none named for brand '{1}' - the prompt lint will refuse; pass -Profile" -f $packs.Count, $brand)) }
}

if (-not $ResultDir) { $ResultDir = Join-Path $BuildDir $Stage; $derived.Add("ResultDir $Stage\ under the build") }
if (-not (Test-Path -LiteralPath $ResultDir)) { New-Item -ItemType Directory -Force -Path $ResultDir | Out-Null }
$ResultDir = (Resolve-Path -LiteralPath $ResultDir).Path
if ((Test-Path -LiteralPath $SpineDir) -and $ResultDir.StartsWith($SpineDir, [StringComparison]::OrdinalIgnoreCase)) {
    Write-Host "Run-SpineGates: -ResultDir must not be under the spine directory - every whole-spine reader globs spine\*.json, and a gate.json beside a spine file is read as content." -ForegroundColor Red
    exit 2
}
$logDir = Join-Path $ResultDir 'logs'
$subDir = Join-Path $ResultDir 'subsections'
foreach ($d in @($logDir, $subDir)) { if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null } }

$partial = ($null -ne $Only -and @($Only).Count -gt 0)
$resultPath = Join-Path $BuildDir ($Stage + '-results.json')
$partialPath = Join-Path $BuildDir ($Stage + '-results.partial.json')
#  A partial run writes ONLY the partial file. The band's evidence is never
#  overwritten by a subset, and the interim verdict of a subset goes to its
#  own file too, so a sheet can never be cut against it by the default path.
$writePath = if ($partial) { $partialPath } else { $resultPath }
$bandVerdictPath = Join-Path $BuildDir $(if ($partial) { '3c-band-verdict.partial.json' } else { '3c-band-verdict.json' })
$sheetPath = Join-Path $BuildDir 'figure-sheet.txt'

#  The source pack the corpus was extracted from, read from the contract (never
#  guessed from a directory name). A stage 1 member whose header requires
#  -PackDir is handed this; when the contract names none, or names one that is
#  not on disk, the member is REFUSED naming the file it looked for.
#  The three key names are Assert-CorpusComplete's own fallback order (:628),
#  read here so the runner and the gate look for the same thing.
$packDir = ''
if ($contract -and (HasProp $contract 'build')) {
    $cand = [string](Get-GateProp -Object $contract.build -Names @('packDir', 'packDirectory', 'sourcePack') -Default '')
    if ($cand) {
        if (-not [System.IO.Path]::IsPathRooted($cand)) { $cand = Join-Path $BuildDir $cand }
        if (Test-Path -LiteralPath $cand) { $packDir = (Resolve-Path -LiteralPath $cand).Path; $derived.Add(("PackDir from contract build.packDir: {0}" -f $packDir)) }
        else { $derived.Add(("contract build.packDir is not on disk ({0}) - a member whose header requires -PackDir is refused naming it" -f $cand)) }
    }
}

$inputs = @{
    BuildDir = $BuildDir; SkillDir = $SkillDir; SpineDir = $SpineDir; UnitExtract = $UnitExtract
    ResultDir = $ResultDir; Profile = $Profile; Stage = $Stage; BandVerdictPath = $bandVerdictPath
    PackDir = $packDir
    Register = (Join-Path $BuildDir 'withhold-register.json')
    Cells    = (Join-Path $BuildDir 'assessor-cells.json')
    Rules    = (Join-Path $BuildDir 'figures.json')
}
foreach ($k in @('Register', 'Cells', 'Rules')) {
    $derived.Add(("{0}: {1}" -f $k, $(if (Test-Path -LiteralPath $inputs[$k]) { (Split-Path $inputs[$k] -Leaf) + ' beside the build' } else { 'absent - left to each gate''s own discovery and refusal' })))
}

#  Captured BEFORE any gate runs, and handed to the disposition as -NotBefore:
#  every report this band's producers write is stamped at or after it.
$runStartUtc = Get-UtcNow
$inputs['NotBefore'] = $runStartUtc

$fullPlan = @(New-SpineGatePlan -In $inputs)
if ($fullPlan.Count -eq 0) {
    #  A stage with no member is not a pass: nothing examined anything. The
    #  results file says so, in the same shape, so the ledger cannot read an
    #  absent file as "not yet run" and a hand note as a verdict.
    $why = ("no script under {0}\scripts declares stages={1} in a '# GATE:' header - the stage {1} band has no member and nothing ran. Members land their headers ('# GATE: stages={1}; requires=BuildDir') and this runner picks them up; nothing here is hand-listed." -f $SkillDir, $Stage)
    Write-Host ''
    Write-Host ("Run-SpineGates: REFUSED - {0}" -f $why) -ForegroundColor Red
    $empty = [ordered]@{
        runner = 'Run-SpineGates'; stage = $Stage; seed = (-not $isBand); ranAt = (Get-UtcNow)
        buildDir = $BuildDir; spineDir = $SpineDir; resultDir = $ResultDir
        spineFingerprint = (Get-SpineFingerprint -BuildDir $BuildDir -SpineDir $SpineDir -Quiet)
        partial = $partial; gates = @(); failed = @('no-member-declared'); defective = @()
        figureSheet = 'not in this run'; verdict = 'FAIL'; exitCode = 2; reason = $why
    }
    Write-JsonFile -Path $writePath -Body ([pscustomobject]$empty)
    Write-Host ("  results: {0}" -f $writePath) -ForegroundColor DarkGray
    exit 2
}
$plan = $fullPlan
if ($partial) {
    try { $plan = @(Select-PlanByOnly -Plan $fullPlan -Only $Only) }
    catch { Write-Host ("Run-SpineGates: {0}" -f $_.Exception.Message) -ForegroundColor Red; exit 2 }
}

#  Stale per-file results from an earlier run would be collected as this run's -
#  but only a run that includes the sub-section wrapper clears them. A partial
#  run of other gates must not destroy the band's evidence.
if (@($plan | Where-Object { $_.Name -eq 'Test-SubSection' }).Count -gt 0) {
    $stale = @(Get-ChildItem -LiteralPath $subDir -Filter '*.gate.json' -File -ErrorAction SilentlyContinue)
    if ($stale.Count -gt 0) { $stale | Remove-Item -Force; $derived.Add("cleared $($stale.Count) stale gate.json result(s) from $subDir") }
}
#  A stale band-verdict file from an earlier run must never be the one the
#  sheet is cut against: it is removed here and rewritten only at the join.
if ($isBand -and (Test-Path -LiteralPath $bandVerdictPath)) { Remove-Item -LiteralPath $bandVerdictPath -Force; $derived.Add("cleared the earlier $(Split-Path $bandVerdictPath -Leaf) - the join rewrites it") }

$fpBefore = Get-SpineFingerprint -BuildDir $BuildDir -SpineDir $SpineDir -Quiet
$timeout = $TimeoutMinutes * 60
$effectiveJobs = $(if ($Serial) { 1 } else { $MaxJobs })

Write-Host ''
Write-Host ("RUN-SPINEGATES  {0}  Stage {1}  spine {2} file(s)  fingerprint {3}" -f $(if ($unitCode) { $unitCode } else { Split-Path $BuildDir -Leaf }), $Stage, $spineFiles.Count, $(if ($fpBefore) { $fpBefore } else { '(no spine)' })) -ForegroundColor Cyan
Write-Host ("  {0} gate(s) planned, up to {1} at a time, {2} min per gate{3}" -f @($plan | Where-Object { -not $_.Refused }).Count, $effectiveJobs, $TimeoutMinutes, $(if ($Serial) { ' (-Serial)' } else { '' })) -ForegroundColor DarkGray
foreach ($d in $derived) { Write-Host ("  derived: {0}" -f $d) -ForegroundColor DarkGray }
foreach ($e in $plan) { foreach ($rp in @($e.Reports)) { Write-Host ("  REPORT {0}: {1}" -f $e.Name, $rp) -ForegroundColor Yellow } }
if (-not $isBand) { Write-Host ("  SEED RUN - stage {0} results are labelled 'seed' and never count as 3c evidence" -f $Stage) -ForegroundColor Yellow }
if ($partial) {
    Write-Host ''
    Write-Host '  ################################################################' -ForegroundColor Magenta
    Write-Host ("  #  PARTIAL RUN (-Only {0})" -f (($plan | ForEach-Object { $_.Name }) -join ', ')) -ForegroundColor Magenta
    Write-Host ("  #  This run cannot claim the band. No figure sheet. Exit 3 at best. Writes {0} only." -f (Split-Path $partialPath -Leaf)) -ForegroundColor Magenta
    Write-Host '  ################################################################' -ForegroundColor Magenta
}

# ---------------------------------------------------------------------------
# 7. Run - phase 1 fans out, phase 2 joins, phase 3 only on a green band
# ---------------------------------------------------------------------------

$swAll = [System.Diagnostics.Stopwatch]::StartNew()
$startedAtUtc = Get-UtcNow
$allRes = New-Object System.Collections.Generic.List[object]
$ran = New-Object System.Collections.Generic.List[object]   # plan entries that reached the runner, in order

function Show-PhaseResult {
    param($Entries, $Results)
    foreach ($e in $Entries) {
        $r = @($Results | Where-Object { $_.Name -eq $e.Name })[0]
        Write-Host ''
        $tag = if ($r.Ok) { 'PASS' } elseif ($r.Refused) { 'REFUSED' } else { 'FAIL' }
        $col = if ($r.Ok) { 'Green' } else { 'Red' }
        Write-Host ("{0}  [{1}]  {2}s" -f $e.Title, $tag, $r.Seconds) -ForegroundColor $col
        if ($r.Reason -and -not $r.Ok) { Write-Host ("    X {0}" -f $r.Reason) -ForegroundColor Red }
        foreach ($rp in @($e.Reports)) { Write-Host ("    REPORT {0}" -f $rp) -ForegroundColor Yellow }
        Write-GateText -Text $r.Text
    }
}

$phase1 = @($plan | Where-Object { $_.Phase -eq 1 })
$subVerdicts = @()
if ($phase1.Count -gt 0) {
    Write-Host ''
    Write-Host ("  phase 1: {0} gate(s) fanned out ({1} runnable)" -f $phase1.Count, @($phase1 | Where-Object { -not $_.Refused }).Count) -ForegroundColor DarkGray
    $res1 = @(Invoke-SpineGatePlan -Plan $phase1 -SkillDir $SkillDir -TimeoutSeconds $timeout -MaxJobs $MaxJobs -Serial:$Serial -Evidence $evidence)
    #  The sub-section wrapper's pass is only as good as the per-file results it
    #  wrote: a wrapper that exited 0 having written nothing checked nothing,
    #  and a wrapper that exited 0 while a per-file gate.json says fail (or is
    #  unreadable) contradicts its own evidence - the file wins, by name.
    $ssRes = @($res1 | Where-Object { $_.Name -eq 'Test-SubSection' })
    if ($ssRes.Count -eq 1) {
        $subVerdicts = @(Get-SubSectionVerdict -Dir $subDir)
        if ($ssRes[0].Ok) {
            if ($subVerdicts.Count -eq 0) {
                $ssRes[0].Ok = $false
                $ssRes[0].Reason = "exit 0 but no per-file gate.json was written to $subDir - the wrapper checked nothing this runner can show"
            }
            else {
                $notPass = @($subVerdicts | Where-Object { $_.verdict -ne 'pass' })
                if ($notPass.Count -gt 0) {
                    $ssRes[0].Ok = $false
                    $ssRes[0].Reason = ("exit 0 contradicted by {0} of {1} per-file gate.json: {2}" -f $notPass.Count, $subVerdicts.Count, (($notPass | ForEach-Object { "{0}={1}" -f $_.file, $_.verdict }) -join ', '))
                }
            }
        }
    }
    foreach ($r in $res1) { $allRes.Add($r) }
    foreach ($e in $phase1) { $ran.Add($e) }
    Show-PhaseResult -Entries $phase1 -Results $res1
}

$phase2 = @($plan | Where-Object { $_.Phase -eq 2 })
if ($phase2.Count -gt 0) {
    Write-Host ''
    Write-Host ("  phase 2: {0} gate(s) after the join" -f $phase2.Count) -ForegroundColor DarkGray
    if ($partial) {
        $producers = @('Check-ShapeMirror', 'Check-RowCoverage', 'Check-FigureMirror')
        $absent = @($producers | Where-Object { $_ -notin @($phase1 | ForEach-Object { $_.Name }) })
        if ($absent.Count -gt 0) { Write-Host ("  ! the disposition reads report files that {0} did not refresh in this partial run - they are whatever an earlier run left on disk" -f ($absent -join ', ')) -ForegroundColor Yellow }
    }
    $res2 = @(Invoke-SpineGatePlan -Plan $phase2 -SkillDir $SkillDir -TimeoutSeconds $timeout -MaxJobs 1 -Evidence $evidence)
    foreach ($r in $res2) { $allRes.Add($r) }
    foreach ($e in $phase2) { $ran.Add($e) }
    Show-PhaseResult -Entries $phase2 -Results $res2
}

#  THE JOIN. The fingerprint is recomputed here, and the interim verdict of
#  phases 1-2 is written to disk BEFORE the sheet is considered, so the cut
#  happens under a verdict that exists and can be stamped.
$fpJoin = Get-SpineFingerprint -BuildDir $BuildDir -SpineDir $SpineDir -Quiet
$bandVerdict = $null
if ($isBand) {
    $bandVerdict = Write-BandVerdictFile -Path $bandVerdictPath -Results $allRes -Entries $ran -Partial $partial -FingerprintBefore $fpBefore -FingerprintNow $fpJoin -BuildDir $BuildDir -Stage $Stage
    Write-Host ''
    Write-Host ("  join: band verdict of phases 1-2 {0} written to {1} (fingerprint {2})" -f $bandVerdict.verdict, $bandVerdictPath, $fpJoin) -ForegroundColor $(if ($bandVerdict.verdict -eq 'PASS') { 'DarkGray' } else { 'Yellow' })
}

$phase3 = @($plan | Where-Object { $_.Phase -eq 3 })
$sheetNote = ''
$sheetResult = $null
if ($phase3.Count -gt 0) {
    $sheetNote = Test-SheetMayRun -Results $allRes -Partial $partial -FingerprintBefore $fpBefore -FingerprintNow $fpJoin
    Write-Host ''
    if ($sheetNote) {
        Write-Host ("  phase 3: figure sheet {0}" -f $sheetNote) -ForegroundColor $(if ($sheetNote -like 'REFUSED*') { 'Red' } else { 'Yellow' })
        foreach ($e in $phase3) {
            $allRes.Add((New-GateResult -Name $e.Name -Ok $false -Text '' -Error '' -ExitCode $null -Seconds 0 -GateSeconds 0 -Refused ($sheetNote -like 'REFUSED*') -Reason $sheetNote))
            $ran.Add($e)
        }
    }
    else {
        Write-Host '  phase 3: every blocking gate passed on an unmoved spine - cutting the figure sheet' -ForegroundColor DarkGray
        $res3 = @(Invoke-SpineGatePlan -Plan $phase3 -SkillDir $SkillDir -TimeoutSeconds $timeout -MaxJobs 1 -Evidence $evidence)
        foreach ($r in $res3) { $allRes.Add($r) }
        foreach ($e in $phase3) { $ran.Add($e) }
        $sheetResult = @($res3 | Where-Object { $_.Name -eq 'New-FigureSheet' })[0]
        Show-PhaseResult -Entries $phase3 -Results $res3
    }
}

$swAll.Stop()
$fpAfter = Get-SpineFingerprint -BuildDir $BuildDir -SpineDir $SpineDir -Quiet

#  THE PLANT CHANNEL (P0-13), AFTER the band and never waited for. The band's
#  wall clock is untouched by it; its verdicts reach a LATER run as the
#  UNPROVEN report printed beside each member. It is started here rather than
#  before phase 1 so it cannot compete with the band for cores.
$scriptsHash = Get-SkillScriptsHash -SkillDir $SkillDir
$plantPlan = Get-PlantChannelPlan -BuildDir $BuildDir -SkillDir $SkillDir -Hash $scriptsHash -Suppressed:$NoPlantChannel
$plantStart = [pscustomobject]@{ Started = $false; Pid = 0; Error = ''; Command = '' }
if ($plantPlan.Action -eq 'start') { $plantStart = Start-PlantChannel -Plan $plantPlan -BuildDir $BuildDir -SkillDir $SkillDir }

# ---------------------------------------------------------------------------
# 8. One summary, one result file, one exit code
# ---------------------------------------------------------------------------

#  Every member's discrimination proof, from the newest hash-stamped fixtures
#  report under the build. A report, printed beside each member; never a verdict.
$proof = Get-FixtureProof -BuildDir $BuildDir

$gateRecords = New-Object System.Collections.Generic.List[object]
$sumSeconds = 0.0
$slowest = $null
$unproven = @()
foreach ($e in $ran) {
    $r = @($allRes | Where-Object { $_.Name -eq $e.Name })[0]
    $logPath = ''
    if ($r.Text) {
        $logPath = Join-Path $logDir ($e.Name + '.log')
        [System.IO.File]::WriteAllText($logPath, ($r.Text -replace "`n", "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($true)))
    }
    #  PASS, FAIL, GATE-DEFECT, NOT RUN or REFUSED - REFUSED is a failure with a
    #  reason that names an input or a copy, NOT RUN is a phase-3 member behind
    #  a failed or partial band. Both count against the band exactly as FAIL
    #  does. GATE-DEFECT (exit 4) counts against the band too, but NEVER as a
    #  content failure: the gate could not re-find its own anchor, so it judged
    #  nothing about the document.
    $verdict = if ($r.Ok) { 'PASS' } elseif (Test-ResultIsGateDefect -Result $r) { 'GATE-DEFECT' } elseif ($r.Refused) { 'REFUSED' } elseif ($e.Phase -eq 3 -and $sheetNote) { 'NOT RUN' } else { 'FAIL' }
    $params = [ordered]@{}
    foreach ($k in $e.Args.Keys) { $params[[string]$k] = $e.Args[$k] }
    $proofNote = Get-MemberProofNote -Proof $proof -Name $e.Name
    if ($proofNote -like 'UNPROVEN*') { $unproven += $e.Name }
    $rec = [ordered]@{
        name = $e.Name; script = $e.Script; phase = $e.Phase; stage = $Stage
        params = [pscustomobject]$params; dropped = @($e.Dropped); must = @($e.Must)
        exitCode = $r.ExitCode; startedAt = $r.StartedAt; ranAt = $r.RanAt
        seconds = $r.Seconds; gateSeconds = $r.GateSeconds
        verdict = $verdict; reason = $r.Reason; refused = [bool]$r.Refused
        evidence = $evidence
        arms = @($r.Arms); armLines = @($r.ArmLines); armsBlockingNotRun = @($r.ArmsBlockingNotRun); armProblems = @($r.ArmProblems)
        fixtureProof = $proofNote
        header = $(if ($e.Header.Found) { $e.Header.Raw } else { '' }); headerStages = @($e.Header.Stages); headerProblems = @($e.Header.Problems)
        reports = @($e.Reports)
        log = $logPath; summaryLines = @(Get-SummaryLine -Text $r.Text)
    }
    if ($e.Name -eq 'Test-SubSection') {
        $rec['subSectionResultDir'] = $subDir
        $rec['subSections'] = @($subVerdicts)
        $rec['subSectionsFailing'] = @($subVerdicts | Where-Object { $_.verdict -ne 'pass' }).Count
    }
    $gateRecords.Add([pscustomobject]$rec)
    if ($verdict -ne 'NOT RUN' -and $verdict -ne 'REFUSED') {
        $sumSeconds += $r.Seconds
        if ($null -eq $slowest -or $r.Seconds -gt $slowest.seconds) { $slowest = [pscustomobject]@{ name = $e.Name; seconds = $r.Seconds } }
    }
}

#  THE TWO CLASSES ARE SEPARATED HERE AND NOWHERE ELSE. defective[] is every
#  member that exited 4 - a gate that could not re-find its own anchor. It is
#  subtracted from failed[] because it is not a content failure, and the band
#  still cannot pass while it is non-empty.
$defective = @(Get-GateDefectiveName -Results $allRes)
$blockingFailed = @(@($ran | Where-Object { -not ($_.Phase -eq 3 -and $sheetNote -and $sheetNote -notlike 'REFUSED*') } | ForEach-Object { $n = $_.Name; @($allRes | Where-Object { $_.Name -eq $n -and -not $_.Ok }) } | ForEach-Object { $_.Name }) | Where-Object { $defective -notcontains $_ })
$spineMoved = ($fpBefore -ne $fpAfter)
$wall = [math]::Round($swAll.Elapsed.TotalSeconds, 1)
$figureSheet = Get-FigureSheetState -Note $sheetNote -Result $sheetResult -SheetPath $sheetPath -Planned ($phase3.Count -gt 0)

Write-Host ''
Write-Host ("SPINE GATE BAND (stage {0}) - one line per gate" -f $Stage) -ForegroundColor Cyan
Write-Host ("  {0,-24} {1,-8} {2,8}  {3,-38} {4}" -f 'gate', 'verdict', 'seconds', 'fixture proof', 'reason') -ForegroundColor DarkGray
foreach ($g in $gateRecords) {
    $col = switch ($g.verdict) { 'PASS' { 'Green' } 'NOT RUN' { 'Yellow' } 'GATE-DEFECT' { 'Magenta' } default { 'Red' } }
    $why = $g.reason
    if ($g.name -eq 'Test-SubSection' -and $g.verdict -eq 'FAIL' -and $g.subSectionsFailing -gt 0) { $why = ("{0} of {1} sub-section(s) fail: {2}" -f $g.subSectionsFailing, @($g.subSections).Count, ((@($g.subSections | Where-Object { $_.verdict -ne 'pass' } | ForEach-Object { $_.file })) -join ', ')) }
    $fp = [string]$g.fixtureProof
    if ($fp.Length -gt 38) { $fp = $fp.Substring(0, 35) + '...' }
    Write-Host ("  {0,-24} {1,-8} {2,8}  {3,-38} {4}" -f $g.name, $g.verdict, $g.seconds, $fp, $why) -ForegroundColor $col
}
Write-Host ''
Write-Host ("  fixtures: {0}" -f $proof.Note) -ForegroundColor $(if ($proof.Found) { 'DarkGray' } else { 'Yellow' })
$plantLine = switch ($plantPlan.Action) {
    'start'  { if ($plantStart.Started) { ("plant channel: STARTED detached for scripts hash {0} (pid {1}) - this band did not wait for it; its verdicts arrive in a later run" -f $plantPlan.Hash, $plantStart.Pid) } else { ("plant channel: could not start ({0})" -f $plantStart.Error) } }
    default  { ("plant channel: {0} - {1}" -f $plantPlan.Action, $plantPlan.Reason) }
}
Write-Host ("  {0}" -f $plantLine) -ForegroundColor $(if ($plantPlan.Action -eq 'start' -and -not $plantStart.Started) { 'Red' } else { 'DarkGray' })
if ($proof.Found -and $unproven.Count -gt 0) { Write-Host ("  UNPROVEN by the fixtures report: {0}" -f ($unproven -join ', ')) -ForegroundColor Yellow }
$armFails = @($gateRecords | Where-Object { (Get-GateCount -Value $_.armsBlockingNotRun) -gt 0 })
foreach ($g in $armFails) { Write-Host ("  X {0}: blocking arm(s) never ran: {1}" -f $g.name, (@($g.armsBlockingNotRun) -join ', ')) -ForegroundColor Red }
foreach ($g in ($gateRecords | Where-Object { (Get-GateCount -Value $_.armProblems) -gt 0 })) { foreach ($p in @($g.armProblems)) { Write-Host ("  ! {0}: {1}" -f $g.name, $p) -ForegroundColor Yellow } }
if ($slowest) {
    Write-Host ("  slowest gate: {0} at {1}s" -f $slowest.name, $slowest.seconds) -ForegroundColor DarkGray
    Write-Host ("  band wall clock {0}s against {1}s if the gates had run one after another ({2} of the sum)" -f $wall, [math]::Round($sumSeconds, 1), $(if ($sumSeconds -gt 0) { ('{0:P0}' -f ($wall / $sumSeconds)) } else { 'n/a' })) -ForegroundColor DarkGray
}

Write-Host ''
Write-Host 'PARAMETERS THREADED TO EVERY GATE - nothing below was left to a default the gate would have failed on' -ForegroundColor Cyan
foreach ($ln in (Get-ThreadedParameterLine -Plan $ran)) {
    $col = if ($ln -match 'NOT RUN') { 'Red' } elseif ($ln -match 'dropped') { 'Yellow' } else { 'DarkGray' }
    Write-Host ("  " + $ln) -ForegroundColor $col
}

if ($spineMoved) {
    Write-Host ''
    Write-Host ("  X the spine changed while the band ran (fingerprint {0} -> {1}); every verdict above describes a spine that no longer exists. Re-run." -f $fpBefore, $fpAfter) -ForegroundColor Red
}

if ($defective.Count -gt 0) {
    Write-Host ''
    Write-Host ("  X GATE-DEFECT: {0} member(s) exited 4 without re-finding their own anchors: {1}" -f $defective.Count, ($defective -join ', ')) -ForegroundColor Magenta
    Write-Host '    A gate that cannot re-find its quote at the token boundary it declared did not find a defect in the document - it found one in its own check-set. These members are recorded in defective[], NOT in failed[]: fix the gate and re-run the band. Nothing in the pack is to be edited against their findings, and this band cannot PASS or cut the figure sheet while the list is non-empty.' -ForegroundColor Magenta
}

$verdictLabel = ''
$rc = 0
if ($blockingFailed.Count -gt 0 -or $spineMoved) { $verdictLabel = 'FAIL'; $rc = 1 }
elseif ($defective.Count -gt 0) { $verdictLabel = 'GATE-DEFECT'; $rc = 1 }
elseif ($partial) { $verdictLabel = 'PARTIAL'; $rc = 3 }
else { $verdictLabel = 'PASS'; $rc = 0 }
if ($partial -and $verdictLabel -eq 'FAIL') { $verdictLabel = 'PARTIAL-FAIL' }
if ($partial -and $verdictLabel -eq 'GATE-DEFECT') { $verdictLabel = 'PARTIAL-GATE-DEFECT' }

$result = [ordered]@{
    runner = 'Run-SpineGates'; stage = $Stage; seed = (-not $isBand)
    ranAt = (Get-UtcNow); startedAt = $startedAtUtc
    buildDir = $BuildDir; spineDir = $SpineDir; resultDir = $ResultDir; unitExtract = $UnitExtract
    spineFingerprint = $fpBefore; spineFingerprintAtJoin = $fpJoin; spineFingerprintAfter = $fpAfter; spineChangedDuringRun = $spineMoved
    partial = $partial; only = @($(if ($partial) { @($plan | ForEach-Object { $_.Name }) } else { @() }))
    maxJobs = $effectiveJobs; timeoutMinutes = $TimeoutMinutes
    gates = $gateRecords.ToArray()
    slowest = $slowest
    wallClockSeconds = $wall; sumOfGateSeconds = [math]::Round($sumSeconds, 1)
    failed = @($blockingFailed + $(if ($spineMoved) { @('spine-changed-during-run') } else { @() }))
    #  THE GATE-DEFECT CLASS, APART FROM failed[]. A member here exited 4: it
    #  could not re-find its own anchor at the boundary it declared, so it is a
    #  broken gate to fix and never a document to remediate. The band cannot
    #  PASS and the figure sheet is not cut while this list is non-empty, and
    #  Test-StageLedger refuses to record any member of it as a content failure
    #  or as a partial.
    defective = @($defective)
    fixtures = [pscustomobject]@{ report = $proof.Path; hash = $proof.Hash; found = [bool]$proof.Found; note = $proof.Note; unproven = @($unproven) }
    plantChannel = [pscustomobject]@{ scriptsHash = $scriptsHash; action = $plantPlan.Action; reason = $plantPlan.Reason; started = [bool]$plantStart.Started; pid = $plantStart.Pid; statePath = $plantPlan.StatePath; waitedFor = $false }
    bandVerdictFile = $(if ($isBand) { $bandVerdictPath } else { '' })
    bandVerdictAtJoin = $(if ($null -ne $bandVerdict) { $bandVerdict.verdict } else { '' })
    figureSheet = $figureSheet
    figureSheetPath = $(if ($figureSheet -eq 'cut') { $sheetPath } else { '' })
    verdict = $verdictLabel
    exitCode = $rc
}
Write-JsonFile -Path $writePath -Body ([pscustomobject]$result)

Write-Host ''
if ($partial) {
    Write-Host '  ################################################################' -ForegroundColor Magenta
    Write-Host ("  #  PARTIAL RUN - {0} of {1} gate(s) ran. This is NOT the band." -f $ran.Count, $fullPlan.Count) -ForegroundColor Magenta
    Write-Host ("  #  {0}" -f $(if ($verdictLabel -eq 'PARTIAL') { 'every selected gate passed - exit 3, the band is still unproven' } else { 'selected gate(s) FAILED: ' + ($blockingFailed -join ', ') })) -ForegroundColor Magenta
    Write-Host ("  #  {0} untouched." -f (Split-Path $resultPath -Leaf)) -ForegroundColor Magenta
    Write-Host '  ################################################################' -ForegroundColor Magenta
}
elseif ($rc -eq 0) { Write-Host ("SPINE GATE BAND PASS (stage {0})  ({1} gate(s), {2}s wall clock, slowest {3} {4}s)  figure sheet: {5}" -f $Stage, $ran.Count, $wall, $slowest.name, $slowest.seconds, $figureSheet) -ForegroundColor Green }
elseif ($verdictLabel -like '*GATE-DEFECT') { Write-Host ("SPINE GATE BAND {0} (stage {1}): {2}  ({3}s wall clock)  figure sheet: {4}" -f $verdictLabel, $Stage, ('gate defect in ' + (@($result.defective) -join ', ')), $wall, $figureSheet) -ForegroundColor Magenta }
else { Write-Host ("SPINE GATE BAND FAIL (stage {0}): {1}  ({2}s wall clock)  figure sheet: {3}" -f $Stage, ((@($result.failed) + @($result.defective | ForEach-Object { $_ + ' (GATE-DEFECT)' })) -join ', '), $wall, $figureSheet) -ForegroundColor Red }
if (-not $isBand) { Write-Host ("  seed results - stage {0} never counts as 3c evidence" -f $Stage) -ForegroundColor Yellow }
Write-Host ("  results: {0}" -f $writePath) -ForegroundColor DarkGray
exit $rc
