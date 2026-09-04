<#
  New-Ledger.ps1 - scaffold assurance.json with one finding stub per in-scope
  requirement, per entity.

  Coverage is the thing a gap analysis is most likely to get wrong, and the way
  it goes wrong is boring: forty requirement ids typed by hand, two of them
  mistyped, and the two mistyped ones are the requirements nobody assessed.

  So the stubs are generated from the framework assets. Every in-scope
  requirement has a row before any judgement is made, each carrying its own
  outcome text, its class and its citation. Filling them in is the work;
  remembering them is not.

  Stubs are inert: maturity 0 and gapType TODO both fail the resolver, so a
  scaffold cannot be delivered by accident.

  Usage:
    .\New-Ledger.ps1 -Ledger assurance.json -Name "ACI and MVC uplift" `
        -Entity ACI -Frameworks OS,CS,NC,ESOS
    .\New-Ledger.ps1 -Ledger assurance.json -Entity MVC -Frameworks OS,CS   # add a second entity
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Ledger,
    [Parameter(Mandatory)][string]$Entity,
    [ValidateSet('OS','CS','NC','ESOS')][string[]]$Frameworks = @('OS','CS'),
    [string]$Name,
    [string]$LegalName,
    [string]$RtoCode,
    [string]$CricosCode,
    [string]$RunDate,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-Audit.ps1')

if (-not $RunDate) { $RunDate = Get-Date -Format 'yyyy-MM-dd' }
$req = Get-RequirementIndex

# --------------------------------------------------------------- existing ---

if (Test-Path -LiteralPath $Ledger) {
    $l = Get-Content -LiteralPath $Ledger -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    $l = [pscustomobject]@{
        engagement = [pscustomobject]@{
            name = if ($Name) { $Name } else { 'UNNAMED ENGAGEMENT' }
            runDate = $RunDate
            phase = 1
            preparedBy = 'TODO'
            notARegulatoryDetermination = $true
        }
    }
}
foreach ($k in 'entities','documents','findings','treatments','indicators','risks','decisions','assumptions') {
    if (-not $l.PSObject.Properties[$k]) { $l | Add-Member -NotePropertyName $k -NotePropertyValue @() }
}
if ($Name) { $l.engagement.name = $Name }

# ----------------------------------------------------------------- entity ---

$ent = @($l.entities) | Where-Object { [string]$_.id -eq $Entity } | Select-Object -First 1
if (-not $ent) {
    $ent = [pscustomobject]@{
        id = $Entity
        legalName = if ($LegalName) { $LegalName } else { 'TODO' }
        rtoCode = if ($RtoCode) { $RtoCode } else { 'TODO' }
        cricosCode = if ($CricosCode) { $CricosCode } else { '' }
        cohorts = @()
        scope = @()
        frameworks = $Frameworks
        outOfScope = @()
        verifiedOn = ''
        verifiedAgainst = ''
    }
    $l.entities = @(@($l.entities) + $ent)
    if (-not $Quiet) { Write-Host "Added entity $Entity" }
} else {
    $ent.frameworks = $Frameworks
    if ($LegalName)  { $ent.legalName = $LegalName }
    if ($RtoCode)    { $ent.rtoCode = $RtoCode }
    if ($CricosCode) { $ent.cricosCode = $CricosCode }
    if (-not $Quiet) { Write-Host "Updated entity $Entity" }
}

if (($Frameworks -contains 'NC' -or $Frameworks -contains 'ESOS') -and -not $ent.cricosCode) {
    Write-Warning "$Entity is scoped to the National Code / ESOS with no CRICOS code recorded. Confirm the entity is CRICOS-registered before assessing against it."
}

# ------------------------------------------------------------------ stubs ---

$existing = @{}
foreach ($f in @($l.findings)) { $existing["$($f.entity)|$($f.requirement)"] = $true }

$nextId = 1
foreach ($f in @($l.findings)) { if ($f.id -match '^F(\d+)$') { $n = [int]$Matches[1]; if ($n -ge $nextId) { $nextId = $n + 1 } } }

$added = 0
$stubs = @()
foreach ($rid in ($req.Keys | Sort-Object)) {
    $r = $req[$rid]
    if ($Frameworks -notcontains $r.Framework) { continue }
    if ($existing.ContainsKey("$Entity|$rid")) { continue }

    $stubs += [pscustomobject]@{
        id = ('F{0:d3}' -f $nextId)
        requirement = $rid
        entity = $Entity
        requirementText = $r.Text          # for reading while filling in; not rendered
        outcomePlain = 'TODO restate in plain English - what would an assessor see happening, and see recorded?'
        documentsSay = @()
        gapType = 'TODO'
        maturity = 0
        maturityBasis = 'document'
        evidenceSeen = @()
        evidenceNeeded = @()
        risk = 'TODO name the consequence in this entity''s circumstances'
        priority = 'Medium'
        class = $r.Class
        citation = [pscustomobject]@{ source = $r.Source; ref = $r.Title; verified = $false }
        treatments = @()
    }
    $nextId++; $added++
}

$l.findings = @(@($l.findings) + $stubs)
$l | ConvertTo-Json -Depth 12 | Out-File -LiteralPath $Ledger -Encoding utf8

if (-not $Quiet) {
    Write-Host ("Frameworks  {0}" -f ($Frameworks -join ', '))
    Write-Host ("Stubs added {0}   findings now {1}" -f $added, @($l.findings).Count)
    Write-Host ("Ledger      {0}" -f (Resolve-Path -LiteralPath $Ledger).Path)
    Write-Host ''
    Write-Host 'Every stub carries maturity 0 and gapType TODO, both of which fail the'
    Write-Host 'resolver. Fill them in, then run Resolve-AssuranceLedger.ps1.'
}
