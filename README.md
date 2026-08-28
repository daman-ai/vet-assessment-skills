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
```

**Zero-command for a whole team:** commit this to a shared project's `.claude/settings.json` and everyone who opens that project gets the plugin automatically:

```json
{
  "extraKnownMarketplaces": {
    "vet-skills": { "source": { "source": "github", "repo": "daman-ai/vet-assessment-skills" } }
  },
  "enabledPlugins": { "vet-assessment@vet-skills": true }
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

## What's inside

```
plugins/vet-assessment/
  skills/assessment/    the pack builder: SKILL.md pipeline, PowerShell build/gate scripts,
                        measured house profiles, branding, approved templates, logos, references
  skills/docx-images/   the artwork sub-skill: scans [IMAGE:] prompts, generates with the
                        OpenAI image model, places pictures back into the .docx
```

Brand facts live in `skills/assessment/assets/branding.<brand>.json` and the measured house profiles beside it. **A new RTO is added by measuring its approved artefacts** (see `references/house-standard.md`), never by copying another brand's profile.
