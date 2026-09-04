# Entities, onboarding, and what must never be committed

## The two this skill was built for

**ACI** — Bush Tukka Pty Ltd, RTO `45797`, CRICOS `03978F`. One RTO trading under
two names: **Adelaide Culinary Institute** for `SIT` cookery, hospitality and
patisserie delivery, **Adelaide Construction Institute** for `CPC` construction,
plumbing and building delivery. Both names, one registration, one set of
compliance obligations. A compliance document covering "ACI" covers both trading
names, and any document that names only one of them will be read by staff at the
other as not applying to them.

**MVC** — Meridian Vocational College. RTO code, CRICOS code, scope and cohorts
are **not recorded here**. Ask, then verify.

Both are carried in this repository's other skills as delivery brands. The codes
above come from the `assessment` skill's brand profile — treat them as the
client's own datum, and confirm against the National Register at Phase 1 anyway.

## Verify codes, do not accept them

At Phase 1, for each entity, confirm against training.gov.au:

- The RTO code resolves to the legal entity the client named
- The scope of registration — what is actually on it, which is regularly not what
  the client believes is on it
- The registration period and expiry date, which sets the renewal window
- CRICOS registration, courses and **registered locations**

The scope check earns its keep every time. A qualification the RTO believes it
delivers and is not on scope is a `CS-7` marketing breach the moment it appears
on the website, and a certification integrity problem the moment anything is
issued against it. A qualification on scope that nobody delivers is a dormant
product, and where it is CRICOS-registered it is running the automatic
cancellation clock.

Record `verifiedOn` and `verifiedAgainst` in the ledger's `entities` block. The
gate does not check this — a reviewer does.

## Onboarding a new RTO

Ask for all of this in one block:

1. Legal entity name, trading names, RTO code, CRICOS code
2. Scope of registration, and which products are actually delivered
3. Cohorts — domestic, international, or both — per product
4. Registered delivery locations, and which are actually used
5. Shared services with any related entity: staff, SMS, LMS, campus, PEO,
   compliance function, validation panel
6. Funding contracts: state training authority, VET Student Loans, skills
   agreements
7. Third party arrangements and education agents
8. Whether any student is under 18
9. The document management system, and whether the supplied folder is an export
   of it
10. The governing body, how often it meets, and whether compliance is a standing
    agenda item

Items 5 and 10 are the ones that change the shape of the engagement. Shared
services turn two independent assessments into one correlated one. A governing
body with no standing compliance item makes Standard 4.4 a design problem rather
than an evidence problem.

## Two entities, one engagement

Findings are written per entity (`references/gap-analysis.md`). Documents are
registered against the entity or entities they cover. The RACI spans both.

The recurring trap: a shared document that is compliant for one entity and not
the other. A complaints policy with no external appeal pathway is fine for a
domestic-only RTO and a National Code Standard 10 failure for a CRICOS provider
using the same document. Where one entity is CRICOS-registered and the other is
not, read every shared document twice.

## What must never be committed

This skill's outputs describe an organisation's compliance failures in detail and
often name staff. The working folder does not belong in any repository, and this
one has `.gitignore` patterns as a backstop, not as permission.

Never commit:

- Student records, enrolment data, CoE or PRISMS extracts, anything with a USI
- Staff personal information, trainer qualification certificates, background
  check results
- Complaints and appeals records naming individuals
- Agent commercial agreements and other commercially sensitive contracts
- Correspondence with ASQA or any regulator
- `assurance.json` itself, and any rendered deliverable

The gate's `NoPersonalData` check looks for identifier patterns and named
individuals inside findings, because a finding is where they leak: it is natural
to write *"the intervention record for [student] shows no follow-up"* and it puts
a student's name into a document that will be emailed around a management team.
Write the case, not the person.

Findings name **roles**. Where an individual's conduct is genuinely the finding —
a governing person's fit-and-proper matter, for example — that is a decision item
for the client and legal advice, handled outside the pack.
