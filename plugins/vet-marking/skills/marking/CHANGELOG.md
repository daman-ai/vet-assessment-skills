# Changelog

## v2.8.0 — 9 September 2026

The 7 and 8 September fixes from the CPCCCM2008, CPCCSP2002 and CPCCSP2003
marking runs, merged onto v2.7.0. That work was done on the machine against the
pre-v2.6.0 line, so this is a merge in both directions: its fixes came across,
and nothing v2.7.0 carried was taken back out.

### S / NS checklist grids

A third observation-sheet shape: criteria down the rows, bare boxes under **S**
and **NS** headings, no `Yes`/`No` words anywhere. `snsChecklists` takes one
entry per grid in document order, each with its own `outcomes`, and where the
instrument provides them an `outcome`, a `comments` box, a per-row `notes`
column and a `decision` answering the task decision line printed after the grid.
A count that does not match the grids found is a hard failure.

Three spellings of the pair are in circulation — `S`/`NS`, `S`/`NYS` and
`Satisfactory`/`Not yet` — and the not-satisfactory heading is matched first, or
`Not yet` is claimed by the satisfactory pattern and both columns address one
cell. Two characters are used for an empty box, WHITE SQUARE and BALLOT BOX.

### The learner is not called he or she

`Test-LearnerPronouns` refuses a gendered pronoun in assessor prose — observation
records, criterion comments, checklist comments and notes. Feedback written *to*
the student is second person and is not checked.

### Three silent writers

- **A paragraph's own mark carries a colour, and it is read before the run's.**
  `w:pPr/w:rPr/w:color` tints only the pilcrow, so it changes nothing a reader
  sees, but it is the first `w:color` in the paragraph. Three green Satisfactory
  lines were reported as black. `Set-CellText` and `Add-CellLine` now clear it.
- **A submission with no table at all** — one arrived as fifty-three page images
  and nothing else — now reports its content box on the text margin rather than
  returning `$null`, so the front block and the feedback sheet are sized to the
  same box the gate measures.
- **`Test-AiFlag` unrolled a single-object JSON file into nothing.** It now
  appends element by element.
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
