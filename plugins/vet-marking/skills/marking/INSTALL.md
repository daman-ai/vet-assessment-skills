# Installing the `marking` skill on another computer

## 1. Unzip it into the skills folder

The whole `marking` folder goes into one of these, keeping its structure:

| Scope | Path |
|---|---|
| **Just you** (usual) | `C:\Users\<you>\.claude\skills\marking\` |
| Everyone on a project | `<project>\.claude\skills\marking\` |

`SKILL.md` must end up directly inside `marking\`, like this:

```
C:\Users\<you>\.claude\skills\marking\
    SKILL.md
    INSTALL.md
    assets\
    examples\
    references\
    scripts\
```

If you end up with `…\skills\marking\marking\SKILL.md`, move the inner folder up
one level.

## 2. Check the install

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\marking\scripts\Test-Install.ps1" -Full
```

This is worth the two minutes. It checks the things a file copy can quietly
break and the things that are properties of the machine rather than the skill,
then builds the worked example and puts it through the gate.

A clean run ends `INSTALL OK`.

## 3. Confirm Claude Code can see it

Start a new session and ask it to mark something, or type `/marking`. If it does
not appear, the folder is in the wrong place — see step 1.

---

## What the target machine needs

| | Needed for | If missing |
|---|---|---|
| **PowerShell 5.1+** | everything | the skill cannot run. It ships with Windows 10/11. |
| **Microsoft Word** | the `OpensInWord` gate check, and the one-page feedback-sheet check | both degrade to a **WARN**, not a false pass. The skill still works; open one document by hand before issuing records. |
| **Microsoft Excel** | reading a WiseNet `.xls` matrix | `Import-WisenetMatrix.ps1` stops with a clear message. Export the report as `.xlsx` on a machine that has Excel, or supply the student list directly. |

**No Python and no Node are required.** Everything is PowerShell and raw OOXML.

## The one thing most likely to break in transit

**Every `.ps1` in the skill is UTF-8 *with a byte-order mark*, and must stay
that way.**

PowerShell 5.1 reads a BOM-less file as ANSI. Two things then happen, and the
second is worse than the first:

1. Some scripts **fail to parse**, with errors pointing at lines nowhere near
   the real cause.
2. The ones that still parse **quietly write mojibake** — `Â·` where `·`
   belongs — into every document they produce. The build reports success. The
   files open. The defect is only visible by reading the output.

Zip and unzip preserve the BOM. Some editors, some git configurations and some
copy-paste routes strip it. `Test-Install.ps1` checks for it first, and the
gate's `NoMojibake` check catches the second failure mode on finished documents.

To repair it:

```powershell
$enc = New-Object System.Text.UTF8Encoding($true)
Get-ChildItem "$env:USERPROFILE\.claude\skills\marking" -Filter *.ps1 -Recurse | ForEach-Object {
    $b = [System.IO.File]::ReadAllBytes($_.FullName)
    if (-not ($b.Length -ge 3 -and $b[0] -eq 0xEF)) {
        [System.IO.File]::WriteAllText($_.FullName, [System.Text.Encoding]::UTF8.GetString($b), $enc)
    }
}
```

---

## Before the first real marking run

### The public holiday table has an expiry

`assets\public-holidays.sa.json` covers **2026–2028** for **South Australia**.

- Marking in a year outside that range **throws** rather than falling back to a
  weekends-only calendar. That is deliberate: a quietly skipped public holiday
  puts a wrong resubmission deadline on a signed student record.
- **Verify the gazetted dates before marking**, even inside the range. Dates
  move.
- A different state needs its own table.

### All three RTOs are registered and measured

| Key | RTO | Status |
|---|---|---|
| `mvc` | Meridian Vocational College | three templates included and measured |
| `aci-culinary` | Adelaide Culinary Institute | three templates included and measured |
| `aci-construction` | Adelaide Construction Institute | three templates included and measured |

The builder **refuses** to run for an RTO whose templates are missing, and never
falls back to another RTO's. To add one, follow
[references/onboarding-rto.md](references/onboarding-rto.md).

### The example submissions are test fixtures

`examples\submissions\` holds seven synthetic documents — nobody's real work.
They exist so `Test-Install.ps1 -Full` can mark a whole class end to end on the
machine you have just installed on, which is the only way to know the install
works rather than merely looks complete. Between them they exercise every shape
the skill has to handle:

| Fixture | What it proves |
|---|---|
| `MVC00312_SITHPAT016_WORKBOOK.docx` | two tools in ONE file, marked together into one copy |
| `MVC00318_*`, `MVC00334_*` | the ordinary two-file shape, with a filled observation sheet |
| `MVC00341_SITHPAT016_RW.docx` | a workbook with NO observation sheet, the declared `inSubmission: false` case |

Answers sit in response boxes and the workbooks carry a real observation sheet,
so the outcome placement and the sheet fill are exercised rather than assumed.

`examples\submissions\Build-ExampleSubmissions.ps1` regenerates them. Edit the
ledger's anchors and you will need to run it, or the two will drift apart.

---

## What is in the box

```
SKILL.md                        what Claude reads
INSTALL.md                      this file
assets/
  rto.mvc.json                  MVC's measured template map and marked-copy colours
  rto.aci-culinary.json         measured template map, SIT variant
  rto.aci-construction.json     measured template map, CPC variant
  public-holidays.sa.json       observed SA holidays, 2026-2028
  templates/                    MVC's three approved .docx templates
examples/
  ledger.example.json           five students covering every case
  submissions/                  seven synthetic submissions, and the script that makes them
references/                     ten reference documents
scripts/                        eleven PowerShell scripts
_source_RTO_Marking_Instruction.docx   the RTO's original instruction, kept for provenance
```

`_source_RTO_Marking_Instruction.docx` is the RTO's own document. It is the
source the rules were written from, and it is kept so a later reader can check
the skill against it rather than against memory. Nothing reads it at run time —
delete it if the copy is going somewhere it should not.

Nothing here reaches the network. The skill reads and writes local files only.

## Quick reference

```powershell
$S = "$env:USERPROFILE\.claude\skills\marking\scripts"

# who has to submit
powershell -File "$S\Import-WisenetMatrix.ps1" -Path rpt_WiseNET_0217.xls -Unit BSBOPS501

# validate the ledger and derive everything
powershell -File "$S\Resolve-MarkingLedger.ps1" -Path ledger.json -Out resolved.json

# build every document
powershell -File "$S\Build-MarkingRecords.ps1" -Ledger resolved.json -OutDir out -SubmissionRoot .

# the blocking gate - nothing is delivered until this passes
powershell -File "$S\Test-MarkingRecords.ps1" -Ledger resolved.json -Dir out
```
