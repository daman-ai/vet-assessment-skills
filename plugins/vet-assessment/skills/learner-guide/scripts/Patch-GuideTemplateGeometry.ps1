<#
    Patch-GuideTemplateGeometry.ps1

    Bring the Learner Guide template's PAGE MARGINS into agreement with the
    content width every Learner Guide is actually built to.

    THE DEFECT THIS CLOSES

    Three sources disagreed, and two of them agree with each other:

      Study Guide spec 5.1   margins top 1440, right 849, bottom 1440, left 1440
                             and "CW = 9617 DXA - all full-width tables and
                             column-width arrays must sum exactly to 9617"
      Delivered SITHPAT018   every one of its 361 full-width tables is 9617 DXA
      Learner Guide template pgMar right="1440", which yields CW 9026

    11906 - 1440 - 849 = 9617 exactly, so the spec's arithmetic is deliberate,
    and the delivered guide's tables were built to it. What the delivered guide
    did NOT do is set the margin: it kept the template's right margin of 1440
    while laying 9617-wide tables on it, so every table in that document
    overhangs the right margin by 591 DXA - a little over a centimetre.

    The fix is the one-line change that makes all three agree: set the right
    margin to 849 in the template, so CW is genuinely 9617 and the tables that
    are already built to 9617 sit inside the text column.

    The pristine template is kept beside the patched one as
    *.premargin.docx, matching the convention the assessment skill uses for
    its own template patches. Run this ONCE against the shipped template; it is
    idempotent and reports when there is nothing to do.

    ASCII only in this file.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $TemplatePath,
    [int]    $RightMargin = 849,
    [int]    $ExpectedContentWidth = 9617
)

$ErrorActionPreference = 'Stop'

if (-not $TemplatePath) {
    $TemplatePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\templates\MVC_Learner_Guide_Template.docx'
}
if (-not (Test-Path -LiteralPath $TemplatePath)) { throw "Template not found: $TemplatePath" }

. (Join-Path $PSScriptRoot 'Lib-Resolve.ps1') -NoDeck

$backup = [System.IO.Path]::ChangeExtension($TemplatePath, $null).TrimEnd('.') + '.premargin.docx'
if (-not (Test-Path -LiteralPath $backup)) {
    Copy-Item -LiteralPath $TemplatePath -Destination $backup -Force
    Write-Host "pristine copy kept: $(Split-Path -Leaf $backup)" -ForegroundColor DarkGray
}

$wd = Expand-Docx -Path $TemplatePath
try {
    $doc = Get-DocxPart -WorkDir $wd -Part 'word/document.xml'

    if ($doc -notmatch '<w:pgSz w:w="(\d+)" w:h="(\d+)"\s*/>') { throw 'No page size found in the template.' }
    $pageW = [int]$Matches[1]

    $m = [regex]::Match($doc, '<w:pgMar\b[^>]*/>')
    if (-not $m.Success) { throw 'No page margins found in the template.' }
    $pgMar = $m.Value

    $left  = [int]([regex]::Match($pgMar, 'w:left="(\d+)"').Groups[1].Value)
    $right = [int]([regex]::Match($pgMar, 'w:right="(\d+)"').Groups[1].Value)
    $cwNow = $pageW - $left - $right

    Write-Host "page width      : $pageW"
    Write-Host "margins now     : left $left, right $right"
    Write-Host "content width   : $cwNow"

    if ($right -eq $RightMargin) {
        Write-Host "already patched - right margin is $RightMargin, CW $cwNow. Nothing to do." -ForegroundColor Green
        return
    }

    $cwAfter = $pageW - $left - $RightMargin
    if ($cwAfter -ne $ExpectedContentWidth) {
        throw "Patching right margin to $RightMargin would give CW $cwAfter, not the expected $ExpectedContentWidth. Re-check the geometry before forcing it."
    }

    if (-not $PSCmdlet.ShouldProcess($TemplatePath, "set right margin $right -> $RightMargin (CW $cwNow -> $cwAfter)")) { return }

    $new = [regex]::Replace($pgMar, 'w:right="\d+"', "w:right=`"$RightMargin`"")
    $doc = $doc.Substring(0, $m.Index) + $new + $doc.Substring($m.Index + $m.Length)
    Set-DocxPart -WorkDir $wd -Part 'word/document.xml' -Content $doc

    Assert-DocxPackage -WorkDir $wd

    Compress-Docx -WorkDir $wd -Path $TemplatePath | Out-Null
    Write-Host "patched: right margin $right -> $RightMargin, CW $cwNow -> $cwAfter" -ForegroundColor Green
}
finally { Remove-Item -LiteralPath $wd -Recurse -Force -ErrorAction SilentlyContinue }
