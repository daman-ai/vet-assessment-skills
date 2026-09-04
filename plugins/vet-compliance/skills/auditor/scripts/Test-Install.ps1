<#
  Test-Install.ps1 - prove the toolchain before an engagement, not during one.

  Checks PowerShell 5.1, that every script carries a UTF-8 BOM and parses, that
  every asset is valid JSON with unique requirement ids, that every citation
  source named in an asset exists in sources.json, how stale the sources are,
  and whether Word and Excel are available.

  The BOM check is not fussiness: PowerShell 5.1 reads a BOM-less file as ANSI,
  which either fails to parse with errors pointing nowhere near the cause, or
  parses and mojibakes every dash it writes into a deliverable.

  Usage:  powershell -File .\Test-Install.ps1
#>
[CmdletBinding()]
param([switch]$Quiet)

$ErrorActionPreference = 'Stop'
$root  = Split-Path -Parent $PSScriptRoot
$fails = @()
$warns = @()

function Ok   { param($m) if (-not $Quiet) { Write-Host "  ok    $m" } }
function Fail { param($m) $script:fails += $m; Write-Host "  FAIL  $m" -ForegroundColor Red }
function Warn { param($m) $script:warns += $m; Write-Host "  warn  $m" -ForegroundColor Yellow }

Write-Host ''
Write-Host 'auditor - install check'
Write-Host ''

# --- PowerShell --------------------------------------------------------------
Write-Host 'PowerShell'
$v = $PSVersionTable.PSVersion
if ($v.Major -ge 5) { Ok "version $v" } else { Fail "version $v; 5.1 or later required" }

# --- scripts -----------------------------------------------------------------
Write-Host 'Scripts'
$scripts = Get-ChildItem -LiteralPath $PSScriptRoot -Filter *.ps1 -File
foreach ($s in $scripts) {
    $bytes = [System.IO.File]::ReadAllBytes($s.FullName)
    if ($bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
        Fail "$($s.Name) has no UTF-8 BOM"
    }
    $errors = $null
    [void][System.Management.Automation.PSParser]::Tokenize((Get-Content -LiteralPath $s.FullName -Raw), [ref]$errors)
    if ($errors -and $errors.Count) { Fail "$($s.Name) does not parse: $($errors[0].Message)" }
}
if (-not ($fails | Where-Object { $_ -like '*.ps1*' })) { Ok "$($scripts.Count) script(s), BOM present, all parse" }

# --- assets ------------------------------------------------------------------
Write-Host 'Assets'
$assetDir = Join-Path $root 'assets'
$needed = @('sources.json','requirements.outcome-standards-2025.json','requirements.compliance-2025.json','requirements.national-code-2018.json','obligations.calendar.json')
foreach ($n in $needed) {
    $p = Join-Path $assetDir $n
    if (-not (Test-Path -LiteralPath $p)) { Fail "missing asset $n"; continue }
    try { $null = Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Fail "$n is not valid JSON: $($_.Exception.Message)" }
}

if ($fails.Count -eq 0) {
    . (Join-Path $PSScriptRoot 'Lib-Audit.ps1')
    $req = Get-RequirementIndex
    $src = Get-AuditSources

    Ok "$($req.Count) requirements loaded"

    $byFramework = $req.Values | Group-Object Framework | Sort-Object Name
    foreach ($g in $byFramework) { Ok ("  {0}  {1}" -f $g.Name, $g.Count) }

    # The Outcome Standards are a fixed set. A change in the count means an
    # asset was edited, and that is worth noticing before an engagement.
    $os = @($req.Values | Where-Object { $_.Framework -eq 'OS' }).Count
    if ($os -ne 23) { Warn "expected 23 Outcome Standards (1.1-4.4), found $os" } else { Ok 'Outcome Standards 1.1-4.4 complete' }
    $nc = @($req.Values | Where-Object { $_.Framework -eq 'NC' }).Count
    if ($nc -ne 11) { Warn "expected 11 National Code Standards, found $nc" } else { Ok 'National Code Standards 1-11 complete' }

    $known = @($src.sources | ForEach-Object { $_.id })
    foreach ($r in $req.Values) {
        if ($r.Source -and $known -notcontains $r.Source) { Fail "requirement $($r.Id) names source '$($r.Source)' which is not in sources.json" }
    }
    if ($fails.Count -eq 0) { Ok 'every requirement traces to a source' }

    Write-Host 'Source freshness'
    $now = Get-Date
    foreach ($s in @($src.sources)) {
        if (-not $s.checkedOn) { continue }
        $age = [int]($now - [datetime]::Parse($s.checkedOn)).TotalDays
        if ($age -gt 90) { Warn ("{0} checked {1} days ago - re-fetch and update checkedOn" -f $s.id, $age) }
        else { Ok ("{0} checked {1} days ago" -f $s.id, $age) }
    }
    $unverified = @($src.sources | Where-Object { -not $_.structureVerified })
    if ($unverified.Count) {
        Warn ("{0} source(s) have unverified structure - fetch before citing a clause: {1}" -f $unverified.Count, (($unverified | ForEach-Object { $_.id }) -join ', '))
    }
}

# --- references --------------------------------------------------------------
Write-Host 'References'
$refDir = Join-Path $root 'references'
$refs = @('framework.md','ledger.md','inventory.md','gap-analysis.md','document-uplift.md','systems-design.md','forward-plan.md','verification.md','entities.md','modes.md')
foreach ($r in $refs) { if (-not (Test-Path -LiteralPath (Join-Path $refDir $r))) { Fail "missing reference $r" } }
if (-not ($fails | Where-Object { $_ -like 'missing reference*' })) { Ok "$($refs.Count) reference(s) present" }

# --- Office ------------------------------------------------------------------
Write-Host 'Office'
foreach ($app in 'Excel','Word') {
    try {
        $com = New-Object -ComObject "$app.Application"
        $ver = $com.Version
        $com.Quit()
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($com)
        Ok "$app $ver available"
    } catch {
        Warn "$app not available. Workbooks fall back to CSV; .pdf, .doc and .xls cannot be text-scanned"
    }
}
[GC]::Collect(); [GC]::WaitForPendingFinalizers()

# --- result ------------------------------------------------------------------
Write-Host ''
if ($fails.Count -eq 0) {
    Write-Host ("PASS   {0} warning(s)" -f $warns.Count) -ForegroundColor Green
    Write-Host ''
    exit 0
}
Write-Host ("FAIL   {0} error(s), {1} warning(s)" -f $fails.Count, $warns.Count) -ForegroundColor Red
Write-Host ''
exit 1
