<#
    Stage-Ledger.ps1

    Records which build stages actually ran, and refuses delivery when a
    blocking stage was skipped, has gone stale, or is recorded as something its
    own results file contradicts.

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

    THE LEDGER IS NOT TESTIMONY (8 September 2026). A reference build recorded
    Stage 3c as pass over a 3c-results.json saying FAIL / exit 1, with the three
    failing gates typed into partial[] - a field defined as "rules that could
    not run" - and recorded Stage 0 as pass over a CommandNotFound throw. So
    every stage whose runner writes <stage>-results.json is now DERIVED from
    that file, at the moment the record is written and again every time the
    ledger is checked:

      Add-StageRecord -Status pass refuses, naming the file, its verdict and
      the failing gates, when the file is missing, says anything but pass,
      exited non-zero, was a partial run, was stamped with a spine fingerprint
      the spine no longer has, or names an input whose hash has moved. -Partial
      entries must name gates the file itself lists as refused, not run or not
      implemented - never a FAIL. The record's note is GENERATED from gates[]
      ('N PASS, N FAIL (names), N NOT RUN'); free text goes to operatorNote.
      The record carries rec.machine: the file, its sha256 and what it said.

      Test-StageLedger re-derives every one of those checks for the latest
      record of each stage that has a results file, and fails by name on a
      sha256 that no longer matches, or a file newer than the record that
      claims it. A stage with no results file carries machine = 'none'.

    A GATE-DEFECT MEMBER IS NOT A CONTENT FAILURE (P1-14). A member that exits
    4 could not re-find its own quote at the token boundary it declared, so it
    judged nothing about the document: Run-SpineGates records it in the results
    file's defective[], apart from failed[]. Here that class is read and kept
    apart - subtracted from FailedGates, and not an unrun state - and three
    rules name it: a stage may not be recorded pass over a non-empty
    defective[]; a -Partial entry naming a defective member is refused whatever
    the status (filing a broken gate as "a rule that could not run" is how a
    gate defect becomes a permanent exception); and a member listed in BOTH
    failed[] and defective[] is a contradiction, reported rather than resolved.

    ONE STAGE TABLE. $script:LedgerStages is the single owner of which stages
    exist, which are required, blocking, conditional, terminal, a render, a
    placement, an artwork arm, a verdict stage, and which have a machine
    runner (the Script column). The older names (LedgerRequired, LedgerOrder,
    LedgerBlocking, LedgerRenders, LedgerPlacements, ...) are DERIVED VIEWS of
    it so every consumer keeps working and none can drift from it. Five
    hand-listed arrays once disagreed with each other and with the pipeline:
    seven blocking stages were added to the pipeline and to no list, and a
    build that skipped all seven delivered.

      Stage 7 (remediation + re-render) is CONDITIONAL: it is required when a
      Stage 6 or 7d record carries round > 0 or a verdict below the best one
      (the closed vocabulary is read from Merge-AuditFindings.ps1 by AST, never
      copied here), or when a Stage 6b record carries a non-empty work order.
      It is blocking whenever it is present. It is never in the unconditional
      required set: a build with no findings needs no remediation round, and
      requiring one would push builds into inventing work.

      'n-a' is accepted ONLY on the artwork stages (7b-i, 7b), and only with a
      note that resolves to a Stage 2 record recording the artwork decision as
      no-go. Everywhere else 'n-a' or 'skipped' on a stage that is present is a
      hard problem naming the stage: three blocking stages were once recorded
      n-a plus a note and passed delivery. There are four statuses and there is
      no fifth: a dispositioned failure is a pass whose clearancesApplied[] is
      printed, not a new word.

      Stage keys are validated at the point of writing. An unknown key is
      refused naming the nearest known key; nothing is normalised, so the old
      '7b-ii' is refused naming '7b' (placement) - '7b-i' is generate + review.

    SPANS, AND THE SAME-SECOND RULE. utc is an append time. On one build 21 of
    33 records sat within 0.1 s of their predecessor and four stages were
    back-filled minutes before delivery. So a record now carries started, ended
    and durationSeconds: from -Started/-Ended when the caller gives them, from
    the results file's ranAt minus its seconds when the stage has one, and
    otherwise spanKnown = false. Two records of DIFFERENT stages may share an
    ended-second only when both spans are known and do not overlap; a blocking
    stage whose started equals its ended, or a record written after this change
    with neither, fails naming the stage. Legacy utc-only records print
    spanKnown = false and are REPORTED, never accepted as spans. Every
    staleness comparison reads ended (utc when there is none).

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

    THE RENDER RULE IS PER TOPIC, AND THAT IS WHAT MAKES IT SATISFIABLE.
    A one-word fix in Topic 3 once invalidated the personas and the audit for
    all seven topics after every one of six rounds, and the personas were in
    fact never re-run, because a rule that demands seven re-reads for one word
    is a rule nobody meets. So a review record may say WHICH topics it covered
    and WHICH render it read, and the ledger holds it stale only for the topics
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
    It is cut at the end of the 3c band from the spine and is what makes a
    review record count as having read the figures. Stage 7 edits the spine. A
    sheet nobody regenerated then describes figures the document no longer has.
    Test-FigureSheetCurrent requires the sheet to carry BAND-VERDICT PASS - the
    band's own stamp, so a sheet cut by the direct command from a failed spine,
    or forced with -Force (which stamps BAND-VERDICT FAIL), can never reach
    delivery - and compares its SPINE-FINGERPRINT with the spine on disk
    through Test-GateFingerprintVersion, which tells "the fingerprint format
    changed, re-cut" from "the spine moved". An expected fingerprint that comes
    back EMPTY is a problem, never a silent match. A Stage 5, 6 or 7d record
    written while the guide extract's stamp still shows unresolved prompt
    blocks must name the sheet it was read with (-FigureSheet on the record),
    and the sheet it names is checked then and there.

    NO MUTATION AFTER THE LAST GATE. Test-StageLedger recomputes the sha256 of
    every artefact the newest 4/7c results payload judged and fails by name -
    with both hashes - when one has been rewritten since; an artefact whose
    last write is newer than the results file that judged it fails the same
    way; and the spine fingerprint is held against 3c-results.json.

    Dot-source it, or run it directly to check a build directory:

        powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Stage-Ledger.ps1 -BuildDir <build> -Check [-InProgress] [-SpineDir <dir>]

    Exit codes: 0 pass, 1 finding, 2 refused (input missing), 4 self-test failed.

    SELF-TEST:  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Stage-Ledger.ps1 -SelfTest
    Every rule below has a plant in it. Dot-sourcing never runs it.

    PS 5.1. ASCII only in this file.
#>

[CmdletBinding()]
param(
    [string] $BuildDir,
    [switch] $Check,
    #  These three are reached as -InProgress, -SpineDir and -SelfTest through
    #  aliases. A dot-sourced script binds its parameters as variables in the
    #  CALLER's scope, so a parameter called $SpineDir or $SelfTest here would
    #  overwrite the same-named parameter of every gate that dot-sources this
    #  file (Assert-EnumerateBeforeFix, Assert-FullRegateAfterMutation and
    #  Assert-RenderDelta all carry one or both). The odd names keep their
    #  variables; the aliases keep the command line readable.
    [Alias('InProgress')][switch] $LedgerInProgress,
    [Alias('SpineDir')][string]   $LedgerSpineDir,
    [Alias('SelfTest')][switch]   $LedgerSelfTest
)

#  Where this file lives, resolved in the BODY: $PSScriptRoot is empty inside a
#  parameter default under powershell -File, and the verdict vocabulary and the
#  gate library are both read relative to it.
$script:LedgerScriptRoot = $PSScriptRoot
if (-not $script:LedgerScriptRoot -and $MyInvocation.MyCommand.Path) { $script:LedgerScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }

#  The shared gate library: spine enumeration, the v2 fingerprint and the
#  comparer that tells a version change from a moved spine. Loaded once; the
#  guard names the newest function this file needs so an older copy already in
#  the session is replaced rather than trusted. Get-SpineFingerprint is NEVER
#  re-implemented here - one definition of the spine, one hash of it.
if (-not (Get-Command Test-GateFingerprintVersion -ErrorAction SilentlyContinue)) {
    . (Join-Path $script:LedgerScriptRoot 'Lib-GateCommon.ps1')
}

# ---------------------------------------------------------------------------
# THE STAGE TABLE - the one owner of what a stage is. Every older list name
# below is derived from it. Add a stage HERE and nowhere else. It is written
# as ONE literal assignment of [pscustomobject] rows so a reader that must not
# execute this file (Assert-GateFixtures) can take it from the syntax tree.
#
#   Required     must carry a record before delivery
#   Blocking     fail/skipped stops delivery; started == ended is refused
#   Conditional  required only when the ledger's own records call for it (7)
#   Terminal     the delivery record itself; -InProgress excludes only this (8)
#   Render       assembles both artefacts afresh; 4b, 5 and 6 must postdate it
#   Placement    mutates the page without the prose; 7c and 7d must postdate it
#   StaleAfterRender / StaleAfterPlacement / PostPlacementRead / Verdict
#                the stages each staleness rule judges (see the header)
#   Artwork      the only stages where 'n-a' is accepted, and only with a note
#                resolving to a Stage 2 no-go record
#   Script       the script that writes <Key>-results.json. A pass recorded on
#                such a stage is DERIVED from that file and refused without it.
# ---------------------------------------------------------------------------

$script:LedgerStages = @(
    [pscustomobject]@{ Key = '0';    Title = 'pre-flight';                                    Required = $true;  Blocking = $true;  Conditional = $false; Terminal = $false; Render = $false; Placement = $false; StaleAfterRender = $false; StaleAfterPlacement = $false; PostPlacementRead = $false; Verdict = $false; Artwork = $false; Script = 'Invoke-Stage0.ps1' },
    [pscustomobject]@{ Key = '1';    Title = 'corpus and unit extraction';                    Required = $true;  Blocking = $true;  Conditional = $false; Terminal = $false; Render = $false; Placement = $false; StaleAfterRender = $false; StaleAfterPlacement = $false; PostPlacementRead = $false; Verdict = $false; Artwork = $false; Script = 'Run-SpineGates.ps1' },
    [pscustomobject]@{ Key = '2';    Title = 'contract, registry, registers, artwork go/no-go'; Required = $true; Blocking = $true; Conditional = $false; Terminal = $false; Render = $false; Placement = $false; StaleAfterRender = $false; StaleAfterPlacement = $false; PostPlacementRead = $false; Verdict = $false; Artwork = $false; Script = 'Run-SpineGates.ps1' },
    [pscustomobject]@{ Key = '3';    Title = 'authoring';                                     Required = $true;  Blocking = $false; Conditional = $false; Terminal = $false; Render = $false; Placement = $false; StaleAfterRender = $false; StaleAfterPlacement = $false; PostPlacementRead = $false; Verdict = $false; Artwork = $false; Script = '' },
    [pscustomobject]@{ Key = '3b';   Title = 'visual planning and prompt lint';               Required = $true;  Blocking = $true;  Conditional = $false; Terminal = $false; Render = $false; Placement = $false; StaleAfterRender = $false; StaleAfterPlacement = $false; PostPlacementRead = $false; Verdict = $false; Artwork = $false; Script = '' },
    [pscustomobject]@{ Key = '3c';   Title = 'spine gate band';                               Required = $true;  Blocking = $true;  Conditional = $false; Terminal = $false; Render = $false; Placement = $false; StaleAfterRender = $false; StaleAfterPlacement = $false; PostPlacementRead = $false; Verdict = $false; Artwork = $false; Script = 'Run-SpineGates.ps1' },
    [pscustomobject]@{ Key = '3d';   Title = 'figure sheet review and adjudication';          Required = $true;  Blocking = $true;  Conditional = $false; Terminal = $false; Render = $false; Placement = $false; StaleAfterRender = $false; StaleAfterPlacement = $false; PostPlacementRead = $false; Verdict = $false; Artwork = $false; Script = '' },
    [pscustomobject]@{ Key = '4';    Title = 'render and full gate set';                      Required = $true;  Blocking = $true;  Conditional = $false; Terminal = $false; Render = $true;  Placement = $false; StaleAfterRender = $false; StaleAfterPlacement = $false; PostPlacementRead = $false; Verdict = $false; Artwork = $false; Script = 'Run-Gates.ps1' },
    [pscustomobject]@{ Key = '4b';   Title = 'readability';                                   Required = $true;  Blocking = $true;  Conditional = $false; Terminal = $false; Render = $false; Placement = $false; StaleAfterRender = $true;  StaleAfterPlacement = $false; PostPlacementRead = $false; Verdict = $false; Artwork = $false; Script = '' },
    [pscustomobject]@{ Key = '4c';   Title = 'brand proved';                                  Required = $true;  Blocking = $true;  Conditional = $false; Terminal = $false; Render = $false; Placement = $false; StaleAfterRender = $false; StaleAfterPlacement = $false; PostPlacementRead = $false; Verdict = $false; Artwork = $false; Script = '' },
    [pscustomobject]@{ Key = '5';    Title = 'personas and flow';                             Required = $true;  Blocking = $true;  Conditional = $false; Terminal = $false; Render = $false; Placement = $false; StaleAfterRender = $true;  StaleAfterPlacement = $false; PostPlacementRead = $false; Verdict = $false; Artwork = $false; Script = '' },
    [pscustomobject]@{ Key = '6';    Title = 'clean-room audit';                              Required = $true;  Blocking = $true;  Conditional = $false; Terminal = $false; Render = $false; Placement = $false; StaleAfterRender = $true;  StaleAfterPlacement = $false; PostPlacementRead = $true;  Verdict = $true;  Artwork = $false; Script = '' },
    [pscustomobject]@{ Key = '6b';   Title = 'finding arbitration';                           Required = $true;  Blocking = $true;  Conditional = $false; Terminal = $false; Render = $false; Placement = $false; StaleAfterRender = $false; StaleAfterPlacement = $false; PostPlacementRead = $false; Verdict = $false; Artwork = $false; Script = '' },
    [pscustomobject]@{ Key = '7';    Title = 'remediation and re-render';                     Required = $false; Blocking = $true;  Conditional = $true;  Terminal = $false; Render = $true;  Placement = $false; StaleAfterRender = $false; StaleAfterPlacement = $false; PostPlacementRead = $false; Verdict = $false; Artwork = $false; Script = '' },
    [pscustomobject]@{ Key = '7b-i'; Title = 'artwork generated and reviewed';                Required = $true;  Blocking = $true;  Conditional = $false; Terminal = $false; Render = $false; Placement = $false; StaleAfterRender = $false; StaleAfterPlacement = $false; PostPlacementRead = $false; Verdict = $false; Artwork = $true;  Script = '' },
    [pscustomobject]@{ Key = '7b';   Title = 'artwork placed';                                Required = $true;  Blocking = $false; Conditional = $false; Terminal = $false; Render = $false; Placement = $true;  StaleAfterRender = $false; StaleAfterPlacement = $false; PostPlacementRead = $false; Verdict = $false; Artwork = $true;  Script = '' },
    [pscustomobject]@{ Key = '7c';   Title = 'post-placement full re-gate';                   Required = $true;  Blocking = $true;  Conditional = $false; Terminal = $false; Render = $false; Placement = $true;  StaleAfterRender = $false; StaleAfterPlacement = $true;  PostPlacementRead = $false; Verdict = $false; Artwork = $false; Script = 'Run-Gates.ps1' },
    [pscustomobject]@{ Key = '7d';   Title = 'confirming read of the placed page';            Required = $true;  Blocking = $true;  Conditional = $false; Terminal = $false; Render = $false; Placement = $false; StaleAfterRender = $false; StaleAfterPlacement = $true;  PostPlacementRead = $true;  Verdict = $true;  Artwork = $false; Script = '' },
    [pscustomobject]@{ Key = '8';    Title = 'delivery';                                      Required = $true;  Blocking = $true;  Conditional = $false; Terminal = $true;  Render = $false; Placement = $false; StaleAfterRender = $false; StaleAfterPlacement = $false; PostPlacementRead = $false; Verdict = $false; Artwork = $false; Script = '' }
)

#  Every column every row must carry. A row missing one would read as $false
#  and quietly drop a stage out of a rule, which is the exact class of defect
#  the five hand-listed arrays produced.
$script:LedgerStageColumns = @('Key', 'Title', 'Required', 'Blocking', 'Conditional', 'Terminal',
                               'Render', 'Placement', 'StaleAfterRender', 'StaleAfterPlacement',
                               'PostPlacementRead', 'Verdict', 'Artwork', 'Script')
foreach ($row in $script:LedgerStages) {
    $have = @($row.PSObject.Properties.Name)
    $missing = @($script:LedgerStageColumns | Where-Object { $have -notcontains $_ })
    if ($missing.Count) {
        throw ("Stage table: row '{0}' is missing column(s) {1}. Every row carries every column; an absent column reads as false and silently drops the stage out of a rule." -f $row.Key, ($missing -join ', '))
    }
}

#  Keys the pipeline once used and has since renamed. NOTHING is normalised:
#  a renamed key is refused naming its replacement, so a record can never be
#  written under a name the table does not carry.
$script:LedgerRenamedKeys = @{ '7b-ii' = '7b' }

function Get-LedgerStageKeys {
    <# The keys of every table row carrying -Flag, in table order. #>
    param([Parameter(Mandatory)][string] $Flag)
    return @($script:LedgerStages | Where-Object { $_.$Flag } | ForEach-Object { $_.Key })
}

function Get-LedgerStage {
    <# The table row for a key, or $null. Exact match: keys are not normalised. #>
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Key)
    foreach ($row in $script:LedgerStages) { if ($row.Key -ceq $Key) { return $row } }
    return $null
}

function Get-LedgerStageScript {
    <# The results producer for a stage, or '' when the stage has none. #>
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Key)
    $row = Get-LedgerStage -Key $Key
    if ($null -eq $row) { return '' }
    return "$($row.Script)"
}

#  DERIVED VIEWS. Same names, same shapes, same meanings as before; every value
#  now comes from the one table above.
$script:LedgerOrder    = @($script:LedgerStages | ForEach-Object { $_.Key })
$script:LedgerRequired = @(Get-LedgerStageKeys -Flag 'Required')
$script:LedgerBlocking = @(Get-LedgerStageKeys -Flag 'Blocking')
$script:LedgerRenders    = @(Get-LedgerStageKeys -Flag 'Render')
$script:LedgerPlacements = @(Get-LedgerStageKeys -Flag 'Placement')
$script:LedgerStaleAfterRender    = @(Get-LedgerStageKeys -Flag 'StaleAfterRender')
$script:LedgerStaleAfterPlacement = @(Get-LedgerStageKeys -Flag 'StaleAfterPlacement')
$script:LedgerPostPlacementRead   = @(Get-LedgerStageKeys -Flag 'PostPlacementRead')
$script:LedgerVerdict     = @(Get-LedgerStageKeys -Flag 'Verdict')
$script:LedgerArtwork     = @(Get-LedgerStageKeys -Flag 'Artwork')
$script:LedgerTerminal    = @(Get-LedgerStageKeys -Flag 'Terminal')
$script:LedgerConditional = @(Get-LedgerStageKeys -Flag 'Conditional')
$script:LedgerScripted    = @($script:LedgerStages | Where-Object { "$($_.Script)".Trim() } | ForEach-Object { $_.Key })

# The per-topic render delta Assert-RenderDelta writes, and the archive every
# delta is copied into so a record's deltaSha can be resolved after any number
# of later renders. Both names are read by Assert-RenderDelta from here.
$script:LedgerDeltaFile    = 'render-delta.json'
$script:LedgerDeltaArchive = 'render-deltas'

#  The file name rule for a stage's machine results: <stage>-results.json in
#  the build directory. The stage is READ OUT OF THE FILE NAME - there is no
#  list of files here to drift from the runners. '3c-results.partial.json' and
#  the legacy 'stage4-results.json' do not match it and are not stage results.
$script:LedgerResultsFileRx = '^(?<stage>\d[0-9a-z-]*)-results\.json$'

#  Records written by this version carry it. A record without it is legacy: its
#  missing span is REPORTED, never accepted as a span and never silently taken
#  for one.
$script:LedgerRecordVersion = 2

#  The extracts whose stamp says whether the document a reviewer read still had
#  unresolved prompt blocks in it (Get-DocText writes the stamp).
$script:LedgerExtractFiles = @('guide_gate.txt', 'deck_gate.txt')

# ---------------------------------------------------------------------------
# Small shared helpers
# ---------------------------------------------------------------------------

function Get-LedgerPath {
    param([Parameter(Mandatory)][string] $BuildDir)
    Join-Path $BuildDir 'stage-ledger.json'
}

function Read-LedgerJson {
    <# Explicit UTF-8, BOM dropped. PS 5.1 reads a BOM-less file as ANSI and chokes on a BOM left on a JSON string. #>
    param([Parameter(Mandatory)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $t = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path, [System.Text.Encoding]::UTF8).TrimStart([char]0xFEFF)
    if (-not $t.Trim()) { return $null }
    return ($t | ConvertFrom-Json)
}

function Get-RenderDeltaSha {
    <# SHA256 of a file's bytes, lower-case hex - the same value Get-FileHash prints. '' when the file is absent. #>
    param([Parameter(Mandatory)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path).Path)
        return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLower()
    }
    finally { $sha.Dispose() }
}

function Get-LedgerFileSha256 {
    <# The one file hash this file uses, under the name the rest of the ledger reads. #>
    param([Parameter(Mandatory)][string] $Path)
    return (Get-RenderDeltaSha -Path $Path)
}

function Test-LedgerHasProp {
    <# Presence, for both shapes a record arrives in. @($x).Count -gt 0 on a property that does not exist answers YES. #>
    param($Object, [Parameter(Mandatory)][string] $Name)
    if ($null -eq $Object) { return $false }
    if ($Object -is [System.Collections.IDictionary]) { return $Object.Contains($Name) }
    return (@($Object.PSObject.Properties.Name) -contains $Name)
}

function Get-LedgerCount {
    <# @($null).Count is 1. This answers "how many" without that lie. #>
    param($Value)
    if ($null -eq $Value) { return 0 }
    if ($Value -is [string]) { if ($Value -eq '') { return 0 } else { return 1 } }
    if ($Value -is [System.Collections.ICollection]) { return $Value.Count }
    return 1
}

function ConvertTo-LedgerDateTime {
    <# An ISO timestamp to a UTC [datetime], or $null. A zone-less value is taken as UTC, which is the only zone this ledger writes. #>
    param([AllowNull()][AllowEmptyString()][string] $Text)
    $s = "$Text".Trim()
    if (-not $s) { return $null }
    $d = $null
    try {
        $d = [datetime]::Parse($s, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
    }
    catch { return $null }
    if ($d.Kind -eq [System.DateTimeKind]::Unspecified) { $d = [datetime]::SpecifyKind($d, [System.DateTimeKind]::Utc) }
    return $d.ToUniversalTime()
}

function Get-LedgerUtcNow {
    return (Get-Date).ToUniversalTime().ToString('o')
}

function Get-LedgerUtc {
    <#
      THE ONE READ of a record's time. Every staleness comparison reads ended;
      utc (the append time) is the fallback for legacy records, and started the
      fallback after that. -Start reads the other end of the span. $null when
      the record carries no time at all.
    #>
    param([Parameter(Mandatory)] $Record, [switch] $Start)
    $names = if ($Start) { @('started', 'utc', 'ended') } else { @('ended', 'utc', 'started') }
    foreach ($n in $names) {
        if (-not (Test-LedgerHasProp -Object $Record -Name $n)) { continue }
        $v = if ($Record -is [System.Collections.IDictionary]) { $Record[$n] } else { $Record.$n }
        $d = ConvertTo-LedgerDateTime -Text "$v"
        if ($null -ne $d) { return $d }
    }
    return $null
}

function Get-LedgerRecordNote {
    <# The operator's written reason: operatorNote where the record has one, else note. #>
    param([Parameter(Mandatory)] $Record)
    foreach ($n in @('operatorNote', 'note')) {
        if ((Test-LedgerHasProp -Object $Record -Name $n) -and "$($Record.$n)".Trim()) { return "$($Record.$n)" }
    }
    return ''
}

function Get-LedgerEditDistance {
    <#
      Levenshtein, used only to name the nearest stage key in a refusal.
      The 2-D indices are assigned to temporaries first: inside a method-call
      argument list PS 5.1 parses $d[($i-1), $j] as a single index expression
      and the file does not compile.
    #>
    param([string] $A, [string] $B)
    $la = $A.Length; $lb = $B.Length
    $d = New-Object 'int[,]' ($la + 1), ($lb + 1)
    for ($i = 0; $i -le $la; $i++) { $d[$i, 0] = $i }
    for ($j = 0; $j -le $lb; $j++) { $d[0, $j] = $j }
    for ($i = 1; $i -le $la; $i++) {
        for ($j = 1; $j -le $lb; $j++) {
            $cost = 1
            if ($A[$i - 1] -eq $B[$j - 1]) { $cost = 0 }
            $up   = $d[($i - 1), $j] + 1
            $left = $d[$i, ($j - 1)] + 1
            $diag = $d[($i - 1), ($j - 1)] + $cost
            $best = $up
            if ($left -lt $best) { $best = $left }
            if ($diag -lt $best) { $best = $diag }
            $d[$i, $j] = $best
        }
    }
    return $d[$la, $lb]
}

function Get-LedgerNearestStageKey {
    <# The table key closest to an unknown one: edit distance, then the nearest leading digit, then table order. #>
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Key)
    $best = $null; $bestScore = [int]::MaxValue
    $lead = -1
    if ($Key -match '^(\d)') { $lead = [int]$Matches[1] }
    $i = 0
    foreach ($k in $script:LedgerOrder) {
        $score = (Get-LedgerEditDistance -A $Key.ToLowerInvariant() -B $k.ToLowerInvariant()) * 1000
        if ($lead -ge 0 -and $k -match '^(\d)') { $score += [Math]::Abs($lead - [int]$Matches[1]) * 10 }
        $score += $i
        if ($score -lt $bestScore) { $bestScore = $score; $best = $k }
        $i++
    }
    return $best
}

function Assert-LedgerStageKey {
    <#
      Refuses an unknown stage key, naming the nearest known one. Case, spacing
      and the old '7b-ii' are NOT normalised: a record written under a key the
      table does not carry is a record no rule can find.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Stage)
    if ($null -ne (Get-LedgerStage -Key $Stage)) { return }
    $keys = ($script:LedgerOrder -join ', ')
    if ($script:LedgerRenamedKeys.ContainsKey($Stage)) {
        throw ("Unknown stage key '{0}': it was renamed to '{1}'. Nothing is normalised - pass '{1}'. (7b is placement; 7b-i is generate + review.) The stage keys are: {2}." -f $Stage, $script:LedgerRenamedKeys[$Stage], $keys)
    }
    $near = Get-LedgerNearestStageKey -Key $Stage
    throw ("Unknown stage key '{0}'. Nearest known key: '{1}'. Nothing is normalised. The stage keys are: {2}." -f $Stage, $near, $keys)
}

function Get-LedgerVerdictNames {
    <#
      The closed verdict vocabulary, READ FROM Merge-AuditFindings.ps1 BY AST -
      the $script:VerdictNames assignment - so this file never carries a copy
      that can drift. The first name is the best verdict. Throws naming the
      file when the assignment cannot be found: a verdict rule with no
      vocabulary is a blocking rule with an absent input.
    #>
    param([string] $Path)
    if (-not $Path) { $Path = Join-Path $script:LedgerScriptRoot 'Merge-AuditFindings.ps1' }
    if ($null -ne $script:LedgerVerdictNamesCache -and $script:LedgerVerdictNamesPath -eq $Path) { return @($script:LedgerVerdictNamesCache) }
    if (-not (Test-Path -LiteralPath $Path)) {
        throw ('Verdict vocabulary: {0} does not exist, so the closed verdict vocabulary ($script:VerdictNames) cannot be read. A verdict rule with no vocabulary is a blocking rule with an absent input.' -f $Path)
    }
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path -LiteralPath $Path).Path, [ref]$tokens, [ref]$errors)
    if ($errors -and $errors.Count) {
        throw ("Verdict vocabulary: {0} does not parse ({1}); the vocabulary cannot be read from it." -f $Path, $errors[0].Message)
    }
    $assign = @($ast.FindAll({
        param($n)
        $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $n.Left.Extent.Text -match '^\$script:VerdictNames$'
    }, $true))
    if ($assign.Count -eq 0) {
        throw ('Verdict vocabulary: {0} carries no $script:VerdictNames = @(...) assignment. The ledger reads the closed verdict vocabulary from there and never carries a copy.' -f $Path)
    }
    $names = @($assign[0].Right.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) | ForEach-Object { "$($_.Value)".Trim() } | Where-Object { $_ })
    if ($names.Count -eq 0) {
        throw ('Verdict vocabulary: the $script:VerdictNames assignment in {0} carries no string constants.' -f $Path)
    }
    $script:LedgerVerdictNamesCache = $names
    $script:LedgerVerdictNamesPath = $Path
    return @($names)
}

function Get-LedgerVerdictRank {
    <#
      0 for the best verdict, 1, 2, ... down the vocabulary; -1 for a verdict
      that names none of them.

      The WORST name found anywhere in the string wins. Merge-AuditFindings
      writes 'delivery set Fully Compliant (guide Fully Compliant; deck
      Partially Compliant)': an anchored read of the first word would rank that
      best and let a Partially Compliant deck ship. Reading every name and
      taking the worst can only ever make the rule stricter.
    #>
    param([AllowNull()][AllowEmptyString()][string] $Verdict, [string[]] $Names)
    if ($null -eq $Names -or $Names.Count -eq 0) { $Names = Get-LedgerVerdictNames }
    $v = "$Verdict".Trim()
    if (-not $v) { return -1 }
    $rank = -1
    for ($i = 0; $i -lt $Names.Count; $i++) {
        $n = [regex]::Escape($Names[$i])
        if ($v -match ('(?i)(^|[^A-Za-z])' + $n + '([^A-Za-z]|$)')) { if ($i -gt $rank) { $rank = $i } }
    }
    return $rank
}


# ---------------------------------------------------------------------------
# Machine results: the <stage>-results.json a runner writes, read into one
# shape whichever runner wrote it, and the checks that derive a record's
# status from it. Two shapes exist: Run-SpineGates' 0/1/2/3c-results.json
# (gates[] with verdict PASS|FAIL|NOT RUN|REFUSED and exitCode; spineFingerprint;
# partial; verdict; exitCode) and Run-Gates' 4-results.json / 7c-results.json
# (the same keys plus afterArtwork, inputs{} hashes and artefacts[]).
#
# ABSENT FIELDS ARE TOLERATED BY BEING REPORTED BY NAME. Nothing absent is
# read as zero and nothing absent is read as pass.
# ---------------------------------------------------------------------------

function ConvertTo-LedgerGateVerdict {
    <#  One vocabulary for a gate's verdict: pass | fail | gate-defect | not-run
        | refused | not-implemented | not-applicable | unknown:<raw>.

        gate-defect is the member that exited 4: it could not re-find its own
        anchor at the token boundary it declared, so it judged nothing about the
        content. It is NOT a fail (nothing in the document is to be remediated
        against it) and NOT an unrun state (a partial entry may not name it) -
        it is its own class, and every rule below names it as one.  #>
    param([AllowNull()][AllowEmptyString()][string] $Raw)
    $v = "$Raw".Trim().ToLowerInvariant() -replace '[\s_]+', '-'
    switch -Regex ($v) {
        '^pass(ed)?$'                         { return 'pass' }
        '^fail(ed)?$'                         { return 'fail' }
        '^gate-?defect(ive)?$'                { return 'gate-defect' }
        '^not-?run$'                          { return 'not-run' }
        '^refused$'                           { return 'refused' }
        '^not-?implemented$'                  { return 'not-implemented' }
        '^(not-?applicable|n-?a|deferred)$'   { return 'not-applicable' }
        default                               { return ('unknown:' + $v) }
    }
}

function Test-LedgerGateUnrun {
    <# The states a -Partial entry may name: the gate did not judge anything. #>
    param([string] $Verdict)
    return ($Verdict -in @('not-run', 'refused', 'not-implemented', 'not-applicable'))
}

function Get-StageMachineResults {
    <#
      Every <stage>-results.json in the build directory, mapped to its stage BY
      THE FILE NAME RULE ($script:LedgerResultsFileRx). Derived from the disk,
      never from a list of files this file would have to keep in step with the
      runners.
    #>
    param([Parameter(Mandatory)][string] $BuildDir)
    $out = @{}
    if (-not (Test-Path -LiteralPath $BuildDir)) { return $out }
    foreach ($f in (Get-ChildItem -LiteralPath $BuildDir -Filter '*-results.json' -File -ErrorAction SilentlyContinue)) {
        if ($f.Name -match $script:LedgerResultsFileRx) { $out[$Matches['stage']] = $f.FullName }
    }
    return $out
}

function Get-StageMachineResult {
    <#
      The results file for ONE stage, read into a fixed shape, or $null when
      the stage has no file. Fields the file does not carry come back $null or
      empty - the CALLER decides what an absence means, and every caller in
      this file names it.
    #>
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [Parameter(Mandatory)][string] $Stage
    )
    $files = Get-StageMachineResults -BuildDir $BuildDir
    if (-not $files.ContainsKey($Stage)) { return $null }
    $path = $files[$Stage]
    $raw = $null
    try { $raw = Read-LedgerJson -Path $path } catch { throw ("{0} does not parse as JSON: {1}" -f $path, $_.Exception.Message) }
    if ($null -eq $raw) { throw ("{0} is empty. A results file with nothing in it records no run." -f $path) }
    $fi = Get-Item -LiteralPath $path

    $verdictRaw = ''
    if (Test-LedgerHasProp $raw 'verdict') { $verdictRaw = "$($raw.verdict)" }
    $exitCode = $null
    if ((Test-LedgerHasProp $raw 'exitCode') -and $null -ne $raw.exitCode -and "$($raw.exitCode)" -match '^-?\d+$') { $exitCode = [int]$raw.exitCode }
    $partial = $false
    if (Test-LedgerHasProp $raw 'partial') { $partial = [bool]$raw.partial }
    $fp = ''
    if (Test-LedgerHasProp $raw 'spineFingerprint') { $fp = "$($raw.spineFingerprint)".Trim() }
    $after = $null
    if (Test-LedgerHasProp $raw 'afterArtwork') { $after = [bool]$raw.afterArtwork }
    $ranAtRaw = ''
    if (Test-LedgerHasProp $raw 'ranAt') { $ranAtRaw = "$($raw.ranAt)" }
    $ranAt = ConvertTo-LedgerDateTime -Text $ranAtRaw
    $startedAtRaw = ''
    if (Test-LedgerHasProp $raw 'startedAt') { $startedAtRaw = "$($raw.startedAt)" }
    $seconds = $null
    foreach ($n in @('wallClockSeconds', 'seconds', 'totalSeconds')) {
        if ((Test-LedgerHasProp $raw $n) -and $null -ne $raw.$n -and "$($raw.$n)" -match '^-?\d+(\.\d+)?$') { $seconds = [double]$raw.$n; break }
    }

    # gates[] - both shapes
    $gates = New-Object System.Collections.Generic.List[object]
    if (Test-LedgerHasProp $raw 'gates') {
        foreach ($g in @($raw.gates)) {
            if ($null -eq $g) { continue }
            $gExit = $null
            if ((Test-LedgerHasProp $g 'exitCode') -and $null -ne $g.exitCode -and "$($g.exitCode)" -match '^-?\d+$') { $gExit = [int]$g.exitCode }
            $gPartial = @()
            if (Test-LedgerHasProp $g 'partial') { $gPartial = @($g.partial | Where-Object { $null -ne $_ -and "$_".Trim() } | ForEach-Object { "$_" }) }
            $gSeconds = $null
            if ((Test-LedgerHasProp $g 'seconds') -and $null -ne $g.seconds -and "$($g.seconds)" -match '^-?\d+(\.\d+)?$') { $gSeconds = [double]$g.seconds }
            $gRefused = $false
            if (Test-LedgerHasProp $g 'refused') { $gRefused = [bool]$g.refused }
            $gRawVerdict = ''
            if (Test-LedgerHasProp $g 'verdict') { $gRawVerdict = "$($g.verdict)" }
            $gVerdict = ConvertTo-LedgerGateVerdict -Raw $gRawVerdict
            if ($gVerdict -eq 'unknown:' -and $gRefused) { $gVerdict = 'refused' }
            $gName = '(unnamed gate)'
            if ((Test-LedgerHasProp $g 'name') -and "$($g.name)".Trim()) { $gName = "$($g.name)" }
            $gReason = ''
            if (Test-LedgerHasProp $g 'reason') { $gReason = "$($g.reason)" }
            $gates.Add([pscustomobject]@{
                Name       = $gName
                Verdict    = $gVerdict
                RawVerdict = $gRawVerdict
                ExitCode   = $gExit
                Seconds    = $gSeconds
                Partial    = @($gPartial)
                Refused    = $gRefused
                Reason     = $gReason
            })
        }
    }

    # inputs - a map name -> sha, name -> { sha256, path }, or a list of { name|path, sha256 }
    $inputs = New-Object System.Collections.Generic.List[object]
    if ((Test-LedgerHasProp $raw 'inputs') -and $null -ne $raw.inputs) {
        $node = $raw.inputs
        $isList = ($node -is [System.Collections.IEnumerable] -and $node -isnot [string] -and $node -isnot [System.Collections.IDictionary] -and $null -eq $node.PSObject.Properties['sha256'])
        if ($isList) {
            foreach ($e in @($node)) {
                if ($null -eq $e) { continue }
                $n = Get-GateProp -Object $e -Names @('name', 'path', 'file') -Default ''
                $s = Get-GateProp -Object $e -Names @('sha256', 'sha', 'hash') -Default ''
                $inputs.Add([pscustomobject]@{ Name = "$n"; Path = "$n"; Sha256 = "$s".Replace('-', '').ToLowerInvariant() })
            }
        }
        else {
            foreach ($p in @($node.PSObject.Properties)) {
                $val = $p.Value
                $s = ''; $pth = "$($p.Name)"
                if ($val -is [string]) { $s = $val }
                elseif ($null -ne $val) {
                    $s = "$(Get-GateProp -Object $val -Names @('sha256', 'sha', 'hash') -Default '')"
                    $pp = Get-GateProp -Object $val -Names @('path', 'file') -Default ''
                    if ($pp) { $pth = "$pp" }
                }
                $inputs.Add([pscustomobject]@{ Name = "$($p.Name)"; Path = $pth; Sha256 = "$s".Replace('-', '').ToLowerInvariant() })
            }
        }
    }

    # artefacts[] - { path, sha256, lastWriteUtc }; the top-level guide/deck
    # paths name what the run judged when the payload carries no artefacts[].
    $artefacts = New-Object System.Collections.Generic.List[object]
    foreach ($key in @('artefacts', 'artifacts')) {
        if (-not (Test-LedgerHasProp $raw $key)) { continue }
        foreach ($a in @($raw.$key)) {
            if ($null -eq $a) { continue }
            $pth = "$(Get-GateProp -Object $a -Names @('path', 'file', 'name') -Default '')"
            if (-not $pth) { continue }
            $s = "$(Get-GateProp -Object $a -Names @('sha256', 'sha', 'hash') -Default '')"
            $lw = "$(Get-GateProp -Object $a -Names @('lastWriteUtc', 'lastWrite') -Default '')"
            $artefacts.Add([pscustomobject]@{ Path = $pth; Leaf = (Split-Path $pth -Leaf); Sha256 = $s.Replace('-', '').ToLowerInvariant(); LastWriteUtc = $lw })
        }
    }
    foreach ($key in @('guide', 'deck')) {
        if (-not (Test-LedgerHasProp $raw $key)) { continue }
        $pth = "$($raw.$key)".Trim()
        if (-not $pth) { continue }
        $leaf = Split-Path $pth -Leaf
        if (@($artefacts | Where-Object { $_.Leaf -ieq $leaf }).Count -eq 0) {
            $artefacts.Add([pscustomobject]@{ Path = $pth; Leaf = $leaf; Sha256 = ''; LastWriteUtc = '' })
        }
    }

    #  THE GATE-DEFECT SET IS READ FIRST AND SUBTRACTED FROM THE FAILURES. A
    #  member that exited 4 could not re-find its own anchor, so it found a
    #  defect in its own check-set and none in the document. Run-SpineGates
    #  lists it in defective[] and keeps it out of failed[]; a file that puts
    #  the same name in both is contradicting itself, and the contradiction is
    #  reported by name rather than resolved silently either way.
    $defective = @()
    if (Test-LedgerHasProp $raw 'defective') {
        foreach ($n in @($raw.defective | Where-Object { $null -ne $_ -and "$_".Trim() })) { if ($defective -notcontains "$n") { $defective += "$n" } }
    }
    foreach ($g in $gates) { if ($g.Verdict -eq 'gate-defect' -and $defective -notcontains $g.Name) { $defective += $g.Name } }

    $failedAll = @($gates | Where-Object { $_.Verdict -eq 'fail' } | ForEach-Object { $_.Name })
    $unrun  = @($gates | Where-Object { Test-LedgerGateUnrun -Verdict $_.Verdict } | ForEach-Object { $_.Name })
    $unknown = @($gates | Where-Object { $_.Verdict -like 'unknown:*' } | ForEach-Object { $_.Name })
    if (Test-LedgerHasProp $raw 'failed') {
        foreach ($n in @($raw.failed | Where-Object { $_ })) { if ($failedAll -notcontains "$n") { $failedAll += "$n" } }
    }
    $bothLists = @($failedAll | Where-Object { $defective -contains $_ })
    $failed = @($failedAll | Where-Object { $defective -notcontains $_ })

    [pscustomobject]@{
        Stage        = $Stage
        File         = $fi.Name
        Path         = $fi.FullName
        Sha256       = (Get-LedgerFileSha256 -Path $fi.FullName)
        LastWriteUtc = $fi.LastWriteTimeUtc
        RanAt        = $ranAt
        RanAtRaw     = $ranAtRaw
        StartedAtRaw = $startedAtRaw
        Seconds      = $seconds
        Verdict      = $verdictRaw
        VerdictIsPass = ($verdictRaw -match '^(?i)pass$')
        ExitCode     = $exitCode
        Partial      = $partial
        SpineFingerprint = $fp
        AfterArtwork = $after
        Gates        = $gates.ToArray()
        FailedGates  = $failed
        DefectiveGates = $defective
        FailedAndDefective = $bothLists
        UnrunGates   = $unrun
        UnknownGates = $unknown
        Inputs       = $inputs.ToArray()
        Artefacts    = $artefacts.ToArray()
        Raw          = $raw
    }
}

function Get-LedgerMachineNote {
    <# The generated note: 'N PASS, N FAIL (names), N NOT RUN (names)'. Nothing here is typed by a person. #>
    param([Parameter(Mandatory)] $Machine)
    $pass = @($Machine.Gates | Where-Object { $_.Verdict -eq 'pass' }).Count
    $fail = @($Machine.FailedGates).Count
    $notRun = @($Machine.UnrunGates).Count
    $vlabel = 'NO VERDICT'
    if ("$($Machine.Verdict)".Trim()) { $vlabel = "$($Machine.Verdict)".ToUpperInvariant() }
    $s = ("{0} {1}: {2} PASS, {3} FAIL" -f $Machine.File, $vlabel, $pass, $fail)
    if ($fail -gt 0) { $s += (" ({0})" -f (@($Machine.FailedGates) -join ', ')) }
    $s += (", {0} NOT RUN" -f $notRun)
    if ($notRun -gt 0) { $s += (" ({0})" -f (@($Machine.UnrunGates) -join ', ')) }
    if (@($Machine.DefectiveGates).Count) { $s += (", {0} GATE-DEFECT ({1})" -f @($Machine.DefectiveGates).Count, (@($Machine.DefectiveGates) -join ', ')) }
    if (@($Machine.UnknownGates).Count) { $s += (", {0} UNKNOWN VERDICT ({1})" -f @($Machine.UnknownGates).Count, (@($Machine.UnknownGates) -join ', ')) }
    return $s
}

function Test-LedgerNameMatches {
    <# Does a free-text partial entry name this gate? Whole-token, case-insensitive. #>
    param([string] $Text, [string] $Name)
    if (-not $Text -or -not $Name) { return $false }
    return ($Text -match ('(?i)(^|[^A-Za-z0-9-])' + [regex]::Escape($Name) + '([^A-Za-z0-9-]|$)'))
}

function Get-LedgerMachineFindings {
    <#
      THE CHECKS THAT DERIVE A PASS FROM A RESULTS FILE. Called by
      Add-StageRecord when the record is written and by Test-StageLedger every
      time the ledger is read, so the two can never disagree.

      Returns .Problems (each one a refusal), .Partial (reported, not refused -
      an absent field named by name), .FingerprintState and .InputsChecked.
    #>
    param(
        [Parameter(Mandatory)][string] $Stage,
        [Parameter(Mandatory)] $Machine,
        [Parameter(Mandatory)][string] $BuildDir,
        [string] $SpineDir,
        [string[]] $PartialClaims
    )
    $problems = New-Object System.Collections.Generic.List[string]
    $partial  = New-Object System.Collections.Generic.List[string]
    if (-not $SpineDir) { $SpineDir = Join-Path $BuildDir 'spine' }
    $file = $Machine.File

    # -Partial entries are judged FIRST, because laundering a FAIL into partial[]
    # is the exact move this rule exists to refuse, and it deserves its own name.
    foreach ($claim in @($PartialClaims | Where-Object { $null -ne $_ -and "$_".Trim() })) {
        $namesFail = @($Machine.FailedGates | Where-Object { Test-LedgerNameMatches -Text $claim -Name $_ })
        if ($namesFail.Count) {
            $problems.Add(("Stage {0}: -Partial entry '{1}' names {2}, which {3} lists as FAIL. partial[] is for rules that could not run, never for rules that ran and failed; a failing gate is remediated, or the stage is recorded fail." -f $Stage, $claim, ($namesFail -join ', '), $file))
            continue
        }
        $namesDefect = @($Machine.DefectiveGates | Where-Object { Test-LedgerNameMatches -Text $claim -Name $_ })
        if ($namesDefect.Count) {
            $problems.Add(("Stage {0}: -Partial entry '{1}' names {2}, which {3} lists as GATE-DEFECT. partial[] is for rules that could not run; a gate that cannot re-find its own anchor at the boundary it declared is a BROKEN GATE to fix and re-run, never a rule to file as partial and never a finding about the document. Filing it here is how a gate defect becomes a permanent exception." -f $Stage, $claim, ($namesDefect -join ', '), $file))
            continue
        }
        $namesUnrun = @($Machine.UnrunGates | Where-Object { Test-LedgerNameMatches -Text $claim -Name $_ })
        $namesRule = @()
        foreach ($g in $Machine.Gates) {
            foreach ($r in @($g.Partial)) {
                if ($claim -match ('(?i)' + [regex]::Escape($r)) -or $r -match ('(?i)' + [regex]::Escape($claim))) { $namesRule += ("{0}: {1}" -f $g.Name, $r) }
            }
        }
        if ($namesUnrun.Count -eq 0 -and $namesRule.Count -eq 0) {
            $listed = 'the file lists none'
            if (@($Machine.UnrunGates).Count) { $listed = (@($Machine.UnrunGates) -join ', ') }
            $problems.Add(("Stage {0}: -Partial entry '{1}' names nothing that {2} lists as refused, not run, not implemented, or a rule left unrun inside a gate ({3}). A partial entry must name the gate or rule the file itself says did not run." -f $Stage, $claim, $file, $listed))
        }
    }

    if (-not $Machine.VerdictIsPass) {
        $vshown = 'NONE'
        if ("$($Machine.Verdict)".Trim()) { $vshown = "$($Machine.Verdict)" }
        $exitShown = ''
        if ($null -ne $Machine.ExitCode) { $exitShown = (" (exit {0})" -f $Machine.ExitCode) }
        $failShown = 'none named'
        if (@($Machine.FailedGates).Count) { $failShown = (@($Machine.FailedGates) -join ', ') }
        $problems.Add(("Stage {0}: {1} records verdict '{2}'{3}; failing gates: {4}. A stage is recorded pass only over a file that says pass." -f $Stage, $file, $vshown, $exitShown, $failShown))
    }
    elseif ($null -ne $Machine.ExitCode -and $Machine.ExitCode -ne 0) {
        $problems.Add(("Stage {0}: {1} says verdict '{2}' but exitCode {3}. A non-zero exit is not a pass." -f $Stage, $file, $Machine.Verdict, $Machine.ExitCode))
    }
    if ($null -eq $Machine.ExitCode) {
        $partial.Add(("Stage {0}: {1} carries no exitCode, so the run's own exit status cannot be read (reported, never taken for zero)." -f $Stage, $file))
    }
    if ($Machine.Partial) {
        $onlyShown = ''
        if ((Test-LedgerHasProp $Machine.Raw 'only') -and (Get-LedgerCount -Value $Machine.Raw.only) -gt 0) { $onlyShown = (" (only: {0})" -f (@($Machine.Raw.only) -join ', ')) }
        $problems.Add(("Stage {0}: {1} is a PARTIAL run{2}. A partial run is not the band; run the whole set and record that." -f $Stage, $file, $onlyShown))
    }
    if ($Machine.VerdictIsPass -and @($Machine.FailedGates).Count) {
        $problems.Add(("Stage {0}: {1} says verdict pass while listing FAIL for {2}." -f $Stage, $file, (@($Machine.FailedGates) -join ', ')))
    }
    #  THE GATE-DEFECT CLASS. A member that exited 4 did not judge the content:
    #  it could not re-find its own anchor. Two rules, both by name.
    if (@($Machine.DefectiveGates).Count) {
        $problems.Add(("Stage {0}: {1} lists {2} GATE-DEFECT member(s): {3}. A gate that cannot re-find its own quote at the token boundary it declared examined a defect it invented, so nothing it says about this spine can be believed and the band's verdict cannot carry a stage pass. Fix the gate and re-run the band; do not remediate the document against its findings, and do not file it as a partial." -f $Stage, $file, @($Machine.DefectiveGates).Count, (@($Machine.DefectiveGates) -join ', ')))
    }
    if (@($Machine.FailedAndDefective).Count) {
        $problems.Add(("Stage {0}: {1} lists {2} in BOTH failed[] and defective[]. A GATE-DEFECT member is not a content failure - it is a broken gate - and counting it as one is exactly the confusion defective[] exists to end. The runner writes it to one list; a file carrying both is not evidence of anything." -f $Stage, $file, (@($Machine.FailedAndDefective) -join ', ')))
    }
    if (@($Machine.UnknownGates).Count) {
        $shown = (@($Machine.Gates | Where-Object { $_.Verdict -like 'unknown:*' } | ForEach-Object { "{0}='{1}'" -f $_.Name, $_.RawVerdict }) -join ', ')
        $problems.Add(("Stage {0}: {1} carries gate verdict(s) this ledger does not know ({2}) - neither pass, fail, nor an unrun state. Nothing unknown is read as pass." -f $Stage, $file, $shown))
    }
    if (@($Machine.Gates).Count -eq 0) {
        $problems.Add(("Stage {0}: {1} lists no gates at all. A results file with an empty gates[] records that nothing was judged; it is not evidence of a pass." -f $Stage, $file))
    }
    foreach ($g in $Machine.Gates) {
        if ($g.Verdict -eq 'pass' -and $null -ne $g.ExitCode -and $g.ExitCode -ne 0) {
            $problems.Add(("Stage {0}: {1} lists gate {2} as pass with exitCode {3}." -f $Stage, $file, $g.Name, $g.ExitCode))
        }
    }

    # the spine fingerprint stamped on the file against the spine on disk
    $fpState = 'not-stamped'
    if ($Machine.SpineFingerprint) {
        $current = ''
        try { $current = Get-SpineFingerprint -BuildDir $BuildDir -SpineDir $SpineDir -Quiet } catch { $current = '' }
        if (-not $current) {
            $problems.Add(("Stage {0}: {1} is stamped with spine fingerprint {2} but no spine can be fingerprinted at {3} (no directory, or no spine file in it). Nothing can say whether the file still describes this spine." -f $Stage, $file, $Machine.SpineFingerprint, $SpineDir))
            $fpState = 'no-spine'
        }
        else {
            $fpState = Test-GateFingerprintVersion -Stamp $Machine.SpineFingerprint -Current $current
            if ($fpState -eq 'version-changed') {
                $runner = Get-LedgerStageScript -Key $Stage
                if (-not $runner) { $runner = 'the runner' }
                $problems.Add(("Stage {0}: {1} is stamped with spine fingerprint '{2}' and the current fingerprint is '{3}' - the FINGERPRINT FORMAT changed, not necessarily the spine. Re-run the band ({4}) so the file is stamped in the current format; nothing can be said about the spine until then." -f $Stage, $file, $Machine.SpineFingerprint, $current, $runner))
            }
            elseif ($fpState -eq 'spine-moved') {
                $problems.Add(("Stage {0}: {1} was written against spine {2} and the spine is now {3}. The spine MOVED after the run; every verdict in the file describes a spine that no longer exists. Re-run it." -f $Stage, $file, $Machine.SpineFingerprint, $current))
            }
        }
    }
    else {
        $partial.Add(("Stage {0}: {1} carries no spineFingerprint stamp, so nothing can prove its verdicts were issued against this spine (machine.fingerprint = not-stamped)." -f $Stage, $file))
    }

    # input hashes against the disk
    $checked = 0
    foreach ($in in @($Machine.Inputs)) {
        if (-not $in.Sha256) { $partial.Add(("Stage {0}: {1} names input {2} with no hash, so that input cannot be proved unchanged." -f $Stage, $file, $in.Name)); continue }
        $p = $in.Path
        if (-not [System.IO.Path]::IsPathRooted($p)) { $p = Join-Path $BuildDir $p }
        if (-not (Test-Path -LiteralPath $p)) {
            $problems.Add(("Stage {0}: {1} hashed input {2} ({3}), which no longer exists." -f $Stage, $file, $in.Name, $p))
            continue
        }
        $now = Get-LedgerFileSha256 -Path $p
        $checked++
        if ($now -ne $in.Sha256) {
            $problems.Add(("Stage {0}: input {1} has moved since {2} was written (stamped {3}, now {4}). The verdicts were issued against an input the build no longer has; re-run the stage." -f $Stage, $in.Name, $file, $in.Sha256.Substring(0, [Math]::Min(12, $in.Sha256.Length)), $now.Substring(0, [Math]::Min(12, $now.Length))))
        }
    }

    [pscustomobject]@{
        Problems = $problems.ToArray()
        Partial  = $partial.ToArray()
        FingerprintState = $fpState
        InputsChecked = $checked
    }
}

function New-LedgerMachineBlock {
    <# What a record carries about the file it was derived from. Enough to re-derive later; nothing a person typed. #>
    param([Parameter(Mandatory)] $Machine, [Parameter(Mandatory)][string] $FingerprintState, [int] $InputsChecked)
    $exitShown = 'not-stamped'
    if ($null -ne $Machine.ExitCode) { $exitShown = $Machine.ExitCode }
    $inputsShown = 'not stamped'
    if (@($Machine.Inputs).Count) { $inputsShown = ("{0} of {1} verified" -f $InputsChecked, @($Machine.Inputs).Count) }
    return [ordered]@{
        source      = 'results-file'
        file        = $Machine.File
        sha256      = $Machine.Sha256
        ranAt       = $Machine.RanAtRaw
        verdict     = $Machine.Verdict
        exitCode    = $exitShown
        partial     = [bool]$Machine.Partial
        fingerprint = $FingerprintState
        gates       = [ordered]@{
            pass      = @($Machine.Gates | Where-Object { $_.Verdict -eq 'pass' }).Count
            fail      = @($Machine.FailedGates).Count
            notRun    = @($Machine.UnrunGates).Count
            defective = @($Machine.DefectiveGates).Count
            failed    = @($Machine.FailedGates)
            unrun     = @($Machine.UnrunGates)
            gateDefect = @($Machine.DefectiveGates)
        }
        inputs      = $inputsShown
    }
}

# ---------------------------------------------------------------------------
# The render delta: reading it, resolving a record's deltaSha, and the ONE
# definition of "this topic moved". Assert-RenderDelta dot-sources this file
# so the delta it writes and the rule that reads it can never disagree.
# ---------------------------------------------------------------------------

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
    $sorted = @($Records | Sort-Object { $d = Get-LedgerUtc -Record $_; if ($null -eq $d) { [datetime]::MinValue } else { $d } } -Descending)
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
            $rt = Get-LedgerUtc -Record $r
            if ($LastRender -and $null -ne $rt -and $rt -le $LastRender) {
                $reasons[$t] = ("covered only by the whole-artefact record of {0}, which does not postdate the render at {1}" -f $rt.ToString('u'), $LastRender.ToString('u'))
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


# ---------------------------------------------------------------------------
# Writing the ledger
# ---------------------------------------------------------------------------

function New-StageLedger {
    <# Creates an empty ledger. Safe to call on an existing one - it will not overwrite. #>
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [Parameter(Mandatory)][string] $Unit
    )
    $p = Get-LedgerPath -BuildDir $BuildDir
    if (Test-Path -LiteralPath $p) { return $p }
    $obj = [pscustomobject]@{
        unit    = $Unit
        created = (Get-LedgerUtcNow)
        version = $script:LedgerRecordVersion
        records = @()
    }
    $obj | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $p -Encoding UTF8
    return $p
}

function Add-StageRecord {
    <#
      Records one stage. Call it the moment the stage finishes, not at the end
      of the build - a record written from memory at the end is a record of
      what was intended, not of what happened.

      -Status  pass | fail | n-a | skipped. There is no fifth status: a
               dispositioned failure is a pass whose -ClearancesApplied are
               printed, never a new word.
               'skipped' is honest and allowed; it just will not pass
               Test-StageLedger for a blocking stage. 'n-a' is accepted at
               delivery only on the artwork stages and only with a note
               resolving to the Stage 2 no-go record.
      -Started / -Ended
               The real span, ISO 8601 UTC, sub-second. Omitted, they are
               derived from the stage's results file (startedAt / ranAt); with
               neither source the record carries spanKnown = false, and
               Test-StageLedger reports it. utc is kept as the APPEND time and
               is no longer what any staleness rule reads.
      -Machine A stage whose own writer produced the evidence (Stage 6, written
               by Merge-AuditFindings) passes the sha256 of what it wrote. A
               stage that has a results file must not: that file IS its machine
               record and is re-derived from disk.
      -Verdict Stages 6 and 7d: the compliance judgement, verbatim.
      -Findings Count of findings raised. Zero is a real result and is recorded as one.
      -Partial  Every blocking gate rule that could not run in this stage.
                Where the stage has a results file, each entry must name
                something that file lists as refused, not run or not
                implemented - naming a FAIL is refused here, at the point of
                writing. A partial record needs a written reason.
      -FigureSheet The figure sheet a Stage 5/6/7d reviewer was handed. It is
                required when the extract the reviewer read still stamped
                unresolved prompt blocks.
      -Topics   Stages 4b, 5 and 6: the topics this record covered - numbers,
                or 'all'. Topic 0 is the front and back matter.
      -DeltaSha The SHA256 of the render-delta.json the reviewer was handed.
    #>
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [Parameter(Mandatory)][AllowEmptyString()][string] $Stage,
        [Parameter(Mandatory)][string] $Name,
        [ValidateSet('pass','fail','n-a','skipped')][string] $Status = 'pass',
        [int]    $Round    = 0,
        [int]    $Findings = 0,
        [string] $Verdict,
        [string] $Note,
        [string] $OperatorNote,
        [string[]] $Partial,
        [string[]] $ClearancesApplied,
        [string[]] $Topics,
        [string] $DeltaSha,
        [string] $Started,
        [string] $Ended,
        [string] $Machine,
        [string] $FigureSheet,
        [string] $SpineDir
    )

    # ---- the key first: a record under a key the table does not carry is a
    #      record no rule can find.
    Assert-LedgerStageKey -Stage $Stage
    $row = Get-LedgerStage -Key $Stage

    $p = Get-LedgerPath -BuildDir $BuildDir
    if (-not (Test-Path -LiteralPath $p)) { throw "No stage ledger at $p. Call New-StageLedger first." }
    $l = Read-LedgerJson -Path $p
    if ($null -eq $l) { throw "The stage ledger at $p is empty or unreadable. A ledger that cannot be read cannot be added to." }
    $existing = @($l.records | Where-Object { $null -ne $_ })

    if (-not $SpineDir) { $SpineDir = Join-Path $BuildDir 'spine' }

    # ---- the round, validated against what this stage already carries
    if ($Round -lt 0) { throw ("Stage {0}: -Round {1} is negative. Rounds count up from 0." -f $Stage, $Round) }
    $priorRounds = @($existing | Where-Object { "$($_.stage)" -ceq $Stage } | ForEach-Object { if (Test-LedgerHasProp -Object $_ -Name 'round') { [int]$_.round } else { 0 } })
    if ($priorRounds.Count) {
        $newestRound = ($priorRounds | Sort-Object -Descending)[0]
        if ($Round -lt $newestRound) {
            throw ("Stage {0}: -Round {1} is LOWER than the newest round already recorded for this stage ({2}). A round number that goes backwards makes the newest record look like an earlier one, and every latest-per-stage rule then reads the wrong record." -f $Stage, $Round, $newestRound)
        }
    }

    # ---- the machine evidence: derived from the stage's results file, or
    #      supplied by the stage's own writer. Never both, never neither where
    #      a runner exists.
    $scriptName = "$($row.Script)".Trim()
    $machineBlock = 'none'
    $mr = $null
    $mf = $null
    $partialClaims = @($Partial | Where-Object { $null -ne $_ -and "$_".Trim() })

    if ($Machine) {
        if ($scriptName) {
            throw ("Stage {0}: -Machine was supplied, but stage {0} is written by {1} and its machine record is {0}-results.json, re-derived from disk every time the ledger is read. -Machine is for a stage whose own writer produced the evidence." -f $Stage, $scriptName)
        }
        if ("$Machine".Trim() -notmatch '^[0-9a-fA-F]{64}$') {
            throw ("Stage {0}: -Machine '{1}' is not a sha256 (64 hex characters). A machine-written record is told from a hand-written one by the hash of what the writer wrote; an unverifiable stamp is worse than none." -f $Stage, $Machine)
        }
        #  NO ROUND FLOOR HERE. Round 0 is the FIRST pass, not a missing value:
        #  it is this parameter's own default, and the Stage 7 rule reads
        #  "round > 0" to mean "a remediation cycle preceded this read". A
        #  writer whose first record was round 1 would make Stage 7 owed on a
        #  build that was clean first time, asking for a record of remediation
        #  that never happened - the failure this file's header warns about.
        #  A negative round is refused above, for every record, machine or not.
        $machineBlock = [ordered]@{
            source    = 'stage-writer'
            sha256    = "$Machine".ToLowerInvariant()
            writtenBy = $Name
            round     = $Round
        }
    }

    if ($scriptName) {
        $mr = Get-StageMachineResult -BuildDir $BuildDir -Stage $Stage
        if ($null -eq $mr) {
            if ($Status -eq 'pass') {
                throw ("Stage {0} is recorded pass but there is no {0}-results.json in {1}. {2} writes it, and a pass on this stage is DERIVED from that file - the ledger does not take a stage's word for its own result. Run the stage through {2}, or record the honest status." -f $Stage, $BuildDir, $scriptName)
            }
            $machineBlock = ("none - no {0}-results.json ({1} did not write one)" -f $Stage, $scriptName)
        }
        else {
            $mf = Get-LedgerMachineFindings -Stage $Stage -Machine $mr -BuildDir $BuildDir -SpineDir $SpineDir -PartialClaims $partialClaims
            if ($Status -eq 'pass' -and @($mf.Problems).Count) {
                throw (("Stage {0} cannot be recorded pass over {1}:" -f $Stage, $mr.File) + [Environment]::NewLine + '  - ' + (@($mf.Problems) -join ([Environment]::NewLine + '  - ')))
            }
            #  A -Partial entry that names a FAIL member is refused whatever the
            #  status: laundering a failure into partial[] is the move, and it
            #  is not made honest by recording the stage as fail as well.
            $launder = @($mf.Problems | Where-Object { $_ -match '-Partial entry' })
            if ($Status -ne 'pass' -and $launder.Count) {
                throw (("Stage {0}: the -Partial list is refused whatever the status:" -f $Stage) + [Environment]::NewLine + '  - ' + ($launder -join ([Environment]::NewLine + '  - ')))
            }
            $machineBlock = New-LedgerMachineBlock -Machine $mr -FingerprintState $mf.FingerprintState -InputsChecked $mf.InputsChecked
        }
    }

    # ---- the span
    $startedIso = ''
    $startedKnown = $false
    if ("$Started".Trim()) {
        if ($null -eq (ConvertTo-LedgerDateTime -Text $Started)) { throw ("Stage {0}: -Started '{1}' is not an ISO 8601 timestamp." -f $Stage, $Started) }
        $startedIso = (ConvertTo-LedgerDateTime -Text $Started).ToString('o'); $startedKnown = $true
    }
    elseif ($null -ne $mr) {
        $d = ConvertTo-LedgerDateTime -Text $mr.StartedAtRaw
        if ($null -eq $d -and $null -ne $mr.RanAt -and $null -ne $mr.Seconds) { $d = $mr.RanAt.AddSeconds(-1 * [double]$mr.Seconds) }
        if ($null -ne $d) { $startedIso = $d.ToString('o'); $startedKnown = $true }
    }

    $endedIso = ''
    $endedKnown = $false
    if ("$Ended".Trim()) {
        if ($null -eq (ConvertTo-LedgerDateTime -Text $Ended)) { throw ("Stage {0}: -Ended '{1}' is not an ISO 8601 timestamp." -f $Stage, $Ended) }
        $endedIso = (ConvertTo-LedgerDateTime -Text $Ended).ToString('o'); $endedKnown = $true
    }
    elseif ($null -ne $mr -and $null -ne $mr.RanAt) {
        $endedIso = $mr.RanAt.ToString('o'); $endedKnown = $true
    }
    $appendIso = Get-LedgerUtcNow
    if (-not $endedIso) { $endedIso = $appendIso }

    $spanKnown = ($startedKnown -and $endedKnown)
    $duration = $null
    if ($spanKnown) {
        $sd = ConvertTo-LedgerDateTime -Text $startedIso
        $ed = ConvertTo-LedgerDateTime -Text $endedIso
        if ($ed -lt $sd) {
            throw ("Stage {0}: the span ends before it starts (started {1}, ended {2})." -f $Stage, $startedIso, $endedIso)
        }
        if ($row.Blocking -and $ed -eq $sd) {
            throw ("Stage {0} ({1}) is a blocking stage recorded with started equal to ended ({2}). A blocking stage that took no measurable time did not run; pass the real -Started and -Ended, sub-second." -f $Stage, $Name, $startedIso)
        }
        $duration = [math]::Round(($ed - $sd).TotalSeconds, 3)
    }

    # ---- the record
    $rec = [ordered]@{
        stage    = $Stage
        name     = $Name
        status   = $Status
        round    = $Round
        findings = $Findings
        utc      = $appendIso
        started  = $startedIso
        ended    = $endedIso
        durationSeconds = $duration
        spanKnown = $spanKnown
        ledgerVersion = $script:LedgerRecordVersion
    }
    if ($Verdict) { $rec.verdict = $Verdict }

    #  The note is GENERATED where a results file exists; free text goes to
    #  operatorNote, so nothing a person typed can stand in for what the file
    #  said. On a build the typed note read "18 of 21" against 17 pass, 3 fail
    #  and 1 not run.
    if ($null -ne $mr) {
        $rec.note = Get-LedgerMachineNote -Machine $mr
        $op = @()
        if ("$Note".Trim()) { $op += "$Note" }
        if ("$OperatorNote".Trim()) { $op += "$OperatorNote" }
        if ($op.Count) { $rec.operatorNote = ($op -join ' ') }
    }
    else {
        if ("$Note".Trim()) { $rec.note = "$Note" }
        if ("$OperatorNote".Trim()) { $rec.operatorNote = "$OperatorNote" }
    }
    if ($partialClaims.Count) { $rec.partial = @($partialClaims) }
    $clear = @($ClearancesApplied | Where-Object { $null -ne $_ -and "$_".Trim() })
    if ($clear.Count) { $rec.clearancesApplied = @($clear) }
    if ("$FigureSheet".Trim()) { $rec.figureSheet = "$FigureSheet" }

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

    $rec.machine = $machineBlock

    $l.records = @($existing) + [pscustomobject]$rec
    $l | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $p -Encoding UTF8
    Write-Verbose ("stage {0} recorded: {1}" -f $Stage, $Status)
}

# ---------------------------------------------------------------------------
# The figure sheet, and the extract stamp that says whether a reviewer needed it
# ---------------------------------------------------------------------------

function Get-LedgerExtractPrompts {
    <#
      What Get-DocText stamped on each rendered extract: how many drawings were
      placed and how many artwork prompt blocks were still unresolved. Returns
      one row per extract that exists. An extract with no stamp is REPORTED as
      unstamped - it is never read as zero prompts.
    #>
    param([Parameter(Mandatory)][string] $BuildDir)
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($leaf in $script:LedgerExtractFiles) {
        $p = Join-Path $BuildDir $leaf
        if (-not (Test-Path -LiteralPath $p)) { continue }
        $head = ''
        try { $head = (Get-Content -LiteralPath $p -TotalCount 12 -ErrorAction Stop) -join "`n" } catch { $head = '' }
        $placed = $null; $prompts = $null
        if ($head -match '(?im)^\s*FIGURES:\s*(\d+)\s+placed drawings?,\s*(\d+)\s+unresolved artwork prompt blocks') {
            $placed = [int]$Matches[1]; $prompts = [int]$Matches[2]
        }
        $out.Add([pscustomobject]@{
            Leaf = $leaf; Path = $p; Placed = $placed; Prompts = $prompts
            Stamped = ($null -ne $prompts)
            LastWriteUtc = (Get-Item -LiteralPath $p).LastWriteTimeUtc
        })
    }
    return $out.ToArray()
}

function Get-LedgerSheetStamps {
    <# The stamps New-FigureSheet writes on a figure sheet. Absent stamps come back as '' and are named by the caller. #>
    param([Parameter(Mandatory)][string] $Path)
    $text = ''
    try { $text = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path, [System.Text.Encoding]::UTF8) } catch { $text = '' }
    $fp = ''
    #  v2 stamps read 'v2:<32 hex>'; a bare hex is a v1 stamp and is still
    #  matched here so the comparer - not the regex - can say "the fingerprint
    #  FORMAT changed, re-cut". A regex that only accepted bare hex reported
    #  every v2 sheet as carrying no stamp at all.
    if ($text -match '(?im)^\s*SPINE-FINGERPRINT:\s*((?:v\d+:)?[0-9a-fA-F]{8,})\s*$') { $fp = $Matches[1].Trim() }
    $bv = ''
    if ($text -match '(?im)^\s*BAND-VERDICT:\s*([A-Za-z-]+)') { $bv = $Matches[1].Trim().ToUpperInvariant() }
    $bs = ''
    if ($text -match '(?im)^\s*BAND-RESULTS-SHA256:\s*([0-9a-fA-F]{16,})\s*$') { $bs = $Matches[1].Trim().ToLowerInvariant() }
    $br = ''
    if ($text -match '(?im)^\s*BAND-RAN-AT:\s*(\S+)') { $br = $Matches[1].Trim() }
    $fr = ''
    if ($text -match '(?im)^\s*FORCE-REASON:\s*(.+)$') { $fr = $Matches[1].Trim() }
    [pscustomobject]@{ Path = $Path; Fingerprint = $fp; BandVerdict = $bv; BandResultsSha256 = $bs; BandRanAt = $br; ForceReason = $fr; HasText = [bool]$text }
}

function Test-FigureSheetCurrent {
    <#
      The figure sheet must still describe the spine the documents were
      rendered from, AND it must be the sheet the band cut. Returns .Ok,
      .Problems, .Sheet, .Expected, .Stamped and .BandVerdict.

      WHY IT IS A LEDGER RULE AND NOT A NOTE IN A DOCUMENT. The sheet is cut at
      the end of the 3c band and then travels with every later review pack, and
      the channel-disposition rule counts a Stage 5 or Stage 6 record as having
      read the figures if the figure sheet accompanied the extract. Stage 7
      edits the spine; nothing regenerates the sheet; and a reviewer is handed -
      in good faith, and with the ledger agreeing - a sheet describing figures
      the document no longer contains.

      THREE THINGS ARE CHECKED, AND EACH OF THEM WAS ONCE ABSENT.
        1  BAND-VERDICT PASS. The runner refused to cut the sheet from a failed
           spine, the documented direct command cut it nineteen seconds later
           anyway, and Stage 3d recorded it as cut. A sheet forced with -Force
           is stamped BAND-VERDICT FAIL exactly so it is reported here.
        2  An EMPTY expected fingerprint is a problem, not a pass. It means the
           spine could not be hashed, and a comparison against nothing was
           silently skipped.
        3  A Stage 5/6/7d record written while the rendered extract still
           stamped unresolved prompt blocks must NAME the sheet it was read
           with, and that sheet is checked here and now.
    #>
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [string] $SheetPath,
        [string] $SpineDir,
        $Records
    )

    if (-not $SheetPath) { $SheetPath = Join-Path $BuildDir 'figure-sheet.txt' }
    if (-not $SpineDir)  { $SpineDir  = Join-Path $BuildDir 'spine' }

    $problems = New-Object System.Collections.Generic.List[string]
    $expected = ''
    $stamped  = ''
    $bandVerdict = ''

    if (-not (Test-Path -LiteralPath $SpineDir)) {
        $problems.Add("No spine directory at $SpineDir, so the figure sheet cannot be proved current. Every gate in the 3c band reads the spine; a build without one has nothing for them to read.")
    }
    elseif (-not (Test-Path -LiteralPath $SheetPath)) {
        $problems.Add("No figure sheet at $SheetPath. The 3c band cuts it after the join and every later review pack carries it - without it no review record can claim to have read the figures. Cut it through scripts\Run-SpineGates.ps1; the direct scripts\New-FigureSheet.ps1 call refuses a spine the band did not pass.")
    }
    else {
        try { $expected = Get-SpineFingerprint -BuildDir $BuildDir -SpineDir $SpineDir -Quiet } catch { $expected = '' }
        $st = Get-LedgerSheetStamps -Path $SheetPath
        $stamped = $st.Fingerprint
        $bandVerdict = $st.BandVerdict

        if (-not $expected) {
            $problems.Add(("The spine at {0} exists but nothing in it could be fingerprinted, so the figure sheet at {1} cannot be compared against it. An empty expected fingerprint is a missing input, never a match: supply the spine files the band enumerates (Get-GateSpineFiles -IncludeFrontMatter -Exclude @())." -f $SpineDir, $SheetPath))
        }

        if (-not $stamped) {
            $problems.Add("The figure sheet at $SheetPath carries no SPINE-FINGERPRINT stamp, so nothing can tell whether it still describes this spine. Re-cut it through the 3c band.")
        }
        elseif ($expected) {
            $state = Test-GateFingerprintVersion -Stamp $stamped -Current $expected
            if ($state -eq 'version-changed') {
                $problems.Add(("The figure sheet at {0} is stamped with fingerprint '{1}' and the spine now fingerprints as '{2}' - the FINGERPRINT FORMAT changed, so nothing can be said about whether the spine moved. Re-cut the sheet through the 3c band." -f $SheetPath, $stamped, $expected))
            }
            elseif ($state -eq 'spine-moved') {
                $problems.Add(("The figure sheet at {0} was cut from spine {1} and the spine is now {2}. It is stale: every reviewer downstream of it read figure content this document no longer carries. Re-cut it through the 3c band and re-run any review that was handed the old one." -f $SheetPath, $stamped, $expected))
            }
        }

        if (-not $bandVerdict) {
            $problems.Add(("The figure sheet at {0} carries no BAND-VERDICT stamp, so nothing can tell whether the 3c band had passed when it was cut. A sheet cut from a failing spine carries content the remediation is about to change. Re-cut it through scripts\Run-SpineGates.ps1, which stamps the band verdict it cut under." -f $SheetPath))
        }
        elseif ($bandVerdict -ne 'PASS') {
            $reason = ''
            if ($st.ForceReason) { $reason = (" The sheet records FORCE-REASON: {0}" -f $st.ForceReason) }
            $problems.Add(("The figure sheet at {0} is stamped BAND-VERDICT {1}. It was cut from a spine the 3c band had not passed - a forced cut is stamped exactly so it can never reach delivery.{2} Fix the band, re-run it, and re-cut the sheet." -f $SheetPath, $bandVerdict, $reason))
        }
    }

    # ---- the reviewer who was handed an extract that still showed prompts
    $extracts = @(Get-LedgerExtractPrompts -BuildDir $BuildDir)
    $withPrompts = @($extracts | Where-Object { $_.Stamped -and $_.Prompts -gt 0 })
    $unstamped   = @($extracts | Where-Object { -not $_.Stamped })
    foreach ($e in $unstamped) {
        $problems.Add(("The rendered extract {0} carries no 'FIGURES: n placed drawings, m unresolved artwork prompt blocks' stamp, so nothing can tell whether the reviewers who read it were handed figure content or prompt blocks. Re-cut it with scripts\Get-DocText.ps1; an unstamped extract is not read as zero prompts." -f $e.Leaf))
    }
    if ($withPrompts.Count -and $null -ne $Records) {
        $recs = @($Records | Where-Object { $null -ne $_ })
        $names = ($withPrompts | ForEach-Object { ("{0} ({1} unresolved prompt block(s))" -f $_.Leaf, $_.Prompts) }) -join '; '
        foreach ($s in @('5', '6', '7d')) {
            $mine = @($recs | Where-Object { "$($_.stage)" -ceq $s })
            if (-not $mine.Count) { continue }
            $latest = @($mine | Sort-Object { $d = Get-LedgerUtc -Record $_; if ($null -eq $d) { [datetime]::MinValue } else { $d } } -Descending)[0]
            if ("$($latest.status)" -eq 'n-a') { continue }
            $named = ''
            if (Test-LedgerHasProp -Object $latest -Name 'figureSheet') { $named = "$($latest.figureSheet)".Trim() }
            if (-not $named) {
                $problems.Add(("Stage {0} ({1}) was recorded while the rendered extract still stamped unresolved artwork prompt blocks - {2} - and the record names no figure sheet. A reviewer handed a document whose figures are still prompt text has not read the figures unless the figure sheet went with the pack; record it with -FigureSheet <path>." -f $s, $latest.name, $names))
                continue
            }
            $np = $named
            if (-not [System.IO.Path]::IsPathRooted($np)) { $np = Join-Path $BuildDir $np }
            if (-not (Test-Path -LiteralPath $np)) {
                $problems.Add(("Stage {0} ({1}) names figure sheet '{2}', which does not exist at {3}. A record cannot claim a sheet nobody can read." -f $s, $latest.name, $named, $np))
                continue
            }
            $nst = Get-LedgerSheetStamps -Path $np
            if ($nst.BandVerdict -ne 'PASS') {
                $shown = $nst.BandVerdict
                if (-not $shown) { $shown = 'no BAND-VERDICT stamp at all' }
                $problems.Add(("Stage {0} ({1}) names figure sheet '{2}', which carries {3}. The figures that reviewer read were cut from a spine the 3c band had not passed." -f $s, $latest.name, $named, $shown))
            }
            elseif ($expected -and $nst.Fingerprint -and (Test-GateFingerprintVersion -Stamp $nst.Fingerprint -Current $expected) -ne 'match') {
                $problems.Add(("Stage {0} ({1}) names figure sheet '{2}', cut from spine {3}, and the spine is now {4}. That reviewer read figure content this document no longer carries." -f $s, $latest.name, $named, $nst.Fingerprint, $expected))
            }
        }
    }

    [pscustomobject]@{
        Ok          = ($problems.Count -eq 0)
        Problems    = $problems.ToArray()
        Sheet       = $SheetPath
        Expected    = $expected
        Stamped     = $stamped
        BandVerdict = $bandVerdict
        Extracts    = $extracts
    }
}


# ---------------------------------------------------------------------------
# Reading the ledger
# ---------------------------------------------------------------------------

function Get-LedgerLatestPerStage {
    <#
      The record that decides each stage: the newest by ended (utc for legacy
      records), and where two share an instant the one written later in the
      file. Without the index tie-break a same-second batch write decided the
      stage by hashtable order.
    #>
    param([Parameter(Mandatory)] $Records)
    $latest = @{}
    $i = 0
    foreach ($r in @($Records)) {
        if ($null -eq $r) { $i++; continue }
        $s = "$($r.stage)"
        $t = Get-LedgerUtc -Record $r
        if ($null -eq $t) { $t = [datetime]::MinValue }
        if (-not $latest.ContainsKey($s)) { $latest[$s] = [pscustomobject]@{ Record = $r; Time = $t; Index = $i } }
        else {
            $cur = $latest[$s]
            if ($t -gt $cur.Time -or ($t -eq $cur.Time -and $i -gt $cur.Index)) { $latest[$s] = [pscustomobject]@{ Record = $r; Time = $t; Index = $i } }
        }
        $i++
    }
    $out = @{}
    foreach ($k in $latest.Keys) { $out[$k] = $latest[$k].Record }
    return $out
}

function Get-LedgerStage7Requirement {
    <#
      THE ONE OWNER OF THE STAGE 7 RULE. Stage 7 is never in the unconditional
      required set - a build with no findings needs no remediation round, and
      requiring one pushes builds into inventing work. It becomes required when
      the ledger's own records say remediation happened or is owed:

        - a Stage 6 or 7d record carrying round > 0;
        - a Stage 6 or 7d record whose verdict is below the best one in the
          closed vocabulary Merge-AuditFindings.ps1 owns;
        - a Stage 6b record carrying a non-empty work order (a workOrder field
          with entries in it, or findings > 0 - an arbitration that raised
          findings IS a work order).

      Returns .Required and .Reasons.
    #>
    param([Parameter(Mandatory)] $Latest, [string[]] $VerdictNames)
    $reasons = New-Object System.Collections.Generic.List[string]
    foreach ($s in @('6', '7d')) {
        if (-not $Latest.ContainsKey($s)) { continue }
        $r = $Latest[$s]
        if ("$($r.status)" -eq 'n-a') { continue }
        $round = 0
        if ((Test-LedgerHasProp -Object $r -Name 'round') -and $null -ne $r.round) { $round = [int]$r.round }
        if ($round -gt 0) {
            $reasons.Add(("Stage {0} ({1}) is recorded at round {2}: a round above 0 says a remediation cycle ran, and Stage 7 is where it is recorded." -f $s, $r.name, $round))
        }
        $v = ''
        if (Test-LedgerHasProp -Object $r -Name 'verdict') { $v = "$($r.verdict)" }
        if ($v -and $null -ne $VerdictNames -and @($VerdictNames).Count) {
            $rank = Get-LedgerVerdictRank -Verdict $v -Names $VerdictNames
            if ($rank -gt 0) {
                $reasons.Add(("Stage {0} ({1}) carries verdict '{2}', which is below '{3}': the findings behind it are remediated at Stage 7." -f $s, $r.name, $v, $VerdictNames[0]))
            }
        }
    }
    if ($Latest.ContainsKey('6b')) {
        $r = $Latest['6b']
        if ("$($r.status)" -ne 'n-a') {
            $wo = 0
            if (Test-LedgerHasProp -Object $r -Name 'workOrder') { $wo = Get-LedgerCount -Value $r.workOrder }
            $f = 0
            if ((Test-LedgerHasProp -Object $r -Name 'findings') -and $null -ne $r.findings) { $f = [int]$r.findings }
            if ($wo -gt 0 -or $f -gt 0) {
                $reasons.Add(("Stage 6b ({0}) carries a work order ({1} item(s) in workOrder, {2} finding(s)): every item in it is remediated at Stage 7." -f $r.name, $wo, $f))
            }
        }
    }
    [pscustomobject]@{ Required = ($reasons.Count -gt 0); Reasons = $reasons.ToArray() }
}

function Test-StageLedger {
    <#
      Returns a result object with .Ok and .Problems. Run it in Stage 8, before
      reporting delivery, and with -InProgress at any earlier point: -InProgress
      excludes ONLY the terminal delivery stage, so every other rule is live
      from the first record onward.

      Two rules named in the specification live INSIDE this function and
      nowhere else, because both need the whole ledger at once:
        Assert-LedgerIntegrity - the span and same-second rules (P0-03)
        Assert-Staleness       - no mutation after the last gate (P0-16)
    #>
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [switch] $InProgress,
        [string] $SpineDir
    )

    if (-not $SpineDir) { $SpineDir = Join-Path $BuildDir 'spine' }

    $problems = New-Object System.Collections.Generic.List[string]
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    $reported = New-Object System.Collections.Generic.List[string]
    function Add-LedgerProblem { param([string] $Text) if ($Text -and $seen.Add($Text)) { $problems.Add($Text) } }

    $p = Get-LedgerPath -BuildDir $BuildDir
    if (-not (Test-Path -LiteralPath $p)) {
        return [pscustomobject]@{
            Ok = $false
            Problems = @('No stage ledger exists. There is no record that any review stage ran, so delivery cannot be confirmed.')
            Reported = @()
            Records = @()
            FigureSheet = $null
            TopicStaleness = [ordered]@{}
            Stage7 = $null
            GeneratedNote = 'LEDGER FAIL - no stage-ledger.json exists.'
        }
    }

    $l = Read-LedgerJson -Path $p
    if ($null -eq $l) {
        return [pscustomobject]@{
            Ok = $false
            Problems = @(("The stage ledger at {0} is empty or unreadable. A ledger nothing can read is a ledger nothing can check." -f $p))
            Reported = @(); Records = @(); FigureSheet = $null; TopicStaleness = [ordered]@{}; Stage7 = $null
            GeneratedNote = 'LEDGER FAIL - the ledger could not be read.'
        }
    }
    $recs = @($l.records | Where-Object { $null -ne $_ })
    $latest = Get-LedgerLatestPerStage -Records $recs

    # ---- keys the table does not carry. A record under an unknown key is
    #      enforced by nothing, which is how '7b-ii' outlived its rename.
    foreach ($k in @($latest.Keys | Sort-Object)) {
        if ($null -eq (Get-LedgerStage -Key $k)) {
            $near = Get-LedgerNearestStageKey -Key $k
            $extra = ''
            if ($script:LedgerRenamedKeys.ContainsKey($k)) { $extra = (" It was renamed to '{0}'." -f $script:LedgerRenamedKeys[$k]) }
            Add-LedgerProblem ("The ledger carries a record for stage '{0}', which is not a stage this pipeline has (nearest known key: '{1}').{2} No rule can find it, so nothing it claims is checked." -f $k, $near, $extra)
        }
    }

    # ---- the verdict vocabulary, read from the file that owns it
    $verdictNames = @()
    try { $verdictNames = @(Get-LedgerVerdictNames) }
    catch { Add-LedgerProblem ("The closed verdict vocabulary could not be read: {0}" -f $_.Exception.Message) }

    # ---- Stage 7, conditional
    $stage7 = Get-LedgerStage7Requirement -Latest $latest -VerdictNames $verdictNames

    $required = @(Get-LedgerStageKeys -Flag 'Required')
    if ($InProgress) {
        $terminal = @(Get-LedgerStageKeys -Flag 'Terminal')
        $required = @($required | Where-Object { $terminal -notcontains $_ })
    }
    if ($stage7.Required -and $required -notcontains '7') { $required = @($required) + '7' }

    foreach ($s in $required) {
        if ($latest.ContainsKey($s)) { continue }
        if ($s -eq '7') {
            Add-LedgerProblem ("Stage 7 (remediation and re-render) has no record, and this build's own ledger says it was owed: {0} Stage 7 is conditional - it is required exactly when the records call for it." -f ($stage7.Reasons -join ' '))
        }
        else {
            $row = Get-LedgerStage -Key $s
            Add-LedgerProblem ("Stage {0} ({1}) has no record. It either did not run or was not recorded; either way delivery cannot claim it." -f $s, $row.Title)
        }
    }

    # ---- what every recorded stage says about itself
    foreach ($s in @($latest.Keys | Sort-Object { $i = [array]::IndexOf($script:LedgerOrder, "$_"); if ($i -lt 0) { 99 } else { $i } })) {
        $row = Get-LedgerStage -Key $s
        if ($null -eq $row) { continue }
        $r = $latest[$s]
        $status = "$($r.status)"
        $note = Get-LedgerRecordNote -Record $r

        if ($status -eq 'fail') {
            Add-LedgerProblem ("Stage {0} ({1}) is recorded as FAILED and was never brought to pass." -f $s, $r.name)
        }
        elseif ($status -eq 'skipped') {
            if ($row.Blocking) {
                $n = ''
                if ($note) { $n = " - $note" }
                Add-LedgerProblem ("Stage {0} ({1}) is recorded as SKIPPED and it is a blocking stage{2}" -f $s, $r.name, $n)
            }
            else {
                Add-LedgerProblem ("Stage {0} ({1}) is recorded as SKIPPED. A stage that is in the pipeline is run or it is recorded honestly as not applicable with a reason; 'skipped' does not deliver." -f $s, $r.name)
            }
        }
        elseif ($status -eq 'n-a') {
            if (-not $note) {
                Add-LedgerProblem ("Stage {0} ({1}) is recorded as 'n-a' with no note. A stage that does not apply must say why it does not apply." -f $s, $r.name)
            }
            if (-not $row.Artwork) {
                Add-LedgerProblem ("Stage {0} ({1}) is recorded as 'n-a'. Only the artwork stages ({2}) may be not applicable, and only against a Stage 2 no-go decision: three blocking stages were once recorded 'n-a' plus a note and passed delivery. Run stage {0}, or record the honest status." -f $s, $r.name, ($script:LedgerArtwork -join ', '))
            }
            else {
                #  An artwork n-a is accepted only where Stage 2 recorded the
                #  artwork decision as no-go. The reason lives in the decision,
                #  not in the stage that skipped the work.
                $nogo = @($recs | Where-Object { "$($_.stage)" -ceq '2' -and (Get-LedgerRecordNote -Record $_) -match '(?i)\bno[ -]?go\b' })
                if (-not $nogo.Count) {
                    Add-LedgerProblem ("Stage {0} ({1}) is recorded as 'n-a', but no Stage 2 record in this ledger records the artwork decision as no-go. The artwork stages are not applicable only where the build decided not to generate artwork, and that decision is a Stage 2 record - not a note typed at Stage {0}." -f $s, $r.name)
                }
            }
        }

        $pl = @($r.partial | Where-Object { $null -ne $_ -and "$_".Trim() })
        if ($pl.Count -and -not $note) {
            Add-LedgerProblem ("Stage {0} ({1}) recorded {2} gate rule(s) that checked nothing - {3} - and no note saying why. A partial gate run is a decision, and a decision needs a written reason." -f $s, $r.name, $pl.Count, ($pl -join '; '))
        }
        $cl = @($r.clearancesApplied | Where-Object { $null -ne $_ -and "$_".Trim() })
        if ($cl.Count -and -not $note) {
            Add-LedgerProblem ("Stage {0} ({1}) records {2} clearance(s) applied - {3} - and no note saying why. A dispositioned failure is a pass whose clearances are written down and read; an unexplained clearance is a waiver." -f $s, $r.name, $cl.Count, ($cl -join '; '))
        }
    }

    # ---- the machine evidence, re-derived from disk every time
    $machineView = [ordered]@{}
    foreach ($s in $script:LedgerScripted) {
        $scriptName = Get-LedgerStageScript -Key $s
        $onDisk = $null
        try { $onDisk = Get-StageMachineResult -BuildDir $BuildDir -Stage $s }
        catch { Add-LedgerProblem ("Stage {0}: its results file could not be read: {1}" -f $s, $_.Exception.Message) }
        if (-not $latest.ContainsKey($s)) {
            if ($null -ne $onDisk) { $machineView[$s] = 'results file on disk, no ledger record' }
            continue
        }
        $r = $latest[$s]
        $status = "$($r.status)"
        $claimed = $null
        if (Test-LedgerHasProp -Object $r -Name 'machine') { $claimed = $r.machine }
        $claimedSha = ''
        if ($null -ne $claimed -and $claimed -isnot [string] -and (Test-LedgerHasProp -Object $claimed -Name 'sha256')) { $claimedSha = "$($claimed.sha256)".ToLowerInvariant() }

        if ($null -eq $onDisk) {
            if ($status -eq 'pass') {
                Add-LedgerProblem ("Stage {0} ({1}) is recorded pass, and there is no {0}-results.json in {2} for it to be derived from. {3} writes that file; without it the record is testimony." -f $s, $r.name, $BuildDir, $scriptName)
            }
            $machineView[$s] = ("none - no {0}-results.json" -f $s)
            continue
        }
        $machineView[$s] = ("{0} {1}" -f $onDisk.File, $onDisk.Verdict)

        if (-not $claimedSha) {
            if ($status -eq 'pass') {
                Add-LedgerProblem ("Stage {0} ({1}) is recorded pass and carries no machine block naming the results file it was derived from, while {2} sits in the build. Re-record the stage so the ledger and the file cannot disagree." -f $s, $r.name, $onDisk.File)
            }
        }
        elseif ($claimedSha -ne $onDisk.Sha256) {
            Add-LedgerProblem ("Stage {0} ({1}) was recorded against {2} with sha256 {3}, and that file on disk now hashes to {4}. The evidence changed after the record was written; nothing in the ledger describes the file the build actually holds." -f $s, $r.name, $onDisk.File, $claimedSha, $onDisk.Sha256)
        }
        else {
            $recEnd = Get-LedgerUtc -Record $r
            if ($null -ne $recEnd -and $onDisk.LastWriteUtc -gt $recEnd.AddSeconds(1)) {
                Add-LedgerProblem ("Stage {0} ({1}) was recorded at {2} and {3} was last written at {4} - after the record that claims it. A results file rewritten after its record is not the evidence the record cites." -f $s, $r.name, $recEnd.ToString('u'), $onDisk.File, $onDisk.LastWriteUtc.ToString('u'))
            }
        }

        if ($status -eq 'pass') {
            $claims = @($r.partial | Where-Object { $null -ne $_ -and "$_".Trim() })
            $mf = Get-LedgerMachineFindings -Stage $s -Machine $onDisk -BuildDir $BuildDir -SpineDir $SpineDir -PartialClaims $claims
            foreach ($x in @($mf.Problems)) { Add-LedgerProblem $x }
            foreach ($x in @($mf.Partial)) { if (-not $reported.Contains($x)) { $reported.Add($x) } }
        }
    }

    # ---- Assert-LedgerIntegrity: spans and the same-second rule (P0-03).
    #      It lives here because it needs every record at once.
    $spanRows = New-Object System.Collections.Generic.List[object]
    $idx = 0
    foreach ($r in $recs) {
        $isV2 = ((Test-LedgerHasProp -Object $r -Name 'ledgerVersion') -and $null -ne $r.ledgerVersion)
        $known = $false
        if ((Test-LedgerHasProp -Object $r -Name 'spanKnown') -and $null -ne $r.spanKnown) { $known = [bool]$r.spanKnown }
        $st = $null; $en = $null
        if (Test-LedgerHasProp -Object $r -Name 'started') { $st = ConvertTo-LedgerDateTime -Text "$($r.started)" }
        if (Test-LedgerHasProp -Object $r -Name 'ended')   { $en = ConvertTo-LedgerDateTime -Text "$($r.ended)" }
        if ($null -eq $en) { $en = Get-LedgerUtc -Record $r }
        $spanRows.Add([pscustomobject]@{ Record = $r; Stage = "$($r.stage)"; Name = "$($r.name)"; IsV2 = $isV2; SpanKnown = ($known -and $null -ne $st -and $null -ne $en); Started = $st; Ended = $en; Index = $idx })
        $idx++
    }
    foreach ($row in $spanRows) {
        $stageRow = Get-LedgerStage -Key $row.Stage
        if (-not $row.IsV2) {
            $reported.Add(("Stage {0} ({1}) is a legacy record: it carries an append time and no span, so spanKnown = false. It is reported, never accepted as a span." -f $row.Stage, $row.Name))
            continue
        }
        if (-not $row.SpanKnown) {
            Add-LedgerProblem ("Stage {0} ({1}) was recorded with neither -Started nor -Ended and no results file to derive them from, so spanKnown = false. utc is an append time: on one build 21 of 33 records sat within 0.1 s of their predecessor and four stages were back-filled minutes before delivery. Re-record the stage with its real span." -f $row.Stage, $row.Name)
            continue
        }
        if ($null -ne $stageRow -and $stageRow.Blocking -and $row.Started -eq $row.Ended) {
            Add-LedgerProblem ("Stage {0} ({1}) is a blocking stage whose started equals its ended ({2}). A blocking stage that took no measurable time did not run." -f $row.Stage, $row.Name, $row.Started.ToString('o'))
        }
    }
    $bySecond = @{}
    foreach ($row in $spanRows) {
        if ($null -eq $row.Ended) { continue }
        $k = $row.Ended.ToString('yyyy-MM-ddTHH:mm:ss')
        if (-not $bySecond.ContainsKey($k)) { $bySecond[$k] = New-Object System.Collections.Generic.List[object] }
        $bySecond[$k].Add($row)
    }
    foreach ($k in @($bySecond.Keys | Sort-Object)) {
        #  .ToArray(), not @(...): in PS 5.1 the array subexpression over a
        #  List[object] throws 'Argument types do not match', and the whole
        #  same-second rule then silently checked nothing.
        $group = $bySecond[$k].ToArray()
        if ($group.Count -lt 2) { continue }
        for ($a = 0; $a -lt $group.Count; $a++) {
            for ($b = $a + 1; $b -lt $group.Count; $b++) {
                $x = $group[$a]; $y = $group[$b]
                if ($x.Stage -ceq $y.Stage) { continue }
                if (-not $x.SpanKnown -or -not $y.SpanKnown) {
                    Add-LedgerProblem ("Stages {0} ({1}) and {2} ({3}) both end in the same second ({4}) and at least one of them has no known span. Two different stages cannot be shown to have run one after the other from an append time alone - this is the batch write that makes a ledger a list of intentions. Record each stage as it finishes, with -Started and -Ended." -f $x.Stage, $x.Name, $y.Stage, $y.Name, $k)
                    continue
                }
                $overlap = ($x.Started -lt $y.Ended) -and ($y.Started -lt $x.Ended)
                if ($overlap) {
                    Add-LedgerProblem ("Stages {0} ({1}) and {2} ({3}) end in the same second ({4}) and their spans OVERLAP ({5} to {6} against {7} to {8}). Two stages cannot have been running at once and each be a record of what happened." -f $x.Stage, $x.Name, $y.Stage, $y.Name, $k, $x.Started.ToString('o'), $x.Ended.ToString('o'), $y.Started.ToString('o'), $y.Ended.ToString('o'))
                }
            }
        }
    }

    # ---- Assert-Staleness: no mutation after the last gate (P0-16).
    #      Also here because it needs the newest 4/7c payload plus the spine.
    $judging = $null
    foreach ($s in @('4', '7c')) {
        $m = $null
        try { $m = Get-StageMachineResult -BuildDir $BuildDir -Stage $s } catch { $m = $null }
        if ($null -eq $m) { continue }
        if ($null -eq $judging) { $judging = $m; continue }
        $a = $judging.RanAt; if ($null -eq $a) { $a = $judging.LastWriteUtc }
        $b = $m.RanAt; if ($null -eq $b) { $b = $m.LastWriteUtc }
        if ($b -ge $a) { $judging = $m }
    }
    if ($null -ne $judging) {
        $arts = @($judging.Artefacts)
        if (-not $arts.Count) {
            Add-LedgerProblem ("Delivery staleness: {0} stamps no artefacts[], so nothing can prove the delivered documents were not rewritten after the run that judged them - the deck of one build was rewritten 92 seconds after the last gate. Run-Gates writes {{path, sha256, lastWriteUtc}} per artefact; re-run the stage so the payload carries them." -f $judging.File)
        }
        foreach ($a in $arts) {
            $ap = $a.Path
            if (-not [System.IO.Path]::IsPathRooted($ap)) { $ap = Join-Path $BuildDir $ap }
            if (-not $a.Sha256) {
                Add-LedgerProblem ("Delivery staleness: {0} names artefact {1} with no sha256, so nothing can say whether it has been rewritten since. An unhashed artefact is not read as unchanged." -f $judging.File, $a.Path)
                continue
            }
            if (-not (Test-Path -LiteralPath $ap)) {
                Add-LedgerProblem ("Delivery staleness: {0} judged artefact {1}, which is not on disk at {2}. The build cannot deliver a document the gates judged and the build no longer has." -f $judging.File, $a.Path, $ap)
                continue
            }
            $now = Get-LedgerFileSha256 -Path $ap
            if ($now -ne $a.Sha256) {
                Add-LedgerProblem ("Delivery staleness: {0} was judged by {1} at sha256 {2} and now hashes to {3}. It was rewritten after the last gate that read it; every verdict in that file describes a document this build no longer holds. Re-run the gate set over what is on disk." -f $a.Path, $judging.File, $a.Sha256, $now)
                continue
            }
            $lw = (Get-Item -LiteralPath $ap).LastWriteTimeUtc
            $jw = $judging.RanAt; if ($null -eq $jw) { $jw = $judging.LastWriteUtc }
            if ($lw -gt $jw.AddSeconds(1)) {
                Add-LedgerProblem ("Delivery staleness: {0} was last written at {1}, after {2} ran at {3}, even though its bytes still hash the same. A delivered artefact touched after the run that judged it is re-gated, not explained." -f $a.Path, $lw.ToString('u'), $judging.File, $jw.ToString('u'))
            }
        }
    }
    $band = $null
    try { $band = Get-StageMachineResult -BuildDir $BuildDir -Stage '3c' } catch { $band = $null }
    if ($null -ne $band) {
        if (-not $band.SpineFingerprint) {
            $reported.Add(("Delivery staleness: {0} carries no spineFingerprint, so the spine on disk cannot be held against the band that judged it." -f $band.File))
        }
        else {
            $cur = ''
            try { $cur = Get-SpineFingerprint -BuildDir $BuildDir -SpineDir $SpineDir -Quiet } catch { $cur = '' }
            if (-not $cur) {
                Add-LedgerProblem ("Delivery staleness: {0} is stamped with spine fingerprint {1} and no spine at {2} can be fingerprinted now." -f $band.File, $band.SpineFingerprint, $SpineDir)
            }
            else {
                $state = Test-GateFingerprintVersion -Stamp $band.SpineFingerprint -Current $cur
                if ($state -eq 'spine-moved') {
                    Add-LedgerProblem ("Delivery staleness: the spine was {0} when {1} judged it and is {2} now. Three spine files were rewritten eleven minutes after the 3c stamp on one build; re-run the band." -f $band.SpineFingerprint, $band.File, $cur)
                }
                elseif ($state -eq 'version-changed') {
                    Add-LedgerProblem ("Delivery staleness: {0} carries a spine fingerprint in a different format ('{1}' against '{2}'), so nothing can be said about whether the spine moved. Re-run the band." -f $band.File, $band.SpineFingerprint, $cur)
                }
            }
        }
    }

    # ---- staleness, in two classes. See the file header.
    $renderTimes = @()
    foreach ($s in $script:LedgerRenders) {
        if ($latest.ContainsKey($s)) {
            $t = Get-LedgerUtc -Record $latest[$s]
            if ($null -ne $t) { $renderTimes += $t }
        }
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
                $t = Get-LedgerUtc -Record $latest[$s]
                if ($null -ne $t -and $t -le $lastRender) {
                    Add-LedgerProblem ("Stage {0} ({1}) ran at {2} and the artefacts were re-rendered at {3}. That verdict does not postdate the render - a record written in the same second as the mutation it must follow cannot claim to have followed it. Re-run it against the current documents." -f $s, $latest[$s].name, $t.ToString('u'), $lastRender.ToString('u'))
                }
                continue
            }

            # A scoped record is judged per topic against the render delta on
            # disk. Every record of the stage takes part, newest first.
            if ($null -eq $deltaSet) { $deltaSet = Get-RenderDeltaSet -BuildDir $BuildDir }
            $v = Test-LedgerStageTopics -Stage $s -Records @($recs | Where-Object { "$($_.stage)" -ceq $s }) -DeltaSet $deltaSet -LastRender $lastRender
            $topicStaleness[$s] = $v
            if ($v.Problem) { Add-LedgerProblem $v.Problem }
        }
    }

    $placeTimes = @()
    foreach ($s in $script:LedgerPlacements) {
        if ($latest.ContainsKey($s) -and "$($latest[$s].status)" -ne 'n-a') {
            $t = Get-LedgerUtc -Record $latest[$s]
            if ($null -ne $t) { $placeTimes += $t }
        }
    }
    if ($placeTimes.Count) {
        $lastPlace = ($placeTimes | Sort-Object -Descending)[0]
        foreach ($s in $script:LedgerStaleAfterPlacement) {
            if (-not $latest.ContainsKey($s)) { continue }
            if ("$($latest[$s].status)" -eq 'n-a') { continue }
            $t = Get-LedgerUtc -Record $latest[$s]
            if ($null -ne $t -and $t -lt $lastPlace) {
                Add-LedgerProblem ("Stage {0} ({1}) ran at {2} but artwork was placed at {3}. Placement is the last mutation of both artefacts and it is followed by the WHOLE gate set, never a subset - re-run it." -f $s, $latest[$s].name, $t.ToString('u'), $lastPlace.ToString('u'))
            }
        }

        # And the half of the rule that cannot be met by re-running a script: a
        # human-class verdict issued against a document that actually has
        # figures in it. Stage 7d is that read, scoped to what placement changed.
        $read = @($script:LedgerPostPlacementRead | Where-Object {
                     $latest.ContainsKey($_) -and "$($latest[$_].status)" -ne 'n-a' -and
                     $null -ne (Get-LedgerUtc -Record $latest[$_]) -and
                     (Get-LedgerUtc -Record $latest[$_]) -ge $lastPlace })
        if (-not $read.Count) {
            Add-LedgerProblem ("No Stage 6-class read postdates the newest placement at {0}. Delivery requires a Stage 6 re-audit or the Stage 7d confirming read AFTER placement - no build ships on a verdict issued against a document that had no figures in it." -f $lastPlace.ToString('u'))
        }
    }

    # Stages 6 and 7d must each carry an actual verdict, and neither may be a
    # failing one. An audit without a stated judgement is not an audit, and a
    # confirming read that confirms nothing in particular is not a confirmation.
    foreach ($s in $script:LedgerVerdict) {
        if (-not $latest.ContainsKey($s)) { continue }
        $a = $latest[$s]
        if ("$($a.status)" -eq 'n-a') { continue }
        $v = ''
        if (Test-LedgerHasProp -Object $a -Name 'verdict') { $v = "$($a.verdict)".Trim() }
        if (-not $v) {
            Add-LedgerProblem ("Stage {0} ({1}) ran but recorded no verdict. A judgement stage that states no judgement is not a judgement stage." -f $s, $a.name)
            continue
        }
        if (-not $verdictNames.Count) { continue }
        $rank = Get-LedgerVerdictRank -Verdict $v -Names $verdictNames
        if ($rank -lt 0) {
            Add-LedgerProblem ("Stage {0} verdict is '{1}', which names none of the closed vocabulary ({2}). A verdict outside the vocabulary is read by no rule - not as a pass, and not as a failure. Record the verdict the audit actually issued." -f $s, $v, ($verdictNames -join ' | '))
        }
        elseif ($rank -gt 0) {
            Add-LedgerProblem ("Stage {0} verdict is '{1}' - below '{2}' in the closed vocabulary. Remediate and re-audit before delivery." -f $s, $v, $verdictNames[0])
        }
    }

    # ---- the figure sheet every later review reads must still describe this spine
    $fs = Test-FigureSheetCurrent -BuildDir $BuildDir -SpineDir $SpineDir -Records $recs
    foreach ($x in $fs.Problems) { Add-LedgerProblem $x }

    $ordered = @($latest.Values | Sort-Object {
                    $i = [array]::IndexOf($script:LedgerOrder, "$($_.stage)")
                    if ($i -lt 0) { 99 } else { $i } })

    $note = ''
    if ($problems.Count -eq 0) {
        $note = ("LEDGER PASS - {0} stage(s) recorded, every blocking stage ran against the current documents; 0 problem(s)." -f $ordered.Count)
    }
    else {
        $note = ("LEDGER FAIL - {0} problem(s) over {1} recorded stage(s): {2}" -f $problems.Count, $ordered.Count, (($problems | ForEach-Object { ($_ -split '\.\s')[0] }) -join '; '))
    }

    [pscustomobject]@{
        Ok             = ($problems.Count -eq 0)
        Problems       = $problems.ToArray()
        Reported       = $reported.ToArray()
        FigureSheet    = $fs
        TopicStaleness = $topicStaleness
        Machine        = $machineView
        Stage7         = $stage7
        Required       = @($required)
        InProgress     = [bool]$InProgress
        GeneratedNote  = $note
        Records        = $ordered
    }
}

function Write-StageLedgerReport {
    param([Parameter(Mandatory, ValueFromPipeline)] $Result)
    process {
        Write-Host ''
        Write-Host 'STAGE LEDGER' -ForegroundColor Cyan
        if ($Result.PSObject.Properties.Name -contains 'InProgress' -and $Result.InProgress) {
            Write-Host '  -InProgress: every rule is live except the terminal delivery stage.' -ForegroundColor DarkGray
        }
        foreach ($r in $Result.Records) {
            $col = switch ("$($r.status)") {
                'pass'    { 'Green' }
                'n-a'     { 'DarkGray' }
                'skipped' { 'Yellow' }
                default   { 'Red' }
            }
            $extra = ''
            if ($null -ne $r.findings -and [int]$r.findings -gt 0) { $extra = " ($($r.findings) finding(s))" }
            if ((Test-LedgerHasProp -Object $r -Name 'verdict') -and $r.verdict) { $extra += " [$($r.verdict)]" }
            if ((Test-LedgerHasProp -Object $r -Name 'durationSeconds') -and $null -ne $r.durationSeconds) { $extra += (" {0}s" -f $r.durationSeconds) }
            elseif ((Test-LedgerHasProp -Object $r -Name 'spanKnown') -and -not $r.spanKnown) { $extra += ' (no span)' }
            if (Test-LedgerRecordScoped -Record $r) {
                $scope = if ($r.topics -is [string]) { "$($r.topics)" } else { (@($r.topics) | ForEach-Object { "$_" }) -join ',' }
                $extra += (" {{topics {0} @ delta {1}}}" -f $scope, "$($r.deltaSha)".Substring(0, [Math]::Min(8, "$($r.deltaSha)".Length)))
            }
            Write-Host ("  {0,-6} {1,-34} {2,-8}{3}" -f $r.stage, $r.name, $r.status, $extra) -ForegroundColor $col
            if ((Test-LedgerHasProp -Object $r -Name 'machine') -and $null -ne $r.machine -and $r.machine -isnot [string]) {
                Write-Host ("         machine: {0} sha256 {1} verdict {2} fingerprint {3}" -f $r.machine.file, "$($r.machine.sha256)".Substring(0, [Math]::Min(12, "$($r.machine.sha256)".Length)), $r.machine.verdict, $r.machine.fingerprint) -ForegroundColor DarkGray
            }
            #  A gate rule that did not run is printed here every time the
            #  ledger is printed. It is the only place a reader of the build
            #  will see it after the gate's own output has scrolled away.
            foreach ($x in (@($r.partial) | Where-Object { $_ })) {
                Write-Host ("         PARTIAL: {0}" -f $x) -ForegroundColor Magenta
            }
            foreach ($x in (@($r.clearancesApplied) | Where-Object { $_ })) {
                Write-Host ("         CLEARANCE APPLIED: {0}" -f $x) -ForegroundColor Magenta
            }
        }
        if ($Result.PSObject.Properties.Name -contains 'Stage7' -and $null -ne $Result.Stage7) {
            if ($Result.Stage7.Required) {
                Write-Host '  stage 7 is REQUIRED by this build (conditional rule):' -ForegroundColor Yellow
                foreach ($x in $Result.Stage7.Reasons) { Write-Host ("    - {0}" -f $x) -ForegroundColor Yellow }
            }
            else {
                Write-Host '  stage 7 is not required: no record calls for a remediation round.' -ForegroundColor DarkGray
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
            Write-Host ("  figure sheet current: BAND-VERDICT {0} against spine {1}" -f $Result.FigureSheet.BandVerdict, $Result.FigureSheet.Expected) -ForegroundColor DarkGray
        }
        foreach ($x in @($Result.Reported)) { Write-Host ("  ! {0}" -f $x) -ForegroundColor Yellow }
        if ($Result.Ok) {
            Write-Host 'LEDGER PASS - every blocking stage ran against the current documents.' -ForegroundColor Green
        } else {
            Write-Host ''
            foreach ($x in $Result.Problems) { Write-Host "  X $x" -ForegroundColor Red }
            Write-Host ("LEDGER FAIL - {0} problem(s)." -f $Result.Problems.Count) -ForegroundColor Red
        }
    }
}


# ---------------------------------------------------------------------------
# SELF-TEST. Every rule above has a PLANT here and a clean control beside it:
# a self-test that plants nothing proves nothing, and this file's whole
# purpose is to refuse a record that the evidence contradicts.
# ---------------------------------------------------------------------------

function Invoke-StageLedgerSelfTest {
    $st = [pscustomobject]@{ Pass = 0; Fail = 0 }
    function Ok  { param([string] $m) $st.Pass++; Write-Host ("  ok   {0}" -f $m) -ForegroundColor Green }
    function Bad { param([string] $m) $st.Fail++; Write-Host ("  FAIL {0}" -f $m) -ForegroundColor Red }
    function Check { param([bool] $cond, [string] $m) if ($cond) { Ok $m } else { Bad $m } }
    function Throws {
        <# Runs a script block and returns the message it threw, or ''. #>
        param([scriptblock] $Body)
        try { & $Body | Out-Null; return '' } catch { return "$($_.Exception.Message)" }
    }
    function Flat {
        <# One string from a problem list. Out-String -Width 4096 elsewhere; here the list is already strings. #>
        param($Items)
        return ((@($Items) | ForEach-Object { "$_" }) -join ' || ')
    }

    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("ledger-selftest-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    $utf8 = New-Object System.Text.UTF8Encoding($true)

    function Write-Text {
        param([string] $Path, [string] $Text, $Stamp)
        $t = $Text -replace "`r?`n", "`r`n"
        [System.IO.File]::WriteAllText($Path, $t, $utf8)
        if ($null -ne $Stamp) { (Get-Item -LiteralPath $Path).LastWriteTimeUtc = $Stamp }
    }
    function Write-Json {
        param([string] $Path, $Body, $Stamp)
        Write-Text -Path $Path -Text ($Body | ConvertTo-Json -Depth 100) -Stamp $Stamp
    }

    function New-LedgerFixtureBuild {
        <#
          A whole honest build on disk: a spine, a figure sheet the band cut, a
          stamped extract, the five results files the runners write, the two
          delivered artefacts they judged, and a ledger with every required
          stage recorded with a real span. Every plant below starts from this.
        #>
        param([Parameter(Mandatory)][string] $Name, [switch] $NoLedger, [string[]] $Omit = @())
        $b = Join-Path $root $Name
        New-Item -ItemType Directory -Force -Path (Join-Path $b 'spine') | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $b 'out') | Out-Null

        #  the spine
        Write-Json -Path (Join-Path $b 'spine\t1.json') -Body ([pscustomobject]@{
            topic = 1; title = 'Topic 1'
            visuals = @([pscustomobject]@{ slot = '1.1.1'; kind = 'image'; caption = 'A caption'; alt = 'Alt text.' })
        })
        Write-Json -Path (Join-Path $b 'spine\t2.json') -Body ([pscustomobject]@{
            topic = 2; title = 'Topic 2'
            visuals = @([pscustomobject]@{ slot = '2.1.1'; kind = 'image'; caption = 'Another caption'; alt = 'More alt text.' })
        })
        #  the gate inputs Run-Gates stamps
        Write-Json -Path (Join-Path $b 'figures.json') -Body ([pscustomobject]@{ figures = @() })
        Write-Json -Path (Join-Path $b 'contract.json') -Body ([pscustomobject]@{ unit = 'TEST001'; topics = @() })
        Write-Json -Path (Join-Path $b 'withhold-register.json') -Body ([pscustomobject]@{ entries = @() })

        $fp = Get-SpineFingerprint -BuildDir $b -Quiet

        #  the spans: one every ten minutes, five minutes long, so no two
        #  stages end in the same second and none of them overlaps.
        $base = (Get-Date).ToUniversalTime().AddHours(-8)
        $spans = @{}
        $i = 0
        foreach ($k in $script:LedgerOrder) {
            $s = $base.AddMinutes(10 * $i)
            $spans[$k] = [pscustomobject]@{ Started = $s; Ended = $s.AddMinutes(5) }
            $i++
        }

        #  the delivered artefacts, written before the run that judges them
        $guide = Join-Path $b 'out\guide.docx'
        $deck  = Join-Path $b 'out\deck.pptx'
        Write-Text -Path $guide -Text 'guide bytes' -Stamp $spans['7c'].Started.AddMinutes(-2)
        Write-Text -Path $deck  -Text 'deck bytes'  -Stamp $spans['7c'].Started.AddMinutes(-2)

        #  the figure sheet the band cuts after the join. New-FigureSheet
        #  stamps these three lines; the self-test writes them because a sheet
        #  is an INPUT to the rules under test here.
        $sheetText = @"
FIGURE SHEET - every planned visual on the spine, as plain text
SPINE-FINGERPRINT: $fp
BAND-VERDICT: PASS
BAND-RESULTS-SHA256: 0000000000000000000000000000000000000000000000000000000000000000
BAND-RAN-AT: $($spans['3c'].Ended.ToString('o'))
SLOTS: 2

-------------------------------------------------------------------
SLOT 1.1.1  image
CAPTION: A caption
ALT: Alt text.
"@
        Write-Text -Path (Join-Path $b 'figure-sheet.txt') -Text $sheetText -Stamp $spans['3c'].Ended

        #  the rendered extracts, stamped by Get-DocText
        Write-Text -Path (Join-Path $b 'guide_gate.txt') -Text "FIGURES: 2 placed drawings, 0 unresolved artwork prompt blocks`nCHANNELS: 1 tables, 0 slides, 2 captions, 2 alt texts, 0 speaker notes`nSOURCE: out\guide.docx  SHA256: 00-11  EXTRACTED: $($spans['7c'].Ended.ToString('o'))`n`nGuide prose." -Stamp $spans['7c'].Ended
        Write-Text -Path (Join-Path $b 'deck_gate.txt')  -Text "FIGURES: 2 placed drawings, 0 unresolved artwork prompt blocks`nCHANNELS: 0 tables, 9 slides, 2 captions, 2 alt texts, 9 speaker notes`nSOURCE: out\deck.pptx  SHA256: 00-22  EXTRACTED: $($spans['7c'].Ended.ToString('o'))`n`nDeck prose." -Stamp $spans['7c'].Ended

        #  the results files, in the two shapes the runners write
        foreach ($s in @('0', '1', '2', '3c')) {
            Write-Json -Path (Join-Path $b ("{0}-results.json" -f $s)) -Stamp $spans[$s].Ended -Body ([pscustomobject]@{
                runner = 'Run-SpineGates'; stage = $s
                startedAt = $spans[$s].Started.ToString('o'); ranAt = $spans[$s].Ended.ToString('o')
                spineFingerprint = $fp; partial = $false
                wallClockSeconds = 300
                gates = @(
                    [pscustomobject]@{ name = 'Test-Spine';         verdict = 'PASS'; exitCode = 0; seconds = 4; ranAt = $spans[$s].Ended.ToString('o'); arms = @() },
                    [pscustomobject]@{ name = 'Assert-SpineCounts'; verdict = 'PASS'; exitCode = 0; seconds = 3; ranAt = $spans[$s].Ended.ToString('o'); arms = @() }
                )
                failed = @(); defective = @(); verdict = 'PASS'; exitCode = 0
            })
        }
        $inputs = [pscustomobject]@{
            'figures.json'            = (Get-LedgerFileSha256 -Path (Join-Path $b 'figures.json'))
            'contract.json'           = (Get-LedgerFileSha256 -Path (Join-Path $b 'contract.json'))
            'withhold-register.json'  = (Get-LedgerFileSha256 -Path (Join-Path $b 'withhold-register.json'))
        }
        foreach ($s in @('4', '7c')) {
            Write-Json -Path (Join-Path $b ("{0}-results.json" -f $s)) -Stamp $spans[$s].Ended -Body ([pscustomobject]@{
                stage = $s; afterArtwork = ($s -eq '7c')
                startedAt = $spans[$s].Started.ToString('o'); ranAt = $spans[$s].Ended.ToString('o')
                spineFingerprint = $fp; inputs = $inputs; partial = @()
                wallClockSeconds = 300
                artefacts = @(
                    [pscustomobject]@{ path = 'out\guide.docx'; sha256 = (Get-LedgerFileSha256 -Path $guide); lastWriteUtc = (Get-Item -LiteralPath $guide).LastWriteTimeUtc.ToString('o') },
                    [pscustomobject]@{ path = 'out\deck.pptx';  sha256 = (Get-LedgerFileSha256 -Path $deck);  lastWriteUtc = (Get-Item -LiteralPath $deck).LastWriteTimeUtc.ToString('o') }
                )
                gates = @(
                    [pscustomobject]@{ name = 'Check-Figures';   verdict = 'pass'; exitCode = 0; seconds = 5; startedAt = $spans[$s].Started.ToString('o'); ranAt = $spans[$s].Ended.ToString('o'); arms = @() },
                    [pscustomobject]@{ name = 'Test-GuideRules'; verdict = 'pass'; exitCode = 0; seconds = 6; startedAt = $spans[$s].Started.ToString('o'); ranAt = $spans[$s].Ended.ToString('o'); arms = @() }
                )
                verdict = 'pass'; exitCode = 0
            })
        }

        if ($NoLedger) { return [pscustomobject]@{ Dir = $b; Fingerprint = $fp; Spans = $spans } }

        New-StageLedger -BuildDir $b -Unit 'TEST001' | Out-Null
        foreach ($k in @(Get-LedgerStageKeys -Flag 'Required')) {
            if ($Omit -contains $k) { continue }
            $row = Get-LedgerStage -Key $k
            $callArgs = @{
                BuildDir = $b; Stage = $k; Name = $row.Title; Status = 'pass'
                Started = $spans[$k].Started.ToString('o'); Ended = $spans[$k].Ended.ToString('o')
            }
            if ($row.Verdict) { $callArgs['Verdict'] = 'Fully Compliant' }
            Add-StageRecord @callArgs
        }
        return [pscustomobject]@{ Dir = $b; Fingerprint = $fp; Spans = $spans }
    }

    function Add-LateRecord {
        <# One more record for a stage, after everything already in the ledger, with a real span. #>
        param([Parameter(Mandatory)]$Fx, [Parameter(Mandatory)][string] $Stage, [int] $Offset = 1, [hashtable] $Extra = @{})
        $s = $Fx.Spans['8'].Ended.AddMinutes(10 * $Offset)
        $a = @{ BuildDir = $Fx.Dir; Stage = $Stage; Name = ("late {0}" -f $Stage); Started = $s.ToString('o'); Ended = $s.AddMinutes(4).ToString('o') }
        foreach ($k in $Extra.Keys) { $a[$k] = $Extra[$k] }
        Add-StageRecord @a
    }

    Write-Host ''
    Write-Host 'STAGE-LEDGER SELF-TEST' -ForegroundColor Cyan

    # -- 0. the table and its derived views -----------------------------------
    Write-Host '  -- the stage table' -ForegroundColor DarkGray
    Check ($script:LedgerRequired -notcontains '7') 'stage 7 is not in the unconditional required set (its omission is deliberate)'
    Check ($script:LedgerBlocking -contains '0' -and $script:LedgerBlocking -contains '1' -and $script:LedgerBlocking -contains '2' -and $script:LedgerBlocking -contains '3b' -and $script:LedgerBlocking -contains '8') 'blocking now includes 0, 1, 2, 3b and 8'
    Check ($script:LedgerOrder -contains '7b' -and $script:LedgerOrder -contains '7b-i' -and $script:LedgerOrder -notcontains '7b-ii') '7b is placement, 7b-i is generate + review, and 7b-ii is gone'
    Check ((Get-LedgerStageScript -Key '3c') -eq 'Run-SpineGates.ps1' -and (Get-LedgerStageScript -Key '7c') -eq 'Run-Gates.ps1' -and (Get-LedgerStageScript -Key '0') -eq 'Invoke-Stage0.ps1') 'the Script column names the results producer for 0, 3c and 7c'
    Check (@($script:LedgerStages).Count -eq @($script:LedgerOrder).Count -and @($script:LedgerOrder | Sort-Object -Unique).Count -eq @($script:LedgerOrder).Count) 'every table key is unique'

    $vn = @()
    $vnErr = Throws { Get-LedgerVerdictNames }
    if (-not $vnErr) { $vn = @(Get-LedgerVerdictNames) }
    Check ($vn.Count -ge 2 -and $vn[0] -match '(?i)compliant') ("the verdict vocabulary is read from Merge-AuditFindings.ps1 by AST: " + ($vn -join ' | '))
    Check ((Get-LedgerVerdictRank -Verdict 'delivery set Fully Compliant (guide Fully Compliant; deck Partially Compliant)' -Names $vn) -eq 1) 'a composite verdict ranks at its WORST named verdict, not its first'
    Check ((Get-LedgerVerdictRank -Verdict 'Not Complaint' -Names $vn) -lt 0) 'a verdict outside the vocabulary ranks -1 and is never read as a pass'

    # -- 1. the key vocabulary ------------------------------------------------
    Write-Host '  -- stage keys' -ForegroundColor DarkGray
    $fx0 = New-LedgerFixtureBuild -Name 'keys'
    $m = Throws { Add-StageRecord -BuildDir $fx0.Dir -Stage '7b-ii' -Name 'placement' -Status pass -Started ((Get-Date).ToUniversalTime().ToString('o')) -Ended ((Get-Date).ToUniversalTime().AddMinutes(1).ToString('o')) }
    Check ($m -match "7b-ii" -and $m -match "'7b'") ("PLANT -Stage '7b-ii' is refused naming '7b': " + $m)
    $m = Throws { Add-StageRecord -BuildDir $fx0.Dir -Stage '4d' -Name 'nonsense' -Status pass }
    Check ($m -match 'Unknown stage key' -and $m -match "Nearest known key") ("PLANT an unknown key is refused naming the nearest: " + $m)

    # -- 2. the clean control -------------------------------------------------
    Write-Host '  -- the clean control' -ForegroundColor DarkGray
    $clean = New-LedgerFixtureBuild -Name 'clean'
    $r = Test-StageLedger -BuildDir $clean.Dir
    Check ($r.Ok) ("CONTROL a complete honest build passes: " + (Flat $r.Problems))
    Check ($r.FigureSheet.Stamped -like 'v2:*' -and $r.FigureSheet.BandVerdict -eq 'PASS') ("CONTROL the sheet's v2 fingerprint stamp is read, not reported as absent: " + $r.FigureSheet.Stamped)
    Check (-not $r.Stage7.Required) 'CONTROL stage 7 is not required by a clean build'
    Check ($r.GeneratedNote -match '^LEDGER PASS') ("CONTROL the Stage 8 note is generated: " + $r.GeneratedNote)

    # -- 3. n-a, skipped, fail ------------------------------------------------
    Write-Host '  -- n-a, skipped and fail' -ForegroundColor DarkGray
    $fx = New-LedgerFixtureBuild -Name 'na3c'
    Add-LateRecord -Fx $fx -Stage '3c' -Extra @{ Status = 'n-a'; Note = 'the spine band was covered by the 4/7c run, so it does not apply here' }
    $r = Test-StageLedger -BuildDir $fx.Dir
    $hit = @($r.Problems | Where-Object { $_ -match "Stage 3c" -and $_ -match "'n-a'" })
    Check ($hit.Count -ge 1) ("PLANT 3c recorded n-a WITH a note is still one named problem: " + (Flat $hit))

    $fx = New-LedgerFixtureBuild -Name 'skip1'
    Add-LateRecord -Fx $fx -Stage '1' -Extra @{ Status = 'skipped'; Note = 'the corpus was carried over from the last build' }
    $r = Test-StageLedger -BuildDir $fx.Dir
    $hit = @($r.Problems | Where-Object { $_ -match 'Stage 1 ' -and $_ -match 'SKIPPED' -and $_ -match 'blocking' })
    Check ($hit.Count -ge 1) ("PLANT stage 1 skipped is a named problem: " + (Flat $hit))

    $fx = New-LedgerFixtureBuild -Name 'fail7'
    Add-LateRecord -Fx $fx -Stage '7' -Extra @{ Status = 'fail'; Note = 'the remediation round did not close' }
    $r = Test-StageLedger -BuildDir $fx.Dir
    $hit = @($r.Problems | Where-Object { $_ -match 'Stage 7 ' -and $_ -match 'FAILED' })
    Check ($hit.Count -ge 1) ("PLANT stage 7 recorded fail is a named problem even though 7 is conditional: " + (Flat $hit))

    #  a round-1 n-a superseded by a later pass is clean - the rule reads the
    #  newest record of the stage, not every record of it.
    $fx = New-LedgerFixtureBuild -Name 'superseded'
    Add-LateRecord -Fx $fx -Stage '4c' -Offset 1 -Extra @{ Status = 'n-a'; Note = 'brand not proved this round'; Round = 1 }
    Add-LateRecord -Fx $fx -Stage '4c' -Offset 2 -Extra @{ Status = 'pass'; Round = 2 }
    $r = Test-StageLedger -BuildDir $fx.Dir
    Check (@($r.Problems | Where-Object { $_ -match 'Stage 4c' }).Count -eq 0) ("CONTROL a round-1 n-a superseded by a round-2 pass is clean: " + (Flat @($r.Problems | Where-Object { $_ -match '4c' })))

    # -- 4. verdicts ----------------------------------------------------------
    Write-Host '  -- verdicts' -ForegroundColor DarkGray
    $fx = New-LedgerFixtureBuild -Name 'verdict'
    Add-LateRecord -Fx $fx -Stage '6' -Extra @{ Status = 'pass'; Verdict = 'Not Complaint' }
    $r = Test-StageLedger -BuildDir $fx.Dir
    $hit = @($r.Problems | Where-Object { $_ -match "Not Complaint" })
    Check ($hit.Count -ge 1) ("PLANT verdict 'Not Complaint' is a named problem: " + (Flat $hit))

    $fx = New-LedgerFixtureBuild -Name 'verdict2'
    Add-LateRecord -Fx $fx -Stage '6' -Extra @{ Status = 'pass'; Verdict = 'Partially Compliant'; Round = 2 }
    $r = Test-StageLedger -BuildDir $fx.Dir
    Check ($r.Stage7.Required -and (@($r.Problems | Where-Object { $_ -match 'Stage 7' -and $_ -match 'no record' }).Count -ge 1)) ("PLANT a non-best verdict at round 2 makes stage 7 required and its absence a named problem: " + (Flat @($r.Problems | Where-Object { $_ -match 'Stage 7' })))

    # -- 5. spans and the same-second rule ------------------------------------
    Write-Host '  -- spans and the same-second rule' -ForegroundColor DarkGray
    $fx = New-LedgerFixtureBuild -Name 'spans' -NoLedger
    New-StageLedger -BuildDir $fx.Dir -Unit 'TEST001' | Out-Null
    $stampAll = (Get-Date).ToUniversalTime().ToString('o')
    foreach ($k in @('3', '3b', '3d')) {
        #  the batch write: three different stages, one loop, one timestamp,
        #  and no -Started. This is what 21 of 33 records on the reference
        #  build looked like.
        Add-StageRecord -BuildDir $fx.Dir -Stage $k -Name ("stage {0}" -f $k) -Status pass -Ended $stampAll
    }
    $r = Test-StageLedger -BuildDir $fx.Dir -InProgress
    $coll = @($r.Problems | Where-Object { $_ -match 'same second' })
    $nospan = @($r.Problems | Where-Object { $_ -match 'spanKnown = false' })
    Check ($coll.Count -ge 1 -and ((Flat $coll) -match 'Stages 3 ' -or (Flat $coll) -match 'Stages 3b')) ("PLANT three records in one loop without -Started collide by name: " + (Flat $coll))
    Check ($nospan.Count -ge 3) ("PLANT each of the three carries no known span, by name: " + $nospan.Count + ' named')

    $fx = New-LedgerFixtureBuild -Name 'spans2' -NoLedger
    New-StageLedger -BuildDir $fx.Dir -Unit 'TEST001' | Out-Null
    $t0 = (Get-Date).ToUniversalTime().AddHours(-3)
    $n = 0
    foreach ($k in @('3', '3b', '3d')) {
        $s = $t0.AddMinutes(20 * $n)
        Add-StageRecord -BuildDir $fx.Dir -Stage $k -Name ("stage {0}" -f $k) -Status pass -Started $s.ToString('o') -Ended $s.AddMinutes(9).ToString('o')
        $n++
    }
    $r = Test-StageLedger -BuildDir $fx.Dir -InProgress
    Check (@($r.Problems | Where-Object { $_ -match 'same second' -or $_ -match 'spanKnown = false' }).Count -eq 0) ("CONTROL three records with distinct, non-overlapping spans raise no span problem: " + (Flat @($r.Problems | Where-Object { $_ -match 'span' })))

    $fx = New-LedgerFixtureBuild -Name 'zerospan' -NoLedger
    New-StageLedger -BuildDir $fx.Dir -Unit 'TEST001' | Out-Null
    $z = (Get-Date).ToUniversalTime().AddHours(-2).ToString('o')
    $m = Throws { Add-StageRecord -BuildDir $fx.Dir -Stage '3b' -Name 'visual planning' -Status pass -Started $z -Ended $z }
    Check ($m -match 'started equal to ended' -and $m -match 'Stage 3b') ("PLANT a blocking stage with started == ended is refused at the point of writing: " + $m)

    # -- 6. the machine record ------------------------------------------------
    Write-Host '  -- the record is derived from the results file' -ForegroundColor DarkGray
    $fx = New-LedgerFixtureBuild -Name 'mach-fail' -NoLedger
    New-StageLedger -BuildDir $fx.Dir -Unit 'TEST001' | Out-Null
    Write-Json -Path (Join-Path $fx.Dir '3c-results.json') -Stamp $fx.Spans['3c'].Ended -Body ([pscustomobject]@{
        runner = 'Run-SpineGates'; stage = '3c'
        startedAt = $fx.Spans['3c'].Started.ToString('o'); ranAt = $fx.Spans['3c'].Ended.ToString('o')
        spineFingerprint = $fx.Fingerprint; partial = $false; wallClockSeconds = 300
        gates = @(
            [pscustomobject]@{ name = 'Test-Spine';         verdict = 'PASS'; exitCode = 0; seconds = 4 },
            [pscustomobject]@{ name = 'Assert-SpineCounts'; verdict = 'FAIL'; exitCode = 1; seconds = 3 }
        )
        failed = @('Assert-SpineCounts'); verdict = 'FAIL'; exitCode = 1
    })
    $m = Throws { Add-StageRecord -BuildDir $fx.Dir -Stage '3c' -Name 'spine gate band' -Status pass -Started $fx.Spans['3c'].Started.ToString('o') -Ended $fx.Spans['3c'].Ended.ToString('o') }
    Check ($m -match 'Assert-SpineCounts' -and $m -match '3c-results\.json') ("PLANT -Status pass over a 3c-results FAIL is refused naming the gate and the file: " + $m)

    $m2 = Throws { Add-StageRecord -BuildDir $fx.Dir -Stage '3c' -Name 'spine gate band' -Status fail -Findings 1 -Partial @('Assert-SpineCounts could not read the register') -Note 'recorded honestly' -Started $fx.Spans['3c'].Started.ToString('o') -Ended $fx.Spans['3c'].Ended.ToString('o') }
    Check ($m2 -match 'Assert-SpineCounts' -and $m2 -match 'lists as FAIL') ("PLANT a -Partial entry naming a FAIL member is refused whatever the status: " + $m2)

    $m3 = Throws { Add-StageRecord -BuildDir $fx.Dir -Stage '3c' -Name 'spine gate band' -Status fail -Findings 1 -Note 'the band failed and it is recorded as failed' -Started $fx.Spans['3c'].Started.ToString('o') -Ended $fx.Spans['3c'].Ended.ToString('o') }
    Check ($m3 -eq '') ("CONTROL the same band recorded honestly as fail is accepted: " + $m3)

    #  -- the GATE-DEFECT class (P1-14): a broken gate is not a content failure
    #     and may not be filed as a partial
    Write-Host '  -- GATE-DEFECT is neither a content failure nor a partial' -ForegroundColor DarkGray
    $fxD = New-LedgerFixtureBuild -Name 'mach-gatedefect' -NoLedger
    New-StageLedger -BuildDir $fxD.Dir -Unit 'TEST001' | Out-Null
    $defBody = [pscustomobject]@{
        runner = 'Run-SpineGates'; stage = '3c'
        startedAt = $fxD.Spans['3c'].Started.ToString('o'); ranAt = $fxD.Spans['3c'].Ended.ToString('o')
        spineFingerprint = $fxD.Fingerprint; partial = $false; wallClockSeconds = 300
        gates = @(
            [pscustomobject]@{ name = 'Test-Spine';         verdict = 'PASS';        exitCode = 0; seconds = 4 },
            [pscustomobject]@{ name = 'Assert-SpineCounts'; verdict = 'GATE-DEFECT'; exitCode = 4; seconds = 3; reason = "exit 4: the quote 'Observation 1 item' could not be re-found at a token boundary in uat.txt" }
        )
        failed = @(); defective = @('Assert-SpineCounts'); verdict = 'GATE-DEFECT'; exitCode = 1
    }
    Write-Json -Path (Join-Path $fxD.Dir '3c-results.json') -Stamp $fxD.Spans['3c'].Ended -Body $defBody
    $mrD = Get-StageMachineResult -BuildDir $fxD.Dir -Stage '3c'
    Check ((@($mrD.DefectiveGates) -contains 'Assert-SpineCounts') -and (@($mrD.FailedGates).Count -eq 0) -and (@($mrD.UnrunGates) -notcontains 'Assert-SpineCounts') -and (@($mrD.UnknownGates).Count -eq 0)) ("the reader puts a GATE-DEFECT member in its own list - not in FailedGates, not in UnrunGates, and not 'a verdict this ledger does not know': defective=[" + (@($mrD.DefectiveGates) -join ',') + "] failed=[" + (@($mrD.FailedGates) -join ',') + "]")
    $mD = Throws { Add-StageRecord -BuildDir $fxD.Dir -Stage '3c' -Name 'spine gate band' -Status pass -Started $fxD.Spans['3c'].Started.ToString('o') -Ended $fxD.Spans['3c'].Ended.ToString('o') }
    Check (($mD -match 'GATE-DEFECT') -and ($mD -match 'Assert-SpineCounts') -and ($mD -match '3c-results\.json')) ("PLANT a stage pass over a results file with a non-empty defective[] is refused naming the member: " + $mD)
    $mD2 = Throws { Add-StageRecord -BuildDir $fxD.Dir -Stage '3c' -Name 'spine gate band' -Status fail -Findings 1 -Partial @('Assert-SpineCounts could not re-find its own anchor this round') -Note 'recorded honestly' -Started $fxD.Spans['3c'].Started.ToString('o') -Ended $fxD.Spans['3c'].Ended.ToString('o') }
    Check (($mD2 -match 'lists as GATE-DEFECT') -and ($mD2 -match 'Assert-SpineCounts') -and ($mD2 -match 'never a rule to file as partial')) ("PLANT filing a GATE-DEFECT member into partial[] is refused whatever the status, naming it: " + $mD2)
    $mD3 = Throws { Add-StageRecord -BuildDir $fxD.Dir -Stage '3c' -Name 'spine gate band' -Status fail -Findings 0 -Note 'the band carried a gate defect; the gate is being fixed and the band re-run' -Started $fxD.Spans['3c'].Started.ToString('o') -Ended $fxD.Spans['3c'].Ended.ToString('o') }
    Check ($mD3 -eq '') ("CONTROL the same band recorded honestly as fail is still writable: " + $mD3)

    #  the same member in BOTH lists is a contradiction, reported by name
    $bothBody = $defBody | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    $bothBody.failed = @('Assert-SpineCounts')
    Write-Json -Path (Join-Path $fxD.Dir '3c-results.json') -Stamp $fxD.Spans['3c'].Ended -Body $bothBody
    $mrB = Get-StageMachineResult -BuildDir $fxD.Dir -Stage '3c'
    $mfB = Get-LedgerMachineFindings -Stage '3c' -Machine $mrB -BuildDir $fxD.Dir -PartialClaims @()
    Check ((@($mfB.Problems | Where-Object { $_ -match 'BOTH failed\[\] and defective\[\]' -and $_ -match 'Assert-SpineCounts' }).Count -ge 1) -and (@($mrB.FailedGates).Count -eq 0)) ("PLANT a member listed in both failed[] and defective[] is a named problem, and it is still not counted as a content failure: " + (Flat @($mfB.Problems | Where-Object { $_ -match 'BOTH' })))

    #  CONTROL the clean fixture writes defective = @() and nothing fires
    $fxC = New-LedgerFixtureBuild -Name 'mach-nodefect' -NoLedger
    $mrC = Get-StageMachineResult -BuildDir $fxC.Dir -Stage '3c'
    $mfC = Get-LedgerMachineFindings -Stage '3c' -Machine $mrC -BuildDir $fxC.Dir -PartialClaims @()
    Check ((@($mrC.DefectiveGates).Count -eq 0) -and (@($mfC.Problems | Where-Object { $_ -match 'GATE-DEFECT' }).Count -eq 0)) 'CONTROL an honest band with an empty defective[] raises no gate-defect problem'

    #  a -Partial entry that names a member the file itself says did not run
    $fx = New-LedgerFixtureBuild -Name 'mach-notrun' -NoLedger
    New-StageLedger -BuildDir $fx.Dir -Unit 'TEST001' | Out-Null
    Write-Json -Path (Join-Path $fx.Dir '3c-results.json') -Stamp $fx.Spans['3c'].Ended -Body ([pscustomobject]@{
        runner = 'Run-SpineGates'; stage = '3c'
        startedAt = $fx.Spans['3c'].Started.ToString('o'); ranAt = $fx.Spans['3c'].Ended.ToString('o')
        spineFingerprint = $fx.Fingerprint; partial = $false; wallClockSeconds = 300
        gates = @(
            [pscustomobject]@{ name = 'Test-Spine';        verdict = 'PASS';    exitCode = 0; seconds = 4 },
            [pscustomobject]@{ name = 'Check-RowCoverage'; verdict = 'NOT RUN'; exitCode = 2; seconds = 0; reason = 'the contract declares no keMap' }
        )
        failed = @(); verdict = 'PASS'; exitCode = 0
    })
    $m = Throws { Add-StageRecord -BuildDir $fx.Dir -Stage '3c' -Name 'spine gate band' -Status pass -Partial @('Check-RowCoverage: the contract declares no keMap') -Note 'the keMap lands at stage 2 of the next round' -Started $fx.Spans['3c'].Started.ToString('o') -Ended $fx.Spans['3c'].Ended.ToString('o') }
    Check ($m -eq '') ("CONTROL a -Partial entry naming a NOT RUN member is accepted: " + $m)

    #  no results file at all
    $fx = New-LedgerFixtureBuild -Name 'mach-none' -NoLedger
    Remove-Item -LiteralPath (Join-Path $fx.Dir '3c-results.json') -Force
    New-StageLedger -BuildDir $fx.Dir -Unit 'TEST001' | Out-Null
    $m = Throws { Add-StageRecord -BuildDir $fx.Dir -Stage '3c' -Name 'spine gate band' -Status pass -Started $fx.Spans['3c'].Started.ToString('o') -Ended $fx.Spans['3c'].Ended.ToString('o') }
    Check ($m -match '3c-results\.json' -and $m -match 'Run-SpineGates\.ps1') ("PLANT a pass on a runner stage with no results file is refused naming both: " + $m)

    #  the generated note, and free text pushed to operatorNote
    $fx = New-LedgerFixtureBuild -Name 'note'
    $lj = Read-LedgerJson -Path (Get-LedgerPath -BuildDir $fx.Dir)
    $rec3c = @($lj.records | Where-Object { "$($_.stage)" -eq '3c' })[0]
    Check ("$($rec3c.note)" -match '3c-results\.json PASS: 2 PASS, 0 FAIL, 0 NOT RUN') ("CONTROL the note is generated from gates[], never typed: " + $rec3c.note)
    Check ("$($rec3c.machine.sha256)" -match '^[0-9a-f]{64}$') 'CONTROL the record carries rec.machine with the file sha256'

    # -- 7. the results file rewritten after the record -----------------------
    Write-Host '  -- a results file rewritten after its record' -ForegroundColor DarkGray
    $fx = New-LedgerFixtureBuild -Name 'overwrite'
    $r = Test-StageLedger -BuildDir $fx.Dir
    Check ($r.Ok) ("CONTROL the build passes before the overwrite: " + (Flat $r.Problems))
    $rp = Join-Path $fx.Dir '3c-results.json'
    $was = Get-LedgerFileSha256 -Path $rp
    $body = Read-LedgerJson -Path $rp
    $body | Add-Member -NotePropertyName 'note' -NotePropertyValue 'rewritten after the record was written' -Force
    Write-Json -Path $rp -Body $body -Stamp $fx.Spans['3c'].Ended
    $now = Get-LedgerFileSha256 -Path $rp
    $r = Test-StageLedger -BuildDir $fx.Dir
    $hit = @($r.Problems | Where-Object { $_ -match [regex]::Escape($was) -and $_ -match [regex]::Escape($now) })
    Check ($hit.Count -ge 1) ("PLANT overwriting the results file after a legitimate pass names the sha256 mismatch with both hashes: " + (Flat $hit))

    # -- 8. the figure sheet --------------------------------------------------
    Write-Host '  -- the figure sheet' -ForegroundColor DarkGray
    $fx = New-LedgerFixtureBuild -Name 'sheet-forced'
    $sp = Join-Path $fx.Dir 'figure-sheet.txt'
    $txt = [System.IO.File]::ReadAllText($sp, [System.Text.Encoding]::UTF8) -replace 'BAND-VERDICT: PASS', "BAND-VERDICT: FAIL`r`nFORCE-REASON: the operator forced the cut to unblock the review"
    Write-Text -Path $sp -Text $txt -Stamp $fx.Spans['3c'].Ended
    $r = Test-StageLedger -BuildDir $fx.Dir
    $hit = @($r.Problems | Where-Object { $_ -match 'BAND-VERDICT FAIL' })
    Check ($hit.Count -ge 1) ("PLANT a -Force sheet stamped BAND-VERDICT FAIL is reported: " + (Flat $hit))

    $fx = New-LedgerFixtureBuild -Name 'sheet-nostamp'
    $sp = Join-Path $fx.Dir 'figure-sheet.txt'
    $txt = [System.IO.File]::ReadAllText($sp, [System.Text.Encoding]::UTF8) -replace '(?m)^BAND-VERDICT: PASS\r?\n', ''
    Write-Text -Path $sp -Text $txt -Stamp $fx.Spans['3c'].Ended
    $r = Test-StageLedger -BuildDir $fx.Dir
    Check (@($r.Problems | Where-Object { $_ -match 'no BAND-VERDICT stamp' }).Count -ge 1) 'PLANT a sheet with no BAND-VERDICT stamp is a named problem'

    $fx = New-LedgerFixtureBuild -Name 'sheet-empty-fp'
    Get-ChildItem -LiteralPath (Join-Path $fx.Dir 'spine') -File | Remove-Item -Force
    $fsr = Test-FigureSheetCurrent -BuildDir $fx.Dir -SpineDir (Join-Path $fx.Dir 'spine')
    Check (@($fsr.Problems | Where-Object { $_ -match 'empty expected fingerprint' }).Count -ge 1) ("PLANT an empty expected fingerprint is a problem, never a match: " + (Flat $fsr.Problems))

    #  -SpineDir is honoured
    $fx = New-LedgerFixtureBuild -Name 'sheet-spinedir'
    $alt = Join-Path $fx.Dir 'spine-copy'
    New-Item -ItemType Directory -Force -Path $alt | Out-Null
    Copy-Item (Join-Path $fx.Dir 'spine\*.json') $alt -Force
    Write-Json -Path (Join-Path $alt 't3.json') -Body ([pscustomobject]@{ topic = 3; title = 'Topic 3'; visuals = @() })
    $fsr = Test-FigureSheetCurrent -BuildDir $fx.Dir -SpineDir $alt
    Check (@($fsr.Problems | Where-Object { $_ -match 'spine .* and the spine is now|was cut from spine' }).Count -ge 1) ("CONTROL -SpineDir is used, not ignored - an extra file in the named directory moves the fingerprint: " + (Flat $fsr.Problems))

    #  a Stage 5/6/7d record written while the extract still showed prompts
    $fx = New-LedgerFixtureBuild -Name 'sheet-prompts'
    Write-Text -Path (Join-Path $fx.Dir 'guide_gate.txt') -Text "FIGURES: 0 placed drawings, 31 unresolved artwork prompt blocks`nCHANNELS: 1 tables, 0 slides, 0 captions, 0 alt texts, 0 speaker notes`nSOURCE: out\guide.docx  SHA256: 00-11  EXTRACTED: $($fx.Spans['7c'].Ended.ToString('o'))`nFIGURE CONTENT NOT PRESENT IN THIS EXTRACT`n`nGuide prose." -Stamp $fx.Spans['7c'].Ended
    $r = Test-StageLedger -BuildDir $fx.Dir
    $hit = @($r.Problems | Where-Object { $_ -match 'unresolved artwork prompt blocks' -and $_ -match '-FigureSheet' })
    Check ($hit.Count -ge 1) ("PLANT a Stage 5/6/7d record over an extract showing prompts > 0 must name its figure sheet: " + (Flat $hit))

    $fx = New-LedgerFixtureBuild -Name 'sheet-prompts-ok' -Omit @('5', '6', '7d')
    Write-Text -Path (Join-Path $fx.Dir 'guide_gate.txt') -Text "FIGURES: 0 placed drawings, 31 unresolved artwork prompt blocks`nCHANNELS: 1 tables, 0 slides, 0 captions, 0 alt texts, 0 speaker notes`nSOURCE: out\guide.docx  SHA256: 00-11  EXTRACTED: $($fx.Spans['7c'].Ended.ToString('o'))`nFIGURE CONTENT NOT PRESENT IN THIS EXTRACT`n`nGuide prose." -Stamp $fx.Spans['7c'].Ended
    foreach ($k in @('5', '6', '7d')) {
        $a = @{ BuildDir = $fx.Dir; Stage = $k; Name = (Get-LedgerStage -Key $k).Title; Status = 'pass'
                Started = $fx.Spans[$k].Started.ToString('o'); Ended = $fx.Spans[$k].Ended.ToString('o')
                FigureSheet = 'figure-sheet.txt' }
        if ((Get-LedgerStage -Key $k).Verdict) { $a['Verdict'] = 'Fully Compliant' }
        Add-StageRecord @a
    }
    $r = Test-StageLedger -BuildDir $fx.Dir
    Check (@($r.Problems | Where-Object { $_ -match '-FigureSheet' }).Count -eq 0) ("CONTROL the same records naming the sheet they were read with are clean: " + (Flat @($r.Problems | Where-Object { $_ -match 'FigureSheet' })))

    # -- 9. no mutation after the last gate -----------------------------------
    Write-Host '  -- no mutation after the last gate' -ForegroundColor DarkGray
    $fx = New-LedgerFixtureBuild -Name 'mutation'
    $gp = Join-Path $fx.Dir 'out\guide.docx'
    $wasG = Get-LedgerFileSha256 -Path $gp
    Write-Text -Path $gp -Text 'guide bytes, rewritten 92 seconds after the last gate' -Stamp ((Get-Date).ToUniversalTime())
    $nowG = Get-LedgerFileSha256 -Path $gp
    $r = Test-StageLedger -BuildDir $fx.Dir
    $hit = @($r.Problems | Where-Object { $_ -match 'guide\.docx' -and $_ -match [regex]::Escape($wasG) -and $_ -match [regex]::Escape($nowG) })
    Check ($hit.Count -ge 1) ("PLANT a delivered artefact rewritten after the newest 7c payload is named with both hashes: " + (Flat $hit))

    $fx = New-LedgerFixtureBuild -Name 'mutation-touch'
    $dp = Join-Path $fx.Dir 'out\deck.pptx'
    (Get-Item -LiteralPath $dp).LastWriteTimeUtc = (Get-Date).ToUniversalTime()
    $r = Test-StageLedger -BuildDir $fx.Dir
    Check (@($r.Problems | Where-Object { $_ -match 'deck\.pptx' -and $_ -match 'last written at' }).Count -ge 1) 'PLANT an artefact touched after the run that judged it is named, even with identical bytes'

    $fx = New-LedgerFixtureBuild -Name 'mutation-spine'
    Write-Json -Path (Join-Path $fx.Dir 'spine\t2.json') -Body ([pscustomobject]@{ topic = 2; title = 'Topic 2 edited after the band'; visuals = @() })
    $r = Test-StageLedger -BuildDir $fx.Dir
    Check (@($r.Problems | Where-Object { $_ -match 'spine' -and $_ -match 'MOVED|was .* when' }).Count -ge 1) ("PLANT a spine file rewritten after the 3c stamp is named: " + (Flat @($r.Problems | Where-Object { $_ -match 'spine' })))

    #  the artefacts[] key absent altogether
    $fx = New-LedgerFixtureBuild -Name 'no-artefacts' -NoLedger
    $body = Read-LedgerJson -Path (Join-Path $fx.Dir '7c-results.json')
    $body.PSObject.Properties.Remove('artefacts')
    Write-Json -Path (Join-Path $fx.Dir '7c-results.json') -Body $body -Stamp $fx.Spans['7c'].Ended
    New-StageLedger -BuildDir $fx.Dir -Unit 'TEST001' | Out-Null
    $r = Test-StageLedger -BuildDir $fx.Dir -InProgress
    Check (@($r.Problems | Where-Object { $_ -match 'stamps no artefacts' }).Count -ge 1) 'PLANT a results payload with no artefacts[] is REPORTED BY NAME, never read as nothing to check'

    # -- 10. -InProgress ------------------------------------------------------
    Write-Host '  -- -InProgress' -ForegroundColor DarkGray
    $fx = New-LedgerFixtureBuild -Name 'inprogress' -Omit @('8')
    $r1 = Test-StageLedger -BuildDir $fx.Dir -InProgress
    $r2 = Test-StageLedger -BuildDir $fx.Dir
    Check ($r1.Ok) ("CONTROL -InProgress passes a build that has everything but the delivery record: " + (Flat $r1.Problems))
    Check ((-not $r2.Ok) -and (@($r2.Problems | Where-Object { $_ -match 'Stage 8' -and $_ -match 'no record' }).Count -ge 1)) ("PLANT without -InProgress the same build names Stage 8: " + (Flat $r2.Problems))

    $fx = New-LedgerFixtureBuild -Name 'inprogress2' -Omit @('8', '4c')
    $r1 = Test-StageLedger -BuildDir $fx.Dir -InProgress
    Check ((-not $r1.Ok) -and (@($r1.Problems | Where-Object { $_ -match 'Stage 4c' -and $_ -match 'no record' }).Count -ge 1)) ("PLANT -InProgress excludes ONLY stage 8 - a missing 4c is still named: " + (Flat $r1.Problems))

    # -- 11. the machine-written Stage 6 record (Merge-AuditFindings) ---------
    Write-Host '  -- a machine-written Stage 6 record' -ForegroundColor DarkGray
    $fx = New-LedgerFixtureBuild -Name 'merge' -Omit @('6')
    $sha = ('a' * 64)
    $s6 = $fx.Spans['6']
    $m = Throws { Add-StageRecord -BuildDir $fx.Dir -Stage '6' -Name 'Clean-room audit, round 1 - merged by Merge-AuditFindings' -Status pass -Round 1 -Findings 0 -Verdict 'delivery set Fully Compliant (guide Fully Compliant; deck Fully Compliant)' -Note ('MACHINE-WRITTEN by Merge-AuditFindings.ps1 - sha256 ' + $sha) -Machine $sha -Started $s6.Started.ToString('o') -Ended $s6.Ended.ToString('o') }
    Check ($m -eq '') ("CONTROL a Stage 6 record carrying rec.machine and a validated -Round is accepted: " + $m)
    $lj = Read-LedgerJson -Path (Get-LedgerPath -BuildDir $fx.Dir)
    $rec6 = @($lj.records | Where-Object { "$($_.stage)" -eq '6' })[0]
    Check ("$($rec6.machine.sha256)" -eq $sha -and "$($rec6.machine.source)" -eq 'stage-writer') 'CONTROL the supplied sha256 lands in rec.machine as a stage-writer stamp'

    $m = Throws { Add-StageRecord -BuildDir $fx.Dir -Stage '7d' -Name 'confirming read' -Status pass -Round 1 -Verdict 'Fully Compliant' -Machine 'not-a-hash' -Started ((Get-Date).ToUniversalTime().AddMinutes(-9).ToString('o')) -Ended ((Get-Date).ToUniversalTime().AddMinutes(-4).ToString('o')) }
    Check ($m -match 'not a sha256') ("PLANT -Machine that is not a sha256 is refused: " + $m)
    $m = Throws { Add-StageRecord -BuildDir $fx.Dir -Stage '7d' -Name 'confirming read' -Status pass -Round -1 -Verdict 'Fully Compliant' -Machine $sha -Started ((Get-Date).ToUniversalTime().AddMinutes(-9).ToString('o')) -Ended ((Get-Date).ToUniversalTime().AddMinutes(-4).ToString('o')) }
    Check ($m -match 'is negative') ("PLANT a machine-written record at a negative round is refused: " + $m)
    #  CONTROL for the rule above: round 0 is the first pass and is ACCEPTED,
    #  so a build that was clean first time is not asked for a Stage 7 record
    #  of remediation that never happened.
    $fx0 = New-LedgerFixtureBuild -Name 'merge-round0' -Omit @('6')
    $s60 = $fx0.Spans['6']
    $m = Throws { Add-StageRecord -BuildDir $fx0.Dir -Stage '6' -Name 'Clean-room audit, first read - merged by Merge-AuditFindings' -Status pass -Round 0 -Findings 0 -Verdict 'delivery set Fully Compliant (guide Fully Compliant; deck Fully Compliant)' -Note ('MACHINE-WRITTEN by Merge-AuditFindings.ps1 - sha256 ' + $sha) -Machine $sha -Started $s60.Started.ToString('o') -Ended $s60.Ended.ToString('o') }
    Check ($m -eq '') ("CONTROL a machine-written Stage 6 record at round 0 (the first audit) is accepted: " + $m)
    #  -notmatch over an ARRAY returns the non-matching elements, not a
    #  boolean, so it reads as true whenever any unrelated problem exists.
    #  Count the matches instead.
    $stage7Problems = @((Test-StageLedger -BuildDir $fx0.Dir).Problems | Where-Object { $_ -match 'Stage 7\b' })
    Check ($stage7Problems.Count -eq 0) ("CONTROL a round-0 Stage 6 record does not make Stage 7 owed: " + ($stage7Problems -join ' | '))
    #  and the PLANT for that control: the same build at round 1 DOES owe a
    #  Stage 7 record, so it is the round that carries the rule, not the fixture.
    $m = Throws { Add-StageRecord -BuildDir $fx0.Dir -Stage '6' -Name 'Clean-room audit, round 1 - merged by Merge-AuditFindings' -Status pass -Round 1 -Findings 2 -Verdict 'delivery set Partially Compliant (guide Partially Compliant; deck Fully Compliant)' -Note ('MACHINE-WRITTEN by Merge-AuditFindings.ps1 - sha256 ' + $sha) -Machine $sha -Started ((Get-Date).ToUniversalTime().AddMinutes(-8).ToString('o')) -Ended ((Get-Date).ToUniversalTime().AddMinutes(-3).ToString('o')) }
    $stage7After = @((Test-StageLedger -BuildDir $fx0.Dir).Problems | Where-Object { $_ -match 'Stage 7\b' })
    Check ($m -eq '' -and $stage7After.Count -ge 1) ("PLANT the same build re-recorded at round 1 does make Stage 7 owed: " + $(if ($m) { $m } else { ($stage7After -join ' | ') }))
    $m = Throws { Add-StageRecord -BuildDir $fx.Dir -Stage '3c' -Name 'band' -Status pass -Round 1 -Machine $sha -Started ((Get-Date).ToUniversalTime().AddMinutes(-9).ToString('o')) -Ended ((Get-Date).ToUniversalTime().AddMinutes(-4).ToString('o')) }
    Check ($m -match '-Machine is for a stage whose own writer produced the evidence') ("PLANT -Machine on a stage that has a results file is refused: " + $m)

    #  a round number that goes backwards
    $m = Throws { Add-LateRecord -Fx $fx -Stage '6' -Offset 3 -Extra @{ Status = 'pass'; Round = 0; Verdict = 'Fully Compliant' } }
    Check ($m -match 'LOWER than the newest round') ("PLANT a round number that goes backwards is refused: " + $m)

    # -- 12. the report prints without throwing -------------------------------
    Write-Host '  -- the report' -ForegroundColor DarkGray
    $fx = New-LedgerFixtureBuild -Name 'report'
    $out = (Test-StageLedger -BuildDir $fx.Dir | Write-StageLedgerReport 6>&1 | Out-String -Width 4096)
    Check ($out -match 'LEDGER PASS' -and $out -match 'machine:' -and $out -match 'stage 7 is not required') ("CONTROL the report prints the machine block, the stage 7 rule and the verdict")

    Write-Host ''
    Write-Host ("SELF-TEST: {0} passed, {1} failed" -f $st.Pass, $st.Fail) -ForegroundColor $(if ($st.Fail) { 'Red' } else { 'Green' })
    try { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue } catch { }
    return $st
}

# ---------------------------------------------------------------------------
# Entry points. Dot-sourcing this file must run NOTHING: the guard on the
# self-test is the same one Lib-GateCommon uses, because a dot-sourced param
# block binds in the caller's scope and a caller's own -SelfTest would
# otherwise run this one.
# ---------------------------------------------------------------------------

if ($LedgerSelfTest -and $MyInvocation.InvocationName -ne '.') {
    $r = Invoke-StageLedgerSelfTest
    if ($r.Fail -gt 0) { exit 4 }
    exit 0
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
    $checkArgs = @{ BuildDir = $BuildDir }
    if ($LedgerInProgress) { $checkArgs['InProgress'] = $true }
    if ($LedgerSpineDir)   { $checkArgs['SpineDir']   = $LedgerSpineDir }
    $r = Test-StageLedger @checkArgs
    $r | Write-StageLedgerReport
    Write-Host ''
    Write-Host ("  stage 8 note (generated, not typed): {0}" -f $r.GeneratedNote) -ForegroundColor DarkGray
    if (-not $r.Ok) { exit 1 }
    exit 0
}
