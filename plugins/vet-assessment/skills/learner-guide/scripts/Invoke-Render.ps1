<#
    Invoke-Render.ps1 - Stage 4 and Stage 7 render: the Learner Guide and the
    Delivery PowerPoint from ONE spine, as two parallel processes, with no Word
    or PowerPoint anywhere in the path.

    THIS SCRIPT AUTHORS NOTHING. Every sentence, figure and diagram
    specification comes out of spine\*.json, and every derived table - the
    mapping matrix, the question cross-reference, the glossary, the practical
    activity index - is derived here from the spine and the contract, never
    typed, so it cannot fall out of step with the teaching.

    WHY TWO PROCESSES. Build-Guide splices OOXML into a fresh copy of the
    approved template; Pptx-Blocks clones and fills slides out of the approved
    deck template. Neither opens an Office application, neither shares a file
    with the other, and each takes a minute or more on a full unit - so they run
    as two Start-Job processes under one timeout, and this script joins them
    and prints both artefact paths and sizes. The two build-directory scripts
    this was promoted from ran one after the other. Each job runs THIS script
    again in -Worker mode, one artefact per process, which is how the render
    functions reach the job without being serialised into it.

    THE BRAND SWAP STAYS WHERE THE BUILD COPIES PUT IT: at render, on the fresh
    artefact, before any artwork. Both resources are rendered from the TEMPLATE
    RTO's approved templates and profiles, and the build brand is swapped on top
    - logo, palette, identity, rels - by Set-GuideBrand / Set-DeckBrand. It runs
    here because the logo setter sweeps every part that draws the mark and
    refuses to guess once the package is full of placed figures. Skip it and the
    guide ships in the template brand with every text gate green, because a text
    sweep cannot see an image - which is exactly what happened to a delivered
    assessment pack on 29 August 2026.

    HEADING LEVELS ARE LOAD-BEARING, because Test-GuideRules reads them:
      Heading1  "Topic N - ..." and every major front or back section
      Heading2  parts within a section
      Heading3  "N.M <criterion>" - the PC sub-section, page break before
      Heading4  the four prose sub-parts; "Underpinning knowledge" opens the
                block the 800-word floor is measured on

    WHAT WAS GENERALISED FROM THE BUILD COPIES, and how
      file names            <UnitCode>_Learner_Guide.docx / _Delivery_PowerPoint.pptx
      spine, output, plan   -SpineDir, -OutDir, -PlanPath (default build\spine,
                            build\out, build\deckplan.json)
      template and profiles the RTO profile pack (-TemplateRto, discovered when
                            the skill carries exactly one pack)
      brand, variant, unit  the contract, overridable
      deck owner            contract.build.tradingName, else the brand profile
      word guides           the PACK's content files, found by pattern and
                            labelled through the contract's referenceConvention
      chip label regex      built from the same reference labels
      cover figure slot     spine\cover.json, not a literal
      appendix kinds        an explicit "kind" on the appendix, else its title
      document control      contract.documentControl, else the template's own
                            footer values stand (the build copy typed a document
                            number and three dates into the renderer)
      house boilerplate     spine\front.json fields where present; the fixed
                            house wording the build copy carried stands in
                            otherwise and is reported as a NOTE when used. It is
                            house text, not unit content - the one unit-specific
                            sentence the build copy carried (a named Observation
                            as the exception to who completes a record) is NOT
                            carried; it belongs on the spine.

    WHAT COULD NOT BE GENERALISED WITHOUT A SPINE-SCHEMA DECISION is listed at
    the end of this header, so a reader knows the edges:
      - the section order and the fixed section titles of the guide (Unit
        overview, Mapping matrix, ...) are this document type's structure and
        are constants here, not spine fields;
      - the KE-to-PC mapping is read from contract.keMap.taughtAt as free text
        and parsed for N.M tokens, as the build copy did;
      - appendix rendering special-cases the glossary and the practical activity
        index (derived tables); every other appendix is a rows table with a
        heading map;
      - the self-check pointer wording, the "my summary" prompt and the
        observation word-guide line are house text with spine overrides
        (front.selfCheckPointer, front.mySummaryPrompt,
        front.assessmentOverview.observationWordGuide).

    Usage
      Invoke-Render.ps1 -BuildDir <dir> [-PackDir <dir>] [-UnitCode X] [-Brand ACI -Variant culinary]
                        [-OutDir <dir>] [-ImageDir <dir>] [-GuideOnly|-DeckOnly] [-TimeoutMinutes 20]
      Invoke-Render.ps1 -SelfTest        no Office, no build

    PS 5.1. ASCII only in this file. UTF-8 BOM required on disk.
    Exit 0 every requested artefact rendered and verified on disk; 1 otherwise;
    2 usage; 4 self-test failed.
#>

[CmdletBinding()]
param(
    [string] $BuildDir,
    [string] $PackDir,
    [string] $SkillDir = (Split-Path -Parent $PSScriptRoot),
    [string] $UnitCode,
    [string] $Brand,
    [string] $Variant,
    [string] $TemplateRto,
    [string] $SpineDir,
    [string] $OutDir,
    [string] $ImageDir,
    [string] $PlanPath,
    [hashtable] $TaskFileMap,
    [string] $TaskIdPattern = 'T(\d+)$',
    [switch] $GuideOnly,
    [switch] $DeckOnly,
    [int] $TimeoutMinutes = 20,
    #  Internal: render ONE artefact in this process. The parallel jobs call
    #  this script with -Worker; nobody else needs to.
    [switch] $Worker,
    [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'

function AsArr { param($x) if ($null -eq $x) { return @() } return @($x) }
function HasProp { param($o, [string] $n) if ($null -eq $o) { return $false } return (@($o.PSObject.Properties.Name) -contains $n) }

function Read-JsonFile {
    param([Parameter(Mandatory)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $t = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path, [System.Text.Encoding]::UTF8)
    $t = $t.TrimStart([char]0xFEFF)
    if (-not $t.Trim()) { return $null }
    return ($t | ConvertFrom-Json)
}

# ---------------------------------------------------------------------------
# The parallel job wrapper - generic, self-tested
# ---------------------------------------------------------------------------

function Invoke-ParallelJob {
    <#  Start every entry as a job, wait for all of them under ONE deadline,
        and return name -> result. An entry is @{ Name; Body (scriptblock);
        ArgumentList }. A job still running at the deadline is stopped and
        reported TimedOut; a job that threw is reported with its error. Nothing
        here hangs: the deadline is the longest this function can take.  #>
    param(
        [Parameter(Mandatory)] $Entries,
        [Parameter(Mandatory)][int] $TimeoutSeconds
    )
    $jobs = [ordered]@{}
    foreach ($e in $Entries) {
        $jobs[$e.Name] = Start-Job -Name $e.Name -ScriptBlock $e.Body -ArgumentList $e.ArgumentList
    }
    $null = Wait-Job -Job @($jobs.Values) -Timeout $TimeoutSeconds
    $out = [ordered]@{}
    foreach ($name in $jobs.Keys) {
        $j = $jobs[$name]
        if ($j.State -eq 'Completed') {
            $r = @(Receive-Job -Job $j -ErrorAction SilentlyContinue | Where-Object { $_ -and ($_.PSObject.Properties.Name -contains 'Ok') } | Select-Object -Last 1)
            if ($r.Count -eq 1) { $out[$name] = $r[0] }
            else { $out[$name] = [pscustomobject]@{ Ok = $false; Error = 'the job returned no result object'; TimedOut = $false } }
        }
        else {
            $timedOut = ($j.State -eq 'Running')
            if ($timedOut) { Stop-Job -Job $j -ErrorAction SilentlyContinue }
            $errText = ''
            try { $reason = $j.ChildJobs[0].JobStateInfo.Reason; if ($reason) { $errText = [string]$reason.Message } } catch { }
            if (-not $errText) { try { $null = Receive-Job -Job $j -ErrorAction Stop } catch { $errText = $_.Exception.Message } }
            $why = if ($timedOut) { "did not finish within $TimeoutSeconds s - job stopped" } else { "job ended in state $($j.State)" }
            if ($errText) { $why = $why + ' - ' + $errText }
            $out[$name] = [pscustomobject]@{ Ok = $false; Error = $why; TimedOut = $timedOut }
        }
        Remove-Job -Job $j -Force -ErrorAction SilentlyContinue
    }
    return $out
}

#  The body every render job runs: this script again, in -Worker mode, for one
#  artefact. Host lines are captured as text; the worker's one output object is
#  the artefact path.
$script:RenderJobBody = {
    param($ScriptPath, $ArgHash)
    $ErrorActionPreference = 'Stop'
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $lines = New-Object System.Collections.Generic.List[string]
    $path = $null
    $err = ''
    try {
        $a = @{}
        foreach ($k in $ArgHash.Keys) { $a[[string]$k] = $ArgHash[$k] }
        $a['Worker'] = $true
        $stream = & $ScriptPath @a 6>&1
        foreach ($o in @($stream)) {
            if ($o -is [System.Management.Automation.InformationRecord]) { $lines.Add([string]$o.MessageData) }
            elseif ($o -is [string]) { $path = $o }
        }
    }
    catch { $err = $_.Exception.Message }
    $ok = ($null -ne $path) -and (Test-Path -LiteralPath $path)
    if (-not $ok -and -not $err) { $err = 'the worker returned no artefact path' }
    [pscustomobject]@{ Ok = $ok; Path = $path; Text = ($lines -join "`n"); Error = $err; TimedOut = $false; Seconds = [int]$sw.Elapsed.TotalSeconds }
}


# ---------------------------------------------------------------------------
# Shared derivations (the reference-label logic is the same as Run-Gates.ps1
# carries - keep the two in step; they cannot share a file until the gate
# library's owner lifts it there)
# ---------------------------------------------------------------------------

function Get-ReferenceLabelSet {
    param([Parameter(Mandatory)] $Contract)
    $labels = [ordered]@{}
    if ((HasProp $Contract 'referenceConvention') -and $Contract.referenceConvention) {
        foreach ($p in $Contract.referenceConvention.PSObject.Properties) {
            if ($p.Name -like '_*') { continue }
            if ($p.Value -isnot [string]) { continue }
            if ($p.Value -notmatch '^[A-Za-z][A-Za-z ]*\{n\}(\(\{part\}\))?$') { continue }
            $labels[$p.Name] = ([string]$p.Value -replace '\s*\(\{part\}\)\s*', '').Trim()
        }
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
    }
    return $labels
}

function Resolve-TaskFileFamily {
    param([Parameter(Mandatory)][string] $Prefix, [Parameter(Mandatory)] $Labels, $Contract, [hashtable] $TaskFileMap)
    if ($TaskFileMap -and $TaskFileMap.ContainsKey($Prefix)) { return [string]$TaskFileMap[$Prefix] }
    if ($Contract -and (HasProp $Contract 'referenceConvention') -and (HasProp $Contract.referenceConvention 'contentFiles')) {
        $cf = $Contract.referenceConvention.contentFiles
        if (HasProp $cf $Prefix) { return [string]$cf.$Prefix }
    }
    $families = @($Labels.Keys | Where-Object { $_ -notmatch '(?i)observ' })
    if ($families.Count -eq 1) { return [string]$families[0] }
    $wb = @($families | Where-Object { $_ -match '(?i)work|recipe|wb' })
    $kn = @($families | Where-Object { $_ -match '(?i)know|uat|kt' })
    if ($Prefix -match '(?i)^(wb|workbook|recipe)' -and $wb.Count -gt 0) { return [string]$wb[0] }
    if ($kn.Count -gt 0) { return [string]$kn[0] }
    throw ("Invoke-Render: cannot tell which reference family the content file prefix '{0}' belongs to. Pass -TaskFileMap." -f $Prefix)
}

function Get-PackWordGuide {
    <#  "Knowledge Task 5" -> the word guide the pack sets for it, read off the
        pack's own content files. Derived, never typed.  #>
    param([Parameter(Mandatory)] $Contract, [Parameter(Mandatory)][string] $PackDir, [hashtable] $TaskFileMap, [string] $TaskIdPattern)
    $labels = Get-ReferenceLabelSet -Contract $Contract
    $out = @{}
    $contentDir = Join-Path $PackDir 'content'
    if (-not (Test-Path -LiteralPath $contentDir)) { throw "Invoke-Render: pack content directory missing: $contentDir" }
    foreach ($f in @(Get-ChildItem -LiteralPath $contentDir -Filter '*_tasks_*.json' -File | Sort-Object Name)) {
        $prefix = ($f.BaseName -split '_tasks_')[0]
        $fam = Resolve-TaskFileFamily -Prefix $prefix -Labels $labels -Contract $Contract -TaskFileMap $TaskFileMap
        if (-not $labels.Contains($fam)) { continue }
        $tmpl = [string]$labels[$fam]
        $j = Read-JsonFile -Path $f.FullName
        foreach ($it in (AsArr $j.items)) {
            if ([string]$it.id -match $TaskIdPattern) { $out[$tmpl.Replace('{n}', $Matches[1])] = [string](Get-Prop $it 'wordGuide') }
        }
    }
    return [pscustomobject]@{ WordGuide = $out; Labels = $labels }
}

function Get-Prop { param($o, [string] $n) if (HasProp $o $n) { return $o.$n } return $null }

function Get-ChipLabelRegex {
    <# '^(Knowledge Task|Workbook Task|Observation)\s*(.+)$' from the labels. #>
    param([Parameter(Mandatory)] $Labels)
    $alts = @()
    foreach ($k in $Labels.Keys) {
        $lab = ([string]$Labels[$k] -replace '\s*\{n\}\s*$', '').Trim()
        if ($lab) { $alts += [regex]::Escape($lab) }
    }
    if ($alts.Count -eq 0) { return '^(\S+(?:\s+\S+)*?)\s*(\d.*)$' }
    return ('^(' + ($alts -join '|') + ')\s*(.+)$')
}

function Get-AppendixKind {
    <#  glossary | practicalIndex | rows. An explicit "kind" wins; the title
        decides otherwise. The build copy keyed on appendix ids '5' and '7',
        which are this unit's numbering, not a schema.  #>
    param([Parameter(Mandatory)] $Appendix)
    $k = [string](Get-Prop $Appendix 'kind')
    if ($k) {
        if ($k -match '(?i)gloss') { return 'glossary' }
        if ($k -match '(?i)practical') { return 'practicalIndex' }
        return 'rows'
    }
    $t = [string](Get-Prop $Appendix 'title')
    if ($t -match '(?i)glossary') { return 'glossary' }
    if ($t -match '(?i)practical\s+activit') { return 'practicalIndex' }
    return 'rows'
}

# ---------------------------------------------------------------------------
# House text - boilerplate the build copy carried in its renderer. Each has a
# spine override; the fallback is reported when used. NONE of it names a unit,
# a task number, a brand or an RTO.
# ---------------------------------------------------------------------------

$script:HouseText = @{
    SelfCheckHeading = 'Where to find your self-check answers - Topic {n}'
    SelfCheckParas   = @(
        'Work each self-check question out from the teaching before you look anything up. That is what makes it useful.',
        'This guide does not print the answers. Your knowledge assessment is open book and you may have this guide with you, so an answer key here would be the marking guide on your desk, and your work would no longer be your own. The table below tells you which part of the guide answers each question. Re-read it, then answer again in your own words.',
        'If you still cannot get there, ask your trainer. That is not a failure; it is the point of a self-check.')
    SelfCheckRowNote = 'Re-read section {pc} - Underpinning knowledge for the reasoning, How to do it for the steps, and the Common errors box for what goes wrong.'
    MySummaryPrompt  = 'Write the three things from Topic {n} you most need to remember. Use your own words.'
    ObservationWordGuide = 'Your assessor completes this while you work, and you sign it at the end.'
}

# ---------------------------------------------------------------------------
# Context - everything both renderers need, resolved ONCE and printed
# ---------------------------------------------------------------------------

function Resolve-RenderContext {
    param([switch] $Quiet)
    if (-not $BuildDir) { throw 'Invoke-Render: -BuildDir is required.' }
    $bd = (Resolve-Path -LiteralPath $BuildDir).Path
    $sd = (Resolve-Path -LiteralPath $SkillDir).Path
    $notes = New-Object System.Collections.Generic.List[string]

    $contract = Read-JsonFile -Path (Join-Path $bd 'contract.json')
    if ($null -eq $contract) { throw "Invoke-Render: no contract.json in $bd" }

    $unit = $UnitCode
    if (-not $unit) { $unit = [string]$contract.unit.code; $notes.Add("UnitCode '$unit' from contract.unit.code") }
    $brand = $Brand
    if (-not $brand -and (HasProp $contract 'build')) { $brand = [string]$contract.build.brand; $notes.Add("Brand '$brand' from contract.build.brand") }
    $variant = $Variant
    if (-not $variant -and (HasProp $contract 'build')) { $variant = [string]$contract.build.variant; $notes.Add("Variant '$variant' from contract.build.variant") }
    $pack = $PackDir
    if (-not $pack -and (HasProp $contract 'build') -and (HasProp $contract.build 'packDir')) { $pack = [string]$contract.build.packDir; $notes.Add('PackDir from contract.build.packDir') }
    if (-not $pack -or -not (Test-Path -LiteralPath $pack)) { throw "Invoke-Render: pack directory not found: '$pack' - pass -PackDir." }

    $spine = $SpineDir
    if (-not $spine) { $spine = Join-Path $bd 'spine' }
    if (-not (Test-Path -LiteralPath $spine)) { throw "Invoke-Render: spine directory not found: $spine" }
    $out = $OutDir
    if (-not $out) { $out = Join-Path $bd 'out' }
    $planPath = $PlanPath
    if (-not $planPath) { $planPath = Join-Path $bd 'deckplan.json' }
    $images = $ImageDir
    if (-not $images) {
        $cand = Join-Path $bd 'images'
        if ((Test-Path -LiteralPath $cand) -and (Test-Path -LiteralPath (Join-Path $cand 'manifest.json'))) { $images = $cand; $notes.Add('ImageDir: build\images (a manifest is present)') }
    }

    $tRto = $TemplateRto
    if (-not $tRto) {
        $packs = @(Get-ChildItem -LiteralPath (Join-Path $sd 'assets') -Filter 'rto-profile.*.json' -File | Where-Object { $_.Name -ne 'rto-profile.schema.json' })
        if ($packs.Count -eq 1 -and $packs[0].Name -match '^rto-profile\.([^.]+)\.json$') { $tRto = $Matches[1].ToUpperInvariant(); $notes.Add("TemplateRto '$tRto' - the one RTO profile pack in assets") }
        else { throw ("Invoke-Render: {0} RTO profile pack(s) in assets - pass -TemplateRto to say whose approved templates to render from." -f $packs.Count) }
    }

    [pscustomobject]@{
        BuildDir = $bd; SkillDir = $sd; PackDir = $pack; SpineDir = $spine; OutDir = $out; PlanPath = $planPath; ImageDir = $images
        UnitCode = $unit; Brand = $brand; Variant = $variant; TemplateRto = $tRto; Contract = $contract
        GuideOut = (Join-Path $out ("{0}_Learner_Guide.docx" -f $unit))
        DeckOut  = (Join-Path $out ("{0}_Delivery_PowerPoint.pptx" -f $unit))
        Notes = @($notes)
    }
}

# ===========================================================================
# THE GUIDE RENDERER
# ===========================================================================

function Invoke-GuideRender {
    param([Parameter(Mandatory)] $Ctx)

    . (Join-Path $Ctx.SkillDir 'scripts\Lib-Resolve.ps1')
    . (Join-Path $Ctx.SkillDir 'scripts\Set-ResourceBrand.ps1')
    $savedRto = $Rto
    . (Join-Path $Ctx.SkillDir 'scripts\Get-RtoProfile.ps1')
    $rtoProfile = Get-RtoProfile -Rto $Ctx.TemplateRto -SkillDir $Ctx.SkillDir

    $GP = $rtoProfile.GuideProfile
    Set-HousePalette -Brand $Ctx.TemplateRto | Out-Null
    $script:CW = [int]$GP.page.contentWidthDxa
    Reset-GuideNumbering

    $contract = $Ctx.Contract
    $spineDir = $Ctx.SpineDir
    $OutPath  = $Ctx.GuideOut
    $front    = Read-JsonFile -Path (Join-Path $spineDir 'front.json')
    if ($null -eq $front) { throw "Invoke-Render: no front.json in $spineDir" }

    $topics = @{}; $subs = @{}
    foreach ($f in Get-ChildItem $spineDir -Filter 't*_*.json' -File) {
        $j = Read-JsonFile -Path $f.FullName
        if     ($f.Name -match '^t(\d+)_topic\.json$')     { $topics[[int]$Matches[1]] = $j }
        elseif ($f.Name -match '^t\d+_(\d+\.\d+)\.json$')  { $subs[$Matches[1]] = $j }
    }

    # Word guides come off the assessment pack itself, per Task - derived.
    $pw = Get-PackWordGuide -Contract $contract -PackDir $Ctx.PackDir -TaskFileMap $TaskFileMap -TaskIdPattern $TaskIdPattern
    $wordGuide = $pw.WordGuide
    Write-Host ("word guides: {0} task(s) read from the pack's content files" -f $wordGuide.Count) -ForegroundColor DarkGray

    # House text, spine override first
    $used = New-Object System.Collections.Generic.List[string]
    function House { param([string] $Key, $Override)
        if ($null -ne $Override -and "$Override".Trim()) { return $Override }
        [void]$used.Add($Key)
        return $script:HouseText[$Key]
    }
    $scp = Get-Prop $front 'selfCheckPointer'
    $selfCheckHeading = House 'SelfCheckHeading' (Get-Prop $scp 'heading')
    $selfCheckParas   = @(House 'SelfCheckParas' (Get-Prop $scp 'paras'))
    $selfCheckRowNote = House 'SelfCheckRowNote' (Get-Prop $scp 'rowNote')
    $mySummaryPrompt  = House 'MySummaryPrompt' (Get-Prop $front 'mySummaryPrompt')
    $obsWordGuide     = Get-Prop (Get-Prop $front 'assessmentOverview') 'observationWordGuide'
    if (-not $obsWordGuide -and (HasProp $contract 'referenceConvention')) { $obsWordGuide = Get-Prop $contract.referenceConvention 'observationWordGuide' }
    $obsWordGuide = House 'ObservationWordGuide' $obsWordGuide

    # --------------------------------------------------------------- helpers
    $script:PROSE_CAP = 300   # the readability cap Test-Readability measures against

    function Split-Long {
        <# Break a paragraph over the readability cap at sentence boundaries. #>
        param([string] $Text)
        $t = ([string]$Text).Trim()
        if ($t.Length -le $script:PROSE_CAP) { return @($t) }
        $parts = [regex]::Split($t, '(?<=[.!?])\s+')
        $out = New-Object System.Collections.Generic.List[string]
        $buf = ''
        foreach ($s in $parts) {
            if (-not $s) { continue }
            $cand = if ($buf) { "$buf $s" } else { $s }
            if ($buf -and $cand.Length -gt $script:PROSE_CAP) { $out.Add($buf); $buf = $s } else { $buf = $cand }
        }
        if ($buf) { $out.Add($buf) }
        return @($out)
    }

    function GProse {
        <# Paragraph array -> body XML. A leading "- " makes a real bullet. #>
        param($Paras)
        $xml = ''
        foreach ($p in (AsArr $Paras)) {
            $s = ([string]$p).Trim()
            if (-not $s) { continue }
            if ($s -match '^-\s+(.+)$') { $xml += HBullet -Text $Matches[1].Trim(); continue }
            $chunks = Split-Long -Text $s
            foreach ($c in $chunks) {
                $keep = ($c.EndsWith(':'))
                $xml += HBody -Text $c -KeepNext:$keep
            }
        }
        return $xml
    }

    function GNumListLong {
        <#  A decimal numbered list whose items may run past the readability cap.

            GNumList puts one paragraph per item, so an item over 300 characters
            renders as a single over-long paragraph and the readability gate
            fails it - correctly, because it is over-long on the page. Trimming
            is the wrong fix: these are self-check answer guides and procedure
            steps. So a long item is split at a SENTENCE boundary and its
            remainder rendered as a continuation paragraph at the list's own
            indent, carrying no numPr. Word numbers only paragraphs that carry
            numPr, so the continuation does not consume a number.  #>
        param([Parameter(Mandatory)][string[]] $Items, [int] $After = 100)
        if (-not $Items -or -not $Items.Count) { return '' }
        $numId = New-GuideNumId
        $xml = ''
        $i = 0
        foreach ($it in $Items) {
            $i++
            $chunks = @(Split-Long -Text ([string]$it))
            $first = $true
            foreach ($c in $chunks) {
                if ($first) {
                    $keep = if ($i -eq ($Items.Count - 1)) { '<w:keepNext/>' } else { '' }
                    $xml += '<w:p><w:pPr><w:pStyle w:val="ListParagraph"/>' + $keep +
                            "<w:numPr><w:ilvl w:val=`"0`"/><w:numId w:val=`"$numId`"/></w:numPr>" +
                            "<w:spacing w:after=`"$After`" w:line=`"276`" w:lineRule=`"auto`"/>" +
                            '</w:pPr><w:r><w:t xml:space="preserve">' + (ConvertTo-XmlText $c) + '</w:t></w:r></w:p>'
                    $first = $false
                }
                else {
                    # NOT styled ListParagraph: the readability gate requires every
                    # ListParagraph-styled paragraph to carry numPr, and a
                    # continuation is the rest of an item, not a new one. keepNext
                    # binds it to what follows so one answer is not split.
                    $xml += '<w:p><w:pPr><w:keepNext/>' +
                            "<w:spacing w:after=`"$After`" w:line=`"276`" w:lineRule=`"auto`"/>" +
                            '<w:ind w:left="720"/>' +
                            '</w:pPr><w:r><w:t xml:space="preserve">' + (ConvertTo-XmlText $c) + '</w:t></w:r></w:p>'
                }
            }
        }
        return $xml
    }

    function GTable {
        param([string[]] $Headers, [int[]] $Widths, [array] $Rows, [switch] $ShadeFirstCol, [int] $FontSize = 0)
        $x = HTable -Headers $Headers -Widths $Widths -Rows $Rows -ShadeFirstCol:$ShadeFirstCol -FontSize $FontSize
        return $x + (HSpacer -H 160)
    }

    function GVisual {
        <# Emit one spine visual entry as a prompt block at its declared placement. #>
        param($V)
        if (-not $V) { return '' }
        $kind = if ([string]$V.kind -eq 'Diagram') { 'Diagram' } else { 'Image' }
        $ga = @{ Kind = $kind; Figure = [string]$V.slot; Prompt = [string]$V.prompt }
        if ((HasProp $V 'caption') -and $V.caption) { $ga['Caption'] = [string]$V.caption }
        if ((HasProp $V 'alt')     -and $V.alt)     { $ga['Alt']     = [string]$V.alt }
        if ((HasProp $V 'aspect')  -and $V.aspect)  { $ga['Aspect']  = [string]$V.aspect }
        return (GImagePrompt @ga)
    }

    function Get-Visual { param($Sub, [string] $Suffix)
        foreach ($v in (AsArr $Sub.visuals)) { if (([string]$v.slot).EndsWith(".$Suffix")) { return $v } }
        return $null
    }

    $body = New-Object System.Text.StringBuilder
    function Add { param([string] $X) [void]$body.Append($X) }

    # =========================================================== UNIT OVERVIEW
    #  The section titles below are the fixed structure of this document type -
    #  the same in every unit's guide - and the first one is what the template
    #  profile declares as the seam (structure.bodyStartsAt).
    Add (GHeading -Level 1 -Text ([string]$GP.structure.bodyStartsAt) -Profile $GP)

    $cover = Read-JsonFile -Path (Join-Path $spineDir 'cover.json')
    if ($cover -and (HasProp $cover 'visual')) { Add (GVisual $cover.visual) }

    Add (GProse $front.unitOverview.aboutThisUnit)
    Add (GHeading -Level 2 -Text 'Where this work happens' -Profile $GP)
    Add (GProse $front.unitOverview.whereYouWillWork)
    Add (GHeading -Level 2 -Text 'Elements and performance criteria' -Profile $GP)
    Add (GProse @($front.unitOverview.elementsIntro))
    $w = HSplitWidth -Cols 2 -Weights @(30, 70)
    $rows = @()
    foreach ($e in (AsArr $front.unitOverview.elements)) {
        $rows += ,@(("$($e.n).  " + $e.title), ((AsArr $e.pcs) -join '||'))
    }
    Add (GTable -Headers @('Element', 'Performance criteria') -Widths $w -Rows $rows -ShadeFirstCol)
    Add (GHeading -Level 2 -Text 'Foundation skills' -Profile $GP)
    Add (GProse @($front.unitOverview.foundationSkillsIntro))
    Add (GProse (AsArr $front.unitOverview.foundationSkills | ForEach-Object { "- $_" }))

    # =========================================================== MAPPING MATRIX
    Add (GHeading -Level 1 -Text 'Mapping matrix' -PageBreakBefore -Profile $GP)
    Add (GProse @($front.mappingMatrix.intro))

    $keOf = @{}
    foreach ($p in ($contract.keMap.PSObject.Properties)) {
        foreach ($pcRef in ($p.Value.taughtAt -split '[ ,;()]+')) {
            if ($pcRef -match '^\d+\.\d+$') {
                if (-not $keOf.ContainsKey($pcRef)) { $keOf[$pcRef] = @() }
                $keOf[$pcRef] += $p.Name
            }
        }
    }
    $obsLabel = ''
    foreach ($k in $pw.Labels.Keys) { if ($k -match '(?i)observ') { $obsLabel = ([string]$pw.Labels[$k] -replace '\s*\{n\}\s*$', '').Trim() } }
    $obsRx = if ($obsLabel) { '^' + [regex]::Escape($obsLabel) + ' \d+$' } else { '^Observation \d+$' }

    $w = HSplitWidth -Cols 5 -Weights @(7, 36, 15, 11, 31)
    $rows = @()
    foreach ($t in (AsArr $contract.topics)) {
        # An observation checklist covers EVERY criterion in its element, not only
        # the criterion the question map hangs it on. The map records where a
        # thing is TAUGHT, one home each; the matrix records where it is
        # ASSESSED. Derived here from the element's own references.
        $elementObs = @()
        foreach ($pc in (AsArr $t.pcs)) {
            foreach ($r in (AsArr $subs[$pc].assessmentLink.refs)) {
                if (([string]$r) -match $obsRx) { $elementObs += [string]$r }
            }
        }
        $elementObs = @($elementObs | Sort-Object -Unique)

        foreach ($pc in (AsArr $t.pcs)) {
            $s = $subs[$pc]
            $ke = if ($keOf.ContainsKey($pc)) { ($keOf[$pc] | Sort-Object -Unique) -join ', ' } else { 'Performance only' }
            $refs = @(AsArr $s.assessmentLink.refs | ForEach-Object { [string]$_ })
            foreach ($o in $elementObs) { if ($refs -notcontains $o) { $refs += $o } }
            $rows += ,@($pc, [string]$s.title, ("Topic $($t.n), section $pc"), $ke, ($refs -join '||'))
        }
    }
    Add (GTable -Headers @('PC', 'Performance criterion', 'Taught in', 'KE', 'Assessed in') -Widths $w -Rows $rows -ShadeFirstCol -FontSize 18)

    $w = HSplitWidth -Cols 3 -Weights @(12, 58, 30)
    $rows = @()
    foreach ($p in ($contract.keMap.PSObject.Properties)) {
        $item = @($front.assessmentRequirements.part1.items | Where-Object { $_.ke -eq $p.Name })
        $txt = if ($item.Count) { [string]$item[0].text } else { '' }
        $rows += ,@($p.Name, $txt, ("Taught in section " + [string]$p.Value.taughtAt + "||Assessed in " + [string]$p.Value.assessedIn))
    }
    Add (GTable -Headers @('KE', 'Knowledge evidence', 'Where it is taught and assessed') -Widths $w -Rows $rows -ShadeFirstCol -FontSize 18)
    Add (GIconCallout -Profile $GP -Type note -Lines @([string]$front.mappingMatrix.note))

    # =========================================================== SEQUENCE MAP
    Add (GHeading -Level 1 -Text 'Assessment activity sequence map' -PageBreakBefore -Profile $GP)
    Add (GProse @($front.sequenceMap.intro))
    $w = HSplitWidth -Cols 3 -Weights @(8, 34, 58)
    $rows = @()
    foreach ($s in (AsArr $front.sequenceMap.stages)) { $rows += ,@([string]$s.stage, [string]$s.what, [string]$s.then) }
    Add (GTable -Headers @('Stage', 'What happens', 'What you do') -Widths $w -Rows $rows -ShadeFirstCol)
    Add (GIconCallout -Profile $GP -Type keyPoint -TitleSuffix ' - the records you complete' -Bullets (AsArr $front.sequenceMap.records))

    # =========================================================== ASSESSMENT REQUIREMENTS
    Add (GHeading -Level 1 -Text 'Assessment requirements' -PageBreakBefore -Profile $GP)
    Add (GProse @($front.assessmentRequirements.intro))

    Add (GHeading -Level 2 -Text $front.assessmentRequirements.part1.heading -Profile $GP)
    Add (GProse @($front.assessmentRequirements.part1.intro))
    $w = HSplitWidth -Cols 3 -Weights @(10, 62, 28)
    $rows = @()
    foreach ($i in (AsArr $front.assessmentRequirements.part1.items)) { $rows += ,@([string]$i.ke, [string]$i.text, [string]$i.task) }
    Add (GTable -Headers @('KE', 'What you must know', 'Assessed in') -Widths $w -Rows $rows -ShadeFirstCol -FontSize 18)

    Add (GHeading -Level 2 -Text $front.assessmentRequirements.part2.heading -Profile $GP)
    Add (GProse @($front.assessmentRequirements.part2.intro))
    $w = HSplitWidth -Cols 2 -Weights @(12, 88)
    $rows = @()
    foreach ($i in (AsArr $front.assessmentRequirements.part2.items)) { $rows += ,@([string]$i.pe, [string]$i.text) }
    Add (GTable -Headers @('PE', 'What you must be able to do') -Widths $w -Rows $rows -ShadeFirstCol -FontSize 18)

    Add (GHeading -Level 2 -Text 'What the assessor is looking for' -Profile $GP)
    Add (GProse $front.assessmentRequirements.whatTheAssessorLooksFor)
    Add (GIconCallout -Profile $GP -Type note -TitleSuffix ' - reasonable adjustment' -Lines (AsArr $front.assessmentRequirements.reasonableAdjustment))

    # =========================================================== INTRODUCTION
    Add (GHeading -Level 1 -Text 'Introduction' -PageBreakBefore -Profile $GP)
    Add (GProse $front.introduction.whatThisUnitIsAbout)
    Add (GHeading -Level 2 -Text 'Why it matters' -Profile $GP)
    Add (GProse $front.introduction.whyItMatters)
    Add (GHeading -Level 2 -Text 'How to use this guide' -Profile $GP)
    Add (GProse $front.introduction.howToUseThisGuide)
    Add (GHeading -Level 2 -Text 'Before you start this unit' -Profile $GP)
    Add (GProse $front.introduction.prerequisites)

    # =========================================================== WORKPLACE
    Add (GHeading -Level 1 -Text 'Your workplace for this guide' -PageBreakBefore -Profile $GP)
    Add (GProse $front.workplace.intro)
    Add (GHeading -Level 2 -Text 'The people you work with' -Profile $GP)
    Add (GProse @($front.workplace.peopleIntro))
    $w = HSplitWidth -Cols 2 -Weights @(32, 68)
    $rows = @()
    foreach ($p in (AsArr $front.workplace.people)) { $rows += ,@([string]$p.role, [string]$p.does) }
    Add (GTable -Headers @('Role', 'What they do') -Widths $w -Rows $rows -ShadeFirstCol)
    Add (GHeading -Level 2 -Text 'The production run' -Profile $GP)
    Add (GProse $front.workplace.theRun)
    Add (GHeading -Level 2 -Text 'Where the food goes' -Profile $GP)
    Add (GProse $front.workplace.destinations)
    Add (GHeading -Level 2 -Text 'The documents you work from' -Profile $GP)
    Add (GProse $front.workplace.documents)
    Add (GIconCallout -Profile $GP -Type keyPoint -TitleSuffix ' - carry this into every scenario' `
         -Lines @((AsArr $front.workplace.carryThisIntoEveryScenario)[0]) `
         -Bullets (AsArr $front.workplace.carryThisIntoEveryScenario | Select-Object -Skip 1 | ForEach-Object { ($_ -replace '^-\s+', '') }))

    # =========================================================== TOPICS
    foreach ($t in (AsArr $contract.topics)) {
        $n  = [int]$t.n
        $tp = $topics[$n]

        Add (GHeading -Level 1 -Text ("Topic $n - " + [string]$tp.title) -PageBreakBefore -Profile $GP)
        Add (GProse $tp.overview)

        Add (GHeading -Level 2 -Text 'Learning outcomes' -Profile $GP)
        Add (GNumListLong -Items (AsArr $tp.outcomes | ForEach-Object { [string]$_ }))

        Add (GIconCallout -Profile $GP -Type keyTerms -Bullets (AsArr $tp.keyTerms | ForEach-Object {
                $e = "$($_.term) - $($_.plain)"
                if ($_.example) { $e += " For example: $($_.example)" }
                $e }))
        Add (GIconCallout -Profile $GP -Type readBeforeYouStart -Lines (AsArr $tp.readBeforeYouStart))

        foreach ($pc in (AsArr $t.pcs)) {
            $s = $subs[$pc]

            Add (GHeading -Level 3 -Text ("$pc  " + [string]$s.title) -PageBreakBefore -Profile $GP)
            Add (GVisual (Get-Visual -Sub $s -Suffix '1'))

            Add (GHeading -Level 4 -Text 'What this means in practice' -Profile $GP)
            Add (GProse $s.whatThisMeans)
            Add (GIconCallout -Profile $GP -Type remember -Lines @([string]$s.remember))

            Add (GHeading -Level 4 -Text 'Underpinning knowledge' -Profile $GP)
            Add (GProse $s.underpinningKnowledge)

            Add (GHeading -Level 4 -Text 'Regulatory basis' -Profile $GP)
            Add (GProse $s.regulatoryBasis)

            Add (GHeading -Level 4 -Text 'How to do it' -Profile $GP)
            Add (GNumListLong -Items (AsArr $s.howToDoIt | ForEach-Object { "$($_.step) - $($_.detail)" }))
            Add (GVisual (Get-Visual -Sub $s -Suffix '2'))

            if ($s.workedExample) {
                $lines = @()
                if ($s.workedExample.intro) { $lines += [string]$s.workedExample.intro }
                Add (GIconCallout -Profile $GP -Type workedExample -Lines $lines -Bullets (AsArr $s.workedExample.lines))
                if ($s.workedExample.table -and (AsArr $s.workedExample.table.rows).Count) {
                    $hd = @(AsArr $s.workedExample.table.headers | ForEach-Object { [string]$_ })
                    $wd = HSplitWidth -Cols $hd.Count
                    $rr = @(); foreach ($r in (AsArr $s.workedExample.table.rows)) { $rr += ,@(@($r) | ForEach-Object { [string]$_ }) }
                    Add (GTable -Headers $hd -Widths $wd -Rows $rr -FontSize 18)
                }
            }

            Add (GVisual (Get-Visual -Sub $s -Suffix '3'))
            Add (GIconCallout -Profile $GP -Type caseStudy -Lines (Split-Long -Text ([string]$s.caseStudy.narrative)) `
                 -Bullets (AsArr $s.caseStudy.thinkItThrough))

            if ($s.practicalActivity) {
                $pa = $s.practicalActivity
                $lines = @()
                if ($pa.scenario) { $lines += (Split-Long -Text ([string]$pa.scenario)) }
                $bul = @()
                foreach ($x in (AsArr $pa.youWillNeed)) { $bul += "You will need: $x" }
                foreach ($x in (AsArr $pa.steps))       { $bul += [string]$x }
                foreach ($x in (AsArr $pa.doneWell))    { $bul += "Done well: $x" }
                if ($pa.pointsTo) { $lines += [string]$pa.pointsTo }
                Add (GIconCallout -Profile $GP -Type practicalActivity -Lines $lines -Bullets $bul)
                if ($pa.workedExampleTable -and (AsArr $pa.workedExampleTable.rows).Count) {
                    $hd = @(AsArr $pa.workedExampleTable.headers | ForEach-Object { [string]$_ })
                    $wd = HSplitWidth -Cols $hd.Count
                    $rr = @(); foreach ($r in (AsArr $pa.workedExampleTable.rows)) { $rr += ,@(@($r) | ForEach-Object { [string]$_ }) }
                    Add (GTable -Headers $hd -Widths $wd -Rows $rr -FontSize 18)
                }
            }

            # A role play renders only if it HAS something in it. `if ($s.rolePlay)`
            # is true for an object whose every field is empty, and that shipped
            # three blank Role play boxes once. Read EVERY field name the authors
            # actually used - Test-SpineRead finds the drift; this bends to it.
            if ($s.rolePlay) {
                $rp = $s.rolePlay
                function RpField { param($Node, [string[]] $Names)
                    foreach ($nm in $Names) {
                        if (@($Node.PSObject.Properties.Name) -notcontains $nm) { continue }
                        foreach ($v in (AsArr $Node.$nm)) { if ("$v".Trim()) { $v } }
                    }
                }
                $lines = @()
                foreach ($x in (RpField $rp @('scenario', 'situation'))) { $lines += (Split-Long -Text ([string]$x)) }
                $bul = @()
                foreach ($x in (RpField $rp @('roles', 'yourRole', 'otherRole', 'yourGoal'))) { $bul += [string]$x }
                foreach ($x in (RpField $rp @('steps', 'whatToSay', 'whatYouMustCover', 'prompts', 'phrases'))) { $bul += [string]$x }
                foreach ($x in (RpField $rp @('doneWell', 'whatGoodSoundsLike'))) { $bul += "Done well: $x" }
                foreach ($x in (RpField $rp @('commonMistakes'))) { $bul += "Avoid: $x" }
                if ($lines.Count -or $bul.Count) {
                    Add (GIconCallout -Profile $GP -Type rolePlay -Lines $lines -Bullets $bul)
                }
                else {
                    Write-Host ("  role play at $pc is empty and was not rendered") -ForegroundColor Yellow
                }
            }

            Add (GIconCallout -Profile $GP -Type commonErrors -Bullets (AsArr $s.commonErrors | ForEach-Object {
                    "$($_.error) Why it happens: $($_.why) What it costs: $($_.consequence)" }))

            Add (GVisual (Get-Visual -Sub $s -Suffix '4'))

            # Numbered in the box, so a learner can line their answer up against
            # the right pointer in the topic's answers table. The numbers are
            # written into the text because a callout is a single table cell,
            # where Word's own numbering indents wrongly.
            $qi = 0
            Add (GIconCallout -Profile $GP -Type selfCheck -Bullets (AsArr $s.selfCheck.questions | ForEach-Object {
                    $qi++; "$qi.  $_" }))
            Add (GIconCallout -Profile $GP -Type assessmentLink -Lines @([string]$s.assessmentLink.wording))
        }

        Add (GIconCallout -Profile $GP -Type topicSummary -Bullets (AsArr $tp.summary))
        Add (GIconCallout -Profile $GP -Type industryInsight -Lines (Split-Long -Text ([string]$tp.industryInsight)))
        Add (GIconCallout -Profile $GP -Type reflection -Lines (Split-Long -Text ([string]$tp.reflection)))
        Add (GIconCallout -Profile $GP -Type discussion -Lines (Split-Long -Text ([string]$tp.discussion)))
        Add (GIconCallout -Profile $GP -Type assessmentPrep -Bullets (AsArr $tp.assessmentPrep))

        Add (GIconCallout -Profile $GP -Type mySummary -Lines @(([string]$mySummaryPrompt).Replace('{n}', "$n")))
        Add (HTable -Headers @() -Widths (HSplitWidth -Cols 1) -Rows @(,@{ cells = @(''); height = 1400 }))
        Add (HSpacer -H 160)

        # SELF-CHECK: WHERE THE ANSWERS ARE, NOT WHAT THEY ARE. An open-book
        # knowledge assessment that permits the guide would otherwise have the
        # marking guide on the desk. The teaching stays; the pointer keeps the
        # formative loop; the block labelled as answers is gone.
        Add (GHeading -Level 2 -Text (([string]$selfCheckHeading).Replace('{n}', "$n")) -Profile $GP)
        Add (GProse @($selfCheckParas))
        $w = HSplitWidth -Cols 3 -Weights @(14, 34, 52)
        $rows = @()
        foreach ($pc in (AsArr $t.pcs)) {
            $s = $subs[$pc]
            $qn = (AsArr $s.selfCheck.questions).Count
            $range = if ($qn -gt 1) { "1 to $qn" } elseif ($qn -eq 1) { '1' } else { '-' }
            $rows += ,@($pc, [string]$s.title, ("Questions $range||" + ([string]$selfCheckRowNote).Replace('{pc}', $pc)))
        }
        Add (GTable -Headers @('Section', 'Sub-section', 'Where the answers are taught') -Widths $w -Rows $rows -ShadeFirstCol -FontSize 18)

        Add (GIconCallout -Profile $GP -Type furtherReading -Bullets (AsArr $tp.furtherReading))
    }

    # =========================================================== ASSESSMENT OVERVIEW
    Add (GHeading -Level 1 -Text 'Assessment overview' -PageBreakBefore -Profile $GP)
    Add (GProse $front.assessmentOverview.intro)
    Add (GHeading -Level 2 -Text 'How this guide names the assessment items' -Profile $GP)
    Add (GProse $front.assessmentOverview.referenceConvention)
    Add (GHeading -Level 2 -Text 'Question cross-reference' -Profile $GP)
    Add (GProse @($front.assessmentOverview.crossReferenceIntro))

    $w = HSplitWidth -Cols 4 -Weights @(24, 14, 22, 40)
    $rows = @()
    foreach ($t in (AsArr $contract.topics)) {
        foreach ($pc in (AsArr $t.pcs)) {
            $s = $subs[$pc]
            foreach ($r in (AsArr $s.assessmentLink.refs)) {
                $key = ([string]$r) -replace '\s*\([a-z]\)\s*$', ''
                $wg  = if ($wordGuide.ContainsKey($key)) { $wordGuide[$key] } else { [string]$obsWordGuide }
                $rows += ,@([string]$r, "Topic $($t.n)", "Section $pc", $wg)
            }
        }
    }
    Add (GTable -Headers @('Assessment item', 'Topic', 'Prepared in', 'Word guide the assessment sets') -Widths $w -Rows $rows -ShadeFirstCol -FontSize 18)
    Add (GIconCallout -Profile $GP -Type note -Lines @([string]$front.assessmentOverview.pointer))

    # =========================================================== APPENDICES
    foreach ($a in (AsArr $front.appendices)) {
        Add (GHeading -Level 1 -Text ([string]$a.title) -PageBreakBefore -Profile $GP)
        Add (GProse @($a.intro))
        $kind = Get-AppendixKind -Appendix $a

        if ($kind -eq 'glossary') {
            $terms = @{}
            foreach ($tn in ($topics.Keys | Sort-Object)) {
                foreach ($k in (AsArr $topics[$tn].keyTerms)) {
                    $key = ([string]$k.term).Trim()
                    if (-not $key) { continue }
                    if (-not $terms.ContainsKey($key)) {
                        $terms[$key] = [pscustomobject]@{ Term = $key; Plain = [string]$k.plain; Example = [string]$k.example; Topic = $tn }
                    }
                }
            }
            $w = HSplitWidth -Cols 3 -Weights @(20, 50, 30)
            $rows = @()
            foreach ($k in ($terms.Keys | Sort-Object)) {
                $e = $terms[$k]
                $rows += ,@($e.Term, $e.Plain, ("Topic $($e.Topic)||" + $e.Example))
            }
            Add (GTable -Headers @('Term', 'What it means', 'Where you meet it') -Widths $w -Rows $rows -ShadeFirstCol -FontSize 18)
            if ($a.note) { Add (GIconCallout -Profile $GP -Type note -Lines @([string]$a.note)) }
            continue
        }

        if ($kind -eq 'practicalIndex') {
            $w = HSplitWidth -Cols 4 -Weights @(12, 12, 40, 36)
            $rows = @()
            foreach ($t in (AsArr $contract.topics)) {
                foreach ($pc in (AsArr $t.pcs)) {
                    $s = $subs[$pc]
                    if (-not $s.practicalActivity) { continue }
                    $rows += ,@("Topic $($t.n)", $pc, [string]$s.practicalActivity.scenario, ((AsArr $s.assessmentLink.refs) -join '||'))
                }
            }
            Add (GTable -Headers @('Topic', 'Section', 'Practical activity', 'Prepares you for') -Widths $w -Rows $rows -ShadeFirstCol -FontSize 18)
            if ($a.note) { Add (GIconCallout -Profile $GP -Type note -Lines @([string]$a.note)) }
            continue
        }

        $rowsData = AsArr $a.rows
        if (-not $rowsData.Count) { continue }
        $keys = @($rowsData[0].PSObject.Properties.Name)
        $hdMap = @{ instrument = 'Instrument'; regulator = 'Who enforces it'; whatItDoes = 'What it does'
                    requires = 'What it requires'; document = 'Document'; purpose = 'What it is for'
                    usedIn = 'Where you meet it'; source = 'Source'; covers = 'What it covers' }
        $hd = @($keys | ForEach-Object { if ($hdMap.ContainsKey($_)) { $hdMap[$_] } else { $_ } })
        $wts = switch ($keys.Count) { 2 { @(34, 66) } 3 { @(26, 22, 52) } default { @(30, 70) } }
        $w = HSplitWidth -Cols $keys.Count -Weights $wts
        $rows = @()
        foreach ($r in $rowsData) { $rows += ,@($keys | ForEach-Object { [string]$r.$_ }) }
        Add (GTable -Headers $hd -Widths $w -Rows $rows -ShadeFirstCol -FontSize 18)
    }

    # =========================================================== DECLARATION
    Add (GHeading -Level 1 -Text $front.declaration.heading -PageBreakBefore -Profile $GP)
    Add (GProse $front.declaration.lines)
    Add (GIconCallout -Profile $GP -Type note -Lines @([string]$front.declaration.controlNote))

    # --------------------------------------------------------------- write
    $unit = @{
        Code          = [string]$contract.unit.code
        Title         = [string]$contract.unit.title
        Qualification = ([string]$contract.qualification.code + ' ' + [string]$contract.qualification.title)
        Release       = [string]$contract.unit.release
        AqfLevel      = ('AQF Level ' + [string]$contract.qualification.aqfLevel)
    }
    #  Document control comes from the contract or not at all. The build copy
    #  typed a document number and three dates into its renderer; with none
    #  declared, Set-GuideFooter keeps whatever the template carries, and the
    #  gate reports the footer divergence as it always has.
    $dc = Get-Prop $contract 'documentControl'
    if ($dc) {
        foreach ($pair in @(@('DocNumber', 'docNumber'), @('DocVersion', 'version'), @('RevisionDate', 'revisionDate'), @('NextReview', 'nextReview'))) {
            $v = Get-Prop $dc $pair[1]
            if ($v) { $unit[$pair[0]] = [string]$v }
        }
        Write-Host 'document control: from contract.documentControl' -ForegroundColor DarkGray
    }
    else { Write-Host 'NOTE: no contract.documentControl - the footer keeps the template''s own document number and dates' -ForegroundColor Yellow }

    if ($used.Count -gt 0) {
        Write-Host ("NOTE: house text used for {0} (no spine override in front.json)" -f (($used | Sort-Object -Unique) -join ', ')) -ForegroundColor Yellow
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutPath) | Out-Null
    $outFile = Write-GuideDocument -Unit $unit -BodyXml $body.ToString() -OutPath $OutPath -Profile $GP `
            -TemplatePath $rtoProfile.GuideTemplate -Confirm:$false

    # --------------------------------------------------------------- brand
    # Rendered from the TEMPLATE RTO's approved template and profile; the build
    # brand is swapped on the fresh render, before any artwork - see the header.
    if ($Ctx.Brand -and $Ctx.Brand -ne $Ctx.TemplateRto) {
        $br = Set-GuideBrand -Path $outFile -Brand $Ctx.Brand -Variant $Ctx.Variant -UnitCode $unit.Code
        Write-Host ("brand: {0}/{1} - logo parts {2}, palette refs {3}, identity refs {4}" -f `
            $br.Brand, $br.Variant, $br.Logo, $br.PaletteRefs, $br.IdentityRefs) -ForegroundColor Green
    }
    else { Write-Host ("brand: {0} is the template brand - no swap" -f $Ctx.TemplateRto) -ForegroundColor DarkGray }

    Write-Host "guide: $outFile  ($([math]::Round((Get-Item $outFile).Length / 1KB)) KB)" -ForegroundColor Green
    return $outFile
}

# ===========================================================================
# THE DECK RENDERER - from the SAME spine
# ===========================================================================

function Invoke-DeckRender {
    param([Parameter(Mandatory)] $Ctx)

    . (Join-Path $Ctx.SkillDir 'scripts\Lib-Resolve.ps1')
    . (Join-Path $Ctx.SkillDir 'scripts\Set-ResourceBrand.ps1')
    $savedRto = $Rto
    . (Join-Path $Ctx.SkillDir 'scripts\Get-RtoProfile.ps1')
    $rtoProfile = Get-RtoProfile -Rto $Ctx.TemplateRto -SkillDir $Ctx.SkillDir

    $DP  = $rtoProfile.DeckLayouts
    $TPL = $rtoProfile.DeckTemplate
    $OutPath  = $Ctx.DeckOut
    $ImageDir = $Ctx.ImageDir
    $contract = $Ctx.Contract
    $spineDir = $Ctx.SpineDir
    $frame    = Read-JsonFile -Path (Join-Path $spineDir 'deckframe.json')
    if ($null -eq $frame) { throw "Invoke-Render: no deckframe.json in $spineDir" }

    $topics = @{}; $subs = @{}
    foreach ($f in Get-ChildItem $spineDir -Filter 't*_*.json' -File) {
        $j = Read-JsonFile -Path $f.FullName
        if     ($f.Name -match '^t(\d+)_topic\.json$')    { $topics[[int]$Matches[1]] = $j }
        elseif ($f.Name -match '^t\d+_(\d+\.\d+)\.json$') { $subs[$Matches[1]] = $j }
    }

    # The deck's owner: the build's trading name, else the brand profile's.
    $owner = ''
    if (HasProp $contract 'build') { $owner = [string](Get-Prop $contract.build 'tradingName') }
    if (-not $owner -and $Ctx.Brand) {
        try {
            $b = Get-Branding -Brand $Ctx.Brand
            if ($Ctx.Variant -and (HasProp $b 'variants') -and (HasProp $b.variants $Ctx.Variant)) { $owner = [string](Get-Prop $b.variants.$($Ctx.Variant) 'tradingName') }
            if (-not $owner) { $owner = [string](Get-Prop $b.rto 'tradingName') }
        } catch { }
    }

    $deck = New-Deck -TemplatePath $TPL `
            -Title  ("$($contract.unit.code) $($contract.unit.title) - Delivery PowerPoint") `
            -Subject ("$($contract.qualification.code) $($contract.qualification.title)") `
            -Owner  $owner

    $plan = New-Object System.Collections.Generic.List[hashtable]

    # Keys that are metadata rather than a template slot.
    $META = @('layout', 'kind', 'notes', 'chip', 'tableRows', 'figureSlot', 'rows', 'tag', '_comment', '_taglineNote', 'fit')

    # Slide kinds that must point the room at the assessment: the deck profile's
    # notes-required kinds plus recap, which the delivery spec signposts too.
    $CHIP_KINDS = @('teaching', 'case-study', 'figures', 'process', 'table', 'assessment-link', 'recap')
    if ((HasProp $DP 'deckRules') -and (HasProp $DP.deckRules 'notesRequiredOn')) {
        $CHIP_KINDS = @(@(AsArr $DP.deckRules.notesRequiredOn | ForEach-Object { [string]$_ }) + @('recap') | Sort-Object -Unique)
    }

    $labels = Get-ReferenceLabelSet -Contract $contract
    $chipRx = Get-ChipLabelRegex -Labels $labels

    # The cover figure's slot, from the spine, for the manifest lookup below.
    $coverSlot = $null
    $cover = Read-JsonFile -Path (Join-Path $spineDir 'cover.json')
    if ($cover -and (HasProp $cover 'visual') -and (HasProp $cover.visual 'slot')) { $coverSlot = [string]$cover.visual.slot }

    function Get-ChipFor {
        <#  The short chip for a slide from its sub-section's OWN references.
            Authors nothing: refs off the spine, wording off the deck profile.
            NEVER "and 3 more" - the orientation slide promises every chip names
            the exact item, so a long list is grouped by instrument label with
            the item numbers listed after it, complete.  #>
        param([string[]] $Refs)
        $r = @($Refs | Where-Object { $_ })
        if (-not $r.Count) { return $null }
        $tmpl = [string]$DP.chip.wording
        if (-not $tmpl) { $tmpl = 'Prepares you for: {refs}' }
        $full = $tmpl.Replace('{refs}', ($r -join ', '))
        if ($full.Length -le 100) { return $full }
        $groups = [ordered]@{}
        foreach ($x in $r) {
            $m = [regex]::Match($x, $chipRx)
            if (-not $m.Success) { continue }
            $lab = $m.Groups[1].Value
            if (-not $groups.Contains($lab)) { $groups[$lab] = New-Object System.Collections.Generic.List[string] }
            $groups[$lab].Add($m.Groups[2].Value.Trim())
        }
        if (-not $groups.Count) { return $full }
        $parts = @()
        foreach ($lab in $groups.Keys) { $parts += ("{0} {1}" -f $lab, (($groups[$lab]) -join ', ')) }
        return $tmpl.Replace('{refs}', ($parts -join ' - '))
    }

    function Find-SlotPicture {
        <#  The guide's OWN picture for a figure slot, through the artwork
            manifest - the only thing that knows which generated file belongs to
            which slot. Matching a slot against a filename by string never
            succeeds, so every image slide silently fell back to text once.  #>
        param([string] $Want)
        if (-not $ImageDir -or -not $Want) { return $null }
        $mp = Join-Path $ImageDir 'manifest.json'
        if (-not (Test-Path -LiteralPath $mp)) { $mp = Join-Path (Split-Path -Parent $ImageDir) 'images\manifest.json' }
        if (-not (Test-Path -LiteralPath $mp)) { return $null }
        $man = Read-JsonFile -Path $mp
        $first = $true
        foreach ($e in (AsArr $man.placeholders)) {
            $slot = $null
            if ($e.caption -and ([string]$e.caption) -match 'Figure\s+(\d+(?:\.\d+)+)') { $slot = $Matches[1] }
            elseif ($first -and $coverSlot) { $slot = $coverSlot }
            $first = $false
            if ($slot -eq $Want -and $e.imageFile -and (Test-Path -LiteralPath ([string]$e.imageFile))) { return [string]$e.imageFile }
        }
        return $null
    }

    function Add-Slide {
        param(
            [Parameter(Mandatory)] $S,
            [string] $Tag,
            [int]    $Topic = 0,
            [string] $LayoutOverride,
            [string[]] $ChipFallbackRefs
        )
        $layout = if ($LayoutOverride) { $LayoutOverride } else { [string]$S.layout }
        $kind   = [string]$S.kind
        $picture = $null

        # The image layout needs a real picture. Without one, fall back to
        # single - an unfilled placeholder ships reading "Replace with image"
        # and the deck gate fails it, correctly. THE PICTURE IS THE ONE THE
        # GUIDE USES; never generate a second one for the deck.
        if ($layout -eq 'image') {
            if ((HasProp $S 'figureSlot') -and $S.figureSlot) { $picture = Find-SlotPicture -Want ([string]$S.figureSlot) }
            if (-not $picture) { $layout = 'single' }
        }

        $lay = $DP.layouts.PSObject.Properties | Where-Object { $_.Name -eq $layout } | Select-Object -First 1
        if (-not $lay) { throw "Slide '$Tag' names unknown layout '$layout'." }
        $slotNames = @($lay.Value.slots.PSObject.Properties | ForEach-Object { $_.Name })

        $content = @{}
        foreach ($p in $S.PSObject.Properties) {
            if ($META -contains $p.Name) { continue }
            if ($p.Name -like '_*') { continue }
            if ($slotNames -notcontains $p.Name) { continue }
            $v = $p.Value
            if ($null -eq $v) { continue }
            if ($v -is [array]) { $content[$p.Name] = @($v | ForEach-Object { [string]$_ }) }
            else { $content[$p.Name] = [string]$v }
        }

        # A fallback from image to single needs its caption folded into the lead.
        if ($layout -eq 'single' -and [string]$S.layout -eq 'image') {
            if (-not $content.ContainsKey('lead') -and (HasProp $S 'caption')) { $content['lead'] = [string]$S.caption }
            if (-not $content.ContainsKey('bullets') -and (HasProp $S 'bullets')) { $content['bullets'] = @(AsArr $S.bullets | ForEach-Object { [string]$_ }) }
        }

        # agenda rows -> n1..n5 / t1..t5
        if ($layout -eq 'agenda' -and (HasProp $S 'rows')) {
            $i = 0
            foreach ($r in (AsArr $S.rows)) {
                $i++
                if ($i -gt 5) { break }
                $content["n$i"] = [string]$r.n
                $content["t$i"] = [string]$r.t
            }
            for ($j = $i + 1; $j -le 5; $j++) { $content["n$j"] = ''; $content["t$j"] = '' }
        }

        $chip  = if ((HasProp $S 'chip')  -and $S.chip)  { [string]$S.chip }  else { $null }
        $notes = if ((HasProp $S 'notes') -and $S.notes) { [string]$S.notes } else { $null }
        if (-not $chip -and $ChipFallbackRefs -and ($CHIP_KINDS -contains $kind)) { $chip = Get-ChipFor -Refs $ChipFallbackRefs }

        $n = New-DeckSlide -Deck $deck -Profile $DP -Layout $layout -Content $content -Notes $notes -Chip $chip -Tag $Tag

        # table layout: fill the real PowerPoint table, then drop the spare rows
        if ($layout -eq 'table' -and (HasProp $S 'tableRows')) {
            $part = "ppt/slides/slide$n.xml"
            $xml  = Get-DocxPart -WorkDir $deck.WorkDir -Part $part
            $rows = AsArr $S.tableRows
            $r = 0
            foreach ($row in $rows) {
                $r++
                if ($r -gt 5) { break }
                $c = 0
                foreach ($cell in (AsArr $row)) {
                    $c++
                    if ($c -gt 3) { break }
                    $xml = Set-SlideTableCell -SlideXml $xml -Row $r -Column $c -Text ([string]$cell)
                }
            }
            for ($k = 5; $k -gt $r; $k--) { $xml = Remove-SlideTableRow -SlideXml $xml -Row $k }
            Set-DocxPart -WorkDir $deck.WorkDir -Part $part -Content $xml
        }

        if ($picture) {
            $ip = $DP.layouts.image.imagePlaceholder
            $fit = if ((HasProp $S 'fit') -and $S.fit) { [string]$S.fit } else { 'cover' }
            Set-SlidePicture -Deck $deck -SlideNumber $n -ImagePath $picture `
                -FrameShape ([int]$ip.frameShape) -RemoveShapes ([int[]]$ip.removeShapes) `
                -CaptionShape ([int]$ip.captionShape) -AltText ([string]$S.caption) -Fit $fit | Out-Null
        }

        $entry = @{ Tag = $Tag; Kind = $kind; LayoutSlide = [int]$lay.Value.slide }
        if ($Topic -gt 0) { $entry['Topic'] = $Topic }
        if ($lay.Value.PSObject.Properties.Name -contains 'verbatim' -and $lay.Value.verbatim) { $entry['Verbatim'] = $true }
        $plan.Add($entry)
        return $n
    }

    # ------------------------------------------------------------- framing, front
    Add-Slide -S $frame.title        -Tag 'title'                  | Out-Null
    Add-Slide -S $frame.housekeeping -Tag 'housekeeping'           | Out-Null
    Add-Slide -S $frame.agenda1      -Tag 'agenda 1'               | Out-Null
    Add-Slide -S $frame.agenda2      -Tag 'agenda 2'               | Out-Null
    Add-Slide -S $frame.orientation  -Tag 'assessment orientation' | Out-Null

    # ------------------------------------------------------------- topics
    foreach ($t in (AsArr $contract.topics)) {
        $n  = [int]$t.n
        $tp = $topics[$n]
        $topicSlides = AsArr $tp.slides

        foreach ($k in @('divider', 'outcomes', 'key-terms')) {
            foreach ($s in ($topicSlides | Where-Object { [string]$_.kind -eq $k })) {
                Add-Slide -S $s -Tag "T$n $k" -Topic $n | Out-Null
            }
        }

        $topicRefs = New-Object System.Collections.Generic.List[string]
        foreach ($pc in (AsArr $t.pcs)) {
            $sub = $subs[$pc]
            $subRefs = @(AsArr $sub.assessmentLink.refs | ForEach-Object { [string]$_ })
            foreach ($r in $subRefs) { $topicRefs.Add($r) }
            $i = 0
            foreach ($s in (AsArr $sub.slides)) {
                $i++
                Add-Slide -S $s -Tag "$pc slide $i" -Topic $n -ChipFallbackRefs $subRefs | Out-Null
            }
        }

        foreach ($s in ($topicSlides | Where-Object { [string]$_.kind -eq 'recap' })) {
            Add-Slide -S $s -Tag "T$n recap" -Topic $n -ChipFallbackRefs @($topicRefs) | Out-Null
        }

        $extras = @($topicSlides | Where-Object { @('divider', 'outcomes', 'key-terms', 'recap') -notcontains [string]$_.kind })
        foreach ($s in $extras) { Add-Slide -S $s -Tag "T$n extra" -Topic $n | Out-Null }
    }

    # ------------------------------------------------------------- briefing, close
    Add-Slide -S $frame.briefingIntro   -Tag 'briefing - what you produce' | Out-Null
    Add-Slide -S $frame.briefingRecords -Tag 'briefing - records'          | Out-Null
    Add-Slide -S $frame.briefingXref    -Tag 'briefing - cross-reference'  | Out-Null
    Add-Slide -S $frame.thanks          -Tag 'thanks'                      | Out-Null

    # ------------------------------------------------------------- number and save
    $num = Set-DeckSlideNumbers -Deck $deck -NumberSlotByLayout (Get-DeckNumberSlotMap -Profile $DP)
    Write-Host "numbered $($num.Numbered) slide(s); $($num.NoNumberByDesign) carry no number by design" -ForegroundColor DarkGray

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutPath) | Out-Null
    $deckPath = Save-Deck -Deck $deck -Path $OutPath

    # THE DECK TEMPLATE IS THE TEMPLATE RTO'S, AND EVERY FOOTER CARRIES ITS MARK,
    # NAME, RTO NUMBER AND CRICOS CODE. A title slide naming the build brand over
    # another RTO's footer is the defect a trainer meets in week one. Set-DeckBrand
    # swaps the mark holding its aspect ratio, remaps the palette by role across
    # every part, swaps the identity, and gates the result byte-level.
    if ($Ctx.Brand -and $Ctx.Brand -ne $Ctx.TemplateRto) {
        $br = Set-DeckBrand -Path $deckPath -Brand $Ctx.Brand -Variant $Ctx.Variant -UnitCode ([string]$contract.unit.code)
        Write-Host ("brand: {0}/{1} - logo redrawn on {2} part(s), {3} part(s) recoloured, {4} identity ref(s)" -f `
            $br.Brand, $br.Variant, $br.LogoPartsResized, $br.PartsRecolored, $br.IdentityRefs) -ForegroundColor Green
    }
    else { Write-Host ("brand: {0} is the template brand - no swap" -f $Ctx.TemplateRto) -ForegroundColor DarkGray }

    # The plan is what Test-DeckRules gates against; keep it where the gate runner looks.
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Ctx.PlanPath) | Out-Null
    $plan | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Ctx.PlanPath -Encoding UTF8

    Write-Host "deck: $deckPath  ($([math]::Round((Get-Item $deckPath).Length / 1KB)) KB, $($plan.Count) slides; plan at $($Ctx.PlanPath))" -ForegroundColor Green
    return $deckPath
}

# ---------------------------------------------------------------------------
# Self-test - no Office, no build
# ---------------------------------------------------------------------------

if ($SelfTest) {
    $pass = 0; $fail = 0
    function Ok  ($m) { $script:pass++; Write-Host "  PASS  $m" -ForegroundColor Green }
    function Bad ($m) { $script:fail++; Write-Host "  FAIL  $m" -ForegroundColor Red }
    Write-Host ''
    Write-Host 'Invoke-Render self-test' -ForegroundColor Cyan

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $r = Invoke-ParallelJob -TimeoutSeconds 60 -Entries @(
        [pscustomobject]@{ Name = 'guide'; Body = { param($x) Start-Sleep -Milliseconds 300; [pscustomobject]@{ Ok = $true; Path = "guide-$x" } }; ArgumentList = @('A') },
        [pscustomobject]@{ Name = 'deck';  Body = { param($x) Start-Sleep -Milliseconds 300; [pscustomobject]@{ Ok = $true; Path = "deck-$x" } };  ArgumentList = @('B') }
    )
    if ($r.Count -eq 2 -and $r['guide'].Ok -and $r['guide'].Path -eq 'guide-A' -and $r['deck'].Ok -and $r['deck'].Path -eq 'deck-B') { Ok 'the wrapper collects two results, each with its own output' } else { Bad ("two results: " + ($r | Out-String)) }

    $sw.Restart()
    $r2 = Invoke-ParallelJob -TimeoutSeconds 3 -Entries @(
        [pscustomobject]@{ Name = 'quick'; Body = { [pscustomobject]@{ Ok = $true; Path = 'q' } }; ArgumentList = @() },
        [pscustomobject]@{ Name = 'stuck'; Body = { Start-Sleep -Seconds 60; [pscustomobject]@{ Ok = $true } }; ArgumentList = @() }
    )
    if ($r2['quick'].Ok -and -not $r2['stuck'].Ok -and $r2['stuck'].TimedOut -and $sw.Elapsed.TotalSeconds -lt 30) { Ok ("a stub that overruns the timeout is stopped cleanly and the finished job's result is kept ({0:N1}s)" -f $sw.Elapsed.TotalSeconds) } else { Bad ("timeout: " + ($r2 | Out-String)) }
    if (@(Get-Job -Name 'stuck' -ErrorAction SilentlyContinue).Count -eq 0) { Ok 'the stopped job is removed' } else { Bad 'stopped job left behind'; Get-Job -Name 'stuck' | Remove-Job -Force }

    $r3 = Invoke-ParallelJob -TimeoutSeconds 30 -Entries @(
        [pscustomobject]@{ Name = 'throws'; Body = { throw 'planted failure' }; ArgumentList = @() }
    )
    if (-not $r3['throws'].Ok -and $r3['throws'].Error -match 'planted failure') { Ok 'a job that throws is reported with its error, not lost' } else { Bad ("throw: " + ($r3 | Out-String)) }

    # ---- the worker job body: a stub script standing in for this one
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('ir_selftest_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        $stub = Join-Path $tmp 'stub_worker.ps1'
        $art  = Join-Path $tmp 'X_Learner_Guide.docx'
        [System.IO.File]::WriteAllText($stub, "param([string] `$OutDir, [switch] `$Worker, [switch] `$GuideOnly)`r`nWrite-Host 'rendering'`r`n`$p = Join-Path `$OutDir 'X_Learner_Guide.docx'`r`n[System.IO.File]::WriteAllText(`$p, 'x')`r`n`$p`r`n", (New-Object System.Text.UTF8Encoding($true)))
        $r4 = Invoke-ParallelJob -TimeoutSeconds 60 -Entries @(
            [pscustomobject]@{ Name = 'guide'; Body = $script:RenderJobBody; ArgumentList = @($stub, @{ OutDir = $tmp; GuideOnly = $true }) }
        )
        if ($r4['guide'].Ok -and $r4['guide'].Path -eq $art -and $r4['guide'].Text -match 'rendering') { Ok 'the worker body captures host text and returns the artefact path it verified on disk' } else { Bad ("worker body: " + ($r4['guide'] | Out-String)) }
    }
    finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }

    # ---- derivations that need no build
    $lbl = [ordered]@{ knowledge = 'Knowledge Task {n}'; workbook = 'Workbook Task {n}'; observation = 'Observation {n}' }
    $rx = Get-ChipLabelRegex -Labels $lbl
    $m = [regex]::Match('Workbook Task 3(b)', $rx)
    if ($m.Success -and $m.Groups[1].Value -eq 'Workbook Task' -and $m.Groups[2].Value.Trim() -eq '3(b)') { Ok 'the chip label regex is built from the reference labels, not typed' } else { Bad "chip regex: $rx" }
    if ((Get-AppendixKind -Appendix ([pscustomobject]@{ id = '5'; title = 'Appendix 5 - Glossary' })) -eq 'glossary' -and
        (Get-AppendixKind -Appendix ([pscustomobject]@{ id = '7'; title = 'Appendix 7 - Practical activity index' })) -eq 'practicalIndex' -and
        (Get-AppendixKind -Appendix ([pscustomobject]@{ id = '9'; title = 'Anything'; kind = 'glossary' })) -eq 'glossary' -and
        (Get-AppendixKind -Appendix ([pscustomobject]@{ id = '1'; title = 'Appendix 1 - Legislation' })) -eq 'rows') { Ok 'appendix kinds come from an explicit kind, else the title, else a rows table' } else { Bad 'appendix kind derivation' }

    Write-Host ''
    Write-Host ("  {0} passed, {1} failed" -f $pass, $fail) -ForegroundColor $(if ($fail) { 'Red' } else { 'Green' })
    if ($fail) { exit 4 }
    exit 0
}

# ---------------------------------------------------------------------------
# Worker mode - one artefact, this process
# ---------------------------------------------------------------------------

if ($Worker) {
    if (-not ($GuideOnly -xor $DeckOnly)) { throw 'Invoke-Render -Worker renders exactly one artefact: pass -GuideOnly or -DeckOnly.' }
    $ctx = Resolve-RenderContext -Quiet
    if ($GuideOnly) { $p = Invoke-GuideRender -Ctx $ctx } else { $p = Invoke-DeckRender -Ctx $ctx }
    if (-not $p -or -not (Test-Path -LiteralPath $p)) { throw "the renderer reported '$p' but nothing is on disk there" }
    Write-Output ([string]$p)
    return
}

# ---------------------------------------------------------------------------
# Orchestrator - two processes, one deadline, one summary
# ---------------------------------------------------------------------------

if ($GuideOnly -and $DeckOnly) { Write-Host 'Invoke-Render: -GuideOnly and -DeckOnly together render nothing.' -ForegroundColor Red; exit 2 }
try { $ctx = Resolve-RenderContext }
catch { Write-Host ("Invoke-Render: {0}" -f $_.Exception.Message) -ForegroundColor Red; exit 2 }

Write-Host ''
Write-Host ("INVOKE-RENDER  {0}  brand {1}/{2} on {3} templates" -f $ctx.UnitCode, $ctx.Brand, $ctx.Variant, $ctx.TemplateRto) -ForegroundColor Cyan
foreach ($n in $ctx.Notes) { Write-Host ("  derived: {0}" -f $n) -ForegroundColor DarkGray }
Write-Host ("  spine: {0}" -f $ctx.SpineDir) -ForegroundColor DarkGray
Write-Host ("  out:   {0}" -f $ctx.OutDir) -ForegroundColor DarkGray
if ($ctx.ImageDir) { Write-Host ("  images: {0} (image slides carry the guide's pictures)" -f $ctx.ImageDir) -ForegroundColor DarkGray }
else { Write-Host '  images: none - image slides fall back to the single layout until artwork exists' -ForegroundColor DarkGray }

$common = @{ BuildDir = $ctx.BuildDir; PackDir = $ctx.PackDir; SkillDir = $ctx.SkillDir; UnitCode = $ctx.UnitCode
             TemplateRto = $ctx.TemplateRto; SpineDir = $ctx.SpineDir; OutDir = $ctx.OutDir; PlanPath = $ctx.PlanPath; TaskIdPattern = $TaskIdPattern }
if ($ctx.Brand)    { $common['Brand'] = $ctx.Brand }
if ($ctx.Variant)  { $common['Variant'] = $ctx.Variant }
if ($ctx.ImageDir) { $common['ImageDir'] = $ctx.ImageDir }
if ($TaskFileMap)  { $common['TaskFileMap'] = $TaskFileMap }

$entries = @()
if (-not $DeckOnly)  { $g = $common.Clone(); $g['GuideOnly'] = $true; $entries += [pscustomobject]@{ Name = 'guide'; Body = $script:RenderJobBody; ArgumentList = @($PSCommandPath, $g) } }
if (-not $GuideOnly) { $d = $common.Clone(); $d['DeckOnly']  = $true; $entries += [pscustomobject]@{ Name = 'deck';  Body = $script:RenderJobBody; ArgumentList = @($PSCommandPath, $d) } }

Write-Host ("  rendering {0} artefact(s) in parallel, {1} minute deadline" -f $entries.Count, $TimeoutMinutes) -ForegroundColor DarkGray
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$res = Invoke-ParallelJob -Entries $entries -TimeoutSeconds ($TimeoutMinutes * 60)

$rc = 0
foreach ($e in $entries) {
    $r = $res[$e.Name]
    Write-Host ''
    if ($r.Ok) {
        $size = (Get-Item -LiteralPath $r.Path).Length
        Write-Host ("{0}  [OK]  {1}s" -f $e.Name.ToUpper(), $r.Seconds) -ForegroundColor Green
        foreach ($ln in (([string]$r.Text) -split "`n")) { if ($ln.Trim()) { Write-Host ("    " + $ln.TrimEnd()) -ForegroundColor $(if ($ln -match '^\s*NOTE') { 'Yellow' } else { 'Gray' }) } }
        Write-Host ("    {0}  ({1:N0} KB)" -f $r.Path, [math]::Round($size / 1KB)) -ForegroundColor Green
    }
    else {
        $rc = 1
        Write-Host ("{0}  [FAILED]" -f $e.Name.ToUpper()) -ForegroundColor Red
        foreach ($ln in (([string]$r.Text) -split "`n")) { if ($ln.Trim()) { Write-Host ("    " + $ln.TrimEnd()) -ForegroundColor Gray } }
        Write-Host ("    X {0}" -f $r.Error) -ForegroundColor Red
    }
}

Write-Host ''
if ($rc -eq 0) { Write-Host ("RENDERED {0} artefact(s) in {1}s - gate them with Run-Gates.ps1 before anything else reads them" -f $entries.Count, [int]$sw.Elapsed.TotalSeconds) -ForegroundColor Green }
else           { Write-Host ("RENDER FAILED ({0}s)" -f [int]$sw.Elapsed.TotalSeconds) -ForegroundColor Red }
exit $rc
