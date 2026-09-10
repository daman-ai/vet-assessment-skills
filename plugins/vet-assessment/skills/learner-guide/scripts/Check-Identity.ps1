<#
    Check-Identity.ps1 - prove, on the FINISHED files, that the brand swap
    landed and that no other brand survives anywhere in either package.

    Implements the gate the design calls Assert-BrandCrossover. Runs at Stage 4c
    (apply and prove the mark), again at 7c after placement, and again at Stage 8
    before delivery.

    WHY A TEXT SWEEP OF THE BODY IS NOT ENOUGH. The cover lock-up, the running
    head and the footer live in different parts; the mark itself is an image no
    text sweep can see; and a deck keeps its identity in slides, masters,
    layouts, notes, theme and rels. So this reads the cover (or the title slide)
    back and then sweeps EVERY text-bearing part of EVERY delivered artefact.

    THE FORBIDDEN SET IS DERIVED, NEVER TYPED. This is the defect this gate
    exists for. The sweep it replaces hand-listed three of the nine palette
    hexes the swap moves - navy, accent and rule - and simply did not carry the
    light fill or either border. So when a library defect left 608 of another
    brand's light fills in the guide and 158 in the deck, it printed "no
    crossover" over the top of them and the report repeated it. A gate that
    checks a hand-picked subset of what it claims to check is worse than no
    gate, because it is believed.

    So the hexes come from THE SAME ROLE MAP THE SWAP APPLIES - every hex that
    map moves, and only those, because a hex both brands share is not a
    crossover and flagging it would train the reader to ignore the sweep. The
    identity strings come from every OTHER brand profile on disk and from every
    other variant of this brand, minus every string this brand and variant
    legitimately carry. Nothing in this file is a literal from any brand.

    IT ALSO RAN ON ONE PACKAGE AND CLAIMED TWO. The sweep this replaces was
    written for the guide and only ever run on the guide, so the deck - which
    had its own un-swapped fills - was never swept at all, and the delivery
    report's claim about "every part of both packages" was true of one. This
    takes a LIST of artefacts, asserts it ran on every one, and prints the
    counts of what it checked and what it found.

    TRUSTED ONLY AFTER FAILING ON A PLANTED DEFECT. Run with -SelfTest and the
    scanner is handed a copy of a real part with a forbidden token planted in
    it; the plant is verified to have landed before the scan, and the gate fails
    if the scan does not find it. The build this was promoted from planted a
    defect that was a no-op, proved nothing, and passed.

    PS 5.1. ASCII only in this file.
    Exit 1 crossover found, 3 the build brand is absent, 4 the self-test failed,
    2 a usage error or an empty check-set.

    ARMS (Lib-GateCommon roster). identity-strings, palette-hexes and artefacts
    are BLOCKING: each ends ran (size > 0), empty (a refusal, exit 2, naming
    the input) or declared-n-a with a written reason from contract.json
    gateArms. The check-set lines print on every run, quiet or not - a blocking
    check-set computed only when the gate is talkative is one that never fires
    in a band that runs every member quiet.
#>

# GATE: stages=4,7c; requires=Path,BuildDir

[CmdletBinding()]
param(
    #  EVERY delivered artefact. A stage cannot pass unless this ran on all of
    #  them, which is why they are passed together rather than one per call.
    [string[]] $Path,
    [string] $BuildDir,
    [string] $Brand,
    [string] $Variant,
    [string] $SkillDir,
    [string] $BrandingDir,
    [switch] $SelfTest,
    [switch] $Quiet
)

#  -Path was Mandatory, so -SelfTest could never be run on its own: PowerShell
#  refused the call before the script started. The gate this skill says is
#  "trusted only after failing on a planted defect" could not be asked to
#  prove itself, and a fixtures sweep scored it inconclusive for that reason.
#  It is enforced here instead, so a real run still FAILS naming the input.
if (-not $SelfTest -and @($Path | Where-Object { "$_".Trim() }).Count -eq 0) {
    Write-Host '  X Check-Identity: -Path is required. Pass every delivered artefact in ONE call.' -ForegroundColor Red
    Write-Host '    A stage cannot pass having run this on one artefact and not the other.' -ForegroundColor Yellow
    exit 2
}

#  $PSScriptRoot is EMPTY inside a PARAMETER DEFAULT when the script is run as
#  `powershell -File`, so a default that called Split-Path on it threw inside
#  the parameter block: the script exited 1 having never run a single check -
#  the same exit code it uses for a real finding, which is why nobody noticed.
#  Resolved here instead, where the automatic variable is populated, with a
#  guarded fallback for the scriptblock case.
if (-not $SkillDir) {
    $__here = $PSScriptRoot
    if (-not $__here -and $MyInvocation.MyCommand.Path) { $__here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if ($__here) { $SkillDir = Split-Path -Parent $__here }
}

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')
. (Join-Path $SkillDir 'scripts\Lib-Resolve.ps1')
. (Join-Path $SkillDir 'scripts\Set-ResourceBrand.ps1')

$GATE = 'Check-Identity'

# ---------------------------------------------------------------------------
# 1. Which brand is this build, from the contract - never from a literal
# ---------------------------------------------------------------------------

if (-not $Brand -and $BuildDir) {
    $contract = Get-GateContract -BuildDir $BuildDir
    if ($null -ne $contract) {
        $Brand = [string](Get-GateProp -Object $contract.build -Names @('brand'))
        if (-not $Variant) { $Variant = [string](Get-GateProp -Object $contract.build -Names @('variant')) }
    }
}
#  A SELF-TEST proves the gate on a fixture it builds itself, so it needs A
#  brand, not THE brand. Take the first branding profile on disk and say which,
#  so the gate can always be asked to prove itself. A REAL run still refuses
#  below: a crossover sweep that does not know which brand it is proving cannot
#  derive what is forbidden.
if ($SelfTest -and -not $Brand) {
    foreach ($d in @($BrandingDir, (Join-Path $SkillDir 'assets'), (Join-Path (Split-Path -Parent $SkillDir) 'assessment\assets'))) {
        if (-not "$d".Trim() -or -not (Test-Path -LiteralPath "$d")) { continue }
        $bf = @(Get-ChildItem -LiteralPath "$d" -Filter 'branding.*.json' -File -ErrorAction SilentlyContinue | Sort-Object Name)
        if ($bf.Count -gt 0) {
            $Brand = ($bf[0].BaseName -split '\.')[1]
            Write-Host ("  self-test: no -Brand given; proving against '{0}', the first branding profile in {1}" -f $Brand, $d) -ForegroundColor DarkGray
            break
        }
    }
}
if (-not $Brand) {
    throw "$GATE`: no brand. Pass -Brand, or -BuildDir so the contract can supply it. A crossover sweep that does not know which brand it is proving cannot derive what is forbidden."
}

$branding = Get-Branding -Brand $Brand
$palette = Set-HousePalette -Brand $Brand -Variant $Variant
if (-not $Variant -and $branding.PSObject.Properties.Name -contains 'variants' -and $branding.variants) {
    $Variant = [string]$branding.variants.default
}

if (-not $BrandingDir) {
    #  $script:SkillRoot is set by the shared library when it loads, and points
    #  at the skill that owns the branding profiles.
    if ($script:SkillRoot) { $BrandingDir = Join-Path $script:SkillRoot 'assets' }
}
if (-not $BrandingDir -or -not (Test-Path -LiteralPath $BrandingDir)) {
    throw "$GATE`: cannot locate the branding profiles. Pass -BrandingDir. The forbidden set is DERIVED from every brand profile on disk; a sweep that cannot read them would have to fall back on typed literals, which is the defect this gate exists to end."
}

# ---------------------------------------------------------------------------
# 2. Derive the forbidden set
# ---------------------------------------------------------------------------

function Get-IdentityFieldName {
    <#  THE IDENTITY FIELD NAMES, READ OFF THE SCHEMA THAT DECLARES THEM.

        assets\rto-profile.schema.json holds identityFields - the buckets
        (required, optional) whose members are every identity string a
        delivered artefact can carry, and therefore every string another
        brand's profile makes forbidden in this one. Lib-RtoProfile derives
        the same set from the same place, so the validator and this sweep
        cannot disagree about what an identity string IS.

        The buckets are ENUMERATED rather than named one by one: a bucket
        added to the schema is swept here without editing this file. A list of
        field names typed into a gate is a second source of truth, and three of
        nine palette hexes typed by hand is how a sweep printed "no crossover"
        over 766 live occurrences.

        Returns All (every bucket, de-duplicated, in schema order), Required
        (the bucket a package must actually CARRY) and Path.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $SchemaPath)

    $schema = Get-GateJson -Path $SchemaPath
    if ($null -eq $schema) {
        throw ("$GATE`: no RTO profile schema at {0}. The identity field names are DERIVED from its identityFields declaration; a gate that fell back on its own typed list would be free to drift from the validator that uses the schema." -f $SchemaPath)
    }
    $decl = Get-GateProp -Object $schema -Names @('identityFields') -Required -What 'identity field list (identityFields)'
    $all = New-Object System.Collections.Generic.List[string]
    foreach ($bucket in @($decl.PSObject.Properties)) {
        if ($bucket.Name -like '_*') { continue }
        foreach ($n in @($bucket.Value)) {
            $nm = "$n".Trim()
            if ($nm -and -not $all.Contains($nm)) { $all.Add($nm) }
        }
    }
    $req = New-Object System.Collections.Generic.List[string]
    foreach ($n in @(Get-GateProp -Object $decl -Names @('required') -Required -What 'required identity field list (identityFields.required)')) {
        $nm = "$n".Trim()
        if ($nm -and -not $req.Contains($nm)) { $req.Add($nm) }
    }
    return [pscustomobject]@{ All = $all.ToArray(); Required = $req.ToArray(); Path = $SchemaPath }
}

$schemaPath = Join-Path $SkillDir 'assets\rto-profile.schema.json'
$idFields = Get-IdentityFieldName -SchemaPath $schemaPath

#  THE MARKS A DELIVERED ARTEFACT ACTUALLY PRINTS - the trading name and the
#  two provider codes, which is what a cover, a running head, a footer and a
#  title slide carry. A package free of every brand is a swap that never ran,
#  and this is the set that proves it did.
#
#  THIS IS NOT identityFields.required AND MUST NOT BE DERIVED FROM IT. That
#  bucket declares what a BRANDING PROFILE must contain for the pack to
#  validate; it is not a claim about what a document prints. It carries
#  legalEntity, whose value for this brand is a Pty Ltd trading-as name that
#  appears in no delivered guide and on no slide. Deriving this set from it was
#  tried on 10 September 2026 and this gate's own self-test failed at exit 3 -
#  "this package does not carry the build brand at all" - over a deck
#  Set-DeckBrand had just normalised correctly. No file on disk carries the
#  set "identity strings a delivered artefact must print", so this one is the
#  gate's own, and it is recorded as a refutation against GH02 in
#  assets\gate-hygiene.reclassified.json rather than derived from a set that
#  means something else.
$presenceFields = @('tradingName', 'rtoCode', 'cricosCode')

function Get-IdentityString {
    <#  Every identity string an object carries, under any of the known names.
        The names come from the schema (see Get-IdentityFieldName), never from
        a list typed here.  #>
    param($Rto)
    $out = New-Object System.Collections.Generic.List[string]
    if ($null -eq $Rto) { return $out }
    foreach ($n in $idFields.All) {
        $v = Get-GateProp -Object $Rto -Names @($n)
        if ($v -and "$v".Trim().Length -ge 4) { $out.Add("$v".Trim()) }
    }
    #  A website is also a bare domain in a rels target and in a footer, so both
    #  forms are forbidden. A swap that leaves the old domain in a hyperlink is
    #  a swap that did not finish.
    $w = Get-GateProp -Object $Rto -Names @('website', 'domain')
    if ($w) {
        $bare = ("$w" -replace '(?i)^https?://', '') -replace '(?i)^www\.', ''
        if ($bare.Length -ge 6) { $out.Add($bare) }
    }
    return $out
}

$mine = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($s in (Get-IdentityString -Rto $branding.rto)) { [void]$mine.Add($s) }
if ($Variant -and $branding.PSObject.Properties.Name -contains 'variants' -and $branding.variants.PSObject.Properties.Name -contains $Variant) {
    foreach ($s in (Get-IdentityString -Rto $branding.variants.$Variant)) { [void]$mine.Add($s) }
}

$forbidWords = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$profilesRead = 0
foreach ($pf in (Get-ChildItem -LiteralPath $BrandingDir -Filter 'branding.*.json' -File)) {
    $prof = Get-GateJson -Path $pf.FullName
    if ($null -eq $prof) { continue }
    $profilesRead++
    $isThisBrand = ([string]$prof.brand -eq $Brand)
    foreach ($s in (Get-IdentityString -Rto $prof.rto)) { if (-not $isThisBrand) { [void]$forbidWords.Add($s) } }
    if ($prof.PSObject.Properties.Name -contains 'variants' -and $prof.variants) {
        foreach ($vp in $prof.variants.PSObject.Properties) {
            if ($vp.Name -like '_*' -or $vp.Name -eq 'default') { continue }
            #  ANOTHER VARIANT OF THE SAME BRAND IS ALSO A CROSSOVER. One
            #  registered entity trading under two names still must not print
            #  the other trading name on this unit's cover.
            if ($isThisBrand -and $vp.Name -eq $Variant) { continue }
            foreach ($s in (Get-IdentityString -Rto $vp.Value)) { [void]$forbidWords.Add($s) }
        }
    }
}
$forbidWords.ExceptWith($mine)

#  THE HEXES COME FROM THE SAME ROLE MAP THE SWAP APPLIES, and only the pairs
#  that actually move. A role that maps to itself is either shared between the
#  brands or unresolved; the resolution gate at Stage 0 is what catches the
#  unresolved case, and flagging a shared role here would be noise.
$pairs = Get-BrandPalettePairs -Palette $palette
$forbidHex = @($pairs.Keys | Where-Object { [string]$pairs[$_] -ne [string]$_ })

# Carve-outs, declared with a reason - never typed into this gate.
$carve = @{}
if ($BuildDir) {
    $contract = Get-GateContract -BuildDir $BuildDir
    if ($null -ne $contract -and @($contract.PSObject.Properties.Name) -contains 'brandCrossover') {
        $carve = Get-GateAllowList -Registry $contract.brandCrossover -Key 'carveOut' -IdField @('token', 'hex', 'text') -GateName $GATE
    }
}
if (@($branding.PSObject.Properties.Name) -contains 'crossoverCarveOut') {
    foreach ($k in (Get-GateAllowList -Registry $branding -Key 'crossoverCarveOut' -IdField @('token', 'hex', 'text') -GateName $GATE).GetEnumerator()) {
        $carve[$k.Key] = $k.Value
    }
}

$tokens = New-Object System.Collections.Generic.List[string]
foreach ($t in $forbidWords) { if (-not $carve.ContainsKey($t)) { $tokens.Add($t) } }
foreach ($t in $forbidHex)   { if (-not $carve.ContainsKey($t)) { $tokens.Add($t) } }

if (-not $Quiet) {
    Write-Host ''
    Write-Host 'CROSSOVER SWEEP - no other brand may appear anywhere' -ForegroundColor Cyan
    Write-Host ("  build brand: {0}{1}" -f $Brand, $(if ($Variant) { " / $Variant" } else { '' })) -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# The arm roster. Registered before anything is swept, so an arm that never
# completes is visible as not-run rather than absent. The two derived sets are
# blocking SEPARATELY: the sweep this replaces carried three of nine hexes and
# printed "no crossover" over 766 live occurrences, and a combined count would
# let a full word list hide an empty hex list.
# ---------------------------------------------------------------------------

$ciNa = @{}
try {
    foreach ($arm in @('identity-strings', 'palette-hexes')) {
        if ($BuildDir) {
            $r = Get-GateDeclaredNa -BuildDir $BuildDir -Gate $GATE -Arm $arm
            if ($r) { $ciNa[$arm] = $r }
        }
    }
}
catch { Write-Host ("  X {0}: {1}" -f $GATE, $_.Exception.Message) -ForegroundColor Red; exit 2 }

Reset-GateArmRoster
Register-GateArm -Name 'identity-strings' -Blocking:(-not $ciNa.ContainsKey('identity-strings'))
Register-GateArm -Name 'palette-hexes' -Blocking:(-not $ciNa.ContainsKey('palette-hexes'))
Register-GateArm -Name 'artefacts' -Blocking

try {
    #  BOTH DERIVED SETS SAY WHERE THEY CAME FROM AND HOW BIG THEY ARE, and
    #  they print on every run, quiet or not. The field names below are what
    #  the word half of this sweep reads out of every profile on disk, and the
    #  required half is what every delivered package must still carry: a hex
    #  or a field name typed into a gate is the second source of truth that
    #  printed "no crossover" over 766 live occurrences.
    Write-GateCheckSet -What 'identity field name(s) read from every brand profile' -Count @($idFields.All).Count -DerivedFrom ('identityFields in ' + (Split-Path -Leaf $idFields.Path)) -Blocking -Input ($idFields.Path + ' - identityFields declares no field name, so every profile on disk would be read for nothing and the forbidden word set would be empty')
    Write-GateCheckSet -What 'identity field(s) every delivered package must PRINT' -Count @($presenceFields).Count -DerivedFrom "this gate's own cover/footer identity set - see the note at its declaration for why it is NOT identityFields.required" -Blocking -Input 'the presence set: with no field in it a package could be free of every brand and still pass, which is a swap that never ran'
    if ($ciNa.ContainsKey('identity-strings')) { Complete-GateArm -Name 'identity-strings' -State 'declared-n-a' -Reason $ciNa['identity-strings'] }
    else {
        Write-GateCheckSet -What 'identity strings' -Count $forbidWords.Count -DerivedFrom ("{0} brand profile(s) in {1}, minus every string this brand carries" -f $profilesRead, (Split-Path $BrandingDir -Leaf)) -Blocking -Input ('the brand profiles under {0}: no OTHER brand''s identity string could be derived, so the word half of this sweep would examine nothing' -f $BrandingDir)
        Complete-GateArm -Name 'identity-strings' -State 'ran' -Size $forbidWords.Count
    }
    if ($ciNa.ContainsKey('palette-hexes')) { Complete-GateArm -Name 'palette-hexes' -State 'declared-n-a' -Reason $ciNa['palette-hexes'] }
    else {
        Write-GateCheckSet -What 'palette hexes' -Count $forbidHex.Count -DerivedFrom 'the resolved role map the swap itself applies (only the roles that move)' -Blocking -Input 'the resolved palette role map: not one role moves, so the hex half of this sweep would examine nothing - this is the exact shape that printed "no crossover" over 766 live fills'
        Complete-GateArm -Name 'palette-hexes' -State 'ran' -Size $forbidHex.Count
    }
}
catch {
    $msg = $_.Exception.Message
    if ($msg -match '^(CHECK-SET EMPTY|ARMS INCOMPLETE)') {
        Write-Host ("  X {0} REFUSED - {1}" -f $GATE, $msg) -ForegroundColor Red
        [void](Write-GateArmRoster)
        exit 2
    }
    Write-Host ("  X {0}: {1}" -f $GATE, $msg) -ForegroundColor Red
    exit 1
}

if (-not $Quiet) {
    foreach ($k in ($carve.Keys | Sort-Object)) {
        Write-Host ("  carve-out '{0}': {1}" -f $k, $carve[$k]) -ForegroundColor DarkGray
    }
}

if ($tokens.Count -eq 0) {
    Write-Host ("  X {0}: the forbidden set is empty, so this sweep would pass by having nothing to check." -f $GATE) -ForegroundColor Red
    [void](Write-GateArmRoster)
    exit 2
}

# ---------------------------------------------------------------------------
# 3. Scan
# ---------------------------------------------------------------------------

function Get-PackagePart {
    <#  Every text-bearing part of an OPC package, as name -> xml.

        .rels PARTS ARE INCLUDED, and that is an addition. The identity swap
        rewrites hyperlink targets, which live in .rels and not in any .xml, so
        a sweep filtered to *.xml can report a clean package that still links to
        the other brand's website.  #>
    param([Parameter(Mandatory)][string] $WorkDir)
    $out = [ordered]@{}
    foreach ($f in (Get-ChildItem -LiteralPath $WorkDir -Recurse -File | Where-Object { $_.Extension -in @('.xml', '.rels') })) {
        $rel = $f.FullName.Substring($WorkDir.Length).TrimStart('\') -replace '\\', '/'
        $out[$rel] = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    }
    return $out
}

function Invoke-CrossoverScan {
    <# Count every forbidden token in every part. Returns the hit list. #>
    param(
        [Parameter(Mandatory)] $Parts,
        [Parameter(Mandatory)][string[]] $Tokens
    )
    $hits = New-Object System.Collections.Generic.List[object]
    foreach ($name in $Parts.Keys) {
        $xml = $Parts[$name]
        foreach ($tok in $Tokens) {
            $n = ([regex]::Matches($xml, [regex]::Escape($tok), 'IgnoreCase')).Count
            if ($n -gt 0) { $hits.Add([pscustomobject]@{ Part = $name; Token = $tok; Count = $n }) }
        }
    }
    return $hits
}

$totalHits = 0
$absentBrand = 0
$selfTestFailed = 0
$artefactsScanned = 0

foreach ($file in $Path) {
    if (-not (Test-Path -LiteralPath $file)) { throw "$GATE`: artefact not found: $file" }
    $leaf = Split-Path $file -Leaf
    $isDeck = ($file -match '(?i)\.pptx$')

    $w = Expand-Docx -Path $file
    try {
        $parts = Get-PackagePart -WorkDir $w
        $artefactsScanned++

        Write-Host ''
        Write-Host ("  {0} - {1} text-bearing part(s)" -f $leaf, $parts.Count) -ForegroundColor Cyan

        # --- the cover, or the title slide, read back
        if (-not $Quiet) {
            $coverPart = if ($isDeck) { 'ppt/slides/slide1.xml' } else { 'word/document.xml' }
            if ($parts.Contains($coverPart)) {
                $tagRx = if ($isDeck) { '<a:t[^>]*>([^<]*)</a:t>' } else { '<w:t[^>]*>([^<]*)</w:t>' }
                $shown = 0
                foreach ($m in [regex]::Matches($parts[$coverPart], $tagRx)) {
                    $t = [System.Net.WebUtility]::HtmlDecode($m.Groups[1].Value).Trim()
                    if (-not $t) { continue }
                    $shown++
                    if ($shown -gt 12) { break }
                    Write-Host ("    cover: {0}" -f $t) -ForegroundColor DarkGray
                }
            }
        }

        # --- the sweep
        $hits = Invoke-CrossoverScan -Parts $parts -Tokens $tokens.ToArray()
        if ($hits.Count -eq 0) {
            Write-Host ("    no crossover: {0} token(s) checked in {1} part(s), 0 found" -f $tokens.Count, $parts.Count) -ForegroundColor Green
        }
        else {
            foreach ($h in $hits) {
                Write-Host ("    X {0}: '{1}' x{2}" -f $h.Part, $h.Token, $h.Count) -ForegroundColor Red
            }
            Write-Host ("    {0} crossover hit(s) in {1}" -f $hits.Count, $leaf) -ForegroundColor Red
            $totalHits += $hits.Count
        }

        # --- THIS brand, where it must be. A package can be free of the other
        #     brand by being free of every brand: that is a swap that never ran.
        $wanted = @()
        foreach ($n in $presenceFields) {
            $v = $null
            if ($Variant -and $branding.variants -and $branding.variants.PSObject.Properties.Name -contains $Variant) {
                $v = Get-GateProp -Object $branding.variants.$Variant -Names @($n)
            }
            if (-not $v) { $v = Get-GateProp -Object $branding.rto -Names @($n) }
            if ($v) { $wanted += "$v" }
        }
        foreach ($tok in $wanted) {
            $n = 0
            foreach ($name in $parts.Keys) { $n += ([regex]::Matches($parts[$name], [regex]::Escape($tok), 'IgnoreCase')).Count }
            if ($n -gt 0) { Write-Host ("    {0}: x{1}" -f $tok, $n) -ForegroundColor Green }
            else {
                Write-Host ("    X {0}: NOT PRESENT - this package does not carry the build brand at all" -f $tok) -ForegroundColor Red
                $absentBrand++
            }
        }

        # --- the planted defect
        if ($SelfTest) {
            $plantToken = $tokens[0]
            $victim = @($parts.Keys)[0]
            $clone = [ordered]@{}
            foreach ($k in $parts.Keys) { $clone[$k] = $parts[$k] }
            $clone[$victim] = $clone[$victim] + ("<!-- planted {0} -->" -f $plantToken)
            if ($clone[$victim].IndexOf($plantToken, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
                Write-Host "    X self-test: the plant did not land, so this proves nothing." -ForegroundColor Red
                $selfTestFailed++
            }
            else {
                $found = Invoke-CrossoverScan -Parts $clone -Tokens @($plantToken)
                if ($found.Count -gt 0) {
                    Write-Host ("    self-test: planted '{0}' in {1}, scanner found it. This sweep can fail." -f $plantToken, $victim) -ForegroundColor Green
                }
                else {
                    Write-Host ("    X self-test: planted '{0}' in {1} and the scanner did NOT find it." -f $plantToken, $victim) -ForegroundColor Red
                    $selfTestFailed++
                }
            }
        }
    }
    finally {
        if ($w -and (Test-Path -LiteralPath $w) -and $w.Length -gt 12) {
            Remove-Item -LiteralPath $w -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host ''
#  STANDALONE SELF-TEST. The plant inside the artefact loop augments a real
#  sweep and needs a document; with no -Path that loop never runs, so the gate
#  could not be asked to prove itself at all - and a gate this skill calls
#  "trusted only after failing on a planted defect" that cannot be asked is
#  the same silent gap as a rule behind an optional parameter. The scanner
#  works on a parts hashtable, so the fixture is built here rather than
#  requiring a real .docx: same scanner, same token set, no Office.
if ($SelfTest -and @($Path | Where-Object { "$_".Trim() }).Count -eq 0) {
    $stFail = 0
    if (@($tokens).Count -eq 0) {
        Write-Host '  X self-test: no forbidden tokens were derived, so a plant would prove nothing.' -ForegroundColor Red
        $stFail++
    }
    else {
        $tok = @($tokens)[0]
        $clean = [ordered]@{ 'word/document.xml' = '<w:p><w:t>ordinary body text with no other brand in it</w:t></w:p>' }
        $none = Invoke-CrossoverScan -Parts $clean -Tokens @($tok)
        if (@($none).Count -eq 0) { Write-Host '  self-test: clean fixture is silent' -ForegroundColor Green }
        else { Write-Host '  X self-test: the scanner fired on a fixture carrying no forbidden token.' -ForegroundColor Red; $stFail++ }
        $planted = [ordered]@{ 'word/document.xml' = ($clean['word/document.xml'] + ("<w:p><w:t>{0}</w:t></w:p>" -f $tok)) }
        if ($planted['word/document.xml'].IndexOf($tok, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
            Write-Host '  X self-test: the plant did not land, so this proves nothing.' -ForegroundColor Red
            $stFail++
        }
        else {
            $hit = Invoke-CrossoverScan -Parts $planted -Tokens @($tok)
            if (@($hit).Count -gt 0) { Write-Host ("  self-test: planted '{0}' and the scanner found it. This sweep can fail." -f $tok) -ForegroundColor Green }
            else { Write-Host ("  X self-test: planted '{0}' and the scanner did NOT find it." -f $tok) -ForegroundColor Red; $stFail++ }
        }
    }
    #  THE STARVED ARM, proved through the EXIT CODE a runner reads. A branding
    #  directory holding only THIS brand's own profile derives no other brand's
    #  identity strings, so the word half of the sweep has nothing to look for.
    #  That is exit 2 naming the directory, never the green "no crossover" line
    #  this gate's predecessor printed over 766 live fills.
    $stRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ci-selftest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    try {
        New-Item -ItemType Directory -Force -Path $stRoot | Out-Null
        $own = Get-ChildItem -LiteralPath $BrandingDir -Filter ('branding.' + $Brand + '.json') -File -ErrorAction SilentlyContinue
        if (@($own).Count -eq 1) {
            #  Copy THIS brand's profile and strip its variants: another
            #  variant of the same brand is itself a crossover, so a profile
            #  that keeps them still derives a non-empty word set and would
            #  not starve the arm.
            $stProf = Get-GateJson -Path $own[0].FullName
            if (@($stProf.PSObject.Properties.Name) -contains 'variants') { $stProf.PSObject.Properties.Remove('variants') }
            [System.IO.File]::WriteAllText((Join-Path $stRoot $own[0].Name), ($stProf | ConvertTo-Json -Depth 40), (New-Object System.Text.UTF8Encoding($true)))
            $left = @(Get-ChildItem -LiteralPath $stRoot -Filter 'branding.*.json' -File)
            $backProf = Get-GateJson -Path (Join-Path $stRoot $own[0].Name)
            if ($left.Count -ne 1 -or (@($backProf.PSObject.Properties.Name) -contains 'variants')) { Write-Host '  X self-test: the starved branding fixture did not land.' -ForegroundColor Red; $stFail++ }
            else {
                $out = ''
                try { $out = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath -Path (Join-Path $stRoot 'nothing.docx') -Brand $Brand -BrandingDir $stRoot -SkillDir $SkillDir 2>&1 | Out-String -Width 4096) }
                catch { $out = "$($_.Exception.Message)" }
                $code = $LASTEXITCODE
                if ($code -eq 2 -and $out -match 'CHECK-SET EMPTY' -and $out.IndexOf($stRoot, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    Write-Host '  self-test: a branding directory holding only this brand exits 2 naming the directory (the identity-strings arm is starved, not silent)' -ForegroundColor Green
                }
                else {
                    Write-Host ("  X self-test: the starved identity-strings arm exited {0} (wanted 2 naming the branding directory)" -f $code) -ForegroundColor Red
                    foreach ($ln in @(($out -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -Last 4)) { Write-Host ("      | {0}" -f $ln) -ForegroundColor DarkGray }
                    $stFail++
                }
            }
        }
        else {
            Write-Host ("  X self-test: no branding.{0}.json in {1}, so the starved-arm case could not be built - it proves nothing and is a failure, not a skip." -f $Brand, $BrandingDir) -ForegroundColor Red
            $stFail++
        }
    }
    finally { if ($stRoot -and (Test-Path -LiteralPath $stRoot)) { Remove-Item -LiteralPath $stRoot -Recurse -Force -ErrorAction SilentlyContinue } }

    #  THE CLEAN CONTROL: the real branding directory yields both blocking
    #  derived sets, and the roster says so.
    $rosterLine = ''
    foreach ($a in @(Get-GateArmRoster)) {
        if ($a.Blocking -and $a.Name -ne 'artefacts' -and $a.State -ne 'ran') {
            Write-Host ("  X self-test: blocking arm '{0}' ended '{1}' on the real branding set" -f $a.Name, $a.State) -ForegroundColor Red
            $stFail++
        }
        $rosterLine += ('{0}={1}/{2} ' -f $a.Name, $a.State, $a.Size)
    }
    if ($stFail -eq 0) { Write-Host ("  self-test: both derived sets ran on the real branding directory - {0}" -f $rosterLine.Trim()) -ForegroundColor Green }

    Write-Host ''
    if ($stFail -eq 0) { Write-Host ("SELF-TEST PASS - the crossover scanner fails on a verified plant and refuses a starved arm by name ({0} token(s) in the check-set)" -f @($tokens).Count) -ForegroundColor Green; exit 0 }
    Write-Host ("SELF-TEST FAILED - {0} check(s)" -f $stFail) -ForegroundColor Red
    exit 4
}

try {
    Write-GateCheckSet -What 'delivered artefact(s) swept' -Count $artefactsScanned -DerivedFrom '-Path, every artefact the stage delivers, passed in ONE call' -Blocking -Input '-Path: not one supplied artefact could be opened and swept'
    Complete-GateArm -Name 'artefacts' -State 'ran' -Size $artefactsScanned -Findings $totalHits
    Assert-GateArmsComplete
    [void](Write-GateArmRoster)
}
catch {
    $msg = $_.Exception.Message
    if ($msg -match '^(CHECK-SET EMPTY|ARMS INCOMPLETE)') {
        Write-Host ("  X {0} REFUSED - {1}" -f $GATE, $msg) -ForegroundColor Red
        [void](Write-GateArmRoster)
        exit 2
    }
    Write-Host ("  X {0}: {1}" -f $GATE, $msg) -ForegroundColor Red
    exit 1
}
if ($artefactsScanned -ne @($Path).Count) {
    Write-Host ("  X not every supplied artefact was swept ({0} of {1}). A stage cannot pass on a partial sweep." -f $artefactsScanned, @($Path).Count) -ForegroundColor Red
    exit 2
}

if ($selfTestFailed -gt 0) { exit 4 }
if ($totalHits -gt 0) {
    Write-Host ("  X {0} crossover hit(s) across the delivery set" -f $totalHits) -ForegroundColor Red
    exit 1
}
if ($absentBrand -gt 0) {
    Write-Host '  X the build brand is missing from at least one package. Branding did not run, or did not finish.' -ForegroundColor Red
    exit 3
}
Write-Host '  no crossover anywhere in the delivery set, and every package carries the build brand' -ForegroundColor Green
exit 0
