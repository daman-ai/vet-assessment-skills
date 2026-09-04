<#
    Assert-CitationConsistency.ps1 - does the spine contradict ITSELF about
    what an instrument says, which clause says it, and what qualifies it?

    Implements the gate references\gates.md section 26 specifies. Runs at Stage
    3c as a member of the spine gate band (section 12). Re-runs unchanged
    before every Stage 7 re-render.

    IT NEEDS NO COPY OF THE LEGISLATION, WHICH IS WHY IT CAN RUN THIS EARLY.
    Every arm here compares the spine against itself: two statements of one
    duty, two statements of one instrument's scope, two statements of one
    adoption relationship, and a registry proviso present in one place and
    absent in another. Nothing is checked against an external source, and
    nothing here decides whether a citation is CORRECT - only whether the
    delivery set says it twice, differently. Deciding which of the two is right
    belongs to Stage 6, and this gate hands that reader both anchors.

    BLOCKING IS EXACT AND THE NARROWNESS IS THE DESIGN. Similarity clustering
    over duty phrases is precisely where a citation gate cries wolf, so only
    exact contradiction blocks:

      duty-two-clauses     one normalised duty phrase cited to two different
                           clause or instrument references
      scope-two-ways       one instrument's scope or applicability asserted and
                           denied, or given two different role labels
      adoption-inconsistent  an adoption relationship stated in both directions
                           or both polarities
      proviso-absent       a registry proviso missing from an occurrence of the
                           figure it attaches to

    The fuzzy half REPORTS, with every location named, so the fix is
    enumerated rather than sampled (section 32). It blocks nothing. That is
    rule 4, and it is what keeps the whole set credible: a gate that blocks on
    a guess is a gate that gets switched off.

    APPENDICES AND BODY PROSE ARE ONE NAMESPACE. A contradiction is a
    contradiction wherever it sits, so the front matter is swept with the
    topics and the deck is swept with the guide. Section 26 records an inverted
    scope statement that survived ALL THREE audit rounds because each round
    fixed the instance it was shown, and round 2 recorded it as "so the
    delivery set says it both ways" - which is a description of exactly the
    comparison this gate makes.

    NOTHING HERE IS A LITERAL FROM ONE BUILD. Instruments, clause numbers,
    duty phrases, adoption pairs and provisos are all extracted from the spine
    and the figure registry at run time. There is no instrument name, unit
    code, RTO code, CRICOS code, provider number or hex in this file.

    PS 5.1. ASCII only in this file.
    Exit 0 clean, 1 a blocking contradiction, 2 a usage error or an empty
    check-set, 4 the self-test failed.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $BuildDir,
    [string] $SpineDir,
    #  The figure registry. Provisos and every allow-list live here.
    [string] $RulesPath,
    [string] $ReportPath,
    #  The fuzzy REPORT arm's clustering threshold, over duty content words.
    #  It changes nothing that blocks; it changes how many pairs a reader is
    #  handed. Printed on every run so the number a report was produced at is
    #  never in doubt.
    [double] $ClusterSimilarity = 0.6,
    [switch] $SelfTest,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

$GATE = 'Assert-CitationConsistency'

# ---------------------------------------------------------------------------
# THE ONE SHARED OBLIGATION LIST
# ---------------------------------------------------------------------------

#  Every arm that has to find where a duty starts composes this list. Section
#  24's failure was a rule watching requires / mandates / sets while the
#  defective sentence said "approach": widening HERE widens every arm at once,
#  and there is deliberately no second list anywhere in this file.
$script:OBLIGATION = @(
    'requires', 'require', 'required', 'mandates', 'mandate', 'mandated',
    'sets', 'set', 'specifies', 'specify', 'specified', 'states', 'state',
    'stipulates', 'stipulate', 'prescribes', 'prescribe', 'demands', 'demand',
    'obliges', 'oblige', 'imposes', 'impose', 'dictates', 'dictate',
    'says', 'say', 'calls for', 'call for', 'allows', 'allow', 'permits', 'permit',
    'covers', 'cover', 'applies to', 'apply to', 'deals with', 'governs', 'govern',
    'is', 'are'
)

#  Words that carry no duty. Removed before two duty phrases are compared, so
#  "food to be cooled" and "the food be cooled" are one duty rather than two.
$script:STOPWORD = @(
    'a', 'an', 'the', 'of', 'to', 'in', 'on', 'at', 'by', 'for', 'from', 'with',
    'that', 'this', 'these', 'those', 'is', 'are', 'be', 'been', 'being', 'was',
    'were', 'it', 'its', 'as', 'and', 'or', 'but', 'so', 'then', 'than', 'which',
    'when', 'where', 'must', 'shall', 'will', 'can', 'may', 'any', 'all', 'each',
    'every', 'you', 'your', 'we', 'our', 'they', 'their'
)

# ---------------------------------------------------------------------------
# Findings
# ---------------------------------------------------------------------------

$script:Findings = New-Object System.Collections.Generic.List[object]
$script:RuleBook = New-Object System.Collections.Generic.List[object]
$script:Suppressed = @{}
$script:SuppressWhy = @{}

function Add-CitRule {
    param([Parameter(Mandatory)][string] $Name, [Parameter(Mandatory)][string] $Level, [Parameter(Mandatory)][string] $Reason)
    $script:RuleBook.Add([pscustomobject]@{ Rule = $Name; Level = $Level; Reason = $Reason })
}

function Add-CitFinding {
    param(
        [Parameter(Mandatory)][string] $Rule,
        [Parameter(Mandatory)][string] $Level,
        [Parameter(Mandatory)][string] $Detail,
        $Anchors,
        [string] $Extra = ''
    )
    #  @() OVER A List[object] THROWS "Argument types do not match", so the
    #  anchors are enumerated rather than coerced. Every grouping in this file
    #  is a generic list, and the coercion that looks harmless is the one that
    #  takes a gate down mid-run.
    $items = $Anchors
    if ($null -ne $Anchors -and $Anchors -is [System.Collections.Generic.List[object]]) { $items = $Anchors.ToArray() }
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($a in $items) {
        if ($null -eq $a) { continue }
        $rows.Add([pscustomobject]@{
            File = [string]$a.File; Path = [string]$a.Path; Channel = [string]$a.Channel
            Slot = [string]$a.Slot; Surface = [string]$a.Surface; Sentence = [string]$a.Sentence
        })
    }
    $script:Findings.Add([pscustomobject]@{
        Rule = $Rule; Level = $Level; Detail = $Detail; Extra = $Extra
        Locations = $rows.ToArray(); LocationCount = $rows.Count
    })
}

function Add-CitSuppression {
    param([Parameter(Mandatory)][string] $Rule, [Parameter(Mandatory)][string] $Reason)
    if (-not $script:Suppressed.ContainsKey($Rule)) { $script:Suppressed[$Rule] = 0 }
    $script:Suppressed[$Rule] = $script:Suppressed[$Rule] + 1
    $script:SuppressWhy[$Rule] = $Reason
}

# ---------------------------------------------------------------------------
# Text
# ---------------------------------------------------------------------------

$script:RxCache = @{}

function Get-CitRx {
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

function Get-CitWordRx {
    <#  Word-boundary regex over an escaped literal. An unanchored substring
        match is not a check: "grilling" sits inside "chargrilling", and a
        clause number sits inside a longer one.  #>
    param([Parameter(Mandatory)][string] $Term)
    $t = $Term.Trim()
    $core = [regex]::Escape($t)
    $lead = ''
    $tail = ''
    if ($t -match '^\w') { $lead = '(?<![\w-])' }
    if ($t -match '\w$') { $tail = '(?![\w-])' }
    return ($lead + $core + $tail)
}

function Test-CitContains {
    param([string] $Text, [string] $Term)
    if (-not $Text -or -not $Term) { return $false }
    if ($Text.IndexOf($Term.Trim(), [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false }
    return (Get-CitRx -Pattern (Get-CitWordRx -Term $Term)).IsMatch($Text)
}

function Split-CitSentence {
    param([string] $Text)
    if (-not $Text) { return @() }
    $t = ($Text -replace '\s+', ' ').Trim()
    return @([regex]::Split($t, '(?<=[\.\!\?;])\s+(?=[A-Z0-9"''(])') | Where-Object { "$_".Trim().Length -gt 0 })
}

function Get-CitContentWords {
    <# A duty reduced to the words that carry it, in order. #>
    param([string] $Text)
    $n = ConvertTo-GateNormal -Text $Text
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($w in ($n -split ' ')) {
        if (-not $w) { continue }
        if ($script:STOPWORD -contains $w) { continue }
        $out.Add($w)
    }
    return $out.ToArray()
}

# ---------------------------------------------------------------------------
# What a citation looks like - extracted, never typed
# ---------------------------------------------------------------------------

#  These are SHAPES, not names. No instrument in any jurisdiction is written
#  into this file: the patterns describe how a legislative reference is
#  written, and every actual instrument comes off the spine.
$script:INSTRUMENT_RX = @(
    '(?<i>Standard\s+\d+(?:\.\d+){1,3}[A-Z]?)',
    '(?<i>(?:[A-Z][A-Za-z]+|and|of|for)(?:\s+(?:[A-Z][A-Za-z]+|and|of|for)){0,6}\s+Act\s+\d{4}(?:\s*\([A-Za-z]{2,4}\))?)',
    '(?<i>(?:[A-Z][A-Za-z]+|and|of|for)(?:\s+(?:[A-Z][A-Za-z]+|and|of|for)){0,6}\s+Regulations?\s+\d{4}(?:\s*\([A-Za-z]{2,4}\))?)',
    '(?<i>(?:[A-Z][A-Za-z]+|and|of|for)(?:\s+(?:[A-Z][A-Za-z]+|and|of|for)){0,6}\s+Code)(?![\w-])'
)

function Get-CitNormInstrument {
    <#  ONE instrument, however the sentence introduces it.

        "The Food Standards Code", "Food Standards Code" and - where a sentence
        opens "No Food Standards Code clause sets ..." - "No Food Standards
        Code" are one instrument with a determiner in front of it. Left
        unnormalised they become three, every grouping in this gate fragments,
        and a real contradiction between two of them is invisible because they
        were never compared.  #>
    param([string] $Name)
    $n = ("$Name" -replace '\s+', ' ').Trim()
    $n = $n -replace '(?i)^(the|a|an|no|any|every|each|this|that)\s+', ''
    return $n.ToLowerInvariant()
}
#  A CLAUSE IS A DIVISION INSIDE AN INSTRUMENT, and the numbered Standard is
#  the INSTRUMENT, not a clause of one. Counting it as both put "clause 21"
#  and "Standard 3.2.2" in the same comparison and reported the abbreviated
#  citation of one duty as a contradiction of the fuller one.
$script:CLAUSE_RX = @(
    '(?<c>clause\s+\d+(?:\(\d+\))*(?:\([a-z]\))?)',
    '(?<c>section\s+\d+(?:\(\d+\))*)',
    '(?<c>Part\s+\d+(?:\.\d+)*)',
    '(?<c>Schedule\s+\d+)'
)

function Get-CitTokens {
    <# Every instrument and clause reference in one sentence, normalised. #>
    param([string] $Sentence)
    $inst = New-Object System.Collections.Generic.List[object]
    $seenNorm = @{}
    $clause = New-Object System.Collections.Generic.List[string]
    foreach ($rx in $script:INSTRUMENT_RX) {
        foreach ($m in (Get-CitRx -Pattern $rx -CaseSensitive).Matches($Sentence)) {
            $v = ($m.Groups['i'].Value -replace '\s+', ' ').Trim()
            if (-not $v) { continue }
            $norm = Get-CitNormInstrument -Name $v
            if (-not $norm) { continue }
            if ($seenNorm.ContainsKey($norm)) { continue }
            $seenNorm[$norm] = $true
            #  The RAW form is kept because the sentence has to be searched
            #  with the words it actually uses; the NORM form is what two
            #  sentences are compared on.
            $inst.Add([pscustomobject]@{ Raw = $v; Norm = $norm })
        }
    }
    foreach ($rx in $script:CLAUSE_RX) {
        foreach ($m in (Get-CitRx -Pattern $rx).Matches($Sentence)) {
            $v = ($m.Groups['c'].Value -replace '\s+', ' ').Trim().ToLowerInvariant()
            if ($v -and -not $clause.Contains($v)) { $clause.Add($v) }
        }
    }
    return [pscustomobject]@{ Instruments = $inst.ToArray(); Clauses = @($clause.ToArray() | Sort-Object) }
}

function Get-CitDutyKey {
    <#  The duty a sentence asserts, with every reference stripped out.

        The reference is removed first, deliberately: two sentences that state
        the same duty and cite different clauses must reduce to the SAME key,
        or the contradiction cannot be seen. Stop words go too, so a rewording
        of the articles is one duty rather than two. What survives is the
        obligation and its object, in order, and the comparison on it is EXACT.
        Paraphrase is the fuzzy arm's job and the fuzzy arm reports.  #>
    param([string] $Sentence)
    $s = $Sentence
    foreach ($rx in ($script:INSTRUMENT_RX + $script:CLAUSE_RX)) { $s = (Get-CitRx -Pattern $rx).Replace($s, ' ') }
    $s = $s -replace '\s+', ' '

    $oblRx = '(?<![\w-])(' + (($script:OBLIGATION | Where-Object { $_ -ne 'is' -and $_ -ne 'are' } | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')(?![\w-])'
    $m = (Get-CitRx -Pattern $oblRx).Match($s)
    if (-not $m.Success) { return '' }
    $tail = $s.Substring($m.Index + $m.Length)
    $words = Get-CitContentWords -Text $tail
    if ($words.Count -lt 4) { return '' }
    return ($words -join ' ')
}

# ---------------------------------------------------------------------------
# Reading the spine as sentences with anchors
# ---------------------------------------------------------------------------

function Get-CitSentences {
    <#  Every sentence of every authored string, with its anchor and surface.

        Front matter is included with the topics: section 26 says appendices
        and body prose are ONE namespace, and the inverted scope statement it
        records survived partly by sitting in an addendum nobody swept with
        the body.  #>
    param([Parameter(Mandatory)][string] $Build, [string] $Spine)

    $skip = @{}
    foreach ($k in (Get-GateUnrenderedFields -BuildDir $Build -ForSweep).Keys) { $skip[$k] = $true }

    $out = New-Object System.Collections.Generic.List[object]
    $files = Get-GateSpineFiles -BuildDir $Build -SpineDir $Spine -Exclude @('cover.json', 'deckframe.json')
    foreach ($f in $files) {
        $j = Get-GateJson -Path $f.FullName
        if ($null -eq $j) { continue }
        foreach ($c in (Get-GateSpineCells -Node $j -File $f.Name -Path '' -Channel '' -Slot '' -Skip $skip)) {
            $surface = 'guide'
            if ([string]$c.Channel -eq 'slides') { $surface = 'deck' }
            #  The occurrence UNIT for the proviso arm: a sub-section in the
            #  guide, one slide on the deck. A caveat that sits beside the
            #  figure in the same sub-section has qualified it for the reader
            #  of that page; a slide carries only what is on the slide.
            $unit = [string]$c.File
            $sm = [regex]::Match([string]$c.Path, '^slides\[(\d+)\]')
            if ($sm.Success) { $unit = [string]$c.File + '#slide' + $sm.Groups[1].Value }
            foreach ($s in (Split-CitSentence -Text ([string]$c.Text))) {
                $out.Add([pscustomobject]@{
                    File = $c.File; Path = $c.Path; Channel = $c.Channel; Slot = $c.Slot
                    Surface = $surface; Unit = $unit; Sentence = $s; CellText = [string]$c.Text
                })
            }
        }
    }
    return $out.ToArray()
}

# ---------------------------------------------------------------------------
# The scan
# ---------------------------------------------------------------------------

function Invoke-CitScan {
    param(
        [Parameter(Mandatory)][string] $Build,
        [string] $Spine,
        $Registry,
        [double] $Similarity = 0.6,
        [switch] $Announce
    )

    $script:Findings = New-Object System.Collections.Generic.List[object]
    $script:RuleBook = New-Object System.Collections.Generic.List[object]
    $script:Suppressed = @{}
    $script:SuppressWhy = @{}

    Add-CitRule -Name 'duty-two-clauses' -Level 'BLOCK' -Reason 'one normalised duty phrase cited to two different clause or instrument references'
    Add-CitRule -Name 'scope-two-ways' -Level 'BLOCK' -Reason 'one instrument''s scope asserted and denied, or given two different role labels'
    Add-CitRule -Name 'adoption-inconsistent' -Level 'BLOCK' -Reason 'one adoption relationship stated in both directions or both polarities'
    Add-CitRule -Name 'proviso-absent' -Level 'BLOCK' -Reason 'a registry proviso absent from an occurrence unit that states the figure it attaches to'
    Add-CitRule -Name 'duty-cluster' -Level 'REPORT' -Reason 'duty phrases that are similar but not identical and carry different references - the fuzzy half, which blocks nothing and names every location'
    Add-CitRule -Name 'proviso-thin' -Level 'REPORT' -Reason 'the figure and its proviso are in the same unit but not the same string, which a reader may still want to tighten'
    Add-CitRule -Name 'proviso-paraphrased' -Level 'REPORT' -Reason 'the caveat is in the unit in the author''s own words rather than the registry''s wording'

    $sentences = Get-CitSentences -Build $Build -Spine $Spine

    #  Only the sentences that actually carry a reference are candidates. The
    #  size of that set is printed, because a gate that sweeps four sentences
    #  and reports clean has told you nothing.
    $cited = New-Object System.Collections.Generic.List[object]
    foreach ($s in $sentences) {
        $tok = Get-CitTokens -Sentence $s.Sentence
        if ($tok.Instruments.Count -eq 0 -and $tok.Clauses.Count -eq 0) { continue }
        $cited.Add([pscustomobject]@{
            File = $s.File; Path = $s.Path; Channel = $s.Channel; Slot = $s.Slot
            Surface = $s.Surface; Unit = $s.Unit; Sentence = $s.Sentence
            Instruments = $tok.Instruments; Clauses = $tok.Clauses
            DutyKey = (Get-CitDutyKey -Sentence $s.Sentence)
        })
    }

    $instrumentsSeen = @{}
    foreach ($c in $cited) { foreach ($i in $c.Instruments) { $instrumentsSeen[$i.Norm] = $true } }

    if ($Announce -and -not $Quiet) {
        Write-Host ''
        Write-Host 'CITATION CONSISTENCY - the spine against itself, with no copy of the legislation' -ForegroundColor Cyan
        Write-GateCheckSet -What 'authored sentences' -Count $sentences.Count -DerivedFrom 'every string of every spine file, front matter and topics in one namespace'
        Write-GateCheckSet -What 'sentences carrying a reference' -Count $cited.Count -DerivedFrom 'the reference SHAPES declared in this script, matched against the spine - no instrument is named here'
        Write-GateCheckSet -What 'distinct instruments found on the spine' -Count $instrumentsSeen.Count -DerivedFrom 'the spine itself'
        foreach ($i in ($instrumentsSeen.Keys | Sort-Object)) { Write-Host ("    instrument: {0}" -f $i) -ForegroundColor DarkGray }
        Write-Host ("  fuzzy cluster similarity: {0} (report arm only - it changes nothing that blocks)" -f $Similarity) -ForegroundColor DarkGray
    }

    # -- 0. which instruments sit inside which, DERIVED FROM THE SPINE --------
    #  A guide that writes "Food Standards Code Standard 3.2.2" has told this
    #  gate that the numbered Standard is part of the Code. Without that
    #  relation, "the Code requires X" and "Standard 3.2.2 clause 22 requires
    #  X" read as two different citations of one duty, and the gate blocks on
    #  a guide introducing an instrument and then citing it precisely - which
    #  is correct writing. The relation is read off the spine's own adjacency,
    #  never declared here, so it holds for any jurisdiction's instruments.
    $compatible = @{}
    foreach ($c in $cited) {
        if ($c.Instruments.Count -lt 2) { continue }
        for ($a = 0; $a -lt $c.Instruments.Count; $a++) {
            for ($b = 0; $b -lt $c.Instruments.Count; $b++) {
                if ($a -eq $b) { continue }
                $x = $c.Instruments[$a]
                $y = $c.Instruments[$b]
                $adj = ('(?<![\w-])' + [regex]::Escape($x.Raw) + '(?:\s+(?:of|in|under|,)?\s*)' + [regex]::Escape($y.Raw) + '(?![\w-])')
                if ((Get-CitRx -Pattern $adj).IsMatch($c.Sentence)) {
                    $pair = (@($x.Norm, $y.Norm) | Sort-Object) -join ' || '
                    $compatible[$pair] = $true
                }
            }
        }
    }

    function Test-CitRefsDisagree {
        <#  Do two citations of one duty actually DISAGREE?

            Only when they disagree at the SAME LEVEL: two different clauses,
            or two unrelated instruments. A sentence that cites the clause and
            a sentence that cites only the instrument are the same citation at
            two levels of detail. An instrument the spine itself places inside
            another is the same authority named at two levels of generality.  #>
        param($A, $B, $Compatible)
        $ca = @($A.Clauses)
        $cb = @($B.Clauses)
        if ($ca.Count -gt 0 -and $cb.Count -gt 0) {
            $shared = @($ca | Where-Object { $cb -contains $_ })
            if ($shared.Count -eq 0) { return 'clause' }
        }
        $ia = @($A.Instruments | ForEach-Object { $_.Norm })
        $ib = @($B.Instruments | ForEach-Object { $_.Norm })
        if ($ia.Count -gt 0 -and $ib.Count -gt 0) {
            $shared = @($ia | Where-Object { $ib -contains $_ })
            if ($shared.Count -eq 0) {
                foreach ($x in $ia) {
                    foreach ($y in $ib) {
                        $pair = (@($x, $y) | Sort-Object) -join ' || '
                        if ($Compatible.ContainsKey($pair)) { return '' }
                    }
                }
                return 'instrument'
            }
        }
        return ''
    }

    # -- 1. one duty, two clause numbers -------------------------------------
    $byDuty = @{}
    foreach ($c in $cited) {
        if (-not $c.DutyKey) { continue }
        if (-not $byDuty.ContainsKey($c.DutyKey)) { $byDuty[$c.DutyKey] = New-Object System.Collections.Generic.List[object] }
        $byDuty[$c.DutyKey].Add($c)
    }
    foreach ($k in ($byDuty.Keys | Sort-Object)) {
        $grp = $byDuty[$k]
        if ($grp.Count -lt 2) { continue }
        $refSets = @{}
        foreach ($g in $grp) {
            $ref = (@(@($g.Clauses) + @($g.Instruments | ForEach-Object { $_.Norm })) | Sort-Object -Unique) -join ' + '
            if (-not $refSets.ContainsKey($ref)) { $refSets[$ref] = New-Object System.Collections.Generic.List[object] }
            $refSets[$ref].Add($g)
        }
        if ($refSets.Count -lt 2) { continue }
        $keys = @($refSets.Keys | Sort-Object)
        $level = ''
        $softened = $false
        $items = $grp.ToArray()
        for ($a = 0; $a -lt $items.Count; $a++) {
            for ($b = $a + 1; $b -lt $items.Count; $b++) {
                $d = Test-CitRefsDisagree -A $items[$a] -B $items[$b] -Compatible $compatible
                if ($d) { $level = $d } else { $softened = $true }
            }
        }
        if (-not $level) {
            if ($softened) {
                Add-CitSuppression -Rule 'duty-two-clauses/same-authority-named-two-ways' -Reason 'the two citations are the same authority at two levels of detail - a clause against its own instrument, or an instrument the spine itself places inside another - which is a guide introducing then citing precisely, not a contradiction'
                Add-CitFinding -Rule 'duty-cluster' -Level 'REPORT' -Anchors $grp `
                    -Detail ("one duty is cited at two levels of detail: {0}" -f (($keys | ForEach-Object { "[$_]" }) -join ' vs ')) `
                    -Extra ("duty phrase (normalised): " + $k)
            }
            continue
        }
        Add-CitFinding -Rule 'duty-two-clauses' -Level 'BLOCK' -Anchors $grp `
            -Detail ("one duty is cited to {0} different references, disagreeing at {1} level: {2}" -f $refSets.Count, $level, (($keys | ForEach-Object { "[$_]" }) -join ' vs ')) `
            -Extra ("duty phrase (normalised): " + $k)
    }

    # -- 2. one instrument, two scopes ---------------------------------------
    #  Polarity: the same instrument asserted and denied over the same object.
    $polar = @{}
    $roleOf = @{}
    $negRx = '(?<![\w-])(does not|do not|is not|are not|never|no longer|neither)(?![\w-])'
    $oblAlt = (($script:OBLIGATION | ForEach-Object { [regex]::Escape($_) }) -join '|')
    foreach ($c in $cited) {
        foreach ($i in $c.Instruments) {
            #  .Raw, NOT the object. An instrument is now a {Raw, Norm} pair,
            #  and passing the pair where a string is wanted stringifies it to
            #  "@{Raw=...; Norm=...}" - a pattern that matches nothing, in a
            #  gate that then reports clean. The self-test caught it because
            #  the planted contradiction did not fire; nothing else would have.
            $iRx = Get-CitWordRx -Term $i.Raw
            $m = (Get-CitRx -Pattern ($iRx + '\s*(?<neg>' + $negRx + ')?\s*(?<obl>' + $oblAlt + ')(?![\w-])(?<obj>[^.;]{4,160})')).Match($c.Sentence)
            if ($m.Success) {
                $obj = ((Get-CitContentWords -Text $m.Groups['obj'].Value) -join ' ')
                if ($obj) {
                    $neg = $false
                    if ($m.Groups['neg'].Success) { $neg = $true }
                    $key = $i.Norm + '||' + $obj
                    if (-not $polar.ContainsKey($key)) { $polar[$key] = New-Object System.Collections.Generic.List[object] }
                    $polar[$key].Add([pscustomobject]@{ Neg = $neg; At = $c })
                }
            }
            #  Role label: "<instrument> is the <label> standard".
            $rm = (Get-CitRx -Pattern ($iRx + '\s+is\s+the\s+(?<role>[a-z][a-z\- ]{2,40}?)\s+(standard|regulation|code|act)(?![\w-])')).Match($c.Sentence)
            if ($rm.Success) {
                $role = ((Get-CitContentWords -Text $rm.Groups['role'].Value) -join ' ')
                if ($role) {
                    $k2 = $i.Norm
                    if (-not $roleOf.ContainsKey($k2)) { $roleOf[$k2] = @{} }
                    if (-not $roleOf[$k2].ContainsKey($role)) { $roleOf[$k2][$role] = New-Object System.Collections.Generic.List[object] }
                    $roleOf[$k2][$role].Add($c)
                }
            }
        }
    }
    foreach ($k in ($polar.Keys | Sort-Object)) {
        $grp = $polar[$k]
        $pos = @($grp | Where-Object { -not $_.Neg })
        $neg = @($grp | Where-Object { $_.Neg })
        if ($pos.Count -eq 0 -or $neg.Count -eq 0) { continue }
        $anchors = @()
        foreach ($g in $grp) { $anchors += $g.At }
        Add-CitFinding -Rule 'scope-two-ways' -Level 'BLOCK' -Anchors $anchors `
            -Detail ("the same instrument's scope is both asserted ({0} place(s)) and denied ({1} place(s)) over the same object" -f $pos.Count, $neg.Count) `
            -Extra ("instrument and object (normalised): " + $k)
    }
    foreach ($k in ($roleOf.Keys | Sort-Object)) {
        $roles = $roleOf[$k]
        if ($roles.Count -lt 2) { continue }
        $anchors = @()
        foreach ($r in $roles.Keys) { foreach ($a in $roles[$r]) { $anchors += $a } }
        Add-CitFinding -Rule 'scope-two-ways' -Level 'BLOCK' -Anchors $anchors `
            -Detail ("one instrument is labelled {0} different ways: {1}" -f $roles.Count, (($roles.Keys | Sort-Object | ForEach-Object { "'$_'" }) -join ' vs ')) `
            -Extra ("instrument (normalised): " + $k)
    }

    # -- 3. adoption relationships -------------------------------------------
    $adopt = @{}
    $adoptRx = '(?<a>[A-Z][A-Za-z''\- ]{1,60}?)\s+(?<neg>' + $negRx + '\s+)?(?<v>adopts|adopt|adopted|has adopted|gives legal force to|give legal force to|incorporates|incorporate)\s+(?<b>(?:the\s+)?[A-Za-z][A-Za-z0-9''\-\. ]{2,60})'
    foreach ($c in $cited) {
        foreach ($m in (Get-CitRx -Pattern $adoptRx -CaseSensitive).Matches($c.Sentence)) {
            $a = ((Get-CitContentWords -Text $m.Groups['a'].Value) -join ' ')
            $b = ((Get-CitContentWords -Text $m.Groups['b'].Value) -join ' ')
            if (-not $a -or -not $b -or $a -eq $b) { continue }
            $pair = (@($a, $b) | Sort-Object) -join ' || '
            $dir = $a + ' -> ' + $b
            $neg = $false
            if ($m.Groups['neg'].Success) { $neg = $true }
            if (-not $adopt.ContainsKey($pair)) { $adopt[$pair] = New-Object System.Collections.Generic.List[object] }
            $adopt[$pair].Add([pscustomobject]@{ Dir = $dir; Neg = $neg; At = $c })
        }
    }
    foreach ($k in ($adopt.Keys | Sort-Object)) {
        $grp = $adopt[$k]
        $dirs = @($grp | ForEach-Object { $_.Dir } | Sort-Object -Unique)
        $pols = @($grp | ForEach-Object { $_.Neg } | Sort-Object -Unique)
        if ($dirs.Count -lt 2 -and $pols.Count -lt 2) { continue }
        $anchors = @()
        foreach ($g in $grp) { $anchors += $g.At }
        $what = 'both polarities'
        if ($dirs.Count -ge 2) { $what = 'both directions: ' + ($dirs -join ' vs ') }
        Add-CitFinding -Rule 'adoption-inconsistent' -Level 'BLOCK' -Anchors $anchors `
            -Detail ("one adoption relationship is stated {0}" -f $what) -Extra ("pair (normalised): " + $k)
    }

    # -- 4. registry provisos ------------------------------------------------
    #  A PROVISO IS DERIVED FROM THE REGISTRY'S OWN SHAPE, not declared here.
    #  Where a figure's required set holds both a MEASURED value and a
    #  qualifying phrase that carries no measurement, the qualifier is the
    #  caveat that travels with the value. Section 26's dropped caveat sat
    #  correctly in two places and was absent from seven sections and six
    #  slides, which is what this arm counts.
    $measureRx = '\d+(?:\.\d+)?\s*(?:degrees|degree|c|mm|cm|m|l|ml|g|gms|kg|hour|hours|minute|minutes|day|days|week|weeks|month|months|portions|portion)(?![\w-])'
    $provisos = New-Object System.Collections.Generic.List[object]
    if ($null -ne $Registry) {
        foreach ($f in @(Get-GateProp -Object $Registry -Names @('figures') -Default @())) {
            if ($null -eq $f) { continue }
            $name = [string](Get-GateProp -Object $f -Names @('name') -Default '')
            $reqs = @(@(Get-GateProp -Object $f -Names @('require') -Default @()) | Where-Object { "$_".Trim() })
            $declared = @(@(Get-GateProp -Object $f -Names @('proviso', 'caveat') -Default @()) | Where-Object { "$_".Trim() })
            $values = @($reqs | Where-Object { (Get-CitRx -Pattern $measureRx).IsMatch("$_") })
            $quals = $declared
            #  A QUALIFIER CARRIES NO NUMBER AT ALL. Testing only for the unit
            #  pattern read "30 individual portions" as a caveat, because the
            #  word between the number and its unit defeated the measurement
            #  match - and the gate then demanded that one measured value
            #  accompany another everywhere in the build, which is 25 findings
            #  of pure noise. A caveat is prose; a figure has a number in it.
            if ($quals.Count -eq 0) { $quals = @($reqs | Where-Object { "$_" -notmatch '\d' }) }
            if ($values.Count -eq 0 -or $quals.Count -eq 0) { continue }
            foreach ($v in $values) {
                foreach ($q in $quals) {
                    $provisos.Add([pscustomobject]@{ Figure = $name; Value = "$v"; Proviso = "$q" })
                }
            }
        }
    }
    if ($Announce -and -not $Quiet) {
        Write-GateCheckSet -What 'registry provisos' -Count $provisos.Count -DerivedFrom 'the registry itself - a required value that carries a measurement, paired with a required qualifier that carries none'
        foreach ($p in $provisos) { Write-Host ("    proviso: '{0}' must accompany '{1}'  ({2})" -f $p.Proviso, $p.Value, $p.Figure) -ForegroundColor DarkGray }
    }
    foreach ($p in $provisos) {
        $units = @{}
        foreach ($s in $sentences) {
            if (-not (Test-CitContains -Text $s.Sentence -Term $p.Value)) { continue }
            if (-not $units.ContainsKey($s.Unit)) { $units[$s.Unit] = New-Object System.Collections.Generic.List[object] }
            $units[$s.Unit].Add($s)
        }
        foreach ($u in ($units.Keys | Sort-Object)) {
            $here = $units[$u]
            $unitHasProviso = $false
            foreach ($s in $sentences) {
                if ($s.Unit -ne $u) { continue }
                if (Test-CitContains -Text $s.Sentence -Term $p.Proviso) { $unitHasProviso = $true; break }
            }
            if ($unitHasProviso) {
                $sameString = $false
                foreach ($s in $here) { if (Test-CitContains -Text $s.Sentence -Term $p.Proviso) { $sameString = $true; break } }
                if (-not $sameString) {
                    Add-CitSuppression -Rule 'proviso-absent/qualified-in-unit' -Reason 'the proviso is present in the same occurrence unit - the same sub-section, or the same slide - as the figure, so the reader of that page has it; requiring it in every individual string reports every row of a table the sentence beside it already qualifies'
                    Add-CitFinding -Rule 'proviso-thin' -Level 'REPORT' -Anchors $here `
                        -Detail ("the proviso is in this unit but not in the string that states the figure") -Extra ("proviso: " + $p.Proviso + " | value: " + $p.Value)
                }
                continue
            }
            #  THE CAVEAT IN THE AUTHOR'S OWN WORDS IS STILL THE CAVEAT. The
            #  registry stores one wording; the guide legitimately writes
            #  "stricter than the Code's 5 degrees C" or "tighter than the
            #  Code". Blocking on the literal alone reported ten units that
            #  carried the caveat in a paraphrase, which is a gate teaching its
            #  reader to skip it. So a unit carrying most of the caveat's own
            #  content words REPORTS for a reader to tighten the wording, and
            #  only a unit carrying none of it blocks.
            $provWords = Get-CitContentWords -Text $p.Proviso
            $unitText = ''
            foreach ($s in $sentences) { if ($s.Unit -eq $u) { $unitText += ' ' + $s.Sentence } }
            $unitWords = Get-CitContentWords -Text $unitText
            $hitWords = @($provWords | Where-Object { $unitWords -contains $_ })
            $overlap = 0.0
            if ($provWords.Count -gt 0) { $overlap = [double]$hitWords.Count / [double]$provWords.Count }
            if ($overlap -ge 0.5) {
                Add-CitSuppression -Rule 'proviso-absent/paraphrased-in-unit' -Reason 'the occurrence unit carries at least half of the caveat''s own content words, so the caveat is present in the author''s wording rather than the registry''s; the wording is worth tightening and is reported, but the caveat has not been dropped'
                Add-CitFinding -Rule 'proviso-paraphrased' -Level 'REPORT' -Anchors $here `
                    -Detail ("figure '{0}' is stated in {1} with the caveat in the author's own words rather than the registry's" -f $p.Value, $u) `
                    -Extra ("registry proviso: " + $p.Proviso + " | content-word overlap: " + [math]::Round($overlap, 2))
                continue
            }
            Add-CitFinding -Rule 'proviso-absent' -Level 'BLOCK' -Anchors $here `
                -Detail ("figure '{0}' is stated in {1} without the registry proviso that attaches to it" -f $p.Value, $u) `
                -Extra ("registry figure: " + $p.Figure + " | missing proviso: " + $p.Proviso + " | content-word overlap: " + [math]::Round($overlap, 2))
        }
    }

    # -- 5. the fuzzy half - REPORTS, blocks nothing -------------------------
    $withDuty = @($cited | Where-Object { $_.DutyKey })
    $wordsOf = @{}
    foreach ($c in $withDuty) { $wordsOf[$c] = @($c.DutyKey -split ' ') }
    $used = @{}
    for ($i = 0; $i -lt $withDuty.Count; $i++) {
        if ($used.ContainsKey($i)) { continue }
        $cluster = New-Object System.Collections.Generic.List[object]
        $cluster.Add($withDuty[$i])
        $wi = $wordsOf[$withDuty[$i]]
        for ($j = $i + 1; $j -lt $withDuty.Count; $j++) {
            if ($used.ContainsKey($j)) { continue }
            $wj = $wordsOf[$withDuty[$j]]
            if ($withDuty[$i].DutyKey -eq $withDuty[$j].DutyKey) { continue }
            $inter = @($wi | Where-Object { $wj -contains $_ }).Count
            $union = (@($wi + $wj | Sort-Object -Unique)).Count
            if ($union -eq 0) { continue }
            $sim = [double]$inter / [double]$union
            if ($sim -ge $Similarity) {
                $cluster.Add($withDuty[$j])
                $used[$j] = $true
            }
        }
        if ($cluster.Count -lt 2) { continue }
        $refs = @()
        foreach ($c in $cluster) { $refs += ((@(@($c.Clauses) + @($c.Instruments | ForEach-Object { $_.Norm })) | Sort-Object -Unique) -join ' + ') }
        $refs = @($refs | Sort-Object -Unique)
        if ($refs.Count -lt 2) {
            Add-CitSuppression -Rule 'duty-cluster/one-reference' -Reason 'the similar duty phrases all carry the same reference, so there is nothing for a reader to arbitrate'
            continue
        }
        Add-CitFinding -Rule 'duty-cluster' -Level 'REPORT' -Anchors $cluster.ToArray() `
            -Detail ("{0} similar duty phrases carry {1} different references: {2}" -f $cluster.Count, $refs.Count, (($refs | ForEach-Object { "[$_]" }) -join ' vs ')) `
            -Extra ("anchor duty phrase: " + $withDuty[$i].DutyKey)
    }

    return [pscustomobject]@{
        Findings = $script:Findings.ToArray()
        Rules = $script:RuleBook.ToArray()
        Suppressed = $script:Suppressed
        SuppressWhy = $script:SuppressWhy
        CheckSets = [pscustomobject]@{
            sentences = $sentences.Count
            citedSentences = $cited.Count
            instruments = $instrumentsSeen.Count
            provisos = $provisos.Count
            dutyPhrases = $withDuty.Count
            clusterSimilarity = $Similarity
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
$registryJson = Get-GateRegistry -BuildDir $buildResolved -RulesPath $RulesPath

# ---------------------------------------------------------------------------
# Self-test - plant, VERIFY THE PLANT LANDED, then run the shipping gate
# ---------------------------------------------------------------------------

$selfTestFailed = 0

if ($SelfTest) {
    Write-Host ''
    Write-Host ("  {0} SELF-TEST - a clean result is not believed until the gate has failed on a planted defect" -f $GATE) -ForegroundColor Cyan

    $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("cit-selftest-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null
    try {
        foreach ($n in @('contract.json', 'figures.json')) {
            $src = Join-Path $buildResolved $n
            if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $tmpRoot $n) -Force }
        }
        $tmpSpine = Join-Path $tmpRoot 'spine'
        New-Item -ItemType Directory -Force -Path $tmpSpine | Out-Null
        #  -LiteralPath does NOT expand a wildcard: a copy written that way
        #  moves nothing and the plant lands in an empty fixture.
        foreach ($sf in (Get-ChildItem -LiteralPath $spineResolved -Filter '*.json' -File)) {
            Copy-Item -LiteralPath $sf.FullName -Destination (Join-Path $tmpSpine $sf.Name) -Force
        }

        function Test-CitPlant {
            <# Read it BACK, in the channel the gate scans. A plant that
               silently failed to apply once made a gate on this project look
               proven when it was not. #>
            param([string] $File, [string] $Needle, [string] $What)
            $txt = Get-GateFileText -Path $File
            if ($txt.IndexOf($Needle, [System.StringComparison]::Ordinal) -ge 0) {
                Write-Host ("    plant landed: {0}" -f $What) -ForegroundColor DarkGray
                return $true
            }
            Write-Host ("    X plant did NOT land: {0} - this proves nothing" -f $What) -ForegroundColor Red
            return $false
        }

        function Set-CitPlant {
            param([string] $File, [string] $Field, [string[]] $Values)
            $j = Get-GateJson -Path $File
            $cur = @(Get-GateProp -Object $j -Names @($Field) -Default @())
            $new = New-Object System.Collections.Generic.List[object]
            foreach ($x in $cur) { $new.Add($x) }
            foreach ($v in $Values) { $new.Add($v) }
            if (@($j.PSObject.Properties.Name) -contains $Field) { $j.$Field = $new.ToArray() }
            else { $j | Add-Member -NotePropertyName $Field -NotePropertyValue $new.ToArray() }
            [System.IO.File]::WriteAllText($File, ($j | ConvertTo-Json -Depth 40), (New-Object System.Text.UTF8Encoding($true)))
        }

        $subFiles = @(Get-ChildItem -LiteralPath $tmpSpine -Filter '*.json' -File |
                      Where-Object { $_.Name -ne 'front.json' -and $_.Name -ne 'cover.json' -and $_.Name -ne 'deckframe.json' } |
                      Sort-Object Name)
        if ($subFiles.Count -lt 2) { throw "$GATE`: the fixture spine is empty, so nothing could be planted." }
        $victimA = $subFiles[0].FullName
        $victimB = $subFiles[1].FullName
        $plants = New-Object System.Collections.Generic.List[object]

        #  1. ONE DUTY, TWO CLAUSE NUMBERS. The instrument and both clause
        #     numbers are shaped, not named after any real instrument.
        $dutyA = 'Standard 9.9.9 clause 4 requires every planted batch to be labelled with its planted batch number before dispatch.'
        $dutyB = 'Standard 9.9.9 clause 5 requires every planted batch to be labelled with its planted batch number before dispatch.'
        Set-CitPlant -File $victimA -Field 'regulatoryBasis' -Values @($dutyA)
        Set-CitPlant -File $victimB -Field 'regulatoryBasis' -Values @($dutyB)
        $ok1 = (Test-CitPlant -File $victimA -Needle $dutyA -What 'one duty cited to clause 4') -and
               (Test-CitPlant -File $victimB -Needle $dutyB -What 'the same duty cited to clause 5')
        $plants.Add([pscustomobject]@{ Rule = 'duty-two-clauses'; Needle = 'planted batch number before dispatch'; What = 'one duty phrase cited to two different clause numbers'; Ok = $ok1 })

        #  2. ONE INSTRUMENT'S SCOPE, TWO NON-EQUIVALENT WAYS.
        $scopeA = 'Standard 9.9.8 applies to every planted ready-to-eat product held in the planted store.'
        $scopeB = 'Standard 9.9.8 does not apply to every planted ready-to-eat product held in the planted store.'
        Set-CitPlant -File $victimA -Field 'regulatoryBasis' -Values @($scopeA)
        Set-CitPlant -File $victimB -Field 'regulatoryBasis' -Values @($scopeB)
        $ok2 = (Test-CitPlant -File $victimA -Needle $scopeA -What 'the instrument applying to the planted product') -and
               (Test-CitPlant -File $victimB -Needle $scopeB -What 'the same instrument NOT applying to it')
        $plants.Add([pscustomobject]@{ Rule = 'scope-two-ways'; Needle = 'planted ready-to-eat product held'; What = 'one instrument''s scope stated two non-equivalent ways'; Ok = $ok2 })

        #  3. THE CORRECT CASE, which must NOT fire: the same duty, cited the
        #     same way, in two places. A guide is expected to repeat a duty.
        $clean = 'Standard 9.9.7 clause 2 requires every planted transfer to be recorded on the planted transfer record.'
        Set-CitPlant -File $victimA -Field 'regulatoryBasis' -Values @($clean)
        Set-CitPlant -File $victimB -Field 'regulatoryBasis' -Values @($clean)
        [void](Test-CitPlant -File $victimB -Needle $clean -What 'the SAME duty cited the SAME way twice, which must not fire')

        $bad = @($plants | Where-Object { -not $_.Ok })
        if ($bad.Count -gt 0) {
            Write-Host ("    X {0} plant(s) did not land. The self-test is void." -f $bad.Count) -ForegroundColor Red
            $selfTestFailed++
        }
        else {
            $probe = Invoke-CitScan -Build $tmpRoot -Spine $tmpSpine -Registry $registryJson -Similarity $ClusterSimilarity
            foreach ($p in $plants) {
                $hit = @($probe.Findings | Where-Object {
                    $_.Rule -eq $p.Rule -and $_.Level -eq 'BLOCK' -and
                    (([string]$_.Extra).IndexOf($p.Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                     @($_.Locations | Where-Object { ([string]$_.Sentence).IndexOf($p.Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 }).Count -gt 0)
                })
                if ($hit.Count -gt 0) {
                    Write-Host ("    self-test: {0} -> {1} fired as BLOCKING on the planted contradiction ({2} finding(s)). This arm can fail." -f $p.What, $p.Rule, $hit.Count) -ForegroundColor Green
                }
                else {
                    Write-Host ("    X self-test: {0} planted and {1} did NOT fire on it." -f $p.What, $p.Rule) -ForegroundColor Red
                    $selfTestFailed++
                }
            }
            $falsePos = @($probe.Findings | Where-Object {
                $_.Level -eq 'BLOCK' -and
                @($_.Locations | Where-Object { ([string]$_.Sentence).IndexOf('planted transfer record', [System.StringComparison]::OrdinalIgnoreCase) -ge 0 }).Count -gt 0
            })
            if ($falsePos.Count -eq 0) {
                Write-Host '    self-test: the same duty cited the same way in two places did NOT fire. Repetition is not contradiction.' -ForegroundColor Green
            }
            else {
                Write-Host '    X self-test: a duty repeated with the SAME citation fired as a contradiction. A gate that blocks on correct content gets switched off.' -ForegroundColor Red
                $selfTestFailed++
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

$result = Invoke-CitScan -Build $buildResolved -Spine $spineResolved -Registry $registryJson -Similarity $ClusterSimilarity -Announce

if ($result.CheckSets.citedSentences -eq 0) {
    Write-Host ("  X {0}: not one authored sentence carries a legislative reference, so this gate would pass by having nothing to compare." -f $GATE) -ForegroundColor Red
    exit 2
}

$blocking = @($result.Findings | Where-Object { $_.Level -eq 'BLOCK' })
$reported = @($result.Findings | Where-Object { $_.Level -ne 'BLOCK' })

$reportOut = $ReportPath
if (-not $reportOut) { $reportOut = Join-Path $buildResolved 'citation-consistency-report.json' }

$exitCode = 0
if ($selfTestFailed -gt 0) { $exitCode = 4 }
elseif ($blocking.Count -gt 0) { $exitCode = 1 }

$suppressRows = New-Object System.Collections.Generic.List[object]
foreach ($k in ($result.Suppressed.Keys | Sort-Object)) {
    $suppressRows.Add([pscustomobject]@{ Rule = $k; Count = $result.Suppressed[$k]; Reason = $result.SuppressWhy[$k] })
}

$payload = [pscustomobject]@{
    gate = $GATE
    generatedUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    buildDir = $buildResolved
    spineDir = $spineResolved
    spineFingerprint = (Get-SpineFingerprint -BuildDir $buildResolved -SpineDir $spineResolved)
    checkSets = $result.CheckSets
    rules = $result.Rules
    suppressions = $suppressRows.ToArray()
    blockingCount = $blocking.Count
    reportCount = $reported.Count
    blocking = $blocking
    report = $reported
    exitCode = $exitCode
}
[System.IO.File]::WriteAllText($reportOut, ($payload | ConvertTo-Json -Depth 12), (New-Object System.Text.UTF8Encoding($true)))

Write-Host ''
if ($suppressRows.Count -gt 0) {
    Write-Host '  named suppression rules that ran (never an allow-list of values):' -ForegroundColor DarkGray
    foreach ($s in $suppressRows) { Write-Host ("    {0} x{1}: {2}" -f $s.Rule, $s.Count, $s.Reason) -ForegroundColor DarkGray }
}
else { Write-Host '  no named suppression rule fired on this run' -ForegroundColor DarkGray }

if ($reported.Count -gt 0) {
    $byRule = @{}
    foreach ($f in $reported) {
        if (-not $byRule.ContainsKey($f.Rule)) { $byRule[$f.Rule] = 0 }
        $byRule[$f.Rule] = $byRule[$f.Rule] + 1
    }
    Write-Host ''
    Write-Host ("  REPORT ONLY - {0} finding(s), none of which changes the exit code. Every location is named in the report" -f $reported.Count) -ForegroundColor Yellow
    Write-Host '  so the fix is enumerated rather than sampled; a reader arbitrates, this gate does not.' -ForegroundColor Yellow
    foreach ($k in ($byRule.Keys | Sort-Object)) { Write-Host ("    {0}: {1}" -f $k, $byRule[$k]) -ForegroundColor Yellow }
    $shown = 0
    foreach ($f in $reported) {
        $shown++
        if ($shown -gt 12) { break }
        Write-Host ("      {0} - {1}" -f $f.Rule, $f.Detail) -ForegroundColor DarkGray
        foreach ($l in @($f.Locations | Select-Object -First 4)) { Write-Host ("        [{0}] {1}" -f $l.File, $l.Path) -ForegroundColor DarkGray }
        if ($f.LocationCount -gt 4) { Write-Host ("        ... {0} more location(s) in the report" -f ($f.LocationCount - 4)) -ForegroundColor DarkGray }
    }
    if ($reported.Count -gt 12) { Write-Host ("      ... and {0} more, all of them in {1}" -f ($reported.Count - 12), $reportOut) -ForegroundColor DarkGray }
}

Write-Host ''
Write-Host ("  complete finding list written to {0}" -f $reportOut) -ForegroundColor DarkGray

if ($selfTestFailed -gt 0) {
    Write-Host ("  X {0}: the self-test failed, so no result from this run may be believed." -f $GATE) -ForegroundColor Red
    exit 4
}

if ($blocking.Count -eq 0) {
    Write-Host ("  the spine does not contradict itself on any duty, scope, adoption or proviso ({0} report-level cluster(s) recorded)" -f $reported.Count) -ForegroundColor Green
    exit 0
}

Write-Host ("  X {0} exact contradiction(s)" -f $blocking.Count) -ForegroundColor Red
$shown = 0
foreach ($f in $blocking) {
    $shown++
    if ($shown -gt 25) { break }
    Write-Host ("    {0}: {1}" -f $f.Rule, $f.Detail) -ForegroundColor Red
    if ($f.Extra) { Write-Host ("      {0}" -f $f.Extra) -ForegroundColor DarkGray }
    foreach ($l in @($f.Locations | Select-Object -First 6)) {
        Write-Host ("      [{0}] {1}  ({2})" -f $l.File, $l.Path, $l.Surface) -ForegroundColor Yellow
        Write-Host ("        {0}" -f $l.Sentence) -ForegroundColor DarkGray
    }
    if ($f.LocationCount -gt 6) { Write-Host ("      ... {0} more location(s) in the report" -f ($f.LocationCount - 6)) -ForegroundColor DarkGray }
}
if ($blocking.Count -gt 25) { Write-Host ("    ... and {0} more in {1}" -f ($blocking.Count - 25), $reportOut) -ForegroundColor DarkGray }
Write-Host ''
Write-Host '  BOTH anchors are named because both have to be read: section 26 records a contradiction that' -ForegroundColor Yellow
Write-Host '  survived three audit rounds because each round fixed the instance it was shown. Fix every' -ForegroundColor Yellow
Write-Host '  location, then re-run.' -ForegroundColor Yellow
exit 1
