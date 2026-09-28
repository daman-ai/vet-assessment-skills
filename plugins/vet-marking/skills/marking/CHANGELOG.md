# Changelog

## v2.11.0 — 28 September 2026

- **Rule 4 in `Get-OutcomeTargetIndex`: the outcome line must end up INSIDE the
  response box.** Rules 1 to 3 all walk back from the next question, and rule 3
  only engages where that next question opens a table of its own. Where it is
  plain body text — as every ACI CPCC task's `(a)` is, under its own Task
  heading — nothing stopped the walk-back at the box, and the verdict came to
  rest on the last non-empty paragraph before the anchor: the **next** task's
  *Question / instructions* line.

  Two things went wrong at once and neither showed in a build log. The student's
  own response box came back **empty** — which this skill names by name, *"the
  student's eye goes to the box and finds nothing in it"* — and a red Not yet
  Satisfactory printed directly above a part they had passed. Every gate passed
  it, because each question did carry an outcome in the right colour; only
  reading *where* it landed finds it.

  Found by the annotated feedback map on the CPCCSP3001 24 September copies,
  where it hit the last sub-question of nearly every task — 12 of 43 on one
  student. Rule 4 now places the line after the last thing written inside the
  question's own response box; where rules 1 to 3 already landed inside the box
  it changes nothing. A lookahead bound stops a question whose response is plain
  paragraphs from adopting the next task's scenario or *Maps to* box as its own.
  All four CPCCSP3001 copies rebuilt: 12 misplaced verdicts to zero, main gate
  40/40.

- **The marking gate no longer mistakes an annotated map for a record.** Built
  into the same directory as the records, `ANNOTATED_*.docx` read as unexpected
  files and as marked copies missing their tool name — three checks failed on
  documents that were correct. They are excluded now, and **named in the
  summary** rather than quietly filtered: a gate that drops files from its
  inventory without saying so is a gate with a hole in it, and the next thing to
  land in that directory would vanish the same way. They have their own gate.

- **A fifth document type: the annotated feedback map.** Each page of the
  student's marked copy is reproduced at 75% of the text width, each item of
  feedback is written in the column beside it, and a hand-drawn arrow runs from
  the note to the exact place on the page. Built by
  `Build-AnnotatedFeedback.ps1`, checked by `Test-AnnotatedFeedback.ps1`,
  described in `references/annotated-feedback.md`. It is **optional and
  additional**: the Student Feedback Sheet is the RTO's record that feedback was
  issued, and the map travels with it rather than instead of it.
  - **It adds placement, never content.** Every note is the ledger's `items[]`
    row, rendered a second time — the same row the feedback sheet prints. The
    sheet and the map cannot drift, because there is one description of a fault
    and two renderings of it.
  - **It never opens the student's work for writing.** Widening the marked
    copy's right margin to make room for the notes would reflow the student's
    document, move every page break and push fixed-width response tables off the
    page. The builder renders each page as a picture and annotates the picture.
  - **Word supplies the coordinates.** `Range.Information` gives a found
    anchor's page and its position in points, which is the space the exported
    PDF renders in, so the arrow lands without a calibration step. It points
    between one question's anchor and the next — the middle of the response —
    and at the right edge of the text column, which is clear of the student's
    own writing where the middle is not.
  - **The page is narrowed, not shrunk.** The height is left at the full text
    height and only the width is taken to 75%, so the column opens on the right
    without costing a third of the page. `-KeepAspect` restores proportional
    scaling where the returned work has to measure true.
  - **Every question carries a panel, pass and fail.** Satisfactory is a quiet
    green-outlined panel with a thin grey leader; Not yet Satisfactory is a
    solid blue panel with white type, a full-weight arrow and a numbered ring.
    Blue because the page is already carrying the red and green of the marked
    copy's own outcome lines, so a red panel competes and a green one reads as a
    pass. A column of failures alone left every unannotated page ambiguous —
    right, or not looked at?
  - **The note sits level with the CENTRE OF THE WRITING**, not of the box. A
    response box is sized for the longest answer the writers expected, so a
    student who answered in six lines leaves two thirds of it blank; centring on
    the box put the note in the middle of an empty page with the answer well
    above it. Only the paragraphs carrying text are measured. That also disposed
    of a second fault: a table's `Range.End` sits just PAST the table, often on
    the following page, so a box wholly on one page looked broken across two and
    took the page-break fallback. Writing that genuinely runs over a break
    centres on the part on its first page, because where an answer starts is
    where the student looks. The outcome line is now the fallback, not the
    target.
  - **The outcome line is found** by
    searching for `Not yet Satisfactory` only within the span between this
    question's anchor and the next, so the right line is found though every NYS
    question carries the same words. Only the opening words are matched, because
    profiles end the line *refer to the feedback sheet* or *refer to the
    feedback page*. The midpoint between anchors is the fallback: on a task
    whose stem runs to a paragraph, the midpoint is still the stem.
  - **It reports a verdict written outside the student's response box.** The
    test is structural — is the line inside a table? — and self-calibrating:
    where most of a document's verdicts sit in a box, the ones that do not are
    named; where hardly any do, the instrument does not work that way and
    nothing is said. A page-distance test was tried first and was worse in both
    directions: it flagged long answers that legitimately run onto the next page
    and missed a verdict one page on in the next task's heading block.
    On the CPCCSP3001 24 Sep copy it finds **12 of 43** — Q1(c), Q2(b), Q3(c),
    Q4(b), Q5(b), Q6(c), Q7(b), Q8(c), Q9(c), Q10(c), Q11(c) and T2(d), which is
    the last part of nearly every task. Those response boxes come back to the
    student empty and the verdict prints over the next task's heading.
  - **Scratch paths are per copy, not per student.** A student whose tools
    arrived as separate files has several marked copies under one studentId, and
    the second collided with the first's working directory. It surfaced only
    once every question produced an entry, because the student it hit had been
    skipped before.
  - **`-Timing`** prints the elapsed time of each stage. Word COM and the PDF
    renderer vary enough between instruments that "it is taking a while" is not
    a diagnosis. **Known limitation:** a table-heavy instrument is far slower
    than its page count suggests — CPCCSP3001 builds 54 pages in under two
    minutes, SITHPAT020 at 37 pages but 71 tables takes considerably longer.
    The Word stages were measured at about 5s in total on that document, so the
    document's size is not the cause and the cost lies later in the pipeline.
    Records are unaffected; this is the optional map only.
  - **The whole assessment is the default.** Every page of the marked copy is
    carried, annotated where there is something to say, so the map is read end
    to end rather than as an extract that sends the student back to the marked
    copy for context. `-NotedPagesOnly` gives the extract where a short handout
    is wanted; `-Dpi 110` roughly halves a long workbook's file size.
  - **The wobble is seeded from the item's text, not `Get-Random`.** Rebuilding
    the same ledger twice produces a byte-identical `document.xml`; arrows that
    moved on every build would defeat a gate that reads delivered files back.
  - **Nothing is dropped and nothing is claimed.** An item whose `questionNo` is
    a label rather than a question ref has nothing to point at; it is still
    printed at the end of the map and counted in the run's report. Where no item
    on a copy could be anchored, no map is built — a map with no arrow is the
    feedback sheet behind a picture of the cover page — and the run names those
    students rather than leaving a missing file to be noticed later.
  - `0xFFFFFFFF` parses as Int32 `-1` in PowerShell 5.1, so masking a hash with
    it changes nothing and the product then overflows a `[uint32]` cast. The
    seed uses `0xFFFFFFFFL`.

## v2.10.1 — 24 September 2026

- **Inline S / NS grids in `snsChecklists`.** A grid headed by one `S / NS`
  column with `☐ S ☐ NS` in each cell is now a grid. The box is ticked inside
  the cell, the entry's `outcome` ticks the `□ Satisfactory (S) □ Not
  Satisfactory (NS)` line after it, `comments` replace the box's `Record … here…`
  prompt, and the `Assessor name:` line is filled with the signature blank.
  Found only in tables with no separate S and NS columns, and not at all where
  the tool's sheet is `layout: "inlinePairs"`, so every existing grid count is
  unchanged. `MarkedCopySnsChecklist` carries the writer's patterns and checks
  each inline grid's ticks, box, outcome line and sign-off against that grid.
  Written for ACI CPCCSP3001's two observation occasions.
- **The resolver refused a sheet with no `outcomes`.** `@($null)` is one
  element, so a sheet that only carries `snsChecklists` failed with "outcomes
  must each be 'Yes', got ''".
- **`Test-SubmissionBlanks.ps1` reported every question unanswered.** It split
  the key file on `|` only; a tab-separated file gave every key an empty
  anchor, which every paragraph contains, so all questions sat on paragraph 0.
  Tabs are read, an empty anchor is refused, a key missing from a copy is
  listed under KEY NOT FOUND, short table labels count as template text, a
  `Write … here…` prompt is not an answer, `-EndAnchor` closes the last block,
  and assessor sign-off lines are no longer reported as blank student lines.

## v2.10.0 — 23 September 2026

Two lines of this skill had been running apart since early September and are
merged here. Neither was ahead of the other: the machine copy carried the
CPCCCM2008 / CPCCSP2002 / CPCCSP2003 work and the repository copy carried the
SITXMGT004 rulings and everything the RTO settled on 8 and 10 September.

**Both lines called their release v2.8.0.** The entry below dated 8 September is
the repository's; the machine's v2.8.0 of 9 September is folded into this one.

### Brought across from the CPCC line

- **S / NS checklist grids.** The third observation-sheet shape — criteria down
  the rows, bare boxes under `S` and `NS`, no Yes/No words anywhere.
  `snsChecklists` takes one entry per grid in document order, each with its own
  `outcomes` and, where the instrument provides them, an `outcome`, a `comments`
  box, a per-row `notes` column and a `decision` answering the task decision
  line printed after the grid. A count that does not match the grids found is a
  hard failure. Three spellings of the pair are in circulation and the
  not-satisfactory heading is matched first; two characters are used for an
  empty box. `Write-SnsChecklist`, `Write-VerificationTable`, `Set-BoxAtIndex`,
  `New-CommentsBox` and `Get-SnsCellText`, gated by `MarkedCopySnsChecklist` and
  `MarkedCopyTaskDecision`.
- **`Test-LearnerPronouns`** refuses a gendered pronoun in assessor prose —
  observation records, criterion comments, checklist comments and notes.
  Feedback written *to* the student is second person and is not checked.
- **A paragraph's own mark carries a colour, and it is read before the run's.**
  `w:pPr/w:rPr/w:color` tints only the pilcrow, so it changes nothing a reader
  sees, but it is the first `w:color` in the paragraph. Three green Satisfactory
  lines were reported as black. `Set-CellText` and `Add-CellLine` now clear it.
- **A submission with no table at all** — one arrived as fifty-three page images
  and nothing else — now reports its content box on the text margin rather than
  returning `$null`.
- **`Test-AiFlag` unrolled a single-object JSON file into nothing.** It now
  appends element by element.

### Three defects the merge itself uncovered

All three were splices left by the earlier hand-merge onto the pre-v2.6.0 line.
Each passed a parse and each was silently wrong, so each is fixed here rather
than carried across as it stood.

1. **The S / NS writers ran once per student instead of once per tool.**
   `Write-VerificationTable` and `Write-SnsChecklist` sat *outside* both the
   `if ($sheet)` block and the per-tool loop, reading `$sheet`, `$sns`, `$res`
   and `$obs` left over from the final iteration. On a student with more than
   one tool, every tool but the last had its grids left untouched. They are now
   inside the loop, beside `Write-ObservationSheet`.
2. **The criterion-comment pronoun check had never run.** It was placed inside
   the `observationSheet` blank-field branch and tested `$text`, a variable that
   appears exactly once in the file and is never assigned. It now runs in the
   comment loop it belongs to, against `$cmText` and `$ci`.
3. **`references/ledger.md` documented `snsChecklists` inside another comment.**
   The block had been spliced into the middle of a sentence about `anchorAfter`,
   outside the `observationSheet` object it describes. The sentence is whole
   again and the example sits inside the object.

### Where the two lines touched the same code

- `-SkipRecord` is kept, but skips **only** the notes-cell record. The sign-off
  row and the student feedback line are written either way, so the 8 September
  sign-off rule holds on an S / NS instrument.
- The S / NS record builder now honours the emptied `observationHeading` and
  `observationCompletedText`, matching what `Write-ObservationSheet` already did.
- `SKILL.md` describes three sheet shapes again, keeping the column-sheet detail
  and all four sections the repository line added.


## v2.9.0 — 8 September 2026

### What the student left blank is now found, not noticed

`Test-SubmissionBlanks.ps1` reads every submission in a cohort together and
reports unanswered questions, blank signature and date lines, and empty cells
above the floor the layout itself leaves. Template text is what several copies
share, so what is left inside a question block is the student's own answer.

**The RTO's rule, given the same day: a task left unanswered, a record left
undated, a signature line left empty is a requirement not demonstrated, and the
tool is NYS for it.** Stage 3b of SKILL.md runs the check; the assessor reads
the finding and marks it.

On SITXMGT004 it found what four readings had missed: 36 unsigned or undated
role-play records across four submissions, from two on the tidiest copy to
sixteen on another. It also demonstrated why the empty-cell count is a pointer
and not a verdict — one learner typed her whole workflow plan into a single cell,
leaving 36 grid cells empty behind complete work.

### Trainer and assessor details, everywhere they appear

A cover-sheet field may now name `"onRule": true`, which writes the value onto a
printed rule of underscores inside a cell that also carries the RTO's own
instructions — `Date Pre-requisite assessed ____/____/____` was the box that
could not be filled without deleting the paragraph beside it.
## v2.8.0 — 8 September 2026

Four rulings from the RTO, taken on SITXMGT004.

### The outcome follows the answer, never sits between question and answer

`Get-OutcomeTargetIndex` skipped back over a short run of the next question's
table to avoid landing among its heading rows. Where a question's stem, the
student's answer and the next stem all sat in ONE table — the workbook's
"Feedback on the daily tasks" block does — every paragraph between them belonged
to that table, so the skip walked back over the answer and printed the outcome
between the question and the answer it judged. The skip is now applied only
where the next question opens a table of its own.

### No banner and no completion line in the notes cell

`observationHeading` and `observationCompletedText` are empty in all three RTO
profiles, and an empty string prints nothing. The record in the notes cell is
the assessor's account of what the learner did, and the sheet already says
whose record it is. The gate no longer counts bullets between two markers that
are gone: where the heading is suppressed it matches each observation point by
its own words, which is the stronger test.

### The sign-off row is filled

`Set-SheetSignOff` writes the assessor's name against the signature label and
the date of assessment against the date label, into the cell beside the label
where the sheet gives one and onto a new line inside the label's own cell where
it does not. A cell the trainer filled on the day is left alone.

### At least three observation points, and several cover blocks

The resolver refuses an observation record of fewer than three points — where
the sheet gives room, fill it. And `coverSheet` now takes an array as well as a
single block, because a pack that prints its identity block twice left the
second one blank: `Write-CoverSheet` fills every block the ledger names and
`CoverSheetFilled` checks every one.
## v2.7.0 — 7 September 2026

Merged the 6 September group-packaging branch onto v2.6.0. That branch was cut
before v2.6.0 and carried its own fixes, so this is a merge in both directions:
its work came across, and nothing v2.6.0 added — prerequisites and RW
withholding, `inlinePairs` observation sheets, cover-sheet filling, observation
comments, resubmission stacking — was taken back out.

### Consolidation by WiseNet course-offer group

A marking run is scoped to a **day**. What the RTO files is scoped to a
**course-offer group**, and a group's learners are marked on whatever day their
work came in — so the records that go on the file are cut differently from the
runs that made them. Five scripts do the cutting, and Stage 8 of SKILL.md
describes the workflow.

- **`Read-Groups.ps1`** reads *every* worksheet of the 0217 export — one per
  course offer — and returns each group's roster. The importer read only the
  first, which silently lost every group but one.
- **`Merge-MarkingLedgers.ps1`** consolidates several resolved ledgers into one
  per group. It refuses the same student in two ledgers, a student on two
  worksheets, and a marked student on no worksheet at all: each is a record an
  auditor would reject. Every learner keeps their own feedback-given and
  resubmission dates; serials are renumbered per group and rows sorted by
  surname.
- **`Build-GroupPackage.ps1`** lays the documents out the way they are filed and
  handed back — a folder per group, its record at the top, a folder per student
  inside — copying every file by the exact name its ledger holds.
- **`Test-GroupPackage.ps1`** is the blocking gate for a package: eleven checks,
  including that each record names its own group's students and nobody else, and
  that no student ID sits under two group folders.
- **`Set-AmrrColumns.ps1`** re-lays a record's column widths, writing the grid
  and every cell together so Word does not reflow to the one that was not
  changed.
- **`Build-MarkingRecords.ps1 -RecordOnly`** builds the class record alone. The
  SARs, feedback sheets and marked copies were built, gated and issued by the
  runs being consolidated; rebuilding them would need the submissions back and
  would replace signed documents with fresh ones nobody has read.

### Two zip defects, one of which had a gate agreeing with it

`Save-Docx` used `ZipFile::CreateFromDirectory`, which on .NET Framework writes
**backslash entry names** — `word\document.xml`. Word opens those files, so
nothing complains, but Moodle will not preview them, Google Docs will not import
them and macOS Quick Look shows nothing. Every document this skill produced
carried it. The archive is now written entry by entry with `/`, and
`[Content_Types].xml` first.

The same class of defect sat in `Build-GroupPackage.ps1`, and there the gate
repeated the builder's arithmetic and agreed with it. Both computed a zip entry
name by subtracting `$dirFull.Length` from a `Get-ChildItem` `FullName`. Where
the account name runs past eight characters, `$env:TEMP` arrives in **8.3 short
form** (`C:\Users\ACI-AD~1\...`) while `FullName` comes back long, so the
subtraction cut one character short and the tail of the package folder's own
name became a directory inside the zip — every path under a phantom `e/`.
`ZipMatchesFolders` passed because it was wrong in exactly the same way. Builder
and gate now both enumerate with `Directory::GetFiles` from the same root
string.

### The SAR's blank page and its signature line

Filled in, a SAR's page 1 overflows by a line or two; what follows the template's
page break is then a page with eighty characters on it, or nothing at all. On the
5 September run every record came out that way; on the 6th, page 2 was completely
empty on all fifteen. `Remove-PageBreaks` lets the content flow — every field,
every table and their order unchanged — and the RTO's signature line goes with
`Remove-SignatureLine`, since the RTO signs in the student management system and
a ruled line on an issued record asks for something nobody will provide.

Neither is visible in the XML or in the template, only in a rendered, filled-in
record, so the gate now opens every SAR and looks: `SarNoBlankPage` and
`SarNoSignatureLine`.

### The gate steps over text boxes

`Get-BodyParagraphs` selects on the descendant axis, so a paragraph inside a
`w:txbxContent` sits in the list between an answer and the outcome line written
after it. `MarkedCopyInAnswerSpace` took `$i-1` blindly, compared the outcome
against a floating caption, and reported a correctly placed line as sitting
outside its response box. It now walks back past text-box paragraphs.


## v2.6.0 — 3 September 2026

### A third observation-sheet shape: both boxes in one cell

ACI's older CPCC packs head a single decision column `S / NS` and print both
boxes inside that one cell with their words beside them — `☐ S ☐ NS`. Neither
existing reader can see it. The labelled reader wants a paragraph that is only a
box and a word; the column reader wants a second heading to pair with the first.
Both returned no rows and no error, which would have left every criterion on a
signed sheet unjudged.

- New `observationSheet.layout: "inlinePairs"`, with `decisionHeader`,
  `yesLabel`, `noLabel` and `commentsHeader`. Criterion rows are found by the
  heading text and by the cell holding exactly the two labelled boxes; the count
  is checked against `outcomes` before anything is written.
- `Test-MarkingRecords.ps1` reads the delivered file the same way, so the ticks
  and the row notes are verified rather than trusted.
- The row-note standard now applies to `inlinePairs` as well as `columns`.
- **The anchor has to sit above the table.** The line these sheets invite you to
  anchor on — *To be completed by the Assessor only* — is inside the checklist's
  own first row, and a sheet anchored there excludes the table it names.

Found marking CPCCOM2001 on 3 September 2026, where two editions of the pack
were in circulation across one cohort.

## v2.5.0 — 3 September 2026

### The judgement goes in the box the instrument provides

A task outcome written as loose paragraphs after a table reads as an annotation
someone added. Written into the boxes the instrument already has, it reads as
the instrument being completed — which is what an auditor is looking for.

- **Every criterion row** of a performance checklist now carries its own
  coloured outcome, in that row's `Trainer/Assessor Comments` cell under the
  note already there. A student saw thirty-two coloured judgements on their
  knowledge test and, on the practical, three.
- **The task's own comment** goes in the cell the template labels for it —
  `tasks[].commentCellLabel` names it, `Assessor / Supervisor comments` in this
  unit. Only where the template provides no such cell does the ledger's anchor
  place a block in the body, which is now the fallback rather than the rule.
- `results[].checklistRowsMarked` records how many criterion rows were judged,
  because the count varies with the instrument — three criteria in one activity,
  a dozen in another — and `MarkedCopyOutcomes` counts them.

### Three counting bugs the new placement exposed

- **The colour was read from the wrong place.** `.//w:rPr/w:color` matches a
  paragraph-mark `w:pPr/w:rPr/w:color` first, so an outcome added inside a table
  cell was read as its pilcrow's colour and went uncounted. Both checks now read
  `.//w:r/w:rPr/w:color` — the colour the words are actually painted in.
- **A tick is not always text.** These students confirm with a Webdings symbol,
  `<w:sym w:font="Webdings" w:char="F061"/>`, which carries no `w:t` at all. A
  text-based check read the row as unticked and added a second mark beside the
  first. Anything that ticks a box is now looked for as a symbol as well.
- **`MarkedCopyObservationSheet`** compared a criterion's comments cell to the
  ledger's note for equality. The cell now also closes with that criterion's
  outcome, so the comparison is a starts-with.

### The sign-off blocks get completed

`Write-VerificationRows` grew a sibling behaviour across the SWMS blocks: a
`Print Name / Company / Signature / Date` row and a `Supervisor Name / Signature
/ Date` row are completed for a simulated assessment where they are blank. **A
cell already carrying the student's own entry is never overwritten.**

The comments column of a pre-start check table is usually **one vertically
merged cell**, not one per row. Writing a note into each row put all but the
first into merge continuations, which Word does not draw — the page showed one
comment and eleven blanks. The confirmations now go into the `w:vMerge` master
as one block.

## v2.4.0 — 3 September 2026

### The assessor's comment has to say something

**Twenty words is now a floor, not a ceiling.** The standard capped a paragraph
at twenty words; the comments that produced were too thin to stand as a record
of what the assessor saw. Every assessor comment is now **at least two
paragraphs of at least twenty words each**, with a ceiling of four sentences and
seventy words to a paragraph so it cannot sprawl the other way.

Two functions now carry that shape, because the voice differs:

| | judges | person |
|---|---|---|
| `Test-ObservationCommentStyle` | the assessor's record of what happened | third person — *Tarnpreet examined the drawings* |
| `Test-AssessorComment` | what the student reads, on a tool or a task | second person — *You answered all twelve questions* |

The old function banned `you` and `your`, which would have rejected every
correctly written piece of student-facing feedback in the skill.

The resolver blocks a build where any submitted tool's comment falls short, and
`AssessorCommentDepth` checks the DELIVERED text — a comment that meets the
standard in the ledger and lands on the page as one swallowed paragraph has
still failed the student reading it.

### Every task carries its own outcome

A tool made of tasks — three practical activities in a unit project — was judged
once at the foot of its observation sheet. A student saw thirty-two coloured
judgements on their knowledge test and none at all on the three activities they
actually performed.

`results[].tasks[]` now carries `ref`, `anchor`, `outcome` and `comment`. The
builder stamps the comment and a coloured outcome under each task; the resolver
holds the comment to the assessor-comment standard, requires S or NYS, and
refuses a Satisfactory tool holding a Not Yet Satisfactory task or the reverse.
`TaskOutcomeColoured` checks each block's heading appears once in the delivered
file and that its outcome follows in the right colour, and `MarkedCopyOutcomes`
counts task lines alongside question lines.

### The pre-start verification checklist gets filled

`observationSheet.verification[]` carries `item`, `outcome` and `note` per row.
`Write-VerificationRows` fills them — and **fills only what is blank**. Some
students complete this checklist on site in their own words before the assessor
sees it; that is evidence, and a row that already carries a decision or a note is
left exactly as they wrote it.

New profile key: `markedAssessment.taskCommentHeading` (`ASSESSOR COMMENT`).

## v2.3.4 — 3 September 2026

### Page one of a marked copy is the feedback sheet, not a lookalike of it

The feedback page inside a marked copy was a run of indented paragraphs — the
right words, laid out as prose. The standalone sheet a non-submitting student in
the same class receives is a table: banner rows in the accent colour, label
cells on a tint, one row per item across five columns. Two students comparing
their feedback were reading two documents.

Page one is now built from the same tables and the same palette:

- **`Student and Unit Details`**, **`Feedback on your assessment`** and
  **`Questions and Tasks to be Fixed and Resubmitted`** are accent banner rows,
  white on `234B8C`, with white rules so each reads as a solid band.
- Labels sit in tinted cells, two label/value pairs to a row; `RTO` and
  `Assessment` run full width.
- Items are the sheet's five columns — No. / Assessment tool / Question / task /
  Issue identified / What you need to do — and the heading row is marked
  `w:tblHeader`, so it repeats where a student's items run past one page.
- Nothing to correct prints as one plain row, not five empty columns.
- The referral note is italic on the tint rather than red: the result already
  reads in colour twice above it.
- `What happens next` and `Assessor` are a two-row table below the sheet.

**The face is named.** The sheet's document default is Arial 9pt; a student's
own assessment is usually a themed 11pt. Every run now carries an explicit
`rFonts`, or the sheet came out in the student's theme font and read as a
near-miss of itself.

**The sheet is scaled onto the student's own content.** The eight columns keep
the template's proportions, but the total is the width the student's first table
actually draws at, and the indent is that table's own `w:tblInd`.

New in `Lib-Docx.ps1`: `New-SheetTable`, `Add-SheetRow`, `New-SheetParagraph`,
`Get-ScaledGrid`. `Get-BodyContentBox` takes `-After` to measure the first table
below a node.

New in the RTO profiles: `styling.feedbackSheetFill` and
`styling.feedbackSheetRule`. A profile without them gets the house values, so an
older profile still builds.

`MarkedCopyFrontBlockAligned` now checks the block's **tables** as well as its
paragraphs, and measures the student's content **below** the page break — above
it the first table is the sheet itself, and measuring that only asked whether
the sheet agreed with itself.

## v2.3.3 — 2 September 2026

### The result is colour coded on the feedback sheet

`Overall result` on the standalone sheet now prints in the same three colours the
marked copy uses — green Competent, red Not Yet Competent, amber withheld — from
the same profile values, so the three documents cannot drift apart. The letters
still carry the meaning on their own, so a greyscale print loses nothing; the
colour is what makes the result findable at a glance.

`FeedbackSheetIssued` reads the colour off the delivered file and fails where it
is wrong or where no cell carries the result on its own.

### The feedback sheet is named like the SAR

```
SAR_BSBESB401_Jordan RILEY_ADL3000901_NYC.docx
FEEDBACK_BSBESB401_Jordan RILEY_ADL3000901_NYC.docx
```

The SAR's four fields behind its own prefix. It was
`FEEDBACK_<ID>_<UNIT>_<date>`, which sorted a folder by student ID and put the
result nowhere. `MarkedCopyName` now checks feedback names too — unit code,
student ID and a result of C, NYC or RW.

## v2.3.2 — 2 September 2026

### The SAR and the marking record take the same palette

All nine templates now print as one set. Each brand's SAR and Assessment Marking
and Results Record were recoloured **role by role** — accent to accent, rule to
rule — to the palette the feedback sheet already carries:

| Role | ACI Culinary was | ACI Construction was | Now |
|---|---|---|---|
| Accent | `2A364E` | `2F3640` | `234B8C` |
| Fill, rows | `F4F6F8` | `F2F4F6` | `F0F2F7` |
| Fill, alternate | `FAFBFC` | `FAFBFC` | `F7F9FC` |
| Rules | `CCCCCC` | `BFC5CB` | `C3CBDA` |
| Unfilled field text | `9AA3B2` | `8A939C` | `8E96A3` |
| Muted text | `7A8699` | `5A646E` | `606060` |

MVC's two were already on it and were not touched. Colour counts now match
MVC's file for file, which is the check that the mapping was by role and not by
eye.

**Only `word/document.xml` was rewritten**, in each brand's own file, and every
other part was hashed against the original afterwards — the header, the footer,
the logo and the document number are the brand's and are not ours to restyle.
Replacement is scoped to the three places a colour is written (`w:fill`,
`<w:color w:val>`, `w:color`), so a `w:val` that happens to read the same six
characters cannot be caught by it.

**This also closed a hole I had opened.** v2.3 set `styling.placeholderColor` to
`8E96A3` for all three profiles while the SAR and marking record still used the
old per-brand greys. `NoPlaceholderStyling` looks for that exact value, so an
unfilled field on a SAR would have gone out unseen. The templates and the
profiles now agree.

## v2.3.1 — 2 September 2026

### The layout travels; the branding does not

Putting the three brands on one layout was done by copying the MVC file — which
carried **Meridian's logo into the header and `MVC-CMS RTO # 45039 CRICOS #
03551M` into the footer** of both ACI templates. The body read Adelaide
Construction Institute and the page read Meridian Vocational College. Bush Tukka
cannot issue a record under another provider's logo, footer or document number.

Rebuilt the right way round: each brand keeps **its own file** — header, footer,
logo, document number, relationships and media untouched — and only
`word/document.xml` is replaced with the new layout. The two share a lineage, so
the layout body names no styles, no numbering and no inline images, and its
`sectPr` binds to the same `rId7`–`rId12` each brand's own headers and footers
already use. Every part except the body was hashed against the brand's original
afterwards, and each file was searched for the other provider's name.

### `NoForeignRtoIdentity`, the check that would have caught it

Nothing in the gate read a header or a footer, so a logo swap was invisible to
all 33 checks. The new check reads **every part** of every record — headers and
footers included — and looks for any other registered RTO's trading name, legal
name, RTO code or CRICOS code. ACI's two brands share one registration, so a
value this RTO also holds is not foreign; only what genuinely differs is.

Marked copies are exempt: they are the student's own document, and ACI's own
cover sheet names both of its trading names.

A hit in `docProps` is a **WARN**, not a failure. That is Word's own metadata —
the Company field, the custom properties — and the RTO's supplied templates carry
the sibling brand there because one was saved from the other. It is worth
reporting and not worth blocking a class of marking over.

## v2.3 — 2 September 2026

### One feedback sheet layout and one palette across the three brands

The RTO supplied `MVC_Student_Feedback_Sheet_Template` and instructed that its
format and colour palette carry across all three brands. All three feedback
templates are now that document, and differ **only in the RTO row**:

| | |
|---|---|
| Accent — section headers | `234B8C` |
| Row fills | `F0F2F7` / `F7F9FC` |
| Rules | `C3CBDA` |
| Unfilled field text | `8E96A3` |

What changed with them:

- **The two ACI templates were rebuilt from the MVC file**, each carrying its own
  identity line, and each read back afterwards to prove it names its own brand
  and no other. A Meridian-headed sheet carrying an ACI student's feedback is a
  wrong record whatever it says underneath.
- **The measured maps were replaced.** Both ACI variants used to give the item
  rows a table of their own (`itemTable.table: "items"`, three tables); this
  layout keeps them inside the details table at row 9 (`"details"`, two tables).
  A map left on the old value reads a table that is no longer there.
- **`styling.placeholderColor` is `8E96A3` for all three**, which is what the
  gate's `NoPlaceholderStyling` looks for. Left on the old per-brand greys it
  would have stopped detecting unfilled fields.
- **Page one of the marked copy took the same accent**, through
  `markedAssessment.headingColor`, so a class receiving some marked copies and
  some standalone sheets sees one document in one palette.

## v2.2 — 2 September 2026

Five rules from the RTO, after the first BSBESB401 run went out.

### The standalone Student Feedback Sheet is back, for students with nothing to return

Retiring it in v2 moved the feedback onto page one of the marked assessment —
which works only for a student who HAS a marked assessment. A non-submitter has
none, so their feedback existed on the SAR alone, and the SAR is an internal
record the student never sees. The sheet is built again for **every student with
no marked copy**, which is exactly the set the resolver can name: nothing
submitted, or the wrong assessment submitted. `needsFeedbackSheet` is now derived
from whether a marked copy exists, not from the overall result.

### Page one follows the RTO's feedback sheet format

The details block, the items to fix, what happens next, the assessor's name and
date, under that RTO's own headings — read from `markedAssessment.feedbackPage`
in the profile rather than from strings in the builder. A class that receives
some marked copies and some standalone sheets now reads one document, not two.

### The wrong assessment is not a non-submission

`wrongAssessment` + `submittedInstead` on a result: NYS, an item naming what
arrived and what to send instead, and the class comment `Incorrect assessment
submitted`. A student who submits another unit's work is told so — filing it as
`No submission` tells them nothing about the file they know they sent.

### Pending enrolments are not marked

A student whose WiseNet status reads *Pending* has an enrolment that has not
started. The importer lists them under **PENDING ENROLMENT** and keeps them off
REQUIRED TO SUBMIT; the resolver refuses a ledger that carries one.

### The cover sheet comes back filled

`coverSheet` in the ledger maps each label on the assessment's own cover sheet to
its value, with fields for the student, unit, qualification, assessor and dates,
and an assessment-type box driven by the attempt. Cells the student filled are
left alone. After the named fields are written, **every** label on the sheet is
checked for a value — including labels the map never named — and the new
`CoverSheetFilled` gate check reads the delivered file again.

Two smaller things fell out of it: `Get-ParagraphTable` moved to `Lib-Docx.ps1`
so the gate can use it, and the stacking check accepts an earlier attempt's page
under the title this skill used when that attempt was marked. That file is the
audit trail of the attempt and is not ours to rewrite.

## v2.1 — 2 September 2026

Found while marking BSBESB401 for ACI Construction, whose observation checklist
is a shape the skill could not fill.

### Column-style observation sheets

A sheet whose boxes carry their own word — `☐ Yes` — was the only shape the
builder could read. ACI's construction checklist heads two **columns** `Yes` and
`No` and leaves a bare `☐` in each cell, so the labelled reader found nothing to
tick and said nothing: twenty-eight empty boxes under a signed record.

`observationSheet.layout: "columns"` reads the sheet row by row off its tables.
The Yes and No columns are found by their heading text, never by position; a
criterion row is one whose Yes and No cells hold a lone box; the row count is
checked against `outcomes` before anything is ticked. `comments` then writes one
note into each row's comments cell — the sheet's own comments area — held to a
new **row-note standard** (`Test-ObservationRowNoteStyle`): 1–2 sentences, 25
words, the two-comma rule, third person, no assessor filler. Until now
`observationSheet.comments` was demanded by the resolver and written by nobody.

Also: `sufficientLabels`, for an overall box reading something other than Yes and
No (`Competent / Not Yet Competent`), and `fields` that writes onto a printed
rule — `Assessor Signature: ______` — where the label is not in a table.

The gate reads all of it back off the delivered file, row by row, independently.

### The record-in-the-sheet check now tests range, not tables

`MarkedCopyObservationSheet` required the record to sit inside a table, because
every sheet seen until now was one. A column sheet's instructions and notes line
are body text above its section tables, so a record written exactly where the
sheet asks for it read as *loose in the body*. The check now requires the record
to lie between the sheet's own anchors, which is what the rule was always about.

### `anchorAfter`, for a heading printed twice

An assessment that lists its tasks and then prints each task heading again has
two identical paragraphs, and no anchor text can separate them. `anchorAfter`
names something unique that sits before the copy that is meant; the anchor must
still match once inside what is left. It narrows the search and never picks a
match on its own.

### A one-line bug that read as a one-row sheet

`,@($out)` at the end of the row reader, wrapped in `@()` by its caller, turned
28 rows into a single element holding an array — reported as *the sheet has 1
criterion row*. The comma idiom protects a one-item list from unrolling and
quietly breaks every longer one.

## v2 — 2 September 2026

All ten briefed changes are in. The skill builds 16 documents from the worked
example and passes the gate at **30 checks**.

### 1. The unit's prerequisites are read from training.gov.au

New `scripts/Get-UnitPrerequisites.ps1`, `references/prerequisite-lookup.md` and
`assets/prerequisites.cache.json`; new Stage 1b in the workflow.
`unit.prerequisite` (free text, accepted `"N/A"`) is replaced by
`unit.prerequisites` + `prerequisitesConfirmedNone` + `prerequisiteSource` +
`prerequisiteCheckedOn`. The old field is accepted for one release with a
deprecation CHECK, then rejected.

The lookup uses the JSON API behind the page, not the page: a plain GET of
`/training/details/<CODE>/unitdetails` returns 200 and an empty Nuxt shell in
which *prerequisite* appears zero times. `Nil` means Nil; every other outcome is
`unknown`, and `unknown` stops the run.

> **The shipped example ledger was wrong.** It read `"prerequisite": "N/A"` for
> SITHPAT016, which has a prerequisite — SITXFSA005. The first lookup found it.

### 2. Each student's prerequisite is confirmed from WiseNet 0217

`Import-WisenetMatrix.ps1 -Prerequisite <code[,code…]>`, a fifth report list
**PREREQUISITE NOT COMPLETED** with the *no column on this report* case listed
separately, and the `confirmedExternally` override with required evidence. There
is no `unknown` on this axis, deliberately — the opposite of change 1.

### 3. RW, a third overall result

Applied after the S/NYS → C/NYC derivation and overriding it. Exact comment
string held once in `Lib-Text.ps1`. Invoice and re-enrol never ticked.
Resubmission Due is five working days from the marking date for every withheld
result - confirmed by the RTO. Amber `B45F06` in the `styling` block of all three profiles — no colour is
hard-coded. WiseNet outcome code **70** published on the student.

### 4. The feedback page replaces the Student Feedback Sheet

**A document type is retired.** Every student — C, NYC and RW alike — now gets
their feedback as **page one of their marked assessment**: overall result top
right and colour-coded, declaration block, per-tool feedback, the items to
correct as *Issue identified* / *What you need to do*, the ten-item cap and its
closing note, then a page break before their own work.

`FeedbackSheetPerNyc` → **`FeedbackPageEveryStudent`**. `FeedbackSheetOnePage`
retired: page one may run past one physical page, and the page break is what
matters. `MarkedCopyDeclarationPage` → **`MarkedCopyFeedbackPage`**.
`CrossDocumentAgreement` lost its feedback-sheet leg and gained a page-one leg.

The measured feedback-template maps are **kept, marked `"retired": true`** — they
were measured against supplied templates and re-measuring is not free. The three
feedback `.docx` templates stay in `assets/templates/`, unused.

`notSatisfactoryText` and `referralText` in all three profiles no longer point a
student at a document that no longer exists.

### 5. The withheld-result notice

Approved RTO wording held once in `Lib-Text.ps1`, filled from the ledger and the
profile, printed on page one for an RW student. New
`rto.studentAdminContact { name, email, phone }` in all three profiles, required
by the builder. New gate check **`RwNoticePresent`**.

**The two-comma rule does not apply to the notice** — `Test-NoticeExempt` matches
it against the notice's own skeleton, so nobody "fixes" approved wording to
satisfy a style check.

> Contacts confirmed by the RTO: MVC `info@mvc.edu.au` / `08 7080 5055`; ACI
> Culinary and ACI Construction share `info@culinaryadelaide.sa.edu.au` /
> `08 7001 6145`.

### 6. One student, no Assessment Marking and Results Record

The resolver publishes `buildMarkingRecord: false`, the builder skips it and says
so, and the gate swaps `MarkingRecordName` for
**`SingleStudentNoMarkingRecord`**.

### 7. Resubmissions stack

At attempt 2 the builder opens the file already marked at attempt 1 —
`priorMarkedCopy`, required by the resolver — so that attempt's feedback page and
outcome lines travel forward untouched and the new page goes on top. Each page is
headed `ASSESSMENT FEEDBACK — Attempt N · DD / MM / YYYY`. New gate check
**`ResubmissionStacked`**.

New outcome lines are prefixed `Attempt N:` so the two attempts can be told
apart, by the student and by the gate, which counts only the current attempt's.

### 8. The observation sheet is always completed and always satisfactory

`outcomes` no longer accepts `"No"`; `sufficient` must be `true`;
`observationSheet.comments` is required. The comment standard moved to the RTO's
revised limits — **2 paragraphs, 20 words** — held once in `Lib-Text.ps1` and used
by both the resolver and `Test-ObservationComments.ps1`.

> **Why the sheet reads Yes**, confirmed by the RTO: the practical is conducted
> BEFORE marking, always overseen by a trainer, with oral feedback given at the
> time. The sheet is then ticked Yes for all submitted work, so a Yes records an
> observation that happened and was watched. The printed sheet keeps both
> columns. A practical shortfall goes in the tool result, the SAR feedback and
> the feedback items - see SKILL.md, *The practical observation, and why the
> sheet reads Yes*.

### 9. New filenames

`<UNITCODE>_<Student Name>_<StudentID>_<RESULT>.docx`, and the same four fields
behind `SAR_`. New **`MarkedCopyName`** and **`NoDuplicateOutputName`**. The gate
no longer identifies marked copies by a filename prefix — it reads the resolver's
`markedCopies` list.

> **Deviation, flagged.** The convention names a student once, but this skill
> produces one marked copy per submitted *file*. Where a student has more than
> one, the tool group is appended. A single submission gets the four-field name
> exactly as briefed.

### 10. The rest brought into line

`SKILL.md` frontmatter `description` rewritten for three documents, the feedback
page, three result states and the prerequisite check. `feedback-writing.md` is
two places, not three. `audit-checklist.md` carries a mutation per new check.
`Test-Install.ps1` covers the new assets and the training.gov.au path including
its offline behaviour. `examples/ledger.example.json` gained an RW student, a
`priorMarkedCopy`, observation comments and all-Yes sheets.

### Gate checks

**Added:** `MarkedCopyName`, `NoDuplicateOutputName`,
`SingleStudentNoMarkingRecord`, `WithheldComment`, `FeedbackPageEveryStudent`,
`RwNoticePresent`, `ResubmissionStacked`.
**Renamed:** `MarkedCopyDeclarationPage` → `MarkedCopyFeedbackPage`;
`FeedbackSheetPerNyc` → `FeedbackPageEveryStudent`.
**Retired:** `FeedbackSheetOnePage`.
**Widened:** `OverallResultRule` and `MarkedCopyOutcomes` for RW and for stacked
attempts; `MarkingRecordName` and `CrossDocumentAgreement` made conditional.

Eight mutations were run against the new checks and all eight failed the gate.

### Settled by the RTO, 2 September 2026

- **Student administration contacts.** MVC `info@mvc.edu.au`, `08 7080 5055`.
  ACI Culinary and ACI Construction share one inbox and one number,
  `info@culinaryadelaide.sa.edu.au`, `08 7001 6145` - one legal entity, one
  student administration. The notice joins only the parts that exist, so an RTO
  registered later without a phone number does not get a dangling comma.
- **The amber** `B45F06` is confirmed.
- **The RW resubmission date** is five working days from the marking date,
  ALWAYS - not N/A for an all-satisfactory RW student. It is the date the
  prerequisite question falls due.
- **Per-question outcomes on a resubmission** stay one line per attempt, the
  newer prefixed `Attempt N:`.
