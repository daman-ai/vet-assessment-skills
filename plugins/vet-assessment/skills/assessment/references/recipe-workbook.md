# The Recipe / Activity Workbook

Built **only** where the unit requires food to be produced. Every other unit carries its practical evidence inside Section B of the UAT — see `simulated-industry.md`.

Ported from the MVC Recipe/Activity Workbook Master Production Prompt v4.0, with the four cover-sheet positions superseded per `assets/templates/README.md`.

---

## 1. The trigger test

Build the recipe workbook where the **Performance Evidence requires producing food items or dishes to standard recipes** — a stated number of products, portions, dishes, service periods or occasions.

Signals in the Performance Evidence: *produce*, *prepare*, *cook*, *plate*, named products or product groups, portion counts, "using standard recipes", "to industry standards", commercial time constraints.

Not a trigger: a unit that only *plans*, *costs*, *orders*, *stores* or *supervises* food without producing it. Those are practical, but they are Section B work.

**State the decision and its reason in the compliance report either way.** An omission is a decision to be reported, not a silent gap.

**The trigger decides the whole pack shape.** Food production gives FOUR documents - a knowledge-only UAT1 and a recipe workbook, each with an assessor guide. Everything else gives TWO - one combined UAT carrying Section A Knowledge and Section B Performance, plus its assessor guide. See `simulated-industry.md`.

Where it is built, the knowledge tool carries **no practical section at all** - the practical is a separate assessment task in the workbook. **Never duplicate a recipe card, a production observation or a dish record in the knowledge tool.**

---

## 2. The workbook and its assessor guide

| Document | Audience |
|---|---|
| `[UNIT]_Recipe_Workbook.docx` | The learner. A book the student writes in. |
| `Assessor_Guide_[UNIT]_Recipe_Workbook.docx` | The assessor. **Mirrors the workbook exactly** and adds benchmarks, model answers and observable indicators. |

Both come from the same template, so they carry the same branding and the same field-driven footer.

> **No separate `[UNIT]_Assessor_Evidence_Pack.docx`.** The v4.0 master prompt at `D:\Superseded\` requires one; the measured architecture has four documents and no such pack, and the assessor layer lives in the mirrored assessor guide. Do not re-derive the pack from that prompt.
>
> **But raise it once per build.** The pack existed to carry assessor records the mirrored guide does not replace - see section 8. Their absence is a real gap, not a simplification, and it is the RTO's decision to accept or close.

The learner workbook stays **learner-facing**. A record the assessor completes must never be printed in the student's copy, because that invites a student to fill in evidence meant to be independent.

---

## 3. The inclusion test — what goes in the workbook

This governs **all three written activity types** independently: theory questions, the case study, and the recipe/quantity-adjustment templates. Each is tested and omitted separately.

The workbook sits beside the UAT. Assessing the same requirement twice wastes learner time, creates two versions of the same benchmark, and hands an auditor two records to reconcile.

**Build an activity only where BOTH are true:**

1. it is a **mandatory requirement of the unit** — a Performance Evidence item, a Knowledge Evidence point, a performance criterion, a Foundation Skill, or a requirement stated in the Assessment Conditions; **and**
2. it is **not already assessed** — not in the UAT, not elsewhere in the pack, not elsewhere in this workbook.

If either fails, **omit that activity entirely** — no heading, no empty section, no "for practice" version. Nothing goes in because it is interesting, because it rounds the document out, or because the template has a block for it.

Where a requirement is genuinely better evidenced in the workbook than in the UAT, **move it — do not duplicate it** — and say so in the compliance report.

| Activity | Build only where the unit mandates… | Otherwise |
|---|---|---|
| Theory questions | knowledge the UAT leaves unassessed | omit the section |
| Case study | planning, sequencing, or responding to a documented customer or production scenario | omit the section, including the detailed scenario and every template |
| Recipe requirements / quantity adjustment templates | calculating quantities, scaling a recipe, adjusting yield or portions | omit those template pages |

> **On the MVC measured architecture the last two are not built at all** — section 4 records that the RTO's own artefact carries no case study and no quantity-adjustment templates, which settles this test for those two before you run it. The test still governs for another RTO whose artefact does carry them, and the include-or-omit decision for all three is still reported.

The **recipe cards themselves are not subject to this test.** They are the practical production record and are always built.

### Precedence over the observation instrument

Section 6 below requires **every** performance criterion to appear on at least one observation sheet. A performance criterion is therefore *always* assessed practically, even when a written activity also covers it. The two rules reconcile like this:

- A written activity built for a PC gathers the **reasoning**. The observation sheet judges the **performance**.
- The justification box says exactly that: *"This question gathers the written reasoning behind the criterion. The practical performance is judged separately on Observation N."*
- It must **never** claim a PC is assessed "here and nowhere else" when an observation sheet also carries it. That statement is checkable in one search and it will not survive validation.
- Where the requirement is a Knowledge Evidence point rather than a PC, "assessed once, and nowhere else" remains correct and should still be stated.

### Question format

Break every question into numbered **Parts**, each with **its own box and its own writing space** — a tinted label row carrying `Part n.` and the task, above a bordered answer row. A learner working through a boxed list cannot skip a component without leaving a visibly empty box, which is the point. Never run the components together as a bullet list above one large answer box.

**A scenario is not a Part.** Context — a shift, an order, a set of conditions — goes in its own **Scenario box** above the Parts. It is read, not answered, so it carries no numbered label and no writing space. Number only what the learner must actually do. A scenario given a `Part 1.` label and an answer box asks the learner to write a response to a statement of fact, which is the most common way a boxed question goes wrong.

**Paging.** Two Parts sit under the question header, or one Part where the question carries a Scenario box, since the box takes the room the second Part would have used. The remainder start on the next page. Answer rows around 2200 DXA for a four-part continuation page. Bind each box so its label row and answer row cannot separate across a page break, and never strand a single Part on a page of its own. Close with the minimum word count in italics.

---

## 4. Document structure, in order

> **The RTO's measured order governs.** What follows is the MVC house order as measured on 21 August 2026. Where a section below is not in that measured order, it is **not built** — see the note after the list.

1. **Assessment cover sheet** — the approved MVC sheet, leading the document, ahead of the title page. Verbatim. One page. See `template-build.md`.
2. **Title page** — the `ASSESSMENT` wordmark, tagline, unit code and title, release, cover photo space, RTO block. **No qualification. No AQF level. No colour band.** The cover photo space carries a landscape `[IMAGE: ...]` prompt written by `Build-Pack.ps1` — section 12.
3. **Instructions to students**
4. **Principles of assessment and rules of evidence** - two tables, eight rows total. The workbook shipped with only the four principles under a heading naming both; corrected 21 August 2026 by adding the four rules of evidence, written to the practical subject matter rather than copied from the knowledge tool. — where the heading names both, the document carries **all eight**, in two tables as the UAT does: fairness, flexibility, validity, reliability; then valid, sufficient, authentic, current. Validity and valid are distinct concepts - one is a principle of assessment, the other a rule of evidence - so the count is eight, not seven. A four-row table under a heading naming both is a claim the document does not honour. Where only the principles are wanted, rename the heading instead.
5. **Assessment conditions** — in **bullets**, one condition per bullet, never as prose. The learner scans this before they start; a paragraph hides the condition that matters to them.
6. **Workbook purpose** — one paragraph: alignment to the unit's PE, KE and assessment conditions; used with the assessment pack; not a stand-alone competency decision.
7. **Current unit focus** — bulleted summary of the exact PE production requirements.
8. **How to use this workbook**
9. **Theory questions** *(conditional — section 3)*, including the *Special customer request adjustment* question. That one is explicitly marked **"Not assessed in UAT 1."**
10. **Special customer request scenarios** — the scenario list, followed by the allocation table required by section 7.
11. **Product evidence matrix** — each required product mapped to group, base, filling, coating, decoration, special-request option and PE coverage note.
12. **Recipe cards** — one per required product, **all together**.
13. **Observation instrument cover** — *Assessment instrument — observation of practical competency*.
14. **Observations 1 to N** — **all together at the end.**

**Not built, because the RTO's artefact does not have them:**

- **No case study**, and no detailed scenario block
- **No recipe requirements or quantity adjustment templates**
- No observation sheet interleaved between recipe cards

> If a future RTO's artefact does carry them, measure it and build them.

### Why the title page prints no qualification

Most SIT units are packaged into more than one qualification — SITHPAT018 runs in both SIT40721 Certificate IV in Patisserie and SIT30821 Certificate III in Commercial Cookery — so any printed qualification is wrong for part of the cohort. The `Qualification:` field on the cover sheet is part of the approved wording and stays, **blank for the student to complete**. The observation instrument cover leaves it blank too.

The AQF level follows the qualification, not the unit, so it differs between cohorts and is not printed either.

> This diverges deliberately from the UAT, which **does** print both, because the UAT is built per qualification. Do not harmonise them.

---

## 5. Recipe card structure

Every card is a complete, professional standard recipe. In this order:

1. **Product banner** — navy band with the product name and recipe number.
2. **Photo space** — the merged photo cell on the right of the header row, carrying an `[IMAGE: ...]` **prompt block**, not a dashed empty box and not a caption. One per card, `ASPECT: square`. The artwork pass replaces it with the real photograph and deletes the prompt.
   > **Write the prompt into the cell — see section 12.** The picture is sized to the CELL, not the page column, so nothing about the width belongs in the prompt. The old warning here about a find-and-replace hitting the cover photo first is retired: only the cover placeholder survives the seam, and each prompt now names its own subject.
3. **Header — one table, never nested.** Information left, photo right, built as a **single table** with the photo as one cell **vertically merged** down every details row. Three rows of label/value pairs across the row, not six stacked rows. Widths 1150 · 1500 · 1400 · 1250 · **4338**.
   > **The five widths must sum to 9638**, the house table width. They were documented as ending in 3726, which sums to 9026 — the cover-sheet width, not the body width — so a card built exactly as written here failed the blocking `ColumnWidthSum` check and no workbook could be built. Corrected 27 August 2026. Give the LAST column the remainder; never floor every column.
   > **Do not nest tables to achieve this.** A details table and a photo box inside the cells of an outer two-column table render correctly in some renderers and **overlap in Word**. The vertically merged cell is the only reliable construction. Where a nested table is unavoidable elsewhere, it carries both its own `tblW` and `<w:tblLayout w:type="fixed"/>`.
4. **Competency focus** — its **own independent box** with an orange left rule, not a row inside the details table. States the performance criteria the recipe demonstrates and the evidence tags.
5. **Ingredients table** — ingredient, quantity, unit.
   - **Every quantity is a number.** No blanks, no "to taste", no "piping bag" in the quantity column. Where the source recipe omits one, supply a defensible value and list it in the compliance report for the chef to confirm.
   - **Every unit is present and normalised, in lower case**: `gms`, `ml`, `each`, `tbsp`, `tsp`, `drops`, `pinch`, `sheet`. **Grams are `gms` — never `g`, `G` or `Gms`.** This is an MVC/ACI divergence, not a drafting slip; the brand-crossover sweep catches `Gms`.
   - **No conditional quantity in a summative recipe.** "Use half the xanthan gum if your blend already contains it" is training advice. In a standard recipe two candidates work to two different formulas and the assessor marks two different products. Specify the one product the assessment uses and give a fixed quantity.
   - **Component sub-headings** are bold navy on a tinted row, so a multi-component recipe reads as separate builds.
6. **Method** — **3 to 5 steps.** Short, plain, imperative, present tense, one action per step. Not thirty. Where the recipe has components, repeat the bold component heading and restart numbering at 1 under each.
7. **Test and Tip** — a bold `Test:` line giving the check the learner makes before moving on, and a bold `Tip:` line giving the advice that prevents the most common mistake.
   > **Check the source method first.** Some chef's methods already carry `Test:`, `Tip:` or `To hold:` inside their numbered steps. Do not add a second pair.
   > **The Test must agree with the method.** A `Test:` naming a temperature the method cannot reach is a food-safety defect, not a wording slip. Where the method uses a low-temperature or sealed process, state the endpoint the method actually delivers and add a step requiring time and temperature to be recorded as a validated process in the food safety plan.
8. **Storage and presentation** — storage and labelling as **bullets**, one instruction per point, then a bold `Presentation standard:` label and the description of the finished product.

**Do not include** a student record section or a signature block on a recipe card. Signatures appear in four places only: the cover sheet's student declaration and administration receipt, the trainer signature row on each observation sheet, and the assessor declaration in the workbook's assessor guide — there is no separate evidence pack (§2, §8).

### Bold action labels

Where a line opens with an action word, that label is **bold navy** and the instruction after it is plain. The approved set: `Test:` · `Tip:` · `Note:` · `Presentation standard:`. Inside a box: `Spoilage check` · `Equipment fault` · `Quality deficiency`. Set the label as its own run; do not bold the whole paragraph. Do not invent a new label without adding it here first.

---

## 6. The observation instrument

**Placement — collected at the end.** One sheet per element of the unit, and **all the sheets sit together at the end of the workbook**, after an instrument cover page.

> **The v4.0 master prompt at `D:\Superseded\` says to interleave them after each recipe, and calls end-collection a build defect. Do not re-derive that layout from it.** The RTO artefact collects them at the end; measured 21 August 2026.

The **instrument cover** goes once, ahead of the sheets: *Assessment instrument — observation of practical competency*.

**Heading form** is `Observation N` **tab** `Element title` — a tab, not an em dash. Confirmed at byte level in the source; reproduce it.

Each sheet carries:

- **Heading** — `Observation N — [element title]` on a navy banner, with a line naming the element.
- **Criteria table** — four columns: `PC · The student did this · S · NS`. **No per-row assessor notes column** — a 3 cm column repeated down seventy rows is unwritable, and the assessor only needs one place to write. The S and NS cells are left **empty** for the assessor to mark; **no checkbox glyphs**.
  - Every criterion is **one observable action**, plain English, past tense.
  - The **PC column is populated on every row**.
  - Every action is marked **individually** — never one Yes/No for a whole sheet.
- **Assessor notes** — one combined full-width box directly beneath the criteria table, deep enough to write in.
- **Result block** — a `Result` row reading `Satisfactory / Not satisfactory`, and a `Trainer signature` · `Date` row. The two rows are **one continuous table**; stacked tables leave a visible gap. No "questions asked during the task" row, no "reasonable adjustment applied" row, no "date to be repeated" row, no signature block beyond the trainer row.

> Checkbox glyphs appear **only** on the assessment cover sheet, where the approved wording requires them. Nowhere else in the workbook.

> When you remove a field, search the instrument cover for instructions that referenced it. Removing the notes column and the adjustment row leaves two assessor instructions pointing at fields that no longer exist.

**One sheet, one page.** Cut the table's vertical cell margins to zero and shorten the assessor notes box before touching the criteria — the padding is nearly always where the overflow is, and the criteria are the instrument.

**Every performance criterion in the unit must appear on at least one sheet.** State the coverage count in the compliance report.

### Contingent criteria

The rule is `compliance-rules.md` section 5. In this workbook the events are typically reporting spoiled stock, reporting an equipment fault, identifying a quality deficiency, referring a decision outside the learner's scope, or correcting a plate at the pass.

**Where the instrument carries one, the trigger is named on the instrument cover** — an **Assessor-supplied triggers** box listing the trigger for each, with the instruction to set it up before the session and record which was used. That placement is specific to this workbook, because the sheets are collected at the end and the cover is the only page the assessor reads before the session.

---

## 7. Special customer request allocation

**Every recipe carries a scenario, and every scenario produces a real modification.** A mapping naming a scenario the recipe cannot answer is worse than no mapping, because it lets an assessor nominate a dish that cannot generate the evidence. Two failures to check for:

- **Nothing to act on** — a nut-allergy request against a dish with no nuts; a lower-fat request against poached fruit; a gluten-free request against a dish that never contained gluten.
- **Impossible** — an egg-allergy request against an omelette. Where the ingredient carries a Performance Evidence requirement it cannot be removed, so that scenario cannot apply to that dish.

**Set the allocation out in its own table** after the scenario list: recipe, scenario number, and *the modification the assessor observes*, written concretely. "Scenario 1" alone is not an allocation; "Scenario 1 — corn tortilla with gluten free labelled beans" is. Use every scenario at least once.

**An allergen substitution names every shared machine, not just the hand tools.** A control listing board, cooking water and colander while the method passes the dough through a shared pasta machine controls the easy half of the risk and misses the hard half. Walk the method, list every piece of equipment the product touches, and write the control against each: dedicated equipment where available, otherwise clean and verify under the organisational allergen procedure, and **produce the allergen-free product before the standard product**. The same applies to a fryer, mixer, slicer or griddle.

**A special request never asks the learner to determine clinical safety.** "Adjust the dish so it is safe to chew and swallow" asks a cook under supervision to make a decision belonging to a health professional and a documented care plan. Write the scenario so the learner **follows a documented requirement supplied by the supervising chef** and is assessed on meeting it. Texture modification, allergen exclusion and therapeutic diets all take this shape. Nominate one specific outcome — "puree to the documented smooth texture standard supplied", not "dice or puree".

**Where a request needs a different formula, build it as its own recipe card.** "Replace the flour" is not a benchmark an assessor can mark against. Give it a card with quantities, method, test, tip and storage, and point the parent recipe's allocation at it.

**The observation criteria for the request are scenario-neutral.** Written once, they must work for every permitted scenario, so they never assume an ingredient substitution, an excluded food, or that the cookery method is unchanged:

- *Selected ingredients or approved modifications that met the documented customer request.*
- *Prepared and handled ingredients using the controls the request required, including prevention of cross-contact where an allergen or excluded food applied.*
- *Cooked the modified dish using the approved cookery method for the customer request or the modified recipe.*

Criteria naming a substitute ingredient, an excluded food, or "the cookery method the recipe requires" fail against a texture-modification or lower-fat request and must not be used.

**Where a case study is built (section 3) and sets a request against a numbered order, state how the order splits.** "Twelve portions, two guests are coeliac" is ambiguous. Say ten standard and two modified, require the quantities to be calculated separately, and require the separation controls to be recorded.

---

## 8. The assessor records — build these

> **Every one of these is a RECORD, not a question.** They carry no model answer, so each one carries an instruction saying who completes it, when, and what a complete entry looks like — `compliance-rules.md` section 7, *Every table is answered, or it says who fills it in*. The tables the learner answers are the opposite case: those are filled in the model colour, in the table itself.

**RTO decision, 21 August 2026: build all three, in the practical document's ASSESSOR GUIDE.** Not a separate evidence pack - the architecture is four documents, and the assessor guide is the assessor's book.

**They must never appear in the learner copy.** Printing an independent evidence record in the student's book invites the student to complete it. Render them behind the assessor switch and verify their absence from the learner document on every build.

**Why they exist.** Observation sheets are organised by **element**. Performance Evidence is organised by **requirement** — techniques, functions, food types, portions, occasions, customer requests. One sheet per element cannot show which dish demonstrated which requirement, on what date, or how many portions were plated. The product evidence matrix does not close it: the learner completes it, and it states what the dishes *could* demonstrate, not what the student *did*.

The three records, in order, after the observation sheets:

1. **Assessment conditions and assessor declaration** — one row per condition in the unit's Assessment Conditions, with an *available on the day* column and a notes column, then the declaration and signature row. **Reproduce the unit's equipment and organisational-specification lists; do not summarise them to "as required by the unit".**
   > The declaration exists because most SIT units impose assessor requirements beyond the Standards — a trade qualification and a stated number of years in industry — and an instrument that never asks the assessor to confirm them leaves that condition unevidenced.
2. **Dish production record** — one row per required product: dish, date, each portion the unit mandates as its own column, required-by time, actual finish time, assessor initials, S/NS. This is where portion count and commercial time constraints become auditable.
3. **Performance evidence completion matrix** — one row per PE requirement, **verbatim** from the unit: which dish demonstrated it, the date, assessor initials, S/NS. Completed by the assessor from the dish production record and the observation sheets.
   > **Every PE bullet, not only the lists.** It is easy to build this from the enumerated requirements — the techniques, the functions, the food types — and leave out the framing bullets that carry equal weight: mise en place and following standard recipes, the number of portions of each finished dish, working within commercial time constraints and deadlines, and applying portion control and food safety across the different food types. A matrix claiming to record *every* requirement while omitting four of them is a mapping defect. **Check the matrix row count against the unit's PE bullet count before delivery.**

> A **special customer request observation sheet** is a separate instrument, not one of these three. Where the unit mandates a customer request, it sits with the observation sheets and carries the scenario number, the dish, the request as documented, the modification made and the controls applied. Never instruct the learner to record a request "on the observation sheet" unless a sheet with that field exists.

Set these tables at 9 pt with row heights deep enough to write in. Report each row count in the compliance report and confirm every PE requirement has a row.

---

## 9. Content rules

- Ground food-safety references in current standards — FSANZ Food Standards Code, Safe Food Australia, temperature danger zone 5–60 °C, refrigerated holding 1–4 °C, allergen cross-contact controls — and in SA legislation per `sa-legislation.md`.
- Reflect the **exact** PE/KE of the named unit. Re-derive products, techniques and questions per unit.
- **Attribute a third-party recipe on the card itself**, in that recipe's competency focus box. It is not a front-matter courtesy that can be dropped when the front matter is trimmed — it is the condition on which the formula is used, and it belongs where the person cooking from it will see it. Report it and confirm the RTO is content to carry third-party content in a controlled assessment tool.
- Where recipes carry across from an existing workbook, reproduce the chef's ingredients and method faithfully. **Flag anything incomplete or internally inconsistent rather than silently correcting it.**
- Default to **vegetarian-friendly (egg permitted)** unless the unit or the user specifies otherwise.
- Plain, direct instructions; short sentences; define technical terms on first use.

### Choosing the dishes — cheap and simple, and still complete

**This runs BEFORE ingredient economy, and it matters more.** Economising on the ingredients of an expensive, complicated dish is fixing the wrong end. The dish set is chosen once, and it decides the cost and the difficulty of everything after it.

Three tests, in this order. A set must pass all three.

1. **Does it evidence the unit completely?** This is not negotiable and it is not traded against the other two. Every Performance Evidence item, technique and cookery method is carried, and a coverage check proves it. **The skill does not ship one** — write it in the build folder for the unit, listing the PE items, techniques and methods verbatim from training.gov.au and failing on any the dish set does not carry. Asserting coverage in prose is what this replaces. A cheaper set that drops a requirement is not cheaper, it is non-compliant.
2. **Is it within budget?** These are produced by students, often in multiples, and the RTO pays.
3. **Can a student at this AQF level actually cook it?** A Certificate III student works *"under the guidance of more senior chefs ... routine activities ... in known and stable contexts"*. Read the unit's own Application statement and build to it.

**How to make a set cheap without losing coverage:**

- **Load the requirements onto the cheap protein.** Where the unit names several food items, only one dish per item is mandatory. Everything else can sit on the cheapest one. Three chicken dishes and one duck dish costs a fraction of two chicken and two duck, and evidences exactly the same list.
- **Count the mandatory proteins and buy no more.** If the unit needs duck *once*, build **one** duck dish. A second duck dish carries nothing the first did not.
- **Take the cheap cut of the expensive bird.** Duck marylands cost a fraction of duck breasts and carry braising, stewing and marinating just as well.
- **Double up methods on one dish where the cooking genuinely does it** — sous vide then grilled, sautéed then stewed. Two methods, one protein, one purchase.
- **Put the offal and the trim to work.** They are the cheapest thing in the unit and they satisfy a mandatory item outright.

**How to keep it simple:**

- **Prefer the simplest technique that satisfies the requirement.** Where the Knowledge Evidence asks the learner to *know* something, questioning it is enough — it does not have to be cooked. A ballotine is a de-boned thigh, rolled and tied; a galantine is a whole bird de-boned through the back, farced, wrapped in muslin, poached, pressed overnight and glazed with aspic. If only one has to be produced, produce the ballotine and question the galantine.
- **Avoid a technique the unit never asks for.** Aspic, clarification, forcemeat with pork back fat, overnight pressing: if no PE item names it, it is difficulty the assessment did not ask you to buy.
- **Keep the method list per card to three to five steps.** A card that needs more is usually a dish above the level.
- **Watch the equipment.** A method requiring a piece of kit the Assessment Conditions do not list cannot be assessed at all.

**Report the set as a decision.** The compliance report names the six dishes, the estimated cost, what each carries, and — where a cheaper or simpler dish was rejected — which requirement it failed to carry. A set the chef cannot afford gets substituted at the bench, blind, and the coverage goes with it.

> **Never buy coverage twice.** Two dishes carrying the same item, technique and method is one dish of evidence and two dishes of cost. Run the coverage check and look at the single-point-of-failure list: anything carried by two or more dishes is a candidate for simplification.

### Ingredient economy

These recipes are produced by students in a training kitchen, often in multiples, and the cost lands on the RTO rather than a paying customer. Choose the lowest-cost ingredient that still evidences the requirement.

- **Never substitute an ingredient the Performance Evidence depends on.** If the unit names a food type, a farinaceous item or a state — dried, fresh, frozen — that ingredient is locked, whatever it costs. A dried mushroom costing more per kilo than the rest of the card stays, because nothing else in the set carries the dried vegetable.
- **Substitute the premium item that carries nothing** — a nut garnish, a named artisan cheese, a vanilla bean, a specialty flour, a premium cut where a secondary cut cooks the same way. Seeds for nuts, ricotta for a named soft cheese, extract for a bean, plain flour for 00, thigh for breast.
- **Watch the bulk liquids and the garnish cheeses.** Rarely the line a chef notices, and often the largest single cost on a scaled production run.
- **Cost substitution is a proposal, never a silent edit.** Make the change, then list every substitution in the compliance report as *was → now* so the chef signs it off or reverses it. Where it changes what the dish is called, say so and rename the card.
- **Sweep the knock-ons.** A substitution changes more than the ingredient row: the dish name, the competency focus, the evidence tags, the product evidence matrix, the special-request allocation, and any scenario prose naming the old ingredient. Removing nuts from a dish silently invalidates a nut-allergy scenario mapped to it.
- **State the reasoning against the requirement, not against taste.** "The souffle technique, the aerating and the glazing are unaffected" is the test. "It tastes similar" is not.
- Report the **PE-locked ingredients** too — the ones deliberately not substituted — so the chef can see the cost floor and why it exists.

---

## 10. Layout

Beyond the general rules in `template-build.md` and `house-style.md`:

**Fit each recipe card on one page where the content allows**, and each observation sheet on one page. Set the ingredients table to 9 pt before accepting a second page. Tighten the header, the numbered-step spacing and the table spacers before accepting a second page. Cards with multi-component methods will not fit, and that is acceptable — **cutting the chef's steps to make them fit is not.**

**A card that cannot hold one page starts its method on a new page.** Splitting mid-ingredient-list or mid-method leaves the learner turning back and forth between the quantities and the steps. Break at the natural seam: page one carries the banner, header, competency focus and ingredients; page two carries the method and the closing lines.

Apply it from a size test, not by hand, or the rule wastes a page on every card that already fits. Count the ingredient rows, add 1.6 per method step, add one per component heading, add the storage bullets. **Above about 34, break.** Report which cards broke and which held one page.

**Let the closing lines breathe.** Roughly 6 pt of space before `Test:`, before the `STORAGE AND PRESENTATION` heading and before `Presentation standard:`. A method running straight into its test line reads as one block and the learner loses the point where the cooking stops and the checking starts. Spend the space the 9 pt ingredients table frees, not the space between method steps.

**Size a scaling template to the longest recipe it has to hold.** Take the ingredient count of every recipe, take the largest, give the template that many rows. Raising the row count is the right lever; nominating a shorter dish or telling the learner to group by component both solve the layout by shrinking the task. A commercial cookery workbook typically peaks around twenty ingredient rows on a multi-component dish. **Do not leave the learner to discover the shortfall with a pen in their hand.**

**Capitals** are applied in the heading helper itself so they cannot drift as content changes — banners and section headings uppercase their own text at render. Field labels inside tables stay sentence case. The cover sheet is **exempt**: build its section titles with plain paragraphs so its verbatim wording, including `Please confirm:`, is never re-cased.

---

## 11. Report on the build

`compliance-rules.md` section 11 carries what every build reports. On this branch, add:

- The recipe-branch trigger decision and its reason
- The include-or-omit decision and justification for **each of the three written activity types** — section 3
- A coverage map: every mandatory requirement and the single place it is assessed
- Confirmation that no requirement is assessed twice, and which PCs are covered by both a written activity and an observation sheet under the precedence rule
- Recipe card count; theory question count with justification for each
- Observation sheet count and the element each sheet covers; observable action count; PC coverage count
- Every technique, function and food type against the recipe carrying it, naming any carried by only one recipe
- The three assessor records from section 8: condition count, dish production record rows, and PE completion matrix rows - and confirmation that none of them appears in the learner document
- **Any ingredient quantity supplied because the source recipe omitted it**
- **Cost substitutions** as a *was → now* list with the reason each is safe against the requirement, flagged for chef sign-off
- **PE-locked ingredients** and why
- Which cards held one page and which broke to two
- **The artwork counts from section 12.9** — images generated, cards without one, anything regenerated or failed, and the zero-hit prompt sweep

**Derive every count, never type one**, and **re-check every cross-reference when a section moves** — both in `house-style.md` section G. A pointer into the assessor guide names that document by title.

---

## 12. Photographs and the artwork pass

**The workbook ships with real photographs, not empty boxes.** A recipe card whose photo space is a dashed rectangle tells the learner nothing about what they are aiming at, and "what the finished product looks like" is the single most useful thing a recipe card carries.

This is the only section of the pack that generates artwork. The UAT and the assessor guide carry none.

### 12.1 The placeholder **is** the prompt

Every photo space is written into the document as a **prompt block** that the `docx-images` sub-skill reads, generates from, and then deletes. What ships contains no prompt text.

A block opens with `[IMAGE:` and closes with `]`. It may run to several paragraphs — the scanner keeps consuming until the bracket closes, up to twelve. `CAPTION:` and `ALT:` sit on their own lines inside the block:

```
[IMAGE: <the prompt body, one subject, one action>
CAPTION: <what the reader should take from the picture>
ALT: <what a reader who cannot see it needs>
ASPECT: square
]
```

`ASPECT` takes `landscape`, `portrait` or `square` and nothing else. It defaults to `landscape`, which is **wrong for a recipe card** — say `square` there explicitly.

> **Write the prompt, never a caption.** The old behaviour replaced `[ Insert photograph here ]` with a caption string and left the box empty. A caption is not artwork. `Build-Pack.ps1` now writes the cover prompt, and the recipe cards carry their own.

### 12.2 The two sites

| Site | Where it comes from | Cell width | Aspect |
|---|---|---|---|
| **Cover photo**, title page | The template prefix. `Build-Pack.ps1` writes it from `$Unit.CoverImagePrompt` | 9638 dxa, full width | `landscape` |
| **Recipe card photo**, one per card | **You author it**, inside the card's merged photo cell | 4338 dxa | `square` |

Exactly **one** photo per recipe card and **one** cover photo. A workbook with six recipe cards generates seven images.

> The two used to share the literal string `[ Insert photograph here ]`, and this file used to warn that a find-and-replace would hit the cover first. **That warning is retired.** Only the cover placeholder survives the seam — the template's sample card is discarded with the rest of the body — and each prompt now names its own subject, so there is nothing left to confuse.

### 12.3 Sizing is automatic, and it is cell-aware

`Set-DocxImages.ps1` sizes a picture against **the cell it sits in**, not the page column. This matters here more than anywhere: the recipe card photo cell is 4338 dxa inside a 9638 dxa column, so a picture sized to the column is two and a half times its cell and bursts the card open in Word.

**Do not try to control size from the prompt.** There is no width field, and asking for one in the prompt body produces a picture of a ruler.

### 12.4 Writing the prompt

`docx-images/references/prompt-rules.md` is the authority. The rules that bite hardest here:

- **No text anywhere in the frame.** No signage, no labels, no packaging copy, no menu boards. Asking produces mangled lettering that an auditor will read as a defect.
- **No faces.** Hands, forearms and torsos only.
- **No real brand, venue or person.**
- **State the compliance detail you want to see.** Gloves, sleeves down, hair covered, correct board colour, probe actually in the food. What you do not ask for, you do not reliably get — and a training photograph showing bare hands on ready-to-eat food is a food-safety defect on the page.
- **One subject, one action.** Three things happening at once reads as stock photography and teaches nothing.

**Never name the assessed term in a way the picture has to spell.** A prompt asking for "a *mise en place* station labelled by section" asks for lettering. Describe the arrangement instead.

### 12.4a NOBODY IS IDENTIFIABLE, AND NO COMPANY APPEARS - absolute

**This is not a style preference and it has no exceptions.** A generated photograph is placed in a document that is issued to students, held on file for the RTO's records, and handed to an auditor. Anything in it that identifies a real person or a real business is a privacy problem the RTO carries, not a picture that could have been framed better.

**Never generate, and never place, an image containing:**

- **A face.** Not in focus, not blurred, not in the background, not partially in frame, not reflected in a surface. **Frame to torso and hands.** A blurred face is still a face and a reflection is still a likeness.
- **Anything that identifies a person** - a name badge, a name on a jacket, a lanyard, a visible tattoo, a distinctive item of jewellery, a staff photograph on a wall.
- **Any real company or venue** - a logo, a brand mark, a uniform carrying a business name, branded packaging, a supplier label, a delivery box, signage, a menu, a shopfront, a vehicle.
- **Any real place that can be located** - a street sign, a building exterior, a view through a window that names or places the venue.
- **Any text at all.** It is the usual route by which a brand gets in, and generated lettering is malformed anyway.

**Write the exclusion into every prompt.** The model composes a face by default in any scene with a person; the constraint has to be stated or it will not hold. Use the same closing sentence every time:

> *No faces, no people identifiable, no logos, no brand marks, no signage, no packaging, no labels and no text anywhere in the frame. Framed to the torso and hands only.*

**Then LOOK at the returned image and check it.** The prompt reduces the risk; it does not remove it. An image that arrives with a face in the background is regenerated, never cropped and never blurred - a crop leaves the composition wrong and a blur is not anonymisation.

> **If two attempts still return a face, stop and report it.** Do not place the image. An empty photo space is recoverable; a student's likeness printed in an assessment tool and distributed to a cohort is not.

### 12.4b Food safety in the photograph - checked, not assumed

**A photograph in a food unit teaches. One showing a breach teaches the breach**, and it does it on the page where the document is telling the learner the opposite. This is a compliance defect, not a styling preference, and it is the single most likely thing to be wrong with a generated kitchen image - the model composes for looks, not for the Food Standards Code.

**Ask for the control in the prompt, then CHECK the returned image against this list. What you do not ask for, you do not get.**

| # | Check | The failure it catches |
|---|---|---|
| 1 | **Raw poultry sits on a dedicated cutting board, never directly on the bench** | The default composition. A generated "chef preparing chicken" puts the bird straight onto stainless nearly every time. |
| 2 | **The board colour matches the RTO's own board-colour procedure** | Colour coding is not universal - confirm it against the RTO's procedure and record it in the compliance report rather than assuming. |
| 3 | **Knives, shears and utensils are on the board or a clean tray, not lying bare beside raw poultry** | Cross-contamination through the utensil, which the picture then normalises. |
| 4 | **Hands are gloved wherever raw poultry is touched** | |
| 5 | **Sleeves down, no watch, no rings, no bracelets** | Jewellery is the one an auditor names first. |
| 6 | **Hair covered wherever a head is in frame** | Frame to torso and hands and the question does not arise. |
| 7 | **Raw and ready-to-eat never share a surface, and raw is never above ready-to-eat** | |
| 8 | **A probe, where shown, is in the thickest part and away from bone** | A picture of a probe touching bone teaches a false high reading. |
| 9 | **Nothing rests on the floor, and no cloth sits under raw product** | |
| 10 | **The bench is clean and uncluttered** - no unrelated food, no personal items | |

**Where the document is teaching the WRONG practice deliberately**, say so in the prompt - *"showing the incorrect practice of ..."* - and caption it as such. Otherwise every image is a compliant image.

**Record the audit.** The compliance report states that every image was checked against this list, and names anything corrected. An image that was regenerated for a food safety reason is worth reporting: it is the difference between a document that was checked and one that merely looks checked.

#### The cover photo

Landscape, and it carries the unit, not a single dish. Build it from the unit's own subject matter:

```
[IMAGE: A close three-quarter view of <the unit's characteristic action - tempering
couverture on a marble slab, portioning a bulk braise into gastronorms, finishing a
plated dessert>, on a stainless steel commercial kitchen bench under even neutral
daylight. <The one piece of equipment the unit turns on, named precisely - a digital
probe thermometer, a palette knife, a blast chiller shelf.> Gloved hands, sleeves
down, no jewellery, hair covered. Shallow depth of field with the work sharp and an
uncluttered commercial kitchen falling away softly behind. Warm neutral colour, no
heavy grading. No text, no signage, no packaging, no labels, no faces and no logos
anywhere in the frame.
ALT: <one or two sentences describing what is pictured, plainly>
ASPECT: landscape
]
```

#### The recipe card photo

Square, one portion, no hands. The learner is matching their plate against this:

```
[IMAGE: A single <product name> finished to service standard and photographed
<overhead | at a low three-quarter angle | at eye level>, on <a white ceramic plate |
a slate | a cooling rack | greaseproof on a stainless bench> under even neutral
daylight. <The finish that defines a correct result - a high gloss snap on the
couverture, an even crumb, a clean quenelle, sharp piped shell borders.> One portion
only, centred, filling most of the frame, with clean uncluttered space around it.
Natural food colour, no gloss spray, no styling props, no garnish the recipe does not
specify. No hands, no faces, no text, no signage, no packaging, no labels and no logos
anywhere in the frame.
CAPTION: <product name>
ALT: <what the finished product looks like, including the detail the method depends on>
ASPECT: square
]
```

**The photo must match the recipe card it sits on.** If the method pipes a shell border, the picture has a shell border. A photograph contradicting its own method is worse than no photograph, because the learner works to the picture.

### 12.5 Running the pass

It runs **after both gates and before delivery**, on the learner workbook. Ordering is not a preference:

- **After** `Test-HouseRules` and `Test-Readability`, because neither knows what a prompt block is and both would read one as body prose.
- **Before** `Invoke-RenderedSweeps`, because that sweep fails any unresolved `[...]` on the page — which is exactly the safety net that stops a prompt reaching an auditor. If artwork ran last, a missed prompt would ship.

```powershell
$s = "$env:USERPROFILE\.claude\skills\docx-images\scripts"
& "$s\Find-DocxImagePrompts.ps1" -Path .\out\WORKBOOK.docx -ManifestPath .\images\manifest.json
# read the manifest, fix any kind / caption / alt / span, then:
& "$s\New-DocImages.ps1"  -ManifestPath .\images\manifest.json -ImageDir .\images
& "$s\Set-DocxImages.ps1" -Path .\out\WORKBOOK.docx -ManifestPath .\images\manifest.json -OutPath .\out\WORKBOOK.docx
```

**Every entry here is an illustration.** A recipe workbook has no diagrams. If the scanner reports `needs-spec`, something has been mis-detected — check it rather than authoring a spec.

**Look at every image before placing it.** Read the PNG and check: no lettering, no faces, no logos, and nothing that contradicts the document — bare hands on ready-to-eat food, jewellery, uncovered hair. Two regenerations is the ceiling; past that, say so and leave the entry `failed` rather than placing a wrong picture.

### 12.5b The image cache is keyed on the PROMPT, never on the image id

Image ids are **positional** - `IMG-003` means *"the third prompt in the document"*. Change the dish set and `IMG-003` becomes a different dish while still pointing at the picture generated for the old one. A chicken ballotine card carrying a photograph of a galantine, with a valid manifest, an existing file, and every gate passing.

**Key the cache on a hash of the prompt text.** Neither skill ships this — build it in the unit's build folder, alongside the artwork step. Then a changed prompt misses the cache and is regenerated, and an unchanged one is never re-billed. **An image cannot outlive the prompt that produced it.**

It is also what makes 12.6 work without hand-mapping: the assessor guide resolves against the same cache and gets the learner's pictures automatically.

> **A stale `.prompt.txt` is the record, not the manifest.** The manifest is rewritten by every scan, so it holds the CURRENT prompts. When re-seeding a cache from images generated earlier, match against the `.prompt.txt` files written beside them - that is the record of what actually produced each picture.

### 12.5c Generate at the quality and size the page needs - never at the maximum and then shrink

**Asking for the biggest, best image and compressing it afterwards pays for detail nobody ever sees.** Quality is billed per image and rises steeply from `low` to `high`, so the setting is a cost decision, and it is decided by **where the picture lands on the page**, not by wanting a good one.

| Where it lands | Printed size | Quality |
|---|---|---|
| A recipe card photo, in the merged header cell | about 6 cm wide | **`low`** is usually enough; `medium` if the finish is what the learner judges |
| A cover photograph, full column | about 14 cm wide | **`medium`** |
| A close-up the learner must READ or judge in detail - a date code, a rotation label, a texture, a doneness cue | any | **`high`**, and only this case |

**Set it on the entry, in the prompt**, exactly like `ASPECT`:

```
[IMAGE: <the prompt body>
CAPTION: <...>
ALT: <...>
ASPECT: square
QUALITY: low
]
```

Omit it and the entry takes the file-wide default in `docx-images/config/defaults.json`. **Never raise the file-wide default "to be safe"** - that bills every image in the document for the one that needed it.

> **The failure this replaces.** Seven photographs were generated at `high`, then re-encoded down to display size afterwards. The re-encode fixed a 12 MB document that Word could not repaginate, but it did not recover the money: the detail was paid for and thrown away. Generating right-sized from the start does both jobs at once.

**Re-encoding is now a fallback, not the plan.** Ask for `jpeg` output at the generation step - the config already does - and only re-encode where an image arrives larger than the page needs. Photographs are JPEG; a logo stays PNG because it needs transparency.
### 12.6 The assessor guide reuses the learner's images

The assessor workbook mirrors the learner's recipe cards, so it carries the same photographs. **Generate once.**

Scan the assessor document for its own manifest, then point each entry's `imageFile` at the PNG already generated for the matching learner card and set its `status` to **`generated`**.
   > `generated` is the exact word `Set-DocxImages.ps1` tests for. `ready` looks right, reads right, and is silently rejected as an unfilled prompt. Then run `Set-DocxImages.ps1` only. Regenerating doubles the bill and returns *different pictures*, so the two documents would disagree about what the product looks like.

### 12.7 The cost gate

Illustrations cost money per image; nothing else here does. **Two levers, in this order:**

1. **Generate fewer.** Cache on the prompt (12.5b), so an unchanged dish is never re-billed and the assessor guide reuses the learner's pictures rather than generating its own.
2. **Generate cheaper.** Pick the quality from where the image lands (12.5c). A recipe card photo at `low` against `high` is roughly a quarter of the cost, and at 6 cm on the page nobody can tell.

**Count and tell the user before generating**, and **ask before more than about ten images**. Say what it will cost, not just how many.

**Never regenerate a whole document to fix one picture** - `-Only IMG-004` redoes one.

If no API key resolves, **stop and ask**. Do not build the workbook with empty boxes and do not write a key into any skill file.
### 12.8 When there is no key, or the user declines

Build the workbook with the prompts left in place, deliver it, and say plainly that the photo spaces carry prompts rather than pictures and that `Invoke-RenderedSweeps` will report each one as an unresolved placeholder. **That is the honest outcome**, and it is recoverable — the pass can be run later against the delivered document without rebuilding it.

Never delete a prompt to silence the sweep. An empty box that once had a prompt is unrecoverable.

### 12.9 Report on it

Section 11 also carries:

- **Images generated**, and the count of recipe cards without one — expect zero
- **Anything regenerated**, and what was wrong the first time
- **Anything left `failed`**, and why
- Confirmation that the assessor guide reuses the learner's images rather than its own
- Confirmation that a search of both delivered documents for `[IMAGE`, `[DIAGRAM`, `[ILLUSTRATION` and `PROMPT:` returns **zero hits**
