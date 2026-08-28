# The Learner Guide

Structure, callouts, depth and the carve-outs from the shared house-style block.

Read the assessment skill's `references/house-style.md` and `references/readability.md` alongside this. **Part 1 of that block is universal and must not be forked** — everything that legitimately differs for this document type is in *Carve-outs* below, and nowhere else.

---

## 1. Document structure

The template's front matter is approved and is **kept**: cover lock-up, Acknowledgement of Country, Contents field, "How to use this guide", and the twelve-row icon legend. Authoring starts at the **`Unit overview`** heading.

Then, in order:

1. **Unit overview** — application, Elements and performance criteria
2. **Mapping matrix** — one row **per PC**: PC, criterion, topic, sub-section, KE, **Assess Q** including observation number
3. **Assessment activity sequence map**
4. **Assessment requirements** — Part 1 Knowledge with every KE item, Part 2 Performance with every PE item, "What the assessor is looking for"
5. **Introduction** — what this unit is about, why it matters, prerequisites
6. **Your workplace for this guide** — a standalone page: the venue, the project, the characters table, house policy, and a "carry this into every scenario" box
7. **Topics 1–N**, one per Element
8. **Assessment overview** — the Question Cross-Reference table (each question to its topic and word guide) and a pointer back to Assessment requirements. **No practice activities, research tasks or UAT 2 restatement here** — competency is assessed solely through the formal tools the trainer provides
9. **Appendices A–G** — state legislation, national framework, codes and standards, workplace templates index, glossary, further reading, practical activity index
10. **Mapping compliance declaration**

### Each Topic

Topic heading (`pageBreakBefore`) → Overview → Learning outcomes → **Key terms in this topic** → **Read before you start** → one sub-section per PC, each on a new page → Topic summary → Industry insight → Reflection → Discussion → Assessment preparation → My summary → Self-check answer guide → Further reading.

### Each PC sub-section

Heading `1.1 …` carries `pageBreakBefore`, then:

| Sub-part | Delivered as |
|---|---|
| i. What this means in practice | Heading4 + prose |
| — Remember | callout |
| i-b. **Underpinning knowledge — subject detail** | Heading4 + prose, **≥ 800 words** |
| ii. Regulatory basis | Heading4 + prose, state-specific |
| iii. How to do it | Heading4 + numbered steps, a sentence of explanation each |
| iv. Worked example | callout |
| v. Case study — workplace example | callout, at the scenario anchor |
| vi. Practical activity | callout |
| vii. Role play *(communication PCs)* | callout |
| viii. Common errors and consequences | callout |
| ix. Self-check questions | callout, starts a new page |
| x. Assessment link | callout, naming the exact questions |

**The four prose sub-parts get headings. Everything else is a self-titled callout and gets NO heading line above it** — the box's own bold icon-prefixed title *is* the heading. A duplicate heading repeats the title and strands an orphan page.

---

## 2. Callouts

A callout is a full-width single shaded cell with a **thick coloured left border only** — no top, bottom or right border — opening with the icon in its own run in **Noto Color Emoji**, then a bold coloured title, then the body. `GIconCallout` builds it; the map is in `assets/guide-profile.mvc.json`.

**`Noto Color Emoji`, registered in `word/fontTable.xml`.** Never `Segoe UI Emoji` — it is Windows-only and renders as empty tofu boxes anywhere else, including LibreOffice and macOS. `Register-IconFont` does the registration and is idempotent.

**Three neutral types — Note, Key terms, Further reading — carry the navy left rule but put icon *and* title in default body black**, exactly as the template's own library does.

Where two families share a colour — Topic summary, Case study and Worked example are all blue — **the icon and the title wording do the separation, never colour alone.** The body never shows a bracketed label word like `[PRACTISE]`; the icon carries that.

Palette, scope and the crossover carve-out: `gates.md` §9.

---

## 3. Depth

**3,000 words of counted body prose per Topic. 800 words per Underpinning knowledge block.** Both block. What counts and how it is measured: `gates.md` §3.

Reach the floor with genuine depth, never filler:

- *What this means in practice* runs 3–4 paragraphs — the criterion, the staff role, good versus poor practice.
- *Underpinning knowledge* is the deepest block in the sub-section. Give self-contained coverage of the real subject: plain-English definitions of every key term, **the underlying "why" — the mechanism, principle or reasoning, not just the rule** — worked detail, and state-specific specifics. Write it as **plain running prose with no bolded key terms**; explain each term in line, and follow an abstract concept with a worked example.
- *Regulatory basis* explains what the instrument requires **and how it applies on the job**.
- *Common errors* explains the error, **why it happens**, and the consequence.

The assessor guide's model answers are the best available guide to required depth. Teaching that stops short of them sets the learner up to under-answer.

---

## 4. Written for EAL/D learners

The cohort is international students under CRICOS. This is a requirement, not a preference.

- Plain English at the **ACSF level of the qualification**, per the shared block's reading-level table. Where a unit is delivered across two qualifications at different levels, write to the **lower**.
- **Sentences of 25 words or fewer.** One idea per sentence. Active voice, second person, present tense.
- **Expand every acronym at first use in each topic** before using the short form, and list it in the glossary.
- **Avoid idiom and slang** unless it is a genuine industry term the learner must know — and when an unavoidable Australian workplace term appears ("front of house", "mise en place", "86 an item"), gloss it at first use and add it to the glossary.
- **One word per concept.** Do not alternate guest / customer / patron / diner for one role, or clean / sanitise / wash where they mean different things.
- **Assume no prior Australian workplace, cultural or regulatory knowledge.** Explain the regulators' roles where they bear on a PC.
- Name characters by **role** at every appearance — "Sofia Rossi, Head Chef" — so the learner is never tracking an unexplained name.
- Give the full descriptive name plus the on-the-job name: "a probe thermometer (also called a temperature probe)".
- The consolidated glossary collects **every** Key-terms entry from every topic, alphabetised, so it works as a standalone reference.

---

## 5. Worked examples, sign-off and white space

**No blank "your turn" print-ready templates.** A practical activity shows a **completed** worked example and nothing more, then points the learner at the real document — *"Complete this on the hazard report form supplied in your assessment tool."* Three reasons: the real form is the RTO's and a parallel copy drifts out of step with the tool it shadows; empty rows consume a third to a half of every activity page; and the filled example is what carries the teaching.

**Sign-off is a bordered three-column table** — Learner signature | Supervisor / trainer signature | Date — with a shaded navy-titled header row and one writable row of ≈ 520 DXA. Columns sum exactly to CW. Never a run of underscores: they do not align, they break differently at every zoom, and they do not read as a form field.

**Keep example tables tight** — 420–500 DXA for a single-line entry. An over-tall row pushes the example to a second page and strands the sign-off block alone.

A Contents page that is empty until the field is updated is expected, not a defect — but `Update-Fields` at Stage 8 is what stops it shipping that way.

---

## 6. Carve-outs from the shared block

The only permitted differences for this document type.

| Item | Learner Guide |
|---|---|
| Build method | Edit the approved template: unpack → edit XML as text → repack. Same as upstream. **Not** the docx-js/Node build the old spec describes — there is no Node on this machine, and the template is the authority anyway |
| Content width | **9617 DXA**, derived from the page's own margins — see `gates.md` §1 |
| Length guide | 3,000 words of counted body prose per Topic; 800 per Underpinning knowledge block |
| Page-break rule applies to | Each Topic chapter **and** each PC sub-section |
| Response spaces | Not applicable — a guide has no answer spaces, other than the My summary box |
| Benchmark / assessor devices | Not applicable — this is a learner-only document. No model answers, no benchmarks, no amber assessor notices |
| Extended chunking | Additionally split any body paragraph over ~90 words into 2–3-sentence paragraphs, losslessly |
| Callout / box titles | **Icon-prefixed** — the twelve-icon set in `Noto Color Emoji`, icon in its own run ahead of the bold coloured title. The icon never carries meaning alone; it always sits with the written title |
| Document control | **Forbidden in the body.** Applied later in novacore.cloud — see `gates.md` §6 |

Everything not in this table is identical to the shared block. If a rule needs to change for this type only, add a row here — do not fork Part 1.
