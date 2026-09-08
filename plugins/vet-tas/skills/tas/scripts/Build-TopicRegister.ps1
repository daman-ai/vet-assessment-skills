<#
    Build-TopicRegister.ps1 - join the authored ownership decisions to the
    detected topic families and emit assets/topics/<courseId>.topics.json.

    THIS IS THE FILE THE ASSESSMENT AND LEARNER-GUIDE SKILLS READ. Everything
    upstream of it - the harvest, the TAS parse, the overlap detection, the
    family clustering - exists to make it possible to author, and everything
    downstream reads it and nothing else.

    EVERY FAMILY IS CLAIMED EXACTLY ONCE, and the script fails if that is not
    true. A family claimed twice means two topics own the same ground and the
    duplication this registry exists to remove has been re-introduced inside
    the register itself. A family claimed by nobody means an overlap was
    detected, nobody decided who owned it, and the next build will teach it
    twice - silently, because the register will look complete.

    A TOPIC HAS EXACTLY ONE OWNER and any number of units that APPLY it:

      owns               This unit teaches the topic. Its learner guide carries
                         the full explanation; its assessment tool may assess it.
      applied-not-taught The topic appears in this unit's requirements, but a
                         learner has already met it. The learner guide recalls
                         it in a line or two and points at the owning unit. The
                         assessment tool does NOT re-assess it as knowledge.

    KINDS, and why the distinction matters more than it looks:

      shared-scaffold    One generic concept several units restate. Teach once.
                         This is the duplication the registry removes.
      commodity-parallel Same STRUCTURE, different subject matter - cookery
                         methods for poultry against cookery methods for
                         seafood. NOT duplication. Each unit teaches its own
                         commodity; only the generic frame is owned once.
                         Collapsing these would gut the qualification.
      progressive-depth  Introduced at one AQF level, deepened at the next with
                         a stated delta. The owner teaches the foundation; the
                         later unit teaches only what is new.
      regulatory-recall  Legislation, codes and standards. Taught once in full;
                         everywhere else a named recall, because an auditor
                         reading two different summaries of one Act finds two
                         chances to be wrong.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $CourseId,
    [string] $TopicDir,
    [string] $CourseDir
)

$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $TopicDir)  { $TopicDir  = Join-Path $root '../assets/topics' }
if (-not $CourseDir) { $CourseDir = Join-Path $root '../assets/courses' }

$course  = Get-Content -LiteralPath (Join-Path $CourseDir "$CourseId.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$fam     = Get-Content -LiteralPath (Join-Path $TopicDir "families/$CourseId.families.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$dec     = Get-Content -LiteralPath (Join-Path $TopicDir "decisions/$CourseId.decisions.json") -Raw -Encoding UTF8 | ConvertFrom-Json

$famById = [ordered]@{}
$i = 0
foreach ($f in $fam.families) { $i++; $famById[("F{0:D2}" -f $i)] = $f }

$claimed = @{}
$errors  = @()
$topics  = @()
$n = 0

foreach ($d in $dec.topics) {
    $n++
    $units = @(); $stmts = @()
    foreach ($fid in $d.families) {
        if (-not $famById.Contains($fid)) { $errors += "$($d.name): family $fid does not exist"; continue }
        if ($claimed.ContainsKey($fid))   { $errors += "family $fid claimed twice - by '$($claimed[$fid])' and '$($d.name)'"; continue }
        $claimed[$fid] = $d.name
        $units += $famById[$fid].units
        $stmts += $famById[$fid].statements
    }
    $units = @($units | Select-Object -Unique)
    if ($units -notcontains $d.owner) {
        $errors += "$($d.name): owner $($d.owner) is not among the units of its families ($($units -join ', '))"
    }

    $ownerUnit = $course.units | Where-Object { $_.code -eq $d.owner } | Select-Object -First 1
    $anchors = @($stmts | Where-Object { $_.Code -eq $d.owner } | ForEach-Object {
        [ordered]@{ unit = $_.Code; section = $_.Source; text = $_.Text }
    })
    if (-not $anchors) {
        $anchors = @($stmts | Select-Object -First 2 | ForEach-Object {
            [ordered]@{ unit = $_.Code; section = $_.Source; text = $_.Text }
        })
    }

    $applied = @($units | Where-Object { $_ -ne $d.owner })
    $topics += [ordered]@{
        id               = ("{0}-T{1:D2}" -f $course.qualificationCode, $n)
        name             = $d.name
        kind             = $d.kind
        owner            = $d.owner
        ownerCluster     = $(if ($ownerUnit) { $ownerUnit.cluster } else { $null })
        rationale        = $d.rationale
        teachingRule     = $d.teachingRule
        tgaAnchors       = $anchors
        appliedNotTaught = $applied
        families         = $d.families
    }
}

foreach ($u in @($famById.Keys)) {
    if (-not $claimed.ContainsKey($u)) {
        $errors += "family $u is claimed by no topic - units $($famById[$u].units -join ', ') - decide who owns it"
    }
}

if ($errors) {
    Write-Host "$CourseId - topic register NOT written" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    exit 1
}

$index = [ordered]@{}
foreach ($cu in ($course.units | Where-Object { $_.deliveryStatus -eq 'delivered' })) {
    $owns    = @($topics | Where-Object { $_.owner -eq $cu.code } | ForEach-Object { $_.id })
    $applies = @($topics | Where-Object { $_.appliedNotTaught -contains $cu.code } | ForEach-Object { $_.id })
    $index[$cu.code] = [ordered]@{ owns = $owns; appliedNotTaught = $applies }
}

$out = [ordered]@{
    schemaVersion      = '1.0'
    courseId           = $CourseId
    qualificationCode  = $course.qualificationCode
    qualificationTitle = $course.qualificationTitle
    provider           = $course.provider
    brandVariant       = $course.brandVariant
    priorCourse        = $course.priorCourse
    generatedUtc       = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    method             = [ordered]@{
        unitSource       = 'training.gov.au REST API'
        overlapDetection = "assets/topics/families/$CourseId.families.json"
        decisions        = "assets/topics/decisions/$CourseId.decisions.json"
        threshold        = $fam.threshold
        note             = 'Families are detected mechanically; ownership is authored. Every family is claimed exactly once and the build fails otherwise.'
    }
    topicCount         = $topics.Count
    topics             = $topics
    unitTopicIndex     = $index
    unownedTopicsNote  = 'A requirement not appearing here overlapped nothing: it is unique to its unit, that unit teaches it, and no ruling was needed.'
}

$dest = Join-Path $TopicDir "$CourseId.topics.json"
[System.IO.File]::WriteAllText($dest, ($out | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding $true))

$byKind = $topics | ForEach-Object { $_.kind } | Group-Object | ForEach-Object { "$($_.Name)=$($_.Count)" }
Write-Host ("  {0,-14} {1,2} topics ({2}), all {3} families claimed" -f $CourseId, $topics.Count, ($byKind -join ' '), $famById.Count)
