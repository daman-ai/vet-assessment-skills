#requires -Version 5.1
<#
    Add-DeckAnimations.ps1

    Adds the on-slide motion to a built deck: each card and each illustration
    fades and grows into place, one after another, so a slide assembles itself
    rather than arriving all at once. The slide-to-slide Morph transition is
    written by the builder; this adds what happens once a slide has landed.

    Written through PowerPoint's own object model rather than by hand. The
    p:timing tree is long, order-sensitive and unforgiving - a malformed one
    makes PowerPoint declare the file corrupt - so PowerPoint is left to
    generate it and this script only says what should move.

    Office COM never opens the OneDrive path: the deck is copied to local temp,
    animated there, and copied back.

    ASCII only in this file.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $Deck,
    [double] $Duration = 0.45,
    [double] $Stagger  = 0.12,
    [int]    $CardEffect = 23,
    [int]    $ArtEffect  = 10,
    [switch] $OnClick,
    [switch] $Clear
)

$ErrorActionPreference = 'Stop'

# MsoAnimEffect / OOXML entrance preset ids.
$FX_FADE  = 10
$FX_ZOOM  = 23

# msoAnimTriggerOnPageClick = 1, WithPrevious = 2, AfterPrevious = 3
$TRG_CLICK = 1
$TRG_WITH  = 2
$TRG_AFTER = 3
$LEVEL_NONE = 0

# Cards run on after the slide arrives by default, which is what makes the
# deck feel alive. -OnClick hands the pacing back to the trainer instead, so a
# four-step process can be revealed one step at a time while they talk.
$LEAD = if ($OnClick) { $TRG_CLICK } else { $TRG_AFTER }

function Step ([string] $m) { Write-Host ("[{0:HH:mm:ss}] {1}" -f (Get-Date), $m) -ForegroundColor Cyan }

$tmp = Join-Path $env:TEMP ("deckanim_" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$local = Join-Path $tmp 'deck.pptx'
Copy-Item -LiteralPath $Deck -Destination $local -Force

$app = $null; $pres = $null
$added = 0
try {
    Step 'PowerPoint: opening'
    $app  = New-Object -ComObject PowerPoint.Application
    $pres = $app.Presentations.Open($local, $false, $false, $false)

    foreach ($i in 1..$pres.Slides.Count) {
        $slide = $pres.Slides.Item($i)
        $seq   = $slide.TimeLine.MainSequence

        if ($Clear) {
            while ($seq.Count -gt 0) { $seq.Item(1).Delete() }
        }
        if ($seq.Count -gt 0) { continue }   # already animated

        # A card is a group of parts that must arrive as one: the filled blob,
        # the numbered badge, and the card's own copy.
        # The first pass animated only the blob, so the heading and body text
        # were already sitting on the slide when their card flew in behind
        # them - which is what made the motion look broken rather than slick.
        $cards   = @{}
        $title   = @()
        $chip    = @()
        # The photograph is a blob filled with the picture rather than a bare
        # picture shape. Matched on the prefix rather than on the exact name,
        # so a guide photograph and a loose scene illustration - both named
        # "!!art" by the restyle - are caught by the same rule.
        $artShape = @()

        # Free-standing copy - the lead-in paragraph and the bullet block on a
        # slide that has no cards - was in none of these buckets, so it got no
        # effect at all and was simply THERE from the first frame while the
        # heading and the picture animated in around it. On a teaching slide
        # that reads as the content arriving before its own heading. It is
        # everything the builder did not rename: furniture all carries a "!!"
        # prefix and card parts are named "Card NN".
        $body = @()
        foreach ($j in 1..$slide.Shapes.Count) {
            $sh = $slide.Shapes.Item($j)
            $nm = [string]$sh.Name
            if ($nm -like '!!art*') { $artShape += $sh; continue }
            if ($nm -like '!!titleblob*' -or $nm -eq '!!title' -or $nm -eq '!!eyebrow') { $title += $sh; continue }
            if ($nm -like '!!chip*') { $chip += $sh; continue }
            if ($nm -match '^Card (\d\d)') {
                $key = $Matches[1]
                if (-not $cards.ContainsKey($key)) { $cards[$key] = @{ Blob = @(); Text = @() } }
                if ($nm -match ' text ') { $cards[$key].Text += $sh } else { $cards[$key].Blob += $sh }
                continue
            }
            if ($nm -like '!!*') { continue }        # logo, footer, page number: standing furniture
            $body += $sh
        }
        # top to bottom, so a lead-in arrives before the bullets under it
        $body = @($body | Sort-Object { [double]$_.Top })

        # 1. the title block settles first
        $firstInSlide = $true
        foreach ($sh in $title) {
            $trigger = if ($firstInSlide) { $LEAD } else { $TRG_WITH }
            $eff = $seq.AddEffect($sh, $ArtEffect, $LEVEL_NONE, $trigger)
            $eff.Timing.Duration = 0.5
            if ($firstInSlide -and -not $OnClick) { $eff.Timing.TriggerDelayTime = 0.1 }
            $added++; $firstInSlide = $false
        }

        # 2. the picture, before any of the words it illustrates
        $leadArt = $true
        foreach ($sh in $artShape) {
            $trigger = if ($leadArt) { if ($firstInSlide) { $LEAD } else { $TRG_AFTER } } else { $TRG_WITH }
            $eff = $seq.AddEffect($sh, $ArtEffect, $LEVEL_NONE, $trigger)
            $eff.Timing.Duration = 0.6
            $added++; $firstInSlide = $false; $leadArt = $false
        }

        # 3. each card, blob and copy together, left to right
        $n = 0
        foreach ($key in ($cards.Keys | Sort-Object)) {
            $c = $cards[$key]
            $isLeadShape = $true
            foreach ($sh in (@($c.Blob) + @($c.Text))) {
                if (-not $sh) { continue }
                $trigger = if ($isLeadShape) { $LEAD } elseif ($firstInSlide) { $LEAD } else { $TRG_WITH }
                $eff = $seq.AddEffect($sh, $CardEffect, $LEVEL_NONE, $trigger)
                $eff.Timing.Duration = $Duration
                if ($isLeadShape -and -not $OnClick) {
                    $eff.Timing.TriggerDelayTime = $(if ($n -eq 0) { 0.12 } else { $Stagger })
                }
                $added++; $isLeadShape = $false; $firstInSlide = $false
            }
            $n++
        }

        # 4. the copy, after the heading and the picture it belongs to
        foreach ($sh in $body) {
            $trigger = $LEAD
            $eff = $seq.AddEffect($sh, $ArtEffect, $LEVEL_NONE, $trigger)
            $eff.Timing.Duration = 0.5
            $added++; $firstInSlide = $false
        }

        # 5. the assessment chip last
        $isLeadShape = $true
        foreach ($sh in $chip) {
            $trigger = if ($isLeadShape) { $TRG_AFTER } else { $TRG_WITH }
            $eff = $seq.AddEffect($sh, $ArtEffect, $LEVEL_NONE, $trigger)
            $eff.Timing.Duration = 0.45
            if ($isLeadShape -and -not $OnClick) { $eff.Timing.TriggerDelayTime = 0.25 }
            $added++; $isLeadShape = $false
        }
    }

    Step ("added {0} effect(s) across {1} slide(s)" -f $added, $pres.Slides.Count)

    # PowerPoint embeds the deck's typefaces itself on this save. It can only
    # embed what it has installed, which is why this replaced hand-injecting the
    # template's own font parts: those went into the package correctly declared
    # and the title face still would not bind. msoTrue = -1; the second flag
    # embeds the whole character set rather than the characters used so far, so
    # editing the deck later does not run out of glyphs.
    # Font embedding is an argument to SaveAs, not a property on the
    # presentation - setting it as a property throws, and because that happens
    # before the save the whole animation pass is lost without writing back.
    # SaveAs(name, ppSaveAsOpenXMLPresentation = 24, EmbedTrueTypeFonts = msoTrue).
    $pres.SaveAs($local, 24, -1)
    $pres.Close()
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($pres)
    $pres = $null

    # The Morph is written as XML by Restyle-Deck, and the save above is a full
    # PowerPoint round-trip through PowerPoint's own model - exactly where an
    # unrecognised p159:morph is normalised away with nothing reported. So
    # reopen the SAVED package and make PowerPoint itself say it accepted it.
    # ppEntryEffectMorphByObject = 3954. The XML alone does not prove it.
    Step 'PowerPoint: verifying the Morph survived the round-trip'
    $pres = $app.Presentations.Open($local, $true, $false, $false)
    $slideCount = $pres.Slides.Count
    $badMorph = @()
    foreach ($i in 1..$slideCount) {
        $ee = [int]$pres.Slides.Item($i).SlideShowTransition.EntryEffect
        if ($ee -ne 3954) { $badMorph += ("slide {0} (EntryEffect {1})" -f $i, $ee) }
    }
    $pres.Close()
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($pres)
    $pres = $null
    if ($badMorph.Count -gt 0) {
        # Thrown BEFORE the copy-back below, so a deck whose Morph was dropped
        # is never written over the one on disk.
        throw ("Morph not accepted by PowerPoint on {0} of {1} slide(s): {2}" -f `
               $badMorph.Count, $slideCount, (($badMorph | Select-Object -First 8) -join '; '))
    }
    Step ("Morph verified: EntryEffect 3954 on {0} of {0} slide(s)" -f $slideCount)
} finally {
    if ($pres) { $pres.Close(); [void][Runtime.InteropServices.Marshal]::ReleaseComObject($pres) }
    if ($app)  { $app.Quit();  [void][Runtime.InteropServices.Marshal]::ReleaseComObject($app) }
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
}

Copy-Item -LiteralPath $local -Destination $Deck -Force
Step ("wrote {0} ({1:N1} MB)" -f (Split-Path $Deck -Leaf), ((Get-Item $Deck).Length / 1MB))
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
