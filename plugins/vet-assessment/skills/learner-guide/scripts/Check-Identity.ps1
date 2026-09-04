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
    2 a usage error.
#>

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

function Get-IdentityString {
    <# Every identity string an object carries, under any of the known names. #>
    param($Rto)
    $out = New-Object System.Collections.Generic.List[string]
    if ($null -eq $Rto) { return $out }
    foreach ($n in @('tradingName', 'legalEntity', 'rtoCode', 'cricosCode', 'website', 'domain', 'email', 'address', 'phone', 'shortName')) {
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
    Write-GateCheckSet -What 'identity strings' -Count $forbidWords.Count -DerivedFrom ("{0} brand profile(s) in {1}, minus every string this brand carries" -f $profilesRead, (Split-Path $BrandingDir -Leaf))
    Write-GateCheckSet -What 'palette hexes' -Count $forbidHex.Count -DerivedFrom 'the resolved role map the swap itself applies (only the roles that move)'
    foreach ($k in ($carve.Keys | Sort-Object)) {
        Write-Host ("  carve-out '{0}': {1}" -f $k, $carve[$k]) -ForegroundColor DarkGray
    }
}

if ($tokens.Count -eq 0) {
    Write-Host ("  X {0}: the forbidden set is empty, so this sweep would pass by having nothing to check." -f $GATE) -ForegroundColor Red
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
        foreach ($n in @('tradingName', 'rtoCode', 'cricosCode')) {
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
    Write-Host ''
    if ($stFail -eq 0) { Write-Host ("SELF-TEST PASS - the crossover scanner fails on a verified plant ({0} token(s) in the check-set)" -f @($tokens).Count) -ForegroundColor Green; exit 0 }
    Write-Host ("SELF-TEST FAILED - {0} check(s)" -f $stFail) -ForegroundColor Red
    exit 4
}

Write-Host ("  artefacts swept: {0} of {1} supplied" -f $artefactsScanned, @($Path).Count) -ForegroundColor DarkGray
if ($artefactsScanned -ne @($Path).Count) {
    Write-Host '  X not every supplied artefact was swept. A stage cannot pass on a partial sweep.' -ForegroundColor Red
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
