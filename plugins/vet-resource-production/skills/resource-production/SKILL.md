---
name: resource-production
description: Run the whole resource production loop for one unit of competency at Meridian Vocational College or ACI from a single command - unit code and college in, a staged and register-backed assessment pack, learner guide and delivery deck out. Chains the tas registry brief, the assessment skill, the learner-guide skill and a clean-room AI verification against training.gov.au, rebuilds until the verification is clean, packages the deliverables to Google Drive, and writes every row the three compliance registers need (assessment tool register, pre-use tool review record, industry consultation register) - opening the work order before the build, staging with attachments after it, and recording the trainer's review, the pre-use review, the approval and the publish as named people make them. Use when asked to build, produce, generate or version a unit's resources end to end, to run the resource production loop or the P-01 pipeline, to stage a pack for review, to record a pre-use review or industry consultation, to approve or publish a unit's pack, or to bring a unit's assessment tools into the register.
---

# Resource production loop

One command builds; people hold the gates. This skill is the "command" specified on the Resource Production Loop page: it runs the chain, verifies it, rebuilds until clean, packages it, and keeps the three registers - and it **never** approves, never numbers a version 1.0, never uploads to eSkilled, never edits an approved document, and never runs an AI use past its review date. Every judgement value written to a register was typed by a named person in front of you; this skill records it with their name and refuses when the separation of duties or the order of dates fails.

Read `references/loop.md` first. It is the loop, the eleven steps, the three registers, and the three-people rule this skill enforces.

## The command

```
/resource-production <UNIT CODE> <MVC|ACI> [--course <PROVIDER-QUAL>]
/resource-production review  <UNIT CODE> <MVC|ACI>      the trainer's sitting (R6, R7)
/resource-production approve <UNIT CODE> <MVC|ACI>      gate one (R9)
/resource-production publish <UNIT CODE> <MVC|ACI>      R10
/resource-production status  <UNIT CODE> <MVC|ACI>
```

All scripts are node (v20+, no packages). Run them from anywhere:

```
node ~/.claude/skills/resource-production/scripts/<script>.js ...
```

Paths in `config/loop.config.json`: `buildRoot` (one folder per unit and college, outside every skill), `registerMirror` (local CSV copies of the three sheets), `serviceAccountKey` (see Set-up). Without the key the scripts still run: rows go to the mirror and are printed for a person to paste into the sheet, and the staging package stays on disk with a note to drag it in.

## Before the build: the three names

The builder is **whoever runs this command** - the signed-in user, or the dashboard's submitting staff member. Ask for the other two if they were not given:

- the **reviewing trainer** - the trainer who will deliver the unit; holds the unit on the credential matrix and has industry currency on the PD register; not the builder
- the **approver** - not the builder, not the reviewing trainer. When Daman builds and the head of training delivers, nobody is left: stop and say so - someone else must build so that Daman can approve

`work-order.js` refuses any set where two of the three are the same person. Defaults for a known head of training and approver live in `config.people`; ask rather than assume when they are blank.

## The build - one run

### R0 · AI uses registered (checked, not done here)

`work-order.js` reads `config.aiUses`. Each of the five uses needs `registeredOn` and a `reviewDue` not yet passed; ICT & AI maintain these from the AI system register. If any is missing the command stops. `--allow-unregistered-ai` proceeds with the finding written on every tool row and in the run log - use it only when the user says so, and say in the summary that R0 is open.

### R1 · Work order

```
node scripts/work-order.js --unit SITHCCC035 --college MVC --builder "<name>" --trainer "<name>" --approver "<name>" [--course MVC-SIT30821]
node scripts/registers.js open --unit SITHCCC035 --college MVC
```

The first resolves the course from the tas registry (stops if the unit is superseded, not delivered at that college, or delivered in more than one course without `--course`), the ACI trading name from the course record, and the expected document set - four pack documents for a food unit, two otherwise, plus the guide and the deck. It writes `work-order.json` and starts `run-log.md` in the build folder. The second opens one tool-register row per expected document at 0.1 Draft, with builder, skills, roles and the unit release read that day. **Nothing is built before the rows exist.** Without a key, the rows are printed: hand them to the head of training to enter now, not after.

### R2 · Build

Work in the build folder the work order names. In order, and never out of it:

1. **The brief.** `& <tas>\scripts\Get-UnitBrief.ps1 -Unit <UNIT> -CourseId <courseId> -Json > brief.json`. A blocker stops the command; report it to the head of training and go no further.
2. **The pack.** Invoke the `assessment` skill with `/assessment <UNIT> <QUAL> <BRAND>` (the work order carries the qualification and the brand; for ACI the variant is resolved in the skill from the unit's training package). Give it the brief. Follow that skill in full - its Stage 0 measures the RTO's documents, its gates are its own evidence. Record the build directory it used and the paths of every document and the compliance report.
3. **The resources.** Invoke `learner-guide` with `/learner-guide <UNIT> <BRAND> <path to the pack>`. Follow it in full. Record the guide, the deck and the resource report.

A red gate in either skill's report stops the run here. Do not stage a pack with a red gate.

### R3 · Clean-room verification

```
node scripts/extract-text.js --out <build>/verify <every .docx and .pptx deliverable>
node scripts/verify-report.js brief --unit <UNIT> --college <COLLEGE>
```

Then launch **one subagent** (Agent tool, general-purpose) with this and only this: "Read `<build>/verify/brief.md` and every `<build>/verify/*.txt`. Do not read anything else in `<build>`. Return the JSON the brief asks for." The agent has no build folder, no prompts and no reasoning from the build - that is what makes it clean-room. Save its JSON as `verify/round-1.json` and run:

```
node scripts/verify-report.js round --unit <UNIT> --college <COLLEGE> --json <build>/verify/round-1.json
```

Exit 0 means clean. Exit 3 means discrepancies. A release mismatch stops everything: the unit changed on training.gov.au during the build.

### R4 · Rebuild until clean

For each discrepancy: fix it **through the skill that built the document** - the assessment skill's remediation path, or a learner-guide rebuild - never by editing the file. Then `registers.js version --unit U --college C --version 0.<n+1> --note "<what changed>"`, re-extract, re-brief, run a fresh subagent, record `round-<n>.json`. At most `config.verification.maxRounds` rounds; after that, stop and hand the report to the builder. A `should` item that is not worth a rebuild may be reasoned instead of fixed. When the final round is clean or every remaining item has a reason, write `verify/resolutions.json` (`fixed` or `reasoned` per id, with a note) and:

```
node scripts/verify-report.js resolve --unit <UNIT> --college <COLLEGE> --json <build>/verify/resolutions.json
```

Exit 1 while anything is open. Nothing unresolved reaches staging.

### R5 · Stage

Write `files.json` mapping each work-order document key to its file, plus `complianceReport` and `resourceReport`, then:

```
node scripts/stage-package.js --unit <UNIT> --college <COLLEGE> --version 0.<n> --files <build>/files.json --ai-rules-stated Yes|No
```

It copies the deliverables and the four attachments (work order, run log, reports, verification) into `staging/v0.n`, uploads them to Drive > Registers > Staging > `<UNIT>-<COLLEGE>` > `v0.n`, and sets every tool row to Staged with the links. `--ai-rules-stated Yes` only if every task in the tool states what AI help a student may use.

**Stop here.** Tell the user the package is staged, name the reviewing trainer, and that nothing reaches a student until `review`, `approve` and `publish` have each been run by the person they belong to.

## The gates - people, recorded by the command

### `review` · R6 and R7, one sitting, the reviewing trainer

The trainer sits at the keyboard, or the user relays their answers verbatim and says so. Confirm the trainer's name matches the work order. Then ask - with AskUserQuestion, one screen at a time - and write the answers:

**R6, the consultation row** (pack, guide and deck together): date; their organisation and role; why they are relevant industry for this product; the currency evidence (the PD register row or a dated industry activity); the advice, in their words; the decision (Changed / No change, reasoned / Pending); the change to be made or the reason for none; the next review trigger. Save as `consult.json` and run `registers.js consult`. A trainer with no currency evidence is not a consultation - stop and say what is missing.

**R7, the pre-use review** - once per assessment tool row (Knowledge, Practical, Workbook): confirm they hold the unit on the credential matrix; that they worked through the AI verification report against training.gov.au; then the eight questions, each Met or Amend - validity, reliability, flexibility, fairness, sufficiency, authenticity, currency, validity of evidence - with their reasons; practical application components present, Yes or No; findings and amendments required. Save as `preuse.json` and run `registers.js preuse`. Any Amend makes the outcome *Return to builder* and the row says why.

If the sitting produces findings: R8. Otherwise tell the approver the unit is ready.

### R8 · Correct after review

Findings go back through the skill as a new 0.x - `registers.js version` - then R3, R4, R5 again, then the sitting again on the new version (new rows). Never a hand edit; where a hand edit to a learner tool is unavoidable, regenerate its assessor guide with `assessorguide`.

### `approve` · R9, the approver

The approver is at the keyboard, or the user relays their decision and says so. Show them `registers.js show`. Confirm they have read the pack, the consultation row(s), the pre-use row(s) and the verification report. On their word:

```
node scripts/registers.js approve --unit <UNIT> --college <COLLEGE> --approver "<name>" [--version 1.0] [--date YYYY-MM-DD]
```

The script refuses if the approver built it or will deliver it, if any tool row lacks a pre-use row at this version with *Ready for approval*, if any consultation row is Pending, if discrepancies are unresolved, or if a review is dated after the approval. It sets Approved, the version, the approver and the date, and supersedes any earlier Approved or Published version of the same document (matched by title). **An approved version is never re-versioned in place**: `registers.js version` refuses on an Approved or Published row. Rework after approval starts a new row set with `work-order.js --force` (which archives the old work order beside the new one), runs the whole loop again from R2, and is approved as `--version 1.1`; a new unit release on training.gov.au the same way as `2.0`.

### `publish` · R10, the head of training

After the approved files are in eSkilled under their version: `registers.js publish --unit U --college C --publisher "<name>"`. Then update the TAS's list of tools in use. The eSkilled version must equal the row's version - say so in the summary.

## What an auditor is shown

For any unit: the work order and run log (who, when, which skills, which release, every verification round), the AI verification report with every item resolved or reasoned, the compliance and resource reports, the consultation row(s) with the change made, the pre-use row with eight answers and a reviewer who holds the unit and did not build it, the approval by a third person, the publish date, and the superseded chain. The registers are the evidence; this skill's job is that they are never a step behind the documents.

## The five things this command never does

1. Mark anything Approved, or number a version 1.0 - `registers.js version` accepts 0.x only; `approve` is a person's command.
2. Upload to eSkilled.
3. Edit an approved document - a change is a new 0.x through the whole loop.
4. Build a guide from anything but its own current pack build - the resources are rebuilt on every pack rebuild and carry the pack version.
5. Run an unregistered AI use silently - R0 stops the run, or writes the finding on every row.

## Set-up (once)

1. **Google access.** Create a service account in Google Cloud with the Sheets API and Drive API enabled, download its JSON key to `config/service-account.json`, and share the Registers folder (`config.drive.registersFolderId`) and the three sheets with the service account's email as Editor. Workspace admins may need to allow sharing with that address. Until then the scripts work in mirror-and-paste mode.
2. **People.** Fill `config.people` with the head of training and the default approver.
3. **AI uses.** ICT & AI register the five uses and fill `registeredOn` and `reviewDue` for each. `AI-USE-05` is this skill's clean-room verifier.
4. **The other skills.** `tas` with the course in the registry (record hashed to the approved TAS, rulings authored); `assessment` and `learner-guide` installed with the RTO's templates and profiles; the OpenAI key for `docx-images` where a unit produces food.
5. **The sheets.** Keep the header rows exactly as designed - `registers.js` maps columns by name and stops if one is missing. The example row 2 in each sheet can be deleted; ids continue from the highest number present.
