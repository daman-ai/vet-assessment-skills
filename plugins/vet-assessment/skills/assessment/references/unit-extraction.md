# Extracting a unit from training.gov.au

## The site is a JavaScript application

`WebFetch` and `curl` return an **empty page**. This is confirmed, not suspected. Do not spend a turn retrying them.

Use a JavaScript-capable browser:
- the in-app Browser — `mcp__Claude_Browser__preview_start` then `get_page_text`, or
- Claude in Chrome — `mcp__claude-in-chrome__*`

## URLs

| Page | URL |
|---|---|
| Unit details **and** assessment requirements | `https://training.gov.au/training/details/{UNITCODE}/unitdetails` |
| Qualifications the unit is packaged into | `https://training.gov.au/training/details/{UNITCODE}/unitgridusage` |

Both the unit of competency and its assessment requirements render on the `unitdetails` page. There is no separate fetch for Performance Evidence.

## Procedure

1. Open the unit details page.
2. `get_page_text` to capture the whole record.
3. The page is long. Where the text is truncated, pull specific sections with JavaScript rather than re-fetching:

```javascript
(() => {
  const t = document.querySelector('main').innerText;
  const i = t.indexOf('Assessment conditions');
  return i < 0 ? 'NOT FOUND' : t.slice(i, i + 2000);
})()
```

Useful anchors: `Elements and performance criteria`, `Foundation skills`, `Assessment requirements`, `Performance evidence`, `Knowledge evidence`, `Assessment conditions`.

4. Open the qualifications page and read **every** qualification the unit is packaged into, with each one's AQF level. See the AQF gate below.
5. Re-load the unit page and diff against what you captured.

## The currency gate

At the top of the page, under the unit title:

```
Usage recommendation
Current
10/Jun/2022
```

**If *Usage recommendation* is anything other than `Current`, stop.** Report the actual status, the date, and the superseding unit named in the page's history. Do not build.

Common non-current values: `Superseded`, `Deleted`. A unit that is `Current` but whose *Release* is not the latest is also a problem — check the release list and build against the current release.

Continue past a non-current unit only on the user's explicit instruction, and record the override in the compliance report.

## The AQF gate

**The unit code and the brand are the inputs. The qualification MAY be named by the user, and is then VERIFIED, never trusted** — confirm it appears on the unit's own qualification list on training.gov.au before using it, and record it as *user-chosen* rather than *unambiguous* (`section-contract.md` `aqfSource`). Where the user names none, read it from training.gov.au. Where the unit spans more than one AQF level and the user named none, **stop and ask** — never infer a level from the unit code.

Read the qualifications tab and list every qualification the unit is packaged into, with its AQF level.

**Never infer the level from the code.** `CPCCBC4012` carries a `4` and sits in qualifications at more than one level. `SITHPAT018` runs in both SIT40721 Certificate IV in Patisserie and SIT30821 Certificate III in Commercial Cookery. The digit in a unit code is a training-package convention, not an AQF level.

Then:

| Situation | Do |
|---|---|
| Every qualification sits at **one** AQF level | Use it. Report the level and the qualifications it came from. |
| The qualifications span **more than one** AQF level | **Stop and ask the user which level to build for.** List each qualification, its code, its title and its level, so the choice is made on the facts. |
| The unit is packaged into **no** qualification | Stop and ask. A unit with no qualification has no reading level and no title-page qualification line. |

The answer sets three things downstream, so it cannot be guessed:

- the **cognitive demand** of every question and task — `compliance-rules.md`
- the **ACSF reading level** the whole document is written to — `house-style.md` section A
- the **qualification code and title printed on the UAT title page** — `template-build.md`

Where the level is chosen from several, **write to the lower one** if the tool is intended to serve both cohorts, and say so explicitly in the compliance report. Record the chosen level, the qualification it came from, and whether the user chose it or it was unambiguous.

> The recipe workbook prints **no** qualification and no AQF level, because a workbook travels between qualifications. The UAT prints both, because it is built per qualification. That divergence is deliberate — see `recipe-workbook.md` section 4.

## What to capture, verbatim

Every bullet and every sub-bullet. Sub-points nest several levels deep in Knowledge Evidence and dropping one is invisible for the rest of the build.

**Unit metadata**
- Unit code and title
- Usage recommendation and its date
- Release number and release date
- Application
- Pre-requisite unit
- Competency field
- Unit sector

**Unit of competency**
- Every Element, with its number and wording
- Every Performance Criterion under each Element, with its number
- Foundation Skills — the skill name **and** its full description. The description is what the mapping cites; the name alone is not enough

**Assessment requirements**
- Performance Evidence — the framing sentence and every bullet and sub-bullet, including counts ("on at least three occasions") and enumerated sets
- Knowledge Evidence — every bullet and sub-bullet at every nesting level
- Assessment Conditions — the environment statement verbatim, the complete list of fixtures, equipment, documents and resources, and the assessor requirements sentence

**From the qualifications tab**
- **Every** qualification the unit is packaged into — code, title and AQF level. Never infer the level from the code. See the AQF gate above

## Two things that are easy to lose

**The environment statement governs the alternative assessment.** Capture it word for word — for example "Skills must be demonstrated in an operational food preparation or service environment. This can be: an industry workplace; or an industry-realistic simulated environment." The alternative assessment section must keep the learner inside that environment.

**The resource list is a checklist, not prose.** Capture every category the unit names, including the ones that are easy to overlook: externally published regulatory documents, industry-association material, current organisational policies and procedures. What the tool then has to do with that list is `compliance-rules.md` section 8.

## Output

Write the extract to `[UNITCODE]_unit_extract.md` in the working directory, organised under the headings above, verbatim.

The Stage 6 clean-room reviewer does **not** read this file — it extracts its own copy so it can catch a transcription error. The build reads this file; the auditor needs to see what the build worked from.
