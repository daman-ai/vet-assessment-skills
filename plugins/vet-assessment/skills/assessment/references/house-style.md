# House style — readability, response spaces, accessibility, pagination

**These are build rules, not review findings.** They carry the same force as the compliance rules, and the mechanical ones are enforced at the blocking house-rules gate in Stage 4. A document that is compliant and unusable has failed.

The reason this file exists: it is easy to specify everything that protects the auditor as a hard build step and everything that protects the learner as a wish. When that happens, every remediation round makes the document longer, denser and more demanding, and the learner ends up with a compliant document they cannot complete.

---

## A. Language

**Reading level is set by the qualification, not the unit.**

| Qualification (AQF) | ACSF target | Plain-English proxy |
|---|---|---|
| Certificate I–II | Level 2 | Grade 6–8 |
| Certificate III | Level 3 | Grade 8–9 |
| Certificate IV | Level 4 | Grade 9–10 |
| Diploma and above | Level 4 | Grade 10–12 |

Never write above the qualification's level. Where a unit is delivered across two qualifications at different levels, write to the lower one.

- **Sentences of 20 words or fewer.** Split anything longer. The only exception is a sentence carrying a legislative citation in full.
- **Delete throat-clearing.** Start with the verb the learner must act on.
- **Cut words, never demands.** If a stem asks for three things, the tightened stem still asks for three things. Never drop a requirement, a figure, a product code or an appendix reference.
- **One instruction per sentence.** Never stack two demands, or a demand plus a condition. Multiple demands become labelled parts, each with its own response space.
- **Active voice, second person.** "Identify the two hazards you find", not "Two hazards are to be identified by the candidate."
- **No double negatives**, no "unless … except where …" constructions.
- **Consistent terminology over elegant variation.** Use the same word for the same concept every time. Do not alternate guest / customer / patron / diner for one role, or use clean / sanitise / wash interchangeably where they mean different things. Synonym-switching is a known comprehension barrier for learners with English as an additional language.
- **Two-sentence paragraphs** in authored body content.
- **Numbered lists where order matters**, bulleted where it does not. Bullets carry the conditions, steps and requirements — with the **key demand bolded**: the document to use, the number required, the person to work with, the action to take. Never bold decoratively, never bold a whole sentence.
- **Australian conventions** — dates written out (13 August 2026), consistent 24-hour or am/pm time, metric units, Australian currency and spelling.

### Terminology — expand, but never simplify what is assessed

Expand every acronym on first use — *Safe Work Method Statement (SWMS)* — and gloss incidental jargon.

Gloss unavoidable Australian workplace terms at first use: *mise en place*, *front of house*, *split shift*, *in the weeds*. Assume no prior Australian workplace, cultural or regulatory knowledge.

**Do not simplify, paraphrase or substitute the technical terminology the unit actually assesses.** If the unit assesses the term, the learner must meet the term. Simplifying assessed vocabulary under-assesses the unit and is a compliance defect, not a readability improvement.

**Gloss every term in line, at first use.** There is no back-matter glossary — RTO decision, 27 August 2026, `compliance-rules.md` section 3. Inline glossing is what fairness asks for and it is where the reader actually needs it.

### Named people

Every person named in a scenario carries their role at first mention in each part — "Sofia Rossi, Head Chef" — so the learner is never tracking an unexplained name.

---

## B. Response and deliverable spaces

**One labelled space per answerable part — never a single shared box.**

A single-demand item keeps one response box. A multi-part item places a separate labelled space *immediately after each part* — "Student response — (a)", "Deliverable — Part A" — each with a muted-italic inner prompt. The reader must never have to map one box back to several parts.

**Item-per-row tables are mandatory for any list-type component** — two or more named items to define, compare, check or specify.

- Column 1 = the item, shaded, bold, vertically centred
- Remaining columns = the distinct demands, one column per demand, each writable with a muted-italic placeholder. Take the headers from the actual stem — *Term | Definition | Example*; *Item | Storage conditions | How it supports food safety*
- Header row uses the accent band with white bold text
- Column widths sum exactly to the content width
- Row height scaled to the depth expected — deep enough to write in
- **Point to the table** in the stem: "… **Complete the table.**"
- Where a part has a list **and** a separate explanatory demand, the items go in the table and the explanation gets its own labelled box beneath
- A genuinely single-demand part keeps the single open box. Do not force a table where there is only one thing to answer

**A word guide on every question and a stated scope on every deliverable.** No written demand ships without one. This is the first thing a learner checks. "Explain how you would respond to a food safety incident" without a word guide asks the learner to guess whether the answer is 40 words or 400, and a short guess earns a Not Yet Satisfactory for a depth the question never stated.

Scale the guide to the breadth of the evidence point and the AQF level.

---

## C. Self-containment

**Every question, task and checklist item must be completable using this document together with the resources it explicitly supplies or identifies.**

- Never require information that exists only in an assessor guide, benchmark or supplement.
- Every resource named must actually exist and be named precisely enough to find. If a task says "follow the venue's cleaning schedule", the cleaning schedule is in the document or attached to it.
- Every document referenced in the scenario appears in the scenario's *documents available* list.

A learner whose first act is to ask a question the document should have answered has been failed by the document.

---

## D. Page, spacing, navigation, pagination

- **A clickable table of contents in every document**, immediately after the title page. `TableOfContentsPresent` is a blocking check. Build it with `HTableOfContents`, and run `Update-Fields` before delivery or it ships showing its placeholder text instead of a contents list.
- **Banner headings carry `w:outlineLvl`** - 0 for a section banner, 1 for a sub-banner. This is what the table-of-contents field indexes; without it the field renders empty. It is invisible on the page and changes no formatting. Ordinary prose carries none, or the prose lands in the contents list.
- **Keep content together.** `keepNext` on every heading and every question or task stem; `keepLines` on short instruction paragraphs. No heading, stem, one-line instruction or table header stranded at the foot of a page.
- **Line spacing.** `w:line` is **240 (single) or 360 (1.5) only. Never 276.** These are the measured house values and `LineSpacing` is a blocking check. The template cover sheet legitimately runs 216 - the compressed leading that holds it to one page - and is exempt; that is not a licence to use 216 in generated content.
- **Hanging indents**, so wrapped lines align under the text and not under the marker. Without one, a three-line numbered step reads as three steps. Measured values: **460/460** for method steps, **260/260** for panel bullets, **200/200** for bullets inside a grid cell.

### The pagination rule

This replaces the old "one item per page" list and its two hand-coded exceptions:

> **A section heading never occupies a page alone. The first child of a section runs on under its heading. Every sibling after the first starts a new page.**

| Element | Breaks? |
|---|---|
| First body block after the title page | **No** — runs on under the version line |
| Front-matter blocks in the practical workbook | **No** — forcing a break per short block leaves pages nearly empty |
| Front-matter banners in the UAT | Yes |
| Theory question 1 / recipe card 1 / observation 1 | **No** — each runs on under its section heading |
| Theory questions, recipe cards, observations 2..n | Yes |
| Every UAT task | Yes |
| Knowledge Evidence mapping matrix | Yes |
| Foundation skills, End of assessment task | **No** |

**In code this is exactly three conditional sites** — theory questions, recipe cards, observations — each `-PageBreakBefore:($index -gt 0)`. Everywhere else the break is unconditional or absent. **If you find yourself adding a fourth exception, you have misread the rule.**

**Verify by extracting what each break actually lands on, not by counting breaks.** A count of 22 tells you nothing; a list of 22 headings tells you everything. `Get-PageBreakTarget` returns that list and `PageBreakTargets` is a blocking check.

### Bullets — and the exception that gets "fixed" by mistake

Body prose bullets are **real Word numbering** (`pStyle ListParagraph` + `numPr`), never a literal glyph and a tab.

**But inside a table cell or an assessor panel, use a literal `•` + tab + hanging indent.** The house numbering style indents wrongly in a cell.

This exception is written here, in `house-profile.mvc.json`, in `template-build.md` and in the header of `scripts/Docx-Blocks-House.ps1`, because otherwise the next implementer reads the "never a literal glyph" rule and helpfully breaks every panel. Four statements of one rule is the one place duplication is deliberate.

### Spacers, long tables, the cover sheet

- **Put the page break on the heading, never on an empty spacer paragraph.** A spacer left in front of a bound block stays behind when the block is pushed, and prints as a blank page.
Holding a whole table on one page takes `keepNext` on every row but the last, plus real headroom in the sizing. **Never `cantSplit`** — the gate blocks it. `readability.md` rule 5.
- **The cover sheet holds one page.** Compress the layout, never the wording. No clause is cut, summarised or abridged to make it fit. Verify by extracting the rendered page-1 text, not by eye — a dropped clause looks like nothing at all. The compression figures and `Test-CoverSheet` are in `template-build.md`.

### No blank pages, no half-empty pages

Render to PDF and inspect every page before delivery.

**Where a page is less than roughly half filled and is not the last page of a section, deepen the writing rows so the page fills.** The writing room is the learner's working surface — spend the space there rather than pulling content up. Never resolve a half-empty page by shrinking a response box.

---

## E. Accessibility

- Body text at least 11 pt; table and checklist cell text at least 10 pt; placeholder and footer text never below 8 pt

  > **Met since 21 August 2026.** The artefacts rendered body at 10 pt and table text at 9.5 pt, because `docDefaults` carried no `w:sz`. The RTO chose to meet the floor rather than match the artefact - one of only two places a measured value is deliberately overridden, the other being the table of contents. It cost three to five pages per document. `FontFloor` and `DocDefaultFontSize` are blocking checks, scoped to the generated body; the template cover sheet keeps its 8.5 pt policy prose because raising it would push the sheet to a second page.
- **Left-align body text.** Do not justify — ragged right is easier for lower-literacy and EAL/D readers
- **No meaning carried by colour alone.** Every distinction is also carried by a label or by wording. **Exempt: model answers** in an assessor guide — the panel label carries the meaning, so keep the label
- **No coloured text on coloured fill.** **Exempt: model answers** on the light cell fill — red `E43C30` on `F0F2F7` is the house treatment and is deliberate
- **No blocks of ALL CAPS** beyond short banner labels; sentence case in learner-facing prose
- **Icons and symbols never carry an instruction, warning or status alone** — always paired with a text label
- Maintain contrast: white bold on the dark accent, dark text on light fills. No coloured text on coloured fill
- Every instructional image carries a caption or adjacent explanation plus meaningful alt text. Decorative images carry no assessment information
- **Links name their destination** — "SafeWork SA — Hazardous Manual Tasks", not "click here" or a bare URL. A reader working from a printed copy needs enough source detail to find the resource
- **A reasonable-adjustment statement** in the instructions, naming what support is available and how to request it — including for learners with English as an additional language: LLN support, extra time, use of a bilingual dictionary in line with the assessment conditions, oral clarification of instructions. It must say what is permitted, so a learner is not left guessing whether opening a dictionary is cheating. Support never compromises the competency standard

---

## F. Pre-delivery sweeps

Run all of these on the **rendered output**, not the source.

| Sweep | Pass condition |
|---|---|
| Placeholder | Search for `[`, `[Unit code]`, `[Qualification`, `[n]`. Zero count |
| Assessor-only content in the learner document | Search for "benchmark", "critical error", "model answer", "assessor use only", "setup". Zero count |
| Word guides | Every question has one; every deliverable has a stated scope |
| Response spaces | Every answerable part has its own labelled space |
| Acronyms | Every acronym expanded at first use, and every technical term glossed in line at first use. **Do not sweep for a back-matter glossary** — there is none. |
| Named resources | Every resource a task refers to is supplied or precisely identified |
| Reading level | At or below the qualification's ACSF level, excluding legislation titles, verbatim unit text and assessed terminology |
| Page flow | No blank pages, no half-empty pages, nothing stranded at a page foot |
| Australian conventions | Dates, times, measurements, currency, spelling |
| Guidance markers | No line opening with `»` survives. Zero count |
| Brand crossover | See section G. Zero count |

`Invoke-RenderedSweeps` in `scripts/Verify-Document.ps1` runs the mechanical ones. `Test-DocxSweeps` runs the same checks against the source text as a faster early gate, but does not replace the rendered pass — a field or content control can put text on the page that never appears in the source.

---

## G. Brand separation

The skill serves two RTOs whose documents share their rules and differ in every brand fact. **The chosen profile locks for the whole build.** Never check a value against memory of the other brand — check it against the profile.

The figures most often crossed over: the cover-sheet day counts, the palette, the logo, the RTO and CRICOS numbers, and the recipe unit casing.

### Recipe units are lower case

MVC writes `gms`, `ml`, `each`, `tbsp`, `tsp`, `drops`, `pinch`, `sheet`. ACI initial-caps them. **Grams are `gms` — never `g`, `G` or `Gms`.** Normalise every source variant. This is a brand divergence, not a drafting slip, and `Gms` is on the MVC forbidden-token list for exactly that reason.

### The sweep

`forbiddenTokens` in each branding profile drives it. Every token declares its own match mode, because one blanket rule produces false positives that train the reader to ignore the sweep:

| Mode | Matching | For |
|---|---|---|
| `word-cs` | whole word, case-sensitive | acronyms and cased style tokens — `ACI`, `MVC`, `Gms` |
| `word-ci` | whole word, case-insensitive | codes, numbers, hex colours |
| `substring-ci` | anywhere, case-insensitive | multi-word names and domains |

`ACI` matched as a loose case-insensitive substring hits **"facility"** and **"spacing"**. `Gms` matched loosely hits every correctly lower-cased `gms`. Both were observed on the real templates.

Check the header image and the footer fields as well as the body. A logo is a brand crossover the text sweep cannot see.

### The footer is field-driven, never typed

The footer reads its values through `DOCPROPERTY` fields so they populate from the document properties. **Never re-type a footer value a field can supply.** The previous MVC template typed its footer, and the typed values drifted out of step with the properties within one revision. A file whose footer disagrees with its own document properties is a document-control finding.

The mechanics — writing both `docProps/custom.xml` and the cached field result, and why both are required — are in `template-build.md`, *Document control*.

### Derive every count, never type one

This rule and the cross-reference rule below apply to every document the skill builds. `recipe-workbook.md` section 11 points here.

"This workbook carries thirteen recipes" is true on the day it is written and wrong the moment a recipe is added. Any number in prose describing the document — recipe count, question count, portion count, page count — is generated from the data at build time. Where a count distinguishes kinds of thing, generate both parts.

### Re-check every cross-reference when a section moves

Text saying where something lives — "at the back", "on the following page", "in the section below" — is a pointer, and moving a section silently invalidates it. After any structural change, search the rendered text for locational phrases and confirm each still points at something that exists in this document. A pointer into a companion document names that document by title.
