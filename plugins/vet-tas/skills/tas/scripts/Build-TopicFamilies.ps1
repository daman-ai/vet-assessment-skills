<#
    Build-TopicFamilies.ps1 - collapse the pairwise overlaps of a course into
    TOPIC FAMILIES, so ownership is decided once per concept instead of once
    per pair.

    Find-TopicOverlap reports pairs. A 25-unit cookery qualification produces
    over five hundred of them, and nobody adjudicates five hundred pairs - they
    adjudicate "food safety and temperature control", "mise en place",
    "portion control and waste", and assign each to one unit. This script does
    the collapsing: statements are nodes, an overlap above the threshold is an
    edge, and each connected component of that graph is a candidate family.

    THE FAMILIES ARE CANDIDATES, NOT ANSWERS. A connected component can chain
    two genuinely different topics together through one ambiguous statement
    that resembles both. The output is read by a human who names each family,
    splits the ones that merged wrongly, and names the owner. That authored
    result is assets/topics/<courseId>.topics.json.

    THE FIRST-SEQUENCED UNIT IS THE DEFAULT OWNER, and it is only a default.
    A topic belongs where it is taught most fully, which is usually but not
    always the first unit that mentions it. The suggested owner is printed so
    the reviewer has somewhere to start disagreeing from.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $CourseId,
    [double] $Threshold = 0.45,
    [int]    $MinWords  = 3,
    [int]    $MinUnits  = 2,
    [string] $CourseDir,
    [string] $UnitCache,
    [string] $OutJson
)

$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $CourseDir) { $CourseDir = Join-Path $root '../assets/courses' }
if (-not $UnitCache) { $UnitCache = Join-Path $root '../assets/units' }

$stop = @'
the a an and or of to in for with on at by from as is are be been being that this these those it its their they them
which where when who whose what how why all any each other others own such into out up down over under about
must may can will shall should would could than then there here also more most some no not non
including include includes included use used using uses required require requirements requirement relevant appropriate
following follows follow different various range types type forms form ways way area areas
'@ -split '\s+' | Where-Object { $_ }
$stopSet = @{}; foreach ($s in $stop) { $stopSet[$s] = $true }

function Get-Tokens {
    param([string]$Text)
    $t = $Text.ToLower() -replace "[^a-z0-9\s-]", ' '
    $words = $t -split '\s+' | Where-Object { $_.Length -gt 2 -and -not $stopSet.ContainsKey($_) }
    $out = @{}
    foreach ($w in $words) {
        $s = $w
        if ($s.Length -gt 5 -and $s.EndsWith('ies'))  { $s = $s.Substring(0, $s.Length-3) + 'y' }
        elseif ($s.Length -gt 4 -and $s.EndsWith('ing')) { $s = $s.Substring(0, $s.Length-3) }
        elseif ($s.Length -gt 4 -and $s.EndsWith('ed'))  { $s = $s.Substring(0, $s.Length-2) }
        elseif ($s.Length -gt 3 -and $s.EndsWith('s') -and -not $s.EndsWith('ss')) { $s = $s.Substring(0, $s.Length-1) }
        $out[$s] = $true
    }
    return $out
}

$course = Get-Content -LiteralPath (Join-Path $CourseDir "$CourseId.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$units  = @($course.units | Where-Object { $_.deliveryStatus -eq 'delivered' })
$orderOf = @{}
foreach ($u in $units) {
    $orderOf[$u.code] = if ($null -ne $u.cluster) { [int]$u.cluster * 1000 + [int]$u.sequence } else { [int]$u.sequence }
}

$nodes = @()
foreach ($cu in $units) {
    $f = Join-Path $UnitCache "$($cu.code).json"
    if (-not (Test-Path $f)) { continue }
    $u = Get-Content -LiteralPath $f -Raw -Encoding UTF8 | ConvertFrom-Json
    $stmts = @()
    foreach ($ln in ($u.knowledgeEvidence -split "`n")) {
        $x = $ln.Trim()
        if ($x.Length -lt 12) { continue }
        if ($x -match '^(Demonstrated knowledge required|To be competent in this unit|A person must demonstrate|The candidate must demonstrate|The candidate must be able to demonstrate|There must be evidence the candidate|Evidence of the ability|Evidence must be provided|The following knowledge must be assessed)') { continue }
        $stmts += @{ S='KE'; T=$x }
    }
    foreach ($ln in ($u.elements -split "`n")) {
        $x = $ln.Trim()
        if ($x.Length -lt 12 -or $x -eq '|') { continue }
        if ($x -match '^(Elements|Performance criteria) (describe|\|)') { continue }
        if ($x -match '^\d+\.\d+\.') { continue }
        if ($x -notmatch '^\d+\.\s') { continue }
        $stmts += @{ S='EL'; T=$x }
    }
    foreach ($st in $stmts) {
        $tok = Get-Tokens $st.T
        if ($tok.Count -lt $MinWords) { continue }
        $nodes += [pscustomobject]@{
            Code=$cu.code; Cluster=$cu.cluster; Order=$orderOf[$cu.code]
            Source=$st.S; Text=$st.T; Tok=$tok
        }
    }
}

# --- union-find over statements ---------------------------------------
$parent = [int[]](0..($nodes.Count - 1))
function Find-Root {
    param([int]$i)
    while ($parent[$i] -ne $i) { $parent[$i] = $parent[$parent[$i]]; $i = $parent[$i] }
    return $i
}
$edges = 0
for ($i = 0; $i -lt $nodes.Count; $i++) {
    for ($j = $i + 1; $j -lt $nodes.Count; $j++) {
        if ($nodes[$i].Code -eq $nodes[$j].Code) { continue }
        $a = $nodes[$i].Tok; $b = $nodes[$j].Tok
        $inter = 0; foreach ($k in $a.Keys) { if ($b.ContainsKey($k)) { $inter++ } }
        if ($inter -eq 0) { continue }
        if (($inter / ($a.Count + $b.Count - $inter)) -lt $Threshold) { continue }
        $ri = Find-Root $i; $rj = Find-Root $j
        if ($ri -ne $rj) { $parent[$rj] = $ri }
        $edges++
    }
}

$groups = @{}
for ($i = 0; $i -lt $nodes.Count; $i++) {
    $r = Find-Root $i
    if (-not $groups.ContainsKey($r)) { $groups[$r] = @() }
    $groups[$r] += $i
}

$families = @()
foreach ($k in $groups.Keys) {
    $ix = $groups[$k]
    $codes = @($ix | ForEach-Object { $nodes[$_].Code } | Select-Object -Unique)
    if ($codes.Count -lt $MinUnits) { continue }
    $ordered = @($codes | Sort-Object { $orderOf[$_] })
    $families += [pscustomobject]@{
        Units          = $ordered
        SuggestedOwner = $ordered[0]
        Statements     = @($ix | Sort-Object { $orderOf[$nodes[$_].Code] } | ForEach-Object {
            [pscustomobject]@{ Code=$nodes[$_].Code; Cluster=$nodes[$_].Cluster; Source=$nodes[$_].Source; Text=$nodes[$_].Text }
        })
    }
}
$families = @($families | Sort-Object { -$_.Units.Count })

Write-Host ""
Write-Host "$CourseId - $($course.qualificationTitle)"
Write-Host ("$($units.Count) delivered units, $($nodes.Count) statements, $edges overlapping pairs")
Write-Host ("$($families.Count) topic families spanning $MinUnits or more units")
Write-Host ""
$n = 0
foreach ($fam in $families) {
    $n++
    Write-Host ("=== F{0:D2}  {1} units  suggested owner: {2}" -f $n, $fam.Units.Count, $fam.SuggestedOwner)
    Write-Host ("    units: " + ($fam.Units -join ', '))
    foreach ($s in $fam.Statements) {
        $t = if ($s.Text.Length -gt 155) { $s.Text.Substring(0,152) + '...' } else { $s.Text }
        Write-Host ("      {0} [cl{1}] {2}" -f $s.Code, $s.Cluster, $t)
    }
    Write-Host ""
}

if ($OutJson) {
    $out = [ordered]@{
        courseId     = $CourseId
        threshold    = $Threshold
        generatedUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        families     = @($families | ForEach-Object {
            [ordered]@{ units=$_.Units; suggestedOwner=$_.SuggestedOwner; statements=$_.Statements }
        })
    }
    [System.IO.File]::WriteAllText($OutJson, ($out | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding $true))
    Write-Host "wrote $OutJson"
}
