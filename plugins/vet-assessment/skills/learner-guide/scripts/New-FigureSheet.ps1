<#
    New-FigureSheet.ps1 - cut the FIGURE SHEET from the spine, stamped with the
    fingerprint of the spine it was cut from.

    Run it at Stage 3d, when the sheet is first produced, and AGAIN AT THE END OF
    EVERY STAGE 7 ROUND, because Stage 7 edits the spine.

        & "$SkillDir\scripts\New-FigureSheet.ps1" -BuildDir $out

    WHAT THE SHEET IS FOR. A reviewer must be able to read what a figure SAYS
    whether or not a picture has been placed yet. Under the ordering this
    pipeline replaced, artwork was placed after the audits, so every pre-artwork
    round read a document in which every figure was still a prompt block - and
    the rule that was supposed to prevent that ("a diagram's labels live in its
    alt text, so a review that skips alt text has not read the figures") was
    guaranteed vacuous in every one of those rounds, because alt text only
    reaches the document at placement. The figures were first read at the third
    audit round, four hours after they were written, and that round returned Not
    Compliant. The sheet is what makes figure content readable from hour one.

    WHY IT IS GENERATED AND NOT WRITTEN. The sheet is a transcript, and a
    hand-assembled transcript is a second source of truth that drifts from the
    spine the moment either is edited. One build held its diagram content as
    hand-typed copies inside a spec-writer script; three rounds of spine
    corrections never touched them and the figures went on teaching a superseded
    calculation. So this dumps EVERY field of every visual node, rather than a
    list of field names somebody maintains - a channel added to the spine cannot
    go missing from the sheet by being forgotten here.

    WHY IT STAMPS A FINGERPRINT. The sheet travels with every later review pack
    and is what lets a Stage 5 or Stage 6 record count as having read the
    figures. Stage 7 edits the spine. A sheet nobody regenerated then hands a
    reviewer figure content the document no longer has, while the ledger records
    that the figures were read. Test-StageLedger recomputes the fingerprint and
    BLOCKS DELIVERY when it does not match, so a stale sheet cannot travel.

    PS 5.1. ASCII only in this file.
    Exit 0 written, 2 a usage error.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $BuildDir,
    [string] $SpineDir,
    [string] $OutPath,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

$GATE = 'FIGURE SHEET'

if (-not (Test-Path -LiteralPath $BuildDir)) { Write-Host "$GATE`: no build directory at $BuildDir" -ForegroundColor Red; exit 2 }
if (-not $SpineDir) { $SpineDir = Join-Path $BuildDir 'spine' }
if (-not (Test-Path -LiteralPath $SpineDir)) {
    Write-Host "$GATE`: no spine at $SpineDir. The sheet is cut from the spine, not from the rendered document - the content is machine-readable JSON hours before a picture exists." -ForegroundColor Red
    exit 2
}
if (-not $OutPath) { $OutPath = Join-Path $BuildDir 'figure-sheet.txt' }

# ---------------------------------------------------------------------------
# Dump a node EXHAUSTIVELY. Nothing here names a field, so nothing here can
# forget one.
# ---------------------------------------------------------------------------

function Add-NodeLine {
    param(
        [Parameter(Mandatory)] $Node,
        [Parameter(Mandatory)] $Lines,
        [string] $Path = '',
        [int] $Depth = 0
    )

    if ($null -eq $Node) { return }
    if ($Depth -gt 12) { $Lines.Add(("  {0}: [deeper than 12 levels - not dumped]" -f $Path)); return }

    if ($Node -is [string] -or $Node -is [ValueType]) {
        $v = "$Node".Trim()
        if ($v) { $Lines.Add(("  {0}: {1}" -f $Path, $v)) }
        return
    }

    if ($Node -is [System.Collections.IEnumerable]) {
        $i = 0
        foreach ($item in $Node) {
            Add-NodeLine -Node $item -Lines $Lines -Path ("{0}[{1}]" -f $Path, $i) -Depth ($Depth + 1)
            $i++
        }
        return
    }

    foreach ($p in @($Node.PSObject.Properties)) {
        if ($p.Name -like '_*') { continue }        # commentary, not content
        $child = if ($Path) { "$Path.$($p.Name)" } else { $p.Name }
        Add-NodeLine -Node $p.Value -Lines $Lines -Path $child -Depth ($Depth + 1)
    }
}

# ---------------------------------------------------------------------------

$visuals = @(Get-GateSpineVisuals -BuildDir $BuildDir -SpineDir $SpineDir)
$files   = @(Get-GateSpineFiles   -BuildDir $BuildDir -SpineDir $SpineDir)
$print   = Get-SpineFingerprint   -BuildDir $BuildDir -SpineDir $SpineDir

$out = New-Object System.Collections.Generic.List[string]
$out.Add('FIGURE SHEET - every planned visual on the spine, as plain text')
$out.Add(("SPINE-FINGERPRINT: {0}" -f $print))
$out.Add(("GENERATED: {0}" -f (Get-Date).ToUniversalTime().ToString('o')))
$out.Add(("SOURCE: {0} ({1} spine file(s))" -f $SpineDir, $files.Count))
$out.Add(("SLOTS: {0}" -f $visuals.Count))
$out.Add('')
$out.Add('Read this as figure CONTENT, not as a manifest. Whether a picture has')
$out.Add('been placed yet says nothing about whether the figure is true, whether')
$out.Add('it matches its caption and alt text, or whether it hands a learner an')
$out.Add('assessed answer. Those are the three questions this sheet exists for.')
$out.Add('')

foreach ($v in ($visuals | Sort-Object { "$($_.Slot)" })) {
    $out.Add('-------------------------------------------------------------------')
    $out.Add(("SLOT {0}   kind: {1}   spine file: {2}" -f `
              $(if ($v.Slot) { $v.Slot } else { '(no slot declared)' }),
              $(if ($v.Kind) { $v.Kind } else { '(no kind declared)' }),
              $v.File))
    $out.Add('')
    Add-NodeLine -Node $v.Node -Lines $out
    $out.Add('')
}

if (-not $visuals.Count) {
    $out.Add('NO VISUAL ENTRIES ON THE SPINE. Either visual planning has not run, or')
    $out.Add('the visuals were written under a field name no reader looks for. Both')
    $out.Add('are defects: a guide with no planned visuals has skipped Stage 3b.')
}

[System.IO.File]::WriteAllText($OutPath, (($out -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))

if (-not $Quiet) {
    Write-Host ''
    Write-Host "$GATE" -ForegroundColor Cyan
    Write-GateCheckSet -What 'visual slot(s)' -Count $visuals.Count -DerivedFrom ("{0} spine file(s) in {1}" -f $files.Count, $SpineDir)
    Write-Host ("  written: {0}" -f $OutPath) -ForegroundColor DarkGray
    Write-Host ("  spine fingerprint: {0}" -f $print) -ForegroundColor DarkGray
    Write-Host '  It travels with every later review pack. Regenerate it after every spine edit -' -ForegroundColor Yellow
    Write-Host '  Test-StageLedger blocks delivery on a sheet cut from a spine that has moved on.' -ForegroundColor Yellow
    Write-Host ''
}

exit 0
