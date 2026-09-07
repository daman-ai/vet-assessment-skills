<#
  Set-AmrrColumns.ps1 — re-lay the column widths of an AMRR template's student
  table, keeping the table's overall width exactly as it is.

  WHY THE WIDTHS LIVE IN TWO PLACES. A table's column widths are declared once
  in w:tblGrid and again in every single cell's w:tcW. Change the grid alone and
  Word reflows to the cell widths, so nothing appears to happen; change the
  cells alone and a later row insertion picks the grid back up. Both are written
  here, and every merged cell is given the SUM of the grid columns it spans, so
  the table is self-consistent whichever one Word chooses to believe.

  The total is held constant on purpose. This table is already wider than the
  text area on all three templates — it overhangs the right margin by design —
  so widening it further would push it off the page.
#>
param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][int[]]$Widths,
    [switch]$WhatIf
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-Docx.ps1')
$W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'

$pkg = Open-Docx -Path (Resolve-Path -LiteralPath $Path).Path
$ns = $pkg.Ns
try {
    $tbl = $null
    foreach ($t in @($pkg.Body.SelectNodes('./w:tbl', $ns))) {
        $all = (($t.SelectNodes('.//w:t', $ns) | ForEach-Object { $_.InnerText }) -join ' ')
        if ($all -match 'Student ID') { $tbl = $t; break }
    }
    if (-not $tbl) { throw "No student table in $Path" }

    $cols = @($tbl.SelectNodes('w:tblGrid/w:gridCol', $ns))
    if ($cols.Count -ne $Widths.Count) { throw "$Path has $($cols.Count) columns; $($Widths.Count) widths given." }

    $before = @($cols | ForEach-Object { [int]$_.GetAttribute('w', $W) })
    $sumB = ($before | Measure-Object -Sum).Sum
    $sumA = ($Widths | Measure-Object -Sum).Sum
    if ($sumA -ne $sumB) { throw "$Path : new widths sum to $sumA, the table is $sumB. The total must not change." }

    Write-Output ("{0}" -f (Split-Path -Leaf $Path))
    Write-Output ("   before {0}" -f ($before -join ' '))
    Write-Output ("   after  {0}   (total {1}, unchanged)" -f ($Widths -join ' '), $sumA)
    if ($WhatIf) { Close-Docx $pkg; return }

    # NB: the width accumulator is NOT called $w. PowerShell variable names are
    # case-insensitive, so $w and $W are one variable — naming it $w overwrites
    # the namespace URI on the first cell, and every SetAttribute after that
    # writes into a namespace called "460" instead of WordprocessingML. The grid
    # updates (it is written first, while $W is still the namespace) and not one
    # cell does, which looks exactly like Word ignoring the file.
    for ($i = 0; $i -lt $cols.Count; $i++) { [void]$cols[$i].SetAttribute('w', $W, [string]$Widths[$i]) }

    $rows = 0; $cells = 0
    foreach ($tr in @($tbl.SelectNodes('./w:tr', $ns))) {
        $rows++
        $col = 0
        foreach ($tc in @($tr.SelectNodes('./w:tc', $ns))) {
            $spN = $tc.SelectSingleNode('w:tcPr/w:gridSpan', $ns)
            $span = if ($spN) { [int]$spN.GetAttribute('val', $W) } else { 1 }
            $cw = 0
            for ($k = $col; $k -lt [Math]::Min($col + $span, $Widths.Count); $k++) { $cw += $Widths[$k] }
            $tcW = $tc.SelectSingleNode('w:tcPr/w:tcW', $ns)
            if ($tcW -and $cw -gt 0) { [void]$tcW.SetAttribute('w', $W, [string]$cw); $cells++ }
            $col += $span
        }
    }
    Write-Output ("   rewrote {0} cell width(s) across {1} row(s)" -f $cells, $rows)

    [void](Save-Docx -Package $pkg -Destination (Resolve-Path -LiteralPath $Path).Path)
}
catch { Close-Docx $pkg; throw }
