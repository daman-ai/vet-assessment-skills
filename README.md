# VET Assessment Skills

Claude Code skills for **Meridian Vocational College (MVC)** and **Adelaide Culinary Institute /
Adelaide Construction Institute (ACI)**: marking submitted student assessments, and running the
RTO's own quality system against the 2025 Standards for RTOs and the ESOS framework.

> **The assessment pack builder, the curriculum registry (tas) and the end-to-end resource
> production loop have moved to a private repository** — they now depend on live Google Sheets/Drive
> access under the RTO's own service account, which has no place in a public repo. This repository
> keeps the two plugins that don't: marking and compliance.

> **Made public by the RTO's decision.** The approved templates, logos, branding profiles and house
> standards in this repository remain the property of Meridian Vocational College and Bush Tukka Pty
> Ltd (T/A Adelaide Culinary Institute / Adelaide Construction Institute). You are welcome to study
> and reuse the **engine** (scripts, gates, references); do not present the RTOs' documents, marks or
> identities as your own.

> **No API keys, no service-account keys, ever in this repository.** Nothing in `vet-marking` or
> `vet-compliance` calls an external API or needs a credential of any kind.

## Requirements

| Requirement | Why |
|---|---|
| Windows 10/11 with **Microsoft Word** installed | Both skills update fields, count pages and export PDFs through Word COM |
| Windows PowerShell 5.1 (ships with Windows) | All build scripts target 5.1 |
| **Claude Code** with a JavaScript-capable browser tool | training.gov.au is a JS application; plain fetches return an empty page |

Avoid running builds inside a OneDrive-synced folder where possible — Word silently re-maps synced paths to SharePoint URLs and refuses to save; the skill works around this, but local folders are simpler.

## Install — option A: Claude Code plugin (recommended)

In Claude Code:

```
/plugin marketplace add daman-ai/vet-assessment-skills
/plugin install vet-marking@vet-skills
/plugin install vet-compliance@vet-skills
```

**Zero-command for a whole team:** commit this to a shared project's `.claude/settings.json` and everyone who opens that project gets the plugin automatically:

```json
{
  "extraKnownMarketplaces": {
    "vet-skills": { "source": { "source": "github", "repo": "daman-ai/vet-assessment-skills" } }
  },
  "enabledPlugins": { "vet-marking@vet-skills": true, "vet-compliance@vet-skills": true }
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

Mark a batch of submitted student assessments with:

```
/marking <UNITCODE>
```

The marking skill reads the WiseNet 0217 Unit Enrolment Outcome Matrix **by cell colour** to work out who was actually enrolled and is required to submit. It reads the unit's prerequisites from training.gov.au and withholds the result as **RW** where the matrix does not positively show the student holding them. Every student is handed their feedback, not only those assessed NYC. A 0217 export carries **one worksheet per course offer**, and where the RTO files by group rather than by marking day, several runs consolidate into one record per group and a handover package - one folder per group, one per student inside it. Real roll exports carry student names and IDs - they are gitignored, never commit one.

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
