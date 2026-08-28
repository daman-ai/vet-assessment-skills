# Diagram specs

A diagram is never a picture. It is built as **native Word objects** — a
drawing canvas of real shapes, or a real Word table — so every box is
clickable, every label is live text, and an assessor can retype a word without
anyone regenerating anything.

Your job is to turn the diagram prompt the document carries into a spec. The
renderer does the rest. Specs cost nothing to build and nothing to fix, so
iterate freely.

## Writing one

Put the spec object into the manifest entry's `spec` field and set `status` to
`spec-ready`. Anything still on `needs-spec` blocks the build.

```json
{
  "layout": "process",
  "orientation": "horizontal",
  "nodes": [
    { "text": "Record the fault", "note": "on the delivery docket" },
    { "text": "Segregate the stock" },
    { "text": "Notify the supplier" },
    { "text": "Complete the credit", "fill": "accent" }
  ],
  "edges": [ { "from": "n1", "to": "n2", "label": "same day" } ]
}
```

| Field | Meaning |
|---|---|
| `layout` | `process`, `bands`, `cycle`, `hierarchy`, or `table` |
| `orientation` | `horizontal` (default) or `vertical`. `process` only |
| `nodes[].text` | The label. Two or three words. This is the content |
| `nodes[].note` | Optional smaller italic second line — a figure, a range, a qualifier |
| `nodes[].fill` | `light` (default), `accent`, `navy`, `orange`, `grey`, `white` |
| `nodes[].shape` | Optional preset: `roundRect` (default), `rect`, `ellipse`, `diamond` |
| `edges[].label` | Optional words on an arrow. Labels are applied to arrows in order |
| `rows` | `table` layout only: an array of row arrays. First row is the header |
| `headerRow` | `table` layout only. Default true |

Named fills only — never a raw hex. The names map to the RTO's palette in
`config/defaults.json`, so a brand change repaints every diagram at once.

## Choosing the layout

| The prompt describes | Use |
|---|---|
| Steps in order, one after another | `process` |
| A scale, a range, or a bar split into named parts | `bands` |
| A loop that returns to its start | `cycle` |
| One thing above several things — a team, a structure | `hierarchy` |
| A grid: hazards against controls, options against criteria, anything with column headings | `table` |

**When in doubt, use `table`.** It is the most robust thing in this skill:
it never overflows, it is searchable, it is read correctly by a screen reader,
and an RTO can edit it without touching a drawing tool. Reach for a canvas only
when the arrows genuinely carry meaning.

`process` with more than about five boxes, or `hierarchy` with more than about
five children, stops being readable at A4 width. Split it in two, or render it
as a table.

## Preview before you place

```powershell
& "$s\Show-DiagramPreview.ps1" -ManifestPath .\images\manifest.json -OutDir .\images\previews
```

It runs the real layout engine, reports any box that overflows the column or
overlaps another, and writes a PNG you can look at. Exit code 5 means it found
a geometry problem.

The PNG is a check, not an output. It never goes into a document.

## Captions and alt text

Both are required, same as for an illustration, and both are your job.

For a diagram the alt text must carry **every label and the relationship
between them**, because the labels are the whole content:

> A horizontal bar in three bands: cold at 5 degrees and below, the danger zone
> from 5 to 60 degrees, and hot at 60 degrees and above.

Not "a diagram of the temperature danger zone". That tells a reader who cannot
see it nothing at all.

## What not to do

- **Do not send a diagram to the image model.** `New-DocImages.ps1` skips them on purpose. A generated diagram carries labels no one can correct and spelling no one can trust.
- **Do not bake a figure into a label that belongs in the caption.** `5 degrees` in a box, `Temperatures in degrees Celsius` in the caption.
- **Do not use `orange` for more than one node.** It is an accent in this house style, not a fill.
- **Do not exceed eight boxes on a canvas.** `config/defaults.json` records the limit; the reason is legibility at print size, and no font trick fixes it.
