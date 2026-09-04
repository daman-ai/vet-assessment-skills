# Phase 6 — Verify

Phase 6 is a gate, not a promise. Run it, report what it found, and report what
it could not settle.

```powershell
.\scripts\Test-AuditPack.ps1 -Ledger assurance.json -Out .\deliverables
```

## What the gate checks

| Check | Fails when |
|---|---|
| `RequirementIdsResolve` | A finding, indicator or treatment names a requirement id that is not in the assets |
| `CoverageComplete` | A requirement in scope for an entity has no finding, and no explicit out-of-scope reason |
| `MaturityBasis` | Maturity ≥ 3 with basis `document`, or missing basis |
| `EvidenceNeeded` | Maturity 2 on basis `document` with nothing in `evidenceNeeded` |
| `GapTypeConsistent` | `gapType: none` with maturity below 4, or a gap type with maturity 5 |
| `TreatmentCoverage` | A Critical or High finding with no treatment |
| `TreatmentsOwned` | A treatment with no owner or no due date |
| `RisksReviewed` | A risk with no owner or no review date |
| `CitationClass` | `MANDATORY` with no citation, or `GOOD PRACTICE` carrying one |
| `SourcesFresh` | A source in `sources.json` whose `checkedOn` is more than 90 days before the run date |
| `NoFabricatedClauses` | A citation reference that does not match the shape the named source uses |
| `DeliverablesRendered` | A deliverable listed for the phase is missing from the output folder |
| `DisclaimerPresent` | A rendered deliverable with no not-a-regulatory-determination statement |
| `NoPersonalData` | A student identifier pattern, a USI-shaped string, or a named individual in a finding |

Failures block. Warnings are reported and do not block; the only warnings are
`SourcesFresh` and unverified citations.

## What the gate cannot check, and you must

**Re-check every citation against the actual instrument.** The gate checks shape,
not truth: it can tell that `Standard 1.5` looks like an Outcome Standards
reference, and it cannot tell whether Standard 1.5 says what the finding claims.
Fetch the instrument. Where a clause cannot be verified, set
`citation.verified: false` and say so in the report — that is a better outcome
than a plausible number.

Every unverified citation is listed by id in `08-verification-report.md`. A
report with none is either excellent or dishonest, and the reviewer cannot tell
which, so state how many were checked and against what.

**Adversarially review the rewritten documents.** Read each one as an assessor
looking for a reason to doubt it:

- Where does the document claim a practice with no evidence behind it? Phase 3's
  cardinal rule, checked from the other side.
- Where is a timeframe stated that the organisation has never met?
- Where does a named role not exist, or hold three other named roles?
- Where does a procedure produce a record with nowhere to store it?
- Where would a trainer, following this on their second day, stop and ask
  someone?

**Confirm every Phase 2 gap is addressed in Phases 3–5, and list any that are
not.** `TreatmentCoverage` does this mechanically for Critical and High. Read
Medium and Watch yourself. A deliberately deferred gap is a legitimate outcome —
say it is deferred, say why, and give it a review date. An accidentally dropped
gap is not.

## Assumptions and open questions

Every assumption, with what breaks if it is wrong. The one that is always there:

> **A01** — The documents supplied are the current approved versions in use.
> If wrong, every maturity rating is unreliable and the register must be rebuilt
> from the document management system.

Then the open questions, batched, addressed to a named person, each saying what
it would change. A question with no consequence attached does not get answered.

## The disclaimer

Every deliverable carries it, in these words or close to them:

> This is internal working material. It is not a regulatory determination, it is
> not legal advice, and it does not bind the regulator. Requirements are cited to
> the instruments named in the source register, checked on the date shown.

Not a formality. The deliverables read like determinations — they use the
regulator's language and cite its instruments — and they will be circulated to
people who did not commission them.

## Not-fabricating, restated

The rule that everything else rests on: **if a document, record or system does
not exist, say it does not exist.**

The pressure runs the other way at every stage. The client wants to hear the gap
is smaller than it is. The rewritten policy is easier to write if you assume the
practice happens. The maturity rating is more comfortable at 3. Every one of
those is a small, reasonable-feeling step, and the destination is a compliance
pack that reads well and describes an organisation that does not exist — which is
exactly what a performance assessment is designed to find, and it will be found
against documents carrying your fingerprints.
