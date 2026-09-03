<#
    Get-RtoProfile.ps1 - load and validate an RTO PROFILE PACK.

    DOT-SOURCE IT, or run it directly as the Stage S0-RTO gate:

        . "$SkillDir\scripts\Get-RtoProfile.ps1"
        $rtoProfile = Get-RtoProfile -Rto MVC

        & "$SkillDir\scripts\Get-RtoProfile.ps1" -Rto MVC -Check

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

# No Set-StrictMode - dot-sourced.

function Get-RtoProfileRoot {
    param([string] $SkillDir)
    if ($SkillDir) { return $SkillDir }
    return (Split-Path -Parent $PSScriptRoot)
}

function Read-RtoJson {
    <#  Read JSON as EXPLICIT UTF-8 with the BOM dropped. Windows PowerShell 5.1
        decodes a BOM-less UTF-8 file as ANSI, which mangles every non-ASCII
        character in a profile; a BOM left on the front of the string makes
        ConvertFrom-Json throw on a file that is perfectly valid. #>
    param([Parameter(Mandatory)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $t = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path, [System.Text.Encoding]::UTF8)
    $t = $t.TrimStart([char]0xFEFF)
    if (-not $t.Trim()) { return $null }
    return ($t | ConvertFrom-Json)
}

function Get-RtoProp {
    <# A dotted path into a parsed JSON object, or $null. #>
    param($Object, [Parameter(Mandatory)][string] $Path)
    $cur = $Object
    foreach ($seg in ($Path -split '\.')) {
        if ($null -eq $cur) { return $null }
        if (@($cur.PSObject.Properties.Name) -notcontains $seg) { return $null }
        $cur = $cur.$seg
    }
    return $cur
}

function Resolve-RtoBrandingDir {
    <#  The directory holding branding.<brand>.json.

        Checked in order: an explicit -BrandingDir, $script:SkillRoot (set by
        the shared library when it loads, and pointing at the skill that owns
        the branding profiles), the MVC_ASSESSMENT_SKILL environment variable, a
        sibling 'assessment' skill, then this skill's own assets - which is
        where they live after the two skills merge. #>
    param([string] $BrandingDir, [string] $Root)

    $cand = New-Object System.Collections.Generic.List[string]
    if ($BrandingDir)              { $cand.Add($BrandingDir) }
    if ($script:SkillRoot)         { $cand.Add((Join-Path $script:SkillRoot 'assets')) }
    if ($env:MVC_ASSESSMENT_SKILL) { $cand.Add((Join-Path $env:MVC_ASSESSMENT_SKILL 'assets')) }
    $cand.Add((Join-Path (Split-Path -Parent $Root) 'assessment\assets'))
    $cand.Add((Join-Path $Root 'assets'))

    foreach ($c in $cand) {
        if ((Test-Path -LiteralPath $c) -and
            @(Get-ChildItem -LiteralPath $c -Filter 'branding.*.json' -File -ErrorAction SilentlyContinue).Count) {
            return (Resolve-Path -LiteralPath $c).Path
        }
    }
    throw @"
Cannot locate the branding profiles. Looked in:
$(($cand | ForEach-Object { "  $_" }) -join "`n")

The pack reads identity strings and palette roles from them and copies neither.
Pass -BrandingDir, install the 'assessment' skill beside this one, or set
MVC_ASSESSMENT_SKILL to its skill directory.
"@
}

function Get-RtoIdentityString {
    <#  Every identity string a profile carries, under any of its known names.
        The crossover gate derives its forbidden set from these same files by
        the same rule; this is the same derivation, never a copy of its list. #>
    param($Node, [string[]] $Fields)
    $out = [ordered]@{}
    if ($null -eq $Node) { return $out }
    foreach ($f in $Fields) {
        if (@($Node.PSObject.Properties.Name) -contains $f -and $Node.$f) {
            $out[$f] = [string]$Node.$f
        }
    }
    return $out
}

function Get-RtoProfile {
    <#  Load assets/rto-profile.<rto>.json, resolve everything it points at, and
        validate it. Returns the pack as an object whose .GuideTemplate and
        .DeckTemplate are absolute paths a build can hand straight to
        Expand-Docx.

        -SkipValidation exists for the S0-RTO assembly loop only, where the pack
        is being written and is not yet valid. A BUILD never passes it: a
        profile that loads but does not validate is worse than one that refuses,
        because the failure then surfaces somewhere unrelated. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Rto,
        [string] $SkillDir,
        [string] $BrandingDir,
        [switch] $SkipValidation
    )

    $root = Get-RtoProfileRoot -SkillDir $SkillDir
    $path = Join-Path $root ("assets\rto-profile.{0}.json" -f $Rto.ToLower())

    if (-not (Test-Path -LiteralPath $path)) {
        throw @"
No RTO profile pack for '$Rto' at:
  $path

An RTO with no profile pack builds the pack first - it is assembled once, off
the per-build critical path, and amortised across every unit that RTO ever
builds. Copy assets\rto-profile.mvc.json as the worked example, and validate it
with:

  & "<skill>\scripts\Get-RtoProfile.ps1" -Rto $Rto -Check

A build must never fill the gap with template paths, palette hexes or provider
codes typed into its own scripts.
"@
    }

    $pack = Read-RtoJson -Path $path
    if ($null -eq $pack) { throw "The RTO profile pack at $path is empty or is not valid JSON." }

    $schemaPath = Join-Path $root 'assets\rto-profile.schema.json'
    $schema = Read-RtoJson -Path $schemaPath
    if ($null -eq $schema) { throw "No profile schema at $schemaPath. The pack cannot be validated against a schema that is not there, and an unvalidated pack is the hard-coding it exists to prevent." }

    $brandingDirR = Resolve-RtoBrandingDir -BrandingDir $BrandingDir -Root $root

    # ---- resolve the files the pack points at
    $resolve = {
        param([string] $Rel)
        if (-not $Rel) { return '' }
        if ([System.IO.Path]::IsPathRooted($Rel)) { return $Rel }
        return (Join-Path $root ($Rel -replace '/', '\'))
    }

    $guideTpl  = & $resolve ([string](Get-RtoProp -Object $pack -Path 'templates.guide'))
    $deckTpl   = & $resolve ([string](Get-RtoProp -Object $pack -Path 'templates.deck'))
    $guideProf = & $resolve ([string]$pack.guideProfile)
    $deckProf  = & $resolve ([string]$pack.deckLayouts)
    $brandFile = Join-Path $brandingDirR ([string]$pack.brandingFile)

    $branding = Read-RtoJson -Path $brandFile

    # ---- derive the palette role map over the schema's CLOSED enum
    $roles = [ordered]@{}
    $roleProblems = @()
    if ($branding -and $branding.palette) {
        foreach ($rp in @($schema.paletteRoles.PSObject.Properties)) {
            if ($rp.Name -like '_*') { continue }
            $hit = $null
            foreach ($alias in @($rp.Value)) {
                if (@($branding.palette.PSObject.Properties.Name) -contains $alias -and $branding.palette.$alias) {
                    $hit = [string]$branding.palette.$alias; break
                }
            }
            if ($hit) { $roles[$rp.Name] = $hit }
            else { $roleProblems += ("palette role '{0}' resolves to nothing under any of its declared names ({1})" -f $rp.Name, (@($rp.Value) -join ', ')) }
        }
    }

    # ---- identity, this brand and every other brand on disk
    $idFields = @(@($schema.identityFields.required) + @($schema.identityFields.optional)) | Where-Object { $_ }
    $identity = Get-RtoIdentityString -Node $branding.rto -Fields $idFields

    $others = New-Object System.Collections.Generic.List[object]
    foreach ($pf in (Get-ChildItem -LiteralPath $brandingDirR -Filter 'branding.*.json' -File)) {
        $op = Read-RtoJson -Path $pf.FullName
        if ($null -eq $op) { continue }
        if ("$($op.brand)" -eq "$($pack.rto)") { continue }
        $others.Add([pscustomobject]@{
            Brand    = [string]$op.brand
            File     = $pf.Name
            Identity = (Get-RtoIdentityString -Node $op.rto -Fields $idFields)
        })
    }

    $deckProfile = Read-RtoJson -Path $deckProf

    $out = [pscustomobject]@{
        Rto             = [string]$pack.rto
        ProfileVersion  = [string]$pack.profileVersion
        SchemaVersion   = [string]$pack.schemaVersion
        Path            = $path
        SchemaPath      = $schemaPath
        GuideTemplate   = $guideTpl
        DeckTemplate    = $deckTpl
        GuideProfile    = (Read-RtoJson -Path $guideProf)
        GuideProfilePath = $guideProf
        DeckLayouts     = $deckProfile
        DeckLayoutsPath = $deckProf
        Branding        = $branding
        BrandingPath    = $brandFile
        BrandingDir     = $brandingDirR
        PaletteRoles    = $roles
        Identity        = $identity
        OtherIdentities = $others.ToArray()
        RtoCode         = [string](Get-RtoProp -Object $branding -Path 'rto.rtoCode')
        CricosCode      = [string](Get-RtoProp -Object $branding -Path 'rto.cricosCode')
        NoNotesReasons  = $pack.noNotesReasons
        NoNotesLayouts  = @(Get-RtoProp -Object $deckProfile -Path 'deckRules.notesNotRequiredOn')
        ImageFraming    = $pack.imageFraming
        Terminology     = $pack.lockedTerminology
        DocumentControl = $pack.documentControl
        CarveOuts       = @($pack.carveOuts)
        Schema          = $schema
        Raw             = $pack
        RoleProblems    = $roleProblems
    }

    if (-not $SkipValidation) {
        $v = Assert-RtoProfile -Profile $out
        if (-not $v.Ok) {
            throw ("The RTO profile pack for '{0}' does not validate:{1}{2}{1}Fix the pack, or build it - it is validated once per RTO, not once per build." -f `
                   $pack.rto, [Environment]::NewLine, (($v.Problems | ForEach-Object { "  - $_" }) -join [Environment]::NewLine))
        }
    }

    return $out
}

function Assert-RtoProfile {
    <#  The Stage S0-RTO gate. Returns .Ok and .Problems.

        Every check-set here is DERIVED from the schema: the required keys, the
        closed palette role enum and its aliases, and the identity fields. Add a
        key to a pack and it is unvalidated until the schema names it, which is
        the point - the validator and the specification are one file apart, not
        two lists apart. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Profile)

    $p = @()
    $pack   = $Profile.Raw
    $schema = $Profile.Schema

    # ---- required keys
    $required = @($schema.requiredKeys)
    foreach ($k in $required) {
        $v = Get-RtoProp -Object $pack -Path $k
        $empty = ($null -eq $v)
        if (-not $empty -and ($v -is [string]) -and -not "$v".Trim()) { $empty = $true }
        if (-not $empty -and ($v -is [array]) -and -not @($v).Count)  { $empty = $true }
        if ($empty) { $p += "required key '$k' is missing or empty (schema says: $($schema.keyReasons.$k))" }
    }

    # ---- the approved templates
    foreach ($t in @(@{ N = 'Learner Guide'; V = $Profile.GuideTemplate }, @{ N = 'deck'; V = $Profile.DeckTemplate })) {
        if (-not $t.V -or -not (Test-Path -LiteralPath $t.V)) {
            $p += ("the approved {0} template is not at '{1}'. A brand with no approved guide template and no deck template cannot be built - ask the RTO for one rather than generating it." -f $t.N, $t.V)
        }
    }

    # ---- the files it points at
    if ($null -eq $Profile.GuideProfile) { $p += "the guide profile named at '$($Profile.GuideProfilePath)' does not load" }
    if ($null -eq $Profile.DeckLayouts)  { $p += "the deck profile named at '$($Profile.DeckLayoutsPath)' does not load" }
    if ($null -eq $Profile.Branding)     { $p += "the branding profile named at '$($Profile.BrandingPath)' does not load" }
    elseif ("$($Profile.Branding.brand)" -ne "$($Profile.Rto)") {
        $p += ("the pack declares RTO '{0}' but the branding profile at '{1}' declares brand '{2}'. A pack and the identity it claims must be the same RTO." -f `
               $Profile.Rto, $Profile.BrandingPath, $Profile.Branding.brand)
    }

    # ---- palette: total over the closed enum, and no accidental collision
    foreach ($rp in $Profile.RoleProblems) { $p += $rp }
    foreach ($k in @($Profile.PaletteRoles.Keys)) {
        if ("$($Profile.PaletteRoles[$k])" -notmatch '^[0-9A-Fa-f]{6}$') {
            $p += ("palette role '{0}' resolves to '{1}', which is not a six-digit hex" -f $k, $Profile.PaletteRoles[$k])
        }
    }

    # ---- identity: required fields present, and unique across brands
    foreach ($f in @($schema.identityFields.required)) {
        if (-not $Profile.Identity.Contains($f) -or -not "$($Profile.Identity[$f])".Trim()) {
            $p += "identity field '$f' is missing from $($Profile.BrandingPath). The crossover sweep derives its forbidden set from these fields; a field nothing carries is a string nothing forbids."
        }
    }
    foreach ($o in $Profile.OtherIdentities) {
        foreach ($f in @($o.Identity.Keys)) {
            $mine = "$($Profile.Identity[$f])".Trim()
            if (-not $mine) { continue }
            if ($mine -and "$($o.Identity[$f])".Trim() -eq $mine -and $mine.Length -ge 4) {
                $p += ("identity field '{0}' has the same value ('{1}') in this RTO and in brand '{2}'. The crossover sweep cannot tell two brands apart on a string they share." -f $f, $mine, $o.Brand)
            }
        }
    }

    # ---- the no-notes exemptions and their written reasons must match exactly
    $listed  = @($Profile.NoNotesLayouts | Where-Object { $_ })
    $reasons = @()
    if ($Profile.NoNotesReasons) {
        $reasons = @($Profile.NoNotesReasons.PSObject.Properties | Where-Object { $_.Name -notlike '_*' } | ForEach-Object { $_.Name })
    }
    foreach ($n in $listed) {
        if ($reasons -notcontains $n) {
            $p += ("the deck profile exempts '{0}' from the speaker-notes rule and this pack gives no reason for it. Speaker notes are a shipped deck rule, and this list is the only place it can be switched off - an exemption with no written reason is a rule turned off where no audit would see it." -f $n)
        }
    }
    foreach ($n in $reasons) {
        if ($listed -notcontains $n) {
            $p += ("this pack carries a no-notes reason for '{0}', which the deck profile does not exempt. A stale allow-list entry is evidence for a decision nobody made." -f $n)
        }
        else {
            $why = "$($Profile.NoNotesReasons.$n)".Trim()
            if ($why.Length -lt 20) { $p += "the no-notes reason for '$n' is too short to audit: '$why'" }
        }
    }
    $needNotes = @(Get-RtoProp -Object $Profile.DeckLayouts -Path 'deckRules.notesRequiredOn')
    foreach ($n in $listed) {
        if ($needNotes -contains $n) {
            $p += ("'{0}' is on BOTH the notes-required and the no-notes list. The exemption list may never switch off the rule for a slide kind that teaches." -f $n)
        }
    }

    # ---- carve-outs carry a scope and a reason
    $i = 0
    foreach ($c in $Profile.CarveOuts) {
        $i++
        if (-not "$($c.rule)".Trim())   { $p += "carve-out $i names no rule" }
        if (-not "$($c.scope)".Trim())  { $p += "carve-out $i ('$($c.rule)') has no scope. A carve-out with no scope is a rule switched off everywhere." }
        if ("$($c.reason)".Trim().Length -lt 20) { $p += "carve-out $i ('$($c.rule)') has no written reason a reader can audit" }
    }

    [pscustomobject]@{
        Ok       = ($p.Count -eq 0)
        Problems = $p
        Rto      = $Profile.Rto
        Version  = $Profile.ProfileVersion
    }
}

function Write-RtoProfileReport {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)] $Result, $Profile)
    process {
        Write-Host ''
        Write-Host ("RTO PROFILE PACK - {0} v{1}" -f $Result.Rto, $Result.Version) -ForegroundColor Cyan
        if ($Profile) {
            Write-Host ("  guide template : {0}" -f $Profile.GuideTemplate) -ForegroundColor DarkGray
            Write-Host ("  deck template  : {0}" -f $Profile.DeckTemplate)  -ForegroundColor DarkGray
            Write-Host ("  check-set: {0} palette role(s), derived from the closed enum in {1}" -f `
                        @($Profile.PaletteRoles.Keys).Count, (Split-Path $Profile.SchemaPath -Leaf)) -ForegroundColor DarkGray
            Write-Host ("  check-set: {0} identity field(s) for this brand and {1} other brand profile(s), derived from {2}" -f `
                        @($Profile.Identity.Keys).Count, @($Profile.OtherIdentities).Count, $Profile.BrandingDir) -ForegroundColor DarkGray
            Write-Host ("  no-notes exemptions: {0}, every one with a written reason" -f @($Profile.NoNotesLayouts).Count) -ForegroundColor DarkGray
            Write-Host ("  carve-outs: {0}, surfaced to Stage 6 as evidence" -f @($Profile.CarveOuts).Count) -ForegroundColor DarkGray
        }
        foreach ($x in $Result.Problems) { Write-Host "  X  $x" -ForegroundColor Red }
        if ($Result.Ok) { Write-Host '  PASS' -ForegroundColor Green }
        else            { Write-Host ("  FAIL - {0} problem(s)" -f $Result.Problems.Count) -ForegroundColor Red }
        Write-Host ''
    }
}

if ($Check) {
    if (-not $Rto) { Write-Host 'Get-RtoProfile.ps1 -Check needs -Rto <brand key>.' -ForegroundColor Red; exit 2 }
    $prof = Get-RtoProfile -Rto "$Rto" -SkillDir $SkillPath -BrandingDir $BrandingPath -SkipValidation
    $res  = Assert-RtoProfile -Profile $prof
    if (-not $Quiet) { Write-RtoProfileReport -Result $res -Profile $prof }
    if (-not $res.Ok) { exit 1 }
    exit 0
}
