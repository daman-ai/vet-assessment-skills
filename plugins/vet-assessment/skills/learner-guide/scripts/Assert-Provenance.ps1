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
      RESOLVED-DERIVED
                    the row says the figure was COMPUTED - a locator beginning
                    DERIVED, or a derivedFrom list - and every input it names
                    resolves in the corpus, directly or through another derived
                    row whose own inputs resolve (the chain is run to a
                    fixpoint). A computed teaching figure is not in any source
                    BY CONSTRUCTION; what can be proved about it is that its
                    inputs are real, and that is what this disposition says.
                    An input that resolves nowhere is UNRESOLVED naming the
                    FIRST input that did not, because the reader has to know
                    WHICH link of the chain is missing.
      UNLOCATED     the locator resolves to NOTHING to point at: no anchor it
                    names is present in the document(s) it names, so "at the
                    locator" degenerates to "anywhere in the document" and the
                    locator half of the check never ran. Counted, non-zero
                    exit, and cleared only by fixing the registry or by a
                    provenanceAllow entry with a written reason. It is NOT
                    silently passed as verbatim, which is what 59 of 258
                    resolved rows on the reference build were.
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

    AND A COMPOSITE ROW IS SPLIT, ONE RECORD PER VALUE. Where the row's own
    wording is not in the source and the row states MORE THAN ONE quantity,
    each quantity is dispositioned on its own record. One row carrying "40 mm
    and 77 minutes" cannot report one disposition for two figures, because the
    row that does is the row where a fabricated figure hides behind a real one.
    Money is a quantity here: a currency amount is decomposed and matched like
    any other, and never falls through to the paraphrase arm, which is where
    every dollar figure went before.

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

    ------------------------------------------------------------------------
    THE THREE BANDS THIS GATE RUNS IN
    ------------------------------------------------------------------------
    -SeedOnly (Stage 2)  There is no spine yet. The REGISTRY rows are checked
      against the corpus on their own, before a word is authored, because a
      registry row whose source does not carry its value is a defect that gets
      copied into every sub-section that reads the row. A missing registry is a
      refusal naming the file - a seed run with nothing to check is not a pass.
      A row whose locator begins DERIVED is dispositioned by its INPUTS, here
      as everywhere else: RESOLVED-DERIVED when every one of them resolves,
      UNRESOLVED naming the first that does not.

    Stage 3c   the spine arms, as documented above.

    -Stage 7c -DocText <guide extract>,<deck extract>  the RENDERED arm. Every
      sentence in the delivered documents is swept for attribution exactly as
      the spine is, because a claim can reach a page without ever having been a
      spine cell. -Stage 7c with no extract is a refusal naming both extracts:
      a rendered arm with no rendering is the empty check-set this gate set
      exists to stop printing green over.

    PS 5.1. ASCII only in this file.
    Exit 0 clean; 1 at least one UNRESOLVED row or sentence, or an UNLOCATED
    row no provenanceAllow entry clears; 5 an L-class mandate conflict with
    neither; 2 a usage error; 4 the self-test failed.
#>

# GATE: stages=2,3c,4,7c; requires=BuildDir; 2: SeedOnly; 7c: DocText

[CmdletBinding()]
param(
    [string] $BuildDir,
    [string] $SpineDir,
    [string] $CorpusDir,
    #  Stage 2: the registry arms alone, against the corpus, with no spine.
    [switch] $SeedOnly,
    #  The band this run stands for (2, 3c, 4 or 7c). Recorded in the report;
    #  an unknown value is a usage error, not a silently ignored argument.
    [string] $Stage,
    #  The rendered extracts (guide_gate.txt, deck_gate.txt). Required by
    #  -Stage 7c and refused by name when it is passed without them.
    [string[]] $DocText,
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
$script:Self = $PSCommandPath

function Fail-Usage {
    <# Exit 2: a usage error, an absent input, or an empty blocking check-set. #>
    param([string] $Message)
    Write-Host ("  X {0}: {1}" -f $GATE, $Message) -ForegroundColor Red
    exit 2
}

function Stop-OnRefusal {
    <# The library's typed refusals reach exit 2 through here. #>
    param($Err)
    $m = $Err.Exception.Message
    if ($m -match '^(CHECK-SET EMPTY|ARMS INCOMPLETE):') { Fail-Usage $m }
    Fail-Usage ("the gate could not run - {0}" -f $m)
}

# REQUEST: Lib-GateCommon Set-GateArmState (see scratchpad\p0\REQUESTS\K.md)
function Set-ProvArmState {
    <# Record an arm DEFERRED: registered, not run, and not a pass. #>
    param([Parameter(Mandatory)][string] $Name, [Parameter(Mandatory)][string] $Reason)
    $arm = $null
    foreach ($a in @(Get-GateArmRoster)) { if ($a.Name -eq $Name) { $arm = $a } }
    if ($null -eq $arm) { throw ("Set-ProvArmState: arm '{0}' was never registered." -f $Name) }
    if ($arm.State -ne 'not-run') { throw ("Set-ProvArmState: arm '{0}' already ended as '{1}'." -f $Name, $arm.State) }
    if ("$Reason".Trim().Length -lt 20) { throw ("Set-ProvArmState: arm '{0}' needs a written reason." -f $Name) }
    $arm.State = 'deferred'
    $arm.Reason = "$Reason"
    $arm.CompletedUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
}

#  A locator that begins DERIVED says the figure was COMPUTED from other
#  figures rather than read out of a source. Such a row is dispositioned on its
#  INPUTS - see Resolve-ProvDerivedChains - and never on the computed value,
#  which by construction no source carries.
$script:DerivedLocatorRx = '^\s*DERIVED\b'

#  THE DERIVATION GRAMMAR a locator is allowed to use, and the only part of a
#  DERIVED locator this gate mines for inputs. The declared shape is the row's
#  own derivedFrom list; these markers read the prose form the registry and the
#  spine have written until now, so that a chain written in words is still
#  checked rather than waved through.
#    - everything after "inputs:" / "from these named inputs:" / "named inputs
#      that resolve:" is the input list;
#    - with no such marker, everything after "DERIVED from";
#    - everything after "the value(s) this chain produces" is the OUTPUT of the
#      chain and is NOT an input. Mining it would fail the row on the very
#      figure it was computed to produce, which is the false finding this whole
#      change exists to remove.
$script:DerivedInputMarkerRx   = '(?i)\b(?:named\s+)?inputs?\b(?:\s+that\s+resolve)?\s*(?:are\s*)?[:,-]?\s*'
$script:DerivedProducesMarkerRx = '(?i)\bthe\s+values?\s+th(?:is|e)\s+chain\s+produces\b'
#  A conclusion clause states the ANSWER: "..., so the Friday between those two
#  Mondays is 11 September 2026". Everything after it is output, like the
#  produces marker, and mining it would fail the row on its own result.
$script:DerivedConclusionRx = '(?i),\s*(?:so|which\s+(?:gives|makes|leaves|comes\s+to)|therefore)\b'
$script:DerivedFromMarkerRx    = '(?i)^\s*DERIVED\b[\s,]*(?:from\b\s*)?'

#  A number that follows one of these words is a REFERENCE - a line, a clause,
#  a page - not a quantity the chain consumes. Without this the input harvester
#  would ask the corpus to carry "line 201" as a figure.
#  Matched against the text IMMEDIATELY BEFORE a candidate, so the rule reads
#  in one direction and needs no lookbehind.
$script:LocatorRefWordRx = '(?i)\b(?:line|lines|clause|clauses|page|pages|item|items|task|tasks|question|questions|appendix|section|sections|no\.?|number|paragraph|step|slide|row|table|figure)\s{1,3}$'

#  A currency amount. Money is a quantity: without this shape a dollar figure
#  carries no quantity at all, falls through to the paraphrase arm and can
#  never reach UNRESOLVED however absent it is.
#  Every comma inside the number must be FOLLOWED by digits, or "Freezer 2,
#  SITXINV007" harvests the figure "2," and the gate asks the corpus to carry
#  a comma.
$script:MoneyRx = '\$\s?\d+(?:,\d+)*(?:\.\d{1,2})?'

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
    <#  Every number-with-unit token in a string, every currency amount, plus
        bare temperatures.

        MONEY IS A QUANTITY. Until the currency shape was here, "$1,250.00"
        decomposed to NOTHING: the row carried no quantity, so it fell through
        to the paraphrase arm, which reports on content words and never blocks.
        A costing figure could not reach UNRESOLVED however absent it was, and
        a whole class of figure was checked by a rule written for prose. The
        currency alternative comes FIRST so the amount is consumed with its
        symbol rather than read as a bare number.  #>
    param([string] $Text)
    $t = ConvertTo-ProvFold $Text
    $rx = '(?i)(?:' + $script:MoneyRx + '|(?:minus\s+)?\d+(?:,\d+)*(?:\.\d+)?\s*(?:' + $script:DegRx + '|per\s*cent|%|' + ($script:UnitFamilies -join '|') + '))(?![a-z])'
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($t, $rx)) {
        $v = ($m.Value -replace '\s+', ' ').Trim()
        if (-not $out.Contains($v)) { $out.Add($v) }
    }
    return $out.ToArray()
}

# REQUEST: Lib-GateCommon Get-GateValueBoundaryRegex (see scratchpad\p0\REQUESTS\P2.md - LANDED)
function Get-ProvValueBoundaryRegex {
    <#  A value regex that cannot land inside a longer number or word: 0.6 kg
        must not resolve on 10.6 kg, and 7.5 L must not resolve on 17.5 L.

        The boundary is the LIBRARY's - Get-GateValueBoundaryRegex -Raw, one
        definition of a token boundary for every gate. The private wrap below
        is the fallback for a library that predates it, and it is the same
        expression; a boundary that two files define twice is a boundary two
        gates can disagree about.

        Used by the DERIVED-input arm only. The three general matching arms are
        deliberately left as they are: widening or narrowing them would move
        every disposition in the report, and that is not this change.  #>
    param([string] $Pattern)
    if (-not "$Pattern") { return $null }
    if (Get-Command -Name 'Get-GateValueBoundaryRegex' -ErrorAction SilentlyContinue) {
        return (Get-GateValueBoundaryRegex -Value ('(?:' + $Pattern + ')') -Raw)
    }
    return ('(?<![\d.\w])(?:' + $Pattern + ')(?![\d.\w])')
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

function Get-ProvRenderedCells {
    <#  The RENDERED arm's cells: every substantive line of each extract, in the
        same shape a spine cell has, so both arms sweep the delivered documents
        with the machinery they already use. The channel is stamped
        rendered:<artefact> from the extract's own name, so a finding says which
        document it is in. A claim can reach a page without ever having been a
        spine cell - through the renderer's own prose, a template block or a
        hand edit - and nothing read the pages until this arm existed.  #>
    param([string[]] $Paths)
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($p in @($Paths)) {
        if (-not "$p".Trim()) { continue }
        $leaf = Split-Path $p -Leaf
        $artefact = 'unknown'
        if ($leaf -match '(?i)guide') { $artefact = 'guide' }
        elseif ($leaf -match '(?i)deck|slide|ppt') { $artefact = 'deck' }
        else { $artefact = ($leaf -replace '\.[A-Za-z0-9]+$', '') }
        $text = Get-GateFileText -Path $p
        $ln = 0
        foreach ($line in @("$text" -split "`r?`n")) {
            $ln++
            $t = "$line".Trim()
            if ($t.Length -lt 12) { continue }
            $out.Add([pscustomobject]@{
                File = $leaf; Path = ("line {0}" -f $ln); Channel = ('rendered:' + $artefact); Slot = ''
                Text = $t; Fold = (ConvertTo-ProvFold $t).ToLowerInvariant()
            })
        }
    }
    return $out.ToArray()
}

# ===========================================================================
# 3. Finding a value in a document
# ===========================================================================

#  The value cache: value + document -> that document's hits, cleared at the
#  top of every run because two builds in one process can carry the same
#  document name over different text. This gate is one of the slower ones and
#  the same value is looked up over the same document again and again - once
#  per row that names it, again per quantity inside it, again per derived input
#  that consumes it - so the cache is free and the saving is not.
$script:ValueCacheCap = 8

function Find-ProvValueInDoc {
    <#  ONE document, cached. Up to $ValueCacheCap hits of the STRONGEST arm
        that matches; a caller wanting fewer takes the first N, which is the
        same list the uncached code produced for that N.  #>
    param([string] $Value, $Doc)
    if ($null -eq $script:ValueCache) { $script:ValueCache = @{} }
    #  [char]1 and not '|': a value or a document name may contain any
    #  printable character, and a cache key that two different pairs can share
    #  is a cache that answers the wrong question. (PS 5.1 has no `u{} escape.)
    $key = "$Value" + ([string][char]1) + "$($Doc.Name)"
    if ($script:ValueCache.ContainsKey($key)) { return $script:ValueCache[$key] }
    $hits = New-Object System.Collections.Generic.List[object]
    $arms = @(
        @{ Arm = 'exact';   Rx = (Get-ProvExactRegex   -Value $Value) },
        @{ Arm = 'loose';   Rx = (Get-ProvLooseRegex   -Value $Value) },
        @{ Arm = 'variant'; Rx = (Get-ProvVariantRegex -Value $Value) }
    )
    foreach ($a in $arms) {
        if (-not $a.Rx) { continue }
        $m = [regex]::Match($Doc.Text, $a.Rx, 'IgnoreCase')
        if (-not $m.Success) { continue }
        $seenOffsets = New-Object 'System.Collections.Generic.HashSet[int]'
        while ($m.Success -and $hits.Count -lt $script:ValueCacheCap) {
            if ($seenOffsets.Add($m.Index)) {
                $ln = Get-ProvLineAt -Doc $Doc -Offset $m.Index
                $hits.Add([pscustomobject]@{
                    Doc = $Doc.Name; Audience = $Doc.Audience; Arm = $a.Arm; Offset = $m.Index
                    Line = $ln; Text = (Get-ProvSafeQuote -Doc $Doc -Line $ln); Matched = (Get-ProvSnippet $m.Value 80)
                })
            }
            $m = $m.NextMatch()
        }
        break   # a document reports its STRONGEST arm, not all three
    }
    $out = $hits.ToArray()
    $script:ValueCache[$key] = $out
    return $out
}

function Find-ProvValue {
    <#  Three arms in order of strength, and the arm is REPORTED, because the
        arm is the whole difference between a verbatim match and a near miss.
        Cheapest arm first so 500 rows against a 200 KB corpus stay quick.  #>
    param([string] $Value, $Docs, [int] $Max = 6)
    $hits = New-Object System.Collections.Generic.List[object]
    if (-not "$Value".Trim()) { return $hits }
    foreach ($d in @($Docs)) {
        if ($null -eq $d) { continue }
        foreach ($h in @(Find-ProvValueInDoc -Value $Value -Doc $d)) {
            if ($hits.Count -ge $Max) { break }
            $hits.Add($h)
        }
        if ($hits.Count -ge $Max) { break }
    }
    return $hits
}

# ===========================================================================
# 3b. DERIVED rows - the chain, run to a fixpoint
#
#  A CALCULATED FIGURE IS NOT IN ANY SOURCE, AND THAT IS NOT A DEFECT. A guide
#  that teaches ordering has to work an example: 5 cartons at $250.00 is
#  $1,250.00, and no document in the pack carries $1,250.00 because the pack
#  never did that sum. Until this section existed the gate had NO disposition
#  for such a row, so every computed teaching figure came back as a fabricated
#  one - a false finding against correct content, and a large share of the
#  fifty blocking findings the reference build raised.
#
#  What CAN be proved about a derived figure is that its INPUTS are real. So
#  the row is dispositioned on the inputs it names, and an input that is itself
#  produced by another derived row resolves through that row - the chain is run
#  to a fixpoint, so "the 72 portions derived above" is an input like any
#  other, and only a chain that bottoms out in the corpus is RESOLVED-DERIVED.
# ===========================================================================

function Get-ProvRowKey {
    param($Row)
    return ("{0}|{1}|{2}" -f $Row.Register, $Row.File, $Row.Field)
}

function Test-ProvIsDerived {
    <# Either shape says derived: the locator, or a derivedFrom list. #>
    param($Row)
    if ($null -eq $Row) { return $false }
    if (@($Row.DerivedFrom | Where-Object { "$_".Trim() }).Count -gt 0) { return $true }
    return ("$($Row.Locator)" -match $script:DerivedLocatorRx)
}

function ConvertTo-ProvValueKey {
    <#  One value, one key - so that "1,800 gms" produced by one row and
        "1800 g" consumed by another are the same figure. Unit families fold to
        the family's first spelling; the number folds through [double] so
        0.040 and 0.04 are one value.  #>
    param([string] $Value)
    $v = (ConvertTo-ProvFold $Value).ToLowerInvariant()
    $v = $v -replace ',', ''
    $v = ($v -replace '\s+', ' ').Trim()
    if (-not $v) { return '' }
    $m = [regex]::Match($v, '^(\$?)\s*(\d+(?:\.\d+)?)\s*([a-z]+)?$')
    if ($m.Success) {
        $num = $m.Groups[2].Value
        $d = 0.0
        if ([double]::TryParse($num, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref] $d)) {
            $num = $d.ToString([System.Globalization.CultureInfo]::InvariantCulture)
        }
        $u = $m.Groups[3].Value
        if ($u) {
            #  -contains over the family's own spellings, not a regex built from
            #  a domain string: the family IS the list, and comparing against
            #  the list says so.
            foreach ($f in $script:UnitFamilies) {
                $forms = @($f -split '\|')
                if ($forms -contains $u) { $u = $forms[0]; break }
            }
        }
        return ($m.Groups[1].Value + $num + $u)
    }
    return ($v -replace '\s', '')
}

function Get-ProvDerivedSegment {
    <#  The part of a DERIVED locator that names the INPUTS.

        Everything after "the values this chain produces" is the chain's OUTPUT
        and is cut away first. Mining the output as an input would fail the row
        on the very figure it was computed to produce - the exact false finding
        this change exists to remove.  #>
    param([string] $Locator)
    $t = ConvertTo-ProvFold $Locator
    $cut = $t.Length
    foreach ($rx in @($script:DerivedProducesMarkerRx, $script:DerivedConclusionRx)) {
        $m = [regex]::Match($t, $rx)
        if ($m.Success -and $m.Index -lt $cut) { $cut = $m.Index }
    }
    if ($cut -lt $t.Length) { $t = $t.Substring(0, $cut) }
    $mi = [regex]::Match($t, $script:DerivedInputMarkerRx)
    if ($mi.Success) { return $t.Substring($mi.Index + $mi.Length) }
    $mf = [regex]::Match($t, $script:DerivedFromMarkerRx)
    if ($mf.Success) { return $t.Substring($mf.Index + $mf.Length) }
    return $t
}

function Get-ProvHarvestValues {
    <#  Currency, then number-with-unit, then bare number - each consumed span
        BLANKED before the next pass, so one amount cannot seed three
        candidates ($250.00 must not also yield 250 and 00). A number that
        follows "line", "clause" or "page" is a reference, not a quantity, and
        is left alone. Returned in the order they are written.  #>
    param([string] $Text, [switch] $NoBare)
    $t = "$Text"
    if (-not $t.Trim()) { return @() }
    $chars = $t.ToCharArray()
    $found = New-Object System.Collections.Generic.List[object]
    $qtyRx = '(?i)(?:minus\s+)?\d+(?:,\d+)*(?:\.\d+)?\s*(?:' + $script:DegRx + '|per\s*cent|%|' + ($script:UnitFamilies -join '|') + ')(?![a-z])'
    #  A BARE NUMBER IS AN INPUT ONLY WHERE A NOUN FOLLOWS IT - "5 cartons" is
    #  a quantity in a unit this file does not know; "Freezer 2, SITXINV007"
    #  and "7 September 2026" are not quantities at all. The lower-case noun is
    #  what separates them: a month, a document code and a proper name are
    #  capitalised, and a unit is not. Without this rule the harvester asked
    #  the corpus to carry 814 and 2026 as figures.
    $bareRx = '(?<![\w.,$])\d+(?:,\d+)*(?:\.\d+)?(?=\s+[a-z]{3,})'
    #  A DATE AND A CLOCK TIME ARE QUANTITIES a chain consumes: "the purchasing
    #  week commencing Monday 14 September 2026" and "the order cut-off of 2.00
    #  pm" are inputs a source either carries or does not. Harvested WHOLE and
    #  first, so the bare pass cannot reduce a date to the number 14.
    $dateRx = '(?i)\b\d{1,2}\s+(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{4}\b'
    $clockRx = '(?i)\b\d{1,2}[.:]\d{2}\s*(?:am|pm)\b'
    $passes = New-Object System.Collections.Generic.List[object]
    $passes.Add(@{ Rx = $dateRx; Bare = $false })
    $passes.Add(@{ Rx = $clockRx; Bare = $false })
    $passes.Add(@{ Rx = ('(?i)' + $script:MoneyRx); Bare = $false })
    $passes.Add(@{ Rx = $qtyRx; Bare = $false })
    if (-not $NoBare) { $passes.Add(@{ Rx = $bareRx; Bare = $true }) }
    foreach ($p in $passes) {
        $cur = (-join $chars)
        foreach ($m in [regex]::Matches($cur, $p.Rx)) {
            if ($p.Bare) {
                $from = $m.Index - 24
                if ($from -lt 0) { $from = 0 }
                $before = $cur.Substring($from, $m.Index - $from)
                if ($before -match $script:LocatorRefWordRx) { continue }
            }
            $v = ($m.Value -replace '\s+', ' ').Trim()
            if (-not $v) { continue }
            $found.Add([pscustomobject]@{ At = $m.Index; Value = $v })
            for ($i = $m.Index; $i -lt ($m.Index + $m.Length); $i++) { $chars[$i] = ' ' }
        }
    }
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($f in @($found | Sort-Object At)) {
        if (-not $out.Contains($f.Value)) { $out.Add($f.Value) }
    }
    return $out.ToArray()
}

function Get-ProvDerivedInputs {
    <#  The inputs a derived row names, and in which shape.

        The DECLARED shape is derivedFrom and it wins outright: a list is a
        thing a gate can check and a sentence is a thing a gate has to parse.
        Then the values in the prose after the input marker. Then - for a chain
        whose inputs are PLACES rather than amounts, "the unsalted butter line
        printed in Appendix D" - the locator anchors that segment names, which
        resolve through the same reader. A row that names none of the three
        names nothing, and says so.

        A CHAIN'S OWN OUTPUT IS NEVER ITS INPUT. An input that the row's own
        value contains, or that the row declares as a value the chain produces,
        is dropped here: "so the Friday between those two Mondays is 11
        September 2026" states the answer, and asking the corpus to carry the
        answer is the false finding this whole change removes.  #>
    param($Row, $Patterns)
    $listed = @(@($Row.DerivedFrom) | Where-Object { "$_".Trim() } | ForEach-Object { "$_".Trim() })
    if ($listed.Count -gt 0) { return [pscustomobject]@{ Inputs = $listed; Kind = 'declared' } }

    $seg = Get-ProvDerivedSegment -Locator $Row.Locator
    $own = (ConvertTo-ProvFold $Row.Value).ToLowerInvariant()
    $producedKeys = @{}
    foreach ($p in @(Get-ProvDerivedProduces -Row $Row)) {
        $k = ConvertTo-ProvValueKey $p
        if ($k) { $producedKeys[$k] = $true }
    }
    $vals = New-Object System.Collections.Generic.List[string]
    foreach ($v in @(Get-ProvHarvestValues -Text $seg)) {
        #  AT A TOKEN BOUNDARY, never as a substring: the input 5 is inside the
        #  computed value $1,250.00, and dropping it there would leave the
        #  chain proved on half its inputs.
        if ($own) {
            $ownRx = Get-ProvValueBoundaryRegex -Pattern (Get-ProvExactRegex -Value $v)
            if ($ownRx -and [regex]::IsMatch($own, $ownRx, 'IgnoreCase')) { continue }
        }
        $k = ConvertTo-ProvValueKey $v
        if ($k -and $producedKeys.ContainsKey($k)) { continue }
        $vals.Add($v)
    }
    if ($vals.Count -gt 0) { return [pscustomobject]@{ Inputs = $vals.ToArray(); Kind = 'values' } }

    if ($null -ne $Patterns) {
        $places = New-Object System.Collections.Generic.List[string]
        foreach ($l in @(Get-ProvLocators -Text $seg -Patterns $Patterns)) {
            if ($l.Kind -eq 'field') { continue }
            if (-not $places.Contains("$($l.Text)")) { $places.Add("$($l.Text)") }
        }
        if ($places.Count -gt 0) { return [pscustomobject]@{ Inputs = $places.ToArray(); Kind = 'places' } }
    }
    return [pscustomobject]@{ Inputs = @(); Kind = 'none' }
}

function Get-ProvDerivedProduces {
    <#  What the chain PRODUCES: the row's own value, plus every quantity the
        locator names after the produces marker. These are what a later row's
        "derived above" input resolves against.  #>
    param($Row)
    $out = New-Object System.Collections.Generic.List[string]
    if ("$($Row.Value)".Trim()) { $out.Add("$($Row.Value)".Trim()) }
    foreach ($q in @(Get-ProvQuantity -Text $Row.Value)) { if (-not $out.Contains($q)) { $out.Add($q) } }
    $t = ConvertTo-ProvFold $Row.Locator
    foreach ($rx in @($script:DerivedProducesMarkerRx, $script:DerivedConclusionRx)) {
        $mp = [regex]::Match($t, $rx)
        if (-not $mp.Success) { continue }
        $tail = $t.Substring($mp.Index + $mp.Length)
        foreach ($q in @(Get-ProvHarvestValues -Text $tail -NoBare)) { if (-not $out.Contains($q)) { $out.Add($q) } }
    }
    return $out.ToArray()
}

function Find-ProvDerivedInput {
    <#  Does this input occur in the corpus, at a TOKEN BOUNDARY? 0.6 kg must
        not resolve on 10.6 kg: an input that resolves on a digit substring is
        a chain proved against a number that is not there.  #>
    param([string] $Value, $Docs)
    $out = New-Object System.Collections.Generic.List[object]
    if (-not "$Value".Trim()) { return $out }
    if ($null -eq $script:DerivedInputCache) { $script:DerivedInputCache = @{} }
    if ($script:DerivedInputCache.ContainsKey("$Value")) { return $script:DerivedInputCache["$Value"] }
    $arms = @(
        @{ Arm = 'exact';   Rx = (Get-ProvValueBoundaryRegex -Pattern (Get-ProvExactRegex   -Value $Value)) },
        @{ Arm = 'loose';   Rx = (Get-ProvValueBoundaryRegex -Pattern (Get-ProvLooseRegex   -Value $Value)) },
        @{ Arm = 'variant'; Rx = (Get-ProvValueBoundaryRegex -Pattern (Get-ProvVariantRegex -Value $Value)) }
    )
    foreach ($d in @($Docs)) {
        if ($null -eq $d) { continue }
        foreach ($a in $arms) {
            if (-not $a.Rx) { continue }
            $m = [regex]::Match($d.Text, $a.Rx, 'IgnoreCase')
            if (-not $m.Success) { continue }
            $ln = Get-ProvLineAt -Doc $d -Offset $m.Index
            $out.Add([pscustomobject]@{
                Doc = $d.Name; Audience = $d.Audience; Arm = $a.Arm; Offset = $m.Index
                Line = $ln; Text = (Get-ProvSafeQuote -Doc $d -Line $ln); Matched = (Get-ProvSnippet $m.Value 80)
            })
            break
        }
        if ($out.Count -gt 0) { break }
    }
    $script:DerivedInputCache["$Value"] = $out
    return $out
}

function Resolve-ProvDerivedChains {
    <#  Every derived row in the build, resolved together, because they refer
        to one another. Pass 1 asks the corpus about every input; then the
        fixpoint: a row whose inputs all resolve is SATISFIED and its produced
        values join the resolvable set, which may satisfy the next row, until
        nothing changes. A row that never satisfies names the FIRST input that
        did not resolve - the reader has to know which link is missing, not
        that some link is.  #>
    param($Rows, $Ctx)
    $map = @{}
    $states = New-Object System.Collections.Generic.List[object]
    foreach ($row in @($Rows)) {
        if (-not (Test-ProvIsDerived -Row $row)) { continue }
        $decl = Get-ProvDerivedInputs -Row $row -Patterns $Ctx.Patterns
        $states.Add([pscustomobject]@{
            Key       = (Get-ProvRowKey -Row $row)
            Row       = $row
            Inputs    = @($decl.Inputs)
            InputKind = $decl.Kind
            Produces  = @(Get-ProvDerivedProduces -Row $row)
            Hits      = @{}
            Via       = @{}
            Missing   = @()
            Satisfied = $false
        })
    }
    if ($states.Count -eq 0) { return $map }

    foreach ($s in $states) {
        foreach ($in in @($s.Inputs)) {
            $h = @(Find-ProvDerivedInput -Value $in -Docs $Ctx.Docs)
            if ($h.Count -gt 0) { $s.Hits[$in] = $h[0]; $s.Via[$in] = ('the corpus: ' + $h[0].Doc + ' line ' + $h[0].Line) }
        }
    }

    $produced = @{}
    for ($pass = 0; $pass -le ($states.Count + 1); $pass++) {
        $changed = $false
        foreach ($s in $states) {
            if ($s.Satisfied) { continue }
            if (@($s.Inputs).Count -eq 0) { continue }
            $missing = New-Object System.Collections.Generic.List[string]
            foreach ($in in @($s.Inputs)) {
                if ($s.Hits.ContainsKey($in)) { continue }
                $k = ConvertTo-ProvValueKey $in
                if ($k -and $produced.ContainsKey($k)) { $s.Via[$in] = ('another derived row: ' + $produced[$k]); continue }
                $missing.Add($in)
            }
            $s.Missing = $missing.ToArray()
            if ($missing.Count -eq 0) {
                $s.Satisfied = $true
                $changed = $true
                foreach ($p in @($s.Produces)) {
                    $pk = ConvertTo-ProvValueKey $p
                    if ($pk -and -not $produced.ContainsKey($pk)) { $produced[$pk] = ("{0} ({1} {2})" -f $s.Row.Name, $s.Row.File, $s.Row.Field) }
                }
            }
        }
        if (-not $changed) { break }
    }
    foreach ($s in $states) { $map[$s.Key] = $s }
    return $map
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
    #  "SITXINV007_UAT line 199" and "lines 606-608". A line number into an
    #  EXTRACT is the most precise locator this toolchain writes and the gate
    #  could not read one: the row got no region, "at the locator" became
    #  "anywhere in this document", and the check silently degraded to a grep.
    #  Twenty-one seed rows of the reference build are locators of exactly this
    #  shape. Resolved from the document's own line table, not by searching for
    #  the text "line 199" - see Find-ProvAnchorRegion.
    $pats.Add([pscustomobject]@{ Kind = 'line';      Rx = '\blines?\s+(\d+)(?:\s*(?:-|to|and)\s*(\d+))?\b';                    From = 'shape' })
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
        #  A LINE NUMBER IS RESOLVED FROM THE LINE TABLE, not by looking for
        #  the words "line 199" in the text - the document does not print its
        #  own line numbers. A number past the end of THIS document resolves to
        #  nothing here, which is exactly what it should say.
        if ($l.Kind -eq 'line') {
            $mm = [regex]::Match("$($l.Text)", '(?i)lines?\s+(\d+)(?:\s*(?:-|to|and)\s*(\d+))?')
            if (-not $mm.Success) { continue }
            $n1 = [int]$mm.Groups[1].Value
            $n2 = $n1
            if ($mm.Groups[2].Success) { $n2 = [int]$mm.Groups[2].Value }
            if ($n1 -lt 1 -or $n1 -gt @($Doc.Lines).Count) { continue }
            if ($n2 -lt $n1) { $n2 = $n1 }
            if ($n2 -gt @($Doc.Lines).Count) { $n2 = @($Doc.Lines).Count }
            $lineFrom = [int]$Doc.LineStarts[$n1 - 1]
            $lineTo   = [int]$Doc.LineStarts[$n2 - 1] + "$($Doc.Lines[$n2 - 1])".Length
            $from = $lineFrom - $script:AnchorBack
            if ($from -lt 0) { $from = 0 }
            $to = $lineTo + $script:AnchorFwd
            if ($to -gt $Doc.Text.Length) { $to = $Doc.Text.Length }
            $regions.Add([pscustomobject]@{ Kind = 'line'; Anchor = $l.Text; From = $from; To = $to; At = $lineFrom })
            continue
        }
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

function Get-ProvPhraseAnchors {
    <#  THE LOCATOR'S OWN WORDS, as a last-resort anchor.

        Half the locators this toolchain writes name a place by its HEADING -
        "SITXINV007 UAT, Detailed scenario, the six goods you must arrange" -
        and no pattern shape matches a heading. Without this the row got no
        region at all, "at the locator" became "anywhere in this document", and
        the row was either passed on a grep or, once UNLOCATED existed, failed
        on a locator that is perfectly good.

        USED ONLY WHERE EVERY PATTERN ANCHOR FAILED IN THIS DOCUMENT, so it can
        only ever NARROW a whole-document region and never widen a precise one.
        The segment naming the document itself is dropped: a title matches the
        title line, which is a place the value is not.  #>
    param([string] $Locator, $Doc)
    $out = New-Object System.Collections.Generic.List[object]
    $t = ConvertTo-ProvFold $Locator
    if (-not $t) { return $out.ToArray() }
    $nameTokens = @{}
    foreach ($nt in @($Doc.NameTokens)) { $nameTokens["$nt"] = $true }
    foreach ($seg in @([regex]::Split($t, '[,;:]|\s+/\s+|\s+-\s+'))) {
        $s = "$seg".Trim()
        if ($s.Length -lt 8) { continue }
        $words = @([regex]::Matches($s.ToLowerInvariant(), '[a-z]{3,}') | ForEach-Object { $_.Value })
        if ($words.Count -lt 2) { continue }
        $ownName = $true
        foreach ($w in $words) { if (-not $nameTokens.ContainsKey($w)) { $ownName = $false } }
        if ($ownName) { continue }
        $out.Add([pscustomobject]@{ Kind = 'phrase'; Text = $s })
    }
    return $out.ToArray()
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
    param([string] $ForBuildDir, [string] $ForSpineDir, [string] $ForRulesPath, $Classes, [switch] $RegistryOnly, [switch] $RequireRegistry)
    $rows = New-Object System.Collections.Generic.List[object]
    #  The spine files that carry no provenance block at all. Returned through
    #  the script scope rather than by changing this function's return shape,
    #  which three callers unpack as a bare array. Reported by name: a
    #  sub-section that registers nothing is a sub-section nothing was proved
    #  about, and a silent skip is how that stays invisible.
    $script:ProvFilesWithoutProvenance = @()
    $noProv = New-Object System.Collections.Generic.List[string]

    $registry = $null
    $regFile = $ForRulesPath
    if (-not $regFile) { $regFile = Join-Path $ForBuildDir 'figures.json' }
    if (-not (Test-Path -LiteralPath $regFile)) {
        if ($RequireRegistry) {
            throw ("{0}: no figure registry at {1}. The seed arms ARE the registry rows read against the corpus; with no registry there is nothing to check, and a run with nothing to check is a refusal, not a pass. Write figures.json (New-WithholdRegister / the figure registry step) before Stage 2, or pass -RulesPath." -f $GATE, $regFile)
        }
    }
    else { $registry = Get-GateJson -Path $regFile }
    if ($null -ne $registry) {
        $fi = 0
        foreach ($f in @($registry.figures)) {
            if ($null -eq $f) { $fi++; continue }
            $auth = "$(Get-GateProp -Object $f -Names @('authority', 'class', 'authorityClass') -Default '')"
            $src  = "$(Get-GateProp -Object $f -Names @('source', 'provenance', 'locator') -Default '')"
            $name = "$(Get-GateProp -Object $f -Names @('name', 'figure', 'id') -Default ('figures[' + $fi + ']'))"
            $req  = @(Get-GateProp -Object $f -Names @('require', 'value', 'values') -Default @())
            #  The declared derivation shape. A row that carries one is
            #  dispositioned on its inputs whatever its locator says.
            $dfrom = @(Get-GateProp -Object $f -Names @('derivedFrom', 'derivedfrom', 'inputs') -Default @())
            if ($req.Count -eq 0) {
                $rows.Add([pscustomobject]@{
                    Register = 'figures.json'; File = (Split-Path $regFile -Leaf); Field = ("figures[{0}]" -f $fi)
                    Name = $name; Value = ''; Authority = $auth; Classes = (Get-ProvClassTokens -Authority $auth -Classes $Classes); Locator = $src
                    DerivedFrom = $dfrom
                })
            }
            else {
                $vi = 0
                foreach ($v in $req) {
                    $rows.Add([pscustomobject]@{
                        Register = 'figures.json'; File = (Split-Path $regFile -Leaf); Field = ("figures[{0}].require[{1}]" -f $fi, $vi)
                        Name = $name; Value = "$v"; Authority = $auth; Classes = (Get-ProvClassTokens -Authority $auth -Classes $Classes); Locator = $src
                        DerivedFrom = $dfrom
                    })
                    $vi++
                }
            }
            $fi++
        }
    }

    if ($RegistryOnly) { return $rows.ToArray() }

    foreach ($sf in (Get-GateSpineFiles -BuildDir $ForBuildDir -SpineDir $ForSpineDir -Exclude @())) {
        $j = Get-GateJson -Path $sf.FullName
        if ($null -eq $j) { continue }
        if (@($j.PSObject.Properties.Name) -notcontains 'provenance') { $noProv.Add($sf.Name); continue }
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
                DerivedFrom = @(Get-GateProp -Object $p -Names @('derivedFrom', 'derivedfrom', 'inputs') -Default @())
                Mandatory = (Get-GateProp -Object $p -Names @('mandatory', 'isMandatory'))
            })
            $pi++
        }
    }
    $script:ProvFilesWithoutProvenance = $noProv.ToArray()
    return $rows.ToArray()
}

function Test-ProvAllowEntry {
    <#  A provenanceAllow entry, matched to a record. The keys a build may use
        are the ones a human would write down: the value, the claim, the field,
        'file|field', or the locator. Every entry carries a written reason -
        Get-GateAllowList refuses one that does not, which is why the refusal
        arrives as exit 2 and not as a cleared finding.  #>
    param($Rec, $Allow)
    if ($null -eq $Allow -or @($Allow.Keys).Count -eq 0) { return $null }
    $keys = @(
        "$($Rec.value)", "$($Rec.claim)", "$($Rec.field)", "$($Rec.locator)",
        ("{0}|{1}" -f $Rec.file, $Rec.field), ("{0} {1}" -f $Rec.file, $Rec.field)
    )
    foreach ($k in $keys) {
        if (-not "$k".Trim()) { continue }
        foreach ($a in @($Allow.Keys)) {
            if ("$a".Trim().ToLowerInvariant() -eq "$k".Trim().ToLowerInvariant()) {
                return [pscustomobject]@{ Id = "$a"; Reason = "$($Allow[$a])" }
            }
        }
    }
    return $null
}

function Test-ProvRow {
    <#  Returns ONE record, or - for a composite row - one record per value.
        The caller unpacks with @(), because a row that states two figures and
        reports one disposition is a row where a fabricated figure hides behind
        a real one.  #>
    param($Row, $Ctx, [switch] $NoSplit)

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
        #  Did the locator resolve to a PLACE, or only to a document? A row
        #  whose value is verbatim in the document its locator names, while
        #  nothing the locator names is IN that document, has had half its
        #  check skipped - see UNLOCATED.
        anchored    = $false
        derivedFrom = @(@($Row.DerivedFrom) | Where-Object { "$_".Trim() })
        derivedInputs = @()
        derivedMissing = @()
        compositeOf = ''
        parts          = @(Get-ProvQuantity -Text $Row.Value)
        partsResolved  = @()
        partsMissing   = @()
        disposition = 'NO-CLAIM'
        kind        = ''
        note        = ''
        evidence    = @()
        blocking    = $false
        allowedBy   = ''
        allowReason = ''
        locations   = @()
        occurrences = 1
    }

    # -----------------------------------------------------------------------
    #  DERIVED, BEFORE ANYTHING CAN CALL THIS ROW ABSENT. A computed figure is
    #  in no source by construction; what is provable is that its inputs are.
    # -----------------------------------------------------------------------
    if (Test-ProvIsDerived -Row $Row) {
        $key = Get-ProvRowKey -Row $Row
        $st = $null
        if ($null -ne $Ctx.Derived -and $Ctx.Derived.ContainsKey($key)) { $st = $Ctx.Derived[$key] }
        if ($null -eq $st) {
            #  Standalone: no precomputed chain map, so this row is its own
            #  chain. It resolves against the corpus or it does not.
            $solo = Resolve-ProvDerivedChains -Rows @($Row) -Ctx $Ctx
            if ($solo.ContainsKey($key)) { $st = $solo[$key] }
        }
        $rec.kind = 'derived'
        if ($null -ne $st) { $rec.derivedInputs = @($st.Inputs) }
        if ($null -eq $st -or @($st.Inputs).Count -eq 0) {
            $rec.disposition = 'UNRESOLVED'
            $rec.kind = 'derived-no-inputs'
            $rec.blocking = $true
            $rec.note = ("the row says the figure is DERIVED and names no input this gate can resolve - no declared derivedFrom list, and no amount, date, time or measured quantity in the prose after the input marker: '{0}'. The fix is a registry edit, not a content edit: add derivedFrom listing the values the chain consumes. A derived figure whose inputs cannot be read is a figure with no provenance at all, and this gate will not pass one." -f (Get-ProvSnippet $Row.Locator 200))
            return $rec
        }
        $rec.derivedMissing = @($st.Missing)
        $ev = New-Object System.Collections.Generic.List[object]
        foreach ($in in @($st.Inputs)) {
            if ($st.Hits.ContainsKey($in) -and $ev.Count -lt $script:MaxEvidence) { $ev.Add($st.Hits[$in]) }
        }
        $rec.evidence = $ev.ToArray()
        $chain = @()
        foreach ($in in @($st.Inputs)) {
            $via = 'NOT FOUND'
            if ($st.Via.ContainsKey($in)) { $via = "$($st.Via[$in])" }
            $chain += ("'{0}' <- {1}" -f $in, $via)
        }
        if ($st.Satisfied) {
            $rec.disposition = 'RESOLVED-DERIVED'
            $rec.kind = 'derived-inputs-resolve'
            $rec.note = ("the figure is COMPUTED, so no source carries it. Every input the row names resolves{0}: {1}." -f $(switch ("$($st.InputKind)") { 'declared' { ' (from the row''s own derivedFrom list)' } 'values' { ' (values read from the locator''s input clause)' } 'places' { ' - the row names PLACES rather than amounts, and each named place is in the corpus; what the place SAYS is a reader''s call' } default { '' } }), ($chain -join '; '))
        }
        else {
            $rec.disposition = 'UNRESOLVED'
            $rec.kind = 'derived-input-absent'
            $rec.blocking = $true
            $rec.note = ("the figure is computed from {0} named input(s) and the FIRST one that resolves nowhere is '{1}'. A chain is only as real as its inputs: {2}. Fix the input or the chain - the computed value itself is not expected in any source." -f @($st.Inputs).Count, @($st.Missing)[0], ($chain -join '; '))
        }
        return $rec
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
    $phraseAnchored = @()
    foreach ($d in @($named.Docs)) {
        $regions = Find-ProvAnchorRegion -Doc $d -Locators $locs
        if (@($regions).Count -eq 0) {
            #  Last resort, and only here: the locator's own heading words.
            $ph = @(Get-ProvPhraseAnchors -Locator $Row.Locator -Doc $d)
            if ($ph.Count -gt 0) {
                $regions = Find-ProvAnchorRegion -Doc $d -Locators $ph
                foreach ($r in @($regions)) { if ($phraseAnchored -notcontains $r.Anchor) { $phraseAnchored += $r.Anchor } }
            }
        }
        $regionsBy[$d.Name] = $regions
        if (@($regions).Count -gt 0) { $anchored = $true }
        foreach ($h in @(Find-ProvValue -Value $Row.Value -Docs @($d) -Max $script:MaxEvidence)) {
            $hitsNamed.Add($h)
            if (@($regions).Count -eq 0 -or (Test-ProvInRegion -Offset $h.Offset -Regions $regions)) { $atLocator.Add($h) }
        }
    }

    $rec.anchored = $anchored
    if (@($phraseAnchored).Count -gt 0) {
        $rec.anchors = @($rec.anchors) + @($phraseAnchored | ForEach-Object { 'phrase:' + (Get-ProvSnippet $_ 60) })
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
        #  ONE RECORD PER VALUE. A row that states more than one quantity and
        #  whose own wording is in no source is SPLIT here and each quantity is
        #  dispositioned on its own, because a single disposition over two
        #  figures is how a fabricated figure rides in beside a real one: the
        #  row reads NEAR-MISS, a reader sees "some of it resolved", and the
        #  half that resolved nowhere is never looked at.
        if (-not $NoSplit -and $rec.parts.Count -gt 1) {
            $split = New-Object System.Collections.Generic.List[object]
            $pi = 0
            foreach ($q in @($rec.parts)) {
                $sub = [pscustomobject]@{
                    Register = $Row.Register; File = $Row.File
                    Field = ("{0} value[{1}]" -f $Row.Field, $pi)
                    Name = $Row.Name; Value = $q; Authority = $Row.Authority
                    Classes = @($Row.Classes); Locator = $Row.Locator; DerivedFrom = @()
                    Mandatory = $Row.Mandatory
                }
                foreach ($sr in @(Test-ProvRow -Row $sub -Ctx $Ctx -NoSplit)) {
                    $sr.compositeOf = "$($Row.Value)"
                    $sr.note = ("value {0} of {1} in a composite row ('{2}'), dispositioned on its own: {3}" -f ($pi + 1), $rec.parts.Count, (Get-ProvSnippet $Row.Value 90), $sr.note)
                    $split.Add($sr)
                }
                $pi++
            }
            return $split.ToArray()
        }

        $partHitsAt = New-Object System.Collections.Generic.List[object]
        $partHitsNamed = New-Object System.Collections.Generic.List[object]
        $resolvedParts = New-Object System.Collections.Generic.List[string]
        $missingParts = New-Object System.Collections.Generic.List[string]
        #  PER PART, exact AND in region. Counting exact-at-locator HITS and
        #  comparing the total to the number of parts let one part that occurs
        #  three times stand in for two parts that occur nowhere, so a row
        #  could be called verbatim on a quantity it does not carry.
        $exactAtPart = @{}
        foreach ($q in @($rec.parts)) {
            $hitIn = $false
            foreach ($d in @($named.Docs)) {
                $reg = $regionsBy[$d.Name]
                foreach ($h in @(Find-ProvValue -Value $q -Docs @($d) -Max 3)) {
                    $hitIn = $true
                    $partHitsNamed.Add($h)
                    if (@($reg).Count -eq 0 -or (Test-ProvInRegion -Offset $h.Offset -Regions $reg)) {
                        $partHitsAt.Add($h)
                        if ($h.Arm -eq 'exact') { $exactAtPart[$q] = $true }
                    }
                }
            }
            if ($hitIn) { $resolvedParts.Add($q) } else { $missingParts.Add($q) }
        }
        $rec.partsResolved = $resolvedParts.ToArray()
        $rec.partsMissing = $missingParts.ToArray()

        $everyPartExactAt = $true
        foreach ($q in @($rec.parts)) { if (-not $exactAtPart.ContainsKey($q)) { $everyPartExactAt = $false } }
        $allPartsExactAt = ($rec.parts.Count -gt 0 -and $missingParts.Count -eq 0 -and $everyPartExactAt)

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

    # -----------------------------------------------------------------------
    #  UNLOCATED. The three dispositions above that say "AT THE LOCATOR" are
    #  entitled to say it only where the locator opened a region. Where it did
    #  not - no anchor it names occurs in the document it names - "at the
    #  locator" silently became "anywhere in this document", and the locator
    #  half of the check never ran. On the reference build 59 of 258 resolved
    #  rows were resolved that way and every one of them read as proof.
    #
    #  It is a finding, not a pass: counted, non-zero exit, and cleared only by
    #  fixing the registry or by a provenanceAllow entry whose written reason
    #  an auditor can read. UNRESOLVED, SOURCE-ABSENT, wrong-document, stale
    #  locator and paraphrase are left alone - none of them rests on the
    #  degenerate region.
    # -----------------------------------------------------------------------
    #  Nulls filtered before counting, both times: @($null).Count is 1 in 5.1,
    #  and a count that answers YES for an absent property would make this
    #  class fire on a row that never resolved a document at all.
    $namedDocCount = 0
    foreach ($d in @($named.Docs)) { if ($null -ne $d) { $namedDocCount++ } }
    $anchorCount = 0
    foreach ($a in @($rec.anchors)) { if ("$a".Trim()) { $anchorCount++ } }
    if ((-not $rec.anchored) -and $namedDocCount -gt 0 -and
        (@('verbatim-at-locator', 'quantities-verbatim-at-locator', 'not-verbatim') -contains $rec.kind)) {
        $was = $rec.disposition
        $wasKind = $rec.kind
        $rec.disposition = 'UNLOCATED'
        $rec.kind = 'locator-resolves-to-nothing'
        $rec.blocking = $true
        $rec.note = ("the locator names {0} but nothing it names as a PLACE occurs in the document(s) it names [{1}], so 'at the locator' degenerated to 'anywhere in the document' and only half this check ran. The value itself was {2}{3}. Fix the locator so it names an anchor the document carries, or record a provenanceAllow entry with a written reason." -f $(if ($anchorCount -gt 0) { 'anchor(s) ' + (($rec.anchors) -join ', ') } else { 'no anchor of any shape this build declares' }), ($rec.namedSource -join ', '), $(if ($wasKind -eq 'not-verbatim') { 'found but not verbatim' } else { 'found verbatim' }), $(if ($was -eq 'RESOLVED') { ' - it would have passed' } else { '' }))
        $allow = Test-ProvAllowEntry -Rec $rec -Allow $Ctx.Allow
        if ($null -ne $allow) {
            $rec.blocking = $false
            $rec.allowedBy = $allow.Id
            $rec.allowReason = $allow.Reason
            $rec.note = ("{0} ADJUDICATED by provenanceAllow entry '{1}': {2}" -f $rec.note, $allow.Id, $allow.Reason)
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
            #  NOT `($Ctx.VenueTokens.Count -eq 0)`. A build whose contract
            #  names no venue used to satisfy this test on every page: an empty
            #  token list made hasVenue true everywhere, so the V-class arm
            #  printed a clean line having compared nothing. The empty token
            #  list is now a refusal upstream (the 'venue' check-set), and the
            #  default here is false, so no route reaches a vacuous pass.
            $hasVenue = $false
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

    #  'line' is excluded here on purpose. A raw line number is a locator INTO
    #  AN EXTRACT - a thing the registry writes and delivered prose does not -
    #  and accepting one in a swept sentence would let "line 5" stand as a
    #  reference a reader could follow. Arm 2 stays exactly as strict as it was.
    $locs = @(Get-ProvLocators -Text $A.Sentence -Patterns $Ctx.Patterns | Where-Object { $_.Kind -ne 'field' -and $_.Kind -ne 'line' })
    $scope = 'sentence'
    if (@($locs).Count -eq 0) {
        $locs = @(Get-ProvLocators -Text $A.Cell.Text -Patterns $Ctx.Patterns | Where-Object { $_.Kind -ne 'field' -and $_.Kind -ne 'line' })
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

function Group-ProvRecords {
    <#  Records sharing a disposition, a value and a locator are ONE finding
        with its locations listed. The reference build printed the same
        registered value against the same locator from nine sub-sections as
        nine findings, and a reader who fixes the registry once still has eight
        of them staring back. Nothing is dropped: every file and field is on
        the record it was merged into.  #>
    param($Records)
    $order = New-Object System.Collections.Generic.List[string]
    $byKey = @{}
    $sep = [string][char]1
    foreach ($r in @($Records)) {
        if ($null -eq $r) { continue }
        $key = "$($r.disposition)" + $sep + "$($r.kind)" + $sep +
               (ConvertTo-ProvFold "$($r.value)").ToLowerInvariant() + $sep +
               (ConvertTo-ProvFold "$($r.locator)").ToLowerInvariant()
        $here = ("{0} {1}" -f $r.file, $r.field)
        if (-not $byKey.ContainsKey($key)) {
            $r.locations = @($here)
            $r.occurrences = 1
            $byKey[$key] = $r
            $order.Add($key)
            continue
        }
        $first = $byKey[$key]
        $locs = @($first.locations)
        if ($locs -notcontains $here) { $locs += $here }
        $first.locations = $locs
        $first.occurrences = [int]$first.occurrences + 1
        if ($r.blocking) { $first.blocking = $true }
        if ("$($r.claim)".Trim() -and "$($first.claim)" -ne "$($r.claim)" -and "$($first.claim)" -notmatch [regex]::Escape("$($r.claim)")) {
            $first.claim = ("{0}; {1}" -f $first.claim, $r.claim)
        }
    }
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($k in $order) { $out.Add($byKey[$k]) }
    return $out.ToArray()
}

function New-ProvFindingRecord {
    <#  A blocking finding in the toolchain's shape.

        P1-14 lands New-GateFinding in Lib-GateCommon (Rule, File, Field,
        Quote, re-found at the harvester's token boundary at write time). It is
        used the moment it exists and its parameters accept this call; until
        then the finding is written in today's shape. The check is on the
        PARAMETERS and not only on the name, because a call that binds against
        a different signature would stop the gate dead in the middle of a run
        rather than fall back.  #>
    param($Rec, [string] $Rule)
    #  The quote is what the harvester actually READ. For a value row that is
    #  the value; for a derived row with no value of its own it is the claim,
    #  and last of all the locator - never empty, because a finding that cannot
    #  say what it read cannot be tested.
    $quote = ''
    foreach ($e in @($Rec.evidence)) { if (-not $quote -and "$($e.Text)".Trim()) { $quote = "$($e.Text)" } }
    foreach ($cand in @("$($Rec.value)", "$($Rec.claim)", "$($Rec.locator)")) {
        if (-not $quote -and "$cand".Trim()) { $quote = (Get-ProvSnippet $cand 200) }
    }
    if (-not "$quote".Trim()) { $quote = '(the row carries no text)' }
    $cmd = Get-Command -Name 'New-GateFinding' -ErrorAction SilentlyContinue
    if ($null -ne $cmd) {
        $want = @{ Rule = $Rule; File = "$($Rec.file)"; Field = "$($Rec.field)"; Quote = $quote
                   Locator = (Get-ProvSnippet "$($Rec.locator)" 300); Detail = (Get-ProvSnippet "$($Rec.note)" 600) }
        $names = @($cmd.Parameters.Keys)
        $unknown = @(@($want.Keys) | Where-Object { $names -notcontains $_ })
        $missingMandatory = New-Object System.Collections.Generic.List[string]
        foreach ($p in @($cmd.Parameters.Values)) {
            $mand = $false
            foreach ($at in @($p.Attributes)) {
                if ($at -is [System.Management.Automation.ParameterAttribute] -and $at.Mandatory) { $mand = $true }
            }
            if ($mand -and -not $want.ContainsKey($p.Name)) { $missingMandatory.Add($p.Name) }
        }
        if ($unknown.Count -eq 0 -and $missingMandatory.Count -eq 0) {
            try { return (New-GateFinding @want) } catch { }
        }
    }
    return [pscustomobject]@{
        rule = $Rule; file = "$($Rec.file)"; field = "$($Rec.field)"; claim = "$($Rec.claim)"
        value = "$($Rec.value)"; locator = "$($Rec.locator)"; disposition = "$($Rec.disposition)"
        kind = "$($Rec.kind)"; quote = $quote; note = "$($Rec.note)"; locations = @($Rec.locations)
    }
}

function Get-ProvAllowMap {
    <#  provenanceAllow, read through Get-GateAllowList so an entry with no
        written reason is REFUSED rather than honoured. An allow-list entry
        that does not say why is a gate quietly switched off.  #>
    param([string] $ForBuildDir, [string] $ForRulesPath)
    $registry = $null
    try { $registry = Get-GateRegistry -BuildDir $ForBuildDir -RulesPath $ForRulesPath } catch { $registry = $null }
    if ($null -eq $registry) { return @{} }
    return (Get-GateAllowList -Registry $registry -Key 'provenanceAllow' -IdField @('value', 'claim', 'field', 'locator', 'id', 'figure') -GateName $GATE)
}

function Invoke-Provenance {
    param([string] $RunBuildDir, [string] $RunSpineDir, [string] $RunCorpusDir, [string] $RunPackDir, [string] $RunRulesPath, [string[]] $RunDocText, [string] $RunStage, [switch] $RunQuiet)

    #  Cleared per run. The caches key on a document NAME, and two builds in
    #  one process can carry the same document name over different text.
    $script:AnchorDocCache = @{}
    $script:RegionCache    = @{}
    $script:LabelForms     = @{}
    $script:ValueCache     = @{}
    $script:DerivedInputCache = @{}

    $contract = Get-GateContract -BuildDir $RunBuildDir
    $script:LabelForms = Get-ProvLabelForm -Contract $contract
    $classes  = Get-ProvAuthorityClasses -Contract $contract
    $allow    = Get-ProvAllowMap -ForBuildDir $RunBuildDir -ForRulesPath $RunRulesPath
    $sources  = Get-ProvSources -ForBuildDir $RunBuildDir -ForCorpusDir $RunCorpusDir -ForPackDir $RunPackDir
    if (@($sources.Docs).Count -eq 0) {
        throw ("{0}: no source documents. Provenance cannot be proved against nothing." -f $GATE)
    }
    $spineCells = Get-ProvSpineCells -ForBuildDir $RunBuildDir -ForSpineDir $RunSpineDir
    $renderedCells = @(Get-ProvRenderedCells -Paths $RunDocText)
    $cells    = @($spineCells) + @($renderedCells)
    $rows     = Get-ProvRows -ForBuildDir $RunBuildDir -ForSpineDir $RunSpineDir -ForRulesPath $RunRulesPath -Classes $classes
    $noProv   = @($script:ProvFilesWithoutProvenance)
    $patterns = Get-ProvLocatorPatterns -Contract $contract
    $alias    = Get-ProvAliasMap -Contract $contract -Docs $sources.Docs
    $nouns    = Get-ProvSourceNouns -Contract $contract -Docs $sources.Docs -Rows $rows -Alias $alias
    $verbs    = Get-ProvReportingVerbs -Contract $contract
    $venue    = Get-ProvVenueTokens -Contract $contract

    $ctx = [pscustomobject]@{
        Docs = $sources.Docs; Cells = $cells; Alias = $alias; Patterns = $patterns
        Classes = $classes; VenueTokens = $venue; Allow = $allow; Derived = $null
    }
    #  Every derived row in the build resolved TOGETHER, before any row is
    #  dispositioned: one row's output is the next row's input, and a chain is
    #  only readable end to end.
    $ctx.Derived = Resolve-ProvDerivedChains -Rows $rows -Ctx $ctx

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

    # -----------------------------------------------------------------------
    #  THE ARM ROSTER. Every arm ends ran / empty / declared-n-a; a blocking arm
    #  whose check-set is empty is a refusal (exit 2), never a green line.
    # -----------------------------------------------------------------------
    $vRows = @(@($rows) | Where-Object { @($_.Classes) -contains 'V' -and "$($_.Value)".Trim() })
    $lRows = @(@($rows) | Where-Object { @($_.Classes) -contains 'L' -and "$($_.Value)".Trim() })
    Reset-GateArmRoster
    Register-GateArm -Name 'registry'    -Blocking
    Register-GateArm -Name 'attribution' -Blocking
    Register-GateArm -Name 'spine-provenance'
    #  The venue arm is blocking exactly when the registry carries a V-class row
    #  to check. With none, it has no work and says so; with one, an empty venue
    #  token list is a refusal instead of the vacuous pass it used to be.
    Register-GateArm -Name 'venue' -Blocking:($vRows.Count -gt 0)
    Register-GateArm -Name 'legal'
    if ($RunStage -eq '7c') { Register-GateArm -Name 'rendered' -Blocking }

    Write-GateCheckSet -What 'provenance row(s)' -Count @($rows).Count -Blocking `
        -Input ('figures.json figures[] and every spine sub-section provenance[] block under ' + $(if ($RunSpineDir) { $RunSpineDir } else { Join-Path $RunBuildDir 'spine' })) `
        -DerivedFrom 'both registers, enumerated - never a hand-listed subset'
    Write-GateCheckSet -What 'cell(s) swept for an attributed sentence' -Count @($cells).Count -Blocking `
        -Input ('the spine, and the rendered extracts when -Stage 7c passes them') `
        -DerivedFrom ("{0} spine cell(s) + {1} rendered line(s)" -f @($spineCells).Count, @($renderedCells).Count)
    if ($vRows.Count -gt 0) {
        Write-GateCheckSet -What 'venue name token(s)' -Count @($venue).Count -Blocking `
            -Input 'contract.json build.brand / build.tradingName / scenario.employer / scenario.venue' `
            -DerivedFrom ("{0} V-class registry row(s) claim the figure is the venue's own procedure, and each one is proved by finding the venue's NAME beside the statement" -f $vRows.Count)
    }
    if ($RunStage -eq '7c') {
        Write-GateCheckSet -What 'rendered line(s) from the delivered documents' -Count @($renderedCells).Count -Blocking `
            -Input 'the extracts passed to -DocText (guide_gate.txt, deck_gate.txt)' `
            -DerivedFrom 'every line of every extract with twelve or more characters'
    }

    $records = New-Object System.Collections.Generic.List[object]
    $legal = New-Object System.Collections.Generic.List[object]
    $venueFindings = New-Object System.Collections.Generic.List[object]

    $derivedRows = 0
    foreach ($row in @($rows)) {
        if (Test-ProvIsDerived -Row $row) { $derivedRows++ }
        #  One row, one or more records: a composite row is one record per
        #  value. Every record of the row carries the row's class arms.
        $recs = @(Test-ProvRow -Row $row -Ctx $ctx)
        $lg = $null
        if (@($row.Classes) -contains 'L' -and "$($row.Value)".Trim()) {
            $lg = Test-ProvLegalRow -Row $row -Rec $recs[0] -Ctx $ctx
            if ($lg.conflict) {
                $legal.Add([pscustomobject]@{ Row = $row; Rec = $recs[0]; Legal = $lg })
            }
        }
        $vn = $null
        if (@($row.Classes) -contains 'V' -and "$($row.Value)".Trim()) {
            $v = Test-ProvVenueRow -Row $row -Ctx $ctx
            if ($null -ne $v) {
                $vn = [ordered]@{ onPage = $v.OnPage; statement = $v.Statement; filesWithoutStatement = @($v.Missing) }
                if ($v.OnPage -and @($v.Missing).Count -gt 0) { $venueFindings.Add([pscustomobject]@{ Row = $row; Missing = @($v.Missing) }) }
            }
        }
        foreach ($rec in $recs) {
            if ($null -ne $lg) { $rec.legal = $lg }
            if ($null -ne $vn) { $rec.venue = $vn }
            $records.Add([pscustomobject]$rec)
        }
    }
    $grouped = @(Group-ProvRecords -Records $records.ToArray())

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

    # ---- every declared arm ends
    Complete-GateArm -Name 'registry' -State 'ran' -Size @($rows).Count -Findings @($grouped | Where-Object { $_.blocking }).Count
    Complete-GateArm -Name 'attribution' -State 'ran' -Size @($cells).Count -Findings @($attrRecords | Where-Object { $_.disposition -eq 'UNRESOLVED' }).Count
    if (@($spineCells).Count -gt 0) { Complete-GateArm -Name 'spine-provenance' -State 'ran' -Size (@($spineCells | ForEach-Object { $_.File } | Select-Object -Unique)).Count -Findings @($noProv).Count }
    else { Complete-GateArm -Name 'spine-provenance' -State 'empty' -Size 0 }
    #  .Count on the List itself, never @($list): wrapping a List of
    #  PSCustomObjects in an array subexpression throws 'Argument types do not
    #  match' in 5.1, which is a parse-clean way to stop a gate dead.
    if ($vRows.Count -gt 0) { Complete-GateArm -Name 'venue' -State 'ran' -Size $vRows.Count -Findings $venueFindings.Count }
    else { Complete-GateArm -Name 'venue' -State 'empty' -Size 0 }
    if ($lRows.Count -gt 0) { Complete-GateArm -Name 'legal' -State 'ran' -Size $lRows.Count -Findings $legal.Count }
    else { Complete-GateArm -Name 'legal' -State 'empty' -Size 0 }
    if ($RunStage -eq '7c') { Complete-GateArm -Name 'rendered' -State 'ran' -Size @($renderedCells).Count -Findings @($attrRecords | Where-Object { $_.disposition -eq 'UNRESOLVED' -and "$($_.file)" -notmatch '\.json$' }).Count }

    return [pscustomobject]@{
        Registry     = $grouped
        Attribution  = $attrRecords.ToArray()
        LegalConflict= $legal.ToArray()
        VenueFinding = $venueFindings.ToArray()
        FilesWithoutProvenance = @($noProv)
        DerivedRows  = $derivedRows
        Records      = $records.Count
        RenderedLines = @($renderedCells).Count
        Stage        = $RunStage
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
        @{ Disp = 'UNLOCATED';     Colour = 'Red';    Head = 'UNLOCATED - the locator resolves to no place in the document it names, so only half the check ran. BLOCKING unless a provenanceAllow entry with a written reason clears it.' },
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
            Write-Host ("    [{0}] {1} {2}{3}" -f (@($r.class) -join ''), $r.file, $r.field, $(if ([int]$r.occurrences -gt 1) { ' (+' + ([int]$r.occurrences - 1) + ' more location(s): ' + ((@($r.locations) | Select-Object -Skip 1 | Select-Object -First 6) -join '; ') + ')' } else { '' })) -ForegroundColor $grp.Colour
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

    $derived = @($Run.Registry | Where-Object { $_.disposition -eq 'RESOLVED-DERIVED' })
    if ($derived.Count -gt 0) {
        Write-Host ''
        Write-Host ("  RESOLVED-DERIVED ({0}) - a COMPUTED figure, so no source carries it. Every input each chain names resolves, in the corpus or through another derived row. The chain is printed per row in the report." -f $derived.Count) -ForegroundColor Green
        foreach ($r in @($derived | Select-Object -First $script:MaxConsole)) {
            Write-Host ("    {0} {1}: '{2}' <- {3}" -f $r.file, $r.field, (Get-ProvSnippet $r.value 60), ((@($r.derivedInputs) | Select-Object -First 6) -join ', ')) -ForegroundColor DarkGray
        }
    }

    $cleared = @($Run.Registry | Where-Object { "$($_.allowedBy)".Trim() })
    if ($cleared.Count -gt 0) {
        Write-Host ''
        Write-Host ("  ADJUDICATED BY provenanceAllow ({0}) - counted, printed with the reason, and subtracted from the exit only. An allow entry is a claim a reader verifies, not a cleared row." -f $cleared.Count) -ForegroundColor Yellow
        foreach ($r in @($cleared | Select-Object -First $script:MaxConsole)) {
            Write-Host ("    {0} {1} [{2}]: {3}" -f $r.file, $r.field, $r.allowedBy, (Get-ProvSnippet $r.allowReason 160)) -ForegroundColor DarkGray
        }
    }

    if (@($Run.FilesWithoutProvenance).Count -gt 0) {
        Write-Host ''
        Write-Host ("  SPINE FILE(S) WITH NO PROVENANCE BLOCK ({0}) - nothing in them was registered, so nothing in them was proved. Reported by name; a silent skip is how that stays invisible." -f @($Run.FilesWithoutProvenance).Count) -ForegroundColor Yellow
        Write-Host ("    {0}" -f ((@($Run.FilesWithoutProvenance)) -join ', ')) -ForegroundColor DarkGray
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
    #  $Arms defaults to an empty ARRAY, not to $null: @($null).Count is 1, and
    #  a report carrying one null arm would read as a roster.
    param($Run, [string] $Path, $Arms = @(), [string] $Mode = 'spine')
    $out = [ordered]@{
        gate = [ordered]@{
            script       = $GATE
            mode         = $Mode
            stage        = "$($Run.Stage)"
            ranAt        = (Get-Date -Format 'o')
            corpusDir    = "$($Run.CorpusDir)"
            renderedLines = [int]$Run.RenderedLines
            derivedRows  = [int]$Run.DerivedRows
            derivedResolved = @($Run.Registry | Where-Object { $_.disposition -eq 'RESOLVED-DERIVED' }).Count
            derivedUnresolved = @($Run.Registry | Where-Object { $_.kind -like 'derived-*' -and $_.disposition -eq 'UNRESOLVED' }).Count
            unlocatedRows = @($Run.Registry | Where-Object { $_.disposition -eq 'UNLOCATED' }).Count
            unlocatedAdjudicated = @($Run.Registry | Where-Object { $_.disposition -eq 'UNLOCATED' -and "$($_.allowedBy)".Trim() }).Count
            compositeRecords = @($Run.Registry | Where-Object { "$($_.compositeOf)".Trim() }).Count
            records      = [int]$Run.Records
            groupedRecords = @($Run.Registry).Count
            spineFilesWithoutProvenance = @($Run.FilesWithoutProvenance)
            sources      = @($Run.Docs)
            spineCells   = $Run.Cells
            rows         = $Run.Rows
            sentences    = $Run.Sentences
            sourceNouns  = $Run.Nouns
            verbList     = @($Run.Verbs.Stems)
            verbListFrom = $Run.Verbs.DerivedFrom
            classes      = @($Run.Classes)
            dispositions = 'RESOLVED | RESOLVED-DERIVED | NEAR-MISS | UNLOCATED | UNRESOLVED | SOURCE-ABSENT'
            rule         = 'A NEAR-MISS is reported for adjudication, never silently failed and never silently passed: a near miss is usually a stale locator and a true absence is usually a fabricated figure. A line from an assessor-only document is recorded by document and line number and its text is withheld. A DERIVED row is dispositioned on the inputs it names, never on the computed value, which by construction no source carries. A row whose locator resolves to no place in the document it names is UNLOCATED and blocks - it is not passed as verbatim. Records sharing a disposition, a value and a locator are one record with every location listed.'
        }
        arms        = @($Arms)
        findings    = @(@($Run.Registry) + @($Run.Attribution) | Where-Object { $_.blocking } | ForEach-Object { New-ProvFindingRecord -Rec $_ -Rule ('provenance:' + $_.kind) })
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
# 8b. The seed arms - Stage 2, registry against corpus, no spine
# ===========================================================================

function Invoke-ProvSeed {
    <#  Stage 2. The registry rows are read against the corpus before a word is
        authored. A missing registry THROWS by name - a seed run with nothing to
        check is a refusal, not a pass - and a row whose locator begins DERIVED
        is dispositioned on the inputs it names, exactly as at Stage 3c.  #>
    param([string] $RunBuildDir, [string] $RunCorpusDir, [string] $RunPackDir, [string] $RunRulesPath, [switch] $RunQuiet)

    $script:AnchorDocCache = @{}
    $script:RegionCache    = @{}
    $script:LabelForms     = @{}
    $script:ValueCache     = @{}
    $script:DerivedInputCache = @{}

    $contract = Get-GateContract -BuildDir $RunBuildDir
    $script:LabelForms = Get-ProvLabelForm -Contract $contract
    $classes  = Get-ProvAuthorityClasses -Contract $contract
    $allow    = Get-ProvAllowMap -ForBuildDir $RunBuildDir -ForRulesPath $RunRulesPath
    $sources  = Get-ProvSources -ForBuildDir $RunBuildDir -ForCorpusDir $RunCorpusDir -ForPackDir $RunPackDir
    if (@($sources.Docs).Count -eq 0) {
        throw ("{0}: no source documents. Provenance cannot be proved against nothing." -f $GATE)
    }
    $rows = Get-ProvRows -ForBuildDir $RunBuildDir -ForSpineDir '' -ForRulesPath $RunRulesPath -Classes $classes -RegistryOnly -RequireRegistry
    $patterns = Get-ProvLocatorPatterns -Contract $contract
    $alias    = Get-ProvAliasMap -Contract $contract -Docs $sources.Docs
    $venue    = Get-ProvVenueTokens -Contract $contract

    $ctx = [pscustomobject]@{
        Docs = $sources.Docs; Cells = @(); Alias = $alias; Patterns = $patterns
        Classes = $classes; VenueTokens = $venue; Allow = $allow; Derived = $null
    }
    $ctx.Derived = Resolve-ProvDerivedChains -Rows $rows -Ctx $ctx

    Reset-GateArmRoster
    Register-GateArm -Name 'registry' -Blocking
    Register-GateArm -Name 'attribution' -Blocking
    Register-GateArm -Name 'venue' -Blocking

    if (-not $RunQuiet) {
        Write-Host ''
        Write-Host 'PROVENANCE (SEED) - does every registry row resolve in the source it names, before anything is authored?' -ForegroundColor Cyan
        Write-GateCheckSet -What 'source document(s)' -Count @($sources.Docs).Count -DerivedFrom 'the canonical corpus and unit_extract*.md'
    }
    Write-GateCheckSet -What 'registry row(s)' -Count @($rows).Count -Blocking `
        -Input ($(if ($RunRulesPath) { $RunRulesPath } else { Join-Path $RunBuildDir 'figures.json' }) + ' figures[]') `
        -DerivedFrom 'the figure registry, enumerated'

    $records = New-Object System.Collections.Generic.List[object]
    $legal = New-Object System.Collections.Generic.List[object]
    $derivedRows = 0
    foreach ($row in @($rows)) {
        if (Test-ProvIsDerived -Row $row) { $derivedRows++ }
        $recs = @(Test-ProvRow -Row $row -Ctx $ctx)
        $lg = $null
        if (@($row.Classes) -contains 'L' -and "$($row.Value)".Trim()) {
            $lg = Test-ProvLegalRow -Row $row -Rec $recs[0] -Ctx $ctx
            if ($lg.conflict) { $legal.Add([pscustomobject]@{ Row = $row; Rec = $recs[0]; Legal = $lg }) }
        }
        foreach ($rec in $recs) {
            if ($null -ne $lg) { $rec.legal = $lg }
            $records.Add([pscustomobject]$rec)
        }
    }
    $grouped = @(Group-ProvRecords -Records $records.ToArray())

    Complete-GateArm -Name 'registry' -State 'ran' -Size @($rows).Count -Findings @($grouped | Where-Object { $_.blocking }).Count
    #  The two spine arms cannot run at Stage 2 and say so by name.
    $why = 'there is no spine at Stage 2; the attributed-sentence sweep and the V-class page statement both read authored prose and run at Stage 3c'
    Set-ProvArmState -Name 'attribution' -Reason $why
    Set-ProvArmState -Name 'venue' -Reason $why

    return [pscustomobject]@{
        Registry     = $grouped
        Attribution  = @()
        LegalConflict= $legal.ToArray()
        VenueFinding = @()
        FilesWithoutProvenance = @()
        DerivedRows  = $derivedRows
        Records      = $records.Count
        RenderedLines = 0
        Stage        = '2'
        Rows         = @($rows).Count
        Sentences    = 0
        Docs         = @($sources.Docs | ForEach-Object { $_.Name })
        CorpusDir    = $sources.CorpusDir
        Cells        = 0
        Nouns        = 0
        Verbs        = (Get-ProvReportingVerbs -Contract $contract)
        Classes      = $classes
    }
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
    #  The DERIVED plants read their inputs from here: 5 (of cartons) and
    #  $250.00 are both in the corpus, and $18.00 is the money control.
    $wb.Add('Task 12(a) Receiving. Each carton holds 5 trays and is invoiced at $250.00 per carton, with a delivery fee of $18.00 per drop.')
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
                        require = @('6 degrees C or below within 90 minutes') },
            #  V-class, and the value appears on a page that does NOT say the
            #  figure is the venue's own. The other page does, so the finding
            #  has to name one file and not the other.
            [ordered]@{ name = 'PLANT-VENUE tray depth'; authority = 'V'
                        source = 'Fixture Recipe Workbook, Task 9(c)'
                        require = @('40 mm') },
            #  DERIVED, EVERY INPUT IN THE CORPUS. The computed value is in no
            #  source and must NOT be called absent: the row is dispositioned
            #  on '5' and '$250.00', both of which are at Task 12(a).
            [ordered]@{ name = 'PLANT-DERIVED-OK carton total'; authority = 'P'
                        source = 'DERIVED from 5 cartons at $250.00'
                        require = @('$1,250.00') },
            #  DERIVED with an input NOTHING carries. The row must name the
            #  missing input, not the computed value.
            [ordered]@{ name = 'PLANT-DERIVED-MISSING carton total'; authority = 'P'
                        source = 'DERIVED from 5 cartons at $999.00'
                        require = @('$4,995.00') },
            #  DERIVED naming no input of any shape: not a pass, and the fix
            #  it names is a registry edit.
            [ordered]@{ name = 'PLANT-DERIVED-NO-INPUTS tray count'; authority = 'P'
                        source = 'DERIVED from the batch size and the tray depth'
                        require = @('3 trays') },
            #  MONEY. Before the currency shape existed this value carried no
            #  quantity at all, fell through to the paraphrase arm and could
            #  not block however absent it was.
            [ordered]@{ name = 'PLANT-MONEY absent fee'; authority = 'P'
                        source = 'Fixture Recipe Workbook, Task 1(a)'
                        require = @('$47.50') },
            [ordered]@{ name = 'PLANT-MONEY present fee'; authority = 'P'
                        source = 'Fixture Recipe Workbook, Task 12(a)'
                        require = @('$18.00') },
            #  COMPOSITE: one value at the locator, one value in no document.
            #  It must split into TWO records so the bad half cannot hide.
            [ordered]@{ name = 'PLANT-COMPOSITE depth and hold'; authority = 'P'
                        source = 'Fixture Recipe Workbook, Task 9(c)'
                        require = @('40 mm and 77 minutes') },
            #  UNLOCATED: the document resolves, the value is verbatim in it,
            #  and NOTHING the locator names as a place is in the document. It
            #  passed as verbatim before this class existed.
            [ordered]@{ name = 'PLANT-UNLOCATED bench rest'; authority = 'P'
                        source = 'Fixture Recipe Workbook, the pickling schedule appendix'
                        require = @('25 minutes') }
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

    #  A second sub-section. It carries the V-class figure and does NOT say the
    #  figure is the venue's own, and it DOES carry a provenance block - so the
    #  venue finding must name this file, and the no-provenance report must name
    #  the other one. Two plants that discriminate between two files.
    $spine2 = [ordered]@{
        ref = '1.2'; pc = '1.2'; topic = 1; title = 'Second fixture sub-section'
        underpinningKnowledge = @(
            'The tray depth used on this run is 40 mm from lip to base.',
            'Check the depth with the gauge before the trays are loaded.'
        )
        provenance = @(
            [ordered]@{ figure = 'bench rest'; value = '25 minutes'; class = 'P'
                        source = 'Fixture Recipe Workbook, Task 4(b), the bench rest line' }
        )
    }
    [System.IO.File]::WriteAllText((Join-Path $root 'spine\t1_1.2.json'), ($spine2 | ConvertTo-Json -Depth 8), $enc)

    #  The rendered extracts the 7c arm reads. One line of each carries an
    #  attribution that resolves, so the arm has real work and a control.
    [System.IO.File]::WriteAllText((Join-Path $root 'guide_gate.txt'), (@(
        'Fixture Learner Guide - rendered extract.',
        'Workbook Task 9(c) states that each tray is filled to a depth of 40 mm before it goes to the blast chiller.',
        'The house rule at the FixtureCo production kitchen is 25 minutes of bench rest, and that is our own procedure.'
    ) -join "`r`n"), $enc)
    [System.IO.File]::WriteAllText((Join-Path $root 'deck_gate.txt'), (@(
        'Fixture delivery deck - rendered extract.',
        'Slide 1. Workbook Task 1(a) lists the documents you read before the run starts.'
    ) -join "`r`n"), $enc)
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

        # plant 6 - the DERIVED inputs. Both must be IN the corpus, at a token
        #           boundary, or RESOLVED-DERIVED would prove nothing.
        $in5 = @(Find-ProvDerivedInput -Value '5' -Docs $src.Docs)
        $in250 = @(Find-ProvDerivedInput -Value '$250.00' -Docs $src.Docs)
        if ($in5.Count -gt 0 -and $in250.Count -gt 0) { & $ok ("plant 6 landed: both derived inputs are in the corpus - '5' at {0} line {1}, '{2}' at {3} line {4}" -f $in5[0].Doc, $in5[0].Line, '$250.00', $in250[0].Doc, $in250[0].Line) }
        else { & $bad ("plant 6 did NOT land: '5' found {0} time(s), '{1}' found {2} time(s)" -f $in5.Count, '$250.00', $in250.Count) }

        # plant 7 - the values that must be ABSENT, or three findings are luck.
        $stillThere = New-Object System.Collections.Generic.List[string]
        foreach ($v in @('$999.00', '$47.50', '77 minutes')) {
            if (@(Find-ProvValue -Value $v -Docs $src.Docs -Max 1).Count -gt 0) { $stillThere.Add($v) }
        }
        if ($stillThere.Count -eq 0) { & $ok "plant 7 landed: the three absent values occur in NO source document" }
        else { & $bad ("plant 7 did NOT land: still present - {0}" -f (($stillThere.ToArray()) -join ', ')) }

        # plant 8 - the currency shape itself. Money must decompose to a
        #           quantity, or a money row can only ever be a paraphrase.
        $moneyParts = @(Get-ProvQuantity -Text '$1,250.00 for 5 cartons')
        if ($moneyParts -contains '$1,250.00') { & $ok ("plant 8 landed: money decomposes to a quantity ({0}) instead of to nothing" -f ($moneyParts -join ', ')) }
        else { & $bad ("plant 8 did NOT land: the money value decomposed to [{0}]" -f ($moneyParts -join ', ')) }

        # plant 9 - the UNLOCATED locator names a place the document does not
        #           carry, while the VALUE is verbatim in it.
        $noPlace = [regex]::IsMatch($wbDoc.Text, '(?i)pickling schedule')
        $valThere = @(Find-ProvValue -Value '25 minutes' -Docs @($wbDoc) -Max 1)
        if ((-not $noPlace) -and $valThere.Count -gt 0) { & $ok 'plant 9 landed: the workbook carries "25 minutes" verbatim and carries no "pickling schedule appendix", so the row can only be UNLOCATED - before this class existed it passed as verbatim' }
        else { & $bad ("plant 9 did NOT land: the named place is present={0}, the value was found {1} time(s)" -f $noPlace, $valThere.Count) }

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

        # ---- MONEY REACHES THE QUANTITY ARM, AND NEVER THE PARAPHRASE ARM.
        $m1 = & $get 'PLANT-MONEY absent fee'
        if ($null -ne $m1 -and $m1.disposition -eq 'UNRESOLVED' -and $m1.kind -ne 'paraphrase' -and (@($m1.parts) -contains '$47.50')) {
            & $ok 'gate fires on money: an absent currency value decomposes to a quantity and reaches UNRESOLVED - before the currency shape it carried no quantity, took the paraphrase arm and could not block'
        }
        else { & $bad ("the absent money row came back {0}/{1} with parts [{2}], wanted UNRESOLVED and a quantity" -f $(if ($null -eq $m1) { 'MISSING' } else { $m1.disposition }), $(if ($null -eq $m1) { '' } else { $m1.kind }), $(if ($null -eq $m1) { '' } else { (@($m1.parts) -join ', ') })) }

        $m2 = & $get 'PLANT-MONEY present fee'
        if ($null -ne $m2 -and $m2.disposition -eq 'RESOLVED' -and -not $m2.blocking) { & $ok 'the money CONTROL does not fire: a currency value at its locator is RESOLVED' }
        else { & $bad ("the money control came back {0}, wanted RESOLVED" -f $(if ($null -eq $m2) { 'MISSING' } else { $m2.disposition })) }

        # ---- COMPOSITE ROW: one record per value, and the bad half fails.
        #  -match, not -eq: the good half shares a value, a locator and a
        #  disposition with the V-class row, so grouping folds them into one
        #  record carrying both claims - which is the grouping rule working.
        $comp = @($reg | Where-Object { "$($_.claim)" -match 'PLANT-COMPOSITE' })
        $compGood = @($comp | Where-Object { $_.value -eq '40 mm' })
        $compBad  = @($comp | Where-Object { $_.value -eq '77 minutes' })
        if ($comp.Count -eq 2 -and $compGood.Count -eq 1 -and $compBad.Count -eq 1 -and
            $compGood[0].disposition -eq 'RESOLVED' -and -not $compGood[0].blocking -and
            $compBad[0].disposition -eq 'UNRESOLVED' -and $compBad[0].blocking -and
            "$($compBad[0].compositeOf)" -eq '40 mm and 77 minutes') {
            & $ok 'gate splits a composite row: TWO records, 40 mm RESOLVED at the locator and 77 minutes UNRESOLVED and blocking - one row can no longer report one disposition for two figures'
        }
        else { & $bad ("the composite row produced {0} record(s): {1}" -f $comp.Count, ((@($comp) | ForEach-Object { "'" + $_.value + "'=" + $_.disposition }) -join ', ')) }

        # ---- UNLOCATED: the locator resolves to no place, and it BLOCKS.
        $ul = & $get 'PLANT-UNLOCATED bench rest'
        if ($null -ne $ul -and $ul.disposition -eq 'UNLOCATED' -and $ul.kind -eq 'locator-resolves-to-nothing' -and $ul.blocking -and -not $ul.anchored) {
            & $ok 'gate fires: a row whose locator resolves to no place in the document it names is UNLOCATED and blocking, not verbatim'
        }
        else { & $bad ("the unlocated row came back {0}/{1} (blocking={2}), wanted UNLOCATED/locator-resolves-to-nothing/blocking" -f $(if ($null -eq $ul) { 'MISSING' } else { $ul.disposition }), $(if ($null -eq $ul) { '' } else { $ul.kind }), $(if ($null -eq $ul) { '' } else { $ul.blocking })) }

        $anch = & $get 'PLANT-OK bench rest'
        if ($null -ne $anch -and $anch.anchored) { & $ok 'the CONTROL for UNLOCATED is anchored: the same value under a locator the document does carry stays RESOLVED' }
        else { & $bad 'the anchored control lost its anchor, so the UNLOCATED plant proves nothing' }

        # ---- NOTHING IS NOT RUN ANY MORE. The P0-15 deferral is gone.
        $notRun = @(@($run.Registry) + @($run.Attribution) | Where-Object { "$($_.disposition)" -eq 'NOT RUN' -or "$($_.kind)" -eq 'derived-locator' })
        if ($notRun.Count -eq 0) { & $ok 'no row is recorded NOT RUN for being DERIVED: every derived row now carries a real disposition' }
        else { & $bad ("{0} row(s) are still NOT RUN: {1}" -f $notRun.Count, ((@($notRun) | ForEach-Object { $_.claim }) -join ', ')) }

        $blocking = @(@($run.Registry) + @($run.Attribution) | Where-Object { $_.blocking })
        $wantBlocking = @(
            'PLANT-ABSENT hold time', 'PLANT-MONEY absent fee', 'PLANT-COMPOSITE depth and hold',
            'PLANT-DERIVED-MISSING carton total', 'PLANT-DERIVED-NO-INPUTS tray count',
            'PLANT-UNLOCATED bench rest'
        )
        $gotClaims = @(@($blocking) | ForEach-Object { "$($_.claim)" })
        $missingBlock = @(@($wantBlocking) | Where-Object { $gotClaims -notcontains $_ })
        #  Six registry plants plus the unlocated attribution: SEVEN, and the
        #  set is asserted by name, not by count, so a plant that stopped
        #  firing cannot be paid for by a new record that started.
        if ($missingBlock.Count -eq 0 -and $blocking.Count -eq ($wantBlocking.Count + 1)) {
            & $ok ('exactly the {0} planted defects block, by name, plus the unlocated attribution - and nothing else does' -f $wantBlocking.Count)
        }
        else { & $bad ("{0} record(s) block, wanted {1}; not firing: [{2}]; firing: [{3}]" -f $blocking.Count, ($wantBlocking.Count + 1), ($missingBlock -join ', '), (($gotClaims | Select-Object -Unique) -join ', ')) }

        # ---- V-CLASS PLANT: the figure is on a page that does not say it is
        #      the venue's own, and on another page that does. The finding must
        #      name one file and not the other.
        $vf = @($run.VenueFinding | Where-Object { $_.Row.Name -eq 'PLANT-VENUE tray depth' })
        if ($vf.Count -ge 1) {
            $miss = @($vf[0].Missing)
            if (($miss -contains 't1_1.2.json') -and -not ($miss -contains 't1_1.1.json')) {
                & $ok 'gate fires: the V-class figure is reported in t1_1.2.json, which does not say it is the venue''s own, and NOT in t1_1.1.json, which does'
            }
            else { & $bad ("the V-class finding named [{0}], wanted t1_1.2.json only" -f ($miss -join ', ')) }
        }
        else { & $bad 'the V-class row with no venue statement on its page did NOT fire' }

        # ---- NO-PROVENANCE PLANT: one spine file registers nothing.
        $np = @($run.FilesWithoutProvenance)
        if (($np -contains 't1_1.1.json') -and -not ($np -contains 't1_1.2.json')) {
            & $ok 'gate reports by name: t1_1.1.json carries no provenance block, and t1_1.2.json - which does - is not named'
        }
        else { & $bad ("the no-provenance report named [{0}], wanted t1_1.1.json only" -f ($np -join ', ')) }

        # ---- DERIVED, RESOLVED ON ITS INPUTS. The computed value is in no
        #      source; calling that a fabrication is the false finding this
        #      disposition exists to remove.
        $dv = & $get 'PLANT-DERIVED-OK carton total'
        if ($null -ne $dv -and $dv.disposition -eq 'RESOLVED-DERIVED' -and -not $dv.blocking -and
            (@($dv.derivedInputs) -contains '5') -and (@($dv.derivedInputs) -contains '$250.00')) {
            & $ok ("the DERIVED row is RESOLVED-DERIVED naming its inputs [{0}] - its computed value '{1}' is in no source and is NOT called absent" -f (@($dv.derivedInputs) -join ', '), $dv.value)
        }
        else { & $bad ("the derived row came back {0} with inputs [{1}], wanted RESOLVED-DERIVED naming 5 and the price" -f $(if ($null -eq $dv) { 'MISSING' } else { $dv.disposition + '/' + $dv.kind }), $(if ($null -eq $dv) { '' } else { (@($dv.derivedInputs) -join ', ') })) }

        $dvm = & $get 'PLANT-DERIVED-MISSING carton total'
        if ($null -ne $dvm -and $dvm.disposition -eq 'UNRESOLVED' -and $dvm.kind -eq 'derived-input-absent' -and
            (@($dvm.derivedMissing)[0] -eq '$999.00') -and $dvm.note -match '\$999\.00') {
            & $ok 'the DERIVED row whose input is in no source is UNRESOLVED naming THAT input, not the computed value'
        }
        else { & $bad ("the derived-missing row came back {0}, missing [{1}]" -f $(if ($null -eq $dvm) { 'MISSING' } else { $dvm.disposition + '/' + $dvm.kind }), $(if ($null -eq $dvm) { '' } else { (@($dvm.derivedMissing) -join ', ') })) }

        #  THE SAME ROW, WITH ITS PRICE TAKEN OUT OF THE CORPUS. Two rows that
        #  differ in the registry prove the rule reads the registry; this proves
        #  it reads the CORPUS, on one identical row against two corpora.
        $noPrice = New-Object System.Collections.Generic.List[object]
        foreach ($d in @($src.Docs)) {
            $txt = $d.Text -replace '\$250\.00', 'the agreed rate'
            $noPrice.Add((New-ProvDoc -Name $d.Name -Path $d.Path -Audience $d.Audience -Text $txt))
        }
        $stillPriced = @(Find-ProvValue -Value '$250.00' -Docs $noPrice.ToArray() -Max 1)
        $rowA = [pscustomobject]@{ Register = 'figures.json'; File = 'figures.json'; Field = 'figures[99].require[0]'
                                   Name = 'PLANT-DERIVED-OK carton total'; Value = '$1,250.00'; Authority = 'P'
                                   Classes = @('P'); Locator = 'DERIVED from 5 cartons at $250.00'; DerivedFrom = @() }
        $ctxA = [pscustomobject]@{ Docs = $noPrice.ToArray(); Cells = @(); Alias = @{}; Patterns = $pats; Classes = @('P'); VenueTokens = @(); Allow = @{}; Derived = $null }
        $script:ValueCache = @{}; $script:DerivedInputCache = @{}
        $ctxA.Derived = Resolve-ProvDerivedChains -Rows @($rowA) -Ctx $ctxA
        $recA = @(Test-ProvRow -Row $rowA -Ctx $ctxA)[0]
        $script:ValueCache = @{}; $script:DerivedInputCache = @{}
        if ($stillPriced.Count -eq 0 -and $recA.disposition -eq 'UNRESOLVED' -and (@($recA.derivedMissing)[0] -eq '$250.00') -and $recA.note -match '\$250\.00') {
            & $ok 'the SAME derived row against a corpus with the price removed is UNRESOLVED naming that price specifically - the disposition follows the corpus, not the wording'
        }
        else { & $bad ("the same row against the stripped corpus came back {0}, missing [{1}] (price still present: {2})" -f $recA.disposition, (@($recA.derivedMissing) -join ', '), $stillPriced.Count) }

        $dvn = & $get 'PLANT-DERIVED-NO-INPUTS tray count'
        if ($null -ne $dvn -and $dvn.disposition -eq 'UNRESOLVED' -and $dvn.kind -eq 'derived-no-inputs' -and $dvn.note -match 'derivedFrom') {
            & $ok 'a DERIVED row naming no input of any shape is UNRESOLVED naming the registry fix - it is not passed, and it is not called a fabricated figure either'
        }
        else { & $bad ("the derived-no-inputs row came back {0}" -f $(if ($null -eq $dvn) { 'MISSING' } else { $dvn.disposition + '/' + $dvn.kind })) }

        # the report itself must be writable and re-readable
        $rp = Join-Path $fixture 'provenance-report.json'
        Write-ProvReport -Run $run -Path $rp
        $back = Get-GateJson -Path $rp
        if ($null -ne $back -and @($back.registry).Count -eq @($run.Registry).Count) { & $ok 'the report writes and parses back with every registry record' }
        else { & $bad 'the report did not write, or did not parse back' }

        #  EVERY BLOCKING RECORD REACHES findings[] IN THE ANCHORED SHAPE -
        #  through Lib-GateCommon's New-GateFinding where it exists, and in
        #  today's shape where it does not. A finding with no quote cannot be
        #  re-found, and P1-14's anchor test would have nothing to test.
        $fset = @($back.findings)
        $fbad = @($fset | Where-Object { -not "$($_.Rule)".Trim() -or -not "$($_.File)".Trim() -or -not "$($_.Field)".Trim() -or -not "$($_.Quote)".Trim() })
        if ($fset.Count -eq $blocking.Count -and $fbad.Count -eq 0) {
            & $ok ("every one of the {0} blocking record(s) is written to findings[] with a Rule, a File, a Field and a non-empty Quote{1}" -f $fset.Count, $(if (Get-Command -Name 'New-GateFinding' -ErrorAction SilentlyContinue) { ' (through Lib-GateCommon New-GateFinding)' } else { ' (in this file''s fallback shape)' }))
        }
        else { & $bad ("findings[] carries {0} entr(ies) for {1} blocking record(s), {2} of them missing a required field" -f $fset.Count, $blocking.Count, $fbad.Count) }

        # ===================================================================
        #  The band arms, run as CHILD PROCESSES so the EXIT CODE is asserted.
        # ===================================================================
        function Invoke-ProvChild {
            param([hashtable] $Params)
            $op = Join-Path $fixture ('child_' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.json')
            $global:LASTEXITCODE = 0
            $text = & $script:Self @Params -OutPath $op -Quiet *>&1 | Out-String -Width 4096
            $code = $LASTEXITCODE
            $body = $null
            if (Test-Path -LiteralPath $op) { $body = Get-GateJson -Path $op }
            return [pscustomobject]@{ Code = $code; Report = $body; Text = $text }
        }

        # -Stage 7c with NO extract: a rendered arm with no rendering.
        $c7 = Invoke-ProvChild @{ BuildDir = $fixture; Stage = '7c' }
        if (($c7.Code -eq 2) -and ($c7.Text -match 'guide_gate\.txt') -and ($c7.Text -match 'deck_gate\.txt')) {
            & $ok '-Stage 7c with zero -DocText exits 2 naming guide_gate.txt and deck_gate.txt'
        }
        else { & $bad ("-Stage 7c with no extract exited {0} (wanted 2); extracts named: {1}" -f $c7.Code, (($c7.Text -match 'guide_gate\.txt') -and ($c7.Text -match 'deck_gate\.txt'))) }

        # -Stage 7c WITH both extracts: the rendered arm runs over real lines.
        $c7b = Invoke-ProvChild @{ BuildDir = $fixture; Stage = '7c'; DocText = @((Join-Path $fixture 'guide_gate.txt'), (Join-Path $fixture 'deck_gate.txt')) }
        $rendArm = @(@($c7b.Report.arms) | Where-Object { $_.name -eq 'rendered' })
        if (($rendArm.Count -eq 1) -and ($rendArm[0].state -eq 'ran') -and ($rendArm[0].size -ge 4) -and ($c7b.Text -match 'rendered\|true\|ran\|')) {
            & $ok ("-Stage 7c with both extracts runs the rendered arm over {0} line(s) of the delivered documents" -f $rendArm[0].size)
        }
        else { & $bad ("the rendered arm did not run: {0}" -f $(if ($rendArm.Count -eq 1) { $rendArm[0].state + '/' + $rendArm[0].size } else { 'MISSING from the roster' })) }

        # ---- THE SEED ARMS. Registry against corpus, no spine at all.
        $seedDir = Join-Path $fixture 'seedcopy'
        New-Item -ItemType Directory -Force -Path $seedDir | Out-Null
        Copy-Item -LiteralPath (Join-Path $fixture 'contract.json') -Destination $seedDir
        Copy-Item -LiteralPath (Join-Path $fixture 'figures.json') -Destination $seedDir
        Copy-Item -LiteralPath (Join-Path $fixture 'corpus') -Destination $seedDir -Recurse
        $cs = Invoke-ProvChild @{ BuildDir = $seedDir; SeedOnly = $true; Stage = '2' }
        $seedRows = @(@($cs.Report.registry))
        $seedNotRun = @($seedRows | Where-Object { $_.disposition -eq 'NOT RUN' })
        $seedUnres  = @($seedRows | Where-Object { $_.disposition -eq 'UNRESOLVED' })
        $seedDerived = @($seedRows | Where-Object { $_.disposition -eq 'RESOLVED-DERIVED' })
        $seedUnloc  = @($seedRows | Where-Object { $_.disposition -eq 'UNLOCATED' })
        $seedDeferred = ($cs.Text -match 'attribution\|true\|deferred') -and ($cs.Text -match 'venue\|true\|deferred')
        if (($cs.Code -eq 1) -and ($seedNotRun.Count -eq 0) -and ($seedDerived.Count -eq 1) -and ($seedUnres.Count -eq 5) -and ($seedUnloc.Count -eq 1) -and $seedDeferred) {
            & $ok 'seed arms: with no spine at all the registry is read against the corpus - exit 1, the derived row RESOLVED-DERIVED, five UNRESOLVED, one UNLOCATED, NOTHING recorded NOT RUN, and the two spine arms deferred by name'
        }
        else { & $bad ("seed arms: exit {0} (wanted 1); NOT RUN {1} (wanted 0); RESOLVED-DERIVED {2} (wanted 1); UNRESOLVED {3} (wanted 5); UNLOCATED {4} (wanted 1); spine arms deferred {5}" -f $cs.Code, $seedNotRun.Count, $seedDerived.Count, $seedUnres.Count, $seedUnloc.Count, $seedDeferred) }

        # ===================================================================
        #  THE ADJUDICATION CHANNEL. A build with ONE row - the unlocated one -
        #  so the exit code is the row's and nothing else's.
        # ===================================================================
        $alwDir = Join-Path $fixture 'allowcopy'
        New-Item -ItemType Directory -Force -Path $alwDir | Out-Null
        Copy-Item -LiteralPath (Join-Path $fixture 'contract.json') -Destination $alwDir
        Copy-Item -LiteralPath (Join-Path $fixture 'corpus') -Destination $alwDir -Recurse
        $oneRow = [ordered]@{ name = 'PLANT-UNLOCATED bench rest'; authority = 'P'
                              source = 'Fixture Recipe Workbook, the pickling schedule appendix'
                              require = @('25 minutes') }
        $encA = New-Object System.Text.UTF8Encoding($false)
        $alwPath = Join-Path $alwDir 'figures.json'

        [System.IO.File]::WriteAllText($alwPath, (([ordered]@{ figures = @($oneRow) }) | ConvertTo-Json -Depth 8), $encA)
        $ca1 = Invoke-ProvChild @{ BuildDir = $alwDir; SeedOnly = $true; Stage = '2' }
        if (($ca1.Code -eq 1) -and ($ca1.Text -match 'UNLOCATED')) { & $ok 'an UNLOCATED row on its own exits 1 and names the class - it never silently passes' }
        else { & $bad ("the unlocated-only build exited {0} (wanted 1); UNLOCATED named: {1}" -f $ca1.Code, ($ca1.Text -match 'UNLOCATED')) }

        [System.IO.File]::WriteAllText($alwPath, (([ordered]@{
            figures = @($oneRow)
            provenanceAllow = @([ordered]@{ value = '25 minutes'
                                            reason = 'The workbook has no appendix headings in this extraction; the bench rest line was read by hand on 8 September 2026 and the figure is correct. Locator to be repointed at Task 4(b) in the next registry pass.' })
        }) | ConvertTo-Json -Depth 8), $encA)
        $ca2 = Invoke-ProvChild @{ BuildDir = $alwDir; SeedOnly = $true; Stage = '2' }
        $ca2Rec = @(@($ca2.Report.registry) | Where-Object { $_.disposition -eq 'UNLOCATED' })
        if (($ca2.Code -eq 0) -and ($ca2Rec.Count -eq 1) -and (-not $ca2Rec[0].blocking) -and ("$($ca2Rec[0].allowReason)" -match 'read by hand')) {
            & $ok 'a provenanceAllow entry WITH a written reason clears the exit and keeps the row, its class and its reason in the report - adjudicated, not deleted'
        }
        else { & $bad ("the allowed build exited {0} (wanted 0); UNLOCATED records {1}; blocking {2}" -f $ca2.Code, $ca2Rec.Count, $(if ($ca2Rec.Count -gt 0) { $ca2Rec[0].blocking } else { 'n/a' })) }

        [System.IO.File]::WriteAllText($alwPath, (([ordered]@{
            figures = @($oneRow)
            provenanceAllow = @([ordered]@{ value = '25 minutes' })
        }) | ConvertTo-Json -Depth 8), $encA)
        $ca3 = Invoke-ProvChild @{ BuildDir = $alwDir; SeedOnly = $true; Stage = '2' }
        if (($ca3.Code -eq 2) -and ($ca3.Text -match 'provenanceAllow')) {
            & $ok 'a provenanceAllow entry with NO written reason is REFUSED (exit 2) naming the list - an allow-list nobody can audit is a gate quietly switched off'
        }
        else { & $bad ("the reasonless allow entry exited {0} (wanted 2); provenanceAllow named: {1}" -f $ca3.Code, ($ca3.Text -match 'provenanceAllow')) }

        Remove-Item -LiteralPath (Join-Path $seedDir 'figures.json') -Force
        $cs2 = Invoke-ProvChild @{ BuildDir = $seedDir; SeedOnly = $true; Stage = '2' }
        if (($cs2.Code -eq 2) -and ($cs2.Text -match 'figures\.json')) { & $ok 'seed arms with no registry: exit 2 naming figures.json - a run with nothing to check is a refusal, not a pass' }
        else { & $bad ("a missing registry exited {0} (wanted 2); figures.json {1}" -f $cs2.Code, $(if ($cs2.Text -match 'figures\.json') { 'named' } else { 'NOT named' })) }
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
if ($Stage -and $Stage -notin @('2', '3c', '4', '7c')) {
    Fail-Usage ("-Stage '{0}' is not a band this gate runs at (2, 3c, 4 or 7c)." -f $Stage)
}

#  THE RENDERED ARM REFUSES AN EMPTY RENDERING. -Stage 7c says the delivered
#  documents are what is being judged; with no extract there is nothing to
#  judge, and printing a green line over that is the exact failure the 7c band
#  was found to have.
$extracts = @(@($DocText) | Where-Object { "$_".Trim() })
if ($Stage -eq '7c' -and $extracts.Count -eq 0) {
    Fail-Usage 'the rendered arm was asked for (-Stage 7c) and no extract was passed. Pass -DocText <guide extract>,<deck extract> - guide_gate.txt and deck_gate.txt, the extracts Get-DocText writes from the delivered .docx and .pptx. A rendered arm with no rendering examines nothing, and an arm that examines nothing does not pass.'
}
foreach ($x in $extracts) {
    if (-not (Test-Path -LiteralPath $x)) { Fail-Usage ("-DocText names an extract that is not there: {0}. The rendered arm reads guide_gate.txt and deck_gate.txt; an absent extract is refused by name rather than swept as an empty document." -f $x) }
}

if ($SeedOnly) {
    try { $run = Invoke-ProvSeed -RunBuildDir $BuildDir -RunCorpusDir $CorpusDir -RunPackDir $PackDir -RunRulesPath $RulesPath -RunQuiet:$Quiet }
    catch { Stop-OnRefusal $_ }
    $seedRoster = @()
    try { Assert-GateArmsComplete; $seedRoster = @(Write-GateArmRoster) } catch { Stop-OnRefusal $_ }
    if (-not $Quiet) { Write-ProvConsole -Run $run }
    if (-not $OutPath) { $OutPath = Join-Path $BuildDir 'provenance-seed-report.json' }
    Write-ProvReport -Run $run -Path $OutPath -Arms $seedRoster -Mode 'seed'
    $seedUnresolved = @($run.Registry | Where-Object { $_.disposition -eq 'UNRESOLVED' })
    $seedUnlocated  = @($run.Registry | Where-Object { $_.disposition -eq 'UNLOCATED' -and $_.blocking })
    Write-Host ''
    Write-Host ("  {0} registry row(s) read against {1} source document(s) as {2} record(s); {3} DERIVED row(s), {4} of them RESOLVED-DERIVED; report written: {5}" -f $run.Rows, @($run.Docs).Count, @($run.Registry).Count, $run.DerivedRows, @($run.Registry | Where-Object { $_.disposition -eq 'RESOLVED-DERIVED' }).Count, $OutPath) -ForegroundColor DarkGray
    if ($seedUnresolved.Count -gt 0 -or $seedUnlocated.Count -gt 0) {
        if ($seedUnresolved.Count -gt 0) {
            Write-Host ("  X {0} UNRESOLVED - a registered value its own named source does not carry, or a derived chain whose input resolves nowhere, found before a word was authored." -f $seedUnresolved.Count) -ForegroundColor Red
        }
        if ($seedUnlocated.Count -gt 0) {
            Write-Host ("  X {0} UNLOCATED - the locator names no place the document it names carries, so the row was never checked AT a locator. Fix the registry, or record a provenanceAllow entry with a written reason." -f $seedUnlocated.Count) -ForegroundColor Red
        }
        exit 1
    }
    if (@($run.LegalConflict).Count -gt 0) {
        Write-Host ("  X {0} L-class mandate conflict(s)." -f @($run.LegalConflict).Count) -ForegroundColor Red
        exit 5
    }
    Write-Host '  every registry row resolves in the source it names' -ForegroundColor Green
    exit 0
}

try { $run = Invoke-Provenance -RunBuildDir $BuildDir -RunSpineDir $SpineDir -RunCorpusDir $CorpusDir -RunPackDir $PackDir -RunRulesPath $RulesPath -RunDocText $extracts -RunStage $Stage -RunQuiet:$Quiet }
catch { Stop-OnRefusal $_ }
$roster = @()
try { Assert-GateArmsComplete; $roster = @(Write-GateArmRoster) } catch { Stop-OnRefusal $_ }
if (-not $Quiet) { Write-ProvConsole -Run $run }

if (-not $OutPath) { $OutPath = Join-Path $BuildDir 'provenance-report.json' }
Write-ProvReport -Run $run -Path $OutPath -Arms $roster

$unresolved = @(@($run.Registry) + @($run.Attribution) | Where-Object { $_.disposition -eq 'UNRESOLVED' })
$unlocated  = @(@($run.Registry) | Where-Object { $_.disposition -eq 'UNLOCATED' -and $_.blocking })
$nearMiss   = @(@($run.Registry) + @($run.Attribution) | Where-Object { $_.disposition -eq 'NEAR-MISS' })
$absent     = @(@($run.Registry) + @($run.Attribution) | Where-Object { $_.disposition -eq 'SOURCE-ABSENT' })
$derivedOk  = @(@($run.Registry) | Where-Object { $_.disposition -eq 'RESOLVED-DERIVED' })

Write-Host ''
Write-Host ("  {0} provenance row(s) as {1} record(s) ({2} DERIVED, {3} RESOLVED-DERIVED), {4} attributed sentence(s) swept over {5} spine cell(s) and {6} rendered line(s); report written: {7}" -f $run.Rows, @($run.Registry).Count, $run.DerivedRows, $derivedOk.Count, $run.Sentences, ($run.Cells - $run.RenderedLines), $run.RenderedLines, $OutPath) -ForegroundColor DarkGray

if ($unresolved.Count -gt 0 -or $unlocated.Count -gt 0) {
    if ($unresolved.Count -gt 0) {
        Write-Host ("  X {0} UNRESOLVED - a registered value or an attributed quantity that its own named source does not carry, or a derived chain whose input resolves nowhere." -f $unresolved.Count) -ForegroundColor Red
    }
    if ($unlocated.Count -gt 0) {
        Write-Host ("  X {0} UNLOCATED - the locator names no place the document it names carries, so 'at the locator' was never tested. Fix the locator, or record a provenanceAllow entry with a written reason." -f $unlocated.Count) -ForegroundColor Red
    }
    Write-Host ("    {0} NEAR-MISS and {1} SOURCE-ABSENT are reported above for adjudication and do not block." -f $nearMiss.Count, $absent.Count) -ForegroundColor Yellow
    exit 1
}
if (@($run.LegalConflict).Count -gt 0) {
    Write-Host ("  X {0} L-class mandate conflict(s) - a recommendation asserted as a legal requirement." -f @($run.LegalConflict).Count) -ForegroundColor Red
    exit 5
}
Write-Host ("  every registered value resolves in the source it names, and every attributed quantity carries a locator that resolves. {0} NEAR-MISS and {1} SOURCE-ABSENT reported for adjudication." -f $nearMiss.Count, $absent.Count) -ForegroundColor Green
exit 0
