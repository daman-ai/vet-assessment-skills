# Compliance audit — clean-room learner-resource review

This file is the reviewer's **only** rule source. It stands alone: it never assumes the reader knows how the documents under review were produced.

It is the sibling of the assessment skill's checklist of the same name, and it is **not a copy of it**. An assessment instrument fails by not gathering the required evidence. A learning resource fails by **teaching something that is not true**, by preparing a learner for the wrong instrument, or by pitching content the learner cannot use. Those are different audits.

---

## Spawning the reviewer

**Two modes.** The prompt below is the **single-reviewer mode**: one reviewer, the whole guide, the whole deck, the whole pack. Use it only where the reviewer's whole input - both extracts, the pack, this checklist and the evidence - fits comfortably in one context (as a working rule, under the pack budget `scripts\New-ReviewPack.ps1` enforces - 180,000 tokens by default, counted as characters / 4). Above that, use the **split mode** under *Split mode* below: one reviewer per topic plus one cross-document reviewer, cut by `scripts\New-ReviewPack.ps1` and merged by `scripts\Merge-AuditFindings.ps1`. Both modes write the same structured output, `findings.json`, under *The structured output contract* below.

Use this prompt verbatim. Fill in `{GUIDE}`, `{DECK}`, `{PACK}`, `{UNIT}`, `{EVIDENCE}` and `{SKILL_DIR}` only — `{SKILL_DIR}` is the absolute path of this skill folder on the machine you are running on. Get it right: it is the reviewer's only rule source, and a wrong path leaves it auditing with no rules at all. `{EVIDENCE}` is the list of enumeration files described below; where the build has produced none, say so in the prompt rather than leaving the placeholder in.

**Give it nothing that argues.** No build script, no contract, no workflow, no conversation history, no stage ledger, no remediation brief, no unit extract taken from the build, and — this one is absolute — **nothing produced by the persona review, which runs at the same time as this one.** A reviewer shown the reasoning behind a figure will find a way to agree with it; a reviewer handed the build's copy of the unit cannot catch a transcription error in that copy; and a reviewer handed another reviewer's findings stops being a second opinion.

**Give it the evidence.** Alongside the two documents and the pack, hand the reviewer the enumerations listed under *What the gates have already done* below — the figure sheet, the provenance ledger, the cross-reference index, the pack hazard list and the channel manifest. Every one of them is a **transcript or an enumeration, never an argument**: rows, captions, alt text, notes, locators, counts. None of them says why anything was chosen, and none of them claims anything is correct. They exist because three consecutive audit rounds each rebuilt a sixty-row provenance ledger by hand, and one of them spent its effort refuting a section it had wrongly reported as non-existent.

> **Timing.** The reviewer's own verbatim unit extraction is performed **once per unit release**, at the start of the build, by an agent with no build context, and archived as an audit artefact. It is the reviewer's own independent extraction and the transcription-error check is fully intact; what it is not is a job to redo from scratch in every round. It was performed in full three times on one build against an input all three rounds recorded identically. Each later round re-verifies only the cheap currency check — usage recommendation and release, on the day.
>
> **The review itself still runs on the finished documents**, and the no-build-context rule is not relaxed by it.

```
You are an expert Australian VET compliance auditor and learning-resource validator. You are conducting an audit-level review of a learner guide and its delivery deck, as an external validator preparing evidence for an ASQA audit.

You know nothing about how these documents were produced, and you must not assume anything about it. Judge only what is on the page.

UNDER REVIEW:  {GUIDE}  and  {DECK}
THE ASSESSMENT PACK THESE TEACH TOWARD:  {PACK}

EVIDENCE SUPPLIED WITH THE DOCUMENTS:  {EVIDENCE}
These are transcripts and enumerations - figure content, resolved locators, resolved cross-references, known pack hazards, and which content channels are final rather than placeholder. They are not arguments and they make no claim that anything is correct. Use them so your reading goes to judgement rather than to hunting and to re-deriving sixty rows by hand. Never treat one as a verdict, and where you find a defect a supplied sweep reported clean, report both.

THE UNIT: {UNIT}. Extract it yourself from https://training.gov.au/training/details/{UNIT}/unitdetails using a JavaScript-capable browser (the in-app Browser, or Claude in Chrome). WebFetch and curl return an empty page because the site is a JavaScript application - do not use them. Capture every Element, Performance Criterion, Foundation Skill, Performance Evidence item, Knowledge Evidence point and Assessment Condition verbatim, including every sub-point. Record the unit's usage recommendation (Current / Superseded) and its release.

THE PACK IS THE AUTHORITY, NOT THE GUIDE. The guide is written after the assessment and derived from it. Where the two disagree on a figure, a term, a count or a threshold, the guide is wrong unless the pack is demonstrably wrong on the law - and if the pack is wrong, say so as a SEPARATE upstream finding against the pack. Never report a pack defect as a guide defect.

Do NOT accept any statement the guide makes about its own coverage. A cross-reference table claiming a topic prepares Question 7 is a claim to verify, not evidence. Open Question 7 in the pack and check that it exists, and that the topic actually prepares it.

VERIFY EVERY FIGURE INDEPENDENTLY. This is the central task of this audit, not a side check. See "The provenance audit" in the checklist. Do not take a number on trust because it looks like a number a trainer would use.

AND BEFORE YOU CALL A FIGURE FABRICATED, SEARCH FOR IT AND SAY WHERE YOU SEARCHED. Quote the locator when you find it, and name the documents you searched when you do not. A review of this kind once declared a batch weight fabricated - "the card states no raw weight" - when the card states it in its own Portion size field, in the pack extract the reviewer had been handed. That false High finding cost a full remediation round, corrected a correct slide, and wrote a permanent rule into the build forbidding a value the pack carries. A finding you cannot anchor to a search is not yet a finding.

READ THE FIGURES AS CONTENT, NOT AS PICTURES. Every diagram in this kind of guide is a table of steps and values. Read its rows, its caption and its alt text, and check each one against the pack. See "Read the figures" in the checklist - it is mandatory and it is where the most serious defect on record was found.

WRITE YOUR REPORT FILE FIRST. Create it, write the header, the documents reviewed and your scope, and save it BEFORE you begin analysing. Then append each section as you complete it. Do not hold the report in your head and write it at the end.

WHEN YOU FINISH, WRITE findings.json BESIDE YOUR REPORT, exactly per the checklist's structured output contract: every finding in the report, one to one, with the same anchor and the same replacement wording, plus your coverage claims and your channel dispositions. It is the file the arbitration and the merger read. A finding that is in the report and not in findings.json reaches nobody.

Review the guide, the deck and the pack TOGETHER, not one at a time. A conflict between any two is a defect even where each looks reasonable alone.

YOUR RULE SOURCE: read the checklist file at:
{SKILL_DIR}/references/audit-checklist.md
Follow it in full and produce every output it requires.

Jurisdiction: South Australia.

Be direct and evidence-based. Do not summarise - perform point-by-point analysis. Anchor every finding to the specific page, figure, sub-section, slide or question number. Do not assume correctness; critically evaluate every claim the resource teaches.
```

### Split mode - one reviewer per topic, plus one for agreement across topics

**Why.** The single reviewer's input - a guide extract of about 900 KB, a deck extract of about 210 KB, a pack of about 540 KB, this checklist and the evidence - is roughly 350K tokens, beyond one context window. So "one reviewer with everything" was always a hidden chain of partial reads: whatever the reader happened to hold when it judged was the review, which is why six rounds on one build each found a different defect class, and why each round took 35 to 42 minutes. Readers who cannot see each other are harder to anchor than one, every one of them reads the whole of its input, and the wave clock becomes the slowest agent.

**How.** `scripts\New-ReviewPack.ps1 -BuildDir <build> -OutDir <dir>` cuts one directory per topic (`topic1` .. `topicN`) and the cross-document pack(s), each holding exactly what that reviewer receives and a `SCOPE.md` stating what it owns, what it must still report, and the block to paste into its prompt. It prints every pack's size in KB and as an estimated token count, split into what every reviewer shares and what is the pack's own, and it FAILS when any pack exceeds the budget (180,000 tokens by default), so an over-large pack is split on purpose rather than truncated silently by the reader.

**What a topic reviewer receives, and why.** A topic pack holds: the topic's slice of the guide (with the shared front matter, where the cross-reference table and the assessment overview live, and the shared back matter); its slides (with the shared orientation and briefing slides); its figure-sheet slots; **the learner-facing assessment tools in full** - they are what the learner holds, and every cross-reference target must resolve in them; **from each assessor guide, only the regions for the tasks the topic prepares** - the tasks the contract's question map assigns to the topic's sub-sections, cut at the assessor guide's own task headings (the body lines that equal its Contents entries, so a task's benchmarks travel with the task and an observation checklist that is its own section comes with its own heading), each region bannered with its heading and source line range; the independent unit extract; and the Stage 3d allow-list. The assessor guides are not handed whole because on the build that produced this rule they alone were 87K tokens: handing every reviewer everything put every pack over any workable budget, and the reason for doing so - a Topic 3 answer grid mirrored in Topic 5 - is the mirror gate's job over the whole spine, not a reader's. `-FullPack` keeps the everything-to-everyone mode for a small unit.

**What the cross-document reviewer receives.** The `crossdoc` pack holds the learner-facing tools only - its job is guide-versus-deck-versus-pack agreement, and the assessor guides are not learner-held; the claims digest (`scripts\Get-ClaimsDigest.ps1` - every claim-bearing sentence from both artefacts with its locator, repeats collapsed with counts, and a values index; sentences whose only claim is a correctly used locked term are dropped from the sentence list and counted, because on the reference build 1,048 of them carried no value to compare while the values index already counts every term per topic); the full figure sheet; `figures.json`; the unit extract; and the allow-list - and no topic's prose. Where that pack would still exceed the budget, the cutter splits it into `crossdoc-values` (numbers, temperatures, quantities, the scenario clock, adoption language) and `crossdoc-refs` (instrument citations, locked terms and their forbidden variants, question references, adoption language), each with its own filtered digest and its own `SCOPE.md` saying which half it is, and `manifest.json` tells the merger to expect both. Adoption language is in both, because a venue-versus-Code statement is both a value and a citation.

**Spawn every reviewer with the prompt above**, its placeholders filled with that pack's files, and the `SCOPE:` block from the pack's `SCOPE.md` inserted immediately after `UNDER REVIEW`. `New-ReviewPack.ps1` fills the block; this is its shape for a topic reviewer:

```
SCOPE: Topic {N} - {TITLE}
PACK DIRECTORY: {PACK_DIR}   (read SCOPE.md there first; it lists every file and what it is)
YOU OWN: the Topic {N} slice of the Learner Guide (sub-sections {SUBS}); deck slides {SLIDES}; figure slots {SLOTS}. Every check in this checklist, on that material: provenance of every figure, the figure read, assessed-grid leakage, coverage depth, usability and pitch, and guide-versus-deck agreement inside the topic.
YOU ALSO HOLD, SHARED WITH EVERY REVIEWER: the guide's front matter and back matter; the shared orientation and briefing slides; the learner-facing assessment tools IN FULL - they are what the learner holds, and every cross-reference target must resolve in them; the unit extract; the Stage 3d allow-list.
FROM THE ASSESSOR GUIDES YOU HOLD ONLY: the regions for the tasks Topic {N} prepares - {TASKS} - cut at the documents' own task headings and bannered with the source line range. They are the benchmarks and checklists you need to judge leakage inside your own topic. No other task's benchmark is here.
YOU DO NOT HAVE: any other topic's prose, or the assessor-guide regions of any other topic's tasks. Cross-topic mirroring - a Topic 3 grid answered in Topic 5 - is checked mechanically by the mirror gate over the whole spine; it is not your job to hunt for it, and you could not from here. Do not go looking for it and do not infer it.
YOU STILL REPORT, IF YOU SEE IT: another topic's assessed task answered in your slice (class leak, naming the task - the learner tools you hold in full are enough to recognise one); a pack defect (upstream, listed separately, never as a guide defect); a defect in the front or back matter your topic relies on; an allow-list entry whose reason does not survive your read of the task text (class leak, quoting the reason).
THE CROSS-DOCUMENT REVIEWER OWNS: agreement across topics, scope statements, adoption relationships and the scenario clock. A disagreement inside your topic, or between your slides and your prose, is yours.
COVERAGE IS LOAD-BEARING: in findings.json coverage[], claim every KE and PE item - sub-points included, each on its own - that Topic {N} teaches, with anchors. The merger raises a High finding for any item no reviewer claims. Claim only what you found taught on the page; a heading is not coverage.
OUTPUT: write your report file in the pack directory FIRST and append as you go; then write findings.json beside it, reviewer "topic{N}", scope "Topic {N} - {TITLE}".
```

**The cross-document reviewer** gets the same prompt with this block instead, and reads no topic's prose:

```
SCOPE: cross-document agreement across all {N} topics
PACK DIRECTORY: {PACK_DIR}
YOU OWN: guide-versus-deck-versus-pack agreement across topics - every value, term, clause, question reference and scenario fact that appears in more than one place must agree everywhere, and a value both artefacts carry must be identical in both; scope statements (a duty stated two incompatible ways); adoption relationships (what the venue has adopted against what the Code requires, stated the same way in every place that states it); the scenario clock (dates, days, times and the production run, against the pack's own order form); question references (every cited item exists in the pack under that number, and the cross-reference table agrees with the chips and the assessment-link slides); locked terminology and its forbidden variants, everywhere.
YOU DO NOT REVIEW: any topic's prose for truth, depth, pitch or leakage. You do not have the prose; the topic reviewers own it. A figure-sheet value that disagrees with the digest is yours; whether the figure is true is theirs.
YOUR INPUTS: the LEARNER-facing tools only - agreement is between what the learner holds and what the guide and deck say, and the assessor guides are not learner-held; claims-digest.txt (every claim-bearing sentence from both artefacts with its locator, exact repeats collapsed with a count, and a values index showing where each distinct value occurs; sentences whose only claim is a correctly used locked term are dropped and counted in its header); the full figure sheet; figures.json (the classes and locators the build CLAIMS - verify against the pack, never accept); the unit extract; the full Stage 3d allow-list.
YOU STILL REPORT, IF YOU SEE IT: a pack defect (upstream, separately); an allow-list entry whose reason does not survive your read of the task text (class leak, quoting the reason).
COVERAGE: you teach nothing. Write coverage as an empty list and say so in the report.
OUTPUT: report file FIRST, appended as you go; then findings.json beside it, reviewer "crossdoc", scope "cross-document agreement".
```

**When the cross-document work is two reviewers.** Where the single `crossdoc` pack would exceed the budget, the cutter writes `crossdoc-values` and `crossdoc-refs` instead, each with the same prompt and its own block: `SCOPE: cross-document agreement - VALUES: numbers, temperatures, quantities, the scenario clock and adoption language, across all {N} topics` (reviewer `crossdoc-values`) and `SCOPE: cross-document agreement - REFERENCES: instrument citations, locked terms and their forbidden variants, question references, and adoption language, across all {N} topics` (reviewer `crossdoc-refs`). Each block names what the other half owns, and each digest carries only its half's categories. Neither half sees the other; the merger expects both.

**Isolation, in the split.** Reviewers never see each other's packs, each other's output, or the merged result. The merger is `scripts\Merge-AuditFindings.ps1` - a script - and it never summarises or rewords a finding. A summarising merger would be a ninth reviewer with sight of the other eight, which is exactly what the isolation rule forbids. What the merger does is arithmetic: it unions every reviewer's coverage claims against the unit extract and RAISES a High `not-taught` finding for any KE or PE item no reviewer claims; concatenates the findings; dedupes on (anchor, class), keeping the copy with the worst risk verbatim and listing the others on it; and sets each artefact's verdict to the WORST any reviewer gave it, floored to Partially Compliant where a High finding remains. It refuses a `findings.json` that does not meet the contract, and it refuses to merge at all while any expected reviewer has written none - seven of eight merged quietly is how an untaught topic ships. The expected set is read from the cutter's `manifest.json`, so when the cross-document work is two reviewers the merger waits for both.

**Cross-topic mirroring is the mirror gate's job.** A Topic 3 answer grid reproduced in Topic 5 is found mechanically by `scripts\Check-FigureMirror.ps1` over the whole spine, at Stage 3c and again after every remediation; that is why a topic reviewer no longer holds every benchmark, and why it is told not to hunt for what it cannot see. A reviewer that nonetheless sees another topic's assessed task answered in its slice still reports it, class `leak`, naming the task - the learner tools it holds in full are enough to recognise one. "Not my topic" is still not a disposition.

**Input slicing for the persona arm (Stage 5).** Where the personas face the same context limit, the student and assessor personas may each be run on topic halves (for a seven-topic unit, Topics 1 to 4 and Topics 5 to 7) and the trainer-cold persona on the deck only - the artefact that persona is defined against - with the union of the slices equal to the full artefact. **That is an input split, not a scope reduction**: every persona keeps its full brief on every slice, each slice is reported separately and merged by the same script, and no persona is excused any check because another slice "probably covers it". A persona run on one half that was never run on the other has not reviewed the document.

---

## Review discipline — non-negotiable

### Write the report file first, and append as you go
**Create the report file, write its header, the documents reviewed and your scope, and save it before you analyse anything.** Then append each section the moment it is finished — the provenance ledger as you build it, each finding as you confirm it. Never hold a review in memory and write it up at the end.

**Why this is a rule and not a preference.** On the build that produced this instruction the final audit ran three times: two runs died on a transport error part-way through the analysis, having written nothing to disk, and everything both had established was lost. Thirty-one minutes went to those two dead runs. The third survived only because it was restarted with instructions to write the report first and append as it went — and the addendum it wrote *after* its main body is what widened the worst finding in the build from five figures to six assessed tasks across both documents. A review that dies with nothing on disk did not happen.

If you are resuming after an interruption, read what you already wrote and continue from there. Do not start again.

`findings.json` is written **last**, from the finished report, beside it - never first and never instead. It is the report's structured shadow for the scripts that follow (Stage 6b arbitration, and the merger in the split mode); the report is the review. See *The structured output contract* below.

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

## What the gates have already done — and what that means for your attention

A mechanical gate band runs on the content **before** you see it, and again on the finished files. You are handed its output. This does not narrow your scope by a single item: everything the checklist asks for, you still judge. What it changes is where your effort goes — **from hunting to deciding.**

Read this section before you plan your review.

| You are given | What it already enumerates | What is left for you |
|---|---|---|
| **The figure sheet** — every planned visual as plain text: slot, caption, alt text, rows, nodes, items, slide bodies and speaker notes | That the figure content exists and what it says | Whether what it says is **true**, whether it matches its caption and alt text, and whether it hands over an assessed answer |
| **The provenance ledger** — every registry figure with its authority class and a locator naming a source document and a line or field | That each registered figure resolves somewhere | Whether it resolves to the **right** thing: the right instrument, the right scope, mandatory versus recommended, and whether unregistered figures exist that nobody classed |
| **The cross-reference index** — every internal reference resolved to its target | That no reference dangles | Whether the target actually **prepares** the question it claims to |
| **The pack hazard list** — numeral divergences, benchmark divergences and arithmetic mismatches found in the pack itself, each with a recorded handling decision | Which upstream defects were known before authoring | Whether the handling decision was **sound**, and whether any hazard was quietly inherited into the guide |
| **The channel manifest** — which content channels are in final form and which are still placeholders | Which parts of the document are real | A **disposition for every channel**: see below |
| **The leakage and mirror sweep output** — anchored candidate hits, by file, field and slot | Where wording and answer grids coincide with the assessment | Whether each hit is a **leak or a coincidence** — the sweeps report anchors and deliberately do not decide |
| **The Stage 3d allow-list** - every mirror and leakage gate hit a builder cleared, from `figures.json` (`mirrorAllow`, one entry per slot; `leakageAllow`, one per phrase), each with its written reason; in the split mode it travels as `allow-list.txt` in every pack, and where there are no entries the file says so | Which candidate hits were waived, and the reason recorded for each | Whether each **reason survives a read of the task text** - an entry is a claim to verify, not a verdict |

**Every allow-list entry is a claim, and you re-read it.** A cleared hit is a gate switched off at one point, by one person, for one stated reason. Open the task the entry names, read the row or the phrase against it, and decide whether the reason holds: one worked exemplar row is legitimate teaching, and a phrase the pack itself prints to the learner is not a leak - but a second worked row under the assessed column headings is the answer sheet whatever the entry says, and a phrase that occurs only in the assessor guide is assessor-only text whatever the entry says. Where you disagree, that is a finding of class `leak`, quoting the entry's reason, because an allow-list nobody re-reads is a way of turning a gate off, and the entries are surfaced to you for exactly this purpose. Where the list is empty or absent, nothing was waived: every gate hit still stands as a candidate.

**You must return a disposition for every channel on the manifest.** If a channel is marked *placeholder*, say so in your report and do not rate it. A channel you do not disposition is automatically re-queued for a later round, and delivery fails if any channel was never dispositioned in final form by anybody.

**A gate result is evidence, not a verdict, and it is never a reason to skip a check.** If a sweep reports clean and you find a defect of that class by reading, report the defect — and say the sweep missed it, because that is a finding about the gate and it is worth more than the one about the document.

---

## Read the figures — mandatory, and it is where the worst defect on record was found

**Read every figure as content.** Not as decoration, not as "a diagram illustrating the text". In this kind of guide a figure is usually a **native table of steps and values**, and it teaches as hard as any paragraph.

For every figure in the guide and every table on a slide, ask all four:

1. **What does it say?** Read the rows, the node labels, the caption, the alt text and the speaker note.
2. **Is it true, and does it agree with the pack?** A figure is a factual claim in a box.
3. **Does the caption and alt text describe what is actually there?** A caption naming the wrong pack item is a defect, not a typo.
4. **Does it hand the learner an assessed answer?** See immediately below.

### Does any figure or passage reproduce an assessed response grid?

**This is a required check with its own finding line, and it was missed for three consecutive audit rounds.**

The assessment gives the learner a table with the first column filled in and the rest blank, and asks them to complete it. **A figure, worked example, practical activity or slide that carries the same row labels with those columns filled in is the completed answer sheet.** Where the assessment is open book and expressly permits the Learner Guide — as it commonly is — the learner copies it straight across, and the assessment no longer assesses anything.

How it stayed hidden for three rounds, because the shape of the miss matters more than the instance:

- the guide is built with artwork **prompts** on the page and the pictures placed at the very end, so rounds one and two read a document in which every figure was still a prompt block;
- round one duly reported "every figure is missing" and was correctly told that was expected at that stage;
- **nobody drew the consequence — that the figures had therefore never been read by anyone.** Round three was the first audit ever to read them, four hours after they were written, and returned *Not Compliant, not for release* on six figures reproducing assessed grids, two of them under the task's own column headings verbatim;
- and the leak had been **manufactured by an earlier correct remediation**. Round one had rightly found assessed rows taught too thinly; the fix filled the grid in. Coverage pressure and leakage pressure act on the same table, and satisfying one can create the other.

So, for every assessed response grid in the pack:

- find where the guide **teaches** every row — thin coverage is still a defect; and
- confirm that no figure, table, worked example, activity, slide, chip, caption, alt text or speaker note **presents those rows as a completed grid**.

Both, in one verdict, on the same table. Reporting one without the other sends the build round the loop again.

**What is not a defect.** Sharing the row *labels* is fine — the task prints them itself. **One** worked exemplar is legitimate teaching. What makes it the answer sheet is the assessed **columns** being filled in, and more than one row answered across a sub-section. Where a figure withholds a row honestly, check the deck does not fill the same row in: one artefact defeating the other's withholding is the same defect wearing a different hat.

---

## The five layers

**1. Training-product alignment** — every Element, PC, Foundation Skill, PE item and KE point, including sub-points, that the pack assesses is taught somewhere in the guide, at the depth the AQF level demands. Nothing is taught that lies outside the unit's scope.

**2. Factual, legislative and jurisdictional accuracy** — the heavy layer for this document type. Every figure, threshold, duration, temperature, percentage, dollar amount, count, regulator name, standard number, form name and legal proposition.

**3. Assessment alignment** — the guide prepares the learner for the instrument that actually exists. Every question it cites is in the pack. Every question in the pack is prepared somewhere. No model answer to a pack question appears anywhere in the guide or the deck, **and no figure, table or slide reproduces an assessed response grid with its assessed columns filled in.**

**4. Learner usability and AQF pitch** — readable at the level, scaffolded, terminology introduced before it is used, assessed terminology never simplified away, LLN and EAL load reasonable.

**5. Standards for RTOs 2025** — the outcome standards governing training delivery and the sufficiency of learning resources.

> **Verify the exact Outcome Standards numbering and wording before relying on a standard number, and cite only a standard you have checked.** Do not casually assign an unrelated number to give a finding weight it has not earned. Where you are confident of the obligation but not the number, state the obligation in words and say the number is unverified. That is a stronger finding than a wrong citation, and this checklist would rather have it.

---

## The provenance audit

**The centrepiece. Run it before any other analysis — after opening your report file — because most other findings fall out of it.**

Build a ledger of **every** numeric claim and every legal proposition in the guide and the deck. Include: temperatures, times, durations, percentages, dollar amounts, counts, volumes, weights, ratios, ages, distances, retention periods, standard numbers and named legal duties.

For each one, assign exactly one **authority class**:

| Class | Means | Test |
|---|---|---|
| **P** | It comes from the assessment pack | Find it in the pack, verbatim. The pack is upstream and wins. |
| **U** | It comes from the unit | Find it in your own extraction from training.gov.au. |
| **L** | It comes from legislation, a standard or a code | Cite the instrument, the clause and the jurisdiction. Verify against the current source, not memory. |
| **V** | It is the scenario venue's own documented procedure | The page must say so, in the learner's sight. |

**A figure that fits none of the four classes is fabricated.** That is a High-risk defect, regardless of how reasonable it looks. Plausibility is not provenance.

### Every row carries a locator, and a condemnation carries a search

**A row marked source-attributed must carry a quotable locator** — the document, and the line, field or clause where the value sits — and the quoted string must actually occur there. "Verified against the pack" is not a locator. The value of this ledger is that another person can re-run it without repeating the reading.

**And the test runs in both directions, because this audit has failed in both.** On one build, round two certified a batch weight as pack-sourced and invented a quotation to support it; round three then declared the same value fabricated. **Round three was wrong** — the value is stated in the recipe card's own Portion size field, in the extract the reviewer had been handed, and the same line appears in the assessor guide. The false finding cost a full round, remediated a correct slide on a false premise, and left behind a permanent build rule forbidding a value the pack states, which would have failed every future build that taught the recipe correctly.

So:

- **Before you rate a figure fabricated, search the supplied sources for it** — the pack, the unit, the instrument you believe it comes from — and **record what you searched.** State it in the row: *"searched pack (both learner tools, both assessor guides) and unit extract; not present."*
- **A derived figure is not a fabricated one.** Where a value is computed from figures the pack states, say so and name the inputs, and check the arithmetic. A derivation whose inputs all resolve is sound provenance; a derivation whose inputs do not resolve is the defect.
- **Never propose a rule forbidding a literal that occurs in a source document.** If your finding requires the build to forbid a string the pack itself carries, the finding is wrong. Re-read the extract.

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

| Figure | Where it appears | Class | Source **and locator** | Mandatory or recommended | Applies to | Searched (where a value did not resolve) | Verdict |
|---|---|---|---|---|---|---|---|

**A "verified" row is as much a required output as a defect row.** The value of the ledger is that it is complete.

**Start from the provenance ledger you were handed and extend it.** It carries the registered figures with their classes and locators already resolved. Your work is the figures that are *not* on it — the registry on the build that produced this instruction listed 31 figures against 112 captioned figures in the document, and its own header said that a figure not in the registry is a figure nobody is checking. **The unregistered figures are where your attention buys the most.**

---

## Method

### Step 0 — Open the report file and write the header
Before anything else. See *Write the report file first* above. Then append as you go.

### Step 1 — Extract the training product exactly
Verbatim, from your own browser session: every Element, PC, Foundation Skill, PE item and KE point **and every sub-point**. Never silently collapse a sub-point into its parent.

**Where an independent extraction for this unit release already exists**, taken by an agent with no build context and archived as an audit artefact, use it — it is your own extraction, not the build's, and the transcription-error check it exists for is intact. In that case **re-verify the currency only**: usage recommendation and release, on the day, from training.gov.au. Do not re-transcribe a document that has not changed; that effort belongs to the figures.

### Step 2 — Run the provenance audit
As above, starting from the ledger you were handed and extending it to the figures nobody registered. Do this before reading the guide for coverage, so you read the content already knowing which of its numbers you have verified.

### Step 3 — Coverage
For every KE point and PE item the pack assesses: find where the guide teaches it. Confirm it is explicitly taught, not merely mentioned; that breadth matches the requirement and depth matches the AQF level; and that the terminology is the unit's.

**A topic heading is not coverage.** The learner must be able to answer from what is on the page.

### Step 4 — Assessment alignment, both directions
- Every question the guide or deck **cites** exists in the pack, with that number. *(The cross-reference index you were handed resolves the references; what it cannot tell you is whether the target actually prepares the question. That is your judgement.)*
- Every question in the pack is **prepared** somewhere in the guide.
- **No model answer, benchmark, marking guide or assessor-only note appears in either learner-facing document.** A guide that answers the pack's questions destroys the assessment it was built to support.
- **No figure or passage reproduces an assessed response grid.** See *Read the figures* above. This is the check that was missed three rounds running.

**A verbatim sweep has already run** over every channel of both artefacts, and you have its anchored hits. Adjudicate them — each one is a candidate, not a verdict. Then spend your own reading on what a string sweep structurally cannot see: **the model answer handed over in the author's own words, and the assessor's own bullets reproduced in the assessor's own order.** That second one is real; it was found in running prose, five consecutive bullets deep, by a reviewer who read rather than searched.

### Step 5 — Cross-document consistency
Guide against deck, guide against pack, deck against pack. Figures, terminology, counts, thresholds, scenario facts, venue name, character names, question numbers, sub-section numbering.

**The registry gate has already swept the registered figures across both artefacts**, so a stale registered value in one and a corrected one in the other has been enumerated for you. Your reading is for the inconsistencies a registry cannot hold: a duty cited to two different clause numbers, a scope statement made two incompatible ways, a caveat present in two places and absent from seven others, a scenario whose dates do not survive contact with the pack's own order form. **One of those — an inverted scope statement — survived all three audit rounds on the build that produced this checklist**, because each round found it in a different place and fixed that place.

### Step 6 — Visuals
Every figure, diagram and table — read as content, per *Read the figures* above, which is where the requirement is set out in full. Does the image show what its caption and alt text claim? Does it contradict the text it illustrates, or contradict something the guide teaches elsewhere? In a compliance-bearing subject, an image showing a practice the document forbids is a defect on the page, not a styling quibble.

**If any figure in your extract is still an artwork prompt block rather than a picture, say so in your report and disposition that channel as a placeholder.** Do not treat "the figures are missing" as a stage artefact you can set aside and move on from: on the build this rule comes from, that reasonable dismissal is exactly what let six answer-grid figures reach hour four unread. If the pictures are not there, read the figure sheet — the content is in it, and it is the same content.

### Step 7 — Usability and pitch
AQF level, reading load, scaffolding, terminology introduced before use, whether a learner could work through it unaided. Assessed terminology is never simplified — flag any place it has been.

### Step 8 — Document control
Version, date, unit code and release on the artefact; footer attribution; the deck's slide numbering matching its actual positions; the PDF no older than the file beside it.

**Counting slides and comparing file times is a gate's job and it has already been done.** What is left is the part a gate cannot rule on: whether the document-control block **says what the RTO's own standard requires it to say**, and whether the artefact you are holding is the one the record describes. Three consecutive audits on one build could only record the document-control block as *not verifiable*, because the standard it must meet had never been written down. If it is still not verifiable, **say so as a finding** rather than passing over it.

### Step 9 — Say what you did not check, and why
Close the report with the scope you did **not** cover and the reason: a channel still in placeholder form, a resource not supplied, a standard number you could not verify. An audit that lists its own blind spots is worth more than one that implies it had none — and it is what stops a later round assuming a thing was checked when it was not.

---

## Risk rating

**High / Critical** — a fabricated figure with no traceable source · a recommendation taught as a legal requirement, or a requirement taught as optional · a real figure attached to the wrong subject · a guide figure contradicting the pack · a cited question that does not exist in the pack · an assessed KE or PE item taught nowhere · a model answer or benchmark leaked into a learner document · **a figure, table, activity or slide that reproduces an assessed response grid with the assessed columns filled in** · **one artefact filling a row the other honestly withholds** · superseded legislation or the wrong jurisdiction or regulator · content taught that is outside the unit's scope · a visual contradicting a compliance requirement the document teaches.

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
- **A completed version of an assessed response grid anywhere in either document** — most of all where the assessment is open book and permits the guide
- **A figure nobody has classed** — an unregistered figure is one nobody is checking
- Assessor marking vocabulary in a learner document: *benchmark*, *mark NS when*, *minimum acceptable*, *a satisfactory answer covers*, or a speaker note telling the learner what the task is marked against
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
6. **Check what the correction created.** A remediation that fixes thin coverage by filling an assessed grid in has traded a Medium for a High. Coverage pressure and leakage pressure act on the same table, and on the build that produced this checklist the two corrections that satisfied round one are precisely what round three found as the worst leaks in the document. Read the figures the remediation touched, not only the prose.
7. Re-check cross-document consistency
8. **Confirm the artefact you are reading postdates the last change to it.** If the documents were re-rendered or the artwork re-placed since the previous verdict, that verdict describes a document that no longer exists, and your read must be against the current files.
9. Then issue the new overall judgement

---

## Required output

Write section 2 first, before you analyse. Append the rest as each is finished.

1. **Overall judgement** — Fully Compliant · Partially Compliant · Not Compliant, stated separately for the guide, the deck, and the pair as a delivery set
2. **Documents reviewed** — every file and version, **plus the channel manifest with your disposition against every channel**
3. **Training product summary** — unit, release, usage recommendation and date checked, qualification, AQF level
4. **The provenance ledger** — complete, every figure, verified rows included, **each with its locator**, and each unresolved value with the search that failed to find it
5. **The figure read** — every figure and slide table, what it says, and whether it reproduces an assessed response grid. **Required, even where the answer is no.**
6. **Coverage matrix** — KE/PE item → where the guide teaches it → which question it prepares
7. **Cross-document consistency findings**
8. **Findings table** — origin, risk rating, evidence, replacement wording
9. **Upstream findings against the pack**, listed separately and never mixed with guide findings
10. **Scope not covered**, and why
11. **The decision**
12. **`findings.json`** beside the report, per *The structured output contract* immediately below. Required in both modes: it is the file the arbitration and the merger read.

---

## The structured output contract - findings.json

**Required in both modes, beside the markdown report, written last, from the report.** The report is still written first and appended as you go - see *Write the report file first* - because a review that dies part-way must leave what it established on disk. `findings.json` is the structured summary of the finished report that the mechanical stages consume: Stage 6b arbitration (`Test-Finding.ps1`) reads every finding's `class`, `value` and `source` to grep the corpus before a finding can become a work order, and in the split mode `Merge-AuditFindings.ps1` reads every reviewer's file. A finding that is in the report and not in `findings.json` reaches neither. Every finding in the report appears in the JSON, one to one, with the same anchor and the same replacement wording.

```
{
  "reviewer": "topic3",                       single-reviewer mode: "cleanroom"; split mode: "topic{N}" or "crossdoc"
  "scope":    "Topic 3 - Portion and prepare bulk ingredients",
  "verdict":  { "guide": "Partially Compliant", "deck": "Fully Compliant", "deliverySet": "Partially Compliant" },
  "findings": [
    {
      "id":             "H-1",                your own numbering, unique within this file
      "risk":           "High",               High | Medium | Low
      "class":          "wrong-value",        exactly one of the class names below
      "claim":          "what the document says, quoted",
      "value":          "the figure, term, clause or reference at issue, as it appears",
      "where":          { "artefact": "guide", "locator": "3.2, Figure 3.2.2, row 4" },
      "source":         { "doc": "SITHCCC032_Recipe_Workbook.txt", "locator": "recipe 2094, Portion size" },
                                              or null where nothing resolves - and then the report records the search
      "replacement":    "the corrected text, ready to paste, in the guide's voice",
      "proposedForbid": []                    literals the build should forbid from now on - never one a source document carries
    }
  ],
  "coverage": [ { "item": "KE5", "anchors": ["3.2 Underpinning knowledge", "Figure 3.2.4"] } ],
  "channels": { "guide body": "final", "guide alt text": "final", "deck notes": "final" }
}
```

**`class` - exactly these names.** They are the names Stage 6b arbitration (`Test-Finding.ps1`) consumes, and a class it does not recognise is a finding it silently skips; the merger refuses a file that uses any other.

| class | Means |
|---|---|
| `fabricated` | a figure that fits none of P, U, L or V - and you searched for it, and the search is in the report |
| `unsourced` | a figure a source states but the page does not attribute |
| `misattributed` | a genuine figure attached to the wrong instrument, the wrong weight (a recommendation as law, or the reverse) or the wrong subject |
| `wrong-value` | the guide or deck states a value that the pack, the unit or the instrument states differently |
| `wrong-clause` | the right duty cited to the wrong standard, clause, regulator or jurisdiction |
| `leak` | a model answer, benchmark, assessor-only text or completed assessed grid in a learner artefact - including one artefact filling a row the other withholds, and an allow-list entry whose reason does not hold |
| `not-taught` | an assessed KE or PE item, or an assessed row, taught nowhere or too thinly |
| `missing-target` | a cited question the pack does not contain, or a pack question that nothing prepares |
| `other` | everything else - usability, pitch, document control, a visual, a preference (and a preference is never High) |

**`verdict`** is `Fully Compliant`, `Partially Compliant` or `Not Compliant`, stated for `guide`, `deck` and `deliverySet`; a single string is accepted and applies to all three. In the split mode a topic reviewer's verdict is a verdict on its slice, and the merger takes the worst per artefact.

**`coverage`** lists every KE and PE item **you found taught** on the material you hold, by the identifier the unit extract uses (`KE2a`, `PE1c`), each sub-point on its own, with anchors. Never collapse a sub-point into its parent. In the split mode this list is load-bearing: the merger raises a High `not-taught` finding for any item no reviewer claims, so a claim you cannot anchor is a claim you do not make. The cross-document reviewer writes `[]`.

**`channels`** is your disposition for every channel on the manifest - `final`, `placeholder` or `not supplied`. A channel you do not disposition is re-queued.

**`where.locator`** is what the merger dedupes on and what remediation works from: sub-section, figure number, slide number, row, or a quoted phrase. In the split mode never a line number of a slice, because the slice's line numbers are not the extract's.

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
8. **no figure, table, activity or slide reproduces an assessed response grid, and you read the figures to be sure of it**
9. **every channel on the manifest was in final form when you read it, and you dispositioned each one**
10. the guide, the deck and the pack agree on every figure, term and count
11. visuals are consistent with the text and with the compliance content
12. legislation, regulators and jurisdiction are current and correct
13. no High-risk defect remains

**Point 8 and point 9 are not optional and they are not satisfied by a gate result.** A build shipped once on a verdict issued against a document that contained no figures at all. If you have not read the figure content yourself — in the document or in the figure sheet — you cannot sign this off, and you should say so instead.

**Where the pack was not supplied, or was supplied incomplete, do not overstate the conclusion:**

> **Guide compliant on its own terms; alignment with the assessment instrument remains unverified pending review of the pack.**

---

## What not to do

Do not: accept a figure because it is the one everybody uses · treat industry custom as a legal requirement · cite an Outcome Standard number you have not verified · report a pack defect as a guide defect · judge coverage from a cross-reference table alone · accept a topic heading as evidence of depth · simplify assessed terminology and call it a usability improvement · invent legislation, regulators, standard numbers or processing times · rate a cosmetic preference High · state page-layout defects on an unrendered file · reverse a correct earlier finding because a later revision merely looks tidier.

And three more, each of which cost a full remediation round on the build that produced this checklist:

- **Do not call a figure fabricated without searching for it and recording the search.** One reviewer did, on a value the recipe card states in its own field, and the build spent a round correcting a correct slide.
- **Do not set missing figures aside as a stage artefact.** If the figures are not in the document, read the figure sheet and report the channel as a placeholder. "The pictures are not placed yet" is a fact about the file, not permission to leave the figures unread.
- **Do not report a defect class from a single instance.** Say plainly that it is a class, and name every place you found it. A fix that lands where the finding pointed and nowhere else is how the same defect survives three rounds — it was corrected in the front matter, missed in all eight rows of a cross-reference table, and missed again in the deck's closing note.

---

## Closing instruction

Perform the review like an external validator preparing evidence for an ASQA audit.

A strong review of a learning resource **traces every number to a source**, **reads the figures as content**, distinguishes what the law requires from what a regulator recommends and from what a venue has chosen, verifies that the resource prepares the learner for the instrument that actually exists — and does not hand the learner its answers — separates its own findings from the pack's, gives replacement wording, and **states clearly when no further defect remains.**

It also **writes itself down as it goes**, so that a review which is interrupted is a review that can be resumed rather than one that never happened.

End with a defensible compliance decision.
