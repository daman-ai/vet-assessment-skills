<#
    Assert-PromptLint.ps1 - Stage 3b exit check. Lint every Route A
    (illustration) prompt on the spine against the RTO's house framing rule
    BEFORE a single image is generated.

    Implements the gate references\gates.md section 30.1 calls
    Assert-PromptLint. Runs at the exit of Stage 3b, before any generation
    spend. Blocks.

    WHY IT EXISTS. 47 of 57 first-pass illustrations on one build came back
    with an identifiable face; 17 failed a second review and 2 a third, for 48
    minutes of billed regeneration inside a 1h43m artwork block. The prompts
    described a PERSON - "a catering assistant in her twenties, looking down
    at the tray" - and the model composes a face for any person, whatever the
    prohibition that follows it. The house rules already said "ABSOLUTE: no
    faces". Telling the model not to draw a face does not work. The fix that
    worked was COMPOSITIONAL and sat at the FRONT of the prompt: "framed from
    the shoulders down; hands and equipment are the subject". The script
    written under pressure to apply it read prompts, never images - so this was
    a text operation all along, and it belongs before the spend, not after.

    THE RULE, read from the RTO profile's imageFraming block and never typed
    here:

      subjectRule = hands-and-equipment
        A Route A prompt FAILS when its grammatical subject is a person noun
        from the profile's closed personNouns list - a person noun at the head
        of the first clause (before the first preposition, verb or punctuation)
        or heading the phrase after "of", "showing", "featuring" or "depicting"
        - UNLESS the prompt opens with the framing sentence, which makes the
        composition the subject. This is a closed list matched at the head of
        the subject phrase, not a semantic judgement: a lint that guesses is a
        lint that gets switched off.

      requiredNegatives
        Every Route A prompt must carry every phrase in the "any" class. A
        prompt whose subject is a person AND whose slot is allow-listed (the
        person is the legitimate subject, so a face may be in shot) must also
        carry the "person-present" class. Every other class the profile
        defines (food-handling, workplace, ...) applies where the visual entry
        declares it in subjectClass - the lint does not guess a prompt's class
        from its wording. Set membership on normalised text, word-bounded.

    ALLOW-LIST. imageFraming.allowList in the profile, and promptAllow in the
    build's figures.json - per slot, with a written reason of twenty or more
    characters, printed here as evidence for the audit. Never a script
    parameter, never an in-file table.

    THE IMAGE REVIEW IS NOT WEAKENED. It keeps its full scope and authority;
    this removes the volume it has to wade through.

    THE COVER IS LINTED WITH EVERYTHING ELSE. cover.json plans the guide's
    first image under the SINGULAR name 'visual', and every visuals gate read
    only the plural, so the one image a reader sees before anything else was
    linted, sheeted, mirrored and reconciled by nobody. The walk here asks for
    the front matter explicitly, and the cover is an arm of its own.

    AND THE ROUTE A COUNT IS RECONCILED AGAINST THE ARTWORK MANIFEST. The
    sub-skill's manifest is what actually gets generated; the spine is what was
    planned. Where the two disagree, either an image is paid for that nothing
    plans or a planned illustration is never made, and until now nothing
    compared them. The manifest's GENERATED slots are counted with the SAME
    route predicate this file applies to the spine, so one definition decides
    both sides.

    ABSENT SUB-SKILL, settled once for P0-11 and P3-14: an absent manifest is
    REFUSED BY NAME when the spine declares any Route B visual (this build uses
    the sub-skill) or when the comparison is asked for with -RequireManifest. A
    guide-only build with no diagram kinds prints the absence by name and
    continues on the spine's declared kinds.

    No API call. No unit code, brand or build path is typed in this file.
    PS 5.1. ASCII only in this file.
    Exit 0 every Route A prompt passes; 1 at least one fails; 2 a usage error,
    an empty blocking check-set, or an absent input refused by name; 4 the
    self-test failed.

    ARMS (Lib-GateCommon roster): person-nouns, required-negatives,
    route-a-prompts, cover-visual and manifest-parity are BLOCKING;
    subject-classes is advisory unless the profile declares it mandatory, and
    reports examined = 0 rather than passing silently.
#>

# GATE: stages=3c; requires=BuildDir

[CmdletBinding()]
param(
    [string] $BuildDir,
    #  The RTO profile pack. Resolved from the build contract's brand when not
    #  given: assets\rto-profile.<brand>.json in this skill.
    [string] $Profile,
    [string] $SpineDir,
    [string] $SkillDir,
    #  The docx-images manifest this build's artwork is generated from.
    #  Default: <BuildDir>\images\manifest.json.
    [string] $ManifestPath,
    #  Ask for the manifest comparison outright. Without it the comparison is
    #  still required whenever the spine declares a Route B visual - see the
    #  absent-sub-skill rule above.
    [switch] $RequireManifest,
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

$GATE = 'Assert-PromptLint'
#  This script's own path, for the self-test's child runs ($PSCommandPath is
#  empty inside a function, so it is captured once here at script scope).
$script:PlSelf = $PSCommandPath

#  Function words that END a subject phrase. The head of the subject is what
#  sits before the first of these; a person noun after one is inside a
#  modifier ("two hands in white chef jacket cuffs"), not the subject.
$script:Prepositions = @('of', 'in', 'on', 'at', 'with', 'over', 'under', 'above', 'beside', 'behind', 'from',
    'into', 'onto', 'across', 'through', 'by', 'near', 'inside', 'outside', 'against', 'along', 'around',
    'between', 'during', 'before', 'after', 'toward', 'towards', 'beneath', 'below', 'among', 'within',
    'without', 'per', 'via', 'to', 'for', 'upon')
#  Words that introduce the picture's subject as an object phrase.
$script:SubjectTriggers = @('of', 'showing', 'shows', 'show', 'featuring', 'features', 'depicting', 'depicts', 'portraying', 'portrays')
#  Verb markers that end the head-walk: the subject is complete before them.
$script:VerbMarkers = @('is', 'are', 'was', 'were', 'sits', 'sit', 'stands', 'stand', 'lies', 'lie', 'rests', 'rest',
    'holds', 'hold', 'has', 'have', 'hangs', 'hang', 'waits', 'wait')
#  Skipped inside a trigger window: determiners, small numbers, wh-words and the
#  age/sex adjectives that summon a face.
$script:Skippable = @('a', 'an', 'the', 'one', 'two', 'three', 'four', 'five', 'six', 'several', 'some', 'how',
    'what', 'where', 'which', 'this', 'that', 'these', 'those', 'and', 'or', 'young', 'older', 'adult',
    'male', 'female', 'single', 'senior', 'junior', 'new')
$script:DefaultFramingOpener = '^\W*framed from the (?:shoulders|chest|neck|waist) down\b'
$script:RouteAKinds = '^(?:image|illustration|photo|photograph|picture)$'
$script:RouteBKinds = '^(?:diagram|table|canvas|chart|flow|flowchart|process|cycle|hierarchy|bands|matrix|comparison|timeline)$'

# ---------------------------------------------------------------------------
# 1. The rules, from the profile
# ---------------------------------------------------------------------------

function Resolve-ProfilePath {
    param([string] $Profile, [string] $BuildDir, [string] $SkillDir, [switch] $AnyForSelfTest)
    if ($Profile) {
        if (-not (Test-Path -LiteralPath $Profile)) { throw "$GATE`: -Profile not found: $Profile" }
        return (Resolve-Path -LiteralPath $Profile).Path
    }
    $assets = Join-Path $SkillDir 'assets'
    $brand = ''
    if ($BuildDir) {
        $c = Get-GateContract -BuildDir $BuildDir
        if ($null -ne $c -and @($c.PSObject.Properties.Name) -contains 'build') {
            $brand = "" + (Get-GateProp -Object $c.build -Names @('rto', 'brand') -Default '')
        }
    }
    $packs = @(Get-ChildItem -LiteralPath $assets -Filter 'rto-profile.*.json' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '(?i)schema' })
    if ($brand) {
        $cand = @($packs | Where-Object { $_.Name -ieq ('rto-profile.' + $brand + '.json') })
        if ($cand.Count -gt 0) { return $cand[0].FullName }
    }
    if ($AnyForSelfTest -and $packs.Count -gt 0) { return $packs[0].FullName }
    $looked = if ($brand) { " (looked for rto-profile.$brand.json in $assets)" } else { '' }
    throw ("$GATE`: no RTO profile. Pass -Profile <rto-profile.json>, or a -BuildDir whose contract.json names build.brand with a matching assets\rto-profile.<brand>.json" + $looked + ". The person-noun list and the required negatives are DERIVED from the profile; without it this lint would have to type them, which is the drift this gate exists to end.")
}

function Get-FramingAllowList {
    <# imageFraming.allowList: slot -> written reason. Refuses an entry with no reason. #>
    param($Framing, [string] $Where)
    $out = @{}
    $al = Get-GateProp -Object $Framing -Names @('allowList', 'allow')
    if ($null -eq $al) { return $out }
    $entries = New-Object System.Collections.Generic.List[object]
    if ($al -is [System.Collections.IEnumerable] -and $al -isnot [string]) {
        foreach ($e in @($al)) {
            if ($null -eq $e) { continue }
            $entries.Add([pscustomobject]@{ Id = ("" + (Get-GateProp -Object $e -Names @('slot', 'id', 'figure'))); Why = ("" + (Get-GateProp -Object $e -Names @('reason', 'why', 'note'))) })
        }
    }
    else {
        foreach ($prop in $al.PSObject.Properties) {
            if ($prop.Name -like '_*') { continue }
            $why = ''
            if ($prop.Value -is [string]) { $why = $prop.Value }
            else { $why = "" + (Get-GateProp -Object $prop.Value -Names @('reason', 'why', 'note')) }
            $entries.Add([pscustomobject]@{ Id = $prop.Name; Why = $why })
        }
    }
    foreach ($e in $entries) {
        if (-not $e.Id) { throw "$GATE`: an imageFraming.allowList entry names no slot ($Where)." }
        if ($e.Why.Trim().Length -lt 20) {
            throw ("$GATE`: imageFraming.allowList entry '{0}' carries no written reason, or one too short to be one ({1}). Record WHY a person is the legitimate subject of that slot, so the audit can weigh it." -f $e.Id, $Where)
        }
        $out[$e.Id] = $e.Why
    }
    return $out
}

function Get-FramingRules {
    param([string] $ProfilePath)
    $p = Get-GateJson -Path $ProfilePath
    if ($null -eq $p) { throw "$GATE`: profile is empty or not JSON: $ProfilePath" }
    $fr = Get-GateProp -Object $p -Names @('imageFraming', 'framing')
    if ($null -eq $fr) { throw "$GATE`: the profile carries no imageFraming block: $ProfilePath" }

    $nouns = @(@(Get-GateProp -Object $fr -Names @('personNouns') -Default @()) | ForEach-Object { "$_".Trim().ToLowerInvariant() } | Where-Object { $_ } | Select-Object -Unique)
    if ($nouns.Count -eq 0) { throw "$GATE`: imageFraming.personNouns is empty in $ProfilePath - a subject test with an empty list passes by having nothing to check." }

    $neg = [ordered]@{}
    $rn = Get-GateProp -Object $fr -Names @('requiredNegatives')
    if ($null -ne $rn) {
        foreach ($prop in $rn.PSObject.Properties) {
            if ($prop.Name -like '_*') { continue }
            $neg[$prop.Name] = @(@($prop.Value) | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
        }
    }

    $opener = "" + (Get-GateProp -Object $fr -Names @('framingOpener', 'framingSentencePattern') -Default '')
    $openerFrom = 'imageFraming.framingOpener'
    if (-not $opener) { $opener = $script:DefaultFramingOpener; $openerFrom = 'script default; override with imageFraming.framingOpener' }

    return [pscustomobject]@{
        Path        = $ProfilePath
        Rto         = "" + (Get-GateProp -Object $p -Names @('rto', 'brand') -Default '?')
        SubjectRule = ("" + (Get-GateProp -Object $fr -Names @('subjectRule') -Default '')).Trim().ToLowerInvariant()
        PersonNouns = $nouns
        Negatives   = $neg
        Opener      = $opener
        OpenerFrom  = $openerFrom
        Allow       = (Get-FramingAllowList -Framing $fr -Where $ProfilePath)
    }
}

# ---------------------------------------------------------------------------
# 2. The subject test - closed list, head of the subject phrase
# ---------------------------------------------------------------------------

function Test-PersonNoun {
    <# The noun if this word is a person noun (singular or plural); $null otherwise. A possessive is a modifier, never the head. #>
    param([string] $Word, [string[]] $Nouns)
    $w = "$Word".ToLowerInvariant()
    if ($w -match "(?:'|\u2019)s$") { return $null }
    $w = $w.Trim("'")
    if ($Nouns -contains $w) { return $w }
    if ($w.Length -gt 3 -and $w.EndsWith('es') -and ($Nouns -contains $w.Substring(0, $w.Length - 2))) { return $w.Substring(0, $w.Length - 2) }
    if ($w.Length -gt 2 -and $w.EndsWith('s') -and ($Nouns -contains $w.Substring(0, $w.Length - 1))) { return $w.Substring(0, $w.Length - 1) }
    return $null
}

function Get-PromptSubjectNoun {
    <#  The offending person noun and where it sits, or $null.

        Rule 1 - head of the first clause: a person noun within the first six
        words, before any preposition, verb marker or punctuation.
        Rule 2 - the phrase after of / showing / featuring / depicting: a person
        noun within the next four content words, before any preposition.
        Both run over the first two sentences, so "Documentary photograph. A
        chef plates ..." is still caught.  #>
    param([string] $Prompt, [string[]] $Nouns)
    $p = "$Prompt".Trim()
    if (-not $p) { return $null }
    $sentences = @([regex]::Split($p, '(?<=\.)\s+(?=[A-Z])') | Select-Object -First 2)
    $wordRx = "[A-Za-z][A-Za-z'\u2019\-]*"

    foreach ($sentence in $sentences) {
        $clause = @([regex]::Split($sentence, ',\s|;|:|\('))[0]
        $words = @([regex]::Matches($clause, $wordRx) | ForEach-Object { $_.Value })
        $limit = [math]::Min(6, $words.Count)
        for ($i = 0; $i -lt $limit; $i++) {
            $w = $words[$i].ToLowerInvariant()
            if ($script:Prepositions -contains $w -or $script:SubjectTriggers -contains $w -or $script:VerbMarkers -contains $w) { break }
            $hit = Test-PersonNoun -Word $words[$i] -Nouns $Nouns
            if ($hit) { return [pscustomobject]@{ Noun = $hit; Word = $words[$i]; Position = ($i + 1); Rule = 'head of the first clause' } }
        }

        $all = @([regex]::Matches($sentence, $wordRx) | ForEach-Object { $_.Value })
        for ($i = 0; $i -lt $all.Count; $i++) {
            $w = $all[$i].ToLowerInvariant()
            if ($script:SubjectTriggers -notcontains $w) { continue }
            $seen = 0
            for ($j = $i + 1; $j -lt $all.Count -and $seen -lt 4; $j++) {
                $x = $all[$j].ToLowerInvariant()
                if ($script:Skippable -contains $x) { continue }
                if ($script:Prepositions -contains $x -or $script:SubjectTriggers -contains $x -or $script:VerbMarkers -contains $x) { break }
                $seen++
                $hit = Test-PersonNoun -Word $all[$j] -Nouns $Nouns
                if ($hit) { return [pscustomobject]@{ Noun = $hit; Word = $all[$j]; Position = ($j + 1); Rule = ("subject of '{0}'" -f $all[$i]) } }
            }
        }
    }
    return $null
}

function Get-MissingNegatives {
    <# Required phrases absent from the prompt, compared normalised and word-bounded. #>
    param([string] $Prompt, [string[]] $Required)
    $np = ConvertTo-GateNormal $Prompt
    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($r in @($Required)) {
        $nr = ConvertTo-GateNormal $r
        if (-not $nr) { continue }
        if (-not [regex]::IsMatch($np, ('(?<![a-z0-9])' + [regex]::Escape($nr) + '(?![a-z0-9])'))) { $missing.Add($r) }
    }
    return $missing.ToArray()
}

function Test-RouteA {
    <# Route A is generated; Route B is built natively and never reaches the endpoint. Unknown kinds with no spec are generated. #>
    param($V)
    $k = ("" + $V.Kind).Trim().ToLowerInvariant()
    if ($k -match $script:RouteAKinds) { return $true }
    if ($k -match $script:RouteBKinds) { return $false }
    return ($null -eq $V.Spec)
}

# ---------------------------------------------------------------------------
# 3. The lint
# ---------------------------------------------------------------------------

function Get-PlManifestGeneratedSlot {
    <#  The slots the ARTWORK MANIFEST says are generated, counted with the same
        route predicate this file applies to the spine, so one definition
        decides both sides of the comparison. A placeholder counts when its
        kind is a Route A kind (or it carries no spec and no Route B kind),
        which is exactly Test-RouteA.  #>
    param([string] $Path)
    $j = Get-GateJson -Path $Path
    if ($null -eq $j) { return $null }
    $slots = New-Object System.Collections.Generic.List[string]
    foreach ($p in @(Get-GateProp -Object $j -Names @('placeholders', 'entries', 'images') -Default @())) {
        if ($null -eq $p) { continue }
        $v = [pscustomobject]@{
            Kind = [string](Get-GateProp -Object $p -Names @('kind', 'type'))
            Spec = (Get-GateProp -Object $p -Names @('spec'))
        }
        if (Test-RouteA $v) { $slots.Add([string](Get-GateProp -Object $p -Names @('slot', 'id', 'figure'))) }
    }
    return $slots.ToArray()
}

function Invoke-PromptLint {
    param($Rules, [string] $BuildDir, [string] $SpineDir, [hashtable] $ExtraAllow)

    #  -IncludeFrontMatter IS LOAD-BEARING. Without it cover.json is outside the
    #  walk and the guide's first image is linted by nobody.
    $visuals = @(Get-GateSpineVisuals -BuildDir $BuildDir -SpineDir $SpineDir -IncludeFrontMatter)
    $allow = @{}
    foreach ($k in $Rules.Allow.Keys) { $allow[$k] = $Rules.Allow[$k] }
    if ($null -ne $ExtraAllow) { foreach ($k in $ExtraAllow.Keys) { $allow[$k] = $ExtraAllow[$k] } }

    $results = New-Object System.Collections.Generic.List[object]
    $kindsA = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $kindsB = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $routeA = 0; $routeB = 0

    foreach ($v in $visuals) {
        if (-not (Test-RouteA $v)) { $routeB++; [void]$kindsB.Add("" + $v.Kind); continue }
        $routeA++
        [void]$kindsA.Add("" + $v.Kind)

        $prompt = "" + $v.Prompt
        $problems = New-Object System.Collections.Generic.List[string]
        $framed = [regex]::IsMatch($prompt, $Rules.Opener, 'IgnoreCase')
        $allowed = ($v.Slot -and $allow.ContainsKey($v.Slot))
        $subject = $null

        if (-not $prompt.Trim()) { $problems.Add('empty prompt') }
        elseif ($Rules.SubjectRule -eq 'hands-and-equipment') {
            if (-not $framed) {
                $subject = Get-PromptSubjectNoun -Prompt $prompt -Nouns $Rules.PersonNouns
                if ($subject -and -not $allowed) {
                    $problems.Add(("subject '{0}' ({1}, word {2}): a person is the subject and the prompt does not open with the framing sentence" -f $subject.Word, $subject.Rule, $subject.Position))
                }
            }
        }

        $required = New-Object System.Collections.Generic.List[string]
        $classes = New-Object System.Collections.Generic.List[string]
        if ($Rules.Negatives.Contains('any')) { foreach ($x in @($Rules.Negatives['any'])) { $required.Add($x) }; $classes.Add('any') }
        if ($subject -and $allowed -and $Rules.Negatives.Contains('person-present')) {
            foreach ($x in @($Rules.Negatives['person-present'])) { $required.Add($x) }
            $classes.Add('person-present')
        }
        $declared = Get-GateProp -Object $v.Node -Names @('subjectClass', 'subjectClasses', 'negativeClass', 'promptClass')
        foreach ($c in @($declared)) {
            if (-not $c) { continue }
            $cn = "$c".Trim()
            if ($Rules.Negatives.Contains($cn)) { foreach ($x in @($Rules.Negatives[$cn])) { $required.Add($x) }; $classes.Add($cn) }
            else { $problems.Add(("declares subject class '{0}', which the profile's requiredNegatives does not define" -f $cn)) }
        }
        $missing = @(Get-MissingNegatives -Prompt $prompt -Required @($required | Select-Object -Unique))
        if ($missing.Count -gt 0) {
            $problems.Add(("missing negative(s): {0}  [class {1}]" -f (($missing | ForEach-Object { "'" + $_ + "'" }) -join ', '), ($classes -join '+')))
        }

        $results.Add([pscustomobject]@{
            Slot = "" + $v.Slot; File = $v.File; Kind = "" + $v.Kind
            Framed = $framed; Allowed = $allowed
            AllowReason = $(if ($allowed) { $allow[$v.Slot] } else { '' })
            SubjectNoun = $(if ($subject) { $subject.Noun } else { '' })
            Classes = @($classes); Missing = $missing
            Problems = @($problems); Pass = ($problems.Count -eq 0)
            Prompt = $prompt
        })
    }

    #  The cover is one of the walked files, not a special case in the lint: it
    #  is linted by the same rules and only COUNTED separately, so its arm can
    #  say whether it was examined at all.
    $coverResults = @($results | Where-Object { "$($_.File)" -eq 'cover.json' })
    #  The subjectClass arm reports what it EXAMINED. A prompt that declares no
    #  class is not a prompt that passed the class rule.
    $classDeclared = @($results | Where-Object { @($_.Classes | Where-Object { $_ -ne 'any' -and $_ -ne 'person-present' }).Count -gt 0 })

    return [pscustomobject]@{
        Results = $results.ToArray(); Visuals = $visuals.Count
        RouteA = $routeA; RouteB = $routeB
        KindsA = @($kindsA | Sort-Object); KindsB = @($kindsB | Sort-Object)
        Allow = $allow
        Cover = $coverResults
        SubjectClassExamined = $classDeclared.Count
    }
}

function Write-LintReport {
    param($Rules, $Run, [switch] $Quiet)
    if (-not $Quiet) {
        Write-Host ''
        Write-Host 'PROMPT LINT - Route A prompts against the house framing rule, before any spend' -ForegroundColor Cyan
        Write-Host ("  profile: {0}  (rto {1}, subjectRule '{2}')" -f (Split-Path $Rules.Path -Leaf), $Rules.Rto, $Rules.SubjectRule) -ForegroundColor DarkGray
        Write-GateCheckSet -What 'person nouns' -Count $Rules.PersonNouns.Count -DerivedFrom ('imageFraming.personNouns in ' + (Split-Path $Rules.Path -Leaf))
        foreach ($k in $Rules.Negatives.Keys) {
            Write-GateCheckSet -What ("required negative(s), class '{0}'" -f $k) -Count @($Rules.Negatives[$k]).Count -DerivedFrom 'imageFraming.requiredNegatives'
        }
        Write-Host ("  framing opener: {0}   [{1}]" -f $Rules.Opener, $Rules.OpenerFrom) -ForegroundColor DarkGray
        Write-Host ("  visuals: {0} on the spine - {1} Route A linted (kinds: {2}), {3} Route B skipped (kinds: {4})" -f $Run.Visuals, $Run.RouteA, ($Run.KindsA -join ', '), $Run.RouteB, ($Run.KindsB -join ', ')) -ForegroundColor DarkGray
        if ($Run.Allow.Count -gt 0) {
            Write-Host ("  allow-list: {0} slot(s), surfaced to the audit as evidence:" -f $Run.Allow.Count) -ForegroundColor DarkGray
            foreach ($k in ($Run.Allow.Keys | Sort-Object)) { Write-Host ("    {0}: {1}" -f $k, $Run.Allow[$k]) -ForegroundColor DarkGray }
        }
        else { Write-Host '  allow-list: empty' -ForegroundColor DarkGray }
        Write-Host ''
    }
    $failed = @($Run.Results | Where-Object { -not $_.Pass })
    foreach ($r in $failed) {
        foreach ($p in $r.Problems) { Write-Host ("  X {0,-7} {1,-16} {2}" -f $r.Slot, $r.File, $p) -ForegroundColor Red }
        $snip = ($r.Prompt -replace '\s+', ' ').Trim()
        if ($snip.Length -gt 110) { $snip = $snip.Substring(0, 107) + '...' }
        Write-Host ("    {0,-7} {1,-16} {2}" -f '', '', $snip) -ForegroundColor DarkGray
    }
    $subj = @($failed | Where-Object { $_.SubjectNoun -and -not $_.Allowed -and -not $_.Framed }).Count
    $negs = @($failed | Where-Object { @($_.Missing).Count -gt 0 }).Count
    Write-Host ''
    if ($failed.Count -eq 0) {
        Write-Host ("  {0} Route A prompt(s) checked, every one framed hands-and-equipment and carrying its required negatives" -f $Run.RouteA) -ForegroundColor Green
    }
    else {
        Write-Host ("  {0} Route A prompt(s) checked, {1} failed ({2} person-subject, {3} missing negatives)" -f $Run.RouteA, $failed.Count, $subj, $negs) -ForegroundColor Red
        Write-Host '  Fix the SPINE prompt: open with the framing sentence and make hands, tools and food the subject;' -ForegroundColor Yellow
        Write-Host '  add the missing negatives verbatim. Clear a legitimate person-subject slot only in the allow-list, with a reason.' -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
# 4. Self-test - three synthetic prompts built FROM the profile's own lists
# ---------------------------------------------------------------------------

function Invoke-LintSelfTest {
    param($Rules)
    $script:stPass = 0; $script:stFail = 0
    $ok  = { param($m) $script:stPass++; Write-Host "  PASS  $m" -ForegroundColor Green }
    $bad = { param($m) $script:stFail++; Write-Host "  FAIL  $m" -ForegroundColor Red }

    Write-Host ''
    Write-Host "$GATE self-test" -ForegroundColor Cyan
    Write-Host ("  fixtures derived from {0}" -f (Split-Path $Rules.Path -Leaf)) -ForegroundColor DarkGray

    if (-not $Rules.Negatives.Contains('any') -or @($Rules.Negatives['any']).Count -lt 1) {
        & $bad "the profile defines no 'any' class in imageFraming.requiredNegatives, so the negatives fixture cannot be built"
        return $script:stFail
    }
    $noun = $Rules.PersonNouns[0]
    $anyAll = @($Rules.Negatives['any'])
    $anyButLast = @($anyAll | Select-Object -First ($anyAll.Count - 1))
    $dropped = $anyAll[$anyAll.Count - 1]
    $framing = 'Framed from the shoulders down, so that no head, face or chin appears anywhere in the picture. '
    $p1 = ("A {0} in whites weighs diced potato on a bench scale at a stainless steel bench. {1}." -f $noun, ($anyAll -join ', '))
    $p2 = $framing + $p1
    $p3 = ("Close view of gloved hands weighing diced potato on a bench scale. {0}." -f ($anyButLast -join ', '))
    if ($anyButLast.Count -eq 0) { $p3 = 'Close view of gloved hands weighing diced potato on a bench scale.' }

    # the plant must be verified to have landed before the gate is believed
    $s1 = Get-PromptSubjectNoun -Prompt $p1 -Nouns $Rules.PersonNouns
    if ($s1 -and $s1.Noun -eq $noun) { & $ok ("fixture plant landed: '{0}' is the subject of prompt 1" -f $noun) } else { & $bad 'fixture plant did not land: prompt 1 has no person subject' }
    if ([regex]::IsMatch($p2, $Rules.Opener, 'IgnoreCase')) { & $ok 'fixture plant landed: prompt 2 opens with the framing sentence' } else { & $bad 'fixture plant did not land: the framing opener does not match prompt 2' }
    if (-not (ConvertTo-GateNormal $p3).Contains((ConvertTo-GateNormal $dropped))) { & $ok ("fixture plant landed: prompt 3 omits '{0}'" -f $dropped) } else { & $bad 'fixture plant did not land: prompt 3 still carries the dropped negative' }

    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('apl_selftest_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path (Join-Path $root 'spine') | Out-Null
    try {
        $spine = [ordered]@{
            ref = '9.1'; pc = '9.1'; topic = 9; title = 'Self-test'
            visuals = @(
                [ordered]@{ slot = '9.1.1'; kind = 'Image'; prompt = $p1; caption = 'person subject, unframed' },
                [ordered]@{ slot = '9.1.2'; kind = 'Image'; prompt = $p2; caption = 'person subject, framed' },
                [ordered]@{ slot = '9.1.3'; kind = 'Image'; prompt = $p3; caption = 'hands only, one negative missing' },
                [ordered]@{ slot = '9.1.4'; kind = 'Diagram'; prompt = ("A flow showing how a {0} checks an order line." -f $noun); caption = 'Route B, must be skipped'; spec = [ordered]@{ layout = 'table'; rows = @(@('Step', 'Do')) } }
            )
        }
        [System.IO.File]::WriteAllText((Join-Path $root 'spine\t9_9.1.json'), ($spine | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding($false)))

        $run = Invoke-PromptLint -Rules $Rules -BuildDir $root -SpineDir (Join-Path $root 'spine')
        Write-LintReport -Rules $Rules -Run $run -Quiet

        $r1 = @($run.Results | Where-Object { $_.Slot -eq '9.1.1' })[0]
        $r2 = @($run.Results | Where-Object { $_.Slot -eq '9.1.2' })[0]
        $r3 = @($run.Results | Where-Object { $_.Slot -eq '9.1.3' })[0]
        if ($run.RouteA -eq 3 -and $run.RouteB -eq 1) { & $ok 'three Route A prompts linted, the diagram skipped' } else { & $bad ("Route A {0} / Route B {1}, wanted 3 / 1" -f $run.RouteA, $run.RouteB) }
        if ($null -ne $r1 -and -not $r1.Pass -and $r1.SubjectNoun -eq $noun) { & $ok ("prompt 1 FAILS on subject '{0}'" -f $noun) } else { & $bad 'prompt 1 should fail on its person subject' }
        if ($null -ne $r1 -and @($r1.Missing).Count -eq 0) { & $ok 'prompt 1 carries every required negative (fails on the subject alone)' } else { & $bad 'prompt 1 reported missing negatives it carries' }
        if ($null -ne $r2 -and $r2.Pass -and $r2.Framed) { & $ok 'prompt 2 (same prompt, framing sentence prepended) PASSES' } else { & $bad ("prompt 2 should pass: {0}" -f (@($r2.Problems) -join '; ')) }
        if ($null -ne $r3 -and -not $r3.Pass -and -not $r3.SubjectNoun -and (@($r3.Missing) -contains $dropped)) { & $ok ("prompt 3 (hands only) FAILS on the missing negative '{0}' and not on its subject" -f $dropped) } else { & $bad 'prompt 3 should fail on the missing negative only' }
    }
    finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }

    # -----------------------------------------------------------------------
    # THE COVER AND THE MANIFEST (P0-11), proved through the EXIT CODE a runner
    # reads. These run THIS script as a child: the cover arm, the manifest
    # reconciliation and the absent-sub-skill rule all live at the top level.
    # -----------------------------------------------------------------------

    $root2 = Join-Path ([System.IO.Path]::GetTempPath()) ('apl_cover_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    try {
        $enc = New-Object System.Text.UTF8Encoding($true)
        $cleanPrompt = $framing + ("Close view of gloved hands weighing diced potato on a bench scale at a stainless steel bench. {0}." -f ($anyAll -join ', '))
        $facePrompt  = ("A {0} in whites looks up from the pass while checking a delivery docket. {1}." -f $noun, ($anyAll -join ', '))

        function New-PlFixture {
            param([string] $Dir, [string] $CoverPrompt, [int] $ManifestGenerated = -1, [switch] $NoRouteB)
            New-Item -ItemType Directory -Force -Path (Join-Path $Dir 'spine') | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $Dir 'contract.json'), (([ordered]@{ build = [ordered]@{ brand = '' }; unit = [ordered]@{ code = 'FIXTURE001' } }) | ConvertTo-Json -Depth 8), $enc)
            $vis = New-Object System.Collections.Generic.List[object]
            $vis.Add([ordered]@{ slot = '9.1.1'; kind = 'Image'; prompt = $script:PlCleanPrompt; caption = 'hands only, clean' })
            if (-not $NoRouteB) { $vis.Add([ordered]@{ slot = '9.1.2'; kind = 'Diagram'; prompt = 'A flow of the order line.'; caption = 'Route B'; spec = [ordered]@{ layout = 'table'; rows = @(@('Step', 'Do')) } }) }
            $sub = [ordered]@{ ref = '9.1'; pc = '9.1'; topic = 9; title = 'Fixture'; visuals = $vis.ToArray() }
            [System.IO.File]::WriteAllText((Join-Path $Dir 'spine\t9_9.1.json'), ($sub | ConvertTo-Json -Depth 10), $enc)
            #  The cover plans its image under the SINGULAR name, which is the
            #  shape every visuals gate used to miss.
            $cover = [ordered]@{ title = 'Fixture cover'; visual = [ordered]@{ slot = '0.1'; kind = 'Image'; prompt = $CoverPrompt; caption = 'cover image' } }
            [System.IO.File]::WriteAllText((Join-Path $Dir 'spine\cover.json'), ($cover | ConvertTo-Json -Depth 10), $enc)
            if ($ManifestGenerated -ge 0) {
                New-Item -ItemType Directory -Force -Path (Join-Path $Dir 'images') | Out-Null
                $ph = New-Object System.Collections.Generic.List[object]
                for ($i = 1; $i -le $ManifestGenerated; $i++) { $ph.Add([ordered]@{ id = ('IMG-{0:d3}' -f $i); slot = ('9.1.' + $i); kind = 'illustration'; status = 'generated' }) }
                if (-not $NoRouteB) { $ph.Add([ordered]@{ id = 'DIA-001'; slot = '9.1.9'; kind = 'diagram'; status = 'drawn'; spec = [ordered]@{ layout = 'table' } }) }
                [System.IO.File]::WriteAllText((Join-Path $Dir 'images\manifest.json'), (([ordered]@{ sourceDocument = 'fixture.docx'; placeholders = $ph.ToArray() }) | ConvertTo-Json -Depth 10), $enc)
            }
            return $Dir
        }
        $script:PlCleanPrompt = $cleanPrompt

        function Invoke-PlChild {
            param([string] $Build, [int] $Expect, [string[]] $Names, [string] $What, [switch] $Require)
            $out = ''
            $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script:PlSelf, '-BuildDir', $Build, '-Profile', $Rules.Path)
            if ($Require) { $args += '-RequireManifest' }
            try { $out = (& powershell.exe @args 2>&1 | Out-String -Width 4096) } catch { $out = "$($_.Exception.Message)" }
            $code = $LASTEXITCODE
            $missing = @($Names | Where-Object { $out.IndexOf($_, [System.StringComparison]::OrdinalIgnoreCase) -lt 0 })
            if ($code -eq $Expect -and $missing.Count -eq 0) { & $ok ("{0} -> exit {1}, naming {2}" -f $What, $code, (($Names | ForEach-Object { "'" + $_ + "'" }) -join ' and ')) }
            else {
                & $bad ("{0} -> exit {1} (wanted {2}); not named: {3}" -f $What, $code, $Expect, $(if ($missing.Count) { ($missing -join ' | ') } else { 'nothing' }))
                foreach ($ln in @(($out -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -Last 5)) { Write-Host ("      | {0}" -f $ln) -ForegroundColor DarkGray }
            }
        }

        #  0. the clean control: cover clean, manifest agrees (2 Route A: the
        #     sub-section image and the cover).
        $b0 = New-PlFixture -Dir (Join-Path $root2 'clean') -CoverPrompt $cleanPrompt -ManifestGenerated 2
        Invoke-PlChild -Build $b0 -Expect 0 -Names @('ARMS: ', 'cover-visual|true|ran|1', 'manifest-parity|true|ran|2') -What 'clean cover with a manifest that agrees'

        #  1. A FACE-NAMING COVER PROMPT. Verified to have landed first.
        $b1 = New-PlFixture -Dir (Join-Path $root2 'facecover') -CoverPrompt $facePrompt -ManifestGenerated 2
        $backCover = Get-GateFileText -Path (Join-Path $b1 'spine\cover.json')
        if ($backCover.IndexOf($noun, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { & $bad 'cover plant did not land: the person noun is not in cover.json' }
        else {
            Write-Host ("    plant landed: the cover prompt names a {0} as its subject" -f $noun) -ForegroundColor DarkGray
            Invoke-PlChild -Build $b1 -Expect 1 -Names @('cover.json', $noun) -What 'a face-naming cover prompt fails naming cover.json'
        }

        #  2. A ROUTE A COUNT THAT DISAGREES WITH THE MANIFEST. 2 planned, 5
        #     generated: both numbers must be named.
        $b2 = New-PlFixture -Dir (Join-Path $root2 'countgap') -CoverPrompt $cleanPrompt -ManifestGenerated 5
        $gen = @(Get-PlManifestGeneratedSlot -Path (Join-Path $b2 'images\manifest.json'))
        if ($gen.Count -ne 5) { & $bad ("count plant did not land: the fixture manifest declares {0} generated slot(s), wanted 5" -f $gen.Count) }
        else {
            Write-Host '    plant landed: the manifest declares 5 generated slots against 2 planned Route A prompts' -ForegroundColor DarkGray
            Invoke-PlChild -Build $b2 -Expect 1 -Names @('2 Route A prompt', '5 generated slot') -What 'a Route A count differing from the manifest fails naming both numbers'
        }

        #  3. THE ABSENT-SUB-SKILL RULE, both halves. Route B declared and no
        #     manifest is a refusal naming the manifest; a guide-only build
        #     with no Route B prints the absence and continues.
        $b3 = New-PlFixture -Dir (Join-Path $root2 'nomanifest') -CoverPrompt $cleanPrompt
        Invoke-PlChild -Build $b3 -Expect 2 -Names @('CHECK-SET EMPTY', 'manifest.json', 'Route B') -What 'an absent manifest with a Route B visual on the spine is refused by name'
        $b4 = New-PlFixture -Dir (Join-Path $root2 'guideonly') -CoverPrompt $cleanPrompt -NoRouteB
        Invoke-PlChild -Build $b4 -Expect 0 -Names @('artwork manifest absent', 'manifest.json', 'manifest-parity|false|empty') -What 'a guide-only build with no Route B prints the absence by name and continues'
    }
    finally { Remove-Item -LiteralPath $root2 -Recurse -Force -ErrorAction SilentlyContinue }

    Write-Host ''
    Write-Host ("  self-test: {0} passed, {1} failed" -f $script:stPass, $script:stFail) -ForegroundColor $(if ($script:stFail) { 'Red' } else { 'Green' })
    return $script:stFail
}

# ---------------------------------------------------------------------------
# Entry
# ---------------------------------------------------------------------------

$profilePath = $null
try { $profilePath = Resolve-ProfilePath -Profile $Profile -BuildDir $BuildDir -SkillDir $SkillDir -AnyForSelfTest:$SelfTest }
catch { Write-Host ("  X {0}" -f $_.Exception.Message) -ForegroundColor Red; exit 2 }
$rules = Get-FramingRules -ProfilePath $profilePath

if ($SelfTest) {
    $failed = Invoke-LintSelfTest -Rules $rules
    if ($failed -gt 0) { exit 4 }
    exit 0
}

if (-not $BuildDir) {
    Write-Host "  X $GATE`: -BuildDir <build> is required (the spine is read from it)." -ForegroundColor Red
    exit 2
}

$extra = @{}
$registry = Get-GateRegistry -BuildDir $BuildDir
if ($null -ne $registry) { $extra = Get-GateAllowList -Registry $registry -Key 'promptAllow' -IdField @('slot', 'id', 'figure') -GateName $GATE }

$run = $null
try { $run = Invoke-PromptLint -Rules $rules -BuildDir $BuildDir -SpineDir $SpineDir -ExtraAllow $extra }
catch { Write-Host ("  X {0}" -f $_.Exception.Message) -ForegroundColor Red; exit 2 }

Write-LintReport -Rules $rules -Run $run -Quiet:$Quiet

# ---------------------------------------------------------------------------
# The arm roster, the cover arm, and the manifest reconciliation
# ---------------------------------------------------------------------------

if (-not $ManifestPath) { $ManifestPath = Join-Path $BuildDir 'images\manifest.json' }
$manifestPresent = (Test-Path -LiteralPath $ManifestPath)
#  A build that declares a Route B visual is a build that uses the sub-skill,
#  so its manifest is not optional. Derived from the spine, never declared.
$manifestRequired = ($RequireManifest -or $run.RouteB -gt 0)

$plNa = @{}
try {
    foreach ($arm in @('cover-visual', 'manifest-parity')) {
        $r = Get-GateDeclaredNa -BuildDir $BuildDir -Gate $GATE -Arm $arm
        if ($r) { $plNa[$arm] = $r }
    }
}
catch { Write-Host ("  X {0}: {1}" -f $GATE, $_.Exception.Message) -ForegroundColor Red; exit 2 }

#  The profile decides whether the subjectClass arm blocks. It reports
#  examined = 0 otherwise - never a green line over an arm that saw nothing.
$classMandatory = $false
$imf = Get-GateProp -Object (Get-GateJson -Path $rules.Path) -Names @('imageFraming')
if ($null -ne $imf) {
    $sc = Get-GateProp -Object $imf -Names @('subjectClassMandatory', 'requireSubjectClass')
    if ("$sc" -match '^(?i)(true|yes|1)$') { $classMandatory = $true }
}

Reset-GateArmRoster
Register-GateArm -Name 'person-nouns' -Blocking
Register-GateArm -Name 'required-negatives' -Blocking
Register-GateArm -Name 'route-a-prompts' -Blocking
Register-GateArm -Name 'cover-visual' -Blocking:(-not $plNa.ContainsKey('cover-visual'))
Register-GateArm -Name 'manifest-parity' -Blocking:($manifestRequired -and -not $plNa.ContainsKey('manifest-parity'))
Register-GateArm -Name 'subject-classes' -Blocking:$classMandatory

$plFail = 0
$plRoster = @()
try {
    Write-GateCheckSet -What 'person noun(s)' -Count $rules.PersonNouns.Count -DerivedFrom ('imageFraming.personNouns in ' + (Split-Path $rules.Path -Leaf)) -Blocking -Input ($rules.Path + ' imageFraming.personNouns - the closed list the subject rule is matched against yielded nothing, so no prompt could fail on its subject')
    Complete-GateArm -Name 'person-nouns' -State 'ran' -Size $rules.PersonNouns.Count

    $negCount = 0
    foreach ($k in $rules.Negatives.Keys) { $negCount += @($rules.Negatives[$k]).Count }
    Write-GateCheckSet -What 'required negative phrase(s), all classes' -Count $negCount -DerivedFrom ('imageFraming.requiredNegatives in ' + (Split-Path $rules.Path -Leaf)) -Blocking -Input ($rules.Path + ' imageFraming.requiredNegatives - not one required phrase is declared, so no prompt could fail on a missing negative')
    Complete-GateArm -Name 'required-negatives' -State 'ran' -Size $negCount

    Write-GateCheckSet -What 'Route A prompt(s) linted' -Count $run.RouteA -DerivedFrom ("the spine's own visuals, front matter included ({0} visual(s), {1} Route B)" -f $run.Visuals, $run.RouteB) -Blocking -Input ('the spine under ' + $BuildDir + ': no Route A prompt at all (' + $run.Visuals + ' visual(s), all Route B). A lint with nothing to lint passes by having nothing to check; if this build genuinely generates no illustration, declare it in contract.json gateArms')
    Complete-GateArm -Name 'route-a-prompts' -State 'ran' -Size $run.RouteA -Findings @($run.Results | Where-Object { -not $_.Pass }).Count

    if ($plNa.ContainsKey('cover-visual')) { Complete-GateArm -Name 'cover-visual' -State 'declared-n-a' -Reason $plNa['cover-visual'] }
    else {
        Write-GateCheckSet -What 'cover visual(s) linted' -Count @($run.Cover).Count -DerivedFrom "cover.json's own visual node, singular or plural, walked with the front matter" -Blocking -Input ((Join-Path $BuildDir 'spine\cover.json') + ' - no visual could be read from the cover, so the guide''s first image was linted by nobody')
        Complete-GateArm -Name 'cover-visual' -State 'ran' -Size @($run.Cover).Count -Findings @($run.Cover | Where-Object { -not $_.Pass }).Count
    }

    if ($plNa.ContainsKey('manifest-parity')) { Complete-GateArm -Name 'manifest-parity' -State 'declared-n-a' -Reason $plNa['manifest-parity'] }
    elseif ($manifestPresent) {
        $genSlots = Get-PlManifestGeneratedSlot -Path $ManifestPath
        if ($null -eq $genSlots) { throw ("CHECK-SET EMPTY: {0} is present and unreadable, so the generated-slot count could not be derived from it." -f $ManifestPath) }
        $genCount = @($genSlots).Count
        Write-GateCheckSet -What 'generated slot(s) in the artwork manifest' -Count $genCount -DerivedFrom ((Split-Path $ManifestPath -Leaf) + ' placeholders, counted with the same route predicate the spine is read with') -Blocking -Input ($ManifestPath + ' - the manifest is present and declares no generated slot, so the Route A count would be compared against nothing')
        if ($genCount -ne $run.RouteA) {
            Write-Host ("  X {0}: the spine plans {1} Route A prompt(s) and {2} declares {3} generated slot(s). One of them is wrong: either an image is generated that nothing plans, or a planned illustration is never made." -f $GATE, $run.RouteA, (Split-Path $ManifestPath -Leaf), $genCount) -ForegroundColor Red
            $plFail++
        }
        elseif (-not $Quiet) {
            Write-Host ("  manifest parity: {0} Route A prompt(s) on the spine = {1} generated slot(s) in {2}" -f $run.RouteA, $genCount, (Split-Path $ManifestPath -Leaf)) -ForegroundColor DarkGray
        }
        Complete-GateArm -Name 'manifest-parity' -State 'ran' -Size $genCount -Findings $plFail
    }
    elseif ($manifestRequired) {
        #  THE ABSENT-SUB-SKILL RULE. Refused BY NAME, because this build's own
        #  spine declares a Route B visual (or the comparison was asked for).
        throw ("CHECK-SET EMPTY: {0} is absent and this build needs it - the spine declares {1} Route B visual(s), so the artwork sub-skill is in use and its manifest is what actually gets generated. Supply the manifest, or declare gateArms.{2}.manifest-parity applicable:false with a written reason." -f $ManifestPath, $run.RouteB, $GATE)
    }
    else {
        #  A guide-only build with no diagram kind: print the absence BY NAME
        #  and continue on the spine's declared kinds.
        Write-Host ("  ! artwork manifest absent: {0}. This build declares no Route B visual, so the sub-skill is not in use and the Route A count is not reconciled against anything. Named here so its absence is on the record." -f $ManifestPath) -ForegroundColor Yellow
        Complete-GateArm -Name 'manifest-parity' -State 'empty'
    }

    if ($classMandatory) {
        Write-GateCheckSet -What 'visual(s) declaring a subjectClass' -Count $run.SubjectClassExamined -DerivedFrom 'the spine visuals'' own subjectClass field' -Blocking -Input ('the spine under ' + $BuildDir + ': the profile declares subjectClass mandatory and not one visual declares one')
        Complete-GateArm -Name 'subject-classes' -State 'ran' -Size $run.SubjectClassExamined
    }
    elseif ($run.SubjectClassExamined -gt 0) { Complete-GateArm -Name 'subject-classes' -State 'ran' -Size $run.SubjectClassExamined }
    else {
        Write-Host '  ! subjectClass arm examined 0 visual(s): the profile does not declare subjectClass mandatory and no visual declares one. Reported, not passed.' -ForegroundColor Yellow
        Complete-GateArm -Name 'subject-classes' -State 'empty'
    }

    Assert-GateArmsComplete
    $plRoster = Write-GateArmRoster
}
catch {
    $msg = $_.Exception.Message
    if ($msg -match '^(CHECK-SET EMPTY|ARMS INCOMPLETE)') {
        Write-Host ("  X {0} REFUSED - {1}" -f $GATE, $msg) -ForegroundColor Red
        [void](Write-GateArmRoster)
        exit 2
    }
    Write-Host ("  X {0}: {1}" -f $GATE, $msg) -ForegroundColor Red
    exit 1
}

if ($plFail -gt 0) { exit 1 }
if (@($run.Results | Where-Object { -not $_.Pass }).Count -gt 0) { exit 1 }
exit 0
