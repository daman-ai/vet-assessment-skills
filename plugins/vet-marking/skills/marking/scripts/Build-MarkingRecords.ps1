<#
  Build-MarkingRecords.ps1 — render every marking document from one resolved ledger.

  Produces, into -OutDir:
      one SAR per student
      one Assessment Marking and Results Record for the class
      one Student Feedback Sheet per student assessed NYC

  Every value comes from the resolved ledger. This script makes no marking
  judgement, computes no date, and invents no text. It fills the RTO's approved
  templates and changes nothing else — headers, footers, styles, document
  numbering and version control are never touched.

  Usage:
    .\Build-MarkingRecords.ps1 -Ledger resolved.json -OutDir .\out
    .\Build-MarkingRecords.ps1 -Ledger ledger.json -OutDir .\out -Resolve
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Ledger,
    [Parameter(Mandatory)][string]$OutDir,
    [switch]$Resolve,
    [string]$RtoProfile,
    [string]$SubmissionRoot,
    [switch]$NoMarkedCopies
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-Docx.ps1')

$AssetRoot = Join-Path $PSScriptRoot '..\assets'
$BOX_E = [char]0x2610
$BOX_T = [char]0x2612

# --------------------------------------------------------------- ledger -----

if ($Resolve) {
    $tmp = Join-Path $env:TEMP ("resolved_" + [guid]::NewGuid().ToString('N') + '.json')
    & (Join-Path $PSScriptRoot 'Resolve-MarkingLedger.ps1') -Path $Ledger -Out $tmp -Quiet | Out-Null
    $Ledger = $tmp
}
$L = Get-Content -Raw -Encoding UTF8 -LiteralPath $Ledger | ConvertFrom-Json
if (-not $L.dates) { throw "This looks like an unresolved ledger. Run Resolve-MarkingLedger.ps1 first, or pass -Resolve." }

# ------------------------------------------------------------ RTO profile ---

if (-not $RtoProfile) { $RtoProfile = Join-Path $AssetRoot ("rto.{0}.json" -f $L.rto) }
if (-not (Test-Path -LiteralPath $RtoProfile)) {
    throw "No profile for RTO '$($L.rto)'. Expected $RtoProfile. Register the RTO and measure its three templates with Measure-Template.ps1 before marking."
}
$Rto = Get-Content -Raw -Encoding UTF8 -LiteralPath $RtoProfile | ConvertFrom-Json

if ($Rto.PSObject.Properties.Name.Contains('status') -and $Rto.status -eq 'awaiting-templates') {
    $missing = @()
    foreach ($k in @('sar','amrr','feedback')) { if (-not $Rto.templates.$k.file) { $missing += $k } }
    throw @"
RTO '$($L.rto)' ($($Rto.rto.tradingName)) is registered but its templates have not been supplied.

Missing: $($missing -join ', ')

This build will NOT fall back to another RTO's templates. A Meridian-headed SAR
carrying an ACI student's result is a wrong record, not a near-miss. Ask the RTO
for its Student Assessment Record, Assessment Marking and Results Record and
Student Feedback Sheet templates, copy them into assets/templates/, measure each
with Measure-Template.ps1, and complete $RtoProfile.
"@
}

function Get-TemplatePath { param([string]$Key)
    $rel = $Rto.templates.$Key.file
    if (-not $rel) { throw "RTO profile declares no '$Key' template." }
    $full = Join-Path $AssetRoot $rel
    if (-not (Test-Path -LiteralPath $full)) { throw "Template file missing: $full" }
    $full
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$built = @()

# ------------------------------------------------------------- helpers ------

function Get-TableByKey { param($Pkg, $Spec, [string]$Key)
    $tbls = @(Get-Tables $Pkg)
    $idx = $Spec.tables.$Key.index
    if (-not $idx) { throw "Template map has no table '$Key'." }
    if ($idx -gt $tbls.Count) {
        throw "Template map expects table $idx ('$Key') but the file has $($tbls.Count). The template has been revised — re-measure it with Measure-Template.ps1 before marking."
    }
    $tbls[$idx - 1]
}

function Assert-Filled { param($Count, [string]$What)
    if ($Count -lt 1) { throw "Nothing filled for '$What'. The template no longer carries that field — re-measure it." }
}

# =============================================================== SAR ==========

function Build-Sar {
    param($Student)

    $spec = $Rto.templates.sar
    $pkg  = Open-Docx -Path (Get-TemplatePath 'sar')
    try {
        $ns = $pkg.Ns
        $tDetails = Get-TableByKey $pkg $spec 'details'
        $tOut     = Get-TableByKey $pkg $spec 'outcomes'
        $tCert    = Get-TableByKey $pkg $spec 'certification'
        $tAdmin   = Get-TableByKey $pkg $spec 'admin'

        # ---- Assessment Details (scoped to its own table) ------------------
        if ($Rto.rtoRowIsPlaceholder) {
            [void](Set-Placeholder -Node $tDetails -Ns $ns -Name 'Insert RTO name and code' -Value $Rto.rto.identityLine)
        }
        Assert-Filled (Set-Placeholder -Node $tDetails -Ns $ns -Name 'Insert qualification code and title' -Value ("{0} {1}" -f $L.qualification.code, $L.qualification.title)) 'qualification'
        Assert-Filled (Set-Placeholder -Node $tDetails -Ns $ns -Name 'Insert student name' -Value $Student.fullName) 'student name'
        Assert-Filled (Set-Placeholder -Node $tDetails -Ns $ns -Name 'Insert student ID'   -Value $Student.studentId) 'student ID'
        Assert-Filled (Set-Placeholder -Node $tDetails -Ns $ns -Name 'Insert trainer / assessor name' -Value $L.assessor) 'assessor (details)'
        Assert-Filled (Set-Placeholder -Node $tDetails -Ns $ns -Name 'dd / mm / yyyy' -Value $L.dates.assessmentDateText) 'date of assessment'
        Assert-Filled (Set-Placeholder -Node $tDetails -Ns $ns -Name 'Insert unit code and title' -Value ("{0} {1}" -f $L.unit.code, $L.unit.title)) 'unit'
        Assert-Filled (Set-Placeholder -Node $tDetails -Ns $ns -Name 'Insert pre-requisite unit, or N/A' -Value $L.unit.prerequisite) 'prerequisite'
        Assert-Filled (Set-Placeholder -Node $tDetails -Ns $ns -Name 'Core / Elective' -Value $L.unit.coreElective) 'core/elective'
        Assert-Filled (Set-Placeholder -Node $tDetails -Ns $ns -Name 'Insert location' -Value $L.location) 'location'
        Assert-Filled (Set-Placeholder -Node $tDetails -Ns $ns -Name 'Simulated environment / Workplace — specify' -Value $L.environment) 'environment'

        # ---- Assessment Outcomes -------------------------------------------
        $om = $spec.outcomeRows
        $cells = $om.cells

        # grow or shrink the tool rows to the real tool count
        $toolRows = @()
        $r1 = @(Find-RowByText $tOut $ns @($om.tool1RowText))
        $r2 = @(Find-RowByText $tOut $ns @($om.tool2RowText))
        if ($r1.Count -ne 1 -or $r2.Count -ne 1) {
            throw "SAR template: expected exactly one row per tool field, found $($r1.Count) and $($r2.Count). Re-measure the template."
        }
        $toolRows = @($r1[0], $r2[0])

        $need = @($L.tools).Count
        if ($need -lt 1) { throw 'No tools in the ledger.' }

        while ($toolRows.Count -gt $need) {
            Remove-Row $toolRows[$toolRows.Count - 1]
            $toolRows = $toolRows[0..($toolRows.Count - 2)]
        }
        while ($toolRows.Count -lt $need) {
            # clone the SECOND tool row: row 1 carries the vMerge master cell that
            # spans the tool block, and duplicating it would split the panel.
            $clone = Copy-RowAfter $toolRows[$toolRows.Count - 1]
            $toolRows += $clone
        }

        for ($i = 0; $i -lt $need; $i++) {
            $tool = $L.tools[$i]
            $res  = @($Student.results | Where-Object { $_.toolId -eq $tool.id })[0]
            if (-not $res) { throw "No judgement for tool '$($tool.name)' on $($Student.fullName)." }

            $row = $toolRows[$i]
            $rc  = @(Get-Cells $row $ns)

            # tool name — the field on a cloned row is whatever it was cloned from
            $nameCell = $rc[$cells.toolName - 1]
            foreach ($n in @(1, 2)) {
                [void](Set-Placeholder -Node $nameCell -Ns $ns -Name "Insert assessment tool $n" -Value $tool.name)
            }
            # Cloned rows carry the field they were cloned from, so one of the two
            # forms above always lands. If neither did, the template's tool rows are
            # not shaped the way the map says — stop rather than write a tool name
            # into a cell nobody has measured.
            if ((Get-RunText $nameCell $ns) -notlike "*$($tool.name)*") {
                throw "SAR template: could not place tool name '$($tool.name)' in row $($i + 1). Re-measure the template with Measure-Template.ps1."
            }

            [void](Set-BracketedBox -Node $rc[$cells.s   - 1] -Ns $ns -Ticked ($res.result -eq 'S'))
            [void](Set-BracketedBox -Node $rc[$cells.nys - 1] -Ns $ns -Ticked ($res.result -eq 'NYS'))

            $fb = $rc[$cells.feedback - 1]
            $labels = $spec.checkboxes.perToolRow.feedbackOptions.labels
            foreach ($opt in @('completed','notSubmitted','corrections')) {
                [void](Set-LabelledBox -Node $fb -Ns $ns -Label $labels.$opt -Ticked ($res.feedbackOption -eq $opt))
            }
            [void](Set-Placeholder -Node $fb -Ns $ns -Name 'Insert feedback to student' -Value $res.feedback)
        }

        # ---- resit row ------------------------------------------------------
        $resitRows = @(Find-RowByText $tOut $ns @($om.resitRowText))
        if ($resitRows.Count -ge 1) {
            $rr = $resitRows[0]
            $rc = @(Get-Cells $rr $ns)
            if ($Student.resit) {
                [void](Set-LabelledBox -Node $rc[$cells.toolName - 1] -Ns $ns -Label $om.resitRowText -Ticked $true)
                [void](Set-BracketedBox -Node $rc[$cells.s   - 1] -Ns $ns -Ticked ($Student.resit.result -eq 'S'))
                [void](Set-BracketedBox -Node $rc[$cells.nys - 1] -Ns $ns -Ticked ($Student.resit.result -eq 'NYS'))
                $fb = $rc[$cells.feedback - 1]
                $labels = $spec.checkboxes.perToolRow.feedbackOptions.labels
                foreach ($opt in @('completed','notSubmitted','corrections')) {
                    [void](Set-LabelledBox -Node $fb -Ns $ns -Label $labels.$opt -Ticked ($Student.resit.option -eq $opt))
                }
                [void](Set-Placeholder -Node $fb -Ns $ns -Name 'Insert feedback to student' -Value $Student.resit.feedback)
            } else {
                # no resit: boxes stay ☐, brackets go, feedback reads N/A
                [void](Set-BracketedBox -Node $rc[$cells.s   - 1] -Ns $ns -Ticked $false)
                [void](Set-BracketedBox -Node $rc[$cells.nys - 1] -Ns $ns -Ticked $false)
                [void](Set-Placeholder -Node $rc[$cells.feedback - 1] -Ns $ns -Name 'Insert feedback to student' -Value 'N/A')
            }
        }

        # ---- re-enrol -------------------------------------------------------
        [void](Set-LabelledBox -Node $tOut -Ns $ns -Label $spec.checkboxes.reEnrol.label -Ticked ([bool]$Student.reEnrol))

        # ---- certification --------------------------------------------------
        [void](Set-LabelledBox -Node $tCert -Ns $ns -Label 'is Competent'         -Ticked ($Student.overall -eq 'C'))
        [void](Set-LabelledBox -Node $tCert -Ns $ns -Label 'is Not Yet Competent' -Ticked ($Student.overall -eq 'NYC'))
        [void](Set-LabelledBox -Node $tCert -Ns $ns -Label 'has been advised of the result' -Ticked $true)
        Assert-Filled (Set-Placeholder -Node $tCert -Ns $ns -Name 'Insert trainer / assessor name' -Value $L.assessor) 'assessor (certification)'
        Assert-Filled (Set-Placeholder -Node $tCert -Ns $ns -Name 'dd / mm / yyyy' -Value $L.dates.markingDateText) 'certification date'

        # ---- admin note -----------------------------------------------------
        [void](Set-LabelledBox -Node $tAdmin -Ns $ns -Label 'Resit invoice raised' -Ticked ([bool]$Student.invoiceRaised))
        [void](Set-LabelledBox -Node $tAdmin -Ns $ns -Label 'Not applicable'       -Ticked (-not [bool]$Student.invoiceRaised))
        foreach ($lab in @('Results updated in the student management system',
                           'Assessment scanned and stored in the student management system',
                           'Feedback / appeals information sent to the student')) {
            [void](Set-LabelledBox -Node $tAdmin -Ns $ns -Label $lab -Ticked $true)
        }
        Assert-Filled (Set-Placeholder -Node $tAdmin -Ns $ns -Name 'dd / mm / yyyy' -Value $L.dates.resultsEnteredText) 'results entered date'

        $dest = Join-Path $OutDir $Student.sarFile
        [void](Save-Docx -Package $pkg -Destination $dest)
        $dest
    } catch { Close-Docx $pkg; throw }
}

# =============================================================== AMRR ========

function Build-Amrr {
    $spec = $Rto.templates.amrr
    $pkg  = Open-Docx -Path (Get-TemplatePath 'amrr')
    try {
        $ns = $pkg.Ns
        $tHead     = Get-TableByKey $pkg $spec 'header'
        $tStudents = Get-TableByKey $pkg $spec 'students'
        $tSign     = Get-TableByKey $pkg $spec 'signOff'

        # ---- header ---------------------------------------------------------
        if ($Rto.rtoRowIsPlaceholder) {
            [void](Set-Placeholder -Node $tHead -Ns $ns -Name 'Insert RTO name and code' -Value $Rto.rto.identityLine)
        }
        Assert-Filled (Set-Placeholder -Node $tHead -Ns $ns -Name 'Insert trainer / assessor name' -Value $L.assessor) 'assessor (header)'
        Assert-Filled (Set-Placeholder -Node $tHead -Ns $ns -Name 'Insert qualification code and title' -Value ("{0} {1}" -f $L.qualification.code, $L.qualification.title)) 'qualification'
        Assert-Filled (Set-Placeholder -Node $tHead -Ns $ns -Name 'dd / mm / yyyy' -Value $L.dates.assessmentDateText) 'date of assessment'
        Assert-Filled (Set-Placeholder -Node $tHead -Ns $ns -Name 'Insert unit code and title' -Value ("{0} {1}" -f $L.unit.code, $L.unit.title)) 'unit'
        Assert-Filled (Set-Placeholder -Node $tHead -Ns $ns -Name 'Insert pre-requisite unit, or N/A' -Value $L.unit.prerequisite) 'prerequisite'

        # ---- tool columns ---------------------------------------------------
        $st    = $spec.studentTable
        $cols  = $st.columns
        $tools = @($L.tools)
        $extra = $tools.Count - $cols.toolColumns

        if ($extra -lt 0) {
            throw "This unit has $($tools.Count) tool(s) and the marking record template has $($cols.toolColumns) tool columns. Removing a column changes an approved record's shape — ask the RTO for a one-tool template rather than cutting one out."
        }
        if ($extra -gt 0) {
            # Row 1 is the grouped header — 'Assessment Tools' already spans the
            # tool block, so it takes a wider gridSpan rather than a new cell.
            $groupedRows = @(1..($st.headerRows - 1))
            # 0-based index of the new column. It must land INSIDE the existing
            # tool block, not one past it: the grouped header widens whichever
            # cell already covers this index, and one past the block is the
            # first column of 'Results'. Insert there and the new tool column
            # is filled correctly but sits under the wrong heading — 'Results'
            # spanning 4 and 'Assessment Tools' still spanning 2.
            #   tool columns occupy 0-based (firstToolColumn-1) .. (firstToolColumn+toolColumns-2)
            #   so the last of them is firstToolColumn + toolColumns - 2
            $insertAt = $cols.firstToolColumn + $cols.toolColumns - 2
            $width    = [int][Math]::Floor(1620 / [Math]::Max(1, $extra))
            for ($e = 0; $e -lt $extra; $e++) {
                [void](Add-TableColumn -Table $tStudents -Ns $ns -At ($insertAt + $e) -Width $width -WidenSpanRows $groupedRows)
            }
        }

        # ---- tool name row --------------------------------------------------
        $rows = @(Get-Rows $tStudents $ns)
        $toolRow = $rows[$st.toolNameRow - 1]
        $trc = @(Get-Cells $toolRow $ns)
        for ($i = 0; $i -lt $tools.Count; $i++) {
            $cell = $trc[$cols.firstToolColumn - 1 + $i]
            $done = Set-Placeholder -Node $cell -Ns $ns -Name ("Insert assessment tool {0}" -f ($i + 1)) -Value $tools[$i].name
            if ($done -lt 1) {
                # an inserted column starts blank; write the heading in full
                [void](Set-CellText -Cell $cell -Ns $ns -Value $tools[$i].name)
                [void](Add-CellLine -Cell $cell -Ns $ns -Value 'S / NYS')
            }
        }

        # ---- student rows ---------------------------------------------------
        $allRows      = @(Get-Rows $tStudents $ns)
        $templateRows = @()
        for ($i = $st.firstStudentRow - 1; $i -lt $allRows.Count; $i++) { $templateRows += $allRows[$i] }

        $students = @($L.students)
        $rowsNow  = Set-RowCount -Rows $templateRows -Count $students.Count

        for ($i = 0; $i -lt $students.Count; $i++) {
            $s  = $students[$i]
            $rc = @(Get-Cells $rowsNow[$i] $ns)

            [void](Set-CellText -Cell $rc[$cols.serial    - 1] -Ns $ns -Value "$($i + 1)")
            [void](Set-CellText -Cell $rc[$cols.firstName - 1] -Ns $ns -Value $s.firstName)
            [void](Set-CellText -Cell $rc[$cols.surname   - 1] -Ns $ns -Value $s.surname)
            [void](Set-CellText -Cell $rc[$cols.studentId - 1] -Ns $ns -Value $s.studentId)

            for ($t = 0; $t -lt $tools.Count; $t++) {
                $res = @($s.results | Where-Object { $_.toolId -eq $tools[$t].id })[0]
                [void](Set-CellText -Cell $rc[$cols.firstToolColumn - 1 + $t] -Ns $ns -Value $res.result)
            }

            $shift = $tools.Count - $cols.toolColumns    # columns after the tool block move right
            [void](Set-CellText -Cell $rc[$cols.overall         - 1 + $shift] -Ns $ns -Value $s.overall)
            [void](Set-CellText -Cell $rc[$cols.feedbackGiven   - 1 + $shift] -Ns $ns -Value $L.dates.feedbackGivenText)
            [void](Set-CellText -Cell $rc[$cols.resubmissionDue - 1 + $shift] -Ns $ns -Value $s.resubmissionDueText)
            [void](Set-CellText -Cell $rc[$cols.invoiceRaised   - 1 + $shift] -Ns $ns -Value $(if ($s.invoiceRaised) { "$BOX_T" } else { "$BOX_E" }))
            [void](Set-CellText -Cell $rc[$cols.comments        - 1 + $shift] -Ns $ns -Value $s.comment)
        }

        # ---- sign-off -------------------------------------------------------
        [void](Set-Placeholder -Node $tSign -Ns $ns -Name 'dd / mm / yyyy' -Value $L.dates.markingDateText  -Limit 1)
        [void](Set-Placeholder -Node $tSign -Ns $ns -Name 'dd / mm / yyyy' -Value $L.dates.resultsEnteredText -Limit 1)

        $dest = Join-Path $OutDir $L.amrrFile
        [void](Save-Docx -Package $pkg -Destination $dest)
        $dest
    } catch { Close-Docx $pkg; throw }
}

# ============================================================ FEEDBACK ======

function Build-Feedback {
    param($Student)

    $spec = $Rto.templates.feedback
    $pkg  = Open-Docx -Path (Get-TemplatePath 'feedback')
    try {
        $ns = $pkg.Ns
        $tDetails = Get-TableByKey $pkg $spec 'details'
        $tNext    = Get-TableByKey $pkg $spec 'next'

        if ($Rto.rtoRowIsPlaceholder) {
            [void](Set-Placeholder -Node $tDetails -Ns $ns -Name 'Insert RTO name and code' -Value $Rto.rto.identityLine)
        }
        Assert-Filled (Set-Placeholder -Node $tDetails -Ns $ns -Name 'Insert student name' -Value $Student.fullName) 'student name'
        Assert-Filled (Set-Placeholder -Node $tDetails -Ns $ns -Name 'Insert student ID'   -Value $Student.studentId) 'student ID'
        Assert-Filled (Set-Placeholder -Node $tDetails -Ns $ns -Name 'Insert unit code and title' -Value ("{0} {1}" -f $L.unit.code, $L.unit.title)) 'unit'
        Assert-Filled (Set-Placeholder -Node $tDetails -Ns $ns -Name 'Insert qualification code' -Value $L.qualification.code) 'qualification code'
        Assert-Filled (Set-Placeholder -Node $tDetails -Ns $ns -Name 'Insert trainer / assessor name' -Value $L.assessor) 'assessor'
        # The two date fields are distinct whole strings — '[ dd / mm / yyyy ]'
        # cannot match inside '[ dd / mm / yyyy or N/A ]' because of the closing
        # bracket — but they are filled longest-first anyway, so that a template
        # revision which drops a bracket cannot silently strand ' or N/A'.
        Assert-Filled (Set-Placeholder -Node $tDetails -Ns $ns -Name 'dd / mm / yyyy or N/A' -Value $Student.resubmissionDueText) 'resubmission due'
        Assert-Filled (Set-Placeholder -Node $tDetails -Ns $ns -Name 'dd / mm / yyyy' -Value $L.dates.markingDateText) 'date of marking'
        Assert-Filled (Set-Placeholder -Node $tDetails -Ns $ns -Name 'C / NYC' -Value $Student.overall) 'overall result'

        # ---- items ----------------------------------------------------------
        $it = $spec.itemTable
        $c  = $it.cells

        $items = @()
        foreach ($res in $Student.results) {
            foreach ($i in @($res.items)) {
                $items += [pscustomobject]@{
                    toolName   = $res.toolName
                    questionNo = $i.questionNo
                    issue      = $i.issue
                    action     = $i.action
                }
            }
        }

        $overflow = 0
        if ($items.Count -gt $it.maxItems) {
            $overflow = $items.Count - $it.maxItems
            $items = $items[0..($it.maxItems - 1)]
        }
        if ($items.Count -eq 0) {
            throw "$($Student.fullName) is NYC but has no feedback items. A feedback sheet with no items tells the student nothing."
        }

        # Which table holds the item rows is an RTO's layout decision, not ours.
        # MVC keeps them inside the details table; ACI gives them a table of
        # their own. 'details' stays the default so a map written before this
        # key existed still resolves to the same table it always did.
        $itemTableKey = if ($it.PSObject.Properties.Name.Contains('table') -and $it.table) { $it.table } else { 'details' }
        $tItems  = Get-TableByKey $pkg $spec $itemTableKey
        $allRows = @(Get-Rows $tItems $ns)
        $tplRows = @()
        for ($i = $it.firstItemRow - 1; $i -lt $allRows.Count; $i++) { $tplRows += $allRows[$i] }
        if ($tplRows.Count -eq 0) {
            throw "Feedback template: no item rows at or after row $($it.firstItemRow) of table '$itemTableKey', which has $($allRows.Count) row(s). Re-measure the template with Measure-Template.ps1 — itemTable.firstItemRow or itemTable.table is wrong for this RTO."
        }
        $rowsNow = Set-RowCount -Rows $tplRows -Count $items.Count

        for ($i = 0; $i -lt $items.Count; $i++) {
            $rc = @(Get-Cells $rowsNow[$i] $ns)
            [void](Set-CellText -Cell $rc[$c.serial     - 1] -Ns $ns -Value "$($i + 1)")
            [void](Set-CellText -Cell $rc[$c.toolName   - 1] -Ns $ns -Value $items[$i].toolName)
            [void](Set-CellText -Cell $rc[$c.questionNo - 1] -Ns $ns -Value $items[$i].questionNo)
            [void](Set-CellText -Cell $rc[$c.issue      - 1] -Ns $ns -Value $items[$i].issue)
            [void](Set-CellText -Cell $rc[$c.action     - 1] -Ns $ns -Value $items[$i].action)
        }

        # ---- what happens next ----------------------------------------------
        $note = $null
        if ($Student.PSObject.Properties.Name.Contains('furtherInstruction') -and $Student.furtherInstruction) {
            $note = $Student.furtherInstruction
        } elseif ($overflow -gt 0) {
            $note = "A further $overflow item(s) are marked in your returned assessment. Correct those as well."
        }
        if ($note) {
            [void](Set-Placeholder -Node $tNext -Ns $ns -Name 'Add any further instruction to the student, or delete this line' -Value $note)
        } else {
            # the field says delete the line, so the line goes
            foreach ($para in @($tNext.SelectNodes('.//w:p', $ns))) {
                if ((Get-RunText $para $ns) -like '*Add any further instruction to the student*') {
                    [void]$para.ParentNode.RemoveChild($para)
                }
            }
        }
        Assert-Filled (Set-Placeholder -Node $tNext -Ns $ns -Name 'Insert trainer / assessor name' -Value $L.assessor) 'foot assessor'
        Assert-Filled (Set-Placeholder -Node $tNext -Ns $ns -Name 'dd / mm / yyyy' -Value $L.dates.markingDateText) 'foot date'

        $dest = Join-Path $OutDir $Student.feedbackFile
        [void](Save-Docx -Package $pkg -Destination $dest)
        [pscustomobject]@{ Path = $dest; Overflow = $overflow; Items = $items.Count }
    } catch { Close-Docx $pkg; throw }
}

# =============================================================== run =========

Write-Output ''
Write-Output ("Building marking records for {0} {1} — {2} student(s), {3} tool(s)." -f $L.unit.code, $L.unit.title, @($L.students).Count, @($L.tools).Count)
Write-Output ("RTO: {0}  ·  marking date {1}" -f $Rto.rto.tradingName, $L.dates.markingDateText)
Write-Output ''

foreach ($s in @($L.students)) {
    $file = Build-Sar -Student $s
    $built += $file
    Write-Output ("  SAR       {0,-46} {1}" -f (Split-Path -Leaf $file), $s.overall)
}

$amrr = Build-Amrr
$built += $amrr
Write-Output ("  RECORD    {0}" -f (Split-Path -Leaf $amrr))

foreach ($s in @($L.students | Where-Object { $_.needsFeedbackSheet })) {
    $r = Build-Feedback -Student $s
    $built += $r.Path
    $note = if ($r.Overflow -gt 0) { "  ($($r.Items) listed, $($r.Overflow) carried to a closing note)" } else { "  ($($r.Items) item(s))" }
    Write-Output ("  FEEDBACK  {0,-46}{1}" -f (Split-Path -Leaf $r.Path), $note)
}
# ---- marked copies of the students' own submissions ------------------------
# Built last, because they depend on files outside this skill. A submission
# that cannot be found stops the marked copy and says so; it never stops the
# official records, which stand on the ledger alone.
if (-not $NoMarkedCopies) {
    $mArgs = @{ Ledger = $Ledger; OutDir = $OutDir; RtoProfile = $RtoProfile }
    if ($SubmissionRoot) { $mArgs['SubmissionRoot'] = $SubmissionRoot }
    $marked = & (Join-Path $PSScriptRoot 'Build-MarkedAssessment.ps1') @mArgs
    # Capturing the call captures its REPORT as well as its objects. Print the
    # report, or the assessor never sees which submissions were skipped and
    # never sees the CHECK warning about a last outcome with no end anchor —
    # and a misplaced last outcome looks exactly like a correct one.
    foreach ($m in @($marked | Where-Object { $_ -is    [string] })) { Write-Output $m }
    foreach ($m in @($marked | Where-Object { $_ -isnot [string] })) { $built += $m.path }
}


Write-Output ''
Write-Output ("{0} document(s) written to {1}" -f $built.Count, (Resolve-Path -LiteralPath $OutDir).Path)
Write-Output 'Nothing is delivered until Test-MarkingRecords.ps1 passes on this folder.'
Write-Output ''
$built
