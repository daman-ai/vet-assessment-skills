# Phase 2 — Gap and maturity analysis

One finding per requirement per entity. Written into `assurance.json`, rendered
to `01-gap-analysis.xlsx`.

## Start with the plain-English restatement

Before quoting anything, write `outcomePlain`: what the requirement is actually
chasing, in a sentence a trainer would understand.

Standard 1.5 says *the assessment system is quality assured by appropriately
skilled and credentialled persons through a regular process of validating
assessment practices and judgements.* The plain restatement is: **someone
competent checks that assessment judgements are right, on a schedule, and the
check leaves a record.**

Do this first because it is what everything else is measured against. It tells
you what evidence to look for, it tells the client what the finding means, and it
exposes the requirements you have not actually understood — those are the ones
where the restatement comes out as a paraphrase of the instrument's own words.

## The row

| Field | Rule |
|---|---|
| `requirement` | An id from the requirement assets. Never free text |
| `outcomePlain` | The restatement above |
| `documentsSay` | Document id, section, and a **verbatim quote**. Not a summary |
| `gapType` | One of the six below |
| `maturity` | 1–5 |
| `maturityBasis` | What the rating rests on. Mandatory at 3+ |
| `evidenceSeen` / `evidenceNeeded` | What you actually saw; what would move the rating |
| `risk` | Concrete consequence, in this entity's circumstances |
| `priority` | Critical / High / Medium / Watch |
| `class` | MANDATORY / GUIDANCE / GOOD PRACTICE |
| `citation` | Source id and reference, with `verified` true or false |

### Gap types

- `absent` — nothing in the supplied documents addresses it.
- `superseded` — addressed, but against the repealed instrument.
- `documented-not-operationalised` — the document says it happens; nothing shows
  it does.
- `operational-no-evidence` — it demonstrably happens, and leaves no record an
  assessor could inspect. **This is the most valuable finding type you produce**,
  because the RTO is doing the work and getting no credit for it, and the fix is
  cheap: change what the doing writes down.
- `below-good-practice` — compliant, and beneath what a decent provider does.
  Always `GOOD PRACTICE`, never `MANDATORY`.
- `none` — requires maturity 4 or 5.

### The maturity scale

| | Level | What it means | Basis required |
|---|---|---|---|
| 1 | Absent | Nothing | — |
| 2 | Documented only | It is written down | `document` |
| 3 | Implemented | It demonstrably happens | `record`, `sample`, `system` or `interview` |
| 4 | Monitored | It happens, and someone watches whether it keeps happening | `record` or `system` |
| 5 | Self-assuring | Drift is detected and corrected without anyone asking | `system` |

**A policy is basis for 2 and nothing higher.** The resolver rejects
`maturity: 3` with `maturityBasis: "document"`; it does not warn. Where you
cannot tell, rate 2, set `maturityBasis: "document"`, and fill `evidenceNeeded`
with what would settle it.

Most first engagements come back a sea of 2s. That is the correct result and it
is worth saying out loud to the client, because the instinct is to read it as
failure. It is not: it is the difference between what the documents claim and
what the engagement has been shown. Half of those 2s become 3s and 4s the moment
someone exports the registers.

Nothing reaches 5 in a first engagement. If you have written a 5, you have rated
a design rather than a practice.

## Risk, written concretely

"Non-compliance with Standard 1.5" is not a risk. It restates the finding.

A risk names the consequence in this entity's circumstances:

> No validation evidence exists for any product in the current registration
> period. On a performance assessment this reads as a systemic QA1 failure across
> the whole scope rather than a single-product issue, and systemic findings drive
> conditions on registration rather than a rectification period.

That is a sentence a PEO acts on. The first one is a sentence they file.

For a CRICOS entity, ask on every finding whether the ESOS consequence differs
from the VET one. It usually does, and it is usually worse, because the
consequences arrive faster and land on students who then have visa problems.

## Priority

- `Critical` — a live compliance failure with a consequence that is hard to
  reverse: registration conditions, automatic cancellation, systemic assessment
  invalidity, a cohort of students affected.
- `High` — a real failure that would be found and would be rectifiable.
- `Medium` — a genuine gap with a manageable consequence.
- `Watch` — sound today, and fragile: one person, one spreadsheet, one expiring
  credential.

Keep Critical scarce. A gap analysis with thirty Criticals has no priorities in
it, and the roadmap that comes out of it cannot be sequenced.

## Both entities, separately

Where the engagement covers two RTOs, findings are written **per entity**. One
row covering both is only correct where the document, the practice and the
evidence are genuinely shared — and where they are, that itself is a Standard 4.2
question about who is accountable for the shared function.

Shared services are where two-entity engagements go wrong. The same compliance
manager, the same SMS, the same validation panel: it looks efficient and it means
a single failure is a failure at both providers simultaneously. Note it in the
finding; carry it into the risk register as a concentration risk.

## Coverage

Every requirement in scope gets a finding, including the ones that are fine. A
gap analysis listing only problems cannot be used to demonstrate that the
organisation looked at everything — which is the Standard 4.4 evidence the
exercise is meant to generate.

`Resolve-AssuranceLedger.ps1` fails on any requirement with no finding. Scope is
declared per entity: an entity with no international cohort has the National Code
and ESOS requirements marked out of scope explicitly, with a reason, rather than
silently missing.
