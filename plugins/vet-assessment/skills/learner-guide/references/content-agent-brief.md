# {unitCode} Learner Guide - content agent brief

<!-- TEMPLATE. Stage 3 fills every {placeholder} from contract.json and the RTO profile pack
     before an agent sees it. Never hand an agent a brief with a placeholder still in it.
     Never hard-code a unit, a brand or a path into this file. -->

| Placeholder | Filled from |
|---|---|
| `{unitCode}` `{unitTitle}` `{qualification}` `{aqfLevel}` `{acsfLevel}` | `contract.json -> unit`, `qualification` |
| `{rtoName}` `{brand}` `{unitCasing}` | the RTO profile pack |
| `{venue}` `{scenarioAnchor}` `{cohort}` `{jurisdiction}` | `contract.json -> scenario`; the RTO profile |
| `{assignment}` | the orchestrator: the sub-sections this agent writes, and whether it writes the Topic wrapper |
| `{buildDir}` `{skillDir}` `{deckLayoutsPath}` | the build |
| `{referenceForms}` | `contract.json -> referenceConvention` |
| `{hazardNotes}` `{provenanceHazards}` | the Stage 1 hazard list, filtered to this agent's sub-sections |

---

You are writing **{assignment}** of the Learner Guide and Delivery PowerPoint for
**{unitCode} {unitTitle}**, for **{rtoName} ({brand})**, delivered inside
**{qualification} ({aqfLevel})**.

You write **content only**. You never build a document. You write JSON files into
`{buildDir}\spine\`, and two renderers read them later - Word and PowerPoint - so guide text and
slide text come from **one** authored source and cannot drift.

The spine schema, the slide layouts, the four visual slots and the cross-reference convention live
in the skill's references and this brief does not repeat them. It tells you three things: what you
receive, how deep to teach, and the one rule that decides where every example is set.

---

## 1. What you receive, and what you do not

One directory per sub-section: `{buildDir}\agent-pack\<sub-section>\`. Read all of it before you
write a word.

| File | What it is | What you do with it |
|---|---|---|
| `contract.json` | The scenario card, the terminology lock, the numbering plan, and **your sub-section's question map** | Obey it. `questionMap` is the only source of your `assessmentLink.refs`. |
| `tasks.md` | The **learner-facing** text of every task your sub-section prepares - stem, scenario, column headers, row labels, word guide - exactly as the learner will read it | Teach toward it. Never restate it. |
| `withhold.json` | One entry per task: `kind`, `headers`, `assessedHeaders`, `items`, `subjects`, `unassessedSubjects`, `allowance`, `permittedGround` and `shape` | Section 2 tells you how to read `shape`; section 3 tells you where your examples go. |
| the recipe cards, appendices and the unit extract | The working facts of this unit, verbatim | The only sources you quote. |
| `figures.json` | Every working figure, its canonical wording and its authority class. **Read-only.** | Copy figures from it character for character. Never edit it, and never touch its allow-lists. |
| the shared style block | Reading level, sentence and paragraph caps, unit casing, the house conventions | Every sentence you write obeys it. |
| `{hazardNotes}` | Pack hazards dispositioned at Stage 1 that touch your sub-sections | Teach as the disposition says. Never teach around a hazard silently. |

**You do not receive the assessor guides, the model rows, the benchmarks or the marking criteria,
and nothing in this brief sends you to them.** If a path to one is within your reach, do not open
it. An answer that is read is an answer that gets written: on one build the brief allowed the
assessor guides "for one purpose only, to gauge depth", and every agent wrote the model answers
into an open-book guide - same items, same order, same words - and six audit rounds found the
leak one location at a time.

---

## 2. Depth comes from `shape`, not from an answer

Every task in `withhold.json` carries `shape`, and it is numbers only:

| Field | Means |
|---|---|
| `rows` | how many rows the learner fills |
| `assessedColumns` | how many columns per row the learner writes |
| `bulletsPerCell.min` / `.max` | how many distinct points a cell carries |
| `wordGuide` | the learner's word budget for the task |
| `benchmarkMinimum` | the number of points per cell a Satisfactory response must carry |

**Read depth off the shape.** A task of six rows by two columns, two-plus points a cell, 30 to
50 words a cell, tells you the learner must be able to produce two independent, explained
indicators for ANY item of that class in about 40 words. Teach the mechanism that produces them -
the biology, the physics, the commercial reasoning, the paperwork - to that depth, with enough
worked detail that the learner can do it for an item you never mention. **A cell needing 30 to 50
words and two-plus indicators tells you how deep to teach; the answer does not, and you have not
seen it.**

`benchmarkMinimum` is a floor on the teaching, never a ceiling. Teaching that stops short of it sets
the learner up to under-answer. Teaching that hands over the answer defeats the assessment. The
rest of this brief is how to do the first without the second.

---

## 3. The relocation rule - decided when you write, not when you are audited

**Teach the mechanism in full. Then work every example on a subject the task does not assess.**

That is the whole rule, and every leak this build family has shipped is its opposite: the
mechanism taught correctly, then worked on the exact item, machine, run or date the task asks the
learner to work. In an open-book assessment that permits the guide, a worked example on an
assessed subject **is** the answer. Relocated onto an unassessed subject, nothing is withheld,
nothing is lost, and the teaching grows, because you have to explain the reasoning instead of
listing its result.

`withhold.json` gives you, per task:

- `kind` - `labelled` (the task prints the row labels), `numbered` (the learner chooses the items),
  `records` (a log or record the learner completes), `lookup` (the answer is a value read from a
  pack document).
- `freeText` - a fifth kind: a prose part with no grid (the task asks for a written answer). It carries the same `subjects`, `unassessedSubjects`, `allowance` and `permittedGround`, and the same rule applies - teach the reasoning, work it on an unassessed subject, and never pair a listed subject with that task's answer.
- `headers` and `assessedHeaders` - the task's column headings, and the ones the learner writes.
- `items` - the row labels the task prints. `subjects` - the items a numbered grid draws on.
- `unassessedSubjects` - **the subjects you MAY work examples on.** Everything else of that class
  is assessed.
- `allowance` - how many assessed rows you may work end to end in this sub-section: **0** wherever
  `unassessedSubjects` is non-empty, **1** only where the task assesses every subject there is.
- `permittedGround` - the generator's one-line statement of where your examples may be set: the
  runs, dates, documents and items outside the assessed set.

### 3a. Tables - worked examples, practical activities, figures and slides

**Any worked example, practical-activity table, figure table or slide table that shares two or
more column headings with a grid in `withhold.json` is worked on a subject from
`unassessedSubjects`, never on an assessed row, and its intro or caption says so** - "worked on
{an unassessed subject}, which the task does not ask about". A table under the task's own headings
is a response grid, and a learner transcribes it whatever the caption says.

Assessed row labels may appear in such a table on one condition: **every assessed column of that
row carries the withhold token `Your turn: work this row from section {X.Y}`**, where `{X.Y}` is
the sub-section that teaches the mechanism. At most once per sub-section, counted across every
table in the file; never partly filled. A row with the token in one column and an answer in the
next is a filled row, and two tables each showing "one" exemplar of the same grid is two answers.

Where `allowance` is 1, work exactly one assessed row, labelled as the worked example, with every
other row carrying the token. Where `allowance` is 0, no assessed row is worked anywhere in the
sub-section.

**Brevity is not absence.** A cell holding a temperature, a time or a yes/no is a filled cell.

For a `records` task the record's own column headings count as shared headings; work the record
on a run or date from `permittedGround`. For a `lookup` task teach how to read the document the
answer lives in, and never state the value the task asks for.

### 3b. Numbered grids

**For a `numbered` task, never pair any listed `subjects` entry with the reasons that task asks
for; teach the reasoning on a different dish, machine or run.** The learner chooses the items, so
the leak is the pairing of item and reason rather than a row label, and a string sweep cannot see
it. Teach the two or three properties the choice turns on, then stop: "{documentName} names the
equipment for each recipe. Read the column, then ask which property the dish is calling for."

### 3c. Prose

**Write prose to teach the mechanism, not to the shape of a model answer: never walk the assessed
items in the task's order with an answer beside each.** That is a response grid set as
paragraphs, and it fails the same gate. **The test: could a learner transcribe this paragraph into
the response grid?** If yes, restructure it around the question you ask of ANY item - what
changes, what you see, why it matters, what you do - and work it on an unassessed one.

Coverage still applies. Every row label the task prints is TAUGHT in your prose, as a class of
thing and the reasoning that applies to it. Teach the item; do not answer the row.

### 3d. Case study and practical activity

The case study lives in `{venue}` - reuse the scenario world, never invent a second one - but its
events are set on `permittedGround`, not on the assessed run. A case study that walks the assessed
run through the assessed sequence is the answer with a narrative around it. The practical
activity's worked example and `workedExampleTable` follow section 3a: a completed example on an
unassessed subject, then `pointsTo` the real form in the assessment tool.

---

## 4. Speaker notes and self-check questions

**Speaker notes never state what an answer is "marked against", never quote a benchmark, and
never name how many rows the task has** ("asks for exactly these four rows"). A note sits on a
slide a trainer projects, and marking vocabulary on it tells the room what the assessor counts.

Every note still does two things: it says what the trainer explains and what the learner leaves
with, and it names the exact assessment item and directs learners to it per the Assessment Activity
Sequence Map. Where the slide carries a figure, the note says where the figure comes from and what
weight it carries - the code, the unit, the card or the venue's own procedure.

**Self-check questions test the method, never restate an assessed task, and there is no answer
key.** Write `selfCheck.questions` only; do not write `answerGuide`. The renderer declares that
field withheld and never prints it, because the guide is permitted in the open-book assessment
and an answer key on the learner's desk is a marking guide. A good self-check asks the learner to
apply the mechanism to an item from `permittedGround`, or to explain why the rule is the rule.

---

## 5. The dependency direction, and provenance

The assessment was written first. This guide is derived from it.

- Guide and pack disagree on a figure, a term, a count or a threshold: **the pack wins.**
- You need a fact the pack does not carry: source it from the unit, from named {jurisdiction}
  legislation, or from the venue's own documented procedure, and **say which**.
- The pack looks wrong: **write it in `openQuestions`.** Do not teach around it silently.

Every figure, threshold, temperature, duration, count and legal proposition you write carries
exactly one authority class, and goes into your file's `provenance` array:

| Class | Means | How you write it |
|---|---|---|
| **P** | the assessment pack - a card, a task stem, an appendix | "Recipe card {n} sets ..." / "the standard recipe requires ..." |
| **U** | the unit on training.gov.au | "The unit requires you to ..." |
| **L** | named legislation, a standard or a code | "{instrument}, clause {n}, requires ..." |
| **V** | the venue's own documented procedure | "The {venue} house standard is ..." - and it must say it is the venue's |

**A figure that fits none of the four is fabricated, however reasonable it looks.** For every L
figure also answer: does the source say the number, does it mandate it or only recommend it, and
does it apply to the thing you attached it to? A recommendation written as a legal requirement is
a High-risk defect; so is a requirement written as optional, and so is a venue figure written as
the law's.

**Figures are never retyped.** Take every figure from `figures.json`, character for character,
write it once in the prose, and let the slide carry the same string.

{provenanceHazards}

---

## 6. Who you are writing for

{cohort}, studying at **{aqfLevel} / ACSF Level {acsfLevel}**, with no assumed Australian
workplace, cultural or regulatory knowledge. The shared style block governs. The rules that most
often fail:

- **Sentences of 25 words or fewer.** One idea per sentence. Active voice, second person, present tense.
- **No paragraph over 300 characters.** Target 200. Longer is usually a list; make it a list.
- **Expand every acronym and gloss every workplace term at first use in your Topic.**
- **One word per concept.** The lock is `contract.json -> terminology`. Never alternate.
- **Name people by role.** The pack names no individuals and neither do you.
- **Never simplify assessed terminology.** If the unit assesses the term, the learner meets the term.
- Australian conventions: dates written out, metric, AUD, Australian spelling. Units of measure
  are written as the brand profile writes them: {unitCasing}.

---

## 7. What you write

One JSON file per sub-section, `spine\t{T}_{PC}.json`, plus - where `{assignment}` says so - the
Topic wrapper `spine\t{T}_topic.json`. Do not write one giant file.

Where the shapes live, so you write to the schema as compiled:

| Shape | Reference |
|---|---|
| The sub-section and Topic field sets, the slide object, the visual entry | `{skillDir}\references\content-model.md` |
| The order the sub-section renders in | `{skillDir}\references\learner-guide.md` section 1 |
| Layouts and the slots each must fill | `{skillDir}\references\powerpoint.md` section 2, and `{deckLayoutsPath}` |
| The four visual slots, Route A prompt rules, Route B spec rules | `{skillDir}\references\visuals.md` |

The spine writer refuses a field no renderer reads (UNREAD) and a container with no readable
content (MISSING). Fix the violation it names and write again.

Use the Write tool. Valid JSON, UTF-8, no comments, no trailing commas. Plain ASCII: straight
quotes and apostrophes, `-` not an en dash, "degrees C" not a degree symbol.

### Floors - blocking, and the expensive part

| Block | Floor |
|---|---|
| `underpinningKnowledge` | **at least 800 words**, plain running prose with no bolded terms, ten to eighteen paragraphs each under 300 characters |
| Whole Topic | **at least 3,000 words** of counted prose: `whatThisMeans` + `underpinningKnowledge` + `regulatoryBasis` + `howToDoIt` details + topic `overview`. Callout boxes do not count. |

Do not reach 800 by restating the criterion three times. Teach the subject - the mechanism, why
the rule is the rule - and follow every abstract idea with a concrete example set on
`permittedGround`.

### Field rules

- `whatThisMeans` 3 to 4 paragraphs: the criterion in plain words, what the worker does, good
  against poor practice. `regulatoryBasis` 2 to 3 paragraphs, 120 to 250 words, {jurisdiction} and
  Commonwealth instruments only, named exactly, regulator named, citing nothing this criterion does
  not engage. `howToDoIt` 6 to 9 steps with a sentence or two each. `commonErrors` 4 to 5 entries:
  the error, why it happens, what it costs. `selfCheck.questions` 4 to 5, and no `answerGuide`.
- `workedExample`, `practicalActivity` and `caseStudy`: sections 3a and 3d. A practical activity is
  never a blank template.
- `rolePlay` only where the criterion genuinely involves speaking to someone. Otherwise `null`.
- `assessmentLink.refs` **verbatim from `contract.json -> questionMap`** for your sub-section:
  nothing invented, nothing dropped, nothing borrowed from another sub-section. `wording` is
  written once and used word for word in the guide's Assessment link box and the deck's chip, in
  the reference forms `contract.json -> referenceConvention` sets, and only these:
  {referenceForms}.
- Topic file: 7 to 12 `keyTerms`, each standing alone for the consolidated glossary;
  `readBeforeYouStart` names real documents from `contract.json -> scenario` only; exactly four
  topic-level slides - `divider`, `outcomes`, `keyTerms`, `recap`.

### Slides

**4 to 6 per sub-section**, on the sub-section that teaches them. Every slide except `divider`,
`outcomes` and `key-terms` carries `notes` (section 4). No text on any shape over 420 characters:
bullets short, depth in the notes. At least one `figures` slide per Topic carrying the Topic's key
numbers. At least one `assessment-link` slide per sub-section whose `chip` is
`assessmentLink.wording` verbatim, trimmed to 180 characters if longer, keeping every reference.
A slide `table` obeys section 3a exactly as a guide table does.

### Visuals - exactly four per sub-section

| Slot | What | Route |
|---|---|---|
| `{T}.{S}.1` | Topic image | A - generated |
| `{T}.{S}.2` | Process diagram | B - built natively, `spec` required |
| `{T}.{S}.3` | Workplace image | A - generated |
| `{T}.{S}.4` | Summary table or infographic | B - built natively, `spec` required |

A Route B `spec` is the exact final wording of every node, row and label; the build's spec-writer
copies it by slot and refuses a slot with none. Never emit a diagram, chart or table as
`kind: "Image"`. A Route A prompt is one paragraph of 90 to 160 words per `visuals.md`: setting,
people by role with faces angled away, equipment, camera, lighting, colour in plain words, and a
closing exclusion clause of at least "No text, no numbers, no signage lettering, no logos."
**Slot `.4` is the figure most likely to mirror a grid; section 3a applies to it in full.**

---

## 8. Before you return

Run the sub-section test on every file you wrote:

```powershell
& "{skillDir}\scripts\Test-SubSection.ps1" -File "{buildDir}\spine\t{T}_{PC}.json"
```

**The contract is exit 0, or fix and re-run.** It reads your file against your pack's
`withhold.json` and reports the things this brief forbids: headings shared with an assessed grid
on a worked row, assessed rows worked past `allowance`, a partly filled token row, subject-reason
pairings on a numbered grid, withheld values outside a posed question, marking vocabulary in a
note, and the floors and ASCII rule. **Paste its verdict block into your report, verbatim.**

If you believe a hit is a coincidence - a heading that is ordinary vocabulary, a row label that is
the name of a class - **leave the content as it is, say so in `openQuestions` naming the hit, and
return.** Stage 3d decides, with the anchor in front of a reader, and clears a hit only by writing
a reason into `figures.json`. **You never edit `figures.json`**, because an allow-list an author
edits to pass an author's own file is not an allow-list.

---

## 9. What will fail your file

- An `underpinningKnowledge` block under 800 words, or a Topic under 3,000.
- A worked, activity, figure or slide table sharing two or more headings with an assessed grid and
  worked on an assessed row; a token row partly filled; a second exemplar in one sub-section.
- A numbered grid's subject paired with the task's reason, anywhere in the file.
- Prose a learner could transcribe into the response grid.
- A speaker note that says "marked against", quotes a benchmark, or counts the task's rows.
- A self-check that restates an assessed task, or an `answerGuide`.
- A figure with no provenance class, a venue standard written as law, or a figure not in `figures.json`.
- A reference that is not in your `questionMap`, or one of yours left out.
- A Route B visual with no `spec`, or a diagram emitted as an Image.
- Non-ASCII punctuation, invalid JSON, a field the renderer does not read.
- Invented characters, an invented venue, or an invented workplace document.
- Any edit to `figures.json`.

## 10. When you are done

Reply with **only** a short report: the files you wrote; the counted word length of each
`underpinningKnowledge` block; your Topic's total counted prose; slide count; visual count; the
subject each worked example, activity table and slot `.4` figure is set on; the
`Test-SubSection.ps1` verdict block for each file, verbatim; and your open questions. Do not
paste the content back.
