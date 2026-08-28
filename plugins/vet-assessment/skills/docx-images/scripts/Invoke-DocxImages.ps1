<#
.SYNOPSIS
  Find, generate and place in one run.

.DESCRIPTION
  The unattended path: scan the document for prompts, generate every
  illustration, place them all, and write the finished .docx.

  Illustrations only. A diagram is built as native Word shapes from a spec,
  and writing that spec means reading the document's prompt and deciding what
  the diagram actually is - which no script can do. If this finds a diagram it
  stops and tells you to run the stages by hand.

.EXAMPLE
  .\Invoke-DocxImages.ps1 -Path .\SITHKOP013_UAT.docx -OutPath .\out\SITHKOP013_UAT.docx
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Path,
  [Parameter(Mandatory)][string]$OutPath,
  [string]$ImageDir,
  [string]$ConfigPath,
  [string]$ApiKey,
  [switch]$AllowMissing
)

$ErrorActionPreference = 'Stop'

if (-not $ImageDir) {
  $ImageDir = Join-Path (Split-Path -Parent ([System.IO.Path]::GetFullPath($OutPath))) 'images'
}
$manifest = Join-Path $ImageDir 'manifest.json'

Write-Host "== 1/3  scanning for prompts ==" -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'Find-DocxImagePrompts.ps1') -Path $Path -ManifestPath $manifest -ConfigPath $ConfigPath
if ($LASTEXITCODE -eq 3) { Write-Host 'No image prompts in this document. Nothing to do.'; exit 0 }

# A diagram needs a spec, and writing one is a judgement call. Stop rather than
# quietly leave the diagrams out of the finished document.
$scan = Get-Content -LiteralPath $manifest -Raw -Encoding UTF8 | ConvertFrom-Json
$diag = @($scan.placeholders | Where-Object { $_.kind -eq 'diagram' })
if ($diag.Count -gt 0) {
  Write-Host ''
  Write-Host ("This document holds {0} diagram(s), which are built as native Word shapes from a spec." -f $diag.Count) -ForegroundColor Yellow
  foreach ($d in $diag) { Write-Host ("  {0}  para {1}" -f $d.id, $d.paraStart) -ForegroundColor Yellow }
  Write-Host 'Run the stages separately so each one gets a spec. See SKILL.md and references/diagram-specs.md.' -ForegroundColor Yellow
  Write-Host ("The scan is saved, so pick it up from: {0}" -f $manifest)
  exit 6
}

Write-Host "`n== 2/3  generating images ==" -ForegroundColor Cyan
$genArgs = @{ ManifestPath = $manifest; ImageDir = $ImageDir }
if ($ConfigPath) { $genArgs.ConfigPath = $ConfigPath }
if ($ApiKey)     { $genArgs.ApiKey     = $ApiKey }
& (Join-Path $PSScriptRoot 'New-DocImages.ps1') @genArgs

Write-Host "`n== 3/3  placing images ==" -ForegroundColor Cyan
$setArgs = @{ Path = $Path; ManifestPath = $manifest; OutPath = $OutPath }
if ($ConfigPath)   { $setArgs.ConfigPath = $ConfigPath }
if ($AllowMissing) { $setArgs.AllowMissing = $true }
& (Join-Path $PSScriptRoot 'Set-DocxImages.ps1') @setArgs

Write-Host "`nImages kept in $((Resolve-Path -LiteralPath $ImageDir).Path)" -ForegroundColor Green
