<#
    Assert-Provenance.ps1 - prove that every registered figure actually resolves
    in the source it names, and that every "the source says X" sentence carries
    a locator that resolves.

    Implements references\gates.md section 18. Runs at Stage 2 (registry seed),
    Stage 3c inside the band of section 12, and again at 7c. Blocks.

    WHY IT EXISTS. Until now this was performed by the Stage 6 auditor
    rebuilding the provenance ledger BY HAND, in all three audit rounds of one
    build. The reference build carries 493 provenance rows on its spine and 32
    on its registry; a human rebuilding 525 rows from four extracted documents
    is a human who will get two of them wrong, and did: two HIGH findings whose
    premise was false cost about two hours and damaged the document once. The
    fields this gate reads - authority and source - already existed on every
    registry entry and were read by NO script.

    IT IS NOT THE UNREGISTERED FIGURE SWEEP (section 17). That gate asks "is
    this figure registered at all"; this one asks "does the registration hold
    up". Section 17 inverts the registry into a whitelist; this one opens the
    named source and looks.

    ------------------------------------------------------------------------
    ARM 1 - REGISTRY RESOLUTION
    ------------------------------------------------------------------------
    Every provenance row - from figures.json AND from every spine sub-section's
    own provenance block, because both carry the same three fields and both are
    what the auditor rebuilds - names an authority class from a closed enum
    (P pack, U unit, L cited law, V venue procedure) and a locator naming a
    source document and a line or field. For each row the gate resolves the
    named document in the corpus, resolves the locator's own anchor inside it,
    and looks for the canonical value.

      RESOLVED      the value is at the locator, VERBATIM. Typography only -
                    case, curly quotes, the dash family, the spellings of
                    "degrees C", runs of whitespace - is folded, because a
                    curly apostrophe is not a provenance defect.
      NEAR-MISS     the value is there in a different form, or in a different
                    place: same number with a different unit, the value inside
                    another sentence, the locator pointing at the wrong line
                    while the value sits elsewhere in the same document, or the
                    value in a different document of the corpus. REPORTED for
                    adjudication. NEVER silently failed and never silently
                    passed: a near miss is usually a STALE LOCATOR and a true
                    absence is usually a FABRICATED FIGURE, and the two need
                    opposite fixes.
      UNRESOLVED    no variant of the value occurs anywhere in the corpus, and
                    the named source IS in the corpus. Blocking.
      SOURCE-ABSENT the named source is not in the corpus at all - the Code
                    itself, a manufacturer's manual, a standard nobody
                    extracted. Reported with the source name, because the fix
                    may be to ADD the source rather than to cut the sentence.
                    Where the value is also absent from every other source, the
                    row is additionally flagged: that is the shape a fabricated
                    figure takes when it hides behind an uncheckable citation.

    THE VERBATIM TEST RUNS ON THE QUANTITY, NOT ON THE SENTENCE AROUND IT.
    A provenance row states its figure in the build's own words - "50 portions
    of 350 Gms, 5 buckets of 3.5 L, 17.5 L in total". Grepping that sentence
    and calling its absence a fabrication is the false HIGH this gate exists to
    stop, and it is what the first run of this gate did to 216 rows. So where
    the row's own wording is not in the source, the row is DECOMPOSED into the
    quantities inside it and each is tested: all of them verbatim at the
    locator is RESOLVED; some of them is a NEAR-MISS that names the ones which
    did not resolve; and only NONE of them - the value gone and every quantity
    in it gone, from every document in the corpus - is UNRESOLVED. A row with
    no quantity in it at all is a paraphrase, and section 18's own rule
    applies: at least one distinctive content word present in the source,
    REPORTED rather than failed.

    AND NOTHING IS CALLED AN ABSENCE UNTIL THE WHOLE CORPUS HAS BEEN READ.
    Before a row can be UNRESOLVED, the same decomposition is run over every
    document the locator did NOT name. A value in the wrong document is a
    stale locator; only a value in no document is a fabricated figure. The
    first run of this gate reported a probe tolerance as an absence while the
    pack carried it verbatim, in a document the locator simply did not name.

    CLASS L, and this is the highest-risk defect this document type produces.
    An L row must resolve to named legislation, a standard or a code WITH its
    citation, and the gate reports separately whether the cited text present in
    the corpus MANDATES or merely RECOMMENDS the value. A recommendation
    dressed as a legal requirement is what put "75 degrees C as a critical
    limit" for a whole-muscle cut on a delivered page. The conflict arm is
    deliberately narrow and BLOCKS only when both halves are quotable: the
    guide's own prose applies a mandating verb to the cited instrument, AND the
    cited text in the corpus carries a recommending modal and no mandating one.
    Both sentences are printed. An L row with no citation shape in its locator
    is REPORTED, not failed - see rule 4 below.

    CLASS V. A venue figure must be accompanied on the page by the statement
    that it is the venue's own procedure. The venue vocabulary is derived from
    the contract, never typed. This arm REPORTS rather than blocks: it is a
    phrase match standing in for a judgement about wording, and gates.md rule 4
    says a gate of that shape names the anchor and stops. It names the
    sub-section file that carries the figure without the statement.

    ------------------------------------------------------------------------
    ARM 2 - SENTENCE-LEVEL ATTRIBUTION
    ------------------------------------------------------------------------
    Sweeps the spine's prose for [source noun] + [reporting verb] + [quantity],
    in that order and within a proximity window, so that "the Food Standards
    Code requires 5 degrees C", "the manufacturer specifies 90 seconds" and
    "Standard 3.2.2A states records are kept for three months" are all caught
    and an ordinary sentence that happens to contain a number is not.

      The SOURCE-NOUN vocabulary is DERIVED (rule 1) from the build contract's
      own source list - the workplace documents, the reference convention's
      document names, the unit and qualification titles - plus the corpus
      document names and the instrument names already written into the
      registry's own locators. Nothing about a unit, a brand or a path is
      typed into this file.

      The REPORTING VERB list is ONE list, so widening it widens every rule
      that uses it at once. It is read from contract.provenance.reportingVerbs
      where a build declares one, and otherwise from the documented default in
      section 18. When that list is promoted into Lib-GateCommon.ps1, delete
      the fallback here and read it from there.

      A sentence carrying an attributed quantity must carry a LOCATOR that
      resolves in the named source: a question reference in the contract's own
      convention, a recipe number from the contract's own recipe list, an
      appendix, a performance- or knowledge-evidence code, or a legal citation.
      The locator may sit in the sentence or in the cell that holds it, and the
      report says which - a locator one sentence away is ordinary prose, and
      failing it would be the kind of noise a builder learns to route around.

      An attributed quantity with NO resolving locator is UNRESOLVED and blocks.
      An attribution whose source is in no corpus document is SOURCE-ABSENT and
      is reported with the source name.
      An attribution carrying no quantity - "the pack's own open items list
      flags the storage life as provisional", the exact defect that reached
      twenty-one spine files of one build - is reported when its source cannot
      be resolved or it carries no locator, and never blocks, because the
      mechanical test on a proposition is weaker than the one on a quantity.

    ------------------------------------------------------------------------
    WHAT THIS GATE WILL NOT PRINT
    ------------------------------------------------------------------------
    It quotes the guide's own sentences and the cited source's, and nothing
    else. Where a value resolves in a document the corpus classifies
    assessor-only, the gate records the document and the line NUMBER and
    withholds the line TEXT. An anchor is enough to re-read; a benchmark row
    printed into a report that travels is a leak this toolchain has already
    paid for. Where the same value also resolves in a learner-facing document,
    that quote is preferred and printed.

    ------------------------------------------------------------------------
    OUTPUT
    ------------------------------------------------------------------------
    provenance-report.json in the build directory (or -OutPath): one record per
    registry row and per attributed sentence, each carrying the claim, the
    class, the locator, the disposition, the source line quoted where it
    resolved, and the file and field where the claim sits.

    PROVE IT FIRST. -SelfTest builds a throwaway fixture carrying five planted
    defects, VERIFIES EACH PLANT LANDED in the exact channel this gate scans
    before running anything, and then requires the gate to produce the exact
    disposition each plant was built for - including the correct row, which
    must NOT fire. A plant that silently failed to apply once passed a gate on
    this project and proved nothing.

    PS 5.1. ASCII only in this file.
    Exit 0 clean; 1 at least one UNRESOLVED row or sentence; 5 an L-class
    mandate conflict with no UNRESOLVED; 2 a usage error; 4 the self-test
    failed.
#>

[CmdletBinding()]
param(
    [string] $BuildDir,
    [string] $SpineDir,
    [string] $CorpusDir,
    #  Extra source text beyond the canonical corpus - extracted legislation, a
    #  manufacturer's manual, an appendix the pack references. Every .txt and
    #  .md beneath it is a source document, so a SOURCE-ABSENT row is fixed by
    #  adding the source here rather than by deleting the sentence.
    [string] $PackDir,
    [string] $RulesPath,
    [string] $OutPath,
    [switch] $SelfTest,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

$GATE = 'Assert-Provenance'

#  How far from the locator's own anchor the value may sit and still count as
#  being AT the locator. Wider than a paragraph, narrower than a document: a
#  locator that names a line and points 3000 characters away is a stale
#  locator, which is the thing this window exists to see.
$script:AnchorBack = 400
$script:AnchorFwd  = 2500

#  How close the reporting verb must follow the source noun, and the quantity
#  the verb, for the three to be one construction rather than three things that
#  happen to share a sentence.
$script:VerbGap = 60
$script:QtyGap  = 140

$script:MaxEvidence = 4
$script:MaxConsole  = 40

#  The closed enum section 18 declares. A build may widen it in
#  contract.provenance.authorityClasses; it is never widened here.
$script:DefaultClasses = @('P', 'U', 'L', 'V')

#  ONE reporting-verb list. Section 18's own list, in every inflection prose
#  uses. Overridden by contract.provenance.reportingVerbs.
$script:DefaultVerbs = @('state', 'say', 'give', 'list', 'show', 'carry', 'specify', 'record', 'require', 'flag')

#  The modal vocabulary that separates a duty from advice. Generic English, not
#  a build literal.
$script:MandateWords   = @('must', 'shall', 'requires', 'required', 'require', 'requirement', 'mandatory', 'mandates', 'legal requirement', 'is an offence', 'not permitted', 'prohibited', 'obliged', 'duty')
$script:RecommendWords = @('recommends', 'recommended', 'recommendation', 'recommend', 'should', 'advisable', 'guidance', 'guideline', 'guidelines', 'best practice', 'suggests', 'suggested', 'encouraged', 'may choose', 'good practice')

#  Phrases that say "this figure is ours". The venue's NAME comes from the
#  contract; these are the English shapes an author uses around it.
$script:VenuePhrases = @('house standard', 'house rule', 'house figure', 'house limit', 'own standard', 'own procedure', 'own figure', 'own rule', 'venue standard', 'venue procedure', 'organisational procedure', 'organisational specification', 'workplace procedure', 'in house standard', 'in house rule', 'standard operating procedure', 'own documented procedure', 'not a legal requirement', 'stricter than')

$script:UnitFamilies = @(
    'g|gm|gms|gram|grams|gramme|grammes',
    'kg|kgs|kilo|kilos|kilogram|kilograms',
    'l|ltr|ltrs|litre|litres|liter|liters',
    'ml|mls|millilitre|millilitres|milliliter|milliliters',
    'h|hr|hrs|hour|hours',
    'min|mins|minute|minutes',
    'sec|secs|second|seconds',
    'mm|millimetre|millimetres|millimeter|millimeters',
    'cm|centimetre|centimetres|centimeter|centimeters',
    'm|metre|metres|meter|meters',
    'day|days', 'week|weeks', 'month|months', 'year|years',
    'portion|portions', 'serve|serves|serving|servings', 'tray|trays', 'batch|batches',
    #  A recipe card writes tsp and tbsp; a registry row writes teaspoons and
    #  tablespoons. Without this family the gate called a unit that IS on the
    #  card an absence - a false HIGH on its own first real run.
    'tsp|tsps|teaspoon|teaspoons', 'tbsp|tbsps|tbs|tablespoon|tablespoons'
)

$script:NumberWords = @{
    'zero' = 0; 'one' = 1; 'two' = 2; 'three' = 3; 'four' = 4; 'five' = 5; 'six' = 6; 'seven' = 7;
    'eight' = 8; 'nine' = 9; 'ten' = 10; 'eleven' = 11; 'twelve' = 12; 'thirteen' = 13; 'fourteen' = 14;
    'fifteen' = 15; 'sixteen' = 16; 'seventeen' = 17; 'eighteen' = 18; 'nineteen' = 19; 'twenty' = 20;
    'thirty' = 30; 'forty' = 40; 'fifty' = 50; 'sixty' = 60; 'seventy' = 70; 'eighty' = 80; 'ninety' = 90
}

#  Words that are not source nouns however often they appear in a document
#  name. A vocabulary that contains "the" matches every sentence.
$script:NounStop = @('the', 'and', 'for', 'with', 'from', 'this', 'that', 'each', 'all', 'any', 'its',
                     'produce', 'use', 'using', 'prepare', 'certificate', 'docx', 'txt', 'json', 'pdf')

# ===========================================================================
# 1. Text - folding, and the three matching arms
# ===========================================================================

function ConvertTo-ProvFold {
    <#  Typography folded, nothing else. A curly apostrophe, an en dash and a
        double space are not provenance defects, so they must not be allowed to
        turn a verbatim match into a near miss - which would bury the near
        misses that ARE stale locators under a pile of punctuation.  #>
    param([string] $Text)
    if ($null -eq $Text) { return '' }
    $t = "$Text"
    $t = $t -replace '[\u2018\u2019\u02BC]', "'"
    $t = $t -replace '[\u201C\u201D]', '"'
    $t = $t -replace '[\u2010-\u2015\u2212]', '-'
    $t = $t -replace '[\u00A0\u2007\u202F]', ' '
    $t = $t -replace '\s+', ' '
    return $t.Trim()
}

function ConvertTo-ProvEnglishNumber {
    param([long] $N)
    $ones = @('zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten',
              'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen')
    $tens = @('', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety')
    if ($N -lt 0) { return ('minus ' + (ConvertTo-ProvEnglishNumber (-$N))) }
    if ($N -lt 20) { return $ones[[int]$N] }
    if ($N -lt 100) {
        $t = $tens[[int][math]::Floor($N / 10)]
        $r = $N % 10
        if ($r -gt 0) { return ($t + ' ' + $ones[[int]$r]) }
        return $t
    }
    if ($N -lt 1000) {
        $h = $ones[[int][math]::Floor($N / 100)] + ' hundred'
        $r = $N % 100
        if ($r -gt 0) { return ($h + ' and ' + (ConvertTo-ProvEnglishNumber $r)) }
        return $h
    }
    foreach ($sc in @(@(1000000, 'million'), @(1000, 'thousand'))) {
        if ($N -ge $sc[0]) {
            $head = (ConvertTo-ProvEnglishNumber ([long][math]::Floor($N / $sc[0]))) + ' ' + $sc[1]
            $r = $N % $sc[0]
            if ($r -eq 0) { return $head }
            if ($r -lt 100) { return ($head + ' and ' + (ConvertTo-ProvEnglishNumber $r)) }
            return ($head + ' ' + (ConvertTo-ProvEnglishNumber $r))
        }
    }
    return "$N"
}

function ConvertTo-ProvWordRegex {
    param([string] $Words)
    $parts = @("$Words" -split '\s+' | Where-Object { $_ })
    $s = ''
    for ($i = 0; $i -lt $parts.Count; $i++) {
        $tk = $parts[$i]
        if ($tk -eq 'and') { $s += '(?:and[\s-]*)?'; continue }
        $s += $tk
        if ($i -lt $parts.Count - 1) { $s += '[\s-]*' }
    }
    return ('\b' + $s + '\b')
}

function Get-ProvNumberRegex {
    <# 3840, 3,840, 3 840, and the word form. #>
    param([string] $Tok)
    $alts = New-Object System.Collections.Generic.List[string]
    $t = "$Tok" -replace ',', ''
    if ($t -match '^(\d+)\.(\d+)$') {
        $ip = $Matches[1]; $fp = $Matches[2]
        $alts.Add(([regex]::Escape($ip) + '[.,]' + [regex]::Escape($fp)))
    }
    elseif ($t -match '^\d+$') {
        $sb = ''
        for ($i = 0; $i -lt $t.Length; $i++) {
            $sb += $t[$i]
            $remaining = $t.Length - $i - 1
            if ($remaining -gt 0 -and ($remaining % 3) -eq 0) { $sb += '[,\s]?' }
        }
        $alts.Add($sb)
        if ($t.Length -le 7) { $alts.Add((ConvertTo-ProvWordRegex (ConvertTo-ProvEnglishNumber ([long]$t)))) }
    }
    else { $alts.Add([regex]::Escape("$Tok")) }
    return ('(?<![\d.,])(?:' + ($alts -join '|') + ')(?!\d)')
}

function Add-ProvCharClass {
    <#  After escaping, let a straight quote match a curly one and a hyphen
        match the whole dash family, so the EXACT arm stays exact about the
        value and blind to the typesetter.  #>
    param([string] $Escaped)
    $s = "$Escaped"
    $s = $s.Replace("'", "['\u2018\u2019\u02BC]")
    $s = $s.Replace('"', '["\u201C\u201D]')
    $s = $s.Replace('\-', '[-\u2010-\u2015\u2212]')
    return $s
}

$script:DegRx = '(?:(?:degrees?|deg\.?)\s*(?:c|celsius|centigrade)\b|\u00B0\s*c\b|\u00B0C)'

function Get-ProvExactRegex {
    <# The verbatim arm: the value itself, whitespace- and typography-tolerant. #>
    param([string] $Value)
    $v = ConvertTo-ProvFold $Value
    if (-not $v) { return $null }
    $v = [regex]::Replace($v, '(?i)(?:degrees?|deg\.?)\s*(?:c|celsius|centigrade)\b', ' __DEGC__ ')
    $toks = @($v -split '\s+' | Where-Object { $_ })
    if ($toks.Count -eq 0) { return $null }
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($tk in $toks) {
        if ($tk -eq '__DEGC__') { $parts.Add($script:DegRx); continue }
        $parts.Add((Add-ProvCharClass ([regex]::Escape($tk))))
    }
    return ($parts -join '\s+')
}

function Get-ProvLooseRegex {
    <# Same words, indifferent to punctuation between them: "3.5 L" / "3.5L". #>
    param([string] $Value)
    $v = ConvertTo-ProvFold $Value
    if (-not $v) { return $null }
    $v = [regex]::Replace($v, '(?i)(?:degrees?|deg\.?)\s*(?:c|celsius|centigrade)\b', ' __DEGC__ ')
    $toks = @([regex]::Matches($v, '__DEGC__|[A-Za-z]+|\d+(?:[.,]\d+)?') | ForEach-Object { $_.Value })
    if ($toks.Count -eq 0) { return $null }
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($tk in $toks) {
        if ($tk -eq '__DEGC__') { $parts.Add($script:DegRx); continue }
        $parts.Add([regex]::Escape($tk))
    }
    return ($parts -join '\W*')
}

function Get-ProvVariantRegex {
    <#  Every spelling this toolchain has seen a source use: digits for words,
        Gms for grams, deg C for degrees C. A literal-string check is not an
        enumerating check.  #>
    param([string] $Value)
    $v = ConvertTo-ProvFold $Value
    if (-not $v) { return $null }
    $v = [regex]::Replace($v, "(?i)(?:'|\u2019)s\b", '')
    $v = [regex]::Replace($v, '(?i)(?:degrees?|deg\.?)\s*(?:c|celsius|centigrade)\b', ' __degc__ ')
    $v = [regex]::Replace($v, '(?i)%|\bper\s*cent\b|\bpercent\b', ' __pct__ ')

    $toks = @([regex]::Matches($v, '\d+(?:[.,]\d+)*|__[a-z]+__|[A-Za-z]+') | ForEach-Object { $_.Value })
    $parts = New-Object System.Collections.Generic.List[string]
    $i = 0
    while ($i -lt $toks.Count) {
        $tok = $toks[$i]
        $low = $tok.ToLowerInvariant()
        $i++
        if ($tok -match '^\d') { $parts.Add((Get-ProvNumberRegex $tok)); continue }
        if ($low -eq '__degc__') { $parts.Add('(?:' + $script:DegRx + '|\bcelsius\b|\bcentigrade\b|\bdegrees?\b)'); continue }
        if ($low -eq '__pct__')  { $parts.Add('(?:%|\bper\s*cent\b|\bpercent\b|\bpct\b)'); continue }
        if ($script:NumberWords.ContainsKey($low)) {
            $n = [long]$script:NumberWords[$low]
            if ($n -ge 20 -and $i -lt $toks.Count) {
                $nxt = $toks[$i].ToLowerInvariant()
                if ($script:NumberWords.ContainsKey($nxt) -and $script:NumberWords[$nxt] -ge 1 -and $script:NumberWords[$nxt] -le 9) {
                    $n += [long]$script:NumberWords[$nxt]; $i++
                }
            }
            $parts.Add((Get-ProvNumberRegex "$n")); continue
        }
        $fam = $null
        foreach ($f in $script:UnitFamilies) { if ($low -match ('^(?:' + $f + ')$')) { $fam = $f; break } }
        if ($fam) { $parts.Add(('\b(?:' + $fam + ')\b')) }
        else      { $parts.Add(('\b' + [regex]::Escape($low) + '\b')) }
    }
    if ($parts.Count -eq 0) { return $null }
    return ($parts -join '\W*')
}

function Get-ProvQuantity {
    <# Every number-with-unit token in a string, plus bare temperatures. #>
    param([string] $Text)
    $t = ConvertTo-ProvFold $Text
    $rx = '(?i)(?:minus\s+)?\d[\d,]*(?:\.\d+)?\s*(?:' + $script:DegRx + '|per\s*cent|%|' + ($script:UnitFamilies -join '|') + ')(?![a-z])'
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($t, $rx)) {
        $v = ($m.Value -replace '\s+', ' ').Trim()
        if (-not $out.Contains($v)) { $out.Add($v) }
    }
    return $out.ToArray()
}

function Get-ProvDistinctWord {
    <#  The content words a paraphrase can be tested by. Section 18's own
        false-positive control: a paraphrase is not required to be verbatim,
        it is required to share a distinctive content word with its source.  #>
    param([string] $Value)
    $w = @([regex]::Matches((ConvertTo-ProvFold $Value).ToLowerInvariant(), '[a-z]{5,}') | ForEach-Object { $_.Value })
    return @($w | Where-Object { $script:NounStop -notcontains $_ } | Select-Object -Unique)
}

function Get-ProvSnippet {
    param([string] $Text, [int] $Max = 200)
    $s = ConvertTo-ProvFold $Text
    if ($s.Length -gt $Max) { return ($s.Substring(0, $Max - 3) + '...') }
    return $s
}

# ===========================================================================
# 2. The documents this gate opens
# ===========================================================================

function New-ProvDoc {
    param([string] $Name, [string] $Path, [string] $Audience, [string] $Text)
    $body = "$Text"
    $lines = @($body -split "`r?`n")
    $starts = New-Object System.Collections.Generic.List[int]
    $starts.Add(0)
    foreach ($m in [regex]::Matches($body, "`n")) { $starts.Add($m.Index + 1) }
    return [pscustomobject]@{
        Name       = $Name
        Path       = $Path
        Audience   = $Audience
        Text       = $body
        Lines      = $lines
        LineStarts = $starts.ToArray()
        NameTokens = @(([regex]::Split(("$Name" -replace '\.[A-Za-z0-9]+$', ''), '[^A-Za-z0-9]+')) | Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() })
    }
}

function Get-ProvLineAt {
    <# Offset to 1-based line number, by binary search on the line starts. #>
    param($Doc, [int] $Offset)
    $idx = [array]::BinarySearch($Doc.LineStarts, [int]$Offset)
    if ($idx -lt 0) { $idx = (-$idx) - 2 }
    if ($idx -lt 0) { $idx = 0 }
    if ($idx -ge $Doc.Lines.Count) { $idx = $Doc.Lines.Count - 1 }
    return ($idx + 1)
}

function Get-ProvSafeQuote {
    <#  The line, unless the document is assessor-only. This gate never prints
        a benchmark row or a model answer, so an assessor-only hit is reported
        as an anchor a reader can open and nothing more.  #>
    param($Doc, [int] $Line)
    if ($Doc.Audience -eq 'assessor') {
        return ('[assessor-only line withheld - open {0} line {1}]' -f $Doc.Name, $Line)
    }
    $i = $Line - 1
    if ($i -lt 0 -or $i -ge $Doc.Lines.Count) { return '' }
    return (Get-ProvSnippet $Doc.Lines[$i])
}

function Get-ProvSources {
    <#  The canonical corpus, the unit extract, and anything under -PackDir.
        One resolution shared with every other gate, so two gates can never
        read two different extractions of the same pack.  #>
    param([string] $ForBuildDir, [string] $ForCorpusDir, [string] $ForPackDir)
    $docs = New-Object System.Collections.Generic.List[object]
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $resolved = $null
    try { $resolved = Get-GateCorpusDir -BuildDir $ForBuildDir -CorpusDir $ForCorpusDir }
    catch { if (-not $ForPackDir) { throw } }

    if ($resolved) {
        $corpus = Get-GateCorpusDocs -CorpusDir $resolved -BuildDir $ForBuildDir
        foreach ($d in @($corpus.Documents)) {
            if ($seen.Add($d.Path)) { $docs.Add((New-ProvDoc -Name $d.Name -Path $d.Path -Audience $d.Audience -Text $d.Text)) }
        }
    }
    foreach ($dir in @($ForBuildDir, $resolved)) {
        if (-not $dir -or -not (Test-Path -LiteralPath $dir)) { continue }
        foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter 'unit_extract*.md' -File -ErrorAction SilentlyContinue)) {
            if ($seen.Add($f.FullName)) { $docs.Add((New-ProvDoc -Name $f.BaseName -Path $f.FullName -Audience 'unit' -Text (Get-GateFileText -Path $f.FullName))) }
        }
    }
    if ($ForPackDir) {
        if (-not (Test-Path -LiteralPath $ForPackDir)) { throw ("{0}: -PackDir does not exist: {1}" -f $GATE, $ForPackDir) }
        foreach ($f in @(Get-ChildItem -LiteralPath $ForPackDir -Recurse -File | Where-Object { $_.Extension -eq '.txt' -or $_.Extension -eq '.md' })) {
            if ($seen.Add($f.FullName)) { $docs.Add((New-ProvDoc -Name $f.BaseName -Path $f.FullName -Audience 'pack' -Text (Get-GateFileText -Path $f.FullName))) }
        }
    }
    return [pscustomobject]@{ Docs = $docs.ToArray(); CorpusDir = $resolved }
}

function Get-ProvSpineCells {
    <#  Every string the spine puts in front of a reader, with its file, field
        path and channel. Identifiers and build metadata are skipped from the
        SWEEP only - never anything that carries prose.  #>
    param([string] $ForBuildDir, [string] $ForSpineDir)
    $skip = @{}
    foreach ($k in (Get-GateUnrenderedFields -BuildDir $ForBuildDir -ForSweep).Keys) { $skip[$k] = $true }
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($f in (Get-GateSpineFiles -BuildDir $ForBuildDir -SpineDir $ForSpineDir -Exclude @())) {
        $j = Get-GateJson -Path $f.FullName
        if ($null -eq $j) { continue }
        foreach ($c in @(Get-GateSpineCells -Node $j -File $f.Name -Path '' -Channel '' -Slot '' -Skip $skip)) {
            $out.Add([pscustomobject]@{
                File = $c.File; Path = $c.Path; Channel = $c.Channel; Slot = $c.Slot
                Text = $c.Text; Fold = (ConvertTo-ProvFold $c.Text).ToLowerInvariant()
            })
        }
    }
    return $out.ToArray()
}

# ===========================================================================
# 3. Finding a value in a document
# ===========================================================================

function Find-ProvValue {
    <#  Three arms in order of strength, and the arm is REPORTED, because the
        arm is the whole difference between a verbatim match and a near miss.
        Cheapest arm first so 500 rows against a 200 KB corpus stay quick.  #>
    param([string] $Value, $Docs, [int] $Max = 6)
    $hits = New-Object System.Collections.Generic.List[object]
    if (-not "$Value".Trim()) { return $hits }
    $arms = @(
        @{ Arm = 'exact';   Rx = (Get-ProvExactRegex   -Value $Value) },
        @{ Arm = 'loose';   Rx = (Get-ProvLooseRegex   -Value $Value) },
        @{ Arm = 'variant'; Rx = (Get-ProvVariantRegex -Value $Value) }
    )
    foreach ($d in @($Docs)) {
        foreach ($a in $arms) {
            if (-not $a.Rx) { continue }
            $m = [regex]::Match($d.Text, $a.Rx, 'IgnoreCase')
            if (-not $m.Success) { continue }
            $seenOffsets = New-Object 'System.Collections.Generic.HashSet[int]'
            while ($m.Success -and $hits.Count -lt $Max) {
                if ($seenOffsets.Add($m.Index)) {
                    $ln = Get-ProvLineAt -Doc $d -Offset $m.Index
                    $hits.Add([pscustomobject]@{
                        Doc = $d.Name; Audience = $d.Audience; Arm = $a.Arm; Offset = $m.Index
                        Line = $ln; Text = (Get-ProvSafeQuote -Doc $d -Line $ln); Matched = (Get-ProvSnippet $m.Value 80)
                    })
                }
                $m = $m.NextMatch()
            }
            break   # a document reports its STRONGEST arm, not all three
        }
        if ($hits.Count -ge $Max) { break }
    }
    return $hits
}

# ===========================================================================
# 4. The vocabularies - all DERIVED, none typed (rule 1)
# ===========================================================================

function Get-ProvReportingVerbs {
    param($Contract)
    $declared = @()
    if ($null -ne $Contract -and @($Contract.PSObject.Properties.Name) -contains 'provenance') {
        $declared = @(Get-GateProp -Object $Contract.provenance -Names @('reportingVerbs') -Default @())
    }
    $stems = @($script:DefaultVerbs)
    $from = 'the section 18 default list'
    if ($declared.Count -gt 0) { $stems = @($declared | ForEach-Object { "$_".ToLowerInvariant() }); $from = 'contract.provenance.reportingVerbs' }
    $forms = New-Object System.Collections.Generic.List[string]
    foreach ($v in $stems) {
        $s = "$v".Trim().ToLowerInvariant()
        if (-not $s) { continue }
        $forms.Add($s)
        if ($s -match '(s|x|z|ch|sh)$') { $forms.Add($s + 'es') }
        elseif ($s -match '[^aeiou]y$') { $forms.Add(($s.Substring(0, $s.Length - 1) + 'ies')) }
        else { $forms.Add($s + 's') }
        if ($s -match 'e$') { $forms.Add($s + 'd') } else { $forms.Add($s + 'ed') }
    }
    return [pscustomobject]@{ Forms = @($forms | Select-Object -Unique); DerivedFrom = $from; Stems = $stems }
}

function Get-ProvAuthorityClasses {
    param($Contract)
    if ($null -ne $Contract -and @($Contract.PSObject.Properties.Name) -contains 'provenance') {
        $d = @(Get-GateProp -Object $Contract.provenance -Names @('authorityClasses') -Default @())
        if ($d.Count -gt 0) { return @($d | ForEach-Object { "$_".ToUpperInvariant() }) }
    }
    return $script:DefaultClasses
}

function Add-ProvPhrase {
    param($Bag, [string] $Text, [string] $From, [int] $MinWords = 1)
    $p = ConvertTo-ProvFold $Text
    if (-not $p) { return }
    $p = ($p -replace '[^A-Za-z0-9 ]', ' ') -replace '\s+', ' '
    $p = $p.Trim().ToLowerInvariant()
    if (-not $p) { return }
    $words = @($p -split ' ' | Where-Object { $_ -and ($script:NounStop -notcontains $_) })
    if ($words.Count -lt $MinWords) { return }
    if ($words.Count -eq 0) { return }
    $p = ($words -join ' ')
    if ($p.Length -lt 6) { return }
    if (-not $Bag.ContainsKey($p)) { $Bag[$p] = $From }
}

function Get-ProvSourceNouns {
    <#  The build contract's own source list is the vocabulary. Nothing about
        this unit, this brand or this pack is typed here: a gate that names its
        sources by hand cannot notice the source nobody declared.  #>
    param($Contract, $Docs, $Rows, $Alias)
    $bag = @{}
    #  The reference convention's own LABELS are source nouns in their own
    #  right. "Workbook Task 9(c) states that ..." is the archetypal attributed
    #  sentence in this document type, and a vocabulary built only from
    #  document TITLES cannot see it.
    foreach ($k in @($Alias.Keys)) { Add-ProvPhrase -Bag $bag -Text $k -From 'contract.referenceConvention label' }
    if ($null -ne $Contract) {
        $sc = Get-GateProp -Object $Contract -Names @('scenario')
        if ($null -ne $sc) {
            foreach ($w in @(Get-GateProp -Object $sc -Names @('workplaceDocuments') -Default @())) { Add-ProvPhrase -Bag $bag -Text $w -From 'contract.scenario.workplaceDocuments' }
            foreach ($w in @(Get-GateProp -Object $sc -Names @('sources', 'sourceList') -Default @())) { Add-ProvPhrase -Bag $bag -Text $w -From 'contract.scenario.sources' }
            Add-ProvPhrase -Bag $bag -Text (Get-GateProp -Object $sc -Names @('employer') -Default '') -From 'contract.scenario.employer'
        }
        $rc = Get-GateProp -Object $Contract -Names @('referenceConvention')
        if ($null -ne $rc) {
            foreach ($n in @($rc.PSObject.Properties.Name)) {
                if ($n -like '_*') { continue }
                $v = "$($rc.$n)"
                if ($n -match 'Means$') {
                    #  "Task {n} in SITHCCC032_Recipe_Workbook.docx" - the document
                    #  half is the source noun; the pattern half is the locator.
                    $m = [regex]::Match($v, '(?i)\bin\s+(.+)$')
                    if ($m.Success) { Add-ProvPhrase -Bag $bag -Text $m.Groups[1].Value -From 'contract.referenceConvention' }
                }
            }
        }
        $u = Get-GateProp -Object $Contract -Names @('unit')
        if ($null -ne $u) { Add-ProvPhrase -Bag $bag -Text (Get-GateProp -Object $u -Names @('title') -Default '') -From 'contract.unit.title' }
    }
    foreach ($d in @($Docs)) { Add-ProvPhrase -Bag $bag -Text (($d.NameTokens) -join ' ') -From 'corpus document name' }

    #  Instrument NAMES already written into the registry's own locators: an
    #  Act, a Standard, a Code, a Regulation, with its own identifying words.
    #  -MinWords 2 is the whole point. Dozens of locators in a pack of this
    #  shape begin "Standard recipe card 2094", and taking the bare word
    #  "Standard" out of them put a one-word entry in the vocabulary that
    #  matched 76 ordinary sentences and reported every one of them as an
    #  attribution to a source nobody extracted.
    foreach ($r in @($Rows)) {
        foreach ($m in [regex]::Matches("$($r.Locator)", '(?:[A-Z][A-Za-z]+\s+){0,4}(?:Act|Code|Regulations?|Standard|Guidelines?|Manual|Specification)\b(?:\s+\d+(?:\.\d+)*[A-Z]?)?')) {
            Add-ProvPhrase -Bag $bag -Text $m.Value -From 'registry locator' -MinWords 2
        }
    }
    return $bag
}

function Get-ProvAliasMap {
    <#  Which document a reference-convention label means. Derived from the
        contract's own "means" strings, matched onto the corpus by token
        overlap, tightest match first, learner-facing preferred - so a sweep
        quotes the learner workbook and not the assessor guide beside it.  #>
    param($Contract, $Docs)
    $map = @{}
    if ($null -eq $Contract) { return $map }
    $rc = Get-GateProp -Object $Contract -Names @('referenceConvention')
    if ($null -eq $rc) { return $map }
    foreach ($n in @($rc.PSObject.Properties.Name)) {
        if ($n -like '_*' -or $n -notmatch 'Means$') { continue }
        $base = $n -replace 'Means$', ''
        $label = "$($rc.$base)"
        if (-not $label) { continue }
        $labelText = ($label -replace '\{.*$', '').Trim()
        if (-not $labelText) { continue }
        $hint = "$($rc.$n)"
        $m = [regex]::Match($hint, '(?i)\bin\s+(.+)$')
        if ($m.Success) { $hint = $m.Groups[1].Value }
        $doc = Resolve-ProvDocByName -Hint $hint -Docs $Docs
        if ($null -ne $doc) { $map[$labelText.ToLowerInvariant()] = $doc.Name }
    }
    return $map
}

function Get-ProvLabelForm {
    <#  What the DOCUMENT calls the item the guide calls "Workbook Task 5(b)".

        The contract carries both halves: "workbook" is the guide-side label
        and "workbookMeans" says the document's own form is "Task {n}". A
        locator search that hunts for the guide's label inside the pack finds
        nothing, marks every question reference unresolvable, and reports nine
        correctly located sentences as attributions whose locator does not
        resolve - which is exactly what the first real run of this gate did.  #>
    param($Contract)
    $map = @{}
    if ($null -eq $Contract) { return $map }
    $rc = Get-GateProp -Object $Contract -Names @('referenceConvention')
    if ($null -eq $rc) { return $map }
    foreach ($n in @($rc.PSObject.Properties.Name)) {
        if ($n -like '_*' -or $n -notmatch 'Means$') { continue }
        $base = $n -replace 'Means$', ''
        $label = ("$($rc.$base)" -replace '\{.*$', '').Trim()
        $docForm = ("$($rc.$n)" -replace '\{.*$', '').Trim()
        if ($label -and $docForm -and $label.ToLowerInvariant() -ne $docForm.ToLowerInvariant()) {
            $map[$label.ToLowerInvariant()] = $docForm
        }
    }
    return $map
}

function Resolve-ProvDocByName {
    <#  A free-text document name onto a corpus document. Score by matched
        name tokens; break ties on FEWER extra tokens, then on learner-facing,
        so "Recipe Workbook" resolves to the workbook and not to the assessor
        guide whose own name contains every one of those tokens.  #>
    param([string] $Hint, $Docs)
    $h = (ConvertTo-ProvFold $Hint).ToLowerInvariant()
    $ht = @(([regex]::Split($h, '[^a-z0-9]+')) | Where-Object { $_ -and $_.Length -ge 3 -and ($script:NounStop -notcontains $_) })
    if ($ht.Count -eq 0) { return $null }
    $best = $null; $bestScore = 0; $bestExtra = 999; $bestAud = 9
    foreach ($d in @($Docs)) {
        $hit = 0
        foreach ($t in $ht) { if ($d.NameTokens -contains $t) { $hit++ } }
        if ($hit -eq 0) { continue }
        $extra = @($d.NameTokens).Count - $hit
        $aud = 1; if ($d.Audience -eq 'assessor') { $aud = 2 }
        $better = $false
        if ($hit -gt $bestScore) { $better = $true }
        elseif ($hit -eq $bestScore -and $extra -lt $bestExtra) { $better = $true }
        elseif ($hit -eq $bestScore -and $extra -eq $bestExtra -and $aud -lt $bestAud) { $better = $true }
        if ($better) { $best = $d; $bestScore = $hit; $bestExtra = $extra; $bestAud = $aud }
    }
    if ($bestScore -lt [math]::Min(2, $ht.Count)) { return $null }
    return $best
}

function Get-ProvVenueTokens {
    <# The venue's own names, from the contract. Never a brand literal. #>
    param($Contract)
    $out = New-Object System.Collections.Generic.List[string]
    if ($null -eq $Contract) { return $out.ToArray() }
    $b = Get-GateProp -Object $Contract -Names @('build')
    foreach ($n in @('brand', 'tradingName', 'variant')) {
        $v = "$(Get-GateProp -Object $b -Names @($n) -Default '')"
        if ($v.Trim().Length -ge 3) { $out.Add($v.Trim().ToLowerInvariant()) }
    }
    $sc = Get-GateProp -Object $Contract -Names @('scenario')
    foreach ($n in @('employer', 'venue')) {
        $v = "$(Get-GateProp -Object $sc -Names @($n) -Default '')"
        if ($v.Trim().Length -ge 3) { $out.Add((ConvertTo-ProvFold $v).ToLowerInvariant()) }
    }
    return @($out | Select-Object -Unique)
}

# ===========================================================================
# 5. Locators - what one looks like, and whether it resolves
# ===========================================================================

function Get-ProvLocatorPatterns {
    <#  Derived: the contract's own question pattern and recipe numbers, plus
        the document-independent SHAPES a locator takes - an appendix, an
        evidence code, a clause, a standard, a named Act. A shape is not a
        build literal; a recipe number is, which is why it comes from the
        contract's recipe list and not from this file.  #>
    param($Contract)
    $pats = New-Object System.Collections.Generic.List[object]
    $qp = ''
    if ($null -ne $Contract) {
        $rc = Get-GateProp -Object $Contract -Names @('referenceConvention')
        if ($null -ne $rc) { $qp = "$(Get-GateProp -Object $rc -Names @('questionPattern') -Default '')" }
    }
    if ($qp) { $pats.Add([pscustomobject]@{ Kind = 'question'; Rx = $qp; From = 'contract.referenceConvention.questionPattern' }) }
    else     { $pats.Add([pscustomobject]@{ Kind = 'question'; Rx = '\b(?:Task|Question|Item|Observation)\s?(\d+)\s?(\([a-z]\))?'; From = 'documented default shape' }) }

    $nums = New-Object System.Collections.Generic.List[string]
    if ($null -ne $Contract) {
        $sc = Get-GateProp -Object $Contract -Names @('scenario')
        foreach ($r in @(Get-GateProp -Object $sc -Names @('recipes') -Default @())) {
            $no = "$(Get-GateProp -Object $r -Names @('no', 'number', 'code') -Default '')"
            if ($no -match '^\d{2,6}$') { $nums.Add($no) }
        }
    }
    if ($nums.Count -gt 0) {
        $pats.Add([pscustomobject]@{ Kind = 'recipe'; Rx = ('\b(' + (($nums | Select-Object -Unique) -join '|') + ')\b'); From = 'contract.scenario.recipes' })
    }
    $pats.Add([pscustomobject]@{ Kind = 'appendix';  Rx = '\bAppendi(?:x|ces)\s+([A-Z])\b';                                     From = 'shape' })
    $pats.Add([pscustomobject]@{ Kind = 'evidence';  Rx = '\b((?:PE|KE|PC|FS)\s?\d+[a-z]?)\b';                                   From = 'shape' })
    $pats.Add([pscustomobject]@{ Kind = 'clause';    Rx = '\bclause\s+(\d+(?:\.\d+)*(?:\(\d+\))*)';                              From = 'shape' })
    $pats.Add([pscustomobject]@{ Kind = 'standard';  Rx = '\bStandard\s+(\d+(?:\.\d+)*[A-Z]?)\b';                                From = 'shape' })
    $pats.Add([pscustomobject]@{ Kind = 'act';       Rx = '\b([A-Z][A-Za-z]+(?:\s+[A-Z][A-Za-z]+){0,3}\s+Act\s+\d{4})\b';       From = 'shape' })
    $pats.Add([pscustomobject]@{ Kind = 'regs';      Rx = '\b([A-Z][A-Za-z]+(?:\s+[A-Z][A-Za-z]+){0,3}\s+Regulations?\s+\d{4})\b'; From = 'shape' })
    $pats.Add([pscustomobject]@{ Kind = 'field';     Rx = '\b([a-z][a-z ]{2,28}?(?:block|line|column|field|row|section)s?)\b';   From = 'shape' })
    return $pats.ToArray()
}

function Get-ProvLocators {
    <#  Every locator token in a string, strongest first. A quoted sentence in
        the locator is the strongest anchor there is - it names the line.  #>
    param([string] $Text, $Patterns)
    $out = New-Object System.Collections.Generic.List[object]
    $t = "$Text"
    if (-not $t.Trim()) { return $out.ToArray() }
    foreach ($m in [regex]::Matches($t, '[''\u2018\u201C"]([^''\u2019\u201D"]{12,400})[''\u2019\u201D"]')) {
        $out.Add([pscustomobject]@{ Kind = 'quote'; Text = $m.Groups[1].Value })
    }
    foreach ($p in @($Patterns)) {
        foreach ($m in [regex]::Matches($t, $p.Rx)) {
            $v = ($m.Value -replace '\s+', ' ').Trim()
            if (-not $v) { continue }
            $dup = $false
            foreach ($o in $out) { if ($o.Kind -eq $p.Kind -and $o.Text -eq $v) { $dup = $true; break } }
            if (-not $dup) { $out.Add([pscustomobject]@{ Kind = $p.Kind; Text = $v }) }
        }
    }
    return $out.ToArray()
}

#  Five hundred rows over a four-document corpus means the same anchor is
#  looked up hundreds of times. Both caches are keyed on the anchor text, not
#  on the row, so they are correct for any caller and the gate stays quick.
$script:AnchorDocCache = @{}
$script:RegionCache    = @{}
#  Guide-side label -> the form the source document uses for the same item.
#  Filled per run from the contract; empty means "search the locator as
#  written", which is correct for a build that declares no convention.
$script:LabelForms     = @{}

function Resolve-ProvNamedDocs {
    <#  Which corpus documents the locator names. THREE routes, all derived:

          1. the reference-convention alias map - "Workbook Task 5(b)" is a
             reference to a document the contract itself names;
          2. the locator's free text against the corpus document names;
          3. the locator's own strong anchors - a recipe number, an appendix,
             a standard, an Act, a quoted line - found IN a document.

        Route 3 is not a nicety. A locator that reads "Recipe card 2094,
        storage block" names a document that exists only INSIDE another
        document; without it every recipe-sourced row in a pack of this shape
        would report SOURCE-ABSENT, and a gate whose commonest result is an
        excuse is a gate nobody reads.  #>
    param([string] $Locator, $Docs, $Alias, $Patterns)
    $named = New-Object System.Collections.Generic.List[object]
    $why = New-Object System.Collections.Generic.List[string]
    $route = 'none'
    $low = (ConvertTo-ProvFold $Locator).ToLowerInvariant()
    foreach ($k in @($Alias.Keys)) {
        if ($low.Contains($k)) {
            $dn = $Alias[$k]
            foreach ($d in @($Docs)) {
                if ($d.Name -eq $dn -and -not ($named -contains $d)) { $named.Add($d); $why.Add(("'{0}' -> {1} (reference convention)" -f $k, $d.Name)); $route = 'convention' }
            }
        }
    }
    if ($named.Count -eq 0) {
        $d = Resolve-ProvDocByName -Hint $Locator -Docs $Docs
        if ($null -ne $d) { $named.Add($d); $why.Add(("document name match -> {0}" -f $d.Name)); $route = 'name' }
    }
    if ($named.Count -eq 0 -and $null -ne $Patterns) {
        $strong = @('quote', 'recipe', 'appendix', 'evidence', 'standard', 'act', 'regs', 'clause')
        foreach ($l in @(Get-ProvLocators -Text $Locator -Patterns $Patterns)) {
            if ($strong -notcontains $l.Kind) { continue }
            $key = $l.Kind + '|' + $l.Text
            if (-not $script:AnchorDocCache.ContainsKey($key)) {
                $found = New-Object System.Collections.Generic.List[string]
                $rx = Get-ProvLooseRegex -Value $l.Text
                if ($rx) {
                    foreach ($d in @($Docs)) {
                        if ([regex]::IsMatch($d.Text, $rx, 'IgnoreCase')) { $found.Add($d.Name) }
                    }
                }
                $script:AnchorDocCache[$key] = $found.ToArray()
            }
            foreach ($dn in @($script:AnchorDocCache[$key])) {
                foreach ($d in @($Docs)) {
                    if ($d.Name -eq $dn -and -not ($named -contains $d)) { $named.Add($d); $why.Add(("anchor '{0}' found in {1}" -f $l.Text, $d.Name)) }
                }
            }
            if ($named.Count -gt 0) {
                #  A document matched by a CITATION carries a mention of the
                #  instrument, not the instrument. The caller has to be able to
                #  tell those apart, or it will report a clause of an
                #  unextracted Code as a figure the build invented.
                if (@('standard', 'act', 'regs', 'clause') -contains $l.Kind) { $route = 'citation' } else { $route = 'anchor' }
                break
            }
        }
    }
    #  Learner-facing first, so an equally good hit is quoted from the document
    #  a learner holds rather than from the assessor guide beside it.
    $ordered = @(@($named | Where-Object { $_.Audience -ne 'assessor' }) + @($named | Where-Object { $_.Audience -eq 'assessor' }))
    return [pscustomobject]@{ Docs = @($ordered); Why = ($why -join '; '); Route = $route }
}

function Find-ProvAnchorRegion {
    <#  Where inside a document the locator points. Returns the character
        ranges the locator's own anchors open. Empty means the locator named
        no anchor this document carries, in which case the WHOLE document is
        the region - a locator that says "every recipe card storage block" is
        not a stale locator, it is a coarse one.  #>
    param($Doc, $Locators)
    $regions = New-Object System.Collections.Generic.List[object]
    foreach ($l in @($Locators)) {
        #  @($null).Count is 1, so an EMPTY locator list arrives here as one
        #  $null element. Guarded and not assumed: without this the loop calls
        #  a method on nothing and the whole gate dies in the middle of a run,
        #  which is how this gate first came back with an exception instead of
        #  a report.
        if ($null -eq $l -or -not "$($l.Text)".Trim()) { continue }
        #  THE SAME PLACE, WRITTEN THREE WAYS, MOST SPECIFIC FIRST.
        #    "Workbook Task 5(b)"  - as the guide writes it
        #    "Task 5(b)"           - as the contract says the document writes it
        #    "Task 5"              - as the document ACTUALLY writes it, because
        #                            a tool prints the task as a heading and its
        #                            parts as (a), (b), (c) on their own lines,
        #                            so the two never appear as one string.
        #  The first form that lands wins, so a coarse fallback can never widen
        #  a region a precise anchor has already fixed.
        $texts = New-Object System.Collections.Generic.List[string]
        $texts.Add($l.Text)
        foreach ($lab in @($script:LabelForms.Keys)) {
            if ($l.Text.ToLowerInvariant().StartsWith($lab)) {
                $texts.Add(($script:LabelForms[$lab] + $l.Text.Substring($lab.Length)))
            }
        }
        if ($l.Kind -eq 'question') {
            foreach ($t in @($texts.ToArray())) {
                $mm = [regex]::Match($t, '^(.*?)\s*\(\s*[a-z]\s*\)\s*$')
                if ($mm.Success -and $mm.Groups[1].Value.Trim()) { $texts.Add($mm.Groups[1].Value.Trim()) }
            }
        }
        foreach ($lt in @($texts | Select-Object -Unique)) {
            $key = $Doc.Name + '|' + $l.Kind + '|' + $lt
            if (-not $script:RegionCache.ContainsKey($key)) {
                $found = New-Object System.Collections.Generic.List[object]
                $rx = Get-ProvLooseRegex -Value $lt
                if ($rx) {
                    $n = 0
                    foreach ($m in [regex]::Matches($Doc.Text, $rx, 'IgnoreCase')) {
                        $from = $m.Index - $script:AnchorBack
                        if ($from -lt 0) { $from = 0 }
                        $to = $m.Index + $m.Length + $script:AnchorFwd
                        if ($to -gt $Doc.Text.Length) { $to = $Doc.Text.Length }
                        $found.Add([pscustomobject]@{ Kind = $l.Kind; Anchor = $lt; From = $from; To = $to; At = $m.Index })
                        $n++
                        if ($n -ge 12) { break }
                    }
                }
                $script:RegionCache[$key] = $found.ToArray()
            }
            $hit = @($script:RegionCache[$key])
            if ($hit.Count -gt 0) {
                foreach ($r in $hit) { $regions.Add($r) }
                break
            }
        }
    }
    return $regions.ToArray()
}

function Test-ProvInRegion {
    param([int] $Offset, $Regions)
    foreach ($r in @($Regions)) { if ($Offset -ge $r.From -and $Offset -le $r.To) { return $true } }
    return $false
}

# ===========================================================================
# 6. Arm 1 - the provenance rows
# ===========================================================================

function Get-ProvClassTokens {
    param([string] $Authority, $Classes)
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($m in [regex]::Matches("$Authority", '(?<![A-Za-z])([A-Z])(?![A-Za-z])')) {
        $c = $m.Groups[1].Value
        if (($Classes -contains $c) -and -not $out.Contains($c)) { $out.Add($c) }
    }
    return $out.ToArray()
}

function Get-ProvRows {
    <#  Every provenance row this build carries, from BOTH registers: the
        figure registry, and each sub-section's own provenance block. They
        carry the same three fields and the auditor rebuilds both by hand.  #>
    param([string] $ForBuildDir, [string] $ForSpineDir, [string] $ForRulesPath, $Classes)
    $rows = New-Object System.Collections.Generic.List[object]

    $registry = $null
    $regFile = $ForRulesPath
    if (-not $regFile) { $regFile = Join-Path $ForBuildDir 'figures.json' }
    if (Test-Path -LiteralPath $regFile) { $registry = Get-GateJson -Path $regFile }
    if ($null -ne $registry) {
        $fi = 0
        foreach ($f in @($registry.figures)) {
            if ($null -eq $f) { $fi++; continue }
            $auth = "$(Get-GateProp -Object $f -Names @('authority', 'class', 'authorityClass') -Default '')"
            $src  = "$(Get-GateProp -Object $f -Names @('source', 'provenance', 'locator') -Default '')"
            $name = "$(Get-GateProp -Object $f -Names @('name', 'figure', 'id') -Default ('figures[' + $fi + ']'))"
            $req  = @(Get-GateProp -Object $f -Names @('require', 'value', 'values') -Default @())
            if ($req.Count -eq 0) {
                $rows.Add([pscustomobject]@{
                    Register = 'figures.json'; File = (Split-Path $regFile -Leaf); Field = ("figures[{0}]" -f $fi)
                    Name = $name; Value = ''; Authority = $auth; Classes = (Get-ProvClassTokens -Authority $auth -Classes $Classes); Locator = $src
                })
            }
            else {
                $vi = 0
                foreach ($v in $req) {
                    $rows.Add([pscustomobject]@{
                        Register = 'figures.json'; File = (Split-Path $regFile -Leaf); Field = ("figures[{0}].require[{1}]" -f $fi, $vi)
                        Name = $name; Value = "$v"; Authority = $auth; Classes = (Get-ProvClassTokens -Authority $auth -Classes $Classes); Locator = $src
                    })
                    $vi++
                }
            }
            $fi++
        }
    }

    foreach ($sf in (Get-GateSpineFiles -BuildDir $ForBuildDir -SpineDir $ForSpineDir -Exclude @())) {
        $j = Get-GateJson -Path $sf.FullName
        if ($null -eq $j) { continue }
        if (@($j.PSObject.Properties.Name) -notcontains 'provenance') { continue }
        $pi = 0
        foreach ($p in @($j.provenance)) {
            if ($null -eq $p -or $p -is [string]) { $pi++; continue }
            $auth = "$(Get-GateProp -Object $p -Names @('class', 'authority', 'authorityClass') -Default '')"
            $rows.Add([pscustomobject]@{
                Register  = 'spine provenance'
                File      = $sf.Name
                Field     = ("provenance[{0}]" -f $pi)
                Name      = "$(Get-GateProp -Object $p -Names @('figure', 'name', 'claim') -Default '')"
                Value     = "$(Get-GateProp -Object $p -Names @('value', 'figure') -Default '')"
                Authority = $auth
                Classes   = (Get-ProvClassTokens -Authority $auth -Classes $Classes)
                Locator   = "$(Get-GateProp -Object $p -Names @('source', 'locator', 'provenance') -Default '')"
                Mandatory = (Get-GateProp -Object $p -Names @('mandatory', 'isMandatory'))
            })
            $pi++
        }
    }
    return $rows.ToArray()
}

function Test-ProvRow {
    param($Row, $Ctx)

    $rec = [ordered]@{
        arm         = 'registry'
        register    = $Row.Register
        file        = $Row.File
        field       = $Row.Field
        claim       = $Row.Name
        value       = $Row.Value
        authority   = $Row.Authority
        class       = @($Row.Classes)
        locator     = $Row.Locator
        namedSource = @()
        anchors     = @()
        parts          = @(Get-ProvQuantity -Text $Row.Value)
        partsResolved  = @()
        partsMissing   = @()
        disposition = 'NO-CLAIM'
        kind        = ''
        note        = ''
        evidence    = @()
        blocking    = $false
    }

    if (@($Row.Classes).Count -eq 0) {
        $rec.note = ("authority '{0}' names no class from the closed enum ({1}); the row is checked for its value, but nothing class-specific can be said about it." -f $Row.Authority, ($Ctx.Classes -join ' '))
    }

    if (-not "$($Row.Value)".Trim()) {
        $rec.disposition = 'NO-CLAIM'
        if (-not $rec.note) { $rec.note = 'the row carries no canonical value, so there is nothing to resolve. It is a note, not a figure.' }
        return $rec
    }

    if (-not "$($Row.Locator)".Trim()) {
        $rec.disposition = 'UNRESOLVED'
        $rec.kind = 'no-locator'
        $rec.blocking = $true
        $rec.note = 'the row names a value and no source at all. A figure with no provenance locator is a figure nobody can check.'
        return $rec
    }

    $named = Resolve-ProvNamedDocs -Locator $Row.Locator -Docs $Ctx.Docs -Alias $Ctx.Alias -Patterns $Ctx.Patterns
    $rec.namedSource = @($named.Docs | ForEach-Object { $_.Name })
    $locs = Get-ProvLocators -Text $Row.Locator -Patterns $Ctx.Patterns
    $rec.anchors = @($locs | ForEach-Object { ('{0}:{1}' -f $_.Kind, (Get-ProvSnippet $_.Text 60)) })

    $hitsNamed = New-Object System.Collections.Generic.List[object]
    $atLocator = New-Object System.Collections.Generic.List[object]
    $anchored = $false
    $regionsBy = @{}
    foreach ($d in @($named.Docs)) {
        $regions = Find-ProvAnchorRegion -Doc $d -Locators $locs
        $regionsBy[$d.Name] = $regions
        if (@($regions).Count -gt 0) { $anchored = $true }
        foreach ($h in @(Find-ProvValue -Value $Row.Value -Docs @($d) -Max $script:MaxEvidence)) {
            $hitsNamed.Add($h)
            if (@($regions).Count -eq 0 -or (Test-ProvInRegion -Offset $h.Offset -Regions $regions)) { $atLocator.Add($h) }
        }
    }

    $others = @($Ctx.Docs | Where-Object { @($rec.namedSource) -notcontains $_.Name })
    $hitsOther = @()
    if ($atLocator.Count -eq 0) { $hitsOther = @(Find-ProvValue -Value $Row.Value -Docs $others -Max $script:MaxEvidence) }

    $exactAt = @($atLocator | Where-Object { $_.Arm -eq 'exact' })

    if ($exactAt.Count -gt 0) {
        $rec.disposition = 'RESOLVED'
        $rec.kind = 'verbatim-at-locator'
        $rec.evidence = @($exactAt | Select-Object -First $script:MaxEvidence)
        $rec.note = ("verbatim in {0} at line {1}{2}" -f $exactAt[0].Doc, $exactAt[0].Line, $(if ($anchored) { ', inside the region the locator names' } else { ', locator names no line anchor this document carries so the whole document is the region' }))
    }
    elseif ($atLocator.Count -gt 0) {
        $rec.disposition = 'NEAR-MISS'
        $rec.kind = 'not-verbatim'
        $rec.evidence = @($atLocator | Select-Object -First $script:MaxEvidence)
        $rec.note = ("the value is at the locator but NOT verbatim - matched on the {0} arm. Same number, different wording or a different unit. Adjudicate: correct the registry value or the source line." -f $atLocator[0].Arm)
    }
    elseif ($hitsNamed.Count -gt 0) {
        $rec.disposition = 'NEAR-MISS'
        $rec.kind = 'stale-locator'
        $rec.evidence = @($hitsNamed | Select-Object -First $script:MaxEvidence)
        $rec.note = ("the value IS in the named document, at line {0}, but not where the locator points ({1}). That is the shape of a stale locator, not of a fabricated figure - fix the locator." -f $hitsNamed[0].Line, ($rec.anchors -join ', '))
    }
    elseif (@($named.Docs).Count -eq 0) {
        $rec.disposition = 'SOURCE-ABSENT'
        $rec.kind = 'source-not-in-corpus'
        $anywhere = @(Find-ProvValue -Value $Row.Value -Docs $Ctx.Docs -Max $script:MaxEvidence)
        if ($anywhere.Count -eq 0) {
            foreach ($q in @($rec.parts)) {
                foreach ($h in @(Find-ProvValue -Value $q -Docs $Ctx.Docs -Max 2)) { $anywhere += $h }
            }
        }
        $rec.evidence = @($anywhere | Select-Object -First $script:MaxEvidence)
        if ($anywhere.Count -gt 0) {
            $rec.note = ("no corpus document answers to '{0}'. The value, or a quantity inside it, does occur in {1}. The fix may be to ADD the source or to correct the locator, not to cut the figure." -f (Get-ProvSnippet $Row.Locator 90), $anywhere[0].Doc)
        }
        else {
            $rec.kind = 'source-absent-and-value-absent'
            $rec.note = ("no corpus document answers to '{0}', AND no variant of the value or of any quantity inside it occurs in any source. This is the shape a fabricated figure takes when it hides behind an uncheckable citation. Add the source and re-run, or strike the figure." -f (Get-ProvSnippet $Row.Locator 90))
        }
    }
    else {
        #  THE COMPOSED VALUE. A registry row rarely quotes a source sentence:
        #  it states the figure in the build's own words - "50 portions of 350
        #  Gms, 5 buckets of 3.5 L, 17.5 L in total". Grepping THAT sentence
        #  and calling its absence a fabrication is precisely the false HIGH
        #  this gate was written to stop; the first run of this gate produced
        #  216 of them before the value was decomposed. So the VERBATIM test
        #  runs on the QUANTITIES inside the value, which is what section 18
        #  means by a verbatim quantity, and the sentence around them is a
        #  paraphrase, which section 18 says is tested by content word and
        #  REPORTED rather than failed.
        $partHitsAt = New-Object System.Collections.Generic.List[object]
        $partHitsNamed = New-Object System.Collections.Generic.List[object]
        $resolvedParts = New-Object System.Collections.Generic.List[string]
        $missingParts = New-Object System.Collections.Generic.List[string]
        foreach ($q in @($rec.parts)) {
            $hitAt = $false; $hitIn = $false
            foreach ($d in @($named.Docs)) {
                $reg = $regionsBy[$d.Name]
                foreach ($h in @(Find-ProvValue -Value $q -Docs @($d) -Max 3)) {
                    $hitIn = $true
                    $partHitsNamed.Add($h)
                    if (@($reg).Count -eq 0 -or (Test-ProvInRegion -Offset $h.Offset -Regions $reg)) { $hitAt = $true; $partHitsAt.Add($h) }
                }
            }
            if ($hitIn) { $resolvedParts.Add($q) } else { $missingParts.Add($q) }
        }
        $rec.partsResolved = $resolvedParts.ToArray()
        $rec.partsMissing = $missingParts.ToArray()

        $allPartsExactAt = ($rec.parts.Count -gt 0 -and $missingParts.Count -eq 0 -and @($partHitsAt | Where-Object { $_.Arm -eq 'exact' }).Count -ge $rec.parts.Count)

        if ($allPartsExactAt) {
            $rec.disposition = 'RESOLVED'
            $rec.kind = 'quantities-verbatim-at-locator'
            $rec.evidence = @($partHitsAt | Where-Object { $_.Arm -eq 'exact' } | Select-Object -First $script:MaxEvidence)
            $rec.note = ("every quantity in this row resolves verbatim at the locator ({0}); the wording around them is the build's own." -f (($rec.parts) -join ', '))
        }
        elseif ($resolvedParts.Count -gt 0) {
            $rec.disposition = 'NEAR-MISS'
            $rec.kind = 'composed-value'
            #  .ToArray() and not @(): adding two @()-wrapped List[object]s
            #  throws "Argument types do not match" in PS 5.1, which is how a
            #  clean-looking gate came back with an error instead of a report.
            $rec.evidence = @(($partHitsAt.ToArray() + $partHitsNamed.ToArray()) | Select-Object -First $script:MaxEvidence)
            $rec.note = ("the row's own sentence is not in the source, but {0} of its {1} quantities are: resolved [{2}]{3}. Adjudicate the wording, not the figure." -f $resolvedParts.Count, $rec.parts.Count, ($resolvedParts -join ', '), $(if ($missingParts.Count -gt 0) { '; NOT FOUND [' + ($missingParts -join ', ') + ']' } else { '' }))
        }
        else {
            #  NOTHING RESOLVED IN THE NAMED DOCUMENT. Before this is allowed
            #  to be called an absence, the SAME decomposition is run over the
            #  whole corpus. On the first real run this branch called the probe
            #  tolerance fabricated while the pack carried it, verbatim, in a
            #  document the locator simply did not name. A value in the wrong
            #  document is a stale locator; only a value in NO document is a
            #  fabricated figure, and the two need opposite fixes.
            $elsewhere = New-Object System.Collections.Generic.List[object]
            foreach ($h in @($hitsOther)) { $elsewhere.Add($h) }
            foreach ($q in @($rec.parts)) {
                if ($elsewhere.Count -ge $script:MaxEvidence) { break }
                foreach ($h in @(Find-ProvValue -Value $q -Docs $others -Max 2)) { $elsewhere.Add($h) }
            }
            $words = @()
            if ($rec.parts.Count -eq 0) {
                #  A paraphrase with no quantity in it. Section 18: a paraphrase
                #  needs at least one distinctive content word present in the
                #  source, and the result is REPORTED, not failed.
                $words = @(Get-ProvDistinctWord -Value $Row.Value)
                $found = New-Object System.Collections.Generic.List[object]
                foreach ($w in $words) {
                    foreach ($h in @(Find-ProvValue -Value $w -Docs $named.Docs -Max 1)) { $found.Add($h) }
                    if ($found.Count -ge 2) { break }
                }
                if ($found.Count -gt 0) {
                    $rec.disposition = 'NEAR-MISS'
                    $rec.kind = 'paraphrase'
                    $rec.evidence = @($found.ToArray() | Select-Object -First $script:MaxEvidence)
                    $rec.note = ("the row states a proposition, not a quantity. It is not in the named source word for word, but its distinctive content words are ({0}). Whether the source supports the proposition is a reader's call - this gate has named the line." -f (($words | Select-Object -First 4) -join ', '))
                    return $rec
                }
                foreach ($w in $words) {
                    foreach ($h in @(Find-ProvValue -Value $w -Docs $others -Max 1)) { $elsewhere.Add($h) }
                    if ($elsewhere.Count -ge 2) { break }
                }
            }

            if ($elsewhere.Count -gt 0) {
                $rec.disposition = 'NEAR-MISS'
                $rec.kind = 'wrong-document'
                $rec.evidence = @($elsewhere.ToArray() | Select-Object -First $script:MaxEvidence)
                $rec.note = ("nothing of this row resolves in the named document(s) [{0}], but it does resolve in {1} at line {2}. The locator names the wrong document - that is a stale locator, not a fabricated figure." -f ($rec.namedSource -join ', '), $elsewhere[0].Doc, $elsewhere[0].Line)
            }
            elseif ($named.Route -eq 'citation') {
                #  The corpus CITES the instrument; it does not contain it. A
                #  clause of a Code nobody extracted cannot be proved here, and
                #  calling that a fabrication is the defect this gate exists to
                #  stop. Extract the instrument under -PackDir and re-run.
                $rec.disposition = 'SOURCE-ABSENT'
                $rec.kind = 'instrument-cited-but-not-extracted'
                $rec.note = ("the locator cites '{0}'. The corpus MENTIONS that instrument but does not contain it - the document(s) matched [{1}] were found by the citation, not by name - and neither the value nor any quantity inside it occurs anywhere. Add the instrument's text under -PackDir and re-run before treating this as an invention." -f (Get-ProvSnippet $Row.Locator 90), ($rec.namedSource -join ', '))
            }
            else {
                $rec.disposition = 'UNRESOLVED'
                $rec.kind = 'absent'
                $rec.blocking = $true
                $rec.note = ("neither this value{0} occurs in the named source [{1}] or anywhere else in {2} source document(s). The named source IS in the corpus, so this is an absence, not an uncheckable citation." -f $(if ($rec.parts.Count -gt 0) { ' nor ANY of the quantities inside it (' + (($rec.parts) -join ', ') + ')' } elseif ($words.Count -gt 0) { ' nor ANY of its distinctive content words (' + ((@($words) | Select-Object -First 6) -join ', ') + ')' } else { '' }), ($rec.namedSource -join ', '), @($Ctx.Docs).Count)
            }
        }
    }
    return $rec
}

function Test-ProvLegalRow {
    <#  Class L: does the locator cite an instrument at all, and does the cited
        text present in the corpus MANDATE the value or merely RECOMMEND it?

        The conflict arm is narrow ON PURPOSE. It fires only when both halves
        are quotable - the guide's own prose applies a mandating verb to the
        cited instrument, and the corpus's own text for that instrument carries
        a recommending modal and no mandating one. A wider test on a document
        that teaches law in every paragraph would fire on correct teaching, and
        a rule that fires on correct content trains its reader to ignore it.  #>
    param($Row, $Rec, $Ctx)

    $out = [ordered]@{
        citation      = ''
        sourceStance  = 'INDETERMINATE'
        stanceLine    = ''
        guideStance   = 'NONE'
        guideLine     = ''
        guideAt       = ''
        conflict      = $false
    }
    $cite = ''
    foreach ($k in @('standard', 'act', 'regs', 'clause')) {
        foreach ($l in @(Get-ProvLocators -Text $Row.Locator -Patterns $Ctx.Patterns)) {
            if ($l.Kind -eq $k) { $cite = $l.Text; break }
        }
        if ($cite) { break }
    }
    if (-not $cite -and "$($Row.Locator)" -match '(?i)\b(code|legislation|regulation|act|standard)\b') {
        #  Names a body of law with no identifier. That is the defect the class
        #  claims to protect against, and it is reported, not failed.
        $out.citation = ''
    }
    $out.citation = $cite

    if ($cite) {
        $crx = Get-ProvLooseRegex -Value $cite
        $vrx = Get-ProvVariantRegex -Value $Row.Value
        foreach ($d in @($Ctx.Docs)) {
            if (-not $crx) { break }
            foreach ($m in [regex]::Matches($d.Text, $crx, 'IgnoreCase')) {
                $from = $m.Index - 200; if ($from -lt 0) { $from = 0 }
                $len = 900; if ($from + $len -gt $d.Text.Length) { $len = $d.Text.Length - $from }
                $block = $d.Text.Substring($from, $len)
                if ($vrx -and -not [regex]::IsMatch($block, $vrx, 'IgnoreCase')) { continue }
                $mand = $false; $rec2 = $false
                foreach ($w in $script:MandateWords)   { if ([regex]::IsMatch($block, ('\b' + [regex]::Escape($w) + '\b'), 'IgnoreCase')) { $mand = $true; break } }
                foreach ($w in $script:RecommendWords) { if ([regex]::IsMatch($block, ('\b' + [regex]::Escape($w) + '\b'), 'IgnoreCase')) { $rec2 = $true; break } }
                if ($rec2 -and -not $mand) {
                    $out.sourceStance = 'RECOMMENDS'
                    $ln = Get-ProvLineAt -Doc $d -Offset $m.Index
                    $out.stanceLine = ('{0} line {1}: {2}' -f $d.Name, $ln, (Get-ProvSafeQuote -Doc $d -Line $ln))
                    break
                }
                if ($mand) {
                    $out.sourceStance = 'MANDATES'
                    $ln = Get-ProvLineAt -Doc $d -Offset $m.Index
                    $out.stanceLine = ('{0} line {1}: {2}' -f $d.Name, $ln, (Get-ProvSafeQuote -Doc $d -Line $ln))
                    break
                }
            }
            if ($out.sourceStance -ne 'INDETERMINATE') { break }
        }
    }

    #  What the guide itself says about it.
    if ($cite) {
        $crx = Get-ProvLooseRegex -Value $cite
        $vrx = Get-ProvVariantRegex -Value $Row.Value
        foreach ($c in @($Ctx.Cells)) {
            if (-not $crx -or -not $vrx) { break }
            if (-not [regex]::IsMatch($c.Text, $crx, 'IgnoreCase')) { continue }
            if (-not [regex]::IsMatch($c.Text, $vrx, 'IgnoreCase')) { continue }
            $mand = $false
            foreach ($w in $script:MandateWords) { if ([regex]::IsMatch($c.Text, ('\b' + [regex]::Escape($w) + '\b'), 'IgnoreCase')) { $mand = $true; break } }
            if ($mand) {
                $out.guideStance = 'ASSERTS-REQUIREMENT'
                $out.guideLine = (Get-ProvSnippet $c.Text 240)
                $out.guideAt = ('{0} {1}' -f $c.File, $c.Path)
                break
            }
        }
    }
    if ($out.sourceStance -eq 'RECOMMENDS' -and $out.guideStance -eq 'ASSERTS-REQUIREMENT') { $out.conflict = $true }
    return $out
}

function Test-ProvVenueRow {
    <#  Class V: is the figure accompanied on the page by the statement that it
        is the venue's own procedure? Reports the sub-section files that carry
        the figure without one. Rule 4 - it names the anchor and stops.  #>
    param($Row, $Ctx)
    $vrx = Get-ProvExactRegex -Value $Row.Value
    if (-not $vrx) { return $null }
    $files = @{}
    foreach ($c in @($Ctx.Cells)) {
        if (-not [regex]::IsMatch($c.Text, $vrx, 'IgnoreCase')) { continue }
        if (-not $files.ContainsKey($c.File)) { $files[$c.File] = $c.Path }
    }
    if ($files.Count -eq 0) { return [pscustomobject]@{ OnPage = $false; Missing = @(); Statement = '' } }
    $missing = New-Object System.Collections.Generic.List[string]
    $stmt = ''
    foreach ($fn in @($files.Keys)) {
        $found = $false
        foreach ($c in @($Ctx.Cells)) {
            if ($c.File -ne $fn) { continue }
            $hasPhrase = $false
            foreach ($p in $script:VenuePhrases) { if ($c.Fold.Contains($p)) { $hasPhrase = $true; break } }
            if (-not $hasPhrase) { continue }
            $hasVenue = ($Ctx.VenueTokens.Count -eq 0)
            foreach ($v in @($Ctx.VenueTokens)) { if ($c.Fold.Contains($v)) { $hasVenue = $true; break } }
            if ($hasPhrase -and $hasVenue) { $found = $true; if (-not $stmt) { $stmt = ('{0} {1}: {2}' -f $c.File, $c.Path, (Get-ProvSnippet $c.Text 200)) }; break }
        }
        if (-not $found) { $missing.Add($fn) }
    }
    return [pscustomobject]@{ OnPage = $true; Missing = $missing.ToArray(); Statement = $stmt }
}

# ===========================================================================
# 7. Arm 2 - attributed sentences
# ===========================================================================

function Split-ProvSentence {
    param([string] $Text)
    $t = ConvertTo-ProvFold $Text
    if (-not $t) { return @() }
    return @([regex]::Split($t, '(?<=[.!?])\s+(?=[A-Z0-9"\u201C])') | Where-Object { "$_".Trim() })
}

function Get-ProvAttributions {
    <#  [source noun] + [reporting verb] + [quantity], in that order and close
        enough together to be one construction. Order and proximity are the
        false-positive control: without them every sentence that mentions a
        document and contains a number is an attribution, and it is not.  #>
    param($Cells, $Nouns, $VerbRx)
    $out = New-Object System.Collections.Generic.List[object]
    $nounList = @($Nouns.Keys)
    foreach ($c in @($Cells)) {
        if (-not [regex]::IsMatch($c.Fold, $VerbRx)) { continue }
        foreach ($s in (Split-ProvSentence $c.Text)) {
            $sf = $s.ToLowerInvariant()
            $vm = [regex]::Match($sf, $VerbRx)
            if (-not $vm.Success) { continue }
            $noun = ''; $nounAt = -1; $nounLen = 0
            foreach ($n in $nounList) {
                $idx = $sf.IndexOf($n)
                while ($idx -ge 0) {
                    $gap = $vm.Index - ($idx + $n.Length)
                    if ($gap -ge 0 -and $gap -le $script:VerbGap) {
                        if ($idx -gt $nounAt) { $noun = $n; $nounAt = $idx; $nounLen = $n.Length }
                        break
                    }
                    $idx = $sf.IndexOf($n, $idx + 1)
                }
            }
            #  A legal citation is a source noun in its own right, whatever the
            #  contract lists - "Standard 3.2.2A states..." attributes as
            #  surely as a document title does.
            if (-not $noun) {
                #  The WHOLE citation, and a NAMED one. "Model Practice
                #  Standard 9.9.9" has to reach the resolver intact, because
                #  "standard" on its own resolves to nothing; and the bare word
                #  must not be taken as a citation at all - "the house standard
                #  states 4 degrees C" is a venue figure, not a legal one, and
                #  treating it as one put 76 meaningless SOURCE-ABSENT rows in
                #  this gate's first real report. So a match must carry either a
                #  leading capitalised word or an identifier of its own.
                foreach ($m in [regex]::Matches($s, '(?:[A-Z][A-Za-z]*\s+){1,4}\b(?:Standards?|Acts?|Regulations?|Code)\b(?:\s+\d+(?:\.\d+)*[A-Z]?)?(?:\s+\d{4})?|\b(?:Standard|Act|Regulation)\s+\d+(?:\.\d+)*[A-Z]?\b')) {
                    $gap = $vm.Index - ($m.Index + $m.Length)
                    if ($gap -ge 0 -and $gap -le $script:VerbGap) { $noun = (ConvertTo-ProvFold $m.Value).ToLowerInvariant().Trim(); $nounAt = $m.Index; $nounLen = $m.Length; break }
                }
            }
            if (-not $noun) { continue }
            #  The noun AS WRITTEN goes to the resolver. The locator shapes for
            #  a standard, an Act and a regulation are capitalisation-sensitive
            #  on purpose - "the standard 5 degrees" is not a citation - so a
            #  lower-cased noun would resolve to nothing and every cited
            #  instrument would be reported as a source nobody extracted.
            $nounRaw = $noun
            if ($nounAt -ge 0 -and $nounLen -gt 0 -and ($nounAt + $nounLen) -le $s.Length) { $nounRaw = $s.Substring($nounAt, $nounLen) }
            $tail = ''
            $tailFrom = $vm.Index + $vm.Length
            if ($tailFrom -lt $s.Length) {
                $tlen = $script:QtyGap
                if ($tailFrom + $tlen -gt $s.Length) { $tlen = $s.Length - $tailFrom }
                $tail = $s.Substring($tailFrom, $tlen)
            }
            $qty = @(Get-ProvQuantity -Text $tail)
            $out.Add([pscustomobject]@{
                Cell = $c; Sentence = $s; Noun = $noun; NounRaw = $nounRaw; NounFrom = $Nouns[$noun]
                Verb = $vm.Value; Quantities = $qty
            })
        }
    }
    return $out.ToArray()
}

function Test-ProvAttribution {
    param($A, $Ctx)

    $rec = [ordered]@{
        arm         = 'attribution'
        register    = 'spine prose'
        file        = $A.Cell.File
        field       = $A.Cell.Path
        channel     = $A.Cell.Channel
        claim       = (Get-ProvSnippet $A.Sentence 300)
        value       = (@($A.Quantities) -join ' ; ')
        sourceNoun  = $A.Noun
        nounFrom    = $A.NounFrom
        verb        = $A.Verb
        class       = @()
        locator     = ''
        locatorIn   = ''
        namedSource = @()
        disposition = 'RESOLVED'
        kind        = ''
        note        = ''
        evidence    = @()
        blocking    = $false
    }

    $named = Resolve-ProvNamedDocs -Locator $A.NounRaw -Docs $Ctx.Docs -Alias $Ctx.Alias -Patterns $Ctx.Patterns
    $rec.namedSource = @($named.Docs | ForEach-Object { $_.Name })

    $locs = @(Get-ProvLocators -Text $A.Sentence -Patterns $Ctx.Patterns | Where-Object { $_.Kind -ne 'field' })
    $scope = 'sentence'
    if (@($locs).Count -eq 0) {
        $locs = @(Get-ProvLocators -Text $A.Cell.Text -Patterns $Ctx.Patterns | Where-Object { $_.Kind -ne 'field' })
        $scope = 'cell'
    }
    if (@($locs).Count -eq 0) { $scope = '' }
    $rec.locator = (@($locs | ForEach-Object { '{0}:{1}' -f $_.Kind, $_.Text }) -join ', ')
    $rec.locatorIn = $scope

    $hasQty = (@($A.Quantities).Count -gt 0)

    if (@($named.Docs).Count -eq 0) {
        $rec.disposition = 'SOURCE-ABSENT'
        $rec.kind = 'source-not-in-corpus'
        $rec.note = ("the sentence attributes to '{0}', which answers to no document in this corpus. Reported with the source name: the fix may be to add the source rather than to cut the sentence." -f $A.Noun)
        return $rec
    }

    #  Does the locator resolve inside the named source?
    $resolvedLoc = $null
    foreach ($d in @($named.Docs)) {
        $regions = Find-ProvAnchorRegion -Doc $d -Locators $locs
        if (@($regions).Count -gt 0) { $resolvedLoc = [pscustomobject]@{ Doc = $d; Regions = $regions }; break }
    }

    if (-not $hasQty) {
        #  A proposition, not a quantity. Reported, never blocking - the
        #  mechanical test on a proposition is weaker than the one on a number.
        if ($null -eq $resolvedLoc) {
            $rec.disposition = 'NEAR-MISS'
            $rec.kind = 'proposition-without-resolving-locator'
            $rec.note = ("an attributed proposition whose locator does not resolve in {0}. Reported for a reader: a proposition cannot be matched mechanically the way a quantity can." -f ($rec.namedSource -join ', '))
        }
        else {
            $rec.disposition = 'RESOLVED'
            $rec.kind = 'proposition-with-resolving-locator'
            $rec.note = ("locator resolves in {0}; the proposition itself is a reader's judgement." -f $resolvedLoc.Doc.Name)
        }
        return $rec
    }

    if (@($locs).Count -eq 0) {
        $rec.disposition = 'UNRESOLVED'
        $rec.kind = 'attributed-quantity-no-locator'
        $rec.blocking = $true
        $rec.note = ("the sentence attributes {0} to '{1}' and carries no locator at all, in the sentence or in its cell. Add the reference the reader would have to follow, or drop the attribution." -f $rec.value, $A.Noun)
        return $rec
    }

    if ($null -eq $resolvedLoc) {
        $anyQty = New-Object System.Collections.Generic.List[object]
        foreach ($q in @($A.Quantities)) { foreach ($h in @(Find-ProvValue -Value $q -Docs @($named.Docs) -Max 2)) { $anyQty.Add($h) } }
        if ($anyQty.Count -gt 0) {
            $rec.disposition = 'NEAR-MISS'
            $rec.kind = 'locator-does-not-resolve'
            $rec.evidence = @($anyQty | Select-Object -First $script:MaxEvidence)
            $rec.note = ("the quantity is in {0} at line {1}, but the locator '{2}' does not resolve in it. Stale locator, not a fabricated figure." -f $anyQty[0].Doc, $anyQty[0].Line, $rec.locator)
        }
        else {
            $rec.disposition = 'UNRESOLVED'
            $rec.kind = 'locator-and-quantity-absent'
            $rec.blocking = $true
            $rec.note = ("neither the locator '{0}' nor the quantity {1} occurs in the named source [{2}]." -f $rec.locator, $rec.value, ($rec.namedSource -join ', '))
        }
        return $rec
    }

    $best = $null
    foreach ($q in @($A.Quantities)) {
        foreach ($h in @(Find-ProvValue -Value $q -Docs @($resolvedLoc.Doc) -Max $script:MaxEvidence)) {
            $inRegion = Test-ProvInRegion -Offset $h.Offset -Regions $resolvedLoc.Regions
            $rank = 0
            if ($h.Arm -eq 'exact') { $rank += 2 } elseif ($h.Arm -eq 'loose') { $rank += 1 }
            if ($inRegion) { $rank += 4 }
            if ($null -eq $best -or $rank -gt $best.Rank) { $best = [pscustomobject]@{ Rank = $rank; Hit = $h; InRegion = $inRegion } }
        }
    }
    if ($null -eq $best) {
        $rec.disposition = 'UNRESOLVED'
        $rec.kind = 'quantity-absent-from-named-source'
        $rec.blocking = $true
        $rec.note = ("the locator resolves in {0}, but no variant of {1} occurs in that document. The sentence attributes a quantity its own named source does not carry." -f $resolvedLoc.Doc.Name, $rec.value)
        return $rec
    }
    $rec.evidence = @($best.Hit)
    if ($best.InRegion -and $best.Hit.Arm -eq 'exact') {
        $rec.disposition = 'RESOLVED'
        $rec.kind = 'verbatim-at-locator'
        $rec.note = ("{0} line {1}, verbatim, inside the region the locator names." -f $best.Hit.Doc, $best.Hit.Line)
    }
    else {
        $rec.disposition = 'NEAR-MISS'
        $rec.kind = $(if ($best.InRegion) { 'not-verbatim-at-locator' } else { 'quantity-away-from-locator' })
        $rec.note = ("{0} line {1} on the {2} arm{3}. Adjudicate the wording or the locator." -f $best.Hit.Doc, $best.Hit.Line, $best.Hit.Arm, $(if ($best.InRegion) { '' } else { ', outside the region the locator names' }))
    }
    return $rec
}

# ===========================================================================
# 8. The run
# ===========================================================================

function Invoke-Provenance {
    param([string] $RunBuildDir, [string] $RunSpineDir, [string] $RunCorpusDir, [string] $RunPackDir, [string] $RunRulesPath, [switch] $RunQuiet)

    #  Cleared per run. The caches key on a document NAME, and two builds in
    #  one process can carry the same document name over different text.
    $script:AnchorDocCache = @{}
    $script:RegionCache    = @{}
    $script:LabelForms     = @{}

    $contract = Get-GateContract -BuildDir $RunBuildDir
    $script:LabelForms = Get-ProvLabelForm -Contract $contract
    $classes  = Get-ProvAuthorityClasses -Contract $contract
    $sources  = Get-ProvSources -ForBuildDir $RunBuildDir -ForCorpusDir $RunCorpusDir -ForPackDir $RunPackDir
    if (@($sources.Docs).Count -eq 0) {
        throw ("{0}: no source documents. Provenance cannot be proved against nothing." -f $GATE)
    }
    $cells    = Get-ProvSpineCells -ForBuildDir $RunBuildDir -ForSpineDir $RunSpineDir
    $rows     = Get-ProvRows -ForBuildDir $RunBuildDir -ForSpineDir $RunSpineDir -ForRulesPath $RunRulesPath -Classes $classes
    $patterns = Get-ProvLocatorPatterns -Contract $contract
    $alias    = Get-ProvAliasMap -Contract $contract -Docs $sources.Docs
    $nouns    = Get-ProvSourceNouns -Contract $contract -Docs $sources.Docs -Rows $rows -Alias $alias
    $verbs    = Get-ProvReportingVerbs -Contract $contract
    $venue    = Get-ProvVenueTokens -Contract $contract

    $ctx = [pscustomobject]@{
        Docs = $sources.Docs; Cells = $cells; Alias = $alias; Patterns = $patterns
        Classes = $classes; VenueTokens = $venue
    }

    if (-not $RunQuiet) {
        Write-Host ''
        Write-Host 'PROVENANCE AND ATTRIBUTION - does the registration hold up' -ForegroundColor Cyan
        Write-Host '  Arm 1 opens the source each registry row names. Arm 2 reads every "the source says X" sentence.' -ForegroundColor DarkGray
        Write-GateCheckSet -What 'source document(s)' -Count @($sources.Docs).Count -DerivedFrom (('the canonical corpus' + $(if ($sources.CorpusDir) { ' at ' + (Split-Path $sources.CorpusDir -Leaf) } else { '' })) + ', unit_extract*.md' + $(if ($RunPackDir) { ', and -PackDir' } else { '' }))
        foreach ($d in @($sources.Docs)) { Write-Host ("    {0,-9} {1} ({2} lines)" -f $d.Audience, $d.Name, $d.Lines.Count) -ForegroundColor DarkGray }
        Write-GateCheckSet -What 'provenance row(s)' -Count @($rows).Count -DerivedFrom 'figures.json figures[] and every spine sub-section provenance[] block'
        Write-GateCheckSet -What 'spine cell(s)' -Count @($cells).Count -DerivedFrom 'the spine, minus the identifier and metadata fields Lib-GateCommon declares unrendered'
        Write-GateCheckSet -What 'source noun(s)' -Count @($nouns.Keys).Count -DerivedFrom 'the build contract source list, the corpus document names and the registry locators'
        Write-GateCheckSet -What 'reporting verb form(s)' -Count @($verbs.Forms).Count -DerivedFrom $verbs.DerivedFrom
        Write-Host ("  check-set: authority classes [{0}]; venue token(s) {1}; locator shape(s) {2}" -f ($classes -join ' '), @($venue).Count, @($patterns).Count) -ForegroundColor DarkGray
    }

    $records = New-Object System.Collections.Generic.List[object]
    $legal = New-Object System.Collections.Generic.List[object]
    $venueFindings = New-Object System.Collections.Generic.List[object]

    foreach ($row in @($rows)) {
        $rec = Test-ProvRow -Row $row -Ctx $ctx
        if (@($row.Classes) -contains 'L' -and "$($row.Value)".Trim()) {
            $lg = Test-ProvLegalRow -Row $row -Rec $rec -Ctx $ctx
            $rec.legal = $lg
            if ($lg.conflict) {
                $legal.Add([pscustomobject]@{ Row = $row; Rec = $rec; Legal = $lg })
            }
        }
        if (@($row.Classes) -contains 'V' -and "$($row.Value)".Trim()) {
            $v = Test-ProvVenueRow -Row $row -Ctx $ctx
            if ($null -ne $v) {
                $rec.venue = [ordered]@{ onPage = $v.OnPage; statement = $v.Statement; filesWithoutStatement = @($v.Missing) }
                if ($v.OnPage -and @($v.Missing).Count -gt 0) { $venueFindings.Add([pscustomobject]@{ Row = $row; Missing = @($v.Missing) }) }
            }
        }
        $records.Add([pscustomobject]$rec)
    }

    $verbRx = '(?i)\b(?:' + ((@($verbs.Forms) | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\b'
    $attrs = Get-ProvAttributions -Cells $cells -Nouns $nouns -VerbRx $verbRx
    $attrRecords = New-Object System.Collections.Generic.List[object]
    foreach ($a in @($attrs)) {
        $r = Test-ProvAttribution -A $a -Ctx $ctx
        #  A propositional attribution that resolves is not news. Keep the
        #  report to what a reader has to act on, and say so in the header.
        if ($r.kind -eq 'proposition-with-resolving-locator') { continue }
        $attrRecords.Add([pscustomobject]$r)
    }

    return [pscustomobject]@{
        Registry     = $records.ToArray()
        Attribution  = $attrRecords.ToArray()
        LegalConflict= $legal.ToArray()
        VenueFinding = $venueFindings.ToArray()
        Rows         = @($rows).Count
        Sentences    = @($attrs).Count
        Docs         = @($sources.Docs | ForEach-Object { $_.Name })
        CorpusDir    = $sources.CorpusDir
        Cells        = @($cells).Count
        Nouns        = @($nouns.Keys).Count
        Verbs        = $verbs
        Classes      = $classes
    }
}

function Write-ProvConsole {
    param($Run)
    $all = @($Run.Registry) + @($Run.Attribution)
    $byDisp = @{}
    foreach ($r in $all) {
        $k = $r.disposition
        if ($byDisp.ContainsKey($k)) { $byDisp[$k]++ } else { $byDisp[$k] = 1 }
    }
    Write-Host ''
    Write-Host ("  {0} record(s): {1}" -f $all.Count, ((@($byDisp.Keys) | Sort-Object | ForEach-Object { '{0} {1}' -f $byDisp[$_], $_ }) -join ', ')) -ForegroundColor DarkGray

    foreach ($grp in @(
        @{ Disp = 'UNRESOLVED';    Colour = 'Red';    Head = 'UNRESOLVED - the value is not in the source, and the source is in the corpus. BLOCKING.' },
        @{ Disp = 'NEAR-MISS';     Colour = 'Yellow'; Head = 'NEAR-MISS - reported for adjudication, never silently failed and never silently passed.' },
        @{ Disp = 'SOURCE-ABSENT'; Colour = 'Cyan';   Head = 'SOURCE-ABSENT - the named source is in no corpus document. Reported with the source name.' }
    )) {
        $rows = @($all | Where-Object { $_.disposition -eq $grp.Disp })
        if ($rows.Count -eq 0) { continue }
        Write-Host ''
        Write-Host ("  {0} ({1})" -f $grp.Head, $rows.Count) -ForegroundColor $grp.Colour
        $n = 0
        foreach ($r in $rows) {
            if ($n -ge $script:MaxConsole) {
                Write-Host ("    ... and {0} more in the report" -f ($rows.Count - $n)) -ForegroundColor DarkGray
                break
            }
            Write-Host ("    [{0}] {1} {2}" -f (@($r.class) -join ''), $r.file, $r.field) -ForegroundColor $grp.Colour
            Write-Host ("      claim   : {0}" -f (Get-ProvSnippet $r.claim 160)) -ForegroundColor Gray
            if ("$($r.value)".Trim()) { Write-Host ("      value   : {0}" -f $r.value) -ForegroundColor Gray }
            Write-Host ("      locator : {0}" -f (Get-ProvSnippet $r.locator 160)) -ForegroundColor Gray
            Write-Host ("      why     : {0}" -f (Get-ProvSnippet $r.note 300)) -ForegroundColor DarkGray
            foreach ($e in @($r.evidence | Select-Object -First 2)) {
                Write-Host ("      source  : {0} line {1} [{2}] {3}" -f $e.Doc, $e.Line, $e.Arm, $e.Text) -ForegroundColor DarkGray
            }
            $n++
        }
    }

    if (@($Run.LegalConflict).Count -gt 0) {
        Write-Host ''
        Write-Host ("  L-CLASS MANDATE CONFLICT ({0}) - a recommendation dressed as a legal requirement. BLOCKING." -f @($Run.LegalConflict).Count) -ForegroundColor Red
        foreach ($c in @($Run.LegalConflict)) {
            Write-Host ("    {0} {1} - {2}" -f $c.Row.File, $c.Row.Field, $c.Row.Name) -ForegroundColor Red
            Write-Host ("      value        : {0}" -f $c.Row.Value) -ForegroundColor Gray
            Write-Host ("      citation     : {0}" -f $c.Legal.citation) -ForegroundColor Gray
            Write-Host ("      the guide    : {0} :: {1}" -f $c.Legal.guideAt, (Get-ProvSnippet $c.Legal.guideLine 220)) -ForegroundColor Yellow
            Write-Host ("      cited text   : {0}" -f (Get-ProvSnippet $c.Legal.stanceLine 260)) -ForegroundColor Yellow
        }
    }

    $noCite = @($Run.Registry | Where-Object { @($_.class) -contains 'L' -and $null -ne $_.legal -and -not $_.legal.citation -and "$($_.value)".Trim() })
    if ($noCite.Count -gt 0) {
        Write-Host ''
        Write-Host ("  L-CLASS WITHOUT A CITATION ({0}) - the class asserts law and the locator names no instrument. Reported." -f $noCite.Count) -ForegroundColor Yellow
        foreach ($r in @($noCite | Select-Object -First $script:MaxConsole)) {
            Write-Host ("    {0} {1}: '{2}' cited to {3}" -f $r.file, $r.field, (Get-ProvSnippet $r.value 60), (Get-ProvSnippet $r.locator 110)) -ForegroundColor DarkGray
        }
        if ($noCite.Count -gt $script:MaxConsole) { Write-Host ("    ... and {0} more in the report" -f ($noCite.Count - $script:MaxConsole)) -ForegroundColor DarkGray }
    }

    if (@($Run.VenueFinding).Count -gt 0) {
        Write-Host ''
        Write-Host ("  V-CLASS WITHOUT THE VENUE STATEMENT ({0}) - the figure is on the page and the page does not say it is the venue's own. Reported." -f @($Run.VenueFinding).Count) -ForegroundColor Yellow
        foreach ($v in @($Run.VenueFinding | Select-Object -First $script:MaxConsole)) {
            Write-Host ("    '{0}' appears in {1} without it" -f (Get-ProvSnippet $v.Row.Value 60), (@($v.Missing) -join ', ')) -ForegroundColor DarkGray
        }
    }
}

function Write-ProvReport {
    param($Run, [string] $Path)
    $out = [ordered]@{
        gate = [ordered]@{
            script       = $GATE
            ranAt        = (Get-Date -Format 'o')
            corpusDir    = "$($Run.CorpusDir)"
            sources      = @($Run.Docs)
            spineCells   = $Run.Cells
            rows         = $Run.Rows
            sentences    = $Run.Sentences
            sourceNouns  = $Run.Nouns
            verbList     = @($Run.Verbs.Stems)
            verbListFrom = $Run.Verbs.DerivedFrom
            classes      = @($Run.Classes)
            dispositions = 'RESOLVED | NEAR-MISS | UNRESOLVED | SOURCE-ABSENT'
            rule         = 'A NEAR-MISS is reported for adjudication, never silently failed and never silently passed: a near miss is usually a stale locator and a true absence is usually a fabricated figure. A line from an assessor-only document is recorded by document and line number and its text is withheld.'
        }
        registry    = @($Run.Registry)
        attribution = @($Run.Attribution)
        legalConflict = @($Run.LegalConflict | ForEach-Object {
            [ordered]@{ file = $_.Row.File; field = $_.Row.Field; claim = $_.Row.Name; value = $_.Row.Value
                        citation = $_.Legal.citation; guideSays = $_.Legal.guideLine; guideAt = $_.Legal.guideAt
                        citedTextSays = $_.Legal.stanceLine; sourceStance = $_.Legal.sourceStance }
        })
        venueStatementMissing = @($Run.VenueFinding | ForEach-Object {
            [ordered]@{ file = $_.Row.File; field = $_.Row.Field; value = $_.Row.Value; filesWithoutStatement = @($_.Missing) }
        })
    }
    $json = $out | ConvertTo-Json -Depth 12
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

# ===========================================================================
# 9. Self-test - plant, PROVE THE PLANT LANDED, then require the gate to fire
# ===========================================================================

function New-ProvFixture {
    <#  A throwaway build carrying five planted defects. The filler is not
        decoration: the stale-locator plant only means something if the value
        sits further from the locator's anchor than the anchor window, so the
        fixture is padded and the distance is MEASURED before the gate runs.  #>
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('ap_selftest_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path (Join-Path $root 'corpus') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $root 'spine') | Out-Null
    $enc = New-Object System.Text.UTF8Encoding($false)

    $filler = New-Object System.Collections.Generic.List[string]
    for ($i = 1; $i -le 60; $i++) {
        $filler.Add(("Planning note {0}. The team checks the order form, the delivery docket and the storage plan before the run begins, and records what it finds." -f $i))
    }
    $wb = New-Object System.Collections.Generic.List[string]
    $wb.Add('Fixture Recipe Workbook. Cook-chill production.')
    $wb.Add('Task 1(a) Production planning. List the documents you read before the run starts.')
    foreach ($l in $filler) { $wb.Add($l) }
    $wb.Add('Task 4(b) Bench rest. The house rule for the bench rest is 25 minutes before the trays go to the chiller.')
    $wb.Add('Task 9(c) Packing. Each tray is filled to a depth of 40 mm before it goes to the blast chiller.')
    $wb.Add('Recipe card 4001, storage block: chill the cooked product to 6 degrees C or below within 90 minutes.')
    [System.IO.File]::WriteAllText((Join-Path $root 'corpus\Fixture_Recipe_Workbook.txt'), ($wb -join "`r`n"), $enc)

    $std = @(
        'Model Practice Standard 9.9.9 Cooling of cooked food.',
        'The standard recommends that cooked food is chilled to 6 degrees C or below within 90 minutes where that is practicable, and treats the figure as guidance for operators.',
        'Nothing in this clause creates an obligation on a food business to achieve that figure.'
    )
    [System.IO.File]::WriteAllText((Join-Path $root 'corpus\Fixture_Standards_Extract.txt'), ($std -join "`r`n"), $enc)

    $contract = [ordered]@{
        build = [ordered]@{ unitCode = 'FIXTURE001'; brand = 'FixtureCo'; variant = 'test' }
        unit  = [ordered]@{ code = 'FIXTURE001'; title = 'Produce fixture food' }
        referenceConvention = [ordered]@{
            workbook      = 'Workbook Task {n}({part})'
            workbookMeans = 'Task {n} in Fixture_Recipe_Workbook.docx'
        }
        scenario = [ordered]@{
            employer = 'FixtureCo Kitchen'
            venue    = 'the FixtureCo production kitchen'
            recipes  = @([ordered]@{ no = '4001'; name = 'Fixture curry' })
            workplaceDocuments = @('Fixture Recipe Workbook', 'Model Practice Standard 9.9.9', 'equipment manufacturer instructions')
        }
    }
    [System.IO.File]::WriteAllText((Join-Path $root 'contract.json'), ($contract | ConvertTo-Json -Depth 8), $enc)

    $figures = [ordered]@{
        figures = @(
            [ordered]@{ name = 'PLANT-OK bench rest'; authority = 'V'
                        source = 'Fixture Recipe Workbook, Task 4(b), the bench rest line'
                        require = @('25 minutes') },
            [ordered]@{ name = 'PLANT-ABSENT hold time'; authority = 'P'
                        source = 'Fixture Recipe Workbook, Task 1(a)'
                        require = @('77 minutes') },
            [ordered]@{ name = 'PLANT-STALE tray depth'; authority = 'P'
                        source = 'Fixture Recipe Workbook, Task 1(a)'
                        require = @('40 mm') },
            [ordered]@{ name = 'PLANT-MANDATE chill figure'; authority = 'L'
                        source = 'Model Practice Standard 9.9.9, Cooling of cooked food'
                        require = @('6 degrees C or below within 90 minutes') }
        )
    }
    [System.IO.File]::WriteAllText((Join-Path $root 'figures.json'), ($figures | ConvertTo-Json -Depth 8), $enc)

    $spine = [ordered]@{
        ref = '1.1'; pc = '1.1'; topic = 1; title = 'Fixture sub-section'
        underpinningKnowledge = @(
            'Model Practice Standard 9.9.9 requires the cooked product to be chilled to 6 degrees C or below within 90 minutes.',
            'The Fixture Recipe Workbook specifies 40 mm trays for every chilled component.',
            'Workbook Task 9(c) states that each tray is filled to a depth of 40 mm before it goes to the blast chiller.',
            'The house rule at the FixtureCo production kitchen is 25 minutes of bench rest, and that is our own procedure rather than a legal one.'
        )
    }
    [System.IO.File]::WriteAllText((Join-Path $root 'spine\t1_1.1.json'), ($spine | ConvertTo-Json -Depth 8), $enc)
    return $root
}

function Invoke-ProvSelfTest {
    $script:stPass = 0
    $script:stFail = 0
    $ok  = { param($m) $script:stPass++; Write-Host "  PASS  $m" -ForegroundColor Green }
    $bad = { param($m) $script:stFail++; Write-Host "  FAIL  $m" -ForegroundColor Red }

    Write-Host ''
    Write-Host "$GATE self-test" -ForegroundColor Cyan
    Write-Host '  Every plant is READ BACK in the exact channel this gate scans before the gate is run.' -ForegroundColor DarkGray
    Write-Host '  A plant that silently failed to apply once passed a gate on this project and proved nothing.' -ForegroundColor DarkGray

    $fixture = New-ProvFixture
    try {
        # ---- verify the plants landed, using this gate's own readers ----
        $src = Get-ProvSources -ForBuildDir $fixture -ForCorpusDir '' -ForPackDir ''
        $wbDoc  = @($src.Docs | Where-Object { $_.Name -match 'Recipe_Workbook' })[0]
        $stdDoc = @($src.Docs | Where-Object { $_.Name -match 'Standards_Extract' })[0]
        $cells  = Get-ProvSpineCells -ForBuildDir $fixture -ForSpineDir ''

        if ($null -ne $wbDoc -and $null -ne $stdDoc) { & $ok 'fixture corpus loaded: workbook and standards extract' }
        else { & $bad 'fixture corpus did NOT load' }

        # plant 1 - a value that is absent from every source
        $absent = @(Find-ProvValue -Value '77 minutes' -Docs $src.Docs -Max 2)
        if ($absent.Count -eq 0) { & $ok "plant 1 landed: '77 minutes' occurs in NO source document, so the row can only be UNRESOLVED" }
        else { & $bad ("plant 1 did NOT land: '77 minutes' occurs in {0}" -f $absent[0].Doc) }

        # plant 2 - the value is present, but further from the locator anchor than the window
        $anchorM = [regex]::Match($wbDoc.Text, '(?i)Task\s*1\(a\)')
        $valueM  = [regex]::Match($wbDoc.Text, '(?i)40\s*mm')
        if ($anchorM.Success -and $valueM.Success) {
            $gap = $valueM.Index - $anchorM.Index
            if ($gap -gt $script:AnchorFwd) { & $ok ("plant 2 landed: '40 mm' sits {0} characters past the 'Task 1(a)' anchor, beyond the {1} character window, so it can only be a stale locator" -f $gap, $script:AnchorFwd) }
            else { & $bad ("plant 2 did NOT land: the gap is only {0} characters, inside the window - the fixture filler is too short and the row would resolve" -f $gap) }
        }
        else { & $bad 'plant 2 did NOT land: the anchor or the value is missing from the fixture workbook' }

        # plant 3 - the cited text recommends, and the guide requires
        $recWord = [regex]::IsMatch($stdDoc.Text, '(?i)\brecommends\b')
        $noMand  = -not [regex]::IsMatch($stdDoc.Text, '(?i)\b(must|shall|requires|required|mandatory)\b')
        $guideReq = @($cells | Where-Object { $_.Text -match '(?i)Standard\s*9\.9\.9' -and $_.Text -match '(?i)\brequires\b' })
        if ($recWord -and $noMand) { & $ok 'plant 3a landed: the cited text recommends the figure and carries no mandating word' }
        else { & $bad ("plant 3a did NOT land: recommends={0} mandating-word-absent={1}" -f $recWord, $noMand) }
        if ($guideReq.Count -gt 0) { & $ok 'plant 3b landed: the spine asserts the same figure as a requirement of the same instrument' }
        else { & $bad 'plant 3b did NOT land: no spine cell asserts the standard as a requirement' }

        # plant 4 - an attributed quantity with no locator anywhere in its cell
        $contract = Get-GateContract -BuildDir $fixture
        $pats = Get-ProvLocatorPatterns -Contract $contract
        $noLoc = @($cells | Where-Object { $_.Text -match '(?i)Fixture Recipe Workbook specifies' })
        if ($noLoc.Count -gt 0) {
            $found = @(Get-ProvLocators -Text $noLoc[0].Text -Patterns $pats | Where-Object { $_.Kind -ne 'field' })
            if ($found.Count -eq 0) { & $ok "plant 4 landed: the 'specifies 40 mm' sentence carries no locator of any shape" }
            else { & $bad ("plant 4 did NOT land: the sentence carries a locator ({0})" -f (@($found | ForEach-Object { $_.Kind }) -join ',')) }
        }
        else { & $bad 'plant 4 did NOT land: the attributed sentence is not on the spine' }

        # plant 5 - the control. It must be verbatim at its own locator.
        $ctlAnchor = [regex]::Match($wbDoc.Text, '(?i)Task\s*4\(b\)')
        $ctlValue  = [regex]::Match($wbDoc.Text, '(?i)25\s*minutes')
        if ($ctlAnchor.Success -and $ctlValue.Success -and [math]::Abs($ctlValue.Index - $ctlAnchor.Index) -le $script:AnchorFwd) {
            & $ok 'plant 5 landed: the control value sits verbatim inside its own locator window and must NOT fire'
        }
        else { & $bad 'plant 5 did NOT land: the control value is not at its locator' }

        # ---- now run the gate ----
        $run = Invoke-Provenance -RunBuildDir $fixture -RunSpineDir '' -RunCorpusDir '' -RunPackDir '' -RunRulesPath '' -RunQuiet
        Write-ProvConsole -Run $run

        $reg = @($run.Registry)
        $get = { param($n) @($reg | Where-Object { $_.claim -eq $n })[0] }

        $r1 = & $get 'PLANT-ABSENT hold time'
        if ($null -ne $r1 -and $r1.disposition -eq 'UNRESOLVED') { & $ok 'gate fires: the absent value is UNRESOLVED' }
        else { & $bad ("the absent value came back {0}, wanted UNRESOLVED" -f $(if ($null -eq $r1) { 'MISSING' } else { $r1.disposition })) }

        $r2 = & $get 'PLANT-STALE tray depth'
        if ($null -ne $r2 -and $r2.disposition -eq 'NEAR-MISS' -and $r2.kind -eq 'stale-locator') { & $ok 'gate reports, and does not fail: the wrong-line locator is NEAR-MISS / stale-locator' }
        else { & $bad ("the stale locator came back {0}/{1}, wanted NEAR-MISS/stale-locator" -f $(if ($null -eq $r2) { 'MISSING' } else { $r2.disposition }), $(if ($null -eq $r2) { '' } else { $r2.kind })) }
        if ($null -ne $r2 -and -not $r2.blocking) { & $ok 'the stale locator does NOT block - a near miss is adjudicated, not failed' }
        else { & $bad 'the stale locator blocked the run' }

        $r3 = & $get 'PLANT-OK bench rest'
        if ($null -ne $r3 -and $r3.disposition -eq 'RESOLVED') { & $ok 'the correct row does NOT fire: RESOLVED verbatim at its locator' }
        else { & $bad ("the correct row came back {0}, wanted RESOLVED" -f $(if ($null -eq $r3) { 'MISSING' } else { $r3.disposition })) }

        $r4 = & $get 'PLANT-MANDATE chill figure'
        if ($null -ne $r4 -and $r4.disposition -eq 'RESOLVED') {
            & $ok 'the L-class row RESOLVES against the cited extract - so the mandate conflict below is not an artefact of an unresolved value'
        }
        else { & $bad ("the L-class row came back {0}, wanted RESOLVED - the anchor route to the cited document did not work" -f $(if ($null -eq $r4) { 'MISSING' } else { $r4.disposition })) }

        if (@($run.LegalConflict).Count -ge 1) {
            $c = @($run.LegalConflict)[0]
            if ($c.Legal.sourceStance -eq 'RECOMMENDS' -and $c.Legal.guideStance -eq 'ASSERTS-REQUIREMENT') {
                & $ok 'gate fires: an L-class figure asserted as a requirement where the cited text only recommends'
            }
            else { & $bad 'the mandate conflict fired with the wrong stances' }
        }
        else { & $bad 'the L-class mandate conflict did NOT fire' }

        $att = @($run.Attribution | Where-Object { $_.claim -match 'specifies 40 mm' })
        if ($att.Count -gt 0 -and $att[0].disposition -eq 'UNRESOLVED' -and $att[0].kind -eq 'attributed-quantity-no-locator') {
            & $ok 'gate fires: an attributed quantity with no locator is UNRESOLVED'
        }
        else { & $bad ("the unlocated attribution came back {0}, wanted UNRESOLVED/attributed-quantity-no-locator" -f $(if ($att.Count -eq 0) { 'MISSING' } else { $att[0].disposition + '/' + $att[0].kind })) }

        #  The control attribution must be DETECTED and RESOLVED. "It did not
        #  appear in the findings" is not evidence: a sweep that never saw the
        #  sentence produces exactly the same silence as a sweep that cleared
        #  it, and only one of those two is a working gate.
        $seen = @(Get-ProvAttributions -Cells (Get-ProvSpineCells -ForBuildDir $fixture -ForSpineDir '') -Nouns (Get-ProvSourceNouns -Contract $contract -Docs $src.Docs -Rows @() -Alias (Get-ProvAliasMap -Contract $contract -Docs $src.Docs)) -VerbRx ('(?i)\b(?:' + ((@((Get-ProvReportingVerbs -Contract $contract).Forms) | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\b'))
        $ctlSeen = @($seen | Where-Object { $_.Sentence -match 'Workbook Task 9\(c\) states' })
        if ($ctlSeen.Count -gt 0) { & $ok 'the control attribution IS detected by the sweep - silence would have proved nothing' }
        else { & $bad 'the control attribution was never detected, so its absence from the findings proves nothing' }
        $good = @($run.Attribution | Where-Object { $_.claim -match 'Workbook Task 9\(c\) states' })
        if ($good.Count -eq 0) { & $ok 'the correctly located attribution does NOT fire' }
        elseif ($good[0].disposition -eq 'RESOLVED') { & $ok 'the correctly located attribution is RESOLVED' }
        else { & $bad ("the correctly located attribution came back {0}: {1}" -f $good[0].disposition, $good[0].note) }

        $blocking = @(@($run.Registry) + @($run.Attribution) | Where-Object { $_.blocking })
        if ($blocking.Count -eq 2) { & $ok 'exactly two records block: the absent registry value and the unlocated attribution' }
        else { & $bad ("{0} record(s) block, wanted 2: {1}" -f $blocking.Count, ((@($blocking) | ForEach-Object { $_.kind }) -join ', ')) }

        # the report itself must be writable and re-readable
        $rp = Join-Path $fixture 'provenance-report.json'
        Write-ProvReport -Run $run -Path $rp
        $back = Get-GateJson -Path $rp
        if ($null -ne $back -and @($back.registry).Count -eq @($run.Registry).Count) { & $ok 'the report writes and parses back with every registry record' }
        else { & $bad 'the report did not write, or did not parse back' }
    }
    finally { Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue }

    Write-Host ''
    Write-Host ("  self-test: {0} passed, {1} failed" -f $script:stPass, $script:stFail) -ForegroundColor $(if ($script:stFail) { 'Red' } else { 'Green' })
    return $script:stFail
}

# ===========================================================================
# Entry
# ===========================================================================

if ($SelfTest) {
    $failed = Invoke-ProvSelfTest
    if ($failed -gt 0) { exit 4 }
    exit 0
}

if (-not $BuildDir) {
    Write-Host ("  X {0}: -BuildDir <build> is required. Provenance is proved against a build's own corpus, spine and registry." -f $GATE) -ForegroundColor Red
    exit 2
}
if (-not (Test-Path -LiteralPath $BuildDir)) {
    Write-Host ("  X {0}: -BuildDir does not exist: {1}" -f $GATE, $BuildDir) -ForegroundColor Red
    exit 2
}

$run = Invoke-Provenance -RunBuildDir $BuildDir -RunSpineDir $SpineDir -RunCorpusDir $CorpusDir -RunPackDir $PackDir -RunRulesPath $RulesPath -RunQuiet:$Quiet
if (-not $Quiet) { Write-ProvConsole -Run $run }

if (-not $OutPath) { $OutPath = Join-Path $BuildDir 'provenance-report.json' }
Write-ProvReport -Run $run -Path $OutPath

$unresolved = @(@($run.Registry) + @($run.Attribution) | Where-Object { $_.disposition -eq 'UNRESOLVED' })
$nearMiss   = @(@($run.Registry) + @($run.Attribution) | Where-Object { $_.disposition -eq 'NEAR-MISS' })
$absent     = @(@($run.Registry) + @($run.Attribution) | Where-Object { $_.disposition -eq 'SOURCE-ABSENT' })

Write-Host ''
Write-Host ("  {0} provenance row(s), {1} attributed sentence(s) swept; report written: {2}" -f $run.Rows, $run.Sentences, $OutPath) -ForegroundColor DarkGray

if ($unresolved.Count -gt 0) {
    Write-Host ("  X {0} UNRESOLVED - a registered value or an attributed quantity that its own named source does not carry." -f $unresolved.Count) -ForegroundColor Red
    Write-Host ("    {0} NEAR-MISS and {1} SOURCE-ABSENT are reported above for adjudication and do not block." -f $nearMiss.Count, $absent.Count) -ForegroundColor Yellow
    exit 1
}
if (@($run.LegalConflict).Count -gt 0) {
    Write-Host ("  X {0} L-class mandate conflict(s) - a recommendation asserted as a legal requirement." -f @($run.LegalConflict).Count) -ForegroundColor Red
    exit 5
}
Write-Host ("  every registered value resolves in the source it names, and every attributed quantity carries a locator that resolves. {0} NEAR-MISS and {1} SOURCE-ABSENT reported for adjudication." -f $nearMiss.Count, $absent.Count) -ForegroundColor Green
exit 0
