<#
    Assert-FigureCoverage.ps1 - THE UNREGISTERED FIGURE SWEEP (gates.md section 17).

    THE INVERSION, AND IT IS THE WHOLE POINT. Test-FigureConsistency reads the
    registry and checks the figures somebody remembered to write down. That is a
    WHITELIST OF WHAT IS CHECKED, which is the exact inverse of a proof that
    nothing is unchecked. A figure nobody registered is a figure nobody is
    checking, and it passes that gate by being absent from it. On 27 August 2026
    a fabricated legal requirement shipped through exactly that hole, and a batch
    weight went the same way. One build's registry listed 31 figures against 112
    placed captioned figures and 116 drawing objects: four fifths of the numbers
    on the page were outside every gate in the file.

    So this gate starts from the CONTENT, not from the registry. It harvests
    every candidate claim the spine makes and requires each one to carry a
    DISPOSITION. It fails on any candidate with none.

      1. MATCHED    - a figures.json registry entry covers it. Matching is
                      variant-aware in the same way Test-FigureConsistency's is
                      - both gates call the one anchored builder - so
                      "20 gastronorm", "twenty gastronorm" and "20-tray" are one
                      figure and not three. AN ENTRY THAT DECLARES derivedFrom
                      CONFERS NO MATCH: it is claiming the value is computed
                      from named inputs, and the registration is the claim, not
                      the evidence. Matching on it dispositioned every derived
                      value by mere registration, left the derived arm below
                      unreachable by construction, and DERIVED fired 0 times out
                      of 185 candidates on the reference build while the report
                      read as though the arm had run.
      2. PRESENT    - the value occurs verbatim in a canonical source: the
                      corpus of extracted pack documents, or the unit extract.
                      The report names the source file and the line.
      3. DERIVED    - the content itself names its inputs, and every named input
                      itself resolves under 1, 2 or 3. Resolution runs to a
                      FIXPOINT, so a chain resolves: where a batch weight
                      resolves verbatim to a recipe card's own field and three
                      further figures name that weight as their input, all four
                      pass. That is correct behaviour, not a hole - see section
                      17's note and section 19 for what happens when a judgement
                      stage calls the same chain fabricated. EVERY named input
                      must resolve; where one does not, the reason names THE
                      FIRST one, because an author fixes a derivation by
                      supporting its first unsupported input and a reason that
                      lists five keys without saying where to start is a finding
                      nobody can close. Each DERIVED row prints its chain.

    WHY A DISPOSITION AND NOT A MATCH. Failing on every UNMATCHED value would
    fire on every legitimate derived figure in a teaching resource - a yield per
    portion, a total from a stated batch - and a builder would learn to ignore
    the gate inside one build. "Derived, from these named inputs" is a
    first-class answer. That keeps full coverage while making a clean run mean
    something.

    NO SEPARATE ALLOW-LIST EXISTS OR IS NEEDED: the disposition record IS the
    allow-list, versioned in figures.json with its reason (rule 3). Where the
    registry declares a group cover (see SUP-REGGROUP) that entry is read
    through Get-GateAllowList, so an entry with no written reason is refused.

    ----------------------------------------------------------------------------
    NOISE IS THE HARD PART AND IT IS SOLVED STRUCTURALLY, NEVER BY A LIST OF
    VALUES. A naive sweep of ~14,800 spine sentences returns thousands of hits
    and is switched off in a week, which is worse than no gate. Every narrowing
    below is a NAMED RULE with its reason, and every one prints how many
    candidate occurrences it removed, so the suppression is auditable in the log
    and in the report. An allow-list of VALUES would be a second registry that
    nobody reads; there is none here.

      SUP-BARENUM    The token after the number is a closed-class function word,
                     an auxiliary, an arithmetic connective or a reporting verb.
                     A number with no unit is not a number-with-unit token; it is
                     an operand, a cross-reference or a bare count of words in a
                     sentence. Modifier words are stepped OVER rather than
                     stopping the scan ("5 different methods" harvests as
                     "5 methods"), so this rule only ever widens coverage.
      SUP-WORDCOUNT  A number written as an ENGLISH WORD counting something that
                     is not a unit of measurement - "one dish", "two jobs",
                     "twelve methods". That is ordinary enumeration in running
                     prose, not a figure; it cannot be wrong the way a
                     temperature or a batch weight can. The same count written in
                     digits is still harvested, "two hours" is still harvested
                     because an hour is a unit, and a word-form spelling of a
                     REGISTERED figure is still caught by the variant-aware
                     MATCHED arm and by Test-FigureConsistency's variant sweep -
                     so this rule cannot hide a stale registered figure.
      SUP-PROMPTFIELD The candidate is in an artwork "prompt" field. A generation
                     prompt is an instruction to the image tool - camera angle,
                     lens, lighting - it is removed from the artefact at
                     placement, and section 30's prompt lint owns it. The
                     caption, alt text and spec of the same visual, which are
                     where a picture's figures are actually specified, are NOT
                     suppressed and are swept in full.
      SUP-REF        The number or named item is governed by a reference noun -
                     section, figure, table, topic, question, task, step, stage,
                     page, item, part, appendix, clause, element, criterion,
                     recipe, card, row, column, slide, schedule, version. A
                     pointer into a document is not a claim about the world, and
                     cross-references are gated by section 7 and section 28.
      SUP-DOTREF     A dotted number that is one of the SPINE'S OWN sub-section
                     refs, performance criteria or figure slots, followed by a
                     word that is not a unit - "1.3 Date marking" in a slide
                     kicker. The namespace is DERIVED from the spine, so a
                     measured decimal is never suppressed by it: 17.5 kg is in
                     no namespace and is harvested in full.
      SUP-ORDINAL    The candidate number is an ordinal (1st, 2nd, first,
                     second). An ordinal is a position in a sequence, not a
                     measured quantity.
      SUP-LISTNUM    A list counter at the head of a cell or a sentence
                     ("1.", "(2)", "3)"). It is numbering, gated by section 2.
      SUP-IDENT      An identifier: an ABN, ACN, CRICOS, RTO or provider number
                     read out of the build contract and the branding profile, or
                     a token of national unit-code SHAPE. DERIVED, never typed:
                     rule 5 forbids a literal unit, RTO, CRICOS or provider code
                     anywhere in a promoted gate, so the values come from the
                     contract and the code is matched by its shape.
      SUP-CITEYEAR   A four-digit year sitting in a citation frame (an Act, a
                     Regulation, a Standard, a Code, an edition or a
                     parenthesised year). The year is part of the instrument's
                     name; whether the instrument is cited correctly is section
                     18 and section 26, not this gate.
      SUP-QUOTED     The candidate sits inside a quoted run of six words or more.
                     A quoted learner instruction carries the quantity of the
                     instrument being quoted; whether that attribution resolves
                     is section 18's question, and dispositioning it here would
                     demand a registry entry for every task the guide quotes.
      SUP-REGGROUP   The candidate's anchor is declared covered AS A GROUP by a
                     registry entry ("covers": [...] with a written reason). A
                     recipe card reproduced as one registered figure is
                     dispositioned once, as that figure; demanding a separate
                     entry per cell of a card the registry already carries is how
                     a gate becomes unusable. Removes nothing when the registry
                     declares no groups, and says so.
      SUP-HEADFIELD  A NAMED ITEM harvested from a heading or label field. A
                     heading repeats the body it introduces, where the same words
                     are swept. Quantities are NOT suppressed by this rule -
                     a figure in a heading is still a figure.
      SUP-NICOMMON   A single-token capitalised NAMED ITEM whose lower-case form
                     the build itself also writes. A word this build writes in
                     lower case elsewhere is an ordinary noun capitalised by
                     position, not a proper name. Derived from the spine and the
                     corpus, never from a list. Multi-token phrases are never
                     suppressed by this rule.
      SUP-SENTINIT   A single-token capitalised NAMED ITEM at the start of a
                     sentence. Its capitalisation carries no information.
      SUP-EMPTYKEY   The candidate trimmed away to nothing: a named phrase that
                     was all function words or a lone possessive, or a key of
                     under three characters. These were three bare `continue`s
                     and one more in the quantity arm, so the span vanished off
                     the books and the printed suppression tally did not add up
                     to the raw harvest - a reader could not tell a deliberate
                     narrowing from a bug in the trimmer. Every narrowing is a
                     named rule; this one is no exception.

    THE HARVEST ARITHMETIC IS PRINTED AND CHECKED. rawSpans = candidate
    occurrences + suppressed occurrences, and the report says whether it
    balances. Spans folded into a longer value's unit continuation - the year
    inside "16 September 2026", the scale after "5 degrees" - are counted
    separately as consumed: they are harvested once, by the longer value, in
    the same way the clock and ratio masks have always worked. Blanking them
    is what stops a year seeding a second candidate ("2026 service" was a
    blocking finding on the reference build, assembled out of the tail of a
    date and the word after it).

    WHAT THE HARVESTER MAY NOT DO. It may not offer the reader a string that is
    not in the document. "7.45 am" cut to "45 am", "$250.00 and" glued out of an
    amount and the next word, "5 degrees below" glued out of a value and an
    ordinary English word - all three were reported as unsourced figures, and
    none of them can be registered, sourced or corrected, because none of them
    is written anywhere. So: a clock is a clock whether it is written with a
    colon or a full stop; a degree continues only into a temperature SCALE; a
    rate keeps the noun it governs; and on money and on a date, a tail the unit
    vocabulary does not know is cleared from the value and kept as the ANCHOR,
    which is the string the reader actually has to find.

    KEYS ARE LEMMATISED, SURFACES ARE KEPT. "4 cartons" and "4 carton" are one
    figure, so the key carries the lemma of the unit's last token; the spellings
    the build actually used are carried beside it and are what a source and a
    registry entry are searched for, or the lemmatiser would manufacture a
    finding out of a plural.

    WHAT THIS GATE CANNOT SEE, STATED PLAINLY. A generic lower-case equipment
    noun ("blast chiller") is harvested as a named item only when it is counted
    or capitalised. Harvesting every lower-case noun is a part-of-speech problem
    no regex solves, and a lexicon of equipment nouns derived from the corpus
    could only ever find items the corpus already contains - which are exactly
    the items that are never undispositioned. The quantity arm covers the case
    that matters, because an unsupported piece of equipment in a teaching
    resource almost always arrives with an unsupported number attached to it.

    ----------------------------------------------------------------------------
    TRUSTED ONLY AFTER FAILING ON A PLANTED DEFECT (rule 2). -SelfTest builds
    fixture builds in a temporary directory, plants four defects, VERIFIES EACH
    PLANT LANDED by reading the fixture back and confirming the exact text is in
    the exact channel this gate scans, then runs this script against them as a
    child process and asserts the outcome. A plant that did not land proves
    nothing and has passed a gate on this project before. The plants are: an
    unregistered temperature in a prose field; an unregistered named piece of
    equipment; a derivation whose named input does not resolve; and a candidate
    that IS registered, which must NOT fire. A clean fixture is run as well, so a
    gate that fails on everything cannot pass its own self-test.

    IT ALSO PROVES WHAT IT HARVESTS, not only what it fails on. Four sentences
    ("7.45 am", "$20.00 x 4 cartons", "5 degrees C", "20 per tray") must yield
    EXACTLY five candidates and no sixth, because the defect was never a missing
    candidate - it was an extra one the harvester invented out of the tail of a
    value and the word after it. A registry entry declaring derivedFrom must
    read DERIVED naming its inputs and never MATCHED by registration, and must
    read UNRESOLVED naming the input when one of them is in no source. A spine
    value that occurs in the corpus only as a digit substring of a longer value
    must not read PRESENT, and the longer value itself still must. Every one of
    those has a clean control beside it, and on every fixture run the harvest
    arithmetic has to close.

    OUTPUT NEVER QUOTES A SOURCE. Where a candidate is PRESENT the report names
    the source file and the line NUMBER and stops. It never prints assessor-guide
    text, a model answer or a benchmark row: the only sentences this gate quotes
    are the guide's own, from the spine.

    Runs at Stage 3c on the spine, again before every Stage 7 re-render, and at
    7c over the rendered text of both artefacts (-DocText). The rendered arm is
    optional because no document exists at 3c, and the report records in
    renderedArmRan whether it ran - section 11's failure was an optional
    -DocText the runner silently never passed, so its absence is stated rather
    than assumed.

    Usage:
      Assert-FigureCoverage -BuildDir <dir>
      Assert-FigureCoverage -BuildDir <dir> -DocText guide.txt,deck.txt
      Assert-FigureCoverage -SelfTest

    THE RENDERED ARM IS NO LONGER OPTIONAL AT 7c. -Stage 7c says the delivered
    documents are what is being judged; passed without -DocText it exits 2
    naming guide_gate.txt and deck_gate.txt. The optional -DocText the runner
    silently never passed is exactly how section 11's arm came to be recorded as
    having run when it had not.

    PS 5.1. ASCII only in this file.
    Exit 0 clean, 1 undispositioned candidate(s), 2 a usage or input error,
    4 the self-test failed.
#>

# GATE: stages=3c,4,7c; requires=BuildDir; 7c: DocText

[CmdletBinding()]
param(
    [string] $BuildDir,
    [string] $SpineDir,
    [string] $CorpusDir,
    [string] $RulesPath,
    #  The band this run stands for (3c, 4 or 7c). At 7c the rendered arm is
    #  required; an unknown value is a usage error, not a silent no-op.
    [string] $Stage,
    #  Canonical sources beyond the corpus. The unit extract is the one that
    #  always applies; it is found beside the build when it is not passed.
    [string[]] $ExcludeText,
    #  Rendered extracts of both artefacts, for the 7c run. Absent at 3c, and
    #  the report says so rather than letting a spine-only run stand for both.
    [string[]] $DocText,
    [string] $ReportPath,
    #  How many undispositioned candidates the console prints. The COMPLETE
    #  work order is always in the report file - a finding cannot be closed
    #  against the 25 lines that fitted on a console.
    [int] $MaxWorkOrder = 40,
    [switch] $SelfTest,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

$GATE = 'Assert-FigureCoverage'

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

# ---------------------------------------------------------------------------
# Closed-class English vocabularies.
#
# These are lexical recognisers for the English language, not check-sets of
# this build's values, and rule 1 is satisfied by every SET THIS GATE CHECKS
# being derived: the candidates come from the spine, the registry from
# figures.json, the sources from the corpus, the identifiers from the contract.
# Nothing below is a value from any build, any unit or any brand.
# ---------------------------------------------------------------------------

#  Words that end a noun phrase. A number followed by one of these carries no
#  unit. Prepositions, conjunctions, pronouns, determiners, auxiliaries, the
#  arithmetic connectives, and the shared reporting-verb list section 18 uses.
$script:CVG_STOP = @(
    'a','an','the','and','or','but','if','so','than','then','that','this','these','those',
    'of','in','on','at','to','for','from','with','by','as','into','onto','over','under',
    'per','out','up','down','off','about','across','after','before','between','through',
    'is','are','was','were','be','been','being','am','has','have','had','do','does','did',
    'will','would','can','could','shall','should','may','might','must','need','needs',
    'it','its','he','she','they','them','you','your','we','our','i','who','what','which',
    'when','where','why','how','not','no','nor','both','each','every','all','any','some',
    'multiplied','multiply','divided','divide','times','plus','minus','equals','x',
    'states','state','says','say','gives','give','lists','list','shows','show','carries',
    'carry','specifies','specify','records','record','requires','require','flags','flag',
    'uses','use','asks','ask','makes','make','tells','tell','runs','run','holds','hold',
    'contains','contain','covers','cover','places','place','means','mean','becomes',
    'goes','comes','sits','reads','writes','takes','gets','sets','puts','leaves','bakes',
    'cooks','cook','check','checks','more','less','fewer','most','least','only','also',
    'there','here','because','while','until','since','during','without','within','again'
)
#  Modifiers a number may carry before its unit. Stepping OVER one of these
#  WIDENS the harvest ("5 different methods" -> "5 methods"); it can never hide
#  a candidate, so a short list here costs no coverage.
$script:CVG_MODIFIER = @(
    'different','separate','individual','other','further','additional','extra','whole',
    'full','new','same','own','key','main','common','standard','named','planned','total',
    'complete','entire','single','usable','finished','raw','cooked','chilled','frozen'
)
#  Nouns that make the number after them a POINTER, not a measurement.
$script:CVG_REFNOUN = @(
    'section','sections','figure','figures','fig','table','tables','topic','topics',
    'question','questions','task','tasks','step','steps','stage','stages','page','pages',
    'item','items','part','parts','appendix','appendices','clause','clauses',
    'element','elements','criterion','criteria','recipe','recipes','card','cards',
    'row','rows','column','columns','slide','slides','schedule','version','no','number',
    'chapter','division','subsection','paragraph','regulation','regulations','act',
    'standard','standards','code','note','notes','activity','activities','round'
)
$script:CVG_MONTH = @('january','february','march','april','may','june','july','august',
                      'september','october','november','december')
#  Units of measurement. This is the English (and SI) system of units, not a set
#  of this build's values - nothing here is a figure, a brand or a unit code. It
#  separates a MEASURED quantity from an ordinary English enumeration, and it is
#  used by exactly one rule, SUP-WORDCOUNT.
$script:CVG_MEASURE = @(
    'degrees','degree','c','f','k','celsius','fahrenheit',
    'g','gm','gms','gram','grams','kg','kgs','kilogram','kilograms','mg','t','tonne','tonnes',
    'lb','lbs','oz','ounce','ounces','pound','pounds',
    'ml','l','litre','litres','liter','liters','cl','dl','cup','cups','tsp','tbsp',
    'mm','cm','m','metre','metres','meter','meters','km','in','inch','inches','ft','foot','feet',
    'sec','secs','second','seconds','min','mins','minute','minutes','hr','hrs','hour','hours',
    'day','days','week','weeks','fortnight','month','months','year','years',
    'am','pm','noon','midnight','ph','bar','psi','rpm','w','kw','kj','kcal','cal',
    'percent','per','cent','portion','portions','serve','serves','serving','servings','dollars'
) + $script:CVG_MONTH
#  Digits <-> English word forms, exactly as Test-FigureConsistency expands
#  them, so the two gates agree on what counts as one figure. A leaked capacity
#  was "fixed" by deleting the literal "20 gastronorm" and survived a full
#  audit round as "twenty gastronorm", "20-tray" and "6 of 20".
$script:CVG_W2N = @{ zero=0; one=1; two=2; three=3; four=4; five=5; six=6; seven=7; eight=8
                     nine=9; ten=10; eleven=11; twelve=12; thirteen=13; fourteen=14
                     fifteen=15; sixteen=16; seventeen=17; eighteen=18; nineteen=19
                     twenty=20; thirty=30; forty=40; fifty=50; sixty=60; seventy=70
                     eighty=80; ninety=90 }
$script:CVG_N2W = @{}
foreach ($cvgK in $script:CVG_W2N.Keys) { $script:CVG_N2W[[string]$script:CVG_W2N[$cvgK]] = $cvgK }
$script:CVG_NUMWORD = (($script:CVG_W2N.Keys | Sort-Object) -join '|') + '|hundred|thousand'

#  Leaf fields that are headings or labels rather than body content.
$script:CVG_HEADFIELD = @('title','heading','headline','label','name','term','kicker','lead')

$script:CVG_STOPSET = @{}
foreach ($cvgK in $script:CVG_STOP)     { $script:CVG_STOPSET[$cvgK] = $true }
$script:CVG_MODSET = @{}
foreach ($cvgK in $script:CVG_MODIFIER) { $script:CVG_MODSET[$cvgK] = $true }
$script:CVG_REFSET = @{}
foreach ($cvgK in $script:CVG_REFNOUN)  { $script:CVG_REFSET[$cvgK] = $true }
$script:CVG_MONTHSET = @{}
foreach ($cvgK in $script:CVG_MONTH)    { $script:CVG_MONTHSET[$cvgK] = $true }
$script:CVG_MEASURESET = @{}
foreach ($cvgK in $script:CVG_MEASURE)  { $script:CVG_MEASURESET[$cvgK] = $true }

#  THE ONLY WORDS THAT MAY CONTINUE A DEGREE VALUE. "5 degrees C" is one figure
#  and "5 degrees below" is a figure followed by an ordinary English word. The
#  open continuation glued whatever word came next onto the value and then
#  reported the result - a string the document does not contain - as an
#  unsourced figure. The set of temperature scales is closed, so this is a
#  closed-class recogniser like every other vocabulary in this file, not a list
#  of any build's values.
$script:CVG_DEGSCALE = @('c','celsius','f','fahrenheit','k')
$script:CVG_DEGRX = '(?i)^\s*(' + (($script:CVG_DEGSCALE | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\b'

#  REQUEST: Lib-GateCommon Get-GateSingular
#  Lifted from New-WithholdRegister.ps1's Get-Singular, which this agent does not
#  own. One behaviour, two copies until the coordinator collapses them.
function Get-CoverageSingular {
    param([string] $Word)
    if ($null -eq $Word) { return '' }
    if ($Word.Length -gt 4 -and $Word.EndsWith('ies')) { return $Word.Substring(0, $Word.Length - 3) + 'y' }
    if ($Word.Length -gt 4 -and $Word -match '(ss|sh|ch|x|z)es$') { return $Word.Substring(0, $Word.Length - 2) }
    if ($Word.Length -gt 3 -and $Word.EndsWith('s') -and -not $Word.EndsWith('ss')) { return $Word.Substring(0, $Word.Length - 1) }
    return $Word
}

function Get-CoverageUnitLemma {
    <#  Lemmatise the HEAD OF THE UNIT - its last token - so "4 cartons" and
        "4 carton" are one candidate rather than two.

        THE UNIT VOCABULARY GUARDS THE STEM. A word the vocabulary knows is
        only lemmatised when the lemma is also a word the vocabulary knows, so
        "celsius" does not become "celsiu" and "gms" does not become "gm" when
        the vocabulary carries both spellings as distinct units. A word the
        vocabulary does not know ("cartons", "trays") is lemmatised outright,
        which is the case this rule exists for.

        Only the LAST token moves: "degrees c" keeps its head, because the
        figure the reader sees is "5 degrees c" and not "5 degree c".  #>
    [CmdletBinding()]
    param([string] $Unit)

    if (-not "$Unit".Trim()) { return '' }
    $parts = @("$Unit".ToLowerInvariant() -split '\s+' | Where-Object { $_ })
    if ($parts.Count -eq 0) { return '' }
    $last = $parts[$parts.Count - 1]
    if ($script:CVG_MEASURESET.ContainsKey($last)) {
        $s = Get-CoverageSingular $last
        if ($script:CVG_MEASURESET.ContainsKey($s)) { $last = $s }
    }
    else { $last = Get-CoverageSingular $last }
    $parts[$parts.Count - 1] = $last
    return ($parts -join ' ')
}

# ---------------------------------------------------------------------------
# Private helpers. New helpers live HERE and not in Lib-GateCommon: this gate
# owns them, and a shared library grows a private need into a public contract.
# ---------------------------------------------------------------------------

$script:CVG_VARIANTCACHE = @{}

function ConvertTo-CoverageVariantRegex {
    <#  A candidate as a regex that matches THE VALUE AND NOTHING LONGER.

        THE BOUNDARY IS NOT BUILT HERE. Lib-GateCommon's
        Get-GateValueBoundaryRegex is the ONE definition of what a token
        boundary is, and this gate composes only the VARIANT ALTERNATION and
        hands it over with -Raw. Two definitions of a boundary is two answers to
        "does this value appear in that document", which is the defect, not the
        fix. Test-FigureConsistency composes the same alternation and calls the
        same builder, so the two figure gates cannot disagree about what counts
        as one figure.

        WHY IT IS ANCHORED AT ALL. The unanchored form matched "7.5 L" inside
        "17.5 L" and reported a figure this build never wrote as PRESENT in a
        source that says something else; two of the three variant PRESENT
        dispositions on the reference build were wrong for exactly that reason,
        and a wrong PRESENT is a figure that leaves the gate silently.

        -AllowPlural, because a bare boundary would stop "20 gastronorm"
        matching "20 gastronorms" and NARROW the arms this gate shares with
        Test-FigureConsistency; a fix that quietly removes a check is not a fix.
        -IgnoreCase, because a figure is the same figure in either case.

        Standalone numbers also match their English word form and listed words
        their digits, with spaces matching hyphens, so "20 gastronorm",
        "twenty gastronorm" and "20-tray" are one figure and not three.

        MEMOISED. It is asked for once per candidate per registry entry and once
        per candidate per source; on a real build that is tens of thousands of
        rebuilds of a few hundred patterns, and a gate too slow to be run is a
        gate that is not run.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Literal)

    if ($script:CVG_VARIANTCACHE.ContainsKey($Literal)) { return $script:CVG_VARIANTCACHE[$Literal] }
    #  An empty literal matches at every position, which is exactly how a gate
    #  prints PRESENT over a file that never carried the value. The shared
    #  builder throws on it; this returns the pattern that never matches.
    $rx = '(?!)'
    if ("$Literal".Trim()) {
        $n2w = $script:CVG_N2W
        $inner = [regex]::Escape($Literal)
        $inner = [regex]::Replace($inner, '\\ ', '[\s-]+')
        $inner = [regex]::Replace($inner, '(?<![\d.])(\d{1,2})(?![\d.])', {
            param($m); $d = $m.Groups[1].Value
            if ($n2w.ContainsKey($d)) { "(?:$d|$($n2w[$d]))" } else { $d }
        })
        foreach ($w in $script:CVG_W2N.Keys) {
            $inner = [regex]::Replace($inner, "(?i)\b$w\b", "(?:$w|$($script:CVG_W2N[$w]))")
        }
        $rx = Get-GateValueBoundaryRegex -Value $inner -Raw -AllowPlural -IgnoreCase
    }
    $script:CVG_VARIANTCACHE[$Literal] = $rx
    return $rx
}

function New-CoverageSourceIndex {
    <#  One canonical source, normalised once, with an offset -> line map.

        WHY AN OFFSET MAP AND NOT A LINE LOOP. A gate that scans 15,000 source
        lines per candidate for 1,500 candidates does 22 million string
        comparisons and is too slow to be run, and a gate too slow to be run is
        a gate that is not run. One IndexOf over the whole normalised document
        then a binary search for the line is the same answer in milliseconds,
        and PRESENT has to name the line or it is not a locator.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][AllowEmptyString()][string] $Text
    )

    $srcLines = $Text -split "`r?`n"
    $sb = New-Object System.Text.StringBuilder
    $starts = New-Object System.Collections.Generic.List[int]
    $nums   = New-Object System.Collections.Generic.List[int]
    for ($i = 0; $i -lt $srcLines.Count; $i++) {
        $n = ConvertTo-GateNormal $srcLines[$i]
        if (-not $n) { continue }
        [void]$sb.Append(' ')
        $starts.Add($sb.Length)
        [void]$sb.Append($n)
        $nums.Add($i + 1)
    }
    [void]$sb.Append(' ')
    return [pscustomobject]@{
        Name   = $Name
        Path   = $Path
        Norm   = $sb.ToString()
        Starts = $starts.ToArray()
        Lines  = $nums.ToArray()
        LineCount = $srcLines.Count
    }
}

function Get-CoverageSourceLine {
    <# Binary-search a character offset in a source index back to its line. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Index, [Parameter(Mandatory)][int] $Offset)

    $lo = 0; $hi = $Index.Starts.Length - 1; $best = -1
    while ($lo -le $hi) {
        $mid = [int](($lo + $hi) / 2)
        if ($Index.Starts[$mid] -le $Offset) { $best = $mid; $lo = $mid + 1 } else { $hi = $mid - 1 }
    }
    if ($best -lt 0) { return 0 }
    return $Index.Lines[$best]
}

function Find-CoverageInSources {
    <#  Disposition 2. Verbatim first (fast, and it is what "verbatim" means),
        then the variant form, so a corpus that writes "twenty" where the spine
        writes "20" still SOURCES the figure rather than reporting it missing.
        Returns the source name and line, or $null.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string] $Needle,
        #  THE SURFACE FORMS THIS CANDIDATE WAS ACTUALLY WRITTEN IN. The key is
        #  lemmatised ("4 cartons" -> "4 carton") so two spellings are one
        #  figure; a source that writes the plural must still SOURCE it, or the
        #  lemmatiser would manufacture a finding out of a spelling.
        [string[]] $Also,
        [Parameter(Mandatory)] $Indexes
    )

    $needles = New-Object System.Collections.Generic.List[string]
    if ($Needle) { $needles.Add($Needle) }
    foreach ($a in @($Also)) { if ($a -and -not $needles.Contains($a)) { $needles.Add($a) } }
    if ($needles.Count -eq 0) { return $null }

    foreach ($n in $needles) {
        $pad = ' ' + $n + ' '
        foreach ($ix in $Indexes) {
            $at = $ix.Norm.IndexOf($pad, [System.StringComparison]::Ordinal)
            if ($at -ge 0) {
                return [pscustomobject]@{ Source = $ix.Name; Line = (Get-CoverageSourceLine -Index $ix -Offset ($at + 1)); How = 'verbatim' }
            }
        }
    }
    foreach ($n in $needles) {
        $rx = ConvertTo-CoverageVariantRegex -Literal $n
        foreach ($ix in $Indexes) {
            $m = [regex]::Match($ix.Norm, $rx)
            if ($m.Success) {
                return [pscustomobject]@{ Source = $ix.Name; Line = (Get-CoverageSourceLine -Index $ix -Offset $m.Index); How = 'variant' }
            }
        }
    }
    return $null
}

function Split-CoverageSentences {
    <# One cell into sentences, keeping each one whole enough to be a work order. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Text)

    $out = New-Object System.Collections.Generic.List[string]
    foreach ($s in [regex]::Split($Text, '(?<=[.!?])\s+(?=[A-Z0-9"''(])')) {
        if ("$s".Trim()) { $out.Add("$s".Trim()) }
    }
    if ($out.Count -eq 0 -and "$Text".Trim()) { $out.Add("$Text".Trim()) }
    return $out.ToArray()
}

function Get-CoverageQuotedSpans {
    <# Character ranges inside a quoted run of six words or more. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Sentence)

    $spans = New-Object System.Collections.Generic.List[object]
    #  Curly quotes are written as \u escapes, never as the characters: this file
    #  is ASCII, and PS 5.1 decodes a BOM-less .ps1 as ANSI, which would corrupt
    #  any literal it carried and silently stop this rule matching.
    foreach ($m in [regex]::Matches($Sentence, '"([^"]{8,})"|\u201C([^\u201D]{8,})\u201D|''([^'']{12,})''')) {
        $inner = $m.Value
        if (@($inner -split '\s+' | Where-Object { $_ }).Count -ge 6) {
            $spans.Add([pscustomobject]@{ Start = $m.Index; End = ($m.Index + $m.Length) })
        }
    }
    return $spans.ToArray()
}

# ---------------------------------------------------------------------------
# The self-test lives at the foot of this file; the gate body runs first so a
# child self-test process executes exactly the code the real run executes.
# ---------------------------------------------------------------------------

function Invoke-CoverageGate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Dir,
        [string] $Spine,
        [string] $Corpus,
        [string] $Rules,
        [string[]] $Shared,
        [string[]] $Rendered,
        #  NOT $Report. POWERSHELL VARIABLE NAMES ARE CASE-INSENSITIVE, so a body
        #  variable $report holding the report OBJECT silently overwrites a
        #  parameter $Report holding its PATH; WriteAllText is then handed a
        #  PSCustomObject and throws "the given path's format is not supported"
        #  from a line that reads as correct. That is exactly what happened on
        #  the first run of this script, and the same collision cost an
        #  afternoon on this project two days earlier. The parameter and the
        #  object are named apart on purpose.
        [string] $OutReport,
        [int] $ShowMax = 40,
        #  The band this run stands for. At 7c the rendered arm is a blocking
        #  member of the roster instead of an optional extra.
        [string] $Band,
        [switch] $Silent
    )

    $say = -not $Silent

    # -- 1. canonical sources -------------------------------------------------
    $corpusResolved = Get-GateCorpusDir -BuildDir $Dir -CorpusDir $Corpus
    $corpusDocs = Get-GateCorpusDocs -CorpusDir $corpusResolved -BuildDir $Dir

    $sharedFiles = @($Shared | Where-Object { $_ })
    $sharedFrom = 'passed as -ExcludeText'
    if ($sharedFiles.Count -eq 0) {
        foreach ($sharedCand in @((Join-Path $Dir 'unit_extract.md'),
                            (Join-Path $Dir 'cleanroom\unit_extract.md'),
                            (Join-Path (Split-Path $Dir -Parent) 'unit_extract.md'))) {
            if (Test-Path -LiteralPath $sharedCand) { $sharedFiles = @($sharedCand); $sharedFrom = 'found beside the build'; break }
        }
    }

    $sourceIx = New-Object System.Collections.Generic.List[object]
    foreach ($d in $corpusDocs.Documents) {
        $sourceIx.Add((New-CoverageSourceIndex -Name $d.Name -Path $d.Path -Text $d.Text))
    }
    foreach ($x in $sharedFiles) {
        if (-not (Test-Path -LiteralPath $x)) { throw "$GATE`: -ExcludeText does not exist: $x" }
        $sourceIx.Add((New-CoverageSourceIndex -Name (Split-Path $x -Leaf) -Path $x -Text (Get-GateFileText -Path $x)))
    }
    $sourceArr = $sourceIx.ToArray()
    if ($sourceArr.Length -eq 0) {
        throw "$GATE`: no canonical source to disposition against. Stage 1 extracts every pack document exactly once; a coverage sweep with no source passes by having nothing to check against, and PRESENT would be unreachable."
    }
    $unitLoaded = ($sharedFiles.Count -gt 0)

    # -- 2. the registry ------------------------------------------------------
    $registry = Get-GateRegistry -BuildDir $Dir -RulesPath $Rules
    if ($null -eq $registry) {
        throw "$GATE`: no figures registry beside the build. Stage 2 locks one; without it every candidate would be undispositioned and the gate would say nothing useful."
    }
    $regEntries = New-Object System.Collections.Generic.List[object]
    foreach ($e in @($registry.figures)) {
        if ($null -eq $e) { continue }
        $bits = New-Object System.Collections.Generic.List[string]
        $bits.Add([string](Get-GateProp -Object $e -Names @('name') -Default ''))
        foreach ($r in @(Get-GateProp -Object $e -Names @('require') -Default @())) { if ($r) { $bits.Add([string]$r) } }
        foreach ($r in @(Get-GateProp -Object $e -Names @('value','values') -Default @())) { if ($r) { $bits.Add([string]$r) } }
        $bits.Add([string](Get-GateProp -Object $e -Names @('source') -Default ''))
        $inputs = @()
        foreach ($r in @(Get-GateProp -Object $e -Names @('derivedFrom','inputs') -Default @())) { if ($r) { $inputs += [string]$r } }
        $regEntries.Add([pscustomobject]@{
            Name   = [string](Get-GateProp -Object $e -Names @('name') -Default '(unnamed)')
            Norm   = (ConvertTo-GateNormal (($bits | Where-Object { $_ }) -join ' | '))
            Inputs = $inputs
        })
    }
    $regArr = $regEntries.ToArray()

    #  Group cover, read through the shared allow-list reader so an entry with
    #  no written reason is REFUSED rather than quietly honoured.
    $groupCover = @{}
    $groupReason = Get-GateAllowList -Registry $registry -Key 'coverageGroups' -IdField @('id','anchor','slot','path','covers') -GateName $GATE
    foreach ($gk in $groupReason.Keys) { $groupCover[$gk] = $groupReason[$gk] }

    # -- 3. identifiers, derived from the contract and the profile ------------
    $identTokens = New-Object System.Collections.Generic.List[string]
    $identFrom = New-Object System.Collections.Generic.List[string]
    $contract = Get-GateContract -BuildDir $Dir
    function Add-CoverageIdent {
        param($Node, [string] $Where, [int] $Depth = 0)
        if ($null -eq $Node -or $Depth -gt 6) { return }
        if ($Node -is [string] -or $Node -is [ValueType]) { return }
        if ($Node -is [System.Collections.IEnumerable]) { foreach ($i in $Node) { Add-CoverageIdent -Node $i -Where $Where -Depth ($Depth + 1) }; return }
        foreach ($p in @($Node.PSObject.Properties.Name)) {
            $v = $Node.$p
            if ($v -is [string] -or $v -is [ValueType]) {
                #  The FIELD must name an identifier AND the VALUE must have an
                #  identifier's SHAPE. Matching the field name alone swept in a
                #  prose sentence sitting under a field called "_why" beside a
                #  numbering note, and suppressed a real date as an identifier -
                #  a suppression rule that eats content is worse than no rule.
                #  Rule 5 forbids the literal codes, so the values are read here
                #  and the shapes are what is written down.
                $vs = "$v".Trim()
                if ($p -match '(?i)(abn|acn|cricos|rto|provider|unit|qualification|phone|fax)?(code|number|abn|acn|cricos)$' -and
                    ($vs -match '^[A-Za-z]{2,6}\d{3,8}[A-Za-z]?$' -or $vs -match '^\d[\d\s]{4,14}$')) {
                    $identTokens.Add($vs); $identFrom.Add(("{0}.{1}" -f $Where, $p))
                }
            }
            else { Add-CoverageIdent -Node $v -Where $Where -Depth ($Depth + 1) }
        }
    }
    if ($null -ne $contract) { Add-CoverageIdent -Node $contract -Where 'contract.json' }
    $identSet = @{}
    foreach ($t in $identTokens) {
        $tn = ConvertTo-GateNormal $t
        if ($tn) { $identSet[$tn] = $true }
        $bare = ($t -replace '[^0-9]', '')
        if ($bare.Length -ge 5) { $identSet[$bare] = $true }
    }
    $identNames = @()
    for ($ii = 0; $ii -lt $identTokens.Count; $ii++) { $identNames += ("{0} ({1})" -f $identTokens[$ii], $identFrom[$ii]) }

    # -- 4. the spine, every channel ------------------------------------------
    $skipFields = @{}
    foreach ($k in (Get-GateUnrenderedFields -BuildDir $Dir -ForSweep).Keys) { $skipFields[$k] = $true }

    $spineFiles = Get-GateSpineFiles -BuildDir $Dir -SpineDir $Spine
    #  Leaf -> rooted path, so a finding can name a file the anchor test can
    #  actually re-open. A finding that cites a file the build does not have has
    #  not examined the build.
    $fileFull = @{}
    foreach ($f in $spineFiles) { $fileFull[$f.Name] = $f.FullName }
    $cellList = New-Object System.Collections.Generic.List[object]
    foreach ($f in $spineFiles) {
        $j = Get-GateJson -Path $f.FullName
        if ($null -eq $j) { continue }
        foreach ($c in (Get-GateSpineCells -Node $j -File $f.Name -Path '' -Channel '' -Slot '' -Skip $skipFields)) { $cellList.Add($c) }
    }
    $spineCellCount = $cellList.Count

    $renderedFiles = @($Rendered | Where-Object { $_ })
    foreach ($d in $renderedFiles) {
        if (-not (Test-Path -LiteralPath $d)) { throw "$GATE`: -DocText does not exist: $d" }
        $leaf = Split-Path $d -Leaf
        $fileFull[$leaf] = (Resolve-Path -LiteralPath $d).ProviderPath
        $ln = 0
        foreach ($line in ((Get-GateFileText -Path $d) -split "`r?`n")) {
            $ln++
            if ("$line".Trim()) {
                $cellList.Add([pscustomobject]@{ File = $leaf; Path = ("line {0}" -f $ln); Channel = 'rendered'; Slot = ''; Text = "$line" })
            }
        }
    }
    $cellArr = $cellList.ToArray()

    #  THE SPINE'S OWN IDENTIFIER NAMESPACE, for SUP-DOTREF. Derived from the
    #  spine, never listed: every sub-section ref, performance criterion and
    #  figure slot the build uses. "1.3 Date marking" in a slide kicker is that
    #  sub-section's number followed by its heading, not one point three of
    #  anything - and "17.5 kg" is not in this set, so it is still harvested.
    $refNamespace = @{}
    foreach ($f in $spineFiles) {
        $j = Get-GateJson -Path $f.FullName
        if ($null -eq $j) { continue }
        foreach ($n in @('ref', 'pc', 'number')) {
            $v = Get-GateProp -Object $j -Names @($n)
            if ($v) { $refNamespace[(ConvertTo-GateNormal ([string]$v))] = $true }
        }
        foreach ($v in @($j.visuals)) {
            if ($null -eq $v) { continue }
            $s = Get-GateProp -Object $v -Names @('slot', 'figure')
            if ($s) { $refNamespace[(ConvertTo-GateNormal ([string]$s))] = $true }
        }
    }

    #  Lower-case vocabulary of the whole build, for SUP-NICOMMON. Derived from
    #  the spine and the corpus, never listed.
    $lowerVocab = @{}
    foreach ($c in $cellArr) {
        foreach ($m in [regex]::Matches($c.Text, '\b[a-z][a-z''\-]{2,}\b')) { $lowerVocab[$m.Value.ToLowerInvariant()] = $true }
    }
    foreach ($ix in $sourceArr) {
        foreach ($m in [regex]::Matches($ix.Norm, '\b[a-z][a-z]{2,}\b')) { $lowerVocab[$m.Value] = $true }
    }

    # -- 5. harvest -----------------------------------------------------------
    $rxNum = '(?<num>\$\s?\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\$\s?\d+(?:\.\d{1,2})?|\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?|\b(?:' + $script:CVG_NUMWORD + ')\b)'
    $rxQty  = '(?i)(?<![\w$.,])' + $rxNum + '(?<tail>(?:\s*-\s*|\s*)(?<unit>%|[A-Za-z][A-Za-z]{0,17}))?'
    #  A CLOCK IS A CLOCK WITH OR WITHOUT ITS MERIDIEM. "10:40" with no am after
    #  it fell through to the ratio pattern and was reported as the ratio 10:40,
    #  a value nobody wrote, beside the same clock time reported once already.
    #  A CLOCK IS WRITTEN WITH A COLON OR A FULL STOP. "7.45 am" is one clock,
    #  and the colon-only pattern left the dotted form to the quantity pass,
    #  which cut it at the decimal point and offered the reader "45 am" - a
    #  string the document does not contain, which nobody can register, source
    #  or correct. The dotted branch REQUIRES its meridiem, because "17.5 L"
    #  and "2.4 kg" are dotted numbers and not times of day.
    $rxClock= '(?i)(?<![\d.:])(?:(?<num>\d{1,2}:\d{2})\s*(?<unit>am|pm)?|(?<num>\d{1,2}\.\d{2})\s*(?<unit>am|pm))(?![\d:])'
    #  THE LOOKBEHIND IS WHAT STOPS A TIME STARTING INSIDE A LONGER NUMBER.
    #  Without it "\b\d{1,2}\s*am" matches the "45 am" inside "7.45 am" and the
    #  "40 am" inside "9.40 am". \b alone does not help: the digits either side
    #  of a full stop are both word characters, so there is a boundary there.
    $rxTime = '(?i)(?<![\d.:])\b(?<num>\d{1,2})\s*(?<unit>am|pm|noon|midnight)\b'
    $rxRatio= '(?i)(?<![\d.:])(?<num>\d{1,4})\s*:\s*(?<unit>\d{1,4})(?![\d.:])'
    $rxPh   = '(?i)\bp\s?H\s*(?:of\s*)?(?<num>\d(?:\.\d+)?)'
    $rxNamed= '\b[A-Z][A-Za-z0-9''\-]+(?:\s+(?:of|and|the|for|de|in|on|with)\s+[A-Z][A-Za-z0-9''\-]+|\s+[A-Z][A-Za-z0-9''\-]+)*'
    $rxArith= '(?i)(\bmultipl(?:y|ied)\b|\bdivid(?:e|ed)\b|\btimes\b|\bplus\b|\bminus\b|\badd(?:ed)?\b|\bsubtract(?:ed)?\b|\bscal(?:e|ed|ing)\b|\bsum\b|\bproduct\b|\btotals?\b|\bper\b|\d\s*[x*/+]\s*\d|\bat\s+\d)'
    $rxCue  = '(?i)\b(is|are|gives|give|equals|makes|comes to|totals|leaves|so)\b|='
    $rxCite = '(?i)\b(act|regulation|regulations|standard|standards|code|edition|amendment|version|cth|no)\b'

    $occ = New-Object System.Collections.Generic.List[object]
    $supCount = [ordered]@{}
    $supDistinct = [ordered]@{}
    $supSample = @{}
    foreach ($r in @('SUP-BARENUM','SUP-WORDCOUNT','SUP-REF','SUP-DOTREF','SUP-ORDINAL','SUP-LISTNUM',
                     'SUP-IDENT','SUP-CITEYEAR','SUP-QUOTED','SUP-REGGROUP','SUP-PROMPTFIELD',
                     'SUP-HEADFIELD','SUP-NICOMMON','SUP-SENTINIT','SUP-EMPTYKEY')) {
        $supCount[$r] = 0; $supDistinct[$r] = @{}; $supSample[$r] = New-Object System.Collections.Generic.List[string]
    }
    function Add-CoverageSuppressed {
        param([string] $Rule, [string] $Key, [string] $Shown)
        $supCount[$Rule] = $supCount[$Rule] + 1
        $supDistinct[$Rule][$Key] = $true
        if ($supSample[$Rule].Count -lt 3) { $supSample[$Rule].Add($Shown) }
    }
    #  EVERY HARVESTED SPAN IS ACCOUNTED FOR. A span either becomes a candidate
    #  occurrence or is removed by a NAMED rule that says how many it removed.
    #  A bare `continue` in the hit loop dropped spans off the books entirely,
    #  so the printed suppression tally did not add up to the harvest and no
    #  reader could tell a narrowing from a bug. rawSpans is asserted against
    #  occurrences + suppressed in the report and in the self-test.
    $rawSpans = 0
    #  Spans swallowed by a longer span's unit continuation ("2026" inside
    #  "16 September 2026"). Not a suppression: the characters are harvested
    #  once, by the longer candidate, exactly as the clock and ratio masks
    #  already work. Counted and reported so the arithmetic still closes.
    $consumedSpans = 0
    function Get-CoverageDistinctCount {
        #  .psbase.Count, NEVER .Count. A hashtable whose keys came from the
        #  content can hold a key literally called "count", and $h.Count then
        #  returns THAT KEY'S VALUE instead of the size of the table - which is
        #  how this report first printed "True distinct" for a rule that had
        #  removed ten thousand occurrences.
        param([hashtable] $Table)
        return [int]$Table.psbase.Count
    }

    foreach ($c in $cellArr) {
        $leaf = ($c.Path -split '\.')[-1] -replace '\[\d+\]$', ''
        $isHead = ($script:CVG_HEADFIELD -contains $leaf) -or ($script:CVG_HEADFIELD -contains $c.Channel)
        $isPrompt = ($leaf -eq 'prompt')
        $groupKey = $null
        foreach ($gk in $groupCover.Keys) {
            if (("{0}|{1}" -f $c.File, $c.Path).StartsWith($gk, [System.StringComparison]::OrdinalIgnoreCase) -or
                ($c.Slot -and $c.Slot -eq $gk)) { $groupKey = $gk; break }
        }

        foreach ($sentence in (Split-CoverageSentences -Text $c.Text)) {
            $quoted = Get-CoverageQuotedSpans -Sentence $sentence
            $masked = $sentence.ToCharArray()

            $hits = New-Object System.Collections.Generic.List[object]

            #  ORDER MATTERS AND THE MASK IS WHY. A clock time is also a ratio by
            #  shape, so an unmasked ratio pass reported "10:53 am" twice - once
            #  as a time and once as the ratio 10:53 - and doubled the residue
            #  with a candidate nobody wrote. Each class masks its own span
            #  before the next class runs, so every character is harvested once.
            foreach ($m in [regex]::Matches($sentence, $rxClock)) {
                $hits.Add([pscustomobject]@{ M = $m; Class = 'time'; Num = $m.Groups['num'].Value; Unit = $m.Groups['unit'].Value; Span = $m.Value.Trim(); End = ($m.Index + $m.Length) })
            }
            foreach ($h in $hits) { for ($i = $h.M.Index; $i -lt $h.End; $i++) { $masked[$i] = ' ' } }
            $stage0 = -join $masked
            foreach ($m in [regex]::Matches($stage0, $rxTime)) {
                $hits.Add([pscustomobject]@{ M = $m; Class = 'time'; Num = $m.Groups['num'].Value; Unit = $m.Groups['unit'].Value; Span = $m.Value.Trim(); End = ($m.Index + $m.Length) })
            }
            foreach ($h in $hits) { for ($i = $h.M.Index; $i -lt $h.End; $i++) { $masked[$i] = ' ' } }
            $stage1 = -join $masked
            foreach ($m in [regex]::Matches($stage1, $rxRatio)) {
                $hits.Add([pscustomobject]@{ M = $m; Class = 'ratio'; Num = $m.Groups['num'].Value; Unit = (':' + $m.Groups['unit'].Value); Span = $m.Value.Trim(); End = ($m.Index + $m.Length) })
            }
            foreach ($m in [regex]::Matches($stage1, $rxPh)) {
                $hits.Add([pscustomobject]@{ M = $m; Class = 'ph'; Num = $m.Groups['num'].Value; Unit = 'ph'; Span = $m.Value.Trim(); End = ($m.Index + $m.Length) })
            }
            foreach ($h in $hits) { for ($i = $h.M.Index; $i -lt $h.End; $i++) { $masked[$i] = ' ' } }
            $maskedText = -join $masked

            #  A CONSUMED SPAN IS BLANKED, NOT LEFT TO BE FOUND AGAIN. A unit
            #  continuation reaches PAST the regex match - "16 September" reaches
            #  over " 2026" to close the date - and the scan then found that year
            #  standing on its own and offered "2026 service" as a second
            #  candidate: a figure assembled out of the tail of one value and the
            #  first word after it. Each class already masks its own span so
            #  every character is harvested once; the continuation is part of
            #  the span, so it is masked with it.
            $qtyEnd = 0
            foreach ($m in [regex]::Matches($maskedText, $rxQty)) {
                if ($m.Index -lt $qtyEnd) { $consumedSpans++; continue }
                $numRaw = $m.Groups['num'].Value
                $unit = ''
                if ($m.Groups['unit'].Success) { $unit = $m.Groups['unit'].Value }
                #  Step over a modifier to reach the unit; this only ever widens
                #  the harvest. Two steps is enough for "5 different usable trays".
                $after = $maskedText.Substring($m.Index + $m.Length)
                $eaten = 0
                $steps = 0
                while ($unit -and $script:CVG_MODSET.ContainsKey($unit.ToLowerInvariant()) -and $steps -lt 2) {
                    $nx = [regex]::Match($after, '^(?:\s*-\s*|\s+)([A-Za-z][A-Za-z]{0,17})')
                    if (-not $nx.Success) { break }
                    $unit = $nx.Groups[1].Value
                    $after = $after.Substring($nx.Length)
                    $eaten += $nx.Length
                    $steps++
                }
                #  A degree needs its SCALE - and only a scale. The continuation
                #  used to take ANY word of up to nine letters, so "5 degrees
                #  below" and "5 degrees of separation" became figures nobody
                #  wrote. The set of temperature scales is closed, so this is a
                #  closed continuation. "5 degrees" with no scale still harvests
                #  as "5 degrees" and is still swept.
                if ($unit -match '(?i)^degrees?$') {
                    $nx = [regex]::Match($after, $script:CVG_DEGRX)
                    if ($nx.Success) { $unit = $unit + ' ' + $nx.Groups[1].Value; $after = $after.Substring($nx.Length); $eaten += $nx.Length }
                }
                #  A RATE KEEPS THE NOUN IT GOVERNS. "20 per tray" is one figure;
                #  dropping everything but "per cent" left the bare "20", which
                #  SUP-BARENUM then removed, so a stated rate left the sweep
                #  entirely and could not be registered, sourced or corrected.
                elseif ($unit -match '(?i)^per$') {
                    $nx = [regex]::Match($after, '^\s*([A-Za-z][A-Za-z]{0,17})')
                    if ($nx.Success) { $unit = 'per ' + $nx.Groups[1].Value; $after = $after.Substring($nx.Length); $eaten += $nx.Length }
                }
                elseif ($unit -and $script:CVG_MONTHSET.ContainsKey($unit.ToLowerInvariant())) {
                    $nx = [regex]::Match($after, '^\s*((?:19|20)\d{2})\b')
                    if ($nx.Success) { $unit = $unit + ' ' + $nx.Groups[1].Value; $after = $after.Substring($nx.Length); $eaten += $nx.Length }
                }
                $spanEnd = $m.Index + $m.Length + $eaten
                if ($spanEnd -gt $sentence.Length) { $spanEnd = $sentence.Length }
                $qtyEnd = $spanEnd
                $isMoney = ($numRaw -match '^\$')
                $hits.Add([pscustomobject]@{
                    M = $m; Class = $(if ($isMoney) { 'money' } else { 'quantity' }); Num = $numRaw; Unit = $unit
                    Span = $sentence.Substring($m.Index, ($spanEnd - $m.Index)).Trim(); End = $spanEnd })
            }

            #  The quantity spans are blanked before the named pass for the same
            #  reason: the "September" inside a harvested date is not a second,
            #  named candidate.
            #
            #  BLANKED WITH A SEPARATOR, NOT WITH SPACES. A run of spaces where a
            #  value used to be lets the named pattern's `\s+` join straight over
            #  it, so "Topic 1 Element 1.1 SITXINV007 Purchase" collapsed into
            #  the named item "Topic Element SITXINV007 Purchase" - a phrase
            #  built out of the words either side of two removed numbers. The
            #  fill has to be a character that is neither a letter, a digit nor
            #  whitespace, so that it ENDS a phrase instead of joining one.
            foreach ($h in $hits) { for ($i = $h.M.Index; ($i -lt $h.End) -and ($i -lt $masked.Length); $i++) { $masked[$i] = '~' } }
            $namedText = -join $masked
            foreach ($m in [regex]::Matches($namedText, $rxNamed)) {
                $hits.Add([pscustomobject]@{ M = $m; Class = 'named'; Num = ''; Unit = $m.Value; Span = $m.Value.Trim(); End = ($m.Index + $m.Length) })
            }
            $rawSpans += $hits.Count

            foreach ($h in $hits) {
                $m = $h.M
                $shown = $m.Value.Trim()
                #  DECLARED EVERY ITERATION. PowerShell keeps a loop variable
                #  alive between iterations, so a value left over from the
                #  previous hit is read as this hit's - which is how a named
                #  item once carried the surface form of the number before it.
                $shownVal = ''
                $surfaceKey = ''
                $before = $(if ($h.Class -eq 'named') { $namedText } else { $maskedText }).Substring(0, $m.Index)
                $prevWord = ''
                $pw = [regex]::Match($before, '([A-Za-z]+)[\s(\[]*$')
                if ($pw.Success) { $prevWord = $pw.Groups[1].Value.ToLowerInvariant() }

                if ($h.Class -eq 'named') {
                    $phrase = $h.Unit.Trim()
                    $tokens = @($phrase -split '\s+' | Where-Object { $_ })
                    #  A SENTENCE-INITIAL CAPITAL CARRIES NO INFORMATION, so the
                    #  first token of a phrase that starts a sentence is dropped
                    #  and any connector behind it with it. Without this,
                    #  "Ask the Executive Chef" and "Has the Executive Chef" are
                    #  two different named items and neither is the one that
                    #  exists, which is the Executive Chef.
                    if ($m.Index -eq 0 -and $tokens.Count -gt 1) {
                        $tokens = @($tokens[1..($tokens.Count - 1)])
                        while ($tokens.Count -gt 0 -and $tokens[0] -match '(?i)^(of|and|the|for|de|in|on|with)$') {
                            if ($tokens.Count -eq 1) { $tokens = @() } else { $tokens = @($tokens[1..($tokens.Count - 1)]) }
                        }
                        if ($tokens.Count -eq 0) { Add-CoverageSuppressed -Rule 'SUP-SENTINIT' -Key (ConvertTo-GateNormal $phrase) -Shown $phrase; continue }
                        $phrase = ($tokens -join ' ')
                    }
                    #  A NAME DOES NOT BEGIN OR END WITH A FUNCTION WORD, and a
                    #  possessive is not part of one. Trimming them is not a
                    #  suppression - it is what makes "Has the Executive Chef"
                    #  and "the Executive Chef" the same named item, and what
                    #  lets "Monday's" match the source that writes "Monday".
                    while ($tokens.Count -gt 1 -and $script:CVG_STOPSET.ContainsKey($tokens[0].ToLowerInvariant())) {
                        $tokens = @($tokens[1..($tokens.Count - 1)])
                    }
                    while ($tokens.Count -gt 1 -and $script:CVG_STOPSET.ContainsKey(($tokens[-1] -replace "['\-]", '').ToLowerInvariant())) {
                        $tokens = @($tokens[0..($tokens.Count - 2)])
                    }
                    #  SUP-EMPTYKEY, THREE TIMES. These were three bare
                    #  `continue`s: a harvested span vanished off the books, so
                    #  the printed suppression tally did not add up to the raw
                    #  harvest and no reader could tell a deliberate narrowing
                    #  from a bug in the trimmer. A phrase that trims away to
                    #  nothing - all function words, a lone possessive, two
                    #  characters - is a narrowing like any other and is
                    #  recorded like any other.
                    if ($tokens.Count -eq 0) { Add-CoverageSuppressed -Rule 'SUP-EMPTYKEY' -Key (ConvertTo-GateNormal $phrase) -Shown $phrase; continue }
                    $tokens = @($tokens | ForEach-Object { $_ -replace "['\u2019]s$", '' } | Where-Object { $_ })
                    if ($tokens.Count -eq 0) { Add-CoverageSuppressed -Rule 'SUP-EMPTYKEY' -Key (ConvertTo-GateNormal $phrase) -Shown $phrase; continue }
                    $phrase = ($tokens -join ' ')
                    $key = ConvertTo-GateNormal $phrase
                    if (-not $key -or $key.Length -lt 3) { Add-CoverageSuppressed -Rule 'SUP-EMPTYKEY' -Key $(if ($key) { $key } else { '(empty)' }) -Shown $phrase; continue }
                    $shownVal = $phrase
                    $surfaceKey = $key
                    if ($isPrompt) { Add-CoverageSuppressed -Rule 'SUP-PROMPTFIELD' -Key $key -Shown $phrase; continue }
                    if ($isHead) { Add-CoverageSuppressed -Rule 'SUP-HEADFIELD' -Key $key -Shown $phrase; continue }
                    if ($tokens.Count -eq 1 -and $m.Index -eq 0) { Add-CoverageSuppressed -Rule 'SUP-SENTINIT' -Key $key -Shown $phrase; continue }
                    if ($script:CVG_REFSET.ContainsKey($tokens[-1].ToLowerInvariant()) -or
                        ($script:CVG_REFSET.ContainsKey($prevWord))) {
                        Add-CoverageSuppressed -Rule 'SUP-REF' -Key $key -Shown $phrase; continue
                    }
                    if ($identSet.ContainsKey($key) -or $phrase -match '^[A-Z]{3,4}[A-Z]{3}\d{3}[A-Z]?$') {
                        Add-CoverageSuppressed -Rule 'SUP-IDENT' -Key $key -Shown $phrase; continue
                    }
                    if ($groupKey) { Add-CoverageSuppressed -Rule 'SUP-REGGROUP' -Key $key -Shown $phrase; continue }
                    if ($tokens.Count -eq 1 -and $lowerVocab.ContainsKey($tokens[0].ToLowerInvariant())) {
                        Add-CoverageSuppressed -Rule 'SUP-NICOMMON' -Key $key -Shown $phrase; continue
                    }
                }
                else {
                    $numNorm = ($h.Num -replace '[\s,]', '')
                    $unitNorm = ConvertTo-GateNormal $h.Unit
                    $unitHead0 = $(if ($unitNorm) { ($unitNorm -split ' ')[0] } else { '' })
                    $unitKnown = ($unitNorm -and ($script:CVG_MEASURESET.ContainsKey($unitNorm) -or $script:CVG_MEASURESET.ContainsKey($unitHead0)))
                    #  A DATE IS A QUANTITY WHOSE UNIT IS A MONTH, and money is
                    #  money. Both carry their unit INSIDE the value - the "$"
                    #  and the month name - so the word after them is the next
                    #  word of the sentence and not part of the figure.
                    $isDateCand  = ($h.Class -eq 'quantity' -and $unitHead0 -and $script:CVG_MONTHSET.ContainsKey($unitHead0))
                    $isMoneyCand = ($h.Class -eq 'money')

                    #  THE STOP-WORD RULE MAY NEVER SUPPRESS AN AMOUNT. On a
                    #  bare count the word after the number IS the evidence that
                    #  there is no unit, and SUP-BARENUM removes the candidate.
                    #  On money and on a date it is evidence of nothing:
                    #  "The invoice shows $250.00 and delivery is included" was
                    #  harvested as the figure "$250.00 and", which no source
                    #  can carry, no registry can name and no author can
                    #  correct - and it was then reported as an unsourced
                    #  figure. The UNIT is cleared. The amount stays, is swept,
                    #  and is reported.
                    #  MONEY AND DATES ONLY. A clock's unit is "am" or "pm", and
                    #  "am" is also the verb - it is in the stop set. Clearing
                    #  the unit of every class here stripped the meridiem off
                    #  every time of day in the build and offered "7.45" where
                    #  the document says "7.45 am". A time, a ratio and a pH
                    #  carry a unit the harvester chose from a closed set; the
                    #  stop set has no business near them.
                    if ($unitNorm -and $script:CVG_STOPSET.ContainsKey($unitNorm)) {
                        if ($isMoneyCand -or $isDateCand) {
                            $h.Unit = ''; $unitNorm = ''; $unitHead0 = ''; $unitKnown = $false
                        }
                        elseif ($h.Class -eq 'quantity') {
                            Add-CoverageSuppressed -Rule 'SUP-BARENUM' -Key ($numNorm + ' ' + $unitNorm) -Shown $shown; continue
                        }
                    }
                    #  AN UNKNOWN TAIL ON AN AMOUNT DISPOSITIONS THE BARE VALUE,
                    #  and the FULL SPAN stays as the anchor so the work order
                    #  still points at the text that is on the page. "$500 it",
                    #  "$696.00 as", "$2,400 takes" were seven of the reference
                    #  build's blocking findings, every one of them a figure the
                    #  harvester assembled rather than one the guide wrote.
                    if (($isMoneyCand -or $isDateCand) -and $unitNorm -and -not $unitKnown) {
                        $h.Unit = ''; $unitNorm = ''; $unitHead0 = ''
                    }
                    if ($h.Class -eq 'quantity' -and -not $unitNorm) {
                        Add-CoverageSuppressed -Rule 'SUP-BARENUM' -Key (ConvertTo-GateNormal $shown) -Shown $shown; continue
                    }

                    #  THE KEY IS LEMMATISED, THE SURFACE IS KEPT. "4 cartons"
                    #  and "4 carton" are one figure, so the key carries the
                    #  lemma; a source or a registry entry that writes the
                    #  plural must still be able to disposition it, so the
                    #  surface form is carried alongside and searched too.
                    $unitLemma = Get-CoverageUnitLemma $h.Unit
                    $shownVal = (("{0} {1}" -f $h.Num, $unitLemma).Trim())
                    $key = ConvertTo-GateNormal $shownVal
                    $surfaceKey = ConvertTo-GateNormal (("{0} {1}" -f $h.Num, $h.Unit).Trim())
                    if (-not $key) { Add-CoverageSuppressed -Rule 'SUP-EMPTYKEY' -Key '(empty)' -Shown $shown; continue }
                    #  SUP-WORDCOUNT. "one dish", "two jobs", "twelve methods" -
                    #  a number written as an English word, counting something
                    #  that is not a unit of measurement. That is ordinary
                    #  enumeration in running prose, not a figure: it cannot be
                    #  wrong in the way a temperature or a batch weight can. The
                    #  same count in DIGITS is still harvested, "two hours" is
                    #  still harvested because an hour is a unit, and a word-form
                    #  spelling of a REGISTERED figure is still caught by the
                    #  variant-aware MATCHED arm here and by Test-FigureConsistency's
                    #  variant sweep - so this cannot hide a stale figure.
                    if ($h.Class -eq 'quantity' -and $h.Num -match '^[A-Za-z]') {
                        $uw = @($unitNorm -split ' ' | Where-Object { $_ })
                        $unitHead = $(if ($uw.Count -gt 0) { $uw[0] } else { '' })
                        #  A RATE IS JUDGED ON THE NOUN IT GOVERNS. "per" is in
                        #  the unit vocabulary, so once the rate rule started
                        #  keeping the noun after it, "one per good" - ordinary
                        #  enumeration written out in words - passed this rule on
                        #  the strength of the word "per". The thing being
                        #  measured is the noun, so the noun decides.
                        $isUnitWord = $false
                        if ($unitHead -eq 'per' -and $uw.Count -gt 1) {
                            $isUnitWord = $script:CVG_MEASURESET.ContainsKey($uw[$uw.Count - 1])
                        }
                        else {
                            $isUnitWord = ($script:CVG_MEASURESET.ContainsKey($unitNorm) -or $script:CVG_MEASURESET.ContainsKey($unitHead))
                        }
                        if (-not $isUnitWord) {
                            Add-CoverageSuppressed -Rule 'SUP-WORDCOUNT' -Key $key -Shown $shown; continue
                        }
                    }
                    #  SUP-DOTREF. A dotted number that is one of the spine's own
                    #  sub-section refs, performance criteria or figure slots is
                    #  a hierarchical identifier and the words after it are its
                    #  heading. The namespace is DERIVED from the spine, so
                    #  "17.5 kg" - which is in no namespace - is still harvested,
                    #  and a measured quantity is never suppressed by this rule.
                    if ($h.Class -eq 'quantity' -and $h.Num -match '^\d+\.\d') {
                        $numRefKey = ConvertTo-GateNormal $h.Num
                        $unitHead2 = ($unitNorm -split ' ')[0]
                        if ($refNamespace.ContainsKey($numRefKey) -and
                            -not ($script:CVG_MEASURESET.ContainsKey($unitNorm) -or $script:CVG_MEASURESET.ContainsKey($unitHead2))) {
                            Add-CoverageSuppressed -Rule 'SUP-DOTREF' -Key $key -Shown $shown; continue
                        }
                    }
                    if ($isPrompt) { Add-CoverageSuppressed -Rule 'SUP-PROMPTFIELD' -Key $key -Shown $shown; continue }
                    if ($script:CVG_REFSET.ContainsKey($prevWord)) { Add-CoverageSuppressed -Rule 'SUP-REF' -Key $key -Shown $shown; continue }
                    if ($h.Class -eq 'quantity' -and $script:CVG_REFSET.ContainsKey($unitNorm)) { Add-CoverageSuppressed -Rule 'SUP-REF' -Key $key -Shown $shown; continue }
                    if ($shown -match '(?i)\b\d+(st|nd|rd|th)\b') { Add-CoverageSuppressed -Rule 'SUP-ORDINAL' -Key $key -Shown $shown; continue }
                    if ($m.Index -le 1 -and $sentence -match '^\s*\(?\d{1,2}[.)]\s') { Add-CoverageSuppressed -Rule 'SUP-LISTNUM' -Key $key -Shown $shown; continue }
                    if ($identSet.ContainsKey($numNorm) -or $identSet.ContainsKey($key)) { Add-CoverageSuppressed -Rule 'SUP-IDENT' -Key $key -Shown $shown; continue }
                    #  A HYPHENATED IDENTIFIER, BY SHAPE. A number whose
                    #  immediately preceding characters are a short letter run
                    #  and a hyphen is the tail of an identifier - R-5, D-3,
                    #  O-2, A-1 - and not a measured quantity. The identSet
                    #  above cannot reach these: it recognises ABN, ACN, CRICOS
                    #  and national unit-code shapes, every one of which
                    #  carries three or more digits, and a recipe card number
                    #  is one or two.
                    #
                    #  WHAT MISSING IT COSTS: the harvester reads "recipe card
                    #  R-5 stirs 8 drops of the acid solution" and reports the
                    #  figure "5 stir" - a string the document does not contain
                    #  - as an unsourced claim against a card the pack owns.
                    #  Ten such artefacts appeared on this build (5 stir,
                    #  6 boil, 1 warn, 9 allow, 10 batch among them), each one
                    #  a work order naming a figure nobody wrote. A rule that
                    #  sends a reader hunting for a quantity that does not
                    #  exist is the crying-wolf gate this file forbids.
                    #
                    #  A SHAPE, never a build's values: no identifier literal
                    #  is typed here, so rule 5 is untouched.
                    if ($before -match '(?i)[A-Za-z]{1,3}-$') { Add-CoverageSuppressed -Rule 'SUP-IDENT' -Key $key -Shown $shown; continue }
                    if ($numNorm -match '^(1[89]|20)\d{2}$' -and ($before -match ($rxCite + '\W{0,12}$') -or $shown -match '^\(')) {
                        Add-CoverageSuppressed -Rule 'SUP-CITEYEAR' -Key $key -Shown $shown; continue
                    }
                    $inQuote = $false
                    foreach ($q in $quoted) { if ($m.Index -ge $q.Start -and $m.Index -lt $q.End) { $inQuote = $true; break } }
                    if ($inQuote) { Add-CoverageSuppressed -Rule 'SUP-QUOTED' -Key $key -Shown $shown; continue }
                    if ($groupKey) { Add-CoverageSuppressed -Rule 'SUP-REGGROUP' -Key $key -Shown $shown; continue }
                }

                $occ.Add([pscustomobject]@{
                    Key = $key
                    #  The candidate as it was WRITTEN, before the lemma. A
                    #  source or registry entry that spells the plural still
                    #  dispositions it.
                    Surface = $surfaceKey
                    #  SHOW THE CANDIDATE, NOT THE RAW MATCH. The raw match for
                    #  "10 June 2026" is "10 June" - the year is picked up after
                    #  it - and a work order naming "10 June" sends a reader
                    #  hunting for something the guide never wrote. $shown itself
                    #  stays the raw match above, because the ordinal rule reads
                    #  its suffix.
                    Shown = $shownVal
                    #  THE FULL HARVESTED SPAN, exactly as it stands in the
                    #  sentence. Where the candidate is the bare value out of a
                    #  longer span ("$250.00" out of "$250.00 and"), this is how
                    #  a reader - and section 30's anchored-finding contract -
                    #  finds it again in the document.
                    Span = $h.Span
                    Class = $h.Class
                    File = $c.File; Path = $c.Path; Channel = $c.Channel; Slot = $c.Slot
                    Sentence = $sentence
                    Arith = ($sentence -match $rxArith -and $sentence -match $rxCue)
                    At = $m.Index
                })
            }
        }
    }
    $occArr = $occ.ToArray()

    # -- 6. distinct candidates ----------------------------------------------
    $cand = [ordered]@{}
    foreach ($o in $occArr) {
        if (-not $cand.Contains($o.Key)) {
            $cand[$o.Key] = [pscustomobject]@{
                Key = $o.Key; Shown = $o.Shown; Class = $o.Class
                Occurrences = 0
                #  Every spelling this candidate was written in. The key is one
                #  lemma; the surfaces are what a source has to be searched for.
                Surfaces = (New-Object System.Collections.Generic.List[string])
                Anchors = (New-Object System.Collections.Generic.List[object])
                Disposition = ''; MatchedBy = ''; SourceFile = ''; SourceLine = 0; SourceHow = ''
                DerivedFrom = @(); DerivedVia = ''; WhyNot = [ordered]@{}
            }
        }
        $e = $cand[$o.Key]
        $e.Occurrences = $e.Occurrences + 1
        if ($o.Surface -and $o.Surface -ne $o.Key -and -not $e.Surfaces.Contains($o.Surface)) { $e.Surfaces.Add($o.Surface) }
        if ($e.Anchors.Count -lt 6) {
            $e.Anchors.Add([pscustomobject]@{ File = $o.File; Path = $o.Path; Channel = $o.Channel; Slot = $o.Slot; Sentence = $o.Sentence; Span = $o.Span })
        }
    }

    # -- 7. disposition 1, MATCHED -------------------------------------------
    #  A DERIVED ENTRY CONFERS NO MATCH. An entry that declares derivedFrom is
    #  saying "this value is computed from these inputs" - the registration is
    #  the CLAIM, not the evidence. Matching on it here dispositioned every such
    #  value MATCHED by mere registration, the in-registry derived arm below
    #  became unreachable by construction, and DERIVED fired 0 times out of 185
    #  candidates on the reference build while reading as if it worked. An entry
    #  with derivedFrom is answered by the fixpoint at step 9 or not at all.
    foreach ($k in @($cand.Keys)) {
        $e = $cand[$k]
        #  Hoisted and memoised: one variant pattern per candidate, not one per
        #  candidate per registry entry.
        $needles = New-Object System.Collections.Generic.List[string]
        $needles.Add($k)
        foreach ($s in $e.Surfaces) { if (-not $needles.Contains($s)) { $needles.Add($s) } }
        $needleRx = New-Object System.Collections.Generic.List[string]
        foreach ($n in $needles) { $needleRx.Add((ConvertTo-CoverageVariantRegex -Literal $n)) }
        foreach ($r in $regArr) {
            if (-not $r.Norm) { continue }
            #  Get-GateCount, not @($r.Inputs).Count: @($null).Count is 1 in
            #  PS 5.1, so a registry row that carries NO Inputs property
            #  answered YES here and was skipped by a rule that reads as if it
            #  only skipped rows that declare their inputs.
            if ((Get-GateCount -Value $r.Inputs) -gt 0) { continue }
            $ok = $false
            $padded = ' ' + $r.Norm + ' '
            foreach ($n in $needles) {
                if ($padded.IndexOf(' ' + $n + ' ', [System.StringComparison]::Ordinal) -ge 0) { $ok = $true; break }
            }
            if (-not $ok) {
                foreach ($rx in $needleRx) { if ([regex]::IsMatch($r.Norm, $rx)) { $ok = $true; break } }
            }
            if ($ok) { $e.Disposition = 'MATCHED'; $e.MatchedBy = $r.Name; break }
        }
        if (-not $e.Disposition) { $e.WhyNot['matched'] = 'no registry entry in figures.json carries this value, or a digit/word variant of it, in its name, its require list or its source locator (an entry that declares derivedFrom is answered by the derived arm, never by being registered)' }
    }

    # -- 8. disposition 2, PRESENT -------------------------------------------
    foreach ($k in @($cand.Keys)) {
        $e = $cand[$k]
        if ($e.Disposition) { continue }
        $found = Find-CoverageInSources -Needle $k -Also @($e.Surfaces.ToArray()) -Indexes $sourceArr
        if ($found) {
            $e.Disposition = 'PRESENT'; $e.SourceFile = $found.Source; $e.SourceLine = $found.Line; $e.SourceHow = $found.How
        }
        else {
            $e.WhyNot['present'] = ("not found in any of the {0} canonical source(s) ({1}), verbatim or as a digit/word variant" -f $sourceArr.Length, (($sourceArr | ForEach-Object { $_.Name }) -join ', '))
        }
    }

    # -- 9. disposition 3, DERIVED, to a fixpoint -----------------------------
    #  A derivation names its inputs. In-sentence: a sentence carrying an
    #  arithmetic connective AND a result cue derives the quantities after the
    #  cue from the quantities before it. In-registry: an entry's derivedFrom.
    #  Every named input must itself resolve, so a chain resolves and a
    #  derivation from an unsupported number does NOT.
    #  Occurrences indexed BY SENTENCE. Scanning every occurrence for every
    #  occurrence is 31 million string comparisons on a build this size, and a
    #  gate too slow to run is a gate nobody runs.
    $bySentence = @{}
    foreach ($o in $occArr) {
        if (-not $bySentence.ContainsKey($o.Sentence)) { $bySentence[$o.Sentence] = New-Object System.Collections.Generic.List[object] }
        $bySentence[$o.Sentence].Add($o)
    }

    $inputsOf = @{}
    foreach ($o in $occArr) {
        if (-not $o.Arith) { continue }
        $e = $cand[$o.Key]
        if ($e.Disposition) { continue }
        #  THE LAST CUE BEFORE THE CANDIDATE, not the first in the sentence.
        #  "Crushed canned tomatoes ARE 600 Gms on the card, and 600 multiplied
        #  by 5 IS 3000, so you need 3000 Gms" splits at the first "are" if the
        #  first match is taken, the left-hand side then holds no number at all,
        #  and a plainly stated derivation is reported as unsupported. Splitting
        #  at the last cue before the value puts the operands where they are.
        $cueEnd = -1
        foreach ($cm in [regex]::Matches($o.Sentence, $rxCue)) {
            if ($cm.Index -lt $o.At) { $cueEnd = $cm.Index + $cm.Length } else { break }
        }
        if ($cueEnd -lt 0) { continue }          # an operand, not the result
        $lhs = $o.Sentence.Substring(0, $cueEnd)
        $named = New-Object System.Collections.Generic.List[string]
        foreach ($sib in $bySentence[$o.Sentence]) {
            if ($sib.Key -eq $o.Key) { continue }
            if ($sib.Class -eq 'named') { continue }
            if ($sib.At -ge $cueEnd) { continue }
            if (-not $named.Contains($sib.Key)) { $named.Add($sib.Key) }
        }
        #  A DERIVATION IS NEVER ITS OWN INPUT. "600 multiplied by 5 IS 3000, so
        #  you need 3000 Gms" states the result twice, and counting the bare
        #  3000 on the left as an input of "3000 Gms" made the value depend on
        #  itself: unresolvable by construction, and a plainly stated
        #  derivation was reported as unsupported.
        $ownNum = ($o.Key -split ' ')[0]
        foreach ($bn in [regex]::Matches($lhs, '(?<![\w.])\d+(?:\.\d+)?(?![\w.])')) {
            $bk = ConvertTo-GateNormal $bn.Value
            if (-not $bk) { continue }
            if ($bk -eq $ownNum) { continue }
            if (-not $named.Contains($bk)) { $named.Add($bk) }
        }
        if ($named.Count -eq 0) { continue }
        #  ONE SET PER STATED DERIVATION, never one union across all of them.
        #  A value stated once as "8 multiplied by 250 is 2000 Gms" and used
        #  again three sub-sections later in a sentence about something else had
        #  the second sentence's numbers folded into its input list, and the
        #  value was then reported as underived because of a figure it was never
        #  derived from. ONE sound derivation dispositions the value.
        if (-not $inputsOf.ContainsKey($o.Key)) { $inputsOf[$o.Key] = New-Object System.Collections.Generic.List[object] }
        $inputsOf[$o.Key].Add([pscustomobject]@{
            Inputs = $named.ToArray()
            From   = ("the arithmetic stated in {0} {1}" -f $o.File, $o.Path) })
    }
    #  THE IN-REGISTRY DERIVED ARM. Step 7 no longer hands a MATCHED to an entry
    #  that declares derivedFrom, so this arm is reachable: an entry saying "this
    #  value is 8 x 250 g" is answered by resolving 8 and 250 g, not by the fact
    #  that somebody wrote the entry.
    foreach ($k in @($cand.Keys)) {
        $e = $cand[$k]
        if ($e.Disposition) { continue }
        #  PADDED ON BOTH SIDES. The unpadded IndexOf could not see a value at
        #  the very start or the very end of an entry's normalised text, so an
        #  entry whose value was its last field never reached this arm at all.
        $needles2 = New-Object System.Collections.Generic.List[string]
        $needles2.Add($k)
        foreach ($s in $e.Surfaces) { if (-not $needles2.Contains($s)) { $needles2.Add($s) } }
        foreach ($r in $regArr) {
            if (@($r.Inputs).Count -eq 0) { continue }
            $padded2 = ' ' + $r.Norm + ' '
            $hit2 = $false
            foreach ($n in $needles2) {
                if ($padded2.IndexOf(' ' + $n + ' ', [System.StringComparison]::Ordinal) -ge 0) { $hit2 = $true; break }
            }
            if (-not $hit2) {
                foreach ($n in $needles2) {
                    if ([regex]::IsMatch($r.Norm, (ConvertTo-CoverageVariantRegex -Literal $n))) { $hit2 = $true; break }
                }
            }
            if (-not $hit2) { continue }
            if (-not $inputsOf.ContainsKey($k)) { $inputsOf[$k] = New-Object System.Collections.Generic.List[object] }
            $inputsOf[$k].Add([pscustomobject]@{
                Inputs = @($r.Inputs | ForEach-Object { ConvertTo-GateNormal $_ } | Where-Object { $_ })
                From   = ("figures.json entry '{0}' derivedFrom" -f $r.Name) })
        }
    }

    function Test-CoverageInputResolves {
        param([string] $InputKey, $Table, $Indexes)
        if ($Table.Contains($InputKey)) {
            $d = $Table[$InputKey].Disposition
            if ($d -eq 'MATCHED' -or $d -eq 'PRESENT' -or $d -eq 'DERIVED') { return $true }
            return $false
        }
        return ($null -ne (Find-CoverageInSources -Needle $InputKey -Indexes $Indexes))
    }

    $pass = 0
    do {
        $changed = $false
        $pass++
        foreach ($k in @($cand.Keys)) {
            $e = $cand[$k]
            if ($e.Disposition) { continue }
            if (-not $inputsOf.ContainsKey($k)) { continue }
            $bestBad = $null; $bestSet = $null
            foreach ($set in $inputsOf[$k]) {
                #  A DERIVATION WITH NO INPUTS RESOLVES NOTHING. An empty input
                #  list has no unresolved member, so it would have satisfied
                #  "every input resolves" vacuously and conferred DERIVED on a
                #  value nothing supports.
                if (@($set.Inputs).Count -eq 0) { continue }
                $bad = New-Object System.Collections.Generic.List[string]
                #  EVERY named input must resolve. The first that does not is
                #  the one the reason names: an author fixes a derivation by
                #  supporting its first unsupported input, and a reason that
                #  lists five keys without saying which one to start on is a
                #  finding nobody can close.
                foreach ($inp in @($set.Inputs)) {
                    if (-not (Test-CoverageInputResolves -InputKey $inp -Table $cand -Indexes $sourceArr)) { $bad.Add($inp) }
                }
                if ($bad.Count -eq 0) { $bestBad = $bad; $bestSet = $set; break }
                if ($null -eq $bestBad -or $bad.Count -lt $bestBad.Count) { $bestBad = $bad; $bestSet = $set }
            }
            if ($null -eq $bestSet) { continue }
            if ($bestBad.Count -eq 0) {
                $e.Disposition = 'DERIVED'; $e.DerivedFrom = @($bestSet.Inputs); $e.DerivedVia = $bestSet.From; $changed = $true
            }
            else {
                $e.DerivedFrom = @($bestSet.Inputs)
                $e.DerivedVia = $bestSet.From
                $rest = ''
                if ($bestBad.Count -gt 1) { $rest = (" ({0} further input(s) are unresolved as well: [{1}])" -f ($bestBad.Count - 1), (($bestBad.ToArray()[1..($bestBad.Count - 1)]) -join '; ')) }
                $e.WhyNot['derived'] = ("{0} names this as derived from [{1}], and the input '{2}' is UNRESOLVED - it is not registered, not in any canonical source, and not itself derived{3}" -f $bestSet.From, ((@($bestSet.Inputs)) -join '; '), $bestBad[0], $rest)
            }
        }
    } while ($changed -and $pass -lt 12)

    foreach ($k in @($cand.Keys)) {
        $e = $cand[$k]
        if ($e.Disposition) { continue }
        if (-not $e.WhyNot.Contains('derived')) {
            #  THE EXPLANATION NAMES THE STATE THIS CANDIDATE ACTUALLY REACHED.
            #  One sentence for every survivor read as though the content had
            #  been examined for inputs and found to name none - which is a
            #  different fact from "inputs were named and none of them was a
            #  readable value", and a reader closes those two findings in
            #  opposite ways.
            if (-not $inputsOf.ContainsKey($k)) {
                $e.WhyNot['derived'] = 'no input is named for this value anywhere: no sentence carrying it has both an arithmetic connective and a result cue, and no figures.json entry carrying it declares derivedFrom'
            }
            else {
                $emptyFrom = New-Object System.Collections.Generic.List[string]
                foreach ($set in $inputsOf[$k]) { if (@($set.Inputs).Count -eq 0 -and -not $emptyFrom.Contains($set.From)) { $emptyFrom.Add($set.From) } }
                if ($emptyFrom.Count -gt 0) {
                    $e.WhyNot['derived'] = ("this value is declared derived by {0}, and not one of the inputs named there is a readable value - a derivation whose inputs normalise to nothing resolves nothing" -f (($emptyFrom.ToArray()) -join '; '))
                }
                else {
                    $e.WhyNot['derived'] = ("an input set was opened for this value and the fixpoint closed after {0} pass(es) without reaching it - report this as a gate defect, not as a content defect" -f $pass)
                }
            }
        }
        $e.Disposition = 'UNDISPOSITIONED'
    }

    # -- 10. report -----------------------------------------------------------
    $byDisp = @{ MATCHED = 0; PRESENT = 0; DERIVED = 0; UNDISPOSITIONED = 0 }
    foreach ($k in @($cand.Keys)) { $byDisp[$cand[$k].Disposition] = $byDisp[$cand[$k].Disposition] + 1 }
    $undis = @()
    foreach ($k in @($cand.Keys)) { if ($cand[$k].Disposition -eq 'UNDISPOSITIONED') { $undis += $cand[$k] } }
    $undis = @($undis | Sort-Object -Property @{ Expression = { $_.Occurrences }; Descending = $true }, Key)

    $supRows = New-Object System.Collections.Generic.List[object]
    $supTotal = 0
    foreach ($r in $supCount.Keys) {
        $supTotal += [int]$supCount[$r]
        $supRows.Add([pscustomobject]@{
            rule = $r
            occurrencesRemoved = $supCount[$r]
            distinctRemoved = (Get-CoverageDistinctCount -Table $supDistinct[$r])
            examples = @($supSample[$r].ToArray())
        })
    }

    $candRows = New-Object System.Collections.Generic.List[object]
    foreach ($k in @($cand.Keys)) {
        $e = $cand[$k]
        $candRows.Add([pscustomobject]@{
            candidate = $e.Key; shown = $e.Shown; class = $e.Class
            surfaces = @($e.Surfaces.ToArray())
            occurrences = $e.Occurrences; disposition = $e.Disposition
            matchedBy = $e.MatchedBy
            sourceFile = $e.SourceFile; sourceLine = $e.SourceLine; sourceMatch = $e.SourceHow
            derivedFrom = @($e.DerivedFrom)
            derivedVia = $e.DerivedVia
            whyNot = $e.WhyNot
            anchors = @($e.Anchors.ToArray() | ForEach-Object {
                [pscustomobject]@{ file = $_.File; fieldPath = $_.Path; channel = $_.Channel; slot = $_.Slot; sentence = $_.Sentence; span = $_.Span }
            })
        })
    }

    # -----------------------------------------------------------------------
    #  BLOCKING FINDINGS GO THROUGH THE SHARED FINDING WRITER WHEN THERE IS ONE.
    #  New-GateFinding / Test-GateFindingAnchor are landing in Lib-GateCommon
    #  (section 30's anchored-finding contract: a gate that cannot re-find its
    #  own anchor at the token boundary is a GATE defect and not a content
    #  finding). Behind a Get-Command check, because this gate must run whether
    #  or not they are there yet; today's shape is kept on every row either way,
    #  so nothing downstream of this report breaks on the day they land.
    # -----------------------------------------------------------------------
    $haveFindingWriter = [bool](Get-Command New-GateFinding -ErrorAction SilentlyContinue)
    $haveAnchorTest = [bool](Get-Command Test-GateFindingAnchor -ErrorAction SilentlyContinue)
    $workRows = New-Object System.Collections.Generic.List[object]
    foreach ($u in $undis) {
        $located = @($u.Anchors.ToArray() | ForEach-Object {
            [pscustomobject]@{ file = $_.File; fieldPath = $_.Path; channel = $_.Channel; slot = $_.Slot; sentence = $_.Sentence; span = $_.Span }
        })
        #  THE ANCHOR IS THE FULL HARVESTED SPAN, not the shortened candidate.
        #  Where the candidate is the bare amount out of a longer span, the span
        #  is the string that is actually in the document and the only one a
        #  re-find can succeed on.
        $anchorText = $u.Shown
        if (@($located).Count -gt 0 -and "$($located[0].span)".Trim()) {
            $anchorText = [string]$located[0].span
            #  QUOTE THE VALUE AS THE DOCUMENT PUNCTUATES IT. The shared token
            #  boundary treats a dot beside a value as a decimal continuation -
            #  which is exactly what keeps '7.5' out of '7.5.1' - so a value
            #  that ENDS A SENTENCE cannot be re-found unless the full stop
            #  travels with the quote. "A supplier quotes $52.00 per kg." was
            #  anchor-unresolved for that reason alone, and an anchor the gate
            #  cannot re-find is charged to the gate, not to the content.
            $sentTxt = [string]$located[0].sentence
            $at = $sentTxt.IndexOf($anchorText, [System.StringComparison]::Ordinal)
            if ($at -ge 0) {
                $endAt = $at + $anchorText.Length
                if ($endAt -lt $sentTxt.Length -and $sentTxt[$endAt] -eq '.') { $anchorText = $anchorText + '.' }
            }
        }
        $row = [pscustomobject]@{
            candidate = $u.Key; shown = $u.Shown; class = $u.Class; occurrences = $u.Occurrences
            anchor = $anchorText
            whyNot = $u.WhyNot
            located = $located
        }
        if ($haveFindingWriter -and @($located).Count -gt 0) {
            try {
                $srcFile = [string]$located[0].file
                if ($fileFull.ContainsKey($srcFile)) { $srcFile = [string]$fileFull[$srcFile] }
                $w = New-GateFinding -Rule 'FIGURE-UNDISPOSITIONED' -File $srcFile `
                        -Field ([string]$located[0].fieldPath) -Quote $anchorText `
                        -Locator ([string]$located[0].channel) `
                        -Detail ("the candidate claim '{0}' carries no disposition: not matched by the registry, not present in a canonical source, not derived from inputs that resolve" -f $u.Shown)
                if ($null -ne $w) {
                    foreach ($p in @($w.PSObject.Properties)) {
                        if ($row.PSObject.Properties.Name -notcontains $p.Name) {
                            $row | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value
                        }
                    }
                    #  RE-FIND THE QUOTE WHERE THE FINDING SAYS IT IS. Section
                    #  30's contract: a gate that cannot re-find its own anchor
                    #  at the token boundary has a defect of its own. Recorded
                    #  here; P1-14 owns turning it into an exit code, so this
                    #  gate states the fact and does not act on it.
                    if ($haveAnchorTest) {
                        $t = Test-GateFindingAnchor -Finding $w -BaseDir $Dir
                        $row | Add-Member -NotePropertyName 'anchorVerdict' -NotePropertyValue ([string]$t.Verdict) -Force
                        if (-not $t.Resolved) { $row | Add-Member -NotePropertyName 'anchorReason' -NotePropertyValue ([string]$t.Reason) -Force }
                    }
                }
            }
            catch {
                $row | Add-Member -NotePropertyName 'anchorVerdict' -NotePropertyValue ('finding-writer-refused: ' + $_.Exception.Message) -Force
            }
        }
        $workRows.Add($row)
    }

    # -----------------------------------------------------------------------
    #  THE ARM ROSTER, and the check-sets that may not be empty. These used to
    #  sit inside the -Quiet guard, so a run that printed nothing also proved
    #  nothing: a gate whose registry, corpus or spine came back empty inverted
    #  an empty answer set and reported every candidate dispositioned. The
    #  refusal is exit 2 and it names the input.
    # -----------------------------------------------------------------------
    Reset-GateArmRoster
    Register-GateArm -Name 'registry' -Blocking
    Register-GateArm -Name 'sources'  -Blocking
    Register-GateArm -Name 'harvest'  -Blocking
    Register-GateArm -Name 'disposition'
    if ($Band -eq '7c') { Register-GateArm -Name 'rendered' -Blocking }

    Write-GateCheckSet -What 'registry entries' -Count $regArr.Length -Blocking `
        -Input ($(if ($Rules) { $Rules } else { Join-Path $Dir 'figures.json' }) + ' figures[]') `
        -DerivedFrom 'figures.json, the registry this gate INVERTS - it is the answer set, never the question set'
    Write-GateCheckSet -What 'canonical sources' -Count $sourceArr.Length -Blocking `
        -Input ("the corpus at {0} plus unit_extract*.md" -f $corpusResolved) `
        -DerivedFrom ("the corpus classified from the {0}" -f $corpusDocs.ClassifiedFrom)
    Write-GateCheckSet -What 'spine cell(s) harvested' -Count $spineCellCount -Blocking `
        -Input ("the spine under {0}" -f $(if ($Spine) { $Spine } else { Join-Path $Dir 'spine' })) `
        -DerivedFrom ("{0} spine file(s)" -f $spineFiles.Count)
    if ($Band -eq '7c') {
        Write-GateCheckSet -What 'rendered extract(s)' -Count $renderedFiles.Count -Blocking `
            -Input 'the extracts passed to -DocText (guide_gate.txt, deck_gate.txt)' `
            -DerivedFrom '-DocText, one extract per delivered artefact'
    }

    Complete-GateArm -Name 'registry' -State 'ran' -Size $regArr.Length -Findings 0
    Complete-GateArm -Name 'sources'  -State 'ran' -Size $sourceArr.Length -Findings 0
    Complete-GateArm -Name 'harvest'  -State 'ran' -Size $spineCellCount -Findings $occArr.Length
    if ($cand.psbase.Count -gt 0) { Complete-GateArm -Name 'disposition' -State 'ran' -Size $cand.psbase.Count -Findings $undis.Count }
    else { Complete-GateArm -Name 'disposition' -State 'empty' -Size 0 }
    if ($Band -eq '7c') { Complete-GateArm -Name 'rendered' -State 'ran' -Size $renderedFiles.Count -Findings 0 }

    Assert-GateArmsComplete
    $roster = @(Write-GateArmRoster)

    $reportObj = [pscustomobject]@{
        gate = $GATE
        stage = $Band
        arms = @($roster)
        section = 'gates.md 17 - the unregistered figure sweep'
        generated = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
        buildDir = $Dir
        spineFingerprint = (Get-SpineFingerprint -BuildDir $Dir -SpineDir $Spine)
        inputs = [pscustomobject]@{
            spineFiles = @($spineFiles | ForEach-Object { $_.Name })
            spineCells = $spineCellCount
            corpusDir = $corpusResolved
            corpusClassifiedFrom = $corpusDocs.ClassifiedFrom
            canonicalSources = @($sourceArr | ForEach-Object { [pscustomobject]@{ name = $_.Name; path = $_.Path; lines = $_.LineCount } })
            unitExtractLoaded = $unitLoaded
            unitExtractFrom = $(if ($unitLoaded) { $sharedFrom } else { 'NOT LOADED' })
            registryEntries = $regArr.Length
            registryGroupCovers = $groupCover.psbase.Count
            identifiersDerived = (Get-CoverageDistinctCount -Table $identSet)
            renderedArmRan = ($renderedFiles.Count -gt 0)
            renderedExtracts = @($renderedFiles)
        }
        harvest = [pscustomobject]@{
            #  THE HARVEST ARITHMETIC, PRINTED SO IT CAN BE CHECKED. Every span
            #  the harvester found either became a candidate occurrence or was
            #  removed by a NAMED rule. A `continue` that dropped a span off the
            #  books made the suppression tally meaningless, so the identity is
            #  computed and reported: rawSpans = candidateOccurrences +
            #  suppressedOccurrences, and balanced says whether it holds.
            rawSpans = $rawSpans
            candidateOccurrences = $occArr.Length
            suppressedOccurrences = $supTotal
            balanced = (($occArr.Length + $supTotal) -eq $rawSpans)
            #  Spans swallowed by a longer span's unit continuation. Not a
            #  suppression - the characters are harvested once, by the longer
            #  candidate - and never counted in the identity above.
            spansConsumedByContinuation = $consumedSpans
            distinctCandidates = $cand.psbase.Count
            byClass = @($occArr | Group-Object Class | ForEach-Object { [pscustomobject]@{ class = $_.Name; occurrences = $_.Count } })
        }
        suppression = @($supRows.ToArray())
        dispositions = [pscustomobject]@{
            matched = $byDisp['MATCHED']; present = $byDisp['PRESENT']
            derived = $byDisp['DERIVED']; undispositioned = $byDisp['UNDISPOSITIONED']
        }
        workOrder = @($workRows.ToArray())
        findingWriter = $(if ($haveFindingWriter) { 'Lib-GateCommon New-GateFinding' } else { "this gate's own shape - New-GateFinding is not in Lib-GateCommon yet" })
        candidates = @($candRows.ToArray())
        verdict = $(if ($undis.Count -eq 0) { 'PASS' } else { 'FAIL' })
    }

    if (-not $OutReport) { $OutReport = Join-Path $Dir 'figure-coverage-report.json' }
    [System.IO.File]::WriteAllText($OutReport, ($reportObj | ConvertTo-Json -Depth 9), (New-Object System.Text.UTF8Encoding($true)))

    if ($say) {
        Write-Host ''
        Write-Host 'UNREGISTERED FIGURE SWEEP' -ForegroundColor Cyan
        Write-Host ("  spine: {0} file(s), {1} cell(s); rendered arm: {2}" -f $spineFiles.Count, $spineCellCount, $(if ($renderedFiles.Count -gt 0) { "$($renderedFiles.Count) extract(s)" } else { 'NOT RUN - no -DocText (expected at 3c, required at 7c)' })) -ForegroundColor $(if ($renderedFiles.Count -gt 0) { 'DarkGray' } else { 'Yellow' })
        #  The registry, source, harvest and rendered check-sets are printed
        #  above, unconditionally and blocking: a check-set printed only when
        #  the console is on is a check-set nobody can refuse on.
        Write-GateCheckSet -What 'identifier tokens' -Count (Get-CoverageDistinctCount -Table $identSet) -DerivedFrom 'contract.json fields naming an ABN, ACN, CRICOS, RTO, provider or unit code, whose value also has an identifier shape - never typed into this gate'
        if ($identNames.Count -gt 0) { Write-Host ("    identifiers: {0}" -f ($identNames -join '; ')) -ForegroundColor DarkGray }
        Write-Host ("  candidate claims: {0} distinct, from {1} occurrence(s) harvested from every text channel of the spine" -f $cand.psbase.Count, $occArr.Length) -ForegroundColor DarkGray
        if (-not $unitLoaded) {
            Write-Host '  ! unit extract NOT LOADED - unit wording cannot source a figure. Every hit below is suspect' -ForegroundColor Yellow
            Write-Host '    until unit_extract.md is beside the build or passed as -ExcludeText.' -ForegroundColor Yellow
        }
        Write-Host ''
        Write-Host '  suppression - structural only, every rule named, with what it removed:' -ForegroundColor DarkGray
        foreach ($r in $supRows) {
            $ex = ''
            #  Get-GateCount, not @($r.examples).Count: @($null).Count is 1 in
            #  PS 5.1, so a suppression row with no examples property printed
            #  an empty "e.g." beside its count as if it had shown its work.
            if ((Get-GateCount -Value $r.examples) -gt 0) { $ex = '  e.g. ' + (($r.examples | ForEach-Object { "'$_'" }) -join ', ') }
            Write-Host ("    {0,-14} {1,7} occurrence(s), {2,5} distinct{3}" -f $r.rule, $r.occurrencesRemoved, $r.distinctRemoved, $ex) -ForegroundColor DarkGray
        }
        $balanced = (($occArr.Length + $supTotal) -eq $rawSpans)
        Write-Host ("    {0,-14} {1,7} raw span(s) = {2} candidate occurrence(s) + {3} suppressed{4}" -f `
            'HARVEST', $rawSpans, $occArr.Length, $supTotal, $(if ($balanced) { '' } else { '   <-- DOES NOT BALANCE: a span was dropped without a rule' })) -ForegroundColor $(if ($balanced) { 'DarkGray' } else { 'Red' })
        Write-Host ("    {0,-14} {1,7} span(s) folded into a longer value's unit (a year inside a date, a scale after a degree) - harvested once, by the longer value" -f 'CONSUMED', $consumedSpans) -ForegroundColor DarkGray
        Write-Host ''
        Write-Host ("  dispositions: MATCHED {0}   PRESENT {1}   DERIVED {2}   UNDISPOSITIONED {3}" -f `
            $byDisp['MATCHED'], $byDisp['PRESENT'], $byDisp['DERIVED'], $byDisp['UNDISPOSITIONED']) -ForegroundColor DarkGray
        #  THE INPUT CHAIN OF EVERY DERIVED ROW. "DERIVED" without its inputs is
        #  an assertion; with them it is a claim a reader can check, and it is
        #  the only place the chain a fixpoint walked is visible.
        $derivedRows = @()
        foreach ($dk in @($cand.Keys)) { if ($cand[$dk].Disposition -eq 'DERIVED') { $derivedRows += $cand[$dk] } }
        if ($derivedRows.Count -gt 0) {
            Write-Host '  DERIVED, each with the input chain it resolved through:' -ForegroundColor DarkGray
            $dn = 0
            foreach ($dr in $derivedRows) {
                if ($dn -ge $ShowMax) { break }
                $dn++
                Write-Host ("    '{0}' <- [{1}]   ({2})" -f $dr.Shown, ((@($dr.DerivedFrom)) -join '; '), $dr.DerivedVia) -ForegroundColor DarkGray
            }
            if ($derivedRows.Count -gt $dn) { Write-Host ("    ... and {0} more, all of them in the report" -f ($derivedRows.Count - $dn)) -ForegroundColor DarkGray }
        }
        Write-Host ("  complete work order written to {0}" -f $OutReport) -ForegroundColor DarkGray
    }

    if ($undis.Count -eq 0) {
        if ($say) { Write-Host '  every candidate claim on the spine carries a disposition' -ForegroundColor Green }
        return 0
    }

    if ($say) {
        Write-Host ''
        Write-Host ("  X {0} candidate claim(s) carry NO disposition" -f $undis.Count) -ForegroundColor Red
        $n = 0
        foreach ($e in $undis) {
            if ($n -ge $ShowMax) { break }
            $n++
            $a = $e.Anchors[0]
            Write-Host ("    [{0}] {1}{2}  (channel: {3})" -f $a.File, $a.Path, $(if ($a.Slot) { " slot $($a.Slot)" } else { '' }), $a.Channel) -ForegroundColor Yellow
            Write-Host ("      candidate: '{0}'  ({1}, x{2})" -f $e.Shown, $e.Class, $e.Occurrences) -ForegroundColor Red
            Write-Host ("      sentence:  {0}" -f $a.Sentence) -ForegroundColor DarkGray
            foreach ($w in $e.WhyNot.Keys) { Write-Host ("      not {0}: {1}" -f $w, $e.WhyNot[$w]) -ForegroundColor DarkGray }
        }
        if ($undis.Count -gt $ShowMax) { Write-Host ("    ... and {0} more, all of them in the report" -f ($undis.Count - $ShowMax)) -ForegroundColor DarkGray }
        Write-Host ''
        Write-Host '  Each one is fixed by giving it a disposition, not by narrowing this gate: register it in' -ForegroundColor Yellow
        Write-Host '  figures.json with its authority and source, correct it to a value a source carries, or state' -ForegroundColor Yellow
        Write-Host '  its inputs in the content so the derivation can be read. A value nothing supports is deleted.' -ForegroundColor Yellow
    }
    return 1
}

# ---------------------------------------------------------------------------
# Self-test. Rule 2: no clean result is trusted until the gate has been shown to
# FAIL on a seeded defect, and the plant is verified to have landed first.
# ---------------------------------------------------------------------------

function New-CoverageFixture {
    param(
        [Parameter(Mandatory)][string] $Root,
        [Parameter(Mandatory)][hashtable] $Sub,
        #  Extra CANONICAL SOURCE lines, for the cases that turn on whether a
        #  named input is in a source or is not.
        [string[]] $PackExtra,
        #  A replacement figures[] array, for the cases that turn on the SHAPE
        #  of a registry entry (derivedFrom, value) rather than on its content.
        [object[]] $Figures
    )

    $null = New-Item -ItemType Directory -Path $Root -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $Root 'spine') -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $Root 'cleanroom\pack') -Force
    $enc = New-Object System.Text.UTF8Encoding($true)

    $packLines = @(
        'ACI Culinary fixture pack - learner workbook extract.',
        'Task 3(a) Standard recipe card 5501 yields 8 portions of 250 Gms.',
        'Task 5(b) Cool the sauce to 21 degrees C or below within 2 hours.',
        'Task 6(c) Hold the hot bain marie at 60 degrees C for service.',
        'Task 7(d) The chest freezer runs at minus 18 degrees C.',
        'Task 8(e) Each carton holds 12 packs and each pack holds 4 serves.',
        'Task 9(f) The trial run used a factor of 9 on the card quantity.'
    )
    foreach ($xl in @($PackExtra)) { if ("$xl".Trim()) { $packLines += [string]$xl } }
    $pack = ($packLines -join "`r`n")
    [System.IO.File]::WriteAllText((Join-Path $Root 'cleanroom\pack\Fixture_Workbook.txt'), $pack, $enc)
    $ag = @(
        'Fixture assessor guide extract.',
        'Assessor benchmark: the answer states 21 degrees C or below within 2 hours.'
    ) -join "`r`n"
    [System.IO.File]::WriteAllText((Join-Path $Root 'cleanroom\pack\Assessor_Guide_Fixture.txt'), $ag, $enc)
    [System.IO.File]::WriteAllText((Join-Path $Root 'unit_extract.md'), "# Fixture unit extract`r`nPerformance evidence for the fixture unit.`r`n", $enc)

    $figs = @(
        @{ name = 'Cooling stage 1 - house standard'; authority = 'V'
           source = 'Fixture workbook Task 5(b)'
           require = @('21 degrees C or below within 2 hours') },
        @{ name = 'Hot holding temperature'; authority = 'L'
           source = 'Fixture workbook Task 6(c)'
           require = @('60 degrees C') }
    )
    if ($null -ne $Figures -and @($Figures).Count -gt 0) { $figs = @($Figures) }
    $reg = @{ figures = $figs }
    [System.IO.File]::WriteAllText((Join-Path $Root 'figures.json'), ($reg | ConvertTo-Json -Depth 6), $enc)
    #  The fixture's unit code is COMPOSED rather than written out, so a hygiene
    #  scan for a hard-coded national unit code (rule 5) reads this file clean
    #  and no reader can mistake a fixture value for some build's own.
    $fixCode = 'ZZ' + 'TEST' + '000'
    [System.IO.File]::WriteAllText((Join-Path $Root 'contract.json'), ('{ "unitCode": "' + $fixCode + '" }'), $enc)

    foreach ($name in $Sub.Keys) {
        [System.IO.File]::WriteAllText((Join-Path $Root ('spine\' + $name)), ($Sub[$name] | ConvertTo-Json -Depth 8), $enc)
    }
    return $Root
}

function Test-CoveragePlantLanded {
    <#  READ THE FIXTURE BACK and confirm the planted sentence is in the exact
        channel this gate scans. A plant that did not land proves nothing, and
        one on this project passed a gate by writing into a file the gate does
        not read.  #>
    param([string] $Root, [string] $FileName, [string] $Needle)

    $j = Get-GateJson -Path (Join-Path $Root ('spine\' + $FileName))
    if ($null -eq $j) { return $false }
    $skipF = @{}
    foreach ($k in (Get-GateUnrenderedFields -BuildDir $Root -ForSweep).Keys) { $skipF[$k] = $true }
    foreach ($c in (Get-GateSpineCells -Node $j -File $FileName -Path '' -Channel '' -Slot '' -Skip $skipF)) {
        if ($c.Text.IndexOf($Needle, [System.StringComparison]::Ordinal) -ge 0) { return $true }
    }
    return $false
}

if ($SelfTest) {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('figcov-selftest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $failures = 0
    #  The runs case 11 checks the harvest arithmetic over. Declared here so a
    #  plant that did not land leaves a $null rather than an undefined variable,
    #  and case 11 skips it instead of reading a stale run from another case.
    $r0 = $null; $r1 = $null; $r2 = $null; $r3 = $null; $r4 = $null
    $r5 = $null; $r5b = $null; $r8 = $null; $r9 = $null; $r10 = $null; $r10b = $null
    Write-Host ''
    Write-Host 'ASSERT-FIGURECOVERAGE SELF-TEST' -ForegroundColor Cyan
    Write-Host ("  fixtures under {0}" -f $root) -ForegroundColor DarkGray

    $cleanSub = @{
        't1_1.1.json' = [ordered]@{
            ref = '1.1'; pc = '1.1'; topic = 1; title = 'Confirm the recipe'
            whatThisMeans = @(
                'Standard recipe card 5501 yields 8 portions of 250 Gms.',
                'Cool the sauce to 21 degrees C or below within 2 hours before it goes to the chiller.',
                'Hold the hot bain marie at 60 degrees C for service.'
            )
            workedExample = [ordered]@{
                lead = 'Sizing the batch'
                body = @('The card makes 8 portions at 250 Gms, so 8 multiplied by 250 is 2000 Gms for the run.')
            }
        }
    }

    function Invoke-CoverageChild {
        <#  -Extra adds parameters (Stage, DocText) to the run. *>&1 into a
            string, because a refusal writes no report and speaks only through
            the console, and -Width 4096 because the host otherwise wraps and
            an assertion would then turn on the terminal width. #>
        #  A HASHTABLE SPLAT, not a child process command line. `powershell.exe
        #  -File` passes every argument as a literal string, so '-DocText a,b'
        #  arrived as ONE path named 'a,b' and the run was refused for an
        #  extract that does not exist - a self-test artefact that looked
        #  exactly like a gate defect.
        param([string] $Dir, [hashtable] $Extra)
        $rep = Join-Path $Dir ('figure-coverage-report-' + [guid]::NewGuid().ToString('N').Substring(0, 6) + '.json')
        $params = @{ BuildDir = $Dir; ReportPath = $rep; Quiet = $true }
        if ($null -ne $Extra) { foreach ($k in $Extra.Keys) { $params[$k] = $Extra[$k] } }
        $global:LASTEXITCODE = 0
        $text = & $PSCommandPath @params *>&1 | Out-String -Width 4096
        $code = $LASTEXITCODE
        $obj = $null
        if (Test-Path -LiteralPath $rep) { $obj = Get-GateJson -Path $rep }
        return [pscustomobject]@{ Exit = $code; Report = $obj; Text = $text }
    }

    function Get-CoverageCandidate {
        <# The candidate row whose harvested string matches, or $null. #>
        param($Report, [string] $Fragment)
        if ($null -eq $Report) { return $null }
        foreach ($c in @($Report.candidates)) {
            if ("$($c.shown)".IndexOf($Fragment, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { return $c }
        }
        return $null
    }

    function Test-CoverageHasUndispositioned {
        param($Report, [string] $Fragment)
        if ($null -eq $Report) { return $false }
        foreach ($w in @($Report.workOrder)) {
            if ("$($w.candidate)".IndexOf($Fragment, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true }
            if ("$($w.shown)".IndexOf($Fragment, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true }
        }
        return $false
    }

    try {
        # ---- 0. the clean fixture must PASS, or a gate that fails on
        #         everything would pass its own self-test.
        $d0 = New-CoverageFixture -Root (Join-Path $root 'clean') -Sub $cleanSub
        $r0 = Invoke-CoverageChild -Dir $d0
        #  The clean fixture states a derivation - "8 portions at 250 Gms, so 8
        #  multiplied by 250 is 2000 Gms" - whose RESULT is in no source. It has
        #  to pass AS A DERIVATION, or plant 3 proves nothing: a gate that failed
        #  every unsourced number would appear to detect an unresolved input by
        #  accident while the DERIVED disposition was dead code.
        $r0Derived = 0
        if ($null -ne $r0.Report) { $r0Derived = [int]$r0.Report.dispositions.derived }
        if ($r0.Exit -eq 0 -and $r0Derived -gt 0) {
            Write-Host ("  ok  clean fixture PASSES with {0} DERIVED disposition(s) - green is reachable and the derived arm is live" -f $r0Derived) -ForegroundColor Green
        }
        elseif ($r0.Exit -eq 0) {
            Write-Host '  X   clean fixture passed but NOTHING dispositioned as DERIVED - the derived arm is dead code, so plant 3 would prove nothing' -ForegroundColor Red
            $failures++
        }
        else {
            Write-Host ("  X   clean fixture did not pass (exit {0}); every later assertion is worthless" -f $r0.Exit) -ForegroundColor Red
            if ($null -ne $r0.Report) { foreach ($w in @($r0.Report.workOrder)) { Write-Host ("      residue: '{0}' in {1}" -f $w.shown, $w.located[0].fieldPath) -ForegroundColor DarkGray } }
            $failures++
        }

        # ---- 1. an unregistered temperature in a prose field
        $sub1 = @{ 't1_1.1.json' = [ordered]@{
            ref = '1.1'; pc = '1.1'; topic = 1; title = 'Confirm the recipe'
            whatThisMeans = @('Hold the braised beef at 93 degrees C throughout the service period.') } }
        $d1 = New-CoverageFixture -Root (Join-Path $root 'plant-temp') -Sub $sub1
        if (-not (Test-CoveragePlantLanded -Root $d1 -FileName 't1_1.1.json' -Needle '93 degrees C')) {
            Write-Host '  X   plant 1 DID NOT LAND in a channel this gate scans - it proves nothing' -ForegroundColor Red; $failures++
        }
        else {
            $r1 = Invoke-CoverageChild -Dir $d1
            if ($r1.Exit -eq 1 -and (Test-CoverageHasUndispositioned -Report $r1.Report -Fragment '93 degrees c')) {
                Write-Host "  ok  plant 1 landed and the gate FAILED on it: unregistered temperature '93 degrees C'" -ForegroundColor Green
            }
            else { Write-Host ("  X   plant 1 landed and the gate did NOT fail on it (exit {0})" -f $r1.Exit) -ForegroundColor Red; $failures++ }
        }

        # ---- 2. an unregistered named piece of equipment
        $sub2 = @{ 't1_1.1.json' = [ordered]@{
            ref = '1.1'; pc = '1.1'; topic = 1; title = 'Confirm the recipe'
            whatThisMeans = @('Transfer the batch to the Vulcanor Rapidchill before it is labelled.') } }
        $d2 = New-CoverageFixture -Root (Join-Path $root 'plant-equip') -Sub $sub2
        if (-not (Test-CoveragePlantLanded -Root $d2 -FileName 't1_1.1.json' -Needle 'Vulcanor Rapidchill')) {
            Write-Host '  X   plant 2 DID NOT LAND in a channel this gate scans - it proves nothing' -ForegroundColor Red; $failures++
        }
        else {
            $r2 = Invoke-CoverageChild -Dir $d2
            if ($r2.Exit -eq 1 -and (Test-CoverageHasUndispositioned -Report $r2.Report -Fragment 'vulcanor rapidchill')) {
                Write-Host "  ok  plant 2 landed and the gate FAILED on it: unregistered equipment 'Vulcanor Rapidchill'" -ForegroundColor Green
            }
            else { Write-Host ("  X   plant 2 landed and the gate did NOT fail on it (exit {0})" -f $r2.Exit) -ForegroundColor Red; $failures++ }
        }

        # ---- 3. a derivation whose named input does not resolve
        $sub3 = @{ 't1_1.1.json' = [ordered]@{
            ref = '1.1'; pc = '1.1'; topic = 1; title = 'Confirm the recipe'
            whatThisMeans = @('Take the 47 kg trial mass and multiply it by 9, so the run needs 423 kg of stock.') } }
        $d3 = New-CoverageFixture -Root (Join-Path $root 'plant-derive') -Sub $sub3
        if (-not (Test-CoveragePlantLanded -Root $d3 -FileName 't1_1.1.json' -Needle '423 kg')) {
            Write-Host '  X   plant 3 DID NOT LAND in a channel this gate scans - it proves nothing' -ForegroundColor Red; $failures++
        }
        else {
            $r3 = Invoke-CoverageChild -Dir $d3
            $sawResult = Test-CoverageHasUndispositioned -Report $r3.Report -Fragment '423 kg'
            $sawInput = Test-CoverageHasUndispositioned -Report $r3.Report -Fragment '47 kg'
            if ($r3.Exit -eq 1 -and $sawResult -and $sawInput) {
                Write-Host "  ok  plant 3 landed and the gate FAILED on it: '423 kg' derived from an unresolved '47 kg'" -ForegroundColor Green
            }
            else { Write-Host ("  X   plant 3 landed and the gate did NOT fail correctly (exit {0}, result seen {1}, input seen {2})" -f $r3.Exit, $sawResult, $sawInput) -ForegroundColor Red; $failures++ }
        }

        # ---- 4. a candidate that IS registered must not fire
        $sub4 = @{ 't1_1.1.json' = [ordered]@{
            ref = '1.1'; pc = '1.1'; topic = 1; title = 'Confirm the recipe'
            whatThisMeans = @('Cool the sauce to twenty one degrees C or below within two hours, then chill.') } }
        $d4 = New-CoverageFixture -Root (Join-Path $root 'registered') -Sub $sub4
        if (-not (Test-CoveragePlantLanded -Root $d4 -FileName 't1_1.1.json' -Needle 'twenty one degrees C')) {
            Write-Host '  X   control 4 DID NOT LAND - it proves nothing' -ForegroundColor Red; $failures++
        }
        else {
            $r4 = Invoke-CoverageChild -Dir $d4
            $fired = Test-CoverageHasUndispositioned -Report $r4.Report -Fragment 'degrees c'
            if ($r4.Exit -eq 0 -and -not $fired) {
                Write-Host '  ok  control 4: a registered figure written in word form did NOT fire (variant-aware)' -ForegroundColor Green
            }
            else { Write-Host ("  X   control 4: a REGISTERED figure fired - this gate would cry wolf (exit {0})" -f $r4.Exit) -ForegroundColor Red; $failures++ }
        }

        # ---- 5. THE BOUNDED HARVESTER (P1-02). Four sentences, four shapes the
        #         harvester used to mangle, and the assertion is on the EXACT
        #         SET of quantity-class candidates they yield. This used to be a
        #         KNOWN-DEFECT marker recording that '7.45 am' came back as
        #         '45 am'; a marker is not a proof, so it is now an assertion.
        #
        #         The point of asserting the WHOLE SET, and not just that the
        #         four wanted strings are present, is that the defect was never
        #         a missing candidate - it was an EXTRA one the harvester
        #         invented out of the tail of a value and the word after it.
        #         "and '45 am' is not there" only holds if nothing else is
        #         either.
        $harvestProse = @(
            'The delivery window opens at 7.45 am on the day of service.',
            'The supplier invoice shows $20.00 x 4 cartons on the docket.',
            'Chill the stock to 5 degrees C before it goes to the store.',
            'Each rack holds 20 per tray in the cold room.'
        )
        $sub5 = @{ 't1_1.1.json' = [ordered]@{
            ref = '1.1'; pc = '1.1'; topic = 1; title = 'Confirm the recipe'
            whatThisMeans = $harvestProse } }
        $d5 = New-CoverageFixture -Root (Join-Path $root 'harvest-bounds') -Sub $sub5
        $landed5 = $true
        foreach ($needle5 in @('7.45 am', '$20.00 x 4 cartons', '5 degrees C', '20 per tray')) {
            if (-not (Test-CoveragePlantLanded -Root $d5 -FileName 't1_1.1.json' -Needle $needle5)) {
                Write-Host ("  X   case 5: '{0}' DID NOT LAND in a channel this gate scans - it proves nothing" -f $needle5) -ForegroundColor Red
                $failures++; $landed5 = $false
            }
        }
        if ($landed5) {
            $r5 = Invoke-CoverageChild -Dir $d5
            $wanted5 = @('7.45 am', '$20.00', '4 carton', '5 degrees c', '20 per tray')
            $got5 = @(@($r5.Report.candidates) | Where-Object { $_.class -ne 'named' } | ForEach-Object { "$($_.shown)" } | Sort-Object)
            $missing5 = @($wanted5 | Where-Object { $got5 -notcontains $_ })
            $extra5 = @($got5 | Where-Object { $wanted5 -notcontains $_ })
            if ($missing5.Count -eq 0 -and $extra5.Count -eq 0) {
                Write-Host ("  ok  case 5: the harvest is EXACTLY {{{0}}} - no '45 am' cut out of a clock, no '`$20.00 x' glued out of an amount and an operator, the degree closed on its scale, the rate kept its noun" -f (($wanted5 | ForEach-Object { "'$_'" }) -join ', ')) -ForegroundColor Green
            }
            else {
                Write-Host ("  X   case 5: harvest is {{{0}}}; missing [{1}]; unwanted [{2}]" -f (($got5 | ForEach-Object { "'$_'" }) -join ', '), ($missing5 -join '; '), ($extra5 -join '; ')) -ForegroundColor Red
                $failures++
            }
            #  Said again the other way round, because these two strings are the
            #  named defects and a set comparison that drifted must not stop
            #  saying so.
            $badShown = @(@($r5.Report.candidates) | Where-Object { "$($_.shown)" -eq '45 am' -or "$($_.shown)" -eq '$20.00 x' } | ForEach-Object { "$($_.shown)" })
            if ($badShown.Count -eq 0) { Write-Host "  ok  case 5: neither '45 am' nor '`$20.00 x' is a candidate" -ForegroundColor Green }
            else { Write-Host ("  X   case 5: the harvester still invents [{0}]" -f ($badShown -join '; ')) -ForegroundColor Red; $failures++ }
            #  None of the five is registered or in a source, so the gate must
            #  FAIL on them: the strings are corrected, the sweep is not narrowed.
            if ($r5.Exit -eq 1) { Write-Host '  ok  case 5: all five corrected candidates are UNDISPOSITIONED and the gate fails on them - the strings were fixed, not the coverage' -ForegroundColor Green }
            else { Write-Host ("  X   case 5: exit {0}, wanted 1 - correcting the harvested strings must not disposition anything" -f $r5.Exit) -ForegroundColor Red; $failures++ }
            #  The full span is kept as the anchor, so the reader can still find
            #  '$20.00 x 4 cartons' on the page from a work order that names
            #  '$20.00'.
            $moneyRow = @(@($r5.Report.workOrder) | Where-Object { "$($_.shown)" -eq '$20.00' })
            if ($moneyRow.Count -eq 1 -and "$($moneyRow[0].anchor)" -match '^\$20\.00') {
                Write-Host ("  ok  case 5: the work order names the value '`$20.00' and anchors it on the full span '{0}'" -f $moneyRow[0].anchor) -ForegroundColor Green
            }
            else { Write-Host ("  X   case 5: the money work order carries no full-span anchor ({0} row(s))" -f $moneyRow.Count) -ForegroundColor Red; $failures++ }
        }

        # ---- 5b. THE CLEAN CONTROL for case 5. The same four sentences with
        #          every corrected string registered pass. This is what proves
        #          the corrected strings are the ones a reader can act on: a
        #          candidate nobody can register is a candidate nobody can close.
        $figs5b = @(
            @{ name = 'Delivery window'; authority = 'V'; source = 'Fixture workbook'; require = @('7.45 am') },
            @{ name = 'Menu selling price'; authority = 'V'; source = 'Fixture workbook'; require = @('$20.00') },
            @{ name = 'Carton count on the docket'; authority = 'V'; source = 'Fixture workbook'; require = @('4 cartons') },
            @{ name = 'Chill temperature'; authority = 'L'; source = 'Fixture workbook'; require = @('5 degrees C') },
            @{ name = 'Tray rate'; authority = 'V'; source = 'Fixture workbook'; require = @('20 per tray') }
        )
        $d5b = New-CoverageFixture -Root (Join-Path $root 'harvest-bounds-clean') -Sub $sub5 -Figures $figs5b
        $r5b = Invoke-CoverageChild -Dir $d5b
        if ($r5b.Exit -eq 0) {
            Write-Host '  ok  control 5b: the same four sentences pass once each corrected string is registered - every candidate the bounded harvester produces is a string a registry can name' -ForegroundColor Green
        }
        else {
            Write-Host ("  X   control 5b: exit {0}, wanted 0 - a corrected candidate that its own registry entry cannot match is still unusable" -f $r5b.Exit) -ForegroundColor Red
            if ($null -ne $r5b.Report) { foreach ($w in @($r5b.Report.workOrder)) { Write-Host ("      residue: '{0}'" -f $w.shown) -ForegroundColor DarkGray } }
            $failures++
        }

        # ---- 6. THE RENDERED ARM. -Stage 7c with no extract is a refusal
        #         naming both extracts; with them, the arm is on the roster.
        $r6 = Invoke-CoverageChild -Dir $d0 -Extra @{ Stage = '7c' }
        if ($r6.Exit -eq 2 -and $r6.Text -match 'guide_gate\.txt' -and $r6.Text -match 'deck_gate\.txt') {
            Write-Host '  ok  -Stage 7c with zero -DocText exits 2 naming guide_gate.txt and deck_gate.txt' -ForegroundColor Green
        }
        else { Write-Host ("  X   -Stage 7c with no extract exited {0} (wanted 2) and did not name both extracts" -f $r6.Exit) -ForegroundColor Red; $failures++ }

        $gx = Join-Path $d0 'guide_gate.txt'
        $dx = Join-Path $d0 'deck_gate.txt'
        [System.IO.File]::WriteAllText($gx, "Rendered guide extract.`r`nCool the sauce to 21 degrees C or below within 2 hours.`r`n", (New-Object System.Text.UTF8Encoding($true)))
        [System.IO.File]::WriteAllText($dx, "Rendered deck extract.`r`nHold the hot bain marie at 60 degrees C for service.`r`n", (New-Object System.Text.UTF8Encoding($true)))
        $r7 = Invoke-CoverageChild -Dir $d0 -Extra @{ Stage = '7c'; DocText = @($gx, $dx) }
        $rendArm = @(@($r7.Report.arms) | Where-Object { $_.name -eq 'rendered' })
        if ($r7.Exit -eq 0 -and $rendArm.Count -eq 1 -and $rendArm[0].state -eq 'ran' -and [int]$rendArm[0].size -eq 2) {
            Write-Host '  ok  -Stage 7c with both extracts runs the rendered arm over 2 extract(s) and records it on the roster' -ForegroundColor Green
        }
        else { Write-Host ("  X   the rendered arm did not run at 7c: exit {0}, arm {1}" -f $r7.Exit, $(if ($rendArm.Count -eq 1) { $rendArm[0].state + '/' + $rendArm[0].size } else { 'MISSING from the roster' })) -ForegroundColor Red; $failures++ }

        # ---- 8. THE DERIVED ARM IS REACHABLE (P1-03). A registry entry that
        #         declares derivedFrom confers NO match, so the value has to be
        #         answered by RESOLVING its named inputs. Before this, the entry
        #         dispositioned the value MATCHED by the mere fact of having
        #         been written down, the in-registry derived arm below it was
        #         unreachable by construction, and DERIVED fired 0 times out of
        #         185 candidates on the reference build while the report read as
        #         though the arm had run.
        $sub8 = @{ 't1_1.1.json' = [ordered]@{
            ref = '1.1'; pc = '1.1'; topic = 1; title = 'Confirm the recipe'
            whatThisMeans = @('The finished batch weighs 2000 g at the end of the run.') } }
        $figs8 = @(
            @{ name = 'Batch weight'; authority = 'V'; source = 'Fixture workbook Task 3(a)'
               value = '2000 g'; derivedFrom = @('8', '250 g') }
        )
        $pack8 = @('Task 4(a) Each portion is 250 g on the standard card.')
        $r8 = $null
        $d8 = New-CoverageFixture -Root (Join-Path $root 'derived-ok') -Sub $sub8 -Figures $figs8 -PackExtra $pack8
        if (-not (Test-CoveragePlantLanded -Root $d8 -FileName 't1_1.1.json' -Needle '2000 g')) {
            Write-Host '  X   case 8 DID NOT LAND in a channel this gate scans - it proves nothing' -ForegroundColor Red; $failures++
        }
        else {
            $r8 = Invoke-CoverageChild -Dir $d8
            $c8 = Get-CoverageCandidate -Report $r8.Report -Fragment '2000 g'
            $inputs8 = @()
            if ($null -ne $c8) { $inputs8 = @($c8.derivedFrom) }
            if ($r8.Exit -eq 0 -and $null -ne $c8 -and $c8.disposition -eq 'DERIVED' -and
                "$($c8.matchedBy)" -eq '' -and $inputs8 -contains '8' -and $inputs8 -contains '250 g') {
                Write-Host ("  ok  case 8: '2000 g' reads DERIVED naming its inputs [{0}] via {1} - and NOT MATCHED by being registered" -f ($inputs8 -join '; '), $c8.derivedVia) -ForegroundColor Green
            }
            else {
                Write-Host ("  X   case 8: '2000 g' came back {0} (matchedBy '{1}', inputs [{2}], exit {3}); wanted DERIVED naming 8 and 250 g" -f `
                    $(if ($null -eq $c8) { 'NOT HARVESTED' } else { $c8.disposition }), $(if ($null -eq $c8) { '' } else { $c8.matchedBy }), ($inputs8 -join '; '), $r8.Exit) -ForegroundColor Red
                $failures++
            }
        }

        # ---- 9. THE SAME ENTRY with one named input in no source at all is
        #         UNRESOLVED, and the reason NAMES that input. A fixpoint that
        #         dispositioned on a partial resolution would be a hole exactly
        #         the size of the input nobody supplied.
        $d9 = New-CoverageFixture -Root (Join-Path $root 'derived-unresolved') -Sub $sub8 -Figures $figs8
        $r9 = Invoke-CoverageChild -Dir $d9
        $c9 = Get-CoverageCandidate -Report $r9.Report -Fragment '2000 g'
        $why9 = ''
        if ($null -ne $c9 -and $null -ne $c9.whyNot) { $why9 = "$($c9.whyNot.derived)" }
        if ($r9.Exit -eq 1 -and $null -ne $c9 -and $c9.disposition -eq 'UNDISPOSITIONED' -and
            $why9 -match 'UNRESOLVED' -and $why9 -match [regex]::Escape('250 g')) {
            Write-Host "  ok  case 9: with '250 g' in no canonical source, '2000 g' is UNRESOLVED and the reason names '250 g'" -ForegroundColor Green
        }
        else {
            Write-Host ("  X   case 9: '2000 g' came back {0} (exit {1}) with reason '{2}'; wanted UNDISPOSITIONED naming '250 g' as UNRESOLVED" -f `
                $(if ($null -eq $c9) { 'NOT HARVESTED' } else { $c9.disposition }), $r9.Exit, $why9) -ForegroundColor Red
            $failures++
        }

        # ---- 10. THE ANCHORED VARIANT ARM (P1-03). A spine value that occurs in
        #          the corpus only as a DIGIT SUBSTRING of a different value is
        #          not PRESENT. Unanchored, "7.5 L" matched inside "17.5 L" and
        #          the gate sourced a figure this build never wrote against a
        #          line that says something else - and a wrong PRESENT is a
        #          figure that leaves the gate silently.
        $sub10 = @{ 't1_1.1.json' = [ordered]@{
            ref = '1.1'; pc = '1.1'; topic = 1; title = 'Confirm the recipe'
            whatThisMeans = @('The stock pot takes 7.5 L of water for the batch.') } }
        $pack10 = @('Task 2(a) The bulk pot takes 17.5 L of water for the batch.')
        $d10 = New-CoverageFixture -Root (Join-Path $root 'anchor-present') -Sub $sub10 -PackExtra $pack10
        $r10 = Invoke-CoverageChild -Dir $d10
        $c10 = Get-CoverageCandidate -Report $r10.Report -Fragment '7.5 l'
        if ($r10.Exit -eq 1 -and $null -ne $c10 -and $c10.disposition -ne 'PRESENT') {
            Write-Host ("  ok  case 10: '7.5 L' against a corpus that only says '17.5 L' is NOT PRESENT (it came back {0})" -f $c10.disposition) -ForegroundColor Green
        }
        else {
            Write-Host ("  X   case 10: '7.5 L' came back {0} (exit {1}, source '{2}') - a digit substring of '17.5 L' sourced it" -f `
                $(if ($null -eq $c10) { 'NOT HARVESTED' } else { $c10.disposition }), $r10.Exit, $(if ($null -eq $c10) { '' } else { $c10.sourceFile })) -ForegroundColor Red
            $failures++
        }

        # ---- 10b. THE CLEAN CONTROL. The value the corpus DOES carry is still
        #           PRESENT, or the anchor would just have switched the arm off.
        $sub10b = @{ 't1_1.1.json' = [ordered]@{
            ref = '1.1'; pc = '1.1'; topic = 1; title = 'Confirm the recipe'
            whatThisMeans = @('The bulk pot takes 17.5 L of water for the batch.') } }
        $d10b = New-CoverageFixture -Root (Join-Path $root 'anchor-present-clean') -Sub $sub10b -PackExtra $pack10
        $r10b = Invoke-CoverageChild -Dir $d10b
        $c10b = Get-CoverageCandidate -Report $r10b.Report -Fragment '17.5 l'
        if ($r10b.Exit -eq 0 -and $null -ne $c10b -and $c10b.disposition -eq 'PRESENT') {
            Write-Host ("  ok  control 10b: '17.5 L' IS PRESENT, sourced to {0} line {1} - anchoring did not switch the variant arm off" -f $c10b.sourceFile, $c10b.sourceLine) -ForegroundColor Green
        }
        else {
            Write-Host ("  X   control 10b: '17.5 L' came back {0} (exit {1}) - anchoring the variant arm has switched it off" -f `
                $(if ($null -eq $c10b) { 'NOT HARVESTED' } else { $c10b.disposition }), $r10b.Exit) -ForegroundColor Red
            $failures++
        }

        # ---- 11. THE HARVEST ARITHMETIC CLOSES ON EVERY FIXTURE RUN. Every span
        #          the harvester found is either a candidate occurrence or was
        #          removed by a NAMED rule that counted it. The bare `continue`s
        #          dropped spans off the books, so the printed suppression tally
        #          did not add up to the harvest and no reader could tell a
        #          deliberate narrowing from a bug in the trimmer.
        $balanceRuns = @(
            [pscustomobject]@{ Name = 'clean'; R = $r0 },
            [pscustomobject]@{ Name = 'plant-temp'; R = $r1 },
            [pscustomobject]@{ Name = 'plant-equip'; R = $r2 },
            [pscustomobject]@{ Name = 'plant-derive'; R = $r3 },
            [pscustomobject]@{ Name = 'registered'; R = $r4 },
            [pscustomobject]@{ Name = 'harvest-bounds'; R = $r5 },
            [pscustomobject]@{ Name = 'harvest-bounds-clean'; R = $r5b },
            [pscustomobject]@{ Name = 'derived-ok'; R = $r8 },
            [pscustomobject]@{ Name = 'derived-unresolved'; R = $r9 },
            [pscustomobject]@{ Name = 'anchor-present'; R = $r10 },
            [pscustomobject]@{ Name = 'anchor-present-clean'; R = $r10b }
        )
        $unbalanced = New-Object System.Collections.Generic.List[string]
        $balanceChecked = 0
        foreach ($br in $balanceRuns) {
            if ($null -eq $br.R -or $null -eq $br.R.Report -or $null -eq $br.R.Report.harvest) { continue }
            $balanceChecked++
            $hv = $br.R.Report.harvest
            if (-not [bool]$hv.balanced) {
                $unbalanced.Add(("{0}: {1} raw span(s) <> {2} occurrence(s) + {3} suppressed" -f $br.Name, $hv.rawSpans, $hv.candidateOccurrences, $hv.suppressedOccurrences))
            }
        }
        if ($balanceChecked -eq 0) {
            Write-Host '  X   case 11: no fixture report carried a harvest block - the arithmetic was checked against nothing' -ForegroundColor Red; $failures++
        }
        elseif ($unbalanced.Count -eq 0) {
            Write-Host ("  ok  case 11: on all {0} fixture run(s), rawSpans = candidate occurrences + suppressed occurrences - no span leaves the harvest without a named rule counting it" -f $balanceChecked) -ForegroundColor Green
        }
        else { Write-Host ("  X   case 11: the harvest arithmetic does not close on [{0}]" -f (($unbalanced.ToArray()) -join '; ')) -ForegroundColor Red; $failures++ }

        # ---- 12. EVERY BLOCKING FINDING RE-FINDS ITS OWN ANCHOR. Section 30's
        #          contract: a gate that cannot re-open the file it cites and
        #          re-find the quote it read, at the token boundary, has a
        #          defect of its own and has not found one in the content. This
        #          is the reason the work order anchors on the FULL harvested
        #          span and quotes the value as the document punctuates it -
        #          "$52.00 per kg" at the end of a sentence is only re-findable
        #          with its full stop, because the shared boundary reads a dot
        #          beside a value as a decimal continuation.
        $anchorRuns = @(
            [pscustomobject]@{ Name = 'harvest-bounds'; R = $r5 },
            [pscustomobject]@{ Name = 'plant-temp'; R = $r1 },
            [pscustomobject]@{ Name = 'plant-equip'; R = $r2 },
            [pscustomobject]@{ Name = 'plant-derive'; R = $r3 },
            [pscustomobject]@{ Name = 'derived-unresolved'; R = $r9 },
            [pscustomobject]@{ Name = 'anchor-present'; R = $r10 }
        )
        $anchorChecked = 0
        $anchorBad = New-Object System.Collections.Generic.List[string]
        $writerSeen = $false
        foreach ($ar in $anchorRuns) {
            if ($null -eq $ar.R -or $null -eq $ar.R.Report) { continue }
            if ("$($ar.R.Report.findingWriter)" -notmatch 'New-GateFinding') { continue }
            $writerSeen = $true
            foreach ($w in @($ar.R.Report.workOrder)) {
                $anchorChecked++
                if ("$($w.anchorVerdict)" -ne 'anchored') {
                    $anchorBad.Add(("{0}/'{1}': {2}" -f $ar.Name, $w.shown, $(if ("$($w.anchorVerdict)") { $w.anchorVerdict } else { 'no verdict' })))
                }
            }
        }
        if (-not $writerSeen) {
            Write-Host '  --  case 12 SKIPPED: Lib-GateCommon carries no New-GateFinding yet, so no finding was written through it. This gate emits today''s shape and the anchor contract is unproven until it lands.' -ForegroundColor Yellow
        }
        elseif ($anchorChecked -eq 0) {
            Write-Host '  X   case 12: the finding writer is present and not one work-order row was written through it - the anchor contract was checked against nothing' -ForegroundColor Red; $failures++
        }
        elseif ($anchorBad.Count -eq 0) {
            Write-Host ("  ok  case 12: all {0} blocking finding(s) re-find their own quote at the token boundary in the file they cite" -f $anchorChecked) -ForegroundColor Green
        }
        else {
            Write-Host ("  X   case 12: {0} of {1} finding(s) cannot re-find their own anchor - that is a GATE defect, not a content defect: [{2}]" -f $anchorBad.Count, $anchorChecked, (($anchorBad.ToArray()) -join '; ')) -ForegroundColor Red
            $failures++
        }
    }
    finally {
        if ((Test-Path -LiteralPath $root) -and $root.Length -gt 20) {
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host ''
    if ($failures -eq 0) { Write-Host '  SELF-TEST PASS - the gate fails on every planted defect, passes every clean control, harvests every named shape whole, and its suppression tally adds up to its harvest' -ForegroundColor Green; exit 0 }
    Write-Host ("  SELF-TEST FAIL - {0} assertion(s). No clean result from this gate is trusted until they pass." -f $failures) -ForegroundColor Red
    exit 4
}

if (-not $BuildDir) {
    Write-Host ("{0}: -BuildDir is required (or run with -SelfTest)." -f $GATE) -ForegroundColor Red
    exit 2
}
if (-not (Test-Path -LiteralPath $BuildDir)) {
    Write-Host ("{0}: -BuildDir does not exist: {1}" -f $GATE, $BuildDir) -ForegroundColor Red
    exit 2
}
if ($Stage -and $Stage -notin @('3c', '4', '7c')) {
    Fail-Usage ("-Stage '{0}' is not a band this gate runs at (3c, 4 or 7c)." -f $Stage)
}

#  THE RENDERED ARM REFUSES AN EMPTY RENDERING.
$extracts = @(@($DocText) | Where-Object { "$_".Trim() })
if ($Stage -eq '7c' -and $extracts.Count -eq 0) {
    Fail-Usage 'the rendered arm was asked for (-Stage 7c) and no extract was passed. Pass -DocText <guide extract>,<deck extract> - guide_gate.txt and deck_gate.txt, the extracts Get-DocText writes from the delivered .docx and .pptx. The rendered arm was optional and the runner silently never passed it, which is how an arm that never ran came to be recorded as having run.'
}
foreach ($x in $extracts) {
    if (-not (Test-Path -LiteralPath $x)) { Fail-Usage ("-DocText names an extract that is not there: {0}. An absent extract is refused by name rather than swept as an empty document." -f $x) }
}

try {
    $rc = Invoke-CoverageGate -Dir $BuildDir -Spine $SpineDir -Corpus $CorpusDir -Rules $RulesPath `
            -Shared $ExcludeText -Rendered $extracts -OutReport $ReportPath -ShowMax $MaxWorkOrder -Band $Stage -Silent:$Quiet
}
catch { Stop-OnRefusal $_ }
exit $rc
