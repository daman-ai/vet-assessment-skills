<#
  Import-WisenetMatrix.ps1 — read a WiseNet "Unit Enrolment Outcome Matrix"
  (report 0217) and work out which students must submit a given unit.

  THE RULE THE MATRIX ENCODES, cell by cell, for one student in one unit column:

    blacked-out cell   the student is NOT ATTACHED to the unit. They were never
                       enrolled in it. They are not marked and they do not
                       appear on any record.
    an outcome code    a result already exists — 20 competency achieved,
                       40 withdrawn, and so on. Nothing to mark.
    a BLANK cell,      the student is enrolled in the unit with no result yet.
    not blacked out    THESE are the students required to submit.

  The report's own legend states the first of those: a black cell reads
  "- Not Attached to Unit".

  Identity is the RefInternal student ID, never the name. One learner can hold
  two enrolments in the same course offer and appear on two rows.

  Usage:
    .\Import-WisenetMatrix.ps1 -Path rpt_WiseNET_0217.xls -Unit BSBOPS501
    .\Import-WisenetMatrix.ps1 -Path <file> -Unit <code> -Json out.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Unit,
    # The unit's prerequisite code(s), from Get-UnitPrerequisites.ps1. Each is
    # looked up as its own column on the same matrix.
    [string[]]$Prerequisite = @(),
    # Which worksheet to read. A WiseNet export often carries one sheet per
    # course offer, so the same unit appears on several of them with a
    # different class each time. Accepts a 1-based index or a sheet name.
    [string]$Sheet = '1',
    [string]$Json,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

# AVETMISS national outcome codes, as printed on the report itself.
$OUTCOME = @{
    '20'   = 'Competency achieved/pass'
    '30'   = 'Competency not achieved/fail'
    '40'   = 'Withdrawn'
    '51'   = 'Recognition of Prior Learning'
    '53'   = 'Recognition of Current Competency'
    '60'   = 'Credit Transfer'
    '70'   = 'Continuing Enrolment'
    '70AP' = 'Academic Pass (SA Only)'
    '81'   = 'Non-assessable Enrolment - satisfactorily completed'
    '82'   = 'Non-assessable Enrolment - Withdrawn or not satisfactorily completed'
    '85'   = 'Not Yet Started'
    '90'   = 'Enrolled'
}

# Codes that mean "enrolled, no result yet". A student carrying one of these is
# NOT selected by the blank-cell rule, but is reported separately rather than
# dropped in silence: whether they are due to submit is a judgement the
# assessor makes against the class roll, not one this script should make alone.
$PENDING = @('70', '85', '90')

if (-not (Test-Path -LiteralPath $Path)) { throw "WiseNet report not found: $Path" }
$full = (Resolve-Path -LiteralPath $Path).Path

$excel = $null
try {
    try { $excel = New-Object -ComObject Excel.Application }
    catch { throw "Excel is required to read a WiseNet .xls export and is not available on this machine. Open the report and save it as .xlsx or .csv, or supply the student list directly. ($($_.Exception.Message))" }

    $excel.Visible = $false
    $excel.DisplayAlerts = $false
    $wb = $excel.Workbooks.Open($full, 0, $true)      # read-only
    $sheetNames = @()
    foreach ($s in $wb.Worksheets) { $sheetNames += "$($s.Name)" }
    if ($Sheet -match '^\d+$') {
        $idx = [int]$Sheet
        if ($idx -lt 1 -or $idx -gt $sheetNames.Count) {
            throw ("Sheet {0} does not exist. This workbook has {1} sheet(s): {2}" -f $Sheet, $sheetNames.Count, ($sheetNames -join ', '))
        }
        $ws = $wb.Worksheets.Item($idx)
    } else {
        if ($sheetNames -notcontains $Sheet) {
            throw ("Sheet '{0}' not found. This workbook has: {1}" -f $Sheet, ($sheetNames -join ', '))
        }
        $ws = $wb.Worksheets.Item($Sheet)
    }
    $sheetName = "$($ws.Name)"

    # ONE WORKSHEET PER COURSE-OFFER GROUP. An export covering four groups is
    # four worksheets, and reading only the first is how a run once concluded
    # that nobody had to submit while thirteen learners waited on sheets 2 to 4.
    # Defaulting to sheet 1 is right for a single-sheet export and silently
    # wrong for any other, so say so rather than answer a quarter of the cohort
    # confidently. Read-Groups.ps1 reads them all.
    if ($sheetNames.Count -gt 1 -and -not $PSBoundParameters.ContainsKey('Sheet')) {
        Write-Warning ("This workbook has {0} worksheets ({1}) and no -Sheet was given, so only '{2}' was read. A 0217 export carries one sheet per course offer: run once per sheet, or use Read-Groups.ps1 to read every one." -f $sheetNames.Count, ($sheetNames -join ', '), $sheetName)
    }

    $rows = $ws.UsedRange.Rows.Count
    $cols = $ws.UsedRange.Columns.Count

    function Cell-Text { param([int]$r, [int]$c)
        ("$($ws.Cells.Item($r, $c).Text)" -replace '[\r\n]+', ' ').Trim()
    }
    function Cell-IsBlack { param([int]$r, [int]$c)
        # Interior.Color 0 is solid black — the report's "Not Attached to Unit" fill.
        [double]$ws.Cells.Item($r, $c).Interior.Color -eq 0
    }

    # ---- locate the unit header row and the learner header row -------------
    $unitRow = 0; $learnerRow = 0; $unitsCol = 0
    for ($r = 1; $r -le $rows; $r++) {
        for ($c = 1; $c -le $cols; $c++) {
            $t = Cell-Text $r $c
            if ($t -eq 'Units' -and $unitRow -eq 0)        { $unitRow = $r; $unitsCol = $c }
            if ($t -eq 'Learner Name' -and $learnerRow -eq 0) { $learnerRow = $r }
        }
        if ($unitRow -and $learnerRow) { break }
    }
    if (-not $unitRow)    { throw "No 'Units' header row found. This does not look like a WiseNet 0217 Unit Enrolment Outcome Matrix." }
    if (-not $learnerRow) { throw "No 'Learner Name' header row found. This does not look like a WiseNet 0217 Unit Enrolment Outcome Matrix." }

    # ---- map every unit column, honouring merged headers -------------------
    $unitCols = @{}          # unit code -> first column of its (possibly merged) header
    $allUnits = @()
    for ($c = $unitsCol + 1; $c -le $cols; $c++) {
        $t = Cell-Text $unitRow $c
        if ($t -eq '') { continue }
        $code = ($t -split '\s+')[0]
        if ($code -match '^[A-Z]{3}[A-Z0-9]{3,}$') {
            $ma = $ws.Cells.Item($unitRow, $c).MergeArea
            $unitCols[$code] = [int]$ma.Column
            $allUnits += $code
        }
    }
    if ($unitCols.Count -eq 0) { throw 'No unit columns found on the matrix.' }

    $unitKey = $Unit.ToUpper().Trim()
    if (-not $unitCols.ContainsKey($unitKey)) {
        throw ("Unit '{0}' is not on this matrix. Units present: {1}" -f $Unit, ($allUnits -join ', '))
    }
    $col = $unitCols[$unitKey]

    # ---- header columns ----------------------------------------------------
    $nameCol = 0; $refCol = 0; $statusCol = 0; $startCol = 0
    for ($c = 1; $c -le $cols; $c++) {
        switch (Cell-Text $learnerRow $c) {
            'Learner Name' { $nameCol = $c }
            'Status'       { $statusCol = $c }
            default {
                $h = Cell-Text $learnerRow $c
                if ($h -like 'RefInternal*') { $refCol = $c }
                if ($h -like 'Reg Start*')   { $startCol = $c }
            }
        }
    }
    if (-not $nameCol) { $nameCol = 1 }

    # ---- course offer context ---------------------------------------------
    $offerCode = ''; $offerDesc = ''; $location = ''
    for ($r = 1; $r -lt $learnerRow; $r++) {
        for ($c = 1; $c -le 8; $c++) {
            $t = Cell-Text $r $c
            if ($t -eq 'Course Offer Code:' -and -not $offerCode) { for ($k=$c+1; $k -le $cols; $k++) { $v = Cell-Text $r $k; if ($v) { $offerCode = $v; break } } }
            if ($t -eq 'Course Offer Desc:' -and -not $offerDesc) { for ($k=$c+1; $k -le $cols; $k++) { $v = Cell-Text $r $k; if ($v) { $offerDesc = $v; break } } }
            if ($t -eq 'Location:'          -and -not $location)  { for ($k=$c+1; $k -le $cols; $k++) { $v = Cell-Text $r $k; if ($v) { $location  = $v; break } } }
        }
    }

    # ---- walk the student rows --------------------------------------------
    $required = @(); $excluded = @(); $notAttached = @(); $pending = @(); $nameProblems = @()
    $pendingEnrolment = @()

    for ($r = $learnerRow + 1; $r -le $rows; $r++) {
        $rawName = Cell-Text $r $nameCol
        if ($rawName -eq '') { continue }

        # WiseNet prints 'Given SURNAME'; a missing surname renders as '--'.
        $clean = ($rawName -replace '\s*--\s*$', '').Trim()
        $parts = @($clean -split '\s+' | Where-Object { $_ -ne '' })
        $first = ''; $sur = ''
        if ($parts.Count -ge 2 -and $parts[-1] -cmatch '^[A-Z][A-Z''\-]+$') {
            $sur   = $parts[-1]
            $first = ($parts[0..($parts.Count - 2)] -join ' ')
        } else {
            $first = $clean
        }

        $ref    = if ($refCol)    { (Cell-Text $r $refCol) -replace '\s*\(\s*\)\s*$', '' } else { '' }
        $status = if ($statusCol) { Cell-Text $r $statusCol } else { '' }
        $start  = if ($startCol)  { Cell-Text $r $startCol }  else { '' }

        $rec = [pscustomobject]@{
            firstName    = $first
            surname      = $sur
            displayName  = $clean
            studentId    = $ref
            status       = $status
            regStart     = $start
            row          = $r
        }

        if (Cell-IsBlack $r $col) {
            $notAttached += $rec
            continue
        }

        $code = Cell-Text $r $col
        if ($code -ne '') {
            $meaning = if ($OUTCOME.ContainsKey($code)) { $OUTCOME[$code] } else { 'unrecognised outcome code' }
            $withCode = $rec | Select-Object *, @{n='outcomeCode';e={$code}}, @{n='outcomeMeaning';e={$meaning}}
            if ($PENDING -contains $code) { $pending += $withCode } else { $excluded += $withCode }
            continue
        }

        # RTO RULE: a student whose ENROLMENT status is Pending is NOT marked.
        # Their enrolment has not started, so there is no assessment to expect
        # and no result to record — and a record produced for them says an
        # assessment happened that did not. They are listed rather than dropped,
        # because 'not on the list' and 'not yet enrolled' are different answers
        # to the question the assessor is asking.
        if ("$status".Trim() -match '^(?i)pending') {
            $pendingEnrolment += $rec
            continue
        }

        # blank, not blacked out — enrolled with no result yet
        if (-not $sur) { $nameProblems += $rec }
        $required += $rec
    }

    # ---- does each student HOLD the prerequisite? --------------------------
    #
    # THERE IS NO 'unknown' ON THIS AXIS, and that is deliberate. The matrix is
    # the record. Where it does not positively show the prerequisite as held —
    # including where the student is not attached to it, and where the report
    # carries no column for it at all — the prerequisite is NOT COMPLETED and
    # the student's result is withheld.
    #
    # This is the opposite of the training.gov.au rule in Get-UnitPrerequisites.ps1.
    # There, an absence means the skill failed to read the source, so it stops and
    # asks. Here, an absence is a statement about the student, so it decides. A
    # student who holds the unit from another RTO will not appear on this matrix,
    # which is what the assessor's confirmedExternally override is for.
    $COMPLETED_CODES = @('20', '51', '53', '60', '70AP', '81')
    $prereqStatus  = @()
    $prereqMissing = @()

    foreach ($pcode in @($Prerequisite | Where-Object { "$_".Trim() -ne '' } | ForEach-Object { "$_".ToUpper().Trim() })) {
        $pcol = if ($unitCols.ContainsKey($pcode)) { $unitCols[$pcode] } else { 0 }
        foreach ($s in $required) {
            $status = 'notCompleted'; $reason = ''; $seen = ''
            if (-not $pcol) {
                $reason = "the report carries no column for $pcode"
            } elseif (Cell-IsBlack $s.row $pcol) {
                $reason = "not attached to $pcode on the matrix"
            } else {
                $seen = Cell-Text $s.row $pcol
                if ($seen -eq '') {
                    $reason = "the $pcode cell is blank — enrolled with no result"
                } elseif ($COMPLETED_CODES -contains $seen) {
                    $status = 'completed'
                    $reason = "$seen — $(if ($OUTCOME.ContainsKey($seen)) { $OUTCOME[$seen] } else { 'completion code' })"
                } else {
                    $reason = "$seen — $(if ($OUTCOME.ContainsKey($seen)) { $OUTCOME[$seen] } else { 'unrecognised outcome code' })"
                }
            }
            $entry = [pscustomobject]@{
                studentId   = $s.studentId
                displayName = $s.displayName
                prerequisite= $pcode
                status      = $status
                outcomeSeen = $seen
                reason      = $reason
            }
            $prereqStatus += $entry
            if ($status -ne 'completed') { $prereqMissing += $entry }
        }
    }

    $result = [pscustomobject]@{
        source        = Split-Path -Leaf $full
        sheet         = $sheetName
        sheetsInFile  = $sheetNames
        unit          = $unitKey
        unitColumn    = $col
        prerequisites      = @($Prerequisite | Where-Object { "$_".Trim() -ne '' })
        prerequisiteStatus = $prereqStatus
        prerequisiteMissing= $prereqMissing
        courseCode    = $offerCode
        courseDesc    = $offerDesc
        location      = $location
        unitsOnMatrix = $allUnits
        required         = $required
        pending          = $pending
        pendingEnrolment = $pendingEnrolment
        excluded         = $excluded
        notAttached      = $notAttached
        nameProblems     = $nameProblems
    }

    if ($Json) {
        $result | ConvertTo-Json -Depth 8 | Out-File -Encoding utf8 -LiteralPath $Json
        if (-not $Quiet) { Write-Output "Written: $Json" }
    }

    if (-not $Quiet) {
        Write-Output ''
        Write-Output "WISENET UNIT ENROLMENT OUTCOME MATRIX — $($result.source)"
        Write-Output ("  Sheet      {0}   (of {1}: {2})" -f $sheetName, $sheetNames.Count, ($sheetNames -join ', '))
        Write-Output ("  Course     {0} {1}" -f $offerCode, $offerDesc)
        Write-Output ("  Unit       {0}   (column {1} of {2} units on the matrix)" -f $unitKey, $col, $allUnits.Count)
        Write-Output ''
        Write-Output ("REQUIRED TO SUBMIT — {0} student(s). Blank cell, not blacked out." -f $required.Count)
        foreach ($s in $required) {
            Write-Output ("    {0,-28} {1,-14} {2}" -f $s.displayName, $s.studentId, $s.status)
        }
        if ($pendingEnrolment.Count) {
            Write-Output ''
            Write-Output ("PENDING ENROLMENT — {0}, not marked. Their enrolment has not started, so there is" -f $pendingEnrolment.Count)
            Write-Output  '  no assessment to expect and no result to record. They are marked once it does.'
            foreach ($s in $pendingEnrolment) { Write-Output ("    {0,-28} {1,-14} {2}  starts {3}" -f $s.displayName, $s.studentId, $s.status, $s.regStart) }
        }
        if ($pending.Count) {
            Write-Output ''
            Write-Output ("ENROLLED, RESULT PENDING — {0}. A code is recorded, so the blank-cell rule does not" -f $pending.Count)
            Write-Output  '  select them. Confirm against the class roll whether they are due to submit.'
            foreach ($s in $pending) { Write-Output ("    {0,-28} {1,-14} {2} — {3}" -f $s.displayName, $s.studentId, $s.outcomeCode, $s.outcomeMeaning) }
        }
        if ($excluded.Count) {
            Write-Output ''
            Write-Output ("ALREADY HAVE AN OUTCOME — {0}, not marked:" -f $excluded.Count)
            foreach ($s in $excluded) { Write-Output ("    {0,-28} {1,-14} {2} — {3}" -f $s.displayName, $s.studentId, $s.outcomeCode, $s.outcomeMeaning) }
        }
        if ($notAttached.Count) {
            Write-Output ''
            Write-Output ("NOT ATTACHED TO THE UNIT — {0}, never enrolled, no record produced:" -f $notAttached.Count)
            foreach ($s in $notAttached) { Write-Output ("    {0,-28} {1}" -f $s.displayName, $s.studentId) }
        }
        if ($prereqMissing.Count) {
            Write-Output ''
            Write-Output ("PREREQUISITE NOT COMPLETED — {0}. Each student's result is WITHHELD (RW) until" -f $prereqMissing.Count)
            Write-Output  '  the prerequisite is held. The matrix is the record: an absence in it is a'
            Write-Output  '  statement, not a gap.'
            # The no-column case is the one an assessor most often needs to
            # override, so it is listed on its own rather than folded in.
            $noCol = @($prereqMissing | Where-Object { $_.reason -like 'the report carries no column*' })
            $onMat = @($prereqMissing | Where-Object { $_.reason -notlike 'the report carries no column*' })
            foreach ($s in $onMat) {
                Write-Output ("    {0,-28} {1,-14} {2}  —  {3}" -f $s.displayName, $s.studentId, $s.prerequisite, $s.reason)
            }
            if ($noCol.Count) {
                Write-Output ''
                Write-Output ("  NO COLUMN ON THIS REPORT — {0}. These students may well hold the unit; the" -f $noCol.Count)
                Write-Output  '  report simply does not cover it. Check before withholding a result.'
                foreach ($s in $noCol) {
                    Write-Output ("    {0,-28} {1,-14} {2}" -f $s.displayName, $s.studentId, $s.prerequisite)
                }
            }
            Write-Output ''
            Write-Output  '  Where a student holds the prerequisite from ANOTHER RTO it cannot appear here.'
            Write-Output  '  Record the assessor override in the ledger, with the evidence seen:'
            Write-Output  '     "prerequisiteStatus": { "<CODE>": { "status": "confirmedExternally",'
            Write-Output  '                                          "evidence": "Statement of Attainment, ..." } }'
            Write-Output  '  A testamur, a Statement of Attainment or an authenticated USI/VET transcript.'
            Write-Output  '  A verbal claim, a licence card or a white card is NOT acceptable evidence.'
        }
        if ($nameProblems.Count) {
            Write-Output ''
            Write-Output ("SURNAME MISSING ON THE MATRIX — {0}. WiseNet printed '--'. Get the surname before" -f $nameProblems.Count)
            Write-Output  '  building records; the ledger will reject a student without one.'
            foreach ($s in $nameProblems) { Write-Output ("    {0,-28} {1}" -f $s.displayName, $s.studentId) }
        }
        Write-Output ''
    }

    $result
}
finally {
    if ($wb)    { try { $wb.Close($false) } catch {} }
    if ($excel) { try { $excel.Quit() } catch {}; [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) }
}
