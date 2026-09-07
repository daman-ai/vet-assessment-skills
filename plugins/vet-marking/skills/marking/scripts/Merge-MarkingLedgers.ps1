<#
  Merge-MarkingLedgers.ps1 — consolidate several resolved ledgers into one
  resolved ledger PER WISENET COURSE-OFFER GROUP.

  WHY THIS EXISTS. A marking run is scoped to a day: everyone marked on the 5th
  is one run, everyone marked on the 6th is another, and each run produces its
  own class record. What the RTO files, though, is a record per GROUP — the
  course offer a learner is actually enrolled in — and a group's learners are
  marked on whatever day their work came in. So the records that go on the file
  are cut a different way from the runs that produced them.

  This script does the cutting. It reads every resolved ledger, reads group
  membership from a WiseNet 0217 export (EVERY worksheet — the export carries
  one per course offer), and writes one resolved ledger per group.

  THE THREE RULES IT ENFORCES, because each one is a record an auditor would
  reject:

    * a student is marked ONCE. The same student ID in two ledgers is a
      duplicate record, not a resit, and it stops the merge. A genuine resit is
      one ledger entry with attempt 2.
    * a student sits in ONE group. The 0217 export listing them on two
      worksheets stops the merge; the enrolment has to be fixed in WiseNet
      first, because whichever group is picked here the other record is wrong.
    * a student who is marked must BE on the matrix. Marking somebody the
      export has never heard of means the ID is wrong or the enrolment is
      missing, and the record has nowhere to be filed.

  Dates survive the cut. Every student already carries their own
  feedbackGivenText and resubmissionDueText from their own run, so a group
  record shows each learner the day their own feedback was given. The group
  ledger's own date block is the LATEST run it draws on: that is the day the
  record was completed, which is what the sign-off block says.

  Usage:
    .\Merge-MarkingLedgers.ps1 -Ledger a.json,b.json -Matrix rpt_0217.xls -OutDir .\groups
    .\Merge-MarkingLedgers.ps1 -Ledger a.json -Matrix m.xls -OutDir .\g -Roster roster.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string[]]$Ledger,
    [Parameter(Mandatory)][string]$OutDir,
    [string]$Matrix,
    [string]$Roster,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

$problems = New-Object System.Collections.ArrayList
function Fail { param([string]$Message) [void]$problems.Add($Message) }

# ------------------------------------------------------------ the ledgers ---

$loaded = @()
foreach ($p in $Ledger) {
    if (-not (Test-Path -LiteralPath $p)) { throw "Ledger not found: $p" }
    $obj = Get-Content -Raw -Encoding UTF8 -LiteralPath (Resolve-Path -LiteralPath $p).Path | ConvertFrom-Json
    if (-not $obj.dates) { throw "$p is not a resolved ledger. Run Resolve-MarkingLedger.ps1 on it first." }
    $loaded += [pscustomobject]@{ path = (Resolve-Path -LiteralPath $p).Path; L = $obj }
}
if ($loaded.Count -eq 0) { throw 'No ledgers given.' }

# Everything printed on the record has to be the same across the runs, or the
# consolidated record would state something untrue about half its rows.
$first = $loaded[0].L
foreach ($e in $loaded) {
    $l = $e.L
    $n = Split-Path -Leaf $e.path
    if ($l.rto               -ne $first.rto)               { Fail "$n : RTO '$($l.rto)' differs from '$($first.rto)'. A record cannot span two RTOs." }
    if ($l.unit.code         -ne $first.unit.code)         { Fail "$n : unit $($l.unit.code) differs from $($first.unit.code)." }
    if ($l.qualification.code -ne $first.qualification.code) { Fail "$n : qualification $($l.qualification.code) differs from $($first.qualification.code)." }
    if ($l.assessor          -ne $first.assessor)          { Fail "$n : assessor '$($l.assessor)' differs from '$($first.assessor)'. Split the merge by assessor: the record carries one signature." }
    if ($l.dates.assessmentDateText -ne $first.dates.assessmentDateText) { Fail "$n : date of assessment $($l.dates.assessmentDateText) differs from $($first.dates.assessmentDateText). That date is printed once in the header and cannot describe both runs." }
    $a = @($l.tools     | ForEach-Object { "$($_.id)|$($_.name)" }) -join ' ~ '
    $b = @($first.tools | ForEach-Object { "$($_.id)|$($_.name)" }) -join ' ~ '
    if ($a -ne $b) { Fail "$n : tools differ from the first ledger. The record has one column per tool." }
}

# ------------------------------------------------------------ the students --

$students = @()
$seen = @{}
foreach ($e in $loaded) {
    $n = Split-Path -Leaf $e.path
    foreach ($s in @($e.L.students)) {
        if ($seen.ContainsKey($s.studentId)) {
            Fail "$($s.studentId) $($s.fullName) is in $n and already in $($seen[$s.studentId]). A student is marked once; a resit is one entry with attempt 2, not two entries."
            continue
        }
        $seen[$s.studentId] = $n
        # A copy, plus where it came from. The resolved record is taken verbatim
        # — this script re-derives nothing.
        $copy = $s | Select-Object *
        $copy | Add-Member -NotePropertyName sourceLedger   -NotePropertyValue $n -Force
        $copy | Add-Member -NotePropertyName sourceDir      -NotePropertyValue (Split-Path -Parent $e.path) -Force
        $copy | Add-Member -NotePropertyName markingDate    -NotePropertyValue $e.L.dates.markingDate -Force
        $copy | Add-Member -NotePropertyName markingDateText -NotePropertyValue $e.L.dates.markingDateText -Force
        # The marked copy is named on the RUN's ledger, keyed by student, and a
        # student whose tools were bound in one file has one copy covering both.
        # Carrying the names here means the packager looks nothing up by
        # pattern — a guess that would quietly file the wrong student's work.
        $copy | Add-Member -NotePropertyName markedCopyFiles -NotePropertyValue `
            @(@($e.L.markedCopies) | Where-Object { $_.studentId -eq $s.studentId } | ForEach-Object { $_.file }) -Force
        if (-not ($copy.PSObject.Properties.Name -contains 'feedbackGivenText') -or -not $copy.feedbackGivenText) {
            # Ledgers resolved before feedbackGivenText was published per student.
            $copy | Add-Member -NotePropertyName feedbackGivenText -NotePropertyValue $e.L.dates.feedbackGivenText -Force
        }
        $students += $copy
    }
}

# ------------------------------------------------------------- the roster ---

if (-not $Roster -and -not $Matrix) { throw 'Give -Matrix (a WiseNet 0217 export) or -Roster (its already-read JSON).' }
if (-not $Roster) {
    $Roster = Join-Path $OutDir 'roster.json'
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    & (Join-Path $PSScriptRoot 'Read-Groups.ps1') -Path $Matrix -Unit $first.unit.code -Json $Roster | Out-Null
}
# PS 5.1: ConvertFrom-Json hands an array back as ONE object, so cast rather
# than wrapping with @() — @() would give a single element holding the array.
$rosterRows = [object[]](Get-Content -Raw -Encoding UTF8 -LiteralPath $Roster | ConvertFrom-Json)

$groupOf = @{}
foreach ($row in $rosterRows) {
    if (-not $row.studentId) { continue }
    if ($groupOf.ContainsKey($row.studentId) -and $groupOf[$row.studentId] -ne $row.group) {
        Fail "$($row.studentId) $($row.rawName) is on two worksheets of the matrix: '$($groupOf[$row.studentId])' and '$($row.group)'. Fix the enrolment in WiseNet before filing a group record."
        continue
    }
    $groupOf[$row.studentId] = $row.group
}

foreach ($s in $students) {
    if (-not $groupOf.ContainsKey($s.studentId)) {
        Fail "$($s.studentId) $($s.fullName) was marked but is on no worksheet of the matrix. Check the student ID, or the enrolment."
    }
}

if ($problems.Count) {
    Write-Output ''
    Write-Output "MERGE REFUSED — $($problems.Count) problem(s):"
    foreach ($p in $problems) { Write-Output "  * $p" }
    Write-Output ''
    throw 'Nothing was written.'
}

# --------------------------------------------------------- the group ledgers -

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$unitCode = $first.unit.code
$written = @()

foreach ($g in ($students | Group-Object { $groupOf[$_.studentId] } | Sort-Object Name)) {
    $name = $g.Name
    # Sorted by surname then first name: the record is read down the page by a
    # person looking for one learner, not in the order the runs happened.
    $rows = @($g.Group | Sort-Object surname, firstName)

    # Serial numbers are the row numbers of THIS record and are renumbered.
    for ($i = 0; $i -lt $rows.Count; $i++) { $rows[$i].serial = $i + 1 }

    # The record's own date block is the latest run it draws on — the day it was
    # completed. Each row still shows its own learner's feedback date.
    $latest = ($rows | Sort-Object markingDate -Descending)[0]
    $src    = @($loaded | Where-Object { $_.L.dates.markingDate -eq $latest.markingDate })[0].L

    # A short slug for file names. WiseNet course-offer descriptions repeat the
    # qualification on every group ('Certificate III in Solid Plastering -
    # Group 2'), and putting all of that in a file name pushes the part that
    # actually distinguishes the record off the end of a folder listing. Where
    # the description ends in a group number, that is the slug.
    if ($name -match '(?i)\bgroup\s*([0-9A-Za-z]+)\s*$') { $slug = 'Group_' + $Matches[1] }
    else { $slug = ($name -replace '[^A-Za-z0-9]+', '_').Trim('_') }
    $compact = ([datetime]$latest.markingDate).ToString('ddMMyyyy')

    $out = [pscustomobject]@{
        rto           = $first.rto
        unit          = $first.unit
        qualification = $first.qualification
        assessor      = $first.assessor
        location      = $first.location
        environment   = $first.environment
        tools         = $first.tools
        dates         = $src.dates
        group         = [pscustomobject]@{
            name          = $name
            slug          = $slug
            students      = $rows.Count
            markingDates  = @($rows | ForEach-Object { $_.markingDateText } | Sort-Object -Unique)
            sourceLedgers = @($rows | ForEach-Object { $_.sourceLedger } | Sort-Object -Unique)
        }
        students      = $rows
        markedCopies  = @()
        amrrFile      = "AMLC_${unitCode}_${slug}_${compact}.docx"
        summary       = [pscustomobject]@{
            students        = $rows.Count
            competent       = @($rows | Where-Object { $_.overall -eq 'C' }).Count
            notYetCompetent = @($rows | Where-Object { $_.overall -eq 'NYC' }).Count
            tools           = @($first.tools).Count
        }
    }

    $dest = Join-Path $OutDir ("group_{0}.json" -f $slug)
    $payload = ConvertTo-Json -InputObject $out -Depth 12
    [System.IO.File]::WriteAllText($dest, $payload, (New-Object System.Text.UTF8Encoding($false)))
    $written += $dest

    if (-not $Quiet) {
        Write-Output ("  {0,-52} {1,2} student(s)  {2} C / {3} NYC  ->  {4}" -f `
            $name, $rows.Count, $out.summary.competent, $out.summary.notYetCompetent, (Split-Path -Leaf $dest))
    }
}

if (-not $Quiet) {
    Write-Output ''
    Write-Output ("{0} student(s) from {1} ledger(s) consolidated into {2} group record(s)." -f $students.Count, $loaded.Count, $written.Count)
}
$written
