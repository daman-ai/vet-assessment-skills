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

**Read the Script column honestly.** A name marked **Status: NOT YET IMPLEMENTED** is a specification: no file of that name exists under `scripts\` and no function of that name is defined in any script there (re-checked against the directory listing on 8 September 2026). The marker is written in one fixed form, per row and per bullet, never per section - `**Status: NOT YET IMPLEMENTED** - performed today by: <what exists>` - so a reader and a script read the same sentence; `Invoke-Stage0.ps1` reads its Stage 0 members' status out of this table by that marker. The section in the last column says what performs that check today, and where the answer is *nobody*, it says so.

**Read the Stage column as BAND MEMBERSHIP.** It records the runner bands a gate belongs to - the same set its own `# GATE: stages=` header declares - because `Assert-GateFixtures -StaticOnly` reconciles the two and FAILS a header that drops a band this column names. Where a gate is also invoked directly at a pipeline stage that has no runner (Stage 3 at write time, the Stage 3b exit, Stage 3d, Stage 4c, a Stage 7 round), that fact is written in the Gate column and in the gate's own section, and it is not a stage key here.

**Nothing marked is removed from this file**, because the plan is to build it - but a rule nobody can execute must say so, or a builder reads this table as a list of things that ran. *The failure:* a builder read an earlier version of this table, recorded Stage 0 as `pass`, and had run two of its eight gates. The mirror failure is just as expensive and this revision found it too: on 8 September 2026 this file was naming eight gates that do not exist AND marking seven landed gates "not yet implemented", so it was wrong in both directions at once. The **BEING IMPLEMENTED** marker an earlier revision used is gone: all four scripts it covered are on disk.

| Stage | Gate | Script | Blocks | Section |
|---|---|---|---|---|
| S0-RTO | RTO profile pack resolves and validates | `scripts\Get-RtoProfile.ps1 -Rto <id> -Check` (`Assert-RtoProfile`) | yes | 29 |
| 0 | The RTO profile SCHEMA compiles, and every check-set Assert-RtoProfile derives from it is non-empty | `scripts\Invoke-Stage0.ps1` (`schema-compile` member, over `assets\rto-profile.schema.json`) | yes | 29 |
| 0 | Renderer contract compiled into the spine schema | `Assert-RendererContract` - **Status: NOT YET IMPLEMENTED** - performed today by: see section 21 | yes | 21 |
| 0 | Palette resolves as a total function over a closed role enum; on a CROSS-BRAND build a role that maps to itself THROWS | `Get-BrandPalettePairs` in `Set-ResourceBrand.ps1` throws on an unresolved role (no standalone `Resolve-Palette` yet) - the self-map rule fires only when the pack's templates.brand differs from the target brand | yes | 29 |
| 0 | Every styled sub-skill accepts an injected palette | `Assert-DownstreamPalette` - **Status: NOT YET IMPLEMENTED** - performed today by: nobody; the palette is passed to `docx-images` by hand and nothing asserts it was accepted | yes | 29 |
| 0, 1, 2, 3c, 4, 7c | Every gate fails on a planted defect that is verified to have landed | `scripts\Assert-GateFixtures.ps1` (landed 4 Sep 2026; `-StaticOnly` is the band member in every one of those bands, the full plant channel is a detached background report); further cover from `scripts\Test-Pipeline.ps1` and `Check-Identity.ps1 -SelfTest` | yes | 35 |
| 0 | Gate hygiene, portability and allow-list discipline | `scripts\Assert-GateHygiene.ps1` (landed 4 Sep 2026) | yes | 35 |
| 0 | Long-stage output contract declared | `Assert-LongStageOutputContract` - **Status: NOT YET IMPLEMENTED** - performed today by: nobody; the contract is a policy the orchestrating agent applies by hand | yes | 36 |
| 0 | Generation endpoints probed for quota | `scripts\Probe-GenerationEndpoints.ps1` | **no** | 30 |
| 0 | Every library the build calls actually loaded | `scripts\Invoke-Stage0.ps1` (`library-load` member, over `scripts\Lib-Resolve.ps1`) | yes | 29 |
| 1 | One canonical corpus, every pack document extracted exactly once | `scripts\Assert-CorpusComplete.ps1` (landed 4 Sep 2026; proves fidelity, not just presence) | yes | 20 |
| 1, 2 | Pack self-consistency hazards raised and dispositioned | `scripts\Assert-PackSelfConsistency.ps1` (landed 4 Sep 2026; undispositioned hazard blocks; `-Stage 1` records the count-vs-grid arm DEFERRED with its reason because `grids.json` is a Stage 2 product, `-Stage 2` fails on an absent one, an unknown `-Stage` is exit 2) | yes | 20 |
| 3c | Assessor-only leakage sweep, its shingle set derived from the corpus on every run | `scripts\Check-FigureLeakage.ps1` - there is no separate `-Derive` step and no Stage 1 run; Stage 1's only job for this gate is to have extracted every document into the corpus | yes | 14 |
| 2, 3c, 4, 7c | Registry seeded with authority class and resolving provenance, then every authored assertion | `scripts\Assert-Provenance.ps1` (landed 4 Sep 2026; `-SeedOnly -Stage 2` reads no spine and writes `provenance-seed-report.json`, `-Stage 7c -DocText <guide>,<deck>` reads the extracts) | yes | 18 |
| 2 | Withhold register, `grids.json`, gate-only assessor cells and one agent pack per sub-section, all DERIVED from the assessed response cells | `scripts\New-WithholdRegister.ps1` | yes | 16 |
| 2, 3c, 4 | Identifier namespaces do not collide with the pack's, and every cross-reference resolves | `scripts\Assert-IdentifierNamespace.ps1` (landed 4 Sep 2026; `-SeedOnly -Stage 2` reads no spine and writes `identifier-namespace-seed-report.json`; `-Stage 2` without `-SeedOnly` is refused by name) | yes | 28 |
| 3 | Every agent write validated against the compiled schema | `New-SpineWriter` - **Status: NOT YET IMPLEMENTED** - performed today by: see section 21 | yes | 21 |
| 3c | Spec renderability, whole-spine arm (the write-time exact arm is **Status: NOT YET IMPLEMENTED** - performed today by: this same whole-spine run, one stage later) | `scripts\Assert-SpecRenderable.ps1` (landed 4 Sep 2026; `-BuildDir`, no per-file write-time mode) | yes | 22 |
| 3c | Prompt lint, run at the Stage 3b exit before any generation spend and again as a band member | `scripts\Assert-PromptLint.ps1` | yes | 30 |
| 3c | THE SPINE GATE BAND - every check whose inputs are already on disk, fanned out | see section 12; `scripts\Run-SpineGates.ps1` (landed 3 Sep 2026; membership DERIVED from each gate's own `# GATE: stages=` header, never hand-listed); shared helpers in `scripts\Lib-GateCommon.ps1` | yes | 12-28 |
| 3c | Readability, count-based arm, on the spine's prose fields | `Test-Readability` spine arm - **Status: NOT YET IMPLEMENTED** - performed today by: nobody before the render; `Test-Readability` takes an unpacked `.docx` and no wrapper feeds it spine fields, so first detection is the Stage 4b run | yes | 11b |
| 3d | Figure sheet review (judgement, narrow) | reader, not a script | yes | 13 |
| 3c | Figure sheet CUT from the spine and fingerprint-stamped, in the band's phase 3 and only on a green band; read at 3d | `scripts\New-FigureSheet.ps1` | yes | 31 |
| 4 | Every blocking gate from one entry point, every parameter threaded and printed | `scripts\Run-Gates.ps1` | yes | 33 |
| 4 | Extract stamping and the channel manifest | `scripts\Get-DocText.ps1` stamp (FIGURES / CHANNELS / SOURCE) | yes | 31 |
| 4b | Readability, on the rendered document | `Test-Readability` | yes | 11b |
| 4, 7c | Brand applied at Stage 4c, and the mark PROVED on every artefact - re-run at 7c and again at 8 | `scripts\Check-Identity.ps1` (`Assert-BrandCrossover`) | yes | 29 |
| 5 / 6 | Review band (personas, flow pass, clean-room audit) | judgement | yes | 10 |
| 6b | Finding arbitration before any work order | `scripts\Test-Finding.ps1` (specified as Assert-FindingProvenance) | yes | 19 |
| 7 | Enumerate before fixing | `scripts\Assert-EnumerateBeforeFix.ps1` (landed 4 Sep 2026) | yes | 32 |
| 3c | Figure sheet re-cut from the corrected spine at every Stage 7 round, by re-running the band | `scripts\New-FigureSheet.ps1` (a direct re-cut takes `-BandResults` and refuses a spine the band did not pass) | yes | 31 |
| 7b-i | Every generated image reviewed before it is placed | judgement, ledgered as `7b-i` | yes | 30.3 |
| 7b | Resolved palette passed into the artwork sub-skill | `Assert-DownstreamPalette` - **Status: NOT YET IMPLEMENTED** - performed today by: nobody; a wrong-brand repaint is seen only by the 7c crossover sweep, after the fact | yes | 29 |
| 7c | FULL re-gate after the last mutation | `scripts\Assert-FullRegateAfterMutation.ps1` (landed 4 Sep 2026; derives the 7c set from the runner plan, gates.md and SKILL.md Stage 7c) | yes | 33 |
| 7c | Placed drawings: alt text, figure numbering, caption-to-slot | `scripts\Check-Figures.ps1` | yes | 33 |
| 7d | Confirming audit read, scoped to what placement changed, images re-checked against final content | judgement, with a verdict | yes | 30.3, 31 |
| 7e | Deck restyle changed no text - a sorted multiset per SHAPE, plus the slide count against the SOURCE deck, speaker notes verbatim and still present, every image relationship resolving, nothing off the slide, and every typeface one the restyle sets | `scripts\Test-DeckStyle.ps1` | yes | 8b |
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

**And "structural" is narrower than it sounds: no gate reads the deck's APPEARANCE.** Grep every `Test-`, `Assert-`, `Check-` and `Run-` script for `srgbClr`, `solidFill`, `sz=` and `a:off`, and the only hits are in `Test-DeckStyle.ps1`. That gate guarantees exactly what section 8b names: text preserved as a sorted multiset per shape, the slide count against the source, speaker notes verbatim and present, every image relationship resolving, nothing off the slide, and every typeface one of the two the restyle sets. It reads no fill and no type size.

Everything else in `references\deck-style.md` — the eight palette hexes, the ground-by-slide-role map, `FA984C` never being a card fill, the whole type ladder including the 9.5 pt footer, the card depth caps, minimum height, padding and the 0.45 content position, the outline weight, the corner radii and jitter, the picture column widths and gutter, the card floor, chip baseline and footer baseline — is **enforced by construction in `Restyle-Deck.ps1` and by no gate at all.** Those constants exist in exactly one place, that script; change one and nothing in this file fails. (`Check-Identity`'s palette-hexes arm does not close this: it is derived from the brand role map and proves another RTO's hexes are ABSENT, never that these are present or correct.) The one exception is the animation contract, where `Add-DeckAnimations.ps1` reopens the saved deck and fails the run unless PowerPoint reports `EntryEffect` 3954 on every slide.

Whether to close the rest of that gap is a separate decision. What is not optional is that the blind-spot list say so.

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
| `-Rto`, `-Cricos` | Document-property identity | `document properties name RTO nnnnn - confirm it is this RTO (pass -Rto to make this blocking)`. A gate that asks the caller to confirm it themselves is not a gate. The approved template was cloned from another RTO and still carried that RTO's code in `docProps`, where nothing on a slide shows it and it travels with the file wherever it goes |

All four now fail, naming the parameter, unless `-AllowPartial` records the omission. **The stage that runs the complete gate set threads every one of them**, from the RTO profile pack — `-TemplatePath $rtoProfile.DeckTemplate`, `-NumberSlotByLayout (Get-DeckNumberSlotMap -Profile $rtoProfile.DeckLayouts)`, `-Rto $rtoProfile.RtoCode`, `-Cricos $rtoProfile.CricosCode` — and so does the 7c re-gate, which is the same call with `-AfterArtwork` on the guide side. See SKILL.md Stage 4 and Stage 7c.

---

## 8b. Deck restyle content preservation - blocking

`scripts\Test-DeckStyle.ps1`. Invoked directly at Stage 7e, which has **no runner**, so it carries no `# GATE:` header and appears in no runner plan - the same arrangement `Assert-EnumerateBeforeFix.ps1` and `Test-Finding.ps1` already use. Run it yourself, twice, and the second run is the one that counts.

`Assert-GateFixtures` therefore reports a blocking NO-HEADER for it, as it does for those two and for both runners. **Do not close that by adding a header.** `# GATE: stages=7e` was tried: `7e` is outside `Run-SpineGates`' vocabulary (1, 2, 3c, 4, 7c) and `$script:LedgerStages` in `scripts\Stage-Ledger.ps1` has no `7e` row, so the header turns one finding into two - an unknown-stage HEADER and a PLAN finding for a band no runner will ever pick up. The real fix is a `7e` row in the ledger stage table, which SKILL.md already writes records against; until that exists, the honest state is a blocking gate the reconciler cannot place.

**Not one word may change.** The restyle moves shapes, recolours them, resizes type and changes z-order over content that has already passed the pack's gates and the two-way question reconciliation. Text is compared as a sorted multiset **per shape**, not per run: PowerPoint merges identically-formatted runs on save, and a run-level comparison reports five lost and one added on every footer.

`-Source` is the untouched `render\` copy of what `Invoke-Render` wrote; `-Sample` is the restyled deck. Without the copy there is nothing to compare against. It runs before the animation pass and again after it, because the animation pass is a PowerPoint round-trip and a round-trip rewrites the package from PowerPoint's own model.

Every rule it carries is blocking, including the two that were not: the slide count is measured against the **source** deck (taken from the sample it was the sample compared with itself, and could never differ), and a shape hanging off the slide **fails** rather than warning. `-EdgeTolerance` declares any slack explicitly and defaults to 0.

`-AllowRemoved` is its only relaxation. It names exact lines the caller authorised for deletion, must be identical to what `Restyle-Deck.ps1 -DropCoverLines` was given, and the gate prints each one on every run so the deletion stays visible rather than becoming invisible. It lives as a parameter default rather than in a versioned register, which rule 3 above would prefer.

**`-SelfTest` plants the defect before you believe the pass.** It builds minimal packages in temp and proves the gate turns red on each rule: a changed run, a dropped slide, dropped speaker notes, a shape off the right edge, a shape off the top edge, a table off the bottom edge, an unexpected typeface, and an unauthorised deletion. Run it after any change to the gate.

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
| A stage in the pipeline is recorded `skipped` | `skipped` is an honest status and it is allowed to be WRITTEN — it just does not ship |
| A stage is recorded `n-a` anywhere but the artwork stages, or with no note | `n-a` is accepted at delivery only on `7b-i` and `7b`, and only where a Stage 2 record in the same ledger records the artwork decision as no-go. Everywhere else it is a hard problem naming the stage: three blocking stages were once recorded `n-a` plus a note and passed delivery. A stage that does not apply must still say why |
| A record carries partial gate rules with no note | A gate run with `-AllowPartial` left blocking rules unrun (section 7). That is allowed and recorded, and it costs the same written reason an allow-list entry costs |
| A record has no known span, or a blocking stage's `started` equals its `ended`, or two DIFFERENT stages end in the same second with an unknown or overlapping span | Section 34 item 3. The append time `utc` is not a span and no rule reads it as one |
| A delivered artefact's sha256 no longer matches the newest 4/7c results payload that judged it, or it was written after that run | Section 34 item 1. The staleness proof comes from files and hashes, never from clock order in a ledger |
| Stage 4b, 5 or 6 predates the newest Stage 4 or 7 record | Those stages **re-render** from a fresh template. A verdict taken before the last render describes a document that no longer exists |
| Stage 7c or 7d predates the newest 7b or 7c record | **Placement** is a mutation of the page, and what follows it must postdate it — see section 34 for why Stage 5 is deliberately not on this line |
| No Stage 6 or 7d record postdates the newest placement | No build ships on a verdict issued against a document that had no figures in it |
| Stage 6 or Stage 7d has no `verdict` | An audit without a stated judgement is not an audit, and a confirming read that confirms nothing in particular is not a confirmation |
| Stage 6's or 7d's verdict reads `Not Compliant` | Remediate and re-audit |
| The figure sheet's stamped spine fingerprint does not match the spine | Section 31. Every reviewer downstream of a stale sheet read figure content the document no longer carries, while the ledger recorded that the figures were read |

**The stage table is `$script:LedgerStages` in `scripts\Stage-Ledger.ps1`, and it is the only copy.** `$script:LedgerRequired`, `$script:LedgerBlocking`, `$script:LedgerOrder`, `$script:LedgerRenders`, `$script:LedgerPlacements`, `$script:LedgerStaleAfterRender`, `$script:LedgerStaleAfterPlacement`, `$script:LedgerPostPlacementRead`, `$script:LedgerVerdict`, `$script:LedgerArtwork`, `$script:LedgerTerminal`, `$script:LedgerConditional` and `$script:LedgerScripted` are DERIVED VIEWS of that table and cannot drift from it. Read them from the script; do not transcribe them here. The table also carries a **`Script` column** naming the runner that writes `<stage>-results.json` - `Invoke-Stage0.ps1` for 0, `Run-SpineGates.ps1` for 1, 2 and 3c, `Run-Gates.ps1` for 4 and 7c - and a stage with a Script entry cannot be recorded `pass` without that file.

A transcribed stage list is how this gate came to enforce a pipeline that no longer existed: the rewrite added `3c`, `3d`, `4c`, `6b`, `7c` and `7d` as blocking stages and added none of them here, so **a build that skipped all six passed `Test-StageLedger` and delivered** — no spine gate band, no figure adjudication, the brand never proved, a false finding straight to a work order, no post-placement re-gate, and no verdict ever issued against a document containing figures. `7b-i` — generate and review the artwork — was added at the same time for the same reason (section 30.3). Five hand-listed arrays are five copies to keep in step, which is why there is now one table and twelve views of it.

Stage 7 is **conditional**, and the table is the single owner of that rule: it is required when a Stage 6 or 7d record carries `round > 0` or a verdict below the best one in the closed vocabulary (read from `Merge-AuditFindings.ps1` by AST), or when a Stage 6b record carries a non-empty work order; it blocks whenever it is present. It is deliberately **not** in the unconditional required set. A build with no findings needs no remediation round, and requiring one would push builds into inventing work. Stage `7b` is required but is **not** blocked when recorded `skipped`: with no API key, or where the user declines the artwork spend, a build legitimately delivers with the prompts in place and says so.

**Record each stage as it finishes, never from memory at the end.** A ledger written at the end records what was intended, which is exactly the thing this gate exists to distrust.

```powershell
. "$SkillDir\scripts\Stage-Ledger.ps1"
New-StageLedger -BuildDir $out -Unit $code | Out-Null
$t0 = (Get-Date).ToUniversalTime().ToString('o')
# ... run the stage ...
Add-StageRecord -BuildDir $out -Stage '6' -Name 'Clean-room audit' `
                -Status pass -Findings 3 -Verdict 'Partially Compliant' `
                -Started $t0 -Ended ((Get-Date).ToUniversalTime().ToString('o'))
Test-StageLedger -BuildDir $out [-InProgress] [-SpineDir <dir>] | Write-StageLedgerReport
```

`-Started`/`-Ended` are ISO 8601 UTC, sub-second; omitted, they are DERIVED from the stage's results file (`startedAt`, `ranAt`, `wallClockSeconds`), and with neither source the record carries `spanKnown = false`. `Add-StageRecord` also takes `-Machine` (a sha256 from a stage whose own writer produced the evidence; refused on a stage that has a results file, and requires `-Round` >= 1), `-OperatorNote`, `-ClearancesApplied`, `-FigureSheet` and `-SpineDir`; `-Round` may no longer go backwards for a stage. `Test-StageLedger` returns `.Reported`, `.Machine`, `.Stage7`, `.Required`, `.InProgress` and `.GeneratedNote` beside `.Ok`/`.Problems`, and **the Stage 8 note is generated from `.GeneratedNote`, not typed**. `-InProgress` excludes ONLY the terminal stage 8. **There are four statuses and there is no fifth**: a dispositioned failure is a `pass` whose `-ClearancesApplied` entries the report prints every time it runs.

Exit codes are the house convention: **0 pass, 1 finding, 2 refused (input missing), 4 self-test failed**. The old `exit 6` for a ledger finding is gone. `Stage-Ledger.ps1 -SelfTest` proves the file against itself.

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

**The 3c run: Status: NOT YET IMPLEMENTED** - performed today by: nobody before the render. `Test-Readability` takes an unpacked `.docx` (`-WorkDir`, `-Part`) and reads its XML; no wrapper yet feeds it the spine's prose fields, so first readability detection is the Stage 4b run on the rendered document and the artwork-prompt confound that run scripts around is still live.

**The 3c run is an ADDED run, not a moved one, and the distinction is the whole point.** On the spine, prompt text and body prose are separate fields and cannot be confused — which deletes outright the artwork-prompt confound the rendered gate had to script around by stripping prompt paragraphs from a copy of the file. **The Stage 4b run on the rendered document is untouched**, because a spine measurement and a rendered measurement make different claims: the renderer joins, wraps, tables and captions the prose, and a document can fail one and pass the other. Nothing here is faster by being weaker; it is earlier as well as, never instead of.

**Where a rule genuinely differs for this document type it belongs in `references/learner-guide.md` under *Carve-outs*, and nowhere else.** The readability block is shared with the assessment skill and must not be forked — two copies of a 300-character cap drift, and the first drift ships as a guide that passes its own gate and fails the RTO's.

---

## 12. The spine gate band - Stage 3c, blocking, fanned out

**Runs at** Stage 3c: after authoring closes, before the first render, concurrently with background artwork generation. **Blocks.** The whole band re-runs unchanged before every Stage 7 re-render. **Invoked** from one entry point that fans out and joins: `scripts\Run-SpineGates.ps1 -BuildDir $out`.

**`Run-SpineGates.ps1` landed 3 Sep 2026** (`-BuildDir`, `-SpineDir`, `-UnitExtract`, `-Profile`, `-ResultDir`, `-Stage`, `-Only`, `-MaxJobs`, `-TimeoutMinutes`, `-Serial`, `-NoPlantChannel`, `-SelfTest`).

**Membership is DERIVED, and the member list is not repeated here.** It is the roster in `Run-SpineGates.ps1` plus every script whose own `# GATE: stages=` header declares the stage, read at run time. A roster member whose header omits `3c` is **REFUSED** ("a member cannot leave the band by editing its own header"). A script with no header yet gets a printed `REPORT: no GATE header` line and is treated as `stages=3c` - never a silent skip. **Where a header is** matters: at column 0, below the `<# #>` doc block, above `[CmdletBinding()]`. A `# GATE:` line inside a doc comment, or inside a here-string below `param()`, is **not** a header and is not read as one.

`Assert-GateVisualCount` (P0-11) and `Assert-GateFixtures -StaticOnly` (P0-13) are 3c members. The fixtures member is the one member NOT handed `-BuildDir`: `-BuildDir` starts the plant channel, which is a background report and never a band member, and a fixtures copy without `-StaticOnly` is REFUSED by name.

**Phase order.** Phase 1 fans out. Phase 2 is the grid disposition alone, over the reports phase 1 produced, and **the interim band verdict `3c-band-verdict.json` is written at the join**. Phase 3 is the figure sheet, cut only on a green band over an unmoved spine.

Every member is called with only the parameters its copy declares; an absent, refusing, throwing or timed-out member is a FAIL naming the reason, never a skip; a missing `unit_extract.md` refuses the whole run (exit 2); a spine whose fingerprint changed during the run fails. A member that exits 0 while a **blocking arm** on its `ARMS:` line neither ran nor was declared not applicable is recorded FAIL ("arm not run: `<name>`"), and `Test-SubSection -All` exiting 0 while any per-file `gate.json` it wrote says fail - or was never written, or disagrees with the wrapper - fails by name in the wrapper and again in the runner.

**`-Stage 1|2|3c`.** Stages 1 and 2 are the **seed** bands over the corpus, the contract and the registry; membership comes from the same headers, nothing is hand-listed, and a stage no script declares is REFUSED (exit 2) with a `<stage>-results.json` recording FAIL and no member - never a pass. Every arm of a seed run is labelled `seed`, and a seed result never counts as 3c evidence.

**`-Only` is a partial run and cannot stand as evidence.** It writes `3c-results.partial.json` and `3c-band-verdict.partial.json`, leaves `3c-results.json` and `3c-band-verdict.json` untouched, never cuts the figure sheet, and **exits 3 even when every selected gate passed**.

The band prints **UNPROVEN** beside every member the newest `gate-fixtures.<hash>.json` did not record as PROVEN, and starts the full fixtures plant channel as a **detached background process after the band**, keyed on a hash of `scripts\*.ps1`, which it never waits for. `-NoPlantChannel` suppresses the start and nothing else.

**Exit codes:** 0 pass, 1 a member failed / was refused / timed out / is unavailable, 2 a usage error (no unit extract at 3c, or a stage no script declares), 3 a partial run, 4 the self-test failed. It writes `3c-results.json` (per-gate exit code, seconds, verdict and summary; the slowest member; wall clock against the serial sum) and per-gate logs under `<result dir>\logs`; **the results-file key list is documented in the header comment of `Run-SpineGates.ps1`, and that file is the reference shape for `Run-Gates`.**

Measured on the reference build, 4 Sep 2026, at 21 members: 157 s wall clock against 741 s run one after another, 21 per cent of the sum, the slowest member being the sub-section wrapper at 153 s - so the ten gates added that day cost 28 s of wall clock rather than 410. Any row of the table below that no gate's header binds to `3c` is performed by nobody at 3c, and the 3c record must list it as not run rather than let the band's pass stand for it.

**On the reference build two members now exit 2 rather than printing green, and that is the P0-09 measurement.** `Assert-CitationConsistency` - `provisos` is starved: `figures.json` carries figures whose required value holds a digit and no derivable qualifier, so the dropped-caveat arm swept nothing, and the refusal names `figures.json`. `Assert-ScenarioClock` - `deliveries` is starved: no learner-facing corpus document yields an item-bound delivery, so the produced-after-delivery arm compared nothing; the refusal names the delivery input and offers `contract.json gateArms.Assert-ScenarioClock.deliveries` with a written reason as the declared-not-applicable route. **Both are resolved by supplying the input in its declared shape, never by narrowing the rule.**

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
| Prompt lint (again, after its Stage 3b exit run) | 30.1 |
| Gate fixtures, static arms only | 35 |

### The arm roster, and how a runner reads it

Every gate declares its ARMS and prints one roster line. The contract lives in `Lib-GateCommon.ps1` - `Reset-GateArmRoster`, `Register-GateArm -Name x [-Blocking]`, `Write-GateCheckSet`, `Complete-GateArm -Name x -State ran|empty|declared-n-a`, `Write-GateArmRoster`, `Assert-GateArmsComplete`, `Get-GateDeclaredNa` - and every gate carries the same shape:

> **Arms.** Named arms are blocking or advisory. Each ends `ran` (size > 0), `empty` (a refusal, exit 2, naming the input) or `declared-n-a` with a written reason read from `contract.json` `gateArms.<gate>.<arm>`. The gate prints one `ARMS: name|blocking|state|size|findings;...` line both runners parse, and the roster is written into its report as `arms`.

**A runner reads the roster line CASE-SENSITIVELY** - `ARMS:` in capitals, the shape `Write-GateArmRoster` prints. Gates also print a human line `arms: 4 registered, 2 blocking, all complete`, and reading that as a roster reported "ARMS cell does not parse" against six PASSING gates on a real band run. Both runners use `(?-i)`.

Blocking arms, per gate, as the scripts now print them:

| Gate | Blocking arms | Advisory arms |
| --- | --- | --- |
| Assert-Terminology | spine-cells, locked-terms, authority-classes | acronyms, glossary-variants, ambiguity |
| Assert-CitationConsistency | sentences, cited-sentences, provisos | duty-clusters |
| Assert-ScenarioClock | two-production-dates, production-after-delivery | loose-time-attachment, outside-production-run, interval-vs-registry |
| Assert-DeckParity | spine-files, require-strings, benchmark-entries, slide-notes | no-notes-exemptions, table-shape, count-claims |
| Assert-SpecRenderable | spine-files, renderer-layouts, visual-specs | slot-cross-references |
| Assert-PromptLint | person-nouns, required-negatives, route-a-prompts, cover-visual, manifest-parity | subject-classes (blocking only when the profile declares `imageFraming.subjectClassMandatory`) |
| Assert-SpineCounts | spine-files, counted-prose, word-floors, pack-questions | - |
| Test-Spine (whole-spine) | spine-files, front-matter-files, front-matter-fields | - |
| Test-SpineRead | renderer-read-set, spine-files, content-fields | - |
| Test-DeckRules | slides, placeholder-vocabulary, docprops-identity, printed-number, plan-structure | overset-text |
| Check-Identity | identity-strings, palette-hexes, artefacts | - |
| Test-FigureConsistency | registry, sources, rendered (blocking at 7c) | deck-must |
| Test-GridDisposition | report-freshness, grid-disposition, channel-coverage | clearances, unmatched-entries |
| Check-FigureLeakage | spine-channels, blocking-runs | marking-vocabulary, reported-runs, rendered-extracts |
| New-FigureSheet | the spine's visual entries (one blocking check-set) | - |

**`-BuildDir` is no longer `[Parameter(Mandatory)]` on five gates.** `Assert-Terminology`, `Assert-CitationConsistency`, `Assert-ScenarioClock`, `Test-SpineRead` and `Check-Identity` (`-Path`) previously declared their main input mandatory, which made `-SelfTest` unrunnable without a build - PowerShell refused the call before the script started - and a mandatory parameter PROMPTS, so a gate that prompts inside a runner's job hangs instead of failing. Each now refuses the absent input BY NAME with exit 2 in the body, and `-SelfTest` synthesises its own build. Every documented invocation is unchanged; what changes is that the self-tests can be asked to run at all.

**Two checks were REPLACED, not removed.** `Assert-Terminology`'s old "every derived check-set is empty" exit 2 - which fired only when locked terms AND authority rules AND acronyms were all zero - is now three separate blocking arms, each refusing on its own, which is strictly stronger: an empty locked-terms list no longer hides behind a non-empty acronym list. `Assert-PromptLint`'s old "no Route A prompt on the spine" exit 2 is now the `route-a-prompts` blocking check-set: same exit code, now on the roster and named in the refusal text.

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

**Runs at** Stage 3c over every channel of the spine, Stage 4 over the rendered extracts (`-DocText`), and 7c against the placed document. **Blocks.** **Invoked** `scripts\Check-FigureLeakage.ps1 -BuildDir $out -ReportPath <file>`. **There is no separate Stage 1 derivation step and no `-Derive` switch**: the script derives the shingle set from the canonical corpus on every run (`Get-ShingleSet`), prints the size of each set it derived and names what it derived it from, and `-ReportPath` writes the complete hit list - blocking and reported - to a file, because a finding cannot be closed against a list nobody has. Stage 1's only job for this gate is to have extracted every document into the corpus; a document not extracted is not swept, which is section 20's failure. Its `# GATE:` header declares `stages=3c; requires=BuildDir,ExcludeText; 7c: DocText`.

**The sweep includes the spine's front matter (P0-11, 8 Sep 2026).** `Get-GateSpineFiles` excludes `front.json`, `cover.json` and `deckframe.json` by default, and this gate kept that default: `deckframe.json`'s frame slides - the deck's opening, section and closing furniture, authored by the same hand as every other slide - and `front.json` had never been text-gated by anything. Both are swept now; the gate passes `-IncludeFrontMatter -Exclude @('cover.json')`, so `cover.json` is the ONE exclusion (`Assert-PromptLint` owns the cover), and the exclusion is printed beside the check-set line.

**A spine file the sweep cannot read is a finding, not a skip**: an empty, whitespace-only or unparseable file used to fall through the loop in silence, and a file that had lost its content swept clean by having no text in it.

Arms: `spine-channels` and `blocking-runs` block; `marking-vocabulary`, `reported-runs` and `rendered-extracts` report. One `ARMS:` line is printed. An empty blocking check-set - no assessor-only document in the corpus, no learner-facing document, or no blocking phrase - is exit 2 naming the input, where it used to be an uncaught `throw`. `-BuildDir` is no longer `[Parameter(Mandatory)]`: a mandatory parameter PROMPTS, and a gate that prompts inside a runner's job hangs instead of failing; it is now a refusal that names itself.

`-SelfTest` plants an assessor literal in `deckframe.json` (reported, naming the file), the same literal in `front.json` (reported) and in `cover.json` (correctly not swept), a derived marking phrase in a learner channel, a unit quotation that must NOT be a leak, an empty spine file, a missing `-ExcludeText` file and a corpus with no assessor guide. 17 checks, passing 8 Sep 2026.

**The test.** Normalise the assessor-only guides and the learner-facing documents out of the one canonical corpus. Any **n-gram of 8 to 15 words present in an assessor guide and absent from every learner-facing document** is candidate leakage - by definition it is content the learner is not meant to have, whatever it looks like and whatever field it sits in. Swept over EVERY text channel the build produces: body prose, callouts, tables, figure cells, captions, alt text, slide bodies, chips and speaker notes, **with the channel list enumerated from the renderer contract** so a channel cannot be added to the build without being swept (rule 1).

**A companion sweep catches assessor-only marking vocabulary**, with the term list derived from the assessor guides' own section headings rather than typed.

**The blocking set is deliberately narrowed, and the narrowing is the whole design.** An undifferentiated shingle set fires on legal quotations, recipe names, instrument titles and shared boilerplate that an assessor guide and a Learner Guide may both legitimately carry - and a gate that cries wolf is a gate a builder learns to ignore within one build. So **blocking is scoped to n-grams occurring inside the assessor guides' model-answer and benchmark regions**, which Stage 1's typed parse identifies structurally, and n-grams also occurring in the unit extract or in cited instrument text are excluded as legitimately shared. Everything outside that scope is **reported, not blocked**, with its anchor.

**Allow-list:** required, in `figures.json`, one written reason per phrase.

**The failures it exists to catch.** Five consecutive bullets of an assessor's model answer reproduced *in the assessor's own order* in the guide's running prose - which the column-heading test structurally could not see, because it was prose, not a grid. Verbatim runs of 9 to 31 words against the assessor guides across nine worked-example tables. And speaker notes reading "the benchmark this task is marked against", which is assessor vocabulary on a learner-facing slide.

**Why it did not exist before.** The registry gate (section 11) catches a **registered** assessor-only string. This catches the **unregistered** case, which is the one nobody thought of - and the reason it was written late is the same reason as section 13: the figures were never read.

---

## 15. Coverage and leakage - ONE gate, ONE verdict - blocking

**Runs at** Stage 3c, again at Stage 4, again at every Stage 7 remediation, again at 7c. **Blocks.** **Invoked** `scripts\Test-GridDisposition.ps1 -BuildDir $out -ShapeReport <file> -CoverageReport <file> -MirrorReport <file> -NotBefore <run start, ISO 8601 UTC>`. All four inputs are required: an absent one is exit 2 naming it. `-NotBefore` is the runner's own start time, and a report generated before it is a previous round's and is refused.

**Landed 3 Sep 2026 as `Test-GridDisposition.ps1`.** It returns one verdict per (sub-section, grid) over the check-set derived from `withhold-register.json`, reading three channels - the shape mirror's prose channel (`shape-mirror-report.json`), the row-coverage floor (`row-coverage-report.json`, whole-spine run only - a per-file coverage report is refused, because the floor that disposes a grid is the whole-spine one) and the table channel (`figure-mirror-report.json`). **None of the three is optional, and none is believed on sight (P0-08, 8 Sep 2026).** Each must carry `spineFingerprint` (v2, equal to the spine's fingerprint right now), `generated` (UTC ISO 8601, at or after `-NotBefore`) and `mode` = `whole`; a report that is absent, unparseable, unstamped, cut from another spine, cut in file mode or cut before `-NotBefore` is exit 2 **naming the file, the channel and its producer**. Before this, Run-Gates started the disposition beside the producers it reads, so every 4 and 7c verdict was cut from the previous round's reports.

A grid is disposed by teaching every row to the floor AND answering none beyond the register's allowance; it is cleared only by a written reason in `figures.json` "mirrorAllow", surfaced to the audit as evidence, and never by editing a gate.

**A grid absent from all three channels is NOT PROVEN**, naming the channels that are silent about it, and a `mirrorAllow` entry does not clear it: a written reason adjudicates a leak someone read, it cannot stand in for a channel that never looked. An absent key used to be read as zero, which disposed grids on no evidence at all.

An entry in ANY of the three reports that does not resolve to a register grid is listed in `unmatched[]` with its channel and printed - never silently dropped.

Arms: `report-freshness`, `grid-disposition` and `channel-coverage` block; `clearances` and `unmatched-entries` report. One `ARMS:` line is printed on every path, refusals included, and the roster is written into `grid-disposition.json`.

`-SelfTest` builds a synthetic build, drives the real `Check-ShapeMirror.ps1` to prove the stamp this gate reads is the stamp that gate writes, and plants: prior-round reports, a missing shape report, a missing mirror report, an unstamped report, a `mode file` report, a report older than `-NotBefore`, an absent and an unparseable `-NotBefore`, a grid no channel examined, and an unmatched entry. 23 checks, passing 8 Sep 2026.

Measured on the reference build: 35 grids, 26 disposed, 1 cleared with its reason printed, 8 NOT DISPOSED - and the table channel is what raised that count from 4, so before it was wired the gate was blind to half its own evidence.

**All three producers stamp their reports**, and the stamp is what makes freshness checkable: `spineFingerprint` (v2), `generated` (UTC round-trip `o`), `mode` (`whole` for a directory run, `file` for `-SpineFile`) and `spineFiles` (the list they read), plus their `arms` roster. All three accept `-ReportPath` and `-Produces`; `-Produces` alone IS the report path, and `-Produces` naming a different file from `-ReportPath` is exit 2 naming both, because a runner reading one path while the gate writes another is the stale-report defect the stamp exists to catch.

**The rule.** For every typed assessed grid, the gate returns **one verdict over the mapped sub-section**: every row label must be TAUGHT in the prose (coverage) **AND** no figure, slide, chip, caption, alt text or speaker note may present those rows as a completed grid (leakage). Structural matching on normalised row labels, not wording. A mirroring visual must carry an explicit disposition - `withheld`, or `cleared, reason: ...` - so consistency follows from the derived list rather than from an author remembering.

**Why one gate and not two, which is the point of the section.** Coverage pressure and leakage pressure act on **the same assessed table**, in opposite directions. Gated separately, remediating one manufactures the other. *The failure:* round 1 correctly found sixteen assessed cells taught as four paragraphs, and six rows compressed to four on a slide, and demanded every row be taught and all six be shown. Those two remediations were carried out correctly - and **they are precisely what round 3 found as the two worst leaks in the build**, one figure and two slides, whose own speaker note records the intent. A full audit round was spent turning one defect into the other. One gate, one verdict, or the build oscillates.

**False-positive control.** The coverage arm is label presence in prose; the leakage arm is section 13's mirror test. The combination cannot fire on anything neither arm fires on.

**Allow-list:** required, in `figures.json`, one written reason per cleared slot, surfaced to the audit.

**Also catches** the inconsistency case: withholding applied at three figures and not at five others in the same build.

---

## 15b. Three defect classes no current gate can see

The last build's audits found three defects that passed every mechanical check in this file and would pass them again today. Each is recorded here so a builder knows where the net has holes until the planned gate exists, and reads those parts of the document by eye instead of trusting a green result. **Two of the three gates have since landed** - `Check-ShapeMirror.ps1` and `Check-RowCoverage.ps1`, both 3 Sep 2026, both 3c band members with their own planting self-tests. **(c)'s heading test is Status: NOT YET IMPLEMENTED** - performed today by: a reader, who checks every figure whose column headings match an assessed task's and treats a row labelled by time, day, run or batch as an assessed row in disguise.

**(a) Numbered-row grids.** Workbook tasks 2(b), 2(c), 3(a) and 3(b) hand the learner a grid whose rows are numbered, not labelled - the learner supplies the row content. The mirror gate (section 13) matches on normalised row LABELS, so a guide table that fills such a grid shares no label with the assessed one and the gate cannot fire: there is nothing to match. The leak is the SHAPE - the same column headings, the same row count, the assessed columns filled. *Gate, landed 3 Sep 2026:* **`Check-ShapeMirror.ps1`** - match a spine table to a typed grid on its column-heading set and row count where the grid's first column is a numeral, and report the anchor for 3d exactly as section 13 does. Calibrated on the pre-round-4 spine (blocks on Tasks 11(a), 4(a)/(b), 9(a) and 6(a); 25 of 25 audited rows detected) and on the round-6 spine (silent where that audit was clean; four real residuals found); the recall and false-positive counts are in the script header, and a row is FULL only when ONE channel answers every assessed cell.

**(b) Prose written to the shape of the model answer.** Knowledge Task 4's model answer is six rows of four indicators each, in the assessor's order. The guide taught it as prose: six paragraphs, four indicators each, in that order, with no fifteen-word run verbatim. The leakage sweep (section 14) blocks on 12-word shingles and reports on 8-word ones, and the mirror gate reads tables, so prose that paraphrases every cell and keeps the assessor's structure passes both. *Gate, landed 3 Sep 2026:* **`Check-RowCoverage.ps1`** for the under-teaching arm, with the assessor's-ORDER arm of this finding caught by `Check-ShapeMirror`'s ROW ORDER channel - for every typed model-answer region, count the assessed rows whose distinctive content words all fall inside one paragraph of the mapped sub-section, in the assessor's order, and report a sub-section that covers every row in order as an anchor. The two write `shape-mirror-report.json` and `row-coverage-report.json`, which `Test-GridDisposition.ps1` folds into one verdict per grid, cleared only through a written `mirrorAllow` reason.

**(c) A figure row keyed by day or run rather than by the task's row label.** Figure 7.1.4 carried an "On this run" row: the values the assessed task asks for, under a heading the task does not use. The mirror gate matched no label and passed it. *Planned gate:* **the heading test in `Check-FigureMirror`** - where a figure's column headings match an assessed grid's, treat every row as a candidate regardless of its label, and report the anchor. Until it exists, a reader checks every figure whose column headings match an assessed task's, and treats a row labelled by time, day, run or batch as an assessed row in disguise.

**What the three share, and why they are listed rather than fixed here.** Every one is a structural match on something other than the row label - shape, order or heading - and every one is decidable from the spine and the typed grids, which is why each has a planned gate rather than a permanent reader. A reader is the stopgap, not the design; and a stopgap that is not written down is a hole nobody is watching.

---

## 16. The withhold register - blocking, build-wide

**Landed 4 Sep 2026 as `scripts\Assert-WithholdRegister.ps1`.** The posed-question exemption is resolved STRUCTURALLY to exactly one field path on this build (`selfCheck.questions`, derived from the spine schema because that node carries the deliberately withheld `answerGuide`), with a compiled renderer contract taking precedence the moment one exists and a contract-declared list accepted only with a written reason of at least twenty characters. Every other channel is swept, so a channel added later is swept BY DEFAULT rather than exempt by default - the opposite of the arrangement that let a leak survive three rounds. Channels are enumerated from the spine's own node types and classed guide-side or deck-side from the renderers' ASTs: 25 channels, 8,597 strings, 35 spine files on the reference build.

**What it found there, and why section 16 is build-wide rather than per-document:** 31 withheld rows answered outside a posed question, and **34 rows answered in ONE artefact only** - among them a Knowledge Task row answered on a slide while the guide withholds it. Neither document is wrong on its own, which is exactly why a per-document sweep cannot see it. The largest cluster is one grid with 38 anchors across guide and deck under an allowance of 0.

**Two calibrations recorded in the script header rather than as an allow-list.** A hit requires a model bullet's COMPLETE content-word set and a floor of three content words: at two words the sweep fired on 817 cells that were mostly the guide legitimately teaching a row, and a gate that noisy is switched off within a week. And **27 register rows have no model row in the assessor cells, so they are NOT CHECKED** - the gate prints them prominently instead of letting its pass stand for them, because a check-set that silently shrinks is the failure this file was rewritten against.

**Runs at** Stage 2 to derive, Stage 3c to enforce, 7c across both finished artefacts. **Blocks.** **Invoked** `scripts\New-WithholdRegister.ps1 -BuildDir $out` at Stage 2 to derive; `scripts\Assert-WithholdRegister.ps1 -BuildDir $out` at 3c, and `-Stage 7c -DocText <guide>,<deck>` at 7c, to enforce. `-Stage 7c` with zero extracts is exit 2 naming `guide_gate.txt` and `deck_gate.txt`.

- "**across both finished artefacts**": **Status: NOT YET IMPLEMENTED** - performed today by: `Run-Gates.ps1 -AfterArtwork` phase 3, which runs `Test-FigureConsistency`, `Check-FigureLeakage`, `Assert-WithholdRegister` and `Assert-FigureCoverage` against the two `Get-DocText` extracts (`guide_gate.txt`, `deck_gate.txt`). No gate reads the finished `.docx`/`.pptx` themselves at 7c except `Check-Figures` (drawings, captions and alt text) and `Check-Identity`.

**Rendered lines are no longer swept in one channel called `rendered`.** Each extract's lines are stamped `rendered:guide` or `rendered:deck` from the extract's own name, so the one-artefact-only rule can fire on a delivered document; an extract naming neither artefact is refused. The guide/deck split is now derived at FUNCTION scope (`Invoke-GuideRender` / `Invoke-DeckRender` in `Invoke-Render.ps1`) before the file-scope renderer glob - on the fixture that moved 11 of 12 channels off 'both' - and a run where NO channel attributes to a single artefact is a refusal naming the renderer files searched.

**The Stage 2 derivation step is `scripts\New-WithholdRegister.ps1 -BuildDir $out [-PackDir <pack>]`**, and it exists. It reads the pack's typed task JSON, the contract's questionMap, the learner-facing corpus and the unit extract, and writes four things nobody types: `grids.json` in the corpus dir the gates resolve (the mirror gate loads it in preference to its regex parse - and the proof that matters is that WITHOUT it the gate passes a planted answer grid green, and WITH it the gate catches it); `withhold-register.json` per sub-section with kind (labelled | numbered | records | lookup | freeText), items, subjects, unassessedSubjects, allowance and a numeric shape; `assessor-cells.json`, gate-only, carrying the model bullets and their content-word sets; and `agent-pack\<sub-section>\` holding exactly what a content agent may see. On the reference build: 35 grids (27 labelled, 5 numbered, 3 records), 31 prose parts, 28 packs, and a self-sweep proving none of 1,710 assessor-authored strings appears in any agent-facing file. **`agent-pack\_shared` is INSIDE that self-sweep, not excluded from it**, and may hold only the files the run produced (`learner-docs\*.txt` and the unit extract); anything else is named and the pack is removed. The generated block of the register, `grids.json` and every pack slice carry `contractSha256` and `sharedSha256`. `New-WithholdRegister` gained `-SelfTest` (exit 4 on failure); `-BuildDir` is still mandatory and is not read in that mode. It carries no `# GATE:` header because it is a producer, not a band member.

**The enforcement arm is implemented in two places, neither named `Assert-WithholdRegister`.** In-loop, `scripts\Test-SubSection.ps1 -File <spine file>` runs a relocation arm: any table sharing two or more headings with one of the sub-section's register grids fails on a row whose label is an assessed item with an assessed column filled, and for numbered grids reports a cell that names one of the grid's `subjects` together with two or more content words of that subject's model row (read from the gate-only assessor cells; never printed). At 3c, `Check-FigureMirror.ps1` counts answered rows against the register's per-grid `allowance` (0 where unassessed subjects exist, else 1) with the numbered-grid subject rule. First sweep of the reference spine under the register: 23 of 28 sub-sections pass; five fail because the register's allowance 0 is tighter than the old one-exemplar rule (Workbook 1(c), 2(a), 3(b); Knowledge 6(a), 5(b)), and one "relocated" example names an assessed subject after all. Those are content findings for the next round, and they are exactly what this arm exists to find before an auditor does.

**Derived, never typed** (rule 1). Stage 2 builds the withhold set from the corpus: every assessed response cell in the learner-facing tools, plus every value a figure or passage declares withheld, plus every value computable from an assessed task's own inputs. A register somebody types is a register that is short.

**A withheld value is a BUILD-WIDE fact, not a per-document one.** The gate sweeps every channel of every artefact and fails on any occurrence outside a posed-question context, and fails specifically where **one artefact fills a row the other marks withheld**.

**False-positive control.** Exact value matching against a derived set. The one judgement - "is this a posed-question context?" - is decided structurally by the containing node type from the renderer contract, never by prose sentiment.

**Allow-list:** required for the legitimate single exemplar, one written reason each.

**The failures it exists to catch.** A guide that says at 1.2 that it "deliberately does not do them for you" and prints the withheld quantity two paragraphs earlier, twice more at 1.3 and again at 3.2 - the audit had to write this sweep out by hand as remediation advice. And a deck slide that fills the row the guide's own figure withholds as "Your turn": the deck quietly defeating the guide's withholding decision, which is the failure mode that makes this build-wide rather than per-document.

---

## 17. The unregistered figure sweep - blocking

**Runs at** Stage 3c on the spine, again before every Stage 7 re-render, and at 7c on the rendered text of both artefacts. **Blocks.** **Invoked** `scripts\Assert-FigureCoverage.ps1 -BuildDir $out`.

**Landed as `scripts\Assert-FigureCoverage.ps1`.** Its `# GATE:` header declares `stages=3c,4,7c; requires=BuildDir; 7c: DocText`. **The rendered arm is optional at 3c and REQUIRED at 7c**: at `-Stage 7c` an absent `-DocText` is a refusal naming both extracts, `guide_gate.txt` and `deck_gate.txt`. `Test-FigureConsistency.ps1` checks registered figures only - the whitelist this section says must be inverted - so an unregistered figure passes it exactly as the batch weight in section 19 did, and this gate is the inversion.

**A known defect is recorded rather than tuned away (P1-02).** `Assert-FigureCoverage -SelfTest` prints one KNOWN-DEFECT line and counts it in neither tally: `7.45 am` is harvested as `45 am`, because the harvester cuts at the decimal point, so the work order names a figure that is not in the document. The disposition is right and the string is not. **The bounded harvester and the closed unit tails are Status: NOT YET IMPLEMENTED** - performed today by: today's harvester, whose behaviour the self-test asserts as it stands rather than narrowing the harvest to go green. The fix is P1-02.

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

**Landed 4 Sep 2026 as `scripts\Assert-Provenance.ps1`.** Its `# GATE:` header declares `stages=2,3c,4,7c; requires=BuildDir; 2: SeedOnly; 7c: DocText`. `-SeedOnly -Stage 2` checks registry rows against the corpus with no spine and writes `provenance-seed-report.json`; a missing `figures.json` is exit 2 naming it. `-Stage 7c -DocText <guide>,<deck>` reads the extracts, and zero extracts at 7c is exit 2 naming both.

Two arms: every registry entry proved to resolve in the source its locator names, and every *source noun + reporting verb + quantity* sentence proved to carry a locator that resolves. Dispositions are RESOLVED, NEAR-MISS, SOURCE-ABSENT, UNRESOLVED and NOT RUN, and only UNRESOLVED blocks - a stale locator over a correct figure is a different defect from a fabricated one, and collapsing the two would make the gate useless in both directions. `-PackDir` is how a SOURCE-ABSENT row is fixed: by adding the source, not by cutting the sentence. Assessor evidence is never printed - on the reference build 512 evidence lines came from assessor documents and all 512 were recorded as a withheld reference to a document and line.

**A spine file carrying no `provenance` block is now REPORTED by name** (`spineFilesWithoutProvenance` in the report), rather than passing by being silent. **A registry row whose locator begins `DERIVED` is recorded NOT RUN with its reason** - never UNRESOLVED and never a pass - until P1-04 lands; that is why the disposition list has five entries rather than four.

**The V-class arm no longer passes vacuously.** A build whose contract names no venue used to satisfy the V-class test on every page, because an empty token list made the test true by having nothing to fail. Zero venue tokens with at least one V-class row is now a refusal naming `contract.json build.brand / build.tradingName / scenario.employer / scenario.venue`.

**Its first real run returned 216 UNRESOLVED and every one checked was FALSE** - composed rows ("50 portions of 350 Gms, 5 buckets of 3.5 L, 17.5 L in total"), abbreviations where the registry says *teaspoons* and the card says *tsp*, and values sitting in a pack document the locator did not happen to name. Three rules took it to 1: the verbatim test runs on the QUANTITIES inside a row rather than on the sentence around them; the whole corpus is searched before anything is called an absence; and a document matched only by a CITATION carries a mention of the instrument, not the instrument, so it reports SOURCE-ABSENT rather than resolving. That is the difference between a gate people use and a gate people switch off, and it is recorded here because the next gate written against this corpus will meet the same three.

**What it found: nothing fabricated, one wrong locator.** 540 provenance rows, 273 resolved, 202 near-miss, 117 source-absent, **1 unresolved** - a "6 hours in total" cooling figure that is correct arithmetic on the Code's own two stages and states its derivation, but whose locator points at recipe cards instead of the Standard, which is not in the corpus. The fix is the locator or an extraction, never the figure. 202 near-misses is a real adjudication queue for Stage 3d, dominated by coarse locators rather than defects, and it was deliberately NOT tuned down - tuning a gate to reduce its own count is how gates get quietly weakened.

**The mandate-versus-recommendation arm cannot run on a corpus with no legislation in it.** On the reference build 145 L-class rows carry a legal block, 103 come back INDETERMINATE and 29 cite no instrument at all, because the Food Standards Code, the Food Act and the Regulations were never extracted. The arm is proven on fixtures, both halves quoted. **A build that teaches from legislation must extract that legislation into the corpus**, or the highest-risk defect this document type produces - a recommendation dressed as a legal requirement - is checked by nobody. The V-class arm reports rather than blocks, because "is this sentence the venue-ownership statement" is a phrase match standing in for a judgement.

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

**Both landed 4 Sep 2026.** `Assert-CorpusComplete.ps1` proves FIDELITY as well as presence - coverage, character ratio and a tail window, so a truncated extraction that keeps its header cannot pass as complete, which is the shape that would let every downstream gate report clean about text it never saw. It exits 5, not 0, when a pack ships only formats it cannot open: complete but unprovable is not a pass. `Assert-PackSelfConsistency.ps1` reports hazards WITHIN the pack and fails on any that carries no written disposition, so a known pack defect is consciously accepted and reported to the RTO rather than silently absorbed. Its `count-vs-grid` arm is deliberately ASYMMETRIC - a question asking for more than its grid holds always fires, a grid one row longer never does, because the one real instance was a log whose own stem said the extra row was pre-filled.

**What `-PackDir` means, decided 4 Sep 2026: the folder holding the DELIVERED assessment instruments - the tools an assessor and a learner receive.** Not the build tree, not templates, not staging copies. On the reference build the contract's recorded `build.packDir` pointed at the assessment skill's whole build tree, so the gate refused with exit 2 and listed the subdirectories that hold documents rather than guessing - which is the correct behaviour, and the reason the convention now has to be written down. A build whose contract records the tree must be re-pointed at the delivered set before Stage 1 can run. The consequence is deliberate: templates and working copies are NOT corpus, so nothing downstream may cite them as a source, and a figure that resolves only in a staging copy is unresolved.

**A second extraction is a defect even when both copies are correct.** The reference build carries a `packtext\` extraction of the same four documents beside the canonical corpus, and its two halves were cut from DIFFERENT renditions of the same instruments. Nothing downstream states which it reads, so two gates can disagree while both report clean - section 20's own failure mode in miniature. One corpus, one extraction, and the gate warns on any other text tree that shadows it.

**What neither gate catches, printed on every run rather than papered over.** A figure contradicted in DIFFERENT WORDS - a recipe card's yield against its own method - needs a reader who knows what the number is for. Every automated arm written for it produced noise on a clean pack, which is the failure this section warns against, so the arm was not shipped. The typed assessment parse that sections 13 to 16 and 27 depend on is likewise not emitted here; it is still whatever the Stage 1 agent writes.

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

**Runs at** Stage 0 (compile) and Stage 3 (every write). **Blocks.** **Invoked** `scripts\Assert-RendererContract.ps1 -SkillDir $SkillDir` at pre-flight - a script that does not exist; the writer is the only way content reaches the spine at Stage 3, and it does not exist either. What runs today is `scripts\Test-SpineRead.ps1 -BuildDir $out`, after every write and again across the whole spine at 3c.

Three names in this section are specifications. Each is marked separately, because each has a different performer today:

- **`Assert-RendererContract`**: **Status: NOT YET IMPLEMENTED** - performed today by: `scripts\Test-SpineRead.ps1 -BuildDir $out`, which detects an unread field AFTER the write rather than compiling the contract before it, and by `Invoke-Stage0.ps1`'s `schema-compile` member, which compiles the RTO profile schema only.
- **`Get-RendererContract`**: **Status: NOT YET IMPLEMENTED** - performed today by: nobody. No renderer exports a contract and nothing compiles a spine schema; `Test-SpineRead.ps1` derives the read-set by walking the renderers' PowerShell AST instead, at run time.
- **`New-SpineWriter`**: **Status: NOT YET IMPLEMENTED** - performed today by: `scripts\Test-SpineRead.ps1`, which reports UNREAD and MISSING after the write, and `scripts\Test-SubSection.ps1 -File <spine file>`, the agent's own pre-return check. Agents write spine JSON directly and nothing refuses a write, so an agent that does not run either is not refused. The `kind` and dangling-token classes are performed by nobody at write time; a missing `kind` is discovered at placement, which is the failure section 22 records.

`Test-SpineRead` reports UNREAD and MISSING by parsing the renderers' PowerShell AST, so the two classes that shipped the empty role-play boxes are caught - but after the write, not instead of it. Its `# GATE:` header declares `stages=3c; requires=BuildDir`, so the band runs it; the Stage 3 write-time run is the agent's own.

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

**Runs at** Stage 3c for the whole-spine arm (the exact arm at Stage 3 write time is specified below and not built). **Blocks.** **Invoked** `scripts\Assert-SpecRenderable.ps1 -BuildDir $out`.

**Landed 4 Sep 2026 as `scripts\Assert-SpecRenderable.ps1`**, whose `# GATE:` header declares `stages=3c; requires=BuildDir`. It takes `-BuildDir` and reads the whole spine; **the exact arm at Stage 3 write time is Status: NOT YET IMPLEMENTED** - performed today by: this same whole-spine run one stage later, because the script declares no per-file write-time mode. Every cap and width is read, never typed: `diagram.maxNodes`, `diagram.renderer`, `diagram.typography`, `placement.widthFraction` and `placement.maxHeightCm` from the `docx-images` config, and the page height, margins and `contentWidthDxa` from the RTO profile pack's guide profile. Three typographic estimators are in neither file and are therefore PARAMETERS whose resolved values and sources are printed on every run: `-CellPaddingCm`, `-NodeGapCm` and `-AvgCharEmShare`, with `-NodeHeightCm` overriding the derived per-node height outright. Arms: `spine-files`, `renderer-layouts` and `visual-specs` block; `slot-cross-references` reports. **A declared slot with no spine spec is a SPINE DEFECT and fails**, rather than passing over what the gate cannot see.

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

**Performed by `scripts\Test-Spine.ps1` since 3 Sep 2026**, in whole-spine mode at 3c and in `-File` mode in-loop: word floors from the contract (topic 3000, underpinning knowledge 800, slides 15), the two-way cross-reference against the contract's questionMap, prepared-exactly-once, four visuals per sub-section with Route B specs, empty boxes, ASCII, and a machine-readable result with the file's sha256. Byte-identical result to the build's validator on the reference spine; five planted defects each caught. A standalone `Assert-SpineCounts` is no longer needed. **A standalone scripts\Assert-SpineCounts.ps1 landed 4 Sep 2026 and is NOT a duplicate**, on two points that decide different facts. Its question set is derived from the CORPUS's own extracted text, where Test-Spine's comes from the contract's questionMap - so a question the pack contains and the contract forgot is invisible to one and caught by the other. And it prints the EXCLUDED field complement, 110 field paths on the reference build carrying 10,565 words of artwork prompt text, which is the confound the render-side gate has to script around and the spine simply does not have. It measured the reference build clean: seven Topics from 6,728 to 11,740 words against a floor of 3,000, all 28 underpinning blocks between 1,113 and 3,012 against 800, and 74 pack questions prepared in both directions. Its topic-BALANCE arm is implemented but prints NOT RUN, because no wordFloors.balanceTolerance is declared anywhere and the gate will not invent one - its pass does not cover that rule and says so.

**Test-Spine's whole-spine walk gains a front-matter arm set.** `front.json`, `cover.json` and `deckframe.json` are enumerated with `Get-GateSpineFiles -IncludeFrontMatter` and swept for parse and charset like every other file, and each is checked against the fields the renderers read from it - derived at run time from the AST of `Invoke-Render.ps1`, `Build-Guide.ps1` and `Pptx-Blocks.ps1`, following the variable each file is loaded into, never from a list typed into the gate. On the reference spine that derivation yields 19 field names (front 9, deckframe 9, cover 1). Arms: `spine-files`, `front-matter-files` and `front-matter-fields` block. `Assert-SpineCounts`'s own arms are `spine-files`, `counted-prose`, `word-floors` and `pack-questions`, all blocking.

**Test-SubSection's self-test counts skipped cases outside the pass tally.** A case that did not run is SKIPPED, and the summary reads "N of M cases RUN passed, K SKIPPED and not counted: `<names>`". The `mirror plant (real file)` case is skipped unless `-PlantFile` is supplied - it used to be recorded as a pass having planted nothing, which is the shape rule 2 exists to refuse.

Word floors per Topic and per Underpinning knowledge block, and the two-way question cross-reference against references **derived from the corpus**, measured on the spine JSON **where prompt text and body prose are separate fields and cannot be confused**. It also asserts that words-per-topic tracks criteria-and-knowledge-points-per-topic within a declared tolerance.

**It uses the same exclusion rule the render gate uses, and it does not replace that gate.** It moves FIRST detection of a content shortfall to before a render, which is the expensive part of the build.

**The failure it exists to catch.** A topic-balance finding that had to reason around its own measurement surface, because a large part of the measured difference was **artwork prompt text** sitting in the rendered document. The build's gate runner strips prompt paragraphs from a copy of the rendered file to work around a confound that measuring the spine deletes outright. Plus every Stage 4 word-floor failure, which section 3 warns is the expensive one - and which is far cheaper to find before the render than after it.

---

## 24. Terminology - blocking on the exact arms, reporting on the stylistic ones

**Runs at** Stage 3c, one pass over every authored string. **Blocks.** **Invoked** `scripts\Assert-Terminology.ps1 -BuildDir $out`.

**Landed as `scripts\Assert-Terminology.ps1`**, whose `# GATE:` header declares `stages=3c; requires=BuildDir`. The RTO profile pack carries the locked terminology (`assets\rto-profile.<rto>.json`), `Assert-RtoProfile` validates that the list is present and well-formed, and this gate reads it against the spine.

**Arms.** `spine-cells`, `locked-terms` and `authority-classes` block; `acronyms`, `glossary-variants` and `ambiguity` report. The old "every derived check-set is empty" exit 2 - which fired only when locked terms AND authority rules AND acronyms were all zero - is now three separate blocking arms, each refusing on its own. That is strictly stronger: an empty locked-terms list no longer hides behind a non-empty acronym list.

`-SelfTest` **synthesises** a build - a locked term with its `never` proviso, an acronym adoption pair, and a class L figure in the registry - and carries a PLANT ROSTER, one row per BLOCK arm it claims to prove. A plant that cannot be found in the fixture is exit 4 naming its arm ("no plant for arm X"), never a case quietly dropped from the tally. It also proves that a DECLARED terminology block yielding zero locked terms is a `CHECK-SET EMPTY` refusal naming `contract.json terminology`, and that the shipping gate maps it to exit 2. `-BuildDir` is no longer `[Parameter(Mandatory)]`, so the self-test can be asked to run at all.

**One real defect found and fixed in passing.** The gate read `$authRules.Count` on the value returned by `Get-TrmAuthorityRules`, which returns a `List`. PowerShell unrolls a one-element list to the element itself and `[pscustomobject]` has no `.Count`, so a registry with **exactly one** classed figure read as **zero** authority rules. The call is now wrapped in `@()`.

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

**A slide kind on NEITHER notes list is not exempt - silence is never an exemption.** `Assert-DeckParity` treats an unlisted kind as notes-REQUIRED, which is the safe direction, because the alternative is a kind that nobody listed being silently unchecked - the same shape as a blocking rule behind an optional parameter. It found exactly that on the reference build: `outcomes` and `key-terms` sat on neither `deckRules.notesRequiredOn` nor `notesNotRequiredOn`, and eight slides across four topics carried no speaker notes. Both kinds were added to the notes-required list on 4 Sep 2026, so the rule is now declared rather than inferred; the eight slides remain a real content defect. An exemption still costs a written reason in the RTO pack's `noNotesReasons`, and `Get-RtoProfile` fails when the two sets differ in either direction or when a kind appears on both.

**Runs at** Stage 3c, and per-surface again at Stage 4 and 7c. **Blocks.** **Invoked** `scripts\Assert-DeckParity.ps1 -BuildDir $out`.

**Landed as `scripts\Assert-DeckParity.ps1`**, whose `# GATE:` header declares `stages=3c; requires=BuildDir`. **Arms.** `spine-files`, `require-strings`, `benchmark-entries` and `slide-notes` block; `no-notes-exemptions`, `table-shape` and `count-claims` report.

`Test-DeckRules.ps1` is dot-sourced by Run-Gates, and run **as a script** with `-SelfTest` it proves itself on an unpacked deck fixture it builds: a clean deck passes with every arm `ran`; the template's own exemplar sentence left on a slide fails naming the slide; a printed slide number that disagrees with the slide's position fails; a supplied template that harvests no placeholder phrase is a `CHECK-SET EMPTY` refusal naming the template; an empty `-Plan` fails naming `-Plan`. No PowerPoint is needed. The switch is declared `[Alias('SelfTest')][switch] $DeckRulesSelfTest`, for the reason `Lib-GateCommon` states: a dot-sourced script binds its parameters as variables in the CALLER's scope, so a parameter named `$SelfTest` here would set every caller's own `-SelfTest` to `$false`.

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

**Landed as `scripts\Assert-CitationConsistency.ps1`**, whose `# GATE:` header declares `stages=3c; requires=BuildDir`. **Arms.** `sentences`, `cited-sentences` and `provisos` block; `duty-clusters` reports. On the reference build `provisos` is STARVED and the gate exits 2 naming `figures.json`: the registry carries figures whose required value holds a digit and no derivable qualifier, so the dropped-caveat arm swept nothing. That is resolved by supplying the input in its declared shape, never by narrowing the rule. `-BuildDir` is no longer `[Parameter(Mandatory)]`.

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

**Landed as `scripts\Assert-ScenarioClock.ps1`**, whose `# GATE:` header declares `stages=3c; requires=BuildDir`. **Arms.** `two-production-dates` and `production-after-delivery` block; `loose-time-attachment`, `outside-production-run` and `interval-vs-registry` report. On the reference build `deliveries` is STARVED and the gate exits 2: no learner-facing corpus document yields an item-bound delivery, so the produced-after-delivery arm compared nothing. The refusal names the delivery input and offers `contract.json gateArms.Assert-ScenarioClock.deliveries` with a written reason as the declared-not-applicable route. The typed schedule this gate reads from is still whatever the Stage 1 agent writes (section 20). `-BuildDir` is no longer `[Parameter(Mandatory)]`.

Extracts every date, day name and time in scenario text **with the pack identifier it attaches to**, and checks it against the corpus's typed schedule and against itself.

**Blocking:** the same pack-identified item carrying two different production dates within the spine; and an item produced **after** the delivery time the pack's own order form sets for it.

**Report:** stated intervals that violate a registry duration.

**Why the blocking arm is narrow.** Attaching a free-text time to a subject is where a scenario gate would produce noise, so blocking is scoped to scenarios that name the item by its **pack identifier**, which is exact. Everything looser reports with its anchor.

**The failures it exists to catch.** A scenario that places production **after its own delivery deadline**, with the pack's order form setting that delivery for noon on the day the guide has the food being cooked. And one item's production date given as three different dates across four sections, with an internal clash inside one of them.

---

## 28. Identifier namespace and cross-reference resolution - blocking

**Runs at** Stage 2 for the namespace assertion, Stage 3c and Stage 4 for dangling-reference resolution. **Blocks.** **Invoked** `scripts\Assert-IdentifierNamespace.ps1 -BuildDir $out`.

**Landed 4 Sep 2026 as `scripts\Assert-IdentifierNamespace.ps1`**, whose `# GATE:` header declares `stages=2,3c,4; requires=BuildDir; 2: SeedOnly`. Seed mode reads no spine: NS-COLLISION over `contract.identifierNamespace.guideOwns` against `identifierNamespace.packOwns` plus the head-anchored definitions in `withhold-register.json`, written to `identifier-namespace-seed-report.json`. `-Stage 2` without `-SeedOnly` is refused by name.

**The cross-reference resolver is letter-capable** - "Appendix A" resolves and can be reported dangling - and **a vocabulary entry defines an identifier only where the identifier stands at the HEAD of it**, so "Appendix D - Stock on Hand Report, Monday 14 September 2026" defines Appendix D and does not define "Monday 14".

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

**Runs at** Stage 0, resolved once and passed to every consumer; **nothing downstream ever re-resolves by name.** **Blocks.** **Invoked** `Get-BrandPalettePairs` in `scripts\Set-ResourceBrand.ps1`, which throws on an unresolved role, at pre-flight. There is no function called `Resolve-Palette` anywhere in either skill: that name was the design's, this line kept it, and a reader following it would have gone looking for a script that never existed. The stage table (row 0) always named the real one.

**`Resolve-Palette` exists in substance, not as a script.** `Get-BrandPalettePairs` in `Set-ResourceBrand.ps1` now resolves every role under every name it is known by and THROWS on a role it cannot resolve (3 Sep 2026) instead of defaulting to the source brand's own hex - which is the self-map that shipped 766 of the other brand's fills. Proven: ACI and MVC each resolve all nine roles; a palette missing lightFill is refused by name. The crossover sweep prints which roles it excludes as genuinely shared. What is still missing is the Stage 0 assertion that runs this before anything is rendered; today it fires at first use.

**Resolution is TOTAL over a closed role enum.** A role with no match on the supplied object **throws** rather than falling through to a default. **A role that maps to itself throws** - a self-mapping role is an unresolved property name, never a legitimate no-op. Pre-flight additionally fails if the objects the several callers pass carry **differing property-name sets for the same role**.

**The failure it exists to catch, and it is the root of the whole brand defect.** One palette role was named `Fill` on the object the swap actually passes and `lightFill` on the one the lookup expected. The lookup fell through to its own default, mapped the role to itself, and the apply loop skipped it. **Nothing was written and nothing errored** - a silent no-op that left 608 foreign light fills in the guide and 158 on the deck, found about two and a half hours after branding was first reported clean. A lookup that can silently return its own input must assert that it did not.

### 29.3 Downstream palette injection - Stage 0, enforced at 7b

**Runs at** Stage 0 (pre-flight reads each styled sub-skill's config) and 7b (placement passes the palette in). **Blocks.** **Invoked** `scripts\Assert-DownstreamPalette.ps1 -BuildDir $out`.

**Status: NOT YET IMPLEMENTED** - performed today by: the builder passing the resolved palette to `docx-images` by hand at 7b, with nothing asserting that the sub-skill accepted it or that it would throw without one. The only thing that would see a wrong-brand repaint is the crossover sweep at 7c (`Check-Identity.ps1`), after the fact - which is where the 177 header rows below were found.

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

The walk asks for the front matter, so **`cover.json` is linted with everything else**: it plans the guide's first image under the singular name `visual`, and it is a blocking arm of its own.

The gate also reconciles the spine's **Route A count against the artwork manifest's generated-slot count** (default `<build>\images\manifest.json`, overridden with `-ManifestPath`). The manifest's generated slots are counted with the same route predicate the spine is read with, so one definition decides both sides. A mismatch is a finding naming BOTH numbers.

**Absent sub-skill.** An absent manifest is REFUSED BY NAME when the spine declares any Route B visual (the sub-skill is in use) or when `-RequireManifest` is passed. A guide-only build with no diagram kinds prints the absence by name and continues on the spine's declared kinds.

**Arms.** `person-nouns`, `required-negatives`, `route-a-prompts`, `cover-visual` and `manifest-parity` block; `subject-classes` reports `examined = 0` unless the profile declares `imageFraming.subjectClassMandatory`, and it never passes silently. The old "no Route A prompt on the spine" exit 2 is now the `route-a-prompts` blocking check-set: same exit code, now on the roster and named in the refusal text.

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

**Who owns it: whoever launches 7b-i.** Under the serial pipeline the review was an inline step of placement and could not be skipped. Moving generation into the background took the review with it, and a background arm with no owner, no gate row and no ledger record is an arm that can simply not happen while every structural gate passes. So the launcher owns the review, names itself in the record, and **placement at 7b may only use a slot with a passing review record.** An unreviewed image is not placed.

**What it checks, per image, at full scope.** No identifiable face. No lettering, numbers or signage text inside the image. No real brand, logo or trademark. Nothing that contradicts the document: wrong PPE, a non-Australian fitting or plug, unsafe practice - bare hands on ready-to-eat food is a food-safety defect on the page, not a styling quibble - or a subject that does not match the caption and alt text on the spine for that slot. A fail is a regeneration of that slot with its prompt corrected, never a quiet placement. The prompt lint in 30.1 removes the volume this review must wade through; it does not narrow what the review looks for.

**How it is ledgered.** `Add-StageRecord -Stage '7b-i' -Name 'Generate + image review' -Status pass -Findings n`, where `n` is the number of images that failed a first review, so the report can say what the lint saved. `7b-i` is in `$script:LedgerRequired` and `$script:LedgerBlocking`, so a build with no record does not deliver. Where nothing was generated - no API key, or the user declined the spend - it is recorded `n-a` **with a note**, and the ledger rejects an `n-a` without one.

**Heartbeat.** The arm obeys the long-stage output contract (section 36): the review file is created with its header and the full slot list before the first image is looked at, each slot is appended with its verdict as it is judged, a heartbeat runs, and a restart resumes from what is on disk. A review that writes only at the end loses every verdict when the arm dies, and a dead background arm is otherwise invisible - nothing on the critical path is waiting for it.

**An image reviewed against superseded content is re-checked against the final content before it is placed.** The background review judges each image against the spine as it stood at generation time, hours before remediation. Stage 7 edits the spine. So an image passed at hour two against a figure Stage 7 then corrected is an image nobody has checked against what the page now says - and under the serial ordering that could not happen, because the review sat after remediation. Two re-checks close it and neither is optional: Stage 7 step 7 re-reviews every slot whose figure content or prompt changed in the round, regenerates where the prompt hash moved, and records under `7b-i`; and Stage 7d re-checks every placed image against the regenerated figure sheet as part of the confirming read. A slot that fails at 7d is regenerated, re-reviewed and re-placed, and the round is not closed until it passes.

**The failure it exists to catch.** On one build forty-seven of fifty-seven illustrations failed a first review on identifiable faces, and the same review caught two genuine food-safety defects that no prompt check could have seen. The review is worth its cost. What section 30.1 removes is the forty-seven, not the two - and what this section adds is an owner, because the first version of the background arm had none, and the ledger could not tell.

---

## 31. Channel disposition, extract stamping, and the confirming read - blocking

**Runs at** Stage 4 (stamping), Stage 5 and 6 (the review band), Stage 7d (the confirming read) and Stage 8 (delivery). **Blocks.** **Invoked** `Get-DocText` writes the stamp; `scripts\Assert-ChannelDisposition.ps1 -BuildDir $out` enforces it.

- **`Assert-ChannelDisposition`**: **Status: NOT YET IMPLEMENTED** - performed today by: `Assert-WithholdRegister`'s rendered arm, for the withhold channels only. `Run-Gates.ps1` carries the entry and records it `not-implemented` in the results file's `partial[]`, so the stage cannot pass on a gate nobody ran without saying so. The stamping half is implemented and is described below.

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

**The figure sheet** - the spine's visual entries dumped as plain text, one block per slot with rows, caption, alt text, slide bodies and speaker notes - is cut by the 3c band in its phase 3, read and adjudicated at Stage 3d, and it **travels with every later review pack**. That is what lets a reviewer read figure content whether or not a picture exists yet.

**`New-FigureSheet.ps1` inputs and stamps.** `-BuildDir`, `-BandResults` (blocking; default `3c-results.json`, and the runner hands it the interim `3c-band-verdict.json` written at its own join), `-SpineDir`, `-OutPath`. It **exits 2 with no file written** on a band that did not pass, a spine that moved, an empty visual set, or `-Force` without `-ForceReason`; the refusal names the failed members and both fingerprints. Every sheet stamps `SPINE-FINGERPRINT`, `BAND-VERDICT`, `BAND-RESULTS`, `BAND-RESULTS-SHA256` and `BAND-RAN-AT`, and `BAND-FORCED` / `BAND-PROBLEM` on a forced cut. **`Test-FigureSheetCurrent` requires `BAND-VERDICT: PASS`**, compares the fingerprint through `Test-GateFingerprintVersion` (which distinguishes "the format changed, re-cut" from "the spine moved") and treats an EMPTY expected fingerprint as a problem, never a match.

**Its check-set.** `New-FigureSheet` declares one blocking check-set through `Write-GateCheckSet -Blocking -Input "the spine's visual entries in <spine dir>"`, derived from `Get-GateSpineVisuals ... -IncludeFrontMatter` so the cover counts. Zero visuals is `CHECK-SET EMPTY`, exit 2, no file written - not a sheet reporting its own emptiness.

On the reference build the runner refused the cut and the old direct call cut the sheet 19 seconds later from that same failed spine. That route no longer exists.

---

## 32. Enumerate before fixing - Stage 7, blocking, every round

**Runs at** Stage 7, every remediation round. **Blocks.** **Invoked** `scripts\Assert-EnumerateBeforeFix.ps1 -BuildDir $out -Finding <id>`.

**Landed 4 Sep 2026 as `scripts\Assert-EnumerateBeforeFix.ps1`.** The enumerating sweeps it works from are `Test-FigureConsistency.ps1`, which lists every hit across the spine, the declared content sources and both extracts, and `Check-FigureLeakage.ps1 -ReportPath`, which writes its complete hit list to a file. The Stage 7 ledger note still names the hit-list file per finding, because a closure with no file behind it is a sentence, which is the failure below.

**A finding cannot be marked closed without a machine-generated hit list across every content channel of every artefact, produced BEFORE the fix.** The fix must clear the whole list, and **the sweep is retained as a permanent registry rule that re-runs every round**. When an audit finds a defect **class**, the fix is not complete until the sweep has run over every channel and both artefacts, and the channel list it covered is recorded in the ledger.

**Order within the stage: registry first, then the hit list, then the edit.** Patching content before the registry rule exists is how a class-fix becomes an instance-fix.

**Paired rule: a finding closed by deferral to a later stage must register a blocking gate at that stage, and delivery fails if that gate never ran.** A deferral with no gate behind it is a finding that was closed by being written down.

**False-positive control.** It gates the PROCESS, not the content: the assertion is that an enumeration exists and is cleared, which is a file check. No allow-list.

**The failure it exists to catch - it is the shape of an entire audit round.** One finding was corrected in the front matter and the assessment overview and missed in **all eight rows of the cross-reference table and the deck's closing note**. Round 2 states the pattern outright: the remediation landed on the figures and missed the tables, the chips and the closing notes. Five separate findings in that round have the same shape, and one scope-wording defect survived all three rounds by being fixed wherever it was pointed out. Most expensively: an answer-table defect class was fixed in prose at 11:16 and **the identical sweep was never extended to the figure channel until 14:43** - which is the leak that failed the build.

---

## 33. Full re-gate after mutation, and caption-to-slot reconciliation - Stage 7c, blocking

**Runs at** Stage 7c, immediately after artwork placement - the last mutation of both artefacts. **Blocks.** **Invoked** `scripts\Run-Gates.ps1 -BuildDir $out -AfterArtwork` plus the spine band and the crossover sweep.

**Implemented: `scripts\Run-Gates.ps1 -BuildDir $out [-PackDir] [-Brand] [-Variant] [-Rto] [-Cricos] [-UnitCode] [-AfterArtwork] [-AllowPartial] [-SpineDir] [-RequireFresh] [-SkipPlantChannel]`.** It derives the pack references from the pack's own content files, threads every parameter each gate's blocking rules depend on and PRINTS the list at the end so nothing can be omitted silently, REFUSES the leakage gate when `unit_extract.md` is absent rather than letting it degrade, and exits 0 only when every gate passes. On the reference build it reproduces the build copy's result in about 40 seconds against 46 serial.

**The Stage 4 and Stage 7c member list is `New-GateInvocationPlan` in `scripts\Run-Gates.ps1`. It is not repeated in this document.** Each entry carries the phase it runs in, the arguments threaded to it, the ones its blocking rules depend on (an undeclared one REFUSES the entry rather than being dropped) and the report file it must write. Run-Gates reads every gate's `# GATE: stages=` header at run time and FAILS naming any gate that declares itself a member of the stage and is not in the plan. A hand-listed member set in a document is a second source of truth that drifts from the plan the moment either is edited, and it is what let sections 16 to 18 promise a 7c re-run nobody performed.

**The plan runs in three phases:** 1 fan-out (both extracts, the guide, deck, readability, brand crossover, the spine re-verification members and the static fixtures arm), 2 the grid disposition alone - after the three producers it reads have joined, threaded `-NotBefore` set to the runner's start so it cannot read an earlier round's report - and 3 the gates that read the extracts.

**Two results files, and a Stage 4 run can never overwrite the 7c evidence.** A run without `-AfterArtwork` is Stage 4 and writes `4-results.json`; a run with it is 7c and writes `7c-results.json`. Entries the stage cannot run are recorded by name and reason in the results file's `partial[]`, never dropped: `placed` (`Check-Figures`) and the two rendered arms are `not-applicable` before artwork, and `Assert-ChannelDisposition` is `not-implemented`.

**The runner REFUSES (exit 2) and runs nothing** when the spine's v2 fingerprint differs from the one stamped in the newest FULL `3c-results.json`, naming both fingerprints. A spine edited after the band was cut has been gated against no valid band. A `-Only` run's `3c-results.partial.json` is not the band and does not satisfy this.

**Arm rosters.** Every member's `ARMS:` line is parsed by the runner with the same parser and the same result keys Run-SpineGates uses, case-sensitively. A blocking arm that neither ran nor was declared not applicable makes that member FAIL with `arm not run: <name>`, whatever the gate's own exit code was, and both the member and the arm are named in the results file and on the terminal.

**`-RequireFresh` is Stage 8 only:** it runs no gate and writes nothing, and refuses (exit 2) when a delivered artefact was written after the results file that judges it, when its sha256 no longer matches, or when that file's verdict is not pass. Before the Stage 8 record, `Run-Gates.ps1 -BuildDir <dir> -RequireFresh` must exit 0.

**`Assert-FullRegateAfterMutation` landed 4 Sep 2026** and derives the 7c set from the runner plan, this document and SKILL.md Stage 7c. Its arms:

- **Arm I is BLOCKING**, not a warning: a gate that ran before its own input (the spine or `figures.json`) read something the document no longer renders.
- **Arm K:** a delivered artefact newer than the results file that judges it, or whose sha256 no longer matches the one that file recorded. Named with the artefact, the file and both times.
- **Arm H** gains a case: a gate whose only result comes from a run recording `afterArtwork = false` (`4-results.json`) has no 7c evidence, and is named as such rather than reading as a pass.

**Standing rule: any stage that changes what is on the page is followed by the COMPLETE gate set, never a subset.**

At 7c that means all of: guide rules with `-AfterArtwork`; deck rules; readability; the figure registry on **freshly regenerated** extracts of BOTH artefacts; mirror and leakage against the placed document; the derived brand crossover sweep on the finished files; and **caption-to-slot reconciliation**.

**Caption-to-slot reconciliation:** every spine visual slot must have **exactly one** caption in the rendered document, matched on the **caption paragraph style** rather than any text run, and counted **PER NUMBER with no de-duplication before comparison**. Style-scoped matching stops an in-prose cross-reference counting as a caption. The counts come from the spine, never from a literal (rule 1).

**The failure it exists to catch.** Artwork was the last mutation of both artefacts and was followed by **exactly one of five gates**, so the registry's variant-aware sweep never once ran against a document that actually contained figure rows. And the caption checker that was supposed to catch a duplicate caption **de-duplicated its own list before comparing**, making its advertised failure unreachable - in a script that was wired to no caller at all. Both are why the rule is "the whole set" and not "the relevant ones".

---

## 34. Ledger integrity and staleness - Stage 8, blocking

**Runs at** Stage 8, with the render-set constant declared at Stage 0 and enforced at every stage record. **Blocks.** **Invoked** `Test-StageLedger -BuildDir $out | Write-StageLedgerReport`, plus `scripts\Assert-Staleness.ps1 -BuildDir $out`. **Section 10's rules are unchanged; these are added beneath them.**

**Implemented as `scripts\Assert-RenderDelta.ps1` and the per-topic rule in `Stage-Ledger.ps1`.** The delta hashes each topic's guide slice (cut at the Topic headings, front matter as topic 0), its deck slides (by the deck plan, framing slides as topic 0) and its figure-sheet slice, and writes `render-delta.json`. A 4b, 5 or 6 record carrying `-Topics` and `-DeltaSha` is stale only for the topics whose hashes moved since that delta, and `Test-StageLedger` prints the stale set by topic; a record with neither field keeps the whole-artefact timestamp rule unchanged. Proven on the reference build: the round-5-to-round-6 delta found the five topics the touch list named and a sixth the list had missed (one rewritten sentence in 4.3); a planted one-word change reported exactly its topic and arm; re-extracting unchanged files reported no movement, so the stamp sits outside every hash; a scoped Stage 6 record for the changed topics cleared the rule while an unscoped Stage 5 record kept firing the old rule.

**1. Staleness is proven from FILES and hashes, not from clock order in a ledger.** Delivery fails if any delivered artefact's hash or mtime is older than the newest file in the spine, the registry, or any input it renders from. **The ledger was the thing that lied, so the ledger cannot be the witness.**

- **`Assert-Staleness`**: **Status: NOT YET IMPLEMENTED** - performed today by: the delivery-staleness rules implemented inside `Test-StageLedger` in `scripts\Stage-Ledger.ps1`. It recomputes each delivered artefact's sha256 against the newest 4/7c results payload and names both hashes on a mismatch, names an artefact whose last write postdates the run that judged it, names a payload that stamps no `artefacts[]` at all, and holds the spine fingerprint against `3c-results.json`.

**2. Placement is a mutation, held to its own class.** `$script:LedgerRenders` is `4` and `7` and holds `4b`, `5` and `6`; `$script:LedgerPlacements` is `7b` and `7c` and holds `7c` and `7d`. The two classes are separate because they invalidate different things: a render assembles both artefacts from a fresh template, a placement changes the page without changing the prose. `7b` used to sit in the required list and in neither class, so a verdict taken before placement still counted as current. **Stage 5 is deliberately NOT held to placement** - nothing re-runs the personas after it, and a blocking rule no build can satisfy is how a check gets waived by whoever holds the delivery; what placement changes is figure content, and that is read at 3d, by the review band through the figure sheet, and at 7d against the placed page. **Delivery fails unless at least one Stage 6-class verdict - a Stage 6 record or the 7d confirming read - postdates the newest placement** (section 31). `Test-Pipeline.ps1` proves both halves: placement makes 7c stale, and re-running 7c and 7d clears it.

**3. Ledger honesty.** Each stage appends its own real start and end timestamps **as it completes**. **Two records in different stages sharing a timestamp to the second fail** as the mechanical signature of retroactive batch-writing. The one tunable is that same-second rule, and it needs a documented carve-out for stages that genuinely finish within a second of each other: **record sub-second precision and compare start AND end**, which is enough to separate a real coincidence from a batch flush.

- **`Assert-LedgerIntegrity`**: **Status: NOT YET IMPLEMENTED** - performed today by: the span and same-second rules implemented inside `Test-StageLedger` in `scripts\Stage-Ledger.ps1`. It reports a legacy utc-only record, names a record written with neither `-Started` nor `-Ended`, refuses a blocking stage whose started equals its ended, and names any two DIFFERENT stages that end in the same second unless both spans are known and do not overlap.

The carve-out is exactly that last clause, and it is declared rather than assumed: two records of DIFFERENT stages may share an ended-second **only** when both spans are known and do not overlap. `utc` is an APPEND time and no rule reads it as a span; legacy records that carry only one are REPORTED, never accepted. On one build 21 of 33 records sat within 0.1 s of their predecessor, which is a list of intentions, not a record of what happened.

**A PS 5.1 trap this rule paid for, worth carrying into any gate.** `@($listOfObject)` - the array subexpression over a `System.Collections.Generic.List[object]` - throws `Argument types do not match` on PowerShell 5.1.26100, while `foreach`, `.ToArray()`, `[object[]]` and the pipeline all work. It bit the same-second rule: the whole rule threw and checked nothing while every structural test still passed. Use `.ToArray()`.

**4. Stage 8's record must enumerate which mandated sweeps actually ran**, and a substituted script must record what it does **not** cover. **No report may state measured counts unless it postdates the final gate run and every artefact it describes.**

**The failure it exists to catch - found in passing, and caught by nothing.** One build delivered a guide dated 04:34 against ten spine files rewritten between 05:23 and 05:24, so **the delivered artefacts were 50 minutes older than the spine they render**. A report written at 05:19 asserted counts "taken from the delivered files after the last remediation round". Seventeen ledger records were flushed in eight writes, with three records sharing each of three timestamps. There was **no Stage 8 record at all**. And a Stage 6 verdict from 02:03 still counted as current after placement at 03:47 - which is the exact hole section 31 closes from the other side.

---

## 35. Gate fixtures, hygiene, portability and allow-list discipline - blocking

**Both landed 4 Sep 2026** as `scripts\Assert-GateFixtures.ps1` and `scripts\Assert-GateHygiene.ps1`. The hygiene gate takes NO `-Allow`, `-Skip` or `-Exempt` parameter of any kind, because rule 3 forbids exactly that shape: an exemption is a `# gate-exempt: <reason>` region inside the inspected file, every use printed as evidence, and an unclosed or unreasoned region is itself a finding. The fixtures gate's load-bearing behaviour is that a plant which did NOT land is reported UNPROVEN, never PROVEN - the 27 August incident reproduced and caught.

**First full sweep: 7 of 61 gates PROVEN.** Not a scandal, a measurement - and the categories are the work order. Four gates have a `-SelfTest` that passes WITHOUT reading its plant back out of the channel the gate scans, which is the precise shape that once recorded a no-op plant as proof. Seventeen have neither a fixture nor a self-test. Two fixture recipes found nothing to plant into because they guessed spine field names instead of deriving them from the schema, and were honestly reported as not proven rather than as passes.

**A finding from a meta-gate needs its premise checked like any other, and the first one was FALSE.** The sweep's headline was that `Test-FigureConsistency` passed a verified plant of an unregistered figure. It does, by design, and section 17 says so in as many words - the gate enforces a registry and an unregistered figure is the thing section 17 was written to catch. Checked directly on 4 Sep 2026: planting a REGISTERED figure gone stale into rendered text makes it fail with exit 8, naming the figure and the file; planting an unregistered one passes. The defect was in the fixture's claim about the gate, not in the gate. **A fixture harness must derive what a gate claims to catch from the gate's own contract, and where it cannot, report UNPROVEN rather than asserting a failure** - see `references/audit-checklist.md` on arbitration, and the standing rule that a finding contradicting the documented behaviour is the thing to doubt.

**Real portability findings from the same sweep**, each verified against the source before being written here: `Test-DeckRules.ps1` hard-codes one RTO's trading name and its RTO and CRICOS codes while building the template's placeholder vocabulary, so another RTO's template would have its own branding read as unfilled placeholder text; `Check-Identity.ps1` hand-lists ten identity field names that `rto-profile.schema.json` already declares and `Get-RtoProfile.ps1` already reads from it; `Stage-Ledger.ps1` ends on a condition requiring both a switch and a path, so a caller that omits either exits 0 having checked no ledger at all. Twenty-seven presence tests are written as `@($x).Count -gt 0` on a property, which answers YES for a property that does not exist.

**Runs at** Stage 0 (fixtures, hygiene, portability), Stage 4 (source scoping), and continuously over every gate's allow-list. **Blocks.** **Invoked** `scripts\Assert-GateFixtures.ps1 -SkillDir $SkillDir -StaticOnly -ResultDir <dir>` as a band member (and `-BuildDir <lean copy>` for the full plant channel, off every critical path), and `scripts\Assert-GateHygiene.ps1 -BuildDir $out`. These are the enforcement of the five rules at the top of this file.

**Both are on disk.** `Check-Figures.ps1`, `Test-SpineRead.ps1` and `Get-RtoProfile.ps1` have no seeded-defect fixture in the skill, so a clean result from any of them is a result rule 2 says not to trust yet. `Check-FigureMirror.ps1`, `Check-FigureLeakage.ps1`, `Check-ShapeMirror.ps1`, `Check-RowCoverage.ps1` and `Test-GridDisposition.ps1` each carry a `-SelfTest` that plants every defect the file claims to catch, reads the plant back from the fixture before trusting the verdict, and keeps a negative control (8 Sep 2026: 19, 17, 19, 19 and 23 checks, all passing). Further cover: `scripts\Test-Pipeline.ps1 -SkipOffice` plants a word-form variant for the registry gate, omits every degrading parameter for the two rules gates, and drives the ledger through missing, skipped, stale, `n-a`, partial and stale-figure-sheet states; `Check-Identity.ps1 -SelfTest` plants a forbidden token in a copy of a real part and verifies the plant landed. **Allow-list discipline** is performed by `Get-GateAllowList` in `Lib-GateCommon.ps1`, which refuses an entry with no reason, for the gates that read their allow-lists through it.

### 35.1 Two modes, on different paths of the pipeline

`Assert-GateFixtures` runs in two modes and they sit on different paths.

**`-StaticOnly`** spawns no process. It derives the gate set from `scripts\*.ps1`, parses every script, reads every `# GATE:` header and reconciles it against the ledger stage table, this document's stage table and both runner plans, reconciles every fixture recipe against the disk, and reports a BLOCKING gate that has neither a `-SelfTest` switch nor a recipe. Measured on this skill: about 5.5 s over 54 scripts. It is the band member - Run-SpineGates plans it at phase 1 with `-Must @('SkillDir', 'StaticOnly', 'ResultDir')` - and it writes `gate-fixtures.static.json` into `-ResultDir`.

**The full plant channel** (`-BuildDir`, a lean copy) is the strong channel and never sits on a band's critical path. It writes `gate-fixtures.<hash>.json`, where `<hash>` is the sha256 over every `scripts\*.ps1` plus the recipe set, stamped inside the file as well as in its name, so a reader can always tell which scripts a verdict is about. Measured: about 3 minutes for three gates against the SITXINV007 evidence copy. Both runners read the newest such file and print UNPROVEN beside every member it did not prove.

### 35.2 What PROVEN means, and what no longer counts

`FailsOnPlant` is true only when ALL of these hold: the planted run did not time out, it exited non-zero, its output NAMED the plant, the clean arm RAN, and the clean exit DIFFERS from the planted exit. Otherwise the row is UNPROVEN and the reason names BOTH exit codes.

Only **PROVEN** counts toward exit 0. PROVEN-NOCLEAN and PROVEN-SELFTEST are tallied separately and printed, and the tally line says so.

An anchor is at least three characters and must be ABSENT from the gate's clean output. A removal plant has no value to quote back, so its recipe declares an `ExpectRx` that the failing output must match, and that pattern is the anchor instead. (`Check-ShapeMirror`'s recipe uses one: that gate deliberately prints no quotation, because it sweeps assessor-only material, so its anchor is the `ARMS:` roster line showing the blocking full-rows arm ran and found at least one.)

**The exit is split by Blocks.** Exit 0 requires every **Blocks=yes** gate PROVEN. Non-blocking rows and JUDGEMENT-ONLY rows - stage-table rows the table itself records as performed by a reader with a verdict, which no fixture can plant into - are reported and never decide the exit. A FAIL row (an orphan recipe naming a gate that is not on disk, or a gate that does not parse) exits 1 on its own.

### 35.3 The refusal probe is no longer a directory sweep

The bare refusal probe runs only the scripts the ledger stage table binds to a stage, through its `Script` column. `-WhatIf` is added only when the script's `CmdletBinding` declares `SupportsShouldProcess`, read from the syntax tree; a script that does not declare it is probed WITHOUT `-WhatIf` and the row records that, because passing `-WhatIf` to a script that cannot take it is a binding error that would read as a refusal it never made. A script outside the table is recorded NOT PROBED, never as "exits 0 on nothing". This is what stops the probe running `Patch-GuideTemplateGeometry` (it patches a template it resolves for itself) and `Probe-GenerationEndpoints` (it spends image credit) bare.

### 35.4 The stage table is read by syntax tree

`Assert-GateFixtures` reads `$script:LedgerStages` from `Stage-Ledger.ps1` by walking the HashtableAst rows of the one literal assignment. It never dot-sources the file: a dot-sourced `param()` block clobbers the caller's variables, a half-written file yields a SHORT table that would be read as agreement, and executing a file to learn what it declares runs whatever else it declares. With no table on disk the run reports "stage table not found" as a NAMED PARTIAL and exits 3 - never a pass.

The three round-6 leak recipes (withhold, shape-mirror, figure-mirror) are written against a **SYNTHETIC fixture**, not the SITHCCC032 text: the exact prose the audit cites is not present in the evidence copies, so the recipes plant the equivalent defect - an assessed grid's answer column reproduced in a spine table - into a fixture the harness builds itself.

### 35.5 Gate hygiene has three statuses, not two

`Assert-GateHygiene` reports CONFIRMED, SUSPECTED and **REPORT**. A REPORT row is a CONFIRMED row that an independent audit re-read and refuted: the detector is wrong at that line, not the gate under it. Those rows are named, one per file and line with a written reason, in `assets\gate-hygiene.reclassified.json`, and the gate prints each of them with its reason.

**Every rule stays blocking.** Narrowing the blocking set to the rules that happened to be right would have switched off live checks. A row the list does not name still fails the gate, including another row of the same rule in the same file.

The list is meant to be **short-lived**. When P1-18 fixes the detectors each entry stops matching and is printed as STALE. A stale entry silences nothing, so it does not block; it is printed, counted in the report, and named in Stage 0's `partial[]`.

Three further rules, all blocking: a rule that **throws** on a file is CONFIRMED (that file was never inspected by it, and a rule that cannot run clears nothing); a file that cannot be read **leaves the denominator** and is named, so "scanned N scripts" means N scripts were read; and `-Only` naming a rule id the gate does not have **exits 2**, because a name that matches no rule used to filter every rule out and report a partial run with no findings, which reads exactly like a clean one.

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

- **`Assert-LongStageOutputContract`**: **Status: NOT YET IMPLEMENTED** - performed today by: nobody; the contract is a policy the orchestrating agent applies by hand - create the file first, check it is non-empty inside the deadline, keep the heartbeat, resume from disk. Nothing asserts any of it, so a judgement stage that writes at the end fails exactly as the third audit below did, and only its absence from the ledger says so afterwards.

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
