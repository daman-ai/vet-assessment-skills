<#
  Convert-RecordsToPdf.ps1 - the Student Assessment Records and standalone
  feedback sheets, as PDF.

  THE RTO'S RULE, 10 September 2026: a SAR and a feedback sheet leave the RTO as
  PDF, never as Word. A Word record is an editable record, and what is handed to
  a student or filed for an auditor must not be. The marked assessment is the
  exception and stays in Word - it is the student's own document going back to
  them, and a resubmission is written into it.

  Conversion goes through Word itself so the PDF is what the document actually
  prints as, rather than what a second renderer thinks it should look like.

  Two traps, both of which cost a run:

  * Join-Path returns a PSObject-wrapped string, and Word's late-bound SaveAs
    refuses it with "cannot convert the value of type psobject to type Object".
    Cast to [string] and use ExportAsFixedFormat, which takes the path by value.
  * An orphaned WINWORD.EXE holds a lock on every file it opened, so the Quit
    goes in a finally block. Without it the next build cannot overwrite them.

  Usage:
    .\Convert-RecordsToPdf.ps1 -Dir run\G1 -OutDir pdf\G1
    .\Convert-RecordsToPdf.ps1 -Dir run\G1 -OutDir pdf\G1 -Filter 'SAR_*.docx'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Dir,
    [string]$OutDir,
    [string[]]$Filter = @('SAR_*.docx', 'FEEDBACK_*.docx')
)
$ErrorActionPreference = 'Stop'

$src = (Resolve-Path -LiteralPath $Dir).Path
$dst = if ($OutDir) { $OutDir } else { $src }
if (-not (Test-Path -LiteralPath $dst)) { [void](New-Item -ItemType Directory -Path $dst) }
$dst = (Resolve-Path -LiteralPath $dst).Path

$files = @()
foreach ($f in $Filter) { $files += @(Get-ChildItem -LiteralPath $src -Filter $f -File) }
$files = @($files | Sort-Object FullName -Unique)
if ($files.Count -eq 0) { Write-Output "Nothing in $Dir matches $($Filter -join ', ')."; return }

$wdExportFormatPDF = 17
$word = $null
$done = 0
$failed = @()
try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.DisplayAlerts = 0
    foreach ($f in $files) {
        [string]$target = [string](Join-Path $dst ($f.BaseName + '.pdf'))
        $doc = $null
        try {
            $doc = $word.Documents.Open([string]$f.FullName, $false, $true)   # ReadOnly
            $doc.ExportAsFixedFormat($target, $wdExportFormatPDF)
            $done++
        } catch {
            $failed += "$($f.Name): $($_.Exception.Message)"
        } finally {
            if ($doc) {
                $doc.Close([ref]$false)
                [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($doc)
            }
        }
    }
} finally {
    if ($word) {
        $word.Quit()
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($word)
    }
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
}

Write-Output ("{0} of {1} record(s) converted to PDF in {2}" -f $done, $files.Count, $dst)
if ($failed.Count) {
    Write-Output 'FAILED:'
    $failed | ForEach-Object { Write-Output "  $_" }
    throw "$($failed.Count) record(s) could not be converted. Nothing is handed over until every one of them is a PDF."
}
