<#
  Merge-LedgerFragments.ps1 — assemble one ledger from per-student fragments.

  Judging the evidence is the only slow stage of a marking run, and it is the
  only one where the students are independent of one another: reading Daniel's
  workbook tells you nothing about Mei's. So that stage can be done many at a
  time, each worker writing ONE student's block to its own file, and this script
  joins them back together.

  Everything else stays single. The roll is one matrix read for the class, the
  prerequisite is one lookup for the unit, and the resolver, the builder and the
  gate all need the whole class at once — a duplicate student ID, a tool name
  that drifted, a marking record with a missing row. Those are exactly the
  failures that only show up when you can see everybody.

  A FRAGMENT IS ONE ENTRY OF THE LEDGER'S students[] ARRAY, nothing more:

      fragments/MVC00318.json
      { "firstName": "Daniel", "surname": "Okafor", "studentId": "MVC00318",
        "comment": "...", "results": [ ... ] }

  The BASE is the same ledger with everything class-wide and no students: rto,
  unit, qualification, assessor, markingDate, location, environment, tools.

  WHY -Roll MATTERS HERE. A parallel worker that dies writes no fragment, and a
  missing fragment looks exactly like a class that was always one smaller. Give
  this script the roll and it names who has not reported and stops. That is the
  same reasoning as the resolver's own roll check, applied one stage earlier —
  at the point where the work is actually spread out and a silent gap is easiest
  to create.

  Usage:
    .\Merge-LedgerFragments.ps1 -Base ledger.base.json -Fragments .\fragments -Out ledger.json
    .\Merge-LedgerFragments.ps1 -Base ledger.base.json -Fragments .\fragments -Roll roll.json -Out ledger.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Base,
    [Parameter(Mandatory)][string]$Fragments,
    [string]$Roll,
    [string]$Out,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Base))      { throw "Base ledger not found: $Base" }
if (-not (Test-Path -LiteralPath $Fragments)) { throw "Fragment folder not found: $Fragments" }

$baseLedger = Get-Content -Raw -Encoding UTF8 -LiteralPath $Base | ConvertFrom-Json
if ($baseLedger.PSObject.Properties.Name.Contains('students') -and @($baseLedger.students).Count -gt 0) {
    throw "The base ledger already carries $(@($baseLedger.students).Count) student(s). A base holds only what is true of the whole class; the students come from the fragments."
}
if (-not $baseLedger.tools) { throw 'The base ledger declares no tools.' }
$toolIds = @($baseLedger.tools | ForEach-Object { $_.id })

# ------------------------------------------------------------- fragments ----

$problems = @()
$checks   = @()
$byId     = [ordered]@{}

$files = @(Get-ChildItem -LiteralPath $Fragments -Filter '*.json' -File | Sort-Object Name)
if ($files.Count -eq 0) { throw "No .json fragments in $Fragments." }

foreach ($f in $files) {
    try {
        $frag = Get-Content -Raw -Encoding UTF8 -LiteralPath $f.FullName | ConvertFrom-Json
    } catch {
        $problems += "$($f.Name): will not parse as JSON — $($_.Exception.Message)"
        continue
    }
    # A fragment written as a one-element array is the obvious mistake; accept it
    # rather than failing on a shape that means the same thing.
    if ($frag -is [System.Array]) {
        if (@($frag).Count -ne 1) { $problems += "$($f.Name): holds $(@($frag).Count) students. One fragment is one student."; continue }
        $frag = @($frag)[0]
    }

    foreach ($req in @('firstName','surname','studentId','results')) {
        if (-not $frag.PSObject.Properties.Name.Contains($req) -or -not $frag.$req) {
            $problems += "$($f.Name): fragment has no $req."
        }
    }
    if (-not $frag.studentId) { continue }

    if ($byId.Contains($frag.studentId)) {
        $problems += "$($f.Name): student $($frag.studentId) is already in $($byId[$frag.studentId].file). Two fragments for one student is two judgements of the same work."
        continue
    }

    foreach ($r in @($frag.results)) {
        if (-not $r.toolId) { $problems += "$($f.Name): a result has no toolId." ; continue }
        if ($toolIds -notcontains $r.toolId) {
            $problems += "$($f.Name): result names tool '$($r.toolId)', which is not one of the base ledger's tools ($($toolIds -join ', ')). A tool id that drifted in one worker is invisible until the whole class is together."
        }
    }
    $missingTools = @($toolIds | Where-Object { $tid = $_; -not (@($frag.results | Where-Object { $_.toolId -eq $tid }).Count) })
    if ($missingTools.Count) {
        $problems += "$($f.Name): $($frag.studentId) has no judgement for tool(s) $($missingTools -join ', '). A missing judgement is not a pass."
    }

    $byId[$frag.studentId] = [pscustomobject]@{ file = $f.Name; student = $frag }
}

# ------------------------------------------------------------------ roll ----

$order = @($byId.Keys)
$missingFragments = @()
if ($Roll) {
    if (-not (Test-Path -LiteralPath $Roll)) { throw "Roll not found: $Roll" }
    $rollData = Get-Content -Raw -Encoding UTF8 -LiteralPath $Roll | ConvertFrom-Json
    if ($rollData.unit -and $baseLedger.unit.code -and "$($rollData.unit)".ToUpper() -ne "$($baseLedger.unit.code)".ToUpper()) {
        $problems += "The roll is for unit '$($rollData.unit)' but the base ledger is for '$($baseLedger.unit.code)'."
    }
    $required = @($rollData.required)
    foreach ($r in $required) {
        if ($r.studentId -and -not $byId.Contains($r.studentId)) { $missingFragments += $r }
    }
    foreach ($m in $missingFragments) {
        $problems += "$($m.displayName) [$($m.studentId)] is REQUIRED TO SUBMIT but no fragment was written for them. A worker that failed leaves no file, and a missing file looks exactly like a smaller class."
    }
    foreach ($k in $order) {
        if (-not (@($required | Where-Object { $_.studentId -eq $k }).Count)) {
            $checks += "$k has a fragment but is not in REQUIRED TO SUBMIT on the roll. Confirm they are due to submit."
        }
    }
    # The roll's order is the order the marking record numbers its rows in.
    $order = @()
    foreach ($r in $required) { if ($r.studentId -and $byId.Contains($r.studentId)) { $order += $r.studentId } }
    foreach ($k in @($byId.Keys)) { if ($order -notcontains $k) { $order += $k } }
}

# ----------------------------------------------------------------- output ---

if ($problems.Count) {
    Write-Output ''
    Write-Output "FRAGMENTS NOT MERGED — $($problems.Count) problem(s):"
    $i = 0
    foreach ($p in $problems) { $i++; Write-Output ("  {0,2}. {1}" -f $i, $p) }
    Write-Output ''
    Write-Output 'Nothing was written. Fix these and merge again.'
    Write-Output ''
    exit 1
}

$merged = [ordered]@{}
foreach ($p in $baseLedger.PSObject.Properties) { $merged[$p.Name] = $p.Value }
$merged['students'] = @(foreach ($k in $order) { $byId[$k].student })

if ($Out) {
    ($merged | ConvertTo-Json -Depth 25) | Out-File -Encoding utf8 -LiteralPath $Out
    if (-not $Quiet) { Write-Output "Ledger written: $Out" }
}

if (-not $Quiet) {
    Write-Output ''
    Write-Output ("MERGED — {0} fragment(s) into one ledger for {1} {2}" -f $files.Count, $baseLedger.unit.code, $baseLedger.unit.title)
    foreach ($k in $order) { Write-Output ("    {0,-14} {1}" -f $k, $byId[$k].file) }
    if ($Roll) { Write-Output ("  reconciled against the roll: every required student has a fragment") }
    else       { Write-Output ("  NO ROLL SUPPLIED — nothing has confirmed a worker did not fail silently. Pass -Roll.") }
    foreach ($c in $checks) { Write-Output ("  CHECK  {0}" -f $c) }
    Write-Output ''
    Write-Output 'Now run Resolve-MarkingLedger.ps1 on it — the merge checks shapes, the resolver checks meaning.'
    Write-Output ''
}

$merged
