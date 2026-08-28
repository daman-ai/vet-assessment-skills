# =====================================================================
#  WARNING - THIS FILE PREDATES THE CURRENT CONTRACT. READ BEFORE COPYING.
#
#  It is kept as the worked record of a real four-document build, and the
#  BLOCK-BUILDER CALLS and the PAGINATION CALL SITES are still correct and
#  still worth copying.
#
#  Its CONTENT SCHEMA is not. This file reads:
#      $p.modelAnswer      a STRING   - abolished; the contract now defines
#                                       modelAnswerPoints, an ARRAY, and
#                                       section-contract.md explains why a
#                                       string field is the root cause of
#                                       prose model answers
#      $p.responseType / $p.table     - now responseSpace / itemTable
#      $p.scenario / $p.scenarioHeading - now scenarioBox
#      benchmark.workedAnswerKeyAndTolerance - now workedKey
#
#  Copy the RENDERING from here. Take the SCHEMA from references/section-contract.md.
# =====================================================================
# Build-House.ps1 - renders all four SITHPAT018 documents to the MVC house
# standard measured from the RTO's own artefacts. See MVC_HOUSE_STANDARD.md.
#
#   1 SITHPAT018_UAT1_Knowledge.docx                    learner, knowledge
#   2 Assessor_Guide_SITHPAT018_UAT1_Knowledge.docx     mirror + red model answers
#   3 SITHPAT018_Recipe_Workbook.docx                   learner, practical
#   4 Assessor_Guide_SITHPAT018_Recipe_Workbook.docx    mirror + benchmarks
#
# One contract, one builder, four documents. ASCII only in this file; content
# arrives from JSON already carrying degree symbols and en dashes.
param(
    [string]$Root     = 'C:\Users\ACI-Admin\Desktop\SITHPAT018',
    [string]$SkillDir = 'C:\Users\ACI-Admin\.claude\skills\assessment'
)

. "$SkillDir\scripts\Build-FromTemplate.ps1"
. "$Root\build\Docx-Blocks-House.ps1"

$ErrorActionPreference = 'Stop'
$EMD = [char]0x2014      # em dash, for headings the house documents write with one
$ELL = [char]0x2026

function J { param([string]$n) Get-Content "$Root\house\$n" -Raw -Encoding UTF8 | ConvertFrom-Json }
$FRONT   = J 'FRONT.json'
$TASKS   = J 'TASKS.json'
$RECIPES = J 'RECIPES.json'
$WB      = J 'WB.json'

function P { param($o,[string]$n)
    if ($null -eq $o) { return $null }
    if ($o.PSObject.Properties.Name -contains $n) { return $o.$n }
    return $null
}
function AsArr { param($x) if ($null -eq $x) { return @() } return @($x) }
# Assessor fields may be an array of points or a legacy newline-separated string.
function Pts { param($v)
    if ($null -eq $v) { return @() }
    if ($v -is [System.Array]) { return @($v | Where-Object { $_ -and ([string]$_).Trim() }) }
    return @((([string]$v) -split "`n") | Where-Object { $_.Trim() })
}

# =====================================================================
#  UAT 1 - Knowledge
# =====================================================================
function Build-UAT1Body {
    param([switch]$Assessor)
    $sb = New-Object System.Text.StringBuilder

    # ---- assessment overview ----
    # RULE: the first body block continues on the title page. No blank space
    # under the version line and no page given over to nothing.
    # Every document carries a table of contents, immediately after the title page.
    [void]$sb.Append((HTableOfContents))
    [void]$sb.Append((HBanner -Text 'Assessment overview' -PageBreakBefore))
    foreach ($p in (AsArr $FRONT.overview)) { [void]$sb.Append((HBody -Text $p)) }

    [void]$sb.Append((HHead -Text 'What this assessment covers'))
    if (P $FRONT.whatThisCovers 'intro') { [void]$sb.Append((HBody -Text $FRONT.whatThisCovers.intro)) }
    foreach ($s in (AsArr $FRONT.whatThisCovers.sections)) { [void]$sb.Append((HBullet -Text $s.text)) }

    [void]$sb.Append((HHead -Text 'How you are assessed'))
    foreach ($p in (AsArr $FRONT.howYouAreAssessed)) { [void]$sb.Append((HBody -Text $p)) }

    # ---- instructions ----
    [void]$sb.Append((HBanner -Text 'Instructions to students' -PageBreakBefore))
    foreach ($b in (AsArr $FRONT.instructions)) { [void]$sb.Append((HBullet -Text $b)) }

    # ---- principles and rules of evidence ----
    [void]$sb.Append((HBanner -Text 'Principles of assessment & rules of evidence' -PageBreakBefore))
    $w = HSplitWidth -Cols 2 -Weights @(9,26)
    $rows = @(); foreach ($r in (AsArr $FRONT.principles.rows)) { $rows += ,@($r[0],$r[1]) }
    [void]$sb.Append((HTable -Headers @($FRONT.principles.headers) -Widths $w -Rows $rows -ShadeFirstCol))

    [void]$sb.Append((HHead -Text 'Rules of evidence' -Before 240))
    if (P $FRONT.rulesOfEvidence 'intro') { [void]$sb.Append((HBody -Text $FRONT.rulesOfEvidence.intro)) }
    $rows = @(); foreach ($r in (AsArr $FRONT.rulesOfEvidence.rows)) { $rows += ,@($r[0],$r[1]) }
    [void]$sb.Append((HTable -Headers @($FRONT.rulesOfEvidence.headers) -Widths $w -Rows $rows -ShadeFirstCol))

    [void]$sb.Append((HHead -Text 'Quality expected of your written responses' -Before 240))
    foreach ($p in (AsArr $FRONT.qualityExpected)) { [void]$sb.Append((HBody -Text $p)) }

    # ---- assessment conditions ----
    [void]$sb.Append((HBanner -Text 'Assessment conditions' -PageBreakBefore))
    foreach ($blk in (AsArr $FRONT.assessmentConditions)) {
        if (P $blk 'heading') { [void]$sb.Append((HHead -Text $blk.heading -Before 200 -After 60)) }
        foreach ($p in (AsArr (P $blk 'paragraphs'))) { [void]$sb.Append((HBody -Text $p)) }
        foreach ($b in (AsArr (P $blk 'bullets')))    { [void]$sb.Append((HBullet -Text $b)) }
    }

    # ---- task summary ----
    [void]$sb.Append((HBanner -Text 'Task summary' -PageBreakBefore))
    if (P $FRONT.taskSummary 'intro') { [void]$sb.Append((HBody -Text $FRONT.taskSummary.intro)) }
    $w = HSplitWidth -Cols 4 -Weights @(2,7,13,13)
    $rows = @(); foreach ($r in (AsArr $FRONT.taskSummary.rows)) { $rows += ,@($r) }
    [void]$sb.Append((HTable -Headers @($FRONT.taskSummary.headers) -Widths $w -Rows $rows))

    # ---- appendices ----
    foreach ($ap in @($FRONT.appendixA, $FRONT.appendixB)) {
        if ($null -eq $ap) { continue }
        [void]$sb.Append((HBanner -Text $ap.title -PageBreakBefore))
        if (P $ap 'intro') { [void]$sb.Append((HBody -Text $ap.intro)) }
        $hdrs = @($ap.headers)
        if ($hdrs.Count -gt 0) {
            $wts = @(); for ($i=0;$i -lt $hdrs.Count;$i++) { if ($i -eq 0) { $wts += 12 } else { $wts += 10 } }
            $ww = HSplitWidth -Cols $hdrs.Count -Weights $wts
            $rows = @(); foreach ($r in (AsArr $ap.rows)) { $rows += ,@($r) }
            [void]$sb.Append((HTable -Headers $hdrs -Widths $ww -Rows $rows -ShadeFirstCol))
        }
        if (P $ap 'afterTable') { [void]$sb.Append((HBody -Text $ap.afterTable -After 120)) }
        if (P $ap 'productionDataHeading') { [void]$sb.Append((HHead -Text $ap.productionDataHeading -Before 220)) }
        foreach ($b in (AsArr (P $ap 'productionData'))) { [void]$sb.Append((HBullet -Text $b)) }
    }

    # ---- the fifteen tasks ----
    foreach ($t in (AsArr $TASKS.tasks)) {
        [void]$sb.Append((HBanner -Text $t.heading -PageBreakBefore))
        [void]$sb.Append((HMapsBox -MapsTo $t.mapsTo -WordGuide $t.wordGuide))

        $scen = P $t 'scenario'
        if ($scen) {
            $sh = P $t 'scenarioHeading'; if (-not $sh) { $sh = 'Scenario' }
            [void]$sb.Append((HCallout -Title $sh -Lines @($scen) -RuleColor $script:ACCENT))
        }

        [void]$sb.Append((HSubHead -Text 'Question / instructions'))
        if (P $t 'stem') { [void]$sb.Append((HBody -Text $t.stem -After 100)) }

        # Benchmarks are TASK-level in the house guide: one panel after the last
        # part. The extractor hangs it off whichever part carries it, so hold it
        # and render it at the end rather than mid-task.
        $taskBench = $null
        foreach ($p0 in (AsArr $t.parts)) { if (-not $taskBench -and (P $p0 'benchmark')) { $taskBench = $p0.benchmark } }

        foreach ($p in (AsArr $t.parts)) {
            $lbl = $p.label

            # Task 9 carries its scenario INSIDE part (b), headed "Scenario for
            # part (b)". It must not float to the top of the task.
            $pScen = P $p 'scenario'
            if ($pScen) {
                $psh = P $p 'scenarioHeading'; if (-not $psh) { $psh = 'Scenario' }
                [void]$sb.Append((HCallout -Title $psh -Lines @($pScen) -RuleColor $script:ACCENT))
            }

            if ($lbl) {
                [void]$sb.Append((HPara -Runs ((HRun -Text "($lbl)  " -Bold -Color $script:NAVY) + (HRun -Text $p.text)) `
                                  -Before 140 -After 60 -Line $script:LN_ONEHALF -KeepNext))
                $respLabel = "Student response $EMD ($lbl)"
            } else {
                [void]$sb.Append((HBody -Text $p.text -After 60))
                $respLabel = 'Student response'
            }

            $model = ''
            if ($Assessor) { $model = [string](P $p 'modelAnswer') }

            if ((P $p 'responseType') -eq 'table' -and (P $p 'table')) {
                [void]$sb.Append((HSubHead -Text $respLabel -Before 60 -After 40))
                $hdrs = @($p.table.headers)
                $n = $hdrs.Count
                $wts = @(); for ($i=0;$i -lt $n;$i++) { if ($i -eq 0) { $wts += 11 } else { $wts += 13 } }
                $ww = HSplitWidth -Cols $n -Weights $wts
                $modelRows = @()
                if ($model) { $modelRows = @($model -split "`n" | Where-Object { $_.Trim() -ne '' }) }
                $rows = @(); $ri = 0
                foreach ($item in (AsArr $p.table.items)) {
                    $cells = @($item); for ($i=1;$i -lt $n;$i++) { $cells += '' }
                    if ($Assessor -and $ri -lt $modelRows.Count) {
                        $mp = $modelRows[$ri] -split '\s*\|\s*'
                        # '~~' separates points inside one answer cell; HTable
                        # renders each as its own bulleted paragraph.
                        # Column 0 is the row key printed in the learner copy.
                        # Never overwrite it - the assessor grid must line up with
                        # the student's page word for word. Only the answer
                        # columns are filled from the model.
                        for ($i=1;$i -lt $n;$i++) { if ($i -lt $mp.Count) { $cells[$i] = ($mp[$i] -replace '\s*~~\s*','||') } }
                    }
                    $rows += ,@{ cells = $cells; height = $(if ($Assessor) { 0 } else { $script:ROW_WRITE }) }
                    $ri++
                }
                $ansCol = ''; if ($Assessor) { $ansCol = $script:MODEL }
                [void]$sb.Append((HTable -Headers $hdrs -Widths $ww -Rows $rows -ShadeFirstCol -Placeholder "Write here$ELL" -AnswerColor $ansCol))
            } else {
                [void]$sb.Append((HSubHead -Text $respLabel -Before 60 -After 40))
                $ph = "Write your response to ($lbl) here$ELL"
                if (-not $lbl) { $ph = "Write your response here$ELL" }
                [void]$sb.Append((HAnswerBox -Placeholder $ph -Height 2200 -ModelAnswer $model))
            }

        }

        # One benchmark panel per task, after the last part, as the house guide has it.
        if ($Assessor -and $taskBench) {
            $secs = @()
            $sat  = Pts (P $taskBench 'satisfactory');        if (-not $sat)  { $sat  = Pts (P $taskBench 'whatSatisfactoryLooksLike') }
            $min  = Pts (P $taskBench 'minimumAcceptable');   if (-not $min)  { $min  = Pts (P $taskBench 'minimumAcceptableResponse') }
            $crit = Pts (P $taskBench 'criticalErrors')
            $key  = Pts (P $taskBench 'workedKey');           if (-not $key)  { $key  = Pts (P $taskBench 'workedAnswerKeyAndTolerance') }
            if ($sat)  { $secs += @{ label = 'Mark S when';        items = $sat } }
            if ($min)  { $secs += @{ label = 'Minimum acceptable'; items = $min } }
            if ($crit) { $secs += @{ label = 'Mark NS when';       items = $crit } }
            if ($key)  { $secs += @{ label = 'Worked key';         items = $key } }
            $ecs = P $taskBench 'exampleCommentSatisfactory'
            $ecn = P $taskBench 'exampleCommentNotSatisfactory'
            if ($ecs) { $secs += @{ label = 'Example comment - S';  text = $ecs } }
            if ($ecn) { $secs += @{ label = 'Example comment - NS'; text = $ecn } }
            $ttl = P $taskBench 'panelHeading'; if (-not $ttl) { $ttl = 'Assessor benchmark' }
            if ($secs.Count -gt 0) { [void]$sb.Append((HPanel -Title $ttl -Sections $secs)) }
        }
    }

    # ---- mapping matrix ----
    [void]$sb.Append((HBanner -Text 'Knowledge Evidence mapping matrix' -PageBreakBefore))
    if (P $FRONT.mappingMatrix 'intro') { [void]$sb.Append((HBody -Text $FRONT.mappingMatrix.intro)) }
    $w = HSplitWidth -Cols 2 -Weights @(27,8)
    $rows = @(); foreach ($r in (AsArr $FRONT.mappingMatrix.rows)) { $rows += ,@($r) }
    [void]$sb.Append((HTable -Headers @($FRONT.mappingMatrix.headers) -Widths $w -Rows $rows))

    # ---- foundation skills ----
    [void]$sb.Append((HHead -Text $FRONT.foundationSkills.heading -Before 240))
    foreach ($p in (AsArr $FRONT.foundationSkills.paragraphs)) { [void]$sb.Append((HBody -Text $p)) }

    if (P $FRONT 'closing') {
        [void]$sb.Append((HHead -Text 'End of assessment task' -Before 240))
        [void]$sb.Append((HBody -Text $FRONT.closing))
    }
    $sb.ToString()
}

# =====================================================================
#  Recipe Workbook
# =====================================================================
function Build-WorkbookBody {
    param([switch]$Assessor)
    $sb = New-Object System.Text.StringBuilder
    # RULE: the table of contents follows the version line on the title page,
    # then instructions begin the body proper.
    [void]$sb.Append((HTableOfContents))
    [void]$sb.Append((HBanner -Text 'Instructions to students' -PageBreakBefore))
    foreach ($b in (AsArr $WB.instructions)) { [void]$sb.Append((HBullet -Text $b)) }

    # Front matter runs on. Forcing a page break before every short block left
    # pages 3 and 4 nearly empty.
    [void]$sb.Append((HBanner -Text 'Principles of assessment & rules of evidence'))
    $w = HSplitWidth -Cols 2 -Weights @(9,26)
    $rows = @(); foreach ($r in (AsArr $WB.principles.rows)) { $rows += ,@($r) }
    [void]$sb.Append((HTable -Headers @($WB.principles.headers) -Widths $w -Rows $rows -ShadeFirstCol))

    # The heading names BOTH, so the document must carry both. A four-row table
    # under this heading is a claim the document does not honour, and the UAT
    # already does it correctly with two tables.
    if ($WB.PSObject.Properties.Name -contains 'rulesOfEvidence') {
        [void]$sb.Append((HHead -Text 'Rules of evidence' -Before 240))
        $rows = @(); foreach ($r in (AsArr $WB.rulesOfEvidence.rows)) { $rows += ,@($r) }
        [void]$sb.Append((HTable -Headers @($WB.rulesOfEvidence.headers) -Widths $w -Rows $rows -ShadeFirstCol))
    }

    [void]$sb.Append((HBanner -Text 'Assessment conditions'))
    foreach ($b in (AsArr $WB.assessmentConditions)) { [void]$sb.Append((HBullet -Text $b)) }

    [void]$sb.Append((HHead -Text 'Workbook purpose' -Before 240))
    foreach ($p in (AsArr $WB.workbookPurpose)) { [void]$sb.Append((HBody -Text $p)) }

    [void]$sb.Append((HHead -Text 'Current unit focus' -Before 240))
    if (P $WB.currentUnitFocus 'intro') { [void]$sb.Append((HBody -Text $WB.currentUnitFocus.intro)) }
    foreach ($b in (AsArr $WB.currentUnitFocus.bullets)) { [void]$sb.Append((HBullet -Text $b)) }

    [void]$sb.Append((HHead -Text 'How to use this workbook' -Before 240))
    foreach ($b in (AsArr $WB.howToUse)) { [void]$sb.Append((HBullet -Text $b)) }

    # ---- theory questions ----
    [void]$sb.Append((HBanner -Text 'Theory questions' -PageBreakBefore))
    foreach ($p in (AsArr (P $WB 'theoryQuestionsIntro'))) { [void]$sb.Append((HBody -Text $p)) }
    # RULE: question 1 continues under the Theory questions intro - no page left
    # over after the section heading. Every later question starts a new page.
    $qi = 0
    foreach ($q in (AsArr $WB.theoryQuestions)) {
        [void]$sb.Append((HBanner -Text $q.heading -Size 24 -PageBreakBefore:($qi -gt 0)))
        $qi++
        if (P $q 'whyThisQuestionIsHere') {
            [void]$sb.Append((HCallout -Title 'Why this question is here' -Lines @($q.whyThisQuestionIsHere) -RuleColor $script:RULE))
        }
        if (P $q 'scenario') { [void]$sb.Append((HCallout -Title 'Scenario' -Lines @($q.scenario) -RuleColor $script:ACCENT)) }
        if (P $q 'tip') {
            # The extracted value already carries its own "Tip:" label, so
            # prefixing another produced "Tip: Tip: ...". Strip it first.
            $tipTxt = ([string]$q.tip) -replace '^\s*Tip:\s*',''
            [void]$sb.Append((HPara -Runs ((HRun -Text 'Tip: ' -Bold -Color $script:NAVY) + (HRun -Text $tipTxt)) -Before 120 -After 60 -Line $script:LN_ONEHALF))
        }
        if (P $q 'minimumWords') { [void]$sb.Append((HBody -Text $q.minimumWords -After 100)) }
        foreach ($pt in (AsArr $q.parts)) {
            [void]$sb.Append((HPara -Runs ((HRun -Text "Part $($pt.number). " -Bold -Color $script:NAVY) + (HRun -Text $pt.task)) `
                              -Before 140 -After 40 -Line $script:LN_ONEHALF -KeepNext))
            $model = ''
            if ($Assessor) { $model = [string](P $pt 'modelAnswer') }
            $ph = P $pt 'responsePrompt'
            if (-not $ph) { $ph = "Write your response to Part $($pt.number) here$ELL" }
            # Size the box to what is actually being asked. 'Select one scenario'
            # is answered with a number or a name and does not need a third of a
            # page; 'Explain...' does.
            $ask = ([string]$pt.task).Trim()
            $boxH = 1800
            if     ($ask -match '^(Select|Name|State|Identify|List)\b') { $boxH = 700 }
            elseif ($ask -match '^(Explain|Describe|Justify|Discuss)\b') { $boxH = 1800 }
            elseif ($ask.Length -lt 60) { $boxH = 1000 }
            [void]$sb.Append((HAnswerBox -Placeholder $ph -Height $boxH -ModelAnswer $model))
        }
        # One benchmark panel per theory question, as the house guide has it.
        if ($Assessor) {
            $ab = P $q 'assessorBenchmark'
            if ($ab) {
                $secs = @()
                $sat  = Pts (P $ab 'whatSatisfactoryLooksLike')
                $min  = Pts (P $ab 'minimumAcceptableResponse')
                $crit = Pts (P $ab 'criticalErrors')
                $key  = Pts (P $ab 'workedAnswerKeyAndTolerance')
                if ($sat)  { $secs += @{ label = 'Mark S when';        items = $sat } }
                if ($min)  { $secs += @{ label = 'Minimum acceptable'; items = $min } }
                if ($crit) { $secs += @{ label = 'Mark NS when';       items = $crit } }
                if ($key)  { $secs += @{ label = 'Worked key';         items = $key } }
                $ecs = P $ab 'exampleCommentSatisfactory'
                $ecn = P $ab 'exampleCommentNotSatisfactory'
                if ($ecs) { $secs += @{ label = 'Example comment - S';  text = $ecs } }
                if ($ecn) { $secs += @{ label = 'Example comment - NS'; text = $ecn } }
                $ttl = P $ab 'title'; if (-not $ttl) { $ttl = 'Assessor benchmark' }
                if ($secs.Count -gt 0) { [void]$sb.Append((HPanel -Title $ttl -Sections $secs)) }
            }
        }
    }

    # ---- special request scenario table ----
    $srt = P $WB 'specialRequestTable'
    if ($srt -and (AsArr $srt.rows).Count -gt 0) {
        [void]$sb.Append((HBanner -Text 'Special customer request scenarios' -PageBreakBefore))
        $hdrs = @($srt.headers)
        # The scenario number is a single digit. Giving it a quarter of the page
        # wasted the row and pushed the text columns into narrow ribbons.
        $ww = if ($hdrs.Count -eq 4) { @(900,1900,4100,2738) } else { HSplitWidth -Cols $hdrs.Count }
        $rows = @(); foreach ($r in (AsArr $srt.rows)) { $rows += ,@{ cells=@($r); height=0 } }
        [void]$sb.Append((HTable -Headers $hdrs -Widths $ww -Rows $rows -ShadeFirstCol))
    }

    # ---- product evidence matrix ----
    [void]$sb.Append((HBanner -Text 'Product evidence matrix' -PageBreakBefore))
    if (P $WB.productEvidenceMatrix 'intro') { [void]$sb.Append((HBody -Text $WB.productEvidenceMatrix.intro)) }
    $hdrs = @($WB.productEvidenceMatrix.headers)
    $ww = HSplitWidth -Cols $hdrs.Count
    $rows = @(); foreach ($r in (AsArr $WB.productEvidenceMatrix.rows)) { $rows += ,@{ cells = @($r); height = 620 } }
    [void]$sb.Append((HTable -Headers $hdrs -Widths $ww -Rows $rows -Placeholder "Write here$ELL"))

    # ---- recipe cards ----
    # RULE: recipe 1 continues under the Recipe cards banner. Recipes 2 onward
    # each start a new page. No page is spent on the banner alone.
    [void]$sb.Append((HBanner -Text 'Recipe cards' -PageBreakBefore))
    $ri = 0
    foreach ($r in (AsArr $RECIPES.recipes)) {
        [void]$sb.Append((Render-HouseRecipe -r $r -Assessor:$Assessor -NewPage:($ri -gt 0)))
        $ri++
    }

    # ---- observation instrument ----
    $cov = P $WB 'observationInstrumentCover'
    $covHead = P $cov 'heading'; if (-not $covHead) { $covHead = 'Assessment instrument - observation of practical competency' }
    [void]$sb.Append((HBanner -Text $covHead -Size 24 -PageBreakBefore))
    if ($cov) {
        $dt = P $cov 'detailTable'
        if ($dt -and (AsArr $dt.rows).Count -gt 0) {
            $w2 = HSplitWidth -Cols 2 -Weights @(10,25)
            $rows = @(); foreach ($r in (AsArr $dt.rows)) { $rows += ,@($r) }
            [void]$sb.Append((HTable -Headers @() -Widths $w2 -Rows $rows -ShadeFirstCol))
        }
        foreach ($pair in @(@('What this instrument is','whatThisInstrumentIs'),
                            @('Instructions for the assessor','instructionsForAssessor'),
                            @('Instructions for the student','instructionsForStudent'),
                            @('How each action is marked','howMarked'))) {
            $items = AsArr (P $cov $pair[1])
            if ($items.Count -eq 0) { continue }
            [void]$sb.Append((HHead -Text $pair[0] -Before 220))
            foreach ($x in $items) { [void]$sb.Append((HBullet -Text $x)) }
        }
    }

    # RULE: observation 1 continues under the instrument cover. Observations 2
    # onward each start a new page.
    $oi = 0
    foreach ($o in (AsArr $WB.observations)) {
        [void]$sb.Append((Render-HouseObservation -o $o -Assessor:$Assessor -NewPage:($oi -gt 0)))
        $oi++
    }

    # ---- assessor records: ASSESSOR GUIDE ONLY -------------------------------
    #
    # These three are completed by the ASSESSOR. They must never appear in the
    # learner copy - printing an independent evidence record in the student's
    # book invites the student to fill it in.
    #
    # They live here rather than in a separate evidence pack because the measured
    # architecture is four documents, and this is the assessor's book.
    $ar = P $WB 'assessorRecords'
    if ($Assessor -and $ar) {
        [void]$sb.Append((HBanner -Text 'Assessor records' -PageBreakBefore -OutlineLevel 0))
        if (P $ar 'intro') { [void]$sb.Append((HBody -Text $ar.intro)) }

        # 1. Assessment conditions and assessor declaration
        $cd = P $ar 'conditions'
        if ($cd) {
            [void]$sb.Append((HHead -Text $cd.heading -Before 240))
            if (P $cd 'intro') { [void]$sb.Append((HBody -Text $cd.intro)) }
            $w = HSplitWidth -Cols 4 -Weights @(6,16,5,8)
            $rows = @(); foreach ($r in (AsArr $cd.rows)) { $rows += ,@{ cells=@($r); height=560 } }
            [void]$sb.Append((HTable -Headers @($cd.headers) -Widths $w -Rows $rows -ShadeFirstCol))
            if (P $cd 'declaration') {
                [void]$sb.Append((HSubHead -Text 'Assessor declaration' -Before 200))
                [void]$sb.Append((HBody -Text $cd.declaration))
                $w2 = @(2400,7238)
                $sig = @()
                $sig += ,@{ cells=@('Assessor name',''); height=440 }
                $sig += ,@{ cells=@('Signature','');     height=520 }
                $sig += ,@{ cells=@('Date','');          height=440 }
                [void]$sb.Append((HTable -Headers @() -Widths $w2 -Rows $sig -ShadeFirstCol))
            }
        }

        # 2. Dish production record - portion count and time constraint become auditable
        $dr = P $ar 'dishRecord'
        if ($dr) {
            [void]$sb.Append((HBanner -Text $dr.heading -Size 24 -PageBreakBefore -OutlineLevel 1))
            if (P $dr 'intro') { [void]$sb.Append((HBody -Text $dr.intro)) }
            $w = HSplitWidth -Cols 8 -Weights @(9,4,4,5,4,4,4,4)
            $rows = @(); foreach ($r in (AsArr $dr.rows)) { $rows += ,@{ cells=@($r); height=520 } }
            [void]$sb.Append((HTable -Headers @($dr.headers) -Widths $w -Rows $rows -ShadeFirstCol))
        }

        # 3. PE completion matrix - every bullet, framing sentence included
        $pm = P $ar 'peMatrix'
        if ($pm) {
            [void]$sb.Append((HBanner -Text $pm.heading -Size 24 -PageBreakBefore -OutlineLevel 1))
            if (P $pm 'intro') { [void]$sb.Append((HBody -Text $pm.intro)) }
            $w = HSplitWidth -Cols 6 -Weights @(3,15,7,4,4,3)
            $rows = @(); foreach ($r in (AsArr $pm.rows)) { $rows += ,@{ cells=@($r); height=520 } }
            [void]$sb.Append((HTable -Headers @($pm.headers) -Widths $w -Rows $rows -ShadeFirstCol))
        }
    }

    $sb.ToString()
}

function Render-HouseRecipe {
    param($r,[switch]$Assessor,[switch]$NewPage)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append((HBanner -Text ("Recipe $($r.number). $($r.name)   ($($r.code))") -PageBreakBefore:$NewPage))

    # header table - three label/value rows, photo cell merged down the right
    $w = @(1150,1500,1400,1250,4338)   # sums to 9638, the table width
    $photo = @"
<w:p><w:pPr><w:spacing w:before="200" w:after="60"/><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:i/><w:iCs/><w:color w:val="$script:ACCENT"/><w:sz w:val="$script:SZ_CELL"/></w:rPr><w:t>Insert photograph here</w:t></w:r></w:p>
"@
    function C { param([string]$t,[int]$width,[switch]$Label,[string]$Merge)
        $shd=''; $bold=$false
        if ($Label) { $shd = "<w:shd w:val=`"clear`" w:color=`"auto`" w:fill=`"$script:FILL`"/>"; $bold=$true }
        $vm=''
        if ($Merge -eq 'restart') { $vm='<w:vMerge w:val="restart"/>' } elseif ($Merge -eq 'cont') { $vm='<w:vMerge/>' }
        $inner='<w:p/>'
        if ($Merge -ne 'cont') { $inner = HPara -Runs (HRun -Text $t -Size $script:SZ_CELL -Bold:$bold) -After 20 -Line $script:LN_SINGLE }
        if ($Merge -eq 'restart') { $inner = $photo }
        "<w:tc><w:tcPr><w:tcW w:w=`"$width`" w:type=`"dxa`"/>$vm$shd<w:tcMar><w:top w:w=`"60`" w:type=`"dxa`"/><w:left w:w=`"110`" w:type=`"dxa`"/><w:bottom w:w=`"60`" w:type=`"dxa`"/><w:right w:w=`"110`" w:type=`"dxa`"/></w:tcMar><w:vAlign w:val=`"center`"/></w:tcPr>$inner</w:tc>"
    }
    $grid=''; foreach ($x in $w) { $grid += "<w:gridCol w:w=`"$x`"/>" }
    $times = "Preparation: $($r.prepTime)   Cooking: $($r.cookTime)"
    [void]$sb.Append(@"
<w:tbl><w:tblPr><w:tblW w:w="$script:CW" w:type="dxa"/><w:tblLayout w:type="fixed"/><w:tblBorders>
<w:top w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/><w:left w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/>
<w:bottom w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/><w:right w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/>
<w:insideH w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/><w:insideV w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/></w:tblBorders>
<w:tblCellMar><w:left w:w="10" w:type="dxa"/><w:right w:w="10" w:type="dxa"/></w:tblCellMar>
<w:tblLook w:val="04A0" w:firstRow="0" w:lastRow="0" w:firstColumn="0" w:lastColumn="0" w:noHBand="0" w:noVBand="1"/></w:tblPr>
<w:tblGrid>$grid</w:tblGrid>
<w:tr>$(C 'Group' $w[0] -Label)$(C $r.group $w[1])$(C 'Base / method' $w[2] -Label)$(C $r.baseMethod $w[3])$(C '' $w[4] -Merge 'restart')</w:tr>
<w:tr>$(C 'Yield' $w[0] -Label)$(C ([string]$r.yield) $w[1])$(C 'Portion size' $w[2] -Label)$(C ([string]$r.portionSize) $w[3])$(C '' $w[4] -Merge 'cont')</w:tr>
<w:tr>$(C 'Times' $w[0] -Label)$(C $times $w[1])$(C 'Recipe number' $w[2] -Label)$(C $r.code $w[3])$(C '' $w[4] -Merge 'cont')</w:tr>
</w:tbl>
"@)

    [void]$sb.Append((HCallout -Title 'Competency focus' -Lines @($r.competencyFocus, $r.evidenceTags) -RuleColor $script:RULE))

    [void]$sb.Append((HSubHead -Text 'Ingredients' -Before 180 -After 60))
    $iw = @(6338,1400,1900)
    $rows=@(); $last=''
    foreach ($ing in (AsArr $r.ingredients)) {
        $comp = [string](P $ing 'component')
        if ($comp -and $comp -ne $last) { $rows += ,@{ cells=@($comp,'',''); comp=$true }; $last=$comp }
        $rows += ,@{ cells=@($ing.ingredient, [string]$ing.qty, [string]$ing.unit) }
    }
    [void]$sb.Append((New-HouseIngredientTable -Widths $iw -Rows $rows))

    [void]$sb.Append((HSubHead -Text 'Method' -Before 180 -After 60))
    # 5. Test:, Tip: and To hold: are printed once, from the card's own fields.
    # Cards 1 to 3 carry them a second time INSIDE the method block, which made
    # the card read 'Test... Tip... Test... Tip...'. Strip them from the steps
    # and promote anything the card does not already carry.
    $steps=@(); $extraTest=''; $extraTip=''; $holdLines=@()
    foreach ($s in (AsArr $r.method)) {
        $st = ([string]$s).Trim()
        if     ($st -match '^Test:\s*(.+)$')     { if (-not $extraTest) { $extraTest = $Matches[1] } }
        elseif ($st -match '^Tip:\s*(.+)$')      { if (-not $extraTip)  { $extraTip  = $Matches[1] } }
        elseif ($st -match '^To hold:\s*(.+)$')  { $holdLines += $Matches[1] }
        else { $steps += $st }
    }
    $n=1
    foreach ($s in $steps) { [void]$sb.Append((HNumStep -N $n -Text $s)); $n++ }
    foreach ($h in $holdLines) {
        [void]$sb.Append((HPara -Runs ((HRun -Text 'To hold: ' -Bold -Color $script:NAVY) + (HRun -Text $h)) -Before 100 -After 60 -Line $script:LN_ONEHALF))
    }
    $cardTest = [string](P $r 'test'); if (-not $cardTest) { $cardTest = $extraTest }
    $cardTest = $cardTest -replace '^\s*Test:\s*',''
    $cardTip  = [string](P $r 'tip');  if (-not $cardTip)  { $cardTip  = $extraTip }
    $cardTip  = $cardTip  -replace '^\s*Tip:\s*',''
    if ($cardTest) { [void]$sb.Append((HPara -Runs ((HRun -Text 'Test: ' -Bold -Color $script:NAVY) + (HRun -Text $cardTest)) -Before 120 -After 60 -Line $script:LN_ONEHALF)) }
    if ($cardTip)  { [void]$sb.Append((HPara -Runs ((HRun -Text 'Tip: '  -Bold -Color $script:NAVY) + (HRun -Text $cardTip))  -Before 60  -After 60 -Line $script:LN_ONEHALF)) }

    [void]$sb.Append((HSubHead -Text 'Storage and presentation' -Before 140 -After 60))
    foreach ($b in (AsArr $r.storage)) { [void]$sb.Append((HBullet -Text $b)) }
    if (P $r 'presentationStandard') {
        [void]$sb.Append((HPara -Runs ((HRun -Text 'Presentation standard: ' -Bold -Color $script:NAVY) + (HRun -Text $r.presentationStandard)) -Before 120 -After 120 -Line $script:LN_ONEHALF))
    }
    if ($Assessor -and (P $r 'assessorNotes')) {
        [void]$sb.Append((HCallout -Title 'Assessor notes' -Lines @([string]$r.assessorNotes) -Fill 'FFF2CC' -RuleColor $script:RULE))
    }
    $sb.ToString()
}

# ingredients table with component sub-heading rows spanning the full width
function New-HouseIngredientTable {
    param([int[]]$Widths,[array]$Rows)
    $grid=''; foreach($x in $Widths){$grid+="<w:gridCol w:w=`"$x`"/>"}
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append(@"
<w:tbl><w:tblPr><w:tblW w:w="$script:CW" w:type="dxa"/><w:tblLayout w:type="fixed"/><w:tblBorders>
<w:top w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/><w:left w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/>
<w:bottom w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/><w:right w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/>
<w:insideH w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/><w:insideV w:val="single" w:sz="4" w:space="0" w:color="$script:BORD"/></w:tblBorders>
<w:tblCellMar><w:left w:w="10" w:type="dxa"/><w:right w:w="10" w:type="dxa"/></w:tblCellMar>
<w:tblLook w:val="04A0" w:firstRow="1" w:lastRow="0" w:firstColumn="0" w:lastColumn="0" w:noHBand="0" w:noVBand="1"/></w:tblPr>
<w:tblGrid>$grid</w:tblGrid>
<w:tr><w:trPr><w:tblHeader/></w:trPr>
"@)
    foreach ($h in @('Ingredient','Qty','Unit')) {
        $i = [array]::IndexOf(@('Ingredient','Qty','Unit'), $h)
        $p = HPara -Runs (HRun -Text $h -Bold -Color 'FFFFFF' -Size $script:SZ_CELL) -KeepNext -Before 20 -After 20 -Line $script:LN_SINGLE
        [void]$sb.Append("<w:tc><w:tcPr><w:tcW w:w=`"$($Widths[$i])`" w:type=`"dxa`"/><w:shd w:val=`"clear`" w:color=`"auto`" w:fill=`"$script:NAVY`"/><w:tcMar><w:top w:w=`"50`" w:type=`"dxa`"/><w:left w:w=`"110`" w:type=`"dxa`"/><w:bottom w:w=`"50`" w:type=`"dxa`"/><w:right w:w=`"110`" w:type=`"dxa`"/></w:tcMar></w:tcPr>$p</w:tc>")
    }
    [void]$sb.Append('</w:tr>')
    foreach ($row in $Rows) {
        $isComp = ($row.ContainsKey('comp') -and $row['comp'])
        [void]$sb.Append('<w:tr>')
        if ($isComp) {
            $p = HPara -Runs (HRun -Text $row['cells'][0] -Bold -Color $script:NAVY -Size $script:SZ_CELL) -KeepNext -Before 20 -After 20 -Line $script:LN_SINGLE
            $tot=0; foreach($x in $Widths){$tot+=$x}
            [void]$sb.Append("<w:tc><w:tcPr><w:tcW w:w=`"$tot`" w:type=`"dxa`"/><w:gridSpan w:val=`"$($Widths.Count)`"/><w:shd w:val=`"clear`" w:color=`"auto`" w:fill=`"$script:FILL`"/><w:tcMar><w:top w:w=`"50`" w:type=`"dxa`"/><w:left w:w=`"110`" w:type=`"dxa`"/><w:bottom w:w=`"50`" w:type=`"dxa`"/><w:right w:w=`"110`" w:type=`"dxa`"/></w:tcMar></w:tcPr>$p</w:tc>")
        } else {
            for ($i=0;$i -lt $Widths.Count;$i++) {
                $t = [string]$row['cells'][$i]
                $p = HPara -Runs (HRun -Text $t -Size $script:SZ_CELL) -After 20 -Line $script:LN_SINGLE
                [void]$sb.Append("<w:tc><w:tcPr><w:tcW w:w=`"$($Widths[$i])`" w:type=`"dxa`"/><w:tcMar><w:top w:w=`"50`" w:type=`"dxa`"/><w:left w:w=`"110`" w:type=`"dxa`"/><w:bottom w:w=`"50`" w:type=`"dxa`"/><w:right w:w=`"110`" w:type=`"dxa`"/></w:tcMar></w:tcPr>$p</w:tc>")
            }
        }
        [void]$sb.Append('</w:tr>')
    }
    [void]$sb.Append('</w:tbl>')
    $sb.ToString()
}

function Render-HouseObservation {
    param($o,[switch]$Assessor,[switch]$NewPage)
    $sb = New-Object System.Text.StringBuilder

    # The learner heading is "Observation N" TAB "Element title" - confirmed at
    # byte level in the source. Reproduce the tab, not an em dash.
    $head = P $o 'headingForm'
    if (-not $head) { $head = "Observation $($o.number)`t$($o.elementTitle)" }
    [void]$sb.Append((HBanner -Text $head -Size 24 -PageBreakBefore:$NewPage))
    if (P $o 'elementLine') { [void]$sb.Append((HBody -Text $o.elementLine -After 100)) }

    # FOUR columns. The per-row "Assessor notes" column is dropped: a 3 cm
    # column repeated down 74 rows is unwritable, and the assessor only needs
    # one place to write. One notes box closes the sheet instead.
    $hdrs = @('PC','The student did this','S','NS')
    $w    = @(700,6538,1100,1300)
    $rows=@()
    foreach ($r in (AsArr $o.rows)) { $rows += ,@{ cells=@($r.pc, $r.action, '', ''); height = 560 } }
    [void]$sb.Append((HTable -Headers $hdrs -Widths $w -Rows $rows))

    # One assessor notes box, then the result and the sign-and-date row, at the
    # foot of the sheet.
    [void]$sb.Append((HSubHead -Text 'Assessor notes' -Before 140 -After 40))
    [void]$sb.Append((HAnswerBox -Placeholder '' -Height 1500))

    $cb = P $o 'closingBlocks'
    $label = 'Result for this observation'
    $val   = 'Satisfactory     /     Not satisfactory'
    if ($cb) {
        if (P $cb 'resultRowLabel') { $label = $cb.resultRowLabel }
        if (P $cb 'resultRow')      { $val   = $cb.resultRow }
    }
    $w2 = @(2400,7238)
    $closeRows = @()
    $closeRows += ,@{ cells=@($label,$val); height=440 }
    $closeRows += ,@{ cells=@('Trainer signature',''); height=520 }
    $closeRows += ,@{ cells=@('Date',''); height=440 }
    [void]$sb.Append((HTable -Headers @() -Widths $w2 -Rows $closeRows -ShadeFirstCol))

    if ($Assessor) {
        $oi = P $o 'observableIndicators'
        if ($oi) {
            $ttl = P $oi 'title'; if (-not $ttl) { $ttl = "Observable indicators - Observation $($o.number)" }
            [void]$sb.Append((HSubHead -Text $ttl -Before 200 -After 60))
            [void]$sb.Append((HIndicatorTable -Satisfactory (Pts (P $oi 'satisfactory')) `
                                              -NotSatisfactory (Pts (P $oi 'notSatisfactory'))))
            $ecs = P $oi 'exampleCommentSatisfactory'
            $ecn = P $oi 'exampleCommentNotSatisfactory'
            $secs = @()
            if ($ecs) { $secs += @{ label = 'Example comment - S';  text = $ecs } }
            if ($ecn) { $secs += @{ label = 'Example comment - NS'; text = $ecn } }
            if ($secs.Count -gt 0) { [void]$sb.Append((HPanel -Title '' -Sections $secs)) }
        }
    }
    $sb.ToString()
}

# =====================================================================
#  splice and write
# =====================================================================
function Write-HouseDocx {
    param([string]$OutPath,[string]$BodyXml,[string]$DocName,[string]$Kind,[string]$DocNumber,[switch]$Assessor)

    $b    = Get-Branding -Brand MVC
    $work = Expand-Docx -Path (Get-TemplatePath -Branding $b -Kind $Kind)
    $part = 'word/document.xml'
    $doc  = Get-DocxPart -WorkDir $work -Part $part

    if ($Kind -eq 'uat') {
        $sec = @(); foreach ($m in [regex]::Matches($doc,'<w:sectPr')) { $sec += $m.Index }
        if ($sec.Count -lt 3) { throw "Expected 3 sectPr, found $($sec.Count)" }
        $close = $doc.IndexOf('</w:p>', $sec[1])
        $prefix = $doc.Substring(0, $close + 6)
        $suffix = $doc.Substring($sec[2])
    } else {
        $anchor = $doc.IndexOf('Instructions to students')
        $pStart = $doc.LastIndexOf('<w:p ', $anchor)
        $prefix = $doc.Substring(0, $pStart)
        $suffix = $doc.Substring($doc.LastIndexOf('<w:sectPr'))
    }

    # RULE: no colour band on any document. The RTO does not want the coloured
    # rule above the ASSESSMENT wordmark anywhere in the pack.

    # The 'Administration: Rec'd / Date:' row is an internal receipting field
    # that does not belong on a learner cover sheet.
    if ($Kind -eq 'recipeWorkbook') { $prefix = Remove-RowContaining -Xml $prefix -Text 'Administration' }

    # RULE: 14 days late submission and 14 days for results, on every cover
    # sheet. The recipe template shipped 15 and 45.
    $prefix = $prefix.Replace('results within 45 days','results within 14 days')
    $prefix = $prefix.Replace('within 15 days of receipt','within 14 days of receipt')
    $prefix = $prefix.Replace('by 15 days of receiving it','by 14 days of receiving it')

    if ($Assessor) { $BodyXml = (HAssessorBanner) + $BodyXml }

    Set-DocxPart -WorkDir $work -Part $part -Content ($prefix + $BodyXml + $suffix)

    $repl = @{
        '[Unit code]'                   = 'SITHPAT018'
        '[Unit title]'                  = 'Produce chocolate confectionery'
        '[Qualification code and title]'= 'SIT40721 Certificate IV in Patisserie'
        '[Release / version]'           = 'Release 1'
        '[AQF level]'                   = 'Certificate IV (AQF Level 4)'
        'Release [n]'                   = 'Release 1'
        '[ Insert photograph here ]'    = 'Insert a themed chocolate photograph here'
    }
    foreach ($k in $repl.Keys) {
        $n = Test-DocxTextPresent -WorkDir $work -Part $part -Text $k
        if ($n -gt 0) { Invoke-DocxTextReplace -WorkDir $work -Part $part -Find $k -Replace $repl[$k] -Expected $n }
    }

    # Cover sheet: pre-fill Qualification and Unit Code & Name, as the house
    # artefact does. The template ships them blank. Each label sits in its own
    # cell; the value belongs in the next cell along, which the template leaves
    # as a bare empty paragraph.
    $doc2 = Get-DocxPart -WorkDir $work -Part $part
    foreach ($fill in @(@('Qualification:','SIT40721 Certificate IV in Patisserie'),
                        @('Unit Code &amp; Name:','SITHPAT018 Produce chocolate confectionery'))) {
        $lbl = $fill[0]; $val = $fill[1]
        $li = $doc2.IndexOf("<w:t>$lbl</w:t>")
        if ($li -lt 0) { Write-Host "  cover-sheet label not found: $lbl"; continue }
        $cellEnd = $doc2.IndexOf('</w:tc>', $li)
        $nextOpen = $doc2.IndexOf('<w:tc>', $cellEnd)
        $nextOpenA = $doc2.IndexOf('<w:tc ', $cellEnd)
        if ($nextOpenA -ge 0 -and ($nextOpen -lt 0 -or $nextOpenA -lt $nextOpen)) { $nextOpen = $nextOpenA }
        if ($nextOpen -lt 0) { continue }
        $nextEnd = $doc2.IndexOf('</w:tc>', $nextOpen)
        $cell = $doc2.Substring($nextOpen, $nextEnd - $nextOpen)

        # Only fill an EMPTY cell. The recipe template already pre-fills the unit
        # from its own [Unit code] [Unit title] placeholder, so writing again
        # printed the unit name twice.
        $existing = -join ([regex]::Matches($cell,'<w:t[^>]*>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value })
        if ($existing.Trim()) { Write-Host "  cover sheet already filled, skipped: $lbl"; continue }

        $para = HPara -Runs (HRun -Text $val -Size $script:SZ_CELL)
        if ($cell -match '<w:p/>') {
            $newCell = ($cell -replace '<w:p/>', $para)
        } else {
            $newCell = $cell + $para
        }
        $doc2 = $doc2.Substring(0,$nextOpen) + $newCell + $doc2.Substring($nextEnd)
        Write-Host "  cover sheet pre-filled: $lbl"
    }
    Set-DocxPart -WorkDir $work -Part $part -Content $doc2

    Set-DocControl -WorkDir $work -Branding $b -DocNumber $DocNumber -DocName $DocName -Revision '1.0'
    Assert-DocxPackage -WorkDir $work
    Compress-Docx -WorkDir $work -Path $OutPath
    "Wrote $OutPath"
}

New-Item -ItemType Directory -Force "$Root\out-house" | Out-Null
Write-HouseDocx -OutPath "$Root\out-house\SITHPAT018_UAT1_Knowledge.docx" `
                -BodyXml (Build-UAT1Body) -DocName 'SITHPAT018_UAT1_Knowledge' -Kind 'uat' -DocNumber '4518'
Write-HouseDocx -OutPath "$Root\out-house\Assessor_Guide_SITHPAT018_UAT1_Knowledge.docx" `
                -BodyXml (Build-UAT1Body -Assessor) -DocName 'Assessor_Guide_SITHPAT018_UAT1_Knowledge' -Kind 'uat' -DocNumber '4520' -Assessor
Write-HouseDocx -OutPath "$Root\out-house\SITHPAT018_Recipe_Workbook.docx" `
                -BodyXml (Build-WorkbookBody) -DocName 'SITHPAT018_Recipe_Workbook' -Kind 'recipeWorkbook' -DocNumber '4519'
Write-HouseDocx -OutPath "$Root\out-house\Assessor_Guide_SITHPAT018_Recipe_Workbook.docx" `
                -BodyXml (Build-WorkbookBody -Assessor) -DocName 'Assessor_Guide_SITHPAT018_Recipe_Workbook' -Kind 'recipeWorkbook' -DocNumber '4521' -Assessor

"Tasks: $((AsArr $TASKS.tasks).Count)  Recipes: $((AsArr $RECIPES.recipes).Count)  Observations: $((AsArr $WB.observations).Count)  Theory questions: $((AsArr $WB.theoryQuestions).Count)"
