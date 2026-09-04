<#
    Assert-GateHygiene.ps1 - static inspection of every gate script for the
    failure patterns THIS PROJECT HAS ACTUALLY SHIPPED.

    Implements the HYGIENE, PORTABILITY and ALLOW-LIST arms of gates.md
    section 35, and enforces rules 1, 3 and 5 at the top of that file.

    WHY IT EXISTS. Every expensive defect on this build was a SILENT SUCCESS -
    an operation reporting OK while producing the wrong document. The gates
    that printed green over live defects did not fail loudly; they were written
    in a shape that could not fail at all:

      *  A BLOCKING rule sat behind an OPTIONAL parameter. The registry gate's
         rendered-text arm is `foreach ($p in @($DocText))`; the runner simply
         omitted -DocText, the loop ran zero times, the gate exited 0, and NO
         RENDERED TEXT WAS GATED AT ALL. Same shape: -QuestionsInPack, -Plan,
         -Rto, -Cricos.
      *  A check-set was HAND-LISTED where a source of truth existed. A
         crossover sweep typed three of the nine palette hexes its own role map
         moves and printed "no crossover" over 766 real occurrences. A grid
         sweep scanned one JSON property name while complete grids sat in two
         others.
      *  A PASS was printed on a path where the input was missing, the script
         refused, or the collection was empty.
      *  `@($x).Count -gt 0` was used as a presence test. `@($null).Count` is
         1, so that expression answers YES for an absent property.
      *  An unanchored substring match changed domain text: `grilling` matched
         inside `chargrilling`; `7.5 L` matched inside `17.5 L` and silently
         rewrote a batch volume in four places.
      *  An allow-list lived in a script PARAMETER DEFAULT with its reasons in
         a separate in-file hashtable, where no audit would ever read them.
      *  A gate trusted an EXCEPTION over the FILESYSTEM: Word completed the
         export and then died at COM teardown, and the finisher reported FAILED
         while a correct 383-page PDF sat on disk.
      *  Ten build-local scripts hard-coded one unit code, one brand and one
         build's counts, so none of them could ever be promoted.

    HOW IT LOOKS. Structural rules read the POWERSHELL SYNTAX TREE, not the
    source text. A hygiene gate written as a pile of regexes over source would
    itself be an instance of what it hunts. Regex is used only where the thing
    being hunted really is a literal in text (portability), and there it runs
    over the lexer's tokens so a literal in code can be told from a literal in
    a comment.

    IT DOES NOT FIX ANYTHING. Every finding is a WORK ORDER against a named
    file and line. Rewriting a gate to silence its own hygiene finding is how a
    gate gets quietly weakened; the change belongs to whoever owns the gate.

    CONFIRMED vs SUSPECTED. A CONFIRMED finding is one where the shape alone is
    the defect (an optional parameter looped through `@()`, `@($x).Count -gt 0`,
    an allow-list in a parameter default). A SUSPECTED finding needs a reader:
    a plain-word regex that MIGHT want a word boundary, a literal that might be
    an encoding name rather than a unit code. Only CONFIRMED findings block, so
    that nobody learns to route around this gate. Nothing is ever suppressed -
    a downgrade is printed, not hidden.

    NO ALLOW-LIST PARAMETER. This gate takes no -Allow, -Skip or -Exempt of any
    kind, because rule 3 forbids exactly that and a gate that breaks its own
    rule is not evidence of anything. A deliberate exemption is a
    `# gate-exempt: <written reason>` region in the inspected file, and EVERY
    exemption used is printed as evidence with its reason.

    PS 5.1. ASCII only in this file.

    Exit 0 no CONFIRMED finding, 1 CONFIRMED findings present, 2 usage or
    refusal, 3 PARTIAL RUN (-Only; cannot stand for the whole set), 4 the
    self-test failed.
#>

[CmdletBinding()]
param(
    #  The skill whose scripts\ directory holds the promoted gates.
    [string] $SkillDir,

    #  A build directory. Adds its build-local Check-/Test- scripts to the
    #  inspected set and lets the hand-listing rule read that build's registry
    #  and contract as sources of truth.
    [string] $BuildDir,

    #  Explicit files, instead of discovery. Used by the self-test.
    [string[]] $Path,

    #  Where gate-hygiene.json is written.
    [string] $ResultDir,

    #  Run only these rule ids. A PARTIAL RUN: banner, exit 3, never 0.
    [string[]] $Only,

    [switch] $SelfTest,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
$GATE = 'Assert-GateHygiene'

#  $PSScriptRoot is not reliably populated inside a parameter default under
#  every 5.1 host, and a gate that dies in its own parameter block has checked
#  nothing. Resolve it here, from the invocation, with no literal path.
if (-not $SkillDir) {
    $here = $PSScriptRoot
    if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if ($here) { $SkillDir = Split-Path -Parent $here }
}

# ---------------------------------------------------------------------------
# Reading files the way this toolchain has to read them
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
function Read-HygieneText {
    <#  Explicit UTF-8 via ReadAllText, then drop a leading BOM.

        ReadAllBytes + GetString leaves the BOM inside the string and a doubled
        BOM breaks the parse with errors pointing nowhere near the cause. 5.1
        decodes a BOM-less UTF-8 file as ANSI, which mojibakes every non-ASCII
        character in it.  #>
    param([Parameter(Mandatory)][string] $File)
    if (-not (Test-Path -LiteralPath $File)) { return '' }
    $t = [System.IO.File]::ReadAllText($File, [System.Text.Encoding]::UTF8)
    return $t.TrimStart([char]0xFEFF)
}

function Write-HygieneText {
    param([Parameter(Mandatory)][string] $File, [Parameter(Mandatory)][string] $Body)
    $enc = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($File, $Body, $enc)
}

function Get-CodeOnlyText {
    <#  A node's text with its comments removed.

        WHY. The first draft read a branch's whole extent, comments included,
        and a comment quoting the phrase "no crossover" - the incident this
        file documents - made the rule report the branch as printing a pass.
        A rule that fires on its own documentation teaches a reader to ignore
        it, which is how a gate gets routed around.  #>
    param([string] $Value)
    if ($null -eq $Value) { return '' }
    return [regex]::Replace($Value, '(?s)<#.*?#>', ' ')
}

function Get-NodeCode {
    <#  A node's text with every COMMENT TOKEN blanked out.

        The lexer already knows where the comments are. A regex that tries to
        work it out again gets it wrong on the first line that carries a quote
        inside a comment - which is every line in this file that quotes an
        incident - and the rule then fires on its own documentation.  #>
    param($Node, $Ctx)
    if ($null -eq $Node) { return '' }
    $base = New-Object System.Text.StringBuilder ("$($Node.Extent.Text)")
    $s = $Node.Extent.StartOffset
    $e = $Node.Extent.EndOffset
    foreach ($tok in $Ctx.Tokens) {
        if ("$($tok.Kind)" -ine 'Comment') { continue }
        $ts = $tok.Extent.StartOffset
        $te = $tok.Extent.EndOffset
        if ($te -le $s -or $ts -ge $e) { continue }
        $a = [Math]::Max($ts, $s) - $s
        $b = [Math]::Min($te, $e) - $s
        for ($i = $a; $i -lt $b -and $i -lt $base.Length; $i++) { $base[$i] = ' ' }
    }
    return $base.ToString()
}

function Get-ShortText {
    param([string] $Value, [int] $Max = 150)
    if ($null -eq $Value) { return '' }
    $one = ($Value -replace '\s+', ' ').Trim()
    if ($one.Length -le $Max) { return $one }
    return ($one.Substring(0, $Max) + ' ...')
}

# ---------------------------------------------------------------------------
# The rule registry - id, what it is, what it costs, and the real incident
# ---------------------------------------------------------------------------

function Get-HygieneRuleTable {
    $rules = New-Object System.Collections.Generic.List[object]
    $rules.Add([pscustomobject]@{ Id = 'GH00'; Name = 'script does not parse'; Severity = 'BLOCK'
        Incident = 'A gate that will not parse cannot fail on anything; it throws before it checks.' })
    $rules.Add([pscustomobject]@{ Id = 'GH01'; Name = 'blocking rule behind an optional parameter'; Severity = 'BLOCK'
        Incident = 'Test-FigureConsistency loops foreach ($p in @($DocText)) over an optional [string[]]. The runner omitted -DocText, the loop ran zero times and the gate exited 0 with NO rendered text gated. Same shape: -QuestionsInPack, -Plan, -Rto, -Cricos.' })
    $rules.Add([pscustomobject]@{ Id = 'GH02'; Name = 'check-set hand-listed where a source of truth exists'; Severity = 'HIGH'
        Incident = 'Three of nine palette hexes typed by hand; the sweep printed "no crossover" over 766 real hits. One JSON property name scanned while complete grids sat in two others.' })
    $rules.Add([pscustomobject]@{ Id = 'GH03'; Name = 'PASS or exit 0 on a missing, refused or empty input'; Severity = 'BLOCK'
        Incident = 'A gate whose only failure path needs an input it was never given prints green over a document nobody checked.' })
    $rules.Add([pscustomobject]@{ Id = 'GH04'; Name = '@($x).Count used as a presence test'; Severity = 'HIGH'
        Incident = '@($null).Count is 1, so @($x).Count -gt 0 answers YES for an absent property and the check that depends on it never runs.' })
    $rules.Add([pscustomobject]@{ Id = 'GH05'; Name = 'unanchored substring match or replace on domain text'; Severity = 'HIGH'
        Incident = '"grilling" matched inside "chargrilling"; "7.5 L" matched inside "17.5 L" and silently changed a batch volume in four places.' })
    $rules.Add([pscustomobject]@{ Id = 'GH06'; Name = 'allow-list without a reason, or living in a parameter default'; Severity = 'HIGH'
        Incident = 'A mirror gate shipped with $Allow = @(...) in its parameter block and its reasons in a separate in-file hashtable, invisible to the audit that trusted the gate.' })
    $rules.Add([pscustomobject]@{ Id = 'GH07'; Name = 'an exception trusted over the filesystem'; Severity = 'HIGH'
        Incident = 'Word completed the export and then died at COM teardown. The finisher caught the exception and reported FAILED while a correct 383-page PDF sat on disk.' })
    $rules.Add([pscustomobject]@{ Id = 'GH08'; Name = 'portability: a literal unit, brand, RTO, provider code, hex or path'; Severity = 'BLOCK'
        Incident = 'Ten build-local scripts hard-coded one unit code, one brand and the expected counts of a single build, so none of them could ever be promoted. A gate that hard-codes one build passes every other build vacuously.' })
    return $rules
}

$script:RuleTable = Get-HygieneRuleTable

# ---------------------------------------------------------------------------
# Findings
# ---------------------------------------------------------------------------

$script:Findings = New-Object System.Collections.Generic.List[object]

function Get-SeverityRank {
    param([string] $Severity)
    switch ($Severity) {
        'BLOCK'  { return 1 }
        'HIGH'   { return 2 }
        'MEDIUM' { return 3 }
        default  { return 4 }
    }
}

function Get-DowngradedSeverity {
    param([string] $Severity)
    switch ($Severity) {
        'BLOCK'  { return 'HIGH' }
        'HIGH'   { return 'MEDIUM' }
        'MEDIUM' { return 'LOW' }
        default  { return 'LOW' }
    }
}

function Add-HygieneFinding {
    param(
        [Parameter(Mandatory)][string] $Rule,
        [Parameter(Mandatory)][string] $File,
        [int] $Line = 0,
        [string] $Snippet = '',
        [ValidateSet('CONFIRMED', 'SUSPECTED')][string] $Status = 'CONFIRMED',
        [string] $Detail = ''
    )
    $meta = $null
    foreach ($r in $script:RuleTable) { if ($r.Id -eq $Rule) { $meta = $r } }
    $sev = 'HIGH'
    $nm = $Rule
    if ($null -ne $meta) { $sev = $meta.Severity; $nm = $meta.Name }
    if ($Status -eq 'SUSPECTED') { $sev = Get-DowngradedSeverity -Severity $sev }
    $script:Findings.Add([pscustomobject]@{
        Rule     = $Rule
        RuleName = $nm
        Gate     = [System.IO.Path]::GetFileNameWithoutExtension($File)
        File     = $File
        Line     = [int]$Line
        Status   = $Status
        Severity = $sev
        Rank     = (Get-SeverityRank -Severity $sev)
        Snippet  = (Get-ShortText -Value $Snippet)
        Detail   = $Detail
    })
}

# ---------------------------------------------------------------------------
# Discovery - DERIVED from the filesystem, never a hand-typed list of gates
# ---------------------------------------------------------------------------

function Get-HygieneTargetSet {
    <#  Every .ps1 under the skill's scripts\ directory, plus a build's own
        Check-/Test- scripts when a build is given.

        The set is enumerated, never typed. A hand-listed check set is itself
        one of the recorded failure classes here, and this gate would be
        checking whatever the last editor remembered to add.  #>
    param([string] $Skill, [string] $Build)

    $set = New-Object System.Collections.Generic.List[object]
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

    $roots = New-Object System.Collections.Generic.List[object]
    if ($Skill) { $roots.Add([pscustomobject]@{ Dir = (Join-Path $Skill 'scripts'); Origin = 'skill' }) }
    if ($Build) { $roots.Add([pscustomobject]@{ Dir = $Build; Origin = 'build-local' }) }

    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root.Dir)) { continue }
        $files = @()
        try { $files = @(Get-ChildItem -LiteralPath $root.Dir -Filter '*.ps1' -File -ErrorAction Stop) }
        catch { $files = @() }
        foreach ($f in $files) {
            if ($root.Origin -eq 'build-local' -and $f.Name -notmatch '^(Assert|Check|Test)-') { continue }
            if ($seen.Contains($f.FullName)) { continue }
            [void]$seen.Add($f.FullName)
            $set.Add([pscustomobject]@{
                Name   = $f.BaseName
                File   = $f.FullName
                Origin = $root.Origin
                Length = $f.Length
                Mtime  = $f.LastWriteTimeUtc
            })
        }
    }
    return $set.ToArray()
}

# ---------------------------------------------------------------------------
# The sources of truth a check-set could have been derived from
# ---------------------------------------------------------------------------

function Get-JsonLeafValue {
    <# Every string leaf and every property name in a JSON object graph. #>
    param($Node, $Bag, [int] $Depth = 0)
    if ($Depth -gt 8 -or $null -eq $Node) { return }
    if ($Node -is [string]) {
        $s = "$Node".Trim()
        if ($s.Length -ge 3 -and $s.Length -le 80) { [void]$Bag.Add($s) }
        return
    }
    if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string])) {
        foreach ($item in $Node) { Get-JsonLeafValue -Node $item -Bag $Bag -Depth ($Depth + 1) }
        return
    }
    if ($Node -is [psobject] -and $null -ne $Node.PSObject) {
        foreach ($p in $Node.PSObject.Properties) {
            $pn = "$($p.Name)".Trim()
            if ($pn.Length -ge 3 -and $pn.Length -le 80) { [void]$Bag.Add($pn) }
            Get-JsonLeafValue -Node $p.Value -Bag $Bag -Depth ($Depth + 1)
        }
    }
}

function Get-HygieneSourceOfTruth {
    <#  Every config, profile and registry on disk, as file -> set of values.

        This is what the hand-listing rule compares a literal array against.
        Nothing here is typed: the files are enumerated and their values read.  #>
    param([string] $Skill, [string] $Build, [string[]] $ExtraDir)

    $maps = New-Object System.Collections.Generic.List[object]
    $dirs = New-Object System.Collections.Generic.List[string]
    if ($Skill) {
        $dirs.Add((Join-Path $Skill 'assets'))
        $dirs.Add((Join-Path $Skill 'references'))
    }
    if ($Build) { $dirs.Add($Build) }
    if ($null -ne $ExtraDir) { foreach ($d in $ExtraDir) { if ($d) { $dirs.Add($d) } } }

    foreach ($d in $dirs) {
        if (-not (Test-Path -LiteralPath $d)) { continue }
        $jsons = @()
        try { $jsons = @(Get-ChildItem -LiteralPath $d -Filter '*.json' -File -Recurse -Depth 2 -ErrorAction Stop) }
        catch { $jsons = @() }
        foreach ($j in $jsons) {
            if ($j.Length -gt 4000000) { continue }
            $obj = $null
            try { $obj = (Read-HygieneText -File $j.FullName | ConvertFrom-Json) }
            catch { $obj = $null }
            if ($null -eq $obj) { continue }
            $bag = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
            Get-JsonLeafValue -Node $obj -Bag $bag
            if ($bag.Count -ge 2) {
                $maps.Add([pscustomobject]@{ File = $j.FullName; Values = $bag })
            }
        }
    }
    return $maps.ToArray()
}

# ---------------------------------------------------------------------------
# Exempt regions - declared, reasoned, and always printed as evidence
# ---------------------------------------------------------------------------

$script:ExemptionsUsed = New-Object System.Collections.Generic.List[object]

function Get-ExemptRegion {
    <#  `# gate-exempt: <reason>` opens a region, `# gate-exempt-end` closes it.
        A region with no written reason is itself a finding: an exemption
        nobody can audit is a gate switched off quietly.  #>
    param([string] $File, [string[]] $Lines)
    #  THE MARKER MUST OWN ITS LINE. A first draft of this matched the marker
    #  anywhere in a line, so this gate's own header - which quotes the marker
    #  while explaining it - opened a region that never closed and exempted the
    #  whole file from every rule. It then printed HYGIENE PASS over itself.
    #  That is the exact silent success this gate exists to end, committed by
    #  the gate, so the marker is now line-anchored and an UNCLOSED region is a
    #  finding and is NOT honoured.
    $regions = New-Object System.Collections.Generic.List[object]
    $open = $null
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $ln = $Lines[$i]
        $m = [regex]::Match($ln, '(?i)^\s*#\s*gate-exempt\s*:\s*(.*)$')
        if ($m.Success) {
            if ($null -ne $open) {
                Add-HygieneFinding -Rule 'GH06' -File $File -Line ($i + 1) -Snippet $ln -Status 'CONFIRMED' `
                    -Detail 'a gate-exempt region opens inside another one. Nested exemptions hide their own extent; close the first.'
            }
            $reason = $m.Groups[1].Value.Trim()
            $open = [pscustomobject]@{ Start = ($i + 1); End = 0; Reason = $reason }
            $regions.Add($open)
            if ($reason.Length -lt 20) {
                Add-HygieneFinding -Rule 'GH06' -File $File -Line ($i + 1) -Snippet $ln -Status 'CONFIRMED' `
                    -Detail 'a gate-exempt region carries no written reason (or one too short to be one). An exemption nobody can audit is a gate switched off quietly.'
            }
            continue
        }
        if ([regex]::IsMatch($ln, '(?i)^\s*#\s*gate-exempt-end\b') -and $null -ne $open) {
            $open.End = ($i + 1)
            $open = $null
        }
    }
    $honoured = New-Object System.Collections.Generic.List[object]
    foreach ($r in $regions) {
        if ($r.End -lt $r.Start) {
            Add-HygieneFinding -Rule 'GH06' -File $File -Line $r.Start -Snippet (Get-ShortText -Value $r.Reason -Max 100) -Status 'CONFIRMED' `
                -Detail 'this gate-exempt region is never closed with # gate-exempt-end. An unclosed region would exempt the rest of the file, so it is NOT honoured and every rule still ran.'
            continue
        }
        $honoured.Add($r)
        $script:ExemptionsUsed.Add([pscustomobject]@{ File = $File; Start = $r.Start; End = $r.End; Reason = $r.Reason })
    }
    return $honoured.ToArray()
}

function Test-InExemptRegion {
    param($Regions, [int] $Line)
    if ($null -eq $Regions) { return $false }
    foreach ($r in $Regions) { if ($Line -ge $r.Start -and $Line -le $r.End) { return $true } }
    return $false
}

# ---------------------------------------------------------------------------
# AST helpers
# ---------------------------------------------------------------------------

function Get-AstNode {
    param($Root, [Type] $Kind)
    if ($null -eq $Root) { return @() }
    return @($Root.FindAll({ param($n) $n.GetType() -eq $Kind }.GetNewClosure(), $true))
}

function Test-ParameterMandatory {
    param($Parameter)
    foreach ($a in $Parameter.Attributes) {
        if ($a -isnot [System.Management.Automation.Language.AttributeAst]) { continue }
        foreach ($na in $a.NamedArguments) {
            if ("$($na.ArgumentName)" -ieq 'Mandatory') {
                if ($na.ExpressionOmitted) { return $true }
                if ($na.Argument.Extent.Text -match '(?i)\$true') { return $true }
            }
        }
    }
    return $false
}

function Get-ParameterName {
    param($Parameter)
    return "$($Parameter.Name.VariablePath.UserPath)"
}

function Test-BlockingLanguage {
    <#  Does the script's own text call this rule blocking?

        The distinction matters: an optional -Quiet that skips a print is not a
        defect. An optional input whose absence skips a rule the header calls
        BLOCKING is the -DocText incident exactly.  #>
    param([string] $Source, [string[]] $Lines, [int] $Line, [int] $Window = 45)
    if ($Source -match '(?i)\bblock(s|ing)?\b') {
        $lo = [Math]::Max(0, $Line - $Window - 1)
        $hi = [Math]::Min($Lines.Count - 1, $Line + $Window - 1)
        if ($hi -ge $lo) {
            $near = ($Lines[$lo..$hi] -join ' ')
            if ($near -match '(?i)\b(block(s|ing)?|must|fail|refuse)\b') { return $true }
        }
        return $true
    }
    return $false
}

# ---------------------------------------------------------------------------
# GH01 - a BLOCKING rule sitting behind an OPTIONAL parameter
# ---------------------------------------------------------------------------

function Invoke-RuleGH01 {
    param($Ctx)
    $pb = $Ctx.Ast.ParamBlock
    if ($null -eq $pb) { return }

    #  A switch that turns printing down, or an output path, is not an input a
    #  rule depends on. The shape that matters is an optional value or
    #  collection whose absence makes a rule iterate nothing or skip.
    foreach ($p in $pb.Parameters) {
        if (Test-ParameterMandatory -Parameter $p) { continue }
        $pname = Get-ParameterName -Parameter $p
        if ($p.StaticType -eq [System.Management.Automation.SwitchParameter]) { continue }
        if ($pname -match '(?i)^(Quiet|Verbose|Serial|OutPath|ResultPath|ResultDir|ReportPath|OutDir|TimeoutMinutes|MaxJobs|SkillDir)$') { continue }

        $rx = [regex]::Escape('$' + $pname)

        #  (a) CONFIRMED: a loop over @($OptionalParam). @($null) iterates zero
        #      times, so the whole arm disappears without a word in the log.
        foreach ($fe in (Get-AstNode -Root $Ctx.Ast -Kind ([System.Management.Automation.Language.ForEachStatementAst]))) {
            $cond = $fe.Condition.Extent.Text
            if ([regex]::IsMatch($cond, ('@\(\s*' + $rx + '\s*\)')) -or [regex]::IsMatch($cond, ('@\(\s*' + $rx + '\b[^)]*\)'))) {
                $line = $fe.Extent.StartLineNumber
                if (Test-InExemptRegion -Regions $Ctx.Exempt -Line $line) { continue }

                #  A CANDIDATE LIST IS NOT A DISABLED RULE. `foreach ($d in
                #  @($BrandingDir, (Join-Path $SkillDir 'assets'), ...))` still
                #  iterates when the optional parameter is absent, because the
                #  other candidates are always there. The defect is a loop that
                #  becomes EMPTY - one whose every element can be missing. So
                #  an array carrying a non-parameter element is reported for a
                #  reader, not as a blocking finding.
                $allOptional = $true
                $inner = [regex]::Match($cond, '@\(\s*(.*?)\s*\)\s*$')
                $innerTxt = $cond
                if ($inner.Success) { $innerTxt = $inner.Groups[1].Value }
                foreach ($part in ($innerTxt -split ',')) {
                    $ptrim = $part.Trim()
                    if (-not $ptrim) { continue }
                    #  a pipeline filter on the parameter itself is still the
                    #  parameter, e.g. @($DocText | Where-Object { $_ })
                    $ptrim = ($ptrim -split '\|')[0].Trim()
                    if (-not [regex]::IsMatch($ptrim, '^\$[A-Za-z_][A-Za-z0-9_]*$')) { $allOptional = $false; break }
                }

                $blocking = Test-BlockingLanguage -Source $Ctx.Source -Lines $Ctx.Lines -Line $line
                $st = 'SUSPECTED'
                if ($blocking -and $allOptional) { $st = 'CONFIRMED' }
                Add-HygieneFinding -Rule 'GH01' -File $Ctx.File -Line $line -Snippet $fe.Condition.Extent.Text -Status $st `
                    -Detail ("optional parameter -{0} is iterated as @({1}); when it is not passed the loop runs zero times and the rule vanishes silently. A blocking rule with a missing input must FAIL and name the input." -f $pname, ('$' + $pname))
            }
        }

        #  (b) an early skip: `if (-not $P) { return/continue }` or a guard that
        #      wraps the rule in `if ($P) { ... }` and has no else.
        foreach ($ifs in (Get-AstNode -Root $Ctx.Ast -Kind ([System.Management.Automation.Language.IfStatementAst]))) {
            foreach ($clause in $ifs.Clauses) {
                $ctext = $clause.Item1.Extent.Text
                $btext = $clause.Item2.Extent.Text
                $isAbsence = [regex]::IsMatch($ctext, ('-not\s+' + $rx + '\b')) -or [regex]::IsMatch($ctext, ('\$null\s+-eq\s+' + $rx + '\b')) -or [regex]::IsMatch($ctext, ($rx + '\s+-eq\s+\$null'))
                if (-not $isAbsence) { continue }
                #  Only a DIRECT statement of the branch is an early skip. A
                #  `continue` inside a loop nested in the branch belongs to the
                #  loop, and reading the whole extent made this rule fire on
                #  every branch that happened to contain one.
                $direct = ''
                foreach ($st in $clause.Item2.Statements) { $direct = $direct + "`n" + ((Get-NodeCode -Node $st -Ctx $Ctx).Split("`n")[0]) }
                if (-not [regex]::IsMatch($direct, '(?i)\b(return|continue|exit\s+0)\b')) { continue }
                $line = $clause.Item1.Extent.StartLineNumber
                if (Test-InExemptRegion -Regions $Ctx.Exempt -Line $line) { continue }
                Add-HygieneFinding -Rule 'GH01' -File $Ctx.File -Line $line -Snippet $ctext -Status 'SUSPECTED' `
                    -Detail ("optional parameter -{0} missing takes an early exit path; read whether the rule that follows is blocking. If it is, the absence must be a FAIL that names the input." -f $pname)
            }
        }
    }

    #  (c) the runner shape: a gate invoked from this script with a parameter
    #      that is itself optional here and threaded through unvalidated. This
    #      is how -Rto and -Cricos reached a gate as empty strings.
    foreach ($p in $pb.Parameters) {
        if (Test-ParameterMandatory -Parameter $p) { continue }
        $pname = Get-ParameterName -Parameter $p
        if ($p.StaticType -eq [System.Management.Automation.SwitchParameter]) { continue }
        if ($pname -notmatch '(?i)^(Rto|Cricos|UnitCode|Brand|Plan|PlanPath|QuestionsInPack|DocText|Guide|Deck|UnitExtract|Contract|ContractPath)$') { continue }
        $validated = $false
        foreach ($ifs in (Get-AstNode -Root $Ctx.Ast -Kind ([System.Management.Automation.Language.IfStatementAst]))) {
            $t = $ifs.Extent.Text
            if ([regex]::IsMatch($t, ('-not\s+' + [regex]::Escape('$' + $pname) + '\b')) -and [regex]::IsMatch($t, '(?i)\b(throw|exit\s+[1-9])\b')) { $validated = $true }
        }
        if ($validated) { continue }
        $line = $p.Extent.StartLineNumber
        if (Test-InExemptRegion -Regions $Ctx.Exempt -Line $line) { continue }
        Add-HygieneFinding -Rule 'GH01' -File $Ctx.File -Line $line -Snippet $p.Extent.Text -Status 'SUSPECTED' `
            -Detail ("-{0} is optional and no path throws or exits non-zero when it is absent, so a caller that omits it gets a verdict computed without it." -f $pname)
    }
}

# ---------------------------------------------------------------------------
# GH02 - a check-set HAND-LISTED where a source of truth exists
# ---------------------------------------------------------------------------

function Get-DerivedVariable {
    <#  Variables that are ALSO assigned from a parsed source of truth.

        A literal array that a later line REPLACES with a set read from the
        schema is a documented fallback, not a second source of truth: the
        derived set wins whenever the source is present. Reading those as
        hand-listed check-sets produced a CONFIRMED finding against a gate that
        had just been corrected to derive its fields from the schema - the same
        error as accusing a gate of missing a defect it never claimed to catch,
        and just as expensive to the reader's trust.  #>
    param($Ast)
    $bag = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($asn in (Get-AstNode -Root $Ast -Kind ([System.Management.Automation.Language.AssignmentStatementAst]))) {
        if ($asn.Left -isnot [System.Management.Automation.Language.VariableExpressionAst]) { continue }
        $rhs = "$($asn.Right.Extent.Text)"
        if ([regex]::IsMatch($rhs, '(?i)(ConvertFrom-Json|Get-GateRegistry|Get-GateAllowList|Get-GateJson|Get-GateProp|\$schema\b|\$sj\b|\$decl\b|identityFields)')) {
            [void]$bag.Add("$($asn.Left.VariablePath.UserPath)")
        }
    }
    return $bag
}

function Invoke-RuleGH02 {
    param($Ctx)
    if ($null -eq $Ctx.Truth -or $Ctx.Truth.Count -eq 0) { return }
    $derivedVars = Get-DerivedVariable -Ast $Ctx.Ast

    #  ONLY an array literal of constants. A member name parses as a string
    #  constant too, so reading every @( ) in the file made
    #  @($schema.identityFields.required) - a set DERIVED from the schema,
    #  which is the thing this rule asks for - look like a hand-typed list of
    #  the words "identityFields" and "required".
    $arrays = New-Object System.Collections.Generic.List[object]
    foreach ($a in (Get-AstNode -Root $Ctx.Ast -Kind ([System.Management.Automation.Language.ArrayLiteralAst]))) { $arrays.Add($a) }

    foreach ($arr in $arrays) {
        #  An argument list is not a check-set. `Sort-Object a, b, c` and the
        #  right-hand side of -f both parse as array literals, and reading them
        #  as hand-typed check-sets buried the real finding in noise.
        if ($arr.Parent -is [System.Management.Automation.Language.CommandAst]) { continue }
        if ($arr.Parent -is [System.Management.Automation.Language.BinaryExpressionAst]) {
            if ("$($arr.Parent.Operator)".ToLower() -eq 'format') { continue }
        }
        $consts = New-Object System.Collections.Generic.List[string]
        $allConst = $true
        foreach ($el in $arr.Elements) {
            if ($el -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) { $allConst = $false; break }
            $v = "$($el.Value)".Trim()
            if ($v.Length -ge 3 -and $v.Length -le 80) { $consts.Add($v) }
        }
        if (-not $allConst) { continue }
        if ($consts.Count -lt 2) { continue }
        #  A stop-word list, a set of tag names, an argument vector: none of
        #  these is a check-set copied out of a config, and reading them as one
        #  buried the real finding under a hundred lines of noise. A check-set
        #  a source of truth already holds is SMALL and SPECIFIC.
        if ($consts.Count -gt 12) { continue }
        $line = $arr.Extent.StartLineNumber
        if (Test-InExemptRegion -Regions $Ctx.Exempt -Line $line) { continue }

        foreach ($map in $Ctx.Truth) {
            $hit = New-Object System.Collections.Generic.List[string]
            foreach ($c in $consts) { if ($map.Values.Contains($c)) { $hit.Add($c) } }
            if ($hit.Count -lt 2) { continue }
            $longest = 0
            foreach ($h in $hit) { if ($h.Length -gt $longest) { $longest = $h.Length } }
            $share = [double]$hit.Count / [double]$consts.Count
            #  Two specific values, and most of the array, is the shape of a
            #  set copied out of a map. Anything looser is a coincidence of
            #  vocabulary and belongs to a reader, not to a blocking verdict.
            $st = 'SUSPECTED'
            if ($longest -ge 6 -and $share -ge 0.6) { $st = 'CONFIRMED' }
            if ($longest -lt 5) { continue }

            #  Is this array the CONTROL of a foreach that then reads those
            #  names off an object? `foreach ($k in @("required","optional"))
            #  { $schema.identityFields.$k }` is how you ENUMERATE a source of
            #  truth, not how you hand-list a check-set - the values it finds
            #  still come from the schema.
            $isEnumerator = $false
            $up = $arr.Parent
            for ($h2 = 0; $h2 -lt 12 -and $null -ne $up; $h2++) {
                if ($up -is [System.Management.Automation.Language.ForEachStatementAst]) {
                    $varName = "$($up.Variable.VariablePath.UserPath)"
                    $bodyTxt = "$($up.Body.Extent.Text)"
                    if ([regex]::IsMatch($bodyTxt, '\.\s*\$' + [regex]::Escape($varName) + '\b')) { $isEnumerator = $true }
                    break
                }
                $up = $up.Parent
            }
            if ($isEnumerator) {
                Add-HygieneFinding -Rule 'GH02' -File $Ctx.File -Line $line -Snippet $arr.Extent.Text -Status 'SUSPECTED' `
                    -Detail 'these names drive a lookup ON the source of truth rather than standing in for its values - an enumeration helper, not a hand-typed check-set. Read it only for whether the list of buckets can fall behind the schema.'
                break
            }

            #  Is this array a FALLBACK that a derived set replaces?
            $isFallback = $false
            $owner = $arr.Parent
            for ($hop = 0; $hop -lt 12 -and $null -ne $owner; $hop++) {
                if ($owner -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                    $owner.Left -is [System.Management.Automation.Language.VariableExpressionAst]) {
                    if ($derivedVars.Contains("$($owner.Left.VariablePath.UserPath)")) { $isFallback = $true }
                    break
                }
                $owner = $owner.Parent
            }
            if ($isFallback) {
                Add-HygieneFinding -Rule 'GH02' -File $Ctx.File -Line $line -Snippet $arr.Extent.Text -Status 'SUSPECTED' `
                    -Detail 'a literal set that a DERIVED set replaces when the source of truth is present - a documented fallback, not a hand-typed check-set. Worth a read only for whether the fallback can be reached silently when the source is missing.'
                break
            }
            $detail = ("{0} of {1} literals in this array also exist in {2} ({3} values). Derive the set from that file, and print the set size and the map it came from - three of nine hexes typed by hand is how a sweep printed 'no crossover' over 766 live occurrences." -f `
                $hit.Count, $consts.Count, [System.IO.Path]::GetFileName($map.File), $map.Values.Count)
            Add-HygieneFinding -Rule 'GH02' -File $Ctx.File -Line $line -Snippet $arr.Extent.Text -Status $st -Detail $detail
            break
        }
    }
}

# ---------------------------------------------------------------------------
# GH03 - a PASS or exit 0 on a missing, refused or empty input
# ---------------------------------------------------------------------------

function Test-AbsenceCondition {
    param([string] $Text)
    if ($Text -match '-not\s+\(?\s*\$') { return $true }
    if ($Text -match '\$null\s+-eq\s+\$') { return $true }
    if ($Text -match '\$\w+\s+-eq\s+\$null') { return $true }
    if ($Text -match '\.Count\s+-(eq|lt|le)\s+[01]\b') { return $true }
    if ($Text -match '(?i)-not\s*\(\s*Test-Path') { return $true }
    if ($Text -match '(?i)\$\w+\s+-eq\s+''''') { return $true }
    return $false
}

function Test-PassLanguage {
    <#  A VERDICT, not a word. The first draft matched "ok" and "clean"
        case-insensitively and fired on every sentence of prose that happened
        to contain one, which buried the real hits. A printed verdict in this
        codebase is upper-case; a lower-case "clean" is narration.  #>
    param([string] $Text)
    if ([regex]::IsMatch($Text, '(?<![A-Za-z0-9])exit\s+0(?![0-9])')) { return $true }
    if ([regex]::IsMatch($Text, '(?-i)\b(PASS|PASSED|OK|CLEAN)\b')) { return $true }
    if ([regex]::IsMatch($Text, '(?i)\b(no\s+crossover|nothing\s+to\s+check|all\s+good)\b')) { return $true }
    return $false
}

function Test-SwitchOnlyCondition {
    <#  Is this condition testing nothing but display switches?

        `if (-not $Quiet) { Write-Host "PASS" }` is a print guard, not a
        missing-input path, and reading it as one made this rule fire on every
        gate that prints its own verdict quietly.  #>
    param([string] $Text, $SwitchNames)
    $vars = [regex]::Matches($Text, '\$([A-Za-z_][A-Za-z0-9_]*)')
    if ($vars.Count -eq 0) { return $false }
    foreach ($v in $vars) {
        $nm = $v.Groups[1].Value
        $isSwitch = $false
        foreach ($s in $SwitchNames) { if ($s -ieq $nm) { $isSwitch = $true } }
        if (-not $isSwitch) { return $false }
    }
    return $true
}

function Invoke-RuleGH03 {
    param($Ctx)

    $switches = New-Object System.Collections.Generic.List[string]
    if ($null -ne $Ctx.Ast.ParamBlock) {
        foreach ($p in $Ctx.Ast.ParamBlock.Parameters) {
            if ($p.StaticType -eq [System.Management.Automation.SwitchParameter]) { $switches.Add("$($p.Name.VariablePath.UserPath)") }
        }
    }

    foreach ($ifs in (Get-AstNode -Root $Ctx.Ast -Kind ([System.Management.Automation.Language.IfStatementAst]))) {
        foreach ($clause in $ifs.Clauses) {
            $ctext = $clause.Item1.Extent.Text
            $btext = $clause.Item2.Extent.Text
            $ccode = Get-NodeCode -Node $clause.Item1 -Ctx $Ctx
            if (-not (Test-AbsenceCondition -Text $ccode)) { continue }
            if (Test-SwitchOnlyCondition -Text $ccode -SwitchNames $switches) { continue }
            $bcode = Get-NodeCode -Node $clause.Item2 -Ctx $Ctx
            if (-not (Test-PassLanguage -Text $bcode)) { continue }

            #  "No findings, so PASS" is what a gate is FOR. "No input, so PASS"
            #  is the defect. They are the same shape, and only the name of the
            #  thing being counted separates them - so an outcome set is
            #  reported for a reader rather than blocking, and is never dropped.
            $outcomeSet = [regex]::IsMatch($ccode, '(?i)\$\w*(finding|problem|fail|blocking|issue|hit|error|violation|breach|unmapped|missing|stale|conflict|leak|orphan|crossover|defect|warn)\w*\b') -or `
                          [regex]::IsMatch($ccode, '(?i)\.(Findings|Problems|Blocking|Failures|Issues|Hits|Errors|Violations|Unmapped|Missing|Warnings)\b')
            #  A refusal is not a pass. exit 2 / exit 3 / throw on an absent
            #  input is exactly the right behaviour and must not be reported.
            if ([regex]::IsMatch($bcode, '(?<![A-Za-z0-9])exit\s+[1-9]') -or [regex]::IsMatch($bcode, '(?i)\bthrow\b')) { continue }
            $line = $clause.Item1.Extent.StartLineNumber
            if (Test-InExemptRegion -Regions $Ctx.Exempt -Line $line) { continue }
            if ($outcomeSet) {
                Add-HygieneFinding -Rule 'GH03' -File $Ctx.File -Line $line -Snippet $ctext -Status 'SUSPECTED' `
                    -Detail 'a pass printed because a RESULT set is empty. That is correct only if the set could not be empty for want of an input - confirm the inputs were present and non-empty before this counted zero.'
            }
            else {
                Add-HygieneFinding -Rule 'GH03' -File $Ctx.File -Line $line -Snippet $ctext -Status 'CONFIRMED' `
                    -Detail 'this branch fires when an input is absent or a collection is empty and prints a pass (or exits 0). An absent input is a REFUSAL, not a clean result.'
            }
        }
    }

    #  A catch that swallows the failure and exits 0 is the same defect wearing
    #  a different hat.
    foreach ($try in (Get-AstNode -Root $Ctx.Ast -Kind ([System.Management.Automation.Language.TryStatementAst]))) {
        foreach ($cc in $try.CatchClauses) {
            $btext = $cc.Body.Extent.Text
            if ([regex]::IsMatch((Get-NodeCode -Node $cc.Body -Ctx $Ctx), '(?<![A-Za-z0-9])exit\s+0(?![0-9])')) {
                $line = $cc.Extent.StartLineNumber
                if (Test-InExemptRegion -Regions $Ctx.Exempt -Line $line) { continue }
                Add-HygieneFinding -Rule 'GH03' -File $Ctx.File -Line $line -Snippet (Get-ShortText -Value $btext) -Status 'CONFIRMED' `
                    -Detail 'a catch block exits 0. The gate threw and then reported a pass.'
            }
        }
    }
}

# ---------------------------------------------------------------------------
# GH04 - @($x).Count used as a presence test
# ---------------------------------------------------------------------------

function Invoke-RuleGH04 {
    param($Ctx)
    foreach ($be in (Get-AstNode -Root $Ctx.Ast -Kind ([System.Management.Automation.Language.BinaryExpressionAst]))) {
        $op = "$($be.Operator)".ToLower()
        if ($op -notmatch '^(igt|cgt|gt|ige|cge|ge|ine|cne|ne)$') { continue }
        $left = $be.Left
        if ($left -isnot [System.Management.Automation.Language.MemberExpressionAst]) { continue }
        if ("$($left.Member.Extent.Text)" -ine 'Count') { continue }
        if ($left.Expression -isnot [System.Management.Automation.Language.ArrayExpressionAst]) { continue }
        $rt = "$($be.Right.Extent.Text)".Trim()
        if ($rt -ne '0' -and $rt -ne '1') { continue }

        #  What sits inside the @() decides how bad this is. A PROPERTY that
        #  may not exist is the recorded incident exactly. A bare variable
        #  might be $null and is worth a read. A pipeline that yields nothing
        #  really does count zero, and flagging that would be crying wolf.
        $inner = $null
        $stmts = @($left.Expression.SubExpression.Statements)
        if ($stmts.Count -eq 1 -and $stmts[0] -is [System.Management.Automation.Language.PipelineAst]) {
            $els = @($stmts[0].PipelineElements)
            if ($els.Count -eq 1 -and $els[0] -is [System.Management.Automation.Language.CommandExpressionAst]) { $inner = $els[0].Expression }
        }
        if ($null -eq $inner) { continue }
        $st4 = ''
        if ($inner -is [System.Management.Automation.Language.MemberExpressionAst]) { $st4 = 'CONFIRMED' }
        elseif ($inner -is [System.Management.Automation.Language.VariableExpressionAst]) { $st4 = 'SUSPECTED' }
        else { continue }

        $line = $be.Extent.StartLineNumber
        if (Test-InExemptRegion -Regions $Ctx.Exempt -Line $line) { continue }
        Add-HygieneFinding -Rule 'GH04' -File $Ctx.File -Line $line -Snippet $be.Extent.Text -Status $st4 `
            -Detail '@($null).Count is 1 in PS 5.1, so this answers YES for an absent property. Test the property exists before you count it.'
    }
}

# ---------------------------------------------------------------------------
# GH05 - unanchored substring match or replace on domain text
# ---------------------------------------------------------------------------

function Test-RegexAnchored {
    <#  A pattern that carries a boundary, an anchor or a character class is
        doing regex on purpose. A bare run of words is a substring match
        wearing a regex operator, and that is what matched "grilling" inside
        "chargrilling".  #>
    param([string] $Pattern)
    if ($Pattern -match '\\b|\^|\$|\\A|\\Z|\\z') { return $true }
    if ($Pattern -match '[\[\]\(\)\|\*\+\?\{\}]') { return $true }
    if ($Pattern -match '\\[dwsDWSn]') { return $true }
    return $false
}

function Invoke-RuleGH05 {
    param($Ctx)

    #  Which variables in this file are assigned something that IS a regex?
    #  A pattern held in a variable is only the recorded incident when the
    #  value is domain text; when it is an alternation the author wrote, the
    #  finding belongs to a reader.
    $regexVars = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($asn in (Get-AstNode -Root $Ctx.Ast -Kind ([System.Management.Automation.Language.AssignmentStatementAst]))) {
        if ($asn.Left -isnot [System.Management.Automation.Language.VariableExpressionAst]) { continue }
        $rhsText = "$($asn.Right.Extent.Text)"
        if ($rhsText.Length -lt 3) { continue }
        if (Test-RegexAnchored -Pattern $rhsText) {
            [void]$regexVars.Add("$($asn.Left.VariablePath.UserPath)")
        }
    }

    foreach ($be in (Get-AstNode -Root $Ctx.Ast -Kind ([System.Management.Automation.Language.BinaryExpressionAst]))) {
        $op = "$($be.Operator)".ToLower()
        if ($op -notmatch '^(i?match|c?match|i?notmatch|c?notmatch|i?replace|c?replace|i?like|c?like|i?notlike|c?notlike)$') { continue }
        $line = $be.Extent.StartLineNumber
        if (Test-InExemptRegion -Regions $Ctx.Exempt -Line $line) { continue }

        $right = $be.Right
        #  `$a -replace $b, 'c'` parses with an ArrayLiteral on the right: the
        #  pattern is its FIRST element. Reading only the whole node here is
        #  how a rule silently stops covering every -replace in the codebase.
        if ($right -is [System.Management.Automation.Language.ArrayLiteralAst] -and $right.Elements.Count -ge 1) {
            $right = $right.Elements[0]
        }
        if ($right -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
            $right -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
            $pat = "$($right.Extent.Text)".Trim("'", '"')
            if ($right -is [System.Management.Automation.Language.ExpandableStringExpressionAst] -and $pat -match '\$') {
                #  An interpolated pattern is a variable pattern with extra steps.
                if ($pat -notmatch '(?i)regex.{0,4}::Escape') {
                    Add-HygieneFinding -Rule 'GH05' -File $Ctx.File -Line $line -Snippet $be.Extent.Text -Status 'CONFIRMED' `
                        -Detail 'the pattern is built by interpolation with no [regex]::Escape, so any metacharacter in the domain value changes what is matched.'
                }
                continue
            }
            if ($pat.Length -lt 3) { continue }
            if (Test-RegexAnchored -Pattern $pat) { continue }
            if ($pat -notmatch '[A-Za-z]') { continue }
            #  The hazard is a pattern that can match INSIDE a longer word:
            #  "grilling" in "chargrilling", "7.5 L" in "17.5 L". A markup
            #  fragment cannot, and flagging it teaches a reader to skip this
            #  rule.
            if (-not [regex]::IsMatch($pat, "^[A-Za-z0-9][A-Za-z0-9 .,'\-]*$")) { continue }
            $isReplace = [regex]::IsMatch($op, 'replace')
            $st = 'SUSPECTED'
            if ($isReplace) { $st = 'CONFIRMED' }
            Add-HygieneFinding -Rule 'GH05' -File $Ctx.File -Line $line -Snippet $be.Extent.Text -Status $st `
                -Detail ("the pattern carries no word boundary or anchor, so it matches inside a longer word. '7.5 L' matched inside '17.5 L' and silently changed a batch volume in four places.")
            continue
        }

        #  A variable pattern: the domain value goes straight into the regex
        #  engine. Without [regex]::Escape and boundaries this is the incident.
        if ($right -is [System.Management.Automation.Language.VariableExpressionAst] -or
            $right -is [System.Management.Automation.Language.MemberExpressionAst] -or
            $right -is [System.Management.Automation.Language.SubExpressionAst] -or
            $right -is [System.Management.Automation.Language.ParenExpressionAst]) {
            $rtext = "$($right.Extent.Text)"
            if ($rtext -match '(?i)regex.{0,4}::Escape') { continue }
            #  A pattern held in a variable whose name says it is a regex was
            #  authored as one; still worth a read, but not the same defect.
            $st = 'CONFIRMED'
            if ([regex]::IsMatch($rtext, '(?i)(rx|regex|pattern)')) { $st = 'SUSPECTED' }
            foreach ($vn in [regex]::Matches($rtext, '\$(?:script:|global:|local:)?([A-Za-z_][A-Za-z0-9_]*)')) {
                if ($regexVars.Contains($vn.Groups[1].Value)) { $st = 'SUSPECTED' }
            }
            Add-HygieneFinding -Rule 'GH05' -File $Ctx.File -Line $line -Snippet $be.Extent.Text -Status $st `
                -Detail 'a domain value is used as a regex with no [regex]::Escape and no word boundary. Escape it, and anchor it, or the value decides what the pattern means.'
        }
    }

    #  .Replace( and .IndexOf( on a variable are the same substring hazard
    #  without the regex operator.
    foreach ($ie in (Get-AstNode -Root $Ctx.Ast -Kind ([System.Management.Automation.Language.InvokeMemberExpressionAst]))) {
        $mn = "$($ie.Member.Extent.Text)"
        if ($mn -notmatch '(?i)^(Replace|IndexOf|Contains|StartsWith|EndsWith)$') { continue }
        #  [regex]::Replace($input, $pattern, $to) takes the INPUT first. Only
        #  an instance .Replace($needle, $to) puts the needle in argument one.
        if ($ie.Static) { continue }
        if ($null -eq $ie.Arguments -or $ie.Arguments.Count -lt 1) { continue }
        $a0 = $ie.Arguments[0]
        if ($a0 -isnot [System.Management.Automation.Language.VariableExpressionAst] -and
            $a0 -isnot [System.Management.Automation.Language.MemberExpressionAst]) { continue }
        if ($mn -match '(?i)^(IndexOf|Contains|StartsWith|EndsWith)$') { continue }
        $line = $ie.Extent.StartLineNumber
        if (Test-InExemptRegion -Regions $Ctx.Exempt -Line $line) { continue }
        Add-HygieneFinding -Rule 'GH05' -File $Ctx.File -Line $line -Snippet $ie.Extent.Text -Status 'SUSPECTED' `
            -Detail 'a substring replace with a variable needle rewrites every occurrence, including the ones inside a longer token.'
    }
}

# ---------------------------------------------------------------------------
# GH06 - allow-list discipline
# ---------------------------------------------------------------------------

function Invoke-RuleGH06 {
    param($Ctx)

    $pb = $Ctx.Ast.ParamBlock
    if ($null -ne $pb) {
        foreach ($p in $pb.Parameters) {
            $pname = Get-ParameterName -Parameter $p
            if ($pname -notmatch '(?i)(allow|exempt|waiv|permit|whitelist|ignorelist|skiplist)') { continue }
            if ($null -eq $p.DefaultValue) {
                $line = $p.Extent.StartLineNumber
                Add-HygieneFinding -Rule 'GH06' -File $Ctx.File -Line $line -Snippet $p.Extent.Text -Status 'SUSPECTED' `
                    -Detail ("-{0} is an allow-list taken as a parameter. An allow-list belongs in the versioned registry beside the rule it weakens, with a written reason per entry." -f $pname)
                continue
            }
            $dv = "$($p.DefaultValue.Extent.Text)"
            if ($dv -match '^\s*@\(\s*\)\s*$') { continue }
            $line = $p.Extent.StartLineNumber
            Add-HygieneFinding -Rule 'GH06' -File $Ctx.File -Line $line -Snippet $p.Extent.Text -Status 'CONFIRMED' `
                -Detail ("-{0} carries a POPULATED allow-list as a parameter default. This is the exact shape that turned a compliance check off for one figure with its reasons in a separate in-file hashtable, invisible to the audit." -f $pname)
        }
    }

    #  An in-script allow-list of constants with no reason beside it.
    foreach ($asn in (Get-AstNode -Root $Ctx.Ast -Kind ([System.Management.Automation.Language.AssignmentStatementAst]))) {
        $lhs = "$($asn.Left.Extent.Text)"
        if ($lhs -notmatch '(?i)(allow|exempt|waiv|permit|whitelist)') { continue }
        $rhs = "$($asn.Right.Extent.Text)"
        if ($rhs -notmatch '@\(' -and $rhs -notmatch '@\{') { continue }
        if ($rhs -match '^\s*@\(\s*\)\s*$' -or $rhs -match '^\s*@\{\s*\}\s*$') { continue }
        if ($rhs -match '(?i)Get-GateAllowList|Get-GateRegistry|ConvertFrom-Json') { continue }
        $line = $asn.Extent.StartLineNumber
        if (Test-InExemptRegion -Regions $Ctx.Exempt -Line $line) { continue }
        $hasReason = ($rhs -match '(?i)(reason|why|because|note)')
        $st = 'SUSPECTED'
        if (-not $hasReason) { $st = 'CONFIRMED' }
        Add-HygieneFinding -Rule 'GH06' -File $Ctx.File -Line $line -Snippet $asn.Extent.Text -Status $st `
            -Detail 'an allow-list held inside the script. It must live in the versioned registry beside the rule it weakens, carry a written reason per entry, and be surfaced to the audit as evidence.'
    }
}

# ---------------------------------------------------------------------------
# GH07 - an exception trusted over the filesystem
# ---------------------------------------------------------------------------

function Invoke-RuleGH07 {
    param($Ctx)
    foreach ($try in (Get-AstNode -Root $Ctx.Ast -Kind ([System.Management.Automation.Language.TryStatementAst]))) {
        $ttext = Get-NodeCode -Node $try.Body -Ctx $Ctx
        $producesFile = ($ttext -match '(?i)(ComObject|SaveAs2?|ExportAsFixedFormat|\.Quit\(|ReleaseComObject|\.Close\(|Start-Process|Compress-Archive|WriteAllText|WriteAllBytes|\.Save\()')
        if (-not $producesFile) { continue }
        foreach ($cc in $try.CatchClauses) {
            $btext = Get-NodeCode -Node $cc.Body -Ctx $Ctx
            $declaresFailure = [regex]::IsMatch($btext, '(?<![A-Za-z0-9])exit\s+[1-9]') -or [regex]::IsMatch($btext, '(?i)\b(FAIL|FAILED|throw)\b')
            if (-not $declaresFailure) { continue }
            $checksDisk = [regex]::IsMatch($btext, '(?i)(Test-Path|GetFileInfo|\[System\.IO\.File\]::Exists|\.Length\b|Get-Item\b|Get-ChildItem\b)')
            if ($checksDisk) { continue }
            $line = $cc.Extent.StartLineNumber
            if (Test-InExemptRegion -Regions $Ctx.Exempt -Line $line) { continue }
            Add-HygieneFinding -Rule 'GH07' -File $Ctx.File -Line $line -Snippet (Get-ShortText -Value $btext) -Status 'CONFIRMED' `
                -Detail 'this catch declares failure for an operation that writes a file, without looking at the file. Word completes the export and then dies at COM teardown: the finisher reported FAILED while a correct 383-page PDF sat on disk. Read the filesystem before you believe the exception.'
        }
    }
}

# ---------------------------------------------------------------------------
# GH08 - portability
# ---------------------------------------------------------------------------

function Get-IdentityLeafValue {
    <#  Values held under the property names a branding profile uses for
        IDENTITY, at any depth.

        Scoped by SCHEMA, not by a typed list of brand values: the gate is
        shared across RTOs, so what is forbidden has to be read off whatever
        profiles are on disk. This is the same derivation Check-Identity uses
        for its forbidden set.  #>
    param($Node, $Bag, [int] $Depth = 0)
    if ($Depth -gt 8 -or $null -eq $Node) { return }
    if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string])) {
        foreach ($item in $Node) { Get-IdentityLeafValue -Node $item -Bag $Bag -Depth ($Depth + 1) }
        return
    }
    if ($Node -is [psobject] -and $null -ne $Node.PSObject) {
        foreach ($p in $Node.PSObject.Properties) {
            if ([regex]::IsMatch("$($p.Name)", '(?i)^(tradingName|legalEntity|shortName|longName|rtoCode|cricosCode|providerCode|provider|website|domain|email|abn|acn|campus|brandName|displayName)$')) {
                if ($p.Value -is [string]) {
                    $sv = "$($p.Value)".Trim()
                    if ($sv.Length -ge 6) { [void]$Bag.Add($sv) }
                }
            }
            Get-IdentityLeafValue -Node $p.Value -Bag $Bag -Depth ($Depth + 1)
        }
    }
}

function Get-BrandIdentityValue {
    <#  Every identity string any branding profile on disk carries.

        DERIVED, not typed: this gate is shared across RTOs and brands, and a
        portability check that hard-codes the brand it hunts is the defect it
        is looking for.  #>
    param([string] $Skill)
    $bag = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    if (-not $Skill) { return $bag }
    #  The branding profiles do not necessarily live in THIS skill. The RTO
    #  profile pack names a brandingFile and says it is resolved in the skill
    #  that owns the branding profiles, so the search walks the sibling skills
    #  too. Nothing here names a skill, a brand or a path.
    $searchRoots = New-Object System.Collections.Generic.List[string]
    $searchRoots.Add((Join-Path $Skill 'assets'))
    $parent = Split-Path -Parent $Skill
    if ($parent -and (Test-Path -LiteralPath $parent)) {
        $sibs = @()
        try { $sibs = @(Get-ChildItem -LiteralPath $parent -Directory -ErrorAction Stop) }
        catch { $sibs = @() }
        foreach ($s in $sibs) { $searchRoots.Add((Join-Path $s.FullName 'assets')) }
    }
    $jsons = @()
    foreach ($assetDir in $searchRoots) {
        if (-not (Test-Path -LiteralPath $assetDir)) { continue }
        try { $jsons += @(Get-ChildItem -LiteralPath $assetDir -Filter '*.json' -File -Recurse -Depth 2 -ErrorAction Stop) }
        catch { }
    }
    if ($jsons.Count -gt 0) {
        foreach ($j in $jsons) {
            $obj = $null
            try { $obj = (Read-HygieneText -File $j.FullName | ConvertFrom-Json) }
            catch { $obj = $null }
            if ($null -eq $obj) { continue }
            $inner = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
            Get-IdentityLeafValue -Node $obj -Bag $inner
            foreach ($v in $inner) {
                #  Only values long enough and specific enough to be identity.
                if ($v.Length -lt 6) { continue }
                if ($v -notmatch '[A-Za-z]') { continue }
                if ($v -match '^(?i)(true|false|null|default|primary|secondary)$') { continue }
                [void]$bag.Add($v)
            }
        }
    }
    return $bag
}

function Invoke-RuleGH08 {
    param($Ctx)

    #  Tokens, not source text, so a literal in code can be told from a literal
    #  in a comment. A unit code in a comment is documentation; a unit code in
    #  a string is a gate that only works on one build.
    $probes = New-Object System.Collections.Generic.List[object]
    $probes.Add([pscustomobject]@{ Rx = '\b[A-Z]{3,6}[0-9]{3}[A-Z]?\b'; What = 'looks like a training-package unit code' })
    $probes.Add([pscustomobject]@{ Rx = '\b[0-9]{5}[A-Z]\b'; What = 'looks like a CRICOS course code' })
    $probes.Add([pscustomobject]@{ Rx = '(?i)(?<![0-9A-Za-z])#[0-9A-Fa-f]{6}(?![0-9A-Za-z])'; What = 'a six-digit hex colour' })
    $probes.Add([pscustomobject]@{ Rx = '(?<![0-9A-Za-z])[0-9A-Fa-f]{6}(?![0-9A-Za-z])'; What = 'six hex digits - a palette colour if it is one' })
    #  A markup prefix like the one in a slide-layout close tag is not a drive
    #  letter. The lookbehind keeps markup out, and a real path segment does
    #  not start with a digit.
    $probes.Add([pscustomobject]@{ Rx = '(?i)(?<![0-9A-Za-z/\\<:])[a-z]:[\\/](?![0-9])'; What = 'an absolute path with a drive letter' })
    $probes.Add([pscustomobject]@{ Rx = '^\\\\[A-Za-z0-9]'; What = 'a UNC path' })

    #  A downgrade, never a suppression: these shapes are indistinguishable from
    #  a unit code, so they are reported SUSPECTED and a reader decides.
    $noiseRx = '^(SHA|MD|CRC|RGB|RGBA|CMYK|UTF|ISO|RFC|CP|DPI|EMU|PX|PT|HTTP|HTTPS|TLS|AES|BOM|XML|OOXML|WCAG)[0-9]'

    $identity = $Ctx.Identity

    foreach ($tok in $Ctx.Tokens) {
        $kind = "$($tok.Kind)"
        $isString = ($kind -match '(?i)^(StringLiteral|StringExpandable|HereString)')
        $isComment = ($kind -ieq 'Comment')
        if (-not $isString -and -not $isComment) { continue }
        $text = "$($tok.Text)"
        if ($text.Length -lt 4) { continue }
        $line = $tok.Extent.StartLineNumber
        if (Test-InExemptRegion -Regions $Ctx.Exempt -Line $line) { continue }

        foreach ($probe in $probes) {
            $ms = [regex]::Matches($text, $probe.Rx)
            foreach ($m in $ms) {
                $hit = $m.Value
                $st = 'CONFIRMED'
                if ($isComment) { $st = 'SUSPECTED' }
                if ([regex]::IsMatch($probe.What, 'unit code') -and [regex]::IsMatch($hit, $noiseRx)) { $st = 'SUSPECTED' }
                if ([regex]::IsMatch($probe.What, 'six hex digits')) {
                    $hasDigit = [regex]::IsMatch($hit, '[0-9]')
                    $hasAf = [regex]::IsMatch($hit, '(?i)[a-f]')
                    if (-not ($hasDigit -and $hasAf)) { $st = 'SUSPECTED' }
                }
                Add-HygieneFinding -Rule 'GH08' -File $Ctx.File -Line $line -Snippet ("{0}  ->  {1}" -f $hit, (Get-ShortText -Value $text -Max 90)) -Status $st `
                    -Detail ("{0}. No gate may carry a literal unit code, RTO code, CRICOS code, provider number, six-digit hex or absolute path: identity comes from the branding profile, counts from the build contract, filenames from the unit code." -f $probe.What)
            }
        }

        if ($null -ne $identity) {
            foreach ($v in $identity) {
                if ($text.IndexOf($v, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
                $st = 'CONFIRMED'
                if ($isComment) { $st = 'SUSPECTED' }
                Add-HygieneFinding -Rule 'GH08' -File $Ctx.File -Line $line -Snippet (Get-ShortText -Value $text -Max 90) -Status $st `
                    -Detail ("carries an identity string that a branding profile on disk also carries ({0} characters). Resolve it from the profile." -f $v.Length)
                break
            }
        }
    }
}

# ---------------------------------------------------------------------------
# The engine
# ---------------------------------------------------------------------------

function Invoke-HygieneOnFile {
    param(
        [Parameter(Mandatory)][string] $File,
        $Truth,
        $Identity,
        [string[]] $RuleFilter
    )

    if (-not (Test-Path -LiteralPath $File)) {
        Add-HygieneFinding -Rule 'GH00' -File $File -Line 0 -Snippet '(vanished)' -Status 'SUSPECTED' `
            -Detail 'the file was in the discovered set and was gone when it was read. Another build is writing this directory; re-run to cover it.'
        return
    }

    $src = ''
    try { $src = Read-HygieneText -File $File }
    catch {
        Add-HygieneFinding -Rule 'GH00' -File $File -Line 0 -Snippet (Get-ShortText -Value $_.Exception.Message) -Status 'SUSPECTED' -Detail 'unreadable'
        return
    }
    if (-not $src.Trim()) { return }

    $lines = $src -split "`r?`n"
    $tokens = $null
    $errors = $null
    $ast = $null
    try { $ast = [System.Management.Automation.Language.Parser]::ParseFile($File, [ref]$tokens, [ref]$errors) }
    catch {
        Add-HygieneFinding -Rule 'GH00' -File $File -Line 0 -Snippet (Get-ShortText -Value $_.Exception.Message) -Status 'CONFIRMED' -Detail 'the parser threw on this file'
        return
    }
    if ($null -ne $errors -and $errors.Count -gt 0) {
        foreach ($e in $errors) {
            Add-HygieneFinding -Rule 'GH00' -File $File -Line $e.Extent.StartLineNumber -Snippet (Get-ShortText -Value $e.Message) -Status 'CONFIRMED' `
                -Detail 'this script does not parse, so it cannot fail on anything.'
        }
        return
    }

    $exempt = Get-ExemptRegion -File $File -Lines $lines

    $ctx = [pscustomobject]@{
        File     = $File
        Source   = $src
        Lines    = $lines
        Ast      = $ast
        Tokens   = $tokens
        Exempt   = $exempt
        Truth    = $Truth
        Identity = $Identity
    }

    #  The rule set is DERIVED from the rule table above, so adding a rule
    #  there is enough to have it run. A second, hand-typed list here is the
    #  exact failure class this gate hunts.
    $all = New-Object System.Collections.Generic.List[string]
    foreach ($rt in $script:RuleTable) { if ($rt.Id -ne 'GH00') { $all.Add($rt.Id) } }
    foreach ($id in $all) {
        if ($null -ne $RuleFilter -and $RuleFilter.Count -gt 0) {
            $wanted = $false
            foreach ($w in $RuleFilter) { if ("$w" -ieq $id) { $wanted = $true } }
            if (-not $wanted) { continue }
        }
        try { & ("Invoke-Rule" + $id) -Ctx $ctx }
        catch {
            Add-HygieneFinding -Rule $id -File $File -Line 0 -Snippet (Get-ShortText -Value $_.Exception.Message) -Status 'SUSPECTED' `
                -Detail 'the rule threw on this file; it did NOT clear it.'
        }
    }
}

# ---------------------------------------------------------------------------
# Self-test - plant every pattern, verify the plant landed, then detect
# ---------------------------------------------------------------------------

function New-FixtureGateScript {
    <#  Write one fixture gate carrying exactly one planted pattern, then READ
        IT BACK and confirm the plant is in the file. A plant that did not land
        proves nothing and passes - which is how a gate was recorded as proven
        while 766 real hits shipped under it.  #>
    param(
        [Parameter(Mandatory)][string] $Dir,
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][string] $Body,
        [Parameter(Mandatory)][string] $PlantProof
    )
    $f = Join-Path $Dir ($Name + '.ps1')
    Write-HygieneText -File $f -Body $Body
    $back = Read-HygieneText -File $f
    $landed = ($back.IndexOf($PlantProof, [System.StringComparison]::Ordinal) -ge 0)
    $tk = $null; $er = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$tk, [ref]$er)
    $parses = ($null -eq $er -or $er.Count -eq 0)
    return [pscustomobject]@{ File = $f; Landed = $landed; Parses = $parses }
}

function Invoke-HygieneSelfTest {
    param([string] $Skill)

    $ok = 0
    $bad = 0
    function TOk  ($m) { $script:stPass++; Write-Host "  PASS  $m" -ForegroundColor Green }
    function TBad ($m) { $script:stFail++; Write-Host "  FAIL  $m" -ForegroundColor Red }
    $script:stPass = 0
    $script:stFail = 0

    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('gatehyg_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $fixDir = Join-Path $tmp 'scripts'
    $refDir = Join-Path $tmp 'references'
    New-Item -ItemType Directory -Force -Path $fixDir | Out-Null
    New-Item -ItemType Directory -Force -Path $refDir | Out-Null

    try {
        #  A source of truth for the hand-listing rule, written beside the
        #  fixtures so the rule has a real map to compare a literal against.
        $cfgFile = Join-Path $refDir 'fixture-config.json'
        Write-HygieneText -File $cfgFile -Body '{ "channels": [ "guidebody", "deckslide", "figuresheet", "agentpack", "speakernotes" ] }'

        # gate-exempt: the fixture gate bodies below MUST carry the literals this gate hunts - a planted unit code, a planted drive-letter path, a planted allow-list default - or there is nothing for the rules to find. They are inert here-strings written to a temp directory and deleted when the self-test ends.
        $fixtures = New-Object System.Collections.Generic.List[object]

        $fixtures.Add([pscustomobject]@{
            Rule  = 'GH01'
            Name  = 'Fixture-BlockingBehindOptional'
            Proof = 'foreach ($t in @($DocText))'
            Body  = @'
<#  Fixture gate. The rendered-text sweep below is BLOCKING. #>
param([string] $BuildDir, [string[]] $DocText)
$hits = 0
foreach ($t in @($DocText)) { if ($t) { $hits++ } }
Write-Host ('swept {0}' -f $hits)
exit 0
'@
        })

        $fixtures.Add([pscustomobject]@{
            Rule  = 'GH02'
            Name  = 'Fixture-HandListedCheckSet'
            Proof = "'guidebody', 'deckslide'"
            Body  = @'
<# Fixture gate. #>
param([string] $BuildDir)
$channels = @('guidebody', 'deckslide')
Write-Host ('checked {0}' -f $channels.Count)
exit 0
'@
        })

        $fixtures.Add([pscustomobject]@{
            Rule  = 'GH03'
            Name  = 'Fixture-PassOnMissingInput'
            Proof = "Write-Host 'PASS - nothing to check'"
            Body  = @'
<# Fixture gate. #>
param([string] $BuildDir, [string[]] $Extract)
if (-not $Extract) { Write-Host 'PASS - nothing to check'; exit 0 }
Write-Host 'checked'
exit 0
'@
        })

        $fixtures.Add([pscustomobject]@{
            Rule  = 'GH04'
            Name  = 'Fixture-CountAsPresence'
            Proof = '@($doc.grids).Count -gt 0'
            Body  = @'
<# Fixture gate. #>
param([string] $BuildDir)
$doc = [pscustomobject]@{ }
if (@($doc.grids).Count -gt 0) { Write-Host 'has grids' }
exit 0
'@
        })

        $fixtures.Add([pscustomobject]@{
            Rule  = 'GH05'
            Name  = 'Fixture-UnanchoredMatch'
            Proof = '$body -replace $needle'
            Body  = @'
<# Fixture gate. #>
param([string] $BuildDir, [string] $Needle)
$body = 'some domain text'
$needle = $Needle
$out = $body -replace $needle, 'x'
Write-Host $out
exit 0
'@
        })

        $fixtures.Add([pscustomobject]@{
            Rule  = 'GH06'
            Name  = 'Fixture-AllowListInParamDefault'
            Proof = "[string[]] `$Allow = @('4.1.4')"
            Body  = @'
<# Fixture gate. #>
param([string] $BuildDir, [string[]] $Allow = @('4.1.4'))
Write-Host ('allowed {0}' -f $Allow.Count)
exit 0
'@
        })

        $fixtures.Add([pscustomobject]@{
            Rule  = 'GH07'
            Name  = 'Fixture-ExceptionOverFilesystem'
            Proof = "Write-Host 'FAILED'"
            Body  = @'
<# Fixture gate. #>
param([string] $Guide)
try {
    $app = New-Object -ComObject Word.Application
    $app.Quit()
}
catch {
    Write-Host 'FAILED'
    exit 4
}
exit 0
'@
        })

        $fixtures.Add([pscustomobject]@{
            Rule  = 'GH08'
            Name  = 'Fixture-Portability'
            Proof = "'SITXFSA005'"
            Body  = @'
<# Fixture gate. #>
param()
$unit = 'SITXFSA005'
$root = 'D:\builds\resource'
Write-Host ('{0} {1}' -f $unit, $root)
exit 0
'@
        })

        $fixtures.Add([pscustomobject]@{
            Rule  = 'BASELINE'
            Name  = 'Fixture-Clean'
            Proof = 'REFUSE - no declared sources'
            Body  = @'
<#  Fixture gate that is written the way the rules ask. Nothing here may fire.  #>
param([Parameter(Mandatory)][string] $BuildDir)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $BuildDir)) { Write-Host 'REFUSE - no build directory'; exit 2 }
$declared = New-Object System.Collections.Generic.List[string]
foreach ($f in Get-ChildItem -LiteralPath $BuildDir -Filter '*.json' -File) { $declared.Add($f.Name) }
if ($declared.Count -lt 1) { Write-Host 'REFUSE - no declared sources'; exit 2 }
Write-Host ('checked {0} declared sources' -f $declared.Count)
exit 0
'@
        })

        # gate-exempt-end
        Write-Host ''
        Write-Host 'SELF-TEST - plant each pattern, prove the plant landed, then detect it' -ForegroundColor Cyan

        $made = @{}
        foreach ($fx in $fixtures) {
            $r = New-FixtureGateScript -Dir $fixDir -Name $fx.Name -Body $fx.Body -PlantProof $fx.Proof
            $made[$fx.Rule] = $r
            if (-not $r.Landed) { TBad ("{0}: the plant did NOT land in {1} - nothing below proves anything" -f $fx.Rule, $fx.Name); continue }
            if (-not $r.Parses) { TBad ("{0}: fixture {1} does not parse" -f $fx.Rule, $fx.Name); continue }
            TOk ("{0}: plant landed and parses ({1})" -f $fx.Rule, $fx.Name)
        }

        $truth = Get-HygieneSourceOfTruth -Skill $tmp -Build '' -ExtraDir @()
        $identity = Get-BrandIdentityValue -Skill $Skill

        foreach ($fx in $fixtures) {
            $r = $made[$fx.Rule]
            if ($null -eq $r -or -not $r.Landed) { continue }
            $script:Findings = New-Object System.Collections.Generic.List[object]
            $script:ExemptionsUsed = New-Object System.Collections.Generic.List[object]
            Invoke-HygieneOnFile -File $r.File -Truth $truth -Identity $identity -RuleFilter @()
            if ($fx.Rule -eq 'BASELINE') {
                if ($script:Findings.Count -eq 0) { TOk 'the baseline fixture fires no rule' }
                else {
                    $names = (($script:Findings | ForEach-Object { "$($_.Rule)@$($_.Line)" }) -join ', ')
                    TBad ("the baseline fixture fired: {0}" -f $names)
                }
                continue
            }
            $fired = $false
            foreach ($f in $script:Findings) { if ($f.Rule -eq $fx.Rule) { $fired = $true } }
            if ($fired) { TOk ("{0} fires on its own planted fixture" -f $fx.Rule) }
            else { TBad ("{0} did NOT fire on a verified plant of its own pattern" -f $fx.Rule) }
        }

        #  A rule must also be reachable through the discovery path, not only
        #  through a direct file call.
        $script:Findings = New-Object System.Collections.Generic.List[object]
        $set = Get-HygieneTargetSet -Skill $tmp -Build ''
        if ($set.Count -ge 9) { TOk ("discovery enumerates {0} fixture gates from the filesystem, with no list typed anywhere" -f $set.Count) }
        else { TBad ("discovery found only {0} fixture gates" -f $set.Count) }
    }
    finally {
        $script:Findings = New-Object System.Collections.Generic.List[object]
        $script:ExemptionsUsed = New-Object System.Collections.Generic.List[object]
        if ((Test-Path -LiteralPath $tmp) -and $tmp.Length -gt 12) {
            Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host ''
    if ($script:stFail -eq 0) {
        Write-Host ("SELF-TEST PASS - {0} checks. Every rule was proven to fire on a verified plant, and the baseline fixture fired nothing." -f $script:stPass) -ForegroundColor Green
        return 0
    }
    Write-Host ("SELF-TEST FAIL - {0} of {1} checks failed. This gate is not evidence of anything until they pass." -f $script:stFail, ($script:stFail + $script:stPass)) -ForegroundColor Red
    return 4
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if ($SelfTest) {
    $rc = Invoke-HygieneSelfTest -Skill $SkillDir
    exit $rc
}

if (-not $SkillDir -or -not (Test-Path -LiteralPath $SkillDir)) {
    Write-Host ("{0}: -SkillDir '{1}' does not exist. This gate refuses rather than reporting a clean set it never read." -f $GATE, $SkillDir) -ForegroundColor Red
    exit 2
}

$Only = Expand-CommaList -Value $Only
$Path = Expand-CommaList -Value $Path
$targets = @()
if ($null -ne $Path -and $Path.Count -gt 0) {
    $lst = New-Object System.Collections.Generic.List[object]
    foreach ($p in $Path) {
        if (-not (Test-Path -LiteralPath $p)) { continue }
        $fi = Get-Item -LiteralPath $p
        $lst.Add([pscustomobject]@{ Name = $fi.BaseName; File = $fi.FullName; Origin = 'explicit'; Length = $fi.Length; Mtime = $fi.LastWriteTimeUtc })
    }
    $targets = $lst.ToArray()
}
else {
    $targets = Get-HygieneTargetSet -Skill $SkillDir -Build $BuildDir
}

if ($targets.Count -eq 0) {
    Write-Host ("{0}: no gate script found under '{1}'. A hygiene sweep over nothing is not a pass." -f $GATE, $SkillDir) -ForegroundColor Red
    exit 2
}

$partial = $false
if ($null -ne $Only -and $Only.Count -gt 0) { $partial = $true }

if (-not $Quiet) {
    Write-Host ''
    Write-Host ('GATE HYGIENE - {0}' -f $GATE) -ForegroundColor Cyan
    Write-Host ('  check-set: {0} gate scripts, derived from {1}{2}' -f $targets.Count, (Join-Path $SkillDir 'scripts'), $(if ($BuildDir) { " plus build-local Check-/Test- scripts in $BuildDir" } else { '' })) -ForegroundColor DarkGray
    Write-Host ('  rules: {0}, each named with the incident it exists for' -f $script:RuleTable.Count) -ForegroundColor DarkGray
    if ($partial) {
        Write-Host ''
        Write-Host ('  PARTIAL RUN - only {0}. This cannot stand for the hygiene gate.' -f ($Only -join ', ')) -ForegroundColor Yellow
    }
}

$truth = Get-HygieneSourceOfTruth -Skill $SkillDir -Build $BuildDir
$identity = Get-BrandIdentityValue -Skill $SkillDir
$identityActive = ($identity.Count -gt 0)
if (-not $Quiet) {
    Write-Host ('  sources of truth: {0} config/profile/registry files, {1} identity strings' -f $truth.Count, $identity.Count) -ForegroundColor DarkGray
}
if (-not $identityActive) {
    #  A forbidden set of zero is not a clean sweep. The gate that this rule
    #  exists for hand-listed three of nine hexes and printed "no crossover"
    #  over 766 live hits; a portability arm with an EMPTY derived set would do
    #  the same thing with more conviction. So it says so, and the run cannot
    #  stand for the whole gate.
    Write-Host ''
    Write-Host '  IDENTITY ARM INACTIVE - no branding profile was found, so the derived-identity arm of GH08 checked nothing. Its pattern arms (unit, CRICOS, hex, path) still ran. This run cannot stand for the portability rule.' -ForegroundColor Yellow
    $partial = $true
}

$startedAt = Get-Date
$scanned = New-Object System.Collections.Generic.List[object]
foreach ($t in $targets) {
    try {
        Invoke-HygieneOnFile -File $t.File -Truth $truth -Identity $identity -RuleFilter $Only
        $scanned.Add($t)
    }
    catch {
        Add-HygieneFinding -Rule 'GH00' -File $t.File -Line 0 -Snippet (Get-ShortText -Value $_.Exception.Message) -Status 'SUSPECTED' -Detail 'the sweep threw on this file; it was NOT cleared.'
    }
}

#  Another build may be writing this directory while this runs. Say what moved
#  rather than letting a clean report stand for a file nobody read.
$moved = New-Object System.Collections.Generic.List[string]
if ($null -eq $Path -or $Path.Count -eq 0) {
    $after = Get-HygieneTargetSet -Skill $SkillDir -Build $BuildDir
    $beforeMap = @{}
    foreach ($t in $targets) { $beforeMap[$t.File] = $t }
    foreach ($a in $after) {
        if (-not $beforeMap.ContainsKey($a.File)) { $moved.Add(("APPEARED  {0}" -f $a.Name)); continue }
        $b = $beforeMap[$a.File]
        if ($b.Length -ne $a.Length -or $b.Mtime -ne $a.Mtime) { $moved.Add(("REWRITTEN {0}" -f $a.Name)) }
    }
    $afterMap = @{}
    foreach ($a in $after) { $afterMap[$a.File] = $a }
    foreach ($t in $targets) { if (-not $afterMap.ContainsKey($t.File)) { $moved.Add(("VANISHED  {0}" -f $t.Name)) } }
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

$sorted = @($script:Findings | Sort-Object Rank, Rule, Gate, Line)
$confirmed = @($sorted | Where-Object { $_.Status -eq 'CONFIRMED' })
$suspected = @($sorted | Where-Object { $_.Status -eq 'SUSPECTED' })

if (-not $Quiet) {
    Write-Host ''
    Write-Host ('  scanned {0} scripts in {1:n1}s' -f $scanned.Count, ((Get-Date) - $startedAt).TotalSeconds) -ForegroundColor DarkGray

    if ($script:ExemptionsUsed.Count -gt 0) {
        Write-Host ''
        Write-Host '  DECLARED EXEMPTIONS USED (evidence, never silent):' -ForegroundColor Yellow
        foreach ($e in $script:ExemptionsUsed) {
            Write-Host ("    {0}:{1}-{2}  {3}" -f [System.IO.Path]::GetFileName($e.File), $e.Start, $e.End, (Get-ShortText -Value $e.Reason -Max 100)) -ForegroundColor Yellow
        }
    }

    Write-Host ''
    Write-Host 'WORK ORDER - findings by severity. Nothing here has been changed.' -ForegroundColor Cyan
    $lastRule = ''
    foreach ($f in $sorted) {
        if ($f.Rule -ne $lastRule) {
            $lastRule = $f.Rule
            $meta = $null
            foreach ($r in $script:RuleTable) { if ($r.Id -eq $f.Rule) { $meta = $r } }
            Write-Host ''
            Write-Host ("  {0}  {1}" -f $f.Rule, $f.RuleName) -ForegroundColor White
            if ($null -ne $meta) { Write-Host ("      incident: {0}" -f (Get-ShortText -Value $meta.Incident -Max 240)) -ForegroundColor DarkGray }
        }
        $colour = 'Red'
        if ($f.Status -eq 'SUSPECTED') { $colour = 'Yellow' }
        Write-Host ("    [{0}] {1}:{2}  {3}" -f $f.Severity, $f.Gate, $f.Line, $f.Snippet) -ForegroundColor $colour
        Write-Host ("        {0} - {1}" -f $f.Status, (Get-ShortText -Value $f.Detail -Max 260)) -ForegroundColor DarkGray
    }

    if ($moved.Count -gt 0) {
        Write-Host ''
        Write-Host '  MOVED DURING THE RUN - these are not covered by this report:' -ForegroundColor Yellow
        foreach ($m in $moved) { Write-Host ("    {0}" -f $m) -ForegroundColor Yellow }
    }
}

if ($ResultDir) {
    if (-not (Test-Path -LiteralPath $ResultDir)) { New-Item -ItemType Directory -Force -Path $ResultDir | Out-Null }
    $body = [ordered]@{
        gate        = $GATE
        checkedAt   = (Get-Date).ToString('o')
        skillDir    = "$SkillDir"
        buildDir    = "$BuildDir"
        partialRun  = $partial
        identityArmActive = $identityActive
        identityStrings   = $identity.Count
        onlyRules   = @($Only)
        scriptCount = $scanned.Count
        scripts     = @($scanned | ForEach-Object { $_.Name })
        ruleCount   = $script:RuleTable.Count
        rules       = @($script:RuleTable)
        confirmed   = $confirmed.Count
        suspected   = $suspected.Count
        findings    = @($sorted)
        exemptions  = $script:ExemptionsUsed.ToArray()
        movedDuringRun = $moved.ToArray()
    }
    Write-HygieneText -File (Join-Path $ResultDir 'gate-hygiene.json') -Body (($body | ConvertTo-Json -Depth 6))
}

Write-Host ''
if ($partial) {
    $why = 'rules ' + ($Only -join ',') + ' only'
    if (-not $identityActive) { $why = 'the derived-identity arm could not run' }
    Write-Host ("PARTIAL RUN - {0} CONFIRMED, {1} SUSPECTED over {2} scripts; {3}. A partial run cannot stand for the hygiene gate." -f $confirmed.Count, $suspected.Count, $scanned.Count, $why) -ForegroundColor Yellow
    if ($confirmed.Count -gt 0) { exit 1 }
    exit 3
}
if ($confirmed.Count -gt 0) {
    Write-Host ("HYGIENE FAIL - {0} CONFIRMED and {1} SUSPECTED findings over {2} gate scripts. Each is a work order against a named file and line; do not silence a finding by rewriting the gate." -f $confirmed.Count, $suspected.Count, $scanned.Count) -ForegroundColor Red
    exit 1
}
Write-Host ("HYGIENE PASS - no CONFIRMED finding over {0} gate scripts ({1} SUSPECTED for a reader)." -f $scanned.Count, $suspected.Count) -ForegroundColor Green
exit 0
