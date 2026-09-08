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

    THE ENTRY REFUSAL. Before any phase, the spine's v2 fingerprint is computed
    and compared with the one stamped in the newest FULL spine-band result,
    <build>\3c-results.json (a partial -Only run writes 3c-results.partial.json
    and is ignored). A spine edited after the band was cut has been gated
    against no valid band: the runner exits 2 naming both hashes and runs
    nothing. A missing band file, a partial one, an unstamped one, or one whose
    fingerprint format differs (v1 against v2) is the same refusal, by name.

    THE RESULTS FILE. <build>\4-results.json without -AfterArtwork and
    <build>\7c-results.json with it, so a Stage 4 run can never overwrite the
    7c evidence (it did, once). Per gate: startedAt, ranAt, seconds, exitCode
    and verdict - the keys Run-SpineGates writes - plus the arm roster the gate
    printed. The payload stamps the spine fingerprint at entry, the sha256 of
    figures.json, contract.json and withhold-register.json, and each artefact's
    {path, sha256, lastWriteUtc}, so a later stage can prove what was judged. A
    results file that cannot be written makes the run FAIL (exit 1) with an X
    line: a verdict that exists only in a terminal cannot be re-read.

    HONEST VERDICTS. Every entry ends pass, fail, refused, not-applicable-
    before-artwork, not-implemented or skipped-by-request. The last three are
    listed in the payload's partial[] and excluded from the exit code; fail and
    refused set it. Nothing is silently dropped: an input a gate copy cannot
    take and a blocking rule depends on REFUSES the entry by name.

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
    copy accepts - refusing, rather than silently dropping, an input a blocking
    rule depends on and the copy cannot take.

    PHASES. Plan entries carry a Phase field - ORDER, never identity - and the
    phases run in ascending order:
      1  fan-out: guide, deck, readability, registry source arm, both extracts,
         the answer-grid mirror against the placed document, the SPINE
         re-verification members (shape mirror, row coverage, deck parity, spec
         renderability, prompt lint, provenance), brand crossover, placed
         artwork (live after -AfterArtwork, not-applicable before), the static
         fixtures channel, the in-process figure-sheet-current check, and the
         Assert-ChannelDisposition entry recorded not-implemented.
      2  grid disposition ALONE, after the three producers it reads have
         joined, with -NotBefore set to this runner's start so it can refuse a
         report an earlier run left on disk. A producer that threw, timed out,
         was refused or wrote nothing this run FAILS by name and the
         disposition is skipped; a producer exiting 1 with a fresh report still
         feeds it.
      3  the gates that need the extracts: the registry's rendered arm, the
         leakage sweep, and after artwork the withhold register and figure
         coverage rendered arms with -Stage 7c and -DocText both extracts.
    The self-test asserts the disposition's Phase exceeds its producers' and
    the extract-dependent entries' Phase exceeds the extracts', so a plan may
    gain a member in any phase without moving either rule.

    THE 7c SET IS DERIVED, NOT TYPED. The self-test greps every gate's
    '# GATE: stages=' header off disk, keeps the ones that name 7c (in stages=
    or in a stage-qualified clause), and FAILS naming any that the 7c plan
    does not run. A gate cannot join the band by being written and forgotten.

    One summary, one exit code: 0 only when everything passed, and a gate that
    timed out, threw or was refused is a failure, never a skip.

    ARM ROSTERS. A gate that dot-sources Lib-GateCommon prints one 'ARMS:' line
    (name|blocking|state|size|findings;...). This runner parses EVERY member's
    line from the captured stdout with the same parser and the same result keys
    Run-SpineGates uses, records the roster per gate, and FAILS the member with
    reason 'arm not run: <name>' when a blocking arm neither ran nor was
    declared not applicable. An unparsable cell is kept with state 'unparsed'
    and counted as blocking, so an arm cannot vanish by being printed badly.

    FIXTURES, TWO CHANNELS. Assert-GateFixtures -StaticOnly is a phase-1
    member (seconds, no process spawned). The FULL plant channel is never on
    the critical path: it is started as a DETACHED background process keyed on
    the hash of scripts\*.ps1 and left to run - nothing waits for it, and a
    Start-Job would have been killed the moment this runner exited, which is a
    channel that silently never runs. After the run the newest
    gate-fixtures.<hash>.json under the build is read and UNPROVEN is printed
    beside every member it did not prove (verdict PROVEN only); 'no fixtures
    report' when there is none. A fixtures verdict is a REPORT here, never a
    band verdict: the fixtures gate's own exit is what blocks.

    -RequireFresh (Stage 8 only) runs no gate and writes nothing: it refuses,
    exit 2 naming both timestamps, when any delivered artefact was written
    after the results file that judges it started, or its sha256 no longer
    matches the one that file recorded, or that file's verdict is not pass.

    Usage
      Run-Gates.ps1 -BuildDir <dir> [-PackDir <dir>] [-Brand ACI -Variant culinary]
                    [-Rto 45797 -Cricos 03978F] [-UnitCode X] [-AfterArtwork] [-SkipDeck]
                    [-AllowPartial] [-ResultPath <file>]
      Run-Gates.ps1 -BuildDir <dir> -RequireFresh      Stage 8 freshness refusal only
      Run-Gates.ps1 -SelfTest        no Office, no build, no API

    PS 5.1. ASCII only in this file. UTF-8 BOM required on disk.
    Exit 0 all gates pass; 1 a gate failed, was refused, timed out, or the
    results file could not be written; 2 a usage error or an entry refusal
    (spine moved after the band, artefact newer than its gates); 4 the
    self-test failed.
#>

[CmdletBinding()]
param(
    [string] $BuildDir,
    [string] $PackDir,
    [string] $SkillDir,
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
    #  The spine every re-verification member reads and the fingerprint is
    #  taken over. Default <BuildDir>\spine.
    [string] $SpineDir,
    #  Where this runner's verdict is written so a later stage can prove the
    #  gates postdate the last mutation. Default <BuildDir>\4-results.json, or
    #  <BuildDir>\7c-results.json with -AfterArtwork - two names, so a Stage 4
    #  run can never overwrite the 7c evidence.
    [string] $ResultPath,
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
    #  Threaded to Test-GuideRules and Test-DeckRules, and printed. It turns a
    #  rule that checked nothing into a reported, deliberate omission in that
    #  gate's .Partial; it never turns a finding into a pass.
    [switch] $AllowPartial,
    #  Stage 8 only. Verify-only: no gate runs and nothing is written.
    [switch] $RequireFresh,
    #  Do not start the full fixtures plant channel. For a caller that runs it
    #  itself, or a machine where spawning a second PowerShell is unwanted. The
    #  channel decides nothing here, so this omits a REPORT, never a check -
    #  and the omission is printed and recorded in the results payload.
    [switch] $SkipPlantChannel,
    [switch] $SkipDeck,
    [switch] $Serial,
    [int] $TimeoutMinutes = 30,
    [switch] $SelfTest
)

#  $PSScriptRoot is EMPTY inside a PARAMETER DEFAULT when the script is run as
#  `powershell -File`, so a default that called Split-Path on it threw inside
#  the parameter block: the script exited 1 having never run a single check -
#  the same exit code it uses for a real finding, which is why nobody noticed.
#  Resolved here instead, where the automatic variable is populated, with a
#  guarded fallback for the scriptblock case.
if (-not $SkillDir) {
    $__here = $PSScriptRoot
    if (-not $__here -and $MyInvocation.MyCommand.Path) { $__here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if ($__here) { $SkillDir = Split-Path -Parent $__here }
}

$ErrorActionPreference = 'Stop'

#  The shared gate library, loaded HERE and not in section 6, because the
#  entry refusal and the self-test both need Get-SpineFingerprint before a
#  single input is resolved. Guarded so a caller that already dot-sourced it
#  does not load it twice; its only parameter is $GateCommonSelfTest, so the
#  dot-source cannot clobber anything of this script's.
if ($SkillDir -and -not (Get-Command Get-SpineFingerprint -ErrorAction SilentlyContinue)) {
    . (Join-Path $SkillDir 'scripts\Lib-GateCommon.ps1')
}

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

#  The shared gate library: Get-SpineFingerprint and Test-GateFingerprintVersion
#  for the entry refusal. A plain library - dot-sourcing it runs nothing.
. (Join-Path (Join-Path $SkillDir 'scripts') 'Lib-GateCommon.ps1')

# ---------------------------------------------------------------------------
# 0. Phases, stamps, hashes, paths
# ---------------------------------------------------------------------------

#  Phase numbers are ORDER, never identity. The self-test asserts that the
#  disposition's Phase exceeds its producers', not where anything sits in an
#  array - a plan may gain members in any phase without moving that rule.
$script:PhaseFanOut   = 1
$script:PhaseDisposal = 2
$script:PhaseExtract  = 3

function Get-UtcStamp { return (Get-Date).ToUniversalTime().ToString('o') }

function ConvertTo-UtcTime {
    <# A stamp back to a UTC [datetime], or $null when it does not parse. #>
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [datetime]) { return $Value.ToUniversalTime() }
    $s = [string]$Value
    if (-not $s.Trim()) { return $null }
    $dt = [datetime]::MinValue
    $styles = [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal
    if ([datetime]::TryParse($s, [System.Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$dt)) { return $dt }
    return $null
}

function Get-FileSha256 {
    <# Lower-case hex, or '' when the file is absent. Opened shared so an artefact Word still holds can be hashed. #>
    param([Parameter(Mandatory)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $fs = [System.IO.File]::Open((Resolve-Path -LiteralPath $Path).Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try { return [BitConverter]::ToString($sha.ComputeHash($fs)).Replace('-', '').ToLowerInvariant() }
        finally { $fs.Dispose() }
    }
    finally { $sha.Dispose() }
}

function Get-StageKey { param([bool] $AfterArtwork) if ($AfterArtwork) { return '7c' } return '4' }

function Get-DefaultResultPath {
    <#  4-results.json before artwork, 7c-results.json after. Two names on
        purpose: a Stage 4 re-run once overwrote the only 7c evidence.  #>
    param([Parameter(Mandatory)][string] $BuildDir, [bool] $AfterArtwork)
    return (Join-Path $BuildDir ((Get-StageKey -AfterArtwork $AfterArtwork) + '-results.json'))
}

function Test-BandFingerprint {
    <#  The entry refusal. Compares the spine's CURRENT v2 fingerprint with the
        one stamped in the newest FULL spine-band result. Returns Ok, Reason,
        Current, Stamped and what the band recorded. Never throws: an absent
        or unreadable input is a named refusal, not a crash.  #>
    param([Parameter(Mandatory)][string] $BuildDir, [string] $SpineDir, [switch] $Quiet)
    if (-not $SpineDir) { $SpineDir = Join-Path $BuildDir 'spine' }
    $bandPath = Join-Path $BuildDir '3c-results.json'
    $r = [ordered]@{ Ok = $false; Reason = ''; Current = ''; Stamped = ''; BandPath = $bandPath; BandVerdict = ''; BandRanAt = '' }
    $current = ''
    try { $current = [string](Get-SpineFingerprint -BuildDir $BuildDir -SpineDir $SpineDir -Quiet:$Quiet) } catch { $current = '' }
    $r.Current = $current
    if (-not $current) {
        $r.Reason = ("no spine fingerprint can be computed: no spine directory or no spine file under {0}. Every gate here reads a spine the band has passed; there is nothing to gate against." -f $SpineDir)
        return [pscustomobject]$r
    }
    if (-not (Test-Path -LiteralPath $bandPath)) {
        $r.Reason = ("no 3c-results.json in {0}: no FULL spine-band result exists, so this spine has been gated against no band. Run Run-SpineGates.ps1 (a full run, not -Only) first." -f $BuildDir)
        return [pscustomobject]$r
    }
    $band = $null
    try { $band = Read-JsonFile -Path $bandPath } catch { $band = $null }
    if ($null -eq $band) {
        $r.Reason = ("3c-results.json at {0} is empty or does not parse; no band result can be read from it." -f $bandPath)
        return [pscustomobject]$r
    }
    if (HasProp $band 'verdict') { $r.BandVerdict = [string]$band.verdict }
    if (HasProp $band 'ranAt')   { $r.BandRanAt   = [string]$band.ranAt }
    if ((HasProp $band 'partial') -and [bool]$band.partial) {
        $r.Reason = ("3c-results.json at {0} records a PARTIAL run (-Only). A partial run is not the band; the newest full run is the only thing this runner may gate against." -f $bandPath)
        return [pscustomobject]$r
    }
    $stamped = ''
    if (HasProp $band 'spineFingerprint') { $stamped = ([string]$band.spineFingerprint).Trim() }
    $r.Stamped = $stamped
    if (-not $stamped) {
        $r.Reason = ("3c-results.json at {0} carries no spineFingerprint stamp, so nothing can say which spine the band passed." -f $bandPath)
        return [pscustomobject]$r
    }
    $cmp = ''
    try { $cmp = Test-GateFingerprintVersion -Stamp $stamped -Current $current } catch { $cmp = 'error: ' + $_.Exception.Message }
    switch ($cmp) {
        'match' { $r.Ok = $true }
        'spine-moved' {
            $r.Reason = ("the spine moved after the band: 3c-results.json was cut from spine {0} (band verdict {1}, ran {2}) and the spine is now {3}. Every 3c verdict describes a spine that no longer exists; re-run Run-SpineGates.ps1 before gating a render of it." -f $stamped, $r.BandVerdict, $r.BandRanAt, $current)
        }
        'version-changed' {
            $r.Reason = ("the fingerprint format changed since the band ran: 3c-results.json carries {0} and the current format yields {1}. Nothing can say whether the spine moved; re-run Run-SpineGates.ps1 so the band stamps a comparable fingerprint." -f $stamped, $current)
        }
        default { $r.Reason = ("the band fingerprint {0} could not be compared with the current {1}: {2}" -f $stamped, $current, $cmp) }
    }
    return [pscustomobject]$r
}

# ---------------------------------------------------------------------------
# 0b. Arm rosters, fixture proof, delivered freshness
# ---------------------------------------------------------------------------

function ConvertFrom-ArmRosterText {
    <#  Every 'ARMS:' line in a member's output, parsed by the contract
        Write-GateArmRoster prints:

            ARMS: name|true/false|state|size|findings;name|...      or  ARMS: none

        MIRRORED FROM Run-SpineGates.ps1 deliberately, cell rule for cell rule
        and key for key: the two runners write the same results shape, and a
        band that read a roster one way while the other read it another would
        put two different truths about the same gate on disk.

        Returns Lines (the raw lines), Arms[] ({name, blocking, state, size,
        findings, evidence}), BlockingNotRun[] and Problems[] (a cell that does
        not parse is a problem naming the cell, and the arm is kept with state
        'unparsed' so it cannot vanish). -Evidence labels every arm with the
        band that saw it ('4' or '7c' here).  #>
    param([string] $Text, [string] $Evidence = '7c')
    $lines = @(); $arms = @(); $notRun = @(); $problems = @()
    if ($Text) {
        foreach ($ln in ($Text -split "`n")) {
            $t = $ln.TrimEnd()
            #  (?-i) - CASE-SENSITIVE, and it matters. Write-GateArmRoster
            #  prints 'ARMS:' in capitals, but the gates ALSO print a human
            #  summary line 'arms: 4 registered, 2 blocking, all complete'.
            #  -match is case-insensitive by default in PS 5.1, so that human
            #  line was read as a roster and reported 'ARMS cell does not
            #  parse' against six passing gates on a real 3c band. Run-SpineGates
            #  carries the identical rule; the two parsers must not diverge.
            if ($t -notmatch '(?-i)^\s*ARMS:\s*(.*)$') { continue }
            $lines += $t.Trim()
            $body = $Matches[1].Trim()
            if (-not $body -or $body -ieq 'none') { continue }
            foreach ($cell in ($body -split ';')) {
                $c = $cell.Trim()
                if (-not $c) { continue }
                $p = @($c -split '\|')
                if ($p.Count -ne 5 -or -not $p[0].Trim() -or $p[1].Trim() -notin @('true', 'false') -or $p[3].Trim() -notmatch '^\d+$' -or $p[4].Trim() -notmatch '^\d+$') {
                    $problems += ("ARMS cell does not parse: '{0}'" -f $c)
                    $arms += [pscustomobject]@{ name = $c; blocking = $true; state = 'unparsed'; size = 0; findings = 0; evidence = $Evidence }
                    continue
                }
                $blocking = ($p[1].Trim() -eq 'true')
                $state = $p[2].Trim().ToLowerInvariant()
                $arms += [pscustomobject]@{ name = $p[0].Trim(); blocking = $blocking; state = $state; size = [int]$p[3].Trim(); findings = [int]$p[4].Trim(); evidence = $Evidence }
                if ($blocking -and $state -eq 'not-run') { if ($notRun -notcontains $p[0].Trim()) { $notRun += $p[0].Trim() } }
            }
        }
    }
    return [pscustomobject]@{ Lines = @($lines); Arms = @($arms); BlockingNotRun = @($notRun); Problems = @($problems) }
}

function Add-ArmRosterToResult {
    <#  Read the member's ARMS line(s) into its result. A BLOCKING arm that
        neither ran nor was declared not applicable makes the member FAIL with
        'arm not run: <name>' - appended to any reason it already has, never
        replacing it, so the member's own failure is not overwritten by this
        one. 'unparsed' is treated as not-run for the same reason a missing
        arm is: nothing here can say it ran.  #>
    param([Parameter(Mandatory)] $Result, [string] $Evidence = '7c')
    $ro = ConvertFrom-ArmRosterText -Text $Result.Text -Evidence $Evidence
    $unparsed = @(@($ro.Arms) | Where-Object { $_.blocking -and $_.state -eq 'unparsed' } | ForEach-Object { $_.name })
    $notRun = @(@($ro.BlockingNotRun) + $unparsed | Sort-Object -Unique)
    $Result.Arms = @($ro.Arms)
    $Result.ArmLines = @($ro.Lines)
    $Result.ArmsBlockingNotRun = @($notRun)
    $Result.ArmProblems = @($ro.Problems)
    if ($notRun.Count -gt 0) {
        $why = ("arm not run: {0}" -f ($notRun -join ', '))
        $Result.Ok = $false
        $Result.Reason = $(if ($Result.Reason) { $Result.Reason + '; ' + $why } else { $why })
    }
    return $Result
}

function Get-GateScriptName {
    <#  The gate a plan entry runs, as the runner itself names it in the title -
        "GUIDE GATE (Test-GuideRules)" - else the script's base name.  #>
    param([string] $Title, [string] $Script)
    $m = [regex]::Match([string]$Title, '\(([A-Za-z][A-Za-z0-9\-]*)\)\s*$')
    if ($m.Success) { return $m.Groups[1].Value }
    if ($Script) { return [System.IO.Path]::GetFileNameWithoutExtension($Script) }
    return ''
}

function Get-GateProp {
    <# The first of -Names this object carries, else $null. #>
    param($Object, [Parameter(Mandatory)][string[]] $Names)
    if ($null -eq $Object) { return $null }
    $have = @($Object.PSObject.Properties.Name)
    foreach ($n in $Names) { if ($have -contains $n) { return $Object.$n } }
    return $null
}

function Get-FixtureProof {
    <#  The newest gate-fixtures.<hash>.json under the build, read for the
        verdict it recorded per gate. MIRRORED FROM Run-SpineGates.ps1 - same
        file pattern, same keys, same Found/Map/Note shape - so the two bands
        cannot print different proof for the same gate. Only the hash-stamped
        file counts (the plant channel's output, P0-13); the un-stamped
        gate-fixtures.json a static run writes is not a proof of
        discrimination. Nothing here decides a verdict.  #>
    param([Parameter(Mandatory)][string] $BuildDir)
    $none = [pscustomobject]@{ Found = $false; Path = ''; Hash = ''; RanAt = ''; Map = @{}; Note = ("no fixtures report (no gate-fixtures.<hash>.json under {0})" -f $BuildDir) }
    if (-not (Test-Path -LiteralPath $BuildDir)) { return $none }
    $files = @(Get-ChildItem -LiteralPath $BuildDir -Recurse -File -Filter 'gate-fixtures.*.json' -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match '^gate-fixtures\.([0-9a-fA-F]{6,64})\.json$' } |
               Sort-Object LastWriteTimeUtc -Descending)
    if ($files.Count -eq 0) { return $none }
    $f = $files[0]
    $hash = ''
    if ($f.Name -match '^gate-fixtures\.([0-9a-fA-F]{6,64})\.json$') { $hash = $Matches[1].ToLowerInvariant() }
    $j = $null
    try { $j = Read-JsonFile -Path $f.FullName } catch { $j = $null }
    if ($null -eq $j) { return [pscustomobject]@{ Found = $false; Path = $f.FullName; Hash = $hash; RanAt = ''; Map = @{}; Note = ("fixtures report does not parse: {0}" -f $f.FullName) } }
    $map = @{}
    $rows = Get-GateProp -Object $j -Names @('results', 'gates', 'rows')
    foreach ($r in @($rows)) {
        if ($null -eq $r) { continue }
        $n = [string](Get-GateProp -Object $r -Names @('Gate', 'gate', 'name', 'Name', 'script', 'Script'))
        if (-not $n) { continue }
        $n = [System.IO.Path]::GetFileName($n) -replace '(?i)\.ps1$', ''
        $v = [string](Get-GateProp -Object $r -Names @('Verdict', 'verdict', 'state', 'State'))
        if (-not $v) { $v = '(no verdict recorded)' }
        $map[$n.ToLowerInvariant()] = $v
    }
    $ran = [string](Get-GateProp -Object $j -Names @('checkedAt', 'ranAt', 'generated'))
    return [pscustomobject]@{ Found = $true; Path = $f.FullName; Hash = $hash; RanAt = $ran; Map = $map; Note = ("fixtures report {0} (hash {1}, {2} gate(s) recorded)" -f $f.FullName, $hash, $map.Count) }
}

function Get-MemberProofNote {
    <# 'PROVEN', 'UNPROVEN (<verdict>)', 'UNPROVEN (not in the fixtures report)' or 'no fixtures report'. #>
    param([Parameter(Mandatory)] $Proof, [Parameter(Mandatory)][string] $Name)
    if (-not $Proof.Found) { return 'no fixtures report' }
    if (-not $Name) { return 'UNPROVEN (this entry names no gate script)' }
    $k = $Name.ToLowerInvariant()
    if (-not $Proof.Map.ContainsKey($k)) { return 'UNPROVEN (not in the fixtures report)' }
    $v = [string]$Proof.Map[$k]
    if ($v -eq 'PROVEN') { return 'PROVEN' }
    return ("UNPROVEN ({0})" -f $v)
}

function Get-ScriptsFingerprint {
    <#  A sha256 over the bytes of every scripts\*.ps1 in name order - the key
        the full plant channel is started on. Assert-GateFixtures hashes the
        recipe set into ITS key as well, which this runner cannot see, so this
        value is REPORTED and the decision to start the channel is made on the
        report's age against the newest script: a report older than a script is
        a report about scripts that no longer exist.  #>
    param([Parameter(Mandatory)][string] $ScriptsDir)
    $r = [pscustomobject]@{ Hash = ''; Count = 0; NewestUtc = $null; NewestName = '' }
    if (-not (Test-Path -LiteralPath $ScriptsDir)) { return $r }
    $files = @(Get-ChildItem -LiteralPath $ScriptsDir -Filter '*.ps1' -File -ErrorAction SilentlyContinue | Sort-Object Name)
    if ($files.Count -eq 0) { return $r }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $ms = New-Object System.IO.MemoryStream
    try {
        foreach ($f in $files) {
            $nb = [System.Text.Encoding]::UTF8.GetBytes($f.Name + "`n")
            $ms.Write($nb, 0, $nb.Length)
            $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
            $ms.Write($bytes, 0, $bytes.Length)
            if ($null -eq $r.NewestUtc -or $f.LastWriteTimeUtc -gt $r.NewestUtc) { $r.NewestUtc = $f.LastWriteTimeUtc; $r.NewestName = $f.Name }
        }
        $ms.Position = 0
        $r.Hash = ([BitConverter]::ToString($sha.ComputeHash($ms)).Replace('-', '').ToLowerInvariant())
    }
    finally { $sha.Dispose(); $ms.Dispose() }
    $r.Count = $files.Count
    return $r
}

function Test-DeliveredFreshness {
    <#  -RequireFresh. For each delivered artefact, the newest results file
        that lists it (7c-results.json, 4-results.json) is its judge. Refuses
        when the artefact was written after that judge STARTED (the gates read
        it after they started, so a mid-run rewrite is as ungated as a later
        one), when its sha256 differs from the one the judge recorded, or when
        the judge's verdict is not pass.  #>
    param([Parameter(Mandatory)][string] $BuildDir, [Parameter(Mandatory)][string[]] $Artefact)
    $lines = New-Object System.Collections.Generic.List[string]
    $problems = New-Object System.Collections.Generic.List[string]
    $judges = @()
    foreach ($leaf in @('7c-results.json', '4-results.json')) {
        $p = Join-Path $BuildDir $leaf
        if (-not (Test-Path -LiteralPath $p)) { continue }
        $j = $null
        try { $j = Read-JsonFile -Path $p } catch { $j = $null }
        if ($null -eq $j) { $problems.Add(("{0} exists but is empty or does not parse" -f $leaf)); continue }
        $ranAt = $null; $startedAt = $null
        if (HasProp $j 'ranAt') { $ranAt = ConvertTo-UtcTime $j.ranAt }
        if (HasProp $j 'startedAt') { $startedAt = ConvertTo-UtcTime $j.startedAt }
        $judges += [pscustomobject]@{ Leaf = $leaf; Path = $p; Json = $j; RanAt = $ranAt; StartedAt = $startedAt; Order = $(if ($ranAt) { $ranAt } else { [datetime]::MinValue }) }
    }
    if ($judges.Count -eq 0) {
        $problems.Add(("no results file judges the delivered artefacts (looked for 7c-results.json and 4-results.json in {0}); nothing on disk dates the gates" -f $BuildDir))
        return [pscustomobject]@{ Ok = $false; Lines = $lines.ToArray(); Problems = $problems.ToArray() }
    }
    foreach ($a in $Artefact) {
        if (-not (Test-Path -LiteralPath $a)) { $problems.Add(("delivered artefact not found: {0}" -f $a)); continue }
        $fi = Get-Item -LiteralPath $a
        $best = $null; $rec = $null
        foreach ($jd in ($judges | Sort-Object Order -Descending)) {
            $hit = @()
            if (HasProp $jd.Json 'artefacts') { $hit = @((AsArr $jd.Json.artefacts) | Where-Object { $_ -and (HasProp $_ 'path') -and ([string]$_.path -ieq $fi.FullName) }) }
            $listed = ($hit.Count -gt 0)
            if (-not $listed -and (HasProp $jd.Json 'guide') -and ([string]$jd.Json.guide -ieq $fi.FullName)) { $listed = $true }
            if (-not $listed -and (HasProp $jd.Json 'deck')  -and ([string]$jd.Json.deck  -ieq $fi.FullName)) { $listed = $true }
            if ($listed) { $best = $jd; if ($hit.Count -gt 0) { $rec = $hit[0] }; break }
        }
        if ($null -eq $best) { $problems.Add(("{0}: no results file lists it as an artefact it judged ({1})" -f $fi.Name, (($judges | ForEach-Object { $_.Leaf }) -join ', '))); continue }
        $bar = $best.StartedAt; $barName = 'startedAt'
        if ($null -eq $bar) { $bar = $best.RanAt; $barName = 'ranAt' }
        if ($null -eq $bar) { $problems.Add(("{0}: its judge {1} carries no readable ranAt, so the gates cannot be dated" -f $fi.Name, $best.Leaf)); continue }
        if ($fi.LastWriteTimeUtc -gt $bar) {
            $problems.Add(("{0} was written at {1}, AFTER the gates that judge it ({2} {3} {4}). A delivered artefact newer than its last gate is an ungated artefact: re-run the gates." -f `
                $fi.Name, $fi.LastWriteTimeUtc.ToString('o'), $best.Leaf, $barName, $bar.ToString('o')))
            continue
        }
        if ($null -ne $rec -and (HasProp $rec 'sha256') -and $rec.sha256) {
            $now = Get-FileSha256 -Path $fi.FullName
            if ($now -ne [string]$rec.sha256) {
                $problems.Add(("{0}: sha256 is now {1} but {2} judged {3}. The bytes changed without the clock saying so; re-run the gates." -f $fi.Name, $now, $best.Leaf, $rec.sha256))
                continue
            }
        }
        $verdict = ''
        if (HasProp $best.Json 'verdict') { $verdict = [string]$best.Json.verdict }
        if ($verdict -ne 'pass') {
            $problems.Add(("{0} is judged by {1} whose verdict is '{2}', not pass. Fresh against a failing run is not delivered." -f $fi.Name, $best.Leaf, $verdict))
            continue
        }
        $lines.Add(("fresh: {0} written {1}, judged by {2} ({3} {4}, verdict {5}{6})" -f $fi.Name, $fi.LastWriteTimeUtc.ToString('o'), $best.Leaf, $barName, $bar.ToString('o'), $verdict, $(if ($rec) { ', sha256 matches' } else { '' })))
    }
    return [pscustomobject]@{ Ok = ($problems.Count -eq 0); Lines = $lines.ToArray(); Problems = $problems.ToArray() }
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
    <#  The parameter names a script declares; an empty list when it is absent.
        A script that exists but will not parse THROWS (Get-Command's error is
        the reason), and the plan builder turns that into a refusal naming it.  #>
    param([Parameter(Mandatory)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    $c = Get-Command -Name $Path -ErrorAction Stop
    return @($c.Parameters.Keys | Where-Object { $_ -notin [System.Management.Automation.PSCmdlet]::CommonParameters })
}

# ---------------------------------------------------------------------------
# 2b. GATE headers - the band membership every gate declares for itself
# ---------------------------------------------------------------------------

$script:ValidGateStages = @('0', '1', '2', '3c', '4', '7c')

function Get-GateHeader {
    <#  The '# GATE: stages=...; requires=...; <stage>: <param>' line a gate
        carries directly after its comment block. Same clause grammar
        Run-SpineGates parses, because a gate declares ONE membership and both
        runners must read it the same way.

        Returns Found, Raw, Stages[], Requires[], StageRequires{} and
        Problems[]. A file with no header is Found=false - reported, never
        silently treated as a member of nothing.  #>
    param([Parameter(Mandatory)][string] $Path)
    $h = [pscustomobject]@{ Found = $false; Raw = ''; Stages = @(); Requires = @(); StageRequires = @{}; Problems = @() }
    if (-not (Test-Path -LiteralPath $Path)) { return $h }
    $text = ''
    try { $text = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path, [System.Text.Encoding]::UTF8) } catch { return $h }
    $m = [regex]::Match($text, '(?m)^#\s*GATE:\s*(.+?)\s*$')
    if (-not $m.Success) { return $h }
    $h.Found = $true
    $h.Raw = $m.Groups[1].Value.Trim()
    $stages = @(); $req = @(); $sreq = @{}; $problems = @()
    foreach ($clause in ($h.Raw -split ';')) {
        $c = $clause.Trim()
        if (-not $c) { continue }
        if ($c -match '^(?i)stages\s*=\s*(.*)$') {
            foreach ($s in ($Matches[1] -split ',')) {
                $t = $s.Trim().ToLowerInvariant()
                if (-not $t) { continue }
                if ($script:ValidGateStages -contains $t) { if ($stages -notcontains $t) { $stages += $t } }
                else { $problems += ("unknown stage '{0}' in stages= (valid: {1})" -f $t, ($script:ValidGateStages -join ', ')) }
            }
        }
        elseif ($c -match '^(?i)requires\s*=\s*(.*)$') {
            foreach ($n in ($Matches[1] -split ',')) { $t = $n.Trim(); if ($t -and $req -notcontains $t) { $req += $t } }
        }
        elseif ($c -match '^([0-9]+[a-z]?)\s*:\s*(.*)$') {
            $s = $Matches[1].ToLowerInvariant()
            $names = @($Matches[2] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            if ($script:ValidGateStages -notcontains $s) { $problems += ("stage-qualified clause names unknown stage '{0}'" -f $s) }
            elseif ($names.Count -eq 0) { $problems += ("stage-qualified clause '{0}:' names no parameter" -f $s) }
            else { $sreq[$s] = @($names) }
        }
        else { $problems += ("unrecognised clause '{0}'" -f $c) }
    }
    if ($stages.Count -eq 0) { $problems += 'no stages= clause with a valid stage' }
    $h.Stages = @($stages); $h.Requires = @($req); $h.StageRequires = $sreq; $h.Problems = @($problems)
    return $h
}

function Get-HeaderRequirement {
    <# The parameter names a header requires at one stage: requires= plus that stage's clause. #>
    param([Parameter(Mandatory)] $Header, [Parameter(Mandatory)][string] $Stage, [switch] $StageQualified)
    $out = @()
    if ($null -eq $Header -or -not $Header.Found) { return $out }
    foreach ($n in @($Header.Requires)) { if ($out -notcontains $n) { $out += $n } }
    if ($StageQualified -and $Header.StageRequires.ContainsKey($Stage)) {
        foreach ($n in @($Header.StageRequires[$Stage])) { if ($out -notcontains $n) { $out += $n } }
    }
    return $out
}

function Get-DeclaredStageGate {
    <#  Every gate on disk that declares itself a member of -Stage, DERIVED by
        reading the '# GATE:' header of every scripts\*.ps1 at run time. A gate
        counts as a member when stages= names the stage OR a stage-qualified
        clause does (a gate that says '7c: DocText' has told the reader it runs
        at 7c whatever its stages= list says, and the strict reading is the one
        that cannot silently drop a member).

        This is the check-set for "the plan runs every gate the documents
        promise": it is enumerated from the files, never typed here, so a gate
        added tomorrow is in the set the moment its header lands.  #>
    param([Parameter(Mandatory)][string] $ScriptsDir, [Parameter(Mandatory)][string] $Stage)
    $out = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $ScriptsDir)) { return $out.ToArray() }
    foreach ($f in (Get-ChildItem -LiteralPath $ScriptsDir -Filter '*.ps1' -File -ErrorAction SilentlyContinue | Sort-Object Name)) {
        $h = Get-GateHeader -Path $f.FullName
        if (-not $h.Found) { continue }
        $isMember = (@($h.Stages) -contains $Stage) -or ($h.StageRequires.ContainsKey($Stage))
        if (-not $isMember) { continue }
        $out.Add([pscustomobject]@{
            Gate = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
            Path = $f.FullName; Header = $h
            InStages = (@($h.Stages) -contains $Stage)
            Requires = @(Get-HeaderRequirement -Header $h -Stage $Stage -StageQualified)
        })
    }
    return $out.ToArray()
}

# ---------------------------------------------------------------------------
# 2c. Two checks this runner performs itself
# ---------------------------------------------------------------------------

function Test-FigureSheetCurrent {
    <#  IN PROCESS, because it needs no gate and takes milliseconds: is
        figure-sheet.txt the sheet of THIS spine?

        The sheet travels with every review pack and is what lets a review
        record count as having read the figures. Stage 7 edits the spine. A
        sheet nobody re-cut hands a reviewer figure content the document no
        longer has - and on the reference build that was caught at Stage 8,
        after every review had already been signed off against it.

        Fails naming the sheet and BOTH fingerprints. An absent sheet is a
        failure, never a skip: the pack cannot be assembled without it.  #>
    param([Parameter(Mandatory)][string] $BuildDir, [string] $SpineDir, [string] $SheetPath)
    if (-not $SpineDir) { $SpineDir = Join-Path $BuildDir 'spine' }
    if (-not $SheetPath) { $SheetPath = Join-Path $BuildDir 'figure-sheet.txt' }
    $lines = New-Object System.Collections.Generic.List[string]
    $current = ''
    try { $current = [string](Get-SpineFingerprint -BuildDir $BuildDir -SpineDir $SpineDir -Quiet) } catch { $current = '' }
    if (-not $current) {
        $lines.Add(("X no spine fingerprint can be computed from {0}, so nothing can say whether the figure sheet is current" -f $SpineDir))
        return [pscustomobject]@{ Ok = $false; Text = ($lines -join "`n") }
    }
    if (-not (Test-Path -LiteralPath $SheetPath)) {
        $lines.Add(("X no figure sheet at {0}. Cut it with scripts\New-FigureSheet.ps1 -BuildDir <dir>; the spine is {1}." -f $SheetPath, $current))
        return [pscustomobject]@{ Ok = $false; Text = ($lines -join "`n") }
    }
    $text = ''
    try { $text = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $SheetPath).Path, [System.Text.Encoding]::UTF8) } catch { $text = '' }
    $stamped = ''
    if ($text -match '(?im)^\s*SPINE-FINGERPRINT:\s*(\S+)\s*$') { $stamped = $Matches[1].Trim() }
    if (-not $stamped) {
        $lines.Add(("X the figure sheet at {0} carries no SPINE-FINGERPRINT stamp, so nothing can tell whether it still describes this spine (current {1}). Re-cut it with New-FigureSheet.ps1." -f $SheetPath, $current))
        return [pscustomobject]@{ Ok = $false; Text = ($lines -join "`n") }
    }
    $cmp = ''
    try { $cmp = Test-GateFingerprintVersion -Stamp $stamped -Current $current } catch { $cmp = 'error: ' + $_.Exception.Message }
    if ($cmp -eq 'match') {
        $lines.Add(("figure sheet current: {0} carries {1}, which is this spine" -f (Split-Path $SheetPath -Leaf), $stamped))
        return [pscustomobject]@{ Ok = $true; Text = ($lines -join "`n") }
    }
    if ($cmp -eq 'version-changed') {
        $lines.Add(("X the figure sheet at {0} carries fingerprint {1} and the current format yields {2}: nothing can say whether the spine moved. Re-cut the sheet with New-FigureSheet.ps1." -f $SheetPath, $stamped, $current))
    }
    else {
        $lines.Add(("X the figure sheet at {0} was cut from spine {1} and the spine is now {2}. Every review that counted as having read the figures read that sheet. Re-cut it with New-FigureSheet.ps1 and re-read the figures." -f $SheetPath, $stamped, $current))
    }
    return [pscustomobject]@{ Ok = $false; Text = ($lines -join "`n") }
}

function Invoke-InProcessCheck {
    <# Dispatch for Kind 'inproc' entries. An unknown name throws - never passes. #>
    param([Parameter(Mandatory)] $Entry)
    switch ($Entry.Name) {
        'figure-sheet-current' {
            return (Test-FigureSheetCurrent -BuildDir ([string]$Entry.Args['BuildDir']) -SpineDir ([string]$Entry.Args['SpineDir']) -SheetPath ([string]$Entry.Args['SheetPath']))
        }
        default { throw ("Run-Gates: no in-process check is implemented for '{0}'" -f $Entry.Name) }
    }
}

function Test-DisposalPrerequisite {
    <#  May the grid disposition read this run's reports?

        The disposition gate reads three report files. Before the phase split
        the runner started it beside the gates that write them, so every 4/7c
        disposition described LAST round's reports - and an absent key read as
        zero disposed grids on no evidence at all.

        A producer that was refused, threw, timed out or wrote nothing THIS RUN
        makes the disposition NOT RUN, named by producer. A producer that
        exited 1 with a fresh report still feeds it: a finding is a verdict
        about a real report, and the disposition is entitled to read it.

        -NotBefore is the runner's start: a report older than that is last
        round's, and the gate itself refuses it. Nothing here is decided on a
        file's mere existence.  #>
    param(
        [Parameter(Mandatory)] $Plan,
        [Parameter(Mandatory)] $Results,
        [Parameter(Mandatory)][string[]] $Producer,
        [datetime] $NotBefore
    )
    $problems = New-Object System.Collections.Generic.List[string]
    foreach ($p in $Producer) {
        $e = @(@($Plan) | Where-Object { $_.Name -eq $p })
        if ($e.Count -eq 0) { $problems.Add(("{0} is not in this run's plan, so the report the disposition reads is nobody's output this run" -f $p)); continue }
        $r = @(@($Results) | Where-Object { $_.Name -eq $p })
        if ($r.Count -eq 0) { $problems.Add(("{0} produced no result object this run" -f $p)); continue }
        $res = $r[0]
        if ($res.Refused) { $problems.Add(("{0} was REFUSED ({1}), so it wrote no report this run" -f $p, $res.Reason)); continue }
        if ($res.Error -and -not $res.Ok -and ($res.Error -match '(?i)timed out|threw|job ended|no result object')) {
            $problems.Add(("{0} did not complete ({1}), so its report is not this run's" -f $p, $res.Error)); continue
        }
        $out = [string]$e[0].Produces
        if (-not $out) { $problems.Add(("{0} declares no report path, so nothing names the file the disposition would read" -f $p)); continue }
        if (-not (Test-Path -LiteralPath $out)) { $problems.Add(("{0} wrote no report at {1}" -f $p, $out)); continue }
        if ($PSBoundParameters.ContainsKey('NotBefore')) {
            $fi = Get-Item -LiteralPath $out
            if ($fi.LastWriteTimeUtc -lt $NotBefore) {
                $problems.Add(("{0}'s report {1} was written {2}, BEFORE this run started ({3}) - it is an earlier round's report" -f $p, $fi.Name, $fi.LastWriteTimeUtc.ToString('o'), $NotBefore.ToString('o')))
            }
        }
    }
    return [pscustomobject]@{ Ok = ($problems.Count -eq 0); Problems = $problems.ToArray() }
}

# ---------------------------------------------------------------------------
# 3. The invocation plan - DATA, built before any gate runs
#
#  Every gate call is an entry here, with the exact argument hashtable it will
#  be splatted with and the PHASE it runs in. The self-test builds this plan
#  from synthetic inputs and asserts every required parameter name is present,
#  that the phases order the producers before the disposition and the extracts
#  before the gates that read them, and that every gate whose own header says
#  it is a 7c member is in the 7c plan - exercising the real plan builder, not
#  a copy of its rules.
# ---------------------------------------------------------------------------

function New-GateEntry {
    <#  One plan entry.

        -Want is every argument this runner would like to hand the gate; -Must
        names the ones a blocking rule depends on. A declared argument is
        threaded; an undeclared OPTIONAL one is recorded as dropped and
        printed; an undeclared -Must argument, a -Must name this runner has no
        value for, or a missing or unparseable script REFUSES the entry naming
        it - and a refused entry is a failure in the results, never a skip.

        The gate's own '# GATE:' header is read here and its requires= names
        are ADDED to -Must (-StageQualified adds the stage's clause too, for
        the entry that IS the gate's rendered arm at this stage). A header that
        does not name this stage is REPORTED, not refused: this runner's roster
        is wider than the headers that have landed, and the reconciliation is a
        documented change of its own, not a silent band failure.

        -Disposition marks an entry that is deliberately not run:
        'not-applicable' (a gate whose input this stage does not have yet),
        'not-implemented' (specified, nothing on disk runs it) or
        'skipped-by-request'. Those are recorded in the results' partial[] and
        excluded from the exit code - and printed, every one of them.  #>
    param(
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][string] $Title,
        [Parameter(Mandatory)][int] $Phase,
        [string] $Kind = 'script',
        [string] $Script,
        [string] $Gate,
        [string] $Stage = '7c',
        [System.Collections.IDictionary] $Want,
        [string[]] $Must,
        [string] $Produces,
        [string] $Refused,
        [string] $Disposition,
        [string] $Why,
        [System.Collections.IDictionary] $Looked,
        [switch] $StageQualified
    )
    if ($null -eq $Want) { $Want = [ordered]@{} }
    if ($null -eq $Must) { $Must = @() }
    if ($null -eq $Looked) { $Looked = @{} }
    if (-not $Gate -and $Script) { $Gate = [System.IO.Path]::GetFileNameWithoutExtension($Script) }
    $args_ = [ordered]@{}
    $dropped = @()
    $reports = @()
    $must = @($Must)
    $header = [pscustomobject]@{ Found = $false; Raw = ''; Stages = @(); Requires = @(); StageRequires = @{}; Problems = @() }

    if ($Disposition) {
        #  A disposition is a decision, not a run. Its arguments are still
        #  printed so a reader can see what it WOULD have been handed.
        foreach ($k in $Want.Keys) { $args_[[string]$k] = $Want[$k] }
        return [pscustomobject]@{
            Name = $Name; Kind = $Kind; Title = $Title; Script = $Script; Gate = $Gate; Phase = $Phase; Stage = $Stage
            Args = $args_; Wanted = @($Want.Keys | ForEach-Object { [string]$_ }); Dropped = @(); Must = @($must)
            Produces = $Produces; Refused = $null
            Disposition = $Disposition; Why = $Why; Header = $header; Reports = @()
        }
    }

    if ($Kind -eq 'script' -and -not $Refused) {
        $header = Get-GateHeader -Path $Script
        $declared = @()
        try { $declared = @(Get-ScriptParameterName -Path $Script) }
        catch { $Refused = ("gate unavailable - the script could not be read or does not parse: {0}" -f $_.Exception.Message) }
        if (-not $Refused -and $declared.Count -eq 0) { $Refused = ("gate unavailable - script not found: {0}" -f $Script) }
        if (-not $Refused) {
            if (-not $header.Found) { $reports += 'no GATE header on disk (its band membership is this runner''s plan alone)' }
            else {
                foreach ($p in @($header.Problems)) { $reports += ("GATE header problem: {0} (header: '{1}')" -f $p, $header.Raw) }
                if (@($header.Stages).Count -gt 0 -and @($header.Stages) -notcontains $Stage -and -not $header.StageRequires.ContainsKey($Stage)) {
                    $reports += ("GATE header declares stages={0} without {1}, but this runner's {1} plan names it - reconcile the header or the plan" -f (@($header.Stages) -join ','), $Stage)
                }
                foreach ($n in (Get-HeaderRequirement -Header $header -Stage $Stage -StageQualified:$StageQualified)) { if ($must -notcontains $n) { $must += $n } }
            }
        }
        if (-not $Refused) {
            foreach ($m in $must) {
                if (-not $Want.Contains([string]$m)) {
                    $where = if ($Looked.Contains([string]$m)) { (" (looked for {0}: absent)" -f $Looked[[string]$m]) } else { '' }
                    $Refused = ("the gate requires -{0} at stage {1} and this runner has no value to thread for it{2}" -f $m, $Stage, $where)
                    break
                }
            }
        }
        if (-not $Refused) {
            foreach ($k in $Want.Keys) {
                if ($declared -contains [string]$k) { $args_[[string]$k] = $Want[$k]; continue }
                if ($must -contains [string]$k) {
                    $Refused = ("this copy of the gate does not accept -{0}, which its blocking rule depends on (it takes: {1})" -f $k, ($declared -join ', '))
                    break
                }
                $dropped += [string]$k
            }
        }
    }
    else {
        #  A dot-sourced rule set (guide, deck, readability) or an in-process
        #  check: there is no script parameter list to introspect, so -Must is
        #  checked against what the runner has, which is the whole of it.
        if (-not $Refused) {
            foreach ($m in $must) {
                if (-not $Want.Contains([string]$m)) {
                    $where = if ($Looked.Contains([string]$m)) { (" (looked for {0}: absent)" -f $Looked[[string]$m]) } else { '' }
                    $Refused = ("this entry requires -{0} and this runner has no value to thread for it{1}" -f $m, $where)
                    break
                }
            }
        }
        foreach ($k in $Want.Keys) { $args_[[string]$k] = $Want[$k] }
    }

    return [pscustomobject]@{
        Name = $Name; Kind = $Kind; Title = $Title; Script = $Script; Gate = $Gate; Phase = $Phase; Stage = $Stage
        Args = $args_; Wanted = @($Want.Keys | ForEach-Object { [string]$_ }); Dropped = @($dropped); Must = @($must)
        Produces = $Produces; Refused = $Refused
        Disposition = ''; Why = ''; Header = $header; Reports = @($reports)
    }
}

function New-GateInvocationPlan {
    <#  THE WHOLE PLAN, every phase, from one input map. Phase is a field on
        the entry; nothing here depends on where an entry sits in the array.

        $In.DocTexts is the extracts that actually exist. It is empty on the
        first call (before phase 1 runs) and populated on the second, so the
        extract-dependent entries are built from what was really produced -
        and REFUSED by name when nothing was.  #>
    param([Parameter(Mandatory)][hashtable] $In)

    $plan = New-Object System.Collections.Generic.List[object]
    $scripts = Join-Path $In.SkillDir 'scripts'
    $stage = Get-StageKey -AfterArtwork ([bool]$In.AfterArtwork)
    $after = [bool]$In.AfterArtwork
    $build = [string]$In.BuildDir
    $spineDir = [string]$In.SpineDir
    $arts = @(@($In.Guide, $In.Deck) | Where-Object { $_ })
    $docTexts = @(@($In.DocTexts) | Where-Object { $_ -and (Test-Path -LiteralPath $_) })
    $noExtract = ("no rendered extract exists (looked for {0}). A rendered arm with no extract gates no artefact, so it is REFUSED, not run empty." -f ((@($In.GuideText, $In.DeckText) | Where-Object { $_ } | ForEach-Object { Split-Path $_ -Leaf }) -join ' and '))

    #  Where the runner looked for an input it did not find, so a refusal is a
    #  work order and not an observation.
    $looked = @{}
    if ($In.UnitExtract) { $looked['ExcludeText'] = $In.UnitExtract; $looked['UnitExtract'] = $In.UnitExtract }
    if ($In.GuideText)   { $looked['DocText'] = ((@($In.GuideText, $In.DeckText) | Where-Object { $_ }) -join ', ') }

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

    # =======================================================================
    # PHASE 1 - everything that shares no output
    # =======================================================================

    # ---- guide gate
    $ga = [ordered]@{}
    $ga['Path']            = $In.Guide
    $ga['QuestionsInPack'] = @($In.PackRefs)
    $ga['QuestionPattern'] = $In.QuestionPattern
    $ga['AfterArtwork']    = [bool]$after
    $ga['AllowPartial']    = [bool]$In.AllowPartial
    $plan.Add((New-GateEntry -Name 'guide' -Kind 'guide' -Phase $script:PhaseFanOut -Stage $stage -Gate 'Test-GuideRules' `
               -Title 'GUIDE GATE (Test-GuideRules)' -Want $ga -Must @('Path', 'QuestionsInPack') -Looked $looked))

    # ---- readability, on a measurement copy before artwork
    $ra = [ordered]@{}
    $ra['Path']         = $In.Guide
    $ra['Brand']        = $In.Brand
    $ra['AfterArtwork'] = [bool]$after
    $plan.Add((New-GateEntry -Name 'readability' -Kind 'readability' -Phase $script:PhaseFanOut -Stage $stage -Gate 'Test-Readability' `
               -Title 'READABILITY (Test-Readability)' -Want $ra -Must @('Path', 'Brand') -Looked $looked))

    # ---- deck gate
    if (-not $In.SkipDeck -and $In.Deck) {
        $da = [ordered]@{}
        $da['Path']               = $In.Deck
        $da['TemplatePath']       = $In.TemplatePath
        $da['Plan']               = @($In.Plan)
        $da['NumberSlotByLayout'] = $In.NumberSlotByLayout
        $da['Rto']                = $In.Rto
        $da['Cricos']             = $In.Cricos
        $da['AllowPartial']       = [bool]$In.AllowPartial
        $plan.Add((New-GateEntry -Name 'deck' -Kind 'deck' -Phase $script:PhaseFanOut -Stage $stage -Gate 'Test-DeckRules' `
                   -Title 'DECK GATE (Test-DeckRules)' -Want $da -Must @('Path', 'TemplatePath', 'Plan', 'Rto', 'Cricos') -Looked $looked))
    }
    elseif ($In.SkipDeck) {
        $plan.Add((New-GateEntry -Name 'deck' -Kind 'deck' -Phase $script:PhaseFanOut -Stage $stage -Gate 'Test-DeckRules' `
                   -Title 'DECK GATE (Test-DeckRules)' -Disposition 'skipped-by-request' -Why 'the caller passed -SkipDeck: the deck was NOT gated in this run'))
    }
    else {
        $plan.Add((New-GateEntry -Name 'deck' -Kind 'deck' -Phase $script:PhaseFanOut -Stage $stage -Gate 'Test-DeckRules' `
                   -Title 'DECK GATE (Test-DeckRules)' -Refused 'no deck artefact found and -SkipDeck was not given'))
    }

    # ---- figure registry, source arm (the rendered arm is phase 3)
    $plan.Add((New-GateEntry -Name 'figures-source' -Phase $script:PhaseFanOut -Stage $stage `
               -Title 'FIGURE REGISTRY - declared sources (Test-FigureConsistency)' -Script (Join-Path $scripts 'Test-FigureConsistency.ps1') `
               -Want ([ordered]@{ BuildDir = $build }) -Must @('BuildDir') -Looked $looked))

    # ---- extracts, one per artefact. Everything in phase 3 depends on these.
    $plan.Add((New-GateEntry -Name 'extract-guide' -Phase $script:PhaseFanOut -Stage $stage `
               -Title 'EXTRACT - guide (Get-DocText)' -Script (Join-Path $scripts 'Get-DocText.ps1') `
               -Want ([ordered]@{ Path = $In.Guide; OutPath = $In.GuideText }) -Must @('Path', 'OutPath') -Produces $In.GuideText -Looked $looked))
    if ($In.Deck -and -not $In.SkipDeck) {
        $plan.Add((New-GateEntry -Name 'extract-deck' -Phase $script:PhaseFanOut -Stage $stage `
                   -Title 'EXTRACT - deck (Get-DocText)' -Script (Join-Path $scripts 'Get-DocText.ps1') `
                   -Want ([ordered]@{ Path = $In.Deck; OutPath = $In.DeckText }) -Must @('Path', 'OutPath') -Produces $In.DeckText -Looked $looked))
    }

    # ---- the answer-grid mirror, against the placed document
    $mp = @()
    try { $mp = @(Get-ScriptParameterName -Path $In.MirrorScript) } catch { $mp = @() }
    $ma = [ordered]@{ BuildDir = $build }
    if ($spineDir) { $ma['SpineDir'] = $spineDir }
    if ($In.Guide) { $ma['DocxPath'] = @($In.Guide) }
    $ma['ReportPath'] = $In.MirrorReport
    $ma['Produces']   = $In.MirrorReport
    $badM = Merge-PassThrough -Into $ma -Extra $In.MirrorArgs -Accepted $mp
    $plan.Add((New-GateEntry -Name 'mirror' -Phase $script:PhaseFanOut -Stage $stage `
               -Title 'ANSWER-GRID MIRROR (Check-FigureMirror)' -Script $In.MirrorScript `
               -Want $ma -Must @('BuildDir', 'ReportPath', 'Produces') -Produces $In.MirrorReport -Refused $badM -Looked $looked))

    # ---- the grid band's two other producers, then ONE disposition in phase 2
    #  Placement is a mutation of the page, and the standing rule is that a
    #  mutation is followed by the WHOLE gate set. These block at 3c on the
    #  spine; they re-run here as SPINE RE-VERIFICATION because a placed
    #  figure, a caption or an alt-text string can answer an assessed row that
    #  the spine did not. Coverage and leakage are ONE verdict for the reason
    #  section 15 gives: gated apart, remediating one manufactures the other.
    $plan.Add((New-GateEntry -Name 'shape-mirror' -Phase $script:PhaseFanOut -Stage $stage `
               -Title 'ANSWER-SHAPE MIRROR - spine re-verification (Check-ShapeMirror)' -Script (Join-Path $scripts 'Check-ShapeMirror.ps1') `
               -Want ([ordered]@{ BuildDir = $build; SpineDir = $spineDir; ReportPath = $In.ShapeReport; Produces = $In.ShapeReport }) `
               -Must @('BuildDir', 'SpineDir', 'ReportPath', 'Produces') -Produces $In.ShapeReport -Looked $looked))

    $cvWant = [ordered]@{ BuildDir = $build; SpineDir = $spineDir; Whole = $true; ReportPath = $In.CoverageReport; Produces = $In.CoverageReport }
    if ($In.UnitExtract -and (Test-Path -LiteralPath $In.UnitExtract)) { $cvWant['UnitExtract'] = $In.UnitExtract }
    #  -Whole is not decoration: the disposition gate REFUSES a per-file
    #  coverage report, because the floor that disposes a grid is the
    #  whole-spine one.
    $plan.Add((New-GateEntry -Name 'row-coverage' -Phase $script:PhaseFanOut -Stage $stage `
               -Title 'ROW COVERAGE, whole spine - spine re-verification (Check-RowCoverage)' -Script (Join-Path $scripts 'Check-RowCoverage.ps1') `
               -Want $cvWant -Must @('BuildDir', 'Whole', 'ReportPath', 'Produces') -Produces $In.CoverageReport -Looked $looked))

    # ---- the deck, spec and prompt gates the documents promise at this stage
    $plan.Add((New-GateEntry -Name 'deck-parity' -Phase $script:PhaseFanOut -Stage $stage `
               -Title 'GUIDE/DECK PARITY - spine re-verification (Assert-DeckParity)' -Script (Join-Path $scripts 'Assert-DeckParity.ps1') `
               -Want ([ordered]@{ BuildDir = $build; SpineDir = $spineDir; SkillDir = $In.SkillDir; ReportPath = (Join-Path $build 'deck-parity-report.json') }) `
               -Must @('BuildDir') -Produces (Join-Path $build 'deck-parity-report.json') -Looked $looked))

    $plan.Add((New-GateEntry -Name 'spec-renderable' -Phase $script:PhaseFanOut -Stage $stage `
               -Title 'SPEC RENDERABILITY - spine re-verification (Assert-SpecRenderable)' -Script (Join-Path $scripts 'Assert-SpecRenderable.ps1') `
               -Want ([ordered]@{ BuildDir = $build; SpineDir = $spineDir; SkillDir = $In.SkillDir; ReportPath = (Join-Path $build 'spec-renderable-report.json') }) `
               -Must @('BuildDir') -Produces (Join-Path $build 'spec-renderable-report.json') -Looked $looked))

    #  -RequireManifest AT 7c ONLY. Assert-PromptLint compares its Route A
    #  prompt count with the docx-images manifest's generated-slot count. At 3b
    #  and 3c the manifest may legitimately not exist yet (the gate still
    #  demands it whenever the spine declares a Route B visual). At 7c the
    #  artwork has been generated, so the comparison is demanded outright: an
    #  absent manifest after artwork means the count was never checked.
    $plWant = [ordered]@{ BuildDir = $build; SpineDir = $spineDir; SkillDir = $In.SkillDir }
    $plMust = @('BuildDir')
    if ($In.AfterArtwork) {
        $plParams = @()
        try { $plParams = @(Get-ScriptParameterName -Path (Join-Path $scripts 'Assert-PromptLint.ps1')) } catch { $plParams = @() }
        if ($plParams -contains 'RequireManifest') { $plWant['RequireManifest'] = $true; $plMust += 'RequireManifest' }
    }
    $plan.Add((New-GateEntry -Name 'prompt-lint' -Phase $script:PhaseFanOut -Stage $stage `
               -Title 'PROMPT LINT, cover included - spine re-verification (Assert-PromptLint)' -Script (Join-Path $scripts 'Assert-PromptLint.ps1') `
               -Want $plWant -Must $plMust -Looked $looked))

    $prWant = [ordered]@{ BuildDir = $build; SpineDir = $spineDir; OutPath = (Join-Path $build 'provenance-report.json') }
    if ($In.PackDir) { $prWant['PackDir'] = $In.PackDir }
    $plan.Add((New-GateEntry -Name 'provenance' -Phase $script:PhaseFanOut -Stage $stage `
               -Title 'PROVENANCE - spine re-verification (Assert-Provenance)' -Script (Join-Path $scripts 'Assert-Provenance.ps1') `
               -Want $prWant -Must @('BuildDir') -Produces (Join-Path $build 'provenance-report.json') -Looked $looked))

    #  Assert-IdentifierNamespace declares stages=2,3c,4 in its own header, so
    #  it is a member of this band by its own account. It is here rather than
    #  in the derived-omission report because a gate that says it runs at this
    #  stage and is in no plan is exactly the false green the omission rule
    #  exists to catch - the fix is the entry, not a narrower rule.
    $nsWant = [ordered]@{ BuildDir = $build; SpineDir = $spineDir; SkillDir = $In.SkillDir; Stage = $stage; ReportPath = (Join-Path $build 'identifier-namespace-report.json') }
    $plan.Add((New-GateEntry -Name 'identifier-namespace' -Phase $script:PhaseFanOut -Stage $stage `
               -Title 'IDENTIFIER NAMESPACE - spine re-verification (Assert-IdentifierNamespace)' -Script (Join-Path $scripts 'Assert-IdentifierNamespace.ps1') `
               -Want $nsWant -Must @('BuildDir') -Produces (Join-Path $build 'identifier-namespace-report.json') -Looked $looked))

    # ---- brand crossover, BOTH artefacts in one call
    $ia = [ordered]@{ Path = $arts; BuildDir = $build; Brand = $In.Brand }
    if ($In.Variant) { $ia['Variant'] = $In.Variant }
    $plan.Add((New-GateEntry -Name 'identity' -Phase $script:PhaseFanOut -Stage $stage `
               -Title 'BRAND CROSSOVER (Check-Identity)' -Script (Join-Path $scripts 'Check-Identity.ps1') `
               -Want $ia -Must @('Path', 'BuildDir', 'Brand') -Looked $looked))

    # ---- placed artwork. Live and blocking after placement; before it there
    #      is no drawing to inspect, so the entry is recorded NOT APPLICABLE by
    #      name in partial[] rather than quietly left out of the plan.
    if ($after) {
        $plan.Add((New-GateEntry -Name 'placed' -Phase $script:PhaseFanOut -Stage $stage `
                   -Title 'PLACED ARTWORK (Check-Figures)' -Script (Join-Path $scripts 'Check-Figures.ps1') `
                   -Want ([ordered]@{ Path = $arts; BuildDir = $build; SpineDir = $spineDir; AfterArtwork = $true }) `
                   -Must @('Path', 'BuildDir', 'AfterArtwork') -Looked $looked))
    }
    else {
        $plan.Add((New-GateEntry -Name 'placed' -Phase $script:PhaseFanOut -Stage $stage -Script (Join-Path $scripts 'Check-Figures.ps1') `
                   -Title 'PLACED ARTWORK (Check-Figures)' -Disposition 'not-applicable' `
                   -Why 'before artwork: no picture has been placed yet, so there is no drawing, caption or alt text to inspect. This entry is live and blocking with -AfterArtwork.'))
    }

    # ---- the fixtures gate's static arms, seconds, as a band member
    $plan.Add((New-GateEntry -Name 'fixtures-static' -Phase $script:PhaseFanOut -Stage $stage `
               -Title 'GATE FIXTURES, static arms (Assert-GateFixtures -StaticOnly)' -Script (Join-Path $scripts 'Assert-GateFixtures.ps1') `
               -Want ([ordered]@{ SkillDir = $In.SkillDir; StaticOnly = $true; ResultDir = $In.ResultDir; Quiet = $true }) `
               -Must @('SkillDir', 'StaticOnly', 'ResultDir') -Looked $looked))

    # ---- the figure sheet, in process
    $plan.Add((New-GateEntry -Name 'figure-sheet-current' -Kind 'inproc' -Phase $script:PhaseFanOut -Stage $stage -Gate 'New-FigureSheet' `
               -Title 'FIGURE SHEET CURRENT (in process)' `
               -Want ([ordered]@{ BuildDir = $build; SpineDir = $spineDir; SheetPath = $In.FigureSheet }) -Must @('BuildDir', 'SheetPath')))

    # ---- the channel disposition, specified and not built
    $plan.Add((New-GateEntry -Name 'channel-disposition' -Kind 'none' -Phase $script:PhaseFanOut -Stage $stage -Gate 'Assert-ChannelDisposition' `
               -Title 'CHANNEL DISPOSITION (Assert-ChannelDisposition)' -Disposition 'not-implemented' `
               -Why 'specified in the roadmap and NOT YET IMPLEMENTED - no Assert-ChannelDisposition.ps1 exists. Performed today by: Assert-WithholdRegister''s rendered arm for the withhold channels only. Recorded here so the stage cannot pass on a gate nobody ran without saying so.'))

    # =======================================================================
    # PHASE 2 - the grid disposition, ALONE, after its producers have joined
    # =======================================================================

    $gdWant = [ordered]@{
        BuildDir       = $build
        ShapeReport    = $In.ShapeReport
        CoverageReport = $In.CoverageReport
        MirrorReport   = $In.MirrorReport
        NotBefore      = $In.StartedAt
        OutPath        = (Join-Path $build 'grid-disposition.json')
    }
    $plan.Add((New-GateEntry -Name 'grid-disposal' -Phase $script:PhaseDisposal -Stage $stage `
               -Title 'GRID DISPOSITION - one verdict per grid (Test-GridDisposition)' -Script (Join-Path $scripts 'Test-GridDisposition.ps1') `
               -Want $gdWant -Must @('BuildDir', 'ShapeReport', 'CoverageReport', 'MirrorReport', 'NotBefore') `
               -Produces (Join-Path $build 'grid-disposition.json') -Looked $looked))

    # =======================================================================
    # PHASE 3 - the gates that read the extracts
    # =======================================================================

    if ($docTexts.Count -eq 0) {
        $plan.Add((New-GateEntry -Name 'figures-rendered' -Phase $script:PhaseExtract -Stage $stage -StageQualified `
                   -Title 'FIGURE REGISTRY - rendered text (Test-FigureConsistency -DocText)' -Script (Join-Path $scripts 'Test-FigureConsistency.ps1') `
                   -Refused ('the rendered arm did NOT run: ' + $noExtract + ' A registry pass on sources alone gates no artefact.')))
    }
    else {
        $plan.Add((New-GateEntry -Name 'figures-rendered' -Phase $script:PhaseExtract -Stage $stage -StageQualified `
                   -Title ("FIGURE REGISTRY - rendered text, {0} artefact(s) (Test-FigureConsistency -DocText)" -f $docTexts.Count) -Script (Join-Path $scripts 'Test-FigureConsistency.ps1') `
                   -Want ([ordered]@{ BuildDir = $build; DocText = $docTexts; Stage = $stage }) -Must @('BuildDir', 'DocText') -Looked $looked))
    }

    $lp = @()
    try { $lp = @(Get-ScriptParameterName -Path $In.LeakageScript) } catch { $lp = @() }
    if ($lp.Count -eq 0) {
        $plan.Add((New-GateEntry -Name 'leakage' -Phase $script:PhaseExtract -Stage $stage `
                   -Title 'ASSESSOR LEAKAGE (Check-FigureLeakage)' -Script $In.LeakageScript -Refused ("gate script not found: {0}" -f $In.LeakageScript)))
    }
    elseif (-not $In.UnitExtract -or -not (Test-Path -LiteralPath $In.UnitExtract)) {
        $plan.Add((New-GateEntry -Name 'leakage' -Phase $script:PhaseExtract -Stage $stage `
                   -Title 'ASSESSOR LEAKAGE (Check-FigureLeakage)' -Script $In.LeakageScript `
                   -Refused ("REFUSED: no unit_extract.md in the build directory (looked for {0}). An assessor guide quotes the unit; without the unit corpus every unit line the guide teaches is misreported as assessor-only. Put the extract in place and re-run." -f $In.UnitExtract)))
    }
    else {
        $la = [ordered]@{ BuildDir = $build }
        $lkMust = @('BuildDir')
        if     ($lp -contains 'ExcludeText') { $la['ExcludeText'] = @($In.UnitExtract); $lkMust += 'ExcludeText' }
        elseif ($lp -contains 'UnitExtract') { $la['UnitExtract'] = $In.UnitExtract;    $lkMust += 'UnitExtract' }
        else {
            $plan.Add((New-GateEntry -Name 'leakage' -Phase $script:PhaseExtract -Stage $stage `
                       -Title 'ASSESSOR LEAKAGE (Check-FigureLeakage)' -Script $In.LeakageScript `
                       -Refused 'this copy of the leakage gate accepts neither -ExcludeText nor -UnitExtract, so the unit corpus cannot be passed and its findings would be false'))
            $la = $null
        }
        if ($null -ne $la) {
            if ($docTexts.Count -gt 0) { $la['DocText'] = $docTexts }
            $la['ReportPath'] = (Join-Path $build 'leakage_report.txt')
            $badL = Merge-PassThrough -Into $la -Extra $In.LeakageArgs -Accepted $lp
            $plan.Add((New-GateEntry -Name 'leakage' -Phase $script:PhaseExtract -Stage $stage `
                       -Title 'ASSESSOR LEAKAGE (Check-FigureLeakage)' -Script $In.LeakageScript `
                       -Want $la -Must $lkMust -Refused $badL -Looked $looked))
        }
    }

    #  The two rendered arms the documents promise at 7c and nobody ran. Before
    #  artwork they are recorded NOT APPLICABLE by name: the extracts exist,
    #  but the rule they carry is about what a reader sees in the FINISHED
    #  artefact, and running them here would report the prompt blocks.
    $renderedArms = @(
        [pscustomobject]@{ Name = 'withhold-rendered'; Title = 'WITHHOLD REGISTER - rendered text (Assert-WithholdRegister -Stage 7c -DocText)'; Script = (Join-Path $scripts 'Assert-WithholdRegister.ps1'); Out = (Join-Path $build 'withhold-rendered-report.json'); OutKey = 'OutPath' }
        [pscustomobject]@{ Name = 'coverage-rendered'; Title = 'FIGURE COVERAGE - rendered text (Assert-FigureCoverage -Stage 7c -DocText)'; Script = (Join-Path $scripts 'Assert-FigureCoverage.ps1'); Out = (Join-Path $build 'figure-coverage-rendered-report.json'); OutKey = 'ReportPath' }
    )
    foreach ($arm in $renderedArms) {
        if (-not $after) {
            $plan.Add((New-GateEntry -Name $arm.Name -Phase $script:PhaseExtract -Stage $stage -Script $arm.Script -Title $arm.Title `
                       -Disposition 'not-applicable' `
                       -Why 'before artwork: this arm judges what a reader sees in the FINISHED artefact, and every figure is still a prompt block. It is live and blocking with -AfterArtwork.'))
            continue
        }
        if ($docTexts.Count -eq 0) {
            $plan.Add((New-GateEntry -Name $arm.Name -Phase $script:PhaseExtract -Stage $stage -Script $arm.Script -Title $arm.Title `
                       -Refused ('the rendered arm did NOT run: ' + $noExtract)))
            continue
        }
        $aw = [ordered]@{ BuildDir = $build; SpineDir = $spineDir; Stage = $stage; DocText = $docTexts }
        $aw[[string]$arm.OutKey] = $arm.Out
        if ($arm.Name -eq 'coverage-rendered' -and $In.UnitExtract -and (Test-Path -LiteralPath $In.UnitExtract)) { $aw['ExcludeText'] = @($In.UnitExtract) }
        if ($arm.Name -eq 'withhold-rendered' -and $In.SkillDir) { $aw['SkillDir'] = $In.SkillDir }
        $plan.Add((New-GateEntry -Name $arm.Name -Phase $script:PhaseExtract -Stage $stage -StageQualified -Script $arm.Script -Title $arm.Title `
                   -Want $aw -Must @('BuildDir', 'Stage', 'DocText') -Produces $arm.Out -Looked $looked))
    }

    return $plan
}

function Get-PlanPhase {
    <# The phases present in a plan, ascending - the order the runner runs them in. #>
    param([Parameter(Mandatory)] $Plan)
    return @(@($Plan) | ForEach-Object { [int]$_.Phase } | Sort-Object -Unique)
}

function Get-EntryPhase {
    <# One entry's phase by name, or -1. Used by the self-test, so the ordering rules read as rules. #>
    param([Parameter(Mandatory)] $Plan, [Parameter(Mandatory)][string] $Name)
    $e = @(@($Plan) | Where-Object { $_.Name -eq $Name })
    if ($e.Count -eq 0) { return -1 }
    return [int]$e[0].Phase
}

function Format-ArgValue {
    param($v)
    if ($null -eq $v) { return '(null)' }
    if ($v -is [bool]) { return $v.ToString() }
    if ($v -is [datetime]) { return $v.ToUniversalTime().ToString('o') }
    if ($v -is [hashtable]) { return ("{0} entr(ies)" -f $v.Count) }
    if ($v -is [string]) {
        # A rooted path prints as its leaf; a regex full of backslashes does not.
        if ($v -match '^([A-Za-z]:|\\\\)[\\/]' -and $v.Length -gt 40) { return (Split-Path $v -Leaf) }
        if ($v.Length -gt 60) { return ($v.Substring(0, 57) + '...') }
        return $v
    }
    if ($v -is [System.Collections.IEnumerable]) {
        $items = @($v)
        if ($items.Count -le 2 -and @($items | Where-Object { $_ -is [string] }).Count -eq $items.Count) {
            return (($items | ForEach-Object { Format-ArgValue $_ }) -join ', ')
        }
        return ("{0} item(s)" -f $items.Count)
    }
    return [string]$v
}

function Get-ThreadedParameterLine {
    <# One line per gate: "-Name=value -Name=value", plus what was dropped. #>
    param([Parameter(Mandatory)] $Plan)
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($e in $Plan) {
        if ($e.Disposition) { $out.Add(("{0}: {1} - {2}" -f $e.Name, $e.Disposition.ToUpperInvariant(), $e.Why)); continue }
        if ($e.Refused) { $out.Add(("{0}: NOT RUN - {1}" -f $e.Name, $e.Refused)); continue }
        $parts = @()
        foreach ($k in $e.Args.Keys) { $parts += ("-{0}={1}" -f $k, (Format-ArgValue $e.Args[$k])) }
        $line = "{0}: {1}" -f $e.Name, ($parts -join ' ')
        if (@($e.Dropped).Count -gt 0) { $line += ("   [not accepted by this copy, dropped: {0}]" -f (@($e.Dropped) -join ', ')) }
        $out.Add($line)
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
    $startedAt = (Get-Date).ToUniversalTime().ToString('o')
    $lines = New-Object System.Collections.Generic.List[string]
    $ok = $false
    $err = ''
    $code = -1
    $partial = @()
    $refused = $false

    function Take { param($stream) foreach ($o in @($stream)) { if ($o -is [System.Management.Automation.InformationRecord]) { $lines.Add([string]$o.MessageData) } elseif ($o -is [string]) { $lines.Add($o) } elseif ($null -ne $o) { $lines.Add([string]$o) } } }

    #  A dot-sourced rule set returns its roster on .Arms and prints it only if
    #  its report writer does. The runner parses ARMS lines out of the text, so
    #  the roster is written into the text here when the report did not carry
    #  it - the alternative is a rule set whose arms the band cannot see.
    function Add-ArmLine {
        param($Result)
        if ($null -eq $Result) { return }
        if (@($Result.PSObject.Properties.Name) -notcontains 'Arms') { return }
        $arms = @($Result.Arms)
        if ($arms.Count -eq 0) { return }
        foreach ($ln in $lines) { if ([string]$ln -match '^\s*ARMS:') { return } }
        $cells = @()
        foreach ($a in $arms) {
            $names = @($a.PSObject.Properties.Name)
            $nm = ''; $bl = $false; $st = ''; $sz = 0; $fd = 0
            if ($names -contains 'name')     { $nm = [string]$a.name }     elseif ($names -contains 'Name')     { $nm = [string]$a.Name }
            if ($names -contains 'blocking') { $bl = [bool]$a.blocking }   elseif ($names -contains 'Blocking') { $bl = [bool]$a.Blocking }
            if ($names -contains 'state')    { $st = [string]$a.state }    elseif ($names -contains 'State')    { $st = [string]$a.State }
            if ($names -contains 'size')     { $sz = [int]$a.size }        elseif ($names -contains 'Size')     { $sz = [int]$a.Size }
            if ($names -contains 'findings') { $fd = [int]$a.findings }    elseif ($names -contains 'Findings') { $fd = [int]$a.Findings }
            if (-not $nm -or -not $st) { continue }
            $cells += ('{0}|{1}|{2}|{3}|{4}' -f $nm, $(if ($bl) { 'true' } else { 'false' }), $st, [int]$sz, [int]$fd)
        }
        if ($cells.Count -gt 0) { $lines.Add('ARMS: ' + ($cells -join ';')) }
    }

    try {
        $a = @{}
        foreach ($k in $Entry.Args.Keys) { $a[$k] = $Entry.Args[$k] }
        switch ($Entry.Kind) {
            'guide' {
                . (Join-Path $SkillDir 'scripts\Lib-Resolve.ps1')
                $g = Test-GuideRules @a
                Take ($g | Write-GuideRuleReport 6>&1)
                $ok = [bool]$g.Ok
                $code = $(if ($ok) { 0 } else { 1 })
                if (@($g.PSObject.Properties.Name) -contains 'Partial') { $partial = @($g.Partial) }
                Add-ArmLine -Result $g
            }
            'deck' {
                . (Join-Path $SkillDir 'scripts\Lib-Resolve.ps1')
                $d = Test-DeckRules @a
                Take ($d | Write-DeckRuleReport 6>&1)
                $ok = [bool]$d.Ok
                $code = $(if ($ok) { 0 } else { 1 })
                if (@($d.PSObject.Properties.Name) -contains 'Partial') { $partial = @($d.Partial) }
                Add-ArmLine -Result $d
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
                    $code = $(if ($ok) { 0 } else { 1 })
                    Add-ArmLine -Result $r
                }
                finally { Remove-Item -LiteralPath $rwd -Recurse -Force -ErrorAction SilentlyContinue }
            }
            'script' {
                . (Join-Path $SkillDir 'scripts\Lib-Resolve.ps1')
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
        #  THE TYPED REFUSALS ARE NOT GENERIC ERRORS. Lib-GateCommon throws
        #  'CHECK-SET EMPTY: <input> yielded nothing' and 'ARMS INCOMPLETE: ...'
        #  when a supplied input yielded nothing to check, or a declared
        #  blocking arm never finished. A dot-sourced rule set (Test-GuideRules,
        #  Test-DeckRules) raises them in this process rather than exiting 2, so
        #  without this they arrived as an unclassified throw and the member was
        #  recorded FAIL - a wrong word for it. A refusal says the gate could not
        #  judge; a failure says it judged and found a defect. Both stop the
        #  band, and the payload must not confuse them.
        if ($err -match '^(CHECK-SET EMPTY|ARMS INCOMPLETE)') { $code = 2; $refused = $true }
    }
    [pscustomobject]@{
        Name = $Entry.Name; Ok = $ok; Text = ($lines -join "`n"); Error = $err; ExitCode = $code
        Partial = $partial; Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1)
        StartedAt = $startedAt; FinishedAt = (Get-Date).ToUniversalTime().ToString('o')
        Refused = $refused
    }
}

function New-GateResult {
    <#  One member's outcome, in the keys Run-SpineGates writes: StartedAt and
        RanAt are UTC ISO strings and every member carries both whatever its
        verdict, so a later stage can date the gate and not the file it landed
        in. Arms/ArmLines/ArmsBlockingNotRun/ArmProblems are filled from the
        member's ARMS line(s) by the collector.  #>
    param(
        [string] $Name, [bool] $Ok, [string] $Text, [string] $Error, $ExitCode,
        [double] $Seconds, [double] $GateSeconds, [bool] $Refused, [string] $Reason,
        [string] $StartedAt = '', [string] $RanAt = '', $Partial = @()
    )
    if (-not $StartedAt) { $StartedAt = Get-UtcStamp }
    if (-not $RanAt) { $RanAt = Get-UtcStamp }
    return [pscustomobject]@{
        Name = $Name; Ok = $Ok; Text = $Text; Error = $Error; ExitCode = $ExitCode
        Seconds = [math]::Round($Seconds, 1); GateSeconds = [math]::Round($GateSeconds, 1)
        Refused = $Refused; Reason = $Reason; StartedAt = $StartedAt; RanAt = $RanAt
        Partial = @($Partial)
        Arms = @(); ArmLines = @(); ArmsBlockingNotRun = @(); ArmProblems = @()
    }
}

function Invoke-GatePlan {
    <#  Run every runnable entry of a plan as a Start-Job, wait with a timeout,
        and return one result per entry - refused and dispositioned entries
        included, the refusals as failures. -Serial starts and joins one job at
        a time, for debugging. Kind 'inproc' runs here, in this process,
        because it needs no gate and takes milliseconds.  #>
    param(
        [Parameter(Mandatory)] $Plan,
        [Parameter(Mandatory)][string] $SkillDir,
        [int] $TimeoutSeconds = 1800,
        [switch] $Serial,
        [string] $Evidence = '7c'
    )
    $results = New-Object System.Collections.Generic.List[object]
    $jobs = @{}
    $started = @{}
    foreach ($e in $Plan) {
        if ($e.Disposition) {
            $r = New-GateResult -Name $e.Name -Ok $true -Text '' -Error '' -ExitCode $null -Seconds 0 -GateSeconds 0 -Refused $false -Reason $e.Why
            $results.Add($r)
            continue
        }
        if ($e.Refused) {
            $results.Add((New-GateResult -Name $e.Name -Ok $false -Text '' -Error $e.Refused -ExitCode $null -Seconds 0 -GateSeconds 0 -Refused $true -Reason $e.Refused))
            continue
        }
        if ($e.Kind -eq 'inproc') {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $st = Get-UtcStamp
            $ok = $false; $text = ''; $err = ''
            try { $o = Invoke-InProcessCheck -Entry $e; $ok = [bool]$o.Ok; $text = [string]$o.Text }
            catch { $err = $_.Exception.Message; $ok = $false }
            $r = New-GateResult -Name $e.Name -Ok $ok -Text $text -Error $err -ExitCode $(if ($ok) { 0 } else { 1 }) `
                                -Seconds $sw.Elapsed.TotalSeconds -GateSeconds $sw.Elapsed.TotalSeconds -Refused $false `
                                -Reason $(if ($ok) { '' } elseif ($err) { 'threw: ' + $err } else { 'the check failed' }) -StartedAt $st
            $results.Add((Add-ArmRosterToResult -Result $r -Evidence $Evidence))
            continue
        }
        $j = Start-Job -ScriptBlock $script:GateJobBody -ArgumentList $e, $SkillDir
        $jobs[$e.Name] = $j
        $started[$e.Name] = (Get-Date)
        if ($Serial) {
            $done = Wait-Job -Job $j -Timeout $TimeoutSeconds
            if (-not $done) { Stop-Job -Job $j -ErrorAction SilentlyContinue }
        }
    }
    if ($jobs.Count -gt 0 -and -not $Serial) {
        $null = Wait-Job -Job @($jobs.Values) -Timeout $TimeoutSeconds
    }
    foreach ($e in $Plan) {
        if ($e.Disposition -or $e.Refused -or $e.Kind -eq 'inproc') { continue }
        $j = $jobs[$e.Name]
        $wall = ((Get-Date) - $started[$e.Name]).TotalSeconds
        $startedAt = $started[$e.Name].ToUniversalTime().ToString('o')
        if ($j.State -eq 'Completed') {
            $out = Receive-Job -Job $j -ErrorAction SilentlyContinue
            $out = @($out | Where-Object { $_ -and (@($_.PSObject.Properties.Name) -contains 'Ok') } | Select-Object -Last 1)
            if ($out.Count -eq 1) {
                $o = $out[0]
                #  A typed refusal raised inside the job carries Refused; it is
                #  read here so the payload says REFUSED, not FAIL.
                $jobRefused = $false
                if (@($o.PSObject.Properties.Name) -contains 'Refused') { $jobRefused = [bool]$o.Refused }
                $reason = ''
                if ($jobRefused) { $reason = 'REFUSED: ' + [string]$o.Error }
                elseif (-not $o.Ok) { $reason = if ($o.Error) { 'threw: ' + [string]$o.Error } else { 'exit code ' + [string]$o.ExitCode } }
                $ranAt = ''
                if (@($o.PSObject.Properties.Name) -contains 'FinishedAt') { $ranAt = [string]$o.FinishedAt }
                $r = New-GateResult -Name $e.Name -Ok ([bool]$o.Ok) -Text ([string]$o.Text) -Error ([string]$o.Error) -ExitCode $o.ExitCode `
                                    -Seconds $wall -GateSeconds ([double]$o.Seconds) -Refused $jobRefused -Reason $reason `
                                    -StartedAt $startedAt -RanAt $ranAt -Partial @($o.Partial)
                $results.Add((Add-ArmRosterToResult -Result $r -Evidence $Evidence))
            }
            else {
                $results.Add((New-GateResult -Name $e.Name -Ok $false -Text '' -Error 'the job returned no result object' -ExitCode $null -Seconds $wall -GateSeconds 0 -Refused $false -Reason 'the job returned no result object' -StartedAt $startedAt))
            }
        }
        else {
            $why = if ($j.State -eq 'Running') { "timed out after $TimeoutSeconds s - job stopped" } else { "job ended in state $($j.State)" }
            $errText = ''
            try { $reason = $j.ChildJobs[0].JobStateInfo.Reason; if ($reason) { $errText = [string]$reason.Message } } catch { }
            if (-not $errText) { try { $null = Receive-Job -Job $j -ErrorAction Stop } catch { $errText = $_.Exception.Message } }
            if ($j.State -eq 'Running') { Stop-Job -Job $j -ErrorAction SilentlyContinue }
            $results.Add((New-GateResult -Name $e.Name -Ok $false -Text $errText -Error $why -ExitCode $null -Seconds $wall -GateSeconds 0 -Refused $false -Reason $why -StartedAt $startedAt))
        }
        Remove-Job -Job $j -Force -ErrorAction SilentlyContinue
    }
    return $results
}

function Get-GateVerdict {
    <#  One word per member, in the vocabulary Run-SpineGates writes plus the
        three dispositions this band carries. Nothing is ever absent.  #>
    param([Parameter(Mandatory)] $Entry, [Parameter(Mandatory)] $Result)
    if ($Entry.Disposition -eq 'skipped-by-request') { return 'skipped-by-request' }
    if ($Entry.Disposition -eq 'not-applicable')     { return 'not-applicable' }
    if ($Entry.Disposition -eq 'not-implemented')    { return 'not-implemented' }
    if ($Result.Refused) { return 'REFUSED' }
    if ($Result.Ok) { return 'PASS' }
    return 'FAIL'
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
# 5. What the band decides, as functions - so the self-test drives the real
#    rules and not a copy of them
# ---------------------------------------------------------------------------

function Get-PlanOmission {
    <#  Every gate whose OWN header declares it a member of this stage and
        which this runner's plan does not run. The check-set is derived from
        disk (Get-DeclaredStageGate), never typed, so a gate added tomorrow is
        in it the moment its header lands - and a gate the documents promise
        at 7c that nobody runs is exactly the false green this runner exists
        to prevent.

        A dispositioned entry (not-applicable / not-implemented /
        skipped-by-request) still COUNTS as present: it is in the plan, it is
        printed, and it reaches the results file by name. An omission is an
        entry that does not exist at all.  #>
    param([Parameter(Mandatory)] $Plan, [Parameter(Mandatory)][string] $ScriptsDir, [Parameter(Mandatory)][string] $Stage)
    $have = @(@($Plan) | ForEach-Object { [string]$_.Gate } | Where-Object { $_ })
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($d in (Get-DeclaredStageGate -ScriptsDir $ScriptsDir -Stage $Stage)) {
        if ($have -contains $d.Gate) { continue }
        $out.Add([pscustomobject]@{ Gate = $d.Gate; Header = $d.Header.Raw; Path = $d.Path })
    }
    return $out.ToArray()
}

function Get-BandFailure {
    <#  The member names that count against the exit code: a FAIL, a REFUSED,
        or a member whose blocking arm never ran. A dispositioned entry never
        does - it is recorded in partial[] instead, by name and with its
        reason, which is the only honest way to leave a gate unrun.  #>
    param([Parameter(Mandatory)] $Plan, [Parameter(Mandatory)] $Results)
    $failed = @()
    foreach ($e in $Plan) {
        if ($e.Disposition) { continue }
        $r = @(@($Results) | Where-Object { $_.Name -eq $e.Name })
        if ($r.Count -eq 0) { $failed += $e.Name; continue }
        if (-not $r[0].Ok) { $failed += $e.Name }
    }
    return @($failed)
}

function New-ResultPayload {
    <#  The results file, in the shape Run-SpineGates writes 3c-results.json -
        same per-gate keys (name, script, phase, params, exitCode, startedAt,
        ranAt, seconds, verdict, reason, refused, arms), same top-level
        vocabulary (ranAt, startedAt, spineFingerprint, partial, gates, failed,
        defective, fixtures, verdict, exitCode).

        Until 4 Sep 2026 this runner printed its verdict and wrote nothing, so
        nothing on disk dated its own gates and a whole 7c band read as "no
        result at all". Then a Stage 4 run overwrote the 7c evidence, because
        both wrote one file. Hence two names, and hence the input hashes and
        the per-artefact {path, sha256, lastWriteUtc}: a later stage can prove
        WHICH bytes these verdicts are about.  #>
    param(
        [Parameter(Mandatory)] $Plan,
        [Parameter(Mandatory)] $Results,
        [Parameter(Mandatory)][hashtable] $Meta
    )
    $gateRecords = New-Object System.Collections.Generic.List[object]
    $partial = New-Object System.Collections.Generic.List[object]
    foreach ($e in $Plan) {
        $rr = @(@($Results) | Where-Object { $_.Name -eq $e.Name })
        if ($rr.Count -eq 0) { continue }
        $r = $rr[0]
        $verdict = Get-GateVerdict -Entry $e -Result $r
        $params = [ordered]@{}
        foreach ($k in $e.Args.Keys) { $params[[string]$k] = (Format-ArgValue $e.Args[$k]) }
        $proofNote = ''
        if ($Meta.ContainsKey('Proof') -and $null -ne $Meta['Proof']) { $proofNote = Get-MemberProofNote -Proof $Meta['Proof'] -Name ([string]$e.Gate) }
        $gateRecords.Add([pscustomobject]@{
            name = $e.Name; gate = $e.Gate; title = $e.Title; script = $e.Script; phase = [int]$e.Phase; stage = [string]$e.Stage
            params = [pscustomobject]$params; dropped = @($e.Dropped); must = @($e.Must)
            exitCode = $r.ExitCode; startedAt = $r.StartedAt; ranAt = $r.RanAt
            seconds = $r.Seconds; gateSeconds = $r.GateSeconds
            verdict = $verdict; reason = [string]$r.Reason; refused = [bool]$r.Refused
            disposition = [string]$e.Disposition; why = [string]$e.Why
            arms = @($r.Arms); armLines = @($r.ArmLines); armsBlockingNotRun = @($r.ArmsBlockingNotRun); armProblems = @($r.ArmProblems)
            partialRules = @($r.Partial)
            fixtureProof = $proofNote
            header = $(if ($e.Header.Found) { [string]$e.Header.Raw } else { '' }); headerReports = @($e.Reports)
            produces = [string]$e.Produces
        })
        if ($e.Disposition) { $partial.Add([pscustomobject]@{ name = $e.Name; gate = $e.Gate; disposition = [string]$e.Disposition; why = [string]$e.Why }) }
        elseif (@($r.Partial).Count -gt 0) { $partial.Add([pscustomobject]@{ name = $e.Name; gate = $e.Gate; disposition = 'rules-that-checked-nothing'; why = (@($r.Partial) -join '; ') }) }
    }
    $failed = Get-BandFailure -Plan $Plan -Results $Results
    $rc = [int]$Meta['ExitCode']
    return [pscustomobject]([ordered]@{
        runner       = 'Run-Gates'
        stage        = [string]$Meta['Stage']
        ranAt        = (Get-UtcStamp)
        startedAt    = [string]$Meta['StartedAt']
        buildDir     = [string]$Meta['BuildDir']
        spineDir     = [string]$Meta['SpineDir']
        guide        = [string]$Meta['Guide']
        deck         = [string]$Meta['Deck']
        afterArtwork = [bool]$Meta['AfterArtwork']
        skipDeck     = [bool]$Meta['SkipDeck']
        allowPartial = [bool]$Meta['AllowPartial']
        spineFingerprint = [string]$Meta['SpineFingerprint']
        bandFingerprint  = [string]$Meta['BandFingerprint']
        inputs       = $Meta['Inputs']
        artefacts    = @($Meta['Artefacts'])
        seconds      = [double]$Meta['Seconds']
        partial      = $partial.ToArray()
        gates        = $gateRecords.ToArray()
        failed       = @($failed)
        #  The GATE-DEFECT class (a gate that cannot re-find its own anchor) is
        #  P1; the key is written empty now so the shape does not change then.
        defective    = @()
        fixtures     = $Meta['Fixtures']
        planOmissions = @($Meta['PlanOmissions'])
        verdict      = $(if ($rc -eq 0) { 'PASS' } else { 'FAIL' })
        exitCode     = $rc
    })
}

function Get-InputHash {
    <#  The three inputs every verdict in this band depends on and none of
        which is the page: the registry, the contract and the withhold
        register. Stamped so a later reader can tell whether the verdicts are
        about the inputs on disk now.  #>
    param([Parameter(Mandatory)][string] $BuildDir)
    $out = [ordered]@{}
    foreach ($leaf in @('figures.json', 'contract.json', 'withhold-register.json')) {
        $p = Join-Path $BuildDir $leaf
        $out[$leaf] = [pscustomobject]@{
            path = $p
            sha256 = (Get-FileSha256 -Path $p)
            lastWriteUtc = $(if (Test-Path -LiteralPath $p) { (Get-Item -LiteralPath $p).LastWriteTimeUtc.ToString('o') } else { '' })
        }
    }
    return [pscustomobject]$out
}

function Get-ArtefactStamp {
    <# {path, sha256, lastWriteUtc} per delivered artefact - what these gates judged. #>
    param([Parameter(Mandatory)][string[]] $Path)
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($p in $Path) {
        if (-not $p) { continue }
        $exists = Test-Path -LiteralPath $p
        $out.Add([pscustomobject]@{
            path = $p
            sha256 = (Get-FileSha256 -Path $p)
            lastWriteUtc = $(if ($exists) { (Get-Item -LiteralPath $p).LastWriteTimeUtc.ToString('o') } else { '' })
        })
    }
    return $out.ToArray()
}

# ---------------------------------------------------------------------------
# 6. Self-test - no Office, no build, no API. Every rule below is exercised
#    through the REAL function that decides it, on a fixture with a planted
#    defect and a clean control.
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
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        $utf8b = New-Object System.Text.UTF8Encoding($true)

        # =================================================================
        # A. pack references, derived from the contract and the pack
        # =================================================================
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
        [System.IO.File]::WriteAllText((Join-Path $pack 'content\uat1_tasks_1_2.json'), '{"items":[{"id":"UAT1-T1"},{"id":"UAT1-T2"}]}', $utf8)
        [System.IO.File]::WriteAllText((Join-Path $pack 'content\wb_tasks_1_3.json'),   '{"items":[{"id":"WB-T1"},{"id":"WB-T2"},{"id":"WB-T3"}]}', $utf8)
        [System.IO.File]::WriteAllText((Join-Path $pack 'content\observations_1_2.json'), '{"items":[{"id":"OBS-COVER"},{"id":"OBS-1"},{"id":"OBS-2"}]}', $utf8)

        $refs = Get-PackReference -Contract $contract -PackDir $pack
        if ($refs.Part.Count -eq 3) { Ok 'part-level references come from the questionMap (3)' } else { Bad "part-level count $($refs.Part.Count)" }
        if ($refs.Task.Count -eq 5 -and $refs.Task -contains 'Knowledge Task 2' -and $refs.Task -contains 'Workbook Task 3') { Ok 'task-level references derived from the pack content files, labelled by family (5)' } else { Bad ("task-level: " + ($refs.Task -join ', ')) }
        if ($refs.Observation.Count -eq 2 -and $refs.Observation -contains 'Observation 2') { Ok 'observations derived (2); the cover item is not a reference' } else { Bad ("observations: " + ($refs.Observation -join ', ')) }
        if ($refs.All.Count -eq 9) { Ok 'distinct reference set is the union (9)' } else { Bad "distinct $($refs.All.Count)" }
        if (($refs.Notes -join ' ') -match 'uat1 -> knowledge' -and ($refs.Notes -join ' ') -match 'wb -> workbook') { Ok 'the content-file map is printed with how each family was decided' } else { Bad ("notes: " + ($refs.Notes -join ' | ')) }
        $c2 = [pscustomobject]@{ questionMap = [pscustomobject]@{ '1.1' = @('Q1', 'Q2(a)') } }
        $ls2 = Get-ReferenceLabelSet -Contract $c2
        if ($ls2.Labels.Count -eq 1 -and $ls2.Labels['q'] -eq 'Q {n}') { Ok 'labels fall back to the questionMap prefixes when the contract has no convention' } else { Bad ("fallback labels: " + (($ls2.Labels.Keys | ForEach-Object { "$_=$($ls2.Labels[$_])" }) -join ',')) }

        # =================================================================
        # B. the input map every plan below is built from
        # =================================================================
        $unitX = Join-Path $build 'unit_extract.md'
        [System.IO.File]::WriteAllText($unitX, 'Performance Evidence', $utf8)
        $guideText = Join-Path $build 'guide_gate.txt'
        $deckText  = Join-Path $build 'deck_gate.txt'
        [System.IO.File]::WriteAllText($guideText, 'guide text', $utf8)
        [System.IO.File]::WriteAllText($deckText,  'deck text',  $utf8)
        $spineDir = Join-Path $build 'spine'
        New-Item -ItemType Directory -Force -Path $spineDir | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $spineDir 't1_1.1.json'), '{ "topic": 1, "visuals": [] }', $utf8)
        $runStart = (Get-Date).ToUniversalTime()
        $scriptsReal = Join-Path $SkillDir 'scripts'

        $in = @{
            BuildDir = $build; SkillDir = $SkillDir; SpineDir = $spineDir; PackDir = $pack
            Guide = (Join-Path $build 'out\X_Learner_Guide.docx'); Deck = (Join-Path $build 'out\X_Delivery_PowerPoint.pptx')
            PackRefs = $refs.All; QuestionPattern = [string]$contract.referenceConvention.questionPattern
            AfterArtwork = $true; AllowPartial = $false
            TemplatePath = 'C:\t\deck.pptx'; Plan = @(@{ Tag = 't'; Kind = 'title' }); NumberSlotByLayout = @{ 1 = 0 }
            Rto = '00000'; Cricos = '00000A'; Brand = 'X'; Variant = 'y'; UnitExtract = $unitX
            MirrorScript = (Join-Path $scriptsReal 'Check-FigureMirror.ps1'); LeakageScript = (Join-Path $scriptsReal 'Check-FigureLeakage.ps1')
            GuideText = $guideText; DeckText = $deckText; DocTexts = @($guideText, $deckText); SkipDeck = $false
            ShapeReport = (Join-Path $build 'shape-mirror-report.json'); CoverageReport = (Join-Path $build 'row-coverage-report.json')
            MirrorReport = (Join-Path $build 'figure-mirror-report.json'); FigureSheet = (Join-Path $build 'figure-sheet.txt')
            ResultDir = $build; StartedAt = $runStart
        }
        $p7 = New-GateInvocationPlan -In $in

        # ---- every parameter a blocking rule depends on is threaded, and printed
        $names = New-Object 'System.Collections.Generic.HashSet[string]'
        foreach ($e in @($p7)) { foreach ($k in $e.Args.Keys) { [void]$names.Add([string]$k) } }
        $required = @('QuestionsInPack', 'QuestionPattern', 'AfterArtwork', 'TemplatePath', 'Plan', 'NumberSlotByLayout', 'Rto', 'Cricos', 'DocText', 'Path', 'BuildDir', 'Brand', 'Variant', 'AllowPartial')
        $missing = @($required | Where-Object { -not $names.Contains($_) })
        if ($missing.Count -eq 0) { Ok ("the plan threads every required parameter: " + ($required -join ', ')) } else { Bad ("plan is missing: " + ($missing -join ', ')) }
        if ($names.Contains('ExcludeText') -or $names.Contains('UnitExtract')) { Ok 'the unit corpus is threaded to the leakage gate under the name that copy accepts' } else { Bad 'unit corpus not threaded' }
        $lines7 = Get-ThreadedParameterLine -Plan $p7
        $joined = ($lines7 -join "`n")
        $missingInPrint = @($required | Where-Object { $joined -notmatch ('-' + [regex]::Escape($_) + '=') })
        if ($missingInPrint.Count -eq 0) { Ok 'the printed threaded-parameter list names every one of them' } else { Bad ("printed list lacks: " + ($missingInPrint -join ', ')) }
        $id = @($p7 | Where-Object { $_.Name -eq 'identity' })[0]
        if (@($id.Args['Path']).Count -eq 2) { Ok 'Check-Identity is handed BOTH artefacts in one call' } else { Bad 'Check-Identity not handed both artefacts' }

        # =================================================================
        # C. PHASES are order, not array position
        # =================================================================
        $phShape = Get-EntryPhase -Plan $p7 -Name 'shape-mirror'
        $phCov   = Get-EntryPhase -Plan $p7 -Name 'row-coverage'
        $phMir   = Get-EntryPhase -Plan $p7 -Name 'mirror'
        $phDisp  = Get-EntryPhase -Plan $p7 -Name 'grid-disposal'
        if ($phShape -gt 0 -and $phCov -gt 0 -and $phMir -gt 0 -and $phDisp -gt $phShape -and $phDisp -gt $phCov -and $phDisp -gt $phMir) {
            Ok ("grid disposal is in a LATER PHASE ({0}) than all three producers it reads (shape {1}, coverage {2}, mirror {3})" -f $phDisp, $phShape, $phCov, $phMir)
        }
        else { Bad ("phases wrong: shape={0} coverage={1} mirror={2} disposal={3}" -f $phShape, $phCov, $phMir, $phDisp) }
        $phExG = Get-EntryPhase -Plan $p7 -Name 'extract-guide'
        $phExD = Get-EntryPhase -Plan $p7 -Name 'extract-deck'
        $dependents = @('figures-rendered', 'leakage', 'withhold-rendered', 'coverage-rendered')
        $badDep = @($dependents | Where-Object { (Get-EntryPhase -Plan $p7 -Name $_) -le $phExG -or (Get-EntryPhase -Plan $p7 -Name $_) -le $phExD })
        if ($phExG -gt 0 -and $phExD -gt 0 -and $badDep.Count -eq 0) { Ok ("every extract-dependent entry runs in a later phase than both extracts ({0}): {1}" -f $phExG, ($dependents -join ', ')) }
        else { Bad ("extract phase {0}/{1}; these do not follow it: {2}" -f $phExG, $phExD, ($badDep -join ', ')) }
        $ph = Get-PlanPhase -Plan $p7
        if (@($ph).Count -ge 3 -and $ph[0] -lt $ph[1]) { Ok ("the plan declares its phases in ascending order: " + (($ph | ForEach-Object { [string]$_ }) -join ', ')) } else { Bad ("phases present: " + (($ph | ForEach-Object { [string]$_ }) -join ', ')) }

        # =================================================================
        # D. the 7c check-set is DERIVED from the gates' own headers
        # =================================================================
        $declared7 = @(Get-DeclaredStageGate -ScriptsDir $scriptsReal -Stage '7c')
        if ($declared7.Count -gt 0) { Ok ("the expected 7c set is derived at run time from {0} gate header(s) on disk: {1}" -f $declared7.Count, ((@($declared7 | ForEach-Object { $_.Gate })) -join ', ')) }
        else { Bad 'no gate on disk declares a 7c membership - the derived check-set is empty, which would pass by checking nothing' }
        $omit = @(Get-PlanOmission -Plan $p7 -ScriptsDir $scriptsReal -Stage '7c')
        if ($omit.Count -eq 0) { Ok 'the 7c plan runs every gate whose own header declares it a 7c member' }
        else { Bad ("the 7c plan omits gate(s) that declare themselves 7c members: " + ((@($omit | ForEach-Object { $_.Gate + " [" + $_.Header + "]" })) -join '; ')) }
        # ---- PLANTED OMISSION: drop one member and the same rule must name it
        if ($declared7.Count -gt 0) {
            $victim = [string]$declared7[0].Gate
            $cut = @($p7 | Where-Object { [string]$_.Gate -ne $victim })
            $omit2 = @(Get-PlanOmission -Plan $cut -ScriptsDir $scriptsReal -Stage '7c')
            if (@($omit2 | ForEach-Object { $_.Gate }) -contains $victim) { Ok ("PLANT: a 7c member removed from the plan is reported as an omission by name ({0})" -f $victim) }
            else { Bad ("PLANT DID NOT LAND: removing {0} from the plan produced no omission" -f $victim) }
        }

        # =================================================================
        # E. Stage 4 versus 7c: two files, and 'placed' recorded not-applicable
        # =================================================================
        $r4 = Get-DefaultResultPath -BuildDir $build -AfterArtwork $false
        $r7 = Get-DefaultResultPath -BuildDir $build -AfterArtwork $true
        if ((Split-Path $r4 -Leaf) -eq '4-results.json' -and (Split-Path $r7 -Leaf) -eq '7c-results.json') { Ok 'the results file is 4-results.json without -AfterArtwork and 7c-results.json with it - a Stage 4 run cannot overwrite the 7c evidence' }
        else { Bad ("result paths: {0} / {1}" -f (Split-Path $r4 -Leaf), (Split-Path $r7 -Leaf)) }
        $in4 = $in.Clone(); $in4['AfterArtwork'] = $false
        $p4 = New-GateInvocationPlan -In $in4
        $placed4 = @($p4 | Where-Object { $_.Name -eq 'placed' })
        if ($placed4.Count -eq 1 -and $placed4[0].Disposition -eq 'not-applicable') { Ok "without -AfterArtwork the 'placed' entry is recorded NOT APPLICABLE, by name, not dropped from the plan" }
        else { Bad ("placed entry before artwork: count={0} disposition='{1}'" -f $placed4.Count, $(if ($placed4.Count) { $placed4[0].Disposition } else { '' })) }
        $declared4 = @(Get-DeclaredStageGate -ScriptsDir $scriptsReal -Stage '4')
        if ($declared4.Count -gt 0) { Ok ("the expected STAGE 4 set is derived the same way from {0} gate header(s): {1}" -f $declared4.Count, ((@($declared4 | ForEach-Object { $_.Gate })) -join ', ')) }
        else { Bad 'no gate on disk declares a stage-4 membership - the derived check-set is empty, which would pass by checking nothing' }
        $omit4 = @(Get-PlanOmission -Plan $p4 -ScriptsDir $scriptsReal -Stage '4')
        if ($omit4.Count -eq 0) { Ok 'the Stage 4 plan runs every gate whose own header declares it a stage-4 member' }
        else { Bad ("the Stage 4 plan omits gate(s) that declare themselves stage-4 members: " + ((@($omit4 | ForEach-Object { $_.Gate + " [" + $_.Header + "]" })) -join '; ')) }
        $placed7 = @($p7 | Where-Object { $_.Name -eq 'placed' })
        if ($placed7.Count -eq 1 -and -not $placed7[0].Disposition -and $placed7[0].Args.Contains('AfterArtwork')) { Ok 'with -AfterArtwork the placed-artwork gate is live and threaded -AfterArtwork' }
        else { Bad 'placed entry after artwork is not live' }
        # ---- and the payload records it in partial[], never as a pass
        $res4 = @()
        foreach ($e in $p4) { $res4 += (New-GateResult -Name $e.Name -Ok $true -Text '' -Error '' -ExitCode 0 -Seconds 0 -GateSeconds 0 -Refused $false -Reason '') }
        $pay4 = New-ResultPayload -Plan $p4 -Results $res4 -Meta @{
            Stage = '4'; StartedAt = $runStart.ToString('o'); BuildDir = $build; SpineDir = $spineDir; Guide = $in.Guide; Deck = $in.Deck
            AfterArtwork = $false; SkipDeck = $false; AllowPartial = $false; SpineFingerprint = 'v2:x'; BandFingerprint = 'v2:x'
            Inputs = (Get-InputHash -BuildDir $build); Artefacts = @(); Seconds = 1; ExitCode = 0; Fixtures = $null; PlanOmissions = @(); Proof = $null
        }
        $pPlaced = @($pay4.partial | Where-Object { $_.name -eq 'placed' })
        $gPlaced = @($pay4.gates | Where-Object { $_.name -eq 'placed' })
        if ($pPlaced.Count -eq 1 -and $gPlaced.Count -eq 1 -and $gPlaced[0].verdict -eq 'not-applicable') { Ok "4-results.json records 'placed' with verdict not-applicable and lists it in partial[] with its reason" }
        else { Bad ("payload: partial entries for placed={0}, gate verdict='{1}'" -f $pPlaced.Count, $(if ($gPlaced.Count) { $gPlaced[0].verdict } else { '(absent)' })) }
        $chan = @($pay4.gates | Where-Object { $_.name -eq 'channel-disposition' })
        if ($chan.Count -eq 1 -and $chan[0].verdict -eq 'not-implemented' -and @($pay4.partial | Where-Object { $_.name -eq 'channel-disposition' }).Count -eq 1) { Ok 'the Assert-ChannelDisposition entry is recorded not-implemented in partial[], never absent and never a pass' }
        else { Bad 'channel-disposition is not recorded not-implemented in partial[]' }
        if (@($pay4.failed).Count -eq 0) { Ok 'a dispositioned entry does not count against the exit code' } else { Bad ("dispositioned entries counted as failures: " + (@($pay4.failed) -join ', ')) }

        # =================================================================
        # F. a missing extract REFUSES every rendered arm, by name
        # =================================================================
        $inNo = $in.Clone(); $inNo['DocTexts'] = @()
        $pNo = New-GateInvocationPlan -In $inNo
        foreach ($armName in @('figures-rendered', 'withhold-rendered', 'coverage-rendered')) {
            $a = @($pNo | Where-Object { $_.Name -eq $armName })
            if ($a.Count -eq 1 -and $a[0].Refused -and $a[0].Refused -match 'guide_gate\.txt' -and $a[0].Refused -match 'deck_gate\.txt') {
                Ok ("{0}: REFUSED by name when no extract exists (the refusal names guide_gate.txt and deck_gate.txt)" -f $armName)
            }
            else { Bad ("{0} was not refused by name without an extract: '{1}'" -f $armName, $(if ($a.Count) { $a[0].Refused } else { '(absent from the plan)' })) }
        }
        $rrNo = Invoke-GatePlan -Plan @(@($pNo | Where-Object { $_.Name -eq 'figures-rendered' })) -SkillDir $SkillDir -TimeoutSeconds 5
        if (@($rrNo).Count -eq 1 -and -not @($rrNo)[0].Ok -and @($rrNo)[0].Refused) { Ok 'a refused rendered arm is a FAILURE in the results, never a skip' } else { Bad 'refused rendered arm did not fail the run' }

        # =================================================================
        # G. arm rosters: a blocking arm that never ran fails the member AND
        #    the band, naming both
        # =================================================================
        $armText = "some gate output`nARMS: source|true|ran|12|0;rendered|true|not-run|0|0"
        $ar = New-GateResult -Name 'figures-rendered' -Ok $true -Text $armText -Error '' -ExitCode 0 -Seconds 1 -GateSeconds 1 -Refused $false -Reason ''
        $ar = Add-ArmRosterToResult -Result $ar -Evidence '7c'
        if (-not $ar.Ok -and $ar.Reason -match 'arm not run: rendered' -and @($ar.Arms).Count -eq 2) {
            Ok 'PLANT: a blocking arm in state not-run turns a member that exited 0 into a FAILURE naming the arm'
        }
        else { Bad ("arm roster: ok={0} reason='{1}' arms={2}" -f $ar.Ok, $ar.Reason, @($ar.Arms).Count) }
        $fakePlan = @([pscustomobject]@{ Name = 'figures-rendered'; Gate = 'Test-FigureConsistency'; Title = 't'; Script = 's'; Kind = 'script'; Phase = 3; Stage = '7c'; Args = [ordered]@{}; Wanted = @(); Dropped = @(); Must = @(); Produces = ''; Refused = $null; Disposition = ''; Why = ''; Header = ([pscustomobject]@{ Found = $false; Raw = '' }); Reports = @() })
        $bandFail = Get-BandFailure -Plan $fakePlan -Results @($ar)
        if ($bandFail -contains 'figures-rendered') { Ok 'PLANT: the band FAILS naming the member whose blocking arm never ran' } else { Bad 'the band did not fail on the not-run arm' }
        $payArm = New-ResultPayload -Plan $fakePlan -Results @($ar) -Meta @{
            Stage = '7c'; StartedAt = $runStart.ToString('o'); BuildDir = $build; SpineDir = $spineDir; Guide = ''; Deck = ''
            AfterArtwork = $true; SkipDeck = $false; AllowPartial = $false; SpineFingerprint = 'v2:x'; BandFingerprint = 'v2:x'
            Inputs = $null; Artefacts = @(); Seconds = 1; ExitCode = 1; Fixtures = $null; PlanOmissions = @(); Proof = $null
        }
        if (@($payArm.gates)[0].armsBlockingNotRun -contains 'rendered' -and @($payArm.failed) -contains 'figures-rendered') {
            Ok 'the results file records the member, the arm and the band failure together'
        }
        else { Bad 'the results file does not record the not-run arm against the member' }
        $armOk = New-GateResult -Name 'clean' -Ok $true -Text "ARMS: source|true|ran|12|0;rendered|true|declared-n-a|0|0" -Error '' -ExitCode 0 -Seconds 1 -GateSeconds 1 -Refused $false -Reason ''
        $armOk = Add-ArmRosterToResult -Result $armOk -Evidence '7c'
        if ($armOk.Ok -and @($armOk.ArmsBlockingNotRun).Count -eq 0) { Ok 'CONTROL: a blocking arm declared not applicable is not a not-run arm, and the clean member still passes' }
        else { Bad ("control member failed: reason='{0}'" -f $armOk.Reason) }
        $armBadCell = New-GateResult -Name 'bad' -Ok $true -Text "ARMS: source|true|ran" -Error '' -ExitCode 0 -Seconds 1 -GateSeconds 1 -Refused $false -Reason ''
        $armBadCell = Add-ArmRosterToResult -Result $armBadCell -Evidence '7c'
        if (-not $armBadCell.Ok -and @($armBadCell.ArmProblems).Count -eq 1) { Ok 'an ARMS cell that does not parse is a problem naming the cell and the member fails, so an arm cannot vanish by being printed badly' }
        else { Bad 'an unparsable ARMS cell was tolerated' }
        #  PLANT: the human summary line every gate also prints must NOT be
        #  read as a roster. Read case-insensitively it was, and six passing
        #  gates were reported as printing an unparseable ARMS cell on a real
        #  band run. Run-SpineGates carries the identical case.
        $armCase = New-GateResult -Name 'human-line' -Ok $true -Text "  arms: 4 registered, 2 blocking, all complete`nARMS: a|true|ran|1|0" -Error '' -ExitCode 0 -Seconds 1 -GateSeconds 1 -Refused $false -Reason ''
        $armCase = Add-ArmRosterToResult -Result $armCase -Evidence '7c'
        if ($armCase.Ok -and @($armCase.Arms).Count -eq 1 -and "$($armCase.Arms[0].name)" -eq 'a' -and @($armCase.ArmProblems).Count -eq 0) { Ok "the roster line is read case-sensitively: the human 'arms: 4 registered, 2 blocking' line is not a roster and manufactures no problem" }
        else { Bad ("case-sensitive ARMS: arms={0} problems={1}" -f @($armCase.Arms).Count, (@($armCase.ArmProblems) -join ' | ')) }

        # =================================================================
        # H. the grid disposition reads only THIS run's reports
        # =================================================================
        $prodPlan = @(
            [pscustomobject]@{ Name = 'shape-mirror'; Produces = (Join-Path $build 'shape-mirror-report.json') }
            [pscustomobject]@{ Name = 'row-coverage'; Produces = (Join-Path $build 'row-coverage-report.json') }
            [pscustomobject]@{ Name = 'mirror';       Produces = (Join-Path $build 'figure-mirror-report.json') }
        )
        foreach ($e in $prodPlan) { [System.IO.File]::WriteAllText($e.Produces, '{}', $utf8) }
        $prodOk = @(
            (New-GateResult -Name 'shape-mirror' -Ok $true  -Text '' -Error '' -ExitCode 0 -Seconds 1 -GateSeconds 1 -Refused $false -Reason '')
            (New-GateResult -Name 'row-coverage' -Ok $false -Text '' -Error '' -ExitCode 1 -Seconds 1 -GateSeconds 1 -Refused $false -Reason 'exit code 1')
            (New-GateResult -Name 'mirror'       -Ok $true  -Text '' -Error '' -ExitCode 0 -Seconds 1 -GateSeconds 1 -Refused $false -Reason '')
        )
        $bar = (Get-Item -LiteralPath $prodPlan[0].Produces).LastWriteTimeUtc.AddMinutes(-1)
        $dp = Test-DisposalPrerequisite -Plan $prodPlan -Results $prodOk -Producer @('shape-mirror', 'row-coverage', 'mirror') -NotBefore $bar
        if ($dp.Ok) { Ok 'CONTROL: a producer that exited 1 with a report written THIS run still feeds the disposition' } else { Bad ("control disposal blocked: " + ($dp.Problems -join '; ')) }
        # ---- PLANT 1: a producer that threw
        $prodThrew = @($prodOk | ForEach-Object { $_ })
        $prodThrew[2] = New-GateResult -Name 'mirror' -Ok $false -Text '' -Error 'timed out after 5 s - job stopped' -ExitCode $null -Seconds 5 -GateSeconds 0 -Refused $false -Reason 'timed out'
        $dp2 = Test-DisposalPrerequisite -Plan $prodPlan -Results $prodThrew -Producer @('shape-mirror', 'row-coverage', 'mirror') -NotBefore $bar
        if (-not $dp2.Ok -and ($dp2.Problems -join ' ') -match 'mirror') { Ok 'PLANT: a producer that timed out makes the disposition NOT RUN, named by producer' } else { Bad 'a timed-out producer did not stop the disposition' }
        # ---- PLANT 2: a report left by an EARLIER run
        $dp3 = Test-DisposalPrerequisite -Plan $prodPlan -Results $prodOk -Producer @('shape-mirror', 'row-coverage', 'mirror') -NotBefore (Get-Date).ToUniversalTime().AddHours(1)
        if (-not $dp3.Ok -and ($dp3.Problems -join ' ') -match 'BEFORE this run started') { Ok "PLANT: a report older than the runner's start is named as an earlier round's, not read" } else { Bad 'a stale report was accepted' }
        # ---- PLANT 3: a producer that wrote nothing
        Remove-Item -LiteralPath $prodPlan[1].Produces -Force
        $dp4 = Test-DisposalPrerequisite -Plan $prodPlan -Results $prodOk -Producer @('shape-mirror', 'row-coverage', 'mirror') -NotBefore $bar
        if (-not $dp4.Ok -and ($dp4.Problems -join ' ') -match 'row-coverage wrote no report') { Ok 'PLANT: a producer that wrote no report FAILS by name and the disposition is skipped' } else { Bad 'a missing report was not named' }
        [System.IO.File]::WriteAllText($prodPlan[1].Produces, '{}', $utf8)

        # ---- and the plan threads -NotBefore, -ReportPath and -Produces
        $gd = @($p7 | Where-Object { $_.Name -eq 'grid-disposal' })[0]
        if ($gd.Must -contains 'NotBefore') { Ok 'grid disposal REQUIRES -NotBefore: a copy of the gate that cannot take it is refused, never run blind' } else { Bad 'grid disposal does not require -NotBefore' }
        if ($gd.Refused) { Write-Host ("        note: this copy of Test-GridDisposition is refused - {0}" -f $gd.Refused) -ForegroundColor DarkYellow }

        # =================================================================
        # I. the same plan against STUB gates that accept everything
        # =================================================================
        $stubSkill = Join-Path $tmp 'stubskill'
        $stubScripts = Join-Path $stubSkill 'scripts'
        New-Item -ItemType Directory -Force -Path $stubScripts | Out-Null
        $wantByScript = @{}
        foreach ($e in @($p7)) {
            if ($e.Kind -ne 'script' -or -not $e.Script) { continue }
            $leaf = Split-Path $e.Script -Leaf
            if (-not $wantByScript.ContainsKey($leaf)) { $wantByScript[$leaf] = New-Object System.Collections.Generic.List[string] }
            foreach ($w in @($e.Wanted)) { if (-not $wantByScript[$leaf].Contains([string]$w)) { $wantByScript[$leaf].Add([string]$w) } }
        }
        foreach ($leaf in $wantByScript.Keys) {
            $ps = @($wantByScript[$leaf]) | ForEach-Object { '$' + $_ }
            $body = "param(" + ($ps -join ', ') + ")`r`n" +
                    "foreach (`$k in @('ReportPath','OutPath','Produces')) { if (`$PSBoundParameters.ContainsKey(`$k)) { `$v = [string]`$PSBoundParameters[`$k]; if (`$v) { [System.IO.File]::WriteAllText(`$v, '{}') } } }`r`n" +
                    "Write-Host 'ARMS: only|true|ran|1|0'`r`nexit 0`r`n"
            [System.IO.File]::WriteAllText((Join-Path $stubScripts $leaf), $body, $utf8b)
        }
        [System.IO.File]::WriteAllText((Join-Path $stubScripts 'Lib-Resolve.ps1'), "# stub`r`n", $utf8b)
        $inStub = $in.Clone()
        $inStub['SkillDir'] = $stubSkill
        $inStub['MirrorScript'] = (Join-Path $stubScripts 'Check-FigureMirror.ps1')
        $inStub['LeakageScript'] = (Join-Path $stubScripts 'Check-FigureLeakage.ps1')
        $pStub = New-GateInvocationPlan -In $inStub
        $stubRefused = @($pStub | Where-Object { $_.Refused })
        if ($stubRefused.Count -eq 0) { Ok 'against a copy of every gate that declares what the runner threads, NOTHING in the plan is refused - every refusal above is a missing input, never a plan defect' }
        else { Bad ("stub plan still refuses: " + ((@($stubRefused | ForEach-Object { $_.Name + ' (' + $_.Refused + ')' })) -join '; ')) }
        $gdS = @($pStub | Where-Object { $_.Name -eq 'grid-disposal' })[0]
        if ($gdS.Args.Contains('NotBefore') -and ([datetime]$gdS.Args['NotBefore']) -eq $runStart) { Ok "grid disposal is threaded -NotBefore equal to the runner's start" }
        else { Bad ("grid disposal -NotBefore: " + (Format-ArgValue $gdS.Args['NotBefore'])) }
        foreach ($prod in @('shape-mirror', 'row-coverage', 'mirror')) {
            $pe = @($pStub | Where-Object { $_.Name -eq $prod })[0]
            $rp = [string]$pe.Args['ReportPath']; $pr = [string]$pe.Args['Produces']
            if ($rp -and $pr -and $rp -eq $pr -and $pe.Produces -eq $rp) { Ok ("{0} is threaded -ReportPath and -Produces naming ONE file, and the runner asserts that file was written" -f $prod) }
            else { Bad ("{0}: ReportPath='{1}' Produces='{2}' entry.Produces='{3}'" -f $prod, $rp, $pr, $pe.Produces) }
        }
        $gdRead = @($gdS.Args['ShapeReport'], $gdS.Args['CoverageReport'], $gdS.Args['MirrorReport'])
        $prodWrites = @(@('shape-mirror', 'row-coverage', 'mirror') | ForEach-Object { $n = $_; [string](@($pStub | Where-Object { $_.Name -eq $n })[0]).Produces })
        $mismatch = @($prodWrites | Where-Object { $gdRead -notcontains $_ })
        if ($mismatch.Count -eq 0) { Ok 'the disposition is handed exactly the three files its producers were told to write' } else { Bad ("the disposition reads different files from those the producers write: " + ($mismatch -join ', ')) }

        # =================================================================
        # J. the entry refusal: a spine edited after the band
        # =================================================================
        $fpNow = Get-SpineFingerprint -BuildDir $build -SpineDir $spineDir -Quiet
        [System.IO.File]::WriteAllText((Join-Path $build '3c-results.json'), (([pscustomobject]@{ runner = 'Run-SpineGates'; stage = '3c'; partial = $false; verdict = 'PASS'; ranAt = $runStart.ToString('o'); spineFingerprint = $fpNow }) | ConvertTo-Json -Depth 6), $utf8)
        $bf = Test-BandFingerprint -BuildDir $build -SpineDir $spineDir -Quiet
        if ($bf.Ok) { Ok 'CONTROL: a spine whose fingerprint matches the newest FULL 3c results passes the entry check' } else { Bad ("control band check failed: " + $bf.Reason) }
        # ---- PLANT: touch a spine file after the band was cut
        [System.IO.File]::WriteAllText((Join-Path $spineDir 't1_1.1.json'), '{ "topic": 1, "visuals": [], "edited": true }', $utf8)
        $fpAfter = Get-SpineFingerprint -BuildDir $build -SpineDir $spineDir -Quiet
        $bf2 = Test-BandFingerprint -BuildDir $build -SpineDir $spineDir -Quiet
        if (-not $bf2.Ok -and $bf2.Reason -match [regex]::Escape($fpNow) -and $bf2.Reason -match [regex]::Escape($fpAfter)) {
            Ok 'PLANT: a spine file edited after the newest 3c results REFUSES the run, naming both fingerprints, before any phase'
        }
        else { Bad ("spine-moved refusal: ok={0} reason='{1}'" -f $bf2.Ok, $bf2.Reason) }
        $bf3 = Test-BandFingerprint -BuildDir $tmp -SpineDir (Join-Path $tmp 'nospine') -Quiet
        if (-not $bf3.Ok) { Ok 'a build with no spine is a refusal, not a pass on an empty hash' } else { Bad 'a missing spine passed the entry check' }
        # ---- a PARTIAL 3c file is not the band
        [System.IO.File]::WriteAllText((Join-Path $build '3c-results.json'), (([pscustomobject]@{ runner = 'Run-SpineGates'; stage = '3c'; partial = $true; verdict = 'PARTIAL'; spineFingerprint = $fpAfter }) | ConvertTo-Json -Depth 6), $utf8)
        $bf4 = Test-BandFingerprint -BuildDir $build -SpineDir $spineDir -Quiet
        if (-not $bf4.Ok -and $bf4.Reason -match 'PARTIAL') { Ok 'a -Only run''s partial 3c results cannot stand as the band this runner gates against' } else { Bad 'a partial band file was accepted' }
        [System.IO.File]::WriteAllText((Join-Path $build '3c-results.json'), (([pscustomobject]@{ runner = 'Run-SpineGates'; stage = '3c'; partial = $false; verdict = 'PASS'; spineFingerprint = $fpAfter }) | ConvertTo-Json -Depth 6), $utf8)

        # =================================================================
        # K. the figure sheet must describe THIS spine
        # =================================================================
        $sheet = Join-Path $build 'figure-sheet.txt'
        [System.IO.File]::WriteAllText($sheet, ("FIGURE SHEET`r`nSPINE-FINGERPRINT: {0}`r`n" -f $fpAfter), $utf8)
        $fs1 = Test-FigureSheetCurrent -BuildDir $build -SpineDir $spineDir -SheetPath $sheet
        if ($fs1.Ok) { Ok 'CONTROL: a figure sheet stamped with this spine passes the in-process check' } else { Bad ("control figure sheet failed: " + $fs1.Text) }
        [System.IO.File]::WriteAllText($sheet, ("FIGURE SHEET`r`nSPINE-FINGERPRINT: {0}`r`n" -f $fpNow), $utf8)
        $fs2 = Test-FigureSheetCurrent -BuildDir $build -SpineDir $spineDir -SheetPath $sheet
        if (-not $fs2.Ok -and $fs2.Text -match [regex]::Escape($fpNow) -and $fs2.Text -match [regex]::Escape($fpAfter)) { Ok 'PLANT: a figure sheet cut from an older spine FAILS naming the sheet and both fingerprints' }
        else { Bad ("stale figure sheet: ok={0} text='{1}'" -f $fs2.Ok, $fs2.Text) }
        Remove-Item -LiteralPath $sheet -Force
        $fs3 = Test-FigureSheetCurrent -BuildDir $build -SpineDir $spineDir -SheetPath $sheet
        if (-not $fs3.Ok -and $fs3.Text -match 'no figure sheet') { Ok 'an absent figure sheet is a failure naming the file, never a skip' } else { Bad 'an absent figure sheet did not fail' }

        # =================================================================
        # L. -RequireFresh: a delivered artefact newer than the gates
        # =================================================================
        $outDir = Join-Path $build 'out'
        New-Item -ItemType Directory -Force -Path $outDir | Out-Null
        $fGuide = Join-Path $outDir 'X_Learner_Guide.docx'
        [System.IO.File]::WriteAllText($fGuide, 'guide bytes', $utf8)
        $gSha = Get-FileSha256 -Path $fGuide
        $tGate = (Get-Date).ToUniversalTime()
        (Get-Item -LiteralPath $fGuide).LastWriteTimeUtc = $tGate.AddMinutes(-10)
        $freshJson = [pscustomobject]@{
            runner = 'Run-Gates'; stage = '7c'; verdict = 'pass'; startedAt = $tGate.AddMinutes(-5).ToString('o'); ranAt = $tGate.ToString('o')
            artefacts = @([pscustomobject]@{ path = $fGuide; sha256 = $gSha; lastWriteUtc = $tGate.AddMinutes(-10).ToString('o') })
        }
        [System.IO.File]::WriteAllText((Join-Path $build '7c-results.json'), ($freshJson | ConvertTo-Json -Depth 6), $utf8)
        $fr1 = Test-DeliveredFreshness -BuildDir $build -Artefact @($fGuide)
        if ($fr1.Ok) { Ok 'CONTROL: an artefact written before the gates that judge it, whose sha256 still matches, is fresh' } else { Bad ("control freshness: " + ($fr1.Problems -join '; ')) }
        # ---- PLANT: rewrite one byte after the gates
        [System.IO.File]::WriteAllText($fGuide, 'guide bytes rewritten after the gates', $utf8)
        (Get-Item -LiteralPath $fGuide).LastWriteTimeUtc = $tGate.AddMinutes(10)
        $fr2 = Test-DeliveredFreshness -BuildDir $build -Artefact @($fGuide)
        if (-not $fr2.Ok -and ($fr2.Problems -join ' ') -match 'X_Learner_Guide\.docx' -and ($fr2.Problems -join ' ') -match 'AFTER the gates') {
            Ok 'PLANT: an artefact written AFTER its judging results file is refused, naming the artefact and both times'
        }
        else { Bad ("freshness plant: ok={0} problems='{1}'" -f $fr2.Ok, ($fr2.Problems -join '; ')) }

        # =================================================================
        # M. the leakage gate, pass-through arguments and the job wrapper
        # =================================================================
        Remove-Item -LiteralPath $unitX -Force
        $pNoUnit = New-GateInvocationPlan -In $in
        $lk = @($pNoUnit | Where-Object { $_.Name -eq 'leakage' })[0]
        if ($lk.Refused -and $lk.Refused -match 'unit_extract\.md') { Ok 'the leakage gate is refused, naming unit_extract.md, when the extract is absent' } else { Bad "leakage not refused: '$($lk.Refused)'" }
        [System.IO.File]::WriteAllText($unitX, 'Performance Evidence', $utf8)
        $in3 = $in.Clone(); $in3['LeakageArgs'] = @{ Shingle = 15; MinWords = 15 }
        $lk3 = @((New-GateInvocationPlan -In $in3) | Where-Object { $_.Name -eq 'leakage' })[0]
        if (-not $lk3.Refused -and $lk3.Args['Shingle'] -eq 15 -and $lk3.Args['MinWords'] -eq 15) { Ok 'pass-through arguments the gate declares are merged and printed' } else { Bad "pass-through not merged: refused='$($lk3.Refused)'" }
        $in5 = $in.Clone(); $in5['LeakageArgs'] = @{ NoSuchParameter = 1 }
        $lk4 = @((New-GateInvocationPlan -In $in5) | Where-Object { $_.Name -eq 'leakage' })[0]
        if ($lk4.Refused -and $lk4.Refused -match 'NoSuchParameter') { Ok 'a pass-through argument the gate does not declare REFUSES the gate rather than being dropped' } else { Bad 'unknown pass-through not refused' }

        $stub = Join-Path $tmp 'stub_gate.ps1'
        [System.IO.File]::WriteAllText($stub, "param([string] `$BuildDir)`r`nWrite-Host 'X planted failure'`r`nexit 1`r`n", $utf8b)
        #  READ THE PLANT BACK BEFORE ASSERTING ANYTHING ABOUT IT. A stub never
        #  written, or written without its marker, makes the check below prove
        #  nothing while still printing PASS.
        if (-not (Test-Path -LiteralPath $stub)) { Bad 'the planted failing stub was never written' }
        elseif ([System.IO.File]::ReadAllText($stub).IndexOf('X planted failure', [System.StringComparison]::Ordinal) -lt 0) { Bad 'the planted failing stub does not carry its marker' }
        else { Ok 'the planted failing stub was read back and carries its marker' }
        $se = [pscustomobject]@{ Name = 'stub'; Kind = 'script'; Title = 'stub'; Script = $stub; Gate = 'stub'; Phase = 1; Stage = '7c'; Args = @{ BuildDir = $build }; Wanted = @('BuildDir'); Dropped = @(); Must = @(); Produces = $null; Refused = $null; Disposition = ''; Why = ''; Header = ([pscustomobject]@{ Found = $false; Raw = '' }); Reports = @() }
        $sr = Invoke-GatePlan -Plan @($se) -SkillDir $stubSkill -TimeoutSeconds 120
        if (@($sr).Count -eq 1 -and -not @($sr)[0].Ok -and @($sr)[0].Text -match 'planted failure' -and @($sr)[0].ExitCode -eq 1) { Ok 'the job wrapper captures a gate script''s text and its non-zero exit code as a failure' } else { Bad ("job wrapper: ok=$(@($sr)[0].Ok) code=$(@($sr)[0].ExitCode) text='$(@($sr)[0].Text)' err='$(@($sr)[0].Error)'") }
        if (@($sr)[0].StartedAt -match '^\d{4}-\d{2}-\d{2}T' -and @($sr)[0].RanAt -match '^\d{4}-\d{2}-\d{2}T') { Ok 'every member carries its own startedAt and ranAt, so a per-gate time is never the results file''s write time' } else { Bad 'a member has no startedAt/ranAt of its own' }
        $stub2 = Join-Path $tmp 'stub_slow.ps1'
        [System.IO.File]::WriteAllText($stub2, "param([string] `$BuildDir)`r`nStart-Sleep -Seconds 60`r`nexit 0`r`n", $utf8b)
        if (-not (Test-Path -LiteralPath $stub2)) { Bad 'the planted slow stub was never written' }
        elseif ([System.IO.File]::ReadAllText($stub2).IndexOf('Start-Sleep', [System.StringComparison]::Ordinal) -lt 0) { Bad 'the planted slow stub does not carry its sleep' }
        else { Ok 'the planted slow stub was read back and carries its sleep' }
        $se2 = [pscustomobject]@{ Name = 'slow'; Kind = 'script'; Title = 'slow'; Script = $stub2; Gate = 'slow'; Phase = 1; Stage = '7c'; Args = @{ BuildDir = $build }; Wanted = @('BuildDir'); Dropped = @(); Must = @(); Produces = $null; Refused = $null; Disposition = ''; Why = ''; Header = ([pscustomobject]@{ Found = $false; Raw = '' }); Reports = @() }
        $sr2 = Invoke-GatePlan -Plan @($se2) -SkillDir $stubSkill -TimeoutSeconds 3
        if (@($sr2).Count -eq 1 -and -not @($sr2)[0].Ok -and @($sr2)[0].Error -match 'timed out') { Ok 'a gate that overruns the timeout is stopped and reported as a failure' } else { Bad ("timeout: ok=$(@($sr2)[0].Ok) err='$(@($sr2)[0].Error)'") }
        $stub3 = Join-Path $tmp 'stub_nowrite.ps1'
        [System.IO.File]::WriteAllText($stub3, "param([string] `$BuildDir)`r`nWrite-Host 'wrote nothing'`r`nexit 0`r`n", $utf8b)
        $se3 = [pscustomobject]@{ Name = 'nowrite'; Kind = 'script'; Title = 'nowrite'; Script = $stub3; Gate = 'nowrite'; Phase = 1; Stage = '7c'; Args = @{ BuildDir = $build }; Wanted = @('BuildDir'); Dropped = @(); Must = @(); Produces = (Join-Path $tmp 'never-written.json'); Refused = $null; Disposition = ''; Why = ''; Header = ([pscustomobject]@{ Found = $false; Raw = '' }); Reports = @() }
        $sr3 = Invoke-GatePlan -Plan @($se3) -SkillDir $stubSkill -TimeoutSeconds 60
        if (-not @($sr3)[0].Ok -and @($sr3)[0].Text -match 'expected output not written') { Ok 'PLANT: a producer that exits 0 having written nothing is a FAILURE naming the file it owed' } else { Bad 'a producer that wrote nothing passed' }

        # =================================================================
        # N. fixture proof is a report, and an unproven member is named
        # =================================================================
        $fxDir = Join-Path $build 'fx'
        New-Item -ItemType Directory -Force -Path $fxDir | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $fxDir 'gate-fixtures.abc123.json'), (([pscustomobject]@{ checkedAt = $runStart.ToString('o'); results = @([pscustomobject]@{ Gate = 'Check-Identity'; Verdict = 'PROVEN' }, [pscustomobject]@{ Gate = 'Check-ShapeMirror'; Verdict = 'UNPROVEN' }) }) | ConvertTo-Json -Depth 6), $utf8)
        $proof = Get-FixtureProof -BuildDir $build
        if ($proof.Found -and $proof.Hash -eq 'abc123') { Ok 'the newest hash-stamped fixtures report is found and its hash read' } else { Bad ("fixtures report: found={0} hash='{1}'" -f $proof.Found, $proof.Hash) }
        if ((Get-MemberProofNote -Proof $proof -Name 'Check-Identity') -eq 'PROVEN' -and (Get-MemberProofNote -Proof $proof -Name 'Check-ShapeMirror') -match 'UNPROVEN' -and (Get-MemberProofNote -Proof $proof -Name 'Check-RowCoverage') -match 'not in the fixtures report') {
            Ok 'UNPROVEN is printed beside every member the newest fixtures report did not prove, and a member absent from it is UNPROVEN too'
        }
        else { Bad 'the fixture proof note is wrong for at least one member' }
        $sf = Get-ScriptsFingerprint -ScriptsDir $stubScripts
        if ($sf.Hash -and $sf.Count -gt 0 -and $sf.NewestName) { Ok ("the plant channel key is derived from the {0} script(s) on disk, newest {1}" -f $sf.Count, $sf.NewestName) } else { Bad 'the scripts fingerprint could not be computed' }

        # =================================================================
        # O. the fixtures static arm is a band member
        # =================================================================
        $fx = @($p7 | Where-Object { $_.Name -eq 'fixtures-static' })
        if ($fx.Count -eq 1 -and ($fx[0].Refused -or $fx[0].Args.Contains('StaticOnly'))) { Ok 'Assert-GateFixtures -StaticOnly is a phase-1 member of this band' } else { Bad 'the static fixtures arm is not a band member' }
    }
    finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }

    Write-Host ''
    Write-Host ("  {0} passed, {1} failed" -f $pass, $fail) -ForegroundColor $(if ($fail) { 'Red' } else { 'Green' })
    if ($fail) { exit 4 }
    exit 0
}

# ---------------------------------------------------------------------------
# 7. Resolve every input - parameters first, then the contract, then discovery
# ---------------------------------------------------------------------------

if (-not $BuildDir) { Write-Host 'Run-Gates: -BuildDir is required (or -SelfTest).' -ForegroundColor Red; exit 2 }
if (-not (Test-Path -LiteralPath $BuildDir)) { Write-Host "Run-Gates: no build directory at $BuildDir" -ForegroundColor Red; exit 2 }
$BuildDir = (Resolve-Path -LiteralPath $BuildDir).Path
$SkillDir = (Resolve-Path -LiteralPath $SkillDir).Path
$scriptsDir = Join-Path $SkillDir 'scripts'
if (-not $SpineDir) { $SpineDir = Join-Path $BuildDir 'spine' }
$startedAtUtc = (Get-Date).ToUniversalTime()

# ---------------------------------------------------------------------------
# 7a. -RequireFresh (Stage 8): a refusal, not a run. No gate is started and
#     nothing is written - this asks one question about what is already there.
# ---------------------------------------------------------------------------

if ($RequireFresh) {
    $outDir8 = Join-Path $BuildDir 'out'
    $arts8 = @()
    foreach ($p in @($Guide, $Deck)) { if ($p -and (Test-Path -LiteralPath $p)) { $arts8 += (Resolve-Path -LiteralPath $p).Path } }
    if ($arts8.Count -eq 0 -and (Test-Path -LiteralPath $outDir8)) {
        $arts8 = @(Get-ChildItem -LiteralPath $outDir8 -File | Where-Object { $_.Extension -in @('.docx', '.pptx') -and $_.Name -notlike '~$*' } | ForEach-Object { $_.FullName })
    }
    Write-Host ''
    Write-Host ("RUN-GATES -RequireFresh  {0}  {1} delivered artefact(s)" -f $BuildDir, $arts8.Count) -ForegroundColor Cyan
    if ($arts8.Count -eq 0) {
        Write-Host ("  X no delivered artefact under {0}. A freshness assertion with no artefact would pass by having nothing to date the gates against." -f $outDir8) -ForegroundColor Red
        exit 2
    }
    $fresh = Test-DeliveredFreshness -BuildDir $BuildDir -Artefact $arts8
    foreach ($l in @($fresh.Lines)) { Write-Host ("  " + $l) -ForegroundColor DarkGray }
    foreach ($p in @($fresh.Problems)) { Write-Host ("  X " + $p) -ForegroundColor Red }
    if ($fresh.Ok) { Write-Host '  DELIVERY IS FRESH - every artefact was judged by a passing results file it has not changed since' -ForegroundColor Green; exit 0 }
    Write-Host '  REFUSED: the delivery is not fresh. Re-run the gates over what is on disk now.' -ForegroundColor Red
    exit 2
}

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

# ---------------------------------------------------------------------------
# 7b. THE ENTRY REFUSAL, before a single gate is planned. A spine edited after
#     the band was cut has been gated against no valid band.
# ---------------------------------------------------------------------------

$band = Test-BandFingerprint -BuildDir $BuildDir -SpineDir $SpineDir -Quiet
if (-not $band.Ok) {
    Write-Host ''
    Write-Host ("RUN-GATES REFUSED (stage {0}) - nothing was run" -f (Get-StageKey -AfterArtwork ([bool]$AfterArtwork))) -ForegroundColor Red
    Write-Host ("  X {0}" -f $band.Reason) -ForegroundColor Red
    Write-Host ("  spine now:  {0}" -f $(if ($band.Current) { $band.Current } else { '(none)' })) -ForegroundColor Red
    Write-Host ("  band says:  {0}" -f $(if ($band.Stamped) { $band.Stamped } else { '(no stamp)' })) -ForegroundColor Red
    Write-Host ("  band file:  {0}" -f $band.BandPath) -ForegroundColor DarkGray
    exit 2
}
$derived.Add(("spine fingerprint {0} matches the newest full 3c band ({1}, ran {2})" -f $band.Current, $band.BandVerdict, $band.BandRanAt))

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

$stageKey  = Get-StageKey -AfterArtwork ([bool]$AfterArtwork)
$guideText = Join-Path $BuildDir 'guide_gate.txt'
$deckText  = Join-Path $BuildDir 'deck_gate.txt'
if (-not $ResultPath) { $ResultPath = Get-DefaultResultPath -BuildDir $BuildDir -AfterArtwork ([bool]$AfterArtwork) }
$derived.Add(("results file: {0} (stage {1})" -f (Split-Path $ResultPath -Leaf), $stageKey))

Write-Host ''
Write-Host ("RUN-GATES  {0}  brand {1}/{2}  {3}" -f $UnitCode, $Brand, $Variant, $(if ($AfterArtwork) { 'AFTER ARTWORK (Stage 7c)' } else { 'before artwork (Stage 4)' })) -ForegroundColor Cyan
Write-Host ("  pack references derived: {0} part-level, {1} task-level, {2} observation, {3} distinct" -f $refs.Part.Count, $refs.Task.Count, $refs.Observation.Count, $refs.All.Count) -ForegroundColor DarkGray
foreach ($d in $derived) { Write-Host ("  derived: {0}" -f $d) -ForegroundColor DarkGray }

$inputs = @{
    BuildDir = $BuildDir; SkillDir = $SkillDir; SpineDir = $SpineDir; PackDir = $PackDir
    Guide = $Guide; Deck = $Deck
    PackRefs = $refs.All; QuestionPattern = $qp; AfterArtwork = [bool]$AfterArtwork; AllowPartial = [bool]$AllowPartial
    TemplatePath = $templatePath; Plan = $plan; NumberSlotByLayout = $numberSlotMap
    Rto = $Rto; Cricos = $Cricos; Brand = $Brand; Variant = $Variant; UnitExtract = $UnitExtract
    MirrorScript = $MirrorScript; LeakageScript = $LeakageScript
    MirrorArgs = $MirrorArgs; LeakageArgs = $LeakageArgs
    GuideText = $guideText; DeckText = $deckText; DocTexts = @(); SkipDeck = [bool]$SkipDeck
    ShapeReport = (Join-Path $BuildDir 'shape-mirror-report.json')
    CoverageReport = (Join-Path $BuildDir 'row-coverage-report.json')
    MirrorReport = (Join-Path $BuildDir 'figure-mirror-report.json')
    FigureSheet = (Join-Path $BuildDir 'figure-sheet.txt')
    ResultDir = $BuildDir; StartedAt = $startedAtUtc
}

# ---------------------------------------------------------------------------
# 8. Run, one phase at a time
# ---------------------------------------------------------------------------

$rc = 0
$timeout = $TimeoutMinutes * 60
$sw = [System.Diagnostics.Stopwatch]::StartNew()

$planA = New-GateInvocationPlan -In $inputs

#  EVERY GATE THE DOCUMENTS PROMISE. The set is read off the gates' own
#  headers at run time; a member of this stage that the plan does not run is a
#  FAIL naming it, because a stage that lists a gate nobody ran is the false
#  green this runner exists to prevent.
$omissions = @(Get-PlanOmission -Plan $planA -ScriptsDir $scriptsDir -Stage $stageKey)

$phase1 = @($planA | Where-Object { $_.Phase -eq $script:PhaseFanOut })
Write-Host ''
Write-Host ("  phase 1: {0} gate(s) {1}; {2} recorded without running" -f `
    @($phase1 | Where-Object { -not $_.Refused -and -not $_.Disposition }).Count, `
    $(if ($Serial) { 'one at a time' } else { 'in parallel' }), `
    @($phase1 | Where-Object { $_.Disposition }).Count) -ForegroundColor DarkGray
$res1 = Invoke-GatePlan -Plan $phase1 -SkillDir $SkillDir -TimeoutSeconds $timeout -Serial:$Serial -Evidence $stageKey

# ---- the extracts this run actually produced
$docTexts = @()
foreach ($pair in @(@{ N = 'extract-guide'; P = $guideText }, @{ N = 'extract-deck'; P = $deckText })) {
    $made = @($res1 | Where-Object { $_.Name -eq $pair.N -and $_.Ok })
    if ($made.Count -eq 1 -and (Test-Path -LiteralPath $pair.P)) { $docTexts += $pair.P }
}
$inputs['DocTexts'] = $docTexts
$planB = New-GateInvocationPlan -In $inputs
$allPlan = @($phase1) + @($planB | Where-Object { $_.Phase -ne $script:PhaseFanOut })
$allRes = New-Object System.Collections.Generic.List[object]
foreach ($r in $res1) { $allRes.Add($r) }

# ---- phase 2: the grid disposition, and only on THIS run's reports
$phase2 = @($allPlan | Where-Object { $_.Phase -eq $script:PhaseDisposal })
$producers = @('shape-mirror', 'row-coverage', 'mirror')
$pre = Test-DisposalPrerequisite -Plan $phase1 -Results $res1 -Producer $producers -NotBefore $startedAtUtc
if (-not $pre.Ok) {
    foreach ($e in $phase2) {
        if ($e.Disposition) { continue }
        $e.Refused = ("the reports this gate reads are not this run's: {0}. A disposition read from an earlier round's reports describes an earlier round." -f (@($pre.Problems) -join '; '))
    }
}
Write-Host ("  phase 2: {0} gate(s) on this run's producer reports{1}" -f @($phase2 | Where-Object { -not $_.Refused -and -not $_.Disposition }).Count, $(if ($pre.Ok) { '' } else { ' - SKIPPED, see below' })) -ForegroundColor DarkGray
$res2 = Invoke-GatePlan -Plan $phase2 -SkillDir $SkillDir -TimeoutSeconds $timeout -Serial:$Serial -Evidence $stageKey
foreach ($r in $res2) { $allRes.Add($r) }

# ---- phase 3: the gates that read the extracts
$phase3 = @($allPlan | Where-Object { $_.Phase -eq $script:PhaseExtract })
Write-Host ("  phase 3: {0} gate(s) on {1} extract(s)" -f @($phase3 | Where-Object { -not $_.Refused -and -not $_.Disposition }).Count, $docTexts.Count) -ForegroundColor DarkGray
$res3 = Invoke-GatePlan -Plan $phase3 -SkillDir $SkillDir -TimeoutSeconds $timeout -Serial:$Serial -Evidence $stageKey
foreach ($r in $res3) { $allRes.Add($r) }

# ---------------------------------------------------------------------------
# 9. One summary, one results file, one exit code
# ---------------------------------------------------------------------------

$proof = Get-FixtureProof -BuildDir $BuildDir
$unproven = @()

foreach ($e in $allPlan) {
    $rr = @($allRes | Where-Object { $_.Name -eq $e.Name })
    if ($rr.Count -eq 0) { continue }
    $r = $rr[0]
    $verdict = Get-GateVerdict -Entry $e -Result $r
    $note = Get-MemberProofNote -Proof $proof -Name ([string]$e.Gate)
    if ($note -like 'UNPROVEN*') { $unproven += $e.Name }
    Write-Host ''
    $col = switch ($verdict) { 'PASS' { 'Green' } 'FAIL' { 'Red' } 'REFUSED' { 'Red' } default { 'Yellow' } }
    Write-Host ("{0}  [{1}]  {2}s  phase {3}  fixtures: {4}" -f $e.Title, $verdict, $r.Seconds, $e.Phase, $note) -ForegroundColor $col
    if ($e.Disposition) { Write-Host ("    {0}: {1}" -f $e.Disposition, $e.Why) -ForegroundColor Yellow; continue }
    if (-not $r.Ok) { $rc = 1 }
    if ($r.Error) { Write-Host ("    X {0}" -f $r.Error) -ForegroundColor Red }
    Write-GateText -Text $r.Text
    foreach ($p in @($e.Reports)) { Write-Host ("    ! {0}" -f $p) -ForegroundColor Yellow }
    foreach ($p in @($r.ArmProblems)) { Write-Host ("    ! {0}" -f $p) -ForegroundColor Yellow }
    if (@($r.ArmsBlockingNotRun).Count -gt 0) {
        Write-Host ("    X blocking arm(s) that never ran: {0} - a gate that skipped its own rule cannot report green" -f (@($r.ArmsBlockingNotRun) -join ', ')) -ForegroundColor Red
    }
    if (@($r.Partial).Count -gt 0) {
        Write-Host ("    PARTIAL RUN - rules that checked nothing: {0}" -f (@($r.Partial) -join '; ')) -ForegroundColor Magenta
    }
}

if ($omissions.Count -gt 0) {
    $rc = 1
    Write-Host ''
    Write-Host ("X {0} gate(s) declare themselves stage-{1} members and this runner's plan does not run them:" -f $omissions.Count, $stageKey) -ForegroundColor Red
    foreach ($o in $omissions) { Write-Host ("    {0}  [{1}]  {2}" -f $o.Gate, $o.Header, $o.Path) -ForegroundColor Red }
    Write-Host '    Add the entry to New-GateInvocationPlan or correct the header. A stage that lists a gate nobody ran is a false green.' -ForegroundColor Red
}

Write-Host ''
Write-Host 'PARAMETERS THREADED TO EVERY GATE - nothing below was left to a default the gate would have failed on' -ForegroundColor Cyan
foreach ($ln in (Get-ThreadedParameterLine -Plan $allPlan)) {
    $col = if ($ln -match 'NOT RUN') { 'Red' } elseif ($ln -match 'dropped') { 'Yellow' } else { 'DarkGray' }
    Write-Host ("  " + $ln) -ForegroundColor $col
}

Write-Host ''
Write-Host ("  fixtures: {0}" -f $proof.Note) -ForegroundColor $(if ($proof.Found) { 'DarkGray' } else { 'Yellow' })
if ($unproven.Count -gt 0) { Write-Host ("  UNPROVEN by the fixtures report: {0}" -f (($unproven | Sort-Object -Unique) -join ', ')) -ForegroundColor Yellow }

# ---- the full plant channel, started and never waited for
$plantNote = 'not started'
$sfp = Get-ScriptsFingerprint -ScriptsDir $scriptsDir
if ($SkipPlantChannel) { $plantNote = 'not started: -SkipPlantChannel' }
elseif ($proof.Found -and $null -ne $sfp.NewestUtc -and (Get-Item -LiteralPath $proof.Path).LastWriteTimeUtc -gt $sfp.NewestUtc) {
    $plantNote = ("current: {0} is newer than the newest script ({1}), so its verdicts are about these scripts" -f (Split-Path $proof.Path -Leaf), $sfp.NewestName)
}
else {
    #  A DETACHED PROCESS, not Start-Job: a job dies with this runner, and a
    #  channel that never survives its own launcher is a channel that silently
    #  never runs. Nothing waits for it and nothing here reads its result -
    #  the NEXT run reads the report it leaves.
    try {
        $fxScript = Join-Path $scriptsDir 'Assert-GateFixtures.ps1'
        if (-not (Test-Path -LiteralPath $fxScript)) { throw "no Assert-GateFixtures.ps1 at $fxScript" }
        $cmd = ("& '{0}' -SkillDir '{1}' -BuildDir '{2}' -ResultDir '{3}' -Quiet" -f $fxScript, $SkillDir, $BuildDir, $BuildDir)
        $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-Command', $cmd) -WindowStyle Hidden -PassThru
        $plantNote = ("started: pid {0}, scripts hash {1} over {2} file(s); nothing waits for it and the next run reads gate-fixtures.<hash>.json" -f $proc.Id, $sfp.Hash.Substring(0, [Math]::Min(12, $sfp.Hash.Length)), $sfp.Count)
    }
    catch { $plantNote = ("NOT started: {0}. The static arm still ran as a band member; the full plant channel did not." -f $_.Exception.Message) }
}
Write-Host ("  plant channel: {0}" -f $plantNote) -ForegroundColor DarkGray

# ---- the results file
$payload = New-ResultPayload -Plan $allPlan -Results $allRes.ToArray() -Meta @{
    Stage = $stageKey; StartedAt = $startedAtUtc.ToString('o'); BuildDir = $BuildDir; SpineDir = $SpineDir
    Guide = $Guide; Deck = $Deck; AfterArtwork = [bool]$AfterArtwork; SkipDeck = [bool]$SkipDeck; AllowPartial = [bool]$AllowPartial
    SpineFingerprint = $band.Current; BandFingerprint = $band.Stamped
    Inputs = (Get-InputHash -BuildDir $BuildDir)
    Artefacts = (Get-ArtefactStamp -Path @(@($Guide, $Deck) | Where-Object { $_ }))
    Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    ExitCode = $rc
    Fixtures = ([pscustomobject]@{ report = $proof.Path; hash = $proof.Hash; found = [bool]$proof.Found; note = $proof.Note; unproven = @($unproven | Sort-Object -Unique); scriptsHash = $sfp.Hash; plantChannel = $plantNote })
    PlanOmissions = @($omissions | ForEach-Object { [pscustomobject]@{ gate = $_.Gate; header = $_.Header; path = $_.Path } })
    Proof = $proof
}
$wroteResults = $false
try {
    [System.IO.File]::WriteAllText($ResultPath, ($payload | ConvertTo-Json -Depth 100), (New-Object System.Text.UTF8Encoding($false)))
    $wroteResults = (Test-Path -LiteralPath $ResultPath)
    if ($wroteResults) { Write-Host ("results written to {0} ({1} gate(s), {2} recorded without running)" -f $ResultPath, @($payload.gates).Count, @($payload.partial).Count) -ForegroundColor DarkGray }
}
catch {
    Write-Host ("X could not write {0}: {1}" -f $ResultPath, $_.Exception.Message) -ForegroundColor Red
}
if (-not $wroteResults) {
    #  A verdict that exists only in a terminal cannot be re-read by the stage
    #  that must prove the gates postdate the last mutation. A failed write is
    #  a FAILED RUN, not a warning under a green line.
    Write-Host ("X the results file was not written, so nothing on disk dates these gates. The run FAILS on that alone.") -ForegroundColor Red
    $rc = 1
}

$failed = @($payload.failed)
Write-Host ''
if ($rc -eq 0) { Write-Host ("ALL GATES PASS  ({0} gate(s), {1} recorded without running, {2}s)" -f @($payload.gates).Count, @($payload.partial).Count, [int]$sw.Elapsed.TotalSeconds) -ForegroundColor Green }
else           { Write-Host ("GATES FAILED: {0}  ({1}s)" -f (($failed + @($omissions | ForEach-Object { 'plan omits ' + $_.Gate })) -join ', '), [int]$sw.Elapsed.TotalSeconds) -ForegroundColor Red }
exit $rc
