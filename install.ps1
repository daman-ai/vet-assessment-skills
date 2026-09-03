# Installs (or updates) the VET skills into this machine's Claude Code skills
# folder. Run from anywhere:
#
#   git clone https://github.com/daman-ai/vet-assessment-skills "$env:USERPROFILE\vet-assessment-skills"
#   & "$env:USERPROFILE\vet-assessment-skills\install.ps1"
#
# Update later with:  & "$env:USERPROFILE\vet-assessment-skills\install.ps1" -Update

# Optional: pass your own OpenAI API key once and the artwork stage just works:
#   & .\install.ps1 -OpenAIKey "sk-..."
# The key is written ONLY to %USERPROFILE%\.openai-key on YOUR machine. It is
# never read from, written to, or committed into this repository.

[CmdletBinding()]
param([switch] $Update, [string] $OpenAIKey)

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
    'assessment'    = 'vet-assessment'
    'learner-guide' = 'vet-assessment'
    'docx-images'   = 'vet-assessment'
    'marking'       = 'vet-marking'
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

if ($OpenAIKey) {
    if ($OpenAIKey -notmatch '^sk-') { throw 'That does not look like an OpenAI API key (they start with sk-). Not saved.' }
    $keyFile = Join-Path $env:USERPROFILE '.openai-key'
    [System.IO.File]::WriteAllText($keyFile, $OpenAIKey.Trim(), (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "OpenAI key saved to $keyFile (local to this machine only - never committed)." -ForegroundColor Green
}

Write-Host ''
Write-Host 'Installed. Requirements to actually build packs:' -ForegroundColor Green
Write-Host '  - Windows with Microsoft Word installed (delivery uses Word COM for fields and PDF export)'
Write-Host '  - Windows PowerShell 5.1 (ships with Windows)'
Write-Host '  - Claude Code, with a JavaScript-capable browser tool (training.gov.au is a JS app)'
Write-Host '  - For recipe photography: an OpenAI API key in $env:OPENAI_API_KEY or in ~\.openai-key'
Write-Host '  - For marking: Microsoft Excel, to read the WiseNet .xls enrolment matrix'
Write-Host ''
Write-Host 'Use it in Claude Code with:  /assessment <UNITCODE> <QUALIFICATION> <MVC|ACI>' -ForegroundColor Green
Write-Host '                            /marking <UNITCODE>' -ForegroundColor Green
