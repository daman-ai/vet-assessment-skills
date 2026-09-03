<#
  Build-MarkedAssessment.ps1 — return the student's own assessment, marked.

  Takes the file the student submitted and produces a marked copy:

    * a DECLARATION PAGE of its own in front of the student's first page,
      carrying the overall result, the student, the qualification, the unit,
      the tools covered, the assessor, the marking date and the resubmission
      date;
    * under every question's response, inside the response box, an outcome
      line —
        green  Satisfactory
        red    Not yet Satisfactory - refer to feedback sheet
    * for an observation tool, the assessor's record written INTO the
      observation sheet the student submitted.

  The student's own words are never altered. Nothing is deleted.

  ONE MARKED COPY PER SUBMITTED FILE. Where one document carries several tools
  — UAT 1 and UAT 2 bound together, a knowledge tool and a workbook in one
  file — every tool in it is marked into that one copy. The resolver groups
  the results by the file they were read from and publishes the groups as
  'markedCopies'; this script marks one group at a time.

  WHERE THE OUTCOME LINE GOES. Each question in the ledger names an anchor —
  the text that identifies it in the submission. The outcome is inserted at the
  end of that question's response block, which puts it INSIDE the response box,
  under the student's answer, where they look for it. Get-OutcomeTargetIndex
  documents how the end of the block is found.

  This script never guesses. An anchor that is missing, or that matches more
  than one place in the document, is a hard failure naming the question — an
  outcome stamped under the wrong answer is worse than no marked copy at all.

  Usage — normally called by Build-MarkingRecords.ps1, but runs alone:
    .\Build-MarkedAssessment.ps1 -Ledger resolved.json -OutDir out
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Ledger,
    [Parameter(Mandatory)][string]$OutDir,
    [string]$RtoProfile,
    [string]$SubmissionRoot,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-Docx.ps1')

$AssetRoot = Join-Path $PSScriptRoot '..\assets'

$L = Get-Content -Raw -Encoding UTF8 -LiteralPath $Ledger | ConvertFrom-Json
if (-not $L.dates) { throw 'Pass a RESOLVED ledger (Resolve-MarkingLedger.ps1 -Out).' }
if (-not $L.PSObject.Properties.Name.Contains('markedCopies')) {
    throw 'This resolved ledger predates the one-copy-per-file grouping. Re-run Resolve-MarkingLedger.ps1 to add markedCopies.'
}

if (-not $RtoProfile) { $RtoProfile = Join-Path $AssetRoot ("rto.{0}.json" -f $L.rto) }
$Rto = Get-Content -Raw -Encoding UTF8 -LiteralPath $RtoProfile | ConvertFrom-Json

$M = $Rto.markedAssessment
if (-not $M) { throw "RTO profile $RtoProfile declares no 'markedAssessment' section." }

if (-not $SubmissionRoot) { $SubmissionRoot = Split-Path -Parent (Resolve-Path -LiteralPath $Ledger).Path }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Get-ListCount {
    # @($null).Count is 1, not 0, so "has this property anything in it" answers
    # yes for a property that does not exist. Count through here instead.
    param($Value)
    if ($null -eq $Value) { return 0 }
    @($Value | Where-Object { $null -ne $_ }).Count
}

function Test-ParagraphInTextBox {
    <#
      True where a paragraph sits inside a floating text box or shape rather
      than in the body's own flow.

      An outcome line written into one of these prints inside the shape, not
      under the student's answer, so the student never sees the judgement where
      they look for it. It also makes the line count wrong: Word reports the
      containing body paragraph's text as including the box's text, so one
      inserted line reads as two and the gate refuses the build.

      Students paste organisational charts and diagrams into their assessments,
      and an empty leftover shape between two questions is enough to trigger it.
    #>
    param($Paragraph)
    $n = $Paragraph.ParentNode
    while ($n -and $n.Name -ne 'w:body') {
        if ($n.LocalName -eq 'txbxContent') { return $true }
        $n = $n.ParentNode
    }
    $false
}

function Get-ParagraphTable {
    <#
      The <w:tbl> a paragraph sits in, or $null where it sits in the body flow.
      Used to keep an outcome line out of the heading rows of the NEXT
      question's table.
    #>
    param($Paragraph)
    $n = $Paragraph.ParentNode
    while ($n -and $n.Name -ne 'w:body') {
        if ($n.LocalName -eq 'tbl') { return $n }
        $n = $n.ParentNode
    }
    $null
}

function Get-OutcomeTargetIndex {
    <#
      The paragraph an outcome line goes after: the end of this question's
      response block.

      THE LINE BELONGS UNDER THE STUDENT'S ANSWER, INSIDE THE RESPONSE BOX.
      Add-ParagraphAfter inserts as a sibling, so whichever paragraph is chosen
      here decides which cell the judgement lands in. Walking back from the
      paragraph before the next question skips three kinds of thing.

        1. Floating text boxes. A line written into one prints inside the shape
           rather than under the answer, and Word then reports the containing
           paragraph as carrying both texts, so one inserted line reads as two
           and the gate refuses the build.
        2. Empty spacer paragraphs. These sit between an answer table and the
           next question in every workbook-style assessment. Landing on one puts
           the judgement below the box instead of inside it.
        3. A SHORT run of paragraphs belonging to the next question's own table
           — its "Complete the table below" line and its column headings. Those
           sit above the next answer, so a line left among them reads as a
           verdict on the wrong question.

      Rule 3 is bounded, and the bound is the whole point. Where a question's
      stem, the student's answer and the NEXT question's stem all share one
      table, skipping "everything in that table" walks straight back over the
      answer being marked. A heading block is a few paragraphs; an answer is
      many. Past the bound the skip is abandoned and the position found by rules
      1 and 2 is used, which is the end of the student's answer.
    #>
    param(
        [Parameter(Mandatory)][object[]]$Paragraphs,
        [Parameter(Mandatory)]$Ns,
        [Parameter(Mandatory)][int]$From,
        [Parameter(Mandatory)][int]$Next,
        [int]$HeadingRunLimit = 8
    )

    $ti = [Math]::Max($From, $Next - 1)
    while ($ti -gt $From -and (
            (Test-ParagraphInTextBox $Paragraphs[$ti]) -or
            [string]::IsNullOrWhiteSpace((Get-RunText -Node $Paragraphs[$ti] -Ns $Ns))
          )) { $ti-- }

    $nextTbl = if ($Next -lt $Paragraphs.Count) { Get-ParagraphTable $Paragraphs[$Next] } else { $null }
    if ($nextTbl) {
        $ni = $ti; $headingSkips = 0
        while ($ni -gt $From -and $headingSkips -le $HeadingRunLimit) {
            $tbl = Get-ParagraphTable $Paragraphs[$ni]
            if ($tbl -is [System.Xml.XmlElement] -and $tbl.Equals($nextTbl)) { $headingSkips++ }
            elseif (-not (Test-ParagraphInTextBox $Paragraphs[$ni]) -and
                    -not [string]::IsNullOrWhiteSpace((Get-RunText -Node $Paragraphs[$ni] -Ns $Ns))) { break }
            $ni--
        }
        if ($headingSkips -gt 0 -and $headingSkips -le $HeadingRunLimit) { $ti = $ni }
    }
    $ti
}

function Find-OneParagraph {
    <#
      The single paragraph containing $Text, optionally within [$From, $To).
      Ambiguity is a hard failure: silently taking the first match is how a
      judgement lands against the wrong thing.
    #>
    param(
        [Parameter(Mandatory)][object[]]$Paragraphs,
        [Parameter(Mandatory)]$Ns,
        [Parameter(Mandatory)][string]$Text,
        [int]$From = 0,
        [int]$To = -1,
        [Parameter(Mandatory)][string]$What
    )
    if ($To -lt 0) { $To = $Paragraphs.Count }
    $hits = @()
    for ($i = $From; $i -lt $To; $i++) {
        if ((Get-RunText $Paragraphs[$i] $Ns).IndexOf($Text, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $hits += $i }
    }
    if ($hits.Count -eq 0) { throw "${What}: no paragraph contains '$Text'." }
    if ($hits.Count -gt 1) { throw "${What}: '$Text' appears $($hits.Count) times in this range; give text that appears once." }
    $hits[0]
}

function Get-SheetEnd {
    <#
      The first paragraph that is NOT part of this observation sheet.

      A submission commonly carries two sheets — one per observed activity —
      and every lookup inside a sheet is bounded by this so that 'Date' or
      'Feedback to Student' cannot match the other sheet's copy of the same
      label. Without an endAnchor the sheet runs to the end of the document,
      which is right when there is only one.
    #>
    param(
        [Parameter(Mandatory)][object[]]$Paragraphs,
        [Parameter(Mandatory)]$Ns,
        [Parameter(Mandatory)]$Sheet,
        [Parameter(Mandatory)][int]$Start,
        [Parameter(Mandatory)][string]$Who
    )
    if (-not ($Sheet.PSObject.Properties.Name.Contains('endAnchor') -and $Sheet.endAnchor)) { return $Paragraphs.Count }
    for ($i = $Start + 1; $i -lt $Paragraphs.Count; $i++) {
        if ((Get-RunText $Paragraphs[$i] $Ns).IndexOf("$($Sheet.endAnchor)", [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $i }
    }
    throw "$Who / observation sheet: endAnchor '$($Sheet.endAnchor)' was not found after the sheet."
}

function Write-ObservationSheet {
    <#
      Writes the assessor's observation record INTO the observation sheet the
      student submitted, rather than bolting it to the front of the file.

      The observation sheet is the instrument. It carries the observable tasks,
      a Yes/No box for each, a notes column, a feedback line and the assessor's
      signature. An auditor asking whether the observation happened opens THAT,
      and a blank sheet with a tidy summary stapled in front of it answers no.

      Everything is addressed by text the ledger names, never by position in a
      table, because observation sheets differ between assessments and a cell
      addressed by number fills the wrong box the moment one is re-laid-out.
      The one thing counted rather than named is the run of Yes/No pairs, and
      the count is checked against the ledger before a single box is ticked.
    #>
    param(
        [Parameter(Mandatory)]$Pkg,
        [Parameter(Mandatory)]$Sheet,
        [Parameter(Mandatory)][string[]]$Observations,
        [Parameter(Mandatory)][string]$Outcome,
        [Parameter(Mandatory)][string]$MarkingDateText,
        [Parameter(Mandatory)]$Marked,
        [Parameter(Mandatory)][string]$Who
    )
    $ns    = $Pkg.Ns
    $doc   = $Pkg.Xml
    $paras = @(Get-BodyParagraphs $Pkg)

    $start = Find-OneParagraph -Paragraphs $paras -Ns $ns -Text $Sheet.anchor -What "$Who / observation sheet anchor"
    $end   = Get-SheetEnd -Paragraphs $paras -Ns $ns -Sheet $Sheet -Start $start -Who $Who

    # --- the ticks ----------------------------------------------------------
    # Collected in document order and required to alternate Yes, No, Yes, No.
    # Anything else means the paragraphs found are not a column of decision
    # boxes, and ticking them would be guesswork.
    $outcomes = @()
    if ($Sheet.PSObject.Properties.Name.Contains('outcomes') -and $Sheet.outcomes) { $outcomes = @($Sheet.outcomes) }

    $tickEnd = $end
    $sufficientAt = $null
    if ($Sheet.PSObject.Properties.Name.Contains('sufficientAnchor') -and $Sheet.sufficientAnchor) {
        $sufficientAt = Find-OneParagraph -Paragraphs $paras -Ns $ns -Text $Sheet.sufficientAnchor -From $start -To $end -What "$Who / observation sheet sufficientAnchor"
        $tickEnd = $sufficientAt
    }

    function Get-BoxWord {
        param($Para, $Ns)
        $t = (Get-RunText $Para $Ns).Trim()
        if ($t -notmatch '^[☐☒]\s*(Yes|No)$') { return $null }
        $Matches[1]
    }

    $boxes = @()
    for ($i = $start + 1; $i -lt $tickEnd; $i++) {
        $w = Get-BoxWord $paras[$i] $ns
        if ($w) { $boxes += [pscustomobject]@{ index = $i; word = $w } }
    }
    if (($boxes.Count % 2) -ne 0) {
        throw "$Who / observation sheet: found $($boxes.Count) Yes/No box(es), which is not a whole number of pairs. Check the endAnchor and the sufficientAnchor bound the sheet."
    }
    $pairs = @()
    for ($i = 0; $i -lt $boxes.Count; $i += 2) {
        if ($boxes[$i].word -ne 'Yes' -or $boxes[$i + 1].word -ne 'No') {
            throw "$Who / observation sheet: the decision boxes do not read Yes then No in order, so they cannot be paired with the ledger's outcomes."
        }
        $pairs += [pscustomobject]@{ yes = $boxes[$i].index; no = $boxes[$i + 1].index }
    }
    if ($outcomes.Count -gt 0 -and $pairs.Count -ne $outcomes.Count) {
        throw "$Who / observation sheet: the sheet has $($pairs.Count) observable task(s) but the ledger gives $($outcomes.Count) outcome(s). Give one Yes or No per task, in sheet order. Nothing was ticked."
    }
    for ($i = 0; $i -lt $outcomes.Count; $i++) {
        $want = "$($outcomes[$i])"
        [void](Set-LabelledBox -Node $paras[$pairs[$i].yes] -Ns $ns -Label 'Yes' -Ticked ($want -eq 'Yes'))
        [void](Set-LabelledBox -Node $paras[$pairs[$i].no]  -Ns $ns -Label 'No'  -Ticked ($want -eq 'No'))
    }

    if ($null -ne $sufficientAt -and $Sheet.PSObject.Properties.Name.Contains('sufficient') -and $null -ne $Sheet.sufficient) {
        $suf = @()
        for ($i = $sufficientAt; $i -lt $end; $i++) {
            $w = Get-BoxWord $paras[$i] $ns
            if ($w) { $suf += [pscustomobject]@{ index = $i; word = $w } }
        }
        if ($suf.Count -lt 2 -or $suf[0].word -ne 'Yes' -or $suf[1].word -ne 'No') {
            throw "$Who / observation sheet: no Yes/No pair follows '$($Sheet.sufficientAnchor)', so the sufficiency box cannot be ticked."
        }
        [void](Set-LabelledBox -Node $paras[$suf[0].index] -Ns $ns -Label 'Yes' -Ticked ([bool]$Sheet.sufficient))
        [void](Set-LabelledBox -Node $paras[$suf[1].index] -Ns $ns -Label 'No'  -Ticked (-not [bool]$Sheet.sufficient))
    }

    # --- the labelled fields: date, times, assessor name --------------------
    # Set-CellText clears a cell down to one paragraph, so filling a field can
    # REMOVE paragraphs. Re-read the list before each one: an index taken before
    # a removal points at a different paragraph afterwards, and every lookup
    # below it is then quietly one out.
    foreach ($fld in @($Sheet.fields)) {
        if (-not $fld) { continue }
        $paras = @(Get-BodyParagraphs $Pkg)
        $start = Find-OneParagraph -Paragraphs $paras -Ns $ns -Text $Sheet.anchor -What "$Who / observation sheet anchor"
        $end   = Get-SheetEnd -Paragraphs $paras -Ns $ns -Sheet $Sheet -Start $start -Who $Who
        $at   = Find-OneParagraph -Paragraphs $paras -Ns $ns -Text "$($fld.label)" -From $start -To $end -What "$Who / observation sheet field '$($fld.label)'"
        $cell = Get-ParagraphCell $paras[$at]
        if (-not $cell) {
            throw "$Who / observation sheet: field '$($fld.label)' is not in a table, so there is no cell beside it to write '$($fld.value)' into."
        }
        $target = Get-NextCellInRow -Cell $cell -Ns $ns
        if (-not $target) {
            throw "$Who / observation sheet: field '$($fld.label)' is the last cell in its row, so there is nowhere to write '$($fld.value)'."
        }
        [void](Set-CellText -Cell $target -Ns $ns -Value "$($fld.value)" -Color '000000')
    }

    # --- the record itself --------------------------------------------------
    # Inserted after notesAnchor, which is inside the sheet, so it lands in the
    # sheet's own notes cell rather than in the body after the table.
    $paras   = @(Get-BodyParagraphs $Pkg)
    $start   = Find-OneParagraph -Paragraphs $paras -Ns $ns -Text $Sheet.anchor -What "$Who / observation sheet anchor"
    $end     = Get-SheetEnd -Paragraphs $paras -Ns $ns -Sheet $Sheet -Start $start -Who $Who
    $notesAt = Find-OneParagraph -Paragraphs $paras -Ns $ns -Text $Sheet.notesAnchor -From $start -To $end -What "$Who / observation sheet notesAnchor"
    $after   = $paras[$notesAt]

    $lines = @()
    $lines += New-TextParagraph -Doc $doc -Text $Marked.observationHeading -Color $Marked.headingColor -Bold -SpaceBefore 80 -SpaceAfter 60
    foreach ($point in $Observations) {
        $lines += New-TextParagraph -Doc $doc -Text ("{0}  {1}" -f $Marked.observationBullet, $point) -Color '000000' -SpaceBefore 0 -SpaceAfter 40
    }
    $lines += New-TextParagraph -Doc $doc -Text ("{0}  {1}" -f $Marked.observationCompletedText, $MarkingDateText) -Color $Marked.headingColor -SpaceBefore 40 -SpaceAfter 60
    $outcomeText   = if ($Outcome -eq 'S') { $Marked.satisfactoryText }  else { $Marked.notSatisfactoryText }
    $outcomeColour = if ($Outcome -eq 'S') { $Marked.satisfactoryColor } else { $Marked.notSatisfactoryColor }
    $lines += New-TextParagraph -Doc $doc -Text $outcomeText -Color $outcomeColour -Bold -SpaceBefore 80 -SpaceAfter 80

    foreach ($line in $lines) { $after = Add-ParagraphAfter -Anchor $after -NewParagraph $line }

    # --- feedback to the student, on the sheet's own feedback line ----------
    if ($Sheet.PSObject.Properties.Name.Contains('feedback') -and $Sheet.feedback) {
        $paras = @(Get-BodyParagraphs $Pkg)          # the inserts above moved everything
        $start = Find-OneParagraph -Paragraphs $paras -Ns $ns -Text $Sheet.anchor -What "$Who / observation sheet anchor"
        $fbEnd = Get-SheetEnd -Paragraphs $paras -Ns $ns -Sheet $Sheet -Start $start -Who $Who
        $fbAt  = Find-OneParagraph -Paragraphs $paras -Ns $ns -Text $Sheet.feedbackAnchor -From $start -To $fbEnd -What "$Who / observation sheet feedbackAnchor"
        $cell = Get-ParagraphCell $paras[$fbAt]
        $next = if ($cell) { Get-NextCellInRow -Cell $cell -Ns $ns } else { $null }
        if ($next) {
            [void](Set-CellText -Cell $next -Ns $ns -Value "$($Sheet.feedback)" -Color '000000')
        } else {
            $fb = New-TextParagraph -Doc $doc -Text "$($Sheet.feedback)" -Color '000000' -SpaceBefore 40 -SpaceAfter 60
            [void](Add-ParagraphAfter -Anchor $paras[$fbAt] -NewParagraph $fb)
        }
    }

    $pairs.Count
}

function Resolve-Submission {
    param([string]$Evidence)
    if (-not $Evidence) { return $null }
    if (Test-Path -LiteralPath $Evidence) { return (Resolve-Path -LiteralPath $Evidence).Path }
    $joined = Join-Path $SubmissionRoot $Evidence
    if (Test-Path -LiteralPath $joined) { return (Resolve-Path -LiteralPath $joined).Path }
    $null
}

$built        = @()
$skipped      = @()
$lastWarnings = @()

# Report every tool that gets no marked copy, and why. The resolver has already
# decided which files exist; this is the human-readable other half of the same
# decision, so nothing is passed over in silence.
$studentsById = @{}
foreach ($s in @($L.students)) {
    $studentsById[$s.studentId] = $s
    foreach ($res in @($s.results)) {
        if (-not $res.submitted) {
            $skipped += "$($s.fullName) / $($res.toolName): nothing submitted, so there is no assessment to mark"
        } elseif ((Get-ListCount $res.questions) -eq 0 -and (Get-ListCount $res.observations) -eq 0) {
            $skipped += "$($s.fullName) / $($res.toolName): no per-question outcomes and no observation record in the ledger, so no marked copy"
        } elseif (-not $res.evidence) {
            $skipped += "$($s.fullName) / $($res.toolName): outcomes were recorded but no evidence file is named, so there is no document to return"
        }
    }
}

foreach ($mc in @($L.markedCopies)) {

    $s = $studentsById[$mc.studentId]
    if (-not $s) { throw "markedCopies names student '$($mc.studentId)', who is not in the ledger." }

    # In the order the tools were declared, so a copy covering UAT 1 and UAT 2
    # names them in that order on its declaration page.
    $group = @()
    foreach ($tid in @($mc.toolIds)) {
        $r = @($s.results | Where-Object { $_.toolId -eq $tid })
        if ($r.Count -ne 1) { throw "$($s.fullName): expected one result for tool '$tid', found $($r.Count)." }
        $group += $r[0]
    }

    $src = Resolve-Submission $mc.evidence
    if (-not $src) {
        throw "$($s.fullName) / $(($mc.toolNames) -join ' + '): the ledger records outcomes for this file but '$($mc.evidence)' cannot be found. A marked copy cannot be produced from a file that is not there."
    }
    if ([System.IO.Path]::GetExtension($src).ToLower() -ne '.docx') {
        throw "$($s.fullName) / $(($mc.toolNames) -join ' + '): '$src' is not a .docx. Convert the submission to Word before marking it."
    }

    $pkg = Open-Docx -Path $src
    try {
        $ns  = $pkg.Ns
        $doc = $pkg.Xml

        $totalS = 0; $totalNys = 0; $totalQ = 0
        $appendObs = @()          # records with no sheet to write into
        $sheetsWritten = 0

        foreach ($res in $group) {

            $questions = @()
            if ($res.PSObject.Properties.Name.Contains('questions') -and $res.questions) { $questions = @($res.questions) }

            # Re-read the paragraph list for EVERY tool. A previous tool's
            # outcome lines are new paragraphs, so indices taken before them are
            # stale by exactly the number inserted above the point in question —
            # which is a silent off-by-n, not an error.
            $paras = @(Get-BodyParagraphs $pkg)

            $located  = @()
            $problems = @()
            foreach ($q in $questions) {
                $anchorText = if ($q.PSObject.Properties.Name.Contains('anchor') -and $q.anchor) { $q.anchor } else { $q.ref }
                $hits = @(Find-ParagraphIndex -Paragraphs $paras -Ns $ns -Text $anchorText)
                if ($hits.Count -eq 0) {
                    $problems += "question '$($q.ref)': no paragraph contains '$anchorText'"
                } elseif ($hits.Count -gt 1) {
                    $problems += "question '$($q.ref)': '$anchorText' appears $($hits.Count) times; give it a unique 'anchor' in the ledger"
                } else {
                    $located += [pscustomobject]@{ ref = $q.ref; outcome = $q.outcome; index = $hits[0] }
                }
            }
            if ($problems.Count) {
                throw ("$($s.fullName) / $($res.toolName): cannot mark this submission.`n  " + ($problems -join "`n  ") + "`nNothing was written. Fix the anchors and run again.")
            }

            $located = @($located | Sort-Object index)

            # Where the LAST question's response ends. Every other question is
            # bounded by the next question's anchor. The last one has no next
            # anchor, so without help its outcome lands after whatever trails
            # the assessment — 'End of assessment', a declaration block, a
            # signature table. The ledger names the first paragraph that is NOT
            # part of the last answer; failing that the end of the document is
            # used, and the build says so, because a silently misplaced last
            # outcome looks exactly like a correct one.
            $tail = $paras.Count
            $endAnchor = if ($res.PSObject.Properties.Name.Contains('questionsEndAnchor')) { $res.questionsEndAnchor } else { $null }
            if ($located.Count -gt 0) {
                if ($endAnchor) {
                    $endHits = @(Find-ParagraphIndex -Paragraphs $paras -Ns $ns -Text $endAnchor)
                    $after = @($endHits | Where-Object { $_ -gt $located[$located.Count - 1].index })
                    if ($after.Count -eq 0) {
                        throw "$($s.fullName) / $($res.toolName): questionsEndAnchor '$endAnchor' was not found after the last question. Nothing was written."
                    }
                    $tail = $after[0]
                } else {
                    $lastWarnings += "$($s.fullName) / $($res.toolName): no questionsEndAnchor, so '$($located[$located.Count-1].ref)' was marked at the end of the document. Check where its outcome landed."
                }
            }

            # Insert from the BOTTOM up so the earlier indices stay valid.
            for ($i = $located.Count - 1; $i -ge 0; $i--) {
                $q    = $located[$i]
                $next = if ($i -lt $located.Count - 1) { $located[$i + 1].index } else { $tail }

                $ti     = Get-OutcomeTargetIndex -Paragraphs $paras -Ns $ns -From $q.index -Next $next
                $target = $paras[$ti]

                $isS  = ($q.outcome -eq 'S')
                $text = if ($isS) { $M.satisfactoryText } else { $M.notSatisfactoryText }
                $col  = if ($isS) { $M.satisfactoryColor } else { $M.notSatisfactoryColor }

                $line = New-TextParagraph -Doc $doc -Text $text -Color $col -Bold `
                                          -SpaceBefore 80 -SpaceAfter 80
                [void](Add-ParagraphAfter -Anchor $target -NewParagraph $line)
            }

            $totalQ   += $located.Count
            $totalS   += @($located | Where-Object { $_.outcome -eq 'S' }).Count
            $totalNys += @($located | Where-Object { $_.outcome -eq 'NYS' }).Count

            # --- the assessor's observation record ---------------------------
            $obs = @()
            if ($res.PSObject.Properties.Name.Contains('observations') -and $res.observations) { $obs = @($res.observations) }
            if ($obs.Count -gt 0) {
                $sheet = $null
                if ($res.PSObject.Properties.Name.Contains('observationSheet') -and $res.observationSheet) { $sheet = $res.observationSheet }
                if ($sheet) {
                    [void](Write-ObservationSheet -Pkg $pkg -Sheet $sheet -Observations ([string[]]$obs) `
                                                  -Outcome $res.result -MarkingDateText $L.dates.markingDateText `
                                                  -Marked $M -Who "$($s.fullName) / $($res.toolName)")
                    $sheetsWritten++
                } else {
                    # The submission carries no observation sheet, which the
                    # ledger had to say explicitly. The record goes on the
                    # declaration page instead — still in the file, still
                    # signed for, just not in an instrument that is not there.
                    $appendObs += [pscustomobject]@{ toolName = $res.toolName; points = $obs; result = $res.result }
                }
                if ($res.result -eq 'S') { $totalS++ } else { $totalNys++ }
            }
        }

        # ---- the declaration page --------------------------------------------
        # A PAGE OF ITS OWN, not a block squeezed onto the student's cover sheet.
        # The cover sheet is the student's document: their name, their signature,
        # their declaration that the work is their own. Writing over the top of
        # it crowds both and leaves the result competing with their own heading.
        # A separate first page gives the result room and returns the student's
        # own page one exactly as they submitted it.
        $overallText = if ($s.overall -eq 'C') { $M.overallCompetentText } else { $M.overallNotCompetentText }
        $overallCol  = if ($s.overall -eq 'C') { $M.satisfactoryColor }    else { $M.notSatisfactoryColor }

        # The block is body-level text, so it lands on the section's text margin
        # — while the student's own content sits on the edges its tables set with
        # w:tblInd, which is usually somewhere else entirely. Left alone, the
        # declaration page sits visibly out of line with every page beneath it.
        # Measure the content box and put the block on it. $fit is empty where
        # there is nothing to measure, and the block stays on the margin.
        $box = Get-BodyContentBox -Pkg $pkg
        $fit = @{}
        if ($box) { $fit = @{ IndentLeft = $box.IndentLeft; IndentRight = $box.IndentRight } }

        $header = @()

        # The overall result goes FIRST and RIGHT-ALIGNED, so it sits in the top
        # right corner of the declaration page — the first thing a student sees
        # when they open their returned assessment. Green for Competent, red for
        # Not Yet Competent, and the words carry the meaning on their own so a
        # greyscale print or a reader who cannot separate the two colours loses
        # nothing.
        $header += New-TextParagraph -Doc $doc -Text $overallText -Color $overallCol -Bold -SizeHalfPoints 32 -SpaceBefore 0 -SpaceAfter 160 -Align 'right' @fit

        $header += New-TextParagraph -Doc $doc -Text $M.frontTitle -Color $M.headingColor -Bold -SizeHalfPoints 28 -SpaceBefore 0 -SpaceAfter 160 @fit
        $header += New-TextParagraph -Doc $doc -Text ("Student:  {0}  ·  {1}" -f $s.fullName, $s.studentId) -Color '000000' -SizeHalfPoints 22 -SpaceBefore 0 -SpaceAfter 60 @fit
        $header += New-TextParagraph -Doc $doc -Text ("Qualification:  {0} {1}" -f $L.qualification.code, $L.qualification.title) -Color '000000' -SizeHalfPoints 22 -SpaceBefore 0 -SpaceAfter 60 @fit
        $header += New-TextParagraph -Doc $doc -Text ("Unit:  {0} {1}" -f $L.unit.code, $L.unit.title) -Color '000000' -SizeHalfPoints 22 -SpaceBefore 0 -SpaceAfter 60 @fit
        $header += New-TextParagraph -Doc $doc -Text ("Assessment:  {0}" -f (($mc.toolNames) -join '  ·  ')) -Color '000000' -SizeHalfPoints 22 -SpaceBefore 0 -SpaceAfter 60 @fit
        $header += New-TextParagraph -Doc $doc -Text ("Assessor:  {0}  ·  Date of marking: {1}" -f $L.assessor, $L.dates.markingDateText) -Color '000000' -SizeHalfPoints 22 -SpaceBefore 0 -SpaceAfter 60 @fit
        $header += New-TextParagraph -Doc $doc -Text ("Resubmission due:  {0}" -f $s.resubmissionDueText) -Color '000000' -SizeHalfPoints 22 -SpaceBefore 0 -SpaceAfter 160 @fit
        if ($s.overall -ne 'C') {
            $header += New-TextParagraph -Doc $doc -Text $M.referralText -Color $M.notSatisfactoryColor -SizeHalfPoints 22 -SpaceBefore 0 -SpaceAfter 120 @fit
        } else {
            $header += New-TextParagraph -Doc $doc -Text '' -Color '000000' -SizeHalfPoints 22 -SpaceBefore 0 -SpaceAfter 120 @fit
        }

        foreach ($a in $appendObs) {
            $header += New-TextParagraph -Doc $doc -Text ("{0} — {1}" -f $M.observationHeading, $a.toolName) -Color $M.headingColor -Bold -SizeHalfPoints 24 -SpaceBefore 80 -SpaceAfter 60 @fit
            foreach ($point in $a.points) {
                $header += New-TextParagraph -Doc $doc -Text ("{0}  {1}" -f $M.observationBullet, $point) -Color '000000' -SizeHalfPoints 22 -SpaceBefore 0 -SpaceAfter 40 @fit
            }
            $header += New-TextParagraph -Doc $doc -Text ("{0}  {1}" -f $M.observationCompletedText, $L.dates.markingDateText) -Color $M.headingColor -SizeHalfPoints 22 -SpaceBefore 40 -SpaceAfter 60 @fit
            $aText = if ($a.result -eq 'S') { $M.satisfactoryText }  else { $M.notSatisfactoryText }
            $aCol  = if ($a.result -eq 'S') { $M.satisfactoryColor } else { $M.notSatisfactoryColor }
            $header += New-TextParagraph -Doc $doc -Text $aText -Color $aCol -Bold -SpaceBefore 0 -SpaceAfter 120 @fit
        }

        # The page break is what makes it a page. Without it the declaration
        # runs straight into the student's cover sheet and the whole point of
        # the change is lost.
        $header += New-PageBreakParagraph -Doc $doc

        $first = $pkg.Body.FirstChild
        foreach ($h in $header) { [void]$pkg.Body.InsertBefore($h, $first) }

        # ---- save -----------------------------------------------------------
        $dest = Join-Path $OutDir $mc.file
        [void](Save-Docx -Package $pkg -Destination $dest)
        $built += [pscustomobject]@{
            path      = $dest
            student   = $s.fullName
            studentId = $s.studentId
            tools     = @($mc.toolNames)
            questions = $totalQ
            s         = $totalS
            nys       = $totalNys
            sheets    = $sheetsWritten
            appended  = $appendObs.Count
            overall   = $s.overall
        }
    } catch { Close-Docx $pkg; throw }
}

if (-not $Quiet) {
    Write-Output ''
    foreach ($b in $built) {
        $what = @()
        if ($b.questions -gt 0) { $what += "{0} question(s): {1} S, {2} NYS" -f $b.questions, $b.s, $b.nys }
        if ($b.sheets   -gt 0)  { $what += "{0} observation sheet(s) completed" -f $b.sheets }
        if ($b.appended -gt 0)  { $what += "{0} observation record(s) on the declaration page" -f $b.appended }
        if (@($b.tools).Count -gt 1) { $what += "{0} tools in one file" -f @($b.tools).Count }
        Write-Output ("  MARKED    {0,-52} {1}  ·  overall {2}" -f (Split-Path -Leaf $b.path), ($what -join '  ·  '), $b.overall)
    }
    foreach ($k in $skipped)      { Write-Output ("  skipped   {0}" -f $k) }
    foreach ($k in $lastWarnings) { Write-Output ("  CHECK     {0}" -f $k) }
    Write-Output ''
    Write-Output ("{0} marked assessment copy/copies written." -f $built.Count)
}

$built
