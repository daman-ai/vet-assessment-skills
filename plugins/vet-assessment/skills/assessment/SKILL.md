---
name: assessment
description: Build audit-compliant Australian VET assessment packs for an RTO, matched to that RTO's own existing documents. Produces paired learner and assessor Word documents - four where the unit produces food (a knowledge tool plus a recipe workbook, each mirrored by an assessor guide), two otherwise (one combined knowledge-and-performance UAT plus its assessor guide) - with red point-form model answers and benchmarks, plus a compliance report. Measures the RTO's approved artefacts first, sources the unit live from training.gov.au, enforces an assess-once register so no requirement is assessed twice, builds by editing the approved templates, and puts the output through a blocking house-rules gate, a readability gate, an adversarial three-persona review and an independent clean-room compliance audit. Generates and places the recipe workbook's photographs automatically where the unit produces food. Use when asked to create, build or write an assessment tool, assessment workbook, assessor guide, marking guide, RTO assessment, unit assessment tool, recipe workbook or UAT for a unit of competency or training package unit.
---

# VET Assessment Builder

## What you are given

```
/assessment <UNIT CODE> <QUALIFICATION> <BRAND>
```

Example: `/assessment SITHKOP013 SIT40521 Certificate IV in Kitchen Management MVC`

**The unit code and the brand are the only things you are REQUIRED to be told.** The qualification is optional: name it and it is verified against the unit's own qualification list before use and recorded as *user-chosen*; omit it and it is read from training.gov.au. Everything else is read or measured — the AQF level from training.gov.au, the architecture and formatting from the RTO's own documents.

**The qualification is still verified, never trusted.** Where the user names one, confirm it appears on the unit's `unitgridusage` list before using it, and record it as *user-chosen* rather than *unambiguous*.

### The brand

| Brand | Resolves to | Templates |
|---|---|---|
| `MVC` | Meridian Vocational College | `MVC_Assessment_Template_Combined_PE_KE_v2.2.docx`, `MVC_Recipe_Workbook_Template.docx` |
| `ACI` | **Adelaide Culinary Institute** *or* **Adelaide Construction Institute** — see below | **MVC's templates**, with the logo, palette and identity swapped in at build time |

**ACI is one RTO — Bush Tukka Pty Ltd, RTO 45797, CRICOS 03978F — trading under two names.** Which name a document carries is decided by the *vocation of the unit*, not by anything the user types:

- A **cookery, hospitality or patisserie** unit — `SIT` training package — is **Adelaide Culinary Institute**.
- A **construction, plumbing or building** unit — `CPC` training package — is **Adelaide Construction Institute**.
- A `BSB` business unit takes the variant of the qualification it is being built for. **Where that is not obvious from the qualification, ask.** Never guess a trading name.

**Contacts are shared.** One email for all of ACI — `info@culinaryadelaide.sa.edu.au`, the culinary address, on construction documents too — and one phone, `08 7001 6745`. There is no `constructionadelaide` mailbox; do not derive one. Only the **trading name, tagline, website, logo and palette** differ between the two variants.

Resolve the variant at Stage 1, once the unit's training package is known, and state it in the build report. **The chosen brand and variant lock for the whole build.**

**Everything is as MVC except the logo and the colours.** RTO decision, 26 August 2026. ACI builds from MVC's approved templates and inherits MVC's structure, cover sheet, policy, day counts, typography, margins, table width, pagination and every house rule. Three things are swapped in by `Write-PackDocument`, and only for a brand whose profile declares them:

| Step | Function | Swaps |
|---|---|---|
| 1 | `Set-BrandLogo` | The mark, keeping its own aspect ratio. The two ACI marks differ - 3.53:1 culinary, 2.46:1 construction - so a fixed height would stretch one. |
| 2 | `Set-BrandPalette` | Every colour, by role, across the document, numbering, styles, headers and footers. |
| 3 | `Set-BrandIdentity` | The RTO identity — legal entity, trading name, acronym, website, email, **street address**, **phone**, student-ID label, RTO and CRICOS codes, tagline. Covers `document.xml`, every header and footer, and `docProps`. |

**A brand swap that moves the name but leaves the address is not a brand swap.** The address and the phone were missing from step 3, so ACI documents printed MVC's street address and MVC's phone number on their own title page, under an ACI logo and the ACI trading name. The text sweep missed it too, because neither string was a forbidden token. **Every identity field the template prints must be in the swap AND in the crossover sweep** — if it is not in both, it fails silently.

**The logo is swapped wherever it is DRAWN, and a blocking gate proves it - `Assert-BrandLogo`, inside `Write-PackDocument`, every build, every brand.** On 29 August 2026 every knowledge document of a delivered ACI pack carried the **MVC mark in its header** with every gate green: the swap stopped at the first image-bearing part (the title page) and never reached the header, and the crossover sweep reads text so it cannot see an image. The gate is byte-level and costs milliseconds: every image referenced from any header or footer must be byte-identical to the **resolved variant's** mark - the culinary mark on Adelaide Culinary Institute documents, the construction mark on Adelaide Construction Institute documents - and no media part anywhere may match any other brand's or the other variant's mark. It throws before a file exists. The same incident's second lesson: **hyperlink TARGETS live in `.rels`, not in the part** - `Set-BrandIdentity` sweeps the rels files too, or the page reads ACI and clicks through to MVC.

**And the variant itself is now resolved in code, not prose: `Resolve-BrandVariant`, inside `Write-PackDocument`, per document.** The unit code's training-package prefix is matched against each variant's declared `trainingPackages` - SIT resolves culinary, CPC construction. A passed `-Variant` that contradicts the unit's package throws; an unmapped package (BSB) throws unless the variant is passed explicitly, because that is a decision and never a default. The delivery verification re-proves the mark on the shipped bytes - `Invoke-DocumentVerification` expands the final file, resolves the variant from the unit code in its name, and fails the document if any header image is not that variant's mark.

**Step 3 is not optional.** With the logo and palette swapped and the identity left alone, the crossover sweep still found MVC's name, domain and RTO code in the retained cover sheet. A recoloured document still naming Meridian Vocational College looks branded and is not.

**Swapping the identity moves the body-start anchor.** The anchor both gates use to separate the RTO's approved front matter from authored body is the title-page email address, which step 3 rewrites. A brand that swaps its identity must name its *post-swap* address first in `formatting.bodyStartsAfter`, and must pass `-Brand` to `Test-Readability`. Miss either and the gates police the approved title page as if this skill had written it.

`Get-Branding` stops a brand that is not set up and names exactly what is missing, rather than building something half-branded.

## What you produce

The practical branch sets the count. Food production means the unit's Performance Evidence requires producing food to standard recipes.

**Food — four documents:**

1. `[UNIT]_UAT1_Knowledge.docx` — learner, knowledge only
2. `Assessor_Guide_[UNIT]_UAT1_Knowledge.docx` — mirrors 1
3. `[UNIT]_Recipe_Workbook.docx` — learner, practical
4. `Assessor_Guide_[UNIT]_Recipe_Workbook.docx` — mirrors 3

**Everything else — two documents:**

1. `[UNIT]_UAT.docx` — learner, Section A Knowledge and Section B Performance, observation checklists bound in
2. `Assessor_Guide_[UNIT]_UAT.docx` — mirrors 1

Plus `[UNIT]_Compliance_Report.md` either way.

The split exists because a recipe workbook needs its own book. Where there is no recipe workbook there is nothing to split off.

Each assessor guide mirrors its learner document exactly and adds. Never remove or renumber learner content. Deliver `.docx` and `.pdf` together and regenerate both — never leave a stale PDF beside a fresh document.

## What to read, and when

Read each file at the stage that needs it. **One file is read in several passes by design** — `recipe-workbook.md`: the branch trigger at Stage 2, the build sections at Stage 4 and section 12 at Stage 7b each need a different slice of a 54 KB file, and only the food branch reads past Stage 2. Every other file is read once, at the stage named — `audit-checklist.md`'s two Stage 3 sections are the orchestrator's whole share of it; the clean-room reviewer reads that file in full itself.

| Read | Before |
|---|---|
| `house-standard.md` | Stage 0 |
| `compliance-rules.md` and `house-style.md`, both in full — equal force | Stage 2 |
| `unit-extraction.md` | Stage 1 |
| `section-contract.md` **in full** — it carries `worldFacts`, the interlock rule and the derived-gate spec, and all three are Stage 2 and Stage 3 obligations; plus `recipe-workbook.md` §§1–4 and §§7–8 — the branch trigger, the measured order, and which items exist at all | Stage 2 |
| `sa-legislation.md` | Stage 3 |
| `template-build.md`, plus `recipe-workbook.md` §§5–11 or `simulated-industry.md` — §§1–4/7–8 were read at Stage 2 and §12 belongs to Stage 7b | Stage 4 |
| `readability.md` | Stage 4b |
| `recipe-workbook.md` section 12, and the `docx-images` sub-skill | Stage 7b, food branch only |
| `audit-checklist.md` — the *Spawning the reviewer* and *Review discipline* sections only, because Stage 3 starts the reviewer's extraction | Stage 3 |
| `personas.md` | Stage 5 |
| `audit-checklist.md` — nothing further; the Stage 3 sections carry the spawn prompt, and the reviewer reads the file in full itself | Stage 6 |
| `learning-loop.md` — but start `findings-register.md` at Stage 3 and keep it as you go; reconstructing it at Stage 9 loses what each finding cost and whether the skill already warned about it | Stage 9 |

## Models

Run the build itself on **Opus 5**. Move up to **Fable 5** for the first build of a new brand or qualification, or when a prior round came back Partially Compliant. Spawned agents take the cheapest model that cannot cost the pack quality — pass it as the Agent tool's `model`:

| Agents | Model | Why |
|---|---|---|
| Stage 3 content agents | `opus` | They author the items and model answers the auditor judges — the substance of the pack |
| Stage 7 remediation agents, where the round **re-derives** content or must reconcile figures across files | `opus` | Judgement about consequences, and the round most likely to introduce a new defect |
| Stage 7 remediation agents, where the round **applies wording the audit already supplied** | `sonnet` | Mechanical application against an explicit decisions file |
| Readability agent · Stage 5 flow pass and personas · the reviewer's unit extraction | `sonnet` | Bounded rewriting, reviewing and verbatim transcription against explicit rules |
| Stage 6 clean-room audit, and every re-audit | `fable` (else the strongest available) | The last line of defence, and one agent — the premium is small against the whole build |

Do not use Haiku anywhere in this skill — its 200K context is tight for whole-pack review and the saving is marginal against the cost of a missed finding.

---

## Stage 0 — Measure the RTO's artefacts

Runs before the unit is sourced and before a scenario card is written.

Ask for the **folder**, not a description. Measure, do not eyeball. Write `assets/house-profile.<brand>.json` and a prose house-standard file.

**Ask two things in the same breath**, because no later stage collects the second:

- Where the existing assessment documents for this unit, or the nearest sibling unit, actually live.
- **Which other tools in this qualification already assess part of this unit.** The assess-once register at Stage 2 needs it to record what is already covered elsewhere.

If the user says there are none, ask again for a sibling unit's pack — an RTO that has been operating has artefacts. Only if there is genuinely nothing may you invent a scenario world, and then only with the user's confirmation first.

**Start Stage 1 while the questions sit with the user.** The unit extraction and the script pre-flight depend on nothing the user is being asked for, so ask, then source the unit in the same turn — the same overlap Stage 3 uses for the reviewer's extraction. Nothing is authored until Stage 2, which still starts only with both in hand, and a unit that fails a Stage 1 gate stops the build before the user digs out folders for nothing.

**Two rules govern everything downstream:**

- **The RTO's own artefacts are the authority.** Where an artefact contradicts anything in `references/`, the artefact wins. Record the divergence; do not correct their document.
- **Never fact-check an assessment against a Learner Resource.** It is written after the assessment and derived from it. Checking against it inverts the dependency and launders errors.

**Establish the build directory first.** Everything this build writes — the unit extract, the contract, the content, the documents, the report — goes in one folder **outside the skill**. Never write build output into `~/.claude/skills/assessment/`; the next build inherits it.

**Pre-flight before any content agent runs.** Dot-source from `scripts/`, in this order — the gates and the assembler all need `Build-FromTemplate.ps1`'s part readers, and `Build-Pack.ps1` needs everything above it:

```powershell
. "$SkillDir\scripts\Build-FromTemplate.ps1"   # Get-Branding, Expand-Docx, Test-DocxPackage
. "$SkillDir\scripts\Docx-Blocks-House.ps1"    # the H* block builders
. "$SkillDir\scripts\Test-HouseRules.ps1"      # Get-HouseProfile, Test-HouseRules
. "$SkillDir\scripts\Test-Readability.ps1"     # Test-Readability
. "$SkillDir\scripts\Verify-Document.ps1"      # Invoke-DocumentVerification - Complete-Pack needs it
. "$SkillDir\scripts\Build-Pack.ps1"           # Write-PackDocument, Complete-Pack
```

Then run `Get-Branding` and `Get-HouseProfile`, and check both templates. **`Test-DocxPackage` takes an unpacked directory, not a file**, so expand first:

```powershell
$b = Get-Branding -Brand MVC
foreach ($k in 'uat','recipeWorkbook') {
    $w = Expand-Docx -Path (Get-TemplatePath -Branding $b -Kind $k)
    (Test-DocxPackage -WorkDir $w).Ok      # expect True
}
```

Each takes seconds and each otherwise fails the build after the expensive work.

**A brand with no measured house profile and no approved template cannot be built.** MVC ships both. **ACI ships a measured profile and inherits MVC's templates** — its `templates` block points at MVC's files and sets `swapLogo` and `swapPalette`, which is what makes an ACI document ACI. Any other brand: stop and ask the RTO for an approved template rather than generating one — Stage 4 forbids building from scratch, so there is no legal path to a document without it.

Detail: `references/house-standard.md`.

## Stage 1 — Source the unit

`https://training.gov.au/training/details/{UNITCODE}/unitdetails`, in a **JavaScript-capable browser**. `WebFetch` and `curl` return an empty shell.

**Two hard gates:**

- **Currency** — if *Usage recommendation* is not `Current`, stop and report the superseding unit.
- **AQF level** — read every qualification the unit is packaged into. If they span more than one level, stop and ask which to build for. Never infer a level from the unit code.

Capture verbatim, every bullet and sub-bullet. Verify by re-reading and diffing.

Detail: `references/unit-extraction.md`.

## Stage 2 — Register, branch, contract

One pass, serial. This is the step that must be done with sight of everything, because it is what stops two sections assessing the same requirement.

- **Assess-once register** — every requirement on one line, each assigned to exactly one place. Where a written item and an observation both touch a Performance Criterion, the written item gathers the reasoning and the observation judges the performance. Say so in the mapping.
- **Practical branch** — food production or not. This decides the document count.
- **Lock the contract** — scenario card, terminology, numbering plan, style card.
- **Lock the CONSEQUENCES — `worldFacts`.** Every derived figure with its workings, every dated event and what it carries, every staged event **and how it resolves**, every grouping, every threshold and what crosses it. **Before a single agent runs.**

**The scenario card stops one step short of where the defects are.** It fixes the venue, the cast and the constraints, so nobody invents a person or a form. It does not fix what those constraints *imply* — so every agent computes the implications separately and they disagree. Each answer is individually plausible, which is exactly why no gate can see it.

On SITXINV007 the card fixed six goods, a $2,400 budget, a $500 approval limit and three delivery days, and left the forecast quantities, the maximum prices, the delivery-day allocation, the purchase-order groupings and the staged event's resolution to be invented independently. **Three audit rounds went on reconciling those five things.** One Stage 2 pass removes them.

Skip `worldFacts` only where the unit carries no arithmetic and no timeline — and say so in the report.

Detail: `references/compliance-rules.md`, `references/section-contract.md`.

## Stage 3 — Content agents (parallel)

Roughly three items per agent. Each gets the contract — **including `worldFacts`** — its own assignment and the brief.

- **Model answers are points, never prose.** The field is `modelAnswerPoints`, an array. No prose instruction elsewhere overrides the shape of a field.
- Each agent produces the learner content **and its assessor layer in the same pass**.
- **Agents never write a document.** They return structured content.
- **A figure in `worldFacts` is not the agent's to recompute.** Say so in the brief.

**Never split an interlocking cluster across agents.** Wave count is the cost, but divergence is the defect. Two agents editing files that must agree will disagree, because neither sees the other. The clusters that go to one agent — the setup pack with the observation instrument, the appendices with the tasks that read them, a benchmark with the thing it marks — are in `section-contract.md`, *Never split an interlocking cluster*. The test before fanning out: *could these two agents each be right alone and contradict each other?*

**Write the build's derived gate now, from `worldFacts`, while the agents run.** A small script over the content JSON — coverage, arithmetic, figure agreement, threshold agreement, leakage, required content — run before every assembly and every re-assembly. Written reactively, one check per audit finding, it arrives a round too late every time. Spec and the three rules that make it worth having: `section-contract.md`, *The derived gate*.

Start the clean-room reviewer's own unit extraction now, overlapped — it depends on nothing the build produces.

## Stage 4 — Assemble and gate

Handle `needsFromContract` first, then render every item into the template. **No glossary block is built** — terms are glossed in line at first use.

**Build by editing the approved template** — unpack, edit the XML as raw text, repack. Never generate from scratch. Never edit through a namespace-aware parser. Always assemble from a fresh copy of the pristine template; edits compound.

**Run the build's derived gate FIRST**, over the content JSON, before you assemble anything. It is the only check that sees a pack contradicting itself, and it costs seconds. `Test-HouseRules` and `Test-Readability` check form; nothing shipped with this skill checks whether the pack's own facts agree, because those facts are per-build.

**Then run `Test-HouseRules`** on the unpacked package, before repacking, so a defect is caught before a file exists to mislead anyone. Its assessor-only checks matter as much as the formatting ones: **`AssessorUnansweredBox`** fails a guide that still shows a learner placeholder, which is how an assessor guide ships with half its questions unanswered. Its **warnings do not block** — they carry defects present in the RTO's own source, which the standing rule says to reproduce rather than silently correct.

Detail: `references/template-build.md`.

## Stage 4b — Readability pass

**Runs on top of the assembled documents, after the house gate and before the personas.** A document can pass every compliance check and still arrive as a wall of text.

- **No paragraph over three lines** — a 300-character cap on body prose, bullets, task stems and scenario boxes. Over it, listify first, split second, cut words third. Never cut a demand.
- **Every list is a real list** — real Word numbering in prose, a literal bullet inside a cell or panel. A hyphen run or a comma enumeration inside a paragraph is a defect, and task stems and instructions are where it happens.
- **Spacing lets the page breathe** — bullets never sit flush against each other.
- **Never stack short paragraphs where a list belongs** — three or more consecutive unbulleted short paragraphs read as a list that lost its dots. Either bullet them, or let the assembler join them into a paragraph.
- **A heading never separates from its content** — any paragraph ending in a colon carries `keepNext`, so a lead-in cannot strand at a page foot away from the list it introduces. Bind with `keepNext`, never `cantSplit` — the house documents use none and the gate blocks it.

Run `Test-Readability` to find them, then the **readability agent** to rewrite the content, then **re-assemble from a fresh template** and re-run both gates. The agent edits content JSON, never the document, and never touches a figure, an assessed term, a count or a threshold.

**Two rounds maximum.** Anything still failing after the second becomes an open finding carried into the report — not a third round, and not quietly passed.

Detail: `references/readability.md`.

## Stage 5 — Flow pass and personas (parallel)

The flow pass owns the seams a batched build creates. The three personas report findings; they do not edit.

**When they conflict: the owner sets the floor, the assessor sets the ceiling, the student owns the form.** Except assessed terminology, which is never simplified.

Detail: `references/personas.md`.

## Stage 6 — Clean-room audit

A reviewer with **none of the build context** — document paths, `references/audit-checklist.md`, and its own independent extraction of the unit. Give it every document at once; cross-document consistency is a mandatory step. Use the prompt in the checklist verbatim.

**Spawn it in the same wave as Stage 5.** The clean-room rule governs what the reviewer is told, not when it runs: it consumes no persona output, both waves read the identical post-4b documents, and both findings streams land in the same Stage 7 round.

## Stage 7 — Remediate

Regenerate content only for the sections with findings, then re-assemble from a fresh template.

**A remediation round introduces defects at the same rate as authoring does. Assume it will.** On SITXINV007 round two fixed nine of eleven high-risk findings and introduced three new ones; round three fixed those and introduced two more. Every one was the same shape — **a figure changed in one file and not carried to the others** — which is the authoring failure mode returning under a different name. So a remediation round takes the whole of Stage 2 and Stage 3's discipline, not a lighter version of it:

- **Write a decisions file for the round** before dispatching anything — the corrected figures, the corrected timeline, and what each fix implies elsewhere. Hand it to every agent as the round's contract, ahead of the original. This is `worldFacts` for the repair, and it is what lets agents catch errors in *your* instructions instead of silently diverging on them.
- **The interlock rule still applies.** Do not split the setup pack from the observation instrument, or the appendices from the tasks that read them, just because the findings arrived on different files.
- **Sequence what depends.** Where a fix changes an appendix figure, that agent runs and lands **before** the agents that read it.
- **State explicitly which figures must NOT move.** A round that only says what to change invites an agent to helpfully adjust a neighbouring figure that was already correct.

**A round is: remediate, re-gate, re-audit.** Re-run the **derived gate**, `Test-HouseRules`, `Test-Readability` **and** the Stage 6 clean-room audit, each on fresh agents. A remediation that is never re-audited leaves the pack carrying an out-of-date verdict, which is how a pack ships on a stale "Partially Compliant".

**Ask the re-audit to verify its predecessor's findings one by one**, marking each fixed, partly fixed or unfixed with the evidence checked — not merely to look for new ones. A claim that nine of eleven are fixed is worth nothing unless someone opened each cited task.

**When a figure moves deliberately, re-read the derived gate's guards.** They go stale and then fail correct content, which is worse than no gate. On SITXINV007 *every* gate failure in rounds two and three was a stale guard rather than a defect. Fix the guard, never the document, once you have confirmed the content is right.

The fresh reviewer's independence is from the *build*, not from its predecessor: hand a re-audit round the round-one reviewer's own verbatim extract — never the build's — rather than repeating the training.gov.au extraction. See *Revision rounds* in the checklist.

Maximum three rounds. Anything unresolved is an open finding, not quietly passed.

**Stage 7 re-renders content the readability agent edited**, so `Test-Readability` is one of the gates it re-runs — not just the house gate.

## Stage 7b — Artwork (food branch only)

**The recipe workbook ships with real photographs.** Every photo space in it is an `[IMAGE: ...]` prompt block, and this stage turns each one into a picture and deletes the prompt. The UAT and the assessor guide carry no artwork of their own.

Skip this stage entirely on the non-food branch - there is no recipe workbook and nothing to fill.

**The position is fixed, not a preference:**

- **After Stage 7**, because Stage 7 re-assembles from a fresh template and would throw away placed images.
- **After both gates**, because neither `Test-HouseRules` nor `Test-Readability` knows what a prompt block is, and both read one as over-long body prose.
- **Before Stage 8**, because `Invoke-RenderedSweeps` fails any unresolved `[...]` left on the page. That sweep is the net that stops a prompt reaching an auditor, so artwork must run where the net is still downstream of it.

Invoke the `docx-images` sub-skill and follow its own procedure. Then:

- **Look at every generated image** before placing it - no lettering, no faces, no logos, and nothing contradicting the document. Bare hands on ready-to-eat food is a food-safety defect on the page, not a styling quibble.
- **Generate once.** The assessor workbook mirrors the learner's cards, so point its manifest entries at the PNGs already generated and set each `status` to `generated`. Regenerating doubles the bill and returns *different* pictures, so the two documents would disagree about what the product looks like.
- **Count the cost before generating** and tell the user. Ask before more than about ten images.
- **No API key, or the user declines?** Deliver with the prompts in place and say plainly that the photo spaces carry prompts rather than pictures and that Stage 8 will report each as an unresolved placeholder. **Never delete a prompt to silence the sweep** - an empty box that once held a prompt cannot be recovered.

**Re-validate the package after placing.** The artwork sub-skill edits `document.xml` through a namespace-aware `XmlDocument` - the one thing `template-build.md` forbids everywhere else, and it is exempt only because it rewrites whole paragraphs rather than splicing raw XML. Every packaging check lives inside an assembly (`Write-PackDocument` validates each time, the last being Stage 7's re-assembly) and none runs after artwork, so run `Test-DocxPackage` on the placed document before Stage 8. An artwork step is the last place in the pipeline that touches the XML and the only one with no gate behind it.

Detail: `references/recipe-workbook.md` section 12.

## Stage 8 — Deliver

**No earlier stage renders, verifies or exports anything.** Stages 4, 4b and 7 each re-assemble, so a verification run before the last of them is void. This stage runs once, after the final re-assembly, and nothing ships without it.

- `Invoke-DocumentVerification` on every document — it updates fields, saves, and exports the PDF in one uninterrupted Word session
- **`Update-Fields` is what populates the table of contents.** Skip it and every document ships showing the field's placeholder text instead of a contents list
- `Test-CoverSheet` — one page, every clause present
- `Test-PageFlow` — no blank pages, no thin pages
- `Invoke-RenderedSweeps` — placeholders, guidance markers, brand crossover, assessor leakage
- Open each file in Word once by hand and confirm it does not prompt to repair

**Deliver the `.docx` and the `.pdf` together, regenerated in the same pass.** A PDF older than the document beside it is a delivery defect.

**CHECK THE FOLDER AFTER COPYING, BEFORE REPORTING DELIVERY.** For every `.docx` in the delivery folder, confirm a `.pdf` exists beside it and is no older. This is not a formality: a copy that hits a locked file throws on that one file and **succeeds on the rest**, so the folder ends up half new and half old - a fresh `.docx` next to a stale `.pdf` - and the build reads as delivered. It happened on 27 August 2026 and the user found it, not the gate.

**Where a file is locked, say so and stop.** Do not write a second copy under another name and leave both. Name the file and the process holding it. `WINWORD` left running from an earlier verification is the usual culprit; a PDF viewer is the other.

Full procedure: `references/template-build.md`, *Delivery gate*.

## Stage 9 — Close the loop

**Runs after delivery. Every build teaches this skill something, and almost none of it belongs in this skill.**

The loop exists because the same process defects kept recurring across builds, and a process defect only ever fixed in the pack will be back in the next pack. But a skill that grows by a rule per build becomes a skill nobody reads, and an unread rule does not run. **The loop is selective by design.**

- **Keep `findings-register.md` DURING the build**, not at the end. One row per finding from every gate, every persona and every audit round — **plus the build's own rework**, which no reviewer reports and which carries most of the process defects. Record what each cost and whether the skill already warned about it.
- **Classify every finding into one of four destinations**: the compliance report, the house profile, memory, or the skill. **Only findings that pass both halves of the skill test go near the skill** — the skill's own instructions caused or missed it, *and* it would recur on an unrelated unit for an unrelated RTO.
- **Ask the recurrence question before proposing anything.** If the rule already existed, was read and was correct, then **prose failed** — the fix is to make it executable, not to restate it. That is where `worldFacts` and the derived gate came from; *"a figure lives in one place"* had been written down for months and the figures drifted anyway.
- **Propose amendments as exact diffs, ranked by cost, with what each retires.** Say which you would not make.
- **Nothing is written to the skill without the user's approval.**
- **Report the loop even when it changes nothing.** A build that proposes no amendment means the skill held. Expect most builds to yield none or one.

Detail: `references/learning-loop.md`.

---

## Report, every build

- Page and word count per document
- **What each page break lands on**, as a list — `Get-PageBreakTarget`. A count proves nothing
- Counts proving the rules held: bullet points, longest paragraph, red runs, zero colour band, zero stale day count
- **Readability** — longest paragraph in characters and lines, zero paragraphs over the 300-character cap, zero run-on lists, and what the readability agent changed
- **Artwork**, on the food branch — images generated, recipe cards without one (expect zero), anything regenerated or left failed, confirmation the assessor guide reuses the learner's images, and a zero-hit search of both delivered documents for `[IMAGE`, `[DIAGRAM`, `[ILLUSTRATION` and `PROMPT:`
- The unit's release and currency, with the date checked
- The qualification and AQF level, and whether it was unambiguous or the user chose it
- Which practical branch, and why
- **Every source defect found and not fixed, with the reason** — preserve defects in the RTO's source rather than inventing a correction
- **Every open question, stated as a question**
- Anything still open after three rounds
- **The derived gate** — its check names and their result, and how many arithmetic expressions were recomputed. Zero failures is the only pass
- **`worldFacts`** — that it was built, or that the unit carried no arithmetic and no timeline so it was skipped
- **Each remediation round** — what it fixed, and **what it introduced**. A round that broke nothing is worth stating; a round that broke something is worth stating twice
- **The learning loop** — how many findings went to each of the four destinations, every skill amendment proposed, and the disposition of each: approved, declined, and on whose reasoning. **No amendment proposed is a good result — say so.** A run that proposes one per finding has not classified them

If the audit came back Partially Compliant, say so and name the gap.

### Standing warnings

None at present. Where a build finds a defect in the RTO's own artefacts, reproduce it, report it as a warning, and let the RTO decide - see `references/house-standard.md` for the two that were closed this way.
