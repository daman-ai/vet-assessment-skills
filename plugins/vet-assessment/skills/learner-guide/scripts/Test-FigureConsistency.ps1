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
      exit 8 on failure. -Quiet suppresses the report.

    ASCII only in this file.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $BuildDir,
    [string[]] $DocText,
    [string]   $RulesPath,
    [switch]   $Quiet
)

$ErrorActionPreference = 'Stop'
if (-not $RulesPath) { $RulesPath = Join-Path $BuildDir 'figures.json' }
if (-not (Test-Path -LiteralPath $RulesPath)) {
    throw "No figures registry at $RulesPath. Stage 2 locks one; a build without it cannot gate its figures."
}
$rules = Get-Content -LiteralPath $RulesPath -Raw -Encoding UTF8 | ConvertFrom-Json

# ---- sources: spine JSON, build scripts, and any doc extracts handed in
$text = [ordered]@{}
$spine = Join-Path $BuildDir 'spine'
if (Test-Path -LiteralPath $spine) {
    foreach ($f in Get-ChildItem $spine -Filter '*.json' -File) {
        $text[$f.Name] = Get-Content $f.FullName -Raw -Encoding UTF8
    }
}
foreach ($f in Get-ChildItem $BuildDir -Filter '*.ps1' -File) {
    # This gate and one-time migration records are meta, not content sources.
    if ($f.Name -match 'FigureConsistency|Move-SpecsIntoSpine') { continue }
    $text[$f.Name] = Get-Content $f.FullName -Raw -Encoding UTF8
}
foreach ($p in @($DocText)) {
    if ($p -and (Test-Path -LiteralPath $p)) {
        $text[(Split-Path $p -Leaf)] = Get-Content -LiteralPath $p -Raw -Encoding UTF8
    }
}

# ---- variant expansion: digits <-> words, so "20 gastronorm" also catches
#      "twenty gastronorm" and "6 of twenty". Hyphen/space tolerant.
$W2N = @{ zero=0; one=1; two=2; three=3; four=4; five=5; six=6; seven=7; eight=8; nine=9; ten=10
          eleven=11; twelve=12; thirteen=13; fourteen=14; fifteen=15; sixteen=16; seventeen=17
          eighteen=18; nineteen=19; twenty=20; thirty=30; forty=40; fifty=50; sixty=60
          seventy=70; eighty=80; ninety=90 }
$N2W = @{}; foreach ($k in $W2N.Keys) { $N2W[[string]$W2N[$k]] = $k }

function ConvertTo-VariantRegex ([string] $Literal) {
    # Escape, then let every standalone number 0-99 also match its word form
    # (and every listed word also match its digits), spaces match hyphens too.
    $rx = [regex]::Escape($Literal)
    $rx = [regex]::Replace($rx, '\\ ', '[\s-]+')
    $rx = [regex]::Replace($rx, '(?<![\d.])(\d{1,2})(?![\d.])', {
        param($m); $d = $m.Groups[1].Value
        if ($script:N2W.ContainsKey($d)) { "(?:$d|$($script:N2W[$d]))" } else { $d }
    })
    foreach ($w in $W2N.Keys) {
        $rx = [regex]::Replace($rx, "(?i)\b$w\b", "(?:$w|$($W2N[$w]))")
    }
    return "(?i)$rx"
}

$fail = New-Object System.Collections.Generic.List[string]
$warn = New-Object System.Collections.Generic.List[string]

foreach ($rule in @($rules.figures)) {
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
if ($rules.deckMust) {
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
    foreach ($d in @($rules.deckMust)) {
        if ($deckText -notmatch (ConvertTo-VariantRegex $d)) {
            $fail.Add("DECK GAP: deck-facing text never carries '$d' - the guide teaches it and the deck does not")
        }
    }
}

if (-not $Quiet) {
    Write-Host ''
    Write-Host 'FIGURE CONSISTENCY' -ForegroundColor Cyan
    Write-Host ("  registry: {0} figures, {1} assessor-only strings, {2} deck-must terms; {3} source file(s) scanned" -f `
        @($rules.figures).Count, @($rules.assessorOnly).Count, @($rules.deckMust).Count, $text.Count) -ForegroundColor DarkGray
    if ($fail.Count -eq 0) { Write-Host '  no stale figures, no leakage, no deck gaps' -ForegroundColor Green }
    foreach ($f in $fail) { Write-Host "  X $f" -ForegroundColor Red }
    foreach ($w in $warn) { Write-Host "  ! $w" -ForegroundColor Yellow }
    if ($fail.Count) { Write-Host "FAIL - $($fail.Count) problem(s)" -ForegroundColor Red }
    else             { Write-Host 'PASS' -ForegroundColor Green }
}
# Explicit on BOTH paths. A script that only exits on failure leaves
# $LASTEXITCODE holding whatever the previous command set - the self-test's
# clean-pass check read a stale 8 from its own failure check and reported a
# false positive on the gate itself.
if ($fail.Count) { exit 8 }
exit 0
