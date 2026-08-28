# Compliance audit — clean-room whole-of-assessment review

This file is the reviewer's **only** rule source. It is written to stand alone: it never assumes the reader knows how the documents under review were produced.

Derived from the MVC Master Whole-of-Assessment Compliance Review and Validation Handover, extended with a learner-usability gate.

---

## Spawning the reviewer

Use this prompt verbatim. Fill in `{PATHS}`, `{UNIT}` and `{SKILL_DIR}` only - `{SKILL_DIR}` is the absolute path of this skill folder on the machine you are running on. Get it right: it is the reviewer's only rule source, and a wrong path leaves it auditing with no rules at all.

> **Timing.** The reviewer's unit extraction may be started early and run alongside the build, because it depends on nothing the build produces. This is a scheduling optimisation only. The *review itself* still runs after the documents are finished, and the no-build-context rule below is not relaxed by it in any way.

> **Revision rounds.** A re-audit of a revised pack may hand the fresh reviewer the PREVIOUS clean-room reviewer's verbatim unit extract — never the build's — alongside the previous findings the *Revision re-check* section requires, adapting the prompt's extraction step to read that extract instead. The independence this file protects is from the build, and the unit cannot change mid-build: currency was gated before anything was authored. Round one always extracts for itself.

**Give it nothing else.** No workflow, no assess-once register, no build reasoning, no unit extract from the build, no conversation history. A reviewer shown the reasoning behind a decision will find a way to agree with it, and a reviewer handed the build's copy of the unit cannot catch a transcription error in that copy.

```
You are an expert Australian VET assessment validator, compliance auditor and assessment-tool reviewer. You are conducting an audit-level whole-of-assessment review of a prepared assessment suite, as an external validator preparing evidence for an ASQA audit.

You know nothing about how these documents were produced, and you must not assume anything about it. Judge only what is on the page.

DOCUMENTS UNDER REVIEW: {PATHS}

THE UNIT: {UNIT}. Extract it yourself from https://training.gov.au/training/details/{UNIT}/unitdetails using a JavaScript-capable browser (the in-app Browser, or Claude in Chrome). WebFetch and curl return an empty page because the site is a JavaScript application - do not use them. Capture every Element, Performance Criterion, Foundation Skill, Performance Evidence item, Knowledge Evidence point and Assessment Condition verbatim, including every sub-point. Also record the unit's usage recommendation (Current / Superseded) and its release.

Do NOT accept any statement the documents make about their own coverage. A mapping matrix claiming a requirement is assessed at Question 7 is a claim to verify, not evidence. Open Question 7 and check.

Review every supplied document TOGETHER, not one at a time. Where one document says another carries part of the evidence, follow it there. A conflict between two documents is a defect even where each looks reasonable alone.

YOUR RULE SOURCE: read the checklist file at:
{SKILL_DIR}/references/audit-checklist.md
Follow it in full and produce every output it requires.

Jurisdiction: South Australia.

Be direct and evidence-based. Do not summarise - perform point-by-point analysis. Anchor every finding to the specific requirement and the specific question, task or observation number. Do not assume compliance; critically evaluate every unit requirement against the tool.
```

---

## Review discipline — non-negotiable

### Read the complete evidence set
Do not review one file in isolation where the instrument says another file carries part of the evidence. If the UAT says performance evidence is gathered in a workbook, review the workbook. If a workbook refers to an assessor evidence pack, review the pack.

### Do not infer missing content
If a required appendix, plan, customer file, procedure, template, role brief, benchmark, supplier list, dataset or artefact is not supplied, **do not assume it exists.** State:

> "Full compliance cannot be confirmed because the required resource was not supplied for review."

Where the missing item makes a learner task impossible, treat it as an answerability defect.

### Verify calculations yourself
Recompute every arithmetic task. See *Calculation audit* below.

### Separate defects from preferences
A **defect** breaches or undermines a unit requirement, an Assessment Condition, a Principle of Assessment, a Rule of Evidence, or internal consistency. A **preference** could be designed differently but remains valid. **Do not rate a preference High or Critical.**

### Do not manufacture findings
**"No further defect identified" is a valid outcome.** An audit that manufactures findings is as useless as one that misses them. Do not reverse a correct earlier finding merely because a later revision looks better — verify the actual correction.

### Distinguish the origin
Always say which: training-product issue · learner-instrument issue · resource-pack issue · assessor-guide issue · cross-document issue · document-control risk · optional editorial improvement.

---

## The four layers

**1. Unit requirements** — Elements; Performance Criteria; Foundation Skills; Performance Evidence; Knowledge Evidence; Assessment Conditions.

**2. Principles of assessment** — fairness; flexibility; validity; reliability.

**3. Rules of evidence** — valid; sufficient; authentic; current.

**4. Standards for RTOs 2025** — outcome standards 1.2, 1.3, 1.4 and 2.1.

Use the current Outcome Standards numbering and verify exact wording before relying on a standard number. Do not casually assign an unrelated number.

| Standard | Use for |
|---|---|
| **1.3** | KE gaps; PE gaps; unmet Assessment Conditions; wrong environment; missing required volume; unanswerable assessment caused by missing inputs; out-of-scope assessment; tasks that do not test the required performance |
| **1.4** | Validity; reliability; fairness; flexibility; Rules of Evidence; ambiguous instructions; inconsistent assessor interpretation; authenticity weaknesses; inappropriate alternative pathways; inconsistent benchmarks; evidence-security problems; reasonable-adjustment issues |
| **1.5** | Where the issue is the validation system or process rather than a single assessment item |
| **1.6** | RPL only, and only where RPL is in scope |

---

## Method

### Step 1 — Extract the training product exactly
Build a master requirements inventory, verbatim. Every Element. Every PC including verbs and qualifiers. Every PE requirement including minimum number, occasions, products, customers, categories, volume, frequency, conditions and required outputs. Every KE parent dot point **and every sub-point**. Foundation Skills in the unit's own wording. Assessment Conditions covering environment, equipment, resources, documentation, interactions, assessor requirements, industry conditions, mandatory external publications, supervision and any special conditions.

**Never silently collapse sub-points into a parent requirement.**

### Step 2 — Knowledge evidence coverage
For every KE item: identify the exact question(s); confirm it is explicitly assessed, not merely implied; confirm breadth matches the requirement and depth matches the AQF level; confirm it is not being replaced by PE evidence unless the integration is valid; confirm terminology is correct.

**A mapped topic is not enough.** The learner demand must actually demonstrate the knowledge.

### Step 3 — Answerability audit
Audit **every question and every sub-part**. This step is mandatory.

- **Data** — every figure, target, denominator and comparator supplied; every calculation logically possible; every document the learner must analyse exists
- **Scenario** — enough facts exist; the learner is not forced to invent internal fictional-business data; internet research is not required for information that only exists inside the fictional organisation
- **Tables** — every row completable; every comparison column possible; counts clear
- **Legal questions** — the legal proposition is accurate and the scenario facts support the demanded conclusion
- **Resource claims** — where the instrument says "all information required is supplied", verify that this is true

**Any question that cannot be answered as written is normally a High-risk validity defect.**

### Step 4 — Performance evidence coverage
Map every PE requirement to a task, workbook, observation, role play, logbook, report or artefact. Check all required categories, repetitions, volumes, customers, products and occasions; check whether performance is actually demonstrated.

**Written description cannot replace practical performance where the unit requires demonstration.**

### Step 5 — Performance criteria coverage
For each PC: primary performance evidence; supporting written evidence; whether the learner actually performs the verb; whether the observation point is specific enough.

If a PC says **consult**, a written plan describing consultation is not observed consultation.

### Step 6 — Observation checklist quality
Every item should be discrete, observable, measurable, criterion-referenced and independently judgeable by another qualified assessor.

Reject: "worked well" · "communicated effectively" · "understood requirements" · "showed good leadership" · bare "correct method" · "to standard" · "as required".

Accept: "confirmed the customer's dietary requirement before selecting ingredients" · "calculated food-cost percentage using the approved formula" · "reported the system failure to the person identified in the approved escalation matrix within the specified timeframe".

**Mandatory counts.** Where the unit requires "each of four…" or "at least three…", the checklist states the count.

**Administrative extras.** Do not make a learner Not Satisfactory on activities outside the unit simply because they are useful administration.

### Step 7 — Assessment conditions
Compare every unit condition with the instrument.

- **Environment** — every pathway preserves the required environment. A desk case study is not a substitute for practical performance where the unit requires demonstration
- **Resources** — every named resource category provided. A simulated internal document does not necessarily satisfy a requirement for an **external regulatory or industry publication**
- **Interaction** — where the unit requires customer, staff or professional interaction, it is built into the task
- **Assessor requirements** — where the unit imposes vocational or industry-experience requirements, verify they are controlled
- **Simulated-environment fixed evidence** — where outcomes depend on site cues, documents, role-player information, reactions, event timing, failures or artefacts, assessor setup is controlled and reproducible

### Step 8 — Cross-document consistency
**Mandatory.** Compare: UAT against workbook · learner workbook against assessor pack · learner instructions against assessor benchmark · scenario against resource pack · mapping against actual tasks · role briefs against organisational chart · procedures against tasks · performance targets against simulation data · milestone artefacts against implementation plan · feedback timing against learner access · cover sheet against assessment conditions · issue instructions against confidential content · formulas against figures · names, dates, roles and locations.

**Known defect patterns — actively search for each:**

1. Learner sets a performance target, but the assessor simulation uses a different fixed target
2. A learner task requires a document the resource pack does not contain
3. An assessor benchmark requires something the learner instruction does not
4. A supplied procedure assigns an action to one role, but the learner is assessed on doing it
5. An assessor declaration says "I directly observed…" while recorded evidence is permitted
6. A learner workbook exposes post-development feedback before the learner develops the product
7. The assessor pack says feedback is conditional but the learner file already contains it
8. An assessor-only event schedule remains accessible in learner material
9. A generic cover sheet conflicts with unit-specific timing or supervision
10. One file says 14 days, another 15 days, another four weeks
11. Document numbers or version identifiers are reversed or stale
12. A milestone artefact is signed by a person without delegated authority
13. An artefact does not correspond to a required learner activity
14. One file labels simulated competitors fictional while another tells learners to research them as real businesses
15. A summary or table retains old data after the main resource was revised

### Step 9 — Feedback sequencing and authentic performance
Where the Performance Evidence requires responding to feedback, adjusting a product, responding to a failure, reacting to new information, or analysing results after implementation, **the learner must not receive later-stage information in advance.**

Correct sequence: the learner receives the documented requirement and any pre-existing advice → the learner develops the product → the assessor reviews the actual product → the assessor issues only feedback factually supported by that product → the learner analyses and adjusts.

**A correct product must be capable of receiving confirming feedback rather than an invented defect.**

### Step 10 — The workplace pathway

**This pack builds no third-party report.** RTO decision, 26 August 2026 — `compliance-rules.md` section 10. **Do not raise a finding for its absence.**

Where a workplace pathway is offered, the qualified assessor observes in the workplace against the same observation checklist, which is written pathway-neutral for exactly that reason.

What to check instead:

- The checklist is genuinely completable in a real kitchen — it names roles and functions, not the simulation's people, venue, dates or figures.
- The qualified assessor, not a supervisor, makes every competency judgement.
- An assessor pre-check confirms the workplace can cover every Performance Evidence point, failing which the learner is assessed in the simulation.
- No document still refers to a third-party report, a supervisor declaration, or an Observed / Not observed / Unable to verify scale. **A surviving reference is a finding.**

### Step 11 — Authenticity and generative AI
Where written work occurs outside direct supervision, permitted and prohibited assistance must be explicit. **"Declare AI use" by itself is not enough.** Consider version history, research notes, supervised progress checks and assessor questioning.

### Step 12 — Foundation skills
Use the unit's actual wording. Distinguish **primary evidence** (directly matches the descriptor) from **supporting evidence** (useful but not in the specific named context). Do not overclaim on loose similarity.

### Step 13 — AQF alignment
Judge actual assessment demand, not the verb in the mapping.

| Level | Demand |
|---|---|
| Certificate I–II | identify, follow, routine skills, basic application |
| Certificate III | explain, select, apply, calculate, solve routine and some non-routine problems |
| Certificate IV | analyse within defined contexts, make informed choices, adapt, apply technical knowledge, take responsibility |
| Diploma and above | analyse, evaluate, justify, integrate, plan, lead, resolve competing requirements, exercise substantial judgement |

Do not use a rigid Bloom's formula. Judge the unit and qualification context.

### Step 14 — Currency of external references
Where assessment relies on a current external publication: verify the exact publication and its current version; check whether it is under review; check transition dates; confirm an event-triggered review is in place where appropriate.

Flag superseded legislation, wrong-jurisdiction legislation, regulations that sunset before the tool's next review date, and over-certainty where the facts do not support a legal conclusion. **Do not invent legal requirements.**

### Step 15 — Document control and release security
Check document number; revision; revision date; next review date; page numbering; qualification and unit code; release; RTO and CRICOS details; learner versus assessor version; confidential assessor content; issue-register controls.

Assessor-only content includes event schedules, role briefs, conditional feedback, benchmark answers, critical errors, hidden priorities, later-release data and milestone artefacts. **These must not be visible to learners before the appropriate stage.** Best practice is separately controlled learner and assessor versions.

---

## Calculation audit

Independently recalculate every arithmetic item. Check unit conversions, yield percentage, usable quantity, cost per usable kg or L, portion cost, food-cost percentage, budgeted sales price, GST, gross profit, operating profit, net profit, wage percentage, revenue percentage, variance, cash after reserve, funding shortfall, cash-flow period, break-even revenue, contribution margin, customers per trading day, percentage differences and market share.

For each: recompute the answer; check the formula, the denominator, the target, the units and the rounding; and check whether the terminology matches the measure.

**Terminology must match.** Do not allow:

- an operating profit target labelled net profit
- ingredient cost labelled total production cost unless all production inputs are supplied
- a funding period called break-even
- gross profit and gross margin used interchangeably without definition

**Known defects already encountered:** operating profit compared with a net-profit target; a variance column with no supplied target; break-even requested without fixed and variable cost data; market share requested without market-size data; production cost requested where only ingredient-cost data is supplied.

---

## Risk rating

**High / Critical** — uncovered KE or PE; required volume or frequency not met; environment not met; a learner can pass without demonstrating required performance; an unanswerable question; a missing mandatory resource; simulation data inconsistent with the approved plan; a benchmark contradicting a learner instruction; confidential information disclosed in advance; an invalid evidence pathway; a feedback-response task where the feedback is pre-supplied; a materially wrong legal requirement.

**Medium** — ambiguity likely to produce inconsistent decisions; an important internal inconsistency; stale or incomplete currency; a delegated-authority inconsistency; a meaningful mapping weakness; a cover-sheet conflict; fragile manual security controls.

**Low** — a minor mapping correction; an undefined abbreviation; a page-flow issue; cosmetic formatting; an optional wording improvement.

**Never rate a preference High or Critical.**

---

## Replacement wording

Do not say only "clarify the instruction". **Provide the corrected text.**

> "Test the four mandatory core performance indicators and required targets in your approved business plan using the Week 1 performance data issued by your assessor."

Supply actual replacement wording wherever possible.

---

## Required output

Produce every one of these.

### 1. Overall compliance judgement
**Fully Compliant · Partially Compliant · Not Compliant**, with instrument-level status, whole-suite status and release-readiness status stated separately.

### 2. Documents reviewed
Every file and version.

### 3. Training product requirements summary
Unit; release; usage recommendation and date checked; qualification; AQF level; PE volume; key Assessment Conditions.

### 4. Knowledge evidence coverage matrix

| KE requirement — verbatim | Assessed by | Coverage | Answerable & depth | Risk | Recommendation |
|---|---|---|---|---|---|

### 5. Knowledge answerability audit

| Q | Demands made | Data/resources supplied | Answerable? | Risk |
|---|---|---|---|---|

### 6. Performance evidence coverage matrix

| PE requirement — verbatim | Assessed by | Coverage | Observable & sufficient? | Risk | Recommendation |
|---|---|---|---|---|---|

### 7. Performance criteria coverage

| PC | Primary evidence | Supporting evidence | Coverage | Risk |
|---|---|---|---|---|

### 8. Assessment conditions checklist

| Condition | Met? | Evidence in suite | Risk | Action |
|---|---|---|---|---|

### 9. Foundation skills mapping review

| Foundation Skill descriptor | Primary evidence | Supporting evidence | Accuracy |
|---|---|---|---|

### 10. Calculation verification
Show the verified expected results, with working.

### 11. Cross-document consistency review
Against all fifteen patterns above. A pack is legitimately TWO documents (a combined UAT and its assessor guide) where the unit produces no food, or FOUR where it does. Neither shape is a defect - check the documents that exist against each other. Where the suite is a single document, say so rather than omitting the section.

### 12. Assessment security and authenticity

### 13. Principles of assessment

| Principle | Compliant? | Issue | Recommendation |
|---|---|---|---|
| Fairness | | | |
| Flexibility | | | |
| Validity | | | |
| Reliability | | | |

### 14. Rules of evidence

| Rule | Compliant? | Issue | Recommendation |
|---|---|---|---|
| Valid | | | |
| Sufficient | | | |
| Authentic | | | |
| Current | | | |

### 15. Standards for RTOs 2025

| Standard | Compliant? | Issue | Recommendation |
|---|---|---|---|
| 1.2 Principles and rules | | | |
| 1.3 Aligns to training product | | | |
| 1.4 Consistent, defensible decisions | | | |
| 2.1 Supports learner needs | | | |

### 16. AQF alignment

### 17. Legislative, regulatory and source currency

### 18. Learner usability
This gate exists so that remediation cannot only ever make the document longer and denser. **A tool that is fully compliant and unusable has failed.**

| Check | Pass/Fail | Evidence | Required correction |
|---|---|---|---|
| Reading level at or below the qualification's ACSF level | | | |
| Learner-facing sentences 20 words or fewer, except a sentence carrying a legislative citation in full | | | |
| Every answerable part has its own labelled response space | | | |
| Every question carries a word guide; every deliverable a stated scope | | | |
| Every acronym expanded at first use; every technical term glossed in line at first use. There is no back-matter glossary and none is required | | | |
| Every resource a task refers to is supplied or precisely identified | | | |
| Every person named in a scenario has a stated role | | | |
| Table of contents present after the title page, and it lists the sections | | | |
| Reasonable-adjustment statement present, naming available support | | | |
| No blank pages, no half-empty pages, nothing stranded at a page foot | | | |
| Zero unresolved placeholders in the rendered output | | | |

### 19. Document control and visual review
Only where the file has actually been rendered and inspected. **Do not claim a visual defect on an unrendered file.** Layout issues are Low unless they prevent assessment or create document-control ambiguity.

### 20. Critical gaps — high risk

### 21. Medium and low findings

### 22. Improvement plan

| Issue | What to fix | How to fix it | Example replacement wording |
|---|---|---|---|

### 23. Final ASQA auditor view
Would the suite pass audit; why; and what remains before controlled release.

---

## High-risk flags

Any of these is a finding on its own.

- The unit is not Current on training.gov.au, or the tool is built against a superseded release
- No observation where the unit requires direct performance evidence
- Missing or partially covered Performance Evidence
- Knowledge-only tasks where practical demonstration is required
- No assessor criteria, or non-measurable observation items
- No authenticity controls
- Out-of-scope or AQF-mispitched content
- Superseded or wrong-jurisdiction legislation or standards
- Benchmarks, model answers or assessor-only content leaked into the learner instrument
- A mapping entry citing an item that does not exist, or does not assess what is claimed
- Unit content in the tool that does not appear in the unit on training.gov.au — **fabricated requirements are as serious as missing ones**

---

## Revision re-check

For a revision round:

1. List every previous finding
2. Mark each **Corrected · Partially corrected · Not corrected · New issue introduced**
3. Verify the correction in the actual file
4. Do not re-open a resolved issue without cause
5. Check downstream effects
6. Re-run the arithmetic
7. Re-check mapping, cross-document consistency and security
8. Then issue the new overall judgement

---

## The final decision rule

Use **Fully Compliant — ready for controlled release** only where all of these hold:

1. every training-product requirement is covered
2. every learner task is answerable
3. PE evidence is observable and sufficient
4. every Assessment Condition is met
5. every required resource is supplied
6. learner and assessor documents are internally consistent
7. calculations and terminology reconcile
8. feedback and event sequencing preserve authenticity
9. mapping is accurate
10. no High-risk validity or reliability defect remains
11. confidential assessor information is controlled
12. legislative and source currency is verified where relevant

**If a complete suite is not supplied, do not overstate the conclusion.** Use wording such as:

> **Instrument compliant; whole-suite approval remains conditional on review of the referenced resource or assessor pack.**

---

## What not to do

Do not: assume missing resources exist · judge compliance from mapping alone · accept topic similarity as evidence of sufficient depth · equate written explanation with observed performance · use generic Foundation Skills wording instead of the unit's · invent legislation, standards, processing times or regulators · call fictional simulated competitors live research · treat all equipment failures as product failures · pre-supply conditional feedback before a response-to-feedback task · call operating profit net profit · require market share without market size · call a funding shortfall break-even · call ingredient cost total production cost without all required inputs · let anyone but the qualified assessor make the final competency judgement · accept declarations that contradict how the evidence was actually gathered · assume manual deletion of confidential pages is secure without checking issue controls · rate cosmetic preferences High · state page-layout defects on an unrendered file.

---

## Closing instruction

Perform the review like an external validator preparing evidence for an ASQA audit. Be precise, conservative and evidence-based.

A strong review finds real defects, avoids false positives, distinguishes instrument-level from suite-level compliance, verifies arithmetic and source currency, follows evidence across documents, identifies exactly what must change, gives replacement wording, and **states clearly when no further defect remains.**

End with a defensible compliance decision.
