# The Delivery PowerPoint

A deck a trainer can teach from cold, aligned section by section to the guide, signposting the assessment questions throughout.

---

## 1. How it is built

**Clone a layout exemplar and swap the words.** The MVC template is not a set of PowerPoint layouts — it is a **13-slide layout library**, one worked exemplar per layout, each already carrying the logo, footer, accent stripe and type ramp. The delivered `SITHPAT018_Delivery_PowerPoint.pptx` was built exactly this way: its content slides are the template's slide 4, shape for shape, name for name.

There is no `python-pptx` and no Node on this machine, and neither is needed. A `.pptx` is a zip of XML, and `Expand-Docx` / `Compress-Docx` are format-agnostic.

```powershell
$dp   = Get-DeckProfile -SkillDir "$SkillDir\scripts"
$deck = New-Deck -TemplatePath "$SkillDir\assets\templates\MVC_Branded_PPT_Template.pptx"

New-DeckSlide -Deck $deck -Profile $dp -Layout single `
    -Chip 'Prepares you for: UAT 1 Q5' `
    -Notes 'PC 1.1. ... Direct learners to UAT 1 Q5 per the Assessment Activity Sequence Map.' `
    -Content @{ kicker   = '1.1 CONFIRM PRODUCTION REQUIREMENTS'
                headline = 'The standard recipe is the recipe of record'
                lead     = '...'
                bullets  = @('...', '...') }

Set-DeckSlideNumbers -Deck $deck -NumberSlotByLayout (Get-DeckNumberSlotMap -Profile $dp) | Out-Null
Save-Deck -Deck $deck -Path "$out\$code`_Delivery_PowerPoint.pptx"
```

**Address shapes by slot name, never by ordinal in build code.** Template shapes are named generically — "Text 1", "Text 5" — so names carry no meaning; the ordinal map lives in `assets/deck-layouts.mvc.json` and nowhere else. A typo in a slot name **throws**, because silently ignoring it is how a deck ships with `Headline statement for this slide` still on a slide.

`Save-Deck` gates the package **before writing**. See `gates.md` §8 for what that catches and why it is not optional.

---

## 2. The layouts

| Name | Use it for |
|---|---|
| `title` | Unit code and title, qualification, presenter, date, location |
| `agenda` | One numbered row per Topic. Five rows; more Topics take a second agenda slide |
| `divider` | Section divider, numbered 01–0N, with the questions that section covers |
| `single` | The workhorse — concept, explanation, a short list |
| `two` | Compare or pair two ideas |
| `cards` | Three related items |
| `figures` | **Numbers** — temperatures, percentages, limits, standard drinks. Exactly the items most likely to appear in the knowledge questionnaire |
| `table` | Criteria, options, the question cross-reference. A real PowerPoint table — fill with `Set-SlideTableCell`, and **delete spare rows** with `Remove-SlideTableRow` rather than leaving "Row label four" on screen |
| `process` | Numbered steps with arrows. Ordinals 6, 10 and 14 are the arrows — leave them alone |
| `callout` | A quote or a single statement to land |
| `image` | A visual with explanation |
| `thanks` | `INNOVATION · TRADITION · EDUCATION` and contact |
| `brandref` | Kept at the end, unchanged |

`thanks` and `brandref` are marked `verbatim` in the profile: their template text **is** the delivered text, so the placeholder sweep exempts them.

---

## 3. Deck structure

1. Title
2. Housekeeping *(optional)* — RTO, Acknowledgement of Country, reasonable adjustment, how the session runs
3. Overview / agenda — one numbered row per Topic, mirroring the guide's contents
4. **How this session maps to your assessment** — one orientation slide: the knowledge tool, the performance tool, and the promise that each topic's slides flag the relevant questions
5. **Each Topic — at least 15 slides:** divider (with the questions that section covers) → topic outcomes → key terms → several slides per PC sub-section → assessment-link slides → topic recap
6. **Assessment briefing** near the end — the full Question Cross-Reference, then the practical assessment and its benchmarks
7. Thank-you
8. Brand reference

---

## 4. The 15-slide floor

**At least 15 slides per Topic section.** Counting toward it: the divider, topic outcomes, key terms, every PC content slide, scenario and case-study slides, figures/table/process slides, assessment-link slides, and the recap. Outside the count: title, housekeeping, agenda, assessment orientation, briefing, thank-you and brand reference.

**How to reach 15 without padding.** Split each PC sub-section into focused, one-idea slides:

> concept → why it matters → how to do it → key figures → workplace case study → common errors → assessment link

The delivered SITHPAT018 deck does this well and is worth reading: Topic 1 runs to roughly thirty slides, and six of them are `TECHNICAL ·` slides carrying the underpinning knowledge — what couverture is made of, cocoa butter crystal forms, the two kinds of bloom, why the storage numbers are what they are, the tempering curve, why ingredients spoil. That is where a deck earns its length.

**Where a Topic genuinely cannot reach 15**, report it — `Topic 3: 12 slides, limited PC content` — with what would close the gap. Never duplicate a slide to hit the number.

---

## 5. Assessment references — the distinguishing requirement

The path from teaching to assessment is explicit and consistent, in three places:

- **The chip.** Every PC teaching slide carries a visible pointer, bottom-right, orange-ruled: `Prepares you for: UAT 1 Q5` or `Assessed in: UAT 2 — Task 2`. **The wording is identical to the guide's Assessment Prompt**, taken verbatim from `assessmentLink.wording` in the spine, so the two resources line up word for word.
- **The divider.** Each Topic divider lists the questions that section covers.
- **The cross-reference slide.** A dedicated table reproducing the guide's Question Cross-Reference.

The chip is a **real shape**, built by `Add-SlideChip` — the template ships none — so a trainer editing the slide cannot lose the reference by retyping a bullet.

Where a question maps to several PCs, signpost it on each. Where a PC has several questions, list them all. **Derive every reference fresh from the pack** — never carry one over from a prior deck.

---

## 6. Speaker notes

Required on **every teaching, case-study, assessment-link, figures, process and table slide**. Not required on title, dividers, agenda, thank-you or brand reference.

Each note must do two things:

1. **Summarise the teaching point in plain English for the trainer.**
2. **Name the exact question(s)** and remind the trainer to direct learners to complete them per the Assessment Activity Sequence Map.

The delivered deck's notes are the model:

> *PC 1.2. This is the exact calculation chain in UAT 1 Q9(b). Work it on the board. Note the seed is reserved FROM the total, not added on top — that is stated in Appendix B of the assessment and in the Recipe Workbook.*

The Stage 5 persona test is the check: **could a trainer teach this Topic from the deck and its notes alone, without the guide open?**

---

## 7. Content rules

- **One idea per slide.** Concise on-slide text — a headline plus a few short points, or one visual — with the depth carried in the notes.
- **Reproduce numeric content exactly** as the guide and the pack state it. Figures are referenced from the spine, never retyped.
- **Categorical colours mean something.** Yellow and deep orange for warnings and hazards, not decoration.
- **Accessibility.** High contrast, sentence-case body text, alt text on meaningful images.
- **Watch shape capacity.** The deck gate warns above 420 characters in one shape. A slide that overflows its box is worse than two slides.
