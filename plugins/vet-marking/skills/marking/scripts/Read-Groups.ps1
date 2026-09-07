<#
  Read-Groups.ps1 — read EVERY sheet of a WiseNet 0217 export and return the
  full learner roster of each course-offer group, with that learner's cell for
  one unit.

  The 0217 export carries one worksheet per course-offer group. Group
  membership is what the sheet a learner sits on says it is, so the roster is
  read from all sheets and a learner appearing on two is reported rather than
  silently placed in the last one seen.
#>
param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Unit,
    [Parameter(Mandatory)][string]$Json
)
$ErrorActionPreference = 'Stop'

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
$wb = $excel.Workbooks.Open((Resolve-Path -LiteralPath $Path).Path, 0, $true)
$all = New-Object System.Collections.ArrayList
try {
    foreach ($ws in $wb.Worksheets) {
        $rows = $ws.UsedRange.Rows.Count
        $cols = $ws.UsedRange.Columns.Count

        $desc = ''
        for ($r = 1; $r -le 12; $r++) {
            for ($c = 1; $c -le 8; $c++) {
                if ("$($ws.Cells.Item($r, $c).Text)".Trim() -eq 'Course Offer Desc:') {
                    for ($k = $c + 1; $k -le $cols; $k++) {
                        $v = "$($ws.Cells.Item($r, $k).Text)".Trim()
                        if ($v) { $desc = $v; break }
                    }
                }
            }
        }

        $learnerRow = 0; $unitRow = 0
        for ($r = 1; $r -le $rows; $r++) {
            for ($c = 1; $c -le $cols; $c++) {
                $t = "$($ws.Cells.Item($r, $c).Text)".Trim()
                if ($t -eq 'Learner Name' -and $learnerRow -eq 0) { $learnerRow = $r }
                if ($t -eq 'Units'        -and $unitRow    -eq 0) { $unitRow    = $r }
            }
            if ($learnerRow -and $unitRow) { break }
        }

        $nameCol = 1; $refCol = 0; $statusCol = 0
        for ($c = 1; $c -le $cols; $c++) {
            $h = "$($ws.Cells.Item($learnerRow, $c).Text)".Trim()
            if ($h -eq 'Learner Name')  { $nameCol   = $c }
            if ($h -eq 'Status')        { $statusCol = $c }
            if ($h -like 'RefInternal*'){ $refCol    = $c }
        }

        # merged unit headers: resolve to the first column of the merge area
        $unitCol = 0
        for ($c = 1; $c -le $cols; $c++) {
            $t = "$($ws.Cells.Item($unitRow, $c).Text)".Trim()
            if ($t -like "$Unit*") { $unitCol = [int]$ws.Cells.Item($unitRow, $c).MergeArea.Column; break }
        }
        if (-not $unitCol) { throw "Unit $Unit not found on worksheet $($ws.Index)" }

        for ($r = $learnerRow + 1; $r -le $rows; $r++) {
            $raw = ("$($ws.Cells.Item($r, $nameCol).Text)" -replace '[\r\n]+', ' ').Trim()
            if ($raw -eq '') { continue }
            $ref = ''
            if ($refCol) { $ref = ("$($ws.Cells.Item($r, $refCol).Text)" -replace '\s*\(\s*\)\s*$', '').Trim() }
            $status = ''
            if ($statusCol) { $status = "$($ws.Cells.Item($r, $statusCol).Text)".Trim() }

            $cell = "$($ws.Cells.Item($r, $unitCol).Text)".Trim()
            if ([double]$ws.Cells.Item($r, $unitCol).Interior.Color -eq 0) { $cell = 'NOT-ATTACHED' }
            elseif ($cell -eq '') { $cell = 'BLANK' }

            [void]$all.Add([pscustomobject]@{
                sheet     = [int]$ws.Index
                group     = $desc
                row       = $r
                rawName   = $raw
                studentId = $ref
                status    = $status
                unitCell  = $cell
            })
        }
    }
}
finally {
    if ($wb)    { try { $wb.Close($false) } catch {} }
    if ($excel) { try { $excel.Quit() } catch {}; [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) }
}

$arr = $all.ToArray()
# NB: $json and $Json are the SAME variable in PowerShell. Naming the payload
# $json would overwrite the -Json path parameter and WriteAllText then fails
# with "Illegal characters in path". Same family as the $M/$m and $NS/$ns traps.
$payload = ConvertTo-Json -InputObject $arr -Depth 5
[System.IO.File]::WriteAllText($Json, $payload, (New-Object System.Text.UTF8Encoding($false)))
Write-Output ("roster rows: {0}" -f $arr.Count)
foreach ($g in ($arr | Group-Object group | Sort-Object Name)) {
    Write-Output ("  {0,-52} {1} learner(s)" -f $g.Name, $g.Count)
}
