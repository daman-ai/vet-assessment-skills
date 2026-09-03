<#
    Test-SubSection.ps1 - the ONE command a content agent runs on its own spine
    file before returning. Exit 0, or fix and re-run; paste the verdict block.

    WHY IT EXISTS - SIX ROUNDS, FIVE LOCATIONS. On the build this skill was
    rebuilt from, every content agent was handed the assessor guides "to gauge
    depth", and every one of them wrote the model answers into an open-book
    guide that expressly permits itself. Six clean-room audit rounds then found
    that one leak one LOCATION at a time, each round fixing the copy in front of
    the auditor and missing its siblings:
      1. running prose (underpinning knowledge, case study, role play) walking
         the assessed items in the task's order with an answer beside each;
      2. the captioned figure tables (visual specs), which two audits never read
         because the page carried artwork prompts until placement;
      3. the worked-example tables, where the same grids sat a hundred lines
         above a figure that had been withheld;
      4. the practical-activity tables, the same grid moved rather than removed;
      5. the deck - slide bodies, chips and speaker notes counting the task's
         rows or quoting a benchmark.
    Every one of those was machine-readable JSON on the spine from the moment
    it was written, hours before a document existed. The whole-spine gates
    (Stage 3c) now catch all five, but four hours after the fact and across
    twenty-eight files at once. This script runs the same questions on ONE
    file, in seconds, by the author, so the defect is fixed in the loop that
    made it and never reaches an audit.

    THE EXACT / FUZZY SPLIT IS THE DESIGN, NOT A CONVENIENCE. An in-loop test
    an author cannot satisfy produces workarounds, so only checks that are
    decidable from THIS file plus the contract and the withhold register BLOCK
    here:
      BLOCK  Test-Spine -File (parse, ASCII, fields, empty boxes, the
             sub-section's underpinning-knowledge floor, refs == questionMap,
             four visuals, slide rules); Test-SpineRead UNREAD / MISSING;
             the figure registry's forbid / forbidRx / assessorOnly arms;
             the answer-grid mirror against the grids the register assigns to
             THIS sub-section, beyond the register's allowance; and relocation -
             an assessed row worked under two or more of the task's own
             headings. A token row that also carries other text is REPORTED,
             not blocked: "Read it off card 2097" beside "Yours to work" is a
             pointer, and only a reader can tell a pointer from an answer.
      REPORT the leakage sweep (shared n-gram runs, marking vocabulary), the
             mirror against grids assigned to OTHER sub-sections, the
             registry's require / deckMust arms (a sibling may satisfy them), a
             numbered grid's subject paired with content words of that task's
             model row, and a speaker note or self-check that names a task
             beside its own row count. These are fuzzy or need the whole spine;
             they travel with their anchor to the 3c band, where a reader
             adjudicates and clears a hit only by writing a reason into
             figures.json. An agent never edits figures.json.

    WHAT THE AGENT NEVER SEES. The relocation arm reads assessor-cells.json for
    the model-row content words of a numbered grid. That file is gate-only:
    this script reads it, and no report line ever prints a model bullet - only
    the row label, the subject and the arm.

    HEADINGS ARE MATCHED ON CONTENT WORDS, NOT ON THE EXACT STRING. On the
    reference build's t2_2.1 visuals[3].spec the author wrote "Equipment
    selected" for the task's "Equipment you selected" and "suits" for "suited",
    so an exact match after normalisation saw one shared heading of four and
    never examined a table whose four row labels were the task's four items
    verbatim - the mirror gate caught it on the labels, and the two arms named
    different things. So each heading is normalised with ConvertTo-GateNormal
    (Lib-GateCommon), pronouns and function words are dropped, the remaining
    tokens are stemmed, and two headings match when the content words overlap
    on 60 per cent of the longer one. The two-of-N rule itself is the mirror
    gate's; only the equality test beneath it tolerates an inserted pronoun or
    a tense change. A table that paraphrases the task's headings is still that
    task's grid.

    THE HASH IS OF THE BYTES THE CHECKS READ. The file is read once as bytes,
    hashed, and those same bytes are what every gate is handed (a temp spine
    directory holding only this file, so a sibling mid-write is never touched
    and never globbed). An orchestrator compares gate.json sha256 to the file on
    disk and bounces an author who edited after the check.

    A GATE THAT REFUSES IS A BLOCK, NEVER A PASS. Every external gate is called
    through its declared parameters, introspected before the call; a script
    that is missing, throws, exits with a usage code, or fails without a
    finding this wrapper can parse is recorded as "gate unavailable" and fails
    the file. The build that promoted this skill printed green over a gate
    that had quietly checked nothing.

    Output: one line per arm with its check-set size and result, a verdict
    block the agent pastes verbatim, and <file>.gate.json beside the file:
      { file, sha256, gateVersion, ranAt, mode:"file", verdict, blocks[],
        reports[], skippedArms[], arms[] }  with every finding shaped
      { arm, path, slot, grid, text, match }.

    Modes:
      -File <spine\tT_P.json> [-BuildDir <build>]   one file (the contract)
      -All -BuildDir <build>                         every sub-section the
                                                     contract names, one line each
      -SelfTest -BuildDir <build> [-File <ref>] [-PlantFile <planted copy>]
    Exit 0 pass, 1 fail, 2 usage error, 4 self-test failed.

    Nothing about a unit, a brand or a build path is typed in here. PS 5.1.
    ASCII only in this file.
#>

[CmdletBinding()]
param(
    #  ONE sub-section (or topic) file to test.
    [string] $File,
    #  The build. Default: the parent of the file's directory.
    [string] $BuildDir,
    #  The canonical corpus. Default: resolved the way every gate resolves it.
    [string] $CorpusDir,
    #  The unit extract the leakage gate excludes. Default: unit_extract.md
    #  beside the build.
    [string] $UnitExtract,
    #  The withhold register (grids per sub-section). Default: beside the build.
    [string] $RegisterPath,
    #  GATE-ONLY model-row content words. Default: assessor-cells.json beside
    #  the build; optional - its arm is a REPORT and is skipped without it.
    [string] $AssessorCellsPath,
    #  The figure registry. Default: figures.json beside the build.
    [string] $RulesPath,
    #  Where gate.json goes. Default: <file>.gate.json beside the file.
    [string] $ResultPath,
    #  Gate scripts. Default: this script's own directory. Exposed so the
    #  self-test can point one at a missing path and prove "unavailable" fails.
    [string] $SpineScript,
    [string] $SpineReadScript,
    [string] $ConsistencyScript,
    [string] $MirrorScript,
    [string] $LeakageScript,
    #  Every sub-section the contract names. Never a glob of the spine directory.
    [switch] $All,
    #  -All only: put every gate.json here instead of beside each file.
    [string] $ResultDir,
    [switch] $SelfTest,
    #  -SelfTest: a real planted file (a pre-remediation backup) to prove the
    #  own-grid mirror on, in addition to the synthetic plants.
    [string] $PlantFile,
    #  Echo every line each gate printed. Diagnostic.
    [switch] $ShowGateOutput,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

$GATE = 'Test-SubSection'
$GATE_VERSION = '1.0.0'
$script:Self = $PSCommandPath

#  Number words for the note-count arm, and the unit words that make a number
#  a measurement rather than a row count.
$NUMBER_WORDS = @{ 1 = 'one'; 2 = 'two'; 3 = 'three'; 4 = 'four'; 5 = 'five'; 6 = 'six'; 7 = 'seven'; 8 = 'eight';
                   9 = 'nine'; 10 = 'ten'; 11 = 'eleven'; 12 = 'twelve'; 13 = 'thirteen'; 14 = 'fourteen'; 15 = 'fifteen';
                   16 = 'sixteen'; 17 = 'seventeen'; 18 = 'eighteen'; 19 = 'nineteen'; 20 = 'twenty' }
$UNIT_RX = '(?i)\s*(degrees?|deg|c\b|hours?|hrs?|minutes?|mins?|seconds?|days?|weeks?|months?|years?|kg|g\b|gms?|grams?|ml|l\b|litres?|liters?|mm|cm|m\b|per\b|%|portions?|serves?|cents?|dollars?|\$)'
#  Words that never lead a subject's identifying head.
$HEAD_STOP = @('the', 'a', 'an', 'of', 'and', 'with', 'for', 'to', 'in', 'on', 'or', 'ten', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine')
#  Fallback withholding vocabulary - the mirror gate's own default is read from
#  its param block at run time so the two never disagree; this is used only
#  when that read fails.
$WITHHELD_FALLBACK = '(?i)\b(your turn|yours to (complete|work|fill)|you write this|write here|left for you|complete this row|for you to complete|to be completed)\b'

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

function Get-Count { param($x) if ($null -eq $x) { return 0 } return @($x).Count }
function AsArr     { param($x) if ($null -eq $x) { return @() } return @($x) }
function Has-Prop  { param($o, [string] $n) if ($null -eq $o -or $null -eq $o.PSObject) { return $false } return (@($o.PSObject.Properties.Name) -contains $n) }

function Set-Prop {
    param($Object, [string] $Name, $Value)
    if (Has-Prop $Object $Name) { $Object.$Name = $Value }
    else { $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}

function Get-Stem {
    #  The register's own crude stem: ing, ed, es, s. Applied to spine words so
    #  they compare with the content words assessor-cells.json carries.
    param([string] $w)
    if ($w.Length -gt 5 -and $w.EndsWith('ing')) { return $w.Substring(0, $w.Length - 3) }
    if ($w.Length -gt 4 -and $w.EndsWith('ed'))  { return $w.Substring(0, $w.Length - 2) }
    if ($w.Length -gt 4 -and $w.EndsWith('es'))  { return $w.Substring(0, $w.Length - 2) }
    if ($w.Length -gt 3 -and $w.EndsWith('s'))   { return $w.Substring(0, $w.Length - 1) }
    return $w
}

function Get-ScriptParameterName {
    param([string] $Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return @() }
    try {
        $c = Get-Command -Name $Path -ErrorAction Stop
        return @($c.Parameters.Keys | Where-Object { $_ -notin [System.Management.Automation.PSCmdlet]::CommonParameters })
    }
    catch { return @() }
}

function Get-ScriptParameterDefault {
    #  A gate's own default for a parameter, read from its param block AST.
    param([string] $Path, [string] $Name)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        $toks = $null; $errs = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$toks, [ref]$errs)
        if ($errs -and $errs.Count -gt 0) { return $null }
        if ($null -eq $ast.ParamBlock) { return $null }
        foreach ($p in $ast.ParamBlock.Parameters) {
            if ($p.Name.VariablePath.UserPath -eq $Name -and $null -ne $p.DefaultValue) {
                if ($p.DefaultValue -is [System.Management.Automation.Language.StringConstantExpressionAst]) { return $p.DefaultValue.Value }
                return $p.DefaultValue.SafeGetValue()
            }
        }
    }
    catch { }
    return $null
}

function Invoke-Gate {
    <#  Run one gate script and capture everything it printed plus its exit
        code. A throw, a missing script or a script that returned without an
        exit code all come back as Code -1 with the reason - the caller turns
        that into "gate unavailable", never into a pass.  #>
    param([string] $Path, [hashtable] $Arguments)
    $code = -1; $lines = @(); $err = ''
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{ Code = -1; Lines = @(); Error = ('gate script not found: {0}' -f $Path) }
    }
    $global:LASTEXITCODE = -1
    try {
        $lines = @(& $Path @Arguments *>&1 | ForEach-Object { "$_" })
        $code = $global:LASTEXITCODE
        if ($null -eq $code) { $code = -1 }
        if ($code -eq -1) { $err = 'the gate returned without an exit code' }
    }
    catch {
        $err = $_.Exception.Message
        $code = -1
    }
    return [pscustomobject]@{ Code = [int]$code; Lines = @($lines); Error = $err }
}

function New-Finding {
    param([string] $Arm, [string] $Path, [string] $Slot, [string] $Grid, [string] $Text, [string] $Match)
    if ($Text -and $Text.Length -gt 240) { $Text = $Text.Substring(0, 237) + '...' }
    return [pscustomobject]@{ arm = $Arm; path = $Path; slot = $Slot; grid = $Grid; text = $Text; match = $Match }
}

function Get-SpineFileIdentity {
    param([string] $Name)
    if ($Name -match '^t(\d+)_(\d+\.\d+)\.json$') { return [pscustomobject]@{ Kind = 'sub'; Topic = [int]$Matches[1]; Pc = $Matches[2] } }
    if ($Name -match '^t(\d+)_topic\.json$')     { return [pscustomobject]@{ Kind = 'topic'; Topic = [int]$Matches[1]; Pc = '' } }
    return $null
}

function Write-JsonFile {
    param([string] $Path, $Body)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $json = $Body | ConvertTo-Json -Depth 12
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding $false))
}

# ---------------------------------------------------------------------------
# The register: grids assigned to a sub-section, and how to recognise a row
# ---------------------------------------------------------------------------

#  Function words and pronouns that carry no content in a column heading.
#  "Equipment you selected" and "Equipment selected" are the same heading.
$HEADING_STOP = @('the', 'a', 'an', 'of', 'and', 'or', 'to', 'in', 'on', 'for', 'at', 'by', 'with', 'from', 'as',
                  'you', 'your', 'yours', 'it', 'its', 'this', 'that', 'these', 'those', 'is', 'are', 'was', 'were',
                  'be', 'been', 'being', 'do', 'does', 'did', 'has', 'have', 'had', 'not', 'no', 'would', 'will',
                  'each', 'per', 'any', 'all')

function Get-HeadingTokens {
    <#  The content words of a normalised heading, stemmed: what is left after
        the function words and pronouns go. "why that type suits the job" and
        "why that type suited the job" both give why/type/suit/job.  #>
    param([string] $Norm)
    $set = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    if (-not $Norm) { return ,$set }
    foreach ($w in ($Norm -split ' ')) {
        if (-not $w -or $HEADING_STOP -contains $w) { continue }
        [void]$set.Add((Get-Stem $w))
    }
    return ,$set
}

function Test-HeadingMatch {
    <#  Two headings are the same heading when they are equal after
        normalisation, or when their content words overlap on at least 60 per
        cent of the longer one. "what you do" (what) against "what you record"
        (what, record) is 1 of 2 and does not match; "equipment selected"
        against "equipment you selected" is 2 of 2 and does.  #>
    param([string] $ANorm, $ATokens, [string] $BNorm, $BTokens)
    if ($ANorm -eq $BNorm) { return $true }
    if ($null -eq $ATokens -or $null -eq $BTokens -or $ATokens.Count -eq 0 -or $BTokens.Count -eq 0) { return $false }
    $common = 0
    foreach ($t in $ATokens) { if ($BTokens.Contains($t)) { $common++ } }
    $need = [math]::Ceiling(0.6 * [math]::Max($ATokens.Count, $BTokens.Count))
    return ($common -ge 1 -and $common -ge $need)
}

function Get-RegisterGrids {
    <#  Every grid the register assigns to this sub-section, each with the
        normalised forms the relocation arm matches on.  #>
    param($Register, [string] $Pc)
    $out = New-Object System.Collections.Generic.List[object]
    if ($null -eq $Register -or -not $Pc) { return $out }
    $subs = Get-GateProp -Object $Register -Names @('subSections', 'subsections')
    if ($null -eq $subs -or -not (Has-Prop $subs $Pc)) { return $out }
    $entry = $subs.$Pc
    foreach ($g in (AsArr (Get-GateProp -Object $entry -Names @('tasks', 'grids') -Default @()))) {
        if ($null -eq $g) { continue }
        $headers = @(AsArr $g.headers | ForEach-Object { [string]$_ })
        $headersN = @($headers | ForEach-Object { ConvertTo-GateNormal $_ } | Where-Object { $_ })
        $assessedIdx = @(AsArr $g.assessedHeaders | ForEach-Object { [int]$_ })
        $assessedN = @($assessedIdx | Where-Object { $_ -ge 0 -and $_ -lt $headersN.Count } | ForEach-Object { $headersN[$_] })
        #  One record per heading: its normalised form, its content tokens for
        #  the paraphrase-tolerant match, and whether the learner writes it.
        $headerInfos = New-Object System.Collections.Generic.List[object]
        for ($hi = 0; $hi -lt $headersN.Count; $hi++) {
            $headerInfos.Add([pscustomobject]@{ Norm = $headersN[$hi]; Tokens = (Get-HeadingTokens -Norm $headersN[$hi]); Assessed = ($assessedIdx -contains $hi) })
        }
        $labels = @{}
        foreach ($it in (AsArr $g.items)) { $n = ConvertTo-GateNormal ([string]$it); if ($n) { $labels[$n] = [string]$it } }
        if (Has-Prop $g 'aliases' -and $null -ne $g.aliases -and $g.aliases.PSObject) {
            foreach ($p in $g.aliases.PSObject.Properties) {
                foreach ($a in (AsArr $p.Value)) { $n = ConvertTo-GateNormal ([string]$a); if ($n -and -not $labels.ContainsKey($n)) { $labels[$n] = [string]$p.Name } }
            }
        }
        $subjects = New-Object System.Collections.Generic.List[object]
        foreach ($s in (AsArr $g.subjects)) { $info = Get-SubjectInfo -Subject ([string]$s); if ($null -ne $info) { $subjects.Add($info) } }
        $allowance = 0
        $av = Get-GateProp -Object $g -Names @('allowance')
        if ($null -ne $av -and "$av" -match '^\d+$') { $allowance = [int]$av }
        $itemCount = (Get-Count $g.items)
        if ($itemCount -eq 0 -and (Has-Prop $g 'shape') -and $null -ne $g.shape) { $rv = Get-GateProp -Object $g -Names @('shape'); $rc = Get-GateProp -Object $rv -Names @('rows'); if ($rc) { $itemCount = [int]$rc } }
        $out.Add([pscustomobject]@{
            Ref = [string](Get-GateProp -Object $g -Names @('ref') -Default '')
            Id = [string](Get-GateProp -Object $g -Names @('id') -Default '')
            Kind = [string](Get-GateProp -Object $g -Names @('kind') -Default 'labelled')
            Headers = $headers; HeadersN = $headersN; AssessedN = $assessedN; HeaderInfos = $headerInfos.ToArray()
            Labels = $labels; Subjects = $subjects.ToArray(); Allowance = $allowance; ItemCount = $itemCount
            Items = @(AsArr $g.items | ForEach-Object { [string]$_ })
        })
    }
    return $out
}

function Get-SubjectInfo {
    #  How a subject is recognised in prose: its leading number (a recipe
    #  number, a document number), the first two content words of its name,
    #  and the full normalised name.
    param([string] $Subject)
    $n = ConvertTo-GateNormal $Subject
    if (-not $n) { return $null }
    $num = ''
    if ($n -match '^(\d{3,})\b') { $num = $Matches[1] }
    $words = @($n -split ' ' | Where-Object { $_ -and $_ -notmatch '^\d+$' -and $_.Length -ge 3 -and $HEAD_STOP -notcontains $_ })
    $head = ''
    if ($words.Count -ge 2) { $head = $words[0] + ' ' + $words[1] } elseif ($words.Count -eq 1) { $head = $words[0] }
    return [pscustomobject]@{ Raw = $Subject; Norm = $n; Num = $num; Head = $head }
}

function Test-TextNamesSubject {
    param([string] $Norm, $Info)
    if (-not $Norm -or $null -eq $Info) { return $false }
    if ($Info.Num -and $Norm -match ('\b' + $Info.Num + '\b')) { return $true }
    if ($Info.Norm -and $Norm.IndexOf($Info.Norm, [System.StringComparison]::Ordinal) -ge 0) { return $true }
    if ($Info.Head -and $Info.Head.Length -ge 6 -and $Norm.IndexOf($Info.Head, [System.StringComparison]::Ordinal) -ge 0) { return $true }
    return $false
}

function Find-RelocationRows {
    <#  Every table in the file sharing two or more normalised headings with
        one of this sub-section's grids, and every row in it that is an
        assessed row (a labelled grid's item or alias; a numbered grid's row
        naming one of its assessed subjects - the SAME subject test the mirror
        gate applies, so the two cannot disagree) with an assessed cell
        filled. Withholding vocabulary in the label or the cell is a withheld
        cell; a row with both a token and an answer is partly filled.  #>
    param($Json, [string] $FileName, $Grids, [string[]] $BlankTokens, [string] $WithheldRx, [hashtable] $MirrorAllow)
    $tables = @(Get-GateSpineTables -Node $Json -File $FileName -Path '' -Slot '')
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($g in $Grids) {
        if ($g.HeadersN.Count -lt 2) { continue }
        $fileKey = '{0}|{1}' -f $FileName, $g.Id
        $cleared = ''
        if ($null -ne $MirrorAllow -and $MirrorAllow.ContainsKey($fileKey)) { $cleared = $MirrorAllow[$fileKey] }
        $filledRows = New-Object System.Collections.Generic.List[object]
        $partial = New-Object System.Collections.Generic.List[object]
        $withheldRows = 0
        $sharedTables = 0
        foreach ($tb in $tables) {
            $th = @(AsArr $tb.Headers | ForEach-Object { ConvertTo-GateNormal ([string]$_) } | Where-Object { $_ })
            if ($th.Count -lt 2) { continue }
            #  THE TWO-OF-N RULE, ON CONTENT WORDS - see the header (t2_2.1).
            #  Each table column is mapped to the first grid heading it matches
            #  after normalisation, stop-word removal and stemming; a grid
            #  heading is claimed once. Two or more claimed is the task's shape.
            $colGrid = @{}
            $claimed = @{}
            for ($ci = 0; $ci -lt $th.Count; $ci++) {
                $tt = Get-HeadingTokens -Norm $th[$ci]
                for ($hi = 0; $hi -lt $g.HeaderInfos.Count; $hi++) {
                    if ($claimed.ContainsKey($hi)) { continue }
                    $ginfo = $g.HeaderInfos[$hi]
                    if (Test-HeadingMatch -ANorm $th[$ci] -ATokens $tt -BNorm $ginfo.Norm -BTokens $ginfo.Tokens) { $colGrid[$ci] = $hi; $claimed[$hi] = $true; break }
                }
            }
            $shared = @($colGrid.Keys)
            if ($shared.Count -lt 2) { continue }
            $sharedTables++
            $slotCleared = ''
            if ($null -ne $MirrorAllow -and $tb.Slot -and $MirrorAllow.ContainsKey([string]$tb.Slot)) { $slotCleared = $MirrorAllow[[string]$tb.Slot] }
            $assessedCols = @()
            foreach ($ci in ($colGrid.Keys | Sort-Object)) { if ($g.HeaderInfos[$colGrid[$ci]].Assessed) { $assessedCols += [int]$ci } }
            $rows = @($tb.Rows)
            for ($r = $tb.Skip; $r -lt $rows.Count; $r++) {
                $cells = @($rows[$r])
                if ($cells.Count -lt 2) { continue }
                $label = [string]$cells[0]
                $ln = ConvertTo-GateNormal $label
                if (-not $ln) { continue }
                if ($th -contains $ln) { continue }   # the table's own heading row repeated as a row
                $item = ''
                if ($g.Kind -eq 'numbered') {
                    $rowN = ConvertTo-GateNormal (($cells | ForEach-Object { [string]$_ }) -join ' ')
                    foreach ($s in $g.Subjects) { if (Test-TextNamesSubject -Norm $rowN -Info $s) { $item = $s.Raw; break } }
                }
                else {
                    if ($g.Labels.ContainsKey($ln)) { $item = $g.Labels[$ln] }
                    else { foreach ($k in $g.Labels.Keys) { if ($k.Length -ge 3 -and $ln.StartsWith($k + ' ')) { $item = $g.Labels[$k]; break } } }
                }
                if (-not $item) { continue }
                if ($label -match $WithheldRx) { $withheldRows++; continue }
                $cols = @($assessedCols)
                if ($cols.Count -eq 0) { $cols = @(1..($cells.Count - 1)) }
                $filled = 0; $withheld = 0
                foreach ($ci in $cols) {
                    if ($ci -ge $cells.Count) { continue }
                    $cv = [string]$cells[$ci]
                    if ($cv -match $WithheldRx) { $withheld++; continue }
                    if (Test-GateCellFilled -Text $cv -BlankTokens $BlankTokens) { $filled++ }
                }
                $rec = [pscustomobject]@{ Path = $tb.Path; Slot = [string]$tb.Slot; Label = $label; Item = $item; Filled = $filled; Withheld = $withheld; Shared = $shared.Count; Cleared = $slotCleared }
                #  A row carrying the withhold token in ANY cell is a withheld
                #  row - the mirror gate's rule, kept here so the two arms count
                #  the same rows. "Read it off card 2097" beside "Yours to work"
                #  is a pointer, not an answer, and only a reader can tell a
                #  pointer from an answer; so a token row with other text in it
                #  is REPORTED for the read, never blocked.
                if ($withheld -gt 0) { $withheldRows++; if ($filled -gt 0) { $partial.Add($rec) } }
                elseif ($filled -gt 0) { $filledRows.Add($rec) }
                else { $withheldRows++ }
            }
        }
        $out.Add([pscustomobject]@{ Grid = $g; SharedTables = $sharedTables; FilledRows = $filledRows.ToArray(); Partial = $partial.ToArray(); WithheldRows = $withheldRows; Cleared = $cleared })
    }
    return $out.ToArray()
}

function Get-ModelRowWords {
    <#  The content words of one numbered-grid row in assessor-cells.json, for
        the subject named. Read here, never printed.  #>
    param($CellsGrid, $Info)
    if ($null -eq $CellsGrid -or $null -eq $Info) { return $null }
    foreach ($rw in (AsArr $CellsGrid.rows)) {
        if ($null -eq $rw) { continue }
        $rowText = ''
        foreach ($cl in (AsArr $rw.cells)) { foreach ($b in (AsArr $cl.bullets)) { if ($null -ne $b) { $rowText += ' ' + (ConvertTo-GateNormal ([string]$b.text)) } } }
        $itemN = ConvertTo-GateNormal ([string]$rw.item)
        if ((Test-TextNamesSubject -Norm $rowText -Info $Info) -or ($itemN -and $itemN -eq $Info.Norm)) {
            $words = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
            foreach ($cl in (AsArr $rw.cells)) {
                if ([string]$cl.state -ne 'answered') { continue }
                foreach ($b in (AsArr $cl.bullets)) {
                    if ($null -eq $b) { continue }
                    foreach ($w in (AsArr $b.words)) { if ($w) { foreach ($x in ("$w" -split '\s+')) { if ($x.Length -ge 3) { [void]$words.Add($x) } } } }
                }
            }
            return $words
        }
    }
    return $null
}

# ---------------------------------------------------------------------------
# Parsers for the gates' printed findings. Loose on wording, strict on the
# rule that an exit code saying "fail" with nothing parsed is "unavailable".
# ---------------------------------------------------------------------------

function ConvertFrom-MirrorOutput {
    param([string[]] $Lines)
    $hits = New-Object System.Collections.Generic.List[object]
    $cleared = New-Object System.Collections.Generic.List[string]
    $checkSet = ''
    $tables = ''
    $cur = $null
    foreach ($raw in $Lines) {
        $ln = "$raw"
        if ($ln -match 'check-set:\s*(\d+)\s+assessed answer grids') { $checkSet = $Matches[1]; continue }
        if ($ln -match 'tables examined:\s*(\d+)') { $tables = $Matches[1]; continue }
        if ($ln -match '^\s*ok\s+(\S+)\s+vs\s+(.+?)\s+-\s+(\d+)\s+assessed row') { $cleared.Add(('{0} ({1} row(s))' -f $Matches[2], $Matches[3])); $cur = $null; continue }
        if ($ln -match '^\s*X\s+(\S+\.json)\s*$') {
            $cur = [pscustomobject]@{ File = $Matches[1]; Grid = ''; How = ''; Filled = 0; Paths = (New-Object System.Collections.Generic.List[string]); Slots = ''; Sample = '' }
            $hits.Add($cur); continue
        }
        if ($null -eq $cur) { continue }
        if ($ln -match 'reproduces\s+(.+?)\s+\(matched on (.+)\)\s*$') { $cur.Grid = $Matches[1]; $cur.How = $Matches[2]; continue }
        if ($ln -match '^\s*(\d+)\s+assessed row\(s\) answered across') { $cur.Filled = [int]$Matches[1]; continue }
        if ($ln -match '^\s*at\s+(\S+)\s+\((\d+)\s+assessed row') { $cur.Paths.Add(('{0} ({1})' -f $Matches[1], $Matches[2])); continue }
        if ($ln -match 'figure slot\(s\):\s*(.+)$') { $cur.Slots = $Matches[1].Trim(); continue }
        if ($ln -match '^\s*for instance:\s*(.+?)\s*->') { $cur.Sample = $Matches[1].Trim(); continue }
    }
    return [pscustomobject]@{ Hits = $hits.ToArray(); Cleared = $cleared.ToArray(); CheckSet = $checkSet; Tables = $tables }
}

function ConvertFrom-LeakageOutput {
    param([string[]] $Lines)
    $items = New-Object System.Collections.Generic.List[object]
    $mode = ''
    $cur = $null
    $blockSet = ''; $reportSet = ''; $vocab = ''; $cleared = 0
    foreach ($raw in $Lines) {
        $ln = "$raw"
        if ($ln -match 'check-set:\s*(\d+)\s+blocking') { $blockSet = $Matches[1]; continue }
        if ($ln -match 'check-set:\s*(\d+)\s+reported') { $reportSet = $Matches[1]; continue }
        if ($ln -match 'check-set:\s*(\d+)\s+assessor-only marking') { $vocab = $Matches[1]; continue }
        if ($ln -match '^\s*ok\s+\[') { $cleared++; $cur = $null; continue }
        if ($ln -match '^\s*REPORT ONLY\s+-\s+\d+') { $mode = 'report'; $cur = $null; continue }
        if ($ln -match '^\s*X\s+\d+\s+cell\(s\) carry assessor-only') { $mode = 'block'; $cur = $null; continue }
        if (-not $mode) { continue }
        if ($ln -match '^\s*\[(\S+)\]\s+(\S+?)(?:\s+\(slot\s+([^)]+)\))?(?:\s+\(channel:.*\))?\s*$') {
            $cur = [pscustomobject]@{ Mode = $mode; File = $Matches[1]; Path = $Matches[2]; Slot = [string]$Matches[3]; Cell = ''; Match = '' }
            $items.Add($cur); continue
        }
        if ($null -eq $cur) { continue }
        if ($ln -match '^\s*cell:\s*(.+)$')  { $cur.Cell = $Matches[1].Trim(); continue }
        if ($ln -match '^\s*match:\s*(.+)$') { $cur.Match = $Matches[1].Trim(); continue }
        if ($ln -match '^\s*\.\.\. and \d+ more') { $cur = $null; continue }
    }
    return [pscustomobject]@{ Items = $items.ToArray(); BlockSet = $blockSet; ReportSet = $reportSet; Vocab = $vocab; Cleared = $cleared }
}

# ---------------------------------------------------------------------------
# Context: everything a run needs, resolved once
# ---------------------------------------------------------------------------

function New-RunContext {
    param([string] $BuildDir)
    if (-not $BuildDir -or -not (Test-Path -LiteralPath $BuildDir)) { throw ('{0}: build directory not found: {1}' -f $GATE, $BuildDir) }
    $BuildDir = (Resolve-Path -LiteralPath $BuildDir).Path
    $ctx = [ordered]@{}
    $ctx['BuildDir'] = $BuildDir
    $ctx['ContractPath'] = Join-Path $BuildDir 'contract.json'
    $ctx['Contract'] = Get-GateJson -Path $ctx['ContractPath']
    if ($null -eq $ctx['Contract']) { throw ('{0}: no contract.json at {1}. The question pattern, the topics and the floors all come from it.' -f $GATE, $BuildDir) }
    $rc = Get-GateProp -Object $ctx['Contract'] -Names @('referenceConvention')
    $qp = [string](Get-GateProp -Object $rc -Names @('questionPattern', 'pattern'))
    if (-not $qp) { $qp = '\b(?:Q|Question|Task|Item|Deliverable|Observation)\s?(\d+)\s?(\([a-z]\))?' }
    $null = [regex]::new($qp)
    $ctx['QuestionRx'] = $qp

    $ctx['RegisterPath'] = if ($RegisterPath) { $RegisterPath } else { Join-Path $BuildDir 'withhold-register.json' }
    $ctx['Register'] = $null
    if (Test-Path -LiteralPath $ctx['RegisterPath']) { $ctx['Register'] = Get-GateJson -Path $ctx['RegisterPath'] }

    $ctx['CellsPath'] = if ($AssessorCellsPath) { $AssessorCellsPath } else { Join-Path $BuildDir 'assessor-cells.json' }
    $ctx['Cells'] = $null
    if (Test-Path -LiteralPath $ctx['CellsPath']) { $ctx['Cells'] = Get-GateJson -Path $ctx['CellsPath'] }

    $ctx['RulesPath'] = if ($RulesPath) { $RulesPath } else { Join-Path $BuildDir 'figures.json' }
    $ctx['Registry'] = $null
    if (Test-Path -LiteralPath $ctx['RulesPath']) { $ctx['Registry'] = Get-GateJson -Path $ctx['RulesPath'] }
    $ctx['MirrorAllow'] = @{}
    if ($null -ne $ctx['Registry']) {
        try { $ctx['MirrorAllow'] = Get-GateAllowList -Registry $ctx['Registry'] -Key 'mirrorAllow' -IdField @('slot', 'id', 'key', 'figure', 'grid') -GateName $GATE } catch { $ctx['MirrorAllow'] = @{} }
    }

    $ctx['CorpusDir'] = ''
    try { $ctx['CorpusDir'] = Get-GateCorpusDir -BuildDir $BuildDir -CorpusDir $CorpusDir } catch { $ctx['CorpusDir'] = '' }

    $ue = $UnitExtract
    if (-not $ue) {
        foreach ($cand in @((Join-Path $BuildDir 'unit_extract.md'), (Join-Path $BuildDir 'cleanroom\unit_extract.md'))) { if (Test-Path -LiteralPath $cand) { $ue = $cand; break } }
    }
    $ctx['UnitExtract'] = $ue

    $ctx['Blanks'] = @(Get-GateBlankTokens -BuildDir $BuildDir)
    $ctx['SpineScript']       = if ($SpineScript)       { $SpineScript }       else { Join-Path $PSScriptRoot 'Test-Spine.ps1' }
    $ctx['SpineReadScript']   = if ($SpineReadScript)   { $SpineReadScript }   else { Join-Path $PSScriptRoot 'Test-SpineRead.ps1' }
    $ctx['ConsistencyScript'] = if ($ConsistencyScript) { $ConsistencyScript } else { Join-Path $PSScriptRoot 'Test-FigureConsistency.ps1' }
    $ctx['MirrorScript']      = if ($MirrorScript)      { $MirrorScript }      else { Join-Path $PSScriptRoot 'Check-FigureMirror.ps1' }
    $ctx['LeakageScript']     = if ($LeakageScript)     { $LeakageScript }     else { Join-Path $PSScriptRoot 'Check-FigureLeakage.ps1' }

    $wr = Get-ScriptParameterDefault -Path $ctx['MirrorScript'] -Name 'WithheldRx'
    $ctx['WithheldRx'] = if ($wr -is [string] -and $wr) { [string]$wr } else { $WITHHELD_FALLBACK }
    $ctx['WithheldFrom'] = if ($wr -is [string] -and $wr) { 'the mirror gate''s own default' } else { 'this script''s fallback (the mirror gate''s default could not be read)' }
    $null = [regex]::new($ctx['WithheldRx'])

    $ctx['Unrendered'] = @{}
    foreach ($k in (Get-GateUnrenderedFields -BuildDir $BuildDir -ForSweep).Keys) { $ctx['Unrendered'][$k] = $true }
    return $ctx
}

# ---------------------------------------------------------------------------
# The run: one file, every arm
# ---------------------------------------------------------------------------

function Invoke-SubSectionTest {
    param([string] $FilePath, $Ctx, [string] $OutPath, [switch] $Silent)

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $blocks = New-Object System.Collections.Generic.List[object]
    $reports = New-Object System.Collections.Generic.List[object]
    $skips = New-Object System.Collections.Generic.List[object]
    $arms = New-Object System.Collections.Generic.List[object]
    $infos = New-Object System.Collections.Generic.List[string]
    $gateOut = [ordered]@{}

    function Add-Block  { param([string] $Arm, [string] $Path, [string] $Slot, [string] $Grid, [string] $Text, [string] $Match) $blocks.Add((New-Finding -Arm $Arm -Path $Path -Slot $Slot -Grid $Grid -Text $Text -Match $Match)) }
    function Add-Report { param([string] $Arm, [string] $Path, [string] $Slot, [string] $Grid, [string] $Text, [string] $Match) $reports.Add((New-Finding -Arm $Arm -Path $Path -Slot $Slot -Grid $Grid -Text $Text -Match $Match)) }
    function Add-Skip   { param([string] $Arm, [string] $Reason) $skips.Add([pscustomobject]@{ arm = $Arm; reason = $Reason }) }
    function Add-Arm    { param([string] $Arm, [string] $CheckSet, [string] $Result, [string] $Kind) $arms.Add([pscustomobject]@{ arm = $Arm; kind = $Kind; checkSet = $CheckSet; result = $Result }) }
    function Add-Unavailable { param([string] $Arm, [string] $Why) $blocks.Add((New-Finding -Arm $Arm -Path '' -Slot '' -Grid '' -Text ('gate unavailable: {0}' -f $Why) -Match 'gate unavailable')); Add-Arm $Arm '?' 'UNAVAILABLE - blocks' 'block' }
    function Count-Of { param([string] $Arm, $List) return @($List | Where-Object { $_.arm -eq $Arm }).Count }
    function Arm-Result {
        param([string] $Arm)
        $b = Count-Of $Arm $blocks; $r = Count-Of $Arm $reports
        if ($b -gt 0 -and $r -gt 0) { return ('{0} BLOCK, {1} report' -f $b, $r) }
        if ($b -gt 0) { return ('{0} BLOCK' -f $b) }
        if ($r -gt 0) { return ('{0} report' -f $r) }
        return 'ok'
    }

    $fullPath = (Resolve-Path -LiteralPath $FilePath).Path
    $name = Split-Path $fullPath -Leaf
    if (-not $OutPath) { $OutPath = $fullPath + '.gate.json' }

    # --- the bytes, hashed once; every check below reads these bytes
    $bytes = [System.IO.File]::ReadAllBytes($fullPath)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $hash = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '') } finally { $sha.Dispose() }
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    $text = $text.TrimStart([char]0xFEFF)
    $json = $null
    $parseError = ''
    try { $json = $text | ConvertFrom-Json } catch { $parseError = $_.Exception.Message }

    $ident = Get-SpineFileIdentity -Name $name
    $pc = ''
    if ($null -ne $ident) { $pc = $ident.Pc }
    $grids = @()
    $registerState = ''
    if ($null -eq $Ctx['Register']) { $registerState = ('withhold-register.json not found at {0}' -f $Ctx['RegisterPath']) }
    elseif ($null -eq $ident) { $registerState = ('{0} is not named t{{T}}_{{PC}}.json or t{{T}}_topic.json, so no register entry can be looked up' -f $name) }
    elseif ($ident.Kind -eq 'topic') { $registerState = 'topic file: the register assigns grids to sub-sections, not to a topic wrapper' }
    else {
        $grids = @(Get-RegisterGrids -Register $Ctx['Register'] -Pc $pc)
        if ($grids.Count -eq 0) {
            $subs = Get-GateProp -Object $Ctx['Register'] -Names @('subSections', 'subsections')
            if ($null -eq $subs -or -not (Has-Prop $subs $pc)) { $registerState = ('the register has no entry for sub-section {0}' -f $pc) }
            else { $registerState = ('the register assigns no assessed grid to sub-section {0}' -f $pc) }
        }
    }
    $ownIds = @($grids | ForEach-Object { $_.Id } | Where-Object { $_ })
    $ownRefs = @($grids | ForEach-Object { $_.Ref } | Where-Object { $_ })

    if (-not $Silent -and -not $Quiet) {
        Write-Host ''
        Write-Host ('{0} - {1}{2}' -f $GATE.ToUpperInvariant(), $name, $(if ($pc) { (' (sub-section {0}, topic {1})' -f $pc, $ident.Topic) } elseif ($null -ne $ident) { (' (topic {0} wrapper)' -f $ident.Topic) } else { '' })) -ForegroundColor Cyan
        Write-Host ('  build:    {0}' -f $Ctx['BuildDir']) -ForegroundColor DarkGray
        Write-Host ('  sha256:   {0}' -f $hash.ToLowerInvariant()) -ForegroundColor DarkGray
        if ($grids.Count -gt 0) {
            Write-Host ('  register: {0} grid(s) assigned to {1} - {2}' -f $grids.Count, $pc, (($grids | ForEach-Object { '{0} [{1}, allowance {2}]' -f $_.Ref, $_.Kind, $_.Allowance }) -join '; ')) -ForegroundColor DarkGray
        }
        else { Write-Host ('  register: {0}' -f $registerState) -ForegroundColor Yellow }
        Write-Host ('  withholding vocabulary from {0}' -f $Ctx['WithheldFrom']) -ForegroundColor DarkGray
    }

    $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('subsection_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $tmpSpine = Join-Path $tmpRoot 'spine'
    $tmpFc = Join-Path $tmpRoot 'fc'
    try {
        New-Item -ItemType Directory -Force -Path $tmpSpine | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $tmpFc 'spine') | Out-Null
        [System.IO.File]::WriteAllBytes((Join-Path $tmpSpine $name), $bytes)
        [System.IO.File]::WriteAllBytes((Join-Path $tmpFc ('spine\' + $name)), $bytes)
        $tmpFile = Join-Path $tmpSpine $name

        # ===================================================================
        # BLOCK arm 1: Test-Spine -File
        # ===================================================================
        $armT = [System.Diagnostics.Stopwatch]::StartNew()
        $resultTmp = Join-Path $tmpRoot 'spine-result.json'
        $sp = @(Get-ScriptParameterName -Path $Ctx['SpineScript'])
        if ($sp -notcontains 'File' -or $sp -notcontains 'ResultPath') {
            Add-Unavailable 'spine' ('Test-Spine at {0} does not declare -File and -ResultPath{1}' -f $Ctx['SpineScript'], $(if ($sp.Count -eq 0) { ' (script missing or unparseable)' } else { '' }))
        }
        else {
            $sa = @{ File = $tmpFile; BuildDir = $Ctx['BuildDir']; ResultPath = $resultTmp }
            if ($sp -contains 'Quiet') { $sa['Quiet'] = $true }
            $g = Invoke-Gate -Path $Ctx['SpineScript'] -Arguments $sa
            $gateOut['spine'] = $g.Lines
            $res = $null
            if (Test-Path -LiteralPath $resultTmp) { try { $res = Get-GateJson -Path $resultTmp } catch { $res = $null } }
            if ($g.Code -notin @(0, 1) -or $null -eq $res) {
                Add-Unavailable 'spine' ('Test-Spine exit {0}{1}{2}' -f $g.Code, $(if ($g.Error) { ' - ' + $g.Error } else { '' }), $(if ($null -eq $res) { ' - no result file' } elseif ($res.failures) { ' - ' + (@($res.failures) -join '; ') } else { '' }))
            }
            else {
                foreach ($f in (AsArr $res.failures)) { Add-Block 'spine' '' '' '' ([string]$f) 'Test-Spine failure' }
                foreach ($w in (AsArr $res.warnings)) { Add-Report 'spine' '' '' '' ([string]$w) 'Test-Spine warning' }
                foreach ($k in (AsArr $res.skippedArms)) { if ($null -ne $k) { Add-Skip ('spine/' + [string]$k.arm) ([string]$k.reason) } }
                $ran = Get-Count $res.ranArms
                if ($res.sha256 -and ([string]$res.sha256).ToUpperInvariant() -ne $hash) { Add-Block 'spine' '' '' '' ('Test-Spine hashed different bytes ({0}) from this run ({1})' -f $res.sha256, $hash) 'hash mismatch' }
                Add-Arm 'spine' ('{0} arm(s) ran, {1} skipped' -f $ran, (Get-Count $res.skippedArms)) (Arm-Result 'spine') 'block'
            }
        }
        $infos.Add(('spine {0:N1}s' -f $armT.Elapsed.TotalSeconds))

        $jsonOk = ($null -ne $json -and -not $parseError)
        if (-not $jsonOk) {
            if ((Count-Of 'spine' $blocks) -eq 0) { Add-Block 'parse' '' '' '' ('the file is not valid JSON: {0}' -f $parseError) 'parse' }
            foreach ($a in @('spine-read', 'figure-registry', 'mirror-own', 'mirror-other', 'relocation', 'relocation-numbered', 'leakage', 'note-count')) { Add-Skip $a 'the file is not valid JSON; fix the parse first' }
        }
        else {
            # ===============================================================
            # BLOCK arm 2: Test-SpineRead, scoped to a spine dir holding
            # only this file; renderers and the contract from the real build
            # ===============================================================
            $armT.Restart()
            $rp = @(Get-ScriptParameterName -Path $Ctx['SpineReadScript'])
            if ($rp -notcontains 'BuildDir' -or $rp -notcontains 'SpineDir') {
                Add-Unavailable 'spine-read' ('Test-SpineRead at {0} does not declare -BuildDir and -SpineDir{1}' -f $Ctx['SpineReadScript'], $(if ($rp.Count -eq 0) { ' (script missing or unparseable)' } else { '' }))
            }
            else {
                $g = Invoke-Gate -Path $Ctx['SpineReadScript'] -Arguments @{ BuildDir = $Ctx['BuildDir']; SpineDir = $tmpSpine }
                $gateOut['spine-read'] = $g.Lines
                $n = 0; $cs = '?'
                foreach ($ln in $g.Lines) {
                    if ($ln -match 'check-set:\s*(\d+)\s+field names') { $cs = $Matches[1] }
                    if ($ln -match '^\s*X\s+(UNREAD|MISSING)\s+(\S+)\s+->\s+(\S+)\s+\((.+)\)\s*$') { $n++; Add-Block 'spine-read' $Matches[3] '' '' ('{0}: {1}' -f $Matches[1], $Matches[4]) $Matches[1] }
                }
                if ($g.Code -eq 0) { Add-Arm 'spine-read' ('{0} field names read by a renderer' -f $cs) (Arm-Result 'spine-read') 'block' }
                elseif ($g.Code -in @(11, 12, 13) -and $n -gt 0) { Add-Arm 'spine-read' ('{0} field names read by a renderer' -f $cs) (Arm-Result 'spine-read') 'block' }
                else { Add-Unavailable 'spine-read' ('Test-SpineRead exit {0}{1}{2}' -f $g.Code, $(if ($g.Error) { ' - ' + $g.Error } else { '' }), $(if ($g.Code -in @(11, 12, 13)) { ' with no finding this wrapper could parse' } else { '' })) }
            }
            $infos.Add(('spine-read {0:N1}s' -f $armT.Elapsed.TotalSeconds))

            # ===============================================================
            # BLOCK arm 3: the figure registry - forbid / forbidRx /
            # assessorOnly block; require / deckMust report (a sibling may
            # carry them)
            # ===============================================================
            $armT.Restart()
            $cp = @(Get-ScriptParameterName -Path $Ctx['ConsistencyScript'])
            if ($cp -notcontains 'BuildDir') {
                Add-Unavailable 'figure-registry' ('Test-FigureConsistency at {0} does not declare -BuildDir{1}' -f $Ctx['ConsistencyScript'], $(if ($cp.Count -eq 0) { ' (script missing or unparseable)' } else { '' }))
            }
            elseif (-not (Test-Path -LiteralPath $Ctx['RulesPath'])) {
                Add-Unavailable 'figure-registry' ('no figure registry at {0}' -f $Ctx['RulesPath'])
            }
            else {
                $ca = @{ BuildDir = $tmpFc }
                if ($cp -contains 'RulesPath') { $ca['RulesPath'] = $Ctx['RulesPath'] }
                else { Copy-Item -LiteralPath $Ctx['RulesPath'] -Destination (Join-Path $tmpFc 'figures.json') -Force }
                $g = Invoke-Gate -Path $Ctx['ConsistencyScript'] -Arguments $ca
                $gateOut['figure-registry'] = $g.Lines
                $nForbid = 0; $nAssessor = 0; $nRequire = 0; $nDeck = 0
                $reg = $Ctx['Registry']
                if ($null -ne $reg) {
                    foreach ($fg in (AsArr $reg.figures)) { if ($null -eq $fg) { continue }; $nForbid += (Get-Count $fg.forbid) + (Get-Count $fg.forbidRx); $nRequire += (Get-Count $fg.require) }
                    $nAssessor = Get-Count $reg.assessorOnly
                    $nDeck = Get-Count $reg.deckMust
                }
                $parsed = 0
                #  require / deckMust are whole-spine facts: one file never
                #  carries every registered figure, so they are folded into ONE
                #  report each rather than forty lines that bury the real hits.
                $missingReq = New-Object System.Collections.Generic.List[string]
                $missingDeck = New-Object System.Collections.Generic.List[string]
                foreach ($ln in $g.Lines) {
                    if ($ln -notmatch '^\s*X\s+(.+)$') { continue }
                    $body = $Matches[1]
                    $parsed++
                    if ($body -match '^\[(.+?)\]\s+stale\s+(?:''(.+?)''\s+\(or a variant\)|pattern\s+''(.+?)'')\s+x(\d+)') {
                        $what = if ($Matches[2]) { $Matches[2] } else { $Matches[3] }
                        Add-Block 'figure-registry' '' '' '' ('[{0}] stale figure ''{1}'' (or a variant) x{2} - the registry forbids it' -f $Matches[1], $what, $Matches[4]) 'forbid'
                    }
                    elseif ($body -match '^BENCHMARK LEAKAGE:\s+''(.+?)''\s+\(or a variant\)\s+x(\d+)\s+in\s+\S+\s+-\s+(.+)$') {
                        Add-Block 'figure-registry' '' '' '' ('registered assessor-only string x{0} - {1}' -f $Matches[2], $Matches[3]) 'assessorOnly'
                    }
                    elseif ($body -match '^BENCHMARK LEAKAGE:') {
                        Add-Block 'figure-registry' '' '' '' 'registered assessor-only string present (see figures.json assessorOnly)' 'assessorOnly'
                    }
                    elseif ($body -match '^\[(.+?)\]\s+required\s+''(.+?)''\s+appears NOWHERE') {
                        $missingReq.Add(('[{0}] ''{1}''' -f $Matches[1], $Matches[2]))
                    }
                    elseif ($body -match '^DECK GAP:\s+deck-facing text never carries\s+''(.+?)''') {
                        $missingDeck.Add(("'" + $Matches[1] + "'"))
                    }
                    elseif ($body -match '^DECK GAP:\s+(.+)$') {
                        $missingDeck.Add($Matches[1])
                    }
                    else { Add-Block 'figure-registry' '' '' '' ('registry finding this wrapper could not classify, so it blocks: {0}' -f $body) 'unclassified' }
                }
                if ($missingReq.Count -gt 0) {
                    Add-Report 'figure-registry' '' '' '' ('{0} of {1} required figure(s) are not in this file - a sibling may carry them; decided on the whole spine: {2}' -f $missingReq.Count, $nRequire, ($missingReq -join ', ')) 'require'
                }
                if ($missingDeck.Count -gt 0) {
                    Add-Report 'figure-registry' '' '' '' ('{0} of {1} deck-must term(s) are not in this file''s slides - decided on the whole spine: {2}' -f $missingDeck.Count, $nDeck, ($missingDeck -join ', ')) 'deckMust'
                }
                if ($g.Code -eq 0 -or ($g.Code -eq 8 -and $parsed -gt 0)) {
                    Add-Arm 'figure-registry' ('{0} forbid, {1} assessor-only (block); {2} require, {3} deck-must (report)' -f $nForbid, $nAssessor, $nRequire, $nDeck) (Arm-Result 'figure-registry') 'block'
                }
                else { Add-Unavailable 'figure-registry' ('Test-FigureConsistency exit {0}{1}' -f $g.Code, $(if ($g.Error) { ' - ' + $g.Error } else { '' })) }
            }
            $infos.Add(('figure-registry {0:N1}s' -f $armT.Elapsed.TotalSeconds))

            # ===============================================================
            # BLOCK arm 4 / REPORT arm: the answer-grid mirror. Own grids
            # block beyond the register's allowance; other sub-sections' grids
            # report.
            # ===============================================================
            $armT.Restart()
            $mp = @(Get-ScriptParameterName -Path $Ctx['MirrorScript'])
            if ($mp -notcontains 'BuildDir' -or ($mp -notcontains 'SpineFile' -and $mp -notcontains 'SpineDir')) {
                Add-Unavailable 'mirror-own' ('Check-FigureMirror at {0} declares neither -SpineFile nor -SpineDir with -BuildDir{1}' -f $Ctx['MirrorScript'], $(if ($mp.Count -eq 0) { ' (script missing or unparseable)' } else { '' }))
                Add-Skip 'mirror-other' 'the mirror gate is unavailable'
            }
            elseif ($grids.Count -eq 0 -and $null -eq $Ctx['Register']) {
                Add-Unavailable 'mirror-own' $registerState
                Add-Skip 'mirror-other' 'the register is missing, so no grid can be told from another'
            }
            else {
                $ma = @{ BuildDir = $Ctx['BuildDir'] }
                $scoped = ''
                if ($mp -contains 'SpineFile') { $ma['SpineFile'] = $tmpFile; $scoped = '-SpineFile' }
                else { $ma['SpineDir'] = $tmpSpine; $scoped = '-SpineDir (temp dir holding only this file)' }
                if ($mp -contains 'CorpusDir' -and $Ctx['CorpusDir']) { $ma['CorpusDir'] = $Ctx['CorpusDir'] }
                if ($mp -contains 'RulesPath' -and (Test-Path -LiteralPath $Ctx['RulesPath'])) { $ma['RulesPath'] = $Ctx['RulesPath'] }
                $limitApplied = $false
                if ($mp -contains 'MaxWorkedPerGrid') { $ma['MaxWorkedPerGrid'] = 0; $limitApplied = $true }
                $g = Invoke-Gate -Path $Ctx['MirrorScript'] -Arguments $ma
                $gateOut['mirror'] = $g.Lines
                $pm = ConvertFrom-MirrorOutput -Lines $g.Lines
                if ($g.Code -notin @(0, 1)) {
                    Add-Unavailable 'mirror-own' ('Check-FigureMirror exit {0}{1}' -f $g.Code, $(if ($g.Error) { ' - ' + $g.Error } else { '' }))
                    Add-Skip 'mirror-other' 'the mirror gate refused'
                }
                elseif ($g.Code -eq 1 -and $pm.Hits.Count -eq 0) {
                    Add-Unavailable 'mirror-own' 'Check-FigureMirror exit 1 with no hit this wrapper could parse from its output'
                    Add-Skip 'mirror-other' 'the mirror gate''s output could not be parsed'
                }
                else {
                    foreach ($h in $pm.Hits) {
                        $own = $null
                        foreach ($gr in $grids) { if (($gr.Id -and $h.Grid -eq $gr.Id) -or ($gr.Ref -and $h.Grid -like ('*' + $gr.Ref))) { $own = $gr; break } }
                        $where = ($h.Paths -join ', ')
                        $firstPath = if ($h.Paths.Count) { ($h.Paths[0] -split ' ')[0] } else { '' }
                        if ($null -ne $own) {
                            if ($h.Filled -gt $own.Allowance) {
                                Add-Block 'mirror-own' $firstPath $h.Slots $h.Grid ('{0} assessed row(s) answered across this file, allowance {1} ({2}); at {3}' -f $h.Filled, $own.Allowance, $own.Kind, $where) ('matched on ' + $h.How)
                            }
                            else { $infos.Add(('mirror-own: {0} row(s) on {1} within allowance {2}' -f $h.Filled, $h.Grid, $own.Allowance)) }
                        }
                        else {
                            Add-Report 'mirror-other' $firstPath $h.Slots $h.Grid ('{0} assessed row(s) answered on a grid assigned to another sub-section; at {1}' -f $h.Filled, $where) ('matched on ' + $h.How)
                        }
                    }
                    foreach ($c in $pm.Cleared) { $infos.Add(('mirror: cleared at 3d by figures.json mirrorAllow - {0}' -f $c)) }
                    $csm = '{0} assessed grids, {1} table(s) in this file, {2} own grid(s); {3}{4}' -f $(if ($pm.CheckSet) { $pm.CheckSet } else { '?' }), $(if ($pm.Tables) { $pm.Tables } else { '?' }), $grids.Count, $scoped, $(if ($limitApplied) { ', limit 0 so the register allowance decides' } else { ', gate limit only - rows at or under it are invisible here' })
                    Add-Arm 'mirror-own' $csm (Arm-Result 'mirror-own') 'block'
                    Add-Arm 'mirror-other' 'same sweep, grids of other sub-sections' (Arm-Result 'mirror-other') 'report'
                    if (-not $pm.CheckSet -and $g.Code -eq 0) { Add-Report 'mirror-own' '' '' '' 'the mirror gate printed no check-set size; its pass is taken from the exit code alone' 'check-set unknown' }
                }
            }
            $infos.Add(('mirror {0:N1}s' -f $armT.Elapsed.TotalSeconds))

            # ===============================================================
            # BLOCK arm 5: relocation - this script's own walk of every table
            # ===============================================================
            $armT.Restart()
            if ($null -eq $Ctx['Register']) { Add-Unavailable 'relocation' $registerState }
            elseif ($grids.Count -eq 0) { Add-Skip 'relocation' $registerState }
            else {
                $rel = @(Find-RelocationRows -Json $json -FileName $name -Grids $grids -BlankTokens $Ctx['Blanks'] -WithheldRx $Ctx['WithheldRx'] -MirrorAllow $Ctx['MirrorAllow'])
                $tablesN = @(Get-GateSpineTables -Node $json -File $name -Path '' -Slot '').Count
                $sharedN = 0
                foreach ($r in $rel) {
                    $sharedN += $r.SharedTables
                    $gr = $r.Grid
                    if ($r.Cleared) { $infos.Add(('relocation: {0} cleared at 3d by figures.json mirrorAllow: {1}' -f $gr.Ref, $r.Cleared)); continue }
                    foreach ($p in $r.Partial) {
                        if ($p.Cleared) { continue }
                        Add-Report 'relocation' $p.Path $p.Slot $gr.Id ('token row with other text: row ''{0}'' ({1}) carries the withhold token in {2} cell(s) and text in {3} other assessed cell(s) - a pointer to the teaching is fine, an answer beside a token is a filled row; read it. Counted as withheld, as the mirror gate counts it' -f $p.Label, $p.Item, $p.Withheld, $p.Filled) ('{0} shared heading(s) with {1}' -f $p.Shared, $gr.Ref)
                    }
                    $live = @($r.FilledRows | Where-Object { -not $_.Cleared })
                    if ($live.Count -gt $gr.Allowance) {
                        foreach ($p in $live) {
                            Add-Block 'relocation' $p.Path $p.Slot $gr.Id ('assessed row ''{0}'' ({1}) worked under {2} heading(s) shared with {3}: {4} assessed cell(s) filled; {5} worked row(s) in this file, allowance {6}' -f $p.Label, $p.Item, $p.Shared, $gr.Ref, $p.Filled, $live.Count, $gr.Allowance) ('relocation - ' + $gr.Kind)
                        }
                    }
                    elseif ($live.Count -gt 0) { $infos.Add(('relocation: {0} worked row(s) on {1} within allowance {2} - {3}' -f $live.Count, $gr.Ref, $gr.Allowance, (($live | ForEach-Object { $_.Label }) -join '; '))) }
                }
                Add-Arm 'relocation' ('{0} own grid(s) x {1} table(s); {2} table(s) share 2+ headings' -f $grids.Count, $tablesN, $sharedN) (Arm-Result 'relocation') 'block'
            }
            $infos.Add(('relocation {0:N1}s' -f $armT.Elapsed.TotalSeconds))

            # ===============================================================
            # REPORT arm: a numbered grid's subject paired with content words
            # of that task's model row (assessor-cells.json, gate-only)
            # ===============================================================
            $armT.Restart()
            $numbered = @($grids | Where-Object { $_.Kind -eq 'numbered' -and $_.Subjects.Count -gt 0 })
            if ($grids.Count -eq 0) { Add-Skip 'relocation-numbered' $registerState }
            elseif ($numbered.Count -eq 0) { Add-Arm 'relocation-numbered' 'no numbered grid with subjects in this sub-section' 'ok' 'report' }
            elseif ($null -eq $Ctx['Cells']) { Add-Skip 'relocation-numbered' ('assessor-cells.json not found at {0} - the model-row content words cannot be read' -f $Ctx['CellsPath']) }
            else {
                $spineCells = @(Get-GateSpineCells -Node $json -File $name -Path '' -Channel '' -Slot '' -Skip $Ctx['Unrendered'])
                $mapped = 0; $unmapped = New-Object System.Collections.Generic.List[string]
                foreach ($gr in $numbered) {
                    $cg = $null
                    foreach ($x in (AsArr $Ctx['Cells'].grids)) { if ($null -ne $x -and (([string]$x.ref -eq $gr.Ref) -or ([string]$x.id -eq $gr.Id))) { $cg = $x; break } }
                    if ($null -eq $cg) { $unmapped.Add($gr.Ref + ' (no model grid)'); continue }
                    foreach ($s in $gr.Subjects) {
                        $words = Get-ModelRowWords -CellsGrid $cg -Info $s
                        if ($null -eq $words -or $words.Count -eq 0) { $unmapped.Add(('{0}: {1}' -f $gr.Ref, $s.Raw)); continue }
                        $mapped++
                        foreach ($cell in $spineCells) {
                            $n = ConvertTo-GateNormal $cell.Text
                            if (-not (Test-TextNamesSubject -Norm $n -Info $s)) { continue }
                            $stems = @($n -split ' ' | Where-Object { $_ } | ForEach-Object { Get-Stem $_ })
                            $hits = 0
                            foreach ($mw in $words) {
                                foreach ($st in $stems) {
                                    if (($st.Length -ge 4 -and $mw.StartsWith($st)) -or ($mw.Length -ge 4 -and $st.StartsWith($mw))) { $hits++; break }
                                }
                            }
                            if ($hits -ge 2) {
                                Add-Report 'relocation-numbered' $cell.Path $cell.Slot $gr.Id ('names subject ''{0}'' beside {1} of {2} content words of that task''s model row for it (words withheld) - teach the reasoning on an unassessed subject' -f $s.Raw, $hits, $words.Count) ('subject + model-row words: ' + $gr.Ref)
                            }
                        }
                    }
                }
                Add-Arm 'relocation-numbered' ('{0} numbered grid(s), {1} subject(s) mapped to a model row{2}' -f $numbered.Count, $mapped, $(if ($unmapped.Count) { ('; unmapped: ' + ($unmapped -join ', ')) } else { '' })) (Arm-Result 'relocation-numbered') 'report'
            }
            $infos.Add(('relocation-numbered {0:N1}s' -f $armT.Elapsed.TotalSeconds))

            # ===============================================================
            # REPORT arm: the leakage sweep, unit extract passed
            # ===============================================================
            $armT.Restart()
            $lp = @(Get-ScriptParameterName -Path $Ctx['LeakageScript'])
            if ($lp -notcontains 'BuildDir' -or ($lp -notcontains 'SpineFile' -and $lp -notcontains 'SpineDir')) {
                Add-Unavailable 'leakage' ('Check-FigureLeakage at {0} declares neither -SpineFile nor -SpineDir with -BuildDir{1}' -f $Ctx['LeakageScript'], $(if ($lp.Count -eq 0) { ' (script missing or unparseable)' } else { '' }))
            }
            elseif (-not $Ctx['UnitExtract'] -or -not (Test-Path -LiteralPath $Ctx['UnitExtract'])) {
                Add-Unavailable 'leakage' 'no unit extract (unit_extract.md beside the build, or -UnitExtract) - without it every unit line reads as assessor-only and the findings would be false'
            }
            elseif ($lp -notcontains 'ExcludeText' -and $lp -notcontains 'UnitExtract') {
                Add-Unavailable 'leakage' 'this copy of the leakage gate accepts neither -ExcludeText nor -UnitExtract, so the unit corpus cannot be passed'
            }
            else {
                $la = @{ BuildDir = $Ctx['BuildDir'] }
                if ($lp -contains 'SpineFile') { $la['SpineFile'] = $tmpFile } else { $la['SpineDir'] = $tmpSpine }
                if ($lp -contains 'ExcludeText') { $la['ExcludeText'] = @($Ctx['UnitExtract']) } else { $la['UnitExtract'] = $Ctx['UnitExtract'] }
                if ($lp -contains 'CorpusDir' -and $Ctx['CorpusDir']) { $la['CorpusDir'] = $Ctx['CorpusDir'] }
                if ($lp -contains 'RulesPath' -and (Test-Path -LiteralPath $Ctx['RulesPath'])) { $la['RulesPath'] = $Ctx['RulesPath'] }
                $g = Invoke-Gate -Path $Ctx['LeakageScript'] -Arguments $la
                $gateOut['leakage'] = $g.Lines
                $pl = ConvertFrom-LeakageOutput -Lines $g.Lines
                if ($g.Code -notin @(0, 1)) { Add-Unavailable 'leakage' ('Check-FigureLeakage exit {0}{1}' -f $g.Code, $(if ($g.Error) { ' - ' + $g.Error } else { '' })) }
                elseif ($g.Code -eq 1 -and @($pl.Items | Where-Object { $_.Mode -eq 'block' }).Count -eq 0) { Add-Unavailable 'leakage' 'Check-FigureLeakage exit 1 with no finding this wrapper could parse from its output' }
                else {
                    foreach ($it in $pl.Items) {
                        $tag = if ($it.Mode -eq 'block') { 'BLOCKS AT 3c - assessor-only run or marking phrase' } else { 'shorter shared run - read at 3d' }
                        Add-Report 'leakage' $it.Path $it.Slot '' ('{0}: {1}' -f $tag, $it.Match) $it.Mode
                    }
                    if ($pl.Cleared -gt 0) { $infos.Add(('leakage: {0} hit(s) cleared at 3d by figures.json leakageAllow' -f $pl.Cleared)) }
                    Add-Arm 'leakage' ('{0} blocking / {1} reported phrases, {2} marking phrases' -f $(if ($pl.BlockSet) { $pl.BlockSet } else { '?' }), $(if ($pl.ReportSet) { $pl.ReportSet } else { '?' }), $(if ($pl.Vocab) { $pl.Vocab } else { '?' })) (Arm-Result 'leakage') 'report'
                }
            }
            $infos.Add(('leakage {0:N1}s' -f $armT.Elapsed.TotalSeconds))

            # ===============================================================
            # REPORT arm: a note or self-check naming a task beside its row count
            # ===============================================================
            $armT.Restart()
            if ($grids.Count -eq 0) { Add-Skip 'note-count' $registerState }
            else {
                $counts = @{}
                foreach ($gr in $grids) { if ($gr.Ref -and $gr.ItemCount -ge 1 -and $gr.ItemCount -le 20) { $counts[$gr.Ref] = $gr.ItemCount } }
                $noteCells = @(Get-GateSpineCells -Node $json -File $name -Path '' -Channel '' -Slot '' -Skip $Ctx['Unrendered'] | Where-Object { $_.Path -match '^slides\[\d+\]\.notes$' -or $_.Path -like 'selfCheck*' })
                $sentences = 0
                foreach ($cell in $noteCells) {
                    foreach ($sent in ([string]$cell.Text -split '(?<=[.!?])\s+')) {
                        if (-not $sent) { continue }
                        $ms = [regex]::Matches($sent, $Ctx['QuestionRx'])
                        if ($ms.Count -eq 0) { continue }
                        $sentences++
                        $stripped = [regex]::Replace($sent, $Ctx['QuestionRx'], ' ')
                        $seen = @{}
                        foreach ($m in $ms) {
                            $ref = ($m.Value -replace '\s+', ' ').Trim()
                            if (-not $counts.ContainsKey($ref) -or $seen.ContainsKey($ref)) { continue }
                            $seen[$ref] = $true
                            $nn = $counts[$ref]
                            $word = $NUMBER_WORDS[$nn]
                            $rx = '(?i)\b(' + $nn + '|' + $word + ')\b(?!' + $UNIT_RX.Substring(4) + ')'
                            if ($stripped -match $rx) {
                                Add-Report 'note-count' $cell.Path $cell.Slot '' ('names {0} and the number {1} (''{2}'') in one sentence - the task has {1} item(s); a note never counts the task''s rows' -f $ref, $nn, $word) ('row count beside ' + $ref)
                            }
                        }
                    }
                }
                Add-Arm 'note-count' ('{0} ref(s) with a row count; {1} note/self-check sentence(s) naming a task' -f $counts.Count, $sentences) (Arm-Result 'note-count') 'report'
            }
            $infos.Add(('note-count {0:N1}s' -f $armT.Elapsed.TotalSeconds))
        }
    }
    finally {
        if ($tmpRoot -and (Test-Path -LiteralPath $tmpRoot) -and $tmpRoot.Length -gt 12) { Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue }
    }

    # --- dedupe, verdict, gate.json. Reports are ordered so the ones an author
    #     can act on in this file (relocation pairings, leakage runs, row counts,
    #     another sub-section's grid) come before the whole-spine registry facts.
    $armOrder = @{ 'relocation-numbered' = 0; 'leakage' = 1; 'note-count' = 2; 'mirror-other' = 3; 'mirror-own' = 4; 'spine' = 5; 'figure-registry' = 9 }
    $blockArr = @($blocks.ToArray() | Sort-Object arm, path, grid, text -Unique)
    $reportArr = @($reports.ToArray() | Sort-Object arm, path, grid, text -Unique | Sort-Object { if ($armOrder.ContainsKey($_.arm)) { $armOrder[$_.arm] } else { 8 } }, path)
    $verdict = if ($blockArr.Count -eq 0) { 'pass' } else { 'fail' }
    $body = [ordered]@{}
    $body['file']        = $fullPath
    $body['sha256']      = $hash
    $body['gateVersion'] = ('{0} {1}' -f $GATE, $GATE_VERSION)
    $body['ranAt']       = (Get-Date).ToString('o')
    $body['mode']        = 'file'
    $body['verdict']     = $verdict
    $body['blocks']      = $blockArr
    $body['reports']     = $reportArr
    $body['skippedArms'] = $skips.ToArray()
    $body['arms']        = $arms.ToArray()
    $body['subSection']  = $pc
    $body['buildDir']    = $Ctx['BuildDir']
    $body['registerGrids'] = @($ownRefs)
    $body['notes']       = @($infos)
    $body['elapsedSeconds'] = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    $written = ''
    try { Write-JsonFile -Path $OutPath -Body ([pscustomobject]$body); $written = $OutPath } catch { $written = '' }

    $result = [pscustomobject]@{
        File = $fullPath; Name = $name; Sha256 = $hash; Verdict = $verdict; Blocks = $blockArr; Reports = $reportArr
        Skipped = $skips.ToArray(); Arms = $arms.ToArray(); Notes = @($infos); GateJson = $written; Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1)
        GateOutput = $gateOut; RanAt = $body['ranAt']
    }
    if (-not $Silent) { Write-RunReport -R $result }
    return $result
}

function Write-RunReport {
    param($R)
    if ($Quiet) { return }
    if ($ShowGateOutput) {
        foreach ($k in $R.GateOutput.Keys) {
            Write-Host ''
            Write-Host ('  ---- {0} printed:' -f $k) -ForegroundColor DarkGray
            foreach ($ln in $R.GateOutput[$k]) { Write-Host ('  | ' + $ln) -ForegroundColor DarkGray }
        }
    }
    Write-Host ''
    Write-Host ('  {0,-21} {1,-72} {2}' -f 'arm', 'check-set', 'result') -ForegroundColor DarkGray
    foreach ($a in $R.Arms) {
        $col = 'Green'
        if ($a.result -match 'BLOCK|UNAVAILABLE') { $col = 'Red' } elseif ($a.result -match 'report') { $col = 'Yellow' }
        $cs = [string]$a.checkSet
        if ($cs.Length -gt 72) { $cs = $cs.Substring(0, 69) + '...' }
        Write-Host ('  {0,-21} {1,-72} {2}' -f $a.arm, $cs, $a.result) -ForegroundColor $col
    }
    foreach ($n in $R.Notes) { if ($n -notmatch '^\S+ \d+(\.\d+)?s$') { Write-Host ('  - ' + $n) -ForegroundColor DarkGray } }

    #  The verdict block - the agent pastes this verbatim.
    Write-Host ''
    Write-Host ('==== {0} verdict: {1} ====' -f $GATE, $R.Name) -ForegroundColor Cyan
    Write-Host ('file:     {0}' -f $R.File)
    Write-Host ('sha256:   {0}' -f $R.Sha256)
    Write-Host ('gate:     {0} {1}, ran {2}, {3}s' -f $GATE, $GATE_VERSION, $R.RanAt, $R.Seconds)
    $vc = if ($R.Verdict -eq 'pass') { 'Green' } else { 'Red' }
    Write-Host ('verdict:  {0}   ({1} block(s), {2} report(s), {3} arm(s) skipped)' -f $R.Verdict.ToUpperInvariant(), @($R.Blocks).Count, @($R.Reports).Count, @($R.Skipped).Count) -ForegroundColor $vc
    if (@($R.Blocks).Count -eq 0) { Write-Host 'blocks:   none' -ForegroundColor Green }
    else {
        Write-Host 'blocks:' -ForegroundColor Red
        foreach ($b in $R.Blocks) { Write-Host ('  X {0} | {1} | {2} | {3}' -f $b.arm, $(if ($b.path) { $b.path } else { '-' }), $(if ($b.grid) { $b.grid } else { '-' }), $b.text) -ForegroundColor Red }
    }
    if (@($R.Reports).Count -eq 0) { Write-Host 'reports:  none' }
    else {
        Write-Host ('reports:  {0} - not blocking here; each travels with its anchor to the 3c band' -f @($R.Reports).Count) -ForegroundColor Yellow
        $shown = 0
        #  $rp, never $r: PowerShell variables are case-insensitive, so a loop
        #  variable named $r would overwrite the $R this function was handed.
        foreach ($rp in $R.Reports) {
            $shown++
            if ($shown -gt 15) { Write-Host ('  ... and {0} more in {1}' -f (@($R.Reports).Count - 15), $(if ($R.GateJson) { Split-Path $R.GateJson -Leaf } else { 'gate.json' })) -ForegroundColor DarkGray; break }
            Write-Host ('  ! {0} | {1} | {2} | {3}' -f $rp.arm, $(if ($rp.path) { $rp.path } else { '-' }), $(if ($rp.grid) { $rp.grid } else { '-' }), $rp.text) -ForegroundColor Yellow
        }
    }
    if (@($R.Skipped).Count -gt 0) { Write-Host ('skipped:  {0}' -f (($R.Skipped | ForEach-Object { $_.arm }) -join ', ')) -ForegroundColor DarkGray }
    Write-Host ('gate.json: {0}' -f $(if ($R.GateJson) { $R.GateJson } else { 'NOT WRITTEN' })) -ForegroundColor DarkGray
    Write-Host ('==== end verdict: {0} ====' -f $(if ($R.Verdict -eq 'pass') { 'exit 0' } else { 'exit 1 - fix and re-run; a hit you believe is a coincidence stays in place and is named in openQuestions' })) -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Self-test: planted defects, each verified to have landed before the run
# ---------------------------------------------------------------------------

function Invoke-SelfTest {
    param($Ctx, [string] $RefFile)

    $cases = New-Object System.Collections.Generic.List[object]
    function Record {
        param([string] $Name, [bool] $Ok, [string] $Detail)
        $cases.Add([pscustomobject]@{ name = $Name; ok = $Ok; detail = $Detail })
        if (-not $Quiet) {
            if ($Ok) { Write-Host ('  PASS  {0}: {1}' -f $Name, $Detail) -ForegroundColor Green }
            else     { Write-Host ('  FAIL  {0}: {1}' -f $Name, $Detail) -ForegroundColor Red }
        }
    }
    function Blocks-On { param($R, [string] $Arm) return @($R.Blocks | Where-Object { $_.arm -eq $Arm }) }

    if (-not $RefFile) {
        $t0 = @(AsArr $Ctx['Contract'].topics)[0]
        $pc0 = [string](@(AsArr $t0.pcs)[0])
        $RefFile = Join-Path $Ctx['BuildDir'] ('spine\t{0}_{1}.json' -f [int]$t0.n, $pc0)
    }
    if (-not (Test-Path -LiteralPath $RefFile)) { throw ('{0}: -SelfTest reference file not found: {1}' -f $GATE, $RefFile) }
    $RefFile = (Resolve-Path -LiteralPath $RefFile).Path
    $refName = Split-Path $RefFile -Leaf
    $refIdent = Get-SpineFileIdentity -Name $refName
    if ($null -eq $refIdent -or $refIdent.Kind -ne 'sub') { throw ('{0}: -SelfTest needs a SUB-SECTION file (t{{T}}_{{PC}}.json); got {1}' -f $GATE, $refName) }
    $grids = @(Get-RegisterGrids -Register $Ctx['Register'] -Pc $refIdent.Pc)
    if ($grids.Count -eq 0) { throw ('{0}: -SelfTest needs a reference sub-section the register assigns at least one grid to; {1} has none' -f $GATE, $refIdent.Pc) }

    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('subsection_selftest_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $tmpSpine = Join-Path $tmp 'spine'
    New-Item -ItemType Directory -Force -Path $tmpSpine | Out-Null
    if (-not $Quiet) {
        Write-Host ''
        Write-Host ('{0} SELF-TEST on temp copies of {1} (sub-section {2})' -f $GATE, $refName, $refIdent.Pc) -ForegroundColor Cyan
        Write-Host ('  temp: {0}' -f $tmp) -ForegroundColor DarkGray
        Write-Host ('  own grids: {0}' -f (($grids | ForEach-Object { '{0} [{1}, allowance {2}, {3} item(s)]' -f $_.Ref, $_.Kind, $_.Allowance, $_.ItemCount }) -join '; ')) -ForegroundColor DarkGray
    }

    try {
        $cleanPath = Join-Path $tmpSpine $refName
        Copy-Item -LiteralPath $RefFile -Destination $cleanPath -Force

        # 1. the clean copy passes, in-process and as a child with the exit code
        $r = Invoke-SubSectionTest -FilePath $cleanPath -Ctx $Ctx -OutPath (Join-Path $tmp 'clean.gate.json') -Silent
        Record 'clean copy passes' ($r.Verdict -eq 'pass') ('verdict {0}; {1} block(s), {2} report(s), {3} skipped; {4}s' -f $r.Verdict, @($r.Blocks).Count, @($r.Reports).Count, @($r.Skipped).Count, $r.Seconds)
        if ($r.Verdict -ne 'pass') { foreach ($b in $r.Blocks) { if (-not $Quiet) { Write-Host ('        X {0} | {1} | {2}' -f $b.arm, $b.path, $b.text) -ForegroundColor Red } } }
        $global:LASTEXITCODE = -1
        & $script:Self -File $cleanPath -BuildDir $Ctx['BuildDir'] -Quiet | Out-Null
        $code = $global:LASTEXITCODE
        $beside = $cleanPath + '.gate.json'
        Record 'child exit code and gate.json beside the file' (($code -eq 0) -and (Test-Path -LiteralPath $beside)) ('exit {0}; {1}' -f $code, $(if (Test-Path -LiteralPath $beside) { 'wrote ' + (Split-Path $beside -Leaf) } else { 'gate.json NOT written beside the file' }))

        # 2. the hash is the file's hash; one altered byte breaks it
        if (Test-Path -LiteralPath $beside) {
            $gj = Get-GateJson -Path $beside
            $fh = (Get-FileHash -LiteralPath $cleanPath -Algorithm SHA256).Hash
            $same = ([string]$gj.sha256).ToUpperInvariant() -eq $fh.ToUpperInvariant()
            $altered = Join-Path $tmp ('altered_' + $refName)
            $ab = [System.IO.File]::ReadAllBytes($cleanPath)
            $ab2 = New-Object byte[] ($ab.Length + 1)
            [Array]::Copy($ab, $ab2, $ab.Length)
            $ab2[$ab.Length] = 10
            [System.IO.File]::WriteAllBytes($altered, $ab2)
            $fh2 = (Get-FileHash -LiteralPath $altered -Algorithm SHA256).Hash
            $differs = ([string]$gj.sha256).ToUpperInvariant() -ne $fh2.ToUpperInvariant()
            Record 'sha256 is Get-FileHash of the file; one byte later it is not' ($same -and $differs) ('gate.json {0} == Get-FileHash {1}; after one added byte {2} (mismatch: {3})' -f ([string]$gj.sha256).Substring(0, 12).ToLower(), $fh.Substring(0, 12).ToLower(), $fh2.Substring(0, 12).ToLower(), $differs)
        }
        else { Record 'sha256 is Get-FileHash of the file; one byte later it is not' $false 'no gate.json to compare' }

        # 3. synthetic own-grid mirror plant: every item of the largest labelled
        #    grid worked under the task's own headings
        $pick = @($grids | Where-Object { $_.Kind -ne 'numbered' -and $_.Items.Count -ge 3 -and $_.HeadersN.Count -ge 2 } | Sort-Object { $_.Items.Count } -Descending)
        if ($pick.Count -eq 0) { $pick = @($grids | Where-Object { $_.Items.Count -ge 1 -and $_.HeadersN.Count -ge 2 } | Sort-Object { $_.Items.Count } -Descending) }
        if ($pick.Count -eq 0) { Record 'mirror plant (synthetic)' $false 'no own grid with headers and items to plant from' }
        else {
            $gp = $pick[0]
            $j = Get-GateJson -Path $cleanPath
            $rows = New-Object System.Collections.Generic.List[object]
            foreach ($it in $gp.Items) {
                $row = New-Object System.Collections.Generic.List[string]
                $row.Add([string]$it)
                for ($ci = 1; $ci -lt $gp.Headers.Count; $ci++) { $row.Add(('worked answer for {0} under {1}' -f $it, $gp.Headers[$ci])) }
                $rows.Add($row.ToArray())
            }
            $table = [pscustomobject]@{ headers = @($gp.Headers); rows = $rows.ToArray() }
            if (-not (Has-Prop $j 'practicalActivity') -or $null -eq $j.practicalActivity) { Set-Prop $j 'practicalActivity' ([pscustomobject]@{}) }
            Set-Prop $j.practicalActivity 'workedExampleTable' $table
            $plantDir = Join-Path $tmp 'plant_mirror'
            New-Item -ItemType Directory -Force -Path $plantDir | Out-Null
            $plantPath = Join-Path $plantDir $refName
            [System.IO.File]::WriteAllText($plantPath, ($j | ConvertTo-Json -Depth 100), (New-Object System.Text.UTF8Encoding $false))
            $pj = Get-GateJson -Path $plantPath
            $pt = @(Get-GateSpineTables -Node $pj -File $refName -Path '' -Slot '' | Where-Object { $_.Path -eq 'practicalActivity.workedExampleTable' })
            $rel = @(Find-RelocationRows -Json $pj -FileName $refName -Grids @($gp) -BlankTokens $Ctx['Blanks'] -WithheldRx $Ctx['WithheldRx'] -MirrorAllow @{})
            $landedRows = 0; if ($rel.Count) { $landedRows = $rel[0].FilledRows.Count }
            if ($pt.Count -eq 0 -or $landedRows -lt $gp.Items.Count) { Record 'mirror plant (synthetic)' $false ('the plant did not land: walker sees {0} table(s) at the path, {1} filled item row(s)' -f $pt.Count, $landedRows) }
            else {
                $r = Invoke-SubSectionTest -FilePath $plantPath -Ctx $Ctx -OutPath (Join-Path $tmp 'plant_mirror.gate.json') -Silent
                $mo = @(Blocks-On $r 'mirror-own' | Where-Object { $_.grid -eq $gp.Id -or $_.grid -like ('*' + $gp.Ref) })
                $rl = @(Blocks-On $r 'relocation' | Where-Object { $_.grid -eq $gp.Id })
                $expectMirror = ($gp.Items.Count -ge 3)
                $ok = ($r.Verdict -eq 'fail') -and ($rl.Count -ge 1) -and ((-not $expectMirror) -or ($mo.Count -ge 1))
                Record 'mirror plant (synthetic)' $ok ('{0} item row(s) of {1} planted at practicalActivity.workedExampleTable, verified by Get-GateSpineTables; verdict {2}; mirror-own named it: {3}; relocation named it: {4}' -f $landedRows, $gp.Ref, $r.Verdict, ($mo.Count -ge 1), ($rl.Count -ge 1))
            }
        }

        # 4. a real planted file, when one is supplied
        if ($PlantFile) {
            if (-not (Test-Path -LiteralPath $PlantFile)) { Record 'mirror plant (real file)' $false ('not found: {0}' -f $PlantFile) }
            else {
                $plName = Split-Path $PlantFile -Leaf
                $plIdent = Get-SpineFileIdentity -Name $plName
                $plGrids = @()
                if ($null -ne $plIdent -and $plIdent.Kind -eq 'sub') { $plGrids = @(Get-RegisterGrids -Register $Ctx['Register'] -Pc $plIdent.Pc) }
                if ($plGrids.Count -eq 0) { Record 'mirror plant (real file)' $false ('{0} is not a sub-section the register knows' -f $plName) }
                else {
                    $plDir = Join-Path $tmp 'plant_real'
                    New-Item -ItemType Directory -Force -Path $plDir | Out-Null
                    $plPath = Join-Path $plDir $plName
                    Copy-Item -LiteralPath $PlantFile -Destination $plPath -Force
                    $pj = Get-GateJson -Path $plPath
                    $ptables = @(Get-GateSpineTables -Node $pj -File $plName -Path '' -Slot '')
                    $rel = @(Find-RelocationRows -Json $pj -FileName $plName -Grids $plGrids -BlankTokens $Ctx['Blanks'] -WithheldRx $Ctx['WithheldRx'] -MirrorAllow $Ctx['MirrorAllow'])
                    $over = @($rel | Where-Object { $_.FilledRows.Count -gt $_.Grid.Allowance })
                    if ($ptables.Count -eq 0 -or $over.Count -eq 0) { Record 'mirror plant (real file)' $false ('the plant is not present: {0} table(s), no own grid worked beyond its allowance' -f $ptables.Count) }
                    else {
                        $r = Invoke-SubSectionTest -FilePath $plPath -Ctx $Ctx -OutPath (Join-Path $tmp 'plant_real.gate.json') -Silent
                        $named = @(Blocks-On $r 'mirror-own' | ForEach-Object { $_.grid } | Sort-Object -Unique)
                        $expected = @($over | ForEach-Object { $_.Grid.Ref })
                        $hitAll = $true
                        foreach ($e in $expected) { if (-not @($named | Where-Object { $_ -like ('*' + $e) }).Count) { $hitAll = $false } }
                        Record 'mirror plant (real file)' (($r.Verdict -eq 'fail') -and $hitAll -and $named.Count -ge 1) ('{0}: walker sees {1} table(s); register says worked beyond allowance on {2}; verdict {3}; mirror-own named [{4}]' -f $plName, $ptables.Count, ($expected -join ', '), $r.Verdict, ($named -join '; '))
                    }
                }
            }
        }
        else { Record 'mirror plant (real file)' $true 'no -PlantFile supplied - the synthetic plant above stands in' }

        # 5. relocation plant: ONE assessed row filled under the task's own headings
        $pick = @($grids | Where-Object { $_.Kind -ne 'numbered' -and $_.Items.Count -ge 1 -and $_.HeadersN.Count -ge 2 } | Sort-Object { $_.Allowance }, { -($_.Items.Count) })
        if ($pick.Count -eq 0) { Record 'relocation plant' $false 'no labelled own grid to plant from' }
        else {
            $gp = $pick[0]
            $nRows = $gp.Allowance + 1
            $j = Get-GateJson -Path $cleanPath
            $rows = New-Object System.Collections.Generic.List[object]
            for ($k = 0; $k -lt [math]::Min($nRows, $gp.Items.Count); $k++) {
                $row = New-Object System.Collections.Generic.List[string]
                $row.Add([string]$gp.Items[$k])
                for ($ci = 1; $ci -lt $gp.Headers.Count; $ci++) { $row.Add(('a worked answer for {0}' -f $gp.Items[$k])) }
                $rows.Add($row.ToArray())
            }
            $table = [pscustomobject]@{ headers = @($gp.Headers); rows = $rows.ToArray() }
            if (-not (Has-Prop $j 'workedExample') -or $null -eq $j.workedExample) { Set-Prop $j 'workedExample' ([pscustomobject]@{}) }
            Set-Prop $j.workedExample 'table' $table
            $plantDir = Join-Path $tmp 'plant_reloc'
            New-Item -ItemType Directory -Force -Path $plantDir | Out-Null
            $plantPath = Join-Path $plantDir $refName
            [System.IO.File]::WriteAllText($plantPath, ($j | ConvertTo-Json -Depth 100), (New-Object System.Text.UTF8Encoding $false))
            $pj = Get-GateJson -Path $plantPath
            $pt = @(Get-GateSpineTables -Node $pj -File $refName -Path '' -Slot '' | Where-Object { $_.Path -eq 'workedExample.table' })
            $rel = @(Find-RelocationRows -Json $pj -FileName $refName -Grids @($gp) -BlankTokens $Ctx['Blanks'] -WithheldRx $Ctx['WithheldRx'] -MirrorAllow @{})
            $landedRows = 0; if ($rel.Count) { $landedRows = $rel[0].FilledRows.Count }
            if ($pt.Count -eq 0 -or $landedRows -lt $rows.Count) { Record 'relocation plant' $false ('the plant did not land: walker sees {0} table(s) at workedExample.table, {1} filled item row(s)' -f $pt.Count, $landedRows) }
            else {
                $r = Invoke-SubSectionTest -FilePath $plantPath -Ctx $Ctx -OutPath (Join-Path $tmp 'plant_reloc.gate.json') -Silent
                $rowLabel = [string]$gp.Items[0]
                $rl = @(Blocks-On $r 'relocation' | Where-Object { $_.grid -eq $gp.Id -and $_.text -like ('*''' + $rowLabel + '''*') })
                Record 'relocation plant' (($r.Verdict -eq 'fail') -and ($rl.Count -ge 1)) ('{0} assessed row(s) of {1} (allowance {2}) planted at workedExample.table under its own headings; verdict {3}; relocation named row ''{4}'': {5}' -f $rows.Count, $gp.Ref, $gp.Allowance, $r.Verdict, $rowLabel, ($rl.Count -ge 1))
            }
        }

        # 6. floor plant: underpinning knowledge cut to 200 words
        $j = Get-GateJson -Path $cleanPath
        $words = @(((AsArr $j.underpinningKnowledge) -join ' ') -split '\s+' | Where-Object { $_ })
        $j.underpinningKnowledge = @(($words | Select-Object -First 200) -join ' ')
        $plantDir = Join-Path $tmp 'plant_floor'
        New-Item -ItemType Directory -Force -Path $plantDir | Out-Null
        $plantPath = Join-Path $plantDir $refName
        [System.IO.File]::WriteAllText($plantPath, ($j | ConvertTo-Json -Depth 100), (New-Object System.Text.UTF8Encoding $false))
        $landed = @(((AsArr (Get-GateJson -Path $plantPath).underpinningKnowledge) -join ' ') -split '\s+' | Where-Object { $_ }).Count
        if ($landed -gt 200) { Record 'floor plant' $false ('the plant did not land: still {0} words' -f $landed) }
        else {
            $r = Invoke-SubSectionTest -FilePath $plantPath -Ctx $Ctx -OutPath (Join-Path $tmp 'plant_floor.gate.json') -Silent
            $fl = @(Blocks-On $r 'spine' | Where-Object { $_.text -match '(?i)underpinning knowledge is \d+ words, floor is \d+' })
            Record 'floor plant' (($r.Verdict -eq 'fail') -and ($fl.Count -ge 1)) ('cut to {0} words; verdict {1}; {2}' -f $landed, $r.Verdict, $(if ($fl.Count) { $fl[0].text } else { 'the floor was NOT named' }))
        }

        # 7. a gate that is unreachable is a block named "gate unavailable"
        $ctx2 = [ordered]@{}
        foreach ($k in $Ctx.Keys) { $ctx2[$k] = $Ctx[$k] }
        $ctx2['MirrorScript'] = Join-Path $tmp 'missing-mirror.ps1'
        $r = Invoke-SubSectionTest -FilePath $cleanPath -Ctx $ctx2 -OutPath (Join-Path $tmp 'unavailable.gate.json') -Silent
        $ua = @(Blocks-On $r 'mirror-own' | Where-Object { $_.match -eq 'gate unavailable' })
        Record 'gate unavailable blocks' (($r.Verdict -eq 'fail') -and ($ua.Count -ge 1)) ('mirror gate pointed at a missing path; verdict {0}; {1}' -f $r.Verdict, $(if ($ua.Count) { $ua[0].text } else { 'no "gate unavailable" block' }))
    }
    finally {
        if ($tmp -and (Test-Path -LiteralPath $tmp) -and $tmp.Length -gt 12) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    $bad = @($cases.ToArray() | Where-Object { -not $_.ok })
    if (-not $Quiet) {
        Write-Host ''
        if ($bad.Count -eq 0) { Write-Host ('  self-test: {0} of {0} cases passed. This gate can fail.' -f $cases.Count) -ForegroundColor Green }
        else { Write-Host ('  X self-test: {0} of {1} cases FAILED. Do not trust a green from this gate until they pass.' -f $bad.Count, $cases.Count) -ForegroundColor Red }
    }
    return [pscustomobject]@{ Cases = $cases.ToArray(); Failed = $bad.Count }
}

# ---------------------------------------------------------------------------
# Entry
# ---------------------------------------------------------------------------

$exitCode = 0
try {
    if (-not $File -and -not $All -and -not $SelfTest) { throw ('{0}: pass -File <spine\tT_P.json> (the contract), -All -BuildDir <build>, or -SelfTest -BuildDir <build>.' -f $GATE) }
    if ($File -and -not (Test-Path -LiteralPath $File)) { throw ('{0}: file not found: {1}' -f $GATE, $File) }
    if (-not $BuildDir) {
        if ($File) { $BuildDir = Split-Path -Parent (Split-Path -Parent ((Resolve-Path -LiteralPath $File).Path)) }
        else { throw ('{0}: -All and -SelfTest need -BuildDir.' -f $GATE) }
    }
    $ctx = New-RunContext -BuildDir $BuildDir

    if ($SelfTest) {
        $st = Invoke-SelfTest -Ctx $ctx -RefFile $File
        if ($ResultPath) {
            Write-JsonFile -Path $ResultPath -Body ([pscustomobject]([ordered]@{ mode = 'selftest'; gateVersion = ('{0} {1}' -f $GATE, $GATE_VERSION); ranAt = (Get-Date).ToString('o'); verdict = $(if ($st.Failed -eq 0) { 'pass' } else { 'fail' }); cases = $st.Cases }))
        }
        $exitCode = if ($st.Failed -eq 0) { 0 } else { 4 }
    }
    elseif ($All) {
        $rows = New-Object System.Collections.Generic.List[object]
        $failed = 0
        if (-not $Quiet) {
            Write-Host ''
            Write-Host ('{0} - every sub-section the contract names, from {1}' -f $GATE.ToUpperInvariant(), $ctx['ContractPath']) -ForegroundColor Cyan
            Write-Host ('  {0,-14} {1,-7} {2,7} {3,8} {4,8} {5,7}  {6}' -f 'file', 'verdict', 'blocks', 'reports', 'skipped', 'secs', 'blocking arms') -ForegroundColor DarkGray
        }
        foreach ($t in (AsArr $ctx['Contract'].topics)) {
            foreach ($pc in (AsArr $t.pcs)) {
                $fname = 't{0}_{1}.json' -f [int]$t.n, [string]$pc
                $fpath = Join-Path $ctx['BuildDir'] ('spine\' + $fname)
                if (-not (Test-Path -LiteralPath $fpath)) {
                    $failed++
                    $rows.Add([pscustomobject]@{ file = $fname; verdict = 'MISSING'; blocks = 0; reports = 0; skipped = 0; seconds = 0; arms = 'the contract names it; it is not on disk' })
                    if (-not $Quiet) { Write-Host ('  {0,-14} {1,-7} {2,7} {3,8} {4,8} {5,7}  {6}' -f $fname, 'MISSING', '-', '-', '-', '-', 'named by the contract, not on disk') -ForegroundColor Red }
                    continue
                }
                $op = ''
                if ($ResultDir) { $op = Join-Path $ResultDir ($fname + '.gate.json') }
                $r = Invoke-SubSectionTest -FilePath $fpath -Ctx $ctx -OutPath $op -Silent
                if ($r.Verdict -ne 'pass') { $failed++ }
                $barms = @($r.Blocks | ForEach-Object { $_.arm } | Sort-Object -Unique) -join ', '
                $rows.Add([pscustomobject]@{ file = $fname; verdict = $r.Verdict; blocks = @($r.Blocks).Count; reports = @($r.Reports).Count; skipped = @($r.Skipped).Count; seconds = $r.Seconds; arms = $barms })
                if (-not $Quiet) {
                    $col = if ($r.Verdict -eq 'pass') { 'Green' } else { 'Red' }
                    Write-Host ('  {0,-14} {1,-7} {2,7} {3,8} {4,8} {5,7}  {6}' -f $fname, $r.Verdict.ToUpperInvariant(), @($r.Blocks).Count, @($r.Reports).Count, @($r.Skipped).Count, $r.Seconds, $barms) -ForegroundColor $col
                    foreach ($b in $r.Blocks) { Write-Host ('      X {0} | {1} | {2} | {3}' -f $b.arm, $(if ($b.path) { $b.path } else { '-' }), $(if ($b.grid) { $b.grid } else { '-' }), $b.text) -ForegroundColor Red }
                }
            }
        }
        if (-not $Quiet) {
            Write-Host ''
            if ($failed -eq 0) { Write-Host ('  {0} file(s), every one exit 0' -f $rows.Count) -ForegroundColor Green }
            else { Write-Host ('  {0} of {1} file(s) FAIL' -f $failed, $rows.Count) -ForegroundColor Red }
        }
        if ($ResultPath) { Write-JsonFile -Path $ResultPath -Body ([pscustomobject]([ordered]@{ mode = 'all'; gateVersion = ('{0} {1}' -f $GATE, $GATE_VERSION); ranAt = (Get-Date).ToString('o'); buildDir = $ctx['BuildDir']; verdict = $(if ($failed -eq 0) { 'pass' } else { 'fail' }); files = $rows.ToArray() })) }
        $exitCode = if ($failed -eq 0) { 0 } else { 1 }
    }
    else {
        $r = Invoke-SubSectionTest -FilePath $File -Ctx $ctx -OutPath $ResultPath
        $exitCode = if ($r.Verdict -eq 'pass') { 0 } else { 1 }
    }
}
catch {
    Write-Host ('  X {0}: {1}' -f $GATE, $_.Exception.Message) -ForegroundColor Red
    if ($_.ScriptStackTrace -and $ShowGateOutput) { Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray }
    $exitCode = 2
}
exit $exitCode
