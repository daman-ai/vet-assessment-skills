<#
    Test-GridDisposition.ps1 - ONE verdict per (sub-section, assessed grid).

    Runs at Stage 3c after Check-ShapeMirror.ps1 (over the spine) and
    Check-RowCoverage.ps1 -Whole, and consumes their report files - plus
    Check-FigureMirror's report where one is present. Writes
    grid-disposition.json beside them. Exit 1 on any grid not disposed, 2 on
    a usage error, 0 when every grid is disposed.

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
        NOT DISPOSED   anything else - exit 1

    "answered" is the LARGER of the shape mirror's FULL rows for the grid in
    its own sub-section file and the table mirror's filled rows where its
    report is present: a row answered in a table and a row answered in prose
    are the same leak. "taught" is the number of assessed rows at or above
    the whole-spine teaching floor, from the coverage report's -Whole run;
    a coverage report from a per-file run is refused, because the floor that
    disposes a grid is the whole-spine one.

    THE CLEARANCE KEY. mirrorAllow entries are keyed on a figure slot or on
    "file|grid id" (Check-FigureMirror's convention). This script accepts
    that key, the bare grid id, "subSection|grid id" and the task ref, so one
    written decision clears the grid in every gate that reads the registry.

    NEVER PRINTS A MODEL BULLET - it never reads one; the reports carry none.

    Table-mirror report contract (optional input, -MirrorReport, default
    <BuildDir>\figure-mirror-report.json): a JSON object or array whose
    entries carry a file (file/File), a grid id (grid/Grid/id) and a filled
    row count (filled/Filled/answered/rows). Any entry that does not resolve
    to a register grid is listed as unmatched, never silently dropped.

    PS 5.1. ASCII only in this file. Nothing here names a unit, a brand or a
    build path.
#>

[CmdletBinding()]
param(
    [string] $BuildDir,
    [string] $Register,
    [string] $ShapeReport,
    [string] $CoverageReport,
    [string] $MirrorReport,
    [string] $RulesPath,
    [string] $OutPath,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

$GATE = 'Test-GridDisposition'

function Fail-Usage { param([string] $Message) Write-Host ("  X {0}: {1}" -f $GATE, $Message) -ForegroundColor Red; exit 2 }

if (-not $BuildDir) { Fail-Usage '-BuildDir is required.' }
if (-not (Test-Path -LiteralPath $BuildDir)) { Fail-Usage ("build directory not found: {0}" -f $BuildDir) }
if (-not $Register)       { $Register       = Join-Path $BuildDir 'withhold-register.json' }
if (-not $ShapeReport)    { $ShapeReport    = Join-Path $BuildDir 'shape-mirror-report.json' }
if (-not $CoverageReport) { $CoverageReport = Join-Path $BuildDir 'row-coverage-report.json' }
if (-not $MirrorReport)   { $MirrorReport   = Join-Path $BuildDir 'figure-mirror-report.json' }
if (-not $OutPath)        { $OutPath        = Join-Path $BuildDir 'grid-disposition.json' }

$reg = Get-GateJson -Path $Register
if ($null -eq $reg) { Fail-Usage ("no withhold register at {0} - there is no list of grids to dispose." -f $Register) }
$shape = Get-GateJson -Path $ShapeReport
if ($null -eq $shape) { Fail-Usage ("no shape-mirror report at {0}. Run Check-ShapeMirror.ps1 over the spine first; a disposition with no ceiling input would dispose nothing." -f $ShapeReport) }
$cov = Get-GateJson -Path $CoverageReport
if ($null -eq $cov) { Fail-Usage ("no row-coverage report at {0}. Run Check-RowCoverage.ps1 -Whole first; a disposition with no floor input would dispose nothing." -f $CoverageReport) }
$covMode = [string](Get-GateProp -Object $cov -Names @('mode') -Default '')
if ($covMode -ne 'whole') { Fail-Usage ("the row-coverage report at {0} is from a '{1}' run; the floor that disposes a grid is the whole-spine one. Re-run Check-RowCoverage.ps1 -Whole." -f $CoverageReport, $covMode) }
$mirror = $null
if (Test-Path -LiteralPath $MirrorReport) { $mirror = Get-GateJson -Path $MirrorReport }

# ---------------------------------------------------------------------------
# 1. The grids, from the register
# ---------------------------------------------------------------------------

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
if ($gridList.Count -eq 0) { Fail-Usage 'the register lists no grids - nothing to dispose, which is not a pass.' }

# ---------------------------------------------------------------------------
# 2. answered: shape mirror FULL rows in the grid's own sub-section file(s), and the table mirror's filled rows
# ---------------------------------------------------------------------------

$shapeAnswered = @{}   # "sub|id" -> max full rows across own files
$shapePartial  = @{}
$shapeFiles    = @{}
foreach ($fr in @(Get-GateProp -Object $shape -Names @('files') -Default @())) {
    if ($null -eq $fr) { continue }
    $fSub = [string](Get-GateProp -Object $fr -Names @('SubSection', 'subSection') -Default '')
    foreach ($g in @(Get-GateProp -Object $fr -Names @('Grids', 'grids') -Default @())) {
        if ($null -eq $g) { continue }
        $own = Get-GateProp -Object $g -Names @('Own', 'own') -Default $false
        if (-not $own) { continue }
        $key = "{0}|{1}" -f [string](Get-GateProp -Object $g -Names @('SubSection', 'subSection') -Default $fSub), [string](Get-GateProp -Object $g -Names @('Id', 'id') -Default '')
        $full = [int](Get-GateProp -Object $g -Names @('FullRows', 'fullRows') -Default 0)
        $part = [int](Get-GateProp -Object $g -Names @('PartialRows', 'partialRows') -Default 0)
        if (-not $shapeAnswered.ContainsKey($key) -or $shapeAnswered[$key] -lt $full) { $shapeAnswered[$key] = $full }
        if (-not $shapePartial.ContainsKey($key) -or $shapePartial[$key] -lt $part) { $shapePartial[$key] = $part }
        $shapeFiles[$key] = [string](Get-GateProp -Object $fr -Names @('File', 'file') -Default '')
    }
}

$mirrorAnswered = @{}
$mirrorUnmatched = New-Object System.Collections.Generic.List[string]
$mirrorEntries = 0
if ($null -ne $mirror) {
    $entries = @()
    if ($mirror -is [System.Collections.IEnumerable] -and $mirror -isnot [string]) { $entries = @($mirror) }
    else { $entries = @(Get-GateProp -Object $mirror -Names @('hits', 'grids', 'entries', 'results', 'findings') -Default @()) }
    foreach ($e in $entries) {
        if ($null -eq $e) { continue }
        $mirrorEntries++
        $file = [string](Get-GateProp -Object $e -Names @('file', 'File') -Default '')
        $gid  = [string](Get-GateProp -Object $e -Names @('grid', 'Grid', 'id', 'Id', 'gridId') -Default '')
        $filled = [int](Get-GateProp -Object $e -Names @('filled', 'Filled', 'answered', 'Answered', 'rows', 'Rows') -Default 0)
        $match = @($gridList | Where-Object { $_.Id -eq $gid -or $_.Ref -eq $gid })
        if ($match.Count -eq 0) { $mirrorUnmatched.Add(("{0} ({1})" -f $gid, $file)); continue }
        foreach ($m in $match) {
            $key = "{0}|{1}" -f $m.SubSection, $m.Id
            if (-not $mirrorAnswered.ContainsKey($key) -or $mirrorAnswered[$key] -lt $filled) { $mirrorAnswered[$key] = $filled }
        }
    }
}

# ---------------------------------------------------------------------------
# 3. taught: rows at or above the whole-spine floor, from the coverage report
# ---------------------------------------------------------------------------

$taught = @{}
$floor = 0
$floors = Get-GateProp -Object $cov -Names @('floors') -Default $null
if ($null -ne $floors) { $floor = [int](Get-GateProp -Object $floors -Names @('minTeachWhole') -Default 0) }
foreach ($g in @(Get-GateProp -Object $cov -Names @('grids') -Default @())) {
    if ($null -eq $g) { continue }
    $key = "{0}|{1}" -f [string](Get-GateProp -Object $g -Names @('SubSection', 'subSection') -Default ''), [string](Get-GateProp -Object $g -Names @('Id', 'id') -Default '')
    $taught[$key] = [int](Get-GateProp -Object $g -Names @('TaughtRows', 'taughtRows') -Default 0)
}

# ---------------------------------------------------------------------------
# 4. the allow-list, with reasons
# ---------------------------------------------------------------------------

$registry = Get-GateRegistry -BuildDir $BuildDir -RulesPath $RulesPath
$allow = Get-GateAllowList -Registry $registry -Key 'mirrorAllow' -IdField @('slot', 'id', 'key', 'figure', 'grid') -GateName $GATE

# ---------------------------------------------------------------------------
# 5. verdicts
# ---------------------------------------------------------------------------

$verdicts = New-Object System.Collections.Generic.List[object]
$notDisposed = 0; $cleared = 0; $disposed = 0
foreach ($g in $gridList) {
    $key = "{0}|{1}" -f $g.SubSection, $g.Id
    $sa = 0; if ($shapeAnswered.ContainsKey($key)) { $sa = $shapeAnswered[$key] }
    $sp = 0; if ($shapePartial.ContainsKey($key)) { $sp = $shapePartial[$key] }
    $ma = 0; if ($mirrorAnswered.ContainsKey($key)) { $ma = $mirrorAnswered[$key] }
    $answered = [math]::Max($sa, $ma)
    $t = 0; if ($taught.ContainsKey($key)) { $t = $taught[$key] }
    $ok = ($answered -le $g.Allowance -and $t -eq $g.ItemCount -and $g.ItemCount -gt 0)
    $why = New-Object System.Collections.Generic.List[string]
    if ($answered -gt $g.Allowance) { $why.Add(("answered {0} > allowance {1}" -f $answered, $g.Allowance)) }
    if ($t -ne $g.ItemCount) { $why.Add(("taught {0} of {1} rows to the whole-spine floor of {2}" -f $t, $g.ItemCount, $floor)) }
    if ($g.ItemCount -eq 0) { $why.Add('the register lists no items for this grid') }

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
        taught = $t; floor = $floor
        verdict = $verdict; reason = $reason; allowKey = $allowKey
    })
}

$out = [pscustomobject]@{
    gate = $GATE
    generated = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
    buildDir = $BuildDir
    inputs = [pscustomobject]@{ register = $Register; shapeReport = $ShapeReport; coverageReport = $CoverageReport; mirrorReport = $(if ($null -ne $mirror) { $MirrorReport } else { '' }); mirrorEntries = $mirrorEntries; mirrorUnmatched = $mirrorUnmatched.ToArray() }
    rule = 'disposed when answered <= allowance AND taught == item count; cleared only through figures.json mirrorAllow with a written reason'
    grids = $verdicts.ToArray()
    summary = [pscustomobject]@{ grids = $gridList.Count; disposed = $disposed; cleared = $cleared; notDisposed = $notDisposed }
}
$json = $out | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText($OutPath, $json, (New-Object System.Text.UTF8Encoding($true)))

if (-not $Quiet) {
    Write-Host ''
    Write-Host 'GRID DISPOSITION - one verdict per (sub-section, grid)' -ForegroundColor Cyan
    Write-GateCheckSet -What 'assessed grids' -Count $gridList.Count -DerivedFrom (Split-Path $Register -Leaf)
    Write-Host ("  inputs: shape mirror {0}; row coverage {1} (whole-spine floor {2}); table mirror {3}" -f (Split-Path $ShapeReport -Leaf), (Split-Path $CoverageReport -Leaf), $floor, $(if ($null -ne $mirror) { ("{0} ({1} entries)" -f (Split-Path $MirrorReport -Leaf), $mirrorEntries) } else { 'no report present - table answers come from the shape mirror''s table channel only' })) -ForegroundColor DarkGray
    foreach ($u in $mirrorUnmatched) { Write-Host ("  ! table-mirror entry did not resolve to a register grid: {0}" -f $u) -ForegroundColor Yellow }
    if ($allow.Count -gt 0) { Write-Host ("  allow-list (figures.json mirrorAllow): {0} entr(ies) with written reasons" -f $allow.Count) -ForegroundColor DarkGray }
    Write-Host ''
    Write-Host ("  {0,-6} {1,-22} {2,-9} {3,4} {4,5} {5,8} {6,7}  verdict" -f 'sub', 'grid', 'kind', 'rows', 'allow', 'answered', 'taught') -ForegroundColor DarkGray
    foreach ($v in $verdicts) {
        $c = switch ($v.verdict) { 'disposed' { 'Green' } 'cleared' { 'DarkGray' } default { 'Red' } }
        Write-Host ("  {0,-6} {1,-22} {2,-9} {3,4} {4,5} {5,8} {6,7}  {7}" -f $v.subSection, $(if ($v.ref.Length -gt 22) { $v.ref.Substring(0, 22) } else { $v.ref }), $v.kind, $v.itemCount, $v.allowance, $v.answered, $v.taught, $v.verdict) -ForegroundColor $c
        if ($v.verdict -ne 'disposed') { Write-Host ("         {0}" -f $v.reason) -ForegroundColor $c }
    }
    Write-Host ''
    Write-Host ("  written to {0}" -f $OutPath) -ForegroundColor DarkGray
}

if ($notDisposed -eq 0) {
    Write-Host ("  every grid is disposed: {0} disposed, {1} cleared at Stage 3d" -f $disposed, $cleared) -ForegroundColor Green
    exit 0
}
Write-Host ("  {0} of {1} grid(s) NOT DISPOSED ({2} disposed, {3} cleared)" -f $notDisposed, $gridList.Count, $disposed, $cleared) -ForegroundColor Red
Write-Host '  A grid is disposed by teaching every row to the floor and answering none beyond the allowance,' -ForegroundColor Yellow
Write-Host '  or cleared by a written reason in figures.json "mirrorAllow" - never by editing a gate.' -ForegroundColor Yellow
exit 1
