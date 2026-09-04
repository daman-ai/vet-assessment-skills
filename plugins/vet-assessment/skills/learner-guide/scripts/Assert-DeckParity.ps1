<#
    Assert-DeckParity.ps1 - the guide and the deck are rendered from ONE spine,
    so a fact present in one and missing from the other is a build defect.

    Implements references\gates.md section 25. Runs at Stage 3c inside the spine
    gate band, and per-surface again at Stage 4 and 7c.

        scripts\Assert-DeckParity.ps1 -BuildDir $out

    WHY IT REPLACES THE REGISTRY'S GLOBAL OR. Test-FigureConsistency sums
    `require` matches across every source it can find and passes on one
    occurrence ANYWHERE. Two consequences, both measured on a real build:

      1. A registry of 32 figures against 8 deckMust terms left 24 corrected
         figures with NO deck-side requirement at all. A corrected guide beside
         an uncorrected deck is worse than either alone, because the learner
         cannot tell which document is meant.
      2. That gate scans every *.ps1 in the build directory behind a filename
         regex, so a REMEDIATION SCRIPT'S OWN COMMENT quoting the corrected
         value satisfied the requirement and the page never carried it.

    THIS GATE READS THE SPINE AND NOTHING ELSE. No *.ps1, no report file, no
    rendered extract, no gate sidecar. There is no exclusion regex to maintain,
    because there is no inclusion of anything but declared content. A hit in a
    non-content channel cannot satisfy a requirement here for the structural
    reason that the channel is never opened.

    THE TWO SURFACES ARE DERIVED, NOT LISTED. A spine node that carries a
    `layout` field is a SLIDE and everything under it is DECK-FACING; the
    `slides` property is deck-facing by name. Everything else the spine carries
    is GUIDE-FACING. Structural identifiers and build metadata are skipped
    through Lib-GateCommon's own declared list (Get-GateUnrenderedFields
    -ForSweep), so this gate cannot invent its own idea of what is prose.

    THE NAMED RULES. Every one prints how many candidates it examined, how many
    it suppressed and why, so a rule that has quietly stopped checking anything
    is visible in the log rather than believed.

      DP-REQUIRE-PER-SURFACE   blocking. Every registry `require` string must
                               appear in the guide-facing set AND in the
                               deck-facing set. An entry may NARROW itself with
                               a declared `surfaces` field (["guide"], ["deck"]);
                               narrowing is recorded and printed, never guessed.
      DP-REQUIRE-PROMPT-ONLY   REPORT. The requirement is met on a surface only
                               inside an artwork `prompt`. A prompt is content -
                               it becomes the picture - but a figure that is
                               only correct in its own generation instruction is
                               worth a reader's eye.
      DP-BENCH-PER-TOPIC       blocking. Every instrument, term and item an
                               assessor benchmark will accept must appear in
                               EACH artefact, PER TOPIC. The set is DERIVED
                               from the withhold register, which is itself
                               derived from the assessed response cells, so it
                               cannot be short. Anything the registry marks
                               assessor-only is SUBTRACTED first: a gate that
                               requires a withheld value on a learner page is a
                               gate that orders a leak.
                               SCOPED TO PARITY, and the scoping is the rule.
                               An entry one surface carries in a topic and the
                               other does not is the defect this gate is named
                               for. An entry NEITHER surface carries in that
                               topic is a coverage question and belongs to
                               Check-RowCoverage; blocking on it here fired 300+
                               times on the reference build for one reason - the
                               register's permittedGround lists everything the
                               learner holds during a task, safety data sheets
                               included, and none of that is a fact the topic
                               teaches. Both counts print.
      DP-TABLE-SHAPE           blocking, scoped. Where a slide's table echoes
                               the assessed task its chip names - it shares
                               -MinSharedHeadings or more normalised column
                               headings with that task - its row and column
                               counts must equal the task's. Scoped because a
                               teaching table that is NOT the assessed grid is
                               the correct thing to build, and comparing every
                               table to every task would fire on all of them.
                               The suppression count is printed.
      DP-NOTE-COUNT            blocking where the sentence points at the table
                               ("the table below has four rows"), REPORT where
                               it does not. A count assertion that names no
                               table is ordinary teaching prose - "teach the
                               three decisions" against a four-row table is not
                               a defect - and blocking on it is the crying-wolf
                               gate this file forbids.
      DP-NOTES-PRESENT         blocking. Every slide whose layout AND kind are
                               both off the profile's declared no-notes list
                               carries speaker notes of at least -MinNotesWords
                               words. Ten content slides shipped with none at
                               round 2 of one build.

    CAPS AND LISTS COME FROM THE PROFILE. The no-notes list is the deck
    profile's deckRules.notesNotRequiredOn, reached through the RTO profile
    pack; the notes floor and the shared-heading threshold are parameters whose
    resolved value and source are printed. Nothing here names a unit, an RTO, a
    brand or a path.

    NEVER PRINTS A MODEL ANSWER OR A BENCHMARK ROW. Row labels, column
    headings, item labels, registry field values, counts and paths only - the
    same discipline as the mirror gates beside it.

    PROVED BY PLANTING. -SelfTest builds a synthetic build directory, plants
    seven defects, VERIFIES EACH PLANT LANDED by reading the file back out of
    the exact channel the gate scans, and fails if any planted defect is not
    caught or if the clean fixture fires. One build recorded a plant that was a
    no-op as evidence a gate worked.

    PS 5.1. ASCII only in this file.
    Exit 0 clean, 1 blocking finding(s), 2 usage or input error, 4 self-test failed.
#>

[CmdletBinding()]
param(
    [string] $BuildDir,
    [string] $SpineDir,
    #  The figure registry that carries the `require` strings.
    [string] $RulesPath,
    #  The withhold register - the benchmark-derived per-topic set comes from here.
    [string] $RegisterPath,
    [string] $ContractPath,
    #  The RTO profile pack. Resolved from the contract's brand when not given.
    [string] $Profile,
    [string] $SkillDir,
    [string] $ReportPath,
    [int]    $MinNotesWords = 25,
    [int]    $MinSharedHeadings = 2,
    [switch] $SelfTest,
    [switch] $Quiet
)

#  $PSScriptRoot is EMPTY inside a PARAMETER DEFAULT when the script is run as
#  `powershell -File`, so a default that called Split-Path on it threw inside
#  the parameter block: the script exited 1 having never run a single check -
#  the same exit code it uses for a real finding, which is why nobody noticed.
#  Resolved here instead, where the automatic variable is populated, with a
#  guarded fallback for the scriptblock case.
if (-not $SkillDir) {
    $__here = $PSScriptRoot
    if (-not $__here -and $MyInvocation.MyCommand.Path) { $__here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if ($__here) { $SkillDir = Split-Path -Parent $__here }
}

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

$GATE = 'Assert-DeckParity'

# ---------------------------------------------------------------------------
# Small private helpers. Named Dp* so nothing here can collide with a shared
# helper, and so a reader knows which file to open.
# ---------------------------------------------------------------------------

function Get-DpArray {
    <#  @($null).Count is 1, not 0, and that single trap has passed more empty
        check-sets than any other in this toolchain. Everything that iterates a
        maybe-absent property goes through here.  #>
    param($Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) { return @($Value) }
    if ($Value -is [System.Collections.IEnumerable]) {
        $acc = New-Object System.Collections.Generic.List[object]
        foreach ($v in $Value) { if ($null -ne $v) { $acc.Add($v) } }
        return $acc.ToArray()
    }
    return @($Value)
}

function Get-DpWordCount {
    param([string] $Text)
    if (-not $Text) { return 0 }
    return @([regex]::Matches($Text, '[A-Za-z0-9][A-Za-z0-9''\-]*')).Count
}

function Write-DpJson {
    param([Parameter(Mandatory)] $Object, [Parameter(Mandatory)][string] $Path)
    $json = $Object | ConvertTo-Json -Depth 14
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($true)))
}

function Resolve-DpProfilePath {
    <#  Same resolution order every gate in this skill uses: an explicit
        -Profile, else assets\rto-profile.<brand>.json for the contract's own
        brand. -AnyForSelfTest takes the first pack on disk, because the
        self-test is proving the RULE fires, not which RTO it fired for.  #>
    param([string] $ProfilePath, [string] $Build, [string] $Skill, [switch] $AnyForSelfTest)
    if ($ProfilePath) {
        if (-not (Test-Path -LiteralPath $ProfilePath)) { throw "$GATE`: -Profile not found: $ProfilePath" }
        return (Resolve-Path -LiteralPath $ProfilePath).Path
    }
    $assets = Join-Path $Skill 'assets'
    $brand = ''
    if ($Build) {
        $c = Get-GateContract -BuildDir $Build
        if ($null -ne $c -and @($c.PSObject.Properties.Name) -contains 'build') {
            $brand = '' + (Get-GateProp -Object $c.build -Names @('rto', 'brand') -Default '')
        }
    }
    $packs = @(Get-ChildItem -LiteralPath $assets -Filter 'rto-profile.*.json' -File -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -notmatch '(?i)schema' })
    if ($brand) {
        $cand = @($packs | Where-Object { $_.Name -ieq ('rto-profile.' + $brand + '.json') })
        if ($cand.Count -gt 0) { return $cand[0].FullName }
    }
    if ($AnyForSelfTest -and $packs.Count -gt 0) { return $packs[0].FullName }
    throw ("$GATE`: no RTO profile. Pass -Profile, or a -BuildDir whose contract.json names build.brand with a matching assets\rto-profile.<brand>.json. The no-notes list is READ from the profile; a gate that types its own list is a second source of truth free to drift from the deck the build actually renders.")
}

function Get-DpNoNotesList {
    <#  The layouts and slide kinds that legitimately carry no speaker notes.
        DERIVED: the RTO profile pack points at the deck profile, and the deck
        profile's deckRules.notesNotRequiredOn is the list. The RTO pack's own
        noNotesReasons keys are unioned in, because that is where the written
        reason for each exemption lives and the two sets are asserted equal by
        Assert-RtoProfile. Never typed here.  #>
    param([string] $ProfileFile, [string] $Skill)

    $pack = Get-GateJson -Path $ProfileFile
    if ($null -eq $pack) { throw "$GATE`: RTO profile at $ProfileFile did not parse." }

    $deckRel = '' + (Get-GateProp -Object $pack -Names @('deckLayouts') -Default '')
    $deckPath = ''
    if ($deckRel) {
        $cand = @((Join-Path $Skill $deckRel), (Join-Path (Split-Path -Parent $ProfileFile) (Split-Path -Leaf $deckRel)))
        foreach ($c in $cand) { if (Test-Path -LiteralPath $c) { $deckPath = (Resolve-Path -LiteralPath $c).Path; break } }
    }
    if (-not $deckPath) {
        throw ("$GATE`: the RTO profile names deckLayouts '{0}' and no such file is on disk. The no-notes list lives there; without it this rule would have to guess which slides are allowed to be silent." -f $deckRel)
    }
    $deck = Get-GateJson -Path $deckPath
    $rules = Get-GateProp -Object $deck -Names @('deckRules')
    $notReq = Get-DpArray (Get-GateProp -Object $rules -Names @('notesNotRequiredOn'))
    $reasons = Get-GateProp -Object $pack -Names @('noNotesReasons')
    $reasonKeys = @()
    if ($null -ne $reasons) { $reasonKeys = @($reasons.PSObject.Properties.Name | Where-Object { $_ -notlike '_*' }) }

    $set = @{}
    foreach ($k in $notReq)     { if ("$k") { $set[("$k").ToLowerInvariant()] = $true } }
    foreach ($k in $reasonKeys) { if ("$k") { $set[("$k").ToLowerInvariant()] = $true } }
    if ($set.Count -eq 0) {
        throw ("$GATE`: the deck profile at {0} declares no deckRules.notesNotRequiredOn. An empty exemption list would make every title and divider slide a failure; an absent one is a profile defect, not a licence to invent one." -f $deckPath)
    }
    return [pscustomobject]@{
        Set        = $set
        DeckPath   = $deckPath
        FromDeck   = @($notReq | ForEach-Object { "$_" })
        FromPack   = $reasonKeys
    }
}

# ---------------------------------------------------------------------------
# The two surfaces, derived from the spine's own shape
# ---------------------------------------------------------------------------

function Get-DpSurfaceCells {
    <#  Every string the spine will put in front of a reader, tagged with the
        SURFACE it lands on.

        A node carrying a `layout` field is a slide; the property named
        `slides` is a slide array. Both, and everything beneath them, are
        DECK-FACING. Everything else is GUIDE-FACING. That is the whole rule,
        and it is read off the spine rather than off a list of field names, so
        a channel nobody has invented yet is still classified.

        ONE EXCEPTION, AND THIS GATE'S OWN SELF-TEST FOUND IT ON THE CLEAN
        FIXTURE. A visual's `spec` also carries a `layout` - the DIAGRAM
        renderer's layout, not a slide's - so without -InVisual every table
        spec on the spine read as a slide, the notes rule demanded speaker
        notes on artwork, and a correct build failed. Anything under `visuals`
        or under a `spec` is artwork the guide places, and it can never flip
        the surface.  #>
    param(
        $Node,
        [string] $File = '',
        [string] $Path = '',
        [string] $Surface = 'guide',
        [string] $Channel = '',
        [hashtable] $Skip = $null,
        [switch] $InVisual,
        [int] $Depth = 0
    )

    if ($null -eq $Node -or $Depth -gt 24) { return }

    if ($Node -is [string]) {
        if ("$Node".Trim()) {
            [pscustomobject]@{ File = $File; Path = $Path; Surface = $Surface; Channel = $Channel; Text = [string]$Node }
        }
        return
    }
    if ($Node -is [ValueType]) { return }

    if ($Node -is [System.Collections.IEnumerable]) {
        $i = 0
        foreach ($item in $Node) {
            Get-DpSurfaceCells -Node $item -File $File -Path ("{0}[{1}]" -f $Path, $i) -Surface $Surface -Channel $Channel -Skip $Skip -InVisual:$InVisual -Depth ($Depth + 1)
            $i++
        }
        return
    }

    $props = @($Node.PSObject.Properties.Name)
    if (-not $props) { return }

    $mySurface = $Surface
    if (-not $InVisual -and $props -contains 'layout' -and $Node.layout) { $mySurface = 'deck' }

    foreach ($p in $props) {
        if ($p -like '_*') { continue }
        if ($null -ne $Skip -and $Skip.ContainsKey($p)) { continue }
        $childPath = if ($Path) { "$Path.$p" } else { $p }
        $childVisual = ($InVisual -or $p -eq 'visuals' -or $p -eq 'spec')
        $childSurface = if ($p -eq 'slides' -and -not $childVisual) { 'deck' } else { $mySurface }
        $childChan = if ($Channel -and $mySurface -eq $Surface) { $Channel } else { $p }
        Get-DpSurfaceCells -Node $Node.$p -File $File -Path $childPath -Surface $childSurface -Channel $childChan -Skip $Skip -InVisual:$childVisual -Depth ($Depth + 1)
    }
}

function Get-DpSlides {
    <#  Every slide anywhere on the spine, with the file and path it sits at.
        -InVisual carries the same exception as the surface walker: a visual
        spec's `layout` is a renderer layout, not a slide layout.  #>
    param($Node, [string] $File = '', [string] $Path = '', [switch] $InVisual, [int] $Depth = 0)

    if ($null -eq $Node -or $Depth -gt 24) { return }
    if ($Node -is [string] -or $Node -is [ValueType]) { return }

    if ($Node -is [System.Collections.IEnumerable]) {
        $i = 0
        foreach ($item in $Node) {
            Get-DpSlides -Node $item -File $File -Path ("{0}[{1}]" -f $Path, $i) -InVisual:$InVisual -Depth ($Depth + 1)
            $i++
        }
        return
    }

    $props = @($Node.PSObject.Properties.Name)
    if (-not $props) { return }

    if (-not $InVisual -and $props -contains 'layout' -and $Node.layout) {
        [pscustomobject]@{ File = $File; Path = $Path; Node = $Node }
        return
    }
    foreach ($p in $props) {
        if ($p -like '_*') { continue }
        $childPath = if ($Path) { "$Path.$p" } else { $p }
        $childVisual = ($InVisual -or $p -eq 'visuals' -or $p -eq 'spec')
        Get-DpSlides -Node $Node.$p -File $File -Path $childPath -InVisual:$childVisual -Depth ($Depth + 1)
    }
}

function Get-DpTopicOf {
    <#  Which topic does this spine file belong to? Read off the file's own
        fields - topic, then the ref's leading component, then number - never
        off the file name, which is a build convention rather than data.  #>
    param($Json)
    if ($null -eq $Json) { return '' }
    $t = '' + (Get-GateProp -Object $Json -Names @('topic') -Default '')
    if ($t -match '^\s*(\d+)') { return $Matches[1] }
    $r = '' + (Get-GateProp -Object $Json -Names @('ref') -Default '')
    if ($r -match '^\s*(\d+)') { return $Matches[1] }
    $n = '' + (Get-GateProp -Object $Json -Names @('number') -Default '')
    if ($n -match '^\s*(\d+)') { return $Matches[1] }
    return ''
}

# ---------------------------------------------------------------------------
# The benchmark-derived required set, per topic
# ---------------------------------------------------------------------------

function Get-DpBenchmarkSet {
    <#  DERIVED from the withhold register, which New-WithholdRegister derives
        from the assessed response cells. Three classes:

          instrument  a named document the learner holds during the task -
                      the register's vocabulary.document entries that the
                      task's own permittedGround names.
          term        the equipment vocabulary the task's items and headings
                      name - the pack's word for the thing, which the guide and
                      the deck must both use.
          item        the subjects the benchmark accepts an answer about, from
                      the task's items and prefilledItems, matched through the
                      register's OWN alias map rather than verbatim: an item
                      reads "Chickpea and Potato Curry, 50 portions, 17.5 L,
                      chilled" on the task and "the curry" on a slide, and
                      requiring the long form would be requiring something no
                      correct artefact contains.

        Column HEADINGS are deliberately not in this set. A heading is the
        question's own scaffolding ("Why that size suited the quantity"), not a
        fact either artefact must carry, and requiring them would fire on every
        correct build. They are used by DP-TABLE-SHAPE instead.

        EVERY alias is a matcher, not only the longest. The register stems its
        aliases, so a four-word item can carry "sou vide dessert" as its
        longest alias - a string no correct artefact will ever contain. Taking
        the longest alone reported 100+ absences that were nothing but the
        stemmer. The length and non-numeric filters stay, so a two-letter alias
        still cannot satisfy the rule vacuously.  #>
    param($Register, $Registry)

    $out = New-Object System.Collections.Generic.List[object]
    if ($null -eq $Register) { return [pscustomobject]@{ Entries = @(); Suppressed = 0 } }

    $vocab = Get-GateProp -Object $Register -Names @('vocabulary')
    $docs  = Get-DpArray (Get-GateProp -Object $vocab -Names @('document'))
    $equip = Get-DpArray (Get-GateProp -Object $vocab -Names @('equipment'))

    $subs = Get-GateProp -Object $Register -Names @('subSections')
    if ($null -eq $subs) { return [pscustomobject]@{ Entries = @(); Suppressed = 0 } }

    foreach ($refName in @($subs.PSObject.Properties.Name)) {
        if ($refName -like '_*') { continue }
        $ss = $subs.$refName
        $topic = ''
        if ("$refName" -match '^\s*(\d+)') { $topic = $Matches[1] }
        if (-not $topic) { continue }

        foreach ($task in (Get-DpArray (Get-GateProp -Object $ss -Names @('tasks')))) {
            $tref = '' + (Get-GateProp -Object $task -Names @('ref') -Default '')
            $ground = '' + (Get-GateProp -Object $task -Names @('permittedGround') -Default '')
            $groundN = ConvertTo-GateNormal $ground

            foreach ($d in $docs) {
                $dn = ConvertTo-GateNormal "$d"
                if ($dn.Length -lt 6) { continue }
                if ($groundN -and $groundN.Contains($dn)) {
                    $out.Add([pscustomobject]@{
                        Class = 'instrument'; Topic = $topic; Ref = $tref; Label = "$d"
                        Match = @($dn); From = 'withhold-register vocabulary.document named in the task permittedGround'
                    })
                }
            }

            $itemList = @()
            $itemList += Get-DpArray (Get-GateProp -Object $task -Names @('items'))
            $itemList += Get-DpArray (Get-GateProp -Object $task -Names @('prefilledItems'))
            $itemList += Get-DpArray (Get-GateProp -Object $task -Names @('subjects'))
            $aliases = Get-GateProp -Object $task -Names @('aliases')
            $headersN = ''
            foreach ($h in (Get-DpArray (Get-GateProp -Object $task -Names @('headers')))) { $headersN += ' ' + (ConvertTo-GateNormal "$h") }

            foreach ($it in $itemList) {
                $lab = "$it"
                if (-not $lab.Trim()) { continue }
                #  THE REGISTER'S OWN ALIAS MAP IS THE MATCHER, not the item
                #  label. An item reads "Chickpea and Potato Curry, 50 portions,
                #  17.5 L, chilled" on the task and "the curry" on a slide;
                #  requiring the long form would require something no correct
                #  artefact contains, and this rule would fail every build.
                #  Where the register supplies no aliases the label itself is
                #  the only honest matcher and is used.
                $cands = New-Object System.Collections.Generic.List[string]
                if ($null -ne $aliases -and (@($aliases.PSObject.Properties.Name) -contains $lab)) {
                    foreach ($a in (Get-DpArray $aliases.$lab)) { $cands.Add((ConvertTo-GateNormal "$a")) }
                }
                if ($cands.Count -eq 0) { $cands.Add((ConvertTo-GateNormal $lab)) }
                #  Every candidate is a matcher. The length and non-numeric
                #  filters keep a four-letter alias from satisfying the rule
                #  vacuously, which is the failure mode rule 1 is written
                #  against.
                $keepM = New-Object System.Collections.Generic.List[string]
                foreach ($c in $cands) {
                    if (-not $c) { continue }
                    if ($c.Length -lt 6 -or $c.Length -gt 60) { continue }
                    if ($c -match '^[0-9 ]+$') { continue }
                    if (-not $keepM.Contains($c)) { $keepM.Add($c) }
                }
                if ($keepM.Count -eq 0) { continue }
                $out.Add([pscustomobject]@{
                    Class = 'item'; Topic = $topic; Ref = $tref; Label = $lab
                    Match = $keepM.ToArray(); From = 'withhold-register task items, matched through the register alias map'
                })
            }

            foreach ($e in $equip) {
                $en = ConvertTo-GateNormal "$e"
                if ($en.Length -lt 6) { continue }
                $named = $false
                if ($groundN -and $groundN.Contains($en)) { $named = $true }
                if (-not $named -and $headersN -and $headersN.Contains($en)) { $named = $true }
                if (-not $named) {
                    foreach ($it in $itemList) { if ((ConvertTo-GateNormal "$it").Contains($en)) { $named = $true; break } }
                }
                if ($named) {
                    $out.Add([pscustomobject]@{
                        Class = 'term'; Topic = $topic; Ref = $tref; Label = "$e"
                        Match = @($en); From = 'withhold-register vocabulary.equipment named by the task'
                    })
                }
            }
        }
    }

    #  SUBTRACT everything the registry marks assessor-only. Requiring a
    #  withheld value on a learner-facing surface would be a gate ordering the
    #  exact leak the sweep beside it exists to stop.
    $forbidden = New-Object System.Collections.Generic.List[string]
    foreach ($a in (Get-DpArray (Get-GateProp -Object $Registry -Names @('assessorOnly')))) {
        $t = '' + (Get-GateProp -Object $a -Names @('text') -Default '')
        if ($t) { $forbidden.Add((ConvertTo-GateNormal $t)) }
    }

    $keep = New-Object System.Collections.Generic.List[object]
    $dropped = 0
    $seen = @{}
    foreach ($e in $out) {
        $key = "{0}|{1}|{2}" -f $e.Topic, $e.Class, (ConvertTo-GateNormal $e.Label)
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true
        $bad = $false
        foreach ($f in $forbidden) {
            if (-not $f) { continue }
            foreach ($m in $e.Match) { if ($m -and ($m.Contains($f) -or $f.Contains($m))) { $bad = $true } }
        }
        if ($bad) { $dropped++; continue }
        $keep.Add($e)
    }
    return [pscustomobject]@{ Entries = $keep.ToArray(); Suppressed = $dropped }
}

# ---------------------------------------------------------------------------
# Count assertions in slide prose
# ---------------------------------------------------------------------------

$script:DpNumberWords = @{
    'one' = 1; 'two' = 2; 'three' = 3; 'four' = 4; 'five' = 5; 'six' = 6; 'seven' = 7
    'eight' = 8; 'nine' = 9; 'ten' = 10; 'eleven' = 11; 'twelve' = 12
}
#  A sentence that POINTS AT the table. Only these block; everything else
#  reports. "Teach the three decisions" is teaching prose about a four-row
#  table and is not a defect - blocking on it is how a gate gets switched off.
$script:DpDeicticRx = '(?i)\b(this|the)\s+(table|grid|matrix)\b|\b(table|grid)\s+(below|above|on this slide|here)\b|\b(rows?|columns?)\s+(below|above)\b'

function Get-DpCountClaims {
    <# Every "<n> <noun>" claim in a piece of slide prose, with its sentence. #>
    param([string] $Text)
    $out = New-Object System.Collections.Generic.List[object]
    if (-not $Text) { return $out.ToArray() }
    foreach ($sent in ([regex]::Split($Text, '(?<=[\.\?\!])\s+'))) {
        if (-not $sent.Trim()) { continue }
        foreach ($m in [regex]::Matches($sent, '(?i)\b(?<n>\d{1,2}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\s+(?<noun>[a-z][a-z\-]{2,20})\b')) {
            $raw = $m.Groups['n'].Value.ToLowerInvariant()
            $val = 0
            if ($raw -match '^\d+$') { $val = [int]::Parse($raw) }
            elseif ($script:DpNumberWords.ContainsKey($raw)) { $val = [int]$script:DpNumberWords[$raw] }
            if ($val -le 0 -or $val -gt 30) { continue }
            $out.Add([pscustomobject]@{
                N = $val; Noun = $m.Groups['noun'].Value.ToLowerInvariant()
                Sentence = $sent.Trim(); Deictic = ($sent -match $script:DpDeicticRx)
            })
        }
    }
    return $out.ToArray()
}

# ---------------------------------------------------------------------------
# THE GATE
# ---------------------------------------------------------------------------

function Invoke-DeckParity {
    <#  Runs every rule and returns the finding list plus the counters each rule
        printed. Separated from the top level so -SelfTest can drive it against
        a planted fixture in-process, which is the only way a plant can be
        verified to have landed AND to have been caught by the same code path
        the real run uses.  #>
    param(
        [Parameter(Mandatory)][string] $Build,
        [string] $Spine,
        [string] $Rules,
        [string] $Register,
        [string] $Contract,
        [string] $ProfileFile,
        [string] $Skill,
        [int]    $NotesFloor,
        [int]    $SharedHeadings
    )

    $findings = New-Object System.Collections.Generic.List[object]
    $notes = New-Object System.Collections.Generic.List[object]

    if (-not $Spine) { $Spine = Join-Path $Build 'spine' }
    if (-not $Rules) { $Rules = Join-Path $Build 'figures.json' }
    if (-not $Register) { $Register = Join-Path $Build 'withhold-register.json' }

    $registry = Get-GateJson -Path $Rules
    if ($null -eq $registry) {
        throw ("$GATE`: no figure registry at {0}. Stage 2 locks one; the per-surface require rule has nothing to enforce without it, and a rule with an empty check-set passes by having nothing to check." -f $Rules)
    }
    $reg = Get-GateJson -Path $Register

    $noNotes = Get-DpNoNotesList -ProfileFile $ProfileFile -Skill $Skill

    #  ---- source sets. THE SPINE, AND NOTHING ELSE.
    $skipMap = @{}
    foreach ($k in (Get-GateUnrenderedFields -BuildDir $Build -ForSweep).Keys) { $skipMap[$k] = $true }

    $spineFiles = @(Get-ChildItem -LiteralPath $Spine -Filter '*.json' -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -notmatch '\.gate\.json$' -and $_.Name -notmatch '\.result\.json$' } |
                    Sort-Object Name)
    if ($spineFiles.Count -eq 0) {
        throw ("$GATE`: no spine JSON under {0}. This gate reads the spine and never opens a .ps1, a report or a rendered extract - which is the point - so an empty spine is an input error, not a pass." -f $Spine)
    }

    $cells = New-Object System.Collections.Generic.List[object]
    $slides = New-Object System.Collections.Generic.List[object]
    $topicOf = @{}
    foreach ($f in $spineFiles) {
        $j = Get-GateJson -Path $f.FullName
        if ($null -eq $j) { continue }
        $topicOf[$f.Name] = Get-DpTopicOf -Json $j
        foreach ($c in (Get-DpSurfaceCells -Node $j -File $f.Name -Skip $skipMap)) { $cells.Add($c) }
        foreach ($s in (Get-DpSlides -Node $j -File $f.Name)) { $slides.Add($s) }
    }

    $guideCells = @($cells | Where-Object { $_.Surface -eq 'guide' })
    $deckCells  = @($cells | Where-Object { $_.Surface -eq 'deck' })

    #  One concatenated blob per surface, and per surface per topic, so a
    #  require or a benchmark entry is a substring test rather than 40,000
    #  regex runs. Normalised text is kept beside raw for the same reason.
    $guideRaw = ($guideCells | ForEach-Object { $_.Text }) -join "`n"
    $deckRaw  = ($deckCells  | ForEach-Object { $_.Text }) -join "`n"
    $promptRaw = ($cells | Where-Object { $_.Path -match '(^|\.)prompt$' } | ForEach-Object { $_.Text }) -join "`n"

    $guideByTopic = @{}
    $deckByTopic = @{}
    foreach ($c in $cells) {
        $t = '' + $topicOf[$c.File]
        if (-not $t) { continue }
        $bag = if ($c.Surface -eq 'deck') { $deckByTopic } else { $guideByTopic }
        if (-not $bag.ContainsKey($t)) { $bag[$t] = New-Object System.Text.StringBuilder }
        [void]$bag[$t].Append(' ').Append($c.Text)
    }
    $guideNormByTopic = @{}
    $deckNormByTopic = @{}
    foreach ($t in $guideByTopic.Keys) { $guideNormByTopic[$t] = ConvertTo-GateNormal $guideByTopic[$t].ToString() }
    foreach ($t in $deckByTopic.Keys)  { $deckNormByTopic[$t]  = ConvertTo-GateNormal $deckByTopic[$t].ToString() }

    # -----------------------------------------------------------------------
    # DP-REQUIRE-PER-SURFACE  (and DP-REQUIRE-PROMPT-ONLY)
    # -----------------------------------------------------------------------
    $reqChecked = 0; $reqNarrowed = 0
    foreach ($fig in (Get-DpArray (Get-GateProp -Object $registry -Names @('figures')))) {
        $figName = '' + (Get-GateProp -Object $fig -Names @('name') -Default '(unnamed figure)')
        $declared = @(Get-DpArray (Get-GateProp -Object $fig -Names @('surfaces', 'surface')) | ForEach-Object { ("$_").ToLowerInvariant() })
        $wantGuide = $true; $wantDeck = $true
        if ($declared.Count -gt 0) {
            $wantGuide = ($declared -contains 'guide') -or ($declared -contains 'both') -or ($declared -contains 'all')
            $wantDeck  = ($declared -contains 'deck')  -or ($declared -contains 'both') -or ($declared -contains 'all')
            $reqNarrowed++
        }
        foreach ($need in (Get-DpArray (Get-GateProp -Object $fig -Names @('require')))) {
            $s = "$need"
            if (-not $s.Trim()) { continue }
            $reqChecked++
            $rx = [regex]::Escape($s)
            $inGuide = ([regex]::Matches($guideRaw, $rx, 'IgnoreCase')).Count
            $inDeck  = ([regex]::Matches($deckRaw,  $rx, 'IgnoreCase')).Count
            $inPrompt = ([regex]::Matches($promptRaw, $rx, 'IgnoreCase')).Count

            if ($wantGuide -and $inGuide -eq 0) {
                $findings.Add([pscustomobject]@{
                    Rule = 'DP-REQUIRE-PER-SURFACE'; Level = 'BLOCK'; Figure = $figName; Surface = 'guide'
                    Detail = ("required '{0}' appears 0 times in the guide-facing spine (deck-facing: {1})" -f $s, $inDeck)
                    Surfaces = $(if ($declared.Count) { $declared -join '+' } else { 'guide+deck (default)' })
                })
            }
            if ($wantDeck -and $inDeck -eq 0) {
                $findings.Add([pscustomobject]@{
                    Rule = 'DP-REQUIRE-PER-SURFACE'; Level = 'BLOCK'; Figure = $figName; Surface = 'deck'
                    Detail = ("required '{0}' appears 0 times in the deck-facing spine (guide-facing: {1})" -f $s, $inGuide)
                    Surfaces = $(if ($declared.Count) { $declared -join '+' } else { 'guide+deck (default)' })
                })
            }
            if ($inPrompt -gt 0 -and ($inGuide + $inDeck) -eq $inPrompt) {
                $notes.Add([pscustomobject]@{
                    Rule = 'DP-REQUIRE-PROMPT-ONLY'; Level = 'REPORT'; Figure = $figName; Surface = 'prompt'
                    Detail = ("required '{0}' is carried ONLY by artwork prompt text - correct in the instruction that draws the picture, nowhere in the prose either artefact renders" -f $s)
                })
            }
        }
    }

    # -----------------------------------------------------------------------
    # DP-BENCH-PER-TOPIC
    # -----------------------------------------------------------------------
    $bench = Get-DpBenchmarkSet -Register $reg -Registry $registry
    $benchEntries = @()
    $benchSuppressed = 0
    if ($null -ne $bench) { $benchEntries = @($bench.Entries); $benchSuppressed = [int]$bench.Suppressed }
    #  THE ARM IS SCOPED TO PARITY, AND THAT SCOPING IS THE RULE, NOT A
    #  WEAKENING. An entry the build carries on ONE surface in a topic and not
    #  the other is the defect this gate is named for - "an accepted instrument
    #  named twice in the guide and zero times across 183 slides". An entry
    #  neither surface carries in that topic is a COVERAGE question, owned by
    #  Check-RowCoverage and section 15, and blocking on it here fired 300+
    #  times on a build whose only fault was that the register's permittedGround
    #  lists everything the learner holds during a task, topic-wide, including
    #  the safety data sheets. Both counts are printed, so a reader can see how
    #  many entries this arm passed over and why.
    $benchBoth = 0; $benchNeither = 0
    foreach ($e in $benchEntries) {
        $g = '' + $guideNormByTopic[$e.Topic]
        $d = '' + $deckNormByTopic[$e.Topic]
        $inG = $false; $inD = $false
        foreach ($m in $e.Match) { if ($m -and $g.Contains($m)) { $inG = $true } }
        foreach ($m in $e.Match) { if ($m -and $d.Contains($m)) { $inD = $true } }
        if ($inG -and $inD) { $benchBoth++; continue }
        if (-not $inG -and -not $inD) { $benchNeither++; continue }
        $missing = if ($inG) { 'deck' } else { 'guide' }
        $has     = if ($inG) { 'guide' } else { 'deck' }
        $findings.Add([pscustomobject]@{
            Rule = 'DP-BENCH-PER-TOPIC'; Level = 'BLOCK'; Figure = $e.Ref; Surface = $missing
            Detail = ("Topic {0}: benchmark-accepted {1} '{2}' is carried by the {3} and is absent from the {4} in this topic (matched on '{5}')" -f $e.Topic, $e.Class, $e.Label, $has, $missing, ($e.Match -join ' / '))
        })
    }

    # -----------------------------------------------------------------------
    # Slide-side rules: DP-TABLE-SHAPE, DP-NOTE-COUNT, DP-NOTES-PRESENT
    # -----------------------------------------------------------------------
    #  Task shapes, keyed by the reference a chip can name. DERIVED from the
    #  withhold register's own task entries.
    $taskShape = @{}
    if ($null -ne $reg) {
        $subs = Get-GateProp -Object $reg -Names @('subSections')
        if ($null -ne $subs) {
            foreach ($rn in @($subs.PSObject.Properties.Name)) {
                if ($rn -like '_*') { continue }
                foreach ($task in (Get-DpArray (Get-GateProp -Object $subs.$rn -Names @('tasks')))) {
                    $tref = '' + (Get-GateProp -Object $task -Names @('ref') -Default '')
                    if (-not $tref) { continue }
                    $hdrs = @(Get-DpArray (Get-GateProp -Object $task -Names @('headers')) | ForEach-Object { "$_" })
                    $shape = Get-GateProp -Object $task -Names @('shape')
                    $rows = 0
                    if ($null -ne $shape) { $rows = [int]('0' + ('' + (Get-GateProp -Object $shape -Names @('rows') -Default 0))) }
                    if ($rows -le 0) { $rows = @(Get-DpArray (Get-GateProp -Object $task -Names @('items'))).Count }
                    $taskShape[$tref] = [pscustomobject]@{
                        Ref = $tref; Headers = $hdrs; HeadersNorm = @($hdrs | ForEach-Object { ConvertTo-GateNormal $_ })
                        Rows = $rows; Cols = $hdrs.Count
                    }
                }
            }
        }
    }

    $tableSlidesSeen = 0; $tableSlidesWithChip = 0; $tableCompared = 0; $tableSuppressed = 0
    $notesChecked = 0; $notesExempt = 0
    $countClaimsSeen = 0; $countClaimsBlocking = 0

    foreach ($sl in $slides) {
        $n = $sl.Node
        $layout = ('' + (Get-GateProp -Object $n -Names @('layout') -Default '')).ToLowerInvariant()
        $kind   = ('' + (Get-GateProp -Object $n -Names @('kind') -Default '')).ToLowerInvariant()
        $chip   = '' + (Get-GateProp -Object $n -Names @('chip') -Default '')
        $where  = "{0}:{1}" -f $sl.File, $sl.Path

        # ---- table rows on this slide, however the property is named
        $tblRows = @()
        foreach ($cand in @('tableRows', 'rows', 'table')) {
            $v = Get-GateProp -Object $n -Names @($cand)
            $arr = Get-DpArray $v
            if ($arr.Count -gt 0 -and ($arr[0] -is [System.Collections.IEnumerable]) -and ($arr[0] -isnot [string])) { $tblRows = $arr; break }
        }
        $dataRows = 0; $cols = 0
        if ($tblRows.Count -gt 0) {
            $dataRows = $tblRows.Count - 1     # row one is the heading row in this house style
            foreach ($r in $tblRows) { $c = @(Get-DpArray $r).Count; if ($c -gt $cols) { $cols = $c } }
        }
        #  A figures slide is a table of figure/label pairs by another name.
        $figPairs = 0
        if (-not $tblRows.Count) {
            for ($i = 1; $i -le 12; $i++) {
                $fv = Get-GateProp -Object $n -Names @("fig$i")
                if ($fv -and "$fv".Trim()) { $figPairs++ }
            }
        }

        # ---- DP-TABLE-SHAPE
        if ($tblRows.Count -gt 0) { $tableSlidesSeen++ }
        if ($tblRows.Count -gt 0 -and $chip) {
            $tableSlidesWithChip++
            $slideHdrN = @(Get-DpArray $tblRows[0] | ForEach-Object { ConvertTo-GateNormal "$_" })
            #  -1 seeds the comparison so the task the chip NAMES is always the
            #  matched task, even where it shares no headings at all. Seeded at
            #  0, $matched stayed null on every non-echoing slide and the
            #  suppression counter printed 0 where the truthful answer was
            #  "every slide examined" - a counter reading zero because the rule
            #  never ran is exactly what rule 1 of gates.md is written against.
            $matched = $null; $shared = -1
            foreach ($tref in $taskShape.Keys) {
                if ($chip.IndexOf($tref, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
                $ts = $taskShape[$tref]
                $sh = 0
                foreach ($h in $slideHdrN) {
                    if (-not $h) { continue }
                    foreach ($th in $ts.HeadersNorm) {
                        if (-not $th) { continue }
                        if ($h -eq $th -or ($h.Length -ge 6 -and $th.Contains($h)) -or ($th.Length -ge 6 -and $h.Contains($th))) { $sh++; break }
                    }
                }
                if ($sh -gt $shared) { $shared = $sh; $matched = $ts }
            }
            if ($null -ne $matched -and $shared -ge $SharedHeadings) {
                $tableCompared++
                if ($dataRows -ne $matched.Rows -or $cols -ne $matched.Cols) {
                    $findings.Add([pscustomobject]@{
                        Rule = 'DP-TABLE-SHAPE'; Level = 'BLOCK'; Figure = $matched.Ref; Surface = 'deck'
                        Detail = ("{0}: slide table is {1} data row(s) x {2} column(s); the assessed task its chip names is {3} x {4} (shares {5} column heading(s))" -f $where, $dataRows, $cols, $matched.Rows, $matched.Cols, $shared)
                    })
                }
            }
            elseif ($null -ne $matched) { $tableSuppressed++ }
        }

        # ---- DP-NOTE-COUNT
        $against = if ($tblRows.Count -gt 0) { $dataRows } elseif ($figPairs -gt 0) { $figPairs } else { -1 }
        if ($against -ge 0) {
            $prose = ''
            foreach ($p in @('note', 'lead', 'headline')) {
                $v = Get-GateProp -Object $n -Names @($p)
                if ($v -is [string]) { $prose += ' ' + $v }
            }
            foreach ($cl in (Get-DpCountClaims -Text $prose)) {
                #  Only a claim about the table's OWN unit is a claim about the
                #  table. The unit set is the structural nouns plus the slide's
                #  own column headings, so it is derived from the slide.
                $isStructural = ($cl.Noun -match '^(rows?|columns?|cells?|entries|entry|lines?|items?|figures?)$')
                if (-not $isStructural) { continue }
                $countClaimsSeen++
                if ($cl.N -eq $against) { continue }
                if ($cl.Deictic) {
                    $countClaimsBlocking++
                    $findings.Add([pscustomobject]@{
                        Rule = 'DP-NOTE-COUNT'; Level = 'BLOCK'; Figure = $chip; Surface = 'deck'
                        Detail = ("{0}: the note asserts {1} {2} and the table on the slide has {3}" -f $where, $cl.N, $cl.Noun, $against)
                    })
                }
                else {
                    $notes.Add([pscustomobject]@{
                        Rule = 'DP-NOTE-COUNT'; Level = 'REPORT'; Figure = $chip; Surface = 'deck'
                        Detail = ("{0}: prose asserts {1} {2} against a table of {3}; the sentence does not point at the table, so it reports rather than blocks" -f $where, $cl.N, $cl.Noun, $against)
                    })
                }
            }
        }

        # ---- DP-NOTES-PRESENT
        $exempt = $noNotes.Set.ContainsKey($layout) -or $noNotes.Set.ContainsKey($kind)
        if ($exempt) { $notesExempt++ }
        else {
            $notesChecked++
            $nt = '' + (Get-GateProp -Object $n -Names @('notes', 'speakerNotes') -Default '')
            $w = Get-DpWordCount -Text $nt
            if ($w -lt $NotesFloor) {
                $findings.Add([pscustomobject]@{
                    Rule = 'DP-NOTES-PRESENT'; Level = 'BLOCK'; Figure = $chip; Surface = 'deck'
                    Detail = ("{0}: layout '{1}' / kind '{2}' is not on the profile's no-notes list and carries {3} word(s) of speaker notes, floor {4}" -f $where, $layout, $kind, $w, $NotesFloor)
                })
            }
        }
    }

    return [pscustomobject]@{
        Findings = $findings.ToArray()
        Notes    = $notes.ToArray()
        Stats    = [pscustomobject]@{
            spineFiles = $spineFiles.Count
            guideCells = $guideCells.Count
            deckCells = $deckCells.Count
            slides = $slides.Count
            requireStrings = $reqChecked
            requireNarrowedEntries = $reqNarrowed
            benchmarkEntries = @($benchEntries).Count
            benchmarkSuppressedAssessorOnly = $benchSuppressed
            benchmarkOnBothSurfaces = $benchBoth
            benchmarkOnNeitherSurface = $benchNeither
            tableSlidesSeen = $tableSlidesSeen
            tableSlidesWithChip = $tableSlidesWithChip
            tableShapeCompared = $tableCompared
            tableShapeSuppressedNotEchoing = $tableSuppressed
            countClaimsExamined = $countClaimsSeen
            countClaimsBlocking = $countClaimsBlocking
            slidesNotesChecked = $notesChecked
            slidesNotesExempt = $notesExempt
        }
        NoNotes  = $noNotes
        Sources  = [pscustomobject]@{ spine = $Spine; registry = $Rules; register = $Register; profile = $ProfileFile; deckProfile = $noNotes.DeckPath }
    }
}

# ---------------------------------------------------------------------------
# SELF-TEST - plant, VERIFY THE PLANT LANDED, then require the gate to fire
# ---------------------------------------------------------------------------

function New-DpFixture {
    <#  A synthetic build directory: a contract, a registry, a withhold
        register and a four-file spine. Nothing here names a unit, an RTO or a
        brand - the fixture is a shape, not a build.  #>
    param([Parameter(Mandatory)][string] $Root)

    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Root 'spine') -Force | Out-Null

    $contract = [ordered]@{
        build = [ordered]@{ brand = '' }
        topics = @(@{ n = 1; element = '1'; title = 'Shape one'; pcs = @('1.1') })
        referenceConvention = [ordered]@{
            knowledge = 'Knowledge Task {n}({part})'
            workbook  = 'Workbook Task {n}({part})'
            observation = 'Observation {n}'
        }
        deckFloors = [ordered]@{ slidesPerTopic = 1 }
    }
    Write-DpJson -Object $contract -Path (Join-Path $Root 'contract.json')

    $registry = [ordered]@{
        figures = @(
            [ordered]@{ name = 'Both surfaces'; require = @('ALPHA-VALUE') },
            [ordered]@{ name = 'Guide only, declared'; require = @('BETA-VALUE'); surfaces = @('guide') }
        )
        assessorOnly = @(@{ text = 'WITHHELD-BENCH'; why = 'fixture: proves the assessor-only subtraction runs before the per-topic requirement' })
        deckMust = @()
    }
    Write-DpJson -Object $registry -Path (Join-Path $Root 'figures.json')

    $register = [ordered]@{
        vocabulary = [ordered]@{
            document  = @('Fixture Order Form')
            equipment = @('bench mixer')
            recipe    = @()
        }
        subSections = [ordered]@{
            '1.1' = [ordered]@{
                subSection = '1.1'
                refs = @('Workbook Task 1(a)')
                tasks = @(
                    [ordered]@{
                        ref = 'Workbook Task 1(a)'
                        document = 'FixtureWorkbook'
                        kind = 'labelled'
                        headers = @('The order', 'What you selected', 'Why it suited')
                        assessedHeaders = @(1, 2)
                        items = @('Fixture pumpkin soup, 20 portions', 'Fixture lentil bake, 30 portions')
                        prefilledItems = @()
                        aliases = [ordered]@{
                            'Fixture pumpkin soup, 20 portions' = @('pumpkin soup', 'pumpkin')
                            'Fixture lentil bake, 30 portions'  = @('lentil bake', 'lentil')
                        }
                        permittedGround = 'Learner-held during this task: Fixture Order Form; the bench mixer manual.'
                        shape = [ordered]@{ rows = 2; assessedColumns = 2 }
                    }
                )
                freeText = @()
                observations = @()
            }
        }
    }
    Write-DpJson -Object $register -Path (Join-Path $Root 'withhold-register.json')

    $good = [ordered]@{
        layout = 'table'; kind = 'table'
        kicker = 'ONE'; headline = 'Shape one'
        tableRows = @(
            @('The order', 'What you selected', 'Why it suited'),
            @('Fixture pumpkin soup, 20 portions', 'a', 'b'),
            @('Fixture lentil bake, 30 portions', 'c', 'd')
        )
        note = 'The table below sets out 2 rows, one for each order on the run.'
        chip = 'Prepares you for: Workbook Task 1(a)'
        notes = 'Teaching note for the fixture slide. It runs well past the notes floor so that the notes rule has something to pass on, and it names ALPHA-VALUE and the Fixture Order Form and the bench mixer and pumpkin soup and lentil bake so the deck surface carries every benchmark entry this fixture derives, which is what the clean case has to prove before any planted case means anything at all.'
    }
    $t1 = [ordered]@{
        ref = '1.1'; pc = '1.1'; topic = '1'; title = 'Shape one'
        whatThisMeans = 'The guide surface names ALPHA-VALUE and BETA-VALUE and the Fixture Order Form and the bench mixer, and it teaches pumpkin soup and lentil bake so the guide side of the per-topic benchmark rule is satisfied on a clean fixture.'
        visuals = @(@{ slot = '1.1.1'; kind = 'Diagram'; caption = 'Fixture caption'; prompt = 'A fixture prompt.'; spec = @{ layout = 'table'; headerRow = $true; rows = @(@('a', 'b')) } })
        slides = @($good)
    }
    Write-DpJson -Object $t1 -Path (Join-Path $Root 'spine\t1_1.1.json')

    $frame = [ordered]@{
        title = [ordered]@{ layout = 'title'; kind = 'title'; title = 'Fixture deck'; subtitle = 'Shape only' }
    }
    Write-DpJson -Object $frame -Path (Join-Path $Root 'spine\deckframe.json')

    return $Root
}

function Invoke-DpSelfTest {
    param([string] $Skill, [int] $NotesFloor, [int] $SharedHeadings)

    $ok = 0; $bad = 0
    $prof = Resolve-DpProfilePath -ProfilePath '' -Build '' -Skill $Skill -AnyForSelfTest
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('dp-selftest-' + [Guid]::NewGuid().ToString('N').Substring(0, 12))

    function Ok  { param([string] $M) Write-Host ("    ok   {0}" -f $M) -ForegroundColor Green;  $script:DpOk++ }
    function Bad { param([string] $M) Write-Host ("    X    {0}" -f $M) -ForegroundColor Red;    $script:DpBad++ }
    $script:DpOk = 0; $script:DpBad = 0

    function Test-DpPlantLanded {
        <#  RULE 2 OF gates.md. Read the file back off disk and confirm the
            defect is present in the exact channel the gate scans. One build
            recorded a plant that wrote into a file the gate never opens, the
            gate reported clean, and that was filed as evidence it worked.  #>
        param([string] $Path, [scriptblock] $Probe, [string] $What)
        $j = Get-GateJson -Path $Path
        $landed = $false
        try { $landed = [bool](& $Probe $j) } catch { $landed = $false }
        if ($landed) { Write-Host ("    plant landed: {0}" -f $What) -ForegroundColor DarkGray; return $true }
        Write-Host ("    X plant did NOT land: {0} - this proves nothing." -f $What) -ForegroundColor Red
        return $false
    }

    function Test-DpFires {
        param([string] $Build, [string] $Rule, [string] $What, [switch] $Expect)
        $r = $null
        try { $r = Invoke-DeckParity -Build $Build -ProfileFile $prof -Skill $Skill -NotesFloor $NotesFloor -SharedHeadings $SharedHeadings }
        catch { Bad ("{0}: the gate threw - {1}" -f $What, $_.Exception.Message); return }
        $hit = @($r.Findings | Where-Object { $_.Rule -eq $Rule })
        if ($Expect) {
            if ($hit.Count -gt 0) { Ok ("{0}: {1} fired ({2})" -f $What, $Rule, $hit[0].Detail) }
            else { Bad ("{0}: {1} did NOT fire. Findings: {2}" -f $What, $Rule, (@($r.Findings | ForEach-Object { $_.Rule }) -join ', ')) }
        }
        else {
            if ($hit.Count -eq 0) { Ok ("{0}: {1} correctly silent" -f $What, $Rule) }
            else { Bad ("{0}: {1} fired on a correct fixture - {2}" -f $What, $Rule, $hit[0].Detail) }
        }
    }

    try {
        Write-Host ''
        Write-Host ("  SELF-TEST (profile {0})" -f (Split-Path -Leaf $prof)) -ForegroundColor Cyan

        # ---- CASE 0: the clean fixture must not fire anything
        $c0 = Join-Path $root 'clean'
        New-DpFixture -Root $c0 | Out-Null
        $r0 = $null
        try { $r0 = Invoke-DeckParity -Build $c0 -ProfileFile $prof -Skill $Skill -NotesFloor $NotesFloor -SharedHeadings $SharedHeadings }
        catch { Bad ("clean fixture: the gate threw - {0}" -f $_.Exception.Message) }
        if ($null -ne $r0) {
            if (@($r0.Findings).Count -eq 0) { Ok 'clean fixture: no blocking finding on a correct build' }
            else { Bad ("clean fixture fired {0}: {1}" -f @($r0.Findings).Count, (@($r0.Findings | ForEach-Object { $_.Rule + ' / ' + $_.Detail }) -join ' | ')) }
        }

        # ---- CASE 1: a require present in the guide and absent from the deck
        $c1 = Join-Path $root 'p1'
        New-DpFixture -Root $c1 | Out-Null
        $p = Join-Path $c1 'spine\t1_1.1.json'
        $j = Get-GateJson -Path $p
        $j.slides[0].notes = ($j.slides[0].notes -replace 'ALPHA-VALUE', 'a value the deck no longer names')
        Write-DpJson -Object $j -Path $p
        if (Test-DpPlantLanded -Path $p -What "ALPHA-VALUE removed from every deck-facing channel, still present guide-side" -Probe {
                param($d)
                $deck = ($d.slides | ConvertTo-Json -Depth 12)
                $guide = "" + $d.whatThisMeans
                ($deck -notmatch 'ALPHA-VALUE') -and ($guide -match 'ALPHA-VALUE')
            }) {
            Test-DpFires -Build $c1 -Rule 'DP-REQUIRE-PER-SURFACE' -What 'require present in the guide, absent from the deck' -Expect
        } else { Bad 'plant 1 did not land' }

        # ---- CASE 2: the require satisfied ONLY by a build script's comment
        $c2 = Join-Path $root 'p2'
        New-DpFixture -Root $c2 | Out-Null
        $p = Join-Path $c2 'spine\t1_1.1.json'
        $j = Get-GateJson -Path $p
        $j.slides[0].notes = ($j.slides[0].notes -replace 'ALPHA-VALUE', 'a value the deck no longer names')
        $j.whatThisMeans = ($j.whatThisMeans -replace 'ALPHA-VALUE', 'a value the guide no longer names')
        Write-DpJson -Object $j -Path $p
        $psFile = Join-Path $c2 'Fix-Figures.ps1'
        [System.IO.File]::WriteAllText($psFile, "# remediation: every occurrence of ALPHA-VALUE was corrected in round 3`r`nWrite-Host 'ALPHA-VALUE'`r`n", (New-Object System.Text.UTF8Encoding($true)))
        $back = [System.IO.File]::ReadAllText($psFile, [System.Text.Encoding]::UTF8)
        $spineText = Get-GateFileText -Path $p
        if (($back -match 'ALPHA-VALUE') -and ($spineText -notmatch 'ALPHA-VALUE')) {
            Write-Host '    plant landed: ALPHA-VALUE lives ONLY in a .ps1 comment in the build directory, nowhere on the spine' -ForegroundColor DarkGray
            Test-DpFires -Build $c2 -Rule 'DP-REQUIRE-PER-SURFACE' -What 'require satisfied only by a build-script comment' -Expect
        } else { Bad 'plant 2 did not land' }

        # ---- CASE 3: a slide table with one more row than its assessed task
        $c3 = Join-Path $root 'p3'
        New-DpFixture -Root $c3 | Out-Null
        $p = Join-Path $c3 'spine\t1_1.1.json'
        $j = Get-GateJson -Path $p
        $rows = @($j.slides[0].tableRows)
        $j.slides[0].tableRows = @($rows + , @('Fixture extra row, 40 portions', 'e', 'f'))
        Write-DpJson -Object $j -Path $p
        if (Test-DpPlantLanded -Path $p -What 'slide table now carries 3 data rows against a 2-row assessed task' -Probe {
                param($d) (@($d.slides[0].tableRows).Count - 1) -eq 3
            }) {
            Test-DpFires -Build $c3 -Rule 'DP-TABLE-SHAPE' -What 'slide table one row longer than its assessed task' -Expect
        } else { Bad 'plant 3 did not land' }

        # ---- CASE 4: a note asserting N against a table of N+1
        $c4 = Join-Path $root 'p4'
        New-DpFixture -Root $c4 | Out-Null
        $p = Join-Path $c4 'spine\t1_1.1.json'
        $j = Get-GateJson -Path $p
        $j.slides[0].note = 'The table below sets out 5 rows, one for each order on the run.'
        Write-DpJson -Object $j -Path $p
        if (Test-DpPlantLanded -Path $p -What 'note asserts 5 rows against a 2-row table, and points at the table' -Probe {
                param($d) ("" + $d.slides[0].note) -match '5 rows'
            }) {
            Test-DpFires -Build $c4 -Rule 'DP-NOTE-COUNT' -What 'note asserting N items against a table of N rows' -Expect
        } else { Bad 'plant 4 did not land' }

        # ---- CASE 5: a non-exempt slide with no speaker notes
        $c5 = Join-Path $root 'p5'
        New-DpFixture -Root $c5 | Out-Null
        $p = Join-Path $c5 'spine\t1_1.1.json'
        $j = Get-GateJson -Path $p
        $j.slides[0].notes = ''
        Write-DpJson -Object $j -Path $p
        if (Test-DpPlantLanded -Path $p -What "speaker notes emptied on a 'table' slide, which is not on the profile's no-notes list" -Probe {
                param($d) -not ("" + $d.slides[0].notes).Trim()
            }) {
            Test-DpFires -Build $c5 -Rule 'DP-NOTES-PRESENT' -What 'teaching slide with no speaker notes' -Expect
        } else { Bad 'plant 5 did not land' }

        # ---- CASE 6: a benchmark instrument present in the guide, absent from the deck
        $c6 = Join-Path $root 'p6'
        New-DpFixture -Root $c6 | Out-Null
        $p = Join-Path $c6 'spine\t1_1.1.json'
        $j = Get-GateJson -Path $p
        $j.slides[0].notes = ($j.slides[0].notes -replace 'Fixture Order Form', 'that document')
        Write-DpJson -Object $j -Path $p
        if (Test-DpPlantLanded -Path $p -What 'the accepted instrument is named guide-side and nowhere on any slide' -Probe {
                param($d)
                $deck = ($d.slides | ConvertTo-Json -Depth 12)
                ($deck -notmatch 'Fixture Order Form') -and (("" + $d.whatThisMeans) -match 'Fixture Order Form')
            }) {
            Test-DpFires -Build $c6 -Rule 'DP-BENCH-PER-TOPIC' -What 'benchmark-accepted instrument in the guide and on zero slides' -Expect
        } else { Bad 'plant 6 did not land' }

        # ---- CASE 7: the declared narrowing must NOT fire deck-side
        $c7 = Join-Path $root 'p7'
        New-DpFixture -Root $c7 | Out-Null
        Test-DpFires -Build $c7 -Rule 'DP-REQUIRE-PER-SURFACE' -What "BETA-VALUE declares surfaces:[guide] and is absent from the deck"
    }
    finally {
        if ((Test-Path -LiteralPath $root) -and $root.Length -gt 12) {
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $ok = $script:DpOk; $bad = $script:DpBad
    Write-Host ''
    if ($bad -gt 0) { Write-Host ("  SELF-TEST FAILED - {0} of {1} check(s) failed" -f $bad, ($ok + $bad)) -ForegroundColor Red }
    else            { Write-Host ("  SELF-TEST PASSED - {0} check(s), every planted defect verified to have landed and then caught" -f $ok) -ForegroundColor Green }
    return $bad
}

# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------

if ($SelfTest) {
    $bad = Invoke-DpSelfTest -Skill $SkillDir -NotesFloor $MinNotesWords -SharedHeadings $MinSharedHeadings
    if ($bad -gt 0) { exit 4 }
    if (-not $BuildDir) { exit 0 }
}

if (-not $BuildDir) {
    Write-Host ("  X {0}: -BuildDir is required (or -SelfTest on its own)." -f $GATE) -ForegroundColor Red
    exit 2
}
if (-not (Test-Path -LiteralPath $BuildDir)) {
    Write-Host ("  X {0}: -BuildDir not found: {1}" -f $GATE, $BuildDir) -ForegroundColor Red
    exit 2
}

try { $profPath = Resolve-DpProfilePath -ProfilePath $Profile -Build $BuildDir -Skill $SkillDir }
catch { Write-Host ("  X {0}" -f $_.Exception.Message) -ForegroundColor Red; exit 2 }

try {
    $result = Invoke-DeckParity -Build $BuildDir -Spine $SpineDir -Rules $RulesPath -Register $RegisterPath `
                                -Contract $ContractPath -ProfileFile $profPath -Skill $SkillDir `
                                -NotesFloor $MinNotesWords -SharedHeadings $MinSharedHeadings
}
catch { Write-Host ("  X {0}: {1}" -f $GATE, $_.Exception.Message) -ForegroundColor Red; exit 2 }

$st = $result.Stats
$blocking = @($result.Findings)
$reports  = @($result.Notes)

if (-not $Quiet) {
    Write-Host ''
    Write-Host 'DECK PARITY - per-surface, benchmark-derived' -ForegroundColor Cyan
    Write-GateCheckSet -What 'registry require string(s)' -Count $st.requireStrings -DerivedFrom (Split-Path -Leaf $result.Sources.registry)
    Write-GateCheckSet -What 'benchmark-accepted instrument/term/item(s), per topic' -Count $st.benchmarkEntries -DerivedFrom (Split-Path -Leaf $result.Sources.register)
    Write-GateCheckSet -What 'no-notes layout/kind exemption(s)' -Count $result.NoNotes.Set.Count -DerivedFrom ((Split-Path -Leaf $result.Sources.profile) + ' -> ' + (Split-Path -Leaf $result.NoNotes.DeckPath))
    Write-Host ("  sources: {0} spine file(s) ONLY - no .ps1, no report, no rendered extract is opened by this gate" -f $st.spineFiles) -ForegroundColor DarkGray
    Write-Host ("  surfaces: {0} guide-facing cell(s), {1} deck-facing cell(s), {2} slide(s)" -f $st.guideCells, $st.deckCells, $st.slides) -ForegroundColor DarkGray
    Write-Host ("  suppression: {0} require entry/entries narrow their surfaces by declaration; {1} benchmark entry/entries dropped as assessor-only; {2} on both surfaces already, {3} on neither in their topic (a coverage question, not a parity one - see Check-RowCoverage)" -f `
        $st.requireNarrowedEntries, $st.benchmarkSuppressedAssessorOnly, $st.benchmarkOnBothSurfaces, $st.benchmarkOnNeitherSurface) -ForegroundColor DarkGray
    Write-Host ("  suppression: {0} slide table(s), {1} carry a chip naming an assessed task; of those {2} compared and {3} not compared (<{4} shared column headings, so the table is not the assessed grid); {5} slide table(s) carry no chip and cannot be compared at all" -f `
        $st.tableSlidesSeen, $st.tableSlidesWithChip, $st.tableShapeCompared, $st.tableShapeSuppressedNotEchoing, $MinSharedHeadings, ($st.tableSlidesSeen - $st.tableSlidesWithChip)) -ForegroundColor DarkGray
    Write-Host ("  {0} count claim(s) examined, {1} blocking" -f $st.countClaimsExamined, $st.countClaimsBlocking) -ForegroundColor DarkGray
    Write-Host ("  notes floor {0} word(s); {1} slide(s) checked, {2} exempt by the profile's declared list" -f $MinNotesWords, $st.slidesNotesChecked, $st.slidesNotesExempt) -ForegroundColor DarkGray

    Write-Host ''
    if ($blocking.Count -eq 0) { Write-Host '  no parity defect: every require is on both surfaces, every benchmark entry is in both artefacts per topic, every table matches its task, every non-exempt slide has notes' -ForegroundColor Green }
    foreach ($g in ($blocking | Group-Object Rule | Sort-Object Name)) {
        Write-Host ("  {0}: {1} blocking" -f $g.Name, $g.Count) -ForegroundColor Red
        foreach ($f in ($g.Group | Select-Object -First 25)) { Write-Host ("    X [{0}] {1}" -f $f.Surface, $f.Detail) -ForegroundColor Red }
        if ($g.Count -gt 25) { Write-Host ("    ... {0} more in the report file" -f ($g.Count - 25)) -ForegroundColor DarkGray }
    }
    foreach ($g in ($reports | Group-Object Rule | Sort-Object Name)) {
        Write-Host ("  {0}: {1} REPORT (never changes the exit code)" -f $g.Name, $g.Count) -ForegroundColor Yellow
        foreach ($f in ($g.Group | Select-Object -First 15)) { Write-Host ("    ! {0}" -f $f.Detail) -ForegroundColor Yellow }
        if ($g.Count -gt 15) { Write-Host ("    ... {0} more in the report file" -f ($g.Count - 15)) -ForegroundColor DarkGray }
    }
}

if (-not $ReportPath) { $ReportPath = Join-Path $BuildDir 'deck-parity-report.json' }
$report = [pscustomobject]@{
    gate      = $GATE
    generated = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
    buildDir  = $BuildDir
    sources   = $result.Sources
    spineFingerprint = (Get-SpineFingerprint -BuildDir $BuildDir -SpineDir $SpineDir)
    thresholds = [pscustomobject]@{ minNotesWords = $MinNotesWords; minSharedHeadings = $MinSharedHeadings }
    noNotesList = [pscustomobject]@{ fromDeckProfile = $result.NoNotes.FromDeck; fromRtoPackReasons = $result.NoNotes.FromPack }
    stats     = $st
    blocking  = $blocking
    report    = $reports
    verdict   = $(if ($blocking.Count) { 'FAIL' } else { 'PASS' })
}
Write-DpJson -Object $report -Path $ReportPath
if (-not $Quiet) { Write-Host ("  report written to {0}" -f $ReportPath) -ForegroundColor DarkGray }

if ($blocking.Count) {
    if (-not $Quiet) { Write-Host ("FAIL - {0} blocking parity defect(s)" -f $blocking.Count) -ForegroundColor Red }
    exit 1
}
if (-not $Quiet) { Write-Host 'PASS' -ForegroundColor Green }
exit 0
