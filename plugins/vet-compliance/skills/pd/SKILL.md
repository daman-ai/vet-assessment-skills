---
name: pd
description: Build a complete, ready-to-run professional development session pack for VET trainers and assessors — facilitator guide, slide deck, activity worksheets, group allocation cards, completed model-answer copies, and an attendance and evaluation record. Use this skill whenever the user mentions a PD session, professional development, a trainer or assessor workshop, staff development, a validation or compliance training session, an RTO PD day, or asks for a facilitator guide, session plan, or workshop materials — even if they don't use the words "PD session". Also use it when the user asks for a topic suggestion for trainer development, since the topic and the pack are the same decision.
---

# VET PD session pack

Produces a session pack an RTO can run tomorrow: everything a facilitator carries into the room, everything a participant is handed, and the record that closes the loop back into the PD plan and the continuous improvement register.

The failure mode this skill exists to prevent is a beautiful deck with nothing behind it. A PD session that does not put a real artefact in participants' hands and send them out with a changed behaviour is a morning gone. Every pack this skill builds is anchored to a real assessment tool, with real defects in it.

## What a complete pack contains

| # | File | Format | Size | Audience |
|---|---|---|---|---|
| 1 | Facilitator Guide | .docx | 5–7 pp | Facilitator only |
| 2 | Slide deck | .pptx | 14–18 slides | Projected |
| 3 | Activity 1 worksheet | .docx | 2 pp | Per pair |
| 4 | Activity 2 worksheet | .docx | 2 pp | Per person |
| 5 | Attendance and evaluation record | .docx | 1 pp | Per person |
| 6 | Group allocation cards | .docx | 1 pp per group | Per group |
| 7 | Activity 1 — model answers | .docx | 2–3 pp | Facilitator only |
| 8 | Activity 2 — model answers | .docx | 2 pp | Facilitator only |

Files 6–8 are frequently asked for as a second round. Offer them rather than waiting to be asked — a facilitator who has to invent model answers in the room will avoid running the activity at all.

Read `references/deliverables.md` before building any of them. It specifies each file section by section.

## Settle these before you build

Do not start until you have all five. Guessing any one of them wastes the whole build.

1. **Topic.** Narrow enough for 90 minutes. "The 2025 Standards" is not a topic; "reviewing assessment tools prior to use" is. If the user asks for a suggestion, propose one topic with reasons and two alternates, then stop and let them choose.
2. **Brand.** A specific RTO, or generic and unbranded so it can be used across several. Unbranded is often right for a group with more than one RTO — say so, and note that headers, footers and document control get added later through their document management system.
3. **The worked tool.** A real unit and a real assessment pack, ideally one that has already been through a compliance review so the defects are known and defensible. This is the single most important input. A session built on a hypothetical tool teaches nothing.
4. **Audience.** Trainers and assessors is not the same audience as a validation panel or a management team. It changes what you cut. Governance, credential policy and self-assurance are not this audience's job.
5. **Duration.** 90 minutes is the default and works. Under 60 minutes, drop to one activity.

## Session architecture

The shape that works, and why:

| Time | Segment | Purpose |
|---|---|---|
| 0:00–0:05 | Open | Frame the problem with a question, not the Standards text |
| 0:05–0:20 | What changed | Orientation only. They do not need to recite anything |
| 0:20–0:40 | The yardstick | The criteria they will apply, taught as failure modes |
| 0:40–1:15 | Activity 1 | Apply the yardstick to the real tool, in pairs |
| 1:15–1:30 | Activity 2 | A shorter, sharper activity that exposes a second problem |
| 1:30–1:35 | Close and record | Three commitments, then collect the record |

Two activities, not one and not three. One activity leaves the second half of the session as a lecture. Three means none of them get finished.

Activity 2 should reveal something Activity 1 cannot. The strongest pattern: Activity 1 examines the artefact, Activity 2 exposes what happens to people who use a defective artefact — and the resolution loops back to Activity 1's method. That loop is what makes the session stick.

Keep the slide numbers in the facilitator guide's run sheet matched to the actual deck. Check this at the end; it drifts.

## Build order

Facilitator guide → Activity 1 → Activity 2 → deck → record → cards → model answers.

The facilitator guide first, always. It forces the content decisions. The deck is derived from it, never the reverse — a deck written first produces a session that is a slideshow with activities bolted on.

## Writing rules

**Teach failure modes, not definitions.** Every assessor in the room has heard the definition of validity. Almost none can say what a breach looks like on a page, which is the only thing they need for the activity. For every concept, give: what it requires, what a breach looks like, and one concrete instruction to carry out on the real tool.

**Ground every claim in the real pack.** "Consider whether the evidence is sufficient" is useless. "List every instrument the pack refers to by name; is each one actually in front of you?" produces a finding in four minutes.

**Write the facilitator guide as a person who has run the session.** Include what to anticipate: the question that always comes, the moment the room gets defensive, the thing not to spend time on. A guide that only lists content is a content list, not a facilitator guide.

**Write feedback text in the voice it would actually be written in.** Model answers that read like compliance prose teach the wrong register.

**Anticipate defensiveness.** Somebody in the room usually wrote or bought the tool being examined. Say plainly and early that finding defects is a normal result, not an indictment, and that reviews finding nothing are the ones that worry an auditor.

## Model answer copies

Build these as exact structural clones of the blank worksheets, with answers in red (`C00000`) and a red banner at the top: *COMPLETED MODEL COPY — FACILITATOR USE. Do not hand this to participants.*

Do this by copying the blank build script and patching it, not by writing a new one. Identical layout is the point — a facilitator reads the model copy and the participant's sheet side by side.

Where a worksheet has fixed-height answer boxes, set the height to a minimum (`10` twips) in the model version so rows size to the content instead of leaving gaps under short answers.

## Quality control — not optional

Render every file to PDF and look at every page and every slide. Layout defects in generated documents are invisible in the source and obvious on the page.

```bash
python3 /mnt/skills/public/docx/scripts/office/soffice.py --headless --convert-to pdf FILE.docx
pdftoppm -jpeg -r 90 FILE.pdf page
```

Then run the package validator on every file. LibreOffice renders leniently; Word does not.

```bash
python3 /mnt/skills/public/docx/scripts/office/validate.py FILE.docx
python3 /mnt/skills/public/pptx/scripts/office/validate.py FILE.pptx
```

Specific things to look for, all of which have shipped as real defects:

- A table column crushed to one word per line
- A block split across a page boundary that should hold
- A numbered list continuing from an earlier list instead of restarting at 1
- A near-empty final page
- A heading wrapping onto a second line and colliding with the subtitle below it

`references/build-conventions.md` explains the cause and the fix for each. Read it before writing build code, not after the render looks wrong.

## Reference files

- `references/deliverables.md` — section-by-section specification of all eight files
- `references/build-conventions.md` — palette, layout helpers, and the failure modes above with their fixes
- `references/srto-2025-content.md` — verified 2025 Standards facts, the principles and rules with breach examples, and claims to avoid making

## Assets

- `assets/docx-kit.js` — a tested Node `docx` style module: palette, headings, bullets, tables, callout panels, footers with page numbers, and numbering configuration with three independent numbered-list references. Copy it beside the build scripts and `require('./docx-kit')`. It assumes A4 portrait with 2.54 cm margins, giving a usable width of 9360 DXA.
