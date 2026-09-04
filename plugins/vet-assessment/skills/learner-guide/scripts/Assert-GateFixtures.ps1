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

    PS 5.1. ASCII only in this file.

    Exit 0 every blocking gate proven, 1 one or more UNPROVEN, 2 usage or
    refusal, 3 PARTIAL RUN, 4 the self-test failed.
#>

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

    #  Where gate-fixtures.json is written.
    [string] $ResultDir,

    #  Prove only these gates. A PARTIAL RUN: banner, exit 3, never 0.
    [string[]] $Only,

    #  Per-invocation ceiling. A gate that hangs is a FAIL naming the timeout,
    #  never a skip.
    [int] $TimeoutMinutes = 6,

    #  Enumerate the gate set and each gate's fixture cover, run nothing.
    [switch] $ListOnly,

    [switch] $SelfTest,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
$GATE = 'Assert-GateFixtures'

#  NO NESTED FULL RUN. This harness runs every gate in the skill, and it is
#  itself a gate in the skill, so a full run inside a full run enumerates the
#  set again and starts another one - once per level, forever. Measured: the
#  first real pass had spawned twenty-odd live processes before anyone looked.
#  A nested -SelfTest or -ListOnly is harmless and still allowed; a nested full
#  run REFUSES and says why, rather than being silently skipped.
$script:NestKey = 'LG_ASSERT_GATEFIXTURES_ACTIVE'
if (-not $SelfTest -and -not $ListOnly) {
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

function Get-ScriptFacts {
    <#  What a gate declares about itself: its parameters, whether it has a
        -SelfTest, whether that self-test verifies its own plant, what exit
        codes it can return, and the claim in its header.  #>
    param([Parameter(Mandatory)][string] $File)

    $facts = [pscustomobject]@{
        Name          = [System.IO.Path]::GetFileNameWithoutExtension($File)
        File          = $File
        Parses        = $false
        ParamNames    = @()
        Mandatory     = @()
        HasSelfTest   = $false
        SelfTestVerifiesPlant = $false
        ExitCodes     = @()
        CanFail       = $false
        Claim         = ''
        Length        = 0
        Mtime         = [datetime]::MinValue
    }
    if (-not (Test-Path -LiteralPath $File)) { return $facts }
    $fi = Get-Item -LiteralPath $File
    $facts.Length = $fi.Length
    $facts.Mtime = $fi.LastWriteTimeUtc

    $tokens = $null; $errors = $null; $ast = $null
    try { $ast = [System.Management.Automation.Language.Parser]::ParseFile($File, [ref]$tokens, [ref]$errors) }
    catch { return $facts }
    if ($null -ne $errors -and $errors.Count -gt 0) { return $facts }
    $facts.Parses = $true

    $pnames = New-Object System.Collections.Generic.List[string]
    $mand = New-Object System.Collections.Generic.List[string]
    if ($null -ne $ast.ParamBlock) {
        foreach ($p in $ast.ParamBlock.Parameters) {
            $pn = "$($p.Name.VariablePath.UserPath)"
            $pnames.Add($pn)
            if ($pn -ieq 'SelfTest') { $facts.HasSelfTest = $true }
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
    $src = Read-FixtureText -File $File
    if (-not $facts.CanFail -and [regex]::IsMatch($src, '(?m)^\s*throw\b')) { $facts.CanFail = $true }

    #  Does the self-test READ ITS PLANT BACK? Structure, from the syntax tree.
    $pv = Get-SelfTestPlantVerification -Ast $ast -HasSelfTest ([bool]$facts.HasSelfTest)
    $facts.SelfTestVerifiesPlant = ($pv.State -eq 'VERIFIED')
    Add-Member -InputObject $facts -NotePropertyName 'PlantVerifyState' -NotePropertyValue $pv.State -Force
    Add-Member -InputObject $facts -NotePropertyName 'PlantVerifyEvidence' -NotePropertyValue $pv.Evidence -Force
    Add-Member -InputObject $facts -NotePropertyName 'PlantVerifyLookedFor' -NotePropertyValue $pv.LookedFor -Force

    #  The claim: the first prose of the header block comment.
    $m = [regex]::Match($src, '(?s)^\s*<#(.*?)#>')
    if ($m.Success) {
        $head = $m.Groups[1].Value
        $head = [regex]::Replace($head, '\s+', ' ').Trim()
        $facts.Claim = Get-ShortLine -Value $head -Max 220
    }
    return $facts
}

function Get-FilesystemGateSet {
    <#  Every script in the skill that can return a verdict.

        Enumerated from disk. Anything that can exit non-zero, or is named the
        way this skill names its gates, is in the set - so a gate a sibling
        build adds while this runs is still covered by the next run rather than
        being invisible forever.  #>
    param([Parameter(Mandatory)][string] $Skill)

    $out = New-Object System.Collections.Generic.List[object]
    $dir = Join-Path $Skill 'scripts'
    if (-not (Test-Path -LiteralPath $dir)) { return $out.ToArray() }
    $files = @()
    try { $files = @(Get-ChildItem -LiteralPath $dir -Filter '*.ps1' -File -ErrorAction Stop | Sort-Object Name) }
    catch { $files = @() }
    foreach ($f in $files) {
        $facts = Get-ScriptFacts -File $f.FullName
        $named = [regex]::IsMatch($f.BaseName, '^(Assert|Check|Test)-')
        if (-not $facts.CanFail -and -not $named) { continue }
        Add-Member -InputObject $facts -NotePropertyName 'Origin' -NotePropertyValue 'filesystem' -Force
        $out.Add($facts)
    }
    return $out.ToArray()
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
        $blocks = $cells[3].Trim()
        $section = $cells[4].Trim()

        $marker = 'implemented'
        if ([regex]::IsMatch($scriptCell, '(?i)NOT\s+YET\s+IMPLEMENTED')) { $marker = 'not-yet-implemented' }
        elseif ([regex]::IsMatch($scriptCell, '(?i)BEING\s+IMPLEMENTED')) { $marker = 'being-implemented' }

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
        if ($ordered.Count -eq 0) { continue }
        if ($null -eq $resolved) {
            $resolvedName = $ordered[0]
            $aliases.Clear()
            for ($ai = 1; $ai -lt $ordered.Count; $ai++) { $aliases.Add($ordered[$ai]) }
        }
        $rows.Add([pscustomobject]@{
            Stage      = $stage
            Gate       = $gateName
            Name       = $resolvedName
            Marker     = $marker
            Blocks     = $blocks
            Section    = $section
            File       = $(if ($null -ne $resolved) { $resolved.File } else { '' })
            OnDisk     = ($null -ne $resolved -and $resolved.Kind -eq 'script')
            AsFunction = $(if ($null -ne $resolved -and $resolved.Kind -eq 'function') { $resolved.File } else { '' })
            Aliases    = $aliases.ToArray()
        })
    }
    return $rows.ToArray()
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
                    if ($v -and "$v".Trim().Length -ge 2) { $lit = "$v".Trim(); $figName = "$($fig.name)"; break }
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
            $src = Read-FixtureText -File $gate
            $m = [regex]::Match($src, '(?m)^\s*\$script:LedgerRequired\s*=\s*@\(([^)]*)\)')
            if (-not $m.Success) { return }
            $stages = New-Object System.Collections.Generic.List[string]
            foreach ($q in [regex]::Matches($m.Groups[1].Value, "'([^']+)'")) { $stages.Add($q.Groups[1].Value) }
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
            $body = Read-FixtureText -File $p.FullName
            $marker = 'plantedmissingrequiredfield'
            $new = [regex]::Replace($body, '"brandingFile"', ('"' + $marker + '"'), 1)
            if ($new -eq $body) { return $null }
            Write-FixtureText -File $p.FullName -Body $new
            return [pscustomobject]@{ Token = $marker; Channel = $p.FullName; Describe = 'a required property renamed in a copy of the RTO profile pack'; Extra = $rtoId; SkillCopy = $dst }
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
        [AllowEmptyString()][string] $SectionText = ''
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
        Verdict     = 'UNPROVEN'
        Reason      = ''
        Seconds     = 0.0
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    # ---- channel: REFUSAL. A gate that exits 0 on nothing proves nothing.
    #  A refusal happens at parameter validation, in the first second. A gate
    #  that is still working after this has not refused - it has started, which
    #  is the answer this probe was asking for.
    $bare = Invoke-GateProcess -File $Facts.File -Arguments @() -TimeoutSec ([Math]::Min($TimeoutSec, 45))
    $res.RefusesEmpty = ($bare.Exit -ne 0)

    # ---- channel: SELFTEST
    if ($Facts.HasSelfTest) {
        $stArgs = New-Object System.Collections.Generic.List[string]
        $stArgs.Add('-SelfTest')
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
            if ($null -ne $Recipe.PSObject.Properties['Prepare'] -and $null -ne $Recipe.Prepare) {
                & $Recipe.Prepare $fx
            }

            #  CLEAN FIRST, on the untouched copy. A gate that fails on a clean
            #  build cannot have its failure on a planted one believed.
            $cleanArgs = @()
            if ($null -ne $Recipe.PSObject.Properties['CleanArgs'] -and $null -ne $Recipe.CleanArgs) { $cleanArgs = & $Recipe.CleanArgs $fx }
            elseif ($null -eq $Recipe.PSObject.Properties['CleanArgsDynamic']) { $cleanArgs = & $Recipe.Args $fx }

            $ranClean = $false
            $cleanRc = -9999
            if ($null -ne $cleanArgs -and @($cleanArgs).Count -gt 0) {
                $cl = Invoke-GateProcess -File $Facts.File -Arguments @($cleanArgs) -TimeoutSec $TimeoutSec
                $res.PassesClean = ((-not $cl.TimedOut) -and ($cl.Exit -eq 0))
                $cleanRc = $cl.Exit
                $ranClean = $true
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
                    }

                    $pl = Invoke-GateProcess -File $Facts.File -Arguments @($pArgs) -TimeoutSec $TimeoutSec
                    #  The gate must NAME the plant. Where a recipe declares no
                    #  token of its own, the planted value itself is the token -
                    #  never "assume named", which is what silently switched the
                    #  discrimination guard off for the gates that crash before
                    #  they run.
                    $needle = ''
                    if ($Recipe.NameInOutput) { $needle = "$($Recipe.NameInOutput)" }
                    if (-not $needle -and $plant.Token) { $needle = "$($plant.Token)" }
                    $named = $false
                    if ($needle) { $named = Test-OutputNames -Text $pl.Text -Token $needle }

                    #  DID IT DISCRIMINATE? A gate that returns the same code on
                    #  the clean build and the planted one told us nothing about
                    #  the plant - it very likely never ran. One gate here dies
                    #  inside its own parameter block under -File, because it
                    #  resolves its skill directory from $PSScriptRoot in a
                    #  parameter default and $PSScriptRoot is empty there; it
                    #  exits 1 on clean input and 1 on planted input, and
                    #  reading only "non-zero on the plant" would have scored
                    #  that as the gate catching the defect.
                    $discriminated = ($ranClean -and ($cleanRc -ne $pl.Exit)) -or $named
                    $res.FailsOnPlant = ((-not $pl.TimedOut) -and ($pl.Exit -ne 0) -and $named -and $discriminated)

                    if ($pl.TimedOut) { $res.Reason = 'the gate timed out on the planted fixture' }
                    elseif ($pl.Exit -eq 0) { $res.Reason = 'the gate PASSED a verified plant of the defect it claims to catch' }
                    elseif (-not $discriminated) {
                        $res.Reason = ("the gate exited {0} on the clean build and {1} on the planted one and never named the plant, so it did not discriminate it - check whether it ran at all" -f $cleanRc, $pl.Exit)
                    }
                    elseif (-not $named) { $res.Reason = 'the gate failed on the plant but its output never names it, so the failure may be about something else' }
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
    if ($res.PlantLanded -and $res.FailsOnPlant -and $res.PassesClean) {
        $res.Verdict = 'PROVEN'
        $res.Reason = 'failed on a verified plant and passed the same build clean'
    }
    elseif ($res.PlantLanded -and $res.FailsOnPlant) {
        $res.Verdict = 'PROVEN-NOCLEAN'
        $res.Reason = 'failed on a verified plant, but did not pass the clean build, so it may be failing for another reason'
    }
    elseif ($res.SelfTestOk -and $Facts.PlantVerifyState -eq 'VERIFIED') {
        $res.Verdict = 'PROVEN-SELFTEST'
        $res.Reason = ('its own -SelfTest plants a defect, reads the plant back and branches to failure on it, then requires the gate to catch it. ' + $Facts.PlantVerifyEvidence)
    }
    elseif ($res.SelfTestOk -and $Facts.PlantVerifyState -eq 'INDETERMINATE') {
        #  NEVER WEAK BY DEFAULT. A false WEAK sends someone to add a read-back
        #  that already exists - the mirror of a false PROVEN, and just as
        #  expensive. Where the syntax tree cannot settle it, say so and say
        #  what was looked for.
        $res.Verdict = 'SELFTEST-INDETERMINATE'
        $res.Reason = ('its -SelfTest passes; whether it reads its own plant back could not be settled from the syntax tree. ' + $Facts.PlantVerifyEvidence + ' LOOKED FOR: ' + $Facts.PlantVerifyLookedFor)
    }
    elseif ($res.SelfTestOk) {
        $res.Verdict = 'WEAK-SELFTEST'
        $res.Reason = ('its -SelfTest passes but nothing in it reads the plant back before the gate is believed, which is the exact way a gate was recorded as proven while shipping the defect. ' + $Facts.PlantVerifyEvidence)
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

        $honest = Get-ScriptFacts -File (Join-Path $fxScripts 'Check-Honest.ps1')
        $cannot = Get-ScriptFacts -File (Join-Path $fxScripts 'Check-CannotFail.ps1')
        $blind = Get-ScriptFacts -File (Join-Path $fxScripts 'Check-BlindSelfTest.ps1')

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

        $r3 = Test-OneGate -Facts $cannot -DocRow $null -Recipe $landingRecipe -Skill $Skill -Build $fxBuild -Scratch $scratch -TimeoutSec 60
        if ($r3.Verdict -eq 'UNPROVEN') { TOk 'a gate that exits 0 on everything is UNPROVEN' } else { TBad ("a gate that cannot fail was reported {0}" -f $r3.Verdict) }
        if (-not $r3.RefusesEmpty) { TOk 'a gate that exits 0 with no arguments at all is recorded as not refusing' } else { TBad 'the refusal probe misread the always-pass gate' }

        $r4 = Test-OneGate -Facts $blind -DocRow $null -Recipe $null -Skill $Skill -Build $fxBuild -Scratch $scratch -TimeoutSec 60
        if ($r4.Verdict -eq 'WEAK-SELFTEST') { TOk 'a passing self-test that never verifies its plant is WEAK-SELFTEST, not PROVEN' }
        else { TBad ("expected WEAK-SELFTEST, got {0}" -f $r4.Verdict) }

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
        Write-Host ("SELF-TEST PASS - {0} checks, including the plant that did not land." -f $script:stPass) -ForegroundColor Green
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

$partial = $false
$partialWhy = New-Object System.Collections.Generic.List[string]
if ($null -ne $Only -and $Only.Count -gt 0) { $partial = $true; $partialWhy.Add('only ' + ($Only -join ', ')) }
if (-not $BuildDir) { $partial = $true; $partialWhy.Add('no -BuildDir, so no external plant could be cut') }
elseif (-not (Test-Path -LiteralPath $BuildDir)) {
    Write-Host ("{0}: -BuildDir '{1}' does not exist." -f $GATE, $BuildDir) -ForegroundColor Red
    exit 2
}

$Only = Expand-CommaList -Value $Only
$fsSet = Get-FilesystemGateSet -Skill $SkillDir
$docRows = Get-GatesDocClaim -Doc $GatesDoc -Skill $SkillDir
$script:GatesDocText = ''
try { $script:GatesDocText = Read-FixtureText -File $GatesDoc } catch { $script:GatesDocText = '' }
$recipes = Get-FixtureRecipe -Skill $SkillDir

if (-not $Quiet) {
    Write-Host ''
    Write-Host ('GATE FIXTURES - {0}' -f $GATE) -ForegroundColor Cyan
    Write-Host ('  check-set: {0} gate scripts, derived from {1}' -f $fsSet.Count, (Join-Path $SkillDir 'scripts')) -ForegroundColor DarkGray
    Write-Host ('  plus {0} script names claimed by the stage table in {1}' -f $docRows.Count, [System.IO.Path]::GetFileName($GatesDoc)) -ForegroundColor DarkGray
    Write-Host ('  fixture recipes available: {0}' -f $recipes.Count) -ForegroundColor DarkGray
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
                Verdict = 'NOT RUN'; Reason = '-ListOnly'; Seconds = 0.0
            })
            continue
        }

        if (-not $Quiet) { Write-Host ("  proving {0} ..." -f $g.Name) -ForegroundColor DarkGray }
        $sectionText = Get-GateSectionText -DocText $script:GatesDocText -Name $g.Name
        $r = Test-OneGate -Facts $g -DocRow $docRow -Recipe $recipe -Skill $SkillDir -Build $baseline -Scratch $scratch -TimeoutSec $timeoutSec -SectionText $sectionText
        $results.Add($r)
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
    $results.Add([pscustomobject]@{
        Gate = $row.Name; Stage = $row.Stage; Blocks = $row.Blocks; Section = $row.Section
        Claim = ''; HasSelfTest = $false; SelfTestVerifiesPlant = $false; SelfTestRc = ''; SelfTestOk = $false
        PlantVerifyState = 'N/A'; PlantVerifyEvidence = ''
        ClaimState = 'n/a'; ClaimEvidence = ''; Disclaimers = @(); SelfTestVerdict = 'NOT-RUN'
        HasFixture = $false; PlantKind = ''; PlantLanded = $false; FailsOnPlant = $false
        PassesClean = $false; RefusesEmpty = $false
        Verdict = 'SPECIFIED-ABSENT'
        Reason = ('the stage table names this gate ({0}) and no script or function of that name is on disk, so nothing performs it' -f $row.Marker)
        Seconds = 0.0
    })
}

#  Anything that moved while this ran is named rather than covered silently.
$moved = New-Object System.Collections.Generic.List[string]
$after = Get-FilesystemGateSet -Skill $SkillDir
$beforeMap = @{}
foreach ($g in $fsSet) { $beforeMap[$g.File] = $g }
foreach ($a in $after) {
    if (-not $beforeMap.ContainsKey($a.File)) { $moved.Add('APPEARED  ' + $a.Name); continue }
    $b = $beforeMap[$a.File]
    if ($b.Length -ne $a.Length -or $b.Mtime -ne $a.Mtime) { $moved.Add('REWRITTEN ' + $a.Name) }
}
$afterMap = @{}
foreach ($a in $after) { $afterMap[$a.File] = $a }
foreach ($g in $fsSet) { if (-not $afterMap.ContainsKey($g.File)) { $moved.Add('VANISHED  ' + $g.Name) } }

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

function Get-Mark { param($Value) if ($Value) { return 'yes' } else { return ' - ' } }

if (-not $Quiet) {
    Write-Host ''
    Write-Host 'PER-GATE FIXTURE COVER' -ForegroundColor Cyan
    Write-Host ('  {0,-26} {1,-6} {2,-7} {3,-7} {4,-6} {5,-6} {6,-6} {7,-6} {8,-13} {9}' -f 'gate', 'self', 'verif', 'fixture', 'plant', 'fails', 'clean', 'refuse', 'claim', 'verdict') -ForegroundColor DarkGray
    foreach ($r in ($results | Sort-Object Verdict, Gate)) {
        $colour = 'Red'
        if ($r.Verdict -eq 'PROVEN') { $colour = 'Green' }
        elseif ($r.Verdict -like 'PROVEN*') { $colour = 'Green' }
        elseif ($r.Verdict -eq 'WEAK-SELFTEST') { $colour = 'Yellow' }
        elseif ($r.Verdict -eq 'NOT RUN') { $colour = 'DarkGray' }
        Write-Host ('  {0,-26} {1,-6} {2,-7} {3,-7} {4,-6} {5,-6} {6,-6} {7,-6} {8,-13} {9}' -f `
            $r.Gate, (Get-Mark $r.HasSelfTest), (Get-Mark $r.SelfTestVerifiesPlant), (Get-Mark $r.HasFixture), `
            (Get-Mark $r.PlantLanded), (Get-Mark $r.FailsOnPlant), (Get-Mark $r.PassesClean), (Get-Mark $r.RefusesEmpty), $r.ClaimState, $r.Verdict) -ForegroundColor $colour
    }

    $unproven = @($results | Where-Object { $_.Verdict -notlike 'PROVEN*' -and $_.Verdict -ne 'NOT RUN' })
    if ($unproven.Count -gt 0) {
        Write-Host ''
        Write-Host 'UNPROVEN - each of these is a finding, with the reason it could not be proven' -ForegroundColor Yellow
        foreach ($r in ($unproven | Sort-Object Gate)) {
            Write-Host ("  {0,-26} {1}" -f $r.Gate, (Get-ShortLine -Value $r.Reason -Max 200)) -ForegroundColor Yellow
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

    $noRefuse = @($results | Where-Object { -not $_.RefusesEmpty -and $_.Verdict -ne 'NOT RUN' -and $_.Verdict -ne 'SPECIFIED-ABSENT' })
    if ($noRefuse.Count -gt 0) {
        Write-Host ''
        Write-Host 'EXITS 0 WITH NO ARGUMENTS AT ALL - a green result from these means nothing on its own' -ForegroundColor Red
        foreach ($r in ($noRefuse | Sort-Object Gate)) { Write-Host ("  {0}" -f $r.Gate) -ForegroundColor Red }
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

if ($ResultDir) {
    if (-not (Test-Path -LiteralPath $ResultDir)) { New-Item -ItemType Directory -Force -Path $ResultDir | Out-Null }
    $body = [ordered]@{
        gate         = $GATE
        checkedAt    = (Get-Date).ToString('o')
        skillDir     = "$SkillDir"
        buildDir     = "$BuildDir"
        gatesDoc     = "$GatesDoc"
        partialRun   = $partial
        partialWhy   = $partialWhy.ToArray()
        gateSetSize  = $fsSet.Count
        docClaims    = $docRows.Count
        recipeCount  = $recipes.Count
        results      = $results.ToArray()
        claimIssues  = $claimIssues.ToArray()
        movedDuringRun = $moved.ToArray()
    }
    Write-FixtureText -File (Join-Path $ResultDir 'gate-fixtures.json') -Body ($body | ConvertTo-Json -Depth 6)
}

$proven = @($results | Where-Object { $_.Verdict -like 'PROVEN*' })
$unprovenAll = @($results | Where-Object { $_.Verdict -notlike 'PROVEN*' -and $_.Verdict -ne 'NOT RUN' })

Write-Host ''
if ($ListOnly) {
    Write-Host ("LIST ONLY - {0} gates enumerated, nothing was run. This cannot stand for the fixtures gate." -f $results.Count) -ForegroundColor Yellow
    exit 3
}
if ($partial) {
    Write-Host ("PARTIAL RUN - {0} proven, {1} unproven; {2}. A partial run cannot stand for the fixtures gate." -f $proven.Count, $unprovenAll.Count, ($partialWhy -join '; ')) -ForegroundColor Yellow
    if ($unprovenAll.Count -gt 0) { exit 1 }
    exit 3
}
if ($unprovenAll.Count -gt 0) {
    Write-Host ("FIXTURES FAIL - {0} of {1} gates proven. {2} gates cannot be shown to fail on the defect they claim to catch, and a clean result from any of them is not evidence yet." -f `
        $proven.Count, ($proven.Count + $unprovenAll.Count), $unprovenAll.Count) -ForegroundColor Red
    exit 1
}
Write-Host ("FIXTURES PASS - all {0} gates fail on a verified plant of the defect they claim to catch." -f $proven.Count) -ForegroundColor Green
exit 0
