<#
    Run-Gates.ps1 - every blocking gate of Stage 4 and Stage 7c, from ONE entry
    point, run the same way every time, with every input each gate's blocking
    rules depend on threaded through and PRINTED at the end.

    Promoted from a build-directory copy that hard-coded one unit's file names,
    one pack's content-file map, one brand and one RTO's provider codes. Every
    one of those is now a parameter or a discovery; nothing in this file is a
    literal from any unit, brand, RTO or build.

    WHY THE PARAMETER LIST IS PRINTED. Test-GuideRules and Test-DeckRules now
    FAIL on a missing input, because a blocking rule that sits behind an optional
    parameter prints a clean pass having checked nothing - that is how every
    "figure registry PASS" for a whole build turned out to be the source arm
    only, and how "assessment cross-reference skipped" rode out as an info line
    under a green PASS. This runner is what supplies those inputs, so it prints
    what it supplied. A reader can see nothing was omitted without reading the
    code, and the self-test asserts the list carries every name.

    WHAT IS DERIVED, NEVER TYPED

      pack references   part-level from the contract's questionMap; task-level
                        and observation from the PACK'S OWN content files, found
                        by pattern, labelled through the contract's
                        referenceConvention. Both levels are real references a
                        guide may cite - a mapping matrix points at "Knowledge
                        Task 5", a self-check at "Knowledge Task 5(b)" - and
                        deriving both is what stops a correct whole-task citation
                        being reported as invented.
      artefacts         out\*_Learner_Guide.docx and out\*_Delivery_PowerPoint.pptx
      template, layouts the RTO profile pack of the RTO whose approved templates
                        the render used (discovered when exactly one pack exists)
      provider codes    the build brand's branding profile, variant-aware
      extracts          Get-DocText, run by this script, on both artefacts

    THE FIGURE REGISTRY RUNS TWICE, AND THE EXTRACTS ARE MADE HERE.
    Test-FigureConsistency has two arms. Without -DocText it checks the SOURCES;
    with -DocText it checks what landed on the page. -DocText is an optional
    [string[]] and the loop over it iterates nothing and exits 0 when it is
    absent, so a runner that leaves it off prints a clean pass having gated no
    rendered artefact at all. That is what happened for a whole build. This
    runner derives the extracts itself and FAILS if none could be made.

    READABILITY MEASURES THE DELIVERED PROSE. Before artwork, a Route A prompt is
    900 to 1100 characters of briefing text sitting in a paragraph; the cap reads
    every one of them as the worst defect in the document while the body prose
    passes. They are deleted at placement and none reaches a learner, so before
    -AfterArtwork they are stripped from a measurement COPY. After artwork the
    real thing is measured with nothing removed.

    THE LEAKAGE GATE REFUSES TO RUN WITHOUT THE UNIT EXTRACT. An assessor guide
    quotes the unit, so without the unit corpus every Performance Evidence line
    the guide teaches reads as assessor-only and the gate demands its deletion.
    A missing corpus must not degrade quietly into a stream of false leaks: the
    gate is refused, loudly, and the run fails.

    THE MIRROR AND LEAKAGE GATES ARE RESOLVED BY PATH, AND THEIR PARAMETERS ARE
    READ FROM THE SCRIPT. The default is the skill's own copy of each. A build
    may pass -MirrorScript / -LeakageScript to run its own, and whichever copy
    runs, this script introspects its parameter list and passes the unit corpus,
    the rendered extracts and the placed document under whichever names that
    copy accepts - refusing, rather than silently dropping, an input the copy
    cannot take. The two families differ: the skill's gates take -ExcludeText,
    -DocText and -DocxPath and read their allow-lists from figures.json; an
    older build copy takes -UnitExtract and carries its allow-list inline.

    PARALLELISM. The gates that share no output fan out on Start-Job - guide,
    deck, readability, figure registry (source arm), mirror, crossover,
    placed-artwork, and both extracts - then the two that need the extracts
    run: the registry's rendered arm and the leakage sweep. One summary, one
    exit code: 0 only when everything passed, and a gate that timed out, threw
    or was refused is a failure, never a skip.

    Usage
      Run-Gates.ps1 -BuildDir <dir> [-PackDir <dir>] [-Brand ACI -Variant culinary]
                    [-Rto 45797 -Cricos 03978F] [-UnitCode X] [-AfterArtwork] [-SkipDeck]
      Run-Gates.ps1 -SelfTest        no Office, no build, no API

    PS 5.1. ASCII only in this file. UTF-8 BOM required on disk.
    Exit 0 all gates pass; 1 a gate failed, was refused or timed out; 2 a usage
    error; 4 the self-test failed.
#>

[CmdletBinding()]
param(
    [string] $BuildDir,
    [string] $PackDir,
    [string] $SkillDir = (Split-Path -Parent $PSScriptRoot),
    [string] $Brand,
    [string] $Variant,
    [string] $Rto,
    [string] $Cricos,
    [string] $UnitCode,
    #  The RTO whose APPROVED TEMPLATES and profiles the render used. The build
    #  brand is swapped on top of them, so the deck's residual-placeholder
    #  vocabulary and slot map come from this RTO's pack, not the brand's.
    #  Discovered when the skill carries exactly one profile pack.
    [string] $TemplateRto,
    [string] $Guide,
    [string] $Deck,
    [string] $PlanPath,
    [string] $UnitExtract,
    [string] $MirrorScript,
    [string] $LeakageScript,
    #  Extra arguments for those two gates, e.g. -LeakageArgs @{ Shingle = 15;
    #  MinWords = 15 }. Every key must be a parameter of the copy that runs, or
    #  the gate is REFUSED rather than run without it; every key is printed in
    #  the threaded list. A build's thresholds are a decision it signs here, not
    #  a default it inherits silently - the build this was promoted from passed
    #  its leakage thresholds from its runner, and a re-run on the gate's own
    #  defaults reports 154 hits where it reported one allow-listed entry.
    [hashtable] $MirrorArgs,
    [hashtable] $LeakageArgs,
    #  Content-file prefix -> referenceConvention key, e.g. @{ uat1 = 'knowledge';
    #  wb = 'workbook' }. Only needed where the derivation below cannot tell the
    #  families apart; what it derived is printed either way.
    [hashtable] $TaskFileMap,
    [string] $TaskIdPattern = 'T(\d+)$',
    [switch] $AfterArtwork,
    [switch] $SkipDeck,
    [switch] $Serial,
    [int] $TimeoutMinutes = 30,
    [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'

function AsArr { param($x) if ($null -eq $x) { return @() } return @($x) }
function HasProp { param($o, [string] $n) if ($null -eq $o) { return $false } return (@($o.PSObject.Properties.Name) -contains $n) }

function Read-JsonFile {
    <# Explicit UTF-8, BOM dropped - PS 5.1 reads a BOM-less file as ANSI. #>
    param([Parameter(Mandatory)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $t = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path, [System.Text.Encoding]::UTF8)
    $t = $t.TrimStart([char]0xFEFF)
    if (-not $t.Trim()) { return $null }
    return ($t | ConvertFrom-Json)
}

# ---------------------------------------------------------------------------
# 1. Pack references - derived from the contract and the pack's own content
# ---------------------------------------------------------------------------

function Get-ReferenceLabelSet {
    <#  The reference families this pack uses, as family -> task-level label
        template carrying {n}. From the contract's referenceConvention where it
        exists, else from the prefixes of the part-level references in the
        questionMap. The source is returned so the runner can print it.  #>
    param([Parameter(Mandatory)] $Contract)

    $labels = [ordered]@{}
    $source = ''
    if ((HasProp $Contract 'referenceConvention') -and $Contract.referenceConvention) {
        foreach ($p in $Contract.referenceConvention.PSObject.Properties) {
            if ($p.Name -like '_*') { continue }
            if ($p.Value -isnot [string]) { continue }
            #  A LABEL TEMPLATE is label words, then {n}, then optionally
            #  ({part}), and nothing else: "Knowledge Task {n}({part})". The
            #  convention also carries prose that happens to contain {n} -
            #  knowledgeMeans = "Task {n} in <file>.docx" - and that is a
            #  description, not a reference the guide may cite.
            if ($p.Value -notmatch '^[A-Za-z][A-Za-z ]*\{n\}(\(\{part\}\))?$') { continue }
            # "Knowledge Task {n}({part})" -> "Knowledge Task {n}"
            $labels[$p.Name] = ([string]$p.Value -replace '\s*\(\{part\}\)\s*', '').Trim()
        }
        if ($labels.Count -gt 0) { $source = 'contract.referenceConvention' }
    }
    if ($labels.Count -eq 0 -and (HasProp $Contract 'questionMap')) {
        foreach ($pr in ($Contract.questionMap.PSObject.Properties | Where-Object { $_.Name -notlike '_*' })) {
            foreach ($r in (AsArr $pr.Value)) {
                $m = [regex]::Match([string]$r, '^(.*?)\s*\d+\s*(\([a-z]\))?\s*$')
                if (-not $m.Success) { continue }
                $prefix = $m.Groups[1].Value.Trim()
                if (-not $prefix) { continue }
                $key = ($prefix -replace '[^A-Za-z0-9]', '').ToLowerInvariant()
                if (-not $labels.Contains($key)) { $labels[$key] = "$prefix {n}" }
            }
        }
        if ($labels.Count -gt 0) { $source = 'prefixes of the questionMap references' }
    }
    if ($labels.Count -eq 0) {
        throw 'Run-Gates: no reference labels could be derived. The contract needs referenceConvention templates carrying {n}, or a questionMap.'
    }
    return [pscustomobject]@{ Labels = $labels; Source = $source }
}

function Resolve-TaskFileFamily {
    <#  Which reference family a content file belongs to, from its stem prefix
        (the part before "_tasks_"). Explicit map first, then the contract, then
        a single non-observation family, then the file prefix itself. Returns
        the family key and how it was decided.  #>
    param(
        [Parameter(Mandatory)][string] $Prefix,
        [Parameter(Mandatory)] $Labels,
        $Contract,
        [hashtable] $TaskFileMap
    )
    if ($TaskFileMap -and $TaskFileMap.ContainsKey($Prefix)) {
        return [pscustomobject]@{ Family = [string]$TaskFileMap[$Prefix]; How = 'explicit -TaskFileMap' }
    }
    if ($Contract -and (HasProp $Contract 'referenceConvention') -and (HasProp $Contract.referenceConvention 'contentFiles')) {
        $cf = $Contract.referenceConvention.contentFiles
        if (HasProp $cf $Prefix) { return [pscustomobject]@{ Family = [string]$cf.$Prefix; How = 'contract.referenceConvention.contentFiles' } }
    }
    $families = @($Labels.Keys | Where-Object { $_ -notmatch '(?i)observ' })
    if ($families.Count -eq 1) {
        return [pscustomobject]@{ Family = [string]$families[0]; How = 'the only non-observation family' }
    }
    #  Two or more families: read the prefix. A workbook family is named for the
    #  workbook; anything else is the knowledge tool.
    $wb = @($families | Where-Object { $_ -match '(?i)work|recipe|wb' })
    $kn = @($families | Where-Object { $_ -match '(?i)know|uat|kt' })
    if ($Prefix -match '(?i)^(wb|workbook|recipe)' -and $wb.Count -gt 0) {
        return [pscustomobject]@{ Family = [string]$wb[0]; How = "file prefix '$Prefix' reads as the workbook family" }
    }
    if ($kn.Count -gt 0) {
        return [pscustomobject]@{ Family = [string]$kn[0]; How = "file prefix '$Prefix' reads as the knowledge family" }
    }
    throw ("Run-Gates: cannot tell which reference family the content file prefix '{0}' belongs to (families: {1}). Pass -TaskFileMap @{{ {0} = '<family>' }}." -f $Prefix, ($families -join ', '))
}

function Get-PackReference {
    <#  Every assessment reference the pack actually contains, at both levels,
        plus observations. Returns Part, Task, Observation, All (distinct) and
        the derivation notes to print.  #>
    param(
        [Parameter(Mandatory)] $Contract,
        [Parameter(Mandatory)][string] $PackDir,
        [hashtable] $TaskFileMap,
        [string] $TaskIdPattern = 'T(\d+)$'
    )

    $notes = New-Object System.Collections.Generic.List[string]

    # ---- part-level, from the contract's own question map
    $partRefs = New-Object System.Collections.Generic.List[string]
    if (HasProp $Contract 'questionMap') {
        foreach ($pr in ($Contract.questionMap.PSObject.Properties | Where-Object { $_.Name -notlike '_*' })) {
            foreach ($r in (AsArr $pr.Value)) { $partRefs.Add([string]$r) }
        }
    }

    $ls = Get-ReferenceLabelSet -Contract $Contract
    $notes.Add(("reference labels from {0}: {1}" -f $ls.Source, (($ls.Labels.Keys | ForEach-Object { "{0}='{1}'" -f $_, $ls.Labels[$_] }) -join ', ')))

    $contentDir = Join-Path $PackDir 'content'
    if (-not (Test-Path -LiteralPath $contentDir)) { throw "Run-Gates: pack content directory missing: $contentDir" }

    # ---- task-level, DERIVED from the pack's own content files
    $taskRefs = New-Object System.Collections.Generic.List[string]
    $taskFiles = @(Get-ChildItem -LiteralPath $contentDir -Filter '*_tasks_*.json' -File | Sort-Object Name)
    if ($taskFiles.Count -eq 0) { throw "Run-Gates: no content\*_tasks_*.json in $PackDir - the task-level references cannot be derived from the pack." }
    $fileMap = [ordered]@{}
    foreach ($f in $taskFiles) {
        $prefix = ($f.BaseName -split '_tasks_')[0]
        $fam = Resolve-TaskFileFamily -Prefix $prefix -Labels $ls.Labels -Contract $Contract -TaskFileMap $TaskFileMap
        if (-not $ls.Labels.Contains($fam.Family)) { throw ("Run-Gates: content file '{0}' maps to family '{1}', which the reference labels do not define." -f $f.Name, $fam.Family) }
        $tmpl = [string]$ls.Labels[$fam.Family]
        if (-not $fileMap.Contains($prefix)) { $fileMap[$prefix] = "{0} ({1})" -f $fam.Family, $fam.How }
        $j = Read-JsonFile -Path $f.FullName
        foreach ($it in (AsArr $j.items)) {
            if ([string]$it.id -match $TaskIdPattern) { $taskRefs.Add($tmpl.Replace('{n}', $Matches[1])) }
        }
    }
    $notes.Add(("content-file map: {0}" -f (($fileMap.Keys | ForEach-Object { "{0} -> {1}" -f $_, $fileMap[$_] }) -join '; ')))

    # ---- observations, derived the same way
    $obsRefs = New-Object System.Collections.Generic.List[string]
    $obsFamily = @($ls.Labels.Keys | Where-Object { $_ -match '(?i)observ' })
    $obsFiles = @(Get-ChildItem -LiteralPath $contentDir -Filter '*observation*.json' -File | Sort-Object Name)
    if ($obsFamily.Count -gt 0 -and $obsFiles.Count -gt 0) {
        $tmpl = [string]$ls.Labels[$obsFamily[0]]
        foreach ($f in $obsFiles) {
            $j = Read-JsonFile -Path $f.FullName
            foreach ($it in (AsArr $j.items)) {
                if ([string]$it.id -match '(\d+)$') { $obsRefs.Add($tmpl.Replace('{n}', $Matches[1])) }
            }
        }
    }

    $all = @(@($partRefs) + @($taskRefs) + @($obsRefs) | Sort-Object -Unique)
    return [pscustomobject]@{
        Part        = @($partRefs)
        Task        = @($taskRefs | Sort-Object -Unique)
        Observation = @($obsRefs | Sort-Object -Unique)
        All         = $all
        Notes       = @($notes)
    }
}

# ---------------------------------------------------------------------------
# 2. Script parameter introspection - pass what a gate copy can take
# ---------------------------------------------------------------------------

function Get-ScriptParameterName {
    param([Parameter(Mandatory)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    $c = Get-Command -Name $Path -ErrorAction Stop
    return @($c.Parameters.Keys | Where-Object { $_ -notin [System.Management.Automation.PSCmdlet]::CommonParameters })
}

# ---------------------------------------------------------------------------
# 3. The invocation plan - DATA, built before any gate runs
#
#  Every gate call is an entry here, with the exact argument hashtable it will
#  be splatted with. The self-test builds this plan from synthetic inputs and
#  asserts every required parameter name is present, and that the leakage gate
#  is refused without the unit extract - exercising the real plan builder, not a
#  copy of its rules.
# ---------------------------------------------------------------------------

function New-GateInvocationPlan {
    param(
        [Parameter(Mandatory)][ValidateSet(1, 2)][int] $Phase,
        [Parameter(Mandatory)][hashtable] $In
    )
    $plan = New-Object System.Collections.Generic.List[object]
    #  The parameter is -GateArgs, not -Args: $args is an automatic variable, and
    #  a parameter of that name is silently shadowed by the unbound-argument
    #  array, which arrives as Object[] and fails the [hashtable] cast.
    function Entry {
        param([string] $Name, [string] $Kind, [string] $Title, [string] $Script, [hashtable] $GateArgs, [string] $Produces, [string] $Refused)
        if ($null -eq $GateArgs) { $GateArgs = @{} }
        return [pscustomobject]@{ Name = $Name; Kind = $Kind; Title = $Title; Script = $Script; Args = $GateArgs; Produces = $Produces; Refused = $Refused }
    }
    $scripts = Join-Path $In.SkillDir 'scripts'

    #  Merge a caller's pass-through arguments into a gate's argument set. A key
    #  the running copy does not declare is a REFUSAL, never a silent drop: a
    #  threshold the caller believes is in force must be in force.
    function Merge-PassThrough {
        param([System.Collections.IDictionary] $Into, [hashtable] $Extra, [string[]] $Accepted)   # IDictionary, not [hashtable]: binding an ordered dictionary to [hashtable] COPIES it, and the merge lands in the copy
        if (-not $Extra) { return $null }
        foreach ($k in $Extra.Keys) {
            if ($Accepted -notcontains [string]$k) { return ("pass-through argument -{0} is not a parameter of this copy of the gate (it takes: {1})" -f $k, ($Accepted -join ', ')) }
            $Into[[string]$k] = $Extra[$k]
        }
        return $null
    }

    if ($Phase -eq 1) {
        # ---- guide gate
        $ga = [ordered]@{}
        $ga['Path']            = $In.Guide
        $ga['QuestionsInPack'] = @($In.PackRefs)
        $ga['QuestionPattern'] = $In.QuestionPattern
        $ga['AfterArtwork']    = [bool]$In.AfterArtwork
        $plan.Add((Entry -Name 'guide' -Kind 'guide' -Title 'GUIDE GATE (Test-GuideRules)' -GateArgs $ga))

        # ---- readability, on a measurement copy before artwork
        $ra = [ordered]@{}
        $ra['Path']         = $In.Guide
        $ra['Brand']        = $In.Brand
        $ra['AfterArtwork'] = [bool]$In.AfterArtwork
        $plan.Add((Entry -Name 'readability' -Kind 'readability' -Title 'READABILITY (Test-Readability)' -GateArgs $ra))

        # ---- deck gate
        if (-not $In.SkipDeck -and $In.Deck) {
            $da = [ordered]@{}
            $da['Path']               = $In.Deck
            $da['TemplatePath']       = $In.TemplatePath
            $da['Plan']               = @($In.Plan)
            $da['NumberSlotByLayout'] = $In.NumberSlotByLayout
            $da['Rto']                = $In.Rto
            $da['Cricos']             = $In.Cricos
            $plan.Add((Entry -Name 'deck' -Kind 'deck' -Title 'DECK GATE (Test-DeckRules)' -GateArgs $da))
        }
        else {
            $plan.Add((Entry -Name 'deck' -Kind 'deck' -Title 'DECK GATE (Test-DeckRules)' -GateArgs @{} -Refused $(if ($In.SkipDeck) { 'skipped by -SkipDeck' } else { 'no deck artefact found' })))
        }

        # ---- figure registry, source arm
        $plan.Add((Entry -Name 'figures-source' -Kind 'script' -Title 'FIGURE REGISTRY - declared sources (Test-FigureConsistency)' `
                   -Script (Join-Path $scripts 'Test-FigureConsistency.ps1') -GateArgs ([ordered]@{ BuildDir = $In.BuildDir })))

        # ---- extracts, one per artefact
        $plan.Add((Entry -Name 'extract-guide' -Kind 'script' -Title 'EXTRACT - guide (Get-DocText)' `
                   -Script (Join-Path $scripts 'Get-DocText.ps1') -GateArgs ([ordered]@{ Path = $In.Guide; OutPath = $In.GuideText }) -Produces $In.GuideText))
        if ($In.Deck -and -not $In.SkipDeck) {
            $plan.Add((Entry -Name 'extract-deck' -Kind 'script' -Title 'EXTRACT - deck (Get-DocText)' `
                       -Script (Join-Path $scripts 'Get-DocText.ps1') -GateArgs ([ordered]@{ Path = $In.Deck; OutPath = $In.DeckText }) -Produces $In.DeckText))
        }

        # ---- mirror
        $mp = @(Get-ScriptParameterName -Path $In.MirrorScript)
        if ($mp.Count -eq 0) {
            $plan.Add((Entry -Name 'mirror' -Kind 'script' -Title 'ANSWER-GRID MIRROR (Check-FigureMirror)' -Script $In.MirrorScript -GateArgs @{} -Refused "gate script not found: $($In.MirrorScript)"))
        }
        else {
            $ma = [ordered]@{ BuildDir = $In.BuildDir }
            if ($mp -contains 'DocxPath' -and $In.Guide) { $ma['DocxPath'] = @($In.Guide) }
            $bad = Merge-PassThrough -Into $ma -Extra $In.MirrorArgs -Accepted $mp
            $plan.Add((Entry -Name 'mirror' -Kind 'script' -Title 'ANSWER-GRID MIRROR (Check-FigureMirror)' -Script $In.MirrorScript -GateArgs $ma -Refused $bad))
        }

        # ---- crossover, BOTH artefacts in one call
        $arts = @(@($In.Guide, $In.Deck) | Where-Object { $_ })
        $ia = [ordered]@{ Path = $arts; BuildDir = $In.BuildDir; Brand = $In.Brand }
        if ($In.Variant) { $ia['Variant'] = $In.Variant }
        $plan.Add((Entry -Name 'identity' -Kind 'script' -Title 'BRAND CROSSOVER (Check-Identity)' -Script (Join-Path $scripts 'Check-Identity.ps1') -GateArgs $ia))

        # ---- placed artwork, after placement only
        if ($In.AfterArtwork) {
            $plan.Add((Entry -Name 'placed' -Kind 'script' -Title 'PLACED ARTWORK (Check-Figures)' -Script (Join-Path $scripts 'Check-Figures.ps1') `
                       -GateArgs ([ordered]@{ Path = $arts; BuildDir = $In.BuildDir })))
        }
        return $plan
    }

    # ---- phase 2: the gates that need the extracts
    $docTexts = @($In.DocTexts | Where-Object { $_ -and (Test-Path -LiteralPath $_) })
    if ($docTexts.Count -eq 0) {
        $plan.Add((Entry -Name 'figures-rendered' -Kind 'script' -Title 'FIGURE REGISTRY - rendered text (Test-FigureConsistency -DocText)' `
                   -Script (Join-Path $scripts 'Test-FigureConsistency.ps1') -GateArgs @{} `
                   -Refused 'no rendered text could be extracted - the rendered arm did NOT run, and a registry pass on sources alone gates no artefact'))
    }
    else {
        $plan.Add((Entry -Name 'figures-rendered' -Kind 'script' -Title ("FIGURE REGISTRY - rendered text, {0} artefact(s) (Test-FigureConsistency -DocText)" -f $docTexts.Count) `
                   -Script (Join-Path $scripts 'Test-FigureConsistency.ps1') -GateArgs ([ordered]@{ BuildDir = $In.BuildDir; DocText = $docTexts })))
    }

    $lp = @(Get-ScriptParameterName -Path $In.LeakageScript)
    if ($lp.Count -eq 0) {
        $plan.Add((Entry -Name 'leakage' -Kind 'script' -Title 'ASSESSOR LEAKAGE (Check-FigureLeakage)' -Script $In.LeakageScript -GateArgs @{} -Refused "gate script not found: $($In.LeakageScript)"))
    }
    elseif (-not $In.UnitExtract -or -not (Test-Path -LiteralPath $In.UnitExtract)) {
        $plan.Add((Entry -Name 'leakage' -Kind 'script' -Title 'ASSESSOR LEAKAGE (Check-FigureLeakage)' -Script $In.LeakageScript -GateArgs @{} `
                   -Refused ("REFUSED: no unit_extract.md in the build directory (looked for {0}). An assessor guide quotes the unit; without the unit corpus every unit line the guide teaches is misreported as assessor-only. Put the extract in place and re-run." -f $In.UnitExtract)))
    }
    else {
        $la = [ordered]@{ BuildDir = $In.BuildDir }
        if     ($lp -contains 'ExcludeText') { $la['ExcludeText'] = @($In.UnitExtract) }
        elseif ($lp -contains 'UnitExtract') { $la['UnitExtract'] = $In.UnitExtract }
        else {
            $plan.Add((Entry -Name 'leakage' -Kind 'script' -Title 'ASSESSOR LEAKAGE (Check-FigureLeakage)' -Script $In.LeakageScript -GateArgs @{} `
                       -Refused 'this copy of the leakage gate accepts neither -ExcludeText nor -UnitExtract, so the unit corpus cannot be passed and its findings would be false'))
            return $plan
        }
        if ($lp -contains 'DocText' -and $docTexts.Count -gt 0) { $la['DocText'] = $docTexts }
        if ($lp -contains 'ReportPath') { $la['ReportPath'] = (Join-Path $In.BuildDir 'leakage_report.txt') }
        $bad = Merge-PassThrough -Into $la -Extra $In.LeakageArgs -Accepted $lp
        $plan.Add((Entry -Name 'leakage' -Kind 'script' -Title 'ASSESSOR LEAKAGE (Check-FigureLeakage)' -Script $In.LeakageScript -GateArgs $la -Refused $bad))
    }
    return $plan
}

function Format-ArgValue {
    param($v)
    if ($null -eq $v) { return '(null)' }
    if ($v -is [bool]) { return $v.ToString() }
    if ($v -is [hashtable]) { return ("{0} entr(ies)" -f $v.Count) }
    if ($v -is [string]) {
        # A rooted path prints as its leaf; a regex full of backslashes does not.
        if ($v -match '^([A-Za-z]:|\\\\)[\\/]' -and $v.Length -gt 40) { return (Split-Path $v -Leaf) }
        if ($v.Length -gt 60) { return ($v.Substring(0, 57) + '...') }
        return $v
    }
    if ($v -is [System.Collections.IEnumerable]) {
        $items = @($v)
        if ($items.Count -le 2 -and ($items | Where-Object { $_ -is [string] }).Count -eq $items.Count) {
            return (($items | ForEach-Object { Format-ArgValue $_ }) -join ', ')
        }
        return ("{0} item(s)" -f $items.Count)
    }
    return [string]$v
}

function Get-ThreadedParameterLine {
    <# One line per gate: "-Name=value -Name=value". #>
    param([Parameter(Mandatory)] $Plan)
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($e in $Plan) {
        if ($e.Refused) { $out.Add(("{0}: NOT RUN - {1}" -f $e.Name, $e.Refused)); continue }
        $parts = @()
        foreach ($k in $e.Args.Keys) { $parts += ("-{0}={1}" -f $k, (Format-ArgValue $e.Args[$k])) }
        $out.Add(("{0}: {1}" -f $e.Name, ($parts -join ' ')))
    }
    return $out
}

# ---------------------------------------------------------------------------
# 4. The job body - self-contained, because a job inherits no function
# ---------------------------------------------------------------------------

$script:GateJobBody = {
    param($Entry, $SkillDir)
    $ErrorActionPreference = 'Stop'
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $lines = New-Object System.Collections.Generic.List[string]
    $ok = $false
    $err = ''
    $partial = @()

    function Take { param($stream) foreach ($o in @($stream)) { if ($o -is [System.Management.Automation.InformationRecord]) { $lines.Add([string]$o.MessageData) } elseif ($o -is [string]) { $lines.Add($o) } } }

    try {
        $a = @{}
        foreach ($k in $Entry.Args.Keys) { $a[$k] = $Entry.Args[$k] }
        switch ($Entry.Kind) {
            'guide' {
                . (Join-Path $SkillDir 'scripts\Lib-Resolve.ps1')
                $g = Test-GuideRules @a
                Take ($g | Write-GuideRuleReport 6>&1)
                $ok = [bool]$g.Ok
                if ($g.PSObject.Properties.Name -contains 'Partial') { $partial = @($g.Partial) }
            }
            'deck' {
                . (Join-Path $SkillDir 'scripts\Lib-Resolve.ps1')
                $d = Test-DeckRules @a
                Take ($d | Write-DeckRuleReport 6>&1)
                $ok = [bool]$d.Ok
                if ($d.PSObject.Properties.Name -contains 'Partial') { $partial = @($d.Partial) }
            }
            'readability' {
                . (Join-Path $SkillDir 'scripts\Lib-Resolve.ps1')
                $rwd = Expand-Docx -Path $a['Path']
                try {
                    if (-not $a['AfterArtwork']) {
                        # Strip artwork prompt paragraphs from the MEASUREMENT COPY.
                        $dx = Get-DocxPart -WorkDir $rwd -Part 'word/document.xml'
                        $paras = [regex]::Matches($dx, '<w:p\b.*?</w:p>', 'Singleline')
                        $before = $paras.Count
                        $kept = New-Object System.Text.StringBuilder
                        $pos = 0
                        $stripped = 0
                        foreach ($m in $paras) {
                            $txt = (-join ([regex]::Matches($m.Value, '<w:t[^>]*>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value })).Trim()
                            if ($txt -match '^\[(IMAGE|DIAGRAM)\s*:' -or $txt -match '^\[/(IMAGE|DIAGRAM)\]$' -or $txt -match '^(CAPTION|ALT|ASPECT|QUALITY)\s*:') {
                                [void]$kept.Append($dx.Substring($pos, $m.Index - $pos))
                                $pos = $m.Index + $m.Length
                                $stripped++
                            }
                        }
                        [void]$kept.Append($dx.Substring($pos))
                        Set-DocxPart -WorkDir $rwd -Part 'word/document.xml' -Content $kept.ToString()
                        $lines.Add(("readability: measuring the delivered prose - {0} artwork prompt paragraph(s) of {1} removed from the measurement copy" -f $stripped, $before))
                    }
                    else { $lines.Add('readability: after artwork - the real document is measured with nothing removed') }
                    $r = Test-Readability -WorkDir $rwd -Brand $a['Brand']
                    Take (Write-ReadabilityReport -Result $r -Label 'Learner Guide' 6>&1)
                    $ok = [bool]$r.Ok
                }
                finally { Remove-Item -LiteralPath $rwd -Recurse -Force -ErrorAction SilentlyContinue }
            }
            'script' {
                $LASTEXITCODE = 0
                Take (& $Entry.Script @a 6>&1)
                $code = $LASTEXITCODE
                if ($null -eq $code) { $code = 0 }
                $ok = ($code -eq 0)
                if ($Entry.Produces) {
                    if (-not (Test-Path -LiteralPath $Entry.Produces)) { $ok = $false; $lines.Add("X expected output not written: $($Entry.Produces)") }
                }
                if (-not $ok -and $code -ne 0) { $lines.Add("exit code $code") }
            }
            default { throw "unknown gate kind '$($Entry.Kind)'" }
        }
    }
    catch {
        $err = $_.Exception.Message
        $ok = $false
    }
    [pscustomobject]@{ Name = $Entry.Name; Ok = $ok; Text = ($lines -join "`n"); Error = $err; Partial = $partial; Seconds = [int]$sw.Elapsed.TotalSeconds }
}

function Invoke-GatePlan {
    <#  Run every runnable entry of a plan as a Start-Job, wait with a timeout,
        and return one result per entry - refused entries included, as failures.
        -Serial starts and joins one job at a time, for debugging.  #>
    param(
        [Parameter(Mandatory)] $Plan,
        [Parameter(Mandatory)][string] $SkillDir,
        [int] $TimeoutSeconds = 1800,
        [switch] $Serial
    )
    $results = New-Object System.Collections.Generic.List[object]
    $jobs = @{}
    foreach ($e in $Plan) {
        if ($e.Refused) {
            $results.Add([pscustomobject]@{ Name = $e.Name; Ok = $false; Text = ''; Error = $e.Refused; Partial = @(); Seconds = 0; Refused = $true })
            continue
        }
        $j = Start-Job -ScriptBlock $script:GateJobBody -ArgumentList $e, $SkillDir
        $jobs[$e.Name] = $j
        if ($Serial) {
            $done = Wait-Job -Job $j -Timeout $TimeoutSeconds
            if (-not $done) { Stop-Job -Job $j -ErrorAction SilentlyContinue }
        }
    }
    if ($jobs.Count -gt 0 -and -not $Serial) {
        $null = Wait-Job -Job @($jobs.Values) -Timeout $TimeoutSeconds
    }
    foreach ($e in $Plan) {
        if ($e.Refused) { continue }
        $j = $jobs[$e.Name]
        if ($j.State -eq 'Completed') {
            $r = Receive-Job -Job $j -ErrorAction SilentlyContinue
            $r = @($r | Where-Object { $_ -and ($_.PSObject.Properties.Name -contains 'Ok') } | Select-Object -Last 1)
            if ($r.Count -eq 1) {
                $results.Add([pscustomobject]@{ Name = $e.Name; Ok = [bool]$r[0].Ok; Text = [string]$r[0].Text; Error = [string]$r[0].Error; Partial = @($r[0].Partial); Seconds = [int]$r[0].Seconds; Refused = $false })
            }
            else {
                $results.Add([pscustomobject]@{ Name = $e.Name; Ok = $false; Text = ''; Error = 'the job returned no result object'; Partial = @(); Seconds = 0; Refused = $false })
            }
        }
        else {
            $why = if ($j.State -eq 'Running') { "timed out after $TimeoutSeconds s - job stopped" } else { "job ended in state $($j.State)" }
            $errText = ''
            try { $reason = $j.ChildJobs[0].JobStateInfo.Reason; if ($reason) { $errText = [string]$reason.Message } } catch { }
            if (-not $errText) { try { $null = Receive-Job -Job $j -ErrorAction Stop } catch { $errText = $_.Exception.Message } }
            if ($j.State -eq 'Running') { Stop-Job -Job $j -ErrorAction SilentlyContinue }
            $results.Add([pscustomobject]@{ Name = $e.Name; Ok = $false; Text = $errText; Error = $why; Partial = @(); Seconds = 0; Refused = $false })
        }
        Remove-Job -Job $j -Force -ErrorAction SilentlyContinue
    }
    return $results
}

function Write-GateText {
    param([string] $Text)
    if (-not $Text) { return }
    foreach ($ln in ($Text -split "`n")) {
        $t = $ln.TrimEnd()
        if (-not $t) { continue }
        $col = 'Gray'
        if     ($t -match '^\s*X\s' -or $t -match '^\s*FAIL' -or $t -match 'X\s+\S') { $col = 'Red' }
        elseif ($t -match '^\s*(PASS|ALL GATES PASS)\b' -or $t -match '^\s*no \w') { $col = 'Green' }
        elseif ($t -match '^\s*(WARN|~|!|NOT|PARTIAL)' -or $t -match 'NOT RUN') { $col = 'Yellow' }
        Write-Host ("    " + $t) -ForegroundColor $col
    }
}

# ---------------------------------------------------------------------------
# 5. Self-test - no Office, no build, no API
# ---------------------------------------------------------------------------

if ($SelfTest) {
    $pass = 0; $fail = 0
    function Ok  ($m) { $script:pass++; Write-Host "  PASS  $m" -ForegroundColor Green }
    function Bad ($m) { $script:fail++; Write-Host "  FAIL  $m" -ForegroundColor Red }

    Write-Host ''
    Write-Host 'Run-Gates self-test' -ForegroundColor Cyan
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('rg_selftest_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $build = Join-Path $tmp 'build'
    $pack  = Join-Path $tmp 'pack'
    New-Item -ItemType Directory -Force -Path (Join-Path $pack 'content') | Out-Null
    New-Item -ItemType Directory -Force -Path $build | Out-Null
    try {
        # ---- a synthetic contract and pack, two task families plus observations
        $contract = [pscustomobject]@{
            referenceConvention = [pscustomobject]@{
                _why = 'x'
                knowledge = 'Knowledge Task {n}({part})'
                workbook  = 'Workbook Task {n}({part})'
                observation = 'Observation {n}'
                questionPattern = '\b(?:Knowledge Task|Workbook Task|Observation)\s?(\d+)\s?(\([a-z]\))?'
            }
            questionMap = [pscustomobject]@{ _rule = 'x'; '1.1' = @('Knowledge Task 1(a)', 'Workbook Task 2(b)', 'Observation 1') }
        }
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText((Join-Path $pack 'content\uat1_tasks_1_2.json'), '{"items":[{"id":"UAT1-T1"},{"id":"UAT1-T2"}]}', $utf8)
        [System.IO.File]::WriteAllText((Join-Path $pack 'content\wb_tasks_1_3.json'),   '{"items":[{"id":"WB-T1"},{"id":"WB-T2"},{"id":"WB-T3"}]}', $utf8)
        [System.IO.File]::WriteAllText((Join-Path $pack 'content\observations_1_2.json'), '{"items":[{"id":"OBS-COVER"},{"id":"OBS-1"},{"id":"OBS-2"}]}', $utf8)

        $refs = Get-PackReference -Contract $contract -PackDir $pack
        if ($refs.Part.Count -eq 3) { Ok 'part-level references come from the questionMap (3)' } else { Bad "part-level count $($refs.Part.Count)" }
        if ($refs.Task.Count -eq 5 -and $refs.Task -contains 'Knowledge Task 2' -and $refs.Task -contains 'Workbook Task 3') { Ok 'task-level references derived from the pack content files, labelled by family (5)' } else { Bad ("task-level: " + ($refs.Task -join ', ')) }
        if ($refs.Observation.Count -eq 2 -and $refs.Observation -contains 'Observation 2') { Ok 'observations derived (2); the cover item is not a reference' } else { Bad ("observations: " + ($refs.Observation -join ', ')) }
        if ($refs.All.Count -eq 9) { Ok 'distinct reference set is the union (9)' } else { Bad "distinct $($refs.All.Count)" }
        if (($refs.Notes -join ' ') -match 'uat1 -> knowledge' -and ($refs.Notes -join ' ') -match 'wb -> workbook') { Ok 'the content-file map is printed with how each family was decided' } else { Bad ("notes: " + ($refs.Notes -join ' | ')) }

        # ---- a contract with NO referenceConvention still derives labels
        $c2 = [pscustomobject]@{ questionMap = [pscustomobject]@{ '1.1' = @('Q1', 'Q2(a)') } }
        $ls2 = Get-ReferenceLabelSet -Contract $c2
        if ($ls2.Labels.Count -eq 1 -and $ls2.Labels['q'] -eq 'Q {n}') { Ok 'labels fall back to the questionMap prefixes when the contract has no convention' } else { Bad ("fallback labels: " + (($ls2.Labels.Keys | ForEach-Object { "$_=$($ls2.Labels[$_])" }) -join ',')) }

        # ---- the plan carries every parameter the gates' blocking rules need
        $unitX = Join-Path $build 'unit_extract.md'
        [System.IO.File]::WriteAllText($unitX, 'Performance Evidence', $utf8)
        $guideText = Join-Path $build 'guide_gate.txt'
        $deckText  = Join-Path $build 'deck_gate.txt'
        [System.IO.File]::WriteAllText($guideText, 'guide text', $utf8)
        [System.IO.File]::WriteAllText($deckText,  'deck text',  $utf8)
        $in = @{
            BuildDir = $build; SkillDir = $SkillDir
            Guide = (Join-Path $build 'out\X_Learner_Guide.docx'); Deck = (Join-Path $build 'out\X_Delivery_PowerPoint.pptx')
            PackRefs = $refs.All; QuestionPattern = [string]$contract.referenceConvention.questionPattern
            AfterArtwork = $true; TemplatePath = 'C:\t\deck.pptx'; Plan = @(@{ Tag = 't'; Kind = 'title' }); NumberSlotByLayout = @{ 1 = 0 }
            Rto = '00000'; Cricos = '00000A'; Brand = 'X'; Variant = 'y'; UnitExtract = $unitX
            MirrorScript = (Join-Path $SkillDir 'scripts\Check-FigureMirror.ps1'); LeakageScript = (Join-Path $SkillDir 'scripts\Check-FigureLeakage.ps1')
            GuideText = $guideText; DeckText = $deckText; DocTexts = @($guideText, $deckText); SkipDeck = $false
        }
        $p1 = New-GateInvocationPlan -Phase 1 -In $in
        $p2 = New-GateInvocationPlan -Phase 2 -In $in
        $names = New-Object 'System.Collections.Generic.HashSet[string]'
        foreach ($e in @($p1) + @($p2)) { foreach ($k in $e.Args.Keys) { [void]$names.Add([string]$k) } }
        $required = @('QuestionsInPack', 'QuestionPattern', 'AfterArtwork', 'TemplatePath', 'Plan', 'NumberSlotByLayout', 'Rto', 'Cricos', 'DocText', 'Path', 'BuildDir', 'Brand', 'Variant')
        $missing = @($required | Where-Object { -not $names.Contains($_) })
        if ($missing.Count -eq 0) { Ok ("the plan threads every required parameter: " + ($required -join ', ')) } else { Bad ("plan is missing: " + ($missing -join ', ')) }
        if ($names.Contains('ExcludeText') -or $names.Contains('UnitExtract')) { Ok 'the unit corpus is threaded to the leakage gate under the name that copy accepts' } else { Bad 'unit corpus not threaded' }
        $id = @($p1 | Where-Object { $_.Name -eq 'identity' })[0]
        if (@($id.Args['Path']).Count -eq 2) { Ok 'Check-Identity is handed BOTH artefacts in one call' } else { Bad 'Check-Identity not handed both artefacts' }
        $pl = @($p1 | Where-Object { $_.Name -eq 'placed' })
        if ($pl.Count -eq 1) { Ok 'Check-Figures runs after artwork' } else { Bad 'Check-Figures missing after artwork' }
        $lines = Get-ThreadedParameterLine -Plan (@($p1) + @($p2))
        $joined = $lines -join "`n"
        $missingInPrint = @($required | Where-Object { $joined -notmatch ('-' + [regex]::Escape($_) + '=') })
        if ($missingInPrint.Count -eq 0) { Ok 'the printed threaded-parameter list names every one of them' } else { Bad ("printed list lacks: " + ($missingInPrint -join ', ')) }

        # ---- without the unit extract the leakage gate is REFUSED
        Remove-Item -LiteralPath $unitX -Force
        $p2b = New-GateInvocationPlan -Phase 2 -In $in
        $lk = @($p2b | Where-Object { $_.Name -eq 'leakage' })[0]
        if ($lk.Refused -and $lk.Refused -match 'unit_extract\.md') { Ok 'the leakage gate is refused, naming unit_extract.md, when the extract is absent' } else { Bad "leakage not refused: '$($lk.Refused)'" }
        $rr = Invoke-GatePlan -Plan @($lk) -SkillDir $SkillDir -TimeoutSeconds 5
        if (@($rr).Count -eq 1 -and -not @($rr)[0].Ok -and @($rr)[0].Refused) { Ok 'a refused gate is a FAILURE in the results, never a skip' } else { Bad 'refused gate did not fail the run' }

        # ---- pass-through arguments: merged when the copy declares them, REFUSED when it does not
        [System.IO.File]::WriteAllText($unitX, 'Performance Evidence', $utf8)   # the extract is back for this block
        $in3 = $in.Clone(); $in3['LeakageArgs'] = @{ Shingle = 15; MinWords = 15 }
        $p2d = New-GateInvocationPlan -Phase 2 -In $in3
        $lk3 = @($p2d | Where-Object { $_.Name -eq 'leakage' })[0]
        if (-not $lk3.Refused -and $lk3.Args['Shingle'] -eq 15 -and $lk3.Args['MinWords'] -eq 15) { Ok 'pass-through arguments the gate declares are merged and printed' } else { Bad "pass-through not merged: refused='$($lk3.Refused)'" }
        $in4 = $in.Clone(); $in4['LeakageArgs'] = @{ NoSuchParameter = 1 }
        $lk4 = @((New-GateInvocationPlan -Phase 2 -In $in4) | Where-Object { $_.Name -eq 'leakage' })[0]
        if ($lk4.Refused -and $lk4.Refused -match 'NoSuchParameter') { Ok 'a pass-through argument the gate does not declare REFUSES the gate rather than being dropped' } else { Bad 'unknown pass-through not refused' }

        # ---- without any extract the rendered arm is REFUSED
        $in2 = $in.Clone(); $in2['DocTexts'] = @()
        $p2c = New-GateInvocationPlan -Phase 2 -In $in2
        $fr = @($p2c | Where-Object { $_.Name -eq 'figures-rendered' })[0]
        if ($fr.Refused -and $fr.Refused -match 'rendered arm did NOT run') { Ok 'the registry rendered arm is refused when no extract exists' } else { Bad 'rendered arm not refused' }

        # ---- the job wrapper collects a result and survives a script that exits non-zero
        $stub = Join-Path $tmp 'stub_gate.ps1'
        [System.IO.File]::WriteAllText($stub, "param([string] `$BuildDir)`r`nWrite-Host 'X planted failure'`r`nexit 1`r`n", (New-Object System.Text.UTF8Encoding($true)))
        $se = [pscustomobject]@{ Name = 'stub'; Kind = 'script'; Title = 'stub'; Script = $stub; Args = @{ BuildDir = $build }; Produces = $null; Refused = $null }
        $sr = Invoke-GatePlan -Plan @($se) -SkillDir $SkillDir -TimeoutSeconds 120
        if (@($sr).Count -eq 1 -and -not @($sr)[0].Ok -and @($sr)[0].Text -match 'planted failure') { Ok 'the job wrapper captures a gate script''s text and its non-zero exit as a failure' } else { Bad ("job wrapper: ok=$(@($sr)[0].Ok) text='$(@($sr)[0].Text)' err='$(@($sr)[0].Error)'") }
        $stub2 = Join-Path $tmp 'stub_slow.ps1'
        [System.IO.File]::WriteAllText($stub2, "param([string] `$BuildDir)`r`nStart-Sleep -Seconds 60`r`nexit 0`r`n", (New-Object System.Text.UTF8Encoding($true)))
        $se2 = [pscustomobject]@{ Name = 'slow'; Kind = 'script'; Title = 'slow'; Script = $stub2; Args = @{ BuildDir = $build }; Produces = $null; Refused = $null }
        $sr2 = Invoke-GatePlan -Plan @($se2) -SkillDir $SkillDir -TimeoutSeconds 3
        if (@($sr2).Count -eq 1 -and -not @($sr2)[0].Ok -and @($sr2)[0].Error -match 'timed out') { Ok 'a gate that overruns the timeout is stopped and reported as a failure' } else { Bad ("timeout: ok=$(@($sr2)[0].Ok) err='$(@($sr2)[0].Error)'") }
    }
    finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }

    Write-Host ''
    Write-Host ("  {0} passed, {1} failed" -f $pass, $fail) -ForegroundColor $(if ($fail) { 'Red' } else { 'Green' })
    if ($fail) { exit 4 }
    exit 0
}

# ---------------------------------------------------------------------------
# 6. Resolve every input - parameters first, then the contract, then discovery
# ---------------------------------------------------------------------------

if (-not $BuildDir) { Write-Host 'Run-Gates: -BuildDir is required (or -SelfTest).' -ForegroundColor Red; exit 2 }
$BuildDir = (Resolve-Path -LiteralPath $BuildDir).Path
$SkillDir = (Resolve-Path -LiteralPath $SkillDir).Path
$scriptsDir = Join-Path $SkillDir 'scripts'

$derived = New-Object System.Collections.Generic.List[string]

$contractPath = Join-Path $BuildDir 'contract.json'
$contract = Read-JsonFile -Path $contractPath
if ($null -eq $contract) { Write-Host "Run-Gates: no contract.json in $BuildDir" -ForegroundColor Red; exit 2 }

if (-not $UnitCode -and (HasProp $contract 'unit'))  { $UnitCode = [string]$contract.unit.code;    $derived.Add("UnitCode '$UnitCode' from contract.unit.code") }
if (-not $Brand    -and (HasProp $contract 'build')) { $Brand    = [string]$contract.build.brand;   $derived.Add("Brand '$Brand' from contract.build.brand") }
if (-not $Variant  -and (HasProp $contract 'build')) { $Variant  = [string]$contract.build.variant; $derived.Add("Variant '$Variant' from contract.build.variant") }
if (-not $PackDir  -and (HasProp $contract 'build') -and (HasProp $contract.build 'packDir')) { $PackDir = [string]$contract.build.packDir; $derived.Add("PackDir from contract.build.packDir") }
if (-not $Brand)   { Write-Host 'Run-Gates: no brand - pass -Brand or put build.brand in the contract.' -ForegroundColor Red; exit 2 }
if (-not $PackDir -or -not (Test-Path -LiteralPath $PackDir)) { Write-Host "Run-Gates: pack directory not found: '$PackDir' - pass -PackDir." -ForegroundColor Red; exit 2 }

# ---- the shared library, for the deck profile, the branding and Expand-Docx
. (Join-Path $scriptsDir 'Lib-Resolve.ps1')

# ---- the RTO profile pack of the TEMPLATE RTO. Its script's param block runs
#      in THIS scope and carries a $Rto of its own, so the value is saved and
#      put back; a dot-source that silently blanked -Rto would make the deck
#      gate fail on an input this runner was handed.
if (-not $TemplateRto) {
    $packs = @(Get-ChildItem -LiteralPath (Join-Path $SkillDir 'assets') -Filter 'rto-profile.*.json' -File | Where-Object { $_.Name -ne 'rto-profile.schema.json' })
    if ($packs.Count -eq 1 -and $packs[0].Name -match '^rto-profile\.([^.]+)\.json$') {
        $TemplateRto = $Matches[1].ToUpperInvariant()
        $derived.Add("TemplateRto '$TemplateRto' - the one RTO profile pack in assets ($($packs[0].Name))")
    }
    else {
        Write-Host ("Run-Gates: {0} RTO profile pack(s) in assets - pass -TemplateRto to say whose approved templates the render used." -f $packs.Count) -ForegroundColor Red
        exit 2
    }
}
$savedRto = $Rto
. (Join-Path $scriptsDir 'Get-RtoProfile.ps1')
$Rto = $savedRto
$rtoProfile = Get-RtoProfile -Rto $TemplateRto -SkillDir $SkillDir
$templatePath = $rtoProfile.DeckTemplate
$numberSlotMap = Get-DeckNumberSlotMap -Profile $rtoProfile.DeckLayouts
$derived.Add(("TemplatePath '{0}' and NumberSlotByLayout ({1} layouts) from the {2} profile pack" -f (Split-Path $templatePath -Leaf), $numberSlotMap.Count, $TemplateRto))

# ---- the build brand's provider codes, variant-aware
if (-not $Rto -or -not $Cricos) {
    $branding = Get-Branding -Brand $Brand
    $vnode = $null
    if ($Variant -and (HasProp $branding 'variants') -and (HasProp $branding.variants $Variant)) { $vnode = $branding.variants.$Variant }
    if (-not $Rto) {
        $Rto = if ($vnode -and (HasProp $vnode 'rtoCode') -and $vnode.rtoCode) { [string]$vnode.rtoCode } else { [string]$branding.rto.rtoCode }
        $derived.Add("Rto '$Rto' from branding.$($Brand.ToLower()).json")
    }
    if (-not $Cricos) {
        $Cricos = if ($vnode -and (HasProp $vnode 'cricosCode') -and $vnode.cricosCode) { [string]$vnode.cricosCode } else { [string]$branding.rto.cricosCode }
        $derived.Add("Cricos '$Cricos' from branding.$($Brand.ToLower()).json")
    }
}
if (-not $Rto -or -not $Cricos) { Write-Host 'Run-Gates: the provider codes could not be derived - pass -Rto and -Cricos.' -ForegroundColor Red; exit 2 }

# ---- the artefacts
$outDir = Join-Path $BuildDir 'out'
function Find-Artefact {
    param([string] $Explicit, [string] $Suffix, [string] $What)
    if ($Explicit) {
        if (-not (Test-Path -LiteralPath $Explicit)) { throw "Run-Gates: $What not found: $Explicit" }
        return (Resolve-Path -LiteralPath $Explicit).Path
    }
    if ($UnitCode) {
        $p = Join-Path $outDir ("{0}{1}" -f $UnitCode, $Suffix)
        if (Test-Path -LiteralPath $p) { $derived.Add("$What '$(Split-Path $p -Leaf)' from out\ by unit code"); return $p }
    }
    $c = @(Get-ChildItem -LiteralPath $outDir -Filter ("*" + $Suffix) -File -ErrorAction SilentlyContinue)
    if ($c.Count -eq 1) { $derived.Add("$What '$($c[0].Name)' - the one match in out\"); return $c[0].FullName }
    if ($c.Count -gt 1) { throw ("Run-Gates: {0} candidate {1}s in out\ - pass the path explicitly." -f $c.Count, $What) }
    return $null
}
$Guide = Find-Artefact -Explicit $Guide -Suffix '_Learner_Guide.docx' -What 'Guide'
if (-not $Guide) { Write-Host "Run-Gates: no Learner Guide in $outDir - render first." -ForegroundColor Red; exit 2 }
$Deck = Find-Artefact -Explicit $Deck -Suffix '_Delivery_PowerPoint.pptx' -What 'Deck'
if (-not $Deck -and -not $SkipDeck) { Write-Host "Run-Gates: no deck in $outDir and -SkipDeck not given. A deck the runner cannot find is a deck nobody gated." -ForegroundColor Red; exit 2 }

# ---- the deck plan
if (-not $PlanPath) { $PlanPath = Join-Path $BuildDir 'deckplan.json' }
$plan = @()
if ($Deck -and -not $SkipDeck) {
    $pj = Read-JsonFile -Path $PlanPath
    if ($null -eq $pj) { Write-Host "Run-Gates: no deck plan at $PlanPath. Test-DeckRules cannot run its per-Topic, notes and chip rules without it - the render writes it beside the deck." -ForegroundColor Red; exit 2 }
    foreach ($e in @($pj)) {
        $h = @{}
        foreach ($pp in $e.PSObject.Properties) { $h[$pp.Name] = $pp.Value }
        $plan += $h
    }
    $derived.Add("Plan ($($plan.Count) slides) from $(Split-Path $PlanPath -Leaf)")
}

# ---- the pack references and the question pattern
$refs = Get-PackReference -Contract $contract -PackDir $PackDir -TaskFileMap $TaskFileMap -TaskIdPattern $TaskIdPattern
foreach ($n in $refs.Notes) { $derived.Add($n) }
$qp = $null
if ((HasProp $contract 'referenceConvention') -and (HasProp $contract.referenceConvention 'questionPattern')) { $qp = [string]$contract.referenceConvention.questionPattern }
if ($qp) { $derived.Add("QuestionPattern from contract.referenceConvention.questionPattern") }
else     { $derived.Add("QuestionPattern: none in the contract - Test-GuideRules applies its documented default") }

if (-not $UnitExtract) { $UnitExtract = Join-Path $BuildDir 'unit_extract.md' }
if (-not $MirrorScript)  { $MirrorScript  = Join-Path $scriptsDir 'Check-FigureMirror.ps1' }
if (-not $LeakageScript) { $LeakageScript = Join-Path $scriptsDir 'Check-FigureLeakage.ps1' }
$derived.Add("mirror gate: $MirrorScript")
$derived.Add("leakage gate: $LeakageScript")

$guideText = Join-Path $BuildDir 'guide_gate.txt'
$deckText  = Join-Path $BuildDir 'deck_gate.txt'

Write-Host ''
Write-Host ("RUN-GATES  {0}  brand {1}/{2}  {3}" -f $UnitCode, $Brand, $Variant, $(if ($AfterArtwork) { 'AFTER ARTWORK (Stage 7c)' } else { 'before artwork (Stage 4)' })) -ForegroundColor Cyan
Write-Host ("  pack references derived: {0} part-level, {1} task-level, {2} observation, {3} distinct" -f $refs.Part.Count, $refs.Task.Count, $refs.Observation.Count, $refs.All.Count) -ForegroundColor DarkGray
foreach ($d in $derived) { Write-Host ("  derived: {0}" -f $d) -ForegroundColor DarkGray }

$inputs = @{
    BuildDir = $BuildDir; SkillDir = $SkillDir; Guide = $Guide; Deck = $Deck
    PackRefs = $refs.All; QuestionPattern = $qp; AfterArtwork = [bool]$AfterArtwork
    TemplatePath = $templatePath; Plan = $plan; NumberSlotByLayout = $numberSlotMap
    Rto = $Rto; Cricos = $Cricos; Brand = $Brand; Variant = $Variant; UnitExtract = $UnitExtract
    MirrorScript = $MirrorScript; LeakageScript = $LeakageScript
    MirrorArgs = $MirrorArgs; LeakageArgs = $LeakageArgs
    GuideText = $guideText; DeckText = $deckText; DocTexts = @(); SkipDeck = [bool]$SkipDeck
}

# ---------------------------------------------------------------------------
# 7. Run - phase 1 fans out, phase 2 needs the extracts
# ---------------------------------------------------------------------------

$rc = 0
$timeout = $TimeoutMinutes * 60
$sw = [System.Diagnostics.Stopwatch]::StartNew()

$plan1 = New-GateInvocationPlan -Phase 1 -In $inputs
Write-Host ''
Write-Host ("  phase 1: {0} gate(s) {1}" -f @($plan1 | Where-Object { -not $_.Refused }).Count, $(if ($Serial) { 'one at a time' } else { 'in parallel' })) -ForegroundColor DarkGray
$res1 = Invoke-GatePlan -Plan $plan1 -SkillDir $SkillDir -TimeoutSeconds $timeout -Serial:$Serial

$docTexts = @()
foreach ($p in @($guideText, $deckText)) {
    $made = @($res1 | Where-Object { $_.Name -in @('extract-guide', 'extract-deck') -and $_.Ok })
    if ((Test-Path -LiteralPath $p) -and ($made | Where-Object { $_.Name -eq $(if ($p -eq $guideText) { 'extract-guide' } else { 'extract-deck' }) })) { $docTexts += $p }
}
$inputs['DocTexts'] = $docTexts

$plan2 = New-GateInvocationPlan -Phase 2 -In $inputs
Write-Host ("  phase 2: {0} gate(s) on {1} extract(s)" -f @($plan2 | Where-Object { -not $_.Refused }).Count, $docTexts.Count) -ForegroundColor DarkGray
$res2 = Invoke-GatePlan -Plan $plan2 -SkillDir $SkillDir -TimeoutSeconds $timeout -Serial:$Serial

# ---------------------------------------------------------------------------
# 8. One summary
# ---------------------------------------------------------------------------

$allPlan = @($plan1) + @($plan2)
$allRes  = @($res1) + @($res2)
foreach ($e in $allPlan) {
    $r = @($allRes | Where-Object { $_.Name -eq $e.Name })[0]
    Write-Host ''
    $tag = if ($r.Ok) { 'PASS' } else { 'FAIL' }
    $col = if ($r.Ok) { 'Green' } else { 'Red' }
    Write-Host ("{0}  [{1}]  {2}s" -f $e.Title, $tag, $r.Seconds) -ForegroundColor $col
    if ($e.Name -eq 'deck' -and $e.Refused -and $SkipDeck) {
        #  The only refusal that is not a failure: the caller said so, out loud.
        Write-Host ("    skipped by -SkipDeck - the deck was NOT gated in this run") -ForegroundColor Yellow
        continue
    }
    if (-not $r.Ok) { $rc = 1 }
    if ($r.Error) { Write-Host ("    X {0}" -f $r.Error) -ForegroundColor Red }
    Write-GateText -Text $r.Text
    if ($r.Partial -and @($r.Partial).Count -gt 0) {
        Write-Host ("    PARTIAL RUN - rules that checked nothing: {0}" -f (@($r.Partial) -join '; ')) -ForegroundColor Magenta
    }
}

Write-Host ''
Write-Host 'PARAMETERS THREADED TO EVERY GATE - nothing below was left to a default the gate would have failed on' -ForegroundColor Cyan
foreach ($ln in (Get-ThreadedParameterLine -Plan $allPlan)) {
    $col = if ($ln -match 'NOT RUN') { 'Red' } else { 'DarkGray' }
    Write-Host ("  " + $ln) -ForegroundColor $col
}

Write-Host ''
$failed = @($allRes | Where-Object { -not $_.Ok -and -not ($_.Name -eq 'deck' -and $SkipDeck) } | ForEach-Object { $_.Name })
if ($rc -eq 0) { Write-Host ("ALL GATES PASS  ({0} gate(s), {1}s)" -f $allRes.Count, [int]$sw.Elapsed.TotalSeconds) -ForegroundColor Green }
else           { Write-Host ("GATES FAILED: {0}  ({1}s)" -f ($failed -join ', '), [int]$sw.Elapsed.TotalSeconds) -ForegroundColor Red }
exit $rc
