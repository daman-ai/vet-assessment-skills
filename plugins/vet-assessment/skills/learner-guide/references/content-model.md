# The content model — one spine, two renders

The guide and the deck teach the same unit from the same assessment. Authoring them separately is what makes them drift: the deck cites Q9 where the guide cites Q10, a tempering figure disagrees between a slide and a page, a Topic gains a sub-section in one and not the other.

So content is authored **once**, as JSON, and rendered twice. Neither renderer invents content. A fact that is wrong is wrong in one place.

---

## Shape

```jsonc
{
  "unit":     { "code": "SITHPAT018", "title": "Produce chocolate confectionery",
                "qualification": "SIT40721 Certificate IV in Patisserie",
                "release": "Release 1", "aqfLevel": "AQF Level 4" },

  "scenario": { "venue": "...", "employer": "...",
                "characters": [ { "name": "Chen Wei", "role": "Head Chef" } ],
                "locations": [ "Adelaide CBD", "Norwood" ] },

  "questions": [
    { "ref": "Q5", "focus": "Standard recipes as controlled documents",
      "ke": ["KE1"], "wordGuide": "80-120",
      "preparedBy": "1.1" }        // exactly one primary sub-section
  ],

  "topics": [
    {
      "number": 1,
      "title": "Select ingredients",
      "element": "1",
      "overview": "...",
      "outcomes": ["...", "..."],
      "keyTerms":  [ { "term": "Couverture", "plain": "...", "example": "..." } ],
      "readBeforeYouStart": "...",

      "subSections": [
        {
          "ref": "1.1",
          "pc": "1.1",
          "title": "Confirm food production requirements from standard recipes",
          "whatThisMeans":        ["para", "para"],
          "remember":             "one key point",
          "underpinningKnowledge":["para", "..."],   // >= 800 words, plain prose
          "regulatoryBasis":      ["para"],
          "howToDoIt":            [ { "step": "Read the yield", "detail": "..." } ],
          "workedExample":        { "lines": [], "bullets": [] },
          "caseStudy":            { "narrative": "...", "thinkItThrough": ["..."] },
          "practicalActivity":    { "youWillNeed": [], "scenario": "",
                                    "steps": [], "doneWell": [],
                                    "workedExampleTable": { "headers": [], "rows": [] } },
          "rolePlay":             null,
          "commonErrors":         [ { "error": "", "why": "", "consequence": "" } ],
          "selfCheck":            { "questions": [], "answerGuide": [] },
          "assessmentLink":       { "refs": ["Q5"], "wording": "Prepares you for: UAT 1 Q5" },

          "slides": [ /* see below */ ]
        }
      ],

      "summary": ["..."],
      "industryInsight": "...",
      "reflection": "...",
      "discussion": "...",
      "assessmentPrep": ["Explain ...", "Identify ..."],
      "furtherReading": ["..."]
    }
  ]
}
```

## The two renderers

| | Guide | Deck |
|---|---|---|
| Renderer | `Build-Guide.ps1` | `Pptx-Blocks.ps1` |
| Reads | every prose field | `slides[]`, plus figures and steps it reuses |
| Question reference | `assessmentLink` callout | the chip, **and** the speaker note |

**`assessmentLink.wording` is written once and used verbatim in both.** That is what makes the guide's Assessment Prompt and the slide's chip line up word for word, which is the whole point of the pairing.

---

## Slides live on the sub-section that teaches them

Each sub-section carries its own slides, so the ≥ 15-per-Topic floor is met by real teaching rather than by slides bolted on afterwards:

```jsonc
"slides": [
  { "layout": "single",  "kind": "teaching",
    "kicker": "1.1 CONFIRM PRODUCTION REQUIREMENTS",
    "headline": "The standard recipe is the recipe of record",
    "lead": "...", "bullets": ["...", "..."],
    "chip": "Prepares you for: UAT 1 Q5",
    "notes": "PC 1.1. <teaching point in plain English>. Direct learners to UAT 1 Q5 per the Assessment Activity Sequence Map." }
]
```

`kind` drives the deck gate: which slides must carry notes, which must carry a chip, and which count toward the Topic's 15. `layout` names an entry in `deck-layouts.mvc.json`.

---

## Rules the spine enforces before either renderer runs

1. **Every question has exactly one `preparedBy`.** More than one and the cross-reference table has no defensible answer to "where is this taught".
2. **Every `chip` and every `assessmentLink.refs` entry names a question that exists in `questions[]`.** Checked again at Stage 6 against the pack itself, because a spine can be internally consistent and still cite a question the paper does not have.
3. **Figures appear once.** A temperature, percentage, limit or count is written in the sub-section and *referenced* by the slide, never retyped. Retyping is how a slide and a page come to disagree.
4. **Terminology is fixed at the contract.** One word per concept throughout both artefacts — the same rule as upstream, and the same reason: synonym-switching is a comprehension barrier for EAL/D learners.
5. **Slides count toward their Topic.** Divider, outcomes, every PC content slide, case study, figures, process, assessment-link and recap all count. Title, agenda, assessment orientation, briefing, thank-you and brand reference sit outside the per-Topic count.
6. **Route B visual entries carry their `spec`.** The exact rows or nodes the native renderer builds live ON the visual entry, beside the prompt and alt text they must agree with:

   ```json
   { "slot": "2.1.4", "kind": "Diagram",
     "prompt": "A summary table titled ...",
     "caption": "...", "alt": "...",
     "spec": { "layout": "table", "headerRow": true, "rows": [["Step","Operation","Running quantity"], ["..."]] } }
   ```

   The build's spec-writer is a thin reader - spine to manifest, keyed by slot - and **refuses** any diagram whose slot has no spine spec. It authors nothing. One build held its specs as hand-typed copies inside the spec-writer; three remediation rounds edited the spine and the placed figures kept teaching the superseded content, because nothing that edited the spine could reach them.

   **The spine holds every figure's full content** - rows, nodes, items, caption, alt text, prompt and an explicit `kind` - and that is what makes a figure reviewable at the stage it is authored rather than at the stage a picture appears. A spec is content in exactly the sense body prose is, and it is gated at Stage 3c and adjudicated at Stage 3d, on the spine, by checks that never open a `.docx`. See `references/visuals.md` for the rules those checks enforce and for the build that shipped its figure defects to the third audit round because nobody could read a figure until it had been placed.
7. **Rule 3 is enforced, not hoped for.** The Stage 2 contract locks a **figure registry** - `figures.json` in the build directory: every working figure's canonical value and authority class (P pack, U unit, L cited law, V venue procedure), the stale forms it must never appear as, the assessor-only strings that must never reach a learner document, and the terms the deck must carry wherever the guide does. `Test-FigureConsistency` enforces it with variant-aware matching (digits and their word forms, hyphens and spaces) across the spine, the build scripts and the rendered text - because "fixed the prose, missed the diagram, missed the deck, missed the spelled-out variant" was the failure mode of three consecutive remediation rounds.

   **7a. Register the figure BEFORE you write it into the spine.** Registration is not paperwork done afterwards; it is the act that decides a figure may be taught. The registry is **seeded at Stage 2 from the corpus**, every entry carrying an authority class from the closed enum and a **provenance locator that resolves** - a named source document and a line or field the value actually occurs at - then reconciled and re-locked at Stage 3c against what was actually authored. An entry whose locator does not resolve in the named source fails; a figure written into the spine with no entry fails. A figure that cannot be registered is a figure that cannot be sourced, and the cheapest moment to discover that is before it has been written into two artefacts.

   **7b. The gate must fail on an UNREGISTERED figure, not merely on a stale registered one.** `figures.json`'s own header says a figure not in the registry is a figure nobody is checking - and the registry then implemented a whitelist of what IS checked, which is the exact inverse of a proof that nothing is unchecked. One build listed 31 registered figures against 112 placed captioned figures. So the sweep is inverted (`Assert-FigureCoverage`): harvest every number-with-unit token, in digits and in English word forms, and every named item of equipment, material or facility from the spine, and require each distinct candidate to carry **one of three dispositions** -

   - matched by a registry entry;
   - present verbatim in a canonical source, with the locator;
   - marked **DERIVED**, with its inputs named, where each named input must itself resolve.

   Any **undispositioned** candidate fails, and the gate emits the list as a located work order naming file and field. Note what this deliberately does not do: it does not fail on every unmatched value. A teaching resource is full of legitimately derived figures, and a gate that fired on all of them would be ignored within one build. `DERIVED, from these named inputs` is a first-class answer, and the disposition record IS the allow-list - versioned in the registry, with its reason, visible to the audit.

   **The failure this exists to prevent.** A raw batch weight was asserted **six times** across both artefacts, with a whole arithmetic chain derived from it, and it **passed every figure gate in the build** - because it had never been entered in the registry, and the gate only checks registered figures. Nothing was watching it at all. It was finally challenged at the third audit round as fabricated, and the round was spent either way.

   **7c. Never forbid a value the sources carry.** When that weight was at last arbitrated against the corpus it was found stated verbatim in a source document, in the recipe card's own field - the audit finding was wrong, and the remediation was performed on a false premise. The registry it left behind carries a `source` field asserting the opposite of what the card says, plus six forbid literals for a value the pack states, which will fail every future build that teaches that recipe correctly. So: **no forbid rule may be accepted whose literal occurs in any source document**, and every finding asserting a figure is fabricated, unsourced or misattributed is grepped against the corpus (`Assert-FindingProvenance`, Stage 6b) before it becomes a work order. That check can only ever require re-examination; it can never clear a finding. Judgement stages are indispensable and fallible in **both** directions - one round certified a figure it had invented a quotation for, the next condemned a figure the pack states - and the boundary between a finding and a work order is worth one grep.

8. **Every authored field must be READ by a renderer.** A field no renderer reads is not harmless extra metadata; it is a **content defect**, because everything authored into it is invisible. So is the mirror case: a container whose readable fields are all empty, which renders as a titled empty box - worse than no box, because it looks like the content is missing rather than never written.

   **The failure.** Five role-play boxes shipped empty or near-empty, three completely blank, and all three sat in the topic the guide itself calls safety-critical. Seven parallel authors wrote `situation` / `yourRole` / `otherRole` / `whatYouMustCover` / `phrases`; the renderer read `scenario` / `roles` / `steps` / `doneWell` and drew the box anyway. That content was authored, reviewed and gated, and never reached the page. A persona found it, not a gate - and the detector for it was written during the remediation it should have prevented.

   The rule has three parts, and the order matters:

   - **Compile the schema, never hand-write it.** Each renderer exports `Get-RendererContract`: the field names it reads per node type, which are required, and which must be non-empty for the node to render at all. Stage 0 compiles these into the spine schema and fails if two renderers declare different field sets for the same node type, if a container type declares no must-be-non-empty field, or if the compiled schema changed without a version bump. Detection parses property accesses rather than substring-matching, which once counted a field named in a comment as rendered, and it globs the renderers rather than naming them. Any hand-copied field array elsewhere is deleted: a second source of truth is free to drift, and this defect lived in exactly that drift.
   - **Refuse the write, in-loop, at Stage 3.** Agents author through a validating writer that **rejects** the write and hands the violation straight back for local fixing. This is scoped, deliberately, to violations that are exact and locally fixable: **UNREAD** (a field name no renderer reads), **MISSING** (a container with no non-empty readable field), a visual with no explicit `kind`, and an unresolvable figure or cross-reference token. Both UNREAD and MISSING must actually be implemented - an earlier detector declared a `missing` list and never added anything to it.
   - **Do not push fuzzy checks into the writer.** Mirrored answer grids, leakage shingles and bare numerals need whole-corpus context an agent cannot judge, and refusing a write over them sets parallel authors fighting the writer, which produces workarounds rather than fixes. Those run at Stage 3c where a reader adjudicates with the anchor in front of them.

   Deliberately unrendered metadata is legitimate, but it is **declared once in the contract with a written reason** - not left to look like a typo. Stage 4 additionally compares planned against rendered element counts, per type per sub-section, so content that vanishes between spine and page fails a gate instead of a persona.

---

## Why the spine is edited, never the documents

Stage 4b's readability agent and Stage 7's remediation both edit **the spine**, then re-render. Editing a built document instead means:

- the other artefact silently keeps the old wording;
- the next re-render overwrites the edit;
- and the change is invisible to the gates, which read the rendered file and would have to re-derive what changed.

**Re-render both artefacts even when only one had a finding.** They come from one spine, so a spine edit changes both.
