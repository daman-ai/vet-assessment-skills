# Lib-Audit.ps1 - shared loading and the ledger rules.
#
# One copy of the rules, used by both Resolve-AssuranceLedger.ps1 (run at the
# end of every phase) and Test-AuditPack.ps1 (run before delivery). Two copies
# would diverge, and the copy that diverges is always the one in the gate.

$ErrorActionPreference = 'Stop'

$script:AssetDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets'

function Get-AuditSources {
    $p = Join-Path $script:AssetDir 'sources.json'
    if (-not (Test-Path -LiteralPath $p)) { throw "Missing asset: $p" }
    return (Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Get-RequirementIndex {
    <#
      Every requirement from every framework asset, keyed by id. The gate's
      first check is that a finding's requirement id exists here: a typo
      silently orphans a finding from its requirement, and coverage then passes
      with a hole in it.
    #>
    $index = @{}

    $files = @(
        @{ File = 'requirements.outcome-standards-2025.json'; Framework = 'OS'   },
        @{ File = 'requirements.compliance-2025.json';        Framework = 'CS'   },
        @{ File = 'requirements.national-code-2018.json';     Framework = 'NC'   }
    )

    foreach ($f in $files) {
        $p = Join-Path $script:AssetDir $f.File
        if (-not (Test-Path -LiteralPath $p)) { throw "Missing asset: $p" }
        $j = Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json

        # @($missingProperty) is a ONE-ELEMENT array containing $null, not an
        # empty one, so every loop over an optional block filters nulls first.
        foreach ($r in (@($j.requirements) | Where-Object { $null -ne $_ })) {
            $index[$r.id] = [pscustomobject]@{
                Id = $r.id; Framework = $f.Framework; Source = $j.source
                Title = if ($r.PSObject.Properties['heading']) { $r.heading } elseif ($r.PSObject.Properties['title']) { $r.title } else { $r.id }
                Text = if ($r.PSObject.Properties['outcome']) { $r.outcome } elseif ($r.PSObject.Properties['requires']) { $r.requires } else { '' }
                Class = if ($r.PSObject.Properties['class']) { $r.class } else { 'MANDATORY' }
                QualityArea = if ($r.PSObject.Properties['qualityArea']) { $r.qualityArea } else { '' }
                CiteVerified = [bool]$j.structureVerifiedOn -and -not ($r.PSObject.Properties['detailVerified'] -and $r.detailVerified -eq $false)
            }
        }
        # The National Code asset carries Act-level obligations alongside the
        # eleven Standards. They are requirements too and must be coverable.
        foreach ($r in (@($j.actLevel) | Where-Object { $null -ne $_ })) {
            $index[$r.id] = [pscustomobject]@{
                Id = $r.id; Framework = 'ESOS'; Source = $r.source
                Title = $r.title; Text = $r.requires
                Class = if ($r.PSObject.Properties['class']) { $r.class } else { 'MANDATORY' }
                QualityArea = ''; CiteVerified = $true
            }
        }
    }
    return $index
}

function Set-ArrayField {
    <#
      Forces a property to a real array.

      In PowerShell, @($obj.missingProperty) is a ONE-ELEMENT array containing
      $null, not an empty array. So a finding with no 'treatments' key reads as
      having one treatment, and TreatmentCoverage passes on a Critical finding
      that nothing addresses - a gate that agrees with itself and is wrong.
      Normalising once here is the only reliable fix; every .Count in the rules
      depends on it.
    #>
    param($Object, [string[]]$Fields)
    if ($null -eq $Object) { return }
    foreach ($f in $Fields) {
        $val = if ($Object.PSObject.Properties[$f]) { $Object.$f } else { $null }
        $arr = @()
        if ($null -ne $val) { $arr = @($val | Where-Object { $null -ne $_ }) }
        if ($Object.PSObject.Properties[$f]) { $Object.$f = $arr }
        else { $Object | Add-Member -NotePropertyName $f -NotePropertyValue $arr }
    }
}

function Read-Ledger {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Ledger not found: $Path" }
    $l = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $l.PSObject.Properties['engagement']) { throw 'Ledger has no engagement block.' }

    Set-ArrayField -Object $l -Fields @('entities','documents','findings','treatments','indicators','risks','decisions','assumptions')
    foreach ($e in $l.entities)   { Set-ArrayField -Object $e -Fields @('frameworks','outOfScope','cohorts','scope') }
    foreach ($d in $l.documents)  { Set-ArrayField -Object $d -Fields @('entities','supersededRefs') }
    foreach ($f in $l.findings)   { Set-ArrayField -Object $f -Fields @('documentsSay','evidenceSeen','evidenceNeeded','treatments') }
    foreach ($t in $l.treatments) { Set-ArrayField -Object $t -Fields @('addresses') }
    foreach ($d in $l.decisions)  { Set-ArrayField -Object $d -Fields @('blocks') }
    return $l
}

function New-Issue {
    param([string]$Check, [ValidateSet('ERROR','WARN')][string]$Severity, [string]$Where, [string]$Message)
    [pscustomobject]@{ Check = $Check; Severity = $Severity; Where = $Where; Message = $Message }
}

# The bases that can support a maturity rating of 3 or above. 'document' is
# deliberately absent: a policy saying a thing happens is basis for 2 and
# nothing higher. references/gap-analysis.md carries the reasoning.
$script:EvidenceBases = @('record','sample','system','interview')
$script:GapTypes = @('absent','superseded','documented-not-operationalised','operational-no-evidence','below-good-practice','none')
$script:Priorities = @('Critical','High','Medium','Watch')
$script:Classes = @('MANDATORY','GUIDANCE','GOOD PRACTICE')

function Test-LedgerRules {
    <#
      Returns issues. ERROR blocks; WARN is reported and does not.
      $Phase limits which checks apply, so a Phase 2 ledger is not failed for
      having no risk register yet.
    #>
    param(
        [Parameter(Mandatory)]$Ledger,
        [Parameter(Mandatory)][hashtable]$Requirements,
        [int]$Phase = 6,
        $Sources
    )

    $issues = @()
    $findings = @($Ledger.findings)

    # --- ids resolve -------------------------------------------------------
    foreach ($f in $findings) {
        if (-not $f.requirement -or -not $Requirements.ContainsKey([string]$f.requirement)) {
            $issues += New-Issue 'RequirementIdsResolve' 'ERROR' $f.id "requirement '$($f.requirement)' is not in any framework asset"
        }
    }
    foreach ($i in @($Ledger.indicators)) {
        if ($i.requirement -and -not $Requirements.ContainsKey([string]$i.requirement)) {
            $issues += New-Issue 'RequirementIdsResolve' 'ERROR' $i.id "indicator names unknown requirement '$($i.requirement)'"
        }
    }

    $findingIds = @($findings | ForEach-Object { [string]$_.id })
    foreach ($t in @($Ledger.treatments)) {
        foreach ($a in @($t.addresses)) {
            if ($findingIds -notcontains [string]$a) {
                $issues += New-Issue 'RequirementIdsResolve' 'ERROR' $t.id "treatment addresses unknown finding '$a'"
            }
        }
    }

    # --- duplicate finding ids --------------------------------------------
    $dupe = $findings | Group-Object id | Where-Object { $_.Count -gt 1 }
    foreach ($d in $dupe) { $issues += New-Issue 'RequirementIdsResolve' 'ERROR' $d.Name "finding id used $($d.Count) times" }

    # --- coverage ----------------------------------------------------------
    if ($Phase -ge 2) {
        foreach ($e in @($Ledger.entities)) {
            $frameworks = @($e.frameworks)
            if (-not $frameworks -or $frameworks.Count -eq 0) {
                $issues += New-Issue 'CoverageComplete' 'ERROR' $e.id 'entity declares no frameworks; cannot compute coverage'
                continue
            }
            $excluded = @{}
            foreach ($o in @($e.outOfScope)) {
                if (-not $o.reason) { $issues += New-Issue 'CoverageComplete' 'ERROR' $e.id "out-of-scope '$($o.requirement)' has no reason" }
                $excluded[[string]$o.requirement] = $true
            }
            foreach ($rid in $Requirements.Keys) {
                $r = $Requirements[$rid]
                if ($frameworks -notcontains $r.Framework) { continue }
                if ($excluded.ContainsKey($rid)) { continue }
                $hit = $findings | Where-Object { [string]$_.requirement -eq $rid -and [string]$_.entity -eq [string]$e.id }
                if (-not $hit) {
                    $issues += New-Issue 'CoverageComplete' 'ERROR' $e.id "no finding for $rid"
                }
            }
        }
    }

    # --- per-finding rules -------------------------------------------------
    foreach ($f in $findings) {
        $w = "$($f.id) [$($f.entity)/$($f.requirement)]"

        if ($null -eq $f.maturity) {
            $issues += New-Issue 'MaturityBasis' 'ERROR' $w 'no maturity'
        } else {
            $m = [int]$f.maturity
            if ($m -lt 1 -or $m -gt 5) { $issues += New-Issue 'MaturityBasis' 'ERROR' $w "maturity $m is outside 1-5" }
            $basis = [string]$f.maturityBasis

            if ($m -ge 3) {
                if ([string]::IsNullOrWhiteSpace($basis)) {
                    $issues += New-Issue 'MaturityBasis' 'ERROR' $w "maturity $m needs a maturityBasis"
                } elseif ($script:EvidenceBases -notcontains $basis) {
                    $issues += New-Issue 'MaturityBasis' 'ERROR' $w "maturity $m on basis '$basis'. A policy is basis for 2 and nothing higher; use one of: $($script:EvidenceBases -join ', ')"
                }
            }
            if ($m -eq 4 -and $basis -notin @('record','system')) {
                $issues += New-Issue 'MaturityBasis' 'ERROR' $w "maturity 4 means monitored; basis must be 'record' or 'system', not '$basis'"
            }
            if ($m -eq 5 -and $basis -ne 'system') {
                $issues += New-Issue 'MaturityBasis' 'ERROR' $w "maturity 5 means self-assuring; basis must be 'system', not '$basis'"
            }
            if ($m -eq 2 -and $basis -eq 'document' -and @($f.evidenceNeeded).Count -eq 0) {
                $issues += New-Issue 'EvidenceNeeded' 'ERROR' $w 'maturity 2 on a document with nothing in evidenceNeeded'
            }
        }

        $gt = [string]$f.gapType
        if ($script:GapTypes -notcontains $gt) {
            $issues += New-Issue 'GapTypeConsistent' 'ERROR' $w "gapType '$gt' is not one of: $($script:GapTypes -join ', ')"
        } elseif ($gt -eq 'none' -and [int]$f.maturity -lt 4) {
            $issues += New-Issue 'GapTypeConsistent' 'ERROR' $w "gapType 'none' at maturity $($f.maturity). No gap means monitored or better"
        } elseif ($gt -ne 'none' -and [int]$f.maturity -eq 5) {
            $issues += New-Issue 'GapTypeConsistent' 'ERROR' $w "maturity 5 with gapType '$gt'"
        }

        if ($script:Priorities -notcontains [string]$f.priority) {
            $issues += New-Issue 'GapTypeConsistent' 'ERROR' $w "priority '$($f.priority)' is not one of: $($script:Priorities -join ', ')"
        }

        $cls = [string]$f.class
        if ($script:Classes -notcontains $cls) {
            $issues += New-Issue 'CitationClass' 'ERROR' $w "class '$cls' is not one of: $($script:Classes -join ', ')"
        } elseif ($cls -eq 'MANDATORY') {
            if (-not $f.citation -or -not $f.citation.source -or -not $f.citation.ref) {
                $issues += New-Issue 'CitationClass' 'ERROR' $w 'MANDATORY with no citation source and ref'
            }
        } elseif ($cls -eq 'GOOD PRACTICE' -and $f.citation -and $f.citation.ref) {
            $issues += New-Issue 'CitationClass' 'ERROR' $w 'GOOD PRACTICE carrying a clause citation. A recommendation dressed as law'
        }

        if ($f.citation -and $f.citation.source -and $Sources) {
            $known = @($Sources.sources | ForEach-Object { $_.id })
            if ($known -notcontains [string]$f.citation.source) {
                $issues += New-Issue 'NoFabricatedClauses' 'ERROR' $w "citation source '$($f.citation.source)' is not in sources.json"
            }
        }
        if ($f.citation -and -not $f.citation.verified) {
            $issues += New-Issue 'CitationVerified' 'WARN' $w "citation '$($f.citation.ref)' not verified this run"
        }

        if ([string]::IsNullOrWhiteSpace([string]$f.outcomePlain)) {
            $issues += New-Issue 'GapTypeConsistent' 'ERROR' $w 'no outcomePlain. Restate the requirement in plain English before rating it'
        }
        if ([string]::IsNullOrWhiteSpace([string]$f.risk)) {
            $issues += New-Issue 'GapTypeConsistent' 'ERROR' $w 'no risk stated'
        } elseif ([string]$f.risk -match '(?i)^non-?compliance with') {
            $issues += New-Issue 'GapTypeConsistent' 'WARN' $w 'risk restates the finding. Name the consequence in this entity''s circumstances'
        }
    }

    # --- placeholders ------------------------------------------------------
    # New-Ledger.ps1 writes TODO into every stub. Maturity 0 and gapType TODO
    # already block, but the prose fields do not - and a finding with a real
    # rating and a TODO risk sentence would otherwise render into the pack.
    foreach ($f in $findings) {
        $blob = @($f.outcomePlain, $f.risk, $f.gapType, $f.maturityBasis, ($f.evidenceNeeded -join ' '), ($f.evidenceSeen -join ' ')) -join ' '
        if ($blob -match 'TODO') { $issues += New-Issue 'NoPlaceholders' 'ERROR' $f.id 'still carries a TODO placeholder' }
    }
    foreach ($e in @($Ledger.entities)) {
        $blob = @($e.legalName, $e.rtoCode, $e.cricosCode) -join ' '
        if ($blob -match 'TODO') { $issues += New-Issue 'NoPlaceholders' 'ERROR' $e.id 'entity still carries a TODO placeholder' }
    }
    foreach ($t in @($Ledger.treatments)) {
        $blob = @($t.title, $t.owner, $t.deliverable) -join ' '
        if ($blob -match 'TODO') { $issues += New-Issue 'NoPlaceholders' 'ERROR' $t.id 'treatment still carries a TODO placeholder' }
    }
    if ([string]$Ledger.engagement.preparedBy -match 'TODO' -and $Phase -ge 3) {
        $issues += New-Issue 'NoPlaceholders' 'ERROR' 'engagement' 'preparedBy is still TODO'
    }

    # --- treatments --------------------------------------------------------
    if ($Phase -ge 4) {
        foreach ($f in $findings) {
            if ([string]$f.priority -in @('Critical','High') -and @($f.treatments).Count -eq 0) {
                $issues += New-Issue 'TreatmentCoverage' 'ERROR' $f.id "$($f.priority) finding with no treatment"
            }
        }
        foreach ($t in @($Ledger.treatments)) {
            if ([string]::IsNullOrWhiteSpace([string]$t.owner)) { $issues += New-Issue 'TreatmentsOwned' 'ERROR' $t.id 'treatment has no owner' }
            if ([string]::IsNullOrWhiteSpace([string]$t.due))   { $issues += New-Issue 'TreatmentsOwned' 'ERROR' $t.id 'treatment has no due date' }
        }
    }

    # --- risks -------------------------------------------------------------
    if ($Phase -ge 5) {
        if (@($Ledger.risks).Count -eq 0) { $issues += New-Issue 'RisksReviewed' 'ERROR' 'risks' 'no risk register at Phase 5' }
        foreach ($r in @($Ledger.risks)) {
            if ([string]::IsNullOrWhiteSpace([string]$r.owner))  { $issues += New-Issue 'RisksReviewed' 'ERROR' $r.id 'risk has no owner' }
            if ([string]::IsNullOrWhiteSpace([string]$r.review)) { $issues += New-Issue 'RisksReviewed' 'ERROR' $r.id 'risk has no review date' }
            if ([string]$r.controlEffectiveness -notin @('effective','partially effective','ineffective','untested')) {
                $issues += New-Issue 'RisksReviewed' 'ERROR' $r.id "controlEffectiveness '$($r.controlEffectiveness)' is not one of: effective, partially effective, ineffective, untested"
            }
        }
    }

    # --- entities ----------------------------------------------------------
    foreach ($e in @($Ledger.entities)) {
        if (-not $e.verifiedOn) { $issues += New-Issue 'EntitiesVerified' 'WARN' $e.id 'codes and scope not recorded as verified against the National Register' }
    }
    if (@($Ledger.entities).Count -eq 0) { $issues += New-Issue 'EntitiesVerified' 'ERROR' 'entities' 'ledger has no entities' }

    # --- source freshness --------------------------------------------------
    if ($Sources) {
        $run = [datetime]::Parse($Ledger.engagement.runDate)
        foreach ($s in @($Sources.sources)) {
            if (-not $s.checkedOn) { continue }
            $age = ($run - [datetime]::Parse($s.checkedOn)).TotalDays
            if ($age -gt 90) {
                $issues += New-Issue 'SourcesFresh' 'WARN' $s.id ("checked {0:n0} days before the run date. Re-fetch and update checkedOn" -f $age)
            }
        }
    }

    # --- personal data -----------------------------------------------------
    # A finding is where student names leak: it is natural to write "the record
    # for [student] shows no follow-up", and the pack then travels by email.
    $usi = '(?<![A-Za-z0-9])[A-Za-z0-9]{10}(?![A-Za-z0-9])'
    # Capitalisation is the whole signal here, so the name half of the pattern
    # must stay case-SENSITIVE. An (?i) covering the whole expression makes
    # [A-Z][a-z]+ match any word at all, and "student loses their provider"
    # reads as a person's name.
    $namePattern = '\b[Ss]tudent\s+([A-Z][a-z]+)\s+([A-Z][a-z]+)|\b[Ll]earner\s+([A-Z][a-z]+)\s+([A-Z][a-z]+)'
    $roleWords = @('Support','Services','Service','Handbook','Management','Administration','Record','Records',
                   'Feedback','Assessment','Progress','Welfare','Officer','Coordinator','Enrolment','Enrolments',
                   'Identifier','Declaration','Agreement','Policy','Procedure','Register','Intervention','Advisor','Adviser')
    foreach ($f in $findings) {
        $blob = @($f.risk, $f.outcomePlain, ($f.evidenceSeen -join ' '), ($f.evidenceNeeded -join ' ')) -join ' '
        if ($blob -match '(?i)\bUSI\b\s*:?\s*' + $usi) {
            $issues += New-Issue 'NoPersonalData' 'ERROR' $f.id 'looks like a student identifier in the finding text'
        }
        foreach ($m in [regex]::Matches($blob, $namePattern)) {
            $pair = @($m.Groups[1].Value, $m.Groups[2].Value, $m.Groups[3].Value, $m.Groups[4].Value) | Where-Object { $_ }
            if (@($pair | Where-Object { $roleWords -contains $_ }).Count -gt 0) { continue }
            $issues += New-Issue 'NoPersonalData' 'ERROR' $f.id ("'{0}' reads as a named individual. Write the case, not the person" -f ($pair -join ' '))
        }
    }

    return $issues
}

function Write-IssueReport {
    # AllowNull matters: an empty array returned from a function unrolls to
    # $null on the way out, so a clean run would otherwise fail to bind here -
    # the gate erroring out precisely when everything passed.
    param([Parameter(Mandatory)][AllowNull()][AllowEmptyCollection()][array]$Issues, [switch]$Quiet)

    $Issues = @($Issues | Where-Object { $null -ne $_ })
    $errors = @($Issues | Where-Object { $_.Severity -eq 'ERROR' })
    $warns  = @($Issues | Where-Object { $_.Severity -eq 'WARN' })

    if (-not $Quiet) {
        foreach ($grp in ($Issues | Group-Object Check | Sort-Object Name)) {
            $e = @($grp.Group | Where-Object { $_.Severity -eq 'ERROR' }).Count
            $tag = if ($e) { 'FAIL' } else { 'warn' }
            Write-Host ("{0}  {1} ({2})" -f $tag, $grp.Name, $grp.Count)
            foreach ($i in $grp.Group | Select-Object -First 12) {
                Write-Host ("      {0}  {1}: {2}" -f $i.Severity, $i.Where, $i.Message)
            }
            if ($grp.Count -gt 12) { Write-Host ("      ... and {0} more" -f ($grp.Count - 12)) }
        }
    }
    return [pscustomobject]@{ Errors = $errors.Count; Warnings = $warns.Count; Issues = $Issues }
}
