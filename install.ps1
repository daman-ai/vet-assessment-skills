# Installs (or updates) the VET skills into this machine's Claude Code skills
# folder. Run from anywhere:
#
#   git clone https://github.com/daman-ai/vet-assessment-skills "$env:USERPROFILE\vet-assessment-skills"
#   & "$env:USERPROFILE\vet-assessment-skills\install.ps1"
#
# Update later with:  & "$env:USERPROFILE\vet-assessment-skills\install.ps1" -Update

[CmdletBinding()]
param([switch] $Update)

$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
if (-not $repo) { throw 'Cannot resolve the repo directory. Run the script by path, not by pasted content.' }

if ($Update) {
    Write-Host 'Pulling latest...' -ForegroundColor Cyan
    & git -C $repo pull --ff-only
    if ($LASTEXITCODE -ne 0) { throw 'git pull failed - resolve and re-run.' }
}

$dest = Join-Path $env:USERPROFILE '.claude\skills'
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }

# Skill name -> the plugin in this repo that owns it.
$skills = [ordered] @{
    'marking'       = 'vet-marking'
    'auditor'       = 'vet-compliance'
    'pd'            = 'vet-compliance'
}

# NOTE: rto-validation-docs is versioned in this repo (plugins/vet-marking/skills)
# but is deliberately NOT installed user-level. It currently ships as a PROJECT
# skill in the workspace that uses it; installing it here too would register two
# skills with the same name. Copy it into that project's .claude\skills yourself,
# or move it here and drop the project copy - but not both.

foreach ($skill in $skills.Keys) {
    $src = Join-Path $repo ("plugins\{0}\skills\{1}" -f $skills[$skill], $skill)
    if (-not (Test-Path $src)) { throw "Skill missing from repo: $skill" }
    $tgt = Join-Path $dest $skill
    Write-Host ("Installing {0} -> {1}" -f $skill, $tgt) -ForegroundColor Cyan
    # /MIR keeps the install identical to the repo - local edits to the skill
    # belong in the repo, not in the installed copy.
    $null = robocopy $src $tgt /MIR /NFL /NDL /NJH /NJS /NP
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed for $skill (code $LASTEXITCODE)" }
}
$global:LASTEXITCODE = 0

Write-Host ''
Write-Host 'Installed. Requirements to actually run these:' -ForegroundColor Green
Write-Host '  - Windows with Microsoft Word installed (both skills use Word COM for fields and PDF export)'
Write-Host '  - Windows PowerShell 5.1 (ships with Windows)'
Write-Host '  - Claude Code, with a JavaScript-capable browser tool (training.gov.au is a JS app)'
Write-Host '  - For marking: Microsoft Excel, to read the WiseNet .xls enrolment matrix'
Write-Host ''
Write-Host 'Use it in Claude Code with:  /marking <UNITCODE>' -ForegroundColor Green
Write-Host '                            /auditor  - RTO and CRICOS compliance against the 2025 Standards' -ForegroundColor Green
Write-Host '                            /pd       - a professional development session pack' -ForegroundColor Green
