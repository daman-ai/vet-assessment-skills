# Phase 3 — Uplifting documents

Rewrite policies and procedures as **working documents for staff**, not as audit
artefacts. The test is whether a new trainer could follow it on their second day
without asking anyone. A document that reads well to an auditor and cannot be
followed by staff is the exact failure the 2025 Standards were written to catch:
it produces a perfect policy and no outcome.

## Policy and procedure are different documents

Most RTO documents are a policy and a procedure glued together, and the join is
where the operational detail goes missing.

- A **policy** says what the organisation does and why, who owns it, and what
  principles bind it. Two to four pages. It changes rarely.
- A **procedure** says who does what, when, in what order, and what it writes
  down. It changes whenever the system changes.

Split them where the source document has both. It halves the review burden — the
procedure changes when the SMS changes, and the policy does not have to go back
to the board for it.

## Every procedure step answers six questions

**Who · When triggered · What steps · What record it creates · Where that record
is stored · Who verifies it happened.**

Miss the fifth and the record exists and cannot be found in an audit. Miss the
sixth and the procedure is a hope.

Write the trigger as an event, not a period. "Quarterly" is not a trigger;
"within 5 working days of the student's second missed assessment" is. Period-based
steps are the ones that quietly stop happening, because nothing in the day-to-day
work reminds anyone.

## Writing rules

**Named roles, never "the RTO".** "The RTO will ensure" is the passive voice
wearing a hat: nobody named, nothing verifiable. Write "the Compliance Manager".
Where the role does not exist, that is a Standard 4.2 finding — surface it rather
than writing around it.

**Plain English, active voice.** Short sentences. The reader is a trainer between
classes, not a lawyer.

**Numbers, not adjectives.** "Promptly" is unauditable and unfollowable. "Within
10 business days" is both. Every timeframe in the document is a number, and every
number that comes from an instrument carries its citation in the mapping table.

**Compliance mapping goes at the end, in a table.** Clause references sprinkled
through the body make a document nobody reads. One table at the end maps each
section to the requirements it satisfies. This also makes the next review
tractable: when an instrument changes, you read the table, not the document.

**Say where the entities differ.** Where ACI and MVC need different content —
different scope, different cohorts, one CRICOS-registered and one not — write it
explicitly. A single document that half-fits both entities is worse than two
documents, because staff at each entity have to work out which half is theirs and
they will get it wrong in the direction of doing less.

## Document control

Every rewritten document carries: version, effective date, review date, approver
and role, and a change history. The review date is a real date, and it goes into
the compliance calendar as `REC-POLICY`. A document with no review date cannot be
evidence for Standard 4.4, because nothing shows the organisation intended to
look at it again.

## What must not happen

**Do not write a policy that asserts a practice you have no evidence is
happening.** This is the cardinal rule of Phase 3 and it is broken constantly,
usually with good intentions: the gap was "no validation happening", so the
rewrite says validation happens quarterly, and the gap is closed on paper. It is
not closed. It is now a written commitment the RTO is visibly failing, which is a
materially worse position than the honest absence — an assessor who finds a
policy promising quarterly validation and no validation records has evidence of a
governance failure, not a documentation gap.

Where a document describes something aspirational, mark it plainly:

> *This procedure takes effect from 1 November 2026. The validation schedule it
> refers to is at `05-templates/validation-schedule.xlsx` and has not yet run a
> full cycle.*

Then put the implementation in the roadmap as a treatment with an owner and a
date. The document and the treatment are two halves of one fix, and the ledger
links them.

## Change summary

One `CHANGE-SUMMARY.md` for all rewritten documents. Per document: what changed,
why, and which finding drove it — `F001`, not "compliance". The finding id is
what makes Phase 6's coverage check mechanical.

Include what was **deliberately not changed**. A reviewer who sees a document
untouched cannot tell whether it was examined and found sound, or missed.

## Where the RTO has its own template

If the RTO supplies a document template — its letterhead, its styles, its
document-control block — build by **editing that template**, never by rebuilding
it. This repository's other skills exist largely to enforce that rule, and the
reason is the same here: a rebuilt document loses the headers, footers, numbering
and approval block that make it recognisable as the RTO's own, and staff treat an
unfamiliar-looking document as a draft.

For the mechanics, `anthropic-skills:docx` handles Word documents. Keep the
template's parts intact and change only the body.
