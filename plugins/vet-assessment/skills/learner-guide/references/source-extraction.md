# Source extraction — reading the assessment pack, then the unit

The pack is read **first**, because it fixes the question numbers everything else hangs off. The unit is read second, to confirm the pack covers it and to supply the Element/PC wording the guide's structure follows.

---

## 1. What to collect from the pack

Read every learner-facing instrument and every assessor-facing one that affects what a learner must know:

- the knowledge tool (UAT 1, or Section A of a combined UAT)
- the performance tool (UAT 2, Section B, the recipe workbook, observation checklists)
- the assessor guides, for the model answers — **which tell you what depth the teaching has to reach**
- any controlled resource pack, policy, procedure or dataset the learner is expected to use

### The question bank

For every question, capture verbatim:

| Field | Why |
|---|---|
| Number, **including sub-parts** — `Q9(b)`, not `Q9` | The chip and the cross-reference must match the paper exactly |
| The stem as written | So the guide teaches the thing actually asked |
| KE mapping | To place it against a PC sub-section |
| Word guide / expected length | Sets how much teaching the topic owes it |
| The model answer, where the assessor guide carries one | **The single best guide to required depth** |

**Sub-parts are separate questions for cross-reference purposes.** A guide that says "prepares you for Q9" when only Q9(b) is taught in that sub-section is imprecise in exactly the way that wastes a learner's revision.

### The practical side

Every task, every observation item, by number. A performance item is signposted with `Assessed in: UAT 2 — Task 2` or the observation number, in the same wording the guide's Assessment Prompts use.

### The scenario world

Capture and **reuse**: the venue, the named characters and their roles, the employer, the locations, the house policy. **Never invent a second scenario world.** A guide set in a different venue from its assessment reads as a different unit, and the learner cannot tell which facts carry across.

Where the pack's scenario is thin, extend it consistently rather than replacing it, and say in the report what was added.

---

## 2. What to collect from the unit

`https://training.gov.au/training/details/{UNITCODE}/unitdetails`, in a **JavaScript-capable browser**. `WebFetch` and `curl` return an empty shell.

Capture verbatim, every bullet and sub-bullet: Elements, Performance Criteria (verbs and qualifiers intact), Performance Evidence, Knowledge Evidence (every parent dot point **and** every sub-point), Foundation Skills in the unit's own wording, and Assessment Conditions.

**Two hard gates, unchanged from the assessment skill:**

- **Currency.** If *Usage recommendation* is not `Current`, stop and report the superseding unit. Teaching resources for a superseded unit are worse than none.
- **AQF level.** Read every qualification the unit is packaged into. If they span more than one level, stop and ask. The reading level of the whole guide is set from it — see the ACSF table in the shared house-style block — so guessing sets every sentence in the document to the wrong register.

Never silently collapse a KE sub-point into its parent. The guide's coverage claim is made per sub-point.

---

## 3. Reconcile, and state it back

Build the map and **state it back before writing anything**:

```
PC 1.1  ->  KE 1, KE 3   ->  UAT 1 Q5, Q6      ->  Topic 1, sub-section 1.1
PC 1.2  ->  KE 2         ->  UAT 1 Q9(a), Q9(b) -> Topic 1, sub-section 1.2
PC 2.1  ->  KE 4         ->  UAT 2 Task 1, Obs 3 -> Topic 2, sub-section 2.1
```

Every question lands in exactly **one** primary sub-section. It may be signposted elsewhere, but "where is this taught" needs one defensible answer.

### What to flag rather than fix

This skill does not edit assessments. Where the reconciliation exposes a problem, record it in the report and carry on:

- a **KE item no question assesses** — a coverage gap in the pack, not something the guide can close
- a **question mapped to a KE item it does not actually test**
- a **question that cannot be answered from anything the learner is given** — the answerability defect the compliance handover treats as High risk
- a **figure, threshold or count that differs between two instruments** — teach the one in the learner-facing tool and flag the conflict

**Do not teach around a defect silently.** A guide that quietly supplies the data a question is missing makes an unanswerable question look answerable, and the defect survives into the next validation.

---

## 4. The dependency direction

The assessment skill's standing rule is *never fact-check an assessment against a Learner Resource* — the resource is written after the assessment and derived from it, so checking against it inverts the dependency and launders errors.

This skill is the downstream side:

- Guide and pack disagree on a figure, term, count or threshold: **the pack wins**, the guide changes.
- The guide needs a fact the pack does not carry: source it from the unit, the legislation or the RTO's procedure, and **flag it as content the assessment does not cover**.
- The pack looks wrong: **say so**. Fixing it is the other skill's job.
