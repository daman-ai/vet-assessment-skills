---
name: marking
description: Mark a batch of submitted student assessments for one unit of competency and produce the four records an Australian RTO keeps - a marked copy of each student's own assessment with a green Satisfactory or red Not yet Satisfactory under every response and the overall result on its front page, a Student Assessment Record per student, one Assessment Marking and Results Record for the class, and a Student Feedback Sheet for every student assessed Not Yet Competent. Reads the WiseNet 0217 Unit Enrolment Outcome Matrix to work out who was actually enrolled and is required to submit, by cell colour rather than text. Fills the RTO's own supplied Word templates without touching their headers, footers or numbering; judges substance rather than English, so no student is marked down for spelling or grammar; keeps feedback to two commas a sentence; derives every result, date, tick and filename from one ledger so forty documents cannot disagree; and blocks delivery on a gate that reads the finished files back. Serves Meridian Vocational College, ACI Culinary and ACI Construction, and any RTO that supplies its templates. Use when asked to mark assessments, mark student submissions, complete a SAR or student assessment record, produce a marking record or results record, write student feedback sheets, return marked assessments to students, record assessment outcomes, or process a batch of marking for a unit of competency.
---

# Assessment Marking

You are a VET assessor completing the official assessment records for **one unit
of competency**, for **one class**, on **one marking date**.

## What you produce

| Document | How many | Purpose |
|---|---|---|
| **Marked assessment** | one per submitted **file** | the student's own work returned, with an outcome inside every response box and a declaration page carrying the overall result |
| Student Assessment Record (SAR) | one per student | the individual record of that student's outcome |
| Assessment Marking and Results Record | one per class/unit | the class-wide summary, one row per student |
| Student Feedback Sheet | one per student assessed NYC | a single page listing what to fix and resubmit |

A class of twenty produces upwards of sixty documents. The three official
records are built by filling the RTO's approved templates — never by rebuilding
them. The marked assessment is the student's own file with a declaration page in
front of it and a judgement inside each answer.

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
10. Whether the unit is **Core or Elective** here, and its **pre-requisite** or `N/A`.

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
  **red** for Not Yet Competent — then the student, the qualification, the unit,
  every tool the file covers, the assessor, the marking date and the
  resubmission date;
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

## The workflow

### Stage 1 — the roll

Import the matrix for this unit. Confirm the pending-code students. Chase any
missing surname. That list, and only that list, becomes the class.

### Stage 2 — confirm the inputs

Work through items 2–10 above. Resolve the RTO key and confirm its templates are
registered.

### Stage 3 — read the evidence

For each student, for each tool, locate and read the submission. Record its
path. A tool with no findable submission is a non-submission: NYS, comment
exactly `No submission`.

Run `Test-AiFlag.ps1` over the written responses and **decide** each flag.

### Stage 4 — write the ledger

The class, the tools, and per student per tool: a result, the feedback, the
per-question outcomes for the marked copy, and — where NYS — the items to fix.
Do **not** write overall results, dates other than the marking date, invoice
flags or filenames.

Feedback style: [references/feedback-writing.md](references/feedback-writing.md).

```bash
powershell -File scripts/Resolve-MarkingLedger.ps1 -Path ledger.json -Out resolved.json
```

It reports **every** problem at once and builds nothing until they are fixed.

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

## The result rules

- **Per tool:** meets the requirements → S. Submitted but does not → NYS.
  Confirmed authorship flag → NYS. Nothing submitted → NYS, comment
  `No submission`.
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

## What must never happen

- **Never alter the templates' structure, styling, headers or footers.** The
  gate hashes every part except `document.xml` against the template.
- **Never alter the student's own words** in a marked copy.
- **Never leave an unfilled `[ … ]` field or a bracketed checkbox.**
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
  template-fill.md              OOXML mechanics; the traps that pass every check
  audit-checklist.md            the RTO's checklist mapped to gate checks
  onboarding-rto.md             registering a new RTO's templates
scripts/
  Lib-Docx.ps1                  OOXML: fields, ticks, rows, columns, outcome lines
  Lib-Dates.ps1                 working days, business days, the date block
  Lib-Text.ps1                  sentence splitting and the two comma rules
  Import-WisenetMatrix.ps1      read report 0217, select who must submit
  Measure-Template.ps1          map a supplied template
  Resolve-MarkingLedger.ps1     validate and derive
  Build-MarkingRecords.ps1      render the three official records, then the marked copies
  Build-MarkedAssessment.ps1    mark the student's own submission
  Test-MarkingRecords.ps1       the blocking gate
  Test-AiFlag.ps1               the authorship rule, with its evidence
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
6. **The comma binds tighter than `+` in a PowerShell array literal.**
   `@('a', 'b' + $x, 'c')` is four elements, not three, so a `-join` of it
   silently gains a line break where the concatenation was meant to be.

Details, plus the nested-array and `SetAttribute`-returns-a-value traps:
[references/template-fill.md](references/template-fill.md).
