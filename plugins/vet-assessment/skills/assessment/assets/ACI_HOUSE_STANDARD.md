# ACI house standard — measured

**Measured 26 August 2026** from the RTO's own artefacts in `D:\BT Templates\`, per `references/house-standard.md`. Measured, not chosen. Another RTO gets its own file.

**Source artefacts:**

- `D:\BT Templates\ACI- Culinary\1.1 ACI_Culinary_Assessment_Template.docx`
- `D:\BT Templates\ACI- Construction\1 KE\ACI construction_Assessment_Template.docx`

---

## The RTO decision — 26 August 2026

**Everything is as MVC except the logo and the colours.** The logo and the colours differ between the two ACI trading names; nothing else does.

This supersedes the measured-template approach for everything except the record below. The measurements stay on this page because they document what the RTO's own artefacts contain — including nine defects — but **they are no longer what gets built**. ACI builds from MVC's approved templates and inherits MVC's structure, cover sheet, policy, day counts, typography, margins, table width, pagination and every house rule.

Three things are swapped in at build time, in this order, inside `Write-PackDocument`:

| Step | Function | What it does |
|---|---|---|
| 1 | `Set-BrandLogo` | Replaces `word/media/image1.png` and rewrites `wp:extent` and `a:ext` so the mark keeps its own aspect ratio. The two ACI marks differ — 3.53:1 culinary, 2.46:1 construction — so a fixed height would stretch one of them. |
| 2 | `Set-BrandPalette` | Role-based hex remap across `document.xml`, `numbering.xml`, `styles.xml` and every header and footer. 487 colour references on a demonstration build. |
| 3 | `Set-BrandIdentity` | Longest-match-first replacement of MVC's RTO identity — legal entity, trading name, acronym, website, email, student-ID label, RTO code, CRICOS code, tagline. Runs over `document.xml`, every header and footer, **and `docProps/app.xml` and `core.xml`**. |

**Step 3 exists because steps 1 and 2 are not enough.** With the logo and palette swapped and the identity left alone, the crossover sweep still returned six findings — `MVC` ×6, `Meridian Vocational` ×3, `Golden Wattle` ×2, `mvc.edu.au` ×2, `45039`, `03551M` — all surviving in the retained cover sheet and title page. A recoloured document still naming Meridian Vocational College is worse than one that never tried, because it looks branded and is not.

**All three swaps are skipped for MVC by construction**: they are gated behind `templates.swapLogo` and `templates.swapPalette`, which `branding.mvc.json` does not declare. An MVC build is byte-for-byte what it was.

### Contacts are shared across both trading names

**RTO decision, 26 August 2026: one email and one phone for all of ACI**, and the email is the culinary address `info@culinaryadelaide.sa.edu.au`. There is no `constructionadelaide` mailbox. What was logged as source defect 3 - the culinary address appearing on the construction template - is the intended value, not a leak.

The phone is `08 7001 6745` on both. The docProps `PhoneNumber` property says `0401741018`; the printed value is used and the question is settled.

Only the **trading name, tagline, website, logo and palette** differ between the two variants.

### A brand leak does not have to be visible

`docProps/app.xml` carries `<Company>`, and the template's value is MVC's legal entity. It prints nowhere on the page, and it shows in Word's File > Properties and in any document register built from metadata. An ACI pack whose properties say Meridian Vocational College still names the wrong RTO, so the identity swap covers docProps as well as the body and the footers.

Caught only because the crossover sweep was re-run part by part rather than over `document.xml` alone. **Sweep every part, or the sweep reports clean on the parts it chose to look at.**

**And a visible leak the text sweep is blind to: the logo itself.** 29 August 2026 - the UAT template draws the MVC mark three times (title page once, header twice); `Set-BrandLogo` stopped at the first image-bearing part, so every delivered knowledge document carried the MVC mark in its header while every text gate reported clean. The swap now covers every part that draws the mark, `Set-BrandIdentity` sweeps `.rels` hyperlink targets, and **`Assert-BrandLogo` is a blocking byte-level gate in every build**: header and footer images must BE the resolved variant's mark (culinary vs construction included), and no media part may match any other mark in `assets/logos`.
### The coupling this exposed

`Set-BrandIdentity` rewrites `Info@mvc.edu.au`, and that string was the **body-start anchor** — the marker both gates use to tell the RTO's approved front matter from authored body. Swapping the identity moved the anchor out from under the gates, which then policed the title page as if this skill had written it and failed a correct document on `FontFloor`.

Two fixes, both of which are the general lesson rather than the specific patch:

1. **`formatting.bodyStartsAfter` in `house-profile.aci.json` names the post-swap addresses first**, with MVC's retained as fallback.
2. **`Test-Readability` reads the anchors from the profile.** It had been carrying a private hardcoded copy of MVC's list while its own comment claimed it read the profile. A gate that keeps its own copy of a profile value is a gate that drifts.

### Verified

| Build | MVC colour hits | Crossover findings | House gate | Readability gate |
|---|---|---|---|---|
| MVC | 127 (unchanged) | 0 | Pass | Pass |
| ACI culinary | **0** | **0** | Pass | Pass |
| ACI construction | **0** | **0** | Pass | Pass |

MVC identity in **every** part - body, all six headers and footers, and docProps: **none on either ACI build**. All three packages pass `Test-DocxPackage`.

---
## One RTO, two trading names

**ACI is a single registered entity trading under two names.** This is the fact that shapes everything else.

| | Value | Source |
|---|---|---|
| Legal entity | **Bush Tukka Pty Ltd** | both cover sheets |
| RTO code | **45797** | both, and `docProps` `RTOnumber` |
| CRICOS code | **03978F** | both, and `docProps` `CRICOSnumber` |
| Acronym | **ACI**, for both | both cover sheets |
| Jurisdiction | South Australia | both |

**The RTO and CRICOS numbers carry their prefixes inside the property value** — `RTOnumber` is `"RTO 45797"`, not `45797`. MVC's are unprefixed and its footer text supplies the words. **Do not carry either convention across.**

### The two variants

The templates are **identical except for seven lines**. That is the whole of the difference, measured line by line.

| # | Culinary | Construction |
|---|---|---|
| Trading name | Adelaide Culinary Institute | Adelaide Construction Institute |
| Tagline | `LEARN. COOK. SUCCEED.` | `TRAIN. BUILD. SUCCEED.` |
| Website | *(unfilled placeholder — see defects)* | `www.constructionadelaide.sa.edu.au` |
| Address, as printed | Level 10, 50 Grenfell Street, Adelaide SA 5000 | Level 10 West, 50 Grenfell Street Adelaide 5000 |
| Legislation sentence | "Use the South Australian **food safety and hospitality laws, food standards** and authorities…" | "Use the South Australian **legislation, codes, standards** and authorities…" |
| Right margin | **991** dxa | **849** dxa |
| Practical branch | Recipe workbook exists | No recipe workbook |

Everything else — cover-sheet wording, policy clauses, palette, fonts, table width, line spacing, numbering, structure — is byte-identical.

---

## Measured formatting

| What | Culinary | Construction | MVC, for contrast |
|---|---|---|---|
| Margins L/R/T/B (dxa) | 1440 / **991** / 1440 / 1440 | 1440 / **849** / 1440 / 1440 | 1134 / 1134 / 1440 / 1440 |
| Text column | 9475 | 9617 | 9638 |
| Table width | **9026** | **9026** | 9638 |
| `docDefaults` run size | **21** (10.5 pt) | **21** (10.5 pt) | 22 (11 pt) |
| Line spacing seen | 240, **264**, **270** | 240, **264**, **270** | 216 (cover sheet only) |
| `sectPr` count | **1** | **1** | 3 |
| Numbering definitions | 3 | 3 | — |
| Results / late submission | **14 days** | **14 days** | 14 days |

**Tables fit their text column on both variants** — 9026 sits inside 9475 and 9617, so ACI has no equivalent of the table-overflow defect MVC carried.

### Palette

| Role | Value |
|---|---|
| Dark / navy | **2A364E** |
| Light fill | **F4F6F8** |

Sampled from the templates themselves, not from a logo. **This supersedes the coral/peach palette in the shipped `branding.aci.json`**, which was sampled from a logo file and does not appear anywhere in the approved artefacts.

### Document control

Both footers read through `DOCPROPERTY` fields in the culinary template. Properties measured:

| Property | Culinary | Construction |
|---|---|---|
| `cmsDocNumber` | 4223 | 4137 |
| `cmsRevision` | 1.0 | 1.4 |
| `cmsApprovedDate` | 30 Jun 2026 | 15 Jun 2026 |
| `cmsNextReviewDate` | 30 Jun 2028 | 15 Jun 2028 |
| `cmsApprovedBy` | RTOADM | RTOADM |
| `PhoneNumber` | 0401741018 | 0401741018 |
| `StreetAddress` | Level 10 WEST 50 Grenfell Street | Level 10 WEST 50 Grenfell Street |

**Review interval is 24 months** — approved date plus two years, on both. MVC's is 12.

---

## The seam — a code change, not a profile value

`Split-TemplateAtBody -Kind uat` **throws on both ACI templates**: it expects three `sectPr` blocks (cover sheet, title page, body) and finds one.

```
Expected 3 sectPr blocks in the UAT template, found 1.
```

`-Kind recipeWorkbook` seams both correctly, because it anchors on the first body heading and resumes at the final `sectPr`.

**So the seam is a property of the RTO's template, not of the document kind.** The assembler must take it from the branding profile (`templates.seam`) rather than inferring it from `-Kind`. Until it does, no ACI document can be built.

Both packages pass `Test-DocxPackage` — `Ok = True`, no errors.

---

## Source defects — reproduce, report, let the RTO decide

Per `references/house-standard.md`, these are preserved and flagged, not silently corrected.

**1. The construction template's `RTOName` property says "Adelaide Culinary Institute".** Any field or footer reading `RTOName` prints the wrong trading name on a construction document. This is a live brand-crossover defect inside the RTO's own artefact.

**2. The construction footer does not use `DOCPROPERTY` fields.** The culinary footer does. A typed footer drifts out of step with its own document properties within a revision — the exact failure MVC's house style records having suffered.

**3. ~~`AdminEmail` is `info@culinaryadelaide.sa.edu.au` in both templates.~~ NOT A DEFECT — RTO decision, 26 August 2026.** Both ACI trading names use the one email, and it is the culinary address. What looked like a culinary address leaking onto a construction document is the intended value. There is no `constructionadelaide` mailbox; do not derive one. The same applies to the phone: **one number, `08 7001 6745`, for both variants.**

**4. The culinary template's website is an unfilled placeholder** — `[insert Adelaide Culinary Institute website]` prints literally on the document.

**5. "Adelaide Construction institute" is lower-case on the construction cover sheet** (line 1) and correctly capitalised on the title block (line 37). Same document, two spellings.

**6. `cmsDocLocation` on the culinary template points into the construction tree** — `…\Adelaide Construction Institute\0 AI Prompts\Unit development\COOKERY AI Prompts\`.

**7. The culinary cover sheet address omits "WEST"** — it prints "Level 10, 50 Grenfell Street" where the document property says "Level 10 WEST 50 Grenfell Street".

**8. `docDefaults` is 21 half-points (10.5 pt), below the 11 pt accessibility floor** MVC adopted on 21 August 2026. Body text and table text both inherit it. **This is an RTO decision, not a defect to fix silently** — meeting the floor costs pages and moves every page break.

**9. Line spacing values 264 and 270 appear in the template front matter.** The `LineSpacing` blocking check admits 240 and 360 only. It is scoped to the generated body, so the template's own values do not fail a build — but no generated content may use them.
