# Produces, for every course, the constraint-satisfying delivery order and a first cut at
# theme boundaries. Blocks break where the prerequisite depth rises - that is where the
# course genuinely moves from foundation to application - and never run longer than 7
# units. Names are placeholders; they are written properly afterwards.
$ErrorActionPreference = 'Stop'
$assets = Join-Path $env:USERPROFILE '.claude\skills\tas\assets'
$outJson = Join-Path $PSScriptRoot 'plans-draft.json'
$outTxt  = Join-Path $PSScriptRoot 'plans-draft.txt'

$plans = @(); $txt = @()

foreach ($f in (Get-ChildItem (Join-Path $assets 'courses') -Filter '*.json' | Sort-Object Name)) {
    $c = Get-Content $f.FullName -Raw | ConvertFrom-Json
    $id = $c.courseId
    $tf = Join-Path $assets "topics/$id.topics.json"
    $topics = if (Test-Path $tf) { @((Get-Content $tf -Raw | ConvertFrom-Json).topics) } else { @() }

    $delivered = @($c.units | Where-Object { $_.deliveryStatus -eq 'delivered' })
    $codes = @($delivered | ForEach-Object { $_.code })
    $inC = @{}; foreach ($x in $codes) { $inC[$x] = $true }
    $titleOf = @{}; foreach ($u in $delivered) { $titleOf[$u.code] = $u.title }
    $desOf   = @{}; foreach ($u in $delivered) { $desOf[$u.code] = $u.designation }

    $orig = @{}; $i = 0
    if (@($c.sequencing.clusters).Count) {
        foreach ($cl in ($c.sequencing.clusters | Sort-Object number)) {
            foreach ($u in $cl.units) { if ($inC[$u] -and -not $orig.ContainsKey($u)) { $orig[$u] = $i; $i++ } }
        }
    }
    foreach ($u in ($delivered | Sort-Object sequence)) { if (-not $orig.ContainsKey($u.code)) { $orig[$u.code] = $i; $i++ } }

    $pre = @{}; foreach ($x in $codes) { $pre[$x] = @() }
    foreach ($u in $delivered) {
        $rf = Join-Path $assets "units/$($u.code).json"
        if (-not (Test-Path $rf)) { continue }
        $rec = Get-Content $rf -Raw | ConvertFrom-Json
        foreach ($p in $rec.prerequisites) { if ($inC[$p.code]) { $pre[$u.code] += $p.code } }
    }
    $depth = @{}
    function Get-Depth($x) {
        if ($depth.ContainsKey($x)) { return $depth[$x] }
        $depth[$x] = 0; $m = 0
        foreach ($p in $pre[$x]) { $d = (Get-Depth $p) + 1; if ($d -gt $m) { $m = $d } }
        $depth[$x] = $m; return $m
    }
    foreach ($x in $codes) { [void](Get-Depth $x) }

    $capstone = @{}
    foreach ($u in $delivered) { if ($u.title -match '^Work effectively (as a cook|in a commercial kitchen)') { $capstone[$u.code] = $true } }

    $edges = @{}; $indeg = @{}
    foreach ($x in $codes) { $edges[$x] = New-Object System.Collections.ArrayList; $indeg[$x] = 0 }
    $seen = @{}
    function Add-Edge($a, $b) {
        if (-not $inC[$a] -or -not $inC[$b] -or $a -eq $b -or $seen["$a>$b"]) { return }
        $seen["$a>$b"] = $true; [void]$edges[$a].Add($b); $indeg[$b]++
    }
    foreach ($x in $codes) { foreach ($p in $pre[$x]) { Add-Edge $p $x } }
    foreach ($t in $topics) { foreach ($a in $t.appliedNotTaught) { Add-Edge $t.owner $a } }

    $order = @(); $avail = New-Object System.Collections.ArrayList
    foreach ($x in $codes) { if ($indeg[$x] -eq 0) { [void]$avail.Add($x) } }
    while ($avail.Count) {
        $pick = $null; $best = [double]::MaxValue
        foreach ($x in $avail) {
            $key = $orig[$x] + $(if ($capstone[$x]) { 10000 } else { 0 })
            if ($key -lt $best) { $best = $key; $pick = $x }
        }
        [void]$avail.Remove($pick); $order += $pick
        foreach ($n in $edges[$pick]) { $indeg[$n]--; if ($indeg[$n] -eq 0) { [void]$avail.Add($n) } }
    }
    if ($order.Count -ne $codes.Count) { throw "$id did not sequence" }

    # block boundaries
    $themes = @(); $cur = @(); $curDepth = $depth[$order[0]]
    foreach ($u in $order) {
        $break = ($cur.Count -ge 7) -or ($depth[$u] -gt $curDepth -and $cur.Count -ge 2) -or ($capstone[$u] -and $cur.Count -ge 1)
        if ($break -and $cur.Count) { $themes += ,@($cur); $cur = @() }
        $cur += $u; $curDepth = $depth[$u]
    }
    if ($cur.Count) { $themes += ,@($cur) }

    $planThemes = @()
    $n = 1
    foreach ($t in $themes) {
        $planThemes += [ordered] @{ name = "Theme $n"; focus = $null; weeks = $null; hours = $null; units = @($t) }
        $n++
    }
    $plans += [ordered] @{ courseId = $id; model = 'theme'; themes = $planThemes }

    $txt += "=== $id  $($c.qualificationCode) $($c.qualificationTitle)  [$($c.institute)]  $($c.durationWeeks) weeks"
    $n = 1
    foreach ($t in $themes) {
        $txt += "  Block $n"
        foreach ($u in $t) {
            $owns = @($topics | Where-Object { $_.owner -eq $u })
            $txt += ("    {0,-12} d{1}  {2,-8} teaches:{3,-2}  {4}" -f $u, $depth[$u], $desOf[$u], $owns.Count, $titleOf[$u])
        }
        $n++
    }
    $txt += ""
}

[System.IO.File]::WriteAllText($outJson, ($plans | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
[System.IO.File]::WriteAllLines($outTxt, $txt, (New-Object System.Text.UTF8Encoding($false)))
"wrote $($plans.Count) plans, $(($plans | ForEach-Object { $_.themes.Count } | Measure-Object -Sum).Sum) blocks"
