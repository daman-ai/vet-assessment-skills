<#
    Assert-FullRegateAfterMutation.ps1 - the WHOLE-SET assertion for Stage 7c.

    Implements section 33 of references\gates.md and SKILL.md's Stage 7c.
    Blocking.

    THE STANDING RULE. Any stage that changes what is on the page is followed
    by the COMPLETE gate set, never a subset. Placement is the last mutation of
    both artefacts, and on the build this was written from it was followed by
    EXACTLY ONE OF FIVE GATES - so the figure registry's variant-aware sweep
    never once ran against a document that actually contained figure rows.
    Run-Gates.ps1 -AfterArtwork runs the set; nothing until now proved that a
    7c run followed the LAST mutation. This is that proof.

    WHAT IT ASSERTS

      1  the last mutation of each artefact, taken from the FILESYSTEM and
         from the ledger's own render and placement classes - never from a
         sentence claiming the gates were re-run.
      2  every gate in the 7c set ran AFTER it, established from THE GATES'
         OWN RESULT FILES. A gate whose result predates the mutation is a FAIL
         naming the gate and BOTH timestamps. A gate with no result at all is
         a FAIL naming it - never a skip, because a stage that lists a gate
         nobody ran is the false green this pipeline was rebuilt against.
      3  caption-to-slot reconciliation: every spine visual slot has EXACTLY
         ONE caption in the rendered document, matched on the caption
         PARAGRAPH rather than any text run, counted PER NUMBER WITH NO
         DE-DUPLICATION before comparison. The caption checker this replaces
         de-duplicated its own list before comparing, which made its advertised
         duplicate-caption failure unreachable, in a script wired to no caller
         at all.

    THE 7c SET IS DERIVED, NEVER HAND-TYPED. A hand-listed check set is one of
    this project's recorded failure classes: a sweep that hand-listed three of
    nine palette hexes printed "no crossover" over 766 real hits. So the set is
    read from three sources and unioned:

      - the RUNNER'S OWN PLAN. Run-Gates.ps1 builds its invocation plan as
        data in New-GateInvocationPlan; this parses that function's AST and
        takes every gate it can invoke, including the band table it loops
        over. It executes nothing to do it.
      - the gate table in references\gates.md, every row whose stage is 7c.
      - the Stage 7c section of SKILL.md.

    A member the runner cannot invoke and that has no script and no function
    on disk is reported as SPECIFIED BUT NOT IMPLEMENTED, with the source that
    named it. It is not counted as "ran" and it is not counted as a pass; it is
    the honest half of gates.md's own rule that a rule nobody can execute must
    say so. Ordering is undefined for a gate that does not exist, so it is not
    a blocking finding here - Stage 0's fixtures gate owns that gap - but it is
    printed and recorded every run, so nobody can read this gate's PASS as a
    claim that the whole specified set ran.

    HOW A GATE'S RESULT IS FOUND, and every route is a derivation:
      - an entry for it in <build>\7c-results.json, in the shape
        Run-SpineGates already writes 3c-results.json (per-gate name, script,
        exit code, verdict). Its claimed time is CAPPED BY THE FILE'S OWN
        MTIME: the filesystem is the witness, so a claim cannot outrun it.
      - the same, from 3c-results.json, for the band members that re-run here.
      - the report path the gate's own source declares as its default.
      - the output the runner's plan declares that gate produces.
    Nothing is matched by name resemblance. A gate whose result cannot be
    located by one of those routes has no result, and this gate says so.

    Usage
      Assert-FullRegateAfterMutation.ps1 -BuildDir <dir> [-Guide <docx>] [-Deck <pptx>]
      Assert-FullRegateAfterMutation.ps1 -SelfTest      no build, no Office, no API

    PS 5.1. ASCII only in this file. UTF-8 BOM required on disk.
    Exit 0 pass; 1 a blocking finding; 2 a usage error or a refusal; 4 the
    self-test failed.
#>

[CmdletBinding()]
param(
    [string] $BuildDir,
    [string] $SkillDir,
    [string] $Guide,
    [string] $Deck,
    [string] $SpineDir,
    #  The per-gate results file a 7c run writes. Default <build>\7c-results.json.
    [string] $ResultsFile,
    [string] $OutPath,
    [switch] $SelfTest,
    [switch] $Quiet
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
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')
. (Join-Path $PSScriptRoot 'Stage-Ledger.ps1') -BuildDir $BuildDir
Add-Type -AssemblyName System.IO.Compression.FileSystem
#  ZipArchiveMode lives in the OTHER compression assembly and only the fixture
#  writer needs it - but a type missing there fails at run time with an error
#  pointing nowhere near its cause, so both are loaded here, once.
Add-Type -AssemblyName System.IO.Compression

$GATE = 'Assert-FullRegateAfterMutation'

# ---------------------------------------------------------------------------
# 0. Shared pieces, private to this gate
# ---------------------------------------------------------------------------

function AsArray {
    <# @($null).Count is 1, not 0. Every presence test goes through here. #>
    param($Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) { return @($Value) }
    if ($Value -is [System.Collections.IEnumerable]) { return @($Value | Where-Object { $null -ne $_ }) }
    return @($Value)
}

function ConvertTo-Utc {
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

function Format-Utc {
    param($Value)
    if ($null -eq $Value) { return '(never)' }
    return ([datetime]$Value).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}

function Get-SourceText {
    param([Parameter(Mandatory)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    return [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path, [System.Text.Encoding]::UTF8).TrimStart([char]0xFEFF)
}

function Write-Line {
    param([string] $Text, [string] $Colour = 'DarkGray')
    if (-not $Quiet) { Write-Host $Text -ForegroundColor $Colour }
}

# ---------------------------------------------------------------------------
# 1. Deriving the 7c set
# ---------------------------------------------------------------------------

function Get-AstLiteral {
    <# The literal behind one command element, or '' when it is not one. #>
    param($Element)
    if ($null -eq $Element) { return '' }
    if ($Element -is [System.Management.Automation.Language.StringConstantExpressionAst]) { return [string]$Element.Value }
    if ($Element -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) { return [string]$Element.Value }
    return ''
}

function Get-GateNameFromTitle {
    <#  The runner writes each gate's script into its own title -
        "GUIDE GATE (Test-GuideRules)". That is the runner naming the gate, not
        this file guessing at it.  #>
    param([string] $Title)
    $m = [regex]::Match([string]$Title, '\(([A-Za-z][A-Za-z0-9\-]*)\)\s*$')
    if ($m.Success) { return $m.Groups[1].Value }
    return ''
}

function Get-RunnerPlanMember {
    <#  Every gate Run-Gates.ps1 can invoke, read from the AST of its own
        invocation plan. Nothing is executed and nothing is copied: the plan is
        DATA in that script, and this reads the data.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $RunnerPath)

    $out = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $RunnerPath)) { return $out.ToArray() }

    $errs = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path -LiteralPath $RunnerPath).Path, [ref]$null, [ref]$errs)
    if ($null -eq $ast) { return $out.ToArray() }

    $fn = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'New-GateInvocationPlan' }, $true)
    if ($null -eq $fn) { return $out.ToArray() }

    #  Argument-hashtable variable -> the report path the runner puts in it,
    #  so a gate whose output path is decided by the RUNNER is still linked
    #  exactly rather than by resemblance.
    $argReport = @{}
    foreach ($m in [regex]::Matches($fn.Extent.Text, "\`$(\w+)\['(ReportPath|OutPath|ResultPath)'\]\s*=\s*\(?Join-Path\s+\`$In\.BuildDir\s+'([^']+)'")) {
        $argReport[$m.Groups[1].Value] = $m.Groups[3].Value
    }
    #  -Produces $In.<Var>, and $<var> = Join-Path $BuildDir '<file>' in the
    #  runner's own body: the file the runner declares that gate must write.
    $produced = @{}
    foreach ($m in [regex]::Matches($ast.Extent.Text, "\`$(\w+)\s*=\s*Join-Path\s+\`$BuildDir\s+'([^']+)'")) {
        $produced[$m.Groups[1].Value.ToLowerInvariant()] = $m.Groups[2].Value
    }

    foreach ($c in $fn.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)) {
        if ($c.GetCommandName() -ne 'Entry') { continue }
        $el = @($c.CommandElements)
        $name = ''; $title = ''; $script = ''; $argVar = ''; $prodVar = ''
        for ($i = 0; $i -lt $el.Count; $i++) {
            $p = $el[$i]
            if ($p -isnot [System.Management.Automation.Language.CommandParameterAst]) { continue }
            $next = $null
            if ($p.Argument) { $next = $p.Argument } elseif ($i + 1 -lt $el.Count) { $next = $el[$i + 1] }
            switch ($p.ParameterName) {
                'Name'     { $name = Get-AstLiteral $next }
                'Title'    { $title = Get-AstLiteral $next }
                'Script'   {
                    $lit = Get-AstLiteral $next
                    if (-not $lit -and $next) {
                        $sm = [regex]::Match($next.Extent.Text, "'([^']+\.ps1)'")
                        if ($sm.Success) { $lit = $sm.Groups[1].Value }
                    }
                    $script = $lit
                }
                'GateArgs' { if ($next -is [System.Management.Automation.Language.VariableExpressionAst]) { $argVar = $next.VariablePath.UserPath } }
                'Produces' { if ($next) { $pm = [regex]::Match($next.Extent.Text, '\$In\.(\w+)'); if ($pm.Success) { $prodVar = $pm.Groups[1].Value } } }
            }
        }
        if (-not $name) { continue }   # dynamic entries are recovered from the band table below
        $gateName = Get-GateNameFromTitle -Title $title
        if (-not $gateName -and $script) { $gateName = [System.IO.Path]::GetFileNameWithoutExtension($script) }
        if (-not $gateName) { $gateName = $name }
        $ev = New-Object System.Collections.Generic.List[string]
        if ($argVar -and $argReport.ContainsKey($argVar)) { $ev.Add($argReport[$argVar]) }
        if ($prodVar -and $produced.ContainsKey($prodVar.ToLowerInvariant())) { $ev.Add($produced[$prodVar.ToLowerInvariant()]) }
        $out.Add([pscustomobject]@{ Gate = $gateName; RunnerName = $name; Title = $title; Evidence = $ev.ToArray() })
    }

    #  The band the runner loops over: its names are the keys of a table
    #  literal, so the Entry call above sees a variable and not a name.
    foreach ($h in $fn.FindAll({ param($n) $n -is [System.Management.Automation.Language.HashtableAst] }, $true)) {
        foreach ($kv in $h.KeyValuePairs) {
            $key = Get-AstLiteral $kv.Item1
            if (-not $key) { continue }
            $body = $kv.Item2.Extent.Text
            if ($body -notmatch 'Title\s*=' -or $body -notmatch "\.ps1'") { continue }
            $sm = [regex]::Match($body, "'([^']+\.ps1)'")
            $tm = [regex]::Match($body, "Title\s*=\s*'([^']*)'")
            $gateName = Get-GateNameFromTitle -Title $(if ($tm.Success) { $tm.Groups[1].Value } else { '' })
            if (-not $gateName -and $sm.Success) { $gateName = [System.IO.Path]::GetFileNameWithoutExtension($sm.Groups[1].Value) }
            if (-not $gateName) { continue }
            $out.Add([pscustomobject]@{ Gate = $gateName; RunnerName = $key; Title = $(if ($tm.Success) { $tm.Groups[1].Value } else { $key }); Evidence = @() })
        }
    }

    return $out.ToArray()
}

function Get-DocumentedMember {
    <#  Every gate the DOCUMENTS put at 7c: the rows of the gate table whose
        stage cell is 7c, the body of gates.md section 33, and SKILL.md's
        Stage 7c section. Also returns the alias map the table declares, so
        "scripts\Check-Identity.ps1 (Assert-BrandCrossover)" is one member and
        not two.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $GatesMd, [Parameter(Mandatory)][string] $SkillMd)

    $members = New-Object System.Collections.Generic.List[object]
    $alias = @{}

    function Add-FromText {
        param([string] $Text, [string] $Source)
        foreach ($m in [regex]::Matches($Text, '(?i)scripts[\\/]([A-Za-z][A-Za-z0-9\-]*)\.ps1')) {
            $members.Add([pscustomobject]@{ Gate = $m.Groups[1].Value; Source = $Source })
        }
        foreach ($m in [regex]::Matches($Text, '`(Assert|Test|Check|New|Get)-([A-Za-z0-9]+)`')) {
            $members.Add([pscustomobject]@{ Gate = ($m.Groups[1].Value + '-' + $m.Groups[2].Value); Source = $Source })
        }
    }

    $gates = Get-SourceText -Path $GatesMd
    $skill = Get-SourceText -Path $SkillMd

    # --- the gate table, stage column = 7c
    foreach ($line in ($gates -split "\r?\n")) {
        if ($line -notmatch '^\s*\|') { continue }
        $cells = @($line -split '\|')
        if ($cells.Count -lt 5) { continue }
        #  THE ALIAS MAP IS READ FROM EVERY ROW, NOT ONLY THE 7c ONES. A design
        #  name and the script that implements it are paired once, wherever the
        #  table first pairs them - "scripts\Check-Identity.ps1
        #  (`Assert-BrandCrossover`)" is declared at 4c and used again at 7c.
        #  Scoping the alias map to one stage split that member in two and
        #  reported the implemented half as never run.
        foreach ($am in [regex]::Matches($cells[3], '(?i)scripts[\\/]([A-Za-z][A-Za-z0-9\-]*)\.ps1[^\(]*\(`?([A-Za-z][A-Za-z0-9\-]*)`?\)')) {
            $alias[$am.Groups[2].Value] = $am.Groups[1].Value
        }
        if ($cells[1].Trim() -ne '7c') { continue }
        Add-FromText -Text $cells[3] -Source 'gates.md gate table, stage 7c'
    }
    #  The same pairing written as prose rather than as a table cell:
    #  "`scripts\Check-Identity.ps1 -Path ...`** - `Assert-BrandCrossover`".
    foreach ($am in [regex]::Matches(($gates + "`n" + $skill), '(?i)scripts[\\/]([A-Za-z][A-Za-z0-9\-]*)\.ps1[^`\n]{0,120}`?\*{0,2}\s+-\s+`(Assert-[A-Za-z0-9]+)`')) {
        if (-not $alias.ContainsKey($am.Groups[2].Value)) { $alias[$am.Groups[2].Value] = $am.Groups[1].Value }
    }

    # --- section 33 of gates.md
    $sec = [regex]::Match($gates, '(?ms)^##\s*33\..*?(?=^##\s|\z)')
    if ($sec.Success) { Add-FromText -Text $sec.Value -Source 'gates.md section 33' }

    # --- Stage 7c of SKILL.md
    $st = [regex]::Match($skill, '(?ms)^##\s*Stage\s*7c\b.*?(?=^##\s|\z)')
    if ($st.Success) {
        Add-FromText -Text $st.Value -Source 'SKILL.md Stage 7c'
        foreach ($am in [regex]::Matches($st.Value, '(?i)scripts[\\/]([A-Za-z][A-Za-z0-9\-]*)\.ps1`?\*{0,2}\s*-\s*`?(Assert-[A-Za-z0-9]+)`?')) {
            $alias[$am.Groups[2].Value] = $am.Groups[1].Value
        }
    }

    return [pscustomobject]@{ Members = $members.ToArray(); Alias = $alias }
}

function Get-RegateGateSet {
    <#  The union, keyed on the gate's own name. Every member records which
        sources named it, whether anything on disk can run it, and where its
        result would be found.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $SkillDir, [Parameter(Mandatory)][string] $ScriptsDir)

    $runner = Join-Path $ScriptsDir 'Run-Gates.ps1'
    $planMembers = Get-RunnerPlanMember -RunnerPath $runner
    $doc = Get-DocumentedMember -GatesMd (Join-Path $SkillDir 'references\gates.md') -SkillMd (Join-Path $SkillDir 'SKILL.md')

    #  Neither the runner that runs the set nor this assertion is a member of
    #  the set. Nothing else is filtered.
    $notMembers = @('Run-Gates', 'Run-SpineGates', [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath))
    if (-not $notMembers[2]) { $notMembers[2] = 'Assert-FullRegateAfterMutation' }

    #  Every function this skill's scripts define, so "implemented" is decided
    #  the way gates.md words it: a file of that name, or a function of that
    #  name defined in a script here.
    $functions = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($f in (Get-ChildItem -LiteralPath $ScriptsDir -Filter '*.ps1' -File)) {
        foreach ($m in [regex]::Matches((Get-SourceText -Path $f.FullName), '(?im)^\s*function\s+([A-Za-z][A-Za-z0-9\-]*)')) {
            [void]$functions.Add($m.Groups[1].Value)
        }
    }

    $set = [ordered]@{}
    function Add-Member2 {
        param([string] $Gate, [string] $Source, [string] $RunnerName, [string[]] $Evidence)
        if (-not $Gate) { return }
        if ($doc.Alias.ContainsKey($Gate)) { $Gate = $doc.Alias[$Gate] }
        if ($notMembers -contains $Gate) { return }
        if (-not $set.Contains($Gate)) {
            $set[$Gate] = [pscustomobject]@{
                Gate = $Gate; Sources = (New-Object System.Collections.Generic.List[string])
                RunnerNames = (New-Object System.Collections.Generic.List[string])
                Evidence = (New-Object System.Collections.Generic.List[string])
                InRunnerPlan = $false
            }
        }
        if ($Source -and -not $set[$Gate].Sources.Contains($Source)) { $set[$Gate].Sources.Add($Source) }
        if ($RunnerName) {
            if (-not $set[$Gate].RunnerNames.Contains($RunnerName)) { $set[$Gate].RunnerNames.Add($RunnerName) }
            $set[$Gate].InRunnerPlan = $true
        }
        foreach ($e in (AsArray $Evidence)) { if (-not $set[$Gate].Evidence.Contains($e)) { $set[$Gate].Evidence.Add($e) } }
    }

    foreach ($p in $planMembers) { Add-Member2 -Gate $p.Gate -Source "Run-Gates.ps1 invocation plan" -RunnerName $p.RunnerName -Evidence $p.Evidence }
    foreach ($d in $doc.Members) { Add-Member2 -Gate $d.Gate -Source $d.Source -RunnerName '' -Evidence @() }

    #  The report path each member's own script declares as its default. One
    #  source of truth: the gate decides where it writes, and this reads it.
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($k in $set.Keys) {
        $m = $set[$k]
        $file = Join-Path $ScriptsDir ($k + '.ps1')
        $hasFile = Test-Path -LiteralPath $file
        if ($hasFile) {
            foreach ($rm in [regex]::Matches((Get-SourceText -Path $file), "\`$(ReportPath|OutPath|ResultPath)\s*=\s*Join-Path\s+\`$BuildDir\s+'([^']+)'")) {
                if (-not $m.Evidence.Contains($rm.Groups[2].Value)) { $m.Evidence.Add($rm.Groups[2].Value) }
            }
        }
        $out.Add([pscustomobject]@{
            Gate         = $k
            Sources      = $m.Sources.ToArray()
            RunnerNames  = $m.RunnerNames.ToArray()
            Evidence     = $m.Evidence.ToArray()
            InRunnerPlan = $m.InRunnerPlan
            Implemented  = ($m.InRunnerPlan -or $hasFile -or $functions.Contains($k))
            ScriptPath   = $(if ($hasFile) { $file } else { '' })
        })
    }
    return $out.ToArray()
}

# ---------------------------------------------------------------------------
# 2. The last mutation of each artefact
# ---------------------------------------------------------------------------

function Get-OutDirName {
    <# The render's output folder, read from the runner rather than typed. #>
    param([Parameter(Mandatory)][string] $ScriptsDir)
    $m = [regex]::Match((Get-SourceText -Path (Join-Path $ScriptsDir 'Run-Gates.ps1')), "\`$outDir\s*=\s*Join-Path\s+\`$BuildDir\s+'([^']+)'")
    if ($m.Success) { return [pscustomobject]@{ Name = $m.Groups[1].Value; From = 'Run-Gates.ps1' } }
    return [pscustomobject]@{ Name = 'out'; From = 'NOT DERIVABLE from the runner - falling back to the documented folder name' }
}

function Get-MutationState {
    <#  What the page last became, per artefact.

        THE FILESYSTEM IS THE WITNESS. The ledger was the thing that lied on
        the build these rules come from, so a ledger record can only RAISE the
        bar, never lower it: the mutation time is the later of the file's own
        mtime and the newest record of a stage that mutates.

        THE MUTATING STAGES ARE DERIVED FROM THE LEDGER'S OWN CONSTANTS, and
        the re-gate stages are removed from them. 7c appears in the ledger's
        placement class because it is held stale by a placement; treating it
        as a mutation would demand that the 7c gates postdate the record
        written after they finished, and an unsatisfiable blocking rule is how
        a check gets waived.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $BuildDir, [Parameter(Mandatory)][string[]] $Artefact)

    $mutStages = @()
    foreach ($s in (@(AsArray $script:LedgerRenders) + @(AsArray $script:LedgerPlacements))) {
        if ((AsArray $script:LedgerStaleAfterPlacement) -contains $s) { continue }
        if ($mutStages -notcontains $s) { $mutStages += $s }
    }

    $records = @()
    $lp = Get-LedgerPath -BuildDir $BuildDir
    if (Test-Path -LiteralPath $lp) {
        $j = Get-GateJson -Path $lp
        if ($null -ne $j) { $records = AsArray $j.records }
    }
    $newestMut = $null; $newestMutStage = ''
    foreach ($r in $records) {
        if ($mutStages -notcontains [string]$r.stage) { continue }
        $u = ConvertTo-Utc $r.utc
        if ($null -eq $u) { continue }
        if ($null -eq $newestMut -or $u -gt $newestMut) { $newestMut = $u; $newestMutStage = ("stage {0} round {1}" -f $r.stage, $r.round) }
    }

    $arts = New-Object System.Collections.Generic.List[object]
    foreach ($a in $Artefact) {
        if (-not (Test-Path -LiteralPath $a)) { continue }
        $fi = Get-Item -LiteralPath $a
        $at = $fi.LastWriteTimeUtc
        $src = 'the file itself'
        if ($null -ne $newestMut -and $newestMut -gt $at) { $at = $newestMut; $src = ("the ledger's " + $newestMutStage) }
        $arts.Add([pscustomobject]@{ Name = $fi.Name; Path = $fi.FullName; FileUtc = $fi.LastWriteTimeUtc; MutatedUtc = $at; From = $src })
    }

    $bar = $null; $barBy = ''
    foreach ($a in $arts.ToArray()) {
        if ($null -eq $bar -or $a.MutatedUtc -gt $bar) { $bar = $a.MutatedUtc; $barBy = ("{0} ({1})" -f $a.Name, $a.From) }
    }

    #  Inputs that are not the page, reported as context. A spine newer than
    #  the artefact is Assert-Staleness's finding at Stage 8, not this gate's,
    #  but a gate that ran before it read a spine the document no longer
    #  renders, and a reader is entitled to see that here.
    $inputNewest = $null; $inputBy = ''
    $sd = Join-Path $BuildDir 'spine'
    if (Test-Path -LiteralPath $sd) {
        foreach ($f in (Get-ChildItem -LiteralPath $sd -Filter '*.json' -File)) {
            if ($null -eq $inputNewest -or $f.LastWriteTimeUtc -gt $inputNewest) { $inputNewest = $f.LastWriteTimeUtc; $inputBy = ('spine\' + $f.Name) }
        }
    }
    $reg = Join-Path $BuildDir 'figures.json'
    if (Test-Path -LiteralPath $reg) {
        $rm = (Get-Item -LiteralPath $reg).LastWriteTimeUtc
        if ($null -eq $inputNewest -or $rm -gt $inputNewest) { $inputNewest = $rm; $inputBy = 'figures.json' }
    }

    return [pscustomobject]@{
        Artefacts = $arts.ToArray(); Bar = $bar; BarBy = $barBy
        MutatingStages = $mutStages; LedgerNewest = $newestMut; LedgerNewestStage = $newestMutStage
        InputNewest = $inputNewest; InputNewestBy = $inputBy
    }
}

# ---------------------------------------------------------------------------
# 3. Each gate's own result
# ---------------------------------------------------------------------------

function Get-ResultIndex {
    <#  Per-gate entries out of every results file this build carries, in the
        shape Run-SpineGates writes. A claimed time is capped by the file's own
        mtime, because a results file cannot have recorded a run that had not
        happened when it was written.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $BuildDir, [string] $ResultsFile)

    $index = New-Object System.Collections.Generic.List[object]
    $files = New-Object System.Collections.Generic.List[string]
    if ($ResultsFile) { $files.Add($ResultsFile) }
    else { $files.Add((Join-Path $BuildDir '7c-results.json')) }
    $files.Add((Join-Path $BuildDir '3c-results.json'))

    foreach ($p in $files.ToArray()) {
        if (-not (Test-Path -LiteralPath $p)) { continue }
        $j = Get-GateJson -Path $p
        if ($null -eq $j) { continue }
        $fi = Get-Item -LiteralPath $p
        $fileRan = ConvertTo-Utc (Get-GateProp -Object $j -Names @('ranAt', 'ranAtUtc', 'utc'))
        if ($null -eq $fileRan -or $fileRan -gt $fi.LastWriteTimeUtc) { $fileRan = $fi.LastWriteTimeUtc }
        foreach ($g in (AsArray $j.gates)) {
            $name = [string](Get-GateProp -Object $g -Names @('name'))
            $scriptPath = [string](Get-GateProp -Object $g -Names @('script'))
            $ran = ConvertTo-Utc (Get-GateProp -Object $g -Names @('ranAt', 'ranAtUtc', 'utc', 'finishedAt'))
            if ($null -eq $ran) { $ran = $fileRan }
            if ($ran -gt $fi.LastWriteTimeUtc) { $ran = $fi.LastWriteTimeUtc }
            $index.Add([pscustomobject]@{
                Name = $name
                Script = $(if ($scriptPath) { [System.IO.Path]::GetFileNameWithoutExtension($scriptPath) } else { '' })
                Ran = $ran
                Verdict = [string](Get-GateProp -Object $g -Names @('verdict'))
                ExitCode = (Get-GateProp -Object $g -Names @('exitCode'))
                Refused = (Get-GateProp -Object $g -Names @('refused'))
                From = $fi.Name
            })
        }
    }
    return $index.ToArray()
}

function Resolve-GateEvidence {
    <#  Where this gate's result is, and when it was written. Returns every
        route that produced something, newest first, and nothing at all when
        no route did.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Member,
        [Parameter(Mandatory)][string] $BuildDir,
        [Parameter(Mandatory)] $ResultIndex
    )
    $found = New-Object System.Collections.Generic.List[object]

    foreach ($e in $ResultIndex) {
        $match = $false
        if ($e.Script -and $e.Script -ieq $Member.Gate) { $match = $true }
        elseif ($e.Name -and $e.Name -ieq $Member.Gate) { $match = $true }
        elseif ($e.Name -and (@($Member.RunnerNames) -contains $e.Name)) { $match = $true }
        if (-not $match) { continue }
        $found.Add([pscustomobject]@{
            Route = ("per-gate entry in " + $e.From); Ran = $e.Ran
            Detail = ("verdict {0}, exit {1}{2}" -f $(if ($e.Verdict) { $e.Verdict } else { '(none)' }), $e.ExitCode, $(if ($e.Refused -eq $true) { ', REFUSED' } else { '' }))
            Refused = ($e.Refused -eq $true)
        })
    }

    foreach ($rel in (AsArray $Member.Evidence)) {
        $p = Join-Path $BuildDir $rel
        if (-not (Test-Path -LiteralPath $p)) { continue }
        $fi = Get-Item -LiteralPath $p
        $found.Add([pscustomobject]@{ Route = ("its own report file " + $rel); Ran = $fi.LastWriteTimeUtc; Detail = ("{0} bytes" -f $fi.Length); Refused = $false })
    }

    return @($found.ToArray() | Sort-Object Ran -Descending)
}

# ---------------------------------------------------------------------------
# 4. Caption-to-slot reconciliation
# ---------------------------------------------------------------------------

function Get-CaptionRule {
    <#  The caption discriminators come from the placement gate's own parameter
        defaults, so this reconciliation and Check-Figures cannot disagree
        about what a caption is.  #>
    param([Parameter(Mandatory)][string] $ScriptsDir)
    $src = Get-SourceText -Path (Join-Path $ScriptsDir 'Check-Figures.ps1')
    $prefix = ''; $styleRx = ''
    $pm = [regex]::Match($src, "\`$CaptionPrefix\s*=\s*'([^']*)'")
    if ($pm.Success) { $prefix = $pm.Groups[1].Value }
    $sm = [regex]::Match($src, "\`$CaptionStyleRx\s*=\s*'([^']*)'")
    if ($sm.Success) { $styleRx = $sm.Groups[1].Value }
    $from = 'Check-Figures.ps1 parameter defaults'
    if (-not $prefix) { $prefix = 'Figure'; $from = 'NOT DERIVABLE from the placement gate - falling back to the documented caption word' }
    if (-not $styleRx) { $styleRx = '(?i)caption' }
    return [pscustomobject]@{ Prefix = $prefix; StyleRx = $styleRx; From = $from }
}

function Get-DocumentPart {
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][string] $Match)
    $out = [ordered]@{}
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Path).Path)
    try {
        foreach ($e in $zip.Entries) {
            if ($e.FullName -notmatch $Match) { continue }
            $sr = New-Object System.IO.StreamReader($e.Open())
            $out[$e.FullName] = $sr.ReadToEnd()
            $sr.Dispose()
        }
    }
    finally { $zip.Dispose() }
    return $out
}

function Measure-Caption {
    <#  Captions PER NUMBER, with NO de-duplication before comparison, matched
        on the caption PARAGRAPH and not on any text run.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Xml, [Parameter(Mandatory)] $Rule)

    $capRx = '^\s*' + [regex]::Escape($Rule.Prefix) + '\s+(\d+(?:\.\d+)+)'
    $counts = @{}
    $byStyle = 0; $byCentre = 0; $byItalic = 0; $rejected = 0
    foreach ($pm in [regex]::Matches($Xml, '<w:p\b[^>]*>.*?</w:p>', 'Singleline')) {
        $p = $pm.Value
        $text = -join ([regex]::Matches($p, '<w:t[^>]*>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value })
        $text = [System.Net.WebUtility]::HtmlDecode($text)
        $m = [regex]::Match($text, $capRx)
        if (-not $m.Success) { continue }
        $style = [regex]::Match($p, '<w:pStyle w:val="([^"]*)"').Groups[1].Value
        $isCap = $false
        if ($style -and $style -match $Rule.StyleRx) { $isCap = $true; $byStyle++ }
        elseif ($p -match '<w:jc w:val="center"\s*/>') { $isCap = $true; $byCentre++ }
        elseif ($p -match '<w:i\s*/>' -and $text.Trim().StartsWith($Rule.Prefix)) { $isCap = $true; $byItalic++ }
        if (-not $isCap) { $rejected++; continue }
        $num = $m.Groups[1].Value
        if ($counts.ContainsKey($num)) { $counts[$num]++ } else { $counts[$num] = 1 }
    }
    return [pscustomobject]@{ Counts = $counts; ByStyle = $byStyle; ByCentre = $byCentre; ByItalic = $byItalic; Rejected = $rejected }
}

# ---------------------------------------------------------------------------
# 5. The gate, as a function, so the self-test drives the real thing
# ---------------------------------------------------------------------------

function Invoke-FullRegate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [Parameter(Mandatory)][string] $SkillDir,
        [Parameter(Mandatory)][string] $ScriptsDir,
        [string] $Guide,
        [string] $Deck,
        [string] $SpineDir,
        [string] $ResultsFile
    )

    $blocking = New-Object System.Collections.Generic.List[object]
    $warnings = New-Object System.Collections.Generic.List[object]
    $notes    = New-Object System.Collections.Generic.List[string]

    # ---- the artefacts
    $outInfo = Get-OutDirName -ScriptsDir $ScriptsDir
    $outDir = Join-Path $BuildDir $outInfo.Name
    $arts = New-Object System.Collections.Generic.List[string]
    foreach ($p in @($Guide, $Deck)) { if ($p) { $arts.Add((Resolve-Path -LiteralPath $p).Path) } }
    if ($arts.Count -eq 0 -and (Test-Path -LiteralPath $outDir)) {
        foreach ($f in (Get-ChildItem -LiteralPath $outDir -File | Where-Object { $_.Extension -in @('.docx', '.pptx') -and $_.Name -notlike '~$*' })) {
            $arts.Add($f.FullName)
        }
    }
    if ($arts.Count -eq 0) {
        return [pscustomobject]@{ Refused = ("no delivered artefact under {0}. A whole-set assertion with no artefact would pass by having nothing to date the gates against." -f $outDir) }
    }

    $mut = Get-MutationState -BuildDir $BuildDir -Artefact $arts.ToArray()
    if ($null -eq $mut.Bar) {
        return [pscustomobject]@{ Refused = 'the artefacts carry no readable modification time, so no mutation can be dated' }
    }

    # ---- the set, and each member's own result
    $set = Get-RegateGateSet -SkillDir $SkillDir -ScriptsDir $ScriptsDir
    if (@($set).Count -eq 0) {
        return [pscustomobject]@{ Refused = 'the 7c gate set derived to nothing. A check-set of zero passes by checking nothing, so this is a refusal and not a pass.' }
    }
    $index = Get-ResultIndex -BuildDir $BuildDir -ResultsFile $ResultsFile

    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($m in $set) {
        $ev = Resolve-GateEvidence -Member $m -BuildDir $BuildDir -ResultIndex $index
        $best = $null
        if (@($ev).Count -gt 0) { $best = @($ev)[0] }
        $status = ''
        if (-not $m.Implemented) { $status = 'not-implemented' }
        elseif ($null -eq $best) { $status = 'no-result' }
        elseif ($best.Refused) { $status = 'refused' }
        elseif ($best.Ran -le $mut.Bar) { $status = 'stale' }
        else { $status = 'ok' }

        $rows.Add([pscustomobject]@{
            Gate = $m.Gate; Status = $status; Ran = $(if ($best) { $best.Ran } else { $null })
            Route = $(if ($best) { $best.Route } else { '' }); Detail = $(if ($best) { $best.Detail } else { '' })
            Sources = $m.Sources; Implemented = $m.Implemented; Evidence = $m.Evidence
        })

        switch ($status) {
            'stale' {
                $blocking.Add([pscustomobject]@{
                    Arm = 'G'; What = ('a gate that ran BEFORE the last mutation: ' + $m.Gate)
                    Detail = ("{0} last produced a result at {1} ({2}); the last mutation of the delivery set was {3} ({4}). Any stage that changes what is on the page is followed by the COMPLETE gate set - this one gated the document as it was before placement." -f `
                                $m.Gate, (Format-Utc $best.Ran), $best.Route, (Format-Utc $mut.Bar), $mut.BarBy)
                })
            }
            'no-result' {
                $blocking.Add([pscustomobject]@{
                    Arm = 'H'; What = ('a gate with no result at all: ' + $m.Gate)
                    Detail = ("nothing on disk shows {0} ever ran: no entry for it in a results file and no report file of its own ({1}). That is a FAIL naming it, never a skip - a stage that lists a gate nobody ran is the false green this pipeline was rebuilt against. Named by: {2}. To satisfy it, the 7c run records this gate in 7c-results.json in the shape Run-SpineGates already writes 3c-results.json: name, script, exit code, verdict, ranAt." -f `
                                $m.Gate, $(if (@($m.Evidence).Count) { 'looked for ' + ((AsArray $m.Evidence) -join ', ') } else { 'it declares no report path of its own' }), ((AsArray $m.Sources) -join '; '))
                })
            }
            'refused' {
                $blocking.Add([pscustomobject]@{
                    Arm = 'H'; What = ('a gate that was refused: ' + $m.Gate)
                    Detail = ("{0}'s own result records it as refused ({1}). A refused gate is a failure, never a skip." -f $m.Gate, $best.Route)
                })
            }
            'not-implemented' {
                $notes.Add(("SPECIFIED BUT NOT IMPLEMENTED at 7c: {0} - named by {1}. Nothing on disk can run it, so nothing gated this at 7c. gates.md is the register of that gap; this gate's PASS is not a claim that it ran." -f $m.Gate, ((AsArray $m.Sources) -join '; ')))
            }
            default {
                if ($null -ne $mut.InputNewest -and $best.Ran -le $mut.InputNewest) {
                    $warnings.Add([pscustomobject]@{
                        Arm = 'I'; What = ('a gate older than its own inputs: ' + $m.Gate)
                        Detail = ("{0} ran {1}, after the last mutation of the page but before {2} changed at {3}. That is Assert-Staleness's finding at Stage 8, not this one's, and it is reported here because a gate that ran before its input read something the document no longer renders." -f `
                                    $m.Gate, (Format-Utc $best.Ran), $mut.InputNewestBy, (Format-Utc $mut.InputNewest))
                    })
                }
            }
        }
    }

    # ---- caption-to-slot reconciliation
    $rule = Get-CaptionRule -ScriptsDir $ScriptsDir
    $planned = @(Get-GateSpineVisuals -BuildDir $BuildDir -SpineDir $SpineDir |
                 Where-Object { $_.Caption -and $_.Slot } | ForEach-Object { [string]$_.Slot } | Sort-Object -Unique)
    $capResult = $null
    $guideArt = @($arts.ToArray() | Where-Object { $_ -match '(?i)\.docx$' })
    if ($guideArt.Count -eq 0) {
        $blocking.Add([pscustomobject]@{ Arm = 'J'; What = 'no document to reconcile captions against'; Detail = 'the delivery set carries no .docx, so caption-to-slot reconciliation could not run and this stage cannot pass on a reconciliation nobody performed' })
    }
    elseif ($planned.Count -eq 0) {
        $blocking.Add([pscustomobject]@{ Arm = 'J'; What = 'the spine plans no captioned slot'; Detail = 'the counts come from the spine, and the spine yielded none - so the reconciliation had nothing to check and cannot stand as one' })
    }
    else {
        $parts = Get-DocumentPart -Path $guideArt[0] -Match '(?i)^word/document\.xml$'
        $xml = ''
        foreach ($k in $parts.Keys) { $xml += $parts[$k] }
        $capResult = Measure-Caption -Xml $xml -Rule $rule
        $counts = $capResult.Counts
        $dupes = @($counts.Keys | Where-Object { $counts[$_] -gt 1 } | Sort-Object)
        foreach ($d in $dupes) {
            $blocking.Add([pscustomobject]@{
                Arm = 'J'; What = ('a figure number with more than one caption: ' + $d)
                Detail = ("{0} {1} carries {2} caption paragraphs. Counted PER NUMBER with no de-duplication, which is the fix: the checker this replaces de-duplicated its own list before comparing and made this failure unreachable." -f $rule.Prefix, $d, $counts[$d])
            })
        }
        $missing = @($planned | Where-Object { -not $counts.ContainsKey($_) })
        if ($missing.Count -gt 0) {
            $blocking.Add([pscustomobject]@{
                Arm = 'J'; What = 'planned slot(s) with no caption in the document'
                Detail = ("the spine plans {0} captioned slot(s); {1} of them carry no caption paragraph in the delivered document: {2}" -f $planned.Count, $missing.Count, ($missing -join ', '))
            })
        }
        $strays = @($counts.Keys | Where-Object { $planned -notcontains $_ } | Sort-Object)
        if ($strays.Count -gt 0) {
            $blocking.Add([pscustomobject]@{
                Arm = 'J'; What = 'caption(s) for slot(s) the spine does not plan'
                Detail = ("{0} caption number(s) in the document match no planned slot: {1}" -f $strays.Count, ($strays -join ', '))
            })
        }
    }

    return [pscustomobject]@{
        Refused = ''
        Blocking = $blocking.ToArray(); Warnings = $warnings.ToArray(); Notes = $notes.ToArray()
        Mutation = $mut; Rows = $rows.ToArray(); Set = $set
        Planned = $planned; Captions = $capResult; CaptionRule = $rule
        OutDirFrom = $outInfo.From; Artefacts = $arts.ToArray()
    }
}

# ---------------------------------------------------------------------------
# 6. Reporting
# ---------------------------------------------------------------------------

function Write-Report {
    param([Parameter(Mandatory)] $Result, [Parameter(Mandatory)][string] $Path, [string] $BuildDir)
    $counts = @{}
    if ($Result.Captions) { foreach ($k in $Result.Captions.Counts.Keys) { $counts[$k] = $Result.Captions.Counts[$k] } }
    $payload = [ordered]@{
        gate     = $GATE
        ranAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        buildDir = $BuildDir
        lastMutation = [ordered]@{
            barUtc = (Format-Utc $Result.Mutation.Bar); setBy = $Result.Mutation.BarBy
            mutatingStages = @($Result.Mutation.MutatingStages)
            ledgerNewest = (Format-Utc $Result.Mutation.LedgerNewest); ledgerNewestStage = $Result.Mutation.LedgerNewestStage
            newestInput = (Format-Utc $Result.Mutation.InputNewest); newestInputIs = $Result.Mutation.InputNewestBy
            artefacts = @($Result.Mutation.Artefacts | ForEach-Object { [ordered]@{ name = $_.Name; fileUtc = (Format-Utc $_.FileUtc); mutatedUtc = (Format-Utc $_.MutatedUtc); from = $_.From } })
        }
        gateSet = [ordered]@{
            size = @($Result.Set).Count
            derivedFrom = 'the AST of Run-Gates.ps1 New-GateInvocationPlan, the stage-7c rows of references\gates.md, and SKILL.md Stage 7c'
            members = @($Result.Rows | ForEach-Object {
                [ordered]@{ gate = $_.Gate; status = $_.Status; ranUtc = (Format-Utc $_.Ran); route = $_.Route
                            detail = $_.Detail; implemented = $_.Implemented; namedBy = @($_.Sources) }
            })
        }
        captions = [ordered]@{
            plannedSlots = @($Result.Planned)
            discriminator = $(if ($Result.CaptionRule) { $Result.CaptionRule.From } else { '' })
            perNumber = $counts
            matchedByStyle = $(if ($Result.Captions) { $Result.Captions.ByStyle } else { 0 })
            matchedByCentring = $(if ($Result.Captions) { $Result.Captions.ByCentre } else { 0 })
            matchedByItalic = $(if ($Result.Captions) { $Result.Captions.ByItalic } else { 0 })
            inProseReferencesNotCounted = $(if ($Result.Captions) { $Result.Captions.Rejected } else { 0 })
        }
        blocking = @($Result.Blocking | ForEach-Object { [ordered]@{ arm = $_.Arm; what = $_.What; detail = $_.Detail } })
        warnings = @($Result.Warnings | ForEach-Object { [ordered]@{ arm = $_.Arm; what = $_.What; detail = $_.Detail } })
        notes    = @($Result.Notes)
        verdict  = $(if (@($Result.Blocking).Count -eq 0) { 'PASS' } else { 'FAIL' })
    }
    [System.IO.File]::WriteAllText($Path, ($payload | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding($false)))
}

# ---------------------------------------------------------------------------
# 7. Self-test - every plant VERIFIED to have landed before the gate is run
# ---------------------------------------------------------------------------

function New-MinimalPackage {
    <#  A package with just the parts this gate reads. Nothing here is a
        document; it is the smallest thing the caption scan can be pointed at,
        so the self-test needs no Word and no template.  #>
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][hashtable] $Part)
    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Force }
    $zip = [System.IO.Compression.ZipFile]::Open($Path, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($k in $Part.Keys) {
            $e = $zip.CreateEntry($k)
            $sw = New-Object System.IO.StreamWriter($e.Open())
            $sw.Write([string]$Part[$k])
            $sw.Dispose()
        }
    }
    finally { $zip.Dispose() }
}

function New-CaptionParagraph {
    param([string] $Text, [switch] $Styled)
    if ($Styled) {
        return '<w:p><w:pPr><w:pStyle w:val="Caption"/></w:pPr><w:r><w:t>' + $Text + '</w:t></w:r></w:p>'
    }
    return '<w:p><w:r><w:t>' + $Text + '</w:t></w:r></w:p>'
}

function New-RegateFixture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Root,
        [Parameter(Mandatory)][string] $Case,
        [Parameter(Mandatory)] $GateSet,
        [Parameter(Mandatory)] $Rule
    )
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $build = Join-Path $Root $Case
    if (Test-Path -LiteralPath $build) { Remove-Item -LiteralPath $build -Recurse -Force }
    $null = New-Item -ItemType Directory -Path $build -Force
    $spine = Join-Path $build 'spine'
    $out = Join-Path $build 'out'
    $null = New-Item -ItemType Directory -Path $spine -Force
    $null = New-Item -ItemType Directory -Path $out -Force

    $t0 = (Get-Date).ToUniversalTime().AddHours(-3)      # the mutation
    $tGate = $t0.AddMinutes(10)                          # the 7c gate run
    $tStale = $t0.AddMinutes(-10)                        # a gate that ran too early

    # --- the spine plans one captioned slot
    $slot = '1.1.1'
    $spineJson = '{ "topic": 1, "visuals": [ { "slot": "' + $slot + '", "caption": "a planned caption", "kind": "diagram" } ] }'
    [System.IO.File]::WriteAllText((Join-Path $spine 't1_1.1.json'), $spineJson, $utf8)
    [System.IO.File]::WriteAllText((Join-Path $build 'figures.json'), '{ "figures": [] }', $utf8)

    # --- the document
    $caption = New-CaptionParagraph -Text ($Rule.Prefix + ' ' + $slot + ' - a planned caption') -Styled
    #  A cross-reference paragraph that OPENS with the caption words and the
    #  number, and carries no caption formatting. It is the boundary case the
    #  style scoping exists for: matched by the number pattern, rejected by the
    #  paragraph test. Without it the self-test would only prove the easy half.
    $prose = New-CaptionParagraph -Text ($Rule.Prefix + ' ' + $slot + ' is discussed in the paragraph above')
    $body = $caption + $prose
    if ($Case -eq 'caption-missing') { $body = $prose }
    if ($Case -eq 'caption-duplicate') { $body = $caption + $caption + $prose }
    $docXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="x"><w:body>' + $body + '</w:body></w:document>'

    $guide = Join-Path $out 'FIXTURE_Learner_Guide.docx'
    $deck  = Join-Path $out 'FIXTURE_Delivery_PowerPoint.pptx'
    New-MinimalPackage -Path $guide -Part @{ 'word/document.xml' = $docXml }
    New-MinimalPackage -Path $deck  -Part @{ 'ppt/slides/slide1.xml' = '<p:sld/>' }

    # --- a results file carrying an entry for every implemented member
    $gates = New-Object System.Collections.Generic.List[object]
    $implemented = @($GateSet | Where-Object { $_.Implemented })
    $skipGate = ''
    $staleGate = ''
    if ($Case -eq 'gate-missing') { $skipGate = $implemented[0].Gate }
    if ($Case -eq 'gate-stale')   { $staleGate = $implemented[0].Gate }
    foreach ($m in $implemented) {
        if ($m.Gate -eq $skipGate) { continue }
        $ran = $(if ($m.Gate -eq $staleGate) { $tStale } else { $tGate })
        $gates.Add([ordered]@{ name = $m.Gate; script = ($m.Gate + '.ps1'); exitCode = 0; verdict = 'PASS'; ranAt = $ran.ToString('o') })
    }
    $results = [ordered]@{ ranAt = $tGate.ToString('o'); buildDir = $build; gates = $gates.ToArray() }
    [System.IO.File]::WriteAllText((Join-Path $build '7c-results.json'), ($results | ConvertTo-Json -Depth 6), $utf8)

    # --- a ledger whose newest mutation is the placement
    $ledger = [ordered]@{
        unit = 'FIXTURE'; created = $t0.ToString('o')
        records = @(
            [ordered]@{ stage = '7'; name = 'remediate'; status = 'pass'; round = 1; findings = 0; utc = $t0.AddMinutes(-30).ToString('o') }
            [ordered]@{ stage = '7b'; name = 'place'; status = 'pass'; round = 1; findings = 0; utc = $t0.ToString('o') }
            [ordered]@{ stage = '7c'; name = 're-gate'; status = 'pass'; round = 1; findings = 0; utc = $tGate.ToString('o') }
        )
    }
    [System.IO.File]::WriteAllText((Join-Path $build 'stage-ledger.json'), ($ledger | ConvertTo-Json -Depth 6), $utf8)

    # --- times last: writing a file resets them
    (Get-Item -LiteralPath $guide).LastWriteTimeUtc = $t0
    (Get-Item -LiteralPath $deck).LastWriteTimeUtc = $t0
    (Get-Item -LiteralPath (Join-Path $spine 't1_1.1.json')).LastWriteTimeUtc = $t0.AddMinutes(-30)
    (Get-Item -LiteralPath (Join-Path $build 'figures.json')).LastWriteTimeUtc = $t0.AddMinutes(-30)
    (Get-Item -LiteralPath (Join-Path $build '7c-results.json')).LastWriteTimeUtc = $tGate.AddMinutes(1)

    return [pscustomobject]@{
        BuildDir = $build; Guide = $guide; Deck = $deck; Slot = $slot
        T0 = $t0; TGate = $tGate; TStale = $tStale; SkipGate = $skipGate; StaleGate = $staleGate
    }
}

function Invoke-SelfTest {
    [CmdletBinding()] param([Parameter(Mandatory)][string] $SkillDir, [Parameter(Mandatory)][string] $ScriptsDir)

    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("regate-selftest-" + [guid]::NewGuid().ToString('n').Substring(0, 8))
    $null = New-Item -ItemType Directory -Path $root -Force
    $script:sfChecks = 0
    $script:sfFail = 0

    function Check {
        param([string] $What, [bool] $Ok, [string] $Detail)
        $script:sfChecks++
        if ($Ok) { Write-Host ("    ok   {0}" -f $What) -ForegroundColor Green }
        else { Write-Host ("    X    {0}{1}" -f $What, $(if ($Detail) { " - $Detail" } else { '' })) -ForegroundColor Red; $script:sfFail++ }
    }

    try {
        Write-Host ''
        Write-Host ("SELF-TEST {0} - every plant is read back before the gate is run" -f $GATE) -ForegroundColor Cyan

        $set = Get-RegateGateSet -SkillDir $SkillDir -ScriptsDir $ScriptsDir
        $rule = Get-CaptionRule -ScriptsDir $ScriptsDir
        Check -What ("the 7c set derives to something ({0} member(s))" -f @($set).Count) -Ok (@($set).Count -ge 5)
        Check -What 'and it was derived from all three sources, not one' `
              -Ok ((@($set | Where-Object { @($_.Sources) -match 'invocation plan' }).Count -gt 0) -and (@($set | Where-Object { @($_.Sources) -match 'gates.md' }).Count -gt 0))
        Check -What 'the caption discriminator came from the placement gate, not a literal here' -Ok ($rule.From -notmatch 'NOT DERIVABLE')

        # ---- 1. clean
        Write-Host '  case: every gate ran after the last mutation, one caption per planned slot' -ForegroundColor DarkGray
        $fx = New-RegateFixture -Root $root -Case 'clean' -GateSet $set -Rule $rule
        Check -What 'plant landed: every implemented member has a result newer than the artefact' `
              -Ok ((Get-GateJson -Path (Join-Path $fx.BuildDir '7c-results.json')).gates.Count -eq @($set | Where-Object { $_.Implemented }).Count)
        $r = Invoke-FullRegate -BuildDir $fx.BuildDir -SkillDir $SkillDir -ScriptsDir $ScriptsDir -Guide $fx.Guide -Deck $fx.Deck
        Check -What 'the clean build passes' -Ok (-not $r.Refused -and @($r.Blocking).Count -eq 0) `
              -Detail (@($r.Blocking | ForEach-Object { $_.What }) -join '; ')
        Check -What 'and the in-prose cross-reference was correctly NOT counted as a caption' -Ok ($r.Captions.Rejected -ge 1)
        Check -What 'and the pass is not vacuous - the spine planned a slot to reconcile' -Ok (@($r.Planned).Count -eq 1)

        # ---- 2. a gate result older than the artefact it gates
        Write-Host '  case: one gate ran BEFORE the last mutation' -ForegroundColor DarkGray
        $fx = New-RegateFixture -Root $root -Case 'gate-stale' -GateSet $set -Rule $rule
        $rj = Get-GateJson -Path (Join-Path $fx.BuildDir '7c-results.json')
        $planted = @($rj.gates | Where-Object { $_.name -eq $fx.StaleGate })
        Check -What 'plant landed: the entry claims a time before the artefact was written' `
              -Ok ($planted.Count -eq 1 -and (ConvertTo-Utc $planted[0].ranAt) -lt (Get-Item -LiteralPath $fx.Guide).LastWriteTimeUtc)
        $r = Invoke-FullRegate -BuildDir $fx.BuildDir -SkillDir $SkillDir -ScriptsDir $ScriptsDir -Guide $fx.Guide -Deck $fx.Deck
        $hit = @($r.Blocking | Where-Object { $_.Arm -eq 'G' -and $_.What -match [regex]::Escape($fx.StaleGate) })
        Check -What 'the gate FAILS, naming the gate' -Ok ($hit.Count -eq 1) -Detail (@($r.Blocking | ForEach-Object { $_.What }) -join '; ')
        Check -What 'and it names BOTH timestamps' -Ok ($hit.Count -eq 1 -and $hit[0].Detail -match 'Z.*Z')

        # ---- 3. a gate with no result at all
        Write-Host '  case: one gate has no result anywhere' -ForegroundColor DarkGray
        $fx = New-RegateFixture -Root $root -Case 'gate-missing' -GateSet $set -Rule $rule
        $rj = Get-GateJson -Path (Join-Path $fx.BuildDir '7c-results.json')
        Check -What 'plant landed: the results file carries no entry for it' `
              -Ok (@($rj.gates | Where-Object { $_.name -eq $fx.SkipGate }).Count -eq 0)
        Check -What 'plant landed: and it has no report file of its own in the build either' `
              -Ok (@(@($set | Where-Object { $_.Gate -eq $fx.SkipGate })[0].Evidence | Where-Object { Test-Path -LiteralPath (Join-Path $fx.BuildDir $_) }).Count -eq 0)
        $r = Invoke-FullRegate -BuildDir $fx.BuildDir -SkillDir $SkillDir -ScriptsDir $ScriptsDir -Guide $fx.Guide -Deck $fx.Deck
        Check -What 'the gate FAILS on arm H, naming it, and does not skip it' `
              -Ok (@($r.Blocking | Where-Object { $_.Arm -eq 'H' -and $_.What -match [regex]::Escape($fx.SkipGate) }).Count -eq 1)

        # ---- 4. a planned slot with no caption
        Write-Host '  case: a planned slot carries no caption in the document' -ForegroundColor DarkGray
        $fx = New-RegateFixture -Root $root -Case 'caption-missing' -GateSet $set -Rule $rule
        $parts = Get-DocumentPart -Path $fx.Guide -Match '(?i)^word/document\.xml$'
        Check -What 'plant landed: no caption-styled paragraph survives in the document part' `
              -Ok ($parts['word/document.xml'] -notmatch 'w:pStyle w:val="Caption"')
        $r = Invoke-FullRegate -BuildDir $fx.BuildDir -SkillDir $SkillDir -ScriptsDir $ScriptsDir -Guide $fx.Guide -Deck $fx.Deck
        Check -What 'the gate FAILS on arm J, naming the slot' `
              -Ok (@($r.Blocking | Where-Object { $_.Arm -eq 'J' -and $_.Detail -match [regex]::Escape($fx.Slot) }).Count -ge 1)

        # ---- 5. two captions for one number
        Write-Host '  case: one figure number carries two captions' -ForegroundColor DarkGray
        $fx = New-RegateFixture -Root $root -Case 'caption-duplicate' -GateSet $set -Rule $rule
        $parts = Get-DocumentPart -Path $fx.Guide -Match '(?i)^word/document\.xml$'
        Check -What 'plant landed: the document part carries two caption-styled paragraphs' `
              -Ok (([regex]::Matches($parts['word/document.xml'], 'w:pStyle w:val="Caption"')).Count -eq 2)
        $r = Invoke-FullRegate -BuildDir $fx.BuildDir -SkillDir $SkillDir -ScriptsDir $ScriptsDir -Guide $fx.Guide -Deck $fx.Deck
        Check -What 'the gate FAILS - counted per number, with no de-duplication' `
              -Ok (@($r.Blocking | Where-Object { $_.Arm -eq 'J' -and $_.What -match 'more than one caption' }).Count -eq 1)

        Write-Host ''
        Write-Host ("  {0} check(s), {1} failure(s)" -f $script:sfChecks, $script:sfFail) -ForegroundColor $(if ($script:sfFail) { 'Red' } else { 'Green' })
    }
    finally {
        if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }
    return [pscustomobject]@{ Checks = $script:sfChecks; Failures = $script:sfFail }
}

# ---------------------------------------------------------------------------
# 8. Main
# ---------------------------------------------------------------------------

$scriptsDir = Join-Path $SkillDir 'scripts'
if (-not (Test-Path -LiteralPath $scriptsDir)) { $scriptsDir = $PSScriptRoot }

if ($SelfTest) {
    $st = Invoke-SelfTest -SkillDir $SkillDir -ScriptsDir $scriptsDir
    if ($st.Failures -gt 0) {
        Write-Host ("X {0}: the self-test failed. No clean result from this gate is trustworthy until it does." -f $GATE) -ForegroundColor Red
        exit 4
    }
    Write-Host ("{0}: self-test passed - the gate fails on every planted defect and passes the clean build." -f $GATE) -ForegroundColor Green
    exit 0
}

if (-not $BuildDir) { Write-Host ("{0}: -BuildDir is required (or -SelfTest)." -f $GATE) -ForegroundColor Red; exit 2 }
if (-not (Test-Path -LiteralPath $BuildDir)) { Write-Host ("{0}: no build directory at {1}" -f $GATE, $BuildDir) -ForegroundColor Red; exit 2 }
$BuildDir = (Resolve-Path -LiteralPath $BuildDir).Path

$result = Invoke-FullRegate -BuildDir $BuildDir -SkillDir $SkillDir -ScriptsDir $scriptsDir `
            -Guide $Guide -Deck $Deck -SpineDir $SpineDir -ResultsFile $ResultsFile

if ($result.Refused) {
    Write-Host ("  X {0} REFUSED: {1}" -f $GATE, $result.Refused) -ForegroundColor Red
    exit 2
}

Write-Line '' 'DarkGray'
Write-Line 'FULL RE-GATE AFTER MUTATION - the whole set, after the LAST mutation' 'Cyan'
if (-not $Quiet) {
    Write-GateCheckSet -What 'gates in the 7c set' -Count @($result.Set).Count `
        -DerivedFrom 'the AST of Run-Gates.ps1 New-GateInvocationPlan, the stage-7c rows of references\gates.md, and SKILL.md Stage 7c'
    Write-GateCheckSet -What 'captioned slots planned' -Count @($result.Planned).Count -DerivedFrom 'the spine itself, never a literal'
}
Write-Line ("  mutating stages, from the ledger's own classes: {0}" -f ((AsArray $result.Mutation.MutatingStages) -join ', '))
foreach ($a in $result.Mutation.Artefacts) {
    Write-Line ("  artefact {0}: file {1}, last mutation {2} ({3})" -f $a.Name, (Format-Utc $a.FileUtc), (Format-Utc $a.MutatedUtc), $a.From)
}
Write-Line ("  the bar every 7c gate must postdate: {0}  set by {1}" -f (Format-Utc $result.Mutation.Bar), $result.Mutation.BarBy) 'Cyan'
if ($result.Mutation.InputNewest) {
    Write-Line ("  newest render input (context, Stage 8's rule not this one's): {0} at {1}" -f $result.Mutation.InputNewestBy, (Format-Utc $result.Mutation.InputNewest))
}

Write-Line ''
foreach ($row in $result.Rows) {
    $col = switch ($row.Status) { 'ok' { 'Green' } 'not-implemented' { 'Yellow' } default { 'Red' } }
    Write-Line ("  {0,-28} {1,-16} {2}  {3}" -f $row.Gate, $row.Status, (Format-Utc $row.Ran), $row.Route) $col
}

if ($result.Captions) {
    Write-Line ''
    Write-Line ("  captions: {0} distinct number(s); by style {1}, centring {2}, italic {3}; {4} in-prose reference(s) correctly not counted (discriminator from {5})" -f `
        $result.Captions.Counts.Count, $result.Captions.ByStyle, $result.Captions.ByCentre, $result.Captions.ByItalic, $result.Captions.Rejected, $result.CaptionRule.From)
}

foreach ($n in $result.Notes) { Write-Line ("  note: {0}" -f $n) 'Yellow' }
foreach ($w in $result.Warnings) { Write-Line ("  ! [{0}] {1}" -f $w.Arm, $w.Detail) 'Yellow' }
foreach ($b in $result.Blocking) { Write-Line ("  X [{0}] {1}: {2}" -f $b.Arm, $b.What, $b.Detail) 'Red' }

if (-not $OutPath) { $OutPath = Join-Path $BuildDir 'full-regate-report.json' }
Write-Report -Result $result -Path $OutPath -BuildDir $BuildDir
Write-Line ("  report: {0}" -f $OutPath)

if (@($result.Blocking).Count -gt 0) {
    Write-Line ("FULL RE-GATE FAIL - {0} blocking finding(s)" -f @($result.Blocking).Count) 'Red'
    exit 1
}
Write-Line 'FULL RE-GATE PASS - every implemented gate in the 7c set postdates the last mutation, and every planned slot carries exactly one caption' 'Green'
exit 0
