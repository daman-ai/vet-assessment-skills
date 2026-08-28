# Compliance audit — clean-room learner-resource review

This file is the reviewer's **only** rule source. It stands alone: it never assumes the reader knows how the documents under review were produced.

It is the sibling of the assessment skill's checklist of the same name, and it is **not a copy of it**. An assessment instrument fails by not gathering the required evidence. A learning resource fails by **teaching something that is not true**, by preparing a learner for the wrong instrument, or by pitching content the learner cannot use. Those are different audits.

---

## Spawning the reviewer

Use this prompt verbatim. Fill in `{GUIDE}`, `{DECK}`, `{PACK}`, `{UNIT}` and `{SKILL_DIR}` only — `{SKILL_DIR}` is the absolute path of this skill folder on the machine you are running on. Get it right: it is the reviewer's only rule source, and a wrong path leaves it auditing with no rules at all.

**Give it nothing else.** No spine, no build script, no contract, no workflow, no conversation history, no unit extract taken from the build. A reviewer shown the reasoning behind a figure will find a way to agree with it, and a reviewer handed the build's copy of the unit cannot catch a transcription error in that copy.

> **Timing.** The reviewer's own unit extraction may start early and run alongside the build, because it depends on nothing the build produces. The *review itself* still runs on the finished documents, and the no-build-context rule is not relaxed by it.

```
You are an expert Australian VET compliance auditor and learning-resource validator. You are conducting an audit-level review of a learner guide and its delivery deck, as an external validator preparing evidence for an ASQA audit.

You know nothing about how these documents were produced, and you must not assume anything about it. Judge only what is on the page.

UNDER REVIEW:  {GUIDE}  and  {DECK}
THE ASSESSMENT PACK THESE TEACH TOWARD:  {PACK}

THE UNIT: {UNIT}. Extract it yourself from https://training.gov.au/training/details/{UNIT}/unitdetails using a JavaScript-capable browser (the in-app Browser, or Claude in Chrome). WebFetch and curl return an empty page because the site is a JavaScript application - do not use them. Capture every Element, Performance Criterion, Foundation Skill, Performance Evidence item, Knowledge Evidence point and Assessment Condition verbatim, including every sub-point. Record the unit's usage recommendation (Current / Superseded) and its release.

THE PACK IS THE AUTHORITY, NOT THE GUIDE. The guide is written after the assessment and derived from it. Where the two disagree on a figure, a term, a count or a threshold, the guide is wrong unless the pack is demonstrably wrong on the law - and if the pack is wrong, say so as a SEPARATE upstream finding against the pack. Never report a pack defect as a guide defect.

Do NOT accept any statement the guide makes about its own coverage. A cross-reference table claiming a topic prepares Question 7 is a claim to verify, not evidence. Open Question 7 in the pack and check that it exists, and that the topic actually prepares it.

VERIFY EVERY FIGURE INDEPENDENTLY. This is the central task of this audit, not a side check. See "The provenance audit" in the checklist. Do not take a number on trust because it looks like a number a trainer would use.

Review the guide, the deck and the pack TOGETHER, not one at a time. A conflict between any two is a defect even where each looks reasonable alone.

YOUR RULE SOURCE: read the checklist file at:
{SKILL_DIR}/references/audit-checklist.md
Follow it in full and produce every output it requires.

Jurisdiction: South Australia.

Be direct and evidence-based. Do not summarise - perform point-by-point analysis. Anchor every finding to the specific page, figure, sub-section, slide or question number. Do not assume correctness; critically evaluate every claim the resource teaches.
```

---

## Review discipline — non-negotiable

### Verify every figure yourself
The provenance audit below is mandatory and is the reason this review exists. A learner guide's most damaging defect is a confident, plausible, wrong number, because the learner reproduces it in the assessment and in the workplace.

### Read the complete set
Guide, deck and pack together. Where the guide sends the learner to a resource, a procedure or an appendix, follow it. Where the deck teaches something the guide does not, that is a finding.

### Do not infer missing content
If the guide relies on a venue procedure, a form, a policy, a supplier list or a dataset that is not supplied, **do not assume it exists.** State:

> "Full compliance cannot be confirmed because the referenced resource was not supplied for review."

### Separate defects from preferences
A **defect** teaches something untrue, leaves an assessed requirement untaught, contradicts the pack, misattributes legal authority, or puts the content out of the learner's reach. A **preference** could be written differently and remains correct. **Do not rate a preference High or Critical.**

### Do not manufacture findings
**"No further defect identified" is a valid outcome.** An audit that manufactures findings is as useless as one that misses them.

### Distinguish the origin
Always say which: **guide defect · deck defect · guide/deck inconsistency · guide-versus-pack conflict · upstream pack defect · training-product issue · visual defect · document-control risk · optional editorial improvement.**

---

## The five layers

**1. Training-product alignment** — every Element, PC, Foundation Skill, PE item and KE point, including sub-points, that the pack assesses is taught somewhere in the guide, at the depth the AQF level demands. Nothing is taught that lies outside the unit's scope.

**2. Factual, legislative and jurisdictional accuracy** — the heavy layer for this document type. Every figure, threshold, duration, temperature, percentage, dollar amount, count, regulator name, standard number, form name and legal proposition.

**3. Assessment alignment** — the guide prepares the learner for the instrument that actually exists. Every question it cites is in the pack. Every question in the pack is prepared somewhere. No model answer to a pack question appears anywhere in the guide or the deck.

**4. Learner usability and AQF pitch** — readable at the level, scaffolded, terminology introduced before it is used, assessed terminology never simplified away, LLN and EAL load reasonable.

**5. Standards for RTOs 2025** — the outcome standards governing training delivery and the sufficiency of learning resources.

> **Verify the exact Outcome Standards numbering and wording before relying on a standard number, and cite only a standard you have checked.** Do not casually assign an unrelated number to give a finding weight it has not earned. Where you are confident of the obligation but not the number, state the obligation in words and say the number is unverified. That is a stronger finding than a wrong citation, and this checklist would rather have it.

---

## The provenance audit

**The centrepiece. Run it before anything else, because most other findings fall out of it.**

Build a ledger of **every** numeric claim and every legal proposition in the guide and the deck. Include: temperatures, times, durations, percentages, dollar amounts, counts, volumes, weights, ratios, ages, distances, retention periods, standard numbers and named legal duties.

For each one, assign exactly one **authority class**:

| Class | Means | Test |
|---|---|---|
| **P** | It comes from the assessment pack | Find it in the pack, verbatim. The pack is upstream and wins. |
| **U** | It comes from the unit | Find it in your own extraction from training.gov.au. |
| **L** | It comes from legislation, a standard or a code | Cite the instrument, the clause and the jurisdiction. Verify against the current source, not memory. |
| **V** | It is the scenario venue's own documented procedure | The page must say so, in the learner's sight. |

**A figure that fits none of the four classes is fabricated.** That is a High-risk defect, regardless of how reasonable it looks. Plausibility is not provenance.

### The attribution test — the one that matters most

For every figure classed **L**, three separate questions, and all three must pass:

1. **Does the source actually say the number?** Verify it against the instrument, not against recollection or common practice.

2. **Does the source *mandate* it, or merely *recommend* it?** These are not interchangeable. A regulator's recommendation, an industry guideline, a good-practice note and a code requirement carry different legal weight. Then read the sentence the figure sits in and check the language matches its weight:
   - Mandatory language — *must*, *required*, *the legal limit*, *the Code requires*, *critical limit*, *you are obliged to* — is available **only** to a genuine mandatory requirement.
   - A recommendation is written as a recommendation, and named as one, with the body that recommends it: *"X recommends…"*, *"the venue has adopted…"*.
   - **A recommendation dressed as a legal requirement is a High-risk defect.** It teaches a learner to state a legal position that is not the law, and the learner then states it in the assessment and in the workplace. **The reverse — a genuine mandatory requirement written as optional — is equally a defect.**

3. **Does it apply to the thing it is attached to?** A real figure can be attached to the wrong subject. A recommendation that applies to one category of product, task, premises or worker is wrong when written as the limit for a different one, even though the number itself is genuine and citable. Check the *scope* of the source, not only its value.

### Cross-check the classes against each other

- A figure the pack carries (**P**) and the guide states differently is a **guide-versus-pack conflict** — High risk, because the learner is being prepared against a number the assessment will mark wrong.
- A figure the guide carries that the pack does not is not automatically a defect — a resource may legitimately teach beyond the instrument — but it must still be classed, sourced, and flagged as content the assessment does not cover.
- A figure that appears in both the guide and the deck must be identical in both.

### Report it as a table

Every entry, every time, whatever the verdict:

| Figure | Where it appears | Class | Source | Mandatory or recommended | Applies to | Verdict |
|---|---|---|---|---|---|---|

**A "verified" row is as much a required output as a defect row.** The value of the ledger is that it is complete.

---

## Method

### Step 1 — Extract the training product exactly
Verbatim, from your own browser session. Every Element, PC, Foundation Skill, PE item and KE point **and every sub-point**. Never silently collapse a sub-point into its parent.

### Step 2 — Run the provenance audit
As above. Do this before reading the guide for coverage, so you read the content already knowing which of its numbers you have verified.

### Step 3 — Coverage
For every KE point and PE item the pack assesses: find where the guide teaches it. Confirm it is explicitly taught, not merely mentioned; that breadth matches the requirement and depth matches the AQF level; and that the terminology is the unit's.

**A topic heading is not coverage.** The learner must be able to answer from what is on the page.

### Step 4 — Assessment alignment, both directions
- Every question the guide or deck **cites** exists in the pack, with that number.
- Every question in the pack is **prepared** somewhere in the guide.
- **No model answer, benchmark, marking guide or assessor-only note appears in either learner-facing document.** A guide that answers the pack's questions destroys the assessment it was built to support. Search for the pack's own answer wording.

### Step 5 — Cross-document consistency
Guide against deck, guide against pack, deck against pack. Figures, terminology, counts, thresholds, scenario facts, venue name, character names, question numbers, sub-section numbering.

### Step 6 — Visuals
Every figure, diagram and table. Does the image show what its caption and alt text claim? Does it contradict the text it illustrates, or contradict something the guide teaches elsewhere? In a compliance-bearing subject, an image showing a practice the document forbids is a defect on the page, not a styling quibble.

### Step 7 — Usability and pitch
AQF level, reading load, scaffolding, terminology introduced before use, whether a learner could work through it unaided. Assessed terminology is never simplified — flag any place it has been.

### Step 8 — Document control
Version, date, unit code and release on the artefact; footer attribution; the deck's slide numbering matching its actual positions; the PDF no older than the file beside it.

---

## Risk rating

**High / Critical** — a fabricated figure with no traceable source · a recommendation taught as a legal requirement, or a requirement taught as optional · a real figure attached to the wrong subject · a guide figure contradicting the pack · a cited question that does not exist in the pack · an assessed KE or PE item taught nowhere · a model answer or benchmark leaked into a learner document · superseded legislation or the wrong jurisdiction or regulator · content taught that is outside the unit's scope · a visual contradicting a compliance requirement the document teaches.

**Medium** — an ambiguity likely to send learners to different conclusions · an internal inconsistency between guide and deck · thin coverage of an assessed requirement · a figure correctly sourced but not attributed on the page · stale currency · a mapping weakness · a visual whose caption and content disagree.

**Low** — a minor cross-reference correction · an undefined abbreviation · a page-flow issue · cosmetic formatting · an optional wording improvement.

**Never rate a preference High or Critical.**

---

## Replacement wording

Do not say only "clarify this". **Provide the corrected text**, ready to paste, in the guide's own voice and reading level. For a misattributed figure, the replacement must carry the correct attribution, not merely soften the claim:

> "The Food Standards Code does not set a single cooking temperature for all food. Food Standards Australia New Zealand recommends 75 degrees Celsius at the centre for poultry and for minced or rolled meat. La Meridienne has adopted that figure in its Food Safety Program as the standard for this dish, and it is the figure you monitor against."

---

## High-risk flags

Any of these is a finding on its own.

- The unit is not Current on training.gov.au, or the resource is built against a superseded release
- Any figure that cannot be traced to the pack, the unit, a cited source or a stated venue procedure
- A recommendation presented as law, or a legal requirement presented as a choice
- A figure that is genuine but attached to a subject its source does not cover
- The guide and the pack disagree on any figure, term, count or threshold
- The guide or deck cites a question number that the pack does not contain
- An assessed Knowledge Evidence or Performance Evidence item taught nowhere in the guide
- Model answers, benchmarks or assessor-only content in a learner-facing document
- Content taught that does not appear in the unit — **fabricated scope is as serious as missing coverage**
- Wrong regulator, wrong jurisdiction, superseded legislation, or a standard number that does not exist
- An image that shows a practice the document teaches against

---

## Revision re-check

For a revision round:

1. List every previous finding
2. Mark each **Corrected · Partially corrected · Not corrected · New issue introduced**
3. Verify the correction in the actual file, not in a summary of it
4. **Re-run the provenance audit on every figure the remediation touched, and on any figure in the same sentence**
5. Check downstream effects — a figure appears in the guide, the deck and often a diagram, and a correction in one leaves the others stale
6. Re-check cross-document consistency
7. Then issue the new overall judgement

---

## Required output

1. **Overall judgement** — Fully Compliant · Partially Compliant · Not Compliant, stated separately for the guide, the deck, and the pair as a delivery set
2. **Documents reviewed** — every file and version
3. **Training product summary** — unit, release, usage recommendation and date checked, qualification, AQF level
4. **The provenance ledger** — complete, every figure, verified rows included
5. **Coverage matrix** — KE/PE item → where the guide teaches it → which question it prepares
6. **Cross-document consistency findings**
7. **Findings table** — origin, risk rating, evidence, replacement wording
8. **Upstream findings against the pack**, listed separately and never mixed with guide findings
9. **The decision**

---

## The final decision rule

Use **Fully Compliant — ready for release** only where all of these hold:

1. every figure in both documents is traced to a class, and correctly attributed on the page
2. no recommendation is taught as law, and no legal requirement is taught as optional
3. every figure applies to the subject it is attached to
4. every assessed KE and PE item is taught at the required depth
5. nothing is taught outside the unit's scope
6. every cited question exists in the pack, and every pack question is prepared
7. no model answer or assessor-only content appears in a learner document
8. the guide, the deck and the pack agree on every figure, term and count
9. visuals are consistent with the text and with the compliance content
10. legislation, regulators and jurisdiction are current and correct
11. no High-risk defect remains

**Where the pack was not supplied, or was supplied incomplete, do not overstate the conclusion:**

> **Guide compliant on its own terms; alignment with the assessment instrument remains unverified pending review of the pack.**

---

## What not to do

Do not: accept a figure because it is the one everybody uses · treat industry custom as a legal requirement · cite an Outcome Standard number you have not verified · report a pack defect as a guide defect · judge coverage from a cross-reference table alone · accept a topic heading as evidence of depth · simplify assessed terminology and call it a usability improvement · invent legislation, regulators, standard numbers or processing times · rate a cosmetic preference High · state page-layout defects on an unrendered file · reverse a correct earlier finding because a later revision merely looks tidier.

---

## Closing instruction

Perform the review like an external validator preparing evidence for an ASQA audit.

A strong review of a learning resource **traces every number to a source**, distinguishes what the law requires from what a regulator recommends and from what a venue has chosen, verifies that the resource prepares the learner for the instrument that actually exists, separates its own findings from the pack's, gives replacement wording, and **states clearly when no further defect remains.**

End with a defensible compliance decision.
