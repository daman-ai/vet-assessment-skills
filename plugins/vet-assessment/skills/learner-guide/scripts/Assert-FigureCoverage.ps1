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
                      variant-aware in the same way Test-FigureConsistency's is,
                      so "20 gastronorm", "twenty gastronorm" and "20-tray" are
                      one figure and not three.
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
                      stage calls the same chain fabricated.

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

    PS 5.1. ASCII only in this file.
    Exit 0 clean, 1 undispositioned candidate(s), 2 a usage or input error,
    4 the self-test failed.
#>

[CmdletBinding()]
param(
    [string] $BuildDir,
    [string] $SpineDir,
    [string] $CorpusDir,
    [string] $RulesPath,
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

# ---------------------------------------------------------------------------
# Private helpers. New helpers live HERE and not in Lib-GateCommon: this gate
# owns them, and a shared library grows a private need into a public contract.
# ---------------------------------------------------------------------------

function ConvertTo-CoverageVariantRegex {
    <#  Escape a literal, then let every standalone number also match its
        English word form and every listed word its digits, with spaces
        matching hyphens. This mirrors Test-FigureConsistency's expansion so
        the two gates treat the same three spellings as one figure.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Literal)

    $rx = [regex]::Escape($Literal)
    $rx = [regex]::Replace($rx, '\\ ', '[\s-]+')
    $rx = [regex]::Replace($rx, '(?<![\d.])(\d{1,2})(?![\d.])', {
        param($m); $d = $m.Groups[1].Value
        if ($script:CVG_N2W.ContainsKey($d)) { "(?:$d|$($script:CVG_N2W[$d]))" } else { $d }
    })
    foreach ($w in $script:CVG_W2N.Keys) {
        $rx = [regex]::Replace($rx, "(?i)\b$w\b", "(?:$w|$($script:CVG_W2N[$w]))")
    }
    return "(?i)$rx"
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
        [Parameter(Mandatory)][string] $Needle,
        [Parameter(Mandatory)] $Indexes
    )

    if (-not $Needle) { return $null }
    $pad = ' ' + $Needle + ' '
    foreach ($ix in $Indexes) {
        $at = $ix.Norm.IndexOf($pad, [System.StringComparison]::Ordinal)
        if ($at -ge 0) {
            return [pscustomobject]@{ Source = $ix.Name; Line = (Get-CoverageSourceLine -Index $ix -Offset ($at + 1)); How = 'verbatim' }
        }
    }
    $rx = ConvertTo-CoverageVariantRegex -Literal $Needle
    foreach ($ix in $Indexes) {
        $m = [regex]::Match($ix.Norm, $rx)
        if ($m.Success) {
            return [pscustomobject]@{ Source = $ix.Name; Line = (Get-CoverageSourceLine -Index $ix -Offset $m.Index); How = 'variant' }
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
    $rxClock= '(?i)(?<![\d.:])(?<num>\d{1,2}:\d{2})\s*(?<unit>am|pm)?(?![\d:])'
    $rxTime = '(?i)\b(?<num>\d{1,2})\s*(?<unit>am|pm|noon|midnight)\b'
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
                     'SUP-HEADFIELD','SUP-NICOMMON','SUP-SENTINIT')) {
        $supCount[$r] = 0; $supDistinct[$r] = @{}; $supSample[$r] = New-Object System.Collections.Generic.List[string]
    }
    function Add-CoverageSuppressed {
        param([string] $Rule, [string] $Key, [string] $Shown)
        $supCount[$Rule] = $supCount[$Rule] + 1
        $supDistinct[$Rule][$Key] = $true
        if ($supSample[$Rule].Count -lt 3) { $supSample[$Rule].Add($Shown) }
    }
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
                $hits.Add([pscustomobject]@{ M = $m; Class = 'time'; Num = $m.Groups['num'].Value; Unit = $m.Groups['unit'].Value })
            }
            foreach ($h in $hits) { for ($i = $h.M.Index; $i -lt ($h.M.Index + $h.M.Length); $i++) { $masked[$i] = ' ' } }
            $stage0 = -join $masked
            foreach ($m in [regex]::Matches($stage0, $rxTime)) {
                $hits.Add([pscustomobject]@{ M = $m; Class = 'time'; Num = $m.Groups['num'].Value; Unit = $m.Groups['unit'].Value })
            }
            foreach ($h in $hits) { for ($i = $h.M.Index; $i -lt ($h.M.Index + $h.M.Length); $i++) { $masked[$i] = ' ' } }
            $stage1 = -join $masked
            foreach ($m in [regex]::Matches($stage1, $rxRatio)) {
                $hits.Add([pscustomobject]@{ M = $m; Class = 'ratio'; Num = $m.Groups['num'].Value; Unit = (':' + $m.Groups['unit'].Value) })
            }
            foreach ($m in [regex]::Matches($stage1, $rxPh)) {
                $hits.Add([pscustomobject]@{ M = $m; Class = 'ph'; Num = $m.Groups['num'].Value; Unit = 'ph' })
            }
            foreach ($h in $hits) { for ($i = $h.M.Index; $i -lt ($h.M.Index + $h.M.Length); $i++) { $masked[$i] = ' ' } }
            $maskedText = -join $masked

            foreach ($m in [regex]::Matches($maskedText, $rxQty)) {
                $numRaw = $m.Groups['num'].Value
                $unit = ''
                if ($m.Groups['unit'].Success) { $unit = $m.Groups['unit'].Value }
                #  Step over a modifier to reach the unit; this only ever widens
                #  the harvest. Two steps is enough for "5 different usable trays".
                $after = $maskedText.Substring($m.Index + $m.Length)
                $steps = 0
                while ($unit -and $script:CVG_MODSET.ContainsKey($unit.ToLowerInvariant()) -and $steps -lt 2) {
                    $nx = [regex]::Match($after, '^(?:\s*-\s*|\s+)([A-Za-z][A-Za-z]{0,17})')
                    if (-not $nx.Success) { break }
                    $unit = $nx.Groups[1].Value
                    $after = $after.Substring($nx.Length)
                    $steps++
                }
                #  A degree needs its scale, and a month needs its year, or the
                #  candidate is not the figure the reader sees.
                if ($unit -match '(?i)^degrees?$') {
                    $nx = [regex]::Match($after, '^\s*([A-Za-z]{1,9})')
                    if ($nx.Success) { $unit = $unit + ' ' + $nx.Groups[1].Value }
                }
                elseif ($unit -match '(?i)^per$') {
                    $nx = [regex]::Match($after, '^\s*(cent)\b')
                    if ($nx.Success) { $unit = 'per cent' } else { $unit = '' }
                }
                elseif ($unit -and $script:CVG_MONTHSET.ContainsKey($unit.ToLowerInvariant())) {
                    $nx = [regex]::Match($after, '^\s*((?:19|20)\d{2})\b')
                    if ($nx.Success) { $unit = $unit + ' ' + $nx.Groups[1].Value }
                }
                $isMoney = ($numRaw -match '^\$')
                $hits.Add([pscustomobject]@{
                    M = $m; Class = $(if ($isMoney) { 'money' } else { 'quantity' }); Num = $numRaw; Unit = $unit })
            }

            foreach ($m in [regex]::Matches($maskedText, $rxNamed)) {
                $hits.Add([pscustomobject]@{ M = $m; Class = 'named'; Num = ''; Unit = $m.Value })
            }

            foreach ($h in $hits) {
                $m = $h.M
                $shown = $m.Value.Trim()
                $before = $maskedText.Substring(0, $m.Index)
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
                    if ($tokens.Count -eq 0) { continue }
                    $tokens = @($tokens | ForEach-Object { $_ -replace "['\u2019]s$", '' } | Where-Object { $_ })
                    if ($tokens.Count -eq 0) { continue }
                    $phrase = ($tokens -join ' ')
                    $key = ConvertTo-GateNormal $phrase
                    if (-not $key -or $key.Length -lt 3) { continue }
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
                    if ($h.Class -eq 'quantity') {
                        if (-not $unitNorm) { Add-CoverageSuppressed -Rule 'SUP-BARENUM' -Key (ConvertTo-GateNormal $shown) -Shown $shown; continue }
                        if ($script:CVG_STOPSET.ContainsKey($unitNorm)) { Add-CoverageSuppressed -Rule 'SUP-BARENUM' -Key ($numNorm + ' ' + $unitNorm) -Shown $shown; continue }
                    }
                    $key = (ConvertTo-GateNormal ($h.Num + ' ' + $h.Unit))
                    if (-not $key) { continue }
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
                        $unitHead = ($unitNorm -split ' ')[0]
                        if (-not ($script:CVG_MEASURESET.ContainsKey($unitNorm) -or $script:CVG_MEASURESET.ContainsKey($unitHead))) {
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
                    #  SHOW THE CANDIDATE, NOT THE RAW MATCH. The raw match for
                    #  "10 June 2026" is "10 June" - the year is picked up after
                    #  it - and a work order naming "10 June" sends a reader
                    #  hunting for something the guide never wrote. $shown itself
                    #  stays the raw match above, because the ordinal rule reads
                    #  its suffix.
                    Shown = $(if ($h.Class -eq 'named') { $phrase } else { ("{0} {1}" -f $h.Num, $h.Unit).Trim() })
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
                Anchors = (New-Object System.Collections.Generic.List[object])
                Disposition = ''; MatchedBy = ''; SourceFile = ''; SourceLine = 0; SourceHow = ''
                DerivedFrom = @(); WhyNot = [ordered]@{}
            }
        }
        $e = $cand[$o.Key]
        $e.Occurrences = $e.Occurrences + 1
        if ($e.Anchors.Count -lt 6) {
            $e.Anchors.Add([pscustomobject]@{ File = $o.File; Path = $o.Path; Channel = $o.Channel; Slot = $o.Slot; Sentence = $o.Sentence })
        }
    }

    # -- 7. disposition 1, MATCHED -------------------------------------------
    foreach ($k in @($cand.Keys)) {
        $e = $cand[$k]
        foreach ($r in $regArr) {
            if (-not $r.Norm) { continue }
            $ok = $false
            if ($r.Norm.IndexOf(' ' + $k + ' ', [System.StringComparison]::Ordinal) -ge 0 -or
                $r.Norm.StartsWith($k + ' ', [System.StringComparison]::Ordinal) -or
                $r.Norm -eq $k) { $ok = $true }
            if (-not $ok) { if ([regex]::IsMatch($r.Norm, (ConvertTo-CoverageVariantRegex -Literal $k))) { $ok = $true } }
            if ($ok) { $e.Disposition = 'MATCHED'; $e.MatchedBy = $r.Name; break }
        }
        if (-not $e.Disposition) { $e.WhyNot['matched'] = 'no registry entry in figures.json carries this value, or a digit/word variant of it, in its name, its require list or its source locator' }
    }

    # -- 8. disposition 2, PRESENT -------------------------------------------
    foreach ($k in @($cand.Keys)) {
        $e = $cand[$k]
        if ($e.Disposition) { continue }
        $found = Find-CoverageInSources -Needle $k -Indexes $sourceArr
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
        $inputsOf[$o.Key].Add($named.ToArray())
    }
    foreach ($k in @($cand.Keys)) {
        $e = $cand[$k]
        if ($e.Disposition) { continue }
        foreach ($r in $regArr) {
            if (@($r.Inputs).Count -eq 0) { continue }
            if ($r.Norm.IndexOf(' ' + $k + ' ', [System.StringComparison]::Ordinal) -lt 0) { continue }
            if (-not $inputsOf.ContainsKey($k)) { $inputsOf[$k] = New-Object System.Collections.Generic.List[object] }
            $inputsOf[$k].Add(@($r.Inputs | ForEach-Object { ConvertTo-GateNormal $_ } | Where-Object { $_ }))
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
                $bad = New-Object System.Collections.Generic.List[string]
                foreach ($inp in @($set)) {
                    if (-not (Test-CoverageInputResolves -InputKey $inp -Table $cand -Indexes $sourceArr)) { $bad.Add($inp) }
                }
                if ($bad.Count -eq 0) { $bestBad = $bad; $bestSet = $set; break }
                if ($null -eq $bestBad -or $bad.Count -lt $bestBad.Count) { $bestBad = $bad; $bestSet = $set }
            }
            if ($null -eq $bestSet) { continue }
            if ($bestBad.Count -eq 0) {
                $e.Disposition = 'DERIVED'; $e.DerivedFrom = @($bestSet); $changed = $true
            }
            else {
                $e.DerivedFrom = @($bestSet)
                $e.WhyNot['derived'] = ("the content names this as derived from [{0}], and the named input(s) [{1}] do not themselves resolve" -f ((@($bestSet)) -join '; '), (($bestBad.ToArray()) -join '; '))
            }
        }
    } while ($changed -and $pass -lt 12)

    foreach ($k in @($cand.Keys)) {
        $e = $cand[$k]
        if ($e.Disposition) { continue }
        if (-not $e.WhyNot.Contains('derived')) {
            $e.WhyNot['derived'] = 'the content does not name any input for this value: no arithmetic frame in its sentence and no derivedFrom in the registry'
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
    foreach ($r in $supCount.Keys) {
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
            occurrences = $e.Occurrences; disposition = $e.Disposition
            matchedBy = $e.MatchedBy
            sourceFile = $e.SourceFile; sourceLine = $e.SourceLine; sourceMatch = $e.SourceHow
            derivedFrom = @($e.DerivedFrom)
            whyNot = $e.WhyNot
            anchors = @($e.Anchors.ToArray() | ForEach-Object {
                [pscustomobject]@{ file = $_.File; fieldPath = $_.Path; channel = $_.Channel; slot = $_.Slot; sentence = $_.Sentence }
            })
        })
    }

    $reportObj = [pscustomobject]@{
        gate = $GATE
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
            candidateOccurrences = $occArr.Length
            distinctCandidates = $cand.psbase.Count
            byClass = @($occArr | Group-Object Class | ForEach-Object { [pscustomobject]@{ class = $_.Name; occurrences = $_.Count } })
        }
        suppression = @($supRows.ToArray())
        dispositions = [pscustomobject]@{
            matched = $byDisp['MATCHED']; present = $byDisp['PRESENT']
            derived = $byDisp['DERIVED']; undispositioned = $byDisp['UNDISPOSITIONED']
        }
        workOrder = @($undis | ForEach-Object {
            [pscustomobject]@{
                candidate = $_.Key; shown = $_.Shown; class = $_.Class; occurrences = $_.Occurrences
                whyNot = $_.WhyNot
                located = @($_.Anchors.ToArray() | ForEach-Object {
                    [pscustomobject]@{ file = $_.File; fieldPath = $_.Path; channel = $_.Channel; slot = $_.Slot; sentence = $_.Sentence }
                })
            }
        })
        candidates = @($candRows.ToArray())
        verdict = $(if ($undis.Count -eq 0) { 'PASS' } else { 'FAIL' })
    }

    if (-not $OutReport) { $OutReport = Join-Path $Dir 'figure-coverage-report.json' }
    [System.IO.File]::WriteAllText($OutReport, ($reportObj | ConvertTo-Json -Depth 9), (New-Object System.Text.UTF8Encoding($true)))

    if ($say) {
        Write-Host ''
        Write-Host 'UNREGISTERED FIGURE SWEEP' -ForegroundColor Cyan
        Write-Host ("  spine: {0} file(s), {1} cell(s); rendered arm: {2}" -f $spineFiles.Count, $spineCellCount, $(if ($renderedFiles.Count -gt 0) { "$($renderedFiles.Count) extract(s)" } else { 'NOT RUN - no -DocText (expected at 3c, required at 7c)' })) -ForegroundColor $(if ($renderedFiles.Count -gt 0) { 'DarkGray' } else { 'Yellow' })
        Write-GateCheckSet -What 'registry entries' -Count $regArr.Length -DerivedFrom 'figures.json, the registry this gate INVERTS - it is the answer set, never the question set'
        Write-GateCheckSet -What 'canonical sources' -Count $sourceArr.Length -DerivedFrom ("the corpus at {0} (classified from the {1}) plus the unit extract" -f (Split-Path $corpusResolved -Leaf), $corpusDocs.ClassifiedFrom)
        Write-GateCheckSet -What 'identifier tokens' -Count (Get-CoverageDistinctCount -Table $identSet) -DerivedFrom 'contract.json fields naming an ABN, ACN, CRICOS, RTO, provider or unit code, whose value also has an identifier shape - never typed into this gate'
        if ($identNames.Count -gt 0) { Write-Host ("    identifiers: {0}" -f ($identNames -join '; ')) -ForegroundColor DarkGray }
        Write-GateCheckSet -What 'candidate claims' -Count $cand.psbase.Count -DerivedFrom ("{0} occurrence(s) harvested from every text channel of the spine" -f $occArr.Length)
        if (-not $unitLoaded) {
            Write-Host '  ! unit extract NOT LOADED - unit wording cannot source a figure. Every hit below is suspect' -ForegroundColor Yellow
            Write-Host '    until unit_extract.md is beside the build or passed as -ExcludeText.' -ForegroundColor Yellow
        }
        Write-Host ''
        Write-Host '  suppression - structural only, every rule named, with what it removed:' -ForegroundColor DarkGray
        foreach ($r in $supRows) {
            $ex = ''
            if (@($r.examples).Count -gt 0) { $ex = '  e.g. ' + (($r.examples | ForEach-Object { "'$_'" }) -join ', ') }
            Write-Host ("    {0,-14} {1,7} occurrence(s), {2,5} distinct{3}" -f $r.rule, $r.occurrencesRemoved, $r.distinctRemoved, $ex) -ForegroundColor DarkGray
        }
        Write-Host ''
        Write-Host ("  dispositions: MATCHED {0}   PRESENT {1}   DERIVED {2}   UNDISPOSITIONED {3}" -f `
            $byDisp['MATCHED'], $byDisp['PRESENT'], $byDisp['DERIVED'], $byDisp['UNDISPOSITIONED']) -ForegroundColor DarkGray
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
    param([Parameter(Mandatory)][string] $Root, [Parameter(Mandatory)][hashtable] $Sub)

    $null = New-Item -ItemType Directory -Path $Root -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $Root 'spine') -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $Root 'cleanroom\pack') -Force
    $enc = New-Object System.Text.UTF8Encoding($true)

    $pack = @(
        'ACI Culinary fixture pack - learner workbook extract.',
        'Task 3(a) Standard recipe card 5501 yields 8 portions of 250 Gms.',
        'Task 5(b) Cool the sauce to 21 degrees C or below within 2 hours.',
        'Task 6(c) Hold the hot bain marie at 60 degrees C for service.',
        'Task 7(d) The chest freezer runs at minus 18 degrees C.',
        'Task 8(e) Each carton holds 12 packs and each pack holds 4 serves.',
        'Task 9(f) The trial run used a factor of 9 on the card quantity.'
    ) -join "`r`n"
    [System.IO.File]::WriteAllText((Join-Path $Root 'cleanroom\pack\Fixture_Workbook.txt'), $pack, $enc)
    $ag = @(
        'Fixture assessor guide extract.',
        'Assessor benchmark: the answer states 21 degrees C or below within 2 hours.'
    ) -join "`r`n"
    [System.IO.File]::WriteAllText((Join-Path $Root 'cleanroom\pack\Assessor_Guide_Fixture.txt'), $ag, $enc)
    [System.IO.File]::WriteAllText((Join-Path $Root 'unit_extract.md'), "# Fixture unit extract`r`nPerformance evidence for the fixture unit.`r`n", $enc)

    $reg = @{
        figures = @(
            @{ name = 'Cooling stage 1 - house standard'; authority = 'V'
               source = 'Fixture workbook Task 5(b)'
               require = @('21 degrees C or below within 2 hours') },
            @{ name = 'Hot holding temperature'; authority = 'L'
               source = 'Fixture workbook Task 6(c)'
               require = @('60 degrees C') }
        )
    }
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
        param([string] $Dir)
        $rep = Join-Path $Dir 'figure-coverage-report.json'
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath -BuildDir $Dir -ReportPath $rep -Quiet | Out-Null
        $code = $LASTEXITCODE
        $obj = $null
        if (Test-Path -LiteralPath $rep) { $obj = Get-GateJson -Path $rep }
        return [pscustomobject]@{ Exit = $code; Report = $obj }
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
    }
    finally {
        if ((Test-Path -LiteralPath $root) -and $root.Length -gt 20) {
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host ''
    if ($failures -eq 0) { Write-Host '  SELF-TEST PASS - the gate fails on every planted defect and passes a clean fixture' -ForegroundColor Green; exit 0 }
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

$rc = Invoke-CoverageGate -Dir $BuildDir -Spine $SpineDir -Corpus $CorpusDir -Rules $RulesPath `
        -Shared $ExcludeText -Rendered $DocText -OutReport $ReportPath -ShowMax $MaxWorkOrder -Silent:$Quiet
exit $rc
