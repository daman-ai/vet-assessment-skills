# Registering an RTO's templates

Every RTO supplies its own three marking documents. The skill fills whatever it
is given; it does not carry one RTO's forms to another.

## The rule that makes this necessary

**The builder refuses to run for an RTO whose templates have not been supplied,
and it does not fall back to another RTO's.**

A Meridian-headed Student Assessment Record carrying an ACI student's result is
not a near-miss. It is a wrong record — wrong RTO code, wrong CRICOS code, wrong
legal entity — signed by an assessor and filed as evidence. Refusing is the
cheaper outcome, so `status: "awaiting-templates"` in a profile is a hard stop
that names exactly which of the three is missing.

## Currently registered

| Key | RTO | Status |
|---|---|---|
| `mvc` | Golden Wattle Group Pty Ltd T/A Meridian Vocational College · RTO 45039 · CRICOS 03551M | **measured** — three templates supplied 31 August 2026 |
| `aci-culinary` | Bush Tukka Pty Ltd T/A Adelaide Culinary Institute · RTO 45797 · CRICOS 03978F | **measured** — three templates supplied 1 September 2026 |
| `aci-construction` | Bush Tukka Pty Ltd T/A Adelaide Construction Institute · RTO 45797 · CRICOS 03978F | **measured** — three templates supplied 1 September 2026 |

**ACI is one RTO trading under two names.** The legal entity, RTO code and
CRICOS code are identical; only the trading name differs on a record. Which name
a record carries is decided by the **vocation of the unit**, not by what anyone
types:

- an **SIT** unit (cookery, hospitality, patisserie) → Adelaide Culinary Institute
- a **CPC** unit (construction, plumbing, building) → Adelaide Construction Institute
- a **BSB** unit takes the variant of the qualification it sits in — **ask**
  where that is not obvious. Never guess a trading name onto a student record.

**ACI's two sets of marking templates are not the same files.** That question is
settled — measured 1 September 2026 — so do not point both profiles at one file.
They differ in three ways that each matter:

| | `aci-culinary` | `aci-construction` |
|---|---|---|
| RTO row | pre-filled with the identity line | `[ Insert RTO name and code ]`, filled by the builder |
| Placeholder grey | `9AA3B2` | `8A939C` |
| Feedback sheet | details table carries an RTO row | no RTO row |

The placeholder colour is the one that bites quietly: the gate's
`NoPlaceholderStyling` check looks for that exact value, so a profile carrying
the other variant's grey cannot see a field that was never filled.

## Onboarding a new RTO, or a revised template

### 1. Get the three templates

- Student Assessment Record (SAR)
- Assessment Marking and Results Record
- Student Feedback Sheet

Blank, with every field still unfilled. Copy them into
`assets/templates/` with clear names.

### 2. Measure each one

```bash
powershell -File scripts/Measure-Template.ps1 -Path assets/templates/<file>.docx
```

This reports what the builder needs and must not assume: table count and
headings, every bracketed field with its occurrence count, every standing
checkbox label, the repeating rows and their length, table widths and column
grids, and page orientation.

### 3. Write the profile

Copy `assets/rto.mvc.json` to `assets/rto.<key>.json` and work through it
against the measurement. The fields that matter most:

- **`rtoRowIsPlaceholder`** — does the template pre-fill the RTO row (as MVC's
  does) or leave `[ Insert RTO name and code ]`? `null` means unmeasured and the
  builder refuses.
- **`tables`** — the index and heading of each table. Found by index, checked by
  heading.
- **`outcomeRows` / `studentTable` / `itemTable`** — how rows are identified, and
  which row to clone when the block must grow. Note any `vMerge` master: clone
  the continuation row, not the master.
- **`placeholders`** — field text and which table it is scoped to. **Scope
  matters**: `dd / mm / yyyy` appears three times in the MVC SAR and a
  document-wide replace would fill the wrong cells.
- **`checkboxes`** — the exact standing labels, character for character,
  including the punctuation. A label matched loosely will match the wrong box.
- **`styling.placeholderColor`** — so the gate can see a field that was never
  filled.

### 4. Remove the hard stop

Delete `status: "awaiting-templates"` once all three templates are registered.

### 5. Prove it end to end

Build the worked example against the new profile and run the gate:

```bash
powershell -File scripts/Resolve-MarkingLedger.ps1 -Path examples/ledger.example.json -Out resolved.json
powershell -File scripts/Build-MarkingRecords.ps1 -Ledger resolved.json -OutDir out
powershell -File scripts/Test-MarkingRecords.ps1 -Ledger resolved.json -Dir out
```

Change `"rto"` in a copy of the example ledger to the new key first. **Open one
of each document type in Word and look at it** before marking a real batch — the
gate proves the values, not that the layout still reads well after a row was
cloned.

## When a template is revised

Re-measure and update the profile **in the same change**. A stale map fills the
wrong cell, and the builder's structural throws are the only thing standing
between a revised template and a silently mis-filled record:

> Template map expects table 5 ('admin') but the file has 4. The template has
> been revised — re-measure it with Measure-Template.ps1 before marking.

## Related

- [template-fill.md](template-fill.md) — the mechanics, and the traps
- [audit-checklist.md](audit-checklist.md) — what the gate proves once registered
