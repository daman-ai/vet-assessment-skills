<#
    Assert-Registry.ps1 - read the whole registry back and fail on anything
    that would mislead a build. Run it after any change to assets/.

    It checks what a human reading the files would not notice: that every unit
    a course lists is cached, that every cached unit is current, that every
    topic owner is a delivered unit of its own course, that no topic is owned
    by a unit that also appears in its own appliedNotTaught list, that the
    per-unit index agrees with the topic list it was derived from, and that
    every course with a topic register has one built from the decisions file
    that is actually on disk.
#>
[CmdletBinding()]
param([string] $AssetDir)

$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $AssetDir) { $AssetDir = Join-Path $root '../assets' }

$fail = @(); $warn = @(); $checked = 0

$courses = @(Get-ChildItem (Join-Path $AssetDir 'courses') -Filter *.json | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
})
if (-not $courses) { throw 'no course records found' }

foreach ($c in $courses) {
    $codes = @($c.units | ForEach-Object { $_.code })

    if ($codes.Count -ne ($codes | Select-Object -Unique).Count) {
        $fail += "$($c.courseId): a unit is listed twice"
    }
    if ($c.packagingRule.totalUnits -and $c.unitCount -ne $c.packagingRule.totalUnits) {
        $fail += "$($c.courseId): $($c.unitCount) units recorded but the packaging rule states $($c.packagingRule.totalUnits)"
    }
    if (-not (Test-Path $c.source.tasFile)) {
        $warn += "$($c.courseId): source TAS is not at $($c.source.tasFile) - the record still stands, but it can no longer be re-derived"
    }

    foreach ($u in $c.units) {
        $checked++
        $f = Join-Path $AssetDir "units/$($u.code).json"
        if (-not (Test-Path $f)) { $fail += "$($c.courseId): $($u.code) is not in the unit cache"; continue }
        $rec = Get-Content -LiteralPath $f -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($rec.title -ne $u.title) { $fail += "$($c.courseId): $($u.code) title disagrees with the cache" }
        if ($rec.status -ne 'current' -and $u.deliveryStatus -eq 'delivered') {
            $fail += "$($c.courseId): $($u.code) is $($rec.statusLabel) on training.gov.au and is still a DELIVERED unit"
        }
        foreach ($pre in $rec.prerequisites) {
            if ($codes -notcontains $pre.code) {
                $warn += "$($c.courseId): $($u.code) requires prerequisite $($pre.code), which this course does not include"
            }
        }
    }

    $tf = Join-Path $AssetDir "topics/$($c.courseId).topics.json"
    if (-not (Test-Path $tf)) { $warn += "$($c.courseId): no topic register - builds get no cross-unit ruling"; continue }
    $t = Get-Content -LiteralPath $tf -Raw -Encoding UTF8 | ConvertFrom-Json

    $delivered = @($c.units | Where-Object { $_.deliveryStatus -eq 'delivered' } | ForEach-Object { $_.code })
    $ids = @()
    foreach ($tp in $t.topics) {
        $ids += $tp.id
        if ($delivered -notcontains $tp.owner) { $fail += "$($c.courseId) $($tp.id): owner $($tp.owner) is not a delivered unit of this course" }
        if ($tp.appliedNotTaught -contains $tp.owner) { $fail += "$($c.courseId) $($tp.id): $($tp.owner) both owns and applies this topic" }
        foreach ($a in $tp.appliedNotTaught) {
            if ($delivered -notcontains $a) { $fail += "$($c.courseId) $($tp.id): applied-not-taught unit $a is not a delivered unit of this course" }
        }
        if (-not $tp.rationale)    { $fail += "$($c.courseId) $($tp.id): no written reason for the ruling" }
        if (-not $tp.teachingRule) { $fail += "$($c.courseId) $($tp.id): no teaching rule for the units that apply it" }
        if ($tp.kind -notin @('shared-scaffold','commodity-parallel','progressive-depth','regulatory-recall')) {
            $fail += "$($c.courseId) $($tp.id): unknown kind '$($tp.kind)'"
        }
    }
    if ($ids.Count -ne ($ids | Select-Object -Unique).Count) { $fail += "$($c.courseId): duplicate topic id" }

    foreach ($k in $t.unitTopicIndex.PSObject.Properties) {
        $expectOwn = @($t.topics | Where-Object { $_.owner -eq $k.Name } | ForEach-Object { $_.id })
        $expectApp = @($t.topics | Where-Object { $_.appliedNotTaught -contains $k.Name } | ForEach-Object { $_.id })
        if (($k.Value.owns -join ',') -ne ($expectOwn -join ','))            { $fail += "$($c.courseId): unitTopicIndex owns list for $($k.Name) disagrees with the topic list" }
        if (($k.Value.appliedNotTaught -join ',') -ne ($expectApp -join ',')) { $fail += "$($c.courseId): unitTopicIndex applied list for $($k.Name) disagrees with the topic list" }
    }



    # ORDER: a topic's owner must not be delivered AFTER a unit that only
    # applies it. A learner cannot recall what they have not met, so an owner
    # scheduled later than an applier means the applier has to teach it after
    # all - the duplication this registry removes, reintroduced by the ruling.
    #
    # WHAT COUNTS AS ORDER DEPENDS ON THE MODEL, and getting this wrong buries
    # the real findings in noise. A cluster or theme is a BLOCK of weeks with
    # no stated order inside it, so only the cluster NUMBER is comparable and
    # two units in one cluster are simultaneous. A timetable or an explicit
    # delivery sequence is ordered unit by unit and the position is real.
    $rank = @{}
    if ($c.sequencing.model -in @('cluster','theme')) {
        foreach ($u in $c.units) { if ($null -ne $u.cluster) { $rank[$u.code] = [int]$u.cluster } }
    } elseif ($c.sequencing.model -in @('timetable','sequence')) {
        foreach ($u in $c.units) { if ($null -ne $u.sequence) { $rank[$u.code] = [int]$u.sequence } }
    }
    foreach ($tp in $t.topics) {
        if (-not $rank.ContainsKey($tp.owner)) { continue }
        $early = @($tp.appliedNotTaught | Where-Object { $rank.ContainsKey($_) -and $rank[$_] -lt $rank[$tp.owner] })
        if ($early) {
            $warn += "$($c.courseId) $($tp.id) '$($tp.name)': owner $($tp.owner) is delivered AFTER $($early -join ', '), which only applies it - revisit the ruling against the delivery order"
        }
    }

    $df = Join-Path $AssetDir "topics/decisions/$($c.courseId).decisions.json"
    if (-not (Test-Path $df)) { $fail += "$($c.courseId): topic register exists but its decisions file does not - it cannot be rebuilt" }
}

Write-Host ""
Write-Host "checked $($courses.Count) courses, $checked course-unit rows"
if ($warn) { Write-Host ""; Write-Host "WARNINGS ($($warn.Count))" -ForegroundColor Yellow; $warn | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow } }
if ($fail) {
    Write-Host ""
    Write-Host "FAILURES ($($fail.Count))" -ForegroundColor Red
    $fail | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    exit 1
}
Write-Host ""
Write-Host "registry is consistent" -ForegroundColor Green
