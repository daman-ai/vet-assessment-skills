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

    A RULE THAT CHECKED NOTHING IS NOT A PASS, AND FOUR OF THESE USED TO BE.

    -TemplatePath, -Plan, -NumberSlotByLayout, -Rto and -Cricos were all
    optional, and four blocking rules sat behind them. Omit -Plan and the gate
    wrote "per-topic count and chip rules skipped - no -Plan given" into $info
    and returned Ok: the 15-slide floor, the speaker-notes rule and the chip
    rule had not run, and the caller saw PASS. Omit -TemplatePath and the
    residual-placeholder sweep did the same. Omit -NumberSlotByLayout and the
    printed-number rule fell back to guessing that the last text shape holds the
    number - on a template where two layouts legitimately have none. Omit -Rto
    and a deck whose document properties name a competitor's RTO code passed
    with an info line suggesting the caller confirm it themselves.

    An info line is not a failure. Every one of those now FAILS and names the
    input it needs. -AllowPartial is the only way past: it turns each into a
    loud PARTIAL RUN warning, returns them on .Partial, and the caller must
    record that list in the stage ledger (Add-StageRecord -Partial), where the
    delivery report has to carry it.

    Requires Build-FromTemplate.ps1 and Pptx-Blocks.ps1 dot-sourced first.

    ASCII only in this file.
#>

# No Set-StrictMode - dot-sourced.

function Get-DeckIdentityStringFromAssets {
    <#  The identity strings of EVERY brand whose profile is on disk, plus the
        tagline words the templates ship, harvested from the branding profiles
        rather than typed. Read the field NAMES from the RTO profile schema
        where it declares them, so a field added to the schema is covered here
        without editing this file - a hand-listed check set is the failure this
        skill has shipped more than once.

        Returns every brand's strings, not just the template's, because the
        caller may not know which brand's template it was handed, and a string
        that belongs to some RTO's identity is never a placeholder to fill.  #>
    [CmdletBinding()]
    param([string] $AssetsDir)

    $out = New-Object System.Collections.Generic.List[string]
    $roots = New-Object System.Collections.Generic.List[string]
    if ($AssetsDir) { $roots.Add($AssetsDir) }
    else {
        #  $PSScriptRoot is set when this file is dot-sourced by path, which is
        #  how every caller loads it. It is EMPTY when the text is run as a
        #  scriptblock - a known harness artefact on this machine - so each
        #  candidate is guarded and an unresolved root is skipped rather than
        #  crashing. Deriving nothing is then caught by the caller, loudly.
        $here = ''
        $cands = @($PSScriptRoot)
        if ($MyInvocation.MyCommand.Path) { $cands += (Split-Path -Parent $MyInvocation.MyCommand.Path) }
        if (Get-Variable -Name SkillDir -Scope Global -ErrorAction SilentlyContinue) { $cands += (Join-Path $global:SkillDir 'scripts') }
        foreach ($c in $cands) {
            if ("$c".Trim() -and (Test-Path -LiteralPath "$c")) { $here = "$c"; break }
        }
        if ($here) {
            $skill = Split-Path -Parent $here
            if ($skill) {
                $roots.Add((Join-Path $skill 'assets'))
                $sib = Split-Path -Parent $skill
                if ($sib) { $roots.Add((Join-Path $sib 'assessment\assets')) }
            }
        }
    }

    #  Field names from the schema when it declares them; the four that name an
    #  organisation otherwise. Codes and names only - never an address or a
    #  phone number, which are long enough to collide with real slide text.
    $fields = @('tradingName', 'legalEntity', 'shortName', 'rtoCode', 'cricosCode', 'website', 'domain', 'accreditationBody')
    foreach ($r in $roots) {
        $schema = Join-Path $r 'rto-profile.schema.json'
        if (Test-Path -LiteralPath $schema) {
            try {
                $sj = [IO.File]::ReadAllText($schema) | ConvertFrom-Json
                $decl = @()
                if ($sj.PSObject.Properties.Name -contains 'identityFields') {
                    foreach ($k in @('required', 'optional')) {
                        if ($sj.identityFields.PSObject.Properties.Name -contains $k) {
                            $decl += @($sj.identityFields.$k | ForEach-Object { [string]$_ })
                        }
                    }
                }
                if ($decl.Count -gt 0) { $fields = @($decl | Where-Object { $_ -notmatch '(?i)address|phone' }) }
            }
            catch { }
        }
    }

    foreach ($r in $roots) {
        if (-not (Test-Path -LiteralPath $r)) { continue }
        foreach ($f in @(Get-ChildItem -LiteralPath $r -Filter 'branding.*.json' -File -ErrorAction SilentlyContinue)) {
            try { $j = [IO.File]::ReadAllText($f.FullName) | ConvertFrom-Json } catch { continue }
            #  Identity lives under an "rto" object in a branding profile and
            #  at the root in an RTO profile pack. Search both, plus the
            #  tagline the templates print, which is template text and never a
            #  placeholder. Looking only at the root returned nothing at all
            #  and would have thrown on every build.
            $bags = New-Object System.Collections.Generic.List[object]
            $bags.Add($j)
            foreach ($nest in @('rto', 'identity', 'organisation')) {
                if ($j.PSObject.Properties.Name -contains $nest -and $j.$nest -is [pscustomobject]) { $bags.Add($j.$nest) }
            }
            $wanted = @($fields) + @('tagline')
            foreach ($bag in $bags) {
                foreach ($name in $wanted) {
                    if ($bag.PSObject.Properties.Name -notcontains $name) { continue }
                    $v = "$($bag.$name)".Trim()
                    if ($v.Length -lt 4) { continue }
                    if (-not $out.Contains($v)) { $out.Add($v) }
                    if ($name -eq 'rtoCode')    { $x = "RTO $v";    if (-not $out.Contains($x)) { $out.Add($x) } }
                    if ($name -eq 'cricosCode') { $x = "CRICOS $v"; if (-not $out.Contains($x)) { $out.Add($x) } }
                }
            }
        }
    }
    return $out.ToArray()
}
function Get-DeckPlaceholderPhrase {
    <#  Every distinct run of text the TEMPLATE ships, as the placeholder
        vocabulary. Harvested rather than hard-coded, so the list cannot drift
        away from the template it is meant to police.

        Footer, RTO and tagline strings are excluded: those are template text
        that is SUPPOSED to survive into the built deck.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $TemplatePath,
        #  The template RTO's own identity strings - trading name, RTO code,
        #  CRICOS code, tagline. They are template text that is SUPPOSED to
        #  survive into the built deck, so they must not enter the placeholder
        #  vocabulary. Until 4 Sep 2026 one RTO's were TYPED HERE, which made
        #  this gate wrong for every other RTO: a second college's template
        #  would have its own branding read as unfilled placeholder text. The
        #  caller passes them; absent, they are derived from the branding
        #  profiles on disk. Nothing about any RTO is written into this file.
        [string[]] $TemplateIdentity
    )

    if ($null -eq $TemplateIdentity -or @($TemplateIdentity | Where-Object { "$_".Trim() }).Count -eq 0) {
        $TemplateIdentity = @(Get-DeckIdentityStringFromAssets)
    }
    $identityRx = @()
    foreach ($s in @($TemplateIdentity | Where-Object { "$_".Trim().Length -ge 4 })) {
        $identityRx += [regex]::Escape("$s".Trim())
    }

    $wd = Expand-Docx -Path $TemplatePath
    try {
        $keep = New-Object System.Collections.Generic.HashSet[string]
        foreach ($p in (Get-DeckSlideOrder -WorkDir $wd)) {
            $xml = Get-DocxPart -WorkDir $wd -Part "ppt/slides/$p"
            foreach ($m in [regex]::Matches($xml, '<a:t>([^<]*)</a:t>')) {
                $t = $m.Groups[1].Value.Trim()
                if ($t.Length -lt 8) { continue }                       # digits, bullets, arrows
                #  Derived, never typed: the template RTO's own identity and
                #  tagline text belongs to the template and is not a placeholder.
                $isIdentity = $false
                foreach ($rx in $identityRx) { if ($t -match $rx) { $isIdentity = $true; break } }
                if ($isIdentity) { continue }
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

        -Plan describes what the build intended, so the structural rules can be
        checked at all. One entry per slide, in deck order:

            @{ Tag = '1.1 concept'; Topic = 1; Kind = 'teaching' }

        Kind is one of: title, housekeeping, agenda, assessment-orientation,
        divider, outcomes, teaching, case-study, figures, process, table,
        assessment-link, recap, briefing, thanks, brandref.

        -TemplatePath, -Plan, -NumberSlotByLayout, -Rto and -Cricos each carry a
        BLOCKING rule. Leave one out and the gate fails, naming it, because the
        rule behind it did not run.

        -AllowPartial records those omissions as deliberate, reported decisions:
        each becomes a loud warning instead of a failure, and all of them come
        back on .Partial for the caller to write into the stage ledger.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [string]    $TemplatePath,
        [array]     $Plan,
        [int]       $MinSlidesPerTopic = 15,
        [hashtable] $NumberSlotByLayout,
        [string]    $Rto,
        [string]    $Cricos,
        [switch]    $AllowPartial
    )

    $wd = if ((Get-Item -LiteralPath $Path).PSIsContainer) { $Path } else { Expand-Docx -Path $Path }

    $fail    = New-Object System.Collections.Generic.List[string]
    $warn    = New-Object System.Collections.Generic.List[string]
    $info    = New-Object System.Collections.Generic.List[string]
    $partial = New-Object System.Collections.Generic.List[string]

    #  ONE place decides what a missing input means, so no rule can quietly
    #  invent a gentler answer for itself. Every caller of this block is a
    #  BLOCKING rule that could not run.
    $partialRule = {
        param([string] $Rule, [string] $Fix, [string] $Why)
        $partial.Add($Rule)
        if ($AllowPartial) {
            $warn.Add("PARTIAL RUN - $Rule checked nothing. $Why Record it in the stage ledger with -Partial and a note.")
        } else {
            $fail.Add("$Rule checked nothing - $Fix, or pass -AllowPartial to record the omission as a deliberate, reported decision. $Why")
        }
    }

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
    else {
        & $partialRule 'residual placeholder sweep (-TemplatePath)' `
            'pass -TemplatePath, the same template this deck was cloned from' `
            "The vocabulary is harvested from the template itself, so without the template there is no vocabulary and the sweep compares against nothing. An unfilled slot then ships the exemplar's own words into a classroom."
    }

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
    #  The identity rule cannot run without being told whose deck this is, and
    #  "confirm it yourself" is not a gate. Both codes come from the RTO profile
    #  pack, never typed here.
    if (-not $Rto) {
        & $partialRule 'document-property identity, RTO (-Rto)' `
            "pass -Rto from the RTO profile pack's identity strings" `
            'The approved template was cloned from another RTO and still carried that RTO code in docProps, where nothing on a slide shows it and every exported PDF carries it.'
    }
    if (-not $Cricos) {
        & $partialRule 'document-property identity, CRICOS (-Cricos)' `
            "pass -Cricos from the RTO profile pack's identity strings" `
            'Same part, same clone, same invisibility on the page.'
    }

    if ($props.Trim()) {
        foreach ($m in [regex]::Matches($props, '(?i)\bRTO\s*#?\s*:?\s*(\d{4,6})\b')) {
            $code = $m.Groups[1].Value
            if ($Rto -and $code -ne $Rto) {
                $fail.Add("document properties name RTO $code, but this deck is branded RTO $Rto")
            } elseif (-not $Rto) {
                $warn.Add("document properties name RTO $code and nothing checked it - no -Rto was given")
            }
        }
        foreach ($m in [regex]::Matches($props, '(?i)\bCRICOS\s*#?\s*:?\s*([0-9]{5}[0-9A-Z])\b')) {
            $code = $m.Groups[1].Value
            if ($Cricos -and $code -ne $Cricos) {
                $fail.Add("document properties name CRICOS $code, but this deck is branded CRICOS $Cricos")
            } elseif (-not $Cricos) {
                $warn.Add("document properties name CRICOS $code and nothing checked it - no -Cricos was given")
            }
        }
        # An unstamped clone still calls itself a template. A delivered deck
        # never should.
        $t = [regex]::Match($props, '(?i)\b([A-Za-z ]*Branded[A-Za-z ]*Template)\b')
        if ($t.Success) { $fail.Add("document properties still carry the template's own title: `"$($t.Groups[1].Value.Trim())`"") }
    } else { $info.Add('no document properties found to check') }

    # ---- slide numbering
    #
    # WHICH SHAPE HOLDS THE NUMBER IS DECLARED, NOT GUESSED. Without the layout
    # map and the plan that says which layout each slide came from, the rule
    # below falls back to "the last text shape", and on this template two
    # layouts legitimately have no number at all - so the fallback reports a
    # correct thank-you slide as a defect and can miss a real wrong number in a
    # slot that is not last. A rule running on a guess is not the rule.
    if (-not ($NumberSlotByLayout -and $Plan -and $Plan.Count)) {
        & $partialRule 'printed slide number (-NumberSlotByLayout with -Plan)' `
            'pass -NumberSlotByLayout (Get-DeckNumberSlotMap -Profile $dp) together with -Plan' `
            'The footer number is literal text, not a field, so a cloned slide keeps the exemplar number: the reference deck prints the wrong number on 19 of its 39 slides.'
    }

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
    else {
        & $partialRule 'speaker notes, assessment chips and slides per Topic (-Plan)' `
            'pass -Plan, one entry per slide in deck order, from the same plan the build rendered' `
            'Without it nothing knows which slide is a teaching slide, so the 15-slides-per-Topic floor, the speaker-notes rule and the chip rule all pass on nothing - and a trainer finds that out in front of a class.'
    }

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
        Ok           = ($fail.Count -eq 0)
        Failures     = $fail
        Warnings     = $warn
        Info         = $info
        Partial      = $partial          # blocking rules that could not run
        AllowPartial = [bool]$AllowPartial
        Slides       = $order.Count
    }
}

function Write-DeckRuleReport {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)] $Result)
    process {
        Write-Host ''
        Write-Host "DECK GATE - $($Result.Slides) slides" -ForegroundColor Cyan
        if ($Result.Partial -and @($Result.Partial).Count) {
            Write-Host ("  !  PARTIAL RUN - {0} blocking rule(s) checked nothing: {1}" -f `
                        @($Result.Partial).Count, (@($Result.Partial) -join '; ')) -ForegroundColor Magenta
            Write-Host '     Record every one of them in the stage ledger (Add-StageRecord -Partial) and in the build report.' -ForegroundColor Magenta
        }
        foreach ($i in $Result.Info)     { Write-Host "  .  $i"  -ForegroundColor DarkGray }
        foreach ($w in $Result.Warnings) { Write-Host "  ~  $w"  -ForegroundColor Yellow }
        foreach ($f in $Result.Failures) { Write-Host "  X  $f"  -ForegroundColor Red }
        if ($Result.Ok -and @($Result.Partial).Count) {
            Write-Host ("  PASS - PARTIAL, {0} rule(s) not run" -f @($Result.Partial).Count) -ForegroundColor Yellow
        }
        elseif ($Result.Ok) { Write-Host '  PASS' -ForegroundColor Green }
        else                { Write-Host "  FAIL - $($Result.Failures.Count) blocking" -ForegroundColor Red }
        Write-Host ''
    }
}
