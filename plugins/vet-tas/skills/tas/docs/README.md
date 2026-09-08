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
| [SIT40521 Certificate IV in Kitchen Management](ACI-SIT40521.md) | Certificate IV | 30 | 33 | 10 | 5 | own TAS |
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
| [SIT40521 Certificate IV in Kitchen Management](MVC-SIT40521.md) | Certificate IV | 30 | 32 | 10 | 4 | own TAS |
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

Everything the registry found that someone has to decide or fix. Blocking items stop a build.

- **BLOCKING** &middot; **ACI-MSF30322** &mdash; BLOCKING FOR ANY BUILD - MSFGN2001 Make measurements and calculations is SUPERSEDED on training.gov.au. It sits in Cluster 2 as a core unit. Transition to the superseding unit before building or delivering against it.
- **BLOCKING** &middot; **ACI-MSF30322** &mdash; MSFGN2001 is SUPERSEDED on training.gov.au and is still listed as a delivered unit.
- Open &middot; **ACI-SITSS00069** &mdash; Neither unit carries a Core or Elective designation in the TAS table, because a skill set has no packaging rule of that kind. Both are recorded as Core.
- Open &middot; **ACI-SIT50422** &mdash; The TAS names the credit-transfer source as SIT40516 Certificate IV in Commercial Cookery. That qualification code is SUPERSEDED - the current code is SIT40521 Certificate IV in Kitchen Management, which is what ACI actually delivers. Correct the reference.
- Open &middot; **MVC-BSB80120** &mdash; The TAS types BSBHRM613 Contribute to the development of learning and development strategies as BSBHRM6153 - one digit too many, and no such unit exists on training.gov.au. Corrected on the way in and recorded in titleCorrections. A student training plan for this qualification carries the same table and marks only two units as Core where the packaging rule requires three; check the designations against the rule.
- Open &middot; **MVC-SIT40521** &mdash; The TAS states 33 units but its core-and-elective table lists 32. One unit is missing from the table. Reconcile before the next intake.
- Open &middot; **MVC-SIT50422** &mdash; The TAS unit table types SITXFIN010 as SITXFIN0010. Corrected against training.gov.au and recorded in titleCorrections.
- Open &middot; **ACI-CPC40120** &mdash; BSBESB401 Research and Develop Business Plans is listed in the unit table with no Core/Elective designation. Recorded as elective on the arithmetic - 14 core are designated and the TAS states 19 units - but confirm.
- Open &middot; **ACI-CPC40120** &mdash; THE TAS CARRIES THE WRONG DELIVERY PLAN, AND THE SEPTEMBER 2026 DOCX STILL DOES. Its Course Clustering Overview and Delivery Sequence sections were copied from the CPC20220 Certificate II strategy: they cluster and timetable CPCWHS1001, CPCCOM1012, CPCCOM1013, CPCCOM1015, CPCCCM2012, CPCCSP2002, CPCCSP2003, CPCCCO2013 and CPCCVE1011 - NINE units this qualification does not contain - plus one Diploma unit, CPCCBC5010. The registry sequences the course from the draft timetable instead, so builds are unblocked, but AN AUDITOR READING THE TAS FINDS A DELIVERY PLAN FOR A DIFFERENT QUALIFICATION. Rewrite that section.
- Open &middot; **ACI-MSF30322** &mdash; The assessment skill Resolve-BrandVariant maps CPC to the construction variant and throws on an unmapped package. MSF and MSM are unmapped, so an MSF unit cannot resolve a trading name. assets/providers.json records MSF and MSM as construction; the assessment skill needs the same mapping.
- Open &middot; **ACI-SIT30821** &mdash; IS THE NUMBERING A TEACHING ORDER OR A LISTING ORDER? The ACI strategy numbers its 25 units 1 to 25 with no grouping. Meridian delivers the identical 25 in the identical order but groups them into four themes, and within a theme the units are taught as a block rather than strictly one after another. Three rulings turn on the difference: this register owns equipment in SITHCCC023, cleaning chemicals in SITHKOP009 and dietary requirements in SITHCCC042, and each of those units is numbered AFTER a unit that applies the topic. Under Meridian theme grouping they are simultaneous and the rulings hold; read as a strict sequence they should flip. Confirm which the numbering means, then either group the units into blocks in the strategy or re-rule those three topics here.
- Open &middot; **ACI-CPC20220** &mdash; CPC20220 nationally packages 12 units (6 core + 6 elective). This TAS states and lists 10. Confirm against the RTO scope of registration before the next intake.

_Generated 2026-09-08 from the Training and Assessment Strategies named in each course record, and from training.gov.au._
