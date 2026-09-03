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
exactly that: two rows reading *Mei Tanaka*, `MVC00366` and `MVC00387`,
attached to different sets of units.

Match on the ID. A name-based match merges two students into one record.

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

## Related

- [ledger.md](ledger.md) — where the student list goes
- [result-rules.md](result-rules.md) — what happens to each student once selected
