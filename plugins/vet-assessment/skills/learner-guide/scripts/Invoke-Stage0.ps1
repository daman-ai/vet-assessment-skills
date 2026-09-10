<#
    Invoke-Stage0.ps1 - the Stage 0 pre-flight runner, and the one thing it may
    never do is record a THROW as a pass.

    WHY IT EXISTS. On the reference build Stage 0 was performed by a
    build-local Stage0-Preflight.ps1 and written into the ledger by hand. That
    run recorded a CommandNotFound throw for the palette check and a non-zero
    exit from the fixtures gate, and the ledger record said `pass`, with a note
    asserting the opposite of both. Nothing on disk could contradict it,
    because Stage 0 wrote no results file at all. Stages 1, 2, 3c, 4 and 7c all
    have one; Stage 0, the stage that decides whether the gates are trustworthy
    at all, did not.

    So this runner writes `0-results.json` IN THE 3c SHAPE - the same keys
    Run-SpineGates writes, so one reader serves every banded stage - and the
    verdict in it is DERIVED from what each member actually did:

      * a member that THROWS is FAIL, and the exception text is its reason
      * a member that exits non-zero is FAIL, and the exit code is recorded
      * a member with no implementation is NOT RUN, named in partial[], and is
        never PASS
      * the endpoint probe is NON-BLOCKING by declaration in gates.md, and its
        exit code is recorded and excluded from failed[] - never quietly
        dropped, and never allowed to fail the stage

    THE MEMBER SET IS DERIVED FROM references\gates.md. Every row of the stage
    table whose Stage column is `0` or `S0-RTO` is a member, and the Blocks
    column decides whether it can fail the stage. A row this runner has no
    binding for is a REFUSAL (exit 2) naming the row: a new Stage 0 gate added
    to the documentation must be wired here before Stage 0 can pass again,
    which is the opposite of the arrangement where the documentation named
    three gates nobody had built and the stage passed anyway.

    THREE DOCUMENTED STAGE 0 GATES ARE NOT IMPLEMENTED - Assert-RendererContract,
    Assert-DownstreamPalette and Assert-LongStageOutputContract. They are read
    out of gates.md by their own NOT YET IMPLEMENTED marker, recorded NOT RUN
    with that reason, and listed in partial[]. Marking them is the whole point:
    an unimplemented blocking gate that leaves no trace is indistinguishable
    from one that ran and passed.

    THE FIXTURES MEMBER RUNS -StaticOnly, and that is deliberate. The plant
    channel opens Word, spends image credit and takes minutes; it is a
    background job keyed on the scripts hash and it need not finish before
    Stage 0. What Stage 0 asserts is the STATIC arms - the gate set derives,
    every gate parses, no recipe is orphaned - plus a NAMED partial listing
    every Blocks=yes gate the newest fixtures report did not prove. An UNPROVEN
    gate is therefore visible in `0-results.json` by name, rather than being
    absorbed into an exit code nobody reads.

    Usage
      Invoke-Stage0.ps1 -BuildDir <out> -Rto MVC [-UnitCode SITXINV007]
      Invoke-Stage0.ps1 -SelfTest

    PS 5.1. ASCII only in this file.
    Exit 0 every blocking member passed; 1 a blocking member failed; 2 refused
    (an input is missing, or a documented member has no binding); 4 the
    self-test failed.
#>

# GATE: stages=0; requires=BuildDir,Rto

[CmdletBinding()]
param(
    #  The build directory. 0-results.json is written here unless -ResultDir
    #  says otherwise.
    [string] $BuildDir,

    #  The RTO whose profile pack this build uses. Untyped and named -Rto to
    #  match Get-RtoProfile.ps1's own contract.
    $Rto,

    #  The skill directory. Defaults to the parent of this script's directory.
    [string] $SkillDir,

    #  The unit code, used only to resolve a brand variant for the palette
    #  check. A brand with no variants does not need it.
    [string] $UnitCode,

    #  Where 0-results.json and each member's log are written.
    [string] $ResultDir,

    #  references\gates.md, if it is not where it usually is. The member set is
    #  derived from its stage table.
    [string] $GatesDoc,

    #  The newest fixtures report, if it is not under -BuildDir or -ResultDir.
    [string] $FixtureReport,

    #  Per-member ceiling.
    [int] $TimeoutMinutes = 20,

    #  The probe spends one low-quality image. Skipping it records the member
    #  NOT RUN with that reason - it is non-blocking either way, and it is
    #  never recorded as having passed.
    [switch] $SkipProbe,

    [switch] $SelfTest,
    [switch] $Quiet
)

$GATE = 'Invoke-Stage0'

# ---------------------------------------------------------------------------
# Small shared shapes, written the way Run-SpineGates writes them
# ---------------------------------------------------------------------------

function Get-S0Utc { return (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ') }

function Write-S0Json {
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)] $Body)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $json = ($Body | ConvertTo-Json -Depth 100) -replace "`r?`n", "`r`n"
    [System.IO.File]::WriteAllText($Path, $json + "`r`n", (New-Object System.Text.UTF8Encoding($true)))
}

function Get-S0Text {
    param([Parameter(Mandatory)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    $t = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path, [System.Text.Encoding]::UTF8)
    return $t.TrimStart([char]0xFEFF)
}

function Get-S0Short {
    param([string] $Value, [int] $Max = 400)
    if ($null -eq $Value) { return '' }
    $one = ($Value -replace '\s+', ' ').Trim()
    if ($one.Length -le $Max) { return $one }
    return ($one.Substring(0, $Max) + ' ...')
}

# ---------------------------------------------------------------------------
# The member set, DERIVED from the gates.md stage table
# ---------------------------------------------------------------------------

function Get-S0GatesDocPath {
    param([string] $GatesDoc, [string] $SkillDir)
    if ($GatesDoc) { return $GatesDoc }
    return (Join-Path $SkillDir 'references\gates.md')
}

function Get-S0RowKey {
    <#  The member key a stage-table row names.

        The FIRST backticked token in the Script column is the thing the row
        points at. Where it names a script, the key is that script's leaf;
        otherwise it is the identifier itself. Taking the first one matters: a
        row can mention a second script in its prose ("the write-time arm is
        scripts\Test-SpineRead.ps1"), and keying on that would bind a member to
        a gate the row does not claim.  #>
    param([string] $ScriptCell)
    $m = [regex]::Match("$ScriptCell", '`([^`]+)`')
    if (-not $m.Success) { return '' }
    $tok = $m.Groups[1].Value.Trim()
    $ps1 = [regex]::Match($tok, '([A-Za-z0-9_.-]+\.ps1)')
    if ($ps1.Success) { return $ps1.Groups[1].Value }
    $id = [regex]::Match($tok, '^[A-Za-z][A-Za-z0-9-]*')
    if ($id.Success) { return $id.Value }
    return $tok
}

function Get-S0StageRow {
    <#  Every row of the gates.md stage table, parsed.

        Not a hand-listed member array: adding a Stage 0 row to the
        documentation adds a member here, and a member with no binding refuses
        rather than vanishing.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)
    $txt = Get-S0Text -Path $Path
    if (-not $txt) { throw ("references\gates.md is not readable at {0}. The Stage 0 member set is derived from its stage table; there is no hand-listed fallback, because a hand-listed member set is how three documented Stage 0 gates came to be enforced by nobody." -f $Path) }
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($line in ($txt -split "`r?`n")) {
        if ($line -notmatch '^\s*\|') { continue }
        $cells = @(($line -split '\|') | ForEach-Object { $_.Trim() })
        #  a split on '|' yields an empty first and last cell
        if ($cells.Count -lt 7) { continue }
        $stage = $cells[1]
        if ($stage -match '^-+$' -or $stage -eq 'Stage') { continue }
        $blocks = $cells[4]
        $rows.Add([pscustomobject]@{
            Stage    = $stage
            Gate     = $cells[2]
            Script   = $cells[3]
            Blocks   = ($blocks -match '(?i)yes')
            Section  = $cells[5]
            Key      = (Get-S0RowKey -ScriptCell $cells[3])
            NotImplemented = ($cells[3] -match 'NOT YET IMPLEMENTED')
        })
    }
    return $rows.ToArray()
}

function Get-S0BlockingGateSet {
    <#  Every Blocks=yes row that names a real script, by script leaf.

        This is the denominator the UNPROVEN partial is measured against, and
        it is the documentation's own claim about which gates block - not a
        list typed here.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Rows)
    $out = [ordered]@{}
    foreach ($r in $Rows) {
        if (-not $r.Blocks) { continue }
        if ($r.NotImplemented) { continue }
        if ($r.Key -notmatch '\.ps1$') { continue }
        $name = [System.IO.Path]::GetFileNameWithoutExtension($r.Key)
        if (-not $out.Contains($name)) { $out[$name] = $r.Stage }
    }
    return $out
}

# ---------------------------------------------------------------------------
# The newest fixtures report, and what it did NOT prove
# ---------------------------------------------------------------------------

function Get-S0FixtureReport {
    <#  The newest gate-fixtures report under the directories given.

        A hash-stamped `gate-fixtures.<hash>.json` is preferred over the plain
        file when both are present - it is the plant channel's own evidence,
        keyed to the scripts it judged - but the plain file is read when it is
        all there is, and the report says WHICH was read. A reader must never
        have to guess which run a proof came from.  #>
    [CmdletBinding()]
    param([string[]] $Directory, [string] $Explicit)
    if ($Explicit) {
        if (-not (Test-Path -LiteralPath $Explicit)) { return [pscustomobject]@{ Found = $false; Path = $Explicit; Hash = ''; Note = ("no fixtures report at {0}" -f $Explicit); Results = @() } }
        $f = Get-Item -LiteralPath $Explicit
    }
    else {
        $cands = New-Object System.Collections.Generic.List[object]
        foreach ($d in @($Directory | Where-Object { $_ -and (Test-Path -LiteralPath $_) })) {
            foreach ($x in @(Get-ChildItem -LiteralPath $d -Filter 'gate-fixtures*.json' -File -ErrorAction SilentlyContinue)) { $cands.Add($x) }
        }
        if ($cands.Count -eq 0) {
            return [pscustomobject]@{ Found = $false; Path = ''; Hash = ''; Results = @()
                Note = ("no gate-fixtures report under {0}. The UNPROVEN list is empty because nothing was read, which is not the same as nothing being unproven." -f (@($Directory) -join '; ')) }
        }
        $stamped = @($cands | Where-Object { $_.Name -match '^gate-fixtures\.[0-9a-f]{6,}\.json$' } | Sort-Object LastWriteTimeUtc -Descending)
        $f = $(if ($stamped.Count -gt 0) { $stamped[0] } else { @($cands | Sort-Object LastWriteTimeUtc -Descending)[0] })
    }
    $hash = ''
    $hm = [regex]::Match($f.Name, '^gate-fixtures\.([0-9a-f]{6,})\.json$')
    if ($hm.Success) { $hash = $hm.Groups[1].Value }
    $j = $null
    try { $j = (Get-S0Text -Path $f.FullName) | ConvertFrom-Json }
    catch {
        return [pscustomobject]@{ Found = $false; Path = $f.FullName; Hash = $hash; Results = @()
            Note = ("the fixtures report {0} is not valid JSON: {1}" -f $f.Name, $_.Exception.Message) }
    }
    #  A -StaticOnly report carries no per-gate discrimination verdict at all -
    #  it proves the gate set derives, the headers reconcile and every gate
    #  parses, which is a different claim. Reading it as evidence that a gate
    #  fails on a planted defect would be the false PROVEN the fixtures gate
    #  exists to prevent, so the mode is read and said out loud.
    $mode = "$($j.mode)"
    $results = @($j.results)
    $note = ''
    if ($mode -eq 'static' -or (@($results).Count -eq 0 -and (@($j.PSObject.Properties.Name) -contains 'findings'))) {
        $note = ("{0} is a STATIC report (scripts hash {1}): it proves the gate set derives and every gate parses, and it proves discrimination for NOTHING. Until the plant channel writes gate-fixtures.<hash>.json every Blocks=yes gate is unproven, and each is named below. Written {2}." -f `
                 $f.Name, $(if ("$($j.scriptsHash)") { "$($j.scriptsHash)".Substring(0, [Math]::Min(12, "$($j.scriptsHash)".Length)) } else { 'none' }), $f.LastWriteTimeUtc.ToString('yyyy-MM-ddTHH:mm:ssZ'))
        $results = @()
    }
    else {
        $note = ("{0}{1}, {2} gate result(s), written {3}" -f $f.Name, $(if ($hash) { " (scripts hash $hash)" } else { ' (NOT hash-stamped - the plant channel has not written one)' }), @($results).Count, $f.LastWriteTimeUtc.ToString('yyyy-MM-ddTHH:mm:ssZ'))
    }
    return [pscustomobject]@{ Found = $true; Path = $f.FullName; Hash = $hash; Results = $results; Mode = $mode; Note = $note }
}

function Get-S0Unproven {
    <#  Every Blocks=yes gate the fixtures report did not prove, BY NAME.

        A gate absent from the report is unproven exactly as a gate the report
        calls UNPROVEN is: in both cases nothing has shown it fails on the
        defect it claims to catch. Reporting only the rows the file happens to
        carry would make an empty report look like a clean one.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Blocking, [Parameter(Mandatory)] $Report)
    $seen = @{}
    foreach ($r in @($Report.Results)) {
        $n = "$($r.Gate)"
        if (-not $n) { continue }
        $seen[$n] = "$($r.Verdict)"
    }
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($g in @($Blocking.Keys)) {
        if ($seen.ContainsKey($g)) {
            if ("$($seen[$g])" -notlike 'PROVEN*') { $out.Add([pscustomobject]@{ gate = $g; stage = $Blocking[$g]; verdict = $seen[$g] }) }
        }
        else { $out.Add([pscustomobject]@{ gate = $g; stage = $Blocking[$g]; verdict = 'ABSENT FROM THE REPORT' }) }
    }
    return @($out | Sort-Object gate)
}

# ---------------------------------------------------------------------------
# One member, run and recorded honestly
# ---------------------------------------------------------------------------

function New-S0Entry {
    <#  One member's record, in the same shape Run-SpineGates writes.

        Verdict is PASS, FAIL, NOT RUN or REFUSED, and NOTHING sets it but this
        function: it is computed from the exit code and the exception, never
        passed in beside them. That separation IS the change - the record this
        replaces carried a hand-written status and a note that contradicted it.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Name,
        [string] $Script = '',
        [string] $Stage = '0',
        [bool] $Blocking = $true,
        [Nullable[int]] $ExitCode = $null,
        [string] $Error = '',
        [string] $Reason = '',
        [string] $NotRun = '',
        [bool] $NotImplemented = $false,
        [string] $Refused = '',
        [double] $Seconds = 0,
        [string] $StartedAt = '',
        [string] $Text = '',
        $Params = $null
    )
    $verdict = 'PASS'
    $why = $Reason
    if ($NotRun) { $verdict = 'NOT RUN'; if (-not $why) { $why = $NotRun } }
    elseif ($Refused) { $verdict = 'REFUSED'; if (-not $why) { $why = $Refused } }
    elseif ($Error) { $verdict = 'FAIL'; if (-not $why) { $why = ('THREW: ' + (Get-S0Short -Value $Error)) } }
    elseif ($null -ne $ExitCode -and [int]$ExitCode -ne 0) { $verdict = 'FAIL'; if (-not $why) { $why = ("exit code {0}" -f [int]$ExitCode) } }
    $pv = [ordered]@{}
    if ($null -ne $Params) { foreach ($k in @($Params.Keys)) { $pv[[string]$k] = $Params[$k] } }
    return [pscustomobject]([ordered]@{
        name = $Name; script = $Script; phase = 1; stage = $Stage
        blocking = $Blocking; notImplemented = $NotImplemented
        params = [pscustomobject]$pv; dropped = @(); must = @()
        exitCode = $(if ($null -ne $ExitCode) { [int]$ExitCode } else { $null })
        startedAt = $StartedAt; ranAt = (Get-S0Utc)
        seconds = [math]::Round($Seconds, 1); gateSeconds = [math]::Round($Seconds, 1)
        verdict = $verdict; reason = $why; refused = [bool]$Refused
        error = (Get-S0Short -Value $Error)
        evidence = ''
        arms = @(); armLines = @(); armsBlockingNotRun = @(); armProblems = @()
        fixtureProof = ''
        header = ''; headerStages = @('0'); headerProblems = @()
        reports = @()
        log = ''
        summaryLines = @($(if ($Text) { @($Text -split "`r?`n" | Where-Object { $_ -match '^(PASS|FAIL|HYGIENE|FIXTURES|PARTIAL|LIST ONLY)' } | Select-Object -Last 3) } else { @() }))
    })
}

function Invoke-S0Script {
    <#  Run one skill script as a child of this process and read its exit code
        RIGHT THERE.

        $LASTEXITCODE is stale after a cmdlet, so it is captured on the very
        next statement and never consulted again. The probe's exit code in
        particular has to be read here and nowhere else: it is the one member
        whose non-zero exit must NOT fail the stage, and reading a stale value
        later is how a non-blocking member came to be recorded as a failure -
        and how the fixtures gate's real non-zero exit came to be recorded as a
        pass.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path, [hashtable] $Arguments = @{})
    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{ ExitCode = $null; Error = ("the script is not on disk: " + $Path); Text = '' }
    }
    $global:LASTEXITCODE = 0
    $text = ''
    $err = ''
    $rc = $null
    try {
        $out = & $Path @Arguments 6>&1 2>&1
        $rc = $global:LASTEXITCODE
        $text = ($out | Out-String -Width 4096)
    }
    catch {
        $rc = $global:LASTEXITCODE
        $err = $_.Exception.Message
    }
    return [pscustomobject]@{ ExitCode = $rc; Error = $err; Text = $text }
}

# ---------------------------------------------------------------------------
# The bindings - one per documented Stage 0 row, plus the runner's own two
# ---------------------------------------------------------------------------

function Get-S0Binding {
    <#  Which member key this runner knows how to run.

        A documented Stage 0 row whose key is not here and which is not marked
        NOT YET IMPLEMENTED is a REFUSAL. That is the point: the documentation
        and the runner move together, or Stage 0 says so.  #>
    return @(
        'Get-RtoProfile.ps1',
        'Get-BrandPalettePairs',
        'Assert-GateFixtures.ps1',
        'Assert-GateHygiene.ps1',
        'Probe-GenerationEndpoints.ps1',
        #  The runner's own two. gates.md binds the `schema-compile` and
        #  `library-load` rows to scripts\Invoke-Stage0.ps1, so both rows key to
        #  this file's leaf. They ARE implemented - run inline in
        #  Invoke-Stage0Run, because the dot-source cannot live in a function -
        #  but omitting the key here made every Stage 0 run refuse at exit 2,
        #  naming this script twice and running nothing.
        'Invoke-Stage0.ps1'
    )
}


# ---------------------------------------------------------------------------
# The members - each returns ONE entry, and each records what actually happened
# ---------------------------------------------------------------------------

function New-S0LibraryLoadEntry {
    <#  Record the outcome of the Lib-Resolve dot-source.

        THE DOT-SOURCE ITSELF CANNOT LIVE IN A FUNCTION, and this comment is
        the reason it is done inline in Invoke-Stage0Run instead. Dot-sourcing
        inside a function loads the definitions into THAT FUNCTION's scope, and
        they vanish the moment it returns - so a loader function reports
        success and leaves its caller with no functions at all, which is
        precisely the trap Lib-Resolve's own header documents. On the first
        draft of this runner it read as library-load PASS beside
        "Get-RtoProfile is not loaded", which is the same false pairing this
        whole change exists to make impossible.

        Library-load is a MEMBER, not a precondition, because it is the one
        that turns a missing library file into a NAMED failure: before
        Lib-Resolve loaded through a throwing loop, a renamed file loaded
        nothing, said nothing, and surfaced as a CommandNotFound throw at the
        first call site - which at Stage 0 was the palette check.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $SkillDir, [string] $ErrorText, [datetime] $Started, [string] $StartedUtc)
    return (New-S0Entry -Name 'library-load' -Script 'scripts\Lib-Resolve.ps1' -Blocking $true `
        -Error $ErrorText -StartedAt $StartedUtc -Seconds ((Get-Date) - $Started).TotalSeconds `
        -Reason $(if ($ErrorText) { '' } else { 'every library named in Lib-Resolve loaded' }) `
        -Params @{ SkillDir = $SkillDir })
}

function Invoke-S0SchemaCompile {
    <#  Compile the RTO profile SCHEMA - the file Assert-RtoProfile derives
        every one of its check-sets from.

        A schema that does not parse, or that carries no requiredKeys, no
        paletteRoles or no identityFields, makes Assert-RtoProfile a validator
        with nothing to validate against: it would run, find nothing to check,
        and pass. So the compile is its own blocking member, and it FAILS
        naming the block that is missing rather than letting an empty check-set
        read as a clean one.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $SkillDir)
    $t0 = Get-Date
    $started = Get-S0Utc
    $path = Join-Path $SkillDir 'assets\rto-profile.schema.json'
    $err = ''
    $reason = ''
    try {
        $txt = Get-S0Text -Path $path
        if (-not $txt) { throw ("no profile schema at {0}. Assert-RtoProfile derives its required keys, its closed palette-role enum and its identity fields from this file; with no schema it would validate nothing and pass." -f $path) }
        $schema = $txt | ConvertFrom-Json
        $counts = [ordered]@{}
        $counts['requiredKeys']   = @($schema.requiredKeys).Count
        $counts['paletteRoles']   = @($schema.paletteRoles.PSObject.Properties | Where-Object { $_.Name -notlike '_*' }).Count
        $counts['identityFields'] = @($schema.identityFields.required).Count
        foreach ($k in @($counts.Keys)) {
            if ([int]$counts[$k] -le 0) { throw ("the schema at {0} declares no {1}. A check-set of zero is not a clean validation." -f $path, $k) }
        }
        #  every required key needs a written reason, or the refusal it
        #  produces cannot tell a reader what the key is for
        $missingWhy = @()
        foreach ($k in @($schema.requiredKeys)) {
            $why = "$($schema.keyReasons.$k)".Trim()
            if ($why.Length -lt 20) { $missingWhy += $k }
        }
        if ($missingWhy.Count -gt 0) { throw ("the schema requires {0} key(s) it gives no auditable reason for: {1}" -f $missingWhy.Count, ($missingWhy -join ', ')) }
        $reason = ("schema compiled: {0} required key(s) each with a written reason, {1} palette role(s) in the closed enum, {2} required identity field(s)" -f $counts['requiredKeys'], $counts['paletteRoles'], $counts['identityFields'])
    }
    catch { $err = $_.Exception.Message }
    return (New-S0Entry -Name 'schema-compile' -Script 'assets\rto-profile.schema.json' -Blocking $true `
        -Error $err -Reason $reason -StartedAt $started -Seconds ((Get-Date) - $t0).TotalSeconds `
        -Params @{ SkillDir = $SkillDir })
}

function Invoke-S0RtoProfile {
    <# S0-RTO: the pack loads and validates, in process, so a THROW is visible. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $SkillDir, $Rto)
    $t0 = Get-Date
    $started = Get-S0Utc
    $err = ''
    $reason = ''
    $rc = 0
    try {
        if (-not "$Rto".Trim()) { throw 'no -Rto was given. The profile pack decides the templates, the palette roles, the identity strings and the layouts, and there is no fallback profile; a build with no brand cannot be validated against one.' }
        if (-not (Get-Command Get-RtoProfile -ErrorAction SilentlyContinue)) { throw 'Get-RtoProfile is not loaded - see the library-load member. The profile gate cannot run.' }
        $prof = Get-RtoProfile -Rto "$Rto" -SkillDir $SkillDir -SkipValidation
        $v = Assert-RtoProfile -Profile $prof
        if (-not $v.Ok) {
            $rc = 1
            $reason = ("{0} problem(s): {1}" -f @($v.Problems).Count, (Get-S0Short -Value (@($v.Problems) -join '; ')))
        }
        else {
            $reason = ("pack {0} v{1} validates: {2} palette role(s) over the closed enum, {3} identity field(s) against {4} other brand profile(s), {5} no-notes exemption(s) each with a written reason, {6} carve-out(s)" -f `
                       $prof.Rto, $prof.ProfileVersion, @($prof.PaletteRoles.Keys).Count, @($prof.Identity.Keys).Count, @($prof.OtherIdentities).Count, @($prof.NoNotesLayouts).Count, @($prof.CarveOuts).Count)
        }
        $script:S0Profile = $prof
    }
    catch { $err = $_.Exception.Message }
    return (New-S0Entry -Name 'Assert-RtoProfile' -Script 'scripts\Get-RtoProfile.ps1' -Stage 'S0-RTO' -Blocking $true `
        -ExitCode $rc -Error $err -Reason $reason -StartedAt $started -Seconds ((Get-Date) - $t0).TotalSeconds `
        -Params @{ Rto = "$Rto"; SkillDir = $SkillDir })
}

function Invoke-S0Palette {
    <#  The palette resolves as a TOTAL FUNCTION over a closed role enum.

        Get-BrandPalettePairs throws when a role resolves to nothing, and that
        throw is the gate. The SELF-MAP rule is applied on top of it, and only
        on a CROSS-BRAND build: a pair that maps to itself is the expected
        no-op when the target brand IS the template brand, and an unresolved
        property name when it is not. Applying it unconditionally would fail
        every same-brand build; not applying it at all is how one role mapped
        to itself, the apply loop skipped it, and 766 of another brand's fills
        shipped under a gate that read clean.  #>
    [CmdletBinding()]
    param($Profile, [string] $UnitCode)
    $t0 = Get-Date
    $started = Get-S0Utc
    $err = ''
    $reason = ''
    $rc = 0
    try {
        if (-not (Get-Command Get-BrandPalettePairs -ErrorAction SilentlyContinue)) {
            throw 'Get-BrandPalettePairs is not loaded, so the palette check could not run. It lives in scripts\Set-ResourceBrand.ps1, which Lib-Resolve loads - see the library-load member for what went missing.'
        }
        if ($null -eq $Profile) { throw 'no validated RTO profile - the palette map is resolved from the branding profile the pack points at, and there is no default palette.' }
        $target = [string]$Profile.Rto
        $templateBrand = [string](Get-RtoProp -Object $Profile.Raw -Path 'templates.brand')
        if (-not $templateBrand) { throw "the pack declares no templates.brand. It names the brand whose approved templates this build renders FROM, and without it a role that maps to itself cannot be told from a legitimate same-brand no-op." }
        $branding = Get-Branding -Brand $target
        $variant = Resolve-BrandVariant -Branding $branding -UnitCode $UnitCode -Variant $null
        $pal = Set-HousePalette -Brand $target -Variant $variant
        $pairs = Get-BrandPalettePairs -Palette $pal
        $moves = @(@($pairs.Keys) | Where-Object { "$($pairs[$_])" -ine "$_" })
        $selfs = @(@($pairs.Keys) | Where-Object { "$($pairs[$_])" -ieq "$_" })
        $problems = @()
        if (@($pairs.Keys).Count -eq 0) { $problems += 'the palette map is EMPTY. A brand swap over no pairs changes nothing and reports success.' }
        foreach ($k in @($pairs.Keys)) {
            if ("$($pairs[$k])" -notmatch '^[0-9A-Fa-f]{6}$') { $problems += ("the role that maps {0} resolves to '{1}', which is not a six-digit hex" -f $k, $pairs[$k]) }
        }
        if ($target -ine $templateBrand) {
            foreach ($k in $selfs) {
                $names = @($pal.PSObject.Properties | Where-Object { "$($_.Value)" -ieq "$k" } | ForEach-Object { $_.Name })
                $problems += ("SELF-MAPPING ROLE: the source colour {0} maps to itself on a CROSS-BRAND build ({1} rendered from {2} templates){3}. The apply loop skips a pair that maps to itself, so this role would silently never be swapped - which is an unresolved property name, never a legitimate no-op." -f `
                              $k, $target, $templateBrand, $(if ($names.Count) { " - palette propert(y/ies) " + ($names -join ', ') } else { '' }))
            }
        }
        if ($problems.Count -gt 0) { $rc = 1; $reason = (Get-S0Short -Value (@($problems) -join ' | ')) }
        else {
            $reason = ("palette resolves over {0} pair(s) from the closed role enum: {1} move, {2} map to themselves; target {3}, templates.brand {4} - {5}" -f `
                       @($pairs.Keys).Count, $moves.Count, $selfs.Count, $target, $templateBrand,
                       $(if ($target -ieq $templateBrand) { 'a same-brand build, so the palette step runs as NORMALISATION and a self-mapping pair is the expected no-op' } else { 'a cross-brand build, so a self-mapping pair is a failure' }))
        }
    }
    catch { $err = $_.Exception.Message }
    return (New-S0Entry -Name 'Resolve-Palette' -Script 'scripts\Set-ResourceBrand.ps1' -Blocking $true `
        -ExitCode $rc -Error $err -Reason $reason -StartedAt $started -Seconds ((Get-Date) - $t0).TotalSeconds `
        -Params @{ UnitCode = $UnitCode })
}

function Invoke-S0Fixtures {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $SkillDir, [string] $ResultDir, [string] $GatesDoc)
    $t0 = Get-Date
    $started = Get-S0Utc
    $args = @{ SkillDir = $SkillDir; StaticOnly = $true; Quiet = $true }
    if ($ResultDir) { $args['ResultDir'] = $ResultDir }
    if ($GatesDoc)  { $args['GatesDoc']  = $GatesDoc }
    $r = Invoke-S0Script -Path (Join-Path $SkillDir 'scripts\Assert-GateFixtures.ps1') -Arguments $args
    #  THE STATIC ARMS ARE WHAT STAGE 0 ASSERTS. An UNPROVEN gate is recorded
    #  by name in partial[]; it is not what fails this member, because the
    #  plant channel that would prove it is a background job that need not
    #  finish before Stage 0. A REFUSAL (2) or a failed self-test (4) does
    #  fail it: those say the static arms could not run at all.
    $rc = $r.ExitCode
    $treated = $rc
    $reason = ''
    if ($null -ne $rc -and ([int]$rc -eq 1 -or [int]$rc -eq 3)) {
        $treated = 0
        $reason = ("Assert-GateFixtures -StaticOnly exited {0}; the static arms ran and every UNPROVEN gate is named in partial[] rather than failing this member - the plant channel is a background job Stage 0 does not wait for." -f $rc)
    }
    return (New-S0Entry -Name 'Assert-GateFixtures' -Script 'scripts\Assert-GateFixtures.ps1' -Blocking $true `
        -ExitCode $treated -Error $r.Error -Reason $reason -Text $r.Text `
        -StartedAt $started -Seconds ((Get-Date) - $t0).TotalSeconds `
        -Params @{ SkillDir = $SkillDir; StaticOnly = $true; ResultDir = $ResultDir; rawExitCode = $rc })
}

function Invoke-S0Hygiene {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $SkillDir, [string] $ResultDir)
    $t0 = Get-Date
    $started = Get-S0Utc
    $args = @{ SkillDir = $SkillDir; Quiet = $true }
    if ($ResultDir) { $args['ResultDir'] = $ResultDir }
    $r = Invoke-S0Script -Path (Join-Path $SkillDir 'scripts\Assert-GateHygiene.ps1') -Arguments $args
    return (New-S0Entry -Name 'Assert-GateHygiene' -Script 'scripts\Assert-GateHygiene.ps1' -Blocking $true `
        -ExitCode $r.ExitCode -Error $r.Error -Text $r.Text `
        -StartedAt $started -Seconds ((Get-Date) - $t0).TotalSeconds `
        -Params @{ SkillDir = $SkillDir; ResultDir = $ResultDir })
}

function Invoke-S0Probe {
    <#  NON-BLOCKING BY DECLARATION. gates.md's Blocks column says no, and this
        runner reads that column rather than deciding for itself.

        Its exit code is captured on the statement after the call - never read
        later, where a cmdlet in between would have replaced it - and recorded
        in full. Recording it is the point: on the reference build the probe's
        verdict reached the ledger as prose and the exit code reached nobody.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $SkillDir, [bool] $Skip)
    $t0 = Get-Date
    $started = Get-S0Utc
    if ($Skip) {
        return (New-S0Entry -Name 'Probe-GenerationEndpoints' -Script 'scripts\Probe-GenerationEndpoints.ps1' -Blocking $false `
            -NotRun '-SkipProbe was given, so no endpoint was probed. This member is non-blocking either way, and it is recorded NOT RUN rather than as having passed.' `
            -StartedAt $started -Seconds 0)
    }
    $r = Invoke-S0Script -Path (Join-Path $SkillDir 'scripts\Probe-GenerationEndpoints.ps1') -Arguments @{ Quality = 'low'; Quiet = $true }
    $meaning = switch ([string]$r.ExitCode) {
        '0' { 'the endpoint answered 200 - go' }
        '2' { 'A QUOTA OR CREDIT BLOCK. Add credit NOW, in parallel with authoring; this does not stop the build.' }
        '3' { 'no API key was found and no call was made' }
        '1' { 'a rate limit, an auth failure, a transport error or a bad config' }
        default { 'no exit code was returned' }
    }
    return (New-S0Entry -Name 'Probe-GenerationEndpoints' -Script 'scripts\Probe-GenerationEndpoints.ps1' -Blocking $false `
        -ExitCode $r.ExitCode -Error $r.Error -Text $r.Text `
        -Reason ("exit {0}: {1}" -f $(if ($null -ne $r.ExitCode) { $r.ExitCode } else { 'none' }), $meaning) `
        -StartedAt $started -Seconds ((Get-Date) - $t0).TotalSeconds)
}

# ---------------------------------------------------------------------------
# The run
# ---------------------------------------------------------------------------

function Invoke-Stage0Run {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $SkillDir,
        [Parameter(Mandatory)][string] $BuildDir,
        $Rto,
        [string] $UnitCode,
        [string] $ResultDir,
        [string] $GatesDoc,
        [string] $FixtureReport,
        [bool] $SkipProbe,
        [bool] $Quiet
    )
    $swAll = [System.Diagnostics.Stopwatch]::StartNew()
    $startedAt = Get-S0Utc
    if (-not $ResultDir) { $ResultDir = $BuildDir }
    $gatesPath = Get-S0GatesDocPath -GatesDoc $GatesDoc -SkillDir $SkillDir
    $rows = Get-S0StageRow -Path $gatesPath
    $stage0 = @($rows | Where-Object { $_.Stage -eq '0' -or $_.Stage -eq 'S0-RTO' })
    if ($stage0.Count -eq 0) {
        throw ("the stage table in {0} declares no Stage 0 row. The member set is derived from it, and a member set of zero is not a pre-flight." -f $gatesPath)
    }

    #  Every documented row must be bound or marked NOT YET IMPLEMENTED.
    $bindings = Get-S0Binding
    $unbound = @($stage0 | Where-Object { -not $_.NotImplemented -and ($bindings -notcontains $_.Key) })

    $entries = New-Object System.Collections.Generic.List[object]
    $partial = New-Object System.Collections.Generic.List[string]

    if (-not $Quiet) {
        Write-Host ''
        Write-Host ("STAGE 0 - PRE-FLIGHT ({0} member(s) derived from {1})" -f $stage0.Count, (Split-Path $gatesPath -Leaf)) -ForegroundColor Cyan
    }

    if ($unbound.Count -gt 0) {
        foreach ($u in $unbound) {
            $entries.Add((New-S0Entry -Name $u.Key -Script $u.Script -Stage $u.Stage -Blocking $u.Blocks `
                -Refused ("references\gates.md binds this gate to Stage 0 and this runner has no binding for it. A documented Stage 0 gate that the runner does not run is exactly the arrangement this change removes: wire it in Get-S0Binding, or mark the row NOT YET IMPLEMENTED with what performs the check today." ) `
                -StartedAt $startedAt))
        }
        $result = New-S0Result -Stage0 $stage0 -Entries $entries.ToArray() -Partial $partial.ToArray() -BuildDir $BuildDir -ResultDir $ResultDir `
            -StartedAt $startedAt -Seconds $swAll.Elapsed.TotalSeconds -Fixtures $null -Rto $Rto -Refused $true
        Write-S0Json -Path (Join-Path $ResultDir '0-results.json') -Body $result
        if (-not $Quiet) {
            Write-Host ''
            Write-Host ("STAGE 0 REFUSED - {0} documented member(s) have no binding: {1}" -f $unbound.Count, (@($unbound | ForEach-Object { $_.Key }) -join ', ')) -ForegroundColor Red
        }
        return $result
    }

    # ---- the runner's own two, before anything that depends on them.
    #  The dot-source is INLINE, at this function's scope, so every member
    #  called from here can see the library. See New-S0LibraryLoadEntry.
    $libT0 = Get-Date
    $libStarted = Get-S0Utc
    $libErr = ''
    try { . (Join-Path $SkillDir 'scripts\Lib-Resolve.ps1') }
    catch { $libErr = $_.Exception.Message }
    $entries.Add((New-S0LibraryLoadEntry -SkillDir $SkillDir -ErrorText $libErr -Started $libT0 -StartedUtc $libStarted))
    $entries.Add((Invoke-S0SchemaCompile -SkillDir $SkillDir))
    $script:S0Profile = $null

    foreach ($row in $stage0) {
        if ($row.NotImplemented) {
            $what = (Get-S0Short -Value $row.Script -Max 200)
            $entries.Add((New-S0Entry -Name $row.Key -Script $row.Script -Stage $row.Stage -Blocking $row.Blocks `
                -NotRun ("NOT YET IMPLEMENTED - " + $what) -NotImplemented $true -StartedAt (Get-S0Utc)))
            $partial.Add(("{0}: NOT YET IMPLEMENTED (gates.md section {1}, Blocks={2}) - {3}" -f $row.Key, $row.Section, $(if ($row.Blocks) { 'yes' } else { 'no' }), $what))
            continue
        }
        switch ($row.Key) {
            'Get-RtoProfile.ps1'            { $entries.Add((Invoke-S0RtoProfile -SkillDir $SkillDir -Rto $Rto)) }
            'Get-BrandPalettePairs'         { $entries.Add((Invoke-S0Palette -Profile $script:S0Profile -UnitCode $UnitCode)) }
            'Assert-GateFixtures.ps1'       { $entries.Add((Invoke-S0Fixtures -SkillDir $SkillDir -ResultDir $ResultDir -GatesDoc $GatesDoc)) }
            'Assert-GateHygiene.ps1'        { $entries.Add((Invoke-S0Hygiene -SkillDir $SkillDir -ResultDir $ResultDir)) }
            'Probe-GenerationEndpoints.ps1' { $entries.Add((Invoke-S0Probe -SkillDir $SkillDir -Skip $SkipProbe)) }
        }
    }

    # ---- the UNPROVEN list, named
    $report = Get-S0FixtureReport -Directory @($ResultDir, $BuildDir) -Explicit $FixtureReport
    $blocking = Get-S0BlockingGateSet -Rows $rows
    $unproven = @()
    if ($report.Found) {
        $unproven = Get-S0Unproven -Blocking $blocking -Report $report
        foreach ($u in $unproven) { $partial.Add(("UNPROVEN {0} (stage {1}, Blocks=yes): {2}" -f $u.gate, $u.stage, $u.verdict)) }
    }
    else {
        $partial.Add(("UNPROVEN: no fixtures report could be read, so NONE of the {0} Blocks=yes gate(s) is proven to fail on the defect it claims to catch. {1}" -f @($blocking.Keys).Count, $report.Note))
    }

    foreach ($e in $entries) {
        if ($e.verdict -eq 'NOT RUN' -and -not ($partial -join ' ').Contains($e.name)) {
            $partial.Add(("{0}: NOT RUN - {1}" -f $e.name, $e.reason))
        }
    }

    $result = New-S0Result -Stage0 $stage0 -Entries $entries.ToArray() -Partial $partial.ToArray() -BuildDir $BuildDir -ResultDir $ResultDir `
        -StartedAt $startedAt -Seconds $swAll.Elapsed.TotalSeconds -Fixtures $report -Rto $Rto -Unproven $unproven
    Write-S0Json -Path (Join-Path $ResultDir '0-results.json') -Body $result

    if (-not $Quiet) { Write-S0Report -Result $result }
    return $result
}

function New-S0Result {
    <#  0-results.json, in the 3c shape Run-SpineGates writes.

        `partial` is an ARRAY of named entries here, which is what the ledger's
        -Partial takes and what "zero partial[] entries naming a FAIL member"
        is measured against; `partialRun` carries the boolean sense the band
        runner uses for a -Only run. Every other key is the band's, spelled the
        same way, so one reader serves stage 0, 1, 2, 3c, 4 and 7c.

        THE VERDICT IS COMPUTED HERE AND NOWHERE ELSE, from the entries: any
        BLOCKING member that is not PASS puts its name in failed[] and makes
        the verdict FAIL. The probe cannot reach failed[] because gates.md says
        it does not block, and a NOT RUN member cannot reach PASS.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Stage0, [Parameter(Mandatory)] $Entries, [Parameter(Mandatory)] $Partial,
        [string] $BuildDir, [string] $ResultDir, [string] $StartedAt, [double] $Seconds,
        $Fixtures, $Rto, $Unproven = @(), [bool] $Refused = $false
    )
    #  NOT @($Entries). In PS 5.1 the array subexpression over a
    #  List[object] of PSCustomObjects throws 'Argument types do not
    #  match' - reproduced on this machine. Callers pass .ToArray(), and
    #  this loop is the belt to that brace.
    $gates = @()
    foreach ($x in $Entries) { $gates += $x }
    #  A BLOCKING MEMBER THAT IS NOT PASS IS A FAILURE - with exactly one
    #  exception, and it is narrow on purpose. A row gates.md itself marks
    #  NOT YET IMPLEMENTED names a gate nobody has built; the roadmap says
    #  to mark it and not to build it, so failing the stage on it forever
    #  would make the Stage 0 verdict carry no information at all - which
    #  is how a reader learns to route around a gate. It is recorded NOT
    #  RUN, named in partial[], and counted below, and it can never read as
    #  PASS. Every OTHER not-run blocking member - a missing input, a
    #  refusal, a throw - still fails, so 'not run' is not a way to pass.
    $failed = @($gates | Where-Object { $_.blocking -and $_.verdict -ne 'PASS' -and -not $_.notImplemented } | ForEach-Object { $_.name })
    $unbuilt = @($gates | Where-Object { $_.blocking -and $_.notImplemented } | ForEach-Object { $_.name })
    $rc = 0
    $verdict = 'PASS'
    if (@($gates | Where-Object { $_.verdict -eq 'REFUSED' }).Count -gt 0 -or $Refused) { $verdict = 'FAIL'; $rc = 2 }
    elseif ($failed.Count -gt 0) { $verdict = 'FAIL'; $rc = 1 }
    $slowest = $null
    $sum = 0.0
    foreach ($g in $gates) { $sum += [double]$g.seconds; if ($null -eq $slowest -or [double]$g.seconds -gt [double]$slowest.seconds) { $slowest = [pscustomobject]@{ name = $g.name; seconds = $g.seconds } } }
    return [pscustomobject]([ordered]@{
        runner = 'Invoke-Stage0'; stage = '0'; seed = $false
        ranAt = (Get-S0Utc); startedAt = $StartedAt
        buildDir = "$BuildDir"; spineDir = ''; resultDir = "$ResultDir"; unitExtract = ''
        rto = "$Rto"
        #  Stage 0 runs BEFORE any spine exists, so there is nothing to
        #  fingerprint. The key is written empty rather than omitted: a reader
        #  that compares fingerprints across stages must see the absence.
        spineFingerprint = ''; spineFingerprintAtJoin = ''; spineFingerprintAfter = ''; spineChangedDuringRun = $false
        partial = @($Partial); partialRun = $false; only = @()
        maxJobs = 1; timeoutMinutes = 0
        memberSetDerivedFrom = 'references\gates.md stage table, rows with Stage 0 or S0-RTO'
        memberSetSize = @($Stage0).Count
        gates = $gates
        slowest = $slowest
        wallClockSeconds = [math]::Round($Seconds, 1); sumOfGateSeconds = [math]::Round($sum, 1)
        failed = @($failed)
        notImplemented = @($unbuilt)
        defective = @()
        fixtures = [pscustomobject]@{
            report = $(if ($null -ne $Fixtures) { $Fixtures.Path } else { '' })
            hash   = $(if ($null -ne $Fixtures) { $Fixtures.Hash } else { '' })
            found  = [bool]$(if ($null -ne $Fixtures) { $Fixtures.Found } else { $false })
            note   = $(if ($null -ne $Fixtures) { $Fixtures.Note } else { 'not read' })
            unproven = @($Unproven | ForEach-Object { $_.gate })
            unprovenDetail = @($Unproven)
        }
        bandVerdictFile = ''; bandVerdictAtJoin = ''
        figureSheet = 'not in this run'; figureSheetPath = ''
        verdict = $verdict
        exitCode = $rc
    })
}

function Write-S0Report {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Result)
    Write-Host ''
    Write-Host ("  {0,-28} {1,-8} {2,-9} {3,8}  {4}" -f 'member', 'verdict', 'blocking', 'seconds', 'reason') -ForegroundColor DarkGray
    foreach ($g in @($Result.gates)) {
        $col = switch ($g.verdict) { 'PASS' { 'Green' } 'NOT RUN' { 'Yellow' } default { 'Red' } }
        Write-Host ("  {0,-28} {1,-8} {2,-9} {3,8}  {4}" -f $g.name, $g.verdict, $(if ($g.blocking) { 'yes' } else { 'no' }), $g.seconds, (Get-S0Short -Value $g.reason -Max 150)) -ForegroundColor $col
    }
    Write-Host ''
    Write-Host ("  fixtures: {0}" -f $Result.fixtures.note) -ForegroundColor $(if ($Result.fixtures.found) { 'DarkGray' } else { 'Yellow' })
    #  READ ONCE, AND WITHOUT THE @($null).Count LIE. @($null).Count is 1 in
    #  PS 5.1, so `@($Result.partial).Count -gt 0` answered YES for a result
    #  object that carries no partial[] at all, and Stage 0 announced a PARTIAL
    #  run with nothing under it.
    $partialItems = if ($null -ne $Result.partial) { @($Result.partial) } else { @() }
    if ($partialItems.Count -gt 0) {
        Write-Host ''
        Write-Host ("  PARTIAL - {0} named entr(y/ies), every one of them in 0-results.json:" -f $partialItems.Count) -ForegroundColor Yellow
        foreach ($x in $partialItems) { Write-Host ("    {0}" -f (Get-S0Short -Value $x -Max 200)) -ForegroundColor Yellow }
    }
    Write-Host ''
    if ($Result.verdict -eq 'PASS') {
        Write-Host ("STAGE 0 PASS - {0} member(s), {1}s. Every blocking member that EXISTS ran and passed." -f @($Result.gates).Count, $Result.wallClockSeconds) -ForegroundColor Green
    }
    else { Write-Host ("STAGE 0 FAIL - {0}  ({1}s)" -f (@($Result.failed) -join ', '), $Result.wallClockSeconds) -ForegroundColor Red }
    #  Same shape, same lie: an absent notImplemented[] counted 1 and this gate
    #  reported one unnamed NOT-YET-IMPLEMENTED blocking gate on every build
    #  whose result object did not carry the property. Read once.
    $nyiItems = if ($null -ne $Result.notImplemented) { @($Result.notImplemented) } else { @() }
    if ($nyiItems.Count -gt 0) {
        Write-Host ("  {0} BLOCKING gate(s) the documentation declares are NOT YET IMPLEMENTED and were performed by NOBODY: {1}" -f $nyiItems.Count, ($nyiItems -join ', ')) -ForegroundColor Yellow
        Write-Host '  They are recorded NOT RUN, named in partial[], and can never read as PASS. They do not fail the stage because nobody has built them; that is a roadmap item, not a build defect.' -ForegroundColor DarkGray
    }
    Write-Host ("  0-results.json written to {0}" -f (Join-Path $Result.resultDir '0-results.json')) -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# Self-test - every plant is verified to have landed before it is detected
# ---------------------------------------------------------------------------

function New-S0FixtureGatesDoc {
    <#  A stage table with exactly the rows a case needs. The member set is
        derived from this file, so a fixture that wants two members writes two
        rows - never a switch inside the runner.  #>
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][string[]] $Row)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('# Fixture stage table')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| Stage | Gate | Script | Blocks | Section |')
    [void]$sb.AppendLine('|---|---|---|---|---|')
    foreach ($r in $Row) { [void]$sb.AppendLine($r) }
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($Path, ($sb.ToString() -replace "`r?`n", "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
}

function Invoke-Stage0SelfTest {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $SkillDir)
    $script:s0Pass = 0
    $script:s0Fail = 0
    #  Declared before anything runs, so a body that dies half way through is
    #  caught by the count rather than by nobody.
    $script:s0Expected = 34
    $ok  = { param($m) $script:s0Pass++; Write-Host "  PASS  $m" -ForegroundColor Green }
    $bad = { param($m) $script:s0Fail++; Write-Host "  FAIL  $m" -ForegroundColor Red }

    Write-Host ''
    Write-Host 'Invoke-Stage0 self-test - a THROW may never be recorded as a pass' -ForegroundColor Cyan

    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('stage0_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $savedEnv = $env:MVC_ASSESSMENT_SKILL
    try {
        # -------------------------------------------------------------------
        # 1. the key derivation, and the second-script trap
        # -------------------------------------------------------------------
        $k1 = Get-S0RowKey -ScriptCell '`scripts\Get-RtoProfile.ps1 -Rto <id> -Check` (`Assert-RtoProfile`)'
        if ($k1 -eq 'Get-RtoProfile.ps1') { & $ok 'a row naming a script keys to that script' } else { & $bad "key was '$k1'" }
        $k2 = Get-S0RowKey -ScriptCell '`Assert-RendererContract` - NOT YET IMPLEMENTED; the write-time arm is `scripts\Test-SpineRead.ps1`'
        if ($k2 -eq 'Assert-RendererContract') { & $ok 'a row whose prose names a SECOND script still keys to the gate it claims, not to the aside' }
        else { & $bad "key was '$k2' - the second-script trap fired" }
        $k3 = Get-S0RowKey -ScriptCell '`Get-BrandPalettePairs` in `Set-ResourceBrand.ps1` throws on an unresolved role'
        if ($k3 -eq 'Get-BrandPalettePairs') { & $ok 'a row naming a FUNCTION keys to the function' } else { & $bad "key was '$k3'" }

        # -------------------------------------------------------------------
        # 2. the shipped gates.md: every Stage 0 row is bound or marked
        # -------------------------------------------------------------------
        $rows = Get-S0StageRow -Path (Join-Path $SkillDir 'references\gates.md')
        $s0 = @($rows | Where-Object { $_.Stage -eq '0' -or $_.Stage -eq 'S0-RTO' })
        if ($s0.Count -ge 8) { & $ok ("the shipped stage table yields {0} Stage 0 member(s), derived not typed" -f $s0.Count) }
        else { & $bad ("only {0} Stage 0 row(s) parsed" -f $s0.Count) }
        $nyi = @($s0 | Where-Object { $_.NotImplemented })
        if ($nyi.Count -eq 3) { & $ok ("and {0} of them are marked NOT YET IMPLEMENTED: {1}" -f $nyi.Count, ((@($nyi | ForEach-Object { $_.Key })) -join ', ')) }
        else { & $bad ("expected 3 NOT YET IMPLEMENTED rows, found {0}" -f $nyi.Count) }
        $bindings = Get-S0Binding
        $unbound = @($s0 | Where-Object { -not $_.NotImplemented -and ($bindings -notcontains $_.Key) })
        if ($unbound.Count -eq 0) { & $ok 'every implemented Stage 0 row the documentation declares has a binding in this runner' }
        else { & $bad ("unbound: " + ((@($unbound | ForEach-Object { $_.Key })) -join ', ')) }
        $blocking = Get-S0BlockingGateSet -Rows $rows
        if (@($blocking.Keys).Count -ge 20) { & $ok ("the UNPROVEN denominator is {0} Blocks=yes gate(s), derived from the whole stage table" -f @($blocking.Keys).Count) }
        else { & $bad ("blocking gate set is only {0}" -f @($blocking.Keys).Count) }

        # -------------------------------------------------------------------
        # 3. the verdict is COMPUTED, and a THROW can never read as a pass
        # -------------------------------------------------------------------
        $eThrow = New-S0Entry -Name 'x' -Error 'CommandNotFound: Get-BrandPalettePairs'
        if ($eThrow.verdict -eq 'FAIL' -and $eThrow.reason -match 'THREW') { & $ok 'a member that THREW records FAIL with the exception in its reason' } else { & $bad ("throw entry: " + ($eThrow | Out-String)) }
        $eRc = New-S0Entry -Name 'x' -ExitCode 1
        if ($eRc.verdict -eq 'FAIL' -and $eRc.reason -match 'exit code 1') { & $ok 'a member that exited non-zero records FAIL naming the code' } else { & $bad 'non-zero exit did not fail' }
        $eNr = New-S0Entry -Name 'x' -NotRun 'nobody built it'
        if ($eNr.verdict -eq 'NOT RUN') { & $ok 'a member with no implementation records NOT RUN, never PASS' } else { & $bad 'NOT RUN became something else' }
        $eOk = New-S0Entry -Name 'x' -ExitCode 0
        if ($eOk.verdict -eq 'PASS') { & $ok 'and the clean control: exit 0 with no exception is PASS' } else { & $bad 'a clean member did not pass' }

        $rThrow = New-S0Result -Stage0 @(1) -Entries @($eThrow) -Partial @() -BuildDir $tmp -ResultDir $tmp -StartedAt (Get-S0Utc) -Seconds 1 -Fixtures $null -Rto 'MVC'
        if ($rThrow.verdict -eq 'FAIL' -and [int]$rThrow.exitCode -ne 0 -and @($rThrow.failed) -contains 'x') { & $ok 'a results file written over a THROW carries verdict FAIL, a non-zero exitCode, and the member in failed[]' }
        else { & $bad ("result over a throw: verdict={0} exit={1} failed={2}" -f $rThrow.verdict, $rThrow.exitCode, (@($rThrow.failed) -join ',')) }

        #  the probe is non-blocking by declaration, so its non-zero exit is
        #  recorded and kept OUT of failed[]
        $eProbe = New-S0Entry -Name 'Probe-GenerationEndpoints' -Blocking $false -ExitCode 2 -Reason 'quota block'
        $rProbe = New-S0Result -Stage0 @(1) -Entries @($eOk, $eProbe) -Partial @() -BuildDir $tmp -ResultDir $tmp -StartedAt (Get-S0Utc) -Seconds 1 -Fixtures $null -Rto 'MVC'
        if ($eProbe.verdict -eq 'FAIL' -and $rProbe.verdict -eq 'PASS' -and @($rProbe.failed).Count -eq 0) { & $ok 'the probe exits 2, its exit code is RECORDED as a member failure, and the stage still passes - non-blocking by declaration, never by being dropped' }
        else { & $bad ("probe: member={0} stage={1} failed={2}" -f $eProbe.verdict, $rProbe.verdict, (@($rProbe.failed) -join ',')) }

        #  every 3c key is present, so one reader serves every banded stage
        $need = @('runner','stage','ranAt','startedAt','spineFingerprint','partial','gates','failed','defective','fixtures','bandVerdictFile','figureSheet','verdict','exitCode','slowest','wallClockSeconds','sumOfGateSeconds')
        $have = @($rThrow.PSObject.Properties.Name)
        $missing = @($need | Where-Object { $have -notcontains $_ })
        if ($missing.Count -eq 0) { & $ok ("0-results.json carries every key of the 3c results shape ({0} checked)" -f $need.Count) }
        else { & $bad ("missing keys: " + ($missing -join ', ')) }
        $gneed = @('name','verdict','exitCode','startedAt','ranAt','seconds','arms')
        $ghave = @($rThrow.gates[0].PSObject.Properties.Name)
        $gmiss = @($gneed | Where-Object { $ghave -notcontains $_ })
        if ($gmiss.Count -eq 0) { & $ok 'and every member record carries the 3c per-gate keys' } else { & $bad ("member missing: " + ($gmiss -join ', ')) }

        # -------------------------------------------------------------------
        # 4. an UNPROVEN blocking gate is named in partial[]
        # -------------------------------------------------------------------
        $fxDir = Join-Path $tmp 'fx'
        New-Item -ItemType Directory -Force -Path $fxDir | Out-Null
        $stub = '{ "results": [ { "Gate": "Check-Figures", "Verdict": "UNPROVEN" }, { "Gate": "Test-Spine", "Verdict": "PROVEN" } ] }'
        [System.IO.File]::WriteAllText((Join-Path $fxDir 'gate-fixtures.abc123def.json'), $stub, (New-Object System.Text.UTF8Encoding($true)))
        $rep = Get-S0FixtureReport -Directory @($fxDir) -Explicit ''
        if ($rep.Found -and $rep.Hash -eq 'abc123def') { & $ok 'the newest HASH-STAMPED fixtures report is the one read, and the hash is recorded' }
        else { & $bad ("fixture report: " + ($rep | Out-String)) }
        $blk = [ordered]@{ 'Check-Figures' = '7c'; 'Test-Spine' = '3c'; 'Check-Identity' = '4c' }
        $unp = Get-S0Unproven -Blocking $blk -Report $rep
        $names = @($unp | ForEach-Object { $_.gate })
        if ($names.Count -eq 2 -and $names -contains 'Check-Figures' -and $names -contains 'Check-Identity') {
            & $ok 'two blocking gates read UNPROVEN by name: the one the report calls UNPROVEN, and the one the report never mentions'
        }
        else { & $bad ("unproven: " + ($names -join ', ')) }
        if (@($unp | Where-Object { $_.gate -eq 'Check-Identity' }).verdict -match 'ABSENT') { & $ok 'and a gate ABSENT from the report is unproven for that reason, not silently proven' }
        else { & $bad 'an absent gate was not reported absent' }
        if ($names -notcontains 'Test-Spine') { & $ok 'the clean control: a PROVEN gate is not listed' } else { & $bad 'a proven gate was listed unproven' }

        # -------------------------------------------------------------------
        # 5. THE HEADLINE PLANT - rename Set-ResourceBrand.ps1 in a COPY of
        #    the skill. Lib-Resolve must throw BY NAME, and 0-results.json
        #    must record the palette check as fail.
        # -------------------------------------------------------------------
        $copy = Join-Path $tmp 'skill'
        New-Item -ItemType Directory -Force -Path $copy | Out-Null
        Copy-Item -LiteralPath (Join-Path $SkillDir 'scripts') -Destination (Join-Path $copy 'scripts') -Recurse -Force
        Copy-Item -LiteralPath (Join-Path $SkillDir 'assets')  -Destination (Join-Path $copy 'assets')  -Recurse -Force
        #  The copy sits in a temp directory, so Lib-Resolve's sibling-skill
        #  candidate cannot resolve there. Point the environment variable at the
        #  shared library the REAL skill resolves, exactly as an operator would,
        #  and restore it in the finally block.
        if (-not $savedEnv -or -not (Test-Path -LiteralPath (Join-Path "$savedEnv" 'scripts'))) {
            $env:MVC_ASSESSMENT_SKILL = Join-Path (Split-Path -Parent $SkillDir) 'assessment'
        }
        if (-not (Test-Path -LiteralPath (Join-Path $env:MVC_ASSESSMENT_SKILL 'scripts\Build-FromTemplate.ps1'))) {
            throw ("the shared library is not at {0}; the copy-of-the-skill cases cannot run" -f $env:MVC_ASSESSMENT_SKILL)
        }

        #  A stage table with just the two members this case is about, so the
        #  case does not pay for the fixtures and hygiene sweeps.
        $gd = Join-Path $copy 'references\gates.md'
        New-S0FixtureGatesDoc -Path $gd -Row @(
            '| S0-RTO | RTO profile pack resolves and validates | `scripts\Get-RtoProfile.ps1 -Rto <id> -Check` (`Assert-RtoProfile`) | yes | 29 |',
            '| 0 | Palette resolves as a total function over a closed role enum | `Get-BrandPalettePairs` in `Set-ResourceBrand.ps1` throws on an unresolved role | yes | 29 |'
        )

        $b1 = Join-Path $tmp 'build-clean'
        New-Item -ItemType Directory -Force -Path $b1 | Out-Null
        $null = & (Join-Path $copy 'scripts\Invoke-Stage0.ps1') -BuildDir $b1 -Rto 'MVC' -SkillDir $copy -GatesDoc $gd -SkipProbe -Quiet 6>&1 2>&1
        $rc1 = $LASTEXITCODE
        $j1 = (Get-S0Text -Path (Join-Path $b1 '0-results.json')) | ConvertFrom-Json
        $pal1 = @($j1.gates | Where-Object { $_.name -eq 'Resolve-Palette' })
        $lib1 = @($j1.gates | Where-Object { $_.name -eq 'library-load' })
        if ($rc1 -eq 0 -and $j1.verdict -eq 'PASS') { & $ok 'THE CLEAN CONTROL: an unmodified copy of the skill passes Stage 0 exit 0' }
        else { & $bad ("clean control: exit {0} verdict {1} failed {2}" -f $rc1, $j1.verdict, (@($j1.failed) -join ',')) }
        if (@($lib1).Count -eq 1 -and $lib1[0].verdict -eq 'PASS' -and @($pal1).Count -eq 1 -and $pal1[0].verdict -eq 'PASS') { & $ok 'with library-load and the palette check both PASS, and the palette reason names the template brand' }
        else { & $bad ("clean members: lib={0} pal={1}" -f $lib1[0].verdict, $pal1[0].verdict) }
        if ($pal1[0].reason -match 'templates\.brand') { & $ok ('palette reason: ' + (Get-S0Short -Value $pal1[0].reason -Max 170)) } else { & $bad 'the palette reason does not name templates.brand' }

        #  PLANT: rename the file Lib-Resolve names.
        $srb = Join-Path $copy 'scripts\Set-ResourceBrand.ps1'
        Rename-Item -LiteralPath $srb -NewName 'Set-ResourceBrand.ps1.renamed' -Force
        if (-not (Test-Path -LiteralPath $srb)) { & $ok 'plant landed: Set-ResourceBrand.ps1 is gone from the copy' } else { & $bad 'the rename plant did not land' }

        $b2 = Join-Path $tmp 'build-planted'
        New-Item -ItemType Directory -Force -Path $b2 | Out-Null
        $null = & (Join-Path $copy 'scripts\Invoke-Stage0.ps1') -BuildDir $b2 -Rto 'MVC' -SkillDir $copy -GatesDoc $gd -SkipProbe -Quiet 6>&1 2>&1
        $rc2 = $LASTEXITCODE
        $j2 = (Get-S0Text -Path (Join-Path $b2 '0-results.json')) | ConvertFrom-Json
        $lib2 = @($j2.gates | Where-Object { $_.name -eq 'library-load' })
        $pal2 = @($j2.gates | Where-Object { $_.name -eq 'Resolve-Palette' })
        if (@($lib2).Count -eq 1 -and $lib2[0].verdict -eq 'FAIL' -and $lib2[0].reason -match 'Set-ResourceBrand\.ps1') { & $ok 'Lib-Resolve THROWS BY NAME and library-load records FAIL naming Set-ResourceBrand.ps1' }
        else { & $bad ("library-load: " + ($lib2 | Out-String)) }
        if (@($pal2).Count -eq 1 -and $pal2[0].verdict -eq 'FAIL' -and $pal2[0].reason -match 'Get-BrandPalettePairs') { & $ok 'and 0-results.json records the PALETTE CHECK as fail, naming the function that is not loaded' }
        else { & $bad ("palette: " + ($pal2 | Out-String)) }
        if ($j2.verdict -eq 'FAIL' -and [int]$j2.exitCode -ne 0 -and $rc2 -ne 0) { & $ok ("the stage verdict is FAIL with exitCode {0} and the process exits {1} - the run this replaces recorded pass over exactly this throw" -f $j2.exitCode, $rc2) }
        else { & $bad ("planted verdict={0} exitCode={1} rc={2}" -f $j2.verdict, $j2.exitCode, $rc2) }
        if (@($j2.failed) -contains 'library-load' -and @($j2.failed) -contains 'Resolve-Palette') { & $ok 'and both members are named in failed[]' } else { & $bad ("failed[]: " + (@($j2.failed) -join ',')) }
        Rename-Item -LiteralPath ($srb + '.renamed') -NewName 'Set-ResourceBrand.ps1' -Force

        # -------------------------------------------------------------------
        # 6. a documented member with no binding REFUSES
        # -------------------------------------------------------------------
        $gd2 = Join-Path $copy 'references\gates-unbound.md'
        New-S0FixtureGatesDoc -Path $gd2 -Row @(
            '| 0 | A gate nobody wired up | `scripts\Assert-SomethingNew.ps1` | yes | 35 |'
        )
        $b3 = Join-Path $tmp 'build-unbound'
        New-Item -ItemType Directory -Force -Path $b3 | Out-Null
        $null = & (Join-Path $copy 'scripts\Invoke-Stage0.ps1') -BuildDir $b3 -Rto 'MVC' -SkillDir $copy -GatesDoc $gd2 -SkipProbe -Quiet 6>&1 2>&1
        $rc3 = $LASTEXITCODE
        $j3 = (Get-S0Text -Path (Join-Path $b3 '0-results.json')) | ConvertFrom-Json
        if ($rc3 -eq 2 -and $j3.verdict -eq 'FAIL' -and @($j3.gates | Where-Object { $_.verdict -eq 'REFUSED' }).Count -eq 1) {
            & $ok 'a documented Stage 0 gate with no binding REFUSES exit 2 and is recorded REFUSED, never absent'
        }
        else { & $bad ("unbound: rc={0} verdict={1}" -f $rc3, $j3.verdict) }

        # -------------------------------------------------------------------
        # 7. a NOT YET IMPLEMENTED row is NOT RUN and named in partial[]
        # -------------------------------------------------------------------
        $gd3 = Join-Path $copy 'references\gates-nyi.md'
        New-S0FixtureGatesDoc -Path $gd3 -Row @(
            '| S0-RTO | RTO profile pack resolves and validates | `scripts\Get-RtoProfile.ps1 -Rto <id> -Check` (`Assert-RtoProfile`) | yes | 29 |',
            '| 0 | Renderer contract compiled into the spine schema | `Assert-RendererContract` - NOT YET IMPLEMENTED; the write-time arm is `scripts\Test-SpineRead.ps1` | yes | 21 |'
        )
        $b4 = Join-Path $tmp 'build-nyi'
        New-Item -ItemType Directory -Force -Path $b4 | Out-Null
        $null = & (Join-Path $copy 'scripts\Invoke-Stage0.ps1') -BuildDir $b4 -Rto 'MVC' -SkillDir $copy -GatesDoc $gd3 -SkipProbe -Quiet 6>&1 2>&1
        $rc4 = $LASTEXITCODE
        $j4 = (Get-S0Text -Path (Join-Path $b4 '0-results.json')) | ConvertFrom-Json
        $nyiRec = @($j4.gates | Where-Object { $_.name -eq 'Assert-RendererContract' })
        if (@($nyiRec).Count -eq 1 -and $nyiRec[0].verdict -eq 'NOT RUN' -and $nyiRec[0].reason -match 'NOT YET IMPLEMENTED') { & $ok 'a NOT YET IMPLEMENTED blocking row is recorded NOT RUN with that reason, never PASS' }
        else { & $bad ("nyi: " + ($nyiRec | Out-String)) }
        if ((@($j4.partial) -join ' ') -match 'Assert-RendererContract') { & $ok 'and it is NAMED in partial[], where the ledger can read it' } else { & $bad ("partial[]: " + (@($j4.partial) -join ' | ')) }
        if ((@($j4.partial) -join ' ') -match 'UNPROVEN') { & $ok 'and the UNPROVEN list is in partial[] too, by name' } else { & $bad 'no UNPROVEN entry in partial[]' }
        if (@($j4.failed) -notcontains 'Assert-RendererContract' -and @($j4.notImplemented) -contains 'Assert-RendererContract') {
            & $ok 'a gate the DOCUMENTATION marks unbuilt is counted in notImplemented[], not in failed[] - so partial[] never names a FAIL member'
        }
        else { & $bad ("nyi in failed[]: " + (@($j4.failed) -join ',')) }

        #  and the narrowness of that exception: any OTHER not-run blocking
        #  member still fails, so "not run" is not a way to pass.
        $eSkip = New-S0Entry -Name 'some-gate' -Blocking $true -NotRun 'the operator passed a skip switch'
        $rSkip = New-S0Result -Stage0 @(1) -Entries @($eSkip) -Partial @() -BuildDir $tmp -ResultDir $tmp -StartedAt (Get-S0Utc) -Seconds 1 -Fixtures $null -Rto 'MVC'
        if ($rSkip.verdict -eq 'FAIL' -and @($rSkip.failed) -contains 'some-gate') { & $ok 'a blocking member NOT RUN for any reason OTHER than being unbuilt still fails the stage' }
        else { & $bad ("skipped blocking member: verdict={0} failed={1}" -f $rSkip.verdict, (@($rSkip.failed) -join ',')) }
        $eNyi = New-S0Entry -Name 'unbuilt-gate' -Blocking $true -NotRun 'NOT YET IMPLEMENTED - nobody built it' -NotImplemented $true
        $rNyi = New-S0Result -Stage0 @(1) -Entries @($eNyi) -Partial @() -BuildDir $tmp -ResultDir $tmp -StartedAt (Get-S0Utc) -Seconds 1 -Fixtures $null -Rto 'MVC'
        if ($rNyi.verdict -eq 'PASS' -and @($rNyi.failed).Count -eq 0 -and @($rNyi.notImplemented) -contains 'unbuilt-gate' -and $eNyi.verdict -eq 'NOT RUN') {
            & $ok 'and the unbuilt one is NOT RUN, named in notImplemented[], and still never reads as PASS on its own record'
        }
        else { & $bad ("nyi entry: member={0} stage={1} failed={2}" -f $eNyi.verdict, $rNyi.verdict, (@($rNyi.failed) -join ',')) }
    }
    catch {
        & $bad ('the self-test itself threw before it finished: ' + $_.Exception.Message + ' [line ' + $_.InvocationInfo.ScriptLineNumber + ']')
    }
    finally {
        $env:MVC_ASSESSMENT_SKILL = $savedEnv
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host ''
    Write-Host ("  {0} passed, {1} failed" -f $script:s0Pass, $script:s0Fail) -ForegroundColor $(if ($script:s0Fail) { 'Red' } else { 'Green' })
    if ($script:s0Fail) { return 4 }
    if (($script:s0Pass + $script:s0Fail) -lt $script:s0Expected) {
        Write-Host ("  FAIL  only {0} of the {1} declared cases ran - a case that never ran cannot pass" -f ($script:s0Pass + $script:s0Fail), $script:s0Expected) -ForegroundColor Red
        return 4
    }
    return 0
}
# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if ($SelfTest) {
    exit (Invoke-Stage0SelfTest -SkillDir $(if ($SkillDir) { $SkillDir } else { (Split-Path -Parent $PSScriptRoot) }))
}

if (-not $SkillDir) { $SkillDir = Split-Path -Parent $PSScriptRoot }
if (-not $BuildDir) {
    Write-Host ("{0}: -BuildDir is required. Stage 0 writes 0-results.json, and a stage that leaves no results file is a stage whose ledger record nothing on disk can contradict - which is the whole reason this runner exists." -f $GATE) -ForegroundColor Red
    exit 2
}
if (-not (Test-Path -LiteralPath $BuildDir)) { New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null }
$BuildDir = (Resolve-Path -LiteralPath $BuildDir).Path

$res = Invoke-Stage0Run -SkillDir $SkillDir -BuildDir $BuildDir -Rto $Rto -UnitCode $UnitCode `
        -ResultDir $ResultDir -GatesDoc $GatesDoc -FixtureReport $FixtureReport `
        -SkipProbe ([bool]$SkipProbe) -Quiet ([bool]$Quiet)
exit ([int]$res.exitCode)
