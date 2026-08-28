---
name: learner-guide
description: Turn a finished VET assessment pack into the two teaching resources that must match it - a branded Learner Guide (Word) and a classroom Delivery PowerPoint - for an RTO. Reads the assessment tools and recipe workbook as the source of truth for every question cross-reference, sources the unit live from training.gov.au, builds one shared content spine and renders it twice so the guide and the deck cannot drift, builds by editing the RTO's approved Word and PowerPoint templates, plans four visuals per performance-criterion sub-section and fills them through the docx-images sub-skill, and gates the output on content width, list numbering, per-topic word floors, slide numbering, speaker notes, unresolved artwork prompts and a two-way question reconciliation. Use when asked to create, build or write a learner guide, learner resource, study guide, student guide, delivery PowerPoint, trainer deck, presentation or teaching resources for a unit of competency, or to produce the learner-facing resources that go with an assessment pack.
---

# VET Learner Guide and Delivery Deck Builder

## What you are given

```
/learner-guide <UNIT CODE> <BRAND> [path to the assessment pack]
```

Example: `/learner-guide SITHPAT018 MVC D:\Units\SITHPAT018`

**This skill runs downstream of `assessment`.** That skill produces the tools; this one produces the resources that teach toward them. It does not invent an assessment, and it does not change one.

**The assessment pack is the input, and it is the authority.** The unit, the qualification and the AQF level are read from training.gov.au; the architecture and formatting are measured from the RTO's own documents; **every assessment-question reference is derived from the pack, fresh, every build.** Never carry a question number over from a previous guide, a previous deck, or a sibling unit.

### The dependency that runs the other way

The assessment skill carries a standing rule: *never fact-check an assessment against a Learner Resource, because the resource is written after the assessment and derived from it.* This skill is the other side of that rule.

- The assessment is **upstream**. Where the guide and the pack disagree on a figure, a term, a count or a threshold, **the pack wins** and the guide is corrected.
- Where the guide needs a fact the pack does not carry, source it (the unit, the legislation, the RTO's own procedure) and **flag it in the report** as content the assessment does not cover.
- Where the pack looks wrong, **say so in the report — do not silently teach around it.** Correcting an assessment is the other skill's job, and doing it here hides the defect.

## What you produce

1. `[UNIT]_Learner_Guide.docx` — the learner-facing guide
2. `[UNIT]_Delivery_PowerPoint.pptx` — the trainer-facing deck
3. `[UNIT]_Resource_Report.md` — counts, cross-reference reconciliation, open questions

Deliver `.docx`/`.pptx` **and their PDFs together**, regenerated in the same pass. A PDF older than the file beside it is a delivery defect.

## The one idea this skill is built on

**Build one content spine, then render it twice.**

The guide and the deck teach the same unit from the same assessment, and the single most common failure in a paired build is drift: the deck cites Q9 where the guide cites Q10, the guide's tempering figure and the slide's disagree, a topic gains a sub-section in one and not the other.

So the content is authored **once**, as structured JSON, and rendered twice — Word by `Build-Guide.ps1`, PowerPoint by `Pptx-Blocks.ps1`. Neither renderer invents content. If a fact is wrong it is wrong in one place, and fixing it fixes both.

Detail: `references/content-model.md`.

## The brand

| Brand | Resolves to | Templates |
|---|---|---|
| `MVC` | Meridian Vocational College | `MVC_Learner_Guide_Template.docx`, `MVC_Branded_PPT_Template.pptx` |

Brand resolution, the ACI trading-name rules and the logo/palette/identity swap all work exactly as they do in the assessment skill, and read from the same `assets/branding.<brand>.json`. **A brand with no approved Learner Guide template and no deck template cannot be built** — ask the RTO for one rather than generating it.

## What to read, and when

| Read | Before |
|---|---|
| `references/source-extraction.md` | Stage 1 |
| `references/content-model.md` | Stage 2 |
| `references/learner-guide.md` | Stage 3 |
| `references/powerpoint.md` | Stage 3 |
| `references/visuals.md` | Stage 3b |
| `references/gates.md` in full | Stage 4 |
| `references/personas.md`, and the assessment skill's | Stage 5 |
| `references/audit-checklist.md` in full | Stage 6 |
| `references/visuals.md` §9, and the `docx-images` sub-skill | Stage 7b |
| The assessment skill's `references/house-style.md` and `references/readability.md` | Stage 3 |

The readability and house-style blocks are **shared with the assessment skill and must not be forked**. Where a rule genuinely differs for this document type it belongs in `references/learner-guide.md` under *Carve-outs*, and nowhere else.

## Model tiers for the agent stages

**Use the model the stage needs, never the biggest one everywhere** — the same rule as image quality: paying top tier for mechanical work buys nothing anyone sees. The dividing line is whether the agent exercises **judgement** or applies **a specification that already exists**.

| Stage | Work | Tier |
|---|---|---|
| 3 — content agents | Authoring 3,000-word Topics to AQF pitch | capable (session default) |
| 4 / 4b / figure gate | Scripts, not agents | none |
| 5 — personas | Reading the documents as a human would | capable |
| 6 — clean-room audit | The provenance audit; the verdict the build ships on | **most capable available** |
| 7 — remediation appliers | Applying fixes whose replacement text a verifier already wrote | **cheap tier, low effort** — the judgement was spent upstream |
| 7 — verification fan-out | Adversarial refutation of the fixes | capable |
| Extraction, spec migration, JSON validation | Mechanical transforms | cheap tier, or no agent at all |

A fix list that carries quoted defective text and exact replacement text is mechanical **by definition** — route it cheap. A finding that says "reconcile these two passages" still needs judgement — route it capable. When one fan-out mixes both, split it rather than paying the capable rate for the mechanical majority.

---

## Stage 0 — Pre-flight

Establish the **build directory outside the skill**. Never write build output into `~/.claude/skills/learner-guide/`; the next build inherits it.

Dot-source the library — one line, which resolves the assessment skill's scripts and loads both libraries:

```powershell
. "$SkillDir\scripts\Lib-Resolve.ps1"
```

Then confirm the templates are sound and the geometry patch has been applied:

```powershell
$P = Get-GuideProfile -SkillDir "$SkillDir\scripts"
Set-HousePalette -Brand MVC | Out-Null
Assert-DocxPackage -WorkDir (Expand-Docx -Path (Get-GuideTemplatePath -SkillDir "$SkillDir\scripts")) | Out-Null
(Test-PptxPackage -WorkDir (Expand-Docx -Path "$SkillDir\assets\templates\MVC_Branded_PPT_Template.pptx")).Ok
```

**Run `scripts\Patch-GuideTemplateGeometry.ps1` once** against a freshly installed template. It is idempotent and says when there is nothing to do. Skip it and every full-width table overhangs the right margin — see `references/gates.md`.

Then open the stage ledger, and **record every stage into it as that stage finishes** — not from memory at the end, which records what was intended rather than what happened:

```powershell
. "$SkillDir\scripts\Stage-Ledger.ps1"
New-StageLedger -BuildDir $out -Unit $code | Out-Null
# ... and after each stage:
Add-StageRecord -BuildDir $out -Stage '5' -Name 'Personas' -Status pass -Findings 4
```

`skipped` is an honest status and it is allowed. It simply will not pass Stage 8 for a blocking stage, which is the point.

## Stage 1 — Read the assessment pack, then the unit

**The pack first, because it sets the question numbers everything else hangs off.**

Extract, verbatim and completely:

- **Every question**, with its number, its sub-parts, its focus, its KE mapping and its word guide.
- **Every practical task and observation item**, with its number.
- The scenario world already in use — the venue, the characters, the employer, the locations. **Reuse it; never invent a second one.** A guide set in a different venue from its assessment reads as a different unit.

Then source the unit at `https://training.gov.au/training/details/{UNITCODE}/unitdetails` in a **JavaScript-capable browser** — `WebFetch` and `curl` return an empty shell. The currency and AQF-level gates apply exactly as in the assessment skill: a unit that is not `Current` stops the build, and a unit spanning two AQF levels is a question for the user, never an inference.

**Reconcile the two before writing anything.** State the `PC -> KE -> Question (+ observation)` map back, and flag every mismatch. That map is the contract for the rest of the build.

Detail: `references/source-extraction.md`.

## Stage 2 — Plan the spine

One pass, serial, with sight of everything.

- **Topic per Element.** One Topic per Element, one sub-section per Performance Criterion.
- **Assign every question to exactly one PC sub-section** as its primary preparation. A question may be signposted in more than one place, but it is *prepared* in one — otherwise the cross-reference table has no defensible answer to "where is this taught".
- **Plan the deck alongside the guide, not after it.** Each Topic needs **at least 15 slides**, and they are planned from the same sub-sections. Where a Topic cannot reach 15 from genuine content, record it now and report it — never pad.
- **Lock the contract**: scenario card, terminology, numbering plan, the question map.
- **Lock the figure registry** — `figures.json` in the build directory. Every working figure the resources will carry — every temperature, duration, quantity, percentage, dollar amount, date and count — goes in now, each with its authority class (**P** pack · **U** unit · **L** cited law · **V** venue procedure), its canonical value, the stale forms it must never appear as, and the strings that exist only in the assessor guide and must never reach a learner document. **A figure not in the registry is a figure nobody is checking**, and an unchecked figure is how a fabricated legal requirement shipped on 27 August 2026. `Test-FigureConsistency` enforces the registry at Stage 4 and before every Stage 7 re-render.

Detail: `references/content-model.md`.

## Stage 3 — Content agents (parallel)

Roughly one Topic per agent. Each gets the contract, its assignment, the question map and the shared style block.

- Agents produce the **guide content and the slide content for their Topic in the same pass**, into the shared spine. Splitting them across agents is how the two drift.
- **Agents never write a document.** They return structured content.
- **Word floors are content requirements, not formatting**: 3,000 words of counted body prose per Topic, and **800 words per PC sub-section's Underpinning knowledge block**. Both are checked at Stage 4 and both are common failures — the delivered reference guide meets the first and misses the second everywhere.

Detail: `references/learner-guide.md`, `references/powerpoint.md`.

## Stage 3b — Plan the visuals

**One PC sub-section gets four visuals**, plus one cover image for the guide:

| Slot | Visual | Route | Placement |
|---|---|---|---|
| `X.1` | Topic image | A — generate | After the sub-section heading, before the first body paragraph |
| `X.2` | Process diagram | B — build natively | Immediately after the step list it renders |
| `X.3` | Workplace image | A — generate | Beside the case study or worked example |
| `X.4` | Summary table or infographic | B — build natively | At the close, before the assessment link |

Emit each as a prompt block with `GImagePrompt` at the exact placement. The guide is built with **prompts on the page, not pictures**; Stage 7b turns them into artwork.

**Route B specs live IN the spine, on the visual entry, beside the prompt and alt text they must agree with.** Each Diagram entry carries a `spec` field — the exact rows or nodes the native renderer will build — and the build's spec-writer is a thin reader that copies spine → manifest, keyed by slot. **A build script must never restate spine content.** One build held its diagram specs as hand-typed copies in the spec-writer itself: three remediation rounds corrected the spine and the figures kept teaching the superseded calculation, because nothing that edited the spine could see them. A diagram whose slot has no spine spec is a **spine defect** — the spec-writer refuses and reports it, and nobody patches the manifest by hand.

**Route A is generated and costs money. Route B is built as native Word objects and is free.** Never image-generate a diagram or a table — a generated diagram carries labels nobody can correct, in a document an auditor reads.

**Count the cost and tell the user before Stage 7b.** Route A is `(sub-sections x 2) + 1`. For a unit the size of SITHPAT018 — 31 PC sub-sections — that is **63 generated images and 62 built natively**. `docx-images` asks before about ten, so a guide of this size is a conversation, not an assumption.

**The visual theme is the scenario business's, not MVC's.** Every colour justified by something real in that business. The college palette is document attribution in the footer only. Expect the scenario-themed visuals to sit against MVC-branded callouts and say so in the report.

Detail: `references/visuals.md`.

## Stage 4 — Render and gate

Render the guide and the deck from the finished spine, then gate both. **Always assemble from a fresh copy of the pristine template** — edits compound.

```powershell
$guide = Write-GuideDocument -Unit $unit -BodyXml $body -OutPath "$out\$code`_Learner_Guide.docx" -Profile $P
Test-GuideRules -Path $guide -QuestionsInPack $questions | Write-GuideRuleReport

$deck = Save-Deck -Deck $deck -Path "$out\$code`_Delivery_PowerPoint.pptx"
Test-DeckRules -Path $deck -TemplatePath $tpl -Plan $plan `
    -NumberSlotByLayout (Get-DeckNumberSlotMap -Profile $dp) | Write-DeckRuleReport
```

**Both gates block.** The deck gate additionally runs a package check that catches malformed XML *before* a file exists — PowerPoint reports a broken package only as "corrupted and unreadable", naming neither the part nor the tag.

**`-QuestionsInPack` reconciles the cross-references, both directions**, and fails on either: every question in the pack is prepared somewhere, and every question the guide or deck cites exists in the pack. A cited question the pack does not contain is an invented reference — a learner revises for a question that is not on the paper.

**Then the figure gate, and it blocks:**

```powershell
& "$SkillDir\scripts\Test-FigureConsistency.ps1" -BuildDir $out          # sources
& "$SkillDir\scripts\Get-DocText.ps1" -Path $guide -OutPath "$out\guide.txt"
& "$SkillDir\scripts\Get-DocText.ps1" -Path $deck  -OutPath "$out\deck.txt"
& "$SkillDir\scripts\Test-FigureConsistency.ps1" -BuildDir $out -DocText "$out\guide.txt","$out\deck.txt"   # rendered
```

It enforces the Stage 2 registry across everything that can put a number on a page — spine, build scripts, and the rendered text — with **variant-aware matching**: a forbidden `20 gastronorm` also fails as `twenty gastronorm`, `20-tray` and `fit inside 20`, because a literal-string sweep is exactly the check that let a leaked benchmark figure survive three remediation rounds in four spellings. Its `assessorOnly` list is the leakage tripwire; its `deckMust` list fails a corrected guide sitting beside an uncorrected deck, which is worse than either alone.

**What the structural gates cannot see.** Widths, numbering, schema order, word floors, cross-references — **none of them reads a sentence and asks whether it is true.** A fabricated temperature is perfectly well-formed XML and passes every structural check. The figure gate catches a *registered* figure gone stale; only Stage 6 catches a figure that was wrong from the start. That is why Stage 6 is not optional.

Detail: `references/gates.md`.

## Stage 4b — Readability

Runs on the assembled documents, after the house gate. Use the assessment skill's `Test-Readability` and its readability agent unchanged — same 300-character paragraph cap, same real-lists rule, same two-round maximum. The agent edits the **spine**, never the document, and never touches a figure, an assessed term, a count or a threshold.

Re-render from a fresh template afterwards and re-run both gates.

## Stage 5 — Flow pass and personas (parallel)

The flow pass owns the seams a batched build creates — a term glossed twice, a Topic that opens as though the previous one never happened, a figure numbered for a sub-section that moved.

Then the three personas from the assessment skill's `references/personas.md`, **unchanged and never forked**, plus a fourth this skill adds because this skill ships a deck: **the trainer who has to deliver it cold.**

The personas report findings; they do not edit. Conflicts resolve as they do upstream: the owner sets the floor, the assessor sets the ceiling, the student owns the form. Assessed terminology is never simplified.

**This stage blocks.** It is not an optional polish pass, and skipping it is not a shortcut — it is the stage that reads the document the way a human will.

Detail: `references/personas.md`.

## Stage 6 — Clean-room compliance audit

**The stage this skill exists to survive.** A reviewer with **none of the build context** — the guide, the deck, the assessment pack, `references/audit-checklist.md`, and its own independent extraction of the unit. Give it everything at once; cross-document consistency is a mandatory step. Use the prompt in the checklist verbatim.

**Hand the reviewers text extracts, not Office files.** `scripts/Get-DocText.ps1` dumps a `.docx` or `.pptx` to plain text in seconds — one block per slide with its speaker notes, and every figure's alt text appended, because a diagram's labels live in its alt text and a review that skips it has not read the figures. Reviewers driving Word COM spend their minutes opening documents instead of reading them.

It is **not** the assessment skill's audit, and its checklist is not a copy of that one. An assessment instrument fails by not gathering the required evidence. **A learning resource fails by teaching something that is not true.**

Its centrepiece is the **provenance audit**: every figure, threshold, temperature, duration, count and legal proposition in both documents traced to exactly one authority class —

| | |
|---|---|
| **P** | the assessment pack — upstream, and it wins |
| **U** | the unit on training.gov.au |
| **L** | named legislation, a standard or a code, cited |
| **V** | the scenario venue's own documented procedure, **and said so on the page** |

**A figure that fits none of the four is fabricated**, however reasonable it looks. Plausibility is not provenance.

Then, for every **L** figure, the attribution test — does the source say the number; does it **mandate** it or merely **recommend** it; and does it apply to the thing it is attached to? **A recommendation dressed as a legal requirement is a High-risk defect**, because the learner states it in the assessment and then in the workplace. A genuine requirement written as optional is the same defect inverted. So is a real, citable figure attached to a subject its source does not cover.

Detail: `references/audit-checklist.md`.

## Stage 7 — Remediate

**Registry first, prose second.** A round that starts by rewriting sentences is a round that fixes the instance in front of the author and misses its siblings — that exact pattern failed three consecutive rounds on one build: round 1 fixed prose and left the diagram specs, round 2 fixed the guide and left the deck, round 3 fixed the literal string and missed its four spelled-out variants. The order that works:

1. **Update `figures.json`** — the corrected value becomes the `require`, every stale form becomes a `forbid`, any newly-discovered assessor-only wording joins `assessorOnly`.
2. **Run `Test-FigureConsistency`** — it now *enumerates* every location carrying the stale figure, across spine, build scripts and rendered text. That enumeration is the work order; a sweep by eye is not.
3. **Fix what it lists**, plus the prose-level findings the registry cannot see.
4. **Run it again to zero**, then re-render **both** artefacts from fresh templates.

**A round is: registry, enumerate, remediate, re-gate, re-reconcile, re-audit.** Re-run `Test-GuideRules`, `Test-DeckRules`, `Test-Readability`, `Test-FigureConsistency` (sources *and* rendered text) **and** the Stage 6 clean-room audit, each on fresh agents. A remediation that is never re-audited leaves the resource carrying an out-of-date verdict — which is how a pack ships on a stale "Partially Compliant", and the same trap is set here.

Maximum three rounds; anything unresolved is an open finding, not quietly passed.

**Both artefacts are re-rendered even when only one had a finding.** They come from one spine, so a spine edit changes both, and re-rendering one leaves the other stale. **A corrected figure is the worst case** — it typically appears in guide prose, a summary diagram and at least one slide; the registry-then-enumerate order above exists because fixing the prose alone leaves two stale copies contradicting it, and it did, twice.

**Remediation is where leakage sneaks in.** The audit report quotes assessor benchmarks as evidence; an author fixing a finding from that report is one careless paste away from writing the benchmark into the learner document — it happened with an equipment capacity figure lifted straight from a Task model answer. Fix from the *pack facts and the registry*, never from the audit's quotation of a benchmark, and let `assessorOnly` catch the slip.

## Stage 7b — Artwork

**The position is fixed, not a preference** — the same three reasons the assessment skill fixes its own:

- **After Stage 7**, because Stage 7 re-renders from a fresh template and would throw placed images away.
- **After both gates**, because neither knows what a prompt block is and both read one as over-long body prose.
- **Before Stage 8**, because the delivery sweep fails any unresolved bracketed placeholder. Artwork must run while that net is still downstream of it.

Invoke the **`docx-images`** sub-skill and follow its own procedure. `GImagePrompt` pre-fills the caption, alt text and aspect, so its manifest needs no repair — but still **read the manifest and check every `kind`**: a prompt describing a labelled bar, a flowchart, a cycle or a scale is a diagram even if it was marked `[IMAGE:`.

Then:

- **Look at every generated image before placing it.** No lettering, no faces, no logos, nothing contradicting the document. Bare hands on ready-to-eat food is a food-safety defect on the page, not a styling quibble.
- **Generate once, and reuse for the deck.** Point `Set-SlidePicture` at the PNG already produced for the corresponding guide figure. A deck figure and its guide figure showing different pictures of the same thing is worse than either alone.
- **Re-run the guide gate with `-AfterArtwork`.** It then fails on any prompt block that survived, rather than reporting them as work pending.

**No API key, or the user declines?** Deliver with the prompts in place and say plainly that the figure spaces carry prompts rather than pictures. **Never delete a prompt to silence the sweep** — an empty space that once held a prompt cannot be recovered.

Detail: `references/visuals.md`.

## Stage 8 — Deliver

Runs once, after the final re-render.

- **`Test-StageLedger` first, before anything is verified or exported.** It fails delivery when a blocking stage has no record, or when Stage 4b, 5 or 6 last ran *before* the final re-render and is therefore describing a document that no longer exists. Nothing else in this pipeline can see a skipped judgement stage — every structural gate passes just as happily without one.
- `Invoke-DocumentVerification` on the guide — updates fields, saves, exports the PDF in one Word session. **`Update-Fields` is what populates the Contents**; skip it and the guide ships showing the field placeholder.
- Export the deck to PDF through PowerPoint, and open each file once by hand to confirm neither prompts to repair.
- `Test-PageFlow` on the guide — no blank pages, no thin pages.
- Confirm the deck's printed slide numbers match their deck positions. They are **literal text, not fields**; the reference deck prints the wrong number on 19 of its 39 slides.

---

## Report, every build

- Word count per Topic against the 3,000 floor, and per Underpinning knowledge block against the 800 floor
- **Slides per Topic against the 15 floor**, listed, with the reason for any shortfall
- The question cross-reference, reconciled both ways, with any gap named
- Content width, and confirmation every full-width table equals it
- Distinct `numId` count, and that every list restarts at 1
- **Visuals: planned, generated, built natively, and what each cost** — plus zero unresolved prompt blocks
- Speaker notes present on every teaching, case-study and assessment-link slide
- The unit's release and currency, with the date checked
- **The Stage 6 compliance verdict, its date, and which remediation round it was issued against.** A verdict from before the last re-render is stale and must be re-issued, not carried forward
- **The provenance ledger** — every figure, its authority class, its source, and whether it is mandatory or a recommendation. Verified rows are part of the output, not just defects
- **Which personas ran, and which findings each raised** — a stage recorded as run with no findings is a result; a stage silently skipped is a defect in the build, and saying so is this report's job
- **Every divergence between the spec, the template and the RTO's delivered guide, with which one was followed and why**
- **Every open question, stated as a question**

### Standing divergences

Three, all real, all found by measuring the RTO's own artefacts. `references/gates.md` carries the evidence and the decision for each.

1. **Content width.** The template shipped margins giving CW 9026 while the spec and every table in the delivered guide use 9617. Resolved by patching the template's right margin to 849. **The delivered SITHPAT018 guide overhangs its right margin by 591 DXA on all 361 of its tables.**
2. **Callout palette and icons.** The v3.4 template uses the ACI callout hexes and the twelve-icon set; the delivered guide uses the MVC palette and no icons at all. Resolved in favour of the template, which is the approved brand source — but it is a visible change from the last guide the RTO shipped, and it needs the crossover carve-out in `references/gates.md`.
3. **Underpinning knowledge depth.** The spec sets an 800-word floor per PC sub-section. The delivered guide's blocks measure 96–242 words. Resolved in favour of the spec; expect this to be the expensive part of the build.
