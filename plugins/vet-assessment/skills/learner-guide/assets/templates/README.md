# Templates

The RTO's approved brand sources. **Build by editing these** — never generate a Learner Guide or a deck from scratch.

| File | What it is |
|---|---|
| `MVC_Learner_Guide_Template.docx` | The Learner Guide brand source. **Geometry-patched** — see below |
| `MVC_Learner_Guide_Template.premargin.docx` | The pristine shipped template, kept for reference. Do not build from it |
| `MVC_Branded_PPT_Template.pptx` | The deck brand source: a 13-slide layout library |

Both were supplied by the RTO on 14 August 2026 and copied in unmodified, apart from the one geometry patch recorded below.

---

## The Learner Guide template

A skeleton, not a document: cover lock-up, Acknowledgement of Country, Contents field, "How to use this guide" with the **twelve-row icon legend**, a Topic 1 block to duplicate, a **ten-shell callout box library**, and appendix stubs.

Everything from the `Unit overview` heading onward is **scaffolding** — there to be copied from, not shipped. `Split-GuideTemplate` keeps the front matter and drops the rest.

**The seam is `Unit overview` as a Heading1 outside the contents control.** The anchor text occurs twice: once in the table-of-contents field, which sits inside the contents `<w:sdt>`, and once as the real heading. Cutting at the first match slices that control open and Word refuses the file. `Split-GuideTemplate` skips any match whose enclosing paragraph is not a Heading1 or that sits inside an unclosed `<w:sdt>`.

### Geometry patch — applied

| | Page | Left | Right | CW |
|---|---|---|---|---|
| As shipped | 11906 | 1440 | **1440** | 9026 |
| Patched | 11906 | 1440 | **849** | **9617** |

The Study Guide spec and every one of the 361 full-width tables in the delivered `SITHPAT018-Learner Resource.docx` use 9617; the template's own margin gave 9026. `11906 - 1440 - 849 = 9617` exactly, so the spec's arithmetic is deliberate and the margin was the outlier — which is why the delivered guide's tables overhang its right margin by 591 DXA.

Re-apply after any template refresh:

```powershell
& "$SkillDir\scripts\Patch-GuideTemplateGeometry.ps1"
```

Idempotent; reports when there is nothing to do. Full evidence in `references/gates.md` §1.

---

## The deck template

Thirteen exemplar slides, one master, one layout, and the MVC logo at `ppt/media/image1.png`. The build clones an exemplar and swaps its text, so master, theme, fonts, logo and footer are inherited rather than re-created.

**Two things about it drive real rules:**

- **The footer slide number is literal text, not a `slidenum` field.** A cloned slide keeps the exemplar's number unless it is rewritten. The delivered deck prints the wrong number on 19 of its 39 slides. `Set-DeckSlideNumbers` fixes it; `Test-DeckRules` checks it.
- **Shapes are named generically** — "Text 1", "Text 5" — so names carry no meaning. The slot map in `../deck-layouts.mvc.json` is the only place an ordinal is recorded.

### Re-measuring after a template change

Both profiles hold measurements, not guesses. If the RTO reissues either template, re-measure rather than assuming:

```powershell
. "$SkillDir\scripts\Lib-Resolve.ps1"

# deck: text-shape ordinals per layout
$wd = Expand-Docx -Path "$SkillDir\assets\templates\MVC_Branded_PPT_Template.pptx"
foreach ($p in (Get-DeckSlideOrder -WorkDir $wd)) {
    "--- $p"
    Get-SlideShape -SlideXml (Get-DocxPart -WorkDir $wd -Part "ppt/slides/$p") |
        Where-Object { $_.TextIndex -gt 0 } |
        ForEach-Object { "  [{0,2}] {1}" -f $_.TextIndex, ($_.Text -join ' / ') }
}

# guide: geometry and heading colours
$wd = Expand-Docx -Path "$SkillDir\assets\templates\MVC_Learner_Guide_Template.docx"
[regex]::Match((Get-DocxPart -WorkDir $wd -Part 'word/document.xml'), '<w:pgMar\b[^>]*/>').Value
```

Then update `deck-layouts.mvc.json` or `guide-profile.mvc.json`. Nothing else should hold an ordinal, a colour or a width.
