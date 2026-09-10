# For an elective that is delivered but NOT on the RTO's scope, find the replacements
# that are BOTH listed in the qualification's national elective bank AND already on that
# RTO's scope - so the qualification becomes awardable without an application to ASQA.
$ErrorActionPreference = 'Stop'
$xmlDir = Join-Path $PSScriptRoot 'qual-xml'
$assets = Join-Path $env:USERPROFILE '.claude\skills\tas\assets'
$today  = (Get-Date).Date

function Get-Scope($rto) {
    $r = Invoke-RestMethod -Uri "https://training.gov.au/api/organisation/$rto/scope?api-version=1.0" -TimeoutSec 60 -Headers @{Accept='application/json'}
    $m = @{}
    foreach ($i in $r.value) {
        $exp = $false
        if ($i.endDate) { try { $exp = ([datetime]$i.endDate).Date -lt $today } catch {} }
        if (-not $exp -and $i.componentTypeLabel -eq 'Unit of competency') { $m[$i.code] = $i.title }
    }
    return $m
}
function Get-ElectiveBank($qc) {
    $t = ((Get-Content (Join-Path $xmlDir "$qc.xml") -Raw -Encoding UTF8) -replace '<[^>]*>', ' ') -replace '\s+', ' '
    $i = $t.IndexOf('Elective'); if ($i -lt 0) { return @() }
    $seg = $t.Substring($i)
    # stop before the modification-history / mapping tail
    $j = $seg.IndexOf('Modification History'); if ($j -gt 0) { $seg = $seg.Substring(0, $j) }
    return @([regex]::Matches($seg, '\b[A-Z]{3}[A-Z]{0,4}\d{3,5}[A-Z]?\b') | ForEach-Object { $_.Value } | Sort-Object -Unique)
}

$cases = @(
  @{ course='ACI-CPC40120'; rto='45797'; qual='CPC40120'; drop='BSBESB401' },
  @{ course='MVC-BSB50420'; rto='45039'; qual='BSB50420'; drop='BSBTEC404' }
)

foreach ($c in $cases) {
    $scope = Get-Scope $c.rto
    $bank  = Get-ElectiveBank $c.qual
    $rec   = Get-Content (Join-Path $assets "courses\$($c.course).json") -Raw | ConvertFrom-Json
    $have  = @($rec.units | ForEach-Object { $_.code })

    "=== $($c.course)  drop $($c.drop)"
    "    qualification elective bank: $($bank.Count) codes;  RTO $($c.rto) has $($scope.Count) current units on scope"

    $ok = @($bank | Where-Object { $scope.ContainsKey($_) -and $have -notcontains $_ })
    "    ON SCOPE, IN THE ELECTIVE BANK, NOT ALREADY IN THE COURSE: $($ok.Count)"
    foreach ($u in ($ok | Sort-Object)) { "        {0,-12} {1}" -f $u, $scope[$u] }
    ""
}
