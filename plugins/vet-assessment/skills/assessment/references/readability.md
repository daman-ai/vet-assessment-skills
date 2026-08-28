# Readability — the standard, and the pass that enforces it

**This runs after the documents are assembled, on top of everything else.** It is the last content gate before the personas and the clean-room audit.

It exists because a document can pass every compliance check and every house-style check and still arrive as a wall of text. Compliance protects the auditor. This file protects the reader.

RTO decision, 26 August 2026. Applies to every build, both branches, every document in the pack.

---

## The rules

### 1. No paragraph runs more than three lines

**A body paragraph must not exceed three rendered lines.**

The measurement is character count, because the builder cannot render. The house content column is 9638 dxa — about 17 cm — and body text is 11 pt. That is **roughly 100 characters per line**, so:

> **Every figure on this page is held in `assets/house-profile.<brand>.json` → `readability`, and `Test-Readability.ps1` reads them from there.** The numbers below are the measured MVC values, reproduced for the reader. Change the profile and the gate follows; change only this page and they drift.

| Limit | Value |
|---|---|
| Hard cap on a body paragraph, a bullet, or a task stem | **300 characters** |
| Target | 200 characters or fewer |

Over the cap, do **one** of these, in this order of preference:

1. **Convert it to a list.** Most over-long paragraphs are a list someone wrote as a sentence. This is almost always the right fix.
2. **Split it into two or three short paragraphs**, each carrying one idea.
3. **Cut words.** Never cut demands — `house-style.md` section A. If a stem asks for three things, the shortened stem still asks for three things.

**Never** solve it by shrinking the font or the leading.

A table cell is exempt from the character cap — a cell is already a bounded column, and the row height gives it room. The cap applies to body prose, bullets, task stems, part instructions and scenario boxes.

### 2. Every list is a real list

**If content enumerates two or more items, steps, conditions, documents or people, it renders as a real list.**

Real means:

- **In body prose** — real Word numbering: `pStyle ListParagraph` + `numPr`. `HBullet` builds it.
- **Inside a table cell or an assessor panel** — a literal `•` + tab + hanging indent. `HPanelBullet` builds it. The house numbering style indents wrongly in a cell, which is why this exception exists.

**These are all defects, and all of them shipped at least once:**

| Defect | Looks like |
|---|---|
| A hyphen run inside a paragraph | `Tools provided: - À la carte menu - Function running sheet - Standard recipe cards` |
| A semicolon or comma enumeration doing a list's job | `Record the covers, the service times, the menu items, the dietary requirements and the storage.` |
| A numbered sequence written as a sentence | `First calculate the yield, then apply the wastage, then round up.` |
| A list whose items are separated only by line breaks | items that render as one paragraph because nothing marks them |

**The highest-risk sites are the instructions and the task stems.** A Task stem carrying the tools, the documents, the steps and the deliverable in one paragraph is the single most common readability failure in this pack, and it is the one learners complain about.

**Order matters, or it does not.** Numbered where the learner must do things in sequence; bulleted where they need not.

### 2b. Never stack short paragraphs where a list belongs

**Three or more consecutive short paragraphs, none of them bulleted, read as a list that has lost its dots.** This is the defect a reader notices first, and it is the one that survives every other check.

It happens when prose is split one sentence per line and each line is rendered as its own paragraph. The learner sees a stack of one-line statements with no markers, and cannot tell whether it is prose or a list someone forgot to format.

There are exactly two correct outcomes, and the writer must pick one:

- **They are a list** — give them real bullets. Parallel rule statements, sets of conditions, sequences of steps.
- **They are prose** — join them back into a paragraph, up to the three-line cap.

The assembler does the second automatically. **`HRenderProse`** in `scripts/Docx-Blocks-House.ps1` takes an agent's multi-line string and **joins consecutive unmarked lines into paragraphs**, greedily, up to 300 characters, breaking after any line that ends in a colon. Only a line marked `- ` becomes a bullet.

**So the `- ` marker is the only thing that decides list or prose.** An agent writing one sentence per line gets flowing paragraphs. An agent writing `- ` gets dots. Nothing lands in between.

**Front matter is caught by the same rule.** Blocks of parallel statements — how you are assessed, quality expected of your responses — are lists and take bullets, not paragraphs. Check every `paragraphs` array in the front matter for this.

`StackedShortParagraphs` fails a run of **four or more** consecutive non-bulleted prose paragraphs of 110 characters or fewer. Headings are excluded.

**What "front matter" means here, because the two senses pull opposite ways.** The **approved cover sheet and title page** are the RTO's own wording, laid out by the template, and are out of scope for every check. **Authored front matter — the overview, how you are assessed, quality expected, the conditions block, the detailed scenario — is fully in scope**, and it is where stacked one-liners are most likely to be hiding. Rewrite those; never touch the cover sheet.
### 3. Spacing lets the page breathe

Measured house values. `LineSpacing` is a blocking check and admits **240 or 360 only**, so readability is bought with space *before* and *after*, never with leading.

| Element | Before | After | Line |
|---|---|---|---|
| Body paragraph | 0 | **160** | 360 |
| Bullet in body prose | 0 | **80** | 360 |
| Panel or cell bullet | 0 | 40 | 240 |
| Table cell paragraph | 0 | **60** | 240 |
| Heading | 200 | 60 | — |
| Sub-heading | 160 | 40 | — |

**A list whose items sit flush against each other is unreadable.** Bullets shipped at `after=0` and it was the single worst spacing defect in the pack.

### 4. One idea per paragraph

Where a paragraph carries a second idea, it becomes a second paragraph. This falls out of rule 1 most of the time, but state it, because a 290-character paragraph carrying three ideas passes the cap and still fails the reader.

---

### 5. A heading never separates from its content

**Any line that introduces what follows must be bound to it.** Otherwise it strands at the foot of a page while its content opens the next one, and someone has to fix it by hand every time the pagination shifts.

Observed in the wild: *"Wastage allowance to apply:"* closed page 41 and its three bullets opened page 42.

The binding is `keepNext`. It is already carried by:

- **Section banners** — `HBanner`
- **Headings and sub-headings** — `HHead`, `HSubHead`
- **A task stem, a part label, a Scope line** — set at the call site

And, since 26 August 2026, by:

- **Any paragraph ending in a colon.** `HBody` takes `-KeepNext`, and **`HRenderProse`** sets it automatically whenever a paragraph ends in `:`. A colon lead-in introduces a list, so it binds to the first item beneath it.

`OrphanLeadIn` fails any body paragraph that ends in a colon without `keepNext`. Table cells are excluded — the cover sheet's `Student Name:` fields are approved front matter laid out by the template.

> **Do not reach for `cantSplit`.** It looks like the obvious belt-and-braces fix for a box that breaks across a page, and the house gate will reject it: `NoCantSplit` is a blocking check, because **the RTO's own documents use none**. The template cover sheet is the only exempt place. Bind with `keepNext` instead. This was tried on 26 August 2026 and reverted.
## What is exempt, and why

- **The approved cover sheet.** It is the RTO's own wording at 8.5 pt on compressed leading to hold one page. It is not authored by this skill and must not be reflowed. `house-style.md` section D.
- **Table cells**, from the character cap only. Rules 2, 2b and 4 still apply inside them.
- **Verbatim unit text** — a Knowledge Evidence point or an Assessment Condition quoted in a mapping matrix is quoted, not authored.
- **Legislative citations** carrying a full instrument title.
- **The table of contents.** A populated contents list is two dozen short entries with no bullets and would trip `StackedShortParagraphs` on every delivered document. It only appears *after* Word updates the field, so a gate run inside the build never sees it and a gate run after delivery always does. TOC paragraphs are detected by their `TOCn` style or their `PAGEREF` field and excluded from every check.

Everything else is in scope.

**The anchor that marks the end of the front matter is brand-specific.** It is the RTO's own email address on the title page, so any brand whose identity is swapped at build time must name its *post-swap* address in `formatting.bodyStartsAfter`. Miss this and the gate loses the seam, treats the approved title page as authored body, and fails a correct document on the RTO's own six-line address block. Generic fallbacks such as `ASSESSMENT` are admitted only near the front of the document, because those words recur in the body and a late match would silently scope the gate to a fragment.

---

## The mechanical gate

`scripts/Test-Readability.ps1` measures what can be measured. Run it on the unpacked package, after `Test-HouseRules` and before repacking.

```powershell
. .\scripts\Build-FromTemplate.ps1    # Get-DocxPart
. .\scripts\Test-HouseRules.ps1       # Get-HouseProfile - without it the thresholds fall back
. .\scripts\Test-Readability.ps1
$r = Test-Readability -WorkDir $work -Brand $Brand
if (-not (Write-ReadabilityReport -Result $r -Label 'UAT')) { throw 'Readability gate failed' }
```

**Pass `-Brand`.** Without it the gate reads MVC's thresholds and MVC's body anchor, so an ACI build is measured against the wrong profile and, because the identity swap rewrites the MVC email that anchor names, throws outright. The anchors come from `formatting.bodyStartsAfter` in the brand's house profile - the same place `Test-HouseRules` takes them from.

It reports:

| Check | Fails when |
|---|---|
| `ParagraphLength` | a body paragraph, bullet or stem exceeds 300 characters |
| `RunOnList` | a paragraph carries a hyphen run. A single sentence over 150 characters with five or more clauses warns rather than fails - the comma heuristic is noisy, and a gate that fails correct prose teaches people to ignore it |
| `StackedShortParagraphs` | four or more consecutive non-bulleted prose paragraphs of 110 characters or fewer |
| `OrphanLeadIn` | a body paragraph ends in a colon without `keepNext`, so it can strand at a page foot away from the list it introduces |
| `BulletSpacing` | a body bullet carries `after` below the profile value |
| `ListParagraphIsList` | a paragraph styled `ListParagraph` carries no `numPr` |

Two further names **warn and never block**: `LongSentenceClauses`, and `LiteralBulletInBody` where a literal `•` opens a body paragraph outside a cell or panel.

**The gate finds them. It does not fix them** — an automatic split would cut a sentence in the wrong place. The readability agent below does the rewriting.

---

## The readability agent

Spawn it **after assembly, before the personas**. It rewrites content; it does not touch the document.

Give it the built document paths, the content directory, and this brief.

```
You are a readability editor for a VET assessment tool. The documents are already
compliant and already built. Your job is the reader, not the auditor.

DOCUMENTS: {PATHS}
CONTENT: {CONTENT_DIR} - the JSON the assembler renders. You edit THIS, never the .docx.

Read the built documents to see how the content lands on the page. Use:
  . "{SKILL_DIR}\scripts\Build-FromTemplate.ps1"
  $w = Expand-Docx -Path "<path>"; Get-DocxText -WorkDir $w -Part 'word/document.xml'

THE RULES

1. NO PARAGRAPH OVER THREE LINES. The cap is 300 characters; target 200. Over the
   cap, convert to a list first, split into short paragraphs second, cut words third.
   NEVER cut a demand. If a stem asks for three things, your version asks for three.

2. EVERY LIST IS A REAL LIST. Any enumeration of two or more items, steps,
   conditions, documents or people becomes a list. In the content JSON, a list is
   expressed as separate lines: put each item on its own line, prefixed with "- ".
   The assembler turns those into real Word bullets. Never leave a hyphen run or a
   comma enumeration inside a paragraph.

3. ONE IDEA PER PARAGRAPH.

4. Leave table cells alone for length. Rules 2 and 3 still apply inside them.

WHAT YOU MUST NOT CHANGE
- Any figure, temperature, quantity, date, time, code, price or standard number.
- Any assessed term: mise en place, a la carte, table d'hote, buffet, bulk cooking
  operations, reconstitution, re-thermalisation, critical control point, portion
  control, standard recipe, food production system, purchase order, staff allocation,
  central stock ordering system. Never simplify these.
- Any word guide, scope, count or threshold.
- Any model answer, benchmark, or `modelRows` content. Those are assessor-facing and
  already capped at 18 words a line.
- The number of parts, the number of table rows, or any `covers` mapping.
- The cover sheet. It is approved wording and is out of scope.

HOW TO EDIT
Edit the JSON files in place. For each item you change, keep the same `id`, the same
`parts` array length, and the same field names. Only the prose inside `stem`,
`text`, `scenarioBox`, `paragraphs`, `bullets` and `intro` may change.

RETURN
A table of every block you changed: file, item id, field, characters before, characters
after, and what you did (listified / split / trimmed). Then confirm in one line that no
figure, term, count or threshold was altered.
```

**Then re-assemble from a fresh template and re-run both gates.** The readability agent changes content, so the build must be re-run, not patched.

---

## Reporting

Every build reports, alongside the counts in `compliance-rules.md` section 11:

- **The longest body paragraph in each document**, in characters and rendered lines
- **The count of paragraphs over 300 characters** — expect zero
- **The count of real list items** versus **run-on lists found** — expect the second to be zero
- What the readability agent changed, as a table
