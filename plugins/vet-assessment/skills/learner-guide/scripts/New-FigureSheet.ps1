<#
    New-FigureSheet.ps1 - cut the FIGURE SHEET from the spine, stamped with the
    fingerprint of the spine it was cut from AND with the band verdict it was
    cut under.

    Run it from Run-SpineGates phase 3 - the only route that cuts it:

        & "$SkillDir\scripts\Run-SpineGates.ps1" -BuildDir $out

    The direct call exists for a re-cut after a spine edit and takes the same
    proof:

        & "$SkillDir\scripts\New-FigureSheet.ps1" -BuildDir $out -BandResults $out\3c-results.json

    WHAT THE SHEET IS FOR. A reviewer must be able to read what a figure SAYS
    whether or not a picture has been placed yet. Under the ordering this
    pipeline replaced, artwork was placed after the audits, so every pre-artwork
    round read a document in which every figure was still a prompt block - and
    the rule that was supposed to prevent that ("a diagram's labels live in its
    alt text, so a review that skips alt text has not read the figures") was
    guaranteed vacuous in every one of those rounds, because alt text only
    reaches the document at placement. The figures were first read at the third
    audit round, four hours after they were written, and that round returned Not
    Compliant. The sheet is what makes figure content readable from hour one.

    WHY IT IS GENERATED AND NOT WRITTEN. The sheet is a transcript, and a
    hand-assembled transcript is a second source of truth that drifts from the
    spine the moment either is edited. One build held its diagram content as
    hand-typed copies inside a spec-writer script; three rounds of spine
    corrections never touched them and the figures went on teaching a superseded
    calculation. So this dumps EVERY field of every visual node, rather than a
    list of field names somebody maintains - a channel added to the spine cannot
    go missing from the sheet by being forgotten here.

    WHY IT STAMPS A FINGERPRINT. The sheet travels with every later review pack
    and is what lets a Stage 5 or Stage 6 record count as having read the
    figures. Stage 7 edits the spine. A sheet nobody regenerated then hands a
    reviewer figure content the document no longer has, while the ledger records
    that the figures were read. Test-StageLedger recomputes the fingerprint and
    BLOCKS DELIVERY when it does not match, so a stale sheet cannot travel.

    WHY IT REFUSES TO CUT FROM A FAILED OR MOVED SPINE (P0-07). On the reference
    build the runner refused the cut because the band had failed - and the
    documented direct call cut the sheet 19 seconds later from that same failed
    spine, Stage 3d recorded it as cut, and the content the remediation was
    about to change travelled to every reviewer. So the decision is not the
    caller's: -BandResults names the band's results file (3c-results.json by
    default; Run-SpineGates hands over the interim 3c-band-verdict.json written
    at its own join), and this script refuses - exit 2, no file written - unless
    that file says verdict PASS, partial false, exitCode 0 and its spine
    fingerprint equals the fingerprint of the spine on disk RIGHT NOW. The
    refusal names the failed members and BOTH fingerprints.

    Every sheet carries BAND-VERDICT, BAND-RESULTS-SHA256 and BAND-RAN-AT, so a
    later reader (Test-FigureSheetCurrent) can tell a proven cut from a forced
    one without trusting a note. -Force exists for the operator who must read
    the figures of a spine that is failing, requires -ForceReason, and stamps
    BAND-VERDICT: FAIL - a forced sheet can never reach delivery.

    ZERO VISUALS IS A REFUSAL, NOT A SHEET (P0-07). A sheet that says "no
    visuals were found" is evidence of nothing and was, on one build, filed as
    the figure evidence for a guide whose visuals were written under a field
    name no reader looks for. The check-set goes through Write-GateCheckSet
    -Blocking, which refuses an empty set by name.

    PS 5.1. ASCII only in this file.
    Exit 0 written, 2 refused (no build, no spine, no band results, a band that
    did not pass, a spine that moved, an empty visual set, -Force without
    -ForceReason), 4 the self-test failed.
#>
# GATE: stages=3c; requires=BuildDir,BandResults

[CmdletBinding()]
param(
    [string] $BuildDir,
    [string] $SpineDir,
    [string] $OutPath,
    #  The band's results file, which is the PROOF the spine passed. Default
    #  <BuildDir>\3c-results.json; Run-SpineGates passes the interim
    #  3c-band-verdict.json it writes at the join, before phase 3.
    [string] $BandResults,
    #  Cut anyway. Requires -ForceReason and stamps BAND-VERDICT: FAIL.
    [switch] $Force,
    [string] $ForceReason,
    [switch] $Quiet,
    [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

$GATE = 'FIGURE SHEET'
$script:Self = $PSCommandPath
if (-not $script:Self) { $script:Self = $MyInvocation.MyCommand.Path }

function Get-FileSha256 {
    <# Lower-case hex sha256 of a file's bytes, '' when the file is absent. #>
    param([Parameter(Mandatory)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path).Path))).Replace('-', '').ToLowerInvariant()) }
    finally { $sha.Dispose() }
}

function Get-Prop {
    param($Object, [string] $Name)
    if ($null -eq $Object -or $null -eq $Object.PSObject) { return $null }
    if (@($Object.PSObject.Properties.Name) -contains $Name) { return $Object.$Name }
    return $null
}

# ---------------------------------------------------------------------------
# The band decision - one function, so the self-test can plant a results file
# and read the verdict back without cutting anything.
# ---------------------------------------------------------------------------

function Test-BandGreen {
    <#  Read the band results file and say whether this spine may be cut from.

        Returns Ok, Problems[] (each one a sentence naming a file, a member or
        a fingerprint), Verdict, ExitCode, Partial, Failed[], RanAt, Sha and
        Expected/Actual fingerprints. Nothing here writes or exits: the caller
        maps Ok=false to exit 2, and -Force to a FAIL stamp.

        An ABSENT or unreadable file is a problem, never a pass: a blocking
        rule whose input is missing fails naming the input.  #>
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][AllowEmptyString()][string] $Fingerprint
    )
    $out = [pscustomobject]@{
        Ok = $false; Problems = @(); Path = $Path; Sha = ''; RanAt = ''
        Verdict = ''; ExitCode = $null; Partial = $null; Failed = @()
        Expected = ''; Actual = $Fingerprint; Found = $false
    }
    $problems = @()
    if (-not $Path) {
        $out.Problems = @('no -BandResults path was resolved. The sheet is cut only from a band that passed, so the results file that says so is a required input.')
        return $out
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        $out.Problems = @(("no band results file at {0}. Run the band (Run-SpineGates -BuildDir <build>) and cut the sheet from its phase 3; a sheet cut with no verdict on disk proves nothing about the spine it came from." -f $Path))
        return $out
    }
    $out.Found = $true
    $out.Sha = Get-FileSha256 -Path $Path
    $json = $null
    try {
        $text = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path, [System.Text.Encoding]::UTF8)
        $text = $text.TrimStart([char]0xFEFF)
        if ($text.Trim()) { $json = $text | ConvertFrom-Json }
    }
    catch { $json = $null }
    if ($null -eq $json) {
        $out.Problems = @(("the band results file does not parse as JSON: {0}" -f $Path))
        return $out
    }

    $out.Verdict = [string](Get-Prop $json 'verdict')
    $out.RanAt = [string](Get-Prop $json 'ranAt')
    $out.Expected = [string](Get-Prop $json 'spineFingerprint')
    $ec = Get-Prop $json 'exitCode'
    $out.ExitCode = $ec
    $partial = Get-Prop $json 'partial'
    $out.Partial = $partial
    $failed = @()
    foreach ($f in @(Get-Prop $json 'failed')) { if ($null -ne $f -and "$f" -ne '') { $failed += [string]$f } }
    $out.Failed = @($failed)

    if ($out.Verdict -ne 'PASS') {
        $problems += ("the band did not pass: {0} says verdict '{1}'{2}" -f (Split-Path $Path -Leaf), $(if ($out.Verdict) { $out.Verdict } else { '(no verdict recorded)' }), $(if ($failed.Count) { (' - failed member(s): ' + ($failed -join ', ')) } else { '' }))
    }
    if ($null -eq $ec -or [string]$ec -ne '0') {
        $problems += ("the band's exit code is {0}, not 0 ({1})" -f $(if ($null -eq $ec) { '(not recorded)' } else { [string]$ec }), (Split-Path $Path -Leaf))
    }
    if ($partial -ne $false) {
        $problems += ("the band results are partial ({0} says partial={1}). A -Only run cannot stand as the band's evidence and never cuts the sheet." -f (Split-Path $Path -Leaf), $(if ($null -eq $partial) { '(not recorded)' } else { [string]$partial }))
    }
    if (-not $out.Expected) {
        $problems += ("{0} records no spineFingerprint, so nothing proves those verdicts describe the spine on disk." -f (Split-Path $Path -Leaf))
    }
    elseif (-not $Fingerprint) {
        $problems += ("the spine on disk has no fingerprint (no spine file to hash); the band judged {0}." -f $out.Expected)
    }
    elseif ($out.Expected -ne $Fingerprint) {
        $problems += ("the spine MOVED after the band ran: the band judged fingerprint {0}, the spine on disk is {1}. Every verdict in {2} describes a spine that no longer exists - re-run the band." -f $out.Expected, $Fingerprint, (Split-Path $Path -Leaf))
    }

    $out.Problems = @($problems)
    $out.Ok = ($problems.Count -eq 0)
    return $out
}

# ---------------------------------------------------------------------------
# Dump a node EXHAUSTIVELY. Nothing here names a field, so nothing here can
# forget one.
# ---------------------------------------------------------------------------

function Add-NodeLine {
    param(
        [Parameter(Mandatory)] $Node,
        [Parameter(Mandatory)] $Lines,
        [string] $Path = '',
        [int] $Depth = 0
    )

    if ($null -eq $Node) { return }
    if ($Depth -gt 12) { $Lines.Add(("  {0}: [deeper than 12 levels - not dumped]" -f $Path)); return }

    if ($Node -is [string] -or $Node -is [ValueType]) {
        $v = "$Node".Trim()
        if ($v) { $Lines.Add(("  {0}: {1}" -f $Path, $v)) }
        return
    }

    if ($Node -is [System.Collections.IEnumerable]) {
        $i = 0
        foreach ($item in $Node) {
            Add-NodeLine -Node $item -Lines $Lines -Path ("{0}[{1}]" -f $Path, $i) -Depth ($Depth + 1)
            $i++
        }
        return
    }

    foreach ($p in @($Node.PSObject.Properties)) {
        if ($p.Name -like '_*') { continue }        # commentary, not content
        $child = if ($Path) { "$Path.$($p.Name)" } else { $p.Name }
        Add-NodeLine -Node $p.Value -Lines $Lines -Path $child -Depth ($Depth + 1)
    }
}

# ---------------------------------------------------------------------------
# Self-test - synthetic spine, planted band results, no build needed
# ---------------------------------------------------------------------------

if ($SelfTest) {
    $pass = 0; $fail = 0
    function Ok  ($m) { $script:pass++; Write-Host "  PASS  $m" -ForegroundColor Green }
    function Bad ($m) { $script:fail++; Write-Host "  FAIL  $m" -ForegroundColor Red }

    Write-Host ''
    Write-Host 'New-FigureSheet self-test' -ForegroundColor Cyan
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('figsheet_selftest_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $build = Join-Path $tmp 'build'
    $spine = Join-Path $build 'spine'
    New-Item -ItemType Directory -Force -Path $spine | Out-Null
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $bom  = New-Object System.Text.UTF8Encoding($true)
    $sheet = Join-Path $build 'figure-sheet.txt'
    $bandPath = Join-Path $build '3c-results.json'

    function Stamp { param([string] $Key) if (-not (Test-Path -LiteralPath $sheet)) { return '' }; foreach ($ln in [System.IO.File]::ReadAllLines($sheet)) { if ($ln -match ('^' + [regex]::Escape($Key) + ':\s*(.*)$')) { return $Matches[1].Trim() } }; return '' }
    function Write-Band {
        param([string] $Verdict, [string] $Fp, [int] $ExitCode = 0, [bool] $Partial = $false, [string[]] $Failed = @(), [string] $Path = $bandPath)
        $b = [ordered]@{ runner = 'Run-SpineGates'; stage = '3c'; kind = 'band-verdict'; ranAt = '2026-09-08T01:02:03.4567890Z'; spineFingerprint = $Fp; verdict = $Verdict; exitCode = $ExitCode; partial = $Partial; failed = @($Failed) }
        [System.IO.File]::WriteAllText($Path, (([pscustomobject]$b) | ConvertTo-Json -Depth 10), $bom)
    }
    function Run-Sheet {
        #  A HASHTABLE splat, never an array: array splatting binds
        #  positionally in PS 5.1, so '-BuildDir' lands IN -BuildDir and every
        #  assertion below would be made against a usage error.
        param([hashtable] $Arguments)
        if (Test-Path -LiteralPath $sheet) { Remove-Item -LiteralPath $sheet -Force }
        $global:LASTEXITCODE = 0
        $out = @(& $script:Self @Arguments 6>&1 2>&1 | ForEach-Object { if ($_ -is [System.Management.Automation.InformationRecord]) { [string]$_.MessageData } else { "$_" } })
        return [pscustomobject]@{ Code = $global:LASTEXITCODE; Text = ($out -join "`n"); Sheet = (Test-Path -LiteralPath $sheet) }
    }

    try {
        [System.IO.File]::WriteAllText((Join-Path $spine 't1_1.1.json'), '{"pc":"1.1","visuals":[{"slot":"1.1.1","kind":"photo","caption":"A caption","alt":"An alt","prompt":"PLANTED-VISUAL-CONTENT"}]}', $utf8)
        [System.IO.File]::WriteAllText((Join-Path $spine 't1_topic.json'), '{"topic":1}', $utf8)
        [System.IO.File]::WriteAllText((Join-Path $spine 'cover.json'), '{"visual":{"slot":"cover","kind":"photo","caption":"Cover caption","alt":"Cover alt"}}', $utf8)
        $fp = Get-SpineFingerprint -BuildDir $build -SpineDir $spine -Quiet
        if ($fp -match '^v2:[0-9a-f]{32}$') { Ok ("the spine fingerprint is v2-prefixed and content-derived ({0})" -f $fp) } else { Bad "fingerprint '$fp'" }

        #  ---- the decision function, before anything is cut
        Write-Band -Verdict 'PASS' -Fp $fp
        $d = Test-BandGreen -Path $bandPath -Fingerprint $fp
        if ($d.Ok -and $d.RanAt -and $d.Sha) { Ok 'a PASS band file over the same spine is green, with its ranAt and sha256 read' } else { Bad ("clean decision: " + (@($d.Problems) -join ' | ')) }
        Write-Band -Verdict 'FAIL' -Fp $fp -ExitCode 1 -Failed @('Assert-SpineCounts', 'Test-SubSection')
        if ((Get-Content -LiteralPath $bandPath -Raw) -notmatch 'Assert-SpineCounts') { Bad 'the planted FAIL band file was not written' }
        $d = Test-BandGreen -Path $bandPath -Fingerprint $fp
        if (-not $d.Ok -and (@($d.Problems) -join ' ') -match 'Assert-SpineCounts, Test-SubSection') { Ok 'a FAIL band file is refused, naming every failed member' } else { Bad ("fail decision: " + (@($d.Problems) -join ' | ')) }
        Write-Band -Verdict 'PASS' -Fp 'v2:00000000000000000000000000000000'
        $d = Test-BandGreen -Path $bandPath -Fingerprint $fp
        if (-not $d.Ok -and (@($d.Problems) -join ' ') -match 'v2:00000000000000000000000000000000' -and (@($d.Problems) -join ' ') -match [regex]::Escape($fp)) { Ok 'a band that judged another spine is refused, naming BOTH fingerprints' } else { Bad ("moved decision: " + (@($d.Problems) -join ' | ')) }
        Write-Band -Verdict 'PASS' -Fp $fp -Partial $true
        $d = Test-BandGreen -Path $bandPath -Fingerprint $fp
        if (-not $d.Ok -and (@($d.Problems) -join ' ') -match 'partial') { Ok 'a partial band file is refused by name' } else { Bad ("partial decision: " + (@($d.Problems) -join ' | ')) }
        $d = Test-BandGreen -Path (Join-Path $build 'no-such-results.json') -Fingerprint $fp
        if (-not $d.Ok -and (@($d.Problems) -join ' ') -match 'no-such-results\.json') { Ok 'an ABSENT band results file is refused naming the file - never read as "not yet judged"' } else { Bad ("absent decision: " + (@($d.Problems) -join ' | ')) }

        #  ---- the whole script, as a child call
        Write-Band -Verdict 'PASS' -Fp $fp
        $r = Run-Sheet -Arguments @{ BuildDir = $build; BandResults = $bandPath; Quiet = $true }
        $sha = Get-FileSha256 -Path $bandPath
        if ($r.Code -eq 0 -and $r.Sheet) { Ok 'a green band cuts the sheet, exit 0' } else { Bad ("green cut: exit $($r.Code) sheet=$($r.Sheet): " + $r.Text) }
        if ((Stamp 'BAND-VERDICT') -eq 'PASS' -and (Stamp 'SPINE-FINGERPRINT') -eq $fp -and (Stamp 'BAND-RESULTS-SHA256') -eq $sha -and (Stamp 'BAND-RAN-AT') -eq '2026-09-08T01:02:03.4567890Z') { Ok 'and it is stamped BAND-VERDICT PASS, BAND-RESULTS-SHA256, BAND-RAN-AT and the spine fingerprint' } else { Bad ("stamps: bv='{0}' fp='{1}' sha='{2}' ran='{3}'" -f (Stamp 'BAND-VERDICT'), (Stamp 'SPINE-FINGERPRINT'), (Stamp 'BAND-RESULTS-SHA256'), (Stamp 'BAND-RAN-AT')) }
        if ((Get-Content -LiteralPath $sheet -Raw) -match 'PLANTED-VISUAL-CONTENT' -and (Get-Content -LiteralPath $sheet -Raw) -match 'spine file: cover\.json') { Ok 'the sheet carries every field of every visual, the cover included' } else { Bad 'the sheet is missing the planted visual field or the cover row' }

        Write-Band -Verdict 'FAIL' -Fp $fp -ExitCode 1 -Failed @('Assert-SpineCounts')
        $r = Run-Sheet -Arguments @{ BuildDir = $build; BandResults = $bandPath; Quiet = $true }
        if ($r.Code -eq 2 -and -not $r.Sheet -and $r.Text -match 'Assert-SpineCounts') { Ok 'a FAIL results file makes the direct call exit 2 with NO sheet written, naming the failed member' } else { Bad ("fail cut: exit $($r.Code) sheet=$($r.Sheet): " + $r.Text) }

        $r = Run-Sheet -Arguments @{ BuildDir = $build; BandResults = $bandPath; Force = $true; Quiet = $true }
        if ($r.Code -eq 2 -and -not $r.Sheet -and $r.Text -match 'ForceReason') { Ok '-Force without -ForceReason is refused by name, and cuts nothing' } else { Bad ("force without reason: exit $($r.Code) sheet=$($r.Sheet): " + $r.Text) }

        $r = Run-Sheet -Arguments @{ BuildDir = $build; BandResults = $bandPath; Force = $true; ForceReason = 'reading the figures of a failing spine'; Quiet = $true }
        if ($r.Code -eq 0 -and $r.Sheet -and (Stamp 'BAND-VERDICT') -eq 'FAIL' -and (Stamp 'BAND-FORCED') -match 'reading the figures') { Ok '-Force -ForceReason cuts a sheet stamped BAND-VERDICT: FAIL with the reason - it can never reach delivery' } else { Bad ("forced cut: exit $($r.Code) bv='$(Stamp 'BAND-VERDICT')' forced='$(Stamp 'BAND-FORCED')'") }

        #  ---- zero visuals: exit 2, no sheet, even with a green band
        $noVis = Join-Path $tmp 'build2'
        $noVisSpine = Join-Path $noVis 'spine'
        New-Item -ItemType Directory -Force -Path $noVisSpine | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $noVisSpine 't1_1.1.json'), '{"pc":"1.1","underpinningKnowledge":"no visuals here"}', $utf8)
        $fp2 = Get-SpineFingerprint -BuildDir $noVis -SpineDir $noVisSpine -Quiet
        $band2 = Join-Path $noVis '3c-results.json'
        Write-Band -Verdict 'PASS' -Fp $fp2 -Path $band2
        $sheet2 = Join-Path $noVis 'figure-sheet.txt'
        $global:LASTEXITCODE = 0
        $txt2 = @(& $script:Self -BuildDir $noVis -BandResults $band2 -Quiet 6>&1 2>&1 | ForEach-Object { if ($_ -is [System.Management.Automation.InformationRecord]) { [string]$_.MessageData } else { "$_" } }) -join "`n"
        $code2 = $global:LASTEXITCODE
        if ($code2 -eq 2 -and -not (Test-Path -LiteralPath $sheet2) -and $txt2 -match 'CHECK-SET EMPTY') { Ok 'a spine with no visual entries is a CHECK-SET EMPTY refusal (exit 2) and NO sheet - never a sheet that says "none found"' } else { Bad ("zero visuals: exit $code2 sheet=$(Test-Path -LiteralPath $sheet2): $txt2") }

        #  ---- a forced cut cannot launder an empty check-set either
        $global:LASTEXITCODE = 0
        $txt3 = @(& $script:Self -BuildDir $noVis -BandResults $band2 -Force -ForceReason 'x' -Quiet 6>&1 2>&1 | ForEach-Object { if ($_ -is [System.Management.Automation.InformationRecord]) { [string]$_.MessageData } else { "$_" } }) -join "`n"
        $code3 = $global:LASTEXITCODE
        if ($code3 -eq 2 -and -not (Test-Path -LiteralPath $sheet2)) { Ok '-Force does not launder an empty visual set: still exit 2, still no sheet' } else { Bad ("forced zero visuals: exit $code3 sheet=$(Test-Path -LiteralPath $sheet2)") }

        #  ---- no -BandResults value at all: the default is named, not defaulted away
        $bare = Join-Path $tmp 'build3'
        New-Item -ItemType Directory -Force -Path (Join-Path $bare 'spine') | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $bare 'spine\t1_1.1.json'), '{"pc":"1.1","visuals":[{"slot":"1.1.1"}]}', $utf8)
        $global:LASTEXITCODE = 0
        $txt4 = @(& $script:Self -BuildDir $bare -Quiet 6>&1 2>&1 | ForEach-Object { if ($_ -is [System.Management.Automation.InformationRecord]) { [string]$_.MessageData } else { "$_" } }) -join "`n"
        $code4 = $global:LASTEXITCODE
        if ($code4 -eq 2 -and $txt4 -match '3c-results\.json' -and -not (Test-Path -LiteralPath (Join-Path $bare 'figure-sheet.txt'))) { Ok 'with no band results on disk the default path is named in the refusal and nothing is cut' } else { Bad ("bare build: exit $code4 : $txt4") }
    }
    finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }

    Write-Host ''
    Write-Host ("  {0} passed, {1} failed" -f $pass, $fail) -ForegroundColor $(if ($fail) { 'Red' } else { 'Green' })
    if ($fail) { exit 4 }
    exit 0
}

# ---------------------------------------------------------------------------
# Resolve every input
# ---------------------------------------------------------------------------

if (-not $BuildDir) { Write-Host "$GATE`: -BuildDir is required (or -SelfTest)." -ForegroundColor Red; exit 2 }
if (-not (Test-Path -LiteralPath $BuildDir)) { Write-Host "$GATE`: no build directory at $BuildDir" -ForegroundColor Red; exit 2 }
$BuildDir = (Resolve-Path -LiteralPath $BuildDir).Path
if (-not $SpineDir) { $SpineDir = Join-Path $BuildDir 'spine' }
if (-not (Test-Path -LiteralPath $SpineDir)) {
    Write-Host "$GATE`: no spine at $SpineDir. The sheet is cut from the spine, not from the rendered document - the content is machine-readable JSON hours before a picture exists." -ForegroundColor Red
    exit 2
}
if (-not $OutPath) { $OutPath = Join-Path $BuildDir 'figure-sheet.txt' }
if (-not $BandResults) { $BandResults = Join-Path $BuildDir '3c-results.json' }
if ($Force -and -not $ForceReason) {
    Write-Host ''
    Write-Host "$GATE`: REFUSED - -Force requires -ForceReason." -ForegroundColor Red
    Write-Host '  A forced sheet is stamped BAND-VERDICT: FAIL and can never reach delivery, so the reason it was' -ForegroundColor Red
    Write-Host '  cut travels with it. Pass -ForceReason "<why this spine had to be read while it was failing>".' -ForegroundColor Red
    exit 2
}

$print = Get-SpineFingerprint -BuildDir $BuildDir -SpineDir $SpineDir -Quiet
$band = Test-BandGreen -Path $BandResults -Fingerprint $print

if (-not $band.Ok) {
    Write-Host ''
    Write-Host ("$GATE" + ": " + $(if ($Force) { 'FORCED over a band that did not pass' } else { 'REFUSED - the sheet is never cut from a spine that failed or moved' })) -ForegroundColor Red
    foreach ($p in @($band.Problems)) { Write-Host ("  X {0}" -f $p) -ForegroundColor Red }
    Write-Host ("  band results:      {0}" -f $BandResults) -ForegroundColor DarkGray
    Write-Host ("  band fingerprint:  {0}" -f $(if ($band.Expected) { $band.Expected } else { '(none recorded)' })) -ForegroundColor DarkGray
    Write-Host ("  spine fingerprint: {0}" -f $(if ($print) { $print } else { '(no spine to hash)' })) -ForegroundColor DarkGray
    if (-not $Force) {
        Write-Host '  Nothing was written. Fix the band and re-run Run-SpineGates, which cuts the sheet in its phase 3.' -ForegroundColor Red
        Write-Host '  To read the figures of a spine that is failing: -Force -ForceReason "<why>" - that sheet is stamped FAIL.' -ForegroundColor Yellow
        exit 2
    }
    Write-Host ("  -Force: {0}" -f $ForceReason) -ForegroundColor Yellow
    Write-Host '  The sheet will be stamped BAND-VERDICT: FAIL. Test-FigureSheetCurrent blocks delivery on it.' -ForegroundColor Yellow
}

#  A FORCED sheet is stamped FAIL whatever the band said. -Force is the switch
#  that lets a cut happen without a proof, so a sheet cut with it can never be
#  the proof - not even when the band happened to be green.
$stampVerdict = if ($band.Ok -and -not $Force) { 'PASS' } else { 'FAIL' }
if ($band.Ok -and $Force) {
    Write-Host ''
    Write-Host "$GATE`: -Force over a band that passed. The sheet is stamped BAND-VERDICT: FAIL anyway - a cut made without reading the proof is not the proof. Drop -Force to stamp PASS." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# Cut
# ---------------------------------------------------------------------------

$visuals = @(Get-GateSpineVisuals -BuildDir $BuildDir -SpineDir $SpineDir -IncludeFrontMatter)
$files   = @(Get-GateSpineFiles   -BuildDir $BuildDir -SpineDir $SpineDir -IncludeFrontMatter)

#  The visual set is the sheet's whole subject: an empty one is a refusal, by
#  name, not a sheet reporting its own emptiness. Write-GateCheckSet -Blocking
#  throws CHECK-SET EMPTY on 0 and the catch below maps it to exit 2.
try {
    Write-GateCheckSet -What 'visual slot(s)' -Count $visuals.Count -Blocking -Input ("the spine's visual entries in {0} ({1} file(s))" -f $SpineDir, $files.Count) -DerivedFrom ("Get-GateSpineVisuals over {0} spine file(s), front matter included" -f $files.Count)
}
catch {
    if ($_.Exception.Message -match '^CHECK-SET EMPTY') {
        Write-Host ''
        Write-Host ("$GATE`: REFUSED - {0}" -f $_.Exception.Message) -ForegroundColor Red
        Write-Host '  Either visual planning (Stage 3b) has not run, or the visuals were written under a field name no' -ForegroundColor Red
        Write-Host '  reader looks for. A sheet saying "no visuals found" is evidence of nothing and has been filed as' -ForegroundColor Red
        Write-Host '  figure evidence before now. Nothing was written.' -ForegroundColor Red
        exit 2
    }
    throw
}

$out = New-Object System.Collections.Generic.List[string]
$out.Add('FIGURE SHEET - every planned visual on the spine, as plain text')
$out.Add(("SPINE-FINGERPRINT: {0}" -f $print))
$out.Add(("BAND-VERDICT: {0}" -f $stampVerdict))
$out.Add(("BAND-RESULTS: {0}" -f $BandResults))
$out.Add(("BAND-RESULTS-SHA256: {0}" -f $band.Sha))
$out.Add(("BAND-RAN-AT: {0}" -f $band.RanAt))
if ($Force) { $out.Add(("BAND-FORCED: {0}" -f $ForceReason)) }
foreach ($p in @($band.Problems)) { $out.Add(("BAND-PROBLEM: {0}" -f $p)) }
$out.Add(("GENERATED: {0}" -f (Get-Date).ToUniversalTime().ToString('o')))
$out.Add(("SOURCE: {0} ({1} spine file(s))" -f $SpineDir, $files.Count))
$out.Add(("SLOTS: {0}" -f $visuals.Count))
$out.Add('')
if ($stampVerdict -ne 'PASS') {
    $out.Add('THIS SHEET WAS FORCED. The band it was cut under did not pass, so the content below may')
    $out.Add('be about to change. It is stamped BAND-VERDICT: FAIL and cannot count as figure evidence')
    $out.Add('for any stage record: Test-FigureSheetCurrent blocks delivery on it.')
    $out.Add('')
}
$out.Add('Read this as figure CONTENT, not as a manifest. Whether a picture has')
$out.Add('been placed yet says nothing about whether the figure is true, whether')
$out.Add('it matches its caption and alt text, or whether it hands a learner an')
$out.Add('assessed answer. Those are the three questions this sheet exists for.')
$out.Add('')

foreach ($v in ($visuals | Sort-Object { "$($_.Slot)" })) {
    $out.Add('-------------------------------------------------------------------')
    $out.Add(("SLOT {0}   kind: {1}   spine file: {2}" -f `
              $(if ($v.Slot) { $v.Slot } else { '(no slot declared)' }),
              $(if ($v.Kind) { $v.Kind } else { '(no kind declared)' }),
              $v.File))
    $out.Add('')
    Add-NodeLine -Node $v.Node -Lines $out
    $out.Add('')
}

[System.IO.File]::WriteAllText($OutPath, (($out -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))

if (-not $Quiet) {
    Write-Host ''
    Write-Host "$GATE" -ForegroundColor Cyan
    Write-Host ("  written: {0}" -f $OutPath) -ForegroundColor DarkGray
    Write-Host ("  spine fingerprint: {0}" -f $print) -ForegroundColor DarkGray
    Write-Host ("  band verdict:      {0} (from {1}, sha256 {2})" -f $stampVerdict, (Split-Path $BandResults -Leaf), $(if ($band.Sha) { $band.Sha.Substring(0, 12) } else { '(none)' })) -ForegroundColor $(if ($band.Ok) { 'DarkGray' } else { 'Red' })
    Write-Host '  It travels with every later review pack. Regenerate it after every spine edit -' -ForegroundColor Yellow
    Write-Host '  Test-StageLedger blocks delivery on a sheet cut from a spine that has moved on.' -ForegroundColor Yellow
    Write-Host ''
}

exit 0
