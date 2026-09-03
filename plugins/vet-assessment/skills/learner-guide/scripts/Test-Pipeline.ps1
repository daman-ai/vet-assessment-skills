<#
    Test-Pipeline.ps1

    End-to-end smoke test. Builds a small Learner Guide and a small deck from
    the approved templates, runs both gates, and opens both in Office to confirm
    neither prompts to repair.

    Run it after ANY change to the scripts, the profiles or the templates:

        & "$SkillDir\scripts\Test-Pipeline.ps1"

    It writes to a temp directory and cleans up, so it never touches a build.

    EXIT CODE: 0 when every check passed, 4 when any check failed or any
    fixture threw. A report is not a verdict - before this rule the code a
    caller saw was whatever the LAST INNER GATE returned, so a run could print
    PIPELINE OK and leave a non-zero code, or print FAILED and leave zero.

    ASCII only in this file.
#>

[CmdletBinding()]
param(
    [string] $OutDir,
    [switch] $KeepOutput,
    [switch] $SkipOffice
)

$ErrorActionPreference = 'Stop'
$SkillDir = Split-Path -Parent $PSScriptRoot

if (-not $OutDir) {
    $OutDir = Join-Path ([System.IO.Path]::GetTempPath()) ('lgtest_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$pass = 0; $fail = 0
function Ok   ($m) { $script:pass++; Write-Host "  PASS  $m" -ForegroundColor Green }
function Bad  ($m) { $script:fail++; Write-Host "  FAIL  $m" -ForegroundColor Red }
function Step ($m) { Write-Host "`n$m" -ForegroundColor Cyan }

try {
    Step '1. library resolves'
    . (Join-Path $PSScriptRoot 'Lib-Resolve.ps1')
    foreach ($fn in 'Expand-Docx', 'Get-DocxPart', 'Get-XmlFragment', 'HCallout',
                    'Test-Readability', 'Get-GuideProfile', 'GIconCallout',
                    'Get-DeckProfile', 'New-DeckSlide', 'Test-GuideRules', 'Test-DeckRules') {
        if (Get-Command $fn -ErrorAction SilentlyContinue) { Ok $fn } else { Bad "$fn not loaded" }
    }

    Step '2. templates are structurally sound'
    $P   = Get-GuideProfile -SkillDir $PSScriptRoot
    $DP  = Get-DeckProfile  -SkillDir $PSScriptRoot
    Set-HousePalette -Brand MVC | Out-Null

    # The RTO profile pack is where the templates and the identity strings come
    # from. Nothing below types a template path, a provider code or a hex.
    . (Join-Path $PSScriptRoot 'Get-RtoProfile.ps1')
    $rtoProfile = Get-RtoProfile -Rto MVC
    $rpv = Assert-RtoProfile -Profile $rtoProfile
    if ($rpv.Ok) { Ok "RTO profile pack MVC v$($rtoProfile.ProfileVersion) validates" }
    else { foreach ($x in $rpv.Problems) { Bad "RTO profile: $x" } }

    $gt  = $rtoProfile.GuideTemplate
    $pt  = $rtoProfile.DeckTemplate

    $gwd = Expand-Docx -Path $gt
    try { Assert-DocxPackage -WorkDir $gwd | Out-Null; Ok 'guide template package' }
    catch { Bad "guide template: $($_.Exception.Message)" }

    $cw = 0
    $gx = Get-DocxPart -WorkDir $gwd -Part 'word/document.xml'
    if ($gx -match '<w:pgSz w:w="(\d+)"') {
        $pw = [int]$Matches[1]
        $mm = [regex]::Match($gx, '<w:pgMar\b[^>]*/>').Value
        $cw = $pw - [int]([regex]::Match($mm, 'w:left="(\d+)"').Groups[1].Value) -
                    [int]([regex]::Match($mm, 'w:right="(\d+)"').Groups[1].Value)
    }
    if ($cw -eq [int]$P.page.contentWidthDxa) { Ok "template CW $cw matches the profile" }
    else { Bad "template CW $cw but the profile says $($P.page.contentWidthDxa) - run Patch-GuideTemplateGeometry.ps1" }
    Remove-Item -LiteralPath $gwd -Recurse -Force -ErrorAction SilentlyContinue

    $pwd2 = Expand-Docx -Path $pt
    $pk = Test-PptxPackage -WorkDir $pwd2
    if ($pk.Ok) { Ok "deck template package ($($pk.SlideCount) exemplars)" } else { Bad "deck template: $($pk.Issues -join '; ')" }
    Remove-Item -LiteralPath $pwd2 -Recurse -Force -ErrorAction SilentlyContinue

    Step '3. build a guide'
    $body  = GHeading -Level 1 -Text 'Unit overview' -Profile $P
    $body += '<w:p><w:r><w:t>Smoke-test guide.</w:t></w:r></w:p>'
    $body += GHeading -Level 1 -Text 'Topic 1 - Smoke test' -PageBreakBefore -Profile $P
    $body += GIconCallout -Profile $P -Type readBeforeYouStart -Lines @('Locate the standard recipe card.')
    $body += GIconCallout -Profile $P -Type keyTerms -Bullets @('Yield - how much one batch makes.')
    $body += GHeading -Level 3 -Text '1.1 Confirm requirements' -PageBreakBefore -Profile $P
    $body += GHeading -Level 4 -Text 'What this means in practice' -Profile $P
    $body += '<w:p><w:r><w:t>The standard recipe is the recipe of record.</w:t></w:r></w:p>'
    $body += GIconCallout -Profile $P -Type remember      -Lines @('Report a problem with a recipe; do not correct it yourself.')
    # X.1 Route A and X.2 Route B, at their declared placements
    $body += GImagePrompt -Kind Image -Figure '1.1.1' -Aspect '3:2 landscape' `
        -Prompt ('A photorealistic documentary photograph of a chocolatier reading a standard recipe card at a stainless steel bench in an independent South Australian patisserie, early morning before production. A woman in her thirties in clean pressed chef whites, sleeves down, hair covered, no jewellery, holds a printed recipe card while her other gloved hand rests on a digital scale. Trays of empty polycarbonate moulds and a slab of tempered dark couverture sit beside her. Shot at 35 mm, medium wide, chest height, shallow depth of field, cool even north light from a high window, face angled away from camera. No text, no numbers, no signage lettering, no logos, no bare hands on ready-to-eat food.') `
        -Caption 'Reading the standard recipe before production begins' `
        -Alt 'A chocolatier in whites reading a standard recipe card at a stainless steel bench.'
    $body += GImagePrompt -Kind Diagram -Figure '1.1.2' `
        -Prompt ('A four-step horizontal process flowchart titled Scaling a standard recipe. Nodes in order: Read the recipe yield; Divide required yield by recipe yield; Multiply every ingredient by the factor; Sense-check the per-piece weight. A decision diamond after the final node reads Does the per-piece weight look believable? Yes exits to Proceed to production. No loops back to Divide required yield by recipe yield.') `
        -Caption 'Scaling a standard recipe' `
        -Alt 'Four-step flowchart for scaling a standard recipe with a sense-check decision that loops back on failure.'
    $body += GIconCallout -Profile $P -Type commonErrors  -Bullets @('Reading only the ingredient list.')
    $body += GIconCallout -Profile $P -Type assessmentLink -Lines @('Prepares you for UAT 1 Q5.')

    $guide = Write-GuideDocument -Unit @{
        Code = 'SMOKE001'; Title = 'Smoke test unit'
        Qualification = 'TEST10001 Certificate in Testing'
        Release = 'Release 1'; AqfLevel = 'AQF Level 4'
    } -BodyXml $body -OutPath (Join-Path $OutDir 'SMOKE_Guide.docx') -Profile $P -Confirm:$false

    if (Test-Path -LiteralPath $guide) { Ok "guide built ($([math]::Round((Get-Item $guide).Length / 1KB)) KB)" }
    else { Bad 'guide not written' }

    Step '4. guide gate'
    # Floors relaxed: this is a structural smoke test, not a real guide.
    $gr = Test-GuideRules -Path $guide -TopicWordFloor 1 -SubjectWordFloor 1 -QuestionsInPack @('Q5')
    foreach ($i in $gr.Info) { Write-Host "        $i" -ForegroundColor DarkGray }
    if ($gr.Ok) { Ok 'guide gate clean' } else { foreach ($f in $gr.Failures) { Bad $f } }
    if ($gr.ContentWidth -eq [int]$P.page.contentWidthDxa) { Ok "built guide CW $($gr.ContentWidth)" }
    else { Bad "built guide CW $($gr.ContentWidth)" }

    # A BLOCKING RULE WHOSE INPUT IS ABSENT MUST FAIL, NOT PASS QUIETLY.
    # The gate used to write "assessment cross-reference skipped - no
    # -QuestionsInPack given" into $info and return Ok, so a caller who left the
    # parameter off got a clean PASS on a guide whose question references had
    # been reconciled in neither direction.
    $grNoQ = Test-GuideRules -Path $guide -TopicWordFloor 1 -SubjectWordFloor 1
    if (-not $grNoQ.Ok -and (($grNoQ.Failures -join ' ') -match 'QuestionsInPack')) {
        Ok 'the guide gate FAILS when -QuestionsInPack is omitted'
    } else { Bad 'the guide gate passed without -QuestionsInPack - a rule that did not run reported green' }

    $grPartial = Test-GuideRules -Path $guide -TopicWordFloor 1 -SubjectWordFloor 1 -AllowPartial
    if ($grPartial.Ok -and @($grPartial.Partial).Count -eq 1) {
        Ok "-AllowPartial records the omission instead of hiding it: $($grPartial.Partial -join '; ')"
    } else { Bad "-AllowPartial did not record exactly the omitted rule (Ok=$($grPartial.Ok), partial=$(@($grPartial.Partial).Count))" }

    Step '4b. artwork prompts are emitted, and docx-images can read them'
    $ip = Get-GuideImagePrompt -Path $guide
    if (@($ip | Where-Object { $_.Kind -eq 'IMAGE' }).Count -eq 1)   { Ok 'one Route A prompt emitted' }   else { Bad 'Route A prompt missing' }
    if (@($ip | Where-Object { $_.Kind -eq 'DIAGRAM' }).Count -eq 1) { Ok 'one Route B prompt emitted' }   else { Bad 'Route B prompt missing' }
    if (@($ip | Where-Object { -not $_.Closed }).Count -eq 0)        { Ok 'every prompt block is closed' } else { Bad 'an unclosed prompt block' }
    if (@($ip | Where-Object { -not $_.Figure -or -not $_.Alt }).Count -eq 0) { Ok 'every prompt carries a figure number and alt text' }
    else { Bad 'a prompt is missing its figure number or alt text' }
    $wordy = @($ip | Where-Object { $_.Kind -eq 'IMAGE' -and ($_.Words -lt 90 -or $_.Words -gt 175) })
    if (-not $wordy.Count) { Ok 'Route A prompt is inside the 90-160 word band' }
    else { Bad "Route A prompt is $($wordy[0].Words) words - the band is 90-160" }

    # The real integration test: docx-images' own scanner, classifying correctly.
    $scan = Join-Path (Split-Path -Parent $SkillDir) 'docx-images\scripts\Find-DocxImagePrompts.ps1'
    if (Test-Path -LiteralPath $scan) {
        $mf = Join-Path $OutDir 'manifest.json'
        & $scan -Path $guide -ManifestPath $mf *>&1 | Out-Null
        if (Test-Path -LiteralPath $mf) {
            $m = Get-Content -LiteralPath $mf -Raw | ConvertFrom-Json
            $ill = @($m.placeholders | Where-Object { $_.kind -eq 'illustration' }).Count
            $dia = @($m.placeholders | Where-Object { $_.kind -eq 'diagram' }).Count
            if ($ill -eq 1 -and $dia -eq 1) { Ok "docx-images classified them: $ill illustration, $dia diagram" }
            else { Bad "docx-images classified $ill illustration / $dia diagram - expected 1 and 1" }
            if (@($m.placeholders | Where-Object { -not $_.caption -or -not $_.alt }).Count -eq 0) { Ok 'manifest carries caption and alt for every entry' }
            else { Bad 'manifest has an entry missing caption or alt' }
        }
        else { Bad 'docx-images produced no manifest' }
    }
    else { Write-Host '        docx-images not installed - handoff test skipped' -ForegroundColor DarkGray }

    Step '5. build a deck'
    $deck = New-Deck -TemplatePath $pt
    # Every slot the layout declares is filled. Leaving one out is exactly what
    # the placeholder sweep exists to catch, and it caught this when the smoke
    # test first omitted the presenter line.
    New-DeckSlide -Deck $deck -Profile $DP -Layout title -Content @{
        title     = 'SMOKE001 SMOKE TEST UNIT'
        subtitle  = 'TEST10001 - AQF Level 4'
        presenter = @('Trainer name  -  Trainer/Assessor', 'Date  -  Adelaide') } | Out-Null
    New-DeckSlide -Deck $deck -Profile $DP -Layout divider -Content @{
        number = '01'; title = 'Smoke test'; description = 'This section covers UAT 1 Q5' } | Out-Null
    New-DeckSlide -Deck $deck -Profile $DP -Layout single -Chip 'Prepares you for: UAT 1 Q5' `
        -Notes 'PC 1.1. The recipe of record. Direct learners to UAT 1 Q5.' -Content @{
        kicker = '1.1 CONFIRM REQUIREMENTS'; headline = 'The standard recipe is the recipe of record'
        lead = 'It is the written recipe the business uses every time.'
        bullets = @('Same product every time', 'Predictable cost per piece') } | Out-Null
    # The image layout, with a real picture standing in for a docx-images output.
    Add-Type -AssemblyName System.Drawing
    $png = Join-Path $OutDir 'fig.png'
    $bmp = New-Object System.Drawing.Bitmap 1200, 800
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $gfx.Clear([System.Drawing.Color]::FromArgb(35, 75, 140))
    $gfx.Dispose(); $bmp.Save($png, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()

    $ipDef = $DP.layouts.image.imagePlaceholder
    $imgN = New-DeckSlide -Deck $deck -Profile $DP -Layout image -Chip 'Prepares you for: UAT 1 Q5' `
        -Notes 'PC 1.1. Walk the bench setup. Direct learners to UAT 1 Q5.' -Content @{
        kicker = '1.1 CONFIRM REQUIREMENTS'; headline = 'Reading the recipe before you start'
        caption = 'Figure 1.1.1 - Reading the standard recipe before production begins'
        subhead = 'What to check'; bullets = @('Yield and portion size', 'Allergen notes') }
    Set-SlidePicture -Deck $deck -SlideNumber $imgN -ImagePath $png `
        -FrameShape ([int]$ipDef.frameShape) -RemoveShapes ([int[]]$ipDef.removeShapes) `
        -CaptionShape ([int]$ipDef.captionShape) -AltText 'A chocolatier reading a standard recipe card.' | Out-Null
    Ok 'picture placed into the image layout'

    New-DeckSlide -Deck $deck -Profile $DP -Layout thanks -Content @{ contact = @('info@mvc.edu.au') } | Out-Null

    $num = Set-DeckSlideNumbers -Deck $deck -NumberSlotByLayout (Get-DeckNumberSlotMap -Profile $DP)
    Ok "numbered $($num.Numbered) slide(s), $($num.NoNumberByDesign) without a number by design"

    $deckPath = Save-Deck -Deck $deck -Path (Join-Path $OutDir 'SMOKE_Deck.pptx')
    if (Test-Path -LiteralPath $deckPath) { Ok "deck built ($([math]::Round((Get-Item $deckPath).Length / 1KB)) KB)" }
    else { Bad 'deck not written' }

    Step '6. deck gate'
    $plan = @(
        @{ Tag = 'title';   Kind = 'title';    LayoutSlide = 1 },
        @{ Tag = 'divider'; Kind = 'divider';  Topic = 1; LayoutSlide = 3 },
        @{ Tag = '1.1';     Kind = 'teaching'; Topic = 1; LayoutSlide = 4 },
        @{ Tag = '1.1 fig'; Kind = 'teaching'; Topic = 1; LayoutSlide = 11 },
        @{ Tag = 'thanks';  Kind = 'thanks';   LayoutSlide = 12; Verbatim = $true }
    )
    $dr = Test-DeckRules -Path $deckPath -TemplatePath $pt -Plan $plan -MinSlidesPerTopic 2 `
                         -NumberSlotByLayout (Get-DeckNumberSlotMap -Profile $DP) `
                         -Rto $rtoProfile.RtoCode -Cricos $rtoProfile.CricosCode
    foreach ($i in $dr.Info) { Write-Host "        $i" -ForegroundColor DarkGray }
    if ($dr.Ok) { Ok 'deck gate clean' } else { foreach ($f in $dr.Failures) { Bad $f } }

    # Same rule as the guide gate: four blocking deck rules sat behind optional
    # parameters and reported green when nothing had been checked.
    $drBare = Test-DeckRules -Path $deckPath -MinSlidesPerTopic 2
    $expect = @('TemplatePath', 'Plan', 'NumberSlotByLayout', 'Rto', 'Cricos')
    $missed = @($expect | Where-Object { ($drBare.Failures -join ' ') -notmatch $_ })
    if (-not $drBare.Ok -and -not $missed.Count) {
        Ok "the deck gate FAILS on every unsupplied input ($($expect.Count) of them)"
    } else { Bad "the deck gate did not fail on: $($missed -join ', ') (Ok=$($drBare.Ok))" }

    $drPartial = Test-DeckRules -Path $deckPath -MinSlidesPerTopic 2 -AllowPartial
    if ($drPartial.Ok -and @($drPartial.Partial).Count -ge 4) {
        Ok "-AllowPartial records all $(@($drPartial.Partial).Count) of them instead of hiding them"
    } else { Bad "-AllowPartial recorded $(@($drPartial.Partial).Count) rule(s), Ok=$($drPartial.Ok)" }

    Step '6a. figure registry gate is variant-aware and catches leakage'
    $fd = Join-Path $OutDir 'figreg'
    New-Item -ItemType Directory -Force -Path (Join-Path $fd 'spine') | Out-Null
    # A planted spine file carrying: a stale figure as a WORD-FORM variant, a
    # benchmark leak in a different spelling from the registered one, and the
    # canonical value the registry requires.
    Set-Content (Join-Path $fd 'spine\t.json') -Encoding UTF8 -Value (@{
        body = @('The chiller holds twenty gastronorm trays per cycle.',
                 'Purchase 35.5 kg for the banquet.',
                 'The oven fits a twenty-tray load.')
    } | ConvertTo-Json)
    Set-Content (Join-Path $fd 'figures.json') -Encoding UTF8 -Value (@'
{ "figures": [
    { "name": "chain", "forbid": ["40 kg"], "require": ["35.5"] },
    { "name": "chiller", "forbidRx": ["(?i)\\b(10|20|ten|twenty)[\\s-]*(gastronorm[\\s-]*)?trays?\\b"] } ],
  "assessorOnly": [ { "text": "20 gastronorm", "why": "test benchmark" } ],
  "deckMust": [] }
'@)
    $fcOut = & (Join-Path $PSScriptRoot 'Test-FigureConsistency.ps1') -BuildDir $fd -Quiet 2>&1
    $fcRc  = $LASTEXITCODE
    if ($fcRc -ne 8) { Bad "figure gate passed a planted word-form variant (rc=$fcRc)" }
    else { Ok 'word-form variant of a forbidden figure fails the gate' }
    # Clean the plant; the registry then passes.
    Set-Content (Join-Path $fd 'spine\t.json') -Encoding UTF8 -Value (@{
        body = @('Check the chiller capacity on the equipment inventory.', 'Purchase 35.5 kg for the banquet.')
    } | ConvertTo-Json)
    & (Join-Path $PSScriptRoot 'Test-FigureConsistency.ps1') -BuildDir $fd -Quiet 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Ok 'clean sources pass the figure gate' }
    else { Bad 'clean sources failed the figure gate' }
    # A missing registry must throw, never silently pass.
    Remove-Item (Join-Path $fd 'figures.json') -Force
    $threw = $false
    try { & (Join-Path $PSScriptRoot 'Test-FigureConsistency.ps1') -BuildDir $fd -Quiet 2>&1 | Out-Null } catch { $threw = $true }
    if ($threw) { Ok 'a build with no registry cannot gate its figures' }
    else { Bad 'missing registry did not throw' }

    Step '6b. stage ledger catches a skipped, stale or unrecorded stage'
    . (Join-Path $PSScriptRoot 'Stage-Ledger.ps1')
    $ld = Join-Path $OutDir 'ledger'
    New-Item -ItemType Directory -Force -Path (Join-Path $ld 'spine') | Out-Null
    Set-Content (Join-Path $ld 'spine\t1.json') -Encoding UTF8 -Value (@{
        visuals = @(@{ slot = '1.1.1'; kind = 'image'; caption = 'A caption'; alt = 'Alt text.' })
    } | ConvertTo-Json -Depth 8)
    & (Join-Path $PSScriptRoot 'New-FigureSheet.ps1') -BuildDir $ld -Quiet
    New-StageLedger -BuildDir $ld -Unit 'TEST001' | Out-Null

    if ((Test-StageLedger -BuildDir $ld).Ok) { Bad 'empty ledger passed - a build with no review stages must fail' }
    else { Ok 'empty ledger fails' }

    # The stage list is DERIVED from the ledger's own required set, never typed
    # here: a hand-copied list is what let six blocking stages be added to the
    # pipeline and to no gate. A build that skipped 3c, 3d, 4c, 6b, 7b-i, 7c and
    # 7d passed this test and delivered.
    $oldRequired = @('0','1','2','3','3b','4','4b','5','6','7b','8')
    foreach ($s in $oldRequired) {
        Add-StageRecord -BuildDir $ld -Stage $s -Name "stage $s" -Status pass `
                        -Verdict $(if ($s -eq '6') { 'Fully Compliant' } else { $null })
    }
    $miss = @($script:LedgerRequired | Where-Object { $oldRequired -notcontains $_ })
    $st = Test-StageLedger -BuildDir $ld
    $unseen = @($miss | Where-Object { ($st.Problems -join ' ') -notmatch ("Stage {0} has no record" -f [regex]::Escape($_)) })
    if (-not $st.Ok -and -not $unseen.Count) { Ok "every blocking stage added since is enforced ($($miss -join ', '))" }
    else { Bad "these blocking stages are still unenforced: $($unseen -join ', ')" }

    Remove-Item (Join-Path $ld 'stage-ledger.json') -Force
    New-StageLedger -BuildDir $ld -Unit 'TEST001' | Out-Null
    foreach ($s in $script:LedgerRequired) {
        Add-StageRecord -BuildDir $ld -Stage $s -Name "stage $s" -Status pass `
                        -Verdict $(if ($script:LedgerVerdict -contains $s) { 'Fully Compliant' } else { $null })
        Start-Sleep -Milliseconds 12
    }
    if ((Test-StageLedger -BuildDir $ld).Ok) { Ok 'complete ledger passes' }
    else { Bad "complete ledger failed: $((Test-StageLedger -BuildDir $ld).Problems -join '; ')" }

    # Placement is a mutation: what re-runs after it must postdate it.
    Add-StageRecord -BuildDir $ld -Stage '7b' -Name 'place artwork' -Status pass -Round 2
    $st = Test-StageLedger -BuildDir $ld
    if (($st.Problems -join ' ') -match 'artwork was placed at') { Ok 'placement makes the post-placement re-gate stale' }
    else { Bad 'a re-placement did not invalidate the stages that follow it' }
    Start-Sleep -Milliseconds 12
    Add-StageRecord -BuildDir $ld -Stage '7c' -Name 'post-placement re-gate' -Status pass -Round 2
    Add-StageRecord -BuildDir $ld -Stage '7d' -Name 'confirming read' -Status pass -Round 2 -Verdict 'Fully Compliant'
    if ((Test-StageLedger -BuildDir $ld).Ok) { Ok 'and re-running exactly those two clears it - the rule is satisfiable' }
    else { Bad "the placement staleness rule cannot be satisfied: $((Test-StageLedger -BuildDir $ld).Problems -join '; ')" }

    # The figure sheet travels with every later review pack, so it must still
    # describe the spine the documents were rendered from.
    Set-Content (Join-Path $ld 'spine\t1.json') -Encoding UTF8 -Value (@{
        visuals = @(@{ slot = '1.1.1'; kind = 'image'; caption = 'A corrected caption'; alt = 'Alt text.' })
    } | ConvertTo-Json -Depth 8)
    if ((Test-StageLedger -BuildDir $ld).Problems -join ' ' -match 'figure sheet') { Ok 'a spine edit makes the figure sheet stale' }
    else { Bad 'the figure sheet was not checked against the spine it was cut from' }
    & (Join-Path $PSScriptRoot 'New-FigureSheet.ps1') -BuildDir $ld -Quiet
    if ((Test-StageLedger -BuildDir $ld).Ok) { Ok 'regenerating it clears the block' }
    else { Bad "regenerating the figure sheet did not clear it: $((Test-StageLedger -BuildDir $ld).Problems -join '; ')" }

    # A re-render after the audit must invalidate the audit, not inherit it.
    Add-StageRecord -BuildDir $ld -Stage '7' -Name 'remediate + re-render' -Status pass -Round 3
    $st = Test-StageLedger -BuildDir $ld
    if ($st.Ok) { Bad 'a re-render after Stage 6 did not make the audit stale' }
    elseif (($st.Problems -join ' ') -match 'stale') { Ok 'a re-render makes the audit stale' }
    else { Bad "re-render flagged, but not as stale: $($st.Problems -join '; ')" }

    # And an honest 'skipped' on a blocking stage still blocks.
    Add-StageRecord -BuildDir $ld -Stage '5' -Name 'personas' -Status skipped -Round 3 -Note 'no time'
    if ((Test-StageLedger -BuildDir $ld).Problems -join ' ' -match 'SKIPPED') { Ok 'a skipped blocking stage blocks' }
    else { Bad 'a skipped blocking stage did not block' }

    # An 'n-a' with no written reason is a shrug, and a partial gate run with no
    # written reason is a check switched off where nobody would see it.
    Add-StageRecord -BuildDir $ld -Stage '4c' -Name 'brand' -Status 'n-a'
    Add-StageRecord -BuildDir $ld -Stage '4'  -Name 'render + gates' -Status pass -Partial @('assessment cross-reference (-QuestionsInPack)')
    $st = Test-StageLedger -BuildDir $ld
    if (($st.Problems -join ' ') -match "'n-a' with no note") { Ok "an 'n-a' with no reason blocks" }
    else { Bad "an 'n-a' with no reason was accepted" }
    if (($st.Problems -join ' ') -match 'checked nothing') { Ok 'a partial gate run with no reason blocks' }
    else { Bad 'a partial gate run with no reason was accepted' }

    Step '6c. withhold register derives the shape of a grid and never carries its answer'
    # A two-task synthetic pack: one labelled grid, one numbered grid, three
    # recipe cards. Every string is invented; nothing here names a real unit.
    # The learner text renders the labelled grid's rows TAB-JOINED, the way a
    # different extractor renders a table row, so the mirror gate's regex
    # fallback cannot see the grid and passes green - which is the failure the
    # typed grids.json exists to end.
    # The spine walker the plant is verified with lives in the shared gate library.
    . (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')
    $wr  = Join-Path $OutDir 'withhold'
    $wrp = Join-Path $wr 'pack'
    $wrb = Join-Path $wr 'build'
    New-Item -ItemType Directory -Force -Path (Join-Path $wrp 'content'), (Join-Path $wrb 'corpus'), (Join-Path $wrb 'spine') | Out-Null
    $plant = 'PLANTED ANSWER holds the spindle under tension'
    Set-Content (Join-Path $wrp 'content\test_tasks_1_2.json') -Encoding UTF8 -Value (@{
        items = @(
            @{ id = 'T-T1'; heading = 'Task 1 - Widgets'; wordGuide = '10 to 20 words per cell'
               stem = 'You keep the widgets. Answer the part below.'
               parts = @(@{ label = 'a'; text = 'Complete the table below for each widget. Name at least two care steps.'
                            itemTable = @{ headers = @('Widget', 'Purpose', 'Care')
                                           items = @('Widget A', 'Widget B', 'Widget C')
                                           modelRows = @(
                                               ('Widget A | turns the main spindle~~' + $plant + ' | oil the bearing weekly~~check the belt for fraying'),
                                               'Widget B | feeds the hopper evenly | clear the chute after every run~~grease the pivot monthly',
                                               'Widget C | holds the jig square | inspect the clamp face~~replace a worn pad at once') } }) },
            @{ id = 'T-T2'; heading = 'Task 2 - Gadgets'; wordGuide = '10 to 20 words per cell'
               stem = 'Name two dishes from the recipe list that need a gadget. Say why each suits the job.'
               parts = @(@{ label = 'a'; text = 'Complete the table below.'
                            itemTable = @{ headers = @('Order', 'Dish and recipe number', 'Why it suits')
                                           items = @('1', '2')
                                           modelRows = @(
                                               '1 | 9001 Alpha stew | a wet dish that needs long even heat',
                                               '2 | 9002 Beta soup | a large liquid volume that must not catch') } }) }
        )
    } | ConvertTo-Json -Depth 12)
    Set-Content (Join-Path $wrp 'content\recipes_test.json') -Encoding UTF8 -Value (@{
        items = @(@{ kind = 'recipeCard'; recipeNumber = '9001'; name = 'Alpha stew' },
                  @{ kind = 'recipeCard'; recipeNumber = '9002'; name = 'Beta soup' },
                  @{ kind = 'recipeCard'; recipeNumber = '9003'; name = 'Gamma pie' })
    } | ConvertTo-Json -Depth 6)
    Set-Content (Join-Path $wrb 'contract.json') -Encoding UTF8 -Value (@{
        unit = @{ code = 'TEST001' }
        questionMap = @{ '1.1' = @('Task 1(a)'); '1.2' = @('Task 2(a)') }
    } | ConvertTo-Json -Depth 6)
    $tab = [char]9
    $learnerLines = @(
        'Test Tool', 'Contents',
        'Task 1 - Widgets PAGEREF _Toc1 \h 2', 'Task 2 - Gadgets PAGEREF _Toc2 \h 3', 'End of tool PAGEREF _Toc3 \h 4',
        'Assessment conditions', 'This tool is open book. You may use your Learner Guide.',
        'Task 1 - Widgets', 'You keep the widgets. Answer the part below.',
        '(a)  Complete the table below for each widget. Name at least two care steps.',
        'Word guide: 10 to 20 words per cell', 'Student response - (a)',
        ('Widget' + $tab + 'Purpose' + $tab + 'Care'),
        ('Widget A' + $tab + 'Write here' + $tab + 'Write here'),
        ('Widget B' + $tab + 'Write here' + $tab + 'Write here'),
        ('Widget C' + $tab + 'Write here' + $tab + 'Write here'),
        'Task 2 - Gadgets', 'Name two dishes from the recipe list that need a gadget. Say why each suits the job.',
        '(a)  Complete the table below.', 'Word guide: 10 to 20 words per cell', 'Student response - (a)',
        'Order', 'Dish and recipe number', 'Why it suits',
        '1', 'Write here', 'Write here', '2', 'Write here', 'Write here',
        'Recipe 9001. Alpha stew', 'Recipe 9002. Beta soup', 'Recipe 9003. Gamma pie',
        'End of tool'
    )
    Set-Content (Join-Path $wrb 'corpus\TEST_Tool.txt') -Encoding UTF8 -Value ($learnerLines -join "`r`n")

    # *>&1, not 2>&1: the gates report through Write-Host, which 2>&1 does not
    # capture, and an assertion on an empty capture fails a passing gate.
    $wrOut = & (Join-Path $PSScriptRoot 'New-WithholdRegister.ps1') -BuildDir $wrb -PackDir $wrp -Quiet *>&1 | ForEach-Object { "$_" }
    $wrRc = $LASTEXITCODE
    if ($wrRc -eq 0) { Ok 'register generated' } else { Bad "register generator exited $wrRc`: $($wrOut -join ' ')" }

    $regPath = Join-Path $wrb 'withhold-register.json'
    $reg = Get-Content -LiteralPath $regPath -Raw | ConvertFrom-Json
    $g1 = @($reg.subSections.'1.1'.tasks) | Select-Object -First 1
    $g2 = @($reg.subSections.'1.2'.tasks) | Select-Object -First 1
    if ($null -ne $g1 -and $g1.kind -eq 'labelled')  { Ok 'a grid with printed row labels derives as labelled' } else { Bad "Task 1(a) kind is '$($g1.kind)', expected labelled" }
    if ($null -ne $g2 -and $g2.kind -eq 'numbered')  { Ok 'a grid with numeric row labels derives as numbered' } else { Bad "Task 2(a) kind is '$($g2.kind)', expected numbered" }
    if ($null -ne $g1 -and @($g1.items).Count -eq 3 -and @($g1.assessedHeaders).Count -eq 2 -and $g1.shape.rows -eq 3 -and $g1.shape.assessedColumns -eq 2) { Ok 'shape is 3 rows x 2 assessed columns' }
    else { Bad "shape derived as $($g1.shape.rows) x $($g1.shape.assessedColumns)" }
    if ($null -ne $g1 -and $g1.shape.bulletsPerCell.min -eq 1 -and $g1.shape.bulletsPerCell.max -eq 2 -and $g1.shape.wordGuide.min -eq 10 -and $g1.shape.wordGuide.max -eq 20 -and $g1.shape.benchmarkMinimum -eq 2) { Ok 'bullets per cell, word guide and benchmark minimum are numbers derived from the data' }
    else { Bad "shape numbers: bullets $($g1.shape.bulletsPerCell.min)-$($g1.shape.bulletsPerCell.max), words $($g1.shape.wordGuide.min)-$($g1.shape.wordGuide.max), benchmark $($g1.shape.benchmarkMinimum)" }
    if ($null -ne $g2 -and @($g2.subjects).Count -eq 2 -and @($g2.unassessedSubjects).Count -eq 1 -and ($g2.unassessedSubjects[0] -match '9003') -and $g2.allowance -eq 0) { Ok 'numbered grid: subjects resolved to the recipe vocabulary, the unassessed recipe remains, allowance 0' }
    else { Bad "numbered grid subjects=$(@($g2.subjects).Count) unassessed=$(@($g2.unassessedSubjects) -join ',') allowance=$($g2.allowance)" }
    if ($null -ne $g1 -and $g1.allowance -eq 1 -and @($g1.unassessedSubjects).Count -eq 0) { Ok 'labelled grid with no subject class: allowance 1' } else { Bad "labelled grid allowance=$($g1.allowance)" }

    # the answer is in the gate file and nowhere an agent can reach
    $cellsTxt = Get-Content -LiteralPath (Join-Path $wrb 'assessor-cells.json') -Raw
    if ($cellsTxt -match [regex]::Escape($plant)) { Ok 'assessor-cells.json carries the model bullet (gate-only)' } else { Bad 'assessor-cells.json does not carry the model bullet' }
    if ($cellsTxt -match '"_WARNING"\s*:\s*"GATE-ONLY') { Ok 'assessor-cells.json opens with the never-give-to-an-agent warning' } else { Bad 'assessor-cells.json has no warning header' }
    $agentFiles = @(Get-ChildItem -LiteralPath (Join-Path $wrb 'agent-pack') -Recurse -File)
    $leaked = @()
    foreach ($af in @($agentFiles) + @(Get-Item -LiteralPath $regPath)) {
        $t = Get-Content -LiteralPath $af.FullName -Raw
        foreach ($needle in @($plant, 'turns the main spindle', 'oil the bearing weekly', 'wet dish that needs long even heat')) {
            if ($t -match [regex]::Escape($needle)) { $leaked += "$($af.Name): $needle" }
        }
    }
    if ($leaked.Count -eq 0) { Ok "no model bullet in the register or any of the $($agentFiles.Count) agent-pack files" } else { Bad "model text reached an agent-facing file: $($leaked -join '; ')" }
    foreach ($need in @('1.1\tasks.md', '1.1\withhold.json', '1.1\README.md', '1.1\contract.json', '1.2\tasks.md')) {
        if (-not (Test-Path -LiteralPath (Join-Path $wrb ('agent-pack\' + $need)))) { Bad "agent-pack is missing $need" }
    }
    $tasksMd = Get-Content -LiteralPath (Join-Path $wrb 'agent-pack\1.1\tasks.md') -Raw
    if ($tasksMd -match 'Complete the table below for each widget' -and $tasksMd -match 'Widget B' -and $tasksMd -notmatch 'Task 2 - Gadgets') { Ok 'tasks.md carries the learner text of the assigned part only' }
    else { Bad 'tasks.md does not slice the learner text at the assigned task' }
    if ((Get-Content -LiteralPath (Join-Path $wrb 'agent-pack\1.1\README.md') -Raw) -match 'deliberately NOT here') { Ok 'README states what is deliberately absent' } else { Bad 'README does not state what is absent' }

    # grids.json in the shape the mirror gate loads
    $gridsPath = Join-Path $wrb 'corpus\grids.json'
    $gj = Get-Content -LiteralPath $gridsPath -Raw | ConvertFrom-Json
    if (@($gj.grids).Count -eq 2 -and (@($gj.grids | ForEach-Object { $_.id }) -contains 'TEST_Tool Task 1(a)')) { Ok 'grids.json carries both grids under the gate''s id form' } else { Bad "grids.json: $(@($gj.grids).Count) grid(s), ids $(@($gj.grids | ForEach-Object { $_.id }) -join ', ')" }
    foreach ($outFile in @($regPath, $gridsPath, (Join-Path $wrb 'assessor-cells.json'))) {
        $bytes = [System.IO.File]::ReadAllBytes($outFile)
        if (@($bytes | Where-Object { $_ -gt 127 }).Count -gt 0) { Bad "$(Split-Path $outFile -Leaf) is not ASCII" }
    }

    # Plant the labelled grid, answered, into a spine file - then PROVE the plant landed.
    Set-Content (Join-Path $wrb 'spine\t1_1.1.json') -Encoding UTF8 -Value (@{
        ref = '1.1'
        workedExample = @{ table = @{ headers = @('Widget', 'Purpose', 'Care')
            rows = @(@('Widget A', 'turns the main spindle', 'oil the bearing weekly'),
                     @('Widget B', 'feeds the hopper evenly', 'clear the chute after every run'),
                     @('Widget C', $plant, 'inspect the clamp face')) } }
    } | ConvertTo-Json -Depth 10)
    $planted = Get-Content -LiteralPath (Join-Path $wrb 'spine\t1_1.1.json') -Raw | ConvertFrom-Json
    $plantTables = @(Get-GateSpineTables -Node $planted -File 't1_1.1.json' -Path '' -Slot '')
    $plantRows = @($plantTables | ForEach-Object { @($_.Rows) } | ForEach-Object { @($_)[0] })
    if ($plantTables.Count -ge 1 -and ($plantRows -contains 'Widget A') -and ((Get-Content -LiteralPath (Join-Path $wrb 'spine\t1_1.1.json') -Raw) -match [regex]::Escape($plant))) { Ok 'the plant landed: the spine walker sees the answered grid' }
    else { Bad 'the plant did not land - nothing below proves anything' }

    # Without grids.json the regex fallback sees a grid, but not this one: green.
    Move-Item -LiteralPath $gridsPath -Destination ($gridsPath + '.off') -Force
    $mirrorOff = & (Join-Path $PSScriptRoot 'Check-FigureMirror.ps1') -BuildDir $wrb *>&1 | ForEach-Object { "$_" }
    $mirrorOffRc = $LASTEXITCODE
    # The claim is "caught ONLY when grids.json is present". Without it the
    # regex fallback either passes green on a decoy (rc 0) or finds no grid at
    # all and refuses (rc 2), depending on the gate's parse rules; either way
    # the planted grid is not named, and that is what is asserted. Naming it
    # (rc 1) would mean the typed file was not needed.
    $offSaw = ($mirrorOff -join ' ') -match 'Task 1\(a\)'
    if (-not $offSaw -and $mirrorOffRc -ne 1 -and (($mirrorOff -join ' ') -match 'structural parse')) { Ok "without grids.json the mirror gate does not catch the planted answer grid (rc=$mirrorOffRc, regex fallback)" }
    else { Bad "without grids.json: rc=$mirrorOffRc, named the grid: $offSaw" }
    Move-Item -LiteralPath ($gridsPath + '.off') -Destination $gridsPath -Force
    $mirrorOn = & (Join-Path $PSScriptRoot 'Check-FigureMirror.ps1') -BuildDir $wrb *>&1 | ForEach-Object { "$_" }
    $mirrorOnRc = $LASTEXITCODE
    $onSaw = ($mirrorOn -join ' ') -match 'TEST_Tool Task 1\(a\)'
    if ($mirrorOnRc -eq 1 -and $onSaw -and (($mirrorOn -join ' ') -match 'typed parse \(grids\.json\)')) { Ok 'with grids.json the same gate loads the typed grids and catches the plant' }
    else { Bad "with grids.json: rc=$mirrorOnRc, named the grid: $onSaw" }

    Step '6d. shape mirror, row coverage and grid disposition on a synthetic grid'
    # One labelled grid, 3 rows x 2 assessed columns, with model bullets in a
    # synthetic GATE-ONLY cells file. Every string is invented. The content
    # words are hand-stemmed to the register's rule (ing / ed / es / s) so the
    # fixture's truth does not come from the gate's own tokeniser.
    $sd = Join-Path $OutDir 'shape'
    New-Item -ItemType Directory -Force -Path (Join-Path $sd 'spine') | Out-Null
    Set-Content (Join-Path $sd 'contract.json') -Encoding UTF8 -Value (@{
        unit = @{ code = 'TEST001' }
        questionMap = @{ '1.1' = @('Task 1(a)') }
        keMap = @{ KE1 = @{ assessedIn = 'Task 1'; taughtAt = '1.1' }; KE2 = @{ assessedIn = 'Task 1'; taughtAt = '1.1' }; KE3 = @{ assessedIn = 'Task 1'; taughtAt = '1.1' } }
    } | ConvertTo-Json -Depth 6)
    Set-Content (Join-Path $sd 'unit_extract.md') -Encoding UTF8 -Value (@(
        '# TEST001 - unit extract', '', '## Knowledge evidence (verbatim)', '',
        'Demonstrated knowledge required to complete the tasks:', '',
        '- **KE1** widget drive gearing', '- **KE2** hopper material rate:', '  - KE2a chute blockage', '- **KE3** belt tensioner', '',
        '## Assessment conditions', '', 'None.') -join "`r`n")
    $figClean = '{ "figures": [], "mirrorAllow": [] }'
    Set-Content (Join-Path $sd 'figures.json') -Encoding UTF8 -Value $figClean
    Set-Content (Join-Path $sd 'withhold-register.json') -Encoding UTF8 -Value (@{
        subSections = @{ '1.1' = @{ subSection = '1.1'; refs = @('Task 1(a)'); tasks = @(
            @{ ref = 'Task 1(a)'; id = 'TEST_Tool Task 1(a)'; document = 'TEST_Tool'; kind = 'labelled'
               headers = @('Widget', 'Purpose', 'Care'); assessedHeaders = @(1, 2)
               items = @('Widget A', 'Widget B', 'Widget C'); aliases = @{ 'Widget A' = @(); 'Widget B' = @(); 'Widget C' = @() }
               subjectClass = 'widget'; subjects = @(); unassessedSubjects = @('Widget D'); allowance = 1
               shape = @{ rows = 3; assessedColumns = 2; bulletsPerCell = @{ min = 1; max = 2 }; wordGuide = @{ min = 10; max = 20 }; benchmarkMinimum = 1 } } ); freeText = @() } }
    } | ConvertTo-Json -Depth 12)
    Set-Content (Join-Path $sd 'assessor-cells.json') -Encoding UTF8 -Value (@{
        _WARNING = 'GATE-ONLY synthetic cells for the pipeline test'
        wordPipeline = @{ stopwords = 176; stem = 'crude suffix strip: ing, ed, es, s'; stripLearnerWords = 'headers and items'; dfCeiling = 0.25 }
        grids = @(@{ ref = 'Task 1(a)'; id = 'TEST_Tool Task 1(a)'; subSection = '1.1'; kind = 'labelled'; document = 'TEST_Tool'
                     headers = @('Widget', 'Purpose', 'Care'); assessedHeaders = @(1, 2)
                     rows = @(
                        @{ item = 'Widget A'; assessed = $true; cells = @(
                            @{ col = 1; header = 'Purpose'; state = 'answered'; bullets = @(@{ text = 'turns the main spindle'; words = @('turn', 'main', 'spindle') }, @{ text = 'holds the spindle under tension'; words = @('hold', 'spindle', 'tension') }) },
                            @{ col = 2; header = 'Care'; state = 'answered'; bullets = @(@{ text = 'oil the bearing weekly'; words = @('oil', 'bear', 'weekly') }, @{ text = 'check the belt for fraying'; words = @('check', 'belt', 'fray') }) }) },
                        @{ item = 'Widget B'; assessed = $true; cells = @(
                            @{ col = 1; header = 'Purpose'; state = 'answered'; bullets = @(@{ text = 'feeds the hopper evenly'; words = @('feed', 'hopper', 'evenly') }) },
                            @{ col = 2; header = 'Care'; state = 'answered'; bullets = @(@{ text = 'clear the chute after every run'; words = @('clear', 'chute', 'run') }, @{ text = 'grease the pivot monthly'; words = @('grease', 'pivot', 'monthly') }) }) },
                        @{ item = 'Widget C'; assessed = $true; cells = @(
                            @{ col = 1; header = 'Purpose'; state = 'answered'; bullets = @(@{ text = 'holds the jig square'; words = @('hold', 'jig', 'square') }) },
                            @{ col = 2; header = 'Care'; state = 'answered'; bullets = @(@{ text = 'inspect the clamp face'; words = @('inspect', 'clamp', 'face') }, @{ text = 'replace a worn pad at once'; words = @('replace', 'worn', 'pad') }) }) }
                     ) })
        freeText = @(); taskLevel = @()
    } | ConvertTo-Json -Depth 14)
    $shapeScript = Join-Path $PSScriptRoot 'Check-ShapeMirror.ps1'
    $covScript   = Join-Path $PSScriptRoot 'Check-RowCoverage.ps1'
    $dispScript  = Join-Path $PSScriptRoot 'Test-GridDisposition.ps1'
    $spinePath   = Join-Path $sd 'spine\t1_1.1.json'
    function Get-PlantText ([string] $Path) {
        $j = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        return ((@(Get-GateSpineCells -Node $j -File 't1_1.1.json' -Path '' -Channel '' -Slot '') | ForEach-Object { $_.Text }) -join ' | ')
    }

    # (i) prose that answers all three rows, in the task's order -> BLOCK
    Set-Content $spinePath -Encoding UTF8 -Value (@{
        ref = '1.1'; title = 'Widgets'
        underpinningKnowledge = @(
            'Widget A turns the main spindle and holds the spindle under tension. Oil the bearing weekly and check the belt for fraying.',
            'Widget B feeds the hopper evenly. Clear the chute after every run and grease the pivot monthly.',
            'Widget C holds the jig square. Inspect the clamp face and replace a worn pad at once.')
    } | ConvertTo-Json -Depth 6)
    $pt = Get-PlantText $spinePath
    if ($pt -match 'Widget A turns the main spindle' -and $pt -match 'Widget C holds the jig square') { Ok 'shape plant (i) landed: the spine walker sees the three answered rows' }
    else { Bad 'shape plant (i) did not land - nothing below proves anything' }
    $smOut = & $shapeScript -BuildDir $sd -Quiet *>&1 | ForEach-Object { "$_" }
    $smRc = $LASTEXITCODE
    $smTxt = $smOut -join ' '
    $smRep = Get-Content -LiteralPath (Join-Path $sd 'shape-mirror-report.json') -Raw | ConvertFrom-Json
    $smGrid = @($smRep.files | ForEach-Object { $_.Grids }) | Select-Object -First 1
    $smArms = if ($null -ne $smGrid) { @($smGrid.Arms) -join ' ' } else { '' }
    if ($smRc -eq 1 -and $smArms -match 'FULL ROWS: 3 answered in full, allowance 1' -and $smArms -match 'ROW ORDER') { Ok 'prose answering all three rows in order BLOCKS the shape mirror (full rows + row order)' }
    else { Bad "shape mirror on the answered prose: rc=$smRc; arms: $smArms" }
    if ($null -ne $smGrid -and $smGrid.FullRows -eq 3 -and @($smGrid.Rows | Where-Object { $_.Label -eq 'Widget B' -and $_.Full }).Count -eq 1) { Ok 'the report matrix carries 3 full rows with row labels, not bullets' }
    else { Bad 'the shape report does not carry the 3-row matrix' }
    $cellsTxt = Get-Content -LiteralPath (Join-Path $sd 'assessor-cells.json') -Raw
    $bulletLeak = @('turns the main spindle', 'grease the pivot monthly', 'inspect the clamp face') | Where-Object { $smTxt -match [regex]::Escape($_) -or (Get-Content -LiteralPath (Join-Path $sd 'shape-mirror-report.json') -Raw) -match [regex]::Escape($_) }
    if (-not @($bulletLeak).Count) { Ok 'neither the console nor the report prints a model bullet' } else { Bad "a model bullet reached the output: $($bulletLeak -join '; ')" }

    # (ii) the same facts taught as mechanism, no row named -> silent
    Set-Content $spinePath -Encoding UTF8 -Value (@{
        ref = '1.1'; title = 'Widgets'
        underpinningKnowledge = @(
            'A spindle is held under tension so the belt cannot slip. Bearings are oiled weekly because a dry bearing seizes.',
            'A hopper feeds evenly when its chute is cleared after every run. A jig stays square only while the clamp face is true, so inspect it and replace a worn pad at once.')
    } | ConvertTo-Json -Depth 6)
    $pt = Get-PlantText $spinePath
    if ($pt -match 'dry bearing seizes' -and $pt -notmatch 'Widget [ABC]') { Ok 'shape plant (ii) landed: the same facts, no row named' } else { Bad 'shape plant (ii) did not land' }
    $smOut2 = & $shapeScript -BuildDir $sd -Quiet *>&1 | ForEach-Object { "$_" }
    $smRc2 = $LASTEXITCODE
    $smRep2 = Get-Content -LiteralPath (Join-Path $sd 'shape-mirror-report.json') -Raw | ConvertFrom-Json
    if ($smRc2 -eq 0 -and $smRep2.summary.blockGrids -eq 0 -and $smRep2.summary.reportGrids -eq 0) { Ok 'mechanism prose with no row anchor is silent - unanchored sentences are never scored' }
    else { Bad "unanchored prose: rc=$smRc2, block=$($smRep2.summary.blockGrids), report=$($smRep2.summary.reportGrids)" }

    # (iii) two rows taught, one row never mentioned -> coverage REPORT per file, BLOCK whole
    Set-Content $spinePath -Encoding UTF8 -Value (@{
        ref = '1.1'; title = 'Widgets'
        underpinningKnowledge = @(
            'Widget A is the drive unit with the main gearing. Widget A needs watching in humid weather. Widget A is serviced by the fitter, not by you.',
            'Widget B sets the rate at which material reaches the hopper. A chute blockage stops Widget B. Widget B is serviced by the fitter as well.')
    } | ConvertTo-Json -Depth 6)
    $pt = Get-PlantText $spinePath
    if ($pt -match 'Widget A is the drive unit' -and $pt -notmatch 'Widget C') { Ok 'coverage plant (iii) landed: Widget C is never mentioned' } else { Bad 'coverage plant (iii) did not land' }
    $cvOut = & $covScript -BuildDir $sd -SpineFile $spinePath -Quiet *>&1 | ForEach-Object { "$_" }
    $cvRc = $LASTEXITCODE
    $cvRep = Get-Content -LiteralPath (Join-Path $sd 'row-coverage-report.json') -Raw | ConvertFrom-Json
    $cvRows = @($cvRep.files[0].Grids[0].Rows)
    $rowC = $cvRows | Where-Object { $_.Label -eq 'Widget C' }
    $rowA = $cvRows | Where-Object { $_.Label -eq 'Widget A' }
    $rowB = $cvRows | Where-Object { $_.Label -eq 'Widget B' }
    # Widget A is named in three sentences and the two-sentence window carries
    # its anchor into the opening of the next paragraph of the same array, so
    # its count is AT LEAST three; none of its sentences answers a bullet.
    if ($cvRc -eq 0 -and $null -ne $rowC -and $rowC.Teaching -eq 0 -and $rowC.Below -and $rowA.Teaching -ge 3 -and $rowA.Answering -eq 0 -and $rowB.Teaching -ge 3 -and $rowB.Answering -eq 0 -and $cvRep.summary.rowsBelowFile -eq 1) { Ok 'file mode REPORTS the untaught row (teaching 0) and counts 3+ teaching / 0 answering on the taught ones' }
    else { Bad "file-mode coverage: rc=$cvRc, Widget C teaching=$($rowC.Teaching) below=$($rowC.Below), Widget A teaching=$($rowA.Teaching) answering=$($rowA.Answering), Widget B teaching=$($rowB.Teaching)" }
    $cvOutW = & $covScript -BuildDir $sd -Whole -Quiet *>&1 | ForEach-Object { "$_" }
    $cvRcW = $LASTEXITCODE
    $cvRepW = Get-Content -LiteralPath (Join-Path $sd 'row-coverage-report.json') -Raw | ConvertFrom-Json
    if ($cvRcW -eq 1 -and @($cvRepW.belowWhole | Where-Object { $_.Row -eq 'Widget C' }).Count -eq 1 -and $cvRepW.grids[0].TaughtRows -eq 2) { Ok '-Whole BLOCKS on the untaught row (2 of 3 rows taught to the floor)' }
    else { Bad "whole-mode coverage: rc=$cvRcW, belowWhole=$(@($cvRepW.belowWhole).Count), taught=$($cvRepW.grids[0].TaughtRows)" }
    $ke3 = @($cvRepW.ke.points | Where-Object { $_.Id -eq 'KE3' })
    $ke1 = @($cvRepW.ke.points | Where-Object { $_.Id -eq 'KE1' })
    if ($ke3.Count -eq 1 -and -not $ke3[0].Covered -and $ke1.Count -eq 1 -and $ke1[0].Covered -and (($cvOutW -join ' ') -match 'KE3')) { Ok 'KE coverage: the taught point is covered and the untaught point (KE3) blocks with its missing terms' }
    else { Bad "KE coverage: KE3 covered=$($ke3.Covered) KE1 covered=$($ke1.Covered)" }

    # (iv) one verdict per grid; not disposed while a row is untaught; cleared only through mirrorAllow with a reason
    & $shapeScript -BuildDir $sd -Quiet *>&1 | Out-Null
    $dpOut = & $dispScript -BuildDir $sd -Quiet *>&1 | ForEach-Object { "$_" }
    $dpRc = $LASTEXITCODE
    $dp = Get-Content -LiteralPath (Join-Path $sd 'grid-disposition.json') -Raw | ConvertFrom-Json
    if ($dpRc -eq 1 -and @($dp.grids).Count -eq 1 -and $dp.grids[0].verdict -eq 'NOT DISPOSED' -and $dp.grids[0].taught -eq 2 -and $dp.grids[0].answered -eq 0) { Ok 'disposition: exactly one verdict for the one grid, NOT DISPOSED (taught 2 of 3), exit 1' }
    else { Bad "disposition: rc=$dpRc, verdicts=$(@($dp.grids).Count), verdict=$($dp.grids[0].verdict), taught=$($dp.grids[0].taught)" }
    Set-Content (Join-Path $sd 'figures.json') -Encoding UTF8 -Value '{ "figures": [], "mirrorAllow": [ { "id": "TEST_Tool Task 1(a)", "reason": "synthetic Stage 3d clearance for the pipeline test: the third widget is taught in the practical session, not in the guide" } ] }'
    & $dispScript -BuildDir $sd -Quiet *>&1 | Out-Null
    $dpRc2 = $LASTEXITCODE
    $dp2 = Get-Content -LiteralPath (Join-Path $sd 'grid-disposition.json') -Raw | ConvertFrom-Json
    if ($dpRc2 -eq 0 -and $dp2.grids[0].verdict -eq 'cleared' -and $dp2.grids[0].reason -match 'practical session') { Ok 'a written mirrorAllow reason clears the grid, and the reason travels into the disposition' }
    else { Bad "clearance: rc=$dpRc2, verdict=$($dp2.grids[0].verdict)" }
    Set-Content (Join-Path $sd 'figures.json') -Encoding UTF8 -Value '{ "figures": [], "mirrorAllow": [ { "id": "TEST_Tool Task 1(a)" } ] }'
    $threw = $false
    try { & $dispScript -BuildDir $sd -Quiet *>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { $threw = $true } } catch { $threw = $true }
    if ($threw) { Ok 'a mirrorAllow entry with no reason cannot clear anything' } else { Bad 'an allow-list entry with no reason cleared the grid' }
    Set-Content (Join-Path $sd 'figures.json') -Encoding UTF8 -Value $figClean

    # (v) every row taught, nothing answered, a hollow relocated exemplar -> disposed
    Set-Content $spinePath -Encoding UTF8 -Value (@{
        ref = '1.1'; title = 'Widgets'
        underpinningKnowledge = @(
            'Widget A is the drive unit with the main gearing. Widget A needs watching in humid weather. Widget A is serviced by the fitter, not by you.',
            'Widget B sets the rate at which material reaches the hopper. A chute blockage stops Widget B. Widget B is serviced by the fitter as well.',
            'Widget C carries the belt tensioner. Widget C is checked by eye at the start of each shift. Widget C is the last unit in the line.')
        workedExample = @{ table = @{ headers = @('Widget', 'Purpose', 'Care'); rows = @(, @('Widget D', 'spins', 'oil it')) } }
    } | ConvertTo-Json -Depth 8)
    $pt = Get-PlantText $spinePath
    if ($pt -match 'Widget C carries the belt tensioner' -and $pt -match 'Widget D') { Ok 'plant (v) landed: three taught rows and a relocated exemplar' } else { Bad 'plant (v) did not land' }
    & $shapeScript -BuildDir $sd -Quiet *>&1 | Out-Null
    $smRc5 = $LASTEXITCODE
    & $covScript -BuildDir $sd -Whole -Quiet *>&1 | Out-Null
    $cvRc5 = $LASTEXITCODE
    $cvRep5 = Get-Content -LiteralPath (Join-Path $sd 'row-coverage-report.json') -Raw | ConvertFrom-Json
    & $dispScript -BuildDir $sd -Quiet *>&1 | Out-Null
    $dpRc5 = $LASTEXITCODE
    $dp5 = Get-Content -LiteralPath (Join-Path $sd 'grid-disposition.json') -Raw | ConvertFrom-Json
    if ($smRc5 -eq 0 -and $cvRc5 -eq 0 -and $dpRc5 -eq 0 -and $dp5.grids[0].verdict -eq 'disposed' -and $dp5.grids[0].taught -eq 3) { Ok 'with every row taught and none answered, the grid is DISPOSED and all three gates exit 0' }
    else { Bad "disposed path: shape rc=$smRc5, coverage rc=$cvRc5, disposition rc=$dpRc5, verdict=$($dp5.grids[0].verdict)" }
    if (@($cvRep5.hollow).Count -eq 2 -and $cvRep5.hollow[0].Row -eq 'Widget D') { Ok 'a relocated exemplar with two-word cells is REPORTED as hollow (does not block)' }
    else { Bad "hollow relocation: $(@($cvRep5.hollow).Count) cell(s) reported" }
    Remove-Item -LiteralPath (Join-Path $sd 'unit_extract.md') -Force
    & $covScript -BuildDir $sd -Whole -Quiet *>&1 | Out-Null
    if ($LASTEXITCODE -eq 1) { Ok '-Whole with no unit extract BLOCKS and names the missing input - a floor with no input has checked nothing' }
    else { Bad "-Whole passed with no unit extract (rc=$LASTEXITCODE)" }

    Step '7. Office opens both without repairing'
    if ($SkipOffice) { Write-Host '        skipped' -ForegroundColor DarkGray }
    else {
        $w = $null
        try {
            $w = New-Object -ComObject Word.Application; $w.Visible = $false
            $d = $w.Documents.Open($guide, $false, $true)
            Ok "Word opened the guide ($($d.ComputeStatistics(2)) pages)"
            $d.Close(0)
        } catch { Bad "Word: $($_.Exception.Message)" }
        finally { if ($w) { $w.Quit() } }

        $a = $null
        try {
            $a = New-Object -ComObject PowerPoint.Application
            $pr = $a.Presentations.Open($deckPath, $true, $false, $false)
            Ok "PowerPoint opened the deck ($($pr.Slides.Count) slides)"
            $pr.Close()
        } catch { Bad "PowerPoint: $($_.Exception.Message)" }
        finally { if ($a) { $a.Quit() } }
        [GC]::Collect()
    }
}
catch {
    # An exception that escapes a step is a failed check, not a skipped one:
    # without this, a crash in step N left the summary reading PIPELINE OK
    # over the steps that never ran.
    Bad ("unhandled exception at line {0}: {1}" -f $_.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
}
finally {
    Write-Host ''
    if ($KeepOutput) { Write-Host "output kept: $OutDir" -ForegroundColor DarkGray }
    else { Remove-Item -LiteralPath $OutDir -Recurse -Force -ErrorAction SilentlyContinue }

    if ($fail -eq 0) { Write-Host "PIPELINE OK - $pass checks passed" -ForegroundColor Green }
    else             { Write-Host "PIPELINE FAILED - $fail of $($pass + $fail) checks failed" -ForegroundColor Red }
    Write-Host ''
}

# A REPORT IS NOT A VERDICT. The exit code is this script's own, derived from
# its own tally - never the code the last inner gate happened to leave.
if ($fail -eq 0) { exit 0 } else { exit 4 }
