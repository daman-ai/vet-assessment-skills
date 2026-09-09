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
    # The roll, as written by Import-WisenetMatrix.ps1 -Json. Supply it and the
    # ledger is reconciled against it: a student the matrix says must submit,
    # and who has no ledger entry, is a hard failure. Without it that student is
    # invisible — every check downstream compares the ledger to the documents,
    # and someone missing from both looks exactly like a clean run.
    [string]$Roll,
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

function Get-NameSegment {
    <#
      The <Student Name> segment of an output filename. Spaces are KEPT — the
      convention is four fields separated by underscores and the name is one of
      them, so the name itself must never contain an underscore or the fields
      stop being parseable. Any underscore, and any character illegal in a
      filename, becomes a space, and the substitution is reported rather than
      made quietly.
    #>
    param([string]$Name)
    $clean = (("$Name" -replace '[_\\/:*?"<>|]', ' ') -replace '\s+', ' ').Trim()
    if ($clean -ne "$Name".Trim()) {
        $script:checks += "Filename: '$Name' carries a character that cannot go in a filename, so its name segment reads '$clean'. The record itself still carries the name in full."
    }
    $clean
}

if (-not (Test-Path -LiteralPath $Path)) { throw "Ledger not found: $Path" }
$L = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json

# ------------------------------------------------------------------ roll -----
#
# THE ONE THING NOTHING ELSE CHECKS. Every other check in this skill compares
# the ledger to the documents built from it, so a student left out of the ledger
# is absent from both and the whole run looks clean. The matrix is the record of
# who must submit; this is where the two are put side by side.
$rollData = $null
$rollRequired = @()
if ($Roll) {
    if (-not (Test-Path -LiteralPath $Roll)) { throw "Roll not found: $Roll" }
    $rollData = Get-Content -Raw -Encoding UTF8 -LiteralPath $Roll | ConvertFrom-Json
    $rollRequired = @($rollData.required)
    if ($rollData.unit -and $L.unit.code -and "$($rollData.unit)".ToUpper() -ne "$($L.unit.code)".ToUpper()) {
        Fail "The roll is for unit '$($rollData.unit)' but the ledger is for '$($L.unit.code)'. This is the wrong roll for this marking run."
    }
}

# The matrix is the record of who holds a prerequisite, so where the importer
# read one it is used directly rather than hand-copied into the ledger. The
# ledger still overrides — that is where an assessor's confirmedExternally,
# with the evidence they saw, is recorded.
$rollPrereq = @{}
foreach ($e in @($rollData.prerequisiteStatus)) {
    if (-not $e.studentId) { continue }
    if (-not $rollPrereq.ContainsKey($e.studentId)) { $rollPrereq[$e.studentId] = @{} }
    $rollPrereq[$e.studentId][$e.prerequisite] = $e.status
}

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
# --------------------------------------------------------- prerequisites -----
#
# The old field was a free-text string that accepted 'N/A', which made "nobody
# checked" and "the register says Nil" the same value. The replacement cannot
# express unknown by accident: an empty list is a hard failure unless the ledger
# also carries an explicit prerequisitesConfirmedNone.
#
# Look the unit up with scripts/Get-UnitPrerequisites.ps1 — and read
# references/prerequisite-lookup.md before assuming a plain page fetch will do.

$unitPrereqs = @()
$prereqTextParts = @()
$legacyPrereq = ($L.unit.PSObject.Properties.Name.Contains('prerequisite') -and $L.unit.prerequisite)
$hasNewPrereq = $L.unit.PSObject.Properties.Name.Contains('prerequisites')

if (-not $hasNewPrereq -and $legacyPrereq) {
    # One release of grace. The old field still fills the template, but the run
    # says so every time so the ledger gets migrated rather than forgotten.
    $checks += "unit.prerequisite is the retired free-text field and will be rejected in the next release. Replace it with 'prerequisites' plus 'prerequisitesConfirmedNone', looked up with Get-UnitPrerequisites.ps1. 'N/A' cannot tell 'the register says Nil' apart from 'nobody checked'."
    if ("$($L.unit.prerequisite)".Trim() -ne 'N/A') {
        $prereqTextParts += "$($L.unit.prerequisite)".Trim()
    }
}
elseif ($hasNewPrereq) {
    foreach ($p in @($L.unit.prerequisites)) {
        if (-not $p.code)  { Fail 'A unit.prerequisites entry has no code.' ; continue }
        if (-not $p.title) { Fail "unit.prerequisites entry '$($p.code)' has no title." }
        $unitPrereqs += [pscustomobject]@{ code = "$($p.code)"; title = "$($p.title)" }
        $prereqTextParts += ("{0} {1}" -f $p.code, $p.title)
    }
    $confirmedNone = ($L.unit.PSObject.Properties.Name.Contains('prerequisitesConfirmedNone') -and [bool]$L.unit.prerequisitesConfirmedNone)
    if ($unitPrereqs.Count -eq 0 -and -not $confirmedNone) {
        Fail ("unit.prerequisites is empty and prerequisitesConfirmedNone is not set. Confirm on training.gov.au whether {0} has a prerequisite. A blank array is not a statement that there is none." -f $L.unit.code)
    }
    if ($unitPrereqs.Count -gt 0 -and $confirmedNone) {
        Fail 'unit.prerequisitesConfirmedNone is set but prerequisites are listed. One of the two is wrong.'
    }
    if (-not $L.unit.PSObject.Properties.Name.Contains('prerequisiteSource') -or -not $L.unit.prerequisiteSource) {
        Fail "unit.prerequisiteSource is empty. Record where the answer came from, e.g. 'training.gov.au'."
    }
    if (-not $L.unit.PSObject.Properties.Name.Contains('prerequisiteCheckedOn') -or -not $L.unit.prerequisiteCheckedOn) {
        Fail 'unit.prerequisiteCheckedOn is empty. Record the date the register was read.'
    }
}
else {
    Fail ("unit.prerequisites is missing. Look {0} up with Get-UnitPrerequisites.ps1 and record the answer. Where the register says Nil, write an empty array with prerequisitesConfirmedNone: true." -f $L.unit.code)
}

# The single string the SAR and the marking record print. Derived here, once.
$prereqText = if ($prereqTextParts.Count -gt 0) { $prereqTextParts -join '; ' } else { 'N/A' }
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

# AN EXTENSION THE ASSESSOR GRANTED. Resubmission due is five business days from
# the marking date, and that is the rule. It is not the rule when the assessor
# has given the class longer â€” a run marked in one sitting and handed back with
# a fortnight to resubmit. That is an INPUT, not a derived value, so it is stated
# here rather than computed, and it is reported so nobody reads the longer date
# as the five-day rule having been miscounted.
if ($L.PSObject.Properties.Name.Contains('resubmissionDueDate') -and $L.resubmissionDueDate) {
    [datetime]$resubGiven = [datetime]::ParseExact("$($L.resubmissionDueDate)", 'yyyy-MM-dd', $null)
    if ($resubGiven.Date -lt $marking.Date) {
        Fail "resubmissionDueDate $($L.resubmissionDueDate) is before the marking date. A student cannot resubmit before the work was marked."
    } else {
        $derived = $dates.ResubmissionDueText
        $dates.ResubmissionDue     = $resubGiven
        $dates.ResubmissionDueText = Format-RecordDate $resubGiven
        $checks += "Resubmission due is $($dates.ResubmissionDueText), an extension stated in the ledger. The five-business-day rule alone would give $derived."
    }
}

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

        # THE WRONG ASSESSMENT. A student who hands in work for another unit, or
        # another unit's assessment tool, HAS submitted something — so this is
        # not a non-submission and must not read as one. It is assessed, found
        # not to address this unit, and resulted NYS with feedback that says
        # what arrived and what to send instead. The alternative, filing it as
        # 'No submission', tells the student nothing about the file they know
        # they submitted.
        $wrongAssessment = ($r.PSObject.Properties.Name.Contains('wrongAssessment') -and $r.wrongAssessment -eq $true)
        if ($wrongAssessment -and -not $submitted) {
            Fail "$who / '$($t.name)': wrongAssessment is set but 'submitted' is false. Something was submitted; it was the wrong thing."
        }
        if ($wrongAssessment -and -not ($r.PSObject.Properties.Name.Contains('submittedInstead') -and "$($r.submittedInstead)".Trim())) {
            Fail "$who / '$($t.name)': wrongAssessment is set but 'submittedInstead' does not say what was received. Name the assessment that arrived."
        }

        $result = $r.result
        if ($result -notin @('S','NYS')) { Fail "$who / '$($t.name)': result must be S or NYS, got '$result'." }

        if (-not $submitted -and $result -ne 'NYS') {
            Fail "$who / '$($t.name)': nothing was submitted, so the result must be NYS."
        }
        if ($wrongAssessment -and $result -ne 'NYS') {
            Fail "$who / '$($t.name)': the assessment submitted is not this unit's, so the result must be NYS."
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
        # The same reasoning for the wrong assessment: there is no question to
        # fix, so the item names what arrived and what to send instead. It reads
        # identically for every student this happens to, which is why it is
        # written here rather than asked for.
        if ($wrongAssessment -and $items.Count -eq 0) {
            $items = @([pscustomobject]@{
                questionNo = 'Whole assessment'
                issue      = "The work submitted is $($r.submittedInstead). It does not assess this unit."
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

        if ($attempt -ge 2 -and $submitted -and
            -not ($r.PSObject.Properties.Name.Contains('priorMarkedCopy') -and $r.priorMarkedCopy)) {
            Fail "$who / '$($t.name)': this is attempt $attempt, so the ledger must name 'priorMarkedCopy' — the file already marked at the previous attempt. Marking the raw submission again would lose that attempt's feedback page and its outcome lines, which are the audit trail."
        }
        # An observation tool needs the assessor's record of what was observed —
        # unless what arrived was another unit's assessment, in which case there
        # was nothing of THIS unit to observe. Demanding a record there would ask
        # the assessor to write down an observation that did not happen.
        if ($isObservationTool -and $submitted -and -not $wrongAssessment -and $observations.Count -eq 0) {
            Fail "$who / '$($t.name)': this is an observation tool, so it needs a brief point-form observation record. Add 'observations' to this result — one short point per thing you observed."
        }
        if ($observations.Count -gt 0 -and -not $submitted) {
            Fail "$who / '$($t.name)': nothing was submitted or observed, so there can be no observation record. Remove 'observations'."
        }
        foreach ($point in $observations) {
            foreach ($h in @(Test-FeedbackStyle -Text "$point" -Where "$who / '$($t.name)' / observation point")) {
                Fail ("{0}: {1} commas in one sentence, limit is {2}. {3} — `"{4}`"" -f $h.where, $h.commas, (Get-FeedbackMaxCommas), $h.fix, $h.sentence)
            }
            foreach ($h in @(Test-LearnerPronouns -Text "$point" -Where "$who / '$($t.name)' / observation point")) {
                Fail ("{0}: the word '{1}' - the RTO does not call a learner he or she. {2} - `"{3}`"" -f $h.where, $h.word, $h.fix, $h.near)
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

                # TWO SHEET SHAPES. A 'labelled' sheet writes the decision into
                # the box's own text — '☐ Yes'. A 'columns' sheet heads two
                # columns Yes and No and leaves a bare '☐' in each cell beneath,
                # which is what ACI's construction checklists do. The reader for
                # one is blind to the other, so the ledger says which it is.
                $sheetLayout = 'labelled'
                if ($sheet.PSObject.Properties.Name.Contains('layout') -and $sheet.layout) {
                    $sheetLayout = "$($sheet.layout)".Trim().ToLowerInvariant()
                }
                if (@('labelled', 'columns', 'inlinepairs') -notcontains $sheetLayout) {
                    Fail "$who / '$($t.name)': observationSheet.layout is '$($sheet.layout)'. Use 'labelled' for '☐ Yes' boxes, 'columns' for a Yes/No column table, or 'inlinePairs' for one decision column holding '☐ S ☐ NS'."
                }
                if ($sheet.PSObject.Properties.Name.Contains('sufficientLabels') -and $sheet.sufficientLabels) {
                    if (@($sheet.sufficientLabels).Count -ne 2) {
                        Fail "$who / '$($t.name)': observationSheet.sufficientLabels needs exactly two labels — the satisfied one first, as the sheet prints them."
                    }
                }
                foreach ($o in @($sheet.outcomes)) {
                    # RTO PROCESS: the practical is conducted before marking,
                    # always overseen by a trainer, with oral feedback given at
                    # the time. The sheet is then ticked Yes for all submitted
                    # work. So a Yes records an observation that happened and was
                    # watched — and the printed sheet still shows both columns,
                    # because the instrument's shape is the RTO's, not ours.
                    #
                    # A practical shortfall is recorded in the tool result, the
                    # SAR feedback and the feedback items, not here.
                    if ("$o" -eq 'No') {
                        Fail "$who / '$($t.name)': observationSheet.outcomes contains 'No'. The RTO's process is that the practical is conducted and supervised before marking, and the sheet is ticked Yes for all submitted work. Record a practical shortfall in the tool result, the SAR feedback and the feedback items — see SKILL.md, 'The practical observation, and why the sheet reads Yes'."
                    }
                    elseif ("$o" -ne 'Yes') { Fail "$who / '$($t.name)': observationSheet.outcomes must each be 'Yes', got '$o'." }
                }
                foreach ($fld in @($sheet.fields)) {
                    if (-not $fld.label) { Fail "$who / '$($t.name)': an observationSheet field has no label." }
                    if (-not $fld.PSObject.Properties.Name.Contains('value') -or "$($fld.value)".Trim() -eq '') {
                        Fail "$who / '$($t.name)': observationSheet field '$($fld.label)' has no value. A field left blank on a signed observation sheet reads as nobody filled it in."
                        foreach ($h in @(Test-LearnerPronouns -Text $text -Where "$who / '$($t.name)' / criterion comment $($ci + 1)")) {
                            Fail ("{0}: the word '{1}' - the RTO does not call a learner he or she. {2} - `"{3}`"" -f $h.where, $h.word, $h.fix, $h.near)
                        }
                    }
                }

                # snsChecklists — one per S / NS tick-box grid in the
                # submission, in document order. A practical tool observed on
                # two occasions carries two grids, and each needs its own
                # outcomes, its own overall outcome and its own comments box.
                # Same floor as the observation record, because that box IS the
                # record for that occasion.
                $sns = @()
                if ($sheet.PSObject.Properties.Name.Contains('snsChecklists') -and $sheet.snsChecklists) {
                    $sns = @($sheet.snsChecklists)
                }
                $snsSeen = @{}
                # A checklist split across two tables carries its outcome and
                # its comments on the second of them, so the record is required
                # once per TOOL rather than once per grid.
                $snsRecorded = $false
                for ($si = 0; $si -lt $sns.Count; $si++) {
                    $cl = $sns[$si]
                    $n  = $si + 1
                    # 'outcome' and 'comments' are both optional, because the
                    # small-table instrument records its overall outcome and its
                    # commentary somewhere other than beside each grid. What is
                    # never optional is the per-criterion judgement.
                    if ("$($cl.outcome)" -ne '' -and "$($cl.outcome)" -notin @('S','NS')) {
                        Fail "$who / '$($t.name)': observation checklist $n outcome must be 'S' or 'NS', got '$($cl.outcome)'."
                    }
                    if ("$($cl.outcome)" -eq 'NS' -and $result -ne 'NYS') {
                        Fail "$who / '$($t.name)': observation checklist $n is Not Satisfactory but the tool is $result. The checklist and the SAR would disagree."
                    }
                    # 'decision' answers the task decision line printed after
                    # this grid, where the instrument prints one. It is allowed
                    # to be Satisfactory under an NYS tool - a practical the
                    # assessor watched and accepted stays accepted when the
                    # tool fails on written evidence - but an NS decision under
                    # a Satisfactory tool would contradict the SAR.
                    if ("$($cl.decision)" -ne '' -and "$($cl.decision)" -notin @('S','NS')) {
                        Fail "$who / '$($t.name)': observation checklist $n decision must be 'S' or 'NS', got '$($cl.decision)'."
                    }
                    if ("$($cl.decision)" -eq 'NS' -and $result -ne 'NYS') {
                        Fail "$who / '$($t.name)': observation checklist $n records a Not Yet Satisfactory task decision but the tool is $result. The marked copy and the SAR would disagree."
                    }
                    $cn = @()
                    if ($cl.PSObject.Properties.Name.Contains('notes') -and $cl.notes) { $cn = @($cl.notes) }
                    if ($cn.Count -gt 0 -and $cn.Count -ne @($cl.outcomes).Count) {
                        Fail "$who / '$($t.name)': observation checklist $n gives $($cn.Count) note(s) for $(@($cl.outcomes).Count) criterion outcome(s). Give one per row, blank where there is nothing to add."
                    }
                    foreach ($nt in $cn) {
                        if ("$nt".Trim() -eq '') { continue }
                        foreach ($h in @(Test-FeedbackStyle -Text "$nt" -Where "$who / '$($t.name)' / observation checklist $n note")) {
                            Fail ("{0}: {1} commas in one sentence, limit is {2}. {3} — `"{4}`"" -f $h.where, $h.commas, (Get-FeedbackMaxCommas), $h.fix, $h.sentence)
                        }
                        foreach ($h in @(Test-LearnerPronouns -Text "$nt" -Where "$who / '$($t.name)' / observation checklist $n note")) {
                            Fail ("{0}: the word '{1}' - the RTO does not call a learner he or she. {2} - `"{3}`"" -f $h.where, $h.word, $h.fix, $h.near)
                        }
                    }
                    $co = @($cl.outcomes)
                    if ($co.Count -eq 0) { Fail "$who / '$($t.name)': observation checklist $n has no per-criterion outcomes." }
                    foreach ($o in $co) {
                        if ("$o" -notin @('S','NS')) { Fail "$who / '$($t.name)': observation checklist $n outcomes must each be 'S' or 'NS', got '$o'." }
                    }
                    if ("$($cl.outcome)" -eq 'S' -and @($co | Where-Object { "$_" -eq 'NS' }).Count -gt 0) {
                        Fail "$who / '$($t.name)': observation checklist $n is Satisfactory overall but has a criterion marked NS."
                    }
                    if ("$($cl.outcome)" -eq 'NS' -and @($co | Where-Object { "$_" -eq 'NS' }).Count -eq 0) {
                        Fail "$who / '$($t.name)': observation checklist $n is Not Satisfactory overall but every criterion is marked S. Say which behaviour was not met."
                    }
                    if (@($cn | Where-Object { "$_".Trim() -ne '' }).Count -gt 0) { $snsRecorded = $true }
                    $cp = @((("$($cl.comments)") -split "`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
                    if ($cp.Count -eq 0) { continue }
                    $snsRecorded = $true
                    if (-not $cl.assessor)  { Fail "$who / '$($t.name)': observation checklist $n has no assessor name for its sign-off line." }
                    if (-not $cl.dateText)  { Fail "$who / '$($t.name)': observation checklist $n has no dateText for its sign-off line." }
                    if ($cp.Count -lt 2) {
                        Fail "$who / '$($t.name)': observation checklist $n comments run to $($cp.Count) paragraph(s); the RTO requires at least 2. Separate them with a newline."
                    }
                    for ($pi = 0; $pi -lt $cp.Count; $pi++) {
                        $wc = @(($cp[$pi] -split '\s+') | Where-Object { $_ -ne '' }).Count
                        if ($wc -lt 25) {
                            Fail "$who / '$($t.name)': observation checklist $n, comment paragraph $($pi + 1) is $wc word(s); the RTO requires at least 25. Say what you saw this student do."
                        }
                    }
                    $key = (("$($cl.comments)") -replace '\s+', ' ').Trim().ToLowerInvariant()
                    if ($snsSeen.ContainsKey($key)) {
                        Fail "$who / '$($t.name)': observation checklist $n repeats checklist $($snsSeen[$key]) word for word. Each occasion is a different project and needs its own record."
                    }
                    $snsSeen[$key] = $n
                    foreach ($h in @(Test-FeedbackStyle -Text "$($cl.comments)" -Where "$who / '$($t.name)' / observation checklist $n")) {
                        Fail ("{0}: {1} commas in one sentence, limit is {2}. {3} — `"{4}`"" -f $h.where, $h.commas, (Get-FeedbackMaxCommas), $h.fix, $h.sentence)
                    }
                    foreach ($h in @(Test-LearnerPronouns -Text "$($cl.comments)" -Where "$who / '$($t.name)' / observation checklist $n")) {
                        Fail ("{0}: the word '{1}' - the RTO does not call a learner he or she. {2} - `"{3}`"" -f $h.where, $h.word, $h.fix, $h.near)
                    }
                }
                if ($sns.Count -gt 0 -and -not $snsRecorded) {
                    Fail "$who / '$($t.name)': the observation checklists carry no comments and no notes, so nothing on them records what was observed."
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
                # RTO PROCESS: the sufficiency box is always satisfactory, for
                # the same reason — the practical was conducted and watched.
                if ($sheet.PSObject.Properties.Name.Contains('sufficient') -and $sheet.sufficient -eq $false) {
                    Fail "$who / '$($t.name)': observationSheet.sufficient is false. The RTO's process is that a conducted and supervised observation is satisfactory — see SKILL.md, 'The practical observation, and why the sheet reads Yes'."
                }
                # RTO RULE: assessor comments in every comments area the sheet
                # carries, one entry per area, in sheet order.
                $sheetComments = @()
                if ($sheet.PSObject.Properties.Name.Contains('comments') -and $sheet.comments) {
                    $sheetComments = @($sheet.comments)
                }
                # NOT EVERY COLUMN SHEET TAKES A NOTE IN EVERY ROW. Two shapes
                # in circulation do not:
                #
                #   * a checklist with no comments cell at all â€” ACI's
                #     CPCCCO2013 sheet heads '# / Observable behaviour / Maps to
                #     / S / NS' and stops. Demanding a note per row demands a
                #     cell that does not exist, and the build throws on row one;
                #   * a checklist whose column is the instrument's own reference
                #     field for a shortfall â€” 'Record comments for any NS item'.
                #     Filling all seventy of those on an all-satisfactory sheet
                #     writes padded prose into a column the instrument asks to be
                #     used only when something was not met.
                #
                # Either way the sheet's real comments areas are its per-activity
                # 'Assessor Comments' boxes, which the tool's tasks fill. The
                # ledger has to SAY SO, once and explicitly, so silence is still
                # refused and a sheet that does take row notes cannot quietly
                # lose them.
                $perRowComments = $true
                foreach ($flagName in @('perRowComments','hasCommentsColumn')) {
                    if ($sheet.PSObject.Properties.Name.Contains($flagName) -and $null -ne $sheet.$flagName) {
                        $perRowComments = [bool]$sheet.$flagName
                        break
                    }
                }
                $hasCommentsColumn = $perRowComments
                if ($sheetComments.Count -eq 0 -and $hasCommentsColumn) {
                    Fail "$who / '$($t.name)': observationSheet.comments is missing. Every Assessor comments area on the sheet takes a comment, written to references/observation-comments.md and checked with Test-ObservationComments.ps1. Where the checklist carries no comments column beside its criteria, say so with 'perRowComments': false."
                }
                if ($sheetComments.Count -gt 0 -and -not $hasCommentsColumn) {
                    Fail "$who / '$($t.name)': observationSheet.perRowComments is false but row comments were written. There is nowhere on that sheet to put them."
                }
                # A COLUMN SHEET's comments area is a narrow cell beside each
                # criterion, and there is one per row. So the count is checked
                # against the outcomes, and each entry is held to the row-note
                # standard rather than the two-paragraph standard written for an
                # 'Assessor comments' box — twenty-eight boxed comments say less
                # than twenty-eight lines do.
                if (@('columns','inlinepairs') -contains $sheetLayout -and $sheetComments.Count -gt 0 -and @($sheet.outcomes).Count -gt 0 -and
                    $sheetComments.Count -ne @($sheet.outcomes).Count) {
                    Fail "$who / '$($t.name)': observationSheet.comments has $($sheetComments.Count) entr(ies) but the sheet judges $(@($sheet.outcomes).Count) criterion row(s). A column sheet takes one comment per row, in sheet order."
                }
                $ci = 0
                foreach ($cm in $sheetComments) {
                    $ci++
                    $cmText = if ($cm -is [string]) { "$cm" } else { "$($cm.text)" }
                    if (-not "$cmText".Trim()) {
                        Fail "$who / '$($t.name)': observationSheet.comments entry $ci is empty. A comments area left blank on a signed observation sheet reads as nobody filling it in."
                        continue
                    }
                    $style = if (@('columns','inlinepairs') -contains $sheetLayout) {
                        @(Test-ObservationRowNoteStyle -Text $cmText -Where "$who / '$($t.name)' / row note $ci")
                    } else {
                        @(Test-ObservationCommentStyle -Text $cmText -Where "$who / '$($t.name)' / assessor comment $ci")
                    }
                    foreach ($h in $style) { Fail $h }
                }
            } else {
                $checks += "$who / '$($t.name)': the observation record goes on the declaration page, because the ledger states this submission carries no observation sheet."
            }
        }
        if ($sheet -and $observations.Count -eq 0) {
            Fail "$who / '$($t.name)': an observationSheet is named but there is no observation record to write into it. Add 'observations', or remove the sheet."
        }

        # ---- the assessor's comment on the tool ------------------------------
        # At least two paragraphs of at least twenty words, on every tool that
        # was actually assessed. A non-submission carries the RTO's own standing
        # wording and is exempt; a withheld result is NOT — the work was still
        # marked and the student still reads the comment on their sheet.
        if ($submitted) {
            foreach ($h in @(Test-AssessorComment -Text "$($r.feedback)" -Where "$who / '$($t.name)' / assessor comment")) { Fail $h }
        }

        # ---- the tasks inside the tool ---------------------------------------
        $taskList = @()
        if ($r.PSObject.Properties.Name -contains 'tasks' -and $r.tasks) { $taskList = @($r.tasks) }
        $seenTask = @{}
        foreach ($tk in $taskList) {
            $ref = "$($tk.ref)".Trim()
            if (-not $ref) { Fail "$who / '$($t.name)': a task carries no 'ref'."; continue }
            if ($seenTask.ContainsKey($ref)) { Fail "$who / '$($t.name)': duplicate task ref '$ref'." }
            $seenTask[$ref] = $true
            if ("$($tk.outcome)" -notin @('S', 'NYS')) {
                Fail "$who / '$($t.name)' / task '$ref': outcome is '$($tk.outcome)'; it must be S or NYS."
            }
            if (-not "$($tk.anchor)".Trim()) {
                Fail "$who / '$($t.name)' / task '$ref': no 'anchor'. A task outcome is placed by text the ledger names, never by position."
            }
            foreach ($h in @(Test-AssessorComment -Text "$($tk.comment)" -Where "$who / '$($t.name)' / task '$ref'")) { Fail $h }
        }
        # A tool judged S cannot hold a task judged NYS, and a tool judged NYS
        # with tasks must name which one failed.
        if ($taskList.Count -gt 0) {
            $nysTasks = @($taskList | Where-Object { "$($_.outcome)" -eq 'NYS' }).Count
            if ($result -eq 'S'   -and $nysTasks -gt 0) { Fail "$who / '$($t.name)': the tool is Satisfactory but $nysTasks task(s) are Not Yet Satisfactory." }
            if ($result -eq 'NYS' -and $nysTasks -eq 0) { Fail "$who / '$($t.name)': the tool is Not Yet Satisfactory but every task is Satisfactory. Name the task that was not met." }
        }

        # ---- the pre-start verification checklist -----------------------------
        if ($sheet -and ($sheet.PSObject.Properties.Name -contains 'verification') -and $sheet.verification) {
            $vi = 0
            foreach ($v in @($sheet.verification)) {
                $vi++
                if (-not "$($v.item)".Trim()) { Fail "$who / '$($t.name)': verification row $vi names no item."; continue }
                if ("$($v.outcome)" -notin @('Yes', 'No')) {
                    Fail "$who / '$($t.name)' / verification '$($v.item)': outcome is '$($v.outcome)'; it must be Yes or No."
                }
                foreach ($h in @(Test-ObservationRowNoteStyle -Text "$($v.note)" -Where "$who / '$($t.name)' / verification '$($v.item)'")) { Fail $h }
            }
        }

        # Every submitted tool should be marked in a way the student can see on
        # their returned copy: a remark under each question, or an observation
        # record. Neither is a CHECK rather than a failure, because a tool can
        # legitimately be judged on evidence that is not a Word document.
        if ($submitted -and -not $wrongAssessment -and $questions.Count -eq 0 -and $observations.Count -eq 0) {
            $checks += "$who / '$($t.name)': submitted but carries neither per-question outcomes nor an observation record, so the student's returned copy will show no remarks for this tool."
        }
        if ($wrongAssessment -and ($questions.Count -gt 0 -or $observations.Count -gt 0)) {
            Fail "$who / '$($t.name)': the assessment submitted is not this unit's, so it carries no question outcomes and no observation record. Remove them."
        }

        # the feedback option is DERIVED, never stated
        $option = if (-not $submitted) { 'notSubmitted' } elseif ($result -eq 'S') { 'completed' } else { 'corrections' }
        if ($result -eq 'NYS') { $anyNys = $true }

        $resolvedResults += [pscustomobject]@{
            toolId         = $t.id
            toolName       = $t.name
            result           = $result
            submitted        = $submitted
            wrongAssessment  = $wrongAssessment
            submittedInstead = $(if ($r.PSObject.Properties.Name.Contains('submittedInstead')) { $r.submittedInstead } else { $null })
            feedbackOption = $option
            feedback       = $r.feedback
            aiFlagged      = $aiFlagged
            evidence       = $(if ($r.PSObject.Properties.Name.Contains('evidence')) { $r.evidence } else { $null })
            questions      = $questions
            observations   = $observations
            # RESUBMISSIONS STACK. At attempt 2 the marked copy is built FROM
            # the file marked at attempt 1, so that attempt's feedback page and
            # outcome lines survive. Required, because marking the raw
            # submission again would quietly destroy the earlier record.
            priorMarkedCopy = $(if ($r.PSObject.Properties.Name.Contains('priorMarkedCopy')) { $r.priorMarkedCopy } else { $null })
            isObservation  = [bool]$isObservationTool
            observationSheet = $(if ($sheetInSubmission) { $sheet } else { $null })
            questionsEndAnchor = $(if ($r.PSObject.Properties.Name.Contains('questionsEndAnchor')) { $r.questionsEndAnchor } else { $null })
            # THE TASKS HAVE TO REACH THE BUILDER. They were validated above and
            # then dropped here, so a ledger naming three activities produced a
            # marked copy with no judgement on any of them â€” and the gate agreed,
            # because TaskOutcomeColoured checks the resolved ledger and the
            # resolved ledger no longer mentioned them. A silent no-op that every
            # check reports as a pass.
            tasks          = $taskList
            tasksEndAnchor = $(if ($r.PSObject.Properties.Name.Contains('tasksEndAnchor')) { $r.tasksEndAnchor } else { $null })
            checklistMarker = $(if ($r.PSObject.Properties.Name.Contains('checklistMarker')) { $r.checklistMarker } else { $null })
            items          = $items
        }
    }

    $overall = if ($anyNys) { 'NYC' } else { 'C' }

    # --- RW: the prerequisite gate ------------------------------------------
    #
    # Applied AFTER the S/NYS -> C/NYC derivation, and overriding it. RW
    # withholds a result; it does not skip the assessment. Every tool is still
    # judged, the work is still marked, and the marked copy still carries a
    # coloured outcome under every answer.
    #
    # Status comes from the WiseNet matrix (Import-WisenetMatrix.ps1
    # -Prerequisite). The only way off notCompleted is an assessor's
    # confirmedExternally, which needs evidence recorded against it.
    $prereqNotMet = @()
    foreach ($p in $unitPrereqs) {
        $st = 'notCompleted'; $ev = $null
        # the matrix first, the ledger over the top of it
        if ($rollPrereq.ContainsKey($s.studentId) -and $rollPrereq[$s.studentId].ContainsKey($p.code)) {
            $st = $rollPrereq[$s.studentId][$p.code]
        }
        if ($s.PSObject.Properties.Name.Contains('prerequisiteStatus') -and $s.prerequisiteStatus) {
            $entry = $s.prerequisiteStatus.PSObject.Properties | Where-Object { $_.Name -eq $p.code } | Select-Object -First 1
            if ($entry) {
                $st = "$($entry.Value.status)"
                $ev = "$($entry.Value.evidence)"
            }
        }
        if ($st -eq 'confirmedExternally') {
            if (-not $ev) {
                Fail "$who / prerequisite $($p.code): status is confirmedExternally but no evidence is recorded. A testamur, a Statement of Attainment or an authenticated USI/VET transcript — a verbal claim or a licence card is not evidence."
            }
        } elseif ($st -ne 'completed') {
            $prereqNotMet += $p
        }
    }
    if ($prereqNotMet.Count -gt 0) { $overall = 'RW' }

    # --- comment ------------------------------------------------------------
    $noSubmissionAll = ($resolvedResults.Count -gt 0) -and (@($resolvedResults | Where-Object { -not $_.submitted }).Count -eq $resolvedResults.Count)
    $wrongAll        = ($resolvedResults.Count -gt 0) -and (@($resolvedResults | Where-Object { $_.wrongAssessment }).Count -eq $resolvedResults.Count)
    $comment = $s.comment
    if ($noSubmissionAll) {
        if ($comment -and $comment -ne 'No submission') {
            Fail "$who submitted nothing, so the marking record comment must be exactly 'No submission' (found '$comment')."
        }
        $comment = 'No submission'
    }
    # Reads identically for every student it happens to, for the same reason
    # 'No submission' does: the Comments column is read down a class, and two
    # wordings for one situation read as two different situations.
    if ($wrongAll) {
        if ($comment -and $comment -ne 'Incorrect assessment submitted') {
            Fail "$who submitted another assessment, so the marking record comment must be exactly 'Incorrect assessment submitted' (found '$comment')."
        }
        $comment = 'Incorrect assessment submitted'
    }
    # A withheld result overrides whatever the comment would otherwise say. The
    # Comments column has to carry the reason the result is not there, and it
    # has to read identically for every RW student in the class.
    if ($overall -eq 'RW') { $comment = Get-WithheldComment }
    if (-not $comment) { Fail "$who has no marking record comment." }
    foreach ($h in @(Test-FeedbackStyle -Text "$comment" -Where "$who / marking record comment")) {
        Fail ("{0}: {1} commas in one sentence, limit is {2}. {3} — `"{4}`"" -f $h.where, $h.commas, (Get-FeedbackMaxCommas), $h.fix, $h.sentence)
    }
    if ($comment -and $comment.Length -gt 120) {
        Fail "$who comment is $($comment.Length) characters. The Comments column takes a short phrase, not a paragraph — the SAR carries the full feedback."
    }

    # --- resit, invoice, re-enrol ------------------------------------------
    # RW is not an adverse outcome — the student has done nothing wrong and has
    # not used an attempt. Neither box is ever ticked for them.
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

    # SETTLED by the RTO on 2 September 2026: a withheld result carries a
    # resubmission date of five working days from the marking date, ALWAYS —
    # whether or not any tool is NYS. The earlier reading gave an all-S RW
    # student N/A on the grounds that they had nothing to resubmit; the RTO's
    # answer is that the date is the date by which the prerequisite question has
    # to be resolved, so it applies to every withheld result.
    #
    # It is the same five-business-day date the NYC students get, computed once
    # in Lib-Dates.ps1 from the marking date. Nothing here recomputes it.
    $resubText =
        if     ($overall -eq 'NYC') { $dates.ResubmissionDueText }
        elseif ($overall -eq 'RW')  { $dates.ResubmissionDueText }
        else                        { 'N/A' }

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
        # the prerequisites this student does not hold — drives the withheld
        # notice on page one and the gate's RwNoticePresent check
        prerequisitesNotMet = @($prereqNotMet)
        wisenetOutcomeCode  = $(if ($overall -eq 'RW') { '70' } else { $null })
        needsFeedbackSheet  = ($overall -eq 'NYC')
        feedbackItemCount   = (@($resolvedResults | ForEach-Object { $_.items }) | Measure-Object).Count
        # SAR_<UNITCODE>_<Student Name>_<StudentID>_<RESULT>.docx
        # The SAR_ prefix is load-bearing, not a leftover: without it the SAR and
        # the marked copy resolve to the identical name and one overwrites the
        # other in the output directory.
        sarFile             = "SAR_${unitCode}_$(Get-NameSegment "$($s.firstName) $($s.surname)")_$($s.studentId)_$overall.docx"
        # FEEDBACK_<UNITCODE>_<Student Name>_<StudentID>_<RESULT>.docx — the SAR's
        # four fields behind its own prefix, so a folder of records sorts and
        # reads one way. It was FEEDBACK_<ID>_<UNIT>_<date>, which sorted by
        # student ID and put the result nowhere.
        feedbackFile        = "FEEDBACK_${unitCode}_$(Get-NameSegment "$($s.firstName) $($s.surname)")_$($s.studentId)_$overall.docx"
    }
}

if (@($L.students).Count -eq 0) { Fail 'No students in the ledger.' }

# ------------------------------------------------- roll reconciliation -------
#
# A student on the matrix with no ledger entry is the failure this exists for.
# Nothing downstream can see it: the build renders the ledger, and the gate
# compares the ledger to what was rendered, so a student missing from both looks
# like a clean run of a smaller class. The only place the omission is visible is
# here, against the roll.
$rollSummary = $null
if ($rollData) {
    $ledgerIds = @{}
    foreach ($rs in $resolvedStudents) { $ledgerIds[$rs.studentId] = $rs }

    $missing = @()
    foreach ($r in $rollRequired) {
        if (-not $r.studentId) {
            $checks += "The roll lists '$($r.displayName)' with no student ID, so they cannot be reconciled against the ledger. Identity is the ID, never the name."
            continue
        }
        if (-not $ledgerIds.ContainsKey($r.studentId)) { $missing += $r }
    }
    foreach ($m in $missing) {
        Fail "$($m.displayName) [$($m.studentId)] is REQUIRED TO SUBMIT on the roll but has no entry in the ledger. Mark them, or say why they are out — a student dropped here is invisible to every check that follows."
    }

    # The other direction is a question, not a fault: a student carrying a
    # pending code (70, 85, 90) is not selected by the blank-cell rule, and the
    # assessor may have confirmed against the class roll that they are due.
    $rollIds = @{}
    foreach ($r in $rollRequired) { if ($r.studentId) { $rollIds[$r.studentId] = $true } }
    foreach ($rs in $resolvedStudents) {
        if (-not $rollIds.ContainsKey($rs.studentId)) {
            $checks += "$($rs.fullName) [$($rs.studentId)] is in the ledger but not in REQUIRED TO SUBMIT on the roll. Confirm they are due to submit — a pending code (70, 85, 90) is the usual reason."
        }
    }

    # RTO RULE: a student whose ENROLMENT is Pending is not marked. They have no
    # result to record and no submission to expect, so a record produced for
    # them says an assessment happened that did not. The importer keeps them off
    # REQUIRED TO SUBMIT; this catches one written into the ledger by hand.
    $pendingIds = @{}
    foreach ($p in @($rollData.pendingEnrolment)) { if ($p.studentId) { $pendingIds[$p.studentId] = $p } }
    foreach ($rs in $resolvedStudents) {
        if ($pendingIds.ContainsKey($rs.studentId)) {
            Fail "$($rs.fullName) [$($rs.studentId)] is Pending enrolment on the roll, so they are not marked. Remove them from the ledger; they are marked once their enrolment starts."
        }
    }

    $rollSummary = [pscustomobject]@{
        source        = $rollData.source
        unit          = $rollData.unit
        requiredCount = @($rollRequired).Count
        matched       = (@($rollRequired).Count - $missing.Count)
        missingCount  = $missing.Count
        pendingCount  = @($rollData.pendingEnrolment).Count
    }
}

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

    # <UNITCODE>_<Student Name>_<StudentID>_<RESULT>.docx
    #
    # DEVIATION, FLAGGED: that convention names a student once, but this skill
    # produces one marked copy per submitted FILE, so a student who submits two
    # documents has two copies and they would collide. Where — and only where —
    # a student has more than one, the tool group is appended to keep them apart.
    # A student with a single submission gets the four-field name exactly as
    # specified. The duplicate-name check below is what makes this visible rather
    # than a silent overwrite.
    $multi = ($groups.Keys.Count -gt 1)
    foreach ($key in $groups.Keys) {
        $g       = $groups[$key]
        $toolIds = @($g.results | ForEach-Object { $_.toolId })
        $stem    = "{0}_{1}_{2}_{3}" -f $L.unit.code, (Get-NameSegment "$($rs.firstName) $($rs.surname)"), $rs.studentId, $rs.overall
        if ($multi) { $stem = "{0}_{1}" -f $stem, ($toolIds -join '-') }
        $markedCopies += [pscustomobject]@{
            file      = "$stem.docx"
            studentId = $rs.studentId
            student   = $rs.fullName
            evidence  = $g.evidence
            # At attempt 2+ this is the file the builder actually opens, so the
            # earlier attempt's feedback page travels forward intact.
            priorMarkedCopy = @(@($g.results | ForEach-Object { $_.priorMarkedCopy } | Where-Object { $_ }))[0]
            attempt   = $rs.attempt
            toolIds   = $toolIds
            toolNames = @($g.results | ForEach-Object { $_.toolName })
        }
    }
}

# --------------------------------------- who still needs a standalone sheet ---
#
# THE FEEDBACK GOES WHERE THE STUDENT CAN READ IT. A student with a marked copy
# reads it on page one of their own returned assessment, where it cannot be
# separated from the work it describes. A student with NO marked copy — nothing
# submitted, or the wrong assessment submitted — has nothing coming back, and
# their feedback would otherwise exist only on a SAR, which is an internal
# record and not a document the student is handed.
#
# So they get the Student Feedback Sheet, standalone, in the same format as page
# one. Not a fallback: it is the only copy of their feedback that reaches them.
$copiesByStudent = @{}
foreach ($mc in $markedCopies) { $copiesByStudent[$mc.studentId] = $true }
foreach ($rs in $resolvedStudents) {
    $hasCopy = $copiesByStudent.ContainsKey($rs.studentId)
    $rs.needsFeedbackSheet = (-not $hasCopy)
    if ($rs.needsFeedbackSheet -and $rs.feedbackItemCount -eq 0) {
        # Build-Feedback refuses an empty sheet, and it is right to: a sheet
        # with no rows tells the student nothing. Say so here, where it can be
        # fixed, rather than at the build.
        $checks += "$($rs.fullName) [$($rs.studentId)] has no marked copy and no feedback items, so no standalone feedback sheet is produced. Their feedback is on the SAR alone."
        $rs.needsFeedbackSheet = $false
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
    unit          = [pscustomobject]@{
        code                       = $L.unit.code
        title                      = $L.unit.title
        coreElective               = $L.unit.coreElective
        prerequisites              = $unitPrereqs
        prerequisitesConfirmedNone = ($unitPrereqs.Count -eq 0)
        prerequisiteSource         = $(if ($L.unit.PSObject.Properties.Name.Contains('prerequisiteSource'))    { $L.unit.prerequisiteSource }    else { $null })
        prerequisiteCheckedOn      = $(if ($L.unit.PSObject.Properties.Name.Contains('prerequisiteCheckedOn')) { $L.unit.prerequisiteCheckedOn } else { $null })
        # the one string every template prints — derived, never hand-written
        prerequisiteText           = $prereqText
    }
    qualification = $L.qualification
    assessor      = $L.assessor
    location      = $L.location
    environment   = $L.environment
    # The map of the assessment pack's own cover sheet — which label takes which
    # value, and which assessment-type box is ticked. It travels with the
    # resolved ledger so the builder fills it and the gate can check it was.
    coverSheet    = $(if ($L.PSObject.Properties.Name.Contains('coverSheet')) { $L.coverSheet } else { $null })
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
        # The date the assessment was due back from the student. It is a fact
        # about the class timetable rather than something this skill can derive,
        # so the ledger states it; where it does not, the date of assessment
        # stands in, which is the date the records already carry for the work.
        dueDateText          = $(if ($L.PSObject.Properties.Name.Contains('dueDate') -and "$($L.dueDate)".Trim()) { "$($L.dueDate)".Trim() } else { $dates.AssessmentDateText })
    }
    students      = $resolvedStudents
    markedCopies  = $markedCopies
    amrrFile      = "AMLC_$($unitCode.ToUpper())_$($marking.ToString('ddMMyyyy')).docx"
    # Null where no roll was supplied. The gate reports that as a WARN: the run
    # is usable, but nothing has confirmed the class is the whole class.
    roll          = $rollSummary
    summary       = [pscustomobject]@{
        students       = $resolvedStudents.Count
        competent      = @($resolvedStudents | Where-Object { $_.overall -eq 'C' }).Count
        notYetCompetent= @($resolvedStudents | Where-Object { $_.overall -eq 'NYC' }).Count
        resultWithheld = @($resolvedStudents | Where-Object { $_.overall -eq "RW" }).Count
        # one student is not a class, so no Assessment Marking and Results Record
        buildMarkingRecord = (@($resolvedStudents).Count -gt 1)
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
    Write-Output ("  Students        {0}  —  {1} C, {2} NYC, {3} RW" -f $resolved.summary.students, $resolved.summary.competent, $resolved.summary.notYetCompetent, $resolved.summary.resultWithheld)
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
