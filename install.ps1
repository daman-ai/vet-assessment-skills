# Installs (or updates) the VET assessment skills into this machine's
# Claude Code skills folder. Run from anywhere:
#
#   git clone https://github.com/<org>/vet-assessment-skills "$env:USERPROFILE\vet-assessment-skills"
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

foreach ($skill in 'assessment', 'docx-images') {
    $src = Join-Path $repo "plugins\vet-assessment\skills\$skill"
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
Write-Host 'Installed. Requirements to actually build packs:' -ForegroundColor Green
Write-Host '  - Windows with Microsoft Word installed (delivery uses Word COM for fields and PDF export)'
Write-Host '  - Windows PowerShell 5.1 (ships with Windows)'
Write-Host '  - Claude Code, with a JavaScript-capable browser tool (training.gov.au is a JS app)'
Write-Host '  - For recipe photography: an OpenAI API key in $env:OPENAI_API_KEY or in ~\.openai-key'
Write-Host ''
Write-Host 'Use it in Claude Code with:  /assessment <UNITCODE> <QUALIFICATION> <MVC|ACI>' -ForegroundColor Green
