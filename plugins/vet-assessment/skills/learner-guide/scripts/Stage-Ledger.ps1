<#
    Stage-Ledger.ps1

    Records which build stages actually ran, and refuses delivery when a
    blocking stage was skipped or has gone stale.

    WHY THIS EXISTS. Stages 5 and 6 are judgement stages: a person or an agent
    reads the document and reports what is wrong with it. Nothing in the file
    system changes when they are skipped, so every structural gate still passes
    and the build still looks finished. On 27 August 2026 a guide shipped with
    Stage 5 never run and Stage 6 reduced to a cross-reference check, and it
    carried a fabricated legal requirement to the page. No gate could have seen
    it, because a wrong temperature is well-formed XML.

    So the fact that a stage ran is itself recorded, and Stage 8 checks the
    record. A stage that ran and found nothing is a result. A stage with no
    record is a defect in the build.

    STALENESS, AND IT IS TWO RULES, NOT ONE. This is where a version of this
    file made a rule nobody could satisfy, which is how a check gets waived.

      A RE-RENDER (stages 4 and 7) assembles both artefacts from a fresh
      template, so everything a reader or a measuring gate said about the last
      document describes a document that no longer exists. Stages 4b, 5 and 6
      are therefore rejected as stale if they predate the newest render - and
      Stage 7's round re-runs all three, so the rule is satisfiable by design.

      A PLACEMENT (7b, and the 7c re-gate that follows it) changes what is on
      the page without changing a word of the prose: figure spaces stop being
      prompt blocks and become pictures with captions and alt text. What must
      postdate it is 7c - the whole gate set, readability included - and 7d,
      the confirming read of exactly what placement changed, plus at least one
      Stage 6-class verdict, which 7d is.

      STAGE 5 IS HELD TO THE RENDER SET AND NOT TO PLACEMENT, ON PURPOSE.
      Nothing in this pipeline re-runs the personas after placement, so a rule
      demanding a post-placement Stage 5 record could never be met by any build,
      and an unsatisfiable blocking rule is how a check ends up waived by
      whoever is holding the delivery. What placement changes is figure content,
      and that is read at 3d on the spine, again by the review band through the
      figure sheet, and again at 7d against the placed page.

    THE RENDER RULE IS NOW PER TOPIC, AND THAT IS WHAT MAKES IT SATISFIABLE.
    The rule above compared timestamps: any 4b, 5 or 6 record older than the
    newest render was stale, whole. On one build a one-word fix in Topic 3
    therefore invalidated the personas and the audit for all seven topics and
    forced a full re-review wave - 35 to 45 minutes - after every one of six
    rounds. The personas were in fact never re-run after round 1, because a
    rule that demands seven re-reads for one word is a rule nobody meets, and
    an unmet blocking rule is a rule that gets waived by whoever holds the
    delivery. So a review record may now say WHICH topics it covered and
    WHICH render it read, and the ledger holds it stale only for the topics
    whose rendered content has moved since:

      scripts\Assert-RenderDelta.ps1 hashes, per topic, the guide extract's
      slice, the deck extract's slides (by deckplan.json) and the figure
      sheet's slots, and writes render-delta.json; every delta it writes is
      also archived under render-deltas\<sha>.json so a record can be checked
      against the exact delta it was issued against, however many renders
      later. Add-StageRecord -Topics <n,n,..|all> -DeltaSha <sha> records the
      scope. Test-StageLedger compares that delta against the current one and
      reports "Stage 6 is stale for topics 1, 2, 3, 5, 7; current for 4, 6".
      Delivery still requires that NO topic is stale for the Stage 6-class
      read - the rule is narrowed to what changed, never weakened.

    A record with no topics and no deltaSha keeps the whole-artefact timestamp
    rule exactly as it was. Opting in is a claim about scope, and a claim is
    checked: the delta named must exist on disk and every topic named must be
    a topic that delta knows, or the record is refused at the point of writing.

    THE FIGURE SHEET IS AN INPUT TO EVERY LATER REVIEW, SO IT IS CHECKED HERE.
    It is generated at Stage 3d from the spine and is what makes a review record
    count as having read the figures. Stage 7 edits the spine. A sheet nobody
    regenerated then describes figures the document no longer has, and every
    reviewer downstream of it reads the wrong thing while the ledger says the
    figures were read. Test-StageLedger compares the sheet's stamped spine
    fingerprint against the spine on disk and blocks when they differ.

    Dot-source it, or run it directly to check a build directory.

    ASCII only in this file.
#>

[CmdletBinding()]
param(
    [string] $BuildDir,
    [switch] $Check
)

# Every stage that must have a record. Stage 7 is deliberately absent: a build
# with no findings needs no remediation round, so requiring one would push
# builds into inventing work. It still sorts into place when it does run.
#
# 3c, 3d, 4c, 6b, 7b-i, 7c and 7d were added when the pipeline gained them and
# this list did not. Every one of them is a blocking stage, and a build that
# skipped all seven passed this gate and delivered: the spine gate band never
# ran, nobody adjudicated a mirror anchor, the brand was never proved, a false
# finding went straight to a work order, the placed images were never reviewed,
# the post-placement re-gate never happened and no verdict was ever issued
# against a document that contained figures. Nothing else in the pipeline can
# see a judgement stage that did not run.
$script:LedgerRequired = @('0','1','2','3','3b','3c','3d','4','4b','4c','5','6','6b','7b-i','7b','7c','7d','8')
$script:LedgerOrder    = @('0','1','2','3','3b','3c','3d','4','4b','4c','5','6','6b','7','7b-i','7b','7c','7d','8')

# Renders assemble both artefacts from a fresh template; placements change the
# page without changing the prose. They invalidate different things, so they are
# two sets - see the header.
$script:LedgerRenders    = @('4','7')
$script:LedgerPlacements = @('7b','7c')
$script:LedgerStaleAfterRender    = @('4b','5','6')
$script:LedgerStaleAfterPlacement = @('7c','7d')

# At least one of these must postdate the newest placement. No build ships on a
# verdict issued against a document that had no figures in it.
$script:LedgerPostPlacementRead = @('6','7d')

# Stages whose absence stops delivery if they are recorded 'skipped'. 7b is not
# among them: with no API key, or where the user declines the artwork spend, a
# build legitimately delivers with the prompts in place and says so. Everything
# else here is a check, and a check is never skipped to save time.
$script:LedgerBlocking = @('3c','3d','4','4b','4c','5','6','6b','7b-i','7c','7d')

# A judgement stage that states no judgement is not a judgement stage.
$script:LedgerVerdict = @('6','7d')

# The per-topic render delta Assert-RenderDelta writes, and the archive every
# delta is copied into so a record's deltaSha can be resolved after any number
# of later renders. Both names are read by Assert-RenderDelta from here.
$script:LedgerDeltaFile    = 'render-delta.json'
$script:LedgerDeltaArchive = 'render-deltas'

function Get-LedgerPath {
    param([Parameter(Mandatory)][string] $BuildDir)
    Join-Path $BuildDir 'stage-ledger.json'
}

function New-StageLedger {
    <# Creates an empty ledger. Safe to call on an existing one - it will not overwrite. #>
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [Parameter(Mandatory)][string] $Unit
    )
    $p = Get-LedgerPath -BuildDir $BuildDir
    if (Test-Path -LiteralPath $p) { return $p }
    $obj = [pscustomobject]@{ unit = $Unit; created = (Get-Date).ToUniversalTime().ToString('o'); records = @() }
    $obj | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $p -Encoding UTF8
    return $p
}

function Add-StageRecord {
    <#
      Records one stage. Call it the moment the stage finishes, not at the end
      of the build - a record written from memory at the end is a record of
      what was intended, not of what happened.

      -Status  pass | fail | n-a | skipped
               'skipped' is honest and allowed; it just will not pass Test-StageLedger
               for a blocking stage. Use 'n-a' where the stage genuinely does not
               apply to this build, and always give -Note saying why - an 'n-a'
               with no note is a shrug, and Test-StageLedger rejects it.
      -Verdict Stages 6 and 7d: the compliance judgement, verbatim.
      -Findings Count of findings raised. Zero is a real result and is recorded as one.
      -Partial  Every blocking gate rule that could not run in this stage,
                verbatim from the gate's .Partial. A gate run with -AllowPartial
                returns them; passing them here is what turns an omission into a
                decision somebody signed. A partial record needs a -Note saying
                why, on the same rule as an allow-list entry.
      -Topics   Stages 4b, 5 and 6: the topics this record covered - numbers,
                or 'all'. Topic 0 is the front and back matter. With -Topics
                and no -DeltaSha the record is issued against the current
                render-delta.json.
      -DeltaSha The SHA256 of the render-delta.json the reviewer was handed
                (Assert-RenderDelta prints it). It must resolve to the current
                delta or to one in render-deltas\, or the record is refused:
                a scope nobody can check later is a scope, not a record. With
                -DeltaSha and no -Topics the scope is 'all'.
    #>
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [Parameter(Mandatory)][string] $Stage,
        [Parameter(Mandatory)][string] $Name,
        [ValidateSet('pass','fail','n-a','skipped')][string] $Status = 'pass',
        [int]    $Round    = 0,
        [int]    $Findings = 0,
        [string] $Verdict,
        [string] $Note,
        [string[]] $Partial,
        [string[]] $Topics,
        [string] $DeltaSha
    )
    $p = Get-LedgerPath -BuildDir $BuildDir
    if (-not (Test-Path -LiteralPath $p)) { throw "No stage ledger at $p. Call New-StageLedger first." }
    $l = Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json

    $rec = [ordered]@{
        stage    = $Stage
        name     = $Name
        status   = $Status
        round    = $Round
        findings = $Findings
        utc      = (Get-Date).ToUniversalTime().ToString('o')
    }
    if ($Verdict) { $rec.verdict = $Verdict }
    if ($Note)    { $rec.note    = $Note }
    if ($Partial -and @($Partial).Count) { $rec.partial = @($Partial) }

    # ---- per-topic scope, checked at the point of writing
    $topicsGiven = @($Topics | Where-Object { "$_".Trim() })
    if ($topicsGiven.Count -or $DeltaSha) {
        $set = Get-RenderDeltaSet -BuildDir $BuildDir
        if (-not $DeltaSha) {
            if (-not $set.CurrentSha) {
                throw ("Stage {0}: -Topics was given but {1} has no {2}, so there is no render to scope the record against. Run scripts\Assert-RenderDelta.ps1 after the render, then record the stage." -f $Stage, $BuildDir, $script:LedgerDeltaFile)
            }
            $DeltaSha = $set.CurrentSha
        }
        $resolved = Resolve-RenderDelta -Set $set -Sha $DeltaSha
        if ($null -eq $resolved) {
            throw ("Stage {0}: -DeltaSha '{1}' matches neither {2} nor any file in {3}\. A review record must name a delta that exists on disk, or nothing can later tell which topics it still covers." -f $Stage, $DeltaSha, $script:LedgerDeltaFile, $script:LedgerDeltaArchive)
        }
        $known = @(Get-RenderDeltaTopicKeys -Delta $resolved.Delta)
        if ($topicsGiven.Count -eq 0 -or @($topicsGiven | Where-Object { "$_" -match '^(?i)all$' }).Count) {
            $rec.topics = 'all'
        }
        else {
            $nums = New-Object System.Collections.Generic.List[int]
            foreach ($t in $topicsGiven) {
                foreach ($piece in ("$t" -split '[,\s]+' | Where-Object { $_ })) {
                    if ($piece -notmatch '^\d+$') { throw ("Stage {0}: -Topics entry '{1}' is not a topic number or 'all'." -f $Stage, $piece) }
                    if ($known -notcontains $piece) {
                        throw ("Stage {0}: -Topics names topic {1}, which delta {2} does not have (it has {3}). A record cannot cover a topic the render does not contain." -f $Stage, $piece, $resolved.Sha.Substring(0, 8), ($known -join ', '))
                    }
                    if ($nums -notcontains [int]$piece) { $nums.Add([int]$piece) }
                }
            }
            $rec.topics = @($nums | Sort-Object)
        }
        $rec.deltaSha = $resolved.Sha
    }

    $l.records = @($l.records) + [pscustomobject]$rec
    $l | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $p -Encoding UTF8
    Write-Verbose ("stage {0} recorded: {1}" -f $Stage, $Status)
}

# ---------------------------------------------------------------------------
# The render delta: reading it, resolving a record's deltaSha, and the ONE
# definition of "this topic moved". Assert-RenderDelta dot-sources this file
# so the delta it writes and the rule that reads it can never disagree.
# ---------------------------------------------------------------------------

function Read-LedgerJson {
    <# Explicit UTF-8, BOM dropped. PS 5.1 reads a BOM-less file as ANSI and chokes on a BOM left on a JSON string. #>
    param([Parameter(Mandatory)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $t = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path, [System.Text.Encoding]::UTF8).TrimStart([char]0xFEFF)
    if (-not $t.Trim()) { return $null }
    return ($t | ConvertFrom-Json)
}

function Get-RenderDeltaSha {
    <# SHA256 of a file's bytes, lower-case hex - the same value Get-FileHash prints. #>
    param([Parameter(Mandatory)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path).Path)
        return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLower()
    }
    finally { $sha.Dispose() }
}

function Get-DeltaMember {
    <#
      One member read for both shapes a delta arrives in: the [ordered]
      dictionaries Assert-RenderDelta builds in memory, and the PSCustomObjects
      ConvertFrom-Json returns from disk. A dictionary's PSObject.Properties
      are Count, Keys and Values - not its keys - so a single-shape reader
      silently sees no topics in one of the two and compares nothing.
    #>
    param($Object, [Parameter(Mandatory)][string] $Name)
    if ($null -eq $Object) { return $null }
    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $null
    }
    if (@($Object.PSObject.Properties.Name) -contains $Name) { return $Object.$Name }
    return $null
}

function Get-RenderDeltaTopicKeys {
    <# The topic keys a delta carries, numerically ordered, as strings. #>
    param($Delta)
    $topics = Get-DeltaMember -Object $Delta -Name 'topics'
    if ($null -eq $topics) { return @() }
    $keys = if ($topics -is [System.Collections.IDictionary]) { @($topics.Keys) } else { @($topics.PSObject.Properties.Name) }
    return @($keys | ForEach-Object { "$_" } | Sort-Object { [int]$_ })
}

function Get-RenderDeltaSet {
    <#
      The current render-delta.json (or $null), its sha, and the archive index
      sha -> path. Everything Test-StageLedger needs to place a record's
      deltaSha against the render on disk.
    #>
    param([Parameter(Mandatory)][string] $BuildDir)
    $path = Join-Path $BuildDir $script:LedgerDeltaFile
    $current = $null
    $sha = ''
    if (Test-Path -LiteralPath $path) {
        $current = Read-LedgerJson -Path $path
        $sha = Get-RenderDeltaSha -Path $path
    }
    $archive = @{}
    $dir = Join-Path $BuildDir $script:LedgerDeltaArchive
    if (Test-Path -LiteralPath $dir) {
        foreach ($f in (Get-ChildItem -LiteralPath $dir -Filter '*.json' -File)) {
            $k = [System.IO.Path]::GetFileNameWithoutExtension($f.Name).ToLower()
            if ($k -match '^[0-9a-f]{64}$') { $archive[$k] = $f.FullName }
        }
    }
    [pscustomobject]@{ Path = $path; Current = $current; CurrentSha = $sha; ArchiveDir = $dir; Archive = $archive }
}

function Resolve-RenderDelta {
    <#
      A deltaSha (full, or a unique prefix of 12+ hex characters) to the delta
      it names: the current one, or an archived one. $null when nothing on
      disk carries that sha - which is a fact the caller must not paper over.
    #>
    param([Parameter(Mandatory)] $Set, [string] $Sha)
    $s = "$Sha".Trim().ToLower()
    if (-not $s -or $s -notmatch '^[0-9a-f]{12,64}$') { return $null }
    if ($Set.CurrentSha -and $Set.CurrentSha.StartsWith($s)) {
        return [pscustomobject]@{ Sha = $Set.CurrentSha; Delta = $Set.Current; Path = $Set.Path; IsCurrent = $true }
    }
    $hits = @($Set.Archive.Keys | Where-Object { $_.StartsWith($s) })
    if ($hits.Count -ne 1) { return $null }
    $d = Read-LedgerJson -Path $Set.Archive[$hits[0]]
    if ($null -eq $d) { return $null }
    return [pscustomobject]@{ Sha = $hits[0]; Delta = $d; Path = $Set.Archive[$hits[0]]; IsCurrent = $false }
}

function Compare-RenderDeltaTopics {
    <#
      Which topics moved between two deltas. A topic has moved when ANY of its
      three hashes - guide slice, deck slides, figure-sheet slots - differs; a
      topic the newer delta has and the older does not is moved, because the
      record issued against the older one never saw it. The universe is the
      newer delta's topics; topics that vanished are reported separately.
    #>
    param([Parameter(Mandatory)] $From, [Parameter(Mandatory)] $To)
    $changed   = New-Object System.Collections.Generic.List[string]
    $unchanged = New-Object System.Collections.Generic.List[string]
    $why       = [ordered]@{}
    $fromKeys = @(Get-RenderDeltaTopicKeys -Delta $From)
    $fromTopics = Get-DeltaMember -Object $From -Name 'topics'
    $toTopics   = Get-DeltaMember -Object $To -Name 'topics'
    foreach ($t in (Get-RenderDeltaTopicKeys -Delta $To)) {
        $b = Get-DeltaMember -Object $toTopics -Name $t
        if ($fromKeys -notcontains $t) { $changed.Add($t); $why[$t] = 'new topic'; continue }
        $a = Get-DeltaMember -Object $fromTopics -Name $t
        $moved = New-Object System.Collections.Generic.List[string]
        foreach ($arm in @('guide', 'deck', 'figures')) {
            $av = "$(Get-DeltaMember -Object $a -Name $arm)".ToLower()
            $bv = "$(Get-DeltaMember -Object $b -Name $arm)".ToLower()
            if ($av -ne $bv) { $moved.Add($arm) }
        }
        if ($moved.Count) { $changed.Add($t); $why[$t] = ($moved -join '+') } else { $unchanged.Add($t) }
    }
    $toKeys = @(Get-RenderDeltaTopicKeys -Delta $To)
    $removed = @($fromKeys | Where-Object { $toKeys -notcontains $_ })
    [pscustomobject]@{
        Changed   = $changed.ToArray()
        Unchanged = $unchanged.ToArray()
        Removed   = $removed
        Why       = $why
    }
}

function Test-LedgerRecordScoped {
    <# Opted in to the per-topic rule: carries both a topics field and a deltaSha. #>
    param($Record)
    if ($null -eq $Record) { return $false }
    $names = @($Record.PSObject.Properties.Name)
    if ($names -notcontains 'topics' -or $names -notcontains 'deltaSha') { return $false }
    if ($null -eq $Record.topics -or -not "$($Record.deltaSha)".Trim()) { return $false }
    return $true
}

function Test-LedgerRecordCovers {
    <# Does this record claim a topic? A record with no scope claims every topic (the whole-artefact rule). #>
    param($Record, [string] $Topic)
    if (-not (Test-LedgerRecordScoped -Record $Record)) { return $true }
    $tv = $Record.topics
    if ($tv -is [string]) { return ($tv -match '^(?i)all$') }
    foreach ($x in @($tv)) { if ("$x" -eq $Topic) { return $true } }
    return $false
}

function Format-LedgerTopicList {
    param([string[]] $Topics)
    $t = @($Topics | Where-Object { $null -ne $_ -and "$_" -ne '' })
    if (-not $t.Count) { return 'none' }
    if (@($t | Where-Object { "$_" -notmatch '^\d+$' }).Count) { return ($t -join ', ') }
    return (($t | Sort-Object { [int]$_ }) -join ', ')
}

function Test-LedgerStageTopics {
    <#
      Per-topic currency for ONE stage. For every topic the current delta has,
      the newest record of the stage that covers it decides: a scoped record
      is current when its delta's hashes for that topic equal the current
      delta's; an unscoped record falls back to the timestamp rule; a topic no
      record covers is stale. Returns .Stale, .Current, .Reasons and .Problem
      (one sentence for the problem list, or '').
    #>
    param(
        [Parameter(Mandatory)][string] $Stage,
        [Parameter(Mandatory)] $Records,
        [Parameter(Mandatory)] $DeltaSet,
        [datetime] $LastRender
    )
    $sorted = @($Records | Sort-Object { [datetime]$_.utc } -Descending)
    $name = "$($sorted[0].name)"
    $newestSha = "$($sorted[0].deltaSha)"
    $short = if ($newestSha.Length -ge 8) { $newestSha.Substring(0, 8) } else { $newestSha }

    if ($null -eq $DeltaSet.Current) {
        return [pscustomobject]@{
            Stage = $Stage; Name = $name; Stale = @('all'); Current = @(); Reasons = @{}
            Problem = ("Stage {0} ({1}) is scoped by topic against delta {2}, but the build has no {3}. Run scripts\Assert-RenderDelta.ps1 after every render - without a current delta no per-topic record can be proved current, so the whole stage is treated as stale." -f $Stage, $name, $short, $script:LedgerDeltaFile)
        }
    }

    $reasons = [ordered]@{}
    $current = New-Object System.Collections.Generic.List[string]
    $cmpCache = @{}
    foreach ($t in (Get-RenderDeltaTopicKeys -Delta $DeltaSet.Current)) {
        $r = $null
        foreach ($cand in $sorted) { if (Test-LedgerRecordCovers -Record $cand -Topic $t) { $r = $cand; break } }
        if ($null -eq $r) { $reasons[$t] = 'no record of this stage covers it'; continue }

        if (-not (Test-LedgerRecordScoped -Record $r)) {
            if ($LastRender -and ([datetime]$r.utc) -lt $LastRender) {
                $reasons[$t] = ("covered only by the whole-artefact record of {0}, which predates the render at {1}" -f ([datetime]$r.utc).ToString('u'), $LastRender.ToString('u'))
            }
            else { $current.Add($t) }
            continue
        }

        $sha = "$($r.deltaSha)".Trim().ToLower()
        if ($sha -eq $DeltaSet.CurrentSha) { $current.Add($t); continue }
        if (-not $cmpCache.ContainsKey($sha)) {
            $from = Resolve-RenderDelta -Set $DeltaSet -Sha $sha
            if ($null -eq $from) { $cmpCache[$sha] = $null }
            else { $cmpCache[$sha] = Compare-RenderDeltaTopics -From $from.Delta -To $DeltaSet.Current }
        }
        $cmp = $cmpCache[$sha]
        $s8 = if ($sha.Length -ge 8) { $sha.Substring(0, 8) } else { $sha }
        if ($null -eq $cmp) {
            $reasons[$t] = ("issued against delta {0}, which is neither {1} nor in {2}\, so it cannot be proved current" -f $s8, $script:LedgerDeltaFile, $script:LedgerDeltaArchive)
        }
        elseif ($cmp.Changed -contains $t) {
            $reasons[$t] = ("rendered content moved ({0}) since delta {1}" -f $cmp.Why[$t], $s8)
        }
        else { $current.Add($t) }
    }

    $problem = ''
    if ($reasons.Count) {
        $groups = [ordered]@{}
        foreach ($k in $reasons.Keys) {
            $why = $reasons[$k]
            if (-not $groups.Contains($why)) { $groups[$why] = New-Object System.Collections.Generic.List[string] }
            $groups[$why].Add($k)
        }
        $detail = @()
        foreach ($why in $groups.Keys) { $detail += ("topic(s) {0}: {1}" -f (Format-LedgerTopicList -Topics $groups[$why].ToArray()), $why) }
        $problem = ("Stage {0} ({1}) is stale for topics {2}; current for {3}. {4}. Re-run it for the stale topics against the current render and record the result with -Topics and -DeltaSha." -f `
            $Stage, $name, (Format-LedgerTopicList -Topics @($reasons.Keys)), (Format-LedgerTopicList -Topics $current.ToArray()), ($detail -join '; '))
    }
    [pscustomobject]@{
        Stage = $Stage; Name = $name
        Stale = @($reasons.Keys | Sort-Object { [int]$_ })
        Current = @($current.ToArray() | Sort-Object { [int]$_ })
        Reasons = $reasons
        Problem = $problem
    }
}

function Test-FigureSheetCurrent {
    <#
      The figure sheet must still describe the spine the documents were rendered
      from. Returns .Ok, .Problems, .Sheet, .Expected and .Stamped.

      WHY IT IS A LEDGER RULE AND NOT A NOTE IN A DOCUMENT. The sheet is
      generated at Stage 3d and then travels with every later review pack, and
      the channel-disposition rule counts a Stage 5 or Stage 6 record as having
      read the figures if the figure sheet accompanied the extract. Stage 7
      edits the spine and nothing regenerated the sheet, so a reviewer could be
      handed - in good faith, and with the ledger agreeing - a figure sheet
      describing figures the document no longer contains. Regenerate it with
      scripts\New-FigureSheet.ps1 after every spine edit.
    #>
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [string] $SheetPath,
        [string] $SpineDir
    )

    if (-not $SheetPath) { $SheetPath = Join-Path $BuildDir 'figure-sheet.txt' }
    if (-not $SpineDir)  { $SpineDir  = Join-Path $BuildDir 'spine' }

    $problems = @()
    $expected = ''
    $stamped  = ''

    if (-not (Test-Path -LiteralPath $SpineDir)) {
        $problems += "No spine directory at $SpineDir, so the figure sheet cannot be proved current. Every gate in the 3c band reads the spine; a build without one has nothing for them to read."
    }
    elseif (-not (Test-Path -LiteralPath $SheetPath)) {
        $problems += "No figure sheet at $SheetPath. Stage 3d emits it and every later review pack carries it - without it no review record can claim to have read the figures. Generate it with scripts\New-FigureSheet.ps1."
    }
    else {
        if (-not (Get-Command Get-SpineFingerprint -ErrorAction SilentlyContinue)) {
            . (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')
        }
        $expected = Get-SpineFingerprint -BuildDir $BuildDir -SpineDir $SpineDir
        $text = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $SheetPath).Path, [System.Text.Encoding]::UTF8)
        if ($text -match '(?im)^\s*SPINE-FINGERPRINT:\s*([0-9a-f]{8,})\s*$') { $stamped = $Matches[1].ToLower() }

        if (-not $stamped) {
            $problems += "The figure sheet at $SheetPath carries no SPINE-FINGERPRINT stamp, so nothing can tell whether it still describes this spine. Regenerate it with scripts\New-FigureSheet.ps1."
        }
        elseif ($expected -and $stamped -ne $expected) {
            $problems += ("The figure sheet at {0} was cut from spine {1} and the spine is now {2}. It is stale: every reviewer downstream of it read figure content this document no longer carries. Regenerate it with scripts\New-FigureSheet.ps1 and re-run any review that was handed the old one." -f $SheetPath, $stamped, $expected)
        }
    }

    [pscustomobject]@{
        Ok       = ($problems.Count -eq 0)
        Problems = $problems
        Sheet    = $SheetPath
        Expected = $expected
        Stamped  = $stamped
    }
}

function Test-StageLedger {
    <#
      Returns a result object with .Ok and .Problems. Run it in Stage 8, before
      reporting delivery.
    #>
    param([Parameter(Mandatory)][string] $BuildDir)

    $problems = @()
    $p = Get-LedgerPath -BuildDir $BuildDir
    if (-not (Test-Path -LiteralPath $p)) {
        return [pscustomobject]@{
            Ok = $false
            Problems = @('No stage ledger exists. There is no record that any review stage ran, so delivery cannot be confirmed.')
            Records = @()
        }
    }

    $l    = Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json
    $recs = @($l.records)

    # Latest record per stage wins - a later round supersedes an earlier one.
    $latest = @{}
    foreach ($r in $recs) {
        $s = [string]$r.stage
        if (-not $latest.ContainsKey($s) -or
            ([datetime]$r.utc) -gt ([datetime]$latest[$s].utc)) { $latest[$s] = $r }
    }

    foreach ($s in $script:LedgerRequired) {
        if (-not $latest.ContainsKey($s)) {
            $problems += "Stage $s has no record. It either did not run or was not recorded; either way delivery cannot claim it."
            continue
        }
        $r = $latest[$s]
        if ($r.status -eq 'fail') {
            $problems += "Stage $s ($($r.name)) is recorded as FAILED and was never brought to pass."
        }
        elseif ($r.status -eq 'skipped' -and $script:LedgerBlocking -contains $s) {
            $n = if ($r.note) { " - $($r.note)" } else { '' }
            $problems += "Stage $s ($($r.name)) is recorded as SKIPPED and it is a blocking stage$n"
        }
    }

    # 'n-a' is the honest answer for a stage that genuinely does not apply, and
    # it is also the easiest way to rubber-stamp one that does. It costs a
    # written reason, exactly as an allow-list entry does.
    foreach ($r in $recs) {
        if ("$($r.status)" -eq 'n-a' -and -not $r.note) {
            $problems += "Stage $($r.stage) ($($r.name)) is recorded as 'n-a' with no note. A stage that does not apply must say why it does not apply."
        }
    }

    # A gate run with -AllowPartial left blocking rules unrun. That is allowed
    # and it is recorded, but it is not free: it needs the same written reason
    # an allow-list entry needs, and the report has to carry it.
    foreach ($r in $recs) {
        $p = @($r.partial) | Where-Object { $_ }
        if ($p.Count -and -not $r.note) {
            $problems += ("Stage {0} ({1}) recorded {2} gate rule(s) that checked nothing - {3} - and no note saying why. A partial gate run is a decision, and a decision needs a written reason." -f `
                $r.stage, $r.name, $p.Count, ($p -join '; '))
        }
    }

    # ---- staleness, in two classes. See the file header.
    $renderTimes = @()
    foreach ($s in $script:LedgerRenders) {
        if ($latest.ContainsKey($s)) { $renderTimes += [datetime]$latest[$s].utc }
    }
    $topicStaleness = [ordered]@{}
    if ($renderTimes.Count) {
        $lastRender = ($renderTimes | Sort-Object -Descending)[0]
        $deltaSet = $null
        foreach ($s in $script:LedgerStaleAfterRender) {
            if (-not $latest.ContainsKey($s)) { continue }

            # The newest record decides which rule applies. A record that names
            # no topics and no delta is judged whole, by time, exactly as before.
            if (-not (Test-LedgerRecordScoped -Record $latest[$s])) {
                if (([datetime]$latest[$s].utc) -lt $lastRender) {
                    $problems += ("Stage {0} ({1}) ran at {2} but the artefacts were re-rendered at {3}. That verdict is stale - re-run it against the current documents." -f `
                        $s, $latest[$s].name, ([datetime]$latest[$s].utc).ToString('u'), $lastRender.ToString('u'))
                }
                continue
            }

            # A scoped record is judged per topic against the render delta on
            # disk. Every record of the stage takes part, newest first, so a
            # scoped re-review of the changed topics sits on top of the earlier
            # record that still covers the unchanged ones.
            if ($null -eq $deltaSet) { $deltaSet = Get-RenderDeltaSet -BuildDir $BuildDir }
            $v = Test-LedgerStageTopics -Stage $s -Records @($recs | Where-Object { [string]$_.stage -eq $s }) -DeltaSet $deltaSet -LastRender $lastRender
            $topicStaleness[$s] = $v
            if ($v.Problem) { $problems += $v.Problem }
        }
    }

    $placeTimes = @()
    foreach ($s in $script:LedgerPlacements) {
        if ($latest.ContainsKey($s) -and "$($latest[$s].status)" -ne 'n-a') { $placeTimes += [datetime]$latest[$s].utc }
    }
    if ($placeTimes.Count) {
        $lastPlace = ($placeTimes | Sort-Object -Descending)[0]
        foreach ($s in $script:LedgerStaleAfterPlacement) {
            if (-not $latest.ContainsKey($s)) { continue }
            if ("$($latest[$s].status)" -eq 'n-a') { continue }
            if (([datetime]$latest[$s].utc) -lt $lastPlace) {
                $problems += ("Stage {0} ({1}) ran at {2} but artwork was placed at {3}. Placement is the last mutation of both artefacts and it is followed by the WHOLE gate set, never a subset - re-run it." -f `
                    $s, $latest[$s].name, ([datetime]$latest[$s].utc).ToString('u'), $lastPlace.ToString('u'))
            }
        }

        # And the half of the rule that cannot be met by re-running a script: a
        # human-class verdict issued against a document that actually has
        # figures in it. Stage 7d is that read, scoped to what placement changed.
        $read = @($script:LedgerPostPlacementRead | Where-Object {
                     $latest.ContainsKey($_) -and "$($latest[$_].status)" -ne 'n-a' -and
                     ([datetime]$latest[$_].utc) -ge $lastPlace })
        if (-not $read.Count) {
            $problems += ("No Stage 6-class read postdates the newest placement at {0}. Delivery requires a Stage 6 re-audit or the Stage 7d confirming read AFTER placement - no build ships on a verdict issued against a document that had no figures in it." -f $lastPlace.ToString('u'))
        }
    }

    # Stages 6 and 7d must each carry an actual verdict, and neither may be a
    # failing one. An audit without a stated judgement is not an audit, and a
    # confirming read that confirms nothing in particular is not a confirmation.
    foreach ($s in $script:LedgerVerdict) {
        if (-not $latest.ContainsKey($s)) { continue }
        $a = $latest[$s]
        if ("$($a.status)" -eq 'n-a') { continue }
        if (-not $a.verdict) {
            $problems += "Stage $s ($($a.name)) ran but recorded no verdict. A judgement stage that states no judgement is not a judgement stage."
        }
        elseif ("$($a.verdict)" -match '(?i)not\s+compliant') {
            $problems += "Stage $s verdict is '$($a.verdict)'. Remediate and re-audit before delivery."
        }
    }

    # ---- the figure sheet every later review reads must still describe this spine
    $fs = Test-FigureSheetCurrent -BuildDir $BuildDir
    foreach ($p in $fs.Problems) { $problems += $p }

    [pscustomobject]@{
        Ok         = ($problems.Count -eq 0)
        Problems   = $problems
        FigureSheet = $fs
        TopicStaleness = $topicStaleness
        Records    = ($latest.Values | Sort-Object {
                        $i = [array]::IndexOf($script:LedgerOrder, [string]$_.stage)
                        if ($i -lt 0) { 99 } else { $i } })
    }
}

function Write-StageLedgerReport {
    param([Parameter(Mandatory, ValueFromPipeline)] $Result)
    process {
        Write-Host ''
        Write-Host 'STAGE LEDGER' -ForegroundColor Cyan
        foreach ($r in $Result.Records) {
            $col = switch ("$($r.status)") {
                'pass'    { 'Green' }
                'n-a'     { 'DarkGray' }
                'skipped' { 'Yellow' }
                default   { 'Red' }
            }
            $extra = ''
            if ($null -ne $r.findings -and [int]$r.findings -gt 0) { $extra = " ($($r.findings) finding(s))" }
            if ($r.verdict) { $extra += " [$($r.verdict)]" }
            if (Test-LedgerRecordScoped -Record $r) {
                $scope = if ($r.topics -is [string]) { "$($r.topics)" } else { (@($r.topics) | ForEach-Object { "$_" }) -join ',' }
                $extra += (" {{topics {0} @ delta {1}}}" -f $scope, "$($r.deltaSha)".Substring(0, [Math]::Min(8, "$($r.deltaSha)".Length)))
            }
            Write-Host ("  {0,-6} {1,-34} {2,-8}{3}" -f $r.stage, $r.name, $r.status, $extra) -ForegroundColor $col
            #  A gate rule that did not run is printed here every time the
            #  ledger is printed. It is the only place a reader of the build
            #  will see it after the gate's own output has scrolled away.
            foreach ($p in (@($r.partial) | Where-Object { $_ })) {
                Write-Host ("         PARTIAL: {0}" -f $p) -ForegroundColor Magenta
            }
        }
        if ($Result.PSObject.Properties.Name -contains 'TopicStaleness' -and $Result.TopicStaleness) {
            foreach ($k in $Result.TopicStaleness.Keys) {
                $v = $Result.TopicStaleness[$k]
                $colour = if (@($v.Stale).Count) { 'Yellow' } else { 'DarkGray' }
                Write-Host ("  stage {0} by topic: stale {1} - current {2}" -f $k, (Format-LedgerTopicList -Topics @($v.Stale)), (Format-LedgerTopicList -Topics @($v.Current))) -ForegroundColor $colour
            }
        }
        if ($Result.PSObject.Properties.Name -contains 'FigureSheet' -and $Result.FigureSheet -and $Result.FigureSheet.Ok) {
            Write-Host ("  figure sheet current against spine {0}" -f $Result.FigureSheet.Expected) -ForegroundColor DarkGray
        }
        if ($Result.Ok) {
            Write-Host 'LEDGER PASS - every blocking stage ran against the current documents.' -ForegroundColor Green
        } else {
            Write-Host ''
            foreach ($p in $Result.Problems) { Write-Host "  X $p" -ForegroundColor Red }
            Write-Host ("LEDGER FAIL - {0} problem(s)." -f $Result.Problems.Count) -ForegroundColor Red
        }
    }
}

#  -Check with no -BuildDir used to fall through this condition and exit 0,
#  having checked no ledger at all - a caller that mistyped the path got a
#  clean delivery gate. A blocking rule with a missing input FAILS and names
#  the input; it never passes quietly. Dot-sourcing this file for its
#  functions asks for neither and must stay silent, so the refusal is bound
#  to -Check having been asked for.
if ($Check) {
    if (-not $BuildDir) {
        Write-Host '  X Stage-Ledger: -Check was asked for without -BuildDir. There is no ledger to check.' -ForegroundColor Red
        Write-Host '    Pass -BuildDir <build>. This gate does not pass on a missing input.' -ForegroundColor Yellow
        exit 2
    }
    if (-not (Test-Path -LiteralPath $BuildDir)) {
        Write-Host ("  X Stage-Ledger: build directory not found: {0}" -f $BuildDir) -ForegroundColor Red
        exit 2
    }
    $r = Test-StageLedger -BuildDir $BuildDir
    $r | Write-StageLedgerReport
    if (-not $r.Ok) { exit 6 }
}
