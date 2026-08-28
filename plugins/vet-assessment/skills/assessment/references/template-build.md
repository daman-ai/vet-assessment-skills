# Building the documents from the approved templates

Every document this skill produces is made by **editing an approved `.docx` template** — unpack the package, edit the XML, repack it. Nothing is generated from scratch.

That is what keeps the styles, the palette, the header logo, the footer fields and the cover-sheet wording identical to what the RTO signed off. A document built from scratch has to re-earn that agreement every time; a document built from the template inherits it.

---

## The scripts

| Script | Needs Word? | Does |
|---|---|---|
| `scripts/Build-FromTemplate.ps1` | No | Unpack, edit, validate, repack. All editing is raw-string. |
| `scripts/Docx-Blocks-House.ps1` | No | The house block builders — banners, tables, callouts, answer boxes, assessor panels, indicator tables. Measured, not invented. |
| `scripts/Build-Pack.ps1` | No | **The assembler.** Splices a generated body into a template, fills the cover sheet and the placeholders, writes document control, runs the gate, repacks. |
| `scripts/Test-HouseRules.ps1` | No | **The blocking gate.** Schema child order, colour band, day counts, line spacing, table width, font floor, model-answer form and colour, page-break targets. |
| `scripts/Verify-Document.ps1` | Yes | Open the finished file, update fields, export PDF, check page flow and run the rendered sweeps. |

Dot-source what you need. `Verify-Document.ps1` and `Test-HouseRules.ps1` both call helpers from `Build-FromTemplate.ps1`, so source that first.

**The house profile is the authority.** `Get-HouseProfile` loads `assets/house-profile.<brand>.json` — the measured record of the RTO's own artefacts. Every threshold in the gate reads from it. Change the profile and the scripts follow; that is what stops a figure drifting out of step with the check that reads it. See `house-standard.md`.

**A worked implementation is in `examples/Build-House-SITHPAT018.ps1`** - the real four-document build the assembler was extracted from. Read it when a new build needs a body shape this skill does not already describe; it shows the block builders driven from JSON content.

> **Copy its rendering, not its schema.** That file predates the current contract and still reads `modelAnswer` as a string, `responseType`/`table`, and `scenario`/`scenarioHeading`. All four were superseded — `section-contract.md`. Its block-builder calls and pagination call sites are still correct. Its field names are not.

```powershell
# from the skill folder; adjust the prefix for wherever it is installed
. ".\scripts\Build-FromTemplate.ps1"
. ".\scripts\Verify-Document.ps1"

$b    = Get-Branding -Brand MVC                       # MVC is the default
$work = Expand-Docx -Path (Get-TemplatePath -Branding $b -Kind uat)

# ... edits ...

Set-DocControl -WorkDir $work -Branding $b -DocNumber '4501' -DocName 'SITXFSA005_UAT' -Revision '1.0'
Assert-DocxPackage -WorkDir $work
Compress-Docx -WorkDir $work -Path 'C:\out\SITXFSA005_UAT.docx'

$v = Invoke-DocumentVerification -Path 'C:\out\SITXFSA005_UAT.docx' -Branding $b
if (-not $v.Ok) { <# remediate #> }
```

`Invoke-DocumentVerification` always closes Word, including on failure. Anywhere you drive Word yourself, wrap it so `Close-Word` runs in a `finally` — an orphaned `WINWORD.EXE` holds a lock on the output file and the next build fails confusingly.

---

## The rule that governs every edit

**Edit the XML as text. Never through a namespace-aware parser.** *(One exemption, documented: the `docx-images` sub-skill places pictures through an `XmlDocument`. It replaces whole paragraphs rather than splicing raw XML, and it preserves `mc:Ignorable` - verified. Re-run `Test-DocxPackage` after it, because nothing else does.)*

A namespace-aware parser silently drops the `xmlns` declarations for prefixes that appear only in `mc:Ignorable` — `w15`, `wp14`, `w16se` and others. The file still parses afterwards. Word still refuses to open it, and the error message says nothing about namespaces.

Editing as text cannot lose a declaration it never resolved. `Test-DocxPackage` checks for this specifically and names the missing prefix, because the failure is otherwise very hard to read.

The one place XML is parsed is `Test-DocxPackage`, on a copy it loads itself, purely to confirm every part is well formed. It never writes.

---

## OOXML traps — these corrupt the file, and only Word tells you

Package validation covers well-formedness, namespaces, content types, relationships, `numId` uniqueness and control characters — but **not schema child order**, which is the one thing that actually corrupts a document. A `pageBreakBefore`-before-`keepNext` package passes every structural gate and fails only when a human opens it. `Test-HouseRules.ps1` adds the ordering checks.

| Trap | Rule |
|---|---|
| **`pPr` child order** | `pStyle, keepNext, keepLines, pageBreakBefore, numPr, spacing, ind, jc`. Out of order, Word rejects the file. `pageBreakBefore` follows `keepNext`, **never** precedes it |
| **`tcPr` child order** | `tcW, gridSpan, vMerge, tcBorders, shd, tcMar, vAlign` |
| **`trPr` position** | First child of `<w:tr>`, before any `<w:tc>`. Emit it only when a height is actually needed, never empty |
| **Empty cells** | Every `<w:tc>` must contain at least one block-level element. Fall back to `<w:p/>`. **This includes `vMerge` continuation cells**, which are easy to emit empty |
| **Prefix collisions** | Searching for `<w:tr` also matches `<w:trPr` and `<w:trHeight`, and cuts a row open mid-way. Search `<w:tr>` **and** `<w:tr ` and take the later match. Same family: `<w:p ` with a trailing space (not `<w:pPr`), `<w:tc>`/`<w:tc ` (not `<w:tcPr`) |
| **Escaped labels** | When matching a label against raw XML, write it **pre-escaped** — `Unit Code &amp; Name:`, not `Unit Code & Name:` |
| **Accent rules** | A coloured left rule must be set in **both** `tblBorders/left` and the cell's `tcBorders/left`. One alone renders inconsistently |
| **Nested tables** | A details table and a photo box inside the cells of an outer table render correctly in some renderers and **overlap in Word**. Use a vertically merged cell instead. Where a nested table is unavoidable, it carries both its own `tblW` and `<w:tblLayout w:type="fixed"/>` |

**Column widths must sum to exactly the table width.** Compute all but the last by weight, then give the last column the remainder. Floor-rounding drift makes Word re-flow the table. `ColumnWidthSum` is a blocking check.

### Bullets — the exception that gets "fixed" by mistake

Body prose bullets are **real Word numbering** (`pStyle ListParagraph` + `numPr`), never a literal glyph and a tab. **But inside a table cell or an assessor panel, use a literal `•` + tab + hanging indent** — the house numbering style indents wrongly in a cell. `HBullet` builds the first form, `HPanelBullet` the second.

Written here as well as in `house-style.md` section D and `house-profile.mvc.json`, deliberately, because otherwise the next implementer reads the "never a literal glyph" rule and helpfully breaks every panel.

### Traps that cost a build, 27 August 2026

Every one of these produced a wrong document that passed its gates, or a failure whose message pointed somewhere else entirely.

| Trap | What it looks like | Rule |
|---|---|---|
| **Variable names are CASE-INSENSITIVE** | `foreach ($w in $W)` leaves `$W` holding the last element. `param([hashtable]$R)` with a `for ($r = 0; ...)` loop assigns `0` to a hashtable-typed variable | Never let a loop variable differ from another only by case. The type-constrained version surfaces as **"Argument types do not match" at the CALL SITE**, which sends you hunting the arguments instead of the loop |
| **`-eq` on an array filters, it does not compare** | `if ($pair -eq $rows[$r][0])` throws instead of returning a bool | Compare by index |
| **`$PSScriptRoot` is empty inside a `param()` default** | `[string]$OutDir = "$PSScriptRoot\out"` becomes `"\out"`, which is **drive-relative** — four documents were written to `C:\out` | Resolve it in the body, and throw rather than guess |
| **Read once, write once** | A part re-read from disk between two edits silently discards the first, because it was never saved | Read the part, make every edit to that string, write it back once |
| **A self-closing tag may carry a space** | An `XmlDocument` round-trip writes `<w:color w:val="E43C30" />`. A regex matching `"/>` misses it | Write `\s*/>` in every tag regex. This false-failed a correct assessor guide and, worse, made the leaked-model-answer check **false-PASS** |
| **`Get-DocxText` returns an array** | Passing it to a `[string]` parameter throws a transformation error | `-join "`n"` |
| **A single regex match collapses to a scalar** | `$img[0]` returns the first **character** | Wrap in `@()` |

**Word COM: do not kill `WINWORD` between documents in a loop.** It races the COM session and produces `0x800706BE` RPC failures that read like corruption. It also leaves the previous document locked, so the next write fails and the delivery folder ends up **half new and half old** — the worst possible state, and nothing flags it.

### PowerShell specifics

- PowerShell 5.1 decodes a BOM-less UTF-8 `.ps1` as ANSI — keep build scripts **ASCII only** and build non-ASCII characters from code points (`[char]0x2014`)
- Read JSON with `-Raw -Encoding UTF8`, or degree symbols and en dashes arrive mojibaked
- Under `Set-StrictMode`, guard every optional property read

### Word COM is fragile

Field update, repagination, page counting and PDF export must run in **one uninterrupted session**. Do not kill `WINWORD` while a job is in flight — that produces RPC failures that look like document corruption and are not.

---

## Editing text

`Invoke-DocxTextReplace` replaces inside `<w:t>` element bodies only. A bare replace across the whole part can corrupt an attribute value, an rsid or a style id that happens to contain the same characters.

**Always pass `-Expected`.** A patch that silently matched nothing is the failure this catches. Without it the build carries on and the defect surfaces at audit instead.

```powershell
$n = Test-DocxTextPresent -WorkDir $work -Part 'word/document.xml' -Text '[Unit code]'
Invoke-DocxTextReplace -WorkDir $work -Part 'word/document.xml' `
                       -Find '[Unit code]' -Replace 'SITXFSA005' -Expected $n
```

**Word may split a phrase across runs.** A phrase broken across two `<w:t>` elements is not present in either, so nothing matches. `Test-DocxTextPresent` first tells you whether the phrase is reachable. Where it is not, anchor on a shorter fragment that sits inside one run.

`Remove-DocxParagraph` deletes whole `<w:p>` elements, not just their runs. A paragraph stripped of its runs still prints as an empty line — and an empty spacer in front of a `keepNext`-bound block is exactly what strands a blank page.

### Non-ASCII characters in a build script

Windows PowerShell 5.1 decodes a BOM-less UTF-8 `.ps1` as ANSI. A literal `□`, `☐`, `»` or `·` written into a script arrives at the template as mojibake and matches nothing.

**Build the character from its code point:**

```powershell
$BOX = [char]0x25A1      # □ WHITE SQUARE
$BALLOT = [char]0x2610   # ☐ BALLOT BOX
```

This was a real failure on the recipe-template cover-sheet patch: the edit reported success on five of six changes and skipped the sixth silently.

The same applies to reading the branding profile. `Get-Branding` uses `[System.IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)` for this reason — `Get-Content` would mangle the tagline's middots.

---

## The placeholder map

Both templates are fill-in bases. Two marker conventions:

| Marker | Meaning | At delivery |
|---|---|---|
| `[Something in square brackets]` | A value to replace | Zero count |
| A line opening with `»` | Guidance for the builder | Deleted — zero count |

Both sweeps are delivery gates, run against the rendered output — the full sweep list is `house-style.md` section F, and the source-text early gate does not replace the rendered pass.

### Blocks already in the combined UAT template

Duplicate these rather than authoring new XML. They carry the styles, the borders and the shading already.

| Block | Anchor text |
|---|---|
| Question | `Maps to` → stem → `Student response — (a)` / `— (b)` |
| Task | `Task 1 — [Task title]` with its `Maps to` and `Task brief` |
| Task part | `Task 1 — Part (a) [part title]` |
| Observation checklist | `Observation checklist — [Task(s) observed]` |
| Observation record | `Observation record — [occasion and tasks covered]` |

Locate a block by its text, not by its position — the offsets move as soon as anything above it changes.

### Blocks already in the recipe workbook template

Recipe card banner, photo placeholder, header table with the vertically merged photo cell, competency focus box, ingredients table, method, storage and presentation, observation sheet, product evidence matrix, special-request scenario list.

---

## Document control

`Set-DocControl` writes the whole block from the branding profile. It sets each value in **two** places:

1. `docProps/custom.xml`
2. The cached result of every `DOCPROPERTY` field that displays it, in `document.xml` and in every header and footer part

Both are required. Word shows the **cached** result until the field is updated, so writing only the property produces a file whose footer disagrees with its own properties. That is a document-control finding, not a cosmetic one, and it is invisible until someone opens the file.

`Update-Fields` in `Verify-Document.ps1` is the second half of the same belt and braces — and it reaches header and footer story ranges, which `Document.Fields.Update()` alone does not.

**Never type a footer value.** The previous MVC template typed its footer and the typed values drifted out of step with the properties within one revision.

---

## Positions fixed by the template

**The positions themselves are `compliance-rules.md` section 10** — results and late submission days, oral questioning, the two title pages, the cover sheet, a table of contents in every document, no colour band. Verify each on the rendered output; none needs editing on a normal build. What follows is only what the *build* has to know about them.

| Position | What the build must know |
|---|---|
| Results — 14 days | Both templates shipped 45 and both are patched at source by `scripts/Patch-TemplateDayCounts.ps1`. `DayCounts` is a blocking check reading `resultsWithinDays` from the profile, so profile and template must agree or a correct document fails its own gate |
| Title-page colour band — removed | It DOES appear in the RTO artefact and is removed anyway. It is a **table**, not an image, which is why searching for pictures does not find it. `ColourBand` is a blocking check |
| `Qualification:` and `Unit Code & Name:` — pre-filled | Fill only an *empty* cell. The recipe template already fills the unit from its own placeholder, and writing again prints the unit name twice |
| Administration / receipting row — removed | `Remove-RowContaining` in `Docx-Blocks-House.ps1` drops it from the learner cover sheet |

### The cover sheet

**Holds exactly one page. Compress the layout, never the wording.** No clause is cut, summarised or abridged to make it fit. The template is already built to hold it: policy prose at 8.5 pt on `w:line="216"` with 40 after, headings at 9.5 pt bold navy, field and signature rows at 300 DXA `atLeast` with `cantSplit`, cell text at 9 pt, and `keepNext` across the block. If a longer unit title pushes it over, tighten the leading further.

**Verify by extraction, not by eye.** `Test-CoverSheet` pulls the rendered page-1 text and confirms each clause verbatim. A dropped clause looks like nothing at all — there is no gap on the page where it used to be. It also distinguishes a clause that **spilled** to page 2 from one that was **dropped**, because those are different failures.

The two templates originally disagreed on five cover-sheet points. The RTO standardised on the combined template, and `scripts/Patch-RecipeTemplateCoverSheet.ps1` has been applied to the recipe template. See `assets/templates/README.md` for the full record — it supersedes four positions the Recipe Workbook prompt v4.0 calls "MVC locks", and that correction is reported in every compliance report.

---

## Pagination

**The rule is `house-style.md` section D** — a section heading never occupies a page alone, the first child runs on under it, every sibling after the first starts a new page, and exactly three conditional sites in code. What follows is that rule instantiated on the combined UAT template, plus the mechanics.

**Put the page break on the heading, never on an empty spacer paragraph.** A spacer left in front of a bound block stays behind when the block is pushed, and prints as a blank page.

Each of these begins on a new page: the principles block; the assessment conditions; the assessment summary; the detailed scenario; each question after the first; each task after the first; each part of a task; each observation checklist; each observation record; the mapping matrix. **Not the foundation skills note** — the profile sets `pageBreakBefore.foundationSkills` to `false`, and it is a prose note rather than a mapping.

Two exceptions, both deliberate: the **Section A banner sits with Question 1** and the **Section B banner sits with Task 1**. A banner alone on a page with white space beneath it wastes a sheet and tells the learner nothing.

### Holding a table on one page

`cantSplit` on a row stops **that row** splitting. It does **not** stop the table breaking between two rows, and that is the break you actually see.

    **To hold a whole table on one page, set `keepNext` on every paragraph in every row except the final row, and SIZE THE TABLE WITH SLACK.** Do **not** reach for `cantSplit`: `NoCantSplit` is a blocking check because the RTO's own documents use none, so a table built with it fails the build. `readability.md` rule 5 is the canonical statement. A table that "just fits" is the one that gets pushed - leave real headroom rather than trusting a clean render.

**Size with slack, not to the limit.** A table that "just fits" is the one that gets pushed. Around 17 cm of table under a heading on A4 leaves roughly 5 cm spare: twenty data rows at ~460 DXA, or five rows at ~1400 DXA for a short template. Sizing to 20 cm because the render says it fits is how the push happens.

**Shrink the presentation, never the row count.** The row count is set by the task. Take the space out of the font (9 pt), the cell margins (zero vertical) and the explicit row height.

> A table that fits in one renderer can still break in Word, because Word measures rows slightly taller. A clean render is not proof.

---

## Delivery gate

Run in this order. Every step is a gate, not a report.

1. `Assert-DocxPackage` — parts parse, namespaces intact, content types declared, relationships resolve, `numId`s unique, no illegal control characters
2. **`Test-HouseRules`** — the blocking gate. Runs on the unpacked package, before repacking, so a defect is caught before a file exists to mislead anyone

   ```powershell
   $r = Test-HouseRules -WorkDir $work -Profile (Get-HouseProfile) -Learner
   if (-not (Write-HouseRuleReport -Result $r -Label 'UAT1')) { throw 'House gate failed' }
   ```

   `$r.Warnings` do **not** block. They carry defects present in the RTO's own source that the standing rule says to reproduce rather than silently correct — report them and let the RTO decide.
2b. **`Test-Readability`** — the readability gate, on the unpacked package, after the house gate and before repacking. Six checks: paragraph length, run-on lists, stacked short paragraphs, orphan lead-ins, bullet spacing, real lists. `readability.md`

> **`Assert-BrandLogo` runs before either gate, inside `Write-PackDocument`, and blocks.** Byte-level: every header and footer image must BE the resolved brand variant's mark, and no media part may match any other logo in `assets/logos` or the bytes the swap replaced. It exists because the crossover sweep reads text and a logo is an image - on 29 August 2026 a delivered pack's knowledge documents carried the MVC mark in their headers with every text gate green. `Set-BrandIdentity` also sweeps `.rels` hyperlink TARGETS for the same reason: a link's visible text lives in the part, its destination does not.

3. `Compress-Docx`
4. `Invoke-DocumentVerification` — updates fields, saves, then:
   - `Test-PageFlow` — no blank pages, no thin pages
   - `Test-CoverSheet` — one page, every clause present
   - `Invoke-RenderedSweeps` — placeholders, guidance markers, brand crossover, assessor-only leakage, oral questioning
   - `Get-LongSentence` — candidates over the profile's `writing.maxSentenceWords` (20), for a human to read
   - PDF export
5. Open the file in Word once, by hand, and confirm it does not prompt to repair

Step 5 is not redundant. A package that validates can still be one Word rejects; only Word settles that.

**Fix a thin page by deepening the writing rows above it, never by shrinking a response box.** The writing room is the learner's working surface. Spend the space there rather than pulling content up.

`Get-LongSentence` reports candidates, not failures. Legislation titles, verbatim unit text and assessed terminology are exempt from the reading-level judgement — a 30-word sentence that is the verbatim title of an Act is not a defect.

---

## Assembly and remediation

Parallel content agents return structured content and **one assembler renders it** — the fan-out contract, and why assembly is serial and deterministic, are in `section-contract.md`.

**To remediate:** regenerate the content for the affected section only — one agent, not all of them — then re-run the assembly from the pristine template. Section-addressability lives at the **content** level, not inside a live Word document.

Rebuilding one section in place by deleting its range does not work: deleting a section leaves the following section's marker adjacent to the insertion point, and Word absorbs the newly inserted content into it. This was tested — rebuilding Q2 corrupted Q3. It is also unnecessary. What costs time in a remediation round is regenerating content with an agent; re-running the template edit takes seconds.

Always assemble from a **fresh** `Expand-Docx` of the pristine template. Never re-edit a previous output — edits compound, and an `-Expected` count that was right on the template is wrong on a document already patched.
