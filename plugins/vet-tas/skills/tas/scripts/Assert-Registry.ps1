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

# A retired course is kept on file so the decision stays reversible, but it is no longer
# delivered, so gating it would raise failures about training the RTO does not do.
$retiredCourses = @($courses | Where-Object { $_.retired })
$courses = @($courses | Where-Object { -not $_.retired })
if (-not $courses) { throw 'every course record is retired' }

foreach ($c in $courses) {
    $codes = @($c.units | ForEach-Object { $_.code })

    if ($codes.Count -ne ($codes | Select-Object -Unique).Count) {
        $fail += "$($c.courseId): a unit is listed twice"
    }
    if ($c.packagingRule.totalUnits -and $c.unitCount -ne $c.packagingRule.totalUnits) {
        $fail += "$($c.courseId): $($c.unitCount) units recorded but the packaging rule states $($c.packagingRule.totalUnits)"
    }
    # A newly added course has no TAS document yet - the registry record is what a TAS
    # will be written FROM. Test-Path throws on a null, so the two cases are separated.
    if (-not $c.source.tasFile) {
        $warn += "$($c.courseId): no TAS document exists yet - this record is the source for writing one"
    } elseif (-not (Test-Path $c.source.tasFile)) {
        $warn += "$($c.courseId): source TAS is not at $($c.source.tasFile) - the record still stands, but it can no longer be re-derived"
    }

    foreach ($u in $c.units) {
        $checked++
        $f = Join-Path $AssetDir "units/$($u.code).json"
        if (-not (Test-Path $f)) { $fail += "$($c.courseId): $($u.code) is not in the unit cache"; continue }
        $rec = Get-Content -LiteralPath $f -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($rec.title -ne $u.title) { $fail += "$($c.courseId): $($u.code) title disagrees with the cache" }
        if ($rec.status -ne 'current' -and $u.deliveryStatus -eq 'delivered') {
            # A superseded unit is normally a hard failure. The exception is a unit the
            # QUALIFICATION still names in its packaging rules: it must keep being
            # delivered as part of that qualification until the qualification itself is
            # reissued. Recording that on the unit as a supersession decision downgrades
            # the failure to a warning - but only until reviewBy. THE ACCEPTANCE EXPIRES,
            # which is the point: a decision to defer is not a decision to forget.
            $s = $u.supersession
            $accepted = $s -and $s.decision -eq 'continue-delivery' -and $s.reviewBy -and
                        ([datetime]::Parse($s.reviewBy) -ge (Get-Date).Date)
            if ($accepted) {
                $warn += "$($c.courseId): $($u.code) is $($rec.statusLabel), delivered under a recorded supersession decision - equivalent to $($s.equivalentTo), review by $($s.reviewBy)"
            } else {
                $fail += "$($c.courseId): $($u.code) is $($rec.statusLabel) on training.gov.au and is still a DELIVERED unit" +
                         $(if ($s) { " - the supersession decision recorded on $($s.decidedOn) lapsed on $($s.reviewBy). Transition to $($s.equivalentTo) or re-date the decision." } else { "" })
            }
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
        # In an add-on course, a topic may be owned UPSTREAM: its owning unit is credit
        # transfer here because the student was taught it in the prior qualification. The
        # ruling still belongs in this register - units here recall the topic - but the
        # owner is legitimately not delivered. It must name where it was taught.
        if ($tp.ownedUpstream) {
            if (-not $tp.upstreamCourse) { $fail += "$($c.courseId) $($tp.id): held on entry but does not say which course teaches it" }
            if ($delivered -contains $tp.owner) { $fail += "$($c.courseId) $($tp.id): marked held on entry, but $($tp.owner) IS delivered here" }
            if (-not $tp.appliedNotTaught.Count) { $fail += "$($c.courseId) $($tp.id): held on entry and nothing here recalls it - it does not belong in this register" }
        }
        elseif ($delivered -notcontains $tp.owner) { $fail += "$($c.courseId) $($tp.id): owner $($tp.owner) is not a delivered unit of this course" }
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
    # SINCE 8 SEPTEMBER 2026 THIS IS A FAILURE, NOT A WARNING, AND IT READS THE UNIT
    # SEQUENCE RATHER THAN THE CLUSTER NUMBER. Every course is now sequenced strictly
    # from its constraints, so "two units in one theme are simultaneous" no longer
    # holds - and it was the loophole that let three SIT30821 rulings sit unresolved
    # for months. A topic is taught in full before any unit recalls it, full stop.
    $rank = @{}
    foreach ($u in $c.units) { if ($null -ne $u.sequence) { $rank[$u.code] = [int]$u.sequence } }
    foreach ($tp in $t.topics) {
        if (-not $rank.ContainsKey($tp.owner)) { continue }
        $early = @($tp.appliedNotTaught | Where-Object { $rank.ContainsKey($_) -and $rank[$_] -lt $rank[$tp.owner] })
        if ($early) {
            $fail += "$($c.courseId) $($tp.id) '$($tp.name)': owner $($tp.owner) is taught AFTER $($early -join ', '), which only recalls it"
        }
    }

    # PREREQUISITES, IN ORDER. training.gov.au decides these and they cannot move: a
    # prerequisite is either taught earlier in this course or held on entry by credit
    # transfer. Anything else means a learner meets a unit they cannot yet attempt.
    $heldOnEntry = @($c.units | Where-Object { $_.deliveryStatus -ne 'delivered' } | ForEach-Object { $_.code })
    foreach ($u in $c.units) {
        $uf = Join-Path $AssetDir "units/$($u.code).json"
        if (-not (Test-Path $uf)) { continue }
        if (-not $rank.ContainsKey($u.code)) { continue }
        foreach ($p in (Get-Content -LiteralPath $uf -Raw -Encoding UTF8 | ConvertFrom-Json).prerequisites) {
            if ($rank.ContainsKey($p.code)) {
                if ($rank[$p.code] -gt $rank[$u.code]) {
                    $fail += "$($c.courseId): $($u.code) is taught at #$($rank[$u.code]) but its prerequisite $($p.code) is taught later at #$($rank[$p.code])"
                }
            } elseif ($heldOnEntry -notcontains $p.code) {
                $fail += "$($c.courseId): $($u.code) requires $($p.code), which this course neither delivers nor holds on entry"
            }
        }
    }

    # THEMES MUST COVER THE COURSE. Every delivered unit sits in exactly one theme, and
    # the week ranges run start to finish without a gap or an overlap.
    if (@($c.sequencing.clusters).Count) {
        $placed = @(); foreach ($cl in $c.sequencing.clusters) { $placed += $cl.units }
        $del = @($c.units | Where-Object { $_.deliveryStatus -eq 'delivered' } | ForEach-Object { $_.code })
        foreach ($x in $del)    { if ($placed -notcontains $x) { $fail += "$($c.courseId): $x is delivered but sits in no theme" } }
        foreach ($x in $placed) { if ($del -notcontains $x)    { $fail += "$($c.courseId): $x sits in a theme but is not delivered" } }
        if ($placed.Count -ne (@($placed | Select-Object -Unique).Count)) { $fail += "$($c.courseId): a unit appears in more than one theme" }

        $prev = 0; $ok = $true
        foreach ($cl in ($c.sequencing.clusters | Sort-Object number)) {
            if ($cl.weeks -match '^(\d+)\s*-\s*(\d+)$') {
                if ([int]$Matches[1] -ne $prev + 1) { $fail += "$($c.courseId): theme $($cl.number) starts at week $($Matches[1]) but the previous theme ended at week $prev"; $ok = $false }
                $prev = [int]$Matches[2]
            } else { $ok = $false }
        }
        if ($ok -and $c.durationWeeks -and $prev -ne $c.durationWeeks) {
            $fail += "$($c.courseId): the themes end at week $prev but the course runs $($c.durationWeeks) weeks"
        }
    }

    $df = Join-Path $AssetDir "topics/decisions/$($c.courseId).decisions.json"
    if (-not (Test-Path $df)) { $fail += "$($c.courseId): topic register exists but its decisions file does not - it cannot be rebuilt" }
}

# ---------------------------------------------------------------------------
# HARMONISATION. RTO decision of 8 September 2026: where a qualification is
# delivered by two institutes the unit set follows Meridian and ONLY THE BRANDING
# DIFFERS. Two records that must stay identical will drift the moment someone
# edits one and not the other, and nothing else in this file would notice - the
# separate records were originally justified BECAUSE the institutes differed.
# ---------------------------------------------------------------------------
function Get-UnitSignature($cc)  { ($cc.units | Sort-Object code | ForEach-Object { "$($_.code)/$($_.designation)/$($_.deliveryStatus)/$($_.sequence)/$($_.cluster)" }) -join ';' }
function Get-ThemeSignature($cc) { ($cc.sequencing.clusters | Sort-Object number | ForEach-Object { "$($_.number)|$($_.name)|$($_.weeks)|$($_.units -join ',')" }) -join ' || ' }
function Get-RulingSignature($tt) { ($tt | Sort-Object id | ForEach-Object { "$($_.id)=$($_.owner)|$((@($_.appliedNotTaught) | Sort-Object) -join ',')" }) -join ' ; ' }

$pairSeen = @{}
foreach ($c in $courses) {
    if (-not $c.siblingCourse -or $pairSeen[$c.courseId]) { continue }
    $sib = $courses | Where-Object { $_.courseId -eq $c.siblingCourse } | Select-Object -First 1
    if (-not $sib) { $fail += "$($c.courseId): names sibling $($c.siblingCourse), which is not in the registry"; continue }
    $pairSeen[$c.courseId] = $true; $pairSeen[$sib.courseId] = $true

    if ((Get-UnitSignature $c) -ne (Get-UnitSignature $sib)) {
        $fail += "HARMONISATION $($c.qualificationCode): $($c.courseId) and $($sib.courseId) differ on units, designations, delivery status or position"
    }
    if ((Get-ThemeSignature $c) -ne (Get-ThemeSignature $sib)) {
        $fail += "HARMONISATION $($c.qualificationCode): $($c.courseId) and $($sib.courseId) differ on themes, names or week ranges"
    }
    if ($c.durationWeeks -ne $sib.durationWeeks) {
        $fail += "HARMONISATION $($c.qualificationCode): durations differ - $($c.courseId) $($c.durationWeeks) weeks, $($sib.courseId) $($sib.durationWeeks) weeks"
    }
    $ta = Join-Path $AssetDir "topics/$($c.courseId).topics.json"
    $tb = Join-Path $AssetDir "topics/$($sib.courseId).topics.json"
    if ((Test-Path $ta) -and (Test-Path $tb)) {
        $ra = @((Get-Content -LiteralPath $ta -Raw -Encoding UTF8 | ConvertFrom-Json).topics)
        $rb = @((Get-Content -LiteralPath $tb -Raw -Encoding UTF8 | ConvertFrom-Json).topics)
        if ((Get-RulingSignature $ra) -ne (Get-RulingSignature $rb)) {
            $fail += "HARMONISATION $($c.qualificationCode): $($c.courseId) and $($sib.courseId) differ on topic rulings - $($ra.Count) against $($rb.Count)"
        }
    }
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
