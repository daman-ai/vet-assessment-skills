<#
    Assert-EnumerateBeforeFix.ps1 - a remediation round may not BEGIN with
    prose edits.

    Implements section 32 of references\gates.md, and step 2 of SKILL.md's
    Stage 7. Runs at Stage 7, every round. Blocking.

    THE ORDER THAT WORKS, AND THE ONE THAT FAILED THREE ROUNDS IN A ROW.
    Registry first, then a MACHINE-GENERATED hit list across every content
    channel of both artefacts, then the edits, then run to zero. A round that
    starts by rewriting sentences fixes the instance in front of the author and
    misses its siblings. On the build this gate was written from, round 1 fixed
    the prose and left the diagram specs, round 2 fixed the guide and left the
    deck, and round 3 fixed a literal string and missed its four spelled-out
    variants. Each of those cost a full audit-remediate-re-render-re-audit
    cycle, and nothing in the pipeline could see any of them, because a fix by
    eye and a fix from an enumeration produce identical-looking green gates.

    WHAT IT PROVES, and it proves it from the FILESYSTEM and from CONTENT,
    never from a sentence in a ledger note:

      A  an enumeration exists for the round's finding(s), was machine
         generated, and is named where a later reader can find it - in the
         Stage 7 ledger note, in the registry, or on the command line.
      B  the enumeration PREDATES every edit the round made. This is the
         headline rule: an enumeration produced after the fix is a receipt,
         not a work order.
      C  every location the round edited is named by an enumeration, or
         carries a written reason in the registry's allow-list. An edit
         nobody enumerated is a fix by eye - that is the whole failure class.
      D  every enumerated location was cleared. Cleared is a CONTENT test -
         the stale token is gone from that location - not a timestamp. A
         location still carrying its token is a FAIL unless the registry
         records a written reason for leaving it.
      E  the enumeration records WHICH CHANNELS it covered, and they are all
         of them. "Fixed the guide and left the deck" is a channel-coverage
         defect, and a sweep that never says what it swept cannot be shown to
         have swept anything.

    WHAT IT DOES NOT DO. It gates the PROCESS, not the content: whether the
    corrected value is right is Stage 6's job. There is no allow-list on the
    process itself; the only allow-list is the registry's written reason for
    an enumerated location deliberately left alone, read through the shared
    Get-GateAllowList, which refuses an entry that gives no reason.

    HOW THE ROUND'S EDITS ARE DETERMINED. With -Baseline (a pre-round copy of
    the spine) the edits are computed by CONTENT, per file and per field, the
    way Assert-RenderDelta computes a render delta. Without one they are
    computed from file mtimes inside the round's ledger window, and the report
    says so. A window narrower than a minute means the ledger records were
    batch-written - the signature section 34 names - and the gate REFUSES to
    attribute edits rather than passing vacuously.

    NOTHING QUOTED. A hit's token can be an assessor benchmark: an audit
    report quoting one is how a benchmark got pasted into a learner document
    on this project. So this gate prints a token's SHA-8 and its length, never
    its text, in the console and in the report alike.

    Nothing here is a literal from any unit, brand, RTO or path. The content
    channels are derived from the spine itself, from the registry gate's own
    source-scoping rule and from the runner's own extract names.

    Usage
      Assert-EnumerateBeforeFix.ps1 -BuildDir <dir> [-Finding <id>] [-Round <n>]
                                    [-Enumeration <file>...] [-Baseline <spineCopy>]
      Assert-EnumerateBeforeFix.ps1 -SelfTest        no build, no Office, no API

    PS 5.1. ASCII only in this file. UTF-8 BOM required on disk.
    Exit 0 pass; 1 a blocking finding; 2 a usage error or a refusal; 4 the
    self-test failed.
#>

[CmdletBinding()]
param(
    [string] $BuildDir,
    #  One finding id. Omitted, every finding the round enumerated is checked -
    #  the rule does not weaken when the parameter is absent, it widens.
    [string] $Finding,
    #  The remediation round. Omitted, the highest Stage 7 round in the ledger.
    [int]    $Round = 0,
    [string] $SkillDir,
    [string] $SpineDir,
    #  Hit-list files, where the ledger note does not name them.
    [string[]] $Enumeration,
    #  A copy of the spine as it stood BEFORE the round. With it, the edited
    #  set is computed from content per field; without it, from mtimes.
    [string] $Baseline,
    [string] $RulesPath,
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
#  Dot-sourcing a script that has a param block binds ITS parameters in THIS
#  scope, so the value must be passed through or $BuildDir is blanked.
. (Join-Path $PSScriptRoot 'Stage-Ledger.ps1') -BuildDir $BuildDir

$GATE = 'Assert-EnumerateBeforeFix'

# ---------------------------------------------------------------------------
# 0. Small shared pieces, defined privately here rather than in the library
# ---------------------------------------------------------------------------

function AsArray {
    <#  @($null).Count is 1, not 0, so a null must be turned into an empty
        array BEFORE anything counts it. Every presence test in this file goes
        through here.  #>
    param($Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) { return @($Value) }
    if ($Value -is [System.Collections.IEnumerable]) { return @($Value | Where-Object { $null -ne $_ }) }
    return @($Value)
}

function Get-TokenDigest {
    <#  A token is never printed. An audit report quoting an assessor
        benchmark is how a benchmark reached a learner document on this
        project, and a hit list is full of exactly those strings. So a token
        is identified by hash and length, which is enough to match two reports
        to each other and tells a reader nothing they must not read.  #>
    param([string] $Text)
    if ($null -eq $Text) { $Text = '' }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $h = [BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text))).Replace('-', '').ToLower()
        return ("#{0} ({1} chars)" -f $h.Substring(0, 8), $Text.Length)
    }
    finally { $sha.Dispose() }
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
    if ($null -eq $Value) { return '(none)' }
    return ([datetime]$Value).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
}

function Write-Line {
    param([string] $Text, [string] $Colour = 'DarkGray')
    if (-not $Quiet) { Write-Host $Text -ForegroundColor $Colour }
}

# ---------------------------------------------------------------------------
# 1. The content channels - DERIVED, never typed
#
#  Three families, and the round failures this gate exists for are one per
#  family: the spine (prose fixed, diagram specs left), the build scripts
#  (a renderer literal nobody swept), and the rendered text of BOTH artefacts
#  (guide fixed, deck left).
# ---------------------------------------------------------------------------

function Get-ScriptSourceText {
    param([Parameter(Mandatory)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    return [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path, [System.Text.Encoding]::UTF8).TrimStart([char]0xFEFF)
}

function Get-BuildScriptExclusionRx {
    <#  The registry gate decides which build scripts are content sources and
        which are meta. That decision is ITS rule, so it is read out of its
        source rather than copied here - a copied rule is a second source of
        truth, and a second source of truth drifts.  #>
    param([Parameter(Mandatory)][string] $ScriptsDir)
    $src = Get-ScriptSourceText -Path (Join-Path $ScriptsDir 'Test-FigureConsistency.ps1')
    if ($src) {
        $m = [regex]::Match($src, "\`$f\.Name\s+-match\s+'([^']+)'\s*\)\s*\{\s*continue")
        if ($m.Success) {
            return [pscustomobject]@{ Rx = $m.Groups[1].Value; From = 'Test-FigureConsistency.ps1, its own source-scoping rule' }
        }
    }
    return [pscustomobject]@{ Rx = '^$'; From = 'NOT DERIVABLE - the registry gate did not yield its exclusion rule, so no build script is excluded (over-inclusion is the safe direction)' }
}

function Get-RunnerExtractName {
    <#  The rendered-text channel names, read from the runner that writes them.
        Run-Gates assigns them as $guideText / $deckText = Join-Path $BuildDir
        '<name>'; whatever it calls them today is what this gate looks for.  #>
    param([Parameter(Mandatory)][string] $ScriptsDir)
    $out = [ordered]@{}
    $src = Get-ScriptSourceText -Path (Join-Path $ScriptsDir 'Run-Gates.ps1')
    foreach ($m in [regex]::Matches($src, "\`$(\w*[Tt]ext)\s*=\s*Join-Path\s+\`$BuildDir\s+'([^']+)'")) {
        $out[$m.Groups[1].Value] = $m.Groups[2].Value
    }
    return $out
}

function Get-ContentChannel {
    <#  Every file a corrected figure can survive in, and the fine-grained
        spine channels underneath. Returns the file index the arms work over.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [string] $SpineDir,
        [Parameter(Mandatory)][string] $ScriptsDir
    )

    $files = New-Object System.Collections.Generic.List[object]

    # --- the spine
    $spineFiles = @(Get-GateSpineFiles -BuildDir $BuildDir -SpineDir $SpineDir)
    foreach ($f in $spineFiles) {
        $files.Add([pscustomobject]@{ Name = $f.Name; Path = $f.FullName; Family = 'spine' })
    }

    # --- the build scripts, scoped by the registry gate's own rule
    $ex = Get-BuildScriptExclusionRx -ScriptsDir $ScriptsDir
    foreach ($f in (Get-ChildItem -LiteralPath $BuildDir -Filter '*.ps1' -File -ErrorAction SilentlyContinue)) {
        if ($ex.Rx -ne '^$' -and $f.Name -match $ex.Rx) { continue }
        $files.Add([pscustomobject]@{ Name = $f.Name; Path = $f.FullName; Family = 'buildScripts' })
    }

    # --- the rendered text of BOTH artefacts
    $extracts = Get-RunnerExtractName -ScriptsDir $ScriptsDir
    $renderedFamilies = New-Object System.Collections.Generic.List[string]
    foreach ($k in $extracts.Keys) {
        $p = Join-Path $BuildDir $extracts[$k]
        $fam = 'rendered:' + $k
        $renderedFamilies.Add($fam)
        $files.Add([pscustomobject]@{ Name = $extracts[$k]; Path = $p; Family = $fam })
    }

    # --- the fine spine channels, from the spine's own top-level fields
    $spineChannels = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($f in $spineFiles) {
        $j = Get-GateJson -Path $f.FullName
        if ($null -eq $j) { continue }
        foreach ($p in $j.PSObject.Properties) {
            if ($p.Name -like '_*') { continue }
            [void]$spineChannels.Add($p.Name)
        }
    }

    $required = New-Object System.Collections.Generic.List[string]
    $required.Add('spine')
    $required.Add('buildScripts')
    foreach ($rf in $renderedFamilies) { $required.Add($rf) }

    return [pscustomobject]@{
        Files            = $files.ToArray()
        SpineFiles       = $spineFiles
        SpineChannels    = @($spineChannels | Sort-Object)
        RequiredFamilies = $required.ToArray()
        ExclusionRx      = $ex.Rx
        ExclusionFrom    = $ex.From
        ExtractNames     = $extracts
    }
}

# ---------------------------------------------------------------------------
# 2. The ledger: which round, and what window it ran in
# ---------------------------------------------------------------------------

function Get-LedgerRecord {
    param([Parameter(Mandatory)][string] $BuildDir)
    $p = Get-LedgerPath -BuildDir $BuildDir
    if (-not (Test-Path -LiteralPath $p)) { return @() }
    $j = Get-GateJson -Path $p
    if ($null -eq $j) { return @() }
    return (AsArray $j.records)
}

function Resolve-RemediationRound {
    <#  The round under test, its record, and the window its edits fall in.

        roundEnd is the round's own record. roundStart is the newest boundary
        BEFORE it that a round cannot have started before: the previous Stage 7
        record, or the newest render or placement record older than this one.
        Taking the immediately preceding record of any stage would give a
        window of milliseconds wherever the ledger was batch-written, and a
        window nothing falls inside is a gate that passes by measuring
        nothing.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Records,
        [int] $Round
    )
    $seven = @(AsArray $Records | Where-Object { [string]$_.stage -eq '7' })
    if ($seven.Count -eq 0) { return $null }
    if ($Round -le 0) {
        $Round = ([int](@($seven | ForEach-Object { [int]$_.round } | Sort-Object -Descending)[0]))
    }
    $rec = @($seven | Where-Object { [int]$_.round -eq $Round })
    if ($rec.Count -eq 0) { return [pscustomobject]@{ Round = $Round; Record = $null; Start = $null; End = $null; Boundary = '' } }
    $rec = $rec[$rec.Count - 1]
    $end = ConvertTo-Utc $rec.utc

    $boundaryStages = @(AsArray $script:LedgerRenders) + @(AsArray $script:LedgerPlacements)
    $cands = New-Object System.Collections.Generic.List[object]
    foreach ($r in (AsArray $Records)) {
        $u = ConvertTo-Utc $r.utc
        if ($null -eq $u -or $null -eq $end -or $u -ge $end) { continue }
        $isPrevRound = ([string]$r.stage -eq '7' -and [int]$r.round -lt $Round)
        $isBoundary  = ($boundaryStages -contains [string]$r.stage)
        if ($isPrevRound -or $isBoundary) { $cands.Add([pscustomobject]@{ Utc = $u; Stage = [string]$r.stage; Round = [int]$r.round }) }
    }
    $start = $null; $why = 'the ledger has no earlier round or render, so the window opens at the ledger itself'
    if ($cands.Count -gt 0) {
        $best = @($cands.ToArray() | Sort-Object Utc -Descending)[0]
        $start = $best.Utc
        $why = ("stage {0} round {1}" -f $best.Stage, $best.Round)
    }
    else {
        $all = @(AsArray $Records | ForEach-Object { ConvertTo-Utc $_.utc } | Where-Object { $_ } | Sort-Object)
        if ($all.Count -gt 0) { $start = $all[0] }
    }
    return [pscustomobject]@{ Round = $Round; Record = $rec; Start = $start; End = $end; Boundary = $why }
}

# ---------------------------------------------------------------------------
# 3. The enumerations
# ---------------------------------------------------------------------------

function Read-Enumeration {
    <#  A hit list, in either shape a sweep on this project produces.

        JSON is the shape a sweep should write, because it can declare the
        channels it covered and carry a per-hit disposition. A plain text hit
        list - what Check-FigureLeakage -ReportPath and Test-FigureConsistency
        print - is read by matching each line against the KNOWN channel file
        names, so a line naming a file nothing in the build declares is not
        silently accepted as a hit.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)] $Channels
    )

    $item = Get-Item -LiteralPath $Path
    $hits = New-Object System.Collections.Generic.List[object]
    $declared = New-Object System.Collections.Generic.List[string]
    $finding = ''
    $generated = $null
    $shape = 'text'

    $known = @{}
    foreach ($f in $Channels.Files) { $known[$f.Name.ToLowerInvariant()] = $f }

    if ($Path -match '(?i)\.json$') {
        $j = Get-GateJson -Path $Path
        if ($null -ne $j) {
            $shape = 'json'
            $finding = [string](Get-GateProp -Object $j -Names @('finding', 'findingId', 'id'))
            $generated = ConvertTo-Utc (Get-GateProp -Object $j -Names @('generatedUtc', 'generated', 'ranAt', 'utc'))
            foreach ($c in (AsArray (Get-GateProp -Object $j -Names @('channels', 'channelsCovered', 'scanned')))) {
                $declared.Add([string]$c)
            }
            foreach ($h in (AsArray (Get-GateProp -Object $j -Names @('hits', 'locations', 'workOrder')))) {
                if ($h -is [string]) { $hits.Add([pscustomobject]@{ File = [string]$h; Field = ''; Token = ''; Reason = '' }); continue }
                $hits.Add([pscustomobject]@{
                    File   = [string](Get-GateProp -Object $h -Names @('file', 'name', 'path', 'location'))
                    Field  = [string](Get-GateProp -Object $h -Names @('field', 'fieldPath', 'jsonPath', 'channel', 'slot'))
                    Token  = [string](Get-GateProp -Object $h -Names @('token', 'text', 'value', 'stale'))
                    Reason = [string](Get-GateProp -Object $h -Names @('reason', 'why', 'disposition'))
                })
            }
        }
    }

    if ($shape -eq 'text') {
        $txt = Get-GateFileText -Path $Path
        foreach ($line in ($txt -split "\r?\n")) {
            if (-not $line.Trim()) { continue }
            $lower = $line.ToLowerInvariant()
            foreach ($k in $known.Keys) {
                if ($lower.IndexOf($k, [System.StringComparison]::Ordinal) -lt 0) { continue }
                $tok = ''
                $tm = [regex]::Match($line, "'([^']{1,200})'")
                if ($tm.Success) { $tok = $tm.Groups[1].Value }
                $hits.Add([pscustomobject]@{ File = $known[$k].Name; Field = ''; Token = $tok; Reason = '' })
                break
            }
            $cm = [regex]::Match($line, '(?i)^\s*channels?\s*(covered|scanned)?\s*[:=]\s*(.+)$')
            if ($cm.Success) {
                foreach ($c in ($cm.Groups[2].Value -split '[,;]')) { if ($c.Trim()) { $declared.Add($c.Trim()) } }
            }
            $fm = [regex]::Match($line, '(?i)^\s*finding\s*[:=]\s*(\S+)')
            if ($fm.Success -and -not $finding) { $finding = $fm.Groups[1].Value }
        }
    }

    if ($null -eq $generated) { $generated = $item.LastWriteTimeUtc }
    if (-not $finding) { $finding = [System.IO.Path]::GetFileNameWithoutExtension($item.Name) }

    return [pscustomobject]@{
        Path      = $item.FullName
        Name      = $item.Name
        Shape     = $shape
        Finding   = $finding
        Generated = $generated
        Mtime     = $item.LastWriteTimeUtc
        Declared  = $declared.ToArray()
        Hits      = $hits.ToArray()
    }
}

function Find-Enumeration {
    <#  Where a round's hit lists are named, in the order section 32 sets out:
        on the command line, in the Stage 7 ledger note, or in the registry.
        A file nobody names is not an enumeration, because no later reader
        could find it - which is the whole point of recording it.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        $Record,
        [string[]] $Explicit,
        $Registry
    )
    $found = New-Object System.Collections.Generic.List[object]
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

    function Add-Candidate {
        param([string] $Path, [string] $How)
        if (-not $Path) { return }
        $p = $Path
        if (-not [System.IO.Path]::IsPathRooted($p)) { $p = Join-Path $BuildDir $p }
        if (-not (Test-Path -LiteralPath $p)) { return }
        if ((Get-Item -LiteralPath $p).PSIsContainer) { return }
        $full = (Resolve-Path -LiteralPath $p).Path
        if (-not $seen.Add($full)) { return }
        $found.Add([pscustomobject]@{ Path = $full; How = $How })
    }

    foreach ($e in (AsArray $Explicit)) { Add-Candidate -Path $e -How 'named on the command line' }

    if ($null -ne $Record) {
        $note = [string](Get-GateProp -Object $Record -Names @('note'))
        foreach ($m in [regex]::Matches($note, '(?i)[\w\-\.\\/]+\.(json|txt|md|csv)')) {
            Add-Candidate -Path $m.Value -How 'named in the Stage 7 ledger note'
        }
        foreach ($e in (AsArray (Get-GateProp -Object $Record -Names @('enumerations', 'hitLists', 'enumeration')))) {
            Add-Candidate -Path ([string]$e) -How 'named in the Stage 7 ledger record'
        }
    }

    if ($null -ne $Registry) {
        foreach ($e in (AsArray (Get-GateProp -Object $Registry -Names @('enumerations', 'hitLists')))) {
            if ($e -is [string]) { Add-Candidate -Path $e -How 'named in the registry'; continue }
            Add-Candidate -Path ([string](Get-GateProp -Object $e -Names @('path', 'file'))) -How 'named in the registry'
        }
    }

    return $found.ToArray()
}

# ---------------------------------------------------------------------------
# 4. What the round actually changed
# ---------------------------------------------------------------------------

function Get-RoundEdit {
    <#  From CONTENT where a baseline exists, from mtimes otherwise. Either
        way the answer comes from the filesystem, never from the round's own
        account of itself.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Channels,
        [Parameter(Mandatory)] $Window,
        [string] $Baseline,
        [string] $BuildDir,
        [string] $SpineDir
    )
    $edits = New-Object System.Collections.Generic.List[object]

    if ($Baseline -and (Test-Path -LiteralPath $Baseline)) {
        $before = @{}
        #  The baseline is enumerated by the SAME rule as the live spine, so a
        #  structural file the spine reader excludes cannot show up as a
        #  location the round deleted. Two different rules over the two sides
        #  of one diff is how a diff invents work.
        foreach ($f in (Get-GateSpineFiles -BuildDir $BuildDir -SpineDir $Baseline)) {
            $j = Get-GateJson -Path $f.FullName
            if ($null -eq $j) { continue }
            foreach ($c in (Get-GateSpineCells -Node $j -File $f.Name)) {
                $before[($f.Name + '|' + $c.Path)] = $c.Text
            }
        }
        $after = @{}
        foreach ($f in $Channels.SpineFiles) {
            $j = Get-GateJson -Path $f.FullName
            if ($null -eq $j) { continue }
            foreach ($c in (Get-GateSpineCells -Node $j -File $f.Name)) {
                $after[($f.Name + '|' + $c.Path)] = $c.Text
            }
        }
        foreach ($k in $after.Keys) {
            if (-not $before.ContainsKey($k) -or $before[$k] -ne $after[$k]) {
                $bits = $k -split '\|', 2
                $edits.Add([pscustomobject]@{ File = $bits[0]; Field = $bits[1]; How = 'content, against the baseline' })
            }
        }
        foreach ($k in $before.Keys) {
            if (-not $after.ContainsKey($k)) {
                $bits = $k -split '\|', 2
                $edits.Add([pscustomobject]@{ File = $bits[0]; Field = $bits[1]; How = 'removed, against the baseline' })
            }
        }
        #  Files outside the spine still have to be attributed, and the
        #  baseline only covers the spine.
        foreach ($f in $Channels.Files) {
            if ($f.Family -eq 'spine') { continue }
            if (-not (Test-Path -LiteralPath $f.Path)) { continue }
            $m = (Get-Item -LiteralPath $f.Path).LastWriteTimeUtc
            if ($Window.Start -and $m -le $Window.Start) { continue }
            if ($Window.End -and $m -gt $Window.End) { continue }
            $edits.Add([pscustomobject]@{ File = $f.Name; Field = ''; How = 'mtime inside the round window' })
        }
        return [pscustomobject]@{ Edits = $edits.ToArray(); Mode = 'baseline'; Degenerate = $false }
    }

    $degenerate = $false
    if ($Window.Start -and $Window.End) {
        $degenerate = (([datetime]$Window.End) - ([datetime]$Window.Start)).TotalSeconds -lt 60
    }
    foreach ($f in $Channels.Files) {
        if (-not (Test-Path -LiteralPath $f.Path)) { continue }
        $m = (Get-Item -LiteralPath $f.Path).LastWriteTimeUtc
        if ($Window.Start -and $m -le $Window.Start) { continue }
        if ($Window.End -and $m -gt $Window.End) { continue }
        $edits.Add([pscustomobject]@{ File = $f.Name; Field = ''; How = 'mtime inside the round window' })
    }
    return [pscustomobject]@{ Edits = $edits.ToArray(); Mode = 'mtime window'; Degenerate = $degenerate }
}

# ---------------------------------------------------------------------------
# 5. The gate itself, as a function so the self-test drives the real thing
# ---------------------------------------------------------------------------

function Invoke-EnumerateBeforeFix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [string] $Finding,
        [int]    $Round = 0,
        [Parameter(Mandatory)][string] $ScriptsDir,
        [string] $SpineDir,
        [string[]] $Enumeration,
        [string] $Baseline,
        [string] $RulesPath
    )

    $blocking = New-Object System.Collections.Generic.List[object]
    $warnings = New-Object System.Collections.Generic.List[object]
    $notes    = New-Object System.Collections.Generic.List[string]

    if (-not $RulesPath) { $RulesPath = Join-Path $BuildDir 'figures.json' }
    $registry = $null
    if (Test-Path -LiteralPath $RulesPath) { $registry = Get-GateJson -Path $RulesPath }

    $channels = Get-ContentChannel -BuildDir $BuildDir -SpineDir $SpineDir -ScriptsDir $ScriptsDir
    $records  = Get-LedgerRecord -BuildDir $BuildDir
    $window   = Resolve-RemediationRound -Records $records -Round $Round

    if ($null -eq $window) {
        $blocking.Add([pscustomobject]@{ Arm = 'A'; What = 'no Stage 7 record'; Detail = 'the ledger carries no Stage 7 record at all, so there is no round to check and no round can be closed' })
        return [pscustomobject]@{ Blocking = $blocking.ToArray(); Warnings = $warnings.ToArray(); Notes = $notes.ToArray(); Channels = $channels; Window = $null; Enumerations = @(); Edits = @() }
    }
    if ($null -eq $window.Record) {
        $blocking.Add([pscustomobject]@{ Arm = 'A'; What = 'no record for the round'; Detail = ("round {0} has no Stage 7 ledger record" -f $window.Round) })
        return [pscustomobject]@{ Blocking = $blocking.ToArray(); Warnings = $warnings.ToArray(); Notes = $notes.ToArray(); Channels = $channels; Window = $window; Enumerations = @(); Edits = @() }
    }

    # ---- the allow-list, read through the shared reader that refuses an
    #      entry with no written reason
    $allow = @{}
    if ($null -ne $registry) {
        $allow = Get-GateAllowList -Registry $registry -Key 'enumerationAllow' -IdField @('location', 'file', 'path', 'id') -GateName $GATE
    }

    # ---- ARM A: an enumeration exists, and it is named where it can be found
    $candidates = Find-Enumeration -BuildDir $BuildDir -Record $window.Record -Explicit $Enumeration -Registry $registry
    $enums = New-Object System.Collections.Generic.List[object]
    foreach ($c in $candidates) {
        $e = Read-Enumeration -Path $c.Path -Channels $channels
        $e | Add-Member -NotePropertyName How -NotePropertyValue $c.How -Force
        $enums.Add($e)
    }
    $enumArr = $enums.ToArray()
    if ($Finding) {
        $scoped = @($enumArr | Where-Object { $_.Finding -and ($_.Finding -eq $Finding -or $_.Name -match [regex]::Escape($Finding)) })
    }
    else { $scoped = @($enumArr) }

    if (@($enumArr).Count -eq 0) {
        $blocking.Add([pscustomobject]@{
            Arm = 'A'; What = 'no enumeration'
            Detail = ("round {0} named no machine-generated hit list. A finding cannot be marked closed without one, produced BEFORE the fix; the Stage 7 ledger note must name the hit-list file per finding, or the closure is a sentence." -f $window.Round)
        })
    }
    elseif ($Finding -and @($scoped).Count -eq 0) {
        $blocking.Add([pscustomobject]@{
            Arm = 'A'; What = 'no enumeration for this finding'
            Detail = ("{0} hit list(s) were found for round {1}, none of them for finding '{2}'" -f @($enumArr).Count, $window.Round, $Finding)
        })
    }

    # ---- the union of every hit the round enumerated. Arm C compares against
    #      the union, never one finding's list: a round fixes several findings
    #      and an edit enumerated under any of them is not a fix by eye.
    $enumeratedFiles = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $allHits = New-Object System.Collections.Generic.List[object]
    foreach ($e in $enumArr) {
        foreach ($h in $e.Hits) {
            if ($h.File) { [void]$enumeratedFiles.Add((Split-Path $h.File -Leaf)) }
            $h | Add-Member -NotePropertyName Source -NotePropertyValue $e.Name -Force
            $allHits.Add($h)
        }
    }

    # ---- what the round changed
    $editSet = Get-RoundEdit -Channels $channels -Window $window -Baseline $Baseline -BuildDir $BuildDir -SpineDir $SpineDir
    $editedFiles = @($editSet.Edits | ForEach-Object { $_.File } | Sort-Object -Unique)

    if ($editSet.Degenerate) {
        $blocking.Add([pscustomobject]@{
            Arm = 'C'; What = 'the round window cannot bound its edits'
            Detail = ("the ledger puts round {0} inside {1:N1} second(s) ({2} to {3}), which is the retroactive batch-write signature section 34 names. With no -Baseline the edited set cannot be attributed, and a gate that attributes nothing passes by measuring nothing." -f `
                        $window.Round, (([datetime]$window.End) - ([datetime]$window.Start)).TotalSeconds, (Format-Utc $window.Start), (Format-Utc $window.End))
        })
    }

    # ---- ARM B: the enumeration predates every edit
    $earliestEdit = $null
    foreach ($f in $editedFiles) {
        $fi = @($channels.Files | Where-Object { $_.Name -eq $f })
        if ($fi.Count -eq 0) { continue }
        if (-not (Test-Path -LiteralPath $fi[0].Path)) { continue }
        $m = (Get-Item -LiteralPath $fi[0].Path).LastWriteTimeUtc
        if ($null -eq $earliestEdit -or $m -lt $earliestEdit) { $earliestEdit = $m }
    }
    foreach ($e in $enumArr) {
        if ($null -eq $earliestEdit) { continue }
        if ($e.Generated -gt $earliestEdit) {
            $blocking.Add([pscustomobject]@{
                Arm = 'B'; What = 'the round began with edits'
                Detail = ("hit list '{0}' was generated {1}, after the round's earliest edit at {2}. An enumeration produced after the fix is a receipt, not a work order - registry first, then the hit list, then the edit." -f $e.Name, (Format-Utc $e.Generated), (Format-Utc $earliestEdit))
            })
        }
    }

    # ---- the registry ordering, reported and not blocked: figures.json is
    #      legitimately touched again inside a round (an allow-list entry, a
    #      narrowed rule), so this is the anchor a reader weighs, not a verdict.
    if (Test-Path -LiteralPath $RulesPath) {
        $regM = (Get-Item -LiteralPath $RulesPath).LastWriteTimeUtc
        foreach ($e in $enumArr) {
            if ($regM -gt $e.Generated) {
                $warnings.Add([pscustomobject]@{
                    Arm = 'F'; What = 'registry updated after the hit list'
                    Detail = ("{0} was written {1}, after hit list '{2}' at {3}. The order is registry first, then the hit list: a rule added afterwards was never swept for." -f (Split-Path $RulesPath -Leaf), (Format-Utc $regM), $e.Name, (Format-Utc $e.Generated))
                })
            }
        }
    }

    # ---- ARM C: every edit is enumerated, or carries a written reason
    foreach ($f in $editedFiles) {
        if ($enumeratedFiles.Contains($f)) { continue }
        if ($allow.ContainsKey($f)) {
            $notes.Add(("edit outside every hit list, allowed: {0} - {1}" -f $f, $allow[$f]))
            continue
        }
        $blocking.Add([pscustomobject]@{
            Arm = 'C'; What = 'an edit no enumeration named'
            Detail = ("{0} changed inside round {1} and no hit list names it. That is a fix by eye: it corrects the instance in front of the author and leaves its siblings. Enumerate it, or record a written reason in the registry's enumerationAllow." -f $f, $window.Round)
        })
    }

    # ---- ARM D: every enumerated location cleared, or reasoned
    $cleared = 0; $reasoned = 0; $unverifiable = 0
    foreach ($h in $allHits.ToArray()) {
        if (-not $h.File) { continue }
        $leaf = Split-Path $h.File -Leaf
        $fi = @($channels.Files | Where-Object { $_.Name -eq $leaf })
        $key = $leaf
        $keyField = if ($h.Field) { ($leaf + '|' + $h.Field) } else { $leaf }
        $reason = ''
        if ($h.Reason) { $reason = [string]$h.Reason }
        elseif ($allow.ContainsKey($keyField)) { $reason = $allow[$keyField] }
        elseif ($allow.ContainsKey($key)) { $reason = $allow[$key] }

        if ($fi.Count -eq 0 -or -not (Test-Path -LiteralPath $fi[0].Path)) {
            $unverifiable++
            $warnings.Add([pscustomobject]@{
                Arm = 'D'; What = 'an enumerated location that does not exist'
                Detail = ("hit list '{0}' names {1}, which is not a content channel of this build" -f $h.Source, $leaf)
            })
            continue
        }

        $still = $false
        $how = ''
        if ($h.Token) {
            $body = Get-GateFileText -Path $fi[0].Path
            $still = ($body.IndexOf($h.Token, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
            $how = 'content: the token is still in the file'
        }
        else {
            $still = (-not ($editedFiles -contains $leaf))
            $how = 'mtime: the hit carries no token, so clearing could only be judged by whether the file was edited at all'
        }

        if (-not $still) { $cleared++; continue }
        if ($reason) {
            $reasoned++
            $notes.Add(("enumerated location left as it is, with a reason: {0}{1} - {2}" -f $leaf, $(if ($h.Field) { ' / ' + $h.Field } else { '' }), $reason))
            continue
        }
        $blocking.Add([pscustomobject]@{
            Arm = 'D'; What = 'an enumerated location not cleared'
            Detail = ("{0}{1} is on hit list '{2}' (token {3}) and was not cleared - {4}. The fix must clear the WHOLE list, or the registry must record a written reason for leaving this one." -f `
                        $leaf, $(if ($h.Field) { ' / ' + $h.Field } else { '' }), $h.Source, (Get-TokenDigest -Text ([string]$h.Token)), $how)
        })
    }

    # ---- ARM E: the channels the sweep covered, recorded and complete
    foreach ($e in $enumArr) {
        $decl = @($e.Declared)
        if ($decl.Count -eq 0) {
            $blocking.Add([pscustomobject]@{
                Arm = 'E'; What = 'the hit list does not say what it swept'
                Detail = ("'{0}' records no channel list. Section 32 requires the channel list a sweep covered to be recorded: 'fixed the guide and left the deck' and 'fixed the prose and left the diagram specs' are both channel-coverage defects, and a sweep that never says what it swept cannot be shown to have swept anything." -f $e.Name)
            })
            continue
        }
        $whole = @($decl | Where-Object { $_ -eq '*' -or $_ -match '(?i)^(all|whole|every)' }).Count -gt 0
        $missing = New-Object System.Collections.Generic.List[string]
        foreach ($req in $channels.RequiredFamilies) {
            if ($whole) { continue }
            $hit = $false
            foreach ($d in $decl) {
                $dn = ([string]$d).Trim()
                if (-not $dn) { continue }
                if ($req -ieq $dn) { $hit = $true; break }
                if ($req -like ('*' + $dn + '*') -or $dn -like ('*' + $req + '*')) { $hit = $true; break }
            }
            if (-not $hit) { $missing.Add($req) }
        }
        if ($missing.Count -gt 0) {
            $blocking.Add([pscustomobject]@{
                Arm = 'E'; What = 'the sweep did not cover every channel'
                Detail = ("'{0}' declares {1} channel(s) and never covered: {2}. A class-fix is not complete until the sweep has run over every channel of BOTH artefacts." -f $e.Name, $decl.Count, (($missing.ToArray()) -join ', '))
            })
        }
        if ($whole) { $notes.Add(("'{0}' declares a whole-build sweep, which covers every channel by construction" -f $e.Name)) }
    }

    return [pscustomobject]@{
        Blocking     = $blocking.ToArray()
        Warnings     = $warnings.ToArray()
        Notes        = $notes.ToArray()
        Channels     = $channels
        Window       = $window
        Enumerations = $enumArr
        Scoped       = @($scoped)
        Edits        = $editSet
        EditedFiles  = $editedFiles
        Cleared      = $cleared
        Reasoned     = $reasoned
        Unverifiable = $unverifiable
        Allow        = $allow
    }
}

# ---------------------------------------------------------------------------
# 6. Reporting
# ---------------------------------------------------------------------------

function Write-Report {
    param([Parameter(Mandatory)] $Result, [Parameter(Mandatory)][string] $Path, [string] $BuildDir)
    $payload = [ordered]@{
        gate        = $GATE
        ranAtUtc    = (Get-Date).ToUniversalTime().ToString('o')
        buildDir    = $BuildDir
        round       = $(if ($Result.Window) { $Result.Window.Round } else { 0 })
        windowStart = $(if ($Result.Window) { Format-Utc $Result.Window.Start } else { '' })
        windowEnd   = $(if ($Result.Window) { Format-Utc $Result.Window.End } else { '' })
        windowFrom  = $(if ($Result.Window) { $Result.Window.Boundary } else { '' })
        editMode    = $(if ($Result.Edits) { $Result.Edits.Mode } else { '' })
        channels    = [ordered]@{
            files            = @($Result.Channels.Files | ForEach-Object { $_.Name })
            requiredFamilies = @($Result.Channels.RequiredFamilies)
            spineChannels    = @($Result.Channels.SpineChannels)
            buildScriptRule  = $Result.Channels.ExclusionFrom
        }
        enumerations = @($Result.Enumerations | ForEach-Object {
            [ordered]@{ name = $_.Name; shape = $_.Shape; finding = $_.Finding; how = $_.How
                        generatedUtc = (Format-Utc $_.Generated); hits = @($_.Hits).Count; declaredChannels = @($_.Declared) }
        })
        editedFiles = @($Result.EditedFiles)
        cleared     = $Result.Cleared
        reasoned    = $Result.Reasoned
        blocking    = @($Result.Blocking | ForEach-Object { [ordered]@{ arm = $_.Arm; what = $_.What; detail = $_.Detail } })
        warnings    = @($Result.Warnings | ForEach-Object { [ordered]@{ arm = $_.Arm; what = $_.What; detail = $_.Detail } })
        notes       = @($Result.Notes)
        verdict     = $(if (@($Result.Blocking).Count -eq 0) { 'PASS' } else { 'FAIL' })
    }
    $json = $payload | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

# ---------------------------------------------------------------------------
# 7. Self-test - every plant VERIFIED to have landed before the gate is run
#
#  A plant that lands where the defect cannot occur proves nothing and passes.
#  One build's first plant was a no-op and was recorded as evidence the gate
#  worked. So each case below reads its own plant back and asserts the defect
#  is present in the exact channel this gate scans, and only then runs it.
# ---------------------------------------------------------------------------

function New-Fixture {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Root, [Parameter(Mandatory)][string] $Case)

    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $build = Join-Path $Root $Case
    if (Test-Path -LiteralPath $build) { Remove-Item -LiteralPath $build -Recurse -Force }
    $null = New-Item -ItemType Directory -Path $build -Force
    $spine = Join-Path $build 'spine'
    $null = New-Item -ItemType Directory -Path $spine -Force
    $enumDir = Join-Path $build 'enumerations'
    $null = New-Item -ItemType Directory -Path $enumDir -Force

    $t0    = (Get-Date).ToUniversalTime().AddHours(-4)
    $tEnum = $t0.AddMinutes(10)
    $tEdit = $t0.AddMinutes(20)
    $tEnd  = $t0.AddMinutes(30)

    #  The stale token is a nonsense string invented here. Nothing in a fixture
    #  is a value from any unit, pack or brand.
    $stale = 'ZZQ-STALE-TOKEN-7'

    $clean = '{ "topic": 1, "body": [ "a sentence with nothing stale in it" ], "visuals": [ { "slot": "1.1.1", "caption": "a caption" } ] }'
    $dirty = '{ "topic": 1, "body": [ "a sentence carrying ' + $stale + ' in it" ], "visuals": [ { "slot": "1.2.1", "caption": "a caption" } ] }'

    [System.IO.File]::WriteAllText((Join-Path $spine 't1_1.1.json'), $clean, $utf8)
    [System.IO.File]::WriteAllText((Join-Path $spine 't1_1.2.json'), $clean.Replace('1.1.1', '1.2.1'), $utf8)
    [System.IO.File]::WriteAllText((Join-Path $spine 't1_1.3.json'), $clean.Replace('1.1.1', '1.3.1'), $utf8)
    [System.IO.File]::WriteAllText((Join-Path $build 'Build-Fixture.ps1'), "# a build script channel`r`nWrite-Output 'render'`r`n", $utf8)
    [System.IO.File]::WriteAllText((Join-Path $build 'guide_gate.txt'), "guide rendered text`r`n", $utf8)
    [System.IO.File]::WriteAllText((Join-Path $build 'deck_gate.txt'), "deck rendered text`r`n", $utf8)

    $registry = [ordered]@{ figures = @(); assessorOnly = @(); deckMust = @() }
    $hits = @(
        [ordered]@{ file = 't1_1.1.json'; field = 'body[0]'; token = $stale }
        [ordered]@{ file = 't1_1.2.json'; field = 'body[0]'; token = $stale }
    )
    $channelsDeclared = @('*')
    $enumGenerated = $tEnum

    switch ($Case) {
        'clean'            { }
        'edit-outside'     { }
        'unedited-noreason'{ }
        'unedited-reason'  {
            $registry['enumerationAllow'] = @(
                [ordered]@{ location = 't1_1.2.json|body[0]'; reason = 'the source carries this value verbatim, so forbidding it would be forbidding a literal a source carries' }
            )
        }
        'edit-first'       { $enumGenerated = $tEdit.AddMinutes(5) }
        'no-enumeration'   { }
        'channels-short'   { $channelsDeclared = @('spine') }
    }

    $enumObj = [ordered]@{
        finding      = 'F-1'
        generatedUtc = $enumGenerated.ToString('o')
        sweep        = 'fixture sweep'
        channels     = $channelsDeclared
        hits         = $hits
    }
    $enumPath = Join-Path $enumDir 'F-1.json'
    if ($Case -ne 'no-enumeration') {
        [System.IO.File]::WriteAllText($enumPath, ($enumObj | ConvertTo-Json -Depth 6), $utf8)
    }

    [System.IO.File]::WriteAllText((Join-Path $build 'figures.json'), ($registry | ConvertTo-Json -Depth 6), $utf8)

    $note = 'Registry first, then enumerated. Hit list: enumerations\F-1.json'
    if ($Case -eq 'no-enumeration') { $note = 'Fixed the finding.' }
    $ledger = [ordered]@{
        unit    = 'FIXTURE'
        created = $t0.ToString('o')
        records = @(
            [ordered]@{ stage = '4'; name = 'render'; status = 'pass'; round = 0; findings = 0; utc = $t0.ToString('o') }
            [ordered]@{ stage = '7'; name = 'round 1'; status = 'pass'; round = 1; findings = 1; utc = $tEnd.ToString('o'); note = $note }
        )
    }
    [System.IO.File]::WriteAllText((Join-Path $build 'stage-ledger.json'), ($ledger | ConvertTo-Json -Depth 6), $utf8)

    # ---- the plants, written as CONTENT, then stamped with their times
    $f11 = Join-Path $spine 't1_1.1.json'
    $f12 = Join-Path $spine 't1_1.2.json'
    $f13 = Join-Path $spine 't1_1.3.json'

    if ($Case -in @('unedited-noreason', 'unedited-reason')) {
        # t1_1.2 keeps the stale token and is NOT touched inside the window
        [System.IO.File]::WriteAllText($f12, $dirty, $utf8)
    }

    #  Times last, because writing a file resets them.
    (Get-Item -LiteralPath $f11).LastWriteTimeUtc = $tEdit
    (Get-Item -LiteralPath $f12).LastWriteTimeUtc = $(if ($Case -in @('unedited-noreason', 'unedited-reason')) { $t0.AddMinutes(-5) } else { $tEdit })
    (Get-Item -LiteralPath $f13).LastWriteTimeUtc = $(if ($Case -eq 'edit-outside') { $tEdit } else { $t0.AddMinutes(-5) })
    (Get-Item -LiteralPath (Join-Path $build 'Build-Fixture.ps1')).LastWriteTimeUtc = $t0.AddMinutes(-5)
    (Get-Item -LiteralPath (Join-Path $build 'guide_gate.txt')).LastWriteTimeUtc = $t0.AddMinutes(-5)
    (Get-Item -LiteralPath (Join-Path $build 'deck_gate.txt')).LastWriteTimeUtc = $t0.AddMinutes(-5)
    (Get-Item -LiteralPath (Join-Path $build 'figures.json')).LastWriteTimeUtc = $t0.AddMinutes(1)
    if ($Case -eq 'edit-first') { (Get-Item -LiteralPath $f11).LastWriteTimeUtc = $tEdit }
    if (Test-Path -LiteralPath $enumPath) { (Get-Item -LiteralPath $enumPath).LastWriteTimeUtc = $enumGenerated }

    return [pscustomobject]@{
        BuildDir = $build; SpineDir = $spine; Enum = $enumPath; Stale = $stale
        T0 = $t0; TEnum = $tEnum; TEdit = $tEdit; TEnd = $tEnd
        F11 = $f11; F12 = $f12; F13 = $f13
    }
}

function Invoke-SelfTest {
    [CmdletBinding()] param([Parameter(Mandatory)][string] $ScriptsDir)

    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("ebf-selftest-" + [guid]::NewGuid().ToString('n').Substring(0, 8))
    $null = New-Item -ItemType Directory -Path $root -Force
    $failures = 0
    $checks = 0

    function Check {
        param([string] $What, [bool] $Ok, [string] $Detail)
        $script:sfChecks++
        if ($Ok) { Write-Host ("    ok   {0}" -f $What) -ForegroundColor Green }
        else { Write-Host ("    X    {0}{1}" -f $What, $(if ($Detail) { " - $Detail" } else { '' })) -ForegroundColor Red; $script:sfFail++ }
    }
    $script:sfChecks = 0
    $script:sfFail = 0

    try {
        Write-Host ''
        Write-Host ("SELF-TEST {0} - every plant is read back before the gate is run" -f $GATE) -ForegroundColor Cyan

        # ---- 1. a clean round passes
        Write-Host '  case: a clean round - enumeration first, every hit cleared' -ForegroundColor DarkGray
        $fx = New-Fixture -Root $root -Case 'clean'
        Check -What 'plant landed: neither enumerated file still carries the token' `
              -Ok ((Get-GateFileText -Path $fx.F11).IndexOf($fx.Stale) -lt 0 -and (Get-GateFileText -Path $fx.F12).IndexOf($fx.Stale) -lt 0)
        $r = Invoke-EnumerateBeforeFix -BuildDir $fx.BuildDir -ScriptsDir $ScriptsDir
        Check -What 'the clean round passes' -Ok (@($r.Blocking).Count -eq 0) -Detail (@($r.Blocking | ForEach-Object { $_.Arm + ':' + $_.What }) -join '; ')
        Check -What 'and it did attribute edits, so the pass is not vacuous' -Ok (@($r.EditedFiles).Count -gt 0)

        # ---- 2. an edit no enumeration named
        Write-Host '  case: the round edited a file no enumeration names' -ForegroundColor DarkGray
        $fx = New-Fixture -Root $root -Case 'edit-outside'
        $plantedMtime = (Get-Item -LiteralPath $fx.F13).LastWriteTimeUtc
        Check -What 'plant landed: t1_1.3.json sits inside the round window' -Ok ($plantedMtime -gt $fx.T0 -and $plantedMtime -le $fx.TEnd)
        Check -What 'plant landed: and no hit list names it' -Ok ((Get-GateFileText -Path $fx.Enum).IndexOf('t1_1.3.json') -lt 0)
        $r = Invoke-EnumerateBeforeFix -BuildDir $fx.BuildDir -ScriptsDir $ScriptsDir
        Check -What 'the gate FAILS on arm C, naming the file' `
              -Ok (@($r.Blocking | Where-Object { $_.Arm -eq 'C' -and $_.Detail -match 't1_1\.3\.json' }).Count -eq 1)

        # ---- 3. an enumerated location left unedited, no reason
        Write-Host '  case: an enumerated location left unedited, with no reason' -ForegroundColor DarkGray
        $fx = New-Fixture -Root $root -Case 'unedited-noreason'
        Check -What 'plant landed: t1_1.2.json still carries the stale token' -Ok ((Get-GateFileText -Path $fx.F12).IndexOf($fx.Stale) -ge 0)
        Check -What 'plant landed: and it is on the hit list' -Ok ((Get-GateFileText -Path $fx.Enum).IndexOf('t1_1.2.json') -ge 0)
        $r = Invoke-EnumerateBeforeFix -BuildDir $fx.BuildDir -ScriptsDir $ScriptsDir
        Check -What 'the gate FAILS on arm D, naming the location' `
              -Ok (@($r.Blocking | Where-Object { $_.Arm -eq 'D' -and $_.Detail -match 't1_1\.2\.json' }).Count -eq 1)
        $allDetail = (@($r.Blocking | ForEach-Object { [string]$_.Detail }) -join ' ')
        Check -What 'and the token itself was not printed anywhere in the finding' -Ok ($allDetail.IndexOf($fx.Stale, [System.StringComparison]::OrdinalIgnoreCase) -lt 0)

        # ---- 4. the same, WITH a recorded reason - must not fire
        Write-Host '  case: the same location, left with a written reason in the registry' -ForegroundColor DarkGray
        $fx = New-Fixture -Root $root -Case 'unedited-reason'
        Check -What 'plant landed: the token is still there' -Ok ((Get-GateFileText -Path $fx.F12).IndexOf($fx.Stale) -ge 0)
        Check -What 'plant landed: and the registry carries a written reason for it' `
              -Ok ((Get-GateFileText -Path (Join-Path $fx.BuildDir 'figures.json')).IndexOf('enumerationAllow') -ge 0)
        $r = Invoke-EnumerateBeforeFix -BuildDir $fx.BuildDir -ScriptsDir $ScriptsDir
        Check -What 'the gate does NOT fire on arm D' -Ok (@($r.Blocking | Where-Object { $_.Arm -eq 'D' }).Count -eq 0) `
              -Detail (@($r.Blocking | ForEach-Object { $_.Arm + ':' + $_.What }) -join '; ')
        Check -What 'and the disposition is recorded in the report notes' -Ok (@($r.Notes | Where-Object { $_ -match 'with a reason' }).Count -ge 1)

        # ---- 5. the round began with edits
        Write-Host '  case: the hit list was generated after the first edit' -ForegroundColor DarkGray
        $fx = New-Fixture -Root $root -Case 'edit-first'
        $eg = (Get-Item -LiteralPath $fx.Enum).LastWriteTimeUtc
        Check -What 'plant landed: the hit list postdates the earliest edit' -Ok ($eg -gt (Get-Item -LiteralPath $fx.F11).LastWriteTimeUtc)
        $r = Invoke-EnumerateBeforeFix -BuildDir $fx.BuildDir -ScriptsDir $ScriptsDir
        Check -What 'the gate FAILS on arm B' -Ok (@($r.Blocking | Where-Object { $_.Arm -eq 'B' }).Count -ge 1)

        # ---- 6. no enumeration at all
        Write-Host '  case: the round named no hit list' -ForegroundColor DarkGray
        $fx = New-Fixture -Root $root -Case 'no-enumeration'
        Check -What 'plant landed: no enumeration file exists' -Ok (-not (Test-Path -LiteralPath $fx.Enum))
        $r = Invoke-EnumerateBeforeFix -BuildDir $fx.BuildDir -ScriptsDir $ScriptsDir
        Check -What 'the gate FAILS on arm A' -Ok (@($r.Blocking | Where-Object { $_.Arm -eq 'A' }).Count -ge 1)

        # ---- 7. the sweep covered fewer channels than the build has
        Write-Host '  case: the hit list declares only one channel' -ForegroundColor DarkGray
        $fx = New-Fixture -Root $root -Case 'channels-short'
        Check -What 'plant landed: the declaration names only the spine' `
              -Ok ((Get-GateFileText -Path $fx.Enum) -match '"channels"\s*:\s*\[\s*"spine"\s*\]')
        $r = Invoke-EnumerateBeforeFix -BuildDir $fx.BuildDir -ScriptsDir $ScriptsDir
        Check -What 'the gate FAILS on arm E, naming the channels it never swept' `
              -Ok (@($r.Blocking | Where-Object { $_.Arm -eq 'E' -and $_.Detail -match 'rendered:' }).Count -ge 1)

        Write-Host ''
        Write-Host ("  {0} check(s), {1} failure(s)" -f $script:sfChecks, $script:sfFail) -ForegroundColor $(if ($script:sfFail) { 'Red' } else { 'Green' })
        $failures = $script:sfFail
        $checks = $script:sfChecks
    }
    finally {
        if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }
    return [pscustomobject]@{ Checks = $checks; Failures = $failures }
}

# ---------------------------------------------------------------------------
# 8. Main
# ---------------------------------------------------------------------------

$scriptsDir = Join-Path $SkillDir 'scripts'
if (-not (Test-Path -LiteralPath $scriptsDir)) { $scriptsDir = $PSScriptRoot }

if ($SelfTest) {
    $st = Invoke-SelfTest -ScriptsDir $scriptsDir
    if ($st.Failures -gt 0) {
        Write-Host ("X {0}: the self-test failed. No clean result from this gate is trustworthy until it does." -f $GATE) -ForegroundColor Red
        exit 4
    }
    Write-Host ("{0}: self-test passed - the gate fails on every planted defect and passes the clean round." -f $GATE) -ForegroundColor Green
    exit 0
}

if (-not $BuildDir) {
    Write-Host ("{0}: -BuildDir is required (or -SelfTest)." -f $GATE) -ForegroundColor Red
    exit 2
}
if (-not (Test-Path -LiteralPath $BuildDir)) {
    Write-Host ("{0}: no build directory at {1}" -f $GATE, $BuildDir) -ForegroundColor Red
    exit 2
}
$BuildDir = (Resolve-Path -LiteralPath $BuildDir).Path

$result = Invoke-EnumerateBeforeFix -BuildDir $BuildDir -Finding $Finding -Round $Round `
            -ScriptsDir $scriptsDir -SpineDir $SpineDir -Enumeration $Enumeration -Baseline $Baseline -RulesPath $RulesPath

Write-Line '' 'DarkGray'
Write-Line 'ENUMERATE BEFORE FIXING - a round may not begin with prose edits' 'Cyan'
if ($result.Window) {
    Write-Line ("  round {0}: {1} to {2}   (window opens at {3})" -f $result.Window.Round, (Format-Utc $result.Window.Start), (Format-Utc $result.Window.End), $result.Window.Boundary)
}
if (-not $Quiet) {
    Write-GateCheckSet -What 'content channel files' -Count @($result.Channels.Files).Count `
        -DerivedFrom ('the spine itself, the registry gate''s own build-script scoping rule, and the runner''s own extract names')
    Write-GateCheckSet -What 'required channel families' -Count @($result.Channels.RequiredFamilies).Count `
        -DerivedFrom ('the spine plus every rendered extract the runner declares: ' + (@($result.Channels.RequiredFamilies) -join ', '))
}
Write-Line ("  build-script scoping: {0}" -f $result.Channels.ExclusionFrom)
Write-Line ("  hit list(s): {0}" -f $(if (@($result.Enumerations).Count) { (@($result.Enumerations | ForEach-Object { "{0} ({1}, {2} hit(s), {3})" -f $_.Name, $_.Shape, @($_.Hits).Count, $_.How }) -join '; ') } else { 'NONE' }))
Write-Line ("  edits attributed by {0}: {1} location(s) - {2}" -f $result.Edits.Mode, @($result.EditedFiles).Count, $(if (@($result.EditedFiles).Count) { (@($result.EditedFiles) -join ', ') } else { 'none' }))
Write-Line ("  enumerated locations cleared: {0}; left with a written reason: {1}" -f $result.Cleared, $result.Reasoned)

foreach ($n in $result.Notes) { Write-Line ("  note: {0}" -f $n) }
foreach ($w in $result.Warnings) { Write-Line ("  ! [{0}] {1}: {2}" -f $w.Arm, $w.What, $w.Detail) 'Yellow' }
foreach ($b in $result.Blocking) { Write-Line ("  X [{0}] {1}: {2}" -f $b.Arm, $b.What, $b.Detail) 'Red' }

if (-not $OutPath) { $OutPath = Join-Path $BuildDir ('enumerate-before-fix-r{0}.json' -f $(if ($result.Window) { $result.Window.Round } else { 0 })) }
Write-Report -Result $result -Path $OutPath -BuildDir $BuildDir
Write-Line ("  report: {0}" -f $OutPath)

if (@($result.Blocking).Count -gt 0) {
    Write-Line ("ENUMERATE-BEFORE-FIX FAIL - {0} blocking finding(s)" -f @($result.Blocking).Count) 'Red'
    exit 1
}
Write-Line 'ENUMERATE-BEFORE-FIX PASS - the enumeration came first, covered every channel, and the round cleared it' 'Green'
exit 0
