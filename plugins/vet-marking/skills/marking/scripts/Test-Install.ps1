<#
  Test-Install.ps1 — prove this skill works on THIS machine before it is used
  to mark anything.

  Run it once after copying the skill onto a new computer. It checks the things
  that are properties of the machine rather than of the skill, and the things
  that a file copy can quietly break.

  Usage:
    .\Test-Install.ps1
    .\Test-Install.ps1 -Full     # also builds the worked example and gates it
#>
[CmdletBinding()]
param([switch]$Full)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot

$pass = 0; $fail = 0; $warn = 0
function Say { param([string]$Status, [string]$Name, [string]$Detail)
    switch ($Status) { 'PASS' { $script:pass++ } 'FAIL' { $script:fail++ } 'WARN' { $script:warn++ } }
    Write-Output ("  {0,-4} {1,-26} {2}" -f $Status, $Name, $Detail)
}

Write-Output ''
Write-Output "MARKING SKILL — INSTALL CHECK"
Write-Output "  $root"
Write-Output ''

# ---------------------------------------------------------- 1. PowerShell ---

$psv = $PSVersionTable.PSVersion
if ($psv.Major -ge 5) { Say 'PASS' 'PowerShellVersion' "$psv" }
else { Say 'FAIL' 'PowerShellVersion' "$psv - 5.1 or later is required" }

# ------------------------------------------------------------- 2. the BOM ---
#
# The single most likely thing a file copy, a zip tool, an editor or a git
# checkout will break. Without it PowerShell 5.1 reads these scripts as ANSI:
# some fail to parse, and the ones that do not quietly write mojibake into
# every document they produce.

# EVERY .ps1 in the skill, not just scripts\. The example generator lives under
# examples\ and breaks the same way; a check that scans one folder proves the
# other folder nothing.
$allScripts = @(Get-ChildItem -LiteralPath $root -Filter '*.ps1' -File -Recurse)

$noBom = @()
foreach ($f in $allScripts) {
    $b = [System.IO.File]::ReadAllBytes($f.FullName)
    if (-not ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)) { $noBom += $f.Name }
}
if ($noBom.Count -eq 0) { Say 'PASS' 'ScriptsHaveUtf8Bom' "all $($allScripts.Count) scripts" }
else { Say 'FAIL' 'ScriptsHaveUtf8Bom' "missing on: $($noBom -join ', ')  -  re-copy them, or re-save as UTF-8 with BOM" }

# --------------------------------------------------------------- 3. parse ---

$bad = @()
foreach ($f in $allScripts) {
    $e = $null; $t = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$t, [ref]$e)
    if (@($e).Count) { $bad += "$($f.Name) ($(@($e).Count))" }
}
if ($bad.Count -eq 0) { Say 'PASS' 'ScriptsParse' 'every script parses' }
else { Say 'FAIL' 'ScriptsParse' ($bad -join ', ') }

# ----------------------------------------------------------------- 4. json ---

$badJson = @()
foreach ($j in @(Get-ChildItem "$root\assets\*.json") + @(Get-ChildItem "$root\examples\*.json" -ErrorAction SilentlyContinue)) {
    try { [void](Get-Content -Raw -Encoding UTF8 -LiteralPath $j.FullName | ConvertFrom-Json) }
    catch { $badJson += $j.Name }
}
if ($badJson.Count -eq 0) { Say 'PASS' 'ProfilesParse' 'every profile and example is valid JSON' }
else { Say 'FAIL' 'ProfilesParse' ($badJson -join ', ') }

# ------------------------------------------------------------ 5. templates ---

$missing = @()
foreach ($j in Get-ChildItem "$root\assets\rto.*.json") {
    $p = Get-Content -Raw -Encoding UTF8 -LiteralPath $j.FullName | ConvertFrom-Json
    if ($p.PSObject.Properties.Name.Contains('status') -and $p.status -eq 'awaiting-templates') { continue }
    foreach ($k in @('sar','amrr','feedback')) {
        $rel = $p.templates.$k.file
        if (-not $rel) { $missing += "$($p.key)/$k (not declared)"; continue }
        if (-not (Test-Path -LiteralPath (Join-Path "$root\assets" $rel))) { $missing += "$($p.key)/$k -> $rel" }
    }
}
if ($missing.Count -eq 0) { Say 'PASS' 'TemplatesPresent' 'every registered RTO has its three templates' }
else { Say 'FAIL' 'TemplatesPresent' ($missing -join '; ') }

# --------------------------------------------------------- 6. holiday table ---

try {
    . (Join-Path $PSScriptRoot 'Lib-Dates.ps1')
    $h = Import-PublicHolidays
    $thisYear = (Get-Date).Year
    if ($h.Years -contains $thisYear) { Say 'PASS' 'PublicHolidayTable' "$($h.Count) dates, covering $($h.Years -join ', ')" }
    else { Say 'WARN' 'PublicHolidayTable' "covers $($h.Years -join ', ') but not $thisYear - add the year before marking, verified against the state's gazetted list" }
} catch { Say 'FAIL' 'PublicHolidayTable' $_.Exception.Message }

# ------------------------------------------------------------- 7. the date maths ---

try {
    $d = Get-MarkingDates -MarkingDate ([datetime]'2026-09-02')
    $ok = ($d.AssessmentDateText -eq '19 / 08 / 2026') -and ($d.ResubmissionDueText -eq '09 / 09 / 2026')
    if ($ok) { Say 'PASS' 'DateMathsRegression' 'the worked example reproduces exactly' }
    else { Say 'FAIL' 'DateMathsRegression' "got assessment $($d.AssessmentDateText), resubmission $($d.ResubmissionDueText)" }
} catch { Say 'FAIL' 'DateMathsRegression' $_.Exception.Message }

# --------------------------------------------------------------- 8. Word ---
#
# Needed by the gate's OpensInWord check - the one that catches a document that
# is valid XML and still unopenable. Without Word that check degrades to a
# warning, and the skill is weaker but usable.

$word = $null
try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    Say 'PASS' 'WordAvailable' "$($word.Version) - the OpensInWord gate check will run"
} catch {
    Say 'WARN' 'WordAvailable' 'not installed - OpensInWord degrades to a WARN. Open one document by hand before issuing records.'
} finally {
    if ($word) { try { $word.Quit() } catch {}; [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) }
}

# -------------------------------------------------------------- 9. Excel ---
#
# Needed only by Import-WisenetMatrix.ps1, and only for a legacy .xls. Without
# it, export the WiseNet report as .xlsx elsewhere or supply the roll directly.

$excel = $null
try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    Say 'PASS' 'ExcelAvailable' "$($excel.Version) - the WiseNet matrix can be read"
} catch {
    Say 'WARN' 'ExcelAvailable' 'not installed - Import-WisenetMatrix.ps1 cannot read a .xls on this machine'
} finally {
    if ($excel) { try { $excel.Quit() } catch {}; [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) }
}

# ------------------------------------------------------- 10. the full build ---

if ($Full) {
    Write-Output ''
    Write-Output '  running the worked example end to end...'
    $tmp = Join-Path $env:TEMP ("marking_install_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        & (Join-Path $PSScriptRoot 'Resolve-MarkingLedger.ps1') -Path "$root\examples\ledger.example.json" -Out "$tmp\resolved.json" -Quiet | Out-Null
        & (Join-Path $PSScriptRoot 'Build-MarkingRecords.ps1') -Ledger "$tmp\resolved.json" -OutDir "$tmp\out" -SubmissionRoot "$root\examples" | Out-Null
        & (Join-Path $PSScriptRoot 'Test-MarkingRecords.ps1') -Ledger "$tmp\resolved.json" -Dir "$tmp\out" -Quiet | Out-Null
        if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) {
            $n = @(Get-ChildItem "$tmp\out\*.docx").Count
            Say 'PASS' 'WorkedExample' "$n documents built and the gate passed"
        } else {
            Say 'FAIL' 'WorkedExample' 'the gate failed - run Test-MarkingRecords.ps1 directly to see which check'
        }
    } catch {
        Say 'FAIL' 'WorkedExample' $_.Exception.Message
    } finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# --------------------------------------------------------------- verdict ---

Write-Output ''
if ($fail -eq 0) {
    Write-Output "INSTALL OK - $pass passed, $warn warning(s)."
    if (-not $Full) { Write-Output 'Run again with -Full to build the worked example and gate it.' }
} else {
    Write-Output "INSTALL INCOMPLETE - $fail check(s) failed, $pass passed, $warn warning(s)."
    Write-Output 'Fix the failures above before marking anything.'
}
Write-Output ''
if ($fail -gt 0) { exit 1 }
