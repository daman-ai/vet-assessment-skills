<#
    Patch-TemplateDayCounts.ps1

    One-time asset patch. Brings both approved templates to the RTO's decision of
    21 August 2026: late submission 14 days, results 14 days.

    WHY AT SOURCE. Both templates shipped "results within 45 days". Build-House.ps1
    was patching that string at build time, in every build, for every document.
    A value fixed in the template is fixed once; a value patched at build time is
    a rule every future builder has to remember. Correct the asset.

    The branding profile carries the same figure in `policy.resultsWithinDays`,
    and two executable checks read it - the rendered sweep and the cover-sheet
    clause check. Profile and template must agree or a correct document fails its
    own gate.

    Idempotent: reports "already patched" rather than failing.

        pwsh -File Patch-TemplateDayCounts.ps1
        pwsh -File Patch-TemplateDayCounts.ps1 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param([switch] $NoBackup)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Build-FromTemplate.ps1')

$b    = Get-Branding -Brand MVC
$want = [int]$b.policy.resultsWithinDays
$late = [int]$b.policy.lateSubmissionDays

Write-Host "Branding profile: results $want days, late submission $late days`n"

$edits = @(
    @{ Find = 'results within 45 days'      ; Replace = "results within $want days"      ; Note = 'results window' }
    @{ Find = 'within 15 days of receipt'   ; Replace = "within $late days of receipt"   ; Note = 'late submission window' }
    @{ Find = 'by 15 days of receiving it'  ; Replace = "by $late days of receiving it"  ; Note = 'late submission window' }
)

$total = 0

foreach ($kind in 'uat', 'recipeWorkbook') {
    $path = Get-TemplatePath -Branding $b -Kind $kind
    Write-Host "$kind  ->  $([System.IO.Path]::GetFileName($path))"
    $work    = Expand-Docx -Path $path
    $part    = 'word/document.xml'
    $applied = 0

    foreach ($e in $edits) {
        $n = Test-DocxTextPresent -WorkDir $work -Part $part -Text $e.Find
        if ($n -eq 0) { Write-Host ("    skip    {0,-26} already patched or absent" -f $e.Note); continue }
        if ($PSCmdlet.ShouldProcess("$kind : $($e.Note)", 'patch day count')) {
            $c = Invoke-DocxTextReplace -WorkDir $work -Part $part -Find $e.Find -Replace $e.Replace -Expected $n
            Write-Host ("    applied {0,-26} x{1}  '{2}' -> '{3}'" -f $e.Note, $c, $e.Find, $e.Replace)
            $applied += $c
        }
    }

    if ($applied -eq 0) { Write-Host "    nothing to do`n"; continue }

    Assert-DocxPackage -WorkDir $work | Out-Null
    if ($PSCmdlet.ShouldProcess($path, 'write patched template')) {
        if (-not $NoBackup) {
            $bak = [System.IO.Path]::ChangeExtension($path, '.predaycount.docx')
            if (-not (Test-Path -LiteralPath $bak)) { Copy-Item -LiteralPath $path -Destination $bak; Write-Host "    backup: $([System.IO.Path]::GetFileName($bak))" }
        }
        Compress-Docx -WorkDir $work -Path $path | Out-Null
        Write-Host "    written`n"
    }
    $total += $applied
}

# Confirm both templates now agree with the profile, and that no stale figure survives.
Write-Host 'Post-patch check:'
$bad = 0
foreach ($kind in 'uat', 'recipeWorkbook') {
    $w   = Expand-Docx -Path (Get-TemplatePath -Branding $b -Kind $kind)
    $txt = (Get-DocxText -WorkDir $w) -join "`n"
    foreach ($probe in @(
            @{ Want = $true ; Text = "results within $want days" },
            @{ Want = $true ; Text = "within $late days of receipt" },
            @{ Want = $false; Text = '45 days' },
            @{ Want = $false; Text = '15 days' })) {
        $present = $txt.Contains($probe.Text)
        $ok      = ($present -eq $probe.Want)
        if (-not $ok) { $bad++ }
        Write-Host ("  {0} {1,-16} {2,-30} {3}" -f $(if ($ok) { 'OK  ' } else { 'FAIL' }),
                                                  $kind,
                                                  $probe.Text,
                                                  $(if ($present) { 'present' } else { 'absent' }))
    }
}
Write-Host ("`n{0} edit(s) applied. {1}" -f $total, $(if ($bad -eq 0) { 'Templates agree with the branding profile.' } else { "$bad check(s) FAILED." }))
