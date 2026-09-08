# VET Assessment Skills

Claude Code skills that build **audit-compliant Australian VET assessment packs** matched to the RTO's own approved templates — for **Meridian Vocational College (MVC)** and **Adelaide Culinary Institute / Adelaide Construction Institute (ACI)**.

One command in Claude Code:

```
/assessment SITHCCC036 "SIT30821 Certificate III in Commercial Cookery" ACI
```

produces paired learner and assessor Word documents (a knowledge tool plus a recipe workbook with generated photography on food units; one combined UAT otherwise), red point-form model answers and benchmarks, and a compliance report — sourced live from training.gov.au, gated by blocking house-rules / readability / brand-logo checks, reviewed by three adversarial personas and an independent clean-room compliance audit.

> **Made public by the RTO's decision.** The approved assessment templates, logos, branding profiles and house standards in this repository remain the property of Meridian Vocational College and Bush Tukka Pty Ltd (T/A Adelaide Culinary Institute / Adelaide Construction Institute). You are welcome to study and reuse the **engine** (scripts, gates, references); do not present the RTOs' documents, marks or identities as your own. To use the pipeline for a different RTO, measure that RTO's own artefacts and add its `assets/` profile — see `references/house-standard.md`.

> **API keys are never in this repository.** The artwork stage reads *your* OpenAI key from `$env:OPENAI_API_KEY` or `%USERPROFILE%\.openai-key` on your machine. `install.ps1 -OpenAIKey "sk-..."` stores it locally in one step. Never commit a key anywhere; the `.gitignore` blocks key files as a backstop.

## Requirements

| Requirement | Why |
|---|---|
| Windows 10/11 with **Microsoft Word** installed | Delivery updates fields, counts pages and exports PDFs through Word COM |
| Windows PowerShell 5.1 (ships with Windows) | All build scripts target 5.1 |
| **Claude Code** with a JavaScript-capable browser tool | training.gov.au is a JS application; plain fetches return an empty page |
| An **OpenAI API key** (only for recipe photography) | `$env:OPENAI_API_KEY`, or a file at `%USERPROFILE%\.openai-key` |

Avoid running builds inside a OneDrive-synced folder where possible — Word silently re-maps synced paths to SharePoint URLs and refuses to save; the skill works around this, but local folders are simpler.

## Install — option A: Claude Code plugin (recommended)

In Claude Code:

```
/plugin marketplace add daman-ai/vet-assessment-skills
/plugin install vet-assessment@vet-skills
/plugin install vet-marking@vet-skills
/plugin install vet-compliance@vet-skills
/plugin install vet-tas@vet-skills
```

**Zero-command for a whole team:** commit this to a shared project's `.claude/settings.json` and everyone who opens that project gets the plugin automatically:

```json
{
  "extraKnownMarketplaces": {
    "vet-skills": { "source": { "source": "github", "repo": "daman-ai/vet-assessment-skills" } }
  },
  "enabledPlugins": { "vet-assessment@vet-skills": true, "vet-marking@vet-skills": true, "vet-compliance@vet-skills": true, "vet-tas@vet-skills": true }
}
```

## Install — option B: plain clone

```powershell
git clone https://github.com/daman-ai/vet-assessment-skills "$env:USERPROFILE\vet-assessment-skills"; & "$env:USERPROFILE\vet-assessment-skills\install.ps1"
```

Update later:

```powershell
& "$env:USERPROFILE\vet-assessment-skills\install.ps1" -Update
```

## Usage

```
/assessment <UNITCODE> <QUALIFICATION> <MVC|ACI>
```

- The **unit code** and **brand** are required; the qualification is optional (verified either way against the unit's own qualification list on training.gov.au).
- **ACI** resolves its trading name from the unit's training package, enforced in code: `SIT` → Adelaide Culinary Institute, `CPC` → Adelaide Construction Institute; an ambiguous package (e.g. `BSB`) refuses to guess and asks.
- The brand mark is **byte-verified in every header of every document** at build *and* delivery time — a wrong or missing logo fails the build, it cannot ship silently.

Mark a batch of submitted student assessments with:

```
/marking <UNITCODE>
```

The marking skill reads the WiseNet 0217 Unit Enrolment Outcome Matrix **by cell colour** to work out who was actually enrolled and is required to submit. It reads the unit's prerequisites from training.gov.au and withholds the result as **RW** where the matrix does not positively show the student holding them. Every student is handed their feedback, not only those assessed NYC. A 0217 export carries **one worksheet per course offer**, and where the RTO files by group rather than by marking day, several runs consolidate into one record per group and a handover package - one folder per group, one per student inside it. Real roll exports carry student names and IDs - they are gitignored, never commit one.

After a pack is delivered, build its teaching resources with:

```
/learner-guide <UNITCODE>
```

Assess the RTO itself against the 2025 Standards and the ESOS framework, and design the system that keeps it compliant:

```
/auditor
```

Build a professional development session pack for trainers and assessors:

```
/pd
```

## What's inside

```
plugins/vet-assessment/
  skills/assessment/    the pack builder: SKILL.md pipeline, PowerShell build/gate scripts,
                        measured house profiles, branding, approved templates, logos, references
  skills/learner-guide/ the teaching resources: builds a branded Learner Guide (Word) and a
                        classroom Delivery PowerPoint from a finished assessment pack, on one
                        shared content spine so guide and deck cannot drift
  skills/docx-images/   the artwork sub-skill: scans [IMAGE:] prompts, generates with the
                        OpenAI image model, places pictures back into the .docx

plugins/vet-marking/
  skills/marking/       the marking engine: reads the unit prerequisites from training.gov.au and
                        the WiseNet 0217 enrolment matrix by cell colour to decide who must submit
                        and who is withheld RW, then produces the records an RTO keeps - a marked
                        copy per student carrying a filled cover sheet and a feedback page, a
                        standalone Student Feedback Sheet for anyone with nothing coming back, a
                        Student Assessment Record each, and one class Assessment Marking and
                        Results Record - all derived from one ledger. Consolidates several marking
                        runs into one record per WiseNet course-offer group and lays the result
                        out as a handover package, one folder per group and per student
  skills/rto-validation-docs/
                        the controlled assessment-validation document set: Parts A/B/C, the
                        Validation Plan, the Continuous Improvement Register and panel rosters,
                        against the Standards for RTOs 2025 (versioned here; installed per-project)

plugins/vet-tas/
  skills/tas/           the curriculum registry that sits above the rest: one record per institute
                        per qualification, built from that institute's own Training and Assessment
                        Strategy, with every unit sourced live from the training.gov.au REST API.
                        Detects mechanically where two units in one course cover the same ground,
                        then carries an AUTHORED ruling - with a written reason - on which unit
                        owns each shared topic, so a concept is taught once and recalled after.
                        Distinguishes real duplication from commodity-parallel content that must
                        not be collapsed. Serves assessment and learner-guide a per-unit brief:
                        what to teach in full, what to recall, and what should stop the build
plugins/vet-compliance/
  skills/auditor/       the compliance architect: registers the RTO's documents, builds one gap
                        analysis row per requirement of the 2025 Standards and the ESOS framework,
                        uplifts the policies, then designs the evidence architecture, compliance
                        calendar, registers, risk register and 12-month roadmap - all rendered from
                        one assurance ledger, every requirement cited to a verified instrument
  skills/pd/            the professional development pack: facilitator guide, slide deck, activity
                        worksheets, group allocation cards, model-answer copies, attendance and
                        evaluation record
```

Brand facts live in `skills/assessment/assets/branding.<brand>.json` and the measured house profiles beside it. **A new RTO is added by measuring its approved artefacts** (see `references/house-standard.md`), never by copying another brand's profile.
