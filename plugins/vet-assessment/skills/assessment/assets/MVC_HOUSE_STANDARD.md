# MVC house standard — derived from the RTO's own artefacts

Measured from `D:\Superseded\SAMPLE RESOURCE` on 21 August 2026. **These artefacts are the authority.** Where the assessment skill's `references/` disagree, the artefacts win.

**The Learner Resource is NOT a source of truth.** It is written after the assessment is finalised and is derived from a compliance-passed assessment. Never fact-check an assessment against it.

---

## 1. Document architecture — fixed, never varied

| # | Document | Audience |
|---|---|---|
| 1 | `SITHPAT018_UAT1_Knowledge.docx` | Learner — knowledge |
| 2 | `Assessor_Guide_SITHPAT018_UAT1_Knowledge.docx` | Assessor — mirror + red model answers |
| 3 | `SITHPAT018_Recipe_Workbook.docx` | Learner — practical |
| 4 | `Assessor_Guide_SITHPAT018_Recipe_Workbook.docx` | Assessor — mirror + benchmarks |

Knowledge and practical are **separate assessment tasks** — UAT 1 and UAT 2. The knowledge tool does not carry a practical section, and the practical is not folded into the knowledge tool.

Assessor documents open with, before the cover sheet:

> **ASSESSOR VERSION — CONTAINS BENCHMARK ANSWERS**
> Model answers are shown in red in the student response spaces. Do not issue this document to students.

The assessor guide **mirrors the learner document exactly** and adds. Learner page counts: UAT 1 = 53 pages as an assessor guide against the learner original; Recipe Workbook 66 learner / 81 assessor.

**No table of contents in any document.**

### UAT 1 — Knowledge, internal order

1. Assessment cover sheet
2. Title page
3. Assessment overview — names the task as UAT 1, the qualification, the scenario venue, and points at Appendix A and B
4. What this assessment covers — the six sections
5. How you are assessed
6. Instructions to students
7. Principles of assessment & rules of evidence — two separate tables
8. Quality expected of your written responses
9. Assessment conditions — open book, duration and session structure, security between sessions, individual work / permitted assistance / generative AI, assessment mode, resources provided
10. Task summary — table of Q · Section · Focus · Word guide
11. **Appendix A** — the chocolate range
12. **Appendix B** — the tempering standard
13. **Tasks 1 to 15**
14. Knowledge Evidence mapping matrix — KE point · Assessed in, using *primary* / *supporting*
15. Foundation skills — a short prose note, not a table
16. End of assessment task

Items are **Tasks**, not Questions: `Task 7 — Protecting polished chocolate moulds`.

Tasks are grouped into six sections, named in the overview only:

- **A** — terminology and stock (Tasks 1–2)
- **B** — production processes and origins (Tasks 3–4)
- **C** — mise en place, equipment and moulds (Tasks 5–7)
- **D** — tempering (Tasks 8–10)
- **E** — centres, fillings and coating (Tasks 11–13)
- **F** — decoration and storage (Tasks 14–15)

### Recipe Workbook — internal order

1. Assessment cover sheet
2. Title page
3. Instructions to students
4. Principles of assessment & rules of evidence
5. Assessment conditions
6. Workbook purpose
7. Current unit focus
8. How to use this workbook
9. **Theory questions**, including the *Special customer request adjustment* question
10. **Product evidence matrix**
11. **Recipe cards 1 to 15**, all together
12. **Assessment instrument — observation of practical competency** (cover)
13. **Observations 1 to 8**, all together at the end

**The observation sheets are collected at the end, not interleaved after each recipe.** There is no case study, no detailed scenario block, and no recipe requirements or quantity adjustment templates.

---

## 2. Cover sheet

Both artefacts differ. **Use the UAT 1 variant** — it is the newer, standardised sheet.

| Point | UAT 1 (use this) | Recipe Workbook sample (pre-patch) |
|---|---|---|
| Student ID label | `Student MVC ID:` | `Student ID:` |
| Due date label | `Due Date:` | `Assessment Due Date:` |
| Online checkbox | present | absent |
| Late submission | **14 days** | 15 days |
| Results | **14 days** | 45 days |
| "Gaps" paragraph | absent | present |
| Checkbox glyph | ☐ U+2610 | □ U+25A1 |

`Qualification:` and `Unit Code & Name:` are **pre-filled**, not left blank.

> The assessment skill states results = 45 days. The RTO's newest artefact says **14**. The artefact wins; flag it once per build.

---

## 3. Title page

- `ASSESSMENT` wordmark — bold, 32 pt (`w:sz 64`), colour `2F60B4`, centred, `spacing before 280`
- Tagline `I N N O V A T I O N   ·   T R A D I T I O N   ·   E D U C A T I O N`
- `SITHPAT018 — Produce chocolate confectionery`
- `SIT40721 Certificate IV in Patisserie`
- `Release 1   ·   Certificate IV (AQF Level 4)` — one line, middot separated
- **Colour band** — a four-cell table, each cell 1927 DXA: `F09C0C` · `F5C800` · `E45418` · `606060`
- RTO block: name, `RTO 45039      ·      CRICOS 03551M`, legal entity, website, address, phone · email

> The skill says the colour band was removed. It is present in the RTO's artefact. **Keep the band.**

---

## 4. Formatting — measured, not inferred

| Setting | Value |
|---|---|
| `docDefaults` run size | **not set** — Word falls back to **10 pt**. Do not add one. |
| Font | Arial, colour `1A1A1A` |
| Table and cell text | **9.5 pt** (`w:sz 19`) — the dominant size, 217 runs |
| Body prose | 11 pt (`w:sz 22`) where explicitly sized |
| Banner headings | 13 pt (`w:sz 26`), white bold on `234B8C` |
| Line spacing | **240 (single) or 360 (1.5) only.** Never 276. |
| Table width | `9638` DXA, every table |
| Writing-cell row heights | 850–2600, **typically 1050**; deep answers 2200–2600 |
| `cantSplit` | **none** |
| `tblHeader` | on header rows (22 uses) |
| Bullets | **real Word numbering** (`numPr`, 26 uses) — never a literal glyph plus tab |
| `outlineLvl` | **none** |
| Page breaks | `pageBreakBefore` on headings (17); three explicit `br type=page` |
| `keepNext` | 45 uses, on headings and stems |

### Typography conventions

| Convention | House style |
|---|---|
| Degrees | `°C` — the symbol, not "degrees Celsius" |
| Ranges | en dash — `16–18 °C`, `1–4 °C`, `20–35 words` |
| Percent | `50–60%` |
| Portion size | `5g`, `30g` — no space, single `g` |
| Ingredient units | `gms`, lower case |
| Middot separator | `·` with wide spacing |

---

## 5. Scenario world — fixed

**La Meridienne Patisserie, Rundle Street, Adelaide.** A patisserie and chocolatier producing a boxed retail range and function orders. Do not invent a venue, a cast, an order or a product.

### Appendix A — La Meridienne chocolate range

| Product | Centre or filling | Process | Couverture | Finish |
|---|---|---|---|---|
| A1 — Rocher / mendiant, fruit and nut | Hard centre — fruit and nut cluster | Cut or dressed | Dark | Rough surface, fruit and nut set on top |
| A2 — Chocolate heaven bliss ball, marzipan | Soft centre — marzipan | Hand coated | Dark | Hand-rolled finish |
| A3 — Caramel bonbon | Hard centre — caramel filling | Moulded | Milk | Cast shell, coloured cocoa butter |
| A4 — Coffee liqueur bonbon | Filling — coffee liqueur fondant | Moulded | Dark | Cast shell, piped line |
| A5 — Strawberry fondant bonbon | Filling — strawberry flavoured fondant | Moulded | White | Cast shell, coloured cocoa butter |
| A6 — Passionfruit ganache chocolate | Filling — passionfruit milk chocolate ganache | Cut or dressed | Milk | Hand dipped, fork marking |
| A7 — Almond croquant | Filling — almond croquant | Cut or dressed | Dark | Hand dipped, dusted finish |
| A8 — Chocolate dipped nougat | Hard centre — nougat | Cut or dressed | Dark | Hand dipped, smooth dipped finish |
| A9 — Raspberry jelly square | Soft centre — raspberry jelly | Enrobing | Dark | Transfer sheet |
| A10 — Orange liqueur hollow sphere | Filling — orange liqueur syrup | Prepared hollow shells | Dark | Piped filigree |

### Appendix B — MVC tempering standard

**The house method is vaccination (addition) / seeding.** Melt the couverture, add unmelted seed couverture, stir until the temperature falls to the working temperature.

| Couverture | Melting temperature | Working temperature |
|---|---|---|
| Dark | close to 40 °C | **32 °C** |
| Milk | close to 40 °C | **31 °C** |
| White | close to 40 °C | **30 °C** |

- If couverture cools to 27 °C and is still fluid it can be reheated; if solidified it must be re-tempered.
- The tempering machine cools melted couverture at **1.5 °C per minute**.
- Seed couverture is **reserved from** the total weight required, not added on top.
- Raspberry jelly (A9) needs **four hours** to set before cutting. Caramel (A3) needs **two hours** to cool before piping.
- Available: **one** tempering machine, **one** enrobing machine, **one** set of polished bonbon moulds.

> The tabling method is taught and assessed as knowledge, but the **house production standard is seeding**. Recipe cards temper by seeding.

---

## 6. Recipe cards

Fifteen cards, numbered `Recipe N. Name   (MVCxxxx)`:

| # | Name | Code |
|---|---|---|
| 1 | Tempered White Chocolate Couverture | MVC1845 |
| 2 | Tempered Milk Chocolate Couverture | MVC1846 |
| 3 | Tempered Dark Chocolate Couverture | MVC1847 |
| 4 | Rocher, Mendiant – Fruit and Nut | MVC1848 |
| 5 | Chocolate heaven bliss balls, Marzipan filling | MVC1849 |
| 6 | Caramel Filling | MVC1850 |
| 7 | Coffee liqueur fondant filling | MVC1851 |
| 8 | Strawberry filling, flavoured fondant | MVC1852 |
| 9 | Filled chocolates | MVC1853 |
| 10 | Raspberry jelly | MVC1854 |
| 11 | Passionfruit milk chocolate ganache | MVC1855 |
| 12 | Almond croquant | MVC1856 |
| 13 | Chocolate dipped nougat | MVC801 |
| 14 | Raspberry jelly square | MVC1857 |
| 15 | Orange liqueur hollow sphere | MVC1858 |

**The three tempered couvertures are recipe cards in their own right.**

### Card anatomy and house length

Banner → photo → header table (Group · Base / method — Yield · Portion size — Times · Recipe number) → Competency focus with evidence tags → Ingredients → Method → `Test:` → `Tip:` → Storage and presentation → `Presentation standard:`

- **Method is 3 to 5 steps.** Short, plain, imperative. Not 30.
- **Storage bullets are boilerplate**, repeated across cards:
  - Store finished chocolates at 16–18 °C and 50–60% relative humidity, sealed, away from light and strong odours
  - Refrigerate cream-based fillings and components at 1–4 °C, covered and labelled with production date and use-by
  - Rotate stock first-in first-out.
- **Presentation standard is boilerplate**, repeated: *"Consistent size and shape, even coating thickness, glossy surface with a clean snap, no fingerprints, bloom or air bubbles."*
- Times row may be left blank (`Preparation: Cooking:`).
- No production notes box. No per-card assessor content.

---

## 7. Theory questions in the workbook

Present, and they include the **Special customer request adjustment** question — structured as numbered Parts, each with its own box, headed by *Why this question is here* and a `Tip:` line, closing with a minimum word count. That question is explicitly marked *"Not assessed in UAT 1."*

---

## 8. Observation instrument

- One cover page: *Assessment instrument — observation of practical competency*
- Observations 1 to 8, one per element, **collected at the end of the workbook**
- Heading form: `Observation 1` tab `Select ingredients`
- Table: PC · The student did this · S · NS, then assessor notes, then result and trainer signature rows

---

## 9. Pagination rules — fixed by the RTO, 21 August 2026

These are rules, not one-off fixes. Every future build obeys them.

| # | Rule |
|---|---|
| P1 | The **first body block continues on the title page**. No page is given over to white space under the version line. UAT 1 opens with *Assessment overview*; the Recipe Workbook opens with *Instructions to students*. |
| P2 | **Theory question 1 continues under the *Theory questions* intro.** No page is left over after the section heading. Questions 2 onward each start a new page. |
| P3 | **Every UAT task starts a new page.** |
| P4 | **Every recipe card starts a new page.** |
| P5 | **Every observation sheet starts a new page.** |
| P6 | The **Knowledge Evidence mapping matrix starts a new page.** |

### Reversals of earlier entries

- **§3 colour band — REMOVED.** The four-cell colour rule under the logo is not to appear on any of the four documents. The earlier note "Keep the band" is withdrawn.
- **§2 cover sheet — 14 and 14.** Late submission **14 days**, results **14 days**, on every cover sheet in the pack. Both templates shipped 45 days for results; both are patched at build time. (The "results = 45 days" remark earlier in this file records what the artefact carried, not what a build ships.)
- **Table of contents — EVERY document carries one.** RTO decision, 21 August 2026, overriding the measurement above ("No table of contents in any document"). `TableOfContentsPresent` blocks without it; banners carry outline levels so the field has something to index.
- **Font floor — 10 pt cell text, docDefaults w:sz 22.** RTO decision, 21 August 2026. The measured 9.5 pt cell text and the unset docDefaults recorded above are the artefact's history, not the rule: builds meet the accessibility floor, and `FontFloor` / `DocDefaultFontSize` block below it. The earlier "Do not add one" note about docDefaults is withdrawn — `Patch-TemplateFontFloor.ps1` added it.
- **Provenance.** The `D:\Superseded\SAMPLE RESOURCE` folder this file was measured from is superseded — do not re-measure from it; `references/house-standard.md` records the current source of truth. Where this file and `assets/house-profile.mvc.json` disagree, the profile wins: it is what the gates read.

### Assessor guide

- Model answers print in the model colour `E43C30` **everywhere they appear** — in the open response boxes and in the answer grids.
- Model answers are point form, not prose.
