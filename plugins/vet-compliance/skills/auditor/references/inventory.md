# Phase 1 — Inventory

Register what exists before judging any of it. Phase 1 ends with a stop: the
client sees the register and the missing-document list, and directs what happens
next. Nothing is rewritten in Phase 1.

The reason for the stop is not politeness. A gap analysis built on an incomplete
document set produces findings that are wrong in the most damaging direction —
"absent" against a policy that exists and was simply not sent. Every one of those
costs credibility, and the client stops reading the ones that are real.

## Run the scan first

```powershell
.\scripts\New-DocumentRegister.ps1 -Path <working folder> -Ledger assurance.json
```

It walks the folder, extracts text from `.docx`, `.pdf`, `.xlsx`, `.md` and
`.txt`, records name, type, size, modified date, a SHA-256, and every superseded
reference it finds. It writes `documents` into the ledger and
`00-document-register.md` beside it.

Read the output; do not trust it. The scan gets file facts right and document
facts wrong — it cannot tell a policy from a procedure reliably, it reads a
version number out of a filename that may be a lie, and it has no idea which
entity a document covers. Correct those by hand in the ledger.

## Superseded references

The scan flags text matching the repealed instrument. The patterns and why each
one matters:

| Pattern | Why it is a finding |
|---|---|
| `Standards for RTOs 2015`, `SRTO 2015`, `SRTOs 2015` | Names an instrument repealed in full by Schedule 3 of `F2025L00355` |
| `clause N.N` | The 2015 Standards used *clauses*; the 2025 Outcome Standards use *Standards*. A document saying "clause 1.8" is citing the repealed instrument even where it never names it |
| `Schedule 5`, `Schedule 6` | 2015 Standards schedules. Do not exist in the 2025 instruments |
| `AQTF` | Superseded by the 2015 Standards, which are themselves now repealed. Two generations stale |
| `VET Quality Framework` | Still used loosely in the sector; check whether the document uses it as a defined term with a 2015 meaning |
| `National Code 2007` | Superseded by the 2018 National Code |
| `TAE40110`, `TAE40116` | Not automatically wrong — both remain acceptable credentials. Flag for checking, not as a defect |
| `Standards for NVR Registered Training Organisations 2012` | Three generations stale |

A hit is a **flag, not a finding**. Some are quotations of history in a document
control table and are perfectly proper. Read the context before writing it up.

The absence of hits is not clearance either. A document written in 2019 that
cites nothing at all is still a 2015-era document; it just does not admit it.

## What the register must carry

Per document: name, type (`policy` / `procedure` / `form` / `template` /
`record` / `strategy` / `register`), version, date, owner, which entity or
entities it covers, its own stated review date, and whether that review date has
passed.

The review-date column earns its place immediately. A folder where a third of the
documents are past their own review date is a Standard 4.4 finding on its own,
visible before a single policy has been read.

## The missing list

Compare what exists against what the framework needs. The recurring absences,
roughly in order of how often they are missing:

- Validation schedule and validation records — the single most common Critical
  gap, and the one an assessor reaches for first
- Industry engagement records that show what *changed* as a result
- Trainer profile and currency matrix, current, per trainer, per product
- Continuous improvement register with closed loops rather than a list of
  observations
- Risk register that is reviewed rather than written once
- Student-at-risk identification and intervention records
- Third party arrangement register, and the written agreements behind it
- Agent performance monitoring, where the entity is CRICOS-registered
- Complaints and appeals register with dates against the timeframes
- Governance forum terms of reference, agendas and minutes

State each as *absent from what was supplied*, not as *absent*. The difference
matters and Phase 1 cannot tell them apart.

## Batch the questions

End Phase 1 with one block of questions, not a trickle. Typically:

1. Which documents are the current approved versions, where the folder holds more
   than one?
2. Which entity does each shared document actually apply to?
3. Is there a document management system, and is this folder an export of it?
4. What was **not** sent — records, registers, SMS or LMS extracts — because it
   was not thought relevant?
5. RTO and CRICOS codes, scope, cohorts, and shared services between the
   entities, where these are not already known.

Question 4 is the one that changes the engagement. Most of the evidence that
would raise a maturity rating above 2 lives in systems nobody thought to export.
