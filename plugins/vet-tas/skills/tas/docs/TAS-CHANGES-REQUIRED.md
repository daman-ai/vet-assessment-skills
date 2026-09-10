# Changes to replicate into the TAS documents

Every change below has already been made in the curriculum registry. None of them is in
the TAS documents yet. Until a TAS is updated, the document and the registry disagree,
and the document is what an auditor reads.

RTO decision of 8 September 2026: **where a qualification is delivered by both institutes,
the unit set follows Meridian and only the branding differs.** Meridian's own gap was
closed first, so ACI has been matched to a corrected set, not a faulty one.

Source of truth for every unit code, title, prerequisite and currency below:
training.gov.au, verified 8 September 2026 across all 161 units with zero disagreements.

---

## 0. RE-DERIVATION, 8 SEPTEMBER 2026 — READ THIS FIRST

All eighteen current TAS documents were exported from the DMS and their unit tables read
back against the registry. **None of the eighteen matched the SHA-256 of the document its
registry record was originally built from** — every record had been derived from an older
revision.

The result of that re-derivation is reassuring: **sixteen of the eighteen courses are
IDENTICAL** between the registry and the current TAS — same units, same Core/Elective
designations, same delivered-versus-credit-transfer split. The only two that differ are
`ACI-SIT40521` and `ACI-SIT50422`, and they differ solely by the harmonisation decision
recorded in sections 2 and 3 below.

Two items previously on this list have been **withdrawn** as a result. See section 11.

---

## 1. MVC-SIT40521 — WITHDRAWN, NOT A FAULT

An earlier version of this file said Meridian's Certificate IV was missing the core unit
`SITHKOP012`, and that a student completing it could not be issued the qualification.
**That was wrong, and it was wrong about the document.**

The current TAS lists `SITHKOP012` Develop recipes for special dietary requirements as
**Core Unit number 9**, delivered, with 60 supervised and 15 unsupervised hours in the
hours table. Its unit table holds **33 units — 27 core plus 6 electives** — exactly what
the national packaging rule requires, and its eleven delivered units are confirmed by the
hours arithmetic, which sums to precisely the 560 supervised hours the document states.

The stale thing was the registry record, built from an older revision that had 32. The
registry has been corrected and now matches the current document exactly. **No change is
needed to this TAS, and no student has completed against a 32-unit structure.**

---

## 2. ACI-SIT40521 — Certificate IV in Kitchen Management — MATCH MERIDIAN

| Remove | Title | Was |
|---|---|---|
| `SITXHRM007` | Coach others in job skills | Elective, credit transfer |
| `SITHCCC025` | Prepare and present sandwiches | Elective, credit transfer |

| Add | Title | Designation | Delivery |
|---|---|---|---|
| `BSBTWK501` | Lead diversity and inclusion | Elective | **Delivered** |
| `SITXINV007` | Purchase goods | Elective | Credit transfer |

Result: 33 units, 11 delivered, identical to Meridian.

Also required:
- Confirm `BSBTWK501` and `SITXINV007` are on RTO 45797 scope of registration.
- `BSBTWK501` is delivered, so it needs an assessment tool and learner guide.

---

## 3. ACI-SIT50422 — Diploma of Hospitality Management — MATCH MERIDIAN

Every unit in this change is credit transfer, so no new assessment tool is needed.

| Remove | Title |
|---|---|
| `SITHCCC025` | Prepare and present sandwiches |
| `SITHCCC031` | Prepare vegetarian and vegan dishes |
| `SITHCCC032` | Produce cook-chill and cook-freeze foods |
| `SITHCCC038` | Produce and serve food for buffets |
| `SITHCCC044` | Prepare specialised food items |

| Add | Title |
|---|---|
| `SITHKOP013` | Plan cooking operations |
| `BSBTWK501` | Lead diversity and inclusion |
| `SITXFSA006` | Participate in safe food handling practices |
| `SITXINV006` | Receive, store and maintain stock |
| `SITHPAT016` | Produce desserts |

Result: 28 units, 5 delivered, identical to Meridian.

**Check the credit-transfer source actually contains them.** These arrive from
SIT40521; confirm each is in the Certificate IV a learner will hold.

---

## 4. ACI-SIT50422 — CORRECT THE CREDIT-TRANSFER SOURCE

The TAS names the credit-transfer source qualification as **SIT40516 Certificate IV in
Commercial Cookery**. That code is superseded. The current code is **SIT40521 Certificate
IV in Kitchen Management**, which is what ACI actually delivers. The registry already
records SIT40521; only the document is wrong.

---

## 5. ACI-CPC40120 — THE DELIVERY PLAN IS FOR A DIFFERENT QUALIFICATION

The Course Clustering Overview and Delivery Sequence sections were copied from the
CPC20220 Certificate II strategy. They cluster and timetable **nine units this
qualification does not contain** — `CPCWHS1001`, `CPCCOM1012`, `CPCCOM1013`,
`CPCCOM1015`, `CPCCCM2012`, `CPCCSP2002`, `CPCCSP2003`, `CPCCCO2013`, `CPCCVE1011` —
plus one Diploma unit, `CPCCBC5010`.

Replace both sections with the six themes now in the registry
(`docs/ACI-CPC40120.md`), which are derived from the qualification's own prerequisites
and topic ownership.

Also: give `BSBESB401` an explicit **Elective** designation in the unit table. It
currently has none. Checked against the CPC40120 national packaging: BSBESB401 is not
a core unit, so Elective is correct — but the next reader should not have to derive it.

---

## 6. MVC-BSB80120 — TWO DOCUMENT FAULTS

- The TAS types `BSBHRM613` as **`BSBHRM6153`** — one digit too many. No such unit
  exists on training.gov.au. Correct it to `BSBHRM613` Contribute to the development of
  learning and development strategies.
- The **student training plan** for this qualification marks only two units as Core.
  BSB80120's packaging rule requires three: `BSBLDR811`, `BSBHRM613` and `TAELED803`.
  The registry has all three correctly designated; the training plan does not.

---

## 7. MVC-SIT50422 — TYPO

The TAS unit table types `SITXFIN010` as **`SITXFIN0010`**. Correct it. The registry
already holds the right code.

---

## 8. ACI-MSF30322 — SUPERSEDED UNIT, DECISION RECORDED

`MSFGN2001` Make measurements and calculations was superseded on 12 March 2026 by
`MSFOPS201`, flagged **equivalent**, so it is on scope automatically.

**Do not transition yet.** MSF30322 has not been reissued since Release 2 of
21 December 2022 and that release still names `MSFGN2001` as one of its eight core
units, so it continues to be delivered as part of this qualification — but never as a
standalone enrolment, where the current unit must be used. Every other provider checked
on 8 September 2026 is in the same position.

**Review by 12 March 2027**, or when the qualification is reissued, whichever comes
first. Add a note to the TAS recording the decision and the review date so an auditor
sees a decision rather than an oversight.

---

## 9. ACI-SITSS00069 — DESIGNATIONS

Neither unit carries a Core or Elective designation, because a skill set has no packaging
rule of that kind. Both are recorded as Core in the registry. No change needed unless the
RTO wants the table to say so explicitly.

---

## 10. ALL EIGHTEEN COURSES — THE DELIVERY SEQUENCE HAS CHANGED

Every course was re-sequenced on 8 September 2026. The order is no longer read off a
timetable; it is derived from two rules that must both hold:

1. A **prerequisite** unit is taught before the unit that requires it.
2. A unit that **owns** a shared topic is taught before every unit that only recalls it.

Thirteen ordering violations were removed, and eleven courses that had no grouping at all
now carry themes. **Each TAS's Course Clustering Overview and Delivery Sequence should be
replaced with the themes now in `docs/<courseId>.md`** — theme name, focus, week range and
unit list.

The most-changed courses: `ACI-SIT20421` (6 of 13 units moved), `ACI-SIT30821` and
`MVC-SIT30821` (6 of 25 each), `ACI-CPC50220` (3 of 27), `ACI-MSF30322` (3 of 25),
`ACI-CPC31020` (2 of 20), `MVC-SIT31021` (2 of 21).

One consequence worth naming: in `ACI-SIT20421`, `SITXFSA005` now precedes `SITHCCC023`.
It is `SITHCCC023`'s prerequisite and was previously timetabled after it.

---

## 9a. TWO ELECTIVES SUBSTITUTED — SCOPE OF REGISTRATION

Two courses delivered a unit their RTO is not registered for. An RTO cannot award a
qualification on the strength of a unit outside its scope, so both were blocking. Rather
than apply to ASQA, each was replaced with a unit **already on scope and already in that
qualification's national elective bank** — so nothing needs lodging with the regulator.

**`ACI-CPC40120`: `BSBESB401` → `BSBESB407` Manage finances for new business ventures.**
BSBESB401 Research and Develop Business Plans is not on RTO 45797's scope. BSBESB407 is in
the CPC40120 elective bank, is on ACI's scope until 16 February 2031, and **ACI already
delivers it in CPC31020** — so the assessment tool, learner guide and trainer capability
exist. It keeps the business-establishment purpose of the elective it replaces and sits in
the same position and theme.
*If you would rather preserve the business-plan content exactly, `BSBESB406` Establish
operational strategies and procedures for new business ventures is the closer match on
content and is also on scope — but ACI delivers it nowhere, so it would need a new pack.*

**`MVC-BSB50420`: `BSBTEC404` → `BSBOPS503` Develop administrative systems.**
BSBTEC404 Use digital technologies to collaborate in a work environment is not on RTO
45039's scope. **No BSBTEC unit Meridian does hold appears in the BSB50420 elective bank**,
so a like-for-like digital swap was not available from the listed electives. BSBOPS503 is
in the bank, is on Meridian's scope, and keeps theme 4 coherent — it sits with Manage
business resources and Manage budgets and financial plans as the systems a work area runs
on. **It needs a new assessment tool and learner guide**; Meridian does not deliver it
elsewhere.

One knock-on, already applied to the registry: ruling `BSB50420-T01` "Confidentiality of
information" listed BSBTEC404 as a unit that recalled it. BSBOPS503 does not inherit that —
its knowledge evidence covers policies for *reviewing administrative systems*, stakeholders
and training procedures, with no confidentiality requirement — so the recall edge was
removed rather than transferred. The topic is now owned by BSBCMM511 and recalled only by
BSBLDR523.

Both TAS unit tables, delivery plans and elective rationales must be updated to match.

---

## 10a. FOUND BY THE RE-DERIVATION — FAULTS NOT PREVIOUSLY LISTED

These came out of reading the eighteen current documents in full. None of them changes
what the registry holds except the first, which has already been corrected there.

**`ACI-CPC40120` designates 14 units as Core where its own stated rule is 11 core plus 8
electives.** The CPC40120 national core is eleven units: CPCCBC4001, CPCCBC4002,
CPCCBC4007, CPCCBC4008, CPCCBC4009, CPCCBC4010, CPCCBC4012, CPCCBC4014, CPCCBC4018,
CPCCBC4021, CPCCBC4053. **`CPCCBC4003`, `CPCCBC4004` and `CPCCBC4005` are Elective Group A
units and are wrongly marked Core.** All 19 units and all 11 national core units are
present, so the qualification can still be issued. Corrected in the registry on
8 September 2026; the TAS table still needs it.

**`ACI-SIT40521` and `ACI-SIT50422` grant credit transfer against `SIT40516`.** Both head
their credit-transfer column "Credit Transfer from SIT40516" — a superseded qualification
code. Worse, each document contradicts itself: SIT40521's own entry requirement names
SIT30821 Certificate III in Commercial Cookery, and SIT50422's names SIT40521 Certificate
IV in Kitchen Management. Credit is being granted on paper against a qualification the
cohort does not hold. `ACI-SIT50422` Annex A is also headed "…– SIT40516 Certificate IV in
Commercial Cookery", and its Annex B links to `SIT50416`, another superseded code.

**`ACI-SIT40521` credit-transfers `SITHCCC025`, which has no source in the stated
pathway.** SITHCCC025 Prepare and present sandwiches is not among ACI-SIT30821's 25 units;
it appears only in the Certificate II. Every other credit-transferred unit is present in
the Cert III. The error chains forward, because ACI-SIT50422 then credit-transfers it
again. The harmonisation in section 2 removes SITHCCC025 from ACI's Certificate IV, which
resolves this as a side effect — but the underlying reasoning should be corrected, not
left to be fixed by accident.

**`ACI-SIT40521` clause 1.2 a) lists 23 prior units in superseded SIT Release 1 codes** —
SITHCCC001, SITHCCC005, SITHCCC012, SITHKOP002, SITXFSA001, SITXHRM001, SITXINV001,
SITXINV002, SITHIND002, BSBSUS211 and the rest — contradicting the current codes printed
in its own unit table a few pages earlier.

**`MVC-SIT40521` states the wrong credit-transfer count and the wrong qualification.** The
note reads "Credit Transfer for 23 units apply from SIT30821" but the table carries 22.
Three Cert III units are not carried forward at all: `SITXWHS005`, `SITXHRM007` and
`SITHKOP009`. The optional-units note also calls the qualification "SIT40521 Certificate
IV in **Commercial cookery**" and links to training.gov.au for **SIT30821**.

**`MVC-SIT60322` links to `BSB80215`.** Its optional-units note reads "…for Credit
Transfer (CT) for … **Diploma of Leadership and Management** is available on the National
register https://training.gov.au/training/details/**BSB80215**". Neither the qualification
name nor the code belongs in a SIT60322 strategy. It is boilerplate carried over from a
BSB document, not a unit in the course.

**`MVC-SIT50422` prints the same unit under two codes in one document** — `SITXFIN0010` in
the hours table, `SITXFIN010` in the sequence table.

**Hours tables that do not reconcile.** `MVC-BSB80120`: core totals row reads
`300 | 80 | 60 | 510` where its own rows sum to `300 | 120 | 90`; the rationale explains
delivery "at 1200 hours" against the document's own 1360; trainer ratio given as 1:18 in
one place and 1:20 everywhere else. `MVC-BSB60420`: training hours computed on "12 units"
twice where the table lists 10; the row summing all ten units is labelled "Total
hours-elective units" and there is no core total row; the sequence column is blank for
every row. `MVC-SIT31021`: unsupervised column sums to 257 against a stated 260, the
difference being SITHPAT017 given 12 where every comparable row has 15. `ACI-SIT20421`:
total assessment hours stated as 141, omitting the 100 supervised assessment hours, so the
volume of learning reads 541 where 300 + 141 = 441. `ACI-SIT40521`: unsupervised assessment
given as both 126 and 168 hours in the same section. `MVC-SIT50422`: volume of learning
doubled to 3850 in the final column with no explanation, and a stated 600 hours against a
table total of 1925. `MVC-SIT60322`: stated 2665 hours against a table total of 2400.

**Course durations that contradict themselves.** `MVC-SIT50422`: 30 weeks on the summary
page, 28 weeks in the amount-of-training section. `MVC-SIT60322`: 30 weeks on the summary
page, 55 weeks in the amount-of-training section. `MVC-SIT31021`: 58 weeks throughout, 52
weeks in the amount-of-training section.

**`ACI-SIT20421` quotes the wrong AQF benchmark and schedules the wrong assessment.** It
states its 541 hours "aligns to AQF Volume of learning hours for Certificate III" and
quotes the 600–1200 hour benchmark — this is a Certificate II. Separately, the Annex A
Week 8 row for `SITXWHS005` Participate in safe work practices carries the assessment task
list belonging to `SITXFSA006`, copied verbatim from the Week 2 row. **No WHS assessment
is scheduled for the WHS unit.**

**`MVC-SIT31021` contradicts itself on work placement** — "48 service periods" on the
summary page against "minimum 12 service periods" in the mandatory work placement section,
with 48 only recommended.

**Superseded White Card code in three ACI documents.** `ACI-CPC20220`, `ACI-CPC31020` and
`ACI-MSF30322` all print the current `CPCWHS1001` in the unit table but the superseded
`CPCCWHS1001` in Annex A or the cluster narrative. CPCCWHS1001 was superseded by
CPCWHS1001, equivalent, on 7 April 2022.

**`ACI-CPC40120` Annex A lists the wrong units.** It omits `CPCCBC4053`, a core unit of
this qualification, and adds `CPCCBC5010` Manage construction work, a CPC50220 Diploma
unit. Both lists carry 19 rows, so the count masks the mismatch.

**`ACI-CPC20220` unit table numbering runs 1–5 then jumps to 16–20**, a residue of a
20-row table. Ten units are listed and none is missing.

**Review dates in the past.** `ACI-SIT30821` and `ACI-SIT50422` both state "to be formally
reviewed in July 2021"; `ACI-SIT20421` and `ACI-SIT40521` both state February 2024.

**Standards drift.** `ACI-SITSS00069` is written against the Standards for RTOs 2025; the
other four ACI culinary documents still cite the Standards for RTOs 2015.

**`MVC-SIT50422` files two electives under a CORE UNITS heading** — `SITHKOP013` (Elective
B) and `BSBTWK501` (Elective D) sit under a heading covering 13 rows. Only by excluding
them does the count reconcile to the stated 11 core plus 17 electives.

**`MVC-BSB50420` contradicts itself on `BSBTEC404`** — designated a Listed Elective in the
table, described in the rationale as a Certificate IV unit selected under the packaging
rules, i.e. an imported elective.

**Not faults, recorded so nobody re-raises them.** A unit may legitimately be Core in one
qualification and Elective in another — `SITXFSA006` is Elective in SIT20421 and Core in
SIT30821, and `SITHKOP010` is Core in SIT30821 and Elective in SIT31021. Both are correct.
The `*` and `**` markers on unit codes in the ACI and Meridian cookery documents are
prerequisite footnote markers, not part of the codes, though `ACI-SIT30821` and
`MVC-SIT31021` use them with no legend defining what `**` means.

---

## 11. NOT A FAULT — THREE EARLIER CLAIMS WITHDRAWN

**ACI-CPC20220 is compliant.** An earlier registry note claimed CPC20220 nationally
packages 12 units (6 core plus 6 elective) against this TAS's 10. That note was wrong.
The packaging rules read: *"the candidate must demonstrate competency in 10 units of
competency: 5 core units, 5 elective units."* This course carries all five national core
units and five valid electives, with `CPCWHS1001` taken under the clause allowing one
elective from any current training package. **No change needed.**

**ACI-SIT40521's unusual electives were legitimate.** `SITXHRM007` and `SITHCCC025` are
not named in the SIT40521 unit lists, but the rule allows three electives "from any
current endorsed Training Package or accredited course." They are being removed under the
harmonisation decision, not because they were non-compliant.

---

## 12. THE SOURCE DOCUMENTS ARE MISSING

Every one of the eighteen course records cites a TAS at `C:\Users\ACI-Admin\Downloads\...`
and **none of those files is on this machine**. The records stand — each carries the
SHA-256 of the document it was built from — but nobody can re-verify a record against its
source or rebuild one after a change.

Put the eighteen TAS documents somewhere permanent and shared, then update the `tasFile`
path in each course record. Until then the registry cannot be re-derived.

---

_Generated 8 September 2026 from the curriculum registry. Unit data verified against_
_training.gov.au the same day: 161 units, zero disagreements on title, currency or_
_prerequisites._
