<#
    Patch-TemplateFontFloor.ps1

    Raises the document default run size so body text meets the accessibility
    floor of 11 pt.

    THE DEFECT. Both templates leave <w:rPrDefault> without a <w:sz>, and OOXML
    falls back to 10 pt. Every run the builder does not size explicitly - body
    prose, bullets, numbered method steps - therefore rendered at 10 pt against a
    house rule of 11 pt. It had been that way since the templates were made.

    RTO decision, 21 August 2026: meet the floor. Body 11 pt, table and cell text
    10 pt. The builder's own constants carry the second half of that change -
    SZ_CELL and SZ_SMALL in Docx-Blocks-House.ps1.

    WHAT THIS DOES NOT TOUCH. The cover sheet's policy prose runs at 8.5 pt
    (w:sz 17) and is compressed specifically to hold the sheet to exactly one
    page, which is a separate locked position. Raising it is a real conflict
    between two rules, not a patch - it is measured and reported, not decided
    here. See the note this script prints at the end.

    Idempotent.

        pwsh -File Patch-TemplateFontFloor.ps1
        pwsh -File Patch-TemplateFontFloor.ps1 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [int]    $BodyHalfPoints = 22,      # 11 pt
    [switch] $NoBackup
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Build-FromTemplate.ps1')

$b     = Get-Branding -Brand MVC
$total = 0

Write-Host "Document default run size -> $BodyHalfPoints half-points ($($BodyHalfPoints/2) pt)`n"

foreach ($kind in 'uat', 'recipeWorkbook') {
    $path = Get-TemplatePath -Branding $b -Kind $kind
    Write-Host "$kind  ->  $([System.IO.Path]::GetFileName($path))"
    $work = Expand-Docx -Path $path
    $part = 'word/styles.xml'
    $xml  = Get-DocxPart -WorkDir $work -Part $part

    if ($xml -notmatch '<w:rPrDefault>\s*<w:rPr>(.*?)</w:rPr>\s*</w:rPrDefault>') {
        Write-Host "    no rPrDefault/rPr found - skipped`n"; continue
    }
    $inner = $Matches[1]

    if ($inner -match '<w:sz\s+w:val="(\d+)"') {
        if ([int]$Matches[1] -eq $BodyHalfPoints) { Write-Host "    already $BodyHalfPoints - nothing to do`n"; continue }
        Write-Host "    default was $($Matches[1]); setting $BodyHalfPoints"
        $new = [regex]::Replace($inner, '<w:sz\s+w:val="\d+"\s*/>',   "<w:sz w:val=`"$BodyHalfPoints`"/>")
        $new = [regex]::Replace($new,   '<w:szCs\s+w:val="\d+"\s*/>', "<w:szCs w:val=`"$BodyHalfPoints`"/>")
    }
    else {
        # CT_RPr child order: rFonts, b, i, ... , color, sz, szCs, ... , lang.
        # sz and szCs go AFTER color and BEFORE lang, or Word rejects styles.xml.
        Write-Host "    no default size set (Word was falling back to 10 pt); adding $BodyHalfPoints"
        $add = "<w:sz w:val=`"$BodyHalfPoints`"/><w:szCs w:val=`"$BodyHalfPoints`"/>"
        if ($inner -match '<w:lang\b') { $new = $inner -replace '(<w:lang\b)', "$add`$1" }
        else                           { $new = $inner + $add }
    }

    $xml = $xml.Replace("<w:rPrDefault><w:rPr>$inner</w:rPr></w:rPrDefault>",
                        "<w:rPrDefault><w:rPr>$new</w:rPr></w:rPrDefault>")

    if ($PSCmdlet.ShouldProcess($path, 'raise default run size')) {
        Set-DocxPart -WorkDir $work -Part $part -Content $xml
        Assert-DocxPackage -WorkDir $work | Out-Null
        if (-not $NoBackup) {
            $bak = [System.IO.Path]::ChangeExtension($path, '.prefontfloor.docx')
            if (-not (Test-Path -LiteralPath $bak)) { Copy-Item -LiteralPath $path -Destination $bak; Write-Host "    backup    $([System.IO.Path]::GetFileName($bak))" }
        }
        Compress-Docx -WorkDir $work -Path $path | Out-Null
        Write-Host "    written`n"
        $total++
    }
}

Write-Host 'Post-patch check:'
foreach ($kind in 'uat', 'recipeWorkbook') {
    $w = Expand-Docx -Path (Get-TemplatePath -Branding $b -Kind $kind)
    $s = Get-DocxPart -WorkDir $w -Part 'word/styles.xml'
    $v = 'not set'
    if ($s -match '<w:rPrDefault>\s*<w:rPr>(?:(?!</w:rPr>).)*?<w:sz\s+w:val="(\d+)"') { $v = $Matches[1] }
    $ok = ($v -eq [string]$BodyHalfPoints)
    Write-Host ("  {0} {1,-16} docDefaults w:sz = {2}" -f $(if ($ok) { 'OK  ' } else { 'FAIL' }), $kind, $v)
}

Write-Host "`n$total template(s) patched."
Write-Host @'

STILL BELOW THE FLOOR, deliberately, and NOT changed by this script:
  The cover sheet policy prose runs at 8.5 pt (w:sz 17). It is compressed to
  that size specifically to hold the cover sheet to exactly one page, which is
  its own locked position. Raising it to 10 pt would very likely push the sheet
  onto a second page, and "compress the layout, never the wording" forbids
  solving that by cutting a clause.

  Two rules genuinely conflict there. Measure the render and put it to the RTO;
  do not pick one silently.
'@
