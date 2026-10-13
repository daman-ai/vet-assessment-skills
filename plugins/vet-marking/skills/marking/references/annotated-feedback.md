# The annotated feedback map

> **SUPERSEDED, 28 September 2026.** The marked assessment now carries each
> question's outcome and feedback in a box in its own right margin — see
> [marked-assessment.md](marked-assessment.md#the-outcome-also-goes-in-the-right-margin).
> That does the same job in one document instead of two, stays editable so the
> student can write their resubmission into it, and builds in about five seconds
> against the ten-plus minutes this takes on a table-heavy instrument.
>
> This remains for the one thing it still does better: it reproduces the pages
> as pictures, so it can annotate a submission that must not be reopened at all.
> Nothing calls it automatically. Prefer the margin notes.

The fifth document type, and the only one that puts the feedback **next to the
work it judges**.

```
ANNOTATED_<the marked copy's own filename>
```

Each page of the student's marked assessment is reproduced down the left of an
A4 page, **narrowed to 75% of the text width but left at the full page height**.
Every question's outcome is written in the column on the right — Satisfactory
and Not yet Satisfactory alike — and a hand-drawn arrow runs from each one to
the exact place on the page it judges.

**Narrowed, not shrunk.** Scaling both dimensions to 75% keeps the proportions
and costs a third of the page height: the student's work ends half way down and
the foot of every sheet is blank. Taking only the width to 75% opens the column
on the right without giving up any of the page. The type is therefore about a
quarter narrower than it was printed — the same squeeze a condensed face
applies. It stays legible, but it is not a facsimile, so `-KeepAspect` is there
for anyone who needs the returned work to measure true.

## Why it exists

The Student Feedback Sheet lists everything to fix in one table. For a student
with two items that is easy to act on. For a student with nine, spread over a
thirty-page workbook, it is a list of faults with no map: the student reads
*"the recipe card records no setting time"* and then has to find the recipe
card, work out which of the three cards is meant, and decide which line the
remark is about. Many of these students are reading in a second language, and
the sheet asks them to do that search nine times before they can start work.

The map does the search for them. What they get back says *this note is about
this spot*, and nothing has to be matched up by hand.

## It adds placement, never content

**Nothing on the map is written for it.** The label, the issue and the action
beside every arrow are the ledger's `items[]` row, rendered a second time — the
same row the Student Feedback Sheet prints, word for word. The map adds *where*,
and only where.

This is what keeps it from becoming a third description of the same fault. A
note composed for the map would be assessor prose written twice, and two
descriptions of one fault drift apart the moment either is edited. There is one
description, in the ledger, and the sheet and the map are two renderings of it.

It follows that the map **does not replace the Student Feedback Sheet**. The
sheet is the RTO's record that feedback was issued and it is built from the
RTO's template; the map is a reading aid that travels with it. Handing over the
map alone would drop a required record. The marked copy's red line still reads
*refer to feedback sheet*, and the sheet is still what the student works from.

## Why it photographs the page instead of reshaping it

The obvious build is to widen the marked copy's right margin and drop the notes
into the space that opens up. **It cannot be done safely.**

Changing a page margin reflows the student's own document. Every page break
moves, every table wider than the new text width runs off the page, and a
workbook whose response boxes are fixed-width table cells — which is most of
them — comes back with its layout broken. The student would receive a document
that is theirs in words and not in shape, and the assessor would have no way to
see it had happened short of reading all thirty pages.

So the builder never opens the student's work for writing. It renders each page
as a picture and annotates the picture. The submission is altered in no way at
all, the marked copy and the map cannot disagree about what is on page 9, and
the arrow lands where it lands because both are the same pixels.

The cost is that the map is not editable and its text is not selectable. That is
the right trade: the map is for reading, and the editable document the student
writes their resubmission into is the marked copy, which they also receive.

## Where the arrow points, and how it knows

Word is asked, not guessed at. `Range.Information` reports a found range's page
number and its position in points from the top-left of the physical page, and
the PDF the same document exports to is rendered in that same coordinate space —
so the two line up without a calibration step.

The chain from a feedback item to a point on a page is made of fields the ledger
already carries:

```
items[].questionNos  ->  questions[].ref  ->  questions[].anchor  ->  a point
```

Nothing new is authored to place an arrow. An item that names the questions it
answers for can be placed; one that does not, cannot.

Three candidates decide the exact point, in this order:

- **Down the page — the CENTRE OF THE WRITING.** This is the one that matters.
  It is the middle of what the student actually wrote, so the note lands beside
  the answer rather than beside an edge of it.

  **Of the writing, not of the box.** A response box is sized for the longest
  answer the writers expected, so a student who answered in six lines leaves two
  thirds of it blank. Centring on the box put the note in the middle of an empty
  page with the answer sitting well above it. Only the paragraphs carrying text
  are measured.

  The box itself is a table in every instrument measured. Where the verdict was
  found inside one, *that* table is the answer box and there is nothing to
  guess; otherwise the first table after the question's anchor is taken.
  Measuring the text also disposes of a trap: a table's `Range.End` sits just
  **past** the table, which is often on the following page, so a box wholly on
  one page looked like a box broken across two. Writing that genuinely runs over
  a break centres on the part on its **first** page — where the answer starts is
  where the student looks, and the alternative is a note on a page the answer
  merely spills onto.
- **Failing that, the outcome line.** It sits at the **foot** of the response,
  which on a long answer is most of a page below where the student was writing,
  so a note pinned there reads as a remark about the last sentence. It is found
  by searching for `Not yet Satisfactory` *only within the span between this
  question's anchor and the next one*, so the right line is found even though
  every NYS question carries the same words. Only the opening words are matched:
  RTO profiles end the line differently — *refer to the feedback sheet*, *refer
  to the feedback page* — and matching the whole sentence would find nothing on
  half the documents this runs on.
- **Last resort, half way to the next anchor.** Where a question's stem runs to
  a paragraph — CPCCSP3001's tasks do — that midpoint is still inside the stem,
  and the arrow then appears to be remarking on the wording of the question.
- **Across the page** — at the **right** edge of the text column. The middle is
  where the student actually wrote, so a marker there sits on top of their
  words; the right edge is nearly always clear, and the note it belongs to is
  off to the right anyway, which makes it the shorter arrow too.
- **An anchor matching twice is refused**, exactly as the marked copy refuses
  it. Two matches mean the builder would be choosing, and a silently chosen
  anchor puts a student's feedback on the wrong question.

## The arrow is drawn, not ruled

A preset connector draws a straight line, which reads as something a machine
added. What a marker actually leaves is a slightly uneven curve, and a student
recognises it as a person having gone through their work.

Each arrow is a custom geometry — four cubic segments whose control points are
pushed off the straight line by a wobble that tapers to nothing at both ends, so
the tail leaves the note cleanly and the head lands exactly on the target. The
amplitude is proportional to the arrow's length, so a short arrow does not look
like a scrawl and a long one does not look ruled.

**The wobble is seeded from the item's own text, never from `Get-Random`.** A
rebuild has to produce the same file: the gate reads delivered files back and
compares them against the ledger, and a document whose arrows move on every
build is a different document each time it is checked. Rebuilding the same
ledger twice produces a byte-identical `document.xml`.

## Both outcomes are shown, and the fail is blue

**Every question gets a panel, pass and fail alike.** A column carrying only
failures tells the student where they went wrong and nothing about the rest, so
a page with no panel on it is ambiguous — was that answer right, or was it not
looked at? Showing both answers that on every page, and it is the same judgement
the marked copy already carries.

| | Panel | Arrow | Ring |
|---|---|---|---|
| Satisfactory | white, thin green outline, green type | thin grey leader | none |
| Not yet Satisfactory | **solid blue panel, white type**, carrying the issue and the action | blue, full weight | numbered |

**Not yet Satisfactory is blue and not red.** The page beside it is already
carrying red and green — the marked copy's own outcome lines, the instrument's
headings, its tables. A red panel competes with what is underneath it and a
green one reads as a pass at a glance. Blue appears nowhere else in these
documents, which is the point: the student finds every panel they have to act on
by colour alone, without reading a word.

Satisfactory is deliberately quiet. It confirms the part was looked at and
passed, and it must not pull the eye away from the panels that need work.

**Only a numbered fail gets a ring.** The numbers pair a panel with its place on
the page; a student told to fix items 1 to 4 should be able to count four rings,
not find twenty-eight because every pass was numbered too. Where one item covers
a run of questions, its words go on the first question it covers and the rest
carry the outcome alone — repeating a paragraph down ten panels would bury the
page it is printed beside.

A student who was Competent still gets a map: every panel green, which is a
plain statement that each part was assessed and passed.

## The numbered ring carries the pairing, not the arrow

Every note is numbered, and the same number sits in a ring where its arrow
lands. On a page with six notes the arrows will cross, and on a crowded page the
stack of notes is pushed up or down to stop them overlapping — at which point a
note no longer sits beside the thing it points at.

The number survives all of that. A student should never have to trace a line to
work out which remark is about which answer, and the arrow alone cannot promise
they will not have to.

## Nothing is dropped, and nothing is claimed that did not happen

An item whose `questionNo` is a label rather than a question ref — *"Recipe card
2 — chocolate mousse"*, *"Observation item 7"* — has nothing in the document to
find. Those items are **still printed**, in an *Also on your feedback sheet*
block at the end of the map, and the run reports how many there were and why.
Feedback that reached the sheet but not the map would otherwise disappear
between two documents that each look complete.

Give such an item a `questionNos` entry naming the question it belongs to and it
gets an arrow like any other.

Where **no** item on a copy could be anchored, no map is built for that student.
A map with no arrow on it is the feedback sheet again behind a picture of the
cover page — it tells the student nothing they were not already given. The run
says which students those were, rather than leaving a missing file to be noticed
later.

## It finds verdicts that never made it into the response box

Because the arrow goes to the outcome line rather than to the question, the map
notices something no other check does: a verdict written **outside the student's
response box**.

```
CHECK  A verdict was found OUTSIDE the student's response box.
         ADL3000323 / Q1(c): verdict is on page 10, outside any response box (question is on page 9)
```

That is what it looks like when the marked copy walked back from the *next*
question's anchor and overshot into that question's heading block. Two things
then go wrong at once: the student's own response box comes back **empty**, and
a verdict appears above a question it has nothing to do with.
`marked-assessment.md` names this exactly — *"the student's eye goes to the box
and finds nothing in it"* — and this is how you find out the bounded skip did
not hold on a real instrument.

**The test is structural, and self-calibrating.** A page-distance test cannot do
this job: a long answer legitimately runs its verdict onto the next page, so
distance flags correct work and still misses a verdict that sits one page on in
the next task's heading block. Instead, each verdict is asked whether it is
inside a table — these instruments put every response in a bordered box, and the
skill's own rule is that the outcome lands in that box. Where most of a
document's verdicts are in a box, the handful that are not are the anomalies and
are named. Where hardly any are, the instrument does not work that way and the
test says nothing rather than flagging every question.

The map cannot fix it; it points at where the line actually is. **Fix the marked
copy**, then rebuild the map.

## The whole assessment, by default

The map carries **every** page of the marked copy, annotated where there is
something to say. That is the point of it: the student reads one document end to
end — their own work, with the outcomes where the outcomes belong — instead of
an extract that sends them back to the marked copy to see what came before and
after.

A 54-page workbook therefore makes a 54-page map, around 9 MB at the default
150 dpi. Where a short handout is what is wanted instead, `-NotedPagesOnly`
keeps only the pages that carry an outcome:

```powershell
.\Build-AnnotatedFeedback.ps1 -Ledger run\resolved.json -MarkedDir run -NotedPagesOnly
```

`-Dpi 110` roughly halves the file size and is still legible on screen, which is
worth having for a class of twenty going out by email.

## Orientation

| | Student's work | Note column | Page used |
|---|---|---|---|
| `-Orientation Portrait` (default) | full page height, narrowed to 75% of the width | narrow — short notes read well, long ones run deep | all of it |
| `-Orientation Portrait -KeepAspect` | scaled to 75% both ways, so nothing is squeezed | same | about two thirds; the foot of the page is blank |
| `-Orientation Landscape` | fitted to the page height, proportions kept, so smaller | wide — a long note fits on two lines | nearly all |

Portrait is the default because the student's own work is the thing being read
and it stays legible narrowed. `-KeepAspect` restores true proportions at the
cost of a third of the page. Where a cohort's feedback runs long, landscape
gives the notes roughly three times the width and keeps the proportions too.

## Building it

```powershell
.\Build-AnnotatedFeedback.ps1 -Ledger run\resolved.json -MarkedDir run -OutDir run
.\Build-AnnotatedFeedback.ps1 -Ledger run\resolved.json -MarkedDir run -Orientation Landscape
```

It runs **after** `Build-MarkedAssessment.ps1`, and reads the marked copies
rather than the raw submissions — so the map shows the green and red outcome
lines the student will see, not an unmarked page.

It needs Word (for the coordinates and the PDF export) and
`Windows.Data.Pdf` (to render the pages), both of which the skill already
depends on. `-Dpi` controls how sharp the page pictures are; 150 is the default
and is legible on screen and in print. `-KeepPages` leaves the intermediate
PDFs and PNGs in place for inspection.

### How long it takes, and how to find out where it went

`-Timing` prints the elapsed time of each stage:

```
  [t] geometry+pdf        5.1s
  [t] render pages        1.9s
  [t] layout              0.2s
  [t] write docx          8.4s
```

Word COM and the PDF renderer are both slow enough, and vary enough between
instruments, that "it is taking a while" is not a diagnosis. Use this before
changing anything: measured separately, the Word stages on a 37-page cookery
booklet come to about five seconds in total, so a long run is not the document
being large.

**KNOWN: some instruments are much slower than their page count suggests.**
CPCCSP3001 builds 54 pages in under two minutes; SITHPAT020, at 37 pages but 71
tables, takes far longer. The Word stages are not the cause — they were measured
at roughly 5s — so a slow run on a table-heavy instrument is expected for now
and `-Timing` is the way to see which stage owns it. A class of twenty on such a
unit should be run with time to spare, or with `-NotedPagesOnly` and a lower
`-Dpi`.

## Related

- [feedback-writing.md](feedback-writing.md) — the wording the map renders
- [marked-assessment.md](marked-assessment.md) — the document it annotates, and
  where `anchor` semantics are defined
- [ledger.md](ledger.md) — `items[]`, `questionNos` and `questions[]`
