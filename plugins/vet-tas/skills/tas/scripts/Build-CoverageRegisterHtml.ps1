<#
    Build-CoverageRegisterHtml.ps1 - regenerate the data block inside
    docs/Curriculum-Coverage-Register.html from the registry.

    THE PAGE USED TO BE HAND-MAINTAINED, and it drifted: on 9 September 2026 it
    was found carrying six superseded topics and fourteen stale rulings, because
    it had been published from .topics.json files that had not been rebuilt since
    their decisions files changed. Nothing regenerated it, so nothing caught it.

    This script is that missing step. Run it after Build-TopicRegister.ps1 and
    Build-TopicMap.ps1, as the last step of "Adding or changing a course".

    IT REWRITES ONLY THE topics ARRAY of each course, and only for courses that
    have a register. Everything else in the data block - unitList, clusters,
    pathway, routes and the derived ordering fields - is computed elsewhere and
    is carried through untouched. A course with no register (MVC-SIT40721) keeps
    whatever the page already holds for it.
#>
[CmdletBinding()]
param(
    [string] $DocPath,
    [string] $TopicDir,
    [switch] $WhatIfOnly
)

$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $DocPath)  { $DocPath  = Join-Path $root '../docs/Curriculum-Coverage-Register.html' }
if (-not $TopicDir) { $TopicDir = Join-Path $root '../assets/topics' }

if (-not (Test-Path -LiteralPath $DocPath)) { throw "page not found: $DocPath" }

$raw = [System.IO.File]::ReadAllText($DocPath)
$m = [regex]::Match($raw, '(?s)(<script id="data" type="application/json">)(.*?)(</script>)')
if (-not $m.Success) { throw "no <script id=`"data`"> block in $DocPath - the page shape changed" }

$data = $m.Groups[2].Value | ConvertFrom-Json

# ---------------------------------------------------------------------------
# Build a whole course entry for a register the page does not yet carry.
#
# The ordering fields are DERIVED, not timetabled. Two things constrain a unit:
# a prerequisite, and a topic it recalls (whose owner must be taught first).
# earliest is 1 + the longest chain of things that must precede it; latest is
# the mirror. Together they are the slack bar - how far a unit can move before
# it breaks the partial order.
# ---------------------------------------------------------------------------
function New-CourseEntry {
    param($Course, $Reg)

    $units = @($Course.units)
    $n = $units.Count
    $codes = @($units | ForEach-Object { $_.code })

    $pre = @{}   # code -> units that must come BEFORE it, with a reason
    foreach ($u in $units) { $pre[$u.code] = @{} }

    foreach ($u in $units) {
        foreach ($p in @($u.prerequisites)) {
            $pc = if ($p -is [string]) { $p } else { $p.code }
            if ($codes -contains $pc) { $pre[$u.code][$pc] = 'prerequisite' }
        }
    }
    foreach ($t in @($Reg.topics)) {
        foreach ($a in @($t.appliedNotTaught)) {
            if (($codes -contains $a) -and ($codes -contains $t.owner) -and $a -ne $t.owner) {
                if (-not $pre[$a].ContainsKey($t.owner)) { $pre[$a][$t.owner] = 'teaches a topic it recalls' }
            }
        }
    }

    $succ = @{}
    foreach ($c in $codes) { $succ[$c] = @() }
    foreach ($c in $codes) { foreach ($p in $pre[$c].Keys) { $succ[$p] += $c } }

    $depthCache = @{}
    function Get-Depth { param($c)
        if ($depthCache.ContainsKey($c)) { return $depthCache[$c] }
        $depthCache[$c] = 1   # guards a cycle from recursing forever
        $best = 1
        foreach ($p in $pre[$c].Keys) { $d = (Get-Depth $p) + 1; if ($d -gt $best) { $best = $d } }
        $depthCache[$c] = $best
        return $best
    }
    $heightCache = @{}
    function Get-Height { param($c)
        if ($heightCache.ContainsKey($c)) { return $heightCache[$c] }
        $heightCache[$c] = 1
        $best = 1
        foreach ($sx in $succ[$c]) { $h = (Get-Height $sx) + 1; if ($h -gt $best) { $best = $h } }
        $heightCache[$c] = $best
        return $best
    }

    $unitList = @()
    foreach ($u in ($units | Sort-Object { $_.sequence })) {
        $after = @($pre[$u.code].Keys | Sort-Object | ForEach-Object { [ordered]@{ code = $_; why = $pre[$u.code][$_] } })
        $before = @($succ[$u.code] | Sort-Object | ForEach-Object { [ordered]@{ code = $_; why = $pre[$_][$u.code] } })
        $unitList += [ordered]@{
            code = $u.code; title = $u.title; des = $u.designation; ds = $u.deliveryStatus
            cl = $u.cluster; seq = $u.sequence; wk = $u.weeks; st = $u.status
            pre = @(@($u.prerequisites) | ForEach-Object { if ($_ -is [string]) { $_ } else { $_.code } })
            pos = $u.sequence
            earliest = (Get-Depth $u.code)
            latest = $n - (Get-Height $u.code) + 1
            after = $after; before = $before
        }
    }

    $clusters = @(@($Course.sequencing.clusters) | ForEach-Object {
        [ordered]@{ n = $_.number; name = $_.name; weeks = $_.weeks; units = @($_.units) }
    })

    $delivered = @($units | Where-Object { $_.deliveryStatus -eq 'delivered' }).Count
    [ordered]@{
        id = $Course.courseId; code = $Course.qualificationCode; title = $Course.qualificationTitle
        aqf = $Course.aqfLevel; weeks = $Course.durationWeeks; ptype = $Course.productType
        units = $Course.unitCount; delivered = $delivered; rule = $Course.packagingRule
        prior = $Course.priorCourse; prov = $Course.provider
        routes = [ordered]@{ via = $null; viaCode = $null; taught = $delivered; credited = ($units.Count - $delivered) }
        pathway = [ordered]@{ role = 'entry'; prior = @(); next = @(); direct = $false }
        seqModel = $Course.sequencing.model; inst = $Course.institute; sib = $Course.siblingCourse
        open = @($Course.openItems); superseded = @($Course.supersededUnits)
        clusters = $clusters; unitList = $unitList; topics = @()
    }
}

# A register the page has never carried is a whole course missing from the
# published document. Two were found this way on 9 September 2026.
$courseDir = Join-Path $root '../assets/courses'
$onPage = @($data.courses | ForEach-Object { $_.id })
$added = @()
foreach ($rp in (Get-ChildItem -LiteralPath $TopicDir -Filter *.topics.json | Sort-Object Name)) {
    $rid = $rp.Name -replace '\.topics\.json$', ''
    if ($onPage -contains $rid) { continue }
    $cp = Join-Path $courseDir "$rid.json"
    if (-not (Test-Path -LiteralPath $cp)) { continue }
    $cr = Get-Content -LiteralPath $cp -Raw -Encoding UTF8 | ConvertFrom-Json
    $rr = Get-Content -LiteralPath $rp.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $data.courses += [pscustomobject](New-CourseEntry -Course $cr -Reg $rr)
    $added += $rid
}
$data.courses = @($data.courses | Sort-Object { $_.id })

$touched = 0; $skipped = @(); $topicTotal = 0
foreach ($c in $data.courses) {
    $rp = Join-Path $TopicDir "$($c.id).topics.json"
    if (-not (Test-Path -LiteralPath $rp)) { $skipped += $c.id; continue }

    $reg = Get-Content -LiteralPath $rp -Raw -Encoding UTF8 | ConvertFrom-Json

    # `up` is the prior-course pointer for credit-transfer courses. It is computed
    # outside the register, so carry it forward by topic id rather than dropping it.
    $prior = @{}
    foreach ($t in $c.topics) { $prior[$t.id] = $t.up }

    $out = @()
    foreach ($rt in $reg.topics) {
        $out += [ordered]@{
            id    = $rt.id
            name  = $rt.name
            kind  = $rt.kind
            owner = $rt.owner
            app   = @($rt.appliedNotTaught)
            why   = $rt.rationale
            rule  = $rt.teachingRule
            depth = $rt.assessmentDepth
            bench = $rt.ownerBenchmark
            prov  = $rt.benchmarkProvenance
            cites = @($rt.citations | ForEach-Object { [ordered]@{ unit = $_.unit; status = $_.status } })
            excl  = @($rt.excludedUnits | ForEach-Object { [ordered]@{ unit = $_.unit; reason = $_.reason } })
            up    = $(if ($prior.ContainsKey($rt.id)) { $prior[$rt.id] } else { $null })
        }
    }
    $c.topics = $out
    $topicTotal += $out.Count
    $touched++
}

$data.generated = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

$json = $data | ConvertTo-Json -Depth 25 -Compress
$null = $json | ConvertFrom-Json   # fail here rather than in a browser

if ($WhatIfOnly) {
    Write-Host ("  would rewrite {0} courses, {1} topics ({2} skipped: {3})" -f $touched, $topicTotal, $skipped.Count, ($skipped -join ', '))
    return
}

$new = $raw.Substring(0, $m.Groups[2].Index) + $json + $raw.Substring($m.Groups[2].Index + $m.Groups[2].Length)
[System.IO.File]::WriteAllText($DocPath, $new, (New-Object System.Text.UTF8Encoding $false))

Write-Host ("  docs/Curriculum-Coverage-Register.html - {0} courses, {1} topics" -f $touched, $topicTotal)
if ($added) { Write-Host ("  ADDED, previously missing from the page: {0}" -f ($added -join ', ')) -ForegroundColor Yellow }
if ($skipped) { Write-Host ("  carried through unchanged (no register): {0}" -f ($skipped -join ', ')) }
Write-Host "  PUBLISH IT: the page on claude.ai is a separate copy and does not update itself."
