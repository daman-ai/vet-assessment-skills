# Build conventions and failure modes

Every failure mode below has shipped as a real defect in a delivered pack. They pass validation, they render fine in LibreOffice, and they are obvious the moment someone opens the file in Word. Read this before writing build code.

## Contents

1. [Toolchain](#toolchain)
2. [Palette and type](#palette-and-type)
3. [Word failure modes](#word-failure-modes)
4. [PowerPoint failure modes](#powerpoint-failure-modes)
5. [The QA loop](#the-qa-loop)

---

## Toolchain

Node with the `docx` library for Word files. `pptxgenjs` for slides. Both are usually already available; check before installing.

Copy `assets/docx-kit.js` beside the build scripts and `require('./docx-kit')`. It gives you the palette, heading levels, bullets, tables with header rows, callout panels, a footer with page numbering, and a numbering configuration with three independent numbered-list references.

Write one build script per deliverable. Do not build several documents from one script — when one needs a layout fix you will be re-rendering all of them.

Never rebuild a `.docx` by unzipping and re-zipping with shell `zip`. Word rejects the result even though `unzip -t` passes and the file opens fine in python-docx. Make every package change through the library.

## Palette and type

For an unbranded pack, a restrained scheme reads as professional rather than corporate:

| Role | Hex |
|---|---|
| Ink / headings | `33404F` |
| Body text | `222B36` |
| Accent | `1F6F8B` |
| Muted / captions | `6B7785` |
| Panel fill | `EEF2F5` |
| Accent panel | `E3EDF1` |
| Rules and borders | `C6D0D8` |
| Model answer red | `C00000` |

The deck can carry a warmer accent than the documents — a burnt ochre such as `C46A2F` against a deep ink `27333F` gives contrast that survives a projector, and reads as "flag" or "finding", which suits compliance material.

Calibri for body throughout. A serif such as Cambria for slide headings gives the deck a voice the documents do not need.

If the pack is branded, take the palette from the RTO's own brand rather than adapting this one.

## Word failure modes

### Ruled writing lines collapse into one box

Consecutive empty paragraphs each carrying an identical bottom border are merged by Word into a single bordered region. You get vertical space but only one visible rule, at the bottom.

Alternating the border `space` value between paragraphs is the documented workaround and does not reliably survive rendering.

**Use fixed-height table rows instead.** One empty paragraph per cell, with `height: { value: N, rule: HeightRule.ATLEAST }` on the row. This gives exact control over the writing space and no artefact. In the model-answer version, drop the height to `10` so rows size to their content.

### A numbered list continues from an earlier list

Two lists sharing one numbering reference run continuously across a document, so the second starts at 4 rather than 1.

Declare a separate reference per list. `docx-kit.js` ships `numlist`, `numlist2` and `numlist3` for this; pass `{ ref: 'numlist2' }` to the bullet helper.

### A table splits across a page boundary

`cantSplit` prevents a single *row* from breaking. It does not prevent a table breaking *between* rows.

To hold a whole table on one page, apply `keepNext` to every paragraph in every row except the final row. Use both mechanisms together. Word measures rows taller than LibreOffice, so a clean LibreOffice render is not evidence the table holds.

Where a block genuinely will not fit alongside what precedes it, put it on its own page with an explicit page break rather than fighting the layout.

### A near-empty page appears

Usually an empty spacer paragraph carrying `pageBreakBefore`, sitting in front of a `keepNext`-bound block. When the bound block will not fit, Word pushes it and leaves the spacer alone on a page.

Put the page break on the heading itself, not on a spacer in front of it. Size bound tables with real slack rather than to the page limit.

### A table column is crushed to one word per line

Cell width alone does not drive column width. The table grid does.

Set `columnWidths` on the table, and check the render — a column carrying prose needs roughly 3500 DXA minimum at 9–10 pt. Do not distribute widths evenly out of habit; give the prose column the room and squeeze the label column.

### Content overflows a page you intended to be complete

Trim before you shrink. Cut a redundant sentence, move a block to the next page, or shorten a callout. Reducing font size and padding to force a fit produces a page nobody wants to read.

## PowerPoint failure modes

### A heading wraps and collides with the subtitle

Section divider headings over roughly 26 characters wrap to two lines at 34 pt, and the second line lands on the subtitle beneath.

Make the divider helper measure the heading and drop to about 27 pt above that threshold, rather than fixing each slide by hand. The next divider you add will have the same problem otherwise.

### Text boxes overflow silently

`pptxgenjs` does not reflow. Set generous box heights, render, and look. Body text below about 11 pt does not survive a projector at the back of a room.

### Validation is mandatory

```bash
python3 /mnt/skills/public/pptx/scripts/office/validate.py FILE.pptx
```

Run it after every build, not once at the end.

## The QA loop

For every file, every time:

```bash
python3 /mnt/skills/public/docx/scripts/office/soffice.py --headless --convert-to pdf FILE.docx
pdfinfo FILE.pdf | grep Pages
pdftoppm -jpeg -r 90 FILE.pdf page
```

Then view every page image. Not a sample — every one. The page count alone tells you something is wrong but never what.

Validate every file before delivery:

```bash
python3 /mnt/skills/public/docx/scripts/office/validate.py FILE.docx
```

Clean the intermediate PDFs and JPEGs out of the output directory before presenting. Stray render artefacts in a delivered folder look like carelessness, and on a shared drive they will outlive the person who made them.
