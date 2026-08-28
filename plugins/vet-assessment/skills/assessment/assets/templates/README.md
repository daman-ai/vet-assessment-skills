# Templates

The approved MVC build bases. Every document this skill produces is made by editing one of these — unpack, edit the XML, repack — never generated from scratch. That is what keeps the styles, palette, header logo, footer fields and cover-sheet wording identical to what the RTO signed off.

| File | Builds | Source |
|---|---|---|
| `MVC_Assessment_Template_Combined_PE_KE_v2.2.docx` | `[UNIT]_UAT1_Knowledge.docx` (food branch) or `[UNIT]_UAT.docx` (non-food, carries both sections), each with its assessor guide | `D:\Superseded\1 MVC_Assessment_Template_Combined PE KE_v2.2.docx` |
| `MVC_Recipe_Workbook_Template.docx` | `[UNIT]_Recipe_Workbook.docx` and its assessor guide — food branch only | `D:\Superseded\2 MVC_Recipe_Workbook_Template.docx` |
| `MVC_Recipe_Workbook_Template.prepatch.docx` | nothing — kept as the pre-patch original | created by `scripts/Patch-RecipeTemplateCoverSheet.ps1` |
| `*.predaycount.docx` (both templates) | nothing — kept as the pre-patch originals | created by `scripts/Patch-TemplateDayCounts.ps1`, see below |

Both carry the MVC logo embedded in `word/media/` and referenced from `header1.xml`. **Inherit it.** Do not re-insert, resize or substitute it.

Both carry the document-control custom properties the footer reads through `DOCPROPERTY` fields — `RTOnumber` = `45039` and `CRICOSnumber` = `03551M`, both **unprefixed**, with the footer text supplying the words.

---

## The cover-sheet patch

The two templates arrived disagreeing about their own cover sheet. Since a build now emits both documents as one pack, the cross-document consistency step of the compliance review would raise that difference on every run.

**The RTO's decision was to standardise on the combined template.** `scripts/Patch-RecipeTemplateCoverSheet.ps1` applies it to the recipe template. It has been run; the table below is the record.

| Cover-sheet point | Combined v2.2 | Recipe, as supplied | Now |
|---|---|---|---|
| Student ID label | `Student MVC ID:` | `Student ID:` | `Student MVC ID:` |
| Due date label | `Due Date:` | `Assessment Due Date:` | `Due Date:` |
| Online submission checkbox | present | absent | present |
| Late submission window | 14 days (×2) | 15 days (×2) | 14 days (×2) |
| "Gaps" paragraph | absent | present | absent |
| Results window | 45 days | 45 days | **14 days** — see the day-count patch below |

### What this supersedes

The Recipe/Activity Workbook Master Production Prompt v4.0 states four of these as **"MVC locks"** — 15 days, the Gaps paragraph, `Student ID` / `Assessment Due Date`, and no Online checkbox. Those four positions are **superseded**, and only those four. Everything else in v4.0 stands unchanged, including the $150/$200 resit fees, the 20 working days for appeals and the three-attempt limit.

Record the correction in the compliance report on every build, under the document-control heading. It is a deliberate divergence from a written master prompt, so it is stated rather than left for a validator to discover.

### One difference deliberately left alone

The two sheets use different checkbox glyphs: the combined template uses `☐` (U+2610 BALLOT BOX), the recipe template `□` (U+25A1 WHITE SQUARE). This was **not** part of the decision and has not been changed — swapping a glyph risks font substitution, and both render as an empty box. It is recorded here so a validator comparing the two sheets side by side sees a known, accepted difference rather than a fresh defect.

---

## Re-running the patch

Safe and idempotent. It checks each source string is present before editing and reports `already patched` rather than failing, so a partly-applied patch completes cleanly.

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Patch-RecipeTemplateCoverSheet.ps1
```

Add `-WhatIf` to see what it would change without writing. The first real run copies the original to `.prepatch.docx`; later runs leave that backup alone, so it always holds the file as supplied.

---

## Replacing a template

When the RTO issues a new template version:

1. Drop the new file in beside the old one and update the path in `assets/branding.mvc.json` under `templates`.
2. Re-run the cover-sheet patch — it will report which edits the new template already carries.
3. Re-check `references/template-build.md` against the new file. The placeholder tokens and the Question, Task, Part, Observation checklist and Observation record blocks are located by their text, so a reworded template moves them.
4. Round-trip it before trusting it:

```powershell
. scripts\Build-FromTemplate.ps1
$w = Expand-Docx -Path <template>
(Test-DocxPackage -WorkDir $w).Ok      # expect True
```

Then open the repacked file in Word once and confirm it does not prompt to repair. A package that validates can still be one Word rejects; only Word settles that.

---

## The day-count patch — 21 August 2026

A second RTO decision, applied by `scripts/Patch-TemplateDayCounts.ps1`. Both templates shipped **45 days** for results; the RTO's newest artefact says **14**.

| Point | Shipped | Now |
|---|---|---|
| Results | 45 days | **14 days** |
| Late submission | 14 (UAT) / 15 (recipe) | **14 days** |

`MVC_Assessment_Template_Combined_PE_KE_v2.2.predaycount.docx` and `MVC_Recipe_Workbook_Template.predaycount.docx` hold the pre-patch originals.

**Why at source rather than at build time.** The figure was being patched in every build, in every document. A value fixed in the template is fixed once; a value patched at build time is a rule every future builder has to remember.

It also has to agree with `assets/branding.mvc.json` and `assets/house-profile.mvc.json`, because **two executable checks read it** — the rendered sweep and the `DayCounts` gate. When the profile said 45 and the artefact said 14, the sweep *failed a correct document* and the cover-sheet check reported the clause *missing*. Profile, template and artefact now agree.

---

## The margin patch — 21 August 2026

The third and last of the template patches, applied by `scripts/Patch-TemplateMargins.ps1`. It closes the table-overflow defect.

**The defect.** House tables are **9638 dxa**. Both templates had 1440 twip side margins on A4, giving a **9026 dxa** text column. Every table therefore sat 612 twips — about **1.08 cm** — wider than the column it was in, and bled past the right margin. It was in the RTO's own artefacts too, so it was reproduced faithfully for a long time before anyone measured it.

**The RTO's decision: widen the margins.**

| | Before | After |
|---|---|---|
| Side margins | 1440 | **1134** |
| Text column | 9026 | **9638** |
| Tables off-column | 27 (UAT) + 46 (recipe) + every generated table | **0** |

1134 each side makes the text column exactly the house table width. The alternative — narrowing every table to 9026 — would have meant recomputing every column width in the builder and both templates, and would have made the documents visibly narrower than the RTO's existing set.

**Two edits, both needed.** The margin change alone fixes the UAT template (whose 27 tables are all already 9638) and every table the builder generates. The recipe template's 46 tables were all 9026, so they were widened to match, with the 612 added to each table's **last** column so every other measured width is preserved.

`*.premargin.docx` holds each template as it was.

**The cover sheet was the risk** — it is held to exactly one page by compression, and this changes the page geometry under it. Verified after rebuilding: all four documents still report *"Cover sheet: one page, every clause present."* A wider column gives more room per line, so it held.

**If `tableWidthDxa` ever changes, the margins must change with it.** Both live in `assets/house-profile.mvc.json`, under `formatting`, with a note on each pointing at the other.
