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

**All nine templates share one palette, and the feedback sheet shares one layout
across the three brands** — the RTO's instruction of 2 September 2026. The three
feedback templates are the same document and differ **only in the RTO row**; the
SAR and the marking record keep each brand's own structure and were recoloured to
the same values:

| | |
|---|---|
| Accent — section headers | `234B8C` |
| Row fills | `F0F2F7` / `F7F9FC` |
| Rules | `C3CBDA` |
| Unfilled field text | `8E96A3` |

Page one of every marked copy takes the same accent, through
`markedAssessment.headingColor`, so a class receiving some marked copies and some
standalone sheets reads one document.

**A shared layout is not a shared file.** The header, the footer, the logo and
the document number stay each brand's own — Bush Tukka cannot issue a record
under Meridian's logo, and a footer reading `MVC-CMS RTO # 45039` on an ACI
record is a mis-issued document however right the body is. When a layout is
carried across, replace **`word/document.xml` only**, in a copy of the receiving
brand's own file, and check afterwards that every other part is byte-identical to
what that brand supplied.

The gate's `NoForeignRtoIdentity` reads every part of every record, headers and
footers included, and fails on another registered provider's name. Nothing else
in the gate reads a header, so a logo swap is otherwise invisible.

**The SAR and the marking record are still each brand's own files**, measured
1 September 2026, so do not point two profiles at one of those. They differ in
ways that each matter:

| | `aci-culinary` | `aci-construction` |
|---|---|---|
| RTO row | pre-filled with the identity line | `[ Insert RTO name and code ]`, filled by the builder |
| Document numbers | its own | its own |

`styling.placeholderColor` is the setting that bites quietly: the gate's
`NoPlaceholderStyling` looks for that exact value, so a profile left on a colour
its templates no longer use cannot see a field that was never filled. All three
now read `8E96A3`, which is the grey the shared feedback layout uses; it was
`9AA3B2` and `8A939C` while the two ACI sheets were their own designs.

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
- **`styling.feedbackAccentColor`**, **`styling.feedbackSheetFill`**,
  **`styling.feedbackSheetRule`** — the Student Feedback Sheet's banner, label
  tint and hairline rule, measured from that RTO's own sheet. The marked copy
  rebuilds the sheet on page one from these, so a profile that leaves them out
  gets the house values (`234B8C` / `F0F2F7` / `C3CBDA`) and a feedback page
  that does not match the standalone sheet the same class receives.

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
