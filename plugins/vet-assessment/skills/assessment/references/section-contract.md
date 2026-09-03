# The build contract and the content-agent brief

Parallel agents write **content**. One deterministic assembler builds the **document**. This file defines what the agents receive and what they must return.

The rule that makes parallel generation safe: **everything shared is locked before the fan-out.** Flow is not something the writers negotiate between themselves — they cannot see each other. It comes from all of them reading the same contract.

---

## Concurrency

The cap is `min(16, CPUs - 2)`. On a 6-CPU machine that is **4 agents at a time**.

This inverts the obvious approach. One agent per question does not give twelve-way parallelism — it gives three queued waves of four, plus twelve sets of context to build and twelve chances to drift.

**Wave count is the cost, not agent count.**

Batch so that:
- The batch count lands near a multiple of the cap
- Batches are similar in size, so no wave waits on one straggler
- Related items sit in the same batch — they share context inside the agent, which helps flow

Working default for a typical unit: **three questions per agent, one or two tasks per agent**. Twelve questions and three tasks becomes six batches — still two waves at a cap of four, not four waves of singletons.

**That default is a ceiling on batch size, not a licence to split anything.** The rule below overrides it wherever the two disagree.

### Never split an interlocking cluster across agents

Wave count is the cost, but **divergence is the defect**, and it beats wave count every time. Two agents editing files that must agree will disagree, because neither can see the other's output. This is the single largest source of rework in this skill's history — on SITXINV007 it cost two extra remediation rounds and about ninety minutes.

**These clusters go to ONE agent, however large that agent's slice becomes:**

| Cluster | Why it cannot split |
|---|---|
| **The setup pack + the observation instrument** | The staged cues, the delivery timeline, the contingent trigger and the checklist items that judge them are one mechanism. Split them and the pack stages a fault on a day the good does not arrive, or a checklist item demands a response the staging makes impossible |
| **The appendices + every task that reads a figure from them** | A task that states a rate, a price or an order unit the appendix does not carry is a contradiction on the page. Where the tasks are too large for one agent, the appendices go FIRST, alone, and the task agents read the finished file |
| **A benchmark + the thing it marks** | A model answer written by one agent and a staged condition written by another will accept what the other stages to fail |
| **Any two files that share a computed figure** | The forecast chain, the money, the counts. One agent owns the arithmetic |

**Genuinely independent content still parallelises.** Section A knowledge tasks that cover different Knowledge Evidence points share only the scenario card, so four agents on ten questions is correct and safe.

**The test before you fan out:** for each pair of agents, ask *"could these two return outputs that are each correct alone and contradict each other?"* If yes, they are one agent.

---

## The contract

Produced once, in the same pass as the assess-once register. Handed identically to every content agent.

```json
{
  "brand":         "MVC",

  "unit":          { "code": "", "title": "", "release": "", "usageRecommendation": "Current" },

  "qualification": {
    "code":          "",
    "title":         "",
    "aqfLevel":      0,
    "aqfSource":     "unambiguous | user-chosen",
    "allPackagedInto": [ { "code": "", "title": "", "aqfLevel": 0 } ]
  },

  "workbookMode":  "recipe | simulated",

  "scenarioCard": {
    "business":     "Name, type, size and location of the venue",
    "learnerRole":  "The position the learner holds",
    "people":       [ { "name": "", "role": "" } ],
    "documents":    [ "Procedures, plans, registers, forms and specifications available" ],
    "constraints":  [ "Volume, time, access, budget, conditions" ],
    "situation":    "What is happening on the day"
  },

  "worldFacts": {
    "_comment": "THE CONSEQUENCES. Computed at Stage 2, before any agent runs. See 'Lock the consequences, not just the scenario' below. Omit only where the unit has no arithmetic and no timeline.",
    "timeline":     [ { "when": "", "what": "", "carries": "" } ],
    "computed":     [ { "figure": "", "value": "", "workings": "", "source": "" } ],
    "stagedEvents": [ { "event": "", "when": "", "attachesTo": "", "resolvesHow": "" } ],
    "groupings":    [ { "grouping": "", "members": [], "total": "", "consequence": "" } ],
    "thresholds":   [ { "limit": "", "value": "", "whatCrossesIt": [] } ]
  },

  "terminology": {
    "preferred":    { "concept": "the one word to use for it, every time" },
    "assessedTerms":[ "terms the unit assesses - never simplify these" ],
    "glossary":     { "term": "plain-English definition" }
  },

  "styleCard": {
    "acsfLevel":        4,
    "maxSentenceWords": 20,
    "voice":            "active, second person",
    "wordGuideScale":   "how to size a word guide against the evidence point",
    "responseSpaceRule":"one labelled space per answerable part, never shared"
  },

  "assignment": [
    {
      "id":           "Q3",
      "kind":         "frontMatter | question | task | checklist | recipeCard | observationSheet | theoryQuestion | caseStudy",
      "document":     "uat | recipeWorkbook | assessorPack",
      "title":        "",
      "covers":       [ "KE 2.1", "KE 2.2" ],
      "wordGuide":    "150-200 words",
      "notes":        "anything specific to this item"
    }
  ],

  "numberingPlan": {
    "questions":  [ "Q1", "Q2", "Q3" ],
    "tasks":      [ "Task 1", "Task 2" ],
    "taskParts":  { "Task 1": [ "a", "b" ] },
    "checklists": { "Observation 1": [ "Task 1" ] }
  }
}
```

### Lock the consequences, not just the scenario

**`scenarioCard` stops one step short of where the defects are.** It fixes the venue, the cast, the documents and the constraints — so no agent invents a person or a form. It does not fix what those constraints *imply*, so every agent computes the implications separately and they disagree.

On SITXINV007 the card fixed six goods, four suppliers, a $2,400 budget, a $500 approval limit and Monday/Wednesday/Friday deliveries. It did not fix the forecast quantity for any good, the maximum price for any good, which good arrived on which day, which orders crossed $500, or what the staged supply failure resolved to. **Three audit rounds were spent reconciling exactly those five things.** Each agent's answer was individually plausible, so no arithmetic or consistency check could see the disagreement.

**Build `worldFacts` at Stage 2, before the fan-out, for any unit with an arithmetic or temporal spine.** It costs one pass and it removes the thing agents diverge on.

| Block | What it fixes | The defect it prevents |
|---|---|---|
| `timeline` | Every dated event, and what each one carries | A cue staged on a day the good does not arrive |
| `computed` | Every derived figure, with its workings and its source appendix | Two agents deriving the same quantity two ways |
| `stagedEvents` | Each planted event, when it fires, what it attaches to, and **how it resolves** | An event that is simultaneously unavailable and delivered |
| `groupings` | How items aggregate — per supplier, per delivery, per order | A limit applied to a line when the procedure applies it to the group |
| `thresholds` | Every limit, and **which specific things cross it** | A benchmark saying "under the limit" for something over it |

Two rules make it work:

- **Compute, do not assert.** Every figure carries its workings, so the assembler's derived gate can recompute it and the model answer can quote it. A figure typed once and copied is a figure that drifts.
- **State the resolution of every staged event.** *"The supplier cannot deliver on Wednesday"* is half a fact. The other half — *"so the full quantity arrives Friday at contract price, and no downstream figure moves"* — is what stops three agents inventing three different endings.

Hand `worldFacts` to every agent alongside the scenario card, and tell them plainly: **a figure in `worldFacts` is not theirs to recompute.**

---

## The derived gate — write it at Stage 3, not after an auditor finds the defect

The house gate and the readability gate check **form**. Nothing shipped with this skill checks whether the pack's own facts agree with each other, because those facts are per-build. So each build writes a small script over its content JSON — `Test-Coverage.ps1` alongside the build script — and runs it before every assembly.

**Write it at Stage 3, from `worldFacts`, while the agents are still running.** Written reactively, one check per audit finding, it arrives a round too late every time.

Six classes, all of which have shipped defects:

| Class | Fails when |
|---|---|
| **Coverage** | A requirement is named by no item's `mapsTo` and no checklist item. An absence is invisible to a presence sweep |
| **Arithmetic** | Any `A x B = C`, `A + B = C` or `A / B = C` written anywhere does not compute. Every figure is individually plausible, so nothing else can see a wrong one |
| **Figure agreement** | A task states a figure `worldFacts` settles differently, or one an appendix does not carry |
| **Threshold agreement** | Something on the wrong side of a limit is described as being on the right side |
| **Leakage** | Assessor-only language, a staged cue, a trigger or a benchmark reaches learner-facing content — **including via the front matter, which renders in both documents** |
| **Pointing answers** | A model cell says where the answer is instead of stating it — `copied from`, `from the report`, `as per`, `see Appendix` — and carries no figure of its own. The cell is not empty, so nothing else catches it. `compliance-rules.md` §7 |
| **Required content** | A block the order mandates is absent. `if ($node)` is not a test — use `@(AsArr (P $node 'rows')).Count -gt 0` |

Three rules that decide whether the gate is worth having:

1. **Plant the defect and watch it fail.** A guard never seen to fail is a guard you do not know works. Each of these was proven against the real defect before being trusted.
2. **Exempt by field path, not by guessing.** A model row carries every column in one string, so it is not a paragraph; an example assessor comment quotes a learner's *wrong* figure on purpose. Both trip a naive check. Record the path with each string and exempt precisely — a gate that fails correct content teaches people to ignore it.
3. **When a figure moves deliberately, re-read the guards.** They go stale and then fail correct content. On SITXINV007 **every** gate failure in rounds two and three was a stale guard, not a defect. Budget for that: after any deliberate figure change, the guard that names it is the next thing to check.

---

### The front matter is an assignment too

**`assignment` carries only assessable items, so on its own it builds a document of Tasks and nothing else.** `compliance-rules.md` section 3 mandates the further blocks, in the measured order it records — cover sheet, overview, what this covers, how you are assessed, instructions, the two principles tables, quality expected, conditions, task summary, the detailed scenario or the appendices, mapping matrix, foundation skills. Nothing writes them unless you assign them. There is **no glossary block and no alternative-assessment block** — RTO decision, 27 August 2026 — and *evidence to submit* lives inside Instructions to students, not as a block of its own.

**The front matter renders in BOTH documents.** The assessor guide mirrors the learner document and adds, so every front-matter block reaches the learner too — including one headed *Assessor requirements*, which reads as though it would not. Assessor-only guidance placed there **leaks**: on SITXINV007 a line explaining the two-tier marking scheme put the words *model answer* into the learner copy and failed the delivery sweep.

**Marking guidance, benchmarks and anything about how the pack is graded go in the assessor setup pack**, which is the only assessor-guide-only assignment. The front matter may say who assesses and against what conditions; it may not say how they mark.

**Assign the front matter explicitly, as its own item, to its own agent:**

```json
{ "id": "FRONT", "kind": "frontMatter", "document": "uat",
  "covers": [],
  "notes": "Every block in compliance-rules.md section 3, in the measured order. Returns one object per block, not an items array." }
```

Two blocks are the assembler's, not an agent's, because both are **derived** and a typed count is wrong the moment an item is added:

- **The task summary table** — built by walking `numberingPlan` and reading each item's own `wordGuide`.
- **The evidence mapping matrix** — built from the register, one row per requirement.

**There is no back-matter glossary** — RTO decision, 27 August 2026. `glossaryAdditions` is still collected, but it is used to check that every term an agent glosses is glossed **in line at first use** in the rendered document, not to build a block. On the non-food branch the **assessor setup pack** is also front matter — `simulated-industry.md` section 5 — and it is assessor-guide only.

### Two rules every content agent needs, that live in a later file

`readability.md` is read at Stage 4b, one stage after the agents run. These two rules govern what agents write, so they belong in the brief:

- **A line beginning `- ` is a list item and gets a real bullet. Every other line is prose.** Consecutive prose lines are joined back into a paragraph by `HRenderProse`, up to the 300-character cap. So: mark a list, and leave prose as sentences. Never split prose one sentence per line and leave it unmarked — rendered one paragraph per line it reads as a list that has lost its dots.
- **No paragraph over three lines** — 300 characters. Over it, listify first, split second, cut words third. Never cut a demand.

Brief agents on both at Stage 3 and the Stage 4b round is a check rather than a rewrite.

---

`covers` comes straight from the register. It is the whole reason two isolated agents cannot assess the same requirement.

`brand` locks the branding profile for the whole build. `workbookMode` is the practical-evidence branch from `compliance-rules.md` section 1a, and it decides which documents exist at all.

`qualification.aqfLevel` comes from the AQF gate in `unit-extraction.md`. `aqfSource` records whether it was unambiguous or the user chose it from several — the compliance report states which, so a validator can see the level was read rather than assumed.

`styleCard` is filled from the measured profile and `house-style.md` section A, never typed from memory. `acsfLevel` follows the qualification, not the unit. `maxSentenceWords` is **20** — `assets/house-profile.mvc.json` → `writing.maxSentenceWords`, whose note reads *"20, not 25"*, and that file is the authority over anything in `references/` that disagrees with it. The only exception is a sentence carrying a legislative citation in full.

`document` tells the assembler which file an item belongs in.

---

## The model-answer schema, and why it is shaped this way

`modelAnswerPoints` is **an array**, not a string. This is the change that makes the assessor guides usable.

The previous field was `modelAnswer`, a string described as *"a fully Satisfactory exemplar at the unit's AQF level"*. That description is the root cause of prose answers, and **no amount of prose instruction elsewhere overrides the shape of a field.** An agent handed a string field described as an exemplar writes a paragraph. An agent handed an array of points writes points.

The complaint that drove this: *"too wordy for a trainer to understand."*

`ProseModelAnswer` is a blocking check — it measures the rendered runs and fails any line over 18 words.

### Answer grids

An `itemTable` is a grid the learner completes, one row per item. It needs a model answer **per row**, which `modelAnswerPoints` alone cannot carry. `modelRows` does:

| Delimiter | Means |
|---|---|
| newline | next row, **in the same order as the grid's `items`** |
| `\|` | next column |
| `~~` | next bullet point within one cell |

**Column 0 is never overwritten.** It is the row key printed in the learner copy, and the assessor's grid must line up with the student's page word for word. Anything written before the first `|` is discarded — so a model line may safely repeat the row key for readability.

Two to four points per cell.

### Backward compatibility

Accept **either a string or an array** at render time, filtering blanks. An older contract, or an extractor that hangs a benchmark off whichever part carried it, still renders. **Assume every optional field may be absent, may be a string where an array is expected, or may already carry its own label** — a `tip` field often contains `Tip:`, so strip before adding or you print `Tip: Tip:`. Filter blank lines everywhere; an empty cell must still emit a paragraph.

The recipe card's own duplicate-label problem — `Test:`, `Tip:` and `To hold:` appearing both inside extracted method steps and in their own fields — is `recipe-workbook.md` section 5, which every food-branch build reads. It was stated in both places; it now lives only there.

---

## The content-agent brief

Give each agent the contract, its own slice of `assignment`, and this brief.

```
You are writing content for one part of a VET assessment tool. Other agents are writing other parts at the same time. You cannot see their work and they cannot see yours.

YOUR CONTRACT: {CONTRACT_JSON}
YOUR ITEMS: {ASSIGNED_ITEMS}

Write only the items assigned to you. Do not write, renumber or refer to any other item.

RULES

1. Cover exactly what `covers` lists for each item. Not one requirement more. Another agent is covering the rest, and anything you add beyond your assignment becomes a duplicate that will be found and removed.

2. Use the scenario card as the only source of workplace detail. Same venue, same people, same documents, same constraints.

3. If you need a scenario detail the card does not have - a form name, a person, a quantity, a piece of equipment - DO NOT INVENT IT. Add it to `needsFromContract` in your return and write the item using what the card does give you. Two agents inventing independently is exactly how a scenario world fractures, and it is the single most damaging thing you can do here.

4. Use the terminology map. One word per concept, every time. Never simplify a term in `assessedTerms` - if the unit assesses the term, the learner must meet the term.

5. Write to the style card. Sentences at or under the word limit, active voice, second person, one instruction per sentence.

6. Every answerable part gets its own labelled response space. A multi-part question with one shared box is a defect. Any part naming two or more items to define, compare or specify becomes an item-per-row table, not an open box.

7. Every question carries a word guide; every deliverable carries a stated scope.

8. Observation checklist items are written as: action + against what standard + observable result. No bare "correct method", "to standard" or "as required".

9. Produce the assessor layer for your items in the same pass - the model answer points, the benchmark, and the critical errors. This costs no extra time now and saves a whole second pass over the document later.

10. MODEL ANSWERS ARE POINTS, NEVER PROSE. A trainer marks against a list, not a paragraph. Each point is a phrase of 4-14 words, no terminal full stop, and does not restate the question. Never lose an assessable fact - every temperature, percentage, weight, time, product code, legislative reference and standard number must survive into the points.

11. BENCHMARK LINES ARE BULLETS, 18 WORDS OR FEWER. No prose blocks.

12. You do NOT write a document. Return structured content only. An assembler renders it.

RETURN this JSON and nothing else:
{
  "items": [
    {
      "id": "Q3",
      "heading": "",
      "mapsTo": "KE 2.1, KE 2.2",
      "wordGuide": "150-200 words",
      "scenarioBox": "optional, drawn only from the scenario card",
      "stem": "",
      "parts": [
        { "label": "a", "text": "", "responseSpace": { "label": "Student response - (a)", "lines": 8 } },
        { "label": "b", "text": "", "itemTable": { "headers": [], "items": [], "modelRows": [] } }
      ],
      "assessor": {
        "modelAnswerPoints": [ "4-14 words, no full stop, no restating the question" ],
        "benchmark": {
          "satisfactory":      [ "bullets, not prose" ],
          "minimumAcceptable": [ "the sufficiency threshold" ],
          "criticalErrors":    [ "what forces Not Satisfactory" ],
          "workedKey":         [ "fully worked numeracy, correct values, rounding tolerance" ],
          "exampleCommentSatisfactory":    "one line",
          "exampleCommentNotSatisfactory": "one line"
        }
      }
    }
  ],
  "glossaryAdditions": { "term": "definition" },
  "needsFromContract": [ "scenario detail you needed and did not have" ]
}
```

---

## After the fan-out

**Assembly is serial and deterministic.** The assembler walks `numberingPlan` in order and renders every item through the same builder functions. No judgement at assembly time — that is what guarantees styling and pagination cannot drift, because only one thing ever writes them.

**Handle `needsFromContract` before assembling.** If agents asked for scenario detail, add it to the card and re-run only the affected batches. Ignoring these produces exactly the vague, hedged writing the rule exists to prevent.

**Use `glossaryAdditions` to verify inline glossing**, not to build a back-matter block. There is no glossary section.

**Then run the flow pass** — one agent over the assembled whole, looking for the seams a batched build creates:

- Terminology that drifted despite the card
- Scenario details that contradict each other
- Two questions opening with the same construction
- Difficulty that does not escalate across the document
- Cross-references that no longer resolve

The flow pass owns seam defects, and it runs before the personas so their round is not spent on things a cheaper check catches first.
