<#
    Get-UnitRecord.ps1 - harvest units of competency from training.gov.au into
    the curriculum registry's unit cache, one JSON file per unit.

    training.gov.au renders as a JavaScript application, so the HTML pages are
    empty to a plain fetch. Its REST API is not: every unit's elements,
    performance criteria, performance evidence, knowledge evidence, assessment
    conditions and prerequisites are served as JSON and reachable with
    Invoke-RestMethod. That is what this script uses, and it is why a 136-unit
    harvest takes minutes rather than an afternoon of browser navigation.

        .\Get-UnitRecord.ps1 -Code SITXFSA005
        .\Get-UnitRecord.ps1 -CodeFile units.txt -OutDir ..\assets\units

    THE CURRENCY FIELD IS THE POINT OF THE CACHE, NOT A DECORATION. Every
    record carries the unit's usage recommendation and the date it changed.
    A superseded unit still returns a complete record - the training package
    keeps serving it - so nothing downstream can tell a current unit from a
    dead one except this field. Assert-Registry reads it and fails the course
    that still lists a superseded unit.

    Records are refreshed only with -Force. A harvest is a network operation
    against a public register; re-running it for units already cached wastes
    minutes and risks a half-written cache if the network drops midway.
#>
[CmdletBinding()]
param(
    [string]   $Code,
    [string]   $CodeFile,
    [string]   $OutDir,
    [switch]   $Force,
    [int]      $DelayMs = 120
)

$ErrorActionPreference = 'Stop'
if (-not $OutDir) {
    $root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $OutDir = Join-Path $root "../assets/units"
}
$ApiVersion = '1.0'
$Base       = 'https://training.gov.au/api'

function ConvertFrom-TgaHtml {
    param([string]$Html)
    if ([string]::IsNullOrWhiteSpace($Html)) { return '' }
    $t = $Html
    $t = $t -replace '(?is)<(script|style)[^>]*>.*?</\1>', ''
    # Row and cell boundaries become line breaks before tags are stripped, or a
    # table collapses into one unreadable line.
    $t = $t -replace '(?i)</(li|p|tr|td|th|div|h[1-6])\s*>', "`n"
    $t = $t -replace '(?i)<br\s*/?>', "`n"
    $t = $t -replace '(?s)<[^>]+>', ''
    $t = [System.Net.WebUtility]::HtmlDecode($t)
    $t = $t -replace '\u00A0', ' '
    $lines = $t -split "`r?`n" | ForEach-Object { ($_ -replace '[ \t]+', ' ').Trim() } | Where-Object { $_.Length -gt 0 }
    return ($lines -join "`n")
}

function Get-Json {
    param([string]$Uri)
    for ($try = 1; $try -le 3; $try++) {
        try { return Invoke-RestMethod -Uri $Uri -TimeoutSec 45 -Headers @{ Accept = 'application/json' } }
        catch {
            if ($try -eq 3) { throw }
            Start-Sleep -Milliseconds (400 * $try)
        }
    }
}

function Get-UnitRecord {
    param([string]$UnitCode)

    $meta = Get-Json "$Base/training/$UnitCode`?api-version=$ApiVersion&include=all"

    # The current release, or the highest-numbered one where none is current -
    # a superseded unit has no current release and must still return a record
    # so the caller can SEE that it is superseded.
    $rel = $meta.releases | Where-Object { $_.currency -eq 'current' } | Select-Object -First 1
    if (-not $rel) { $rel = $meta.releases | Sort-Object { [int]$_.releaseNumber } -Descending | Select-Object -First 1 }
    if (-not $rel) { throw "no releases returned for $UnitCode" }

    $full = Get-Json "$Base/training/$UnitCode/releases/$($rel.releaseNumber)`?include=All&api-version=$ApiVersion"

    $sections = [ordered]@{}
    foreach ($bundle in $full.contentBundles) {
        $b = Get-Json "$Base/content/bundle/$($bundle.id)"
        foreach ($item in ($b.items | Sort-Object { [int]$_.sequence })) {
            if (-not $item.title) { continue }
            $sections[$item.title] = ConvertFrom-TgaHtml $item.content
        }
    }

    $pre = @()
    if ($meta.preRequisites -and $meta.preRequisites.preRequisites) {
        $pre = @($meta.preRequisites.preRequisites | ForEach-Object {
            [ordered]@{ code = $_.code; title = $_.title }
        })
    }

    $get = { param($n) if ($sections.Contains($n)) { $sections[$n] } else { '' } }

    [ordered]@{
        schemaVersion        = '1.0'
        code                 = $meta.code
        title                = $meta.title
        type                 = $meta.type
        status               = $meta.usageRecommendation
        statusLabel          = $meta.usageRecommendationLabel
        releaseNumber        = $rel.releaseNumber
        releaseDate          = $rel.releaseDate
        currency             = $rel.currency
        trainingPackage      = ($UnitCode -replace '^([A-Z]{3}).*$', '$1')
        prerequisites        = $pre
        competencyField      = (& $get 'Competency field')
        unitSector           = (& $get 'Unit sector')
        application          = (& $get 'Application')
        elements             = (& $get 'Elements and performance criteria')
        foundationSkills     = (& $get 'Foundation skills')
        performanceEvidence  = (& $get 'Performance evidence')
        knowledgeEvidence    = (& $get 'Knowledge evidence')
        assessmentConditions = (& $get 'Assessment conditions')
        sourceUrl            = "https://training.gov.au/training/details/$UnitCode/unitdetails"
        fetchedUtc           = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    }
}

# --- run ---------------------------------------------------------------

$codes = @()
if ($Code)     { $codes += $Code }
if ($CodeFile) { $codes += (Get-Content -LiteralPath $CodeFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[A-Z]{3}' }) }
$codes = $codes | Select-Object -Unique
if (-not $codes) { throw 'nothing to harvest: pass -Code or -CodeFile' }

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$OutDir = (Resolve-Path $OutDir).Path

$ok = 0; $skip = 0; $fail = @()
foreach ($c in $codes) {
    $dest = Join-Path $OutDir "$c.json"
    if ((Test-Path $dest) -and -not $Force) { $skip++; continue }
    try {
        $rec = Get-UnitRecord -UnitCode $c
        $json = $rec | ConvertTo-Json -Depth 8
        [System.IO.File]::WriteAllText($dest, $json, (New-Object System.Text.UTF8Encoding $true))
        $flag = if ($rec.status -ne 'current') { "  ** $($rec.statusLabel) **" } else { '' }
        Write-Host ("  {0,-12} {1}{2}" -f $rec.code, $rec.title, $flag)
        $ok++
    } catch {
        $fail += "$c :: $($_.Exception.Message)"
        Write-Host ("  {0,-12} FAILED: {1}" -f $c, $_.Exception.Message) -ForegroundColor Red
    }
    Start-Sleep -Milliseconds $DelayMs
}

Write-Host ''
Write-Host "harvested $ok, cached-already $skip, failed $($fail.Count)"
if ($fail) { $fail | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }; exit 1 }
