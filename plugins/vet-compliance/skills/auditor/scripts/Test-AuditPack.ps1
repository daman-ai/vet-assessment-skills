<#
  Test-AuditPack.ps1 - the delivery gate. Runs the ledger rules at Phase 6, then
  reads the RENDERED files back and checks them against the same ledger.

  Reading the delivered files back is the point. A ledger that validates and a
  folder of deliverables that were rendered two edits ago are the failure this
  catches, and it is invisible from either side on its own.

  Writes 08-verification-report.md. Exit 0 clean, 1 blocked.

  Usage:
    .\Test-AuditPack.ps1 -Ledger assurance.json -Out .\deliverables
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Ledger,
    [string]$Out = '.\deliverables',
    # Deliverables expected for the phase reached. Phase 6 expects all of them.
    [int]$Phase = 0,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-Audit.ps1')

$l   = Read-Ledger -Path $Ledger
$req = Get-RequirementIndex
$src = Get-AuditSources
if ($Phase -le 0) { $Phase = if ($l.engagement.phase) { [int]$l.engagement.phase } else { 6 } }
if (-not (Test-Path -LiteralPath $Out)) { throw "Output folder not found: $Out" }
$Out = (Resolve-Path -LiteralPath $Out).Path

$issues = @(Test-LedgerRules -Ledger $l -Requirements $req -Phase $Phase -Sources $src)

# ------------------------------------------------------ rendered artefacts ---

$expected = @{
    1 = @('00-document-register.md')
    2 = @('00-document-register.md','01-gap-analysis')
    3 = @('00-document-register.md','01-gap-analysis','CHANGE-SUMMARY.md')
    4 = @('00-document-register.md','01-gap-analysis','CHANGE-SUMMARY.md','03-systems-design.md','04-compliance-calendar','INDICATORS.md')
    5 = @('00-document-register.md','01-gap-analysis','CHANGE-SUMMARY.md','03-systems-design.md','04-compliance-calendar','INDICATORS.md','06-risk-register','07-forward-plan.md','ROADMAP.md')
    6 = @('00-document-register.md','01-gap-analysis','CHANGE-SUMMARY.md','03-systems-design.md','04-compliance-calendar','INDICATORS.md','06-risk-register','07-forward-plan.md','ROADMAP.md','SOURCES.md')
}
$want = $expected[[Math]::Min($Phase, 6)]
$present = Get-ChildItem -LiteralPath $Out -File | ForEach-Object { $_.Name }
$parents = Get-ChildItem -LiteralPath (Split-Path -Parent (Resolve-Path -LiteralPath $Ledger)) -File -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }

foreach ($w in $want) {
    # Workbooks may have rendered as CSV; match on stem.
    $hit = @($present + $parents) | Where-Object { $_ -eq $w -or $_ -like "$w.*" -or $_ -like "$w*" }
    if (-not $hit) { $issues += New-Issue 'DeliverablesRendered' 'ERROR' $w 'expected deliverable not found' }
}

# ------------------------------------------------- disclaimer and staleness ---

$ledgerWrite = (Get-Item -LiteralPath $Ledger).LastWriteTime
foreach ($f in (Get-ChildItem -LiteralPath $Out -File -Include *.md, *.xlsx, *.csv -Recurse)) {
    # This gate writes 08 itself, so it is always newer than the ledger and
    # never evidence of a stale render.
    if ($f.Name -ne '08-verification-report.md' -and $f.LastWriteTime -lt $ledgerWrite.AddSeconds(-2)) {
        $issues += New-Issue 'DeliverablesRendered' 'ERROR' $f.Name ('rendered {0:n0} minute(s) before the ledger was last written. Re-render' -f ($ledgerWrite - $f.LastWriteTime).TotalMinutes)
    }
    if ($f.Extension -eq '.md') {
        $body = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
        if ($body -notmatch '(?i)not a regulatory determination') {
            $issues += New-Issue 'DisclaimerPresent' 'ERROR' $f.Name 'no not-a-regulatory-determination statement'
        }
        if ($body -match '(?<![A-Za-z0-9])\d{2}[A-Za-z]\d{7}(?![A-Za-z0-9])') {
            $issues += New-Issue 'NoPersonalData' 'ERROR' $f.Name 'a string shaped like a student or CoE identifier'
        }
        if ($body -match 'TODO') {
            $issues += New-Issue 'NoPlaceholders' 'ERROR' $f.Name 'contains TODO'
        }
    }
}

# ---------------------------------------------------------------- report ---

$report  = Write-IssueReport -Issues $issues -Quiet:$Quiet
$errors  = @($issues | Where-Object { $_.Severity -eq 'ERROR' })
$warns   = @($issues | Where-Object { $_.Severity -eq 'WARN' })
$unver   = @($l.findings | Where-Object { $_.citation -and -not $_.citation.verified })
$today   = Get-Date -Format 'yyyy-MM-dd'

$vr = New-Object System.Text.StringBuilder
[void]$vr.AppendLine('# 08 - Verification report')
[void]$vr.AppendLine()
[void]$vr.AppendLine("Engagement: $($l.engagement.name)  ·  Phase $Phase  ·  Gate run $today")
[void]$vr.AppendLine()
$allChecks = @('RequirementIdsResolve','CoverageComplete','MaturityBasis','EvidenceNeeded','GapTypeConsistent',
               'TreatmentCoverage','TreatmentsOwned','RisksReviewed','CitationClass','CitationVerified',
               'SourcesFresh','NoFabricatedClauses','DeliverablesRendered','DisclaimerPresent','NoPersonalData','NoPlaceholders','EntitiesVerified')

[void]$vr.AppendLine(('**{0}**  {1} error(s) and {2} warning(s) across {3} check(s).' -f
    $(if ($errors.Count) { 'BLOCKED' } else { 'PASS' }), $errors.Count, $warns.Count, $allChecks.Count))
[void]$vr.AppendLine()

[void]$vr.AppendLine('## Mechanical checks')
[void]$vr.AppendLine()
[void]$vr.AppendLine('| Check | Result | Detail |')
[void]$vr.AppendLine('|---|---|---|')
foreach ($c in $allChecks) {
    $hits = @($issues | Where-Object { $_.Check -eq $c })
    $e = @($hits | Where-Object { $_.Severity -eq 'ERROR' }).Count
    $res = if ($e) { "**FAIL** ($e)" } elseif ($hits.Count) { "warn ($($hits.Count))" } else { 'pass' }
    $detail = if ($hits.Count) { (($hits | Select-Object -First 3 | ForEach-Object { "$($_.Where): $($_.Message)" }) -join ' · ') } else { '' }
    if ($detail.Length -gt 300) { $detail = $detail.Substring(0, 300) + '...' }
    [void]$vr.AppendLine("| $c | $res | $detail |")
}

[void]$vr.AppendLine()
[void]$vr.AppendLine('## Citations')
[void]$vr.AppendLine()
$cited = @($l.findings | Where-Object { $_.citation -and $_.citation.ref })
[void]$vr.AppendLine(("{0} of the {1} findings that carry a citation were verified against the instrument during this engagement. {2} finding(s) carry no citation, which is correct for anything classed GOOD PRACTICE." -f
    ($cited.Count - $unver.Count), $cited.Count, (@($l.findings).Count - $cited.Count)))
if ($unver.Count) {
    [void]$vr.AppendLine()
    [void]$vr.AppendLine('Not verified this run - treat each as unconfirmed until it is fetched:')
    [void]$vr.AppendLine()
    foreach ($f in $unver) { [void]$vr.AppendLine("- **$($f.id)** $($f.requirement) - cites ``$($f.citation.source) $($f.citation.ref)``") }
}
[void]$vr.AppendLine()
[void]$vr.AppendLine('The gate checks the SHAPE of a citation, not its truth. It can tell that a')
[void]$vr.AppendLine('reference looks like an Outcome Standards reference; it cannot tell whether the')
[void]$vr.AppendLine('Standard says what the finding claims. That check is done by hand.')

if (@($l.assumptions).Count) {
    [void]$vr.AppendLine()
    [void]$vr.AppendLine('## Assumptions')
    [void]$vr.AppendLine()
    foreach ($a in @($l.assumptions)) {
        [void]$vr.AppendLine("**$($a.id)** - $($a.assumption)")
        [void]$vr.AppendLine()
        [void]$vr.AppendLine("*If wrong:* $($a.ifWrong)")
        [void]$vr.AppendLine()
    }
}

if (@($l.decisions).Count) {
    [void]$vr.AppendLine('## Decisions for a human')
    [void]$vr.AppendLine()
    [void]$vr.AppendLine('| Id | Question | Who decides | Why it matters | Blocks |')
    [void]$vr.AppendLine('|---|---|---|---|---|')
    foreach ($d in @($l.decisions)) {
        [void]$vr.AppendLine("| $($d.id) | $($d.question) | $($d.whoDecides) | $($d.why) | $((@($d.blocks) -join ', ')) |")
    }
    [void]$vr.AppendLine()
}

$deferred = @($l.findings | Where-Object { [string]$_.priority -in @('Medium','Watch') -and @($_.treatments).Count -eq 0 -and [string]$_.gapType -ne 'none' })
if ($deferred.Count) {
    [void]$vr.AppendLine('## Gaps with no treatment')
    [void]$vr.AppendLine()
    [void]$vr.AppendLine('Legitimate if deliberate. Say why each is deferred and give it a review date,')
    [void]$vr.AppendLine('or it reads as an accidentally dropped gap.')
    [void]$vr.AppendLine()
    foreach ($f in $deferred) { [void]$vr.AppendLine("- **$($f.id)** $($f.requirement) ($($f.entity), $($f.priority)) - $($f.gapType)") }
    [void]$vr.AppendLine()
}

[void]$vr.AppendLine('---')
[void]$vr.AppendLine()
[void]$vr.AppendLine('*Internal working material. Not a regulatory determination, not legal advice, and it does not bind the regulator. Requirements are cited to the instruments in the source register, checked on the date shown.*')

$vrPath = Join-Path $Out '08-verification-report.md'
$vr.ToString() | Out-File -LiteralPath $vrPath -Encoding utf8

if (-not $Quiet) {
    Write-Host ''
    Write-Host "Report  $vrPath"
    if ($errors.Count -eq 0) { Write-Host ("PASS   {0} warning(s)" -f $warns.Count) -ForegroundColor Green }
    else { Write-Host ("BLOCKED   {0} error(s), {1} warning(s)" -f $errors.Count, $warns.Count) -ForegroundColor Red }
    Write-Host ''
}

if ($errors.Count -gt 0) { exit 1 }
exit 0
