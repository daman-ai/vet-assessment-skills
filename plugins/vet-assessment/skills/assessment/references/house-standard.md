# Stage 0 — locate and measure the RTO's own artefacts

**This runs before anything else. Before the unit is sourced. Before a scenario card is written.**

---

## Precedence — read this first

1. **The RTO's own existing artefacts are the authority.** Not this skill's defaults. Not a template you found. If the RTO has already made an assessment for this unit or a sibling unit, its architecture, formatting and scenario world are the specification. **Measure them; do not approximate them.**
2. **Never use a Learner Resource to fact-check an assessment.** The learner resource is written *after* the assessment is finalised, and is derived from a compliance-passed assessment. It is downstream. Checking an assessment against it inverts the dependency and launders errors. The UAT, the workbook and the assessor guides are the sources.
3. **Never ignore the RTO's document architecture** — not the number of documents, not their internal order, not what lives in which. If their knowledge tool has fifteen Tasks in six sections with two appendices, you produce fifteen Tasks in six sections with two appendices.
4. Where an RTO artefact contradicts anything in `references/`, **the artefact wins.** Record the divergence in the build report. Do not "correct" their document to match this skill.

> The single most expensive failure on SITHPAT018: the skill took only the unit code, invented a venue, invented recipe codes, and used a tempering method that contradicted the standard already printed in the RTO's own Appendix B. Three remediation rounds polished a pack aimed at the wrong target.

---

## The procedure

**1. Ask for the artefacts.** Ask for the *folder*, not for a description.

> "Before I build anything: where are your existing assessment documents for this unit, or for the nearest sibling unit? I need the folder — the UAT, the workbook and the assessor guides. I will measure them and match them."

**If the user says there are none, ask a second time for a different unit's pack.** An RTO that has been operating has artefacts. Only when there is genuinely nothing may you invent a scenario world — and then you ask the user to confirm it before building on it.

**2. Measure. Do not eyeball.** Read `word/styles.xml` and `word/document.xml` and *count*:

| What | Capture |
|---|---|
| Architecture | How many documents, what each is called, the internal order of every section |
| Formatting | Default run size, cell text size, line spacing values, table widths, row heights, bullet mechanics, page-break sites |
| Scenario world | Venue, cast, product range, codes, technical standards, appendices |
| Cover sheet and title page | Clause by clause |
| Item noun | Do they say Task or Question? Copy their noun |

**3. Write two outputs:**

- `assets/MVC_HOUSE_STANDARD.md` (or the RTO equivalent) — the prose record, with the measured numbers and where each came from. MVC's is shipped with the skill
- `assets/house-profile.<brand>.json` — the machine-readable profile the builder and the gate both load

**4. Only then** source the unit and build the register.

---

## What the profile drives

`assets/house-profile.mvc.json` is loaded by `Get-HouseProfile` and is read by:

- `scripts/Test-HouseRules.ps1` — every blocking check reads its threshold from it
- the builder — table width, sizes, line spacing, row heights, response-box heights
- the pagination gate — the break map

**Change the profile and the scripts follow.** That is the point: a figure that lives in one place cannot drift out of step with a check that reads it. The 45-day results figure was once asserted in a dozen places, three of them executable. Two of those three would have **failed a correct document**: a build sweep, and a cover-sheet clause check that reported the clause *missing*. That is the cost of a figure living in more than one place.

---

## The reference set

Four documents the RTO approved on 21 August 2026, in `C:\Users\ACI-Admin\Desktop\SITHPAT018\out-house`:

- `SITHPAT018_UAT1_Knowledge.docx`
- `Assessor_Guide_SITHPAT018_UAT1_Knowledge.docx`
- `SITHPAT018_Recipe_Workbook.docx`
- `Assessor_Guide_SITHPAT018_Recipe_Workbook.docx`

**Future output matches these.** They are the measurement source, and `assets/house-profile.mvc.json` was verified against them value by value - the verification is recorded in `_provenance.verifiedAgainstReferenceSet`.

They supersede `D:\Superseded\SAMPLE RESOURCE`. That older set has no table of contents, and it carried two defects since fixed: a reversed `jc`/`spacing` pair in the recipe photo cell, and a recipe header table whose columns summed to 8638 against a 9638 width. **Do not re-measure from it.**

---

## Re-measure when

- A different RTO
- The RTO issues a new template
- The RTO changes a position (record the decision and its date in the profile)

**Do not carry measured numbers across between RTOs.** The MVC figures in the profile are MVC's, measured on 21 August 2026. Another RTO gets its own profile.

---

## Reporting a source defect

Measuring properly means you will find defects in the RTO's own documents. **Preserve them and flag them. Do not silently invent a correction.**

The standing rule is *match the artefact*. Where matching it reproduces something wrong, the build reports it as a **warning, not a block**, and puts it to the RTO as an explicit decision.

**No warning is currently standing.** Both examples below are closed. They are kept as the worked record of the process, because the process is the point: measure, report, let the RTO decide, patch at source, then retire the warning.

> **Closed, 21 August 2026 - table overflow.** House tables are 9638 dxa and both templates had a 9026 dxa text column, so every table bled 612 twips (about 1.08 cm) past the right margin. The RTO chose to **widen the margins to 1134 each side**, making the text column exactly 9638. `scripts/Patch-TemplateMargins.ps1` applied it to both templates and widened the recipe template's 46 tables to match. Kept here as the worked example of the process: measure, report, let the RTO decide, then patch at source.

> **Closed, 21 August 2026 - accessibility floor.** The artefacts rendered body at 10 pt and table text at 9.5 pt, below the 11/10 floor, because `docDefaults` carried no `w:sz` and OOXML falls back to 10. The RTO chose to **meet the floor**. `scripts/Patch-TemplateFontFloor.ps1` set the document default to 22 half-points; `SZ_CELL` and `SZ_SMALL` moved to 20. Cost: three to five pages per document, and every page break moved. The cover sheet keeps its 8.5 pt policy prose - raising it would push the sheet to a second page, and cutting a clause to compensate is forbidden.

---

## The MVC measured architecture

Recorded here because it is the shape everything else assumes. It is **measured**, not chosen — for another RTO, measure theirs.

**The practical branch sets the document count: four documents on the food branch, two on the non-food branch.** The file names and audiences are in `SKILL.md`; the machine copy is `assets/house-profile.mvc.json` → `architecture`. Measured for MVC on 21 August 2026 and matching both. What follows is what the measurement adds to that list.

Knowledge and practical are separate assessment tasks on the food branch; the knowledge tool carries no practical section.

Each assessor guide **mirrors its learner document exactly and adds**. It is not a document with its own structure. It opens, before the cover sheet, with:

> **ASSESSOR VERSION — CONTAINS BENCHMARK ANSWERS**
> Model answers are shown in red in the student response spaces. Do not issue this document to students.

**A clickable table of contents in every document**, after the title page. RTO decision, 21 August 2026 - this overrides the measurement, because the RTO artefacts have none.

Items are **Tasks**, not Questions — because the RTO's artefact calls them Tasks. Copy their noun; measure it, do not assume it.

### Internal order

The measured sequence for each document is `assets/house-profile.mvc.json` → `order` (`uat1`, `uatCombined`, `workbook`), and what each block must contain is `compliance-rules.md` section 3. Two things the measurement settles that are easy to reverse by accident:

**The observation sheets are collected at the end, not interleaved after each recipe.** There is no case study, no detailed scenario block, and no recipe requirements or quantity adjustment templates.
