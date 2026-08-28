<#
    Stage-Ledger.ps1

    Records which build stages actually ran, and refuses delivery when a
    blocking stage was skipped or has gone stale.

    WHY THIS EXISTS. Stages 5 and 6 are judgement stages: a person or an agent
    reads the document and reports what is wrong with it. Nothing in the file
    system changes when they are skipped, so every structural gate still passes
    and the build still looks finished. On 27 August 2026 a guide shipped with
    Stage 5 never run and Stage 6 reduced to a cross-reference check, and it
    carried a fabricated legal requirement to the page. No gate could have seen
    it, because a wrong temperature is well-formed XML.

    So the fact that a stage ran is itself recorded, and Stage 8 checks the
    record. A stage that ran and found nothing is a result. A stage with no
    record is a defect in the build.

    STALENESS. Stages 4 and 7 re-render the artefacts from a fresh template. A
    persona pass or an audit taken BEFORE the last render describes a document
    that no longer exists, so any Stage 5 or 6 record older than the newest
    render record is rejected as stale rather than accepted as done.

    Dot-source it, or run it directly to check a build directory.

    ASCII only in this file.
#>

[CmdletBinding()]
param(
    [string] $BuildDir,
    [switch] $Check
)

# Every stage that must have a record. Stage 7 is deliberately absent: a build
# with no findings needs no remediation round, so requiring one would push
# builds into inventing work. It still sorts into place when it does run.
$script:LedgerRequired = @('0','1','2','3','3b','4','4b','5','6','7b','8')
$script:LedgerOrder    = @('0','1','2','3','3b','4','4b','5','6','7','7b','8')
$script:LedgerRenders  = @('4','7')          # stages that re-render the artefacts
$script:LedgerBlocking = @('4','4b','5','6') # stages whose absence stops delivery

function Get-LedgerPath {
    param([Parameter(Mandatory)][string] $BuildDir)
    Join-Path $BuildDir 'stage-ledger.json'
}

function New-StageLedger {
    <# Creates an empty ledger. Safe to call on an existing one - it will not overwrite. #>
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [Parameter(Mandatory)][string] $Unit
    )
    $p = Get-LedgerPath -BuildDir $BuildDir
    if (Test-Path -LiteralPath $p) { return $p }
    $obj = [pscustomobject]@{ unit = $Unit; created = (Get-Date).ToUniversalTime().ToString('o'); records = @() }
    $obj | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $p -Encoding UTF8
    return $p
}

function Add-StageRecord {
    <#
      Records one stage. Call it the moment the stage finishes, not at the end
      of the build - a record written from memory at the end is a record of
      what was intended, not of what happened.

      -Status  pass | fail | n-a | skipped
               'skipped' is honest and allowed; it just will not pass Test-StageLedger
               for a blocking stage. Use 'n-a' where the stage genuinely does not
               apply to this build, and always give -Note saying why.
      -Verdict Stage 6 only: the compliance judgement, verbatim.
      -Findings Count of findings raised. Zero is a real result and is recorded as one.
    #>
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [Parameter(Mandatory)][string] $Stage,
        [Parameter(Mandatory)][string] $Name,
        [ValidateSet('pass','fail','n-a','skipped')][string] $Status = 'pass',
        [int]    $Round    = 0,
        [int]    $Findings = 0,
        [string] $Verdict,
        [string] $Note
    )
    $p = Get-LedgerPath -BuildDir $BuildDir
    if (-not (Test-Path -LiteralPath $p)) { throw "No stage ledger at $p. Call New-StageLedger first." }
    $l = Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json

    $rec = [ordered]@{
        stage    = $Stage
        name     = $Name
        status   = $Status
        round    = $Round
        findings = $Findings
        utc      = (Get-Date).ToUniversalTime().ToString('o')
    }
    if ($Verdict) { $rec.verdict = $Verdict }
    if ($Note)    { $rec.note    = $Note }

    $l.records = @($l.records) + [pscustomobject]$rec
    $l | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $p -Encoding UTF8
    Write-Verbose ("stage {0} recorded: {1}" -f $Stage, $Status)
}

function Test-StageLedger {
    <#
      Returns a result object with .Ok and .Problems. Run it in Stage 8, before
      reporting delivery.
    #>
    param([Parameter(Mandatory)][string] $BuildDir)

    $problems = @()
    $p = Get-LedgerPath -BuildDir $BuildDir
    if (-not (Test-Path -LiteralPath $p)) {
        return [pscustomobject]@{
            Ok = $false
            Problems = @('No stage ledger exists. There is no record that any review stage ran, so delivery cannot be confirmed.')
            Records = @()
        }
    }

    $l    = Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json
    $recs = @($l.records)

    # Latest record per stage wins - a later round supersedes an earlier one.
    $latest = @{}
    foreach ($r in $recs) {
        $s = [string]$r.stage
        if (-not $latest.ContainsKey($s) -or
            ([datetime]$r.utc) -gt ([datetime]$latest[$s].utc)) { $latest[$s] = $r }
    }

    foreach ($s in $script:LedgerRequired) {
        if (-not $latest.ContainsKey($s)) {
            $problems += "Stage $s has no record. It either did not run or was not recorded; either way delivery cannot claim it."
            continue
        }
        $r = $latest[$s]
        if ($r.status -eq 'fail') {
            $problems += "Stage $s ($($r.name)) is recorded as FAILED and was never brought to pass."
        }
        elseif ($r.status -eq 'skipped' -and $script:LedgerBlocking -contains $s) {
            $n = if ($r.note) { " - $($r.note)" } else { '' }
            $problems += "Stage $s ($($r.name)) is recorded as SKIPPED and it is a blocking stage$n"
        }
    }

    # Staleness: a review that predates the last render describes a document
    # that no longer exists.
    $renderTimes = @()
    foreach ($s in $script:LedgerRenders) {
        if ($latest.ContainsKey($s)) { $renderTimes += [datetime]$latest[$s].utc }
    }
    if ($renderTimes.Count) {
        $lastRender = ($renderTimes | Sort-Object -Descending)[0]
        foreach ($s in @('4b','5','6')) {
            if (-not $latest.ContainsKey($s)) { continue }
            if (([datetime]$latest[$s].utc) -lt $lastRender) {
                $problems += ("Stage {0} ({1}) ran at {2} but the artefacts were re-rendered at {3}. That verdict is stale - re-run it against the current documents." -f `
                    $s, $latest[$s].name, ([datetime]$latest[$s].utc).ToString('u'), $lastRender.ToString('u'))
            }
        }
    }

    # Stage 6 must carry an actual verdict, and it must not be a failing one.
    if ($latest.ContainsKey('6')) {
        $a = $latest['6']
        if (-not $a.verdict) {
            $problems += 'Stage 6 ran but recorded no compliance verdict. An audit without a stated judgement is not an audit.'
        }
        elseif ("$($a.verdict)" -match '(?i)not\s+compliant') {
            $problems += "Stage 6 verdict is '$($a.verdict)'. Remediate and re-audit before delivery."
        }
    }

    [pscustomobject]@{
        Ok       = ($problems.Count -eq 0)
        Problems = $problems
        Records  = ($latest.Values | Sort-Object {
                        $i = [array]::IndexOf($script:LedgerOrder, [string]$_.stage)
                        if ($i -lt 0) { 99 } else { $i } })
    }
}

function Write-StageLedgerReport {
    param([Parameter(Mandatory, ValueFromPipeline)] $Result)
    process {
        Write-Host ''
        Write-Host 'STAGE LEDGER' -ForegroundColor Cyan
        foreach ($r in $Result.Records) {
            $col = switch ("$($r.status)") {
                'pass'    { 'Green' }
                'n-a'     { 'DarkGray' }
                'skipped' { 'Yellow' }
                default   { 'Red' }
            }
            $extra = ''
            if ($null -ne $r.findings -and [int]$r.findings -gt 0) { $extra = " ($($r.findings) finding(s))" }
            if ($r.verdict) { $extra += " [$($r.verdict)]" }
            Write-Host ("  {0,-4} {1,-34} {2,-8}{3}" -f $r.stage, $r.name, $r.status, $extra) -ForegroundColor $col
        }
        if ($Result.Ok) {
            Write-Host 'LEDGER PASS - every blocking stage ran against the current documents.' -ForegroundColor Green
        } else {
            Write-Host ''
            foreach ($p in $Result.Problems) { Write-Host "  X $p" -ForegroundColor Red }
            Write-Host ("LEDGER FAIL - {0} problem(s)." -f $Result.Problems.Count) -ForegroundColor Red
        }
    }
}

if ($Check -and $BuildDir) {
    $r = Test-StageLedger -BuildDir $BuildDir
    $r | Write-StageLedgerReport
    if (-not $r.Ok) { exit 6 }
}
