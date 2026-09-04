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
         -- join --
     10  Test-GridDisposition     one verdict per grid, from 4, 8 and 9's reports
         -- only when every blocking gate above passed --
     11  New-FigureSheet          the Stage 3d figure sheet, fingerprinted to the
                                  spine it was cut from

    REFUSED COUNTS AS A FAILURE. A gate that throws, times out, refuses on a
    missing input, is absent from the scripts directory, or cannot be handed a
    parameter its rule depends on is a FAIL that names the gate and the reason.
    It is never a skip: a band of four scripts recorded as "the spine gate
    band: pass" is the false green gates.md was rewritten against, and a gate
    still being written is "gate unavailable", not "not applicable".

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

    THE FIGURE SHEET IS NEVER CUT FROM A SPINE THAT FAILED. It is the transcript
    reviewers read at Stage 3d and it travels with every later review pack. Cut
    from a failing spine it would carry content the remediation is about to
    change, stamped with a fingerprint the ledger will reject later - so it runs
    last, after the join, only on a green band, and never in a partial run.

    -Only IS A PARTIAL RUN AND CANNOT CLAIM THE BAND. A subset re-run is for
    fixing one gate's findings quickly. It prints a PARTIAL RUN banner, writes
    partial=true into the result, never cuts the sheet, and exits 3 even when
    every selected gate passed - so a subset can never be mistaken for the band.

    NEVER PRINTS A MODEL BULLET OF ITS OWN. Gate output is passed through as
    the gate printed it; the gates own that rule.

    Usage
      Run-SpineGates.ps1 -BuildDir <dir> [-SpineDir <dir>] [-UnitExtract <md>]
                         [-Profile <rto-profile.json>] [-ResultDir <dir>]
                         [-MaxJobs 8] [-TimeoutMinutes 10] [-Serial]
                         [-Only Test-Spine,Assert-PromptLint]
      Run-SpineGates.ps1 -SelfTest        no build, no Office, no API

    Writes <build>\3c-results.json:
      { ranAt, spineFingerprint, gates: [ { name, script, params, exitCode,
        seconds, verdict, summaryLines[] } ], slowest, verdict }
    plus the per-gate logs under <build>\3c\logs.

    PS 5.1. ASCII only in this file. UTF-8 BOM required on disk.
    Exit 0 every blocking gate passed; 1 a gate failed, was refused, timed out
    or is unavailable; 2 a usage error (including no unit extract); 3 a partial
    run (-Only) in which every selected gate passed; 4 the self-test failed.
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
    [int] $MaxJobs = 8,
    [int] $TimeoutMinutes = 10,
    #  One job at a time, for debugging. The same wrapper, the same rules.
    [switch] $Serial,
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
        the entry - and a refused entry is a failure in the results.  #>
    param(
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][string] $Title,
        [Parameter(Mandatory)][string] $Script,
        [Parameter(Mandatory)][int] $Phase,
        [System.Collections.IDictionary] $Want,
        [string[]] $Must,
        [string] $Produces,
        [string] $Refused
    )
    if ($null -eq $Want) { $Want = [ordered]@{} }
    if ($null -eq $Must) { $Must = @() }
    $args_ = [ordered]@{}
    $dropped = @()
    if (-not $Refused) {
        $declared = @()
        try { $declared = @(Get-ScriptParameterName -Path $Script) }
        catch { $Refused = ("gate unavailable - the script could not be read: {0}" -f $_.Exception.Message) }
        if (-not $Refused -and $declared.Count -eq 0) {
            $Refused = ("gate unavailable - script not found: {0}" -f $Script)
        }
        if (-not $Refused) {
            foreach ($k in $Want.Keys) {
                if ($declared -contains [string]$k) { $args_[[string]$k] = $Want[$k]; continue }
                if ($Must -contains [string]$k) {
                    $Refused = ("this copy of the gate does not accept -{0}, which its blocking rule depends on (it takes: {1})" -f $k, ($declared -join ', '))
                    break
                }
                $dropped += [string]$k
            }
        }
    }
    return [pscustomobject]@{
        Name = $Name; Title = $Title; Script = $Script; Phase = $Phase
        Args = $args_; Dropped = @($dropped); Produces = $Produces; Refused = $Refused
    }
}

# ---------------------------------------------------------------------------
# 2. The invocation plan - DATA, built before any gate runs
# ---------------------------------------------------------------------------

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
    'New-FigureSheet'
)

function New-SpineGatePlan {
    <#  Every entry of the band, in order, from one input set. The self-test
        builds this plan from a synthetic build and asserts what it threads.

        $In keys: BuildDir, SkillDir, SpineDir, UnitExtract, ResultDir,
        Profile (optional), Register, Cells, Rules (paths that may not exist -
        an existing one is threaded, an absent one is left to the gate's own
        discovery so its refusal, if any, is the gate's).  #>
    param([Parameter(Mandatory)][hashtable] $In)

    $scripts = Join-Path $In.SkillDir 'scripts'
    $plan = New-Object System.Collections.Generic.List[object]
    function S { param([string] $n) return (Join-Path $scripts ($n + '.ps1')) }
    function Existing { param([string] $p) if ($p -and (Test-Path -LiteralPath $p)) { return $p } return $null }

    $shapeReport = Join-Path $In.BuildDir 'shape-mirror-report.json'
    $covReport   = Join-Path $In.BuildDir 'row-coverage-report.json'
    $mirrorReport = Join-Path $In.BuildDir 'figure-mirror-report.json'
    $dispOut     = Join-Path $In.BuildDir 'grid-disposition.json'
    $sheetOut    = Join-Path $In.BuildDir 'figure-sheet.txt'
    $subDir      = Join-Path $In.ResultDir 'subsections'

    # ---- 1 whole-spine validator
    $w = [ordered]@{ BuildDir = $In.BuildDir; SpineDir = $In.SpineDir; ResultPath = (Join-Path $In.ResultDir 'test-spine.json') }
    $plan.Add((New-GateEntry -Name 'Test-Spine' -Title 'SPINE (Test-Spine, whole-spine mode)' -Script (S 'Test-Spine') -Phase 1 -Want $w -Must @('BuildDir')))

    # ---- 2 unread fields
    $w = [ordered]@{ BuildDir = $In.BuildDir; SpineDir = $In.SpineDir; SkillDir = $In.SkillDir }
    $plan.Add((New-GateEntry -Name 'Test-SpineRead' -Title 'UNREAD FIELDS (Test-SpineRead)' -Script (S 'Test-SpineRead') -Phase 1 -Want $w -Must @('BuildDir')))

    # ---- 3 figure registry, SOURCE arm only. No -DocText on purpose: the
    #      rendered arm needs the extracts and belongs to Run-Gates.
    $w = [ordered]@{ BuildDir = $In.BuildDir }
    $plan.Add((New-GateEntry -Name 'Test-FigureConsistency' -Title 'FIGURE REGISTRY - declared sources (Test-FigureConsistency)' -Script (S 'Test-FigureConsistency') -Phase 1 -Want $w -Must @('BuildDir')))

    # ---- 4 table / answer-grid mirror
    $w = [ordered]@{ BuildDir = $In.BuildDir; SpineDir = $In.SpineDir }
    if (Existing $In.Register) { $w['RegisterPath'] = $In.Register }
    $plan.Add((New-GateEntry -Name 'Check-FigureMirror' -Title 'ANSWER-GRID MIRROR (Check-FigureMirror)' -Script (S 'Check-FigureMirror') -Phase 1 -Want $w -Must @('BuildDir')))

    # ---- 5 assessor-only leakage, whole spine, unit extract excluded
    if (-not $In.UnitExtract -or -not (Test-Path -LiteralPath $In.UnitExtract)) {
        $plan.Add((New-GateEntry -Name 'Check-FigureLeakage' -Title 'ASSESSOR LEAKAGE (Check-FigureLeakage)' -Script (S 'Check-FigureLeakage') -Phase 1 `
                   -Refused ("REFUSED: no unit_extract.md (looked for {0}). An assessor guide quotes the unit; without the unit corpus every unit line the guide teaches is misreported as assessor-only." -f $In.UnitExtract)))
    }
    else {
        $w = [ordered]@{ BuildDir = $In.BuildDir; ExcludeText = @($In.UnitExtract); SpineDir = $In.SpineDir; ReportPath = (Join-Path $In.ResultDir 'leakage_report.txt') }
        $plan.Add((New-GateEntry -Name 'Check-FigureLeakage' -Title 'ASSESSOR LEAKAGE (Check-FigureLeakage, whole spine)' -Script (S 'Check-FigureLeakage') -Phase 1 -Want $w -Must @('BuildDir', 'ExcludeText')))
    }

    # ---- 6 prompt lint; the profile comes from the contract's brand unless given
    $w = [ordered]@{ BuildDir = $In.BuildDir; SpineDir = $In.SpineDir; SkillDir = $In.SkillDir }
    if ($In.Profile) { $w['Profile'] = $In.Profile }
    $plan.Add((New-GateEntry -Name 'Assert-PromptLint' -Title 'PROMPT LINT (Assert-PromptLint)' -Script (S 'Assert-PromptLint') -Phase 1 -Want $w -Must @('BuildDir')))

    # ---- 7 the in-loop wrapper over every sub-section, results OUTSIDE spine\
    $w = [ordered]@{ All = $true; BuildDir = $In.BuildDir; ResultDir = $subDir; ResultPath = (Join-Path $In.ResultDir 'test-subsection-all.json'); UnitExtract = $In.UnitExtract }
    if (Existing $In.Register) { $w['RegisterPath'] = $In.Register }
    if (Existing $In.Cells)    { $w['AssessorCellsPath'] = $In.Cells }
    $plan.Add((New-GateEntry -Name 'Test-SubSection' -Title 'EVERY SUB-SECTION (Test-SubSection -All)' -Script (S 'Test-SubSection') -Phase 1 -Want $w -Must @('All', 'BuildDir', 'ResultDir')))

    # ---- 8 prose shape mirror
    $w = [ordered]@{ BuildDir = $In.BuildDir; SpineDir = $In.SpineDir; ReportPath = $shapeReport }
    $plan.Add((New-GateEntry -Name 'Check-ShapeMirror' -Title 'SHAPE MIRROR (Check-ShapeMirror, whole spine)' -Script (S 'Check-ShapeMirror') -Phase 1 -Want $w -Must @('BuildDir', 'SpineDir') -Produces $shapeReport))

    # ---- 9 row coverage, whole-spine floor
    $w = [ordered]@{ BuildDir = $In.BuildDir; Whole = $true; SpineDir = $In.SpineDir; ReportPath = $covReport; UnitExtract = $In.UnitExtract }
    $plan.Add((New-GateEntry -Name 'Check-RowCoverage' -Title 'ROW COVERAGE (Check-RowCoverage -Whole)' -Script (S 'Check-RowCoverage') -Phase 1 -Want $w -Must @('BuildDir', 'Whole') -Produces $covReport))

    # ---- 10 one verdict per grid, after 4, 8 and 9 have joined
    $w = [ordered]@{ BuildDir = $In.BuildDir; ShapeReport = $shapeReport; CoverageReport = $covReport; OutPath = $dispOut }
    if (Existing $mirrorReport) { $w['MirrorReport'] = $mirrorReport }
    if (Existing $In.Rules)     { $w['RulesPath'] = $In.Rules }
    $plan.Add((New-GateEntry -Name 'Test-GridDisposition' -Title 'GRID DISPOSITION (Test-GridDisposition)' -Script (S 'Test-GridDisposition') -Phase 2 -Want $w -Must @('BuildDir', 'ShapeReport', 'CoverageReport') -Produces $dispOut))

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
        $plan.Add((New-GateEntry -Name $g.N -Title $g.T -Script (S $g.N) -Phase 1 -Want $w -Must $g.M))
    }

    # ---- 11 the figure sheet, last, green band only
    $w = [ordered]@{ BuildDir = $In.BuildDir; SpineDir = $In.SpineDir; OutPath = $sheetOut }
    $plan.Add((New-GateEntry -Name 'New-FigureSheet' -Title 'FIGURE SHEET (New-FigureSheet)' -Script (S 'New-FigureSheet') -Phase 3 -Want $w -Must @('BuildDir') -Produces $sheetOut))

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
        if (@($e.Dropped).Count -gt 0) { $line += ("   [not accepted by this copy, dropped: {0}]" -f (@($e.Dropped) -join ', ')) }
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
    [pscustomobject]@{ Name = $Entry.Name; Ok = $ok; Text = ($lines -join "`n"); Error = $err; ExitCode = $code; Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1) }
}

function New-GateResult {
    param([string] $Name, [bool] $Ok, [string] $Text, [string] $Error, $ExitCode, [double] $Seconds, [double] $GateSeconds, [bool] $Refused, [string] $Reason, [bool] $Removed = $true)
    return [pscustomobject]@{
        Name = $Name; Ok = $Ok; Text = $Text; Error = $Error; ExitCode = $ExitCode
        Seconds = [math]::Round($Seconds, 1); GateSeconds = [math]::Round($GateSeconds, 1)
        Refused = $Refused; Reason = $Reason; Removed = $Removed
    }
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
        [switch] $Serial
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
        $r = $null
        if ($Why) {
            $errText = ''
            if ($j.State -eq 'Running') { Stop-Job -Job $j -ErrorAction SilentlyContinue }
            try { $reason = $j.ChildJobs[0].JobStateInfo.Reason; if ($reason) { $errText = [string]$reason.Message } } catch { }
            if (-not $errText) { try { $null = Receive-Job -Job $j -ErrorAction Stop } catch { $errText = $_.Exception.Message } }
            $r = New-GateResult -Name $e.Name -Ok $false -Text $errText -Error $Why -ExitCode $null -Seconds $wall -GateSeconds 0 -Refused $false -Reason $Why
        }
        elseif ($j.State -eq 'Completed') {
            $out = Receive-Job -Job $j -ErrorAction SilentlyContinue
            $out = @($out | Where-Object { $_ -and ($_.PSObject.Properties.Name -contains 'Ok') } | Select-Object -Last 1)
            if ($out.Count -eq 1) {
                $o = $out[0]
                $reason = ''
                if (-not $o.Ok) { $reason = if ($o.Error) { "threw: " + [string]$o.Error } else { "exit code " + [string]$o.ExitCode } }
                $r = New-GateResult -Name $e.Name -Ok ([bool]$o.Ok) -Text ([string]$o.Text) -Error ([string]$o.Error) -ExitCode $o.ExitCode -Seconds $wall -GateSeconds ([double]$o.Seconds) -Refused $false -Reason $reason
            }
            else {
                $r = New-GateResult -Name $e.Name -Ok $false -Text '' -Error 'the job returned no result object' -ExitCode $null -Seconds $wall -GateSeconds 0 -Refused $false -Reason 'the job returned no result object'
            }
        }
        else {
            $why = "job ended in state $($j.State)"
            $errText = ''
            try { $reason = $j.ChildJobs[0].JobStateInfo.Reason; if ($reason) { $errText = [string]$reason.Message } } catch { }
            if (-not $errText) { try { $null = Receive-Job -Job $j -ErrorAction Stop } catch { $errText = $_.Exception.Message } }
            $r = New-GateResult -Name $e.Name -Ok $false -Text $errText -Error $why -ExitCode $null -Seconds $wall -GateSeconds 0 -Refused $false -Reason $why
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

function Test-SheetMayRun {
    <#  The sheet runs only when every result so far passed and the run is the
        whole band. A refused gate, an unavailable gate or a timeout is a
        failure here like anywhere else.  #>
    param([Parameter(Mandatory)] $Results, [bool] $Partial)
    if ($Partial) { return 'NOT RUN - a partial run (-Only) never cuts the figure sheet' }
    $failed = @($Results | Where-Object { -not $_.Ok } | ForEach-Object { $_.Name })
    if ($failed.Count -gt 0) { return ("NOT RUN - a sheet is never cut from a spine that failed ({0})" -f ($failed -join ', ')) }
    return ''
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

        $fp1 = Get-SpineFingerprint -BuildDir $build
        [System.IO.File]::WriteAllText((Join-Path $spine 't1_1.1.json'), '{"pc":"1.1","edited":true}', $utf8)
        $fp2 = Get-SpineFingerprint -BuildDir $build
        if ($fp1 -and $fp2 -and $fp1 -ne $fp2 -and $fp1.Length -eq 32) { Ok 'the spine fingerprint is content-derived and changes when a spine file is edited' } else { Bad "fingerprint: '$fp1' -> '$fp2'" }

        $in = @{
            BuildDir = $build; SkillDir = $SkillDir; SpineDir = $spine; UnitExtract = $unitX; ResultDir = $resultDir; Profile = ''
            Register = (Join-Path $build 'withhold-register.json'); Cells = (Join-Path $build 'assessor-cells.json'); Rules = (Join-Path $build 'figures.json')
        }
        $plan = @(New-SpineGatePlan -In $in)
        $names = @($plan | ForEach-Object { $_.Name })
        $expected = @($script:GateOrder | Where-Object { $_ -ne 'Test-GridDisposition' -and $_ -ne 'New-FigureSheet' }) + @('Test-GridDisposition', 'New-FigureSheet')
        if ($names.Count -eq $script:GateOrder.Count -and (($names | Sort-Object) -join ',') -eq (($script:GateOrder | Sort-Object) -join ',')) { Ok ('the plan carries every gate of the band ({0}), the sheet last' -f $script:GateOrder.Count) } else { Bad ("plan names: " + ($names -join ', ')) }
        $ph = @{}
        foreach ($e in $plan) { $ph[$e.Name] = $e.Phase }
        $p1 = @($plan | Where-Object { $_.Phase -eq 1 }).Count
        if ($ph['Test-GridDisposition'] -eq 2 -and $ph['New-FigureSheet'] -eq 3 -and $p1 -eq ($script:GateOrder.Count - 2)) { Ok ('{0} gates fan out in phase 1; the disposition joins in phase 2; the sheet is phase 3' -f $p1) } else { Bad ('phase assignment wrong: phase1=' + $p1) }

        function E { param([string] $n) return @($plan | Where-Object { $_.Name -eq $n })[0] }
        $available = @($plan | Where-Object { -not $_.Refused })
        $unavailable = @($plan | Where-Object { $_.Refused })
        Write-Host ("        (on this machine {0} of {2} gate scripts are present: {1})" -f $available.Count, (($available | ForEach-Object { $_.Name }) -join ', '), $script:GateOrder.Count) -ForegroundColor DarkGray
        foreach ($u in $unavailable) { Write-Host ("        absent: {0} -> {1}" -f $u.Name, $u.Refused) -ForegroundColor DarkGray }

        $bad = @()
        foreach ($e in $available) { if (-not $e.Args.Contains('BuildDir')) { $bad += $e.Name } }
        if ($bad.Count -eq 0) { Ok 'every available gate is handed -BuildDir' } else { Bad ("no -BuildDir on: " + ($bad -join ', ')) }
        $lk = E 'Check-FigureLeakage'
        if (-not $lk.Refused -and @($lk.Args['ExcludeText']).Count -eq 1 -and $lk.Args['ExcludeText'][0] -eq $unitX) { Ok 'the unit extract is threaded to the leakage gate as -ExcludeText' } elseif ($lk.Refused) { Bad "leakage refused: $($lk.Refused)" } else { Bad 'unit extract not threaded to the leakage gate' }
        $fc = E 'Test-FigureConsistency'
        if (-not $fc.Refused -and -not $fc.Args.Contains('DocText')) { Ok 'the figure registry runs its SOURCE arm only here (no -DocText)' } elseif ($fc.Refused) { Bad "registry refused: $($fc.Refused)" } else { Bad '-DocText leaked into the 3c registry call' }
        $ss = E 'Test-SubSection'
        if (-not $ss.Refused -and $ss.Args['All'] -eq $true -and $ss.Args['ResultDir'] -and -not ([string]$ss.Args['ResultDir']).StartsWith($spine, [StringComparison]::OrdinalIgnoreCase)) { Ok 'Test-SubSection runs -All with a -ResultDir outside spine\' } elseif ($ss.Refused) { Bad "sub-section wrapper refused: $($ss.Refused)" } else { Bad "sub-section args: ResultDir='$($ss.Args['ResultDir'])' All='$($ss.Args['All'])'" }
        $sm = E 'Check-ShapeMirror'
        if ($sm.Refused -or ($sm.Args['SpineDir'] -eq $spine -and $sm.Args['ReportPath'])) { Ok 'Check-ShapeMirror is wired by name with -BuildDir -SpineDir and a report path (or reported unavailable)' } else { Bad 'shape mirror wiring' }
        $rc = E 'Check-RowCoverage'
        if ($rc.Refused -or ($rc.Args['Whole'] -eq $true -and $rc.Args['ReportPath'])) { Ok 'Check-RowCoverage is wired by name with -Whole and a report path (or reported unavailable)' } else { Bad 'row coverage wiring' }
        $gd = E 'Test-GridDisposition'
        if ($gd.Refused -or ($gd.Args['ShapeReport'] -eq $sm.Args['ReportPath'] -and $gd.Args['CoverageReport'] -eq $rc.Args['ReportPath'])) { Ok 'Test-GridDisposition consumes the very report paths handed to the shape mirror and the coverage gate' } else { Bad 'disposition report paths do not match' }
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
        if ($gr.Count -eq 1 -and -not $gr[0].Ok -and $gr[0].Refused -and $gr[0].Reason -match 'gate unavailable') { Ok 'and in the results it is a FAIL naming the gate and the reason - never a pass, never a skip' } else { Bad "ghost result ok=$($gr[0].Ok) reason='$($gr[0].Reason)'" }

        # ---- a copy that cannot take a parameter the rule depends on is refused
        $narrow = Join-Path $tmp 'Narrow-Gate.ps1'
        [System.IO.File]::WriteAllText($narrow, "param([string] `$BuildDir)`r`nexit 0`r`n", $bom)
        $ne = New-GateEntry -Name 'Narrow' -Title 'narrow' -Script $narrow -Phase 1 -Want ([ordered]@{ BuildDir = $build; ExcludeText = @($unitX); Quiet = $true }) -Must @('BuildDir', 'ExcludeText')
        if ($ne.Refused -match 'ExcludeText') { Ok 'a copy that cannot take a parameter the blocking rule depends on is REFUSED, not run without it' } else { Bad "narrow refused='$($ne.Refused)'" }
        $ne2 = New-GateEntry -Name 'Narrow2' -Title 'narrow' -Script $narrow -Phase 1 -Want ([ordered]@{ BuildDir = $build; Quiet = $true }) -Must @('BuildDir')
        if (-not $ne2.Refused -and $ne2.Args.Count -eq 1 -and @($ne2.Dropped) -contains 'Quiet') { Ok 'an optional parameter the copy lacks is dropped and recorded as dropped' } else { Bad "narrow2 refused='$($ne2.Refused)' dropped=$($ne2.Dropped -join ',')" }

        # ---- the job wrapper: a stub result is collected with its text and exit code
        $stubFail = Join-Path $tmp 'stub_fail.ps1'
        [System.IO.File]::WriteAllText($stubFail, "param([string] `$BuildDir)`r`nWrite-Host 'X planted failure'`r`nexit 1`r`n", $bom)
        $stubPass = Join-Path $tmp 'stub_pass.ps1'
        [System.IO.File]::WriteAllText($stubPass, "param([string] `$BuildDir)`r`nWrite-Host 'planted pass'`r`nexit 0`r`n", $bom)
        $stubThrow = Join-Path $tmp 'stub_throw.ps1'
        [System.IO.File]::WriteAllText($stubThrow, "param([string] `$BuildDir)`r`nthrow 'planted throw'`r`n", $bom)
        $stubSlow = Join-Path $tmp 'stub_slow.ps1'
        [System.IO.File]::WriteAllText($stubSlow, "param([string] `$BuildDir)`r`nStart-Sleep -Seconds 60`r`nexit 0`r`n", $bom)
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
            @{ P = $stubSlow;  M = 'Start-Sleep' }
        )) {
            if (-not (Test-Path -LiteralPath $pl.P)) { Bad ("the planted stub was never written: {0}" -f (Split-Path $pl.P -Leaf)); $plantOk = $false; continue }
            $txt = [System.IO.File]::ReadAllText($pl.P)
            if ($txt.IndexOf($pl.M, [System.StringComparison]::Ordinal) -lt 0) { Bad ("the planted stub {0} does not carry its marker" -f (Split-Path $pl.P -Leaf)); $plantOk = $false }
        }
        if ($plantOk) { Ok 'every planted stub was read back and carries its marker, so the checks below prove something' }
        $eFail  = New-GateEntry -Name 'stub-fail'  -Title 'f' -Script $stubFail  -Phase 1 -Want ([ordered]@{ BuildDir = $build }) -Must @('BuildDir')
        $ePass  = New-GateEntry -Name 'stub-pass'  -Title 'p' -Script $stubPass  -Phase 1 -Want ([ordered]@{ BuildDir = $build }) -Must @('BuildDir')
        $eThrow = New-GateEntry -Name 'stub-throw' -Title 't' -Script $stubThrow -Phase 1 -Want ([ordered]@{ BuildDir = $build }) -Must @('BuildDir')
        $swFan = [System.Diagnostics.Stopwatch]::StartNew()
        $rr = @(Invoke-SpineGatePlan -Plan @($eFail, $ePass, $eThrow) -SkillDir $SkillDir -TimeoutSeconds 120 -MaxJobs 3)
        $swFan.Stop()
        $rFail = @($rr | Where-Object { $_.Name -eq 'stub-fail' })[0]
        $rPass = @($rr | Where-Object { $_.Name -eq 'stub-pass' })[0]
        $rThrow = @($rr | Where-Object { $_.Name -eq 'stub-throw' })[0]
        if ($rFail -and -not $rFail.Ok -and $rFail.Text -match 'planted failure' -and $rFail.ExitCode -eq 1) { Ok 'the job wrapper collects a stub''s text and its exit code 1 as a FAIL' } else { Bad ("stub-fail: ok=$($rFail.Ok) code=$($rFail.ExitCode) text='$($rFail.Text)' err='$($rFail.Error)'") }
        if ($rPass -and $rPass.Ok -and $rPass.Text -match 'planted pass' -and $rPass.ExitCode -eq 0) { Ok 'a stub that exits 0 is a PASS with its text captured' } else { Bad ("stub-pass: ok=$($rPass.Ok) code=$($rPass.ExitCode) err='$($rPass.Error)'") }
        if ($rThrow -and -not $rThrow.Ok -and $rThrow.Error -match 'planted throw' -and $rThrow.Reason -match 'planted throw') { Ok 'a stub that throws is a FAIL reporting the thrown error' } else { Bad ("stub-throw: ok=$($rThrow.Ok) err='$($rThrow.Error)' reason='$($rThrow.Reason)'") }
        $sumSec = 0.0; foreach ($x in $rr) { $sumSec += $x.Seconds }
        Write-Host ("        (three stubs fanned out: wall {0}s, sum of gate wall times {1}s)" -f [math]::Round($swFan.Elapsed.TotalSeconds, 1), [math]::Round($sumSec, 1)) -ForegroundColor DarkGray
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

        # ---- the figure sheet decision
        $good = @([pscustomobject]@{ Name = 'a'; Ok = $true }, [pscustomobject]@{ Name = 'b'; Ok = $true })
        $mixed = @([pscustomobject]@{ Name = 'a'; Ok = $true }, [pscustomobject]@{ Name = 'b'; Ok = $false })
        if (-not (Test-SheetMayRun -Results $good -Partial $false)) { Ok 'the sheet runs on a green full band' } else { Bad 'sheet blocked on a green band' }
        if ((Test-SheetMayRun -Results $mixed -Partial $false) -match 'never cut from a spine that failed') { Ok 'the sheet is NOT cut when any blocking gate failed' } else { Bad 'sheet ran on a failed band' }
        if ((Test-SheetMayRun -Results $good -Partial $true) -match 'partial') { Ok 'the sheet is NOT cut in a partial run' } else { Bad 'sheet ran in a partial run' }

        # ---- sub-section verdicts are read from gate.json by contract
        $sd = Join-Path $resultDir 'subsections'
        New-Item -ItemType Directory -Force -Path $sd | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $sd 't1_1.1.json.gate.json'), '{"verdict":"fail","blocks":[{"arm":"mirror-own","text":"x"}]}', $utf8)
        [System.IO.File]::WriteAllText((Join-Path $sd 't1_1.2.json.gate.json'), '{"verdict":"pass","blocks":[]}', $utf8)
        $sv = @(Get-SubSectionVerdict -Dir $sd)
        if ($sv.Count -eq 2 -and $sv[0].verdict -eq 'fail' -and $sv[0].blocks -eq 1 -and $sv[0].arms -eq 'mirror-own' -and $sv[1].verdict -eq 'pass') { Ok 'per-file sub-section verdicts are collected from gate.json by contract' } else { Bad ("sub-section verdicts: " + (($sv | ForEach-Object { "$($_.file)=$($_.verdict)" }) -join ', ')) }
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

$derived = New-Object System.Collections.Generic.List[string]

if (-not $SpineDir) { $SpineDir = Join-Path $BuildDir 'spine'; $derived.Add("SpineDir spine\ under the build") }
if (-not (Test-Path -LiteralPath $SpineDir)) { Write-Host "Run-SpineGates: no spine at $SpineDir - there is nothing to gate. The band runs after authoring closes." -ForegroundColor Red; exit 2 }
$SpineDir = (Resolve-Path -LiteralPath $SpineDir).Path
$spineFiles = @(Get-ChildItem -LiteralPath $SpineDir -Filter '*.json' -File)
if ($spineFiles.Count -eq 0) { Write-Host "Run-SpineGates: the spine directory holds no JSON: $SpineDir" -ForegroundColor Red; exit 2 }

$contractPath = Join-Path $BuildDir 'contract.json'
if (-not (Test-Path -LiteralPath $contractPath)) { Write-Host "Run-SpineGates: no contract.json in $BuildDir - every gate in the band reads it." -ForegroundColor Red; exit 2 }
$contract = $null
try { $contract = Read-JsonFile -Path $contractPath } catch { Write-Host ("Run-SpineGates: contract.json does not parse: {0}" -f $_.Exception.Message) -ForegroundColor Red; exit 2 }
$unitCode = ''; $brand = ''
if ($contract -and (HasProp $contract 'unit') -and (HasProp $contract.unit 'code')) { $unitCode = [string]$contract.unit.code }
if ($contract -and (HasProp $contract 'build') -and (HasProp $contract.build 'brand')) { $brand = [string]$contract.build.brand }

if (-not $UnitExtract) { $UnitExtract = Join-Path $BuildDir 'unit_extract.md'; $derived.Add("UnitExtract unit_extract.md beside the build") }
if (-not (Test-Path -LiteralPath $UnitExtract)) {
    Write-Host ''
    Write-Host ("Run-SpineGates: REFUSED - no unit extract at {0}." -f $UnitExtract) -ForegroundColor Red
    Write-Host '  An assessor guide quotes the unit. Without the unit corpus the leakage sweep reports every unit line' -ForegroundColor Red
    Write-Host '  the guide teaches as assessor-only, and the row-coverage KE floor has no points to cover. Put the' -ForegroundColor Red
    Write-Host '  extract in place (Stage 1 writes it) and re-run. Nothing ran.' -ForegroundColor Red
    exit 2
}
$UnitExtract = (Resolve-Path -LiteralPath $UnitExtract).Path

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

if (-not $ResultDir) { $ResultDir = Join-Path $BuildDir '3c'; $derived.Add("ResultDir 3c\ under the build") }
if (-not (Test-Path -LiteralPath $ResultDir)) { New-Item -ItemType Directory -Force -Path $ResultDir | Out-Null }
$ResultDir = (Resolve-Path -LiteralPath $ResultDir).Path
if ($ResultDir.StartsWith($SpineDir, [StringComparison]::OrdinalIgnoreCase)) {
    Write-Host "Run-SpineGates: -ResultDir must not be under the spine directory - every whole-spine reader globs spine\*.json, and a gate.json beside a spine file is read as content." -ForegroundColor Red
    exit 2
}
$logDir = Join-Path $ResultDir 'logs'
$subDir = Join-Path $ResultDir 'subsections'
foreach ($d in @($logDir, $subDir)) { if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null } }

$inputs = @{
    BuildDir = $BuildDir; SkillDir = $SkillDir; SpineDir = $SpineDir; UnitExtract = $UnitExtract
    ResultDir = $ResultDir; Profile = $Profile
    Register = (Join-Path $BuildDir 'withhold-register.json')
    Cells    = (Join-Path $BuildDir 'assessor-cells.json')
    Rules    = (Join-Path $BuildDir 'figures.json')
}
foreach ($k in @('Register', 'Cells', 'Rules')) {
    $derived.Add(("{0}: {1}" -f $k, $(if (Test-Path -LiteralPath $inputs[$k]) { (Split-Path $inputs[$k] -Leaf) + ' beside the build' } else { 'absent - left to each gate''s own discovery and refusal' })))
}

$fullPlan = @(New-SpineGatePlan -In $inputs)
$partial = ($null -ne $Only -and @($Only).Count -gt 0)
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

$fpBefore = Get-SpineFingerprint -BuildDir $BuildDir -SpineDir $SpineDir
$timeout = $TimeoutMinutes * 60
$effectiveJobs = $(if ($Serial) { 1 } else { $MaxJobs })

Write-Host ''
Write-Host ("RUN-SPINEGATES  {0}  Stage 3c  spine {1} file(s)  fingerprint {2}" -f $(if ($unitCode) { $unitCode } else { Split-Path $BuildDir -Leaf }), $spineFiles.Count, $fpBefore) -ForegroundColor Cyan
Write-Host ("  {0} gate(s) planned, up to {1} at a time, {2} min per gate{3}" -f @($plan | Where-Object { -not $_.Refused }).Count, $effectiveJobs, $TimeoutMinutes, $(if ($Serial) { ' (-Serial)' } else { '' })) -ForegroundColor DarkGray
foreach ($d in $derived) { Write-Host ("  derived: {0}" -f $d) -ForegroundColor DarkGray }
if ($partial) {
    Write-Host ''
    Write-Host '  ################################################################' -ForegroundColor Magenta
    Write-Host ("  #  PARTIAL RUN (-Only {0})" -f (($plan | ForEach-Object { $_.Name }) -join ', ')) -ForegroundColor Magenta
    Write-Host '  #  This run cannot claim the band. No figure sheet. Exit 3 at best.' -ForegroundColor Magenta
    Write-Host '  ################################################################' -ForegroundColor Magenta
}

# ---------------------------------------------------------------------------
# 7. Run - phase 1 fans out, phase 2 joins, phase 3 only on a green band
# ---------------------------------------------------------------------------

$swAll = [System.Diagnostics.Stopwatch]::StartNew()
$allRes = New-Object System.Collections.Generic.List[object]
$ran = New-Object System.Collections.Generic.List[object]   # plan entries that reached the runner, in order

function Show-PhaseResult {
    param($Entries, $Results)
    foreach ($e in $Entries) {
        $r = @($Results | Where-Object { $_.Name -eq $e.Name })[0]
        Write-Host ''
        $tag = if ($r.Ok) { 'PASS' } else { 'FAIL' }
        $col = if ($r.Ok) { 'Green' } else { 'Red' }
        Write-Host ("{0}  [{1}]  {2}s" -f $e.Title, $tag, $r.Seconds) -ForegroundColor $col
        if ($r.Reason -and -not $r.Ok) { Write-Host ("    X {0}" -f $r.Reason) -ForegroundColor Red }
        Write-GateText -Text $r.Text
    }
}

$phase1 = @($plan | Where-Object { $_.Phase -eq 1 })
if ($phase1.Count -gt 0) {
    Write-Host ''
    Write-Host ("  phase 1: {0} gate(s) fanned out ({1} runnable)" -f $phase1.Count, @($phase1 | Where-Object { -not $_.Refused }).Count) -ForegroundColor DarkGray
    $res1 = @(Invoke-SpineGatePlan -Plan $phase1 -SkillDir $SkillDir -TimeoutSeconds $timeout -MaxJobs $MaxJobs -Serial:$Serial)
    #  The sub-section wrapper's pass is only as good as the per-file results it
    #  wrote: a wrapper that exited 0 having written nothing checked nothing.
    $ssRes = @($res1 | Where-Object { $_.Name -eq 'Test-SubSection' })
    if ($ssRes.Count -eq 1 -and $ssRes[0].Ok) {
        if (@(Get-ChildItem -LiteralPath $subDir -Filter '*.gate.json' -File -ErrorAction SilentlyContinue).Count -eq 0) {
            $ssRes[0].Ok = $false
            $ssRes[0].Reason = "exit 0 but no per-file gate.json was written to $subDir - the wrapper checked nothing this runner can show"
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
    $res2 = @(Invoke-SpineGatePlan -Plan $phase2 -SkillDir $SkillDir -TimeoutSeconds $timeout -MaxJobs 1)
    foreach ($r in $res2) { $allRes.Add($r) }
    foreach ($e in $phase2) { $ran.Add($e) }
    Show-PhaseResult -Entries $phase2 -Results $res2
}

$phase3 = @($plan | Where-Object { $_.Phase -eq 3 })
$sheetNote = ''
if ($phase3.Count -gt 0) {
    $sheetNote = Test-SheetMayRun -Results $allRes -Partial $partial
    Write-Host ''
    if ($sheetNote) {
        Write-Host ("  phase 3: figure sheet {0}" -f $sheetNote) -ForegroundColor Yellow
        foreach ($e in $phase3) {
            $allRes.Add((New-GateResult -Name $e.Name -Ok $false -Text '' -Error '' -ExitCode $null -Seconds 0 -GateSeconds 0 -Refused $false -Reason $sheetNote))
            $ran.Add($e)
        }
    }
    else {
        Write-Host '  phase 3: every blocking gate passed - cutting the figure sheet' -ForegroundColor DarkGray
        $res3 = @(Invoke-SpineGatePlan -Plan $phase3 -SkillDir $SkillDir -TimeoutSeconds $timeout -MaxJobs 1)
        foreach ($r in $res3) { $allRes.Add($r) }
        foreach ($e in $phase3) { $ran.Add($e) }
        Show-PhaseResult -Entries $phase3 -Results $res3
    }
}

$swAll.Stop()
$fpAfter = Get-SpineFingerprint -BuildDir $BuildDir -SpineDir $SpineDir

# ---------------------------------------------------------------------------
# 8. One summary, one result file, one exit code
# ---------------------------------------------------------------------------

$subVerdicts = @()
if (@($ran | Where-Object { $_.Name -eq 'Test-SubSection' }).Count -gt 0) { $subVerdicts = @(Get-SubSectionVerdict -Dir $subDir) }

$gateRecords = New-Object System.Collections.Generic.List[object]
$sumSeconds = 0.0
$slowest = $null
foreach ($e in $ran) {
    $r = @($allRes | Where-Object { $_.Name -eq $e.Name })[0]
    $logPath = ''
    if ($r.Text) {
        $logPath = Join-Path $logDir ($e.Name + '.log')
        [System.IO.File]::WriteAllText($logPath, ($r.Text -replace "`n", "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($true)))
    }
    $verdict = if ($r.Ok) { 'PASS' } elseif ($e.Phase -eq 3 -and $sheetNote) { 'NOT RUN' } else { 'FAIL' }
    $params = [ordered]@{}
    foreach ($k in $e.Args.Keys) { $params[[string]$k] = $e.Args[$k] }
    $rec = [ordered]@{
        name = $e.Name; script = $e.Script; phase = $e.Phase
        params = [pscustomobject]$params; dropped = @($e.Dropped)
        exitCode = $r.ExitCode; seconds = $r.Seconds; gateSeconds = $r.GateSeconds
        verdict = $verdict; reason = $r.Reason; refused = [bool]$r.Refused
        log = $logPath; summaryLines = @(Get-SummaryLine -Text $r.Text)
    }
    if ($e.Name -eq 'Test-SubSection') {
        $rec['subSectionResultDir'] = $subDir
        $rec['subSections'] = @($subVerdicts)
        $rec['subSectionsFailing'] = @($subVerdicts | Where-Object { $_.verdict -ne 'pass' }).Count
    }
    $gateRecords.Add([pscustomobject]$rec)
    if ($verdict -ne 'NOT RUN') {
        $sumSeconds += $r.Seconds
        if ($null -eq $slowest -or $r.Seconds -gt $slowest.seconds) { $slowest = [pscustomobject]@{ name = $e.Name; seconds = $r.Seconds } }
    }
}

$blockingFailed = @($ran | Where-Object { -not ($_.Phase -eq 3 -and $sheetNote) } | ForEach-Object { $n = $_.Name; @($allRes | Where-Object { $_.Name -eq $n -and -not $_.Ok }) } | ForEach-Object { $_.Name })
$spineMoved = ($fpBefore -ne $fpAfter)
$wall = [math]::Round($swAll.Elapsed.TotalSeconds, 1)

Write-Host ''
Write-Host 'SPINE GATE BAND - one line per gate' -ForegroundColor Cyan
Write-Host ("  {0,-24} {1,-8} {2,8}  {3}" -f 'gate', 'verdict', 'seconds', 'reason') -ForegroundColor DarkGray
foreach ($g in $gateRecords) {
    $col = switch ($g.verdict) { 'PASS' { 'Green' } 'NOT RUN' { 'Yellow' } default { 'Red' } }
    $why = $g.reason
    if ($g.name -eq 'Test-SubSection' -and $g.verdict -eq 'FAIL' -and $g.subSectionsFailing -gt 0) { $why = ("{0} of {1} sub-section(s) fail: {2}" -f $g.subSectionsFailing, @($g.subSections).Count, ((@($g.subSections | Where-Object { $_.verdict -ne 'pass' } | ForEach-Object { $_.file })) -join ', ')) }
    Write-Host ("  {0,-24} {1,-8} {2,8}  {3}" -f $g.name, $g.verdict, $g.seconds, $why) -ForegroundColor $col
}
Write-Host ''
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

$bandVerdict = ''
$rc = 0
if ($blockingFailed.Count -gt 0 -or $spineMoved) { $bandVerdict = 'FAIL'; $rc = 1 }
elseif ($partial) { $bandVerdict = 'PARTIAL'; $rc = 3 }
else { $bandVerdict = 'PASS'; $rc = 0 }
if ($partial -and $bandVerdict -eq 'FAIL') { $bandVerdict = 'PARTIAL-FAIL' }

$result = [ordered]@{
    ranAt = (Get-Date).ToUniversalTime().ToString('o')
    buildDir = $BuildDir; spineDir = $SpineDir; resultDir = $ResultDir; unitExtract = $UnitExtract
    spineFingerprint = $fpBefore; spineFingerprintAfter = $fpAfter; spineChangedDuringRun = $spineMoved
    partial = $partial; only = @($(if ($partial) { @($plan | ForEach-Object { $_.Name }) } else { @() }))
    maxJobs = $effectiveJobs; timeoutMinutes = $TimeoutMinutes
    gates = $gateRecords.ToArray()
    slowest = $slowest
    wallClockSeconds = $wall; sumOfGateSeconds = [math]::Round($sumSeconds, 1)
    failed = @($blockingFailed)
    figureSheet = $(if ($sheetNote) { $sheetNote } elseif ($phase3.Count -gt 0) { 'cut' } else { 'not in this run' })
    verdict = $bandVerdict
    exitCode = $rc
}
$resultPath = Join-Path $BuildDir '3c-results.json'
Write-JsonFile -Path $resultPath -Body ([pscustomobject]$result)

Write-Host ''
if ($partial) {
    Write-Host '  ################################################################' -ForegroundColor Magenta
    Write-Host ("  #  PARTIAL RUN - {0} of {1} gate(s) ran. This is NOT the band." -f $ran.Count, $fullPlan.Count) -ForegroundColor Magenta
    Write-Host ("  #  {0}" -f $(if ($bandVerdict -eq 'PARTIAL') { 'every selected gate passed - exit 3, the band is still unproven' } else { 'selected gate(s) FAILED: ' + ($blockingFailed -join ', ') })) -ForegroundColor Magenta
    Write-Host '  ################################################################' -ForegroundColor Magenta
}
elseif ($rc -eq 0) { Write-Host ("SPINE GATE BAND PASS  ({0} gate(s), {1}s wall clock, slowest {2} {3}s)  figure sheet cut" -f $ran.Count, $wall, $slowest.name, $slowest.seconds) -ForegroundColor Green }
else { Write-Host ("SPINE GATE BAND FAIL: {0}  ({1}s wall clock)" -f (($blockingFailed + $(if ($spineMoved) { @('spine-changed-during-run') } else { @() })) -join ', '), $wall) -ForegroundColor Red }
Write-Host ("  results: {0}" -f $resultPath) -ForegroundColor DarkGray
exit $rc
