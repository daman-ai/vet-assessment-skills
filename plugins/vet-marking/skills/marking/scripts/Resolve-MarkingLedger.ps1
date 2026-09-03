<#
  Resolve-MarkingLedger.ps1 — validate a marking ledger and derive everything
  that follows from it.

  The ledger is the single source of truth for a marking run. Every value that
  appears on a SAR, on the marking record and on a feedback sheet comes from
  here, and the gate checks the finished documents back against this same file.
  Nothing is computed twice: a result, a date or a tool name that lives in one
  place cannot go out of step with itself across thirty documents.

  What this script DERIVES (and therefore what you must not hand-write):
    overall result, resubmission due date, date of assessment, feedback-given
    date, the per-tool feedback option, invoice-raised, re-enrol, and every
    output filename.

  What it VALIDATES:
    every student has a judgement for every tool; a non-submission carries the
    exact comment 'No submission'; an AI-flagged response forces its tool to
    NYS; every NYS tool has at least one feedback item; student IDs are unique;
    tool names are non-empty and distinct.

  Usage:
    .\Resolve-MarkingLedger.ps1 -Path ledger.json [-Out resolved.json]
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Path,
    [string]$Out,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-Dates.ps1')
. (Join-Path $PSScriptRoot 'Lib-Text.ps1')

$problems = New-Object System.Collections.ArrayList
function Fail { param([string]$m) [void]$problems.Add($m) }

# Things worth an assessor's eye that are not grounds to refuse the build.
# They are printed after a successful resolve, never swallowed.
$checks = @()

if (-not (Test-Path -LiteralPath $Path)) { throw "Ledger not found: $Path" }
$L = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json

# ------------------------------------------------------------- required ------

foreach ($f in @('rto','unit','qualification','assessor','markingDate','tools','students')) {
    if (-not $L.PSObject.Properties.Name.Contains($f)) { Fail "Ledger is missing required field '$f'." }
}
if ($problems.Count) { $problems | ForEach-Object { Write-Error $_ -ErrorAction Continue }; throw "Ledger is incomplete. Ask for the missing inputs; do not guess them." }

foreach ($f in @('code','title')) {
    if (-not $L.unit.$f)          { Fail "unit.$f is empty." }
    if (-not $L.qualification.$f) { Fail "qualification.$f is empty." }
}
if (-not $L.assessor) { Fail 'assessor is empty.' }
foreach ($f in @('location','environment')) {
    if (-not $L.PSObject.Properties.Name.Contains($f) -or -not $L.$f) {
        Fail "$f is empty. The SAR prints it; there is no defensible default."
    }
}
if (-not $L.unit.PSObject.Properties.Name.Contains('prerequisite') -or -not $L.unit.prerequisite) {
    Fail "unit.prerequisite is empty. Use 'N/A' where the unit has none — blank is not the same statement."
}
if (-not $L.unit.PSObject.Properties.Name.Contains('coreElective') -or $L.unit.coreElective -notin @('Core','Elective')) {
    Fail "unit.coreElective must be exactly 'Core' or 'Elective' (per the qualification packaging rules)."
}

# ---------------------------------------------------------------- dates ------

[datetime]$marking = [datetime]::ParseExact($L.markingDate, 'yyyy-MM-dd', $null)
$resultsEntered = if ($L.PSObject.Properties.Name.Contains('resultsEnteredDate') -and $L.resultsEnteredDate) {
    [datetime]::ParseExact($L.resultsEnteredDate, 'yyyy-MM-dd', $null)
} else { $marking }

[void](Import-PublicHolidays)
$dates = Get-MarkingDates -MarkingDate $marking -ResultsEnteredDate $resultsEntered

# ---------------------------------------------------------------- tools ------

$tools = @($L.tools)
if ($tools.Count -lt 1) { Fail 'At least one assessment tool is required.' }
$seenTool = @{}
foreach ($t in $tools) {
    if (-not $t.id)   { Fail 'A tool has no id.' }
    if (-not $t.name) { Fail "Tool '$($t.id)' has no name. Use the tool's actual name as it appears on the assessment." }
    if ($seenTool.ContainsKey($t.id)) { Fail "Duplicate tool id '$($t.id)'." }
    $seenTool[$t.id] = $t.name
}

# ------------------------------------------------------------- students ------

$seenId = @{}
$resolvedStudents = @()
$serial = 0

foreach ($s in @($L.students)) {
    $serial++
    $who = "$($s.firstName) $($s.surname) [$($s.studentId)]"

    foreach ($f in @('firstName','surname','studentId')) {
        if (-not $s.$f) { Fail "Student #$serial has no $f." }
    }
    if ($s.studentId) {
        if ($seenId.ContainsKey($s.studentId)) { Fail "Duplicate student ID '$($s.studentId)'." }
        $seenId[$s.studentId] = $true
    }

    $attempt = if ($s.PSObject.Properties.Name.Contains('attempt') -and $s.attempt) { [int]$s.attempt } else { 1 }
    if ($attempt -lt 1) { Fail "$who has attempt $attempt; attempts start at 1." }

    # --- per-tool judgements ------------------------------------------------
    $byTool = @{}
    foreach ($r in @($s.results)) { if ($r.toolId) { $byTool[$r.toolId] = $r } }

    $resolvedResults = @()
    $anyNys = $false

    foreach ($t in $tools) {
        if (-not $byTool.ContainsKey($t.id)) {
            Fail "$who has no judgement for tool '$($t.name)'. Every student is judged on every tool — a missing judgement is not a pass."
            continue
        }
        $r = $byTool[$t.id]

        $submitted = -not ($r.PSObject.Properties.Name.Contains('submitted') -and $r.submitted -eq $false)
        $aiFlagged = @()
        if ($r.PSObject.Properties.Name.Contains('aiFlagged') -and $r.aiFlagged) { $aiFlagged = @($r.aiFlagged) }

        $result = $r.result
        if ($result -notin @('S','NYS')) { Fail "$who / '$($t.name)': result must be S or NYS, got '$result'." }

        if (-not $submitted -and $result -ne 'NYS') {
            Fail "$who / '$($t.name)': nothing was submitted, so the result must be NYS."
        }
        if ($aiFlagged.Count -gt 0 -and $result -ne 'NYS') {
            Fail "$who / '$($t.name)': a response is flagged as not the student's own work, so the tool must be NYS."
        }

        $items = @()
        if ($r.PSObject.Properties.Name.Contains('items') -and $r.items) { $items = @($r.items) }

        # A non-submission is NYS, so the student gets a feedback sheet — and a
        # sheet with no rows tells them nothing. There is no question to fix
        # here, so the item is synthesised rather than asked for: the whole tool
        # is outstanding, and the action is to submit it by the due date.
        if (-not $submitted -and $items.Count -eq 0) {
            $items = @([pscustomobject]@{
                questionNo = 'Whole assessment'
                issue      = "No assessment was submitted for this tool, so it could not be assessed."
                action     = "Complete and submit your $($t.name) by $($dates.ResubmissionDueText)."
            })
        }

        if ($result -eq 'NYS' -and $submitted -and $items.Count -eq 0) {
            Fail "$who / '$($t.name)': NYS with no feedback items. A student sent to resubmission must be told which questions or tasks to fix."
        }
        foreach ($it in $items) {
            foreach ($f in @('questionNo','issue','action')) {
                if (-not $it.$f) { Fail "$who / '$($t.name)': a feedback item has no $f." }
            }
            foreach ($f in @('issue','action')) {
                foreach ($h in @(Test-FeedbackStyle -Text "$($it.$f)" -Where "$who / '$($t.name)' / item $($it.questionNo) / $f")) {
                    Fail ("{0}: {1} commas in one sentence, limit is {2}. {3} — `"{4}`"" -f $h.where, $h.commas, (Get-FeedbackMaxCommas), $h.fix, $h.sentence)
                }
            }
        }

        if (-not $r.feedback) {
            Fail "$who / '$($t.name)': no feedback written. Every tool row on the SAR carries feedback."
        }
        foreach ($h in @(Test-FeedbackStyle -Text "$($r.feedback)" -Where "$who / '$($t.name)' feedback")) {
            Fail ("{0}: {1} commas in one sentence, limit is {2}. {3} — `"{4}`"" -f $h.where, $h.commas, (Get-FeedbackMaxCommas), $h.fix, $h.sentence)
        }

        # --- per-question outcomes, for the marked copy of the submission ----
        # These drive the green/red line under each answer. They must agree with
        # the tool-level result: a marked copy showing five green Satisfactory
        # lines above a SAR row reading NYS is two records of the same judgement
        # disagreeing, handed to the student and the auditor at once.
        $questions = @()
        if ($r.PSObject.Properties.Name.Contains('questions') -and $r.questions) { $questions = @($r.questions) }
        if ($questions.Count -gt 0) {
            $seenRef = @{}
            foreach ($q in $questions) {
                if (-not $q.ref) { Fail "$who / '$($t.name)': a question outcome has no ref." }
                if ($q.outcome -notin @('S','NYS')) { Fail "$who / '$($t.name)' / question '$($q.ref)': outcome must be S or NYS, got '$($q.outcome)'." }
                if ($q.ref -and $seenRef.ContainsKey($q.ref)) { Fail "$who / '$($t.name)': duplicate question ref '$($q.ref)'." }
                if ($q.ref) { $seenRef[$q.ref] = $true }
            }
            $qNys = @($questions | Where-Object { $_.outcome -eq 'NYS' })
            if ($qNys.Count -gt 0 -and $result -ne 'NYS') {
                Fail "$who / '$($t.name)': $($qNys.Count) question(s) marked NYS but the tool is $result. The marked copy and the SAR would disagree."
            }
            if ($qNys.Count -eq 0 -and $result -eq 'NYS' -and $submitted) {
                Fail "$who / '$($t.name)': the tool is NYS but every question is marked S. Say which question was not satisfactory."
            }
            # every NYS question should have a matching feedback item, or the
            # marked copy sends the student to a sheet that does not mention it
            foreach ($q in $qNys) {
                if (-not (@($items | Where-Object { "$($_.questionNo)" -eq "$($q.ref)" }).Count)) {
                    Fail "$who / '$($t.name)': question '$($q.ref)' is NYS on the marked copy but has no item on the feedback sheet. The red line tells the student to refer to a sheet that does not mention it."
                }
            }
        }

        # --- the assessor's observation record -------------------------------
        # An observation tool does not decompose into numbered questions, so the
        # evidence that it was actually conducted is the assessor's own brief
        # point-form notes. A tool declared 'isObservation' must carry them for
        # every student who was observed — an observation with no record is an
        # assertion that something happened, with nothing behind it.
        $observations = @()
        if ($r.PSObject.Properties.Name.Contains('observations') -and $r.observations) {
            $observations = @($r.observations | Where-Object { "$_".Trim() -ne '' } | ForEach-Object { "$_".Trim() })
        }
        $isObservationTool = ($t.PSObject.Properties.Name.Contains('isObservation') -and $t.isObservation)

        if ($isObservationTool -and $submitted -and $observations.Count -eq 0) {
            Fail "$who / '$($t.name)': this is an observation tool, so it needs a brief point-form observation record. Add 'observations' to this result — one short point per thing you observed."
        }
        if ($observations.Count -gt 0 -and -not $submitted) {
            Fail "$who / '$($t.name)': nothing was submitted or observed, so there can be no observation record. Remove 'observations'."
        }
        foreach ($point in $observations) {
            foreach ($h in @(Test-FeedbackStyle -Text "$point" -Where "$who / '$($t.name)' / observation point")) {
                Fail ("{0}: {1} commas in one sentence, limit is {2}. {3} — `"{4}`"" -f $h.where, $h.commas, (Get-FeedbackMaxCommas), $h.fix, $h.sentence)
            }
        }

        # --- where the observation record is written --------------------------
        # The observation sheet is part of the assessment the student submitted:
        # a checklist of observable tasks, its Yes/No boxes, its notes column,
        # its feedback line and the assessor's signature. THAT is the document
        # an auditor opens to see whether the observation happened, so that is
        # where the record belongs — not on a block bolted to the front of the
        # file, leaving the sheet itself blank underneath it.
        #
        # So an observation tool must say where its sheet is. A submission that
        # genuinely carries no sheet is a real case, and it is declared rather
        # than inferred from a missing field: 'inSubmission': false.
        $sheet = $null
        if ($r.PSObject.Properties.Name.Contains('observationSheet') -and $r.observationSheet) {
            $sheet = $r.observationSheet
        }
        $sheetInSubmission = $true
        if ($sheet -and $sheet.PSObject.Properties.Name.Contains('inSubmission') -and $sheet.inSubmission -eq $false) {
            $sheetInSubmission = $false
        }
        $evidenceIsDocx = ("$($r.evidence)").ToLower().EndsWith('.docx')

        if ($observations.Count -gt 0 -and $evidenceIsDocx) {
            if (-not $sheet) {
                Fail "$who / '$($t.name)': this tool carries an observation record but no 'observationSheet', so the record would be bolted to the front of the file and the observation sheet inside it left blank. Give the sheet's 'anchor' and 'notesAnchor'; where the submission truly has no sheet, say so with `"observationSheet`": { `"inSubmission`": false }."
            } elseif ($sheetInSubmission) {
                if (-not $sheet.anchor)      { Fail "$who / '$($t.name)': observationSheet.anchor is empty. Name the text that identifies the observation sheet in the submission." }
                if (-not $sheet.notesAnchor) { Fail "$who / '$($t.name)': observationSheet.notesAnchor is empty. Name the paragraph the observation record is written under." }
                foreach ($o in @($sheet.outcomes)) {
                    if ("$o" -notin @('Yes','No')) { Fail "$who / '$($t.name)': observationSheet.outcomes must each be 'Yes' or 'No', got '$o'." }
                }
                foreach ($fld in @($sheet.fields)) {
                    if (-not $fld.label) { Fail "$who / '$($t.name)': an observationSheet field has no label." }
                    if (-not $fld.PSObject.Properties.Name.Contains('value') -or "$($fld.value)".Trim() -eq '') {
                        Fail "$who / '$($t.name)': observationSheet field '$($fld.label)' has no value. A field left blank on a signed observation sheet reads as nobody filled it in."
                    }
                }
                if ($sheet.PSObject.Properties.Name.Contains('feedback') -and $sheet.feedback) {
                    if (-not $sheet.feedbackAnchor) { Fail "$who / '$($t.name)': observationSheet.feedback was written but there is no feedbackAnchor saying where it goes." }
                    foreach ($h in @(Test-FeedbackStyle -Text "$($sheet.feedback)" -Where "$who / '$($t.name)' / observation sheet feedback")) {
                        Fail ("{0}: {1} commas in one sentence, limit is {2}. {3} — `"{4}`"" -f $h.where, $h.commas, (Get-FeedbackMaxCommas), $h.fix, $h.sentence)
                    }
                }
                if ($sheet.PSObject.Properties.Name.Contains('sufficient') -and $null -ne $sheet.sufficient -and -not $sheet.sufficientAnchor) {
                    Fail "$who / '$($t.name)': observationSheet.sufficient was set but there is no sufficientAnchor saying which box to tick."
                }
            } else {
                $checks += "$who / '$($t.name)': the observation record goes on the declaration page, because the ledger states this submission carries no observation sheet."
            }
        }
        if ($sheet -and $observations.Count -eq 0) {
            Fail "$who / '$($t.name)': an observationSheet is named but there is no observation record to write into it. Add 'observations', or remove the sheet."
        }

        # Every submitted tool should be marked in a way the student can see on
        # their returned copy: a remark under each question, or an observation
        # record. Neither is a CHECK rather than a failure, because a tool can
        # legitimately be judged on evidence that is not a Word document.
        if ($submitted -and $questions.Count -eq 0 -and $observations.Count -eq 0) {
            $checks += "$who / '$($t.name)': submitted but carries neither per-question outcomes nor an observation record, so the student's returned copy will show no remarks for this tool."
        }

        # the feedback option is DERIVED, never stated
        $option = if (-not $submitted) { 'notSubmitted' } elseif ($result -eq 'S') { 'completed' } else { 'corrections' }
        if ($result -eq 'NYS') { $anyNys = $true }

        $resolvedResults += [pscustomobject]@{
            toolId         = $t.id
            toolName       = $t.name
            result         = $result
            submitted      = $submitted
            feedbackOption = $option
            feedback       = $r.feedback
            aiFlagged      = $aiFlagged
            evidence       = $(if ($r.PSObject.Properties.Name.Contains('evidence')) { $r.evidence } else { $null })
            questions      = $questions
            observations   = $observations
            isObservation  = [bool]$isObservationTool
            observationSheet = $(if ($sheetInSubmission) { $sheet } else { $null })
            questionsEndAnchor = $(if ($r.PSObject.Properties.Name.Contains('questionsEndAnchor')) { $r.questionsEndAnchor } else { $null })
            items          = $items
        }
    }

    $overall = if ($anyNys) { 'NYC' } else { 'C' }

    # --- comment ------------------------------------------------------------
    $noSubmissionAll = ($resolvedResults.Count -gt 0) -and (@($resolvedResults | Where-Object { -not $_.submitted }).Count -eq $resolvedResults.Count)
    $comment = $s.comment
    if ($noSubmissionAll) {
        if ($comment -and $comment -ne 'No submission') {
            Fail "$who submitted nothing, so the marking record comment must be exactly 'No submission' (found '$comment')."
        }
        $comment = 'No submission'
    }
    if (-not $comment) { Fail "$who has no marking record comment." }
    foreach ($h in @(Test-FeedbackStyle -Text "$comment" -Where "$who / marking record comment")) {
        Fail ("{0}: {1} commas in one sentence, limit is {2}. {3} — `"{4}`"" -f $h.where, $h.commas, (Get-FeedbackMaxCommas), $h.fix, $h.sentence)
    }
    if ($comment -and $comment.Length -gt 120) {
        Fail "$who comment is $($comment.Length) characters. The Comments column takes a short phrase, not a paragraph — the SAR carries the full feedback."
    }

    # --- resit, invoice, re-enrol ------------------------------------------
    $invoice = ($overall -eq 'NYC' -and $attempt -ge 2)
    $reEnrol = ($overall -eq 'NYC' -and $attempt -ge 2)
    if ($s.PSObject.Properties.Name.Contains('invoiceRaised') -and $null -ne $s.invoiceRaised -and [bool]$s.invoiceRaised -ne $invoice) {
        Fail "${who}: invoiceRaised is derived (NYC after the second attempt), not stated. Remove it from the ledger or correct 'attempt'."
    }

    $resit = $null
    if ($s.PSObject.Properties.Name.Contains('resit') -and $s.resit) {
        $resit = [pscustomobject]@{
            result   = $s.resit.result
            option   = $(if ($s.resit.result -eq 'S') { 'completed' } else { 'corrections' })
            feedback = $s.resit.feedback
        }
        if ($resit.result -notin @('S','NYS')) { Fail "${who}: resit.result must be S or NYS." }
        if (-not $resit.feedback)              { Fail "${who}: a recorded resit needs feedback." }
        foreach ($h in @(Test-FeedbackStyle -Text "$($resit.feedback)" -Where "${who} / resit feedback")) {
            Fail ("{0}: {1} commas in one sentence, limit is {2}. {3} — `"{4}`"" -f $h.where, $h.commas, (Get-FeedbackMaxCommas), $h.fix, $h.sentence)
        }
    }

    $resubText = if ($overall -eq 'NYC') { $dates.ResubmissionDueText } else { 'N/A' }

    $unitCode = $L.unit.code
    $resolvedStudents += [pscustomobject]@{
        serial              = $serial
        firstName           = $s.firstName
        surname             = $s.surname
        fullName            = "$($s.firstName) $($s.surname)"
        studentId           = $s.studentId
        attempt             = $attempt
        results             = $resolvedResults
        overall             = $overall
        comment             = $comment
        invoiceRaised       = $invoice
        reEnrol             = $reEnrol
        resit               = $resit
        resubmissionDueText = $resubText
        needsFeedbackSheet  = ($overall -eq 'NYC')
        feedbackItemCount   = (@($resolvedResults | ForEach-Object { $_.items }) | Measure-Object).Count
        sarFile             = "SAR_$($s.studentId)_${unitCode}_$overall.docx"
        feedbackFile        = "FEEDBACK_$($s.studentId)_${unitCode}_$($marking.ToString('ddMMyyyy')).docx"
    }
}

if (@($L.students).Count -eq 0) { Fail 'No students in the ledger.' }

# ------------------------------------------------------- the marked copies ---
#
# ONE MARKED COPY PER SUBMITTED FILE, not per tool.
#
# Assessments are routinely supplied as one document covering several tools —
# UAT 1 and UAT 2 bound together, a knowledge tool and a practical workbook in
# one workbook. Marking those tool by tool produces two marked copies of the
# same file, each carrying half the outcomes and a front page naming only its
# own half. The student then receives the same document twice, marked twice,
# and neither copy is the marked assessment.
#
# So results are grouped by the file they were read from. Each group becomes one
# marked copy, carrying every tool's outcomes, every tool's observation record,
# and a declaration page naming all of them. The grouping is derived here so the
# builder and the gate cannot disagree about which files exist or what is in
# them.

$markedCopies = @()
foreach ($rs in $resolvedStudents) {
    $groups = [ordered]@{}
    foreach ($res in @($rs.results)) {
        if (-not $res.submitted) { continue }
        $hasQ = (@($res.questions).Count -gt 0)
        $hasO = (@($res.observations).Count -gt 0)
        if (-not $hasQ -and -not $hasO) { continue }

        if (-not $res.evidence) {
            $checks += "$($rs.fullName) [$($rs.studentId)] / '$($res.toolName)': outcomes were recorded but no evidence file is named, so there is no document to return marked. Add 'evidence', or accept that this tool has no marked copy."
            continue
        }

        # One file, one key. Windows paths are case-insensitive and mix
        # separators, so 'ev/Foo.docx' and 'ev\foo.docx' are the same file and
        # must not become two marked copies of it.
        $key = ("$($res.evidence)").Trim().Replace('\', '/').ToLowerInvariant()
        if (-not $groups.Contains($key)) {
            $groups[$key] = [pscustomobject]@{ evidence = $res.evidence; results = @() }
        }
        $groups[$key].results += $res
    }

    foreach ($key in $groups.Keys) {
        $g       = $groups[$key]
        $toolIds = @($g.results | ForEach-Object { $_.toolId })
        $markedCopies += [pscustomobject]@{
            file      = "MARKED_{0}_{1}_{2}_{3}.docx" -f $rs.studentId, $L.unit.code, ($toolIds -join '-'), $marking.ToString('ddMMyyyy')
            studentId = $rs.studentId
            student   = $rs.fullName
            evidence  = $g.evidence
            toolIds   = $toolIds
            toolNames = @($g.results | ForEach-Object { $_.toolName })
        }
    }
}

# ------------------------------------------------------------------ out ------

if ($problems.Count) {
    Write-Output ''
    Write-Output "LEDGER REJECTED — $($problems.Count) problem(s):"
    $i = 0
    foreach ($p in $problems) { $i++; Write-Output ("  {0,2}. {1}" -f $i, $p) }
    Write-Output ''
    throw 'Ledger did not resolve. Fix the problems above; nothing has been built.'
}

$unitCode = $L.unit.code
$resolved = [pscustomobject]@{
    rto           = $L.rto
    unit          = $L.unit
    qualification = $L.qualification
    assessor      = $L.assessor
    location      = $L.location
    environment   = $L.environment
    tools         = @($tools | ForEach-Object { [pscustomobject]@{
                        id            = $_.id
                        name          = $_.name
                        isObservation = [bool]($_.PSObject.Properties.Name.Contains('isObservation') -and $_.isObservation)
                    } })
    dates         = [pscustomobject]@{
        markingDate          = $marking.ToString('yyyy-MM-dd')
        markingDateText      = $dates.MarkingDateText
        markingDateCompact   = $marking.ToString('ddMMyyyy')
        assessmentDateText   = $dates.AssessmentDateText
        assessmentRolledBack = $dates.AssessmentRolledBack
        assessmentRollReason = $dates.AssessmentRollReason
        feedbackGivenText    = $dates.FeedbackGivenText
        resubmissionDueText  = $dates.ResubmissionDueText
        resultsEnteredText   = $dates.ResultsEnteredText
    }
    students      = $resolvedStudents
    markedCopies  = $markedCopies
    amrrFile      = "AMLC_$($unitCode.ToUpper())_$($marking.ToString('ddMMyyyy')).docx"
    summary       = [pscustomobject]@{
        students       = $resolvedStudents.Count
        competent      = @($resolvedStudents | Where-Object { $_.overall -eq 'C' }).Count
        notYetCompetent= @($resolvedStudents | Where-Object { $_.overall -eq 'NYC' }).Count
        feedbackSheets = @($resolvedStudents | Where-Object { $_.needsFeedbackSheet }).Count
        markedCopies   = @($markedCopies).Count
        tools          = $tools.Count
    }
}

if ($Out) {
    $resolved | ConvertTo-Json -Depth 12 | Out-File -Encoding utf8 -LiteralPath $Out
    if (-not $Quiet) { Write-Output "Resolved ledger written: $Out" }
}

if (-not $Quiet) {
    Write-Output ''
    Write-Output "LEDGER RESOLVED"
    Write-Output ("  Unit            {0} {1}" -f $L.unit.code, $L.unit.title)
    Write-Output ("  Tools           {0}: {1}" -f $tools.Count, (($tools | ForEach-Object { $_.name }) -join ' | '))
    Write-Output ("  Marking date    {0}" -f $dates.MarkingDateText)
    Write-Output ("  Assessment date {0}{1}" -f $dates.AssessmentDateText, $(if ($dates.AssessmentRolledBack) { "  (rolled back: $($dates.AssessmentRollReason))" } else { '' }))
    Write-Output ("  Resubmission    {0}" -f $dates.ResubmissionDueText)
    Write-Output ("  Students        {0}  —  {1} C, {2} NYC" -f $resolved.summary.students, $resolved.summary.competent, $resolved.summary.notYetCompetent)
    Write-Output ("  Documents       {0} SAR + 1 marking record + {1} feedback sheet(s) + {2} marked copy/copies = {3}" -f $resolved.summary.students, $resolved.summary.feedbackSheets, $resolved.summary.markedCopies, ($resolved.summary.students + 1 + $resolved.summary.feedbackSheets + $resolved.summary.markedCopies))
    foreach ($mc in @($markedCopies | Where-Object { @($_.toolIds).Count -gt 1 })) {
        Write-Output ("  One file        {0}: {1} are in one document, so they are marked together" -f $mc.student, (($mc.toolNames) -join ' + '))
    }
    if ($checks.Count) {
        Write-Output ''
        foreach ($c in $checks) { Write-Output ("  CHECK  {0}" -f $c) }
    }
    Write-Output ''
}

$resolved
