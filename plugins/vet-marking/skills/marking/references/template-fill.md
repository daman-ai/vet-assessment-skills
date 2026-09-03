# Filling a supplied template

The three templates are the RTO's approved, controlled documents. We **edit**
them — fill fields, tick boxes, clone and delete rows, insert a column. We never
rebuild them.

**Headers, footers, styles, numbering, relationships and document numbering are
never touched.** The gate check `TemplateUntouched` hashes every part except
`word/document.xml` and `docProps/` against the template and fails on any
difference, so this is enforced rather than merely intended.

## Everything works on the XML DOM

Not regex over `document.xml`. Row cloning and column insertion cannot be done
safely with string surgery, and the failures are silent — a mismatched tag count
produces a file that looks fine until someone opens it.

## Placeholders

A field is a single run, italic, in the placeholder grey (`8E96A3` for MVC).
`Set-Placeholder` matches both `[ Name ]` and `[Name]`, because a template
author's spacing is not something a build should depend on.

**Filling a field drops the placeholder styling.** `Set-RunAnswerStyle` removes
`w:i`/`w:iCs` and sets the answer colour, leaving bold, size and font alone so
the field keeps whatever weight the template gave it. A finished record that
still prints grey italic reads as an unfilled one; the gate check
`NoPlaceholderStyling` blocks on any surviving placeholder-coloured run.

### Scope every fill to its table

`dd / mm / yyyy` occurs three times in the SAR — date of assessment,
certification date, results entered — and `Insert trainer / assessor name`
twice. A document-wide replace puts the results-entered date in the
date-of-assessment cell, and every gate above the cross-document check would
still pass.

Fill table by table. Where two occurrences live in one table (the marking
record's sign-off block), use `-Limit 1` twice in order.

### Runs split across boundaries

Word splits runs on spell-check and revision boundaries, so a field can span
several `w:r`. `Set-TextInNode` handles both cases: it looks for a single run
holding the whole field first, and falls back to merging the paragraph's runs
into the first before replacing.

## Checkboxes

Two kinds, and they are not interchangeable.

**Bracketed decision boxes** — `[ ☐ ]`. These are decisions the assessor must
make. Replace with ☒ or ☐ and **remove the brackets either way**. There are six
in the SAR and fifteen in the marking record; scope each to a single cell.

**Standing option labels** — `☐ Assessment completed`. Flip the glyph in front
of an exact label. The label is matched with its box glyph as a prefix, so
`☐ is Competent` cannot match inside `☐ is Not Yet Competent` — the two share a
line in the SAR's certification block.

### Scope: a cell, a row, or ONE paragraph

An observation sheet puts a whole column of `☐ Yes` / `☐ No` pairs in a single
cell, one per observable task. Scoping a tick to that cell would flip every box
in it, so the tick is scoped to the individual **paragraph**.

`Set-TextInNode` accepts a `w:p` for exactly this reason — and did not, for as
long as it existed. It enumerated `.//w:p`, which selects *descendant*
paragraphs, and a paragraph has none. Handed one it matched nothing, replaced
nothing, and **returned zero without error**. A full build shipped an
observation sheet whose every box was still empty beneath a signed record and a
completion date, and the gate passed it.

The fix is one line. The lesson is two:

- **A no-op is not an error, and nothing downstream will say so.** Where a
  helper reports how many replacements it made, a caller that ignores the count
  has thrown away its only evidence that anything happened.
- **The gate must read the thing itself, not the record of it.**
  `MarkedCopyObservationSheet` now re-pairs the boxes off the delivered file and
  compares each with the ledger. That check, and not the fix, is what makes the
  failure impossible to ship twice.

## Rows

`Set-RowCount` grows or shrinks a repeating block to its real length by cloning
or deleting from the end. The marking record ships fifteen student rows and the
feedback sheet ten item rows; both are trimmed to the real count. The gate check
`NoUnusedRows` blocks on any surviving placeholder row.

### The SAR's vMerge trap

The SAR's outcome table has a `vMerge` **master** cell — "Evidence to be
attached" — spanning the tool rows. Row 3 is the master; row 4 is the
continuation.

**Clone row 4, never row 3.** Cloning the master duplicates the merge and splits
the panel. The RTO profile records this as `cloneFromRowText`.

## Inserting a tool column

A unit with three or more tools needs a column in the marking record.
`Add-TableColumn` inserts it into every row and **rebalances the grid so the
widths still sum to the table's declared `w:tblW`**. Word re-flows a table whose
column widths do not sum to its declared width, so the new column is paid for
out of the columns it sits among and the last column takes the rounding
remainder.

### Grouped header rows take a wider span, not a new cell

Row 1 of the marking record's student table is a grouped header — `Assessment
Tools` already spans the tool block. Give it a cell of its own and the row ends
up one cell wider than the grid, which prints as a stray empty box in the
header. Pass those rows to `-WidenSpanRows` and their covering cell's
`gridSpan` widens instead.

Verify after inserting: the grid must still sum to the table width. Three tools
in the MVC record gives twelve columns summing to 14822; four gives thirteen,
also summing to 14822. Both are verified against all three RTOs' templates.

#### The insert index must land *inside* the tool block

`-WidenSpanRows` widens whichever cell already covers the index you insert at.
The tool columns occupy 0-based `firstToolColumn - 1` to
`firstToolColumn + toolColumns - 2`, so the index must be **the last of those**,
not one past them:

```powershell
# WRONG — one past the block. That index is the first column of 'Results',
# so 'Results' widens to 4 and 'Assessment Tools' stays at 2.
$insertAt = $cols.firstToolColumn + $cols.toolColumns - 1

# RIGHT — the last existing tool column
$insertAt = $cols.firstToolColumn + $cols.toolColumns - 2
```

This is a trap worth naming because **the damage is invisible to the gate**. The
tool names, the results and every date still land in the right cells, the grid
still sums to the table width, and all twenty-two checks pass. The only symptom
is a printed record whose third tool sits under the heading *Results* instead of
*Assessment Tools* — visible to a reader and to an auditor, and to nothing else.
It cost a build to find, which is why the fix is written down here rather than
just corrected.

## Two traps that pass every structural check

Both of these produce well-formed XML that satisfies every check short of
opening the file, so both cost a full build before they were found.

### 1. `xml:space` must use an explicit prefix

```powershell
# WRONG — emits <w:t d8p1:space="preserve" xmlns:d8p1="…/XML/1998/namespace">
$t.SetAttribute('space', 'http://www.w3.org/XML/1998/namespace', 'preserve')

# RIGHT
Set-XmlSpacePreserve $t
```

`XmlDocument` invents a prefix for the reserved `xml` namespace. The result is
well-formed XML, passes every structural check, and makes **Word refuse to open
the document**. Use `Set-XmlSpacePreserve`, which calls `CreateAttribute` with
an explicit `xml` prefix.

Two gate checks now cover it: `NoInventedNamespacePrefix` (cheap, needs no Word)
and `OpensInWord` (definitive).

### 2. `.ps1` files need a UTF-8 BOM

PowerShell 5.1 loads a BOM-less file as ANSI. Every em dash, `°`, `·`, `☐` and
`☒` in these scripts then decodes as mojibake, and the file fails to **parse** —
with errors pointing at lines nowhere near the real problem.

Every script in `scripts/` is UTF-8 **with BOM**. After any edit, check:

```powershell
Get-ChildItem scripts\*.ps1 | ForEach-Object { $e=$null;$t=$null; [System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$t,[ref]$e); "{0}: {1}" -f $_.Name, @($e).Count }
```

Some editors and tools strip the BOM on save. If a script suddenly fails to
parse after an edit that looks harmless, this is why.

### And one PowerShell trap of the same family

`"$who: something"` is parsed as a drive-qualified variable and is a **parse
error**, not a runtime one. Write `"${who}: something"`.

## Measuring a template

`Measure-Template.ps1` reports what the builder needs and cannot assume: table
count and headings, every bracketed field with its occurrence count, every
standing checkbox label, the repeating rows and their length, table widths and
grids, and page orientation.

Run it on every template an RTO supplies, before marking anything with it, and
paste the result into `assets/rto.<key>.json`. **A template that disagrees with
its registered map is a template that has been revised** — the builder throws
and names the table rather than filling the wrong cell.

## Related

- [onboarding-rto.md](onboarding-rto.md) — registering a new RTO's templates
- [audit-checklist.md](audit-checklist.md) — what the gate proves
