# Scope check, done properly: the endpoint returns the whole list in one call and ignores
# $filter, so the list is fetched once and searched locally. An entry whose endDate has
# passed is no longer on scope, so expiry is checked as well as presence.
$ErrorActionPreference = 'Stop'
$assets = Join-Path $env:USERPROFILE '.claude\skills\tas\assets\courses'
$today  = (Get-Date).Date

$scope = @{}
foreach ($rto in '45797','45039') {
    $r = Invoke-RestMethod -Uri "https://training.gov.au/api/organisation/$rto/scope?api-version=1.0" -TimeoutSec 60 -Headers @{Accept='application/json'}
    $m = @{}
    foreach ($i in $r.value) {
        $expired = $false
        if ($i.endDate) { try { $expired = ([datetime]$i.endDate).Date -lt $today } catch {} }
        $m[$i.code] = [pscustomobject]@{ type=$i.componentTypeLabel; status=$i.statusLabel; end=$i.endDate; expired=$expired; implicit=$i.isImplicit; extent=$i.extentLabel }
    }
    $scope[$rto] = $m
    $units = 0; $quals = 0; $exp = 0
    foreach ($k in $m.Keys) { if ($m[$k].type -eq 'Unit') { $units++ } elseif ($m[$k].type -eq 'Qualification') { $quals++ }; if ($m[$k].expired) { $exp++ } }
    "RTO $rto : $($m.Count) entries - $quals qualifications, $units units, $exp expired"
}
""

$rtoOf = @{ 'ACI'='45797'; 'MVC'='45039' }
$problems = 0
foreach ($cf in (Get-ChildItem $assets -Filter '*.json' | Sort-Object Name)) {
    $c = Get-Content $cf.FullName -Raw | ConvertFrom-Json
    $rto = $rtoOf[$c.provider]; $m = $scope[$rto]
    $issues = @()

    if (-not $m.ContainsKey($c.qualificationCode)) { $issues += "qualification $($c.qualificationCode) NOT on scope" }
    elseif ($m[$c.qualificationCode].expired) { $issues += "qualification $($c.qualificationCode) scope ENDED $($m[$c.qualificationCode].end)" }

    foreach ($u in ($c.units | Where-Object { $_.deliveryStatus -eq 'delivered' })) {
        if (-not $m.ContainsKey($u.code)) { $issues += "$($u.code) not listed on scope" }
        elseif ($m[$u.code].expired) { $issues += "$($u.code) scope ENDED $($m[$u.code].end)" }
    }
    if ($issues.Count) {
        $problems++
        "{0,-15} RTO {1}" -f $c.courseId, $rto
        foreach ($i in $issues) { "      $i" }
    }
}
if (-not $problems) { "every delivered unit and every qualification is on scope and unexpired" }
""
"--- units the harmonisation adds ---"
foreach ($t in @(@('SITHKOP012','45039'), @('BSBTWK501','45797'), @('SITXINV007','45797'))) {
    $m = $scope[$t[1]]
    if ($m.ContainsKey($t[0])) { $e = $m[$t[0]]; "  {0,-12} RTO {1}: ON SCOPE ({2}, {3}, ends {4})" -f $t[0], $t[1], $e.type, $e.status, $e.end }
    else { "  {0,-12} RTO {1}: NOT ON SCOPE - application to ASQA required" -f $t[0], $t[1] }
}
