<#
  Get-UnitPrerequisites.ps1 — read a unit's Pre-requisite unit field from
  training.gov.au.

  WHY THIS IS NOT A ONE-LINE FETCH. training.gov.au is a client-rendered Nuxt
  application. A plain GET of

      https://training.gov.au/training/details/<CODE>/unitdetails

  returns HTTP 200 and about 3.3 KB of empty shell — a viewport tag, a stylesheet
  list and <div id="__nuxt"></div>. It contains no unit content and the string
  'prerequisite' appears in it zero times. A lookup written against that page
  finds no Pre-requisite unit field, and a careless implementation concludes the
  unit has none. That is the exact failure this script exists to prevent.

  So it reads the JSON API the page itself calls:

      https://training.gov.au/api/training/<CODE>?api-version=1.0&include=all

  which returns, among much else:

      "preRequisites": {
        "hasPreRequisites": true,
        "preRequisites": [ { "code": "SITXFSA005", "title": "Use hygienic..." } ]
      }

  NIL MEANS NIL. NOTHING ELSE DOES. An empty response, a failed request, a
  timeout, a redirect, a unit that cannot be found, or a payload without the
  preRequisites object is 'unknown' — never 'none'. 'unknown' stops the run and
  asks the assessor. See references/prerequisite-lookup.md.

  Usage:
    .\Get-UnitPrerequisites.ps1 -Unit SITHPAT016
    .\Get-UnitPrerequisites.ps1 -Unit SITHPAT016 -Refresh
    .\Get-UnitPrerequisites.ps1 -Unit SITHPAT016 -Json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Unit,
    [string]$CachePath,
    [switch]$Refresh,
    [switch]$Json,
    [switch]$Quiet,
    [int]$TimeoutSec = 30
)

$ErrorActionPreference = 'Stop'

$ApiBase  = 'https://training.gov.au/api/training'
$PageUrl  = 'https://training.gov.au/training/details/{0}/unitdetails'
$code     = $Unit.ToUpper().Trim()
$url      = "$ApiBase/$code`?api-version=1.0&include=all"

if (-not $CachePath) { $CachePath = Join-Path $PSScriptRoot '..\assets\prerequisites.cache.json' }

function Read-Cache {
    if (-not (Test-Path -LiteralPath $CachePath)) { return @{} }
    try {
        $raw = Get-Content -Raw -Encoding UTF8 -LiteralPath $CachePath | ConvertFrom-Json
        $h = @{}
        foreach ($p in $raw.PSObject.Properties) { if ($p.Name -notlike '_*') { $h[$p.Name] = $p.Value } }
        $h
    } catch { @{} }
}

function Write-Cache {
    param($Table)
    $obj = [ordered]@{
        '_comment' = 'Cached training.gov.au Pre-requisite unit lookups, keyed by unit code. Each entry records the endpoint it came from and the date it was read, so a marking run is reproducible and an auditor can see when the check was made. Only successful lookups are cached: an unknown is never stored, because a cached unknown would look like an answer.'
        '_endpoint' = "$ApiBase/<CODE>?api-version=1.0&include=all"
    }
    foreach ($k in ($Table.Keys | Sort-Object)) { $obj[$k] = $Table[$k] }
    $dir = Split-Path -Parent $CachePath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    ($obj | ConvertTo-Json -Depth 8) | Out-File -Encoding utf8 -LiteralPath $CachePath
}

# ------------------------------------------------------------------ cache ----

$cache = Read-Cache
if (-not $Refresh -and $cache.ContainsKey($code)) {
    $hit = $cache[$code]
    if (-not $Quiet) { Write-Output ("CACHED  {0}  read {1} from {2}" -f $code, $hit.checkedOn, $hit.source) }
    if ($Json) { $hit | ConvertTo-Json -Depth 8; return }
    return $hit
}

# ----------------------------------------------------------------- lookup ----

$result = [pscustomobject]@{
    unit                       = $code
    status                     = 'unknown'
    prerequisites              = @()
    prerequisitesConfirmedNone = $false
    source                     = $url
    pageUrl                    = ($PageUrl -f $code)
    checkedOn                  = (Get-Date).ToString('yyyy-MM-dd')
    note                       = $null
}

try {
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }
    $resp = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec $TimeoutSec -UseBasicParsing -Headers @{ Accept = 'application/json' }

    if ($null -eq $resp) {
        $result.note = 'the endpoint returned nothing'
    }
    elseif (-not $resp.PSObject.Properties.Name.Contains('preRequisites') -or $null -eq $resp.preRequisites) {
        # The payload came back but carries no preRequisites object. That is a
        # changed contract, not a unit without prerequisites.
        $result.note = "the response carries no 'preRequisites' object — the API contract may have changed"
    }
    else {
        $pr = $resp.preRequisites
        $list = @()
        if ($pr.PSObject.Properties.Name.Contains('preRequisites') -and $pr.preRequisites) {
            foreach ($p in @($pr.preRequisites)) {
                if ($p.code) { $list += [pscustomobject]@{ code = "$($p.code)"; title = "$($p.title)" } }
            }
        }
        $has = $false
        if ($pr.PSObject.Properties.Name.Contains('hasPreRequisites')) { $has = [bool]$pr.hasPreRequisites }

        if ($list.Count -gt 0) {
            $result.status        = 'found'
            $result.prerequisites = $list
        }
        elseif (-not $has) {
            # hasPreRequisites is explicitly false AND the list is empty. This is
            # the only shape that means Nil.
            $result.status                     = 'none'
            $result.prerequisitesConfirmedNone = $true
        }
        else {
            # hasPreRequisites true but nothing listed — contradictory, so unknown.
            $result.note = 'hasPreRequisites is true but no prerequisite units were listed'
        }
    }
} catch {
    $result.note = "the lookup failed: $($_.Exception.Message)"
}

if ($result.status -eq 'unknown') {
    if (-not $Quiet) {
        Write-Output ''
        Write-Output "PREREQUISITE UNKNOWN — $code"
        Write-Output ("  $($result.note)")
        Write-Output ''
        Write-Output '  This is NOT a statement that the unit has no prerequisite. Nil means Nil;'
        Write-Output '  nothing else does. The run stops here.'
        Write-Output ''
        Write-Output '  Ask the assessor to confirm the Pre-requisite unit from the unit of'
        Write-Output '  competency itself or the training package companion volume, then record it'
        Write-Output '  in the ledger:'
        Write-Output ''
        Write-Output '     "prerequisites": [ { "code": "...", "title": "..." } ]'
        Write-Output '   or, where the unit genuinely has none,'
        Write-Output '     "prerequisites": [], "prerequisitesConfirmedNone": true'
        Write-Output ''
        Write-Output ("  Page for a human to read: $($result.pageUrl)")
        Write-Output ''
    }
    if ($Json) { $result | ConvertTo-Json -Depth 8 }
    exit 2
}

# only a definite answer is cached; a cached unknown would look like an answer
$cache[$code] = $result
Write-Cache $cache

if (-not $Quiet) {
    if ($result.status -eq 'none') {
        Write-Output ("{0}  —  Pre-requisite unit: Nil (confirmed by the register)" -f $code)
    } else {
        Write-Output ("{0}  —  {1} prerequisite(s):" -f $code, $result.prerequisites.Count)
        foreach ($p in $result.prerequisites) { Write-Output ("    {0}  {1}" -f $p.code, $p.title) }
    }
    Write-Output ("  source {0}" -f $result.source)
    Write-Output ("  read   {0}" -f $result.checkedOn)
}

if ($Json) { $result | ConvertTo-Json -Depth 8; return }
$result
