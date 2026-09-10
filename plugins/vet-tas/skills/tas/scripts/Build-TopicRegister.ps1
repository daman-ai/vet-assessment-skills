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

      owns               This unit teaches the topic in full and assesses it at
                         FOUNDATION depth. Its benchmark is the anchor every
                         other unit's benchmark for the same requirement follows.
      applied-not-taught The topic appears in this unit's requirements and the
                         learner has already been taught it. The learner guide
                         RECALLS rather than re-explains: a short restatement
                         that stands on its own, a retrieval prompt the learner
                         answers, then the delta taught in full. Never a bare
                         cross-reference - a pointer is worse than a re-teach,
                         because the learner who has forgotten it finds nothing
                         on the page.

                         ASSESSMENT COVERAGE IS NOT REDUCED. Every unit is
                         separately certified - a learner can be issued a
                         Statement of Attainment for this unit alone - so this
                         unit's tool still evidences this requirement in full,
                         in its own instrument, on its own mapped line. No
                         register line may name another unit as its evidence.

                         What the ruling governs is DEPTH and FORM: assessed
                         APPLIED, inside a question about this unit's own
                         subject or carried by an observation item, against the
                         owner's benchmark rather than a benchmark reinvented
                         from scratch. Twelve units carrying one requirement
                         must not produce twelve different standards - that is
                         the consistency Standard 1.5 validation tests.

    KINDS, and why the distinction matters more than it looks:

      shared-scaffold    One generic concept several units restate. Teach once.
                         This is the duplication the registry removes.
                         assessmentDepth: applied.
      commodity-parallel Same STRUCTURE, different subject matter - cookery
                         methods for poultry against cookery methods for
                         seafood. NOT duplication. Each unit teaches its own
                         commodity; only the generic frame is owned once.
                         Collapsing these would gut the qualification.
                         assessmentDepth: full - it is this unit's own subject.
      progressive-depth  Introduced at one AQF level, deepened at the next with
                         a stated delta. The owner teaches the foundation; the
                         later unit teaches only what is new.
                         assessmentDepth: applied, at the later unit's level.
      regulatory-recall  Legislation, codes and standards. Taught once in full;
                         everywhere else a named recall, because an auditor
                         reading two different summaries of one Act finds two
                         chances to be wrong. assessmentDepth: applied - and the
                         owner's benchmark matters most here, because two
                         differing summaries of one Act is the defect itself.
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

    # A unit the detector put in a family but which TEACHES THIS IN ITS OWN RIGHT.
    # Authored, with a reason, because the detector matches words and cannot see
    # that SITXFSA006's temperature probe is a food-safety instrument rather than
    # a piece of the equipment topic. An excluded unit is not a recaller: it
    # teaches and assesses its own slice in full.
    $excl = @()
    if ($d.PSObject.Properties['excludeUnits']) { $excl = @($d.excludeUnits) }
    $exclCodes = @($excl | ForEach-Object { $_.unit })

    $applied = @($units | Where-Object { $_ -ne $d.owner -and $exclCodes -notcontains $_ })

    # ORDERING GATE. A learner cannot recall what they have not been taught, so
    # every applying unit must sit AFTER its owner in the delivery sequence.
    # A violation is an authoring error - usually a rationale claiming "earliest"
    # against the unit TABLE rather than the delivery order - or a missing
    # exclusion. Both are fixed by deciding, not by suppressing.
    $ownerSeq = ($course.units | Where-Object { $_.code -eq $d.owner } | Select-Object -First 1).sequence
    foreach ($a in $applied) {
        $aSeq = ($course.units | Where-Object { $_.code -eq $a } | Select-Object -First 1).sequence
        if ($null -ne $aSeq -and $null -ne $ownerSeq -and $aSeq -lt $ownerSeq) {
            $errors += "$($d.name): $a (seq $aSeq) recalls this, but owner $($d.owner) is taught later (seq $ownerSeq) - move ownership earlier, or exclude $a with a reason"
        }
    }

    # Depth at which the APPLYING units assess the topic. Coverage is never in
    # question - every applying unit still evidences the requirement in full.
    # Authored per topic where it matters; defaulted by kind otherwise, so no
    # existing decisions file has to be migrated to gain the field.
    $depth = if ($d.PSObject.Properties['assessmentDepth'] -and $d.assessmentDepth) {
                 $d.assessmentDepth
             } elseif ($d.kind -eq 'commodity-parallel') {
                 'full'      # its own commodity, taught and assessed in full
             } else {
                 'applied'   # inside this unit's own subject, or by observation
             }
    $benchmark = if ($d.PSObject.Properties['ownerBenchmark']) { $d.ownerBenchmark } else { $null }
    $benchProv = if ($d.PSObject.Properties['benchmarkProvenance']) { $d.benchmarkProvenance } else { $null }

    $topics += [ordered]@{
        id               = ("{0}-T{1:D2}" -f $course.qualificationCode, $n)
        name             = $d.name
        kind             = $d.kind
        owner            = $d.owner
        ownerCluster     = $(if ($ownerUnit) { $ownerUnit.cluster } else { $null })
        rationale        = $d.rationale
        teachingRule     = $d.teachingRule
        assessmentDepth  = $depth
        ownerBenchmark   = $benchmark
        benchmarkProvenance = $benchProv
        excludedUnits    = @($excl)
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

# A teachingRule that says "cite CPCCWHS2001 for the frame" names a unit the topic
# itself does not link to. That is normally fine - a requirement carried by only one
# unit overlaps nothing and never enters the register, so the unit teaching it owns
# no topic. Recording the classification is what stops a reader having to re-derive
# it, and what makes a genuinely missed overlap visible instead of invisible.
$allOwners = @($topics | ForEach-Object { $_.owner })
$courseCodes = @($course.units | ForEach-Object { $_.code })
foreach ($t in $topics) {
    $linked = @($t.owner) + @($t.appliedNotTaught) + @($t.excludedUnits | ForEach-Object { $_.unit })
    $cites = @()
    foreach ($mm in [regex]::Matches([string]$t.teachingRule, '\b[A-Z]{3}[A-Z0-9]{3,9}\b')) {
        $u = $mm.Value
        if ($courseCodes -notcontains $u -or $linked -contains $u) { continue }
        if ($cites.unit -contains $u) { continue }
        $cites += [ordered]@{
            unit   = $u
            status = $(if ($allOwners -contains $u) { 'owns-another-topic-here' } else { 'outside-the-register - carries this as a requirement unique to it, so no ruling was needed' })
        }
    }
    $t.citations = @($cites)
}

$index = [ordered]@{}
foreach ($cu in ($course.units | Where-Object { $_.deliveryStatus -eq 'delivered' })) {
    $owns    = @($topics | Where-Object { $_.owner -eq $cu.code } | ForEach-Object { $_.id })
    $applies = @($topics | Where-Object { $_.appliedNotTaught -contains $cu.code } | ForEach-Object { $_.id })
    $index[$cu.code] = [ordered]@{ owns = $owns; appliedNotTaught = $applies }
}

$out = [ordered]@{
    schemaVersion      = '1.1'
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
    assessmentNote     = 'ASSESSMENT IS PER UNIT. A ruling never removes a requirement from an applying unit''s assessment tool - every unit is separately certified and evidences its own requirements in full, on its own mapped line, with no line naming another unit as its evidence. assessmentDepth governs DEPTH and FORM only: "applied" means assessed inside a question about this unit''s own subject or carried by an observation item, against the owner''s benchmark; "full" means this unit teaches and assesses its own subject matter in full. The register exists to keep those benchmarks consistent across the units that share a requirement, which is what Standard 1.5 validation tests.'
}

$dest = Join-Path $TopicDir "$CourseId.topics.json"
[System.IO.File]::WriteAllText($dest, ($out | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding $true))

$byKind = $topics | ForEach-Object { $_.kind } | Group-Object | ForEach-Object { "$($_.Name)=$($_.Count)" }
Write-Host ("  {0,-14} {1,2} topics ({2}), all {3} families claimed" -f $CourseId, $topics.Count, ($byKind -join ' '), $famById.Count)
