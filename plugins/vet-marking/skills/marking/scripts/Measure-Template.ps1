<#
  Measure-Template.ps1 — read a supplied RTO template and report its structure.

  Run this on every template an RTO supplies, BEFORE marking anything with it.
  It reports what the builder needs to know and cannot safely assume:

    * how many tables, and what each one is called
    * every bracketed field, and how many times it occurs
    * every standing checkbox label
    * the repeating rows (student rows, feedback item rows) and their count
    * table widths and column grids, so a column insert can be costed
    * page orientation

  The output is what you paste into assets/rto.<key>.json. A template that
  disagrees with its registered map is a template that has been revised, and
  the gate will say so rather than filling the wrong cell.

  Usage:
    .\Measure-Template.ps1 -Path <template.docx> [-Json]
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Path,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-Docx.ps1')

$WNS = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
$BOX = [char]0x2610

$pkg = Open-Docx -Path $Path
try {
    $ns = $pkg.Ns

    # ---- orientation -------------------------------------------------------
    $sect   = $pkg.Body.SelectSingleNode('.//w:sectPr', $ns)
    $pgSz   = if ($sect) { $sect.SelectSingleNode('w:pgSz', $ns) } else { $null }
    $orient = if ($pgSz -and $pgSz.GetAttribute('orient', $WNS)) { $pgSz.GetAttribute('orient', $WNS) } else { 'portrait' }

    # ---- whole-document text ----------------------------------------------
    $all = New-Object System.Text.StringBuilder
    foreach ($p in $pkg.Body.SelectNodes('.//w:p', $ns)) { [void]$all.AppendLine((Get-RunText $p $ns)) }
    $text = $all.ToString()

    # ---- bracketed fields --------------------------------------------------
    $fields = @{}
    foreach ($m in [regex]::Matches($text, '\[[^\[\]]{1,120}\]')) {
        $name = $m.Value.Trim('[', ']').Trim()
        if ($name -eq "$BOX") { $name = '<checkbox>' }
        if (-not $fields.ContainsKey($name)) { $fields[$name] = 0 }
        $fields[$name]++
    }

    # ---- standing checkbox labels -----------------------------------------
    $labels = @{}
    foreach ($m in [regex]::Matches($text, "$BOX\s*([^\r\n]{1,110})")) {
        $lab = ($m.Groups[1].Value.Trim() -replace '\s+', ' ')
        if ($lab -eq ']' -or $lab -eq '') { continue }
        if (-not $labels.ContainsKey($lab)) { $labels[$lab] = 0 }
        $labels[$lab]++
    }

    # ---- tables ------------------------------------------------------------
    $tables = @()
    $ti = 0
    foreach ($tbl in @(Get-Tables $pkg)) {
        $ti++
        $rows = @(Get-Rows $tbl $ns)
        $grid = $tbl.SelectSingleNode('w:tblGrid', $ns)
        $cols = if ($grid) { @($grid.SelectNodes('w:gridCol', $ns)) | ForEach-Object { [int]$_.GetAttribute('w', $WNS) } } else { @() }
        $tblW = $tbl.SelectSingleNode('w:tblPr/w:tblW', $ns)
        $width = if ($tblW) { [int]$tblW.GetAttribute('w', $WNS) } else { 0 }

        $first = if ($rows.Count -gt 0) { (Get-RunText $rows[0] $ns).Trim() } else { '' }
        if ($first.Length -gt 70) { $first = $first.Substring(0, 70) + '…' }

        # a repeating row block: rows of the same shape carrying the same fields
        $sig = @{}
        $ri = 0
        foreach ($r in $rows) {
            $ri++
            $key = ((Get-RunText $r $ns) -replace '\d+', '#') -replace '\s+', ' '
            $key = $key.Trim()
            if ($key.Length -gt 160) { $key = $key.Substring(0, 160) }
            if (-not $sig.ContainsKey($key)) { $sig[$key] = @() }
            $sig[$key] += $ri
        }
        $repeats = @()
        foreach ($key in $sig.Keys) {
            if ($sig[$key].Count -ge 2 -and $key -match '\[') {
                $repeats += [pscustomobject]@{ signature = $key; count = $sig[$key].Count; rowIndex = @($sig[$key]) }
            }
        }

        $tables += [pscustomobject]@{
            index         = $ti
            heading       = $first
            rows          = $rows.Count
            columns       = $cols.Count
            widthDxa      = $width
            gridColumns   = @($cols)
            gridSum       = ($cols | Measure-Object -Sum).Sum
            repeatingRows = @($repeats)
        }
    }

    $result = [pscustomobject]@{
        file           = Split-Path -Leaf (Resolve-Path -LiteralPath $Path).Path
        orientation    = $orient
        tableCount     = $tables.Count
        tables         = $tables
        fields         = ($fields.GetEnumerator() | Sort-Object Name | ForEach-Object { [pscustomobject]@{ field = $_.Key; occurrences = $_.Value } })
        checkboxLabels = ($labels.GetEnumerator() | Sort-Object Name | ForEach-Object { [pscustomobject]@{ label = $_.Key; occurrences = $_.Value } })
    }

    if ($Json) { $result | ConvertTo-Json -Depth 8; return }

    Write-Output "FILE         $($result.file)"
    Write-Output "ORIENTATION  $($result.orientation)"
    Write-Output "TABLES       $($result.tableCount)"
    Write-Output ''
    foreach ($t in $result.tables) {
        Write-Output ("  [{0}] '{1}'" -f $t.index, $t.heading)
        Write-Output ("       rows {0}  cols {1}  tblW {2}  gridSum {3}" -f $t.rows, $t.columns, $t.widthDxa, $t.gridSum)
        if ($t.gridColumns.Count) { Write-Output ("       grid {0}" -f ($t.gridColumns -join ',')) }
        foreach ($r in $t.repeatingRows) {
            $sg = $r.signature; if ($sg.Length -gt 78) { $sg = $sg.Substring(0, 78) + '…' }
            Write-Output ("       repeats x{0} at rows {1}: {2}" -f $r.count, ($r.rowIndex -join ','), $sg)
        }
        Write-Output ''
    }
    Write-Output 'BRACKETED FIELDS'
    foreach ($f in $result.fields) { Write-Output ("  x{0,-3} {1}" -f $f.occurrences, $f.field) }
    Write-Output ''
    Write-Output 'STANDING CHECKBOX LABELS'
    foreach ($l in $result.checkboxLabels) { Write-Output ("  x{0,-3} {1}" -f $l.occurrences, $l.label) }
}
finally { Close-Docx $pkg }
