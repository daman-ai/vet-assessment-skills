<#
    Test-FigureConsistency.ps1  -  ONE FIGURE, ONE VALUE, EVERYWHERE.

    THE GATE THAT EXISTS BECAUSE SWEEPS FAIL. Three remediation rounds on one
    build each fixed the instance in front of the author and missed its
    siblings: round 1 fixed prose and left the diagram specs, round 2 fixed
    the guide and left the deck, round 3 fixed the literal string "20
    gastronorm" and missed "twenty gastronorm", "20-tray", "fit inside 20"
    and "6 of 20". A corrected figure lives in prose, a summary figure, a
    slide and an exemplar; nothing short of an enumerating check finds them
    all, and a literal-string check is not an enumerating check.

    So: rules live in a FIGURES REGISTRY (figures.json in the build dir), and
    this script enforces them across every source that can put a figure on a
    page - the spine, the build scripts, and any extracted document text
    handed to it. Matching is VARIANT-AWARE: every numeric token in a
    Forbid/assessorOnly string is automatically also matched as its English
    word form (and vice versa), and ForbidRx entries take full regexes for
    the shapes words cannot pin down.

    registry schema (figures.json):
      {
        "figures": [
          { "name":  "Beef cheek purchase chain",
            "forbid":   ["37.8", "$740"],          // stale values - none may survive
            "forbidRx": ["\\b6 of (10|20)\\b"],    // regex forbids
            "require":  ["35.5"] }                  // >=1 occurrence somewhere
        ],
        "assessorOnly": [                           // exists ONLY in the assessor guide
          { "text": "20 gastronorm", "why": "Task 10(c) benchmark" },
          { "rx": "...", "why": "..." }
        ],
        "deckMust": ["wastage", "2:00 pm"]          // deck text must carry these
      }

    Usage:
      Test-FigureConsistency -BuildDir <dir>                 # spine + *.ps1
      Test-FigureConsistency -BuildDir <dir> -DocText a.txt,b.txt   # also gate extracts
      Test-FigureConsistency -BuildDir <dir> -Stage 7c -DocText guide_gate.txt,deck_gate.txt
      Test-FigureConsistency -SelfTest
      exit 8 on failure. -Quiet suppresses the report.

    ABSENT INPUTS ARE REFUSED BY NAME, NEVER DROPPED. A -DocText path that does
    not exist used to be skipped silently (a rendered-arm run over nothing then
    printed PASS); it is now exit 2 naming the path. With -Stage 7c and no
    -DocText the rendered arm has nothing to sweep and exits 2 naming the two
    extracts it expected. Every arm is on the roster (Lib-GateCommon), so a
    blocking arm that examined nothing cannot pass.

    ASCII only in this file.
#>

#  7c is named in stages= as well as in the stage-qualified clause: this gate is
#  a member of the 4/7c band (Run-Gates plans it there for the rendered arm),
#  and a header declaring only 3c says the rendered arm runs nowhere.
# GATE: stages=3c,7c; requires=BuildDir; 7c: DocText

[CmdletBinding()]
param(
    [string]   $BuildDir,
    [string[]] $DocText,
    [string]   $RulesPath,
    #  The pipeline stage this run stands for. '7c' makes the rendered arm
    #  BLOCKING: zero extracts is a refusal, not a pass.
    [string]   $Stage,
    [switch]   $SelfTest,
    [switch]   $Quiet
)

$ErrorActionPreference = 'Stop'

#  $PSScriptRoot is populated here (it is EMPTY inside a parameter default when
#  the script is run as `powershell -File`), with a guarded fallback.
$script:FcScriptDir = $PSScriptRoot
if (-not $script:FcScriptDir -and $MyInvocation.MyCommand.Path) { $script:FcScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $script:FcScriptDir 'Lib-GateCommon.ps1')

$GATE = 'Test-FigureConsistency'

function Stop-FcUsage {
    param([string] $Message)
    Write-Host ("  X {0}: {1}" -f $GATE, $Message) -ForegroundColor Red
    exit 2
}

# ---- variant expansion: digits <-> words, so "20 gastronorm" also catches
#      "twenty gastronorm" and "6 of twenty". Hyphen/space tolerant, and
#      ANCHORED at the token boundary so a value is never matched inside a
#      longer number.
$W2N = @{ zero=0; one=1; two=2; three=3; four=4; five=5; six=6; seven=7; eight=8; nine=9; ten=10
          eleven=11; twelve=12; thirteen=13; fourteen=14; fifteen=15; sixteen=16; seventeen=17
          eighteen=18; nineteen=19; twenty=20; thirty=30; forty=40; fifty=50; sixty=60
          seventy=70; eighty=80; ninety=90 }
$N2W = @{}; foreach ($k in $W2N.Keys) { $N2W[[string]$W2N[$k]] = $k }

$script:FcVariantCache = @{}

#  REQUEST: Lib-GateCommon Get-GateValueBoundaryRegex -AllowSentenceEnd
#  (see scratchpad\p0\REQUESTS\C2.md). The one line marked below is this gate's
#  only departure from the shared builder's output, and it exists because this
#  gate reads RAW document text where the coverage sweep reads normalised text.
function ConvertTo-VariantRegex ([string] $Literal) {
    <#  A registry value as a regex that matches THE VALUE AND NOTHING LONGER.

        THE BOUNDARY IS NOT BUILT HERE. Lib-GateCommon's
        Get-GateValueBoundaryRegex is the ONE definition of a token boundary,
        and this gate composes only the VARIANT ALTERNATION and hands it over
        with -Raw. Assert-FigureCoverage composes the same alternation and calls
        the same builder, so the two figure gates cannot disagree about what
        counts as one figure.

        Unanchored, a forbid of "37.8" fired on "137.85" - a different number
        this build is entitled to write - and the same unanchored matching let
        the coverage sweep source "7.5 L" against a corpus line reading
        "17.5 L".

        -AllowPlural, or the anchor would stop "20 gastronorm" matching
        "20 gastronorms" and NARROW the stale-value and leakage arms this gate
        exists for. -IgnoreCase, because a stale figure is stale in either case.

        THE ONE WIDENING, AND WHY IT IS HERE AND NOT IN THE COVERAGE GATE. The
        shared builder's trailing boundary excludes a full stop, deliberately:
        it is what keeps "7.5" out of "7.5.1", and for a PRESENT test erring
        towards ABSENT is the safe direction. THIS gate's arms err the other
        way - a stale value it fails to match is a defect it ships - and it
        reads raw document text, where "not 37.8." at the end of a sentence is
        the ordinary case. So the trailing class is widened to refuse a word
        character and a DECIMAL continuation, and nothing else. It is applied to
        the shared builder's own output rather than rebuilt, so there is still
        one definition of a boundary; case 9 of the self-test fails loudly if
        this stops applying.  #>
    if ($script:FcVariantCache.ContainsKey($Literal)) { return $script:FcVariantCache[$Literal] }
    $rx = '(?!)'
    if ("$Literal".Trim()) {
        $n2w = $script:N2W
        $inner = [regex]::Escape($Literal)
        $inner = [regex]::Replace($inner, '\\ ', '[\s-]+')
        $inner = [regex]::Replace($inner, '(?<![\d.])(\d{1,2})(?![\d.])', {
            param($m); $d = $m.Groups[1].Value
            if ($n2w.ContainsKey($d)) { "(?:$d|$($n2w[$d]))" } else { $d }
        })
        foreach ($w in $script:W2N.Keys) {
            $inner = [regex]::Replace($inner, "(?i)\b$w\b", "(?:$w|$($script:W2N[$w]))")
        }
        $rx = Get-GateValueBoundaryRegex -Value $inner -Raw -AllowPlural -IgnoreCase
        # -- the one widening, on the shared builder's own output --
        $rx = $rx -replace '\(\?!\[\\d\.\\w\]\)$', '(?!\.?\d)(?!\w)'
    }
    $script:FcVariantCache[$Literal] = $rx
    return $rx
}

# ---------------------------------------------------------------------------
# SELF-TEST - a fixture registry and spine, every plant read back, then the
# gate run as a child so its exit codes are the thing asserted.
# ---------------------------------------------------------------------------

if ($SelfTest) {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('figcons-selftest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $failures = 0
    $enc = New-Object System.Text.UTF8Encoding($true)
    function Ok  { param([string] $m) Write-Host ("  ok   {0}" -f $m) -ForegroundColor Green }
    function Bad { param([string] $m) Write-Host ("  X    {0}" -f $m) -ForegroundColor Red; $script:failures++ }
    $script:failures = 0

    function New-FcFixture {
        param([string] $Dir, [string[]] $Prose)
        New-Item -ItemType Directory -Force -Path (Join-Path $Dir 'spine') | Out-Null
        $reg = [ordered]@{
            figures = @(
                [ordered]@{ name = 'Fixture batch yield'; forbid = @('37.8'); forbidRx = @('\b6 of (10|20)\b'); require = @('35.5') }
            )
            assessorOnly = @([ordered]@{ text = '20 gastronorm'; why = 'fixture benchmark' })
            deckMust = @('wastage')
        }
        [System.IO.File]::WriteAllText((Join-Path $Dir 'figures.json'), ($reg | ConvertTo-Json -Depth 6), $enc)
        $spine = [ordered]@{
            ref = '1.1'; pc = '1.1'; topic = 1; title = 'Fixture sub-section'
            whatThisMeans = @($Prose)
            slides = @([ordered]@{ layout = 'single'; kind = 'teaching'; headline = 'Fixture'; bullets = @('Count the wastage before the run.'); notes = 'Wastage is counted.' })
        }
        [System.IO.File]::WriteAllText((Join-Path $Dir 'spine\t1_1.1.json'), ($spine | ConvertTo-Json -Depth 6), $enc)
        return $Dir
    }
    function Invoke-FcChild {
        param([hashtable] $Params)
        $global:LASTEXITCODE = 0
        #  *>&1, not 2>&1: the gate speaks through Write-Host, which is the
        #  information stream in PS 5.1, and a capture that misses it asserts
        #  against an empty string.
        $text = & $PSCommandPath @Params *>&1 | Out-String
        return [pscustomobject]@{ Code = $LASTEXITCODE; Text = $text }
    }

    Write-Host ''
    Write-Host ("{0} SELF-TEST" -f $GATE) -ForegroundColor Cyan
    try {
        # 0. clean fixture passes
        $d0 = New-FcFixture -Dir (Join-Path $root 'clean') -Prose @('The batch yields 35.5 kg after trimming.')
        $r = Invoke-FcChild @{ BuildDir = $d0 }
        if ($r.Code -eq 0) { Ok 'clean fixture: exit 0 (the required figure is present, nothing stale, deck carries its term)' } else { Bad ("clean fixture exited {0}: {1}" -f $r.Code, $r.Text) }

        # 1. a stale figure planted in prose, read back, must exit 8 naming it
        $d1 = New-FcFixture -Dir (Join-Path $root 'stale') -Prose @('The batch yields 35.5 kg after trimming, not 37.8 kg as the old card said.')
        $back = Get-GateFileText -Path (Join-Path $d1 'spine\t1_1.1.json')
        if ($back -notmatch '37\.8') { Bad 'plant 1 did not land in the spine file' }
        else {
            $r = Invoke-FcChild @{ BuildDir = $d1; Quiet = $true }
            if ($r.Code -eq 8) { Ok "plant 1 (stale '37.8' in prose): exit 8" } else { Bad ("plant 1 exited {0}, wanted 8" -f $r.Code) }
        }

        # 2. a word-form leak of an assessor-only figure inside a rendered extract, via -DocText
        $d2 = New-FcFixture -Dir (Join-Path $root 'leak') -Prose @('The batch yields 35.5 kg after trimming.')
        $ext = Join-Path $d2 'guide_gate.txt'
        [System.IO.File]::WriteAllText($ext, "Learner guide extract`r`nThe chiller takes twenty gastronorm trays.`r`n", $enc)
        if ((Get-GateFileText -Path $ext) -notmatch 'twenty gastronorm') { Bad 'plant 2 did not land in the extract' }
        else {
            $r = Invoke-FcChild @{ BuildDir = $d2; DocText = @($ext); Quiet = $true }
            if ($r.Code -eq 8) { Ok "plant 2 (word-form 'twenty gastronorm' in guide_gate.txt): exit 8 - variant-aware over the rendered arm" } else { Bad ("plant 2 exited {0}, wanted 8" -f $r.Code) }
        }

        # 3. a -DocText path that does not exist is a refusal naming it, never dropped
        $missing = Join-Path $root 'nowhere\guide_gate.txt'
        $r = Invoke-FcChild @{ BuildDir = $d0; DocText = @($missing) }
        if ($r.Code -eq 2 -and $r.Text -match [regex]::Escape('nowhere')) { Ok 'missing -DocText path: exit 2 naming the path' } else { Bad ("missing -DocText exited {0} (wanted 2 naming the path): {1}" -f $r.Code, $r.Text) }

        # 4. -Stage 7c with no -DocText: exit 2 naming the two extracts
        $r = Invoke-FcChild @{ BuildDir = $d0; Stage = '7c' }
        if ($r.Code -eq 2 -and $r.Text -match 'guide_gate\.txt' -and $r.Text -match 'deck_gate\.txt') { Ok '-Stage 7c without -DocText: exit 2 naming guide_gate.txt and deck_gate.txt' } else { Bad ("-Stage 7c without -DocText exited {0}: {1}" -f $r.Code, $r.Text) }

        # 5. -Stage 7c with both extracts present and clean: exit 0 and the rendered arm on the roster ran with 2
        $g = Join-Path $d0 'guide_gate.txt'; $k = Join-Path $d0 'deck_gate.txt'
        [System.IO.File]::WriteAllText($g, "Guide extract`r`nThe batch yields 35.5 kg.`r`n", $enc)
        [System.IO.File]::WriteAllText($k, "Deck extract`r`nCount the wastage.`r`n", $enc)
        $r = Invoke-FcChild @{ BuildDir = $d0; Stage = '7c'; DocText = @($g, $k) }
        if ($r.Code -eq 0 -and $r.Text -match 'ARMS: .*rendered\|true\|ran\|2\|') { Ok '-Stage 7c with both extracts: exit 0, roster shows rendered|true|ran|2' } else { Bad ("-Stage 7c with extracts exited {0}: {1}" -f $r.Code, $r.Text) }

        # 6. a missing registry is a refusal naming it
        $d6 = Join-Path $root 'noreg'; New-Item -ItemType Directory -Force -Path (Join-Path $d6 'spine') | Out-Null
        $r = Invoke-FcChild @{ BuildDir = $d6 }
        if ($r.Code -eq 2 -and $r.Text -match 'figures\.json') { Ok 'no figures.json: exit 2 naming the registry' } else { Bad ("no registry exited {0}: {1}" -f $r.Code, $r.Text) }

        # 7. THE ANCHORED BOUNDARY. A forbid value is THE VALUE, not any digit
        #    string that contains it. Unanchored, forbid '37.8' fired on
        #    '137.85' - a different number this build is entitled to write - and
        #    the same unanchored matching let the coverage sweep source '7.5 L'
        #    against a corpus line that says '17.5 L'. Both figure gates now
        #    call one anchored builder.
        $d7 = New-FcFixture -Dir (Join-Path $root 'anchored') -Prose @('The batch yields 35.5 kg after trimming, and the bulk drum holds 137.85 kg.')
        if ((Get-GateFileText -Path (Join-Path $d7 'spine\t1_1.1.json')) -notmatch '137\.85') { Bad 'the anchored control did not land in the spine file' }
        else {
            $r = Invoke-FcChild @{ BuildDir = $d7; Quiet = $true }
            if ($r.Code -eq 0) { Ok "anchored boundary: forbid '37.8' does NOT fire on '137.85' - a value is matched at its token boundary, never as a digit substring" }
            else { Bad ("anchored control exited {0}, wanted 0 - the forbid arm fired on a digit substring: {1}" -f $r.Code, $r.Text) }
        }

        # 8. AND THE ANCHOR DOES NOT NARROW THE ARM. The value at its own
        #    boundary, and an English plural of it, are both still caught. An
        #    anchor that silently stopped catching 'twenty gastronorms' would
        #    have switched off the leakage arm this gate exists for.
        $d8 = New-FcFixture -Dir (Join-Path $root 'plural') -Prose @('The batch yields 35.5 kg after trimming.')
        $ext8 = Join-Path $d8 'guide_gate.txt'
        [System.IO.File]::WriteAllText($ext8, "Learner guide extract`r`nThe chiller takes twenty gastronorms.`r`n", $enc)
        if ((Get-GateFileText -Path $ext8) -notmatch 'twenty gastronorms') { Bad 'the plural leakage plant did not land in the extract' }
        else {
            $r = Invoke-FcChild @{ BuildDir = $d8; DocText = @($ext8); Quiet = $true }
            if ($r.Code -eq 8) { Ok "plural leakage: 'twenty gastronorms' still trips an assessor-only rule written '20 gastronorm' - the anchor allows an English plural" }
            else { Bad ("plural leakage exited {0}, wanted 8 - anchoring has narrowed the leakage arm" -f $r.Code) }
        }

        # 9. A STALE VALUE AT THE END OF A SENTENCE. The full stop after a value
        #    is not a decimal continuation, and an anchor that treated it as one
        #    would miss every stale figure that ends a sentence - which is most
        #    of them.
        $d9 = New-FcFixture -Dir (Join-Path $root 'sentence-end') -Prose @('The batch yields 35.5 kg after trimming, not 37.8.')
        $r = Invoke-FcChild @{ BuildDir = $d9; Quiet = $true }
        if ($r.Code -eq 8) { Ok "sentence-final stale value: forbid '37.8' fires on '37.8.' - a full stop is not a decimal continuation" }
        else { Bad ("sentence-final stale value exited {0}, wanted 8 - the trailing anchor is eating a full stop" -f $r.Code) }
    }
    finally {
        if ((Test-Path -LiteralPath $root) -and $root.Length -gt 20) { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }
    Write-Host ''
    if ($script:failures -eq 0) { Write-Host '  SELF-TEST PASS - every plant landed and the gate refused or failed by name on each' -ForegroundColor Green; exit 0 }
    Write-Host ("  SELF-TEST FAIL - {0} check(s)" -f $script:failures) -ForegroundColor Red
    exit 4
}

# ---------------------------------------------------------------------------
# Inputs - refused by name when absent
# ---------------------------------------------------------------------------

if (-not $BuildDir) { Stop-FcUsage '-BuildDir is required (or run with -SelfTest).' }
if (-not (Test-Path -LiteralPath $BuildDir)) { Stop-FcUsage ('build directory not found: {0}' -f $BuildDir) }
if ($Stage -and $Stage -notin @('3c', '7c')) { Stop-FcUsage ("-Stage '{0}' is not one this gate runs at (3c or 7c)." -f $Stage) }
$is7c = ($Stage -eq '7c')

$docPaths = @($DocText | Where-Object { $_ })
foreach ($p in $docPaths) {
    if (-not (Test-Path -LiteralPath $p)) {
        Stop-FcUsage ("-DocText path does not exist: {0}. A rendered extract that cannot be read is not silently dropped - the rendered arm would then pass over nothing." -f $p)
    }
}
if ($is7c -and $docPaths.Count -eq 0) {
    Stop-FcUsage 'at -Stage 7c the rendered arm is BLOCKING and no -DocText was passed. Expected guide_gate.txt and deck_gate.txt (the Get-DocText extracts of both artefacts). Zero extracts is a refusal, not a pass.'
}

if (-not $RulesPath) { $RulesPath = Join-Path $BuildDir 'figures.json' }
if (-not (Test-Path -LiteralPath $RulesPath)) {
    Stop-FcUsage ("no figures registry at {0}. Stage 2 locks one; a build without it cannot gate its figures." -f $RulesPath)
}

$rc = 0
try {
    Reset-GateArmRoster
    Register-GateArm -Name 'registry' -Blocking
    Register-GateArm -Name 'sources' -Blocking
    Register-GateArm -Name 'rendered' -Blocking:$is7c
    Register-GateArm -Name 'deck-must'

    $rules = Get-GateJson -Path $RulesPath
    if ($null -eq $rules) { throw ("CHECK-SET EMPTY: {0} is empty or unparseable - no figure rule can be read from it." -f $RulesPath) }

    # ---- sources: spine JSON, build scripts, and any doc extracts handed in
    $text = [ordered]@{}
    $spine = Join-Path $BuildDir 'spine'
    if (Test-Path -LiteralPath $spine) {
        foreach ($f in (Get-GateSpineFiles -BuildDir $BuildDir -SpineDir $spine -IncludeFrontMatter -Exclude @())) {
            $text[$f.Name] = Get-GateFileText -Path $f.FullName
        }
    }
    foreach ($f in Get-ChildItem -LiteralPath $BuildDir -Filter '*.ps1' -File) {
        # This gate and one-time migration records are meta, not content sources.
        if ($f.Name -match 'FigureConsistency|Move-SpecsIntoSpine') { continue }
        $text[$f.Name] = Get-GateFileText -Path $f.FullName
    }
    $renderedNames = New-Object System.Collections.Generic.List[string]
    foreach ($p in $docPaths) {
        $leaf = Split-Path $p -Leaf
        $text[$leaf] = Get-GateFileText -Path $p
        $renderedNames.Add($leaf)
    }

    $ruleCount = @($rules.figures | Where-Object { $null -ne $_ }).Count + @($rules.assessorOnly | Where-Object { $null -ne $_ }).Count
    if (-not $Quiet) { Write-Host ''; Write-Host 'FIGURE CONSISTENCY' -ForegroundColor Cyan }
    Write-GateCheckSet -What 'registry rule(s) (figures + assessor-only strings)' -Count $ruleCount -DerivedFrom (Split-Path $RulesPath -Leaf) -Blocking -Input $RulesPath
    Complete-GateArm -Name 'registry' -State $(if ($ruleCount -gt 0) { 'ran' } else { 'empty' }) -Size $ruleCount
    Write-GateCheckSet -What 'source file(s) scanned (spine, build scripts, extracts)' -Count $text.Count -DerivedFrom 'the spine directory, *.ps1 beside the build, and -DocText' -Blocking -Input ('{0}\spine and -DocText' -f $BuildDir)
    Complete-GateArm -Name 'sources' -State $(if ($text.Count -gt 0) { 'ran' } else { 'empty' }) -Size $text.Count
    Write-GateCheckSet -What 'rendered extract(s)' -Count $renderedNames.Count -DerivedFrom '-DocText' -Blocking:$is7c -Input 'guide_gate.txt / deck_gate.txt (-DocText)'
    Complete-GateArm -Name 'rendered' -State $(if ($renderedNames.Count -gt 0) { 'ran' } else { 'empty' }) -Size $renderedNames.Count

    $fail = New-Object System.Collections.Generic.List[string]
    $warn = New-Object System.Collections.Generic.List[string]

    foreach ($rule in @($rules.figures)) {
        if ($null -eq $rule) { continue }
        foreach ($bad in @($rule.forbid)) {
            if (-not $bad) { continue }
            $rx = ConvertTo-VariantRegex $bad
            foreach ($k in $text.Keys) {
                $n = ([regex]::Matches($text[$k], $rx)).Count
                if ($n -gt 0) { $fail.Add("[$($rule.name)] stale '$bad' (or a variant) x$n in $k") }
            }
        }
        foreach ($brx in @($rule.forbidRx)) {
            if (-not $brx) { continue }
            foreach ($k in $text.Keys) {
                $n = ([regex]::Matches($text[$k], $brx)).Count
                if ($n -gt 0) { $fail.Add("[$($rule.name)] stale pattern '$brx' x$n in $k") }
            }
        }
        foreach ($need in @($rule.require)) {
            if (-not $need) { continue }
            $total = 0
            foreach ($k in $text.Keys) { $total += ([regex]::Matches($text[$k], [regex]::Escape($need))).Count }
            if ($total -eq 0) { $fail.Add("[$($rule.name)] required '$need' appears NOWHERE") }
        }
    }

    foreach ($a in @($rules.assessorOnly)) {
        if ($null -eq $a) { continue }
        $rx = if ($a.rx) { $a.rx } else { ConvertTo-VariantRegex ([string]$a.text) }
        $label = if ($a.text) { $a.text } else { $a.rx }
        foreach ($k in $text.Keys) {
            $n = ([regex]::Matches($text[$k], $rx)).Count
            if ($n -gt 0) { $fail.Add("BENCHMARK LEAKAGE: '$label' (or a variant) x$n in $k - $($a.why)") }
        }
    }

    # The deck must carry every corrected figure the guide carries. A corrected
    # guide against an uncorrected deck is worse than the original defect: the
    # learner cannot tell which document is meant.
    $deckMust = @($rules.deckMust | Where-Object { $_ })
    if ($deckMust.Count -gt 0) {
        $deckText = ''
        foreach ($k in $text.Keys) {
            foreach ($m in [regex]::Matches($text[$k], '"(?:notes|note|lead|headline|kicker|chip|left|right|bullets|fig\d|label\d)":\s*(?:"((?:[^"\\]|\\.)*)"|\[)')) {
                $deckText += ' ' + $m.Groups[1].Value
            }
            if ($k -match '\.ps1$' -or $k -match 'deck') { $deckText += ' ' + $text[$k] }
            # slides arrays: take everything after the first "slides" key too
            $si = $text[$k].IndexOf('"slides"')
            if ($si -ge 0) { $deckText += ' ' + $text[$k].Substring($si) }
        }
        foreach ($d in $deckMust) {
            if ($deckText -notmatch (ConvertTo-VariantRegex $d)) {
                $fail.Add("DECK GAP: deck-facing text never carries '$d' - the guide teaches it and the deck does not")
            }
        }
        Complete-GateArm -Name 'deck-must' -State 'ran' -Size $deckMust.Count -Findings @($fail | Where-Object { $_ -like 'DECK GAP*' }).Count
    }
    else {
        Complete-GateArm -Name 'deck-must' -State 'empty' -Size 0
    }

    Assert-GateArmsComplete
    $roster = Write-GateArmRoster

    if (-not $Quiet) {
        Write-Host ("  registry: {0} figures, {1} assessor-only strings, {2} deck-must terms; {3} source file(s) scanned; rendered extract(s): {4}" -f `
            @($rules.figures).Count, @($rules.assessorOnly).Count, $deckMust.Count, $text.Count, $(if ($renderedNames.Count) { ($renderedNames -join ', ') } else { 'none (expected at 3c, refused at 7c)' })) -ForegroundColor DarkGray
        if ($fail.Count -eq 0) { Write-Host '  no stale figures, no leakage, no deck gaps' -ForegroundColor Green }
        foreach ($f in $fail) { Write-Host "  X $f" -ForegroundColor Red }
        foreach ($w in $warn) { Write-Host "  ! $w" -ForegroundColor Yellow }
        if ($fail.Count) { Write-Host "FAIL - $($fail.Count) problem(s)" -ForegroundColor Red }
        else             { Write-Host 'PASS' -ForegroundColor Green }
    }
    if ($fail.Count) { $rc = 8 }
}
catch {
    $msg = $_.Exception.Message
    if ($msg -match '^(CHECK-SET EMPTY|ARMS INCOMPLETE):') { Stop-FcUsage $msg }
    Stop-FcUsage ("the gate could not run - {0}" -f $msg)
}
# Explicit on BOTH paths. A script that only exits on failure leaves
# $LASTEXITCODE holding whatever the previous command set - the self-test's
# clean-pass check read a stale 8 from its own failure check and reported a
# false positive on the gate itself.
exit $rc
