<#
    Get-UnitBrief.ps1 - THE ONE ENTRY POINT. Given a unit code, return
    everything a build needs to know about that unit IN THE COURSE IT IS BEING
    BUILT FOR: the provider and trading name, where it sits in the delivery
    sequence, what it owns and must teach, what it must NOT re-teach because a
    sibling unit owns it, what the learner already holds, and anything that
    should stop the build.

    THE COURSE IS NOT OPTIONAL WHERE A UNIT SITS IN MORE THAN ONE. SITXFSA005
    appears in five of these courses. In SIT30821 it owns the organisational
    hygiene procedures and the Food Standards Code outright; in SIT50422 it is
    credit-transferred and is not taught at all. A brief without a course is a
    brief for the wrong course, so this script REFUSES to guess and lists the
    candidates instead.

    ANYTHING THAT SHOULD STOP A BUILD COMES BACK IN blockers, and a caller that
    ignores it will build against a superseded unit or an unusable delivery
    plan. The blockers are not advice.

        .\Get-UnitBrief.ps1 -Unit SITHCCC027 -CourseId MVC-SIT30821
        .\Get-UnitBrief.ps1 -Unit CPCCBC4002 -Json
        .\Get-UnitBrief.ps1 -Unit SITXFSA005            # lists the five courses
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $Unit,
    [string] $CourseId,
    [string] $Qualification,
    [switch] $Json,
    [string] $AssetDir
)

$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $AssetDir) { $AssetDir = Join-Path $root '../assets' }
$Unit = $Unit.Trim().ToUpper()

$courses = @(Get-ChildItem (Join-Path $AssetDir 'courses') -Filter *.json | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
})

$hits = @($courses | Where-Object { $_.units.code -contains $Unit })
if (-not $hits) { throw "$Unit is not in any course in this registry." }

if ($CourseId)          { $hits = @($hits | Where-Object { $_.courseId -eq $CourseId }) }
elseif ($Qualification) { $hits = @($hits | Where-Object { $_.qualificationCode -eq $Qualification.ToUpper() }) }

if ($hits.Count -eq 0) { throw "$Unit is not in the course you named." }
if ($hits.Count -gt 1) {
    Write-Host ""
    Write-Host "$Unit sits in $($hits.Count) courses. Name one with -CourseId; a topic allocation is meaningless without it." -ForegroundColor Yellow
    foreach ($h in $hits) {
        $c2 = $h.units | Where-Object { $_.code -eq $Unit }
        Write-Host ("  {0,-14} {1,-52} {2}" -f $h.courseId, $h.qualificationTitle, $c2.deliveryStatus)
    }
    Write-Host ""
    exit 2
}

$course = $hits[0]
$cu     = $course.units | Where-Object { $_.code -eq $Unit } | Select-Object -First 1
$rec    = Get-Content -LiteralPath (Join-Path $AssetDir "units/$Unit.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$prov   = (Get-Content -LiteralPath (Join-Path $AssetDir 'providers.json') -Raw -Encoding UTF8 | ConvertFrom-Json).providers

$topicFile = Join-Path $AssetDir "topics/$($course.courseId).topics.json"
$topics = if (Test-Path $topicFile) { Get-Content -LiteralPath $topicFile -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }

$owns = @(); $applies = @()
if ($topics) {
    $owns    = @($topics.topics | Where-Object { $_.owner -eq $Unit })
    $applies = @($topics.topics | Where-Object { $_.appliedNotTaught -contains $Unit })
}

$p = $prov.($course.provider)
$tradingName = if ($course.brandVariant) { $p.variants.($course.brandVariant).tradingName } else { $p.tradingName }
$deliveredNames = @($course.institute)

$assumedPrior = @($course.units | Where-Object { $_.deliveryStatus -eq 'credit-transfer' } | ForEach-Object { $_.code })
$priorCourseUnits = @()
if ($course.priorCourse) {
    $pc = $courses | Where-Object { $_.courseId -eq $course.priorCourse } | Select-Object -First 1
    if ($pc) { $priorCourseUnits = @($pc.units | ForEach-Object { $_.code }) }
}

$blockers = @()
$deferred = @()
# A superseded unit normally stops the build. The exception is a unit the QUALIFICATION
# still names in its packaging rules, where a decision to keep delivering it is recorded
# on the unit and has not yet lapsed - then the build proceeds against the superseded
# unit, which is what the qualification requires, and the brief says so out loud.
if ($rec.status -ne 'current') {
    $sup = $cu.supersession
    $live = $sup -and $sup.decision -eq 'continue-delivery' -and $sup.reviewBy -and
            ([datetime]::Parse($sup.reviewBy) -ge (Get-Date).Date)
    if ($live) {
        $deferred += "$Unit is $($rec.statusLabel) on training.gov.au, equivalent to $($sup.equivalentTo), BUT $($course.qualificationCode) still names $Unit in its packaging rules ($($sup.qualificationRelease)). BUILD AGAINST $Unit - that is what the qualification requires. Decision recorded $($sup.decidedOn), review by $($sup.reviewBy). Never deliver it as a standalone enrolment."
    } else {
        $blockers += "$Unit is $($rec.statusLabel) on training.gov.au. Do not build against it - transition to the superseding unit first." +
                     $(if ($sup) { " The decision to keep delivering it lapsed on $($sup.reviewBy)." } else { "" })
    }
}
if ($cu.deliveryStatus -ne 'delivered') { $blockers += "$Unit is $($cu.deliveryStatus) in $($course.courseId) - it is not taught here, so no learner guide or assessment tool is built for it in this course." }
if ($course.sequencing.model -eq 'none') { $blockers += "$($course.courseId) has no usable delivery sequence. Topic ownership was decided on subject matter alone - see openItems in the course record." }
foreach ($oi in $course.openItems) { if ($oi -match '^BLOCKING') { $blockers += $oi } }
$caveats = @()
foreach ($d in $deferred) { $caveats += $d }
if ($course.siblingCourse) {
    $caveats += "The same qualification is delivered by the other institute under $($course.siblingCourse), from its OWN Training and Assessment Strategy and with its own elective selection. This brief is for $($course.institute) only - never carry a ruling across."
}

$missingPre = @($rec.prerequisites | Where-Object { $course.units.code -notcontains $_.code } | ForEach-Object { "$($_.code) $($_.title)" })
$clusterName = ($course.sequencing.clusters | Where-Object { $_.number -eq $cu.cluster } | Select-Object -First 1).name

$brief = [ordered]@{
    unit             = $Unit
    unitTitle        = $rec.title
    unitStatus       = $rec.statusLabel
    courseId         = $course.courseId
    qualification    = "$($course.qualificationCode) $($course.qualificationTitle)"
    aqfLevel         = $course.aqfLevel
    provider         = $course.provider
    brandVariant     = $course.brandVariant
    tradingName      = $tradingName
    siblingCourse    = $course.siblingCourse
    institute        = $course.institute
    designation      = $cu.designation
    deliveryStatus   = $cu.deliveryStatus
    cluster          = $cu.cluster
    clusterName      = $clusterName
    sequence         = $cu.sequence
    prerequisitesNotInCourse = $missingPre
    prerequisites    = @($rec.prerequisites | ForEach-Object { "$($_.code) $($_.title)" })
    doNotReTeach     = @($applies | ForEach-Object { [ordered]@{ id=$_.id; name=$_.name; kind=$_.kind; ownedBy=$_.owner; teachingRule=$_.teachingRule; assessmentDepth=$_.assessmentDepth; ownerBenchmark=$_.ownerBenchmark } })
    teachInFull      = @($owns | ForEach-Object { [ordered]@{ id=$_.id; name=$_.name; kind=$_.kind; alsoAppearsIn=$_.appliedNotTaught; anchors=$_.tgaAnchors; assessmentDepth='foundation'; ownerBenchmark=$_.ownerBenchmark } })
    assessmentRule   = 'Assessment is PER UNIT. This unit''s tool evidences every one of this unit''s requirements in full, including every doNotReTeach topic. No assess-once register line may name another unit as its evidence. doNotReTeach governs TEACHING depth and assessment FORM only - assess it applied, inside a question about this unit''s own subject or by an observation item, against ownerBenchmark so the standard matches the owning unit''s.'
    assumedPriorInThisCourse = $assumedPrior
    priorCourse      = $course.priorCourse
    priorCourseUnits = $priorCourseUnits
    blockers         = $blockers
    caveats          = $caveats
    sources          = [ordered]@{ tas = $course.source.tasFile; unit = $rec.sourceUrl; topics = "assets/topics/$($course.courseId).topics.json" }
}

if ($Json) { $brief | ConvertTo-Json -Depth 8; return }

Write-Host ""
Write-Host "$Unit  $($rec.title)"
Write-Host "$($course.qualificationCode) $($course.qualificationTitle)"
Write-Host ("delivered by: " + $course.institute)
if ($course.siblingCourse) {
    Write-Host ("  also delivered by the other institute as $($course.siblingCourse), which holds its own strategy and its own topic map") -ForegroundColor Yellow
}
$line = "$($cu.designation), $($cu.deliveryStatus)"
if ($cu.cluster) { $line += ", cluster $($cu.cluster) $clusterName" }
Write-Host $line
if ($brief.prerequisites) { Write-Host "prerequisite: $($brief.prerequisites -join '; ')" }
if ($missingPre) { Write-Host "PREREQUISITE NOT IN THIS COURSE: $($missingPre -join '; ')" -ForegroundColor Yellow }
Write-Host ""

if ($blockers) {
    Write-Host "BLOCKERS" -ForegroundColor Red
    $blockers | ForEach-Object { Write-Host "  ! $_" -ForegroundColor Red }
    Write-Host ""
}

if ($caveats) {
    Write-Host "CAVEATS" -ForegroundColor Yellow
    $caveats | ForEach-Object { Write-Host "  ~ $_" -ForegroundColor Yellow }
    Write-Host ""
}
Write-Host "TEACH IN FULL - this unit owns these topics ($($owns.Count))"
if (-not $owns) { Write-Host "  (none shared - every requirement of this unit is unique to it, so teach the unit's own requirements in full)" }
foreach ($t in $owns) {
    Write-Host ("  {0}  [{1}]  {2}" -f $t.id, $t.kind, $t.name)
    if ($t.appliedNotTaught) { Write-Host ("       also required by: " + ($t.appliedNotTaught -join ', ')) }
}
Write-Host ""

Write-Host "TEACH BY RECALL - a sibling unit owns the TEACHING of these ($($applies.Count))"
Write-Host "  Assessment is per unit and is NOT reduced: this unit's tool still evidences every" -ForegroundColor DarkGray
Write-Host "  one of these requirements in full, on its own mapped line. Never cite another unit" -ForegroundColor DarkGray
Write-Host "  as the evidence. These rulings govern teaching depth and assessment FORM only." -ForegroundColor DarkGray
if (-not $applies) { Write-Host "  (none)" }
foreach ($t in $applies) {
    Write-Host ("  {0}  [{1}]  {2}" -f $t.id, $t.kind, $t.name)
    Write-Host ("       owned by {0}   assess: {1}" -f $t.owner, $t.assessmentDepth)
    Write-Host ("       {0}" -f $t.teachingRule)
    if ($t.ownerBenchmark) { Write-Host ("       benchmark anchor: {0}" -f $t.ownerBenchmark) }
}
Write-Host ""

if ($assumedPrior) {
    Write-Host "ASSUMED PRIOR - credit-transferred into this course, the learner already holds these ($($assumedPrior.Count))"
    Write-Host ("  " + ($assumedPrior -join ', '))
    if ($course.priorCourse) { Write-Host "  from $($course.priorCourse)" }
    Write-Host ""
}
