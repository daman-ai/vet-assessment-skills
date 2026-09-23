# The marked copy of the assessment

The student gets their own submission back, marked. It is the fourth document
type, and the only one the student reads question by question.

```
MARKED_<StudentID>_<UnitCode>_<toolIds>_<DDMMYYYY>.docx
```

## One marked copy per submitted FILE

Assessments are routinely supplied as one document covering several tools — UAT
1 and UAT 2 bound together, a knowledge tool and a practical workbook in one
workbook. **They are marked together, into that one copy.**

Marking them tool by tool would produce two marked copies of the same document,
each carrying half the outcomes and a declaration naming only its own half. The
student would receive the same file twice, marked twice, and neither copy would
be the marked assessment.

`Resolve-MarkingLedger.ps1` groups each student's results by the `evidence` path
they were read from and publishes the groups as **`markedCopies`**:

```jsonc
"markedCopies": [
  { "file": "MARKED_TEST001_BSBFIX001_uat1-uat2_01092026.docx",
    "studentId": "TEST001", "evidence": "ev/TEST001_UAT.docx",
    "toolIds":   ["uat1", "uat2"],
    "toolNames": ["UAT 1 - Knowledge Questions", "UAT 2 - Practical Demonstration"] }
]
```

The builder marks one group at a time; the gate checks the same list. Neither
re-derives it, because a gate that decides for itself which files should exist is
checking a different build from the one that ran.

Two results share a copy when their `evidence` strings name the same file. The
comparison is case-insensitive and separator-insensitive, so `ev/Foo.docx` and
`ev\foo.docx` are one file, not two.

## The declaration page

**The result goes on a page of its own, in front of the student's first page.**

The cover sheet is the student's document: their name, their signature, their
declaration that the work is their own. Crowding a result onto it competes with
their own heading and leaves neither room to be read. A separate first page gives
the declaration space and returns page one exactly as they submitted it.

**And it IS the RTO's own Student Feedback Sheet** — the same tables, the same
palette — so a class where some students get a marked copy and some get the
standalone sheet is reading one document rather than two. The headings, labels
and standing lines come from `markedAssessment.feedbackPage` in the RTO profile,
which carries that RTO's wording:

```
                                      Overall result: Not Yet Competent   ← TOP RIGHT
              Student Feedback Sheet — Attempt 1  ·  02 / 09 / 2026       ← CENTRED

┌────────────────────────────────────────────────────────────────────────────┐
│                          Student and Unit Details                          │  ← accent banner
├──────────────────┬─────────────────────────────────────────────────────────┤
│ RTO              │ Golden Wattle Group Pty Ltd T/A Meridian … · RTO 45039  │
├──────────────────┼──────────────────────┬────────────────┬─────────────────┤
│ Student name     │ Daniel Okafor        │ Student ID     │ MVC00318        │
│ Unit assessed    │ SITHPAT016 Produce…  │ Qualification  │ SIT30821 Cert…  │
├──────────────────┼──────────────────────┴────────────────┴─────────────────┤
│ Assessment       │ Knowledge Questions  ·  Recipe Workbook                 │
├──────────────────┼──────────────────────┬────────────────┬─────────────────┤
│ Trainer/Assessor │ Priya Raman          │ Date of marking│ 02 / 09 / 2026  │
│ Overall result   │ Not Yet Competent…   │ Resubmission…  │ 09 / 09 / 2026  │
├──────────────────┴──────────────────────┴────────────────┴─────────────────┤
│ See the feedback on this page for the items to correct …        ← italic    │
├────────────────────────────────────────────────────────────────────────────┤
│                        Feedback on your assessment                         │  ← accent banner
├──────────────────┬─────────────────────────────────────────────────────────┤
│ <tool>           │ <the same words the SAR carries for that tool>           │
├──────────────────┴─────────────────────────────────────────────────────────┤
│               Questions and Tasks to be Fixed and Resubmitted              │  ← accent banner
├────┬─────────────┬──────────────┬──────────────────┬───────────────────────┤
│ No.│ Assessment  │ Question /   │ Issue identified │ What you need to do   │  ← repeats per page
│    │ tool        │ task         │                  │                       │
├────┼─────────────┼──────────────┼──────────────────┼───────────────────────┤
│ 1  │ Recipe Work…│ Recipe card 2│ …                │ …                     │
└────┴─────────────┴──────────────┴──────────────────┴───────────────────────┘

┌──────────────────┬─────────────────────────────────────────────────────────┐
│ What happens next│ Correct only the items listed above. …                   │
│ Assessor         │ Name: Priya Raman          Date: 02 / 09 / 2026          │
└──────────────────┴─────────────────────────────────────────────────────────┘
                          ─── page break ───
```

**Why a table and not indented paragraphs.** The standalone sheet is a table.
Built here as a run of paragraphs the page carried the right words in the wrong
document — a near-miss of the sheet rather than the sheet — which is exactly the
second layout the declaration page exists to avoid. Same tables, same palette,
one document to learn.

The palette comes from the profile: `styling.feedbackAccentColor` for the banner
rows, `styling.feedbackSheetFill` for label cells, `styling.feedbackSheetRule`
for the hairline rules. A banner cell takes **white** rules rather than grey,
which is what makes it read as a solid band instead of a boxed cell. **The face
is named explicitly (Arial).** The standalone sheet's document default is Arial
9pt and a student's own assessment is usually a themed 11pt; runs dropped in
without an `rFonts` come out in the student's theme, and the sheet reads as a
near-miss of itself.

**The sheet is scaled onto the student's own content width.** Its eight columns
keep the template's proportions, but the total is the width the student's first
table actually draws at and the indent is that table's own `w:tblInd` — often
not the text margin at all. A sheet on the margin sits visibly out of line with
every page beneath it.

The **overall result is right-aligned above the sheet**, so it is the first thing
a student sees on opening the file. Green `1E7B34` for Competent, red `C00000`
for Not Yet Competent. `Assessment` names every tool the file covers.
`Resubmission due` reads `N/A` where the student is Competent — a blank says
nothing, `N/A` says the question was asked and answered. A Competent student's
items section reads *There is nothing to correct* as one plain row rather than
five empty columns, and the resubmission line of *What happens next* is dropped,
because neither applies to them. The item table's heading row is marked
`w:tblHeader`, so a student reading page two of their own feedback does not have
to page back to learn which column is the issue and which is the fix.

`MarkedCopyDeclarationPage` checks the delivered file for the page break, for the
result above it, and for the student's own content below it.
`MarkedCopyFrontBlockAligned` checks that every paragraph AND every table in the
block sits on the edges of the student's own first table — measured **below** the
page break, because above it the first table is now the sheet itself and
measuring that would only ask whether the sheet agrees with itself.

## The cover sheet comes back filled

The assessment's own cover sheet sits below the page break, at the front of the
student's document, and half its fields are the RTO's to complete. The ledger's
`coverSheet` maps each label to a value:

```jsonc
"coverSheet": {
  "anchor":    "RTO- Bush Tukka",           // text that appears ONCE at the sheet
  "endAnchor": "Assessment Overview",
  "fields": [
    { "label": "Student ACI ID:",     "value": "{{studentId}}" },
    { "label": "Due Date:",           "value": "{{dueDate}}" },
    { "label": "Trainer / Assessor:", "value": "{{assessor}}" }
  ],
  "boxes": [ { "label": "First submission", "whenAttempt": 1 } ]
}
```

- The value goes in the **cell beside the label**, or — where the label is the
  last cell in its row, as ACI's `Due Date:` is — after the label in that cell.
- **A cell the student already filled is left alone.** Their words are not ours
  to restate, and `Ramandeep Singh` does not need correcting to `Ramandeep
  SINGH`.
- A box is ticked by `whenAttempt` (the attempt this copy is) or by `ticked`. The
  cover sheet's boxes are not always the ballot box the rest of the marking uses:
  ACI prints `□` U+25A1, and each glyph in circulation is tried before the build
  fails rather than ticking nothing.
- **Then every label on the sheet is checked for a value**, including labels the
  map never named, and one without a value stops the build. The gate's
  `CoverSheetFilled` reads the delivered file and checks it again.

## The outcome line goes IN the answer

Under each question's response, one line:

| Outcome | Line | Colour |
|---|---|---|
| Satisfactory | `Satisfactory` | green `1E7B34` |
| Not yet satisfactory | `Not yet Satisfactory - refer to feedback sheet` | red `C00000` |

**Every question carries one.** A question left out of the ledger's `questions`
array is a question the student gets back with no remark on it, which reads as an
oversight rather than a judgement.

**And it lands inside the response box, under the student's own words** — not on
the empty paragraph below the answer table. That failure is quiet and specific:
every word right, every colour right, and the student's eye goes to the box and
finds nothing in it.

### Tasks get an outcome too, in the box the instrument provides

A tool made of **tasks** rather than questions — three practical activities in a
unit project — is judged task by task. Without it a student saw thirty-two
coloured judgements on their knowledge test and none at all on the three
activities they actually performed, with one tool-level line at the foot of the
observation sheet standing for all three.

**It goes in the instrument's own boxes, not in paragraphs after them.** These
templates already carry an assessor's column beside every criterion and, at the
foot of an activity, a cell headed `Assessor / Supervisor comments`. A judgement
written as loose paragraphs after the table reads as an annotation someone
added; written into those boxes it reads as the instrument being completed.

- **every criterion row** takes its own coloured outcome, in that row's comments
  cell under the note already there;
- **the task's comment** goes in the labelled cell — `tasks[].commentCellLabel`
  names it — followed by that task's coloured outcome;
- only where the template provides **neither** does the ledger's `anchor` place
  an `ASSESSOR COMMENT — <task>` block in the body. That is the fallback now,
  not the rule.

`results[].checklistRowsMarked` records how many criterion rows were judged; the
count varies with the instrument, so it cannot be assumed.
`TaskOutcomeColoured` finds each task's comment and checks that its outcome
follows in the colour of that outcome.

**Read a colour from the run, never from the paragraph.** `.//w:rPr/w:color`
matches a paragraph mark's `w:pPr/w:rPr/w:color` first, and an outcome added
inside a table cell was read as its pilcrow's colour and went uncounted. The
checks read `.//w:r/w:rPr/w:color`.

**A tick is not always text.** Students in this cohort confirm a box with a
Webdings symbol — `<w:sym w:font="Webdings" w:char="F061"/>` — which carries no
`w:t`. A text-only test reads that row as unticked and adds a second mark beside
the first, so anything that ticks a box looks for a `w:sym` too.

**A comments column is often one vertically merged cell**, not one per row. A
note written into each row lands in merge continuations, which Word does not
draw — the page shows one comment and eleven blanks. Write to the `w:vMerge`
master.

### The pre-start verification checklist

The small assessor table inside an activity — *Assessor / supervisor to confirm
before commencement* — is filled from `observationSheet.verification`. Nine
untouched boxes and nine empty comment cells on a sheet the assessor has signed
reads, to an auditor, as a check nobody carried out.

**Only blank halves are filled.** Some students complete this checklist on site
before the assessor sees it, in their own words. That is evidence: a row already
carrying a decision or a note is left exactly as they wrote it, and only the
empty half is completed.

### How the end of a response block is found

Each question names an **anchor**: the text identifying it in the submission. The
outcome goes after the last paragraph of that question's response, which is found
by walking back from the paragraph before the *next* question's anchor, skipping
three kinds of thing:

1. **Floating text boxes.** A line written into one prints inside the shape, not
   under the answer. It also makes the line count wrong — Word reports the
   containing body paragraph as carrying the box's text too, so one inserted line
   reads as two and the gate refuses the build.
2. **Empty spacer paragraphs.** These sit between an answer table and the next
   question in every workbook-style assessment. Landing on one puts the judgement
   below the box instead of inside it.
3. **A short run of the next question's own table** — its "Complete the table
   below" line and its column headings. Those sit above the *next* answer, so a
   line left among them reads as a verdict on the wrong question.

**Rule 3 is bounded at eight paragraphs, and the bound is the whole point.**
Where a question's stem, the student's answer and the next question's stem all
share one table, skipping "everything in that table" walks straight back over the
answer being marked. A heading block is a few paragraphs; an answer is many. Past
the bound the skip is abandoned and the position found by rules 1 and 2 is used,
which is the end of the student's answer.

```jsonc
"questions": [
  { "ref": "Q1", "anchor": "Q1.", "outcome": "S"   },
  { "ref": "Q3", "anchor": "Q3.", "outcome": "NYS" }
],
"questionsEndAnchor": "End of assessment"
```

**Anchor on the FIRST paragraph of each question's block**, not on a stem line
buried inside it. The line for question N is placed relative to the anchor of
question N+1, so an anchor set too late leaves the previous question's judgement
stranded among the next question's headings.

### `anchorAfter` — when the heading is printed twice

An assessment routinely prints its task headings twice: once in the list of what
the student will do, and again over the task itself. Both paragraphs read the
same, word for word, so **no anchor text can tell them apart** and the build
refuses the ambiguity rather than taking the first.

`anchorAfter` names something that appears **once** and sits before the copy that
is meant — the scenario, the previous task's template:

```jsonc
{ "ref": "Activity 2",
  "anchor":      "Activity 2: Draft a business plan",
  "anchorAfter": "Template 1: Report on elements of a business plan",
  "outcome": "S" }
```

It narrows the search and nothing else. The anchor must still match exactly once
in what is left, so this disambiguates without ever choosing a match on its own.
`anchorAfter` itself must be unique, or the build says so and stops.

### `questionsEndAnchor` — where the last answer stops

Every question but the last is bounded by the next question's anchor. The last
one has no next anchor, so without help its outcome lands after whatever trails
the assessment: *End of assessment*, a declaration block, a signature table.

`questionsEndAnchor` names the first paragraph that is **not** part of the last
answer. Omit it and the build says so:

> CHECK  Daniel Okafor / Knowledge Questions: no questionsEndAnchor, so 'Q5' was
> marked at the end of the document. Check where its outcome landed.

A misplaced last outcome looks exactly like a correct one, which is why it gets a
warning rather than silence.

### Why the red line does not say what was wrong

It points at the feedback sheet instead. The fault is then described in exactly
one place, and the marked copy cannot drift out of step with the sheet the
student actually works from. It also keeps the marked copy readable: a red line
under each answer, not a paragraph.

### Colour is not the only signal

Green and red are both dark enough to print legibly in greyscale, where they read
as two clearly different tones. More importantly the **words** carry the meaning
— a reader who cannot distinguish the colours, or who prints in mono, loses
nothing.

## The observation record goes IN the observation sheet

An observation or practical tool does not decompose into numbered questions. What
it has instead is an **observation sheet inside the submission**: the observable
tasks, a Yes/No box for each, a notes column, a feedback line, a sufficiency box
and the assessor's signature.

**That sheet is the instrument.** An auditor asking whether the observation
happened opens it, and a blank sheet with a tidy summary stapled to the front of
the file answers them the wrong way round. So the record is written into the
sheet:

```jsonc
"observations": [
  "Observed the work area set up safely before starting.",
  "Observed the documented procedure followed throughout.",
  "The work area was left uncleaned at the end of the task."
],
"observationSheet": {
  "anchor":           "Observation Checklist 1: Practical demonstration",
  "endAnchor":        "Observation Checklist 2",     // optional; bounds this sheet
  "notesAnchor":      "Observation notes",           // the record is written under this
  "outcomes":         ["Yes", "Yes", "No"],          // one per Yes/No pair, in sheet order
  "sufficientAnchor": "Sufficient",
  "sufficient":       false,
  "feedbackAnchor":   "Feedback to Student",
  "feedback":         "You set up safely and followed the procedure throughout. …",
  "fields": [
    { "label": "Date",        "value": "01 / 09 / 2026" },
    { "label": "Start time",  "value": "10:00 am" },
    { "label": "Finish time", "value": "10:35 am" }
  ]
}
```

Everything is **addressed by text the ledger names**, never by position in a
table. Observation sheets differ between assessments, and a cell addressed by
number fills the wrong box the moment one is re-laid-out. `fields` writes each
value into the cell beside its label.

The one thing counted rather than named is the run of **Yes/No pairs**, and the
count is checked before a single box is ticked:

> the sheet has 13 observable task(s) but the ledger gives 12 outcome(s). Give
> one Yes or No per task, in sheet order. Nothing was ticked.

The boxes must read Yes then No, in order, or the pairing is refused. `endAnchor`
and `sufficientAnchor` bound the search, so a submission carrying two sheets
cannot have one sheet's labels matched against the other's.

### Two sheet shapes: labelled boxes, and Yes/No columns

The sheet above is **labelled**: each box carries its own word, `☐ Yes`, so the
decision reads off the box. ACI's construction checklists are not. They head two
columns `Yes` and `No` and leave a bare `☐` in every cell beneath, so a box
paragraph carries no label at all and the labelled reader finds nothing to tick —
silently, which is the failure that looks most like success: every box on a
signed sheet still empty.

The ledger says which shape it is. `"layout": "columns"` reads the sheet row by
row off its tables instead:

```jsonc
"observationSheet": {
  "layout":           "columns",
  "anchor":           "INSTRUCTIONS FOR ASSESSOR",
  "notesAnchor":      "Tick YES if demonstrated satisfactorily",
  "outcomes":         ["Yes", "Yes", "Yes", "…"],   // one per criterion row, in sheet order
  "comments":         ["Stated the plan guides decisions in the Activity 1 report.", "…"],
  "sufficientAnchor": "OVERALL PERFORMANCE RESULT",
  "sufficientLabels": ["Competent", "Not Yet Competent"],
  "sufficient":       true,
  "fields": [
    { "label": "Assessor Signature", "value": "Simran Singh" },
    { "label": "Date",               "value": "02 / 09 / 2026" }
  ]
}
```

- **Which column means Yes is read from the heading row, never from position.** A
  sheet that gains a column, or prints No before Yes, must not shift the ticks
  one to the left. The first column is the criterion whatever it is headed — ACI
  heads four sections `Criteria` and the fifth `Skill`.
- A **criterion row** is a row after a heading row whose Yes and No cells hold a
  lone box. Section titles, notes and spacer rows are skipped rather than
  counted, and the count is checked against `outcomes` before anything is ticked.
- `comments` are the **comments column** — one note per criterion row, in sheet
  order, held to the row-note standard rather than to the two-paragraph standard
  written for an `Assessor comments` box. See
  [observation-comments.md](observation-comments.md).
- `sufficientLabels` names an overall box that does not read Yes and No, the
  satisfied label first. Without it the sufficiency box is read as a Yes/No pair,
  which is what a labelled sheet carries.
- `fields` writes into the cell beside a label, and where the label is not in a
  table it writes onto the printed rule after it: `Assessor Signature: ______`
  becomes `Assessor Signature: Simran Singh`. Label and rule are matched
  together, because the shorter rule after `Date` is a substring of the longer
  one after `Signature`.

The record itself goes under `notesAnchor` as it always has, and the gate checks
it lies **between the sheet's own anchors** — not that it lies inside a table.
A column sheet's instructions and notes line are body text above its section
tables, so a record written where the sheet asks for it is at body level and in
the sheet, which is what the rule was always about.

### A third shape: both boxes inside one cell

ACI's **older** CPCC packs head a single decision column `S / NS` and print
**both** boxes in that one cell, each with its word beside it: `☐ S ☐ NS`. The
labelled reader looks for a paragraph that is only a box and a word and finds
none; the column reader looks for a second heading to pair with the first and
finds none. Both return no rows, silently, and every criterion on a signed sheet
stays unjudged.

```jsonc
"observationSheet": {
  "layout":         "inlinePairs",
  "decisionHeader": "S / NS",              // the one decision column's heading
  "commentsHeader": "Assessor Comments",
  "yesLabel":       "S",
  "noLabel":        "NS",
  "anchor":         "All six items must be correctly annotated",
  "notesAnchor":    "To be completed by the Assessor only",
  "outcomes":       ["Yes", "Yes", "…"],   // one per criterion row, in sheet order
  "comments":       ["…", "…"]             // one row note per row, same order
}
```

- The decision column is found by `decisionHeader`, never by position, and a
  **criterion row** is one whose decision cell holds exactly the two labelled
  boxes and nothing else. Section titles and the decision-rule row are skipped.
- The count is checked against `outcomes` **before a box is written**, the same
  way a column sheet checks it.
- `comments` are held to the **row-note** standard, not the two-paragraph one —
  see [observation-comments.md](observation-comments.md).

**The anchor must sit ABOVE the table.** On this pack the obvious line, *To be
completed by the Assessor only*, is inside the checklist's own first row, and a
sheet anchored there excludes the very table it names: no rows found, nothing
ticked, no error. Anchor on the last body paragraph before the table and use the
line inside it as `notesAnchor`.

### The S / NS grid, and where its record goes

A third shape has no `Yes` or `No` beside its boxes at all — criteria down the
rows, bare boxes under an `S` and an `NS` heading — and often no comments column
either. `Write-SnsChecklist` handles it from `snsChecklists`, one entry per grid
in document order. The S and NS columns are found **by their headings**, so the
same writer serves a four-column sheet and a five-column one with an
`Assessor Notes` column beside them.

**The record goes in the space the sheet allocates.** For this shape that is the
one-cell table under the `Assessor comments` heading — not the body flow beneath
that heading, which is where it lands if you anchor on the heading and stop
thinking. Where a submission has lost that table, one is **built** by cloning a
table already on that sheet, so the box keeps the learner's own width, borders
and shading rather than being invented.

Boxes that sit in no grid still have to be ticked. One instrument closes each
performance task with a `SATISFACTORY (S)` / `NOT SATISFACTORY (NS)` pair of its
own, outside every grid and every outcome table; four per learner went out empty
under a signed result before the writer learned to reach them.

### When the submission has no sheet

Say so. The resolver **refuses** an observation record with no `observationSheet`
rather than quietly falling back:

```jsonc
"observationSheet": { "inSubmission": false }
```

The record then prints on the declaration page under
`ASSESSOR OBSERVATION RECORD — <tool name>`, with the completion date and the
tool's outcome. The resolver reports the choice as a CHECK, so it stays visible.

Keep each point short and factual — what you saw, not what you concluded. The
two-comma rule applies to them, as it does to all assessor-written prose.

### The sheet's Assessor comments area

`observations` are the terse points that go under `notesAnchor`. A sheet's
**Assessor comments** area is a different thing and has its own standard: 3 to 5
paragraphs, 2 sentences and 30 words each, at least three specifics from that
student's own work, and no phrase shared with any other student in the cohort.

Write those to [observation-comments.md](observation-comments.md) and check them
with `scripts/Test-ObservationComments.ps1` before they reach a ledger.

**The student's own words are never altered, and nothing is deleted.** The
declaration page, the outcome lines and the observation record are the only
additions. This is the student's evidence and part of the audit trail; editing it
would destroy both.

## The build never guesses

An anchor that is **missing**, or that matches **more than one** paragraph, is a
hard failure naming the question. Nothing is written.

> question 'Q3': 'Q3' appears 4 times; give it a unique 'anchor' in the ledger

An outcome stamped under the wrong answer is worse than no marked copy: the
student corrects work that was already satisfactory and leaves the real fault
alone. Where a bare number is ambiguous, anchor on more text — `Q3.` rather than
`Q3`, or the opening words of the question stem.

## What the resolver enforces before anything is built

The marked copy and the SAR are two records of one judgement. They must agree:

- any question marked **NYS** → the tool must be **NYS**;
- every question marked **S** while the tool is **NYS** → you must say which
  question failed;
- every **NYS** question must have a **matching item on the feedback sheet**,
  keyed by the same ref. Otherwise the red line sends the student to a sheet that
  does not mention their question;
- an observation record must say where it goes, in the sheet or on the page.

## What the gate checks on the finished files

| Check | What it reads |
|---|---|
| `MarkedCopyOutcomes` | one green `Satisfactory` per S question and one red line per NYS question, **summed across every tool in the file**, and a declaration matching the SAR |
| `MarkedCopyInAnswerSpace` | every outcome line follows a non-empty paragraph and sits in the same cell as it |
| `MarkedCopyDeclarationPage` | the page break is there, the result is above it, the student's own content is below it |
| `MarkedCopyObservationSheet` | the record is inside the sheet, every Yes/No pair matches the ledger, the sufficiency box matches, each field carries its value |
| `MarkedCopySnsChecklist` | every S/NS grid in the delivered file is re-paired against the ledger: one mark per criterion row in the right column, the comments in the sheet, the sign-off naming the assessor |
| `MarkedCopyFrontBlockAligned` | the declaration sits on the same left and right edge as the content below it |

The tick check re-pairs the boxes from the delivered file rather than trusting
the build. That is not ceremony: `Set-LabelledBox` handed a paragraph silently
ticked nothing for as long as that path existed, and a sheet whose every box is
still empty under a signed record is the failure that looks most like success.

## When no marked copy is produced

- **Nothing was submitted.** There is no document to mark. The build says so and
  moves on; this is the normal non-submission path.
- **The ledger has no per-question outcomes and no observation record** for that
  tool. A tool judged on evidence that is not a Word document — a slide deck, a
  video — has nothing to stamp. The build reports the tool as skipped.
- **No `evidence` path is named.** The resolver reports it and produces no copy,
  rather than the build failing later at the point of opening a file that was
  never identified.

All three are reported, never silent.

## Related

- [ledger.md](ledger.md) — the `questions`, `observations` and `observationSheet` arrays
- [feedback-writing.md](feedback-writing.md) — what the sheet says instead
- [audit-checklist.md](audit-checklist.md) — the gate checks
