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
7. **Rule 3 is enforced, not hoped for.** The Stage 2 contract locks a **figure registry** - `figures.json` in the build directory: every working figure's canonical value and authority class (P pack, U unit, L cited law, V venue procedure), the stale forms it must never appear as, the assessor-only strings that must never reach a learner document, and the terms the deck must carry wherever the guide does. `Test-FigureConsistency` enforces it with variant-aware matching (digits and their word forms, hyphens and spaces) across the spine, the build scripts and the rendered text - because "fixed the prose, missed the diagram, missed the deck, missed the spelled-out variant" was the failure mode of three consecutive remediation rounds.

---

## Why the spine is edited, never the documents

Stage 4b's readability agent and Stage 7's remediation both edit **the spine**, then re-render. Editing a built document instead means:

- the other artefact silently keeps the old wording;
- the next re-render overwrites the edit;
- and the change is invisible to the gates, which read the rendered file and would have to re-derive what changed.

**Re-render both artefacts even when only one had a finding.** They come from one spine, so a spine edit changes both.
