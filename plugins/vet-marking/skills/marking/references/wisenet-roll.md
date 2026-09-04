# Who is required to submit — the WiseNet Unit Enrolment Outcome Matrix

Before marking, ask for the **WiseNet report 0217, Unit Enrolment Outcome
Matrix**, as `.xls` or `.xlsx`. It decides who appears on the marking record and
who gets a Student Assessment Record. Do not build the class list from a class
roll, a folder of submissions, or memory.

```bash
powershell -File scripts/Import-WisenetMatrix.ps1 -Path rpt_WiseNET_0217.xls -Unit BSBOPS501
```

## How the matrix encodes enrolment

One row per enrolment, one column per unit. The cell where they meet says
everything:

| Cell | Meaning | Marked? |
|---|---|---|
| **blacked out** | the student is **not attached to the unit** — never enrolled in it | **No.** No SAR, no row, no feedback sheet. |
| **an outcome code** | a result already exists — 20 competency achieved, 40 withdrawn, and so on | **No.** There is nothing left to assess. |
| **blank, not blacked out** | enrolled in the unit, no result yet | **Yes.** These are the students required to submit. |

The report states the first of these in its own legend, beside a black swatch:
*"- Not Attached to Unit"*.

**A blank cell and a blacked-out cell look nothing alike on screen and identical
in extracted text.** The importer reads the cell's fill colour, not its text,
which is why it needs the spreadsheet rather than a PDF of it.

## Outcome codes

Printed on the report itself; the importer names them in its output so an
exclusion is never a bare number.

| Code | Meaning | | Code | Meaning |
|---|---|---|---|---|
| 20 | Competency achieved/pass | | 70 | Continuing Enrolment |
| 30 | Competency not achieved/fail | | 70AP | Academic Pass (SA only) |
| 40 | Withdrawn | | 81 | Non-assessable, satisfactorily completed |
| 51 | Recognition of Prior Learning | | 82 | Non-assessable, withdrawn or not completed |
| 53 | Recognition of Current Competency | | 85 | Not Yet Started |
| 60 | Credit Transfer | | 90 | Enrolled |

### Codes 70, 85 and 90 are reported separately, not silently dropped

These three mean *enrolled, no result yet* — which is what a blank cell means
too. The blank-cell rule does not select them, because a code is present, so the
importer lists them under **ENROLLED, RESULT PENDING** and asks you to confirm
against the class roll whether they are due to submit.

That is a judgement about a real student's enrolment. It is not one this script
should make alone, and it is not one that should happen by silence.

## Identity is the student ID, never the name

One learner can hold two enrolments in the same course offer and appear on two
rows with the same name and different `RefInternal` IDs. The example report has
exactly that: two rows reading *Alex Fairweather*, `MVC3000901` and `MVC3000902`,
attached to different sets of units.

Match on the ID. A name-based match merges two students into one record.

## Pending enrolment — listed, never marked

A student whose **Status** column reads *Pending* has an enrolment that has not
started. There is nothing to expect from them and no result to record, so they
are not marked, whatever their unit cell says. A SAR produced for one of them
states that an assessment happened on a date they were not yet enrolled for.

They are reported under **PENDING ENROLMENT**, with the date their enrolment
starts, rather than dropped in silence: *not on the list* and *not yet enrolled*
are different answers to the question the assessor is asking.
`Resolve-MarkingLedger.ps1` refuses a ledger that carries one of them.

This is not the same as **ENROLLED, RESULT PENDING**, which is about outcome
codes 70, 85 and 90 recorded against the unit itself.

## Missing surnames

WiseNet prints `Given SURNAME` and renders a missing surname as `--`. The
importer strips the trailing dashes, takes an ALL-CAPS last word as the surname,
and lists anyone left without one under **SURNAME MISSING ON THE MATRIX**.

Get the surname from the student management system before building records. The
ledger rejects a student without one, which is the behaviour you want: a SAR
reading *"Mehreen"* with an empty surname field is not a record of anybody.

## What the importer gives you

Four lists, and the seed of a ledger:

- **REQUIRED TO SUBMIT** — becomes the `students` array
- **ENROLLED, RESULT PENDING** — confirm each one
- **ALREADY HAVE AN OUTCOME** — with the code and its meaning
- **NOT ATTACHED TO THE UNIT** — no record is produced for these students

Pass `-Json roll.json` to keep the machine-readable form.

The course offer code, description and location are read from the report's
header block, so the qualification on the records matches the qualification the
students are enrolled in.

## Excel is required

A legacy `.xls` is an OLE compound file; there is no reading it without Excel.
The importer says so plainly rather than half-working, and suggests saving the
report as `.xlsx` or supplying the student list directly.

## Does the student hold the unit's prerequisite?

The matrix carries one column per unit, so the prerequisite has a column too.
Pass it in and the importer classifies every student required to submit:

```bash
powershell -File scripts/Import-WisenetMatrix.ps1 -Path rpt_WiseNET_0217.xls -Unit SITHPAT016 -Prerequisite SITXFSA005
```

| Cell in the prerequisite's column | Status |
|---|---|
| **20, 51, 53, 60, 70AP, 81** | `completed` |
| Blank, or **30, 40, 70, 82, 85, 90** | `notCompleted` |
| **Blacked out**, or no column for it on the report | `notCompleted` |

Blacked-out is read by **cell fill colour**, exactly as for the unit being
marked. Never from text.

### There is no `unknown` on this axis

Where the matrix does not positively show the prerequisite as held, it is **not
completed**, and the student's result is withheld as **RW**. The report is the
record; an absence in it is a statement, not a gap.

This is the **opposite** of the training.gov.au rule in
[prerequisite-lookup.md](prerequisite-lookup.md), and deliberately so. There, an
absence means the skill failed to read the source, so it stops and asks. Here, an
absence is a statement about the student, so it decides.

### The assessor override

A student may hold the prerequisite from **another RTO**, in which case it cannot
appear on this matrix and the default above would withhold their result wrongly.
The assessor records the confirmation and what they saw:

```jsonc
"prerequisiteStatus": {
  "SITXFSA005": {
    "status": "confirmedExternally",
    "evidence": "Statement of Attainment, Adelaide Culinary Institute, 14/03/2025"
  }
}
```

`confirmedExternally` requires a non-empty `evidence` string and is the **only**
way to move a student off `notCompleted`.

**What counts as evidence:** an AQF testamur or Statement of Attainment issued by
an RTO, or an authenticated USI/VET transcript.

**What does not:** a verbal claim, a licence card, or a white card. None of these
records a unit of competency, and the skill says so wherever the assessor is
asked.

The importer's fifth list, **PREREQUISITE NOT COMPLETED**, names each student,
each prerequisite and which of the three cases put them there. The *no column on
this report* case is listed separately, because it is the one an assessor most
often needs to override.

## Related

- [ledger.md](ledger.md) — where the student list goes
- [prerequisite-lookup.md](prerequisite-lookup.md) — finding what the prerequisite is
- [result-rules.md](result-rules.md) — what happens to each student once selected
