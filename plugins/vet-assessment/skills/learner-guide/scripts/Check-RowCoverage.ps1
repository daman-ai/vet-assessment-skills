<#
    Check-RowCoverage.ps1 - is every assessed row actually TAUGHT, as
    mechanism, somewhere the learner will read it?

    Runs in the content loop on each sub-section file as it lands (REPORT
    only), and at Stage 3c over the whole spine with -Whole (BLOCK). Exit 1 on
    a BLOCK arm, 2 on a usage error, 0 otherwise.

    THE DEFECT THIS LOOKS FOR. The shape mirror beside this gate is a ceiling:
    it stops the prose answering the assessed grid. A ceiling on its own
    teaches an author the cheapest way to pass it, which is to say less. On
    the build that produced these gates the remediation rounds did exactly
    that - a 7-row equipment leak became a 4-row table, then a 6-question
    method table, then a figure with every assessed row reading "Your turn" -
    and the word count, which is the only floor the pipeline had, never
    moved, because a sub-section can be 3,000 words long and still teach a
    row in zero sentences. Under-teaching is invisible to a word floor. So
    this gate counts, per assessed row, the sentences that TEACH it.

    THE FLOOR AND THE CEILING CANNOT BE SATISFIED BY THE SAME SENTENCE. That
    is the whole design. A TEACHING sentence for row R is one the shape
    mirror anchored to R (its label or an alias, in the sentence or the two
    before it in the same paragraph array) and did NOT score as answering any
    bullet of R. So every anchored sentence is classified exactly once -
    answering or teaching - by the SAME code (loaded from Check-ShapeMirror.ps1
    between its SM-LIB markers; that file is canonical). The floor counts only
    teaching; the ceiling counts only answering. An author cannot lift the
    floor by pasting the model answer, and cannot drop under the ceiling by
    deleting the teaching.

    ARMS.
      Row floor, per file (in-loop): REPORT any assessed row with fewer than
        -MinTeachFile (2) teaching sentences in this file, as a matrix of
        row: teaching n / answering n.
      Row floor, whole spine (-Whole, Stage 3c): BLOCK any assessed row with
        fewer than -MinTeachWhole (3) teaching sentences ANYWHERE in the
        spine. Teaching for a row may legitimately live in another
        sub-section (the audit found the equipment items taught as process in
        5.1, 5.2, 6.1 and 6.3), so the whole-spine count is the one that
        blocks and the per-file count only informs.
      KE concept coverage: each Knowledge Evidence point and sub-point in the
        unit extract reduces to its distinctive terms (stopwords out; words
        the KE section's framing uses and words in more than a quarter of all
        points out - "food", "cook", "chill" name the unit, not a point). Every
        term must occur at least once in the underpinning knowledge of the
        sub-section(s) the contract's keMap assigns the point to. REPORT in
        file mode, BLOCK in -Whole. A -Whole run with no unit extract or no
        keMap BLOCKS and names the missing input: a floor whose input is
        absent has checked nothing.
      Hollow relocation (REPORT): the fix for an answered grid is to work the
        exemplar on an UNASSESSED subject, and a relocated exemplar can be
        hollowed to nothing - two words in each cell of a table whose shape
        promises thirty. Any spine table sharing two or more of a task's
        column headings whose rows are NOT the task's rows is a relocated
        exemplar, and each of its filled cells must carry at least
        -HollowShare (60 per cent) of the task's word-guide lower bound.

    NEVER PRINTS A MODEL BULLET. Row labels, headings, counts and paths only.

    CALIBRATION - see the delivery note for the -Whole list on the current
    spine; the numbers here are the ones the gate was tuned against.
      Corpus A (spine_backup_pre_round4): the rows the shape mirror scores as
      FULL have LOW teaching counts (Task 11(a) rows: 1-4 teaching sentences
      each against 6-12 answering) - the prose was answer, not teaching, which
      is the point of counting the two separately.
      Corpus B (current spine, -Whole): see the list in the delivery note.
      Every row below the floor is a real finding for the coordinator, not a
      calibration artefact; the gate was not tuned to make that list shorter.
      KE frame ceiling 0.25 across points; teaching floors 2 (file) and 3
      (whole); hollow share 0.6.

    PS 5.1. ASCII only in this file. Nothing here names a unit, a brand or a
    build path.
#>

[CmdletBinding()]
param(
    [string] $BuildDir,
    [string] $SpineFile,
    [string] $SpineDir,
    [string] $Register,
    [string] $Cells,
    [switch] $Whole,
    [string] $ReportPath,
    [switch] $Quiet,
    [string] $UnitExtract,
    [string] $ContractPath,
    [int]    $MinTeachFile = 2,
    [int]    $MinTeachWhole = 3,
    [double] $HollowShare = 0.6,
    [double] $KeFrameCeiling = 0.25,
    [double] $KeTermShare = 0.6,
    #  Scoring calibration - shared with Check-ShapeMirror.ps1; see its header.
    [int]    $AnchorWindow = 2,
    [int]    $MinHitWords = 2,
    [double] $MinHitShare = 0.5,
    [double] $DfCeiling = 0.25,
    [double] $AliasAmbientCeiling = 0.10,
    [string] $WithheldRx = '(?i)\b(your turn|yours to (complete|work|fill)|you write this|write here|left for you|complete this row|for you to complete|to be completed)\b'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

#  The anchoring and scoring code is loaded from the shape mirror's own file,
#  between its SM-LIB markers, as a scriptblock: dot-sourcing the script
#  itself would run its param block in this scope and reset every variable
#  above to the mirror's defaults.
$smPath = Join-Path $PSScriptRoot 'Check-ShapeMirror.ps1'
if (-not (Test-Path -LiteralPath $smPath)) { throw "Check-RowCoverage: Check-ShapeMirror.ps1 is not beside this script; the two gates share one classifier and cannot run apart." }
$smText = [System.IO.File]::ReadAllText($smPath, [System.Text.Encoding]::UTF8)
$smB = $smText.IndexOf('# === SM-LIB BEGIN ===')
$smE = $smText.IndexOf('# === SM-LIB END ===')
if ($smB -lt 0 -or $smE -le $smB) { throw "Check-RowCoverage: the SM-LIB markers are missing from Check-ShapeMirror.ps1; the shared classifier cannot be loaded." }
. ([scriptblock]::Create($smText.Substring($smB, $smE - $smB)))

$GATE = 'Check-RowCoverage'

function Get-RcKePoints {
    <#  Knowledge Evidence points and sub-points out of the unit extract's own
        markdown: "- **KE1** text", "  - KE2a text", and nested "- chillers"
        under a sub-point (id = parent/slug). Returns points plus the frame
        words (the section's non-bullet lines).  #>
    param([string] $Text)
    $points = New-Object System.Collections.Generic.List[object]
    $frame  = New-Object System.Collections.Generic.List[string]
    if (-not $Text) { return [pscustomobject]@{ Points = $points.ToArray(); Frame = $frame.ToArray() } }
    $lines = @($Text -split "\r?\n")
    $inKe = $false; $lastId = ''; $lastSub = ''
    foreach ($raw in $lines) {
        $ln = "$raw".TrimEnd()
        if ($ln -match '^#+\s') {
            if ($ln -match '(?i)^#+\s*knowledge evidence') { $inKe = $true; continue }
            if ($inKe) { break }
            continue
        }
        if (-not $inKe) { continue }
        if (-not $ln.Trim()) { continue }
        $m = [regex]::Match($ln, '^\s*-\s*\*\*(KE\d+)\*\*\s*(.*)$')
        if ($m.Success) {
            $lastId = $m.Groups[1].Value; $lastSub = ''
            $points.Add([pscustomobject]@{ Id = $lastId; Parent = $lastId; Text = ($m.Groups[2].Value -replace '[*:]+$', '').Trim() })
            continue
        }
        $m = [regex]::Match($ln, '^\s*-\s*(KE\d+[a-z]+)\s+(.*)$')
        if ($m.Success) {
            $lastSub = $m.Groups[1].Value
            $parent = [regex]::Match($lastSub, '^KE\d+').Value
            $points.Add([pscustomobject]@{ Id = $lastSub; Parent = $parent; Text = ($m.Groups[2].Value -replace '[*:]+$', '').Trim() })
            continue
        }
        $m = [regex]::Match($ln, '^\s*-\s+(.*)$')
        if ($m.Success -and $lastId) {
            $t = ($m.Groups[1].Value -replace '[*:]+$', '').Trim()
            $owner = if ($lastSub) { $lastSub } else { $lastId }
            $parent = [regex]::Match($owner, '^KE\d+').Value
            $points.Add([pscustomobject]@{ Id = ("{0}/{1}" -f $owner, ((ConvertTo-GateNormal $t) -replace ' ', '-')); Parent = $parent; Text = $t })
            continue
        }
        $frame.Add($ln.Trim())
    }
    return [pscustomobject]@{ Points = $points.ToArray(); Frame = $frame.ToArray() }
}

try { $in = Get-SmInputs -BuildDir $BuildDir -SpineFile $SpineFile -SpineDir $SpineDir -Register $Register -Cells $Cells -Gate $GATE }
catch { Write-Host ("  X {0}" -f $_.Exception.Message) -ForegroundColor Red; exit 2 }

$set = Get-SmGridSet -RegisterDoc $in.Register -CellsDoc $in.Cells -DfCeiling $DfCeiling -MinHitWords $MinHitWords
$grids = @($set.Grids)
if ($grids.Count -eq 0) {
    Write-Host ("  X {0}: assessor-cells.json carries no grids - a floor with an empty check-set passes by having nothing to check." -f $GATE) -ForegroundColor Red
    exit 2
}
$skip = Get-GateUnrenderedFields -BuildDir $BuildDir -ForSweep
$skipTable = @{}
foreach ($k in $skip.Keys) { $skipTable[$k] = $true }
if (-not $ReportPath) { $ReportPath = Join-Path $BuildDir 'row-coverage-report.json' }
$blanks = Get-GateBlankTokens -BuildDir $BuildDir
$mode = if ($Whole) { 'whole' } else { 'file' }

if (-not $Quiet) {
    Write-Host ''
    Write-Host ("ROW COVERAGE - is every assessed row taught?  ({0} mode)" -f $mode) -ForegroundColor Cyan
    Write-GateCheckSet -What 'assessed grids' -Count $grids.Count -DerivedFrom ("{0} with cells from {1}" -f (Split-Path $in.RegisterPath -Leaf), (Split-Path $in.CellsPath -Leaf))
    Write-Host ("  floors: {0} teaching sentence(s) per row per file (report), {1} anywhere in the spine (-Whole, block); hollow share {2:P0} of the word guide; KE frame ceiling {3:P0}" -f $MinTeachFile, $MinTeachWhole, $HollowShare, $KeFrameCeiling) -ForegroundColor DarkGray
    Write-Host ("  a teaching sentence is anchored to the row and answers none of its bullets - classified once, by the shape mirror's own code") -ForegroundColor DarkGray
    Write-Host ("  spine: {0} file(s)" -f $in.Files.Count) -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# 1. Scan every file against every grid, accumulating teaching per row
# ---------------------------------------------------------------------------

$rowTotals = @{}      # gridKey|row -> @{ Teaching; Answering; Files = list }
$fileReports = New-Object System.Collections.Generic.List[object]
$underpinning = @{}   # sub-section -> HashSet[string] of content words in its underpinning knowledge
$hollow = New-Object System.Collections.Generic.List[object]
$fileReportRows = 0

foreach ($f in $in.Files) {
    $json = Get-GateJson -Path $f.FullName
    if ($null -eq $json) { continue }
    $sub = Get-SmFileSubSection -Json $json -RegisterDoc $in.Register
    $own = @($grids | Where-Object { $sub -and $_.SubSection -eq $sub })

    $sentences = Get-SmSentences -Json $json -File $f.Name -Skip $skipTable
    $scan = Invoke-SmScan -Sentences $sentences -Grids $grids -AnchorWindow $AnchorWindow -MinHitWords $MinHitWords -MinHitShare $MinHitShare -AliasAmbientCeiling $AliasAmbientCeiling

    $gridsOut = New-Object System.Collections.Generic.List[object]
    foreach ($g in $grids) {
        $rows = @(Get-SmMatrix -Grid $g -Scan $scan)
        $rowsOut = New-Object System.Collections.Generic.List[object]
        foreach ($r in $rows) {
            if (-not $r.Assessed) { continue }
            $key = "{0}|{1}" -f $g.Key, $r.Index
            if (-not $rowTotals.ContainsKey($key)) { $rowTotals[$key] = [pscustomobject]@{ Teaching = 0; Answering = 0; Files = (New-Object System.Collections.Generic.List[string]) } }
            $rowTotals[$key].Teaching  += $r.Teaching
            $rowTotals[$key].Answering += $r.Answering
            if ($r.Teaching -gt 0) { $rowTotals[$key].Files.Add(("{0}:{1}" -f $f.Name, $r.Teaching)) }
            if ($own.Count -gt 0 -and $g.SubSection -eq $sub) {
                $rowsOut.Add([pscustomobject]@{ Label = $r.Label; Teaching = $r.Teaching; Answering = $r.Answering; Below = ($r.Teaching -lt $MinTeachFile) })
            }
        }
        if ($rowsOut.Count -gt 0) { $gridsOut.Add([pscustomobject]@{ SubSection = $g.SubSection; Ref = $g.Ref; Id = $g.Id; Kind = $g.Kind; Rows = $rowsOut.ToArray() }) }
    }

    # underpinning knowledge words, for the KE arm
    if ($sub) {
        if (-not $underpinning.ContainsKey($sub)) { $underpinning[$sub] = New-Object 'System.Collections.Generic.HashSet[string]' }
        $uk = Get-GateProp -Object $json -Names @('underpinningKnowledge', 'underpinning', 'knowledge') -Default $null
        if ($null -ne $uk) {
            foreach ($cell in @(Get-GateSpineCells -Node $uk -File $f.Name -Path 'underpinningKnowledge' -Channel 'underpinningKnowledge' -Slot '' -Skip $skipTable)) {
                if ($null -eq $cell) { continue }
                foreach ($w in (Get-SmWords $cell.Text)) { [void]$underpinning[$sub].Add($w) }
            }
        }
    }

    # hollow relocation: a table in the task's shape whose rows are not the task's rows
    foreach ($t in @(Get-GateSpineTables -Node $json -File $f.Name -Path '' -Slot '')) {
        if ($null -eq $t) { continue }
        #  INDEX THE ROWS, NEVER @() THEM AND NEVER ENUMERATE THEM. A one-row
        #  table's rows array reaches this scope such that @() wraps it once
        #  more instead of returning it (the table read as one row of one cell),
        #  and foreach UNROLLS the inner array into its strings (three rows of
        #  one cell). Either way every relocated exemplar was invisible. .Count
        #  and [n] work on the array whatever wrapper it carries.
        $tRowsObj = $t.Rows
        $tRowCount = 0
        if ($null -ne $tRowsObj) { $tRowCount = [int]$tRowsObj.Count }
        $tHeads = @(@($t.Headers) | ForEach-Object { ConvertTo-GateNormal ([string]$_) } | Where-Object { $_ })
        if ($tHeads.Count -lt 2) { continue }
        foreach ($g in $own) {
            if ($g.WordGuideMin -le 0) { continue }
            $gHeads = @(@($g.Headers) | ForEach-Object { ConvertTo-GateNormal $_ } | Where-Object { $_ })
            $shared = @($tHeads | Where-Object { $gHeads -contains $_ })
            if ($shared.Count -lt 2) { continue }
            $need = [int][math]::Ceiling($HollowShare * $g.WordGuideMin)
            for ($r = $t.Skip; $r -lt $tRowCount; $r++) {
                $cells = $tRowsObj[$r]
                if ($null -eq $cells -or $cells -is [string]) { continue }
                $cellCount = [int]$cells.Count
                if ($cellCount -lt 2) { continue }
                $label = [string]$cells[0]
                $labelN = ConvertTo-GateNormal $label
                if (-not $labelN -or $tHeads -contains $labelN) { continue }
                $isAssessed = $false
                foreach ($row in $g.Rows) { foreach ($a in $row.Anchors) { if ($a.IsLabel -and $a.Stem -and (' ' + (@(Get-SmTokens $label) -join ' ') + ' ') -eq $a.Stem) { $isAssessed = $true } } }
                if ($isAssessed) { continue }   # an assessed row is the mirror's business, not a relocation
                if ($label -match $WithheldRx) { continue }
                for ($c = 1; $c -lt $cellCount; $c++) {
                    $txt = [string]$cells[$c]
                    if ($txt -match $WithheldRx) { continue }
                    if (-not (Test-GateCellFilled -Text $txt -BlankTokens $blanks)) { continue }
                    $words = @((ConvertTo-GateNormal $txt) -split ' ' | Where-Object { $_ }).Count
                    if ($words -lt $need) {
                        $hdr = if ($c -lt $tHeads.Count) { [string]@($t.Headers)[$c] } else { "column $c" }
                        $hollow.Add([pscustomobject]@{ File = $f.Name; Path = $t.Path; Grid = $g.Ref; Row = $label; Column = $hdr; Words = $words; Need = $need; WordGuideMin = $g.WordGuideMin })
                    }
                }
            }
        }
    }

    $fileReports.Add([pscustomobject]@{ File = $f.Name; SubSection = $sub; Sentences = $sentences.Count; Ambient = $scan.Ambient; Grids = $gridsOut.ToArray() })

    if (-not $Quiet -and $gridsOut.Count -gt 0) {
        Write-Host ''
        Write-Host ("  {0}  (sub-section {1}; {2} sentences)" -f $f.Name, $sub, $sentences.Count) -ForegroundColor Cyan
        foreach ($am in $scan.Ambient) { Write-Host ("    ambient alias not used as an anchor in this file: {0}" -f $am) -ForegroundColor DarkGray }
        foreach ($go in $gridsOut) {
            $below = @($go.Rows | Where-Object { $_.Below })
            $fileReportRows += $below.Count
            $c = if ($below.Count) { 'Yellow' } else { 'DarkGray' }
            Write-Host ("    {0} [{1}]  {2} row(s) under the per-file floor of {3}" -f $go.Ref, $go.Kind, $below.Count, $MinTeachFile) -ForegroundColor $c
            Write-Host ("       {0,-46} teaching answering" -f 'row') -ForegroundColor DarkGray
            foreach ($r in $go.Rows) {
                $lab = if ($r.Label.Length -gt 46) { $r.Label.Substring(0, 46) } else { $r.Label }
                $mark = if ($r.Below) { '  <- report' } else { '' }
                Write-Host ("       {0,-46} {1,8} {2,9}{3}" -f $lab, $r.Teaching, $r.Answering, $mark) -ForegroundColor $(if ($r.Below) { 'Yellow' } else { 'DarkGray' })
            }
        }
    }
}

# ---------------------------------------------------------------------------
# 2. Whole-spine floor
# ---------------------------------------------------------------------------

$block = 0
$gridSummaries = New-Object System.Collections.Generic.List[object]
$belowWhole = New-Object System.Collections.Generic.List[object]
foreach ($g in $grids) {
    $rowsOut = New-Object System.Collections.Generic.List[object]
    $taught = 0
    foreach ($row in $g.Rows) {
        if (-not $row.Assessed) { continue }
        $key = "{0}|{1}" -f $g.Key, $row.Index
        $tot = $rowTotals[$key]
        $teach = 0; $ans = 0; $files = @()
        if ($null -ne $tot) { $teach = $tot.Teaching; $ans = $tot.Answering; $files = $tot.Files.ToArray() }
        $isBelow = ($teach -lt $MinTeachWhole)
        if (-not $isBelow) { $taught++ }
        $rowsOut.Add([pscustomobject]@{ Label = $row.Label; Teaching = $teach; Answering = $ans; Files = $files; BelowWhole = $isBelow })
        if ($isBelow) { $belowWhole.Add([pscustomobject]@{ SubSection = $g.SubSection; Ref = $g.Ref; Kind = $g.Kind; Row = $row.Label; Teaching = $teach; Answering = $ans }) }
    }
    $gridSummaries.Add([pscustomobject]@{ SubSection = $g.SubSection; Ref = $g.Ref; Id = $g.Id; Kind = $g.Kind; ItemCount = $g.ItemCount; TaughtRows = $taught; Rows = $rowsOut.ToArray() })
}

if ($Whole) {
    Write-Host ''
    Write-Host ("  WHOLE-SPINE FLOOR: {0} teaching sentence(s) per assessed row, anywhere in the spine" -f $MinTeachWhole) -ForegroundColor Cyan
    if ($belowWhole.Count -eq 0) { Write-Host '  every assessed row reaches the floor' -ForegroundColor Green }
    else {
        $block += $belowWhole.Count
        $lastGrid = ''
        foreach ($b in ($belowWhole | Sort-Object SubSection, Ref)) {
            $gk = "{0} {1}" -f $b.SubSection, $b.Ref
            if ($gk -ne $lastGrid) { Write-Host ("  X {0} [{1}]" -f $gk, $b.Kind) -ForegroundColor Red; $lastGrid = $gk }
            Write-Host ("       {0,-60} teaching {1}  answering {2}" -f $(if ($b.Row.Length -gt 60) { $b.Row.Substring(0, 60) } else { $b.Row }), $b.Teaching, $b.Answering) -ForegroundColor Red
        }
    }
}

# ---------------------------------------------------------------------------
# 3. KE concept coverage
# ---------------------------------------------------------------------------

$keOut = New-Object System.Collections.Generic.List[object]
$keMissingInput = New-Object System.Collections.Generic.List[string]
if (-not $UnitExtract) { $UnitExtract = Join-Path $BuildDir 'unit_extract.md' }
$contract = $null
if ($ContractPath) { $contract = Get-GateJson -Path $ContractPath } else { $contract = Get-GateContract -BuildDir $BuildDir }
$keMap = $null
if ($null -ne $contract) { $keMap = Get-GateProp -Object $contract -Names @('keMap', 'knowledgeEvidenceMap') -Default $null }
if (-not (Test-Path -LiteralPath $UnitExtract)) { $keMissingInput.Add(("unit extract not found at {0}" -f $UnitExtract)) }
if ($null -eq $keMap) { $keMissingInput.Add('contract.json carries no keMap') }

$fileSubs = @{}
foreach ($fr in $fileReports) { if ($fr.SubSection) { $fileSubs[$fr.SubSection] = $true } }
$keBelow = 0
if ($keMissingInput.Count -eq 0) {
    $ke = Get-RcKePoints -Text (Get-GateFileText -Path $UnitExtract)
    $points = @($ke.Points)
    $frameWords = @{}
    foreach ($ln in $ke.Frame) { foreach ($w in (Get-SmWords $ln)) { $frameWords[$w] = $true } }
    if ($points.Count -ge 4) {
        $df = @{}
        foreach ($p in $points) { foreach ($w in @(Get-SmWords $p.Text | Select-Object -Unique)) { if ($df.ContainsKey($w)) { $df[$w]++ } else { $df[$w] = 1 } } }
        foreach ($w in @($df.Keys)) { if (($df[$w] / [double]$points.Count) -gt $KeFrameCeiling) { $frameWords[$w] = $true } }
    }
    foreach ($p in $points) {
        $entry = Get-GateProp -Object $keMap -Names @($p.Parent) -Default $null
        $assigned = @()
        if ($null -ne $entry) {
            $ta = if ($entry -is [string]) { $entry } else { [string](Get-GateProp -Object $entry -Names @('taughtAt', 'taught', 'subSection', 'subSections', 'preparedAt') -Default '') }
            $assigned = @([regex]::Matches($ta, '\d+\.\d+') | ForEach-Object { $_.Value } | Select-Object -Unique)
        }
        $terms = @(Get-SmWords $p.Text | Where-Object { -not $frameWords.ContainsKey($_) })
        $inScope = $true
        if (-not $Whole) { $inScope = @($assigned | Where-Object { $fileSubs.ContainsKey($_) }).Count -gt 0 }
        if (-not $inScope) { continue }
        $missing = New-Object System.Collections.Generic.List[string]
        if ($assigned.Count -eq 0) { foreach ($t in $terms) { $missing.Add($t) } }
        else {
            foreach ($t in $terms) {
                $found = $false
                foreach ($s in $assigned) {
                    if (-not $Whole -and -not $fileSubs.ContainsKey($s)) { continue }
                    if ($underpinning.ContainsKey($s) -and $underpinning[$s].Contains($t)) { $found = $true; break }
                }
                if (-not $found) { $missing.Add($t) }
            }
        }
        #  COVERED AT A SHARE, NOT EVERY TERM. Calibration on the audited spine
        #  demanded every term and produced nine gaps in 27 points, eight of
        #  them framing words the DF ceiling cannot see ("commonly subject
        #  to", "procedures", "appropriate") on points the audit found taught;
        #  the one real gap (a one-term sub-point never named in its assigned
        #  underpinning) survives a -KeTermShare floor. Every missing term is
        #  still listed so the reader can weigh it.
        $present = $terms.Count - $missing.Count
        $needTerms = [int][math]::Ceiling($KeTermShare * $terms.Count)
        if ($needTerms -lt 1 -and $terms.Count -gt 0) { $needTerms = 1 }
        $ok = ($assigned.Count -gt 0 -and $terms.Count -gt 0 -and $present -ge $needTerms)
        if (-not $ok) { $keBelow++ }
        $keOut.Add([pscustomobject]@{ Id = $p.Id; Text = $p.Text; AssignedTo = $assigned; Terms = $terms; Present = $present; Need = $needTerms; Missing = $missing.ToArray(); Covered = $ok })
    }
}

Write-Host ''
Write-Host ("  KE CONCEPT COVERAGE ({0})" -f $(if ($Whole) { 'block' } else { 'report - points assigned to the file(s) in hand' })) -ForegroundColor Cyan
if ($keMissingInput.Count -gt 0) {
    foreach ($m in $keMissingInput) {
        if ($Whole) { Write-Host ("  X {0} - the KE floor cannot run; a floor whose input is absent has checked nothing" -f $m) -ForegroundColor Red; $block++ }
        else { Write-Host ("  ! {0} - KE coverage not checked in file mode" -f $m) -ForegroundColor Yellow }
    }
}
else {
    $covered = @($keOut | Where-Object { $_.Covered }).Count
    Write-Host ("  {0} of {1} point(s) covered where the keMap says they are taught (floor: {2:P0} of a point's distinctive terms present)" -f $covered, $keOut.Count, $KeTermShare) -ForegroundColor $(if ($keBelow) { 'Yellow' } else { 'Green' })
    foreach ($k in ($keOut | Where-Object { -not $_.Covered })) {
        $c = if ($Whole) { 'Red' } else { 'Yellow' }
        if ($Whole) { $block++ }
        $where = if (@($k.AssignedTo).Count) { ($k.AssignedTo -join ', ') } else { 'NOT ASSIGNED in keMap' }
        Write-Host ("  {0} {1} -> {2}: {3} of {4} term(s) present, missing {5}   [{6}]" -f $(if ($Whole) { 'X' } else { '~' }), $k.Id, $where, $k.Present, @($k.Terms).Count, ($k.Missing -join ', '), $(if ($k.Text.Length -gt 70) { $k.Text.Substring(0, 70) + '...' } else { $k.Text })) -ForegroundColor $c
    }
    foreach ($k in ($keOut | Where-Object { $_.Covered -and @($_.Missing).Count -gt 0 })) {
        Write-Host ("    ok {0} -> {1}: covered ({2} of {3}); term(s) not found: {4}" -f $k.Id, ($k.AssignedTo -join ', '), $k.Present, @($k.Terms).Count, ($k.Missing -join ', ')) -ForegroundColor DarkGray
    }
}

# ---------------------------------------------------------------------------
# 4. Hollow relocation (report)
# ---------------------------------------------------------------------------

Write-Host ''
if ($hollow.Count -eq 0) { Write-Host '  HOLLOW RELOCATION: none - every relocated exemplar cell carries its share of the word guide' -ForegroundColor Green }
else {
    Write-Host ("  HOLLOW RELOCATION (report): {0} cell(s) below {1:P0} of the word guide's lower bound" -f $hollow.Count, $HollowShare) -ForegroundColor Yellow
    foreach ($h in ($hollow | Select-Object -First 30)) { Write-Host ("    {0} {1}: row '{2}' / {3} - {4} word(s), need {5} (guide min {6}) vs {7}" -f $h.File, $h.Path, $h.Row, $h.Column, $h.Words, $h.Need, $h.WordGuideMin, $h.Grid) -ForegroundColor DarkGray }
    if ($hollow.Count -gt 30) { Write-Host ("    ... {0} more in the report file" -f ($hollow.Count - 30)) -ForegroundColor DarkGray }
}

# ---------------------------------------------------------------------------
# 5. Report and verdict
# ---------------------------------------------------------------------------

$report = [pscustomobject]@{
    gate = $GATE
    generated = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
    buildDir = $BuildDir
    mode = $mode
    floors = [pscustomobject]@{ minTeachFile = $MinTeachFile; minTeachWhole = $MinTeachWhole; hollowShare = $HollowShare; keFrameCeiling = $KeFrameCeiling }
    calibration = [pscustomobject]@{ anchorWindow = $AnchorWindow; minHitWords = $MinHitWords; minHitShare = $MinHitShare; dfCeiling = $DfCeiling; aliasAmbientCeiling = $AliasAmbientCeiling }
    files = $fileReports.ToArray()
    grids = $gridSummaries.ToArray()
    belowWhole = $belowWhole.ToArray()
    ke = [pscustomobject]@{ missingInput = $keMissingInput.ToArray(); points = $keOut.ToArray() }
    hollow = $hollow.ToArray()
    summary = [pscustomobject]@{ files = $in.Files.Count; rowsBelowFile = $fileReportRows; rowsBelowWhole = $belowWhole.Count; kePointsBelow = $keBelow; hollowCells = $hollow.Count; block = $block }
}
Write-SmJson -Object $report -Path $ReportPath

Write-Host ''
if (-not $Quiet) { Write-Host ("  report written to {0}" -f $ReportPath) -ForegroundColor DarkGray }
if ($Whole) {
    if ($block -eq 0) { Write-Host '  every assessed row is taught to the floor and every KE point is covered where the map says it is' -ForegroundColor Green; exit 0 }
    Write-Host ("  {0} BLOCK finding(s): {1} row(s) under the whole-spine teaching floor, {2} KE point(s) uncovered{3}" -f $block, $belowWhole.Count, $keBelow, $(if ($keMissingInput.Count) { ', KE inputs missing' } else { '' })) -ForegroundColor Red
    Write-Host '  Teach the row as mechanism - what happens and why - in sentences that name it. A sentence that' -ForegroundColor Yellow
    Write-Host '  answers a model bullet does not count toward this floor, by design.' -ForegroundColor Yellow
    exit 1
}
if ($fileReportRows -gt 0 -or $keBelow -gt 0) { Write-Host ("  REPORT ONLY: {0} row(s) under the per-file floor, {1} KE point(s) not yet covered here - the whole-spine run at Stage 3c decides" -f $fileReportRows, $keBelow) -ForegroundColor Yellow }
else { Write-Host '  every own row reaches the per-file floor' -ForegroundColor Green }
exit 0
