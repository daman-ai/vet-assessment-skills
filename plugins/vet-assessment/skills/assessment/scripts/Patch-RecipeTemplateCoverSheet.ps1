<#
    Patch-RecipeTemplateCoverSheet.ps1

    One-time asset patch. Brings the Recipe Workbook template's assessment cover
    sheet into line with the combined UAT template's cover sheet.

    WHY. The two approved MVC templates disagreed on five cover-sheet points. A
    build now emits both documents as one pack, so the cross-document consistency
    step of the compliance review would raise the difference on every single run.
    The RTO's decision was to standardise on the COMBINED template.

    Note this reverses four positions the Recipe/Activity Workbook Master Prompt
    v4.0 states as "MVC locks". That prompt's masthead is superseded on those four
    points and only those four. Everything else in v4.0 stands.

    Re-running this script is safe: it verifies the source text is present before
    each edit and reports "already patched" rather than failing.

    Usage:
        pwsh -File Patch-RecipeTemplateCoverSheet.ps1            # patch in place
        pwsh -File Patch-RecipeTemplateCoverSheet.ps1 -WhatIf    # report only
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $TemplatePath,
    [switch] $NoBackup
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Build-FromTemplate.ps1')

# U+25A1 WHITE SQUARE, built from its code point rather than written as a literal.
# Windows PowerShell 5.1 decodes a BOM-less UTF-8 script as ANSI, so a literal
# glyph in this file arrives at the template as mojibake and matches nothing.
$BOX = [char]0x25A1

$b = Get-Branding -Brand MVC
if (-not $TemplatePath) { $TemplatePath = Get-TemplatePath -Branding $b -Kind recipeWorkbook }

Write-Host "Template: $TemplatePath"
$work = Expand-Docx -Path $TemplatePath
$part = 'word/document.xml'

# The five decided changes, in the order they appear on the sheet.
$edits = @(
    @{ Kind = 'replace'; Find = 'Student ID:';           Replace = 'Student MVC ID:'; Note = 'field label' }
    @{ Kind = 'replace'; Find = 'Assessment Due Date:';  Replace = 'Due Date:';       Note = 'field label' }
    @{ Kind = 'replace'
       Find    = "$BOX First submission                $BOX Resit No. ________"
       Replace = "$BOX First submission     $BOX Resit No. ________     $BOX Online"
       Note    = 'add the Online submission checkbox' }
    @{ Kind = 'replace'
       Find    = 'within 15 days of receipt'
       Replace = "within $($b.policy.lateSubmissionDays) days of receipt"
       Note    = 'late submission window' }
    @{ Kind = 'replace'
       Find    = 'not submitted by 15 days'
       Replace = "not submitted by $($b.policy.lateSubmissionDays) days"
       Note    = 'late submission window' }
    @{ Kind = 'removePara'
       Find   = 'Gaps are identified'
       Note   = 'drop the Gaps paragraph, which the combined template does not carry' }
)

$applied = 0
$skipped = 0

foreach ($e in $edits) {
    $n = Test-DocxTextPresent -WorkDir $work -Part $part -Text $e.Find

    if ($n -eq 0) {
        Write-Host ("  skip    {0,-46} already patched or absent" -f $e.Note)
        $skipped++
        continue
    }

    if ($PSCmdlet.ShouldProcess($e.Note, 'patch cover sheet')) {
        if ($e.Kind -eq 'removePara') {
            $c = Remove-DocxParagraph -WorkDir $work -Part $part -Containing $e.Find -Expected 1
        }
        else {
            $c = Invoke-DocxTextReplace -WorkDir $work -Part $part -Find $e.Find -Replace $e.Replace -Expected $n
        }
        Write-Host ("  applied {0,-46} x{1}" -f $e.Note, $c)
        $applied += $c
    }
}

if ($applied -eq 0) {
    Write-Host "`nNothing to do - the template already matches the combined cover sheet."
    return
}

Assert-DocxPackage -WorkDir $work | Out-Null

if ($PSCmdlet.ShouldProcess($TemplatePath, 'write patched template')) {
    if (-not $NoBackup) {
        $bak = [System.IO.Path]::ChangeExtension($TemplatePath, '.prepatch.docx')
        if (-not (Test-Path -LiteralPath $bak)) {
            Copy-Item -LiteralPath $TemplatePath -Destination $bak
            Write-Host "Backup: $bak"
        }
    }
    Compress-Docx -WorkDir $work -Path $TemplatePath | Out-Null
    Write-Host "`nPatched $applied edit(s), $skipped skipped. Written to $TemplatePath"
}

# Confirm the sheet now reads the way the combined template does.
$check = Expand-Docx -Path $TemplatePath
$txt   = (Get-DocxText -WorkDir $check) -join "`n"
Write-Host "`nPost-patch cover sheet check:"
foreach ($pair in @(
        @{ Want = $true;  Text = 'Student MVC ID:'  },
        @{ Want = $true;  Text = 'Due Date:'        },
        @{ Want = $true;  Text = "$BOX Online"      },
        @{ Want = $true;  Text = "within $($b.policy.lateSubmissionDays) days" },
        # Results is 14 days, not 45. The 45-day figure was superseded by the RTO
        # day-count decision of 21 August 2026 and is patched out of both templates
        # by Patch-TemplateDayCounts.ps1. This row asserted 'within 45 days' was
        # PRESENT, so it reported FAIL on a correctly patched template - the exact
        # failure mode (a sweep failing a correct document) that the single-source
        # rule in house-standard.md exists to prevent.
        @{ Want = $false; Text = 'within 45 days'   },
        @{ Want = $false; Text = 'Gaps are identified' },
        @{ Want = $false; Text = '15 days'          },
        @{ Want = $false; Text = 'Assessment Due Date:' })) {
    $present = $txt.Contains($pair.Text)
    $ok      = ($present -eq $pair.Want)
    $state   = if ($present) { 'present' } else { 'absent ' }
    $verdict = if ($ok) { 'OK  ' } else { 'FAIL' }
    Write-Host ("  {0} {1}  {2}" -f $verdict, $state, $pair.Text)
}
