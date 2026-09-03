---
name: rto-validation-docs
description: >
  Maintain and reconcile the controlled VET/RTO assessment-validation document set —
  validation forms (Parts A/B/C), master prompts, the Assessment Validation Plan,
  Validation-to-Closure steps, the Continuous Improvement Register and Report, and
  panel rosters. Use this whenever the user is working on RTO compliance documents:
  creating, versioning, rebranding, merging forked variants, fixing Doc # or register
  prefixes, adding a brand or RTO, reconciling contradictions between controlled
  documents, or preparing evidence for ASQA. Trigger on mentions of Standards for RTOs
  2025, Standard 1.3(b) or 1.5, validation Part A/B/C, pre-assessment or post-assessment
  validation, continuous improvement register, validation schedule, RTO/CRICOS numbers,
  Principles of Assessment, Rules of Evidence, or named brands like ACI, ACnI or MVC —
  even when the user only says "update this form" or "make this brand-neutral" without
  naming compliance. Also use it for any .docx edit inside this document set, because
  the editing mechanics on Windows here are specific and easy to get wrong.
---

# RTO validation document set

A controlled document set is not a pile of Word files. It is an **authority chain**, and
its most damaging defects are not typos — they are two controlled documents that
contradict each other. An auditor reads the set, finds the contradiction, and everything
downstream becomes suspect.

Your job is usually to keep that chain consistent while it grows across brands, versions
and obligations.

## Orient before editing

Read the actual files first. Never work from filenames or from a previous summary.

The authority chain, strongest first:

1. **The unit of competency and its Assessment Requirements** (training.gov.au). Where any
   document conflicts with the unit, the unit wins.
2. **Standards for RTOs 2025.** Note that 1.3(b) and 1.5 are *two separate obligations*:
   1.3(b) reviews the tool before issue and needs no students; 1.5 validates judgements
   already made and needs sampled student evidence. Neither substitutes for the other.
3. **The Assessment Validation Plan** — sets the risk model and sample sizes. Prompts and
   forms apply it; they do not set it.
4. **The validation form** — the record. Parts A, B and C.
5. **Master prompts** — the method for producing Part B and Part C content.
6. **The Continuous Improvement Register** — the master record of findings through to closure.

`references/document-set.md` holds the current map: which document is which Doc #, the
brand and RTO structure, and the register prefix scheme. Read it before assigning a
number or a prefix to anything.

## The five contradictions worth hunting

These recur. Check for them every time, because each one was found in a set that looked fine:

| Contradiction | How it shows |
|---|---|
| **Same document, two numbers** | Two Doc # schemes for one artefact. Check every document's `cmsDocNumber` for collisions and for a `cmsDocName` naming a different document. |
| **Same rule, two answers** | e.g. one document says "one register row per recommendation", another says "one entry per unit". Settle it in the *governing* document, then propagate. |
| **Entity vs brand identifiers** | Register prefixes named after legal entities rather than RTOs, applied across brands they don't belong to. |
| **Name/number mismatch** | A brand's name paired with another brand's RTO or CRICOS number. Check body text *and* document properties. |
| **Forked variants drifting** | Two brand editions of one form. Diff before assuming a merge — the "fork" is often a single string. |
| **A document contradicting itself** | The most easily missed. Check the *operative instruction* against the document's own rules and checklist — a prompt whose writing rules say "one entry per unit" while its Step 10 says "one row per recommendation" will be followed at Step 10, because that is the part the reader acts on. Grep every statement of a rule across the whole document, not just the section you edited. |

## Mandatory steps

**1. Diff before you merge.** When two variants exist, normalise and compare them before
rebuilding anything:

```bash
norm(){ unzip -p "$1" word/document.xml | perl -CS -pe 's/&#(\d+);/chr($1)/ge' \
  | sed -e 's|</w:p>|\n|g' -e 's/<[^>]*>//g' | sed 's/[[:space:]]\+/ /g' | grep -v '^ *$'; }
diff <(norm A.docx) <(norm B.docx)
```

Numeric character references vs literal UTF-8 will produce false differences — normalise
them first, or you will "merge" two identical documents.

**2. Verify organisational facts from primary evidence.** RTO and CRICOS numbers live in
document headers, footers and training and assessment strategies. A trading name does not
imply its own registration — several brands can share one. Getting this wrong propagates
into every document, so confirm it and record it in `references/document-set.md`.

**3. Preserve existing identifiers.** If a document already carries a Doc #, keep it and
renumber the *new* document instead. Renumbering something already in circulation creates
exactly the ambiguity you are trying to remove.

**4. Edit through the safest mechanism available.** See `references/docx-mechanics.md`.
Short version: this environment usually has **no python, pandoc or LibreOffice**, but does
have **Word via COM** and `unzip`. Use `scripts/docx-toolkit.ps1` rather than
re-deriving the technique.

**5. Run the quality gate below before delivering anything.**

## Content rules that constrain what you may write

These are not style preferences. Breaking them produces a document that is *worse than
useless at audit*, because it asserts something the RTO cannot support.

- **Never invent a person, credential, signature or independence declaration.** Panel
  identity is a fact about people. Output blank skeletons and say the panel completes them.
- **Do not pre-fill a real person into a master that serves more than one entity.** A
  responsible or authorising officer is per-entity, and a master carrying one name across two
  legal entities asserts an authority that may not exist. It also pre-empts the independence
  question the form asks at A.1. Make it a placeholder and set it at Step 0.
- **Never assert what a learner could or could not do.** In Part C you are reading a record,
  not the learner. The finding is that the record does not carry the evidence.
- **Never backdate a review.** If a cohort is already being assessed, a "review prior to use"
  cannot honestly be recorded as one. Record the real position and note it in the risk rationale.
- **Never mark a requirement Met from the tool's own mapping document.** Judge against the
  tool's actual content.
- **Do not put a learner's name in a report.** Use the student identifier from the record.
- **Nothing closes without both implementation evidence and effectiveness verification.**
  "Confirm the amendment was made" tests completion, not effect.

`references/validation-standards.md` carries the severity scales, sample-size rules and the
Part B / Part C division in full.

## Quality gate

Run all of these before you say a document is done. Most were added because something got
through without them.

**Structural**
- `unzip -t` reports no errors.
- The document opens in Word without a repair prompt.
- Word count is unchanged when the edit was not meant to change content.

**Layout** — templates in this set carry latent defects; check even when you did not touch layout:
- No heading stranded at the foot of a page. Heading styles here often lack `keepNext` —
  set it explicitly.
- No blank or near-blank page. Stacked empty spacer paragraphs after tables are the usual cause.
- No short table split across two pages.

**Content**
- Zero residual strings you meant to remove (old prefixes, `TBC`, superseded brand names).
  Grep `word/document.xml` *and* `docProps/custom.xml` *and* every header/footer part.
- Every `cmsDocName` matches its actual file.
- No Doc # collision across the set.
- Footer cached field text agrees with the document properties behind it.

A quick cross-set audit:

```bash
for F in *.docx; do
  n=$(unzip -p "$F" docProps/custom.xml 2>/dev/null | grep -o 'name="cmsDocNumber"><vt:lpwstr>[^<]*' | sed 's/.*>//')
  nm=$(unzip -p "$F" docProps/custom.xml 2>/dev/null | grep -o 'name="cmsDocName"><vt:lpwstr>[^<]*' | sed 's/.*>//')
  z=$(unzip -t "$F" >/dev/null 2>&1 && echo OK || echo BAD)
  printf "%-50s %-6s %-4s %s\n" "${F:0:49}" "$n" "$z" "$nm"
done
```

## How to report

The user is accountable for these documents at audit, so the report has to let them
distinguish what you changed from what was already broken.

Structure the response as:

```
## What changed
[the deliverable, and the substantive edits — not a list of every string]

## Defects found and fixed
[separate INHERITED (already in the live document) from INTRODUCED (yours)]

## Verification
[what you actually checked, and anything you could not check]

## What's left, and whose call it is
[open items, and which are the user's decision rather than yours]
```

Two habits that matter more than polish:

- **Label inherited defects as inherited.** "This is in the file you are using today" is
  actionable in a way that "fixed a blank page" is not.
- **Retract wrong conclusions plainly and immediately.** If a rating, a risk claim or a
  priority order turns out to be wrong, say so in one sentence, give the corrected version,
  and move on. Do not bury it.

## Examples

**Example 1 — merging a forked form**

Input: "ACI and MVC each have their own validation form. Merge them."

Correct move: diff first. If they are textually identical apart from a register prefix,
say so and do not rebuild either — take one as base, parameterise the brand through
document properties, and retire both entity prefixes. Report that the fork was one string.

**Example 2 — a rule that two documents answer differently**

Input: "Which is right — one register row per recommendation, or one per unit?"

Correct move: identify the governing document (here, the master prompt's writing rules),
settle it there, then propagate the wording into the Steps document and into the form's
front matter so the answer is visible where the work happens. Do not leave the loser
unedited.

**Example 3 — a product that is on scope but not delivered**

Input: "We're not delivering MSF30322."

Correct move: rescore it. Delivery status and cohort vulnerability drop to 0, which
typically moves the product down a rating band and changes the sample size. Part B still
applies before any tool is issued; Part C cannot run at all until a first cohort has been
assessed. Correct any earlier statement that called it high-risk.

## Bundled resources

- `scripts/docx-toolkit.ps1` — dot-sourceable PowerShell helpers: safe Word COM lifecycle,
  body find/replace, custom-property patching, cached field-text patching, and a
  table-capable body builder that reuses an existing document as its template so header,
  logo, footer fields and styles carry over.
- `references/docx-mechanics.md` — how to edit these documents without corrupting them, and
  the specific traps (Word COM crashes, range-expansion bugs, literal vs list bullets,
  cached field results). Read before your first edit in a session.
- `references/document-set.md` — the live map: documents, Doc #s, brands, RTOs, prefixes.
  Read before numbering or branding anything. Update it when the set changes.
- `references/validation-standards.md` — Standards 1.3(b) vs 1.5, risk model, sample sizes,
  severity scales, and the Part A/B/C division.
