# VET Assessment Skills

Claude Code skills that build **audit-compliant Australian VET assessment packs** matched to the RTO's own approved templates — for **Meridian Vocational College (MVC)** and **Adelaide Culinary Institute / Adelaide Construction Institute (ACI)**.

One command in Claude Code:

```
/assessment SITHCCC036 "SIT30821 Certificate III in Commercial Cookery" ACI
```

produces paired learner and assessor Word documents (a knowledge tool plus a recipe workbook with generated photography on food units; one combined UAT otherwise), red point-form model answers and benchmarks, and a compliance report — sourced live from training.gov.au, gated by blocking house-rules / readability / brand-logo checks, reviewed by three adversarial personas and an independent clean-room compliance audit.

> **This repository contains RTO intellectual property** — the approved assessment templates, both trading names' logos, branding profiles with registration details, and internal house standards. **Keep it private.** Do not fork it to a public location.

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
/plugin marketplace add <org>/vet-assessment-skills
/plugin install vet-assessment@vet-skills
```

(For a private repo, your `gh`/git credentials must have access.)

**Zero-command for a whole team:** commit this to a shared project's `.claude/settings.json` and everyone who opens that project gets the plugin automatically:

```json
{
  "extraKnownMarketplaces": {
    "vet-skills": { "source": { "source": "github", "repo": "<org>/vet-assessment-skills" } }
  },
  "enabledPlugins": { "vet-assessment@vet-skills": true }
}
```

## Install — option B: plain clone

```powershell
git clone https://github.com/<org>/vet-assessment-skills "$env:USERPROFILE\vet-assessment-skills"; & "$env:USERPROFILE\vet-assessment-skills\install.ps1"
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
