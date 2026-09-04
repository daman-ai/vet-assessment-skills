<#
  Test-MarkingRecords.ps1 — the blocking gate. Nothing is delivered until this
  passes.

  It reads the DELIVERED FILES, not the build's own log, and checks them back
  against the resolved ledger. A build that reports success while shipping a
  leftover field, a double tick or a SAR that disagrees with its row in the
  marking record is the failure this exists to catch, so every check reads
  bytes off disk.

  Checks, in the order the RTO's own closing checklist lists them:

    NoUnfilledField          no [ … ] survives anywhere
    NoBracketedBox           every [ ☐ ] became ☐ or ☒, brackets gone
    NoPlaceholderStyling     no run still carries the grey placeholder colour
    SarPerStudent            one SAR per student, named correctly
    MarkingRecordName        AMLC_<UNIT>_<DDMMYYYY>.docx
    NoUnusedRows             no placeholder row left in any document
    FeedbackSheetPerNyc      one per NYC student, named correctly, one page
    OneTickPerToolRow        exactly one of S / NYS per tool row
    OneFeedbackOptionPerRow  exactly one feedback option ticked per tool row
    OverallResultRule        any NYS → NYC; all S → C
    ToolNamesIdentical       same tool names in every document
    CrossDocumentAgreement   SAR, marking record row and feedback sheet agree
    DateRules                assessment, feedback-given and resubmission dates
    InvoiceRule              ticked only where NYC after the second attempt
    NoSubmissionComment      a non-submission reads exactly 'No submission'
    TemplateUntouched        headers, footers, styles and numbering unchanged
    MarkedCopyOutcomes       one coloured outcome per question, front page matches the SAR
    MarkedCopyInAnswerSpace  every outcome line sits in the answer it judges
    MarkedCopyDeclarationPage the declaration is a page of its own, before the student's
    MarkedCopyObservationSheet the observation record is in the sheet, not bolted on the front
    MarkedCopyFrontBlockAligned  the front block sits on the content's own edges
    NoBannedWord             the RTO's banned word appears in no issued document
    NoMojibake               no double-encoded characters
    NoInventedNamespacePrefix no reserved namespace bound to a made-up prefix
    OpensInWord              every file actually opens, feedback sheets on one page

  Usage:
    .\Test-MarkingRecords.ps1 -Ledger resolved.json -Dir .\out
    .\Test-MarkingRecords.ps1 -Ledger resolved.json -Dir .\out -SkipRender
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Ledger,
    [Parameter(Mandatory)][string]$Dir,
    [string]$RtoProfile,
    [switch]$SkipRender,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-Docx.ps1')

$AssetRoot = Join-Path $PSScriptRoot '..\assets'
$BOX_E = [char]0x2610
$BOX_T = [char]0x2612

$L = Get-Content -Raw -Encoding UTF8 -LiteralPath $Ledger | ConvertFrom-Json
if (-not $L.dates) { throw 'Pass a RESOLVED ledger (Resolve-MarkingLedger.ps1 -Out).' }

if (-not $RtoProfile) { $RtoProfile = Join-Path $AssetRoot ("rto.{0}.json" -f $L.rto) }
$Rto = Get-Content -Raw -Encoding UTF8 -LiteralPath $RtoProfile | ConvertFrom-Json

function Get-Count {
    # @($null).Count is 1, not 0. Any "does this list have anything in it"
    # question asked with @($x).Count therefore answers yes for a property that
    # does not exist. This is the only counting used for such tests.
    param($Value)
    if ($null -eq $Value) { return 0 }
    @($Value | Where-Object { $null -ne $_ }).Count
}

$results = New-Object System.Collections.ArrayList
function Add-Check {
    param([string]$Name, [bool]$Pass, [string]$Detail = '', [switch]$Warn)
    [void]$results.Add([pscustomobject]@{
        name   = $Name
        status = $(if ($Pass) { 'PASS' } elseif ($Warn) { 'WARN' } else { 'FAIL' })
        detail = $Detail
    })
}

# --------------------------------------------------------------- inventory ---

$dirFull = (Resolve-Path -LiteralPath $Dir).Path
$files   = @(Get-ChildItem -LiteralPath $dirFull -Filter '*.docx' -File)

$expected = @{}
$markedExpected = @{}
$feedbackExpected = @{}
foreach ($s in $L.students) {
    $expected[$s.sarFile] = "SAR for $($s.fullName)"
    # A student with no marked copy — nothing submitted, or the wrong assessment
    # submitted — has nothing coming back, so their feedback is issued as the
    # standalone Student Feedback Sheet. The resolver decides who that is.
    if ($s.needsFeedbackSheet) {
        $expected[$s.feedbackFile] = "feedback sheet for $($s.fullName)"
        $feedbackExpected[$s.feedbackFile] = $s
    }
}

# Which marked copies exist is the RESOLVER'S decision, not one this script
# repeats. One copy per submitted FILE, so a document carrying UAT 1 and UAT 2
# is one marked copy answering for both. Re-deriving the list here is how a gate
# ends up checking a set of files the builder never agreed to produce.
if (-not $L.PSObject.Properties.Name.Contains('markedCopies')) {
    throw 'This resolved ledger has no markedCopies. Re-run Resolve-MarkingLedger.ps1.'
}
$studentsById = @{}
foreach ($s in $L.students) { $studentsById[$s.studentId] = $s }
foreach ($mc in @($L.markedCopies)) {
    $st = $studentsById[$mc.studentId]
    $expected[$mc.file] = "marked copy for $($mc.student) / $(($mc.toolNames) -join ' + ')"
    $markedExpected[$mc.file] = [pscustomobject]@{
        student = $st
        copy    = $mc
        results = @(foreach ($tid in @($mc.toolIds)) { @($st.results | Where-Object { $_.toolId -eq $tid })[0] })
    }
}
# One student is not a class: the resolver says whether a marking record is due,
# and the gate reads that decision rather than assuming one always exists.
$wantAmrr = -not ($L.summary.buildMarkingRecord -eq $false)
if ($wantAmrr) { $expected[$L.amrrFile] = 'marking record' }

# The three OFFICIAL RECORDS are built from the RTO's templates and every
# template-shaped check applies to them. A MARKED copy is the STUDENT'S OWN
# document with two additions, so checks about fields, rows and house styling
# would be policing the student's writing, not ours.
# Which files are marked copies is the RESOLVER'S list, not a filename prefix.
# The naming convention no longer carries one, and a gate that guessed from the
# name would start policing the student's own writing as if it were our template.
$recordFiles = @($files | Where-Object { -not $markedExpected.ContainsKey($_.Name) })
$markedFiles = @($files | Where-Object {      $markedExpected.ContainsKey($_.Name) })

# cache each file's text once
$textOf = @{}
$rowsOf = @{}
foreach ($f in $files) {
    $textOf[$f.Name] = Get-DocxText     -Path $f.FullName
    $rowsOf[$f.Name] = Get-DocxRowText  -Path $f.FullName
}

# ------------------------------------------------------------- 1. presence ---

$missing = @($expected.Keys | Where-Object { -not (Test-Path -LiteralPath (Join-Path $dirFull $_)) })
$extra   = @($files | Where-Object { -not $expected.ContainsKey($_.Name) } | ForEach-Object { $_.Name })

Add-Check 'SarPerStudent' ($missing.Count -eq 0 -and $extra.Count -eq 0) `
    $(if ($missing.Count) { "missing: $($missing -join ', ')" } elseif ($extra.Count) { "unexpected file(s): $($extra -join ', ')" } else { "$($L.students.Count) SAR + 1 record + $($feedbackExpected.Count) standalone feedback sheet(s) + feedback on page one of every marked copy, all present and correctly named" })

# ---- naming convention, and the collision it would otherwise hide ----------
#
# <UNITCODE>_<Student Name>_<StudentID>_<RESULT>.docx for a marked copy, the
# same four fields behind SAR_ for a SAR. The name segment must carry no
# underscore, or the four fields stop being parseable.
$RESULTS_RX = 'C|NYC|RW'
$nameProbs = @()
foreach ($mc in @($L.markedCopies)) {
    $st = $studentsById[$mc.studentId]
    $expect = "$($L.unit.code)_"
    if ($mc.file -notlike "$expect*") { $nameProbs += "$($mc.file) does not start with the unit code" }
    if ($mc.file -notmatch "_($RESULTS_RX)(_[A-Za-z0-9\-]+)?\.docx$") {
        $nameProbs += "$($mc.file) does not end with a result of C, NYC or RW"
    }
    $seg = ($mc.file -replace '\.docx$','') -split '_'
    if ($seg.Count -lt 4) { $nameProbs += "$($mc.file) has $($seg.Count) underscore-separated fields, expected at least 4" }
    elseif ($seg[1] -match '_') { $nameProbs += "$($mc.file): the name segment contains an underscore" }
}
# A standalone feedback sheet carries the same four fields behind FEEDBACK_, so
# a folder of records sorts and reads one way whatever a student received.
foreach ($fbName in $feedbackExpected.Keys) {
    $st = $feedbackExpected[$fbName]
    $want = "FEEDBACK_$($L.unit.code)_"
    if ($fbName -notlike "$want*") { $nameProbs += "$fbName does not start with FEEDBACK_ and the unit code" }
    if ($fbName -notmatch "_($RESULTS_RX)\.docx$") { $nameProbs += "$fbName does not end with a result of C, NYC or RW" }
    if ($fbName -notlike "*_$($st.studentId)_*") { $nameProbs += "$fbName does not carry the student ID" }
}
Add-Check 'MarkedCopyName' ($nameProbs.Count -eq 0) `
    $(if ($nameProbs.Count) { ($nameProbs | Select-Object -First 6) -join ' · ' } else { "$(@($L.markedCopies).Count) marked copy name(s) follow <UNIT>_<Name>_<ID>_<RESULT>" })

# Two output files sharing a name means one overwrote the other, and the folder
# looks tidy either way. Cheap to check, and it catches a collision without
# anyone having to reason about which conventions might overlap.
$derived = @()
foreach ($s in $L.students) { $derived += $s.sarFile }
foreach ($mc in @($L.markedCopies)) { $derived += $mc.file }
if ($wantAmrr) { $derived += $L.amrrFile }
$dupes = @($derived | Group-Object | Where-Object { $_.Count -gt 1 })
Add-Check 'NoDuplicateOutputName' ($dupes.Count -eq 0) `
    $(if ($dupes.Count) { "these names are produced more than once, so one file overwrites another: $((@($dupes | ForEach-Object { $_.Name })) -join ', ')" } else { "$($derived.Count) output name(s), all distinct" })

if ($wantAmrr) {
    Add-Check 'MarkingRecordName' (Test-Path -LiteralPath (Join-Path $dirFull $L.amrrFile)) $L.amrrFile
} else {
    Add-Check 'SingleStudentNoMarkingRecord' (-not (Test-Path -LiteralPath (Join-Path $dirFull $L.amrrFile))) `
        $(if (Test-Path -LiteralPath (Join-Path $dirFull $L.amrrFile)) { "a marking record was built for a one-student class: $($L.amrrFile)" } else { 'one student, so no Assessment Marking and Results Record — correct' })
}

# ------------------------------------------------- 2. fields, boxes, style ---

$fieldHits = @()
$boxHits    = @()
foreach ($f in $recordFiles) {
    $t = $textOf[$f.Name] + "`n" + (($rowsOf[$f.Name]) -join "`n")
    foreach ($m in [regex]::Matches($t, '\[[^\[\]\r\n]{1,120}\]')) {
        $fieldHits += "$($f.Name): $($m.Value)"
    }
    foreach ($m in [regex]::Matches($t, "\[\s*[$BOX_E$BOX_T]\s*\]")) {
        $boxHits += "$($f.Name): $($m.Value)"
    }
}
$fieldOnly = @($fieldHits | Where-Object { $_ -notmatch "\[\s*[$BOX_E$BOX_T]\s*\]" })

Add-Check 'NoUnfilledField' ($fieldOnly.Count -eq 0) `
    $(if ($fieldOnly.Count) { ($fieldOnly | Select-Object -First 8) -join ' · ' } else { 'no [ … ] field survives in any document' })
Add-Check 'NoBracketedBox' ($boxHits.Count -eq 0) `
    $(if ($boxHits.Count) { ($boxHits | Select-Object -First 8) -join ' · ' } else { 'every decision box resolved and unbracketed' })

# placeholder-coloured runs left behind
$greyHits = @()
$grey = $Rto.styling.placeholderColor
if ($grey) {
    foreach ($f in $recordFiles) {
        $pkg = Open-Docx -Path $f.FullName
        try {
            foreach ($c in $pkg.Xml.SelectNodes("//w:color[@w:val='$grey']", $pkg.Ns)) {
                $run = $c.ParentNode.ParentNode
                $txt = (Get-RunText $run $pkg.Ns).Trim()
                if ($txt) { $greyHits += "$($f.Name): '$txt'" }
            }
        } finally { Close-Docx $pkg }
    }
}
Add-Check 'NoPlaceholderStyling' ($greyHits.Count -eq 0) `
    $(if ($greyHits.Count) { ($greyHits | Select-Object -First 6) -join ' · ' } else { "no run left in the placeholder colour ($grey)" })

# -------------------------------------------------------- 3. unused rows -----

$unused = @()
foreach ($f in $recordFiles) {
    foreach ($r in $rowsOf[$f.Name]) {
        if ($r -match '\[\s*(First name|Surname|ID|S / NYS|C / NYC|date|Tool name|Question / task no\.|Brief explanation|Action required|Insert comments)') {
            $unused += "$($f.Name): $($r.Substring(0, [Math]::Min(70, $r.Length)))"
        }
    }
}
Add-Check 'NoUnusedRows' ($unused.Count -eq 0) `
    $(if ($unused.Count) { ($unused | Select-Object -First 5) -join ' · ' } else { 'every repeating block trimmed to its real length' })

# ------------------------------------------------------- 4. per-SAR checks ---

$tickProblems  = @()
$optionProblems= @()
$overallProbs  = @()
$sarValues     = @{}

foreach ($s in $L.students) {
    $name = $s.sarFile
    if (-not $rowsOf.ContainsKey($name)) { continue }
    $rows = $rowsOf[$name]

    $sawTools = @()
    foreach ($tool in $L.tools) {
        $row = @($rows | Where-Object { $_ -like "*$($tool.name)*" -and $_ -match "[$BOX_E$BOX_T]" }) | Select-Object -First 1
        if (-not $row) { $tickProblems += "${name}: no outcome row for '$($tool.name)'"; continue }
        $sawTools += $tool.name

        $cells = $row -split '\s\|\s'
        # the S and NYS cells are the two whose whole content is a single box
        $boxCells = @($cells | Where-Object { $_.Trim() -eq "$BOX_E" -or $_.Trim() -eq "$BOX_T" })
        $ticked   = @($boxCells | Where-Object { $_.Trim() -eq "$BOX_T" })
        if ($boxCells.Count -ne 2) {
            $tickProblems += "$name / $($tool.name): expected an S and an NYS box, found $($boxCells.Count)"
        } elseif ($ticked.Count -ne 1) {
            $tickProblems += "$name / $($tool.name): $($ticked.Count) of S/NYS ticked — exactly one is required"
        }

        $expectedResult = @($s.results | Where-Object { $_.toolId -eq $tool.id })[0].result
        $sIsTicked = ($boxCells.Count -eq 2 -and $boxCells[0].Trim() -eq "$BOX_T")
        $actual = if ($sIsTicked) { 'S' } else { 'NYS' }
        if ($boxCells.Count -eq 2 -and $actual -ne $expectedResult) {
            $tickProblems += "$name / $($tool.name): document says $actual, ledger says $expectedResult"
        }

        # exactly one feedback option
        $optCount = ([regex]::Matches($row, "$BOX_T\s*(Assessment completed|Assessment not submitted|Please make corrections)")).Count
        if ($optCount -ne 1) {
            $optionProblems += "$name / $($tool.name): $optCount feedback option(s) ticked — exactly one is required"
        }
    }

    # overall certification
    $certRow = @($rows | Where-Object { $_ -like '*is Competent*' }) | Select-Object -First 1
    $isC   = $certRow -match "$BOX_T\s*is Competent"
    $isNyc = $certRow -match "$BOX_T\s*is Not Yet Competent"
    if ($isC -and $isNyc)        { $overallProbs += "${name}: both Competent and Not Yet Competent ticked" }
    elseif (-not $isC -and -not $isNyc) {
        # A withheld result certifies neither, deliberately: there is no result to
        # certify yet. Any other overall with neither box ticked is a real fault.
        if ($s.overall -ne "RW") { $overallProbs += "${name}: neither Competent nor Not Yet Competent ticked" }
    }
    else {
        $shown = if ($isC) { 'C' } else { 'NYC' }
        if ($shown -ne $s.overall) { $overallProbs += "${name}: certifies $shown, ledger says $($s.overall)" }
    }

    $sarValues[$s.studentId] = [pscustomobject]@{ tools = $sawTools; overall = $(if ($isC) { 'C' } else { 'NYC' }) }
}

Add-Check 'OneTickPerToolRow'       ($tickProblems.Count -eq 0)   $(if ($tickProblems.Count) { ($tickProblems | Select-Object -First 6) -join ' · ' } else { 'every tool row carries exactly one of S / NYS, matching the ledger' })
Add-Check 'OneFeedbackOptionPerRow' ($optionProblems.Count -eq 0) $(if ($optionProblems.Count) { ($optionProblems | Select-Object -First 6) -join ' · ' } else { 'every tool row ticks exactly one feedback option' })

# the rule itself, re-derived from the ledger's own per-tool results
$ruleProbs = @()
foreach ($s in $L.students) {
    # RW overrides the S/NYS derivation, so a withheld result is checked against
    # the prerequisite that withheld it rather than against the tool results.
    $shouldBe = if (@($s.results | Where-Object { $_.result -eq "NYS" }).Count -gt 0) { "NYC" } else { "C" }
    if (@($s.prerequisitesNotMet).Count -gt 0) { $shouldBe = "RW" }
    elseif ($s.overall -eq "RW") { $ruleProbs += "$($s.fullName): overall RW but no unmet prerequisite is recorded" }
    if ($s.overall -ne $shouldBe) { $ruleProbs += "$($s.fullName): overall $($s.overall) but tool results give $shouldBe" }
}
Add-Check 'OverallResultRule' (($ruleProbs.Count -eq 0) -and ($overallProbs.Count -eq 0)) `
    $(if ($ruleProbs.Count -or $overallProbs.Count) { (@($ruleProbs) + @($overallProbs) | Select-Object -First 6) -join ' · ' } else { 'any NYS → NYC, all S → C, on every record' })

# --------------------------------------------------- 5. tool names identical --

$toolProbs = @()
foreach ($tool in $L.tools) {
    foreach ($f in $recordFiles) {
        $hay = $textOf[$f.Name] + ' ' + (($rowsOf[$f.Name]) -join ' ')
        # a feedback sheet only names the tools its items belong to
        $isFeedback = $f.Name -like 'FEEDBACK_*'
        if ($isFeedback) { continue }
        if ($hay -notlike "*$($tool.name)*") { $toolProbs += "$($f.Name) does not carry the tool name '$($tool.name)'" }
    }
}
foreach ($f in @($files | Where-Object { $_.Name -like 'FEEDBACK_*' })) {
    foreach ($r in $rowsOf[$f.Name]) {
        if ($r -match '^\d+\s\|\s(.+?)\s\|') {
            $named = $Matches[1].Trim()
            if ($named -and -not (@($L.tools | Where-Object { $_.name -eq $named }).Count)) {
                $toolProbs += "$($f.Name) names a tool '$named' that is not in the ledger"
            }
        }
    }
}
Add-Check 'ToolNamesIdentical' ($toolProbs.Count -eq 0) `
    $(if ($toolProbs.Count) { ($toolProbs | Select-Object -First 6) -join ' · ' } else { "$($L.tools.Count) tool name(s) identical across every document" })

# ----------------------------------------------- 6. cross-document agreement --

$amrrRows = @()
if ($rowsOf.ContainsKey($L.amrrFile)) {
    $amrrRows = @($rowsOf[$L.amrrFile] | Where-Object { $_ -match '^\d+\s\|' })
}
$agree = @()

# Where no marking record was due, its leg of the comparison drops out. The SAR
# and the marked copy still have to agree with each other and with the ledger.
if ($wantAmrr -and $amrrRows.Count -ne $L.students.Count) {
    $agree += "marking record has $($amrrRows.Count) student row(s), ledger has $($L.students.Count)"
}

for ($i = 0; $i -lt [Math]::Min($amrrRows.Count, $L.students.Count); $i++) {
    $s = $L.students[$i]
    $c = $amrrRows[$i] -split '\s*\|\s*'
    # 0 serial, 1 first, 2 surname, 3 id, then one cell per tool, then overall,
    # feedback given, resubmission due, invoice, comments
    $nTools = $L.tools.Count
    if ($c.Count -lt (5 + $nTools)) { $agree += "marking record row $($i+1) has $($c.Count) cells"; continue }

    if ($c[1].Trim() -ne $s.firstName) { $agree += "row $($i+1): first name '$($c[1].Trim())' vs ledger '$($s.firstName)'" }
    if ($c[2].Trim() -ne $s.surname)   { $agree += "row $($i+1): surname '$($c[2].Trim())' vs ledger '$($s.surname)'" }
    if ($c[3].Trim() -ne $s.studentId) { $agree += "row $($i+1): ID '$($c[3].Trim())' vs ledger '$($s.studentId)'" }

    for ($t = 0; $t -lt $nTools; $t++) {
        $want = @($s.results | Where-Object { $_.toolId -eq $L.tools[$t].id })[0].result
        $got  = $c[4 + $t].Trim()
        if ($got -ne $want) { $agree += "row $($i+1) / $($L.tools[$t].name): record says $got, SAR and ledger say $want" }
    }

    $o = 4 + $nTools
    if ($c[$o].Trim()     -ne $s.overall)                    { $agree += "row $($i+1): overall '$($c[$o].Trim())' vs ledger '$($s.overall)'" }
    if ($c[$o+1].Trim()   -ne $L.dates.feedbackGivenText)    { $agree += "row $($i+1): Feedback Given '$($c[$o+1].Trim())' is not the marking date" }
    if ($c[$o+2].Trim()   -ne $s.resubmissionDueText)        { $agree += "row $($i+1): Resubmission Due '$($c[$o+2].Trim())' vs expected '$($s.resubmissionDueText)'" }
    $invoiceShown = ($c[$o+3].Trim() -eq "$BOX_T")
    if ($invoiceShown -ne [bool]$s.invoiceRaised)            { $agree += "row $($i+1): Invoice Raised is $invoiceShown, rule gives $($s.invoiceRaised)" }
    if ($c[$o+4].Trim()   -ne $s.comment)                    { $agree += "row $($i+1): comment '$($c[$o+4].Trim())' vs ledger '$($s.comment)'" }
}

# The feedback sheet's leg is retired with the sheet. Its replacement is page
# one of the marked copy, which every student now has.
foreach ($name in $markedExpected.Keys) {
    if (-not $textOf.ContainsKey($name)) { continue }
    $s    = $markedExpected[$name].student
    $blob = $textOf[$name]
    if ($blob -notlike "*$($s.studentId)*")           { $agree += "$name page one does not carry student ID $($s.studentId)" }
    if ($blob -notlike "*$($s.resubmissionDueText)*") { $agree += "$name page one does not carry resubmission due $($s.resubmissionDueText)" }
}

Add-Check 'CrossDocumentAgreement' ($agree.Count -eq 0) `
    $(if ($agree.Count) { ($agree | Select-Object -First 8) -join ' · ' } else { 'every SAR, its row in the marking record and its feedback sheet agree on every value' })

# ------------------------------------------------------------- 7. dates ------

$dateProbs = @()
foreach ($f in $recordFiles) {
    $hay = $textOf[$f.Name] + ' ' + (($rowsOf[$f.Name]) -join ' ')
    if ($f.Name -like 'FEEDBACK_*') { continue }
    if ($hay -notlike "*$($L.dates.assessmentDateText)*") {
        $dateProbs += "$($f.Name) does not carry the date of assessment $($L.dates.assessmentDateText)"
    }
}
foreach ($s in $L.students) {
    if ($s.overall -eq 'C' -and $s.resubmissionDueText -ne 'N/A') { $dateProbs += "$($s.fullName) is Competent but Resubmission Due is not N/A" }
    if ($s.overall -eq 'NYC' -and $s.resubmissionDueText -eq 'N/A') { $dateProbs += "$($s.fullName) is NYC but has no Resubmission Due date" }
    # A withheld result always carries the date — five working days from the
    # marking date — because that is when the prerequisite question falls due,
    # whether or not the student also has work to redo.
    if ($s.overall -eq 'RW' -and $s.resubmissionDueText -ne $L.dates.resubmissionDueText) {
        $dateProbs += "$($s.fullName) is RW but Resubmission Due reads '$($s.resubmissionDueText)', not $($L.dates.resubmissionDueText)"
    }
}
if ($L.dates.feedbackGivenText -ne $L.dates.markingDateText) { $dateProbs += 'Feedback Given is not the marking date' }

Add-Check 'DateRules' ($dateProbs.Count -eq 0) `
    $(if ($dateProbs.Count) { ($dateProbs | Select-Object -First 6) -join ' · ' } else { "assessment $($L.dates.assessmentDateText), feedback given $($L.dates.feedbackGivenText), resubmission $($L.dates.resubmissionDueText)" })

# ----------------------------------------------------------- 8. invoicing ----

$invProbs = @()
foreach ($s in $L.students) {
    $should = ($s.overall -eq 'NYC' -and $s.attempt -ge 2)
    if ([bool]$s.invoiceRaised -ne $should) { $invProbs += "$($s.fullName): invoice $($s.invoiceRaised), rule gives $should (attempt $($s.attempt), $($s.overall))" }
    if (-not $rowsOf.ContainsKey($s.sarFile)) { continue }
    $adminRow = @($rowsOf[$s.sarFile] | Where-Object { $_ -like '*Resit invoice raised*' }) | Select-Object -First 1
    if ($adminRow) {
        $raised = $adminRow -match "$BOX_T\s*Resit invoice raised"
        $na     = $adminRow -match "$BOX_T\s*Not applicable"
        if ($raised -eq $na)          { $invProbs += "$($s.sarFile): the admin note ticks both or neither of the invoice options" }
        elseif ($raised -ne $should)  { $invProbs += "$($s.sarFile): admin note says invoice raised = $raised, rule gives $should" }
    }
}
Add-Check 'InvoiceRule' ($invProbs.Count -eq 0) `
    $(if ($invProbs.Count) { ($invProbs | Select-Object -First 6) -join ' · ' } else { 'invoice ticked only where NYC after the second attempt' })

# --------------------------------------------------- 9. no-submission text ---

$nsProbs = @()
foreach ($s in $L.students) {
    # A WITHHELD RESULT OWNS THE COMMENT COLUMN. The resolver replaces whatever
    # the comment would otherwise have said with the standing withheld wording,
    # so that it reads identically for every RW student in the class, and the
    # WithheldComment check below holds it to exactly that text. A student who
    # both submitted nothing AND does not hold the prerequisite would otherwise
    # be caught between two rules that cannot both be satisfied — this one
    # demanding 'No submission', that one demanding the withheld wording. RW
    # wins, because the missing prerequisite is the reason the result cannot be
    # issued at all; that they also submitted nothing is recorded on their tool
    # rows and on their feedback sheet.
    if ("$($s.overall)" -eq 'RW') { continue }
    $none = (@($s.results | Where-Object { -not $_.submitted }).Count -eq @($s.results).Count)
    if ($none -and $s.comment -ne 'No submission') { $nsProbs += "$($s.fullName) submitted nothing but the comment reads '$($s.comment)'" }
    if (-not $none -and $s.comment -eq 'No submission') { $nsProbs += "$($s.fullName) submitted work but the comment reads 'No submission'" }
}
# ---- was the class reconciled against the roll? ----------------------------
#
# Every other check here compares the ledger to the documents built from it, so
# none of them can see a student who was never in the ledger. Only the roll can.
# Where no roll was supplied this is a WARN, not a failure: a marking run can
# legitimately be given the student list directly.
if ($L.PSObject.Properties.Name.Contains('roll') -and $L.roll) {
    Add-Check 'RollReconciled' ($L.roll.missingCount -eq 0) `
        $(if ($L.roll.missingCount -gt 0) { "$($L.roll.missingCount) student(s) on the roll have no ledger entry" } else { "$($L.roll.matched) of $($L.roll.requiredCount) required by $($L.roll.source) are in the ledger" })
} else {
    # $false with -Warn, not $true: this is the OpensInWord pattern. A check that
    # did not run reports as a WARN, never as a pass, so 'nobody looked' cannot
    # read as 'nothing wrong'. It does not block delivery.
    Add-Check 'RollReconciled' $false 'no roll was supplied, so nothing has confirmed this class is the whole class. Re-run Resolve-MarkingLedger.ps1 with -Roll to check it against the WiseNet matrix.' -Warn
}

Add-Check 'NoSubmissionComment' ($nsProbs.Count -eq 0) `
    $(if ($nsProbs.Count) { ($nsProbs -join ' · ') } else { 'every non-submission carries exactly "No submission"' })

# ---- the withheld comment, read off the delivered marking record ------------
#
# Sibling of the check above. The string is approved RTO wording held once in
# Lib-Text.ps1, and a stray edit to its spacing must not reach a record — so the
# delivered row is compared to the constant, not to the ledger's copy of it.
. (Join-Path $PSScriptRoot 'Lib-Text.ps1')
$withheld = Get-WithheldComment
$wcProbs = @()
foreach ($s in $L.students) {
    if ($s.overall -eq 'RW' -and $s.comment -ne $withheld) {
        $wcProbs += "$($s.fullName) is RW but the ledger comment reads '$($s.comment)'"
    }
    if ($s.overall -ne 'RW' -and $s.comment -eq $withheld) {
        $wcProbs += "$($s.fullName) is $($s.overall) but carries the withheld comment"
    }
}
if ($wantAmrr -and $rowsOf.ContainsKey($L.amrrFile)) {
    foreach ($s in @($L.students | Where-Object { $_.overall -eq 'RW' })) {
        $row = @($rowsOf[$L.amrrFile] | Where-Object { $_ -like "*$($s.studentId)*" }) | Select-Object -First 1
        if ($row -and $row -notlike "*$withheld*") {
            $wcProbs += "the marking record row for $($s.studentId) does not carry the withheld comment exactly"
        }
    }
}
Add-Check 'WithheldComment' ($wcProbs.Count -eq 0) `
    $(if ($wcProbs.Count) { ($wcProbs | Select-Object -First 5) -join ' · ' } else { "every withheld result reads exactly `"$withheld`"" })

# ---------------------------------------- 10. the feedback page -------------
#
# Replaces FeedbackSheetPerNyc. The sheet was built only for NYC students; the
# page is built for EVERY student, so a Competent student is told what they did
# rather than being told nothing. FeedbackSheetOnePage is retired with it: page
# one may run past one physical page, and what matters is the page break before
# the student's own content, which MarkedCopyFeedbackPage checks.

$fbProbs = @()
$maxItems = $Rto.templates.feedback.itemTable.maxItems
# The page's title is the RTO's own Student Feedback Sheet title, so the gate
# reads it from the profile rather than carrying a copy of the words.
$fbPageTitle = if ($Rto.markedAssessment -and $Rto.markedAssessment.feedbackPage -and $Rto.markedAssessment.feedbackPage.title) {
    "$($Rto.markedAssessment.feedbackPage.title)"
} else { 'ASSESSMENT FEEDBACK' }
foreach ($name in $markedExpected.Keys) {
    if (-not $textOf.ContainsKey($name)) { continue }
    $exp  = $markedExpected[$name]
    $s    = $exp.student
    $blob = $textOf[$name]

    if ($blob -notlike "*$fbPageTitle*") { $fbProbs += "$name carries no feedback page heading" }

    # every tool's feedback, in the student's own copy
    foreach ($res in @($exp.results)) {
        if (-not $res) { continue }
        $probe = "$($res.feedback)"
        if ($probe.Length -gt 40) { $probe = $probe.Substring(0, 40) }
        if ($probe -and $blob -notlike "*$probe*") {
            $fbProbs += "$name does not carry the feedback for '$($res.toolName)'"
        }
    }
    # and the items to correct, capped
    $items = @(foreach ($res in @($exp.results)) { if ($res) { @($res.items) } })
    $items = @($items | Where-Object { $_ })
    $shown = [Math]::Min($items.Count, $maxItems)
    for ($i = 0; $i -lt $shown; $i++) {
        $q = "$($items[$i].questionNo)"
        if ($q -and $blob -notlike "*$q*") { $fbProbs += "$name does not list the item '$q'" }
    }
    if ($items.Count -gt $maxItems -and $blob -notlike '*are marked in your returned assessment*') {
        $fbProbs += "$name lists $maxItems of $($items.Count) items but carries no closing note for the rest"
    }
}
Add-Check 'FeedbackPageEveryStudent' ($fbProbs.Count -eq 0) `
    $(if ($fbProbs.Count) { ($fbProbs | Select-Object -First 6) -join ' · ' } else { "$($markedExpected.Count) marked copy/copies, each carrying its own feedback page" })

# ---- the standalone sheet, for a student with nothing coming back -----------
#
# Same content as page one, in the RTO's own template. This is the ONLY copy of
# their feedback that reaches the student, so it is checked as carefully as the
# page: their name, their ID, the result, the date they must resubmit by, and
# every item they have to fix.
$fbSheetProbs = @()
foreach ($name in $feedbackExpected.Keys) {
    if (-not $textOf.ContainsKey($name)) { continue }
    $s    = $feedbackExpected[$name]
    $blob = $textOf[$name]

    foreach ($must in @($s.fullName, $s.studentId, $s.resubmissionDueText)) {
        if ("$must" -and $blob -notlike "*$must*") { $fbSheetProbs += "${name}: does not carry '$must'" }
    }
    if ($blob -notlike "*$($s.overall)*") { $fbSheetProbs += "${name}: does not carry the overall result $($s.overall)" }

    $items = @(foreach ($res in @($s.results)) { @($res.items) })
    $items = @($items | Where-Object { $_ })
    $shown = [Math]::Min($items.Count, $maxItems)
    for ($i = 0; $i -lt $shown; $i++) {
        $q = "$($items[$i].questionNo)"
        $a = "$($items[$i].action)"
        if ($a.Length -gt 40) { $a = $a.Substring(0, 40) }
        if ($q -and $blob -notlike "*$q*") { $fbSheetProbs += "${name}: does not list the item '$q'" }
        if ($a -and $blob -notlike "*$a*") { $fbSheetProbs += "${name}: lists an item without what the student must do" }
    }

    # The result is colour coded on the sheet, the same three colours the marked
    # copy uses. Read the run that carries the letters, off the delivered file.
    $pkgFb = Open-Docx -Path (Join-Path $dirFull $name)
    try {
        $wantCol =
            switch ($s.overall) {
                'C'  { $Rto.markedAssessment.satisfactoryColor }
                'RW' { $Rto.styling.resultWithheldColor }
                default { $Rto.markedAssessment.notSatisfactoryColor }
            }
        $seen = $false
        foreach ($para in @(Get-BodyParagraphs $pkgFb)) {
            if ((Get-RunText $para $pkgFb.Ns).Trim() -ne "$($s.overall)") { continue }
            $col = $para.SelectSingleNode('.//w:rPr/w:color', $pkgFb.Ns)
            $val = if ($col) { $col.GetAttribute('val', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main') } else { '' }
            $seen = $true
            if ($val -ne $wantCol) { $fbSheetProbs += "${name}: the overall result reads colour '$val', not $wantCol" }
        }
        if (-not $seen) { $fbSheetProbs += "${name}: no cell carries the overall result on its own" }
    } finally { Close-Docx $pkgFb }
}
Add-Check 'FeedbackSheetIssued' ($fbSheetProbs.Count -eq 0) `
    $(if ($fbSheetProbs.Count) { ($fbSheetProbs | Select-Object -First 5) -join ' · ' } else { $(if ($feedbackExpected.Count) { "$($feedbackExpected.Count) student(s) with nothing to return, each issued a standalone feedback sheet" } else { 'every student has a marked copy, so the feedback is on page one of it' }) })

# ---- the assessment cover sheet is filled -----------------------------------
#
# The cover sheet is the first page an auditor turns to and half its fields are
# the RTO's to complete. A returned assessment whose Trainer / Assessor line is
# blank records that nobody was responsible for marking it. Read off the
# delivered file: every label on the sheet, and whether anything answers it.
$coverProbs = @()
if ($L.PSObject.Properties.Name.Contains('coverSheet') -and $L.coverSheet) {
    foreach ($name in $markedExpected.Keys) {
        $path = Join-Path $dirFull $name
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $pkg = Open-Docx -Path $path
        try {
            $ns    = $pkg.Ns
            $paras = @(Get-BodyParagraphs $pkg)
            $startAt = -1
            for ($i = 0; $i -lt $paras.Count; $i++) {
                if ((Get-RunText $paras[$i] $ns).IndexOf("$($L.coverSheet.anchor)", [StringComparison]::OrdinalIgnoreCase) -ge 0) { $startAt = $i; break }
            }
            if ($startAt -lt 0) { $coverProbs += "${name}: no cover sheet at '$($L.coverSheet.anchor)'"; continue }

            $endAt = $paras.Count
            if ($L.coverSheet.PSObject.Properties.Name.Contains('endAnchor') -and $L.coverSheet.endAnchor) {
                for ($i = $startAt + 1; $i -lt $paras.Count; $i++) {
                    if ((Get-RunText $paras[$i] $ns).IndexOf("$($L.coverSheet.endAnchor)", [StringComparison]::OrdinalIgnoreCase) -ge 0) { $endAt = $i; break }
                }
            }

            $pIndex = @{}
            for ($i = 0; $i -lt $paras.Count; $i++) { $pIndex[$paras[$i]] = $i }

            $ownTable = Get-ParagraphTable $paras[$startAt]
            $seenRow  = $false
            foreach ($tbl in @(Get-Tables $pkg)) {
                $isOwn = ($ownTable -is [System.Xml.XmlElement] -and $tbl.Equals($ownTable))
                if (-not $isOwn) {
                    $firstPara = $tbl.SelectSingleNode('.//w:p', $ns)
                    if (-not $firstPara -or -not $pIndex.ContainsKey($firstPara)) { continue }
                    $tAt = $pIndex[$firstPara]
                    if ($tAt -lt $startAt -or $tAt -ge $endAt) { continue }
                }
                foreach ($tr in @(Get-Rows $tbl $ns)) {
                    $cells = @(Get-Cells $tr $ns)
                    $texts = @($cells | ForEach-Object { ((("$($_.InnerText)") -replace '\s+', ' ').Trim()) })
                    for ($i = 0; $i -lt $texts.Count; $i++) {
                        if (-not $texts[$i].EndsWith(':')) { continue }
                        $seenRow = $true
                        if ($i -lt ($texts.Count - 1)) {
                            if (-not $texts[$i + 1]) { $coverProbs += "${name}: '$($texts[$i])' has no value" }
                        } else {
                            $coverProbs += "${name}: '$($texts[$i])' has no value"
                        }
                    }
                }
            }
            if (-not $seenRow) { $coverProbs += "${name}: the cover sheet carries no labelled field, so nothing could be checked" }
        } finally { Close-Docx $pkg }
    }
}
Add-Check 'CoverSheetFilled' ($coverProbs.Count -eq 0) `
    $(if ($coverProbs.Count) { ($coverProbs | Select-Object -First 5) -join ' · ' } else { $(if ($L.coverSheet) { "every field on every returned cover sheet carries a value" } else { 'the ledger names no cover sheet, so none was filled or checked' }) })

# ---- the withheld-result notice --------------------------------------------
$rwProbs = @()
$noticeHead = 'ASSESSMENT OUTCOME: RESULT WITHHELD'
foreach ($name in $markedExpected.Keys) {
    if (-not $textOf.ContainsKey($name)) { continue }
    $s    = $markedExpected[$name].student
    $blob = $textOf[$name]
    $has  = ($blob -like "*$noticeHead*")
    if ($s.overall -eq 'RW') {
        if (-not $has) { $rwProbs += "$name is an RW student's copy but carries no withheld-result notice" }
        else {
            foreach ($p in @($s.prerequisitesNotMet)) {
                if ($blob -notlike "*$($p.code)*") { $rwProbs += "$name notice does not name the prerequisite $($p.code)" }
            }
            if ($blob -match '\{[A-Z]+\}' -or $blob -match '\[[A-Z][A-Za-z /]+\]') {
                $rwProbs += "$name notice still carries an unfilled field"
            }
        }
    } elseif ($has) {
        $rwProbs += "$name is $($s.overall) but carries the withheld-result notice"
    }
}
Add-Check 'RwNoticePresent' ($rwProbs.Count -eq 0) `
    $(if ($rwProbs.Count) { ($rwProbs | Select-Object -First 5) -join ' · ' } else { "$(@($L.students | Where-Object { $_.overall -eq 'RW' }).Count) withheld result(s), each with the notice and its prerequisite named" })

# ---- resubmissions stack ----------------------------------------------------
# A file at attempt N carries N feedback pages, newest first. Nothing from an
# earlier attempt is altered — the marked file IS the audit trail of every
# attempt, and an overwritten attempt 1 cannot be recovered from it.
$stackProbs = @()
foreach ($name in $markedExpected.Keys) {
    if (-not $textOf.ContainsKey($name)) { continue }
    $mc  = $markedExpected[$name].copy
    $att = if ($mc.attempt) { [int]$mc.attempt } else { 1 }
    # An earlier attempt's page was written by whatever this skill titled the
    # page on the day it was marked, and that file is not ours to rewrite: it is
    # the audit trail of that attempt. So a page counts under the current title
    # or under the one it replaced.
    $anyTitle = '(?:' + [regex]::Escape($fbPageTitle) + '|ASSESSMENT FEEDBACK)'
    $pages = ([regex]::Matches($textOf[$name], ($anyTitle + ' — Attempt \d+'))).Count
    if ($pages -ne $att) {
        $stackProbs += "$name is attempt $att but carries $pages feedback page(s); each attempt keeps its own"
    }
    if ($att -ge 2 -and $textOf[$name] -notmatch ($anyTitle + ' — Attempt 1')) {
        $stackProbs += "$name is attempt $att but the attempt 1 page is missing"
    }
}
Add-Check 'ResubmissionStacked' ($stackProbs.Count -eq 0) `
    $(if ($stackProbs.Count) { ($stackProbs | Select-Object -First 5) -join ' · ' } else { 'every marked copy carries one feedback page per attempt, newest first' })

# --------------------------------------------- 11. template parts untouched --

$partProbs = @()
foreach ($kind in @('sar','amrr','feedback')) {
    $tplRel = $Rto.templates.$kind.file
    if (-not $tplRel) { continue }
    $tpl = Join-Path $AssetRoot $tplRel
    if (-not (Test-Path -LiteralPath $tpl)) { continue }

    $tplPkg = Open-Docx -Path $tpl
    # Take the prefix from the FILESYSTEM, not from the string we built. Where
    # %TEMP% is an 8.3 short path ('ACI-AD~1') Get-ChildItem still returns the
    # expanded name ('ACI-Admin'), so subtracting the constructed path's length
    # leaves a stray character on the front of every part name and this check
    # reports parts as removed that were never touched.
    $tplBase = (Get-Item -LiteralPath $tplPkg.Work).FullName.TrimEnd('\')
    $tplParts = @{}
    foreach ($p in Get-ChildItem -Recurse -File -LiteralPath $tplPkg.Work) {
        $rel = $p.FullName.Substring($tplBase.Length).TrimStart('\')
        if ($rel -eq 'word\document.xml') { continue }
        if ($rel -like 'docProps\*')      { continue }   # Word rewrites these
        $tplParts[$rel] = (Get-FileHash -LiteralPath $p.FullName -Algorithm SHA256).Hash
    }
    Close-Docx $tplPkg

    $sample = switch ($kind) {
        'sar'      { @($files | Where-Object { $_.Name -like 'SAR_*' }) }
        'amrr'     { @($files | Where-Object { $_.Name -eq $L.amrrFile }) }
        'feedback' { @($files | Where-Object { $_.Name -like 'FEEDBACK_*' }) }
    }
    foreach ($f in $sample) {
        $pkg = Open-Docx -Path $f.FullName
        try {
            foreach ($rel in $tplParts.Keys) {
                $out = Join-Path $pkg.Work $rel
                if (-not (Test-Path -LiteralPath $out)) { $partProbs += "$($f.Name): part '$rel' was removed"; continue }
                $h = (Get-FileHash -LiteralPath $out -Algorithm SHA256).Hash
                if ($h -ne $tplParts[$rel]) { $partProbs += "$($f.Name): part '$rel' was modified" }
            }
        } finally { Close-Docx $pkg }
    }
}
Add-Check 'TemplateUntouched' ($partProbs.Count -eq 0) `
    $(if ($partProbs.Count) { ($partProbs | Select-Object -First 6) -join ' · ' } else { 'headers, footers, styles, numbering and relationships byte-identical to the approved templates' })

# ---------------------------------------------- 11b. the marked copies -------
#
# The marked copy is what the student actually reads. It must carry one outcome
# line per question, in the right colour, and an overall result matching the
# SAR. A green Satisfactory above a red NYC is two records of one judgement
# contradicting each other in the student's hands.

$markProbs = @()
$M = $Rto.markedAssessment
if ($M) {
    foreach ($name in $markedExpected.Keys) {
        $path = Join-Path $dirFull $name
        if (-not (Test-Path -LiteralPath $path)) { continue }   # presence is SarPerStudent's job

        $exp = $markedExpected[$name]

        # A resubmission STACKS: a file at attempt 2 still carries attempt 1's
        # lines, untouched, because the marked file is the audit trail of every
        # attempt. So this check counts only what THIS attempt wrote, which the
        # builder prefixes for exactly that purpose.
        $att = if ($exp.copy.attempt) { [int]$exp.copy.attempt } else { 1 }
        $pfx = if ($att -ge 2) { "Attempt ${att}: " } else { '' }

        # Summed ACROSS EVERY TOOL in the file. One document carrying UAT 1 and
        # UAT 2 gets one marked copy, so the counts it must show are both tools'
        # counts added together — checking either alone passes a copy that is
        # missing half its marking.
        $wantObs = 0; $wantS = 0; $wantNys = 0; $wantObsBlocks = 0
        foreach ($res in @($exp.results)) {
            $o = Get-Count $res.observations
            $wantObs += $o
            $wantS   += (Get-Count @($res.questions | Where-Object { $_.outcome -eq 'S' }))
            $wantNys += (Get-Count @($res.questions | Where-Object { $_.outcome -eq 'NYS' }))
            # A TASK carries its own outcome line, the same way a question does.
            # Counting only questions and observation records made every task
            # line the builder writes look like a line nobody asked for.
            $wantS   += (Get-Count @($res.tasks | Where-Object { $_.outcome -eq 'S' }))
            $wantNys += (Get-Count @($res.tasks | Where-Object { $_.outcome -eq 'NYS' }))
            # And so does every CRITERION ROW of a performance checklist, in the
            # comments cell the instrument provides. The ledger records how many
            # rows were judged because the count varies with the instrument —
            # some activities carry three criteria, some a dozen.
            if ($res.PSObject.Properties.Name -contains 'checklistRowsMarked') {
                if ($res.result -eq 'S') { $wantS += [int]$res.checklistRowsMarked }
                else { $wantNys += [int]$res.checklistRowsMarked }
            }
            # An observation record carries ONE outcome line of its own, for the
            # tool as a whole, on top of any per-question lines.
            if ($o -gt 0) {
                $wantObsBlocks++
                if ($res.result -eq 'S') { $wantS++ } else { $wantNys++ }
            }
        }

        $pkg = Open-Docx -Path $path
        try {
            $gotS = 0; $gotNys = 0; $overallSeen = $null
            $overallAlign = $null; $obsHeading = 0; $obsPoints = 0; $obsCompleted = 0
            # Count observation points only BETWEEN the heading and the
            # completed-on line. The student's own submission may use the same
            # bullet - a cover sheet declaration usually does - and counting
            # document-wide reads those as assessor observation points.
            $inObs = $false
            $bullet = "$($M.observationBullet)"
            foreach ($para in $pkg.Body.SelectNodes('.//w:p', $pkg.Ns)) {
                $txt = (Get-RunText $para $pkg.Ns).Trim()
                if ($txt -eq '') { continue }
                # THE RUN'S COLOUR, NOT THE PARAGRAPH MARK'S. A paragraph can
                # carry a w:pPr/w:rPr/w:color describing the pilcrow, and it
                # comes first in document order — so './/w:rPr/w:color' returned
                # that instead of the colour the words are actually painted in,
                # and an outcome line added inside a table cell went uncounted.
                $colNode = $para.SelectSingleNode('.//w:r/w:rPr/w:color', $pkg.Ns)
                $col = if ($colNode) { $colNode.GetAttribute('val', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main') } else { '' }

                # An outcome line is one this build INSERTED, and it is
                # identified by its words AND its colour together. The words
                # alone do not identify one: an assessment workbook may print
                # 'Satisfactory' as a checklist column heading, and a learner
                # may type it into the cells under that heading — in this unit
                # one did, nineteen times, in the workbook's own heading colour.
                # Counting those reads the student's document as assessor
                # judgements: an off-by-one on every copy, worse where a learner
                # filled the checklist in.
                #
                # An inserted line that lost its colour is therefore not counted
                # here. That does not hide it — the count below then falls short
                # of the ledger and this check fails, which is exactly what it
                # exists to do. Every failure the old text-only test could catch
                # is still caught; what is gone is a false positive on the
                # submission's own words.
                if ($txt -eq ($pfx + $M.satisfactoryText) -and $col -eq $M.satisfactoryColor) {
                    $gotS++
                }
                elseif ($txt -eq ($pfx + $M.notSatisfactoryText) -and $col -eq $M.notSatisfactoryColor) {
                    $gotNys++
                }
                elseif ($txt -eq $M.overallCompetentText -or $txt -eq $M.overallNotCompetentText -or ($M.overallWithheldText -and $txt -eq $M.overallWithheldText)) {
                    $overallSeen =
                        if     ($txt -eq $M.overallCompetentText) { 'C' }
                        elseif ($M.overallWithheldText -and $txt -eq $M.overallWithheldText) { 'RW' }
                        else   { 'NYC' }
                    $jc = $para.SelectSingleNode('w:pPr/w:jc', $pkg.Ns)
                    $overallAlign = if ($jc) { $jc.GetAttribute('val', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main') } else { 'left' }
                    $wantCol =
                        switch ($overallSeen) {
                            'C'  { $M.satisfactoryColor }
                            'RW' { $Rto.styling.resultWithheldColor }
                            default { $M.notSatisfactoryColor }
                        }
                    if ($col -ne $wantCol) { $markProbs += "${name}: the overall result is colour $col, not $wantCol" }
                }
                # StartsWith, not equals: a record on the declaration page names
                # the tool after the heading, because a file can carry more than
                # one and two identical headings would say nothing about which
                # observation each belongs to.
                # Only THIS attempt's records are counted. An earlier attempt's
                # block is still in the file and must stay there.
                elseif ($M.observationHeading -and $txt.StartsWith($pfx + $M.observationHeading)) { $obsHeading++; $inObs = $true }
                elseif ($M.observationHeading -and $txt.StartsWith($M.observationHeading))        { $inObs = $false }
                elseif ($inObs -and $bullet -and $txt.StartsWith($bullet))                        { $obsPoints++ }
                elseif ($M.observationCompletedText -and $txt.StartsWith($pfx + $M.observationCompletedText)) { $obsCompleted++; $inObs = $false }
                elseif ($M.observationCompletedText -and $txt.StartsWith($M.observationCompletedText))        { $inObs = $false }
            }

            if ($gotS -ne $wantS)     { $markProbs += "${name}: $gotS Satisfactory line(s), ledger has $wantS" }
            if ($gotNys -ne $wantNys) { $markProbs += "${name}: $gotNys Not yet Satisfactory line(s), ledger has $wantNys" }
            if (-not $overallSeen)    { $markProbs += "${name}: no overall result on the front page" }
            elseif ($overallSeen -ne $exp.student.overall) {
                $markProbs += "${name}: front page says $overallSeen, the SAR certifies $($exp.student.overall)"
            }
            # The overall result belongs in the TOP RIGHT corner. Left-aligned is
            # a layout regression nothing else here would notice.
            if ($overallSeen -and $overallAlign -ne 'right') {
                $markProbs += "${name}: the overall result is aligned '$overallAlign', not right"
            }

            if ($wantObs -gt 0) {
                if ($obsHeading -ne $wantObsBlocks) { $markProbs += "${name}: $obsHeading observation heading(s), ledger has $wantObsBlocks observation tool(s)" }
                if ($obsPoints -ne $wantObs)        { $markProbs += "${name}: $obsPoints observation point(s), ledger has $wantObs" }
                if ($obsCompleted -ne $wantObsBlocks) { $markProbs += "${name}: $obsCompleted of $wantObsBlocks observation record(s) state the date the assessor completed them" }
            } elseif ($obsHeading -gt 0) {
                $markProbs += "${name}: carries an observation record the ledger does not record"
            }
        } finally { Close-Docx $pkg }
    }
}
Add-Check 'MarkedCopyOutcomes' ($markProbs.Count -eq 0) `
    $(if ($markProbs.Count) { ($markProbs | Select-Object -First 6) -join ' · ' } else { $(if ($markedExpected.Count) { "$($markedExpected.Count) marked copy/copies: every question carries its outcome in the right colour, and each front page matches its SAR" } else { 'no per-question outcomes in the ledger, so no marked copies were expected' }) })

# ------------------------------- 11b-ii. front block sits on the content ------
#
# The front block is body-level content and lands on the section's text margin,
# while the student's own content sits wherever its tables put it. Those are
# rarely the same edge. Nothing above would notice: the words are right, the
# colours are right, and the block is simply out of line with every page
# beneath it.
#
# So compare the block's edges with the student's own first table, in twips
# from the page edge, and require them to be equal. Both come from the
# finished file — and the student's table is the first one BELOW the page
# break, because the first one above it is the feedback sheet the builder
# just added. Measuring that would only ask whether the sheet agrees with
# itself.
#
# The block is now mostly tables — the sheet is a table, as the RTO's own
# standalone sheet is — so both are checked: paragraphs by their w:ind, tables
# by their w:tblInd and the width their grid actually adds up to.

$alignProbs = @()
$wNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
if ($M) {
    foreach ($name in $markedExpected.Keys) {
        $path = Join-Path $dirFull $name
        if (-not (Test-Path -LiteralPath $path)) { continue }

        $exp = $markedExpected[$name]

        $pkg = Open-Docx -Path $path
        try {
            # The declaration page runs to its page break, so the break is what
            # bounds the block rather than an element count this script would
            # otherwise have to keep in step with the builder by hand.
            $kids  = @($pkg.Body.ChildNodes)
            $brkAt = -1
            for ($i = 0; $i -lt $kids.Count; $i++) {
                if ($kids[$i].LocalName -eq 'p' -and (Test-ParagraphIsPageBreak -Paragraph $kids[$i] -Ns $pkg.Ns)) { $brkAt = $i; break }
            }
            if ($brkAt -lt 0) {
                $alignProbs += "${name}: no page break closes the declaration page, so it is not on a page of its own"
                continue
            }

            $box = Get-BodyContentBox -Pkg $pkg -After $kids[$brkAt]
            if (-not $box) { continue }        # nothing measurable, nothing claimed

            $line = 0
            for ($i = 0; $i -lt $brkAt; $i++) {
                $node = $kids[$i]
                if ($node.LocalName -eq 'p') {
                    $line++
                    $ind = $node.SelectSingleNode('w:pPr/w:ind', $pkg.Ns)
                    $gotL = if ($ind) { [int]$ind.GetAttribute('left',  $wNs) } else { 0 }
                    $gotR = if ($ind) { [int]$ind.GetAttribute('right', $wNs) } else { 0 }
                    if ($gotL -ne $box.IndentLeft -or $gotR -ne $box.IndentRight) {
                        $alignProbs += "${name}: front block line $line is indented L$gotL R$gotR, the content sits at L$($box.IndentLeft) R$($box.IndentRight)"
                        break
                    }
                }
                elseif ($node.LocalName -eq 'tbl') {
                    $line++
                    $tin  = $node.SelectSingleNode('w:tblPr/w:tblInd', $pkg.Ns)
                    $gotL = if ($tin) { [int]$tin.GetAttribute('w', $wNs) } else { 0 }
                    $grid = $node.SelectSingleNode('w:tblGrid', $pkg.Ns)
                    $gotW = 0
                    if ($grid) {
                        $gotW = (@($grid.SelectNodes('w:gridCol', $pkg.Ns)) |
                                    ForEach-Object { [int]$_.GetAttribute('w', $wNs) } |
                                    Measure-Object -Sum).Sum
                    }
                    if ($gotL -ne $box.IndentLeft) {
                        $alignProbs += "${name}: front block table $line is indented L$gotL, the content sits at L$($box.IndentLeft)"
                        break
                    }
                    if ($gotW -ne $box.TableWidth) {
                        $alignProbs += "${name}: front block table $line draws $gotW wide, the content draws $($box.TableWidth)"
                        break
                    }
                }
            }
        } finally { Close-Docx $pkg }
    }
}
Add-Check 'MarkedCopyFrontBlockAligned' ($alignProbs.Count -eq 0) `
    $(if ($alignProbs.Count) { ($alignProbs | Select-Object -First 4) -join ' · ' } else { $(if ($markedExpected.Count) { 'every front block sits on the same left and right edge as the content below it' } else { 'no marked copies were expected' }) })

# ------------------------- 11b-iii. the outcome sits IN the answer -----------
#
# The judgement belongs inside the response box, under the answer it judges.
# The failure this catches is quiet and specific: the line lands on the empty
# spacer paragraph BELOW the answer table instead of in the last cell of it.
# Every word is right, every colour is right, the student's eye goes to the box
# and finds nothing there.
#
# Two things are required of every outcome line, and both are read off the
# finished file:
#
#   * the paragraph immediately before it is not empty — an outcome under a
#     blank line is an outcome under nothing;
#   * it sits in the same container as that paragraph — the same table cell
#     where the answer is in a box, the body where the answer is loose text.
#
# The second is guaranteed by construction today, because Add-ParagraphAfter
# inserts as a sibling. It is checked anyway: the guarantee is a property of one
# helper, and this is the gate that would notice if that ever changed.

$spaceProbs = @()
$looseLines = 0
if ($M) {
    foreach ($name in $markedExpected.Keys) {
        $path = Join-Path $dirFull $name
        if (-not (Test-Path -LiteralPath $path)) { continue }

        $pkg = Open-Docx -Path $path
        try {
            $paras = @(Get-BodyParagraphs $pkg)
            for ($i = 0; $i -lt $paras.Count; $i++) {
                $txt = (Get-RunText $paras[$i] $pkg.Ns).Trim()
                if ($txt -ne $M.satisfactoryText -and $txt -ne $M.notSatisfactoryText) { continue }
                # Same rule as the outcome count above: a line this build
                # inserted carries the outcome colour, so the same words in any
                # other colour are the submission's own — a checklist column
                # heading, or a cell a learner typed it into. Judging where
                # those 'sit' reports the workbook's own layout as a marking
                # fault.
                $cNode = $paras[$i].SelectSingleNode('.//w:rPr/w:color', $pkg.Ns)
                if (-not $cNode) { continue }
                $cVal = $cNode.GetAttribute('val', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
                if ($cVal -ne $M.satisfactoryColor -and $cVal -ne $M.notSatisfactoryColor) { continue }
                if ($i -eq 0) { $spaceProbs += "${name}: an outcome line is the first paragraph in the document"; continue }

                $prev = $paras[$i - 1]
                if ([string]::IsNullOrWhiteSpace((Get-RunText $prev $pkg.Ns))) {
                    $spaceProbs += "${name}: an outcome line sits under an empty paragraph, not under an answer"
                    continue
                }
                $hereCell = Get-ParagraphCell $paras[$i]
                $prevCell = Get-ParagraphCell $prev
                if ($null -eq $hereCell -and $null -eq $prevCell) { $looseLines++; continue }
                if ($null -eq $hereCell -or $null -eq $prevCell -or -not $hereCell.Equals($prevCell)) {
                    $spaceProbs += "${name}: an outcome line is not in the same response box as the answer above it"
                }
            }
        } finally { Close-Docx $pkg }
    }
}
Add-Check 'MarkedCopyInAnswerSpace' ($spaceProbs.Count -eq 0) `
    $(if ($spaceProbs.Count) { ($spaceProbs | Select-Object -First 4) -join ' · ' } else { $(if ($markedExpected.Count) { "every outcome line sits directly under the answer it judges$(if ($looseLines) { ", $looseLines of them in body text where the submission has no response box" })" } else { 'no marked copies were expected' }) })

# ------------------- 11b-iv. the declaration is a page of its own ------------
#
# The result goes on a page in front of the student's own first page, not on top
# of their cover sheet. The cover sheet is theirs: their name, their signature,
# their declaration that the work is their own. Crowding a result onto it
# competes with their own heading and leaves neither room to be read.
#
# Checked on the finished file rather than trusted from the build: the page
# break must be there, and the student's own first paragraph must come after it.

$pageProbs = @()
if ($M) {
    foreach ($name in $markedExpected.Keys) {
        $path = Join-Path $dirFull $name
        if (-not (Test-Path -LiteralPath $path)) { continue }

        $pkg = Open-Docx -Path $path
        try {
            $bodyParas = @($pkg.Body.SelectNodes('./w:p', $pkg.Ns))
            $breakAt = -1
            for ($i = 0; $i -lt $bodyParas.Count; $i++) {
                if (Test-ParagraphIsPageBreak -Paragraph $bodyParas[$i] -Ns $pkg.Ns) { $breakAt = $i; break }
            }
            if ($breakAt -lt 0) {
                $pageProbs += "${name}: the declaration carries no page break, so it runs into the student's cover sheet"
                continue
            }
            # The overall result must be ON the declaration page, above the break.
            $seenAbove = $false
            for ($i = 0; $i -lt $breakAt; $i++) {
                $t = (Get-RunText $bodyParas[$i] $pkg.Ns).Trim()
                if ($t -eq $M.overallCompetentText -or $t -eq $M.overallNotCompetentText -or ($M.overallWithheldText -and $t -eq $M.overallWithheldText)) { $seenAbove = $true; break }
            }
            if (-not $seenAbove) { $pageProbs += "${name}: the overall result is not on the declaration page" }

            # And there must be something after it — a declaration page with the
            # student's assessment missing is not a marked assessment.
            $after = @($pkg.Body.ChildNodes | Where-Object { $_.LocalName -in @('p','tbl') })
            if ($after.Count -le ($breakAt + 1)) {
                $pageProbs += "${name}: nothing follows the declaration page"
            }
        } finally { Close-Docx $pkg }
    }
}
Add-Check 'MarkedCopyFeedbackPage' ($pageProbs.Count -eq 0) `
    $(if ($pageProbs.Count) { ($pageProbs | Select-Object -First 4) -join ' · ' } else { $(if ($markedExpected.Count) { "the result declaration is a page of its own in every copy, and the student's own first page follows it intact" } else { 'no marked copies were expected' }) })

# ------------------- 11b-iv-b. the assessor actually wrote something ---------
#
# An assessment record whose assessor comment is one line says nothing about
# what the assessor saw. The RTO's standard is at least two paragraphs of at
# least twenty words each, on every tool AND on every task inside one, and it
# is checked here against the DELIVERED text rather than the ledger — a comment
# that meets the standard in the ledger and arrives on the page as a single
# swallowed paragraph has still failed the student who reads it.

$depthProbs = @()
if ($M) {
    foreach ($name in $markedExpected.Keys) {
        $path = Join-Path $dirFull $name
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $exp  = $markedExpected[$name]
        $text = Get-DocxText -Path $path

        foreach ($res in @($exp.results)) {
            if (-not $res) { continue }
            # Nothing was submitted: that carries the RTO's own standing
            # wording and is exempt. A withheld result is not — the work was
            # still marked and the student still reads the comment.
            if (-not $res.submitted) { continue }

            foreach ($h in @(Test-AssessorComment -Text "$($res.feedback)" -Where "${name}: $($res.toolName) comment")) {
                $depthProbs += $h
            }
            # every paragraph of it has to be ON THE PAGE
            foreach ($p in @(Split-CommentParagraphs "$($res.feedback)")) {
                $probe = ($p -replace '\s+', ' ').Trim()
                if ($probe.Length -gt 60) { $probe = $probe.Substring(0, 60) }
                if ($probe -and $text -notmatch [regex]::Escape($probe)) {
                    $depthProbs += "${name}: $($res.toolName) comment paragraph is not on the page — '$probe'"
                }
            }

            foreach ($t in @($res.tasks)) {
                if (-not $t) { continue }
                foreach ($h in @(Test-AssessorComment -Text "$($t.comment)" -Where "${name}: task $($t.ref) comment")) {
                    $depthProbs += $h
                }
                foreach ($p in @(Split-CommentParagraphs "$($t.comment)")) {
                    $probe = ($p -replace '\s+', ' ').Trim()
                    if ($probe.Length -gt 60) { $probe = $probe.Substring(0, 60) }
                    if ($probe -and $text -notmatch [regex]::Escape($probe)) {
                        $depthProbs += "${name}: task $($t.ref) comment paragraph is not on the page — '$probe'"
                    }
                }
            }
        }
    }
}
Add-Check 'AssessorCommentDepth' ($depthProbs.Count -eq 0) `
    $(if ($depthProbs.Count) { ($depthProbs | Select-Object -First 5) -join ' · ' } else { $(if ($markedExpected.Count) { "every assessor comment is at least $((Get-ObservationLimits).MinParagraphs) paragraphs of at least $((Get-ObservationLimits).MinWordsPerParagraph) words, and every paragraph of it is on the page" } else { 'no marked copies were expected' }) })

# ------------------------- 11b-iv-c. every task carries its outcome ----------
#
# A tool made of tasks is judged task by task. Thirty-two coloured lines on a
# knowledge test and none at all on the three activities the student actually
# performed is the gap this closes: the tool-level line at the foot of the
# observation sheet is not a judgement of each task.

$taskProbs = @()
if ($M) {
    $sText  = "$($M.satisfactoryText)"
    $nysTxt = "$($M.notSatisfactoryText)"
    foreach ($name in $markedExpected.Keys) {
        $path = Join-Path $dirFull $name
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $exp = $markedExpected[$name]

        $want = 0
        foreach ($res in @($exp.results)) { if ($res) { $want += Get-Count $res.tasks } }
        if ($want -eq 0) { continue }

        $pkg = Open-Docx -Path $path
        try {
            $paras = @(Get-BodyParagraphs -Package $pkg)
            foreach ($res in @($exp.results)) {
                if (-not $res) { continue }
                foreach ($t in @($res.tasks)) {
                    if (-not $t) { continue }
                    $wantText = if ($t.outcome -eq 'S') { $sText } else { $nysTxt }
                    $wantCol  = if ($t.outcome -eq 'S') { "$($M.satisfactoryColor)" } else { "$($M.notSatisfactoryColor)" }
                    # FIND THE COMMENT, THEN THE OUTCOME UNDER IT. A task's
                    # judgement lives either in the labelled cell the
                    # instrument provides or, where it has none, in a block in
                    # the body — so keying off a heading only found half of
                    # them. Its own opening words are in the file either way,
                    # and every paragraph in the document is searched, not only
                    # the body-level ones, because a cell's paragraphs are not
                    # body-level.
                    $probe = (($t.comment -split "`r?`n")[0]).Trim()
                    if ($probe.Length -gt 50) { $probe = $probe.Substring(0, 50) }
                    $hits = @(Find-ParagraphIndex -Paragraphs $paras -Ns $pkg.Ns -Text $probe)
                    if ($hits.Count -lt 1) {
                        $taskProbs += "${name}: task $($t.ref) comment is not in the file"
                        continue
                    }
                    # the outcome line for this task, below its comment, in the
                    # right colour — the colour is half the signal
                    $found = $false
                    for ($i = $hits[0] + 1; $i -lt $paras.Count; $i++) {
                        $ptxt = (Get-RunText -Node $paras[$i] -Ns $pkg.Ns)
                        if ("$ptxt".Trim() -like "*$wantText*") {
                            $col = $paras[$i].SelectSingleNode('.//w:r/w:rPr/w:color', $pkg.Ns)
                            $got = if ($col) { "$($col.GetAttribute('val', $wNs))" } else { '' }
                            if ($got -ne $wantCol) {
                                $taskProbs += "${name}: task $($t.ref) outcome is coloured $got, expected $wantCol"
                            }
                            $found = $true
                            break
                        }
                    }
                    if (-not $found) { $taskProbs += "${name}: task $($t.ref) carries no '$wantText' outcome" }
                }
            }
        } finally { Close-Docx $pkg }
    }
}
Add-Check 'TaskOutcomeColoured' ($taskProbs.Count -eq 0) `
    $(if ($taskProbs.Count) { ($taskProbs | Select-Object -First 5) -join ' · ' } else { $(if ($markedExpected.Count) { 'every task the ledger judges carries its own outcome, in the colour of that outcome' } else { 'no marked copies were expected' }) })

# ------------------ 11b-v. the observation record is IN the sheet ------------
#
# Where the ledger names an observationSheet, the record was written into the
# sheet the student submitted, so it must be found BETWEEN THE SHEET'S OWN
# ANCHORS. A record outside them is the old behaviour coming back: a tidy
# summary bolted to the front of the file with the instrument itself left blank
# underneath it, which answers an auditor's question the wrong way round.
#
# The test was once 'inside a table', because the sheets seen first were tables
# throughout. ACI's construction checklist is not: its instructions and its
# notes line are body text above five section tables, so a record written where
# the sheet asks for it sits at body level and read as loose. Range is what the
# rule was always about.

$obsProbs = @()
if ($M -and $M.observationHeading) {
    foreach ($name in $markedExpected.Keys) {
        $path = Join-Path $dirFull $name
        if (-not (Test-Path -LiteralPath $path)) { continue }

        $exp     = $markedExpected[$name]
        $inSheet = @($exp.results | Where-Object { (Get-Count $_.observations) -gt 0 -and $_.observationSheet }).Count
        if ($inSheet -eq 0) { continue }

        $pkg = Open-Docx -Path $path
        try {
            # The boxes, read off the delivered file and paired the same way the
            # builder pairs them — independently, because 'the builder said it
            # ticked them' is exactly the claim this gate exists to distrust. A
            # sheet whose every box is still empty under a signed record is the
            # failure that looks most like success.
            $paras = @(Get-BodyParagraphs $pkg)
            foreach ($res in @($exp.results)) {
                $sheet = $res.observationSheet
                if (-not $sheet) { continue }
                $who = "${name} / $($res.toolName)"

                $startAt = -1
                for ($i = 0; $i -lt $paras.Count; $i++) {
                    if ((Get-RunText $paras[$i] $pkg.Ns).IndexOf("$($sheet.anchor)", [StringComparison]::OrdinalIgnoreCase) -ge 0) { $startAt = $i; break }
                }
                if ($startAt -lt 0) { $obsProbs += "${who}: the observation sheet named in the ledger is not in the delivered file"; continue }

                $endAt = $paras.Count
                if ($sheet.PSObject.Properties.Name.Contains('endAnchor') -and $sheet.endAnchor) {
                    for ($i = $startAt + 1; $i -lt $paras.Count; $i++) {
                        if ((Get-RunText $paras[$i] $pkg.Ns).IndexOf("$($sheet.endAnchor)", [StringComparison]::OrdinalIgnoreCase) -ge 0) { $endAt = $i; break }
                    }
                }
                $sufAt = $endAt
                if ($sheet.PSObject.Properties.Name.Contains('sufficientAnchor') -and $sheet.sufficientAnchor) {
                    for ($i = $startAt + 1; $i -lt $endAt; $i++) {
                        if ((Get-RunText $paras[$i] $pkg.Ns).IndexOf("$($sheet.sufficientAnchor)", [StringComparison]::OrdinalIgnoreCase) -ge 0) { $sufAt = $i; break }
                    }
                }

                # The record itself: written between this sheet's own anchors,
                # not bolted to the front of the file.
                $recordAt = -1
                for ($i = $startAt; $i -lt $endAt; $i++) {
                    if ((Get-RunText $paras[$i] $pkg.Ns).Trim().StartsWith($M.observationHeading)) { $recordAt = $i; break }
                }
                if ($recordAt -lt 0) {
                    $obsProbs += "${who}: the observation record is not inside the observation sheet; it is loose in the body"
                }

                $sheetLayout = 'labelled'
                if ($sheet.PSObject.Properties.Name.Contains('layout') -and $sheet.layout) {
                    $sheetLayout = "$($sheet.layout)".Trim().ToLowerInvariant()
                }

                # A COLUMN SHEET carries no labelled boxes at all: 'Yes' and 'No'
                # head two columns and each cell holds a bare box. Read row by
                # row off the tables inside the sheet, finding the columns by
                # their heading text — the same way the builder found them, and
                # from the delivered file rather than from anything it reported.
                if ($sheetLayout -eq 'columns') {
                    $want  = @($sheet.outcomes)
                    $notes = @()
                    if ($sheet.PSObject.Properties.Name.Contains('comments') -and $sheet.comments) { $notes = @($sheet.comments) }

                    $yesHeader      = if ($sheet.PSObject.Properties.Name.Contains('yesHeader')      -and $sheet.yesHeader)      { "$($sheet.yesHeader)" }      else { 'Yes' }
                    $noHeader       = if ($sheet.PSObject.Properties.Name.Contains('noHeader')       -and $sheet.noHeader)       { "$($sheet.noHeader)" }       else { 'No' }
                    $commentsHeader = if ($sheet.PSObject.Properties.Name.Contains('commentsHeader') -and $sheet.commentsHeader) { "$($sheet.commentsHeader)" } else { 'Comments' }
                    $sheetCellStyle = if ($sheet.PSObject.Properties.Name.Contains('cellStyle')      -and $sheet.cellStyle)      { "$($sheet.cellStyle)".Trim().ToLowerInvariant() } else { 'box' }

                    $pIndex = @{}
                    for ($i = 0; $i -lt $paras.Count; $i++) { $pIndex[$paras[$i]] = $i }

                    $rows = @()
                    foreach ($tbl in @(Get-Tables $pkg)) {
                        $firstPara = $tbl.SelectSingleNode('.//w:p', $pkg.Ns)
                        if (-not $firstPara -or -not $pIndex.ContainsKey($firstPara)) { continue }
                        $tAt = $pIndex[$firstPara]
                        if ($tAt -le $startAt -or $tAt -ge $endAt) { continue }

                        $cols = $null
                        foreach ($tr in @(Get-Rows $tbl $pkg.Ns)) {
                            $cells = @(Get-Cells $tr $pkg.Ns)
                            if ($cells.Count -eq 0) { continue }
                            $texts = @($cells | ForEach-Object { ((("$($_.InnerText)") -replace '\s+', ' ').Trim()) })
                            $y = [Array]::IndexOf($texts, $yesHeader)
                            $n = [Array]::IndexOf($texts, $noHeader)
                            if ($y -ge 0 -and $n -ge 0 -and $y -ne $n) {
                                $cols = [pscustomobject]@{ yes = $y; no = $n; comments = [Array]::IndexOf($texts, $commentsHeader) }
                                continue
                            }
                            if (-not $cols) { continue }
                            if ($cells.Count -le [Math]::Max($cols.yes, $cols.no)) { continue }
                            $yTxt = ($texts[$cols.yes] -replace '\s+', '')
                            $nTxt = ($texts[$cols.no]  -replace '\s+', '')

                            # A 'word' sheet prints no box at all. Its Yes and No
                            # cells start empty and the decision is the column's
                            # own word typed into one of them. Read it that way
                            # here too — a box reader run over a word sheet finds
                            # no criterion rows and reports nothing wrong, which
                            # is precisely the failure this check exists to catch.
                            if ($sheetCellStyle -eq 'word') {
                                $yOk = ($yTxt -eq '' -or $yTxt -eq $yesHeader -or $yTxt -eq "$BOX_E" -or $yTxt -eq "$BOX_T")
                                $nOk = ($nTxt -eq '' -or $nTxt -eq $noHeader  -or $nTxt -eq "$BOX_E" -or $nTxt -eq "$BOX_T")
                                if (-not $yOk -or -not $nOk) { continue }
                                $rows += [pscustomobject]@{
                                    criterion = $texts[0]
                                    yes       = ($yTxt -eq $yesHeader -or $yTxt -eq "$BOX_T")
                                    no        = ($nTxt -eq $noHeader  -or $nTxt -eq "$BOX_T")
                                    comment   = $(if ($cols.comments -ge 0 -and $cols.comments -lt $texts.Count) { $texts[$cols.comments] } else { '' })
                                }
                                continue
                            }

                            if ($yTxt -ne "$BOX_E" -and $yTxt -ne "$BOX_T") { continue }
                            if ($nTxt -ne "$BOX_E" -and $nTxt -ne "$BOX_T") { continue }
                            $rows += [pscustomobject]@{
                                criterion = $texts[0]
                                yes       = ($yTxt -eq "$BOX_T")
                                no        = ($nTxt -eq "$BOX_T")
                                comment   = $(if ($cols.comments -ge 0 -and $cols.comments -lt $texts.Count) { $texts[$cols.comments] } else { '' })
                            }
                        }
                    }

                    if ((Get-Count $want) -gt 0) {
                        if ($rows.Count -ne $want.Count) {
                            $obsProbs += "${who}: the sheet holds $($rows.Count) criterion row(s), the ledger judges $($want.Count)"
                        } else {
                            for ($k = 0; $k -lt $want.Count; $k++) {
                                $wantYes = ("$($want[$k])" -eq 'Yes')
                                if ($rows[$k].yes -ne $wantYes -or $rows[$k].no -eq $wantYes) {
                                    $obsProbs += "${who}: criterion row $($k + 1) ('$($rows[$k].criterion)') should read $($want[$k]) but its boxes read Yes=$($rows[$k].yes) No=$($rows[$k].no)"
                                }
                            }
                        }
                    }
                    if ($notes.Count -gt 0 -and $rows.Count -eq $notes.Count) {
                        for ($k = 0; $k -lt $notes.Count; $k++) {
                            $noteText = if ($notes[$k] -is [string]) { "$($notes[$k])" } else { "$($notes[$k].text)" }
                            $onSheet  = (("$($rows[$k].comment)") -replace '\s+', ' ').Trim()
                            $expected = (("$noteText") -replace '\s+', ' ').Trim()
                            # The cell OPENS with the ledger's note. It may also
                            # close with the criterion's coloured outcome, which
                            # is written into the same cell because that is the
                            # space the instrument provides — so this is a
                            # starts-with, not an equality.
                            if (-not $onSheet.StartsWith($expected)) {
                                $obsProbs += "${who}: the comments cell on criterion row $($k + 1) does not carry the ledger's note"
                            }
                        }
                    } elseif ($notes.Count -gt 0) {
                        $obsProbs += "${who}: the ledger writes $($notes.Count) comment(s) but the sheet holds $($rows.Count) comments cell(s)"
                    }
                }


                # AN INLINE-PAIR SHEET carries one decision column whose cell
                # holds both boxes with their words: '☐ S ☐ NS'. Neither the
                # labelled scan below nor the column reader above can see it, so
                # it is read here, row by row off the delivered file — not from
                # anything the build reported.
                if ($sheetLayout -eq 'inlinepairs') {
                    $want  = @($sheet.outcomes)
                    $notes = @()
                    if ($sheet.PSObject.Properties.Name.Contains('comments') -and $sheet.comments) { $notes = @($sheet.comments) }

                    $decisionHeader = if ($sheet.PSObject.Properties.Name.Contains('decisionHeader') -and $sheet.decisionHeader) { "$($sheet.decisionHeader)" } else { 'S / NS' }
                    $commentsHeader = if ($sheet.PSObject.Properties.Name.Contains('commentsHeader') -and $sheet.commentsHeader) { "$($sheet.commentsHeader)" } else { 'Assessor Comments' }
                    $yesLabel       = if ($sheet.PSObject.Properties.Name.Contains('yesLabel')       -and $sheet.yesLabel)       { "$($sheet.yesLabel)" }       else { 'S' }
                    $noLabel        = if ($sheet.PSObject.Properties.Name.Contains('noLabel')        -and $sheet.noLabel)        { "$($sheet.noLabel)" }        else { 'NS' }
                    $pairRx = '^[' + $BOX_E + $BOX_T + ']' + [regex]::Escape(($yesLabel -replace '\s+','')) +
                              '[' + $BOX_E + $BOX_T + ']' + [regex]::Escape(($noLabel -replace '\s+','')) + '$'

                    $pIndex = @{}
                    for ($i = 0; $i -lt $paras.Count; $i++) { $pIndex[$paras[$i]] = $i }

                    $rows = @()
                    foreach ($tbl in @(Get-Tables $pkg)) {
                        $firstPara = $tbl.SelectSingleNode('.//w:p', $pkg.Ns)
                        if (-not $firstPara -or -not $pIndex.ContainsKey($firstPara)) { continue }
                        $tAt = $pIndex[$firstPara]
                        if ($tAt -le $startAt -or $tAt -ge $endAt) { continue }

                        $cols = $null
                        foreach ($tr in @(Get-Rows $tbl $pkg.Ns)) {
                            $cells = @(Get-Cells $tr $pkg.Ns)
                            if ($cells.Count -eq 0) { continue }
                            $texts = @($cells | ForEach-Object { ((("$($_.InnerText)") -replace '\s+', ' ').Trim()) })
                            $d = [Array]::IndexOf($texts, $decisionHeader)
                            if ($d -ge 0) {
                                $cols = [pscustomobject]@{ decision = $d; comments = [Array]::IndexOf($texts, $commentsHeader) }
                                continue
                            }
                            if (-not $cols) { continue }
                            if ($cells.Count -le $cols.decision) { continue }
                            $dTxt = ($texts[$cols.decision] -replace '\s+', '')
                            if ($dTxt -notmatch $pairRx) { continue }
                            $bx = @([regex]::Matches($dTxt, '[' + $BOX_E + $BOX_T + ']') | ForEach-Object { $_.Value })
                            $rows += [pscustomobject]@{
                                criterion = $texts[0]
                                yes       = ($bx.Count -ge 1 -and $bx[0] -eq "$BOX_T")
                                no        = ($bx.Count -ge 2 -and $bx[1] -eq "$BOX_T")
                                comment   = $(if ($cols.comments -ge 0 -and $cols.comments -lt $texts.Count) { $texts[$cols.comments] } else { '' })
                            }
                        }
                    }

                    if ((Get-Count $want) -gt 0) {
                        if ($rows.Count -ne $want.Count) {
                            $obsProbs += "${who}: the sheet holds $($rows.Count) criterion row(s), the ledger judges $($want.Count)"
                        } else {
                            for ($k = 0; $k -lt $want.Count; $k++) {
                                $wantYes = ("$($want[$k])" -eq 'Yes')
                                if ($rows[$k].yes -ne $wantYes -or $rows[$k].no -eq $wantYes) {
                                    $obsProbs += "${who}: criterion row $($k + 1) ('$($rows[$k].criterion)') should read $($want[$k]) but its boxes read $yesLabel=$($rows[$k].yes) $noLabel=$($rows[$k].no)"
                                }
                            }
                        }
                    }
                    if ($notes.Count -gt 0 -and $rows.Count -eq $notes.Count) {
                        for ($k = 0; $k -lt $notes.Count; $k++) {
                            $noteText = if ($notes[$k] -is [string]) { "$($notes[$k])" } else { "$($notes[$k].text)" }
                            $onSheet  = (("$($rows[$k].comment)") -replace '\s+', ' ').Trim()
                            $expected = (("$noteText") -replace '\s+', ' ').Trim()
                            if (-not $onSheet.StartsWith($expected)) {
                                $obsProbs += "${who}: the comments cell on criterion row $($k + 1) does not carry the ledger's note"
                            }
                        }
                    } elseif ($notes.Count -gt 0) {
                        $obsProbs += "${who}: the ledger writes $($notes.Count) comment(s) but the sheet holds $($rows.Count) comments cell(s)"
                    }
                }
                $boxes = @()
                for ($i = $startAt + 1; $i -lt $sufAt; $i++) {
                    $t = (Get-RunText $paras[$i] $pkg.Ns).Trim()
                    if ($t -match "^[$BOX_E$BOX_T]\s*(Yes|No)$") { $boxes += [pscustomobject]@{ word = $Matches[1]; ticked = $t.StartsWith($BOX_T) } }
                }
                $want = @($sheet.outcomes)
                if ($sheetLayout -ne 'labelled') { $want = @() }      # columns and inlinePairs are already read row by row above
                if ((Get-Count $want) -gt 0) {
                    if ($boxes.Count -ne (2 * $want.Count)) {
                        $obsProbs += "${who}: the sheet holds $($boxes.Count) Yes/No box(es), the ledger judges $($want.Count) task(s)"
                    } else {
                        for ($k = 0; $k -lt $want.Count; $k++) {
                            $yes = $boxes[2 * $k]; $no = $boxes[2 * $k + 1]
                            $wantYes = ("$($want[$k])" -eq 'Yes')
                            if ($yes.ticked -ne $wantYes -or $no.ticked -eq $wantYes) {
                                $obsProbs += "${who}: observable task $($k + 1) should read $($want[$k]) but its boxes read Yes=$($yes.ticked) No=$($no.ticked)"
                            }
                        }
                    }
                }

                if ($sheet.PSObject.Properties.Name.Contains('sufficient') -and $null -ne $sheet.sufficient -and $sufAt -lt $endAt) {
                    $wantSuf   = [bool]$sheet.sufficient
                    $sufLabels = @()
                    if ($sheet.PSObject.Properties.Name.Contains('sufficientLabels') -and $sheet.sufficientLabels) {
                        $sufLabels = @($sheet.sufficientLabels)
                    }
                    if ($sufLabels.Count -eq 2) {
                        # An overall box that reads something other than Yes/No —
                        # ACI's checklist ends 'Competent / Not Yet Competent'.
                        # Both labels usually print on one line, so the two are
                        # read out of the paragraph text rather than counted.
                        $satTicked = $false; $satSeen = $false
                        $notTicked = $false; $notSeen = $false
                        for ($i = $sufAt; $i -lt $endAt; $i++) {
                            $t = (Get-RunText $paras[$i] $pkg.Ns)
                            if ($t.IndexOf("$BOX_T $($sufLabels[0])", [StringComparison]::Ordinal) -ge 0) { $satSeen = $true; $satTicked = $true }
                            elseif ($t.IndexOf("$BOX_E $($sufLabels[0])", [StringComparison]::Ordinal) -ge 0) { $satSeen = $true }
                            if ($t.IndexOf("$BOX_T $($sufLabels[1])", [StringComparison]::Ordinal) -ge 0) { $notSeen = $true; $notTicked = $true }
                            elseif ($t.IndexOf("$BOX_E $($sufLabels[1])", [StringComparison]::Ordinal) -ge 0) { $notSeen = $true }
                        }
                        if (-not $satSeen -or -not $notSeen) { $obsProbs += "${who}: the overall box labelled '$($sufLabels[0])' was not found on the sheet" }
                        elseif ($satTicked -ne $wantSuf -or $notTicked -eq $wantSuf) {
                            $obsProbs += "${who}: the overall box does not read '$(if ($wantSuf) { $sufLabels[0] } else { $sufLabels[1] })'"
                        }
                    } else {
                        $sBoxes = @()
                        for ($i = $sufAt; $i -lt $endAt; $i++) {
                            $t = (Get-RunText $paras[$i] $pkg.Ns).Trim()
                            if ($t -match "^[$BOX_E$BOX_T]\s*(Yes|No)$") { $sBoxes += [pscustomobject]@{ word = $Matches[1]; ticked = $t.StartsWith($BOX_T) } }
                        }
                        if ($sBoxes.Count -lt 2) { $obsProbs += "${who}: no sufficiency box was found on the sheet" }
                        elseif ($sBoxes[0].ticked -ne $wantSuf -or $sBoxes[1].ticked -eq $wantSuf) {
                            $obsProbs += "${who}: the sufficiency box does not read $(if ($wantSuf) { 'Yes' } else { 'No' })"
                        }
                    }
                }

                foreach ($fld in @($sheet.fields)) {
                    if (-not $fld) { continue }
                    $seen = $false
                    for ($i = $startAt; $i -lt $endAt; $i++) {
                        $t = (Get-RunText $paras[$i] $pkg.Ns).Trim()
                        # A field written into the cell beside its label IS the
                        # cell's whole text. One written onto a printed rule —
                        # 'Assessor Signature: _____' — shares its line with the
                        # label and with whatever else the line carries, so it is
                        # read as label-then-value rather than as the line.
                        if ($t -eq "$($fld.value)") { $seen = $true; break }
                        if ($t.IndexOf("$($fld.label): $($fld.value)", [StringComparison]::OrdinalIgnoreCase) -ge 0) { $seen = $true; break }
                    }
                    if (-not $seen) { $obsProbs += "${who}: field '$($fld.label)' does not carry '$($fld.value)' on the sheet" }
                }
            }
        } finally { Close-Docx $pkg }
    }
}
Add-Check 'MarkedCopyObservationSheet' ($obsProbs.Count -eq 0) `
    $(if ($obsProbs.Count) { ($obsProbs | Select-Object -First 4) -join ' · ' } else { 'every observation record the ledger places in a sheet was written into that sheet' })

# ---------------------------------- 11b-vi. no other provider's identity ------
#
# THE FAILURE THIS EXISTS FOR: a template rebuilt from another brand's file
# carries that brand's LOGO, FOOTER and DOCUMENT NUMBER in its header and footer
# parts, where no check that reads document.xml can see them. The body says
# Adelaide Construction Institute, the page says Meridian Vocational College, and
# the RTO has issued a record under a provider it is not.
#
# So every part of every RECORD is read — headers, footers, document, the lot —
# and every other registered RTO's name is looked for. A marked copy is exempt:
# it is the student's own document, and ACI's own cover sheet names both of its
# trading names.
$foreignProbs = @()
$foreignMarks = @()
foreach ($pf in @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '..\assets') -Filter 'rto.*.json' -File)) {
    $other = Get-Content -Raw -Encoding UTF8 -LiteralPath $pf.FullName | ConvertFrom-Json
    if (-not $other.rto -or "$($other.key)" -eq "$($L.rto)") { continue }
    foreach ($mark in @($other.rto.tradingName, $other.rto.legalName, $other.rto.rtoCode, $other.rto.cricos)) {
        $m = "$mark".Trim()
        if (-not $m) { continue }
        # ACI trades under two names on ONE registration, so its own code and
        # CRICOS number read as another profile's too. Only what genuinely
        # differs from this RTO can be foreign.
        if ($m -eq "$($Rto.rto.tradingName)" -or $m -eq "$($Rto.rto.legalName)" -or
            $m -eq "$($Rto.rto.rtoCode)"     -or $m -eq "$($Rto.rto.cricos)") { continue }
        $foreignMarks += [pscustomobject]@{ mark = $m; who = "$($other.rto.tradingName)" }
    }
}
$foreignMeta = @()
if ($foreignMarks.Count) {
    foreach ($f in $recordFiles) {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($f.FullName)
        try {
            foreach ($e in $zip.Entries) {
                $part = $e.FullName.Replace('\', '/')
                if ($part -notlike '*.xml') { continue }
                $sr = New-Object System.IO.StreamReader($e.Open())
                $xml = $sr.ReadToEnd(); $sr.Close()
                foreach ($fm in $foreignMarks) {
                    if ($xml.IndexOf($fm.mark, [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
                    # What a student and an auditor SEE is the body, the headers
                    # and the footers. docProps is Word's own metadata — the
                    # Company field, the custom properties — and the RTO's
                    # supplied templates carry the sibling brand there because
                    # one was saved from the other. Worth reporting, not worth
                    # blocking a class of marking over.
                    if ($part -like 'docProps/*') {
                        $foreignMeta += "$($f.Name): '$($fm.mark)' in $part"
                    } else {
                        $foreignProbs += "$($f.Name): '$($fm.mark)' ($($fm.who)) appears in $part"
                    }
                }
            }
        } finally { $zip.Dispose() }
    }
}
if ($foreignProbs.Count -eq 0 -and $foreignMeta.Count -gt 0) {
    Add-Check 'NoForeignRtoIdentity' $false -Warn `
        ("nothing visible names another provider, but Word metadata does — " + (($foreignMeta | Select-Object -Unique | Select-Object -First 3) -join ' · ') + ". It came in with the supplied template; clear the Company and custom properties when it is next revised.")
} else {
    Add-Check 'NoForeignRtoIdentity' ($foreignProbs.Count -eq 0) `
        $(if ($foreignProbs.Count) { (($foreignProbs | Select-Object -Unique | Select-Object -First 4) -join ' · ') } else { "no record names a provider other than $($Rto.rto.tradingName), headers and footers included" })
}

# ------------------------------------------- 11c. the RTO's word ban ---------
#
# The RTO's instruction: one word of software jargon does not appear in the
# marking or in any document issued. It reads as machinery on a record that a
# student and an auditor both see. The banned word is held as a character list
# so this check does not itself contain the string it forbids.
#
# MARKED COPIES ARE EXEMPT, and the exemption is not a loosening of the rule.
# A marked copy is the student's own submission with a front block and outcome
# lines added; every other word in it is theirs, and altering it is forbidden
# outright. A student who writes 'prompt implementation' in an answer has used
# an ordinary English word, and the only way to satisfy an unscoped check would
# be to edit their evidence. The ban targets OUR prose, so it is checked where
# our prose lives: the SAR, the marking record and the feedback sheet.

$bannedWord = ([char[]]@(112,114,111,109,112,116) -join '')     # p r o m p t
$banned = @()
foreach ($f in $recordFiles) {
    $hay = $textOf[$f.Name] + ' ' + (($rowsOf[$f.Name]) -join ' ')
    foreach ($m in [regex]::Matches($hay, "(?i)\b${bannedWord}s?\b")) {
        $at = [Math]::Max(0, $m.Index - 40)
        $banned += "$($f.Name): '...$($hay.Substring($at, [Math]::Min(90, $hay.Length - $at)).Trim())...'"
    }
}
Add-Check 'NoBannedWord' ($banned.Count -eq 0) `
    $(if ($banned.Count) { ($banned | Select-Object -First 4) -join ' · ' } else { "the RTO's banned word appears in no issued document" })
# ------------------------------------------------- 11d. character encoding ---
#
# Mojibake: UTF-8 text decoded as ANSI and re-encoded, so 'Â·' stands where '·'
# belongs. It has one common cause here — a .ps1 saved without its BOM, which
# PowerShell 5.1 then reads as ANSI. That failure does NOT stop the build and
# does not break the XML; it just quietly corrupts every dash and degree sign in
# the text this skill writes.

$moji = @()
foreach ($f in $files) {
    $hay = $textOf[$f.Name] + ' ' + (($rowsOf[$f.Name]) -join ' ')
    foreach ($m in [regex]::Matches($hay, '(Â[-¿]|â€[-¿™]|Ã[-¿])')) {
        $banned2 = $m.Value
        $moji += "$($f.Name): '$banned2'"
    }
}
Add-Check 'NoMojibake' ($moji.Count -eq 0) `
    $(if ($moji.Count) { (($moji | Select-Object -Unique | Select-Object -First 6) -join ' · ') + "  — a script was almost certainly saved without its UTF-8 BOM" } else { 'no double-encoded characters in any document' })

# ------------------------------------- 12. namespace prefixes (Word-free) ----
#
# A cheap proxy for the failure below. XmlDocument will happily invent a prefix
# for a reserved namespace — most often xml:space, emitted as
#   <w:t d8p1:space="preserve" xmlns:d8p1="http://www.w3.org/XML/1998/namespace">
# That is well-formed XML, passes every structural check above, and makes Word
# refuse to open the file. This check runs everywhere, including on a machine
# with no Word installed.

$nsProbs2 = @()
foreach ($f in $files) {
    $pkg = Open-Docx -Path $f.FullName
    try {
        $raw = [System.IO.File]::ReadAllText($pkg.DocPath, [System.Text.Encoding]::UTF8)
        foreach ($m in [regex]::Matches($raw, 'xmlns:([A-Za-z_][\w.-]*)="([^"]+)"')) {
            $prefix = $m.Groups[1].Value
            $uri    = $m.Groups[2].Value
            if ($uri -eq 'http://www.w3.org/XML/1998/namespace' -and $prefix -ne 'xml') {
                $nsProbs2 += "$($f.Name): the reserved xml namespace is bound to invented prefix '$prefix'"
            }
        }
    } finally { Close-Docx $pkg }
}
Add-Check 'NoInventedNamespacePrefix' ($nsProbs2.Count -eq 0) `
    $(if ($nsProbs2.Count) { ($nsProbs2 | Select-Object -First 4) -join ' · ' } else { 'no reserved namespace bound to an invented prefix' })

# ------------------------------- 13. the document actually opens in Word -----
#
# Everything above reads XML. XML that satisfies every check here can still be
# a file Word will not open — that is precisely how a build ships ten green
# records that nobody can read. This check opens the real files. It runs by
# default; -SkipRender turns it off, and a machine without Word gets a WARN
# rather than a false pass.

if (-not $SkipRender) {
    $word = $null
    try {
        $word = New-Object -ComObject Word.Application
        $word.Visible = $false
        $word.DisplayAlerts = 0

        $openProbs = @()
        $pageProbs = @()
        foreach ($f in $files) {
            try {
                $doc = $word.Documents.Open($f.FullName, $false, $true)
                # FeedbackSheetOnePage is RETIRED with the sheet. The feedback
                # now lives on page one of the marked copy and may run past one
                # physical page where it is long. The page break before the
                # student's own content is what matters, and
                # MarkedCopyFeedbackPage checks that on the file itself.
                $doc.Close($false)
            } catch {
                $openProbs += "$($f.Name) will not open in Word"
            }
        }
        Add-Check 'OpensInWord' ($openProbs.Count -eq 0) `
            $(if ($openProbs.Count) { ($openProbs | Select-Object -First 6) -join ' · ' } else { "all $($files.Count) file(s) open in Word" })
    } catch {
        Add-Check 'OpensInWord' $true "Word is not available on this machine, so the render check did not run. NoInventedNamespacePrefix and the structural checks stand in its place, and they are weaker: open one file by hand before issuing these records. ($($_.Exception.Message))" -Warn
    } finally {
        if ($word) { try { $word.Quit() } catch {}; [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) }
    }
}

# ---------------------------------------------------------------- report -----

$fails = @($results | Where-Object { $_.status -eq 'FAIL' })
$warns = @($results | Where-Object { $_.status -eq 'WARN' })

if (-not $Quiet) {
    Write-Output ''
    Write-Output "MARKING RECORDS GATE — $($L.unit.code) $($L.unit.title), marking date $($L.dates.markingDateText)"
    Write-Output ("  $dirFull  ·  {0} file(s)" -f $files.Count)
    Write-Output ''
    foreach ($r in $results) {
        Write-Output ("  {0,-4} {1,-24} {2}" -f $r.status, $r.name, $r.detail)
    }
    Write-Output ''
    if ($fails.Count -eq 0) {
        Write-Output "GATE PASSED — $($results.Count) check(s), $($warns.Count) warning(s). These records are ready to sign."
    } else {
        Write-Output "GATE FAILED — $($fails.Count) of $($results.Count) check(s) failed. Nothing here is deliverable."
    }
    Write-Output ''
}

if ($fails.Count -gt 0) { exit 1 }
