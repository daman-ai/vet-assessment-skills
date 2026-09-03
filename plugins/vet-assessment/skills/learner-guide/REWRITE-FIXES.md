# Change record - defects closed after the rewrite verification

Working note, kept as the fixes land. Every behavioural change to a script was
proved by constructing the failing case and running it.

Two findings were closed by someone else before this pass and were NOT redone:
Get-BrandPalettePairs now throws on an unresolvable role, and the crossover
sweep prints the roles it excludes as shared.

**Reconciled 3 September 2026 against the tree as it stands.** `scripts\` holds
the 20 files listed at the foot of this note; `Test-Pipeline.ps1 -SkipOffice`
passes 47/47 on this machine today; gates.md was rewritten on 2 September and
then brought to an honest state on 3 September (item 7). Every status below says
what the tree contains, not what was intended. The previous version of this note
carried "gates.md pending" on five items that gates.md had already closed three
minutes after the note was saved; those are now DONE and say where.

## 1. HIGH - the silently-degrading-parameter class - DONE (scripts, SKILL.md, gates.md)

A blocking rule sitting behind an optional parameter printed a clean pass having
checked nothing.

- `scripts\Test-GuideRules.ps1` - `-QuestionsInPack` absent now FAILS. Also
  covered: page geometry absent (content-width rule), no `Topic N` heading
  (word floor). New `-AllowPartial` switch turns each into a loud PARTIAL RUN
  warning, returns them on `.Partial`, and the report prints them in magenta.
- `scripts\Test-DeckRules.ps1` - same for `-TemplatePath` (placeholder sweep),
  `-Plan` (notes, chips, slides-per-Topic), `-NumberSlotByLayout` with `-Plan`
  (printed slide number), `-Rto` and `-Cricos` (document-property identity,
  which used to print "pass -Rto to make this blocking").
- `Stage-Ledger.ps1` - `Add-StageRecord -Partial`, and a partial record with no
  `-Note` blocks delivery. An omission is a decision somebody signed.
- `SKILL.md` Stage 4 and 7c now thread every parameter, from the RTO profile.
- `gates.md` section 7 carries the -AllowPartial table and the general rule ("a
  blocking rule whose input is absent FAILS, and names the input"); section 8
  carries the four-parameter deck table.

PROOF: `Test-Pipeline.ps1 -SkipOffice`
  PASS  the guide gate FAILS when -QuestionsInPack is omitted
  PASS  -AllowPartial records the omission instead of hiding it
  PASS  the deck gate FAILS on every unsupplied input (5 of them)
  PASS  -AllowPartial records all 5 of them instead of hiding them

## 2. HIGH - six new blocking stages had no ledger enforcement - DONE (script, SKILL.md, gates.md)

`$script:LedgerRequired` gained `3c 3d 4c 6b 7b-i 7b 7c 7d`; `LedgerOrder`,
`LedgerBlocking` and a new `LedgerVerdict` set updated with it. `n-a` now costs a
written note. SKILL.md Stage 8 rewritten to match what the script enforces, and
tells the reader to take the list from the script rather than a copy.
gates.md section 10 lists the required set, says the script is the only copy,
and records why a transcribed list is how six stages came to be enforced by
nothing.

PROOF: recording exactly the old list leaves 7 stages unrecorded and the ledger
names every one. Test-Pipeline derives the list from the script:
  PASS  every blocking stage added since is enforced (3c, 3d, 4c, 6b, 7b-i, 7c, 7d)

## 3. HIGH - Get-RtoProfile did not exist - DONE (script, assets, SKILL.md, gates.md)

Implemented rather than removed, because Stage S0-RTO is what stops a build
hard-coding a template path, a hex or a provider code.

- `scripts\Get-RtoProfile.ps1` - `Get-RtoProfile` (loads, resolves, validates,
  throws) and `Assert-RtoProfile` (the S0-RTO gate, `-Rto MVC -Check`).
- `assets\rto-profile.schema.json` - machine-read: the validator derives its
  required keys, its closed palette role enum and its identity fields from it.
- `assets\rto-profile.mvc.json` - the worked example, for the one brand whose
  guide AND deck templates the assets folder actually ships.
- Trap found and fixed while proving it: a dot-sourced script's param block runs
  in the caller's scope, so `[string] $Rto` made `$rto = Get-RtoProfile ...`
  silently stringify the profile. Params are now untyped and renamed
  `-SkillPath` / `-BrandingPath` so they cannot clobber a build's `$SkillDir`.
- gates.md 29.1 documents the pack, the schema-derived check-sets, the no-notes
  allow-list rule and the dot-source trap.

PROOF: pack validates and returns real values; fails with the plant verified to
have landed on (a) a no-notes exemption with no written reason, (b) an
unapproved deck template; throws on an RTO with no pack.

## 4. HIGH - the unsatisfiable placement-staleness rule - DONE (script, SKILL.md, gates.md)

Split into two classes with the reason written down. Renders (`4`, `7`) hold
`4b`, `5`, `6` - and Stage 7's round now explicitly re-runs all three, which is
what makes it satisfiable. Placements (`7b`, `7c`) hold `7c` and `7d`, plus at
least one Stage 6-class verdict, which `7d` is. Stage 5 is deliberately NOT held
to placement, because nothing re-runs the personas after it and an unsatisfiable
blocking rule is how a check gets waived.

gates.md section 10's table already carried the split. Section 34 item 2 did
not - it still said "7b and 7c join $script:LedgerRenders" and "any 4b, 5 or 6
record older than the newest placement is stale", which is the rule the script
no longer enforces. Rewritten on 3 September to name both classes exactly as
`Stage-Ledger.ps1` declares them.

PROOF:
  PASS  placement makes the post-placement re-gate stale
  PASS  and re-running exactly those two clears it - the rule is satisfiable

## 5. HIGH - the image review lost its owner - DONE (SKILL.md, ledger, gates.md, visuals.md)

Ledger stage `7b-i`, blocking, long-stage output contract, `n-a` with a note
where nothing was generated. Placement may only use a slot with a passing review
record. Re-checked twice against final content: Stage 7 step 7 for any slot whose
content or prompt changed, and Stage 7d against the placed page.

gates.md 30.3 was referenced three times and never written; written on
3 September - owner, scope, ledger record, heartbeat, and the rule that an image
reviewed against superseded content is re-checked against the final content
before placement. visuals.md section 9 gained a matching ownership block.

## 6. HIGH - the figure sheet was never kept current - DONE (scripts, SKILL.md, gates.md)

- `scripts\New-FigureSheet.ps1` - generates the sheet from the spine, dumping
  every field of every visual node rather than a maintained list of field names,
  and stamps `SPINE-FINGERPRINT`.
- `Lib-GateCommon.ps1` - `Get-SpineFingerprint`, one implementation.
- `Stage-Ledger.ps1` - `Test-FigureSheetCurrent`, called by `Test-StageLedger`:
  missing sheet, missing stamp or a moved spine BLOCKS delivery.
- gates.md: section 10 carries the fingerprint row, section 31 the rule that the
  sheet travels with every review pack, and the 3d and 7 gate-table rows name
  `New-FigureSheet.ps1`.

PROOF:
  PASS  a spine edit makes the figure sheet stale
  PASS  regenerating it clears the block

## 7. HIGH - gates.md told builders to call scripts that do not exist - DONE (gates.md)

Found on 3 September: twenty-six script names carrying invocation lines and a
blocking status with no file and no function behind them; five functions
(`New-SpineWriter`, `Resolve-Palette`, `Get-RendererContract`, `Run-Gates`,
`Assert-LongStageOutputContract`) defined nowhere; and section 30.3 referenced
three times and never written. Each name was checked against `Get-ChildItem
scripts\` and a grep for `function <name>` across every script before it was
marked. Nothing was deleted - the plan is to build them - but a rule nobody can
execute now says so in place.

- 30.3 written (item 5).
- Every absent name marked where it is invoked: "Specified, not yet
  implemented. Until it exists, this check is performed by ..." naming the
  actual performer today, or "nobody". Four names a sibling build is writing at
  the time of the pass are marked "being implemented" instead:
  `Assert-PromptLint.ps1`, `Probe-GenerationEndpoints.ps1`,
  `New-WithholdRegister.ps1` (added to section 16 and the Stage 2 table row as
  the derivation step for the withhold register, `grids.json` and the agent
  packs), and `Test-Finding.ps1` (the 6b arbiter; design name
  `Assert-FindingProvenance`). None of the four was on disk at reconciliation.
- The gate table carries a legend and a status on every affected row.
- Five statements corrected to match the scripts: section 14 and the Stage 1
  row no longer describe a `-Derive` switch `Check-FigureLeakage.ps1` does not
  have (it derives on every run; `-ReportPath` writes the hit list); 29.4 names
  `Check-Identity.ps1` rather than a non-existent `Assert-BrandCrossover.ps1`;
  11b says the 3c readability arm has no wrapper (`Test-Readability` reads an
  unpacked .docx); 31 says `Get-DocText.ps1` does not yet write the
  `FIGURES:` / `CHANNELS:` stamp; 35 says `Test-FigureConsistency.ps1` still
  scans every `.ps1` behind a filename regex.
- New section 15b: the three defect classes the last build's audits found that
  no current gate can see - numbered-row grids (Workbook 2(b), 2(c), 3(a),
  3(b)), prose written to the shape of the model answer (Knowledge Task 4), and
  a figure row keyed by run rather than row label (Figure 7.1.4) - with the
  planned gate for each named: `Check-ShapeMirror`, `Check-RowCoverage`, and
  the heading test in `Check-FigureMirror`.

PROOF: none possible for prose. The check is `Get-ChildItem scripts\` against
the gate table's Script column, and it should be re-run whenever a sibling
script lands so the "being implemented" markings can be removed.

## Mediums

- Promoted scripts named by their callers in SKILL.md: `Check-Figures.ps1` (7c,
  and the only check on alt text in placed drawings), `Check-Identity.ps1` (4c,
  7c, 8), `Test-SpineRead.ps1` (Stage 3 and 3c), `Lib-GateCommon.ps1` (Stage 0
  dot-source). DONE in SKILL.md and in gates.md (gate table, 21, 29.4, 33).
- Readability: SKILL.md 4b says it GAINS a spine-side run and keeps the rendered
  run unchanged; gates.md 11b matches, and now also says the spine-side run has
  no wrapper yet. DONE, with the gap named.
- Stage 3d allow-list surfaced to the reviewer: audit-checklist.md STILL
  PENDING. The file (last written 2 September 16:18) carries no Stage 3d or
  allow-list section. Not touched in this pass; owned elsewhere.
- No-notes layout list: now an audited allow-list - the list stays in the deck
  profile, the written reasons live in the RTO profile pack, and
  `Assert-RtoProfile` fails on divergence either way or on an entry that is also
  notes-required. DONE.

## Status table, 3 September 2026

| Item | scripts | SKILL.md | gates.md | visuals.md | audit-checklist.md |
|---|---|---|---|---|---|
| 1 Degrading parameters | DONE | DONE | DONE (7, 8) | - | - |
| 2 Ledger required set | DONE | DONE | DONE (10) | - | - |
| 3 Get-RtoProfile | DONE | DONE | DONE (29.1) | - | - |
| 4 Placement staleness | DONE | DONE | DONE (10, 34.2) | - | - |
| 5 Image review owner | DONE (ledger) | DONE | DONE (30.3) | DONE (sec 9) | - |
| 6 Figure sheet currency | DONE | DONE | DONE (10, 31) | - | - |
| 7 Absent scripts marked | n/a | n/a | DONE (table, 11b-36, 15b) | DONE (4 names) | - |
| M Promoted script names | DONE | DONE | DONE | - | - |
| M Readability spine run | NOT BUILT (no wrapper) | DONE | DONE, gap named | - | - |
| M 3d allow-list to reviewer | - | - | - | - | PENDING |
| M No-notes allow-list | DONE | DONE | DONE (29.1) | - | - |

## What the tree does NOT contain, so nobody reads a DONE above as "the gate exists"

Not yet implemented (specified in gates.md, no file, no function):
Assert-RendererContract, Get-RendererContract, New-SpineWriter,
Resolve-Palette, Assert-DownstreamPalette, Assert-GateFixtures,
Assert-GateHygiene, Assert-LongStageOutputContract, Assert-CorpusComplete,
Assert-PackSelfConsistency, Assert-Provenance, Assert-WithholdRegister
(enforcement arm), Assert-IdentifierNamespace, Assert-SpecRenderable,
Run-SpineGates, Run-Gates, Assert-ChannelDisposition (and the Get-DocText
stamp), Assert-EnumerateBeforeFix, Assert-FullRegateAfterMutation (whole-set
assertion), Assert-Staleness, Assert-GridDisposition, Assert-FigureCoverage,
Assert-SpineCounts, Assert-Terminology, Assert-DeckParity,
Assert-CitationConsistency, Assert-ScenarioClock, the Test-Readability spine
wrapper, Check-ShapeMirror, Check-RowCoverage.

Being implemented by sibling builds (not on disk at reconciliation):
Assert-PromptLint.ps1, Probe-GenerationEndpoints.ps1, New-WithholdRegister.ps1,
Test-Finding.ps1.

Design names that resolve to an existing script (no file of the design name):
Assert-BrandCrossover -> Check-Identity.ps1; Assert-AssessorLeakage ->
Check-FigureLeakage.ps1; Assert-RtoProfile -> function in Get-RtoProfile.ps1;
the write-time arm of Assert-RendererContract -> Test-SpineRead.ps1; the
placement arm of Assert-FullRegateAfterMutation -> Check-Figures.ps1.

## scripts\ as of 3 September 2026

Build-Guide.ps1, Check-FigureLeakage.ps1, Check-FigureMirror.ps1,
Check-Figures.ps1, Check-Identity.ps1, Get-DocText.ps1, Get-RtoProfile.ps1,
Lib-GateCommon.ps1, Lib-Resolve.ps1, New-FigureSheet.ps1,
Patch-GuideTemplateGeometry.ps1, Pptx-Blocks.ps1, Set-ResourceBrand.ps1,
Stage-Ledger.ps1, Test-DeckRules.ps1, Test-FigureConsistency.ps1,
Test-GuideRules.ps1, Test-Pipeline.ps1, Test-SpineRead.ps1, Xml-Scan.ps1.

Status at the last save: scripts complete and proven (47/47 in
`Test-Pipeline.ps1 -SkipOffice`, re-run 3 September); SKILL.md complete;
gates.md and visuals.md honest; audit-checklist.md pending on one medium.
