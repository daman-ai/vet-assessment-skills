---
name: tas
description: The curriculum registry for Meridian Vocational College, Adelaide Culinary Institute and Adelaide Construction Institute - which institute delivers which qualification, which units each course carries, how they are sequenced, and WHICH UNIT OWNS EACH SHARED TOPIC so the same concept is taught once rather than in every unit that mentions it. Sources units live from training.gov.au, reads the delivered unit list from each course's Training and Assessment Strategy, detects where two units in one course cover the same ground, and records an authored ruling on who owns it. Read by the assessment and learner-guide skills before they build anything. Use when asked what units a qualification has, which institute runs a course, what a unit should and should not teach, where a topic is covered, whether a unit is superseded, or to add a course to the registry.
---

# Curriculum registry

## What problem this solves

Twelve of the twenty-five units in SIT30821 carry a knowledge-evidence point that reads *contents of date codes and rotation labels for stock*. Fifteen carry *safe operational practices using essential functions and features of equipment*, changing only the dish it names. Built one unit at a time, each learner guide explains stock rotation from scratch and each assessment tool asks about it again - so a learner meets the same paragraph twelve times, and an auditor finds twelve differently-worded benchmarks for one requirement.

The `assessment` skill already runs an assess-once register, but only INSIDE one unit, and it fills the cross-unit part by asking the user which sibling tools overlap. Nobody remembers, so the answer is usually "none", and the duplication ships.

This registry is the memory that was missing. It records, per course, which unit OWNS each shared topic. Everything else applies it.

**It solves the two halves differently, and the difference is deliberate.** On the teaching side it removes the repetition outright: the owner explains it once, every later unit recalls and applies it. On the assessment side it removes nothing, because **assessment is per unit** - each unit is separately certified and must evidence its own requirements in full. What it removes there is the *inconsistency*: one owner benchmark instead of twelve, and a later unit assessing the topic applied inside its own subject rather than re-asking the owner's question. Twelve differently-worded benchmarks for one requirement is the defect; twelve tools covering the requirement is the law.

## Read this before building anything

```powershell
scripts\Get-UnitBrief.ps1 -Unit SITHCCC035 -CourseId MVC-SIT30821
```

It returns the provider and trading name, the unit's place in the delivery sequence, its prerequisites, **what this unit teaches in full**, **what it must not re-teach because a sibling owns it**, what the learner already holds by credit transfer, and any blocker that should stop the build.

**Name the course.** `SITXFSA005` sits in five of these courses. In SIT30821 it owns the organisational hygiene procedures outright; in SIT50422 it is credit-transferred and is not taught at all. The script refuses to guess and lists the candidates.

Add `-Json` for a machine-readable brief.

## What is in the registry

| Path | What it holds |
|---|---|
| `assets/providers.json` | The two RTOs, the three trading names, and how an ACI unit resolves to Culinary or Construction |
| `assets/courses/<courseId>.json` | One per course: units, core/elective, delivered against credit-transfer, clusters or themes, prerequisites, currency, source TAS and its hash, open items |
| `assets/units/<CODE>.json` | 135 units harvested from training.gov.au - elements, performance criteria, performance evidence, knowledge evidence, assessment conditions, prerequisites, currency |
| `assets/topics/<courseId>.topics.json` | **The rulings.** One owner per topic, the units that apply it, the teaching rule, and the training.gov.au text it is anchored to |
| `assets/topics/families/` | The detected overlaps, before anybody ruled on them |
| `assets/topics/decisions/` | The authored rulings, in the form a human edits |
| `docs/` | The same thing as Markdown, for people. Generated - never edit it |

A course id is `<PROVIDER>-<QUALIFICATION>`: `MVC-SIT30821`, `ACI-CPC31020`. **Provider and qualification together**, because ACI and MVC select different electives for the same national code and their topic maps differ.

## The four kinds of topic

The distinction decides whether consolidating is a saving or an amputation.

| Kind | Meaning | What a later unit TEACHES | How it ASSESSES |
|---|---|---|---|
| `shared-scaffold` | One generic concept several units restate. **This is the duplication.** | Restate briefly, prompt a recall, then what is specific to it | `applied` |
| `commodity-parallel` | Same *structure*, different subject - cookery methods for poultry against for seafood | **Teaches its own commodity in full.** Never collapse these | `full` |
| `progressive-depth` | Introduced at one level, deepened later | Teaches only the delta, and says what the delta is | `applied`, at this unit's level |
| `regulatory-recall` | Legislation, codes, standards | Names the clause that governs it, recalls the frame | `applied` - and the owner's benchmark matters most here |

**The assess column is depth and form, never coverage.** Every one of these is still evidenced in full in the later unit's own tool.

**A requirement that appears in only one unit is not in the register at all.** It overlapped nothing, so no ruling was needed, and that unit teaches it in full.

## How a build uses the brief

**Learner guide.** Write the `teachInFull` topics properly. For each `doNotReTeach` topic, follow its `teachingRule`, which has three parts and needs all three: a **short restatement** that stands on its own, a **retrieval prompt** the learner answers, then the **delta** taught in full. Never a second full explanation - and never a bare cross-reference, which is worse than a re-teach, because the learner who has forgotten it finds nothing on the page.

The word floors do not shrink for a `doNotReTeach` topic, they **redirect**: the 800 words go to the delta and its worked application, not to re-explaining the base.

**Assessment tool. ASSESSMENT IS PER UNIT AND COVERAGE IS NEVER REDUCED.** Every unit is separately certified - a learner can be issued a Statement of Attainment for one unit alone - so that unit's tool evidences **every one of its own requirements**, `doNotReTeach` topics included, each on its own mapped line. **No assess-once register line may name another unit as its evidence.** A ruling never deletes a question; it is not a coverage exemption.

What a ruling governs is **depth, form and benchmark**:

- **Depth** - `assessmentDepth: applied` means assessed inside a question about *this* unit's own subject rather than as a standalone recall question. `full` (the `commodity-parallel` default) means this unit's own subject matter, assessed in full.
- **Form** - where an observation item already evidences it, it is not also asked in writing. That is the within-unit assess-once rule, and with per-unit assessment it is the main compression lever, alongside one question carrying several requirements.
- **Benchmark** - use `ownerBenchmark` as the anchor. Twelve units carrying one requirement must not produce twelve differently-worded standards. Consistency of assessment judgement is what Standard 1.5 validation tests, so this is the register's strongest audit contribution.

**Blockers stop the build.** A superseded unit, a course with no usable delivery sequence, a unit that is credit-transferred and therefore not taught here. They are not advice.

## Adding or changing a course

1. **Harvest any unit not yet cached.** `scripts\Get-UnitRecord.ps1 -CodeFile codes.txt`. Idempotent; `-Force` refreshes.
2. **Add the course block** to `scripts\Build-CourseRecord.ps1` - provider, variant, duration, packaging rule, TAS path, clusters or themes, and for a credit-transfer course the `delivered` list and `priorCourse`. Run it.
3. **Detect the overlaps.** `scripts\Build-TopicFamilies.ps1 -CourseId <id> -OutJson assets\topics\families\<id>.families.json`
4. **Rule on them.** Write `assets\topics\decisions\<id>.decisions.json`. One entry per topic; `families` lists the detected families it absorbs.
5. **Build the register.** `scripts\Build-TopicRegister.ps1 -CourseId <id>`. **It fails unless every family is claimed exactly once** - claimed twice means two topics own one piece of ground, claimed by nobody means an overlap nobody ruled on that will ship as duplicated teaching.
6. **Regenerate the docs.** `scripts\Build-TopicMap.ps1`.
7. **Regenerate the coverage register page.** `scripts\Build-CoverageRegisterHtml.ps1`, then **publish it** — the page on claude.ai is a separate copy and does not update itself. Skipping this is how the published register came to carry six superseded topics and two missing courses on 9 September 2026.

**The ordering gate.** `Build-TopicRegister.ps1` fails if a unit recalls a topic whose owner is taught later — a learner cannot recall what they have not been taught. Fix it by moving ownership earlier, or by excluding the unit with `excludeUnits: [{ unit, reason }]` when it teaches its own slice in full and is not a recaller at all. **Check the claim before writing "earliest" in a rationale**: the unit TABLE and the delivery SEQUENCE are different orders, and three rulings were wrong because the table was read as the sequence.

**Re-read the family numbering before writing decisions.** Families are numbered by position, so changing the detector or the unit list renumbers them. Authoring against a stale numbering silently attaches a ruling to the wrong topic - the owner check catches most of it, and will not catch a swap between two families that share a unit.

## What the detector cannot do

It matches words. It put `CPCCBC4002` nowhere near the WHS legislation family in CPC40120 because that unit words the duty differently - **the unit that owns a topic can be the one the machine misses**. It also chains two different topics together through one ambiguous statement. Both are why the families are candidates and the rulings are authored, and why every ruling carries a written reason.

## A course enters the registry only when its TAS is on file

The unit list, the elective selection and the delivery sequence are the RTO's own decisions, and the Training and Assessment Strategy is the only place they are recorded. Without one there is nothing to read, and a unit list assembled from the national packaging rules would be an invention wearing the registry's authority. **No TAS, no course record.**

## One record per institute, not one per qualification

Three qualifications are on both prospectuses, and **each institute has its own strategy**:

| Qualification | Adelaide Culinary Institute | Meridian Vocational College |
|---|---|---|
| SIT30821 Certificate III in Commercial Cookery | `ACI-SIT30821` | `MVC-SIT30821` |
| SIT40521 Certificate IV in Kitchen Management | `ACI-SIT40521` | `MVC-SIT40521` |
| SIT50422 Diploma of Hospitality Management | `ACI-SIT50422` | `MVC-SIT50422` |

**They are not interchangeable, and that was checked rather than assumed.** For SIT40521 and SIT50422 the two institutes select **different electives** — Meridian delivers `BSBTWK501` in its Certificate IV, which does not appear in ACI's unit list at all. A different elective set changes which unit owns a shared topic, so each institute holds its own register and `siblingCourse` points at the counterpart. `Get-UnitBrief.ps1` returns a caveat naming the sibling on every brief for these six records.

**SIT30821 is the exception and it is still two records.** ACI and Meridian select the identical 25 units and deliver them in the identical order, confirmed unit by unit and position by position, so the 46 detected families match one for one and the rulings are the same. `ACI-SIT30821`'s decisions file says so at the top. If either institute changes an elective or its order, it stops being a copy and must be re-ruled on its own.

## Skill sets

`SITSS00069 Food Safety Supervision` is in the registry with `productType: "skill set"`. It carries two units over four weeks and issues a Statement of Attainment, not a qualification. It is not on the course prospectus and it has no AQF level; everything else about it works the same way.

## Not in the registry

**SIT40721 Certificate IV in Patisserie (Meridian)** — the one advertised qualification with no register.

A strategy was supplied on 8 September 2026, and it is **for the superseded SIT40716**. It names SIT40716 throughout, and **all 32 of its units are superseded** — not one is current. Five of the transitions are non-equivalent, so the assessment tools behind them do not carry over either. Admitting it would put 32 dead unit codes in the registry under a qualification the RTO cannot issue, so nothing was recorded.

`docs/SIT40716-transition.md` carries the full old-to-new map read live from training.gov.au, the five non-equivalent transitions called out, and one packaging consequence: `SITXINV001` and `SITXINV002` both supersede to the single unit `SITXINV006`, so the set collapses from 32 to 31 and one further elective has to be chosen.

**What is needed is a TAS for SIT40721.** Supply it and follow *Adding or changing a course*.
