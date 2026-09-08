<#
    Assert-SpineCounts.ps1 - the word floors and the two-way question
    cross-reference, measured ON THE SPINE.

    Implements references\gates.md section 23. Runs at Stage 3c, hours before
    a document exists, and again before every Stage 7 re-render.

    IT DOES NOT REPLACE THE RENDER-TIME GATE. Section 3's 3,000-word Topic
    floor and 800-word Underpinning knowledge floor, and section 7's question
    cross-reference, keep running at Stage 4 on the built .docx exactly as they
    always did. What this moves earlier is FIRST DETECTION of a content
    shortfall, which is the expensive thing to find after a render: section 3
    warns that the 800-word floor is the one that bites, and the build it was
    measured on had thirty-one blocks under it.

    WHY THE SPINE IS THE BETTER MEASURING SURFACE. On the rendered page,
    artwork prompt text sits in the same paragraph stream as body prose, and
    the build's own gate runner had to strip prompt paragraphs from a COPY of
    the rendered file to measure anything. A topic-balance finding then had to
    reason around its own measurement surface. On the spine, prompt text and
    body prose are separate fields and cannot be confused: the counted set is
    a set of FIELDS, so a prompt is excluded by construction rather than by a
    regular expression applied to a page.

    THE EXCLUSION RULE IS THE RENDER GATE'S, TRANSLATED, NOT A NEW ONE. The
    render gate counts paragraphs not inside a <w:tbl>, which in this house
    style excludes every callout, sign-off block, worked-example table and
    answer space. The spine equivalent is the authored prose fields the content
    brief names as counted - whatThisMeans, underpinningKnowledge,
    regulatoryBasis, howToDoIt and the topic overview - with every box, table,
    grid, visual, slide and identifier excluded. THE SET IS READ FROM THE
    CONTRACT, never typed here, and a build that declares none is refused
    exactly as a build that declares no floor is: the field names belong to
    the spine this build wrote. It is printed with the full list of field
    paths it excluded, so a reader can see exactly what was and was not
    counted.

    THE FLOORS ARE READ, NEVER TYPED. contract.json wordFloors, or the RTO /
    build profile passed on -Profile. A build that declares neither is not
    silently given a default: the gate fails and names the input, because a
    blocking rule measured against a number nobody declared is a rule nobody
    signed.

    THE CROSS-REFERENCE IS DERIVED FROM THE CORPUS, AND BOTH DIRECTIONS BLOCK.
    The pack's questions are read out of the extracted pack text itself, using
    the reference pattern each document declares in the Stage 2 register - not
    out of the contract's question map, which is a plan and can be wrong in the
    same direction as the spine that was written from it.

      prepared nowhere    a question the pack contains that no sub-section
                          prepares. A coverage gap.
      invented reference  a question the guide or the deck cites that the pack
                          does not contain. The most damaging defect this
                          document type can ship: a learner revises for a
                          question that is not on the paper.

    A BLOCKING RULE WHOSE INPUT IS ABSENT FAILS AND NAMES THE INPUT. It is
    never reported as information and never returns a pass. -AllowPartial is
    the only way past, and it turns every unrunnable rule into a loud PARTIAL
    RUN banner, returns them on the result, and exits 3 so no caller can read
    it as a pass.

    TRUSTED ONLY AFTER FAILING ON A PLANTED DEFECT. -SelfTest builds a fixture,
    plants four defects one at a time, VERIFIES EACH PLANT LANDED by measuring
    the fixture back before the gate is run on it, and fails if the gate does
    not catch it or if it fires on the clean control.

    PS 5.1. ASCII only in this file. Nothing here names a unit, a brand or a path.
    Exit 1 a blocking finding, 2 a usage error, a missing blocking input or an
    empty blocking check-set, 3 a PARTIAL RUN, 4 the self-test failed.

    ARMS (Lib-GateCommon roster). spine-files, counted-prose, word-floors and
    pack-questions are BLOCKING; each ends ran (size > 0), empty (a refusal,
    exit 2, naming the input) or declared-n-a with a written reason from
    contract.json gateArms.

    ONE REFERENCE REGEX, ONE KEY, BOTH DIRECTIONS (P1-01). The pack's
    references and the spine's citations are read with the SAME compiled
    regex - contract.json referenceConvention.questionPattern, and nothing
    else. There is no fallback pattern: an undeclared questionPattern puts the
    arm in PARTIAL and the gate exits naming the key, because a grammar this
    gate guessed for itself is what manufactured every finding it has ever
    raised on the reference build. Both sides are then normalised through one
    key (whitespace removed, lower-cased), so 'Task 11 (a)' in the pack and
    'Task 11(a)' on the spine are one reference.

    The retired harvester formatted each reference by substituting into the
    pattern template, and for an observation it substituted an EMPTY {part}:
    'Observation {n} item {part}' collapsed to 'Observation 1 item', a string
    in neither vocabulary. The gate reported that phantom as a question
    prepared nowhere and all eleven genuine observation references as
    invented - twelve blocking findings, twelve false, one remediation round.
    Nothing here builds a reference by substitution any more. Where this house
    style writes a task's parts on their own lines under the heading, the
    continuation joins heading and part and hands the candidate BACK to the
    one regex, which must match it whole or it is not a reference.

    TWO CLASSES COME OUT OF THE PACK, and the difference is the contract's own
    grammar. A family whose declared pattern carries {part} is not complete
    without one, so 'Observation 1 runs across Tasks 11, 12 and 13' is the pack
    SIGNPOSTING, not a question. Nothing prepares a signpost, so direction one
    runs over the questions; but the pack does contain it, so a guide sentence
    repeating it invents nothing and direction two counts it present. A
    citation that names a task the pack never names is admitted only where
    contract.json declares allowTaskLevelSignpost, and then only on a boundary
    a digit cannot cross - the retired escape used StartsWith, so a cited
    'Task 1' was satisfied by a pack holding nothing but 'Task 12(a)'.

    THE COUNTED FIELD SET IS DECLARED OR THE GATE REFUSES, exactly as the
    floors are, and a missing wordFloors.balanceTolerance is PARTIAL (which
    moves the exit code) rather than NOT RUN (which never did).
#>

# GATE: stages=3c; requires=BuildDir

[CmdletBinding()]
param(
    [string] $BuildDir,
    [string] $SpineDir,
    [string] $CorpusDir,
    #  Written by New-WithholdRegister.ps1 at Stage 2. Read for ONE thing: the
    #  reference pattern each pack document declares, so the pack's questions
    #  can be read out of the pack's own text.
    [string] $Register,
    #  An RTO or build profile that may carry the floors.
    [string] $Profile,
    #  Explicit floors override everything and are printed as an override.
    [int] $TopicWordFloor,
    [int] $SubjectWordFloor,
    [string] $OutPath,
    [switch] $AllowPartial,
    [switch] $SelfTest,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'

$script:ScScriptDir = $PSScriptRoot
if (-not $script:ScScriptDir) { $script:ScScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $script:ScScriptDir 'Lib-GateCommon.ps1')

$GATE = 'Assert-SpineCounts'
#  This script's own path, for the self-test's child runs ($PSCommandPath is
#  empty inside a function, so it is captured once here at script scope).
$script:ScSelf = $PSCommandPath

function Stop-ScUsage {
    param([string] $Message)
    Write-Host ("  X {0}: {1}" -f $GATE, $Message) -ForegroundColor Red
    exit 2
}

# ---------------------------------------------------------------------------
# Counting
# ---------------------------------------------------------------------------

function Measure-ScWords {
    <#  The render gate's token rule, so a spine count and a rendered count of
        the same prose are the same number and a difference between them means
        something.  #>
    param([string] $Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return 0 }
    return @([regex]::Matches($Text, "[A-Za-z0-9][A-Za-z0-9'\-\.]*")).Count
}

# ---------------------------------------------------------------------------
# What counts as body prose - read from the contract, printed either way
# ---------------------------------------------------------------------------

function Resolve-ScCountedFields {
    <#  Returns the counted field paths (indices stripped) with a reason each,
        and the source it came from. A field path is matched against the path
        Get-GateSpineCells reports, so 'howToDoIt.step' catches every step of
        every entry and nothing else.  #>
    param($Contract)

    $out = [ordered]@{}
    $src = ''
    $wf = $null
    if ($null -ne $Contract) { $wf = Get-GateProp -Object $Contract -Names @('wordFloors') -Default $null }
    $declared = @()
    if ($null -ne $wf) { $declared = @(Get-GateProp -Object $wf -Names @('countedFields', 'countedProseFields') -Default @()) }
    if (@($declared).Count -eq 0 -and $null -ne $Contract) {
        $sc = Get-GateProp -Object $Contract -Names @('spineContract') -Default $null
        if ($null -ne $sc) { $declared = @(Get-GateProp -Object $sc -Names @('countedProseFields', 'countedFields') -Default @()) }
    }

    #  P1-01. THE COUNTED SET IS DECLARED OR THE GATE REFUSES. This function
    #  used to fall back to six field names typed into this file. That is the
    #  same defect as a typed word floor: both floors below, and therefore
    #  every topic and underpinning finding this gate has ever raised, were
    #  measured over a field list nobody signed - and a build whose spine
    #  renames a prose field would have been measured over the wrong fields
    #  while printing a green line. A blocking rule whose input is absent
    #  FAILS and names the input.
    if (@($declared).Count -eq 0) {
        throw ("{0}: no counted-prose field set is declared. Declare it in contract.json wordFloors.countedFields (or spineContract.countedProseFields) as the field paths Get-GateSpineCells reports, each with a reason - the render gate's not-inside-a-table exclusion rule has to be translated into THIS build's spine field names by the build that wrote them, and a word floor measured over a field list this gate typed in for itself is a rule nobody signed." -f $GATE)
    }

    foreach ($e in $declared) {
        if ($e -is [string]) { $out["$e"] = 'declared by the build contract' ; continue }
        $f = Get-GateProp -Object $e -Names @('field', 'name', 'path')
        $r = Get-GateProp -Object $e -Names @('reason', 'why') -Default 'declared by the build contract'
        if ($f) { $out["$f"] = "$r" }
    }
    $src = 'contract.json wordFloors.countedFields'

    if ($out.Count -eq 0) {
        throw ("{0}: contract.json wordFloors.countedFields is declared but yielded no usable field path - every entry is missing its 'field' (or 'name'/'path') property. Declare the field paths, or the floors below measure nothing." -f $GATE)
    }
    return [pscustomobject]@{ Fields = $out; Source = $src }
}

# ---------------------------------------------------------------------------
# The pack's questions, read out of the pack's own text
# ---------------------------------------------------------------------------

function Get-ScDocumentPatterns {
    <#  document stem -> the reference pattern it declares, from the Stage 2
        register. The register resolved this from the pack; nothing here
        guesses which document a bare "Task 5" belongs to, which is the
        ambiguity the reference convention exists to remove.  #>
    param($RegJson)

    $map = @{}
    if ($null -eq $RegJson) { return $map }
    $docs = Get-GateProp -Object $RegJson -Names @('documents') -Default $null
    if ($null -eq $docs) { return $map }
    foreach ($p in $docs.PSObject.Properties) {
        if ($p.Name -like '_*') { continue }
        $aud = [string](Get-GateProp -Object $p.Value -Names @('audience') -Default 'learner')
        $pat = [string](Get-GateProp -Object $p.Value -Names @('referencePattern', 'pattern') -Default '')
        if ($pat) { $map[$p.Name] = [pscustomobject]@{ Audience = $aud; Pattern = $pat } }
    }
    return $map
}

function Get-ScRefKey {
    # REQUEST: Lib-GateCommon Get-GateRefKey
    <#  THE ONE NORMALISATION KEY, used on BOTH sides of the reconciliation.

        Test-GuideRules has carried this key (as its private NormRef) for as
        long as the render-side cross-reference has existed, and it is correct:
        whitespace carries no meaning inside a reference, and case carries
        none either. What was wrong was that this gate did not use it. The
        pack writes "Task 11 (a)" and the spine writes "Task 11(a)"; without
        one key those are two different references and the gate reports the
        second as invented.

        Requested for Lib-GateCommon so that Test-GuideRules, this gate and
        Test-Spine cannot drift apart again - see scratchpad REQUESTS\S.md.  #>
    param([string] $Ref)
    if ($null -eq $Ref) { return '' }
    return (("$Ref" -replace '\s+', '')).ToLowerInvariant()
}

function ConvertTo-ScLabelSpec {
    # REQUEST: Lib-GateCommon Get-ReferenceLabelSet
    <#  A declared reference pattern -> what the build says a reference of that
        family looks like. "Task {n}({part})" and "Observation {n} item {part}"
        are both read here; the second is the shape Invoke-Render's copy of
        Get-ReferenceLabelSet rejects, which is why that copy sees one family
        on a pack that declares two.

        Label             the literal text before {n} ('Task', 'Observation')
        RequiresPart      the pattern carries {part}: a reference of this
                          family is not complete without one, so a bare
                          "Task 11" is the pack talking ABOUT task 11, not a
                          question the guide must prepare
        ParenthesisedPart {part} follows {n} immediately in brackets, which is
                          the only shape whose parts are written on their own
                          lines under the heading rather than beside it  #>
    param([string] $Pattern, [string] $Key)

    if (-not $Pattern) { return $null }
    if ($Pattern -notmatch '\{n\}') { return $null }
    $i = $Pattern.IndexOf('{n}')
    $label = $Pattern.Substring(0, $i).Trim()
    if (-not $label) { return $null }
    if ($label -notmatch '^[A-Za-z][A-Za-z ]*$') { return $null }
    return [pscustomobject]@{
        Key               = $Key
        Label             = $label
        Pattern           = $Pattern
        RequiresPart      = [bool]($Pattern -match '\{part\}')
        ParenthesisedPart = [bool]($Pattern -match '\{n\}\s*\(\{part\}\)')
    }
}

function Get-ScReferenceLabels {
    # REQUEST: Lib-GateCommon Get-ReferenceLabelSet
    <#  Every reference family the contract declares, as label specs. Only
        string properties carrying {n} are patterns; 'taskMeans' names a .docx
        and 'questionPattern' is a regex, and neither is a reference grammar.  #>
    param($Contract)

    $out = New-Object System.Collections.Generic.List[object]
    if ($null -eq $Contract) { return $out.ToArray() }
    $rc = Get-GateProp -Object $Contract -Names @('referenceConvention') -Default $null
    if ($null -eq $rc) { return $out.ToArray() }
    foreach ($p in $rc.PSObject.Properties) {
        if ($p.Name -like '_*') { continue }
        if ($p.Value -isnot [string]) { continue }
        $spec = ConvertTo-ScLabelSpec -Pattern ([string]$p.Value) -Key $p.Name
        if ($null -ne $spec) { $out.Add($spec) }
    }
    return $out.ToArray()
}

function Get-ScLabelFor {
    <#  The declared family a harvested reference belongs to, longest label
        first so 'Knowledge Task' beats 'Task'. Null when the contract
        declares no family that could own it.  #>
    param([string] $Value, $Labels)

    $best = $null
    foreach ($l in @($Labels)) {
        if ($null -eq $l) { continue }
        if ($Value -match ('^\s*' + [regex]::Escape($l.Label) + '\s*\d')) {
            if ($null -eq $best -or $l.Label.Length -gt $best.Label.Length) { $best = $l }
        }
    }
    return $best
}

function Test-ScRefIsComplete {
    <#  Is this harvested reference a QUESTION, or the pack naming a task
        without naming a question inside it?

        Derived from the contract's own grammar, never from a literal here:
        a family whose pattern carries {part} is not complete without one.
        SITXINV007's contract says so in as many words - "The pattern
        deliberately requires a part on a Task and an item on an Observation,
        because a bare reference is exactly what the part-precision rule
        forbids". Where the contract declares no family for a reference, or
        declares one that needs no part, every match is a question.  #>
    param([string] $Value, $Labels)

    $spec = Get-ScLabelFor -Value $Value -Labels $Labels
    if ($null -eq $spec) { return $true }
    if (-not $spec.RequiresPart) { return $true }
    $rest = ([regex]::Replace($Value, ('^\s*' + [regex]::Escape($spec.Label) + '\s*\d+'), '')).Trim()
    return [bool]$rest
}

function Get-ScPackReferences {
    <#  Every reference the pack CONTAINS, read out of the pack's own extracted
        text with THE ONE COMPILED REFERENCE REGEX the contract declares - the
        same object direction two runs over the spine. Nothing here builds a
        reference by substituting into a pattern template.

        WHY THAT MATTERS. The retired harvester formatted each observation
        reference through Format-ScRef with an EMPTY {part}, so the pattern
        'Observation {n} item {part}' collapsed to the string 'Observation 1
        item' - a form that appears nowhere in the pack and matches nothing on
        the spine. The gate then reported that phantom as a question prepared
        nowhere AND reported all eleven genuine observation references the
        spine cites as invented: twelve blocking findings, twelve of them
        false, one whole remediation round.

        TWO CLASSES COME BACK, and the difference is the contract's grammar,
        not this file's opinion:
          Questions  complete references under the declared grammar. These are
                     what direction one requires a sub-section to prepare.
          Signposts  the pack naming a task or an observation without naming a
                     question inside it ("Observation 1 runs across Tasks 11,
                     12 and 13"). Nothing prepares a signpost - but the pack
                     DOES contain it, so a guide sentence that repeats it is
                     not inventing anything, and direction two counts it as
                     present.

        THE PARTS THE REGEX CANNOT SEE ON ONE LINE. Where the register's
        document pattern puts {part} in brackets straight after {n}, this pack
        style writes the heading on one line ("Task 3 - Quality and
        suitability of stock on hand") and each part on its own ("(a)  Below
        are six things..."). The continuation joins them - and then hands the
        candidate BACK TO THE ONE REGEX, which must match it whole or it is
        not a reference. The regex stays the only authority on both sides.  #>
    param($Corpus, [hashtable] $DocPatterns, [regex] $Rx, $Labels)

    $byKey = [ordered]@{}
    $scanned = New-Object System.Collections.Generic.List[string]
    $skippedDocs = New-Object System.Collections.Generic.List[string]
    $tocLines = 0

    function Add-ScPackRef {
        param([string] $Display, [string] $Doc, [string] $DocPath, [int] $Line, [string] $Quote, [string] $How)
        $disp = ($Display -replace '\s+', ' ').Trim()
        if (-not $disp) { return }
        $key = Get-ScRefKey $disp
        if ($byKey.Contains($key)) { $byKey[$key].Occurrences++ ; return }
        $complete = Test-ScRefIsComplete -Value $disp -Labels $Labels
        $byKey[$key] = [pscustomobject]@{
            Ref = $disp; Key = $key; Document = $Doc; DocumentPath = $DocPath; Line = $Line
            Quote = $Quote; HarvestedBy = $How
            Kind = $(if ($complete) { 'question' } else { 'signpost' })
            Occurrences = 1
        }
    }

    foreach ($d in @($Corpus.Learner)) {
        if (-not $DocPatterns.ContainsKey($d.Name)) { $skippedDocs.Add($d.Name); continue }
        $docSpec = ConvertTo-ScLabelSpec -Pattern ([string]$DocPatterns[$d.Name].Pattern) -Key $d.Name
        if ($null -eq $docSpec) { $skippedDocs.Add($d.Name); continue }
        $scanned.Add(("{0} ({1})" -f $d.Name, $DocPatterns[$d.Name].Pattern))

        $lines = @($d.Text -split "`r?`n")
        $cur = $null
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $s = "$($lines[$i])".Trim()
            if (-not $s) { continue }
            #  A contents entry carries the extractor's field code and is the
            #  page number of a task, not the task.
            if ($s -match 'PAGEREF|\\h\s|TOC \\') { $tocLines++; continue }
            $lineNo = $i + 1
            $quote = $s
            if ($quote.Length -gt 120) { $quote = $quote.Substring(0, 120) }

            foreach ($m in $Rx.Matches($s)) {
                Add-ScPackRef -Display $m.Value -Doc $d.Name -DocPath ([string]$d.Path) -Line $lineNo -Quote $m.Value -How 'reference regex'
            }

            if (-not $docSpec.ParenthesisedPart) { continue }

            $h = $Rx.Match($s)
            $isHeading = ($h.Success -and $h.Index -eq 0 -and ($s -match ('^' + [regex]::Escape($docSpec.Label) + '\s*\d')))
            if ($isHeading) {
                $headText = ($h.Value -replace '\s+', ' ').Trim()
                #  Only a BARE label-and-number heads a list of parts. A line
                #  opening with a complete reference is a mapping row, not a
                #  heading, and must not adopt the parts printed under it.
                if (-not (Test-ScRefIsComplete -Value $headText -Labels $Labels)) {
                    $cur = [pscustomobject]@{ Text = $headText; Line = $lineNo }
                }
                continue
            }
            if ($null -ne $cur -and $s -match '^\(([a-z])\)') {
                $cand = ('{0} ({1})' -f $cur.Text, $Matches[1])
                $cm = $Rx.Match($cand)
                if ($cm.Success -and $cm.Index -eq 0 -and $cm.Length -eq $cand.Length) {
                    Add-ScPackRef -Display $cand -Doc $d.Name -DocPath ([string]$d.Path) -Line $lineNo -Quote $quote -How ("part label under the heading at line {0}" -f $cur.Line)
                }
            }
        }
    }

    $all = @($byKey.Values)
    return [pscustomobject]@{
        Refs        = @($all | Where-Object { $_.Kind -eq 'question' })
        Signposts   = @($all | Where-Object { $_.Kind -eq 'signpost' })
        All         = $all
        Scanned     = $scanned.ToArray()
        Skipped     = $skippedDocs.ToArray()
        TocLinesSkipped = $tocLines
    }
}

function New-ScFinding {
    <#  One blocking finding. P1-14 gives Lib-GateCommon a New-GateFinding that
        re-opens the file a finding names and re-finds its Quote there, so a
        gate that cannot anchor its own finding exits GATE-DEFECT rather than
        blocking a build on a check-set artefact. Until it lands, this gate
        carries the same four properties in its own shape, so the anchors are
        already written and the adoption is a one-line change.  #>
    param(
        [string] $Kind,
        [string] $Where,
        [string] $Detail,
        [string] $File = '',
        [string] $Field = '',
        [string] $Quote = ''
    )

    $anchored = $null
    $anchorError = ''
    if (Get-Command New-GateFinding -ErrorAction SilentlyContinue) {
        try {
            $anchored = New-GateFinding -Rule $Kind -File $File -Field $Field -Quote $Quote -Detail $Detail
        }
        catch {
            #  A finding this gate cannot anchor is still a finding today. What
            #  it must NOT do is disappear, and what it must not do either is
            #  claim an anchor it does not have - so the reason is carried.
            $anchored = $null
            $anchorError = $_.Exception.Message
        }
    }
    else { $anchorError = 'Lib-GateCommon carries no New-GateFinding yet' }

    #  Today's finding shape is unchanged - every reader of this gate's report
    #  and every case in its own self-test keys on 'kind' - and the anchored
    #  object travels beside it for P1-14 to test and to exit 4 on.
    $o = [pscustomobject]@{ kind = $Kind; where = $Where; detail = $Detail; file = $File; field = $Field; quote = $Quote }
    Add-Member -InputObject $o -NotePropertyName 'anchored' -NotePropertyValue $anchored
    Add-Member -InputObject $o -NotePropertyName 'anchorError' -NotePropertyValue $anchorError
    return $o
}

# ---------------------------------------------------------------------------
# The measurement
# ---------------------------------------------------------------------------

function Invoke-ScMeasure {
    <#  Measure the spine and reconcile the cross-reference. Returns a result
        object and decides no exit code, so the self-test calls it exactly as
        the real run does.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [string] $SpineDir,
        [string] $CorpusDir,
        [string] $Register,
        [string] $Profile,
        [int] $TopicWordFloor,
        [int] $SubjectWordFloor,
        [bool] $ExplicitTopicFloor,
        [bool] $ExplicitSubjectFloor
    )

    $fail = New-Object System.Collections.Generic.List[object]
    $info = New-Object System.Collections.Generic.List[string]
    $partial = New-Object System.Collections.Generic.List[string]
    $notRun = New-Object System.Collections.Generic.List[string]

    $contract = Get-GateContract -BuildDir $BuildDir
    $profileJson = $null
    if ($Profile) {
        if (-not (Test-Path -LiteralPath $Profile)) { throw ("{0}: -Profile does not exist: {1}" -f $GATE, $Profile) }
        $profileJson = Get-GateJson -Path $Profile
    }

    # ---- floors, read never typed
    function Resolve-ScFloor {
        param([bool] $Explicit, [int] $Value, [string[]] $Names, [string] $Label)
        if ($Explicit) { return [pscustomobject]@{ Value = $Value; From = 'passed on the command line, which overrides every declaration and is recorded here as an override' } }
        foreach ($pair in @(
            [pscustomobject]@{ Node = $(if ($null -ne $contract) { Get-GateProp -Object $contract -Names @('wordFloors') -Default $null } else { $null }); Where = 'contract.json wordFloors' },
            [pscustomobject]@{ Node = $(if ($null -ne $profileJson) { Get-GateProp -Object $profileJson -Names @('wordFloors') -Default $null } else { $null }); Where = 'the profile''s wordFloors' }
        )) {
            if ($null -eq $pair.Node) { continue }
            $v = Get-GateProp -Object $pair.Node -Names $Names -Default $null
            if ($null -ne $v) { return [pscustomobject]@{ Value = [int]$v; From = $pair.Where } }
        }
        return $null
    }

    $tf = Resolve-ScFloor -Explicit $ExplicitTopicFloor   -Value $TopicWordFloor   -Names @('topic', 'topicWords', 'topicProse') -Label 'topic'
    $sf = Resolve-ScFloor -Explicit $ExplicitSubjectFloor -Value $SubjectWordFloor -Names @('underpinningKnowledge', 'subject', 'subjectWords') -Label 'underpinning knowledge'
    if ($null -eq $tf -or $null -eq $sf) {
        $missing = @()
        if ($null -eq $tf) { $missing += 'wordFloors.topic' }
        if ($null -eq $sf) { $missing += 'wordFloors.underpinningKnowledge' }
        throw ("{0}: no floor declared for {1}. Declare it in contract.json wordFloors or in the profile passed on -Profile - gates.md section 3 states the house values, but a blocking rule measured against a number this gate typed in for itself is a rule nobody signed." -f $GATE, ($missing -join ' and '))
    }

    # ---- what counts
    $counted = Resolve-ScCountedFields -Contract $contract
    $countedKeys = @($counted.Fields.Keys)

    # ---- walk the spine
    $files = @(Get-GateSpineFiles -BuildDir $BuildDir -SpineDir $SpineDir)
    if ($files.Count -eq 0) { throw ("{0}: the spine holds no authored file. There is nothing to measure, which is not a pass." -f $GATE) }

    $subs = @{}
    $topics = @{}
    $allPaths = @{}
    $excludedWords = @{}
    $citedRefs = @{}
    $preparedBy = @{}
    $preparedByKey = @{}
    $promptWords = 0

    #  The whole spine is walked; NOTHING is skipped for the field census, so
    #  the excluded list below is the real complement of the counted list.
    foreach ($f in $files) {
        $j = Get-GateJson -Path $f.FullName
        if ($null -eq $j) { $fail.Add((New-ScFinding -Kind 'unreadable' -Where $f.Name -Detail 'the file is empty or does not parse' -File $f.FullName -Field '(whole file)' -Quote '')); continue }

        $isSub = (@($j.PSObject.Properties.Name) -contains 'pc' -and $j.pc)
        $pc = ''
        $topicNo = 0
        if ($isSub) {
            $pc = [string]$j.pc
            $topicNo = [int](Get-GateProp -Object $j -Names @('topic') -Default 0)
        }
        else {
            $topicNo = [int](Get-GateProp -Object $j -Names @('number', 'topic') -Default 0)
        }

        $countedHere = 0
        $ukHere = 0
        foreach ($c in (Get-GateSpineCells -Node $j -File $f.Name -Path '' -Channel '' -Slot '' -Skip $null)) {
            $fp = ($c.Path -replace '\[\d+\]', '')
            if (-not $allPaths.ContainsKey($fp)) { $allPaths[$fp] = 0 }
            $w = Measure-ScWords $c.Text
            $allPaths[$fp] += $w

            if ($countedKeys -contains $fp) {
                $countedHere += $w
                if ($fp -eq 'underpinningKnowledge') { $ukHere += $w }
            }
            else {
                if (-not $excludedWords.ContainsKey($fp)) { $excludedWords[$fp] = 0 }
                $excludedWords[$fp] += $w
                if ($fp -match '(^|\.)prompt$') { $promptWords += $w }
            }
        }

        if ($isSub) {
            $subs[$pc] = [pscustomobject]@{ Pc = $pc; File = $f.Name; FilePath = $f.FullName; Topic = $topicNo; Counted = $countedHere; Uk = $ukHere }
            $linkRefs = @()
            $link = Get-GateProp -Object $j -Names @('assessmentLink') -Default $null
            if ($null -ne $link) { $linkRefs = @(Get-GateProp -Object $link -Names @('refs') -Default @()) }
            foreach ($r in $linkRefs) {
                $rs = "$r".Trim()
                if (-not $rs) { continue }
                if (-not $preparedBy.ContainsKey($rs)) { $preparedBy[$rs] = New-Object System.Collections.Generic.List[string] }
                $preparedBy[$rs].Add($pc)
                #  P1-01. Direction one used to compare this RAW string against
                #  a reference the harvester had formatted, so 'Task 11(a)' on
                #  the spine and 'Task 11 (a)' in the pack were two different
                #  questions. Both sides carry the same key from here on.
                $rk = Get-ScRefKey $rs
                if (-not $preparedByKey.ContainsKey($rk)) { $preparedByKey[$rk] = New-Object System.Collections.Generic.List[string] }
                $preparedByKey[$rk].Add($pc)
            }
        }
        else {
            $topics[$topicNo] = [pscustomobject]@{ Topic = $topicNo; File = $f.Name; FilePath = $f.FullName; Counted = $countedHere; Title = [string](Get-GateProp -Object $j -Names @('title') -Default '') }
        }
    }

    # ---- THE ONE COMPILED REFERENCE REGEX, read from the contract or nothing
    #      P1-01. There is no built fallback. The retired one composed a
    #      grammar out of the register's label words - '\b(?:Task|Observation)
    #      \s?(\d+)\s?(\([a-z]\))?' - which cannot see an observation ITEM at
    #      all, so on the reference build it was a guessed grammar sitting
    #      under a blocking rule. A guessed grammar is what manufactured the
    #      findings; a blocking rule whose input is absent goes to PARTIAL and
    #      the gate exits naming the key, which is a work order.
    $refConv = $null
    if ($null -ne $contract) { $refConv = Get-GateProp -Object $contract -Names @('referenceConvention') -Default $null }
    $questionRx = ''
    if ($null -ne $refConv) { $questionRx = [string](Get-GateProp -Object $refConv -Names @('questionPattern') -Default '') }
    $labels = Get-ScReferenceLabels -Contract $contract

    $rx = $null
    if ($questionRx) {
        try { $rx = New-Object System.Text.RegularExpressions.Regex($questionRx, [System.Text.RegularExpressions.RegexOptions]::None) }
        catch {
            $rx = $null
            $partial.Add(("question cross-reference: contract.referenceConvention.questionPattern is not a usable regular expression - {0}. Both directions of the cross-reference matched nothing." -f $_.Exception.Message))
        }
    }
    else {
        $partial.Add('question cross-reference: contract.referenceConvention.questionPattern is not declared, and this gate does not build one. Both directions of the cross-reference matched nothing, in either vocabulary. Declare the pattern with its two capture groups (number, then subpart) in contract.json referenceConvention.questionPattern.')
    }

    #  The task-level signpost escape of direction two, and whether it is
    #  switched on. Not declared means not allowed, which is the answer that
    #  cannot silence a finding.
    $allowSignpost = $false
    $allowSignpostFrom = 'not declared, so a task-level citation must appear in the pack exactly as it is cited'
    foreach ($node in @($refConv, $contract)) {
        if ($null -eq $node) { continue }
        $v = Get-GateProp -Object $node -Names @('allowTaskLevelSignpost') -Default $null
        if ($null -eq $v) { continue }
        $allowSignpost = [bool]$v
        $allowSignpostFrom = ("declared: allowTaskLevelSignpost = {0}" -f $v)
        break
    }

    $regPath = $Register
    if (-not $regPath) { $regPath = Join-Path $BuildDir 'withhold-register.json' }
    $regJson = $null
    if (Test-Path -LiteralPath $regPath) { $regJson = Get-GateJson -Path $regPath }
    $docPatterns = Get-ScDocumentPatterns -RegJson $regJson

    # ---- every reference the guide or the deck cites, from every channel,
    #      read with THE SAME regex object and keyed with THE SAME key
    $citedByKey = [ordered]@{}
    if ($null -ne $rx) {
        foreach ($f in $files) {
            $j = Get-GateJson -Path $f.FullName
            if ($null -eq $j) { continue }
            foreach ($c in (Get-GateSpineCells -Node $j -File $f.Name -Path '' -Channel '' -Slot '' -Skip $null)) {
                foreach ($m in $rx.Matches([string]$c.Text)) {
                    $r = ($m.Value -replace '\s+', ' ').Trim()
                    if (-not $r) { continue }
                    if (-not $citedRefs.ContainsKey($r)) { $citedRefs[$r] = 0 }
                    $citedRefs[$r]++
                    $k = Get-ScRefKey $r
                    if ($citedByKey.Contains($k)) { $citedByKey[$k].Occurrences++ ; continue }
                    $citedByKey[$k] = [pscustomobject]@{
                        Ref = $r; Key = $k; Occurrences = 1
                        File = $c.File; FilePath = $f.FullName; Field = $c.Path
                        Anchor = ("{0} {1}" -f $c.File, $c.Path)
                    }
                }
            }
        }
    }

    # ---- the pack's own references, from the corpus, with THE SAME regex
    $pack = $null
    $corpusResolved = ''
    $corpusErr = ''
    if ($null -ne $rx) {
        try {
            $corpusResolved = Get-GateCorpusDir -BuildDir $BuildDir -CorpusDir $CorpusDir
            $corpus = Get-GateCorpusDocs -CorpusDir $corpusResolved -BuildDir $BuildDir
            if (@($corpus.Learner).Count -eq 0) { throw 'the corpus contains no learner-facing document, so the pack has no questions to read' }
            if ($docPatterns.Count -eq 0) { throw ("no document reference patterns. scripts\New-WithholdRegister.ps1 writes them into {0}; without them a bare 'Task 5' cannot be resolved to a document and the reconciliation would compare two different vocabularies" -f (Split-Path $regPath -Leaf)) }
            $pack = Get-ScPackReferences -Corpus $corpus -DocPatterns $docPatterns -Rx $rx -Labels $labels
            if (@($pack.Refs).Count -eq 0) { throw 'the corpus scan found no complete question reference in any learner-facing document; a reconciliation against an empty pack passes by checking nothing' }
        }
        catch {
            $pack = $null
            $corpusErr = $_.Exception.Message
            $partial.Add(("question cross-reference: the pack's questions could not be derived from the corpus - {0}" -f $corpusErr))
        }
    }

    # ---- floors
    $topicRows = New-Object System.Collections.Generic.List[object]
    $ukRows = New-Object System.Collections.Generic.List[object]

    foreach ($pc in ($subs.Keys | Sort-Object)) {
        $s = $subs[$pc]
        $ukRows.Add([pscustomobject]@{ pc = $pc; file = $s.File; words = $s.Uk; floor = $sf.Value; ok = ($s.Uk -ge $sf.Value) })
        if ($s.Uk -lt $sf.Value) {
            $fail.Add((New-ScFinding -Kind 'underpinning knowledge below floor' -Where ("{0} ({1})" -f $pc, $s.File) `
                -Detail ("{0} words of counted prose against a floor of {1}, short by {2}" -f $s.Uk, $sf.Value, ($sf.Value - $s.Uk)) `
                -File ([string]$s.FilePath) -Field 'underpinningKnowledge' -Quote $pc))
        }
    }

    #  Topic membership: the contract's topic list where it declares one, else
    #  the topic number each sub-section file carries.
    $topicMembers = @{}
    $membershipFrom = 'each sub-section file''s own topic number'
    if ($null -ne $contract) {
        $ct = @(Get-GateProp -Object $contract -Names @('topics') -Default @())
        if ($ct.Count -gt 0) {
            foreach ($t in $ct) {
                $n = [int](Get-GateProp -Object $t -Names @('n', 'number') -Default 0)
                if ($n -le 0) { continue }
                $topicMembers[$n] = @(Get-GateProp -Object $t -Names @('pcs', 'subSections') -Default @()) | ForEach-Object { "$_" }
            }
            $membershipFrom = 'contract.json topics[].pcs'
        }
    }
    if ($topicMembers.Count -eq 0) {
        foreach ($pc in $subs.Keys) {
            $n = $subs[$pc].Topic
            if ($n -le 0) { continue }
            if (-not $topicMembers.ContainsKey($n)) { $topicMembers[$n] = @() }
            $topicMembers[$n] = @($topicMembers[$n] + $pc)
        }
    }

    foreach ($n in ($topicMembers.Keys | Sort-Object)) {
        $w = 0
        if ($topics.ContainsKey($n)) { $w += $topics[$n].Counted }
        $missingSubs = New-Object System.Collections.Generic.List[string]
        foreach ($pc in @($topicMembers[$n])) {
            if ($subs.ContainsKey($pc)) { $w += $subs[$pc].Counted } else { $missingSubs.Add($pc) }
        }
        $topicRows.Add([pscustomobject]@{ topic = $n; words = $w; floor = $tf.Value; subSections = @($topicMembers[$n]); missing = $missingSubs.ToArray(); ok = ($w -ge $tf.Value) })
        $topicFile = ''
        $topicQuote = ''
        if ($topics.ContainsKey($n)) { $topicFile = [string]$topics[$n].FilePath; $topicQuote = [string]$topics[$n].Title }
        if ($missingSubs.Count -gt 0) {
            $fail.Add((New-ScFinding -Kind 'sub-section missing from the spine' -Where ("topic {0}" -f $n) `
                -Detail ("the topic list names {0}, which the spine does not carry, so its words could not be counted" -f ($missingSubs.ToArray() -join ', ')) `
                -File 'contract.json' -Field ('topics[] for topic ' + $n) -Quote (@($missingSubs.ToArray())[0])))
        }
        if ($w -lt $tf.Value) {
            $fail.Add((New-ScFinding -Kind 'topic below word floor' -Where ("topic {0}" -f $n) `
                -Detail ("{0} words of counted prose against a floor of {1}, short by {2}" -f $w, $tf.Value, ($tf.Value - $w)) `
                -File $topicFile -Field 'the counted prose of this topic and its sub-sections' -Quote $topicQuote))
        }
    }

    # ---- the two-way cross-reference
    $preparedNowhere = New-Object System.Collections.Generic.List[object]
    $invented = New-Object System.Collections.Generic.List[object]
    $preparedTwice = New-Object System.Collections.Generic.List[object]

    $signpostsAllowed = New-Object System.Collections.Generic.List[object]
    if ($null -ne $pack -and $null -ne $rx) {
        #  ONE SET, ONE KEY. Direction two asks whether the pack CONTAINS the
        #  reference, so it is answered against everything the pack contains -
        #  questions and the pack's own task-level signposts alike. Direction
        #  one asks what a sub-section must PREPARE, and nothing prepares a
        #  signpost, so it runs over the questions only. The difference is the
        #  contract's grammar, read in Test-ScRefIsComplete.
        $packAll = @{}
        foreach ($r in @($pack.All)) { $packAll[$r.Key] = $r }

        #  Direction one: every question in the pack is prepared somewhere.
        foreach ($r in @($pack.Refs)) {
            if ($preparedByKey.ContainsKey($r.Key)) { continue }
            $preparedNowhere.Add([pscustomobject]@{ ref = $r.Ref; document = $r.Document; kind = $r.Kind; line = $r.Line; harvestedBy = $r.HarvestedBy })
            $fail.Add((New-ScFinding -Kind 'prepared nowhere' -Where $r.Ref `
                -Detail ("the pack contains it ({0}, line {1}, harvested by the {2}) and no sub-section prepares it - a coverage gap" -f $r.Document, $r.Line, $r.HarvestedBy) `
                -File ([string]$r.DocumentPath) -Field ('corpus text, line ' + $r.Line) -Quote $r.Quote))
        }

        #  Direction two: every reference the guide or the deck cites is one
        #  the pack contains.
        foreach ($k in @($citedByKey.Keys)) {
            if ($packAll.ContainsKey($k)) { continue }
            $c = $citedByKey[$k]

            #  THE TASK-LEVEL SIGNPOST ESCAPE. A citation that names a task
            #  without naming a part inside it may be satisfied by a part of
            #  that task existing in the pack - but ONLY where the build has
            #  declared allowTaskLevelSignpost, and ONLY on a boundary that a
            #  digit cannot cross. The retired escape used StartsWith, so a
            #  cited 'Task 1' was satisfied by a pack holding nothing but
            #  'Task 12(a)': the arm that catches the most damaging defect
            #  this document type can ship silenced itself on a prefix.
            $matchedSignpost = ''
            if ($allowSignpost -and -not (Test-ScRefIsComplete -Value $c.Ref -Labels $labels)) {
                $anchored = New-Object System.Text.RegularExpressions.Regex ('^' + [regex]::Escape($k) + '(?!\d)')
                foreach ($pk in $packAll.Keys) {
                    if ($anchored.IsMatch($pk)) { $matchedSignpost = $packAll[$pk].Ref; break }
                }
            }
            if ($matchedSignpost) {
                $signpostsAllowed.Add([pscustomobject]@{ ref = $c.Ref; satisfiedBy = $matchedSignpost; occurrences = $c.Occurrences; firstSeen = $c.Anchor })
                continue
            }

            $invented.Add([pscustomobject]@{ ref = $c.Ref; occurrences = $c.Occurrences; firstSeen = $c.Anchor })
            $fail.Add((New-ScFinding -Kind 'invented reference' -Where $c.Ref `
                -Detail ("cited {0} time(s), first at {1}; the pack does not contain it - a learner would revise for a question that is not on the paper" -f $c.Occurrences, $c.Anchor) `
                -File ([string]$c.FilePath) -Field $c.Field -Quote $c.Ref))
        }

        foreach ($k in ($preparedBy.Keys | Sort-Object)) {
            $homes = @($preparedBy[$k] | Sort-Object -Unique)
            if ($homes.Count -gt 1) { $preparedTwice.Add([pscustomobject]@{ ref = $k; preparedIn = $homes }) }
        }
        if ($preparedTwice.Count -gt 0) {
            $info.Add(("{0} reference(s) are prepared in more than one sub-section; 'prepared exactly once' is Test-Spine's rule and is reported here, not decided here" -f $preparedTwice.Count))
        }
        $info.Add(("cross-reference: {0} question(s) and {1} task-level signpost(s) in the pack, {2} prepared by the spine, {3} distinct reference(s) cited across every channel, all keyed by one normalisation" -f @($pack.Refs).Count, @($pack.Signposts).Count, $preparedByKey.Count, $citedByKey.Count))
        $info.Add(("task-level signpost escape: {0}{1}" -f $allowSignpostFrom, $(if ($signpostsAllowed.Count) { ("; {0} citation(s) satisfied by it" -f $signpostsAllowed.Count) } else { '' })))
    }

    # ---- the balance arm, only where a tolerance is declared
    $tolerance = $null
    if ($null -ne $contract) {
        $wfn = Get-GateProp -Object $contract -Names @('wordFloors') -Default $null
        if ($null -ne $wfn) { $tolerance = Get-GateProp -Object $wfn -Names @('balanceTolerance') -Default $null }
    }
    $balance = New-Object System.Collections.Generic.List[object]
    if ($null -eq $tolerance) {
        #  P1-01. This was in $notRun, which prints a yellow line and does not
        #  move the exit code: the gate passed green with a blocking rule
        #  switched off by a missing number, which is the shape this whole file
        #  exists to refuse. A blocking rule whose input is absent is PARTIAL,
        #  and PARTIAL exits non-zero unless a caller writes down a reason.
        $partial.Add('topic balance (words per topic against the criteria and knowledge points per topic): no contract.json wordFloors.balanceTolerance is declared, so the tolerance this blocking rule is measured against does not exist and the rule checked nothing. Declare wordFloors.balanceTolerance.')
    }
    else {
        $tol = [double]$tolerance
        $totalW = 0; $totalP = 0
        foreach ($r in $topicRows) {
            $pts = @($topicMembers[$r.topic]).Count
            $totalW += $r.words; $totalP += $pts
        }
        if ($totalP -gt 0 -and $totalW -gt 0) {
            $perPoint = $totalW / $totalP
            foreach ($r in $topicRows) {
                $pts = @($topicMembers[$r.topic]).Count
                if ($pts -le 0) { continue }
                $expected = $perPoint * $pts
                $ratio = $r.words / $expected
                $ok = ($ratio -ge (1 - $tol) -and $ratio -le (1 + $tol))
                $balance.Add([pscustomobject]@{ topic = $r.topic; words = $r.words; points = $pts; expected = [math]::Round($expected, 0); ratio = [math]::Round($ratio, 3); tolerance = $tol; ok = $ok })
                if (-not $ok) {
                    $balFile = ''
                    $balQuote = ''
                    if ($topics.ContainsKey($r.topic)) { $balFile = [string]$topics[$r.topic].FilePath; $balQuote = [string]$topics[$r.topic].Title }
                    $fail.Add((New-ScFinding -Kind 'topic balance outside the declared tolerance' -Where ("topic {0}" -f $r.topic) `
                        -Detail ("{0} words for {1} point(s); {2} expected at the spine average, ratio {3} against a declared tolerance of {4}" -f $r.words, $pts, [math]::Round($expected, 0), [math]::Round($ratio, 3), $tol) `
                        -File $balFile -Field 'the counted prose of this topic and its sub-sections' -Quote $balQuote))
                }
            }
        }
    }

    return [pscustomobject]@{
        BuildDir = $BuildDir
        Floors = [pscustomobject]@{ Topic = $tf; Subject = $sf }
        Counted = $counted
        CountedPaths = $countedKeys
        ExcludedPaths = $excludedWords
        AllPaths = $allPaths
        PromptWords = $promptWords
        Files = $files.Count
        SubSections = $subs.Count
        Topics = $topicRows.ToArray()
        Underpinning = $ukRows.ToArray()
        MembershipFrom = $membershipFrom
        Corpus = $corpusResolved
        CorpusError = $corpusErr
        Pack = $pack
        DocPatterns = $docPatterns
        QuestionPattern = $questionRx
        QuestionPatternFrom = $(if ($questionRx) { 'contract.json referenceConvention.questionPattern' } else { 'NOT DECLARED - contract.json referenceConvention.questionPattern' })
        Labels = $labels
        AllowTaskLevelSignpost = $allowSignpost
        AllowTaskLevelSignpostFrom = $allowSignpostFrom
        SignpostsAllowed = $signpostsAllowed.ToArray()
        Cited = $citedRefs
        CitedByKey = @($citedByKey.Values)
        PreparedBy = $preparedBy
        PreparedByKey = $preparedByKey
        PreparedNowhere = $preparedNowhere.ToArray()
        Invented = $invented.ToArray()
        PreparedTwice = $preparedTwice.ToArray()
        Balance = $balance.ToArray()
        Fail = $fail.ToArray()
        Info = $info.ToArray()
        Partial = $partial.ToArray()
        NotRun = $notRun.ToArray()
    }
}

# ---------------------------------------------------------------------------
# Self-test
# ---------------------------------------------------------------------------

function Write-ScJson {
    param([string] $Path, $Object)
    [System.IO.File]::WriteAllText($Path, ($Object | ConvertTo-Json -Depth 12), (New-Object System.Text.UTF8Encoding($true)))
}

function New-ScContractObject {
    <#  The fixture contract, in one place so a case can drop exactly one
        declaration and prove the refusal that is supposed to follow.  #>
    param(
        [switch] $NoCountedFields,
        [switch] $NoBalanceTolerance,
        [switch] $NoQuestionPattern,
        $AllowTaskLevelSignpost = $null
    )

    $wf = [ordered]@{ topic = 300; underpinningKnowledge = 40 }
    if (-not $NoCountedFields) {
        $wf['countedFields'] = @(
            [ordered]@{ field = 'whatThisMeans';         reason = 'body prose - the criterion in plain words' }
            [ordered]@{ field = 'underpinningKnowledge'; reason = 'body prose - the block the underpinning floor is measured on' }
            [ordered]@{ field = 'regulatoryBasis';       reason = 'body prose - the instruments this criterion engages' }
            [ordered]@{ field = 'howToDoIt.step';        reason = 'body prose - the procedure headings, which render as paragraphs' }
            [ordered]@{ field = 'howToDoIt.detail';      reason = 'body prose - the procedure text' }
            [ordered]@{ field = 'overview';              reason = 'body prose - the topic opening' }
        )
    }
    if (-not $NoBalanceTolerance) { $wf['balanceTolerance'] = 0.95 }

    $rc = [ordered]@{
        task        = 'Fixture Task {n}({part})'
        observation = 'Observation {n}, item {part}'
    }
    if (-not $NoQuestionPattern) {
        #  The reference build's own grammar, in miniature: group 2 admits a
        #  task part OR an observation item range, which is the shape the
        #  retired formatter could not express and therefore collapsed.
        $rc['questionPattern'] = '\b(?:Fixture Task|Observation)\s+(\d+)\s*(\([a-z]\)|,\s*items?\s+\d+(?:\s+to\s+\d+)?)?'
    }
    if ($null -ne $AllowTaskLevelSignpost) { $rc['allowTaskLevelSignpost'] = [bool]$AllowTaskLevelSignpost }

    return [ordered]@{
        build = [ordered]@{ brand = 'FIXTURE' }
        wordFloors = $wf
        topics = @([ordered]@{ n = 1; element = '1'; title = 'Fixture topic'; pcs = @('1.1', '1.2') })
        referenceConvention = $rc
    }
}

function New-ScFixture {
    <#  A build directory with a contract that declares its own small floors and
        its own counted-prose set, a corpus holding a two-part task AND the
        observation item references that broke the reference build, a register
        that declares the document's reference pattern, and a spine that clears
        both floors and reconciles in both directions. Every plant is a
        mutation of THIS.  #>
    param([string] $Root, $Contract = $null, [string] $ToolText = '')

    if (Test-Path -LiteralPath $Root) { Remove-Item -LiteralPath $Root -Recurse -Force }
    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Root 'spine') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Root 'corpus') -Force | Out-Null

    $enc = New-Object System.Text.UTF8Encoding($true)

    #  The pack: one task whose two parts are written on their OWN lines under
    #  the heading (this house style, and the reason a single-line regex alone
    #  cannot see them), and an observation whose items are written beside the
    #  label in a mapping row.
    $tool = @"
Contents
Fixture Task 1 - the fixture task PAGEREF _Toc1 \h 3
Observation 1 - the fixture observation PAGEREF _Toc2 \h 8

Fixture Task 1 - the fixture task
Read the scenario and answer both parts.
(a)
Complete the first grid.
(b)
Complete the second grid.

Observation 1 - the fixture observation
Your assessor observes the run across the whole task.
The mapping matrix records Observation 1, item 3 and Observation 1, items 9 to 11.
"@
    if ($ToolText) { $tool = $ToolText }
    [System.IO.File]::WriteAllText((Join-Path $Root 'corpus\Fixture_Tool.txt'), $tool, $enc)
    [System.IO.File]::WriteAllText((Join-Path $Root 'corpus\Assessor_Guide_Fixture_Tool.txt'), "Assessor benchmark for the fixture task.", $enc)

    if ($null -eq $Contract) { $Contract = New-ScContractObject }
    Write-ScJson -Path (Join-Path $Root 'contract.json') -Object $Contract

    Write-ScJson -Path (Join-Path $Root 'withhold-register.json') -Object ([ordered]@{
        unit = 'FIXTURE'
        documents = [ordered]@{
            Fixture_Tool = [ordered]@{ audience = 'learner'; referencePattern = 'Fixture Task {n}({part})' }
        }
        subSections = [ordered]@{}
    })

    #  Prose long enough to clear the fixture's own floors.
    $ukPara = 'A record exists so a decision taken in the moment can be checked later by somebody who was not there to see it.'
    $bodyPara = 'The worker reads the whole instruction before touching anything, because the cost of starting on the wrong line is paid at the end of the run.'

    $mk = {
        param([string] $Pc, [string[]] $Refs, [int] $UkParas, [int] $BodyParas)
        $uk = @(); for ($i = 0; $i -lt $UkParas; $i++) { $uk += $ukPara }
        $wt = @(); for ($i = 0; $i -lt $BodyParas; $i++) { $wt += $bodyPara }
        return [ordered]@{
            ref = $Pc; pc = $Pc; topic = 1; title = ('Fixture sub-section ' + $Pc)
            whatThisMeans = $wt
            underpinningKnowledge = $uk
            regulatoryBasis = @('The fixture cites no instrument, because it is a fixture.')
            howToDoIt = @([ordered]@{ step = 'Read the task'; detail = 'Read the whole task before starting any part of it.' })
            remember = 'A callout does not count toward the floor and is here to prove that.'
            workedExample = [ordered]@{ intro = 'A worked example is a table and its words are excluded from every count in this gate.'; lines = @('One line of a worked example.') }
            selfCheck = [ordered]@{ questions = @('What does the record show?'); answerGuide = @('Points at the teaching above.') }
            assessmentLink = [ordered]@{ refs = $Refs; wording = ('Prepares you for: ' + ($Refs -join ' and ') + '.') }
            visuals = @([ordered]@{ slot = ($Pc + '.1'); kind = 'Image'; prompt = 'An artwork prompt whose words must never be counted as body prose in any topic total anywhere.'; caption = 'A fixture figure'; alt = 'A fixture figure' })
            slides = @([ordered]@{ layout = 'single'; kind = 'teaching'; headline = 'Fixture slide'; bullets = @('One bullet.'); notes = 'Speaker notes are not body prose.' })
            openQuestions = @(); provenance = @()
        }
    }

    #  The spine writes 'Fixture Task 1(a)' with no space; the pack writes
    #  'Fixture Task 1 (a)'. ONE KEY makes those the same reference. The
    #  observation references are the exact shapes the reference build carries.
    Write-ScJson -Path (Join-Path $Root 'spine\t1_1.1.json') -Object (& $mk '1.1' @('Fixture Task 1(a)', 'Observation 1, items 9 to 11') 3 3)
    Write-ScJson -Path (Join-Path $Root 'spine\t1_1.2.json') -Object (& $mk '1.2' @('Fixture Task 1(b)', 'Observation 1, item 3') 3 3)
    Write-ScJson -Path (Join-Path $Root 'spine\t1_topic.json') -Object ([ordered]@{
        number = 1; element = '1'; title = 'Fixture topic'; elementText = 'Fixture element'
        overview = 'The fixture topic exists so that the topic floor has an overview to count and a file to name.'
        outcomes = @('Understand the fixture.'); summary = @('The fixture is a fixture.')
        slides = @([ordered]@{ layout = 'single'; kind = 'title'; headline = 'Fixture topic'; bullets = @('Fixture'); notes = 'Open the topic.' })
        openQuestions = @(); provenance = @()
    })
    return $Root
}

function Invoke-ScSelfTest {
    param()

    $records = New-Object System.Collections.Generic.List[object]
    function Record {
        param([string] $Name, [bool] $Ok, [string] $Detail)
        $script:ScSelfRecords.Add([pscustomobject]@{ test = $Name; ok = $Ok; detail = $Detail })
        if ($Ok) { Write-Host ("    ok   {0} - {1}" -f $Name, $Detail) -ForegroundColor Green }
        else { Write-Host ("    X    {0} - {1}" -f $Name, $Detail) -ForegroundColor Red }
    }
    $script:ScSelfRecords = $records

    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('scgate_' + [Guid]::NewGuid().ToString('N').Substring(0, 12))
    try {
        Write-Host ''
        Write-Host '  SELF-TEST - every defect is planted, the plant is VERIFIED BY MEASURING THE FIXTURE BACK' -ForegroundColor Cyan
        Write-Host '  before the gate is run on it, and only then is the gate required to catch it.' -ForegroundColor Cyan

        # ---- control
        New-ScFixture -Root $root | Out-Null
        $r0 = Invoke-ScMeasure -BuildDir $root
        $blockers0 = @($r0.Fail).Count
        $t0 = @($r0.Topics | Where-Object { $_.topic -eq 1 })[0]
        Record 'control (clean fixture)' (($blockers0 -eq 0) -and (@($r0.Partial).Count -eq 0)) ("floors {0}/{1} from {2}; topic 1 measures {3} words; {4} pack question(s); {5} blocking finding(s); {6} partial rule(s)" -f $r0.Floors.Topic.Value, $r0.Floors.Subject.Value, $r0.Floors.Topic.From, $(if ($t0) { $t0.words } else { 0 }), @($r0.Pack.Refs).Count, $blockers0, @($r0.Partial).Count)
        Record 'control (pack derived from the corpus with the ONE contract regex)' (@($r0.Pack.Refs).Count -eq 4) ("the corpus scan found {0} question(s): {1}" -f @($r0.Pack.Refs).Count, ((@($r0.Pack.Refs) | ForEach-Object { $_.Ref }) -join ', '))
        Record 'control (counted set is the contract''s, not this file''s)' ($r0.Counted.Source -eq 'contract.json wordFloors.countedFields') ("counted prose field paths came from {0}" -f $r0.Counted.Source)
        Record 'control (prompt text excluded)' ($r0.PromptWords -gt 0 -and ($r0.CountedPaths -notcontains 'visuals.prompt')) ("{0} word(s) of artwork prompt text found on the spine and excluded from every count" -f $r0.PromptWords)

        # ------------------------------------------------------------------
        #  P1-01 PROOF 1 - THE FALSE FINDING THIS CHANGE EXISTS TO KILL.
        #  BEFORE: Format-ScRef formatted 'Observation {n}, item {part}' with an
        #  EMPTY {part}. On the reference build that produced 'Observation 1
        #  item' - a string the pack does not contain and the spine does not
        #  cite - so the gate reported that phantom as a question prepared
        #  nowhere AND reported all eleven genuine observation references as
        #  invented. Twelve blocking findings, all false.
        #  AFTER: the corpus form and the spine form carry ONE key and
        #  reconcile. Both halves are asserted here.
        # ------------------------------------------------------------------
        $obsPattern = 'Observation {n}, item {part}'
        $retired = ($obsPattern.Replace('{n}', '1') -replace '\(\{part\}\)', '' -replace '\{part\}', '').Trim()
        $packKeysNow = @(@($r0.Pack.All) | ForEach-Object { $_.Key })
        Record 'BEFORE (the retired formatter''s collapsed form is not a reference)' `
            (($retired -eq 'Observation 1, item') -and ($packKeysNow -notcontains (Get-ScRefKey $retired))) `
            ("Format-ScRef with an empty {{part}} returned '{0}'; it appears in neither vocabulary now" -f $retired)
        $obsRef = 'Observation 1, items 9 to 11'
        $obsKey = Get-ScRefKey $obsRef
        $inPack = ($packKeysNow -contains $obsKey)
        $inSpine = $r0.PreparedByKey.ContainsKey($obsKey)
        $noFinding = (@($r0.Fail | Where-Object { "$($_.where)" -match 'Observation' }).Count -eq 0)
        Record 'AFTER (corpus "Observation 1, items 9 to 11" and the spine citing it RECONCILE)' `
            ($inPack -and $inSpine -and $noFinding) `
            ("in the pack={0}, prepared on the spine={1}, key '{2}', observation finding(s)={3}" -f $inPack, $inSpine, $obsKey, @($r0.Fail | Where-Object { "$($_.where)" -match 'Observation' }).Count)

        # ---- P1-01 PROOF 2: an observation item the pack does not reach
        New-ScFixture -Root $root | Out-Null
        $f = Join-Path $root 'spine\t1_1.1.json'
        $j = Get-GateJson -Path $f
        $j.assessmentLink.refs = @(@($j.assessmentLink.refs) + 'Observation 1, item 99')
        $j.assessmentLink.wording = 'Prepares you for: Observation 1, item 99.'
        Write-ScJson -Path $f -Object $j
        $probe = Invoke-ScMeasure -BuildDir $root
        $landed = ($probe.CitedByKey | Where-Object { $_.Key -eq (Get-ScRefKey 'Observation 1, item 99') })
        $maxInPack = (@($probe.Pack.Refs | Where-Object { $_.Ref -match 'items? (\d+)' }) | ForEach-Object { [int]([regex]::Matches($_.Ref, '\d+') | Select-Object -Last 1).Value } | Sort-Object | Select-Object -Last 1)
        if (-not $landed) {
            Record 'plant landed: an observation item beyond the pack is cited' $false 'the citation is not among the references the sweep read off the spine; this plant proves nothing'
        }
        else {
            Record 'plant landed: an observation item beyond the pack is cited' $true ("'Observation 1, item 99' is cited on the spine and the pack's observation items stop at {0}" -f $maxInPack)
            $hit = @($probe.Invented | Where-Object { $_.ref -eq 'Observation 1, item 99' })
            Record 'gate fires: an observation item beyond the pack FAILS, naming the reference' ($hit.Count -ge 1) $(if ($hit.Count) { ("invented reference '{0}', first seen at {1}" -f $hit[0].ref, $hit[0].firstSeen) } else { 'the gate did not report it' })

            #  P1-14's contract, already honoured: the finding carries the four
            #  anchored fields and its quote re-finds in the file it names.
            $anchorable = @($probe.Fail | Where-Object { $_.kind -eq 'invented reference' -and $null -ne $_.anchored })
            $ok = $false; $why = 'the finding carries no anchored record'
            if ($anchorable.Count -ge 1 -and (Get-Command Test-GateFindingAnchor -ErrorAction SilentlyContinue)) {
                $ar = Test-GateFindingAnchor -Finding $anchorable[0].anchored -BaseDir $root
                $ok = [bool]$ar.Resolved
                $why = ("verdict '{0}'{1}" -f $ar.Verdict, $(if ($ar.Reason) { ' - ' + $ar.Reason } else { '' }))
            }
            Record 'every cross-reference finding carries a quote that re-finds in the file it names' $ok $why
        }

        # ------------------------------------------------------------------
        #  P1-01 PROOF 3 - THE SIGNPOST ESCAPE MUST NOT SWALLOW A BARE REF.
        #  The retired escape was $k.StartsWith($c), so a cited 'Fixture Task 1'
        #  was satisfied by a pack holding nothing but 'Fixture Task 12(a)'.
        #  The three cases below run with the escape DECLARED ON, so what is
        #  proved is the anchor and not the switch, and then with it undeclared
        #  so the switch is proved too.
        # ------------------------------------------------------------------
        $signpostTool = @"
Fixture Task 12 (a) - the only task in this pack
Complete the grid.
"@
        function New-ScSignpostCase {
            param([string] $Root, [string] $CitedBare, $Allow)
            $ct = New-ScContractObject -AllowTaskLevelSignpost $Allow
            New-ScFixture -Root $Root -Contract $ct -ToolText $signpostTool | Out-Null
            foreach ($pair in @(
                @{ File = 'spine\t1_1.1.json'; Refs = @('Fixture Task 12(a)') },
                @{ File = 'spine\t1_1.2.json'; Refs = @() }
            )) {
                $p = Join-Path $Root $pair.File
                $o = Get-GateJson -Path $p
                $o.assessmentLink.refs = $pair.Refs
                $o.assessmentLink.wording = ('Prepares you for: ' + (@($pair.Refs) -join ' and ') + '.')
                $o.remember = ("This sub-section signposts {0}, with no part named." -f $CitedBare)
                Write-ScJson -Path $p -Object $o
            }
            return (Invoke-ScMeasure -BuildDir $Root)
        }

        $sp = Join-Path $root 'signpost'
        $rA = New-ScSignpostCase -Root $sp -CitedBare 'Fixture Task 1' -Allow $true
        $citedBare = (@($rA.CitedByKey) | Where-Object { $_.Key -eq 'fixturetask1' })
        $packHas12 = (@($rA.Pack.All) | Where-Object { $_.Key -eq 'fixturetask12(a)' })
        if (-not $citedBare -or -not $packHas12) {
            Record 'plant landed: a bare task citation over a pack that only has Task 12(a)' $false ("cited bare={0}, pack has Task 12(a)={1}; this plant proves nothing" -f [bool]$citedBare, [bool]$packHas12)
        }
        else {
            Record 'plant landed: a bare task citation over a pack that only has Task 12(a)' $true ("the spine cites 'Fixture Task 1'; the pack contains only {0}" -f ((@($rA.Pack.All) | ForEach-Object { "'" + $_.Ref + "'" }) -join ', '))
            $hit = @($rA.Invented | Where-Object { $_.ref -eq 'Fixture Task 1' })
            Record 'gate fires: bare ''Fixture Task 1'' is NOT swallowed by ''Fixture Task 12 (a)''' ($hit.Count -ge 1) $(if ($hit.Count) { ("invented reference '{0}' reported with the escape switched ON - the anchor, not the switch, is what refuses it" -f $hit[0].ref) } else { 'the anchored escape swallowed the bare citation, which is the defect this change removes' })
        }

        $sp2 = Join-Path $root 'signpost-ok'
        $rB = New-ScSignpostCase -Root $sp2 -CitedBare 'Fixture Task 12' -Allow $true
        Record 'control: the escape still admits a true signpost when it is declared' `
            ((@($rB.Invented | Where-Object { $_.ref -eq 'Fixture Task 12' }).Count -eq 0) -and (@($rB.SignpostsAllowed | Where-Object { $_.ref -eq 'Fixture Task 12' }).Count -eq 1)) `
            ("'Fixture Task 12' cited bare is satisfied by the pack's 'Fixture Task 12 (a)' and is printed as an allowed signpost")

        $sp3 = Join-Path $root 'signpost-undeclared'
        $rC = New-ScSignpostCase -Root $sp3 -CitedBare 'Fixture Task 12' -Allow $null
        Record 'gate fires: the escape is OFF unless allowTaskLevelSignpost is declared' `
            ((-not $rC.AllowTaskLevelSignpost) -and (@($rC.Invented | Where-Object { $_.ref -eq 'Fixture Task 12' }).Count -eq 1)) `
            ("{0}; the same citation that passed above now fails" -f $rC.AllowTaskLevelSignpostFrom)

        # ---- P1-01: a missing balanceTolerance is PARTIAL, never NOT RUN
        New-ScFixture -Root $root -Contract (New-ScContractObject -NoBalanceTolerance) | Out-Null
        $probe = Invoke-ScMeasure -BuildDir $root
        $inPartial = @($probe.Partial | Where-Object { "$_" -match 'balanceTolerance' }).Count
        $inNotRun = @($probe.NotRun | Where-Object { "$_" -match 'balanceTolerance' }).Count
        Record 'a missing balanceTolerance is PARTIAL, not NOT RUN' (($inPartial -eq 1) -and ($inNotRun -eq 0)) ("partial={0}, notRun={1}; PARTIAL moves the exit code, NOT RUN never did" -f $inPartial, $inNotRun)

        # ---- plant 1: a Topic under the word floor
        New-ScFixture -Root $root | Out-Null
        $f = Join-Path $root 'spine\t1_1.2.json'
        $j = Get-GateJson -Path $f
        $j.whatThisMeans = @('Short.')
        $j.underpinningKnowledge = @(@($j.underpinningKnowledge)[0])
        Write-ScJson -Path $f -Object $j
        $probe = Invoke-ScMeasure -BuildDir $root
        $tRow = @($probe.Topics | Where-Object { $_.topic -eq 1 })[0]
        if ($null -eq $tRow -or $tRow.words -ge $probe.Floors.Topic.Value) {
            Record 'plant landed: Topic under the word floor' $false ("the fixture still measures {0} words against a floor of {1}; this plant proves nothing" -f $(if ($tRow) { $tRow.words } else { -1 }), $probe.Floors.Topic.Value)
        }
        else {
            Record 'plant landed: Topic under the word floor' $true ("the fixture now measures {0} words against a floor of {1}" -f $tRow.words, $probe.Floors.Topic.Value)
            $hit = @($probe.Fail | Where-Object { $_.kind -eq 'topic below word floor' })
            Record 'gate fires: Topic under the word floor' ($hit.Count -ge 1) $(if ($hit.Count) { ("{0}: {1}" -f $hit[0].where, $hit[0].detail) } else { 'the gate did not report the topic floor' })
        }

        # ---- plant 2: an underpinning knowledge block under its floor
        New-ScFixture -Root $root | Out-Null
        $f = Join-Path $root 'spine\t1_1.1.json'
        $j = Get-GateJson -Path $f
        $j.underpinningKnowledge = @('Too short to teach anything at all.')
        Write-ScJson -Path $f -Object $j
        $probe = Invoke-ScMeasure -BuildDir $root
        $uRow = @($probe.Underpinning | Where-Object { $_.pc -eq '1.1' })[0]
        if ($null -eq $uRow -or $uRow.words -ge $probe.Floors.Subject.Value) {
            Record 'plant landed: underpinning block under its floor' $false 'the block still clears its floor; this plant proves nothing'
        }
        else {
            Record 'plant landed: underpinning block under its floor' $true ("1.1 now measures {0} words against a floor of {1}" -f $uRow.words, $probe.Floors.Subject.Value)
            $hit = @($probe.Fail | Where-Object { $_.kind -eq 'underpinning knowledge below floor' })
            Record 'gate fires: underpinning block under its floor' ($hit.Count -ge 1) $(if ($hit.Count) { ("{0}: {1}" -f $hit[0].where, $hit[0].detail) } else { 'the gate did not report the underpinning floor' })
        }

        # ---- plant 3: a cited question absent from the pack
        New-ScFixture -Root $root | Out-Null
        $f = Join-Path $root 'spine\t1_1.1.json'
        $j = Get-GateJson -Path $f
        $j.assessmentLink.refs = @(@($j.assessmentLink.refs) + 'Fixture Task 9(z)')
        $j.assessmentLink.wording = 'Prepares you for: Fixture Task 1(a) and Fixture Task 9(z).'
        Write-ScJson -Path $f -Object $j
        $probe = Invoke-ScMeasure -BuildDir $root
        $landed = $probe.Cited.ContainsKey('Fixture Task 9(z)')
        if (-not $landed) {
            Record 'plant landed: cited question absent from the pack' $false 'the invented citation is not among the references the sweep read off the spine; this plant proves nothing'
        }
        else {
            Record 'plant landed: cited question absent from the pack' $true ("'Fixture Task 9(z)' is cited {0} time(s) on the spine" -f $probe.Cited['Fixture Task 9(z)'])
            $hit = @($probe.Invented | Where-Object { $_.ref -eq 'Fixture Task 9(z)' })
            Record 'gate fires: cited question absent from the pack' ($hit.Count -ge 1) $(if ($hit.Count) { ("invented reference reported, first seen at {0}" -f $hit[0].firstSeen) } else { 'the gate did not report the invented reference' })
        }

        # ---- plant 4: a pack question prepared nowhere
        New-ScFixture -Root $root | Out-Null
        $f = Join-Path $root 'spine\t1_1.2.json'
        $j = Get-GateJson -Path $f
        $j.assessmentLink.refs = @()
        $j.assessmentLink.wording = 'Prepares you for: nothing, which is the defect.'
        Write-ScJson -Path $f -Object $j
        $probe = Invoke-ScMeasure -BuildDir $root
        $bKey = Get-ScRefKey 'Fixture Task 1(b)'
        $stillPrepared = $probe.PreparedByKey.ContainsKey($bKey)
        $stillInPack = (@($probe.Pack.Refs | Where-Object { $_.Key -eq $bKey }).Count -ge 1)
        if ($stillPrepared -or -not $stillInPack) {
            Record 'plant landed: pack question prepared nowhere' $false ("prepared={0}, in the pack={1}; this plant proves nothing" -f $stillPrepared, $stillInPack)
        }
        else {
            Record 'plant landed: pack question prepared nowhere' $true "the pack's 'Fixture Task 1 (b)' still keys to the spine's 'Fixture Task 1(b)' and no sub-section now prepares it"
            $hit = @($probe.PreparedNowhere | Where-Object { (Get-ScRefKey $_.ref) -eq $bKey })
            Record 'gate fires: pack question prepared nowhere' ($hit.Count -ge 1) $(if ($hit.Count) { ("prepared nowhere reported for {0} ({1})" -f $hit[0].ref, $hit[0].document) } else { 'the gate did not report the coverage gap' })

            #  A direction-one finding names a line of the PACK, so its quote
            #  has to re-find there. 'Observation 1 item' - the phantom this
            #  change removed - never could.
            $pnf = @($probe.Fail | Where-Object { $_.kind -eq 'prepared nowhere' -and $null -ne $_.anchored })
            $ok = $false; $why = 'the finding carries no anchored record'
            if ($pnf.Count -ge 1 -and (Get-Command Test-GateFindingAnchor -ErrorAction SilentlyContinue)) {
                $ar = Test-GateFindingAnchor -Finding $pnf[0].anchored -BaseDir $root
                $ok = [bool]$ar.Resolved
                $why = ("verdict '{0}' for quote '{1}'{2}" -f $ar.Verdict, $ar.Quote, $(if ($ar.Reason) { ' - ' + $ar.Reason } else { '' }))
            }
            Record 'a prepared-nowhere finding re-finds its quote in the pack document it names' $ok $why
        }

        # ---- the missing-input rule
        New-ScFixture -Root $root | Out-Null
        Remove-Item -LiteralPath (Join-Path $root 'contract.json') -Force
        $threw = $false
        $msg = ''
        try { Invoke-ScMeasure -BuildDir $root | Out-Null } catch { $threw = $true; $msg = $_.Exception.Message }
        Record 'a blocking rule whose floor is not declared FAILS and names the input' $threw $(if ($threw) { ($msg -split "`n")[0] } else { 'the gate ran to a verdict with no declared floor, which is a pass over a rule nobody signed' })

        # ---- THE ARM ROSTER, proved through the EXIT CODE a runner reads.
        #      These run THIS script as a child: the roster and its refusals
        #      live at the top level, so an in-process call to Invoke-ScMeasure
        #      would not exercise them at all.
        function Invoke-ScChild {
            param([string] $Build, [int] $Expect, [string[]] $Names, [string] $What)
            $out = ''
            try { $out = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:ScSelf -BuildDir $Build -OutPath (Join-Path $Build 'sc-out.json') -Quiet 2>&1 | Out-String -Width 4096) }
            catch { $out = "$($_.Exception.Message)" }
            $code = $LASTEXITCODE
            $missing = @($Names | Where-Object { $out.IndexOf($_, [System.StringComparison]::OrdinalIgnoreCase) -lt 0 })
            Record $What (($code -eq $Expect) -and ($missing.Count -eq 0)) $(if (($code -eq $Expect) -and ($missing.Count -eq 0)) { ("exit {0}, naming {1}" -f $code, (($Names | ForEach-Object { "'" + $_ + "'" }) -join ' and ')) } else { ("exit {0} (wanted {1}); not named: {2}" -f $code, $Expect, $(if ($missing.Count) { ($missing -join ' | ') } else { 'nothing' })) })
        }

        $ctl = Join-Path $root 'roster-control'
        New-ScFixture -Root $ctl | Out-Null
        Invoke-ScChild -Build $ctl -Expect 0 -Names @('ARMS: ', 'counted-prose|true|ran', 'word-floors|true|ran', 'pack-questions|true|ran') -What 'the clean fixture passes with every blocking arm ran'

        #  Starve the pack-questions arm: the same fixture with its corpus
        #  removed. Both directions of the cross-reference then compare against
        #  nothing, which is the shape that printed a green line.
        $starved = Join-Path $root 'roster-starved'
        New-ScFixture -Root $starved | Out-Null
        $corpusDir = Join-Path $starved 'corpus'
        if (Test-Path -LiteralPath $corpusDir) { Remove-Item -LiteralPath $corpusDir -Recurse -Force }
        if (Test-Path -LiteralPath $corpusDir) { Record 'plant landed: the fixture corpus is gone' $false 'the corpus directory could not be removed, so this case proves nothing' }
        else {
            Record 'plant landed: the fixture corpus is gone' $true 'the pack question set can no longer be derived from anything'
            Invoke-ScChild -Build $starved -Expect 2 -Names @('CHECK-SET EMPTY', 'question(s) in the pack') -What 'a build whose corpus yields no pack question REFUSES naming the corpus'
        }

        # ---- P1-01 REFUSALS, proved through the exit code a runner reads
        #      No questionPattern: the arm goes to PARTIAL and the gate exits 2
        #      naming the contract key. It NEVER builds a fallback grammar.
        $noRx = Join-Path $root 'refuse-no-question-pattern'
        New-ScFixture -Root $noRx -Contract (New-ScContractObject -NoQuestionPattern) | Out-Null
        $rNoRx = Invoke-ScMeasure -BuildDir $noRx
        $rxPartial = @($rNoRx.Partial | Where-Object { "$_" -match 'questionPattern' }).Count
        Record 'no questionPattern: the arm is in PARTIAL and no pattern was invented' `
            (($rxPartial -eq 1) -and (-not $rNoRx.QuestionPattern) -and ($null -eq $rNoRx.Pack)) `
            ("partial entries naming questionPattern={0}; pattern resolved='{1}'; pack derived={2}" -f $rxPartial, [string]$rNoRx.QuestionPattern, ($null -ne $rNoRx.Pack))
        Invoke-ScChild -Build $noRx -Expect 2 -Names @('contract.referenceConvention.questionPattern') -What 'a build declaring no questionPattern REFUSES naming contract.referenceConvention.questionPattern'

        #  No counted-field set: the floors would be measured over a field list
        #  this gate typed in for itself.
        $noCf = Join-Path $root 'refuse-no-counted-fields'
        New-ScFixture -Root $noCf -Contract (New-ScContractObject -NoCountedFields) | Out-Null
        Invoke-ScChild -Build $noCf -Expect 2 -Names @('wordFloors.countedFields') -What 'a build declaring no counted-prose field set REFUSES naming wordFloors.countedFields'

        #  A missing balanceTolerance now moves the exit code.
        $noBt = Join-Path $root 'refuse-no-balance-tolerance'
        New-ScFixture -Root $noBt -Contract (New-ScContractObject -NoBalanceTolerance) | Out-Null
        Invoke-ScChild -Build $noBt -Expect 2 -Names @('balanceTolerance', 'blocking rule(s) could not run') -What 'a build declaring no balanceTolerance REFUSES rather than printing NOT RUN over a green pass'

        $failures = @($records | Where-Object { -not $_.ok }).Count
        return [pscustomobject]@{ Failures = $failures; Records = $records.ToArray() }
    }
    finally {
        if ($root -and (Test-Path -LiteralPath $root) -and $root.Length -gt 20) {
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if ($SelfTest -and -not $BuildDir) {
    $st = Invoke-ScSelfTest
    Write-Host ''
    if ($st.Failures -gt 0) {
        Write-Host ("  X {0}: self-test FAILED - {1} of {2} check(s) did not hold." -f $GATE, $st.Failures, @($st.Records).Count) -ForegroundColor Red
        exit 4
    }
    Write-Host ("  {0}: self-test passed - {1} check(s), every plant measured back before the gate was believed." -f $GATE, @($st.Records).Count) -ForegroundColor Green
    exit 0
}

if (-not $BuildDir) { Stop-ScUsage '-BuildDir is required (or run with -SelfTest alone to prove the gate on a fixture).' }
if (-not (Test-Path -LiteralPath $BuildDir)) { Stop-ScUsage ("build directory not found: {0}" -f $BuildDir) }
if (-not $OutPath) { $OutPath = Join-Path $BuildDir 'spine-counts.json' }

$selfTestFailures = 0
$selfTestRecords = @()
if ($SelfTest) {
    $st = Invoke-ScSelfTest
    $selfTestFailures = $st.Failures
    $selfTestRecords = $st.Records
}

$result = $null
try {
    $result = Invoke-ScMeasure -BuildDir $BuildDir -SpineDir $SpineDir -CorpusDir $CorpusDir -Register $Register -Profile $Profile `
        -TopicWordFloor $TopicWordFloor -SubjectWordFloor $SubjectWordFloor `
        -ExplicitTopicFloor ($PSBoundParameters.ContainsKey('TopicWordFloor')) `
        -ExplicitSubjectFloor ($PSBoundParameters.ContainsKey('SubjectWordFloor'))
}
catch {
    Stop-ScUsage $_.Exception.Message
}

# ---------------------------------------------------------------------------
# The arm roster (P0-09). The reference-regex rewrite is P1-01's; what changes
# here is only that a starved arm can no longer print a green line. The
# check-set lines print quiet or not - the band runs every member quiet, and a
# blocking check-set computed only when the gate is talkative never fires.
# ---------------------------------------------------------------------------

$scNa = @{}
try {
    foreach ($arm in @('counted-prose', 'pack-questions')) {
        $r = Get-GateDeclaredNa -BuildDir $BuildDir -Gate $GATE -Arm $arm
        if ($r) { $scNa[$arm] = $r }
    }
}
catch { Stop-ScUsage $_.Exception.Message }

Reset-GateArmRoster
Register-GateArm -Name 'spine-files' -Blocking
Register-GateArm -Name 'counted-prose' -Blocking:(-not $scNa.ContainsKey('counted-prose'))
Register-GateArm -Name 'word-floors' -Blocking
Register-GateArm -Name 'pack-questions' -Blocking:(-not ($scNa.ContainsKey('pack-questions') -or $AllowPartial))

$scRoster = @()
try {
    Write-GateCheckSet -What 'spine file(s) measured' -Count $result.Files -DerivedFrom 'the build spine' -Blocking -Input ('the spine under {0}' -f $BuildDir)
    Complete-GateArm -Name 'spine-files' -State 'ran' -Size $result.Files

    if ($scNa.ContainsKey('counted-prose')) { Complete-GateArm -Name 'counted-prose' -State 'declared-n-a' -Reason $scNa['counted-prose'] }
    else {
        Write-GateCheckSet -What 'counted prose field path(s)' -Count @($result.CountedPaths).Count -DerivedFrom $result.Counted.Source -Blocking -Input ('contract.json wordFloors.countedFields: not one prose field path was declared, so every word floor below would be measured against nothing')
        Complete-GateArm -Name 'counted-prose' -State 'ran' -Size @($result.CountedPaths).Count
    }

    $floorBlocks = (@($result.Topics).Count + @($result.Underpinning).Count)
    Write-GateCheckSet -What 'block(s) measured against a word floor (topics plus underpinning-knowledge blocks)' -Count $floorBlocks -DerivedFrom 'the contract topic membership and the numbered sub-sections on the spine' -Blocking -Input ('the spine under ' + $BuildDir + ': no topic and no underpinning-knowledge block could be identified, so both floors were applied to nothing')
    Complete-GateArm -Name 'word-floors' -State 'ran' -Size $floorBlocks -Findings (@($result.Topics | Where-Object { -not $_.ok }).Count + @($result.Underpinning | Where-Object { -not $_.ok }).Count)

    if ($scNa.ContainsKey('pack-questions')) { Complete-GateArm -Name 'pack-questions' -State 'declared-n-a' -Reason $scNa['pack-questions'] }
    elseif ($null -ne $result.Pack) {
        Write-GateCheckSet -What 'question(s) in the pack' -Count @($result.Pack.Refs).Count -DerivedFrom ("the pack's own extracted text: " + ((@($result.Pack.Scanned)) -join '; ')) -Blocking:(-not $AllowPartial) -Input ('the corpus at ' + [string]$result.Corpus + ': not one question reference could be read out of the pack text with the pattern ' + $(if ($result.QuestionPattern) { $result.QuestionPattern } else { '(none resolved)' }) + ', so BOTH directions of the cross-reference compared against nothing')
        Complete-GateArm -Name 'pack-questions' -State 'ran' -Size @($result.Pack.Refs).Count -Findings (@($result.PreparedNowhere).Count + @($result.Invented).Count)
    }
    else {
        $pqInput = 'the corpus: ' + $(if ($result.CorpusError) { [string]$result.CorpusError } else { 'no corpus was read' }) + ' - the two-way question cross-reference compared nothing'
        if (-not $result.QuestionPattern) { $pqInput = 'contract.referenceConvention.questionPattern is not declared, and this gate builds no fallback pattern - the two-way question cross-reference compared nothing in either direction' }
        Write-GateCheckSet -What 'question(s) in the pack' -Count 0 -DerivedFrom 'the corpus, which yielded no pack question set' -Blocking:(-not $AllowPartial) -Input $pqInput
        Complete-GateArm -Name 'pack-questions' -State 'empty'
    }

    Assert-GateArmsComplete
    $scRoster = Write-GateArmRoster
}
catch {
    $msg = $_.Exception.Message
    if ($msg -match '^(CHECK-SET EMPTY|ARMS INCOMPLETE)') {
        Write-Host ("  X {0} REFUSED - {1}" -f $GATE, $msg) -ForegroundColor Red
        [void](Write-GateArmRoster)
        exit 2
    }
    Stop-ScUsage $msg
}

if (-not $Quiet) {
    Write-Host ''
    Write-Host 'SPINE-MEASURED COUNTS - word floors and the two-way question cross-reference' -ForegroundColor Cyan
    Write-Host '  This does NOT replace the Stage 4 render-side gates in gates.md sections 3 and 7. It moves' -ForegroundColor DarkGray
    Write-Host '  FIRST DETECTION earlier, onto a surface where prompt text and body prose are separate fields.' -ForegroundColor DarkGray
    Write-Host ("  floors: topic {0} ({1}); underpinning knowledge {2} ({3})" -f $result.Floors.Topic.Value, $result.Floors.Topic.From, $result.Floors.Subject.Value, $result.Floors.Subject.From) -ForegroundColor DarkGray
    foreach ($k in @($result.CountedPaths)) { Write-Host ("      counted:  {0} - {1}" -f $k, $result.Counted.Fields[$k]) -ForegroundColor DarkGray }
    $exKeys = @($result.ExcludedPaths.Keys | Sort-Object)
    Write-Host ("  excluded, as the complement of the counted set over every field path on the spine: {0} path(s)" -f $exKeys.Count) -ForegroundColor DarkGray
    Write-Host ("      {0}" -f ($exKeys -join ', ')) -ForegroundColor DarkGray
    Write-Host ("      of which artwork prompt text: {0} word(s), never counted as body prose" -f $result.PromptWords) -ForegroundColor DarkGray
    Write-Host ("  spine: {0} file(s), {1} sub-section(s); topic membership from {2}" -f $result.Files, $result.SubSections, $result.MembershipFrom) -ForegroundColor DarkGray
    if ($result.Corpus) {
        Write-Host ("  corpus: {0}" -f $result.Corpus) -ForegroundColor DarkGray
        if ($null -ne $result.Pack) {
            foreach ($s in @($result.Pack.Skipped)) { Write-Host ("      ! learner document not scanned - no reference pattern declared for it: {0}" -f $s) -ForegroundColor Yellow }
        }
    }
    Write-Host ("  reference pattern (the ONE regex, both directions): {0}" -f $(if ($result.QuestionPattern) { $result.QuestionPattern } else { 'NOT DECLARED - contract.json referenceConvention.questionPattern' })) -ForegroundColor DarkGray
    if ($null -ne $result.Pack) {
        Write-Host ("      pack: {0} question(s) plus {1} task-level signpost(s); {2} contents line(s) skipped" -f @($result.Pack.Refs).Count, @($result.Pack.Signposts).Count, $result.Pack.TocLinesSkipped) -ForegroundColor DarkGray
    }
    Write-Host ("      task-level signpost escape: {0}" -f $result.AllowTaskLevelSignpostFrom) -ForegroundColor DarkGray
    foreach ($sp in @($result.SignpostsAllowed)) {
        Write-Host ("      signpost allowed: '{0}' satisfied by the pack's '{1}' ({2} citation(s), first at {3})" -f $sp.ref, $sp.satisfiedBy, $sp.occurrences, $sp.firstSeen) -ForegroundColor DarkGray
    }

    Write-Host ''
    Write-Host ("  {0,-8} {1,8} {2,8}   {3}" -f 'topic', 'words', 'floor', 'sub-sections') -ForegroundColor DarkGray
    foreach ($t in $result.Topics) {
        Write-Host ("  {0,-8} {1,8} {2,8}   {3}" -f $t.topic, $t.words, $t.floor, (@($t.subSections) -join ', ')) -ForegroundColor $(if ($t.ok) { 'Green' } else { 'Red' })
    }
    Write-Host ''
    Write-Host ("  {0,-8} {1,8} {2,8}   {3}" -f 'sub', 'uk words', 'floor', 'file') -ForegroundColor DarkGray
    foreach ($u in $result.Underpinning) {
        Write-Host ("  {0,-8} {1,8} {2,8}   {3}" -f $u.pc, $u.words, $u.floor, $u.file) -ForegroundColor $(if ($u.ok) { 'Green' } else { 'Red' })
    }
    foreach ($i in $result.Info) { Write-Host ("  i {0}" -f $i) -ForegroundColor DarkGray }
    foreach ($n in $result.NotRun) { Write-Host ("  ! NOT RUN - {0}" -f $n) -ForegroundColor Yellow }
}

$out = [pscustomobject]@{
    gate = $GATE
    generated = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
    buildDir = $result.BuildDir
    rule = 'word floors per Topic and per Underpinning knowledge block, and the two-way question cross-reference against corpus-derived references, measured on spine fields; it does not replace the Stage 4 render-side gates'
    floors = [pscustomobject]@{
        topic = $result.Floors.Topic.Value; topicFrom = $result.Floors.Topic.From
        underpinningKnowledge = $result.Floors.Subject.Value; underpinningKnowledgeFrom = $result.Floors.Subject.From
    }
    countedProse = [pscustomobject]@{
        source = $result.Counted.Source
        fields = $result.Counted.Fields
        excludedFieldPaths = $result.ExcludedPaths
        artworkPromptWordsExcluded = $result.PromptWords
    }
    topics = $result.Topics
    underpinningKnowledge = $result.Underpinning
    crossReference = [pscustomobject]@{
        corpus = $result.Corpus
        corpusError = $result.CorpusError
        documentPatterns = $result.DocPatterns
        questionPattern = $result.QuestionPattern
        questionPatternFrom = $result.QuestionPatternFrom
        referenceLabels = $result.Labels
        allowTaskLevelSignpost = $result.AllowTaskLevelSignpost
        allowTaskLevelSignpostFrom = $result.AllowTaskLevelSignpostFrom
        taskLevelSignpostsAllowed = $result.SignpostsAllowed
        packQuestions = $(if ($null -ne $result.Pack) { @($result.Pack.Refs) } else { @() })
        packSignposts = $(if ($null -ne $result.Pack) { @($result.Pack.Signposts) } else { @() })
        preparedNowhere = $result.PreparedNowhere
        inventedReferences = $result.Invented
        preparedInMoreThanOneSubSection = $result.PreparedTwice
    }
    arms = $scRoster
    balance = $result.Balance
    findings = $result.Fail
    info = $result.Info
    partial = $result.Partial
    notRun = $result.NotRun
    selfTest = [pscustomobject]@{ run = [bool]$SelfTest; failures = $selfTestFailures; checks = $selfTestRecords }
}
[System.IO.File]::WriteAllText($OutPath, ($out | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($true)))
if (-not $Quiet) { Write-Host ("  written to {0}" -f $OutPath) -ForegroundColor DarkGray }

Write-Host ''
if ($selfTestFailures -gt 0) {
    Write-Host ("  X {0}: self-test FAILED ({1} check(s)). No result from this gate is believable until it fails on a planted defect." -f $GATE, $selfTestFailures) -ForegroundColor Red
    exit 4
}

$partialCount = @($result.Partial).Count
if ($partialCount -gt 0 -and -not $AllowPartial) {
    Write-Host ("  X {0}: {1} blocking rule(s) could not run, and a blocking rule whose input is absent FAILS rather than passing quietly:" -f $GATE, $partialCount) -ForegroundColor Red
    foreach ($p in $result.Partial) { Write-Host ("      {0}" -f $p) -ForegroundColor Red }
    Write-Host '  Supply the input, or re-run with -AllowPartial and record the reason on the stage ledger.' -ForegroundColor Yellow
    exit 2
}

if (@($result.Fail).Count -eq 0) {
    if ($partialCount -gt 0) {
        Write-Host ("  PARTIAL RUN - {0} blocking rule(s) checked nothing:" -f $partialCount) -ForegroundColor Yellow
        foreach ($p in $result.Partial) { Write-Host ("      {0}" -f $p) -ForegroundColor Yellow }
        Write-Host ("  PASS - PARTIAL, {0} rule(s) not run. Add-StageRecord -Partial <these> -Note '<why>'." -f $partialCount) -ForegroundColor Yellow
        exit 3
    }
    Write-Host '  every topic and every underpinning knowledge block clears its floor, and the question cross-reference reconciles in both directions' -ForegroundColor Green
    exit 0
}

Write-Host ("  X {0} blocking finding(s)" -f @($result.Fail).Count) -ForegroundColor Red
foreach ($f in $result.Fail) {
    Write-Host ("    [{0}] {1}" -f $f.kind, $f.where) -ForegroundColor Yellow
    Write-Host ("      {0}" -f $f.detail) -ForegroundColor DarkGray
}
if ($partialCount -gt 0) {
    Write-Host ("  and {0} blocking rule(s) could not run at all:" -f $partialCount) -ForegroundColor Red
    foreach ($p in $result.Partial) { Write-Host ("      {0}" -f $p) -ForegroundColor Red }
}
Write-Host ''
Write-Host '  Fix on the spine. A shortfall found here costs a re-write; the same shortfall found after Stage 4' -ForegroundColor Yellow
Write-Host '  costs a re-write, a re-render, and every gate and reader downstream of it a second time.' -ForegroundColor Yellow
exit 1
