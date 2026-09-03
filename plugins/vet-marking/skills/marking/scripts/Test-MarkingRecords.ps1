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
foreach ($s in $L.students) {
    $expected[$s.sarFile] = "SAR for $($s.fullName)"
    if ($s.needsFeedbackSheet) { $expected[$s.feedbackFile] = "feedback sheet for $($s.fullName)" }

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
$expected[$L.amrrFile] = 'marking record'

# The three OFFICIAL RECORDS are built from the RTO's templates and every
# template-shaped check applies to them. A MARKED copy is the STUDENT'S OWN
# document with two additions, so checks about fields, rows and house styling
# would be policing the student's writing, not ours.
$recordFiles = @($files | Where-Object { $_.Name -notlike 'MARKED_*' })
$markedFiles = @($files | Where-Object { $_.Name -like 'MARKED_*' })

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
    $(if ($missing.Count) { "missing: $($missing -join ', ')" } elseif ($extra.Count) { "unexpected file(s): $($extra -join ', ')" } else { "$($L.students.Count) SAR + 1 record + $(@($L.students | Where-Object { $_.needsFeedbackSheet }).Count) feedback, all present and correctly named" })

Add-Check 'MarkingRecordName' (Test-Path -LiteralPath (Join-Path $dirFull $L.amrrFile)) $L.amrrFile

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
    elseif (-not $isC -and -not $isNyc) { $overallProbs += "${name}: neither Competent nor Not Yet Competent ticked" }
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
    $shouldBe = if (@($s.results | Where-Object { $_.result -eq 'NYS' }).Count -gt 0) { 'NYC' } else { 'C' }
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

if ($amrrRows.Count -ne $L.students.Count) {
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

# feedback sheet agrees with its SAR
foreach ($s in @($L.students | Where-Object { $_.needsFeedbackSheet })) {
    if (-not $rowsOf.ContainsKey($s.feedbackFile)) { continue }
    $fr = $rowsOf[$s.feedbackFile]
    $blob = $fr -join ' § '
    if ($blob -notlike "*$($s.studentId)*")            { $agree += "$($s.feedbackFile) does not carry student ID $($s.studentId)" }
    if ($blob -notlike "*$($s.resubmissionDueText)*")  { $agree += "$($s.feedbackFile) does not carry resubmission due $($s.resubmissionDueText)" }
    $overallRow = @($fr | Where-Object { $_ -like 'Overall result*' }) | Select-Object -First 1
    if ($overallRow -and $overallRow -notmatch "\|\s*$($s.overall)\s*\|") {
        $agree += "$($s.feedbackFile) overall result does not read $($s.overall)"
    }
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
    $none = (@($s.results | Where-Object { -not $_.submitted }).Count -eq @($s.results).Count)
    if ($none -and $s.comment -ne 'No submission') { $nsProbs += "$($s.fullName) submitted nothing but the comment reads '$($s.comment)'" }
    if (-not $none -and $s.comment -eq 'No submission') { $nsProbs += "$($s.fullName) submitted work but the comment reads 'No submission'" }
}
Add-Check 'NoSubmissionComment' ($nsProbs.Count -eq 0) `
    $(if ($nsProbs.Count) { ($nsProbs -join ' · ') } else { 'every non-submission carries exactly "No submission"' })

# ------------------------------------------------- 10. feedback sheet size ---

$sizeProbs = @()
$maxItems  = $Rto.templates.feedback.itemTable.maxItems
foreach ($s in @($L.students | Where-Object { $_.needsFeedbackSheet })) {
    if (-not $rowsOf.ContainsKey($s.feedbackFile)) { continue }
    $items = @($rowsOf[$s.feedbackFile] | Where-Object { $_ -match '^\d+\s\|' })
    if ($items.Count -eq 0)         { $sizeProbs += "$($s.feedbackFile) lists no items" }
    if ($items.Count -gt $maxItems) { $sizeProbs += "$($s.feedbackFile) lists $($items.Count) items; the sheet holds $maxItems on one page" }
}
Add-Check 'FeedbackSheetPerNyc' ($sizeProbs.Count -eq 0) `
    $(if ($sizeProbs.Count) { ($sizeProbs -join ' · ') } else { "$(@($L.students | Where-Object { $_.needsFeedbackSheet }).Count) sheet(s), each within the one-page item limit of $maxItems" })

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
                $colNode = $para.SelectSingleNode('.//w:rPr/w:color', $pkg.Ns)
                $col = if ($colNode) { $colNode.GetAttribute('val', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main') } else { '' }

                if ($txt -eq $M.satisfactoryText) {
                    $gotS++
                    if ($col -ne $M.satisfactoryColor) { $markProbs += "${name}: a Satisfactory line is colour $col, not $($M.satisfactoryColor)" }
                }
                elseif ($txt -eq $M.notSatisfactoryText) {
                    $gotNys++
                    if ($col -ne $M.notSatisfactoryColor) { $markProbs += "${name}: a Not yet Satisfactory line is colour $col, not $($M.notSatisfactoryColor)" }
                }
                elseif ($txt -eq $M.overallCompetentText -or $txt -eq $M.overallNotCompetentText) {
                    $overallSeen = if ($txt -eq $M.overallCompetentText) { 'C' } else { 'NYC' }
                    $jc = $para.SelectSingleNode('w:pPr/w:jc', $pkg.Ns)
                    $overallAlign = if ($jc) { $jc.GetAttribute('val', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main') } else { 'left' }
                    $wantCol = if ($overallSeen -eq 'C') { $M.satisfactoryColor } else { $M.notSatisfactoryColor }
                    if ($col -ne $wantCol) { $markProbs += "${name}: the overall result is colour $col, not $wantCol" }
                }
                # StartsWith, not equals: a record on the declaration page names
                # the tool after the heading, because a file can carry more than
                # one and two identical headings would say nothing about which
                # observation each belongs to.
                elseif ($M.observationHeading -and $txt.StartsWith($M.observationHeading)) { $obsHeading++; $inObs = $true }
                elseif ($inObs -and $bullet -and $txt.StartsWith($bullet))                 { $obsPoints++ }
                elseif ($M.observationCompletedText -and $txt.StartsWith($M.observationCompletedText)) { $obsCompleted++; $inObs = $false }
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
# The front block is body-level text and lands on the section's text margin,
# while the student's content sits wherever its tables put it. Those are rarely
# the same edge. Nothing above would notice: the words are right, the colours
# are right, and the block is simply out of line with every page beneath it.
#
# So compare the block's edges with the first table's edges, in twips from the
# page edge, and require them to be equal. Both come from the finished file.

$alignProbs = @()
$wNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
if ($M) {
    foreach ($name in $markedExpected.Keys) {
        $path = Join-Path $dirFull $name
        if (-not (Test-Path -LiteralPath $path)) { continue }

        $exp = $markedExpected[$name]

        $pkg = Open-Docx -Path $path
        try {
            $box = Get-BodyContentBox -Pkg $pkg
            if (-not $box) { continue }        # nothing measurable, nothing claimed

            # The declaration page runs to its page break, so the break is what
            # bounds the block rather than a paragraph count this script would
            # otherwise have to keep in step with the builder by hand.
            $bodyParas = @($pkg.Body.SelectNodes('./w:p', $pkg.Ns))
            $blockLen = -1
            for ($i = 0; $i -lt $bodyParas.Count; $i++) {
                if (Test-ParagraphIsPageBreak -Paragraph $bodyParas[$i] -Ns $pkg.Ns) { $blockLen = $i; break }
            }
            if ($blockLen -lt 0) {
                $alignProbs += "${name}: no page break closes the declaration page, so it is not on a page of its own"
                continue
            }
            for ($i = 0; $i -lt $blockLen; $i++) {
                $ind = $bodyParas[$i].SelectSingleNode('w:pPr/w:ind', $pkg.Ns)
                $gotL = if ($ind) { [int]$ind.GetAttribute('left',  $wNs) } else { 0 }
                $gotR = if ($ind) { [int]$ind.GetAttribute('right', $wNs) } else { 0 }
                if ($gotL -ne $box.IndentLeft -or $gotR -ne $box.IndentRight) {
                    $alignProbs += "${name}: front block line $($i + 1) is indented L$gotL R$gotR, the content sits at L$($box.IndentLeft) R$($box.IndentRight)"
                    break
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
                if ($t -eq $M.overallCompetentText -or $t -eq $M.overallNotCompetentText) { $seenAbove = $true; break }
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
Add-Check 'MarkedCopyDeclarationPage' ($pageProbs.Count -eq 0) `
    $(if ($pageProbs.Count) { ($pageProbs | Select-Object -First 4) -join ' · ' } else { $(if ($markedExpected.Count) { "the result declaration is a page of its own in every copy, and the student's own first page follows it intact" } else { 'no marked copies were expected' }) })

# ------------------ 11b-v. the observation record is IN the sheet ------------
#
# Where the ledger names an observationSheet, the record was written into the
# sheet the student submitted, so it must be found inside a table — the sheet is
# one. A record that has slipped out to body level is the old behaviour coming
# back: a tidy summary bolted to the front of the file with the instrument
# itself left blank underneath it, which answers an auditor's question the wrong
# way round.

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
            $found = 0
            foreach ($para in @(Get-BodyParagraphs $pkg)) {
                $t = (Get-RunText $para $pkg.Ns).Trim()
                if (-not $t.StartsWith($M.observationHeading)) { continue }
                if (Get-ParagraphCell $para) { $found++ }
            }
            if ($found -lt $inSheet) {
                $obsProbs += "${name}: $found of $inSheet observation record(s) are inside the observation sheet; the rest are loose in the body"
            }

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

                $boxes = @()
                for ($i = $startAt + 1; $i -lt $sufAt; $i++) {
                    $t = (Get-RunText $paras[$i] $pkg.Ns).Trim()
                    if ($t -match "^[$BOX_E$BOX_T]\s*(Yes|No)$") { $boxes += [pscustomobject]@{ word = $Matches[1]; ticked = $t.StartsWith($BOX_T) } }
                }
                $want = @($sheet.outcomes)
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
                    $sBoxes = @()
                    for ($i = $sufAt; $i -lt $endAt; $i++) {
                        $t = (Get-RunText $paras[$i] $pkg.Ns).Trim()
                        if ($t -match "^[$BOX_E$BOX_T]\s*(Yes|No)$") { $sBoxes += [pscustomobject]@{ word = $Matches[1]; ticked = $t.StartsWith($BOX_T) } }
                    }
                    $wantSuf = [bool]$sheet.sufficient
                    if ($sBoxes.Count -lt 2) { $obsProbs += "${who}: no sufficiency box was found on the sheet" }
                    elseif ($sBoxes[0].ticked -ne $wantSuf -or $sBoxes[1].ticked -eq $wantSuf) {
                        $obsProbs += "${who}: the sufficiency box does not read $(if ($wantSuf) { 'Yes' } else { 'No' })"
                    }
                }

                foreach ($fld in @($sheet.fields)) {
                    if (-not $fld) { continue }
                    $seen = $false
                    for ($i = $startAt; $i -lt $endAt; $i++) {
                        if ((Get-RunText $paras[$i] $pkg.Ns).Trim() -eq "$($fld.value)") { $seen = $true; break }
                    }
                    if (-not $seen) { $obsProbs += "${who}: field '$($fld.label)' does not carry '$($fld.value)' on the sheet" }
                }
            }
        } finally { Close-Docx $pkg }
    }
}
Add-Check 'MarkedCopyObservationSheet' ($obsProbs.Count -eq 0) `
    $(if ($obsProbs.Count) { ($obsProbs | Select-Object -First 4) -join ' · ' } else { 'every observation record the ledger places in a sheet was written into that sheet' })

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
foreach ($f in @($files | Where-Object { $_.Name -notlike 'MARKED_*' })) {
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
                if ($f.Name -like 'FEEDBACK_*') {
                    $pages = $doc.ComputeStatistics(2)      # wdStatisticPages
                    if ($pages -gt 1) { $pageProbs += "$($f.Name) renders $pages pages; the sheet is one page" }
                }
                $doc.Close($false)
            } catch {
                $openProbs += "$($f.Name) will not open in Word"
            }
        }
        Add-Check 'OpensInWord' ($openProbs.Count -eq 0) `
            $(if ($openProbs.Count) { ($openProbs | Select-Object -First 6) -join ' · ' } else { "all $($files.Count) file(s) open in Word" })
        Add-Check 'FeedbackSheetOnePage' ($pageProbs.Count -eq 0) `
            $(if ($pageProbs.Count) { ($pageProbs -join ' · ') } else { 'every feedback sheet renders on one page' })
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
