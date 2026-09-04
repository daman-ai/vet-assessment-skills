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
    grid, visual, slide and identifier excluded. The set is read from the
    contract where the build declares one, and printed either way, together
    with the full list of field paths it excluded, so a reader can see exactly
    what was and was not counted.

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
    Exit 1 a blocking finding, 2 a usage error or a missing blocking input,
    3 a PARTIAL RUN, 4 the self-test failed.
#>

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

    if (@($declared).Count -gt 0) {
        foreach ($e in $declared) {
            if ($e -is [string]) { $out["$e"] = 'declared by the build contract' ; continue }
            $f = Get-GateProp -Object $e -Names @('field', 'name', 'path')
            $r = Get-GateProp -Object $e -Names @('reason', 'why') -Default 'declared by the build contract'
            if ($f) { $out["$f"] = "$r" }
        }
        $src = 'contract.json wordFloors.countedFields'
    }
    else {
        #  The content brief's rule, which is the render gate's exclusion rule
        #  expressed as fields: body prose counts, boxes and tables do not.
        $out['whatThisMeans']         = 'body prose - the criterion in plain words'
        $out['underpinningKnowledge'] = 'body prose - the subject teaching, and the block the 800-word floor is measured on'
        $out['regulatoryBasis']       = 'body prose - the instruments this criterion engages'
        $out['howToDoIt.step']        = 'body prose - the procedure headings, which render as paragraphs, not as a table'
        $out['howToDoIt.detail']      = 'body prose - the procedure text'
        $out['overview']              = 'body prose - the topic opening, counted toward the topic floor'
        $src = "the content brief's counted-prose rule (references\content-agent-brief.md), which is the render gate's not-inside-a-table rule expressed as spine fields"
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

function Split-ScPattern {
    <#  "Knowledge Task {n}({part})" -> prefix 'Knowledge', task word 'Task'.
        The task word is the literal token immediately before {n}; the prefix
        is everything before it. Both come from the pattern, never from a
        literal in this file.  #>
    param([string] $Pattern)

    $i = $Pattern.IndexOf('{n}')
    if ($i -lt 0) { return $null }
    $head = $Pattern.Substring(0, $i).Trim()
    if (-not $head) { return $null }
    $parts = @($head -split '\s+' | Where-Object { $_ })
    if ($parts.Count -eq 0) { return $null }
    $taskWord = $parts[$parts.Count - 1]
    $prefix = ''
    if ($parts.Count -gt 1) { $prefix = ($parts[0..($parts.Count - 2)] -join ' ') }
    return [pscustomobject]@{ Prefix = $prefix; TaskWord = $taskWord; Pattern = $Pattern }
}

function Format-ScRef {
    param([string] $Pattern, [int] $N, [string] $Part)
    $r = $Pattern.Replace('{n}', [string]$N)
    if ($Part) { return $r.Replace('{part}', $Part) }
    #  A pattern with no part supplied loses its bracketed placeholder entirely.
    return ($r -replace '\(\{part\}\)', '' -replace '\{part\}', '').Trim()
}

function Get-ScPackQuestions {
    <#  Every question the pack actually contains, read from the extracted pack
        text. Task numbers come from the document's own task headings and part
        letters from its own part labels; a table-of-contents line is not a
        task heading and is skipped by the field-code marker every extract
        carries.  #>
    param($Corpus, [hashtable] $DocPatterns, [string] $ObservationPattern)

    $refs = New-Object System.Collections.Generic.List[object]
    $scanned = New-Object System.Collections.Generic.List[string]
    $skippedDocs = New-Object System.Collections.Generic.List[string]

    foreach ($d in @($Corpus.Learner)) {
        if (-not $DocPatterns.ContainsKey($d.Name)) { $skippedDocs.Add($d.Name); continue }
        $spec = Split-ScPattern -Pattern $DocPatterns[$d.Name].Pattern
        if ($null -eq $spec) { $skippedDocs.Add($d.Name); continue }
        $scanned.Add(("{0} ({1})" -f $d.Name, $DocPatterns[$d.Name].Pattern))

        $taskRx = '^' + [regex]::Escape($spec.TaskWord) + '\s+(\d+)\b'
        $cur = 0
        $seen = @{}
        foreach ($raw in ($d.Text -split "`r?`n")) {
            $s = "$raw".Trim()
            if (-not $s) { continue }
            if ($s -match $taskRx) {
                #  A contents entry carries the extractor's field code and is
                #  not the task itself.
                if ($s -match 'PAGEREF|\\h\s|TOC \\') { continue }
                $cur = [int]$Matches[1]
                continue
            }
            if ($cur -gt 0 -and $s -match '^\(([a-z])\)') {
                $r = Format-ScRef -Pattern $DocPatterns[$d.Name].Pattern -N $cur -Part $Matches[1]
                if (-not $seen.ContainsKey($r)) {
                    $seen[$r] = $true
                    $refs.Add([pscustomobject]@{ Ref = $r; Document = $d.Name; Kind = 'task' })
                }
            }
        }

        if ($ObservationPattern) {
            $obsSpec = Split-ScPattern -Pattern $ObservationPattern
            if ($null -ne $obsSpec) {
                $obsRx = [regex]::Escape($obsSpec.TaskWord) + '\s*(\d+)'
                $obsSeen = @{}
                foreach ($m in [regex]::Matches($d.Text, $obsRx)) {
                    $n = [int]$m.Groups[1].Value
                    $r = Format-ScRef -Pattern $ObservationPattern -N $n -Part ''
                    if (-not $obsSeen.ContainsKey($r)) {
                        $obsSeen[$r] = $true
                        if (-not (@($refs | Where-Object { $_.Ref -eq $r }).Count)) {
                            $refs.Add([pscustomobject]@{ Ref = $r; Document = $d.Name; Kind = 'observation' })
                        }
                    }
                }
            }
        }
    }
    return [pscustomobject]@{ Refs = $refs.ToArray(); Scanned = $scanned.ToArray(); Skipped = $skippedDocs.ToArray() }
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
    $promptWords = 0

    #  The whole spine is walked; NOTHING is skipped for the field census, so
    #  the excluded list below is the real complement of the counted list.
    foreach ($f in $files) {
        $j = Get-GateJson -Path $f.FullName
        if ($null -eq $j) { $fail.Add([pscustomobject]@{ kind = 'unreadable'; where = $f.Name; detail = 'the file is empty or does not parse' }); continue }

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
            $subs[$pc] = [pscustomobject]@{ Pc = $pc; File = $f.Name; Topic = $topicNo; Counted = $countedHere; Uk = $ukHere }
            $linkRefs = @()
            $link = Get-GateProp -Object $j -Names @('assessmentLink') -Default $null
            if ($null -ne $link) { $linkRefs = @(Get-GateProp -Object $link -Names @('refs') -Default @()) }
            foreach ($r in $linkRefs) {
                $rs = "$r".Trim()
                if (-not $rs) { continue }
                if (-not $preparedBy.ContainsKey($rs)) { $preparedBy[$rs] = New-Object System.Collections.Generic.List[string] }
                $preparedBy[$rs].Add($pc)
            }
        }
        else {
            $topics[$topicNo] = [pscustomobject]@{ Topic = $topicNo; File = $f.Name; Counted = $countedHere }
        }
    }

    # ---- every reference the guide or the deck cites, from every channel
    $refConv = $null
    if ($null -ne $contract) { $refConv = Get-GateProp -Object $contract -Names @('referenceConvention') -Default $null }
    $questionRx = ''
    if ($null -ne $refConv) { $questionRx = [string](Get-GateProp -Object $refConv -Names @('questionPattern') -Default '') }

    $regPath = $Register
    if (-not $regPath) { $regPath = Join-Path $BuildDir 'withhold-register.json' }
    $regJson = $null
    if (Test-Path -LiteralPath $regPath) { $regJson = Get-GateJson -Path $regPath }
    $docPatterns = Get-ScDocumentPatterns -RegJson $regJson

    if (-not $questionRx) {
        #  Build it from the declared reference patterns rather than typing one.
        $words = New-Object System.Collections.Generic.List[string]
        foreach ($k in $docPatterns.Keys) {
            $sp = Split-ScPattern -Pattern $docPatterns[$k].Pattern
            if ($null -ne $sp) {
                $lead = (("{0} {1}" -f $sp.Prefix, $sp.TaskWord)).Trim()
                if (-not $words.Contains($lead)) { $words.Add($lead) }
            }
        }
        if ($null -ne $refConv) {
            $obs = [string](Get-GateProp -Object $refConv -Names @('observation') -Default '')
            $osp = Split-ScPattern -Pattern $obs
            if ($null -ne $osp) { $words.Add((("{0} {1}" -f $osp.Prefix, $osp.TaskWord)).Trim()) }
        }
        if ($words.Count -gt 0) {
            $questionRx = '\b(?:' + ((@($words) | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\s?(\d+)\s?(\([a-z]\))?'
        }
    }

    $citedAnchor = @{}
    if ($questionRx) {
        foreach ($f in $files) {
            $j = Get-GateJson -Path $f.FullName
            if ($null -eq $j) { continue }
            foreach ($c in (Get-GateSpineCells -Node $j -File $f.Name -Path '' -Channel '' -Slot '' -Skip $null)) {
                foreach ($m in [regex]::Matches([string]$c.Text, $questionRx)) {
                    $r = ($m.Value -replace '\s+', ' ').Trim()
                    if (-not $citedRefs.ContainsKey($r)) { $citedRefs[$r] = 0 }
                    $citedRefs[$r]++
                    if (-not $citedAnchor.ContainsKey($r)) { $citedAnchor[$r] = ("{0} {1}" -f $c.File, $c.Path) }
                }
            }
        }
    }
    else {
        $partial.Add('question cross-reference: no reference pattern could be resolved from contract.json referenceConvention.questionPattern or from the register''s document patterns, so nothing was matched in either direction')
    }

    # ---- the pack's own questions, from the corpus
    $pack = $null
    $corpusResolved = ''
    $corpusErr = ''
    try {
        $corpusResolved = Get-GateCorpusDir -BuildDir $BuildDir -CorpusDir $CorpusDir
        $corpus = Get-GateCorpusDocs -CorpusDir $corpusResolved -BuildDir $BuildDir
        if (@($corpus.Learner).Count -eq 0) { throw 'the corpus contains no learner-facing document, so the pack has no questions to read' }
        if ($docPatterns.Count -eq 0) { throw ("no document reference patterns. scripts\New-WithholdRegister.ps1 writes them into {0}; without them a bare 'Task 5' cannot be resolved to a document and the reconciliation would compare two different vocabularies" -f (Split-Path $regPath -Leaf)) }
        $obsPattern = ''
        if ($null -ne $refConv) { $obsPattern = [string](Get-GateProp -Object $refConv -Names @('observation') -Default '') }
        $pack = Get-ScPackQuestions -Corpus $corpus -DocPatterns $docPatterns -ObservationPattern $obsPattern
        if (@($pack.Refs).Count -eq 0) { throw 'the corpus scan found no question in any learner-facing document; a reconciliation against an empty pack passes by checking nothing' }
    }
    catch {
        $corpusErr = $_.Exception.Message
        $partial.Add(("question cross-reference: the pack's questions could not be derived from the corpus - {0}" -f $corpusErr))
    }

    # ---- floors
    $topicRows = New-Object System.Collections.Generic.List[object]
    $ukRows = New-Object System.Collections.Generic.List[object]

    foreach ($pc in ($subs.Keys | Sort-Object)) {
        $s = $subs[$pc]
        $ukRows.Add([pscustomobject]@{ pc = $pc; file = $s.File; words = $s.Uk; floor = $sf.Value; ok = ($s.Uk -ge $sf.Value) })
        if ($s.Uk -lt $sf.Value) {
            $fail.Add([pscustomobject]@{ kind = 'underpinning knowledge below floor'; where = ("{0} ({1})" -f $pc, $s.File); detail = ("{0} words of counted prose against a floor of {1}, short by {2}" -f $s.Uk, $sf.Value, ($sf.Value - $s.Uk)) })
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
        if ($missingSubs.Count -gt 0) {
            $fail.Add([pscustomobject]@{ kind = 'sub-section missing from the spine'; where = ("topic {0}" -f $n); detail = ("the topic list names {0}, which the spine does not carry, so its words could not be counted" -f ($missingSubs.ToArray() -join ', ')) })
        }
        if ($w -lt $tf.Value) {
            $fail.Add([pscustomobject]@{ kind = 'topic below word floor'; where = ("topic {0}" -f $n); detail = ("{0} words of counted prose against a floor of {1}, short by {2}" -f $w, $tf.Value, ($tf.Value - $w)) })
        }
    }

    # ---- the two-way cross-reference
    $preparedNowhere = New-Object System.Collections.Generic.List[object]
    $invented = New-Object System.Collections.Generic.List[object]
    $preparedTwice = New-Object System.Collections.Generic.List[object]

    if ($null -ne $pack -and $questionRx) {
        $packSet = @{}
        foreach ($r in $pack.Refs) { $packSet[$r.Ref] = $r }

        #  Direction one: every question in the pack is prepared somewhere.
        foreach ($r in $pack.Refs) {
            if (-not $preparedBy.ContainsKey($r.Ref)) {
                $preparedNowhere.Add([pscustomobject]@{ ref = $r.Ref; document = $r.Document; kind = $r.Kind })
                $fail.Add([pscustomobject]@{ kind = 'prepared nowhere'; where = $r.Ref; detail = ("the pack contains it ({0}) and no sub-section prepares it - a coverage gap" -f $r.Document) })
            }
        }

        #  Direction two: every question the guide or the deck cites is in the pack.
        foreach ($c in ($citedRefs.Keys | Sort-Object)) {
            if ($packSet.ContainsKey($c)) { continue }
            #  A citation with no part letter is a task-level signpost and is
            #  satisfied by any part of that task existing in the pack.
            $taskLevel = $false
            if ($c -notmatch '\([a-z]\)\s*$') {
                foreach ($k in $packSet.Keys) { if ($k.StartsWith($c)) { $taskLevel = $true; break } }
            }
            if ($taskLevel) { continue }
            $invented.Add([pscustomobject]@{ ref = $c; occurrences = $citedRefs[$c]; firstSeen = $citedAnchor[$c] })
            $fail.Add([pscustomobject]@{ kind = 'invented reference'; where = $c; detail = ("cited {0} time(s), first at {1}; the pack does not contain it - a learner would revise for a question that is not on the paper" -f $citedRefs[$c], $citedAnchor[$c]) })
        }

        foreach ($k in ($preparedBy.Keys | Sort-Object)) {
            $homes = @($preparedBy[$k] | Sort-Object -Unique)
            if ($homes.Count -gt 1) { $preparedTwice.Add([pscustomobject]@{ ref = $k; preparedIn = $homes }) }
        }
        if ($preparedTwice.Count -gt 0) {
            $info.Add(("{0} reference(s) are prepared in more than one sub-section; 'prepared exactly once' is Test-Spine's rule and is reported here, not decided here" -f $preparedTwice.Count))
        }
        $info.Add(("cross-reference: {0} question(s) in the pack, {1} prepared by the spine, {2} distinct reference(s) cited across every channel" -f @($pack.Refs).Count, $preparedBy.Count, $citedRefs.Count))
    }

    # ---- the balance arm, only where a tolerance is declared
    $tolerance = $null
    if ($null -ne $contract) {
        $wfn = Get-GateProp -Object $contract -Names @('wordFloors') -Default $null
        if ($null -ne $wfn) { $tolerance = Get-GateProp -Object $wfn -Names @('balanceTolerance') -Default $null }
    }
    $balance = New-Object System.Collections.Generic.List[object]
    if ($null -eq $tolerance) {
        $notRun.Add('topic balance (words per topic against criteria and knowledge points per topic): no wordFloors.balanceTolerance is declared, so the tolerance this rule is measured against does not exist. This gate''s pass does NOT cover it.')
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
                    $fail.Add([pscustomobject]@{ kind = 'topic balance outside the declared tolerance'; where = ("topic {0}" -f $r.topic); detail = ("{0} words for {1} point(s); {2} expected at the spine average, ratio {3} against a declared tolerance of {4}" -f $r.words, $pts, [math]::Round($expected, 0), [math]::Round($ratio, 3), $tol) })
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
        Cited = $citedRefs
        PreparedBy = $preparedBy
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

function New-ScFixture {
    <#  A build directory with a contract that declares its own small floors, a
        corpus holding a two-part task, a register that declares the document's
        reference pattern, and a spine that clears both floors and reconciles
        in both directions. Every plant is a mutation of THIS.  #>
    param([string] $Root)

    if (Test-Path -LiteralPath $Root) { Remove-Item -LiteralPath $Root -Recurse -Force }
    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Root 'spine') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Root 'corpus') -Force | Out-Null

    $enc = New-Object System.Text.UTF8Encoding($true)

    #  The pack: one task with two parts.
    $tool = @"
Contents
Task 1 - the fixture task PAGEREF _Toc1 \h 3

Task 1 - the fixture task
Read the scenario and answer both parts.
(a)
Complete the first grid.
(b)
Complete the second grid.
Observation 1
The assessor observes the run.
"@
    [System.IO.File]::WriteAllText((Join-Path $Root 'corpus\Fixture_Tool.txt'), $tool, $enc)
    [System.IO.File]::WriteAllText((Join-Path $Root 'corpus\Assessor_Guide_Fixture_Tool.txt'), "Assessor benchmark for the fixture task.", $enc)

    Write-ScJson -Path (Join-Path $Root 'contract.json') -Object ([ordered]@{
        build = [ordered]@{ brand = 'FIXTURE' }
        wordFloors = [ordered]@{ topic = 300; underpinningKnowledge = 40 }
        topics = @([ordered]@{ n = 1; element = '1'; title = 'Fixture topic'; pcs = @('1.1', '1.2') })
        referenceConvention = [ordered]@{
            observation = 'Observation {n}'
            questionPattern = '\b(?:Fixture Task|Observation)\s?(\d+)\s?(\([a-z]\))?'
        }
    })

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

    Write-ScJson -Path (Join-Path $Root 'spine\t1_1.1.json') -Object (& $mk '1.1' @('Fixture Task 1(a)', 'Observation 1') 3 3)
    Write-ScJson -Path (Join-Path $Root 'spine\t1_1.2.json') -Object (& $mk '1.2' @('Fixture Task 1(b)') 3 3)
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
        Record 'control (clean fixture)' ($blockers0 -eq 0) ("floors {0}/{1} from {2}; topic 1 measures {3} words; {4} pack question(s); {5} blocking finding(s)" -f $r0.Floors.Topic.Value, $r0.Floors.Subject.Value, $r0.Floors.Topic.From, $(if ($t0) { $t0.words } else { 0 }), @($r0.Pack.Refs).Count, $blockers0)
        Record 'control (pack derived from the corpus)' (@($r0.Pack.Refs).Count -eq 3) ("the corpus scan found {0} question(s): {1}" -f @($r0.Pack.Refs).Count, ((@($r0.Pack.Refs) | ForEach-Object { $_.Ref }) -join ', '))
        Record 'control (prompt text excluded)' ($r0.PromptWords -gt 0 -and ($r0.CountedPaths -notcontains 'visuals.prompt')) ("{0} word(s) of artwork prompt text found on the spine and excluded from every count" -f $r0.PromptWords)

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
        $stillPrepared = $probe.PreparedBy.ContainsKey('Fixture Task 1(b)')
        $stillInPack = (@($probe.Pack.Refs | Where-Object { $_.Ref -eq 'Fixture Task 1(b)' }).Count -ge 1)
        if ($stillPrepared -or -not $stillInPack) {
            Record 'plant landed: pack question prepared nowhere' $false ("prepared={0}, in the pack={1}; this plant proves nothing" -f $stillPrepared, $stillInPack)
        }
        else {
            Record 'plant landed: pack question prepared nowhere' $true "'Fixture Task 1(b)' is still in the pack and no sub-section now prepares it"
            $hit = @($probe.PreparedNowhere | Where-Object { $_.ref -eq 'Fixture Task 1(b)' })
            Record 'gate fires: pack question prepared nowhere' ($hit.Count -ge 1) $(if ($hit.Count) { ("prepared nowhere reported for {0} ({1})" -f $hit[0].ref, $hit[0].document) } else { 'the gate did not report the coverage gap' })
        }

        # ---- the missing-input rule
        New-ScFixture -Root $root | Out-Null
        Remove-Item -LiteralPath (Join-Path $root 'contract.json') -Force
        $threw = $false
        $msg = ''
        try { Invoke-ScMeasure -BuildDir $root | Out-Null } catch { $threw = $true; $msg = $_.Exception.Message }
        Record 'a blocking rule whose floor is not declared FAILS and names the input' $threw $(if ($threw) { ($msg -split "`n")[0] } else { 'the gate ran to a verdict with no declared floor, which is a pass over a rule nobody signed' })

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

if (-not $Quiet) {
    Write-Host ''
    Write-Host 'SPINE-MEASURED COUNTS - word floors and the two-way question cross-reference' -ForegroundColor Cyan
    Write-Host '  This does NOT replace the Stage 4 render-side gates in gates.md sections 3 and 7. It moves' -ForegroundColor DarkGray
    Write-Host '  FIRST DETECTION earlier, onto a surface where prompt text and body prose are separate fields.' -ForegroundColor DarkGray
    Write-Host ("  floors: topic {0} ({1}); underpinning knowledge {2} ({3})" -f $result.Floors.Topic.Value, $result.Floors.Topic.From, $result.Floors.Subject.Value, $result.Floors.Subject.From) -ForegroundColor DarkGray
    Write-GateCheckSet -What 'counted prose field path(s)' -Count @($result.CountedPaths).Count -DerivedFrom $result.Counted.Source
    foreach ($k in @($result.CountedPaths)) { Write-Host ("      counted:  {0} - {1}" -f $k, $result.Counted.Fields[$k]) -ForegroundColor DarkGray }
    $exKeys = @($result.ExcludedPaths.Keys | Sort-Object)
    Write-Host ("  excluded, as the complement of the counted set over every field path on the spine: {0} path(s)" -f $exKeys.Count) -ForegroundColor DarkGray
    Write-Host ("      {0}" -f ($exKeys -join ', ')) -ForegroundColor DarkGray
    Write-Host ("      of which artwork prompt text: {0} word(s), never counted as body prose" -f $result.PromptWords) -ForegroundColor DarkGray
    Write-Host ("  spine: {0} file(s), {1} sub-section(s); topic membership from {2}" -f $result.Files, $result.SubSections, $result.MembershipFrom) -ForegroundColor DarkGray
    if ($result.Corpus) {
        Write-Host ("  corpus: {0}" -f $result.Corpus) -ForegroundColor DarkGray
        if ($null -ne $result.Pack) {
            Write-GateCheckSet -What 'question(s) in the pack' -Count @($result.Pack.Refs).Count -DerivedFrom ("the pack's own extracted text: " + ((@($result.Pack.Scanned)) -join '; '))
            foreach ($s in @($result.Pack.Skipped)) { Write-Host ("      ! learner document not scanned - no reference pattern declared for it: {0}" -f $s) -ForegroundColor Yellow }
        }
    }
    Write-Host ("  reference pattern: {0}" -f $(if ($result.QuestionPattern) { $result.QuestionPattern } else { 'NONE RESOLVED' })) -ForegroundColor DarkGray

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
        packQuestions = $(if ($null -ne $result.Pack) { @($result.Pack.Refs) } else { @() })
        preparedNowhere = $result.PreparedNowhere
        inventedReferences = $result.Invented
        preparedInMoreThanOneSubSection = $result.PreparedTwice
    }
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
