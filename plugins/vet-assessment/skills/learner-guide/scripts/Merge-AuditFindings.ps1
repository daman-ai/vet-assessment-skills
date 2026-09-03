<#
    Merge-AuditFindings.ps1 - merge every reviewer's findings.json into ONE
    findings.json and ONE merged_audit.md, by rule and never by judgement.

        & "$SkillDir\scripts\Merge-AuditFindings.ps1" -ReviewDir $out\cleanroom\review -UnitExtract $out\unit_extract.md -OutPath $out\cleanroom\review\merged\findings.json

    WHY THIS IS A SCRIPT AND NOT AN AGENT. The clean-room audit is split into
    topic reviewers and a cross-document reviewer who cannot see each other,
    because a reviewer handed another reviewer's findings stops being a
    second opinion. A merger that SUMMARISED would be a ninth reviewer with
    sight of the other eight - it would decide which findings matter, soften
    the ones it found unconvincing, and reword the ones it found clumsy, and
    the isolation rule that makes the split worth anything would be gone at
    the last step. So this merger never summarises and never rewords. Every
    finding's text leaves this script byte-for-byte as it arrived. What the
    merger does is arithmetic:

      union     every reviewer's coverage[] claims, checked against the KE
                and PE items of the unit extract; any item NO reviewer claims
                becomes a High finding of class not-taught, raised here,
                because eight reviewers each holding one topic cannot see the
                item that fell between them
      concat    every finding, stamped with its reviewer
      dedupe    on (anchor, class) - the same defect at the same locator
                reported by two reviewers is one finding; the copy with the
                worst risk is kept verbatim and the others travel on it,
                each with its own claim, value and replacement verbatim, so
                dedupe collapses the count and never a reviewer's words
      worst     the delivery-set verdict per artefact is the WORST any
                reviewer gave it; and where a High finding remains, a
                Fully Compliant verdict is floored to Partially Compliant,
                because the checklist's own decision rule says Fully requires
                no High defect - that is a rule, not an opinion
      reject    a findings.json that does not meet the contract - an unknown
                class, an unanchored finding, a verdict that is not one of
                the three - fails the whole merge with every violation named,
                because Stage 6b arbitration consumes class, value and source
                and silently skips what it does not recognise

    A MISSING REVIEWER IS A MISSING REVIEWER. Every pack directory that
    carries a SCOPE.md (or is named in manifest.json) must carry a
    findings.json, or the merge FAILS naming the absentee. Seven of eight
    merged quietly is how an untaught topic ships with a green verdict.

    THE CLASS LIST IS THE ONE STAGE 6b CONSUMES. fabricated, unsourced,
    misattributed, wrong-value, wrong-clause, leak, not-taught,
    missing-target, other. Exactly those names; the checklist documents them.

    NO unit code, brand or build path is hard-coded. The item list comes
    from the unit extract handed in; the reviewer set from the directory.

    PS 5.1 TRAP, KEPT OUT OF THIS FILE ON PURPOSE: @($list) on a
    List[object] throws "Argument types do not match" from the engine's
    array binder (List[int] and List[string] do not trigger it). Lists are
    returned with .ToArray(), never wrapped in @().

    TRUSTED ONLY AFTER PASSING ON PLANTED INPUT. -SelfTest writes two
    synthetic reviewers and a synthetic unit extract with a KE item nobody
    claims, a finding both reviewers report at the same anchor with
    different risks, and disagreeing verdicts, then asserts the uncovered
    item is raised, the duplicate collapses to the worse risk, the worst
    verdict wins, every claim string round-trips unchanged, and a
    contract violation is refused.

    PS 5.1. ASCII only in this file.
    Exit 0 merged with no High finding, 1 merged with High finding(s)
    remaining (including any uncovered item), 2 a usage or contract error,
    4 the self-test failed.
#>

[CmdletBinding()]
param(
    [string] $ReviewDir,
    [string] $UnitExtract,
    [string] $OutPath,
    [string] $MarkdownPath,
    [switch] $SelfTest,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

$GATE = 'MERGE FINDINGS'

#  The contract. The class names are the ones Test-Finding.ps1 (Stage 6b)
#  consumes; the checklist lists them with their meanings.
$script:FindingClasses = @('fabricated', 'unsourced', 'misattributed', 'wrong-value', 'wrong-clause', 'leak', 'not-taught', 'missing-target', 'other')
$script:RiskRank = @{ 'critical' = 3; 'high' = 2; 'medium' = 1; 'low' = 0 }
$script:VerdictNames = @('Fully Compliant', 'Partially Compliant', 'Not Compliant')

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Write-Utf8File {
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][AllowEmptyString()][string] $Content)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($true)))
}

function Get-RiskRank {
    param([AllowEmptyString()][string] $Risk)
    $k = "$Risk".Trim().ToLowerInvariant()
    if ($script:RiskRank.ContainsKey($k)) { return [int]$script:RiskRank[$k] }
    return -1
}

function ConvertTo-VerdictRank {
    param([AllowEmptyString()][string] $Verdict)
    $s = "$Verdict".Trim().ToLowerInvariant()
    if (-not $s) { return -2 }
    if ($s -like 'fully compliant*') { return 0 }
    if ($s -like 'partially compliant*') { return 1 }
    if ($s -like 'not compliant*') { return 2 }
    return -1
}

function Get-VerdictName {
    param([int] $Rank)
    if ($Rank -ge 0 -and $Rank -le 2) { return $script:VerdictNames[$Rank] }
    return 'not stated'
}

function ConvertTo-ItemId {
    <# "ke 2A" -> "KE2a"; anything that is not a KE/PE identifier is returned trimmed, for the report to name. #>
    param([AllowEmptyString()][string] $Item)
    $s = "$Item" -replace '\s', ''
    $m = [regex]::Match($s, '^(?i)(KE|PE)(\d+)([A-Za-z])?$')
    if ($m.Success) { return ($m.Groups[1].Value.ToUpperInvariant() + $m.Groups[2].Value + $m.Groups[3].Value.ToLowerInvariant()) }
    return "$Item".Trim()
}

function Get-FindingAnchor {
    param($Finding)
    $a = ''; $l = ''
    if ($null -ne $Finding -and @($Finding.PSObject.Properties.Name) -contains 'where' -and $null -ne $Finding.where) {
        $a = [string](Get-GateProp -Object $Finding.where -Names @('artefact') -Default '')
        $l = [string](Get-GateProp -Object $Finding.where -Names @('locator') -Default '')
    }
    return (((($a + '|' + $l) -replace '\s+', ' ').Trim().TrimEnd('.', ';', ',')).ToLowerInvariant())
}

function Escape-MdCell {
    param([AllowEmptyString()][string] $Text)
    return (("$Text" -replace '\r?\n', ' ') -replace '\|', '\|')
}

# ---------------------------------------------------------------------------
# 1. The unit's KE and PE items, from the extract handed in
# ---------------------------------------------------------------------------

function Get-UnitItems {
    param([AllowEmptyString()][string] $Text)
    $items = New-Object System.Collections.Generic.List[object]
    $seen = @{}
    $lines = @($Text -split "`r?`n")
    for ($i = 0; $i -lt $lines.Count; $i++) {
        foreach ($m in [regex]::Matches($lines[$i], '\b(KE|PE)(\d+)([a-z])?\b')) {
            $id = $m.Groups[1].Value + $m.Groups[2].Value + $m.Groups[3].Value
            if ($seen.ContainsKey($id)) { continue }
            $seen[$id] = $true
            $parent = if ($m.Groups[3].Value) { $m.Groups[1].Value + $m.Groups[2].Value } else { $null }
            $text = (($lines[$i].Substring($m.Index + $m.Length)) -replace '\*\*', '').Trim().TrimStart('-', ':', ' ').Trim()
            if ($text.Length -gt 160) { $text = $text.Substring(0, 157) + '...' }
            $items.Add([pscustomobject]@{ Id = $id; Parent = $parent; Line = $i + 1; Text = $text })
        }
    }
    return $items.ToArray()
}

# ---------------------------------------------------------------------------
# 2. The reviewer set, and each reviewer's file against the contract
# ---------------------------------------------------------------------------

function Get-ReviewerSet {
    param([string] $ReviewDir, [string] $ExcludeDir)
    $set = New-Object System.Collections.Generic.List[object]
    $expected = @()
    $mf = Join-Path $ReviewDir 'manifest.json'
    if (Test-Path -LiteralPath $mf) {
        $m = Get-GateJson -Path $mf
        if ($null -ne $m -and @($m.PSObject.Properties.Name) -contains 'expectedReviewers') { $expected = @($m.expectedReviewers | ForEach-Object { "$_" }) }
    }
    foreach ($d in (Get-ChildItem -LiteralPath $ReviewDir -Directory | Sort-Object Name)) {
        if ($ExcludeDir -and ($d.FullName -eq $ExcludeDir)) { continue }
        $fp = Join-Path $d.FullName 'findings.json'
        $sp = Join-Path $d.FullName 'SCOPE.md'
        $hasF = Test-Path -LiteralPath $fp
        $hasS = Test-Path -LiteralPath $sp
        $isExpected = ($expected -contains $d.Name) -or $hasS
        if (-not $hasF -and -not $isExpected) { continue }
        $set.Add([pscustomobject]@{ Name = $d.Name; Dir = $d.FullName; FindingsPath = $fp; HasFindings = $hasF; Expected = $isExpected })
    }
    foreach ($e in $expected) {
        if (@($set | Where-Object { $_.Name -eq $e }).Count -eq 0) {
            $set.Add([pscustomobject]@{ Name = $e; Dir = (Join-Path $ReviewDir $e); FindingsPath = (Join-Path (Join-Path $ReviewDir $e) 'findings.json'); HasFindings = $false; Expected = $true })
        }
    }
    return $set.ToArray()
}

function Read-Verdict {
    param($Value, [string] $Reviewer, $Violations)
    $out = [ordered]@{ guide = -2; deck = -2; deliverySet = -2 }
    if ($null -eq $Value -or ($Value -is [string] -and -not "$Value".Trim())) { $Violations.Add(("{0}: verdict is missing" -f $Reviewer)); return $out }
    if ($Value -is [string]) {
        $r = ConvertTo-VerdictRank -Verdict $Value
        if ($r -lt 0) { $Violations.Add(("{0}: verdict '{1}' is not one of {2}" -f $Reviewer, $Value, ($script:VerdictNames -join ' | '))) }
        $out['guide'] = $r; $out['deck'] = $r; $out['deliverySet'] = $r
        return $out
    }
    $stated = 0
    foreach ($pair in @(@('guide', @('guide')), @('deck', @('deck')), @('deliverySet', @('deliverySet', 'delivery-set', 'delivery_set', 'deliveryset', 'pair', 'set')))) {
        $v = Get-GateProp -Object $Value -Names $pair[1] -Default $null
        if ($null -eq $v -or -not "$v".Trim()) { continue }
        $r = ConvertTo-VerdictRank -Verdict "$v"
        if ($r -lt 0) { $Violations.Add(("{0}: verdict.{1} '{2}' is not one of {3}" -f $Reviewer, $pair[0], $v, ($script:VerdictNames -join ' | '))) }
        $out[$pair[0]] = $r
        $stated++
    }
    if ($stated -eq 0) { $Violations.Add(("{0}: verdict names none of guide, deck, deliverySet" -f $Reviewer)) }
    return $out
}

function Read-ReviewerFile {
    param([Parameter(Mandatory)] $Slot, $Violations)
    $name = $Slot.Name
    $j = $null
    try { $j = Get-GateJson -Path $Slot.FindingsPath } catch { $Violations.Add(("{0}: findings.json did not parse - {1}" -f $name, $_.Exception.Message)); return $null }
    if ($null -eq $j) { $Violations.Add(("{0}: findings.json is empty" -f $name)); return $null }
    $keys = @($j.PSObject.Properties.Name)
    foreach ($req in @('reviewer', 'scope', 'verdict', 'findings', 'coverage', 'channels')) {
        if ($keys -notcontains $req) { $Violations.Add(("{0}: findings.json has no '{1}' key" -f $name, $req)) }
    }
    $reviewer = [string](Get-GateProp -Object $j -Names @('reviewer') -Default $name)
    $scope = [string](Get-GateProp -Object $j -Names @('scope') -Default '')
    $verdict = Read-Verdict -Value $(if ($keys -contains 'verdict') { $j.verdict } else { $null }) -Reviewer $name -Violations $Violations

    $findings = @()
    if ($keys -contains 'findings' -and $null -ne $j.findings) { $findings = @($j.findings) }
    $n = 0
    foreach ($f in $findings) {
        $n++
        if ($null -eq $f) { $Violations.Add(("{0}: finding #{1} is null" -f $name, $n)); continue }
        $fid = [string](Get-GateProp -Object $f -Names @('id') -Default '')
        $label = if ($fid) { $fid } else { ("#" + $n) }
        if (-not $fid) { $Violations.Add(("{0}: finding #{1} has no id" -f $name, $n)) }
        $risk = [string](Get-GateProp -Object $f -Names @('risk') -Default '')
        if ((Get-RiskRank -Risk $risk) -lt 0) { $Violations.Add(("{0}: finding {1}: risk '{2}' is not High, Medium or Low" -f $name, $label, $risk)) }
        $cls = [string](Get-GateProp -Object $f -Names @('class') -Default '')
        if ($script:FindingClasses -cnotcontains $cls) { $Violations.Add(("{0}: finding {1}: class '{2}' is not one of {3} - arbitration would skip it" -f $name, $label, $cls, ($script:FindingClasses -join '|'))) }
        $anchor = Get-FindingAnchor -Finding $f
        if ($anchor -eq '|' -or $anchor -match '^\|' -or $anchor -match '\|$') { $Violations.Add(("{0}: finding {1}: where.artefact and where.locator are both required - a finding you cannot anchor is not yet a finding" -f $name, $label)) }
        $claim = [string](Get-GateProp -Object $f -Names @('claim') -Default '')
        if (-not $claim.Trim()) { $Violations.Add(("{0}: finding {1}: claim is empty" -f $name, $label)) }
    }

    $coverage = @()
    if ($keys -contains 'coverage' -and $null -ne $j.coverage) { $coverage = @($j.coverage) }
    $cov = New-Object System.Collections.Generic.List[object]
    foreach ($c in $coverage) {
        if ($null -eq $c) { continue }
        $item = if ($c -is [string]) { $c } else { [string](Get-GateProp -Object $c -Names @('item') -Default '') }
        if (-not "$item".Trim()) { $Violations.Add(("{0}: a coverage entry names no item" -f $name)); continue }
        $anchors = @()
        if (-not ($c -is [string]) -and @($c.PSObject.Properties.Name) -contains 'anchors' -and $null -ne $c.anchors) { $anchors = @($c.anchors | ForEach-Object { "$_" }) }
        $cov.Add([pscustomobject]@{ Item = (ConvertTo-ItemId -Item $item); AsWritten = "$item"; Anchors = $anchors })
    }

    $channels = [ordered]@{}
    if ($keys -contains 'channels' -and $null -ne $j.channels -and -not ($j.channels -is [string])) {
        foreach ($p in $j.channels.PSObject.Properties) { $channels[$p.Name] = "$($p.Value)" }
    }

    return [pscustomobject]@{ Name = $name; Reviewer = $reviewer; Scope = $scope; Verdict = $verdict; Findings = $findings; Coverage = $cov.ToArray(); Channels = $channels; Path = $Slot.FindingsPath }
}

# ---------------------------------------------------------------------------
# 3. The merge
# ---------------------------------------------------------------------------

function Invoke-MergeFindings {
    param(
        [Parameter(Mandatory)][string] $ReviewDir,
        [Parameter(Mandatory)][string] $UnitExtractPath,
        [Parameter(Mandatory)][string] $OutPath,
        [Parameter(Mandatory)][string] $MarkdownPath,
        [switch] $Quiet
    )

    $result = [pscustomobject]@{ ExitCode = 0; Errors = (New-Object System.Collections.Generic.List[string]); Merged = $null; Reviewers = @(); Uncovered = @(); Findings = @() }
    $violations = New-Object System.Collections.Generic.List[string]

    if (-not (Test-Path -LiteralPath $ReviewDir)) { $result.Errors.Add("no review directory at $ReviewDir"); $result.ExitCode = 2; return $result }
    if (-not (Test-Path -LiteralPath $UnitExtractPath)) { $result.Errors.Add("no unit extract at $UnitExtractPath - coverage cannot be checked against a unit nobody supplied"); $result.ExitCode = 2; return $result }

    $outDir = Split-Path -Parent $OutPath
    $slots = @(Get-ReviewerSet -ReviewDir $ReviewDir -ExcludeDir $outDir)
    if ($slots.Count -eq 0) { $result.Errors.Add("no reviewer directory under $ReviewDir carries a findings.json or a SCOPE.md"); $result.ExitCode = 2; return $result }
    foreach ($s in $slots) {
        if (-not $s.HasFindings) { $violations.Add(("{0}: expected reviewer has NO findings.json at {1} - the reviewer died, or never wrote the contract. Re-run it; do not merge without it." -f $s.Name, $s.FindingsPath)) }
    }

    $reviewers = New-Object System.Collections.Generic.List[object]
    foreach ($s in ($slots | Where-Object { $_.HasFindings })) {
        $rv = Read-ReviewerFile -Slot $s -Violations $violations
        if ($null -ne $rv) { $reviewers.Add($rv) }
    }
    if ($violations.Count -gt 0) {
        foreach ($v in $violations) { $result.Errors.Add($v) }
        $result.ExitCode = 2
        return $result
    }

    # --- unit items
    $unitItems = @(Get-UnitItems -Text (Get-GateFileText -Path $UnitExtractPath))
    if ($unitItems.Count -eq 0) { $result.Errors.Add(("the unit extract at {0} carries no KE or PE identifiers (KE1, KE2a, PE1 ...). Coverage cannot be checked against nothing." -f $UnitExtractPath)); $result.ExitCode = 2; return $result }

    # --- coverage union
    $claims = @{}
    $unknownClaims = New-Object System.Collections.Generic.List[object]
    $unitIds = @($unitItems | ForEach-Object { $_.Id })
    foreach ($rv in $reviewers) {
        foreach ($c in $rv.Coverage) {
            if ($unitIds -cnotcontains $c.Item) { $unknownClaims.Add([pscustomobject]@{ Reviewer = $rv.Reviewer; Item = $c.AsWritten }); continue }
            if (-not $claims.ContainsKey($c.Item)) { $claims[$c.Item] = New-Object System.Collections.Generic.List[object] }
            $claims[$c.Item].Add([pscustomobject]@{ Reviewer = $rv.Reviewer; Anchors = $c.Anchors })
        }
    }
    $coverageRows = New-Object System.Collections.Generic.List[object]
    $uncovered = New-Object System.Collections.Generic.List[object]
    foreach ($u in $unitItems) {
        $direct = $claims.ContainsKey($u.Id)
        $children = @($unitItems | Where-Object { $_.Parent -eq $u.Id })
        $viaChildren = $false
        if (-not $direct -and $children.Count -gt 0) { $viaChildren = (@($children | Where-Object { -not $claims.ContainsKey($_.Id) }).Count -eq 0) }
        $via = if ($direct) { 'claim' } elseif ($viaChildren) { 'sub-items' } else { 'none' }
        $claimedBy = if ($direct) { @($claims[$u.Id] | ForEach-Object { [ordered]@{ reviewer = $_.Reviewer; anchors = @($_.Anchors) } }) } else { @() }
        $coverageRows.Add([ordered]@{ item = $u.Id; text = $u.Text; covered = ($direct -or $viaChildren); via = $via; claimedBy = $claimedBy })
        if (-not ($direct -or $viaChildren)) { $uncovered.Add($u) }
    }

    # --- findings: concat, dedupe on (class, anchor), keep the worst risk verbatim
    $byKey = [ordered]@{}
    foreach ($rv in ($reviewers | Sort-Object Name)) {
        foreach ($f in $rv.Findings) {
            $anchor = Get-FindingAnchor -Finding $f
            $cls = [string]$f.class
            $key = $cls + '||' + $anchor
            $entry = [ordered]@{
                mergedId = ("{0}/{1}" -f $rv.Reviewer, $f.id)
                reviewer = $rv.Reviewer
                id = $f.id
                risk = $f.risk
                class = $cls
                claim = $f.claim
                value = $(if (@($f.PSObject.Properties.Name) -contains 'value') { $f.value } else { $null })
                where = $f.where
                source = $(if (@($f.PSObject.Properties.Name) -contains 'source') { $f.source } else { $null })
                replacement = $(if (@($f.PSObject.Properties.Name) -contains 'replacement') { $f.replacement } else { $null })
                proposedForbid = $(if (@($f.PSObject.Properties.Name) -contains 'proposedForbid' -and $null -ne $f.proposedForbid) { @($f.proposedForbid) } else { @() })
                duplicates = @()
            }
            if ($byKey.Contains($key)) {
                $kept = $byKey[$key]
                #  The copy that is not kept still travels, verbatim, on the copy that is.
                #  Dedupe collapses the COUNT; it never drops a reviewer's own words.
                if ((Get-RiskRank -Risk $entry['risk']) -gt (Get-RiskRank -Risk $kept['risk'])) {
                    $entry['duplicates'] = @(@($kept['duplicates']) + @([ordered]@{ reviewer = $kept['reviewer']; id = $kept['id']; risk = $kept['risk']; claim = $kept['claim']; value = $kept['value']; replacement = $kept['replacement'] }))
                    $byKey[$key] = $entry
                }
                else {
                    $kept['duplicates'] = @(@($kept['duplicates']) + @([ordered]@{ reviewer = $entry['reviewer']; id = $entry['id']; risk = $entry['risk']; claim = $entry['claim']; value = $entry['value']; replacement = $entry['replacement'] }))
                }
            }
            else { $byKey[$key] = $entry }
        }
    }
    $merged = New-Object System.Collections.Generic.List[object]
    foreach ($k in $byKey.Keys) { $merged.Add($byKey[$k]) }
    $dupCount = 0
    foreach ($m in $merged) { $dupCount += @($m['duplicates']).Count }

    # --- the merger's own findings: an item nobody claims
    $unitLeaf = Split-Path $UnitExtractPath -Leaf
    foreach ($u in $uncovered) {
        $merged.Add([ordered]@{
            mergedId = ("merger/MERGE-COV-{0}" -f $u.Id)
            reviewer = 'merger'
            id = ("MERGE-COV-{0}" -f $u.Id)
            risk = 'High'
            class = 'not-taught'
            claim = ("No reviewer claims to teach {0}: {1}" -f $u.Id, $u.Text)
            value = $u.Id
            where = [ordered]@{ artefact = 'guide'; locator = ("(no anchor: no reviewer's coverage[] names {0})" -f $u.Id) }
            source = [ordered]@{ doc = $unitLeaf; locator = ("line {0}" -f $u.Line) }
            replacement = ''
            proposedForbid = @()
            duplicates = @()
        })
    }

    # --- verdicts: the worst per artefact, then the High floor
    $derivation = New-Object System.Collections.Generic.List[string]
    $ranks = [ordered]@{ guide = -2; deck = -2; deliverySet = -2 }
    foreach ($art in @('guide', 'deck', 'deliverySet')) {
        $parts = New-Object System.Collections.Generic.List[string]
        foreach ($rv in $reviewers) {
            $r = [int]$rv.Verdict[$art]
            if ($r -lt 0) { continue }
            $parts.Add(("{0}={1}" -f $rv.Reviewer, (Get-VerdictName -Rank $r)))
            if ($r -gt $ranks[$art]) { $ranks[$art] = $r }
        }
        $derivation.Add(("{0}: worst of [{1}] = {2}" -f $art, ($parts -join ', '), (Get-VerdictName -Rank $ranks[$art])))
    }
    if ($ranks['guide'] -gt $ranks['deliverySet']) { $ranks['deliverySet'] = $ranks['guide']; $derivation.Add('deliverySet: raised to the guide verdict, because the set cannot be better than one of its artefacts') }
    if ($ranks['deck'] -gt $ranks['deliverySet']) { $ranks['deliverySet'] = $ranks['deck']; $derivation.Add('deliverySet: raised to the deck verdict, because the set cannot be better than one of its artefacts') }

    $highGuide = 0; $highDeck = 0; $highAll = 0
    foreach ($m in $merged) {
        if ((Get-RiskRank -Risk $m['risk']) -lt 2) { continue }
        $highAll++
        $art = ''
        if ($null -ne $m['where']) { $art = ([string](Get-GateProp -Object $m['where'] -Names @('artefact') -Default '')).ToLowerInvariant() }
        if ($art -eq 'guide') { $highGuide++ } elseif ($art -eq 'deck') { $highDeck++ }
    }
    if ($highGuide -gt 0 -and $ranks['guide'] -ge 0 -and $ranks['guide'] -lt 1) { $ranks['guide'] = 1; $derivation.Add(("guide: floored to Partially Compliant - {0} High finding(s) remain against it, and the decision rule reserves Fully Compliant for no High defect" -f $highGuide)) }
    if ($highDeck -gt 0 -and $ranks['deck'] -ge 0 -and $ranks['deck'] -lt 1) { $ranks['deck'] = 1; $derivation.Add(("deck: floored to Partially Compliant - {0} High finding(s) remain against it" -f $highDeck)) }
    if ($highAll -gt 0 -and $ranks['deliverySet'] -ge 0 -and $ranks['deliverySet'] -lt 1) { $ranks['deliverySet'] = 1; $derivation.Add(("deliverySet: floored to Partially Compliant - {0} High finding(s) remain" -f $highAll)) }
    if ($ranks['guide'] -gt $ranks['deliverySet']) { $ranks['deliverySet'] = $ranks['guide'] }
    if ($ranks['deck'] -gt $ranks['deliverySet']) { $ranks['deliverySet'] = $ranks['deck'] }

    # --- channels: union, disagreements kept, not resolved
    $channels = [ordered]@{}
    foreach ($rv in $reviewers) {
        foreach ($k in $rv.Channels.Keys) {
            if (-not $channels.Contains($k)) { $channels[$k] = @() }
            $channels[$k] = @(@($channels[$k]) + @([ordered]@{ reviewer = $rv.Reviewer; disposition = $rv.Channels[$k] }))
        }
    }

    # --- per-reviewer table
    $table = New-Object System.Collections.Generic.List[object]
    foreach ($rv in $reviewers) {
        $h = 0; $md = 0; $lo = 0
        foreach ($f in $rv.Findings) { $rr = Get-RiskRank -Risk ([string]$f.risk); if ($rr -ge 2) { $h++ } elseif ($rr -eq 1) { $md++ } else { $lo++ } }
        $table.Add([ordered]@{
            reviewer = $rv.Reviewer; scope = $rv.Scope; file = $rv.Path
            verdict = [ordered]@{ guide = (Get-VerdictName -Rank $rv.Verdict['guide']); deck = (Get-VerdictName -Rank $rv.Verdict['deck']); deliverySet = (Get-VerdictName -Rank $rv.Verdict['deliverySet']) }
            findings = [ordered]@{ high = $h; medium = $md; low = $lo; total = @($rv.Findings).Count }
            coverageItems = @($rv.Coverage).Count
            channels = @($rv.Channels.Keys).Count
        })
    }

    $out = [ordered]@{
        reviewer = 'merger'
        scope = ("merged: {0}" -f (($reviewers | ForEach-Object { $_.Reviewer }) -join ', '))
        generated = (Get-Date).ToUniversalTime().ToString('o')
        reviewDir = $ReviewDir
        unitExtract = $UnitExtractPath
        rule = 'union coverage against the unit extract and raise not-taught for any unclaimed item; concatenate; dedupe on (class, anchor) keeping the worst risk verbatim; worst verdict per artefact; Fully floored to Partially where a High finding remains. No finding text was altered.'
        verdict = [ordered]@{ guide = (Get-VerdictName -Rank $ranks['guide']); deck = (Get-VerdictName -Rank $ranks['deck']); deliverySet = (Get-VerdictName -Rank $ranks['deliverySet']); derivation = $derivation.ToArray() }
        reviewers = $table.ToArray()
        findings = $merged.ToArray()
        coverage = $coverageRows.ToArray()
        uncovered = @($uncovered | ForEach-Object { $_.Id })
        claimsAgainstUnknownItems = @($unknownClaims | ForEach-Object { [ordered]@{ reviewer = $_.Reviewer; item = $_.Item } })
        channels = $channels
        counts = [ordered]@{ reviewers = $reviewers.Count; findingsIn = (($reviewers | ForEach-Object { @($_.Findings).Count } | Measure-Object -Sum).Sum); duplicatesCollapsed = $dupCount; raisedByMerger = $uncovered.Count; findingsOut = $merged.Count; high = $highAll }
    }

    Write-Utf8File -Path $OutPath -Content (($out | ConvertTo-Json -Depth 20) + "`r`n")
    Write-Utf8File -Path $MarkdownPath -Content (New-MergedMarkdown -Out $out -UnitItems $unitItems)

    $result.Merged = $out
    $result.Reviewers = $table.ToArray()
    $result.Uncovered = @($uncovered | ForEach-Object { $_.Id })
    $result.Findings = $merged.ToArray()
    $result.ExitCode = $(if ($highAll -gt 0) { 1 } else { 0 })

    if (-not $Quiet) {
        Write-Host ''
        Write-Host "$GATE" -ForegroundColor Cyan
        Write-GateCheckSet -What 'reviewer file(s)' -Count $reviewers.Count -DerivedFrom ("directories under {0} carrying SCOPE.md or findings.json{1}" -f $ReviewDir, $(if (Test-Path -LiteralPath (Join-Path $ReviewDir 'manifest.json')) { ', and manifest.json expectedReviewers' } else { '' }))
        Write-GateCheckSet -What 'KE/PE item(s)' -Count $unitItems.Count -DerivedFrom ("the identifiers in {0}" -f $unitLeaf)
        foreach ($t in $table) {
            Write-Host ("  {0,-10} guide={1,-20} deck={2,-20} set={3,-20} H{4} M{5} L{6}  coverage {7}" -f $t.reviewer, $t.verdict.guide, $t.verdict.deck, $t.verdict.deliverySet, $t.findings.high, $t.findings.medium, $t.findings.low, $t.coverageItems) -ForegroundColor DarkGray
        }
        Write-Host ("  findings in {0}, duplicates collapsed {1}, raised by the merger {2}, out {3}" -f $out.counts.findingsIn, $dupCount, $uncovered.Count, $merged.Count) -ForegroundColor DarkGray
        foreach ($u in $uncovered) { Write-Host ("  X {0} is claimed by NO reviewer: {1}" -f $u.Id, $u.Text) -ForegroundColor Red }
        foreach ($d in $derivation) { Write-Host ("  {0}" -f $d) -ForegroundColor DarkGray }
        $col = if ($ranks['deliverySet'] -eq 0) { 'Green' } elseif ($ranks['deliverySet'] -eq 1) { 'Yellow' } else { 'Red' }
        Write-Host ("  VERDICT guide={0}  deck={1}  delivery set={2}" -f $out.verdict.guide, $out.verdict.deck, $out.verdict.deliverySet) -ForegroundColor $col
        Write-Host ("  written: {0}" -f $OutPath) -ForegroundColor DarkGray
        Write-Host ("  written: {0}" -f $MarkdownPath) -ForegroundColor DarkGray
    }
    return $result
}

function New-MergedMarkdown {
    param($Out, $UnitItems)
    $o = New-Object System.Collections.Generic.List[string]
    $o.Add('# Merged clean-room audit')
    $o.Add('')
    $o.Add(("Generated {0} by Merge-AuditFindings.ps1 from {1}." -f $Out.generated, $Out.reviewDir))
    $o.Add('')
    $o.Add('**This file was produced by a script that did not read, summarise or reword any finding.** Every finding below is verbatim from the reviewer named on it. The merger unioned coverage against the unit extract, raised a finding for every item no reviewer claims, collapsed exact duplicates on (class, anchor) keeping the worst risk, took the worst verdict per artefact, and floored Fully Compliant to Partially Compliant where a High finding remains. Nothing else.')
    $o.Add('')
    $o.Add('## Verdict')
    $o.Add('')
    $o.Add('| Artefact | Verdict |')
    $o.Add('|---|---|')
    $o.Add(("| Guide | {0} |" -f $Out.verdict.guide))
    $o.Add(("| Deck | {0} |" -f $Out.verdict.deck))
    $o.Add(("| Delivery set | **{0}** |" -f $Out.verdict.deliverySet))
    $o.Add('')
    foreach ($d in $Out.verdict.derivation) { $o.Add(("- {0}" -f $d)) }
    $o.Add('')
    $o.Add('## Reviewers')
    $o.Add('')
    $o.Add('| Reviewer | Scope | Guide | Deck | Delivery set | High | Medium | Low | Coverage claims | Channels | File |')
    $o.Add('|---|---|---|---|---|---|---|---|---|---|---|')
    foreach ($t in $Out.reviewers) {
        $o.Add(("| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} | {10} |" -f $t.reviewer, (Escape-MdCell $t.scope), $t.verdict.guide, $t.verdict.deck, $t.verdict.deliverySet, $t.findings.high, $t.findings.medium, $t.findings.low, $t.coverageItems, $t.channels, (Escape-MdCell $t.file)))
    }
    $o.Add('')
    $o.Add(("Findings in: {0}. Duplicates collapsed: {1}. Raised by the merger: {2}. Findings out: {3}. High remaining: {4}." -f $Out.counts.findingsIn, $Out.counts.duplicatesCollapsed, $Out.counts.raisedByMerger, $Out.counts.findingsOut, $Out.counts.high))
    $o.Add('')
    $o.Add('## Items no reviewer claims to teach')
    $o.Add('')
    if (@($Out.uncovered).Count -eq 0) { $o.Add('None. Every KE and PE item in the unit extract is claimed by at least one reviewer, directly or through all of its sub-items.') }
    else {
        $o.Add('Each of these is raised below as a High finding of class not-taught. A topic reviewer holding one topic cannot see an item that fell between topics; that is why the merger raises it.')
        $o.Add('')
        foreach ($u in $Out.uncovered) { $row = $Out.coverage | Where-Object { $_.item -eq $u } | Select-Object -First 1; $o.Add(("- **{0}** - {1}" -f $u, (Escape-MdCell $row.text))) }
    }
    if (@($Out.claimsAgainstUnknownItems).Count -gt 0) {
        $o.Add('')
        $o.Add('Claims against identifiers the unit extract does not carry (not counted as coverage; a reviewer naming an item that does not exist is itself worth a look):')
        foreach ($c in $Out.claimsAgainstUnknownItems) { $o.Add(('- {0} claimed `{1}`' -f $c.reviewer, (Escape-MdCell $c.item))) }
    }
    $o.Add('')
    $o.Add('## Findings')
    $o.Add('')
    $o.Add('| Merged id | Risk | Class | Artefact | Locator | Claim | Value | Duplicates |')
    $o.Add('|---|---|---|---|---|---|---|---|')
    foreach ($f in $Out.findings) {
        $art = ''; $loc = ''
        if ($null -ne $f.where) { $art = [string](Get-GateProp -Object $f.where -Names @('artefact') -Default ''); $loc = [string](Get-GateProp -Object $f.where -Names @('locator') -Default '') }
        $dups = @($f.duplicates | ForEach-Object { ("{0}/{1} ({2})" -f $_.reviewer, $_.id, $_.risk) }) -join ', '
        $o.Add(("| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} |" -f $f.mergedId, $f.risk, $f.class, (Escape-MdCell $art), (Escape-MdCell $loc), (Escape-MdCell ([string]$f.claim)), (Escape-MdCell ([string]$f.value)), (Escape-MdCell $dups)))
    }
    $o.Add('')
    $o.Add('### Every finding in full, verbatim')
    $o.Add('')
    foreach ($f in $Out.findings) {
        $o.Add(("#### {0} - {1} - {2}" -f $f.mergedId, $f.risk, $f.class))
        $o.Add('')
        $o.Add(("- Reviewer: {0}" -f $f.reviewer))
        if ($null -ne $f.where) { $o.Add(("- Where: {0} - {1}" -f [string](Get-GateProp -Object $f.where -Names @('artefact') -Default ''), [string](Get-GateProp -Object $f.where -Names @('locator') -Default ''))) }
        if ($null -ne $f.source) { $o.Add(("- Source: {0} - {1}" -f [string](Get-GateProp -Object $f.source -Names @('doc') -Default ''), [string](Get-GateProp -Object $f.source -Names @('locator') -Default ''))) }
        else { $o.Add('- Source: (none resolved)') }
        $o.Add(("- Value: {0}" -f [string]$f.value))
        if (@($f.proposedForbid).Count -gt 0) { $o.Add(("- Proposed forbid: {0}" -f (@($f.proposedForbid) -join ' | '))) }
        $o.Add('')
        $o.Add('Claim:')
        $o.Add('')
        $o.Add([string]$f.claim)
        $o.Add('')
        if ("$($f.replacement)".Trim()) { $o.Add('Replacement:'); $o.Add(''); $o.Add([string]$f.replacement); $o.Add('') }
        foreach ($d in @($f.duplicates)) {
            $o.Add(("Also reported by {0}/{1} ({2}) at the same anchor and class; their claim, verbatim:" -f $d.reviewer, $d.id, $d.risk))
            $o.Add('')
            $o.Add([string]$d.claim)
            $o.Add('')
            if ("$($d.replacement)".Trim()) { $o.Add('Their replacement:'); $o.Add(''); $o.Add([string]$d.replacement); $o.Add('') }
        }
    }
    $o.Add('## Coverage matrix')
    $o.Add('')
    $o.Add('| Item | Covered | Via | Claimed by | Anchors |')
    $o.Add('|---|---|---|---|---|')
    foreach ($c in $Out.coverage) {
        $by = @($c.claimedBy | ForEach-Object { $_.reviewer }) -join ', '
        $an = @($c.claimedBy | ForEach-Object { @($_.anchors) -join '; ' }) -join ' / '
        $o.Add(("| {0} | {1} | {2} | {3} | {4} |" -f $c.item, $(if ($c.covered) { 'yes' } else { '**NO**' }), $c.via, (Escape-MdCell $by), (Escape-MdCell $an)))
    }
    $o.Add('')
    $o.Add('## Channels')
    $o.Add('')
    if (@($Out.channels.PSObject.Properties).Count -eq 0 -and @($Out.channels.Keys).Count -eq 0) { $o.Add('No reviewer dispositioned any channel.') }
    else {
        $o.Add('| Channel | Dispositions |')
        $o.Add('|---|---|')
        $keys = if ($Out.channels -is [System.Collections.IDictionary]) { @($Out.channels.Keys) } else { @($Out.channels.PSObject.Properties.Name) }
        foreach ($k in $keys) {
            $entries = @($Out.channels[$k] | ForEach-Object { ("{0}: {1}" -f $_.reviewer, $_.disposition) })
            $distinct = @($Out.channels[$k] | ForEach-Object { "$($_.disposition)".Trim().ToLowerInvariant() } | Sort-Object -Unique)
            $flag = if ($distinct.Count -gt 1) { ' **(reviewers disagree)**' } else { '' }
            $o.Add(("| {0} | {1}{2} |" -f (Escape-MdCell $k), (Escape-MdCell ($entries -join '; ')), $flag))
        }
    }
    $o.Add('')
    return (($o -join "`r`n") + "`r`n")
}

# ---------------------------------------------------------------------------
# 4. Self-test
# ---------------------------------------------------------------------------

function Invoke-MergeSelfTest {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("mergefindings-selftest-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $rd = Join-Path $root 'review'
    New-Item -ItemType Directory -Path (Join-Path $rd 'topic1') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $rd 'topic2') -Force | Out-Null
    $fails = New-Object System.Collections.Generic.List[string]
    function Assert-True { param([bool] $Cond, [string] $What) if ($Cond) { Write-Host ("  PASS  {0}" -f $What) -ForegroundColor Green } else { Write-Host ("  FAIL  {0}" -f $What) -ForegroundColor Red; $fails.Add($What) } }

    try {
        $unit = Join-Path $root 'unit_extract.md'
        Write-Utf8File -Path $unit -Content (@('# unit', '## Knowledge evidence', '- **KE1** culinary terms', '- **KE2** uses of food types:', '  - KE2a bulk foods', '  - KE2b plated meals', '- **KE3** contents of date codes', '## Performance evidence', '- **PE1** produce ten portions:', '  - PE1a entire meals') -join "`r`n")

        $oddClaim = 'Figure 1.2.2 says "17.5 L" | the card says 15.5 L - see ' + [char]0x2014 + ' Standard 3.2.2'
        $t1 = [ordered]@{
            reviewer = 'topic1'; scope = 'Topic 1 - Alpha'; verdict = 'Partially Compliant'
            findings = @(
                [ordered]@{ id = 'H-1'; risk = 'Medium'; class = 'wrong-value'; claim = $oddClaim; value = '17.5 L'; where = [ordered]@{ artefact = 'guide'; locator = 'Topic 1, 1.2, Figure 1.2.2' }; source = [ordered]@{ doc = 'Workbook.txt'; locator = 'recipe 2094' }; replacement = 'Use 15.5 L.'; proposedForbid = @() },
                [ordered]@{ id = 'L-1'; risk = 'Low'; class = 'other'; claim = 'An undefined abbreviation.'; value = 'CCP'; where = [ordered]@{ artefact = 'guide'; locator = 'Topic 1, 1.1' }; source = $null; replacement = 'critical control point (CCP)'; proposedForbid = @() }
            )
            coverage = @([ordered]@{ item = 'KE1'; anchors = @('1.1 Underpinning knowledge') }, [ordered]@{ item = 'ke2a'; anchors = @('1.1 uses table') }, [ordered]@{ item = 'KE2b'; anchors = @('1.1 uses table') }, [ordered]@{ item = 'PE1a'; anchors = @('Topic 1 overview') })
            channels = [ordered]@{ 'guide body' = 'final'; 'guide alt text' = 'final' }
        }
        $t2 = [ordered]@{
            reviewer = 'topic2'; scope = 'Topic 2 - Beta'; verdict = [ordered]@{ guide = 'Fully Compliant'; deck = 'Not Compliant'; deliverySet = 'Not Compliant' }
            findings = @(
                [ordered]@{ id = 'H-1'; risk = 'High'; class = 'wrong-value'; claim = 'Figure 1.2.2 states 17.5 L where the card states 15.5 L.'; value = '17.5 L'; where = [ordered]@{ artefact = 'Guide'; locator = 'Topic 1, 1.2, Figure 1.2.2.' }; source = [ordered]@{ doc = 'Workbook.txt'; locator = 'recipe 2094' }; replacement = 'Use 15.5 L.'; proposedForbid = @() },
                [ordered]@{ id = 'H-2'; risk = 'High'; class = 'leak'; claim = 'Slide 40 fills the assessed column.'; value = 'Workbook Task 2(a)'; where = [ordered]@{ artefact = 'deck'; locator = 'slide 40' }; source = [ordered]@{ doc = 'Workbook.txt'; locator = 'Task 2(a)' }; replacement = 'Withhold the column.'; proposedForbid = @() }
            )
            coverage = @([ordered]@{ item = 'KE1'; anchors = @('2.1') }, [ordered]@{ item = 'PE1a'; anchors = @() }, [ordered]@{ item = 'KE99'; anchors = @('nowhere') })
            channels = [ordered]@{ 'guide body' = 'placeholder'; 'deck notes' = 'placeholder' }
        }
        Write-Utf8File -Path (Join-Path $rd 'topic1\findings.json') -Content (($t1 | ConvertTo-Json -Depth 10) + "`r`n")
        Write-Utf8File -Path (Join-Path $rd 'topic2\findings.json') -Content (($t2 | ConvertTo-Json -Depth 10) + "`r`n")

        Write-Host ''
        Write-Host "$GATE self-test - two synthetic reviewers at $root" -ForegroundColor Cyan
        $op = Join-Path $rd 'merged\findings.json'
        $mp = Join-Path $rd 'merged\merged_audit.md'
        $r = Invoke-MergeFindings -ReviewDir $rd -UnitExtractPath $unit -OutPath $op -MarkdownPath $mp -Quiet
        Assert-True ($r.ExitCode -eq 1) ("merge succeeds and exits 1 because High findings remain (exit {0}; {1})" -f $r.ExitCode, ($r.Errors -join ' | '))
        $j = Get-GateJson -Path $op
        Assert-True (@($j.uncovered) -contains 'KE3') 'the KE item no reviewer claims (KE3) is raised as uncovered'
        Assert-True (@($j.findings | Where-Object { $_.id -eq 'MERGE-COV-KE3' -and $_.risk -eq 'High' -and $_.class -eq 'not-taught' -and $_.reviewer -eq 'merger' }).Count -eq 1) 'and becomes one High not-taught finding from the merger'
        Assert-True (-not (@($j.uncovered) -contains 'KE2')) 'a parent whose sub-items are all claimed is covered via its sub-items'
        Assert-True (-not (@($j.uncovered) -contains 'PE1')) 'PE parent covered via PE1a'
        Assert-True (@($j.coverage | Where-Object { $_.item -eq 'KE2a' -and $_.covered }).Count -eq 1) 'a lower-case claim "ke2a" is normalised to KE2a'
        Assert-True (@($j.claimsAgainstUnknownItems | Where-Object { $_.item -eq 'KE99' }).Count -eq 1) 'a claim against an item the unit does not carry is listed, not counted'
        $wv = @($j.findings | Where-Object { $_.class -eq 'wrong-value' })
        Assert-True ($wv.Count -eq 1) ("the same (anchor, class) from two reviewers collapses to one finding ({0})" -f $wv.Count)
        Assert-True ($wv.Count -eq 1 -and $wv[0].risk -eq 'High' -and $wv[0].reviewer -eq 'topic2' -and @($wv[0].duplicates).Count -eq 1 -and $wv[0].duplicates[0].reviewer -eq 'topic1') 'the copy with the worse risk is kept and the other is listed on it'
        Assert-True ($j.counts.duplicatesCollapsed -eq 1 -and $j.counts.findingsIn -eq 4 -and $j.counts.findingsOut -eq 4) ("counts: in {0}, collapsed {1}, raised {2}, out {3}" -f $j.counts.findingsIn, $j.counts.duplicatesCollapsed, $j.counts.raisedByMerger, $j.counts.findingsOut)
        Assert-True ($j.verdict.guide -eq 'Partially Compliant' -and $j.verdict.deck -eq 'Not Compliant' -and $j.verdict.deliverySet -eq 'Not Compliant') ("the worst verdict wins per artefact (guide={0}, deck={1}, set={2})" -f $j.verdict.guide, $j.verdict.deck, $j.verdict.deliverySet)
        $kept = @($j.findings | Where-Object { $_.id -eq 'L-1' })[0]
        Assert-True ($kept.claim -ceq 'An undefined abbreviation.' -and $kept.replacement -ceq 'critical control point (CCP)') 'a finding''s claim and replacement round-trip byte-for-byte'
        $raw = Get-GateFileText -Path $op
        Assert-True ($raw.Contains('An undefined abbreviation.')) 'the merged JSON carries the text verbatim'
        $t1dup = @($j.findings | Where-Object { $_.mergedId -eq 'topic2/H-1' })[0]
        Assert-True ($t1dup.claim -ceq 'Figure 1.2.2 states 17.5 L where the card states 15.5 L.') 'the kept duplicate''s claim is untouched'
        $md = Get-GateFileText -Path $mp
        Assert-True ($md.Contains('| topic1 |') -and $md.Contains('| topic2 |') -and $md.Contains('**NO**')) 'merged_audit.md carries the per-reviewer table and marks the uncovered item'
        Assert-True ($md.Contains('reviewers disagree')) 'a channel two reviewers disposition differently is flagged, not resolved'
        Assert-True ($wv.Count -eq 1 -and $wv[0].duplicates[0].claim -ceq $oddClaim -and $wv[0].duplicates[0].replacement -ceq 'Use 15.5 L.') 'the dropped duplicate''s own claim and replacement travel verbatim on the kept finding'
        Assert-True ($md.Contains($oddClaim)) 'a claim with a pipe, quotes and a non-ASCII dash reaches the markdown verbatim in its full listing'

        # plant 1: a High-free merge is exit 0 and Fully stays Fully
        $t3 = [ordered]@{ reviewer = 'topic1'; scope = 'x'; verdict = 'Fully Compliant'; findings = @(); coverage = @('KE1', 'KE2a', 'KE2b', 'KE3', 'PE1a'); channels = [ordered]@{} }
        $rd2 = Join-Path $root 'review2'; New-Item -ItemType Directory -Path (Join-Path $rd2 'topic1') -Force | Out-Null
        Write-Utf8File -Path (Join-Path $rd2 'topic1\findings.json') -Content (($t3 | ConvertTo-Json -Depth 10) + "`r`n")
        $r2 = Invoke-MergeFindings -ReviewDir $rd2 -UnitExtractPath $unit -OutPath (Join-Path $rd2 'merged\findings.json') -MarkdownPath (Join-Path $rd2 'merged\merged_audit.md') -Quiet
        $j2 = Get-GateJson -Path (Join-Path $rd2 'merged\findings.json')
        Assert-True ($r2.ExitCode -eq 0 -and $j2.verdict.deliverySet -eq 'Fully Compliant' -and @($j2.uncovered).Count -eq 0) 'full coverage with no findings merges clean, exit 0, Fully Compliant stands (bare-string coverage accepted)'

        # plant 2: Fully Compliant with a High finding is floored
        $t4 = [ordered]@{ reviewer = 'topic1'; scope = 'x'; verdict = 'Fully Compliant'; findings = @([ordered]@{ id = 'H-1'; risk = 'High'; class = 'fabricated'; claim = 'c'; value = '9'; where = [ordered]@{ artefact = 'guide'; locator = '1.1' }; source = $null; replacement = ''; proposedForbid = @() }); coverage = @('KE1', 'KE2a', 'KE2b', 'KE3', 'PE1a'); channels = [ordered]@{} }
        Write-Utf8File -Path (Join-Path $rd2 'topic1\findings.json') -Content (($t4 | ConvertTo-Json -Depth 10) + "`r`n")
        $r3 = Invoke-MergeFindings -ReviewDir $rd2 -UnitExtractPath $unit -OutPath (Join-Path $rd2 'merged\findings.json') -MarkdownPath (Join-Path $rd2 'merged\merged_audit.md') -Quiet
        $j3 = Get-GateJson -Path (Join-Path $rd2 'merged\findings.json')
        Assert-True ($r3.ExitCode -eq 1 -and $j3.verdict.guide -eq 'Partially Compliant' -and $j3.verdict.deliverySet -eq 'Partially Compliant') 'a Fully Compliant verdict with a High finding against it is floored to Partially Compliant, by the decision rule'

        # plant 3: an unknown class is refused, naming the reviewer and the finding
        $t5 = [ordered]@{ reviewer = 'topic1'; scope = 'x'; verdict = 'Fully Compliant'; findings = @([ordered]@{ id = 'H-9'; risk = 'High'; class = 'fabrication'; claim = 'c'; value = '9'; where = [ordered]@{ artefact = 'guide'; locator = '1.1' }; source = $null; replacement = ''; proposedForbid = @() }); coverage = @(); channels = [ordered]@{} }
        Write-Utf8File -Path (Join-Path $rd2 'topic1\findings.json') -Content (($t5 | ConvertTo-Json -Depth 10) + "`r`n")
        $r4 = Invoke-MergeFindings -ReviewDir $rd2 -UnitExtractPath $unit -OutPath (Join-Path $rd2 'merged\findings.json') -MarkdownPath (Join-Path $rd2 'merged\merged_audit.md') -Quiet
        Assert-True ($r4.ExitCode -eq 2 -and @($r4.Errors | Where-Object { $_ -match "topic1: finding H-9: class 'fabrication'" }).Count -eq 1) 'an unknown class is REFUSED, naming the reviewer and the finding'

        # plant 4: an expected reviewer with no findings.json is refused
        New-Item -ItemType Directory -Path (Join-Path $rd 'topic3') -Force | Out-Null
        Write-Utf8File -Path (Join-Path $rd 'topic3\SCOPE.md') -Content '# SCOPE - Topic 3'
        $r5 = Invoke-MergeFindings -ReviewDir $rd -UnitExtractPath $unit -OutPath $op -MarkdownPath $mp -Quiet
        Assert-True ($r5.ExitCode -eq 2 -and @($r5.Errors | Where-Object { $_ -match 'topic3: expected reviewer has NO findings.json' }).Count -eq 1) 'a pack directory with SCOPE.md and no findings.json is REFUSED - seven of eight is not a merge'

        # plant 5: an unanchored finding is refused
        Remove-Item -LiteralPath (Join-Path $rd 'topic3') -Recurse -Force
        $t6 = [ordered]@{ reviewer = 'topic1'; scope = 'x'; verdict = 'Fully Compliant'; findings = @([ordered]@{ id = 'M-1'; risk = 'Medium'; class = 'other'; claim = 'c'; value = ''; where = [ordered]@{ artefact = 'guide'; locator = '' }; source = $null; replacement = ''; proposedForbid = @() }); coverage = @(); channels = [ordered]@{} }
        Write-Utf8File -Path (Join-Path $rd2 'topic1\findings.json') -Content (($t6 | ConvertTo-Json -Depth 10) + "`r`n")
        $r6 = Invoke-MergeFindings -ReviewDir $rd2 -UnitExtractPath $unit -OutPath (Join-Path $rd2 'merged\findings.json') -MarkdownPath (Join-Path $rd2 'merged\merged_audit.md') -Quiet
        Assert-True ($r6.ExitCode -eq 2 -and @($r6.Errors | Where-Object { $_ -match 'M-1: where.artefact and where.locator are both required' }).Count -eq 1) 'a finding with no locator is REFUSED - it cannot be deduped, arbitrated or remediated'

        # plant 6: the expected set resolves from manifest.json when crossdoc is two packs
        $rd3 = Join-Path $root 'review3'
        foreach ($nm in @('topic1', 'crossdoc-values', 'crossdoc-refs')) { New-Item -ItemType Directory -Path (Join-Path $rd3 $nm) -Force | Out-Null }
        $tAll = [ordered]@{ reviewer = 'topic1'; scope = 'x'; verdict = 'Fully Compliant'; findings = @(); coverage = @('KE1', 'KE2a', 'KE2b', 'KE3', 'PE1a'); channels = [ordered]@{} }
        $cv = [ordered]@{ reviewer = 'crossdoc-values'; scope = 'cross-document agreement - values'; verdict = 'Fully Compliant'; findings = @(); coverage = @(); channels = [ordered]@{} }
        $cf = [ordered]@{ reviewer = 'crossdoc-refs'; scope = 'cross-document agreement - references'; verdict = 'Partially Compliant'; findings = @([ordered]@{ id = 'M-1'; risk = 'Medium'; class = 'wrong-clause'; claim = 'clause 6 in T1, clause 7 in T5'; value = 'clause 6'; where = [ordered]@{ artefact = 'guide'; locator = '1.3 and 5.4' }; source = $null; replacement = 'clause 7'; proposedForbid = @() }); coverage = @(); channels = [ordered]@{} }
        Write-Utf8File -Path (Join-Path $rd3 'topic1\findings.json') -Content (($tAll | ConvertTo-Json -Depth 10) + "`r`n")
        Write-Utf8File -Path (Join-Path $rd3 'crossdoc-values\findings.json') -Content (($cv | ConvertTo-Json -Depth 10) + "`r`n")
        Write-Utf8File -Path (Join-Path $rd3 'crossdoc-refs\findings.json') -Content (($cf | ConvertTo-Json -Depth 10) + "`r`n")
        Write-Utf8File -Path (Join-Path $rd3 'manifest.json') -Content (([ordered]@{ expectedReviewers = @('topic1', 'crossdoc-values', 'crossdoc-refs') } | ConvertTo-Json -Depth 4) + "`r`n")
        $r7 = Invoke-MergeFindings -ReviewDir $rd3 -UnitExtractPath $unit -OutPath (Join-Path $rd3 'merged\findings.json') -MarkdownPath (Join-Path $rd3 'merged\merged_audit.md') -Quiet
        $j7 = Get-GateJson -Path (Join-Path $rd3 'merged\findings.json')
        Assert-True ($r7.ExitCode -eq 0 -and @($j7.reviewers).Count -eq 3 -and $j7.verdict.deliverySet -eq 'Partially Compliant' -and ((Get-GateFileText -Path (Join-Path $rd3 'merged\merged_audit.md')).Contains('| crossdoc-refs |'))) 'three reviewers named by manifest.json (topic1, crossdoc-values, crossdoc-refs) merge, and the worst crossdoc verdict carries'
        Remove-Item -LiteralPath (Join-Path $rd3 'crossdoc-refs') -Recurse -Force
        $r8 = Invoke-MergeFindings -ReviewDir $rd3 -UnitExtractPath $unit -OutPath (Join-Path $rd3 'merged\findings.json') -MarkdownPath (Join-Path $rd3 'merged\merged_audit.md') -Quiet
        Assert-True ($r8.ExitCode -eq 2 -and @($r8.Errors | Where-Object { $_ -match 'crossdoc-refs: expected reviewer has NO findings.json' }).Count -eq 1) 'a manifest-expected reviewer whose directory is gone is REFUSED by name'
        Write-Utf8File -Path (Join-Path $rd3 'manifest.json') -Content (([ordered]@{ expectedReviewers = @('topic1', 'crossdoc') } | ConvertTo-Json -Depth 4) + "`r`n")
        New-Item -ItemType Directory -Path (Join-Path $rd3 'crossdoc') -Force | Out-Null
        $cs = [ordered]@{ reviewer = 'crossdoc'; scope = 'cross-document agreement'; verdict = 'Fully Compliant'; findings = @(); coverage = @(); channels = [ordered]@{} }
        Write-Utf8File -Path (Join-Path $rd3 'crossdoc\findings.json') -Content (($cs | ConvertTo-Json -Depth 10) + "`r`n")
        $r9 = Invoke-MergeFindings -ReviewDir $rd3 -UnitExtractPath $unit -OutPath (Join-Path $rd3 'merged\findings.json') -MarkdownPath (Join-Path $rd3 'merged\merged_audit.md') -Quiet
        $j9 = Get-GateJson -Path (Join-Path $rd3 'merged\findings.json')
        Assert-True ($r9.ExitCode -eq 0 -and @($j9.reviewers).Count -eq 3) 'with a single crossdoc in the manifest the set resolves to topic1, crossdoc and the leftover crossdoc-values directory (a findings.json present is always read)'
    }
    finally {
        if ($root -and (Test-Path -LiteralPath $root) -and $root.Length -gt 12) { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    Write-Host ''
    if ($fails.Count -gt 0) { Write-Host ("  X self-test: {0} assertion(s) failed" -f $fails.Count) -ForegroundColor Red; return 4 }
    Write-Host '  self-test: every assertion held. This merger raises, collapses, takes the worst, and rewords nothing.' -ForegroundColor Green
    return 0
}

# ---------------------------------------------------------------------------
# Entry
# ---------------------------------------------------------------------------

if ($SelfTest) { exit (Invoke-MergeSelfTest) }

if (-not $ReviewDir) {
    Write-Host "$GATE`: usage: Merge-AuditFindings.ps1 -ReviewDir <dir> [-UnitExtract <md>] [-OutPath <findings.json>] [-MarkdownPath <merged_audit.md>] | -SelfTest" -ForegroundColor Red
    exit 2
}
if (-not $UnitExtract) {
    #  The packs each carry a copy; the manifest names the original. Any of them is the same file.
    $cands = @((Join-Path $ReviewDir 'unit_extract.md'))
    $mf = Join-Path $ReviewDir 'manifest.json'
    if (Test-Path -LiteralPath $mf) { $m = Get-GateJson -Path $mf; if ($null -ne $m -and $m.inputs -and $m.inputs.unitExtract) { $cands += [string]$m.inputs.unitExtract } }
    if (Test-Path -LiteralPath $ReviewDir) { foreach ($d in (Get-ChildItem -LiteralPath $ReviewDir -Directory | Sort-Object Name)) { $cands += (Join-Path $d.FullName 'unit_extract.md') } }
    foreach ($c in $cands) { if (Test-Path -LiteralPath $c) { $UnitExtract = $c; break } }
    if (-not $UnitExtract) { Write-Host "$GATE`: no unit extract found under $ReviewDir - pass -UnitExtract" -ForegroundColor Red; exit 2 }
}
if (-not $OutPath) { $OutPath = Join-Path (Join-Path $ReviewDir 'merged') 'findings.json' }
if (-not $MarkdownPath) { $MarkdownPath = Join-Path (Split-Path -Parent $OutPath) 'merged_audit.md' }

$run = Invoke-MergeFindings -ReviewDir $ReviewDir -UnitExtractPath $UnitExtract -OutPath $OutPath -MarkdownPath $MarkdownPath -Quiet:$Quiet
foreach ($e in $run.Errors) { Write-Host ("  X {0}" -f $e) -ForegroundColor Red }
if ($run.ExitCode -eq 2) { Write-Host '  X nothing was merged. Every violation above must be fixed in the reviewer''s own file, or the reviewer re-run.' -ForegroundColor Red }
exit $run.ExitCode
