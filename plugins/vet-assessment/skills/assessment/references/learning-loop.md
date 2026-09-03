# The learning loop — Stage 9

**Every build teaches this skill something. Almost none of it belongs in this skill.**

The loop exists because the same defects kept recurring across builds — a figure invented in one file and contradicted in another, a benchmark that never met the simulation it marks, a gate written a round too late. Those are process defects, and a process defect that is only ever fixed in the pack will be back in the next pack.

But an unguarded write-back is worse than no loop. A skill that grows by one rule per build becomes a skill nobody reads, and a rule nobody reads is a rule that does not run. **The loop's job is to be selective, not comprehensive.**

Runs after Stage 8, once the pack is delivered. **Nothing is written to the skill without the user's approval.**

---

## 1. The findings register is the loop's input

The register is written **during** the build, not reconstructed at the end. Reconstruction loses the two things that matter most: what a finding cost, and whether the skill already warned about it.

`findings-register.md`, in the build directory, one row per finding from every source — the derived gate, the flow pass, each persona, each clean-room audit round, and **the build's own rework**. That last source is the one that gets forgotten and it is the richest: a stale guard, a mis-scoped instruction to an agent, an assumption that had to be undone.

| Column | Why |
|---|---|
| Source | Which reviewer or gate found it, or `build` where nothing found it and it simply cost time |
| Round | 0 for pre-review, then 1, 2, 3 |
| Finding | One line |
| Severity | As the finder graded it |
| Disposition | Fixed · fixed with a decision recorded · not fixed with a reason · false positive |
| **Cost** | Rounds it added, or minutes of rework. This is what ranks the amendments |
| **Already written down?** | Yes, and where — or no. **This decides the fix.** See §3 |

---

## 2. Classify every finding. Four destinations, and only one is the skill

Work through the register and put every row in exactly one bucket.

| Destination | Test | Example from SITXINV007 |
|---|---|---|
| **The compliance report** | A defect in *this pack* or in *this RTO's artefacts*. Already handled at Stage 8 | The cover sheet's ungrammatical re-sit sentence |
| **The house profile** | A structural or measured position **this RTO** should ratify. An order change, a locked figure, a template patch | Appendices added to the `uatCombined` order |
| **Memory** | A fact about *this machine, this RTO or this operator* — not about how assessments are built | Word COM failing on OneDrive-synced paths |
| **THE SKILL** | Both of: the skill's own instructions **caused or failed to catch** it, **and** it would recur on an unrelated unit for an unrelated RTO | Parallel agents diverging on a figure the contract never fixed |

**If a finding fails either half of the skill test, it does not touch the skill.** A defect the skill already prevents on any other unit is a build error, not a skill error. A defect that only arises from this scenario's arithmetic is content, not process.

Rank what survives by the **Cost** column. A finding that cost a remediation round earns an amendment; a finding fixed in one edit rarely does.

---

## 3. The recurrence question decides what kind of fix it needs

**Before proposing any amendment, ask: was this already written down somewhere in the skill?**

The answer changes the fix completely, and getting it wrong is how a skill accumulates prose that does not work.

| Already written down? | What that means | The fix |
|---|---|---|
| **No** | A genuine gap | Add the rule, in the file the relevant stage already reads |
| **Yes, and it was read** | The rule was followed and was **wrong or incomplete** | Correct the rule. Do not add a second one beside it |
| **Yes, but in a file that stage does not read** | A routing failure | **Move it**, or add a pointer from the stage that needs it. Adding a duplicate is the wrong fix |
| **Yes, read, correct — and it happened anyway** | **Prose failed.** This is the most important case | **Make it executable.** A rule that is followed only when remembered is a rule that will be forgotten. Turn it into a gate, a schema field, or a required artefact |

That last row is the one that pays. On SITXINV007, *"a figure that lives in one place cannot drift"* was already in `house-standard.md`, and the figures drifted anyway — because the rule was prose and nothing computed it. The fix was not to restate it. It was `worldFacts` (a schema field the agents receive) and the derived gate (a script that recomputes every figure). **Prefer a gate to a paragraph, a schema field to an instruction, and a required artefact to a reminder.**

---

## 4. Amendment discipline

A skill that only grows becomes unreadable, and an unread rule does not run. Every proposed amendment obeys these.

- **Amend an existing line before adding a new one.** Two rules on one subject is how contradictions start.
- **Put it where the stage that needs it already reads.** A rule in a file that stage does not open has not been added; it has been hidden.
- **Name the evidence.** Every amendment carries the unit, the finding and what it cost. A rule with no incident behind it is a guess, and guesses are what make skills long.
- **Look for what it retires.** Every amendment must be checked against the rules it supersedes, and those must be deleted or marked closed in the same pass. `house-standard.md`'s two closed source-defect warnings are the pattern.
- **Pay for growth.** Measured **per amendment**, against the file as it stood before that amendment. Where `SKILL.md` would pass **40 KB**, or a single amendment would grow any reference file by more than a quarter, it must be paid for by a consolidation or a deletion in the same edit. Length is a cost, not a virtue.

  A **commissioned redesign** — the user asking for a structural change rather than the loop proposing one — is exempt from the per-amendment test, because its size is the point. It is not exempt from being **declared**: state the file, the before and after, and why the growth is load-bearing rather than accretion. `section-contract.md` grew from 14 KB to 22 KB on 3 September 2026 for `worldFacts`, the interlock rule and the derived-gate spec. That was commissioned and is declared here.

  **A consolidation that removes a duplication but not the bytes is still worth making** — routing beats byte count, and a rule stated in two files will diverge. Say which it achieved rather than claiming both.
- **Never encode a scenario.** A venue, a product, an arithmetic chain or a figure from one build is content. The transferable form is the *class* of defect, never the instance.
- **One exception is worth more than one rule.** Where a build shows a rule was right but its exception was missing, add the exception to the existing rule rather than writing a new rule about the exception.

---

## 5. The procedure

1. **Read `findings-register.md`.** Add any build rework that no reviewer found — this is the step most easily skipped and the one that carries the process defects.
2. **Classify every row** against §2. Most rows leave the skill's scope here.
3. For each survivor, **answer the recurrence question** in §3 and decide the *kind* of fix.
4. **Draft each amendment as an exact change** — file, the text now, the text proposed, the evidence, and what it retires.
5. **Put them to the user, ranked by cost, with a recommendation on each.** Say plainly which you would not make, and why. A short list you believe in beats a long list you do not.
6. **Apply only what the user approves.** Re-read each edited file afterwards and confirm the change did not contradict a rule elsewhere in it.
7. **Record the closed loop in the compliance report** — what was proposed, what was approved, what was declined and on whose reasoning.

---

## 6. What never enters the skill

Stated plainly, because each of these is tempting in the moment.

- **A finding the user overruled.** Their decision is recorded in the report, not encoded as a rule.
- **A one-off tool or model failure** — a rate limit, a timeout, a transient API error.
- **Anything about a specific unit, qualification, venue, product or figure.**
- **A preference with no defect behind it.** "It would read better if" is not evidence.
- **A rule that contradicts a measured house profile.** The profile is measured from the RTO's artefacts; the skill does not overrule it. That is a profile amendment, and it belongs to the RTO.
- **A second statement of a rule that already exists.** Fix the original or move it.

---

## 7. Report the loop, even when it changes nothing

A build that proposes no amendment is a good result and should say so: it means the skill held. Report the count classified to each destination, every amendment proposed, and the disposition of each.

**A run that proposes an amendment for every finding has not classified them.** Expect most builds to yield none or one.
