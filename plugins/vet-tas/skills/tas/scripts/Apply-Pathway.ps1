# Writes a derived pathway back into a course record: the delivery order, the theme a
# unit sits in, and the theme blocks themselves. Everything else in the record is left
# exactly as it was.
#
# Input is a plan file: { courseId, model, themes:[ { name, focus, weeks, hours, units:[codes] } ] }
# The order is the order of the themes and of the units within them.
[CmdletBinding()]
param([Parameter(Mandatory)][string] $PlanFile, [switch] $WhatIfOnly)

$ErrorActionPreference = 'Stop'
$repo   = Join-Path $env:USERPROFILE 'vet-assessment-skills\plugins\vet-tas\skills\tas'
$assets = Join-Path $repo 'assets'

$plans = Get-Content $PlanFile -Raw | ConvertFrom-Json
if ($plans -isnot [array]) { $plans = @($plans) }

foreach ($plan in $plans) {
    $cf = Join-Path $assets "courses/$($plan.courseId).json"
    if (-not (Test-Path $cf)) { throw "no such course record: $($plan.courseId)" }
    $c = Get-Content $cf -Raw | ConvertFrom-Json

    $delivered = @($c.units | Where-Object { $_.deliveryStatus -eq 'delivered' } | ForEach-Object { $_.code })
    $planned   = @($plan.themes | ForEach-Object { $_.units } | ForEach-Object { $_ })

    $missing = @($delivered | Where-Object { $planned -notcontains $_ })
    $extra   = @($planned   | Where-Object { $delivered -notcontains $_ })
    if ($missing.Count) { throw "$($plan.courseId): plan omits delivered units: $($missing -join ', ')" }
    if ($extra.Count)   { throw "$($plan.courseId): plan names units the course does not deliver: $($extra -join ', ')" }
    if ($planned.Count -ne (@($planned | Sort-Object -Unique).Count)) { throw "$($plan.courseId): a unit appears twice in the plan" }

    # sequence and cluster numbers follow the plan
    $seq = 0; $pos = @{}; $themeOf = @{}
    $n = 1
    foreach ($t in $plan.themes) {
        foreach ($u in $t.units) { $seq++; $pos[$u] = $seq; $themeOf[$u] = $n }
        $n++
    }

    foreach ($u in $c.units) {
        if ($pos.ContainsKey($u.code)) {
            $u.sequence = $pos[$u.code]
            $u.cluster  = $themeOf[$u.code]
        } else {
            # credit-transfer units are not taught, so they carry no place in the pathway
            $u.sequence = $null
            $u.cluster  = $null
        }
    }

    $clusters = @()
    $i = 1
    foreach ($t in $plan.themes) {
        $clusters += [ordered] @{
            number       = $i
            name         = $t.name
            focus        = $t.focus
            weeks        = $t.weeks
            nominalHours = $t.hours
            units        = @($t.units)
        }
        $i++
    }
    $c.sequencing.model    = if ($plan.model) { $plan.model } else { 'theme' }
    $c.sequencing.clusters = $clusters
    $c.sequencing.order    = @()

    if ($WhatIfOnly) {
        "{0}: {1} themes, {2} units sequenced" -f $plan.courseId, $clusters.Count, $seq
        continue
    }
    $json = $c | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($cf, $json, (New-Object System.Text.UTF8Encoding($false)))
    "{0}: wrote {1} themes, {2} units sequenced" -f $plan.courseId, $clusters.Count, $seq
}
