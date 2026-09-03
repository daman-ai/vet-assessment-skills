# Gates — what blocks, what warns, and why

Every rule in this file exists because a real artefact demonstrated the failure. Nothing here is theoretical. Sections 1 to 11 were measured against the RTO's own delivered documents; sections 12 onward against a build that passed every gate in sections 1 to 11 and was still not fit to release.

Five executable gates used to be the whole set. They are not any more. One build passed all five, passed two clean-room audit rounds, and was then returned **"Not Compliant - not for release"** at a third round against defects that had been sitting in machine-readable form on disk since hour one. Sixty-five of its seventy-seven findings were mechanically detectable, from data that already existed, earlier than the stage that actually caught them. Sections 12 onward are the checks that close that gap.

**Nothing was removed, weakened or made optional to make the build faster.** Every original gate keeps its original invocation at its original stage. Where a check below is described as "moved earlier", what is added is an EARLIER RUN on data that already exists; the later run stays exactly as it was, on the artefact it always read. A spine check and a rendered check are not redundant - they make different claims, and one build proved they can differ: the guide went from zero brand-crossover hits to 177 foreign header rows and 608 foreign light fills through artwork placement alone, with no spine change at all.

### The five original gates - unchanged, at their original stages

| Gate | Script | Runs on |
|---|---|---|
| Guide rules | `Test-GuideRules` | the built `.docx`, or its unpacked working directory |
| Deck rules | `Test-DeckRules` | the built `.pptx`, or its working directory |
| Readability | `Test-Readability` (assessment skill, unchanged) | the built `.docx` |
| Figure registry | `Test-FigureConsistency` | sources at Stage 4 and before every Stage 7 re-render; rendered text extracts too |
| Stage ledger | `Test-StageLedger` | the build directory, in Stage 8 |

### The full gate set, by stage

Sections 1 to 11 are the original five gates and are unchanged. Sections 12 onward are everything added afterwards. Every gate blocks unless the Blocks column says otherwise, and the Section column says where to read its rule, its false-positive control and the failure it exists to catch.

**Read the Script column honestly.** A name marked **NOT YET IMPLEMENTED** is a specification: no file of that name exists under `scripts\` and no function of that name is defined in any script there (checked against the directory listing on 3 September 2026). The section in the last column says what performs that check today, and where the answer is *nobody*, it says so. A name marked **BEING IMPLEMENTED** is a script a sibling build is writing at the time of this revision; treat it as absent until it is on disk. Nothing marked is removed from this file, because the plan is to build it - but a rule nobody can execute must say so, or a builder reads this table as a list of things that ran. *The failure:* a builder read the previous version of this table, recorded Stage 0 as `pass`, and had run two of its eight gates.

| Stage | Gate | Script | Blocks | Section |
|---|---|---|---|---|
| S0-RTO | RTO profile pack resolves and validates | `scripts\Get-RtoProfile.ps1 -Rto <id> -Check` (`Assert-RtoProfile`) | yes | 29 |
| 0 | Renderer contract compiled into the spine schema | `Assert-RendererContract` - NOT YET IMPLEMENTED; the write-time arm is `scripts\Test-SpineRead.ps1` | yes | 21 |
| 0 | Palette resolves as a total function over a closed role enum | `Get-BrandPalettePairs` in `Set-ResourceBrand.ps1` throws on an unresolved role (no standalone `Resolve-Palette` yet) | yes | 29 |
| 0 | Every styled sub-skill accepts an injected palette | `Assert-DownstreamPalette` - NOT YET IMPLEMENTED | yes | 29 |
| 0 | Every gate fails on a planted defect that is verified to have landed | `Assert-GateFixtures` - NOT YET IMPLEMENTED; partial cover from `scripts\Test-Pipeline.ps1` and `Check-Identity.ps1 -SelfTest` | yes | 35 |
| 0 | Gate hygiene, portability and allow-list discipline | `Assert-GateHygiene` - NOT YET IMPLEMENTED | yes | 35 |
| 0 | Long-stage output contract declared | `Assert-LongStageOutputContract` - NOT YET IMPLEMENTED | yes | 36 |
| 0 | Generation endpoints probed for quota | `scripts\Probe-GenerationEndpoints.ps1` | **no** | 30 |
| 1 | One canonical corpus, every pack document extracted exactly once | `Assert-CorpusComplete` - NOT YET IMPLEMENTED | yes | 20 |
| 1 | Pack self-consistency hazards raised and dispositioned | `Assert-PackSelfConsistency` - NOT YET IMPLEMENTED | yes | 20 |
| 1 | Assessor-only shingle set derived | `scripts\Check-FigureLeakage.ps1` derives it from the corpus on every run; there is no separate `-Derive` step | yes | 14 |
| 2 | Registry seeded with authority class and resolving provenance | `Assert-Provenance` - NOT YET IMPLEMENTED | yes | 18 |
| 2 | Withhold register, `grids.json`, gate-only assessor cells and one agent pack per sub-section, all DERIVED from the assessed response cells | `scripts\New-WithholdRegister.ps1` | yes | 16 |
| 2 | Identifier namespaces do not collide with the pack's | `Assert-IdentifierNamespace` - NOT YET IMPLEMENTED | yes | 28 |
| 3 | Every agent write validated against the compiled schema | `New-SpineWriter` - NOT YET IMPLEMENTED; `scripts\Test-SpineRead.ps1` detects after the write | yes | 21 |
| 3 | Spec renderability, exact arm, at write time | `Assert-SpecRenderable` - NOT YET IMPLEMENTED | yes | 22 |
| 3b exit | Prompt lint, before any generation spend | `scripts\Assert-PromptLint.ps1` | yes | 30 |
| 3c | THE SPINE GATE BAND - every check whose inputs are already on disk, fanned out | see section 12; `Run-SpineGates` - NOT YET IMPLEMENTED, members run by hand; shared helpers in `scripts\Lib-GateCommon.ps1` | yes | 12-28 |
| 3c | Readability, count-based arm, on the spine's prose fields | `Test-Readability` spine arm - NOT YET IMPLEMENTED; no wrapper feeds it spine fields | yes | 11b |
| 3d | Figure sheet review (judgement, narrow) | reader, not a script | yes | 13 |
| 3d | Figure sheet CUT from the spine and fingerprint-stamped | `scripts\New-FigureSheet.ps1` | yes | 31 |
| 4 | Every blocking gate from one entry point, every parameter threaded and printed | `scripts\Run-Gates.ps1` | yes | 33 |
| 4 | Extract stamping and the channel manifest | `scripts\Get-DocText.ps1` stamp (FIGURES / CHANNELS / SOURCE) | yes | 31 |
| 4b | Readability, on the rendered document | `Test-Readability` | yes | 11b |
| 4c | Brand applied, and the mark PROVED on every artefact | `scripts\Check-Identity.ps1` (`Assert-BrandCrossover`) | yes | 29 |
| 5 / 6 | Review band (personas, flow pass, clean-room audit) | judgement | yes | 10 |
| 6b | Finding arbitration before any work order | `scripts\Test-Finding.ps1` (specified as Assert-FindingProvenance) | yes | 19 |
| 7 | Enumerate before fixing | `Assert-EnumerateBeforeFix` - NOT YET IMPLEMENTED | yes | 32 |
| 7 | Figure sheet regenerated from the corrected spine | `scripts\New-FigureSheet.ps1` | yes | 31 |
| 7b-i | Every generated image reviewed before it is placed | judgement, ledgered as `7b-i` | yes | 30.3 |
| 7b-ii | Resolved palette passed into the artwork sub-skill | `Assert-DownstreamPalette` - NOT YET IMPLEMENTED | yes | 29 |
| 7c | FULL re-gate after the last mutation | `Assert-FullRegateAfterMutation` - NOT YET IMPLEMENTED as a whole-set assertion; the set is run by hand, SKILL.md Stage 7c | yes | 33 |
| 7c | Placed drawings: alt text, figure numbering, caption-to-slot | `scripts\Check-Figures.ps1` | yes | 33 |
| 7d | Confirming audit read, scoped to what placement changed, images re-checked against final content | judgement, with a verdict | yes | 30.3, 31 |
| 8 | Ledger integrity, staleness proved from files, figure sheet current | `Test-StageLedger`; `scripts\Assert-RenderDelta.ps1` + `Test-StageLedger` per-topic rule | yes | 34 |

---

## Rules that bind every gate in this file

These five are not gates. They are the conditions under which a gate's green result may be believed at all. Four of them exist because a gate printed green over a live defect.

**1. DERIVE the check-set; never hand-list it.** Any gate that checks a *set* of values - hexes, identity strings, forbidden terms, required terms, question references, channel names, counts - must derive that set from the same source of truth the production code uses. A hand-typed list is a second source of truth, free to drift from the first, and it always drifts silently. *The failure:* a brand-crossover sweep listed three palette hexes by hand out of the nine its own colour map moves, omitted the light fill and both borders, and printed **"no crossover" over 766 real occurrences** of the other brand's fills. It had also only ever been run on one of the two delivered artefacts, so its report's claim about the delivery set was true of half of it. Every gate must additionally **print the size of the set it checked and name the map it derived it from**, so a check-set of three where the map holds nine is visible in the log.

**2. PLANT the defect before you believe the pass.** No gate's clean result is trusted until the gate has been shown to FAIL on a seeded-defect fixture. *The trap, and it is the reason this rule is worded the way it is:* a plant that lands somewhere the defect cannot occur proves nothing and passes. One build's first plant attempt was a no-op - it wrote into a file the gate does not read - and the gate reported clean, which was recorded as evidence the gate worked. **So the plant itself must be verified to have landed** (read it back, confirm the defect is present in the exact channel the gate scans) before the gate is run against it. Fixtures live with the skill, not in a build directory, and every promoted gate has one.

**3. An allow-list lives in the versioned registry, beside the rule it weakens, with a written reason per entry.** Never as a script parameter default, never in a hashtable inside the script, and never without a reason a reader can audit. Every allow-list entry is surfaced to Stage 6 as evidence, because an allow-list nobody can see is a way of turning a gate off quietly. *The failure:* a mirror gate shipped with its allow-list as `$Allow = @('4.1.4')` in the parameter block and its reasons in a separate in-file hashtable, where no audit would ever read them.

**4. A gate reports the anchor; a human decides.** Where a check is structural but the verdict needs a reader - is this mirrored grid a leak or a legitimate worked exemplar? - the gate's job is to find the candidates mechanically and early, name the file, the field and the slot, and stop. It does not clear and it does not condemn. The adjudication is a named stage (3d for figures, 6b for findings) and the decision is recorded with its reason. This is what keeps a fuzzy check from becoming a gate everyone learns to route around.

**5. No gate may contain a literal unit code, RTO code, CRICOS code, provider number or six-digit hex.** Identity strings and palette come from the branding profile, counts from the build contract, filenames from the unit code, question references from the pack's own content. This skill is shared across RTOs, brands and units; a gate that hard-codes one build's values passes every other build vacuously. *The failure:* ten build-local check scripts hard-coded one unit code, one brand and one build's expected counts, so none of them could ever be promoted.

**A build-local `Check-` or `Test-` script that is not a copy of a skill script must record why a new gate was needed.** That record is how a gate written under remediation pressure gets promoted into `scripts\` instead of being lost with the build directory - which is what happened to the mirror and leakage sweeps documented in sections 13 and 14.

## What none of these gates can see

**Sections 1 to 8 are all structural.** Widths, ordering, numbering, counts, cross-references, package validity. They read XML, not meaning.

**A fabricated fact passes every one of them.** A temperature no source supports, a legal duty that does not exist, a real figure lifted from the wrong category of food — each is well-formed XML in a correctly sized table with valid numbering, and every gate in this file reports it clean.

On 27 August 2026 this guide shipped teaching **75 degrees Celsius as a critical limit** for a braised beef dish. The Food Standards Code sets no such requirement: 75 °C is FSANZ's *recommendation*, and it applies to poultry and to minced or rolled meat, not to a whole-muscle cut. Both gates passed the document, twice, and the readability gate passed it as well.

Catching that is Stage 6's job, and **section 10 exists to stop Stage 6 being skipped** — which is how the defect reached the page in the first place.

**Sections 12 onward move the boundary, but they do not move that class.** They make mechanical a large body of work that used to need a reader - mirrored answer grids, assessor-only leakage, unsourced figures, contradictory clause numbers, withheld values reprinted two pages later - and they run it on the spine, hours before a document exists. What they cannot do is decide whether a well-sourced sentence teaches something true. That still belongs to Stage 5 and Stage 6, whose scope is untouched. What changed is that those readers now arrive at a document a script has already cleaned, carrying the figure sheet, the provenance ledger, the cross-reference index and the pack hazard list, so their attention goes to truth rather than to hunting. And section 31 exists because a reader can be handed a document with no figures in it and not be told - which is how three audit rounds all failed to read a single figure.

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

## 7. Question cross-reference — blocking, both directions, and the gate FAILS without its input

Pass `-QuestionsInPack` and the gate reconciles:

- **Invented references** — the guide cites a question the pack does not contain. This is the most damaging defect this document type can ship: a learner revises for a question that is not on the paper.
- **Uncovered questions** — a question in the pack that no topic prepares. A coverage gap.

Neither is a warning. **And omitting `-QuestionsInPack` is not a way of not being checked: the gate now FAILS, and names the parameter.**

**This section used to say the gate "says the rule was skipped rather than passing silently", and that was wrong on the only point that matters.** What the gate actually did was write `assessment cross-reference skipped - no -QuestionsInPack given` into its **info** list and return `Ok = $true`. An info line is not a failure. A caller who simply left the parameter off saw `PASS`, printed it into a report, and had reconciled the question references in neither direction.

**It is the same disease as every other gate in this file that printed green over a live defect, one level down**: a check believed because it was green, over a rule that never ran. The clearest instance is in the figure registry, section 11. `Test-FigureConsistency`'s rendered-text arm sat behind an optional `-DocText`; `foreach ($p in @($DocText))` over `$null` iterates nothing and exits 0; and the runner never passed it for an entire build — so **every "figure registry PASS" that build reported was the source arm only, and no rendered artefact was registry-gated at all.** That arm is now derived by the runner itself and fails when its input is missing. This rule is the same fix, applied to the same shape wherever it appears.

### The rule this generalises to, for every gate in this file

**A blocking rule whose input is absent FAILS, and names the input.** It never reports the omission as information, and it never returns a pass.

**`-AllowPartial` is the only way past, and it is deliberately expensive to use:**

| | |
|---|---|
| What it does | Turns each unrunnable blocking rule into a loud `PARTIAL RUN` warning, and returns every one of them on the result's `.Partial` |
| What the report prints | `PARTIAL RUN - n blocking rule(s) checked nothing`, each named, and the verdict reads `PASS - PARTIAL, n rule(s) not run` rather than `PASS` |
| What the caller must then do | `Add-StageRecord -Partial $result.Partial -Note '<why>'`. **The ledger rejects a partial record with no note**, on the same rule as an allow-list entry (rule 3) |
| Where it surfaces | The build report's own line: *every gate rule that did not run, and why* |

An omission is then **a decision somebody signed**, which is a different object from an absence nobody saw. That distinction is the whole of this section.

**The guide gate's other two degrading rules are covered by the same switch**: no readable page geometry means the content-width rule derived nothing (section 1), and no `Topic N` heading means the 3,000-word floor measured nothing (section 3). Both used to be warnings. Both now fail.

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

### Four of these rules sat behind optional parameters, and the gate FAILS without them

Section 7's rule applies here four times over. Each of these inputs carries a blocking rule, and the rule does not run without it:

| Parameter | The rule it carries | What the gate used to do without it |
|---|---|---|
| `-TemplatePath` | Residual placeholder sweep | `placeholder sweep skipped - no -TemplatePath given` into **info**, and PASS. The vocabulary is harvested from the template, so with no template there is no vocabulary and the sweep compares against nothing |
| `-Plan` | Speaker notes, assessment chips, and the 15-slides-per-Topic floor | `per-topic count and chip rules skipped - no -Plan given` into **info**, and PASS. Nothing knows which slide is a teaching slide, so three rules pass on nothing and a trainer finds out in front of a class |
| `-NumberSlotByLayout`, **with** `-Plan` | The printed slide number | Fell back to guessing that the **last text shape** holds the number, on a template where **two layouts legitimately have none** — so it could report a correct thank-you slide as a defect and miss a real wrong number in a slot that is not last. A rule running on a guess is not the rule |
| `-Rto`, `-Cricos` | Document-property identity | `document properties name RTO nnnnn - confirm it is this RTO (pass -Rto to make this blocking)`. A gate that asks the caller to confirm it themselves is not a gate. The approved template was cloned from another RTO and still carried that RTO's code in `docProps`, where nothing on a slide shows it and every exported PDF carries it |

All four now fail, naming the parameter, unless `-AllowPartial` records the omission. **The stage that runs the complete gate set threads every one of them**, from the RTO profile pack — `-TemplatePath $rtoProfile.DeckTemplate`, `-NumberSlotByLayout (Get-DeckNumberSlotMap -Profile $rtoProfile.DeckLayouts)`, `-Rto $rtoProfile.RtoCode`, `-Cricos $rtoProfile.CricosCode` — and so does the 7c re-gate, which is the same call with `-AfterArtwork` on the guide side. See SKILL.md Stage 4 and Stage 7c.

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
| A stage is recorded `n-a` with no note | A stage that does not apply must say why it does not apply. `n-a` is the honest answer for a stage that genuinely cannot run, and it is also the easiest way to rubber-stamp one that can |
| A record carries partial gate rules with no note | A gate run with `-AllowPartial` left blocking rules unrun (section 7). That is allowed and recorded, and it costs the same written reason an allow-list entry costs |
| Stage 4b, 5 or 6 predates the newest Stage 4 or 7 record | Those stages **re-render** from a fresh template. A verdict taken before the last render describes a document that no longer exists |
| Stage 7c or 7d predates the newest 7b or 7c record | **Placement** is a mutation of the page, and what follows it must postdate it — see section 34 for why Stage 5 is deliberately not on this line |
| No Stage 6 or 7d record postdates the newest placement | No build ships on a verdict issued against a document that had no figures in it |
| Stage 6 or Stage 7d has no `verdict` | An audit without a stated judgement is not an audit, and a confirming read that confirms nothing in particular is not a confirmation |
| Stage 6's or 7d's verdict reads `Not Compliant` | Remediate and re-audit |
| The figure sheet's stamped spine fingerprint does not match the spine | Section 31. Every reviewer downstream of a stale sheet read figure content the document no longer carries, while the ledger recorded that the figures were read |

**The required set is `$script:LedgerRequired` in `Stage-Ledger.ps1`, and it is the only copy.** Read it from the script rather than transcribing it, because a transcribed stage list is how this gate came to enforce a pipeline that no longer existed: the rewrite added `3c`, `3d`, `4c`, `6b`, `7c` and `7d` as blocking stages and added none of them here, so **a build that skipped all six passed `Test-StageLedger` and delivered** — no spine gate band, no figure adjudication, the brand never proved, a false finding straight to a work order, no post-placement re-gate, and no verdict ever issued against a document containing figures. `7b-i` — generate and review the artwork — was added at the same time for the same reason (section 30.3). The list now reads:

```
0  1  2  3  3b  3c  3d  4  4b  4c  5  6  6b  7b-i  7b  7c  7d  8
```

Stage 7 is deliberately **not** required. A build with no findings needs no remediation round, and requiring one would push builds into inventing work. Stage `7b` is required but is **not** blocked when recorded `skipped`: with no API key, or where the user declines the artwork spend, a build legitimately delivers with the prompts in place and says so.

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

**And the arm that did not run at all.** The rendered-text arm is an optional `-DocText`, and `foreach ($p in @($DocText))` over `$null` iterates nothing and exits 0. The runner simply never passed it, for a whole build — so **every "figure registry PASS" that build reported was the source arm only**, and the variant-aware sweep never once ran against a rendered artefact. The runner now derives both extracts itself so the arm cannot be dropped, and the gate fails when its input is missing. This is the origin of section 7's general rule, and it is worth remembering that the defect was invisible: the gate printed exactly what a fully successful run prints.

---

## 11b. Readability — blocking, and it GAINED a run

`Test-Readability`, the assessment skill's, **unchanged and never forked**. Same 300-character paragraph cap, same real-lists rule, same two-round maximum, same editing target: the agent edits the **spine**, never the document, and never touches a figure, an assessed term, a count or a threshold.

**It is one of the five original gates and it had no section in this file** — which is how a rule gets quietly reinterpreted, so here it is with the rest.

| | |
|---|---|
| **Runs at** | 3c (count-based arm, on the spine's prose fields), **4b** (the original run, on the rendered document), and again at **7c** after placement |
| **Blocks** | Yes, at every one of those positions |
| **Ledger** | Stage `4b`, required, blocking, and stale if it predates the newest render |

**The 3c run is specified, not yet implemented.** `Test-Readability` takes an unpacked `.docx` (`-WorkDir`, `-Part`) and reads its XML; no wrapper yet feeds it the spine's prose fields. Until one exists, this check is performed by nobody before the render, first readability detection is the Stage 4b run on the rendered document, and the artwork-prompt confound that run scripts around is still live.

**The 3c run is an ADDED run, not a moved one, and the distinction is the whole point.** On the spine, prompt text and body prose are separate fields and cannot be confused — which deletes outright the artwork-prompt confound the rendered gate had to script around by stripping prompt paragraphs from a copy of the file. **The Stage 4b run on the rendered document is untouched**, because a spine measurement and a rendered measurement make different claims: the renderer joins, wraps, tables and captions the prose, and a document can fail one and pass the other. Nothing here is faster by being weaker; it is earlier as well as, never instead of.

**Where a rule genuinely differs for this document type it belongs in `references/learner-guide.md` under *Carve-outs*, and nowhere else.** The readability block is shared with the assessment skill and must not be forked — two copies of a 300-character cap drift, and the first drift ships as a guide that passes its own gate and fails the RTO's.

---

## 12. The spine gate band - Stage 3c, blocking, fanned out

**Runs at** Stage 3c: after authoring closes, before the first render, concurrently with background artwork generation. **Blocks.** The whole band re-runs unchanged before every Stage 7 re-render. **Invoked** from one entry point that fans out and joins: `scripts\Run-SpineGates.ps1 -BuildDir $out`.

**`Run-SpineGates.ps1` is specified, not yet implemented.** Until it exists, nothing fans the band out or joins it: the builder runs each member that exists by hand - `scripts\Check-FigureMirror.ps1`, `scripts\Check-FigureLeakage.ps1`, `scripts\Test-SpineRead.ps1`, and `scripts\Test-FigureConsistency.ps1 -BuildDir $out` for the spine arm of the registry - and the Stage 3c ledger note lists which members ran. The members marked not yet implemented in their own sections (15 to 18 and 22 to 28) are performed by nobody at 3c, so the 3c record must list them as not run rather than let the band's pass stand for them. A band of four scripts recorded as "the spine gate band: pass" is the same false green this file was rewritten against.

**The rule. Every check whose only inputs are the spine, the corpus, the unit extract and the renderer source runs here, before a document exists.** Not one of them replaces a later check. Every one re-runs at its original position later, on the artefact it always read.

| In the band | Section |
|---|---|
| Figure / answer-grid mirror | 13 |
| Assessor-only leakage | 14 |
| Coverage and leakage, one verdict | 15 |
| Withhold enforcement | 16 |
| Unregistered figure sweep | 17 |
| Provenance and attribution | 18 |
| Registry reconciliation and re-lock | 17, 18 |
| Spec renderability, whole-spine arm | 22 |
| Spine-measured word floors and cross-references | 23 |
| Terminology | 24 |
| Deck parity | 25 |
| Citation consistency | 26 |
| Scenario clock | 27 |
| Cross-reference resolution | 28 |

**Why the band exists, stated plainly.** One ordering defect produced four separate expensive symptoms: every check that reads MEANING ran at the end, on the rendered document, while the data those checks need was complete on the spine three to four stages earlier. Figure content that was machine-readable JSON at 01:00 could not be read as a figure until placement at 03:47 and was not read by any human until 05:13. Detection lag on the blocker that stopped that build was **4h12m38s from spine write to discovery**, and the fix cost a full serial audit-remediate-re-render-re-audit cycle of about forty minutes per round for three rounds.

**And the dependency was never real.** The gate eventually written to catch that blocker reads `Join-Path $BuildDir 'spine'` and never opens a `.docx`. Nobody was waiting on artwork. They were waiting on a habit of reading documents.

**The band fans out.** Its members share only two inputs - the spine and the corpus - and none reads another's output, so the band's wall clock is the slowest member plus process start, not the sum of its members. Run it alongside artwork generation, which by then is a background job.

---

## 13. Figure / answer-grid mirror - blocking, reports the anchor, does not decide

**Runs at** Stage 3c on the spine; adjudicated at Stage 3d; re-run unchanged at every Stage 7 remediation and again at 7c against the placed document. **Blocks.** **Invoked** `scripts\Check-FigureMirror.ps1 -BuildDir $out`.

**The question it asks.** Does any figure, slide spec or table on the spine reproduce an assessed response grid **with the assessed columns filled in**?

**It matches on STRUCTURE, not wording.** Row labels are normalised - lower-cased, punctuation stripped, whitespace collapsed - and compared against every typed response grid the Stage 1 corpus parse produced. Handing the grid over in the author's own words fails exactly as hard as copying it. Sharing the row labels alone is *not* a defect: the assessment task prints those labels itself, so the learner already has them. What makes a table an answer sheet is the assessed COLUMNS being filled.

**It walks every node of every spine file**, and treats anything with a `rows` array of arrays as a table wherever it lives and whatever it is called - `spec.rows`, `spec.nodes`, `spec.items`, `workedExample.table`, `practicalActivity.workedExampleTable`, and structures nobody has invented yet. *The failure that forced this:* its first version scanned only the captioned figures' `spec.rows`. A remediation round withheld rows in exactly those, the gate went green, and the next audit found the same grids still printed in full a hundred lines earlier in the same sub-sections. The leak had been moved, not removed, and the gate could not see it because it was looking at one property name instead of at the document. Worse than the leak: the captioned figure said "Your turn" on rows the uncaptioned table beside it answered in full, so the honest signal was contradicted on the same page and the caption became false on its face.

**Exactly one worked exemplar is allowed, and the allowance is counted ACROSS THE WHOLE SUB-SECTION**, not per table - two tables each showing "one" exemplar of the same grid is two answers.

**The filled test is a vocabulary test, not a length test, and this is a correction to the shipped script.** A cell is unfilled when it matches the explicit unfilled vocabulary - `Write here`, `Your turn`, `You write this`, blank, dashes - and filled otherwise. The version that shipped used `$rest.Trim().Length -gt 20`, which reads a temperature, a time, a yes/no or a container name as *unfilled*. **Brevity must never be mistaken for absence**; a one-word answer is still the answer.

**The gate reports the anchor and does not decide.** It names the file, the field path, the slot and the grid it matched, and stops. A reader clears a hit at Stage 3d, and only by recording a **written reason** in an allow-list that lives in `figures.json` beside the registry it weakens - never in a script parameter default, never in an in-file hashtable. Every entry is surfaced to Stage 6 as evidence. See rule 3 at the top of this file.

**The failure it exists to catch, and it is the reason this file was revised.** Six guide figures reproduced an assessed response table with the columns the learner is told to write already filled in; two carried the task's column headings verbatim; four of the same leaks were repeated on the deck. **The assessment is open book and expressly permits the Learner Guide**, so the learner copies the answer across. A third clean-room audit returned "Not Compliant - not for release" on it, four hours and twelve minutes after the offending content was written to the spine as plain JSON. Nothing required waiting for placement to read it.

**Implementation cost is near zero.** The script reads the spine directory and never opens a document. There is no reason for it to run late.

---

## 14. Assessor-only leakage sweep - blocking, scoped

**Runs at** Stage 3c over every channel of the spine, Stage 4 over the rendered extracts (`-DocText`), and 7c against the placed document. **Blocks.** **Invoked** `scripts\Check-FigureLeakage.ps1 -BuildDir $out -ReportPath <file>`. **There is no separate Stage 1 derivation step and no `-Derive` switch**: the script derives the shingle set from the canonical corpus on every run (`Get-ShingleSet`), prints the size of each set it derived and names what it derived it from, and `-ReportPath` writes the complete hit list - blocking and reported - to a file, because a finding cannot be closed against a list nobody has. Stage 1's only job for this gate is to have extracted every document into the corpus; a document not extracted is not swept, which is section 20's failure.

**The test.** Normalise the assessor-only guides and the learner-facing documents out of the one canonical corpus. Any **n-gram of 8 to 15 words present in an assessor guide and absent from every learner-facing document** is candidate leakage - by definition it is content the learner is not meant to have, whatever it looks like and whatever field it sits in. Swept over EVERY text channel the build produces: body prose, callouts, tables, figure cells, captions, alt text, slide bodies, chips and speaker notes, **with the channel list enumerated from the renderer contract** so a channel cannot be added to the build without being swept (rule 1).

**A companion sweep catches assessor-only marking vocabulary**, with the term list derived from the assessor guides' own section headings rather than typed.

**The blocking set is deliberately narrowed, and the narrowing is the whole design.** An undifferentiated shingle set fires on legal quotations, recipe names, instrument titles and shared boilerplate that an assessor guide and a Learner Guide may both legitimately carry - and a gate that cries wolf is a gate a builder learns to ignore within one build. So **blocking is scoped to n-grams occurring inside the assessor guides' model-answer and benchmark regions**, which Stage 1's typed parse identifies structurally, and n-grams also occurring in the unit extract or in cited instrument text are excluded as legitimately shared. Everything outside that scope is **reported, not blocked**, with its anchor.

**Allow-list:** required, in `figures.json`, one written reason per phrase.

**The failures it exists to catch.** Five consecutive bullets of an assessor's model answer reproduced *in the assessor's own order* in the guide's running prose - which the column-heading test structurally could not see, because it was prose, not a grid. Verbatim runs of 9 to 31 words against the assessor guides across nine worked-example tables. And speaker notes reading "the benchmark this task is marked against", which is assessor vocabulary on a learner-facing slide.

**Why it did not exist before.** The registry gate (section 11) catches a **registered** assessor-only string. This catches the **unregistered** case, which is the one nobody thought of - and the reason it was written late is the same reason as section 13: the figures were never read.

---

## 15. Coverage and leakage - ONE gate, ONE verdict - blocking

**Runs at** Stage 3c, again at Stage 4, again at every Stage 7 remediation, again at 7c. **Blocks.** **Invoked** `scripts\Assert-GridDisposition.ps1 -BuildDir $out`.

**Specified, not yet implemented.** Until it exists, the leakage arm is performed by `scripts\Check-FigureMirror.ps1` (section 13); the coverage arm - every assessed row label taught in the prose - is performed by nobody; and the one-verdict property that stops the two arms oscillating is performed by nobody, so the round-1-to-round-3 failure below is currently unguarded. The disposition field (`withheld` / `cleared, reason: ...`) is read by no script yet; a reader at 3d checks it by eye.

**The rule.** For every typed assessed grid, the gate returns **one verdict over the mapped sub-section**: every row label must be TAUGHT in the prose (coverage) **AND** no figure, slide, chip, caption, alt text or speaker note may present those rows as a completed grid (leakage). Structural matching on normalised row labels, not wording. A mirroring visual must carry an explicit disposition - `withheld`, or `cleared, reason: ...` - so consistency follows from the derived list rather than from an author remembering.

**Why one gate and not two, which is the point of the section.** Coverage pressure and leakage pressure act on **the same assessed table**, in opposite directions. Gated separately, remediating one manufactures the other. *The failure:* round 1 correctly found sixteen assessed cells taught as four paragraphs, and six rows compressed to four on a slide, and demanded every row be taught and all six be shown. Those two remediations were carried out correctly - and **they are precisely what round 3 found as the two worst leaks in the build**, one figure and two slides, whose own speaker note records the intent. A full audit round was spent turning one defect into the other. One gate, one verdict, or the build oscillates.

**False-positive control.** The coverage arm is label presence in prose; the leakage arm is section 13's mirror test. The combination cannot fire on anything neither arm fires on.

**Allow-list:** required, in `figures.json`, one written reason per cleared slot, surfaced to the audit.

**Also catches** the inconsistency case: withholding applied at three figures and not at five others in the same build.

---

## 15b. Three defect classes no current gate can see

The last build's audits found three defects that passed every mechanical check in this file and would pass them again today. Each is recorded here so a builder knows where the net has holes until the planned gate exists, and reads those parts of the document by eye instead of trusting a green result. **None of the three planned gates is on disk yet.**

**(a) Numbered-row grids.** Workbook tasks 2(b), 2(c), 3(a) and 3(b) hand the learner a grid whose rows are numbered, not labelled - the learner supplies the row content. The mirror gate (section 13) matches on normalised row LABELS, so a guide table that fills such a grid shares no label with the assessed one and the gate cannot fire: there is nothing to match. The leak is the SHAPE - the same column headings, the same row count, the assessed columns filled. *Planned gate:* **`Check-ShapeMirror`** - match a spine table to a typed grid on its column-heading set and row count where the grid's first column is a numeral, and report the anchor for 3d exactly as section 13 does. Until it exists, a reader checks every guide table whose column headings match an assessed task's, whatever its rows say.

**(b) Prose written to the shape of the model answer.** Knowledge Task 4's model answer is six rows of four indicators each, in the assessor's order. The guide taught it as prose: six paragraphs, four indicators each, in that order, with no fifteen-word run verbatim. The leakage sweep (section 14) blocks on 12-word shingles and reports on 8-word ones, and the mirror gate reads tables, so prose that paraphrases every cell and keeps the assessor's structure passes both. *Planned gate:* **`Check-RowCoverage`** - for every typed model-answer region, count the assessed rows whose distinctive content words all fall inside one paragraph of the mapped sub-section, in the assessor's order, and report a sub-section that covers every row in order as an anchor. Until it exists, a reader compares each Knowledge Task's model answer against the prose of the sub-section that prepares it, looking for the assessor's ORDER rather than the assessor's words.

**(c) A figure row keyed by day or run rather than by the task's row label.** Figure 7.1.4 carried an "On this run" row: the values the assessed task asks for, under a heading the task does not use. The mirror gate matched no label and passed it. *Planned gate:* **the heading test in `Check-FigureMirror`** - where a figure's column headings match an assessed grid's, treat every row as a candidate regardless of its label, and report the anchor. Until it exists, a reader checks every figure whose column headings match an assessed task's, and treats a row labelled by time, day, run or batch as an assessed row in disguise.

**What the three share, and why they are listed rather than fixed here.** Every one is a structural match on something other than the row label - shape, order or heading - and every one is decidable from the spine and the typed grids, which is why each has a planned gate rather than a permanent reader. A reader is the stopgap, not the design; and a stopgap that is not written down is a hole nobody is watching.

---

## 16. The withhold register - blocking, build-wide

**Runs at** Stage 2 to derive, Stage 3c to enforce, 7c across both finished artefacts. **Blocks.** **Invoked** `scripts\New-WithholdRegister.ps1 -BuildDir $out` at Stage 2 to derive; `scripts\Assert-WithholdRegister.ps1 -BuildDir $out` at 3c and 7c to enforce.

**The Stage 2 derivation step is `scripts\New-WithholdRegister.ps1 -BuildDir $out [-PackDir <pack>]`**, and it exists. It reads the pack's typed task JSON, the contract's questionMap, the learner-facing corpus and the unit extract, and writes four things nobody types: `grids.json` in the corpus dir the gates resolve (the mirror gate loads it in preference to its regex parse - and the proof that matters is that WITHOUT it the gate passes a planted answer grid green, and WITH it the gate catches it); `withhold-register.json` per sub-section with kind (labelled | numbered | records | lookup | freeText), items, subjects, unassessedSubjects, allowance and a numeric shape; `assessor-cells.json`, gate-only, carrying the model bullets and their content-word sets; and `agent-pack\<sub-section>\` holding exactly what a content agent may see. On the reference build: 35 grids (27 labelled, 5 numbered, 3 records), 31 prose parts, 28 packs, and a self-sweep proving none of 1,710 assessor-authored strings appears in any agent-facing file.

**The enforcement arm is implemented in two places, neither named `Assert-WithholdRegister`.** In-loop, `scripts\Test-SubSection.ps1 -File <spine file>` runs a relocation arm: any table sharing two or more headings with one of the sub-section's register grids fails on a row whose label is an assessed item with an assessed column filled, and for numbered grids reports a cell that names one of the grid's `subjects` together with two or more content words of that subject's model row (read from the gate-only assessor cells; never printed). At 3c, `Check-FigureMirror.ps1` counts answered rows against the register's per-grid `allowance` (0 where unassessed subjects exist, else 1) with the numbered-grid subject rule. First sweep of the reference spine under the register: 23 of 28 sub-sections pass; five fail because the register's allowance 0 is tighter than the old one-exemplar rule (Workbook 1(c), 2(a), 3(b); Knowledge 6(a), 5(b)), and one "relocated" example names an assessed subject after all. Those are content findings for the next round, and they are exactly what this arm exists to find before an auditor does.

**Derived, never typed** (rule 1). Stage 2 builds the withhold set from the corpus: every assessed response cell in the learner-facing tools, plus every value a figure or passage declares withheld, plus every value computable from an assessed task's own inputs. A register somebody types is a register that is short.

**A withheld value is a BUILD-WIDE fact, not a per-document one.** The gate sweeps every channel of every artefact and fails on any occurrence outside a posed-question context, and fails specifically where **one artefact fills a row the other marks withheld**.

**False-positive control.** Exact value matching against a derived set. The one judgement - "is this a posed-question context?" - is decided structurally by the containing node type from the renderer contract, never by prose sentiment.

**Allow-list:** required for the legitimate single exemplar, one written reason each.

**The failures it exists to catch.** A guide that says at 1.2 that it "deliberately does not do them for you" and prints the withheld quantity two paragraphs earlier, twice more at 1.3 and again at 3.2 - the audit had to write this sweep out by hand as remediation advice. And a deck slide that fills the row the guide's own figure withholds as "Your turn": the deck quietly defeating the guide's withholding decision, which is the failure mode that makes this build-wide rather than per-document.

---

## 17. The unregistered figure sweep - blocking

**Runs at** Stage 3c on the spine, again before every Stage 7 re-render, and at 7c on the rendered text of both artefacts. **Blocks.** **Invoked** `scripts\Assert-FigureCoverage.ps1 -BuildDir $out`.

**Specified, not yet implemented.** Until it exists, this check is performed by nobody. `Test-FigureConsistency.ps1` checks registered figures only - the whitelist this section says must be inverted - so an unregistered figure passes it today exactly as the batch weight in section 19 did.

**A figure nobody registered is a figure nobody is checking.** The registry's own header says exactly that - and then implements a **whitelist of what IS checked**, which is the precise inverse of a proof that nothing is unchecked. This gate inverts it.

**The test.** Harvest from the spine every number-with-unit token - digits **and** English word forms - and every named item of equipment, material or facility. Require each distinct candidate to carry **one of three dispositions**:

1. **Matched** by a registry entry;
2. **Sourced** - present verbatim in a canonical source in the corpus;
3. **Derived** - marked as such with its inputs named, where **each named input must itself resolve** under 1, 2 or 3.

**It fails on any UNDISPOSITIONED candidate**, and emits the list as a located work order naming the file and the field.

**False-positive control, and this is a deliberate rejection of the stricter design.** Failing on every *unmatched* value would fire on every legitimate derived figure in a teaching resource - a yield per portion, a total from a stated batch - and a builder would learn to ignore it inside one build. Requiring a **disposition**, with "derived, from these named inputs" as a first-class answer, keeps the full coverage while making a clean run mean something.

**No separate allow-list is needed: the disposition record IS the allow-list**, versioned in the registry with its reason.

**The failures it exists to catch.** A registry listing **31 figures against 112 placed captioned figures and 116 drawing objects** - four fifths of the numbers on the page outside every gate in this file. Nine unsourced explanatory figures at round 1, three of them surviving to round 2. Equipment dimensions that appear nowhere in the pack. And a pack specification driving an assessed criterion that neither artefact taught.

**Note the correct behaviour on a genuine derived chain**, because this is what separates the gate from a nuisance: where a batch weight resolves verbatim to a recipe card's own field in the corpus, and three further figures resolve as DERIVED from it with that weight named as their input, the gate **passes** all four. That is right. See section 19 for what happens when a judgement stage calls the same chain fabricated.

---

## 18. Provenance and attribution - blocking

**Runs at** Stage 2 (registry seed), Stage 3c (every authored assertion), re-run at 7c. **Blocks.** **Invoked** `scripts\Assert-Provenance.ps1 -BuildDir $out`.

**Specified, not yet implemented.** Until it exists, this check is performed by the Stage 6 auditor rebuilding the provenance ledger by hand - the failure this section records. The `authority` and `source` fields on the registry are still read by no script.

**Every registry entry must carry an authority class from a closed enum and a provenance locator naming a source document and a line or field.** The gate greps the named source in the corpus and fails unless the value occurs there.

**Extended to attribution sentences.** Any construction of *[a source noun drawn from the build contract's own source list]* + *a reporting verb* (states, says, gives, lists, shows, carries, specifies, records, requires, flags) + *a quantity or named proposition* must carry a locator **that resolves in that source**. The source-noun vocabulary is built from the contract, never hard-coded (rule 1); the verb list is one shared list, so widening it widens every rule that uses it at once.

**False-positive control.** Verbatim quantities are exact matches. A paraphrase requires at least one distinctive content word present in the source, and **near-misses are REPORTED for adjudication rather than failed** - which is where the noise would otherwise be. No allow-list: an unresolvable attribution is fixed by correcting the attribution.

**The failures it exists to catch, in both directions.** A guide asserting in five places that "the pack's own open items list flags the storage life as provisional" when no such list exists in either document. A guide asserting that "the assessment pack states plainly" a food-safety prohibition that appears in neither document. And, in the other direction, it **confirms** a correctly attributed figure against the line and field that carries it, which is what stops a later audit condemning it (section 19).

**It also activates two registry fields that already exist and that no gate reads.** `figures.json` carries `authority` and `source` on every entry; the registry gate references neither. That is why a sixty-row provenance ledger had to be rebuilt **by hand in all three audit rounds** of one build.

---

## 19. Finding arbitration - Stage 6b, blocking, mechanical

**Runs at** Stage 6b: after the review band, **before any remediation edit**, and over the audit's own output before its verdict is accepted. **Blocks.** **Invoked** `scripts\Assert-FindingProvenance.ps1 -BuildDir $out -Findings <report>`.

**Implemented: `scripts\Test-Finding.ps1 -Findings <findings.json | audit.md> -BuildDir $out`.** It reads the reviewer's structured findings (or a markdown report, best-effort), variant-expands every value a finding calls fabricated, unsourced or misattributed and greps the ENTIRE corpus for it; greps the spine for a value a finding calls wrong; re-runs the mirror gate scoped to a sub-section for a leak claim; and rejects any proposed forbid whose literal occurs in a source. It never clears a finding - it demotes one to REFUTED-CANDIDATE, STALE, DOUBTFUL or FORBID-REJECTED and exits 1 so the round cannot start unread. First real run, on the round-3 report of the reference build: the "fabricated" 3840 Gms raw came back REFUTED-CANDIDATE citing the recipe-card line in the learner workbook, and the Standard 1.2.5 finding came back STALE - the two false Highs that had cost two rounds.

**Nothing previously sat between an audit finding and a work order.** This stage is that thing, and one build proved the cost in both directions on a single value.

**The test.** For every finding asserting that a figure is fabricated, unsourced or misattributed, grep the normalised value **and** the named source's own text block out of the corpus. A hit **blocks the round** until the finding is re-examined against the extract - either way. A verification-table row may be marked source-attributed only if it carries a quotable locator, and a post-pass confirms the quoted string actually occurs in the named source.

**And a rule that outlives the build: no new `forbid` rule may be accepted whose literal occurs in any source document.** A build must never forbid a value its own sources carry - that poisons the registry for every future build of the same content.

**False-positive control.** It is a string search that **can only ever require re-examination**. It cannot clear a finding and it cannot condemn one; it refuses to let a finding become a work order unchecked. No allow-list - a disputed finding is resolved by reading the extract, and the resolution is recorded.

**The failure it exists to catch, and it ran both ways on one number.** Round 2 **certified** a batch-weight chain as pack-sourced, quoted a source line for it, and raised a finding requiring a deck slide to be remediated on that premise. Round 3 then declared **the same value fabricated**, and a full round was spent on that false finding: a slide was remediated on a false premise, and the delivered registry was permanently taught to forbid six literals - the weight and every figure derived from it. The value is in the pack, in a recipe card's own portion-size field, in both the workbook and the assessor guide, and in both clean-room extracts the auditor was handed. **Round 3 was wrong**, and nothing in the pipeline could tell.

**Judgement stages are indispensable and fallible in both directions.** That is not an argument for weakening them; it is an argument for a mechanical arbiter costing one grep between a finding and an edit.

---

## 20. Corpus completeness and pack self-consistency - Stage 1, blocking

**Runs at** Stage 1, before authoring opens. **Both block.** **Invoked** `scripts\Assert-CorpusComplete.ps1 -BuildDir $out -PackDir $pack` and `scripts\Assert-PackSelfConsistency.ps1 -BuildDir $out`.

**Both specified, not yet implemented.** Until they exist: corpus completeness is performed by nobody - `Lib-GateCommon.ps1` locates the corpus and classifies its documents as learner-facing or assessor-only for the gates that read it (`Get-GateCorpusDir`, `Get-GateCorpusDocs`), but nothing counts the extracted files against the pack manifest or hashes a re-extraction, and the typed parse this section calls the precondition for sections 13 to 16 and 27 is whatever the Stage 1 agent writes. Pack self-consistency is performed by the Stage 1 agent reading the corpus, and by the Stage 6 auditor after the fact - which is where the nine defects below were actually found.

### Corpus completeness

**One canonical corpus, extracted exactly once.** The gate fails when the count of extracted text files does not equal the count of documents the pack manifest lists - **every learner-facing tool AND every assessor guide** - into ONE canonical directory that every later stage and every audit consumes. It fails any later stage that re-extracts a file already present with the same hash.

**It also parses each document into typed assessment data**: tasks, response grids identified structurally (first column pre-filled, remaining cells carrying the tool's blank-answer token), model-answer regions, benchmarks, schedules. **That typed parse is the precondition for sections 13, 14, 15, 16 and 27.** Without it, none of them can be written at all.

**False-positive control.** It is a count and a hash comparison against a manifest. There is no judgement in it and no allow-list.

**The failure it exists to catch.** In one build the assessor guide and the workbook were extracted **twice, byte-identically, four hours and fourteen minutes apart**, while the two knowledge-task documents had **no early extraction at all** - they first reached disk 4h18m into a 4h55m build, though Stage 1 had recorded reading eleven knowledge tasks. The open-book leak found at round 3 was against precisely the document that was never extracted early. You cannot sweep a corpus you have not extracted.

### Pack self-consistency

Three sweeps over the corpus: **numeral divergence** (the same anchor given different values across or within documents), **benchmark divergence** (two benchmarks treating the same item to different criteria), and **arithmetic** (stated totals against stated components). Output is a **typed hazard list** handed to the content stage.

**It does not block on the pack** - the build cannot fix the pack. **It blocks on the hazard being dispositioned**: each hazard must be acknowledged with a written handling decision before authoring opens, not silently inherited. That distinction is exactly what stops it becoming noise.

**The failure it exists to catch.** Nine upstream pack defects found across three audit rounds, every one mechanically detectable before a word of the guide was written. One of them is decisive: an unexplained gap between a recipe card's finished weight and its own instruction, named in the audit as *the gap the guide tried to fill by inventing a figure*. **This is the one gate in this file where earlier detection PREVENTS a downstream defect rather than finding it sooner.**

---

## 21. Renderer contract and the validating spine writer - blocking

**Runs at** Stage 0 (compile) and Stage 3 (every write). **Blocks.** **Invoked** `scripts\Assert-RendererContract.ps1 -SkillDir $SkillDir` at pre-flight; the writer is the only way content reaches the spine at Stage 3.

**`Assert-RendererContract`, `Get-RendererContract` and `New-SpineWriter` are all specified, not yet implemented.** No renderer exports a contract, nothing compiles a schema, and there is no refusing writer: agents write spine JSON directly. Until they exist, this check is performed by `scripts\Test-SpineRead.ps1 -BuildDir $out`, run after every write and across the whole spine at 3c. It reports UNREAD and MISSING by parsing the renderers' PowerShell AST, so the two classes that shipped the empty role-play boxes are caught - but after the write, not instead of it, and an agent that does not run it is not refused. The `kind` and dangling-token classes are performed by nobody at write time; a missing `kind` is discovered at placement, which is the failure section 22 records.

**Each renderer exports `Get-RendererContract`**: the field names it reads per node type, which are required, and which must be non-empty for the node to render at all. Pre-flight **compiles those into the spine schema** and fails if two renderers declare different field sets for the same node type, if a container type declares no must-be-non-empty field, or if the compiled schema changed without a version bump. **The schema is compiled, never hand-written** (rule 1).

**Agents then write through a validator that REFUSES the write** and returns the violation for in-loop fixing - but **only for exact, locally-fixable violations**:

| Refused | Class |
|---|---|
| A field name no renderer reads | UNREAD - content that will silently vanish |
| A container whose readable fields are all empty | MISSING - a titled empty box |
| A visual with no explicit `kind` | Placement will guess |
| An unresolvable figure or cross-reference token | A dangling reference |

**Fuzzy and whole-corpus classes are deliberately NOT enforced at write time.** Mirrored grids, leakage shingles and bare numerals cannot be judged by an agent holding one sub-section, and a refusing writer that an agent cannot satisfy produces workarounds. Those run at 3c where a human can adjudicate with the anchor in front of them. The line is **check exactness**, and it is the line that matters.

**False-positive control.** Set comparison against a compiled contract, with a zero-judgement failure condition, and a message the agent can always act on locally.

**Allow-list:** required only for deliberately-unrendered metadata, declared once in the contract with a reason.

**The failure it exists to catch.** Five role-play boxes shipped empty or near-empty - three completely blank, and all three in the topic the guide itself calls safety-critical - because seven parallel authors wrote `situation` / `yourRole` / `otherRole` / `whatYouMustCover` / `phrases` while the renderer read `scenario` / `roles` / `steps` / `doneWell` and drew the box anyway. Authored, reviewed and gated content that **never reached the page**, found by a persona thirty-four minutes later, with the detector for it written during the remediation it should have prevented.

**Three shipped defects in the old detector this replaces**, all of them the same disease: it matched field names by **substring**, so a field named in a code comment counted as rendered; it capped its walk at a fixed depth, so deep nodes were never inspected; it named the renderers individually instead of globbing them, so a new renderer was invisible. It also declared a `$missing` list and **never added to it** - the MISSING class was documented and unimplemented. Compiling from the renderers' own exports removes all four at once, and **deletes `Test-Spine`'s hand-copied field arrays**, which were a second source of truth free to drift.

---

## 22. Spec renderability - blocking

**Runs at** Stage 3 at write time for the exact arm, Stage 3c for the whole-spine arm. **Blocks.** **Invoked** `scripts\Assert-SpecRenderable.ps1 -BuildDir $out`.

**Specified, not yet implemented.** Until it exists, this check is performed by nobody before placement: the `docx-images` sub-skill discovers an over-length flow or a flattened decision when it builds the figure at 7b-ii, which is the failure this section describes. A 3d reader can count nodes against the renderer's cap by hand, and should.

For every visual spec on the spine, **before any render**:

- **Node count** against the renderer's box cap;
- **Projected height** against the derived column height from the document profile;
- **Branch or decision semantics** against the target renderer's declared capability, naming the table fallback where it has none;
- **An explicit `kind` on the spine**, with the artwork manifest seeded from the spine **BY SLOT** rather than keyword-detected from a prompt the build itself wrote.

**Caps and column widths are read from the profile and the sub-skill config, never hard-coded** (rule 1 and rule 5). No allow-list; it is arithmetic against declared capabilities.

**The failures it exists to catch** - three, all determinable from the spec alone, and all found at or just before placement:

1. Nineteen flow diagrams over length. A nine-node flow lands at 21.6 cm and an eleven-node at 26.5 cm, which cannot fit a page. Fixed **after** Stage 4, Stage 4b, Stage 5 and a full audit round had all passed.
2. A decision figure silently flattened to a straight line, so one branch disappeared and the figure taught "you always report a mismatch" - the opposite of the rule.
3. Four photographs re-detected as diagrams by keyword, because the manifest guessed `kind` from prompt text instead of reading the spine.

---

## 23. Spine-measured counts - blocking

**Runs at** Stage 3c. **The Stage 4 render-side gates in section 3 and section 7 stay exactly as they are.** **Blocks.** **Invoked** `scripts\Assert-SpineCounts.ps1 -BuildDir $out`.

**Performed by `scripts\Test-Spine.ps1` since 3 Sep 2026**, in whole-spine mode at 3c and in `-File` mode in-loop: word floors from the contract (topic 3000, underpinning knowledge 800, slides 15), the two-way cross-reference against the contract's questionMap, prepared-exactly-once, four visuals per sub-section with Route B specs, empty boxes, ASCII, and a machine-readable result with the file's sha256. Byte-identical result to the build's validator on the reference spine; five planted defects each caught. A standalone `Assert-SpineCounts` is no longer needed.

Word floors per Topic and per Underpinning knowledge block, and the two-way question cross-reference against references **derived from the corpus**, measured on the spine JSON **where prompt text and body prose are separate fields and cannot be confused**. It also asserts that words-per-topic tracks criteria-and-knowledge-points-per-topic within a declared tolerance.

**It uses the same exclusion rule the render gate uses, and it does not replace that gate.** It moves FIRST detection of a content shortfall to before a render, which is the expensive part of the build.

**The failure it exists to catch.** A topic-balance finding that had to reason around its own measurement surface, because a large part of the measured difference was **artwork prompt text** sitting in the rendered document. The build's gate runner strips prompt paragraphs from a copy of the rendered file to work around a confound that measuring the spine deletes outright. Plus every Stage 4 word-floor failure, which section 3 warns is the expensive one - and which is far cheaper to find before the render than after it.

---

## 24. Terminology - blocking on the exact arms, reporting on the stylistic ones

**Runs at** Stage 3c, one pass over every authored string. **Blocks.** **Invoked** `scripts\Assert-Terminology.ps1 -BuildDir $out`.

**Specified, not yet implemented.** Until it exists, this check is performed by the Stage 5 personas and the Stage 6 auditor - two of whom had to raise the legislated-figure defect below independently before it was believed. The RTO profile pack carries the locked terminology (`assets\rto-profile.<rto>.json`), `Assert-RtoProfile` validates that the list is present and well-formed, and no script yet reads it against the spine.

**Blocking arms**, every one of them exact matching against a list DERIVED from the contract or the corpus, never typed per rule (rule 1):

- Locked canonical terms with their forbidden near-synonyms and required paired forms;
- Glossary-canonical restatement matching, or an explicit elaboration marker;
- First-use expansion for every pack-derived identifier and acronym, in reading order;
- Structural label uniformity across repeated elements;
- Question and answer pairing counts;
- Truncation patterns - "and N more", trailing ellipsis - with chip item counts against the question map;
- Build-vocabulary and bare provenance-class tokens leaking onto the page;
- Ambiguity-list disambiguators required on **every** occurrence, where the sources apply one value to two subjects;
- **Authority-class rules GENERATED from the class**, so a legislated figure can never be described in venue-ownership language or the reverse, and a new figure cannot be added without its rules coming with it.

**Report-only arms:** duplicate-sentence and opener-diversity counters. These report at Stage 3 so remediation is one edit pass rather than a round.

**Forbidden-verb lists come from one shared list.** *The failure that forces this:* a rule watched `requires` / `mandates` / `sets` while the defective sentence said `approach`. Widening one shared list widens every rule that uses it at once; widening a per-rule list fixes one rule and leaves the rest.

**Allow-list:** required for deliberate repetitions, with the reason recorded.

**The failure it exists to catch.** Eleven separate round-1 findings of this class in one build, including seventeen truncated chips, and - the worst of them - a legislated figure labelled as the venue's own house standard on four consecutive slides. That was **the single most-repeated teaching point in the unit**, the deck had it backwards, and two personas had to raise it independently before it was believed.

---

## 25. Deck parity - per-surface, benchmark-derived - blocking

**Runs at** Stage 3c, and per-surface again at Stage 4 and 7c. **Blocks.** **Invoked** `scripts\Assert-DeckParity.ps1 -BuildDir $out`.

**Specified, not yet implemented.** Until it exists, two of its arms are partly performed by scripts that do exist: `Test-FigureConsistency.ps1`'s `deckMust` list, which is **still the global OR this section says it replaces**; and `Test-DeckRules -Plan`, which checks that teaching slides carry notes. The per-surface `require`, the benchmark-derived per-topic set, and the row-and-column-count rules are performed by nobody. The 24-figures-with-no-deck-requirement failure below is therefore still open.

**It replaces the registry's global-OR `require` with a per-surface rule.** Every required string must appear in the **guide-facing** source set AND the **deck-facing** set, unless the entry explicitly narrows its surfaces in a declared field. **A `.ps1` comment can never satisfy a `require`** (see section 35 on gate hygiene).

It adds four rules on top:

- Every instrument, term and item an assessor benchmark will accept must appear **at least once in EACH artefact**, asserted per topic rather than per document. The required set is **derived from the benchmarks**, so it cannot be short.
- A slide's column and row counts must match the assessed task its chip names.
- A note asserting N items must sit against a table of N.
- Every slide whose layout is not on the RTO profile's declared no-notes list must carry notes above a minimum length.

**The verified false pass this exists to catch.** `Test-FigureConsistency` sums `require` matches across all sources as a **global OR**, so **one occurrence anywhere** satisfies the rule - including inside a build script's own comment. One build's registry carried 32 figures against 8 `deckMust` terms, leaving **24 corrected figures with no deck-side requirement at all**. Also caught: an accepted instrument named twice in the guide and zero times across 183 slides, and ten content slides still carrying no speaker notes at round 2.

---

## 26. Citation consistency - blocking on contradiction, reporting on similarity

**Runs at** Stage 3c. **Blocks.** **Invoked** `scripts\Assert-CitationConsistency.ps1 -BuildDir $out`. Pure self-consistency over the spine - **it needs no copy of the legislation**, which is why it can run this early.

**Specified, not yet implemented.** Until it exists, this check is performed by the Stage 6 auditor - the same reader that let the inverted scope statement below survive three rounds by fixing the instance in front of it.

**Blocking arm, exact:**

- The same normalised duty phrase cited to two different clause numbers;
- The same instrument's scope or applicability stated two non-equivalent ways after normalisation;
- An adoption relationship stated inconsistently;
- A registry proviso or caveat absent from any occurrence of the figure it attaches to.

**Report arm, fuzzy:** clusters formed by duty-phrase similarity, surfaced as prioritised pairs to the auditor with every location named.

**The split is deliberate.** Similarity clustering is exactly where a citation gate would cry wolf, so **only exact contradiction blocks** and the fuzzy half reports with its anchor. **Appendices and body prose are one namespace** - a contradiction is a contradiction wherever it sits.

**Every location in a cluster is reported, so the fix is enumerated rather than sampled** (see section 32).

**The failures it exists to catch.** Six wrong clause numbers in one guide and one on its deck, each contradicted by the same document elsewhere - the deck citing clause 21 and then clause 22 for the same requirement, eleven slides apart. An inverted scope statement that survived **all three audit rounds** because each round fixed the instance it was shown: round 2 recorded it as "so the delivery set says it both ways" and it was still there at round 3 and in the addendum. A wrong adoption instrument. A dropped proviso. And a caveat that sat correctly in two places and was absent from seven sections and six slides.

---

## 27. Scenario clock - blocking on the exact arm

**Runs at** Stage 3c. **Blocks.** **Invoked** `scripts\Assert-ScenarioClock.ps1 -BuildDir $out`.

**Specified, not yet implemented.** Until it exists, this check is performed by the Stage 5 personas and the Stage 6 auditor, reading scenario dates against the pack's order form by eye. The typed schedule it reads from does not exist either (section 20).

Extracts every date, day name and time in scenario text **with the pack identifier it attaches to**, and checks it against the corpus's typed schedule and against itself.

**Blocking:** the same pack-identified item carrying two different production dates within the spine; and an item produced **after** the delivery time the pack's own order form sets for it.

**Report:** stated intervals that violate a registry duration.

**Why the blocking arm is narrow.** Attaching a free-text time to a subject is where a scenario gate would produce noise, so blocking is scoped to scenarios that name the item by its **pack identifier**, which is exact. Everything looser reports with its anchor.

**The failures it exists to catch.** A scenario that places production **after its own delivery deadline**, with the pack's order form setting that delivery for noon on the day the guide has the food being cooked. And one item's production date given as three different dates across four sections, with an internal clash inside one of them.

---

## 28. Identifier namespace and cross-reference resolution - blocking

**Runs at** Stage 2 for the namespace assertion, Stage 3c and Stage 4 for dangling-reference resolution. **Blocks.** **Invoked** `scripts\Assert-IdentifierNamespace.ps1 -BuildDir $out`.

**Specified, not yet implemented.** Until it exists, the namespace assertion is performed by the Stage 2 agent when it locks the numbering plan, and cross-reference resolution by `Test-GuideRules -QuestionsInPack` for question references only. Appendix and section references are resolved by nobody, and no resolved index is written for the audit - so the false "non-existent section" finding below would have to be refuted by hand again.

**The guide's own appendix and section identifier scheme must not collide with any identifier scheme in the source pack.** A collision forces a qualified convention into the build contract *before* anything is authored. Every internal cross-reference must resolve to a target, and **the resolved cross-reference index is supplied to the audit stage as evidence**.

**False-positive control.** Set intersection over identifier schemes, and reference resolution against a target list. No allow-list.

**The failures it exists to catch.** One guide's appendix letters collided with the pack's across **151 references**; the renumbering that followed left a stale reference pointing at nothing, found a round later. And supplying the resolved index pre-refutes the other direction: an auditor once reported a whole section as non-existent, and the false finding had to be refuted by hand search.

---

## 29. The RTO profile pack, palette resolution and brand crossover - blocking

Three gates on one subject, at four positions. **Section 9's carve-out is unchanged and still applies.**

### 29.1 The RTO profile pack - Stage S0-RTO, cached per RTO, versioned

**Runs at** S0-RTO, off the per-build critical path, cached and versioned per RTO. **Blocks.** **Invoked** `scripts\Get-RtoProfile.ps1 -Rto <id> -Check`, which is `Assert-RtoProfile`; a build calls `Get-RtoProfile -Rto <id>`, which validates before it returns and **throws** rather than defaulting.

**The three files.** `assets\rto-profile.<rto>.json` is the pack; `assets\rto-profile.schema.json` is what validates it; `assets\rto-profile.mvc.json` is the worked example, for the one brand whose guide **and** deck templates the assets folder actually ships. **The schema is machine-read, not documentation**: the validator derives its required-key set, its closed palette role enum with the aliases each role is known by, and its identity field list from that file, so a key added to a pack is unvalidated until the schema names it with a reason. The specification and the validator are one file apart rather than two lists apart.

**A pack POINTS at its sources and copies none of them.** Identity strings and palette hexes are read from the branding profile, geometry and callouts from the guide profile, layouts and slot ordinals from the deck profile. A restated hex would be a second source of truth free to drift from the map the swap applies (rule 1) — which is exactly how a sweep came to print "no crossover" over 766 live occurrences.

Everything a build would otherwise hard-code that is a property of **the RTO rather than the unit** lives here and is validated once: geometry-patched templates, the resolved palette role map over a closed role enum, identity strings for this RTO **and every other brand in the file**, deck layouts, the guide profile, the no-notes layout list, house image-framing rules and the negative-constraint list, locked terminology, and the document-control block spec.

**What `Assert-RtoProfile` fails on:** a missing or empty required key; either approved template absent — *a brand with no approved guide template and no deck template cannot be built, ask the RTO for one rather than generating it*; a guide, deck or branding profile that does not load, or one declaring a different brand; a palette role that resolves to nothing under any of its declared names, or to something that is not a six-digit hex; a missing required identity field, or an identity string this RTO **shares** with another brand, which would make the crossover sweep structurally unable to tell them apart; a carve-out with no scope or no written reason; and the no-notes rule below.

**The no-notes layout list is an allow-list against a shipped deck rule, so it obeys allow-list discipline (rule 3).** The list itself stays in the deck profile — one source of truth — and the pack carries **one written reason per entry**. The gate fails when the two sets differ **in either direction**: an exemption the deck profile makes with no reason in the audited pack is a shipped rule switched off where no audit would see it, and a reason for an exemption nobody made is a stale allow-list entry standing as evidence for a decision that was never taken. It also refuses any entry that is simultaneously on the notes-**required** list: the exemption list may never switch off the rule for a slide kind that teaches. Every reason is surfaced to Stage 6 as evidence.

**A trap worth carrying into any dot-sourced gate script.** A dot-sourced script's param block runs **in the caller's scope**. An earlier draft of this one declared `[string] $Rto`, so the pre-flight line `$rto = Get-RtoProfile -Rto $brand` assigned an object to a variable PowerShell had type-constrained to `[string]` — it silently coerced the whole profile to its string form, and `$rto.GuideTemplate` then read as empty with nothing erroring anywhere. The parameters are now untyped, and named `-SkillPath` / `-BrandingPath` so they cannot overwrite a build's own `$SkillDir`. **Check what a dot-sourced script's param block will overwrite before you dot-source it.**

**This is the answer to "the skill is shared across RTOs", and it is where the one-time cost honestly belongs** - paid once per RTO and amortised across every unit that RTO ever builds. *The failure:* ten build-local scripts in one build hard-coded one unit code, one brand and one build's expected counts, and three consecutive audits could only record the document-control block as "not verifiable" because nothing declared what it should be.

### 29.2 Palette resolution as a total function - Stage 0

**Runs at** Stage 0, resolved once and passed to every consumer; **nothing downstream ever re-resolves by name.** **Blocks.** **Invoked** `Resolve-Palette` from the branding library at pre-flight.

**`Resolve-Palette` exists in substance, not as a script.** `Get-BrandPalettePairs` in `Set-ResourceBrand.ps1` now resolves every role under every name it is known by and THROWS on a role it cannot resolve (3 Sep 2026) instead of defaulting to the source brand's own hex - which is the self-map that shipped 766 of the other brand's fills. Proven: ACI and MVC each resolve all nine roles; a palette missing lightFill is refused by name. The crossover sweep prints which roles it excludes as genuinely shared. What is still missing is the Stage 0 assertion that runs this before anything is rendered; today it fires at first use.

**Resolution is TOTAL over a closed role enum.** A role with no match on the supplied object **throws** rather than falling through to a default. **A role that maps to itself throws** - a self-mapping role is an unresolved property name, never a legitimate no-op. Pre-flight additionally fails if the objects the several callers pass carry **differing property-name sets for the same role**.

**The failure it exists to catch, and it is the root of the whole brand defect.** One palette role was named `Fill` on the object the swap actually passes and `lightFill` on the one the lookup expected. The lookup fell through to its own default, mapped the role to itself, and the apply loop skipped it. **Nothing was written and nothing errored** - a silent no-op that left 608 foreign light fills in the guide and 158 on the deck, found about two and a half hours after branding was first reported clean. A lookup that can silently return its own input must assert that it did not.

### 29.3 Downstream palette injection - Stage 0, enforced at 7b-ii

**Runs at** Stage 0 (pre-flight reads each styled sub-skill's config) and 7b-ii (placement passes the palette in). **Blocks.** **Invoked** `scripts\Assert-DownstreamPalette.ps1 -BuildDir $out`.

**Specified, not yet implemented.** Until it exists, the injection is performed by the builder passing the resolved palette to `docx-images` by hand at 7b-ii, and nothing asserts that the sub-skill accepted it or that it would throw without one. The only thing that would see a wrong-brand repaint is the crossover sweep at 7c (`Check-Identity.ps1`), after the fact - which is where the 177 header rows below were found.

**Every sub-skill or shared config that emits styled output must accept an injected palette, and must THROW when a caller that declared a brand supplies none.** No silent defaults. Pre-flight reads each such configuration, compares it to the brand resolved for THIS build, and fails if the sub-skill has no injection path. Where a repaint is genuinely unavoidable, it **registers that repaint as a required stage whose absence fails delivery**.

**The ordering defect it exists to catch.** The brand swap must run **before** artwork, because the logo swap's one-logo-per-part precondition genuinely requires a fresh render. The artwork sub-skill then built 56 native diagram tables from a palette **hard-coded to a different brand**, so the guide went from zero crossover hits to 177 foreign header rows and 608 foreign light fills **after branding had been declared clean**. An entire post-placement repaint round exists for a config value that was knowable at minute one. Passing the resolved palette in means native diagrams are built in the correct brand the first time, and the shared config stays untouched for every other RTO.

### 29.4 Brand crossover - Stage 4c, again at 7c, again at 8

**Runs at** Stage 4c (a numbered, ledgered stage), 7c on the finished files, and Stage 8. **Blocks.** **Invoked** `scripts\Check-Identity.ps1 -Path <guide> <deck> -Brand $brand` - **ONE implementation, called with every delivered artefact in one call, so the stage cannot pass having run on one.** `Assert-BrandCrossover` is this file's design name for it; there is no script of that name, and `Check-Identity.ps1` is the file. Its `-SelfTest` plants a forbidden token in a copy of a real part, verifies the plant landed, and fails if the scan misses it (rule 2).

**The forbidden token set is DERIVED from the same resolved role map the swap applies** (rule 1): every hex the map moves, plus every other brand profile's trading name, legal entity, provider code, CRICOS code, domain and street address, read from the branding file. **Never a hand-typed literal.**

The gate **prints the count of what it checked and what it found**, asserts which artefacts it ran on, and **the stage cannot pass unless it ran on every artefact the stage produced** and every XML part of each. It reads the cover and the title slide back to assert they carry the **build** brand. It is trusted only after failing on a planted defect verified to have landed (rule 2).

**Why Stage 4c is a numbered stage with a ledger record.** The brand swap previously had no stage number, no gate-table entry and no ledger record, **so a build that never branded at all could not fail**.

**The two failures it exists to catch.** First, a swap that had not run at all: one provider's name on the guide cover and in all 182 deck footers, another on the title slide, two RTO codes and two CRICOS codes across the delivery set. Second, the residue: the sweep hand-listed three of nine palette hexes, omitted the light fill and both borders, printed **"no crossover" over 766 occurrences**, and had only ever been run on the guide - so its report's claim about both packages was true of one. Carve-outs (section 9) are declared in the branding profile with a reason, never typed into the gate.

---

## 30. Prompt lint and the generation endpoint probe - Stage 3b and Stage 0

### 30.1 Prompt lint - Stage 3b exit, blocking, before any generation spend

**Runs at** the exit of Stage 3b, before a single image is generated. **Blocks.** **Invoked** `scripts\Assert-PromptLint.ps1 -BuildDir $out`.

**Implemented: `scripts\Assert-PromptLint.ps1 -BuildDir $out [-Profile <rto-profile.json>]`**, self-tested (`-SelfTest`), text-only. Its first real run over a spine written before it existed failed 23 of 56 Route A prompts - one with a person as the grammatical subject, the shape that produced 47 faces, and 22 missing a required negative from the profile - so a spine authored under the old brief will block here until its prompts are brought to the profile. That is the gate working, not a false positive.

Every generation prompt is checked against the RTO profile's **house framing rules** and the artwork sub-skill's own **negative-constraint list**. It fails a prompt whose grammatical subject is a person noun where the house rule requires hands-and-equipment framing, and fails any prompt omitting a required negative constraint for its subject class. A string check over `visuals[].prompt` costing seconds.

**False-positive control.** The subject test is a **closed person-noun list from the RTO profile**, matched at the head of the prompt's subject phrase - not a semantic judgement. The constraint test is set membership.

**Allow-list:** required, per slot with a written reason, for the rare prompt where a person is the legitimate subject.

**The image review is NOT weakened.** It caught two genuine food-safety defects in one build and keeps its full authority and its full scope. The lint removes the **volume** it must wade through, not its remit.

**The failure it exists to catch.** Forty-seven of fifty-seven illustrations failed a first image review on identifiable faces, seventeen failed a second and two a third. The regeneration window ran **48 minutes 38 seconds** inside a 1h43m artwork block. The script written under pressure to fix it proves it was a text operation all along: it rewrites the prompt subject from a person to hands and equipment, and it reads **prompts, not images**.

### 30.2 Generation endpoint probe - Stage 0, NON-blocking by design

**Runs at** Stage 0, minute one. **Does not block.** **Invoked** `scripts\Probe-GenerationEndpoints.ps1`.

**Implemented: `scripts\Probe-GenerationEndpoints.ps1 [-Quality low]`**, self-tested with the transport stubbed, one real low-quality image on a live run (HTTP 200 in under ten seconds on the reference machine). Exit 0 = go; 2 = quota or credit block, tell the user to add credit NOW while authoring runs; 3 = no key, no network call made; 1 = anything else. The images endpoint returns no rate-limit headers, so a parallel fan-out width cannot be sized from it - use the sub-skill default.

One minimum-cost probe of every external generation endpoint the build will use, so a quota refusal surfaces at minute one and the operator can top up **in parallel with content authoring**. It reports the endpoint's own status code; there is nothing to misjudge.

**Non-blocking is deliberate.** A refusal re-sequences the operator's attention; it is not a reason to refuse to author content.

**The failure it exists to catch.** A quota block idled one build **19 minutes 20 seconds on the critical path**, discovered two hours in - and it was only on the critical path at all because the audits sat downstream of artwork.

### 30.3 The image review - Stage 7b-i, blocking, judgement, ledgered

**Runs at** 7b-i, in the background arm launched at the end of Stage 3b, once per generated image; again at Stage 7 step 7 for any slot whose figure content or prompt changed in the round; and its final check is part of the confirming read at 7d. **Blocks.** **Invoked** by a reader, not a script: the agent that launches the generation arm owns the review, and the arm is not finished until its record is written.

**Who owns it: whoever launches 7b-i.** Under the serial pipeline the review was an inline step of placement and could not be skipped. Moving generation into the background took the review with it, and a background arm with no owner, no gate row and no ledger record is an arm that can simply not happen while every structural gate passes. So the launcher owns the review, names itself in the record, and **placement at 7b-ii may only use a slot with a passing review record.** An unreviewed image is not placed.

**What it checks, per image, at full scope.** No identifiable face. No lettering, numbers or signage text inside the image. No real brand, logo or trademark. Nothing that contradicts the document: wrong PPE, a non-Australian fitting or plug, unsafe practice - bare hands on ready-to-eat food is a food-safety defect on the page, not a styling quibble - or a subject that does not match the caption and alt text on the spine for that slot. A fail is a regeneration of that slot with its prompt corrected, never a quiet placement. The prompt lint in 30.1 removes the volume this review must wade through; it does not narrow what the review looks for.

**How it is ledgered.** `Add-StageRecord -Stage '7b-i' -Name 'Generate + image review' -Status pass -Findings n`, where `n` is the number of images that failed a first review, so the report can say what the lint saved. `7b-i` is in `$script:LedgerRequired` and `$script:LedgerBlocking`, so a build with no record does not deliver. Where nothing was generated - no API key, or the user declined the spend - it is recorded `n-a` **with a note**, and the ledger rejects an `n-a` without one.

**Heartbeat.** The arm obeys the long-stage output contract (section 36): the review file is created with its header and the full slot list before the first image is looked at, each slot is appended with its verdict as it is judged, a heartbeat runs, and a restart resumes from what is on disk. A review that writes only at the end loses every verdict when the arm dies, and a dead background arm is otherwise invisible - nothing on the critical path is waiting for it.

**An image reviewed against superseded content is re-checked against the final content before it is placed.** The background review judges each image against the spine as it stood at generation time, hours before remediation. Stage 7 edits the spine. So an image passed at hour two against a figure Stage 7 then corrected is an image nobody has checked against what the page now says - and under the serial ordering that could not happen, because the review sat after remediation. Two re-checks close it and neither is optional: Stage 7 step 7 re-reviews every slot whose figure content or prompt changed in the round, regenerates where the prompt hash moved, and records under `7b-i`; and Stage 7d re-checks every placed image against the regenerated figure sheet as part of the confirming read. A slot that fails at 7d is regenerated, re-reviewed and re-placed, and the round is not closed until it passes.

**The failure it exists to catch.** On one build forty-seven of fifty-seven illustrations failed a first review on identifiable faces, and the same review caught two genuine food-safety defects that no prompt check could have seen. The review is worth its cost. What section 30.1 removes is the forty-seven, not the two - and what this section adds is an owner, because the first version of the background arm had none, and the ledger could not tell.

---

## 31. Channel disposition, extract stamping, and the confirming read - blocking

**Runs at** Stage 4 (stamping), Stage 5 and 6 (the review band), Stage 7d (the confirming read) and Stage 8 (delivery). **Blocks.** **Invoked** `Get-DocText` writes the stamp; `scripts\Assert-ChannelDisposition.ps1 -BuildDir $out` enforces it.

**Implemented: `scripts\Get-DocText.ps1` writes the stamp.** `FIGURES: n placed drawings, m unresolved artwork prompt blocks`, a `CHANNELS:` line with the counts that apply to the artefact (tables, slides, captions, alt texts, speaker notes), and `SOURCE: <file> SHA256: <byte pairs> EXTRACTED: <utc>`, then a blank line, then the text unchanged to the byte. Proven neutral on the reference build: the figure registry's rendered arm produced identical output, the leakage sweep an identical verdict and hit list, and the claims digest read the three lines and digested nothing from them. The hash is written as byte pairs because the registry sweeps extracts for numeric literals and a 64-hex run could contain one; with no digit run longer than two, no forbid can match inside the stamp. A fourth line, `FIGURE CONTENT NOT PRESENT IN THIS EXTRACT`, is written only when m is above zero.

**Every extract carries a mandatory provenance header.** `Get-DocText` stamps every extract with:

```
FIGURES: n placed drawings, m unresolved artwork prompt blocks
CHANNELS: <the channel list, enumerated from the renderer contract>
```

and where `m > 0` it writes, in full:

```
FIGURE CONTENT NOT PRESENT IN THIS EXTRACT
```

**Every review stage receives a manifest** of which channels are in final form and which are placeholders, and **must return a disposition for each**. A channel marked placeholder is automatically re-queued. **The ledger refuses to count a Stage 5 or Stage 6 record as satisfying the figure-reading requirement unless `m = 0` or the spine figure sheet accompanied the extract.** Delivery fails if the union of channels dispositioned in final form across all rounds is not the full channel list. **No stage may emit a placeholder without registering the spine path its content will come from, and a content check must exist for that path.**

**The confirming read at Stage 7d** is the other half of the same rule: **delivery requires at least one Stage 6 record that POSTDATES the newest placement**, so no build can ship on a verdict issued against a document that had no figures in it. It is **scoped** to what placement changed - the placed figures, captions and alt text against the figure sheet already adjudicated at 3d - so the guarantee costs a short read rather than a fourth full audit round.

**The failure it exists to catch, and it is the process defect underneath the whole revision.** `Get-DocText` appends alt text so that "a review that skips it has not read the figures" - but **placement runs after the audit**, so that rule was **guaranteed vacuous in every pre-artwork round** and nothing detected the vacuity. Round 1 reported "every figure is missing", was correctly told that was expected at that stage, and **nobody drew the consequence that the figures had therefore never been read by anyone**. They were not read until round 3, four hours in, and round 3 failed the build. A placeholder contents page went the same way: closed on a claim about a later stage, and found unrebuilt a round afterwards.

**The figure sheet** - the spine's visual entries dumped as plain text, one block per slot with rows, caption, alt text, slide bodies and speaker notes - is produced at Stage 3d and **travels with every later review pack**. That is what lets a reviewer read figure content whether or not a picture exists yet.

---

## 32. Enumerate before fixing - Stage 7, blocking, every round

**Runs at** Stage 7, every remediation round. **Blocks.** **Invoked** `scripts\Assert-EnumerateBeforeFix.ps1 -BuildDir $out -Finding <id>`.

**Specified, not yet implemented.** Until it exists, the enumeration itself is performed by the two sweeps that do exist - `Test-FigureConsistency.ps1`, which once the registry rule is added lists every hit across the spine, the build scripts and both extracts; and `Check-FigureLeakage.ps1 -ReportPath`, which writes its complete hit list to a file - and the assertion that a finding cannot be closed without one is performed by nobody. So the Stage 7 ledger note must name the hit-list file per finding, or the closure is a sentence, which is the failure below.

**A finding cannot be marked closed without a machine-generated hit list across every content channel of every artefact, produced BEFORE the fix.** The fix must clear the whole list, and **the sweep is retained as a permanent registry rule that re-runs every round**. When an audit finds a defect **class**, the fix is not complete until the sweep has run over every channel and both artefacts, and the channel list it covered is recorded in the ledger.

**Order within the stage: registry first, then the hit list, then the edit.** Patching content before the registry rule exists is how a class-fix becomes an instance-fix.

**Paired rule: a finding closed by deferral to a later stage must register a blocking gate at that stage, and delivery fails if that gate never ran.** A deferral with no gate behind it is a finding that was closed by being written down.

**False-positive control.** It gates the PROCESS, not the content: the assertion is that an enumeration exists and is cleared, which is a file check. No allow-list.

**The failure it exists to catch - it is the shape of an entire audit round.** One finding was corrected in the front matter and the assessment overview and missed in **all eight rows of the cross-reference table and the deck's closing note**. Round 2 states the pattern outright: the remediation landed on the figures and missed the tables, the chips and the closing notes. Five separate findings in that round have the same shape, and one scope-wording defect survived all three rounds by being fixed wherever it was pointed out. Most expensively: an answer-table defect class was fixed in prose at 11:16 and **the identical sweep was never extended to the figure channel until 14:43** - which is the leak that failed the build.

---

## 33. Full re-gate after mutation, and caption-to-slot reconciliation - Stage 7c, blocking

**Runs at** Stage 7c, immediately after artwork placement - the last mutation of both artefacts. **Blocks.** **Invoked** `scripts\Run-Gates.ps1 -BuildDir $out -AfterArtwork` plus the spine band and the crossover sweep.

**Implemented: `scripts\Run-Gates.ps1 -BuildDir $out [-PackDir] [-Brand] [-Variant] [-Rto] [-Cricos] [-UnitCode] [-AfterArtwork]`.** It derives the pack references from the pack's own content files, threads every parameter each gate's blocking rules depend on and PRINTS the list at the end so nothing can be omitted silently, fans nine gates out as jobs (guide, readability, deck, registry source arm, both extracts, mirror, identity on both artefacts, placed artwork) and then runs the registry's rendered arm and the leakage sweep on extracts it derives itself, REFUSES the leakage gate when `unit_extract.md` is absent rather than letting it degrade, and exits 0 only when every gate passes. On the reference build it reproduces the build copy's result in about 40 seconds against 46 serial. The whole-set assertion the gate table calls `Assert-FullRegateAfterMutation` remains specified, not implemented: nothing yet proves that a 7c run followed the LAST mutation.

**Standing rule: any stage that changes what is on the page is followed by the COMPLETE gate set, never a subset.**

At 7c that means all of: guide rules with `-AfterArtwork`; deck rules; readability; the figure registry on **freshly regenerated** extracts of BOTH artefacts; mirror and leakage against the placed document; the derived brand crossover sweep on the finished files; and **caption-to-slot reconciliation**.

**Caption-to-slot reconciliation:** every spine visual slot must have **exactly one** caption in the rendered document, matched on the **caption paragraph style** rather than any text run, and counted **PER NUMBER with no de-duplication before comparison**. Style-scoped matching stops an in-prose cross-reference counting as a caption. The counts come from the spine, never from a literal (rule 1).

**The failure it exists to catch.** Artwork was the last mutation of both artefacts and was followed by **exactly one of five gates**, so the registry's variant-aware sweep never once ran against a document that actually contained figure rows. And the caption checker that was supposed to catch a duplicate caption **de-duplicated its own list before comparing**, making its advertised failure unreachable - in a script that was wired to no caller at all. Both are why the rule is "the whole set" and not "the relevant ones".

---

## 34. Ledger integrity and staleness - Stage 8, blocking

**Runs at** Stage 8, with the render-set constant declared at Stage 0 and enforced at every stage record. **Blocks.** **Invoked** `Test-StageLedger -BuildDir $out | Write-StageLedgerReport`, plus `scripts\Assert-Staleness.ps1 -BuildDir $out`. **Section 10's rules are unchanged; these are added beneath them.**

**Implemented as `scripts\Assert-RenderDelta.ps1` and the per-topic rule in `Stage-Ledger.ps1`.** The delta hashes each topic's guide slice (cut at the Topic headings, front matter as topic 0), its deck slides (by the deck plan, framing slides as topic 0) and its figure-sheet slice, and writes `render-delta.json`. A 4b, 5 or 6 record carrying `-Topics` and `-DeltaSha` is stale only for the topics whose hashes moved since that delta, and `Test-StageLedger` prints the stale set by topic; a record with neither field keeps the whole-artefact timestamp rule unchanged. Proven on the reference build: the round-5-to-round-6 delta found the five topics the touch list named and a sixth the list had missed (one rewritten sentence in 4.3); a planted one-word change reported exactly its topic and arm; re-extracting unchanged files reported no movement, so the stamp sits outside every hash; a scoped Stage 6 record for the changed topics cleared the rule while an unscoped Stage 5 record kept firing the old rule.

**1. Staleness is proven from FILES and hashes, not from clock order in a ledger.** Delivery fails if any delivered artefact's hash or mtime is older than the newest file in the spine, the registry, or any input it renders from. **The ledger was the thing that lied, so the ledger cannot be the witness.**

**2. Placement is a mutation, held to its own class.** `$script:LedgerRenders` is `4` and `7` and holds `4b`, `5` and `6`; `$script:LedgerPlacements` is `7b` and `7c` and holds `7c` and `7d`. The two classes are separate because they invalidate different things: a render assembles both artefacts from a fresh template, a placement changes the page without changing the prose. `7b` used to sit in the required list and in neither class, so a verdict taken before placement still counted as current. **Stage 5 is deliberately NOT held to placement** - nothing re-runs the personas after it, and a blocking rule no build can satisfy is how a check gets waived by whoever holds the delivery; what placement changes is figure content, and that is read at 3d, by the review band through the figure sheet, and at 7d against the placed page. **Delivery fails unless at least one Stage 6-class verdict - a Stage 6 record or the 7d confirming read - postdates the newest placement** (section 31). `Test-Pipeline.ps1` proves both halves: placement makes 7c stale, and re-running 7c and 7d clears it.

**3. Ledger honesty.** Each stage appends its own real start and end timestamps **as it completes**. **Two records in different stages sharing a timestamp to the second fail** as the mechanical signature of retroactive batch-writing. The one tunable is that same-second rule, and it needs a documented carve-out for stages that genuinely finish within a second of each other: **record sub-second precision and compare start AND end**, which is enough to separate a real coincidence from a batch flush.

**4. Stage 8's record must enumerate which mandated sweeps actually ran**, and a substituted script must record what it does **not** cover. **No report may state measured counts unless it postdates the final gate run and every artefact it describes.**

**The failure it exists to catch - found in passing, and caught by nothing.** One build delivered a guide dated 04:34 against ten spine files rewritten between 05:23 and 05:24, so **the delivered artefacts were 50 minutes older than the spine they render**. A report written at 05:19 asserted counts "taken from the delivered files after the last remediation round". Seventeen ledger records were flushed in eight writes, with three records sharing each of three timestamps. There was **no Stage 8 record at all**. And a Stage 6 verdict from 02:03 still counted as current after placement at 03:47 - which is the exact hole section 31 closes from the other side.

---

## 35. Gate fixtures, hygiene, portability and allow-list discipline - blocking

**Runs at** Stage 0 (fixtures, hygiene, portability), Stage 4 (source scoping), and continuously over every gate's allow-list. **Blocks.** **Invoked** `scripts\Assert-GateFixtures.ps1 -SkillDir $SkillDir` and `scripts\Assert-GateHygiene.ps1 -BuildDir $out`. These are the enforcement of the five rules at the top of this file.

**Both specified, not yet implemented.** Until they exist: **fixtures** are performed piecemeal - `scripts\Test-Pipeline.ps1 -SkipOffice` plants a word-form variant for the registry gate, omits every degrading parameter for the two rules gates, and drives the ledger through missing, skipped, stale, `n-a`, partial and stale-figure-sheet states (47 checks, passing on 3 September 2026); `Check-Identity.ps1 -SelfTest` plants a forbidden token in a copy of a real part and verifies the plant landed. `Check-FigureMirror.ps1`, `Check-FigureLeakage.ps1`, `Check-Figures.ps1`, `Test-SpineRead.ps1` and `Get-RtoProfile.ps1` have no seeded-defect fixture in the skill, so a clean result from any of them is a result rule 2 says not to trust yet. **Hygiene and portability** are performed by nobody: `Test-FigureConsistency.ps1` still scans every `.ps1` in the build directory behind a filename-regex exclusion, which is the behaviour this section says was replaced, and no script scans a gate for a literal unit code, RTO code or hex. **Allow-list discipline** is performed by `Get-GateAllowList` in `Lib-GateCommon.ps1`, which refuses an entry with no reason, for the gates that read their allow-lists through it.

**FIXTURES.** Every gate must be shown to FAIL on a seeded-defect fixture before any clean result from it is trusted, **and the plant must itself be verified to have landed** (rule 2).

**HYGIENE.** The registry scans only files **DECLARED as content sources**, rather than every `.ps1` in the build directory behind a filename-regex exclusion. A remediation script that must quote the literal it deletes marks a `# gate-exempt:` region the scanner strips. *The failure:* remediation scripts sitting in the build directory poisoned the gate that was supposed to police them, and the exclusion list was a hand-maintained regex of script names.

**PORTABILITY.** Fail any promoted gate containing a literal unit code, RTO code, CRICOS code, provider number or six-digit hex (rule 5).

**ALLOW-LISTS.** Every entry lives in the versioned registry beside the rule it weakens, never as a script parameter default, carries a written reason, and is surfaced to the audit as evidence (rule 3).

**A build-local `Check-` or `Test-` script that is not a copy of a skill script must record why a new gate was needed.**

**False-positive control.** All four are regex or file-existence checks.

**The gates that printed green over live defects, which is the whole case for this section.** The crossover sweep over 766 foreign fills. The caption checker whose advertised failure was unreachable, in a script with no caller. `Test-FigureConsistency` exiting 0 with **no rendered text gated at all**, because `-DocText` was simply omitted by the runner - it is an optional `[string[]]`, and `foreach ($p in @($DocText))` over `$null` iterates nothing and exits clean. A spine-read checker documenting a MISSING output it never implements. A mirror gate holding its allow-list as a script parameter default. Four check scripts hard-coding one unit, one brand and one build's counts. **And the ledger records that the first plant attempt was a no-op that proved nothing and passed** - which is why rule 2 is worded as it is.

**What was deliberately NOT adopted here, and why it costs no coverage.** A proposed meta-check would have failed "a gate whose check-set is a hand-typed list where a source-of-truth map exists". Deciding whether a literal *ought* to have been derived is a judgement, not a mechanical test, and a gate that guesses at that is exactly the crying-wolf gate this file forbids. **The implementable half is kept in full**: the banned literal classes above, plus every gate printing its check-set size and naming the map it derived from (rule 1). A check-set of three where the map holds nine is then visible in the log without anyone having to judge anything.

---

## 36. The long-stage output contract - blocking

**Runs at** Stage 0 as policy, enforced at Stage 5 and 6, at 6b, at 7b-i and at 7d. **Blocks.** **Invoked** by the orchestrator around every long-running judgement stage.

**`Assert-LongStageOutputContract` is specified, not yet implemented.** There is no script; the contract is a policy the orchestrating agent applies by hand - create the file first, check it is non-empty inside the deadline, keep the heartbeat, resume from disk. Nothing asserts any of it, so a judgement stage that writes at the end fails exactly as the third audit below did, and only its absence from the ledger says so afterwards.

**Every long-running judgement stage creates its output file and writes its header and scope section BEFORE analysis begins**, then appends each section as it completes. The orchestrator asserts the file exists and is non-empty within a short deadline of the stage starting, keeps a **heartbeat** so a dead run is detected in seconds rather than at the deadline, and **on restart the stage resumes by reading what it already wrote**.

**Independence, scope and isolation are untouched.** Only *when bytes hit disk* changes.

**The failure it exists to catch.** One build's third audit ran **three times**: two runs died on transport errors mid-analysis having written **nothing**, inside a 31-minute window. The successful run survived only because it was restarted with instructions to write the report first and append as it went - and **its addendum, written after the main body, is what widened the leak from five guide figures to six assessed tasks across both documents**. A stage that writes only at the end loses everything it found, including the finding that mattered most.

---

## 37. What is deliberately not gated, and why that costs no coverage

Three proposed checks were rejected on purpose. Each is recorded here so the next builder does not add them back without reading the reason.

**"No bare numeral may appear as a literal in any prose field", enforced at write time.** Rejected. In a teaching resource it fires on every legitimate "Topic 1", "step 3", "two of the three", and the friction is paid by seven parallel agents fighting a refusing writer - whose predictable response is workarounds. The coverage it reaches for is **fully retained by section 17's disposition sweep**, which is enumerating rather than preventive and produces a work order instead of a fight.

**"Any n-gram present in an assessor guide and absent from every learner document", unscoped.** Narrowed, not dropped - see section 14. The unscoped version fires on legal quotations, instrument titles, recipe names and shared boilerplate, and a builder learns to ignore it inside one build. The actual leak surface is the model-answer and benchmark regions, and Stage 1's typed parse identifies them.

**"A meta-check that fails a gate whose check-set is a hand-typed list."** Rejected; see section 35 for the reasoning and for the implementable half that was kept.

**And one thing that is not a rejection but a boundary.** Fuzzy duty-phrase clustering (section 26) and near-miss paraphrase matching (section 18) **block nothing**. They report with the anchor, and a reader decides. That is rule 4, and it is what keeps the whole set credible: a gate that blocks on a guess is a gate that gets switched off.
