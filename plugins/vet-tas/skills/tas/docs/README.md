# Curriculum registry

Which institute delivers which qualification, which units each one carries, and which unit owns each shared topic so it is taught once.

**Generated. Do not edit.** Run `scripts/Build-TopicMap.ps1` after changing anything in `assets/`.

## Adelaide Construction Institute

RTO 45797 &middot; CRICOS 03978F &middot; Bush Tukka Pty Ltd

| Qualification | Level | Weeks | Units | Delivered | Topics | Record source |
|---|---|---:|---:|---:|---:|---|
| [CPC20220 Certificate II in Construction Pathways](ACI-CPC20220.md) | Certificate II | 26 | 10 | 10 | 6 | own TAS |
| [CPC31020 Certificate III in Solid Plastering](ACI-CPC31020.md) | Certificate III | 52 | 20 | 20 | 11 | own TAS |
| [CPC40120 Certificate IV in Building and Construction](ACI-CPC40120.md) | Certificate IV | 52 | 19 | 19 | 17 | own TAS |
| [CPC50220 Diploma of Building and Construction (Building)](ACI-CPC50220.md) | Diploma | 104 | 27 | 27 | 27 | own TAS |
| [MSF30322 Certificate III in Cabinet Making and Timber Technology](ACI-MSF30322.md) | Certificate III | 92 | 25 | 25 | 9 | own TAS |

## Adelaide Culinary Institute

RTO 45797 &middot; CRICOS 03978F &middot; Bush Tukka Pty Ltd

| Qualification | Level | Weeks | Units | Delivered | Topics | Record source |
|---|---|---:|---:|---:|---:|---|
| [SIT20421 Certificate II in Cookery](ACI-SIT20421.md) | Certificate II | 24 | 13 | 13 | 16 | own TAS |
| [SIT30821 Certificate III in Commercial Cookery](ACI-SIT30821.md) | Certificate III | 52 | 25 | 25 | 29 | own TAS |
| [SIT40521 Certificate IV in Kitchen Management](ACI-SIT40521.md) | Certificate IV | 30 | 33 | 11 | 5 | own TAS |
| [SIT50422 Diploma of Hospitality Management](ACI-SIT50422.md) | Diploma | 30 | 28 | 5 | 4 | own TAS |
| [SITSS00069 Food Safety Supervision Skill Set](ACI-SITSS00069.md) | Skill Set | 4 | 2 | 2 | 3 | own TAS |

## Meridian Vocational College

RTO 45039 &middot; CRICOS 03551M &middot; Golden Wattle Group Pty Ltd T/A Meridian Vocational College

| Qualification | Level | Weeks | Units | Delivered | Topics | Record source |
|---|---|---:|---:|---:|---:|---|
| [BSB50420 Diploma of Leadership and Management](MVC-BSB50420.md) | Diploma | 52 | 12 | 12 | 2 | own TAS |
| [BSB60420 Advanced Diploma of Leadership and Management](MVC-BSB60420.md) | Advanced Diploma | 52 | 10 | 10 | 0 | own TAS |
| [BSB80120 Graduate Diploma of Management (Learning)](MVC-BSB80120.md) | Graduate Diploma | 52 | 8 | 8 | 2 | own TAS |
| [SIT30821 Certificate III in Commercial Cookery](MVC-SIT30821.md) | Certificate III | 52 | 25 | 25 | 29 | own TAS |
| [SIT31021 Certificate III in Patisserie](MVC-SIT31021.md) | Certificate III | 58 | 21 | 21 | 25 | own TAS |
| [SIT40521 Certificate IV in Kitchen Management](MVC-SIT40521.md) | Certificate IV | 30 | 33 | 11 | 4 | own TAS |
| [SIT40721 Certificate IV in Patisserie](MVC-SIT40721.md) | Certificate IV | 30 | 32 | 13 | 0 | own TAS |
| [SIT50422 Diploma of Hospitality Management](MVC-SIT50422.md) | Diploma | 30 | 28 | 5 | 4 | own TAS |
| [SIT60322 Advanced Diploma of Hospitality Management](MVC-SIT60322.md) | Advanced Diploma | 30 | 33 | 7 | 2 | own TAS |

## Delivered by two institutes
These qualifications are on the prospectus of both an ACI institute and Meridian, and **each institute has its own Training and Assessment Strategy**. Comparing the two showed they are not interchangeable: for SIT40521 and SIT50422 the institutes select DIFFERENT ELECTIVES, and a different elective set changes which unit owns a shared topic. Each therefore holds its own register. SIT30821 is the exception - both select the identical 25 units in the identical order, and that was confirmed by comparison rather than assumed.


| Qualification | Register | Counterpart register |
|---|---|---|
| SIT30821 Certificate III in Commercial Cookery | [Adelaide Culinary Institute](ACI-SIT30821.md) | [Meridian Vocational College](MVC-SIT30821.md) |
| SIT40521 Certificate IV in Kitchen Management | [Adelaide Culinary Institute](ACI-SIT40521.md) | [Meridian Vocational College](MVC-SIT40521.md) |
| SIT50422 Diploma of Hospitality Management | [Adelaide Culinary Institute](ACI-SIT50422.md) | [Meridian Vocational College](MVC-SIT50422.md) |

## Open items

Everything the registry found that someone has to decide or fix. Blocking items stop a build. A watch is a decision already taken, carrying the date it must be revisited.

- **WATCH** &middot; **ACI-MSF30322** &mdash; WATCH, REVIEW BY 12 MARCH 2027 - MSFGN2001 Make measurements and calculations was superseded on training.gov.au on 12 March 2026 by MSFOPS201, which is flagged EQUIVALENT, so it is on scope automatically and no application is needed. It is NOT a blocker. MSF30322 has not been reissued since Release 2 of 21 December 2022 and that release still names MSFGN2001 as one of its eight core units, so it continues to be delivered as part of this qualification - but never as a standalone enrolment, where the current unit must be used. Every other provider checked on 8 September 2026 is in the same position. Build against MSFGN2001. Transition to MSFOPS201 when the qualification is reissued, or by the review date, whichever comes first - see the supersession block on the unit for the full ruling.
- Open &middot; **ACI-CPC20220** &mdash; CHECKED AND CLEARED, 8 SEPTEMBER 2026 - an earlier note claimed CPC20220 nationally packages 12 units (6 core plus 6 elective) against this TAS's 10. That is WRONG. The CPC20220 packaging rules read: 'the candidate must demonstrate competency in 10 units of competency: 5 core units, 5 elective units'. This course carries all 5 national core units (CPCCOM1012, CPCCOM1013, CPCCOM1015, CPCCVE1011, CPCCWHS2001) and 5 electives drawn from Group C (one unit, within the maximum of one) and Group I, with CPCWHS1001 taken under the clause allowing one elective from any current training package. Two groups are used, satisfying 'at least two but no more than four of groups A to I'. NO ACTION NEEDED.
- Open &middot; **ACI-CPC40120** &mdash; THE UNIT TABLE DESIGNATES 14 UNITS AS CORE where the document's own stated rule is 11 core plus 8 electives. Checked against the CPC40120 national packaging rules: the 11 core units are CPCCBC4001, CPCCBC4002, CPCCBC4007, CPCCBC4008, CPCCBC4009, CPCCBC4010, CPCCBC4012, CPCCBC4014, CPCCBC4018, CPCCBC4021 and CPCCBC4053. CPCCBC4003, CPCCBC4004 and CPCCBC4005 are Elective Group A units and are wrongly marked Core in the TAS. All 19 units and all 11 national core units are present, so the qualification can still be issued - but the designations are wrong in the document and were wrong here until 8 September 2026.
- Open &middot; **ACI-CPC40120** &mdash; CONFIRMED 8 SEPTEMBER 2026 - BSBESB401 carries no Core/Elective designation in the TAS unit table and was recorded as elective on the arithmetic. Checked against the CPC40120 national packaging rules: BSBESB401 is not among the core units, so ELECTIVE is correct. The TAS table should still be given the designation explicitly so the next reader does not have to derive it.
- Open &middot; **ACI-CPC40120** &mdash; SUBSTITUTED 8 SEPTEMBER 2026 - BSBESB401 replaced by BSBESB407. BSBESB401 Research and Develop Business Plans is not on RTO 45797 scope, so the qualification could not be awarded on it. BSBESB407 Manage finances for new business ventures is in the CPC40120 national elective bank, is on ACI scope until 16 February 2031, and ACI already delivers it in CPC31020 - so the assessment tools and trainer capability exist. It keeps the business-establishment purpose of the elective it replaces. The closest match on content would have been BSBESB406 Establish operational strategies and procedures for new business ventures, which is also on scope but which ACI does not yet deliver anywhere. THE TAS UNIT TABLE, THE DELIVERY PLAN AND THE ELECTIVE RATIONALE MUST BE UPDATED TO MATCH.
- Open &middot; **ACI-CPC40120** &mdash; THE TAS CARRIES THE WRONG DELIVERY PLAN, AND THE SEPTEMBER 2026 DOCX STILL DOES. Its Course Clustering Overview and Delivery Sequence sections were copied from the CPC20220 Certificate II strategy: they cluster and timetable CPCWHS1001, CPCCOM1012, CPCCOM1013, CPCCOM1015, CPCCCM2012, CPCCSP2002, CPCCSP2003, CPCCCO2013 and CPCCVE1011 - NINE units this qualification does not contain - plus one Diploma unit, CPCCBC5010. The registry sequences the course from the draft timetable instead, so builds are unblocked, but AN AUDITOR READING THE TAS FINDS A DELIVERY PLAN FOR A DIFFERENT QUALIFICATION. Rewrite that section.
- Open &middot; **ACI-MSF30322** &mdash; The assessment skill Resolve-BrandVariant maps CPC to the construction variant and throws on an unmapped package. MSF and MSM are unmapped, so an MSF unit cannot resolve a trading name. assets/providers.json records MSF and MSM as construction; the assessment skill needs the same mapping.
- Open &middot; **ACI-SIT30821** &mdash; CLOSED 8 SEPTEMBER 2026 - this register previously asked whether the ACI strategy's 1-to-25 numbering was a teaching order or a listing order, because three rulings turned on the answer. The question is now moot. The course is sequenced from its constraints rather than from the numbering: every prerequisite precedes the unit that needs it and every topic owner precedes the units that recall it, and ACI now carries the identical six themes as Meridian in the identical order. The three rulings were resolved on the units' knowledge evidence, not on the numbering.
- Open &middot; **ACI-SIT40521** &mdash; HARMONISED TO MERIDIAN, 8 SEPTEMBER 2026 - RTO DECISION: where a qualification is delivered by both institutes the unit set follows Meridian, and only the branding differs. This course dropped SITXHRM007 Coach others in job skills and SITHCCC025 Prepare and present sandwiches, and took on BSBTWK501 Lead diversity and inclusion (delivered) and SITXINV007 Purchase goods (credit transfer). CONFIRM BSBTWK501 AND SITXINV007 ARE ON RTO 45797 SCOPE OF REGISTRATION before the next intake, and correct the TAS unit table. BSBTWK501 is delivered, so it needs an assessment tool and learner guide.
- Open &middot; **ACI-SIT50422** &mdash; The TAS names the credit-transfer source as SIT40516 Certificate IV in Commercial Cookery. That qualification code is SUPERSEDED - the current code is SIT40521 Certificate IV in Kitchen Management, which is what ACI actually delivers. Correct the reference.
- Open &middot; **ACI-SIT50422** &mdash; HARMONISED TO MERIDIAN, 8 SEPTEMBER 2026 - RTO DECISION: the unit set follows Meridian. This course dropped SITHCCC025, SITHCCC031, SITHCCC032, SITHCCC038 and SITHCCC044, and took on SITHKOP013, BSBTWK501, SITXFSA006, SITXINV006 and SITHPAT016, all as credit transfer. Every one of them is credit-transferred rather than taught, so no new assessment tool is needed, but THE TAS UNIT TABLE MUST BE CORRECTED and the credit-transfer source qualification must actually contain them.
- Open &middot; **ACI-SITSS00069** &mdash; Neither unit carries a Core or Elective designation in the TAS table, because a skill set has no packaging rule of that kind. Both are recorded as Core.
- Open &middot; **MVC-BSB50420** &mdash; SUBSTITUTED 8 SEPTEMBER 2026 - BSBTEC404 replaced by BSBOPS503. BSBTEC404 Use digital technologies to collaborate in a work environment is not on RTO 45039 scope, so the qualification could not be awarded on it. None of the BSBTEC units Meridian does hold appears in the BSB50420 elective bank, so a like-for-like digital swap was not available from the listed electives. BSBOPS503 Develop administrative systems is in the bank, is on Meridian scope, and keeps the theme coherent: it sits with Manage business resources and Manage budgets and financial plans as the systems a work area runs on. It needs a new assessment tool and learner guide - Meridian does not deliver it elsewhere. THE TAS UNIT TABLE, THE DELIVERY PLAN AND THE ELECTIVE RATIONALE MUST BE UPDATED TO MATCH.
- Open &middot; **MVC-BSB80120** &mdash; CHECKED 8 SEPTEMBER 2026 - the registry holds all three BSB80120 national core units (BSBLDR811, BSBHRM613, TAELED803) correctly designated Core, so the DATA is right and the DOCUMENTS are not. Two things to correct outside the registry: the TAS types BSBHRM613 as BSBHRM6153, one digit too many and no such unit exists on training.gov.au; and the student training plan for this qualification marks only two units as Core where the packaging rule requires three.
- Open &middot; **MVC-SIT40521** &mdash; RESOLVED 8 SEPTEMBER 2026 - SITHKOP012 Develop recipes for special dietary requirements has been ADDED as a delivered core unit. The TAS stated 33 units (27 core plus 6 electives) but its unit table listed only 32, being 26 core plus 6 electives: the electives were complete and exactly one core unit was missing from the table. Cross-checking the table against the 27 core units in the SIT40521 national packaging rules identified the missing unit as SITHKOP012. It is not in SIT30821, so it cannot arrive by credit transfer and must be DELIVERED - this course now delivers 11 units, not 10. THE TAS UNIT TABLE MUST BE CORRECTED TO MATCH, and an assessment tool and learner guide for SITHKOP012 do not yet exist.
- Open &middot; **MVC-SIT40721** &mdash; @{severity=WATCH; item=Course duration of 30 weeks is assumed, not confirmed against PRISMS.; raised=2026-09-09}
- Open &middot; **MVC-SIT40721** &mdash; @{severity=WATCH; item=Topic ownership rulings have not been derived for this course, so the teach-once rule is not yet enforced on it.; raised=2026-09-09}
- Open &middot; **MVC-SIT40721** &mdash; @{severity=BLOCKING; item=SITHPAT018, SITHPAT019 and SITHPAT020 are delivered but have no assessment tool or learner guide.; raised=2026-09-09}
- Open &middot; **MVC-SIT50422** &mdash; The TAS unit table types SITXFIN010 as SITXFIN0010. Corrected against training.gov.au and recorded in titleCorrections.

_Generated 2026-09-09 from the Training and Assessment Strategies named in each course record, and from training.gov.au._
