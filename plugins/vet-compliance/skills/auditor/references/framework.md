# The framework, and how to cite it

Everything this skill asserts about the law traces to `assets/sources.json`. If a
claim cannot be traced to a row there, it is not a requirement — it is an
opinion, and it is labelled `GOOD PRACTICE`.

## What was verified, and when

| Component | Instrument | Register ID | Structure verified |
|---|---|---|---|
| Outcome Standards | Outcome Standards for NVR RTOs Instrument 2025 | `F2025L00354` | **Yes** — every Standard 1.1–4.4, verbatim, 4 Sep 2026 |
| Compliance Requirements | Compliance Standards for NVR RTOs and Fit and Proper Person Requirements Instrument 2025 | `F2025L00355` | **Yes** — clauses 7–20, Schedules 1–3, 4 Sep 2026 |
| Credential Policy | Credential Policy, Standards for RTOs | — | **No** — clause numbering not verified |
| National Code | National Code of Practice 2018 | `F2017L01182` | **Titles only** — Standards 1–11. Sub-clauses not verified |
| ESOS Act | ESOS Act 2000, as amended by the Education Legislation Amendment (Integrity and Other Measures) Act 2025 (assent 4 Dec 2025) | — | **No** — section numbering not verified |

The three components of the 2025 Standards are the Outcome Standards, the
Compliance Requirements and the Credential Policy. Schedule 3 of `F2025L00355`
**repeals the 2015 Standards in full**. That is the single most useful fact in
this file, because it means every clause reference in the RTO's existing
documents is a reference to a repealed instrument.

## The three labels

Every statement in every deliverable carries one:

- `MANDATORY` — traceable to an instrument, with the clause quoted.
- `GUIDANCE` — the regulator's published view. ASQA Practice Guides live here.
  Useful, persuasive, and **not law**. An RTO can depart from guidance and still
  be compliant; it cannot depart from the instrument.
- `GOOD PRACTICE` — your recommendation. Say so plainly. It is often the most
  valuable thing on the page, and mislabelling it as mandatory destroys the
  credibility of everything labelled mandatory.

The commonest failure in RTO compliance writing is a Practice Guide sentence
presented as a legal requirement. It survives until an assessor asks which
clause requires it, and then the whole document is suspect.

## Outcome standards change what a finding is

The 2015 Standards were input standards: they told an RTO what to have. The 2025
Standards are outcome standards: they say what must be true. Standard 1.1 is one
sentence — *training is engaging, well-structured and enables VET students to
attain skills and knowledge consistent with the training product.* There is no
sub-clause telling you what to file.

Two consequences, and both change how you work:

1. **You cannot close a gap with a document.** A policy asserting that training
   is engaging is evidence of nothing. What closes Standard 1.1 is a body of
   practice and the record it leaves — session plans, student feedback,
   completion and withdrawal patterns, trainer observation.
2. **You cannot audit by checklist.** There is no clause list to tick. So the
   gap analysis works from the outcome statement, in plain language, to what an
   assessor would see happening and see recorded. That is the whole method, and
   it is why `references/gap-analysis.md` insists on the plain-English restatement
   before anything else.

The corollary is comforting: the RTO has more room to design its own system than
it had under the 2015 Standards, provided it can show the outcome is achieved.
Say that to the client. Outcome standards frighten people who expect a checklist.

## Citing without fetching is the failure mode

Three components have verified structure. Three do not.

For anything in the unverified group — the Credential Policy, the National Code
sub-clauses, ESOS Act sections — **fetch before citing**. The National Code asset
carries `workingKnowledge` text for each of the eleven Standards. That text is
there so you know what to look for. It is not a citation and must never be
quoted as one.

A citation you could not verify goes into the finding as
`"citation": { ..., "verified": false }`, and the gate lists every one of them in
the verification report. That is the honest outcome, and it is a far better
result than a clause number that turns out to be from the repealed instrument.

## Live watch items

Two things are running right now and both are dated.

**Automatic CRICOS cancellation.** From 1 January 2026, a provider other than an
approved school provider that delivers to no overseas student for 12 consecutive
months has its CRICOS registration cancelled — automatically, under the Act, not
by a regulator decision anyone can be talked out of. It is the only obligation in
the framework that ends a business without a finding, an audit or a warning
letter first.

So it is measured, not remembered: **days since the last overseas-student
delivery day, per registered course, per registered location**, on the monthly
pulse, escalating at nine months. A dormant course on scope at a location nobody
has taught at is the exposure. Providers rarely know they have one.

**CRICOS application freeze, 19 May 2026 to 19 May 2027.** No new CRICOS
registrations and no new course additions for private VET and ELICOS providers.
This is not a compliance obligation and must not appear as a gap. It is a
planning constraint, and it belongs in the risk register: any growth plan
assuming a new CRICOS course before 19 May 2027 is not deliverable, and the work
to have an application ready for 20 May 2027 has to start well inside the freeze.

## Re-verification

Anything in `sources.json` whose `checkedOn` is more than 90 days old is stale.
Re-fetch it, update `checkedOn`, and note the date checked in the deliverable.
International education settings have moved substantially in each of the last
three years; the assumption that nothing changed since the last engagement has
been wrong every time.
