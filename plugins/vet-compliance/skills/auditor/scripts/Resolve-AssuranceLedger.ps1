<#
  Resolve-AssuranceLedger.ps1 - validate assurance.json and report coverage.

  Run this at the END OF EVERY PHASE, not only before delivery. It costs
  seconds, and it catches the orphaned requirement id before that finding has
  been rendered into six deliverables that all agree with each other and are all
  wrong.

  Exit code 0 clean, 1 errors. Warnings never block.

  Usage:
    .\Resolve-AssuranceLedger.ps1 -Ledger assurance.json -Phase 2
    .\Resolve-AssuranceLedger.ps1 -Ledger assurance.json          # phase from the ledger
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Ledger,
    [int]$Phase = 0,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-Audit.ps1')

$l    = Read-Ledger -Path $Ledger
$req  = Get-RequirementIndex
$src  = Get-AuditSources
if ($Phase -le 0) { $Phase = if ($l.engagement.phase) { [int]$l.engagement.phase } else { 6 } }

if (-not $Quiet) {
    Write-Host ""
    Write-Host ("Ledger  {0}" -f (Resolve-Path -LiteralPath $Ledger).Path)
    Write-Host ("Phase   {0}    run date {1}" -f $Phase, $l.engagement.runDate)
    Write-Host ("Assets  {0} requirements across OS, CS, NC and ESOS" -f $req.Count)
    Write-Host ""
}

$issues = @(Test-LedgerRules -Ledger $l -Requirements $req -Phase $Phase -Sources $src)
$report = Write-IssueReport -Issues $issues -Quiet:$Quiet

# ------------------------------------------------------------- coverage ---

if (-not $Quiet -and $Phase -ge 2) {
    Write-Host ""
    Write-Host "Coverage and maturity"
    foreach ($e in @($l.entities)) {
        $mine = @($l.findings | Where-Object { [string]$_.entity -eq [string]$e.id })
        if ($mine.Count -eq 0) { Write-Host ("  {0}: no findings" -f $e.id); continue }

        $inScope = 0
        foreach ($rid in $req.Keys) { if (@($e.frameworks) -contains $req[$rid].Framework) { $inScope++ } }
        $excluded = @($e.outOfScope).Count
        $avg = ($mine | Measure-Object -Property maturity -Average).Average

        Write-Host ("  {0}: {1} finding(s) of {2} in scope ({3} excluded), mean maturity {4:n1}" -f $e.id, $mine.Count, $inScope, $excluded, $avg)

        $byM = $mine | Group-Object maturity | Sort-Object Name
        $mline = ($byM | ForEach-Object { "{0}:{1}" -f $_.Name, $_.Count }) -join '  '
        Write-Host ("      maturity  {0}" -f $mline)

        $pline = ('Critical {0}  High {1}  Medium {2}  Watch {3}' -f
            @($mine | Where-Object { $_.priority -eq 'Critical' }).Count,
            @($mine | Where-Object { $_.priority -eq 'High' }).Count,
            @($mine | Where-Object { $_.priority -eq 'Medium' }).Count,
            @($mine | Where-Object { $_.priority -eq 'Watch' }).Count)
        Write-Host ("      priority  {0}" -f $pline)

        $fives = @($mine | Where-Object { [int]$_.maturity -eq 5 })
        if ($fives.Count -and $Phase -le 2) {
            Write-Warning ("  {0}: {1} finding(s) rated 5 in a first pass. Nothing is self-assuring on first inspection - check you have not rated a design." -f $e.id, $fives.Count)
        }
    }

    $cited = @($l.findings | Where-Object { $_.citation -and $_.citation.ref })
    $unver = @($cited | Where-Object { -not $_.citation.verified })
    Write-Host ""
    Write-Host ("Citations  {0} of {1} cited findings verified against the instrument this run ({2} finding(s) carry no citation)" -f
        ($cited.Count - $unver.Count), $cited.Count, (@($l.findings).Count - $cited.Count))
}

if (-not $Quiet) {
    Write-Host ""
    if ($report.Errors -eq 0) {
        Write-Host ("PASS   {0} warning(s)" -f $report.Warnings) -ForegroundColor Green
    } else {
        Write-Host ("FAIL   {0} error(s), {1} warning(s)" -f $report.Errors, $report.Warnings) -ForegroundColor Red
    }
    Write-Host ""
}

if ($report.Errors -gt 0) { exit 1 }
exit 0
