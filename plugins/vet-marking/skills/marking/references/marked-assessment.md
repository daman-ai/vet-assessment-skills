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

```
                                      Overall result: Not Yet Competent   ← TOP RIGHT
MARKED ASSESSMENT                        green if Competent, red if not

Student:           Daniel Okafor  ·  MVC00318
Qualification:     SIT30821 Certificate III in Commercial Cookery
Unit:              SITHPAT016 Produce desserts
Assessment:        Knowledge Questions  ·  Recipe Workbook
Assessor:          Priya Raman  ·  Date of marking: 02 / 09 / 2026
Resubmission due:  09 / 09 / 2026

See your Student Feedback Sheet for the items to correct and the resubmission date.
                          ─── page break ───
```

The **overall result is right-aligned at the top**, so it is the first thing a
student sees on opening the file. Green `1E7B34` for Competent, red `C00000` for
Not Yet Competent. `Assessment:` names every tool the file covers.
`Resubmission due:` reads `N/A` where the student is Competent — a blank says
nothing, `N/A` says the question was asked and answered.

`MarkedCopyDeclarationPage` checks the delivered file for the page break, for the
result above it, and for the student's own content below it.

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
