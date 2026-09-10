# Prerequisites are served on the RELEASE endpoint, not the metadata one, which is what
# the harvester reads. This re-checks every cached unit's prerequisites against the same
# endpoint the cache was built from, so a disagreement here is a real disagreement.
$ErrorActionPreference = 'Stop'
$assets = Join-Path $env:USERPROFILE '.claude\skills\tas\assets'
$out    = Join-Path $PSScriptRoot 'prereq-verification.txt'
$Base   = 'https://training.gov.au/api'

$used = @{}
foreach ($f in (Get-ChildItem (Join-Path $assets 'courses') -Filter '*.json')) {
    $c = Get-Content $f.FullName -Raw | ConvertFrom-Json
    foreach ($u in $c.units) { $used[$u.code] = $true }
}

$lines = @("Prerequisites verified against the training.gov.au release endpoint on $(Get-Date -Format 'yyyy-MM-dd HH:mm')", "")
$issues = 0; $checked = 0; $failed = @()

foreach ($code in ($used.Keys | Sort-Object)) {
    $cf = Join-Path $assets "units/$code.json"
    if (-not (Test-Path $cf)) { continue }
    $cache = Get-Content $cf -Raw | ConvertFrom-Json
    try {
        $meta = Invoke-RestMethod -Uri "$Base/training/$code`?api-version=1.0&include=all" -TimeoutSec 45 -Headers @{ Accept='application/json' }
    } catch { $failed += $code; continue }
    $checked++

    # preRequisites is an OBJECT wrapping the list, not a list.
    $live = @($meta.preRequisites.preRequisites | ForEach-Object { $_.code } | Where-Object { $_ } | Sort-Object -Unique)
    $cached = @($cache.prerequisites | ForEach-Object { $_.code } | Sort-Object -Unique)

    if (($live -join ',') -ne ($cached -join ',')) {
        $lines += "$code  $($cache.title)"
        $lines += "    cache: [$($cached -join ', ')]"
        $lines += "    tga:   [$($live -join ', ')]"
        $issues++
    }
    Start-Sleep -Milliseconds 80
}
$lines += ""
$lines += "checked $checked units, $issues prerequisite disagreements"
if ($failed.Count) { $lines += "unreachable: $($failed -join ', ')" }
[System.IO.File]::WriteAllLines($out, $lines, (New-Object System.Text.UTF8Encoding($false)))
"checked $checked, prereq disagreements $issues, unreachable $($failed.Count)"
