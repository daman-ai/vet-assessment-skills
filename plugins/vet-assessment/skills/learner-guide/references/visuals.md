# Visuals — placement, prompts and artwork

Distilled from **MVC Learner Guide Visual Placement Report — Master Prompt v3.1** (30 July 2026), which is the RTO's own standard for where visuals go in a learner guide and how they are briefed.

The guide is built with **prompts on the page, not pictures**. Stage 7b-ii hands it to the `docx-images` sub-skill, which turns each prompt into artwork, places it at the same spot with its caption and alt text, and deletes the prompt. What ships carries no prompt text anywhere.

**A figure's content is not the picture. It is the spec on the spine** - the rows, nodes, items, caption, alt text and prompt authored at Stage 3b. That content is complete and machine-readable hours before any picture exists, so it is gated at Stage 3c and adjudicated by a reader at Stage 3d, both on the spine, and it travels into every later review as the **figure sheet**. Nothing about reading a figure waits for placement. Section 9 records what it cost when it did.

---

## 1. Coverage

**One PC sub-section is one unit of coverage, and each gets four visuals.**

| Slot | Visual | Route | Placement |
|---|---|---|---|
| `X.1` | Topic image | A — generate | Straight after the sub-section heading, before the first body paragraph |
| `X.2` | Process diagram — flowchart, decision tree or process map | B — build natively | Inside the procedural content, immediately after the step list it renders |
| `X.3` | Workplace image | A — generate | Beside the case study or the worked example |
| `X.4` | Summary table or infographic | B — build natively | At the close of the sub-section, before the assessment link |

**Plus `Figure 0.1` — one cover image per guide**, additional to that count and briefed to a different standard (§4).

**The per-sub-section count governs.** Do not also apply a per-topic count, and do not target a visuals-per-page figure. Four per sub-section already lands at roughly one visual every one to two pages. Adjust only where the guide is not structured by PC sub-section — and say what you did and why.

**Numbering** is `topic.subsection.slot`: `1.1.3` is the workplace image in sub-section 1.1. The cover is `0.1`.

### Generate at the size and quality the page needs

**Never generate at maximum quality and then shrink.** Quality is billed per image, and an illustration lands at 85% of the column, capped at 10 cm tall — about 14.4 × 9.6 cm — where `1536x1024` is already ~270 dpi. `docx-images` defaults to `medium` quality and `jpeg` at compression 82 for exactly this reason: at document size it is indistinguishable from `high`, and it is roughly a tenth of the bytes.

The difference is not marginal. The same figure came back at **2,300 KB as a high-quality PNG and 129 KB as a medium JPEG**, and a set of 22 was the difference between a 52 MB Word file and a 4.6 MB one — a file the RTO has to store and email, and learners have to download.

Raise it for the **one figure** that needs fine detail with a `QUALITY: high` line in that prompt block, and say why. Never globally.

If images already exist at the wrong setting, **compress them locally — do not regenerate.** Re-billing to fix file size is the opposite of the point.

### Count the cost before you generate

Only Route A costs money. Work it out and **tell the user before generating**:

```
Route A (paid)  = (sub-sections x 2) + 1 cover
Route B (free)  =  sub-sections x 2
```

For SITHPAT018 — 8 topics, **31 PC sub-sections** — that is **125 visuals: 63 generated and 62 built natively.** `docx-images` says to ask before about ten, so a guide of this size is a conversation, not an assumption. Offer the obvious reductions: cover plus `X.1` only, or the highest-priority sub-sections first, with the rest left as prompts for a later run.

For reference, the delivered `SITHPAT018-Learner Resource.docx` contains **three media files — the logo and two template JPEGs — and no instructional figures at all.** This standard has never been applied to a shipped MVC guide.

---

## 2. The two routes

They are not interchangeable, and they map one-to-one onto `docx-images`' own split.

| | **Route A — Generate** | **Route B — Build natively** |
|---|---|---|
| For | Photographic and illustrative visuals | Diagrams, decision trees, charts, tables, infographics |
| Emitted as | `GImagePrompt -Kind Image` -> `[IMAGE: ...]` | `GImagePrompt -Kind Diagram` -> `[DIAGRAM: ...]` |
| `docx-images` calls it | `illustration` | `diagram` |
| Made by | the OpenAI image model | **native Word shapes or a real Word table** |
| Rasterised? | Yes, a PNG | **Never** |
| Cost | per image | nothing |

**Never image-generate a diagram.** A generated diagram carries labels nobody can correct and spelling nobody can trust, and in an audited document that survives to the auditor. Built natively, every box is clickable, every label is live text, and a screen reader reads it.

**Keep tables as native Word tables**, never as images, so they stay editable, searchable and accessible. Set header rows to repeat.

---

## 3. Writing a Route A prompt

**One paragraph, 90–160 words, plain descriptive prose.** No field labels, no bullets, no numbering, and **no reference to the guide or to this skill** — it must work pasted cold into a generator.

It must independently contain: the subject and action in present tense; the setting; the people with role, approximate age, dress and PPE, posture and gaze; the equipment and props; composition and camera — shot type, height, lens character, depth of field, and any space to leave clear for annotation; lighting source, direction and quality; colour direction; style; and jurisdictional cues.

- **Name colours in plain language** — wine-red, olive-green, sandstone, brushed brass. **Never put hex codes in a generation prompt**; generators ignore them. Hex belongs in the theme table and the Route B build specs.
- **Faces angled away**, turned from camera, or softly out of focus.
- **Never ask for text inside the image.** Generators render lettering unreliably. Every label, callout, arrow and caption is added afterwards in Word or PowerPoint.
- **End with an exclusion clause.** At minimum: no text, no numbers, no signage lettering, no logos. Add the failure modes specific to that image — wrong PPE, non-Australian signage or plugs, left-hand-drive vehicles, unsafe practice, distorted hands, cluttered backgrounds, stock-photo eye contact with camera.

`GImagePrompt` emits the block in the shape `docx-images` detects, with `CAPTION`, `ALT` and `ASPECT` on their own lines — **outside** the prompt body, so the caption's figure number never reaches the generator.

**Prefer hands-and-equipment framing over a person as the grammatical subject**, unless the RTO profile's house rules say otherwise for that subject class. `Assert-PromptLint` - **being implemented**: a sibling build is writing `scripts\Assert-PromptLint.ps1` and it is not on disk yet, so until it lands the 3b agent reads its own prompts against the profile's framing rules, because the 7b-i image review is the only other net and it runs after the spend - checks this at the Stage 3b exit, before a cent is spent: it fails a prompt whose subject phrase heads on a person noun where the house rule requires hands and equipment, and fails any prompt missing a required negative constraint for its subject class. Where a person genuinely is the subject, record the slot and a written reason in the allow-list in `figures.json`.

This is a string check over `visuals[].prompt` costing seconds, and it exists because one build regenerated **47 of 57 illustrations on identifiable faces, then 17 again, then 2 again** - 48 minutes of billed regeneration inside a 1h44m artwork block. The repair script that eventually fixed it read prompts, never images: it rewrote the subject from a person to hands and equipment. It was a text operation all along, and it was knowable before the first image was generated. **The image review is not weakened by this and keeps its full authority** - it caught two genuine food-safety defects. The lint removes the volume the reviewer must wade through, not the reviewer's scope.

## Writing a Route B spec

A short bulleted list, then caption and alt text:

- Diagram type and orientation.
- **Every node, box, step, row and column with its exact final wording.** Write the words that will appear, not a description of them.
- Sequence, branching and decision logic — each decision question with its Yes and No paths, entry point, exit points and any loop-backs.
- One line assigning palette and type: fills, text colours, connectors, header bands, row tints, font sizes. Where a colour fails contrast as text, name the substitute here.

**Declare `kind` explicitly on the spine, per slot.** Never let the manifest re-detect a route by keyword from a prompt the build itself wrote - four photographs were re-detected as diagrams that way. **And check the spec is buildable before it is built**: node count against the renderer's box cap, projected height against the column height from the document profile, and branch or decision semantics against what the target renderer can actually draw, naming the table fallback where it cannot. All three are arithmetic on the spec (`Assert-SpecRenderable`, Stage 3c - specified, not yet implemented; see gates.md section 22. Until it exists the 3d reader counts nodes against the renderer's cap by hand, because otherwise `docx-images` finds the over-length flow at placement). One build found nineteen over-length flows only at placement - a nine-node flow lands at 21.6 cm and an eleven-node at 26.5 cm, which cannot fit a page - after four stages and a full audit round had passed over them, and a decision figure was silently flattened to a straight line so one branch disappeared and the figure taught "you always report a mismatch".

---

## The spec is content, so gate it where it is written

A Route A prompt and a Route B spec are **authored content**, in the same sense as body prose. A spec carries row labels, node wording and captions a learner will read on the page. So it is checked at the stage it is authored, against the spine, and never deferred to the stage the picture appears.

- **Every check whose only inputs are the spec, the spine and the corpus runs at Stage 3c** - mirror, leakage, grid disposition, withholding, provenance, figure coverage, spec renderability, caption and alt consistency. None of them opens a `.docx`. The gate written to catch the worst figure defect this skill has ever shipped reads the spine directory and never opens a document at all; there was never a dependency on placement, only a habit of reading documents.
- **The gates report the anchor and do not decide.** A reader adjudicates at **Stage 3d**, on the spine, and clears a hit only by recording a written reason in the allow-list held in `figures.json` beside the registry rule it weakens - never as a default buried in a script parameter, where nobody reviewing the build will ever see it.
- **Stage 3d emits the figure sheet**: every visual entry on the spine dumped as plain text, one block per slot, carrying rows, nodes, items, caption, alt text, and the slide body and speaker note that reuse it. It travels with every later review pack, so a reviewer reads figure content whether or not a picture exists yet.
- **"The pictures are not in yet" is never a reason a figure has not been reviewed.** If the artwork is not placed, the spec is still readable, and reading it is the review.

## A figure must never answer the assessment

The assessment is normally **open book and expressly permits the Learner Guide**. Whatever a figure prints, a learner may copy straight into an assessed answer. That makes figure content an assessment-integrity surface, not a styling one.

**The rule.** No figure, diagram, summary table, slide body, chip, caption, alt text or speaker note may reproduce an assessed response table with the assessed columns filled in. Carrying the task's column headings verbatim is the same defect in a thinner disguise. Matching is structural, on normalised row labels rather than wording, so handing the grid over in your own words fails exactly as hard as copying it.

**Coverage and leakage are one verdict, not two.** Every assessed row must be TAUGHT in the prose, and no visual may present those rows as a completed grid. `Assert-GridDisposition` (specified, not yet implemented - gates.md section 15; today only the leakage half runs, through `scripts\Check-FigureMirror.ps1`, and the coverage half is a reader's job) returns a single verdict over both, because gated separately, fixing one manufactures the other - and that is not hypothetical. One build was correctly told at its first audit that sixteen assessed cells were being taught as four paragraphs; the remediation taught every row by filling the grid in a figure and putting all six rows on a slide; and the last audit round found those two remediations as the worst leaks in the build and returned Not Compliant. A full round was spent on a defect the first remediation created.

**The one-worked-exemplar allowance.** A single row may be worked end to end where the figure teaches the METHOD rather than the answer set. It must be labelled as the worked example, and every other row stays as the tool's own unfilled token - "Write here", "Your turn", blank, dashes.

- **Where the task leaves a row unassessed, put the exemplar on that row.** It is the free one: it demonstrates the method and gives nothing away. Reach for an assessed row only when the task assesses every row, and then use exactly one.
- Brevity is not absence. A row holding a temperature, a time or a yes/no is FILLED. Any test that treats a short cell as empty waves through the leaks that matter most, because an assessed answer is very often a single value. Decide filled-versus-empty against an explicit unfilled vocabulary, never against a character count.

**Every mirroring visual carries an explicit disposition on the spine** - `withheld`, or `cleared, reason: ...`. Consistency then follows from the register rather than from an author remembering: one build applied withholding at three figures and not at five others, in the same document.

**Withholding is a build-wide fact, not a per-document one.** A value the guide withholds must not be filled in by the deck, and the reverse. In one build a deck slide filled a row the guide's own figure had withheld as "Your turn", defeating the guide's withholding decision from the other artefact; the same build told learners it "deliberately does not do them for you" and printed one of the answers two paragraphs earlier. So the sweep runs over every channel of **both** artefacts, and one artefact filling what the other withholds is a failure in itself.

---

## 4. The cover image — Figure 0.1

Briefed to a different standard, because it is the first visual the learner sees and it sets the theme.

- **The business as a whole**, not a task from one sub-section. A wide establishing view of its most recognisable setting.
- Must not duplicate the composition, setting or subject of any interior figure.
- **Name the quiet band for the title block** in the prompt itself — normally the upper third — so the unit code, title, qualification and logo overlay without competing.
- **State the aspect ratio**: 2:3 portrait for a full-bleed A4 cover, or 3:2 landscape for a banner cover. Say which and why.
- People are optional and often better left out. If present, roles the scenario names, correct dress and PPE, faces angled away.
- The derived primary and background tones must be visibly present.
- **No text, no signage lettering, no menu boards, no logos.** The title block is added afterwards in Word.
- **If the title sits on the image**, state the tint overlay — normally the derived neutral at 45–60% — and give the measured contrast ratio for white title text against it.
- Alt text yes; a cover takes no caption.
- **If the guide already has a cover image**, check it against the Scenario Profile and either keep it with a reason or recommend replacing it. Never silently leave an off-scenario cover in place.

---

## 5. The visual theme is the scenario's, not MVC's

**This is the rule most likely to be got wrong.** Derive one visual theme from the simulated business and use it for every visual. Every colour must be justified by something real in that business — its name, products, materials, trade conventions, site conditions, uniform, signage or premises. Colours are not chosen decoratively.

> **MVC identity appears as document attribution in the footer only. The college brand palette is never the visual palette.**

Run an accessibility check and report it: the measured contrast ratio for every pairing, against white and against the background tone. Anything below **4.5:1 as text** is restricted to fills and rules, and you must name the compliant darker shade for where that colour has to carry text.

**Expect a clash and say so.** The guide's own box furniture, headings and table headers run on the MVC brand palette. Scenario-themed visuals will sit against MVC navy and orange callouts. Note it in the report; do not silently re-skin the furniture.

## Brand ordering: anything that draws after a brand swap must be re-branded

The brand swap runs **before** artwork, and that ordering is correct and stays - `Set-BrandLogo` has a one-logo-per-part precondition that genuinely needs a fresh render. But it has a consequence that must be handled explicitly:

> **Any stage that generates or builds visual objects after a brand swap must re-apply or verify the brand afterwards. Sub-skills carry their own palettes and will happily use them.**

This exists because one build swapped the brand, reported it clean, and then handed the document to the artwork sub-skill, which built 56 native diagram tables from a palette hard-coded to a different RTO. The guide went from zero crossover hits to 177 foreign header rows and 608 foreign light fills **after** branding had been declared clean, and an entire post-placement repaint round was spent on a configuration value that was knowable at minute one.

Two rules, and both are needed:

1. **Pass the resolved palette INTO the sub-skill at placement**, so native diagrams are built in the correct brand the first time and the shared sub-skill config stays untouched for every other RTO using it. A sub-skill that emits styled output must accept an injected palette and must **throw** when a caller that declared a brand supplies none - a silent default is how the wrong brand gets drawn without anything erroring. Pre-flight (`Assert-DownstreamPalette` - specified, not yet implemented, gates.md 29.3; until it exists, pass the palette by hand and rely on the 7c crossover sweep to catch a repaint after the fact) reads each such config and fails the build if there is no injection path; where a repaint is genuinely unavoidable, it registers that repaint as a required stage whose absence fails delivery.
2. **Re-run the brand crossover sweep on the finished files after placement** (Stage 7c) and again at delivery, on **every** artefact and every XML part, with the forbidden set **derived** from the same resolved role map the swap applied - never a hand-typed list of hexes. One build's sweep hand-listed three of nine palette hexes, omitted the light fill and both borders, ran on only one of the two artefacts, and printed "no crossover" over 766 surviving foreign fills. Print the counts of what was checked and what was found, so a green result is evidence rather than an assertion.

---

## 6. Realism rules

Every visual must be something that could actually be photographed or produced inside the scenario business. Any candidate that cannot satisfy all of these is replaced with one that can.

Setting, role, equipment, task and document fidelity — only spaces the business has, roles it names, plant consistent with its industry and scale, work it genuinely performs in correct sequence, and forms it actually uses. **Jurisdictional fidelity** — Australian and state-specific practice: correct regulator names, AS/NZS-compliant PPE and signage, metric units, right-hand-drive vehicles, DD/MM/YYYY dates, AUD. **Scale fidelity** — crew sizes, volumes and dollar figures matching the guide's own numbers. **Currency** — contemporary equipment, uniforms and software. **Diversity natural to the workplace**, without stereotyping roles. **No identifiable people, real brands, logos or trademarks.** **Safety accuracy** — everyone complies with the scenario's WHS requirements, unless non-compliance is the single clearly annotated teaching point.

---

## 7. Quality rules

- **Every visual supports a stated learning outcome and either Knowledge Evidence or Performance Evidence.** Recommend no decorative visuals.
- Every visual gets a figure number, title, exact placement, mapping, route, priority, caption and alt text.
- Keep overlaid labels short and in plain English, so the visual reinforces the surrounding text through image-to-term association for EAL and LLN learners rather than adding reading load.
- Avoid generic stock photography and stock staging, decorative graphics, off-scenario settings, idealised depictions of work, embedded generated text, and real brands or identifiable individuals.

---

## 8. The deck

The deck's `image` layout takes a real picture through `Set-SlidePicture`.

**Reuse the guide's artwork.** Point it at the PNG `docx-images` already produced for the corresponding guide figure. Never generate a second image for the deck: it doubles the bill, and a deck figure and its guide figure showing *different* pictures of the same thing is worse than either alone, because the learner cannot tell whether the difference is meaningful.

The template's placeholder is **four shapes** — grey frame, navy circle, icon picture, caption. `Set-SlidePicture` takes its geometry from the frame, deletes the first three, and **keeps the caption**, moving it below the frame. Deleting the caption would shift every text ordinal after it and send the slide number into the wrong shape.

Left unfilled, the layout ships reading **"Replace with image"** — which the deck gate's placeholder sweep catches and fails.

---

## 9. Where this sits in the build

**Artwork is two jobs, not one. Generation is not placement, and only one of them ever had a reason to sit at the end.**

- **Stage 3b - plan.** The visuals go onto the spine with their full content: spec rows and nodes, caption, alt text and prompt. The prompt blocks are emitted onto the page. **The cost count and the user's go/no-go happen here**, where the count is first known, instead of three hours later.
- **Stage 3b exit - lint.** `scripts\Assert-PromptLint.ps1` runs before any generation spend: a person noun as the grammatical subject fails unless the prompt opens with the shoulders-down framing sentence, and every required negative from the RTO profile must be present. It is text-only and costs nothing; the 47-of-57 face round it exists to prevent cost 48 minutes.
- **Stage 7b-i - GENERATE, in the background.** Launched at the END of Stage 3b, keyed by figure slot and prompt hash, with the image review running in the same background arm at its full scope. Writing a PNG into a folder blocks nothing and is blocked by nothing. Generation is off the critical path entirely.
- **Stage 3c - gate the specs**, concurrently with generation. Mirror, leakage, grid disposition, withholding, provenance, figure coverage, spec renderability, caption and cross-reference resolution.
- **Stage 3d - adjudicate**, and emit the figure sheet that travels with every later review pack.
- **Stage 4 / 4b / 4c** render, gate, check readability, and apply and prove the brand.
- **Stages 5 and 6** review. Each reviewer receives the figure sheet, so figure content is read here whether or not any picture has been placed.
- **Stage 7b-ii - PLACE.** `docx-images` runs, and **its position does not move: after Stage 7's re-render, before Stage 8.** Fixed for the same three reasons the assessment skill fixes its own: **after Stage 7**, because Stage 7 re-renders from a fresh template and would throw placed images away; **after both gates**, because neither knows what a prompt block is and both read one as over-long body prose; and **before Stage 8**, because the delivery sweep fails any unresolved bracketed placeholder, and artwork must run while that net is still downstream of it. Regenerate only the slots whose prompt hash changed during remediation; carry the rest, keyed by slot.
- **Stage 7c - full re-gate.** Placement is the last mutation of both artefacts, so it is followed by the COMPLETE gate set, never a subset.
- **Stage 7d - confirming read.** Scoped to what placement changed.

**Read those three reasons again. Every one of them pins PLACEMENT. Not one of them pins generation, and not one of them pins reading the figure content.** The spec was final at Stage 3b.

### The failure this ordering exists to prevent

Placement used to be the whole of artwork, so **every audit round before it read a document in which every figure was still a prompt block.** The first round reported "every figure is missing" and was correctly told that was expected at that stage. Nobody drew the consequence: the figures had therefore **never been read by anyone**. They were first read at the third audit round, more than four hours after the spec was written, and that round returned **Not Compliant - not for release** against a build that had already passed every structural gate. The defects it found - assessed answer grids reproduced in figures, in an open-book assessment - had been sitting in machine-readable JSON since the first hour.

The rule that was supposed to prevent exactly this made it worse. The skill relied on alt-text append so that "a review that skips it has not read the figures" - but alt text only reaches the document at placement, and placement ran after the audits, so **that rule was guaranteed vacuous in every pre-artwork round** and nothing detected the vacuity.

Three rules now close it, and they only work together:

1. **Every text extract carries a provenance header**: `FIGURES: n placed drawings, m unresolved artwork prompt blocks`, plus the channel list. Where `m > 0` it also says **FIGURE CONTENT NOT PRESENT IN THIS EXTRACT**. A reviewer must never have to infer what they are not looking at.
2. **No review record counts as having read the figures** unless `m = 0` or the spine figure sheet accompanied the extract. Every review stage receives a manifest of which channels are final and which are placeholders, and must return a disposition for each; a channel marked placeholder is automatically re-queued.
3. **Delivery requires at least one Stage 6 record that POSTDATES the newest placement.** No build ships on a verdict issued against a document that had no figures in it. Stage 7d exists so that satisfying this costs a short scoped read rather than a fourth full audit round.

**Look at every generated image before placing it** — no lettering, no faces, no logos, nothing contradicting the document. Bare hands on ready-to-eat food is a food-safety defect on the page, not a styling quibble.

### Who owns the image review - Stage 7b-i

**Whoever launches the generation arm owns the review, and the arm is not finished until its record is written** (gates.md section 30.3). Under the serial ordering the review was an inline step of placement and could not be skipped; moving generation into the background took the review with it, and a background arm with no owner, no gate row and no ledger record is an arm that can simply not happen while every structural gate passes.

- **Scope, per image, unchanged:** no identifiable face, no lettering or signage text, no real brand or logo, nothing contradicting the document - wrong PPE, a non-Australian fitting, unsafe practice, or a subject that does not match the slot's caption and alt text on the spine. A fail is a regeneration with the prompt corrected, never a quiet placement.
- **Ledgered as `7b-i`, blocking:** `Add-StageRecord -Stage '7b-i' -Name 'Generate + image review' -Status pass -Findings n`, with `n` the images that failed a first review. No key, or the user declined: `n-a` with a note, which the ledger requires.
- **Heartbeat:** the review file is created with its header and slot list before the first image is looked at, each slot is appended as it is judged, a heartbeat runs, and a restart resumes from disk. A review that writes at the end loses every verdict when the arm dies, and nothing on the critical path is waiting for it.
- **Placement uses only a slot with a passing review record.**
- **An image reviewed against superseded content is re-checked against the final content before placement.** The background review judged it against the spine at generation time; Stage 7 edits the spine. Stage 7 step 7 re-reviews every slot whose content or prompt changed and regenerates where the prompt hash moved; Stage 7d re-checks every placed image against the regenerated figure sheet. A slot that fails at 7d is regenerated, re-reviewed and re-placed before the round closes.

**No API key, or the user declines?** Deliver with the prompts in place and say plainly that the figure spaces carry prompts rather than pictures. **Never delete a prompt to silence the sweep** — an empty space that once held a prompt cannot be recovered.
