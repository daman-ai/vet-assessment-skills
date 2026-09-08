<#
    Find-TopicOverlap.ps1 - find where two units in the SAME course cover the
    same ground, so a human can decide which one owns it.

    THIS SCRIPT DOES NOT DECIDE ANYTHING. It surfaces candidates. Ownership is
    a teaching judgement - which unit is sequenced first, which one assesses
    the requirement most fully, which one a learner would expect to meet it in
    - and a similarity score cannot make it. The register that comes out of
    that judgement is assets/topics/<courseId>.topics.json, and it is authored,
    not generated.

    The comparison runs over KNOWLEDGE EVIDENCE dot points and ELEMENT
    statements, because those are the requirements a learner guide turns into
    teaching topics. Performance evidence is deliberately excluded: two units
    both requiring a learner to "work safely" is not duplicated TEACHING, it is
    the same skill applied twice, which is what a qualification is for.

    Comparison is over content-word sets with a crude stem, and a pair is
    reported when it clears -Threshold. It is a net, not a judge: set it low
    enough to over-report, because a missed overlap ships as duplicated
    teaching and a false positive costs ten seconds to dismiss.

        .\Find-TopicOverlap.ps1 -CourseId MVC-SIT30821
        .\Find-TopicOverlap.ps1 -CourseId ACI-CPC31020 -Threshold 0.45 -IncludeCreditTransfer
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $CourseId,
    [double] $Threshold = 0.5,
    [int]    $MinWords  = 3,
    [switch] $IncludeCreditTransfer,
    [string] $CourseDir,
    [string] $UnitCache
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

function Get-Statements {
    param($Unit)
    $lines = @()
    foreach ($ln in ($Unit.knowledgeEvidence -split "`n")) {
        $x = $ln.Trim()
        if ($x.Length -lt 12) { continue }
        if ($x -match '^(Demonstrated knowledge required|To be competent in this unit|A person must demonstrate|The candidate must demonstrate|The candidate must be able to demonstrate|There must be evidence the candidate|Evidence of the ability|Evidence must be provided|The following knowledge must be assessed)') { continue }
        $lines += [pscustomobject]@{ Source='KE'; Text=$x }
    }
    foreach ($ln in ($Unit.elements -split "`n")) {
        $x = $ln.Trim()
        if ($x.Length -lt 12) { continue }
        if ($x -match '^(Elements|Performance criteria) (describe|\|)') { continue }
        if ($x -eq '|') { continue }
        if ($x -match '^\d+\.\d+\.') { continue }   # performance criteria are the DOING, not the topic
        if ($x -notmatch '^\d+\.\s') { continue }   # keep element statements only
        $lines += [pscustomobject]@{ Source='EL'; Text=$x }
    }
    return $lines
}

$course = Get-Content -LiteralPath (Join-Path $CourseDir "$CourseId.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$units  = $course.units
if (-not $IncludeCreditTransfer) { $units = $units | Where-Object { $_.deliveryStatus -eq 'delivered' } }

$data = @()
foreach ($cu in $units) {
    $f = Join-Path $UnitCache "$($cu.code).json"
    if (-not (Test-Path $f)) { continue }
    $u = Get-Content -LiteralPath $f -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($st in (Get-Statements $u)) {
        $tok = Get-Tokens $st.Text
        if ($tok.Count -lt $MinWords) { continue }
        $data += [pscustomobject]@{
            Code=$cu.code; Cluster=$cu.cluster; Seq=$cu.sequence
            Source=$st.Source; Text=$st.Text; Tok=$tok
        }
    }
}

Write-Host ""
Write-Host "$CourseId - $($course.qualificationTitle)"
Write-Host ("$($units.Count) units in scope, $($data.Count) comparable statements, threshold $Threshold")
Write-Host ""

$pairs = @()
for ($i = 0; $i -lt $data.Count; $i++) {
    for ($j = $i + 1; $j -lt $data.Count; $j++) {
        if ($data[$i].Code -eq $data[$j].Code) { continue }
        $a = $data[$i].Tok; $b = $data[$j].Tok
        $inter = 0; foreach ($k in $a.Keys) { if ($b.ContainsKey($k)) { $inter++ } }
        if ($inter -eq 0) { continue }
        $union = $a.Count + $b.Count - $inter
        $sim = [Math]::Round($inter / $union, 3)
        if ($sim -lt $Threshold) { continue }
        $pairs += [pscustomobject]@{
            Sim=$sim
            A=$data[$i].Code; ASeq=$data[$i].Seq; ACl=$data[$i].Cluster; ASrc=$data[$i].Source; AText=$data[$i].Text
            B=$data[$j].Code; BSeq=$data[$j].Seq; BCl=$data[$j].Cluster; BSrc=$data[$j].Source; BText=$data[$j].Text
        }
    }
}

if (-not $pairs) { Write-Host "no overlaps at or above $Threshold"; return }

$byPair = $pairs | Group-Object { ($_.A, $_.B | Sort-Object) -join ' <-> ' } | Sort-Object { -$_.Count }
Write-Host ("$($pairs.Count) overlapping statements across $($byPair.Count) unit pairs")
Write-Host ""
foreach ($g in $byPair) {
    Write-Host ("### $($g.Name)   [$($g.Count)]")
    foreach ($p in ($g.Group | Sort-Object -Property Sim -Descending)) {
        Write-Host ("  {0}  {1}[cl{2}] {3}" -f $p.Sim, $p.A, $p.ACl, $p.AText)
        Write-Host ("        {0}[cl{1}] {2}" -f $p.B, $p.BCl, $p.BText)
    }
    Write-Host ""
}
