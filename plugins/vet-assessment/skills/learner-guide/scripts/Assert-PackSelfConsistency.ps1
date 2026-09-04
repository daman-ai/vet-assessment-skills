<#
    Assert-PackSelfConsistency.ps1 - the hazards that live INSIDE the
    assessment pack, raised and dispositioned rather than silently inherited.

    Implements the Stage 1 gate gates.md section 20 calls
    Assert-PackSelfConsistency. Runs before authoring opens. Blocks.

        .\Assert-PackSelfConsistency.ps1 -BuildDir $out

    THE STANDING RULE THIS ENFORCES. The pack is upstream and the pack wins:
    where the guide and the pack disagree on a figure, a term, a count or a
    threshold, the guide changes. But the pack is not infallible, and where the
    pack looks wrong the guide SAYS SO IN ITS REPORT rather than teaching
    around it. A guide that quietly supplies the data a question is missing
    makes an unanswerable question look answerable, and the defect survives
    into the next validation. This gate is what makes "say so" mechanical:

      IT DOES NOT BLOCK ON THE PACK. The build cannot fix the pack and must
      never try. Nothing here edits a pack document or a corpus extract.

      IT BLOCKS ON THE HAZARD BEING DISPOSITIONED. Every hazard it raises is
      written into pack-hazards.json, which it re-reads on the next run. A
      hazard with no written handling decision FAILS the gate. So a known pack
      defect has to be consciously accepted and reported to the RTO; it cannot
      be absorbed by nobody noticing. That distinction is the whole design -
      it is what stops the gate becoming noise nobody reads.

    THE FAILURE IT EXISTS TO CATCH. Nine upstream pack defects were found
    across three audit rounds of one build, every one of them mechanically
    detectable before a word of the guide was written. One is decisive: an
    unexplained gap between a recipe card's finished weight and its own
    instruction, named in that audit as the gap the guide tried to fill by
    INVENTING A FIGURE. This is the one gate in the set where earlier
    detection prevents a downstream defect rather than finding it sooner.

    THE ARMS, AND WHY EACH IS SCOPED THE WAY IT IS.

      question-text     the same item and part carrying two different texts in
                        two documents of one family (a tool and its assessor
                        guide). Compared on normalised token overlap, so a
                        re-typed stem that changed a word is caught and a
                        different line break is not.
      missing-item      an item or part in one document of a family and absent
                        from the other, which should carry it.
      mapping           the same item mapped to different knowledge points in
                        two documents of a family, or against the contract's
                        own map where the contract carries one.
      numeral           the same sentence, with its numbers masked out, given
                        different values in two documents of a family. The key
                        is the whole masked sentence, not a window of words
                        around a number: two documents that copy a stem and
                        differ on one figure is precisely the defect, and a
                        looser key turns two rows of one table into a finding.
      count-vs-grid     a stated count in a question's own stem ("name three")
                        against the number of rows in the response grid the
                        pack built for that same question. Asymmetric: a
                        question asking for MORE than its grid holds always
                        fires, a grid one row longer than its question never
                        does - that row is a worked example, and on a real pack
                        the single instance of it was a log whose own stem said
                        so.
      arithmetic        a line that states components and their total, where
                        the components do not sum to the total.

    WHY THE NUMERAL ARM IS CROSS-DOCUMENT BY DEFAULT. Run within a document as
    well, it reports every two-row standard ("21 degrees by 2 hours" beside
    "4 degrees by 4 hours") and every recipe card that cooks for a different
    time from the one before it. On a clean pack that was six candidates, none
    of them defects. A gate that reports six non-defects on a clean pack is a
    gate people learn to route around, so the within-document arm is available
    under -IncludeWithinDocument and is NOT run by default; the output says so
    rather than leaving a reader to assume it ran.

    WHAT THIS GATE CANNOT SEE, STATED SO NOBODY ASSUMES OTHERWISE. A figure
    contradicted in DIFFERENT WORDS - a card's stated yield against its own
    method, the recipe-weight gap above - is not caught by any arm here.
    Detecting it needs a reader who knows what the number is for. Stage 1's
    reading of the pack and Stage 6's audit still own that; this gate clears
    the mechanical hazards off their desks so their attention goes to the ones
    only a reader can find.

    WHAT IT REFUSES TO PRINT. Never a model answer and never a benchmark row.
    Where a hazard has a location in a learner-facing document, the SHORTEST
    span that shows the disagreement is quoted from that side. Where every
    location is in an assessor-only document, nothing is quoted at all: the
    hazard is cited by document, item and line, the disagreement is described
    structurally, and the differing values are withheld - because a benchmark
    threshold is an answer, and pack-hazards.json is read by content agents who
    must never see one. The withheld flag is carried in the file so a reader
    knows a value was held back rather than absent.

    NOTHING IS HAND-LISTED. The documents and their audience come from
    Lib-GateCommon's shared corpus locator and classifier, so this gate reads
    the same extraction every later gate reads. The item label words are
    derived from the contract's referenceConvention; the response grids and
    their row counts from the pack's own typed grids file; the knowledge-point
    map from the contract. Every set's size and source is printed.

    TRUSTED ONLY AFTER FAILING ON A PLANTED DEFECT. -SelfTest builds a fixture
    corpus in a temp directory - it never touches a real build - and plants, one
    at a time: a figure stated two ways in two documents, a question number
    carrying two different texts, a task missing from the assessor guide, a
    mapping divergence, and a count that disagrees with its own grid. It then
    proves the disposition mechanism both ways: the undispositioned hazard
    FAILS, a hazard with an empty note still FAILS, and the same hazard with a
    written decision PASSES. EVERY PLANT IS READ BACK AND VERIFIED TO HAVE
    LANDED before the gate is run against it.

    PS 5.1. ASCII only in this file. Nothing here names a unit, a brand, an RTO
    or a build path.

    Exit 0 no hazard, or every hazard dispositioned; 1 at least one hazard has
    no written disposition; 2 a usage error; 4 the self-test failed.
#>

[CmdletBinding()]
param(
    #  The build directory. The corpus, the contract and the hazard file are
    #  found under it.
    [string] $BuildDir,
    #  Override the canonical corpus directory. Resolved by Lib-GateCommon
    #  otherwise, so this gate reads the extraction every later gate reads.
    [string] $CorpusDir,
    #  The dispositions. Written on the first run, re-read on every run after.
    [string] $HazardPath,
    #  The pack's typed response grids. Default: grids.json in the corpus.
    [string] $GridsPath,
    #  How the pack labels an assessed item. Derived from the contract's
    #  referenceConvention otherwise, then the documented default set.
    [string[]] $ItemLabel,
    #  Token overlap at or above which two stems are the same question.
    [double] $StemOverlap,
    #  Also run the numeral arm within a single document. Off by default; the
    #  header says why, at length.
    [switch] $IncludeWithinDocument,
    [string] $ResultPath,
    [switch] $SelfTest,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

$GATE = 'Assert-PackSelfConsistency'
$script:Self = $PSCommandPath

$DEFAULT_ITEM_LABEL  = @('Task', 'Question', 'Item', 'Activity', 'Observation')
$DEFAULT_STEM_OVERLAP = 0.85
$MIN_MASK_WORDS      = 8      # a masked sentence shorter than this is not a claim
$MIN_NOTE_CHARS      = 20     # a disposition note shorter than this is not a decision
$STEM_MAX_LINES      = 6      # how far a stem runs past its opening line

$UNIT_RX = '(?:degrees\s*c(?:elsius)?|minutes?|hours?|days?|weeks?|months?|gms|grams?|kgs?|kilograms?|mls?|millilitres?|litres?|portions?|serves?|percent)'
$NUM_RX  = '(?<![\w.])(\d+(?:\.\d+)?)\s*(' + $UNIT_RX + ')\b'

$NUMBER_WORD = @{ 'one' = 1; 'two' = 2; 'three' = 3; 'four' = 4; 'five' = 5; 'six' = 6; 'seven' = 7; 'eight' = 8; 'nine' = 9; 'ten' = 10 }

function Fail-Usage {
    param([string] $Message)
    Write-Host ("  X {0}: {1}" -f $GATE, $Message) -ForegroundColor Red
    exit 2
}

# ---------------------------------------------------------------------------
# Private helpers. Nothing else in the gate set parses the pack's own question
# structure; the shared library locates and classifies the corpus and this gate
# does the reading.
# ---------------------------------------------------------------------------

function Get-Sha10 {
    param([string] $Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $b = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(("$Text")))
        return ((([BitConverter]::ToString($b)) -replace '-', '').ToLowerInvariant()).Substring(0, 10)
    }
    finally { $sha.Dispose() }
}

function Get-UnitClass {
    <# One name per measure, so "hour" and "hours" are the same unit. #>
    param([string] $Unit)
    $u = ("$Unit").ToLowerInvariant().Trim() -replace '\s+', ' '
    if ($u -match '^degrees') { return 'degrees c' }
    if ($u -match '^(gms|gram)') { return 'grams' }
    if ($u -match '^(kg|kilogram)') { return 'kilograms' }
    if ($u -match '^(ml|millilitre)') { return 'millilitres' }
    if ($u -match '^litre') { return 'litres' }
    if ($u -match '^minute') { return 'minutes' }
    if ($u -match '^hour') { return 'hours' }
    if ($u -match '^day') { return 'days' }
    if ($u -match '^week') { return 'weeks' }
    if ($u -match '^month') { return 'months' }
    if ($u -match '^(portion|serve)') { return 'portions' }
    return $u
}

function Get-ShortSpan {
    <#  The shortest span that shows the disagreement: a window of words around
        the first place two normalised stems part company. Quoting the whole
        question would put more of the pack in the log than the hazard needs,
        and a hazard report is not a place to reproduce an instrument.  #>
    param([string] $Mine, [string] $Theirs, [int] $Window = 10, [int] $Cap = 160)
    $a = @(("$Mine") -split ' ' | Where-Object { $_ })
    $b = @(("$Theirs") -split ' ' | Where-Object { $_ })
    $i = 0
    while ($i -lt $a.Count -and $i -lt $b.Count -and $a[$i] -eq $b[$i]) { $i++ }
    $start = [Math]::Max(0, $i - 2)
    $take = [Math]::Min($Window, $a.Count - $start)
    if ($take -le 0) { $take = [Math]::Min($Window, $a.Count) ; $start = 0 }
    $s = (@($a[$start..($start + $take - 1)]) -join ' ')
    if ($s.Length -gt $Cap) { $s = $s.Substring(0, $Cap - 3) + '...' }
    $lead = ''
    if ($start -gt 0) { $lead = '...' }
    $trail = ''
    if (($start + $take) -lt $a.Count) { $trail = '...' }
    return ($lead + $s + $trail)
}

function New-Location {
    <#  A hazard location. Quotes only from a learner-facing document; an
        assessor-only one is cited and never echoed.  #>
    param([string] $Doc, [string] $Audience, [string] $Ref, [int] $Line, [string] $Quote)
    $l = [ordered]@{ doc = $Doc; audience = $Audience; ref = $Ref; line = [int]$Line }
    if ($Audience -eq 'assessor' -or -not $Quote) {
        $l['quote'] = ''
        $l['cited'] = $true
    }
    else {
        $l['quote'] = $Quote
        $l['cited'] = $false
    }
    return [pscustomobject]$l
}

function New-Hazard {
    param(
        [string] $Type,
        [string] $Key,
        [string] $Summary,
        $Locations,
        [bool] $ValuesWithheld = $false
    )
    $locArr = @($Locations)
    $idSeed = ($Type + '|' + $Key + '|' + ((@($locArr | ForEach-Object { $_.doc + '#' + $_.ref }) | Sort-Object) -join ','))
    return [pscustomobject]@{
        id             = ('PH-' + (Get-Sha10 $idSeed))
        type           = $Type
        key            = $Key
        summary        = $Summary
        locations      = $locArr
        valuesWithheld = $ValuesWithheld
    }
}

function Get-TextLines {
    param([string] $Text)
    $out = New-Object System.Collections.Generic.List[string]
    if ($null -eq $Text) { return $out.ToArray() }
    foreach ($ln in (("$Text").TrimStart([char]0xFEFF) -split "`r?`n")) { $out.Add($ln.Trim()) }
    return $out.ToArray()
}

function Read-PackDocument {
    <#  The pack document's own question structure: items, their parts, the
        stem of each part, and any knowledge-point mapping stated in the block.

        AN ITEM COUNTS ONLY WHERE IT HAS PARTS OR A RESPONSE MARKER. A table of
        contents, a task summary and a mapping matrix all repeat every item
        heading, and treating those as three statements of one question would
        report every pack as self-contradictory on its first run.  #>
    param(
        [Parameter(Mandatory)] $Doc,
        [Parameter(Mandatory)][string] $ItemRx,
        [Parameter(Mandatory)][string] $PartRx,
        [Parameter(Mandatory)][string] $ResponseRx
    )

    $lines = Get-TextLines -Text $Doc.Text
    $seen = @{}
    $cur = $null
    $acc = $null
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $ln = $lines[$i]
        if ($ln -match $ItemRx) {
            #  The label is captured from the heading, never taken from the
            #  derived set: a hazard that says "Activity 3" where the document
            #  says "Task 3" sends its reader to the wrong page.
            $lbl = $Matches[1]
            $n = [int]$Matches[2]
            $cur = [pscustomobject]@{
                Number  = $n
                Label   = $lbl
                Line    = $i + 1
                Heading = $ln
                Parts   = (New-Object System.Collections.Specialized.OrderedDictionary)
                Ke      = (New-Object System.Collections.Generic.List[string])
            }
            if (-not $seen.ContainsKey($n)) { $seen[$n] = New-Object System.Collections.Generic.List[object] }
            $seen[$n].Add($cur)
            $acc = $null
            continue
        }
        if ($null -eq $cur) { continue }
        #  A mapping is stated in the PREAMBLE - between the item's heading and
        #  its first part - and nowhere else. Read past that and the last item
        #  in a document swallows the knowledge-evidence matrix that follows it,
        #  which on a real pack reported that one task assessed all eleven
        #  points. The block has no closing marker; the first part is it.
        if ($cur.Parts.Count -eq 0) {
            if ($ln -match '(?i)^\s*KE\s*(\d+)\b') { $cur.Ke.Add('KE' + $Matches[1]) }
            elseif ($ln -match '(?i)\bknowledge evidence\s+(\d+)\b') { $cur.Ke.Add('KE' + $Matches[1]) }
        }
        if ($ln -match $PartRx) {
            $p = $Matches[1].ToLowerInvariant()
            $acc = New-Object System.Collections.Generic.List[string]
            $acc.Add($Matches[2])
            $cur.Parts[$p] = [pscustomobject]@{ Part = $p; Line = $i + 1; Acc = $acc }
            continue
        }
        if ($ln -match $ResponseRx) { $acc = $null; continue }
        if ($null -ne $acc -and $ln) { if ($acc.Count -lt $STEM_MAX_LINES) { $acc.Add($ln) } }
    }

    #  One block per item number: the one that carries the most parts, which is
    #  the body of the question rather than its index entry.
    $items = New-Object System.Collections.Specialized.OrderedDictionary
    foreach ($n in (@($seen.Keys) | Sort-Object)) {
        $best = $null
        foreach ($b in $seen[$n]) {
            if ($b.Parts.Count -eq 0) { continue }
            if ($null -eq $best -or $b.Parts.Count -gt $best.Parts.Count) { $best = $b }
        }
        if ($null -ne $best) { $items[[string]$n] = $best }
    }
    return [pscustomobject]@{
        Name       = $Doc.Name
        Audience   = $Doc.Audience
        Lines      = $lines
        Items      = $items
        HeadingsSeen = $seen.Count
    }
}

function Get-StemText {
    param($Part)
    return (($Part.Acc.ToArray()) -join ' ')
}

function Write-Result {
    param([string] $Path, [System.Collections.IDictionary] $Body)
    if (-not $Path) { return }
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $json = [pscustomobject]$Body | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($true)))
}

# ---------------------------------------------------------------------------
# SELF-TEST - a fixture corpus, verified plants, and the disposition mechanism
# proved in BOTH directions
# ---------------------------------------------------------------------------

if ($SelfTest) {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('packhaz_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $fxBuild = Join-Path $tmp 'build'
    $fxCorpus = Join-Path $fxBuild 'corpus'
    $cases = New-Object System.Collections.Generic.List[object]

    function Record {
        param([string] $Name, [bool] $Ok, [string] $Detail)
        $cases.Add([pscustomobject]@{ name = $Name; ok = $Ok; detail = $Detail })
        if (-not $Quiet) {
            if ($Ok) { Write-Host ('  PASS  {0}: {1}' -f $Name, $Detail) -ForegroundColor Green }
            else     { Write-Host ('  FAIL  {0}: {1}' -f $Name, $Detail) -ForegroundColor Red }
        }
    }
    function Invoke-Child {
        param([hashtable] $Params)
        $r = Join-Path $tmp ('result_' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.json')
        $global:LASTEXITCODE = 0
        & $script:Self @Params -ResultPath $r -Quiet | Out-Null
        $code = $LASTEXITCODE
        $body = $null
        if (Test-Path -LiteralPath $r) { $body = Get-GateJson -Path $r }
        return [pscustomobject]@{ Code = $code; Result = $body }
    }
    function Get-HazardsOfType {
        param($Res, [string] $Type)
        if ($null -eq $Res) { return @() }
        return @(@(Get-GateProp -Object $Res -Names @('hazards') -Default @()) | Where-Object { $null -ne $_ -and $_.type -eq $Type })
    }

    #  The fixture body. One learner tool, its assessor guide, and a grids file
    #  the count arm can read. Written by a function so every case starts from
    #  exactly the same bytes and a plant left behind by an earlier case cannot
    #  make a later green mean nothing.
    function Get-FixtureBody {
        param([string] $Flavour)
        $l = New-Object System.Collections.Generic.List[string]
        $l.Add('ASSESSMENT COVER SHEET')
        $l.Add('This fixture tool exists only to prove that this gate can fail.')
        $l.Add('')
        $l.Add('Task 1 - Receiving and storing bulk stock')
        $l.Add('Maps to')
        if ($Flavour -eq 'mapping') { $l.Add('KE4') } else { $l.Add('KE1') }
        $l.Add('Scenario')
        $l.Add('The chilled store must hold stock at 4 degrees c or below at all times of the day.')
        $l.Add('(a)  Name three checks you make on a delivery before you accept it into the chilled store.')
        $l.Add('Student response - (a)')
        $l.Add('Write your response to (a) here')
        $l.Add('(b)  Explain why the oldest stock is used first in a bulk production kitchen.')
        $l.Add('Student response - (b)')
        $l.Add('Write your response to (b) here')
        $l.Add('')
        $l.Add('Task 2 - Cooling cooked bulk food')
        $l.Add('Maps to')
        $l.Add('KE2')
        $l.Add('Scenario')
        if ($Flavour -eq 'numeral') {
            $l.Add('Cooked food must be brought down to 25 degrees c within 2 hours of coming off the heat.')
        }
        else {
            $l.Add('Cooked food must be brought down to 21 degrees c within 2 hours of coming off the heat.')
        }
        $l.Add('Prep 30 minutes cook 30 minutes cooling 60 minutes total 120 minutes')
        if ($Flavour -eq 'stem') {
            $l.Add('(a)  Describe the equipment you would choose to bring the food down and say why you chose it.')
        }
        else {
            $l.Add('(a)  Explain how you record the cooling of a bulk batch from the moment it comes off the heat.')
        }
        $l.Add('Student response - (a)')
        $l.Add('Write your response to (a) here')
        $l.Add('')
        if ($Flavour -ne 'missing') {
            $l.Add('Task 3 - Packaging and labelling for the freezer')
            $l.Add('Maps to')
            $l.Add('KE3')
            $l.Add('Scenario')
            $l.Add('Every pack leaving the production kitchen carries a label a store person can read.')
            $l.Add('(a)  Explain what a rotation label must carry before a pack goes into the freezer.')
            $l.Add('Student response - (a)')
            $l.Add('Write your response to (a) here')
            $l.Add('')
        }
        $l.Add('End of this fixture tool.')
        return $l.ToArray()
    }
    function Write-Fixture {
        param([string] $LearnerFlavour = 'clean', [string] $AssessorFlavour = 'clean', [int] $GridRows = 3)
        if (Test-Path -LiteralPath $fxCorpus) { Remove-Item -LiteralPath $fxCorpus -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $fxCorpus | Out-Null
        $enc = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllText((Join-Path $fxCorpus 'Alpha_Tool.txt'), (((Get-FixtureBody -Flavour $LearnerFlavour) -join "`r`n") + "`r`n"), $enc)
        [System.IO.File]::WriteAllText((Join-Path $fxCorpus 'Assessor_Guide_Alpha_Tool.txt'), (((Get-FixtureBody -Flavour $AssessorFlavour) -join "`r`n") + "`r`n"), $enc)
        $labels = @()
        for ($i = 1; $i -le $GridRows; $i++) { $labels += ('Delivery check row {0}' -f $i) }
        $grids = [ordered]@{
            _purpose = 'fixture response grids'
            grids = @(
                [ordered]@{ doc = 'Alpha_Tool'; ref = 'Alpha Task 1(a)'; labels = $labels; headers = @('What you check', 'Why') }
            )
        }
        [System.IO.File]::WriteAllText((Join-Path $fxCorpus 'grids.json'), (([pscustomobject]$grids | ConvertTo-Json -Depth 8)), $enc)
        if (Test-Path -LiteralPath (Join-Path $fxBuild 'pack-hazards.json')) { Remove-Item -LiteralPath (Join-Path $fxBuild 'pack-hazards.json') -Force }
    }
    function Test-PlantLanded {
        param([string] $Needle, [string] $File, [bool] $Expect = $true)
        $t = Get-GateFileText -Path (Join-Path $fxCorpus $File)
        $has = $t.Contains($Needle)
        return ($has -eq $Expect)
    }

    try {
        New-Item -ItemType Directory -Force -Path $fxCorpus | Out-Null
        $base = @{ BuildDir = $fxBuild }
        $hazFile = Join-Path $fxBuild 'pack-hazards.json'

        if (-not $Quiet) {
            Write-Host ''
            Write-Host ('{0} SELF-TEST on a fixture corpus built from nothing' -f $GATE) -ForegroundColor Cyan
            Write-Host ('  fixture: {0}' -f $tmp) -ForegroundColor DarkGray
            Write-Host ''
        }

        # (a) control - a self-consistent family raises nothing
        Write-Fixture
        $ok = (Test-PlantLanded -Needle '21 degrees c within 2 hours' -File 'Alpha_Tool.txt') -and
              (Test-PlantLanded -Needle '21 degrees c within 2 hours' -File 'Assessor_Guide_Alpha_Tool.txt')
        if (-not $ok) { Record 'control' $false 'the fixture did not build: the two documents do not agree to start with' }
        else {
            $c = Invoke-Child $base
            $n = @(Get-GateProp -Object $c.Result -Names @('hazards') -Default @()).Count
            Record 'control' (($c.Code -eq 0) -and ($n -eq 0)) ('a self-consistent family; exit {0}, {1} hazard(s)' -f $c.Code, $n)
        }

        # (b) a figure stated two ways in two documents
        Write-Fixture -AssessorFlavour 'numeral'
        $landed = (Test-PlantLanded -Needle '21 degrees c within 2 hours' -File 'Alpha_Tool.txt') -and
                  (Test-PlantLanded -Needle '25 degrees c within 2 hours' -File 'Assessor_Guide_Alpha_Tool.txt') -and
                  (Test-PlantLanded -Needle '21 degrees c within 2 hours' -File 'Assessor_Guide_Alpha_Tool.txt' -Expect $false)
        if (-not $landed) { Record 'figure stated two ways' $false 'the plant did not land: the two documents still carry the same figure' }
        else {
            $c = Invoke-Child $base
            $h = @(Get-HazardsOfType -Res $c.Result -Type 'numeral')
            Record 'figure stated two ways' (($c.Code -eq 1) -and ($h.Count -ge 1)) ('learner says one value, assessor guide another; exit {0}; {1}' -f $c.Code, $(if ($h.Count) { $h[0].summary } else { 'NO numeral hazard raised' }))

            # (c) the same hazard, disposition present but empty - still fails
            $hz = Get-GateJson -Path $hazFile
            if ($null -eq $hz) { Record 'empty note still fails' $false 'no pack-hazards.json was written, so there is nothing to dispose' }
            else {
                foreach ($e in @($hz.hazards)) { $e.disposition.decision = 'accept'; $e.disposition.note = '   ' }
                [System.IO.File]::WriteAllText($hazFile, ($hz | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($true)))
                $back = Get-GateJson -Path $hazFile
                $blank = @(@($back.hazards) | Where-Object { -not ("$($_.disposition.note)").Trim() })
                if ($blank.Count -eq 0) { Record 'empty note still fails' $false 'the plant did not land: the note is not blank in the file' }
                else {
                    $c2 = Invoke-Child $base
                    Record 'empty note still fails' ($c2.Code -eq 1) ('{0} hazard(s) carry a decision and a blank note; exit {1}' -f $blank.Count, $c2.Code)
                }

                # (d) the same hazard, properly dispositioned - passes
                $hz2 = Get-GateJson -Path $hazFile
                foreach ($e in @($hz2.hazards)) {
                    $e.disposition.decision = 'accept-and-report'
                    $e.disposition.note = 'Accepted as a pack defect. The guide teaches the learner-facing value and the compliance report raises the divergence with the RTO. The pack is not edited by this build.'
                    $e.disposition.by = 'self-test'
                    $e.disposition.on = (Get-Date).ToUniversalTime().ToString('o')
                }
                [System.IO.File]::WriteAllText($hazFile, ($hz2 | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($true)))
                $back2 = Get-GateJson -Path $hazFile
                $good = @(@($back2.hazards) | Where-Object { ("$($_.disposition.note)").Trim().Length -ge $MIN_NOTE_CHARS })
                if ($good.Count -eq 0) { Record 'dispositioned hazard passes' $false 'the plant did not land: no hazard carries a written note' }
                else {
                    $c3 = Invoke-Child $base
                    Record 'dispositioned hazard passes' ($c3.Code -eq 0) ('{0} hazard(s) carry a written decision; exit {1}' -f $good.Count, $c3.Code)
                }
            }
        }

        # (e) the same question number carrying two different texts
        Write-Fixture -AssessorFlavour 'stem'
        $landed = (Test-PlantLanded -Needle 'Explain how you record the cooling' -File 'Alpha_Tool.txt') -and
                  (Test-PlantLanded -Needle 'Describe the equipment you would choose' -File 'Assessor_Guide_Alpha_Tool.txt')
        if (-not $landed) { Record 'two texts for one question' $false 'the plant did not land: the stems are unchanged' }
        else {
            $c = Invoke-Child $base
            $h = @(Get-HazardsOfType -Res $c.Result -Type 'question-text')
            Record 'two texts for one question' (($c.Code -eq 1) -and ($h.Count -ge 1)) ('Task 2(a) reads differently in the two documents; exit {0}; {1}' -f $c.Code, $(if ($h.Count) { $h[0].summary } else { 'NO question-text hazard raised' }))
        }

        # (f) an item present in one document of the family and absent from the other
        Write-Fixture -AssessorFlavour 'missing'
        $landed = (Test-PlantLanded -Needle 'Task 3 - Packaging and labelling' -File 'Alpha_Tool.txt') -and
                  (Test-PlantLanded -Needle 'Task 3 - Packaging and labelling' -File 'Assessor_Guide_Alpha_Tool.txt' -Expect $false)
        if (-not $landed) { Record 'item missing from the guide' $false 'the plant did not land: Task 3 is still in both documents' }
        else {
            $c = Invoke-Child $base
            $h = @(Get-HazardsOfType -Res $c.Result -Type 'missing-item')
            Record 'item missing from the guide' (($c.Code -eq 1) -and ($h.Count -ge 1)) ('Task 3 is in the tool and not in its guide; exit {0}; {1}' -f $c.Code, $(if ($h.Count) { $h[0].summary } else { 'NO missing-item hazard raised' }))
        }

        # (g) a mapping divergence
        Write-Fixture -AssessorFlavour 'mapping'
        $landed = (Test-PlantLanded -Needle 'KE4' -File 'Assessor_Guide_Alpha_Tool.txt') -and
                  (Test-PlantLanded -Needle 'KE4' -File 'Alpha_Tool.txt' -Expect $false)
        if (-not $landed) { Record 'mapping divergence' $false 'the plant did not land: both documents still map Task 1 the same way' }
        else {
            $c = Invoke-Child $base
            $h = @(Get-HazardsOfType -Res $c.Result -Type 'mapping')
            Record 'mapping divergence' (($c.Code -eq 1) -and ($h.Count -ge 1)) ('Task 1 maps to different knowledge points; exit {0}; {1}' -f $c.Code, $(if ($h.Count) { $h[0].summary } else { 'NO mapping hazard raised' }))
        }

        # (h) a stated count against its own grid - the question asks for more
        #     than the grid can hold, which is the direction that blocks a
        #     learner and the direction this arm fires on.
        Write-Fixture -GridRows 2
        $g = Get-GateJson -Path (Join-Path $fxCorpus 'grids.json')
        $rows = @(@($g.grids)[0].labels).Count
        $stemSaysThree = Test-PlantLanded -Needle 'Name three checks' -File 'Alpha_Tool.txt'
        if (-not ($rows -eq 2 -and $stemSaysThree)) { Record 'count against its own grid' $false ('the plant did not land: grid rows {0}, stem says three = {1}' -f $rows, $stemSaysThree) }
        else {
            $c = Invoke-Child $base
            $h = @(Get-HazardsOfType -Res $c.Result -Type 'count-vs-grid')
            Record 'count against its own grid' (($c.Code -eq 1) -and ($h.Count -ge 1)) ('the stem asks for three and the pack built a grid of {0}; exit {1}; {2}' -f $rows, $c.Code, $(if ($h.Count) { $h[0].summary } else { 'NO count-vs-grid hazard raised' }))
        }

        # (i) nothing an assessor-only document says is ever echoed
        Write-Fixture -AssessorFlavour 'numeral'
        $c = Invoke-Child $base
        $leaked = @(@(Get-GateProp -Object $c.Result -Names @('hazards') -Default @()) | ForEach-Object { @($_.locations) } | Where-Object { $null -ne $_ -and $_.audience -eq 'assessor' -and ("$($_.quote)").Trim() })
        Record 'assessor text never echoed' ($leaked.Count -eq 0) ('{0} assessor-only location(s) carry a quote' -f $leaked.Count)

        # (j) the control again, after every plant
        Write-Fixture
        $c = Invoke-Child $base
        Record 'control after plants' ($c.Code -eq 0) ('the fixture restores clean; exit {0}' -f $c.Code)
    }
    finally {
        if ($tmp -and (Test-Path -LiteralPath $tmp) -and $tmp.Length -gt 12) {
            Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $bad = @($cases.ToArray() | Where-Object { -not $_.ok })
    $stCode = 0
    if ($bad.Count -gt 0) { $stCode = 4 }
    if (-not $Quiet) {
        Write-Host ''
        if ($stCode -eq 0) { Write-Host ('  self-test: {0} of {0} cases passed. This gate can fail.' -f $cases.Count) -ForegroundColor Green }
        else { Write-Host ('  X self-test: {0} of {1} cases FAILED. Do not trust a green from this gate until they pass.' -f $bad.Count, $cases.Count) -ForegroundColor Red }
    }
    $stBody = [ordered]@{}
    $stBody['gate']      = $GATE
    $stBody['mode']      = 'selftest'
    $stBody['verdict']   = $(if ($stCode -eq 0) { 'PASS' } else { 'FAIL' })
    $stBody['failures']  = @($bad | ForEach-Object { '{0}: {1}' -f $_.name, $_.detail })
    $stBody['cases']     = $cases.ToArray()
    $stBody['checkedAt'] = (Get-Date).ToUniversalTime().ToString('o')
    $stBody['exitCode']  = [int]$stCode
    Write-Result -Path $ResultPath -Body $stBody
    exit $stCode
}

# ---------------------------------------------------------------------------
# 1. The corpus, the contract, and the sets this gate derives from them
# ---------------------------------------------------------------------------

if (-not $BuildDir -and -not $CorpusDir) { Fail-Usage 'pass -BuildDir (the corpus, the contract and the hazard file are found under it), or -CorpusDir.' }
if ($BuildDir -and -not (Test-Path -LiteralPath $BuildDir)) { Fail-Usage ('build directory not found: {0}' -f $BuildDir) }

$corpusPath = $null
try { $corpusPath = Get-GateCorpusDir -BuildDir $(if ($BuildDir) { $BuildDir } else { (Split-Path -Parent $CorpusDir) }) -CorpusDir $CorpusDir }
catch { Fail-Usage $_.Exception.Message }

$contract = $null
if ($BuildDir) { $contract = Get-GateContract -BuildDir $BuildDir }

if (-not $HazardPath) {
    if (-not $BuildDir) { Fail-Usage 'pass -HazardPath, or -BuildDir so the disposition file has a home. A hazard list nothing re-reads is a list nobody has to answer.' }
    $HazardPath = Join-Path $BuildDir 'pack-hazards.json'
}
if (-not $GridsPath) { $GridsPath = Join-Path $corpusPath 'grids.json' }
if (-not $ResultPath -and $BuildDir) { $ResultPath = Join-Path $BuildDir 'pack-consistency.json' }

# --- how the pack labels an item, derived from the contract
$labelFrom = 'parameter'
$labels = New-Object System.Collections.Generic.List[string]
if ($null -ne $ItemLabel -and @($ItemLabel).Count -gt 0) {
    foreach ($x in @($ItemLabel)) { if ($x) { $labels.Add("$x") } }
}
else {
    $rc = $null
    if ($null -ne $contract) { $rc = Get-GateProp -Object $contract -Names @('referenceConvention') }
    if ($null -ne $rc) {
        foreach ($p in $rc.PSObject.Properties) {
            if ($p.Name -like '_*') { continue }
            $v = "$($p.Value)"
            if (-not $v) { continue }
            #  The word a reference form puts immediately before its number is
            #  the pack's own label for an item. Take the capitalised one, so
            #  "Observation checklist {n}" yields Observation and not checklist.
            $ix = $v.IndexOf('{n}')
            if ($ix -lt 1) { continue }
            $left = $v.Substring(0, $ix)
            $toks = @($left -split '[^A-Za-z]+' | Where-Object { $_ })
            for ($t = $toks.Count - 1; $t -ge 0 -and $t -ge $toks.Count - 3; $t--) {
                if ($toks[$t] -cmatch '^[A-Z]') { $labels.Add($toks[$t]); break }
            }
        }
        if ($labels.Count -gt 0) { $labelFrom = 'contract referenceConvention' }
    }
    if ($labels.Count -eq 0) {
        foreach ($x in $DEFAULT_ITEM_LABEL) { $labels.Add($x) }
        $labelFrom = 'skill default (the contract carries no reference convention)'
    }
}
$labelSet = @($labels.ToArray() | Sort-Object -Unique)
$itemRx = '^\s*(' + ((@($labelSet | ForEach-Object { [regex]::Escape($_) })) -join '|') + ')\s*(\d+)\b'
$partRx = '^\s*\(([a-z])\)\s*(.*)$'
$respRx = '(?i)^\s*(?:student|learner)\s+response\b'

$stemFloor = $DEFAULT_STEM_OVERLAP
$stemFrom = 'skill default'
if ($PSBoundParameters.ContainsKey('StemOverlap')) { $stemFloor = $StemOverlap; $stemFrom = 'parameter' }

# --- the documents, classified by the shared library
$corpus = Get-GateCorpusDocs -CorpusDir $corpusPath -BuildDir $BuildDir
$parsed = New-Object System.Collections.Generic.List[object]
foreach ($d in @($corpus.Documents)) {
    $parsed.Add((Read-PackDocument -Doc $d -ItemRx $itemRx -PartRx $partRx -ResponseRx $respRx))
}
if ($parsed.Count -eq 0) { Fail-Usage ('the corpus at {0} holds no documents.' -f $corpusPath) }

# --- families: a learner-facing tool and every assessor guide written over it
$families = New-Object System.Collections.Generic.List[object]
$claimed = New-Object 'System.Collections.Generic.HashSet[string]'
$learners = @($parsed.ToArray() | Where-Object { $_.Audience -eq 'learner' })
$assessors = @($parsed.ToArray() | Where-Object { $_.Audience -eq 'assessor' })
foreach ($l in $learners) {
    $ln = ConvertTo-GateNormal $l.Name
    $mem = New-Object System.Collections.Generic.List[object]
    $mem.Add($l)
    foreach ($a in $assessors) {
        if ((ConvertTo-GateNormal $a.Name).Contains($ln)) { $mem.Add($a); [void]$claimed.Add($a.Name) }
    }
    $families.Add([pscustomobject]@{ Name = $l.Name; Members = $mem.ToArray() })
}
$orphans = @($assessors | Where-Object { -not $claimed.Contains($_.Name) })

# --- the pack's typed response grids, keyed by (document, item, part)
$gridRows = @{}
$gridsFrom = 'no typed grids file - the count arm is SKIPPED'
$grids = Get-GateJson -Path $GridsPath
if ($null -ne $grids) {
    $gl = @(Get-GateProp -Object $grids -Names @('grids') -Default @())
    foreach ($g in $gl) {
        if ($null -eq $g) { continue }
        $gd = [string](Get-GateProp -Object $g -Names @('doc', 'document') -Default '')
        $gr = [string](Get-GateProp -Object $g -Names @('ref', 'id') -Default '')
        $m = [regex]::Match($gr, '(\d+)\s*\(([a-z])\)')
        if (-not $m.Success) { continue }
        $n = @(Get-GateProp -Object $g -Names @('labels', 'rows', 'items') -Default @()).Count
        if ($n -le 0) { continue }
        $gridRows[('{0}|{1}|{2}' -f (ConvertTo-GateNormal $gd), $m.Groups[1].Value, $m.Groups[2].Value.ToLowerInvariant())] = $n
    }
    $gridsFrom = ('{0} ({1} grid(s) with row counts)' -f (Split-Path $GridsPath -Leaf), $gridRows.Count)
}

# --- the contract's own knowledge-point map, where it carries one
$contractKe = @{}
$keFrom = 'the contract carries no knowledge-point map'
if ($null -ne $contract) {
    $km = Get-GateProp -Object $contract -Names @('keMap', 'knowledgeMap')
    if ($null -ne $km) {
        foreach ($p in $km.PSObject.Properties) {
            if ($p.Name -like '_*') { continue }
            $inWhat = [string](Get-GateProp -Object $p.Value -Names @('assessedIn', 'assessedAt') -Default '')
            $m = [regex]::Match($inWhat, '(\d+)')
            if ($m.Success) { $contractKe[$p.Name.ToUpperInvariant()] = $m.Groups[1].Value }
        }
        if ($contractKe.Count -gt 0) { $keFrom = ('contract keMap ({0} point(s))' -f $contractKe.Count) }
    }
}

# ---------------------------------------------------------------------------
# 2. The arms
# ---------------------------------------------------------------------------

$hazards = New-Object System.Collections.Generic.List[object]
$armLog = New-Object System.Collections.Generic.List[object]
function Add-Arm { param([string] $Name, [bool] $Ran, [string] $Detail) $armLog.Add([pscustomobject]@{ arm = $Name; ran = $Ran; detail = $Detail }) }

$multiFamilies = @($families.ToArray() | Where-Object { $_.Members.Count -gt 1 })

# --- ARM 1 and 2 and 4: question text, missing items, mapping
if ($multiFamilies.Count -eq 0) {
    Add-Arm 'question-text' $false 'no family has two documents: nothing to compare a question against'
    Add-Arm 'missing-item'  $false 'no family has two documents'
    Add-Arm 'mapping'       $false 'no family has two documents'
}
else {
    foreach ($fam in $multiFamilies) {
        $mem = @($fam.Members)
        for ($a = 0; $a -lt $mem.Count; $a++) {
            for ($b = $a + 1; $b -lt $mem.Count; $b++) {
                $dA = $mem[$a]
                $dB = $mem[$b]

                # missing items
                foreach ($n in @($dA.Items.Keys)) {
                    if (-not $dB.Items.Contains($n)) {
                        $hazards.Add((New-Hazard -Type 'missing-item' -Key ('item {0}' -f $n) `
                            -Summary ('{0} {1} is set out in {2} and does not appear in {3}, which is the same family and should carry it.' -f $dA.Items[$n].Label, $n, $dA.Name, $dB.Name) `
                            -Locations @((New-Location -Doc $dA.Name -Audience $dA.Audience -Ref ('{0} {1}' -f $dA.Items[$n].Label, $n) -Line $dA.Items[$n].Line -Quote $dA.Items[$n].Heading),
                                         (New-Location -Doc $dB.Name -Audience $dB.Audience -Ref ('{0} {1}' -f $dA.Items[$n].Label, $n) -Line 0 -Quote ''))))
                    }
                }
                foreach ($n in @($dB.Items.Keys)) {
                    if (-not $dA.Items.Contains($n)) {
                        $hazards.Add((New-Hazard -Type 'missing-item' -Key ('item {0}' -f $n) `
                            -Summary ('{0} {1} is set out in {2} and does not appear in {3}, which is the same family and should carry it.' -f $dB.Items[$n].Label, $n, $dB.Name, $dA.Name) `
                            -Locations @((New-Location -Doc $dB.Name -Audience $dB.Audience -Ref ('{0} {1}' -f $dB.Items[$n].Label, $n) -Line $dB.Items[$n].Line -Quote $dB.Items[$n].Heading),
                                         (New-Location -Doc $dA.Name -Audience $dA.Audience -Ref ('{0} {1}' -f $dB.Items[$n].Label, $n) -Line 0 -Quote ''))))
                    }
                }

                foreach ($n in @($dA.Items.Keys)) {
                    if (-not $dB.Items.Contains($n)) { continue }
                    $iA = $dA.Items[$n]
                    $iB = $dB.Items[$n]

                    # mapping
                    $keA = @($iA.Ke.ToArray() | Sort-Object -Unique)
                    $keB = @($iB.Ke.ToArray() | Sort-Object -Unique)
                    if (($keA -join ',') -ne ($keB -join ',')) {
                        $hazards.Add((New-Hazard -Type 'mapping' -Key ('item {0} mapping' -f $n) `
                            -Summary ('{0} {1} is mapped to [{2}] in {3} and to [{4}] in {5}. One question cannot assess two different knowledge points.' -f $iA.Label, $n, ($keA -join ' '), $dA.Name, ($keB -join ' '), $dB.Name) `
                            -Locations @((New-Location -Doc $dA.Name -Audience $dA.Audience -Ref ('{0} {1}' -f $iA.Label, $n) -Line $iA.Line -Quote ($keA -join ' ')),
                                         (New-Location -Doc $dB.Name -Audience $dB.Audience -Ref ('{0} {1}' -f $iA.Label, $n) -Line $iB.Line -Quote ($keB -join ' ')))))
                    }

                    # parts, and their stems
                    foreach ($p in @($iA.Parts.Keys)) {
                        $ref = ('{0} {1}({2})' -f $iA.Label, $n, $p)
                        if (-not $iB.Parts.Contains($p)) {
                            $hazards.Add((New-Hazard -Type 'missing-item' -Key ('part {0}({1})' -f $n, $p) `
                                -Summary ('{0} is set out in {1} and has no matching part in {2}.' -f $ref, $dA.Name, $dB.Name) `
                                -Locations @((New-Location -Doc $dA.Name -Audience $dA.Audience -Ref $ref -Line $iA.Parts[$p].Line -Quote (Get-StemText $iA.Parts[$p])),
                                             (New-Location -Doc $dB.Name -Audience $dB.Audience -Ref $ref -Line 0 -Quote ''))))
                            continue
                        }
                        $sA = ConvertTo-GateNormal (Get-StemText $iA.Parts[$p])
                        $sB = ConvertTo-GateNormal (Get-StemText $iB.Parts[$p])
                        if ($sA -eq $sB) { continue }
                        $wA = @($sA -split ' ' | Where-Object { $_ })
                        $wB = @($sB -split ' ' | Where-Object { $_ })
                        $setB = New-Object 'System.Collections.Generic.HashSet[string]'
                        foreach ($w in $wB) { [void]$setB.Add($w) }
                        $hit = 0
                        foreach ($w in $wA) { if ($setB.Contains($w)) { $hit++ } }
                        $ratio = 0.0
                        if ($wA.Count -gt 0) { $ratio = [double]$hit / [double]$wA.Count }
                        if ($ratio -ge $stemFloor) { continue }
                        $hazards.Add((New-Hazard -Type 'question-text' -Key ('part {0}({1}) text' -f $n, $p) `
                            -Summary ('{0} carries two different texts: {1:P0} of the wording in {2} is in {3}. A learner is prepared for one of them and marked against the other.' -f $ref, $ratio, $dA.Name, $dB.Name) `
                            -Locations @((New-Location -Doc $dA.Name -Audience $dA.Audience -Ref $ref -Line $iA.Parts[$p].Line -Quote (Get-ShortSpan -Mine $sA -Theirs $sB)),
                                         (New-Location -Doc $dB.Name -Audience $dB.Audience -Ref $ref -Line $iB.Parts[$p].Line -Quote (Get-ShortSpan -Mine $sB -Theirs $sA)))))
                    }
                    foreach ($p in @($iB.Parts.Keys)) {
                        if ($iA.Parts.Contains($p)) { continue }
                        $ref = ('{0} {1}({2})' -f $iB.Label, $n, $p)
                        $hazards.Add((New-Hazard -Type 'missing-item' -Key ('part {0}({1})' -f $n, $p) `
                            -Summary ('{0} is set out in {1} and has no matching part in {2}.' -f $ref, $dB.Name, $dA.Name) `
                            -Locations @((New-Location -Doc $dB.Name -Audience $dB.Audience -Ref $ref -Line $iB.Parts[$p].Line -Quote (Get-StemText $iB.Parts[$p])),
                                         (New-Location -Doc $dA.Name -Audience $dA.Audience -Ref $ref -Line 0 -Quote ''))))
                    }
                }
            }
        }
    }
    Add-Arm 'question-text' $true ('{0} famil(ies) with two or more documents' -f $multiFamilies.Count)
    Add-Arm 'missing-item'  $true ('{0} famil(ies) with two or more documents' -f $multiFamilies.Count)
    Add-Arm 'mapping'       $true ('{0} famil(ies) with two or more documents; contract map: {1}' -f $multiFamilies.Count, $keFrom)
}

# --- ARM 4b: the pack's own mapping against the contract's
if ($contractKe.Count -gt 0) {
    foreach ($d in $parsed.ToArray()) {
        foreach ($n in @($d.Items.Keys)) {
            $ke = @($d.Items[$n].Ke.ToArray() | Sort-Object -Unique)
            foreach ($k in $ke) {
                $ku = $k.ToUpperInvariant()
                if (-not $contractKe.ContainsKey($ku)) { continue }
                if ($contractKe[$ku] -ne [string]$n) {
                    $hazards.Add((New-Hazard -Type 'mapping' -Key ('{0} against the contract' -f $ku) `
                        -Summary ('{0} states that {1} {2} assesses {3}; the build contract records {3} as assessed in item {4}. The pack and the map the build was given disagree.' -f $d.Name, $d.Items[$n].Label, $n, $ku, $contractKe[$ku]) `
                        -Locations @((New-Location -Doc $d.Name -Audience $d.Audience -Ref ('{0} {1}' -f $d.Items[$n].Label, $n) -Line $d.Items[$n].Line -Quote $ku))))
                }
            }
        }
    }
}

# --- ARM 3: numeral divergence on masked sentences
$maskHits = 0
foreach ($fam in $families.ToArray()) {
    $mem = @($fam.Members)
    if ($mem.Count -lt 2 -and -not $IncludeWithinDocument) { continue }
    #  key -> document -> set of value signatures, with the first line each
    #  signature was seen on, per document.
    $keyMap = @{}
    foreach ($d in $mem) {
        for ($i = 0; $i -lt $d.Lines.Count; $i++) {
            $ln = $d.Lines[$i]
            if (-not $ln) { continue }
            $ms = [regex]::Matches($ln, $NUM_RX, 'IgnoreCase')
            if ($ms.Count -eq 0) { continue }
            $masked = [regex]::Replace($ln, $NUM_RX, { param($m) ' NUMTOKEN ' + $m.Groups[2].Value }, 'IgnoreCase')
            $key = ConvertTo-GateNormal $masked
            if (@($key -split ' ' | Where-Object { $_ }).Count -lt $MIN_MASK_WORDS) { continue }
            $vals = @()
            foreach ($m in $ms) { $vals += ('{0} {1}' -f $m.Groups[1].Value, (Get-UnitClass $m.Groups[2].Value)) }
            $sig = ($vals -join ' + ')
            if (-not $keyMap.ContainsKey($key)) { $keyMap[$key] = @{} }
            if (-not $keyMap[$key].ContainsKey($d.Name)) { $keyMap[$key][$d.Name] = @{} }
            if (-not $keyMap[$key][$d.Name].ContainsKey($sig)) { $keyMap[$key][$d.Name][$sig] = [pscustomobject]@{ Line = $i + 1; Text = $ln; Doc = $d } }
            $maskHits++
        }
    }
    foreach ($key in @($keyMap.Keys)) {
        $perDoc = $keyMap[$key]
        $docNames = @($perDoc.Keys)
        if ($docNames.Count -lt 2) {
            if (-not $IncludeWithinDocument) { continue }
            if ($perDoc[$docNames[0]].Count -lt 2) { continue }
        }
        else {
            #  Two documents that carry the SAME set of values for one sentence
            #  are two documents agreeing: a standard stated as two rows appears
            #  twice in both, and calling that a divergence is how a gate becomes
            #  noise nobody reads.
            $sets = @()
            foreach ($dn in $docNames) { $sets += ((@($perDoc[$dn].Keys) | Sort-Object) -join ' ; ') }
            if (@($sets | Select-Object -Unique).Count -lt 2) { continue }
        }

        $locs = New-Object System.Collections.Generic.List[object]
        $allAssessor = $true
        $desc = New-Object System.Collections.Generic.List[string]
        foreach ($dn in ($docNames | Sort-Object)) {
            foreach ($sig in (@($perDoc[$dn].Keys) | Sort-Object)) {
                $rec = $perDoc[$dn][$sig]
                if ($rec.Doc.Audience -ne 'assessor') { $allAssessor = $false }
                $q = ''
                if ($rec.Doc.Audience -ne 'assessor') {
                    $q = $rec.Text
                    if ($q.Length -gt 160) { $q = $q.Substring(0, 157) + '...' }
                }
                $locs.Add((New-Location -Doc $dn -Audience $rec.Doc.Audience -Ref '' -Line $rec.Line -Quote $q))
                $desc.Add(('{0} line {1}: [{2}]' -f $dn, $rec.Line, $sig))
            }
        }
        if ($allAssessor) {
            $summary = ('One statement is given different values in {0} places, every one of them inside an assessor-only document. The values are WITHHELD - a benchmark figure is an answer - and the locations are cited so a reader can open them: {1}.' -f $locs.Count, ((@($locs.ToArray() | ForEach-Object { '{0} line {1}' -f $_.doc, $_.line })) -join '; '))
            $hazards.Add((New-Hazard -Type 'numeral' -Key $key -Summary $summary -Locations $locs.ToArray() -ValuesWithheld $true))
        }
        else {
            $summary = ('The same statement carries different figures across the family: {0}. The pack wins over the guide, but it cannot win over itself.' -f ($desc.ToArray() -join '; '))
            $hazards.Add((New-Hazard -Type 'numeral' -Key $key -Summary $summary -Locations $locs.ToArray()))
        }
    }
}
Add-Arm 'numeral' $true ('{0} measured statement(s) read; scope: {1}' -f $maskHits, $(if ($IncludeWithinDocument) { 'across AND within documents' } else { 'ACROSS documents of one family only - the within-document arm is available under -IncludeWithinDocument and is off by default, because a two-row standard stated as two rows is not a divergence' }))

# --- ARM 5: a stated count against the pack's own grid for that question
if ($gridRows.Count -eq 0) {
    Add-Arm 'count-vs-grid' $false $gridsFrom
}
else {
    $verbRx = '(?:give|list|name|identify|state|provide|select|describe)'
    $numRx2 = '(?:' + ((@($NUMBER_WORD.Keys) -join '|')) + '|\d+)'
    $countRx = '(?i)\b' + $verbRx + '\s+(?:the\s+)?(' + $numRx2 + ')\b'
    $distributiveRx = '(?i)\b(for each|for every|each of|per row|per cell|one each)\b'
    $checked = 0
    foreach ($d in $parsed.ToArray()) {
        foreach ($n in @($d.Items.Keys)) {
            foreach ($p in @($d.Items[$n].Parts.Keys)) {
                $k = ('{0}|{1}|{2}' -f (ConvertTo-GateNormal $d.Name), $n, $p)
                if (-not $gridRows.ContainsKey($k)) { continue }
                $stem = Get-StemText $d.Items[$n].Parts[$p]
                #  A distributive stem counts PER ROW, not rows: "for each
                #  measure, give one rule" against a four-row grid is correct.
                if ($stem -match $distributiveRx) { continue }
                $m = [regex]::Match($stem, $countRx)
                if (-not $m.Success) { continue }
                $checked++
                $w = $m.Groups[1].Value.ToLowerInvariant()
                $want = 0
                if ($NUMBER_WORD.ContainsKey($w)) { $want = [int]$NUMBER_WORD[$w] }
                elseif ($w -match '^\d+$') { $want = [int]$w }
                if ($want -le 0) { continue }
                $have = [int]$gridRows[$k]
                #  ASYMMETRIC, AND DELIBERATELY SO. A question that asks for
                #  more than its grid can hold blocks the learner and is the
                #  defect this arm is named for. A grid with ONE row more than
                #  the question asks for is almost always a worked example row
                #  or a header the pack pre-filled, and calling that a defect
                #  is how a gate earns its reputation for crying wolf: on a real
                #  pack the single instance of it was a log whose own stem said
                #  the extra row was filled in already. Two or more unexplained
                #  extra rows is a grid that does not match its question.
                $short = ($want -gt $have)
                if (-not $short -and (($have - $want) -lt 2)) { continue }
                if ($want -eq $have) { continue }
                $ref = ('{0} {1}({2})' -f $d.Items[$n].Label, $n, $p)
                $why = 'A learner who answers the question as written cannot fill the grid as built.'
                if (-not $short) { $why = 'The grid carries rows the question does not ask for, and nothing in the stem says what they are.' }
                $hazards.Add((New-Hazard -Type 'count-vs-grid' -Key ('{0} count' -f $ref) `
                    -Summary ('{0} in {1} asks for {2} and the pack built it a response grid of {3} row(s). {4}' -f $ref, $d.Name, $want, $have, $why) `
                    -Locations @((New-Location -Doc $d.Name -Audience $d.Audience -Ref $ref -Line $d.Items[$n].Parts[$p].Line -Quote (Get-ShortSpan -Mine (ConvertTo-GateNormal $stem) -Theirs '' -Window 14)))))
            }
        }
    }
    Add-Arm 'count-vs-grid' $true ('{0}; {1} question(s) stated a count against a grid' -f $gridsFrom, $checked)
}

# --- ARM 6: arithmetic, on a line that states its own components and total
$arithChecked = 0
foreach ($d in $parsed.ToArray()) {
    for ($i = 0; $i -lt $d.Lines.Count; $i++) {
        $ln = $d.Lines[$i]
        if (-not $ln -or $ln -notmatch '(?i)\btotal\b') { continue }
        $ms = @([regex]::Matches($ln, $NUM_RX, 'IgnoreCase'))
        if ($ms.Count -lt 3) { continue }
        $totIx = -1
        foreach ($m in $ms) {
            $lead = $ln.Substring(0, $m.Index)
            if ($lead -match '(?i)\btotal\b[^a-z0-9]{0,12}$') { $totIx = $m.Index }
        }
        if ($totIx -lt 0) { continue }
        $totalM = @($ms | Where-Object { $_.Index -eq $totIx })[0]
        $unit = Get-UnitClass $totalM.Groups[2].Value
        $parts = @($ms | Where-Object { $_.Index -ne $totIx -and (Get-UnitClass $_.Groups[2].Value) -eq $unit })
        if ($parts.Count -lt 2) { continue }
        $arithChecked++
        $sum = 0.0
        foreach ($m in $parts) { $sum += [double]$m.Groups[1].Value }
        $tot = [double]$totalM.Groups[1].Value
        if ([Math]::Abs($sum - $tot) -lt 0.0001) { continue }
        $q = ''
        if ($d.Audience -ne 'assessor') { $q = $ln; if ($q.Length -gt 160) { $q = $q.Substring(0, 157) + '...' } }
        $hazards.Add((New-Hazard -Type 'arithmetic' -Key (ConvertTo-GateNormal $ln) `
            -Summary ('A stated total does not match its own components: {0} component(s) in {1} sum to {2} and the line states {3}.' -f $parts.Count, $unit, $sum, $tot) `
            -Locations @((New-Location -Doc $d.Name -Audience $d.Audience -Ref '' -Line ($i + 1) -Quote $q)) `
            -ValuesWithheld ($d.Audience -eq 'assessor')))
    }
}
Add-Arm 'arithmetic' $true ('{0} line(s) stated components and a total' -f $arithChecked)

# --- de-duplicate: one hazard per id, however many arms reached it
$unique = New-Object System.Collections.Specialized.OrderedDictionary
foreach ($h in ($hazards.ToArray() | Sort-Object type, key)) {
    if (-not $unique.Contains($h.id)) { $unique[$h.id] = $h }
}

# ---------------------------------------------------------------------------
# 3. Disposition - written on the first run, re-read on every run after
# ---------------------------------------------------------------------------

$prior = @{}
$priorFile = Get-GateJson -Path $HazardPath
if ($null -ne $priorFile) {
    foreach ($e in @(Get-GateProp -Object $priorFile -Names @('hazards') -Default @())) {
        if ($null -eq $e) { continue }
        $eid = [string](Get-GateProp -Object $e -Names @('id') -Default '')
        if ($eid) { $prior[$eid] = $e }
    }
}

$now = (Get-Date).ToUniversalTime().ToString('o')
$out = New-Object System.Collections.Generic.List[object]
$undispositioned = New-Object System.Collections.Generic.List[object]
$dispositioned = 0

foreach ($id in @($unique.Keys)) {
    $h = $unique[$id]
    $disp = [ordered]@{ decision = ''; note = ''; by = ''; on = ''; reportToRto = $true }
    $first = $now
    if ($prior.ContainsKey($id)) {
        $pd = Get-GateProp -Object $prior[$id] -Names @('disposition')
        if ($null -ne $pd) {
            $disp['decision']    = [string](Get-GateProp -Object $pd -Names @('decision') -Default '')
            $disp['note']        = [string](Get-GateProp -Object $pd -Names @('note', 'reason', 'why') -Default '')
            $disp['by']          = [string](Get-GateProp -Object $pd -Names @('by', 'who') -Default '')
            $disp['on']          = [string](Get-GateProp -Object $pd -Names @('on', 'when') -Default '')
            $r = Get-GateProp -Object $pd -Names @('reportToRto')
            if ($null -ne $r) { $disp['reportToRto'] = [bool]$r }
        }
        $f = [string](Get-GateProp -Object $prior[$id] -Names @('firstSeen') -Default '')
        if ($f) { $first = $f }
    }
    $noteOk = (("$($disp['note'])").Trim().Length -ge $MIN_NOTE_CHARS)
    $decOk = (("$($disp['decision'])").Trim().Length -gt 0)
    $isDisposed = ($noteOk -and $decOk)
    if ($isDisposed) { $dispositioned++ } else { $undispositioned.Add($h) }

    $out.Add([pscustomobject]@{
        id             = $h.id
        type           = $h.type
        key            = $h.key
        summary        = $h.summary
        locations      = $h.locations
        valuesWithheld = $h.valuesWithheld
        state          = 'open'
        firstSeen      = $first
        lastSeen       = $now
        dispositioned  = $isDisposed
        disposition    = [pscustomobject]$disp
    })
}

# --- hazards the file remembers that this run no longer detects. Kept, with
#     their written decisions, so a disposition is not lost to a re-parse; not
#     blocking, because there is nothing left to accept.
$stale = New-Object System.Collections.Generic.List[object]
foreach ($id in @($prior.Keys)) {
    if ($unique.Contains($id)) { continue }
    $e = $prior[$id]
    $stale.Add([pscustomobject]@{
        id             = $id
        type           = [string](Get-GateProp -Object $e -Names @('type') -Default '')
        key            = [string](Get-GateProp -Object $e -Names @('key') -Default '')
        summary        = [string](Get-GateProp -Object $e -Names @('summary') -Default '')
        locations      = @(Get-GateProp -Object $e -Names @('locations') -Default @())
        valuesWithheld = [bool](Get-GateProp -Object $e -Names @('valuesWithheld') -Default $false)
        state          = 'gone'
        firstSeen      = [string](Get-GateProp -Object $e -Names @('firstSeen') -Default '')
        lastSeen       = [string](Get-GateProp -Object $e -Names @('lastSeen') -Default '')
        dispositioned  = [bool](Get-GateProp -Object $e -Names @('dispositioned') -Default $false)
        disposition    = (Get-GateProp -Object $e -Names @('disposition'))
    })
}

$hazFileBody = [ordered]@{}
$hazFileBody['_purpose']  = 'Hazards found INSIDE the assessment pack, each needing a written disposition before authoring opens. The build never edits the pack; it accepts a defect consciously and reports it, or it explains why the finding is not one. An undispositioned hazard fails the Stage 1 gate.'
$hazFileBody['_howToDispose'] = ("Fill disposition.decision and disposition.note on each open hazard, then re-run the gate. The note must be a real sentence of at least {0} characters saying what the build will do and what the report will say. reportToRto stays true unless the note explains why the RTO does not need to hear about it." -f $MIN_NOTE_CHARS)
$hazFileBody['_leakage']  = 'Where valuesWithheld is true, the differing values are deliberately absent: every location is inside an assessor-only document and a benchmark figure is an answer. Open the cited lines to see them; do not copy them into this file.'
$hazFileBody['generated'] = [ordered]@{ generatedBy = $GATE; generatedOn = $now; corpusDir = $corpusPath; hazardFile = $HazardPath }
$hazFileBody['hazards']   = @($out.ToArray() + $stale.ToArray())
Write-Result -Path $HazardPath -Body $hazFileBody

# ---------------------------------------------------------------------------
# 4. Report
# ---------------------------------------------------------------------------

$exitCode = 0
if ($undispositioned.Count -gt 0) { $exitCode = 1 }

if (-not $Quiet) {
    Write-Host ''
    Write-Host 'PACK SELF-CONSISTENCY - hazards inside the pack, raised and dispositioned, never fixed' -ForegroundColor Cyan
    Write-Host ("  corpus : {0}  (classified from {1})" -f $corpusPath, $corpus.ClassifiedFrom) -ForegroundColor DarkGray
    Write-GateCheckSet -What 'pack documents' -Count $parsed.Count -DerivedFrom 'Lib-GateCommon Get-GateCorpusDocs'
    Write-GateCheckSet -What ('item label word(s): ' + ($labelSet -join ', ')) -Count $labelSet.Count -DerivedFrom $labelFrom
    Write-Host ("  families: {0}" -f ((@($families.ToArray() | ForEach-Object { '{0} [{1} doc(s)]' -f $_.Name, $_.Members.Count })) -join '; ')) -ForegroundColor DarkGray
    foreach ($o in $orphans) { Write-Host ("  ! {0} is assessor-facing and pairs with no learner-facing tool; nothing in the corpus can be compared against it." -f $o.Name) -ForegroundColor Yellow }
    Write-Host ("  stem overlap floor {0:P0} ({1}); grids: {2}; knowledge map: {3}" -f $stemFloor, $stemFrom, $gridsFrom, $keFrom) -ForegroundColor DarkGray
    Write-Host ''
    foreach ($a in $armLog.ToArray()) {
        if ($a.ran) { Write-Host ("  arm {0,-14} ran     - {1}" -f $a.arm, $a.detail) -ForegroundColor DarkGray }
        else        { Write-Host ("  arm {0,-14} SKIPPED - {1}" -f $a.arm, $a.detail) -ForegroundColor Yellow }
    }
    Write-Host ''
    Write-Host '  This gate cannot see a figure contradicted in different words - a card''s stated yield against its own method. That still belongs to the Stage 1 reader and the Stage 6 audit.' -ForegroundColor DarkGray

    Write-Host ''
    if ($out.Count -eq 0) {
        Write-Host '  no hazard found by any arm that ran.' -ForegroundColor Green
    }
    else {
        foreach ($h in $out.ToArray()) {
            $col = 'Red'
            $tag = 'UNDISPOSITIONED'
            if ($h.dispositioned) { $col = 'Green'; $tag = ('disposed: ' + $h.disposition.decision) }
            Write-Host ("  [{0}] {1}  {2}" -f $h.id, $h.type, $tag) -ForegroundColor $col
            Write-Host ("     {0}" -f $h.summary) -ForegroundColor Gray
            foreach ($l in @($h.locations)) {
                if ($l.cited) { Write-Host ("     - {0} line {1} {2} (assessor-only: cited, not quoted)" -f $l.doc, $l.line, $l.ref) -ForegroundColor DarkGray }
                else          { Write-Host ("     - {0} line {1} {2}: `"{3}`"" -f $l.doc, $l.line, $l.ref, $l.quote) -ForegroundColor DarkGray }
            }
            if ($h.dispositioned) { Write-Host ("     note: {0}" -f $h.disposition.note) -ForegroundColor DarkGray }
        }
    }
    if ($stale.Count -gt 0) {
        Write-Host ''
        Write-Host ("  {0} hazard(s) in {1} are no longer detected; their written decisions are kept and they do not block." -f $stale.Count, (Split-Path $HazardPath -Leaf)) -ForegroundColor DarkGray
    }

    Write-Host ''
    Write-Host ("  {0} hazard(s): {1} dispositioned, {2} not." -f $out.Count, $dispositioned, $undispositioned.Count) -ForegroundColor DarkGray
    if ($exitCode -eq 0) {
        if ($out.Count -eq 0) { Write-Host '  the pack is self-consistent on every arm that ran. Authoring may open.' -ForegroundColor Green }
        else { Write-Host '  every hazard carries a written decision. The build inherits them knowingly, and the report says so.' -ForegroundColor Green }
    }
    else {
        Write-Host ("  X {0} hazard(s) have no written disposition. Authoring must not open: an undispositioned pack defect is one the guide will absorb silently, and the RTO will never hear about it." -f $undispositioned.Count) -ForegroundColor Red
        Write-Host ("    Write a decision and a note into {0}, then re-run." -f $HazardPath) -ForegroundColor Red
    }
    Write-Host ("  hazards written to {0}" -f $HazardPath) -ForegroundColor DarkGray
}

$body = [ordered]@{}
$body['gate']            = $GATE
$body['mode']            = 'sweep'
$body['verdict']         = $(if ($exitCode -eq 0) { 'PASS' } else { 'FAIL' })
$body['corpusDir']       = $corpusPath
$body['hazardFile']      = $HazardPath
$body['documents']       = @($parsed.ToArray() | ForEach-Object { [pscustomobject]@{ name = $_.Name; audience = $_.Audience; items = $_.Items.Count } })
$body['families']        = @($families.ToArray() | ForEach-Object { [pscustomobject]@{ name = $_.Name; members = @($_.Members | ForEach-Object { $_.Name }) } })
$body['orphanAssessorDocuments'] = @($orphans | ForEach-Object { $_.Name })
$body['itemLabels']      = $labelSet
$body['itemLabelsFrom']  = $labelFrom
$body['arms']            = $armLog.ToArray()
$body['hazards']         = $out.ToArray()
$body['staleHazards']    = $stale.ToArray()
$body['dispositioned']   = $dispositioned
$body['undispositioned'] = $undispositioned.Count
$body['checkedAt']       = $now
$body['exitCode']        = [int]$exitCode
Write-Result -Path $ResultPath -Body $body

exit $exitCode
