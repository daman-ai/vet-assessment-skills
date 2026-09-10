# The delivered deck style

`Invoke-Render` writes a correct deck. It does not write the **delivered** deck.
Between the two sits a restyle stage that redraws every container in the house
visual language, puts a picture on every slide that can hold one, and animates
the whole thing. This file is that stage: what it does, in what order, the
values it does it with, and the things that look like polish but are not.

The rendered deck is an intermediate. Nobody presents it.

Every constant below is an integer in the generator. Nothing is derived at run
time except where it says so, and nothing here is a suggestion: this is the
format the delivered deck has, and a build that departs from it has drifted.

---

## 1. The pipeline

In this order. Each step's output is the next one's input.

```powershell
# 0. once per machine - see §8, this is not optional
.\Install-DeckFonts.ps1

# 1. keep an untouched copy of what the renderer wrote
Copy-Item build\out\XXX_Delivery_PowerPoint.pptx build\render\XXX_Delivery_PowerPoint.pptx

# 2. WHICH slide gets a photograph, an illustration, or nothing
.\New-DeckPicturePlan.ps1 -Deck build\render\XXX_Delivery_PowerPoint.pptx `
                          -PlanJson build\deckplan.json `
                          -GuideImgDir build\images `
                          -Out build\picture-plan.json

# 3. the scene illustrations, one per slide the plan asks for. -PicturePlan
#    REFUSES if a slide it names has no authored subject.
.\New-DeckDoodles.ps1 -SubjectsPath build\doodles.json `
                      -PicturePlan build\picture-plan.json -OutDir build\doodles

# 4. redraw every slide
.\Restyle-Deck.ps1 -In  build\out\XXX_Delivery_PowerPoint.pptx `
                   -PlanJson build\deckplan.json `
                   -GuideImgDir build\images `
                   -PicturePlan build\picture-plan.json `
                   -DoodleDir  build\doodles

# 5. the content gate - BEFORE animating, so a failure is cheap to read
.\Test-DeckStyle.ps1 -Source build\render\XXX_Delivery_PowerPoint.pptx `
                     -Sample build\out\XXX_Delivery_PowerPoint.pptx

# 6. animation, and the font embedding that rides on the same save
.\Add-DeckAnimations.ps1 -Deck build\out\XXX_Delivery_PowerPoint.pptx

# 7. gate again - the animation pass is a PowerPoint round-trip, and a
#    round-trip can rewrite anything
.\Test-DeckStyle.ps1 -Source ... -Sample ...
```

Keep an untouched copy of what `Invoke-Render` wrote. `Test-DeckStyle` compares
against it, and without it there is nothing to compare against.

The `.pptx` is the deliverable. Nothing in this pipeline exports one to any
other format.

---

## 2. Canvas

EMU throughout — 914,400 to the inch, 12,700 to the point.

| Measure | EMU | |
|---|---|---|
| Slide | 12,192,000 × 6,858,000 | 13.33 × 7.5 in |
| Side margin | 685,800 | 0.75 in |
| Card floor — no filled card reaches past it | 5,486,400 | 6.00 in |
| Assessment chip baseline | 5,715,000 | 6.25 in |
| Footer baseline | 6,263,640 | 6.85 in |
| Outline weight | 34,925 | 2.75 pt |

---

## 3. Non-negotiable: not one word may change

The deck's content has been through the pack's gates and a two-way question
reconciliation. The restyle moves shapes, recolours them, resizes type and
changes z-order. **It must not change a single text run.**

`Test-DeckStyle` reads the finished file back and compares text as a sorted
multiset of runs **per shape** — not per run, because PowerPoint merges
identically-formatted runs on save and a run-level comparison reports five lost
and one added on every footer. It also checks the slide count, the speaker notes
verbatim, every image relationship resolving, no shape hanging off the slide,
and that every typeface on a slide is one the restyle sets.

Every one of those is BLOCKING. The slide count is measured against the
**source** deck, not against the sample (a count taken from the sample is the
sample compared with itself, and can never differ); a notesSlide that goes
missing fails on the count rather than shrinking the comparison loop; and a
shape hanging off the slide FAILS rather than warning - `-EdgeTolerance`
declares any slack explicitly, and it is 0. The bounds scan covers `p:sp`,
`p:pic` and `p:graphicFrame`, all four edges, because the restyle resizes
tables and a table pushed past the footer was the one shape class it could not
see.

`Test-DeckStyle.ps1 -SelfTest` plants each of those defects in a minimal
package and proves the gate turns red on it. Run it after any change to the
gate: a clean result nobody has watched fail is a result nobody has checked.

**If this gate fails, the restyle is wrong.** Never relax it to make a build
pass. The one exception is `-AllowRemoved`, which names exact lines the caller
has authorised for deletion — pass the same list to both scripts, and the gate
prints each one as an authorised deletion on every run so the deletion stays
visible rather than becoming invisible.

---

## 4. Palette

Read off the template's own Resource Page, not sampled by eye. Two earlier
builds guessed the cream at `FDF6E3` and the green at `C4D6B2`; both were wrong.

| Hex | Name | Role |
|---|---|---|
| `C3DBFD` | Cornflower | Card; the chip on warm grounds |
| `FACAD3` | Blush | Card; the case-study ground |
| `FA984C` | Warm orange | Accent only — **never a card** |
| `C4D682` | Soft green | Card; the cover and recap ground |
| `F6EBA5` | Butter | Card; the outcomes ground |
| `FDD1AE` | Peach | The fifth card colour |
| `FFFCEB` | Cream | The default ground |
| `000000` | Ink | Every outline, all type |

**The orange is never a card fill.** The five pastels sit between 0.62 and 0.83
relative luminance; the orange sits at 0.43. Used as a card it made one card in
every row visibly darker than its neighbours and roughly halved the contrast of
the copy inside it. Peach is a tint of the same hue at 0.69 — inside the band,
so the row reads as one set. The orange keeps the jobs where being loudest is
the point: the title container, the divider ground, and the connectors between
process steps.

**Ground by slide role**, so the rhythm carries meaning rather than merely
rotating:

| Role | Ground | Role | Ground |
|---|---|---|---|
| title | green | figures | blue |
| agenda | cream | process | cream |
| assessment-orientation | blue | case-study | pink |
| divider | orange | table | blue |
| outcomes | yellow | recap | green |
| teaching | cream | thanks | green |

---

## 5. Typography

Both faces are the template's own, named on its Resource Page. Both are
installed on the build machine and embedded into the deck by PowerPoint on save,
so the file carries its typography anywhere. **Neither is ever emboldened:**
synthetic bold over an embedded regular is what makes a carried font look wrong
on someone else's machine.

| Role | Face | Size |
|---|---|---|
| Cover title | Sawarabi Mincho | 28 pt |
| Slide title | Sawarabi Mincho | 20 / 18 / 16 pt ladder |
| Section number on a divider | Questrial | 72 pt cap |
| Eyebrow | Questrial | 9 pt, +0.26 em tracking |
| Body and card copy | Questrial | source size, −1 pt beside a picture |
| Figure leading a line | Questrial | same size as its words |
| Connector arrow | Questrial, orange | 18 pt |
| Assessment chip | Questrial | 10 pt |
| Footer | Questrial | 9.5 pt |

**The title ladder is two steps, not five.** 20 pt where the room allows, 18 pt
where it does not, 16 pt only for a title neither will hold. Fitting each
heading to its own container instead let the wordiest one take the largest size,
so the same role read at four sizes with the ranking running backwards.

---

## 6. Containers

Not rounded rectangles. Each is a `custGeom` path of eight cubic Bézier segments
whose anchors and control points are nudged by a seeded generator — so the
outline reads as drawn by hand and rebuilds byte-identically.

| Container | Corner radius | Jitter |
|---|---|---|
| Card | 22% | 38,000 EMU |
| Card that is near square | 50% | 46,000 EMU |
| Title container | 48% | 42,000 EMU |
| Step badge | 50% (a true pill) | 16,000 EMU |
| Assessment chip | 50% | 30,000 EMU |
| Page-number disc | 50% | 22,000 EMU |
| Photograph | 9% | 30,000 EMU |

Compute the corner radius and the jitter in EMU and convert **per axis**: the
path grid stretches to the shape's box, so a single figure makes the wobble five
times wider than it is tall on a wide bar. The radius is of the **short** side.

**One outline, not two.** An offset "ghost" outline was tried and is wrong — the
template draws every container once. Against the real thing the doubled edge
reads as heavier and busier than the design is, and at the slide edge the ghost
hangs off the canvas, which the gate catches as a shape running past the slide.

---

## 7. Figures read as words, not as numbers

The rule most likely to be got wrong, and the one that took three passes to
settle:

> A figure that leads a line is set in the **same face and the same size** as
> the words it leads, top-aligned so it sits on their first line.
> `90  À la carte covers, Wed–Sat`. `1  Collect`. The text takes precedence; the
> figure gets no size of its own.

It stays a separate shape only because the renderer drew it apart and the gate
compares shape by shape. Nothing about how it is **set** may say so.

Two traps:

- **A figure is any short display-size text carrying a digit** — not
  digits-only. `Thu 17`, `2:00 pm` and `Mon 14 + Wed 16` fail a digits-only test,
  keep the source's 58 pt and print straight over their own captions.
- **Share one figure column across a row only when the figures are of a size**
  (within about 1.8×). One long figure otherwise sets the column for all four and
  leaves the short ones trailing an inch of white.

The big section number on a divider is *not* this. It is a marker with the topic
title under it, and it stays large — capped at 72 pt so it does not fill a
quarter of the slide.

---

## 8. Cards

A card row takes the **band** between the title and whatever stands below it —
not the depth the renderer happened to give it. Sizing cards to their content
instead just moves the emptiness above them as well as below.

| Rule | Value |
|---|---|
| Depth cap, by width | 1.30 × the card's own width |
| Depth cap, by content | 1.70 × the content's height |
| Minimum height | 1,188,720 EMU · 1.3 in |
| Inner padding, top and bottom | 274,320 EMU · 0.30 in |
| Inner padding, left and right | 182,880 EMU · 0.20 in |
| Content group, vertical position | 0.45 of the free space, not 0.50 |
| Row depth | one depth for every card in the row |

0.45 because card content is top-weighted — a badge or a heading first, small
print last — and set on the geometric centre it reads as having sunk.

Free-standing copy is swept afterwards so nothing sits on the block above it,
closing the gaps rather than overlapping when the column is tight. Copy that
lands **below** a picture takes the full width; copy beside it keeps the narrow
column. Decide that against where the block actually **lands**, not where it
started — a divider restacks its whole block, and a width chosen before the
sweep puts the line under the photograph.

---

## 9. Pictures

Two sources, and a slide takes at most one. **Slides carrying two or more cards
take neither**; the cards fill them.

| Measure | EMU | |
|---|---|---|
| Picture column | 4,297,680 | 4.70 in |
| Picture column, cover | 4,663,440 | 5.10 in |
| Gutter to the copy | 274,320 | 0.30 in |

**Guide photographs.** Every one is used **exactly once**, and every one is used.
A photograph goes to a slide of the guide section it was drawn for, so the
picture teaches the material it was commissioned for: the guide's
`images/manifest.json` records the figure number each photograph was drawn for,
`deckplan.json` records the section each slide teaches. It is set **inside** a
hand-drawn container filled with it — a bare rectangle on a flat pastel ground
reads as pasted on — at a 9% corner, softer than a card, because a photograph
cropped hard loses whatever is standing in its corners.

**Scene illustrations.** Everything else eligible. Drawn to the subject of its
own slide, named `DOODLE-<slide>-<name>.png` so placement is by slide and not by
sequence, and placed loose on the ground with no frame: the drawing carries its
own black line already.

Subjects are authored, not derived. Write each one from what the slide actually
teaches — the slide about four sauces competing for two burners gets four pans
crowding a two-burner range. A generic object in the right style is the failure
mode here: it matches the design and says nothing.

**Which slide gets what is decided in its own step, and it has to be.** Whether
a slide can hold a picture depends on how many cards the renderer put on it, and
that is only knowable by reading the slide XML. Deciding from `deckplan.json`
alone assigns photographs to slides that turn out to be full, and the restyle
drops them silently — eleven of twenty-two on the reference build, with nothing
reported. `New-DeckPicturePlan` counts the cards first and publishes
`picture-plan.json`, which both the doodle authoring and the restyle then read,
so the two cannot disagree. Author the doodle subjects **against that file**,
never against a hand-picked list; `New-DeckDoodles -PicturePlan` refuses rather
than let that through.

The generated files are ~1.5 MB each. The restyle resamples them to the size
they are placed at and posterises to 16 levels a channel — no visible change on
flat artwork, and the difference between a 7 MB deck and a 55 MB one.

---

## 10. Animation

The order is the point, not the effects. Heading and picture first; the content
follows.

| | What | Effect | Timing |
|---|---|---|---|
| 1 | Title block — container, title, eyebrow | Fade | 0.5 s, 0.1 s in |
| 2 | The picture | Fade | 0.6 s |
| 3 | Each card, with its own copy | Zoom | 0.45 s, staggered 0.12 s left to right |
| 4 | Free-standing copy, top to bottom | Fade | 0.5 s |
| 5 | The assessment chip | Fade | 0.45 s, 0.25 s in — last |

The container and its words arrive together. The picture arrives before any of
the words it illustrates. A card's blob and its copy arrive **together** —
animating the blob alone leaves the heading sitting on the slide while its card
flies in behind it.

**Copy in none of those buckets gets no effect at all** — which means it is on
screen from the first frame while the heading animates in around it. It reads as
the content arriving before its own heading, and nothing in the file looks
wrong. That was a real defect for 172 blocks of copy.

**Connector arrows do not animate.** A connector is not a step; three of them
blinking on after the four cards they join reads as an afterthought. They are
named as furniture so the animation pass leaves them standing, along with the
logo, footer and page number.

**Between slides: Morph.** `p159:morph` set to `byObject`, inside
`mc:AlternateContent` with a `p:fade` fallback, written after `p:clrMapOvr`.
Shapes that must carry between slides are named with a `!!` prefix so PowerPoint
force-matches them. Verify by COM that `Slide.SlideShowTransition.EntryEffect`
reads **3954**: the XML alone does not prove PowerPoint accepted it.
`Add-DeckAnimations.ps1` does this itself: after the save it reopens the saved
package, reads `EntryEffect` on every slide, and **throws before the deck is
copied back** if any slide is not 3954 - so a deck whose Morph PowerPoint
normalised away is never written over the one on disk.

---

## 11. Furniture

Standing elements, identical on every slide that carries them. A piece of
furniture that moves every few slides reads as a slip rather than as a rhythm —
the assessment chip once sat at five different heights across twenty slides.

| Element | Treatment |
|---|---|
| Assessment chip | Pill on the 6.25 in baseline, 10 pt. Blue on cream and yellow grounds, butter elsewhere — a pale pill on a pale ground separates by its outline alone |
| Page number | Ink disc, cream numeral, bottom right |
| Footer | 9.5 pt ink. At 8 pt this face renders as a grey smudge on every ground even when set in full ink |
| Logo | Top right, except the closing slide, where it is the full width of the content area |
| Table header | One fill across the row, chosen to sit off the slide's ground. The body takes cream |

---

## 12. The fonts, and why the install is a prerequisite

The deck carries its typefaces inside the file, and **PowerPoint does that
embedding itself** on the animation save:

```powershell
$pres.SaveAs($path, 24, -1)   # ppSaveAsOpenXMLPresentation, EmbedTrueTypeFonts
```

It is a `SaveAs` **argument**, not a property. `$pres.EmbedTrueTypeFonts = -1`
throws — and because that happens before the save, the entire animation pass is
lost with no file written and no error naming the cause.

PowerPoint can only embed a font it has installed, so `Install-DeckFonts.ps1`
runs first. Injecting the template's own `.fntdata` parts by hand instead does
**not** work for the Mincho: the parts go in, the declaration matches the
template's byte for byte, and PowerPoint still will not bind a large CJK face's
embedded copy to Latin text. Every heading then falls back to the body face and
the deck loses its serif/sans contrast, silently.

To tell a font-availability problem from a pipeline problem, force a known
installed face into the same slot and re-render. If that renders, the pipeline
is fine and the font is the problem.

---

## 13. Slides that are laid out on their own terms

- **Cover** — picture left at the 5.10 in column, title block right at 28 pt;
  decoration removed and the block rebuilt from scratch.
- **Divider** — the block is stacked from the top of the content area rather than
  nudged out of the renderer's spacing. Its section number alone is two and a
  half inches deep; started where a body paragraph starts, the block finishes
  below the slide and the heading runs through the line under it.
- **Closing slide** — the college mark across the full content width
  (10,820,400 EMU), then the closing lines stacked and centred under it. The
  closing lines are measured FIRST: the template mark is 2.46:1, so at the full
  width it is 4.8 inches deep, and sized blind it pushed the last closing line
  through the footer. Where the block does not fit, the mark is scaled to the
  band it actually has rather than the lines being pushed off the slide. If the template ships a row of
  blank pastel cards there, they go: that is a palette swatch, which is a thing a
  template ships to show its colours, not a thing a delivery deck closes on.

---

## 14. Traps that cost a build

- **`Set-Box` writes the XML but does not update the object `Get-Box` returned.**
  A later pass then reads the position the renderer drew, and an overlap sweep
  moves blocks onto each other. Update the object on every write.
- **`Graphics.MeasureString(text, font, width)` takes the width in PIXELS** even
  when `PageUnit` is Point. Pass a `SizeF` and check the result against a known
  two-line case.
- **Measure in the face and weight the run will actually be set in.** A face that
  is named but not installed measures as a silent substitute with quite different
  metrics, and nothing errors.
- **Fit a title container by MEASURING the heading**, never by a per-character
  allowance. The allowance is calibrated against one face; a wider one turns half
  the headings into a full line plus an orphan word inside a container that still
  had inches to give.
- **PowerShell variable names are case-insensitive.** `$face` inside a function
  taking `-Face` overwrites the parameter on the first iteration.
- Office COM must never open a file on the OneDrive path. Copy to local temp,
  work there, copy back.
