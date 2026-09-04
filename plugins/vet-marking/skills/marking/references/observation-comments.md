# Writing the assessor comments on an observation sheet

This is the house standard for the prose that goes into an **Assessor comments**
area on a practical observation sheet. It is narrower and stricter than the
general feedback standard in [feedback-writing.md](feedback-writing.md), because
these comments are read by an auditor as the record that the observation
happened and that this student, not a generic student, was watched doing it.

## The voice

Write the way an experienced assessor writes **on the day**: plain, direct,
slightly clipped. Not polished corporate prose, and not a report.

## What you must be given

Ask for all of it. Do not proceed on three of the four.

1. The **unit code and title**.
2. The **observation sheet** itself — its checklist items and every comments
   area it contains.
3. Each **student's name**, and their completed deliverables or written work for
   that task.

## One comment per comments area

If the sheet has several occasions, or several boxes, write one for each and
match whatever the sheet actually provides. Do not merge two boxes into one
comment, and do not invent a box the sheet does not have.

### A comments COLUMN is not a comments box

Some sheets — ACI's construction checklists among them — carry no `Assessor
comments` box at all. What they have is a narrow **Comments cell beside every
criterion**, twenty-eight of them on one sheet. Holding each of those to the
standard below produces a page of padded, near-identical prose that says less
than one line each would.

So a column sheet's cells take a **row note**, one per criterion row, in sheet
order:

| Rule | Limit |
|---|---|
| Sentences | 1 or 2 |
| Words | 25 |
| Commas in one sentence | 2 |
| Voice | past tense, third person, no assessor filler |

Everything that protects the record is kept — the banned phrases, the person, the
two-comma rule, and the requirement that every note names something in that
student's own work. Only the shape rule written for a box is dropped.
`Test-ObservationRowNoteStyle` in `Lib-Text.ps1` is the check, and the resolver
applies it wherever `observationSheet.layout` is `columns`.

## What each comment must do

1. **Confirm the checklist items for that observation were met** and that the
   student performed competently. Assume competency. No hedging, no gaps, no
   improvement areas unless you are asked for them.
2. **Name at least three specifics from that student's own work** — the item
   they chose, the location, the rating or measurement, the method or tool
   selected, the wording they used, what another participant contributed, what
   they escalated. These are what make the comment theirs rather than anyone's.
3. **Say what the student did, and in what order, tied to the criterion.**
   Behaviour, not labels.
4. **Show the written work carrying through into the performance.** The plan
   they wrote and the thing they then did are one story.
5. **Cover any safety, PPE or procedural item the checklist lists.**

## The writing rules

| Rule | Limit |
|---|---|
| Sentences per paragraph | **2** |
| Words per paragraph | **20**, counting both sentences together |
| Paragraphs per comment | **2** |
| Commas per sentence | **2** — the house rule, and it applies here too |

- **Past tense, third person, active voice.**
- **Plain assessor language.** No *demonstrated a sound understanding*, no
  *showcased*, no *effectively utilised*, no adverb padding.
- **Vary the sentence openings.** Do not start every sentence with the student's
  surname.
- Output **only the comment text**, ready to paste. No headings.

## The date

Include the assessment date **once**, and only if the comments area itself
requires it. Where the sheet has its own date field, leave it out — a date
written twice is a date that can disagree with itself.

## Uniqueness — the rule that matters most

A cohort of comments that read as variations of one comment is not a record of
twenty observations. It is one observation, copied.

- **No two students share an opening sentence, a sentence structure or a
  descriptive phrase.**
- **A student's own comments must not echo each other** across boxes.
- Any distinctive phrase may appear **once across the whole cohort**.
- **Cover the student's name and the comment must still identify who it belongs
  to** from its content alone. If it could describe anyone, rewrite it.
- **Before returning, compare every comment against every other** and strip
  repeated phrasing.

`scripts/Test-ObservationComments.ps1` checks the countable parts of all of this
across the whole cohort at once, including the repeated-phrase rule. Run it
before the comments go anywhere near a ledger.

## Where the work is too thin

**Say so. Do not invent detail.** A comment naming three specifics that were not
in the student's work is fabricated evidence on a signed record, and it is worse
than an honest gap.

> Ravi Deshmukh — Occasion 2: the submitted plan names no site, no rating and no
> control, so there is nothing specific to write from. Ask for the completed
> planning sheet before this comment is written.

This is the same rule as **never invent evidence** in
[marking-standard.md](marking-standard.md), applied to prose instead of to a
judgement.

## Output format

One row per comment:

```
Student Name | Occasion or box | Assessor comment
```

## A worked pair

Two students, same task, same checklist. Note that neither opening sentence,
sentence shape nor descriptive phrasing is shared, and that either comment
identifies its student with the name covered.

> **Amara Nwosu | Occasion 1 |**
>
> Selected the loading dock and rated the pallet stack 4 for likelihood. Boots
> and hi-vis went on first.
>
> Escalated the blocked exit to the site supervisor. The damaged pallet was
> tagged out on the spot.

> **Tomas Ruiz | Occasion 1 |**
>
> Chose the cold store and measured the aisle at 900 mm. Freezer jacket and
> gloves went on before entry.
>
> His hazard sheet named ice build-up near the evaporator. Another participant's
> broken light was added and attributed.

**Revised 3 September 2026: twenty words is a FLOOR, not a ceiling.** The rule
used to cap a paragraph at twenty words, and the comments it produced were too
thin to stand as a record of what the assessor saw. A comment is now **at least
two paragraphs of at least twenty words each**, and no more than four sentences
or seventy words to a paragraph so it cannot sprawl the other way. The examples
above are therefore the *minimum* shape now, not the maximum.

Everything else is unchanged: two commas to a sentence, no assessor filler, past
tense, third person. The three specifics still have to be there — Amara's dock,
her rating of 4 and her escalation; Tomas's cold store, his 900 mm and the other
participant's light.

**Two standards, one shape.** `Test-ObservationCommentStyle` judges a *record* of
what happened and holds it to third person. `Test-AssessorComment` judges the
comment the *student* reads — on a tool, or on a task inside one — and drops the
person rule, because that one is written to them: *You answered all twelve
questions*. Both carry the same length rule. The narrow comments column beside
each criterion is different again and keeps its own short standard, one or two
sentences and twenty-five words — see `Test-ObservationRowNoteStyle`.

## Related

- [feedback-writing.md](feedback-writing.md) — the general feedback standard and
  the two-comma rule
- [marking-standard.md](marking-standard.md) — never invent evidence
- [marked-assessment.md](marked-assessment.md) — where the observation record is
  written into the sheet
