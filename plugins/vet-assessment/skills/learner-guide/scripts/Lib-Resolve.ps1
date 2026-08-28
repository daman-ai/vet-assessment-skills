<#
    Lib-Resolve.ps1

    Locate and load the shared document library. DOT-SOURCE THIS FILE:

        . "$SkillDir\scripts\Lib-Resolve.ps1"

    and every function from both libraries is then available. Optionally:

        . "$SkillDir\scripts\Lib-Resolve.ps1" -SharedPath 'C:\...\assessment\scripts'

    WHY IT IS A DOT-SOURCED SCRIPT AND NOT A FUNCTION

    Dot-sourcing inside a function loads those definitions into the FUNCTION's
    scope, and they disappear the moment it returns - so an Import-Library
    function looks like it works, reports success, and leaves the caller with no
    functions. Loading at script scope is the only arrangement that puts them
    where the caller can reach them.

    WHY THE LIBRARY IS SHARED, NOT COPIED

    The assessment skill already owns a proven, measured OOXML library - zip
    round-tripping, part access, brand swaps, the H* block builders, the
    readability gate and the Word COM verifier. A Learner Guide is the same kind
    of artefact built from the same kind of approved template, so it uses the
    same library rather than a second copy of it. Two forks of a 43 KB assembler
    would drift, and the first drift would surface as a guide that passes its
    own gate and fails the RTO's.

    These two skills are intended to merge. When they do, the sibling-directory
    candidate below resolves to the merged scripts directory and nothing else
    changes.

    ASCII only in this file.
#>

[CmdletBinding()]
param(
    [string] $SharedPath,
    [switch] $NoDeck
)

# ---------------------------------------------------------------------------

function Get-SharedLibraryPath {
    <#  The scripts directory holding the shared OOXML library.

        Checked in order: an explicit -SharedPath, the MVC_ASSESSMENT_SKILL
        environment variable, a sibling 'assessment' skill, then this skill's
        own scripts directory - which is where the files live post-merge.  #>
    [CmdletBinding()]
    param([string] $Path, [string] $Here)

    $skillRoot = Split-Path -Parent $Here
    $skillsDir = Split-Path -Parent $skillRoot

    $candidates = New-Object System.Collections.Generic.List[string]
    if ($Path)                     { $candidates.Add($Path) }
    if ($env:MVC_ASSESSMENT_SKILL) { $candidates.Add((Join-Path $env:MVC_ASSESSMENT_SKILL 'scripts')) }
    $candidates.Add((Join-Path $skillsDir 'assessment\scripts'))
    $candidates.Add($Here)

    foreach ($c in $candidates) {
        if ((Test-Path -LiteralPath (Join-Path $c 'Build-FromTemplate.ps1')) -and
            (Test-Path -LiteralPath (Join-Path $c 'Docx-Blocks-House.ps1'))) {
            return (Resolve-Path -LiteralPath $c).Path
        }
    }

    throw @"
Cannot find the shared document library.

This skill builds on the assessment skill's OOXML library rather than carrying a
second copy of it. Looked in:
$(($candidates | ForEach-Object { "  $_" }) -join "`n")

Fix one of these:
  - install the 'assessment' skill beside this one, or
  - set MVC_ASSESSMENT_SKILL to its skill directory, or
  - dot-source with -SharedPath pointing at the directory holding
    Build-FromTemplate.ps1.
"@
}

# ---------------------------------------------------------------------------
# Load, at THIS script's scope, which is the dot-sourcing caller's scope.
# Order is load-bearing: the later files call functions from the earlier ones.
# ---------------------------------------------------------------------------

$script:GuideSharedLib = Get-SharedLibraryPath -Path $SharedPath -Here $PSScriptRoot

foreach ($f in @(
    'Build-FromTemplate.ps1',   # Get-Branding, Expand/Compress-Docx, Get/Set-DocxPart, Test-DocxPackage
    'Docx-Blocks-House.ps1',    # the H* block builders
    'Test-HouseRules.ps1',      # Get-HouseProfile, Test-HouseRules
    'Test-Readability.ps1',     # Test-Readability
    'Verify-Document.ps1'       # Invoke-DocumentVerification, Test-PageFlow, Get-PageText
)) {
    $p = Join-Path $script:GuideSharedLib $f
    if (-not (Test-Path -LiteralPath $p)) { throw "Shared library is incomplete - missing $f in $script:GuideSharedLib" }
    . $p
}

# Xml-Scan is shared by both builders and always loads - the Word gate needs
# balanced-element scanning as much as the deck builder does.
. (Join-Path $PSScriptRoot 'Xml-Scan.ps1')

foreach ($f in @('Test-GuideRules.ps1', 'Build-Guide.ps1')) {
    $p = Join-Path $PSScriptRoot $f
    if (Test-Path -LiteralPath $p) { . $p }
}

if (-not $NoDeck) {
    foreach ($f in @('Pptx-Blocks.ps1', 'Test-DeckRules.ps1')) {
        $p = Join-Path $PSScriptRoot $f
        if (Test-Path -LiteralPath $p) { . $p }
    }
}

Write-Verbose "shared library: $script:GuideSharedLib"
