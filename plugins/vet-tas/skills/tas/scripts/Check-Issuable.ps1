# Can each course, as recorded, actually award its qualification?
#
# Four things have to hold. Three of them this registry can answer:
#   1  the unit count matches the national packaging rule
#   2  every national CORE unit is present, delivered or credit-transferred
#   3  every DELIVERED unit is on that RTO's scope of registration
#   4  no delivered unit is superseded without a live, unexpired decision
#
# The fourth thing - that a learner was actually assessed and judged competent - is
# outside the registry and is not claimed here.
$ErrorActionPreference = 'Stop'
$assets = Join-Path $env:USERPROFILE '.claude\skills\tas\assets'
$xml    = Join-Path $PSScriptRoot 'qual-xml'
$today  = (Get-Date).Date

# scope, live from training.gov.au
$scope = @{}
foreach ($rto in '45797','45039') {
    $r = Invoke-RestMethod -Uri "https://training.gov.au/api/organisation/$rto/scope?api-version=1.0" -TimeoutSec 60 -Headers @{Accept='application/json'}
    $m = @{}
    foreach ($i in $r.value) {
        $exp = $false
        if ($i.endDate) { try { $exp = ([datetime]$i.endDate).Date -lt $today } catch {} }
        $m[$i.code] = $exp
    }
    $scope[$rto] = $m
}

function Get-NationalCore($qc) {
    $f = Join-Path $xml "$qc.xml"
    if (-not (Test-Path $f)) { return $null }
    $t = ((Get-Content $f -Raw -Encoding UTF8) -replace '<[^>]*>', ' ') -replace '\s+', ' '
    # "core units" appears both in the packaging PROSE ("24 core units 3 elective
    # units") and as the TABLE HEADING above the actual list. Take every occurrence,
    # read the segment after each up to the elective heading, and keep whichever
    # yields the most unit codes - the prose segment yields none.
    $best = @()
    foreach ($m in [regex]::Matches($t, '(?i)core\s+units?')) {
        $seg = $t.Substring($m.Index + $m.Length)
        $e = [regex]::Match($seg, '(?i)elective\s+units?')
        if ($e.Success -and $e.Index -gt 0) { $seg = $seg.Substring(0, $e.Index) }
        if ($seg.Length -gt 6000) { $seg = $seg.Substring(0, 6000) }
        $codes = @([regex]::Matches($seg, '\b[A-Z]{3}[A-Z]{0,4}\d{3,5}[A-Z]?\b') |
                   ForEach-Object { $_.Value } |
                   Where-Object { $_ -ne $qc } | Sort-Object -Unique)
        if ($codes.Count -gt $best.Count) { $best = $codes }
    }
    if ($best.Count -lt 2) { return $null }
    return $best
}
function Get-NationalTotal($qc) {
    $f = Join-Path $xml "$qc.xml"
    if (-not (Test-Path $f)) { return $null }
    $t = ((Get-Content $f -Raw -Encoding UTF8) -replace '<[^>]*>', ' ') -replace '\s+', ' '
    if ($t -match '(\d+)\s+units?\s+must\s+be\s+completed')              { return [int]$Matches[1] }
    if ($t -match 'competency\s+in:?\s*(\d+)\s+units?\s+of\s+competency') { return [int]$Matches[1] }
    if ($t -match '(?i)total\s+number\s+of\s+units\s*=\s*(\d+)')         { return [int]$Matches[1] }
    if ($t -match '(?i)competency\s+in\s+(\d+)\s+units?\s+of\s+competency') { return [int]$Matches[1] }
    return $null
}

$rtoOf = @{ 'ACI'='45797'; 'MVC'='45039' }
$rows = @()
foreach ($cf in (Get-ChildItem (Join-Path $assets 'courses') -Filter '*.json' | Sort-Object Name)) {
    $c = Get-Content $cf.FullName -Raw | ConvertFrom-Json
    $rto = $rtoOf[$c.provider]; $m = $scope[$rto]
    $all = @($c.units | ForEach-Object { $_.code })
    $del = @($c.units | Where-Object { $_.deliveryStatus -eq 'delivered' })

    $blockers = @(); $unknown = @()

    $total = Get-NationalTotal $c.qualificationCode
    if ($null -eq $total) { $unknown += 'national unit total could not be read from the published packaging' }
    elseif ($c.unitCount -ne $total) { $blockers += "records $($c.unitCount) units, national rule requires $total" }

    $core = Get-NationalCore $c.qualificationCode
    if ($null -eq $core) { $unknown += 'national core list could not be read from the published packaging' }
    else {
        $miss = @($core | Where-Object { $all -notcontains $_ })
        if ($miss.Count) { $blockers += "missing core unit(s): $($miss -join ', ')" }
    }

    if (-not $m.ContainsKey($c.qualificationCode)) { $blockers += "qualification not on RTO $rto scope" }
    elseif ($m[$c.qualificationCode]) { $blockers += "qualification scope has expired" }

    foreach ($u in $del) {
        if (-not $m.ContainsKey($u.code)) { $blockers += "delivers $($u.code), which is not on RTO $rto scope" }
        elseif ($m[$u.code]) { $blockers += "delivers $($u.code), whose scope has expired" }
        if ($u.status -ne 'current') {
            $s = $u.supersession
            $live = $s -and $s.decision -eq 'continue-delivery' -and $s.reviewBy -and ([datetime]$s.reviewBy).Date -ge $today
            if (-not $live) { $blockers += "delivers superseded $($u.code) with no live decision" }
        }
    }

    $verdict = if ($blockers.Count) { 'NO' } elseif ($unknown.Count) { 'PROBABLY' } else { 'YES' }
    $rows += [pscustomobject]@{ course=$c.courseId; qual=$c.qualificationCode; verdict=$verdict; blockers=$blockers; unknown=$unknown }
}

"{0,-15} {1,-11} {2}" -f 'COURSE','QUAL','CAN IT BE ISSUED?'
foreach ($r in $rows) {
    "{0,-15} {1,-11} {2}" -f $r.course, $r.qual, $r.verdict
    foreach ($b in $r.blockers) { "      BLOCKER  $b" }
    foreach ($u in $r.unknown)  { "      unverified  $u" }
}
""
"{0} yes, {1} probably (something could not be verified), {2} no" -f `
   @($rows | Where-Object { $_.verdict -eq 'YES' }).Count,
   @($rows | Where-Object { $_.verdict -eq 'PROBABLY' }).Count,
   @($rows | Where-Object { $_.verdict -eq 'NO' }).Count
