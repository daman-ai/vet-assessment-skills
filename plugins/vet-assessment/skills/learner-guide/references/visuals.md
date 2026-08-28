# Visuals — placement, prompts and artwork

Distilled from **MVC Learner Guide Visual Placement Report — Master Prompt v3.1** (30 July 2026), which is the RTO's own standard for where visuals go in a learner guide and how they are briefed.

The guide is built with **prompts on the page, not pictures**. Stage 7b hands it to the `docx-images` sub-skill, which turns each prompt into artwork, places it at the same spot with its caption and alt text, and deletes the prompt. What ships carries no prompt text anywhere.

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

## Writing a Route B spec

A short bulleted list, then caption and alt text:

- Diagram type and orientation.
- **Every node, box, step, row and column with its exact final wording.** Write the words that will appear, not a description of them.
- Sequence, branching and decision logic — each decision question with its Yes and No paths, entry point, exit points and any loop-backs.
- One line assigning palette and type: fills, text colours, connectors, header bands, row tints, font sizes. Where a colour fails contrast as text, name the substitute here.

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

- **Stage 3b** plans the visuals into the spine and emits the prompt blocks.
- **Stage 7b** runs `docx-images`. Its position is fixed, for the same three reasons the assessment skill fixes its own: **after Stage 7**, because Stage 7 re-renders from a fresh template and would throw placed images away; **after both gates**, because neither knows what a prompt block is and both read one as over-long body prose; and **before Stage 8**, because the delivery sweep fails any unresolved bracketed placeholder, and artwork must run while that net is still downstream of it.

**Look at every generated image before placing it** — no lettering, no faces, no logos, nothing contradicting the document. Bare hands on ready-to-eat food is a food-safety defect on the page, not a styling quibble.

**No API key, or the user declines?** Deliver with the prompts in place and say plainly that the figure spaces carry prompts rather than pictures. **Never delete a prompt to silence the sweep** — an empty space that once held a prompt cannot be recovered.
