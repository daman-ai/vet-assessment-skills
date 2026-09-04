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
- Where the pack looks wrong, **say so in the report - do not silently teach around it.** Correcting an assessment is the other skill's job, and doing it here hides the defect.

## What you produce

1. `[UNIT]_Learner_Guide.docx` - the learner-facing guide
2. `[UNIT]_Delivery_PowerPoint.pptx` - the trainer-facing deck
3. `[UNIT]_Resource_Report.md` - counts, cross-reference reconciliation, open questions

Deliver `.docx`/`.pptx` **and their PDFs together**, regenerated in the same pass. A PDF older than the file beside it is a delivery defect.

## The one idea this skill is built on

**Build one content spine, then render it twice.**

The guide and the deck teach the same unit from the same assessment, and the single most common failure in a paired build is drift: the deck cites Q9 where the guide cites Q10, the guide's tempering figure and the slide's disagree, a topic gains a sub-section in one and not the other.

So the content is authored **once**, as structured JSON, and rendered twice - Word by `Build-Guide.ps1`, PowerPoint by `Pptx-Blocks.ps1`. Neither renderer invents content. If a fact is wrong it is wrong in one place, and fixing it fixes both.

Detail: `references/content-model.md`.

## The governing principle

**A defect is caught at the earliest stage where its data exists, mechanically wherever a script can do it, and the model-driven audits are reserved for truth and provenance.**

Three rules follow from it, and every stage below is arranged around them.

1. **If the data exists, the check runs now.** A check never waits for a render, a placement or an audit round when its inputs were complete three stages earlier. Figure content is machine-readable JSON on the spine from Stage 3b; on one build nothing read it as a figure until hour four, and what it turned out to contain - six figures reproducing an assessed answer grid already filled in, two under the task's own column headings, in an open-book assessment that expressly permits the Learner Guide - was a not-for-release blocker found on the third audit round. The gate finally written to catch it reads the spine and never opens a `.docx`. **Nobody was waiting on artwork; they were waiting on a habit of reading documents.**
2. **If a script can decide it, a script decides it.** Every finding a judgement stage makes twice is a gate that was never written. An audit round costs about 40 minutes; the sweep that would have caught the same class costs seconds.
3. **The readers decide truth and provenance, and nothing else.** The personas and the clean-room audit keep their full scope on the full artefact, and they read a document a script has already cleaned. Moving a reader from hunting to deciding is the whole gain.

**And the constraint that binds all three: nothing here is ever made faster by weakening a check.** Speed comes from four sources only - moving a check earlier, converting a judgement-stage finding into a mechanical gate, running genuinely independent work concurrently, and deleting duplicated effort. Never from removing coverage.

**Nothing moves; everything is added.** Where a check below is described as moving earlier, what is added is an **earlier run on data that already exists**. The later run stays, unchanged, on the artefact it always read - a spine check and a rendered check make different claims, and they can differ. No allow-list is widened; several are narrowed by being moved into the audited registry with a written reason each. No threshold is loosened. **A change that trades correctness for speed is a failed change**, because a learner resource fails by teaching something untrue.

## The brand

| Brand | Resolves to | Templates |
|---|---|---|
| `MVC` | Meridian Vocational College | `MVC_Learner_Guide_Template.docx`, `MVC_Branded_PPT_Template.pptx` |

Brand resolution, the trading-name rules and the logo/palette/identity swap all work exactly as they do in the assessment skill, and read from the same `assets/branding.<brand>.json`. **A brand with no approved Learner Guide template and no deck template cannot be built** - ask the RTO for one rather than generating it.

**Everything else about a brand is a property of the RTO, not of this build, and it lives in the RTO profile pack** built once at Stage S0-RTO: the patched templates, the resolved palette role map, the identity strings of this brand and of every other brand in the file, deck layouts, the guide profile, the no-notes layout list, house image-framing rules, locked terminology and the document-control block spec. **No template filename, palette hex, provider code or CRICOS code is ever typed into a build script** - one build ended up with ten build-local scripts hard-coding a single unit, a single brand and that build's own counts, which is not portability however loudly a skill claims it.

## What to read, and when

| Read | Before |
|---|---|
| `references/gates.md` in full | **Stage 0** - pre-flight compiles the spine schema, resolves the palette and proves every gate fails on a planted defect, so the gate contract has to be in hand before the build starts |
| `references/source-extraction.md` | Stage 1 |
| `references/content-model.md` | Stage 2 |
| `references/content-agent-brief.md` - the template every content agent is handed | Stage 3 |
| `references/learner-guide.md` | Stage 3 |
| `references/powerpoint.md` | Stage 3 |
| The assessment skill's `references/house-style.md` and `references/readability.md` | Stage 3 |
| `references/visuals.md` | Stage 3b |
| `references/gates.md` again, for the spine band | Stage 3c |
| `references/personas.md`, and the assessment skill's | Stage 5 |
| `references/audit-checklist.md` in full | Stage 6 |
| `references/visuals.md` section 9, and the `docx-images` sub-skill | Stage 7b-ii |

The readability and house-style blocks are **shared with the assessment skill and must not be forked**. Where a rule genuinely differs for this document type it belongs in `references/learner-guide.md` under *Carve-outs*, and nowhere else.

## Model tiers for the agent stages

**Use the model the stage needs, never the biggest one everywhere** - the same rule as image quality: paying top tier for mechanical work buys nothing anyone sees. The dividing line is whether the agent exercises **judgement** or applies **a specification that already exists**.

| Stage | Work | Tier |
|---|---|---|
| S0-RTO - profile pack | Measuring an RTO's own artefacts and writing the pack, once per RTO | capable |
| 0 - pre-flight, schema compile, self-tests | Scripts, not agents | none |
| 0 - the auditor's independent unit extraction (background) | Verbatim transcription with zero build context | cheap tier - **but it must be a separate agent that has seen nothing of the build**, and that is an isolation rule, not a cost one |
| 1 - corpus extraction and typed parse | Mechanical transforms | cheap tier |
| 1 - hazard disposition | Deciding how the build will handle an upstream pack defect | capable |
| 2 - derived registers | Derivation from the corpus; no judgement in it | cheap tier, or no agent at all |
| 3 - content agents | Authoring 3,000-word Topics to AQF pitch | capable (session default) |
| 3b - visuals and prompts | Planning what each figure teaches | capable |
| 3c - the spine gate band | Scripts, not agents | none |
| 3d - figure sheet review | Adjudicating a mirror or leakage anchor and writing the reason | capable |
| 4 / 4b / 4c / 7c gates | Scripts, not agents | none |
| 5 - personas and flow pass | Reading the documents as a human would | capable |
| 6 - clean-room audit | The provenance audit; the verdict the build ships on | **most capable available** |
| 6b - finding arbitration | The sweep is a grep; the re-examination it forces is a read of the extract | none for the sweep, capable for the re-examination |
| 7 - remediation appliers | Applying fixes whose replacement text a verifier already wrote | **cheap tier, low effort** - the judgement was spent upstream |
| 7 - verification fan-out | Adversarial refutation of the fixes | capable |
| 7d - confirming audit read | Scoped read of the placed figures against an already-adjudicated figure sheet | capable |
| Extraction, spec migration, JSON validation | Mechanical transforms | cheap tier, or no agent at all |

A fix list that carries quoted defective text and exact replacement text is mechanical **by definition** - route it cheap. A finding that says "reconcile these two passages" still needs judgement - route it capable. When one fan-out mixes both, split it rather than paying the capable rate for the mechanical majority.

**The tier table shortens as the gate list grows, and that is the point.** Every class of finding converted into a mechanical gate is work that no longer needs any tier at all.

## The stage sequence

```
S0-RTO   profile pack (once per RTO, cached, off the per-build path)
  0      pre-flight: compile the schema, resolve the palette, self-test the gates
         |-- background: the auditor's independent unit extraction (cached per unit release)
  1      corpus: pack extraction || live unit extraction -> join at the reconciliation
  2      contract, registry SEED, four derived registers, artwork cost go/no-go
  3      authoring, through a validating spine writer
  3b     visuals planned, prompt lint, cost count confirmed against the Stage 2 go/no-go
         |-- background: 7b-i GENERATE + image review (keyed by slot + prompt hash;
             ledgered as '7b-i', blocking, heartbeat, re-checked at 7d)
  3c     THE SPINE GATE BAND - fanned out, concurrent with generation
  3d     figure sheet review - a reader adjudicates the anchors
  4      render + the full gate set from one entry point
  4b     readability
  4c     brand: apply the mark and PROVE it
  5 / 6  REVIEW BAND - personas || clean-room audit, concurrent, isolated
  6b     finding arbitration - between a finding and a work order
  7      remediate on the spine: registry, enumerate, fix, re-run the 3c band, re-render
  7b-ii  PLACE the artwork
  7c     post-placement FULL re-gate
  7d     confirming audit read, scoped to what placement changed
  8      deliver
```

## What runs concurrently, and what genuinely cannot

Five serial dependencies in this pipeline were never real. **Not one of them is a check** - every one was an ordering habit, and removing it removes no coverage.

| These run at the same time | They join at |
|---|---|
| Pack extraction and the live training.gov.au extraction (Stage 1) | The `PC -> KE -> Question` reconciliation, which stays blocking and unchanged |
| The auditor's independent unit extraction, launched at Stage 0 | Stage 6, which reads it |
| Route A generation and the image review (7b-i, launched at the end of 3b) | 7b-ii placement |
| The whole 3c gate band, fanned out gate by gate | 3d |
| Stage 5 personas and flow pass, and the Stage 6 clean-room audit | 6b arbitration |

- **Stage 1's two extractions.** "The pack is the authority" is a **conflict-resolution rule** - which source wins a disagreement - not an instruction about which browser tab opens first. The spine waits for the pack; the browser session does not.
- **The auditor's unit extraction.** It depends on nothing the build produces, so it runs once from minute one, by an agent with zero build context, cached against the unit release. **It stays the reviewers' own independent extraction** and the transcription-error check it exists to preserve is fully intact; each round re-verifies only the cheap currency check. On one build it was performed in full three times against an input all three rounds recorded identically.
- **Generation, but never placement.** Every reason to pin artwork late is a reason to pin **placement** late, and none of them applies to writing a PNG into a folder.
- **The 3c band.** Those gates share two inputs - the spine and the corpus - and none reads another's output, so the band's wall clock is the slowest gate, not the sum of twenty scripts.
- **The review band.** The two arms consume identical inputs and neither reads the other's output. Running them concurrently makes showing the auditor the personas' findings **structurally impossible** rather than merely forbidden, so concurrency **strengthens** the isolation rule.

**What stays strictly serial, deliberately:**

- **Corpus before authoring** - authoring needs the typed grids and the derived registers.
- **The whole-spine 3c band before the render** - cross-node invariants need the whole spine present.
- **Remediation before re-render.**
- **Placement after Stage 7's re-render** - a re-render assembles from a fresh template and throws placed images away.
- **Arbitration between the review band and remediation** - a work order built on a false finding costs a whole round, and on one build it did.
- **The full post-placement re-gate and the scoped confirming read before delivery** - the stage that changes the page most must not be the least checked.

---

## Stage S0-RTO - The RTO profile pack (once per RTO, cached and versioned)

**Consumes:** the RTO's own approved templates and delivered artefacts, and its branding file.
**Produces:** a versioned profile pack the build reads and never re-derives.

This skill is shared across RTOs, brands and units, and almost everything a build hard-codes is a property of the **RTO**, not the unit. Re-deriving it every build is how ten build-local scripts on one build came to hard-code one unit code, one brand and one build's own counts, and how a document-control block went through three consecutive audits recorded only as "not verifiable" - because nothing declared what it was supposed to be. So it is assembled and validated **once**, off the per-build critical path, and the one-time cost honestly belongs here, amortised across every unit that RTO ever builds.

**The pack is `assets/rto-profile.<rto>.json`**, written against `assets/rto-profile.schema.json` and validated by `scripts\Get-RtoProfile.ps1`, which is also the S0-RTO gate:

```powershell
& "$SkillDir\scripts\Get-RtoProfile.ps1" -Rto MVC -Check     # Assert-RtoProfile; exit 1 = do not build
```

`assets/rto-profile.mvc.json` is the worked example. **A pack POINTS at its sources and copies none of them** - identity strings and palette hexes are read from the branding profile, geometry and callouts from the guide profile, layouts and slot ordinals from the deck profile. A restated hex is a second source of truth free to drift from the map the swap actually applies, which is how a crossover sweep came to print "no crossover" over 766 live occurrences.

The pack holds, and Stage 0 validates:

- The **geometry-patched** guide and deck templates. The patch belongs to the template, not to the build.
- The **resolved palette role map**, over a closed role enum, plus the identity strings - trading name, legal entity, provider code, CRICOS code, domain, street address - for this RTO **and for every other brand in the branding file**. The crossover sweep derives its forbidden set from these; it never hand-types a hex.
- Deck layouts, the guide profile, and the **no-notes layout list** - which layouts are legitimately allowed to carry no speaker notes. **That list is an allow-list against a shipped deck rule, so it obeys allow-list discipline**: the list itself stays in the deck profile, one source of truth, and the pack carries **one written reason per entry**. `Assert-RtoProfile` fails when the two sets differ in either direction - an exemption with no reason, or a reason for an exemption nobody made - and refuses any entry that is also on the notes-**required** list. Every reason is surfaced to Stage 6 as evidence.
- House **image-framing rules** and the **negative-constraint list**, including the closed person-noun list the prompt lint matches against.
- **Locked terminology** - canonical terms, their forbidden near-synonyms, the required paired forms.
- The **document-control block spec**.
- Declared **carve-outs**, each with a written reason.

**A brand with no approved Learner Guide template and no deck template cannot be built** - ask the RTO for one rather than generating it. **An RTO with no profile pack builds the pack first**; a build must never fill the gap with literals in its own scripts.

## Stage 0 - Pre-flight, schema compile and self-tests (blocking)

**Consumes:** the RTO profile pack, the renderer scripts, the gate scripts, the seeded-defect fixture corpus.
**Produces:** the compiled spine schema, the resolved palette object, fixture results, the endpoint probe, the open stage ledger, and the auditor's independent unit extraction running in the background.

Establish the **build directory outside the skill**. Never write build output into `~/.claude/skills/learner-guide/`; the next build inherits it.

Dot-source the library - one line, which resolves the assessment skill's scripts and loads both libraries - then the two gate libraries this skill adds:

```powershell
. "$SkillDir\scripts\Lib-Resolve.ps1"
. "$SkillDir\scripts\Lib-GateCommon.ps1"    # the shared, DERIVED answers every spine gate needs
. "$SkillDir\scripts\Get-RtoProfile.ps1"    # Get-RtoProfile, Assert-RtoProfile
. "$SkillDir\scripts\Stage-Ledger.ps1"
```

Then load the RTO profile pack and confirm the templates are sound and the geometry patch has been applied:

```powershell
$rtoProfile = Get-RtoProfile -Rto $brand    # S0-RTO: templates, palette roles, identity, layouts, terminology
$P          = Get-GuideProfile -SkillDir "$SkillDir\scripts"
Assert-DocxPackage -WorkDir (Expand-Docx -Path $rtoProfile.GuideTemplate) | Out-Null
(Test-PptxPackage  -WorkDir (Expand-Docx -Path $rtoProfile.DeckTemplate)).Ok
```

`Get-RtoProfile` **validates before it returns and throws when it cannot** - a missing pack, an unapproved template, a palette role that resolves to nothing, a no-notes exemption with no written reason. There is no fallback profile and no default template path: an RTO with no pack builds the pack first.

**Do not name that variable `$rto`.** Dot-sourcing a script runs its param block in your scope, so a script parameter called `-Rto` leaves a `$Rto` behind, and in an earlier draft it was typed `[string]` - which silently coerced the whole profile object to its string form, leaving `$rto.GuideTemplate` empty with nothing erroring anywhere. The script's parameters are now untyped and named `-SkillPath` / `-BrandingPath` so they cannot collide with a build's own `$SkillDir`, and this is the general trap: **check what a dot-sourced script's param block will overwrite before you dot-source it.**

**Template paths come from the pack, never from a filename typed into a build script.** The previous pre-flight named one brand's deck template inline, which is precisely the portability defect the pack exists to remove.

**Run `scripts\Patch-GuideTemplateGeometry.ps1` once** against a freshly installed template. It is idempotent and says when there is nothing to do. Skip it and every full-width table overhangs the right margin - see `references/gates.md`.

Then the pre-flight assertions. **All of them block except the endpoint probe**, and every one of them reads data that exists before a word is authored:

- **`Assert-RtoProfile`** (`scripts\Get-RtoProfile.ps1`) - the pack loads, both approved templates exist, every palette role in the closed enum resolves, every required identity field is present and is not shared with another brand, every no-notes exemption carries a written reason, and every carve-out carries a scope and a reason. Its check-sets - required keys, the role enum and its aliases, the identity fields - are **derived from the schema file**, so the validator and the specification cannot drift apart.
- **`Assert-RendererContract`** - each renderer exports `Get-RendererContract`: the field names it reads per node type, which are required, and which must be non-empty for the node to render at all. Pre-flight **compiles those into the spine schema** and fails if two renderers declare different field sets for the same node type, if a container type declares no must-be-non-empty field, or if the compiled schema changed without a version bump. It parses property accesses rather than substring-matching, so a field named only in a comment no longer counts as rendered; it globs the renderers rather than naming them; and it deletes the hand-copied field arrays a spine test used to keep, which were a second source of truth free to drift. **Compile the schema, never write it** - five role-play boxes shipped empty on one build because seven parallel authors wrote one set of field names and the renderer read another, and the box was drawn anyway.
- **`Resolve-Palette`** - the brand map resolves **once**, as a total function over a closed role enum, and the resolved object is passed to every consumer. A role with no match **throws** rather than falling through to a default, and **a role that maps to itself throws**: a self-mapping role is an unresolved property name, never a legitimate no-op. Pre-flight also fails if the objects the several callers pass carry differing property-name sets for the same role. Nothing downstream ever re-resolves a role by name. This is the root of the brand defect that passed the brand gate - one role was named differently on the object the swap actually passed, so it silently mapped to itself, the apply loop skipped it, nothing errored, and 766 of another brand's fills survived into the delivered set.
- **`Assert-DownstreamPalette`** - every sub-skill or shared config that emits styled output must accept an **injected** palette and must **throw** when a caller that declared a brand supplies none. Pre-flight reads each such configuration, compares it to the brand resolved for this build, and fails if there is no injection path; where a repaint is genuinely unavoidable it registers that repaint as a required stage whose absence fails delivery. Catches an ordering defect knowable at minute one: the brand swap must precede artwork, and the artwork sub-skill then built native tables from a palette hard-coded to a different brand, so the guide went from zero crossover hits to hundreds **after** branding had been declared clean.
- **`Assert-GateFixtures`** - **every gate must be shown to FAIL on a seeded-defect fixture before any clean result from it is trusted, and the plant itself must be verified to have landed.** One build's first plant attempt was a no-op: it proved nothing, and it passed.
- **`Assert-GateHygiene`** - a gate may scan only files **declared as content sources**, never every `.ps1` in the build directory behind a filename regex; a remediation script that must quote the literal it deletes marks a `# gate-exempt:` region the scanner strips. **Portability:** fail any promoted gate containing a literal unit code, RTO code, CRICOS code or six-digit hex - identity and palette come from the profile pack, counts from the contract, filenames from the unit code. Every gate prints its check-set size and names the map it derived from.
- **`Assert-AllowListDiscipline`** - every allow-list entry lives in the **versioned registry beside the rule it weakens**, never as a script parameter default, carries a **written reason**, and is surfaced to the audit as evidence. A build-local `Check-`/`Test-` script that is not a copy of a skill script must record why a new gate was needed.
- **`scripts\Probe-GenerationEndpoints.ps1`** - **non-blocking by design.** One low-quality image against every external generation endpoint the build will use, so a quota refusal surfaces at minute one and the operator can top up **in parallel with content authoring**. Read its exit code, not its prose: 0 means go; 2 means the account is out of credit - tell the user now and keep authoring; 3 means no API key was found and no call was made. A refusal re-sequences attention; it is never a reason to refuse to author content. On one build a credit block was discovered two hours in, at the first real generation call, and the critical path waited 55 minutes on it.

Pre-flight also **declares two things every later stage is held to**:

- **The long-stage output contract.** Every long-running judgement stage creates its output file and writes its **header and scope section before analysis begins**, then appends each section as it completes, under a heartbeat, and on restart resumes by reading what it already wrote. On one build the third audit round ran three times: two runs died mid-analysis having written nothing, and the run that survived did so only because it was restarted with instructions to write the report first.
- **The mandated-sweep list and the render-set constant.** The render set is `4`, `7`, `7b`, `7c` - **placement and the post-placement re-gate are renders** - and every stage record must enumerate which mandated sweeps actually ran.

Then open the stage ledger, and **record every stage into it as that stage finishes** - not from memory at the end, which records what was intended rather than what happened:

```powershell
New-StageLedger -BuildDir $out -Unit $code | Out-Null
# ... and after each stage, with its own real start and end timestamps, sub-second:
Add-StageRecord -BuildDir $out -Stage '5' -Name 'Personas' -Status pass -Findings 4
# ... and where a gate ran with -AllowPartial, the rules it could not run, with a reason:
Add-StageRecord -BuildDir $out -Stage '4' -Name 'Render + full gate set' -Status pass `
                -Partial $gr.Partial -Note 'pack question list not yet parsed; re-run at 7c'
```

**Every stage in `$script:LedgerRequired` must have a record**, and the list is the script's, not a copy of it - `0, 1, 2, 3, 3b, 3c, 3d, 4, 4b, 4c, 5, 6, 6b, 7b-i, 7b, 7c, 7d, 8`. Read it from `Stage-Ledger.ps1` rather than transcribing it here; a hand-copied stage list is exactly how six blocking stages came to be enforced by nothing.

`skipped` is an honest status and it is allowed. It simply will not pass Stage 8 for a blocking stage, which is the point. `n-a` is allowed too, **and both cost a written `-Note`** - a stage recorded as not applicable with no reason is a shrug, and the ledger rejects it.

**Last, launch the auditor's independent unit extraction as a background task**, by an agent with **zero build context**, cached against the unit release and archived as an audit artefact separate from anything the build authors. It depends on nothing the build produces, so it need never sit on the critical path of a review round; on one build it was performed in full three times against an input all three rounds recorded identically. **The isolation rule is untouched** - it remains the reviewers' own extraction, and the transcription-error check it exists to preserve is fully intact. Each round re-verifies only the cheap currency check: usage recommendation and release, on the day.

## Stage 1 - The corpus (two extractions in parallel, one canonical output, blocking)

**Consumes:** every document in the assessment pack, and the unit on training.gov.au.
**Produces:** ONE canonical corpus directory, a typed parse of it, and a dispositioned hazard list.

**The two extractions start together.** The pack extraction and the live training.gov.au extraction depend on nothing of each other's. "The pack is the authority" is a **conflict-resolution rule** - which source wins a disagreement - not an instruction about which browser tab opens first. The spine waits for the pack; the browser session does not. They **join at the reconciliation**, which stays blocking and unchanged.

Source the unit at `https://training.gov.au/training/details/{UNITCODE}/unitdetails` in a **JavaScript-capable browser** - `WebFetch` and `curl` return an empty shell. The currency and AQF-level gates apply exactly as in the assessment skill: a unit that is not `Current` stops the build, and a unit spanning two AQF levels is a question for the user, never an inference.

**`Assert-CorpusComplete` - blocking.** **Every pack document, learner-facing and assessor-only, is extracted exactly once into ONE canonical corpus** that every later stage and every audit consumes. The gate fails when the count of extracted text files does not equal the count of documents the pack manifest lists, and fails any later stage that re-extracts a file already present with the same hash. It is a count and a hash comparison; there is no judgement in it and it needs no allow-list. On one build the assessor guide and the workbook were extracted twice, byte-identically, four hours apart - and two assessed knowledge documents were never extracted early at all, reaching disk 4h18m into a 4h55m build. **The open-book leak that stopped release was in exactly the document nobody had extracted.** This gate is the precondition that makes every spine-side sweep below possible.

Extract, verbatim and completely, and **parse into typed assessment data** rather than prose:

- **Every question**, with its number, sub-parts, focus, KE mapping and word guide.
- **Every practical task and observation item**, with its number.
- **Every response grid**, identified **structurally** - first column pre-filled, remaining cells carrying the tool's blank-answer token - together with **model-answer regions**, **benchmarks** and **schedules**. Everything downstream that reasons about assessed answers reasons about these typed objects, not about paragraphs.
- The scenario world already in use - venue, characters, employer, locations. **Reuse it; never invent a second one.** A guide set in a different venue from its assessment reads as a different unit.

**`Assert-PackSelfConsistency` - blocking, before authoring opens.** Three sweeps over the corpus: **numeral divergence** (the same anchor given different values across or within documents), **benchmark divergence** (two benchmarks treating the same item to different criteria), and **arithmetic** (stated totals against stated components). It does **not** block on the pack, which this build cannot fix; it blocks on each hazard being **dispositioned** - acknowledged with a written handling decision and handed to the content stage - and that distinction is what stops it becoming noise. Nine upstream pack defects on one build were all mechanically detectable before a word was written, and one mattered more than the rest: an unexplained gap between a card's finished weight and its own instruction was, in the auditor's own words, the gap the guide tried to fill by inventing a figure. **This is the one place where earlier detection prevents a downstream defect rather than finding it sooner.**

**Reconcile the two sources before writing anything.** State the `PC -> KE -> Question (+ observation)` map back, and flag every mismatch. That map is the contract for the rest of the build.

Detail: `references/source-extraction.md`.

## Stage 2 - Contract, registry seed and the derived registers (blocking)

**Consumes:** the canonical corpus and its typed parse.
**Produces:** the locked contract, a seeded `figures.json`, and four **derived** registers - written by `scripts\New-WithholdRegister.ps1`: the withhold register, `grids.json`, the gate-only assessor cells, and one `agent-pack\<sub-section>\` directory per sub-section holding exactly what a content agent may see.

One pass, serial, with sight of everything.

- **Topic per Element.** One Topic per Element, one sub-section per Performance Criterion.
- **Assign every question to exactly one PC sub-section** as its primary preparation. A question may be signposted in more than one place, but it is *prepared* in one - otherwise the cross-reference table has no defensible answer to "where is this taught".
- **Put the artwork cost to the user here, not at Stage 3b.** The Route A count is `(sub-sections x 2) + 1` and every one of those numbers is fixed the moment the sub-sections are - so the go/no-go can be asked while authoring starts, and a no or a quota top-up costs nothing. On one build the count was first stated at Stage 3b and the credit block behind it was found at Stage 7b, three hours in, and the build waited 55 minutes on it. Record the count and the answer in the ledger note for this stage; Stage 3b re-counts against the planned visuals and must match.
- **Plan the deck alongside the guide, not after it.** Each Topic needs **at least 15 slides**, planned from the same sub-sections. Where a Topic cannot reach 15 from genuine content, record it now and report it - never pad.
- **Lock the contract**: scenario card, terminology, numbering plan, the question map.

**Seed the figure registry - do not pretend to lock it.** `figures.json` is **seeded from the corpus** here, then reconciled and **re-locked at 3c** against what was actually authored. A registry locked before anything is written describes an intention rather than a document: on one build it listed 31 figures against 112 placed captioned figures. Each entry carries its authority class (**P** pack, **U** unit, **L** cited law, **V** venue procedure), **a provenance locator naming a source document and a line or field**, its canonical value, the stale forms it must never appear as, and the strings that exist only in the assessor guide and must never reach a learner document. **A figure not in the registry is a figure nobody is checking**, and an unchecked figure is how a fabricated legal requirement once shipped - but that sentence is only true if something proves nothing is *unregistered*, which is what `Assert-FigureCoverage` does at 3c. `Test-FigureConsistency` enforces the registry at Stage 4, before every Stage 7 re-render, and again at 7c.

**`Assert-Provenance` runs on the seed.** Every entry's locator is grepped in the named source and the entry fails unless the value occurs there. This activates the `authority` and `source` fields the registry already carried and that no gate ever read - which is why a sixty-row provenance ledger was rebuilt by hand in all three audit rounds of one build.

**Four registers are DERIVED here, not typed, so none of them can be short:**

| Register | Derived from | Enforced by |
|---|---|---|
| **Withhold register** | every assessed response cell in the learner-facing tools, plus every value a figure or passage declares withheld, plus every value computable from an assessed task's own inputs | `Assert-WithholdRegister` at 3c and 7c |
| **Ambiguity list** | values the sources apply to two different subjects, and registry figures sharing numerals | the content agents, and `Assert-Terminology` |
| **Deck-must terms** | the benchmarks' own accepted-answer sets | `Assert-DeckParity` |
| **Assessor-only shingle set** | n-grams scoped to the **model-answer and benchmark regions** of the assessor guides | `Assert-AssessorLeakage` |

A hand-maintained list is always shorter than the truth: one build's registry carried 32 figures against 8 deck-must terms, leaving 24 corrected figures with no deck-side requirement at all.

**`Assert-IdentifierNamespace` - blocking.** The guide's own appendix and section identifier scheme must not collide with any scheme in the source pack; a collision forces a qualified convention into the contract **now**. On one build the appendix letters collided across 151 references, and the renumbering left a stale reference found a round later. Cross-reference resolution then runs at 3c and Stage 4, and **the resolved cross-reference index is supplied to the audit as evidence** - which also pre-refutes the false finding where an auditor reported an existing section as non-existent.

Detail: `references/content-model.md`.

## Stage 3 - Authoring through a validating spine writer (content agents in parallel)

**Consumes:** the contract, the corpus, the compiled schema, the hazard list, the withhold register and the ambiguity list.
**Produces:** the spine.

Roughly one Topic per agent, **and no agent reads the corpus.** `scripts\New-WithholdRegister.ps1` derives one `agent-pack\<sub-section>\` directory per sub-section from it, and that pack is everything an agent receives: `contract.json` (scenario, terminology, numbering, the sub-section's question map); `tasks.md` (the learner-facing text of its assigned tasks - stem, scenario, column headers, row labels, word guide - and never a model answer); `withhold.json` (per task: `kind`, `headers`, `assessedHeaders`, `items`, `subjects`, `unassessedSubjects`, `allowance`, `permittedGround`, and `shape` - rows, assessed columns, bullets per cell, word guide, benchmark minimum - as numbers only, no answer text); the recipe cards, appendices and unit extract; `figures.json` read-only; and the shared style block. The brief is `references/content-agent-brief.md`, a template Stage 3 fills from the contract and the RTO profile, and it carries the relocation rule the agent applies at write time: teach the mechanism in full, then work every example on a subject from `unassessedSubjects`. An author who is handed the unassessed subjects does not have to be caught working the assessed ones later.

**Content agents never receive the assessor guides, the model rows, the benchmarks or the marking criteria, and depth reaches them only as `shape`.** A shape can only be taught toward; an answer that is read gets written. On one build the brief allowed the assessor guides "for one purpose only, to gauge how deep the teaching has to go", and seven agents wrote the model answers into an open-book guide that expressly permits itself - same items, same order, same three-part structure, often the same words - and six audit rounds found the leak one location at a time. The pattern that closed it, found at round 5 and never in the brief, withheld nothing: the mechanism taught in full, the example relocated onto a subject the task does not assess, and the counted teaching grew in every case. `scripts\Test-SubSection.ps1` is the agent's own pre-return check of its file against its pack; the 3c band asks the same questions again over the whole spine.

- Agents produce the **guide content and the slide content for their Topic in the same pass**, into the shared spine. Splitting them across agents is how the two drift.
- **Agents never write a document.** They return structured content.
- **Word floors are content requirements, not formatting**: 3,000 words of counted body prose per Topic, and **800 words per PC sub-section's Underpinning knowledge block**. Both are measured on the spine at 3c and again on the render at Stage 4, and **both are common failures** - the delivered reference guide meets the first and misses the second everywhere.

**Every write goes through `New-SpineWriter`, which validates against the compiled schema and REFUSES the write**, returning the violation to the agent to fix in-loop. The refusal set is deliberately narrow - **exact, locally fixable violations only**:

1. a **field name no renderer reads** (UNREAD - content that will silently vanish),
2. a **container whose readable fields are all empty** (MISSING - a titled empty box),
3. a **visual with no explicit `kind`**,
4. an **unresolvable figure or cross-reference token**.

Each is set comparison against a compiled contract with a zero-judgement failure condition, and the agent can always act on the message where it stands. That is what makes refusal the right instrument here: the defect becomes **unrepresentable** rather than merely detectable.

**Fuzzy and whole-corpus checks are deliberately NOT enforced at write time.** Mirrored answer grids, leakage shingles and bare numerals need context an agent writing one Topic does not have, and a refusing writer an agent cannot satisfy produces workarounds rather than compliance. Those run at **3c**, on the whole spine, where a human can adjudicate with the anchor in front of them. **This is a split by check exactness, not a softening of anything** - every one of those checks still blocks, at 3c.

**`Assert-SpecRenderable`, exact arm, at write time**: a visual spec must declare its `kind`, and a spec whose node count exceeds the renderer's box cap is refused where it is written.

**`scripts\Test-SpineRead.ps1 -BuildDir $out` is the executable arm of this rule** - run it on every write and again across the whole spine at 3c. It reports **UNREAD** (a field carrying content no renderer reads) and **MISSING** (a node whose entire content is unread - a titled empty box). It walks the renderers' PowerShell AST rather than grepping their source, so a field name that appears only in a comment no longer counts as rendered; it has no depth cap; and it globs the renderers rather than naming two of them. Five role-play boxes shipped empty on one build because seven parallel authors wrote one set of field names and the renderer read another - the content was authored, reviewed and gated, and it never reached the page.

Detail: `references/content-agent-brief.md`, `references/learner-guide.md`, `references/powerpoint.md`.

## Stage 3b - Plan the visuals, then launch generation (blocking exit check)

**Consumes:** the spine and the RTO profile's framing rules.
**Produces:** every figure's full content on the spine, a linted prompt set, the cost decision, and a launched background generation job.

**One PC sub-section gets four visuals**, plus one cover image for the guide:

| Slot | Visual | Route | Placement |
|---|---|---|---|
| `X.1` | Topic image | A - generate | After the sub-section heading, before the first body paragraph |
| `X.2` | Process diagram | B - build natively | Immediately after the step list it renders |
| `X.3` | Workplace image | A - generate | Beside the case study or worked example |
| `X.4` | Summary table or infographic | B - build natively | At the close, before the assessment link |

Emit each as a prompt block with `GImagePrompt` at the exact placement. The guide is built with **prompts on the page, not pictures**; 7b-ii turns them into artwork.

**The spine holds every figure's FULL content - rows, nodes, items, caption, alt text, slide bodies, speaker notes and the prompt - and that is the fact this whole pipeline turns on.** Figure content is machine-readable JSON here, hours before a picture exists, so nothing about a figure's *meaning* ever needs to wait for placement. On one build nobody noticed: the first two audit rounds read a document in which every figure was still a prompt block, round 1 correctly reported the figures as missing and was correctly told that was expected at that stage, and **nobody drew the consequence that the figures had therefore never been read by anyone**. Round 3 read them and stopped the release.

**Route B specs live IN the spine, on the visual entry, beside the prompt and alt text they must agree with.** The build's spec-writer is a thin reader that copies spine to manifest, keyed by slot - it is `docx-images\scripts\New-ManifestFromSpine.ps1`, which builds the whole manifest from `visuals[]` here at 3b before any document exists, copies every diagram spec, sets `kind` from the spine, and carries a generated image forward by slot and prompt hash so a re-render never re-bills. **A build script must never restate spine content.** One build held its diagram specs as hand-typed copies inside the spec-writer: three remediation rounds corrected the spine and the figures kept teaching the superseded calculation, because nothing that edited the spine could see them. A diagram whose slot has no spine spec is a **spine defect** - the spec-writer refuses and reports it, and nobody patches the manifest by hand.

**Route A is generated and costs money. Route B is built as native Word objects and is free.** Never image-generate a diagram or a table - a generated diagram carries labels nobody can correct, in a document an auditor reads.

**Exit check 1 - `Assert-PromptLint`, blocking, before any generation spend.** Every prompt is checked against the RTO profile's house framing rules and the artwork sub-skill's negative-constraint list. It **fails a prompt whose grammatical subject is a person noun** where the house rule requires hands-and-equipment framing, and **fails any prompt omitting a required negative constraint for its subject class**. The subject test is a closed person-noun list from the profile matched at the head of the subject phrase - not a semantic judgement - and the constraint test is set membership. An allow-list is available **per slot with a written reason** for the rare prompt where a person is the legitimate subject. This is a string check over `visuals[].prompt` costing seconds, and on one build its absence cost 48 minutes of regeneration: 47 of 57 illustrations failed a first image review on identifiable faces, 17 failed a second, 2 a third, and the fix script that eventually ran read prompts, not images. **The image review is not weakened by this and keeps its full authority** - it caught two genuine food-safety defects. The lint removes the volume the review must wade through, not its scope.

**Exit check 2 - re-count the cost against the planned visuals and confirm it matches the Stage 2 go/no-go.** The count was first known, and the question first put, at Stage 2; a mismatch here means a sub-section gained or lost a slot and the user is told the new number, not asked again from scratch. Route A is `(sub-sections x 2) + 1`. `docx-images` asks before about ten, so a guide of any size is a conversation, not an assumption.

**Then launch 7b-i - generation and image review - as a BACKGROUND job**, keyed by **figure slot and prompt hash**. See 7b-i below. **Placement does not move.**

**The visual theme is the scenario business's, not the RTO's.** Every colour justified by something real in that business. The RTO palette is document attribution in the footer only. Expect the scenario-themed visuals to sit against RTO-branded callouts, and say so in the report.

Detail: `references/visuals.md`.

## Stage 3c - The spine gate band (NEW, blocking, mechanical, fanned out, concurrent with generation)

**Consumes:** the spine, the corpus, the unit extract and the renderer source. Nothing else - and nothing in this band opens a `.docx`.
**Produces:** a pass or fail per gate, plus located anchors for 3d to adjudicate.

**This is the highest-leverage stage in the pipeline.** Every check whose only inputs are those four runs **here**, on data that is already complete, instead of after a render, after placement, or in an audit round. On the build this design was written from, 65 of 77 defects were mechanically detectable from data that already existed, earlier than the stage that caught them.

**These gates share only two inputs and none reads another's output, so fan them out.** Their wall clock is the slowest gate plus process start, not the sum of twenty scripts - and running them alongside background generation is what takes artwork off the critical path without touching a single check.

```powershell
& "$SkillDir\scripts\Run-SpineGates.ps1" -BuildDir $out     # fans out, joins, writes 3c-results.json, cuts the figure sheet on a green band
```

**`Run-SpineGates.ps1` is the only way this stage is run or recorded** (landed 3 Sep 2026). It introspects every member's parameters and passes only what that copy declares; a member that is absent, refuses a missing input, throws or exceeds `-TimeoutMinutes` is a FAIL naming the reason, never a skip; `-Only` prints a PARTIAL RUN banner and exits 3, so a subset can never stand for the band; and the figure sheet is cut in a third phase only after every blocking member passed, so 3d never reads a sheet from a failed spine. A missing `unit_extract.md` refuses the whole run, because the leakage sweep needs it. The 3c ledger note records the members that ran from `3c-results.json`, and a band pass is a pass of exactly those members. **Members wired (21, all discovered from one ordered list so the self-test can never drift from the plan):** `Test-Spine`, `Test-SpineRead`, `Test-FigureConsistency` (source arm), `Check-FigureMirror`, `Check-FigureLeakage`, `Assert-PromptLint`, `Test-SubSection -All`, `Check-ShapeMirror`, `Check-RowCoverage`, `Assert-FigureCoverage`, `Assert-Provenance`, `Assert-WithholdRegister`, `Assert-SpineCounts`, `Assert-Terminology`, `Assert-CitationConsistency`, `Assert-ScenarioClock`, `Assert-IdentifierNamespace`, `Assert-SpecRenderable` and `Assert-DeckParity` fan out in phase 1; `Test-GridDisposition` joins in phase 2 on the reports the first phase produced; `New-FigureSheet` cuts the sheet in phase 3, and only on a green band. The runner threads its OWN resolved profile into the three gates that read one, because a gate refusing in a real run for want of a parameter the runner already holds is a self-inflicted gap. Every other row in the table below is specified and NOT wired; nobody performs it at 3c, and the record must say so. Measured on the reference build, 4 Sep 2026: **band wall clock 157 s against 741 s run one after another, 21 per cent of the sum**, the slowest member being the sub-section wrapper at 153 s - so the band costs what its slowest gate costs, and adding the ten new gates cost 28 seconds of wall clock rather than 410.

| Gate | What it decides | Note |
|---|---|---|
| `Check-FigureMirror` | Every figure and slide spec's row labels - across `spec.rows`, `spec.nodes` **and** `spec.items` - compared on **normalised labels rather than wording** against every typed response grid from the corpus. Fails on label overlap above threshold where more than one assessed row carries a filled answer column. | **Reports the anchor; does not decide.** Adjudicated at 3d. |
| `Check-FigureLeakage` | Verbatim assessed column headings and answer text in any visual channel. | Same: anchor, not verdict. |
| `Check-ShapeMirror` (landed 3 Sep 2026) | Prose or a numbered grid written to the model answer's SHAPE: a typed grid's row is FULL when ONE channel of the guide answers every assessed cell of it, without a word verbatim. Calibrated to block on every leak the round-6 audit found and to stay silent where it was clean; the numbers are in the script header. | Blocks on a FULL row over the register's allowance; partials report. |
| `Check-RowCoverage` (landed 3 Sep 2026) | Under-teaching, the other side of the same grid: a model row with fewer than 3 teaching sentences anywhere (`-Whole`, blocks) or fewer than 2 in its own file (reports); every KE point's concept terms present in the mapped underpinning block; a relocated worked example that teaches nothing (hollow). | Coverage and leakage read the same rows so one fix cannot manufacture the other. |
| `Test-GridDisposition` (landed 3 Sep 2026; reads the shape-mirror and row-coverage reports, and `figure-mirror-report.json` when present) | **ONE verdict** over each mapped sub-section: every row label is TAUGHT in the prose (coverage) **AND** no figure, slide, chip, caption, alt text or speaker note presents those rows as a completed grid (leakage). A mirroring visual must carry an explicit disposition - `withheld`, or `cleared, reason: ...`. | The pairing is not optional - see below. |
| `Assert-WithholdRegister` | No withheld value appears outside a posed-question context, in **any** channel of **either** artefact. Withholding is a build-wide fact, not a per-document one, and "posed question" is decided structurally by the containing node type from the renderer contract, never by prose sentiment. | Catches one artefact filling a row the other withholds. |
| `Assert-AssessorLeakage` | n-grams (n=8..15) from the assessor guides' **model-answer and benchmark regions**, swept over every text channel, with the channel list enumerated from the renderer contract so a new channel cannot be added without being swept. | Scoped deliberately; everything outside that scope reports rather than blocks. |
| `Assert-Provenance` | Every registry entry resolves in its named source; and any *source noun + reporting verb + quantity* sentence carries a locator that **resolves in that source**. | Verbatim quantities match exactly; near-misses are **reported for adjudication**, not failed. |
| `Assert-FigureCoverage` | Every number-with-unit token and every named item of equipment, material or facility carries **one of three dispositions**: matched by a registry entry, present verbatim in a canonical source, or **DERIVED with its inputs named**, each named input itself resolving. | Fails on any **undispositioned** candidate and emits the list as a located work order naming file and field. |
| Registry reconciliation | The seeded registry against what was actually authored. **Re-lock here.** | |
| `Assert-SpecRenderable` (whole-spine arm) | Node counts against the renderer's box cap, projected height against the derived column height, branch or decision semantics against the target renderer's declared capability, naming the table fallback where it has none. | Caps and column widths read from the profile and the sub-skill config, never hard-coded. |
| `Assert-CitationConsistency` | **Blocks on exact contradiction only**: one duty phrase cited to two clause numbers, one instrument's scope stated two non-equivalent ways, an adoption relationship stated inconsistently, a registry proviso absent from an occurrence of the figure it attaches to. Fuzzy similarity clusters **report** with the anchor. | Pure self-consistency over the spine; needs no copy of the legislation. |
| `Assert-ScenarioClock` | **Blocks** where a scenario names the item by its pack identifier: two production dates for one item, or production after the pack's own order form sets its delivery. Looser time attachments **report**. | The narrow blocking arm is what keeps it out of the noise. |
| `Assert-SpineCounts` | Word floors per Topic and per Underpinning knowledge block, and the two-way question cross-reference against corpus-derived references, **measured on spine fields where prompt text and body prose are separate and cannot be confused**. | Same exclusion rule as the render gate, which it does not replace. |
| `Test-Readability`, count-based arm | Paragraph length and real-lists, on the spine's **prose fields**. This is an ADDED run, not a moved one: the Stage 4b run on the rendered document is unchanged and still blocks. | The spine has no prompt paragraphs to strip, so the confound the old gate scripted around does not exist here. |
| `Assert-Terminology` | Locked terms and forbidden near-synonyms, glossary-canonical restatement, first-use expansion in reading order, structural label uniformity, question/answer pairing counts, truncation patterns and chip counts, ambiguity-list disambiguators, and **authority-class rules generated from the class** so a legislated figure can never be described in venue-ownership language. Duplicate-sentence and opener-diversity counters **report only**. | Forbid verb lists come from one shared list, so widening it widens every rule at once. |
| `Assert-DeckParity` | **Per-surface** require - a required string must appear in the guide-facing source set **AND** the deck-facing set unless the entry explicitly narrows its surfaces - plus every benchmark-accepted instrument, term and item present in **each** artefact per topic, slide row and column counts against the assessed task its chip names, a note asserting N items sitting against a table of N, and notes on every slide whose layout is not on the profile's no-notes list. | Replaces a global OR that let one occurrence anywhere, including inside a build script's comment, satisfy a requirement. |
| Cross-reference resolution | Every internal reference resolves to a target; the resolved index is written out for the audit. | |

**Coverage and leakage are ONE gate with ONE verdict, and this is the most important line in the stage.** They act on the same assessed table and pull in opposite directions. On one build, round 1 correctly demanded every assessed row be taught and every row appear on the slide; the remediation filled the grid; **round 3 then found that exact remediation as the worst leak in the build**, and the slide's own speaker note recorded the intent. Gated separately, fixing one manufactures the other, and that cost a full round.

**Every gate in this band re-runs unchanged at its original position later.** Not one of them replaces anything. A spine check and a rendered check make different claims and they can differ: on one build the guide went from zero crossover hits to hundreds through **placement alone**, with no spine change at all.

**Two thresholds are tightened here, and none is loosened.** The mirror gate's filled-cell test becomes non-empty against an **explicit unfilled vocabulary** ("Write here", "Your turn", blank, dashes) instead of a character-count heuristic - the old heuristic read a temperature, a time or a yes/no as unfilled, and **brevity must never be mistaken for absence**. The registry's `require` becomes per-surface instead of a global OR.

Detail: `references/gates.md`.

## Stage 3d - Figure sheet review (NEW, blocking, judgement, narrow)

**Consumes:** the 3c anchors and the spine's visual entries.
**Produces:** the **figure sheet**, and a recorded adjudication for every mirror or leakage hit.

**The mirror and leakage gates report anchors. A reader decides here** - on the spine, roughly four hours earlier than an audit round would, and before a single image exists. A hit is cleared **only** by recording a **written reason in an allow-list that lives in `figures.json`, beside the registry it weakens**, never as a script parameter default, and that allow-list is surfaced to the audit as evidence.

**The figure sheet is a build artefact and it travels with every later review pack**: the spine's visual entries dumped as plain text, **one block per slot** - rows, caption, alt text, slide bodies, speaker notes. It exists because a reviewer must be able to read what a figure *says* whether or not a picture has been placed yet. The rule that a diagram's labels live in its alt text, so a review that skips alt text has not read the figures, was **guaranteed vacuous in every pre-artwork round** under the old ordering, and nothing detected the vacuity.

```powershell
& "$SkillDir\scripts\New-FigureSheet.ps1" -BuildDir $out      # writes figure-sheet.txt
```

**It is generated, never written by hand, and it is stamped with the fingerprint of the spine it was cut from.** Generated, because a hand-assembled transcript drifts from the spine the moment either is edited - one build held its diagram content as hand-typed copies inside a spec-writer, and three rounds of spine corrections never touched them. Stamped, because **Stage 7 edits the spine**: a sheet nobody regenerated hands every later reviewer figure content the document no longer has, while the ledger records that the figures were read. `Test-StageLedger` recomputes the fingerprint and **blocks delivery** when it does not match, so **regenerate the sheet at the end of every Stage 7 round** and re-run any review that was handed the old one.

This is a short read that replaces an audit round, and adjudicating here does not spend the later reads: the same figures are read again by the review band, again at 7c against the placed document, and again at 7d.

## Stage 4 - Render, and the FULL gate set from one entry point

**Consumes:** the finished spine. **Produces:** both artefacts, and stamped text extracts. The stamp is real: `scripts\Get-DocText.ps1` prefixes every extract with `FIGURES: n placed drawings, m unresolved artwork prompt blocks`, a `CHANNELS:` line (tables, slides, captions, alt texts, speaker notes as they apply) and `SOURCE: <file> SHA256: <bytes> EXTRACTED: <utc>`, then a blank line, then the text unchanged to the byte - proven not to move any gate. A reviewer who is handed a document with no figures in it now knows it from line one; on one build that document was audited twice before anyone noticed.

Render the guide and the deck from the finished spine, then gate both. **Always assemble from a fresh copy of the pristine template** - edits compound.

```powershell
# Both artefacts render as two processes - nothing in the render path uses Office COM.
& "$SkillDir\scripts\Invoke-Render.ps1" -BuildDir $out -PackDir $pack -UnitCode $code -Brand $brand -Variant $variant

# Every blocking gate, from one entry point, with every parameter its rules depend on threaded
# and PRINTED. Nine gates fan out as jobs; the leakage sweep is REFUSED without unit_extract.md
# rather than allowed to degrade; the figure registry runs on sources AND on extracts it derives itself.
& "$SkillDir\scripts\Run-Gates.ps1" -BuildDir $out -PackDir $pack -Brand $brand -Variant $variant -Rto $rtoProfile.RtoCode -Cricos $rtoProfile.CricosCode
```

**Pass every one of those parameters, every run.** Each carries a blocking rule, and the rule does not run without it. `-QuestionsInPack` is the two-way cross-reference; `-TemplatePath` is the residual-placeholder vocabulary, harvested from the template rather than listed; `-Plan` with `-NumberSlotByLayout` is the printed slide number, the speaker-notes rule, the chip rule and the 15-slides-per-Topic floor; `-Rto` and `-Cricos` are the document-property identity check, which is invisible on the page and shows in every exported PDF.

**Omitting one now FAILS the gate**, naming the parameter. It used to write a line into the info list - "assessment cross-reference skipped - no `-QuestionsInPack` given" - and return a clean PASS, which is a gate believed because it was green over a rule that never ran. Where an input genuinely cannot be supplied yet, pass **`-AllowPartial`**: each unrunnable rule becomes a loud PARTIAL RUN warning, comes back on `.Partial`, and **must be recorded** - `Add-StageRecord -Partial $gr.Partial -Note '<why>'`. The ledger rejects a partial record with no note, and the build report has to carry it. An omission is then a decision somebody signed, not an absence nobody saw.

**Both gates block.** The deck gate additionally runs a package check that catches malformed XML *before* a file exists - PowerPoint reports a broken package only as "corrupted and unreadable", naming neither the part nor the tag.

**`-QuestionsInPack` reconciles the cross-references, both directions**, and fails on either: every question in the pack is prepared somewhere, and every question the guide or deck cites exists in the pack. A cited question the pack does not contain is an invented reference - a learner revises for a question that is not on the paper.

**Then the figure gate, and it blocks. The gate runner derives its own extracts:**

```powershell
& "$SkillDir\scripts\Test-FigureConsistency.ps1" -BuildDir $out          # declared content sources
& "$SkillDir\scripts\Get-DocText.ps1" -Path $guide -OutPath "$out\guide.txt"
& "$SkillDir\scripts\Get-DocText.ps1" -Path $deck  -OutPath "$out\deck.txt"
& "$SkillDir\scripts\Test-FigureConsistency.ps1" -BuildDir $out -DocText "$out\guide.txt","$out\deck.txt"   # rendered
```

**The rendered-text arm may never be omitted, and the runner no longer lets it be.** `-DocText` is optional, and the loop over it iterates nothing and exits 0 when it is absent - so a runner that simply left it off printed a clean pass with **no rendered artefact registry-gated at all**. The runner now derives the extracts itself, so the arm cannot be silently dropped.

The registry sweep keeps **variant-aware matching**: a forbidden `20 gastronorm` also fails as `twenty gastronorm`, `20-tray` and `fit inside 20`, because a literal-string sweep is exactly the check that let a leaked benchmark figure survive three remediation rounds in four spellings. Its `assessorOnly` list is the leakage tripwire; its `deckMust` list fails a corrected guide sitting beside an uncorrected deck, which is worse than either alone. Three things change around it: `require` is **per-surface**, not a global OR; it scans only **declared content sources**, so a remediation script may legitimately quote the literal it deletes; and both of those lists are now **derived** at Stage 2 rather than hand-typed, because a hand-typed list is always shorter than the truth.

**`Assert-ChannelDisposition` - extract stamping, blocking.** `Get-DocText` stamps a mandatory provenance header on **every** extract: `FIGURES: n placed drawings, m unresolved artwork prompt blocks`, plus the channel list; where `m > 0` it writes `FIGURE CONTENT NOT PRESENT IN THIS EXTRACT`. Every review stage receives a manifest of which channels are in final form and which are placeholders, and **must return a disposition for each**; a channel marked placeholder is automatically re-queued. **The ledger refuses to count a Stage 5 or 6 record as having read the figures unless `m = 0` or the figure sheet accompanied the extract.** No stage may emit a placeholder without registering the spine path its content will come from, and a content check must exist for that path.

Also at Stage 4: **planned versus rendered element counts, per type per sub-section**. Content that was authored, reviewed and gated and still never reached the page is the failure this catches.

**What the structural gates cannot see.** Widths, numbering, schema order, word floors, cross-references - **none of them reads a sentence and asks whether it is true.** A fabricated temperature is perfectly well-formed XML and passes every structural check. The figure gate catches a *registered* figure gone stale; `Assert-FigureCoverage` catches an *unregistered* one; only Stage 6 catches a figure that was wrong from the start. That is why Stage 6 is not optional.

Detail: `references/gates.md`.

## Stage 4b - Readability (blocking, ledgered)

Runs on the assembled documents, after the house gate. Rule, threshold, round limit and editing target **unchanged**. Use the assessment skill's `Test-Readability` and its readability agent - same 300-character paragraph cap, same real-lists rule, same two-round maximum. The agent edits the **spine**, never the document, and never touches a figure, an assessed term, a count or a threshold.

**Readability GAINS a run; it does not move.** The count-based half now runs a second time, at **3c, on the spine's prose fields**, where prompt text and body prose are separate fields and cannot be confused - which deletes outright the artwork-prompt confound the old gate had to script around by stripping prompt paragraphs from a copy of the rendered file. **The Stage 4b run on the rendered document stays exactly as it was**, and so does the run at 7c: a spine measurement and a rendered measurement make different claims, and a document can fail one and pass the other.

Re-render from a fresh template afterwards and re-run both gates. Rule, evidence and thresholds: `references/gates.md` section 11b.

## Stage 4c - Brand: apply the mark, and PROVE it (NEW numbered stage, blocking, ledgered)

**Consumes:** the resolved palette from Stage 0 and the profile pack's identity strings.
**Produces:** branded artefacts, and a printed, ledgered crossover result.

**The brand swap previously had no stage number, no gate-table entry and no ledger record, so a build that never branded could not fail.** It now has all three.

- **The logo and identity swap keeps its position before artwork**, because the logo setter's one-logo-per-part precondition genuinely requires a fresh render. That is a real dependency, and it is the only reason for the ordering.
- **`Assert-BrandCrossover` - ONE implementation, called from both the guide and the deck path.** Its forbidden token set is **DERIVED from the same resolved role map the swap applies** - every hex the map moves, plus every other brand profile's trading name, legal entity, provider code, CRICOS code, domain and street address, read from the branding file. **Never a hand-typed literal.** The previous sweep hand-listed three of nine palette hexes, omitted the light fill and both borders, printed "no crossover" over 766 live occurrences, and had only ever been run on one of the two artefacts - so its report's claim about both packages was true of one.
- **It prints the count of what it checked and what it found**, asserts which artefacts it ran on, and **the stage cannot pass unless it ran on every artefact the stage produced and every XML part**. It reads the cover and the title slide back to assert they carry the **build** brand - which is how a swap that never ran at all would have been caught.
- **It is trusted only after failing on a planted defect verified to have landed.**
- The only judgement in it is the carve-out list, which is **declared in the branding profile with a reason**, never typed into the gate.

Because artwork is the last writer of fills, the same derived sweep runs again at **7c** and again at **8**.

## Stages 5 and 6 - The review band (personas and clean-room audit, CONCURRENT, both blocking)

**Consumes:** identical inputs, handed to both arms - the frozen extracts with their figure-presence headers, **the figure sheet**, the resolved provenance ledger, the cross-reference index, the pack hazard list and the channel manifest.
**Produces:** two independent finding sets, which meet for the first time at 6b.

**They run concurrently, and concurrency STRENGTHENS the isolation rule rather than weakening it.** Neither reads the other's output - the personas report findings and do not edit, and the clean-room auditor is positively forbidden from seeing anything the build produced. Running them at the same time makes showing the auditor the personas' findings **structurally impossible** rather than merely forbidden. Editing happens only at Stage 7, which merges both sets.

**Stage 5 - flow pass and personas.** The flow pass owns the seams a batched build creates - a term glossed twice, a Topic that opens as though the previous one never happened, a figure numbered for a sub-section that moved. Then the three personas from the assessment skill's `references/personas.md`, **unchanged and never forked**, plus a fourth this skill adds because this skill ships a deck: **the trainer who has to deliver it cold.** The personas report findings; they do not edit. Conflicts resolve as they do upstream: the owner sets the floor, the assessor sets the ceiling, the student owns the form. Assessed terminology is never simplified. **Their input may be sliced, their scope may not:** the student and assessor personas may each read the guide in two halves (Topics 1-4 and 5-7) as two agents, and the trainer-cold persona reads the deck only, so the band's wall clock is the slowest reader rather than the sum - the union of the slices is the whole artefact, every persona text stays unforked, and no check is removed. The flow pass reads the whole guide, because seams are what it is for.

**This stage blocks.** It is not an optional polish pass, and skipping it is not a shortcut - it is the stage that reads the document the way a human will.

**Stage 6 - clean-room compliance audit. The stage this skill exists to survive.** Reviewers with **none of the build context** - the guide, the deck, the assessment pack, `references/audit-checklist.md`, and **their own independent extraction of the unit, already prepared in the background since Stage 0**. Use the prompt in the checklist verbatim. **The audit is split by topic, and the reason is measured, not stylistic:** one reviewer given everything holds about 350K tokens, beyond one context, so the "single reviewer" was always a chain of partial reads - which is why six rounds on one build each found a different defect class. `scripts\New-ReviewPack.ps1` cuts one pack per topic plus the cross-document pack(s): a topic reviewer gets the two learner-facing tools whole, the unit extract, its figure-sheet slice, the allow-list with every written reason, and from the assessor guides ONLY the regions for the tasks its topic prepares, taken from the contract's questionMap and the guides' own Contents headings (on the reference build that cut each topic's assessor material from 348 KB to about 20 KB, and every pack from 200-219K tokens to 121-144K). Cross-document consistency stays mandatory and belongs to the cross-document reviewer, which works from `scripts\Get-ClaimsDigest.ps1` (every numeral-with-unit, locked term, citation, question reference and scenario time, with its location) plus the figure sheet and registry, and splits into a values half and a references half when one pack would exceed the 180K budget. Cross-topic mirroring is the mirror gate's job over the whole spine, not a human's. **`scripts\Merge-AuditFindings.ps1` merges the findings, and it is a script, never an agent** - a summarising merger would be a ninth reviewer with sight of the other eight, which the isolation rule forbids; it reads the expected reviewer set from the pack manifest, refuses a missing `findings.json` by name, unions coverage claims against the unit extract and raises any KE or PE item no topic claims to teach, dedupes on anchor and class keeping the worse risk, and lets the worst verdict win per artefact. `-FullPack` keeps the single-reviewer mode for a unit small enough to fit.

**Hand the reviewers text extracts, not Office files.** `scripts/Get-DocText.ps1` dumps a `.docx` or `.pptx` to plain text in seconds - one block per slide with its speaker notes, and every figure's alt text appended, **because a diagram's labels live in its alt text and a review that skips it has not read the figures**. Every extract carries the Stage 4 figure-presence header, and **where figures are not yet placed the figure sheet goes with it**, so a reviewer reads figure content either way. Reviewers driving Word COM spend their minutes opening documents instead of reading them.

It is **not** the assessment skill's audit, and its checklist is not a copy of that one. An assessment instrument fails by not gathering the required evidence. **A learning resource fails by teaching something that is not true.**

Its centrepiece is the **provenance audit**: every figure, threshold, temperature, duration, count and legal proposition in both documents traced to exactly one authority class -

| | |
|---|---|
| **P** | the assessment pack - upstream, and it wins |
| **U** | the unit on training.gov.au |
| **L** | named legislation, a standard or a code, cited |
| **V** | the scenario venue's own documented procedure, **and said so on the page** |

**A figure that fits none of the four is fabricated**, however reasonable it looks. Plausibility is not provenance.

Then, for every **L** figure, the attribution test - does the source say the number; does it **mandate** it or merely **recommend** it; and does it apply to the thing it is attached to? **A recommendation dressed as a legal requirement is a High-risk defect**, because the learner states it in the assessment and then in the workplace. A genuine requirement written as optional is the same defect inverted. So is a real, citable figure attached to a subject its source does not cover.

**Scope is untouched, and the readers gain evidence rather than losing work.** The mechanical classes are already gone by the time they arrive, and the ledger, the index, the hazard list and the figure sheet mean attention goes to **truth and provenance** instead of to hunting, and instead of re-deriving sixty provenance rows by hand in every round.

**Both arms obey the long-stage output contract**: header and scope written before analysis begins, sections appended as they complete, heartbeat running, restart resuming from what is already on disk.

Detail: `references/personas.md`, `references/audit-checklist.md`.

## Stage 6b - Finding arbitration (NEW, blocking, mechanical)

**Consumes:** both finding sets and the canonical corpus. **Produces:** the work order.

**Nothing previously sat between an audit finding and a work order, and one build failed in both directions on a single value.** One round certified a figure as pack-sourced and raised a remediation on that premise; the next round declared the same figure fabricated. The pack states it - in a recipe card's own field, in two pack documents, and in both clean-room extracts the auditor was handed. **A round was spent on a false finding**, a slide was remediated on a false premise, and the delivered registry was left permanently forbidding a value its own sources carry, which would fail every future build that teaches that content correctly.

So, before any remediation edit:

- **`Assert-FindingProvenance`.** For every finding asserting a figure is fabricated, unsourced or misattributed, grep the normalised value **and** the named source's own text block out of the corpus. **A hit BLOCKS the round until the finding is re-examined against the extract, either way.**
- A verification-table row may be marked source-attributed **only** if it carries a quotable locator, and a post-pass confirms the quoted string occurs in the named source.
- **No new forbid rule may be accepted whose literal occurs in any source document.** A build must never forbid a value its own sources carry.

**The arbiter can never clear a finding** - it can only refuse to let one become a work order unchecked. The resolution is a read of the extract, and it is recorded. It costs one grep, and it would have saved a whole round.

## Stage 7 - Remediate on the spine: enumerate before fixing

**Registry first, prose second.** A round that starts by rewriting sentences fixes the instance in front of the author and misses its siblings - that exact pattern failed three consecutive rounds on one build: round 1 fixed prose and left the diagram specs, round 2 fixed the guide and left the deck, round 3 fixed the literal string and missed its four spelled-out variants. The order that works:

1. **Update `figures.json`** - the corrected value becomes the `require`, every stale form becomes a `forbid`, any newly-discovered assessor-only wording joins `assessorOnly`. Subject to 6b: **never forbid a literal a source carries.**
2. **`Assert-EnumerateBeforeFix`** - produce a **machine-generated hit list per finding, across every content channel of BOTH artefacts, BEFORE the fix.** That enumeration is the work order; a sweep by eye is not.
3. **Fix what it lists**, plus the prose-level findings the registry cannot see. **The fix must clear the whole list.**
4. **The sweep becomes a permanent registry rule** and re-runs every round thereafter.
5. **Re-run the whole 3c band**, then re-render **both** artefacts from fresh templates.
6. **Regenerate the figure sheet** - `New-FigureSheet.ps1` - because step 1 to 3 edited the spine it was cut from, and it is what every later reviewer reads figure content from. Stage 8 blocks on a sheet whose stamped spine fingerprint no longer matches.
7. **Re-check every placed or pending image against the corrected content.** A slot whose figure content or prompt changed in this round has an image that was reviewed against superseded content: re-run the image review for that slot, regenerate it where the prompt hash moved, and record it under `7b-i`.

**A finding with no enumerating sweep cannot be marked closed. A finding closed by deferral to a later stage must register a blocking gate at that stage, and delivery fails if that gate never ran.** Both patterns cost a full round each on one build and nothing gated either: a correction landed in the front matter and the assessment overview and missed all eight rows of the cross-reference table and the deck's closing note; and a class fixed in prose was never extended to the figure channel for three and a half hours.

**A round is: registry, arbitrate, enumerate, remediate, re-gate, re-reconcile, re-read, re-audit.** Re-run `Test-GuideRules`, `Test-DeckRules`, `Test-Readability`, `Test-FigureConsistency` (sources *and* rendered text), the **whole 3c band**, **the Stage 5 personas and flow pass**, and the Stage 6 clean-room audit, each on fresh agents. **Both judgement arms re-run, not just the audit** - a re-render assembles both artefacts from a fresh template, so a persona verdict taken before it describes a document that no longer exists exactly as an audit verdict does, and Stage 8 rejects a Stage 5 record older than the newest render. Record each one as it finishes. A remediation that is never re-audited leaves the resource carrying an out-of-date verdict - which is how a pack ships on a stale "Partially Compliant", and the same trap is set here.

Maximum three rounds; anything unresolved is an open finding, not quietly passed.

**Both artefacts are re-rendered even when only one had a finding.** They come from one spine, so a spine edit changes both, and re-rendering one leaves the other stale. **A corrected figure is the worst case** - it typically appears in guide prose, a summary diagram and at least one slide; the registry-then-enumerate order above exists because fixing the prose alone leaves two stale copies contradicting it, and it did, twice.

**Remediation is where leakage sneaks in.** The audit report quotes assessor benchmarks as evidence; an author fixing a finding from that report is one careless paste away from writing the benchmark into the learner document - it happened with an equipment capacity figure lifted straight from a Task model answer. Fix from the *pack facts and the registry*, never from the audit's quotation of a benchmark, and let `assessorOnly` and `Assert-AssessorLeakage` catch the slip.

## Stage 7b-i - Generate the artwork and review it (BACKGROUND, launched at the end of 3b, ledgered, blocking)

**It runs in the background, and it is still a stage with an owner and a record.** Launched the moment the prompt lint passes and the user approves the cost, keyed by **figure slot and prompt hash**.

**Whoever launches the arm owns it, and the arm is not finished until it is recorded.** Under the serial ordering the image review was an inline step of placement, so it necessarily ran; moving generation into the background took the review with it, and a background arm with no gate row, no ledger record and no heartbeat is an arm that can simply not happen while every structural gate still passes. So:

- **It has a ledger record**, `7b-i`, and it is blocking. `Add-StageRecord -Stage '7b-i' -Name 'Generate + image review' -Status pass -Findings n`. Where nothing was generated - no API key, or the user declined the spend - it is recorded `n-a` **with a note**, which the ledger requires.
- **It obeys the long-stage output contract** like every other long-running stage: the review file is created with its header and scope before the first image is looked at, each slot is appended as it is judged, a heartbeat runs, and a restart resumes from what is on disk.
- **Placement may only use a slot with a passing review record.** An unreviewed image is not placed.

Three reasons pin artwork late, and every one of them is a reason to pin **placement** late: a Stage 7 re-render assembles from a fresh template and would throw placed images away, neither structural gate knows what a prompt block is and both read one as over-long body prose, and the delivery sweep that fails an unresolved bracketed placeholder must stay downstream. **None of the three applies to writing a PNG into a folder.** So generation and the image review run in the background while the 3c band, the render and the review band proceed, and only placement stays in sequence. One build invented this decoupling by hand under pressure: a script written mid-build exists purely to carry passed images across a manifest rebuild, keyed by figure slot.

**The image review runs in the background arm with its scope wholly untouched.** Look at every generated image before it is placed: no lettering, no faces, no logos, nothing contradicting the document. **Bare hands on ready-to-eat food is a food-safety defect on the page, not a styling quibble.**

**"Nothing contradicting the document" is a claim about the FINAL document, so it is judged twice.** In the background arm the image is judged against the content as it stands at generation time - which is the earliest it can be judged, and worth having. But remediation happens after it: an image reviewed at hour two against a figure Stage 7 then corrected is an image nobody has checked against what the page now says, and under the old serial ordering that could not happen because the review sat after remediation. So the second judgement is not optional:

- **Stage 7 step 7** re-reviews every slot whose figure content or prompt changed in the round, and regenerates where the prompt hash moved.
- **Stage 7d re-checks every placed image against the final content**, as part of the confirming read, against the regenerated figure sheet. A slot that fails there is regenerated and the round is not closed until it passes.

## Stage 7b-ii - Place the artwork (position unchanged: after Stage 7's re-render, before delivery)

**Consumes:** the reviewed images, the spine's `kind` per slot, and the **resolved brand palette**.
**Produces:** the placed artefacts.

Invoke the **`docx-images`** sub-skill and follow its own procedure, with one difference from its stand-alone flow: the manifest was seeded from the spine at 3b by `New-ManifestFromSpine.ps1` and the images were generated in the background, so placement does not scan for prompts to generate - it re-reads the rendered document only to locate each slot's paragraph span, joins by slot, and places what is already reviewed. Nothing is regenerated unless the slot's prompt hash moved during remediation.

- **Only slots whose prompt hash changed during remediation are regenerated.** Everything else was generated hours ago and reviewed in the background - and **only a slot carrying a passing `7b-i` review record is placed at all.**
- **`kind` is seeded from the spine BY SLOT**, never re-detected by keyword from a prompt the build itself wrote. Keyword re-detection turned four photographs into diagrams on one build. A prompt describing a labelled bar, a flowchart, a cycle or a scale is a diagram - and the spine already says so.
- **The resolved palette is passed INTO the sub-skill**, so native diagrams are built in the correct brand **the first time**. This is the whole point of `Assert-DownstreamPalette` at Stage 0: without it a shared config hard-coded to another brand repaints the document after branding was declared clean, and an entire post-placement repaint round exists for a config value knowable at minute one. Injecting the palette also leaves that shared config untouched for other RTOs.
- **Generate once, and reuse for the deck.** Point `Set-SlidePicture` at the PNG already produced for the corresponding guide figure. A deck figure and its guide figure showing different pictures of the same thing is worse than either alone.

**No API key, or the user declines?** Deliver with the prompts in place and say plainly that the figure spaces carry prompts rather than pictures. **Never delete a prompt to silence the sweep** - an empty space that once held a prompt cannot be recovered.

Detail: `references/visuals.md` section 9.

## Stage 7c - Post-placement FULL re-gate (NEW, blocking)

**Standing rule: any stage that changes what is on the page is followed by the WHOLE gate set, never a subset.**

Placement is the last mutation of both artefacts, and on one build it was followed by **exactly one of five gates** - so the registry's variant-aware sweep never once ran against a document that actually contained figure rows. It is now followed by all of them, on **freshly regenerated extracts of both artefacts**:

- `Test-GuideRules` with `-AfterArtwork`, **and every parameter it was given at Stage 4** - it then fails on any prompt block that survived, rather than reporting them as work pending
- `Test-DeckRules`, same parameters
- `Test-Readability`
- `Test-FigureConsistency`, declared sources **and** rendered text
- `scripts\Check-FigureMirror.ps1` and `scripts\Check-FigureLeakage.ps1`, **against the placed document**
- `scripts\Test-GridDisposition.ps1`, `scripts\Check-ShapeMirror.ps1` and `scripts\Check-RowCoverage.ps1 -Whole` - the same three that block at 3c, re-run here because placement is a mutation. The disposition gate reads the mirror's table channel from `figure-mirror-report.json`, which the mirror writes on every run, so a 7c disposition verdict is cut from the placed document's own evidence rather than from a stale spine report.
- `Assert-WithholdRegister`, `Assert-AssessorLeakage`, `Assert-FigureCoverage`, `Assert-Provenance` - **check which of these exist before claiming this line**; `references/gates.md` marks each honestly, and a stage that lists a gate nobody ran is the false green this pipeline was rebuilt against.
- **`scripts\Check-Figures.ps1 -Path <guide> <deck> -BuildDir $out`** - the placement arm, and the only check on **alt text in the placed drawings**: every drawing carries non-empty alt text, figure numbers run 1..N inside each sub-section with no gap, no prompt text survived in the body or in any header or footer, and **caption-to-slot reconciliation** against the spine - every planned slot has exactly one caption, matched on the caption paragraph rather than any text run so an in-prose cross-reference cannot count as one, counted **per number with no de-duplication before comparison**. The check it replaces advertised a duplicate-caption failure, de-duplicated its own list before comparing so that failure was unreachable, and was wired to no caller at all.
- **`scripts\Check-Identity.ps1 -Path <guide> <deck> -Brand $brand`** - `Assert-BrandCrossover`, derived set, on the finished files, both artefacts in one call so the stage cannot pass having run on one.

## Stage 7d - Confirming audit read (NEW, blocking, judgement, scoped)

**Delivery requires at least one Stage 6 record that POSTDATES the newest placement.** No build ships on a verdict issued against a document that had no figures in it - which is exactly what the old ordering guaranteed, and on one build a verdict issued before placement still counted as current after it.

**It is scoped to what placement changed** - the placed figures, their captions and their alt text, read against the **regenerated** figure sheet already adjudicated at 3d - so the guarantee costs a short read rather than a fourth full round. It obeys the long-stage output contract like every other judgement stage.

**It carries a verdict, and that verdict is the Stage 6-class read Stage 8 requires after placement.** `Add-StageRecord -Stage '7d' -Name 'Confirming audit read' -Status pass -Verdict '<judgement>'`. A confirming read that confirms nothing in particular is not a confirmation, and the ledger rejects a 7d record with no verdict exactly as it rejects a Stage 6 record with none.

**It is also where every placed image is re-checked against the final content** - no lettering, no faces, no logos, and **nothing contradicting what the page now says.** The background review at 7b-i judged each image against the content as it stood at generation time, hours before remediation; this is the read that judges it against the document being delivered. A slot that fails here is regenerated, re-reviewed and re-placed, and the round is not closed until it passes.

## Stage 8 - Deliver (blocking, hardened)

Runs once, after the final re-render, the full post-placement re-gate and the confirming read. `scripts\Finish-Documents.ps1` does the Contents rebuild and both PDF exports first - Word and PowerPoint each in their own job under one deadline, TablesOfContents updated and never a whole-document Fields.Update, and the verdict taken from the FILESYSTEM (PDF newer than its source, header, %%EOF, page-tree count equal to what the application measured) rather than from the COM exception, because on the reference machine Word completes the export and then dies at teardown, and believing the exception discarded a correct 383-page PDF twice.

- **`Assert-Staleness` first, and it is proven from FILES and hashes, not from clock order in a ledger** - because on one build the ledger was the thing that lied. **Delivery fails if any delivered artefact is older than the newest spine file, registry file or render input.** That build shipped a guide 50 minutes older than the spine it renders, beside a report claiming its counts were taken from the delivered files after the last remediation round.
- **`Assert-LedgerIntegrity`.** **Two records in different stages sharing a timestamp to the second is rejected** as the mechanical signature of retroactive batch-writing - one build flushed seventeen records in eight writes, with three sharing each of three timestamps, and had no Stage 8 record at all. Record **sub-second** start **and** end so genuinely adjacent stages stay distinguishable; the carve-out for stages that really do complete within one second of each other is declared, not assumed.
- **`Test-StageLedger`.** Nothing else in this pipeline can see a skipped judgement stage - every structural gate passes just as happily without one. It fails delivery when:
  - **a required stage has no record.** The required set is `$script:LedgerRequired` in `Stage-Ledger.ps1`, and it now includes every blocking stage the rewrite added - `3c`, `3d`, `4c`, `6b`, `7b-i`, `7c`, `7d`. Read the list from the script, never from a copy of it.
  - **a blocking stage is recorded `skipped`**, or recorded `n-a` **with no note**, or carries **partial gate rules with no note**. An honest status still costs a written reason.
  - **a render made a judgement stale - by TOPIC, from content hashes, not by timestamp.** A re-render (stages `4` and `7`) assembles both artefacts from a fresh template. `scripts\Assert-RenderDelta.ps1` hashes each topic's slice of the guide extract, its deck slides and its figure-sheet slice and writes `render-delta.json`; a `4b`, `5` or `6` record that carries `-Topics` and `-DeltaSha` is stale only for the topics whose hashes moved since that delta, and the ledger prints the stale set by topic ("stale for topics 1, 2, 3, 5, 7; current for 4, 6"). A record with neither field keeps the whole-artefact timestamp rule. On one build the timestamp rule made a one-word fix in Topic 3 invalidate every reader for all seven topics, so the personas were never re-run after round 1 - an unsatisfiable rule is a waived rule. The hash also catches what a file list misses: between rounds 5 and 6 the touch list named five topics and the delta found six, because one sentence in 4.3 had been rewritten.
  - **a placement made a check stale.** Placement (`7b`) and the re-gate that follows it (`7c`) change the page without changing the prose, so what must postdate them is `7c` - the whole gate set, readability included - and `7d`. **Stage 5 is deliberately not held to placement**: nothing re-runs the personas after it, and a rule no build could ever satisfy is how a check ends up waived by whoever is holding the delivery. What placement changes is figure content, and that is read at 3d, again by the review band through the figure sheet, and again at 7d against the placed page.
  - **no Stage 6-class verdict postdates the newest placement** - a full Stage 6 re-audit, or the Stage 7d confirming read. No build ships on a verdict issued against a document that had no figures in it.
  - **Stage 6 or Stage 7d recorded no verdict**, or one reading `Not Compliant`.
  - **the figure sheet no longer describes this spine.** It is stamped with the fingerprint of the spine it was cut from; the check recomputes it. A stale sheet means every reviewer downstream of it read figure content the document no longer carries, while the ledger recorded that the figures were read.
- **Each stage record must enumerate which mandated sweeps actually ran**, and a substituted script must record what it does **not** cover.
- **No report may state measured counts unless it postdates the final gate run and every artefact it describes.**
- `Assert-BrandCrossover` once more, on the delivered files: `scripts\Check-Identity.ps1 -Path <guide> <deck> -Brand $brand`, both artefacts in one call.
- `Invoke-DocumentVerification` on the guide - updates fields, saves, exports the PDF in one Word session. **`Update-Fields` is what populates the Contents**; skip it and the guide ships showing the field placeholder.
- Export the deck to PDF through PowerPoint, and open each file once by hand to confirm neither prompts to repair.
- `Test-PageFlow` on the guide - no blank pages, no thin pages.
- Confirm the deck's printed slide numbers match their deck positions. They are **literal text, not fields**; the reference deck prints the wrong number on 19 of its 39 slides.

Deliver `.docx`/`.pptx` **and their PDFs together**, regenerated in the same pass. A PDF older than the file beside it is a delivery defect, and the staleness check above is what now says so mechanically.

---

## Report, every build

- Word count per Topic against the 3,000 floor, and per Underpinning knowledge block against the 800 floor
- **Slides per Topic against the 15 floor**, listed, with the reason for any shortfall
- The question cross-reference, reconciled both ways, with any gap named
- Content width, and confirmation every full-width table equals it
- Distinct `numId` count, and that every list restarts at 1
- **Visuals: planned, generated, built natively, and what each cost** - plus zero unresolved prompt blocks
- Speaker notes present on every teaching, case-study and assessment-link slide
- The unit's release and currency, with the date checked
- **The Stage 6 compliance verdict, its date, and which remediation round it was issued against.** A verdict from before the last re-render is stale and must be re-issued, not carried forward - **and at least one Stage 6 record must postdate the newest placement**, which is what Stage 7d exists to satisfy
- **The provenance ledger** - every figure, its authority class, its source locator, and whether it is mandatory or a recommendation. Verified rows are part of the output, not just defects
- **The pack hazard list from Stage 1, and the written disposition of each** - an inherited upstream defect that nobody decided about is a defect this build adopted
- **Every allow-list entry that cleared a gate, with its written reason** - mirror and leakage clearances from 3d, prompt-lint clearances, brand carve-outs, and the RTO profile's no-notes exemptions. An allow-list is evidence for the audit, not a private setting
- **Every gate rule that did not run, and why** - every `.Partial` entry any gate returned, with the note recorded against it in the ledger. A gate that checked nothing is not a pass, and this is where a build says so out loud
- **The figure sheet's spine fingerprint against the delivered spine**, so a reader can see the sheet every reviewer read still describes the document that shipped
- **The `Assert-BrandCrossover` result on every delivered artefact: what it checked, how many tokens were in the derived set, and what it found.** A sweep that does not print its counts cannot be told apart from one that checked nothing
- **Every arbitrated finding from 6b, and how it resolved** - including any finding that did not survive arbitration, because a round spent on a false finding is a cost worth recording
- **Which mandated sweeps ran at each stage**, and for any substituted script, what it does not cover
- **The staleness proof** - the newest spine, registry and render-input timestamps against each delivered file
- **Which personas ran, and which findings each raised** - a stage recorded as run with no findings is a result; a stage silently skipped is a defect in the build, and saying so is this report's job
- **Every divergence between the spec, the template and the RTO's delivered guide, with which one was followed and why**
- **Every open question, stated as a question**

**No count in this report may be stated unless the report postdates the final gate run and every artefact it describes.** One build shipped a report asserting counts "taken from the delivered files after the last remediation round" that was written before the files it described were last written.

### Standing divergences

Three, all real, all found by measuring the RTO's own artefacts. `references/gates.md` carries the evidence and the decision for each.

1. **Content width.** The template shipped margins giving CW 9026 while the spec and every table in the delivered guide use 9617. Resolved by patching the template's right margin to 849. **The delivered SITHPAT018 guide overhangs its right margin by 591 DXA on all 361 of its tables.**
2. **Callout palette and icons.** The v3.4 template uses the ACI callout hexes and the twelve-icon set; the delivered guide uses the MVC palette and no icons at all. Resolved in favour of the template, which is the approved brand source - but it is a visible change from the last guide the RTO shipped, and it needs the crossover carve-out in `references/gates.md`.
3. **Underpinning knowledge depth.** The spec sets an 800-word floor per PC sub-section. The delivered guide's blocks measure 96-242 words. Resolved in favour of the spec; expect this to be the expensive part of the build.
