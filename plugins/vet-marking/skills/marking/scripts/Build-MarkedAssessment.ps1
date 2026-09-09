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
. (Join-Path $PSScriptRoot 'Lib-Text.ps1')

$AssetRoot = Join-Path $PSScriptRoot '..\assets'

# Page one of every marked copy. Its title, section headings and standing lines
# come from the RTO profile's markedAssessment.feedbackPage, which carries that
# RTO's own Student Feedback Sheet wording — the same document a student with
# nothing to return receives on its own.
$ITEM_CAP = 10

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

function Resolve-CoverValue {
    <#
      A cover sheet field's value, with the ledger's tokens filled in. The
      tokens exist so the cover-sheet map is written once for a pack and holds
      for every student in the class.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Raw,
        [Parameter(Mandatory)]$Student,
        [Parameter(Mandatory)]$Ledger,
        [string[]]$ToolNames = @()
    )
    $map = [ordered]@{
        '{{studentName}}'       = $Student.fullName
        '{{studentId}}'         = $Student.studentId
        '{{unit}}'              = ("{0} {1}" -f $Ledger.unit.code, $Ledger.unit.title)
        '{{unitCode}}'          = $Ledger.unit.code
        '{{qualification}}'     = ("{0} {1}" -f $Ledger.qualification.code, $Ledger.qualification.title)
        '{{qualificationCode}}' = $Ledger.qualification.code
        '{{assessor}}'          = $Ledger.assessor
        '{{markingDate}}'       = $Ledger.dates.markingDateText
        '{{assessmentDate}}'    = $Ledger.dates.assessmentDateText
        '{{dueDate}}'           = $Ledger.dates.dueDateText
        '{{resubmissionDue}}'   = $Student.resubmissionDueText
        '{{overall}}'           = $Student.overall
        '{{tools}}'             = ($ToolNames -join '  ·  ')
    }
    $v = "$Raw"
    foreach ($k in $map.Keys) { $v = $v.Replace($k, "$($map[$k])") }
    if ($v -match '\{\{[A-Za-z]+\}\}') {
        throw "cover sheet: '$Raw' names a field this skill does not know. Known: $(($map.Keys) -join ', ')."
    }
    $v
}

function Write-CoverSheet {
    <#
      Fills the ASSESSMENT COVER SHEET at the front of the student's own
      submission — the student ID, the due date, the qualification, the trainer,
      the assessment type box.

      WHY THE ASSESSOR FILLS IT. The cover sheet is the first page an auditor
      turns to, and half its fields are the RTO's to complete rather than the
      student's. A returned assessment whose Trainer / Assessor line is blank
      records that nobody was responsible for marking it.

      Two rules keep it honest:

        * A cell the student already filled is LEFT ALONE. Their words are not
          ours to restate, and 'Ramandeep Singh' does not need correcting to
          'Ramandeep SINGH'.
        * Nothing is left blank. After the named fields are written, every
          label on the sheet is checked for a value, and one without a value is
          a hard failure naming it — including a label this map never mentioned.
    #>
    param(
        [Parameter(Mandatory)]$Pkg,
        [Parameter(Mandatory)]$Cover,
        [Parameter(Mandatory)]$Student,
        [Parameter(Mandatory)]$Ledger,
        [string[]]$ToolNames = @(),
        [Parameter(Mandatory)][string]$Who
    )
    $ns    = $Pkg.Ns
    $paras = @(Get-BodyParagraphs $Pkg)

    $start = Find-OneParagraph -Paragraphs $paras -Ns $ns -Text $Cover.anchor -What "$Who / cover sheet anchor"
    $end   = Get-SheetEnd -Paragraphs $paras -Ns $ns -Sheet $Cover -Start $start -Who "$Who / cover sheet"

    $index = @{}
    for ($i = 0; $i -lt $paras.Count; $i++) { $index[$paras[$i]] = $i }

    # The anchor may name the sheet's heading — a paragraph above the table — or
    # a line inside the table itself, which is what a sheet with no heading of
    # its own leaves to name. Both have to reach the same table, so the anchor's
    # OWN table counts as well as the tables after it.
    $ownTable = Get-ParagraphTable $paras[$start]

    $rows = @()
    foreach ($tbl in @(Get-Tables $Pkg)) {
        $isOwn = ($ownTable -is [System.Xml.XmlElement] -and $tbl.Equals($ownTable))
        if (-not $isOwn) {
            $firstPara = $tbl.SelectSingleNode('.//w:p', $ns)
            if (-not $firstPara -or -not $index.ContainsKey($firstPara)) { continue }
            $at = $index[$firstPara]
            if ($at -lt $start -or $at -ge $end) { continue }
        }
        foreach ($tr in @(Get-Rows $tbl $ns)) { $rows += ,@(Get-Cells $tr $ns) }
    }
    if ($rows.Count -eq 0) {
        throw "$Who / cover sheet: no table was found at '$($Cover.anchor)'. The cover sheet is filled cell by cell, so it has to be one."
    }

    $filled = 0
    foreach ($fld in @($Cover.fields)) {
        if (-not $fld) { continue }
        $label = "$($fld.label)"
        $value = Resolve-CoverValue -Raw "$($fld.value)" -Student $Student -Ledger $Ledger -ToolNames $ToolNames
        if (-not "$value".Trim()) { throw "$Who / cover sheet: field '$label' resolves to nothing." }

        $hit = $null
        foreach ($cells in $rows) {
            for ($i = 0; $i -lt $cells.Count; $i++) {
                $t = (("$($cells[$i].InnerText)") -replace '\s+', ' ').Trim()
                if ($t -eq $label -or $t.StartsWith($label, [StringComparison]::OrdinalIgnoreCase)) {
                    $hit = [pscustomobject]@{ cells = $cells; at = $i; text = $t }
                    break
                }
            }
            if ($hit) { break }
        }
        if (-not $hit) { throw "$Who / cover sheet: no cell reads '$label'." }

        if ($hit.at -lt ($hit.cells.Count - 1)) {
            $target  = $hit.cells[$hit.at + 1]
            $current = (("$($target.InnerText)") -replace '\s+', ' ').Trim()
            if ($current) { $filled++; continue }            # the student filled it
            [void](Set-CellText -Cell $target -Ns $ns -Value $value -Color '000000')
        }
        else {
            # The label is the last cell in its row — ACI's 'Due Date:' spans to
            # the edge — so the value goes into that same cell, after the label.
            $current = $hit.text
            if ($current -ne $label -and $current.Length -gt $label.Length) { $filled++; continue }
            [void](Set-CellText -Cell $hit.cells[$hit.at] -Ns $ns -Value ("{0} {1}" -f $label, $value) -Color '000000')
        }
        $filled++
    }

    foreach ($box in @($Cover.boxes)) {
        if (-not $box) { continue }
        $label  = "$($box.label)"
        $ticked = $false
        if ($box.PSObject.Properties.Name.Contains('whenAttempt') -and $null -ne $box.whenAttempt) {
            $ticked = ([int]$Student.attempt -eq [int]$box.whenAttempt)
        } elseif ($box.PSObject.Properties.Name.Contains('ticked')) {
            $ticked = [bool]$box.ticked
        }
        if (-not $ticked) { continue }

        # The cover sheet's boxes are not the ballot boxes the rest of the
        # marking uses: ACI prints U+25A1 WHITE SQUARE. Try each glyph the
        # sheets in circulation use, and fail rather than tick nothing.
        $done = 0
        foreach ($cells in $rows) {
            foreach ($cell in $cells) {
                $t = (("$($cell.InnerText)") -replace '\s+', ' ').Trim()
                if ($t.IndexOf($label, [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
                foreach ($glyph in @($script:BOX_EMPTY, [char]0x25A1, [char]0x25FB, [char]0x2751)) {
                    $done += Set-TextInNode -Node $cell -Ns $ns -Find ("{0} {1}" -f $glyph, $label) -Replace ("{0} {1}" -f $script:BOX_TICKED, $label) -Limit 1
                    if ($done -gt 0) { break }
                }
                if ($done -gt 0) { break }
            }
            if ($done -gt 0) { break }
        }

        # THE LABEL IS THERE BUT THE BOX IS NOT. Students edit these sheets, and
        # one of them deletes the glyph in front of 'First submission' while
        # leaving the words. Refusing here would block a whole marked copy over
        # a character the student removed, and ticking nothing would return a
        # cover sheet that does not say which submission this is. So the box is
        # put back, ticked, in front of the label it belongs to. The empty
        # glyphs above are tried first, and this only runs when none of them is
        # present anywhere on the sheet.
        if ($done -lt 1) {
            foreach ($cells in $rows) {
                foreach ($cell in $cells) {
                    $t = (("$($cell.InnerText)") -replace '\s+', ' ').Trim()
                    if ($t.IndexOf($label, [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
                    $done += Set-TextInNode -Node $cell -Ns $ns -Find $label -Replace ("{0} {1}" -f $script:BOX_TICKED, $label) -Limit 1
                    if ($done -gt 0) { break }
                }
                if ($done -gt 0) { break }
            }
        }

        if ($done -lt 1) { throw "$Who / cover sheet: the box '$label' was not found, so it could not be ticked." }
    }

    # Nothing left blank — including a label this map never named.
    $blank = @()
    foreach ($cells in $rows) {
        for ($i = 0; $i -lt $cells.Count; $i++) {
            $t = (("$($cells[$i].InnerText)") -replace '\s+', ' ').Trim()
            if (-not $t.EndsWith(':')) { continue }
            if ($i -lt ($cells.Count - 1)) {
                $next = (("$($cells[$i + 1].InnerText)") -replace '\s+', ' ').Trim()
                if (-not $next) { $blank += $t }
            } else {
                $blank += $t                              # label alone, no value after it
            }
        }
    }
    if ($blank.Count) {
        throw "$Who / cover sheet: no value against $(($blank | Select-Object -Unique) -join ', '). Every field on the cover sheet is filled before the assessment goes back."
    }
    $filled
}

function Test-LoneBoxText {
    <# A cell holding a decision box and nothing else. #>
    param([string]$Text)
    $t = ("$Text" -replace '\s+', '').Trim()
    ($t -eq "$($script:BOX_EMPTY)" -or $t -eq "$($script:BOX_TICKED)")
}

function Test-DecisionCellText {
    <#
      A cell that carries this sheet's decision and nothing else.

      'box'  — the cell holds a lone ballot box, the shape most sheets print.

      'word' — the cell holds no box at all. ACI's CPCCCM2012 performance
               criteria checklist heads two columns 'Yes' and 'No' and leaves
               both cells EMPTY, and the assessor types the column's word into
               one of them. The previously marked copies in circulation show
               exactly that: 'yes' typed in the Yes cell, the No cell left
               empty. An empty cell is therefore a decision cell here, and so
               is one already carrying the word — a box reader looking for a
               glyph finds neither and silently returns no rows, which leaves
               every criterion on a signed sheet unjudged.
    #>
    param([string]$Text, [string]$Style = 'box', [string]$Word = '')
    $t = ("$Text" -replace '\s+', '').Trim()
    if ($Style -eq 'word') {
        if ($t -eq '') { return $true }
        if ($Word -and $t -eq $Word) { return $true }
        return ($t -eq "$($script:BOX_EMPTY)" -or $t -eq "$($script:BOX_TICKED)")
    }
    ($t -eq "$($script:BOX_EMPTY)" -or $t -eq "$($script:BOX_TICKED)")
}

function Get-SheetCellStyle {
    <# Which shape this sheet's decision cells are: 'box' (default) or 'word'. #>
    param($Sheet)
    if ($Sheet.PSObject.Properties.Name.Contains('cellStyle') -and $Sheet.cellStyle) {
        $s = "$($Sheet.cellStyle)".Trim().ToLowerInvariant()
        if (@('box', 'word') -notcontains $s) {
            throw "observation sheet: unknown cellStyle '$s'. Use 'box' for a cell holding a ballot box, or 'word' for an empty cell the assessor types the column's word into."
        }
        return $s
    }
    'box'
}

function Get-ColumnSheetRows {
    <#
      Reads a COLUMN-STYLE observation sheet — the shape ACI's construction
      packs use, and the shape the labelled reader cannot see.

      A labelled sheet writes its decision as the box's own text: '☐ Yes'. A
      column sheet puts 'Yes' and 'No' in a heading row and leaves a bare '☐' in
      each cell beneath, so the box paragraph carries no label at all and the
      labelled reader finds nothing to tick. It returns silently, which is the
      failure that looks most like success: every box on a signed sheet still
      empty.

      WHICH COLUMN MEANS YES IS READ FROM THE HEADING ROW, never from position.
      A sheet that gains a column, or lists No before Yes, must not shift the
      ticks one to the left. The first column is the criterion, whatever it is
      headed — ACI's own sheet heads four sections 'Criteria' and the fifth
      'Skill'.

      A heading row is any row carrying both heading texts; the criterion rows
      are the rows after it whose Yes and No cells hold a lone box. Anything
      else in the table — a section title spanning the row, a note, a blank
      spacer row — is skipped rather than counted, because a miscount here
      silently pairs the ledger's outcomes with the wrong criteria.

      Returns one entry per criterion row, in sheet order: the criterion text
      and the Yes, No and comments CELLS. Cells, not indices — writing a comment
      removes paragraphs, and an index taken before that points somewhere else
      afterwards.
    #>
    param(
        [Parameter(Mandatory)]$Pkg,
        [Parameter(Mandatory)]$Ns,
        [Parameter(Mandatory)]$Sheet,
        [Parameter(Mandatory)][int]$StartAt,
        [Parameter(Mandatory)][int]$EndAt,
        [Parameter(Mandatory)][string]$Who
    )
    $yesHeader      = if ($Sheet.PSObject.Properties.Name.Contains('yesHeader')      -and $Sheet.yesHeader)      { "$($Sheet.yesHeader)" }      else { 'Yes' }
    $noHeader       = if ($Sheet.PSObject.Properties.Name.Contains('noHeader')       -and $Sheet.noHeader)       { "$($Sheet.noHeader)" }       else { 'No' }
    $commentsHeader = if ($Sheet.PSObject.Properties.Name.Contains('commentsHeader') -and $Sheet.commentsHeader) { "$($Sheet.commentsHeader)" } else { 'Comments' }
    $cellStyle      = Get-SheetCellStyle $Sheet

    $paras = @(Get-BodyParagraphs $Pkg)
    $index = @{}
    for ($i = 0; $i -lt $paras.Count; $i++) { $index[$paras[$i]] = $i }

    $out = @()
    foreach ($tbl in @(Get-Tables $Pkg)) {
        $firstPara = $tbl.SelectSingleNode('.//w:p', $Ns)
        if (-not $firstPara -or -not $index.ContainsKey($firstPara)) { continue }
        $at = $index[$firstPara]
        if ($at -le $StartAt -or $at -ge $EndAt) { continue }

        $cols = $null
        foreach ($tr in @(Get-Rows $tbl $Ns)) {
            $cells = @(Get-Cells $tr $Ns)
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
            if (-not (Test-DecisionCellText -Text $texts[$cols.yes] -Style $cellStyle -Word $yesHeader)) { continue }
            if (-not (Test-DecisionCellText -Text $texts[$cols.no]  -Style $cellStyle -Word $noHeader))  { continue }

            $out += [pscustomobject]@{
                criterion = $texts[0]
                yes       = $cells[$cols.yes]
                no        = $cells[$cols.no]
                comments  = $(if ($cols.comments -ge 0 -and $cols.comments -lt $cells.Count) { $cells[$cols.comments] } else { $null })
            }
        }
    }
    # Emitted as items, not as one array object. Returning ',@($out)' from here
    # protects a one-row list from unrolling and, at a caller that already wraps
    # the call in @(), turns TWENTY-EIGHT rows into a single element holding an
    # array — which reads downstream as a sheet with one criterion on it.
    @($out)
}

function Get-InlinePairRows {
    <#
      Reads an INLINE-PAIR observation sheet — the shape ACI's older CPCC packs
      use, and the shape neither other reader can see.

      A labelled sheet writes each decision as its own paragraph, '☐ Yes'. A
      column sheet heads two columns and leaves a bare box in each cell. This
      one has ONE decision column, and both boxes live inside that single cell
      with their words beside them: '☐ S ☐ NS'. The labelled reader finds no
      paragraph that is only a box and a word; the column reader finds no
      second heading to pair with the first. Both return nothing, silently,
      which leaves every criterion on a signed sheet unjudged.

      The decision column is found by its heading text, never by position, and a
      criterion row is one whose decision cell holds exactly the two labelled
      boxes and nothing else. Section titles, notes and the decision-rule row
      are skipped rather than counted.

      Returns one entry per criterion row, in sheet order: the criterion text
      and the decision and comments CELLS.
    #>
    param(
        [Parameter(Mandatory)]$Pkg,
        [Parameter(Mandatory)]$Ns,
        [Parameter(Mandatory)]$Sheet,
        [Parameter(Mandatory)][int]$StartAt,
        [Parameter(Mandatory)][int]$EndAt,
        [Parameter(Mandatory)][string]$Who
    )
    $decisionHeader = if ($Sheet.PSObject.Properties.Name.Contains('decisionHeader') -and $Sheet.decisionHeader) { "$($Sheet.decisionHeader)" } else { 'S / NS' }
    $commentsHeader = if ($Sheet.PSObject.Properties.Name.Contains('commentsHeader') -and $Sheet.commentsHeader) { "$($Sheet.commentsHeader)" } else { 'Assessor Comments' }
    $yesLabel       = if ($Sheet.PSObject.Properties.Name.Contains('yesLabel')       -and $Sheet.yesLabel)       { "$($Sheet.yesLabel)" }       else { 'S' }
    $noLabel        = if ($Sheet.PSObject.Properties.Name.Contains('noLabel')        -and $Sheet.noLabel)        { "$($Sheet.noLabel)" }        else { 'NS' }

    $paras = @(Get-BodyParagraphs $Pkg)
    $index = @{}
    for ($i = 0; $i -lt $paras.Count; $i++) { $index[$paras[$i]] = $i }

    $out = @()
    foreach ($tbl in @(Get-Tables $Pkg)) {
        $firstPara = $tbl.SelectSingleNode('.//w:p', $Ns)
        if (-not $firstPara -or -not $index.ContainsKey($firstPara)) { continue }
        $at = $index[$firstPara]
        if ($at -le $StartAt -or $at -ge $EndAt) { continue }

        $cols = $null
        foreach ($tr in @(Get-Rows $tbl $Ns)) {
            $cells = @(Get-Cells $tr $Ns)
            if ($cells.Count -eq 0) { continue }
            $texts = @($cells | ForEach-Object { ((("$($_.InnerText)") -replace '\s+', ' ').Trim()) })

            $d = [Array]::IndexOf($texts, $decisionHeader)
            if ($d -ge 0) {
                $cols = [pscustomobject]@{ decision = $d; comments = [Array]::IndexOf($texts, $commentsHeader) }
                continue
            }
            if (-not $cols) { continue }
            if ($cells.Count -le $cols.decision) { continue }
            if (-not (Test-InlinePairText -Text $texts[$cols.decision] -YesLabel $yesLabel -NoLabel $noLabel)) { continue }

            $out += [pscustomobject]@{
                criterion = $texts[0]
                decision  = $cells[$cols.decision]
                comments  = $(if ($cols.comments -ge 0 -and $cols.comments -lt $cells.Count) { $cells[$cols.comments] } else { $null })
            }
        }
    }
    @($out)
}

function Test-InlinePairText {
    <# A decision cell holding exactly '<box> <yes> <box> <no>' and nothing else. #>
    param([string]$Text, [string]$YesLabel = 'S', [string]$NoLabel = 'NS')
    $t = ("$Text" -replace '\s+', '')
    $rx = '^[' + $script:BOX_EMPTY + $script:BOX_TICKED + ']' + [regex]::Escape(($YesLabel -replace '\s+','')) +
          '[' + $script:BOX_EMPTY + $script:BOX_TICKED + ']' + [regex]::Escape(($NoLabel -replace '\s+','')) + '$'
    $t -match $rx
}

function Get-InlinePairState {
    <# Which of an inline pair's two boxes is ticked, read off the cell text. #>
    param([string]$Text)
    $t = ("$Text" -replace '\s+', '')
    $boxes = @([regex]::Matches($t, '[' + $script:BOX_EMPTY + $script:BOX_TICKED + ']') | ForEach-Object { $_.Value })
    [pscustomobject]@{
        yes = ($boxes.Count -ge 1 -and $boxes[0] -eq "$($script:BOX_TICKED)")
        no  = ($boxes.Count -ge 2 -and $boxes[1] -eq "$($script:BOX_TICKED)")
    }
}

function Set-BoxCell {
    <#
      Ticks or clears a cell holding a lone decision box, at run level, so the
      cell keeps the symbol font the box was written in. A cell that cannot be
      changed is an error and never a silent pass: this is the one place where
      doing nothing looks exactly like doing the job.
    #>
    param(
        [Parameter(Mandatory)]$Cell,
        [Parameter(Mandatory)]$Ns,
        [Parameter(Mandatory)][bool]$Ticked,
        [Parameter(Mandatory)][string]$Who,
        [Parameter(Mandatory)][int]$Row,
        [Parameter(Mandatory)][string]$Column,
        [string]$Style = 'box'
    )
    $text = ("$($Cell.InnerText)" -replace '\s+', '').Trim()

    # A 'word' cell carries no box to convert. The decision is the column's own
    # word typed into the cell, and the unchosen column is left empty — which is
    # how this sheet is completed by hand, and how the marked copies already in
    # circulation read.
    if ($Style -eq 'word') {
        $want = if ($Ticked) { $Column } else { '' }
        if ($text -eq $want) { return }                  # already reads that way
        [void](Set-CellText -Cell $Cell -Ns $Ns -Value $want -Color '000000')
        return
    }

    $from = if ($Ticked) { $script:BOX_EMPTY }  else { $script:BOX_TICKED }
    $to   = if ($Ticked) { $script:BOX_TICKED } else { $script:BOX_EMPTY }
    if ($text -eq "$to") { return }                      # already reads that way
    $n = Set-TextInNode -Node $Cell -Ns $Ns -Find "$from" -Replace "$to" -Limit 1
    if ($n -lt 1) {
        throw "$Who / observation sheet: the $Column box on criterion row $Row could not be ticked; its cell reads '$text'."
    }
}

function Write-VerificationRows {
    <#
      Fills the assessor's pre-start verification checklist — the small table
      inside an activity that reads 'Assessor / supervisor to confirm before
      commencement', with a Yes/No pair and a comments cell for each item.

      IT WAS ARRIVING BLANK. Nine untouched boxes and nine empty comment cells
      on a sheet the assessor has signed reads, to an auditor, as a check that
      nobody carried out. The ledger names each row and what was confirmed.

      FILLS WHAT IS BLANK AND OVERWRITES NOTHING. Some students complete this
      checklist on site, in their own words, before the assessor sees it. That
      is evidence. A row that already carries a decision or a note is left
      exactly as the student wrote it, and only the empty half is filled.

      Rows are addressed by the item text the ledger names, never by position.
      Returns the number of cells written.
    #>
    param(
        [Parameter(Mandatory)]$Pkg,
        [Parameter(Mandatory)]$Verification,
        [Parameter(Mandatory)][string]$Who
    )
    $ns      = $Pkg.Ns
    $written = 0
    $missing = @()

    foreach ($v in @($Verification)) {
        $item = "$($v.item)".Trim()
        if (-not $item) { continue }

        $row = $null
        foreach ($tr in @($Pkg.Body.SelectNodes('.//w:tr', $ns))) {
            $cells = @($tr.SelectNodes('w:tc', $ns))
            if ($cells.Count -lt 3) { continue }
            if ((Get-RunText $cells[0] $ns).Trim() -eq $item) { $row = $tr; break }
        }
        if (-not $row) { $missing += $item; continue }

        $cells    = @($row.SelectNodes('w:tc', $ns))
        $boxEmpty = [string][char]0x2610
        $boxTick  = [string][char]0x2612
        $decision = (Get-RunText $cells[1] $ns).Trim()
        $note     = (Get-RunText $cells[2] $ns).Trim()

        $stripped = ($decision -replace [regex]::Escape($boxEmpty), '') -replace '[\s/]', ''
        if (-not $stripped) {
            $yes = if ("$($v.outcome)" -eq 'Yes') { "$boxTick Yes / $boxEmpty No" } else { "$boxEmpty Yes / $boxTick No" }
            [void](Set-CellText -Cell $cells[1] -Ns $ns -Value $yes)
            $written++
        }
        if (-not $note -and "$($v.note)".Trim()) {
            [void](Set-CellText -Cell $cells[2] -Ns $ns -Value "$($v.note)")
            $written++
        }
    }

    if ($missing.Count -gt 0) {
        throw "${Who}: the verification checklist names row(s) that are not in this submission — $($missing -join '; '). Nothing was written."
    }
    $written
}

function Set-BoxAtIndex {
    <#
      Ticks the single box at $CharIndex of a paragraph's flattened text,
      whichever run happens to hold it. Get-RunText concatenates the w:t nodes
      with nothing between them, so the same index addresses both.
    #>
    param($Node, $Ns, [int]$CharIndex, [string]$Tick)
    $pos = 0
    foreach ($tn in @($Node.SelectNodes('.//w:t', $Ns))) {
        $s = [string]$tn.InnerText
        if ($CharIndex -lt $pos + $s.Length) {
            $off = $CharIndex - $pos
            $tn.InnerText = $s.Substring(0, $off) + $Tick + $s.Substring($off + 1)
            return $true
        }
        $pos += $s.Length
    }
    return $false
}
function Write-VerificationTable {
    <#
      Fills an assessor VERIFICATION TABLE - a table that is not an S/NS grid,
      not a Yes/No sheet and not a comments box, but still carries columns only
      the assessor may complete. CPCCCM2008 has two:

        Template 2.6 - Practical Erection Verification Log
          Scaffold feature verified by assessor | Assessor notes | Verified
        Template 3.2 - Mandatory Alteration / Repair / Rectification Log
          ... | Completed by | Assessor verification

      They sit outside every grid, so none of the three observation-sheet
      writers touches them and they went out blank under a signed result.

      Columns are found BY HEADING, never by ordinal, because the two tables
      have different shapes and learners' copies vary. A cell that already
      carries content is LEFT ALONE - a trainer who completed the sheet on the
      day keeps their entry, and this writer only fills what is empty.
    #>
    param(
        [Parameter(Mandatory)]$Pkg,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Tables,
        [Parameter(Mandatory)][string]$Who
    )
    if (@($Tables).Count -eq 0) { return 0 }
    $ns    = $Pkg.Ns
    $TICK  = [string][char]0x2612
    $EMPTY = @([string][char]0x25A1, [string][char]0x2610)
    $filled = 0

    foreach ($spec in $Tables) {
        $anchor = "$($spec.anchor)"
        if ($anchor -eq '') { throw "${Who}: a verification table has no anchor." }
        $target = $null
        foreach ($tbl in @($Pkg.Body.SelectNodes('.//w:tbl', $ns))) {
            if ((Get-RunText $tbl $ns).IndexOf($anchor, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $target = $tbl; break }
        }
        # A submission that does not carry this template at all is reported by
        # the caller, not silently skipped here.
        if (-not $target) {
            if ($spec.PSObject.Properties.Name -contains 'optional' -and $spec.optional) { continue }
            throw "${Who}: no table contains '$anchor', so its assessor columns cannot be filled."
        }

        $trs = @($target.SelectNodes('./w:tr', $ns))
        $noteCol = -1; $tickCol = -1; $hdrRow = -1
        for ($r = 0; $r -lt [math]::Min(4, $trs.Count); $r++) {
            $tc = @($trs[$r].SelectNodes('./w:tc', $ns))
            for ($c = 0; $c -lt $tc.Count; $c++) {
                $h = (Get-SnsCellText $tc[$c] $ns)
                if ($noteCol -lt 0 -and "$($spec.notesHeading)" -ne '' -and $h -match "$($spec.notesHeading)") { $noteCol = $c; $hdrRow = $r }
                if ($tickCol -lt 0 -and "$($spec.tickHeading)"  -ne '' -and $h -match "$($spec.tickHeading)")  { $tickCol = $c; $hdrRow = $r }
            }
            if ($hdrRow -ge 0) { break }
        }
        if ($hdrRow -lt 0) { throw "${Who}: '$anchor' has no column headed '$($spec.notesHeading)' or '$($spec.tickHeading)'." }

        $notes = @(); if ($spec.PSObject.Properties.Name -contains 'notes' -and $spec.notes) { $notes = @($spec.notes) }
        $i = 0
        for ($r = $hdrRow + 1; $r -lt $trs.Count; $r++) {
            $tc = @($trs[$r].SelectNodes('./w:tc', $ns))
            if ($tc.Count -le [math]::Max($noteCol, $tickCol)) { continue }
            if ((Get-SnsCellText $tc[0] $ns) -eq '') { continue }
            # the assessor's note for this row, where one is given and the cell is empty
            if ($noteCol -ge 0 -and $i -lt $notes.Count -and "$($notes[$i])".Trim() -ne '') {
                if ((Get-SnsCellText $tc[$noteCol] $ns) -eq '') {
                    [void](Set-CellText -Cell $tc[$noteCol] -Ns $ns -Value "$($notes[$i])" -Color '000000')
                    $filled++
                }
            }
            if ($tickCol -ge 0) {
                $cur = Get-SnsCellText $tc[$tickCol] $ns
                if ($cur -eq '' -or $EMPTY -contains $cur) {
                    [void](Set-CellText -Cell $tc[$tickCol] -Ns $ns -Value $TICK -Color '000000')
                    $filled++
                }
            }
            $i++
        }
    }
    $filled
}
function Write-SnsChecklist {
    <#
      Fills an observation checklist built as an S / NS TICK-BOX GRID:

          #  |  Observable behaviour  |  S  |  NS
          1  |  Reads and interprets. |  X  |  X

      This is the THIRD shape an observation sheet comes in, and neither of the
      other two writers touches it. Write-ObservationSheet pairs the box-and-word
      paragraph boxes, which this grid has none of. Write-CriterionComments walks
      a grid, but keys on a 'Trainer/Assessor Comments' column, which this grid
      does not have - its comments live in one box under the whole checklist.
      Handed this sheet, both find nothing and tick nothing, silently, which is
      the failure that looks most like success: a signed record over a blank
      instrument.

      One entry per checklist in the submission, in document order. A submission
      observed on two occasions carries two grids and needs two entries; a count
      mismatch is a hard failure rather than a half-filled sheet.

      Each entry fills four things, all addressed by the text around them rather
      than by position in the file:
        - the S or NS box on every numbered criterion row;
        - the Satisfactory / Not Satisfactory row of the 'Outcome (tick one)'
          table that follows the grid;
        - the comments box under 'Assessor comments';
        - the 'Assessor name: ... Date: ...' line, leaving the signature blank
          because a signature is not ours to write.

      A box already ticked by hand is left alone, as everywhere else in this
      skill: a trainer who marked the sheet before it reached us keeps it.
    #>
    param(
        [Parameter(Mandatory)]$Pkg,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Checklists,
        [Parameter(Mandatory)][string]$Who,
        # The tool-level observation record, written into the FIRST comments
        # box rather than into the body above it. An auditor opens the sheet;
        # a record floating in the body beside an empty box answers them the
        # wrong way round, and the gate checks for exactly that.
        [string[]]$Observations = @(),
        [string]$Outcome = '',
        [string]$MarkingDateText = '',
        $Marked = $null
    )
    if (@($Checklists).Count -eq 0) { return 0 }

    $ns    = $Pkg.Ns
    # Two characters are used for an empty box across the instruments in
    # circulation: WHITE SQUARE and BALLOT BOX. They look alike on the page and
    # they are not the same codepoint, so a writer that knows only one leaves
    # every box on the other instrument untouched and reports success. Both are
    # accepted here, and $EMPTYRX is the class the decision lines are read with.
    $EMPTIES = @([string][char]0x25A1, [string][char]0x2610)
    $EMPTYRX = '[' + $EMPTIES[0] + $EMPTIES[1] + ']'
    $TICK    = [string][char]0x2612      # BALLOT BOX WITH X

    # -- every body node in order, so 'the table after this heading' means what
    #    it says. Addressing the outcome table or the comments box by absolute
    #    index would break the moment a student adds a line to their answer.
    $nodes = @($Pkg.Body.ChildNodes)

    # A grid is any table with a header row carrying an S column and an NS
    # column. Two instruments in circulation for this unit shape it differently
    # — one whole checklist in a single table with a '#' column, and a run of
    # small tables each headed 'Performance Criteria' with an 'Assessor Notes'
    # column — so the columns are found by their headings and everything below
    # keys off that, rather than off a shape that only one of them has.
    $gridAt = @(); $gridMap = @{}
    for ($i = 0; $i -lt $nodes.Count; $i++) {
        if ($nodes[$i].LocalName -ne 'tbl') { continue }
        $trs = @($nodes[$i].SelectNodes('./w:tr', $ns))
        if ($trs.Count -lt 2) { continue }
        $found = $false
        for ($k = 0; $k -lt [math]::Min(4, $trs.Count) -and -not $found; $k++) {
            $cells = @($trs[$k].SelectNodes('./w:tc', $ns))
            if ($cells.Count -lt 3) { continue }
            $hdr = @($cells | ForEach-Object { Get-SnsCellText $_ $ns })
            # Column headings vary between instruments and the NOT-satisfactory
            # one is tested FIRST, because 'Not yet' would otherwise be claimed
            # by the Satisfactory pattern and both columns would address the
            # same cell. Three spellings of the pair are in circulation here:
            # S / NS, S / NYS, and Satisfactory / Not yet.
            $sc = -1; $nc = -1; $note = -1
            for ($c = 0; $c -lt $hdr.Count; $c++) {
                if ($nc -lt 0 -and $hdr[$c] -match '^(NS|NYS)(\s|$)')      { $nc = $c; continue }
                if ($nc -lt 0 -and $hdr[$c] -match '^Not\s*[Yy]et')        { $nc = $c; continue }
                if ($sc -lt 0 -and $hdr[$c] -match '^S(\s|$)')             { $sc = $c; continue }
                if ($sc -lt 0 -and $hdr[$c] -match '^Satisfactory(\s|$)')  { $sc = $c; continue }
                if ($note -lt 0 -and $hdr[$c] -match '^(Assessor Notes|Notes|Trainer/Assessor Comments|Comments)') { $note = $c }
            }
            if ($sc -lt 0 -or $nc -lt 0) { continue }
            $gridAt += $i
            $gridMap[$i] = [pscustomobject]@{ header = $k; cols = $hdr.Count; s = $sc; ns = $nc; notes = $note }
            $found = $true
        }
    }
    if ($gridAt.Count -ne @($Checklists).Count) {
        throw "${Who}: the submission has $($gridAt.Count) S/NS observation grid(s) but the ledger gives $(@($Checklists).Count). Give one checklist per grid, in document order. Nothing was ticked."
    }

    $filled        = 0
    $deferred      = @()
    $recordWritten = $false
    for ($g = 0; $g -lt $gridAt.Count; $g++) {
        $cl    = $Checklists[$g]
        $start = $gridAt[$g]
        $stop  = $nodes.Count
        if ($g + 1 -lt $gridAt.Count) { $stop = $gridAt[$g + 1] }

        $outcomes = @()
        if ($cl.PSObject.Properties.Name.Contains('outcomes') -and $cl.outcomes) { $outcomes = @($cl.outcomes) }

        # ---- the criterion rows -------------------------------------------
        # A criterion row has the full set of columns. Section headings span
        # them all and so arrive as a single cell, which is what excludes them.
        $gm    = $gridMap[$start]
        $notes = @()
        if ($cl.PSObject.Properties.Name.Contains('notes') -and $cl.notes) { $notes = @($cl.notes) }
        $trs  = @($nodes[$start].SelectNodes('./w:tr', $ns))
        $crit = @()
        for ($k = $gm.header + 1; $k -lt $trs.Count; $k++) {
            $cells = @($trs[$k].SelectNodes('./w:tc', $ns))
            if ($cells.Count -ne $gm.cols) { continue }
            if ((Get-SnsCellText $cells[0] $ns) -eq '') { continue }
            $crit += ,$cells
        }
        if ($crit.Count -ne $outcomes.Count) {
            throw "${Who}: observation grid $($g + 1) has $($crit.Count) criterion row(s) but the ledger gives $($outcomes.Count) outcome(s). Give one S or NS per row, in sheet order. Nothing was ticked."
        }
        if ($notes.Count -gt 0 -and $notes.Count -ne $crit.Count) {
            throw "${Who}: observation grid $($g + 1) has $($crit.Count) criterion row(s) but the ledger gives $($notes.Count) note(s). Give one per row, in sheet order, blank where there is nothing to add."
        }
        for ($r = 0; $r -lt $crit.Count; $r++) {
            $want = "$($outcomes[$r])"
            if ($want -ne 'S' -and $want -ne 'NS') {
                throw "${Who}: observation grid $($g + 1), row $($r + 1): outcome must be 'S' or 'NS', got '$want'."
            }
            $target = $crit[$r][$gm.ns]
            $other  = $crit[$r][$gm.s]
            if ($want -eq 'S') { $target = $crit[$r][$gm.s]; $other = $crit[$r][$gm.ns] }
            # A submission that arrives with the OPPOSITE box already marked
            # cannot be signed off by ticking beside it: the row would carry two
            # marks and say both things at once. Learners have been found
            # filling the assessor's own columns before submitting, so this is
            # refused loudly rather than resolved by overwriting somebody's mark.
            $opp = Get-SnsCellText $other $ns
            if ($opp -ne '' -and -not ($EMPTIES -contains $opp)) {
                throw "${Who}: observation grid $($g + 1), row $($r + 1) already carries a mark in the column opposite the '$want' judgement. Nothing was ticked on this row."
            }
            $cur = Get-SnsCellText $target $ns
            $strayRx = '^[' + $EMPTIES[0] + $EMPTIES[1] + [char]0x2612 + [char]0x2611 + [char]0x2713 + [char]0x2714 + 'VvXx' + '\s' + ']+$'
            if ($EMPTIES -contains $cur -or $cur -eq '' -or $cur -match $strayRx) {
                if ($cur -ne $TICK) {
                    [void](Set-CellText -Cell $target -Ns $ns -Value $TICK -Color '000000')
                    $filled++
                }
            }
            if ($gm.notes -ge 0 -and $notes.Count -gt 0) {
                $nt = "$($notes[$r])".Trim()
                if ($nt -ne '') {
                    # A notes cell that already carries writing is APPENDED to,
                    # never overwritten - the same rule as the comments box.
                    # Learners have been found filling the assessor's comment
                    # column before submitting; that text is theirs and it
                    # stays, and the assessor's note still has to land in the
                    # row it judges rather than beside it.
                    $cell = $crit[$r][$gm.notes]
                    if ((Get-SnsCellText $cell $ns) -eq '') {
                        [void](Set-CellText -Cell $cell -Ns $ns -Value $nt -Color '000000')
                    } else {
                        [void](Add-CellLine -Cell $cell -Ns $ns -Value $nt -Color '000000')
                    }
                    $filled++
                }
            }
        }

        # ---- the overall outcome table ------------------------------------
        # Optional: the small-table instrument records its outcome elsewhere,
        # so a checklist that names no overall outcome simply skips this.
        $done = ("$($cl.outcome)" -eq '')
        for ($i = $start + 1; $i -lt $stop -and -not $done; $i++) {
            if ($nodes[$i].LocalName -ne 'tbl') { continue }
            $otrs = @($nodes[$i].SelectNodes('./w:tr', $ns))
            if ($otrs.Count -lt 3) { continue }
            $c0 = @($otrs[0].SelectNodes('./w:tc', $ns))
            if ((Get-SnsCellText $c0[0] $ns) -notmatch '^Outcome') { continue }
            # NOT $tick. PowerShell variable names are case-insensitive, so a
            # $tick here IS $TICK, the ballot-box character every box on every
            # grid is written from. The first outcome table would overwrite it
            # with a pair of booleans and every later grid would be filled with
            # 'True False' instead of a mark. That is trap 7 in SKILL.md and it
            # cost a full rebuild here.
            $wantS   = ("$($cl.outcome)" -eq 'S')
            $rows    = @(@($otrs[1].SelectNodes('./w:tc', $ns)), @($otrs[2].SelectNodes('./w:tc', $ns)))
            $wantRow = @($wantS, (-not $wantS))
            for ($z = 0; $z -lt 2; $z++) {
                $cells = $rows[$z]
                if ($cells.Count -lt 2) { continue }
                if (-not $wantRow[$z]) { continue }
                $box = $cells[$cells.Count - 1]
                $cur = Get-SnsCellText $box $ns
                if ($EMPTIES -contains $cur -or $cur -eq '') {
                    [void](Set-CellText -Cell $box -Ns $ns -Value $TICK -Color '000000')
                    $filled++
                }
            }
            $done = $true
        }
        if (-not $done) {
            throw "${Who}: observation grid $($g + 1) has no 'Outcome (tick one)' table after it, so the overall outcome cannot be recorded."
        }

        # ---- this grid's own task decision line ----------------------------
        # One instrument closes each performance task with a decision carrying
        # BOTH boxes in a single paragraph, after the grid it belongs to:
        #   'Assessor decision for Task 2 practical erection:  [] Satisfactory    [] Not Yet Satisfactory'
        # It is ticked from the CHECKLIST's own decision rather than from the
        # tool result, because the two are not always the same judgement: a
        # learner whose erection was watched and was sound, and whose written
        # dismantling record is missing, is Satisfactory on Task 2 and not on
        # Task 3 under one NYS tool. Ticking both from the tool result would
        # put a red mark against work the assessor watched and accepted.
        # The search is bounded by this grid's own range, so each decision line
        # is answered by the grid above it and no other.
        $dec = "$($cl.decision)"
        if ($dec -eq '') { $dec = "$Outcome" }
        if ($dec -ne '') {
            $wantDecS = ($dec -eq 'S')
            # The decision line is a body paragraph on one instrument and a row
            # INSIDE the comments table on the other. Walking body children only
            # skipped every line of the second kind: three per learner went out
            # with both boxes empty under a signed result.
            $decCands = @()
            for ($i = $start + 1; $i -lt $stop; $i++) {
                if     ($nodes[$i].LocalName -eq 'p')   { $decCands += $nodes[$i] }
                elseif ($nodes[$i].LocalName -eq 'tbl') { $decCands += @($nodes[$i].SelectNodes('.//w:p', $ns)) }
            }
            foreach ($dnode in $decCands) {
                $dt = Get-RunText $dnode $ns
                # Two line shapes are in circulation and the second was silently
                # skipped, so three decision lines per learner went out with both
                # boxes empty under a signed result:
                #   'Assessor decision for Task 2 ...:  [] Satisfactory  [] Not Yet Satisfactory'
                #   'Task 1 result:  Satisfactory []   Not Satisfactory []'
                # A THIRD line shape carries no label at all: the pair is the
                # whole cell of an 'Observation outcome (this occasion)' table
                # printed under the grid. Matched only when the paragraph IS
                # the pair and nothing else, so no sentence mentioning the word
                # 'Satisfactory' can be mistaken for a decision.
                $bareDec = "^\s*Satisfactory\s*$EMPTYRX\s+Not\s+(?:Yet\s+)?Satisfactory\s*$EMPTYRX\s*$"
                if ($dt -notmatch '(Assessor decision for |Task\s+\d+\s+result\s*:)' -and $dt -notmatch $bareDec) { continue }
                if ($dt -notmatch $EMPTYRX) { continue }
                $boxPat = $EMPTYRX
                # CASE-INSENSITIVE deliberately. [regex]::Match is case
                # sensitive where PowerShell's own -match is not, and one
                # learner's workbook prints the line as '[] satisfactory'. The
                # box went out empty under a signed result and the gate did not
                # see it, because the gate reads grids and not this line.
                # The matched text is used verbatim as the replacement's Find,
                # so whatever case the page carries is preserved.
                $ci  = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
                # The box sits BEFORE the word on one instrument and AFTER it on
                # the other, and 'Satisfactory []' also matches inside
                # 'Not Satisfactory []', so the Satisfactory form is guarded with
                # a lookbehind. 'Yet' is optional: one pack prints 'Not Yet
                # Satisfactory' and the other 'Not Satisfactory'.
                if ($wantDecS) {
                    $hit = [regex]::Match($dt, "$boxPat\s*Satisfactory", $ci)
                    if (-not $hit.Success) {
                        $hit = [regex]::Match($dt, "(?<!Not\s)(?<!Not\sYet\s)Satisfactory\s*$boxPat", $ci)
                    }
                } else {
                    $hit = [regex]::Match($dt, "Not\s+(?:Yet\s+)?Satisfactory\s*$boxPat", $ci)
                    if (-not $hit.Success) {
                        $hit = [regex]::Match($dt, "$boxPat\s*Not\s+(?:Yet\s+)?Satisfactory", $ci)
                    }
                }
                if (-not $hit.Success) { continue }
                # The box's index inside the match, turned into an index into the
                # whole paragraph, then ticked in whichever run holds it.
                $inMatch = [regex]::Match($hit.Value, $boxPat)
                if (-not $inMatch.Success) { continue }
                if (Set-BoxAtIndex -Node $dnode -Ns $ns -CharIndex ($hit.Index + $inMatch.Index) -Tick $TICK) { $filled++ }
            }
        }

        # ---- the comments box ---------------------------------------------
        # 'Assessor comments' is a heading paragraph and the box is the table
        # that follows it. Writing under the heading instead would put the
        # record in the body flow beside an empty box, the wrong way round.
        # Optional, like the outcome table: a checklist with nothing to say
        # here carries its record in its per-row notes instead.
        if ("$($cl.comments)".Trim() -eq '') { continue }
        $cmtAt = -1
        for ($i = $start + 1; $i -lt $stop; $i++) {
            if ($nodes[$i].LocalName -ne 'p') { continue }
            if ((Get-RunText $nodes[$i] $ns).Trim() -match '^Assessor (comments|Observations)') { $cmtAt = $i; break }
        }
        # A THIRD shape: the heading and its box are both rows of one table, so
        # the heading is never a body-level paragraph and the loop above finds
        # nothing. Here the box is the first EMPTY cell after the heading cell
        # in that same table. Searching only the body flow threw on every
        # learner of this instrument and produced no marked copy at all.
        $bcellDirect = $null
        if ($cmtAt -lt 0) {
            for ($i = $start + 1; $i -lt $stop -and -not $bcellDirect; $i++) {
                if ($nodes[$i].LocalName -ne 'tbl') { continue }
                $tcs = @($nodes[$i].SelectNodes('.//w:tc', $ns))
                $seen = -1
                for ($c = 0; $c -lt $tcs.Count; $c++) {
                    $ct = (Get-SnsCellText $tcs[$c] $ns)
                    if ($seen -lt 0) {
                        if ($ct -match '^Assessor (comments|Observations)') { $seen = $c }
                        continue
                    }
                    if ($ct -eq '') { $bcellDirect = $tcs[$c]; break }
                }
            }
        }
        if ($cmtAt -lt 0 -and -not $bcellDirect) {
            throw "${Who}: observation grid $($g + 1) has no 'Assessor comments' or 'Assessor Observations' heading after it, so the record has nowhere to go."
        }
        # The box is the first table between 'Assessor comments' and the
        # sign-off line. It is NOT simply the next node: Write-ObservationSheet
        # has already run and put the tool-level observation record directly
        # under that heading, so stopping at the first non-empty paragraph
        # stops on our own writing and reports a box that is plainly there.
        $boxAt = -1
        for ($i = $cmtAt + 1; $i -lt $stop -and $cmtAt -ge 0; $i++) {
            if ($nodes[$i].LocalName -eq 'p' -and (Get-RunText $nodes[$i] $ns).Trim() -match '^Assessor name:') { break }
            if ($nodes[$i].LocalName -eq 'tbl') { $boxAt = $i; break }
        }
        $lines = @(("$($cl.comments)" -split "`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
        if ($lines.Count -eq 0) { throw "${Who}: observation grid $($g + 1) has no comments to write." }

        # A FOURTH sheet shape carries a comments box and NO sign-off line at
        # all. The loop further down rewrites a line that exists and writes
        # nothing where there is none, so the record went out naming nobody and
        # the gate refused it. Where the sheet provides no line, the sign-off is
        # written as the last line of the comments box instead - inside the
        # space the sheet allocates for the record, not loose beside it.
        $sigLine = "Assessor name: $($cl.assessor)   Signature: ___________   Date: $($cl.dateText)"
        $hasSig  = $false
        for ($i = $start + 1; $i -lt $stop -and -not $hasSig; $i++) {
            $sigCand = @()
            if     ($nodes[$i].LocalName -eq 'p')   { $sigCand = @($nodes[$i]) }
            elseif ($nodes[$i].LocalName -eq 'tbl') { $sigCand = @($nodes[$i].SelectNodes('.//w:p', $ns)) }
            foreach ($cnode in $sigCand) {
                if ((Get-RunText $cnode $ns).Trim() -match '^Assessor\s+(name:|signature\s*/\s*date:)') { $hasSig = $true; break }
            }
        }
        if (-not $hasSig -and "$($cl.assessor)" -ne '') { $lines += $sigLine }

        # Some submissions arrive with the comments box gone — a learner whose
        # file has been mangled by an editor loses the table and keeps the
        # heading. The record still belongs under that heading, so it is
        # written as paragraphs there rather than refused. Nothing of the
        # learner's is displaced: the paragraphs are inserted, not substituted.
        # Inserting here and now would shift every index below it, and the grid
        # positions were measured before the loop started. The anchor is held
        # as a NODE instead and written after the loop, where no index matters.
        # The tool-level record goes at the head of the first box that exists,
        # above that occasion's own comments.
        $head = @()
        if (-not $recordWritten -and $Marked -and @($Observations).Count -gt 0) {
            $head += [pscustomobject]@{ text = $Marked.observationHeading; color = $Marked.headingColor }
            foreach ($point in $Observations) {
                $head += [pscustomobject]@{ text = ("{0}  {1}" -f $Marked.observationBullet, $point); color = '000000' }
            }
            $head += [pscustomobject]@{ text = ("{0}  {1}" -f $Marked.observationCompletedText, $MarkingDateText); color = $Marked.headingColor }
            $oTxt = $(if ($Outcome -eq 'S') { $Marked.satisfactoryText }  else { $Marked.notSatisfactoryText })
            $oCol = $(if ($Outcome -eq 'S') { $Marked.satisfactoryColor } else { $Marked.notSatisfactoryColor })
            $head += [pscustomobject]@{ text = $oTxt; color = $oCol }
        }

        if ($bcellDirect) {
            $bcell = $bcellDirect
            foreach ($h in $head) {
                if ((Get-SnsCellText $bcell $ns) -eq '') {
                    [void](Set-CellText -Cell $bcell -Ns $ns -Value $h.text -Color $h.color)
                } else {
                    [void](Add-CellLine -Cell $bcell -Ns $ns -Value $h.text -Color $h.color)
                }
            }
            if ($head.Count -gt 0) { $recordWritten = $true }
            if ((Get-SnsCellText $bcell $ns) -eq '') {
                [void](Set-CellText -Cell $bcell -Ns $ns -Value $lines[0] -Color '000000')
                for ($z = 1; $z -lt $lines.Count; $z++) {
                    [void](Add-CellLine -Cell $bcell -Ns $ns -Value $lines[$z] -Color '000000')
                }
            } else {
                foreach ($ln in $lines) { [void](Add-CellLine -Cell $bcell -Ns $ns -Value $ln -Color '000000') }
            }
        } elseif ($boxAt -lt 0) {
            # No box on this sheet. Build one from the outcome table just above,
            # and defer the insert: putting a table into the body here would
            # shift every index the grid positions were measured against.
            $src = $null
            for ($i = $cmtAt - 1; $i -gt $start; $i--) {
                if ($nodes[$i].LocalName -eq 'tbl') { $src = $nodes[$i]; break }
            }
            if (-not $src) {
                throw "${Who}: observation grid $($g + 1) has no comments box and no table above it to build one from."
            }
            $deferred += [pscustomobject]@{ anchor = $nodes[$cmtAt]; lines = $lines; head = $head; src = $src }
            if ($head.Count -gt 0) { $recordWritten = $true }
        } else {
            $bcell = @($nodes[$boxAt].SelectNodes('.//w:tc', $ns))[0]
            if (-not $bcell) { throw "${Who}: the comments box under observation grid $($g + 1) has no cell." }
            foreach ($h in $head) {
                if ((Get-SnsCellText $bcell $ns) -eq '') {
                    [void](Set-CellText -Cell $bcell -Ns $ns -Value $h.text -Color $h.color)
                } else {
                    [void](Add-CellLine -Cell $bcell -Ns $ns -Value $h.text -Color $h.color)
                }
            }
            if ($head.Count -gt 0) { $recordWritten = $true }
            # A box that already carries text is APPENDED to, never overwritten.
            # Some learners type into the assessor's box before submitting; that
            # is their document and it stays, but the assessor's record still
            # has to land in the instrument rather than beside it.
            if ((Get-SnsCellText $bcell $ns) -eq '') {
                [void](Set-CellText -Cell $bcell -Ns $ns -Value $lines[0] -Color '000000')
                for ($p = 1; $p -lt $lines.Count; $p++) {
                    [void](Add-CellLine -Cell $bcell -Ns $ns -Value $lines[$p] -Color '000000')
                }
            } else {
                foreach ($ln in $lines) { [void](Add-CellLine -Cell $bcell -Ns $ns -Value $ln -Color '000000') }
            }
        }
        $filled++

        # ---- the assessor name and date -------------------------------------
        # The signature stays blank. Recording who observed and when is the
        # assessor's own record; signing for them is not ours to do.
        # Two spellings of the sign-off line, and on this instrument it sits in
        # the same table as the comments box rather than in the body flow:
        #   'Assessor name: ...   Signature: ...   Date: ...'
        #   'Assessor signature / date:'
        $sigCands = @()
        for ($i = $start + 1; $i -lt $stop; $i++) {
            if     ($nodes[$i].LocalName -eq 'p')   { $sigCands += $nodes[$i] }
            elseif ($nodes[$i].LocalName -eq 'tbl') { $sigCands += @($nodes[$i].SelectNodes('.//w:p', $ns)) }
        }
        foreach ($snode in $sigCands) {
            $t = (Get-RunText $snode $ns).Trim()
            if ($t -notmatch '^Assessor\s+(name:|signature\s*/\s*date:)') { continue }
            # The WHOLE line is rewritten, not patched around whatever is on it.
            # Learners have been found typing the assessor's name and a date of
            # their own into this line before submitting, and a record that
            # carries somebody else's idea of who assessed it, and when, is
            # worse than one that carries nothing. The signature stays blank.
            $sig = "Assessor name: $($cl.assessor)   Signature: ___________   Date: $($cl.dateText)"
            if ($sig -ne $t) {
                [void](Set-TextInNode -Node $snode -Ns $ns -Find $t -Replace $sig)
                $filled++
            }
            break
        }
    }

    # Per-task assessor outcome boxes. The small-table instrument closes each
    # performance task with a decision pair of its own — an empty box then
    # 'SATISFACTORY (S) ...', and another then 'NOT SATISFACTORY (NS) ...'.
    # They sit in no grid, so neither the criterion ticks nor the sheet's own
    # outcome table reaches them, and four per learner were going out empty
    # underneath a signed result.
    if ("$Outcome" -ne '') {
        $wantS = ("$Outcome" -eq 'S')
        foreach ($p in @($Pkg.Body.SelectNodes('.//w:p', $ns))) {
            $t = (Get-RunText $p $ns).Trim()
            if ($t -notmatch "^$EMPTYRX\s*(NOT\s+)?SATISFACTORY\b") { continue }
            $isNot  = ($t -match "^$EMPTYRX\s*NOT\s+SATISFACTORY\b")
            $tickIt = $(if ($isNot) { -not $wantS } else { $wantS })
            if (-not $tickIt) { continue }
            if ((Set-TextInNode -Node $p -Ns $ns -Find $t.Substring(0,1) -Replace $TICK -Limit 1) -gt 0) { $filled++ }
        }
    }

    # Comments for any grid whose box was missing, written now that no index
    # into the body matters any more. Node references survive the insertions.
    foreach ($d in $deferred) {
        $box = New-CommentsBox -Source $d.src -Ns $ns
        if (-not $box) { throw "${Who}: could not build a comments box for this observation sheet." }
        [void]$d.anchor.ParentNode.InsertAfter($box, $d.anchor)
        $bcell = @($box.SelectNodes('.//w:tc', $ns))[0]
        $first = $true
        foreach ($h in @($d.head)) {
            if (-not $h) { continue }
            if ($first) { [void](Set-CellText -Cell $bcell -Ns $ns -Value $h.text -Color $h.color); $first = $false }
            else        { [void](Add-CellLine -Cell $bcell -Ns $ns -Value $h.text -Color $h.color) }
        }
        foreach ($ln in $d.lines) {
            if ($first) { [void](Set-CellText -Cell $bcell -Ns $ns -Value $ln -Color '000000'); $first = $false }
            else        { [void](Add-CellLine -Cell $bcell -Ns $ns -Value $ln -Color '000000') }
        }
    }
    $filled
}

function New-CommentsBox {
    <#
      Builds the one-cell comments box a sheet is missing, by cloning a table
      that is already on that sheet and reducing it to a single full-width cell.

      Some submissions arrive with the box gone — a file mangled by an editor
      keeps the 'Assessor comments' heading and loses the table under it. The
      record still has to land in the space the sheet allocates for it, so the
      space is rebuilt rather than the record written loose in the body beside
      it. Cloning a neighbouring table rather than composing one from scratch
      is what keeps the width, the borders and the shading the learner's own
      document uses.
    #>
    param($Source, $Ns)
    $box = $Source.CloneNode($true)
    $trs = @($box.SelectNodes('./w:tr', $Ns))
    for ($i = 1; $i -lt $trs.Count; $i++) { [void]$box.RemoveChild($trs[$i]) }
    $row = @($box.SelectNodes('./w:tr', $Ns))[0]
    if (-not $row) { return $null }

    $cols = @($box.SelectNodes('w:tblGrid/w:gridCol', $Ns))
    $total = 0
    foreach ($c in $cols) { $total += [int]$c.GetAttribute('w', $script:W) }

    $cells = @($row.SelectNodes('./w:tc', $Ns))
    for ($i = 1; $i -lt $cells.Count; $i++) { [void]$row.RemoveChild($cells[$i]) }
    $cell = @($row.SelectNodes('./w:tc', $Ns))[0]
    if (-not $cell) { return $null }

    $pr = $cell.SelectSingleNode('w:tcPr', $Ns)
    if ($pr) {
        foreach ($n in @($pr.SelectNodes('w:gridSpan', $Ns))) { [void]$pr.RemoveChild($n) }
        foreach ($n in @($pr.SelectNodes('w:shd', $Ns)))      { [void]$pr.RemoveChild($n) }
        if ($cols.Count -gt 1) {
            $gs = $cell.OwnerDocument.CreateElement('w', 'gridSpan', $script:W)
            [void]$gs.SetAttribute('val', $script:W, "$($cols.Count)")
            [void]$pr.PrependChild($gs)
        }
        $w = $pr.SelectSingleNode('w:tcW', $Ns)
        if ($w -and $total -gt 0) { [void]$w.SetAttribute('w', $script:W, "$total") }
    }

    # One empty paragraph, keeping the cloned cell's own paragraph formatting.
    $paras = @($cell.SelectNodes('w:p', $Ns))
    for ($i = 1; $i -lt $paras.Count; $i++) { [void]$cell.RemoveChild($paras[$i]) }
    $p = $paras[0]
    foreach ($r in @($p.SelectNodes('.//w:r', $Ns))) { [void]$r.ParentNode.RemoveChild($r) }
    $box
}

function Get-SnsCellText {
    <# A cell's whole visible text, trimmed. Named apart from the sibling
       writers' local helpers so nothing shadows anything. #>
    param($Cell, $Ns)
    (($Cell.SelectNodes('.//w:t', $Ns) | ForEach-Object { $_.InnerText }) -join '').Trim()
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
        [Parameter(Mandatory)][string]$Who,
        # Where the sheet's own notes anchor is a body heading with a comments
        # BOX under it, the record belongs in that box, not in the body flow
        # above it. Write-SnsChecklist puts it there; this switch stops the two
        # of them writing the same record twice.
        [switch]$SkipRecord
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

    # Two sheet shapes, read two ways. A LABELLED sheet writes the decision into
    # the box's own text — '☐ Yes' — and is read paragraph by paragraph. A
    # COLUMN sheet heads two columns 'Yes' and 'No' and leaves a bare '☐' in
    # each cell, and is read row by row off the table. Neither reader sees the
    # other's sheet, so the ledger says which one this is.
    $layout = 'labelled'
    if ($Sheet.PSObject.Properties.Name.Contains('layout') -and $Sheet.layout) {
        $layout = "$($Sheet.layout)".Trim().ToLowerInvariant()
    }
    if (@('labelled', 'columns', 'inlinepairs') -notcontains $layout) {
        throw "$Who / observation sheet: unknown layout '$layout'. Use 'labelled' for '☐ Yes' boxes, 'columns' for a Yes/No column table, or 'inlinePairs' for one decision column holding '☐ S ☐ NS'."
    }

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

    $taskCount = 0

    if ($layout -eq 'labelled') {
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
        $taskCount = $pairs.Count
    }
    elseif ($layout -eq 'columns') {
        # A COLUMN SHEET. The criterion rows are read off the tables inside the
        # sheet, the ledger's outcomes are paired with them in sheet order, and
        # the count is checked before a single box is ticked — a sheet read one
        # row short ticks every criterion below the gap against the wrong task.
        $rows = @(Get-ColumnSheetRows -Pkg $Pkg -Ns $ns -Sheet $Sheet -StartAt $start -EndAt $end -Who $Who)
        if ($rows.Count -eq 0) {
            throw "$Who / observation sheet: no criterion rows were found under a Yes/No heading row between '$($Sheet.anchor)' and the end of the sheet. Check the anchors, or set layout to 'labelled' where the boxes read '☐ Yes'."
        }
        if ($outcomes.Count -gt 0 -and $rows.Count -ne $outcomes.Count) {
            throw "$Who / observation sheet: the sheet has $($rows.Count) criterion row(s) but the ledger gives $($outcomes.Count) outcome(s). Give one Yes or No per row, in sheet order. Nothing was ticked."
        }
        $cellStyle = Get-SheetCellStyle $Sheet
        for ($i = 0; $i -lt $outcomes.Count; $i++) {
            $want = "$($outcomes[$i])"
            Set-BoxCell -Cell $rows[$i].yes -Ns $ns -Ticked ($want -eq 'Yes') -Who $Who -Row ($i + 1) -Column 'Yes' -Style $cellStyle
            Set-BoxCell -Cell $rows[$i].no  -Ns $ns -Ticked ($want -eq 'No')  -Who $Who -Row ($i + 1) -Column 'No'  -Style $cellStyle
        }

        # The comments column is this sheet's assessor comments area — one cell
        # per criterion. The resolver has already required one note per row and
        # held each to the row-note standard; this writes them where they belong.
        $notes = @()
        if ($Sheet.PSObject.Properties.Name.Contains('comments') -and $Sheet.comments) { $notes = @($Sheet.comments) }
        if ($notes.Count -gt 0) {
            if ($notes.Count -ne $rows.Count) {
                throw "$Who / observation sheet: the sheet has $($rows.Count) comments cell(s) but the ledger gives $($notes.Count) comment(s). Give one per criterion row, in sheet order."
            }
            for ($i = 0; $i -lt $notes.Count; $i++) {
                if (-not $rows[$i].comments) {
                    throw "$Who / observation sheet: criterion row $($i + 1) ('$($rows[$i].criterion)') has no comments cell to write into."
                }
                $noteText = if ($notes[$i] -is [string]) { "$($notes[$i])" } else { "$($notes[$i].text)" }
                [void](Set-CellText -Cell $rows[$i].comments -Ns $ns -Value $noteText -Color '000000')
            }
        }
        $taskCount = $rows.Count
    }
    else {
        # AN INLINE-PAIR SHEET. One decision column, both boxes inside its cell
        # with their words beside them: '☐ S ☐ NS'. The count is checked against
        # the ledger before a single box is ticked, for the same reason the
        # column reader checks it — a sheet read one row short marks every
        # criterion below the gap against the wrong task.
        $rows = @(Get-InlinePairRows -Pkg $Pkg -Ns $ns -Sheet $Sheet -StartAt $start -EndAt $end -Who $Who)
        if ($rows.Count -eq 0) {
            throw "$Who / observation sheet: no criterion rows were found under a '$(if ($Sheet.PSObject.Properties.Name.Contains('decisionHeader') -and $Sheet.decisionHeader) { $Sheet.decisionHeader } else { 'S / NS' })' heading between '$($Sheet.anchor)' and the end of the sheet. Check the anchors, or set layout to 'columns' where Yes and No head two columns."
        }
        if ($outcomes.Count -gt 0 -and $rows.Count -ne $outcomes.Count) {
            throw "$Who / observation sheet: the sheet has $($rows.Count) criterion row(s) but the ledger gives $($outcomes.Count) outcome(s). Give one Yes or No per row, in sheet order. Nothing was ticked."
        }
        $yesLabel = if ($Sheet.PSObject.Properties.Name.Contains('yesLabel') -and $Sheet.yesLabel) { "$($Sheet.yesLabel)" } else { 'S' }
        $noLabel  = if ($Sheet.PSObject.Properties.Name.Contains('noLabel')  -and $Sheet.noLabel)  { "$($Sheet.noLabel)" }  else { 'NS' }
        for ($i = 0; $i -lt $outcomes.Count; $i++) {
            $want = "$($outcomes[$i])"
            $yBox = if ($want -eq 'Yes') { $script:BOX_TICKED } else { $script:BOX_EMPTY }
            $nBox = if ($want -eq 'Yes') { $script:BOX_EMPTY }  else { $script:BOX_TICKED }
            [void](Set-CellText -Cell $rows[$i].decision -Ns $ns -Value ("{0} {1}  {2} {3}" -f $yBox, $yesLabel, $nBox, $noLabel) -Color '000000')
        }

        # The comments column is this sheet's assessor comments area, one cell
        # per criterion, held to the row-note standard by the resolver.
        $notes = @()
        if ($Sheet.PSObject.Properties.Name.Contains('comments') -and $Sheet.comments) { $notes = @($Sheet.comments) }
        if ($notes.Count -gt 0) {
            if ($notes.Count -ne $rows.Count) {
                throw "$Who / observation sheet: the sheet has $($rows.Count) comments cell(s) but the ledger gives $($notes.Count) comment(s). Give one per criterion row, in sheet order."
            }
            for ($i = 0; $i -lt $notes.Count; $i++) {
                if (-not $rows[$i].comments) {
                    throw "$Who / observation sheet: criterion row $($i + 1) ('$($rows[$i].criterion)') has no comments cell to write into."
                }
                $noteText = if ($notes[$i] -is [string]) { "$($notes[$i])" } else { "$($notes[$i].text)" }
                [void](Set-CellText -Cell $rows[$i].comments -Ns $ns -Value $noteText -Color '000000')
            }
        }
        $taskCount = $rows.Count
    }

    if ($null -ne $sufficientAt -and $Sheet.PSObject.Properties.Name.Contains('sufficient') -and $null -ne $Sheet.sufficient) {
        # The overall box does not always read Yes and No. ACI's checklist ends
        # 'Competent / Not Yet Competent', so the ledger may name the two labels
        # — satisfied first — rather than assume the Yes/No pair.
        $sufLabels = @()
        if ($Sheet.PSObject.Properties.Name.Contains('sufficientLabels') -and $Sheet.sufficientLabels) {
            $sufLabels = @($Sheet.sufficientLabels)
        }
        $paras = @(Get-BodyParagraphs $Pkg)
        $start = Find-OneParagraph -Paragraphs $paras -Ns $ns -Text $Sheet.anchor -What "$Who / observation sheet anchor"
        $end   = Get-SheetEnd -Paragraphs $paras -Ns $ns -Sheet $Sheet -Start $start -Who $Who
        $sufficientAt = Find-OneParagraph -Paragraphs $paras -Ns $ns -Text $Sheet.sufficientAnchor -From $start -To $end -What "$Who / observation sheet sufficientAnchor"

        if ($sufLabels.Count -gt 0) {
            if ($sufLabels.Count -ne 2) {
                throw "$Who / observation sheet: sufficientLabels needs exactly two labels — the satisfied one first."
            }
            $hit = -1
            for ($i = $sufficientAt; $i -lt $end; $i++) {
                $t = (Get-RunText $paras[$i] $ns)
                if ($t.IndexOf("$($script:BOX_EMPTY) $($sufLabels[0])", [StringComparison]::Ordinal) -ge 0 -or
                    $t.IndexOf("$($script:BOX_TICKED) $($sufLabels[0])", [StringComparison]::Ordinal) -ge 0) { $hit = $i; break }
            }
            if ($hit -lt 0) {
                throw "$Who / observation sheet: no box labelled '$($sufLabels[0])' follows '$($Sheet.sufficientAnchor)', so the overall box cannot be ticked."
            }
            $n = Set-LabelledBox -Node $paras[$hit] -Ns $ns -Label "$($sufLabels[0])" -Ticked ([bool]$Sheet.sufficient)
            if ($n -lt 1) {
                throw "$Who / observation sheet: the '$($sufLabels[0])' box was found but not ticked."
            }
            [void](Set-LabelledBox -Node $paras[$hit] -Ns $ns -Label "$($sufLabels[1])" -Ticked (-not [bool]$Sheet.sufficient))
        }
        else {
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

        # A LABEL THE SHEET PRINTS ONCE PER OCCASION. A pack observed over five
        # activities repeats 'Assessor Signature:' and 'Activity Result:' once
        # per activity, all inside one sheet. Find-OneParagraph refuses that
        # ambiguity, which is the right default â€” taking the first would fill one
        # occasion and leave four blank under a signed record. So the ledger says
        # which it means: 'values' gives one value per occurrence in sheet order,
        # and the count has to match what the sheet actually carries. 'all' is
        # the shorthand for the case where every occurrence takes the same value.
        #
        # CELLS ARE COLLECTED BEFORE ANY IS WRITTEN. Set-CellText removes
        # paragraphs, so an index taken before a write points elsewhere after it;
        # the cell element itself stays valid.
        $manyValues = @()
        if ($fld.PSObject.Properties.Name.Contains('values') -and $fld.values) { $manyValues = @($fld.values) }
        $fillAll = ($fld.PSObject.Properties.Name.Contains('all') -and $fld.all)
        if ($manyValues.Count -gt 0 -or $fillAll) {
            $targets = @()
            for ($i = $start; $i -lt $end; $i++) {
                if ((Get-RunText $paras[$i] $ns).IndexOf("$($fld.label)", [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
                $c = Get-ParagraphCell $paras[$i]
                if (-not $c) { continue }
                if ((("$($c.InnerText)") -replace '\s+', ' ').Trim() -ne "$($fld.label)") { continue }
                $t = Get-NextCellInRow -Cell $c -Ns $ns
                if (-not $t) { continue }
                if ($targets -notcontains $t) { $targets += $t }
            }
            if ($targets.Count -eq 0) {
                throw "$Who / observation sheet: field '$($fld.label)' names no cell on the sheet with somewhere to write."
            }
            if ($manyValues.Count -gt 0 -and $manyValues.Count -ne $targets.Count) {
                throw "$Who / observation sheet: field '$($fld.label)' gives $($manyValues.Count) value(s) but the sheet carries $($targets.Count) of it. Give one per occurrence, in sheet order."
            }
            for ($k = 0; $k -lt $targets.Count; $k++) {
                $v = if ($manyValues.Count -gt 0) { "$($manyValues[$k])" } else { "$($fld.value)" }
                [void](Set-CellText -Cell $targets[$k] -Ns $ns -Value $v -Color '000000')
            }
            continue
        }

        $at   = Find-OneParagraph -Paragraphs $paras -Ns $ns -Text "$($fld.label)" -From $start -To $end -What "$Who / observation sheet field '$($fld.label)'"
        $cell = Get-ParagraphCell $paras[$at]
        if (-not $cell) {
            # Not every sheet puts its fields in a table. ACI's checklist signs
            # off on one printed line — 'Assessor Signature: _____ Date: ____' —
            # where the field IS the rule of underscores after the label. Fill
            # that, matching label and rule together: the shorter rule after
            # 'Date' is a substring of the longer one after 'Signature', so a
            # match on underscores alone writes the date over the signature.
            $line = Get-RunText $paras[$at] $ns
            $rx   = [regex]::Escape("$($fld.label)") + '\s*:?\s*(_{2,})'
            $m    = [regex]::Match($line, $rx)
            if (-not $m.Success) {
                throw "$Who / observation sheet: field '$($fld.label)' is not in a table and carries no rule of underscores to write '$($fld.value)' onto."
            }
            $replaced = Set-TextInNode -Node $paras[$at] -Ns $ns -Find $m.Value -Replace ("{0}: {1}" -f $fld.label, $fld.value) -Limit 1
            if ($replaced -lt 1) {
                throw "$Who / observation sheet: field '$($fld.label)' was found but '$($fld.value)' could not be written onto it."
            }
            continue
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
    if ($SkipRecord) { return $Pkg }
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

    $taskCount
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
        } elseif ($res.PSObject.Properties.Name.Contains('wrongAssessment') -and $res.wrongAssessment) {
            $skipped += "$($s.fullName) / $($res.toolName): the work submitted is $($res.submittedInstead), so there is no assessment for this unit to mark. The feedback goes out on a standalone sheet"
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

    # Everything this attempt writes into a file that already carries an earlier
    # attempt is prefixed, so the two can be told apart. Attempt 1 writes plain
    # text, which is what every single-attempt copy has always looked like.
    $attemptPrefix = if ([int]$s.attempt -ge 2) { "Attempt $($s.attempt): " } else { '' }

    # In the order the tools were declared, so a copy covering UAT 1 and UAT 2
    # names them in that order on its declaration page.
    $group = @()
    foreach ($tid in @($mc.toolIds)) {
        $r = @($s.results | Where-Object { $_.toolId -eq $tid })
        if ($r.Count -ne 1) { throw "$($s.fullName): expected one result for tool '$tid', found $($r.Count)." }
        $group += $r[0]
    }

    # RESUBMISSIONS STACK. At attempt 2 the input is the file already marked at
    # attempt 1, not the raw submission — so attempt 1's feedback page and its
    # outcome lines travel with it untouched, and the new page goes on top.
    # Marking attempt 2 from the raw submission would silently lose the record
    # of attempt 1, which is the audit trail.
    $sourcePath = $mc.evidence
    if ($mc.PSObject.Properties.Name.Contains('priorMarkedCopy') -and $mc.priorMarkedCopy) {
        $sourcePath = $mc.priorMarkedCopy
    }
    $src = Resolve-Submission $sourcePath
    if (-not $src) {
        throw "$($s.fullName) / $(($mc.toolNames) -join ' + '): the ledger records outcomes for this file but '$sourcePath' cannot be found. A marked copy cannot be produced from a file that is not there."
    }
    if ([System.IO.Path]::GetExtension($src).ToLower() -ne '.docx') {
        throw "$($s.fullName) / $(($mc.toolNames) -join ' + '): '$src' is not a .docx. Convert the submission to Word before marking it."
    }

    $pkg = Open-Docx -Path $src
    try {
        $ns  = $pkg.Ns
        $doc = $pkg.Xml

        $totalS = 0; $totalNys = 0; $totalQ = 0; $totalTasks = 0
        $appendObs = @()          # records with no sheet to write into
        $sheetsWritten = 0

        # ---- the assessment cover sheet --------------------------------------
        # Filled BEFORE anything is inserted, so its cells are addressed in the
        # submission as the student handed it in.
        if ($L.PSObject.Properties.Name.Contains('coverSheet') -and $L.coverSheet) {
            [void](Write-CoverSheet -Pkg $pkg -Cover $L.coverSheet -Student $s -Ledger $L `
                                    -ToolNames ([string[]]@($mc.toolNames)) -Who $s.fullName)
        } else {
            $lastWarnings += "$($s.fullName): the ledger names no coverSheet, so the assessment cover sheet at the front of this copy was returned as the student left it. Fields the RTO completes may be blank."
        }

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

                # An assessment routinely prints its task headings twice: once in
                # the list of what the student will do, and again over the task
                # itself. Both paragraphs read the same, so no anchor text can
                # tell them apart. 'anchorAfter' says which copy is meant by
                # naming something that appears once and sits before it — the
                # scenario, the previous task's template. It narrows the search;
                # the anchor must still be unique inside what is left, so this
                # disambiguates without ever picking a match on its own.
                $from = 0
                $anchorAfter = if ($q.PSObject.Properties.Name.Contains('anchorAfter')) { $q.anchorAfter } else { $null }
                if ($anchorAfter) {
                    $afterHits = @(Find-ParagraphIndex -Paragraphs $paras -Ns $ns -Text $anchorAfter)
                    if ($afterHits.Count -eq 0) {
                        $problems += "question '$($q.ref)': anchorAfter '$anchorAfter' is not in this submission"
                        continue
                    } elseif ($afterHits.Count -gt 1) {
                        $problems += "question '$($q.ref)': anchorAfter '$anchorAfter' appears $($afterHits.Count) times; name something that appears once"
                        continue
                    }
                    $from = $afterHits[0] + 1
                }

                $hits = @(@(Find-ParagraphIndex -Paragraphs $paras -Ns $ns -Text $anchorText) | Where-Object { $_ -ge $from })
                if ($hits.Count -eq 0) {
                    $problems += $(if ($anchorAfter) {
                        "question '$($q.ref)': no paragraph after '$anchorAfter' contains '$anchorText'"
                    } else {
                        "question '$($q.ref)': no paragraph contains '$anchorText'"
                    })
                } elseif ($hits.Count -gt 1) {
                    $problems += $(if ($anchorAfter) {
                        "question '$($q.ref)': '$anchorText' appears $($hits.Count) times after '$anchorAfter'; give it a unique 'anchor' in the ledger"
                    } else {
                        "question '$($q.ref)': '$anchorText' appears $($hits.Count) times; give it a unique 'anchor' in the ledger, or an 'anchorAfter' naming text that appears once before the copy you mean"
                    })
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
                # At attempt 2+ the previous attempt's line is still under this
                # answer, untouched. The new one is prefixed with its attempt so
                # the two can be told apart — by the student reading it and by
                # the gate counting it.
                # SETTLED by the RTO on 2 September 2026: one line per attempt,
                # the newer prefixed. The alternative — a single line showing
                # only the latest outcome — reads more cleanly and loses the
                # history, and the history is the point of a stacked file.
                $text = ($attemptPrefix + $(if ($isS) { $M.satisfactoryText } else { $M.notSatisfactoryText }))
                $col  = if ($isS) { $M.satisfactoryColor } else { $M.notSatisfactoryColor }

                $line = New-TextParagraph -Doc $doc -Text $text -Color $col -Bold `
                                          -SpaceBefore 80 -SpaceAfter 80
                [void](Add-ParagraphAfter -Anchor $target -NewParagraph $line)
            }

            $totalQ   += $located.Count
            $totalS   += @($located | Where-Object { $_.outcome -eq 'S' }).Count
            $totalNys += @($located | Where-Object { $_.outcome -eq 'NYS' }).Count

            # --- the TASK outcomes --------------------------------------------
            # A tool made of tasks rather than questions — three practical
            # activities in a unit project, say — is judged task by task, and
            # each task carries its own coloured outcome and the assessor's
            # comment on it. Without this a student saw thirty-two judgements on
            # their knowledge test and none at all on the three activities they
            # actually performed, with one tool-level line at the end of the
            # observation sheet standing for all three.
            #
            # IT GOES IN THE SPACE THE TEMPLATE PROVIDES. These instruments
            # already carry an assessor's column beside every criterion and, at
            # the foot of an activity, a cell headed 'Assessor / Supervisor
            # comments'. A judgement written as loose paragraphs after the table
            # reads as an annotation someone added; written into the boxes the
            # instrument provides, it reads as the instrument being completed.
            #
            # So: the outcome for each criterion row goes in that row's comments
            # cell, under the note already there, and the task's own comment
            # goes in the labelled cell where the template has one. Only where
            # the template provides neither does the ledger's anchor place a
            # block in the body, which is the fallback below.
            $tasks = @()
            if ($res.PSObject.Properties.Name.Contains('tasks') -and $res.tasks) { $tasks = @($res.tasks) }

            if ($tasks.Count -gt 0) {
                $placed = @{}
                $rowMark = "$($res.checklistMarker)"
                if (-not $rowMark) { $rowMark = 'Does the candidate meet the following' }

                foreach ($tbl in @($pkg.Body.SelectNodes('.//w:tbl', $ns))) {
                    if ((Get-RunText $tbl $ns) -notlike "*$rowMark*") { continue }
                    foreach ($row in @($tbl.SelectNodes('w:tr', $ns))) {
                        $tc = @($row.SelectNodes('w:tc', $ns))
                        if ($tc.Count -lt 4) { continue }
                        $head = (Get-RunText $tc[0] $ns).Trim()
                        if (-not $head -or $head -like "$rowMark*") { continue }
                        $cur = Get-RunText $tc[3] $ns
                        if ($cur -like "*$($M.satisfactoryText)*" -or $cur -like "*$($M.notSatisfactoryText)*") { continue }
                        $isS = ($res.result -eq 'S')
                        [void](Add-CellLine -Cell $tc[3] -Ns $ns `
                                            -Value ($attemptPrefix + $(if ($isS) { $M.satisfactoryText } else { $M.notSatisfactoryText })) `
                                            -Color $(if ($isS) { $M.satisfactoryColor } else { $M.notSatisfactoryColor }))
                        $totalTasks++
                        if ($isS) { $totalS++ } else { $totalNys++ }
                    }
                }

                # THE LABELLED ASSESSOR CELL, ONE PER TASK THAT NAMES ONE.
                #
                # Rows are claimed IN ORDER, not by emptiness. Claiming the first
                # EMPTY box worked only while every box arrived empty: a
                # submission that comes back with its assessor sections already
                # completed matched no row at all, every task fell through to the
                # anchor fallback, and the fallback placed each comment at the end
                # of a block that ends inside that activity's sign-off table â€”
                # which the observation sheet's own field writer then cleared.
                # The build reported five tasks commented and the delivered file
                # carried two. Ordered claiming makes the box a task owns depend
                # on the instrument, not on whether someone typed in it first.
                #
                # A box that already carries text is APPENDED to, never
                # overwritten: whatever is in it is part of the record.
                $claimed = New-Object System.Collections.ArrayList
                foreach ($t in $tasks) {
                    $label = "$($t.commentCellLabel)"
                    if (-not $label) { continue }
                    foreach ($tbl in @($pkg.Body.SelectNodes('.//w:tbl', $ns))) {
                        foreach ($row in @($tbl.SelectNodes('w:tr', $ns))) {
                            $tc = @($row.SelectNodes('w:tc', $ns))
                            if ($tc.Count -lt 2) { continue }
                            if ((Get-RunText $tc[0] $ns).Trim() -ne $label) { continue }
                            if ($claimed.Contains($row)) { continue }
                            if ($placed.ContainsKey($t.ref)) { continue }
                            [void]$claimed.Add($row)
                            $ps = @(Split-CommentParagraphs "$($t.comment)")
                            if ((Get-RunText $tc[1] $ns).Trim()) {
                                foreach ($pp in $ps) { [void](Add-CellLine -Cell $tc[1] -Ns $ns -Value $pp) }
                            } else {
                                [void](Set-CellText -Cell $tc[1] -Ns $ns -Value $ps[0])
                                for ($z = 1; $z -lt $ps.Count; $z++) { [void](Add-CellLine -Cell $tc[1] -Ns $ns -Value $ps[$z]) }
                            }
                            $isS = ($t.outcome -eq 'S')
                            [void](Add-CellLine -Cell $tc[1] -Ns $ns `
                                                -Value $(if ($isS) { $M.satisfactoryText } else { $M.notSatisfactoryText }) `
                                                -Color $(if ($isS) { $M.satisfactoryColor } else { $M.notSatisfactoryColor }))
                            $placed[$t.ref] = $true
                        }
                    }
                }
                $tasks = @($tasks | Where-Object { -not $placed.ContainsKey($_.ref) })
            }

            if ($tasks.Count -gt 0) {
                $paras = @(Get-BodyParagraphs $pkg)      # positional: the parameter is -Package, so -Pkg bound nothing and $Package came through null
                $tLoc  = @()
                $tProb = @()
                foreach ($t in $tasks) {
                    $aText = if ($t.PSObject.Properties.Name.Contains('anchor') -and $t.anchor) { $t.anchor } else { $t.ref }
                    $hits  = @(Find-ParagraphIndex -Paragraphs $paras -Ns $ns -Text $aText)
                    if ($hits.Count -eq 0) { $tProb += "task '$($t.ref)': no paragraph contains '$aText'"; continue }
                    if ($hits.Count -gt 1) { $tProb += "task '$($t.ref)': '$aText' appears $($hits.Count) times; give it a unique 'anchor' in the ledger"; continue }
                    $tLoc += [pscustomobject]@{ ref = $t.ref; index = $hits[0]; outcome = $t.outcome; comment = "$($t.comment)" }
                }
                if ($tProb.Count -gt 0) {
                    throw ("$($s.fullName) / $($res.toolName): cannot mark the tasks in this submission.`n  " + ($tProb -join "`n  ") + "`nNothing was written. Fix the anchors and run again.")
                }

                $tLoc = @($tLoc | Sort-Object index)
                $tTail = $paras.Count
                if ($res.PSObject.Properties.Name.Contains('tasksEndAnchor') -and $res.tasksEndAnchor) {
                    $endHits = @(Find-ParagraphIndex -Paragraphs $paras -Ns $ns -Text $res.tasksEndAnchor)
                    $afterEnd = @($endHits | Where-Object { $_ -gt $tLoc[$tLoc.Count - 1].index })
                    if ($afterEnd.Count -eq 0) {
                        throw "$($s.fullName) / $($res.toolName): tasksEndAnchor '$($res.tasksEndAnchor)' was not found after the last task. Nothing was written."
                    }
                    $tTail = $afterEnd[0]
                } else {
                    $lastWarnings += "$($s.fullName) / $($res.toolName): no tasksEndAnchor, so '$($tLoc[$tLoc.Count-1].ref)' was marked at the end of the document. Check where its outcome landed."
                }

                # bottom up, so the earlier indices stay valid
                for ($i = $tLoc.Count - 1; $i -ge 0; $i--) {
                    $t    = $tLoc[$i]
                    $next = if ($i -lt $tLoc.Count - 1) { $tLoc[$i + 1].index } else { $tTail }
                    $ti     = Get-OutcomeTargetIndex -Paragraphs $paras -Ns $ns -From $t.index -Next $next
                    $target = $paras[$ti]

                    $isS  = ($t.outcome -eq 'S')
                    $col  = if ($isS) { $M.satisfactoryColor } else { $M.notSatisfactoryColor }
                    $text = ($attemptPrefix + $(if ($isS) { $M.satisfactoryText } else { $M.notSatisfactoryText }))

                    # comment first, outcome last, so the coloured line closes
                    # the task the way it closes a question
                    $block = @()
                    $block += New-TextParagraph -Doc $doc -Text ("{0}{1} — {2}" -f $attemptPrefix, $M.taskCommentHeading, $t.ref) `
                                                -Color $M.headingColor -Bold -SizeHalfPoints 22 -SpaceBefore 120 -SpaceAfter 40
                    foreach ($p in @(Split-CommentParagraphs $t.comment)) {
                        $block += New-TextParagraph -Doc $doc -Text $p -Color '000000' -SizeHalfPoints 22 -SpaceBefore 0 -SpaceAfter 60
                    }
                    $block += New-TextParagraph -Doc $doc -Text $text -Color $col -Bold -SpaceBefore 40 -SpaceAfter 120

                    $after = $target
                    foreach ($b in $block) { $after = Add-ParagraphAfter -Anchor $after -NewParagraph $b }
                }

                $totalTasks += $tLoc.Count
                $totalS     += @($tLoc | Where-Object { $_.outcome -eq 'S' }).Count
                $totalNys   += @($tLoc | Where-Object { $_.outcome -eq 'NYS' }).Count
            }

            # --- the assessor's observation record ---------------------------
            $obs = @()
            if ($res.PSObject.Properties.Name.Contains('observations') -and $res.observations) { $obs = @($res.observations) }
            if ($obs.Count -gt 0) {
                $sheet = $null
                if ($res.PSObject.Properties.Name.Contains('observationSheet') -and $res.observationSheet) { $sheet = $res.observationSheet }
                if ($sheet) {
                    $sns = @()
                    if ($sheet.PSObject.Properties.Name.Contains('snsChecklists') -and $sheet.snsChecklists) {
                        $sns = @($sheet.snsChecklists)
                    }
                    # Hand the record to Write-SnsChecklist only where a grid
                    # actually has a comments box to put it in. The small-table
                    # instrument has none, and skipping both writers would leave
                    # the record nowhere at all.
                    $snsHasBox = (@($sns | Where-Object { "$($_.comments)".Trim() -ne '' }).Count -gt 0)
                    [void](Write-ObservationSheet -Pkg $pkg -Sheet $sheet -Observations ([string[]]$obs) `
                                                  -Outcome $res.result -MarkingDateText $L.dates.markingDateText `
                                                  -Marked $M -Who "$($s.fullName) / $($res.toolName)" `
                                                  -SkipRecord:$snsHasBox)
                    if ($sheet.PSObject.Properties.Name.Contains('verification') -and $sheet.verification) {
                        [void](Write-VerificationRows -Pkg $pkg -Verification $sheet.verification `
                                                      -Who "$($s.fullName) / $($res.toolName)")
                    }
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
                    # The third sheet shape: an S / NS tick-box grid, with its
                    # own outcome table and one comments box, and no Yes/No
                    # paragraph boxes or comments column for the two writers
                    # above to find. One entry per grid in the submission. It
                    # also carries the tool-level record, into the first box.
                    $vts = @()
                    if ($sheet.PSObject.Properties.Name.Contains('verificationTables') -and $sheet.verificationTables) {
                        $vts = @($sheet.verificationTables)
                    }
                    [void](Write-VerificationTable -Pkg $pkg -Tables $vts -Who "$($s.fullName) / $($res.toolName)")
                    [void](Write-SnsChecklist -Pkg $pkg -Checklists $sns -Who "$($s.fullName) / $($res.toolName)" `
                                              -Observations ([string[]]$obs) -Outcome $res.result `
                                              -MarkingDateText $L.dates.markingDateText -Marked $M)

        # ---- the declaration page --------------------------------------------
        # A PAGE OF ITS OWN, not a block squeezed onto the student's cover sheet.
        # The cover sheet is the student's document: their name, their signature,
        # their declaration that the work is their own. Writing over the top of
        # it crowds both and leaves the result competing with their own heading.
        # A separate first page gives the result room and returns the student's
        # own page one exactly as they submitted it.
        # Three states, three colours. The amber comes from the RTO profile's
        # styling block, never from a literal here — see references/result-rules.md.
        $overallText =
            switch ($s.overall) {
                'C'  { $M.overallCompetentText }
                'RW' { $M.overallWithheldText }
                default { $M.overallNotCompetentText }
            }
        $overallCol =
            switch ($s.overall) {
                'C'  { $M.satisfactoryColor }
                'RW' { $Rto.styling.resultWithheldColor }
                default { $M.notSatisfactoryColor }
            }
        if (-not $overallText) { throw "RTO profile declares no overall text for result '$($s.overall)'." }
        if (-not $overallCol)  { throw "RTO profile declares no colour for result '$($s.overall)' — add styling.resultWithheldColor." }

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

        # ---- THE FEEDBACK, IN THE RTO'S OWN SHEET FORMAT ---------------------
        # Page one follows the RTO's Student Feedback Sheet section for section:
        # the details block, the items to fix, what happens next, the assessor's
        # name and date. A student who receives a standalone sheet and a student
        # who receives a marked copy then read the same document, and neither
        # has to be taught a second layout.
        #
        # The heading carries the attempt and the date. It is what makes a stack
        # of feedback pages readable, and what the gate counts.
        $FP = $M.feedbackPage
        if (-not $FP) { throw "RTO profile declares no markedAssessment.feedbackPage, so page one has no format to follow." }
        $lbl = $FP.labels

        $overallWord = "$overallText"
        $colonAt = $overallWord.IndexOf(':')
        if ($colonAt -ge 0) { $overallWord = $overallWord.Substring($colonAt + 1).Trim() }

        # THE SHEET IS A TABLE, and so is this. The standalone sheet is banner
        # rows in the accent colour, label cells on a tint and one row per item
        # across five columns. Built here as indented paragraphs it read as a
        # near-miss of the sheet rather than the sheet — same words, different
        # document — which is the second layout this page exists to avoid.
        # Same tables, same palette, same page.
        $accent = $M.headingColor
        # The sheet palette, from the RTO profile. The three brands share one
        # measured palette, so a profile written before these keys existed
        # still builds — it falls back to the same values it would declare.
        $fill = "$($Rto.styling.feedbackSheetFill)"; if (-not $fill) { $fill = 'F0F2F7' }
        $rule = "$($Rto.styling.feedbackSheetRule)"; if (-not $rule) { $rule = 'C3CBDA' }

        # The sheet's own 8-column grid, in the template's proportions. It is
        # scaled onto the width the student's own tables actually draw at, so
        # the sheet lines up with every page beneath it rather than sitting on
        # a width measured from a different document.
        $sheetW = 9890
        if ($box -and $box.TableWidth -gt 0) { $sheetW = $box.TableWidth }
        $g = Get-ScaledGrid -Proportions @(520, 1580, 320, 2100, 425, 2100, 375, 2470) -TotalWidth $sheetW
        $tblInd  = if ($box) { $box.IndentLeft } else { 0 }
        $wAll    = $sheetW
        $wLabel  = $g[0] + $g[1]                       # label column
        $wWide   = $g[2] + $g[3] + $g[4] + $g[5] + $g[6] + $g[7]
        $wVal1   = $g[2] + $g[3] + $g[4]               # first value in a pair row
        $wLabel2 = $g[5]
        $wVal2   = $g[6] + $g[7]
        $iNo     = $g[0]                               # item table: No.
        $iTool   = $g[1] + $g[2]                       #             Assessment tool
        $iQ      = $g[3]                               #             Question / task
        $iIssue  = $g[4] + $g[5] + $g[6]               #             Issue identified
        $iAction = $g[7]                               #             What you need to do

        $sheetArgs = @{ RuleColor = $rule; AccentColor = $accent }

        # One cell paragraph, in the sheet's face. A scriptblock rather than a
        # function because it has to close over $doc, which is this student's
        # document and changes every time round the loop.
        $SP = {
            param($Text, [switch]$Bold, [switch]$Italic, [string]$Color = '000000', [int]$Size = 18, [string]$Align)
            New-SheetParagraph -Doc $doc -Text "$Text" -Bold:$Bold -Italic:$Italic -Color $Color -SizeHalfPoints $Size -Align $Align
        }

        # The heading carries the attempt and the date, centred over the sheet
        # the way the standalone sheet's own title is.
        $header += New-TextParagraph -Doc $doc -Text ("{0} — Attempt {1}  ·  {2}" -f $FP.title, $s.attempt, $L.dates.markingDateText) `
                                     -Color $accent -Bold -SizeHalfPoints 30 -SpaceBefore 0 -SpaceAfter 60 -Align 'center' @fit

        $t1 = New-SheetTable -Doc $doc -Widths $g -Indent $tblInd -RuleColor $rule

        Add-SheetRow -Doc $doc -Table $t1 -Height 340 @sheetArgs -Cells @(
            @{ Width = $wAll; Span = 8; Fill = $accent; Paragraphs = (& $SP $FP.detailsHeading -Bold -Color 'FFFFFF' -Align 'center') }
        ) | Out-Null

        # The RTO identity line the standalone sheet carries in its first row.
        if ($Rto.rto.identityLine) {
            Add-SheetRow -Doc $doc -Table $t1 -Height 300 @sheetArgs -Cells @(
                @{ Width = $wLabel; Span = 2; Fill = $fill; Paragraphs = (& $SP 'RTO' -Bold) },
                @{ Width = $wWide;  Span = 6;               Paragraphs = (& $SP $Rto.rto.identityLine -Size 17) }
            ) | Out-Null
        }

        # Two label/value pairs to a row, exactly as the sheet sets them out.
        # 'Assessment' names every tool in the file and runs full width because
        # a list of tool names does not fit half of one.
        $pairs = @(
            @($lbl.studentName, $s.fullName,                                             $lbl.studentId,  $s.studentId),
            @($lbl.unit,        ("{0} {1}" -f $L.unit.code, $L.unit.title),               $lbl.qualification, ("{0} {1}" -f $L.qualification.code, $L.qualification.title)),
            @($lbl.assessor,    $L.assessor,                                              $lbl.markingDate, $L.dates.markingDateText),
            # The profile's overall text reads 'Overall result: Competent',
            # written for the coloured line in the corner. Under a label that
            # already says Overall result it would say it twice, so the label's
            # own words are dropped and the code kept beside the word.
            @($lbl.overall,     ("{0} ({1})" -f $overallWord, $s.overall),                $lbl.resubmissionDue, $s.resubmissionDueText)
        )
        $rowIdx = 0
        foreach ($pr in $pairs) {
            Add-SheetRow -Doc $doc -Table $t1 -Height 300 @sheetArgs -Cells @(
                @{ Width = $wLabel;  Span = 2; Fill = $fill; Paragraphs = (& $SP $pr[0] -Bold) },
                @{ Width = $wVal1;   Span = 3;               Paragraphs = (& $SP $pr[1]) },
                @{ Width = $wLabel2;             Fill = $fill; Paragraphs = (& $SP $pr[2] -Bold) },
                @{ Width = $wVal2;   Span = 2;               Paragraphs = (& $SP $pr[3]) }
            ) | Out-Null
            # 'Assessment' sits between the qualification row and the assessor row.
            if ($rowIdx -eq 1) {
                Add-SheetRow -Doc $doc -Table $t1 -Height 300 @sheetArgs -Cells @(
                    @{ Width = $wLabel; Span = 2; Fill = $fill; Paragraphs = (& $SP $lbl.assessment -Bold) },
                    @{ Width = $wWide;  Span = 6;               Paragraphs = (& $SP (($mc.toolNames) -join '  ·  ') -Size 17) }
                ) | Out-Null
            }
            $rowIdx++
        }

        # The referral note. Italic on the tint rather than red, because the
        # result already reads in colour twice above it and a third shout adds
        # nothing; the words carry it on their own.
        if ($s.overall -ne 'C') {
            Add-SheetRow -Doc $doc -Table $t1 -Height 300 @sheetArgs -Cells @(
                @{ Width = $wAll; Span = 8; Fill = $fill; Paragraphs = (& $SP $M.referralText -Italic -Size 17) }
            ) | Out-Null
        }

        # The per-tool feedback. The sheet has no narrative column, so it sits
        # under its own banner between the details and the items — the same
        # words the SAR carries for that tool, from the same ledger field.
        Add-SheetRow -Doc $doc -Table $t1 -Height 340 @sheetArgs -Cells @(
            @{ Width = $wAll; Span = 8; Fill = $accent; Paragraphs = (& $SP $FP.feedbackHeading -Bold -Color 'FFFFFF' -Align 'center') }
        ) | Out-Null

        $itemsAll = @()
        foreach ($res in @($s.results)) {
            # The assessor's comment is at least two paragraphs, so the cell
            # takes a paragraph per paragraph. Rendered as one run it would
            # come out as a wall with the paragraph breaks swallowed, which is
            # how the two-paragraph standard silently stopped being visible.
            $fbParas = @(Split-CommentParagraphs "$($res.feedback)")
            if ($fbParas.Count -eq 0) { $fbParas = @("$($res.feedback)") }
            Add-SheetRow -Doc $doc -Table $t1 -Height 300 @sheetArgs -Cells @(
                @{ Width = $wLabel; Span = 2; Fill = $fill; Paragraphs = (& $SP $res.toolName -Bold) },
                @{ Width = $wWide;  Span = 6;               Paragraphs = @($fbParas | ForEach-Object { & $SP $_ -Size 17 }) }
            ) | Out-Null
            foreach ($it in @($res.items)) {
                $itemsAll += [pscustomobject]@{ toolName = $res.toolName; questionNo = $it.questionNo; issue = $it.issue; action = $it.action }
            }
        }

        # The ten-item cap and its closing note live with the items.
        # Page one may run past one physical page where the feedback is long;
        # what matters is the page break before the student's own content.
        Add-SheetRow -Doc $doc -Table $t1 -Height 340 @sheetArgs -Cells @(
            @{ Width = $wAll; Span = 8; Fill = $accent; Paragraphs = (& $SP $FP.itemsHeading -Bold -Color 'FFFFFF' -Align 'center') }
        ) | Out-Null

        $overflow = 0
        if ($itemsAll.Count -gt $ITEM_CAP) {
            $overflow  = $itemsAll.Count - $ITEM_CAP
            $itemsAll  = $itemsAll[0..($ITEM_CAP - 1)]
        }
        if ($itemsAll.Count -eq 0) {
            # Nothing to correct: one plain row rather than five empty columns.
            Add-SheetRow -Doc $doc -Table $t1 -Height 300 @sheetArgs -Cells @(
                @{ Width = $wAll; Span = 8; Paragraphs = (& $SP $FP.noItemsText -Size 17) }
            ) | Out-Null
        } else {
            Add-SheetRow -Doc $doc -Table $t1 -Height 300 -Header @sheetArgs -Cells @(
                @{ Width = $iNo;                  Fill = $accent; Paragraphs = (& $SP 'No.'                  -Bold -Color 'FFFFFF' -Size 17 -Align 'center') },
                @{ Width = $iTool;   Span = 2;    Fill = $accent; Paragraphs = (& $SP $FP.itemColumns.tool     -Bold -Color 'FFFFFF' -Size 17 -Align 'center') },
                @{ Width = $iQ;                   Fill = $accent; Paragraphs = (& $SP $FP.itemColumns.question -Bold -Color 'FFFFFF' -Size 17 -Align 'center') },
                @{ Width = $iIssue;  Span = 3;    Fill = $accent; Paragraphs = (& $SP $FP.itemColumns.issue    -Bold -Color 'FFFFFF' -Size 17 -Align 'center') },
                @{ Width = $iAction;              Fill = $accent; Paragraphs = (& $SP $FP.itemColumns.action   -Bold -Color 'FFFFFF' -Size 17 -Align 'center') }
            ) | Out-Null

            $n = 0
            foreach ($it in $itemsAll) {
                $n++
                Add-SheetRow -Doc $doc -Table $t1 -Height 420 @sheetArgs -Cells @(
                    @{ Width = $iNo;               Fill = $fill; Paragraphs = (& $SP $n -Bold -Align 'center') },
                    @{ Width = $iTool;   Span = 2;               Paragraphs = (& $SP $it.toolName   -Size 17) },
                    @{ Width = $iQ;                              Paragraphs = (& $SP $it.questionNo -Size 17) },
                    @{ Width = $iIssue;  Span = 3;               Paragraphs = (& $SP $it.issue      -Size 17) },
                    @{ Width = $iAction;                         Paragraphs = (& $SP $it.action     -Size 17) }
                ) | Out-Null
            }
            if ($overflow -gt 0) {
                Add-SheetRow -Doc $doc -Table $t1 -Height 300 @sheetArgs -Cells @(
                    @{ Width = $wAll; Span = 8; Paragraphs = (& $SP ("A further {0} item(s) are marked in your returned assessment. Correct those as well." -f $overflow) -Size 17) }
                ) | Out-Null
            }
        }
        $header += $t1

        # A paragraph between the tables. Two w:tbl elements with nothing
        # between them are one table to Word, and the second one's grid would
        # be pulled onto the first one's columns.
        $header += New-TextParagraph -Doc $doc -Text '' -SpaceBefore 0 -SpaceAfter 140 @fit

        # ---- what happens next, and the sign-off -----------------------------
        $t2 = New-SheetTable -Doc $doc -Widths @($wLabel, $wWide) -Indent $tblInd -RuleColor $rule

        $nextLines = @($FP.nextLines)
        if ($itemsAll.Count -eq 0 -and $nextLines.Count -gt 1) { $nextLines = @($nextLines[1..($nextLines.Count - 1)]) }
        if ($s.PSObject.Properties.Name.Contains('furtherInstruction') -and $s.furtherInstruction) {
            $nextLines += "$($s.furtherInstruction)"
        }
        Add-SheetRow -Doc $doc -Table $t2 @sheetArgs -Cells @(
            @{ Width = $wLabel; Fill = $fill; Paragraphs = (& $SP $FP.nextHeading -Bold) },
            @{ Width = $wWide;                Paragraphs = @($nextLines | ForEach-Object { & $SP $_ -Size 17 }) }
        ) | Out-Null

        Add-SheetRow -Doc $doc -Table $t2 -Height 300 @sheetArgs -Cells @(
            @{ Width = $wLabel; Fill = $fill; Paragraphs = (& $SP $FP.assessorHeading -Bold) },
            @{ Width = $wWide;                Paragraphs = (& $SP ("$($FP.assessorLine)".Replace('{ASSESSOR}', "$($L.assessor)").Replace('{DATE}', "$($L.dates.markingDateText)"))) }
        ) | Out-Null
        $header += $t2

        # ---- the withheld-result notice --------------------------------------
        # Approved RTO wording, filled from the ledger and the profile. Outside
        # the two-comma rule by design — see Lib-Text.ps1.
        if ($s.overall -eq 'RW') {
            $notMet = @($s.prerequisitesNotMet)
            if ($notMet.Count -eq 0) { throw "$($s.fullName): overall is RW but no unmet prerequisite is recorded, so the withheld notice cannot name one." }
            $contact = $Rto.studentAdminContact
            if (-not $contact -or -not $contact.name) { throw "RTO profile declares no studentAdminContact. The withheld notice names it twice and a student must have someone to ask." }

            $unitFull    = "{0} – {1}" -f $L.unit.code, $L.unit.title
            $prereqFull  = (@($notMet | ForEach-Object { "{0} – {1}" -f $_.code, $_.title }) -join ', ')
            $prereqCodes = (@($notMet | ForEach-Object { $_.code }) -join ' and ')
            $thisUnit    = if ($notMet.Count -eq 1) { 'this unit' } else { 'these units' }
            # Join only the parts that exist. An RTO that supplies no phone
            # number should not have the notice print 'Student Administration,
            # info@..., ' with a comma hanging off the end of it.
            $adminFull   = (@($contact.name, $contact.email, $contact.phone) |
                            Where-Object { "$_".Trim() -ne '' }) -join ', '

            $notice = Get-WithheldNoticeTemplate
            $notice = $notice.Replace('{UNITCODE}',   $L.unit.code).
                              Replace('{UNIT}',       $unitFull).
                              Replace('{PREREQCODES}',$prereqCodes).
                              Replace('{PREREQS}',    $prereqFull).
                              Replace('{THISUNIT}',   $thisUnit).
                              Replace('{PROVIDER}',   $Rto.rto.tradingName).
                              Replace('{ADMINNAME}',  $contact.name).
                              Replace('{ADMINFULL}',  $adminFull).
                              Replace('{ASSESSOR}',   $L.assessor).
                              Replace('{DATE}',       $L.dates.markingDateText)
            if ($notice -match '\{[A-Z]+\}') { throw "$($s.fullName): the withheld notice still carries an unfilled field." }

            $first = $true
            foreach ($line in ($notice -split "`r?`n")) {
                if (-not $line.Trim()) { continue }
                $bold = $first
                $p = if ($bold) {
                    New-TextParagraph -Doc $doc -Text $line -Color $Rto.styling.resultWithheldColor -Bold -SizeHalfPoints 24 -SpaceBefore 160 -SpaceAfter 60 @fit
                } else {
                    New-TextParagraph -Doc $doc -Text $line -Color '000000' -SizeHalfPoints 22 -SpaceBefore 0 -SpaceAfter 40 @fit
                }
                $header += $p
                $first = $false
            }
        }

        foreach ($a in $appendObs) {
            $header += New-TextParagraph -Doc $doc -Text ("{0}{1} — {2}" -f $attemptPrefix, $M.observationHeading, $a.toolName) -Color $M.headingColor -Bold -SizeHalfPoints 24 -SpaceBefore 80 -SpaceAfter 60 @fit
            foreach ($point in $a.points) {
                $header += New-TextParagraph -Doc $doc -Text ("{0}  {1}" -f $M.observationBullet, $point) -Color '000000' -SizeHalfPoints 22 -SpaceBefore 0 -SpaceAfter 40 @fit
            }
            $header += New-TextParagraph -Doc $doc -Text ("{0}{1}  {2}" -f $attemptPrefix, $M.observationCompletedText, $L.dates.markingDateText) -Color $M.headingColor -SizeHalfPoints 22 -SpaceBefore 40 -SpaceAfter 60 @fit
            $aText = ($attemptPrefix + $(if ($a.result -eq 'S') { $M.satisfactoryText }  else { $M.notSatisfactoryText }))
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
            tasks     = $totalTasks
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
        if ($b.tasks    -gt 0)  { $what += "{0} task(s) judged and commented" -f $b.tasks }
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

