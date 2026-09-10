# Turns the theme answers into a plan file, and refuses anything that changes the solved
# order. Naming and grouping were delegated; the ORDER was not, because it is the thing
# the two hard constraints determine.
[CmdletBinding()]
param([string] $Answers = 'theme-answers.txt')

$ErrorActionPreference = 'Stop'
$assets = Join-Path $env:USERPROFILE '.claude\skills\tas\assets'

# The draft order is only ONE valid solution. What must hold is the constraints, so
# that a shared qualification can adopt Meridian's order verbatim and still be checked.
$delivered = @{}; $edges = @{}
foreach ($f in (Get-ChildItem (Join-Path $assets 'courses') -Filter '*.json')) {
    $c = Get-Content $f.FullName -Raw | ConvertFrom-Json
    $codes = @($c.units | Where-Object { $_.deliveryStatus -eq 'delivered' } | ForEach-Object { $_.code })
    $delivered[$c.courseId] = $codes
    $inC = @{}; foreach ($x in $codes) { $inC[$x] = $true }
    $e = @()
    foreach ($u in $c.units) {
        $rf = Join-Path $assets "units/$($u.code).json"
        if (-not (Test-Path $rf)) { continue }
        foreach ($p in (Get-Content $rf -Raw | ConvertFrom-Json).prerequisites) {
            if ($inC[$p.code] -and $inC[$u.code]) { $e += ,@($p.code, $u.code, 'prerequisite') }
        }
    }
    $tf = Join-Path $assets "topics/$($c.courseId).topics.json"
    if (Test-Path $tf) {
        foreach ($t in (Get-Content $tf -Raw -Encoding UTF8 | ConvertFrom-Json).topics) {
            foreach ($a in $t.appliedNotTaught) {
                if ($inC[$t.owner] -and $inC[$a]) { $e += ,@($t.owner, $a, "owns $($t.id)") }
            }
        }
    }
    $edges[$c.courseId] = $e
}
$solved = $delivered

$lines = Get-Content (Join-Path $PSScriptRoot $Answers) -Encoding UTF8
$plans = @(); $cur = $null; $themes = @()

function Close-Course {
    if (-not $script:cur) { return }
    $id = $script:cur
    $got = @($script:themes | ForEach-Object { $_.units } | ForEach-Object { $_ })
    $want = $solved[$id]
    if (-not $want) { throw "$id is not a course in the registry" }

    $miss = @($want | Where-Object { $got -notcontains $_ })
    $extra= @($got  | Where-Object { $want -notcontains $_ })
    if ($miss.Count -or $extra.Count) {
        throw "$id : unit set differs from the delivered units. missing: $($miss -join ', ')  unexpected: $($extra -join ', ')"
    }
    # the two hard ordering rules, checked against the order actually given
    $pos = @{}; for ($k = 0; $k -lt $got.Count; $k++) { $pos[$got[$k]] = $k }
    $bad = @()
    foreach ($e in $edges[$id]) {
        if ($pos[$e[0]] -gt $pos[$e[1]]) { $bad += "$($e[0]) must be taught before $($e[1]) [$($e[2])] but sits at #$($pos[$e[0]]+1) against #$($pos[$e[1]]+1)" }
    }
    if ($bad.Count) { throw "$id : the order breaks $($bad.Count) hard constraint(s):`n    $($bad -join "`n    ")" }
    $script:plans += [ordered] @{ courseId = $id; model = 'theme'; themes = $script:themes }
    $script:cur = $null; $script:themes = @()
}

foreach ($line in $lines) {
    $l = $line.Trim()
    if ($l -match '^COURSE:\s*(\S+)') {
        Close-Course
        $cur = $Matches[1]; $themes = @()
        continue
    }
    if ($l -match '^THEME\s*\d+\s*\|(.+)$') {
        if (-not $cur) { throw "THEME line before any COURSE line: $l" }
        $parts = $Matches[1] -split '\|'
        if ($parts.Count -lt 4) { throw "malformed THEME line: $l" }
        $name  = $parts[0].Trim()
        $focus = $parts[1].Trim()
        $wk    = $parts[2].Trim() -replace '^weeks\s*',''
        $units = @($parts[3] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        if (-not $name)  { throw "theme with no name in $cur" }
        if (-not $units.Count) { throw "theme '$name' in $cur has no units" }
        $themes += [ordered] @{ name = $name; focus = $focus; weeks = $wk; hours = $null; units = $units }
        continue
    }
}
Close-Course

$missing = @($solved.Keys | Where-Object { $id = $_; -not ($plans | Where-Object { $_.courseId -eq $id }) })
if ($missing.Count) { throw "no themes given for: $($missing -join ', ')" }

$out = Join-Path $PSScriptRoot 'plans-final.json'
[System.IO.File]::WriteAllText($out, ($plans | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
"validated {0} courses, {1} themes - order preserved everywhere" -f $plans.Count, (($plans | ForEach-Object { $_.themes.Count } | Measure-Object -Sum).Sum)
foreach ($p in $plans) { "  {0,-16} {1} themes: {2}" -f $p.courseId, $p.themes.Count, (($p.themes | ForEach-Object { $_.name }) -join ' / ') }
