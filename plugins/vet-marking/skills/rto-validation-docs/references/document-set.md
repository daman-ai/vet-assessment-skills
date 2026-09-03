# The document set — current map

Read before numbering, branding or referencing anything. **Update this file when the set
changes**, otherwise the next session re-derives it and risks a different answer.

Last reconciled: 19 Aug 2026.

## Organisations

Three trading names, **two** registrations. This is the fact most likely to be got wrong,
because a trading name reads like a separate RTO and is not.

| Trading name | Legal entity | RTO | CRICOS | Register prefix |
|---|---|---|---|---|
| Adelaide Culinary Institute (ACI) | Bush Tukka Pty Ltd | 45797 | 03978F | `ACI-PAV` / `ACI-VAL` |
| Adelaide Construction Institute (ACnI) | Bush Tukka Pty Ltd | 45797 | 03978F | `ACNI-PAV` / `ACNI-VAL` |
| Meridian Vocational College (MVC) | Golden Wattle Group Pty Ltd | 45039 | 03551M | `MVC-PAV` / `MVC-VAL` |

ACI and ACnI **share one registration**. Verify any claim like this against a primary
source — the footer of a training and assessment strategy is a good one — rather than
inferring from the brand name.

**Retired prefixes:** `BT-` (Bush Tukka) and `GW-` (Golden Wattle). They named the legal
entities rather than the RTOs, and `BT-` had been applied to Meridian packs as well as
Adelaide ones. An auditor reading the register should see the RTO.

**Independence consequence:** ACI↔MVC and ACnI↔MVC are cross-RTO pairings. ACI↔ACnI is
**same-RTO** — it still satisfies Standard 1.5(f), since the test is whether the individual
designed, delivered or assessed *this product*, but it is weaker at audit. Prefer cross-RTO.

## Documents and Doc # allocation

| Doc # | Document | Ver | Notes |
|---|---|---|---|
| 4302 | Validation Form MASTER (Parts A/B/C) | 2.0 | Brand-neutral; brand set via document properties |
| 4303 | Continuous Improvement Register | — | **Live in Google Sheets.** The local .xlsx is an export — do not edit it |
| 4304 | Pre-Assessment Validation Master Prompt | 3.0 | Part B, Standard 1.3(b) |
| 4305 | Continuous Improvement Report | — | Generated from a register entry when a signed standalone record is needed |
| 4306 | Assessment Validation Plan | 2.0 | Sets the risk model and sample sizes |
| 4307 | Post-Assessment Validation Master Prompt | 1.0 | Part C, Standard 1.5 |
| 4308 | Validation Panel Roster | 1.0 | Blank; makes Part A per-cycle rather than per-unit |
| 4309 | Validation to Closure — the Fifteen Steps | 2.0 | Steps 1–8 pre-use, 9–14 improvement, 15 judgements |

A competing scheme (4455–4457) existed for MVC-only editions. The 4302 family won because
the three-brand Plan and Steps documents already cited it. If a document already carries a
number, keep it and number the new document around it.

## Settled rules that documents used to disagree on

- **No named individual in a master.** The responsible and authorising officer is a
  placeholder set at Step 0, not a baked-in name. The set spans two legal entities, so one
  name across all of it would assert an authority that may not hold. Confirmed 19 Aug 2026.

- **One register entry per unit, for each part.** Not a range, not a row per recommendation.
  Detail stays in the form at B.9–B.11 or C.6–C.8. A validation raising thirty
  recommendations still produces one entry.
- **Register prefixes follow the brand**, not the legal entity.
- **Part C closes Part B.** A Part C validation of the first cohort is normally the
  effectiveness evidence that closes the Part B register entry for that pack. The form's
  C.9 "Closes a Part B entry?" field is what satisfies Standard 1.5(g).

## Programme state

Numbers reconcile across three documents, which is a useful integrity check:

- **122 units** on the development priority list — ACI 34, MVC 88.
- **83 distinct assessment packs** to build and review; **39 linked entries** that close when
  their parent closes. 83 + 39 = 122.
- **60 of 122 units were already past their start date** at 19 Aug 2026 — ACI 20, MVC 40.
  These are the ones where a "review prior to use" is no longer literally possible and the
  interim position applies.

**ACnI:** its only product is MSF30322 Certificate III in Cabinet Making and Timber
Technology (~21 units, count taken from the TAS — confirm against scope). Confirmed not delivered by the user, 19 Aug 2026. It is **on scope
but not being delivered**, so delivery status and cohort vulnerability score 0 and it rates
**Medium**. Part B applies before any tool is issued; Part C cannot run until a first cohort
has been assessed.

## Known gaps

- A superseded ACI plan records that delivery of the CPC and MSF products "was notified as
  commenced on 22 October 2025", and shows MSF30322 as Superseded on a scope report. The
  user has confirmed MSF30322 is not being delivered, so the Plan stands; the notification
  and the transition position still need reconciling against PRISMS and the scope report.

- The Continuous Improvement Register has columns A–X including *RTO / Brand*, but **no
  column for Part (B or C)** and **none for parent pack**. Without them the register cannot
  express one-entry-per-unit-per-part, nor the 39 linked entries. Adding them is a change to
  the live Google Sheet — the user's call, not an edit to make locally.
- Retention of completed student assessments for the 60 already-started units is the only
  item that degrades with time. Once those records are gone, those judgements can never be
  validated.

## Known defects in the controlled templates

Found while completing a validation from them on 20 Aug 2026. Each is in the live template,
not in a generated record, so it recurs in everything built from it.

- **Validation Form MASTER (4302)** — the footer's brand prefix is the literal text
  `RTO-CMS`. Every other document in the set drives it from `BrandCode`. It should be a
  `DOCPROPERTY BrandCode` field, otherwise each generated record has to be text-patched.
- **Validation Form MASTER (4302)** — `RTOnumber` and `CRICOSnumber` hold the guidance
  string `<45797 for ACI and ACnI / 45039 for MVC>` rather than a placeholder token. The
  cached footer text holds it XML-escaped, so a `Update-DocxCachedText` map keyed on the
  literal `<...>` silently misses. Key on `&lt;...&gt;`.
- **MVC Continuous Improvement Report (4305)** — carries `cmsDocNumber` **4457**, from the
  retired 4455–4457 scheme, and its Register ref placeholder still reads `GW-PAV-nnn`. Its
  Section 2 also cites the validation report as "Doc # 5306", a number in no current scheme.
- **A superseded ACI completed validation form** in Downloads carries `cmsDocNumber` 4306,
  which is now the Assessment Validation Plan, and a `cmsDocName` naming the MASTER rather
  than itself. Left alone — it is an archived record, but do not use it as a template.

## Completed validations on file

| Unit | Brand | Part | Date | Outcome | Register ref |
|---|---|---|---|---|---|
| SITXHRM007 Coach others in job skills | MVC | B | 20 Aug 2026 | Not approved — 5 Critical | MVC-PAV-nnn (to allocate) |

SITXHRM007 delivery at MVC started **17 Aug 2026**, so the Part B review ran three days
after the cohort commenced. Recorded as such in the form; the interim position is at B.12.
