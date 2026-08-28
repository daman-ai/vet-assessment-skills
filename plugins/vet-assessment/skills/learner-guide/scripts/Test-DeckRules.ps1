<#
    Test-DeckRules.ps1

    THE DECK GATE. Runs on a built .pptx (or its unpacked working directory)
    and reports what a trainer would otherwise find in front of a class.

    Every rule here exists because the shipped SITHPAT018 deck or the template
    itself demonstrated the failure:

      RESIDUAL PLACEHOLDER  Clone-and-fill leaves the exemplar's own words in any
                            slot the build forgot. The template's own strings are
                            harvested from the template, so this needs no
                            maintained list of phrases.
      SLIDE NUMBERING       The footer number is literal text, not a field. The
                            shipped deck prints the wrong number on 19 of its 39
                            slides. Blocking.
      SLIDES PER TOPIC      The spec sets a floor of 15 per Topic section.
      SPEAKER NOTES         Required on every teaching, case-study and
                            assessment-link slide.
      ASSESSMENT CHIP       Required on every PC teaching slide - the whole point
                            of the delivery deck is signposting the questions.
      OVERSET TEXT          A slot given far more text than the exemplar held
                            will overflow its shape. Warned, not blocked.

    Requires Build-FromTemplate.ps1 and Pptx-Blocks.ps1 dot-sourced first.

    ASCII only in this file.
#>

# No Set-StrictMode - dot-sourced.

function Get-DeckPlaceholderPhrase {
    <#  Every distinct run of text the TEMPLATE ships, as the placeholder
        vocabulary. Harvested rather than hard-coded, so the list cannot drift
        away from the template it is meant to police.

        Footer, RTO and tagline strings are excluded: those are template text
        that is SUPPOSED to survive into the built deck.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $TemplatePath)

    $wd = Expand-Docx -Path $TemplatePath
    try {
        $keep = New-Object System.Collections.Generic.HashSet[string]
        foreach ($p in (Get-DeckSlideOrder -WorkDir $wd)) {
            $xml = Get-DocxPart -WorkDir $wd -Part "ppt/slides/$p"
            foreach ($m in [regex]::Matches($xml, '<a:t>([^<]*)</a:t>')) {
                $t = $m.Groups[1].Value.Trim()
                if ($t.Length -lt 8) { continue }                       # digits, bullets, arrows
                if ($t -match 'Meridian Vocational College') { continue }
                if ($t -match 'RTO 45039|CRICOS 03551M')     { continue }
                if ($t -match 'INNOVATION')                  { continue }
                # A single ALL-CAPS word is a structural KICKER - "OVERVIEW",
                # "SECTION", "REFERENCE" - not an instruction to replace
                # something. A correct agenda slide legitimately reuses the
                # template's own "OVERVIEW" kicker, as the RTO's shipped deck
                # does, and flagging that is a false positive. Multi-word
                # phrases such as "Section one title" stay in the vocabulary.
                if ($t -cmatch '^[A-Z0-9]+$') { continue }
                [void]$keep.Add($t)
            }
        }
        return $keep
    }
    finally { Remove-Item -LiteralPath $wd -Recurse -Force -ErrorAction SilentlyContinue }
}

function Test-DeckRules {
    <#  Gate a built deck.

        -Plan is optional and describes what the build intended, so structural
        rules can be checked at all. One entry per slide, in deck order:

            @{ Tag = '1.1 concept'; Topic = 1; Kind = 'teaching' }

        Kind is one of: title, housekeeping, agenda, assessment-orientation,
        divider, outcomes, teaching, case-study, figures, process, table,
        assessment-link, recap, briefing, thanks, brandref.

        Without a plan the placeholder, numbering and notes-presence rules still
        run; the per-topic count and chip rules are skipped and said to be.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [string]    $TemplatePath,
        [array]     $Plan,
        [int]       $MinSlidesPerTopic = 15,
        [hashtable] $NumberSlotByLayout,
        [string]    $Rto,
        [string]    $Cricos
    )

    $wd = if ((Get-Item -LiteralPath $Path).PSIsContainer) { $Path } else { Expand-Docx -Path $Path }

    $fail = New-Object System.Collections.Generic.List[string]
    $warn = New-Object System.Collections.Generic.List[string]
    $info = New-Object System.Collections.Generic.List[string]

    $order = @(Get-DeckSlideOrder -WorkDir $wd)
    $info.Add("slides: $($order.Count)")

    # ---- package integrity first; nothing else matters if it will not open
    $pkg = Test-PptxPackage -WorkDir $wd
    if (-not $pkg.Ok) { foreach ($i in $pkg.Issues) { $fail.Add("package: $i") } }

    # ---- residual template placeholder text
    if ($TemplatePath) {
        $phrases = Get-DeckPlaceholderPhrase -TemplatePath $TemplatePath
        $n = 0
        foreach ($p in $order) {
            $n++
            # A layout marked verbatim in the profile (thank-you, brand
            # reference) is DELIVERED as the template wrote it, so its own text
            # is not an unfilled slot. Without this the sweep reports the
            # closing slide's "Thank you" as a defect.
            if ($Plan -and $Plan.Count -ge $n -and $Plan[$n - 1].Verbatim) { continue }

            $xml = Get-DocxPart -WorkDir $wd -Part "ppt/slides/$p"
            foreach ($m in [regex]::Matches($xml, '<a:t>([^<]*)</a:t>')) {
                $t = $m.Groups[1].Value.Trim()
                if ($phrases.Contains($t)) {
                    $fail.Add("slide $n still shows template placeholder text: `"$t`"")
                }
            }
        }
    }
    else { $info.Add('placeholder sweep skipped - no -TemplatePath given') }

    # ---- document properties: whose file does this still say it is?
    #
    # The approved MVC template was cloned from another RTO's deck and kept its
    # docProps - title "ACI Branded PowerPoint Template", subject
    # "RTO 45797 | CRICOS 03978F", creator "Adelaide Construction Institute".
    # Nothing of it appears on a slide, so every other rule in this file passed
    # a deck that told File > Info, Explorer and every exported PDF that it
    # belonged to a competitor. Save-Deck now stamps these; this is the net
    # under that, because the failure is invisible on the page.
    $props = ''
    foreach ($p in @('docProps/core.xml', 'docProps/app.xml')) {
        $x = Get-DocxPart -WorkDir $wd -Part $p -ErrorAction SilentlyContinue
        if ($x) { $props += ($x -replace '<[^>]+>', ' ') }
    }
    if ($props.Trim()) {
        foreach ($m in [regex]::Matches($props, '(?i)\bRTO\s*#?\s*:?\s*(\d{4,6})\b')) {
            $code = $m.Groups[1].Value
            if ($Rto -and $code -ne $Rto) {
                $fail.Add("document properties name RTO $code, but this deck is branded RTO $Rto")
            } elseif (-not $Rto) {
                $info.Add("document properties name RTO $code - confirm it is this RTO (pass -Rto to make this blocking)")
            }
        }
        foreach ($m in [regex]::Matches($props, '(?i)\bCRICOS\s*#?\s*:?\s*([0-9]{5}[0-9A-Z])\b')) {
            $code = $m.Groups[1].Value
            if ($Cricos -and $code -ne $Cricos) {
                $fail.Add("document properties name CRICOS $code, but this deck is branded CRICOS $Cricos")
            } elseif (-not $Cricos) {
                $info.Add("document properties name CRICOS $code - confirm it is this provider")
            }
        }
        # An unstamped clone still calls itself a template. A delivered deck
        # never should.
        $t = [regex]::Match($props, '(?i)\b([A-Za-z ]*Branded[A-Za-z ]*Template)\b')
        if ($t.Success) { $fail.Add("document properties still carry the template's own title: `"$($t.Groups[1].Value.Trim())`"") }
    } else { $info.Add('no document properties found to check') }

    # ---- slide numbering
    $numBad = 0
    $n = 0
    foreach ($p in $order) {
        $n++
        $xml = Get-DocxPart -WorkDir $wd -Part "ppt/slides/$p"
        $shapes = @(Get-SlideShape -SlideXml $xml | Where-Object { $_.TextIndex -gt 0 })
        if (-not $shapes.Count) { continue }

        # Any shape whose whole text is a bare integer is treated as a page
        # number; on these layouts nothing else is ever a lone integer except
        # the divider's section number and the process layout's step numbers,
        # both of which sit in declared slots and are excluded below.
        $slot = $null
        if ($NumberSlotByLayout -and $Plan -and $Plan.Count -ge $n -and $Plan[$n - 1].LayoutSlide) {
            if ($NumberSlotByLayout.ContainsKey([int]$Plan[$n - 1].LayoutSlide)) {
                $slot = [int]$NumberSlotByLayout[[int]$Plan[$n - 1].LayoutSlide]
            }
        }
        if ($null -eq $slot) { $slot = $shapes[-1].TextIndex }
        if ($slot -le 0) { continue }

        $sh = $shapes | Where-Object { $_.TextIndex -eq $slot } | Select-Object -First 1
        if (-not $sh) { continue }
        $val = ($sh.Text -join '').Trim()
        if ($val -match '^\d+$' -and [int]$val -ne $n) {
            $fail.Add("slide $n prints footer number $val")
            $numBad++
        }
    }
    if (-not $numBad) { $info.Add('slide numbering: every printed number matches its deck position') }

    # ---- notes, chips, per-topic counts (need the plan)
    if ($Plan -and $Plan.Count) {
        if ($Plan.Count -ne $order.Count) {
            $warn.Add("plan describes $($Plan.Count) slides but the deck has $($order.Count)")
        }

        $needNotes = @('teaching', 'case-study', 'assessment-link', 'figures', 'process', 'table')
        $needChip  = @('teaching', 'case-study', 'figures', 'process', 'table', 'assessment-link')

        $n = 0
        foreach ($p in $order) {
            $n++
            if ($n -gt $Plan.Count) { break }
            $kind = "$($Plan[$n - 1].Kind)"
            $tag  = "$($Plan[$n - 1].Tag)"

            $rels     = Get-DocxPart -WorkDir $wd -Part "ppt/slides/_rels/$p.rels"
            $hasNotes = $false
            if ($rels -match 'Target="\.\./(notesSlides/[^"]+)"') {
                $np = Join-Path $wd ("ppt\" + ($Matches[1] -replace '/', '\'))
                if (Test-Path -LiteralPath $np) {
                    $nx = [System.IO.File]::ReadAllText($np, [System.Text.Encoding]::UTF8)
                    $body = -join ([regex]::Matches($nx, '<a:t>([^<]*)</a:t>') | ForEach-Object { $_.Groups[1].Value })
                    # the slide-number field also emits an <a:t>; require real prose
                    if (($body -replace '\d', '').Trim().Length -ge 20) { $hasNotes = $true }
                }
            }
            if ($needNotes -contains $kind -and -not $hasNotes) {
                $fail.Add("slide $n ($tag, $kind) has no speaker notes")
            }

            $xml = Get-DocxPart -WorkDir $wd -Part "ppt/slides/$p"
            $hasChip = ($xml -match 'Assessment Link Chip') -or ($xml -match 'Prepares you for|Assessed in')
            if ($needChip -contains $kind -and -not $hasChip) {
                $warn.Add("slide $n ($tag, $kind) carries no assessment-question reference")
            }
        }

        $byTopic = @{}
        foreach ($e in $Plan) {
            if ($null -eq $e.Topic -or "$($e.Topic)" -eq '') { continue }
            $t = [int]$e.Topic
            if (-not $byTopic.ContainsKey($t)) { $byTopic[$t] = 0 }
            $byTopic[$t]++
        }
        foreach ($t in ($byTopic.Keys | Sort-Object)) {
            $c = $byTopic[$t]
            if ($c -lt $MinSlidesPerTopic) { $fail.Add("Topic $t has $c slides, floor is $MinSlidesPerTopic") }
            else { $info.Add("Topic ${t}: $c slides") }
        }
    }
    else { $info.Add('per-topic count and chip rules skipped - no -Plan given') }

    # ---- overset text warning
    $n = 0
    foreach ($p in $order) {
        $n++
        $xml = Get-DocxPart -WorkDir $wd -Part "ppt/slides/$p"
        foreach ($sh in (Get-SlideShape -SlideXml $xml | Where-Object { $_.TextIndex -gt 0 })) {
            $len = (($sh.Text -join ' ')).Length
            if ($len -gt 420) { $warn.Add("slide $n shape $($sh.TextIndex) holds $len characters - likely to overflow") }
        }
    }

    return [pscustomobject]@{
        Ok       = ($fail.Count -eq 0)
        Failures = $fail
        Warnings = $warn
        Info     = $info
        Slides   = $order.Count
    }
}

function Write-DeckRuleReport {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)] $Result)
    process {
        Write-Host ''
        Write-Host "DECK GATE - $($Result.Slides) slides" -ForegroundColor Cyan
        foreach ($i in $Result.Info)     { Write-Host "  .  $i"  -ForegroundColor DarkGray }
        foreach ($w in $Result.Warnings) { Write-Host "  ~  $w"  -ForegroundColor Yellow }
        foreach ($f in $Result.Failures) { Write-Host "  X  $f"  -ForegroundColor Red }
        if ($Result.Ok) { Write-Host '  PASS' -ForegroundColor Green }
        else            { Write-Host "  FAIL - $($Result.Failures.Count) blocking" -ForegroundColor Red }
        Write-Host ''
    }
}
