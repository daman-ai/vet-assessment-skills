# Checks every course record against the national packaging rules published on
# training.gov.au: the stated total, and whether every CORE unit is present.
# A missing core unit means the qualification cannot be issued, whatever else is right.
$ErrorActionPreference = 'Stop'
$assets = Join-Path $env:USERPROFILE '.claude\skills\tas\assets'
$out    = Join-Path $PSScriptRoot 'packaging-audit.txt'
$cache  = Join-Path $PSScriptRoot 'qual-xml'
New-Item -ItemType Directory -Force -Path $cache | Out-Null

$lines = @("Course records checked against national packaging rules, $(Get-Date -Format 'yyyy-MM-dd HH:mm')", "")

$quals = @{}
foreach ($f in (Get-ChildItem (Join-Path $assets 'courses') -Filter '*.json' | Sort-Object Name)) {
    $c = Get-Content $f.FullName -Raw | ConvertFrom-Json
    if (-not $quals.ContainsKey($c.qualificationCode)) { $quals[$c.qualificationCode] = @() }
    $quals[$c.qualificationCode] += $c
}

foreach ($qc in ($quals.Keys | Sort-Object)) {
    $xmlFile = Join-Path $cache "$qc.xml"
    if (-not (Test-Path $xmlFile)) {
        try {
            $m = Invoke-RestMethod -Uri "https://training.gov.au/api/training/$qc`?api-version=1.0&include=all" -TimeoutSec 45 -Headers @{Accept='application/json'}
            $rel = $m.releases | Sort-Object releaseNumber -Descending | Select-Object -First 1
            $r = Invoke-RestMethod -Uri "https://training.gov.au/api/training/$qc/releases/$($rel.releaseNumber)`?include=All&api-version=1.0" -TimeoutSec 60 -Headers @{Accept='application/json'}
            $x = $r.assets | Where-Object { $_.name -like '*.xml' } | Select-Object -First 1
            if (-not $x) { $lines += "$qc : no XML published on training.gov.au - cannot check"; continue }
            Invoke-WebRequest -Uri $x.url -TimeoutSec 90 -UseBasicParsing -OutFile $xmlFile
        } catch {
            $lines += "$qc : could not fetch from training.gov.au - $($_.Exception.Message)"
            continue
        }
    }
    $raw = [System.IO.File]::ReadAllText($xmlFile)
    $txt = ($raw -replace '<[^>]*>', ' ') -replace '\s+', ' '

    # stated total
    $total = $null
    if ($txt -match '(\d+)\s+units?\s+must\s+be\s+completed') { $total = [int]$Matches[1] }

    # core list: everything between "Core units" and the first "Elective"
    $core = @()
    $i = $txt.IndexOf('Core units')
    if ($i -lt 0) { $i = $txt.IndexOf('Core Units') }
    if ($i -ge 0) {
        $seg = $txt.Substring($i)
        $j = $seg.IndexOf('Elective')
        if ($j -gt 0) { $seg = $seg.Substring(0, $j) }
        $core = @([regex]::Matches($seg, '\b[A-Z]{3}[A-Z]{0,4}\d{3,5}[A-Z]?\b') | ForEach-Object { $_.Value } | Sort-Object -Unique)
    }

    $lines += "=== $qc   national rule: $(if($total){"$total units"}else{'total not parsed'});  core units found: $($core.Count)"
    foreach ($c in $quals[$qc]) {
        $codes = @($c.units | ForEach-Object { $_.code })
        $problems = @()
        if ($total -and $c.unitCount -ne $total) { $problems += "records $($c.unitCount) units, national rule states $total" }
        if ($core.Count) {
            $miss = @($core | Where-Object { $codes -notcontains $_ })
            if ($miss.Count) { $problems += "MISSING CORE UNIT(S): $($miss -join ', ')" }
        }
        $notNamed = @()
        foreach ($u in $codes) { if ($txt -notmatch [regex]::Escape($u)) { $notNamed += $u } }
        if ($notNamed.Count) { $problems += "not named in the qualification (check the free-elective clause): $($notNamed -join ', ')" }

        if ($problems.Count) {
            $lines += "  $($c.courseId)  [$($c.institute)]"
            foreach ($p in $problems) { $lines += "      - $p" }
        } else {
            $lines += "  $($c.courseId)  ok"
        }
    }
    $lines += ""
    Start-Sleep -Milliseconds 150
}

[System.IO.File]::WriteAllLines($out, $lines, (New-Object System.Text.UTF8Encoding($false)))
"wrote packaging-audit.txt"
