<#
    Assert-GateFixtures.ps1 - for every gate in this skill, prove that a
    planted defect of the kind it claims to catch makes it FAIL, and prove that
    THE PLANT LANDED before believing any of it.

    Implements the FIXTURES arm of gates.md section 35 and rule 2 at the top of
    that file.

    BOTH HALVES ARE LOAD-BEARING, AND THE SECOND ONE IS THE ONE THAT WAS MISSED.
    A build planted a defect into a slide that had no light fill to change. The
    plant did nothing. The gate reported clean. The clean report was recorded as
    evidence that the gate worked - and the same build then shipped 766 real
    crossover hits under a line that read "no crossover". So this harness reads
    the plant back out of the exact channel the gate scans, and a plant that did
    not land is reported as UNPROVEN, never as a pass.

    THE GATE LIST IS DERIVED, NEVER TYPED. It is the union of every .ps1 in the
    skill's scripts\ directory that can return a verdict, and every script named
    in the stage table of references\gates.md. A hand-listed check set is itself
    one of the recorded failure classes here: a builder read that table, recorded
    Stage 0 as `pass`, and had run two of its eight gates. The table's
    NOT YET IMPLEMENTED markers are read as CLAIMS and checked against the
    filesystem, because sibling builds add scripts to that directory while this
    runs and a stale marker is exactly the kind of second source of truth this
    skill keeps being bitten by.

    THREE PROOF CHANNELS, AND THEY ARE NOT INTERCHANGEABLE.

      PLANT   an external seeded-defect fixture built here: a lean copy of a
              real build, a defect written into it, the defect READ BACK, the
              gate run clean (must pass) and run planted (must fail, and its
              output must name the plant). This is the strong channel.
      SELFTEST the gate's own -SelfTest. Trusted only as far as it goes: this
              harness also reads the gate's source and reports whether its
              self-test VERIFIES ITS OWN PLANT LANDED. A self-test that plants
              and never checks the plant is the incident above, in miniature.
      REFUSAL run the gate with nothing, and with an empty build. A gate that
              exits 0 on no input is a gate whose green means nothing. This is
              the runtime form of the -DocText defect: an optional [string[]],
              `foreach ($p in @($DocText))` over $null, zero iterations, exit 0,
              and no rendered text gated at all.

    A FIXTURE MAY ONLY TEST A CLAIM THE GATE ACTUALLY MAKES. This harness
    shipped a first version that did not, and the result was a false HIGH at
    the top of its own work order. It planted an UNREGISTERED FIGURE into the
    registry gate and reported "the gate PASSED a verified plant of the defect
    it claims to catch" - but that gate never claimed it. Its header says it
    enforces a registry of forbidden and required values, and gates.md section
    17 says in as many words that an unregistered figure passes it today, which
    is the entire reason a separate coverage gate was written. The plant landed,
    the gate behaved correctly, and the harness called it a defect.

    That is worse than a human auditor being wrong, because it arrives with a
    table, a line number and an exit code, and it would have arrived on every
    future build. So the claim is now ESTABLISHED BEFORE THE PLANT IS BELIEVED:
    every recipe declares the claim it tests as a pattern that must be found in
    THE GATE'S OWN HEADER, and where the claim cannot be established the gate is
    reported UNPROVEN naming that reason. The harness may NEVER say a gate
    passed a plant of a defect whose claim it could not evidence. Any sentence
    in gates.md that mentions the gate and disclaims a capability is printed
    alongside, as evidence for the reader.

    A GATE THAT CANNOT BE PROVEN TO FAIL IS REPORTED AS UNPROVEN, WITH THE
    REASON, AND THAT IS A FINDING. It is never skipped silently and never
    counted as covered. gates.md rule 2 says a clean result from an unproven
    gate is a result not to trust yet; this harness is what makes that list
    visible instead of remembered.

    IT NEVER PRINTS WHAT A GATE PRINTED. Gate output is matched in memory and
    reported as a boolean and an exit code. Some of these gates sweep
    assessor-only material, and a fixtures report that quotes their output would
    leak the very thing they exist to keep out of a learner document.

    NOTHING IS HARD-CODED. No unit code, no brand, no RTO, no path. The build
    comes from -BuildDir, the identity from the profiles, the gate set from the
    filesystem.

    TWO MODES, AND THEY SIT ON DIFFERENT PATHS OF THE PIPELINE.

      -StaticOnly  no process is spawned. The gate set is derived, every
                   script is parsed, every '# GATE:' header is reconciled
                   against the stage table, every recipe is reconciled against
                   the disk, and a BLOCKING gate with neither a -SelfTest nor a
                   recipe here is a FAIL (the allow-list for libraries and
                   renderers sits beside that rule, with reasons). Seconds, so
                   it runs as a band member. Writes gate-fixtures.static.json.
      full         the plant channel, cut from a lean copy of -BuildDir. A
                   background job, never on the critical path. Writes
                   gate-fixtures.<hash>.json where <hash> is the sha256 of
                   scripts\*.ps1 plus the recipe set, stamped inside the file
                   so a reader can tell which scripts a verdict is about.

    WHAT DISCRIMINATION MEANS HERE, STATED ONCE. FailsOnPlant is true only when
    the planted run did not time out, exited non-zero, NAMED the plant, and
    the clean arm RAN and exited differently. The first version accepted "the
    plant run failed and named it" as discrimination, which is a tautology: a
    gate that dies in its parameter block exits 1 on clean and on planted, and
    its error text names the file it was handed. A needle is at least three
    characters and must be absent from the clean output; a removal plant has
    no needle to name, so its recipe declares an ExpectRx the failing output
    must match.

    PS 5.1. ASCII only in this file.

    Exit 0 every BLOCKING gate PROVEN (strict: plant landed, clean passed,
    plant failed and was named), 1 a blocking gate UNPROVEN or a FAIL row
    (orphan recipe, unparseable gate, no self-test and no recipe, no refusal
    on empty input), 2 usage or refusal, 3 PARTIAL RUN, 4 the self-test
    failed. Non-blocking and judgement-only rows are reported, never exit.
#>
#  This gate is a member of every band, as its STATIC arms only: the plant
#  channel is a separate, hash-keyed run and never sits on a band's critical
#  path. The three names a runner must thread are its skill directory, the
#  -StaticOnly switch that keeps it inside the band's budget, and the
#  directory its result file is written to.
# GATE: stages=0,1,2,3c,4,7c; requires=SkillDir,StaticOnly,ResultDir

[CmdletBinding()]
param(
    #  The skill whose gates are being proven.
    [string] $SkillDir,

    #  A REAL build directory, used read-only as the clean baseline that
    #  fixtures are cut from. Without it the PLANT channel cannot run, and this
    #  becomes a PARTIAL RUN that cannot stand for the fixtures gate.
    [string] $BuildDir,

    #  references\gates.md, if it is not where it usually is.
    [string] $GatesDoc,

    #  Where the result file is written. Defaults to -BuildDir when one is
    #  given, so the full channel's evidence lands beside the build it judged.
    [string] $ResultDir,

    #  Prove only these gates. A PARTIAL RUN: banner, exit 3, never 0.
    [string[]] $Only,

    #  Per-invocation ceiling. A gate that hangs is a FAIL naming the timeout,
    #  never a skip.
    [int] $TimeoutMinutes = 6,

    #  Enumerate the gate set and each gate's fixture cover, run nothing.
    [switch] $ListOnly,

    #  The static arms only: derivation, header reconciliation, recipe-vs-disk,
    #  parse check, self-test-or-recipe cover. No process is spawned. This is
    #  the band member; the plant channel is the background job.
    [switch] $StaticOnly,

    [switch] $SelfTest,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
$GATE = 'Assert-GateFixtures'

#  NO NESTED FULL RUN. This harness runs every gate in the skill, and it is
#  itself a gate in the skill, so a full run inside a full run enumerates the
#  set again and starts another one - once per level, forever. Measured: the
#  first real pass had spawned twenty-odd live processes before anyone looked.
#  A nested -SelfTest, -ListOnly or -StaticOnly is harmless and still allowed;
#  a nested full run REFUSES and says why, rather than being silently skipped.
$script:NestKey = 'LG_ASSERT_GATEFIXTURES_ACTIVE'
if (-not $SelfTest -and -not $ListOnly -and -not $StaticOnly) {
    $already = [System.Environment]::GetEnvironmentVariable($script:NestKey)
    if ($already) {
        Write-Host ("{0}: refusing a nested full run. A fixtures pass is already running in a parent process, and this harness proves every gate in the skill including itself, so a nested pass recurses without end. Run it once, at the top." -f $GATE) -ForegroundColor Yellow
        exit 2
    }
    [System.Environment]::SetEnvironmentVariable($script:NestKey, '1')
}

#  $PSScriptRoot is not reliably populated inside a parameter default under
#  every 5.1 host, and a gate that dies in its own parameter block has proven
#  nothing. Resolve it here, from the invocation, with no literal path.
$script:Here = $PSScriptRoot
if (-not $script:Here -and $MyInvocation.MyCommand.Path) { $script:Here = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $SkillDir -and $script:Here) { $SkillDir = Split-Path -Parent $script:Here }

# ---------------------------------------------------------------------------
# Reading and writing files the way this toolchain has to
# ---------------------------------------------------------------------------

function Expand-CommaList {
    <#  `powershell -File gate.ps1 -Only a,b` hands the whole list over as ONE
        string: -File does not split commas into an array. A filter that
        silently matches nothing would run no gate at all and then report a
        partial pass over an empty set, which is the same silent success this
        harness exists to catch. So the list is split here rather than
        trusted.  #>
    param($Value)
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($v in @($Value)) {
        if ($null -eq $v) { continue }
        foreach ($piece in ("$v" -split ',')) {
            $p = $piece.Trim()
            if ($p) { $out.Add($p) }
        }
    }
    return $out.ToArray()
}
function Read-FixtureText {
    <#  Explicit UTF-8 via ReadAllText, then drop a leading BOM. ReadAllBytes +
        GetString leaves the BOM inside the string, and a doubled BOM breaks the
        parse with errors pointing nowhere near the cause.  #>
    param([Parameter(Mandatory)][string] $File)
    if (-not (Test-Path -LiteralPath $File)) { return '' }
    $t = [System.IO.File]::ReadAllText($File, [System.Text.Encoding]::UTF8)
    return $t.TrimStart([char]0xFEFF)
}

function Write-FixtureText {
    param([Parameter(Mandatory)][string] $File, [Parameter(Mandatory)][string] $Body)
    $dir = Split-Path -Parent $File
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($File, $Body, (New-Object System.Text.UTF8Encoding($true)))
}

function Get-ShortLine {
    param([string] $Value, [int] $Max = 120)
    if ($null -eq $Value) { return '' }
    $one = ($Value -replace '\s+', ' ').Trim()
    if ($one.Length -le $Max) { return $one }
    return ($one.Substring(0, $Max) + ' ...')
}

# ---------------------------------------------------------------------------
# Running a gate as a real process, with a real ceiling
# ---------------------------------------------------------------------------

function Stop-ProcessTree {
    <#  Kill a process AND everything it started.

        A gate this harness runs may itself fan out to child processes. Killing
        only the parent at the timeout leaves those children running with
        nobody waiting on them, and they in turn start more: measured on this
        machine, one timed-out run left sixteen orphans behind and the count was
        still climbing. A harness that leaks processes is a harness nobody can
        leave running.  #>
    param([int] $ProcessId, [int] $Depth = 0)
    if ($Depth -gt 6 -or $ProcessId -le 0) { return }
    $kids = @()
    try { $kids = @(Get-WmiObject -Class Win32_Process -Filter ("ParentProcessId={0}" -f $ProcessId) -ErrorAction Stop) }
    catch { $kids = @() }
    foreach ($k in $kids) { Stop-ProcessTree -ProcessId ([int]$k.ProcessId) -Depth ($Depth + 1) }
    try { Stop-Process -Id $ProcessId -Force -ErrorAction Stop } catch { }
}

function Invoke-GateProcess {
    <#  Run a gate the way a runner runs it, and report what it did.

        -NonInteractive matters: a script with a Mandatory parameter and no
        argument would otherwise sit on a prompt forever, and a harness that
        hangs is a harness nobody runs.

        The gate's OUTPUT IS NEVER RETURNED TO THE CONSOLE and never written
        beside the report. It is read once, matched, and dropped.  #>
    param(
        [Parameter(Mandatory)][string] $File,
        [string[]] $Arguments = @(),
        [int] $TimeoutSec = 360
    )

    $tmpOut = [System.IO.Path]::GetTempFileName()
    $tmpErr = [System.IO.Path]::GetTempFileName()
    $argList = New-Object System.Collections.Generic.List[string]
    $argList.Add('-NoProfile')
    $argList.Add('-NonInteractive')
    $argList.Add('-ExecutionPolicy'); $argList.Add('Bypass')
    $argList.Add('-File'); $argList.Add($File)
    foreach ($a in $Arguments) { $argList.Add($a) }

    $rc = -1
    $timedOut = $false
    $text = ''
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $argList.ToArray() `
                -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr `
                -WindowStyle Hidden -PassThru
        #  TOUCH THE HANDLE. A process object from Start-Process -PassThru
        #  returns an EMPTY ExitCode unless its handle has been cached first,
        #  and an empty ExitCode is not zero: every gate this harness ran came
        #  back looking like a failure, so a gate that passed its clean build
        #  was recorded as PROVEN-NOCLEAN and a gate that cannot fail was
        #  recorded as refusing. A harness that misreads a pass is the same
        #  class of defect it is here to find.
        try { $null = $p.Handle } catch { }
        if (-not $p.WaitForExit($TimeoutSec * 1000)) {
            $timedOut = $true
            Stop-ProcessTree -ProcessId $p.Id
            try { $p.WaitForExit(5000) | Out-Null } catch { }
        }
        else {
            $code = $null
            try { $code = $p.ExitCode } catch { $code = $null }
            if ($null -eq $code) {
                $timedOut = $false
                $rc = -1
                $text = 'the harness could not read this process exit code'
            }
            else { $rc = [int]$code }
        }
    }
    catch {
        $text = "harness could not start the gate: $($_.Exception.Message)"
    }
    $sw.Stop()

    if (-not $text) {
        try { $text = (Read-FixtureText -File $tmpOut) + "`n" + (Read-FixtureText -File $tmpErr) }
        catch { $text = '' }
    }
    Remove-Item -LiteralPath $tmpOut -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $tmpErr -Force -ErrorAction SilentlyContinue

    return [pscustomobject]@{
        Exit     = $rc
        TimedOut = $timedOut
        Seconds  = [Math]::Round($sw.Elapsed.TotalSeconds, 1)
        Text     = $text
    }
}

function Test-OutputNames {
    <# Does the gate's output name the plant? Matched in memory, never echoed. #>
    param([string] $Text, [string] $Token)
    if (-not $Text -or -not $Token) { return $false }
    return ($Text.IndexOf($Token, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
}

# ---------------------------------------------------------------------------
# Discovery - the gate set, DERIVED
# ---------------------------------------------------------------------------

function Get-AstOf {
    param($Root, [Type] $Kind)
    if ($null -eq $Root) { return @() }
    return @($Root.FindAll({ param($nd) $nd.GetType() -eq $Kind }.GetNewClosure(), $true))
}

function Test-ReadBackNode {
    <#  Is there a FILESYSTEM READ inside this node?

        Node types and API identities, not prose: a Test-Path / Get-Content /
        Get-Item command, or a ReadAllText / ReadAllBytes / Exists member call.
        These are what the operation IS, not what its author called it.  #>
    param($Node)
    if ($null -eq $Node) { return $false }
    foreach ($c in (Get-AstOf -Root $Node -Kind ([System.Management.Automation.Language.CommandAst]))) {
        $nm = ''
        try { $nm = "$($c.GetCommandName())" } catch { $nm = '' }
        if ($nm -imatch '^(Test-Path|Get-Content|Get-Item|Get-ChildItem)$') { return $true }
    }
    foreach ($m in (Get-AstOf -Root $Node -Kind ([System.Management.Automation.Language.InvokeMemberExpressionAst]))) {
        if ("$($m.Member.Extent.Text)" -imatch '^(ReadAllText|ReadAllBytes|ReadAllLines|Exists)$') { return $true }
    }
    #  A SCRIPT MAY WRAP ITS OWN READS. Every gate here reads through a helper
    #  that handles the BOM, so almost no read-back calls ReadAllText directly.
    #  Insisting on the bare API called two gates WEAK for using their own
    #  library - including both of this harness's own gates, which would have
    #  meant reporting a number I already knew was wrong.
    if ($null -ne $script:ReaderFunctions) {
        foreach ($c in (Get-AstOf -Root $Node -Kind ([System.Management.Automation.Language.CommandAst]))) {
            $rn = ''
            try { $rn = "$($c.GetCommandName())" } catch { $rn = '' }
            if ($rn -and $script:ReaderFunctions.Contains($rn)) { return $true }
        }
    }
    return $false
}

function Test-WriteNode {
    <#  Is there a FILESYSTEM WRITE inside this node? Same basis as the read
        predicate: node types and API identities.  #>
    param($Node)
    if ($null -eq $Node) { return $false }
    foreach ($c in (Get-AstOf -Root $Node -Kind ([System.Management.Automation.Language.CommandAst]))) {
        $nm = ''
        try { $nm = "$($c.GetCommandName())" } catch { $nm = '' }
        if ($nm -imatch '^(Set-Content|Out-File|Add-Content|Copy-Item|New-Item|Move-Item)$') { return $true }
        if ($null -ne $script:WriterFunctions -and $nm -and $script:WriterFunctions.Contains($nm)) { return $true }
    }
    foreach ($m in (Get-AstOf -Root $Node -Kind ([System.Management.Automation.Language.InvokeMemberExpressionAst]))) {
        if ("$($m.Member.Extent.Text)" -imatch '^(WriteAllText|WriteAllBytes|WriteAllLines|Copy)$') { return $true }
    }
    return $false
}

function Get-SelfTestPlantVerification {
    <#  DOES THE SELF-TEST READ ITS PLANT BACK? Answered from STRUCTURE.

        The first version of this asked whether the words "plant" and "landed"
        appeared near each other in the source. That is the hand-listed
        check-set failure wearing a new costume: a gate you can pass by
        choosing different words measures nothing, and a skill that learns to
        write for it is worse off than with no gate at all. It produced a false
        WEAK against two gates that had real read-backs written in a different
        word order - and a false WEAK sends someone to add a read-back that is
        already there, which is the mirror of the false PROVEN this harness
        exists to prevent.

        THE PROPERTY, STATED STRUCTURALLY. Between writing the plant and
        asserting anything about the gate, the self-test READS THE PLANT TARGET
        BACK and BRANCHES on what it finds: a filesystem read reaching an if
        condition - directly, or through a variable assigned from one - whose
        branch calls a failure. The failure helpers are DERIVED from the script
        (a function that increments a fail counter or prints in red), never
        named here, so a script may call its own failure whatever it likes.

        Three states, and the third one matters: where the syntax tree cannot
        establish the property, this reports INDETERMINATE and says what it
        looked for. It never reports WEAK by default.  #>
    param($Ast, [bool] $HasSelfTest)

    $out = [pscustomobject]@{
        State     = 'N/A'
        Evidence  = ''
        LookedFor = 'a filesystem read (Test-Path / Get-Content / Get-Item / ReadAllText) reaching an if-condition, directly or through a variable assigned from one, whose branch calls a failure helper derived from this script, throws, or exits non-zero'
    }
    if (-not $HasSelfTest -or $null -eq $Ast) { return $out }

    #  1. WHERE is the self-test?
    $scopes = New-Object System.Collections.Generic.List[object]
    foreach ($ifs in (Get-AstOf -Root $Ast -Kind ([System.Management.Automation.Language.IfStatementAst]))) {
        foreach ($cl in $ifs.Clauses) {
            foreach ($v in (Get-AstOf -Root $cl.Item1 -Kind ([System.Management.Automation.Language.VariableExpressionAst]))) {
                if ("$($v.VariablePath.UserPath)" -ieq 'SelfTest') { $scopes.Add($ifs); break }
            }
        }
    }
    foreach ($fn in (Get-AstOf -Root $Ast -Kind ([System.Management.Automation.Language.FunctionDefinitionAst]))) {
        if ("$($fn.Name)" -imatch 'selftest') { $scopes.Add($fn) }
    }
    if ($scopes.Count -eq 0) {
        $out.State = 'INDETERMINATE'
        $out.Evidence = 'no self-test scope could be located in the syntax tree: no if on the SelfTest switch, and no function whose name contains SelfTest'
        return $out
    }

    #  A SELF-TEST MAY DELEGATE. The read-back can sit in a helper the
    #  self-test calls rather than in the branch itself, so the scope follows
    #  the call graph two levels down. Without this, a gate that factors its
    #  fixture builder into a function scores NOT-VERIFIED for the crime of
    #  being tidy.
    $fnByName = @{}
    foreach ($fn in (Get-AstOf -Root $Ast -Kind ([System.Management.Automation.Language.FunctionDefinitionAst]))) {
        if (-not $fnByName.ContainsKey("$($fn.Name)")) { $fnByName["$($fn.Name)"] = $fn }
    }
    for ($depth = 0; $depth -lt 2; $depth++) {
        $added = New-Object System.Collections.Generic.List[object]
        foreach ($scope in $scopes) {
            foreach ($c in (Get-AstOf -Root $scope -Kind ([System.Management.Automation.Language.CommandAst]))) {
                $cn = ''
                try { $cn = "$($c.GetCommandName())" } catch { $cn = '' }
                if (-not $cn -or -not $fnByName.ContainsKey($cn)) { continue }
                $cand = $fnByName[$cn]
                $seen = $false
                foreach ($s in $scopes) { if ($s -eq $cand) { $seen = $true } }
                foreach ($s in $added) { if ($s -eq $cand) { $seen = $true } }
                if (-not $seen) { $added.Add($cand) }
            }
        }
        foreach ($a in $added) { $scopes.Add($a) }
        if ($added.Count -eq 0) { break }
    }

    #  1b. WHICH of this script's own functions READ? Derived to a fixed point:
    #  a function reads if its body reads, or if it calls one that does.
    $script:ReaderFunctions = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $allFns = @(Get-AstOf -Root $Ast -Kind ([System.Management.Automation.Language.FunctionDefinitionAst]))
    for ($pass = 0; $pass -lt 4; $pass++) {
        $grew = $false
        foreach ($fn in $allFns) {
            if ($script:ReaderFunctions.Contains("$($fn.Name)")) { continue }
            if (Test-ReadBackNode -Node $fn.Body) { [void]$script:ReaderFunctions.Add("$($fn.Name)"); $grew = $true }
        }
        if (-not $grew) { break }
    }

    #  1c. And WHICH of its functions WRITE. A helper that both writes and
    #  reads is a plant-and-verify helper: a branch on what it returns is a
    #  read-back of the plant, one function call away.
    $script:WriterFunctions = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    for ($pass = 0; $pass -lt 4; $pass++) {
        $grew = $false
        foreach ($fn in $allFns) {
            if ($script:WriterFunctions.Contains("$($fn.Name)")) { continue }
            if (Test-WriteNode -Node $fn.Body) { [void]$script:WriterFunctions.Add("$($fn.Name)"); $grew = $true }
        }
        if (-not $grew) { break }
    }
    $plantHelpers = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($fn in $allFns) {
        if ($script:ReaderFunctions.Contains("$($fn.Name)") -and $script:WriterFunctions.Contains("$($fn.Name)")) {
            [void]$plantHelpers.Add("$($fn.Name)")
        }
    }

    #  2. WHAT does this script call failure? Derived, never named here.
    $failHelpers = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($fn in (Get-AstOf -Root $Ast -Kind ([System.Management.Automation.Language.FunctionDefinitionAst]))) {
        $isFail = $false
        foreach ($asn in (Get-AstOf -Root $fn.Body -Kind ([System.Management.Automation.Language.AssignmentStatementAst]))) {
            if ("$($asn.Left.Extent.Text)" -imatch 'fail') { $isFail = $true }
        }
        foreach ($ue in (Get-AstOf -Root $fn.Body -Kind ([System.Management.Automation.Language.UnaryExpressionAst]))) {
            if ("$($ue.Extent.Text)" -imatch 'fail') { $isFail = $true }
        }
        foreach ($c in (Get-AstOf -Root $fn.Body -Kind ([System.Management.Automation.Language.CommandAst]))) {
            $cn = ''
            try { $cn = "$($c.GetCommandName())" } catch { $cn = '' }
            if ($cn -imatch '^Write-Host$' -and "$($c.Extent.Text)" -imatch 'Red') { $isFail = $true }
        }
        if ($isFail) { [void]$failHelpers.Add("$($fn.Name)") }
    }
    $helperList = 'none found'
    if ($failHelpers.Count -gt 0) { $helperList = (@($failHelpers) -join ', ') }

    $sawPlant = $false
    $sawGuardedInspection = $false
    foreach ($scope in $scopes) {
        #  3. Variables that HOLD what was read back.
        $readVars = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($asn in (Get-AstOf -Root $scope -Kind ([System.Management.Automation.Language.AssignmentStatementAst]))) {
            if ($asn.Left -isnot [System.Management.Automation.Language.VariableExpressionAst]) { continue }
            if (Test-ReadBackNode -Node $asn.Right) { [void]$readVars.Add("$($asn.Left.VariablePath.UserPath)") }
        }

        #  NOT EVERY PLANT IS A FILE. One gate plants into an in-memory copy of
        #  a document part and reads it back with IndexOf - a real read-back of
        #  the real plant target, in the exact channel that gate scans. Treating
        #  only filesystem reads as read-backs called that WEAK, which is the
        #  false negative this detector exists to stop. So a variable MUTATED by
        #  the self-test - assigned through an index or member, or built from
        #  itself - is a plant target too, and inspecting its contents in a
        #  condition is reading the plant back.
        #  WHAT DID THIS SELF-TEST ACTUALLY WRITE? A read of a file the gate
        #  merely needs - a config that must resolve - is not a read-back of a
        #  plant. One gate checks Test-Path on its config and fails if it is
        #  missing, which is right and proves nothing about any plant; scoring
        #  that VERIFIED was a false positive in the gate's favour, the mirror
        #  of the false WEAK this rewrite exists to end.
        $plantTargets = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($w in (Get-AstOf -Root $scope -Kind ([System.Management.Automation.Language.InvokeMemberExpressionAst]))) {
            if ("$($w.Member.Extent.Text)" -inotmatch '^(WriteAllText|WriteAllBytes|WriteAllLines)$') { continue }
            foreach ($v in (Get-AstOf -Root $w -Kind ([System.Management.Automation.Language.VariableExpressionAst]))) {
                [void]$plantTargets.Add("$($v.VariablePath.UserPath)")
            }
        }
        foreach ($c in (Get-AstOf -Root $scope -Kind ([System.Management.Automation.Language.CommandAst]))) {
            $cn3 = ''
            try { $cn3 = "$($c.GetCommandName())" } catch { $cn3 = '' }
            $isWrite = ($cn3 -imatch '^(Set-Content|Out-File|Add-Content|Copy-Item|New-Item|Move-Item)$')
            if (-not $isWrite -and $null -ne $script:WriterFunctions -and $cn3) { $isWrite = $script:WriterFunctions.Contains($cn3) }
            if (-not $isWrite) { continue }
            foreach ($v in (Get-AstOf -Root $c -Kind ([System.Management.Automation.Language.VariableExpressionAst]))) {
                [void]$plantTargets.Add("$($v.VariablePath.UserPath)")
            }
        }
        #  A loop over a collection that names a plant target carries the plant
        #  into its loop variable, which is how one gate reads four stubs back.
        for ($fp = 0; $fp -lt 3; $fp++) {
            foreach ($fe in (Get-AstOf -Root $scope -Kind ([System.Management.Automation.Language.ForEachStatementAst]))) {
                foreach ($v in (Get-AstOf -Root $fe.Condition -Kind ([System.Management.Automation.Language.VariableExpressionAst]))) {
                    if ($plantTargets.Contains("$($v.VariablePath.UserPath)")) {
                        [void]$plantTargets.Add("$($fe.Variable.VariablePath.UserPath)")
                    }
                }
            }
        }
        #  A variable holding what a PLANT HELPER returned - a function that
        #  both writes and reads - is the plant, one call away.
        $helperResultVars = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($asn in (Get-AstOf -Root $scope -Kind ([System.Management.Automation.Language.AssignmentStatementAst]))) {
            if ($asn.Left -isnot [System.Management.Automation.Language.VariableExpressionAst]) { continue }
            foreach ($c in (Get-AstOf -Root $asn.Right -Kind ([System.Management.Automation.Language.CommandAst]))) {
                $cn4 = ''
                try { $cn4 = "$($c.GetCommandName())" } catch { $cn4 = '' }
                if ($cn4 -and $plantHelpers.Contains($cn4)) { [void]$helperResultVars.Add("$($asn.Left.VariablePath.UserPath)") }
            }
        }

        if ($plantTargets.Count -gt 0) { $sawPlant = $true }
        $mutatedVars = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($asn in (Get-AstOf -Root $scope -Kind ([System.Management.Automation.Language.AssignmentStatementAst]))) {
            $root = ''
            foreach ($v in (Get-AstOf -Root $asn.Left -Kind ([System.Management.Automation.Language.VariableExpressionAst]))) {
                if (-not $root) { $root = "$($v.VariablePath.UserPath)" }
            }
            if (-not $root) { continue }
            $isIndexed = ($asn.Left -is [System.Management.Automation.Language.IndexExpressionAst]) -or
                         ($asn.Left -is [System.Management.Automation.Language.MemberExpressionAst])
            $selfBuilt = $false
            foreach ($v in (Get-AstOf -Root $asn.Right -Kind ([System.Management.Automation.Language.VariableExpressionAst]))) {
                if ("$($v.VariablePath.UserPath)" -ieq $root) { $selfBuilt = $true }
            }
            if ($isIndexed -or $selfBuilt) { [void]$mutatedVars.Add($root) }
        }

        #  4. A read that reaches a condition whose branch fails.
        foreach ($ifs in (Get-AstOf -Root $scope -Kind ([System.Management.Automation.Language.IfStatementAst]))) {
            foreach ($cl in $ifs.Clauses) {
                #  THREE ACCEPTED SHAPES, and naming a plant target is not one
                #  of them. "The gate found the key I planted" is an assertion
                #  about the GATE; "the file I planted is on disk and carries
                #  its marker" is a read-back of the PLANT. Accepting the first
                #  scored a gate VERIFIED whose only Test-Path checks that its
                #  config resolves - nothing to do with any plant.
                $touchesPlant = $false
                foreach ($v in (Get-AstOf -Root $cl.Item1 -Kind ([System.Management.Automation.Language.VariableExpressionAst]))) {
                    if ($plantTargets.Contains("$($v.VariablePath.UserPath)")) { $touchesPlant = $true }
                }
                $readish = $false
                #  A. a real read operation, on something this self-test wrote
                if ($touchesPlant -and (Test-ReadBackNode -Node $cl.Item1)) { $readish = $true }
                #  B. a variable holding what such a read returned
                if (-not $readish -and $touchesPlant) {
                    foreach ($v in (Get-AstOf -Root $cl.Item1 -Kind ([System.Management.Automation.Language.VariableExpressionAst]))) {
                        if ($readVars.Contains("$($v.VariablePath.UserPath)")) { $readish = $true }
                    }
                }
                #  C. the result of a helper that both plants and reads back.
                #  NOT the self-test's own dispatch: `$failed = Invoke-XSelfTest`
                #  followed by `if ($failed -gt 0) { exit 4 }` is the script
                #  deciding its exit code, and scoring that as a read-back made
                #  a gate VERIFIED whose only Test-Path checks that its config
                #  resolves. So this arm counts only INSIDE a self-test body -
                #  a function scope - never in the top-level if that calls it.
                if (-not $readish -and ($scope -is [System.Management.Automation.Language.FunctionDefinitionAst])) {
                    foreach ($v in (Get-AstOf -Root $cl.Item1 -Kind ([System.Management.Automation.Language.VariableExpressionAst]))) {
                        if ($helperResultVars.Contains("$($v.VariablePath.UserPath)")) { $readish = $true }
                    }
                }
                if (-not $readish) {
                    #  A containment test on something the self-test itself
                    #  mutated: reading the plant back, in memory.
                    foreach ($mi in (Get-AstOf -Root $cl.Item1 -Kind ([System.Management.Automation.Language.InvokeMemberExpressionAst]))) {
                        if ("$($mi.Member.Extent.Text)" -inotmatch '^(IndexOf|Contains|StartsWith|EndsWith|Match)$') { continue }
                        foreach ($v in (Get-AstOf -Root $mi.Expression -Kind ([System.Management.Automation.Language.VariableExpressionAst]))) {
                            if ($mutatedVars.Contains("$($v.VariablePath.UserPath)")) { $readish = $true }
                        }
                    }
                }
                if (-not $readish) {
                    #  Remember that SOMETHING here is inspected under a branch,
                    #  even where it could not be tied to a plant.
                    foreach ($mi2 in (Get-AstOf -Root $cl.Item1 -Kind ([System.Management.Automation.Language.InvokeMemberExpressionAst]))) {
                        if ("$($mi2.Member.Extent.Text)" -imatch '^(IndexOf|Contains|StartsWith|EndsWith|Match|IsMatch)$') { $sawGuardedInspection = $true }
                    }
                    foreach ($be2 in (Get-AstOf -Root $cl.Item1 -Kind ([System.Management.Automation.Language.BinaryExpressionAst]))) {
                        if ("$($be2.Operator)".ToLower() -match '^(i?eq|i?ne|i?match|i?notmatch|i?like)$') { $sawGuardedInspection = $true }
                    }
                    continue
                }

                $failish = $false
                foreach ($c in (Get-AstOf -Root $cl.Item2 -Kind ([System.Management.Automation.Language.CommandAst]))) {
                    $cn = ''
                    try { $cn = "$($c.GetCommandName())" } catch { $cn = '' }
                    if ($cn -and $failHelpers.Contains($cn)) { $failish = $true }
                }
                foreach ($ex in (Get-AstOf -Root $cl.Item2 -Kind ([System.Management.Automation.Language.ExitStatementAst]))) {
                    if ("$($ex.Extent.Text)" -notmatch '(?<![0-9])0\s*$') { $failish = $true }
                }
                if ((Get-AstOf -Root $cl.Item2 -Kind ([System.Management.Automation.Language.ThrowStatementAst])).Count -gt 0) { $failish = $true }
                foreach ($asn in (Get-AstOf -Root $cl.Item2 -Kind ([System.Management.Automation.Language.AssignmentStatementAst]))) {
                    if ("$($asn.Left.Extent.Text)" -imatch 'fail|plantok') { $failish = $true }
                }
                #  `$selfTestFailed++` is an increment, not an assignment, and a
                #  branch may print its own failure in red rather than call a
                #  helper. Both are this script declaring the check failed.
                foreach ($ue in (Get-AstOf -Root $cl.Item2 -Kind ([System.Management.Automation.Language.UnaryExpressionAst]))) {
                    if ("$($ue.Extent.Text)" -imatch 'fail') { $failish = $true }
                }
                foreach ($c in (Get-AstOf -Root $cl.Item2 -Kind ([System.Management.Automation.Language.CommandAst]))) {
                    $cn2 = ''
                    try { $cn2 = "$($c.GetCommandName())" } catch { $cn2 = '' }
                    if ($cn2 -imatch '^Write-(Host|Error|Warning)$' -and "$($c.Extent.Text)" -imatch 'Red|did not|does not|X ') { $failish = $true }
                }

                if ($failish) {
                    $out.State = 'VERIFIED'
                    $out.Evidence = ("line {0}: a filesystem read reaches this condition and its branch fails (failure helpers derived from this script: {1})" -f $cl.Item1.Extent.StartLineNumber, $helperList)
                    return $out
                }
            }
        }
    }

    #  THE THIRD STATE, AND IT MATTERS. Some self-tests build their fixture
    #  entirely in memory - prompt objects, parsed structures - and check it
    #  with a regex or a property comparison under a failing branch. That IS a
    #  read-back of the plant; static analysis cannot tell it apart from an
    #  assertion about the gate, because both are a comparison on a variable
    #  the self-test made. Calling those WEAK would send someone to add a
    #  read-back that is already written, which is the mirror of the false
    #  PROVEN this harness exists to prevent. So they are INDETERMINATE, with
    #  what was looked for, and a reader decides.
    if ($sawPlant -or $sawGuardedInspection) {
        $inMem = ' (its fixture is built in memory, with no filesystem plant to read back)'
        if ($sawPlant) { $inMem = ' (it writes or mutates a plant target)' }
        $out.State = 'INDETERMINATE'
        $out.Evidence = ('a self-test scope was found, and it does build a fixture and branch on what it finds, but no read of the plant target could be tied to the plant statically' + $inMem + '. Failure helpers derived from this script: ' + $helperList)
        return $out
    }
    $out.State = 'NOT-VERIFIED'
    $out.Evidence = ('a self-test scope was found and parsed. It neither plants anything this analysis can see nor branches to failure on any inspection of one. Failure helpers derived from this script: ' + $helperList)
    return $out
}

#  REQUEST: Lib-GateCommon Get-GateHeader
#  Run-SpineGates.ps1 carries its own Get-GateHeader over the same line, and
#  two parsers of one line is the duplication this skill keeps paying for. The
#  parse below is deliberately Run-SpineGates', line for line, so that until a
#  shared helper lands the two cannot disagree about where a header may sit or
#  what a clause means.
function Get-GateHeaderLine {
    <#  The '# GATE:' header a gate carries near its top, parsed.

        Format, fixed by P0-15 and read here without extension:
            # GATE: stages=1,3c; requires=BuildDir; 7c: DocText
        Clauses are ';'-separated. 'stages=' lists the stages the gate runs
        at; 'requires=' lists the parameter names it cannot run without; a
        clause of the form '<stage>: <names>' is a stage-qualified requires.

        THE SCAN IS RUN-SPINEGATES', LINE FOR LINE: from the top, skipping
        block comments, stopping at the first CmdletBinding attribute or
        param block. An earlier version read only the first 60 lines - and
        the opening and closing markers of a block comment cannot be written
        inside one, which is its own small lesson. This very script's
        own header sits at line 117 under a long block comment - so the
        harness reported ITSELF as carrying no header while the runner that
        actually derives membership from it read it perfectly. Two readers of
        one line must not disagree about where the line may be.

        Returns $null when there is none.  #>
    param([AllowEmptyString()][string] $Source)

    if (-not $Source) { return $null }
    $lines = @($Source -split "`r?`n")
    $inBlock = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $ln = $lines[$i]
        if ($inBlock) { if ($ln -match '#>') { $inBlock = $false }; continue }
        if ($ln -match '^\s*<#') { if ($ln -notmatch '#>') { $inBlock = $true }; continue }
        if ($ln -match '^\s*(\[CmdletBinding|param\s*\()') { break }
        $m = [regex]::Match($ln, '^\s*#\s*GATE:\s*(.+?)\s*$')
        if (-not $m.Success) { continue }
        $raw = $m.Groups[1].Value
        $stages = New-Object System.Collections.Generic.List[string]
        $requires = New-Object System.Collections.Generic.List[string]
        $clauses = [ordered]@{}
        $problems = New-Object System.Collections.Generic.List[string]
        foreach ($piece in ($raw -split ';')) {
            $c = $piece.Trim()
            if (-not $c) { continue }
            $kv = [regex]::Match($c, '^(stages|requires)\s*=\s*(.*)$')
            if ($kv.Success) {
                $vals = @($kv.Groups[2].Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
                if ($kv.Groups[1].Value -eq 'stages') { foreach ($v in $vals) { if (-not $stages.Contains($v)) { $stages.Add($v) } } }
                else { foreach ($v in $vals) { if (-not $requires.Contains($v)) { $requires.Add($v) } } }
                continue
            }
            $sc = [regex]::Match($c, '^([0-9][0-9a-z-]*)\s*:\s*(.*)$')
            if ($sc.Success) {
                $clauses[$sc.Groups[1].Value] = @($sc.Groups[2].Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
                continue
            }
            $problems.Add(("clause '{0}' is neither stages=, requires= nor <stage>: <names>" -f $c))
        }
        return [pscustomobject]@{
            Line     = $i + 1
            Raw      = $raw
            Stages   = $stages.ToArray()
            Requires = $requires.ToArray()
            Clauses  = $clauses
            Problems = $problems.ToArray()
        }
    }
    return $null
}

function Get-ScriptFacts {
    <#  What a gate declares about itself: its parameters, whether it has a
        -SelfTest, whether that self-test verifies its own plant, what exit
        codes it can return, the claim in its header, its '# GATE:' line and
        whether it supports ShouldProcess.

        -Deep runs the plant-verification analysis over the syntax tree,
        which costs seconds per large script. The static arms do not need it
        (they ask whether a self-test EXISTS, not whether it reads its plant
        back), so they leave it off and stay inside a band's budget.  #>
    param([Parameter(Mandatory)][string] $File, [switch] $Deep)

    $facts = [pscustomobject]@{
        Name          = [System.IO.Path]::GetFileNameWithoutExtension($File)
        File          = $File
        Parses        = $false
        ParseError    = ''
        ParamNames    = @()
        Mandatory     = @()
        HasSelfTest   = $false
        SelfTestSwitch = ''
        SelfTestVerifiesPlant = $false
        ExitCodes     = @()
        CanFail       = $false
        Claim         = ''
        Length        = 0
        Mtime         = [datetime]::MinValue
        SupportsShouldProcess = $false
        GateHeader    = $null
        PlantVerifyState = 'N/A'
        PlantVerifyEvidence = ''
        PlantVerifyLookedFor = ''
    }
    if (-not (Test-Path -LiteralPath $File)) { $facts.ParseError = 'the file is not on disk'; return $facts }
    $fi = Get-Item -LiteralPath $File
    $facts.Length = $fi.Length
    $facts.Mtime = $fi.LastWriteTimeUtc

    $src = Read-FixtureText -File $File
    $facts.GateHeader = Get-GateHeaderLine -Source $src
    #  The claim: the first prose of the header block comment. Read before
    #  the parse so an unparseable gate still reports what it claimed.
    $m = [regex]::Match($src, '(?s)^\s*<#(.*?)#>')
    if ($m.Success) {
        $head = $m.Groups[1].Value
        $head = [regex]::Replace($head, '\s+', ' ').Trim()
        $facts.Claim = Get-ShortLine -Value $head -Max 220
    }

    $tokens = $null; $errors = $null; $ast = $null
    try { $ast = [System.Management.Automation.Language.Parser]::ParseFile($File, [ref]$tokens, [ref]$errors) }
    catch { $facts.ParseError = ('the parser threw: ' + (Get-ShortLine -Value $_.Exception.Message -Max 160)); return $facts }
    if ($null -ne $errors -and $errors.Count -gt 0) {
        $e0 = $errors[0]
        $facts.ParseError = ("line {0}: {1}" -f $e0.Extent.StartLineNumber, (Get-ShortLine -Value $e0.Message -Max 160))
        return $facts
    }
    $facts.Parses = $true

    $pnames = New-Object System.Collections.Generic.List[string]
    $mand = New-Object System.Collections.Generic.List[string]
    if ($null -ne $ast.ParamBlock) {
        foreach ($attr in $ast.ParamBlock.Attributes) {
            if ("$($attr.TypeName)" -inotmatch 'CmdletBinding') { continue }
            foreach ($na in $attr.NamedArguments) {
                if ("$($na.ArgumentName)" -ieq 'SupportsShouldProcess') {
                    if ($na.ExpressionOmitted -or [regex]::IsMatch($na.Argument.Extent.Text, '(?i)\$true')) { $facts.SupportsShouldProcess = $true }
                }
            }
        }
        foreach ($p in $ast.ParamBlock.Parameters) {
            $pn = "$($p.Name.VariablePath.UserPath)"
            $pnames.Add($pn)
            #  A switch whose name ENDS in SelfTest is a self-test switch:
            #  Lib-GateCommon's is -GateCommonSelfTest, because a plain
            #  -SelfTest on a dot-sourced library would bind to the caller's.
            $isSwitch = $false
            foreach ($a in $p.Attributes) {
                if ($a -is [System.Management.Automation.Language.TypeConstraintAst] -and "$($a.TypeName)" -imatch '^switch$') { $isSwitch = $true }
            }
            if ($isSwitch -and $pn -imatch 'SelfTest$' -and -not $facts.HasSelfTest) { $facts.HasSelfTest = $true; $facts.SelfTestSwitch = $pn }
            foreach ($a in $p.Attributes) {
                if ($a -isnot [System.Management.Automation.Language.AttributeAst]) { continue }
                foreach ($na in $a.NamedArguments) {
                    if ("$($na.ArgumentName)" -ieq 'Mandatory') {
                        if ($na.ExpressionOmitted -or [regex]::IsMatch($na.Argument.Extent.Text, '(?i)\$true')) { $mand.Add($pn) }
                    }
                }
            }
        }
    }
    #  A SCRIPT'S PARAMETERS ARE NOT ALWAYS ITS FILE-SCOPE param() BLOCK.
    #  Test-GuideRules.ps1 has none: it declares a FUNCTION of the same name,
    #  and the runner dot-sources the file and calls that. Reading only the
    #  file scope reported its own header's requires=Path and
    #  requires=QuestionsInPack as naming no parameter of the script - two
    #  confident false findings against a header that was right. So the
    #  function that carries the script's name contributes its parameters too,
    #  and its CmdletBinding is read for SupportsShouldProcess on the same
    #  footing.
    foreach ($fn in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
        if ("$($fn.Name)" -ine $facts.Name) { continue }
        $pb = $null
        if ($null -ne $fn.Body) { $pb = $fn.Body.ParamBlock }
        if ($null -eq $pb) { continue }
        foreach ($attr in $pb.Attributes) {
            if ("$($attr.TypeName)" -inotmatch 'CmdletBinding') { continue }
            foreach ($na in $attr.NamedArguments) {
                if ("$($na.ArgumentName)" -ieq 'SupportsShouldProcess') {
                    if ($na.ExpressionOmitted -or [regex]::IsMatch($na.Argument.Extent.Text, '(?i)\$true')) { $facts.SupportsShouldProcess = $true }
                }
            }
        }
        foreach ($p in $pb.Parameters) {
            $pn = "$($p.Name.VariablePath.UserPath)"
            if (-not $pnames.Contains($pn)) { $pnames.Add($pn) }
        }
    }
    $facts.ParamNames = $pnames.ToArray()
    $facts.Mandatory = $mand.ToArray()

    $exits = New-Object 'System.Collections.Generic.HashSet[int]'
    foreach ($node in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.ExitStatementAst] }, $true)) {
        $pipe = $node.Pipeline
        if ($null -ne $pipe -and [regex]::IsMatch("$($pipe.Extent.Text)", '^\s*\d+\s*$')) {
            [void]$exits.Add([int]("$($pipe.Extent.Text)".Trim()))
        }
        else { [void]$exits.Add(-1) }
    }
    $ecodes = New-Object System.Collections.Generic.List[int]
    foreach ($e in $exits) { $ecodes.Add($e) }
    $facts.ExitCodes = ($ecodes.ToArray() | Sort-Object)
    foreach ($e in $ecodes) { if ($e -ne 0) { $facts.CanFail = $true } }
    #  A gate can also fail by throwing out of a script with a non-zero
    #  terminating error, which 5.1 surfaces as exit 1.
    if (-not $facts.CanFail -and [regex]::IsMatch($src, '(?m)^\s*throw\b')) { $facts.CanFail = $true }

    #  Does the self-test READ ITS PLANT BACK? Structure, from the syntax
    #  tree. Deep only: it is the expensive half of discovery.
    if ($Deep) {
        $pv = Get-SelfTestPlantVerification -Ast $ast -HasSelfTest ([bool]$facts.HasSelfTest)
        $facts.SelfTestVerifiesPlant = ($pv.State -eq 'VERIFIED')
        $facts.PlantVerifyState = $pv.State
        $facts.PlantVerifyEvidence = $pv.Evidence
        $facts.PlantVerifyLookedFor = $pv.LookedFor
    }
    else {
        $facts.PlantVerifyState = 'NOT-ANALYSED'
        $facts.PlantVerifyEvidence = 'the plant-verification analysis runs in the full channel only'
    }
    return $facts
}

function Get-FilesystemGateSet {
    <#  Every script in the skill that can return a verdict.

        Enumerated from disk. Anything that can exit non-zero, or is named the
        way this skill names its gates, is in the set - so a gate a sibling
        build adds while this runs is still covered by the next run rather than
        being invisible forever.

        A SCRIPT THAT DOES NOT PARSE STAYS IN THE SET. The first version
        dropped it (an unparseable script has no exit statements, so it "cannot
        fail" and fell through the filter) - which is exactly backwards: a gate
        with a syntax error is a gate that runs nothing, and the harness made
        it vanish from the report instead of naming it.  #>
    param([Parameter(Mandatory)][string] $Skill, [switch] $Deep)

    $out = New-Object System.Collections.Generic.List[object]
    $dir = Join-Path $Skill 'scripts'
    if (-not (Test-Path -LiteralPath $dir)) { return $out.ToArray() }
    $files = @()
    try { $files = @(Get-ChildItem -LiteralPath $dir -Filter '*.ps1' -File -ErrorAction Stop | Sort-Object Name) }
    catch { $files = @() }
    foreach ($f in $files) {
        $facts = Get-ScriptFacts -File $f.FullName -Deep:$Deep
        $named = [regex]::IsMatch($f.BaseName, '^(Assert|Check|Test)-')
        if ($facts.Parses -and -not $facts.CanFail -and -not $named) { continue }
        Add-Member -InputObject $facts -NotePropertyName 'Origin' -NotePropertyValue 'filesystem' -Force
        $out.Add($facts)
    }
    return $out.ToArray()
}

function Get-ScriptStamp {
    <#  Length and last-write of every script, for the moved-during-run check.
        No parse: a stamp is what tells whether a re-parse would differ.  #>
    param([Parameter(Mandatory)][string] $Skill)
    $map = @{}
    $dir = Join-Path $Skill 'scripts'
    if (-not (Test-Path -LiteralPath $dir)) { return $map }
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter '*.ps1' -File -ErrorAction SilentlyContinue)) {
        $map[$f.FullName] = [pscustomobject]@{ Name = $f.BaseName; Length = $f.Length; Mtime = $f.LastWriteTimeUtc }
    }
    return $map
}

function Get-SkillScriptIndex {
    <#  Every script and every function this toolchain can reach, once.

        SIBLING SKILLS COUNT. `Test-Readability` is the assessment skill's, and
        the stage table says so in the same cell - "(assessment skill,
        unchanged)". A resolver that looked only in its own scripts\ directory
        called it ABSENT and reported that nothing performs readability, which
        is false and would have sent someone to write a gate that already
        exists two directories away.  #>
    param([Parameter(Mandatory)][string] $Skill)

    $files = @{}
    $funcs = @{}
    $roots = New-Object System.Collections.Generic.List[string]
    $roots.Add((Join-Path $Skill 'scripts'))
    $parent = Split-Path -Parent $Skill
    if ($parent -and (Test-Path -LiteralPath $parent)) {
        $sibs = @()
        try { $sibs = @(Get-ChildItem -LiteralPath $parent -Directory -ErrorAction Stop) } catch { $sibs = @() }
        foreach ($s in $sibs) {
            if ($s.FullName -ieq $Skill) { continue }
            $roots.Add((Join-Path $s.FullName 'scripts'))
        }
    }
    foreach ($r in $roots) {
        if (-not (Test-Path -LiteralPath $r)) { continue }
        $ps = @()
        try { $ps = @(Get-ChildItem -LiteralPath $r -Filter '*.ps1' -File -ErrorAction Stop) } catch { $ps = @() }
        foreach ($p in $ps) {
            if (-not $files.ContainsKey($p.BaseName)) { $files[$p.BaseName] = $p.FullName }
            $src = ''
            try { $src = Read-FixtureText -File $p.FullName } catch { $src = '' }
            foreach ($m in [regex]::Matches($src, '(?im)^\s*function\s+([A-Za-z][A-Za-z0-9-]*)')) {
                $fn = $m.Groups[1].Value
                if (-not $funcs.ContainsKey($fn)) { $funcs[$fn] = $p.FullName }
            }
        }
    }
    return [pscustomobject]@{ Files = $files; Functions = $funcs }
}

function Resolve-GateName {
    <# Where does this name live - as a script, or as a function? #>
    param([Parameter(Mandatory)][string] $Name, $Index)
    if ($Index.Files.ContainsKey($Name)) {
        return [pscustomobject]@{ File = $Index.Files[$Name]; Kind = 'script' }
    }
    if ($Index.Functions.ContainsKey($Name)) {
        return [pscustomobject]@{ File = $Index.Functions[$Name]; Kind = 'function' }
    }
    return $null
}

function Get-GatesDocClaim {
    <#  The stage table in gates.md, read as CLAIMS about what exists.

        The file itself says to read the Script column honestly: a name marked
        NOT YET IMPLEMENTED is a specification, not a gate. This reads the
        marker AND checks the filesystem, and reports where the two disagree -
        which they will, because sibling builds are writing that directory.  #>
    param([Parameter(Mandatory)][string] $Doc, [Parameter(Mandatory)][string] $Skill)

    $rows = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $Doc)) { return $rows.ToArray() }
    $Index = Get-SkillScriptIndex -Skill $Skill
    $text = Read-FixtureText -File $Doc
    $lines = $text -split "`r?`n"
    $scriptDir = Join-Path $Skill 'scripts'

    foreach ($ln in $lines) {
        if ($ln -notmatch '^\s*\|') { continue }
        $cells = @($ln.Trim().Trim('|') -split '\s*\|\s*')
        if ($cells.Count -lt 5) { continue }
        $stage = $cells[0].Trim()
        if ($stage -match '^-+$' -or $stage -ieq 'Stage') { continue }
        $gateName = $cells[1].Trim()
        $scriptCell = $cells[2].Trim()
        #  '**no**' is the table's own emphasis on the one non-blocking row.
        $blocks = ($cells[3].Trim() -replace '\*', '').Trim().ToLowerInvariant()
        $section = $cells[4].Trim()
        #  The stage cell as keys the ledger would know: 'S0-RTO' is stage 0,
        #  '3b exit' is 3b, '5 / 6' is two stages.
        $stageKeys = @([regex]::Matches($stage, '(?i)(?<![0-9a-z])(?:S)?([0-9][0-9a-z-]*?)(?=\s|$|/|\b(?!-))') | ForEach-Object { $_.Groups[1].Value.TrimEnd('-') } | Where-Object { $_ } | Select-Object -Unique)
        if ($stage -imatch '^S0') { $stageKeys = @('0') }

        $marker = 'implemented'
        if ([regex]::IsMatch($scriptCell, '(?i)NOT\s+YET\s+IMPLEMENTED')) { $marker = 'not-yet-implemented' }
        elseif ([regex]::IsMatch($scriptCell, '(?i)BEING\s+IMPLEMENTED')) { $marker = 'being-implemented' }
        #  A JUDGEMENT ROW names no script: "reader, not a script", "judgement,
        #  with a verdict". It is part of the answer - a stage the pipeline
        #  claims and no script performs - and is kept as a JUDGEMENT-ONLY row
        #  rather than dropped from the set.
        $isJudgement = [regex]::IsMatch($scriptCell, '(?i)^(judgement|reader)\b')

        #  Every backticked token in the cell that looks like a script or a
        #  gate function name.
        $names = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($bm in [regex]::Matches($scriptCell, '`([^`]+)`')) {
            $tok = $bm.Groups[1].Value.Trim()
            foreach ($nm in [regex]::Matches($tok, '(?i)([A-Za-z]+-[A-Za-z0-9]+)(\.ps1)?')) {
                [void]$names.Add($nm.Groups[1].Value)
            }
        }
        foreach ($nm in [regex]::Matches($scriptCell, '(?<![`\w])(Assert|Check|Test|Get|New|Run|Set|Invoke|Merge|Probe|Stage|Finish)-[A-Za-z0-9]+')) {
            [void]$names.Add($nm.Value)
        }

        #  A ROW NAMES ONE CHECK, NOT SEVERAL GATES. The table's convention is
        #  to name the script that performs a check and put the DESIGN name
        #  beside it: "scripts\Check-Identity.ps1 (`Assert-BrandCrossover`)",
        #  "scripts\Test-Finding.ps1 (specified as Assert-FindingProvenance)".
        #  Reading each name as its own gate reported three checks as performed
        #  by nobody while the scripts that perform them sat in the same cell -
        #  three confident false findings against the documentation, in the
        #  same tone as the one true one. So: resolve every candidate, and if
        #  ANY resolves, the row is performed and the others are its aliases.
        $resolved = $null
        $resolvedName = ''
        $aliases = New-Object System.Collections.Generic.List[string]
        $ordered = New-Object System.Collections.Generic.List[string]
        foreach ($nm in $names) {
            #  A cmdlet-shaped name only. "7b-i" in a stage cell is a stage
            #  label that split into a fragment called "b-i", and a gate by
            #  that name has never existed.
            if (-not [regex]::IsMatch($nm, '^[A-Z][A-Za-z]+-[A-Za-z0-9]+$')) { continue }
            $ordered.Add($nm)
        }
        foreach ($nm in $ordered) {
            $hit = Resolve-GateName -Name $nm -Index $Index
            if ($null -ne $hit -and $null -eq $resolved) { $resolved = $hit; $resolvedName = $nm; continue }
            $aliases.Add($nm)
        }
        if ($ordered.Count -eq 0) {
            if ($isJudgement) {
                $rows.Add([pscustomobject]@{
                    Stage = $stage; StageKeys = @($stageKeys); Gate = $gateName; Name = ''; Marker = 'judgement'
                    Blocks = $blocks; BlocksYes = ($blocks -eq 'yes'); Section = $section; File = ''
                    OnDisk = $false; AsFunction = ''; Aliases = @(); Judgement = $true; ScriptCell = $scriptCell
                })
            }
            continue
        }
        if ($null -eq $resolved) {
            $resolvedName = $ordered[0]
            $aliases.Clear()
            for ($ai = 1; $ai -lt $ordered.Count; $ai++) { $aliases.Add($ordered[$ai]) }
        }
        $rows.Add([pscustomobject]@{
            Stage      = $stage
            StageKeys  = @($stageKeys)
            Gate       = $gateName
            Name       = $resolvedName
            Marker     = $marker
            Blocks     = $blocks
            BlocksYes  = ($blocks -eq 'yes')
            Section    = $section
            File       = $(if ($null -ne $resolved) { $resolved.File } else { '' })
            OnDisk     = ($null -ne $resolved -and $resolved.Kind -eq 'script')
            AsFunction = $(if ($null -ne $resolved -and $resolved.Kind -eq 'function') { $resolved.File } else { '' })
            Aliases    = $aliases.ToArray()
            Judgement  = $false
            ScriptCell = $scriptCell
        })
    }
    return $rows.ToArray()
}

# ---------------------------------------------------------------------------
# The ledger's stage table, read BY SYNTAX TREE and by nothing else
# ---------------------------------------------------------------------------

function Get-LedgerStageView {
    <#  The one ordered stage table the ledger owns, read as data.

        READ BY SYNTAX TREE, NEVER BY DOT-SOURCING. An earlier version of this
        reader dot-sourced Stage-Ledger.ps1 in a child scope and read the
        variables back. Three things are wrong with that and each of them has
        already cost a build:

          - a dot-sourced file with a param() block CLOBBERS the caller's
            variables of the same name, so a harness that reads the ledger this
            way can silently rewrite its own $BuildDir;
          - the file is being rewritten by another author while this runs, and
            a half-landed file either throws or - worse - parses and yields a
            SHORT table, which would be read here as a shrunken stage set and
            reported as agreement;
          - executing a file to find out what it declares runs whatever else it
            declares.

        So: parse, find the ONE literal assignment to $script:LedgerStages,
        walk the HashtableAst nodes underneath it, and read Key, Required,
        Blocking, Conditional, Terminal and Script off each row as constants.
        Nothing is executed.

        WHEN THE TABLE IS NOT THERE, SAY SO AND CARRY IT AS A PARTIAL. The
        table lands with P0-02, separately from this. Until it does, this
        returns Source 'none' with the reason 'stage table not found', every
        caller records a NAMED PARTIAL, and no arm that depends on the table
        may report a pass. It is never guessed and never defaulted - a
        defaulted stage table is a hand-listed check set with extra steps.  #>
    param([Parameter(Mandatory)][string] $Skill)

    $out = [pscustomobject]@{
        Source      = 'none'
        Note        = ''
        Keys        = @()
        Required    = @()
        Blocking    = @()
        Conditional = @()
        Terminal    = @()
        Rows        = @()
        ScriptOf    = @{}
        Found       = $false
    }
    $gate = Join-Path $Skill 'scripts\Stage-Ledger.ps1'
    if (-not (Test-Path -LiteralPath $gate)) {
        $out.Note = 'stage table not found: scripts\Stage-Ledger.ps1 is not on disk'
        return $out
    }

    $tokens = $null; $errors = $null; $ast = $null
    try { $ast = [System.Management.Automation.Language.Parser]::ParseFile($gate, [ref]$tokens, [ref]$errors) }
    catch {
        $out.Note = ('stage table not found: parsing Stage-Ledger.ps1 threw: ' + (Get-ShortLine -Value $_.Exception.Message -Max 140))
        return $out
    }
    if ($null -ne $errors -and $errors.Count -gt 0) {
        $out.Note = ("stage table not found: Stage-Ledger.ps1 does not parse (line {0}: {1})" -f $errors[0].Extent.StartLineNumber, (Get-ShortLine -Value $errors[0].Message -Max 120))
        return $out
    }

    $assign = $null
    $assignCount = 0
    foreach ($asn in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true)) {
        if ("$($asn.Left.Extent.Text)".Trim() -ne '$script:LedgerStages') { continue }
        $assignCount++
        if ($null -eq $assign) { $assign = $asn }
    }
    if ($null -eq $assign) {
        $out.Note = 'stage table not found: no assignment to $script:LedgerStages in scripts\Stage-Ledger.ps1'
        return $out
    }
    if ($assignCount -gt 1) {
        #  Reported, not silently taken from the first. Two assignments to the
        #  one table is two sources of truth inside the file that exists to be
        #  the only one.
        $out.Note = ("{0} assignments to the stage table were found; the first is read and the rest are a finding for the ledger's own author" -f $assignCount)
    }

    $rows = New-Object System.Collections.Generic.List[object]
    $problems = New-Object System.Collections.Generic.List[string]
    foreach ($ht in $assign.Right.FindAll({ param($n) $n -is [System.Management.Automation.Language.HashtableAst] }, $true)) {
        $row = [ordered]@{ Key = ''; Required = $false; Blocking = $false; Conditional = $false; Terminal = $false; Script = '' }
        $seen = @{}
        foreach ($pair in $ht.KeyValuePairs) {
            $k = "$($pair.Item1.Extent.Text)".Trim().Trim("'", '"')
            $vTxt = "$($pair.Item2.Extent.Text)".Trim()
            $seen[$k] = $true
            switch -Regex ($k) {
                '^(?i)key$'         { $row.Key = $vTxt.Trim("'", '"'); break }
                '^(?i)script$'      { $row.Script = $vTxt.Trim("'", '"'); break }
                '^(?i)required$'    { $row.Required = ($vTxt -imatch '^\$true$'); break }
                '^(?i)blocking$'    { $row.Blocking = ($vTxt -imatch '^\$true$'); break }
                '^(?i)conditional$' { $row.Conditional = ($vTxt -imatch '^\$true$'); break }
                '^(?i)terminal$'    { $row.Terminal = ($vTxt -imatch '^\$true$'); break }
                default { }
            }
        }
        if (-not $row.Key) { continue }
        foreach ($need in @('Required', 'Blocking')) {
            if (-not $seen.ContainsKey($need)) { $problems.Add(("stage '{0}' declares no {1} column" -f $row.Key, $need)) }
        }
        $rows.Add([pscustomobject]$row)
    }

    if ($rows.Count -eq 0) {
        $out.Note = 'stage table not found: the assignment to the stage table holds no rows this reader could read as {Key=...}'
        return $out
    }

    $keys = New-Object System.Collections.Generic.List[string]
    $req = New-Object System.Collections.Generic.List[string]
    $blk = New-Object System.Collections.Generic.List[string]
    $cnd = New-Object System.Collections.Generic.List[string]
    $trm = New-Object System.Collections.Generic.List[string]
    $scriptOf = @{}
    foreach ($r in $rows) {
        if (-not $keys.Contains($r.Key)) { $keys.Add($r.Key) }
        if ($r.Required) { $req.Add($r.Key) }
        if ($r.Blocking) { $blk.Add($r.Key) }
        if ($r.Conditional) { $cnd.Add($r.Key) }
        if ($r.Terminal) { $trm.Add($r.Key) }
        if ($r.Script) { $scriptOf[$r.Key] = $r.Script }
    }
    $out.Source = 'syntax tree of scripts\Stage-Ledger.ps1 (the stage table rows, read as HashtableAst nodes; nothing executed)'
    $out.Keys = $keys.ToArray()
    $out.Required = $req.ToArray()
    $out.Blocking = $blk.ToArray()
    $out.Conditional = $cnd.ToArray()
    $out.Terminal = $trm.ToArray()
    $out.Rows = $rows.ToArray()
    $out.ScriptOf = $scriptOf
    $out.Found = $true
    if ($problems.Count -gt 0) { $out.Note = (($out.Note, ($problems -join '; ') | Where-Object { $_ }) -join '; ') }
    return $out
}

# ---------------------------------------------------------------------------
# '# GATE:' headers against the stage table; the refusal probe set; hashing
# ---------------------------------------------------------------------------

function Get-HeaderReconciliation {
    <#  One row per gate on disk: does its '# GATE:' header agree with the
        stage table? REPORTED during the transition (not every gate carries a
        header yet) - the output says how many do.

        States: AGREE (header stages equal the table's stage set for the
        script), DISAGREE (they differ, both printed), NO-HEADER, and
        NOT-IN-TABLE (a header with no table row to reconcile against, stages
        printed). Independently: a header stage the ledger does not know, a
        malformed clause, or a 'requires=' name that is not a parameter of
        the script is a problem on the row.  #>
    param($FsSet, $DocRows, $Ledger)

    $tableStages = @{}
    foreach ($row in $DocRows) {
        if (-not $row.Name -or -not $row.OnDisk) { continue }
        if (-not $tableStages.ContainsKey($row.Name)) { $tableStages[$row.Name] = New-Object System.Collections.Generic.List[string] }
        foreach ($k in @($row.StageKeys)) { if (-not $tableStages[$row.Name].Contains($k)) { $tableStages[$row.Name].Add($k) } }
    }
    $known = @{}
    if ($null -ne $Ledger) { foreach ($k in @($Ledger.Keys)) { $known["$k"] = $true } }

    $out = New-Object System.Collections.Generic.List[object]
    foreach ($g in $FsSet) {
        $h = $g.GateHeader
        $problems = New-Object System.Collections.Generic.List[string]
        $state = 'NO-HEADER'
        $hdrStages = @()
        $tbl = @()
        if ($tableStages.ContainsKey($g.Name)) { $tbl = @($tableStages[$g.Name]) }
        if ($null -ne $h) {
            $hdrStages = @($h.Stages)
            foreach ($p in @($h.Problems)) { $problems.Add($p) }
            if ($known.Count -gt 0) {
                foreach ($s in $hdrStages) { if (-not $known.ContainsKey($s)) { $problems.Add(("stage '{0}' is not a stage key the ledger knows" -f $s)) } }
                foreach ($s in @($h.Clauses.Keys)) { if (-not $known.ContainsKey("$s")) { $problems.Add(("clause stage '{0}' is not a stage key the ledger knows" -f $s)) } }
            }
            if ($g.Parses) {
                $pset = @{}
                foreach ($pn in @($g.ParamNames)) { $pset["$pn"] = $true }
                foreach ($r in @($h.Requires)) { if (-not $pset.ContainsKey("$r")) { $problems.Add(("requires={0} names no parameter of the script" -f $r)) } }
                foreach ($s in @($h.Clauses.Keys)) { foreach ($r in @($h.Clauses[$s])) { if (-not $pset.ContainsKey("$r")) { $problems.Add(("{0}: {1} names no parameter of the script" -f $s, $r)) } } }
            }
            if ($tbl.Count -eq 0) { $state = 'NOT-IN-TABLE' }
            else {
                $a = @($hdrStages | Sort-Object -Unique); $b = @($tbl | Sort-Object -Unique)
                $same = ($a.Count -eq $b.Count)
                if ($same) { for ($i = 0; $i -lt $a.Count; $i++) { if ("$($a[$i])" -ne "$($b[$i])") { $same = $false } } }
                $state = $(if ($same) { 'AGREE' } else { 'DISAGREE' })
            }
        }
        $out.Add([pscustomobject]@{
            Gate = $g.Name; State = $state; HasHeader = ($null -ne $h)
            HeaderStages = @($hdrStages); TableStages = @($tbl)
            Requires = $(if ($null -ne $h) { @($h.Requires) } else { @() })
            Problems = $problems.ToArray()
        })
    }
    return $out.ToArray()
}

function Get-RefusalProbeSet {
    <#  Which scripts the bare refusal probe may run, and with what.

        THE STAGE TABLE'S Script COLUMN, AND NOTHING ELSE. The first version
        probed every .ps1 in scripts\ with no arguments, which ran
        Patch-GuideTemplateGeometry bare (it resolves a template for itself and
        patches it) and Probe-GenerationEndpoints bare (it spends image
        credit). Those are not gates and nobody asked them anything; the probe
        was a side effect of enumerating a directory.

        So the set is the Script column of the ledger's own stage table - the
        scripts the pipeline actually binds to a stage - and a script outside
        it is NOT PROBED and its row says so rather than being scored as
        "exits 0 on nothing".

        -WhatIf IS ADDED ONLY ON EVIDENCE. A script whose param block declares
        SupportsShouldProcess (read from the CmdletBinding attribute in the
        SYNTAX TREE, never from its name and never from a list here) is probed
        with -WhatIf, so it can refuse without doing anything. A script that
        does NOT declare it is probed WITHOUT -WhatIf and the row records
        that, because passing -WhatIf to a script that cannot take it is a
        parameter-binding error - which exits non-zero and would be read as a
        refusal the script never made.

        WHEN THERE IS NO STAGE TABLE THERE IS NO PROBE SET. It returns empty
        with a reason and the caller carries a named partial. An empty probe
        set is never a clean probe sweep.  #>
    param($Ledger, [Parameter(Mandatory)][string] $Skill)

    $out = [pscustomobject]@{ Set = @{}; Source = ''; Note = ''; Found = $false }
    if ($null -eq $Ledger -or -not $Ledger.Found) {
        $out.Note = 'stage table not found, so no refusal probe could be planned from a Script column'
        return $out
    }
    $dir = Join-Path $Skill 'scripts'
    $set = @{}
    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($row in @($Ledger.Rows)) {
        if (-not $row.Script) { continue }
        $leaf = [System.IO.Path]::GetFileName(("$($row.Script)" -replace '/', '\'))
        if (-not $leaf) { continue }
        if ($leaf -notmatch '(?i)\.ps1$') { $leaf = $leaf + '.ps1' }
        $name = [System.IO.Path]::GetFileNameWithoutExtension($leaf)
        if ($set.ContainsKey($name)) {
            if (-not (@($set[$name].Stages) -contains $row.Key)) { $set[$name].Stages = @($set[$name].Stages) + $row.Key }
            continue
        }
        $file = Join-Path $dir $leaf
        if (-not (Test-Path -LiteralPath $file)) { $missing.Add(("stage {0} names {1}, which is not in scripts\" -f $row.Key, $leaf)); continue }
        $facts = Get-ScriptFacts -File $file
        $whatIf = [bool]$facts.SupportsShouldProcess
        $why = 'its param block does not declare SupportsShouldProcess, so -WhatIf would be a binding error and is not passed; the probe asks only whether it exits 0 on no input'
        if ($whatIf) { $why = 'its CmdletBinding declares SupportsShouldProcess, read from the syntax tree, so the probe passes -WhatIf and it cannot write anything' }
        $set[$name] = [pscustomobject]@{
            Name      = $name
            File      = $file
            Stages    = @($row.Key)
            Blocking  = [bool]$row.Blocking
            Arguments = $(if ($whatIf) { @('-WhatIf') } else { @() })
            WhatIf    = $whatIf
            WhatIfWhy = $why
        }
    }
    $out.Set = $set
    $out.Found = ($set.Count -gt 0)
    $out.Source = ("the Script column of the ledger stage table ({0} rows, {1} distinct script(s))" -f @($Ledger.Rows).Count, $set.Count)
    if ($missing.Count -gt 0) { $out.Note = ($missing -join '; ') }
    if (-not $out.Found -and -not $out.Note) { $out.Note = 'the stage table declares no Script for any stage, so nothing could be probed' }
    return $out
}

function Get-RunnerPlanView {
    <#  What the two runners believe their membership is, read by syntax tree.

        Run-SpineGates derives its bands from each gate's '# GATE:' header, so
        what it publishes is the STAGE VOCABULARY it will accept
        ($script:ValidGateStages): a header naming a stage outside that list is
        a member of nothing, and the runner will say so at run time. It is read
        here so the reconciliation can say it at write time instead.

        Run-Gates plans stages 4 and 7c. Its plan is built from `Entry ...
        -Script <expr>` calls; the entries whose script resolves to a literal
        '*.ps1' are read, and the ones behind a variable are counted as
        UNRESOLVED and named. A reconciliation that quietly dropped the
        unresolved ones would report a clean sweep over half a plan.

        Nothing is executed and neither runner is required to exist: an absent
        or unparseable runner is a NOTE and a named partial, never a pass.  #>
    param([Parameter(Mandatory)][string] $Skill)

    $out = [pscustomobject]@{
        SpineStages = @(); SpineFound = $false; SpineNote = ''
        GatesScripts = @(); GatesUnresolved = @(); GatesFound = $false; GatesNote = ''
    }
    $dir = Join-Path $Skill 'scripts'

    $sp = Join-Path $dir 'Run-SpineGates.ps1'
    if (-not (Test-Path -LiteralPath $sp)) { $out.SpineNote = 'scripts\Run-SpineGates.ps1 is not on disk' }
    else {
        $err = $null; $tok = $null; $ast = $null
        try { $ast = [System.Management.Automation.Language.Parser]::ParseFile($sp, [ref]$tok, [ref]$err) } catch { $ast = $null }
        if ($null -eq $ast -or ($null -ne $err -and $err.Count -gt 0)) { $out.SpineNote = 'scripts\Run-SpineGates.ps1 does not parse, so its stage vocabulary could not be read' }
        else {
            foreach ($asn in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true)) {
                if ("$($asn.Left.Extent.Text)".Trim() -ne '$script:ValidGateStages') { continue }
                try {
                    $v = $asn.Right.SafeGetValue()
                    $out.SpineStages = @(@($v) | ForEach-Object { "$_" } | Where-Object { $_ })
                    $out.SpineFound = ($out.SpineStages.Count -gt 0)
                }
                catch {
                    #  SafeGetValue refuses an ArrayExpressionAst - `@('1','2')`
                    #  is not the ArrayLiteralAst it accepts - so the constants
                    #  are read off the extent instead. Reporting "no
                    #  vocabulary" for a list that is right there would have
                    #  turned every header stage into an unverifiable one.
                    $out.SpineStages = @([regex]::Matches("$($asn.Right.Extent.Text)", "'([^']+)'") | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ })
                    $out.SpineFound = ($out.SpineStages.Count -gt 0)
                }
                break
            }
            if (-not $out.SpineFound -and -not $out.SpineNote) { $out.SpineNote = 'Run-SpineGates.ps1 publishes no stage vocabulary this reader could read as constants' }
        }
    }

    $rg = Join-Path $dir 'Run-Gates.ps1'
    if (-not (Test-Path -LiteralPath $rg)) { $out.GatesNote = 'scripts\Run-Gates.ps1 is not on disk' }
    else {
        $err = $null; $tok = $null; $ast = $null
        try { $ast = [System.Management.Automation.Language.Parser]::ParseFile($rg, [ref]$tok, [ref]$err) } catch { $ast = $null }
        if ($null -eq $ast -or ($null -ne $err -and $err.Count -gt 0)) { $out.GatesNote = 'scripts\Run-Gates.ps1 does not parse, so its 4/7c plan could not be read' }
        else {
            $named = New-Object System.Collections.Generic.List[string]
            $unres = New-Object System.Collections.Generic.List[string]
            foreach ($cmd in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)) {
                $head = "$($cmd.CommandElements[0].Extent.Text)".Trim()
                if ($head -ne 'Entry' -and $head -ne 'New-PlanEntry' -and $head -ne 'New-GateEntry') { continue }
                #  THE TITLE IS PART OF THE PLAN, NOT DECORATION. Three of
                #  Run-Gates' entries carry no -Script at all: the guide, deck
                #  and readability arms are Kind-dispatched and name the gate
                #  they run inside the title - 'GUIDE GATE (Test-GuideRules)'.
                #  Reading only -Script reported Test-GuideRules as absent from
                #  a plan that runs it in two bands.
                $want = ''
                foreach ($el in $cmd.CommandElements) {
                    if ($el -is [System.Management.Automation.Language.CommandParameterAst]) {
                        $pn = "$($el.ParameterName)"
                        $want = ''
                        if ($pn -ieq 'Script' -or $pn -ieq 'Title') { $want = $pn }
                        continue
                    }
                    if (-not $want) { continue }
                    $txt = "$($el.Extent.Text)"
                    if ($want -ieq 'Title') {
                        $want = ''
                        foreach ($tm in [regex]::Matches($txt, '(?<![\w-])(Assert|Check|Test|Get|New|Run|Set|Invoke|Merge|Probe|Stage|Finish)-[A-Za-z0-9]+')) {
                            if (-not $named.Contains($tm.Value)) { $named.Add($tm.Value) }
                        }
                        continue
                    }
                    $want = ''
                    $m = [regex]::Match($txt, "['`"]([A-Za-z0-9_.-]+\.ps1)['`"]")
                    if ($m.Success) {
                        $n = [System.IO.Path]::GetFileNameWithoutExtension($m.Groups[1].Value)
                        if (-not $named.Contains($n)) { $named.Add($n) }
                    }
                    else { $unres.Add((Get-ShortLine -Value $txt -Max 80)) }
                }
            }
            $out.GatesScripts = $named.ToArray()
            $out.GatesUnresolved = @(@($unres) | Select-Object -Unique)
            $out.GatesFound = ($named.Count -gt 0)
            if (-not $out.GatesFound) { $out.GatesNote = 'Run-Gates.ps1 has no plan entry naming a script literal this reader could resolve' }
        }
    }
    return $out
}

function Get-StaticFindings {
    <#  Everything that can be decided WITHOUT SPAWNING A PROCESS, as findings.

        This is the band member. It answers six questions, and each answer is a
        row with a Kind, the gate it is about, whether that gate BLOCKS, and
        the detail a reader needs:

          PARSE-ERROR   the gate does not parse. It runs nothing, and the first
                        version of this harness DROPPED it from the set (an
                        unparseable script has no exit statements, so it "cannot
                        fail"), which is exactly backwards.
          ORPHAN-RECIPE a recipe in this harness names a gate that is not on
                        disk. The fixture can never run, and the recipe count in
                        the banner made it look like cover that does not exist.
          NO-HEADER     a gate script with no '# GATE:' line. Run-SpineGates
                        derives band membership from that line, so a gate
                        without one is in no band and is gated by nobody.
          HEADER        a header naming a stage the ledger stage table does not
                        know, a malformed clause, a disagreement with the
                        gates.md stage table, or a requires= name that is not a
                        parameter of the script.
          PLAN          a header stage no runner will honour: a stage outside
                        Run-SpineGates' vocabulary, or a 4/7c member that
                        Run-Gates' plan does not name.
          NO-COVER      a BLOCKING gate with neither a -SelfTest switch nor a
                        recipe here. The allow-list beside this rule
                        ($script:StaticCoverAllow) carries a written reason per
                        entry and never covers an Assert-/Check-/Test- name.

        Findings on a BLOCKING gate decide the exit. Findings on the rest are
        printed and carried in the report - that is what "split by Blocks"
        means.  #>
    param(
        $FsSet,
        $DocRows,
        $Recipes,
        $Headers,
        $Plans,
        $Ledger
    )

    $rows = New-Object System.Collections.Generic.List[object]
    $blockingOf = @{}
    foreach ($d in @($DocRows)) {
        if (-not $d.Name) { continue }
        if ($d.BlocksYes) { $blockingOf[$d.Name] = $true }
        elseif (-not $blockingOf.ContainsKey($d.Name)) { $blockingOf[$d.Name] = $false }
    }
    function Add-StaticFinding {
        param([string] $Kind, [string] $Gate, [string] $Detail)
        $rows.Add([pscustomobject]@{
            Kind = $Kind; Gate = $Gate; Detail = $Detail
            Blocking = [bool]($blockingOf.ContainsKey($Gate) -and $blockingOf[$Gate])
        })
    }

    $onDisk = @{}
    foreach ($g in @($FsSet)) { $onDisk[$g.Name] = $g }

    foreach ($g in @($FsSet)) {
        if (-not $g.Parses) {
            Add-StaticFinding -Kind 'PARSE-ERROR' -Gate $g.Name -Detail ("does not parse: {0}. A gate with a syntax error runs nothing and proves nothing." -f $g.ParseError)
        }
    }

    foreach ($r in @($Recipes)) {
        if ($null -eq $r -or -not $r.Gate) { continue }
        if ($onDisk.ContainsKey("$($r.Gate)")) { continue }
        $rows.Add([pscustomobject]@{
            Kind = 'ORPHAN-RECIPE'; Gate = "$($r.Gate)"
            Detail = ("this harness holds a fixture recipe ('{0}') for a gate that is not in scripts\, so the recipe can never run and its place in the recipe count is false cover" -f $r.Kind)
            Blocking = $true
        })
    }

    $spineVocab = @()
    if ($null -ne $Plans) { $spineVocab = @($Plans.SpineStages) }
    $planNames = @{}
    if ($null -ne $Plans) { foreach ($n in @($Plans.GatesScripts)) { $planNames["$n"] = $true } }

    foreach ($h in @($Headers)) {
        $isGateName = [regex]::IsMatch($h.Gate, '^(Assert|Check|Test)-')
        if (-not $h.HasHeader) {
            #  Only a script that CLAIMS A VERDICT owes a header. A library or
            #  a renderer in the derived set is not a band member, and a header
            #  on it would say nothing.
            if ($isGateName -or ($blockingOf.ContainsKey($h.Gate) -and $blockingOf[$h.Gate])) {
                Add-StaticFinding -Kind 'NO-HEADER' -Gate $h.Gate -Detail "carries no '# GATE: stages=...; requires=...' line, so Run-SpineGates puts it in no band and no runner threads its inputs"
            }
            continue
        }
        foreach ($p in @($h.Problems)) { Add-StaticFinding -Kind 'HEADER' -Gate $h.Gate -Detail $p }
        if ($h.State -eq 'DISAGREE') {
            #  A SUBSET RULE, NOT AN EQUALITY. The gates.md Stage cell records
            #  the band a gate is DOCUMENTED under; the header records every
            #  band it is a member of, and several gates legitimately run in
            #  more than one. Requiring the two sets to be equal made a finding
            #  out of every correct multi-band header - Assert-Provenance's
            #  '2,3c,4,7c' against a cell that says '2' - which is the false
            #  half of a report nobody then reads. What IS a contradiction is
            #  a header that DROPS a band the documentation binds it to: that
            #  gate leaves a band by editing its own header.
            $missing = @(@($h.TableStages) | Where-Object { @($h.HeaderStages) -notcontains "$_" })
            if ($missing.Count -gt 0) {
                Add-StaticFinding -Kind 'HEADER' -Gate $h.Gate -Detail ("the gates.md stage table binds it to {0} and its header says stages={1} - it drops {2}, so that band would run without it" -f (@($h.TableStages) -join ','), (@($h.HeaderStages) -join ','), ($missing -join ','))
            }
            else {
                $rows.Add([pscustomobject]@{
                    Kind = 'HEADER-EXTRA'; Gate = $h.Gate; Blocking = $false
                    Detail = ("its header says stages={0}, more than the gates.md cell's {1}. Reported so the cell can be widened; a header may name more bands than the documentation records." -f (@($h.HeaderStages) -join ','), (@($h.TableStages) -join ','))
                })
            }
        }
        if ($spineVocab.Count -gt 0) {
            foreach ($s in @($h.HeaderStages)) {
                if ($spineVocab -contains "$s") { continue }
                #  A STAGE WITH ITS OWN RUNNER IS NOT AN ORPHAN. Stage 0 is not
                #  in Run-SpineGates' vocabulary because Run-SpineGates does not
                #  run it - the ledger stage table names the script that does.
                #  Reading the band runner's vocabulary as the whole pipeline
                #  reported the Stage 0 runner's own header as belonging to
                #  nothing.
                if ($null -ne $Ledger -and $Ledger.Found -and $Ledger.ScriptOf.ContainsKey("$s")) { continue }
                Add-StaticFinding -Kind 'PLAN' -Gate $h.Gate -Detail ("its header declares stage '{0}', which is outside Run-SpineGates' stage vocabulary ({1}) and the ledger stage table names no script for that stage, so no runner will pick it up" -f $s, ($spineVocab -join ', '))
            }
        }
        if ($planNames.Count -gt 0) {
            foreach ($s in @($h.HeaderStages)) {
                if (@('4', '7c') -notcontains "$s") { continue }
                if (-not $planNames.ContainsKey($h.Gate)) {
                    Add-StaticFinding -Kind 'PLAN' -Gate $h.Gate -Detail ("its header declares stage {0} and Run-Gates' plan names no entry for it, so the stage {0} band would run without it" -f $s)
                }
            }
        }
    }

    $recipeFor = @{}
    foreach ($r in @($Recipes)) { if ($null -ne $r -and $r.Gate) { $recipeFor["$($r.Gate)"] = $true } }
    foreach ($g in @($FsSet)) {
        if (-not ($blockingOf.ContainsKey($g.Name) -and $blockingOf[$g.Name])) { continue }
        if ($g.HasSelfTest -or $recipeFor.ContainsKey($g.Name)) { continue }
        if ($script:StaticCoverAllow.Contains($g.Name) -and -not [regex]::IsMatch($g.Name, '^(Assert|Check|Test)-')) { continue }
        Add-StaticFinding -Kind 'NO-COVER' -Gate $g.Name -Detail 'a BLOCKING gate with neither a -SelfTest switch nor a seeded-defect recipe in this harness: nothing anywhere proves it can fail'
    }

    return $rows.ToArray()
}

function Get-ScriptsHash {
    <#  sha256 over the bytes of every scripts\*.ps1 (sorted by name) plus the
        recipe set (gate, kind, claim and every scriptblock's text), so a
        result file can say which scripts and which recipes its verdicts are
        about, and a reader can tell a stale one from a current one.  #>
    param([Parameter(Mandatory)][string] $Skill, $Recipes)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    $ms = New-Object System.IO.MemoryStream
    try {
        $dir = Join-Path $Skill 'scripts'
        foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter '*.ps1' -File -ErrorAction SilentlyContinue | Sort-Object Name)) {
            $nb = [System.Text.Encoding]::UTF8.GetBytes($f.Name + "`n")
            $ms.Write($nb, 0, $nb.Length)
            $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
            $ms.Write($bytes, 0, $bytes.Length)
        }
        foreach ($r in @($Recipes)) {
            if ($null -eq $r) { continue }
            $sb = New-Object System.Text.StringBuilder
            [void]$sb.Append("recipe`n").Append("$($r.Gate)`n").Append("$($r.Kind)`n")
            foreach ($p in $r.PSObject.Properties) {
                if ($p.Value -is [scriptblock]) { [void]$sb.Append($p.Name).Append("`n").Append($p.Value.ToString()).Append("`n") }
                elseif ($p.Value -is [string]) { [void]$sb.Append($p.Name).Append('=').Append($p.Value).Append("`n") }
            }
            $rb = [System.Text.Encoding]::UTF8.GetBytes($sb.ToString())
            $ms.Write($rb, 0, $rb.Length)
        }
        $ms.Position = 0
        return ([BitConverter]::ToString($sha.ComputeHash($ms)).Replace('-', '').ToLowerInvariant())
    }
    finally { $sha.Dispose(); $ms.Dispose() }
}

#  THE STATIC RULE'S ALLOW-LIST, beside the rule it weakens. A BLOCKING gate
#  with neither a self-test switch nor a recipe in this harness is a FAIL in
#  -StaticOnly. The scripts below are in the derived set because they can
#  exit non-zero, but they are libraries, renderers or tools, not gates: they
#  decide no verdict about a build, so a plant has nothing to make them fail
#  ON. Each carries the reason. A gate-named script (Assert-/Check-/Test-) is
#  never allow-listed here: it claims a verdict, so it owes a proof.
$script:StaticCoverAllow = [ordered]@{
    'Lib-Resolve'                  = 'library: resolves sibling skills and loads libraries; throws on a missing one, decides nothing about a build'
    'Pptx-Blocks'                  = 'library: slide-building primitives dot-sourced by the deck renderer'
    'Xml-Scan'                     = 'library: OOXML part scanning primitives used by the gates, no verdict of its own'
    'Build-Guide'                  = 'renderer: writes the guide from the spine; its output is gated by Test-GuideRules and the 4/7c band'
    'Set-ResourceBrand'            = 'renderer step: applies the palette; the mark is PROVED afterwards by Check-Identity (stage 4c)'
    'Patch-GuideTemplateGeometry'  = 'tool: one-off template geometry patch, ShouldProcess-guarded; its effect is gated by Test-GuideRules content width'
    'New-WithholdRegister'         = 'producer: derives the register at Stage 2; enforced by Assert-WithholdRegister, Check-ShapeMirror and Check-FigureMirror, which carry the proofs'
    'New-FigureSheet'              = 'producer: cuts the figure sheet; refusal on a failed band is the P0-07 proof owned by its own self-test once landed'
    'Get-DocText'                  = 'producer: text extracts with a stamp; every rendered-arm gate consumes it and proves against it'
}


# ---------------------------------------------------------------------------
# What does this gate actually CLAIM to catch?
# ---------------------------------------------------------------------------

function Get-GateSectionText {
    <#  Every section of gates.md that mentions this gate by name.

        The stage table says which section documents a gate, but the sentence
        that matters may sit in a different one: the sentence recording that an
        unregistered figure PASSES the registry gate lives in the section for
        the gate written to replace it. So the search is by name, over the whole
        file, and every hit is kept.  #>
    param([AllowEmptyString()][string] $DocText, [Parameter(Mandatory)][string] $Name)

    if (-not $DocText) { return '' }
    $chunks = New-Object System.Collections.Generic.List[string]
    $parts = [regex]::Split($DocText, '(?m)^##\s')
    foreach ($p in $parts) {
        if ($p.IndexOf($Name, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $chunks.Add($p) }
    }
    return ($chunks -join "`n")
}

function Get-DisclaimerSentence {
    <#  Sentences that mention the gate AND disclaim a capability.

        These are not a verdict. They are evidence handed to the reader beside
        the fixture result, because a builder reading "PROVEN" next to a gate
        the specification says performs nothing has been told two things that
        cannot both be true.  #>
    param([AllowEmptyString()][string] $SectionText, [Parameter(Mandatory)][string] $Name)

    $out = New-Object System.Collections.Generic.List[string]
    if (-not $SectionText) { return $out.ToArray() }
    $flat = [regex]::Replace($SectionText, '\s+', ' ')
    foreach ($m in [regex]::Matches($flat, '[^.]*?' + [regex]::Escape($Name) + '[^.]*\.')) {
        $s = $m.Value.Trim()
        if ([regex]::IsMatch($s, '(?i)(passes it|checks [a-z ]{0,40}only|not yet implemented|performed by nobody|must be inverted|does not (catch|check|see|read|implement)|no (script|gate|wrapper) )')) {
            $out.Add((Get-ShortLine -Value $s -Max 260))
        }
    }
    return $out.ToArray()
}

function Test-GateClaim {
    <#  Is the claim this recipe tests one the gate actually makes?

        ESTABLISHED only when the recipe's ClaimRx matches the gate's OWN
        HEADER - the contract the gate publishes about itself. Not gates.md,
        which describes what a check SHOULD do and is full of specifications
        for gates nobody has written; not the parameter names, which say what
        it reads and not what it decides.

        This one rule is what would have stopped the false HIGH: to assert that
        the registry gate failed to catch an unregistered figure, the harness
        would have had to point at a sentence in that gate's own header saying
        it catches them, and there is none.  #>
    param($Facts, $Recipe, [string] $SectionText)

    $result = [pscustomobject]@{
        State    = 'UNKNOWN'
        Evidence = ''
        Disclaimers = @()
    }
    if ($null -eq $Recipe) { return $result }
    $result.Disclaimers = Get-DisclaimerSentence -SectionText $SectionText -Name $Facts.Name

    $rx = ''
    if ($null -ne $Recipe.PSObject.Properties['ClaimRx']) { $rx = "$($Recipe.ClaimRx)" }
    if (-not $rx) {
        $result.State = 'UNKNOWN'
        return $result
    }
    $header = ''
    try {
        $src = Read-FixtureText -File $Facts.File
        $m = [regex]::Match($src, '(?s)^\s*<#(.*?)#>')
        if ($m.Success) { $header = $m.Groups[1].Value }
    }
    catch { $header = '' }
    if (-not $header) {
        $result.State = 'UNKNOWN'
        return $result
    }
    $hm = [regex]::Match($header, $rx)
    if ($hm.Success) {
        $result.State = 'ESTABLISHED'
        $result.Evidence = Get-ShortLine -Value $hm.Value -Max 200
    }
    return $result
}

# ---------------------------------------------------------------------------
# Reading a spine the way a spine gate reads it - by its ACTUAL field names
# ---------------------------------------------------------------------------

function Get-SpineLeaf {
    <#  Every string leaf in a spine file, with the key that holds it.

        DERIVED, NOT GUESSED. The first version of the spine recipes looked for
        fields called "text", "body" or "prose". This spine calls its prose
        "whatThisMeans" and holds it as an ARRAY of strings, so the plant never
        wrote anything and two gates were reported unproven for a reason that
        was the harness's fault rather than theirs.  #>
    param($Node, [string] $Key = '', $Bag, [int] $Depth = 0)

    if ($Depth -gt 12 -or $null -eq $Node) { return }
    if ($Node -is [string]) {
        $s = "$Node"
        if ($s.Length -ge 1) {
            [void]$Bag.Add([pscustomobject]@{ Key = $Key; Value = $s; Words = @([regex]::Split($s.Trim(), '\s+')).Count })
        }
        return
    }
    if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string])) {
        foreach ($item in $Node) { Get-SpineLeaf -Node $item -Key $Key -Bag $Bag -Depth ($Depth + 1) }
        return
    }
    if ($Node -is [psobject] -and $null -ne $Node.PSObject) {
        foreach ($p in $Node.PSObject.Properties) {
            Get-SpineLeaf -Node $p.Value -Key "$($p.Name)" -Bag $Bag -Depth ($Depth + 1)
        }
    }
}

# ---------------------------------------------------------------------------
# The clean baseline - a lean copy of a real build
# ---------------------------------------------------------------------------

function New-LeanBuildCopy {
    <#  Copy the parts of a build a spine gate reads, and nothing else.

        The rendered artefacts and the generated images are tens of megabytes
        and no spine gate opens them; the backups are older copies of the same
        spine and copying them would give a gate two sources of truth for the
        same topic.  #>
    param([Parameter(Mandatory)][string] $Source, [Parameter(Mandatory)][string] $Dest)

    New-Item -ItemType Directory -Force -Path $Dest | Out-Null
    $copied = 0
    foreach ($item in (Get-ChildItem -LiteralPath $Source -Force -ErrorAction SilentlyContinue)) {
        if ($item.PSIsContainer) {
            if ([regex]::IsMatch($item.Name, '(?i)(backup|_bak|^out$|^out_|^images$|^review$|^cleanroom$)')) { continue }
            Copy-Item -LiteralPath $item.FullName -Destination (Join-Path $Dest $item.Name) -Recurse -Force -ErrorAction SilentlyContinue
            $copied++
            continue
        }
        if ($item.Length -gt 8000000) { continue }
        if ([regex]::IsMatch($item.Name, '(?i)(backup|_bak)')) { continue }
        if ($item.Extension -notmatch '(?i)^\.(json|md|txt|csv)$') { continue }
        Copy-Item -LiteralPath $item.FullName -Destination (Join-Path $Dest $item.Name) -Force -ErrorAction SilentlyContinue
        $copied++
    }
    return $copied
}

function Get-SpineFile {
    <# The spine files of a build, largest first: the biggest has the most prose. #>
    param([Parameter(Mandatory)][string] $Dir)
    $sd = Join-Path $Dir 'spine'
    if (-not (Test-Path -LiteralPath $sd)) { return @() }
    return @(Get-ChildItem -LiteralPath $sd -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object Length -Descending)
}

# ---------------------------------------------------------------------------
# The recipes - what each gate claims to catch, and how to plant it
# ---------------------------------------------------------------------------
#
#  A recipe is per-gate knowledge and there is no way around that: what counts
#  as "a defect of the kind this gate claims to catch" is different for every
#  gate. What is NOT hand-listed is the gate set - that is enumerated from disk
#  and from gates.md - so a gate with no recipe here is REPORTED, as UNPROVEN
#  with the reason, rather than quietly falling out of the set.

function Get-FixtureStem {
    <#  The register's own crude suffix stem (ing, ed, es, s), reproduced so a
        fixture's content-word sets are COMPUTED through the pipeline the
        cells declare, never hand-typed. A hand-typed stem that is wrong makes
        a gate look unable to fire when the truth is that the fixture could
        not be matched.  #>
    param([string] $Word)
    $w = $Word
    if ($w.Length -gt 5 -and $w.EndsWith('ing')) { return $w.Substring(0, $w.Length - 3) }
    if ($w.Length -gt 4 -and $w.EndsWith('ed'))  { return $w.Substring(0, $w.Length - 2) }
    if ($w.Length -gt 4 -and $w -match '(ss|sh|ch|x|z)es$') { return $w.Substring(0, $w.Length - 2) }
    if ($w.Length -gt 3 -and $w.EndsWith('s') -and -not $w.EndsWith('ss')) { return $w.Substring(0, $w.Length - 1) }
    return $w
}

function Get-FixtureWords {
    <#  Content words of a fixture bullet: lower-cased, letters only, crude
        stem, with the function words the sentence needs dropped. Every word
        left is a content word under every gate's stopword list, which is why
        the fixture bullets are written the way they are.  #>
    param([string] $Text)
    $stop = @('a', 'an', 'and', 'the', 'with', 'or', 'of', 'in', 'on', 'that', 'under', 'at', 'to', 'its', 'it', 'is', 'are')
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($tok in (($Text.ToLowerInvariant() -replace '[^a-z0-9 ]', ' ') -split '\s+')) {
        if (-not $tok -or $tok.Length -lt 2) { continue }
        if ($stop -contains $tok) { continue }
        $s = Get-FixtureStem $tok
        if (-not $out.Contains($s)) { $out.Add($s) }
    }
    return $out.ToArray()
}

#  The round-6 grid: one labelled task, six assessed items, one assessed
#  column of spoilage indicators. Every bullet uses vocabulary no other bullet
#  uses, so the shape gate's document-frequency ceiling (a word in more than a
#  quarter of all bullets is not evidence of copying) strips nothing.
$script:Round6Headers = @('Food item', 'Spoilage indicators', 'Action at the door')
$script:Round6Rows = @(
    [pscustomobject]@{ Item = 'Fresh whole fish';       Text = 'dull sunken eyes and slimy grey gills with an ammonia smell' }
    [pscustomobject]@{ Item = 'Chicken breast fillets'; Text = 'tacky surface, greenish tinge and a sour odour under the wrap' }
    [pscustomobject]@{ Item = 'Cos lettuce';            Text = 'wilted limp leaves with brown edges and watery ribs' }
    [pscustomobject]@{ Item = 'Soft ripened cheese';    Text = 'pink or black mould spots and a bitter sharp taste' }
    [pscustomobject]@{ Item = 'Cooked rice';            Text = 'clumped sticky grains that feel warm, with a musty stale scent' }
    [pscustomobject]@{ Item = 'Fresh milk';             Text = 'curdled lumps, a swollen carton and an acidic tang' }
)
foreach ($row in $script:Round6Rows) { Add-Member -InputObject $row -NotePropertyName 'Words' -NotePropertyValue @(Get-FixtureWords -Text $row.Text) -Force }

function New-Round6Fixture {
    <#  A lean fixture build for the round-6 recipes: register, gate-only
        cells, a learner-facing corpus with Stage 1's typed grid parse, two
        renderer stubs (the withhold gate derives channel ownership from the
        field names a renderer reads), and a CLEAN spine for sub-section 1.4
        that teaches spoilage without naming a row beside its answer. Every
        value is synthetic; no real pack's model answer is in here.  #>
    param([Parameter(Mandatory)][string] $Root)

    New-Item -ItemType Directory -Force -Path (Join-Path $Root 'spine') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $Root 'corpus') | Out-Null
    $rows = $script:Round6Rows
    $items = @($rows | ForEach-Object { $_.Item })
    $taskRef = 'Task 6(a)'
    $taskId = 'FIXTURE_UAT Task 6(a)'

    Write-FixtureText -File (Join-Path $Root 'contract.json') -Body ([ordered]@{
        build = [ordered]@{ brand = 'FIXTURE' }
        unit = [ordered]@{ code = 'FIXTURE' }
        wordFloors = [ordered]@{ topic = 50; underpinningKnowledge = 20 }
    } | ConvertTo-Json -Depth 6)

    #  Renderer stubs: the field names each reads decide which artefact a
    #  spine channel belongs to.
    Write-FixtureText -File (Join-Path $Root 'Build-Guide-Fixture.ps1') -Body @'
param($node)
$null = $node.whatThisMeans
$null = $node.underpinningKnowledge
$null = $node.visuals
$null = $node.selfCheck.questions
$null = $node.title
$null = $node.ref
'@
    Write-FixtureText -File (Join-Path $Root 'Build-Deck-Fixture.ps1') -Body @'
param($node)
$null = $node.slides
foreach ($s in $node.slides) { $null = $s.headline; $null = $s.bullets; $null = $s.notes }
'@

    #  The learner-facing corpus and Stage 1's typed grid parse.
    $toolLines = New-Object System.Collections.Generic.List[string]
    $toolLines.Add('FIXTURE_UAT - Unit Assessment Tool (fixture)')
    $toolLines.Add('Task 6 Receiving deliveries')
    $toolLines.Add('(a) For each food item below, list the spoilage indicators you would look for and the action you would take at the door.')
    $toolLines.Add(($script:Round6Headers -join ' | '))
    foreach ($it in $items) { $toolLines.Add(("{0} | Write here | Write here" -f $it)) }
    $toolLines.Add('Task 7 Storage temperatures')
    Write-FixtureText -File (Join-Path $Root 'corpus\FIXTURE_UAT.txt') -Body (($toolLines -join "`r`n") + "`r`n")
    Write-FixtureText -File (Join-Path $Root 'corpus\manifest.json') -Body ([ordered]@{
        documents = @([ordered]@{ file = 'FIXTURE_UAT.txt'; audience = 'learner' })
    } | ConvertTo-Json -Depth 6)
    Write-FixtureText -File (Join-Path $Root 'corpus\grids.json') -Body ([ordered]@{
        _purpose = 'fixture: Stage 1 typed parse of the assessed response grids'
        grids = @([ordered]@{ doc = 'FIXTURE_UAT'; id = $taskId; ref = $taskRef; labels = $items; headers = @($script:Round6Headers); kind = 'labelled' })
    } | ConvertTo-Json -Depth 6)

    $aliases = [ordered]@{}
    foreach ($it in $items) { $aliases[$it] = @() }
    Write-FixtureText -File (Join-Path $Root 'withhold-register.json') -Body ([ordered]@{
        unit = 'FIXTURE'
        documents = [ordered]@{ FIXTURE_UAT = [ordered]@{ audience = 'learner'; referencePattern = 'Task {n}({part})' } }
        subSections = [ordered]@{
            '1.4' = [ordered]@{
                subSection = '1.4'
                refs = @($taskRef)
                tasks = @([ordered]@{
                    ref = $taskRef; id = $taskId; document = 'FIXTURE_UAT'; kind = 'labelled'
                    headers = @($script:Round6Headers); assessedHeaders = @(1)
                    items = $items; prefilledItems = @(); aliases = $aliases
                    subjectClass = 'food'; subjects = @(); unassessedSubjects = @('Dry pasta')
                    allowance = 1
                    permittedGround = 'Set the worked example on dry pasta, which this task does not assess.'
                    shape = [ordered]@{ rows = 6; assessedColumns = 1; benchmarkMinimum = 1; wordGuide = [ordered]@{ min = 5; max = 20 } }
                })
                freeText = @(); observations = @()
            }
        }
        unclassified = @(); unresolvedReferences = @()
    } | ConvertTo-Json -Depth 10)

    $cellRows = New-Object System.Collections.Generic.List[object]
    foreach ($row in $rows) {
        $cellRows.Add([ordered]@{
            item = $row.Item; assessed = $true
            cells = @(
                [ordered]@{ col = 1; header = $script:Round6Headers[1]; state = 'answered'; bullets = @([ordered]@{ text = $row.Text; words = @($row.Words) }) },
                [ordered]@{ col = 2; header = $script:Round6Headers[2]; state = 'answered'; bullets = @([ordered]@{ text = 'reject it at the door and record the rejection'; words = @('reject', 'door', 'record', 'rejection') }) }
            )
        })
    }
    Write-FixtureText -File (Join-Path $Root 'assessor-cells.json') -Body ([ordered]@{
        _WARNING = 'GATE-ONLY fixture written by Assert-GateFixtures. Synthetic content; no real model answer appears here.'
        wordPipeline = [ordered]@{
            normalise = 'lower case, letters digits and single spaces only'
            stem = 'crude suffix strip: ing, ed, es, s'
            stopwords = 176
            stripLearnerWords = 'every word in the learner-facing text of the same task'
            dfCeiling = 0.25
        }
        grids = @([ordered]@{
            ref = $taskRef; id = $taskId; subSection = '1.4'; kind = 'labelled'; document = 'FIXTURE_UAT'
            headers = @($script:Round6Headers); assessedHeaders = @(1); rowSource = 'modelRows'
            rows = $cellRows.ToArray(); extraPoints = @()
        })
        freeText = @(); taskLevel = @()
    } | ConvertTo-Json -Depth 12)

    #  The CLEAN spine: mechanism, not the row beside its answer.
    Write-FixtureText -File (Join-Path $Root 'spine\t1_1.4.json') -Body ([ordered]@{
        ref = '1.4'; pc = '1.4'; topic = 1; title = 'Checking deliveries at the door'
        whatThisMeans = @(
            'Every delivery is checked at the door before it is signed for, because a rejected item costs nothing and an accepted one is yours.',
            'Dry pasta is the example this sub-section works, since the assessment does not ask about it.'
        )
        remember = 'Look, smell, touch, then decide - and write the decision down.'
        underpinningKnowledge = @(
            'Spoilage is a process, and the senses catch it in order: sight first, then smell, then touch.',
            'A cold chain that was broken shows up as condensation inside packaging long before anything smells wrong.',
            'Dry pasta arriving damp or with a split bag is refused and the refusal is written on the delivery docket.',
            'The action at the door is always the same shape: refuse, isolate, record, tell the supplier.'
        )
        regulatoryBasis = @('The Food Standards Code requires food to be received in a condition fit for its intended use.')
        selfCheck = [ordered]@{
            questions = @('What is the first sense you use at the door, and why?')
            answerGuide = @('Points to the teaching above rather than to a model answer.')
        }
        assessmentLink = [ordered]@{ refs = @($taskRef); wording = 'Prepares you for: Task 6(a).' }
        visuals = @([ordered]@{ slot = '1.4.1'; kind = 'Image'; caption = 'Figure 1.4.1 A delivery being checked at the door'; alt = 'A cook checking a delivery on a trolley.'; prompt = 'A commercial kitchen back door, a delivery on a trolley, a cook with a probe thermometer.' })
        slides = @([ordered]@{ layout = 'single'; kind = 'teaching'; headline = 'Check it at the door'; bullets = @('Sight, smell, touch, decide.'); notes = 'Work the dry pasta example on the board.' })
        openQuestions = @(); provenance = @()
    } | ConvertTo-Json -Depth 12)
    Write-FixtureText -File (Join-Path $Root 'spine\t1_topic.json') -Body ([ordered]@{
        number = 1; element = '1'; title = 'Receiving and storing'; elementText = 'Receive and store stock'
        overview = 'The fixture topic exists so the sweep has more than one file to read.'
        outcomes = @('Check a delivery at the door.'); summary = @('Refuse what has turned.')
        slides = @([ordered]@{ layout = 'single'; kind = 'title'; headline = 'Receiving and storing'; bullets = @('Fixture'); notes = 'Open the topic.' })
        openQuestions = @(); provenance = @()
    } | ConvertTo-Json -Depth 8)
    return $Root
}

function Get-FixtureRecipe {
    param([Parameter(Mandatory)][string] $Skill)

    $r = New-Object System.Collections.Generic.List[object]

    $r.Add([pscustomobject]@{
        Gate  = 'Test-Spine'
        Kind  = 'a topic whose prose is far below the word floor'
        ClaimRx = '(?i)(floors\s+underpinning|underpinningKnowledge|naming the floor|word floor)'
        Plant = {
            param($fx)
            $files = Get-SpineFile -Dir $fx.Dir
            if ($files.Count -eq 0) { return $null }
            $target = $files[0]
            $body = Read-FixtureText -File $target.FullName
            $obj = $null
            try { $obj = ($body | ConvertFrom-Json) } catch { return $null }
            #  Find THE PROSE, by measuring it, rather than by guessing what it
            #  is called. Every long string leaf in the file is collapsed, so a
            #  word-floor gate has nothing left to count.
            $bag = New-Object System.Collections.Generic.List[object]
            Get-SpineLeaf -Node $obj -Bag $bag
            $long = @($bag | Where-Object { $_.Words -ge 12 })
            if ($long.Count -eq 0) { return $null }
            $marker = 'PLANTEDSHORTTOPIC'
            $new = $body
            $done = 0
            foreach ($leaf in $long) {
                $needle = '"' + $leaf.Value.Replace('\', '\\').Replace('"', '\"') + '"'
                if ($new.IndexOf($needle, [System.StringComparison]::Ordinal) -lt 0) { continue }
                $new = $new.Replace($needle, ('"' + $marker + ' three words"'))
                $done++
            }
            if ($done -eq 0) { return $null }
            Write-FixtureText -File $target.FullName -Body $new
            return [pscustomobject]@{ Token = $marker; Channel = $target.FullName; Describe = ("{0} prose leaves collapsed to three words in {1}" -f $done, $target.Name) }
        }
        NameInOutputFallback = $true
        Verify = {
            param($fx, $plant)
            $back = Read-FixtureText -File $plant.Channel
            return ($back.IndexOf($plant.Token, [System.StringComparison]::Ordinal) -ge 0)
        }
        Args = { param($fx) @('-BuildDir', $fx.Dir) }
        NameInOutput = 'word'
    })

    $r.Add([pscustomobject]@{
        Gate  = 'Test-SpineRead'
        Kind  = 'an authored field on the spine that no renderer reads'
        #  THE GATE'S ACTUAL CLAIM, from its own report line: "is every
        #  authored field actually rendered?". The first version of this recipe
        #  changed a block-kind VALUE, which proves nothing - the gate compares
        #  authored field NAMES against the names the renderers read. A field
        #  nobody renders is content the author wrote and no reader will ever
        #  see, and that is what it exists to catch.
        ClaimRx = '(?i)(renderer|is every authored field|unread|actually rendered|MISSING output)'
        #  Two of this build's four renderers live in the build directory and
        #  two in the skill. A fixture carrying only the spine finds half the
        #  renderer set, reports every field the other half reads as unread,
        #  and the gate exits 14 to say the renderer set looks incomplete -
        #  which is the gate telling the harness its fixture is invalid.
        Prepare = {
            param($fx)
            $origin = $script:FixtureOriginBuild
            if (-not $origin) { return }
            foreach ($pattern in @('Build-*.ps1', 'Render-*.ps1')) {
                foreach ($r in @(Get-ChildItem -Path (Join-Path $origin $pattern) -File -ErrorAction SilentlyContinue)) {
                    Copy-Item -LiteralPath $r.FullName -Destination $fx.Dir -Force -ErrorAction SilentlyContinue
                }
            }
        }
        Plant = {
            param($fx)
            $files = Get-SpineFile -Dir $fx.Dir
            if ($files.Count -eq 0) { return $null }
            $target = $files[0]
            $body = Read-FixtureText -File $target.FullName
            $marker = 'plantedFieldNoRendererReads'
            #  Add a NEW authored field. Inserted after the opening brace so the
            #  document stays valid JSON, which is checked by parsing it back.
            $i = $body.IndexOf('{', [System.StringComparison]::Ordinal)
            if ($i -lt 0) { return $null }
            $new = $body.Substring(0, $i + 1) + ("`r`n    `"{0}`": `"Planted prose that no renderer will ever put on a page.`"," -f $marker) + $body.Substring($i + 1)
            Write-FixtureText -File $target.FullName -Body $new
            return [pscustomobject]@{ Token = $marker; Channel = $target.FullName; Describe = ('an unrendered field added to ' + $target.Name) }
        }
        Verify = {
            param($fx, $plant)
            $back = Read-FixtureText -File $plant.Channel
            if ($back.IndexOf($plant.Token, [System.StringComparison]::Ordinal) -lt 0) { return $false }
            #  The plant has to leave the file READABLE, or the gate fails on a
            #  parse error and the harness scores that as catching the defect.
            try { $null = ($back | ConvertFrom-Json) } catch { return $false }
            return $true
        }
        Args = { param($fx) @('-BuildDir', $fx.Dir, '-SkillDir', $fx.Skill) }
        NameInOutput = 'plantedFieldNoRendererReads'
    })
    $r.Add([pscustomobject]@{
        Gate  = 'Test-FigureConsistency'
        Kind  = 'a REGISTERED figure gone stale - a value the registry forbids, alive in the rendered text'
        #  The gate's own header: "ONE FIGURE, ONE VALUE, EVERYWHERE", enforced
        #  from a registry of forbid / require entries. That is what it claims,
        #  and so that is what the plant is. An UNREGISTERED figure is section
        #  17's job and is documented as passing this gate; a fixture asserting
        #  otherwise is testing a claim nobody made.
        ClaimRx = '(?i)(forbid|stale value|ONE FIGURE, ONE VALUE|figures registry|registry \(figures\.json\))'
        Plant = {
            param($fx)
            #  The forbidden literal is READ OUT OF THIS BUILD'S OWN REGISTRY,
            #  never typed. A hand-typed stale value would be a second source of
            #  truth and would drift from the map the gate actually enforces.
            $reg = Join-Path $fx.Dir 'figures.json'
            if (-not (Test-Path -LiteralPath $reg)) { return $null }
            $rules = $null
            try { $rules = (Read-FixtureText -File $reg | ConvertFrom-Json) } catch { return $null }
            if ($null -eq $rules -or $null -eq $rules.PSObject.Properties['figures']) { return $null }
            $lit = ''
            $figName = ''
            foreach ($fig in @($rules.figures)) {
                if ($null -eq $fig -or $null -eq $fig.PSObject.Properties['forbid']) { continue }
                foreach ($v in @($fig.forbid)) {
                    if ($v -and "$v".Trim().Length -ge 3) { $lit = "$v".Trim(); $figName = "$($fig.name)"; break }
                }
                if ($lit) { break }
            }
            if (-not $lit) { return $null }
            $extract = Join-Path $fx.Dir 'planted-extract.txt'
            Write-FixtureText -File $extract -Body ("Body text before the figure.`r`nThe batch figure is " + $lit + " for this run.`r`nBody text after it.`r`n")
            return [pscustomobject]@{ Token = $lit; Channel = $extract; Describe = ("a value the registry forbids for '" + $figName + "', planted into a rendered text extract") }
        }
        Verify = {
            param($fx, $plant)
            $back = Read-FixtureText -File $plant.Channel
            return ($back.IndexOf($plant.Token, [System.StringComparison]::Ordinal) -ge 0)
        }
        Args = { param($fx) @('-BuildDir', $fx.Dir, '-DocText', (Join-Path $fx.Dir 'planted-extract.txt')) }
        CleanArgs = { param($fx) @('-BuildDir', $fx.Dir, '-DocText', (Join-Path $fx.Dir 'clean-extract.txt')) }
        Prepare = {
            param($fx)
            Write-FixtureText -File (Join-Path $fx.Dir 'clean-extract.txt') -Body "Body text carrying no registered figure value at all.`r`n"
        }
        NameInOutput = ''
    })

    $r.Add([pscustomobject]@{
        Gate  = 'Stage-Ledger'
        Kind  = 'a blocking stage with no record in the ledger'
        #  THE CLEAN ARM IS CUT AGAINST A LEDGER THIS HARNESS BUILDS GREEN, not
        #  against the reference build. That build's UNPLANTED ledger fails on
        #  purpose - no Stage 6 read postdates its artwork placement, its
        #  recorded verdict is Not Compliant, and its figure sheet is stale -
        #  so a clean run there proves nothing about the gate and leaves the
        #  plant result carrying a half-verdict. The required stage list is
        #  READ OUT OF THE GATE ITSELF rather than typed here, so it cannot
        #  drift from what the gate enforces.
        Prepare = {
            param($fx)
            $gate = Join-Path $fx.Skill 'scripts\Stage-Ledger.ps1'
            if (-not (Test-Path -LiteralPath $gate)) { return }
            #  THE DERIVED VIEW, not a regex over a literal array: the required
            #  set is whatever the ledger publishes, however it builds it.
            $view = Get-LedgerStageView -Skill $fx.Skill
            $stages = New-Object System.Collections.Generic.List[string]
            foreach ($s in @($view.Required)) { if ("$s") { $stages.Add("$s") } }
            $script:LedgerViewSource = $view.Source
            if ($stages.Count -eq 0) { return }
            #  Every record must postdate every file the build renders from.
            $newest = [datetime]::UtcNow.AddMinutes(-30)
            foreach ($fi in @(Get-ChildItem -LiteralPath $fx.Dir -Recurse -File -ErrorAction SilentlyContinue)) {
                if ($fi.LastWriteTimeUtc -gt $newest) { $newest = $fi.LastWriteTimeUtc }
            }
            $recs = New-Object System.Collections.Generic.List[object]
            $i = 0
            foreach ($s in $stages) {
                #  Distinct sub-second start AND end per record: two stages
                #  sharing a timestamp to the second is the ledger gate's
                #  signature for retroactive batch-writing.
                $st = $newest.AddSeconds(60 + ($i * 7)).AddMilliseconds(($i * 37) % 900)
                $en = $st.AddSeconds(5).AddMilliseconds(113)
                #  A judgement stage that states no judgement is not a
                #  judgement stage, so every record carries a verdict. Learned
                #  by asking the gate what it objected to rather than guessing.
                $recs.Add([ordered]@{
                    stage   = $s
                    status  = 'pass'
                    verdict = 'pass'
                    started = $st.ToString('o')
                    ended   = $en.ToString('o')
                    note    = 'fixture record built green by the fixtures harness'
                })
                $i++
            }
            $body = [ordered]@{ records = $recs.ToArray() }
            Write-FixtureText -File (Join-Path $fx.Dir 'stage-ledger.json') -Body ($body | ConvertTo-Json -Depth 6)
            #  Stage 3d emits the figure sheet and every later review record
            #  carries it; without one no review can claim to have read the
            #  figures, and the ledger says so.
            $sheet = Join-Path $fx.Dir 'figure-sheet.txt'
            if (-not (Test-Path -LiteralPath $sheet)) {
                Write-FixtureText -File $sheet -Body "FIGURE SHEET - fixture stub written by the fixtures harness.`r`n"
            }
        }
        #  Header: 'refuses delivery when a blocking stage was skipped or has
        #  gone stale'.
        ClaimRx = '(?i)(blocking stage was skipped|stage that ran|refuses delivery|skipped or has gone stale)'
        Plant = {
            param($fx)
            $led = Join-Path $fx.Dir 'stage-ledger.json'
            if (-not (Test-Path -LiteralPath $led)) { return $null }
            $body = Read-FixtureText -File $led
            $obj = $null
            try { $obj = ($body | ConvertFrom-Json) } catch { return $null }
            $recs = $null
            foreach ($pn in @('records', 'stages', 'entries')) {
                if ($null -ne $obj.PSObject.Properties[$pn]) { $recs = $obj.$pn; $recName = $pn }
            }
            if ($null -eq $recs) { return $null }
            $kept = New-Object System.Collections.Generic.List[object]
            $dropped = ''
            foreach ($rec in @($recs)) {
                if (-not $dropped) { $dropped = "$($rec.stage)"; continue }
                $kept.Add($rec)
            }
            if (-not $dropped) { return $null }
            $obj.$recName = $kept.ToArray()
            Write-FixtureText -File $led -Body ($obj | ConvertTo-Json -Depth 12)
            return [pscustomobject]@{ Token = $dropped; Channel = $led; Describe = ("the record for stage '" + $dropped + "' removed from the ledger"); Absent = $true }
        }
        Verify = {
            param($fx, $plant)
            #  The plant here is a REMOVAL, so landing means the value is GONE
            #  from the channel the gate reads.
            $back = Read-FixtureText -File $plant.Channel
            $rx = '"stage"\s*:\s*"' + [regex]::Escape($plant.Token) + '"'
            return (-not [regex]::IsMatch($back, $rx))
        }
        Args = { param($fx) @('-BuildDir', $fx.Dir, '-Check') }
        #  A removal plant has no needle to find in the output - the token is
        #  a stage key like '0', which is too short to mean anything and is
        #  absent from the build by design. The gate must instead say, in its
        #  own words, that THIS stage has no record. {0} is the escaped token.
        ExpectRx = '(?i)stage\s+{0}\s+has\s+no\s+record'
        NameInOutput = ''
    })

    $r.Add([pscustomobject]@{
        Gate  = 'Get-RtoProfile'
        Kind  = 'an RTO profile pack missing a field its schema requires'
        #  Header: 'load and validate an RTO PROFILE PACK' and 'IT THROWS
        #  RATHER THAN DEFAULTING'.
        ClaimRx = '(?i)(load and validate an RTO PROFILE PACK|throws rather than defaulting|ASSERT-RTOPROFILE CHECKS)'
        Plant = {
            param($fx)
            #  Copy the skill's own assets and break the copy. The real profile
            #  is never touched.
            $src = Join-Path $fx.Skill 'assets'
            if (-not (Test-Path -LiteralPath $src)) { return $null }
            $dst = Join-Path $fx.Dir 'skillcopy'
            New-Item -ItemType Directory -Force -Path (Join-Path $dst 'assets') | Out-Null
            foreach ($j in (Get-ChildItem -LiteralPath $src -Filter '*.json' -File)) {
                Copy-Item -LiteralPath $j.FullName -Destination (Join-Path $dst ('assets\' + $j.Name)) -Force
            }
            $profiles = @(Get-ChildItem -LiteralPath (Join-Path $dst 'assets') -Filter 'rto-profile.*.json' -File |
                            Where-Object { $_.Name -notmatch '(?i)schema' })
            if ($profiles.Count -eq 0) { return $null }
            $p = $profiles[0]
            #  The RTO id is DERIVED from the filename, not typed.
            $rtoId = [regex]::Match($p.Name, '(?i)^rto-profile\.([^.]+)\.json$').Groups[1].Value
            #  THE CLEAN ARM GETS ITS OWN, UNBROKEN COPY. The first version
            #  declared CleanArgsDynamic and never supplied clean arguments, so
            #  the clean arm never ran and the verdict rested on the planted
            #  exit alone - the tautology this rewrite removes. Same assets,
            #  same -SkillPath shape, minus the defect.
            $cleanDst = Join-Path $fx.Dir 'skillclean'
            New-Item -ItemType Directory -Force -Path (Join-Path $cleanDst 'assets') | Out-Null
            foreach ($j in (Get-ChildItem -LiteralPath (Join-Path $dst 'assets') -Filter '*.json' -File)) {
                Copy-Item -LiteralPath $j.FullName -Destination (Join-Path $cleanDst ('assets\' + $j.Name)) -Force
            }
            $body = Read-FixtureText -File $p.FullName
            $marker = 'plantedmissingrequiredfield'
            $new = [regex]::Replace($body, '"brandingFile"', ('"' + $marker + '"'), 1)
            if ($new -eq $body) { return $null }
            Write-FixtureText -File $p.FullName -Body $new
            return [pscustomobject]@{
                Token = $marker; Channel = $p.FullName
                Describe = 'a required property renamed in a copy of the RTO profile pack'
                Extra = $rtoId; SkillCopy = $dst
                CleanArgs = @('-Rto', $rtoId, '-SkillPath', $cleanDst, '-Check')
            }
        }
        Verify = {
            param($fx, $plant)
            $back = Read-FixtureText -File $plant.Channel
            return (($back.IndexOf($plant.Token, [System.StringComparison]::Ordinal) -ge 0) -and ($back.IndexOf('"brandingFile"', [System.StringComparison]::Ordinal) -lt 0))
        }
        Args = { param($fx, $plant) @('-Rto', $plant.Extra, '-SkillPath', $plant.SkillCopy, '-Check') }
        CleanArgsDynamic = $true
        NameInOutput = ''
    })

    # -----------------------------------------------------------------------
    #  THE ROUND-6 LEAK CLASSES, as named recipes. Six clean-room rounds on
    #  one build found the same leak in a new shape each time; the sixth found
    #  it in guide sub-section 1.4 (six list sentences giving a task's spoilage
    #  indicators, row by row, in the assessor's own order) and in Figure
    #  7.1.4 (a row labelled 'On this run' carrying the assessed values under
    #  the task's own column headings). Three gates each own one shape of it,
    #  and each recipe plants exactly the shape its gate owns into a LEAN
    #  FIXTURE SPINE this harness writes for itself - a synthetic register,
    #  gate-only cells and corpus, with no model answer from any real pack -
    #  so the recipe runs without a reference build and can never leak one.
    #  A gate that does not yet fail on its shape reads UNPROVEN, which is the
    #  honest state while those gates are being rewritten.
    # -----------------------------------------------------------------------

    $r.Add([pscustomobject]@{
        Gate  = 'Check-ShapeMirror'
        Kind  = 'round-6: six list sentences giving a grid''s indicators row by row, in the assessor''s order, each carrying most of a model bullet'
        ClaimRx = '(?i)(shape of the assessor|written to the shape|row order|in the task''s own order|assessor''s own order)'
        Fixture = { param($fx) New-Round6Fixture -Root $fx.Dir }
        Plant = {
            param($fx)
            $spine = Join-Path $fx.Dir 'spine\t1_1.4.json'
            $obj = (Read-FixtureText -File $spine) | ConvertFrom-Json
            $rows = $script:Round6Rows
            $lines = New-Object System.Collections.Generic.List[string]
            foreach ($row in $rows) {
                #  Most of the bullet's content words - never all of them, so
                #  this is the SHAPE leak (the withhold gate's complete-bullet
                #  rule stays silent) and the row is named at the front.
                $keep = @($row.Words | Select-Object -First ([Math]::Max(2, $row.Words.Count - 1)))
                $lines.Add(("{0} shows {1}." -f $row.Item, ($keep -join ', ')))
            }
            $obj.underpinningKnowledge = @($obj.underpinningKnowledge) + $lines.ToArray()
            Write-FixtureText -File $spine -Body ($obj | ConvertTo-Json -Depth 14)
            #  NO Token: there is nothing this gate may quote back (see ExpectRx below), so a token would be an anchor it can never satisfy.
            return [pscustomobject]@{ Channel = $spine; Describe = ('six row-by-row list sentences in the assessor''s order added to t1_1.4.json underpinningKnowledge') }
        }
        Verify = {
            param($fx, $plant)
            $back = Read-FixtureText -File $plant.Channel
            $obj = $null
            try { $obj = $back | ConvertFrom-Json } catch { return $false }
            $n = 0
            foreach ($row in $script:Round6Rows) { foreach ($s in @($obj.underpinningKnowledge)) { if ("$s".StartsWith($row.Item + ' shows ')) { $n++; break } } }
            return ($n -eq 6)
        }
        Args = { param($fx) @('-BuildDir', $fx.Dir, '-Quiet') }
        #  THIS GATE DELIBERATELY DOES NOT PRINT WHAT IT FOUND. Check-ShapeMirror
        #  sweeps assessor-only material, so its per-grid detail goes into the
        #  report file and its stdout carries the arm roster instead - measured:
        #  968 bytes, not one of them a quotation. Anchoring on a phrase from a
        #  gate that must not quote is asking it to leak, so the ANCHOR IS THE
        #  ROSTER LINE: the blocking full-rows arm ran and found at least one.
        NameInOutput = ''
        ExpectRx = '(?m)^ARMS:[^\r\n]*full-rows\|true\|ran\|\d+\|[1-9]'
    })

    $r.Add([pscustomobject]@{
        Gate  = 'Check-FigureMirror'
        Kind  = 'round-6: a figure row labelled ''On this run'' carrying assessed values under the task''s own column headings'
        ClaimRx = '(?i)(column headings|transposed|answer sheet''s shape|reproduce[s]? an assessed answer grid)'
        Fixture = { param($fx) New-Round6Fixture -Root $fx.Dir }
        Plant = {
            param($fx)
            $spine = Join-Path $fx.Dir 'spine\t1_1.4.json'
            $obj = (Read-FixtureText -File $spine) | ConvertFrom-Json
            $rows = $script:Round6Rows
            $fig = [ordered]@{
                slot = '7.1.4'; kind = 'Table'
                caption = 'Figure 7.1.4 What the receiving check found on this run'
                alt = 'A table of the receiving check on one delivery run.'
                spec = [ordered]@{
                    headers = @($script:Round6Headers)
                    rows = @(
                        @('On this run', ($rows[0].Words -join ' '), 'rejected at the door and logged'),
                        @('On the previous run', ($rows[1].Words -join ' '), 'rejected at the door and logged')
                    )
                }
            }
            $obj.visuals = @($obj.visuals) + @([pscustomobject]$fig)
            Write-FixtureText -File $spine -Body ($obj | ConvertTo-Json -Depth 14)
            return [pscustomobject]@{ Token = 'On this run'; Channel = $spine; Describe = 'a table under the task''s own three column headings with two filled rows, one labelled On this run, added to t1_1.4.json visuals' }
        }
        Verify = {
            param($fx, $plant)
            $back = Read-FixtureText -File $plant.Channel
            $obj = $null
            try { $obj = $back | ConvertFrom-Json } catch { return $false }
            foreach ($v in @($obj.visuals)) {
                if ($null -eq $v -or $null -eq $v.PSObject.Properties['spec'] -or $null -eq $v.spec) { continue }
                foreach ($row in @($v.spec.rows)) { if (@($row).Count -ge 3 -and "$(@($row)[0])" -eq 'On this run') { return $true } }
            }
            return $false
        }
        Args = { param($fx) @('-BuildDir', $fx.Dir, '-Quiet') }
        NameInOutput = 'On this run'
    })

    $r.Add([pscustomobject]@{
        Gate  = 'Assert-WithholdRegister'
        Kind  = 'round-6: six sentences each naming a withheld row and stating one of its model bullets completely, in the assessor''s order'
        ClaimRx = '(?i)(withheld value|withheld row|complete content-word set|names the row)'
        Fixture = { param($fx) New-Round6Fixture -Root $fx.Dir }
        Plant = {
            param($fx)
            $spine = Join-Path $fx.Dir 'spine\t1_1.4.json'
            $obj = (Read-FixtureText -File $spine) | ConvertFrom-Json
            $lines = New-Object System.Collections.Generic.List[string]
            foreach ($row in $script:Round6Rows) { $lines.Add(("{0}: {1}." -f $row.Item, $row.Text)) }
            $obj.underpinningKnowledge = @($obj.underpinningKnowledge) + $lines.ToArray()
            Write-FixtureText -File $spine -Body ($obj | ConvertTo-Json -Depth 14)
            return [pscustomobject]@{ Token = $lines[0]; Channel = $spine; Describe = 'six sentences each naming a withheld row and carrying its complete model bullet, added to t1_1.4.json underpinningKnowledge' }
        }
        Verify = {
            param($fx, $plant)
            $back = Read-FixtureText -File $plant.Channel
            $obj = $null
            try { $obj = $back | ConvertFrom-Json } catch { return $false }
            $n = 0
            foreach ($row in $script:Round6Rows) { foreach ($s in @($obj.underpinningKnowledge)) { if ("$s" -eq ("{0}: {1}." -f $row.Item, $row.Text)) { $n++; break } } }
            return ($n -eq 6)
        }
        Args = { param($fx) @('-BuildDir', $fx.Dir, '-SkillDir', $fx.Skill, '-Quiet') }
        NameInOutput = 'answered outside a posed-question context'
    })

    return $r.ToArray()
}

# ---------------------------------------------------------------------------
# Proving one gate
# ---------------------------------------------------------------------------

function Test-OneGate {
    param(
        [Parameter(Mandatory)]$Facts,
        $DocRow,
        $Recipe,
        [Parameter(Mandatory)][string] $Skill,
        [string] $Build,
        [string] $Scratch,
        [int] $TimeoutSec,
        #  An empty section is normal: most gates are not named in gates.md at all.
        [AllowEmptyString()][string] $SectionText = '',
        #  The refusal probe plan for THIS gate, from Get-RefusalProbeSet, or
        #  $null when the stage table binds this script to no stage. A gate
        #  outside the table is NOT PROBED - see that function for what a bare
        #  probe over a whole directory was doing.
        $Probe
    )

    $res = [pscustomobject]@{
        Gate        = $Facts.Name
        Stage       = $(if ($null -ne $DocRow) { $DocRow.Stage } else { '' })
        Blocks      = $(if ($null -ne $DocRow) { $DocRow.Blocks } else { '' })
        Section     = $(if ($null -ne $DocRow) { $DocRow.Section } else { '' })
        Claim       = $Facts.Claim
        HasSelfTest = $Facts.HasSelfTest
        SelfTestVerifiesPlant = $Facts.SelfTestVerifiesPlant
        PlantVerifyState = "$($Facts.PlantVerifyState)"
        PlantVerifyEvidence = "$($Facts.PlantVerifyEvidence)"
        SelfTestRc  = ''
        SelfTestOk  = $false
        HasFixture  = ($null -ne $Recipe)
        PlantKind   = $(if ($null -ne $Recipe) { $Recipe.Kind } else { '' })
        ClaimState  = 'n/a'
        ClaimEvidence = ''
        Disclaimers = @()
        SelfTestVerdict = 'NOT-RUN'
        PlantLanded = $false
        FailsOnPlant = $false
        PassesClean = $false
        RefusesEmpty = $false
        ProbeState  = 'NOT-PROBED'
        ProbeWhy    = 'the ledger stage table binds this script to no stage, so the refusal probe does not run it'
        ProbeWhatIf = $false
        CleanExit   = ''
        PlantExit   = ''
        CleanRan    = $false
        NeedleState = 'n/a'
        Verdict     = 'UNPROVEN'
        Reason      = ''
        Seconds     = 0.0
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    # ---- channel: REFUSAL. A gate that exits 0 on nothing proves nothing.
    #  A refusal happens at parameter validation, in the first second. A gate
    #  still working after that has not refused - it has started, which is the
    #  answer this probe was asking for. It runs only for a script the stage
    #  table binds to a stage, and it adds -WhatIf only where the syntax tree
    #  said the script supports it.
    if ($null -ne $Probe) {
        $res.ProbeWhatIf = [bool]$Probe.WhatIf
        $res.ProbeWhy = "$($Probe.WhatIfWhy)"
        $bare = Invoke-GateProcess -File $Facts.File -Arguments @($Probe.Arguments) -TimeoutSec ([Math]::Min($TimeoutSec, 45))
        if ($bare.TimedOut) { $res.ProbeState = 'TIMEOUT'; $res.RefusesEmpty = $false }
        elseif ($bare.Exit -ne 0) { $res.ProbeState = 'REFUSED'; $res.RefusesEmpty = $true }
        else { $res.ProbeState = 'EXITED-0'; $res.RefusesEmpty = $false }
    }

    # ---- channel: SELFTEST
    if ($Facts.HasSelfTest) {
        $stArgs = New-Object System.Collections.Generic.List[string]
        $stArgs.Add('-' + $(if ($Facts.SelfTestSwitch) { $Facts.SelfTestSwitch } else { 'SelfTest' }))
        $unsatisfied = ''
        foreach ($m in $Facts.Mandatory) {
            $filled = $false
            if ($m -imatch '^(BuildDir)$' -and $Build) { $stArgs.Add('-BuildDir'); $stArgs.Add($Build); $filled = $true }
            elseif ($m -imatch '^(Path|Guide|Deck)$' -and $Build) {
                $art = @(Get-ChildItem -LiteralPath $Build -Recurse -Include '*.docx', '*.pptx' -File -ErrorAction SilentlyContinue |
                            Where-Object { $_.FullName -notmatch '(?i)(backup|_bak|~\$)' } | Sort-Object Length -Descending)
                if ($art.Count -gt 0) {
                    $stArgs.Add('-' + $m)
                    $stArgs.Add($art[0].FullName)
                    $filled = $true
                }
            }
            if (-not $filled) { $unsatisfied = $m }
        }
        if ($unsatisfied) {
            $res.SelfTestVerdict = 'NOT-RUN'
            $res.SelfTestRc = 'not run'
            $res.Reason = ("its -SelfTest needs -{0} and this run could not supply one" -f $unsatisfied)
        }
        else {
            $st = Invoke-GateProcess -File $Facts.File -Arguments $stArgs.ToArray() -TimeoutSec $TimeoutSec
            $res.SelfTestRc = $(if ($st.TimedOut) { 'timeout' } else { "$($st.Exit)" })

            #  A NON-ZERO EXIT IS NOT A FAILED SELF-TEST. Several gates run
            #  their self-test and then go on to sweep the build they were
            #  given; one of them exits 1 because it found a REAL crossover in
            #  the reference build, after its self-test passed. Reading the
            #  exit code alone reported fourteen gates as inconclusive when
            #  most of them had told us plainly, in words, that they passed.
            #  So the verdict comes from what the gate SAID, and the exit code
            #  only decides the cases where it said nothing.
            #  A TERMINAL VERDICT LINE WINS OVER ANY PHRASE INSIDE THE RUN.
            #  The first version scanned for failure phrases anywhere in the
            #  output, and this harness's own self-test prints "including the
            #  plant that did not land" ON ITS PASS LINE - describing the check
            #  it just passed. So the harness read its own success as a failure
            #  and reported itself UNPROVEN. A gate that states its verdict on
            #  its own last line is believed about that verdict.
            $finalPass = [regex]::IsMatch($st.Text, '(?m)^\s*SELF-?TEST\s+PASS\b')
            $finalFail = [regex]::IsMatch($st.Text, '(?m)^\s*SELF-?TEST\s+FAIL\b')
            #  "did NOT fire" IS A PASSING CHECK. A good self-test proves both
            #  arms: that the gate fires on the planted defect AND that it does
            #  NOT fire on the negative control - "the same duty cited the same
            #  way twice did NOT fire. Repetition is not contradiction."
            #  Matching failure words anywhere in the output read those
            #  negative controls as failures and reported two gates with
            #  working, plant-verifying self-tests as UNPROVEN. Only an
            #  explicit failure marker counts, and a clean exit is believed.
            $sayFail = [regex]::IsMatch($st.Text, '(?m)^\s*(X\s+self-?test|self-?test\s*(:|-)?\s*fail)') -or
                       [regex]::IsMatch($st.Text, '(?i)self-?test failed')
            $sayPass = [regex]::IsMatch($st.Text, '(?i)(self-?test[^\r\n]{0,160}\b(pass|passed|found it|can fail|caught|detected|proves)\b|plant landed)')
            if ($st.TimedOut) {
                $res.SelfTestVerdict = 'INCONCLUSIVE'
            }
            elseif ($finalFail) { $res.SelfTestVerdict = 'FAIL' }
            elseif ($finalPass) { $res.SelfTestVerdict = 'PASS' }
            elseif ($sayFail) { $res.SelfTestVerdict = 'FAIL' }
            elseif ($st.Exit -eq 0) { $res.SelfTestVerdict = 'PASS' }
            elseif ($st.Exit -eq 4) { $res.SelfTestVerdict = 'FAIL' }
            elseif ($sayPass) { $res.SelfTestVerdict = 'PASS' }
            else { $res.SelfTestVerdict = 'INCONCLUSIVE' }
            $res.SelfTestOk = ($res.SelfTestVerdict -eq 'PASS')
        }
    }

    # ---- establish the claim BEFORE any plant is believed
    $claim = $null
    if ($null -ne $Recipe) {
        $claim = Test-GateClaim -Facts $Facts -Recipe $Recipe -SectionText $SectionText
        $res.ClaimState = $claim.State
        $res.ClaimEvidence = $claim.Evidence
        $res.Disclaimers = $claim.Disclaimers
    }

    # ---- channel: PLANT
    if ($null -ne $Recipe -and $Build -and $claim.State -eq 'ESTABLISHED') {
        $fxDir = Join-Path $Scratch ('fx_' + $Facts.Name + '_' + [Guid]::NewGuid().ToString('N').Substring(0, 6))
        try {
            $null = New-LeanBuildCopy -Source $Build -Dest $fxDir
            $fx = [pscustomobject]@{ Dir = $fxDir; Skill = $Skill; SourceBuild = $Build }
            #  $null = ON BOTH, AND THE REASON IS NOT TIDINESS. A scriptblock
            #  called bare inside a function puts whatever it emits onto THIS
            #  function's output stream, and New-Round6Fixture returns the
            #  directory it built. The caller then received a two-element array
            #  - a path, then the result object - and wrote it into the report,
            #  so every recipe with a Fixture block produced a results[] row the
            #  runners read as a gate with no name and no verdict. The gate was
            #  PROVEN and the file said nothing.
            if ($null -ne $Recipe.PSObject.Properties['Fixture'] -and $null -ne $Recipe.Fixture) {
                #  A recipe that builds its own synthetic fixture writes it over
                #  the lean copy rather than depending on the real build's shape.
                $null = & $Recipe.Fixture $fx
            }
            if ($null -ne $Recipe.PSObject.Properties['Prepare'] -and $null -ne $Recipe.Prepare) {
                $null = & $Recipe.Prepare $fx
            }

            #  CLEAN FIRST, on the untouched copy. A gate that fails on a clean
            #  build cannot have its failure on a planted one believed, and -
            #  since P0-13 - a clean arm that did not RUN AT ALL means the
            #  planted arm proves nothing either.
            $cleanArgs = @()
            if ($null -ne $Recipe.PSObject.Properties['CleanArgs'] -and $null -ne $Recipe.CleanArgs) { $cleanArgs = & $Recipe.CleanArgs $fx }
            elseif ($null -eq $Recipe.PSObject.Properties['CleanArgsDynamic']) { $cleanArgs = & $Recipe.Args $fx }

            $ranClean = $false
            $cleanRc = -9999
            $cleanText = ''
            if ($null -ne $cleanArgs -and @($cleanArgs).Count -gt 0) {
                $cl = Invoke-GateProcess -File $Facts.File -Arguments @($cleanArgs) -TimeoutSec $TimeoutSec
                $res.PassesClean = ((-not $cl.TimedOut) -and ($cl.Exit -eq 0))
                $cleanRc = $cl.Exit
                $cleanText = "$($cl.Text)"
                $ranClean = (-not $cl.TimedOut)
                $res.CleanExit = $(if ($cl.TimedOut) { 'timeout' } else { "$($cl.Exit)" })
            }

            $plant = & $Recipe.Plant $fx
            if ($null -eq $plant) {
                $res.Reason = 'the fixture recipe found nothing in this build to plant into, so nothing was proven'
            }
            else {
                $res.PlantLanded = [bool](& $Recipe.Verify $fx $plant)
                if (-not $res.PlantLanded) {
                    $res.Reason = ('the plant did not land in ' + [System.IO.Path]::GetFileName($plant.Channel) + ' - a plant that changes nothing proves nothing and would have passed')
                }
                else {
                    $pArgs = @()
                    if ($Recipe.Args.Ast.ParamBlock -and $Recipe.Args.Ast.ParamBlock.Parameters.Count -ge 2) { $pArgs = & $Recipe.Args $fx $plant }
                    else { $pArgs = & $Recipe.Args $fx }

                    #  For a recipe whose clean run needs the plant's own
                    #  context (a copied profile, say), run clean now, against
                    #  the same inputs minus the defect.
                    if (-not $ranClean -and $null -ne $plant.PSObject.Properties['CleanArgs']) {
                        $cl = Invoke-GateProcess -File $Facts.File -Arguments @($plant.CleanArgs) -TimeoutSec $TimeoutSec
                        $res.PassesClean = ((-not $cl.TimedOut) -and ($cl.Exit -eq 0))
                        $cleanRc = $cl.Exit
                        $cleanText = "$($cl.Text)"
                        $ranClean = (-not $cl.TimedOut)
                        $res.CleanExit = $(if ($cl.TimedOut) { 'timeout' } else { "$($cl.Exit)" })
                    }

                    $pl = Invoke-GateProcess -File $Facts.File -Arguments @($pArgs) -TimeoutSec $TimeoutSec
                    $res.PlantExit = $(if ($pl.TimedOut) { 'timeout' } else { "$($pl.Exit)" })
                    $res.CleanRan = $ranClean

                    #  THE ANCHOR. The gate must NAME the plant. Where a recipe
                    #  declares no token of its own, the planted value itself is
                    #  the token - never "assume named", which is what silently
                    #  switched the discrimination guard off for the gates that
                    #  crash before they run.
                    #
                    #  A NEEDLE IS AT LEAST THREE CHARACTERS AND MUST BE ABSENT
                    #  FROM THE CLEAN OUTPUT. `0` matches the exit code, the
                    #  year, a count and a column heading in almost any gate's
                    #  output, so "the gate named the plant" was true of gates
                    #  that had never seen it. Three characters is the floor,
                    #  and a needle the gate already prints on the CLEAN build
                    #  is not evidence about the planted one whatever its
                    #  length.
                    #
                    #  A REMOVAL PLANT HAS NO NEEDLE. Deleting a required line
                    #  leaves nothing for the gate to quote back, so its recipe
                    #  declares an ExpectRx that the failing output must match,
                    #  and that pattern is the anchor instead.
                    $needle = ''
                    if ($Recipe.NameInOutput) { $needle = "$($Recipe.NameInOutput)" }
                    if (-not $needle -and $null -ne $plant.PSObject.Properties['Token'] -and $plant.Token) { $needle = "$($plant.Token)" }
                    $expectRx = ''
                    if ($null -ne $Recipe.PSObject.Properties['ExpectRx'] -and $Recipe.ExpectRx) { $expectRx = "$($Recipe.ExpectRx)" }
                    if ($null -ne $plant.PSObject.Properties['ExpectRx'] -and $plant.ExpectRx) { $expectRx = "$($plant.ExpectRx)" }
                    #  A recipe may parameterise its ExpectRx on the plant.
                    if ($expectRx -and $expectRx.Contains('{0}') -and $null -ne $plant.PSObject.Properties['Token']) {
                        $expectRx = ($expectRx -f [regex]::Escape("$($plant.Token)"))
                    }

                    $named = $false
                    $anchorWhy = ''
                    if ($needle -and $needle.Length -lt 3) {
                        $res.NeedleState = 'TOO-SHORT'
                        $anchorWhy = ("the anchor '{0}' is {1} character(s) and a needle is at least three characters, because a one-character needle matches an exit code, a count and a column heading in almost any gate's output" -f $needle, $needle.Length)
                        $needle = ''
                    }
                    elseif ($needle -and $ranClean -and (Test-OutputNames -Text $cleanText -Token $needle)) {
                        $res.NeedleState = 'IN-CLEAN-OUTPUT'
                        $anchorWhy = ("the anchor '{0}' is already printed by this gate on the CLEAN build, so finding it in the planted output says nothing about the plant" -f (Get-ShortLine -Value $needle -Max 60))
                        $needle = ''
                    }
                    elseif ($needle) { $res.NeedleState = 'OK' }

                    if ($needle) {
                        $named = Test-OutputNames -Text $pl.Text -Token $needle
                        if (-not $named) { $anchorWhy = ("the gate's output never contains the anchor '{0}', so the failure it reported may be about something else - either the gate does not name what it caught, or this recipe's anchor is wrong" -f (Get-ShortLine -Value $needle -Max 60)) }
                    }
                    elseif ($expectRx) {
                        $res.NeedleState = $(if ($res.NeedleState -eq 'n/a') { 'EXPECT-RX' } else { $res.NeedleState + '+EXPECT-RX' })
                        $named = [regex]::IsMatch("$($pl.Text)", $expectRx)
                        if (-not $named -and -not $anchorWhy) { $anchorWhy = "the failing output does not match the recipe's ExpectRx, so the failure may be about something else" }
                    }
                    elseif (-not $anchorWhy) {
                        $res.NeedleState = 'NO-ANCHOR'
                        $anchorWhy = 'this recipe declares no NameInOutput, its plant returned no Token, and it declares no ExpectRx - a removal plant must carry a recipe ExpectRx for the failing output to be matched against'
                    }

                    #  DISCRIMINATION, STATED ONCE AND WITH NO ESCAPE HATCH.
                    #  FailsOnPlant is true only when the planted run did not
                    #  time out, exited non-zero, NAMED the plant, the clean arm
                    #  RAN, and the clean exit DIFFERS. The first version wrote
                    #  `($ranClean -and $cleanRc -ne $pl.Exit) -or $named`, and
                    #  that `-or` is a tautology: a gate that dies in its own
                    #  parameter block exits 1 on clean and 1 on planted and its
                    #  error text names the file it was handed, so it scored as
                    #  having caught the defect. Everything below is an AND.
                    $res.FailsOnPlant = ((-not $pl.TimedOut) -and ($pl.Exit -ne 0) -and $named -and $ranClean -and ($cleanRc -ne $pl.Exit))

                    if ($pl.TimedOut) { $res.Reason = ("the gate timed out on the planted fixture (clean exit {0})" -f $res.CleanExit) }
                    elseif ($pl.Exit -eq 0) { $res.Reason = 'the gate PASSED a verified plant of the defect it claims to catch' }
                    elseif (-not $ranClean) {
                        $res.Reason = ("the clean arm did not run (clean {0}, plant {1}), so there is nothing to compare the planted run against and a non-zero exit is not evidence of discrimination" -f $res.CleanExit, $res.PlantExit)
                    }
                    elseif ($cleanRc -eq $pl.Exit) {
                        $res.Reason = ("the gate exited {0} on the clean build and {1} on the planted one - the same code, so it did not discriminate the plant; check whether it ran at all" -f $res.CleanExit, $res.PlantExit)
                    }
                    elseif (-not $named) {
                        $res.Reason = ("the gate exited {0} clean and {1} planted, but the anchor was not found: {2}" -f $res.CleanExit, $res.PlantExit, $anchorWhy)
                    }
                }
            }
        }
        catch {
            $res.Reason = ('the fixture threw: ' + (Get-ShortLine -Value $_.Exception.Message -Max 160))
        }
        finally {
            if ((Test-Path -LiteralPath $fxDir) -and $fxDir.Length -gt 12) {
                Remove-Item -LiteralPath $fxDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
    elseif ($null -ne $Recipe -and $null -ne $claim -and $claim.State -ne 'ESTABLISHED') {
        #  NO PLANT IS RUN AND NO VERDICT ABOUT THE GATE IS EMITTED. This is the
        #  guard that the false HIGH went through: the harness must not be able
        #  to say a gate failed to catch something it never claimed to catch.
        $res.Reason = ("this harness holds a fixture for '{0}', but that claim could not be established from the gate's own header, so no plant was run and nothing is asserted about the gate" -f $Recipe.Kind)
    }
    elseif ($null -ne $Recipe) {
        $res.Reason = 'a fixture exists for this gate but no -BuildDir was given to cut it from'
    }

    $sw.Stop()
    $res.Seconds = [Math]::Round($sw.Elapsed.TotalSeconds, 1)

    # ---- verdict
    #  KEEP THE PLANT'S OWN REASON. A gate whose plant ran, landed and did NOT
    #  discriminate, but whose -SelfTest passed, used to be reported purely on
    #  the self-test - so the one sentence saying WHY the strong channel
    #  rejected it was overwritten by a sentence about a weaker one.
    $plantReason = ''
    if ($res.PlantLanded -and -not $res.FailsOnPlant -and $res.Reason) { $plantReason = " THE PLANT CHANNEL ALSO RAN AND DID NOT PROVE IT: " + $res.Reason }

    if ($res.PlantLanded -and $res.FailsOnPlant -and $res.PassesClean) {
        $res.Verdict = 'PROVEN'
        $res.Reason = ("failed on a verified plant (exit {0}), named it, and passed the same build clean (exit {1})" -f $res.PlantExit, $res.CleanExit)
    }
    elseif ($res.PlantLanded -and $res.FailsOnPlant) {
        $res.Verdict = 'PROVEN-NOCLEAN'
        $res.Reason = ("failed on a verified plant (exit {0}) and named it, but the clean build did not pass (exit {1}), so it may be failing for another reason" -f $res.PlantExit, $res.CleanExit)
    }
    elseif ($res.SelfTestOk -and $Facts.PlantVerifyState -eq 'VERIFIED') {
        $res.Verdict = 'PROVEN-SELFTEST'
        $res.Reason = ('its own -SelfTest plants a defect, reads the plant back and branches to failure on it, then requires the gate to catch it. ' + $Facts.PlantVerifyEvidence + $plantReason)
    }
    elseif ($res.SelfTestOk -and $Facts.PlantVerifyState -eq 'INDETERMINATE') {
        #  NEVER WEAK BY DEFAULT. A false WEAK sends someone to add a read-back
        #  that already exists - the mirror of a false PROVEN, and just as
        #  expensive. Where the syntax tree cannot settle it, say so and say
        #  what was looked for.
        $res.Verdict = 'SELFTEST-INDETERMINATE'
        $res.Reason = ('its -SelfTest passes; whether it reads its own plant back could not be settled from the syntax tree. ' + $Facts.PlantVerifyEvidence + ' LOOKED FOR: ' + $Facts.PlantVerifyLookedFor + $plantReason)
    }
    elseif ($res.SelfTestOk) {
        $res.Verdict = 'WEAK-SELFTEST'
        $res.Reason = ('its -SelfTest passes but nothing in it reads the plant back before the gate is believed, which is the exact way a gate was recorded as proven while shipping the defect. ' + $Facts.PlantVerifyEvidence + $plantReason)
    }
    elseif (-not $res.Reason) {
        #  Say which of the two it actually is. A blanket "it has no -SelfTest"
        #  was printed against gates that HAVE one which came back
        #  inconclusive, which sends a reader to write a self-test that is
        #  already there instead of finding out why it could not be read.
        if ($Facts.HasSelfTest) {
            $res.Reason = ("no seeded-defect fixture exists for this gate in this harness, and its -SelfTest came back {0} (exit {1}) so it could not stand in for one" -f $res.SelfTestVerdict, $res.SelfTestRc)
        }
        else {
            $res.Reason = 'no seeded-defect fixture exists for this gate in this harness and it has no -SelfTest'
        }
    }
    return $res
}

# ---------------------------------------------------------------------------
# Self-test - prove the HARNESS, including that it catches a plant that missed
# ---------------------------------------------------------------------------

function Invoke-FixtureSelfTest {
    param([string] $Skill)

    $script:stPass = 0
    $script:stFail = 0
    function TOk  ($m) { $script:stPass++; Write-Host "  PASS  $m" -ForegroundColor Green }
    function TBad ($m) { $script:stFail++; Write-Host "  FAIL  $m" -ForegroundColor Red }

    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('gatefx_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $fxScripts = Join-Path $tmp 'scripts'
    $fxBuild = Join-Path $tmp 'build'
    New-Item -ItemType Directory -Force -Path $fxScripts | Out-Null
    New-Item -ItemType Directory -Force -Path $fxBuild | Out-Null

    try {
        Write-Host ''
        Write-Host 'SELF-TEST - the plant that misses, and the claim the gate never made' -ForegroundColor Cyan

        Write-FixtureText -File (Join-Path $fxBuild 'target.txt') -Body "clean body text`r`n"
        Write-FixtureText -File (Join-Path $fxBuild 'ignored.txt') -Body "clean body text`r`n"

        #  1. a gate that really reads its channel and really fails
        Write-FixtureText -File (Join-Path $fxScripts 'Check-Honest.ps1') -Body @'
<#  A fixture gate that reads target.txt and fails when a FORBIDDEN MARKER is
    present in it. It makes exactly one claim and this is it.  #>
param([string] $BuildDir, [switch] $SelfTest)
if (-not $BuildDir) { Write-Host 'REFUSE - no build directory'; exit 2 }
$p = Join-Path $BuildDir 'target.txt'
if (-not (Test-Path -LiteralPath $p)) { Write-Host 'REFUSE - no target'; exit 2 }
$t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
if ($t.IndexOf('PLANTEDMARKER', [System.StringComparison]::Ordinal) -ge 0) {
    Write-Host 'FAIL - PLANTEDMARKER is present'
    exit 1
}
Write-Host 'checked target.txt'
exit 0
'@

        #  2. a gate that cannot fail: it exits 0 whatever it is handed
        Write-FixtureText -File (Join-Path $fxScripts 'Check-CannotFail.ps1') -Body @'
<#  A fixture gate that reports a pass no matter what. It claims to enforce a
    FORBIDDEN MARKER and does not.  #>
param([string] $BuildDir, [string[]] $DocText)
foreach ($d in @($DocText)) { Write-Host $d }
Write-Host 'PASS'
exit 0
'@

        #  3. a gate whose self-test passes but never checks its own plant
        Write-FixtureText -File (Join-Path $fxScripts 'Check-BlindSelfTest.ps1') -Body @'
<# A fixture gate with a self-test that plants and never looks. #>
param([string] $BuildDir, [switch] $SelfTest)
if ($SelfTest) {
    $body = 'a copy of something'
    $body = $body + ' marker'
    Write-Host 'self-test: pass'
    exit 0
}
if (-not $BuildDir) { Write-Host 'REFUSE'; exit 2 }
exit 0
'@

        #  4. THE TAUTOLOGY, REPRODUCED. This gate exits 1 on the clean build
        #  and 1 on the planted one, and names the plant when it is there. The
        #  first version scored that as discrimination, because "named" was an
        #  OR against the exit comparison. A gate that dies in its own parameter
        #  block behaves exactly like this, and one of the real gates does.
        Write-FixtureText -File (Join-Path $fxScripts 'Check-AlwaysAngry.ps1') -Body @'
<#  A fixture gate that claims to enforce a FORBIDDEN MARKER and exits 1
    whatever it is handed - the shape of a gate that dies before it runs.  #>
param([string] $BuildDir, [switch] $SelfTest)
$p = Join-Path "$BuildDir" 'target.txt'
if ((Test-Path -LiteralPath $p) -and ([System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8).IndexOf('PLANTEDMARKER', [System.StringComparison]::Ordinal) -ge 0)) {
    Write-Host 'FAIL - PLANTEDMARKER is present'
}
else { Write-Host 'FAIL - something else went wrong' }
exit 1
'@

        #  5. a gate whose param block declares SupportsShouldProcess, for the
        #  refusal probe's -WhatIf decision.
        Write-FixtureText -File (Join-Path $fxScripts 'Check-Careful.ps1') -Body @'
<# A fixture gate that writes, and says so in its CmdletBinding. #>
[CmdletBinding(SupportsShouldProcess = $true)]
param([string] $BuildDir)
if (-not $BuildDir) { Write-Host 'REFUSE - no build directory'; exit 2 }
exit 0
'@

        #  6. a gate with a syntax error. It runs nothing and proves nothing,
        #  and the first version made it VANISH from the report.
        Write-FixtureText -File (Join-Path $fxScripts 'Check-Broken.ps1') -Body @'
<# A fixture gate that does not parse. #>
param([string] $BuildDir
if (-not $BuildDir) { exit 2 }
exit 0
'@

        $honest = Get-ScriptFacts -File (Join-Path $fxScripts 'Check-Honest.ps1')
        $cannot = Get-ScriptFacts -File (Join-Path $fxScripts 'Check-CannotFail.ps1')
        $blind = Get-ScriptFacts -File (Join-Path $fxScripts 'Check-BlindSelfTest.ps1')
        $angry = Get-ScriptFacts -File (Join-Path $fxScripts 'Check-AlwaysAngry.ps1')
        $broken = Get-ScriptFacts -File (Join-Path $fxScripts 'Check-Broken.ps1')

        if ($honest.Parses -and $cannot.Parses -and $blind.Parses) { TOk 'all three fixture gates parse' } else { TBad 'a fixture gate does not parse' }
        if ($blind.HasSelfTest -and -not $blind.SelfTestVerifiesPlant) { TOk 'a self-test that never checks its plant is read as NOT verifying it' }
        else { TBad 'the blind self-test was misread' }

        $landingRecipe = [pscustomobject]@{
            Gate = 'Check-Honest'; Kind = 'a marker in the channel the gate reads'
            Plant = {
                param($fx)
                $p = Join-Path $fx.Dir 'target.txt'
                Write-FixtureText -File $p -Body "clean body text`r`nPLANTEDMARKER`r`n"
                return [pscustomobject]@{ Token = 'PLANTEDMARKER'; Channel = $p; Describe = 'a marker in target.txt' }
            }
            Verify = { param($fx, $plant) return ((Read-FixtureText -File $plant.Channel).IndexOf($plant.Token, [System.StringComparison]::Ordinal) -ge 0) }
            Args = { param($fx) @('-BuildDir', $fx.Dir) }
            NameInOutput = 'PLANTEDMARKER'
            ClaimRx = '(?i)forbidden marker'
        }

        #  THE INCIDENT, REPRODUCED. This recipe writes into a file the gate
        #  never opens, exactly like the plant that was made into a slide with
        #  no light fill to change. The harness must call this UNPROVEN.
        $missRecipe = [pscustomobject]@{
            Gate = 'Check-Honest'; Kind = 'a marker written where the gate does not look'
            Plant = {
                param($fx)
                $p = Join-Path $fx.Dir 'ignored.txt'
                Write-FixtureText -File $p -Body "clean body text`r`nPLANTEDMARKER`r`n"
                return [pscustomobject]@{ Token = 'PLANTEDMARKER'; Channel = (Join-Path $fx.Dir 'target.txt'); Describe = 'a marker written to the wrong file' }
            }
            Verify = { param($fx, $plant) return ((Read-FixtureText -File $plant.Channel).IndexOf($plant.Token, [System.StringComparison]::Ordinal) -ge 0) }
            Args = { param($fx) @('-BuildDir', $fx.Dir) }
            NameInOutput = 'PLANTEDMARKER'
            ClaimRx = '(?i)forbidden marker'
        }

        #  THE SECOND INCIDENT, REPRODUCED: a fixture testing a claim the gate
        #  NEVER MAKES. The real one planted an unregistered figure into the
        #  registry gate and reported that the gate had passed a defect it
        #  claims to catch - a false HIGH at the top of the work order, on a
        #  gate that was behaving exactly as specified. The harness must refuse
        #  to say anything at all about a gate on this path.
        $unclaimedRecipe = [pscustomobject]@{
            Gate = 'Check-Honest'; Kind = 'an unregistered figure caption, which this gate never claimed to catch'
            Plant = {
                param($fx)
                $p = Join-Path $fx.Dir 'target.txt'
                Write-FixtureText -File $p -Body "clean body text`r`nFigure 99.9 Planted unregistered figure`r`n"
                return [pscustomobject]@{ Token = 'Figure 99.9'; Channel = $p; Describe = 'an unregistered figure caption' }
            }
            Verify = { param($fx, $plant) return ((Read-FixtureText -File $plant.Channel).IndexOf($plant.Token, [System.StringComparison]::Ordinal) -ge 0) }
            Args = { param($fx) @('-BuildDir', $fx.Dir) }
            NameInOutput = 'Figure 99.9'
            ClaimRx = '(?i)catches an unregistered figure'
        }

        #  A NEEDLE OF ONE CHARACTER. `0` sits in the exit code, the year, a
        #  count and a column heading of almost every gate's output, so it
        #  matched everywhere and "the gate named the plant" was true of gates
        #  that had never seen it.
        $shortNeedleRecipe = [pscustomobject]@{
            Gate = 'Check-Honest'; Kind = 'a marker anchored on a one-character needle'
            Plant = $landingRecipe.Plant
            Verify = $landingRecipe.Verify
            Args = $landingRecipe.Args
            NameInOutput = '0'
            ClaimRx = '(?i)forbidden marker'
        }

        $scratch = Join-Path $tmp 'scratch'
        New-Item -ItemType Directory -Force -Path $scratch | Out-Null

        $r1 = Test-OneGate -Facts $honest -DocRow $null -Recipe $landingRecipe -Skill $Skill -Build $fxBuild -Scratch $scratch -TimeoutSec 60
        if ($r1.PlantLanded) { TOk 'a plant into the channel the gate reads is confirmed to have landed' } else { TBad 'the landing plant was not seen' }
        if ($r1.Verdict -eq 'PROVEN') { TOk 'a gate that fails on a verified plant and passes clean is PROVEN' } else { TBad ("expected PROVEN, got {0} ({1})" -f $r1.Verdict, $r1.Reason) }

        $r2 = Test-OneGate -Facts $honest -DocRow $null -Recipe $missRecipe -Skill $Skill -Build $fxBuild -Scratch $scratch -TimeoutSec 60
        if (-not $r2.PlantLanded) { TOk 'a plant into a file the gate does not read is reported as NOT LANDED' } else { TBad 'the missed plant was reported as landed' }
        if ($r2.Verdict -ne 'PROVEN') { TOk ("a gate whose plant missed is {0}, not PROVEN - this is the incident this harness exists for" -f $r2.Verdict) }
        else { TBad 'a missed plant produced a PROVEN verdict, which is the exact failure this harness exists to prevent' }

        $rU = Test-OneGate -Facts $honest -DocRow $null -Recipe $unclaimedRecipe -Skill $Skill -Build $fxBuild -Scratch $scratch -TimeoutSec 60
        if ($rU.ClaimState -ne 'ESTABLISHED') { TOk 'a claim absent from the gate header is reported as not established' }
        else { TBad 'a claim the gate never publishes was treated as established' }
        if (-not $rU.FailsOnPlant -and -not $rU.PlantLanded) { TOk 'no plant is run when the claim cannot be established' }
        else { TBad 'a plant ran for a claim the gate never made' }
        if ($rU.Verdict -ne 'PROVEN' -and $rU.Reason -match 'could not be established') {
            TOk 'the verdict names the unestablished claim instead of blaming the gate'
        }
        else { TBad ("expected an unestablished-claim verdict, got {0} / {1}" -f $rU.Verdict, $rU.Reason) }
        if ($rU.Reason -notmatch 'PASSED a verified plant') { TOk 'the harness never says a gate passed a plant of a claim it never made' }
        else { TBad 'the harness emitted the false-HIGH wording' }

        $probeCannot = [pscustomobject]@{ Name = 'Check-CannotFail'; File = $cannot.File; Stages = @('3c'); Blocking = $true
                                          Arguments = @(); WhatIf = $false; WhatIfWhy = 'fixture probe plan' }

        $r3 = Test-OneGate -Facts $cannot -DocRow $null -Recipe $landingRecipe -Skill $Skill -Build $fxBuild -Scratch $scratch -TimeoutSec 60 -Probe $probeCannot
        if ($r3.Verdict -eq 'UNPROVEN') { TOk 'a gate that exits 0 on everything is UNPROVEN' } else { TBad ("a gate that cannot fail was reported {0}" -f $r3.Verdict) }
        if (-not $r3.RefusesEmpty -and $r3.ProbeState -eq 'EXITED-0') { TOk 'a gate that exits 0 with no arguments at all is recorded as not refusing' }
        else { TBad ("the refusal probe misread the always-pass gate ({0})" -f $r3.ProbeState) }

        $r4 = Test-OneGate -Facts $blind -DocRow $null -Recipe $null -Skill $Skill -Build $fxBuild -Scratch $scratch -TimeoutSec 60
        if ($r4.Verdict -eq 'WEAK-SELFTEST') { TOk 'a passing self-test that never verifies its plant is WEAK-SELFTEST, not PROVEN' }
        else { TBad ("expected WEAK-SELFTEST, got {0}" -f $r4.Verdict) }

        # -------------------------------------------------------------------
        # P0-13: the tautology, and the anchor rules
        # -------------------------------------------------------------------

        $rA = Test-OneGate -Facts $angry -DocRow $null -Recipe $landingRecipe -Skill $Skill -Build $fxBuild -Scratch $scratch -TimeoutSec 60
        if ($rA.Verdict -ne 'PROVEN' -and $rA.Verdict -ne 'PROVEN-NOCLEAN') {
            TOk ("a gate that exits 1 on the clean build AND on the planted one is {0}, not PROVEN, even though it named the plant" -f $rA.Verdict)
        }
        else { TBad ("the tautology survived: a gate exiting 1 on both arms was reported {0}" -f $rA.Verdict) }
        if ("$($rA.Reason)" -match 'exited 1 on the clean build and 1 on the planted one') {
            TOk 'the unproven verdict names BOTH exit codes rather than only the failing one'
        }
        else { TBad ("expected both exits in the reason, got: {0}" -f $rA.Reason) }
        if ("$($rA.CleanExit)" -eq '1' -and "$($rA.PlantExit)" -eq '1' -and -not $rA.FailsOnPlant) {
            TOk 'FailsOnPlant is false when the clean exit and the planted exit are the same code'
        }
        else { TBad ("clean {0} / plant {1} / failsOnPlant {2}" -f $rA.CleanExit, $rA.PlantExit, $rA.FailsOnPlant) }

        #  ONE ROW, WHATEVER THE RECIPE EMITS. A recipe with a Fixture block
        #  that returns the directory it built put that string on
        #  Test-OneGate's output stream, and every results[] row for such a
        #  gate reached the report as [path, object] - which the runners read
        #  as a gate with no name and no verdict, on gates that were PROVEN.
        $chattyRecipe = [pscustomobject]@{
            Gate = 'Check-Honest'; Kind = 'a marker, from a recipe whose Fixture block returns a value'
            Fixture = { param($fx) return $fx.Dir }
            Prepare = { param($fx) return 'and so does Prepare' }
            Plant = $landingRecipe.Plant
            Verify = $landingRecipe.Verify
            Args = $landingRecipe.Args
            NameInOutput = 'PLANTEDMARKER'
            ClaimRx = '(?i)forbidden marker'
        }
        $rC = @(Test-OneGate -Facts $honest -DocRow $null -Recipe $chattyRecipe -Skill $Skill -Build $fxBuild -Scratch $scratch -TimeoutSec 60)
        if ($rC.Count -eq 1 -and $null -ne $rC[0].PSObject.Properties['Verdict'] -and $rC[0].Verdict -eq 'PROVEN') {
            TOk 'a recipe whose Fixture and Prepare blocks return values still yields exactly ONE result row carrying a verdict'
        }
        else { TBad ("expected one PROVEN row, got {0} object(s): {1}" -f $rC.Count, (($rC | ForEach-Object { "$_" }) -join ' | ')) }

        $rN = Test-OneGate -Facts $honest -DocRow $null -Recipe $shortNeedleRecipe -Skill $Skill -Build $fxBuild -Scratch $scratch -TimeoutSec 60
        if ($rN.NeedleState -eq 'TOO-SHORT') { TOk "the needle '0' is rejected as too short before it can match an exit code" }
        else { TBad ("expected NeedleState TOO-SHORT, got {0}" -f $rN.NeedleState) }
        if ($rN.Verdict -ne 'PROVEN' -and "$($rN.Reason)" -match 'at least three characters') {
            TOk 'a gate anchored only on a one-character needle is not PROVEN, and the reason says three characters'
        }
        else { TBad ("expected an unproven short-needle verdict, got {0} / {1}" -f $rN.Verdict, $rN.Reason) }

        # -------------------------------------------------------------------
        # P0-02 (this half): the ledger stage table, read BY SYNTAX TREE
        # -------------------------------------------------------------------

        $noTable = Get-LedgerStageView -Skill $tmp
        if (-not $noTable.Found -and "$($noTable.Note)" -match 'stage table not found') {
            TOk 'with no stage table on disk the reader reports "stage table not found" rather than a default'
        }
        else { TBad ("expected a named stage-table-not-found, got Found={0} / {1}" -f $noTable.Found, $noTable.Note) }

        Write-FixtureText -File (Join-Path $fxScripts 'Stage-Ledger.ps1') -Body @'
<# A fixture ledger carrying the one ordered stage table. #>
param([switch] $Check)
$script:LedgerStages = @(
    [pscustomobject]@{ Key = '0';  Required = $true;  Blocking = $true;  Conditional = $false; Terminal = $false; Script = 'Check-Honest.ps1' }
    [pscustomobject]@{ Key = '3c'; Required = $true;  Blocking = $true;  Conditional = $false; Terminal = $false; Script = 'Check-Careful.ps1' }
    [pscustomobject]@{ Key = '7';  Required = $false; Blocking = $false; Conditional = $true;  Terminal = $false; Script = '' }
    [pscustomobject]@{ Key = '8';  Required = $true;  Blocking = $true;  Conditional = $false; Terminal = $true;  Script = '' }
)
if ($Check) { exit 0 }
'@

        $view = Get-LedgerStageView -Skill $tmp
        if ($view.Found -and "$($view.Source)" -match 'syntax tree' -and (@($view.Keys) -join ',') -eq '0,3c,7,8') {
            TOk 'the stage table is read from the HashtableAst rows of the one assignment, in order, with nothing executed'
        }
        else { TBad ("the stage table was misread: found={0} source={1} keys={2}" -f $view.Found, $view.Source, (@($view.Keys) -join ',')) }
        if ((@($view.Blocking) -join ',') -eq '0,3c,8' -and (@($view.Conditional) -join ',') -eq '7' -and (@($view.Terminal) -join ',') -eq '8') {
            TOk 'Blocking, Conditional and Terminal come off the table columns, not from an array typed here'
        }
        else { TBad ("blocking={0} conditional={1} terminal={2}" -f (@($view.Blocking) -join ','), (@($view.Conditional) -join ','), (@($view.Terminal) -join ',')) }

        $probeSet = Get-RefusalProbeSet -Ledger $view -Skill $tmp
        if ($probeSet.Found -and $probeSet.Set.ContainsKey('Check-Honest') -and $probeSet.Set.ContainsKey('Check-Careful')) {
            TOk 'the refusal probe set is the Script column of the stage table and nothing else'
        }
        else { TBad ("the probe set was not derived from the Script column: {0}" -f $probeSet.Note) }
        if ($probeSet.Found -and -not $probeSet.Set['Check-Honest'].WhatIf -and @($probeSet.Set['Check-Honest'].Arguments).Count -eq 0 -and
            "$($probeSet.Set['Check-Honest'].WhatIfWhy)" -match 'does not declare SupportsShouldProcess') {
            TOk 'a stage-table row whose script lacks SupportsShouldProcess is probed WITHOUT -WhatIf, and the row records why'
        }
        else { TBad 'the no-ShouldProcess script was not recorded as probed without -WhatIf' }
        if ($probeSet.Found -and $probeSet.Set['Check-Careful'].WhatIf -and (@($probeSet.Set['Check-Careful'].Arguments) -join ' ') -eq '-WhatIf') {
            TOk 'a script whose CmdletBinding declares SupportsShouldProcess is probed with -WhatIf, decided from the syntax tree'
        }
        else { TBad 'the ShouldProcess script was not probed with -WhatIf' }

        # -------------------------------------------------------------------
        # The static arms: orphan recipe, unparseable gate, header findings
        # -------------------------------------------------------------------

        $fsSetFx = Get-FilesystemGateSet -Skill $tmp
        $docFx = @(
            [pscustomobject]@{ Stage = '3c'; StageKeys = @('3c'); Gate = 'broken'; Name = 'Check-Broken'; Marker = 'implemented'
                               Blocks = 'yes'; BlocksYes = $true; Section = ''; File = $broken.File; OnDisk = $true
                               AsFunction = ''; Aliases = @(); Judgement = $false; ScriptCell = '' }
            [pscustomobject]@{ Stage = '3c'; StageKeys = @('3c'); Gate = 'honest'; Name = 'Check-Honest'; Marker = 'implemented'
                               Blocks = 'yes'; BlocksYes = $true; Section = ''; File = $honest.File; OnDisk = $true
                               AsFunction = ''; Aliases = @(); Judgement = $false; ScriptCell = '' }
        )
        $orphan = @([pscustomobject]@{ Gate = 'Check-NotOnDisk'; Kind = 'a defect in a gate that does not exist' })
        $hdrFx = Get-HeaderReconciliation -FsSet $fsSetFx -DocRows $docFx -Ledger $view
        $findFx = Get-StaticFindings -FsSet $fsSetFx -DocRows $docFx -Recipes $orphan -Headers $hdrFx -Plans $null -Ledger $view

        $orphanRow = @($findFx | Where-Object { $_.Kind -eq 'ORPHAN-RECIPE' -and $_.Gate -eq 'Check-NotOnDisk' })
        if ($orphanRow.Count -eq 1 -and $orphanRow[0].Blocking) { TOk 'a recipe naming a gate that is not on disk is an ORPHAN-RECIPE finding that blocks' }
        else { TBad ("expected one blocking ORPHAN-RECIPE row, got {0}" -f $orphanRow.Count) }

        $parseRow = @($findFx | Where-Object { $_.Kind -eq 'PARSE-ERROR' -and $_.Gate -eq 'Check-Broken' })
        if ($parseRow.Count -eq 1 -and $parseRow[0].Blocking -and "$($parseRow[0].Detail)" -match 'does not parse') {
            TOk 'a gate script with a syntax error is a blocking PARSE-ERROR finding that names it, instead of vanishing from the set'
        }
        else { TBad ("expected one blocking PARSE-ERROR row naming Check-Broken, got {0}" -f $parseRow.Count) }

        $hdrRow = @($findFx | Where-Object { $_.Kind -eq 'NO-HEADER' -and $_.Gate -eq 'Check-Honest' })
        if ($hdrRow.Count -eq 1) { TOk "a gate carrying no '# GATE:' header is a finding, because Run-SpineGates puts it in no band" }
        else { TBad ("expected a NO-HEADER finding for Check-Honest, got {0}" -f $hdrRow.Count) }

        #  A header naming a stage the table does not know, and a requires=
        #  name that is not a parameter of the script.
        Write-FixtureText -File (Join-Path $fxScripts 'Check-Headered.ps1') -Body @'
<# A fixture gate whose header names a stage nobody knows. #>
# GATE: stages=3c,99z; requires=BuildDir,NotAParameter
param([string] $BuildDir)
if (-not $BuildDir) { exit 2 }
exit 0
'@
        $fsSet2 = Get-FilesystemGateSet -Skill $tmp
        $hdr2 = Get-HeaderReconciliation -FsSet $fsSet2 -DocRows $docFx -Ledger $view
        $hrow = @($hdr2 | Where-Object { $_.Gate -eq 'Check-Headered' })
        $probs = @()
        if ($hrow.Count -eq 1) { $probs = @($hrow[0].Problems) }
        if (@($probs | Where-Object { $_ -match "stage '99z' is not a stage key the ledger knows" }).Count -eq 1) {
            TOk 'a header naming a stage the ledger stage table does not know is a finding'
        }
        else { TBad ("expected an unknown-stage problem, got: {0}" -f ($probs -join ' | ')) }
        if (@($probs | Where-Object { $_ -match 'requires=NotAParameter names no parameter' }).Count -eq 1) {
            TOk 'a requires= name that is not a parameter of the script is a finding'
        }
        else { TBad ("expected a requires-not-a-parameter problem, got: {0}" -f ($probs -join ' | ')) }

        #  A HEADER UNDER A LONG BLOCK COMMENT IS STILL A HEADER. This
        #  script's own header sits at line 117; a 60-line window reported the
        #  harness itself as headerless while Run-SpineGates read the same
        #  line without difficulty.
        $deepBody = New-Object System.Text.StringBuilder
        [void]$deepBody.AppendLine('<#')
        for ($di = 0; $di -lt 80; $di++) { [void]$deepBody.AppendLine('    a long header block comment, line ' + $di) }
        [void]$deepBody.AppendLine('#>')
        [void]$deepBody.AppendLine('# GATE: stages=3c; requires=BuildDir')
        [void]$deepBody.AppendLine('param([string] $BuildDir)')
        [void]$deepBody.AppendLine('if (-not $BuildDir) { exit 2 }')
        [void]$deepBody.AppendLine('exit 0')
        Write-FixtureText -File (Join-Path $fxScripts 'Check-Deep.ps1') -Body $deepBody.ToString()
        $deepFacts = Get-ScriptFacts -File (Join-Path $fxScripts 'Check-Deep.ps1')
        if ($null -ne $deepFacts.GateHeader -and (@($deepFacts.GateHeader.Stages) -join ',') -eq '3c' -and $deepFacts.GateHeader.Line -gt 60) {
            TOk ("a '# GATE:' header on line {0}, under an 82-line block comment, is still read - the scan stops at param(), not at a line count" -f $deepFacts.GateHeader.Line)
        }
        else { TBad 'a header below the first 60 lines was missed' }

        # -------------------------------------------------------------------
        # The scripts hash keys the result file NAME
        # -------------------------------------------------------------------

        $h1 = Get-ScriptsHash -Skill $tmp -Recipes $orphan
        $victim = Join-Path $fxScripts 'Check-CannotFail.ps1'
        $bytes = [System.IO.File]::ReadAllBytes($victim)
        [System.IO.File]::WriteAllBytes($victim, ($bytes + [byte]32))
        $h2 = Get-ScriptsHash -Skill $tmp -Recipes $orphan
        if ($h1 -ne $h2 -and $h1.Length -eq 64 -and $h2.Length -eq 64) {
            TOk 'one byte appended to one scripts\*.ps1 changes the hash, so a later run writes a differently named result file'
        }
        else { TBad ("the scripts hash did not move on a one-byte edit ({0} vs {1})" -f $h1, $h2) }
        if (('gate-fixtures.' + $h1 + '.json') -ne ('gate-fixtures.' + $h2 + '.json')) {
            TOk 'the result file NAME carries the hash, so a stale report cannot be read as a verdict about these scripts'
        }
        else { TBad 'the result file name did not change with the hash' }

        # -------------------------------------------------------------------
        # -StaticOnly runs end to end and prints its wall clock
        # -------------------------------------------------------------------

        $selfPath = $PSCommandPath
        if (-not $selfPath -and $MyInvocation.MyCommand.Path) { $selfPath = $MyInvocation.MyCommand.Path }
        if ($selfPath -and (Test-Path -LiteralPath $selfPath)) {
            $so = Invoke-GateProcess -File $selfPath -Arguments @('-StaticOnly', '-SkillDir', $tmp) -TimeoutSec 180
            if (-not $so.TimedOut -and @(0, 1, 3) -contains $so.Exit) {
                TOk ("-StaticOnly runs end to end over a skill directory and exits {0} in {1}s" -f $so.Exit, $so.Seconds)
            }
            else { TBad ("-StaticOnly did not finish (timedOut={0}, exit={1})" -f $so.TimedOut, $so.Exit) }
            if ([regex]::IsMatch("$($so.Text)", '(?m)^\s*STATIC ARMS - \d+ script\(s\) examined in [0-9.]+s wall clock\.')) {
                TOk '-StaticOnly prints how many scripts it examined and its wall clock'
            }
            else { TBad '-StaticOnly printed no wall-clock line' }
            if ([regex]::IsMatch("$($so.Text)", '(?i)(stage table not found|ledger stage table)')) {
                TOk '-StaticOnly names the stage table it read, or says it could not find one'
            }
            else { TBad '-StaticOnly said nothing about the stage table' }
        }
        else { TBad 'the self-test could not locate its own script path to run -StaticOnly' }

        $set = Get-FilesystemGateSet -Skill $tmp
        if ($set.Count -ge 3) { TOk ("discovery enumerates {0} gates from the filesystem with no list typed anywhere" -f $set.Count) }
        else { TBad ("discovery found {0} gates" -f $set.Count) }
    }
    finally {
        if ((Test-Path -LiteralPath $tmp) -and $tmp.Length -gt 12) {
            Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host ''
    if ($script:stFail -eq 0) {
        Write-Host ("SELF-TEST PASS - {0} checks, including the plant that did not land and the gate that fails on everything." -f $script:stPass) -ForegroundColor Green
        return 0
    }
    Write-Host ("SELF-TEST FAIL - {0} of {1} checks failed. This harness is not evidence of anything until they pass." -f $script:stFail, ($script:stFail + $script:stPass)) -ForegroundColor Red
    return 4
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if ($SelfTest) { exit (Invoke-FixtureSelfTest -Skill $SkillDir) }

if (-not $SkillDir -or -not (Test-Path -LiteralPath $SkillDir)) {
    Write-Host ("{0}: -SkillDir '{1}' does not exist. This gate refuses rather than reporting a proven set it never read." -f $GATE, $SkillDir) -ForegroundColor Red
    exit 2
}
if (-not $GatesDoc) { $GatesDoc = Join-Path $SkillDir 'references\gates.md' }

$script:WallClock = [System.Diagnostics.Stopwatch]::StartNew()

$partial = $false
$partialWhy = New-Object System.Collections.Generic.List[string]
if ($null -ne $Only -and $Only.Count -gt 0) { $partial = $true; $partialWhy.Add('only ' + ($Only -join ', ')) }
if (-not $StaticOnly) {
    if (-not $BuildDir) { $partial = $true; $partialWhy.Add('no -BuildDir, so no external plant could be cut') }
    elseif (-not (Test-Path -LiteralPath $BuildDir)) {
        Write-Host ("{0}: -BuildDir '{1}' does not exist." -f $GATE, $BuildDir) -ForegroundColor Red
        exit 2
    }
}
elseif ($BuildDir -and -not (Test-Path -LiteralPath $BuildDir)) {
    Write-Host ("{0}: -BuildDir '{1}' does not exist." -f $GATE, $BuildDir) -ForegroundColor Red
    exit 2
}
if (-not $ResultDir -and $BuildDir) { $ResultDir = $BuildDir }

$Only = Expand-CommaList -Value $Only

# ---------------------------------------------------------------------------
# Derivation. Both modes share it; the static mode stops after it.
# ---------------------------------------------------------------------------

#  -Deep (the plant-verification walk over every syntax tree) is the expensive
#  half of discovery and the static arms do not use it: they ask whether a
#  self-test EXISTS, not whether it reads its plant back. Leaving it off is
#  what keeps -StaticOnly inside a band's budget.
#  EVERY DERIVED SET IS WRAPPED IN @(). An empty result unrolls to $null on
#  the way into the next Mandatory parameter, and the harness died in a
#  parameter binder on a skill whose gates.md was not where it usually is -
#  before printing a single line about the set it had already derived.
$script:BeforeStamp = Get-ScriptStamp -Skill $SkillDir
$fsSet = @(Get-FilesystemGateSet -Skill $SkillDir -Deep:(-not $StaticOnly))
$docRows = @(Get-GatesDocClaim -Doc $GatesDoc -Skill $SkillDir)
$script:GatesDocText = ''
try { $script:GatesDocText = Read-FixtureText -File $GatesDoc } catch { $script:GatesDocText = '' }
$recipes = @(Get-FixtureRecipe -Skill $SkillDir)
$ledger = Get-LedgerStageView -Skill $SkillDir
$plans = Get-RunnerPlanView -Skill $SkillDir
$headers = @(Get-HeaderReconciliation -FsSet $fsSet -DocRows $docRows -Ledger $ledger)
$probes = Get-RefusalProbeSet -Ledger $ledger -Skill $SkillDir
$findings = @(Get-StaticFindings -FsSet $fsSet -DocRows $docRows -Recipes $recipes -Headers $headers -Plans $plans -Ledger $ledger)
$scriptsHash = Get-ScriptsHash -Skill $SkillDir -Recipes $recipes

#  NAMED PARTIALS, never a silent narrowing. Each of these is an input this
#  harness reconciles against and did not get; a run missing one still reports
#  what it did see, and says by name what it could not.
if (-not $ledger.Found) { $partial = $true; $partialWhy.Add('stage table not found: ' + $ledger.Note) }
if (-not $probes.Found) { $partial = $true; $partialWhy.Add('no refusal probe set: ' + $probes.Note) }
if (-not $plans.SpineFound) { $partial = $true; $partialWhy.Add('Run-SpineGates stage vocabulary unreadable: ' + $plans.SpineNote) }
if (-not $plans.GatesFound) { $partial = $true; $partialWhy.Add('Run-Gates 4/7c plan unreadable: ' + $plans.GatesNote) }

if (-not $Quiet) {
    Write-Host ''
    Write-Host ('GATE FIXTURES - {0}{1}' -f $GATE, $(if ($StaticOnly) { ' (static arms only)' } else { '' })) -ForegroundColor Cyan
    Write-Host ('  check-set: {0} gate scripts, derived from {1}' -f $fsSet.Count, (Join-Path $SkillDir 'scripts')) -ForegroundColor DarkGray
    Write-Host ('  plus {0} script names claimed by the stage table in {1}' -f $docRows.Count, [System.IO.Path]::GetFileName($GatesDoc)) -ForegroundColor DarkGray
    Write-Host ('  fixture recipes available: {0}' -f $recipes.Count) -ForegroundColor DarkGray
    Write-Host ('  scripts+recipes hash: {0}' -f $scriptsHash.Substring(0, 16)) -ForegroundColor DarkGray
    Write-Host ('  ledger stage table: {0}' -f $(if ($ledger.Found) { ("{0} stage(s), from the {1}" -f @($ledger.Keys).Count, $ledger.Source) } else { $ledger.Note })) -ForegroundColor DarkGray
    Write-Host ('  refusal probe set: {0}' -f $(if ($probes.Found) { ("{0} script(s), from {1}" -f $probes.Set.Count, $probes.Source) } else { $probes.Note })) -ForegroundColor DarkGray
}

#  Reconcile the doc's claims against the filesystem, both ways.
$fsByName = @{}
foreach ($g in $fsSet) { $fsByName[$g.Name] = $g }
$docByName = @{}
$claimIssues = New-Object System.Collections.Generic.List[object]
foreach ($row in $docRows) {
    if (-not $docByName.ContainsKey($row.Name)) { $docByName[$row.Name] = $row }
    $present = ($row.OnDisk -or $row.AsFunction)
    if ($row.Marker -ne 'implemented' -and $present) {
        #  REPORTED, NOT ASSERTED. A marker in one of these cells can belong to
        #  the design name beside the script ("Assert-RendererContract - NOT
        #  YET IMPLEMENTED; the write-time arm is scripts\Test-SpineRead.ps1")
        #  or to one ARM of a script that exists ("Test-Readability spine arm -
        #  NOT YET IMPLEMENTED"). Calling those stale was three false findings
        #  against the documentation. The anchor is named; a reader decides.

        if ($row.Aliases.Count -gt 0) {
            $claimIssues.Add([pscustomobject]@{ Name = $row.Name; Issue = 'MARKER-CHECK'
                Detail = ("the row is marked {0} and names {1} as well; the marker probably belongs to that design name rather than to {2}, which is on disk. Read the cell." -f $row.Marker, ($row.Aliases -join ', '), $row.Name) })
        }
        else {
            $claimIssues.Add([pscustomobject]@{ Name = $row.Name; Issue = 'MARKER-CHECK'
                Detail = ("the row is marked {0} and {1} is on disk. If the marker is scoped to one ARM of it rather than to the script, the cell is right and this is noise; otherwise the marker is stale." -f $row.Marker, $row.Name) })
        }
    }
    elseif ($row.Marker -eq 'implemented' -and -not $present) {
        $claimIssues.Add([pscustomobject]@{ Name = $row.Name; Issue = 'CLAIMED-ABSENT'
            Detail = ('the stage table names it without a marker, and no script or function of that name is on disk in this skill or any sibling skill' + $(if ($row.Aliases.Count -gt 0) { ' (nor any of: ' + ($row.Aliases -join ', ') + ')' } else { '' })) })
    }
}

# ---------------------------------------------------------------------------
# The static findings, printed the same way in both modes
# ---------------------------------------------------------------------------

function Write-StaticFindings {
    param($Rows, $Headers, $Plans)
    if ($Quiet) { return }
    $withHeader = @(@($Headers) | Where-Object { $_.HasHeader })
    Write-Host ''
    Write-Host ("'# GATE:' HEADERS - {0} of {1} scripts carry one" -f $withHeader.Count, @($Headers).Count) -ForegroundColor Cyan
    if ($null -ne $Plans) {
        Write-Host ('  Run-SpineGates vocabulary: {0}' -f $(if ($Plans.SpineFound) { (@($Plans.SpineStages) -join ', ') } else { $Plans.SpineNote })) -ForegroundColor DarkGray
        $gatesLine = $Plans.GatesNote
        if ($Plans.GatesFound) {
            $gatesLine = ("{0} named entr(ies)" -f @($Plans.GatesScripts).Count)
            if (@($Plans.GatesUnresolved).Count -gt 0) { $gatesLine = $gatesLine + (", {0} behind a variable and UNRESOLVED" -f @($Plans.GatesUnresolved).Count) }
        }
        Write-Host ('  Run-Gates 4/7c plan: {0}' -f $gatesLine) -ForegroundColor DarkGray
    }
    $rowsOut = @($Rows)
    if ($rowsOut.Count -eq 0) {
        Write-Host '  no static finding' -ForegroundColor Green
        return
    }
    Write-Host ''
    Write-Host 'STATIC FINDINGS - decided without running anything' -ForegroundColor Yellow
    foreach ($f in ($rowsOut | Sort-Object @{ Expression = { -[int][bool]$_.Blocking } }, Kind, Gate)) {
        $c = 'Yellow'
        if ($f.Blocking) { $c = 'Red' }
        Write-Host ("  {0,-14} {1,-30} {2,-10} {3}" -f $f.Kind, $f.Gate, $(if ($f.Blocking) { '[blocks]' } else { '[reported]' }), (Get-ShortLine -Value $f.Detail -Max 180)) -ForegroundColor $c
    }
}

$blockingFindings = @(@($findings) | Where-Object { $_.Blocking })

if ($StaticOnly) {
    Write-StaticFindings -Rows $findings -Headers $headers -Plans $plans

    if ($ResultDir) {
        if (-not (Test-Path -LiteralPath $ResultDir)) { New-Item -ItemType Directory -Force -Path $ResultDir | Out-Null }
        $sbody = [ordered]@{
            gate         = $GATE
            mode         = 'static'
            checkedAt    = (Get-Date).ToString('o')
            scriptsHash  = $scriptsHash
            skillDir     = "$SkillDir"
            gatesDoc     = "$GatesDoc"
            partialRun   = $partial
            partialWhy   = $partialWhy.ToArray()
            gateSetSize  = $fsSet.Count
            recipeCount  = $recipes.Count
            ledger       = [ordered]@{ found = [bool]$ledger.Found; source = "$($ledger.Source)"; note = "$($ledger.Note)"; keys = @($ledger.Keys); blocking = @($ledger.Blocking) }
            probeSet     = [ordered]@{ found = [bool]$probes.Found; source = "$($probes.Source)"; note = "$($probes.Note)"
                                       scripts = @(@($probes.Set.Keys) | Sort-Object | ForEach-Object { [ordered]@{ name = $_; whatIf = [bool]$probes.Set[$_].WhatIf; why = "$($probes.Set[$_].WhatIfWhy)" } }) }
            runnerPlans  = [ordered]@{ spineStages = @($plans.SpineStages); spineNote = "$($plans.SpineNote)"
                                       gatesScripts = @($plans.GatesScripts); gatesUnresolved = @($plans.GatesUnresolved); gatesNote = "$($plans.GatesNote)" }
            headers      = @($headers)
            findings     = @($findings)
            claimIssues  = $claimIssues.ToArray()
            seconds      = [Math]::Round($script:WallClock.Elapsed.TotalSeconds, 2)
        }
        Write-FixtureText -File (Join-Path $ResultDir 'gate-fixtures.static.json') -Body ($sbody | ConvertTo-Json -Depth 8)
    }

    $script:WallClock.Stop()
    Write-Host ''
    Write-Host ("STATIC ARMS - {0} script(s) examined in {1}s wall clock." -f $fsSet.Count, [Math]::Round($script:WallClock.Elapsed.TotalSeconds, 2)) -ForegroundColor Cyan
    if ($blockingFindings.Count -gt 0) {
        Write-Host ("STATIC FAIL - {0} finding(s) on blocking gates: {1}. The plant channel is a separate run and does not excuse these." -f `
            $blockingFindings.Count, ((@($blockingFindings | ForEach-Object { $_.Gate }) | Select-Object -Unique) -join ', ')) -ForegroundColor Red
        exit 1
    }
    if ($partial) {
        #  NEVER A PASS ON A MISSING INPUT. The stage table, the probe plan and
        #  the two runner plans are inputs this arm reconciles against; with one
        #  of them absent the reconciliation covered less than it claims, and
        #  saying so is what an exit code is for. 3 is PARTIAL RUN.
        Write-Host ("STATIC PARTIAL - the arms that ran found no blocking finding, but this run could not read: {0}. A partial run cannot stand for the fixtures gate." -f ($partialWhy -join '; ')) -ForegroundColor Yellow
        exit 3
    }
    if (@($findings).Count -gt 0) {
        Write-Host ("STATIC PASS - {0} finding(s), none on a blocking gate; they are reported and carried in the report." -f @($findings).Count) -ForegroundColor Green
    }
    else { Write-Host 'STATIC PASS - no static finding.' -ForegroundColor Green }
    exit 0
}

# ---------------------------------------------------------------------------
# The plant channel
# ---------------------------------------------------------------------------

$results = New-Object System.Collections.Generic.List[object]
$scratch = Join-Path ([System.IO.Path]::GetTempPath()) ('gatefx_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $scratch | Out-Null
$timeoutSec = [Math]::Max(60, $TimeoutMinutes * 60)

#  NOTHING IS RUN AGAINST THE GIVEN BUILD. Every gate here is handed a lean
#  COPY, because a gate's own -SelfTest is free to write a report beside the
#  inputs it was given, and a harness that proves gates by modifying the build
#  it was pointed at is a harness that cannot be run on anything that matters.
$script:FixtureOriginBuild = $BuildDir
$baseline = ''
if ($BuildDir) {
    $baseline = Join-Path $scratch 'baseline'
    $null = New-LeanBuildCopy -Source $BuildDir -Dest $baseline
    #  The two delivered artefacts, for the gates whose self-test needs one.
    $outDir = Join-Path $BuildDir 'out'
    if (Test-Path -LiteralPath $outDir) {
        $keep = Join-Path $baseline 'out'
        New-Item -ItemType Directory -Force -Path $keep | Out-Null
        foreach ($ext in @('*.docx', '*.pptx')) {
            $cand = @(Get-ChildItem -LiteralPath $outDir -Filter $ext -File -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -notmatch '(?i)(~\$|backup|_bak)' } | Sort-Object Length -Descending)
            if ($cand.Count -gt 0) { Copy-Item -LiteralPath $cand[0].FullName -Destination $keep -Force -ErrorAction SilentlyContinue }
        }
    }
    if (-not $Quiet) { Write-Host ('  baseline: a lean copy of the given build; the build itself is never written to') -ForegroundColor DarkGray }
}

try {
    foreach ($g in $fsSet) {
        if ($null -ne $Only -and $Only.Count -gt 0) {
            $want = $false
            foreach ($o in $Only) { if ("$o" -ieq $g.Name) { $want = $true } }
            if (-not $want) { continue }
        }
        $recipe = $null
        foreach ($r in $recipes) { if ($r.Gate -ieq $g.Name) { $recipe = $r } }
        $docRow = $null
        if ($docByName.ContainsKey($g.Name)) { $docRow = $docByName[$g.Name] }
        $probe = $null
        if ($probes.Set.ContainsKey($g.Name)) { $probe = $probes.Set[$g.Name] }

        if ($ListOnly) {
            $results.Add([pscustomobject]@{
                Gate = $g.Name; Stage = $(if ($null -ne $docRow) { $docRow.Stage } else { '' })
                Blocks = $(if ($null -ne $docRow) { $docRow.Blocks } else { '' })
                Section = $(if ($null -ne $docRow) { $docRow.Section } else { '' })
                Claim = $g.Claim; HasSelfTest = $g.HasSelfTest; SelfTestVerifiesPlant = $g.SelfTestVerifiesPlant
                PlantVerifyState = "$($g.PlantVerifyState)"; PlantVerifyEvidence = "$($g.PlantVerifyEvidence)"
                SelfTestRc = ''; SelfTestOk = $false
                ClaimState = 'n/a'; ClaimEvidence = ''; Disclaimers = @(); SelfTestVerdict = 'NOT-RUN'
                HasFixture = ($null -ne $recipe); PlantKind = $(if ($null -ne $recipe) { $recipe.Kind } else { '' })
                PlantLanded = $false; FailsOnPlant = $false; PassesClean = $false; RefusesEmpty = $false
                ProbeState = $(if ($null -ne $probe) { 'PLANNED' } else { 'NOT-PROBED' }); ProbeWhy = ''
                ProbeWhatIf = $(if ($null -ne $probe) { [bool]$probe.WhatIf } else { $false })
                CleanExit = ''; PlantExit = ''; CleanRan = $false; NeedleState = 'n/a'
                Verdict = 'NOT RUN'; Reason = '-ListOnly'; Seconds = 0.0
            })
            continue
        }

        if (-not $Quiet) { Write-Host ("  proving {0} ..." -f $g.Name) -ForegroundColor DarkGray }
        $sectionText = Get-GateSectionText -DocText $script:GatesDocText -Name $g.Name
        #  ONE ROW PER GATE, CHECKED. A recipe scriptblock that emits anything
        #  puts it on Test-OneGate's output stream, and the row that reached
        #  this report was then an array whose first element was a path. The
        #  runners read results[].Gate and results[].Verdict, so a proven gate
        #  arrived as UNPROVEN with no name. It is cheaper to refuse here than
        #  to read a report that says nothing.
        $rowSet = @(Test-OneGate -Facts $g -DocRow $docRow -Recipe $recipe -Skill $SkillDir -Build $baseline -Scratch $scratch -TimeoutSec $timeoutSec -SectionText $sectionText -Probe $probe)
        $rows = @($rowSet | Where-Object { $null -ne $_ -and $null -ne $_.PSObject.Properties['Verdict'] })
        if ($rows.Count -ne 1) {
            throw ("HARNESS DEFECT proving {0}: Test-OneGate emitted {1} object(s) carrying a Verdict out of {2} returned. A recipe scriptblock is writing to the output stream; suppress it with `$null = . The report is not written." -f $g.Name, $rows.Count, $rowSet.Count)
        }
        $results.Add($rows[0])
    }
}
finally {
    if ((Test-Path -LiteralPath $scratch) -and $scratch.Length -gt 12) {
        Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
    }
}

#  Specified-but-absent gates are part of the answer, not an omission.
foreach ($row in $docRows) {
    if ($fsByName.ContainsKey($row.Name)) { continue }
    $already = $false
    foreach ($r in $results) { if ($r.Gate -ieq $row.Name) { $already = $true } }
    if ($already) { continue }
    #  RESOLUTION decides this, not membership of the gate set. The first
    #  version asked whether the resolved name was one of the scripts that can
    #  return a verdict, so a row performed by a script with no exit code -
    #  Get-DocText.ps1 - was reported as performed by nobody. The script is
    #  right there in the cell.
    if ($row.File) { continue }
    $verdict = 'SPECIFIED-ABSENT'
    $reason = ('the stage table names this gate ({0}) and no script or function of that name is on disk, so nothing performs it' -f $row.Marker)
    if ($row.Judgement) {
        #  A JUDGEMENT ROW IS NOT A MISSING GATE. The table says in as many
        #  words that a reader performs it and records a verdict; no fixture
        #  can plant into a reader, and pretending otherwise would put a
        #  permanent false finding at the top of every run.
        $verdict = 'JUDGEMENT-ONLY'
        $reason = 'the stage table records this as a judgement with a verdict, performed by a reader and not by a script, so no fixture can prove it and none is claimed'
    }
    $results.Add([pscustomobject]@{
        Gate = $(if ($row.Name) { $row.Name } else { $row.Gate }); Stage = $row.Stage; Blocks = $row.Blocks; Section = $row.Section
        Claim = ''; HasSelfTest = $false; SelfTestVerifiesPlant = $false; SelfTestRc = ''; SelfTestOk = $false
        PlantVerifyState = 'N/A'; PlantVerifyEvidence = ''
        ClaimState = 'n/a'; ClaimEvidence = ''; Disclaimers = @(); SelfTestVerdict = 'NOT-RUN'
        HasFixture = $false; PlantKind = ''; PlantLanded = $false; FailsOnPlant = $false
        PassesClean = $false; RefusesEmpty = $false
        ProbeState = 'NOT-PROBED'; ProbeWhy = 'there is no script to probe'; ProbeWhatIf = $false
        CleanExit = ''; PlantExit = ''; CleanRan = $false; NeedleState = 'n/a'
        Verdict = $verdict; Reason = $reason; Seconds = 0.0
    })
}

#  Anything that moved while this ran is named rather than covered silently.
#  BOTH SIDES ARE THE SAME SET. Comparing the after-stamp of every scripts\*.ps1
#  against the derived GATE SET reported Xml-Scan and Get-DocText as having
#  APPEARED on every run: they are in the directory and not in the gate set,
#  because neither can return a verdict. A movement report that cries wolf on
#  two files every time is a report nobody reads the third time.
$moved = New-Object System.Collections.Generic.List[string]
$afterStamp = Get-ScriptStamp -Skill $SkillDir
foreach ($k in @($afterStamp.Keys)) {
    $a = $afterStamp[$k]
    if (-not $script:BeforeStamp.ContainsKey($k)) { $moved.Add('APPEARED  ' + $a.Name); continue }
    $b = $script:BeforeStamp[$k]
    if ($b.Length -ne $a.Length -or $b.Mtime -ne $a.Mtime) { $moved.Add('REWRITTEN ' + $a.Name) }
}
foreach ($k in @($script:BeforeStamp.Keys)) { if (-not $afterStamp.ContainsKey($k)) { $moved.Add('VANISHED  ' + $script:BeforeStamp[$k].Name) } }

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

function Get-Mark { param($Value) if ($Value) { return 'yes' } else { return ' - ' } }

$blockingOfName = @{}
foreach ($d in $docRows) { if ($d.Name -and $d.BlocksYes) { $blockingOfName[$d.Name] = $true } }
foreach ($r in $results) {
    Add-Member -InputObject $r -NotePropertyName 'BlocksYes' -NotePropertyValue ([bool]$blockingOfName.ContainsKey($r.Gate)) -Force
}

if (-not $Quiet) {
    Write-Host ''
    Write-Host 'PER-GATE FIXTURE COVER' -ForegroundColor Cyan
    Write-Host ('  {0,-26} {1,-6} {2,-7} {3,-7} {4,-6} {5,-6} {6,-6} {7,-6} {8,-13} {9}' -f 'gate', 'self', 'verif', 'fixture', 'plant', 'fails', 'clean', 'refuse', 'claim', 'verdict') -ForegroundColor DarkGray
    foreach ($r in ($results | Sort-Object Verdict, Gate)) {
        $colour = 'Red'
        if ($r.Verdict -eq 'PROVEN') { $colour = 'Green' }
        elseif ($r.Verdict -like 'PROVEN*') { $colour = 'DarkGreen' }
        elseif ($r.Verdict -eq 'WEAK-SELFTEST') { $colour = 'Yellow' }
        elseif ($r.Verdict -eq 'JUDGEMENT-ONLY') { $colour = 'DarkGray' }
        elseif ($r.Verdict -eq 'NOT RUN') { $colour = 'DarkGray' }
        Write-Host ('  {0,-26} {1,-6} {2,-7} {3,-7} {4,-6} {5,-6} {6,-6} {7,-6} {8,-13} {9}' -f `
            $r.Gate, (Get-Mark $r.HasSelfTest), (Get-Mark $r.SelfTestVerifiesPlant), (Get-Mark $r.HasFixture), `
            (Get-Mark $r.PlantLanded), (Get-Mark $r.FailsOnPlant), (Get-Mark $r.PassesClean), (Get-Mark $r.RefusesEmpty), $r.ClaimState, $r.Verdict) -ForegroundColor $colour
    }

    $unproven = @($results | Where-Object { $_.Verdict -ne 'PROVEN' -and $_.Verdict -ne 'NOT RUN' -and $_.Verdict -ne 'JUDGEMENT-ONLY' })
    if ($unproven.Count -gt 0) {
        Write-Host ''
        Write-Host 'NOT PROVEN - each of these is a finding, with the reason it could not be proven' -ForegroundColor Yellow
        foreach ($r in ($unproven | Sort-Object @{ Expression = { -[int][bool]$_.BlocksYes } }, Gate)) {
            Write-Host ("  {0,-26} {1,-10} {2}" -f $r.Gate, $(if ($r.BlocksYes) { '[blocks]' } else { '[reported]' }), (Get-ShortLine -Value $r.Reason -Max 180)) -ForegroundColor Yellow
        }
    }

#  Not @($_.Disclaimers).Count - this gate's own hygiene rule GH04 caught
    #  that here, and it was right: @($null).Count is 1, so the wrapper
    #  would answer YES for a row that carries no Disclaimers property at
    #  all. The property is initialised on every row, so count it directly.
    $withDisclaimer = @($results | Where-Object { $null -ne $_.Disclaimers -and $_.Disclaimers.Count -gt 0 })
    if ($withDisclaimer.Count -gt 0) {
        Write-Host ''
        Write-Host 'WHAT gates.md SAYS THESE GATES DO NOT DO - read this beside any verdict above' -ForegroundColor Yellow
        foreach ($r in ($withDisclaimer | Sort-Object Gate)) {
            foreach ($d in @($r.Disclaimers)) { Write-Host ("  {0}: {1}" -f $r.Gate, $d) -ForegroundColor Yellow }
        }
    }

    $noRefuse = @($results | Where-Object { $_.ProbeState -eq 'EXITED-0' })
    if ($noRefuse.Count -gt 0) {
        Write-Host ''
        Write-Host 'EXITS 0 WITH NO ARGUMENTS AT ALL - a green result from these means nothing on its own' -ForegroundColor Red
        foreach ($r in ($noRefuse | Sort-Object Gate)) { Write-Host ("  {0}" -f $r.Gate) -ForegroundColor Red }
    }
    $notProbed = @($results | Where-Object { $_.ProbeState -eq 'NOT-PROBED' -and $_.Verdict -ne 'SPECIFIED-ABSENT' -and $_.Verdict -ne 'JUDGEMENT-ONLY' })
    if ($notProbed.Count -gt 0) {
        Write-Host ''
        Write-Host ("NOT PROBED - {0} script(s) the stage table binds to no stage; the refusal channel says nothing about them" -f $notProbed.Count) -ForegroundColor DarkGray
    }

    if ($claimIssues.Count -gt 0) {
        Write-Host ''
        Write-Host 'STAGE TABLE vs THE FILESYSTEM' -ForegroundColor Yellow
        foreach ($c in $claimIssues) { Write-Host ("  {0,-16} {1,-26} {2}" -f $c.Issue, $c.Name, $c.Detail) -ForegroundColor Yellow }
    }

    if ($moved.Count -gt 0) {
        Write-Host ''
        Write-Host '  MOVED DURING THE RUN - not covered by this report:' -ForegroundColor Yellow
        foreach ($m in $moved) { Write-Host ("    {0}" -f $m) -ForegroundColor Yellow }
    }
}

Write-StaticFindings -Rows $findings -Headers $headers -Plans $plans

$script:WallClock.Stop()

if ($ResultDir) {
    if (-not (Test-Path -LiteralPath $ResultDir)) { New-Item -ItemType Directory -Force -Path $ResultDir | Out-Null }
    $body = [ordered]@{
        gate         = $GATE
        mode         = 'full'
        checkedAt    = (Get-Date).ToString('o')
        #  THE HASH IS STAMPED INSIDE THE FILE AS WELL AS IN ITS NAME. A reader
        #  who copies the file somewhere still knows which scripts and which
        #  recipes these verdicts are about; a name alone can be renamed.
        scriptsHash  = $scriptsHash
        seconds      = [Math]::Round($script:WallClock.Elapsed.TotalSeconds, 2)
        skillDir     = "$SkillDir"
        buildDir     = "$BuildDir"
        gatesDoc     = "$GatesDoc"
        partialRun   = $partial
        partialWhy   = $partialWhy.ToArray()
        gateSetSize  = $fsSet.Count
        docClaims    = $docRows.Count
        recipeCount  = $recipes.Count
        ledger       = [ordered]@{ found = [bool]$ledger.Found; source = "$($ledger.Source)"; note = "$($ledger.Note)"; keys = @($ledger.Keys); blocking = @($ledger.Blocking) }
        probeSet     = [ordered]@{ found = [bool]$probes.Found; source = "$($probes.Source)"; note = "$($probes.Note)"
                                   scripts = @(@($probes.Set.Keys) | Sort-Object | ForEach-Object { [ordered]@{ name = $_; whatIf = [bool]$probes.Set[$_].WhatIf; why = "$($probes.Set[$_].WhatIfWhy)" } }) }
        runnerPlans  = [ordered]@{ spineStages = @($plans.SpineStages); spineNote = "$($plans.SpineNote)"
                                   gatesScripts = @($plans.GatesScripts); gatesUnresolved = @($plans.GatesUnresolved); gatesNote = "$($plans.GatesNote)" }
        headers      = @($headers)
        findings     = @($findings)
        results      = $results.ToArray()
        claimIssues  = $claimIssues.ToArray()
        movedDuringRun = $moved.ToArray()
    }
    #  gate-fixtures.<hash>.json: the runners read the NEWEST hash-stamped file
    #  and print UNPROVEN beside every member it did not prove. A file whose
    #  name carries the hash of the scripts it judged cannot be mistaken for a
    #  verdict about a different set of scripts.
    Write-FixtureText -File (Join-Path $ResultDir ('gate-fixtures.' + $scriptsHash + '.json')) -Body ($body | ConvertTo-Json -Depth 8)
}

# ---------------------------------------------------------------------------
# The exit, SPLIT BY Blocks. Only PROVEN counts toward exit 0.
# ---------------------------------------------------------------------------

$judged = @($results | Where-Object { $_.Verdict -ne 'NOT RUN' -and $_.Verdict -ne 'JUDGEMENT-ONLY' })
$proven = @($judged | Where-Object { $_.Verdict -eq 'PROVEN' })
$provenNoClean = @($judged | Where-Object { $_.Verdict -eq 'PROVEN-NOCLEAN' })
$provenSelfTest = @($judged | Where-Object { $_.Verdict -eq 'PROVEN-SELFTEST' })
$judgementOnly = @($results | Where-Object { $_.Verdict -eq 'JUDGEMENT-ONLY' })

$blockingRows = @($judged | Where-Object { $_.BlocksYes })
$blockingUnproven = @($blockingRows | Where-Object { $_.Verdict -ne 'PROVEN' })
$reportedUnproven = @($judged | Where-Object { -not $_.BlocksYes -and $_.Verdict -ne 'PROVEN' })

Write-Host ''
Write-Host ("TALLY  PROVEN {0} | PROVEN-NOCLEAN {1} | PROVEN-SELFTEST {2} | judgement-only rows {3} | wall clock {4}s" -f `
    $proven.Count, $provenNoClean.Count, $provenSelfTest.Count, $judgementOnly.Count, [Math]::Round($script:WallClock.Elapsed.TotalSeconds, 1)) -ForegroundColor Cyan
Write-Host '  PROVEN-NOCLEAN and PROVEN-SELFTEST are counted here and NOT toward the pass. Only a gate that failed a verified plant, named it, and passed the same build clean is proven.' -ForegroundColor DarkGray

if ($ListOnly) {
    Write-Host ("LIST ONLY - {0} gates enumerated, nothing was run. This cannot stand for the fixtures gate." -f $results.Count) -ForegroundColor Yellow
    exit 3
}
if ($blockingFindings.Count -gt 0) {
    Write-Host ("FIXTURES FAIL - {0} static finding(s) on blocking gates: {1}." -f `
        $blockingFindings.Count, ((@($blockingFindings | ForEach-Object { ($_.Kind + ' ' + $_.Gate) }) | Select-Object -Unique) -join '; ')) -ForegroundColor Red
    exit 1
}
if ($partial) {
    Write-Host ("PARTIAL RUN - {0} of {1} blocking gates PROVEN; {2}. A partial run cannot stand for the fixtures gate." -f `
        ($blockingRows.Count - $blockingUnproven.Count), $blockingRows.Count, ($partialWhy -join '; ')) -ForegroundColor Yellow
    if ($blockingUnproven.Count -gt 0) { exit 1 }
    exit 3
}
if ($blockingUnproven.Count -gt 0) {
    Write-Host ("FIXTURES FAIL - {0} of {1} BLOCKING gates proven. {2} cannot be shown to fail on the defect they claim to catch, and a clean result from any of them is not evidence yet: {3}." -f `
        ($blockingRows.Count - $blockingUnproven.Count), $blockingRows.Count, $blockingUnproven.Count, ((@($blockingUnproven | ForEach-Object { $_.Gate }) | Select-Object -Unique) -join ', ')) -ForegroundColor Red
    exit 1
}
if ($reportedUnproven.Count -gt 0) {
    Write-Host ("FIXTURES PASS - all {0} BLOCKING gates fail on a verified plant of the defect they claim to catch. {1} non-blocking row(s) are unproven and reported above, not gated." -f `
        $blockingRows.Count, $reportedUnproven.Count) -ForegroundColor Green
    exit 0
}
Write-Host ("FIXTURES PASS - all {0} BLOCKING gates fail on a verified plant of the defect they claim to catch." -f $blockingRows.Count) -ForegroundColor Green
exit 0
