# Gates — what blocks, what warns, and why

Four executable gates, plus the shared readability gate. All five run on every build, and all five block.

| Gate | Script | Runs on |
|---|---|---|
| Guide rules | `Test-GuideRules` | the built `.docx`, or its unpacked working directory |
| Deck rules | `Test-DeckRules` | the built `.pptx`, or its working directory |
| Readability | `Test-Readability` (assessment skill, unchanged) | the built `.docx` |
| Figure registry | `Test-FigureConsistency` | sources at Stage 4 and before every Stage 7 re-render; rendered text extracts too |
| Stage ledger | `Test-StageLedger` | the build directory, in Stage 8 |

Every rule below exists because the RTO's own artefacts demonstrated the failure. Nothing here is theoretical.

## What none of these gates can see

**Sections 1 to 8 are all structural.** Widths, ordering, numbering, counts, cross-references, package validity. They read XML, not meaning.

**A fabricated fact passes every one of them.** A temperature no source supports, a legal duty that does not exist, a real figure lifted from the wrong category of food — each is well-formed XML in a correctly sized table with valid numbering, and every gate in this file reports it clean.

On 27 August 2026 this guide shipped teaching **75 degrees Celsius as a critical limit** for a braised beef dish. The Food Standards Code sets no such requirement: 75 °C is FSANZ's *recommendation*, and it applies to poultry and to minced or rolled meat, not to a whole-muscle cut. Both gates passed the document, twice, and the readability gate passed it as well.

Catching that is Stage 6's job, and **section 10 exists to stop Stage 6 being skipped** — which is how the defect reached the page in the first place.

---

## 1. Content width — blocking

**The rule.** Content width is `pgSz.w - pgMar.left - pgMar.right`, derived from the document's own margins, never assumed. Every full-width table must equal it exactly.

**The evidence.** Three sources disagreed and two agreed:

| Source | Says |
|---|---|
| Study Guide spec 5.1 | margins `1440 / 849 / 1440 / 1440`, and "CW = 9617 DXA — all full-width tables and column-width arrays must sum exactly to 9617" |
| Delivered `SITHPAT018-Learner Resource.docx` | all **361** full-width tables are 9617 DXA |
| `MVC_Learner_Guide_Template.docx` as shipped | `pgMar right="1440"`, which gives CW **9026** |

`11906 - 1440 - 849 = 9617` exactly, so the spec's arithmetic is deliberate and the delivered guide's tables were built to it. What the delivered guide did not do is set the margin — so **every table in it overhangs the right margin by 591 DXA, a little over a centimetre.**

**The decision.** Patch the template's right margin to 849 (`scripts\Patch-GuideTemplateGeometry.ps1`, idempotent, keeps `*.premargin.docx`). All three sources then agree.

**Why the gate derives CW rather than hard-coding 9617.** A hard-coded constant would have passed the delivered guide, because its tables *are* 9617. Deriving from the page's own margins is what exposed the mismatch, and it keeps working if the RTO changes the geometry again.

A table **narrower** than CW is a warning, not a failure — an inset table is sometimes deliberate — but only when it is within 800 DXA, close enough to have been meant as full width.

---

## 2. List numbering — blocking on structure, warning on ratio

**The rule.** Every separate numbered list needs its **own fresh `numId`** mapped to the shared decimal `abstractNumId`, each with `<w:lvlOverride><w:startOverride w:val="1"/></w:lvlOverride>`, at a consistent `720/360` indent.

**Why.** Reuse one `numId` across genuinely separate lists and Word numbers them continuously: the second Self-Check set starts at 5, the third at 7. Give every *item* its own `numId` and the opposite happens — every question renders as "1.".

**A logical list is one numbered set even when blank answer-space paragraphs sit between its items.** Self-Check questions with writing space between them share one `numId` and number 1, 2, 3, 4. Break to a new `numId` only when a non-empty, non-list paragraph — a heading, a box, running prose — separates two sets.

**The benchmark.** The delivered guide carries **164 distinct `numId`s, every one with a `startOverride`**, across 857 list references. That is the shape a correct guide of this size has, and it matches the spec's "150–200". `Test-DocxPackage` fails an undeclared or duplicated `numId`; `Test-GuideRules` warns when the ratio of references to distinct ids is high enough that lists must be running on.

**Do not auto-number items that carry their own label.** An item whose text begins `KE1.` or `PC 1.1` must not also sit in an auto-numbered list, or it renders "1. KE1. …". Render those as plain labelled paragraphs, and never hard-code the marker in item text.

---

## 3. Word floors — blocking

| Floor | Scope |
|---|---|
| 3,000 words | counted body prose per Topic |
| 800 words | each PC sub-section's *Underpinning knowledge* block |

**What counts.** Paragraphs **not inside a `<w:tbl>`**. In this house style every callout, sign-off block, worked-example table and answer space *is* a table, so that single rule reproduces the spec's whole exclusion list — table cells, readability boxes, self-check lists, answer guides, "My summary" lines and banner boilerplate — without maintaining a list of box names.

**Verified against the delivered guide**, whose eight Topics measure 3,770 / 3,883 / 4,019 / 4,274 / 4,608 / 5,138 / 5,330 / 5,351. All pass. The method is sound.

**The 800-word floor is the one that bites.** The same delivered guide's Underpinning knowledge blocks measure **96 to 242 words** — 31 of them under the floor. Checked by reading one: 237 words of prose plus a 133-word table, against a floor of 800. The spec introduced this floor in v3.0 and the delivered guide predates it. **Expect this to be the expensive part of the build, and do not meet it with padding** — the floor exists to force real subject teaching, so a block that reaches 800 words by restating the criterion three times fails the point even though it passes the count.

---

## 4. Page breaks — blocking

Every Topic heading and every PC sub-section heading carries `pageBreakBefore`. `GHeading -PageBreakBefore` does it.

**Use `pageBreakBefore` on the heading, not a standalone break paragraph.** A standalone break lands mid-page whenever the preceding content exactly fills the sheet. And **never emit an empty spacer paragraph immediately before a heading that carries `pageBreakBefore`** — where the preceding content nearly fills the page the spacer tips over and the forced break then produces a genuinely blank page.

Bind headings with `keepNext` at **paragraph** level, not only on the style. Keep callouts whole with `cantSplit` on the box row. **Never add `cantSplit` to ordinary body content** — the assessment house documents use none and that gate blocks it; the callout row is the carve-out, and it is a table row, not a paragraph.

---

## 5. Forced row heights — blocking except in answer space

Callout consistency comes from **content length**, not forced height. Do not add `<w:trHeight>` or `hRule` to equalise callout rows.

The exception is a **learner answer-space box** — "My summary" writing cells, sign-off rows. Those heights are intentional and are left alone. The delivered guide carries exactly one `trHeight`, which is the correct number for a guide with one answer-space box.

---

## 6. Document control — blocking, but only on structure

The spec forbids a document-control **table** or approval/date **fields** in the guide body. Document control is applied later, in novacore.cloud.

**It does not forbid the words**, and the distinction matters. In this house style **a callout is a table**, and the delivered guide carries a Note box whose text explains that document control is applied separately. A keyword sweep reports that correct paragraph as a defect; so does a naive "a table containing two control labels" test.

The gate therefore requires **structure**: four or more cells, and at least two of the control labels appearing as **short cell values** (under 40 characters) rather than as words inside a paragraph. A real control table is a grid of label/value cells; a callout is one cell of prose.

**Footers are reported, never failed.** The spec says not to build one; the delivered guide ships a full document-control footer (`Doc# 4133 Ver# 1.3 Next Review: 05-08-2028`). Where the RTO's artefact and the spec disagree, the artefact is the authority and the divergence is recorded for the RTO to settle.

---

## 7. Question cross-reference — blocking, both directions

Pass `-QuestionsInPack` and the gate reconciles:

- **Invented references** — the guide cites a question the pack does not contain. This is the most damaging defect this document type can ship: a learner revises for a question that is not on the paper.
- **Uncovered questions** — a question in the pack that no topic prepares. A coverage gap.

Neither is a warning. Omit `-QuestionsInPack` and the gate says the rule was skipped rather than passing silently.

---

## 8. Deck rules — blocking

| Rule | Detail |
|---|---|
| **Package integrity** | Every part well-formed XML, every slide reachable, every content-type override present |
| **Residual placeholder text** | Template phrases harvested from the template itself |
| **Slide numbering** | Printed number equals deck position |
| **Slides per Topic** | 15 minimum |
| **Speaker notes** | On every teaching, case-study, assessment-link, figures, process and table slide |
| **Assessment chip** | Warned, not blocked, on PC teaching slides |
| **Overset text** | Warned above 420 characters in one shape |

**Package integrity runs first and is not optional.** Splicing raw OOXML as text is the whole build method, and an unbalanced element is what it produces. PowerPoint reports that only as *"the file is corrupted and unreadable"*, naming neither the part nor the tag. This gate names both. `Save-Deck` runs it **before writing**, so a broken package never reaches disk.

The failure that motivated it: a non-greedy `<a:rPr\b.*?(?:/>|</a:rPr>)` looks correct and is not. `<a:rPr>` routinely contains self-closing children — `<a:solidFill><a:srgbClr val="234B8C"/></a:solidFill>` — so the `.*?/>` arm matches the inner `<a:srgbClr/>` and returns a truncated fragment. Use `Get-XmlFragment` (in `Xml-Scan.ps1`), which walks the start tag honouring quoted attributes and counts nested opens against closes.

**Slide numbering is not cosmetic.** The template's footer number is **literal text, not a `slidenum` field**, so a cloned slide keeps the exemplar's number. The delivered `SITHPAT018_Delivery_PowerPoint.pptx` prints the wrong number on **19 of its 39 slides**. Which shape holds the number is declared per layout in `deck-layouts.mvc.json` as `numberSlot`, because it is not always the last text shape and two layouts legitimately have none — guessing turns a correct thank-you slide into a reported defect.

**Residual placeholder text is harvested, not listed.** `Get-DeckPlaceholderPhrase` reads the template's own strings, so the vocabulary cannot drift from the template it polices. Footer, RTO and tagline strings are excluded — they are supposed to survive. Layouts marked `verbatim` in the profile (thank-you, brand reference) are exempt: their template text *is* the delivered text.

---

## 9. The brand-crossover carve-out — read before running the assessment sweep

The assessment skill's `branding.mvc.json` lists `2A364E`, `2490CC`, `84549C`, `F05430` and `FCA860` as **forbidden tokens** for an MVC document, and runs a crossover sweep that fails on any of them. That is correct for an assessment tool.

**It is wrong for a Learner Guide**, and running it unmodified fails every correct one.

Study Guide spec v3.3 deliberately adopted the ACI callout palette for MVC guides, hex for hex, so that an MVC guide and an ACI guide are visually identical at callout level. The approved `MVC_Learner_Guide_Template.docx` contains `2A364E` 9 times, `2490CC` 18, `84549C` 6, plus `3CC0D8`, `189C48`, `E43C30`, `F09018` and `C9D2DC` 156 times.

**The carve-out is scoped, not general.** These hexes are legal **inside callout boxes and the icon legend only**. They must never appear on the cover, a heading, a banner band, a table header row, a bullet or a section rule — those stay on the MVC logo palette (`234B8C`, `2F60B4`, `F09C0C`, `C7D0DD`). Do not let ACI navy `2A364E` leak into a heading, or MVC navy into a callout.

**And note the fork.** The delivered `SITHPAT018-Learner Resource.docx` contains **zero** of these hexes and **no emoji icons at all** — it is built entirely on the MVC palette in the older no-icon style. Template and spec agree with each other; the delivered guide predates them both. Resolved in favour of the template as the approved brand source, but **it is a visible change from the last guide the RTO shipped, and the user should be told before the build, not after.**

---

## 10. Stage ledger — blocking

`Test-StageLedger`, run in Stage 8 before anything is verified or exported.

Stages 5 and 6 are judgement stages: an agent reads the documents and reports what is wrong with them. **Nothing in the file system changes when they are skipped.** Every structural gate still passes, the artefacts still build, and the folder still looks finished. So the fact that a stage ran is recorded, and delivery checks the record.

| Fails when | Because |
|---|---|
| A required stage has no record | It either did not run or was not recorded, and delivery cannot claim it either way |
| A blocking stage is recorded `skipped` | `skipped` is an honest status and it is allowed — it just does not ship |
| Stage 4b, 5 or 6 predates the newest Stage 4 or 7 record | Those stages re-render from a fresh template. A verdict taken before the last render describes a document that no longer exists |
| Stage 6 has no `verdict` | An audit without a stated judgement is not an audit |
| Stage 6's verdict reads `Not Compliant` | Remediate and re-audit |

Stage 7 is deliberately **not** required. A build with no findings needs no remediation round, and requiring one would push builds into inventing work.

**Record each stage as it finishes, never from memory at the end.** A ledger written at the end records what was intended, which is exactly the thing this gate exists to distrust.

```powershell
. "$SkillDir\scripts\Stage-Ledger.ps1"
New-StageLedger -BuildDir $out -Unit $code | Out-Null
Add-StageRecord -BuildDir $out -Stage '6' -Name 'Clean-room audit' `
                -Status pass -Findings 3 -Verdict 'Partially Compliant'
Test-StageLedger -BuildDir $out | Write-StageLedgerReport
```

**The evidence.** The 27 August 2026 SITHKOP013 build ran Stage 5 not at all and reduced Stage 6 to a cross-reference check. Both gates passed, the readability gate passed, and the guide shipped with a fabricated legal requirement in its food-safety topic. The defect was found because the user asked whether a compliance check had been done — not by anything in this pipeline.

---

## 11. Figure registry — blocking

`Test-FigureConsistency`, run at Stage 4 on the sources, again on the rendered text extracts, and **before every Stage 7 re-render**. Rules live in the build directory's `figures.json`, locked at Stage 2.

| Fails when | Because |
|---|---|
| A `forbid` string — **or any variant of it** — survives anywhere | A stale figure in one place contradicts the corrected figure everywhere else |
| A `require` string appears nowhere | The correction claimed is a correction that did not land |
| An `assessorOnly` string reaches any learner-facing source | Benchmark leakage — the one defect that destroys the assessment it supports |
| A `deckMust` term is absent from deck-facing text | A corrected guide beside an uncorrected deck is worse than either alone |

**Variant matching is the point, not a nicety.** Forbidden and assessor-only strings match digits *and* their English word forms, spaces *and* hyphens. The evidence: a leaked benchmark capacity was "fixed" by removing the literal string `20 gastronorm` — and survived a full audit round as `twenty gastronorm`, `20-tray`, `fit inside 20` and `6 of 20`. A literal-string sweep is not an enumerating check, and only an enumerating check ends a remediation round.

**The registry is also why `Set-DiagramSpecs` must be a reader, not an author.** The same build held its Route B diagram content as hand-typed copies inside the spec-writer script; three rounds of spine edits never touched them, and Figure 2.1.4 taught a superseded calculation two audit rounds after the prose was corrected. Specs live on the spine's visual entries; the spec-writer copies spine → manifest by slot and **refuses** when a slot has no spine spec, because patching the manifest by hand is how a second source of truth is born.

**The evidence.** Rounds 1–3 on SITHKOP013, 27 August 2026: 40 findings at round 1; round 2 fixed prose and left the deck disagreeing on every corrected figure, and introduced benchmark leakage; round 3 fixed one spelling of the leak and missed four. The registry gate, run before round 4, enumerated all 16 residual locations in one pass.
