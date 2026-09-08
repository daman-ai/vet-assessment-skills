<#
    Build-TopicMap.ps1 - render the registry as the document a human reads:
    one Markdown topic map per course, plus an index across all of them.

    The JSON is what the skills read. This is what a trainer, a validator or an
    auditor reads, and it must say the same thing - so it is GENERATED from the
    JSON and never edited by hand. Editing the Markdown produces a second
    source of truth that disagrees with the one the builds use.
#>
[CmdletBinding()]
param([string] $AssetDir, [string] $DocDir)

$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $AssetDir) { $AssetDir = Join-Path $root '../assets' }
if (-not $DocDir)   { $DocDir   = Join-Path $root '../docs' }
if (-not (Test-Path $DocDir)) { New-Item -ItemType Directory -Path $DocDir -Force | Out-Null }

$prov = (Get-Content -LiteralPath (Join-Path $AssetDir 'providers.json') -Raw -Encoding UTF8 | ConvertFrom-Json).providers
$courses = @(Get-ChildItem (Join-Path $AssetDir 'courses') -Filter *.json | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
}) | Sort-Object provider, qualificationCode

$idx = New-Object System.Text.StringBuilder
[void]$idx.AppendLine('# Curriculum registry')
[void]$idx.AppendLine('')
[void]$idx.AppendLine('Which institute delivers which qualification, which units each one carries, and which unit owns each shared topic so it is taught once.')
[void]$idx.AppendLine('')
[void]$idx.AppendLine('**Generated. Do not edit.** Run `scripts/Build-TopicMap.ps1` after changing anything in `assets/`.')
[void]$idx.AppendLine('')

# GROUPED BY INSTITUTE, NOT BY REGISTERED ENTITY. A qualification delivered by
# two institutes is listed under BOTH, and the row says which institute's TAS
# the record was actually built from - the other inherits it until its own TAS
# is on file.
$institutes = @(
    @{ key='Adelaide Construction Institute'; provider='ACI' }
    @{ key='Adelaide Culinary Institute';     provider='ACI' }
    @{ key='Meridian Vocational College';     provider='MVC' }
)
foreach ($inst in $institutes) {
    $mine = @($courses | Where-Object { $_.institute -eq $inst.key })
    if (-not $mine) { continue }
    $p = $prov.($inst.provider)
    [void]$idx.AppendLine("## $($inst.key)")
    [void]$idx.AppendLine('')
    [void]$idx.AppendLine("RTO $($p.rtoCode) &middot; CRICOS $($p.cricosCode) &middot; $($p.legalEntity)")
    [void]$idx.AppendLine('')
    [void]$idx.AppendLine('| Qualification | Level | Weeks | Units | Delivered | Topics | Record source |')
    [void]$idx.AppendLine('|---|---|---:|---:|---:|---:|---|')
    foreach ($c in ($mine | Sort-Object qualificationCode)) {
        $tf = Join-Path $AssetDir "topics/$($c.courseId).topics.json"
        $tc = if (Test-Path $tf) { (Get-Content -LiteralPath $tf -Raw -Encoding UTF8 | ConvertFrom-Json).topicCount } else { 0 }
        $src = 'own TAS'
        [void]$idx.AppendLine("| [$($c.qualificationCode) $($c.qualificationTitle)]($($c.courseId).md) | $($c.aqfLevel) | $($c.durationWeeks) | $($c.unitCount) | $($c.deliveredCount) | $tc | $src |")
    }
    [void]$idx.AppendLine('')
}

$shared = @($courses | Where-Object { $_.siblingCourse })
if ($shared) {
    [void]$idx.AppendLine('## Delivered by two institutes')
    [void]$idx.AppendLine('These qualifications are on the prospectus of both an ACI institute and Meridian, and **each institute has its own Training and Assessment Strategy**. Comparing the two showed they are not interchangeable: for SIT40521 and SIT50422 the institutes select DIFFERENT ELECTIVES, and a different elective set changes which unit owns a shared topic. Each therefore holds its own register. SIT30821 is the exception - both select the identical 25 units in the identical order, and that was confirmed by comparison rather than assumed.')
    [void]$idx.AppendLine('')
    [void]$idx.AppendLine('')
    [void]$idx.AppendLine('| Qualification | Register | Counterpart register |')
    [void]$idx.AppendLine('|---|---|---|')
    foreach ($c in ($shared | Where-Object { $_.courseId -lt $_.siblingCourse } | Sort-Object qualificationCode)) {
        $sib = $courses | Where-Object { $_.courseId -eq $c.siblingCourse } | Select-Object -First 1
        [void]$idx.AppendLine("| $($c.qualificationCode) $($c.qualificationTitle) | [$($c.institute)]($($c.courseId).md) | [$($sib.institute)]($($sib.courseId).md) |")
    }
    [void]$idx.AppendLine('')
}

# open items across the registry
$allOpen = @()
foreach ($c in $courses) {
    foreach ($oi in $c.openItems) { $allOpen += [pscustomobject]@{ Course=$c.courseId; Item=$oi; Blocking=($oi -match '^BLOCKING') } }
    foreach ($s in $c.supersededUnits) { $allOpen += [pscustomobject]@{ Course=$c.courseId; Item="$s is SUPERSEDED on training.gov.au and is still listed as a delivered unit."; Blocking=$true } }
}
if ($allOpen) {
    [void]$idx.AppendLine('## Open items')
    [void]$idx.AppendLine('')
    [void]$idx.AppendLine('Everything the registry found that someone has to decide or fix. Blocking items stop a build.')
    [void]$idx.AppendLine('')
    foreach ($o in ($allOpen | Sort-Object { -[int]$_.Blocking })) {
        $tag = if ($o.Blocking) { '**BLOCKING**' } else { 'Open' }
        [void]$idx.AppendLine("- $tag &middot; **$($o.Course)** &mdash; $($o.Item)")
    }
    [void]$idx.AppendLine('')
}
[void]$idx.AppendLine("_Generated $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')) from the Training and Assessment Strategies named in each course record, and from training.gov.au._")
[System.IO.File]::WriteAllText((Join-Path $DocDir 'README.md'), $idx.ToString(), (New-Object System.Text.UTF8Encoding $false))
Write-Host "  docs/README.md"

foreach ($c in $courses) {
    $p  = $prov.($c.provider)
    $tn = if ($c.brandVariant) { $p.variants.($c.brandVariant).tradingName } else { $p.tradingName }
    $tf = Join-Path $AssetDir "topics/$($c.courseId).topics.json"
    $t  = if (Test-Path $tf) { Get-Content -LiteralPath $tf -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }

    $m = New-Object System.Text.StringBuilder
    [void]$m.AppendLine("# $($c.qualificationCode) $($c.qualificationTitle)")
    [void]$m.AppendLine('')
    [void]$m.AppendLine("**$($c.institute)** &middot; RTO $($p.rtoCode) &middot; CRICOS $($p.cricosCode) &middot; $($c.aqfLevel) &middot; $($c.durationWeeks) weeks")
    [void]$m.AppendLine('')
    if ($c.siblingCourse) {
        [void]$m.AppendLine("> **The other institute delivers this qualification too, from its own strategy.** See ``$($c.siblingCourse)``. The two hold SEPARATE registers: their elective selections and their delivery orders differ, and a different elective set changes which unit owns a shared topic. Never read one register for the other.")
        [void]$m.AppendLine('')
    }
    [void]$m.AppendLine('')
    [void]$m.AppendLine("$($c.packagingRule.rule) $($c.unitCount) units are recorded; **$($c.deliveredCount) are delivered**.")
    if ($c.priorCourse) { [void]$m.AppendLine("Learners arrive from **$($c.priorCourse)**; units marked *credit-transfer* below are already held and are not taught here.") }
    [void]$m.AppendLine('')
    foreach ($n in $c.notes) { [void]$m.AppendLine("> $n"); [void]$m.AppendLine('') }

    if ($c.openItems -or $c.supersededUnits) {
        [void]$m.AppendLine('## Open items')
        [void]$m.AppendLine('')
        foreach ($s in $c.supersededUnits) { [void]$m.AppendLine("- **BLOCKING** &mdash; $s is SUPERSEDED on training.gov.au and is still a delivered unit.") }
        foreach ($oi in $c.openItems) { [void]$m.AppendLine("- $oi") }
        [void]$m.AppendLine('')
    }

    [void]$m.AppendLine('## Units')
    [void]$m.AppendLine('')
    if ($c.sequencing.model -eq 'none') {
        [void]$m.AppendLine('_No delivery sequence is recorded for this course &mdash; see Open items._')
        [void]$m.AppendLine('')
    }
    [void]$m.AppendLine('| # | Code | Title | Core/Elective | Delivery | Cluster | Prerequisite |')
    [void]$m.AppendLine('|---:|---|---|---|---|---|---|')
    $i = 0
    $unitRows = if ($c.sequencing.model -in @('timetable','sequence')) {
        @($c.units | Sort-Object @{ e = { if ($null -eq $_.sequence) { 9999 } else { [int]$_.sequence } } })
    } else { $c.units }
    foreach ($u in $unitRows) {
        $i++
        $cl = if ($u.weeks) { "weeks $($u.weeks)" }
              elseif ($null -ne $u.cluster) {
                  $cn = ($c.sequencing.clusters | Where-Object { $_.number -eq $u.cluster } | Select-Object -First 1).name
                  "$($u.cluster) $cn"
              } else { '' }
        $pre = if ($u.prerequisites) { $u.prerequisites -join ', ' } else { '' }
        $flag = if ($u.status -ne 'current') { " **($($u.statusLabel))**" } else { '' }
        [void]$m.AppendLine("| $i | $($u.code) | $($u.title)$flag | $($u.designation) | $($u.deliveryStatus) | $cl | $pre |")
    }
    [void]$m.AppendLine('')

    if ($c.sequencing.clusters) {
        $label = if ($c.sequencing.model -eq 'theme') { 'Themes' } else { 'Clusters' }
        [void]$m.AppendLine("## $label")
        [void]$m.AppendLine('')
        foreach ($cl in $c.sequencing.clusters) {
            $extra = @()
            if ($cl.weeks) { $extra += "weeks $($cl.weeks)" }
            if ($cl.nominalHours) { $extra += "$($cl.nominalHours) hrs" }
            $sfx = if ($extra) { ' (' + ($extra -join ', ') + ')' } else { '' }
            [void]$m.AppendLine("**$($cl.number). $($cl.name)**$sfx")
            [void]$m.AppendLine('')
            if ($cl.focus) { [void]$m.AppendLine("$($cl.focus)"); [void]$m.AppendLine('') }
            [void]$m.AppendLine('`' + ($cl.units -join '`, `') + '`')
            [void]$m.AppendLine('')
        }
    }

    if ($t) {
        [void]$m.AppendLine('## Topic map &mdash; who teaches what, once')
        [void]$m.AppendLine('')
        [void]$m.AppendLine("$($t.topicCount) shared topics were found across this course's delivered units. Each has exactly one owner. Every other unit listed **applies** the topic and must not re-teach or re-assess it.")
        [void]$m.AppendLine('')
        [void]$m.AppendLine('| Topic | Kind | Taught in full by | Applied, not taught, in |')
        [void]$m.AppendLine('|---|---|---|---|')
        foreach ($tp in $t.topics) {
            $ap = if ($tp.appliedNotTaught) { '`' + ($tp.appliedNotTaught -join '`, `') + '`' } else { '&mdash;' }
            [void]$m.AppendLine("| **$($tp.name)** | $($tp.kind) | `$($tp.owner)` | $ap |")
        }
        [void]$m.AppendLine('')

        [void]$m.AppendLine('### The rulings in full')
        [void]$m.AppendLine('')
        foreach ($tp in $t.topics) {
            [void]$m.AppendLine("#### $($tp.id) &mdash; $($tp.name)")
            [void]$m.AppendLine('')
            [void]$m.AppendLine("*$($tp.kind)* &middot; taught in full by **$($tp.owner)**")
            [void]$m.AppendLine('')
            [void]$m.AppendLine("**Why here.** $($tp.rationale)")
            [void]$m.AppendLine('')
            [void]$m.AppendLine("**What the other units do.** $($tp.teachingRule)")
            [void]$m.AppendLine('')
            if ($tp.tgaAnchors) {
                [void]$m.AppendLine('Anchored to training.gov.au:')
                [void]$m.AppendLine('')
                foreach ($a in ($tp.tgaAnchors | Select-Object -First 3)) {
                    [void]$m.AppendLine("- $($a.unit) $($a.section): $($a.text)")
                }
                [void]$m.AppendLine('')
            }
        }

        [void]$m.AppendLine('## Per unit')
        [void]$m.AppendLine('')
        [void]$m.AppendLine('| Unit | Teaches in full | Must not re-teach |')
        [void]$m.AppendLine('|---|---|---|')
        foreach ($k in $t.unitTopicIndex.PSObject.Properties) {
            $o = if ($k.Value.owns) { ($k.Value.owns -join ', ') } else { '&mdash;' }
            $a = if ($k.Value.appliedNotTaught) { ($k.Value.appliedNotTaught -join ', ') } else { '&mdash;' }
            [void]$m.AppendLine("| **$($k.Name)** | $o | $a |")
        }
        [void]$m.AppendLine('')
    }

    [void]$m.AppendLine('---')
    [void]$m.AppendLine('')
    [void]$m.AppendLine("Unit list and sequencing from `$($c.source.tasFile)` (SHA256 `$($c.source.tasSha256)`). Unit titles, prerequisites and currency from training.gov.au. Generated $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')) &mdash; do not edit.")
    [void]$m.AppendLine('')

    [System.IO.File]::WriteAllText((Join-Path $DocDir "$($c.courseId).md"), $m.ToString(), (New-Object System.Text.UTF8Encoding $false))
    Write-Host ("  docs/{0}.md" -f $c.courseId)
}
