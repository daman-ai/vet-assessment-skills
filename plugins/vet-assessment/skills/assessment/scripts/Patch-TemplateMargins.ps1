<#
    Patch-TemplateMargins.ps1

    Closes the table-overflow defect: house tables are 9638 dxa, but both
    templates had a 9026 dxa text column (1440 twip margins on A4), so every
    table bled 612 twips - about 1.08 cm - past the right margin.

    RTO decision, 21 August 2026: WIDEN THE MARGINS. 1134 each side makes the
    text column exactly 9638 and every table lines up. The alternative was
    narrowing every table to 9026, which would have meant recomputing every
    column width in the builder and in both templates, and would have made the
    documents visibly narrower than the RTO's existing set.

    Two edits, and both are needed:

      1. Both templates: pgMar left and right 1440 -> 1134.
         Fixes the UAT template's 27 tables (all 9638) and every table the
         builder generates (also 9638).

      2. Recipe template only: every table 9026 -> 9638, the 612 added to the
         table's LAST column so the others keep their measured widths.
         Without this the recipe template's tables would sit 612 short of the
         new column - the same defect, mirrored.

    The cover sheet is the risk in this patch. It is held to exactly one page by
    compression, so the render is re-checked afterwards. A wider column gives
    more room per line, so it should hold or improve, but "should" is not
    evidence - run Test-CoverSheet.

    Idempotent: reports "already patched" rather than failing.

        pwsh -File Patch-TemplateMargins.ps1
        pwsh -File Patch-TemplateMargins.ps1 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [int]    $TargetTextColumn = 0,     # default: the profile's table width
    [switch] $NoBackup
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Build-FromTemplate.ps1')
. (Join-Path $PSScriptRoot 'Test-HouseRules.ps1')

$b     = Get-Branding    -Brand MVC
$prof  = Get-HouseProfile -Brand MVC
if ($TargetTextColumn -le 0) { $TargetTextColumn = [int]$prof.formatting.tableWidthDxa }

$pageW  = 11906                                    # A4 portrait, twips
$margin = [int](($pageW - $TargetTextColumn) / 2)

Write-Host "Target text column : $TargetTextColumn dxa (the house table width)"
Write-Host "A4 width           : $pageW"
Write-Host "New side margins   : $margin each  ->  text column $($pageW - 2*$margin)`n"

$total = 0

foreach ($kind in 'uat', 'recipeWorkbook') {
    $path = Get-TemplatePath -Branding $b -Kind $kind
    Write-Host "$kind  ->  $([System.IO.Path]::GetFileName($path))"
    $work    = Expand-Docx -Path $path
    $part    = 'word/document.xml'
    $xml     = Get-DocxPart -WorkDir $work -Part $part
    $applied = 0

    # ---- 1. page margins ---------------------------------------------------
    $before = ([regex]::Matches($xml, '<w:pgMar[^>]*/>')).Count
    $xml = [regex]::Replace($xml, '(<w:pgMar\b[^>]*?)w:right="\d+"', "`${1}w:right=`"$margin`"")
    $xml = [regex]::Replace($xml, '(<w:pgMar\b[^>]*?)w:left="\d+"',  "`${1}w:left=`"$margin`"")
    $now = ([regex]::Matches($xml, "<w:pgMar[^>]*w:right=`"$margin`"[^>]*w:left=`"$margin`"")).Count
    if ($now -gt 0) { Write-Host ("    margins   {0} sectPr block(s) -> {1}/{1}" -f $before, $margin); $applied++ }

    # ---- 2. recipe template: widen every 9026 table to the new column ------
    if ($kind -eq 'recipeWorkbook') {
        $script:__widened = 0
        $xml = [regex]::Replace($xml, '<w:tbl>.*?</w:tbl>', {
            param($m)
            $t = $m.Value
            if ($t -notmatch '<w:tblW\s+w:w="(\d+)"\s+w:type="dxa"') { return $t }
            $cur = [int]$Matches[1]
            if ($cur -eq $TargetTextColumn -or $cur -eq 0) { return $t }
            $delta = $TargetTextColumn - $cur

            # tblW first. INSTANCE form for the count: there is no static Replace
            # overload taking one - a trailing 1 on the static call binds to
            # RegexOptions.IgnoreCase and replaces EVERY match.
            $t = [regex]::new('(<w:tblW\s+w:w=")\d+("\s+w:type="dxa")').Replace($t, "`${1}$TargetTextColumn`${2}", 1)

            # then the LAST gridCol takes the whole delta, so every other
            # measured column keeps its width
            $cols = [regex]::Matches($t, '<w:gridCol w:w="(\d+)"')
            if ($cols.Count -gt 0) {
                $last    = $cols[$cols.Count - 1]
                $newLast = [int]$last.Groups[1].Value + $delta
                $t = $t.Remove($last.Index, $last.Length).Insert($last.Index, "<w:gridCol w:w=`"$newLast`"/>")

                # and the matching tcW in the last cell of each row - every row
                # on purpose, so the whole last column moves together
                $t = [regex]::Replace($t, '<w:tr[^>]*>.*?</w:tr>', {
                    param($r)
                    $row  = $r.Value
                    $tcws = [regex]::Matches($row, '<w:tcW\s+w:w="(\d+)"\s+w:type="dxa"/>')
                    if ($tcws.Count -eq 0) { return $row }
                    $lt   = $tcws[$tcws.Count - 1]
                    $nv   = [int]$lt.Groups[1].Value + $delta
                    return $row.Remove($lt.Index, $lt.Length).Insert($lt.Index, "<w:tcW w:w=`"$nv`" w:type=`"dxa`"/>")
                }, 'Singleline')
            }
            $script:__widened++
            return $t
        }, 'Singleline')
        $widened = $script:__widened
        Remove-Variable -Name __widened -Scope Script -ErrorAction SilentlyContinue
        if ($widened -gt 0) { Write-Host "    tables    $widened widened to $TargetTextColumn dxa (delta added to the last column)"; $applied++ }
    }

    if ($applied -eq 0) { Write-Host "    nothing to do`n"; continue }

    if ($PSCmdlet.ShouldProcess($path, 'write patched template')) {
        Set-DocxPart -WorkDir $work -Part $part -Content $xml
        Assert-DocxPackage -WorkDir $work | Out-Null
        if (-not $NoBackup) {
            $bak = [System.IO.Path]::ChangeExtension($path, '.premargin.docx')
            if (-not (Test-Path -LiteralPath $bak)) { Copy-Item -LiteralPath $path -Destination $bak; Write-Host "    backup    $([System.IO.Path]::GetFileName($bak))" }
        }
        Compress-Docx -WorkDir $work -Path $path | Out-Null
        Write-Host "    written`n"
        $total += $applied
    }
}

# ---- confirm ---------------------------------------------------------------
Write-Host 'Post-patch check:'
$script:__widened = 0
foreach ($kind in 'uat', 'recipeWorkbook') {
    $w   = Expand-Docx -Path (Get-TemplatePath -Branding $b -Kind $kind)
    $x   = Get-DocxPart -WorkDir $w -Part 'word/document.xml'
    $pw  = 0; $mL = 0; $mR = 0
    if ($x -match '<w:pgSz w:w="(\d+)"') { $pw = [int]$Matches[1] }
    if ($x -match '<w:pgMar w:top="\d+" w:right="(\d+)" w:bottom="\d+" w:left="(\d+)"') { $mR = [int]$Matches[1]; $mL = [int]$Matches[2] }
    $col = $pw - $mL - $mR
    $bad = @([regex]::Matches($x, '<w:tblW\s+w:w="(\d+)"\s+w:type="dxa"') |
             ForEach-Object { [int]$_.Groups[1].Value } |
             Where-Object { $_ -ne $col -and $_ -ne 0 })
    $ok = ($col -eq $TargetTextColumn -and $bad.Count -eq 0)
    Write-Host ("  {0} {1,-16} text column {2}  tables off-column: {3}" -f $(if ($ok) { 'OK  ' } else { 'FAIL' }), $kind, $col, $bad.Count)
}
Write-Host "`n$total edit group(s) applied."
Write-Host 'NEXT: rebuild, then confirm the cover sheet still holds ONE page - Test-CoverSheet. Margins changed; the render is the only proof.'
