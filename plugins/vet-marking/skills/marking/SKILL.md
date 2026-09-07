---
name: marking
description: Mark a batch of submitted student assessments for one unit of competency and produce the records an Australian RTO keeps - a marked copy of each student's own assessment carrying a filled cover sheet, a feedback page and a green Satisfactory or red Not yet Satisfactory inside every response, a standalone Student Feedback Sheet for any student with nothing coming back, a Student Assessment Record per student, and one Assessment Marking and Results Record for the class (not built for a class of one). Every student is handed their feedback, not only those assessed Not Yet Competent. Reads the unit's prerequisites from training.gov.au and confirms each student holds them from the WiseNet 0217 Unit Enrolment Outcome Matrix, withholding the result as RW where they do not. Works out who is required to submit from that same matrix, by cell colour rather than text. Fills the RTO's own supplied Word templates without touching their headers, footers or numbering; judges substance rather than English, so no student is marked down for spelling or grammar; keeps feedback to two commas a sentence; stacks resubmissions so an earlier attempt is never overwritten; derives every result, date, tick and filename from one ledger so fifty documents cannot disagree; and blocks delivery on a gate that reads the finished files back. Consolidates several marking runs into one record per WiseNet course-offer group and lays the result out as a handover package, one folder per group and one per student inside it. Serves Meridian Vocational College, ACI Culinary and ACI Construction, and any RTO that supplies its templates. Use when asked to mark assessments, mark student submissions, complete a SAR or student assessment record, produce a marking record or results record, write student feedback, return marked assessments to students, record assessment outcomes, process a batch of marking for a unit of competency, consolidate marking runs into per-group records, or build a group handover package.
---

# Assessment Marking

You are a VET assessor completing the official assessment records for **one unit
of competency**, for **one class**, on **one marking date**.

## What you produce

| Document | How many | Purpose |
|---|---|---|
| **Marked assessment** | one per submitted **file** | the student's own work returned, with an outcome inside every response box, a filled cover sheet, and a **feedback page** in front carrying the overall result and the feedback |
| **Student Feedback Sheet** | one per student with **no** marked copy | the same feedback, standalone, for a student who has nothing coming back |
| Student Assessment Record (SAR) | one per student | the individual record of that student's outcome |
| Assessment Marking and Results Record | one per class/unit, or **one per WiseNet course-offer group** where the RTO files by group | the class-wide summary, one row per student. **Not built for a class of one** |

**EVERY STUDENT IS HANDED THEIR FEEDBACK.** A student with work coming back reads
it on page one of their own marked assessment, where it cannot be separated from
the work it describes. A student with nothing coming back — nothing submitted, or
the wrong assessment submitted — is issued the standalone Student Feedback Sheet
in the same format. Their feedback must not live only on the SAR: that is an
internal record, and a student never sees it.

Both are the RTO's own Student Feedback Sheet — the same tables, the same
palette, not a paragraph rendering of it — so a class that receives some of each
is reading one document rather than two.

A class of twenty produces around fifty documents. The official records are
built by filling the RTO's approved templates — never by rebuilding them. The
marked assessment is the student's own file with a feedback page in front of it
and a judgement inside each answer.

**One file, one marked copy.** Where UAT 1 and UAT 2 are supplied bound
together, they are marked together and come back as one document. Splitting them
would return the same file to the student twice, each copy carrying half the
marking.

## The one idea that holds it together

**Every fact is written once, in a ledger, and rendered many times.**

A tool name, a date or a result typed separately into sixty documents will go
out of step somewhere, and the place it goes out of step is invisible until an
auditor finds a SAR that disagrees with the marking record summarising it.

So: you write `ledger.json`. `Resolve-MarkingLedger.ps1` validates it and derives
everything that follows — overall results, all four dates, invoice and re-enrol
flags, the per-tool feedback option, every filename. `Build-MarkingRecords.ps1`
renders the documents. `Test-MarkingRecords.ps1` reads the finished files back
and checks them against that same ledger.

Read [references/ledger.md](references/ledger.md) before writing one.

## Before you start — what you must be given

1. The **WiseNet report 0217, Unit Enrolment Outcome Matrix** — `.xls` or
   `.xlsx`. **Ask for this first.** It decides who is marked.
2. The **unit of competency** — code and title.
3. The **qualification** — code and title.
4. The **RTO** — which of the registered profiles.
5. The **trainer/assessor** name.
6. The **marking date**.
7. The **names of the assessment tools**, as they actually appear on the
   assessment.
8. The **submitted assessment evidence** for each student, per tool, as `.docx`
   where a marked copy is wanted.
9. The **location** and the **assessment environment**.
10. Whether the unit is **Core or Elective** here. Its **prerequisites** are not
    asked for - they are looked up from training.gov.au in Stage 1b, because
    "N/A" from a person cannot be told apart from "nobody checked".

**If any of these is missing, ask for it. Do not guess.** The resolver rejects a
ledger missing any of them and names each one.

## Who is required to submit — read the matrix, not a class roll

```bash
powershell -File scripts/Import-WisenetMatrix.ps1 -Path rpt_WiseNET_0217.xls -Unit BSBOPS501
```

For the unit's column, each student's cell says everything:

| Cell | Meaning | Marked? |
|---|---|---|
| **blacked out** | **not attached to the unit** — never enrolled | **No.** No record of any kind. |
| **an outcome code** | a result already exists (20, 40, …) | **No.** Nothing left to assess. |
| **blank, not blacked out** | enrolled, no result yet | **Yes.** Required to submit. |

**A student whose enrolment status is Pending is not marked**, whatever their
cell says. Their enrolment has not started, so there is no assessment to expect
and no result to record — and a record produced for them states that an
assessment happened. The importer lists them under **PENDING ENROLMENT** rather
than dropping them, and the resolver refuses a ledger that contains one.

The report's own legend says it: a black cell reads *"- Not Attached to Unit"*.
The importer reads **cell fill colour**, not text — which is why it needs the
spreadsheet and not a PDF of it.

Codes **70, 85 and 90** mean *enrolled, no result yet* as well. The blank-cell
rule does not select them, so they are listed separately for you to confirm
against the class roll rather than dropped in silence.

**Identity is the student ID, never the name** — one learner can hold two
enrolments and appear twice. Details: [references/wisenet-roll.md](references/wisenet-roll.md).

## The RTO decides the templates

| Key | RTO | Templates |
|---|---|---|
| `mvc` | Golden Wattle Group Pty Ltd T/A Meridian Vocational College · RTO 45039 · CRICOS 03551M | supplied and measured |
| `aci-culinary` | Bush Tukka Pty Ltd T/A Adelaide Culinary Institute · RTO 45797 · CRICOS 03978F | supplied and measured |
| `aci-construction` | Bush Tukka Pty Ltd T/A Adelaide Construction Institute · RTO 45797 · CRICOS 03978F | supplied and measured |

**The builder refuses to run for an RTO whose templates have not been supplied,
and never falls back to another RTO's.** A Meridian-headed SAR carrying an ACI
student's result is a wrong record — wrong RTO code, wrong CRICOS code, wrong
legal entity — signed by an assessor and filed as evidence.

ACI is **one RTO trading under two names**; which name a record carries is
decided by the unit's training package (SIT → Culinary, CPC → Construction). To
register templates: [references/onboarding-rto.md](references/onboarding-rto.md).

## How to judge — read this before marking anything

**Assess the substance, not the English.** Do not mark a student down for
spelling, grammar, punctuation, sentence structure, word choice or written
expression. Many students are working in a second language. Language quality is
not a requirement of the unit and is not being assessed.

**If the answer is reasonable, accept it.** Accept an answer that is brief, uses
different words or a different example than the model answer, is written in dot
points or imperfect English, or is incomplete on detail that is not itself a
requirement of the unit.

**Mark NYS only where the requirement is genuinely not demonstrated** — the
answer is absent, factually wrong, addresses a different question, or misses
something the unit explicitly calls for. A borderline answer that shows the
student understands is Satisfactory. **Where you are unsure, favour
Satisfactory** and note the reasoning in the assessor comments.

**Never invent evidence.** Every judgement traces to a document you have
actually read; record its path in the ledger's `evidence` field. If you cannot
find a submission, that is a **non-submission** — not a fail on quality grounds.

Full standard: [references/marking-standard.md](references/marking-standard.md).

## Two comma rules. They are not the same rule.

| | Target | Limit | Effect |
|---|---|---|---|
| **Authorship flag** | the **student's** written response | more than **4** commas in one sentence | flags possible AI generation; an assessor confirms or dismisses; a confirmed flag makes that tool NYS |
| **Feedback style** | what **you** write | more than **2** commas in one sentence | **blocks the build** |

One reads a student's work to judge it. The other polices our own prose: a
student being asked to act on a resubmission should not have to read the
sentence twice. Both live in `Lib-Text.ps1`, deliberately side by side, so
nobody merges them.

Comma count is a proxy for sentence complexity, not authorship — it flags a
student listing six ingredients and misses generated text in short sentences.
`Test-AiFlag.ps1` therefore reports every hit **with the sentence that triggered
it**, and **every flag is an assessor decision before it reaches the ledger.**

## The marked assessment

The student's own submission comes back marked. It carries:

- a **declaration page of its own**, in front of the student's first page,
  carrying the overall result in the top right corner — **green** for Competent,
  **red** for Not Yet Competent — and below it the RTO's Student Feedback Sheet
  **as a table**: the student, the qualification, the unit, every tool the file
  covers, the assessor, the marking date and the resubmission date, then the
  per-tool feedback and the items to fix in the sheet's own five columns. The
  sheet is scaled onto the width the student's own tables draw at, so it lines
  up with every page beneath it;
- under **every question's response, inside the response box**, one line:
  green **Satisfactory**, or red **Not yet Satisfactory - refer to feedback
  sheet**. Every question gets one — a question with no remark reads as an
  oversight rather than a judgement;
- for an **observation tool**, the assessor's record written **into the
  observation sheet the student submitted** — the ticks, the times, the
  point-form notes, the feedback and the sufficiency box.

**One marked copy per submitted FILE, not per tool.** Where UAT 1 and UAT 2 are
supplied bound together, they are marked together into that one document, and
its declaration page names both. The resolver groups results by the file they
were read from and publishes the groups as `markedCopies`, so the builder and
the gate cannot disagree about which files exist.

**The student's words are never altered and nothing is deleted.** The red line
points at the feedback sheet rather than restating the fault, so the fault is
described in one place and cannot drift.

### The cover sheet comes back filled

The assessment cover sheet at the front of the submission is the first page an
auditor turns to, and half its fields are the RTO's to complete: the student ID,
the due date, the qualification, the trainer or assessor, the assessment type
box. A returned assessment whose Trainer / Assessor line is blank records that
nobody was responsible for marking it.

The ledger's `coverSheet` maps each label to its value, and the builder fills
every one — leaving alone anything the student already wrote, because their words
are not ours to restate. Then **every** label on the sheet is checked for a
value, including labels the map never named, and one without a value stops the
build. `CoverSheetFilled` checks the delivered file again.

### The outcome goes in the answer, not under it

Each question names an `anchor` — the text identifying it in the submission. The
outcome lands at the end of that question's response block, which puts it
**inside the response box, under the student's answer**. Getting there means
walking back over the empty spacer that sits between an answer table and the
next question, over floating text boxes, and over a short run of the next
question's own heading rows. `questionsEndAnchor` marks where the last answer
stops. `MarkedCopyInAnswerSpace` checks the delivered file: an outcome line
sitting under a blank paragraph, or outside the box holding the answer above it,
fails the gate.

### Two sheet shapes

A **labelled** sheet writes the decision into the box's own text — `☐ Yes`. A
**column** sheet heads two columns `Yes` and `No` and leaves a bare `☐` in each
cell, which is what ACI's construction checklists do. The readers are blind to
each other, so the ledger says which shape it is with
`observationSheet.layout: "columns"`, and a column sheet's `comments` fill its
comments column, one note per criterion row. Details:
[references/marked-assessment.md](references/marked-assessment.md).

### The observation sheet is filled in, not bypassed

An observation tool names its sheet with `observationSheet`, and the record is
written into it. The sheet is the instrument an auditor opens; a blank sheet
with a tidy summary stapled in front of it answers their question the wrong way
round. Where a submission genuinely has no sheet, say so —
`"observationSheet": { "inSubmission": false }` — and the record goes on the
declaration page instead. Silence is not an option: the resolver refuses.

**The build never guesses.** A missing or ambiguous anchor is a hard failure
naming the question; nothing is written. So is a sheet whose Yes/No pairs do not
number the same as the ledger's outcomes. An outcome stamped under the wrong
answer, or a box ticked against the wrong task, is worse than no marked copy.

Details: [references/marked-assessment.md](references/marked-assessment.md).

### Writing the assessor comments area

The sheet's **Assessor comments** area has its own, stricter standard. Write the
way an experienced assessor writes on the day — plain, direct, slightly clipped.

- **One comment per comments area.** Several occasions or several boxes get one
  each, matching whatever the sheet actually provides.
- **Assume competency.** Confirm the checklist items were met. No hedging and no
  improvement areas unless you are asked for them.
- **Name at least three specifics from that student's own work** — the item they
  chose, the location, the rating or measurement, the tool selected, what
  another participant contributed, what they escalated.
- **Say what they did and in what order**, tied to the criterion. Behaviour, not
  labels. Show the written work carrying through into the performance, and cover
  every safety, PPE or procedural item the checklist lists.
- **2 sentences and 30 words per paragraph, 3 to 5 paragraphs.** Past tense,
  third person, active voice. No *demonstrated a sound understanding*, no
  *showcased*, no *effectively utilised*.
- **Uniqueness is the rule that matters.** No two students share an opening
  sentence, a sentence shape or a descriptive phrase, and no distinctive phrase
  appears twice in the cohort. Cover the student's name and the comment must
  still say who it belongs to.
- **Where the work is too thin, say so.** Naming three specifics that were not in
  the student's work is fabricated evidence on a signed record.

```bash
powershell -File scripts/Test-ObservationComments.ps1 -Path comments.json
```

It checks the countable rules and the cohort-wide uniqueness rules together,
which is the point — a comment reads fine alone and still fails because the one
above it opens the same way.

Full standard: [references/observation-comments.md](references/observation-comments.md).

## The workflow

### Stage 1 — the roll

Import the matrix for this unit. Confirm the pending-code students. Chase any
missing surname. That list, and only that list, becomes the class.

### Stage 1b — look up the unit's prerequisites

**Every unit, every time.** Not only the ones someone suspects have a
prerequisite.

```bash
powershell -File scripts/Get-UnitPrerequisites.ps1 -Unit SITHPAT016
```

It reads the **Pre-requisite unit** field from training.gov.au and records the
answer in `assets/prerequisites.cache.json` with the endpoint and the date read.

**Do not fetch the unit page and read it.** training.gov.au renders client-side:
a plain GET returns HTTP 200 and an empty shell in which the word *prerequisite*
appears zero times. An implementation that reads "field not found" as "no
prerequisite" gets a wrong answer for every unit and never errors. The script
uses the JSON API behind the page instead —
[references/prerequisite-lookup.md](references/prerequisite-lookup.md).

**`Nil` means no prerequisite. Nothing else does.** An empty response, a failed
request, a unit that cannot be found or a field that cannot be located is
`unknown`, and `unknown` **stops the run**. Ask the assessor to confirm from the
unit of competency or the training package companion volume, and record it. Never
default to `N/A`, and never infer from the unit's name or training package.

### Stage 2 — confirm the inputs

Work through items 2–10 above. Resolve the RTO key and confirm its templates are
registered.

### Stage 3 — read the evidence

For each student, for each tool, locate and read the submission. Record its
path. A tool with no findable submission is a non-submission: NYS, comment
exactly `No submission`.

Run `Test-AiFlag.ps1` over the written responses and **decide** each flag.

**This is the only stage worth doing many at a time.** The students are
independent of one another, and forty documents is the only slow part of a
marking run. Every other stage either reads one thing for the whole class or
needs the whole class at once. Details, and the two things parallelism makes
worse: [references/parallel-marking.md](references/parallel-marking.md).

### Stage 4 — write the ledger

The class, the tools, and per student per tool: a result, the feedback, the
per-question outcomes for the marked copy, and — where NYS — the items to fix.
Do **not** write overall results, dates other than the marking date, invoice
flags or filenames.

Feedback style: [references/feedback-writing.md](references/feedback-writing.md).

Where stage 3 ran in parallel, each worker writes **one student's block to its
own file** and the fragments are merged first:

```bash
powershell -File scripts/Merge-LedgerFragments.ps1 -Base ledger.base.json -Fragments .\fragments -Roll roll.json -Out ledger.json
```

```bash
powershell -File scripts/Resolve-MarkingLedger.ps1 -Path ledger.json -Roll roll.json -Out resolved.json
```

It reports **every** problem at once and builds nothing until they are fixed.

**Pass `-Roll`.** It is the only thing that can see a student who never reached
the ledger. Every check after this compares the ledger to the documents built
from it, so someone missing from both reads as a clean run of a smaller class.
Without a roll the gate reports `RollReconciled` as a **WARN**, not a pass.

### Stage 5 — build

```bash
powershell -File scripts/Build-MarkingRecords.ps1 -Ledger resolved.json -OutDir out -SubmissionRoot .
```

### Stage 6 — gate

```bash
powershell -File scripts/Test-MarkingRecords.ps1 -Ledger resolved.json -Dir out
```

**Nothing is delivered until this passes.** Twenty-six checks, run against the
delivered files rather than the build's log.

### Stage 7 — report

Say what was produced, the outcome split, and anything the assessor must decide:
authorship flags confirmed, students excluded by the matrix and why, evidence
that could not be found, any feedback sheet that overflowed ten items.

### Stage 8 — consolidate by group, where the RTO files by group

A marking run is scoped to a **day**. What the RTO files is scoped to a
**course-offer group** — and a group's learners are marked on whatever day their
work came in, so the records that go on the file are cut differently from the
runs that made them. Where a unit has been marked over more than one day, or
where one run spans several groups, consolidate:

```bash
powershell -File scripts/Merge-MarkingLedgers.ps1 -Ledger run1/resolved.json,run2/resolved.json -Matrix rpt_0217.xls -OutDir groups
powershell -File scripts/Build-MarkingRecords.ps1 -Ledger groups/group_Group_1.json -OutDir records -RecordOnly
powershell -File scripts/Build-GroupPackage.ps1 -GroupLedgerDir groups -RecordDir records -OutDir package -SourceDir run1,run2 -Zip package.zip
powershell -File scripts/Test-GroupPackage.ps1 -GroupLedgerDir groups -Dir package -Zip package.zip
```

The merge reads **every worksheet** of the 0217 export — one per course offer —
and refuses three things outright, because each is a record an auditor would
reject: the **same student in two ledgers** (a resit is one entry with attempt 2,
never two entries), a student **on two worksheets** (fix the enrolment in WiseNet
first — whichever group is picked, the other record is wrong), and a marked
student **on no worksheet at all**.

Each learner keeps their own feedback-given and resubmission dates, so a group
record covering two marking days shows every learner the day their own feedback
was given. The record's own sign-off date is the latest run it draws on. Serial
numbers are renumbered per group and rows are sorted by surname, because the
record is read down the page by somebody looking for one learner.

`-RecordOnly` builds the class record alone. The SARs, feedback sheets and marked
copies were built, gated and issued by the runs that produced them; rebuilding
them would need the submissions back, and would replace documents an assessor has
already signed with fresh ones nobody has read.

The package is the shape the documents are handed over in:

```
Group 1 - Certificate III in Commercial Cookery/
  AMLC_SITHPAT016_Group_1_02092026.docx
  01 Daniel Okafor (MVC00318)/
    SAR_SITHPAT016_Daniel Okafor_MVC00318_NYC.docx
    SITHPAT016_Daniel Okafor_MVC00318_NYC_kq.docx
```

Every file is copied by the name the ledger holds — nothing is matched by
pattern, because a pattern that matched two students would file one learner's
marked work in another learner's folder, and the folder is what a student is
handed. `Test-GroupPackage.ps1` is the blocking gate: eleven checks, including
that each record names its own group's students **and nobody else**, that no
student ID sits under two group folders, and that the zip holds exactly what the
folders hold.

Two things bite on Windows, and both are checked rather than discovered. The
**260 character path limit** — the package root, a group folder, a student folder
and a document name together clear it easily, so the builder measures before it
copies and tells you to choose a shorter `-OutDir`. And **8.3 short paths**:
`$env:TEMP` arrives as `C:\Users\ACI-AD~1\...` wherever the account name runs
past eight characters, while `Get-ChildItem` reports the long form, so a relative
name built by subtracting one string's length from the other keeps the tail of
the folder's own name — every zip entry under a phantom `e/`. Builder and gate
both enumerate with `Directory::GetFiles` from the same root string for that
reason, and a gate that repeats the builder's arithmetic agrees with it and
proves nothing.

## The result rules

- **Per tool:** meets the requirements → S. Submitted but does not → NYS.
  Confirmed authorship flag → NYS. Nothing submitted → NYS, comment
  `No submission`. **The wrong assessment submitted** — another unit's work, or
  another unit's tool → NYS, comment `Incorrect assessment submitted`, and the
  student is told what arrived and what to send instead. It is not filed as a
  non-submission: the student knows they submitted something.
- **Overall:** any NYS → **NYC**. All S → **C**.
- **Invoice Raised** ☒ only where NYC **after the second attempt**.
  **Re-enrol** ☒ only where the second attempt is not satisfactory.

Details: [references/result-rules.md](references/result-rules.md).

## The dates

All four derive from the marking date alone:

| Field | Rule |
|---|---|
| Date of assessment | marking date − 14 calendar days, rolled **back** to a working day |
| Feedback Given | the marking date |
| Resubmission Due | **5 business days** forward; `N/A` where the student is Competent |
| Date results entered | the SMS entry date; defaults to the marking date |

All print `dd / mm / yyyy`. The date functions **throw** outside the years the SA
public holiday table covers rather than falling back to a weekends-only
calendar. Verify the gazetted dates before marking:
[references/date-rules.md](references/date-rules.md).

## The practical observation, and why the sheet reads Yes

**Read this before you mark a practical.**

### How the practical actually runs

The RTO's process, confirmed 2 September 2026:

- **The practical is conducted before any marking happens.** It is a real
  session, not a paper exercise.
- **A trainer always oversees the practical operation.** There is no unsupervised
  practical.
- **Oral feedback is given to the student at the time**, during or straight after
  the session.
- **The sheet is then ticked Yes for all submitted work**, and the assessor
  comments are written to
  [references/observation-comments.md](references/observation-comments.md).

So a Yes on the sheet is a record of something that happened and was watched. It
is not an assumption drawn from the student having handed in the theory.

### What the sheet carries

**The printed sheet keeps both columns.** It still shows Yes and No, because it
is the RTO's approved instrument and its shape is not ours to change. What the
builder does is tick the Yes of each pair and leave the No empty.

Where a submission contains an observation sheet it is completed in full: every
Yes/No pair ticked **Yes**, the sufficiency box **satisfactory**, every field
filled, the feedback line written, and assessor comments in every comments area.
`observationSheet.outcomes` does not accept `"No"` and `sufficient` must be
`true`. The resolver refuses both, naming the sheet.

### Where a practical shortfall goes

Because the sheet records that the observation happened, it is **not** where a
shortfall is recorded. If a student did not do something the checklist asks for,
that belongs in three other places — and the oral feedback given on the day is
what tells them at the time:

- the **tool result** — `NYS` on that tool;
- the **SAR feedback** for that tool, naming what was not demonstrated;
- the **feedback items** on page one, which tell the student what to redo.

The worked example shows exactly this. Daniel's practical is NYS with two items
to correct, and his observation sheet still reads all Yes — the observation
happened and was satisfactory as an observation; the shortfall is in his recipe
workbook, and that is where the record puts it.

### The one thing to watch

A sheet that can only say Yes records **that** an observation happened rather
than **what** it found. That is workable while the practical genuinely runs the
way described above — supervised, before marking, with oral feedback. It stops
being workable the moment someone ticks Yes for a practical that did not happen,
and nothing in this skill could detect that. It rests on the process, not on the
gate.

## What must never happen

- **Never alter the templates' structure, styling, headers or footers.** The
  gate hashes every part except `document.xml` against the template.
- **Never alter the student's own words** in a marked copy.
- **Never leave an unfilled `[ … ]` field or a bracketed checkbox.**
- **Never return a cover sheet with a blank field.** Half of them are the RTO's
  to complete, and a blank Trainer / Assessor line records that nobody marked it.
- **Never mark a student whose enrolment is Pending.** There is no assessment to
  expect, and the record would say one happened.
- **Never file the wrong assessment as a non-submission.** The student submitted
  something; tell them what arrived and what to send instead.
- **Never leave a student's feedback on the SAR alone.** They never see it. Page
  one of the marked copy, or a standalone sheet where nothing comes back.
- **Never let two documents disagree.** The cross-document check compares every
  SAR, its row in the marking record, its feedback sheet and its marked copy.
- **Never mark a student down for their English.**
- **Never stamp an outcome outside the answer it judges.** It belongs in the
  response box, under the student's words, not on the spacer below the table.
- **Never leave an observation sheet blank** under a record that says the
  observation happened.
- **Never split one submitted file into two marked copies.** A document holding
  UAT 1 and UAT 2 comes back once, marked throughout.
- **Never use the word the RTO has banned** — the software-jargon term for a
  fill-in field. Say *field*. `NoBannedWord` blocks any document containing it.
- **Never record one student twice, and never put them in two groups.** One
  student, one marking entry, one group folder, one row on one group record. A
  resit is `attempt: 2` on that single entry, not a second entry. Where the 0217
  export itself lists a learner on two worksheets, the enrolment is wrong and
  the merge stops until WiseNet is fixed.
- **Never file a document by matching a pattern.** Every marked copy, SAR and
  feedback sheet is copied into a group package by the exact name its ledger
  holds. A pattern that matched two students would put one learner's marked work
  in another learner's folder, and the folder is what a student is handed.

## Files

```
SKILL.md
assets/
  rto.mvc.json                  measured template map, RTO identity, marked-copy colours
  rto.aci-culinary.json         measured template map, SIT variant
  rto.aci-construction.json     measured template map, CPC variant
  public-holidays.sa.json       observed SA holidays, 2026–2028
  templates/                    the RTO's supplied .docx templates
examples/
  ledger.example.json           five students: C, part-NYS, non-submission,
                                authorship flag, second attempt; two tools in
                                one file, and an observation sheet filled in
references/
  ledger.md                     the ledger schema — read before writing one
  wisenet-roll.md               who is required to submit, and how the matrix says so
  marked-assessment.md          the green/red copy returned to the student
  marking-standard.md           how to judge; the authorship rule and its limits
  result-rules.md               S/NYS → C/NYC, resit, invoicing
  date-rules.md                 the four dates and the holiday table
  feedback-writing.md           three places, three lengths, the two-comma rule
  observation-comments.md       the assessor comments area on an observation sheet
  parallel-marking.md           what parallelises, what must not, and the fragment contract
  template-fill.md              OOXML mechanics; the traps that pass every check
  audit-checklist.md            the RTO's checklist mapped to gate checks
  onboarding-rto.md             registering a new RTO's templates
scripts/
  Lib-Docx.ps1                  OOXML: fields, ticks, rows, columns, outcome lines
  Lib-Dates.ps1                 working days, business days, the date block
  Lib-Text.ps1                  sentence splitting and the two comma rules
  Import-WisenetMatrix.ps1      read report 0217, select who must submit
  Get-UnitPrerequisites.ps1     read the unit's Pre-requisite unit from training.gov.au
  Measure-Template.ps1          map a supplied template
  Merge-LedgerFragments.ps1     join per-student fragments into one ledger
  Resolve-MarkingLedger.ps1     validate and derive
  Build-MarkingRecords.ps1      render the three official records, then the marked copies
  Build-MarkedAssessment.ps1    mark the student's own submission
  Test-MarkingRecords.ps1       the blocking gate
  Test-AiFlag.ps1               the authorship rule, with its evidence
  Test-ObservationComments.ps1  the observation-comment standard, cohort-wide
  Read-Groups.ps1               read every worksheet of 0217, the roster of each group
  Merge-MarkingLedgers.ps1      consolidate runs into one resolved ledger per group
  Set-AmrrColumns.ps1           re-lay a record's column widths, grid and cells together
  Build-GroupPackage.ps1        group folders, a folder per student, the zip
  Test-GroupPackage.ps1         the blocking gate for a consolidated group package
  Test-Install.ps1              prove the skill runs on this machine
```

## Traps worth knowing before you edit the scripts

All of these produce output that passes ordinary checks, so each cost a full
build before it was found.

1. **`xml:space` must be set with an explicit `xml` prefix.** `SetAttribute` on
   the reserved namespace makes `XmlDocument` invent one (`d8p1:space`) — a
   well-formed file **Word refuses to open**. Use `Set-XmlSpacePreserve`.
2. **Every `.ps1` here needs a UTF-8 BOM.** PowerShell 5.1 reads a BOM-less file
   as ANSI. It fails to *parse* with errors pointing nowhere near the cause —
   or, worse, parses fine and silently mojibakes every dash and degree sign it
   writes into a document. `NoMojibake` catches the second mode.
3. **`@($null).Count` is 1, not 0** — so "does this list have anything in it"
   answers yes for a property that does not exist. Count through `Get-Count`.
4. **`"$var:"` is a parse error** (drive-qualified variable). Write `"${var}:"`.
5. **`.//w:p` selects DESCENDANT paragraphs**, so handing `Set-TextInNode` a
   `w:p` — the natural thing to do when ticking one box out of a column of them
   — matched nothing and replaced nothing, silently. Every box on a delivered
   observation sheet stayed empty under a signed record and the gate passed.
   Fixed in `Set-TextInNode`; the lesson is that a no-op is not an error.
6. **`,@($list)` at a function's end, wrapped in `@()` by the caller, is one
   element.** The comma idiom protects a one-item list from unrolling and turns
   every longer one into a single element holding an array. A 28-row observation
   sheet was reported as having one criterion row. Return `@($list)`.
7. **The comma binds tighter than `+` in a PowerShell array literal.**
   `@('a', 'b' + $x, 'c')` is four elements, not three, so a `-join` of it
   silently gains a line break where the concatenation was meant to be.

Details, plus the nested-array and `SetAttribute`-returns-a-value traps:
[references/template-fill.md](references/template-fill.md).
