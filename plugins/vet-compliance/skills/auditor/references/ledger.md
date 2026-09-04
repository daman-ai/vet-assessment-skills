# The assurance ledger

**Every fact is written once, in `assurance.json`, and rendered many times.**

A compliance engagement produces nine deliverables that all describe the same
findings. Written separately they drift, and the place they drift is invisible:
a gap analysis rating Standard 1.5 as maturity 2, a roadmap with no validation
work in it, and a verification report that says every gap is addressed. All three
are internally consistent. Together they are a lie, and the person who finds it
is an assessor.

So the gap analysis, the roadmap, the risk register, the calendar, the indicator
set and the verification report are all **renders of one file**. They cannot
disagree, because there is only one of them.

`Resolve-AssuranceLedger.ps1` validates the ledger and derives what follows.
`Build-AuditPack.ps1` renders the deliverables. `Test-AuditPack.ps1` reads the
finished files back and checks them against the same ledger. Write the ledger;
never hand-edit a rendered deliverable.

## Shape

```json
{
  "engagement": {
    "name": "ACI and MVC compliance uplift",
    "runDate": "2026-09-04",
    "phase": 2,
    "preparedBy": "…",
    "notARegulatoryDetermination": true
  },

  "entities": [
    { "id": "ACI", "legalName": "Bush Tukka Pty Ltd", "tradingNames": ["Adelaide Culinary Institute", "Adelaide Construction Institute"],
      "rtoCode": "45797", "cricosCode": "03978F",
      "cohorts": ["domestic", "international"],
      "scope": ["SIT40521", "CPC30220"],
      "verifiedOn": "2026-09-04", "verifiedAgainst": "training.gov.au" }
  ],

  "documents": [
    { "id": "D001", "file": "Complaints and Appeals Policy v3.docx", "title": "Complaints and Appeals Policy",
      "type": "policy", "version": "3.0", "dated": "2021-06-30", "owner": "Compliance Manager",
      "entities": ["ACI", "MVC"], "reviewDue": "2023-06-30",
      "supersededRefs": ["clause 6.1", "Standards for RTOs 2015"],
      "sha256": "…" }
  ],

  "findings": [
    { "id": "F001", "requirement": "OS-1.5", "entity": "ACI",
      "outcomePlain": "Someone competent checks that assessment judgements are right, on a schedule, and the check leaves a record.",
      "documentsSay": [ { "document": "D004", "section": "5.2", "quote": "The RTO will validate assessment tools annually." } ],
      "gapType": "documented-not-operationalised",
      "maturity": 2,
      "maturityBasis": "document",
      "evidenceSeen": [],
      "evidenceNeeded": ["Validation records for 2025 and 2026", "Validation schedule", "Credentials of the validators"],
      "risk": "No evidence of validation for any product in the current registration period. On a performance assessment this reads as a systemic QA1 failure across the whole scope, not a single-product issue.",
      "priority": "Critical",
      "class": "MANDATORY",
      "citation": { "source": "OS2025", "ref": "Standard 1.5", "verified": true },
      "treatments": ["T003", "T004"] }
  ],

  "treatments": [
    { "id": "T003", "title": "Validation schedule covering every product on scope to June 2027",
      "addresses": ["F001"], "type": "system", "owner": "Compliance Manager",
      "due": "2026-10-31", "effort": "2 days", "deliverable": "05-templates/validation-schedule.xlsx" }
  ],

  "indicators": [
    { "id": "I001", "requirement": "OS-1.5", "name": "Validation coverage against schedule",
      "leading": true, "source": "Validation register",
      "formula": "products validated to date / products scheduled to date",
      "frequency": "monthly", "threshold": "< 90%", "escalation": "Compliance Manager to PEO" }
  ],

  "risks": [
    { "id": "R001", "entity": "ACI", "risk": "…", "cause": "…", "control": "…",
      "controlEffectiveness": "ineffective", "treatment": "T003",
      "owner": "PEO", "review": "2026-12-01" }
  ],

  "decisions": [
    { "id": "DEC01", "question": "Does MVC intend to keep CRICOS registration for the two dormant courses?",
      "whoDecides": "CEO", "why": "Automatic cancellation applies per provider; the dormant courses drive the 12-month clock and the remediation cost.",
      "blocks": ["T009"] }
  ],

  "assumptions": [
    { "id": "A01", "assumption": "The documents supplied are the current approved versions in use.",
      "ifWrong": "Every maturity rating below is unreliable, and the register must be rebuilt from the document management system." }
  ]
}
```

## Field rules the resolver enforces

**`requirement`** must be an id that exists in one of the requirement assets —
`OS-1.1`…`OS-4.4`, `CS-7`…`CS-20`, `CS-SCH1`, `CS-SCH2`, `NC-1`…`NC-11`,
`ESOS-AUTOCANCEL`, `ESOS-FREEZE`. A typo here silently orphans a finding from
its requirement and the coverage check passes with a hole in it.

**`maturity`** is 1–5 and **`maturityBasis`** is mandatory whenever maturity is
3 or above. The permitted bases are `record`, `sample`, `system` and `interview`.
`document` is **not** a permitted basis for 3+. This is the rule the whole method
rests on: a policy that says a thing happens is basis for maturity 2 and nothing
higher. The resolver rejects `maturity: 3, maturityBasis: "document"` rather than
warning about it, because a warning gets read once and ignored.

**`evidenceNeeded`** must be non-empty wherever maturity is 2 with basis
`document`. If you cannot say what evidence would raise the rating, you have not
finished thinking about the requirement.

**`gapType`** is one of `absent`, `superseded`, `documented-not-operationalised`,
`operational-no-evidence`, `below-good-practice`, `none`. `none` requires
maturity 4 or 5 — a requirement with no gap and maturity 2 is a contradiction.

**`treatments`** must be non-empty for every finding with priority `Critical` or
`High`. This is what makes the Phase 6 check that "every gap is addressed"
mechanical rather than a promise.

**`citation.verified`** is `false` unless you fetched the instrument this run.
Defaults to `false` when absent. Every unverified citation is listed in the
verification report.

**`class`** — `MANDATORY` requires a citation with a source id from
`sources.json`. `GOOD PRACTICE` must not carry one; a recommendation dressed in a
clause number is the failure `references/framework.md` describes.

## Building it up across phases

The ledger grows. It does not get rewritten.

| Phase | Adds | Gate |
|---|---|---|
| 1 | `engagement`, `entities`, `documents` | Every entity verified against the National Register. Every document has an owner or an explicit `"owner": "UNKNOWN"` |
| 2 | `findings` | Every requirement in scope has a finding. Maturity basis rules hold |
| 3 | `documents` gains the rewrites; `treatments` of type `document` | Every rewritten document traces to at least one finding |
| 4 | `indicators`, `treatments` of type `system` | Every Critical and High finding has a treatment |
| 5 | `risks`, roadmap dates on treatments | Every risk has an owner and a review date |
| 6 | `assumptions`, `decisions` | The full gate in `references/verification.md` |

Re-run `Resolve-AssuranceLedger.ps1` at the end of every phase. It costs seconds
and it catches the orphaned requirement id before it has been rendered into six
deliverables.

## Where the ledger lives

In the **working folder**, beside the documents being assessed — never in the
skills repository. It carries the RTO's own document names, findings about its
practice, and often staff names. `references/entities.md` covers what must not
be committed anywhere.
