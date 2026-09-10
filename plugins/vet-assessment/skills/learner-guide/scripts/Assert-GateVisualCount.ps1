<#
    Assert-GateVisualCount.ps1

    The planned-visual COUNT gate. Every sub-section the contract declares
    carries exactly the number of visuals the contract declares for it, the
    cover carries exactly one, no visual sits on a file that is not a
    sub-section, and the hand-typed route totals in the contract's visual plan
    agree with what the plan's own slot table derives.

    WHY THIS EXISTS (8 September 2026). The planned count was typed in three
    places (visuals.perSubSection, visualPlan.perSubSection, the prose formula
    "(15 sub-sections x 2) + 1 cover") and checked by a build-local script the
    skill forbids. The cover's visual lived under a singular 'visual' node that
    no gate read. Nothing on the skill side could say whether 61 slots were
    the right number, so the figure sheet and the artwork order were cut from
    a count nobody had derived.

    THE FORMULA IS NEVER TYPED HERE. Expected = contract.visuals.perSubSection
    multiplied by the union of contract.topics[].pcs; the route totals are
    derived from contract.visualPlan.slots. A missing key is a REFUSAL (exit 2)
    naming the key; a count that disagrees is a FINDING (exit 1) naming the
    sub-section, the expected number and the found number.

    ARMS (all blocking when the contract declares the input):
      declared-plan   perSubSection and the PC union resolved; visuals.perSubSection
                      and visualPlan.perSubSection agree when both are declared
      per-subsection  each declared PC: found == expected
      unattributed    no visual on a file that maps to no declared PC
      cover           cover.json carries exactly one visual (the singular node)
      route-plan      declared routeACount / routeBCount == derived from the slot
                      table (registered only when visualPlan.slots is declared)

    EXIT: 0 pass, 1 finding, 2 refused (missing -BuildDir, contract, key, or
    an empty check-set), 4 self-test failed.

    Runner: Run-SpineGates discovers this gate from the header line below.
#>
# GATE: stages=3c; requires=BuildDir

[CmdletBinding()]
param(
    [string] $BuildDir,
    [string] $SpineDir,
    [string] $ReportPath,
    [switch] $Quiet,
    [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

$GATE = 'Assert-GateVisualCount'
$script:VcLastRc = -1

function Get-VcSubSectionKey {
    <#  The PC a spine file plans for: the file name's t<n>_<pc>.json shape first,
        then the file's own pc / ref field. Empty when neither resolves.  #>
    param([Parameter(Mandatory)][string] $FileName, $Json)
    $m = [regex]::Match($FileName, '^t\d+_(\d+(?:\.\d+)+)\.json$')
    if ($m.Success) { return $m.Groups[1].Value }
    if ($null -ne $Json) {
        $v = [string](Get-GateProp -Object $Json -Names @('pc', 'ref') -Default '')
        $v = $v.Trim() -replace '^(?i)PC\s+', ''
        if ($v -match '^\d+(?:\.\d+)+$') { return $v }
    }
    return ''
}

function Invoke-VcGate {
    param([string] $BuildDir, [string] $SpineDir, [string] $ReportPath, [bool] $Quiet)

    $findings = New-Object System.Collections.Generic.List[string]
    $say = { param([string] $t, [string] $c = 'Gray') if (-not $Quiet) { Write-Host $t -ForegroundColor $c } }

    if (-not $BuildDir) { throw (New-Object System.InvalidOperationException ('CHECK-SET EMPTY: -BuildDir yielded nothing. Name the build directory holding contract.json and the spine.')) }
    if (-not (Test-Path -LiteralPath $BuildDir)) { throw (New-Object System.InvalidOperationException ("CHECK-SET EMPTY: -BuildDir {0} does not exist." -f $BuildDir)) }
    $contract = Get-GateContract -BuildDir $BuildDir
    if ($null -eq $contract) { throw (New-Object System.InvalidOperationException ("CHECK-SET EMPTY: {0}\contract.json yielded nothing - the planned count is declared there and nowhere else." -f $BuildDir)) }

    Reset-GateArmRoster
    Register-GateArm -Name 'declared-plan' -Blocking
    Register-GateArm -Name 'per-subsection' -Blocking
    Register-GateArm -Name 'unattributed' -Blocking
    Register-GateArm -Name 'cover' -Blocking
    $visualPlan = Get-GateProp -Object $contract -Names @('visualPlan') -Default $null
    $slotTable = if ($null -ne $visualPlan) { Get-GateProp -Object $visualPlan -Names @('slots') -Default $null } else { $null }
    #  Get-GateCount, not @(...).Count: @($null).Count is 1 in PS 5.1, so an
    #  EMPTY visualPlan.slots object - which yields no property names at all -
    #  counted as one and armed the blocking route-plan arm over a route plan
    #  that declares nothing.
    $hasRoutePlan = ($null -ne $slotTable) -and ((Get-GateCount -Value $slotTable.PSObject.Properties.Name) -gt 0)
    if ($hasRoutePlan) { Register-GateArm -Name 'route-plan' -Blocking }

    # ---- arm 1: the declared plan. Nothing here is defaulted.
    $vBlock = Get-GateProp -Object $contract -Names @('visuals') -Default $null
    if ($null -eq $vBlock) { throw (New-Object System.InvalidOperationException ('CHECK-SET EMPTY: contract.visuals yielded nothing - declare visuals.perSubSection in contract.json.')) }
    $perRaw = Get-GateProp -Object $vBlock -Names @('perSubSection') -Default $null
    $per = 0
    if ($null -eq $perRaw -or -not [int]::TryParse(("" + $perRaw).Trim(), [ref]$per) -or $per -le 0) {
        throw (New-Object System.InvalidOperationException ("CHECK-SET EMPTY: contract.visuals.perSubSection yielded nothing usable (value: '{0}') - declare a positive whole number." -f $perRaw))
    }
    $topics = @(Get-GateProp -Object $contract -Names @('topics') -Default @())
    $pcs = New-Object System.Collections.Generic.List[string]
    foreach ($t in $topics) {
        if ($null -eq $t) { continue }
        foreach ($p in @(Get-GateProp -Object $t -Names @('pcs', 'subSections') -Default @())) {
            $s = ("" + $p).Trim()
            if ($s -and -not $pcs.Contains($s)) { $pcs.Add($s) }
        }
    }
    Write-GateCheckSet -What 'declared PC sub-section(s)' -Count $pcs.Count -DerivedFrom 'the union of contract.topics[].pcs' -Blocking -Input 'contract.topics[].pcs'
    $expectedTotal = $per * $pcs.Count
    & $say ("  plan: {0} visual(s) per sub-section x {1} sub-section(s) = {2} planned on the sub-sections" -f $per, $pcs.Count, $expectedTotal) 'DarkGray'
    $planFindings = 0
    if ($null -ne $visualPlan) {
        $per2Raw = Get-GateProp -Object $visualPlan -Names @('perSubSection') -Default $null
        if ($null -ne $per2Raw) {
            $per2 = 0
            if (-not [int]::TryParse(("" + $per2Raw).Trim(), [ref]$per2) -or $per2 -ne $per) {
                $findings.Add(("contract.visuals.perSubSection = {0} but contract.visualPlan.perSubSection = '{1}': the two declarations of the planned count disagree. Keep one number in step, or delete the copy." -f $per, $per2Raw))
                $planFindings++
            }
        }
    }
    Complete-GateArm -Name 'declared-plan' -State ran -Size (1 + $pcs.Count) -Findings $planFindings

    # ---- arm 2 and 3: what the spine plans, file by file
    $spineArgs = @{ BuildDir = $BuildDir }
    if ($SpineDir) { $spineArgs['SpineDir'] = $SpineDir }
    $files = @(Get-GateSpineFiles @spineArgs -IncludeFrontMatter -Exclude @())
    $byPc = @{}
    $fileOfPc = @{}
    $unattributed = New-Object System.Collections.Generic.List[string]
    $coverCount = -1
    $coverSeen = $false
    $slotsByFile = @{}
    foreach ($f in $files) {
        $j = Get-GateJson -Path $f.FullName
        $count = 0
        $props = if ($null -ne $j) { @($j.PSObject.Properties.Name) } else { @() }
        if ($props -contains 'visuals') { $count += @($j.visuals | Where-Object { $null -ne $_ }).Count }
        if ($props -contains 'visual')  { $count += @($j.visual  | Where-Object { $null -ne $_ }).Count }
        if ($f.Name -ieq 'cover.json') { $coverSeen = $true; $coverCount = $count; continue }
        $key = Get-VcSubSectionKey -FileName $f.Name -Json $j
        if ($key -and $pcs.Contains($key)) {
            $byPc[$key] = [int]$byPc[$key] + $count
            $fileOfPc[$key] = $f.Name
            continue
        }
        if ($count -gt 0) { $unattributed.Add(("{0} ({1} visual(s), maps to {2})" -f $f.Name, $count, $(if ($key) { "undeclared sub-section $key" } else { 'no sub-section' }))) }
    }
    Write-GateCheckSet -What 'spine file(s) read for planned visuals' -Count $files.Count -DerivedFrom 'Get-GateSpineFiles -IncludeFrontMatter -Exclude @()' -Blocking -Input 'the spine directory'

    $rows = New-Object System.Collections.Generic.List[object]
    $subFindings = 0
    $foundTotal = 0
    foreach ($pc in $pcs) {
        $found = [int]$byPc[$pc]
        $foundTotal += $found
        $file = if ($fileOfPc.ContainsKey($pc)) { $fileOfPc[$pc] } else { '(no spine file)' }
        $ok = ($found -eq $per)
        $rows.Add([pscustomobject]@{ pc = $pc; file = $file; expected = $per; found = $found; ok = $ok })
        if (-not $ok) {
            $subFindings++
            $findings.Add(("sub-section {0} ({1}): {2} visual(s) planned on the spine, contract expects {3}" -f $pc, $file, $found, $per))
        }
    }
    & $say ("  spine plans {0} visual(s) on the declared sub-sections; contract expects {1}" -f $foundTotal, $expectedTotal) $(if ($subFindings -eq 0) { 'Green' } else { 'Red' })
    Complete-GateArm -Name 'per-subsection' -State ran -Size $pcs.Count -Findings $subFindings

    foreach ($u in $unattributed) { $findings.Add(("visual(s) planned on a file that is no declared sub-section: {0}" -f $u)) }
    Complete-GateArm -Name 'unattributed' -State ran -Size $files.Count -Findings $unattributed.Count

    # ---- arm 4: the cover. The guide's first image lives under a singular node.
    if (-not $coverSeen) { throw (New-Object System.InvalidOperationException ('CHECK-SET EMPTY: cover.json yielded nothing - the spine has no cover file, so the cover visual cannot be counted. Invoke-Render reads cover.json; author it.')) }
    $coverFindings = 0
    if ($coverCount -ne 1) {
        $coverFindings = 1
        $findings.Add(("cover.json plans {0} visual(s); exactly 1 is expected (the singular 'visual' node)" -f $coverCount))
    }
    Complete-GateArm -Name 'cover' -State ran -Size 1 -Findings $coverFindings

    # ---- arm 5: the route totals the plan types, against what its slot table derives
    $routes = $null
    if ($hasRoutePlan) {
        $routeCounts = @{}
        $slotNames = @($slotTable.PSObject.Properties.Name)
        foreach ($sn in $slotNames) {
            $entry = $slotTable.$sn
            $r = ("" + (Get-GateProp -Object $entry -Names @('route') -Default '')).Trim().ToUpperInvariant()
            if (-not $r) { $findings.Add(("contract.visualPlan.slots.{0} declares no route" -f $sn)); continue }
            $routeCounts[$r] = [int]$routeCounts[$r] + $pcs.Count
        }
        if ($slotNames.Count -ne $per) {
            $findings.Add(("contract.visualPlan.slots declares {0} slot shape(s) but visuals.perSubSection is {1}: the slot table and the count disagree" -f $slotNames.Count, $per))
        }
        #  The cover is a Route A image when it is planned; the slot table
        #  describes sub-section slots only, so the cover is added from the
        #  cover file itself, never typed.
        $coverRoute = ''
        if ($coverSeen -and $coverCount -gt 0) {
            $cj = Get-GateJson -Path (Join-Path $(if ($SpineDir) { $SpineDir } else { Join-Path $BuildDir 'spine' }) 'cover.json')
            $cv = if ($null -ne $cj) { Get-GateProp -Object $cj -Names @('visual') -Default $null } else { $null }
            $coverRoute = if ($null -ne $cv) { ("" + (Get-GateProp -Object $cv -Names @('route') -Default 'A')).Trim().ToUpperInvariant() } else { 'A' }
            if ($coverRoute) { $routeCounts[$coverRoute] = [int]$routeCounts[$coverRoute] + $coverCount }
        }
        $routeFindings = 0
        $declared = @{}
        foreach ($r in @($routeCounts.Keys | Sort-Object)) {
            $keyName = ('route{0}Count' -f $r)
            $decRaw = Get-GateProp -Object $visualPlan -Names @($keyName) -Default $null
            if ($null -eq $decRaw) { continue }   # a route with no typed total has nothing to disagree with
            $dec = 0
            $declared[$r] = "" + $decRaw
            if (-not [int]::TryParse(("" + $decRaw).Trim(), [ref]$dec) -or $dec -ne [int]$routeCounts[$r]) {
                $routeFindings++
                $findings.Add(("contract.visualPlan.{0} = '{1}' but the slot table derives {2} for route {3} ({4} slot shape(s) x {5} sub-section(s){6})" -f $keyName, $decRaw, $routeCounts[$r], $r, @($slotNames | Where-Object { ("" + (Get-GateProp -Object $slotTable.$_ -Names @('route') -Default '')).Trim().ToUpperInvariant() -eq $r }).Count, $pcs.Count, $(if ($coverRoute -eq $r -and $coverCount -gt 0) { ' + the cover' } else { '' })))
            }
        }
        $routes = [pscustomobject]@{ derived = $routeCounts; declared = $declared }
        & $say ("  route totals derived from the slot table: {0}" -f ((@($routeCounts.Keys | Sort-Object) | ForEach-Object { "{0}={1}" -f $_, $routeCounts[$_] }) -join ', ')) 'DarkGray'
        Complete-GateArm -Name 'route-plan' -State ran -Size ($slotNames.Count + 1) -Findings $routeFindings
    }

    $roster = Write-GateArmRoster
    Assert-GateArmsComplete

    # ---- report
    $fp = ''
    try { $fp = Get-SpineFingerprint -BuildDir $BuildDir -SpineDir $SpineDir -Quiet } catch { $fp = '' }
    $verdict = $(if ($findings.Count -eq 0) { 'pass' } else { 'fail' })
    if (-not $ReportPath) { $ReportPath = Join-Path $BuildDir 'visual-count-report.json' }
    $payload = [ordered]@{
        gate             = $GATE
        generated        = (Get-Date).ToUniversalTime().ToString('o')
        spineFingerprint = $fp
        perSubSection    = $per
        subSections      = @($pcs)
        expectedOnSubSections = $expectedTotal
        foundOnSubSections    = $foundTotal
        #  PS 5.1: @() over a List[object] of PSCustomObjects inside an [ordered]
        #  literal throws 'Argument types do not match'; ToArray() does not.
        rows             = $rows.ToArray()
        unattributed     = $unattributed.ToArray()
        cover            = [pscustomobject]@{ file = 'cover.json'; expected = 1; found = $coverCount }
        routes           = $routes
        findings         = $findings.ToArray()
        arms             = @($roster)
        verdict          = $verdict
    }
    try { [IO.File]::WriteAllText($ReportPath, ($payload | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding($false))) }
    catch { & $say ("  ! {0}: could not write {1}: {2}" -f $GATE, $ReportPath, $_.Exception.Message) 'Yellow' }

    if (-not $Quiet) { Write-Host '' }
    foreach ($fd in $findings) { & $say ("  X {0}" -f $fd) 'Red' }
    if ($findings.Count -eq 0) {
        & $say ("  every declared sub-section plans {0} visual(s), the cover plans 1, and the route totals agree ({1} sub-section(s))" -f $per, $pcs.Count) 'Green'
        return 0
    }
    & $say ("  {0} planned-visual count finding(s)" -f $findings.Count) 'Red'
    return 1
}

function Invoke-VcRun {
    <# The gate with its refusal mapping, returning the exit code instead of exiting (the self-test calls it in-process). #>
    param([string] $BuildDir, [string] $SpineDir, [string] $ReportPath, [bool] $Quiet)
    try {
        $rc = Invoke-VcGate -BuildDir $BuildDir -SpineDir $SpineDir -ReportPath $ReportPath -Quiet $Quiet
        $script:VcLastRc = [int]$rc
        return [int]$rc
    }
    catch {
        $m = $_.Exception.Message
        if ($m -match '^(CHECK-SET EMPTY|ARMS INCOMPLETE)') {
            Write-Host ("  X {0}: {1}" -f $GATE, $m) -ForegroundColor Red
            try { [void](Write-GateArmRoster) } catch { }
            $script:VcLastRc = 2
            return 2
        }
        throw
    }
}

# ---------------------------------------------------------------------------
# Self-test: a synthetic contract and spine; every plant read back before it
# is believed; every refusal and finding asserted by name.
# ---------------------------------------------------------------------------
function Invoke-VcSelfTest {
    $script:vcFailed = 0
    $ok = { param([bool] $c, [string] $msg) if ($c) { Write-Host ("  ok   {0}" -f $msg) -ForegroundColor Green } else { Write-Host ("  FAIL {0}" -f $msg) -ForegroundColor Red; $script:vcFailed++ } }
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $tmp = Join-Path $env:TEMP ('vcselftest_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $spine = Join-Path $tmp 'spine'
    New-Item -ItemType Directory -Force -Path $spine | Out-Null

    $writeJson = { param([string] $path, $obj) [IO.File]::WriteAllText($path, ($obj | ConvertTo-Json -Depth 20), $utf8) }
    $contractObj = {
        [ordered]@{
            unit = [ordered]@{ code = 'TEST' }
            visuals = [ordered]@{ perSubSection = 2 }
            topics = @(
                [ordered]@{ n = 1; pcs = @('1.1', '1.2') }
            )
            visualPlan = [ordered]@{
                perSubSection = 2
                slots = [ordered]@{
                    'X.1' = [ordered]@{ route = 'A'; kind = 'Illustration' }
                    'X.2' = [ordered]@{ route = 'B'; kind = 'Diagram' }
                }
                routeACount = 3
                routeBCount = 2
            }
        }
    }
    $visual = { param([string] $slot, [string] $kind) [ordered]@{ slot = $slot; kind = $kind; caption = ('Figure ' + $slot + ' - a thing'); alt = 'a thing'; prompt = 'p' } }
    $reset = {
        & $writeJson (Join-Path $tmp 'contract.json') (& $contractObj)
        & $writeJson (Join-Path $spine 't1_1.1.json') ([ordered]@{ ref = '1.1'; pc = '1.1'; visuals = @((& $visual '1.1.1' 'Image'), (& $visual '1.1.2' 'Diagram')) })
        & $writeJson (Join-Path $spine 't1_1.2.json') ([ordered]@{ ref = '1.2'; pc = '1.2'; visuals = @((& $visual '1.2.1' 'Image'), (& $visual '1.2.2' 'Diagram')) })
        & $writeJson (Join-Path $spine 't1_topic.json') ([ordered]@{ number = 1; title = 'Topic' })
        & $writeJson (Join-Path $spine 'front.json') ([ordered]@{ title = 'Front' })
        & $writeJson (Join-Path $spine 'deckframe.json') ([ordered]@{ title = 'Deck' })
        & $writeJson (Join-Path $spine 'cover.json') ([ordered]@{ visual = [ordered]@{ slot = 'cover'; kind = 'Image'; route = 'A'; caption = 'c'; alt = 'cover'; prompt = 'x' } })
        Remove-Item -LiteralPath (Join-Path $tmp 'visual-count-report.json') -Force -ErrorAction SilentlyContinue
    }
    $run = {
        param([hashtable] $a)
        #  -Width: the host wraps at the console width, which would break a long
        #  finding across lines and make an assertion pass or fail on the
        #  terminal size rather than on the gate's behaviour.
        $text = & { Invoke-VcRun @a } 6>&1 | Out-String -Width 4096
        return [pscustomobject]@{ Rc = $script:VcLastRc; Text = $text }
    }

    try {
        Write-Host ''
        Write-Host ("{0} self-test" -f $GATE) -ForegroundColor Cyan

        # clean control
        & $reset
        $r = & $run @{ BuildDir = $tmp; Quiet = $false }
        & $ok ($r.Rc -eq 0) ("clean fixture passes (rc={0})" -f $r.Rc)
        & $ok ($r.Text -match '(?m)^ARMS: .*declared-plan\|true\|ran\|3\|0;per-subsection\|true\|ran\|2\|0;unattributed\|true\|ran\|6\|0;cover\|true\|ran\|1\|0;route-plan\|true\|ran\|3\|0') 'the roster shows every arm ran with 0 findings'
        $rep = Get-Content (Join-Path $tmp 'visual-count-report.json') -Raw | ConvertFrom-Json
        & $ok (($rep.verdict -eq 'pass') -and ($rep.expectedOnSubSections -eq 4) -and ($rep.foundOnSubSections -eq 4) -and ($rep.cover.found -eq 1) -and ($rep.spineFingerprint -match '^v2:[0-9a-f]{32}$')) 'the report carries verdict, derived totals, the cover count and the v2 fingerprint'
        & $ok (($rep.routes.derived.A -eq 3) -and ($rep.routes.derived.B -eq 2)) ("route totals derived: A={0}, B={1}" -f $rep.routes.derived.A, $rep.routes.derived.B)

        # plant 1: one visual short on 1.2
        & $reset
        & $writeJson (Join-Path $spine 't1_1.2.json') ([ordered]@{ ref = '1.2'; pc = '1.2'; visuals = @(, (& $visual '1.2.1' 'Image')) })
        $chk = Get-Content (Join-Path $spine 't1_1.2.json') -Raw | ConvertFrom-Json
        & $ok (@($chk.visuals).Count -eq 1) 'plant 1 landed: t1_1.2.json plans one visual'
        $r = & $run @{ BuildDir = $tmp; Quiet = $false }
        & $ok (($r.Rc -eq 1) -and ($r.Text -match 'sub-section 1\.2 \(t1_1\.2\.json\): 1 visual\(s\) planned on the spine, contract expects 2')) ("a sub-section one visual short fails naming it, expected and found (rc={0})" -f $r.Rc)
        & $ok ($r.Text -notmatch 'sub-section 1\.1 ') 'the complete sub-section is not named'

        # plant 2: a visual on the topic file
        & $reset
        & $writeJson (Join-Path $spine 't1_topic.json') ([ordered]@{ number = 1; title = 'Topic'; visuals = @(, (& $visual '1.0.1' 'Image')) })
        $r = & $run @{ BuildDir = $tmp; Quiet = $false }
        & $ok (($r.Rc -eq 1) -and ($r.Text -match 'no declared sub-section: t1_topic\.json \(1 visual\(s\), maps to no sub-section\)')) ("a visual on a topic file is an unattributed finding naming the file (rc={0})" -f $r.Rc)

        # plant 3: a sub-section file for an undeclared PC
        & $reset
        & $writeJson (Join-Path $spine 't1_1.3.json') ([ordered]@{ ref = '1.3'; pc = '1.3'; visuals = @((& $visual '1.3.1' 'Image'), (& $visual '1.3.2' 'Diagram')) })
        $r = & $run @{ BuildDir = $tmp; Quiet = $false }
        & $ok (($r.Rc -eq 1) -and ($r.Text -match 't1_1\.3\.json \(2 visual\(s\), maps to undeclared sub-section 1\.3\)')) ("a file for a PC the contract does not declare is named as undeclared (rc={0})" -f $r.Rc)
        Remove-Item -LiteralPath (Join-Path $spine 't1_1.3.json') -Force

        # plant 4: a declared PC with no spine file
        & $reset
        $c4 = & $contractObj; $c4.topics = @([ordered]@{ n = 1; pcs = @('1.1', '1.2', '1.3') }); $c4.visualPlan.routeACount = 4; $c4.visualPlan.routeBCount = 3
        & $writeJson (Join-Path $tmp 'contract.json') $c4
        $r = & $run @{ BuildDir = $tmp; Quiet = $false }
        & $ok (($r.Rc -eq 1) -and ($r.Text -match 'sub-section 1\.3 \(\(no spine file\)\): 0 visual\(s\) planned on the spine, contract expects 2')) ("a declared PC with no spine file fails naming it with found 0 (rc={0})" -f $r.Rc)

        # plant 5: perSubSection missing -> refusal naming the key
        & $reset
        $c5 = & $contractObj; $c5.visuals = [ordered]@{ note = 'nothing declared' }
        & $writeJson (Join-Path $tmp 'contract.json') $c5
        $r = & $run @{ BuildDir = $tmp; Quiet = $false }
        & $ok (($r.Rc -eq 2) -and ($r.Text -match 'CHECK-SET EMPTY: contract\.visuals\.perSubSection')) ("a missing perSubSection is a refusal naming the key (rc={0})" -f $r.Rc)
        $c5b = & $contractObj; $c5b.visuals.perSubSection = 'four'
        & $writeJson (Join-Path $tmp 'contract.json') $c5b
        $r = & $run @{ BuildDir = $tmp; Quiet = $false }
        & $ok (($r.Rc -eq 2) -and ($r.Text -match "contract\.visuals\.perSubSection yielded nothing usable \(value: 'four'\)")) ("a non-numeric perSubSection is a refusal quoting the value (rc={0})" -f $r.Rc)

        # plant 6: no pcs anywhere -> refusal naming contract.topics[].pcs
        & $reset
        $c6 = & $contractObj; $c6.topics = @([ordered]@{ n = 1; title = 'no pcs' })
        & $writeJson (Join-Path $tmp 'contract.json') $c6
        $r = & $run @{ BuildDir = $tmp; Quiet = $false }
        & $ok (($r.Rc -eq 2) -and ($r.Text -match 'CHECK-SET EMPTY: contract\.topics\[\]\.pcs')) ("an empty PC union is a refusal naming contract.topics[].pcs (rc={0})" -f $r.Rc)

        # plant 7: the cover without its visual, then no cover file at all
        & $reset
        & $writeJson (Join-Path $spine 'cover.json') ([ordered]@{ _comment = 'no visual yet' })
        $r = & $run @{ BuildDir = $tmp; Quiet = $false }
        & $ok (($r.Rc -eq 1) -and ($r.Text -match 'cover\.json plans 0 visual\(s\); exactly 1 is expected')) ("a cover with no visual fails naming cover.json (rc={0})" -f $r.Rc)
        Remove-Item -LiteralPath (Join-Path $spine 'cover.json') -Force
        $r = & $run @{ BuildDir = $tmp; Quiet = $false }
        & $ok (($r.Rc -eq 2) -and ($r.Text -match 'CHECK-SET EMPTY: cover\.json yielded nothing')) ("no cover file is a refusal naming cover.json (rc={0})" -f $r.Rc)

        # plant 8: a typed route total that disagrees with the slot table
        & $reset
        $c8 = & $contractObj; $c8.visualPlan.routeACount = 4
        & $writeJson (Join-Path $tmp 'contract.json') $c8
        $r = & $run @{ BuildDir = $tmp; Quiet = $false }
        & $ok (($r.Rc -eq 1) -and ($r.Text -match "contract\.visualPlan\.routeACount = '4' but the slot table derives 3 for route A \(1 slot shape\(s\) x 2 sub-section\(s\) \+ the cover\)")) ("a typed route total that disagrees with the derived one fails naming both (rc={0})" -f $r.Rc)

        # plant 9: the two perSubSection declarations disagree
        & $reset
        $c9 = & $contractObj; $c9.visualPlan.perSubSection = 3
        & $writeJson (Join-Path $tmp 'contract.json') $c9
        $r = & $run @{ BuildDir = $tmp; Quiet = $false }
        & $ok (($r.Rc -eq 1) -and ($r.Text -match "contract\.visuals\.perSubSection = 2 but contract\.visualPlan\.perSubSection = '3'")) ("disagreeing perSubSection copies fail naming both values (rc={0})" -f $r.Rc)

        # plant 10: no visualPlan at all -> the route arm is not registered, the rest still gates
        & $reset
        $c10 = & $contractObj; $c10.Remove('visualPlan')
        & $writeJson (Join-Path $tmp 'contract.json') $c10
        $r = & $run @{ BuildDir = $tmp; Quiet = $false }
        & $ok (($r.Rc -eq 0) -and ($r.Text -notmatch 'route-plan\|')) ("without a visualPlan the route arm is absent from the roster and the count arms still pass (rc={0})" -f $r.Rc)

        # refusals by name: no -BuildDir, no contract
        $r = & $run @{ BuildDir = ''; Quiet = $false }
        & $ok (($r.Rc -eq 2) -and ($r.Text -match 'CHECK-SET EMPTY: -BuildDir')) ("no -BuildDir is a refusal naming it (rc={0})" -f $r.Rc)
        & $reset
        Remove-Item -LiteralPath (Join-Path $tmp 'contract.json') -Force
        $r = & $run @{ BuildDir = $tmp; Quiet = $false }
        & $ok (($r.Rc -eq 2) -and ($r.Text -match 'contract\.json yielded nothing')) ("no contract.json is a refusal naming it (rc={0})" -f $r.Rc)

        # the header line the runner discovers
        $head = (Get-Content $PSCommandPath -TotalCount 60) -join "`n"
        & $ok ($head -match '(?m)^# GATE: stages=3c; requires=BuildDir\s*$') 'the GATE header declares stage 3c and requires BuildDir'
    }
    finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host ''
    if ($script:vcFailed -gt 0) {
        Write-Host ("  {0} self-test: {1} case(s) FAILED - no verdict from this gate may be believed until they pass" -f $GATE, $script:vcFailed) -ForegroundColor Red
        return 4
    }
    Write-Host ("  {0} self-test: all cases passed" -f $GATE) -ForegroundColor Green
    return 0
}

if ($SelfTest) { exit (Invoke-VcSelfTest) }

if (-not $Quiet) {
    Write-Host ''
    Write-Host ("{0} - planned visual count, derived from contract.json" -f $GATE) -ForegroundColor Cyan
}
exit (Invoke-VcRun -BuildDir $BuildDir -SpineDir $SpineDir -ReportPath $ReportPath -Quiet ([bool]$Quiet))
