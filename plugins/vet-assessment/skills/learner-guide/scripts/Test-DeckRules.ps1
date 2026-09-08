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

    AND A SUPPLIED INPUT THAT YIELDS NOTHING IS THE SAME HOLE ONE LEVEL DOWN.
    $partialRule above covers an input that was never passed. It does not cover
    an input that WAS passed and yielded an empty set: a -TemplatePath whose
    template harvests zero placeholder phrases sweeps every slide against a
    vocabulary of nothing and reports clean; a -Plan with no entries runs the
    per-Topic, notes and chip rules over nothing; a -NumberSlotByLayout with no
    layouts leaves the printed-number rule with no slot to read. Each is now a
    typed CHECK-SET EMPTY refusal naming that input (Lib-GateCommon), and every
    rule is a registered ARM returned on .Arms and printed as one ARMS: line.

    -SelfTest (this file run as a script, not dot-sourced) builds an unpacked
    deck fixture and proves: a clean deck passes with every arm ran; a deck
    whose printed slide number disagrees with its position FAILS; a supplied
    template that yields no placeholder phrase is a refusal naming it.

    ASCII only in this file.
#>

# GATE: stages=4,7c; requires=Path,TemplatePath,Plan,NumberSlotByLayout,Rto,Cricos

param(
    #  NAMED DeckRulesSelfTest and reached as -SelfTest through the alias, for
    #  the reason Lib-GateCommon states: a dot-sourced script binds its
    #  parameters as variables in the CALLER's scope, so a parameter called
    #  $SelfTest here would set every caller's own -SelfTest switch to $false
    #  the moment it dot-sourced this file.
    [Alias('SelfTest')]
    [switch] $DeckRulesSelfTest
)

# No Set-StrictMode - dot-sourced.

#  The shared gate library, loaded only if a caller has not already loaded it.
#  Dot-sourcing it twice is harmless; not having it at all makes every arm on
#  this gate silently absent, which is the defect the roster exists to end.
if (-not (Get-Command -Name 'Register-GateArm' -ErrorAction SilentlyContinue)) {
    $__dr_here = $PSScriptRoot
    if (-not $__dr_here -and $MyInvocation.MyCommand.Path) { $__dr_here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if ($__dr_here -and (Test-Path -LiteralPath (Join-Path $__dr_here 'Lib-GateCommon.ps1'))) {
        . (Join-Path $__dr_here 'Lib-GateCommon.ps1')
    }
}

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

    #  THE ARM ROSTER. Registered before any rule runs, so a rule that never
    #  finishes is visible as not-run rather than absent from the report. An
    #  arm whose input was never PASSED ends 'empty' and $partialRule has
    #  already decided what that means; an arm whose input WAS passed and
    #  yielded nothing is a typed CHECK-SET EMPTY refusal, which is the case
    #  $partialRule cannot see.
    Reset-GateArmRoster
    Register-GateArm -Name 'slides' -Blocking
    Register-GateArm -Name 'placeholder-vocabulary' -Blocking:(-not $AllowPartial)
    Register-GateArm -Name 'docprops-identity' -Blocking:(-not $AllowPartial)
    Register-GateArm -Name 'printed-number' -Blocking:(-not $AllowPartial)
    Register-GateArm -Name 'plan-structure' -Blocking:(-not $AllowPartial)
    Register-GateArm -Name 'overset-text'

    $order = @(Get-DeckSlideOrder -WorkDir $wd)
    $info.Add("slides: $($order.Count)")
    Write-GateCheckSet -What 'slide(s) in presentation order' -Count $order.Count -DerivedFrom 'ppt/presentation.xml sldIdLst joined to the presentation rels' -Blocking -Input ($Path + ' - presentation.xml lists no slide, so every per-slide rule below would sweep nothing')
    Complete-GateArm -Name 'slides' -State 'ran' -Size $order.Count

    # ---- package integrity first; nothing else matters if it will not open
    $pkg = Test-PptxPackage -WorkDir $wd
    if (-not $pkg.Ok) { foreach ($i in $pkg.Issues) { $fail.Add("package: $i") } }

    # ---- residual template placeholder text
    if ($TemplatePath) {
        $phrases = Get-DeckPlaceholderPhrase -TemplatePath $TemplatePath
        #  A TEMPLATE THAT YIELDS NO PHRASE IS THE STARVED ARM. The sweep below
        #  compares every slide's text against this vocabulary; an empty one
        #  matches nothing and reports every slide clean.
        Write-GateCheckSet -What 'template placeholder phrase(s)' -Count @($phrases).Count -DerivedFrom ('the template itself: ' + (Split-Path $TemplatePath -Leaf)) -Blocking -Input ($TemplatePath + ' - the template was read and yielded no placeholder phrase, so the residual-placeholder sweep would compare every slide against nothing')
        Complete-GateArm -Name 'placeholder-vocabulary' -State 'ran' -Size @($phrases).Count
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
        Complete-GateArm -Name 'placeholder-vocabulary' -State 'empty'
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
    if ($Rto -or $Cricos) {
        #  The docProps parts themselves are the check-set. Passing -Rto over a
        #  package with no readable docProps sweeps nothing and reports clean.
        Write-GateCheckSet -What 'character(s) of document-property text swept' -Count $props.Trim().Length -DerivedFrom 'docProps/core.xml and docProps/app.xml, tags stripped' -Blocking -Input ($Path + ' docProps/core.xml + docProps/app.xml - -Rto/-Cricos were supplied and neither part yielded any text, so the identity rule swept nothing')
        Complete-GateArm -Name 'docprops-identity' -State 'ran' -Size $props.Trim().Length
    }
    else { Complete-GateArm -Name 'docprops-identity' -State 'empty' }

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
        Complete-GateArm -Name 'printed-number' -State 'empty'
    }
    else {
        #  A layout map that was SUPPLIED and names no layout leaves the rule
        #  with no declared slot on any slide, so it falls back to a guess or
        #  checks nothing at all.
        Write-GateCheckSet -What 'layout(s) declaring which slot holds the printed number' -Count $NumberSlotByLayout.Count -DerivedFrom '-NumberSlotByLayout (Get-DeckNumberSlotMap over the deck profile)' -Blocking -Input '-NumberSlotByLayout was supplied and names no layout, so no slide has a declared number slot and the rule would run on a guess'
        Complete-GateArm -Name 'printed-number' -State 'ran' -Size $NumberSlotByLayout.Count
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
        Write-GateCheckSet -What 'planned slide entry/entries' -Count @($Plan).Count -DerivedFrom '-Plan, one entry per slide in deck order, from the same plan the build rendered' -Blocking -Input '-Plan was supplied and describes no slide, so the per-Topic floor, the speaker-notes rule and the chip rule would all run over nothing'
        Complete-GateArm -Name 'plan-structure' -State 'ran' -Size @($Plan).Count
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
        Complete-GateArm -Name 'plan-structure' -State 'empty'
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
    if ($order.Count -gt 0) { Complete-GateArm -Name 'overset-text' -State 'ran' -Size $order.Count -Findings @($warn | Where-Object { $_ -like '*likely to overflow*' }).Count }
    else { Complete-GateArm -Name 'overset-text' -State 'empty' }

    #  The roster, printed as the one ARMS: line both runners parse and
    #  returned on .Arms for the results file. Assert-GateArmsComplete is NOT
    #  called here: this is a dot-sourced library, the caller owns the exit
    #  code, and $partialRule has already decided what an input that was never
    #  passed means. What the roster adds is that a rule which ran over an
    #  EMPTY supplied input can no longer be reported as a rule that ran.
    $arms = Write-GateArmRoster

    return [pscustomobject]@{
        Ok           = ($fail.Count -eq 0)
        Failures     = $fail
        Warnings     = $warn
        Info         = $info
        Partial      = $partial          # blocking rules that could not run
        Arms         = $arms
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

# ---------------------------------------------------------------------------
# SELF-TEST
#
# Runs ONLY when this file is executed as a script with -SelfTest. A dot-source
# has InvocationName '.', and $DeckRulesSelfTest is $false besides, so a caller
# loading this library can never trip it.
#
# Every case is built as an UNPACKED deck directory, which Test-DeckRules
# accepts directly, so nothing here needs PowerPoint. The template the
# placeholder sweep harvests from is a real .pptx, zipped from the same shape,
# because Get-DeckPlaceholderPhrase unpacks what it is given.
# ---------------------------------------------------------------------------

function New-DrFixtureDeck {
    <#  A two-slide unpacked deck. -PlaceholderText puts the template's own
        exemplar sentence back on slide 2; -WrongNumber prints '9' where the
        second slide's number belongs; -Bare writes slides whose only text is
        too short to enter a placeholder vocabulary.  #>
    param([Parameter(Mandatory)][string] $Dir, [switch] $PlaceholderText, [switch] $WrongNumber, [switch] $Bare)
    $e = New-Object System.Text.UTF8Encoding($false)
    foreach ($sub in @('ppt\slides\_rels', 'ppt\_rels', 'ppt\slideLayouts', 'docProps')) {
        New-Item -ItemType Directory -Force -Path (Join-Path $Dir $sub) | Out-Null
    }
    $ct = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
          '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
          '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
          '<Default Extension="xml" ContentType="application/xml"/>' +
          '<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>' +
          '<Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>' +
          '<Override PartName="/ppt/slides/slide2.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>' +
          '</Types>'
    [System.IO.File]::WriteAllText((Join-Path $Dir '[Content_Types].xml'), $ct, $e)
    $pres = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
            '<p:sldIdLst><p:sldId id="256" r:id="rId1" /><p:sldId id="257" r:id="rId2" /></p:sldIdLst></p:presentation>'
    [System.IO.File]::WriteAllText((Join-Path $Dir 'ppt\presentation.xml'), $pres, $e)
    $prels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
             '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
             '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>' +
             '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide2.xml"/>' +
             '</Relationships>'
    [System.IO.File]::WriteAllText((Join-Path $Dir 'ppt\_rels\presentation.xml.rels'), $prels, $e)

    $mkSlide = {
        param([int] $Index, [string[]] $Runs)
        $shapes = ''
        $i = 0
        foreach ($r in $Runs) {
            $i++
            $shapes += ('<p:sp><p:nvSpPr><p:cNvPr id="{0}" name="Text {0}"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr/><p:txBody><a:bodyPr/><a:p><a:r><a:t>{1}</a:t></a:r></a:p></p:txBody></p:sp>' -f $i, $r)
        }
        return ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
                '<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">' +
                '<p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>' + $shapes + '</p:spTree></p:cSld></p:sld>')
    }
    $exemplar = 'Section one title goes here'
    if ($Bare) {
        $s1 = & $mkSlide 1 @('1')
        $s2 = & $mkSlide 2 @('2')
    }
    else {
        $s1 = & $mkSlide 1 @('The fixture opening line for slide one', '1')
        $second = @('The fixture teaching line for slide two')
        if ($PlaceholderText) { $second += $exemplar }
        $second += $(if ($WrongNumber) { '9' } else { '2' })
        $s2 = & $mkSlide 2 $second
    }
    [System.IO.File]::WriteAllText((Join-Path $Dir 'ppt\slides\slide1.xml'), $s1, $e)
    [System.IO.File]::WriteAllText((Join-Path $Dir 'ppt\slides\slide2.xml'), $s2, $e)
    $srels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
             '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
             '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>' +
             '</Relationships>'
    foreach ($n in @('slide1.xml', 'slide2.xml')) {
        [System.IO.File]::WriteAllText((Join-Path $Dir ('ppt\slides\_rels\' + $n + '.rels')), $srels, $e)
    }
    [System.IO.File]::WriteAllText((Join-Path $Dir 'ppt\slideLayouts\slideLayout1.xml'), '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sldLayout xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"/>', $e)
    [System.IO.File]::WriteAllText((Join-Path $Dir 'docProps\core.xml'), '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"><cp:keywords>Fixture deck, fixture college</cp:keywords></cp:coreProperties>', $e)
    #  BOTH docProps parts. Get-DocxPart throws on a part that is not present,
    #  and -ErrorAction does not soften a throw, so a package missing app.xml
    #  takes the identity rule down with it.
    [System.IO.File]::WriteAllText((Join-Path $Dir 'docProps\app.xml'), '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"><Company>Fixture College</Company></Properties>', $e)
    return $Dir
}

function New-DrFixturePptx {
    <# Zip an unpacked fixture into a real .pptx, which is what the placeholder harvester unpacks. #>
    param([Parameter(Mandatory)][string] $Dir, [Parameter(Mandatory)][string] $OutFile)
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $OutFile) { Remove-Item -LiteralPath $OutFile -Force }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($Dir, $OutFile)
    return $OutFile
}

function Invoke-DeckRulesSelfTest {
    $ok = 0; $bad = 0
    function DrOk  { param([string] $M) Write-Host ("    ok   {0}" -f $M) -ForegroundColor Green; $script:DrOk++ }
    function DrBad { param([string] $M) Write-Host ("    X    {0}" -f $M) -ForegroundColor Red;   $script:DrBad++ }
    $script:DrOk = 0; $script:DrBad = 0

    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('dr-selftest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    Write-Host ''
    Write-Host '  Test-DeckRules SELF-TEST - a clean result is not believed until the gate has failed on a planted defect' -ForegroundColor Cyan
    try {
        New-Item -ItemType Directory -Force -Path $root | Out-Null

        #  The template the placeholder vocabulary is harvested from.
        $tplDir = New-DrFixtureDeck -Dir (Join-Path $root 'tpl') -PlaceholderText
        $tpl = New-DrFixturePptx -Dir $tplDir -OutFile (Join-Path $root 'template.pptx')
        $phrases = Get-DeckPlaceholderPhrase -TemplatePath $tpl
        if (@($phrases).Count -eq 0) { DrBad 'the fixture template harvested no placeholder phrase, so no case below proves anything' }
        else { DrOk ("the fixture template harvests {0} placeholder phrase(s)" -f @($phrases).Count) }

        $plan = @(
            @{ Tag = 'title'; Topic = 1; Kind = 'title'; LayoutSlide = 1; Verbatim = $true },
            @{ Tag = '1.1 concept'; Topic = 1; Kind = 'teaching'; LayoutSlide = 1 }
        )
        $slotMap = @{ 1 = 2 }

        #  CASE 0: the clean deck. Every arm ran, no blocking failure that is
        #  about a starved rule.
        $clean = New-DrFixtureDeck -Dir (Join-Path $root 'clean')
        $r0 = Test-DeckRules -Path $clean -TemplatePath $tpl -Plan $plan -MinSlidesPerTopic 1 -NumberSlotByLayout $slotMap -Rto '99999' -Cricos '00000X'
        $notRan = @($r0.Arms | Where-Object { $_.blocking -and $_.state -ne 'ran' })
        if ($notRan.Count -eq 0) { DrOk ("clean deck: every blocking arm ran - " + (($r0.Arms | ForEach-Object { $_.name + '=' + $_.state + '/' + $_.size }) -join ', ')) }
        else { DrBad ("clean deck left blocking arm(s) not ran: " + (($notRan | ForEach-Object { $_.name + '=' + $_.state }) -join ', ')) }
        if (@($r0.Partial).Count -eq 0) { DrOk 'clean deck: no rule recorded as partial' }
        else { DrBad ("clean deck recorded partial rule(s): " + (@($r0.Partial) -join '; ')) }

        #  CASE 1: the template's own exemplar sentence left on a slide.
        $dirty = New-DrFixtureDeck -Dir (Join-Path $root 'dirty') -PlaceholderText
        $back = [System.IO.File]::ReadAllText((Join-Path $dirty 'ppt\slides\slide2.xml'), [System.Text.Encoding]::UTF8)
        if ($back.IndexOf('Section one title goes here', [System.StringComparison]::Ordinal) -lt 0) { DrBad 'plant 1 did not land: the placeholder sentence is not on the fixture slide' }
        else {
            Write-Host '    plant landed: the template exemplar sentence is still on slide 2' -ForegroundColor DarkGray
            $r1 = Test-DeckRules -Path $dirty -TemplatePath $tpl -Plan $plan -MinSlidesPerTopic 1 -NumberSlotByLayout $slotMap -Rto '99999' -Cricos '00000X'
            $hit = @($r1.Failures | Where-Object { $_ -like '*template placeholder text*' })
            if (-not $r1.Ok -and $hit.Count -gt 0) { DrOk ("residual template placeholder text fails naming the slide: " + $hit[0]) }
            else { DrBad ("residual placeholder text did not fail. Failures: " + (@($r1.Failures) -join ' | ')) }
        }

        #  CASE 2: the printed number disagreeing with the slide's position.
        $wrong = New-DrFixtureDeck -Dir (Join-Path $root 'wrongnum') -WrongNumber
        $backW = [System.IO.File]::ReadAllText((Join-Path $wrong 'ppt\slides\slide2.xml'), [System.Text.Encoding]::UTF8)
        if ($backW -notmatch '<a:t>9</a:t>') { DrBad 'plant 2 did not land: slide 2 does not print 9' }
        else {
            Write-Host '    plant landed: slide 2 prints the number 9' -ForegroundColor DarkGray
            $r2 = Test-DeckRules -Path $wrong -TemplatePath $tpl -Plan $plan -MinSlidesPerTopic 1 -NumberSlotByLayout $slotMap -Rto '99999' -Cricos '00000X'
            $hit2 = @($r2.Failures | Where-Object { $_ -match '(?i)number' })
            if (-not $r2.Ok -and $hit2.Count -gt 0) { DrOk ("a wrong printed slide number fails: " + $hit2[0]) }
            else { DrBad ("the wrong printed number did not fail. Failures: " + (@($r2.Failures) -join ' | ')) }
        }

        #  CASE 3: THE STARVED ARM. A template that WAS supplied and yields no
        #  placeholder phrase - the sweep would compare every slide against
        #  nothing and report clean. Typed refusal naming the template.
        $bareDir = New-DrFixtureDeck -Dir (Join-Path $root 'bare') -Bare
        $bareTpl = New-DrFixturePptx -Dir $bareDir -OutFile (Join-Path $root 'bare-template.pptx')
        if (@(Get-DeckPlaceholderPhrase -TemplatePath $bareTpl).Count -ne 0) { DrBad 'plant 3 did not land: the bare template still yields a placeholder phrase' }
        else {
            Write-Host '    plant landed: the supplied template yields no placeholder phrase at all' -ForegroundColor DarkGray
            $msg = ''
            try { [void](Test-DeckRules -Path $clean -TemplatePath $bareTpl -Plan $plan -MinSlidesPerTopic 1 -NumberSlotByLayout $slotMap -Rto '99999' -Cricos '00000X') }
            catch { $msg = $_.Exception.Message }
            if ($msg -match '^CHECK-SET EMPTY' -and $msg.IndexOf('bare-template.pptx', [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                DrOk 'a supplied template that yields no placeholder phrase is a CHECK-SET EMPTY refusal naming the template'
            }
            else { DrBad ("the starved placeholder vocabulary did not refuse by name; got: " + $(if ($msg) { $msg } else { '(no refusal at all)' })) }
        }

        #  CASE 4: a -Plan that WAS supplied and describes no slide.
        $msg4 = ''
        try { [void](Test-DeckRules -Path $clean -TemplatePath $tpl -Plan @() -MinSlidesPerTopic 1 -NumberSlotByLayout $slotMap -Rto '99999' -Cricos '00000X') }
        catch { $msg4 = $_.Exception.Message }
        #  An empty -Plan is indistinguishable from no -Plan at the parameter
        #  boundary, so this must land as the PARTIAL rule, not silently pass.
        if ($msg4 -match '^CHECK-SET EMPTY') { DrOk 'an empty -Plan is a CHECK-SET EMPTY refusal' }
        else {
            $r4 = Test-DeckRules -Path $clean -TemplatePath $tpl -Plan @() -MinSlidesPerTopic 1 -NumberSlotByLayout $slotMap -Rto '99999' -Cricos '00000X'
            if (-not $r4.Ok -and @($r4.Partial | Where-Object { $_ -like '*-Plan*' }).Count -gt 0) { DrOk 'an empty -Plan fails naming -Plan and records the rule as partial' }
            else { DrBad ("an empty -Plan neither refused nor failed. Ok=" + $r4.Ok + " partial=" + (@($r4.Partial) -join '; ')) }
        }
    }
    catch { DrBad ("the self-test itself threw: " + $_.Exception.Message) }
    finally { if ($root -and (Test-Path -LiteralPath $root)) { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue } }

    Write-Host ''
    if ($script:DrBad -eq 0) { Write-Host ("  SELF-TEST PASS - {0} check(s), every planted defect verified to have landed and then caught" -f $script:DrOk) -ForegroundColor Green; return 0 }
    Write-Host ("  SELF-TEST FAIL - {0} of {1} check(s)" -f $script:DrBad, ($script:DrOk + $script:DrBad)) -ForegroundColor Red
    return 4
}

if ($DeckRulesSelfTest -and $MyInvocation.InvocationName -ne '.') {
    $__dr_scripts = $PSScriptRoot
    if (-not $__dr_scripts -and $MyInvocation.MyCommand.Path) { $__dr_scripts = Split-Path -Parent $MyInvocation.MyCommand.Path }
    $__dr_skill = Split-Path -Parent $__dr_scripts
    #  Expand-Docx lives in the assessment skill's template library, which every
    #  real caller has already dot-sourced. Named here, not copied.
    $__dr_ftp = Join-Path (Split-Path -Parent $__dr_skill) 'assessment\scripts\Build-FromTemplate.ps1'
    if (Test-Path -LiteralPath $__dr_ftp) { . $__dr_ftp }
    . (Join-Path $__dr_scripts 'Pptx-Blocks.ps1')
    if (-not (Get-Command -Name 'Expand-Docx' -ErrorAction SilentlyContinue)) {
        Write-Host ("  X Test-DeckRules self-test: Expand-Docx is not available (looked for {0}). The placeholder harvester unpacks the template with it, so no case here could prove anything." -f $__dr_ftp) -ForegroundColor Red
        exit 4
    }
    exit (Invoke-DeckRulesSelfTest)
}
