<#
    Merge-AuditFindings.ps1 - merge every reviewer's findings.json into ONE
    findings.json and ONE merged_audit.md, by rule and never by judgement.

        & "$SkillDir\scripts\Merge-AuditFindings.ps1" -ReviewDir $out\cleanroom\review -UnitExtract $out\unit_extract.md -OutPath $out\cleanroom\review\merged\findings.json

    WHY THIS IS A SCRIPT AND NOT AN AGENT. The clean-room audit is split into
    topic reviewers and a cross-document reviewer who cannot see each other,
    because a reviewer handed another reviewer's findings stops being a
    second opinion. A merger that SUMMARISED would be a ninth reviewer with
    sight of the other eight - it would decide which findings matter, soften
    the ones it found unconvincing, and reword the ones it found clumsy, and
    the isolation rule that makes the split worth anything would be gone at
    the last step. So this merger never summarises and never rewords. Every
    finding's text leaves this script byte-for-byte as it arrived. What the
    merger does is arithmetic:

      union     every reviewer's coverage[] claims, checked against the KE
                and PE items of the unit extract; any item NO reviewer claims
                becomes a High finding of class not-taught, raised here,
                because eight reviewers each holding one topic cannot see the
                item that fell between them
      concat    every finding, stamped with its reviewer
      dedupe    on (anchor, class) - the same defect at the same locator
                reported by two reviewers is one finding; the copy with the
                worst risk is kept verbatim and the others travel on it,
                each with its own claim, value and replacement verbatim, so
                dedupe collapses the count and never a reviewer's words
      worst     the delivery-set verdict per artefact is the WORST any
                reviewer gave it; and where a High finding remains, a
                Fully Compliant verdict is floored to Partially Compliant,
                because the checklist's own decision rule says Fully requires
                no High defect - that is a rule, not an opinion
      reject    a findings.json that does not meet the contract - an unknown
                class, an unanchored finding, a verdict that is not one of
                the three - fails the whole merge with every violation named,
                because Stage 6b arbitration consumes class, value and source
                and silently skips what it does not recognise

    A MISSING REVIEWER IS A MISSING REVIEWER. Every pack directory that
    carries a SCOPE.md (or is named in manifest.json) must carry a
    findings.json, or the merge FAILS naming the absentee. Seven of eight
    merged quietly is how an untaught topic ships with a green verdict.

    A STRANGER IS NOT A REVIEWER EITHER. When manifest.json names
    expectedReviewers, that list IS the reviewer set: a directory it does not
    name that carries a findings.json or a SCOPE.md - a stale topic9 from an
    earlier nine-topic cut, or a previous merge's own output - is REFUSED by
    name, with the manifest's generated stamp, and never read as a ninth
    reviewer. A findings.json whose reviewer field is 'merger' is refused
    for the same reason: it is this script's output. The merge's own output
    directory and every reviewer directory are compared as canonical paths,
    so case, a trailing separator or a relative segment cannot let the
    exclusion miss.

    WHERE.ARTEFACT IS A CLOSED VOCABULARY. This build OWNS the guide and the
    deck. A reviewer may also name the pack - 'pack', or a pack document by
    the name manifest.json packDocs gives it - and such a finding is real,
    is carried in full, and is reported UPSTREAM: it is a defect of a
    document this build did not write and it does not floor the learner
    guide's verdict. Anything else ('guidee') is refused naming it, because
    a misspelt artefact floors nothing, dedupes with nothing and is
    remediated nowhere.

    A CLAIM WITH NO ANCHOR IS NO CLAIM. A coverage entry whose anchors[] is
    empty (or a bare item string) is listed, not counted: the checklist says
    a claim you cannot anchor is a claim you do not make, and an unanchored
    claim used to suppress the not-taught finding the merger exists to raise.

    THE COVERAGE CHECK-SET IS DERIVED FROM TWO SOURCES, UNIONED. contract.json
    keMap names the knowledge points the pack maps ("KE 1a" ... "KE 4"); the
    unit extract names whatever KE/PE identifiers it writes. The reference
    build's extract writes its knowledge evidence as prose and carries not one
    identifier, so the extract alone yielded zero items and the whole
    not-taught check silently exited 2. Neither source may narrow the other:
    the set is their union, and when the union is EMPTY the merge is refused
    naming BOTH inputs.

    NOTHING COLLAPSES INTO NOTHING. The same (class, anchor) from two
    reviewers is one finding - the worst risk is kept as the finding - and
    every other copy is still EMITTED, verbatim, as its own entry carrying
    sameAnchorAs = the kept mergedId, so a reader sees every reviewer's own
    words and a consumer can skip the copies. Count and verdict use the kept
    entries only.

    THE STAGE 6 RECORD IS WRITTEN HERE, BY THE MACHINE. The merged verdict
    goes into the build's stage-ledger.json through Add-StageRecord, with
    -Round = the count of prior Stage 6 records (the first audit is round 0,
    because round > 0 is what the ledger reads as "remediation ran") and the sha256 of the merged
    findings.json in the note, so a hand-written record and a machine one
    can be told apart. The build is -BuildDir, else manifest.json buildDir;
    a build with no ledger is refused, and -NoLedger (a scratch merge) is
    printed in the open, never silent.

    THE CLASS LIST IS THE ONE STAGE 6b CONSUMES. fabricated, unsourced,
    misattributed, wrong-value, wrong-clause, leak, not-taught,
    missing-target, other. Exactly those names; the checklist documents them.

    NO unit code, brand or build path is hard-coded. The item list comes
    from the unit extract handed in; the reviewer set from the directory.

    PS 5.1 TRAP, KEPT OUT OF THIS FILE ON PURPOSE: @($list) on a
    List[object] throws "Argument types do not match" from the engine's
    array binder (List[int] and List[string] do not trigger it). Lists are
    returned with .ToArray(), never wrapped in @().

    TRUSTED ONLY AFTER PASSING ON PLANTED INPUT. -SelfTest writes two
    synthetic reviewers and a synthetic unit extract with a KE item nobody
    claims, a finding both reviewers report at the same anchor with
    different risks, and disagreeing verdicts, then asserts the uncovered
    item is raised, the duplicate collapses to the worse risk, the worst
    verdict wins, every claim string round-trips unchanged, and a
    contract violation is refused.

    PS 5.1. ASCII only in this file.
    Exit 0 merged with no High finding against an artefact this build owns
    (upstream Highs are in the JSON and on the console), 1 merged with High
    finding(s) remaining against the guide or the deck (including any
    uncovered item), 2 a usage or contract error, or the Stage 6 record
    could not be written, 4 the self-test failed.
#>

[CmdletBinding()]
param(
    [string] $ReviewDir,
    [string] $UnitExtract,
    [string] $OutPath,
    [string] $MarkdownPath,
    #  The build whose stage-ledger.json receives the Stage 6 record. Defaults
    #  to manifest.json buildDir. A build with no ledger is REFUSED unless
    #  -NoLedger says, in the open, that this is a scratch merge.
    [string] $BuildDir,
    #  The contract whose keMap names the knowledge points. Defaults to the
    #  build's contract.json, then one in the review directory.
    [string] $ContractPath,
    [switch] $NoLedger,
    [switch] $SelfTest,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')
#  -BuildDir is passed on purpose: Stage-Ledger.ps1's own param block binds in
#  THIS scope, so an unqualified dot-source blanks $BuildDir (Assert-RenderDelta
#  learned the same). Its entry code runs only under -Check, which is not asked.
. (Join-Path $PSScriptRoot 'Stage-Ledger.ps1') -BuildDir $BuildDir

$GATE = 'MERGE FINDINGS'

#  The contract. The class names are the ones Test-Finding.ps1 (Stage 6b)
#  consumes; the checklist lists them with their meanings.
$script:FindingClasses = @('fabricated', 'unsourced', 'misattributed', 'wrong-value', 'wrong-clause', 'leak', 'not-taught', 'missing-target', 'other')
$script:RiskRank = @{ 'critical' = 3; 'high' = 2; 'medium' = 1; 'low' = 0 }
$script:VerdictNames = @('Fully Compliant', 'Partially Compliant', 'Not Compliant')

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Write-Utf8File {
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][AllowEmptyString()][string] $Content)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($true)))
}

function Get-RiskRank {
    param([AllowEmptyString()][string] $Risk)
    $k = "$Risk".Trim().ToLowerInvariant()
    if ($script:RiskRank.ContainsKey($k)) { return [int]$script:RiskRank[$k] }
    return -1
}

function ConvertTo-VerdictRank {
    param([AllowEmptyString()][string] $Verdict)
    $s = "$Verdict".Trim().ToLowerInvariant()
    if (-not $s) { return -2 }
    if ($s -like 'fully compliant*') { return 0 }
    if ($s -like 'partially compliant*') { return 1 }
    if ($s -like 'not compliant*') { return 2 }
    return -1
}

function Get-VerdictName {
    param([int] $Rank)
    if ($Rank -ge 0 -and $Rank -le 2) { return $script:VerdictNames[$Rank] }
    return 'not stated'
}

function ConvertTo-ItemId {
    <# "ke 2A" -> "KE2a"; anything that is not a KE/PE identifier is returned trimmed, for the report to name. #>
    param([AllowEmptyString()][string] $Item)
    $s = "$Item" -replace '\s', ''
    $m = [regex]::Match($s, '^(?i)(KE|PE)(\d+)([A-Za-z])?$')
    if ($m.Success) { return ($m.Groups[1].Value.ToUpperInvariant() + $m.Groups[2].Value + $m.Groups[3].Value.ToLowerInvariant()) }
    return "$Item".Trim()
}

function Get-FindingAnchor {
    param($Finding)
    $a = ''; $l = ''
    if ($null -ne $Finding -and @($Finding.PSObject.Properties.Name) -contains 'where' -and $null -ne $Finding.where) {
        $a = [string](Get-GateProp -Object $Finding.where -Names @('artefact') -Default '')
        $l = [string](Get-GateProp -Object $Finding.where -Names @('locator') -Default '')
    }
    return (((($a + '|' + $l) -replace '\s+', ' ').Trim().TrimEnd('.', ';', ',')).ToLowerInvariant())
}

function Escape-MdCell {
    param([AllowEmptyString()][string] $Text)
    return (("$Text" -replace '\r?\n', ' ') -replace '\|', '\|')
}

function Get-CanonicalPath {
    <#  One spelling for a path, so an exclusion or a comparison cannot miss on
        case, a trailing separator or a relative segment. Resolved against
        PowerShell's own current location (the process CWD is not the same
        thing under PS 5.1); a path that does not exist yet still
        canonicalises. Empty in, empty out.  #>
    param([AllowEmptyString()][string] $Path)
    if (-not "$Path".Trim()) { return '' }
    $full = $null
    try { $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path) } catch { $full = $null }
    if (-not $full) { try { $full = [System.IO.Path]::GetFullPath($Path) } catch { $full = $Path } }
    if (Test-Path -LiteralPath $full) { try { $full = (Resolve-Path -LiteralPath $full).Path } catch { } }
    return "$full".TrimEnd('\', '/')
}

function Test-SamePath {
    param([AllowEmptyString()][string] $A, [AllowEmptyString()][string] $B)
    if (-not $A -or -not $B) { return $false }
    return [string]::Equals((Get-CanonicalPath -Path $A), (Get-CanonicalPath -Path $B), [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-FileSha256 {
    <# Lower-case hex, the value Get-FileHash prints. #>
    param([Parameter(Mandatory)][string] $Path)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path).Path))).Replace('-', '').ToLowerInvariant()) }
    finally { $sha.Dispose() }
}

#  What where.artefact may say for an artefact THIS BUILD owns. Everything else
#  a reviewer may name is the pack's: 'pack', or a document manifest.json
#  packDocs lists, with or without its .txt.
$script:OwnArtefacts = @('guide', 'deck', 'guide and deck', 'deck and guide', 'guide+deck')

function Get-ArtefactVocabulary {
    <#  Own = guide/deck; Foreign = 'pack' plus every packDocs name and stem,
        lower-cased; PackDocs = the names as the manifest wrote them; From =
        where the pack half came from, printed so a reader can see what the
        merger believed.  #>
    param([string] $ReviewDir)
    $foreign = New-Object System.Collections.Generic.List[string]
    $foreign.Add('pack')
    $docs = New-Object System.Collections.Generic.List[string]
    $from = 'no manifest.json packDocs - only the generic artefact ''pack'' can name a pack document'
    $mf = Join-Path $ReviewDir 'manifest.json'
    if (Test-Path -LiteralPath $mf) {
        $m = Get-GateJson -Path $mf
        if ($null -ne $m -and @($m.PSObject.Properties.Name) -contains 'packDocs') {
            foreach ($d in @($m.packDocs)) {
                if ($null -eq $d) { continue }
                $n = if ($d -is [string]) { $d } else { [string](Get-GateProp -Object $d -Names @('name', 'file') -Default '') }
                $n = "$n".Trim()
                if (-not $n) { continue }
                $docs.Add($n)
                $lc = $n.ToLowerInvariant()
                if (-not $foreign.Contains($lc)) { $foreign.Add($lc) }
                $stem = [System.IO.Path]::GetFileNameWithoutExtension($n).ToLowerInvariant()
                if ($stem -and -not $foreign.Contains($stem)) { $foreign.Add($stem) }
            }
            if ($docs.Count -gt 0) { $from = 'manifest.json packDocs' }
        }
    }
    return [pscustomobject]@{ Own = $script:OwnArtefacts; Foreign = $foreign.ToArray(); PackDocs = $docs.ToArray(); From = $from }
}

function Resolve-ArtefactOwner {
    <# 'own' (guide/deck), 'foreign' (the pack or one of its documents), 'unknown' (refused), 'none' (empty). #>
    param([AllowEmptyString()][string] $Artefact, $Vocabulary)
    $a = ("$Artefact" -replace '\s+', ' ').Trim().ToLowerInvariant()
    if (-not $a) { return 'none' }
    if ($Vocabulary.Own -contains $a) { return 'own' }
    if ($Vocabulary.Foreign -contains $a) { return 'foreign' }
    return 'unknown'
}

function Get-WhereField {
    <#  A reviewer's where[] arrives from JSON as a PSCustomObject; the merger's
        OWN raised findings build it as an [ordered] dictionary. Get-GateProp
        reads PSObject properties only, so a dictionary fell through to its
        default and every merger-raised not-taught finding read as artefact ''
        - which is why 'guide' was never floored by the merger's own High. Read
        both shapes here, in one place.  #>
    param($Where, [Parameter(Mandatory)][string] $Name)
    if ($null -eq $Where) { return '' }
    if ($Where -is [System.Collections.IDictionary]) {
        foreach ($k in $Where.Keys) { if ([string]::Equals("$k", $Name, [System.StringComparison]::OrdinalIgnoreCase)) { return [string]$Where[$k] } }
        return ''
    }
    return [string](Get-GateProp -Object $Where -Names @($Name) -Default '')
}

function Get-WhereArtefact {
    param($Where)
    if ($null -eq $Where -or ($Where -is [string])) { return '' }
    return (Get-WhereField -Where $Where -Name 'artefact')
}

function Get-WhereLocator {
    param($Where)
    if ($null -eq $Where) { return '' }
    if ($Where -is [string]) { return "$Where" }
    return (Get-WhereField -Where $Where -Name 'locator')
}

function Resolve-MergeLedger {
    <#  Where the Stage 6 record goes: -BuildDir, else manifest.json buildDir.
        A build with no stage-ledger.json is refused - the record is the
        point - unless -NoLedger says out loud that this is a scratch merge.
        Resolved BEFORE anything is read or written, so a refusal costs
        nothing and a merge never ends half-recorded.  #>
    param([string] $ReviewDir, [string] $BuildDir, [switch] $NoLedger)
    $out = [pscustomobject]@{ BuildDir = ''; Path = ''; How = ''; Error = ''; Skipped = $false }
    if ($NoLedger) { $out.Skipped = $true; $out.How = '-NoLedger: NO Stage 6 record is written by this merge (a scratch merge, said in the open)'; return $out }
    $bd = ''; $how = ''
    if ($BuildDir) { $bd = $BuildDir; $how = '-BuildDir' }
    else {
        $mf = Join-Path $ReviewDir 'manifest.json'
        if (Test-Path -LiteralPath $mf) {
            $m = Get-GateJson -Path $mf
            if ($null -ne $m) { $bd = [string](Get-GateProp -Object $m -Names @('buildDir') -Default ''); if ($bd) { $how = 'manifest.json buildDir' } }
        }
    }
    if (-not $bd) { $out.Error = ("no build to record Stage 6 in: no -BuildDir was given and {0} names no buildDir. The merged findings ARE this build's Stage 6 record and the ledger must receive it. Pass -BuildDir <build>, or -NoLedger for a scratch merge (printed, never silent)." -f (Join-Path $ReviewDir 'manifest.json')); return $out }
    if (-not (Test-Path -LiteralPath $bd)) { $out.Error = ("the build directory to record Stage 6 in does not exist: {0} (from {1})" -f $bd, $how); return $out }
    $bd = Get-CanonicalPath -Path $bd
    $lp = Get-LedgerPath -BuildDir $bd
    if (-not (Test-Path -LiteralPath $lp)) { $out.Error = ("no stage-ledger.json at {0} (build from {1}). A build with no ledger cannot record that its audit ran; New-StageLedger creates one at Stage 0. -NoLedger is for a scratch merge only." -f $lp, $how); return $out }
    $out.BuildDir = $bd; $out.Path = $lp; $out.How = $how
    return $out
}

function Write-MergeStageRecord {
    <#  The Stage 6 record, from the merged output and nothing else. Round is
        the COUNT of prior Stage 6 records, counted from the ledger on disk, so
        the first audit is round 0 and round N means N remediation cycles ran
        before this read. The note
        carries the sha256 of the merged findings.json, which is how a
        machine-written record is told from a hand-written one. -Started and
        -Ended (ISO 8601 UTC) are passed the moment Add-StageRecord grows
        them, and not before; a -Machine [string] likewise.  #>
    param($Ledger, $Out, [string] $OutPath, [string] $Started)
    $lj = Read-LedgerJson -Path $Ledger.Path
    $prior = 0
    if ($null -ne $lj -and @($lj.PSObject.Properties.Name) -contains 'records') { $prior = @($lj.records | Where-Object { $null -ne $_ -and "$($_.stage)" -eq '6' }).Count }
    #  The FIRST audit is round 0, not round 1. The ledger's Stage 7 rule reads
    #  "a Stage 6 record with round > 0" as "a remediation cycle preceded this
    #  read", and -Round's own default is 0; counting from 1 made Stage 7 owed
    #  on a build whose first clean-room audit was Fully Compliant, asking for
    #  a record of remediation that never happened.
    $round = $prior
    $sha = Get-FileSha256 -Path $OutPath
    $verdict = ("delivery set {0} (guide {1}; deck {2})" -f $Out.verdict.deliverySet, $Out.verdict.guide, $Out.verdict.deck)
    $uncov = if (@($Out.uncovered).Count -gt 0) { (@($Out.uncovered) -join ', ') } else { 'none' }
    $note = ("MACHINE-WRITTEN by Merge-AuditFindings.ps1 - sha256 {0} of {1}. Reviewers merged: {2}. Findings in {3}, same-anchor copies {4}, raised by the merger {5}, out {6}; High against owned artefacts {7}; upstream (pack) {8}, of which High {9}; items no reviewer claims: {10}; coverage claims with no anchor: {11}." -f $sha, $OutPath, ((@($Out.reviewers) | ForEach-Object { $_.reviewer }) -join ', '), $Out.counts.findingsIn, $Out.counts.sameAnchorEntries, $Out.counts.raisedByMerger, $Out.counts.findingsOut, $Out.counts.high, $Out.counts.upstream, $Out.counts.upstreamHigh, $uncov, $Out.counts.claimsWithoutAnchors)
    $ended = (Get-Date).ToUniversalTime().ToString('o')
    $cmd = Get-Command -Name Add-StageRecord -CommandType Function
    $call = @{ BuildDir = $Ledger.BuildDir; Stage = '6'; Name = ("Clean-room audit, round {0} - merged by Merge-AuditFindings" -f $round); Status = 'pass'; Round = $round; Findings = [int]$Out.counts.findingsOut; Verdict = $verdict; Note = $note }
    $passedTimes = $false
    if ($cmd.Parameters.ContainsKey('Started') -and $cmd.Parameters.ContainsKey('Ended')) { $call['Started'] = $Started; $call['Ended'] = $ended; $passedTimes = $true }
    if ($cmd.Parameters.ContainsKey('Machine') -and $cmd.Parameters['Machine'].ParameterType -eq [string]) { $call['Machine'] = $sha }
    Add-StageRecord @call
    return [ordered]@{ buildDir = $Ledger.BuildDir; ledger = $Ledger.Path; from = $Ledger.How; stage = '6'; round = $round; priorStage6Records = $prior; sha256 = $sha; verdict = $verdict; started = $Started; ended = $ended; startedEndedPassed = $passedTimes }
}

# ---------------------------------------------------------------------------
# 1. The unit's KE and PE items: the contract's keMap UNIONED with the
#    identifiers in the extract handed in
#
#    The reference build's unit_extract.md writes its knowledge evidence as
#    prose and carries not one 'KE1'-shaped identifier, so the extract regex
#    yielded zero items and the coverage arm exited 2 - the whole not-taught
#    check silently absent on the only build it ever ran against. contract.json
#    keMap DOES carry them ("KE 1a" ... "KE 4"), keyed with a space.
#
#    The two sources are UNIONED, never chosen between: keMap holds the
#    knowledge points the pack maps, the extract holds the performance evidence
#    keMap does not, and taking either alone would drop items the other names -
#    a narrower check-set is a weaker check. When the union is empty the merge
#    is REFUSED naming BOTH inputs, so the arm can never run over nothing.
# ---------------------------------------------------------------------------

function Get-UnitItemsFromKeMap {
    <#  Every keMap key that spells a KE/PE identifier, in the contract's own
        order. "KE 1a" -> KE1a with parent KE1; "KE 3" -> KE3. Keys that are
        not identifiers (the block's _comment) are skipped. The text is the
        contract's own taughtAt/assessedIn mapping, so the not-taught finding
        this raises names where the pack says the point is taught.  #>
    param($Contract, [string] $ContractPath)
    $items = New-Object System.Collections.Generic.List[object]
    if ($null -eq $Contract) { return $items.ToArray() }
    $km = $null
    if ($Contract -is [System.Collections.IDictionary]) { if ($Contract.Contains('keMap')) { $km = $Contract['keMap'] } }
    elseif (@($Contract.PSObject.Properties.Name) -contains 'keMap') { $km = $Contract.keMap }
    if ($null -eq $km) { return $items.ToArray() }
    $names = @()
    if ($km -is [System.Collections.IDictionary]) { $names = @($km.Keys | ForEach-Object { "$_" }) }
    else { $names = @($km.PSObject.Properties.Name) }
    $seen = @{}
    $n = 0
    foreach ($k in $names) {
        $n++
        $m = [regex]::Match("$k".Trim(), '^(?i)(KE|PE)\s*(\d+)\s*([A-Za-z])?$')
        if (-not $m.Success) { continue }
        $id = $m.Groups[1].Value.ToUpperInvariant() + $m.Groups[2].Value + $m.Groups[3].Value.ToLowerInvariant()
        if ($seen.ContainsKey($id)) { continue }
        $seen[$id] = $true
        $parent = if ($m.Groups[3].Value) { $m.Groups[1].Value.ToUpperInvariant() + $m.Groups[2].Value } else { $null }
        $v = $null
        if ($km -is [System.Collections.IDictionary]) { $v = $km[$k] } else { $v = $km.$k }
        $taught = [string](Get-WhereField -Where $v -Name 'taughtAt')
        $assessed = [string](Get-WhereField -Where $v -Name 'assessedIn')
        $text = ("{0} (taught at {1}; assessed in {2})" -f "$k".Trim(), $(if ($taught) { $taught } else { '(no taughtAt)' }), $(if ($assessed) { $assessed } else { '(no assessedIn)' }))
        if ($text.Length -gt 160) { $text = $text.Substring(0, 157) + '...' }
        $items.Add([pscustomobject]@{ Id = $id; Parent = $parent; Line = $n; Text = $text; From = 'contract.json keMap'; Doc = (Split-Path $ContractPath -Leaf); Locator = ("keMap key '{0}'" -f "$k".Trim()) })
    }
    return $items.ToArray()
}

function Resolve-MergeContract {
    <#  The contract whose keMap names the knowledge points: -ContractPath, else
        the build's contract.json, else one sitting in the review directory
        (a cut pack carries one). Absent is not an error here - the extract may
        still carry identifiers - but WHERE it looked is printed, because a
        refusal that does not say where it looked cannot be acted on.  #>
    param([string] $ReviewDir, [string] $BuildDir, [string] $ContractPath)
    $out = [pscustomobject]@{ Path = ''; Contract = $null; Tried = (New-Object System.Collections.Generic.List[string]) }
    $cands = New-Object System.Collections.Generic.List[string]
    if ($ContractPath) { $cands.Add($ContractPath) }
    if ($BuildDir) { $cands.Add((Join-Path $BuildDir 'contract.json')) }
    $cands.Add((Join-Path $ReviewDir 'contract.json'))
    foreach ($c in $cands) {
        $out.Tried.Add($c)
        if (-not (Test-Path -LiteralPath $c)) { continue }
        $j = Get-GateJson -Path $c
        if ($null -eq $j) { continue }
        $out.Path = $c; $out.Contract = $j
        break
    }
    return $out
}

function Get-UnitItems {
    param([AllowEmptyString()][string] $Text, [string] $Path = '')
    $items = New-Object System.Collections.Generic.List[object]
    $seen = @{}
    $leaf = if ($Path) { Split-Path $Path -Leaf } else { 'unit_extract.md' }
    $lines = @($Text -split "`r?`n")
    for ($i = 0; $i -lt $lines.Count; $i++) {
        foreach ($m in [regex]::Matches($lines[$i], '\b(KE|PE)(\d+)([a-z])?\b')) {
            $id = $m.Groups[1].Value + $m.Groups[2].Value + $m.Groups[3].Value
            if ($seen.ContainsKey($id)) { continue }
            $seen[$id] = $true
            $parent = if ($m.Groups[3].Value) { $m.Groups[1].Value + $m.Groups[2].Value } else { $null }
            $text = (($lines[$i].Substring($m.Index + $m.Length)) -replace '\*\*', '').Trim().TrimStart('-', ':', ' ').Trim()
            if ($text.Length -gt 160) { $text = $text.Substring(0, 157) + '...' }
            $items.Add([pscustomobject]@{ Id = $id; Parent = $parent; Line = $i + 1; Text = $text; From = 'the unit extract'; Doc = $leaf; Locator = ("line {0}" -f ($i + 1)) })
        }
    }
    return $items.ToArray()
}

# ---------------------------------------------------------------------------
# 2. The reviewer set, and each reviewer's file against the contract
# ---------------------------------------------------------------------------

function Get-ReviewerSet {
    <#  The reviewer set is manifest.json expectedReviewers when the manifest
        names any; a directory it does NOT name that carries a findings.json
        or a SCOPE.md is a stale pack from an earlier cut, or another run's
        output, and is REFUSED by name with the manifest's generated stamp -
        never read as a ninth reviewer. Without a manifest (a hand-assembled
        review directory) the set is every directory carrying either file.
        -ExcludeDir (this merge's own output directory) and every reviewer
        directory are compared as canonical paths.  #>
    param([string] $ReviewDir, [string] $ExcludeDir, $Violations)
    $set = New-Object System.Collections.Generic.List[object]
    $expected = @()
    $stamp = ''
    $mf = Join-Path $ReviewDir 'manifest.json'
    if (Test-Path -LiteralPath $mf) {
        $m = Get-GateJson -Path $mf
        if ($null -ne $m) {
            $stamp = [string](Get-GateProp -Object $m -Names @('generated') -Default '')
            if (-not $stamp) { $stamp = '(no generated stamp)' }
            if (@($m.PSObject.Properties.Name) -contains 'expectedReviewers') { $expected = @($m.expectedReviewers | ForEach-Object { "$_".Trim() } | Where-Object { $_ }) }
        }
    }
    $strict = ($expected.Count -gt 0)
    $excl = Get-CanonicalPath -Path $ExcludeDir
    foreach ($d in (Get-ChildItem -LiteralPath $ReviewDir -Directory | Sort-Object Name)) {
        if ($excl -and (Test-SamePath -A $d.FullName -B $excl)) { continue }
        $fp = Join-Path $d.FullName 'findings.json'
        $sp = Join-Path $d.FullName 'SCOPE.md'
        $hasF = Test-Path -LiteralPath $fp
        $hasS = Test-Path -LiteralPath $sp
        if ($strict) {
            if ($expected -notcontains $d.Name) {
                if ($hasF -or $hasS) {
                    $carries = New-Object System.Collections.Generic.List[string]
                    if ($hasF) { $carries.Add('findings.json') }
                    if ($hasS) { $carries.Add('SCOPE.md') }
                    if ($null -ne $Violations) { $Violations.Add(("{0}: directory {1} carries {2} but manifest.json expectedReviewers [{3}] (generated {4}) does not name it - a stale pack from an earlier cut, or another run's output. It was NOT merged. Remove it, or re-cut the packs so the manifest names it." -f $d.Name, $d.FullName, ($carries.ToArray() -join ' and '), ($expected -join ', '), $stamp)) }
                }
                continue
            }
            $set.Add([pscustomobject]@{ Name = $d.Name; Dir = (Get-CanonicalPath -Path $d.FullName); FindingsPath = $fp; HasFindings = $hasF; Expected = $true })
            continue
        }
        if (-not $hasF -and -not $hasS) { continue }
        $set.Add([pscustomobject]@{ Name = $d.Name; Dir = (Get-CanonicalPath -Path $d.FullName); FindingsPath = $fp; HasFindings = $hasF; Expected = $hasS })
    }
    foreach ($e in $expected) {
        if (@($set | Where-Object { $_.Name -eq $e }).Count -eq 0) {
            $set.Add([pscustomobject]@{ Name = $e; Dir = (Join-Path $ReviewDir $e); FindingsPath = (Join-Path (Join-Path $ReviewDir $e) 'findings.json'); HasFindings = $false; Expected = $true })
        }
    }
    return $set.ToArray()
}

function Read-Verdict {
    param($Value, [string] $Reviewer, $Violations)
    $out = [ordered]@{ guide = -2; deck = -2; deliverySet = -2 }
    if ($null -eq $Value -or ($Value -is [string] -and -not "$Value".Trim())) { $Violations.Add(("{0}: verdict is missing" -f $Reviewer)); return $out }
    if ($Value -is [string]) {
        $r = ConvertTo-VerdictRank -Verdict $Value
        if ($r -lt 0) { $Violations.Add(("{0}: verdict '{1}' is not one of {2}" -f $Reviewer, $Value, ($script:VerdictNames -join ' | '))) }
        $out['guide'] = $r; $out['deck'] = $r; $out['deliverySet'] = $r
        return $out
    }
    $stated = 0
    foreach ($pair in @(@('guide', @('guide')), @('deck', @('deck')), @('deliverySet', @('deliverySet', 'delivery-set', 'delivery_set', 'deliveryset', 'pair', 'set')))) {
        $v = Get-GateProp -Object $Value -Names $pair[1] -Default $null
        if ($null -eq $v -or -not "$v".Trim()) { continue }
        $r = ConvertTo-VerdictRank -Verdict "$v"
        if ($r -lt 0) { $Violations.Add(("{0}: verdict.{1} '{2}' is not one of {3}" -f $Reviewer, $pair[0], $v, ($script:VerdictNames -join ' | '))) }
        $out[$pair[0]] = $r
        $stated++
    }
    if ($stated -eq 0) { $Violations.Add(("{0}: verdict names none of guide, deck, deliverySet" -f $Reviewer)) }
    return $out
}

function Read-ReviewerFile {
    param([Parameter(Mandatory)] $Slot, $Violations, $Vocabulary)
    $name = $Slot.Name
    $j = $null
    try { $j = Get-GateJson -Path $Slot.FindingsPath } catch { $Violations.Add(("{0}: findings.json did not parse - {1}" -f $name, $_.Exception.Message)); return $null }
    if ($null -eq $j) { $Violations.Add(("{0}: findings.json is empty" -f $name)); return $null }
    $keys = @($j.PSObject.Properties.Name)
    foreach ($req in @('reviewer', 'scope', 'verdict', 'findings', 'coverage', 'channels')) {
        if ($keys -notcontains $req) { $Violations.Add(("{0}: findings.json has no '{1}' key" -f $name, $req)) }
    }
    $reviewer = [string](Get-GateProp -Object $j -Names @('reviewer') -Default $name)
    if ($reviewer.Trim() -eq 'merger') {
        $Violations.Add(("{0}: findings.json at {1} declares reviewer 'merger' - that is this script's own output, never a reviewer. A merged file read back as a reviewer carries its own raised findings in twice and its own verdict as a vote. Refused; remove it from the reviewer set." -f $name, $Slot.FindingsPath))
    }
    elseif ($reviewer.Trim() -ne $name) {
        $Violations.Add(("{0}: findings.json declares reviewer '{1}' but sits in directory '{0}'. SCOPE.md tells each reviewer which name to write; a file in the wrong directory is a file whose scope nobody can trust. Refused." -f $name, $reviewer))
    }
    $scope = [string](Get-GateProp -Object $j -Names @('scope') -Default '')
    $verdict = Read-Verdict -Value $(if ($keys -contains 'verdict') { $j.verdict } else { $null }) -Reviewer $name -Violations $Violations

    $findings = @()
    if ($keys -contains 'findings' -and $null -ne $j.findings) { $findings = @($j.findings) }
    $n = 0
    foreach ($f in $findings) {
        $n++
        if ($null -eq $f) { $Violations.Add(("{0}: finding #{1} is null" -f $name, $n)); continue }
        $fid = [string](Get-GateProp -Object $f -Names @('id') -Default '')
        $label = if ($fid) { $fid } else { ("#" + $n) }
        if (-not $fid) { $Violations.Add(("{0}: finding #{1} has no id" -f $name, $n)) }
        $risk = [string](Get-GateProp -Object $f -Names @('risk') -Default '')
        if ((Get-RiskRank -Risk $risk) -lt 0) { $Violations.Add(("{0}: finding {1}: risk '{2}' is not High, Medium or Low" -f $name, $label, $risk)) }
        $cls = [string](Get-GateProp -Object $f -Names @('class') -Default '')
        if ($script:FindingClasses -cnotcontains $cls) { $Violations.Add(("{0}: finding {1}: class '{2}' is not one of {3} - arbitration would skip it" -f $name, $label, $cls, ($script:FindingClasses -join '|'))) }
        $anchor = Get-FindingAnchor -Finding $f
        if ($anchor -eq '|' -or $anchor -match '^\|' -or $anchor -match '\|$') { $Violations.Add(("{0}: finding {1}: where.artefact and where.locator are both required - a finding you cannot anchor is not yet a finding" -f $name, $label)) }
        else {
            $art = Get-WhereArtefact -Where $f.where
            if ((Resolve-ArtefactOwner -Artefact $art -Vocabulary $Vocabulary) -eq 'unknown') {
                $packNames = if (@($Vocabulary.PackDocs).Count -gt 0) { (@($Vocabulary.PackDocs) -join ', ') } else { 'none listed' }
                $Violations.Add(("{0}: finding {1}: where.artefact '{2}' is not an artefact this build knows. This build owns {3}; the pack is 'pack' or one of its documents by name ({4}; from {5}). An artefact nobody owns floors no verdict, dedupes with nothing and is remediated nowhere - name it exactly." -f $name, $label, $art, ($Vocabulary.Own -join ' | '), $packNames, $Vocabulary.From))
            }
        }
        $claim = [string](Get-GateProp -Object $f -Names @('claim') -Default '')
        if (-not $claim.Trim()) { $Violations.Add(("{0}: finding {1}: claim is empty" -f $name, $label)) }
    }

    $coverage = @()
    if ($keys -contains 'coverage' -and $null -ne $j.coverage) { $coverage = @($j.coverage) }
    $cov = New-Object System.Collections.Generic.List[object]
    foreach ($c in $coverage) {
        if ($null -eq $c) { continue }
        $item = if ($c -is [string]) { $c } else { [string](Get-GateProp -Object $c -Names @('item') -Default '') }
        if (-not "$item".Trim()) { $Violations.Add(("{0}: a coverage entry names no item" -f $name)); continue }
        #  A blank or whitespace anchor is no anchor. Anchored is what the
        #  coverage union counts; an unanchored claim is listed and counts as
        #  NO coverage, so it cannot suppress a not-taught finding.
        $anchors = @()
        if (-not ($c -is [string]) -and @($c.PSObject.Properties.Name) -contains 'anchors' -and $null -ne $c.anchors) { $anchors = @($c.anchors | ForEach-Object { "$_".Trim() } | Where-Object { $_ }) }
        $cov.Add([pscustomobject]@{ Item = (ConvertTo-ItemId -Item $item); AsWritten = "$item"; Anchors = $anchors; Anchored = ($anchors.Count -gt 0) })
    }

    $channels = [ordered]@{}
    if ($keys -contains 'channels' -and $null -ne $j.channels -and -not ($j.channels -is [string])) {
        foreach ($p in $j.channels.PSObject.Properties) { $channels[$p.Name] = "$($p.Value)" }
    }

    return [pscustomobject]@{ Name = $name; Reviewer = $reviewer; Scope = $scope; Verdict = $verdict; Findings = $findings; Coverage = $cov.ToArray(); Channels = $channels; Path = $Slot.FindingsPath }
}

# ---------------------------------------------------------------------------
# 3. The merge
# ---------------------------------------------------------------------------

function Invoke-MergeFindings {
    param(
        [Parameter(Mandatory)][string] $ReviewDir,
        [Parameter(Mandatory)][string] $UnitExtractPath,
        [Parameter(Mandatory)][string] $OutPath,
        [Parameter(Mandatory)][string] $MarkdownPath,
        [string] $BuildDir,
        [string] $ContractPath,
        [switch] $NoLedger,
        [switch] $Quiet
    )

    $started = (Get-Date).ToUniversalTime().ToString('o')
    $result = [pscustomobject]@{ ExitCode = 0; Errors = (New-Object System.Collections.Generic.List[string]); Merged = $null; Reviewers = @(); Uncovered = @(); Findings = @(); Upstream = @(); StageRecord = $null }
    $violations = New-Object System.Collections.Generic.List[string]

    if (-not (Test-Path -LiteralPath $ReviewDir)) { $result.Errors.Add("no review directory at $ReviewDir"); $result.ExitCode = 2; return $result }
    if (-not (Test-Path -LiteralPath $UnitExtractPath)) { $result.Errors.Add("no unit extract at $UnitExtractPath - coverage cannot be checked against a unit nobody supplied"); $result.ExitCode = 2; return $result }
    $ReviewDir = Get-CanonicalPath -Path $ReviewDir
    $OutPath = Get-CanonicalPath -Path $OutPath
    $MarkdownPath = Get-CanonicalPath -Path $MarkdownPath

    # --- the ledger this merge records itself in, resolved BEFORE anything is read or written
    $ledger = Resolve-MergeLedger -ReviewDir $ReviewDir -BuildDir $BuildDir -NoLedger:$NoLedger
    if ($ledger.Error) { $result.Errors.Add($ledger.Error); $result.ExitCode = 2; return $result }

    $vocab = Get-ArtefactVocabulary -ReviewDir $ReviewDir
    $outDir = Split-Path -Parent $OutPath
    $slots = @(Get-ReviewerSet -ReviewDir $ReviewDir -ExcludeDir $outDir -Violations $violations)
    if ($slots.Count -eq 0 -and $violations.Count -eq 0) { $result.Errors.Add("no reviewer directory under $ReviewDir carries a findings.json or a SCOPE.md"); $result.ExitCode = 2; return $result }
    foreach ($s in $slots) {
        if (-not $s.HasFindings) { $violations.Add(("{0}: expected reviewer has NO findings.json at {1} - the reviewer died, or never wrote the contract. Re-run it; do not merge without it." -f $s.Name, $s.FindingsPath)) }
    }

    $reviewers = New-Object System.Collections.Generic.List[object]
    foreach ($s in ($slots | Where-Object { $_.HasFindings })) {
        $rv = Read-ReviewerFile -Slot $s -Violations $violations -Vocabulary $vocab
        if ($null -ne $rv) { $reviewers.Add($rv) }
    }
    if ($violations.Count -gt 0) {
        foreach ($v in $violations) { $result.Errors.Add($v) }
        $result.ExitCode = 2
        return $result
    }

    # --- unit items: the contract's keMap UNIONED with the extract's identifiers
    $ct = Resolve-MergeContract -ReviewDir $ReviewDir -BuildDir $(if ($ledger.BuildDir) { $ledger.BuildDir } else { $BuildDir }) -ContractPath $ContractPath
    $fromMap = @(Get-UnitItemsFromKeMap -Contract $ct.Contract -ContractPath $(if ($ct.Path) { $ct.Path } else { 'contract.json' }))
    $fromExtract = @(Get-UnitItems -Text (Get-GateFileText -Path $UnitExtractPath) -Path $UnitExtractPath)
    $unitItems = New-Object System.Collections.Generic.List[object]
    $unitSeen = @{}
    foreach ($it in (@($fromMap) + @($fromExtract))) {
        if ($null -eq $it) { continue }
        if ($unitSeen.ContainsKey($it.Id)) { continue }
        $unitSeen[$it.Id] = $true
        $unitItems.Add($it)
    }
    #  A parent named only as the stem of a sub-item (keMap has KE 1a..KE 1j and
    #  no 'KE 1') is NOT invented here: the check-set is what the two sources
    #  name, and coverage of a parent is decided from its children below.
    $itemsFrom = ("contract.json keMap ({0} item(s) from {1}) UNIONED with the KE/PE identifiers in {2} ({3} item(s))" -f $fromMap.Count, $(if ($ct.Path) { $ct.Path } else { 'no contract.json found' }), $UnitExtractPath, $fromExtract.Count)
    $unitItems = $unitItems.ToArray()
    if (@($unitItems).Count -eq 0) {
        $result.Errors.Add(("no KE or PE item resolves, so there is no coverage check-set and the not-taught check cannot run. Neither source yielded one: contract.json keMap - {0}; and the unit extract at {1} carries no KE/PE identifier (KE1, KE2a, PE1 ...). Supply a contract.json whose keMap names the knowledge points, or an extract that writes their identifiers." -f $(if ($ct.Path) { ("read at {0}, no keMap key spells a KE/PE identifier" -f $ct.Path) } else { ("not found; looked at " + (($ct.Tried) -join ', ')) }), $UnitExtractPath))
        $result.ExitCode = 2; return $result
    }

    # --- coverage union. A claim with no anchor is a claim nobody can check,
    #     and the checklist says a claim you cannot anchor is a claim you do
    #     not make: it is LISTED and counts as NO coverage, so it can no
    #     longer suppress the not-taught finding the merger exists to raise.
    $claims = @{}
    $unknownClaims = New-Object System.Collections.Generic.List[object]
    $unanchoredClaims = New-Object System.Collections.Generic.List[object]
    $unitIds = @($unitItems | ForEach-Object { $_.Id })
    foreach ($rv in $reviewers) {
        foreach ($c in $rv.Coverage) {
            if ($unitIds -cnotcontains $c.Item) { $unknownClaims.Add([pscustomobject]@{ Reviewer = $rv.Reviewer; Item = $c.AsWritten }); continue }
            if (-not $c.Anchored) { $unanchoredClaims.Add([pscustomobject]@{ Reviewer = $rv.Reviewer; Item = $c.Item; AsWritten = $c.AsWritten }); continue }
            if (-not $claims.ContainsKey($c.Item)) { $claims[$c.Item] = New-Object System.Collections.Generic.List[object] }
            $claims[$c.Item].Add([pscustomobject]@{ Reviewer = $rv.Reviewer; Anchors = $c.Anchors })
        }
    }
    $coverageRows = New-Object System.Collections.Generic.List[object]
    $uncovered = New-Object System.Collections.Generic.List[object]
    foreach ($u in $unitItems) {
        $direct = $claims.ContainsKey($u.Id)
        $children = @($unitItems | Where-Object { $_.Parent -eq $u.Id })
        $viaChildren = $false
        if (-not $direct -and $children.Count -gt 0) { $viaChildren = (@($children | Where-Object { -not $claims.ContainsKey($_.Id) }).Count -eq 0) }
        $via = if ($direct) { 'claim' } elseif ($viaChildren) { 'sub-items' } else { 'none' }
        $claimedBy = if ($direct) { @($claims[$u.Id] | ForEach-Object { [ordered]@{ reviewer = $_.Reviewer; anchors = @($_.Anchors) } }) } else { @() }
        $coverageRows.Add([ordered]@{ item = $u.Id; text = $u.Text; covered = ($direct -or $viaChildren); via = $via; claimedBy = $claimedBy })
        if (-not ($direct -or $viaChildren)) { $uncovered.Add($u) }
    }

    # --- findings: concat, group on (class, anchor). The copy with the worst
    #     risk is THE finding; every other copy is still EMITTED, verbatim, as
    #     its own entry carrying sameAnchorAs = the kept mergedId, so a reader
    #     sees every reviewer's own words and a consumer can skip the copies.
    #     Nothing is dropped and nothing is reworded.
    $byKey = [ordered]@{}
    foreach ($rv in ($reviewers | Sort-Object Name)) {
        foreach ($f in $rv.Findings) {
            $anchor = Get-FindingAnchor -Finding $f
            $cls = [string]$f.class
            $key = $cls + '||' + $anchor
            $entry = [ordered]@{
                mergedId = ("{0}/{1}" -f $rv.Reviewer, $f.id)
                reviewer = $rv.Reviewer
                id = $f.id
                risk = $f.risk
                class = $cls
                claim = $f.claim
                value = $(if (@($f.PSObject.Properties.Name) -contains 'value') { $f.value } else { $null })
                where = $f.where
                source = $(if (@($f.PSObject.Properties.Name) -contains 'source') { $f.source } else { $null })
                replacement = $(if (@($f.PSObject.Properties.Name) -contains 'replacement') { $f.replacement } else { $null })
                proposedForbid = $(if (@($f.PSObject.Properties.Name) -contains 'proposedForbid' -and $null -ne $f.proposedForbid) { @($f.proposedForbid) } else { @() })
                artefactOwner = (Resolve-ArtefactOwner -Artefact (Get-WhereArtefact -Where $f.where) -Vocabulary $vocab)
                sameAnchorAs = $null
                duplicates = @()
            }
            if (-not $byKey.Contains($key)) { $byKey[$key] = New-Object System.Collections.Generic.List[object] }
            $byKey[$key].Add($entry)
        }
    }
    $merged = New-Object System.Collections.Generic.List[object]
    $dupCount = 0
    foreach ($k in $byKey.Keys) {
        $group = $byKey[$k]
        $kept = $group[0]
        foreach ($e in $group) { if ((Get-RiskRank -Risk $e['risk']) -gt (Get-RiskRank -Risk $kept['risk'])) { $kept = $e } }
        $others = New-Object System.Collections.Generic.List[object]
        foreach ($e in $group) { if (-not [object]::ReferenceEquals($e, $kept)) { $others.Add($e) } }
        $kept['duplicates'] = @($others | ForEach-Object { [ordered]@{ reviewer = $_['reviewer']; id = $_['id']; risk = $_['risk']; claim = $_['claim']; value = $_['value']; replacement = $_['replacement'] } })
        $merged.Add($kept)
        foreach ($o in $others) {
            $o['sameAnchorAs'] = $kept['mergedId']
            $merged.Add($o)
            $dupCount++
        }
    }

    # --- the merger's own findings: an item nobody claims. The source names the
    #     document the item came from - the contract's keMap or the extract -
    #     so the reader can go to the line that says the point must be taught.
    $unitLeaf = Split-Path $UnitExtractPath -Leaf
    foreach ($u in $uncovered) {
        $merged.Add([ordered]@{
            mergedId = ("merger/MERGE-COV-{0}" -f $u.Id)
            reviewer = 'merger'
            id = ("MERGE-COV-{0}" -f $u.Id)
            risk = 'High'
            class = 'not-taught'
            claim = ("No reviewer claims to teach {0}: {1}" -f $u.Id, $u.Text)
            value = $u.Id
            where = [ordered]@{ artefact = 'guide'; locator = ("(no anchor: no reviewer's coverage[] names {0} with an anchor)" -f $u.Id) }
            source = [ordered]@{ doc = $(if ($u.Doc) { $u.Doc } else { $unitLeaf }); locator = $(if ($u.Locator) { $u.Locator } else { ("line {0}" -f $u.Line) }) }
            replacement = ''
            proposedForbid = @()
            artefactOwner = 'own'
            sameAnchorAs = $null
            duplicates = @()
        })
    }

    # --- verdicts: the worst per artefact, then the High floor. Only a High
    #     against an artefact THIS BUILD OWNS floors a verdict. A finding
    #     against the pack, or one of its documents, is about a document this
    #     build did not write: it is carried in full and reported UPSTREAM,
    #     and the learner guide's verdict is not degraded for it. A
    #     sameAnchorAs copy is the same defect and is not counted twice.
    $derivation = New-Object System.Collections.Generic.List[string]
    $ranks = [ordered]@{ guide = -2; deck = -2; deliverySet = -2 }
    foreach ($art in @('guide', 'deck', 'deliverySet')) {
        $parts = New-Object System.Collections.Generic.List[string]
        foreach ($rv in $reviewers) {
            $r = [int]$rv.Verdict[$art]
            if ($r -lt 0) { continue }
            $parts.Add(("{0}={1}" -f $rv.Reviewer, (Get-VerdictName -Rank $r)))
            if ($r -gt $ranks[$art]) { $ranks[$art] = $r }
        }
        $derivation.Add(("{0}: worst of [{1}] = {2}" -f $art, ($parts -join ', '), (Get-VerdictName -Rank $ranks[$art])))
    }
    if ($ranks['guide'] -gt $ranks['deliverySet']) { $ranks['deliverySet'] = $ranks['guide']; $derivation.Add('deliverySet: raised to the guide verdict, because the set cannot be better than one of its artefacts') }
    if ($ranks['deck'] -gt $ranks['deliverySet']) { $ranks['deliverySet'] = $ranks['deck']; $derivation.Add('deliverySet: raised to the deck verdict, because the set cannot be better than one of its artefacts') }

    $highGuide = 0; $highDeck = 0; $highAll = 0
    $upstream = New-Object System.Collections.Generic.List[object]
    foreach ($m in $merged) {
        if ($m['sameAnchorAs']) { continue }
        $art = (Get-WhereArtefact -Where $m['where']).ToLowerInvariant()
        $isHigh = ((Get-RiskRank -Risk $m['risk']) -ge 2)
        if ($m['artefactOwner'] -eq 'foreign') {
            $upstream.Add([ordered]@{ mergedId = $m['mergedId']; reviewer = $m['reviewer']; id = $m['id']; risk = $m['risk']; class = $m['class']; artefact = $art; locator = (Get-WhereLocator -Where $m['where']); high = $isHigh })
            continue
        }
        if (-not $isHigh) { continue }
        $highAll++
        if ($art -match 'guide') { $highGuide++ }
        if ($art -match 'deck') { $highDeck++ }
    }
    $upstreamHigh = @($upstream | Where-Object { $_['high'] }).Count
    if ($highGuide -gt 0 -and $ranks['guide'] -ge 0 -and $ranks['guide'] -lt 1) { $ranks['guide'] = 1; $derivation.Add(("guide: floored to Partially Compliant - {0} High finding(s) remain against it, and the decision rule reserves Fully Compliant for no High defect" -f $highGuide)) }
    if ($highDeck -gt 0 -and $ranks['deck'] -ge 0 -and $ranks['deck'] -lt 1) { $ranks['deck'] = 1; $derivation.Add(("deck: floored to Partially Compliant - {0} High finding(s) remain against it" -f $highDeck)) }
    if ($highAll -gt 0 -and $ranks['deliverySet'] -ge 0 -and $ranks['deliverySet'] -lt 1) { $ranks['deliverySet'] = 1; $derivation.Add(("deliverySet: floored to Partially Compliant - {0} High finding(s) remain against artefacts this build owns" -f $highAll)) }
    if ($ranks['guide'] -gt $ranks['deliverySet']) { $ranks['deliverySet'] = $ranks['guide'] }
    if ($ranks['deck'] -gt $ranks['deliverySet']) { $ranks['deliverySet'] = $ranks['deck'] }
    if ($upstream.Count -gt 0) {
        $upArts = @($upstream | ForEach-Object { $_['artefact'] } | Sort-Object -Unique)
        $derivation.Add(("upstream: {0} finding(s) ({1} High) against artefacts this build does not own [{2}] are reported to the pack owner and floor nothing here: {3}" -f $upstream.Count, $upstreamHigh, ($upArts -join ', '), (@($upstream | ForEach-Object { $_['mergedId'] }) -join ', ')))
    }

    # --- channels: union, disagreements kept, not resolved
    $channels = [ordered]@{}
    foreach ($rv in $reviewers) {
        foreach ($k in $rv.Channels.Keys) {
            if (-not $channels.Contains($k)) { $channels[$k] = @() }
            $channels[$k] = @(@($channels[$k]) + @([ordered]@{ reviewer = $rv.Reviewer; disposition = $rv.Channels[$k] }))
        }
    }

    # --- per-reviewer table
    $table = New-Object System.Collections.Generic.List[object]
    foreach ($rv in $reviewers) {
        $h = 0; $md = 0; $lo = 0
        foreach ($f in $rv.Findings) { $rr = Get-RiskRank -Risk ([string]$f.risk); if ($rr -ge 2) { $h++ } elseif ($rr -eq 1) { $md++ } else { $lo++ } }
        $table.Add([ordered]@{
            reviewer = $rv.Reviewer; scope = $rv.Scope; file = $rv.Path
            verdict = [ordered]@{ guide = (Get-VerdictName -Rank $rv.Verdict['guide']); deck = (Get-VerdictName -Rank $rv.Verdict['deck']); deliverySet = (Get-VerdictName -Rank $rv.Verdict['deliverySet']) }
            findings = [ordered]@{ high = $h; medium = $md; low = $lo; total = @($rv.Findings).Count }
            coverageItems = @($rv.Coverage).Count
            channels = @($rv.Channels.Keys).Count
        })
    }

    $findingsOut = $merged.Count - $dupCount
    $out = [ordered]@{
        reviewer = 'merger'
        scope = ("merged: {0}" -f (($reviewers | ForEach-Object { $_.Reviewer }) -join ', '))
        generated = (Get-Date).ToUniversalTime().ToString('o')
        reviewDir = $ReviewDir
        unitExtract = $UnitExtractPath
        contract = $(if ($ct.Path) { $ct.Path } else { '' })
        coverageCheckSet = [ordered]@{ count = @($unitItems).Count; derivedFrom = $itemsFrom; fromKeMap = $fromMap.Count; fromExtract = $fromExtract.Count }
        rule = 'union coverage against the unit extract, counting only anchored claims, and raise not-taught for any unclaimed item; concatenate; group on (class, anchor) keeping the worst risk as the finding and emitting every other copy verbatim with sameAnchorAs; worst verdict per artefact; Fully floored to Partially where a High against an artefact this build owns remains; a finding against the pack is reported upstream and floors nothing. No finding text was altered.'
        artefactVocabulary = [ordered]@{ own = @($vocab.Own); pack = @($vocab.Foreign); from = $vocab.From }
        verdict = [ordered]@{ guide = (Get-VerdictName -Rank $ranks['guide']); deck = (Get-VerdictName -Rank $ranks['deck']); deliverySet = (Get-VerdictName -Rank $ranks['deliverySet']); derivation = $derivation.ToArray() }
        reviewers = $table.ToArray()
        findings = $merged.ToArray()
        upstream = $upstream.ToArray()
        coverage = $coverageRows.ToArray()
        uncovered = @($uncovered | ForEach-Object { $_.Id })
        claimsAgainstUnknownItems = @($unknownClaims | ForEach-Object { [ordered]@{ reviewer = $_.Reviewer; item = $_.Item } })
        claimsWithoutAnchors = @($unanchoredClaims | ForEach-Object { [ordered]@{ reviewer = $_.Reviewer; item = $_.Item; asWritten = $_.AsWritten } })
        channels = $channels
        counts = [ordered]@{ reviewers = $reviewers.Count; findingsIn = (($reviewers | ForEach-Object { @($_.Findings).Count } | Measure-Object -Sum).Sum); duplicatesCollapsed = $dupCount; sameAnchorEntries = $dupCount; raisedByMerger = $uncovered.Count; findingsOut = $findingsOut; entriesWritten = $merged.Count; high = $highAll; upstream = $upstream.Count; upstreamHigh = $upstreamHigh; claimsWithoutAnchors = $unanchoredClaims.Count }
        stageRecord = $(if ($ledger.Skipped) { [ordered]@{ written = $false; why = $ledger.How } } else { [ordered]@{ written = $true; buildDir = $ledger.BuildDir; ledger = $ledger.Path; from = $ledger.How } })
    }

    Write-Utf8File -Path $OutPath -Content (($out | ConvertTo-Json -Depth 20) + "`r`n")
    Write-Utf8File -Path $MarkdownPath -Content (New-MergedMarkdown -Out $out -UnitItems $unitItems)

    $result.Merged = $out
    $result.Reviewers = $table.ToArray()
    $result.Uncovered = @($uncovered | ForEach-Object { $_.Id })
    $result.Findings = $merged.ToArray()
    $result.Upstream = $upstream.ToArray()
    $result.ExitCode = $(if ($highAll -gt 0) { 1 } else { 0 })

    # --- the Stage 6 record, written by the machine that produced the verdict
    $record = $null
    if (-not $ledger.Skipped) {
        try {
            $record = Write-MergeStageRecord -Ledger $ledger -Out $out -OutPath $OutPath -Started $started
            $result.StageRecord = $record
        }
        catch {
            $result.Errors.Add(("the merge was written to {0} but the Stage 6 record was NOT written to {1}: {2}" -f $OutPath, $ledger.Path, $_.Exception.Message))
            $result.ExitCode = 2
        }
    }

    if (-not $Quiet) {
        Write-Host ''
        Write-Host "$GATE" -ForegroundColor Cyan
        Write-GateCheckSet -What 'reviewer file(s)' -Count $reviewers.Count -DerivedFrom ("directories under {0}: manifest.json expectedReviewers when it names any, else those carrying SCOPE.md or findings.json; {1} excluded as this merge's own output" -f $ReviewDir, $outDir) -Blocking -Input 'manifest.json expectedReviewers / reviewer directories'
        Write-GateCheckSet -What 'KE/PE item(s)' -Count @($unitItems).Count -DerivedFrom $itemsFrom -Blocking -Input ("contract.json keMap and {0}" -f $UnitExtractPath)
        Write-Host ("  artefact vocabulary: own = {0}; pack = {1} ({2})" -f ($vocab.Own -join ' | '), ($vocab.Foreign -join ' | '), $vocab.From) -ForegroundColor DarkGray
        foreach ($t in $table) {
            Write-Host ("  {0,-10} guide={1,-20} deck={2,-20} set={3,-20} H{4} M{5} L{6}  coverage {7}" -f $t.reviewer, $t.verdict.guide, $t.verdict.deck, $t.verdict.deliverySet, $t.findings.high, $t.findings.medium, $t.findings.low, $t.coverageItems) -ForegroundColor DarkGray
        }
        Write-Host ("  findings in {0}, same-anchor copies {1}, raised by the merger {2}, out {3} (entries written {4})" -f $out.counts.findingsIn, $dupCount, $uncovered.Count, $findingsOut, $merged.Count) -ForegroundColor DarkGray
        foreach ($u in $uncovered) { Write-Host ("  X {0} is claimed by NO reviewer: {1}" -f $u.Id, $u.Text) -ForegroundColor Red }
        foreach ($c in $unanchoredClaims) { Write-Host ("  ! {0} claims {1} with NO anchor - listed, not counted as coverage" -f $c.Reviewer, $c.Item) -ForegroundColor Yellow }
        foreach ($d in $derivation) { Write-Host ("  {0}" -f $d) -ForegroundColor DarkGray }
        foreach ($u in $upstream) { Write-Host ("  UPSTREAM {0} [{1} {2}] against '{3}' - {4}" -f $u['mergedId'], $u['risk'], $u['class'], $u['artefact'], $u['locator']) -ForegroundColor Yellow }
        $col = if ($ranks['deliverySet'] -eq 0) { 'Green' } elseif ($ranks['deliverySet'] -eq 1) { 'Yellow' } else { 'Red' }
        Write-Host ("  VERDICT guide={0}  deck={1}  delivery set={2}" -f $out.verdict.guide, $out.verdict.deck, $out.verdict.deliverySet) -ForegroundColor $col
        Write-Host ("  written: {0}" -f $OutPath) -ForegroundColor DarkGray
        Write-Host ("  written: {0}" -f $MarkdownPath) -ForegroundColor DarkGray
        if ($ledger.Skipped) { Write-Host ("  ! {0}" -f $ledger.How) -ForegroundColor Yellow }
        elseif ($null -ne $record) { Write-Host ("  Stage 6 record: round {0} ({1} prior) written to {2} from {3}; sha256 {4}" -f $record.round, $record.priorStage6Records, $record.ledger, $record.from, $record.sha256) -ForegroundColor Green }
    }
    return $result
}

function New-MergedMarkdown {
    param($Out, $UnitItems)
    $o = New-Object System.Collections.Generic.List[string]
    $o.Add('# Merged clean-room audit')
    $o.Add('')
    $o.Add(("Generated {0} by Merge-AuditFindings.ps1 from {1}." -f $Out.generated, $Out.reviewDir))
    $o.Add('')
    $o.Add('**This file was produced by a script that did not read, summarise or reword any finding.** Every finding below is verbatim from the reviewer named on it. The merger unioned anchored coverage claims against the unit extract (a claim with no anchor is listed and counts as no coverage), raised a finding for every item no reviewer claims, grouped exact duplicates on (class, anchor) keeping the worst risk as the finding and emitting every other copy with "same anchor as", took the worst verdict per artefact, floored Fully Compliant to Partially Compliant where a High finding against the guide or the deck remains, and listed every finding against the pack as upstream without flooring anything. Nothing else.')
    $o.Add('')
    $o.Add('## Verdict')
    $o.Add('')
    $o.Add('| Artefact | Verdict |')
    $o.Add('|---|---|')
    $o.Add(("| Guide | {0} |" -f $Out.verdict.guide))
    $o.Add(("| Deck | {0} |" -f $Out.verdict.deck))
    $o.Add(("| Delivery set | **{0}** |" -f $Out.verdict.deliverySet))
    $o.Add('')
    foreach ($d in $Out.verdict.derivation) { $o.Add(("- {0}" -f $d)) }
    $o.Add('')
    $o.Add('## Reviewers')
    $o.Add('')
    $o.Add('| Reviewer | Scope | Guide | Deck | Delivery set | High | Medium | Low | Coverage claims | Channels | File |')
    $o.Add('|---|---|---|---|---|---|---|---|---|---|---|')
    foreach ($t in $Out.reviewers) {
        $o.Add(("| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} | {10} |" -f $t.reviewer, (Escape-MdCell $t.scope), $t.verdict.guide, $t.verdict.deck, $t.verdict.deliverySet, $t.findings.high, $t.findings.medium, $t.findings.low, $t.coverageItems, $t.channels, (Escape-MdCell $t.file)))
    }
    $o.Add('')
    $o.Add(("Findings in: {0}. Duplicates collapsed: {1}. Raised by the merger: {2}. Findings out: {3}. High remaining: {4}." -f $Out.counts.findingsIn, $Out.counts.duplicatesCollapsed, $Out.counts.raisedByMerger, $Out.counts.findingsOut, $Out.counts.high))
    $o.Add('')
    $o.Add('## Items no reviewer claims to teach')
    $o.Add('')
    if (@($Out.uncovered).Count -eq 0) { $o.Add('None. Every KE and PE item in the unit extract is claimed by at least one reviewer, directly or through all of its sub-items.') }
    else {
        $o.Add('Each of these is raised below as a High finding of class not-taught. A topic reviewer holding one topic cannot see an item that fell between topics; that is why the merger raises it.')
        $o.Add('')
        foreach ($u in $Out.uncovered) { $row = $Out.coverage | Where-Object { $_.item -eq $u } | Select-Object -First 1; $o.Add(("- **{0}** - {1}" -f $u, (Escape-MdCell $row.text))) }
    }
    if (@($Out.claimsAgainstUnknownItems).Count -gt 0) {
        $o.Add('')
        $o.Add('Claims against identifiers the unit extract does not carry (not counted as coverage; a reviewer naming an item that does not exist is itself worth a look):')
        foreach ($c in $Out.claimsAgainstUnknownItems) { $o.Add(('- {0} claimed `{1}`' -f $c.reviewer, (Escape-MdCell $c.item))) }
    }
    if (@($Out.claimsWithoutAnchors).Count -gt 0) {
        $o.Add('')
        $o.Add('Coverage claims with NO anchor (listed, not counted as coverage - a claim you cannot anchor is a claim you do not make; where the item is claimed with an anchor by nobody else it is raised above):')
        foreach ($c in $Out.claimsWithoutAnchors) { $o.Add(('- {0} claimed `{1}` with an empty anchors[]' -f $c.reviewer, (Escape-MdCell $c.item))) }
    }
    $o.Add('')
    $o.Add('## Upstream findings - against the pack, not this build''s artefacts')
    $o.Add('')
    if (@($Out.upstream).Count -eq 0) { $o.Add('None. Every finding is against the guide or the deck.') }
    else {
        $o.Add('These name the assessment pack or one of its documents as the artefact at fault. They are real findings about a document this build did not write: they are listed here for the pack owner, carried in full below, and they floor nothing in the verdict above.')
        $o.Add('')
        $o.Add('| Merged id | Risk | Class | Artefact | Locator |')
        $o.Add('|---|---|---|---|---|')
        foreach ($u in $Out.upstream) { $o.Add(("| {0} | {1} | {2} | {3} | {4} |" -f $u.mergedId, $u.risk, $u.class, (Escape-MdCell $u.artefact), (Escape-MdCell $u.locator))) }
    }
    $o.Add('')
    $o.Add('## Findings')
    $o.Add('')
    $o.Add('| Merged id | Risk | Class | Artefact | Locator | Claim | Value | Duplicates | Same anchor as |')
    $o.Add('|---|---|---|---|---|---|---|---|---|')
    foreach ($f in $Out.findings) {
        $art = ''; $loc = ''
        if ($null -ne $f.where) { $art = [string](Get-GateProp -Object $f.where -Names @('artefact') -Default ''); $loc = [string](Get-GateProp -Object $f.where -Names @('locator') -Default '') }
        $dups = @($f.duplicates | ForEach-Object { ("{0}/{1} ({2})" -f $_.reviewer, $_.id, $_.risk) }) -join ', '
        $same = if ($f.sameAnchorAs) { [string]$f.sameAnchorAs } else { '' }
        $o.Add(("| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} |" -f $f.mergedId, $f.risk, $f.class, (Escape-MdCell $art), (Escape-MdCell $loc), (Escape-MdCell ([string]$f.claim)), (Escape-MdCell ([string]$f.value)), (Escape-MdCell $dups), (Escape-MdCell $same)))
    }
    $o.Add('')
    $o.Add('### Every finding in full, verbatim')
    $o.Add('')
    foreach ($f in $Out.findings) {
        $o.Add(("#### {0} - {1} - {2}" -f $f.mergedId, $f.risk, $f.class))
        $o.Add('')
        $o.Add(("- Reviewer: {0}" -f $f.reviewer))
        if ($f.sameAnchorAs) { $o.Add(("- Same anchor as: {0} (the same defect at the same anchor and class; this copy is carried verbatim and is not counted again)" -f $f.sameAnchorAs)) }
        if ($f.artefactOwner -eq 'foreign') { $o.Add('- Upstream: this finding is against the pack, not an artefact this build owns') }
        if ($null -ne $f.where) { $o.Add(("- Where: {0} - {1}" -f [string](Get-GateProp -Object $f.where -Names @('artefact') -Default ''), [string](Get-GateProp -Object $f.where -Names @('locator') -Default ''))) }
        if ($null -ne $f.source) { $o.Add(("- Source: {0} - {1}" -f [string](Get-GateProp -Object $f.source -Names @('doc') -Default ''), [string](Get-GateProp -Object $f.source -Names @('locator') -Default ''))) }
        else { $o.Add('- Source: (none resolved)') }
        $o.Add(("- Value: {0}" -f [string]$f.value))
        if (@($f.proposedForbid).Count -gt 0) { $o.Add(("- Proposed forbid: {0}" -f (@($f.proposedForbid) -join ' | '))) }
        $o.Add('')
        $o.Add('Claim:')
        $o.Add('')
        $o.Add([string]$f.claim)
        $o.Add('')
        if ("$($f.replacement)".Trim()) { $o.Add('Replacement:'); $o.Add(''); $o.Add([string]$f.replacement); $o.Add('') }
        foreach ($d in @($f.duplicates)) {
            $o.Add(("Also reported by {0}/{1} ({2}) at the same anchor and class; their claim, verbatim:" -f $d.reviewer, $d.id, $d.risk))
            $o.Add('')
            $o.Add([string]$d.claim)
            $o.Add('')
            if ("$($d.replacement)".Trim()) { $o.Add('Their replacement:'); $o.Add(''); $o.Add([string]$d.replacement); $o.Add('') }
        }
    }
    $o.Add('## Coverage matrix')
    $o.Add('')
    $o.Add('| Item | Covered | Via | Claimed by | Anchors |')
    $o.Add('|---|---|---|---|---|')
    foreach ($c in $Out.coverage) {
        $by = @($c.claimedBy | ForEach-Object { $_.reviewer }) -join ', '
        $an = @($c.claimedBy | ForEach-Object { @($_.anchors) -join '; ' }) -join ' / '
        $o.Add(("| {0} | {1} | {2} | {3} | {4} |" -f $c.item, $(if ($c.covered) { 'yes' } else { '**NO**' }), $c.via, (Escape-MdCell $by), (Escape-MdCell $an)))
    }
    $o.Add('')
    $o.Add('## Channels')
    $o.Add('')
    if (@($Out.channels.PSObject.Properties).Count -eq 0 -and @($Out.channels.Keys).Count -eq 0) { $o.Add('No reviewer dispositioned any channel.') }
    else {
        $o.Add('| Channel | Dispositions |')
        $o.Add('|---|---|')
        $keys = if ($Out.channels -is [System.Collections.IDictionary]) { @($Out.channels.Keys) } else { @($Out.channels.PSObject.Properties.Name) }
        foreach ($k in $keys) {
            $entries = @($Out.channels[$k] | ForEach-Object { ("{0}: {1}" -f $_.reviewer, $_.disposition) })
            $distinct = @($Out.channels[$k] | ForEach-Object { "$($_.disposition)".Trim().ToLowerInvariant() } | Sort-Object -Unique)
            $flag = if ($distinct.Count -gt 1) { ' **(reviewers disagree)**' } else { '' }
            $o.Add(("| {0} | {1}{2} |" -f (Escape-MdCell $k), (Escape-MdCell ($entries -join '; ')), $flag))
        }
    }
    $o.Add('')
    return (($o -join "`r`n") + "`r`n")
}

# ---------------------------------------------------------------------------
# 4. Self-test
# ---------------------------------------------------------------------------

function Invoke-MergeSelfTest {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("mergefindings-selftest-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $rd = Join-Path $root 'review'
    New-Item -ItemType Directory -Path (Join-Path $rd 'topic1') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $rd 'topic2') -Force | Out-Null
    $fails = New-Object System.Collections.Generic.List[string]
    function Assert-True { param([bool] $Cond, [string] $What) if ($Cond) { Write-Host ("  PASS  {0}" -f $What) -ForegroundColor Green } else { Write-Host ("  FAIL  {0}" -f $What) -ForegroundColor Red; $fails.Add($What) } }
    #  Every plant below merges with -NoLedger except the ledger plants at the
    #  end, which build a scratch ledger and prove the Stage 6 record lands.
    $fullCov = @([ordered]@{ item = 'KE1'; anchors = @('1.1') }, [ordered]@{ item = 'KE2a'; anchors = @('1.1') }, [ordered]@{ item = 'KE2b'; anchors = @('1.1') }, [ordered]@{ item = 'KE3'; anchors = @('1.2') }, [ordered]@{ item = 'PE1a'; anchors = @('1.3') })

    try {
        $unit = Join-Path $root 'unit_extract.md'
        Write-Utf8File -Path $unit -Content (@('# unit', '## Knowledge evidence', '- **KE1** culinary terms', '- **KE2** uses of food types:', '  - KE2a bulk foods', '  - KE2b plated meals', '- **KE3** contents of date codes', '## Performance evidence', '- **PE1** produce ten portions:', '  - PE1a entire meals') -join "`r`n")

        $oddClaim = 'Figure 1.2.2 says "17.5 L" | the card says 15.5 L - see ' + [char]0x2014 + ' Standard 3.2.2'
        $t1 = [ordered]@{
            reviewer = 'topic1'; scope = 'Topic 1 - Alpha'; verdict = 'Partially Compliant'
            findings = @(
                [ordered]@{ id = 'H-1'; risk = 'Medium'; class = 'wrong-value'; claim = $oddClaim; value = '17.5 L'; where = [ordered]@{ artefact = 'guide'; locator = 'Topic 1, 1.2, Figure 1.2.2' }; source = [ordered]@{ doc = 'Workbook.txt'; locator = 'recipe 2094' }; replacement = 'Use 15.5 L.'; proposedForbid = @() },
                [ordered]@{ id = 'L-1'; risk = 'Low'; class = 'other'; claim = 'An undefined abbreviation.'; value = 'CCP'; where = [ordered]@{ artefact = 'guide'; locator = 'Topic 1, 1.1' }; source = $null; replacement = 'critical control point (CCP)'; proposedForbid = @() }
            )
            coverage = @([ordered]@{ item = 'KE1'; anchors = @('1.1 Underpinning knowledge') }, [ordered]@{ item = 'ke2a'; anchors = @('1.1 uses table') }, [ordered]@{ item = 'KE2b'; anchors = @('1.1 uses table') }, [ordered]@{ item = 'PE1a'; anchors = @('Topic 1 overview') })
            channels = [ordered]@{ 'guide body' = 'final'; 'guide alt text' = 'final' }
        }
        $t2 = [ordered]@{
            reviewer = 'topic2'; scope = 'Topic 2 - Beta'; verdict = [ordered]@{ guide = 'Fully Compliant'; deck = 'Not Compliant'; deliverySet = 'Not Compliant' }
            findings = @(
                [ordered]@{ id = 'H-1'; risk = 'High'; class = 'wrong-value'; claim = 'Figure 1.2.2 states 17.5 L where the card states 15.5 L.'; value = '17.5 L'; where = [ordered]@{ artefact = 'Guide'; locator = 'Topic 1, 1.2, Figure 1.2.2.' }; source = [ordered]@{ doc = 'Workbook.txt'; locator = 'recipe 2094' }; replacement = 'Use 15.5 L.'; proposedForbid = @() },
                [ordered]@{ id = 'H-2'; risk = 'High'; class = 'leak'; claim = 'Slide 40 fills the assessed column.'; value = 'Workbook Task 2(a)'; where = [ordered]@{ artefact = 'deck'; locator = 'slide 40' }; source = [ordered]@{ doc = 'Workbook.txt'; locator = 'Task 2(a)' }; replacement = 'Withhold the column.'; proposedForbid = @() }
            )
            coverage = @([ordered]@{ item = 'KE1'; anchors = @('2.1') }, [ordered]@{ item = 'PE1a'; anchors = @() }, [ordered]@{ item = 'KE99'; anchors = @('nowhere') })
            channels = [ordered]@{ 'guide body' = 'placeholder'; 'deck notes' = 'placeholder' }
        }
        Write-Utf8File -Path (Join-Path $rd 'topic1\findings.json') -Content (($t1 | ConvertTo-Json -Depth 10) + "`r`n")
        Write-Utf8File -Path (Join-Path $rd 'topic2\findings.json') -Content (($t2 | ConvertTo-Json -Depth 10) + "`r`n")

        Write-Host ''
        Write-Host "$GATE self-test - two synthetic reviewers at $root" -ForegroundColor Cyan
        $op = Join-Path $rd 'merged\findings.json'
        $mp = Join-Path $rd 'merged\merged_audit.md'
        $r = Invoke-MergeFindings -ReviewDir $rd -UnitExtractPath $unit -OutPath $op -MarkdownPath $mp -NoLedger -Quiet
        Assert-True ($r.ExitCode -eq 1) ("merge succeeds and exits 1 because High findings remain (exit {0}; {1})" -f $r.ExitCode, ($r.Errors -join ' | '))
        $j = Get-GateJson -Path $op
        Assert-True (@($j.uncovered) -contains 'KE3') 'the KE item no reviewer claims (KE3) is raised as uncovered'
        Assert-True (@($j.findings | Where-Object { $_.id -eq 'MERGE-COV-KE3' -and $_.risk -eq 'High' -and $_.class -eq 'not-taught' -and $_.reviewer -eq 'merger' }).Count -eq 1) 'and becomes one High not-taught finding from the merger'
        Assert-True (-not (@($j.uncovered) -contains 'KE2')) 'a parent whose sub-items are all claimed is covered via its sub-items'
        Assert-True (-not (@($j.uncovered) -contains 'PE1')) 'PE parent covered via PE1a (topic1 anchors it; topic2''s empty anchors[] claim does not count)'
        #  @() around claimedBy on purpose: a one-element array round-trips
        #  through ConvertTo-Json/ConvertFrom-Json as a bare PSCustomObject,
        #  whose .Count is $null in PS 5.1 - the assertion, not the merger,
        #  was wrong the first time this was written.
        $pe1aClaimants = @(@($j.coverage | Where-Object { $_.item -eq 'PE1a' })[0].claimedBy)
        Assert-True (@($j.claimsWithoutAnchors | Where-Object { $_.reviewer -eq 'topic2' -and $_.item -eq 'PE1a' }).Count -eq 1 -and $pe1aClaimants.Count -eq 1 -and $pe1aClaimants[0].reviewer -eq 'topic1') ("topic2's coverage claim with an empty anchors[] is LISTED under claimsWithoutAnchors and is not among the item's claimants (claimants: {0})" -f (@($pe1aClaimants | ForEach-Object { $_.reviewer }) -join ', '))
        Assert-True (@($j.coverage | Where-Object { $_.item -eq 'KE2a' -and $_.covered }).Count -eq 1) 'a lower-case claim "ke2a" is normalised to KE2a'
        Assert-True (@($j.claimsAgainstUnknownItems | Where-Object { $_.item -eq 'KE99' }).Count -eq 1) 'a claim against an item the unit does not carry is listed, not counted'
        $wv = @($j.findings | Where-Object { $_.class -eq 'wrong-value' -and -not $_.sameAnchorAs })
        Assert-True ($wv.Count -eq 1) ("the same (anchor, class) from two reviewers is ONE finding ({0})" -f $wv.Count)
        Assert-True ($wv.Count -eq 1 -and $wv[0].risk -eq 'High' -and $wv[0].reviewer -eq 'topic2' -and @($wv[0].duplicates).Count -eq 1 -and $wv[0].duplicates[0].reviewer -eq 'topic1') 'the copy with the worse risk is kept and the other is listed on it'
        $sa = @($j.findings | Where-Object { $_.sameAnchorAs })
        Assert-True ($sa.Count -eq 1 -and $sa[0].sameAnchorAs -eq 'topic2/H-1' -and $sa[0].mergedId -eq 'topic1/H-1' -and $sa[0].claim -ceq $oddClaim -and $sa[0].risk -eq 'Medium') 'the collapsed copy is still EMITTED as its own verbatim entry carrying sameAnchorAs = the kept mergedId, its own risk intact'
        Assert-True ($j.counts.duplicatesCollapsed -eq 1 -and $j.counts.sameAnchorEntries -eq 1 -and $j.counts.findingsIn -eq 4 -and $j.counts.findingsOut -eq 4 -and $j.counts.entriesWritten -eq 5 -and @($j.findings).Count -eq 5) ("counts: in {0}, collapsed {1}, raised {2}, out {3}, entries {4}" -f $j.counts.findingsIn, $j.counts.duplicatesCollapsed, $j.counts.raisedByMerger, $j.counts.findingsOut, $j.counts.entriesWritten)
        Assert-True ($j.counts.high -eq 3 -and $j.counts.upstream -eq 0) 'High count (3: topic2/H-1, topic2/H-2, MERGE-COV-KE3) counts the kept entries once and the same-anchor copy not at all'
        Assert-True ($j.verdict.guide -eq 'Partially Compliant' -and $j.verdict.deck -eq 'Not Compliant' -and $j.verdict.deliverySet -eq 'Not Compliant') ("the worst verdict wins per artefact (guide={0}, deck={1}, set={2})" -f $j.verdict.guide, $j.verdict.deck, $j.verdict.deliverySet)
        $kept = @($j.findings | Where-Object { $_.id -eq 'L-1' })[0]
        Assert-True ($kept.claim -ceq 'An undefined abbreviation.' -and $kept.replacement -ceq 'critical control point (CCP)') 'a finding''s claim and replacement round-trip byte-for-byte'
        $raw = Get-GateFileText -Path $op
        Assert-True ($raw.Contains('An undefined abbreviation.')) 'the merged JSON carries the text verbatim'
        $t1dup = @($j.findings | Where-Object { $_.mergedId -eq 'topic2/H-1' })[0]
        Assert-True ($t1dup.claim -ceq 'Figure 1.2.2 states 17.5 L where the card states 15.5 L.') 'the kept duplicate''s claim is untouched'
        $md = Get-GateFileText -Path $mp
        Assert-True ($md.Contains('| topic1 |') -and $md.Contains('| topic2 |') -and $md.Contains('**NO**')) 'merged_audit.md carries the per-reviewer table and marks the uncovered item'
        Assert-True ($md.Contains('reviewers disagree')) 'a channel two reviewers disposition differently is flagged, not resolved'
        Assert-True ($wv.Count -eq 1 -and $wv[0].duplicates[0].claim -ceq $oddClaim -and $wv[0].duplicates[0].replacement -ceq 'Use 15.5 L.') 'the collapsed copy''s own claim and replacement also travel verbatim on the kept finding'
        Assert-True ($md.Contains($oddClaim) -and $md.Contains('- Same anchor as: topic2/H-1')) 'a claim with a pipe, quotes and a non-ASCII dash reaches the markdown verbatim in its full listing, marked same anchor as'

        # plant 1: a High-free merge is exit 0 and Fully stays Fully
        $t3 = [ordered]@{ reviewer = 'topic1'; scope = 'x'; verdict = 'Fully Compliant'; findings = @(); coverage = $fullCov; channels = [ordered]@{} }
        $rd2 = Join-Path $root 'review2'; New-Item -ItemType Directory -Path (Join-Path $rd2 'topic1') -Force | Out-Null
        Write-Utf8File -Path (Join-Path $rd2 'topic1\findings.json') -Content (($t3 | ConvertTo-Json -Depth 10) + "`r`n")
        $r2 = Invoke-MergeFindings -ReviewDir $rd2 -UnitExtractPath $unit -OutPath (Join-Path $rd2 'merged\findings.json') -MarkdownPath (Join-Path $rd2 'merged\merged_audit.md') -NoLedger -Quiet
        $j2 = Get-GateJson -Path (Join-Path $rd2 'merged\findings.json')
        Assert-True ($r2.ExitCode -eq 0 -and $j2.verdict.deliverySet -eq 'Fully Compliant' -and @($j2.uncovered).Count -eq 0) 'full ANCHORED coverage with no findings merges clean, exit 0, Fully Compliant stands'

        # plant 1b: an empty anchors[] (and a bare item string) is NO coverage, so it
        #           cannot suppress the not-taught finding - the opposite of what this
        #           self-test asserted before P0-18
        $t3b = [ordered]@{ reviewer = 'topic1'; scope = 'x'; verdict = 'Fully Compliant'; findings = @(); coverage = @([ordered]@{ item = 'KE1'; anchors = @('1.1') }, [ordered]@{ item = 'KE2a'; anchors = @('1.1') }, [ordered]@{ item = 'KE2b'; anchors = @('1.1') }, [ordered]@{ item = 'KE3'; anchors = @() }, 'PE1a'); channels = [ordered]@{} }
        Write-Utf8File -Path (Join-Path $rd2 'topic1\findings.json') -Content (($t3b | ConvertTo-Json -Depth 10) + "`r`n")
        $r2b = Invoke-MergeFindings -ReviewDir $rd2 -UnitExtractPath $unit -OutPath (Join-Path $rd2 'merged\findings.json') -MarkdownPath (Join-Path $rd2 'merged\merged_audit.md') -NoLedger -Quiet
        $j2b = Get-GateJson -Path (Join-Path $rd2 'merged\findings.json')
        Assert-True ($r2b.ExitCode -eq 1 -and (@($j2b.uncovered) -contains 'KE3') -and (@($j2b.uncovered) -contains 'PE1a') -and @($j2b.findings | Where-Object { $_.id -eq 'MERGE-COV-KE3' }).Count -eq 1) 'a coverage claim with an EMPTY anchors[] (KE3) and a bare item string (PE1a) no longer suppress the not-taught finding: both are raised, exit 1'
        Assert-True ($j2b.counts.claimsWithoutAnchors -eq 2 -and @($j2b.claimsWithoutAnchors | Where-Object { $_.item -eq 'KE3' }).Count -eq 1 -and $j2b.verdict.guide -eq 'Partially Compliant' -and @($j2b.verdict.derivation | Where-Object { $_ -match '^guide: floored to Partially Compliant - 3 High' }).Count -eq 1) ("both unanchored claims are listed by item, and the merger's own High against 'guide' floors the GUIDE verdict, not the set alone (guide={0})" -f $j2b.verdict.guide)

        # plant 1c: the coverage check-set comes from contract.json keMap when the
        #           extract carries no identifier at all - the reference build's
        #           own shape, on which this arm exited 2 and checked nothing
        $rdK = Join-Path $root 'review-kemap'; New-Item -ItemType Directory -Path (Join-Path $rdK 'topic1') -Force | Out-Null
        $proseUnit = Join-Path $root 'unit_extract_prose.md'
        Write-Utf8File -Path $proseUnit -Content ((@('# SITXINV007 Purchase goods', '## Knowledge evidence', '- culinary terms for a range of food items', '- the contents of date codes and stock rotation labels', '## Performance evidence', '- purchase goods on three occasions') -join "`r`n") + "`r`n")
        Assert-True (@(Get-UnitItems -Text (Get-GateFileText -Path $proseUnit) -Path $proseUnit).Count -eq 0) 'plant landed: the prose extract carries no KE or PE identifier at all, so the extract regex yields nothing'
        $keMapK = [ordered]@{ '_comment' = 'taughtAt is the guide sub-section; assessedIn is where the pack assesses it'; 'KE 1a' = [ordered]@{ taughtAt = '1.1'; assessedIn = 'Task 1(a)' }; 'KE 1b' = [ordered]@{ taughtAt = '1.2'; assessedIn = 'Task 2(a)' }; 'KE 3' = [ordered]@{ taughtAt = '3.1'; assessedIn = 'Task 12(a)' } }
        Write-Utf8File -Path (Join-Path $rdK 'contract.json') -Content ((([ordered]@{ brand = 'MVC'; keMap = $keMapK }) | ConvertTo-Json -Depth 8) + "`r`n")
        $tK = [ordered]@{ reviewer = 'topic1'; scope = 'x'; verdict = 'Fully Compliant'; findings = @(); coverage = @([ordered]@{ item = 'KE 1a'; anchors = @('1.1') }, [ordered]@{ item = 'ke1b'; anchors = @('1.2') }); channels = [ordered]@{} }
        Write-Utf8File -Path (Join-Path $rdK 'topic1\findings.json') -Content (($tK | ConvertTo-Json -Depth 10) + "`r`n")
        $rK = Invoke-MergeFindings -ReviewDir $rdK -UnitExtractPath $proseUnit -OutPath (Join-Path $rdK 'merged\findings.json') -MarkdownPath (Join-Path $rdK 'merged\merged_audit.md') -NoLedger -Quiet
        $jK = Get-GateJson -Path (Join-Path $rdK 'merged\findings.json')
        Assert-True ($rK.ExitCode -eq 1 -and $jK.coverageCheckSet.count -eq 3 -and $jK.coverageCheckSet.fromKeMap -eq 3 -and $jK.coverageCheckSet.fromExtract -eq 0 -and "$($jK.coverageCheckSet.derivedFrom)" -match 'contract\.json keMap \(3 item\(s\)') ("the KE/PE check-set is DERIVED from contract.json keMap when the extract yields nothing (count {0}, keMap {1}, extract {2}; exit {3}; {4})" -f $jK.coverageCheckSet.count, $jK.coverageCheckSet.fromKeMap, $jK.coverageCheckSet.fromExtract, $rK.ExitCode, ($rK.Errors -join ' | '))
        Assert-True ((@($jK.uncovered) -contains 'KE3') -and -not (@($jK.uncovered) -contains 'KE1a') -and -not (@($jK.uncovered) -contains 'KE1b')) ("'KE 1a' and 'ke1b' normalise to the keMap ids and count as coverage; KE 3, which nobody claims, is raised (uncovered: {0})" -f (@($jK.uncovered) -join ', '))
        $covK = @($jK.findings | Where-Object { $_.id -eq 'MERGE-COV-KE3' })
        Assert-True ($covK.Count -eq 1 -and $covK[0].source.doc -eq 'contract.json' -and $covK[0].source.locator -eq "keMap key 'KE 3'" -and $covK[0].claim -match 'taught at 3\.1; assessed in Task 12\(a\)') ("the not-taught finding names the contract key it came from, not a line of an extract that never mentioned it (source {0} / {1})" -f $(if ($covK.Count) { $covK[0].source.doc } else { '' }), $(if ($covK.Count) { $covK[0].source.locator } else { '' }))

        # plant 1d: neither source yields an item - REFUSED naming BOTH, never a silent pass
        Remove-Item -LiteralPath (Join-Path $rdK 'contract.json') -Force
        $rK2 = Invoke-MergeFindings -ReviewDir $rdK -UnitExtractPath $proseUnit -OutPath (Join-Path $rdK 'merged\findings.json') -MarkdownPath (Join-Path $rdK 'merged\merged_audit.md') -NoLedger -Quiet
        Assert-True ($rK2.ExitCode -eq 2 -and @($rK2.Errors | Where-Object { $_ -match 'no KE or PE item resolves' -and $_ -match 'contract\.json keMap - not found; looked at ' -and $_ -match [regex]::Escape($proseUnit) }).Count -eq 1) ("with no keMap and an extract carrying no identifier the merge is REFUSED naming BOTH inputs (exit {0}; {1})" -f $rK2.ExitCode, ($rK2.Errors -join ' | '))

        # plant 2: Fully Compliant with a High finding is floored
        $t4 = [ordered]@{ reviewer = 'topic1'; scope = 'x'; verdict = 'Fully Compliant'; findings = @([ordered]@{ id = 'H-1'; risk = 'High'; class = 'fabricated'; claim = 'c'; value = '9'; where = [ordered]@{ artefact = 'guide'; locator = '1.1' }; source = $null; replacement = ''; proposedForbid = @() }); coverage = $fullCov; channels = [ordered]@{} }
        Write-Utf8File -Path (Join-Path $rd2 'topic1\findings.json') -Content (($t4 | ConvertTo-Json -Depth 10) + "`r`n")
        $r3 = Invoke-MergeFindings -ReviewDir $rd2 -UnitExtractPath $unit -OutPath (Join-Path $rd2 'merged\findings.json') -MarkdownPath (Join-Path $rd2 'merged\merged_audit.md') -NoLedger -Quiet
        $j3 = Get-GateJson -Path (Join-Path $rd2 'merged\findings.json')
        Assert-True ($r3.ExitCode -eq 1 -and $j3.verdict.guide -eq 'Partially Compliant' -and $j3.verdict.deliverySet -eq 'Partially Compliant') 'a Fully Compliant verdict with a High finding against it is floored to Partially Compliant, by the decision rule'

        # plant 2b: the SAME High against the pack, not the guide, is UPSTREAM - the
        #           verdict is unchanged, exit 0, and the finding is carried in full
        $rd2m = Join-Path $root 'review2m'; New-Item -ItemType Directory -Path (Join-Path $rd2m 'topic1') -Force | Out-Null
        Write-Utf8File -Path (Join-Path $rd2m 'manifest.json') -Content (([ordered]@{ generated = '2026-09-08T00:00:00.0000000Z'; expectedReviewers = @('topic1'); packDocs = @([ordered]@{ name = 'UNIT_Tool.txt'; audience = 'learner' }, [ordered]@{ name = 'Assessor_Guide_UNIT_Tool.txt'; audience = 'assessor' }) } | ConvertTo-Json -Depth 4) + "`r`n")
        $t4b = [ordered]@{ reviewer = 'topic1'; scope = 'x'; verdict = 'Fully Compliant'; findings = @(
            [ordered]@{ id = 'H-1'; risk = 'High'; class = 'wrong-value'; claim = 'Appendix C of the tool prints 32 per cent where its own recipe card prints 30.'; value = '32 per cent'; where = [ordered]@{ artefact = 'UNIT_Tool.txt'; locator = 'Appendix C, row 2' }; source = [ordered]@{ doc = 'UNIT_Tool.txt'; locator = 'recipe card' }; replacement = ''; proposedForbid = @() },
            [ordered]@{ id = 'H-2'; risk = 'High'; class = 'other'; claim = 'The pack dates itself 2019.'; value = '2019'; where = [ordered]@{ artefact = 'pack'; locator = 'cover' }; source = $null; replacement = ''; proposedForbid = @() },
            [ordered]@{ id = 'L-1'; risk = 'Low'; class = 'other'; claim = 'A typo in the guide.'; value = 'teh'; where = [ordered]@{ artefact = 'guide'; locator = '1.1' }; source = $null; replacement = 'the'; proposedForbid = @() }
        ); coverage = $fullCov; channels = [ordered]@{} }
        Write-Utf8File -Path (Join-Path $rd2m 'topic1\findings.json') -Content (($t4b | ConvertTo-Json -Depth 10) + "`r`n")
        $r3b = Invoke-MergeFindings -ReviewDir $rd2m -UnitExtractPath $unit -OutPath (Join-Path $rd2m 'merged\findings.json') -MarkdownPath (Join-Path $rd2m 'merged\merged_audit.md') -NoLedger -Quiet
        $j3b = Get-GateJson -Path (Join-Path $rd2m 'merged\findings.json')
        Assert-True ($r3b.ExitCode -eq 0 -and $j3b.verdict.guide -eq 'Fully Compliant' -and $j3b.verdict.deliverySet -eq 'Fully Compliant' -and $j3b.counts.high -eq 0) ("two High findings against the PACK (a packDocs name and 'pack') leave the delivery verdict unchanged at Fully Compliant, exit 0 (exit {0}; {1})" -f $r3b.ExitCode, ($r3b.Errors -join ' | '))
        Assert-True ($j3b.counts.upstream -eq 2 -and $j3b.counts.upstreamHigh -eq 2 -and @($j3b.upstream | Where-Object { $_.mergedId -eq 'topic1/H-1' -and $_.artefact -eq 'unit_tool.txt' }).Count -eq 1 -and @($j3b.findings | Where-Object { $_.id -eq 'H-1' -and $_.claim -ceq 'Appendix C of the tool prints 32 per cent where its own recipe card prints 30.' }).Count -eq 1) 'both are reported UPSTREAM by mergedId and artefact, and carried verbatim in findings[]'
        Assert-True (@($j3b.verdict.derivation | Where-Object { $_ -match '^upstream: 2 finding\(s\) \(2 High\)' }).Count -eq 1 -and ((Get-GateFileText -Path (Join-Path $rd2m 'merged\merged_audit.md')) -match '\| topic1/H-2 \| High \| other \| pack \| cover \|')) 'the derivation says so, and merged_audit.md lists them under Upstream findings'

        # plant 2c: an artefact outside the vocabulary is REFUSED naming it
        $t4c = [ordered]@{ reviewer = 'topic1'; scope = 'x'; verdict = 'Fully Compliant'; findings = @([ordered]@{ id = 'H-1'; risk = 'High'; class = 'fabricated'; claim = 'c'; value = '9'; where = [ordered]@{ artefact = 'guidee'; locator = '1.1' }; source = $null; replacement = ''; proposedForbid = @() }); coverage = $fullCov; channels = [ordered]@{} }
        Write-Utf8File -Path (Join-Path $rd2m 'topic1\findings.json') -Content (($t4c | ConvertTo-Json -Depth 10) + "`r`n")
        $r3c = Invoke-MergeFindings -ReviewDir $rd2m -UnitExtractPath $unit -OutPath (Join-Path $rd2m 'merged\findings.json') -MarkdownPath (Join-Path $rd2m 'merged\merged_audit.md') -NoLedger -Quiet
        Assert-True ($r3c.ExitCode -eq 2 -and @($r3c.Errors | Where-Object { $_ -match "topic1: finding H-1: where.artefact 'guidee' is not an artefact this build knows" -and $_ -match 'UNIT_Tool.txt' -and $_ -match 'manifest.json packDocs' }).Count -eq 1) "where.artefact 'guidee' is REFUSED naming the value, the finding and the vocabulary it missed"

        # plant 3: an unknown class is refused, naming the reviewer and the finding
        $t5 = [ordered]@{ reviewer = 'topic1'; scope = 'x'; verdict = 'Fully Compliant'; findings = @([ordered]@{ id = 'H-9'; risk = 'High'; class = 'fabrication'; claim = 'c'; value = '9'; where = [ordered]@{ artefact = 'guide'; locator = '1.1' }; source = $null; replacement = ''; proposedForbid = @() }); coverage = @(); channels = [ordered]@{} }
        Write-Utf8File -Path (Join-Path $rd2 'topic1\findings.json') -Content (($t5 | ConvertTo-Json -Depth 10) + "`r`n")
        $r4 = Invoke-MergeFindings -ReviewDir $rd2 -UnitExtractPath $unit -OutPath (Join-Path $rd2 'merged\findings.json') -MarkdownPath (Join-Path $rd2 'merged\merged_audit.md') -NoLedger -Quiet
        Assert-True ($r4.ExitCode -eq 2 -and @($r4.Errors | Where-Object { $_ -match "topic1: finding H-9: class 'fabrication'" }).Count -eq 1) 'an unknown class is REFUSED, naming the reviewer and the finding'

        # plant 3b: a findings.json whose reviewer is 'merger' is REFUSED; so is one in the wrong directory
        $t5b = [ordered]@{ reviewer = 'merger'; scope = 'merged: x'; verdict = 'Fully Compliant'; findings = @(); coverage = $fullCov; channels = [ordered]@{} }
        Write-Utf8File -Path (Join-Path $rd2 'topic1\findings.json') -Content (($t5b | ConvertTo-Json -Depth 10) + "`r`n")
        $r4b = Invoke-MergeFindings -ReviewDir $rd2 -UnitExtractPath $unit -OutPath (Join-Path $rd2 'merged\findings.json') -MarkdownPath (Join-Path $rd2 'merged\merged_audit.md') -NoLedger -Quiet
        Assert-True ($r4b.ExitCode -eq 2 -and @($r4b.Errors | Where-Object { $_ -match "topic1: findings.json at .* declares reviewer 'merger'" }).Count -eq 1) "a findings.json with reviewer 'merger' is REFUSED naming its directory and path - a merged output is never a reviewer"
        $t5c = [ordered]@{ reviewer = 'topic2'; scope = 'x'; verdict = 'Fully Compliant'; findings = @(); coverage = $fullCov; channels = [ordered]@{} }
        Write-Utf8File -Path (Join-Path $rd2 'topic1\findings.json') -Content (($t5c | ConvertTo-Json -Depth 10) + "`r`n")
        $r4c = Invoke-MergeFindings -ReviewDir $rd2 -UnitExtractPath $unit -OutPath (Join-Path $rd2 'merged\findings.json') -MarkdownPath (Join-Path $rd2 'merged\merged_audit.md') -NoLedger -Quiet
        Assert-True ($r4c.ExitCode -eq 2 -and @($r4c.Errors | Where-Object { $_ -match "topic1: findings.json declares reviewer 'topic2' but sits in directory 'topic1'" }).Count -eq 1) 'a findings.json whose reviewer does not match its directory is REFUSED'

        # plant 3c: the merge's own output directory is excluded by CANONICAL path - a
        #           differently-cased or relative spelling of -OutPath cannot let a
        #           previous merged/findings.json be read back as a reviewer
        Write-Utf8File -Path (Join-Path $rd2 'topic1\findings.json') -Content (($t4 | ConvertTo-Json -Depth 10) + "`r`n")
        $rFirst = Invoke-MergeFindings -ReviewDir $rd2 -UnitExtractPath $unit -OutPath (Join-Path $rd2 'merged\findings.json') -MarkdownPath (Join-Path $rd2 'merged\merged_audit.md') -NoLedger -Quiet
        $oddOut = Join-Path $rd2 'MERGED\..\Merged\findings.json'
        $rOdd = Invoke-MergeFindings -ReviewDir ($rd2 + '\') -UnitExtractPath $unit -OutPath $oddOut -MarkdownPath (Join-Path $rd2 'merged\merged_audit.md') -NoLedger -Quiet
        Assert-True ($rFirst.ExitCode -eq 1 -and $rOdd.ExitCode -eq 1 -and @($rOdd.Reviewers).Count -eq 1 -and $rOdd.Merged.reviewDir -eq $rd2) ("a second merge with -OutPath spelt 'MERGED\..\Merged' and -ReviewDir with a trailing separator still excludes its own output and reads one reviewer (exit {0}; {1})" -f $rOdd.ExitCode, ($rOdd.Errors -join ' | '))

        # plant 4: an expected reviewer with no findings.json is refused
        New-Item -ItemType Directory -Path (Join-Path $rd 'topic3') -Force | Out-Null
        Write-Utf8File -Path (Join-Path $rd 'topic3\SCOPE.md') -Content '# SCOPE - Topic 3'
        $r5 = Invoke-MergeFindings -ReviewDir $rd -UnitExtractPath $unit -OutPath $op -MarkdownPath $mp -NoLedger -Quiet
        Assert-True ($r5.ExitCode -eq 2 -and @($r5.Errors | Where-Object { $_ -match 'topic3: expected reviewer has NO findings.json' }).Count -eq 1) 'a pack directory with SCOPE.md and no findings.json is REFUSED - seven of eight is not a merge'

        # plant 5: an unanchored finding is refused
        Remove-Item -LiteralPath (Join-Path $rd 'topic3') -Recurse -Force
        $t6 = [ordered]@{ reviewer = 'topic1'; scope = 'x'; verdict = 'Fully Compliant'; findings = @([ordered]@{ id = 'M-1'; risk = 'Medium'; class = 'other'; claim = 'c'; value = ''; where = [ordered]@{ artefact = 'guide'; locator = '' }; source = $null; replacement = ''; proposedForbid = @() }); coverage = @(); channels = [ordered]@{} }
        Write-Utf8File -Path (Join-Path $rd2 'topic1\findings.json') -Content (($t6 | ConvertTo-Json -Depth 10) + "`r`n")
        $r6 = Invoke-MergeFindings -ReviewDir $rd2 -UnitExtractPath $unit -OutPath (Join-Path $rd2 'merged\findings.json') -MarkdownPath (Join-Path $rd2 'merged\merged_audit.md') -NoLedger -Quiet
        Assert-True ($r6.ExitCode -eq 2 -and @($r6.Errors | Where-Object { $_ -match 'M-1: where.artefact and where.locator are both required' }).Count -eq 1) 'a finding with no locator is REFUSED - it cannot be deduped, arbitrated or remediated'

        # plant 6: the expected set resolves from manifest.json when crossdoc is two packs
        $rd3 = Join-Path $root 'review3'
        foreach ($nm in @('topic1', 'crossdoc-values', 'crossdoc-refs')) { New-Item -ItemType Directory -Path (Join-Path $rd3 $nm) -Force | Out-Null }
        $tAll = [ordered]@{ reviewer = 'topic1'; scope = 'x'; verdict = 'Fully Compliant'; findings = @(); coverage = $fullCov; channels = [ordered]@{} }
        $cv = [ordered]@{ reviewer = 'crossdoc-values'; scope = 'cross-document agreement - values'; verdict = 'Fully Compliant'; findings = @(); coverage = @(); channels = [ordered]@{} }
        $cf = [ordered]@{ reviewer = 'crossdoc-refs'; scope = 'cross-document agreement - references'; verdict = 'Partially Compliant'; findings = @([ordered]@{ id = 'M-1'; risk = 'Medium'; class = 'wrong-clause'; claim = 'clause 6 in T1, clause 7 in T5'; value = 'clause 6'; where = [ordered]@{ artefact = 'guide'; locator = '1.3 and 5.4' }; source = $null; replacement = 'clause 7'; proposedForbid = @() }); coverage = @(); channels = [ordered]@{} }
        Write-Utf8File -Path (Join-Path $rd3 'topic1\findings.json') -Content (($tAll | ConvertTo-Json -Depth 10) + "`r`n")
        Write-Utf8File -Path (Join-Path $rd3 'crossdoc-values\findings.json') -Content (($cv | ConvertTo-Json -Depth 10) + "`r`n")
        Write-Utf8File -Path (Join-Path $rd3 'crossdoc-refs\findings.json') -Content (($cf | ConvertTo-Json -Depth 10) + "`r`n")
        Write-Utf8File -Path (Join-Path $rd3 'manifest.json') -Content (([ordered]@{ generated = '2026-09-08T01:02:03.0000000Z'; expectedReviewers = @('topic1', 'crossdoc-values', 'crossdoc-refs') } | ConvertTo-Json -Depth 4) + "`r`n")
        $r7 = Invoke-MergeFindings -ReviewDir $rd3 -UnitExtractPath $unit -OutPath (Join-Path $rd3 'merged\findings.json') -MarkdownPath (Join-Path $rd3 'merged\merged_audit.md') -NoLedger -Quiet
        $j7 = Get-GateJson -Path (Join-Path $rd3 'merged\findings.json')
        Assert-True ($r7.ExitCode -eq 0 -and @($j7.reviewers).Count -eq 3 -and $j7.verdict.deliverySet -eq 'Partially Compliant' -and ((Get-GateFileText -Path (Join-Path $rd3 'merged\merged_audit.md')).Contains('| crossdoc-refs |'))) 'three reviewers named by manifest.json (topic1, crossdoc-values, crossdoc-refs) merge, and the worst crossdoc verdict carries'
        Remove-Item -LiteralPath (Join-Path $rd3 'crossdoc-refs') -Recurse -Force
        $r8 = Invoke-MergeFindings -ReviewDir $rd3 -UnitExtractPath $unit -OutPath (Join-Path $rd3 'merged\findings.json') -MarkdownPath (Join-Path $rd3 'merged\merged_audit.md') -NoLedger -Quiet
        Assert-True ($r8.ExitCode -eq 2 -and @($r8.Errors | Where-Object { $_ -match 'crossdoc-refs: expected reviewer has NO findings.json' }).Count -eq 1) 'a manifest-expected reviewer whose directory is gone is REFUSED by name'
        Write-Utf8File -Path (Join-Path $rd3 'manifest.json') -Content (([ordered]@{ generated = '2026-09-08T01:02:03.0000000Z'; expectedReviewers = @('topic1', 'crossdoc') } | ConvertTo-Json -Depth 4) + "`r`n")
        New-Item -ItemType Directory -Path (Join-Path $rd3 'crossdoc') -Force | Out-Null
        $cs = [ordered]@{ reviewer = 'crossdoc'; scope = 'cross-document agreement'; verdict = 'Fully Compliant'; findings = @(); coverage = @(); channels = [ordered]@{} }
        Write-Utf8File -Path (Join-Path $rd3 'crossdoc\findings.json') -Content (($cs | ConvertTo-Json -Depth 10) + "`r`n")
        $r9 = Invoke-MergeFindings -ReviewDir $rd3 -UnitExtractPath $unit -OutPath (Join-Path $rd3 'merged\findings.json') -MarkdownPath (Join-Path $rd3 'merged\merged_audit.md') -NoLedger -Quiet
        Assert-True ($r9.ExitCode -eq 2 -and @($r9.Errors | Where-Object { $_ -match '^crossdoc-values: directory .* carries findings.json but manifest.json expectedReviewers \[topic1, crossdoc\] \(generated 2026-09-08T01:02:03\.0000000Z\) does not name it' }).Count -eq 1) 'with a single crossdoc in the manifest the leftover crossdoc-values directory is REFUSED by name with the manifest''s generated stamp - a findings.json the manifest does not expect is a stranger, not a reviewer (this self-test asserted the opposite before P0-18)'
        Remove-Item -LiteralPath (Join-Path $rd3 'crossdoc-values') -Recurse -Force

        # plant 6b: a stale topic9 from an earlier cut (SCOPE.md AND findings.json) is not merged and is named
        New-Item -ItemType Directory -Path (Join-Path $rd3 'topic9') -Force | Out-Null
        Write-Utf8File -Path (Join-Path $rd3 'topic9\SCOPE.md') -Content '# SCOPE - Topic 9 (stale)'
        Write-Utf8File -Path (Join-Path $rd3 'topic9\findings.json') -Content (([ordered]@{ reviewer = 'topic9'; scope = 'stale'; verdict = 'Not Compliant'; findings = @(); coverage = @(); channels = [ordered]@{} } | ConvertTo-Json -Depth 10) + "`r`n")
        #  "Nothing was written" is proved by the file's own bytes, not by a
        #  clock: a -NewerThan window turns the assertion on how fast the
        #  machine ran the previous plant.
        $mergedOutPath = Join-Path $rd3 'merged\findings.json'
        $shaBefore = $(if (Test-Path -LiteralPath $mergedOutPath) { Get-FileSha256 -Path $mergedOutPath } else { '(absent)' })
        $r9b = Invoke-MergeFindings -ReviewDir $rd3 -UnitExtractPath $unit -OutPath $mergedOutPath -MarkdownPath (Join-Path $rd3 'merged\merged_audit.md') -NoLedger -Quiet
        $shaAfter = $(if (Test-Path -LiteralPath $mergedOutPath) { Get-FileSha256 -Path $mergedOutPath } else { '(absent)' })
        Assert-True ($r9b.ExitCode -eq 2 -and @($r9b.Errors | Where-Object { $_ -match '^topic9: directory .*topic9 carries findings.json and SCOPE.md but manifest.json expectedReviewers \[topic1, crossdoc\] \(generated 2026-09-08T01:02:03\.0000000Z\) does not name it' }).Count -eq 1 -and $shaAfter -eq $shaBefore -and $null -eq $r9b.Merged) ("a stale topic9 directory is NOT merged and is named with the manifest's generated stamp; the previous merged file is byte-identical afterwards (before {0}, after {1})" -f $shaBefore.Substring(0, [Math]::Min(8, $shaBefore.Length)), $shaAfter.Substring(0, [Math]::Min(8, $shaAfter.Length)))
        Remove-Item -LiteralPath (Join-Path $rd3 'topic9') -Recurse -Force
        $r9c = Invoke-MergeFindings -ReviewDir $rd3 -UnitExtractPath $unit -OutPath (Join-Path $rd3 'merged\findings.json') -MarkdownPath (Join-Path $rd3 'merged\merged_audit.md') -NoLedger -Quiet
        Assert-True ($r9c.ExitCode -eq 0 -and @($r9c.Reviewers).Count -eq 2) 'with the stranger removed the manifest''s two reviewers merge clean'

        # plant 7: the Stage 6 record is written by the merger, round = prior Stage 6 records + 1,
        #          with the sha256 of the merged findings.json in the note
        $bd = Join-Path $root 'build'; New-Item -ItemType Directory -Path $bd -Force | Out-Null
        New-StageLedger -BuildDir $bd -Unit 'UNIT' | Out-Null
        Add-StageRecord -BuildDir $bd -Stage '5' -Name 'Personas' -Status pass -Round 1
        #  Give crossdoc a per-artefact verdict and one Medium finding, so the
        #  record carries a verdict that is not the trivial all-Fully one and
        #  the guide and the deck can be told apart in it.
        $csM = [ordered]@{ reviewer = 'crossdoc'; scope = 'cross-document agreement'; verdict = [ordered]@{ guide = 'Partially Compliant'; deck = 'Fully Compliant'; deliverySet = 'Partially Compliant' }; findings = @([ordered]@{ id = 'M-1'; risk = 'Medium'; class = 'wrong-clause'; claim = 'clause 6 in T1, clause 7 in T5'; value = 'clause 6'; where = [ordered]@{ artefact = 'guide'; locator = '1.3 and 5.4' }; source = $null; replacement = 'clause 7'; proposedForbid = @() }); coverage = @(); channels = [ordered]@{} }
        Write-Utf8File -Path (Join-Path $rd3 'crossdoc\findings.json') -Content (($csM | ConvertTo-Json -Depth 10) + "`r`n")
        $rL = Invoke-MergeFindings -ReviewDir $rd3 -UnitExtractPath $unit -OutPath (Join-Path $rd3 'merged\findings.json') -MarkdownPath (Join-Path $rd3 'merged\merged_audit.md') -BuildDir $bd -Quiet
        $ledger1 = Read-LedgerJson -Path (Join-Path $bd 'stage-ledger.json')
        $rec1 = @($ledger1.records | Where-Object { "$($_.stage)" -eq '6' })
        $shaNow = Get-FileSha256 -Path (Join-Path $rd3 'merged\findings.json')
        Assert-True ($rL.ExitCode -eq 0 -and $rec1.Count -eq 1 -and [int]$rec1[0].round -eq 0 -and "$($rec1[0].verdict)" -match '^delivery set Partially Compliant \(guide Partially Compliant; deck Fully Compliant\)$' -and "$($rec1[0].note)" -match ('^MACHINE-WRITTEN by Merge-AuditFindings\.ps1 - sha256 ' + $shaNow + ' of ')) ("the merger writes Stage 6 round 0 itself with the verdict and the sha256 of the merged findings.json in the note (exit {0}; records {1}; verdict '{2}'; note '{3}'; {4})" -f $rL.ExitCode, $rec1.Count, $(if ($rec1.Count) { $rec1[0].verdict } else { '' }), $(if ($rec1.Count) { "$($rec1[0].note)".Substring(0, [Math]::Min(90, "$($rec1[0].note)".Length)) } else { '' }), ($rL.Errors -join ' | '))
        Assert-True ($rL.StageRecord.round -eq 0 -and $rL.StageRecord.priorStage6Records -eq 0 -and $rL.StageRecord.sha256 -eq $shaNow -and $rL.Merged.stageRecord.written -eq $true) 'and reports the record it wrote'
        #  THE ROUND-NUMBERING CONTRACT between this writer and Stage-Ledger's
        #  Stage 7 rule. That rule has two limbs: a Stage 6 record above round
        #  0, OR a verdict below the best. This fixture's merged verdict is
        #  Partially Compliant, so the VERDICT limb owes a Stage 7 record here
        #  and rightly so; what must not fire is the ROUND limb. A writer whose
        #  first record was round 1 would fire it on every build, including one
        #  clean first time, asking for a remediation record of work that never
        #  happened.
        #  (-notmatch over an ARRAY returns the non-matching elements, not a
        #  boolean, so the matches are counted instead.)
        $s7 = @((Test-StageLedger -BuildDir $bd).Problems | Where-Object { $_ -match 'Stage 7\b' })
        $s7Round = @($s7 | Where-Object { $_ -match 'recorded at round' -or $_ -match 'a round above 0' })
        Assert-True ($s7Round.Count -eq 0) ("and a first-audit (round 0) Stage 6 record does not make Stage 7 owed BY ITS ROUND: " + ($s7Round -join ' | '))
        $rL2 = Invoke-MergeFindings -ReviewDir $rd3 -UnitExtractPath $unit -OutPath (Join-Path $rd3 'merged\findings.json') -MarkdownPath (Join-Path $rd3 'merged\merged_audit.md') -BuildDir $bd -Quiet
        $rec2 = @((Read-LedgerJson -Path (Join-Path $bd 'stage-ledger.json')).records | Where-Object { "$($_.stage)" -eq '6' })
        Assert-True ($rL2.ExitCode -eq 0 -and $rec2.Count -eq 2 -and [int]$rec2[1].round -eq 1 -and $rL2.StageRecord.priorStage6Records -eq 1) 'a second merge writes Stage 6 round 1 - the round is counted from the ledger, never assumed, and a re-audit says a remediation cycle ran'
        $rL3 = Invoke-MergeFindings -ReviewDir $rd3 -UnitExtractPath $unit -OutPath (Join-Path $rd3 'merged\findings.json') -MarkdownPath (Join-Path $rd3 'merged\merged_audit.md') -BuildDir (Join-Path $root 'nowhere') -Quiet
        Assert-True ($rL3.ExitCode -eq 2 -and @($rL3.Errors | Where-Object { $_ -match 'does not exist' -and $_ -match 'nowhere' }).Count -eq 1) 'a -BuildDir that does not exist is REFUSED by name before anything is read'
        $noLedger = Join-Path $root 'build-noledger'; New-Item -ItemType Directory -Path $noLedger -Force | Out-Null
        $rL4 = Invoke-MergeFindings -ReviewDir $rd3 -UnitExtractPath $unit -OutPath (Join-Path $rd3 'merged\findings.json') -MarkdownPath (Join-Path $rd3 'merged\merged_audit.md') -BuildDir $noLedger -Quiet
        Assert-True ($rL4.ExitCode -eq 2 -and @($rL4.Errors | Where-Object { $_ -match 'no stage-ledger.json at ' -and $_ -match 'build-noledger' }).Count -eq 1) 'a build with no stage-ledger.json is REFUSED naming the ledger path - the record is the point'
        $rL5 = Invoke-MergeFindings -ReviewDir $rd3 -UnitExtractPath $unit -OutPath (Join-Path $rd3 'merged\findings.json') -MarkdownPath (Join-Path $rd3 'merged\merged_audit.md') -Quiet
        Assert-True ($rL5.ExitCode -eq 2 -and @($rL5.Errors | Where-Object { $_ -match 'no -BuildDir was given and .*manifest.json names no buildDir' }).Count -eq 1) 'with neither -BuildDir nor a manifest buildDir nor -NoLedger the merge is REFUSED naming both'
        Write-Utf8File -Path (Join-Path $rd3 'manifest.json') -Content (([ordered]@{ generated = '2026-09-08T01:02:03.0000000Z'; buildDir = $bd; expectedReviewers = @('topic1', 'crossdoc') } | ConvertTo-Json -Depth 4) + "`r`n")
        $rL6 = Invoke-MergeFindings -ReviewDir $rd3 -UnitExtractPath $unit -OutPath (Join-Path $rd3 'merged\findings.json') -MarkdownPath (Join-Path $rd3 'merged\merged_audit.md') -Quiet
        Assert-True ($rL6.ExitCode -eq 0 -and $rL6.StageRecord.from -eq 'manifest.json buildDir' -and $rL6.StageRecord.round -eq 2) 'the build resolves from manifest.json buildDir when -BuildDir is not given, and the record is round 2'
    }
    finally {
        if ($root -and (Test-Path -LiteralPath $root) -and $root.Length -gt 12) { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    Write-Host ''
    if ($fails.Count -gt 0) { Write-Host ("  X self-test: {0} assertion(s) failed" -f $fails.Count) -ForegroundColor Red; return 4 }
    Write-Host '  self-test: every assertion held. This merger raises, collapses, takes the worst, and rewords nothing.' -ForegroundColor Green
    return 0
}

# ---------------------------------------------------------------------------
# Entry
# ---------------------------------------------------------------------------

if ($SelfTest) { exit (Invoke-MergeSelfTest) }

if (-not $ReviewDir) {
    Write-Host "$GATE`: usage: Merge-AuditFindings.ps1 -ReviewDir <dir> [-UnitExtract <md>] [-OutPath <findings.json>] [-MarkdownPath <merged_audit.md>] [-BuildDir <build> | -NoLedger] [-ContractPath <contract.json>] | -SelfTest" -ForegroundColor Red
    Write-Host '  The coverage check-set is contract.json keMap unioned with the KE/PE identifiers in the unit extract; the merge is refused when neither yields an item.' -ForegroundColor Yellow
    Write-Host '  The Stage 6 record is written to <build>\stage-ledger.json; -BuildDir defaults to manifest.json buildDir. -NoLedger is for a scratch merge and is printed.' -ForegroundColor Yellow
    exit 2
}
if (-not $UnitExtract) {
    #  The packs each carry a copy; the manifest names the original. Any of them is the same file.
    $cands = @((Join-Path $ReviewDir 'unit_extract.md'))
    $mf = Join-Path $ReviewDir 'manifest.json'
    if (Test-Path -LiteralPath $mf) { $m = Get-GateJson -Path $mf; if ($null -ne $m -and $m.inputs -and $m.inputs.unitExtract) { $cands += [string]$m.inputs.unitExtract } }
    if (Test-Path -LiteralPath $ReviewDir) { foreach ($d in (Get-ChildItem -LiteralPath $ReviewDir -Directory | Sort-Object Name)) { $cands += (Join-Path $d.FullName 'unit_extract.md') } }
    foreach ($c in $cands) { if (Test-Path -LiteralPath $c) { $UnitExtract = $c; break } }
    if (-not $UnitExtract) { Write-Host "$GATE`: no unit extract found under $ReviewDir - pass -UnitExtract" -ForegroundColor Red; exit 2 }
}
if (-not $OutPath) { $OutPath = Join-Path (Join-Path $ReviewDir 'merged') 'findings.json' }
if (-not $MarkdownPath) { $MarkdownPath = Join-Path (Split-Path -Parent $OutPath) 'merged_audit.md' }

$run = Invoke-MergeFindings -ReviewDir $ReviewDir -UnitExtractPath $UnitExtract -OutPath $OutPath -MarkdownPath $MarkdownPath -BuildDir $BuildDir -ContractPath $ContractPath -NoLedger:$NoLedger -Quiet:$Quiet
foreach ($e in $run.Errors) { Write-Host ("  X {0}" -f $e) -ForegroundColor Red }
if ($run.ExitCode -eq 2 -and $null -eq $run.Merged) { Write-Host '  X nothing was merged. Every violation above must be fixed in the reviewer''s own file, or the reviewer re-run.' -ForegroundColor Red }
elseif ($run.ExitCode -eq 2) { Write-Host '  X merged, but the Stage 6 record was NOT written. The build has no record that its audit ran until it is.' -ForegroundColor Red }
exit $run.ExitCode
