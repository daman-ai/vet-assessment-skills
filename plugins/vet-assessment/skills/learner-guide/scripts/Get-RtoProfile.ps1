<#
    Get-RtoProfile.ps1 - the CLI wrapper over Lib-RtoProfile.ps1, which holds
    every function below and has no param() block of its own.

    RUN IT as the Stage S0-RTO gate:

        & "$SkillDir\scripts\Get-RtoProfile.ps1" -Rto MVC -Check

    To USE the functions, dot-source the library resolver, never this file:

        . "$SkillDir\scripts\Lib-Resolve.ps1"
        $rtoProfile = Get-RtoProfile -Rto MVC

    WHY IT EXISTS. This skill is shared across RTOs, brands and units, and
    almost everything a build hard-codes is a property of the RTO, not of the
    unit: which templates are approved, which palette role means what, which
    layouts may legitimately carry no speaker notes, what a document-control
    block is supposed to look like. Re-deriving that every build is how one
    build ended up with ten build-local scripts hard-coding a single unit code,
    a single brand and that build's own counts, and how a document-control block
    went through three consecutive audits recorded only as "not verifiable" -
    because nothing declared what it was supposed to be.

    THE PACK POINTS; IT DOES NOT COPY. Identity strings and palette hexes are
    read from the branding profile, geometry and callouts from the guide
    profile, layouts and slot ordinals from the deck profile. Nothing is
    restated here, because a restated hex is a second source of truth free to
    drift from the map the brand swap actually applies - which is precisely how
    a crossover sweep came to print "no crossover" over 766 live occurrences of
    another brand's fills.

    IT THROWS RATHER THAN DEFAULTING. There is no built-in fallback profile and
    no default template path. An RTO with no pack builds the pack first; a build
    must never fill the gap with literals in its own scripts, and a silent
    default is how the wrong brand gets drawn without anything erroring.

    WHAT ASSERT-RTOPROFILE CHECKS, all of it derived from
    assets/rto-profile.schema.json rather than typed here:

      - every required key present and non-empty
      - both approved templates exist on disk (a brand with no approved guide
        template and no deck template cannot be built - ask the RTO for one
        rather than generating it)
      - the referenced guide profile, deck profile and branding profile all
        load, and the branding profile declares the same brand as the pack
      - every palette role in the CLOSED enum resolves to a six-hex value under
        one of its declared aliases, and no two roles collide by accident
      - every required identity field is present, and no identity string of this
        RTO is also carried by another brand's profile - a collision would make
        the crossover sweep structurally unable to tell them apart
      - the no-notes exemption list and its written reasons match EXACTLY, in
        both directions: an exemption with no reason is a shipped deck rule
        switched off where no audit would see it, and a reason for an exemption
        nobody made is a stale allow-list entry
      - every carve-out carries a scope and a written reason

    PS 5.1. ASCII only in this file.
    Exit 0 valid, 1 invalid, 2 a usage error.
#>
#  THE PARAMETER NAMES HERE ARE CHOSEN NOT TO COLLIDE, AND $Rto IS DELIBERATELY
#  UNTYPED. Dot-sourcing a script runs its param block IN THE CALLER'S SCOPE, so
#  every name below lands in the build's own variables. Two consequences, and
#  the first one cost an hour of this very change:
#
#    - a TYPED script parameter stays type-constrained afterwards. With
#      [string] $Rto here, the pre-flight line `$rto = Get-RtoProfile -Rto MVC`
#      silently coerced the whole profile object to its string form, and
#      $rto.GuideTemplate then read as empty with nothing erroring anywhere.
#    - a parameter named like a build variable OVERWRITES it. $SkillDir is the
#      build's own skill directory in every code block in SKILL.md, so this
#      script must not have a parameter of that name - dot-sourcing it would set
#      the build's $SkillDir to empty before the next line runs.
#
#  Hence -SkillPath and -BrandingPath, and no type constraints.

[CmdletBinding()]
param(
    $Rto,
    $SkillPath,
    $BrandingPath,
    [switch] $Check,
    [switch] $Quiet
)


#  THIS FILE IS NOW A THIN CLI WRAPPER. Everything it used to define lives in
#  Lib-RtoProfile.ps1, which has NO param() block and therefore cannot clobber a
#  caller's variables. Dot-sourcing THIS file still works and still loads every
#  function - but it also runs the param block below in your scope, so a build
#  that has already resolved its brand into $Rto loses it. Stage 0 dot-sources
#  Lib-Resolve.ps1 alone, which loads the library; run this file only as a CLI.

$script:__RtoLib = Join-Path $PSScriptRoot 'Lib-RtoProfile.ps1'
if (-not (Test-Path -LiteralPath $script:__RtoLib)) {
    throw "Get-RtoProfile.ps1 is a thin wrapper over Lib-RtoProfile.ps1, which is missing from $PSScriptRoot. The pack cannot be loaded, and a wrapper that quietly defined nothing would leave Get-RtoProfile unresolved at the first call site rather than here."
}
. $script:__RtoLib

if ($Check) {
    if (-not $Rto) { Write-Host 'Get-RtoProfile.ps1 -Check needs -Rto <brand key>.' -ForegroundColor Red; exit 2 }
    $prof = Get-RtoProfile -Rto "$Rto" -SkillDir $SkillPath -BrandingDir $BrandingPath -SkipValidation
    $res  = Assert-RtoProfile -Profile $prof
    if (-not $Quiet) { Write-RtoProfileReport -Result $res -Profile $prof }
    if (-not $res.Ok) { exit 1 }
    exit 0
}

