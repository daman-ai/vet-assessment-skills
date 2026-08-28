# Prompt rules

Read this when a prompt has to be written from scratch, or repaired after the
model refused it or returned the wrong thing.

The document's own prompt is the subject. The house rules in
`config/defaults.json` are wrapped around it automatically at generation time —
do not paste them into the prompt yourself, or they go in twice.

---

## Illustrations

Clean instructional photography for a vocational training document.

**What makes one work**

- **One subject, one action.** "A chef probing the core of a delivered chicken tray" beats "a busy receiving dock". Crowded frames read as stock photography and teach nothing.
- **Name the surface and the setting.** Stainless bench, coolroom shelf, pass. It anchors the scene in a commercial kitchen rather than a domestic one.
- **Name the equipment precisely.** "Digital probe thermometer", not "thermometer". "Blue chopping board", not "board", where the colour carries meaning.
- **Describe the camera when it matters.** Overhead for a bench layout, close three-quarter for a hand action, eye level for a full station.
- **State the compliance detail you want visible.** Gloves, hair covered, sleeves down, board colour, the probe actually in the food. What you do not ask for, you do not reliably get.

**What breaks one**

- Asking for text. Signs, labels, whiteboards, packaging copy — the constraints forbid all of it, and asking anyway produces mangled lettering.
- Asking for a face. Hands, forearms and torsos only.
- Naming a real brand, a real venue, or a real person.
- More than about three things happening at once.
- Anything a food-safety auditor would fail: bare hands on ready-to-eat food, jewellery, a probe left in a pocket. If the document is *about* the failure, say so explicitly — "showing the incorrect practice of ..." — or you get a clean kitchen instead.

**NOBODY IS IDENTIFIABLE AND NO COMPANY APPEARS. This is absolute.** These images are placed in documents that are issued, filed and audited, so anything identifying a real person or business is a privacy problem the caller carries.

- **No face** - not blurred, not in the background, not partly in frame, not reflected. Frame to **torso and hands**.
- **Nothing that identifies a person** - name badge, name on a jacket, lanyard, distinctive tattoo or jewellery.
- **No real company or venue** - logo, brand mark, branded uniform, packaging, supplier label, signage, menu, shopfront, vehicle.
- **No locatable place** - street sign, building exterior, a view through a window that places the venue.
- **No text at all**, which is the usual way a brand gets in.

Close every prompt with the same sentence so the constraint cannot be forgotten:

> *No faces, no people identifiable, no logos, no brand marks, no signage, no packaging, no labels and no text anywhere in the frame. Framed to the torso and hands only.*

Then **look at the result**. A face that arrives anyway means REGENERATE - never crop, never blur. Two failures and you stop and report it rather than place it.

**Food photography carries a compliance burden that other subjects do not.** In a food-safety-assessed document the picture is teaching, so it must survive the same audit the text would. Name the control in the prompt or the model will not compose it:

- **Raw meat, poultry or seafood goes on a dedicated cutting board, never straight onto the bench.** This is the default failure - ask for the board explicitly, every time.
- **Utensils rest on the board or a clean tray**, not bare on the surface beside raw product.
- **Gloves on for raw protein. Sleeves down, no watch, no rings.** Frame to torso and hands so hair covering never becomes a question.
- **Raw and ready-to-eat never share a surface**, and raw is never shown above ready-to-eat.
- **A probe goes in the thickest part, away from bone.**

Then LOOK at what came back and check it against the same list. A composition that reads well and breaches the code is the normal output, not the exception.

**Repairing one.** Refused: strip anything that reads as a real person or brand, and any wording about injury, blood or contamination. Wrong subject: move the subject to the first sentence and cut the scene-setting. Text crept in: name the offending element and say it carries no label.

---

## Diagrams

**Diagrams are not prompted and not generated.** They are built as native Word
objects — real shapes on a drawing canvas, or a real table — from a spec you
author. See `diagram-specs.md`.

The diagram prompt in the document is still the author's instruction: read it,
and turn it into a spec that says the same thing. In particular, lift the
labels out of it **verbatim**. A prompt that says "label the three bands Cold 5
and below, Danger zone 5 to 60, Hot 60 and above" is telling you the exact text
of three node labels, and none of those words are yours to reword.

Why this is better than generating one:

- Labels are typed, not drawn, so they cannot be misspelled or garbled.
- Every box stays clickable and every word stays editable in Word.
- The text is searchable, and a screen reader reads it.
- It costs nothing, so a wrong diagram is fixed in seconds rather than regenerated.

---

## Quality is part of the prompt, and it is a cost decision

`QUALITY: low | medium | high` sits in the prompt block beside `ASPECT`. Choose it from **where the picture lands on the page**, not from wanting a good picture:

- **`low`** - a thumbnail-scale image, a photo in a table cell, anything under about 8 cm wide.
- **`medium`** - the working default. A full-column figure.
- **`high`** - only where fine detail carries the teaching: a label the learner must read, a texture or doneness cue they must judge.

Generating at `high` and compressing afterwards pays for detail that is discarded before anyone sees it. Ask for what the page needs, once.

## Captions and alt text

Both are required on every placed image, and both are the writer's job, not the model's.

- **Caption** — what the reader should take from the picture, not what the picture contains. "Probing a delivery on receipt" rather than "A chef with a thermometer". Sentence case, no full stop, no figure number: the number is added when the image is placed.
- **Alt text** — what a reader who cannot see the image needs in order to follow the page. Describe the content plainly and include any detail the surrounding text depends on. One sentence, up to about two. Never "image of" or "photo showing".

For a diagram, the alt text must carry every label and the relationship between them, because the labels are the content. "A horizontal bar in three bands: cold at 5 degrees and below, the danger zone from 5 to 60 degrees, and hot at 60 degrees and above."
