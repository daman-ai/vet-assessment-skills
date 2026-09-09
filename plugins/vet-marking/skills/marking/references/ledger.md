# The marking ledger

The ledger is the single source of truth for a marking run. Every value that
appears on a SAR, on the marking record and on a feedback sheet comes from here,
and the gate checks the finished documents back against this same file.

**Why it exists.** A class of twenty students produces forty-one documents. A
tool name, a date or a result that is typed into each document separately will
go out of step somewhere, and the place it goes out of step is invisible until
an auditor finds a SAR that disagrees with the marking record summarising it.
Writing each fact once and rendering it many times makes that class of error
impossible rather than merely unlikely.

## The two-file flow

```
ledger.json  ──Resolve-MarkingLedger.ps1──▶  resolved.json
                                                  │
                              ┌───────────────────┼───────────────────┐
                              ▼                                       ▼
                  Build-MarkingRecords.ps1                Test-MarkingRecords.ps1
                              │                                       ▲
                              ▼                                       │
                        the documents ──────────────────────────────┘
```

You write `ledger.json`. Everything else is generated, and the gate closes the
loop by reading the documents back against the same resolved file the build
used.

## What you write

```jsonc
{
  "rto": "mvc",                      // key of an assets/rto.<key>.json profile

  "unit": {
    "code": "SITHPAT016",
    "title": "Produce desserts",
    "prerequisite": "N/A",           // 'N/A' where the unit has none — never blank
    "coreElective": "Elective"       // exactly 'Core' or 'Elective'
  },

  "qualification": { "code": "SIT30821", "title": "Certificate III in Commercial Cookery" },

  "assessor": "Priya Raman",
  "dueDate": "19 / 08 / 2026",       // optional; when the work was due back from
                                     // the student. Defaults to the date of
                                     // assessment, and prints on the cover sheet.
  "markingDate": "2026-09-02",       // the ONLY date you supply
  "resultsEnteredDate": "2026-09-03", // optional; defaults to the marking date

  "location": "Meridian Vocational College, Training Kitchen 2, Adelaide",
  "environment": "Simulated environment — commercial training kitchen…",

  "tools": [                         // the ACTUAL names on the assessment
    { "id": "kq", "name": "Knowledge Questions" },
    // isObservation marks a tool judged by watching the student work. The
    // resolver then REQUIRES an 'observations' record for every student who
    // was observed.
    { "id": "rw", "name": "Recipe Workbook and Observation of Direct Competency — Practical Demonstration",
      "isObservation": true }
  ],

  // The assessment pack's own cover sheet, mapped once for the whole class.
  // Values may be literals or any of these fields: {{studentName}},
  // {{studentId}}, {{unit}}, {{unitCode}}, {{qualification}},
  // {{qualificationCode}}, {{assessor}}, {{markingDate}}, {{assessmentDate}},
  // {{dueDate}}, {{resubmissionDue}}, {{overall}}, {{tools}}.
  // A cell the student already filled is left alone; every label on the sheet
  // must end up with a value, including one this map never names.
  "coverSheet": {
    "anchor":    "RTO- Bush Tukka",          // text that appears ONCE at the sheet
    "endAnchor": "Assessment Overview",      // optional; bounds it
    "fields": [
      { "label": "Student ACI ID:",     "value": "{{studentId}}" },
      { "label": "Due Date:",           "value": "{{dueDate}}" },
      { "label": "Trainer / Assessor:", "value": "{{assessor}}" }
    ],
    "boxes": [
      { "label": "First submission",  "whenAttempt": 1 },
      { "label": "Resit No.",         "whenAttempt": 2 },
      { "label": "Online submission", "ticked": true }
    ]
  },

  "students": [
    {
      "firstName": "Daniel",
      "surname": "Okafor",
      "studentId": "MVC00318",
      "attempt": 1,                  // optional, default 1; drives invoice and re-enrol
      "comment": "Recipe workbook: 2 dishes not to standard",
      "results": [
        {
          "toolId": "rw",
          "result": "NYS",           // 'S' or 'NYS'
          "submitted": true,         // optional, default true
          // WHAT YOU ACTUALLY READ. It is also the grouping key for the marked
          // copy: two tools naming the SAME file are marked together into one
          // copy of it, which is what happens when UAT 1 and UAT 2 are supplied
          // bound together. Give them the same path and they come back as one
          // marked document; give them different paths and they come back as
          // two.
          "evidence": "submissions/MVC00318_RW.docx",
          "aiFlagged": [],           // question labels CONFIRMED as not own work

          // THE WRONG ASSESSMENT. Something was submitted, but it is not this
          // unit's assessment. Forces NYS, writes its own feedback item, and
          // requires the class comment 'Incorrect assessment submitted'. It is
          // never filed as a non-submission — the student knows they sent
          // something. No marked copy is produced, so they receive the
          // standalone feedback sheet.
          "wrongAssessment": false,
          "submittedInstead": null,  // required where wrongAssessment is true

          // per-question outcomes drive the MARKED COPY of the submission:
          // a green or red line under each answer. List EVERY question — one
          // left out comes back to the student with no remark on it. Omit the
          // array entirely only for a tool that does not decompose into
          // numbered questions, and give that tool 'observations' instead.
          //
          // 'anchorAfter' is for a heading the assessment prints TWICE — once
            // snsChecklists — one per S / NS tick-box GRID in the submission,
            // in document order. That grid has no Yes/No words beside its
            // boxes and often no comments column, so neither of the writers
            // above finds anything in it. Two occasions is two entries; a
            // checklist split across two tables is also two, and the one
            // carrying the comments box is the second. The pair of columns is
            // found by its headings and three spellings are in circulation:
            // S / NS, S / NYS, and Satisfactory / Not yet.
            //   outcomes  one 'S' or 'NS' per criterion row, in sheet order
            //   notes     optional, one per row, '' where there is nothing.
            //             A notes cell that already carries writing is
            //             appended to, never overwritten
            //   outcome   optional, for the sheet's Outcome (tick one) table
            //   decision  optional, for a task decision line printed AFTER this
            //             grid — 'Assessor decision for Task 2 practical
            //             erection:  [] Satisfactory   [] Not Yet Satisfactory'.
            //             It is THIS GRID's judgement, not the tool's: a learner
            //             whose erection was watched and accepted, and whose
            //             dismantling record is missing, is 'S' here and 'NS' on
            //             the next grid, under one NYS tool. Left out, the tool
            //             result answers the line
            //   comments  optional, for the sheet's comments box; same floor
            //             as the observation record and unique to the learner
            //   assessor / dateText   the sheet's own sign-off line
            "snsChecklists": [
              {
                "outcomes": ["S", "S", "S"],
                "notes":    ["", "", ""],
                "outcome":  "S",
                "decision": "S",
                "comments": "The learner read the work instructions first...\nPPE changed at each stage as the work changed...",
                "assessor": "Priya Raman",
                "dateText": "02 / 09 / 2026"
              }
            ],
          // in its list of tasks and again over the task itself. It narrows the
          // search to what follows text that appears once; the anchor must
          // still match exactly once inside that.
          "questions": [
            { "ref": "Q1", "anchor": "Q1.", "outcome": "S"   },
            { "ref": "Q3", "anchor": "Q3.", "outcome": "NYS" },
            { "ref": "Activity 2", "anchor": "Activity 2: Draft a business plan",
              "anchorAfter": "Template 1: Report on elements of a business plan",
              "outcome": "S" }
          ],
          "questionsEndAnchor": "End of assessment",   // where the last answer stops

          // For an observation tool: the assessor's brief point-form record of
          // what was actually observed. REQUIRED where the tool is marked
          // isObservation. One short point per thing observed; the two-comma
          // rule applies.
          "observations": [
            "Observed mise en place complete before service.",
            "Observed all three desserts produced within the service period."
          ],

          // WHERE that record is written. The observation sheet inside the
          // submission is the instrument an auditor opens, so the record goes
          // into it: the ticks, the times, the notes, the feedback and the
          // sufficiency box. Everything is addressed by text, never by cell
          // number, because sheets differ between assessments.
          //
          // REQUIRED wherever 'observations' is set on a .docx submission.
          // Where the submission truly carries no sheet, say so explicitly with
          // { "inSubmission": false } and the record prints on the declaration
          // page instead. Leaving it out is refused, not assumed.
          //
          // THREE SHEET SHAPES. The default, 'labelled', has boxes that carry
          // their own word: '☐ Yes'. A sheet that instead heads two COLUMNS Yes
          // and No, leaving a bare '☐' in each cell, is read row by row off its
          // tables and must say so: "layout": "columns". Then 'outcomes' is one
          // per criterion row, 'comments' is one note per row of the comments
          // column, and 'sufficientLabels' names an overall box that does not
          // read Yes and No.
          //
          // The third, "layout": "inlinePairs", heads ONE decision column and
          // puts both boxes in its cell with their words: '☐ S ☐ NS'. It names
          // 'decisionHeader', 'yesLabel' and 'noLabel', and its anchor has to
          // sit ABOVE the table — see references/marked-assessment.md.
          "observationSheet": {
            "layout":           "labelled",              // or 'columns', 'inlinePairs'
            "anchor":           "Observation Checklist 1: Practical demonstration",
            "endAnchor":        "Observation Checklist 2",   // optional; bounds this sheet
            "notesAnchor":      "Observation notes",         // the record goes under this
            "outcomes":         ["Yes", "Yes", "No"],        // one per Yes/No pair, in sheet order
            "sufficientAnchor": "Sufficient",
            "sufficient":       false,
            "feedbackAnchor":   "Feedback to Student",
            "feedback":         "You set up safely and followed the procedure. …",
            "fields": [
              { "label": "Date",       "value": "02 / 09 / 2026" },
              { "label": "Start time", "value": "10:00 am" }
            ]
          },
          "feedback": "You produced all three desserts and…",
          "items": [                 // one per thing to redo; drives the feedback sheet
            {
              "questionNo": "Recipe card 2 — chocolate mousse",
              "issue": "The recipe card records no setting time…",
              "action": "Add the setting time in hours and…"
            }
          ]
        }
      ],
      "resit": {                     // optional; only where a re-assessment happened
        "result": "NYS",
        "feedback": "Your second attempt was assessed on…"
      },
      "furtherInstruction": null     // optional student-specific line on the sheet
    }
  ]
}
```

## What you must NOT write

The resolver **derives** these, and rejects a ledger that states them:

- `overall` — from the tool results
- `resubmissionDueText`, the date of assessment, feedback-given date — from `markingDate`
- `invoiceRaised`, `reEnrol` — from `attempt` and `overall`
- the per-tool feedback option — from `result` and `submitted`
- every output filename
- `markedCopies` — which marked copies exist, and which tools each covers, from
  grouping the results by their `evidence` path

Stating a derived value is how a marking record ends up disagreeing with the SAR
it summarises. If you want a different value, change the input it comes from.

## What the resolver validates

- every field above that has no defensible default is present and non-empty;
- every student has a judgement for **every** tool — a missing judgement is not a pass;
- a non-submission is NYS and carries the comment exactly `No submission`;
- an AI-flagged response forces its tool to NYS;
- an NYS tool that *was* submitted has at least one feedback item, so a student
  sent to resubmission is told what to fix;
- every tool row has feedback written;
- **no sentence of feedback carries more than two commas** — SAR feedback, both
  cells of every item, the marking record comment and resit feedback;
- per-question outcomes agree with the tool result: any NYS question forces the
  tool to NYS, an all-S question list cannot sit under an NYS tool, and every
  NYS question has a matching feedback item keyed by the same ref;
- student IDs and tool ids are unique;
- `coreElective` is exactly `Core` or `Elective`;
- the comment fits the Comments column;
- an observation record on a `.docx` submission says where it is written —
  `observationSheet` with an `anchor` and a `notesAnchor`, or an explicit
  `{ "inSubmission": false }`. Silence is refused, because the fallback it would
  otherwise pick leaves the sheet blank under a signed record;
- an `observationSheet` field carries a value, its `outcomes` read `Yes` or `No`,
  its `feedback` names a `feedbackAnchor`, and its `sufficient` names a
  `sufficientAnchor`;
- **every submitted tool's `feedback` meets the assessor-comment standard** — at
  least two paragraphs of at least twenty words each. A non-submission carries
  the RTO's standing wording and is exempt; a withheld result is not, because the
  work was still marked and the student still reads the comment;
- every entry in `results[].tasks[]` names a `ref` and an `anchor`, reads `S` or
  `NYS`, and carries a `comment` meeting the same standard. A Satisfactory tool
  cannot hold a Not Yet Satisfactory task, and an NYS tool with tasks has to name
  which task was not met;
- every row of `observationSheet.verification[]` names an `item`, reads `Yes` or
  `No`, and its `note` meets the row-note standard;
- every `snsChecklists` entry judges each criterion `S` or `NS`, agrees with its
  own overall `outcome` and with the tool result, gives one `notes` entry per
  row where it gives any, and — across the tool — records what was observed
  somewhere, in a comments box or in the notes;
- **no assessor prose calls a learner he or she.** Observation records,
  criterion comments, checklist comments and notes say *the learner*. Feedback
  written to the student is second person and is not checked.

It reports **every** problem at once and builds nothing. Fix them together.

## Tasks inside a tool

A tool made of **tasks** rather than questions — three practical activities in a
unit project — is judged task by task, and each task carries its own coloured
outcome and the assessor's comment on it:

```jsonc
"tasks": [
  {
    "ref":     "Activity 1",
    "anchor":  "Activity 1 - Apply cement render",   // text that appears ONCE
    "outcome": "S",
    "comment": "First paragraph, at least twenty words.\n\nSecond paragraph, likewise."
  }
]
```

`tasksEndAnchor` on the result bounds the last task the way `questionsEndAnchor`
bounds the last question. Without it the build warns and marks the last task at
the end of the document.

## The pre-start verification checklist

The small assessor table inside an activity — *Assessor / supervisor to confirm
before commencement* — is filled from the sheet:

```jsonc
"observationSheet": {
  "verification": [
    { "item": "Platform is stable and suitable for the task",
      "outcome": "Yes",
      "note": "The scaffold platform was checked for stability before access." }
  ]
}
```

Rows are found by their `item` text, never by position. **Only blank halves are
filled.** Where a student completed the checklist on site in their own words,
that is evidence and it is left exactly as they wrote it.

## Synthesised feedback items

A non-submission is NYS, so the student gets a feedback sheet — and a sheet with
no rows tells them nothing. There is no question to fix, so the resolver
synthesises one item per unsubmitted tool:

> **Whole assessment** · No assessment was submitted for this tool, so it could
> not be assessed. · Complete and submit your *&lt;tool&gt;* by *&lt;due date&gt;*.

You do not write these, and you should not: they must read identically for every
non-submitter in the class.

## Related

- [wisenet-roll.md](wisenet-roll.md) — where the student list comes from
- [marked-assessment.md](marked-assessment.md) — what `questions` produces
- [result-rules.md](result-rules.md) — what each derivation computes
- [date-rules.md](date-rules.md) — how one date becomes four
- `examples/ledger.example.json` — a worked five-student ledger covering the
  Competent, part-NYS, non-submission, authorship-flag and second-attempt cases
