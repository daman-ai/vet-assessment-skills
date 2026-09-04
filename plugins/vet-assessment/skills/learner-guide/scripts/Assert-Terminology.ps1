<#
    Assert-Terminology.ps1 - one word per concept, in reading order, with the
    authority of every registered figure stated the way the registry classes it.

    Implements the gate references\gates.md section 24 specifies. Runs at Stage
    3c as a member of the spine gate band (section 12), one pass over every
    authored string of the spine. Re-runs unchanged before every Stage 7
    re-render. Pure self-consistency: it reads the spine, the build contract,
    the figure registry and - when one exists for this RTO - the profile pack.
    It opens no document and needs no external source.

    WHAT IT IS FOR. Section 24 records eleven separate round-one findings of
    this class in one build. The worst of them was a LEGISLATED figure labelled
    as the venue's own house standard on four consecutive slides - the single
    most-repeated teaching point in the unit, taught backwards, and two Stage 5
    personas had to raise it independently before it was believed. Until this
    file existed the whole check was performed by those personas and by the
    Stage 6 auditor, and the auditor is the reader who let an inverted scope
    statement through three rounds.

    THE AUTHORITY-CLASS RULES ARE GENERATED FROM THE CLASS, NEVER HAND-LISTED.
    For every figure in the registry, this script generates the rules its class
    implies: a class that means "named legislation or standard" may never be
    described in venue-ownership language, and a class that means "the venue's
    own documented procedure" may never be described as a legal requirement.
    Add a figure to the registry and its rules arrive with it; nothing here has
    to be edited. A figure whose class names MORE THAN ONE authority - the
    registry writes those as "V vs L", "L, adopted by V", "L and V" - is
    exactly the case where both registers are legitimate in one sentence, so
    those report and never block. That suppression is named, reasoned and
    counted below, not hidden.

    ONE SHARED OBLIGATION LIST. $script:OBLIGATION is defined once and every
    rule that needs a word of obligation composes it. Section 24: a rule that
    watched requires / mandates / sets missed the defective sentence because it
    said "approach". Widening one shared list widens every rule at once;
    widening a per-rule list fixes one rule and leaves the rest.

    READING ORDER IS COMPUTED, NOT ASSUMED. An acronym expanded on page 60 and
    used on page 12 is a defect, so first-use expansion is decided by the
    spine's own sequence: the contract's topic and PC order gives the file
    order, and a spine file's JSON property declaration order is its render
    order (the sub-section files declare whatThisMeans, remember,
    underpinningKnowledge, regulatoryBasis, howToDoIt ... in exactly the order
    Invoke-Render emits them). The two artefacts are two reading orders: an
    acronym expanded in the guide is not expanded on the deck, so the guide
    channels and the slides channel are ordered and checked separately.

    NOTHING HERE IS A LITERAL FROM ONE BUILD. Locked terms, near-synonyms,
    paired forms, acronyms, glossary canon, the ambiguity list, the question
    map, the chip cap, the authority classes and the venue's own name are all
    derived from contract.json, figures.json, the spine's own key terms and the
    RTO profile pack. There is no unit code, RTO code, CRICOS code, provider
    number or hex anywhere in this file.

    BLOCKING ARMS (section 24, exact):
      locked-synonym          a forbidden near-synonym of a locked term
      glossary-variant        a locked or glossary term restated off-canon
      acronym-order           an acronym used before its expansion, per surface
      structural-label        a chip or kicker label that is not the spine's own
      qa-pairing              self-check questions and answer pointers unpaired
      truncation              "and N more", a trailing ellipsis, a cut chip
      chip-cap                a chip naming more references than the cap allows
      build-vocabulary        build words or a bare provenance class on the page
      ambiguity               an ambiguity-list term without its disambiguator
      authority/<class>/...   generated per registered figure, per class

    REPORT-ONLY ARMS: duplicate sentences and opener diversity (section 24 says
    these report at Stage 3 so remediation is one edit pass, not a round), the
    per-topic acronym rule, and every arm a named suppression downgrades.

    PS 5.1. ASCII only in this file.
    Exit 0 clean, 1 a blocking finding, 2 a usage error or an empty check-set,
    4 the self-test failed.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $BuildDir,
    [string] $SpineDir,
    #  The figure registry. Authority classes and every allow-list live here.
    [string] $RulesPath,
    #  assets\rto-profile.<rto>.json. Optional: the contract carries the locked
    #  terminology as well, and a build whose RTO has no profile pack yet is
    #  still checked against the contract. Which sources were read is printed.
    [string] $ProfilePath,
    [string] $SkillDir,
    #  The complete finding list, blocking and reported, as JSON. A finding
    #  cannot be closed against the 25 lines that fitted on the console.
    [string] $ReportPath,
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

$GATE = 'Assert-Terminology'

# ---------------------------------------------------------------------------
# THE ONE SHARED OBLIGATION LIST
# ---------------------------------------------------------------------------

#  Every rule in this file that needs a word of obligation composes this list.
#  It is deliberately wider than a verb list: the sentence that defeated the
#  narrow version of this rule said "approach", and a nominalised obligation
#  ("our standard is", "the house rule is") carries exactly the same claim as
#  the verb. Widen HERE and every rule widens.
$script:OBLIGATION = @(
    'require', 'requires', 'required', 'requirement', 'requirements',
    'mandate', 'mandates', 'mandated', 'mandatory',
    'set', 'sets', 'setting',
    'specify', 'specifies', 'specified', 'specification',
    'state', 'states', 'stated',
    'stipulate', 'stipulates', 'prescribe', 'prescribes',
    'demand', 'demands', 'oblige', 'obliges', 'obligation',
    'impose', 'imposes', 'dictate', 'dictates', 'insist', 'insists',
    'say', 'says', 'call for', 'calls for', 'allow', 'allows', 'permit', 'permits',
    'approach', 'approaches', 'standard', 'standards', 'rule', 'rules',
    'limit', 'limits', 'policy', 'procedure', 'law', 'legal', 'legally'
)

#  Ownership of a requirement, expressed without naming anybody. The venue's
#  own name is added to this at run time from the contract, never typed.
$script:OWNER_WORD = @('our', 'we', 'us', 'the venue', 'the house', 'in-house', 'house', 'this kitchen', 'the kitchen')

#  Speaking as the law. Instrument names are added at run time from the
#  registry's own legislation-class entries, never typed.
$script:LEGAL_WORD = @('the law', 'legally', 'by law', 'a legal requirement', 'legal requirement',
                       'legislation', 'legislated', 'the act', 'the regulations', 'the code',
                       'statutory', 'the regulator', 'the standard')

# ---------------------------------------------------------------------------
# Findings
# ---------------------------------------------------------------------------

$script:Findings = New-Object System.Collections.Generic.List[object]
$script:RuleBook = New-Object System.Collections.Generic.List[object]
$script:Suppressed = @{}
$script:SuppressWhy = @{}

function Add-TrmRule {
    <# Declare a rule so the report carries every rule that RAN, not only the
       rules that fired. A rule nobody can see is a rule nobody can audit. #>
    param(
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][string] $Level,
        [Parameter(Mandatory)][string] $Reason
    )
    $script:RuleBook.Add([pscustomobject]@{ Rule = $Name; Level = $Level; Reason = $Reason })
}

function Add-TrmFinding {
    param(
        [Parameter(Mandatory)][string] $Rule,
        [Parameter(Mandatory)][string] $Level,
        [Parameter(Mandatory)][string] $Detail,
        $Cell,
        [string] $Extra = ''
    )
    $f = [pscustomobject]@{
        Rule    = $Rule
        Level   = $Level
        File    = ''
        Path    = ''
        Channel = ''
        Slot    = ''
        Surface = ''
        Text    = ''
        Detail  = $Detail
        Extra   = $Extra
    }
    if ($null -ne $Cell) {
        $f.File = [string]$Cell.File
        $f.Path = [string]$Cell.Path
        $f.Channel = [string]$Cell.Channel
        $f.Slot = [string]$Cell.Slot
        if (@($Cell.PSObject.Properties.Name) -contains 'Surface') { $f.Surface = [string]$Cell.Surface }
        $f.Text = [string]$Cell.Text
    }
    $script:Findings.Add($f)
}

function Add-TrmSuppression {
    <# A named tuning rule, with its reason, and its count printed at the end.
       Never an allow-list of values. #>
    param(
        [Parameter(Mandatory)][string] $Rule,
        [Parameter(Mandatory)][string] $Reason
    )
    if (-not $script:Suppressed.ContainsKey($Rule)) { $script:Suppressed[$Rule] = 0 }
    $script:Suppressed[$Rule] = $script:Suppressed[$Rule] + 1
    $script:SuppressWhy[$Rule] = $Reason
}

# ---------------------------------------------------------------------------
# Text helpers - anchored, always
# ---------------------------------------------------------------------------

function Get-TrmWordRx {
    <#  A word-boundary regex over an escaped literal.

        AN UNANCHORED SUBSTRING MATCH IS NOT A CHECK. "grilling" sits inside
        "chargrilling", "g" sits inside every word, and a sweep that finds
        either has found nothing. \b on a term that starts or ends with a
        non-word character never matches, so the boundary is asserted only on
        the sides that carry a word character.  #>
    param([Parameter(Mandatory)][string] $Term)
    $core = [regex]::Escape($Term.Trim())
    $lead = ''
    $tail = ''
    if ($Term.Trim() -match '^\w') { $lead = '(?<![\w-])' }
    if ($Term.Trim() -match '\w$') { $tail = '(?![\w-])' }
    return ($lead + $core + $tail)
}

#  Compiled once and kept. .NET caches only the last fifteen static-method
#  patterns, and this gate runs a few hundred patterns over a few thousand
#  strings; without the cache every call recompiles and the gate takes minutes.
$script:RxCache = @{}

function Get-TrmRx {
    param([Parameter(Mandatory)][string] $Pattern, [switch] $CaseSensitive)
    $key = 'i|' + $Pattern
    $opt = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Compiled
    if ($CaseSensitive) {
        $key = 'c|' + $Pattern
        $opt = [System.Text.RegularExpressions.RegexOptions]::Compiled
    }
    if (-not $script:RxCache.ContainsKey($key)) {
        $script:RxCache[$key] = New-Object System.Text.RegularExpressions.Regex($Pattern, $opt)
    }
    return $script:RxCache[$key]
}

function Test-TrmContains {
    <#  -CaseSensitive is not decoration. The contract locks the recipe unit as
        an initial-capped form and forbids the lower-case one; the two differ by
        CASE ALONE, so a case-insensitive sweep fires on every correct use. The
        caller decides, and the decision is derived: see Get-TrmLockedTerms.  #>
    param([string] $Text, [string] $Term, [switch] $CaseSensitive)
    if (-not $Text -or -not $Term) { return $false }
    #  Cheap ordinal pre-filter. The regex cannot match unless the literal is
    #  present, and skipping the regex on the strings that cannot match is the
    #  difference between this gate running in seconds and running in minutes.
    $cmp = [System.StringComparison]::OrdinalIgnoreCase
    if ($CaseSensitive) { $cmp = [System.StringComparison]::Ordinal }
    if ($Text.IndexOf($Term.Trim(), $cmp) -lt 0) { return $false }
    return (Get-TrmRx -Pattern (Get-TrmWordRx -Term $Term) -CaseSensitive:$CaseSensitive).IsMatch($Text)
}

function Split-TrmSentence {
    <# Sentences, for a rule that must judge a claim rather than a document. #>
    param([string] $Text)
    if (-not $Text) { return @() }
    $t = ($Text -replace '\s+', ' ').Trim()
    $parts = [regex]::Split($t, '(?<=[\.\!\?;])\s+(?=[A-Z0-9"''(])')
    return @($parts | Where-Object { "$_".Trim().Length -gt 0 })
}

function Get-TrmSentenceWith {
    <# The sentence(s) of a cell that carry a term. #>
    param([string] $Text, [string] $Term)
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($s in (Split-TrmSentence -Text $Text)) {
        if (Test-TrmContains -Text $s -Term $Term) { $out.Add($s) }
    }
    if ($out.Count -eq 0 -and (Test-TrmContains -Text $Text -Term $Term)) { $out.Add($Text) }
    return $out.ToArray()
}

function Get-TrmRegisterRx {
    <#  A register is generated, never typed: every owner word (or the venue's
        own name) within a short reach of any word from the ONE shared
        obligation list, plus the possessive form that carries the claim with
        no verb at all. #>
    param(
        [Parameter(Mandatory)][string[]] $Subject,
        [Parameter(Mandatory)][string[]] $Obligation
    )
    $subj = ($Subject | ForEach-Object { [regex]::Escape($_) }) -join '|'
    $obl = ($Obligation | ForEach-Object { [regex]::Escape($_) }) -join '|'
    return @(
        ('(?i)(?<![\w-])(' + $subj + ')(?![\w-])[^.;]{0,40}?(?<![\w-])(' + $obl + ')(?![\w-])'),
        ('(?i)(?<![\w-])(' + $subj + ')(?![\w-])''?s?\s+(' + $obl + ')(?![\w-])')
    )
}

# ---------------------------------------------------------------------------
# Reading order over the spine
# ---------------------------------------------------------------------------

function Get-TrmOrderedCells {
    <#  Every authored string of the spine, in READING ORDER, split by surface.

        File order comes from the contract's own topic and PC sequence, matched
        to files by what the FILE SAYS it is (its ref / pc / number), never by
        a filename pattern - nothing about a path is assumed here. Within a
        file the walk follows JSON property declaration order, which is the
        order the renderer emits.

        Surface: the slides channel is the deck and everything else is the
        guide. They are two documents and therefore two reading orders; an
        acronym expanded in the guide has not been expanded on the deck.  #>
    param(
        [Parameter(Mandatory)][string] $Build,
        [string] $Spine,
        $Contract
    )

    $files = Get-GateSpineFiles -BuildDir $Build -SpineDir $Spine -Exclude @('cover.json', 'deckframe.json')
    $recs = New-Object System.Collections.Generic.List[object]
    foreach ($f in $files) {
        $j = Get-GateJson -Path $f.FullName
        if ($null -eq $j) { continue }
        $props = @($j.PSObject.Properties.Name)
        $ref = ''
        $topicNo = -1
        $kind = 'other'
        if ($props -contains 'ref' -or $props -contains 'pc') {
            $ref = [string](Get-GateProp -Object $j -Names @('ref', 'pc'))
            $kind = 'sub'
            if ($props -contains 'topic') { $topicNo = [int](Get-GateProp -Object $j -Names @('topic') -Default -1) }
        }
        elseif ($props -contains 'number' -and ($props -contains 'outcomes' -or $props -contains 'keyTerms')) {
            $topicNo = [int](Get-GateProp -Object $j -Names @('number') -Default -1)
            $kind = 'topic'
        }
        elseif ($props -contains 'unitOverview' -or $props -contains 'assessmentOverview') {
            $kind = 'front'
        }
        $recs.Add([pscustomobject]@{ Name = $f.Name; Json = $j; Ref = $ref; Topic = $topicNo; Kind = $kind; Rank = 999999 })
    }

    $rank = 0
    foreach ($r in $recs) { if ($r.Kind -eq 'front') { $r.Rank = $rank; $rank++ } }
    if ($null -ne $Contract) {
        foreach ($t in @(Get-GateProp -Object $Contract -Names @('topics') -Default @())) {
            if ($null -eq $t) { continue }
            $n = [int](Get-GateProp -Object $t -Names @('n', 'number') -Default -1)
            foreach ($r in $recs) { if ($r.Kind -eq 'topic' -and $r.Topic -eq $n) { $r.Rank = $rank; $rank++ } }
            foreach ($pc in @(Get-GateProp -Object $t -Names @('pcs') -Default @())) {
                foreach ($r in $recs) { if ($r.Kind -eq 'sub' -and $r.Ref -eq [string]$pc) { $r.Rank = $rank; $rank++ } }
            }
        }
    }
    #  Anything the contract does not place still gets read, after what it does,
    #  in name order. A file dropped out of the reading order silently is how a
    #  whole sub-section escapes a sweep.
    $stray = @($recs | Where-Object { $_.Rank -eq 999999 } | Sort-Object Name)
    foreach ($r in $stray) { $r.Rank = $rank; $rank++ }

    $skip = @{}
    foreach ($k in (Get-GateUnrenderedFields -BuildDir $Build -ForSweep).Keys) { $skip[$k] = $true }

    $cells = New-Object System.Collections.Generic.List[object]
    $idx = 0
    foreach ($r in ($recs | Sort-Object Rank)) {
        foreach ($c in (Get-GateSpineCells -Node $r.Json -File $r.Name -Path '' -Channel '' -Slot '' -Skip $skip)) {
            $surface = 'guide'
            if ([string]$c.Channel -eq 'slides') { $surface = 'deck' }
            $cells.Add([pscustomobject]@{
                File = $c.File; Path = $c.Path; Channel = $c.Channel; Slot = $c.Slot
                Text = $c.Text; Surface = $surface; Order = $idx
                Ref = $r.Ref; Topic = $r.Topic; Kind = $r.Kind
            })
            $idx++
        }
    }
    return [pscustomobject]@{
        Cells = $cells.ToArray()
        Files = @($recs | Sort-Object Rank)
        Skipped = $skip
    }
}

# ---------------------------------------------------------------------------
# Derive the check-sets
# ---------------------------------------------------------------------------

function Get-TrmLockedTerms {
    <#  Locked canonical terms, their forbidden near-synonyms and the paired
        forms, DERIVED from the contract's terminology block and from the RTO
        profile pack's lockedTerminology. Both are read; neither is retyped.

        The contract states a locked term as prose - "chill (bring cooked food
        down through the danger zone); never 'cool down' or 'refrigerate' as a
        synonym" - so the canonical form is the head of that prose and the
        forbidden set is what follows the word "never". That is parsing the
        source of truth, which is what rule 1 asks for; a second hand-typed
        list beside it is what rule 1 forbids.  #>
    param($Contract, $RtoProfile)

    $canon = @{}
    $forbid = @{}
    $sources = New-Object System.Collections.Generic.List[string]

    if ($null -ne $Contract) {
        $term = Get-GateProp -Object $Contract -Names @('terminology')
        if ($null -ne $term) {
            $sources.Add('contract.json terminology')
            foreach ($p in $term.PSObject.Properties) {
                if ($p.Name -like '_*') { continue }
                $v = [string]$p.Value
                if (-not $v.Trim()) { continue }
                #  The canonical form is the head of the value, up to the first
                #  bracketed gloss or the first dash that introduces the note.
                $head = ($v -split '\s+\(' )[0]
                $head = ($head -split '\s+-\s+')[0]
                $head = ($head -split ';')[0]
                $head = $head.Trim().Trim(',').Trim()
                if ($head -and $head.Length -le 60) { $canon["$head"] = $p.Name }
                foreach ($m in [regex]::Matches($v, "(?i)never\s+([^.;]+)")) {
                    $tail = $m.Groups[1].Value
                    $tail = $tail -replace "(?i)\s+as\s+a\s+synonym.*$", ''
                    foreach ($piece in ($tail -split "\s*,\s*|\s+or\s+")) {
                        $w = "$piece".Trim().Trim("'").Trim('"').Trim()
                        if ($w.Length -ge 2 -and $w.Length -le 40) {
                            if (-not $forbid.ContainsKey($w)) { $forbid[$w] = "$($p.Name) - the contract locks '$head'" }
                        }
                    }
                }
            }
        }
    }

    if ($null -ne $RtoProfile) {
        $lt = Get-GateProp -Object $RtoProfile -Names @('lockedTerminology')
        if ($null -ne $lt) {
            $sources.Add('rto profile lockedTerminology')
            $cn = Get-GateProp -Object $lt -Names @('canonical')
            if ($null -ne $cn) {
                foreach ($p in $cn.PSObject.Properties) {
                    if ($p.Name -like '_*') { continue }
                    $canon["$($p.Name)"] = $p.Name
                    foreach ($s in @($p.Value)) {
                        $w = "$s".Trim()
                        if ($w -and -not $forbid.ContainsKey($w)) { $forbid[$w] = "the profile locks '$($p.Name)'" }
                    }
                }
            }
        }
    }

    #  CASE-DISTINGUISHED SYNONYMS, DERIVED. Where a forbidden form differs
    #  from a canonical form BY CASE ALONE - the contract locks an initial-
    #  capped recipe unit and forbids the lower-case one - a case-insensitive
    #  sweep fires on every correct use. On the reference build that single
    #  fault produced 283 of 383 blocking findings, all of them on correct
    #  content. The decision is derived from the two strings, never declared.
    $caseSensitive = @{}
    foreach ($bad in @($forbid.Keys)) {
        foreach ($canonical in $canon.Keys) {
            #  -eq IS CASE-INSENSITIVE IN POWERSHELL, and case is the whole
            #  question here. An -eq reads the two forms as the same string,
            #  decides there is nothing to distinguish, and the sweep then
            #  reports every correct use of the canonical form - 283 of 383
            #  blocking findings on the first honest run of this gate.
            if ([string]::Equals("$canonical", "$bad", [System.StringComparison]::Ordinal)) { continue }
            if ([string]::Equals("$canonical", "$bad", [System.StringComparison]::OrdinalIgnoreCase)) {
                $caseSensitive["$bad"] = "$canonical"
            }
        }
    }

    return [pscustomobject]@{ Canonical = $canon; Forbidden = $forbid; CaseSensitive = $caseSensitive; Sources = $sources.ToArray() }
}

function Get-TrmAcronyms {
    <#  Every acronym with its expansion, derived from three sources that
        already exist: the contract's terminology values, the spine's own key
        terms, and the profile's paired forms. Pattern: an expansion followed
        by its short form in brackets, which is how all three write it.  #>
    param($Contract, $RtoProfile, $Cells)

    $out = @{}
    $rx = '(?<long>[A-Za-z][A-Za-z''\- ]{3,60}?)\s*\((?<short>[A-Z][A-Za-z0-9]{1,7})\)'

    if ($null -ne $Contract) {
        $term = Get-GateProp -Object $Contract -Names @('terminology')
        if ($null -ne $term) {
            foreach ($p in $term.PSObject.Properties) {
                if ($p.Name -like '_*') { continue }
                foreach ($m in [regex]::Matches([string]$p.Value, $rx)) {
                    $s = $m.Groups['short'].Value
                    if (-not $out.ContainsKey($s)) { $out[$s] = $m.Groups['long'].Value.Trim() }
                }
            }
        }
    }
    foreach ($c in $Cells) {
        if ([string]$c.Channel -ne 'keyTerms') { continue }
        foreach ($m in [regex]::Matches([string]$c.Text, $rx)) {
            $s = $m.Groups['short'].Value
            if (-not $out.ContainsKey($s)) { $out[$s] = $m.Groups['long'].Value.Trim() }
        }
    }
    if ($null -ne $RtoProfile) {
        $lt = Get-GateProp -Object $RtoProfile -Names @('lockedTerminology')
        if ($null -ne $lt) {
            foreach ($pair in @(Get-GateProp -Object $lt -Names @('pairedForms') -Default @())) {
                $a = @($pair)
                if ($a.Count -ge 2) {
                    $s = "$($a[1])".Trim()
                    if ($s -and -not $out.ContainsKey($s)) { $out[$s] = "$($a[0])".Trim() }
                }
            }
        }
    }
    return $out
}

function Get-TrmAuthorityRules {
    <#  ONE RULE PER REGISTERED FIGURE, GENERATED FROM ITS CLASS.

        The registry states a class per figure and the class legend in its own
        _comment. What a class MEANS is a policy - "legislation" bans venue
        ownership language, "the venue's own procedure" bans legal language -
        and that policy is declared once, here, keyed on the class letter. The
        RULES are then generated: every figure, every required value it
        carries, gets the rules its class implies. A figure added to the
        registry tomorrow arrives with its rules and nothing here changes.

        A COMPOSITE CLASS REPORTS AND DOES NOT BLOCK. "V vs L", "L, adopted by
        V" and "L and V" are the registry saying this figure legitimately has
        two authorities, and the correct teaching sentence names both - which
        is precisely the sentence a single-class rule would fire on. Section 26
        records a forbid rule that fired five times on the correct comparative
        sentence, and a rule that fires on correct content trains the reader to
        ignore the gate.  #>
    param($Registry, [string] $VenueName)

    $rules = New-Object System.Collections.Generic.List[object]
    if ($null -eq $Registry) { return $rules }

    $ownerWords = @($script:OWNER_WORD)
    if ($VenueName) { $ownerWords += $VenueName }
    $legalWords = @($script:LEGAL_WORD)

    #  Instrument names the registry itself carries become legal-register
    #  subjects, so "Standard 3.2.2 requires" counts as speaking as the law
    #  without any instrument being typed into this file.
    foreach ($f in @(Get-GateProp -Object $Registry -Names @('figures') -Default @())) {
        if ($null -eq $f) { continue }
        $cls = [string](Get-GateProp -Object $f -Names @('authority', 'class') -Default '')
        if ($cls -notmatch '(?i)^\s*L\b') { continue }
        foreach ($r in @(Get-GateProp -Object $f -Names @('require') -Default @())) {
            $v = "$r".Trim()
            if ($v -match '^(Standard|Clause|Part|Schedule)\s' -and $v.Length -le 30) { $legalWords += $v }
        }
    }
    $legalWords = @($legalWords | Sort-Object -Unique)

    $ownerRegister = @(Get-TrmRegisterRx -Subject $ownerWords -Obligation $script:OBLIGATION)
    $legalRegister = @(Get-TrmRegisterRx -Subject $legalWords -Obligation $script:OBLIGATION)

    $policy = @{
        'L' = [pscustomobject]@{
            Meaning = 'named legislation or a standard'
            BanName = 'venue-ownership'
            BanRx   = $ownerRegister
            OwnRx   = $legalRegister
            Level   = 'BLOCK'
            Why     = 'a legislated figure described as the venue''s own house standard - the inversion section 24 records on four consecutive slides'
        }
        'V' = [pscustomobject]@{
            Meaning = 'the venue''s own documented procedure'
            BanName = 'legal-requirement'
            BanRx   = $legalRegister
            OwnRx   = $ownerRegister
            Level   = 'BLOCK'
            Why     = 'a house standard described as a legal requirement - the same inversion, the other way round'
        }
        'P' = [pscustomobject]@{
            Meaning = 'the assessment pack'
            BanName = 'venue-ownership-or-legal'
            BanRx   = ($ownerRegister + $legalRegister)
            OwnRx   = @()
            Level   = 'REPORT'
            Why     = 'a pack figure is neither the law nor the venue''s own invention, but a venue that adopts the pack''s figure into its own procedure says so legitimately, so this reports'
        }
        'U' = [pscustomobject]@{
            Meaning = 'the unit of competency'
            BanName = 'venue-ownership-or-legal'
            BanRx   = ($ownerRegister + $legalRegister)
            OwnRx   = @()
            Level   = 'REPORT'
            Why     = 'a unit requirement stated as house or legal is wrong but is routinely also both, so this reports with its anchor'
        }
    }

    foreach ($f in @(Get-GateProp -Object $Registry -Names @('figures') -Default @())) {
        if ($null -eq $f) { continue }
        $name = [string](Get-GateProp -Object $f -Names @('name') -Default '')
        $cls = [string](Get-GateProp -Object $f -Names @('authority', 'class') -Default '')
        $letters = @([regex]::Matches($cls, '(?<![A-Za-z])[PULV](?![A-Za-z])') | ForEach-Object { $_.Value } | Sort-Object -Unique)
        $vals = @(@(Get-GateProp -Object $f -Names @('require') -Default @()) | Where-Object { "$_".Trim() })
        if ($vals.Count -eq 0) { continue }
        if ($letters.Count -eq 0) { continue }

        $composite = ($letters.Count -gt 1)
        $letter = $letters[0]
        if (-not $policy.ContainsKey($letter)) { continue }
        $pol = $policy[$letter]

        $lvl = $pol.Level
        $note = ''
        if ($composite) {
            $lvl = 'REPORT'
            $note = 'composite class "' + $cls + '" - two authorities are legitimate in one sentence'
        }

        $rules.Add([pscustomobject]@{
            Name      = ('authority/' + $letter + '/' + $pol.BanName)
            Figure    = $name
            Class     = $cls
            Letters   = $letters
            Composite = $composite
            Values    = $vals
            BanRx     = @($pol.BanRx)
            OwnRegisterRx = @($pol.OwnRx)
            Level     = $lvl
            Meaning   = $pol.Meaning
            Why       = $pol.Why
            Note      = $note
        })
    }
    return $rules
}

# ---------------------------------------------------------------------------
# The scan
# ---------------------------------------------------------------------------

function Invoke-TrmScan {
    <#  Every arm, over one spine. Factored so the self-test can run the whole
        gate against a planted copy rather than against a re-implementation of
        it - a self-test that exercises different code proves nothing about the
        code that ships.  #>
    param(
        [Parameter(Mandatory)][string] $Build,
        [string] $Spine,
        $Contract,
        $Registry,
        $RtoProfile,
        [switch] $Announce
    )

    $script:Findings = New-Object System.Collections.Generic.List[object]
    $script:RuleBook = New-Object System.Collections.Generic.List[object]
    $script:Suppressed = @{}
    $script:SuppressWhy = @{}

    $ord = Get-TrmOrderedCells -Build $Build -Spine $Spine -Contract $Contract
    $cells = $ord.Cells

    $venue = ''
    if ($null -ne $Contract) {
        $venue = [string](Get-GateProp -Object $Contract.build -Names @('tradingName', 'brand') -Default '')
    }

    $locked = Get-TrmLockedTerms -Contract $Contract -RtoProfile $RtoProfile
    $acros = Get-TrmAcronyms -Contract $Contract -RtoProfile $RtoProfile -Cells $cells
    $authRules = Get-TrmAuthorityRules -Registry $Registry -VenueName $venue

    #  Glossary canon: the spine's own key terms plus every locked canonical
    #  form. The variants are GENERATED mechanically from the canonical form -
    #  hyphen to space, hyphen removed - so a term restated off-canon is caught
    #  without anybody listing the wrong spellings.
    $glossary = @{}
    foreach ($c in $cells) {
        if ([string]$c.Channel -ne 'keyTerms') { continue }
        if ([string]$c.Path -notmatch '\.term$') { continue }
        $t = "$($c.Text)".Trim()
        if ($t) { $glossary[$t] = 'spine keyTerms' }
    }
    foreach ($k in $locked.Canonical.Keys) { if (-not $glossary.ContainsKey($k)) { $glossary[$k] = 'locked terminology' } }

    $variantMap = New-Object System.Collections.Generic.List[object]
    foreach ($g in $glossary.Keys) {
        $canonical = "$g".Trim()
        if ($canonical -notmatch '-') { continue }
        if ($canonical.Length -lt 5) { continue }
        $vSpace = $canonical -replace '-', ' '
        $vNone = $canonical -replace '-', ''
        foreach ($v in @($vSpace, $vNone)) {
            if ($v -eq $canonical) { continue }
            $variantMap.Add([pscustomobject]@{ Canonical = $canonical; Variant = $v; From = $glossary[$g] })
        }
    }

    #  The ambiguity list: terms the sources apply to two subjects, declared in
    #  the contract's own reference convention. Its disambiguators are the
    #  qualified forms the convention states.
    $ambig = New-Object System.Collections.Generic.List[object]
    if ($null -ne $Contract) {
        $rc = Get-GateProp -Object $Contract -Names @('referenceConvention')
        if ($null -ne $rc) {
            $quals = New-Object System.Collections.Generic.List[string]
            $bare = ''
            foreach ($p in $rc.PSObject.Properties) {
                if ($p.Name -like '_*') { continue }
                $v = "$($p.Value)".Trim()
                $m = [regex]::Match($v, '^(?<qual>[A-Z][A-Za-z ]{2,30}?)\s+(?<bare>[A-Z][A-Za-z]{2,20})\s*\{n\}')
                if ($m.Success) {
                    $quals.Add($m.Groups['qual'].Value.Trim())
                    $bare = $m.Groups['bare'].Value.Trim()
                }
            }
            #  The pack documents the convention maps each qualified form onto.
            #  A bare term standing beside the document that resolves it is
            #  already disambiguated, and the document names come from the
            #  contract's own "means" mapping - never typed here.
            $docNames = New-Object System.Collections.Generic.List[string]
            foreach ($p in $rc.PSObject.Properties) {
                if ($p.Name -like '_*') { continue }
                foreach ($dm in [regex]::Matches("$($p.Value)", '(?<![\w.])([A-Za-z0-9_]{4,60}\.docx)')) {
                    $docNames.Add($dm.Groups[1].Value)
                    #  The extra parentheses are load-bearing: inside a method
                    #  call a bare comma separates ARGUMENTS, so an unwrapped
                    #  -replace with two operands becomes a two-argument Add.
                    $stem = (($dm.Groups[1].Value -replace '\.docx$', '') -replace '_', ' ')
                    $docNames.Add($stem)
                }
            }
            if ($bare -and $quals.Count -ge 2) {
                $ambig.Add([pscustomobject]@{
                    Bare = $bare
                    Qualifiers = @($quals.ToArray() | Sort-Object -Unique)
                    Documents = @($docNames.ToArray() | Sort-Object -Unique)
                    Field = 'referenceConvention'
                })
            }
        }
    }

    #  The question map, for the chip cap and the pairing counts.
    $qmap = @{}
    $qmapMax = 0
    if ($null -ne $Contract) {
        $qm = Get-GateProp -Object $Contract -Names @('questionMap')
        if ($null -ne $qm) {
            foreach ($p in $qm.PSObject.Properties) {
                if ($p.Name -like '_*') { continue }
                $list = @(@($p.Value) | Where-Object { "$_".Trim() })
                $qmap[$p.Name] = $list
                if ($list.Count -gt $qmapMax) { $qmapMax = $list.Count }
            }
        }
    }
    $chipCap = $qmapMax
    $chipCapFrom = 'the widest sub-section in the contract question map'
    if ($null -ne $RtoProfile) {
        $ch = Get-GateProp -Object $RtoProfile -Names @('chip')
        $declared = Get-GateProp -Object $ch -Names @('maxRefs', 'maxItems')
        if ($declared) { $chipCap = [int]$declared; $chipCapFrom = 'the RTO profile chip cap' }
    }

    if ($Announce -and -not $Quiet) {
        Write-Host ''
        Write-Host 'TERMINOLOGY - one word per concept, in reading order, with the registry''s authority' -ForegroundColor Cyan
        Write-Host ("  spine: {0} file(s), {1} authored string(s), read in the contract's own topic and PC order" -f @($ord.Files).Count, $cells.Count) -ForegroundColor DarkGray
        Write-Host ("  surfaces: guide {0} string(s), deck {1} string(s) - two reading orders, checked separately" -f @($cells | Where-Object { $_.Surface -eq 'guide' }).Count, @($cells | Where-Object { $_.Surface -eq 'deck' }).Count) -ForegroundColor DarkGray
        Write-Host ("  fields passed over as structural or build metadata: {0}" -f (($ord.Skipped.Keys | Sort-Object) -join ', ')) -ForegroundColor DarkGray
        Write-GateCheckSet -What 'locked canonical terms' -Count $locked.Canonical.Count -DerivedFrom (($locked.Sources -join ' + '))
        Write-GateCheckSet -What 'forbidden near-synonyms' -Count $locked.Forbidden.Count -DerivedFrom 'the same locked-terminology sources, parsed for what they say must never stand in'
        Write-GateCheckSet -What 'acronym / expansion pairs' -Count $acros.Count -DerivedFrom 'contract terminology, the spine key terms and the profile paired forms'
        Write-GateCheckSet -What 'glossary canonical forms' -Count $glossary.Count -DerivedFrom 'the spine key terms plus the locked terminology'
        Write-GateCheckSet -What 'generated off-canon variants' -Count $variantMap.Count -DerivedFrom 'each canonical form, hyphen to space and hyphen removed'
        Write-GateCheckSet -What 'authority-class rules' -Count $authRules.Count -DerivedFrom 'the figure registry, one rule generated per figure from its own class'
        Write-GateCheckSet -What 'ambiguity-list terms' -Count $ambig.Count -DerivedFrom 'the contract reference convention'
        Write-GateCheckSet -What 'obligation words shared by every rule' -Count $script:OBLIGATION.Count -DerivedFrom 'the one shared list at the top of this script'
        Write-Host ("  chip cap: {0} reference(s), from {1}" -f $chipCap, $chipCapFrom) -ForegroundColor DarkGray
        if ($authRules.Count -gt 0) {
            $byLetter = @{}
            foreach ($r in $authRules) {
                $k = ($r.Letters -join '')
                if (-not $byLetter.ContainsKey($k)) { $byLetter[$k] = 0 }
                $byLetter[$k] = $byLetter[$k] + 1
            }
            foreach ($k in ($byLetter.Keys | Sort-Object)) {
                Write-Host ("    class {0}: {1} figure(s)" -f $k, $byLetter[$k]) -ForegroundColor DarkGray
            }
        }
    }

    # -- declare every rule that runs ---------------------------------------
    Add-TrmRule -Name 'locked-synonym' -Level 'BLOCK' -Reason 'a forbidden near-synonym of a locked term, matched on word boundaries'
    Add-TrmRule -Name 'glossary-variant' -Level 'BLOCK' -Reason 'a glossary or locked term restated off its canonical form'
    Add-TrmRule -Name 'acronym-order' -Level 'BLOCK' -Reason 'an acronym used before its expansion in the surface''s own reading order'
    Add-TrmRule -Name 'acronym-order-topic' -Level 'REPORT' -Reason 'the contract asks for expansion at first use IN EACH TOPIC; the document-level order blocks, the per-topic rule reports'
    Add-TrmRule -Name 'structural-label' -Level 'BLOCK' -Reason 'a repeated structural label that is not the spine''s own modal label'
    Add-TrmRule -Name 'qa-pairing' -Level 'BLOCK' -Reason 'self-check questions and their answer pointers do not pair one to one'
    Add-TrmRule -Name 'truncation' -Level 'BLOCK' -Reason '"and N more", a trailing ellipsis or a cut chip - never authored on purpose'
    Add-TrmRule -Name 'chip-cap' -Level 'BLOCK' -Reason 'a chip naming more references than the derived cap allows'
    Add-TrmRule -Name 'build-vocabulary' -Level 'BLOCK' -Reason 'build words or a bare provenance class reaching the page'
    Add-TrmRule -Name 'ambiguity' -Level 'BLOCK' -Reason 'an ambiguity-list term used without the disambiguator the contract declares'
    Add-TrmRule -Name 'duplicate-sentence' -Level 'REPORT' -Reason 'section 24 reports duplicates at Stage 3 so remediation is one edit pass'
    Add-TrmRule -Name 'opener-diversity' -Level 'REPORT' -Reason 'section 24 reports opener repetition at Stage 3, for the same reason'
    foreach ($r in ($authRules | Sort-Object Name -Unique)) {
        Add-TrmRule -Name $r.Name -Level $r.Level -Reason ('class ' + ($r.Letters -join '') + ' = ' + $r.Meaning + '; banned register: ' + $r.Why)
    }

    # -- 1. locked near-synonyms --------------------------------------------
    foreach ($c in $cells) {
        $txt = [string]$c.Text
        foreach ($bad in $locked.Forbidden.Keys) {
            $cs = $locked.CaseSensitive.ContainsKey($bad)
            if ($cs) {
                if (-not (Test-TrmContains -Text $txt -Term $bad -CaseSensitive)) {
                    if (Test-TrmContains -Text $txt -Term $bad) {
                        Add-TrmSuppression -Rule 'locked-synonym/case-distinguished' -Reason 'the forbidden form differs from a canonical form by case alone, so it is matched case-sensitively; matched case-insensitively it fires on every correct use of the canonical form'
                    }
                    continue
                }
            }
            elseif (-not (Test-TrmContains -Text $txt -Term $bad)) { continue }
            #  A near-synonym that is only present because it sits INSIDE a
            #  canonical form is not a near-synonym. Named suppression.
            $inside = $false
            foreach ($canon in $locked.Canonical.Keys) {
                if ("$canon".Length -le "$bad".Length) { continue }
                if ((Test-TrmContains -Text $canon -Term $bad) -and (Test-TrmContains -Text $txt -Term $canon)) { $inside = $true; break }
            }
            if ($inside) {
                Add-TrmSuppression -Rule 'locked-synonym/inside-canonical' -Reason 'the forbidden phrase occurs only as part of the longer canonical term the same cell uses correctly'
                continue
            }
            Add-TrmFinding -Rule 'locked-synonym' -Level 'BLOCK' -Cell $c -Detail ("'{0}' stands in for a locked term: {1}" -f $bad, $locked.Forbidden[$bad])
        }
    }

    # -- 2. glossary canonical restatement ----------------------------------
    foreach ($c in $cells) {
        $txt = [string]$c.Text
        foreach ($v in $variantMap) {
            if (-not (Test-TrmContains -Text $txt -Term $v.Variant)) { continue }
            #  An elaboration marker is the section-24 escape: the cell is
            #  explaining the term rather than using it.
            if ($txt -match '(?i)\b(also called|also known as|sometimes written|spelt|spelled|which means)\b') {
                Add-TrmSuppression -Rule 'glossary-variant/elaboration-marker' -Reason 'the cell carries an explicit elaboration marker, which section 24 accepts in place of the canonical restatement'
                continue
            }
            Add-TrmFinding -Rule 'glossary-variant' -Level 'BLOCK' -Cell $c -Detail ("'{0}' is an off-canon form of the {1} term '{2}'" -f $v.Variant, $v.From, $v.Canonical)
        }
    }

    # -- 3. acronym first use, in reading order, per surface -----------------
    foreach ($surface in @('guide', 'deck')) {
        $sc = @($cells | Where-Object { $_.Surface -eq $surface })
        if ($sc.Count -eq 0) { continue }
        foreach ($short in ($acros.Keys | Sort-Object)) {
            $long = $acros[$short]
            $firstShort = $null
            $firstLong = $null
            foreach ($c in $sc) {
                $txt = [string]$c.Text
                if ($null -eq $firstLong -and (Test-TrmContains -Text $txt -Term $long)) { $firstLong = $c }
                if ($null -eq $firstShort -and (Test-TrmContains -Text $txt -Term $short)) { $firstShort = $c }
                if ($null -ne $firstShort -and $null -ne $firstLong) { break }
            }
            if ($null -eq $firstShort) { continue }
            if ($null -eq $firstLong) {
                Add-TrmFinding -Rule 'acronym-order' -Level 'BLOCK' -Cell $firstShort -Detail ("'{0}' is used on the {1} and its expansion '{2}' appears nowhere on that surface" -f $short, $surface, $long)
                continue
            }
            if ($firstLong.Order -gt $firstShort.Order) {
                Add-TrmFinding -Rule 'acronym-order' -Level 'BLOCK' -Cell $firstShort `
                    -Detail ("'{0}' is used on the {1} at reading position {2} but is not expanded until position {3}" -f $short, $surface, $firstShort.Order, $firstLong.Order) `
                    -Extra ("expansion first appears at [{0}] {1}" -f $firstLong.File, $firstLong.Path)
            }
        }
        #  Per topic, which is what the contract asks for. Reports.
        $topics = @($sc | ForEach-Object { $_.Topic } | Where-Object { $_ -ge 0 } | Sort-Object -Unique)
        foreach ($t in $topics) {
            $tc = @($sc | Where-Object { $_.Topic -eq $t })
            foreach ($short in ($acros.Keys | Sort-Object)) {
                $long = $acros[$short]
                $fs = $null
                $fl = $null
                foreach ($c in $tc) {
                    if ($null -eq $fl -and (Test-TrmContains -Text $c.Text -Term $long)) { $fl = $c }
                    if ($null -eq $fs -and (Test-TrmContains -Text $c.Text -Term $short)) { $fs = $c }
                    if ($null -ne $fs -and $null -ne $fl) { break }
                }
                if ($null -eq $fs) { continue }
                if ($null -eq $fl -or $fl.Order -gt $fs.Order) {
                    Add-TrmFinding -Rule 'acronym-order-topic' -Level 'REPORT' -Cell $fs -Detail ("'{0}' is used in topic {1} on the {2} before that topic expands it" -f $short, $t, $surface)
                }
            }
        }
    }

    # -- 4. structural label uniformity --------------------------------------
    #  The modal label is derived from the spine itself: whatever prefix the
    #  chips overwhelmingly carry IS this build's structural label, and one
    #  chip that carries a different one is the drift.
    #  The LABEL-BEARING strings only. An assessment link also carries its bare
    #  reference list, and a reference is not a label: matching the whole
    #  channel reported every reference in the build as a label that had lost
    #  its prefix - 74 findings, none of them real.
    $chipCells = @($cells | Where-Object { [string]$_.Path -match '(\.chip|\.wording)$' })
    $prefixCount = @{}
    foreach ($c in $chipCells) {
        $m = [regex]::Match([string]$c.Text, '^(?<p>[^:]{3,40}):')
        if ($m.Success) {
            $p = $m.Groups['p'].Value.Trim()
            if (-not $prefixCount.ContainsKey($p)) { $prefixCount[$p] = 0 }
            $prefixCount[$p] = $prefixCount[$p] + 1
        }
    }
    $modalPrefix = ''
    $modalN = 0
    foreach ($k in $prefixCount.Keys) { if ($prefixCount[$k] -gt $modalN) { $modalN = $prefixCount[$k]; $modalPrefix = $k } }
    if ($modalPrefix -and $chipCells.Count -gt 0) {
        foreach ($c in $chipCells) {
            $m = [regex]::Match([string]$c.Text, '^(?<p>[^:]{3,40}):')
            $p = ''
            if ($m.Success) { $p = $m.Groups['p'].Value.Trim() }
            if ($p -ne $modalPrefix) {
                Add-TrmFinding -Rule 'structural-label' -Level 'BLOCK' -Cell $c -Detail ("this assessment-link label reads '{0}' where the spine's own label, used {1} times, is '{2}'" -f $p, $modalN, $modalPrefix)
            }
        }
    }
    #  A slide kicker that names a sub-section other than the file's own.
    foreach ($c in $cells) {
        if ([string]$c.Path -notmatch '\.kicker$') { continue }
        if (-not $c.Ref) { continue }
        $m = [regex]::Match([string]$c.Text, '^\s*(?<r>\d+(?:\.\d+)+)\b')
        if ($m.Success -and $m.Groups['r'].Value -ne [string]$c.Ref) {
            Add-TrmFinding -Rule 'structural-label' -Level 'BLOCK' -Cell $c -Detail ("this kicker is labelled {0} inside the sub-section authored as {1}" -f $m.Groups['r'].Value, $c.Ref)
        }
    }

    # -- 5. question and answer pairing counts -------------------------------
    foreach ($f in $ord.Files) {
        $j = $f.Json
        $sc = Get-GateProp -Object $j -Names @('selfCheck')
        if ($null -eq $sc) { continue }
        $qs = @(@(Get-GateProp -Object $sc -Names @('questions') -Default @()) | Where-Object { "$_".Trim() })
        $ag = @(@(Get-GateProp -Object $sc -Names @('answerGuide', 'answers', 'answerPointers') -Default @()) | Where-Object { "$_".Trim() })
        if ($qs.Count -eq 0 -and $ag.Count -eq 0) { continue }
        if ($ag.Count -eq 0) {
            Add-TrmSuppression -Rule 'qa-pairing/no-answer-channel' -Reason 'this sub-section carries no answer channel at all, which is the deliberate withholding recorded in the unrendered-field contract, not a pairing defect'
            continue
        }
        if ($qs.Count -ne $ag.Count) {
            Add-TrmFinding -Rule 'qa-pairing' -Level 'BLOCK' -Cell ([pscustomobject]@{ File = $f.Name; Path = 'selfCheck'; Channel = 'selfCheck'; Slot = ''; Text = '' }) `
                -Detail ("{0} self-check question(s) against {1} answer pointer(s)" -f $qs.Count, $ag.Count)
        }
    }

    # -- 6. truncation and chip counts ---------------------------------------
    foreach ($c in $cells) {
        $txt = [string]$c.Text
        if ($txt -match '(?i)\band\s+\d+\s+more\b' -or $txt -match '\.\.\.\s*$' -or $txt -match ('[\u' + '2026]\s*$')) {
            Add-TrmFinding -Rule 'truncation' -Level 'BLOCK' -Cell $c -Detail 'a truncation pattern reached the page'
        }
    }
    #  THE REFERENCE PATTERN IS THE CONTRACT'S OWN. A pattern invented here
    #  counted the pack's document code as a reference and reported a correct
    #  chip as over the cap; the contract declares questionPattern precisely so
    #  every reader of a reference uses one pattern.
    $refPattern = ''
    if ($null -ne $Contract) {
        $rcp = Get-GateProp -Object $Contract -Names @('referenceConvention')
        $refPattern = [string](Get-GateProp -Object $rcp -Names @('questionPattern') -Default '')
    }
    foreach ($c in $chipCells) {
        $txt = [string]$c.Text
        if (-not $refPattern) { continue }
        $refs = @((Get-TrmRx -Pattern $refPattern).Matches($txt))
        if ($refs.Count -gt $chipCap -and $chipCap -gt 0) {
            Add-TrmFinding -Rule 'chip-cap' -Level 'BLOCK' -Cell $c -Detail ("this chip names {0} reference(s) against a cap of {1} ({2})" -f $refs.Count, $chipCap, $chipCapFrom)
        }
    }

    # -- 7. build vocabulary and bare provenance classes ---------------------
    $classLetters = @()
    if ($null -ne $Registry) {
        foreach ($f in @(Get-GateProp -Object $Registry -Names @('figures') -Default @())) {
            if ($null -eq $f) { continue }
            $cls = [string](Get-GateProp -Object $f -Names @('authority', 'class') -Default '')
            foreach ($m in [regex]::Matches($cls, '(?<![A-Za-z])[A-Z](?![A-Za-z])')) { $classLetters += $m.Value }
        }
    }
    $classLetters = @($classLetters | Sort-Object -Unique)
    $buildWords = @('TODO', 'TBD', 'FIXME', 'placeholder', 'lorem ipsum', 'spine', 'the registry',
                    'authority class', 'figure registry', 'openQuestions', 'provenance class')
    foreach ($c in $cells) {
        $txt = [string]$c.Text
        foreach ($w in $buildWords) {
            if (Test-TrmContains -Text $txt -Term $w) {
                Add-TrmFinding -Rule 'build-vocabulary' -Level 'BLOCK' -Cell $c -Detail ("build vocabulary '{0}' reached an authored string" -f $w)
            }
        }
        foreach ($L in $classLetters) {
            if ([regex]::IsMatch($txt, ('(?i)\b(class|authority)\s+' + [regex]::Escape($L) + '\b'))) {
                Add-TrmFinding -Rule 'build-vocabulary' -Level 'BLOCK' -Cell $c -Detail ("a bare provenance class token 'class {0}' reached an authored string" -f $L)
            }
        }
    }

    # -- 8. ambiguity-list disambiguators ------------------------------------
    foreach ($a in $ambig) {
        $qualRx = ($a.Qualifiers | ForEach-Object { [regex]::Escape($_) }) -join '|'
        $rx = '(?<!(' + $qualRx + ')\s)(?<![\w-])' + [regex]::Escape($a.Bare) + '(?![\w-])\s+(?<n>\d+)'
        $rxObj = Get-TrmRx -Pattern $rx
        foreach ($c in $cells) {
            $txt = [string]$c.Text
            if ($txt.IndexOf($a.Bare, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
            #  The cell that STATES the convention is its definition, not a use
            #  of it. It has to print the bare form to explain why the bare form
            #  is not used, and a rule that fires there fires on the sentence
            #  that fixes the defect.
            if ([string]$c.Path -match [regex]::Escape($a.Field)) {
                foreach ($m in $rxObj.Matches($txt)) {
                    Add-TrmSuppression -Rule 'ambiguity/convention-statement' -Reason 'this cell is the guide stating the reference convention itself, which must print the bare form in order to explain it'
                }
                continue
            }
            foreach ($m in $rxObj.Matches($txt)) {
                #  Already qualified in this same cell, with the same number.
                $n = $m.Groups['n'].Value
                $qualified = $false
                foreach ($q in $a.Qualifiers) {
                    if ($txt -match ('(?i)' + [regex]::Escape($q) + '\s+' + [regex]::Escape($a.Bare) + '\s*' + [regex]::Escape($n) + '(?![\d])')) { $qualified = $true; break }
                }
                if ($qualified) {
                    Add-TrmSuppression -Rule 'ambiguity/qualified-in-cell' -Reason 'the same cell already names this item in its qualified form with the same number, so the later bare reference is resolved for the reader who is reading it'
                    continue
                }
                $namedDoc = $false
                foreach ($d in $a.Documents) {
                    if ($d.Length -ge 6 -and $txt.IndexOf($d, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $namedDoc = $true; break }
                }
                if ($namedDoc) {
                    Add-TrmSuppression -Rule 'ambiguity/document-named' -Reason 'the cell names the pack document the contract maps this reference form onto, which is the disambiguation the convention exists to supply'
                    continue
                }
                Add-TrmFinding -Rule 'ambiguity' -Level 'BLOCK' -Cell $c `
                    -Detail ("'{0}' is used without its disambiguator; the contract's reference convention requires one of: {1}" -f $a.Bare, ($a.Qualifiers -join ', ')) `
                    -Extra $m.Value
            }
        }
    }

    # -- 9. authority-class rules, generated from the class ------------------
    #  THE CONTRAST SENTENCE IS THE CORRECT SENTENCE, AND IT IS WHY THIS ARM
    #  DOES NOT BLOCK ON EVERY SENTENCE THAT MENTIONS THE OTHER REGISTER. The
    #  inversion this gate exists for states ONE authority, wrongly: "our house
    #  standard requires 21 degrees C within 2 hours". A sentence that names
    #  both - "21 degrees C within 2 hours is the Code's figure, which the
    #  venue adopts, so it is not a house rule" - is the sentence that TEACHES
    #  the distinction, and every one of the six such sentences on the
    #  reference build was correct. So a sentence carrying the figure's OWN
    #  register as well as the banned one reports with its anchor for a reader,
    #  and only the single-register claim blocks.
    $contrastRx = '(?i)\b(stricter|tighter|not a (house|legal)|rather than|whereas|while the|is the [A-Za-z'' ]{0,20}(code|standard|act)''?s|adopts|adopted|unchanged|as well as|both)\b'
    foreach ($r in $authRules) {
        $ownRx = @()
        if ($r.Name -match '/L/') { $ownRx = @($r.OwnRegisterRx) }
        elseif ($r.Name -match '/V/') { $ownRx = @($r.OwnRegisterRx) }
        foreach ($v in $r.Values) {
            foreach ($c in $cells) {
                $txt = [string]$c.Text
                if (-not (Test-TrmContains -Text $txt -Term $v)) { continue }
                foreach ($sent in (Get-TrmSentenceWith -Text $txt -Term $v)) {
                    foreach ($rx in $r.BanRx) {
                        $m = (Get-TrmRx -Pattern $rx).Match($sent)
                        if (-not $m.Success) { continue }
                        $lvl = $r.Level
                        if ($r.Composite) {
                            Add-TrmSuppression -Rule 'authority/composite-class' -Reason 'the registry classes this figure to more than one authority, so a sentence naming both registers is the correct teaching sentence and blocking on it would fire on correct content'
                            $lvl = 'REPORT'
                        }
                        elseif ($lvl -eq 'BLOCK') {
                            $namesOwn = $false
                            foreach ($orx in $ownRx) {
                                if ((Get-TrmRx -Pattern $orx).IsMatch($sent)) { $namesOwn = $true; break }
                            }
                            if (-not $namesOwn -and (Get-TrmRx -Pattern $contrastRx).IsMatch($sent)) { $namesOwn = $true }
                            if ($namesOwn) {
                                Add-TrmSuppression -Rule 'authority/contrast-sentence' -Reason 'the sentence names the figure''s own authority as well as the banned register, which is the comparative teaching sentence; the inversion this arm blocks on states one authority and states it wrongly'
                                $lvl = 'REPORT'
                            }
                        }
                        Add-TrmFinding -Rule $r.Name -Level $lvl -Cell $c `
                            -Detail ("figure '{0}' is registered class {1} ({2}) and this sentence describes it in {3} language" -f $r.Figure, $r.Class, $r.Meaning, ($r.Name -split '/')[2]) `
                            -Extra ("value: " + $v + " | matched: " + $m.Value + " | sentence: " + $sent)
                        break
                    }
                }
            }
        }
    }

    # -- 10. report-only counters --------------------------------------------
    #  WITHIN a surface. The guide and the deck are built from one spine and
    #  are REQUIRED to say the same thing - deck parity is its own gate - so a
    #  sentence appearing once in each is the design, not a duplicate. Counting
    #  across surfaces reported the parity the build is graded on as a defect.
    $seen = @{}
    foreach ($c in $cells) {
        foreach ($s in (Split-TrmSentence -Text ([string]$c.Text))) {
            $n = (ConvertTo-GateNormal -Text $s)
            if (-not $n -or $n.Length -lt 40) { continue }
            $key = [string]$c.Surface + '|' + $n
            if ($seen.ContainsKey($key)) {
                Add-TrmFinding -Rule 'duplicate-sentence' -Level 'REPORT' -Cell $c -Detail ("this sentence already appears on the same surface at [{0}] {1}" -f $seen[$key].File, $seen[$key].Path) -Extra $s
            }
            else {
                if ($seen.ContainsKey('guide|' + $n) -or $seen.ContainsKey('deck|' + $n)) {
                    Add-TrmSuppression -Rule 'duplicate-sentence/cross-surface' -Reason 'the guide and the deck are rendered from one spine and are required to agree, so the same sentence on both surfaces is parity rather than duplication'
                }
                $seen[$key] = $c
            }
        }
    }
    $openers = @{}
    foreach ($c in $cells) {
        $txt = ([string]$c.Text).Trim()
        if ($txt.Length -lt 40) { continue }
        $w = @($txt -split '\s+')
        if ($w.Count -lt 3) { continue }
        $key = (($w[0..2] -join ' ')).ToLowerInvariant()
        if (-not $openers.ContainsKey($key)) { $openers[$key] = New-Object System.Collections.Generic.List[object] }
        $openers[$key].Add($c)
    }
    foreach ($k in $openers.Keys) {
        $grp = $openers[$k]
        if ($grp.Count -lt 4) { continue }
        Add-TrmFinding -Rule 'opener-diversity' -Level 'REPORT' -Cell $grp[0] -Detail ("{0} authored strings open with '{1}'" -f $grp.Count, $k)
    }

    return [pscustomobject]@{
        Findings   = $script:Findings.ToArray()
        Rules      = $script:RuleBook.ToArray()
        Suppressed = $script:Suppressed
        SuppressWhy = $script:SuppressWhy
        Cells      = $cells
        CheckSets  = [pscustomobject]@{
            lockedCanonical = $locked.Canonical.Count
            forbiddenSynonyms = $locked.Forbidden.Count
            acronyms = $acros.Count
            glossary = $glossary.Count
            variants = $variantMap.Count
            authorityRules = $authRules.Count
            ambiguityTerms = $ambig.Count
            obligationWords = $script:OBLIGATION.Count
            chipCap = $chipCap
            cells = $cells.Count
        }
    }
}

# ---------------------------------------------------------------------------
# Inputs
# ---------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $BuildDir)) { throw "$GATE`: no build directory at $BuildDir" }
$buildResolved = (Resolve-Path -LiteralPath $BuildDir).Path
$spineResolved = $SpineDir
if (-not $spineResolved) { $spineResolved = Join-Path $buildResolved 'spine' }

$contractJson = Get-GateContract -BuildDir $buildResolved
$registryJson = Get-GateRegistry -BuildDir $buildResolved -RulesPath $RulesPath

$profileJson = $null
$profileFrom = 'none - the contract carried the locked terminology alone'
$profileCandidate = $ProfilePath
if (-not $profileCandidate -and $null -ne $contractJson) {
    $rto = [string](Get-GateProp -Object $contractJson.build -Names @('rto', 'brand') -Default '')
    if ($rto) {
        $try = Join-Path $SkillDir ("assets\rto-profile.{0}.json" -f $rto.ToLowerInvariant())
        if (Test-Path -LiteralPath $try) { $profileCandidate = $try }
    }
}
if ($profileCandidate -and (Test-Path -LiteralPath $profileCandidate)) {
    $profileJson = Get-GateJson -Path $profileCandidate
    $profileFrom = (Split-Path $profileCandidate -Leaf)
}

if ($null -eq $contractJson -and $null -eq $profileJson) {
    Write-Host ("  X {0}: neither a build contract nor an RTO profile is readable, so there is no locked terminology to check against. A terminology gate with an empty check-set passes by having nothing to check." -f $GATE) -ForegroundColor Red
    exit 2
}

# ---------------------------------------------------------------------------
# Self-test - plant, VERIFY THE PLANT LANDED, then run the shipping gate
# ---------------------------------------------------------------------------

$selfTestFailed = 0

if ($SelfTest) {
    Write-Host ''
    Write-Host ("  {0} SELF-TEST - a clean result is not believed until the gate has failed on a planted defect" -f $GATE) -ForegroundColor Cyan

    $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("trm-selftest-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null
    try {
        Copy-Item -LiteralPath (Join-Path $buildResolved 'contract.json') -Destination $tmpRoot -ErrorAction SilentlyContinue
        Copy-Item -LiteralPath (Join-Path $buildResolved 'figures.json') -Destination $tmpRoot -ErrorAction SilentlyContinue
        $tmpSpine = Join-Path $tmpRoot 'spine'
        New-Item -ItemType Directory -Force -Path $tmpSpine | Out-Null
        #  -LiteralPath does NOT expand a wildcard, so a copy written that way
        #  moves nothing, the fixture spine is empty and the plant lands
        #  nowhere. Enumerate and copy each file.
        foreach ($sf in (Get-ChildItem -LiteralPath $spineResolved -Filter '*.json' -File)) {
            Copy-Item -LiteralPath $sf.FullName -Destination (Join-Path $tmpSpine $sf.Name) -Force
        }

        function Test-TrmPlant {
            <# Read the file BACK and confirm the defect is present in the exact
               channel the gate scans. A plant that silently failed to apply
               once made a gate on this project look proven when it was not. #>
            param([string] $File, [string] $Needle, [string] $What)
            $txt = Get-GateFileText -Path $File
            if ($txt.IndexOf($Needle, [System.StringComparison]::Ordinal) -ge 0) {
                Write-Host ("    plant landed: {0}" -f $What) -ForegroundColor DarkGray
                return $true
            }
            Write-Host ("    X plant did NOT land: {0} - this proves nothing" -f $What) -ForegroundColor Red
            return $false
        }

        function Set-TrmPlant {
            <# Insert a string into an authored array field of a spine file, by
               rewriting the JSON, so the plant is in a channel the walker
               reads rather than beside it. #>
            param([string] $File, [string] $Field, [string] $Value)
            $j = Get-GateJson -Path $File
            $cur = @(Get-GateProp -Object $j -Names @($Field) -Default @())
            $new = New-Object System.Collections.Generic.List[object]
            foreach ($x in $cur) { $new.Add($x) }
            $new.Add($Value)
            if (@($j.PSObject.Properties.Name) -contains $Field) { $j.$Field = $new.ToArray() }
            else { $j | Add-Member -NotePropertyName $Field -NotePropertyValue $new.ToArray() }
            $out = $j | ConvertTo-Json -Depth 40
            [System.IO.File]::WriteAllText($File, $out, (New-Object System.Text.UTF8Encoding($true)))
        }

        $subFiles = @(Get-ChildItem -LiteralPath $tmpSpine -Filter '*.json' -File |
                      Where-Object { $_.Name -ne 'front.json' -and $_.Name -ne 'cover.json' -and $_.Name -ne 'deckframe.json' } |
                      Sort-Object Name)
        $victim = $subFiles[0].FullName
        $plants = New-Object System.Collections.Generic.List[object]

        #  1. a forbidden near-synonym, taken from the contract's own locked list
        $lockedForPlant = Get-TrmLockedTerms -Contract $contractJson -RtoProfile $profileJson
        $synonym = ''
        foreach ($k in ($lockedForPlant.Forbidden.Keys | Sort-Object)) { if ("$k".Length -ge 4) { $synonym = "$k"; break } }
        if ($synonym) {
            $sent = "A planted sentence that uses " + $synonym + " where the locked term belongs."
            Set-TrmPlant -File $victim -Field 'underpinningKnowledge' -Value $sent
            $plants.Add([pscustomobject]@{ Rule = 'locked-synonym'; Needle = $sent; What = ("forbidden near-synonym '" + $synonym + "'"); Ok = (Test-TrmPlant -File $victim -Needle $sent -What ("forbidden near-synonym '" + $synonym + "'")) })
        }

        #  2. an acronym used before its expansion in reading order
        $acroForPlant = Get-TrmAcronyms -Contract $contractJson -RtoProfile $profileJson -Cells @()
        $short = ''
        foreach ($k in ($acroForPlant.Keys | Sort-Object)) { $short = "$k"; break }
        if ($short) {
            $frontPath = Join-Path $tmpSpine 'front.json'
            if (Test-Path -LiteralPath $frontPath) {
                $fj = Get-GateJson -Path $frontPath
                $planted = "The planted opening paragraph uses " + $short + " long before anything expands it."
                if (@($fj.PSObject.Properties.Name) -contains 'introduction') {
                    $cur = @($fj.introduction)
                    $lst = New-Object System.Collections.Generic.List[object]
                    $lst.Add($planted)
                    foreach ($x in $cur) { $lst.Add($x) }
                    $fj.introduction = $lst.ToArray()
                }
                else { $fj | Add-Member -NotePropertyName 'introduction' -NotePropertyValue @($planted) }
                [System.IO.File]::WriteAllText($frontPath, ($fj | ConvertTo-Json -Depth 40), (New-Object System.Text.UTF8Encoding($true)))
                $plants.Add([pscustomobject]@{ Rule = 'acronym-order'; Needle = $planted; What = ("acronym '" + $short + "' used before its expansion"); Ok = (Test-TrmPlant -File $frontPath -Needle $planted -What ("acronym '" + $short + "' used at the front of the reading order")) })
            }
        }

        #  3. a class L figure written in venue-ownership language
        $venuePlant = ''
        if ($null -ne $contractJson) { $venuePlant = [string](Get-GateProp -Object $contractJson.build -Names @('tradingName', 'brand') -Default '') }
        $lFigureValue = ''
        foreach ($f in @(Get-GateProp -Object $registryJson -Names @('figures') -Default @())) {
            if ($null -eq $f) { continue }
            $cls = [string](Get-GateProp -Object $f -Names @('authority', 'class') -Default '')
            $letters = @([regex]::Matches($cls, '(?<![A-Za-z])[PULV](?![A-Za-z])') | ForEach-Object { $_.Value } | Sort-Object -Unique)
            if ($letters.Count -ne 1 -or $letters[0] -ne 'L') { continue }
            foreach ($rq in @(Get-GateProp -Object $f -Names @('require') -Default @())) {
                if ("$rq".Trim()) { $lFigureValue = "$rq".Trim(); break }
            }
            if ($lFigureValue) { break }
        }
        if ($lFigureValue) {
            $own = 'Our house standard requires ' + $lFigureValue + ' on this run.'
            Set-TrmPlant -File $victim -Field 'underpinningKnowledge' -Value $own
            $plants.Add([pscustomobject]@{ Rule = 'authority/L/venue-ownership'; Needle = $own; What = ("a class L figure (" + $lFigureValue + ") in venue-ownership language"); Ok = (Test-TrmPlant -File $victim -Needle $own -What ("class L figure '" + $lFigureValue + "' written as the venue's own standard")) })
        }

        #  4. THE CORRECT CASE, which must NOT fire. A gate that fires on
        #     correct content is a gate that gets switched off.
        $cleanSentence = ''
        if ($lFigureValue) {
            $cleanSentence = 'The Food Standards Code sets ' + $lFigureValue + ', and this kitchen works to it.'
            Set-TrmPlant -File $victim -Field 'underpinningKnowledge' -Value $cleanSentence
            [void](Test-TrmPlant -File $victim -Needle $cleanSentence -What 'the CORRECT statement of the same class L figure, which must not fire')
        }

        $bad = @($plants | Where-Object { -not $_.Ok })
        if ($bad.Count -gt 0) {
            Write-Host ("    X {0} plant(s) did not land. The self-test is void." -f $bad.Count) -ForegroundColor Red
            $selfTestFailed++
        }
        else {
            $probe = Invoke-TrmScan -Build $tmpRoot -Spine $tmpSpine -Contract $contractJson -Registry $registryJson -RtoProfile $profileJson
            foreach ($p in $plants) {
                #  The finding must be ON THE PLANTED STRING and it must BLOCK.
                #  A rule that already fires elsewhere in the build would
                #  otherwise satisfy this assertion without ever having seen
                #  the plant, which is a self-test that proves nothing.
                $hit = @($probe.Findings | Where-Object {
                    $_.Rule -eq $p.Rule -and $_.Level -eq 'BLOCK' -and
                    (([string]$_.Text).IndexOf($p.Needle, [System.StringComparison]::Ordinal) -ge 0 -or
                     ([string]$_.Extra).IndexOf($p.Needle, [System.StringComparison]::Ordinal) -ge 0)
                })
                if ($hit.Count -gt 0) {
                    Write-Host ("    self-test: {0} -> {1} fired as BLOCKING on the planted string ({2} finding(s)). This arm can fail." -f $p.What, $p.Rule, $hit.Count) -ForegroundColor Green
                }
                else {
                    Write-Host ("    X self-test: {0} planted and {1} did NOT fire as blocking on the planted string." -f $p.What, $p.Rule) -ForegroundColor Red
                    $selfTestFailed++
                }
            }
            if ($cleanSentence) {
                $falsePos = @($probe.Findings | Where-Object { $_.Level -eq 'BLOCK' -and [string]$_.Extra -match [regex]::Escape($cleanSentence) })
                if ($falsePos.Count -eq 0) {
                    Write-Host '    self-test: the correct statement of the same figure did NOT fire. The gate distinguishes them.' -ForegroundColor Green
                }
                else {
                    Write-Host '    X self-test: the CORRECT statement fired as a blocking defect. A gate that fires on correct content gets switched off.' -ForegroundColor Red
                    $selfTestFailed++
                }
            }
        }
    }
    finally {
        if ($tmpRoot -and (Test-Path -LiteralPath $tmpRoot)) { Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# ---------------------------------------------------------------------------
# The real run
# ---------------------------------------------------------------------------

if (-not $Quiet) {
    Write-Host ''
    Write-Host ("  locked terminology sources: {0}" -f $profileFrom) -ForegroundColor $(if ($profileJson) { 'DarkGray' } else { 'Yellow' })
}

$result = Invoke-TrmScan -Build $buildResolved -Spine $spineResolved -Contract $contractJson -Registry $registryJson -RtoProfile $profileJson -Announce

$blocking = @($result.Findings | Where-Object { $_.Level -eq 'BLOCK' })
$reported = @($result.Findings | Where-Object { $_.Level -ne 'BLOCK' })

if ($result.CheckSets.lockedCanonical -eq 0 -and $result.CheckSets.authorityRules -eq 0 -and $result.CheckSets.acronyms -eq 0) {
    Write-Host ("  X {0}: every derived check-set is empty. This gate would pass by having nothing to check." -f $GATE) -ForegroundColor Red
    exit 2
}

$reportOut = $ReportPath
if (-not $reportOut) { $reportOut = Join-Path $buildResolved 'terminology-report.json' }

$exitCode = 0
if ($selfTestFailed -gt 0) { $exitCode = 4 }
elseif ($blocking.Count -gt 0) { $exitCode = 1 }

$suppressRows = New-Object System.Collections.Generic.List[object]
foreach ($k in ($result.Suppressed.Keys | Sort-Object)) {
    $suppressRows.Add([pscustomobject]@{ Rule = $k; Count = $result.Suppressed[$k]; Reason = $result.SuppressWhy[$k] })
}

$payload = [pscustomobject]@{
    gate          = $GATE
    generatedUtc  = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    buildDir      = $buildResolved
    spineDir      = $spineResolved
    spineFingerprint = (Get-SpineFingerprint -BuildDir $buildResolved -SpineDir $spineResolved)
    terminologySources = $profileFrom
    checkSets     = $result.CheckSets
    rules         = $result.Rules
    suppressions  = $suppressRows.ToArray()
    blockingCount = $blocking.Count
    reportCount   = $reported.Count
    blocking      = $blocking
    report        = $reported
    exitCode      = $exitCode
}
[System.IO.File]::WriteAllText($reportOut, ($payload | ConvertTo-Json -Depth 12), (New-Object System.Text.UTF8Encoding($true)))

Write-Host ''
if ($suppressRows.Count -gt 0) {
    Write-Host '  named suppression rules that ran (never an allow-list of values):' -ForegroundColor DarkGray
    foreach ($s in $suppressRows) {
        Write-Host ("    {0} x{1}: {2}" -f $s.Rule, $s.Count, $s.Reason) -ForegroundColor DarkGray
    }
}
else { Write-Host '  no named suppression rule fired on this run' -ForegroundColor DarkGray }

if ($reported.Count -gt 0) {
    $byRule = @{}
    foreach ($f in $reported) {
        if (-not $byRule.ContainsKey($f.Rule)) { $byRule[$f.Rule] = 0 }
        $byRule[$f.Rule] = $byRule[$f.Rule] + 1
    }
    Write-Host ''
    Write-Host ("  REPORT ONLY - {0} finding(s), none of which changes the exit code:" -f $reported.Count) -ForegroundColor Yellow
    foreach ($k in ($byRule.Keys | Sort-Object)) { Write-Host ("    {0}: {1}" -f $k, $byRule[$k]) -ForegroundColor Yellow }
    $shown = 0
    foreach ($f in $reported) {
        $shown++
        if ($shown -gt 15) { break }
        Write-Host ("      [{0}] {1} - {2}" -f $f.File, $f.Path, $f.Detail) -ForegroundColor DarkGray
    }
    if ($reported.Count -gt 15) { Write-Host ("      ... and {0} more, all of them in {1}" -f ($reported.Count - 15), $reportOut) -ForegroundColor DarkGray }
}

Write-Host ''
Write-Host ("  complete finding list written to {0}" -f $reportOut) -ForegroundColor DarkGray

if ($selfTestFailed -gt 0) {
    Write-Host ("  X {0}: the self-test failed, so no result from this run may be believed." -f $GATE) -ForegroundColor Red
    exit 4
}

if ($blocking.Count -eq 0) {
    Write-Host ("  every locked term, acronym, structural label and registered figure is stated consistently ({0} report-level finding(s) recorded)" -f $reported.Count) -ForegroundColor Green
    exit 0
}

Write-Host ("  X {0} blocking terminology finding(s)" -f $blocking.Count) -ForegroundColor Red
$shown = 0
foreach ($f in $blocking) {
    $shown++
    if ($shown -gt 40) { break }
    Write-Host ("    [{0}] {1}{2}  (channel: {3})" -f $f.File, $f.Path, $(if ($f.Slot) { " slot $($f.Slot)" } else { '' }), $f.Channel) -ForegroundColor Yellow
    Write-Host ("      {0}: {1}" -f $f.Rule, $f.Detail) -ForegroundColor Red
    if ($f.Extra) { Write-Host ("      {0}" -f $f.Extra) -ForegroundColor DarkGray }
}
if ($blocking.Count -gt 40) { Write-Host ("    ... and {0} more in {1}" -f ($blocking.Count - 40), $reportOut) -ForegroundColor DarkGray }
Write-Host ''
Write-Host '  Fix on the spine, then re-run. A deliberate repetition is cleared in the registry beside the' -ForegroundColor Yellow
Write-Host '  rule it weakens, with a written reason - never by narrowing a rule in this file.' -ForegroundColor Yellow
exit 1
