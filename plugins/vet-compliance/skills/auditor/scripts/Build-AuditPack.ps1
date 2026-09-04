<#
  Build-AuditPack.ps1 - render the mechanical deliverables from the ledger.

  Renders, and never authors:

    01-gap-analysis.xlsx        one sheet per entity, filterable, frozen header
    04-compliance-calendar.xlsx clocks and recurring obligations, per entity
    06-risk-register.xlsx       one sheet per entity
    ROADMAP.md                  treatment table, sequenced by due date
    INDICATORS.md               the leading indicator set

  The prose deliverables - 02 uplifted policies, 03 systems design, 07 forward
  plan - are written by hand and EMBED the two markdown fragments above. That
  keeps the tables and the narrative from disagreeing: there is one table and
  the narrative points at it.

  Excel COM writes the workbooks. Without Excel, -Csv writes the same data as
  CSV rather than failing, because a gap analysis in CSV is still a gap
  analysis and a gap analysis that did not render is nothing.

  Usage:
    .\Build-AuditPack.ps1 -Ledger assurance.json -Out .\deliverables
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Ledger,
    [string]$Out = '.\deliverables',
    [switch]$Csv,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-Audit.ps1')

$l   = Read-Ledger -Path $Ledger
$req = Get-RequirementIndex
$src = Get-AuditSources

New-Item -ItemType Directory -Path $Out -Force | Out-Null
$Out = (Resolve-Path -LiteralPath $Out).Path

$DISCLAIMER = 'Internal working material. Not a regulatory determination, not legal advice, and it does not bind the regulator. Requirements are cited to the instruments in the source register, checked on the date shown.'

# ------------------------------------------------------------------ excel ---

function Test-ExcelAvailable {
    try { $x = New-Object -ComObject Excel.Application; $x.Quit(); [void][Runtime.InteropServices.Marshal]::ReleaseComObject($x); return $true }
    catch { return $false }
}

function Write-Workbook {
    <#
      $Sheets is an ordered list of @{ Name = 'ACI'; Rows = <array of pscustomobject> }.
      Header row bolded and frozen, autofilter on, columns autofitted then capped
      so a long risk sentence does not make a 400-character column.
    #>
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][array]$Sheets)

    $excel = $null; $wb = $null
    try {
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        $wb = $excel.Workbooks.Add()

        while ($wb.Worksheets.Count -gt 1) { $wb.Worksheets.Item($wb.Worksheets.Count).Delete() }

        $i = 0
        foreach ($s in $Sheets) {
            $i++
            if ($i -eq 1) { $ws = $wb.Worksheets.Item(1) }
            else { $ws = $wb.Worksheets.Add([System.Reflection.Missing]::Value, $wb.Worksheets.Item($wb.Worksheets.Count)) }

            $name = ($s.Name -replace '[\\/\?\*\[\]:]', '-')
            if ($name.Length -gt 31) { $name = $name.Substring(0, 31) }
            $ws.Name = $name

            $rows = @($s.Rows)
            if ($rows.Count -eq 0) { $ws.Cells.Item(1,1).Value2 = 'No rows'; continue }

            $cols = @($rows[0].PSObject.Properties.Name)
            for ($c = 0; $c -lt $cols.Count; $c++) { $ws.Cells.Item(1, $c + 1).Value2 = $cols[$c] }

            for ($r = 0; $r -lt $rows.Count; $r++) {
                for ($c = 0; $c -lt $cols.Count; $c++) {
                    $v = $rows[$r].($cols[$c])
                    if ($v -is [array]) { $v = ($v -join '; ') }
                    # A leading = or + would be read as a formula.
                    $sv = [string]$v
                    if ($sv -match '^[=+\-@]') { $sv = "'" + $sv }
                    $ws.Cells.Item($r + 2, $c + 1).Value2 = $sv
                }
            }

            $hdr = $ws.Range($ws.Cells.Item(1,1), $ws.Cells.Item(1, $cols.Count))
            $hdr.Font.Bold = $true
            $ws.Range($ws.Cells.Item(1,1), $ws.Cells.Item($rows.Count + 1, $cols.Count)).AutoFilter() | Out-Null
            $ws.Activate()
            $excel.ActiveWindow.SplitRow = 1
            $excel.ActiveWindow.FreezePanes = $true
            $ws.Columns.AutoFit() | Out-Null
            for ($c = 1; $c -le $cols.Count; $c++) {
                if ($ws.Columns.Item($c).ColumnWidth -gt 60) { $ws.Columns.Item($c).ColumnWidth = 60 }
            }
            $ws.Range($ws.Cells.Item(2,1), $ws.Cells.Item($rows.Count + 1, $cols.Count)).WrapText = $true
        }

        $wb.Worksheets.Item(1).Activate()
        if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Force }
        $wb.SaveAs($Path, 51)   # xlOpenXMLWorkbook
    }
    finally {
        if ($wb)    { try { $wb.Close($false) } catch { } }
        if ($excel) { try { $excel.Quit() } catch { } ; [void][Runtime.InteropServices.Marshal]::ReleaseComObject($excel) }
        [GC]::Collect(); [GC]::WaitForPendingFinalizers()
    }
}

function Write-Sheets {
    param([string]$BaseName, [array]$Sheets)
    $xlsx = Join-Path $Out "$BaseName.xlsx"
    if (-not $Csv -and (Test-ExcelAvailable)) {
        Write-Workbook -Path $xlsx -Sheets $Sheets
        if (-not $Quiet) { Write-Host "  $([System.IO.Path]::GetFileName($xlsx))" }
        return $xlsx
    }
    if (-not $Csv) { Write-Warning "Excel not available; writing $BaseName as CSV." }
    $written = @()
    foreach ($s in $Sheets) {
        $p = Join-Path $Out ("{0}.{1}.csv" -f $BaseName, ($s.Name -replace '[^\w\-]', '-'))
        @($s.Rows) | Export-Csv -LiteralPath $p -NoTypeInformation -Encoding UTF8
        $written += $p
        if (-not $Quiet) { Write-Host "  $([System.IO.Path]::GetFileName($p))" }
    }
    return $written
}

# ----------------------------------------------------------- gap analysis ---

if (-not $Quiet) { Write-Host "Rendering to $Out" }

$gapSheets = @()
foreach ($e in @($l.entities)) {
    $rows = @()
    foreach ($f in @($l.findings | Where-Object { [string]$_.entity -eq [string]$e.id })) {
        $r = if ($req.ContainsKey([string]$f.requirement)) { $req[[string]$f.requirement] } else { $null }
        $says = (@($f.documentsSay) | ForEach-Object { "$($_.document) s.$($_.section): ""$($_.quote)""" }) -join ' | '
        $rows += [pscustomobject]@{
            'Finding'            = $f.id
            'Requirement'        = $f.requirement
            'Framework'          = if ($r) { $r.Framework } else { '?' }
            'Quality area'       = if ($r) { $r.QualityArea } else { '' }
            'Requirement text'   = if ($r) { $r.Text } else { '' }
            'Outcome, plainly'   = $f.outcomePlain
            'What documents say' = $says
            'Gap type'           = $f.gapType
            'Maturity'           = $f.maturity
            'Basis'              = $f.maturityBasis
            'Evidence seen'      = (@($f.evidenceSeen) -join '; ')
            'Evidence needed'    = (@($f.evidenceNeeded) -join '; ')
            'Risk if unaddressed'= $f.risk
            'Priority'           = $f.priority
            'Class'              = $f.class
            'Citation'           = if ($f.citation) { "$($f.citation.source) $($f.citation.ref)" } else { '' }
            'Citation verified'  = if ($f.citation -and $f.citation.verified) { 'yes' } else { 'NO' }
            'Treatments'         = (@($f.treatments) -join ', ')
        }
    }
    $gapSheets += @{ Name = [string]$e.id; Rows = ($rows | Sort-Object Requirement) }
}
if ($gapSheets.Count) { Write-Sheets -BaseName '01-gap-analysis' -Sheets $gapSheets | Out-Null }

# ---------------------------------------------------------------- calendar ---

$calAsset = Get-Content -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\obligations.calendar.json') -Raw -Encoding UTF8 | ConvertFrom-Json

$calSheets = @()
foreach ($e in @($l.entities)) {
    $isCricos = [bool]$e.cricosCode
    $rows = @()
    foreach ($c in @($calAsset.clocks)) {
        if (($c.requirement -like 'ESOS*' -or $c.requirement -like 'NC-*') -and -not $isCricos) { continue }
        $rows += [pscustomobject]@{
            'Id' = $c.id; 'Kind' = 'clock'; 'Requirement' = $c.requirement
            'Obligation' = $c.trigger; 'Duration or due' = $c.duration
            'Evidence output' = $c.output; 'Owner' = $c.owner
            'Escalate at' = if ($c.PSObject.Properties['escalateAt']) { $c.escalateAt } else { '' }
            'Verify locally' = 'no'
            'Note' = if ($c.PSObject.Properties['severity']) { "severity: $($c.severity)" } else { '' }
        }
    }
    foreach ($c in @($calAsset.recurring)) {
        if ($c.PSObject.Properties['appliesTo'] -and $c.appliesTo -match 'CRICOS' -and -not $isCricos) { continue }
        $rows += [pscustomobject]@{
            'Id' = $c.id; 'Kind' = 'recurring'; 'Requirement' = $c.requirement
            'Obligation' = $c.name; 'Duration or due' = "$($c.frequency) - $($c.due)"
            'Evidence output' = $c.output; 'Owner' = 'TO BE ASSIGNED'
            'Escalate at' = if ($c.PSObject.Properties['escalateAt']) { $c.escalateAt } else { '' }
            'Verify locally' = if ($c.verifyLocally) { 'YES - confirm the date before use' } else { 'no' }
            'Note' = if ($c.PSObject.Properties['checkWith']) { "check with: $($c.checkWith)" } else { '' }
        }
    }
    $calSheets += @{ Name = [string]$e.id; Rows = $rows }
}
if ($calSheets.Count) { Write-Sheets -BaseName '04-compliance-calendar' -Sheets $calSheets | Out-Null }

# ----------------------------------------------------------- risk register ---

if (@($l.risks).Count) {
    $riskSheets = @()
    foreach ($e in @($l.entities)) {
        $rows = @()
        foreach ($r in @($l.risks | Where-Object { [string]$_.entity -eq [string]$e.id })) {
            $rows += [pscustomobject]@{
                'Id' = $r.id; 'Risk' = $r.risk; 'Cause' = $r.cause
                'Current control' = $r.control; 'Control effectiveness' = $r.controlEffectiveness
                'Treatment' = (@($r.treatment) -join ', '); 'Owner' = $r.owner; 'Review date' = $r.review
            }
        }
        $riskSheets += @{ Name = [string]$e.id; Rows = $rows }
    }
    Write-Sheets -BaseName '06-risk-register' -Sheets $riskSheets | Out-Null
}

# ------------------------------------------------------------- fragments ---

function Write-Md { param([string]$File, [System.Text.StringBuilder]$Sb)
    $p = Join-Path $Out $File
    $Sb.ToString() | Out-File -LiteralPath $p -Encoding utf8
    if (-not $Quiet) { Write-Host "  $File" }
}

$today = Get-Date -Format 'yyyy-MM-dd'

$rm = New-Object System.Text.StringBuilder
[void]$rm.AppendLine('# Roadmap')
[void]$rm.AppendLine()
[void]$rm.AppendLine("Rendered from the assurance ledger on $today. Do not edit this file - edit the ledger and re-render.")
[void]$rm.AppendLine()
if (@($l.treatments).Count -eq 0) {
    [void]$rm.AppendLine('*No treatments in the ledger yet.*')
} else {
    [void]$rm.AppendLine('| Due | Id | Treatment | Type | Owner | Effort | Closes | Deliverable |')
    [void]$rm.AppendLine('|---|---|---|---|---|---|---|---|')
    foreach ($t in @($l.treatments | Sort-Object due)) {
        $closes = (@($t.addresses) -join ', ')
        [void]$rm.AppendLine("| $($t.due) | $($t.id) | $($t.title) | $($t.type) | $($t.owner) | $($t.effort) | $closes | $($t.deliverable) |")
    }
    $blocked = @()
    foreach ($d in @($l.decisions)) { foreach ($b in @($d.blocks)) { $blocked += "$b (blocked by $($d.id): $($d.question))" } }
    if ($blocked.Count) {
        [void]$rm.AppendLine()
        [void]$rm.AppendLine('## Blocked on a decision')
        [void]$rm.AppendLine()
        foreach ($b in $blocked) { [void]$rm.AppendLine("- $b") }
    }
}
[void]$rm.AppendLine()
[void]$rm.AppendLine("*$DISCLAIMER*")
Write-Md -File 'ROADMAP.md' -Sb $rm

$im = New-Object System.Text.StringBuilder
[void]$im.AppendLine('# Leading indicators')
[void]$im.AppendLine()
[void]$im.AppendLine("Rendered from the assurance ledger on $today. Do not edit this file - edit the ledger and re-render.")
[void]$im.AppendLine()
if (@($l.indicators).Count -eq 0) {
    [void]$im.AppendLine('*No indicators in the ledger yet. See `references/systems-design.md`.*')
} else {
    [void]$im.AppendLine('| Id | Requirement | Indicator | Leading | Source | Formula | Frequency | Threshold | Escalation |')
    [void]$im.AppendLine('|---|---|---|---|---|---|---|---|---|')
    foreach ($i in @($l.indicators)) {
        $lead = if ($i.leading) { 'yes' } else { '**lagging**' }
        [void]$im.AppendLine("| $($i.id) | $($i.requirement) | $($i.name) | $lead | $($i.source) | $($i.formula) | $($i.frequency) | $($i.threshold) | $($i.escalation) |")
    }
    $lag = @($l.indicators | Where-Object { -not $_.leading })
    if ($lag.Count) {
        [void]$im.AppendLine()
        [void]$im.AppendLine("**$($lag.Count) indicator(s) are lagging.** A lagging indicator tells you the finding already exists. Keep only the ones that are genuinely useful as history.")
    }
}
[void]$im.AppendLine()
[void]$im.AppendLine("*$DISCLAIMER*")
Write-Md -File 'INDICATORS.md' -Sb $im

# --------------------------------------------------------------- sources ---

$sm = New-Object System.Text.StringBuilder
[void]$sm.AppendLine('# Source register')
[void]$sm.AppendLine()
[void]$sm.AppendLine('Every requirement cited in this pack traces to a row here.')
[void]$sm.AppendLine()
[void]$sm.AppendLine('| Id | Instrument or source | Register id | Checked | Structure verified |')
[void]$sm.AppendLine('|---|---|---|---|---|')
foreach ($s in @($src.sources)) {
    $rid = if ($s.PSObject.Properties['registerId']) { $s.registerId } else { '' }
    $ver = if ($s.structureVerified) { 'yes' } else { '**no - fetch before citing**' }
    [void]$sm.AppendLine("| $($s.id) | $($s.title) | $rid | $($s.checkedOn) | $ver |")
}
[void]$sm.AppendLine()
[void]$sm.AppendLine("*$DISCLAIMER*")
Write-Md -File 'SOURCES.md' -Sb $sm

if (-not $Quiet) {
    Write-Host ''
    Write-Host 'Rendered. Now run Test-AuditPack.ps1 before anything leaves the building.'
}
