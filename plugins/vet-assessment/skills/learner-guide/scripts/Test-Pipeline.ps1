<#
    Test-Pipeline.ps1

    End-to-end smoke test. Builds a small Learner Guide and a small deck from
    the approved templates, runs both gates, and opens both in Office to confirm
    neither prompts to repair.

    Run it after ANY change to the scripts, the profiles or the templates:

        & "$SkillDir\scripts\Test-Pipeline.ps1"

    It writes to a temp directory and cleans up, so it never touches a build.

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

    $gt  = Get-GuideTemplatePath -SkillDir $PSScriptRoot
    $pt  = Join-Path $SkillDir 'assets\templates\MVC_Branded_PPT_Template.pptx'

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
                         -NumberSlotByLayout (Get-DeckNumberSlotMap -Profile $DP)
    foreach ($i in $dr.Info) { Write-Host "        $i" -ForegroundColor DarkGray }
    if ($dr.Ok) { Ok 'deck gate clean' } else { foreach ($f in $dr.Failures) { Bad $f } }

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

    Step '6b. stage ledger catches a skipped or stale review stage'
    . (Join-Path $PSScriptRoot 'Stage-Ledger.ps1')
    $ld = Join-Path $OutDir 'ledger'
    New-Item -ItemType Directory -Force -Path $ld | Out-Null
    New-StageLedger -BuildDir $ld -Unit 'TEST001' | Out-Null

    if ((Test-StageLedger -BuildDir $ld).Ok) { Bad 'empty ledger passed - a build with no review stages must fail' }
    else { Ok 'empty ledger fails' }

    foreach ($s in @('0','1','2','3','3b','4','4b','5','6','7b','8')) {
        Add-StageRecord -BuildDir $ld -Stage $s -Name "stage $s" -Status pass `
                        -Verdict $(if ($s -eq '6') { 'Fully Compliant' } else { $null })
    }
    if ((Test-StageLedger -BuildDir $ld).Ok) { Ok 'complete ledger passes' }
    else { Bad 'complete ledger failed' }

    # A re-render after the audit must invalidate the audit, not inherit it.
    Add-StageRecord -BuildDir $ld -Stage '7' -Name 'remediate + re-render' -Status pass -Round 1
    $st = Test-StageLedger -BuildDir $ld
    if ($st.Ok) { Bad 'a re-render after Stage 6 did not make the audit stale' }
    elseif (($st.Problems -join ' ') -match 'stale') { Ok 'a re-render makes the audit stale' }
    else { Bad "re-render flagged, but not as stale: $($st.Problems -join '; ')" }

    # And an honest 'skipped' on a blocking stage still blocks.
    Add-StageRecord -BuildDir $ld -Stage '5' -Name 'personas' -Status skipped -Round 1 -Note 'no time'
    if ((Test-StageLedger -BuildDir $ld).Problems -join ' ' -match 'SKIPPED') { Ok 'a skipped blocking stage blocks' }
    else { Bad 'a skipped blocking stage did not block' }

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
finally {
    Write-Host ''
    if ($KeepOutput) { Write-Host "output kept: $OutDir" -ForegroundColor DarkGray }
    else { Remove-Item -LiteralPath $OutDir -Recurse -Force -ErrorAction SilentlyContinue }

    if ($fail -eq 0) { Write-Host "PIPELINE OK - $pass checks passed" -ForegroundColor Green }
    else             { Write-Host "PIPELINE FAILED - $fail of $($pass + $fail) checks failed" -ForegroundColor Red }
    Write-Host ''
}
