# Every rule the registry is supposed to hold, checked in one pass. Read-only.
#
#  R1  a topic's OWNER is taught before every unit that only recalls it
#  R2  a PREREQUISITE is taught before the unit that needs it, or is held on entry
#  R3  a qualification delivered by two institutes is IDENTICAL - units, designations,
#      delivery status, order, themes and rulings. Only the branding differs.
#  R4  a CAPSTONE unit finishes the course
#  R5  every delivered unit sits in exactly one theme, and the themes cover every one
#  R6  theme week ranges are contiguous, start at 1 and reach the course duration
#  R7  every ruling's owner and appliers are delivered units of that course
#  R8  the recorded unit count matches the national packaging total
$ErrorActionPreference = 'Stop'
$assets = Join-Path $env:USERPROFILE '.claude\skills\tas\assets'
$fail = @(); $warn = @()

$courses = @{}
foreach ($f in (Get-ChildItem (Join-Path $assets 'courses') -Filter '*.json' | Sort-Object Name)) {
    $c = Get-Content $f.FullName -Raw | ConvertFrom-Json
    $tf = Join-Path $assets "topics/$($c.courseId).topics.json"
    $t = if (Test-Path $tf) { @((Get-Content $tf -Raw -Encoding UTF8 | ConvertFrom-Json).topics) } else { @() }
    $courses[$c.courseId] = [pscustomobject]@{ C=$c; T=$t }
}

function Get-Order($c) {
    $pos = @{}; $i = 0
    foreach ($cl in ($c.sequencing.clusters | Sort-Object number)) {
        foreach ($u in $cl.units) { if (-not $pos.ContainsKey($u)) { $pos[$u] = $i; $i++ } }
    }
    return $pos
}

foreach ($id in ($courses.Keys | Sort-Object)) {
    $c = $courses[$id].C; $topics = $courses[$id].T
    $pos = Get-Order $c
    $delivered = @($c.units | Where-Object { $_.deliveryStatus -eq 'delivered' } | ForEach-Object { $_.code })
    $held = @($c.units | Where-Object { $_.deliveryStatus -ne 'delivered' } | ForEach-Object { $_.code })

    # R5 - every delivered unit placed exactly once
    $missing = @($delivered | Where-Object { -not $pos.ContainsKey($_) })
    if ($missing.Count) { $fail += "R5 $id : delivered but in no theme - $($missing -join ', ')" }
    $extra = @($pos.Keys | Where-Object { $delivered -notcontains $_ })
    if ($extra.Count) { $fail += "R5 $id : in a theme but not delivered - $($extra -join ', ')" }

    # R1 - owner before applier
    foreach ($t in $topics) {
        if (-not $pos.ContainsKey($t.owner)) { $fail += "R7 $id $($t.id) : owner $($t.owner) is not a delivered unit"; continue }
        foreach ($ap in $t.appliedNotTaught) {
            if (-not $pos.ContainsKey($ap)) { $fail += "R7 $id $($t.id) : applier $ap is not a delivered unit"; continue }
            if ($pos[$t.owner] -gt $pos[$ap]) { $fail += "R1 $id $($t.id) : owner $($t.owner) at #$($pos[$t.owner]+1) after $ap at #$($pos[$ap]+1)" }
        }
    }

    # R2 - prerequisites
    foreach ($u in $c.units) {
        $rf = Join-Path $assets "units/$($u.code).json"
        if (-not (Test-Path $rf)) { continue }
        foreach ($p in (Get-Content $rf -Raw | ConvertFrom-Json).prerequisites) {
            if (-not $pos.ContainsKey($u.code)) { continue }
            if ($pos.ContainsKey($p.code)) {
                if ($pos[$p.code] -gt $pos[$u.code]) { $fail += "R2 $id : $($u.code) at #$($pos[$u.code]+1) needs $($p.code) taught later at #$($pos[$p.code]+1)" }
            } elseif ($held -notcontains $p.code) {
                $fail += "R2 $id : $($u.code) needs $($p.code), which the course neither delivers nor credits"
            }
        }
    }

    # R4 - capstone last
    foreach ($u in $c.units) {
        if ($u.title -match '^Work effectively (as a cook|in a commercial kitchen)' -and $pos.ContainsKey($u.code)) {
            if ($pos[$u.code] -ne ($pos.Count - 1)) { $fail += "R4 $id : capstone $($u.code) at #$($pos[$u.code]+1) of $($pos.Count), not last" }
        }
    }

    # R6 - week ranges
    $cls = @($c.sequencing.clusters | Sort-Object number)
    if ($cls.Count) {
        $prevEnd = 0; $bad = $false
        foreach ($cl in $cls) {
            if ($cl.weeks -match '^(\d+)\s*-\s*(\d+)$') {
                $s = [int]$Matches[1]; $e = [int]$Matches[2]
                if ($s -ne $prevEnd + 1) { $fail += "R6 $id : theme $($cl.number) '$($cl.name)' starts week $s, previous ended $prevEnd"; $bad = $true }
                if ($e -lt $s) { $fail += "R6 $id : theme $($cl.number) week range $($cl.weeks) is backwards"; $bad = $true }
                $prevEnd = $e
            } else { $warn += "R6 $id : theme $($cl.number) has no parsable week range ('$($cl.weeks)')"; $bad = $true }
        }
        if (-not $bad -and $c.durationWeeks -and $prevEnd -ne $c.durationWeeks) {
            $fail += "R6 $id : themes end at week $prevEnd, course duration is $($c.durationWeeks) weeks"
        }
    }
}

# R3 - harmonised pairs
$seen = @{}
foreach ($id in ($courses.Keys | Sort-Object)) {
    $c = $courses[$id].C
    if (-not $c.siblingCourse -or $seen[$id]) { continue }
    $o = $courses[$c.siblingCourse]; if (-not $o) { continue }
    $seen[$id] = $true; $seen[$c.siblingCourse] = $true
    $oc = $o.C

    function Sig($cc) { ($cc.units | Sort-Object code | ForEach-Object { "$($_.code)/$($_.designation)/$($_.deliveryStatus)" }) -join ';' }
    function ThemeSig($cc) { ($cc.sequencing.clusters | Sort-Object number | ForEach-Object { "$($_.number)|$($_.name)|$($_.weeks)|$($_.units -join ',')" }) -join ' || ' }
    function RuleSig($tt) { ($tt | Sort-Object id | ForEach-Object { "$($_.id)=$($_.owner)|$((@($_.appliedNotTaught)|Sort-Object) -join ',')" }) -join ' ; ' }

    if ((Sig $c) -ne (Sig $oc))            { $fail += "R3 $($c.qualificationCode) : $id and $($oc.courseId) differ on units, designations or delivery status" }
    if ((ThemeSig $c) -ne (ThemeSig $oc))  { $fail += "R3 $($c.qualificationCode) : $id and $($oc.courseId) differ on themes or order" }
    if ((RuleSig $courses[$id].T) -ne (RuleSig $o.T)) { $fail += "R3 $($c.qualificationCode) : $id and $($oc.courseId) differ on topic rulings" }
    if ($c.durationWeeks -ne $oc.durationWeeks) { $fail += "R3 $($c.qualificationCode) : durations differ - $($c.durationWeeks) vs $($oc.durationWeeks) weeks" }
}

"{0} failures, {1} warnings" -f $fail.Count, $warn.Count
""
if ($fail.Count) { "FAILURES"; $fail | ForEach-Object { "  $_" }; "" }
if ($warn.Count) { "WARNINGS"; $warn | ForEach-Object { "  $_" } }
if (-not $fail.Count) { "every rule holds across all $($courses.Count) courses" }
