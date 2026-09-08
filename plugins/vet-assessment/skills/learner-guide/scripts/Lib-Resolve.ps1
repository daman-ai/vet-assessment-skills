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

# ---------------------------------------------------------------------------
# EVERY LIBRARY LOADS THROUGH ONE NAMED, THROWING LOOP.
#
# The version this replaces loaded the shared library through a throwing loop
# and this skill's OWN files through `if (Test-Path) { . $p }`. A file that had
# been renamed, or was never installed, therefore loaded NOTHING and said
# NOTHING, and the caller met the miss as a CommandNotFound throw at the first
# call site - which at Stage 0 was the palette check, recorded as a note beside
# a pass. A library that is not there is a broken installation, not an optional
# extra, so each entry below names itself when it is missing.
#
# Set-ResourceBrand.ps1 is in the set because Stage 0's palette check IS
# Get-BrandPalettePairs; Lib-RtoProfile.ps1 is in it because Stage 0's profile
# gate is Get-RtoProfile, and loading the library rather than the CLI wrapper is
# what stops that wrapper's param block from clobbering a caller's $Rto.
#
# Order is load-bearing: later files call functions defined in earlier ones.
# ---------------------------------------------------------------------------

function Import-GuideLibraryFile {
    <#  Dot-source ONE library file at the CALLER's scope, or throw naming it.

        It takes the caller's scope from the dot operator at the call site -
        `. Import-GuideLibraryFile` is not possible, so this function returns
        the resolved path and the caller dot-sources it. Resolution and the
        refusal live here; the dot stays at script scope, where the definitions
        have to land.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Directory,
        [Parameter(Mandatory)][string] $File,
        [Parameter(Mandatory)][string] $Provides
    )
    $p = Join-Path $Directory $File
    if (-not (Test-Path -LiteralPath $p)) {
        throw ("Library file missing: {0}`n  looked in : {1}`n  it provides: {2}`n`nThis is not an optional extra. A missing library used to load silently and surface as a CommandNotFound throw at the first call site, which at Stage 0 was recorded beside a pass. Reinstall the skill, or restore the file." -f $File, $Directory, $Provides)
    }
    return (Resolve-Path -LiteralPath $p).Path
}

#  The shared library, from the assessment skill (or the merged scripts dir).
foreach ($f in @(
    @{ File = 'Build-FromTemplate.ps1'; Provides = 'Get-Branding, Expand/Compress-Docx, Get/Set-DocxPart, Set-BrandLogo, Set-BrandPalette, Set-BrandIdentity, Set-HousePalette, Test-DocxPackage' },
    @{ File = 'Docx-Blocks-House.ps1';  Provides = 'the H* block builders every renderer calls' },
    @{ File = 'Test-HouseRules.ps1';    Provides = 'Get-HouseProfile, Test-HouseRules' },
    @{ File = 'Test-Readability.ps1';   Provides = 'Test-Readability' },
    @{ File = 'Verify-Document.ps1';    Provides = 'Invoke-DocumentVerification, Test-PageFlow, Get-PageText' }
)) {
    . (Import-GuideLibraryFile -Directory $script:GuideSharedLib -File $f.File -Provides $f.Provides)
}

#  This skill's own libraries. Named, not globbed, and every one of them
#  throws by name when it is absent.
$script:GuideOwnLibraries = @(
    @{ File = 'Xml-Scan.ps1';          Provides = 'balanced-element scanning - the Word gate needs it as much as the deck builder does'; Deck = $false },
    @{ File = 'Lib-RtoProfile.ps1';    Provides = 'Get-RtoProfile, Assert-RtoProfile, Write-RtoProfileReport - the Stage 0 profile gate'; Deck = $false },
    @{ File = 'Set-ResourceBrand.ps1'; Provides = 'Get-BrandPalettePairs (the Stage 0 palette check), Set-GuideBrand, Assert-GuideBrand, Set-DeckBrand'; Deck = $false },
    @{ File = 'Test-GuideRules.ps1';   Provides = 'the rendered-guide rule set'; Deck = $false },
    @{ File = 'Build-Guide.ps1';       Provides = 'the guide renderer'; Deck = $false },
    @{ File = 'Pptx-Blocks.ps1';       Provides = 'the deck block builders'; Deck = $true },
    @{ File = 'Test-DeckRules.ps1';    Provides = 'the rendered-deck rule set'; Deck = $true }
)
foreach ($f in $script:GuideOwnLibraries) {
    if ($f.Deck -and $NoDeck) { continue }
    . (Import-GuideLibraryFile -Directory $PSScriptRoot -File $f.File -Provides $f.Provides)
}

Write-Verbose "shared library: $script:GuideSharedLib"
