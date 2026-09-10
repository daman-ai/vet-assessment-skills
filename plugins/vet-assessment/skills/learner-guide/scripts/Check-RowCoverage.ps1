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

    CALIBRATION (the numbers the gate was tuned against, recorded so they can
    be argued with).
    Corpus A (spine_backup_pre_round4, -Whole): the rows the shape mirror
    scores FULL carry far more ANSWERING than teaching relative to their
    size - Task 11(a): Packaging material 17 teaching / 10 answering, Vacuum
    sealing equipment 15 / 12, Ice slurry 59 / 17; Task 4(a): Meat 133 / 16,
    Eggs 98 / 16, Poultry 78 / 9 - the leaked prose was answer, and
    counting the two separately is the point. 2 rows under the whole-spine
    floor, 9 KE points under the every-term rule.
    Corpus B (current spine, -Whole): 0 rows under the whole-spine floor of
    3 once the name part of a qualified label anchors (before it, "Vegetable
    stock - 1.1 L (wet bulk, measured)" in Knowledge Task 5(f) read as taught
    in 0 sentences because neither the label nor the register alias
    "vegetable stock 1 1 l" can occur in prose); 1 row under the per-file
    floor of 2 (Workbook Task 3(a) row 3 in t3_3.1: a numbered row anchors
    only where it is a table label or a list number, and the guide's worked
    sequence is set on a different order). KE: 26 of 27 points covered at a 60 per cent
    term share; the 1 uncovered is real - KE7a "blast" is assigned to 5.1
    and 5.1 underpinningKnowledge (38 paragraphs) never says "blast" (the
    word appears 17 times elsewhere in the file: howToDoIt, activity, slides).
    Under an every-term rule 9 points failed, 8 of them on framing words
    ("commonly subject to", "procedures", "appropriate", "specifications",
    "produce") that the 25 per cent frame ceiling cannot see on a 27-point
    list; hence -KeTermShare 0.6, with every missing term still printed.
    Hollow relocation: 0 cells on the current spine; the fixture in
    Test-Pipeline.ps1 proves the arm fires on two-word cells.
    Floors: 2 (file, report), 3 (whole, block); hollow share 0.6; KE frame
    ceiling 0.25 and term share 0.6. Scoring calibration is the shape
    mirror's and is documented there.

    KE IDS COME FROM THE CONTRACT, NOT FROM ONE BULLET SPELLING (P0-09). The
    unit extract writes its Knowledge Evidence in more than one form: an
    explicit "- **KE1** text / - KE2a text" form, and the plain nested-bullet
    form training.gov.au publishes, with no ids at all. The first version of
    this arm parsed only the explicit form, so on a build whose extract used
    the plain form it evaluated 0 of 0 points and printed that every KE point
    was covered. The ids are now DERIVED from contract.json keMap - the same
    register Invoke-Render renders the mapping matrix from - and the extract
    is parsed in whichever form it uses (positional ids KE1, KE1a, KE1b ...
    when it carries none). A -Whole run REFUSES (exit 2) when the keMap is
    absent or empty, when the extract is absent or yields no point, or when
    the two disagree on the point set at the keMap's own granularity (a
    parent named in the keMap counts once; a parent named only through its
    sub-points counts each of them). A floor whose two inputs describe two
    different units has checked nothing. The "fewer than four points" skip of
    the frame-word ceiling is gone: a frame word is one that occurs in at
    least two points AND in more than the ceiling share of them, which is the
    same rule the ceiling always applied to four or more.

    REPORT STAMP (P0-08). spineFingerprint (v2), generated (UTC 'o'), mode,
    spineFiles and the arm roster are written into the report so
    Test-GridDisposition can refuse a report from another spine, another mode
    or an earlier run. An empty, whitespace-only or unparseable spine file is
    a named finding, not a silent skip.

    SELF-TEST:  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Check-RowCoverage.ps1 -SelfTest

    PS 5.1. ASCII only in this file. Nothing here names a unit, a brand or a
    build path.
#>

# GATE: stages=3c; requires=BuildDir

[CmdletBinding()]
param(
    [string] $BuildDir,
    [string] $SpineFile,
    [string] $SpineDir,
    [string] $Register,
    [string] $Cells,
    [switch] $Whole,
    [string] $ReportPath,
    #  The path the runner expects this gate to produce; the report path when
    #  no -ReportPath is given, a refusal when it names a different file.
    [string] $Produces,
    [switch] $SelfTest,
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

function Get-RcList {
    <#  A value as a plain List[object] of its elements: a table's rows, or one row's cells, whether it arrives as an array, a PSObject-wrapped array or a lone string (one element; $null is none). Returned with the unary comma, because a one-element List returned bare is unrolled by PowerShell into its single element and a one-row table would read as its own first row. Indexing with [n] is then safe at both levels.  #>
    param($Value)
    $out = New-Object System.Collections.Generic.List[object]
    if ($null -eq $Value) { return ,$out }
    $base = $Value
    if ($null -ne $Value.PSObject -and $null -ne $Value.PSObject.BaseObject) { $base = $Value.PSObject.BaseObject }
    if ($base -is [string]) { $out.Add([string]$base); return ,$out }
    if ($base -is [System.Collections.IEnumerable]) {
        foreach ($e in $base) { $out.Add($e) }
        return ,$out
    }
    $out.Add($base)
    return ,$out
}

function Get-RcKeNorm {
    <# One spelling for a KE id on both sides: "KE 1a", "ke1a" and "KE1a" are the same point. #>
    param([string] $Id)
    return (("$Id" -replace '\s', '').ToUpperInvariant())
}

function Get-RcKePoints {
    <#  Knowledge Evidence points out of the unit extract's own markdown, in
        whichever of its two forms the section uses:

          explicit    "- **KE1** text", "  - KE2a text", and a nested plain
                      "- chillers" under either (id = owner/slug)
          positional  plain nested bullets with no ids (the form the unit
                      register publishes): top-level bullets are KE1, KE2 ...
                      in order, their sub-bullets KE1a, KE1b ..., anything
                      deeper owner/slug

        Level 0 is a top-level point, 1 a sub-point, 2 a nested slug. Returns
        the points, the frame words (the section's non-bullet lines) and the
        form it read. The form is decided once for the whole section: any
        explicit id anywhere in it makes the section explicit.  #>
    param([string] $Text)
    $points = New-Object System.Collections.Generic.List[object]
    $frame  = New-Object System.Collections.Generic.List[string]
    if (-not $Text) { return [pscustomobject]@{ Points = $points.ToArray(); Frame = $frame.ToArray(); Form = 'none' } }
    $section = New-Object System.Collections.Generic.List[string]
    $inKe = $false
    foreach ($raw in @($Text -split "\r?\n")) {
        $ln = "$raw".TrimEnd()
        if ($ln -match '^#+\s') {
            if ($ln -match '(?i)^#+\s*knowledge evidence') { $inKe = $true; continue }
            if ($inKe) { break }
            continue
        }
        if ($inKe) { $section.Add($ln) }
    }
    $explicit = $false
    foreach ($ln in $section) { if ($ln -match '^\s*-\s*\*\*KE\d+\*\*' -or $ln -match '^\s*-\s*KE\d+[a-z]+\s') { $explicit = $true; break } }
    $form = if ($section.Count -eq 0) { 'none' } elseif ($explicit) { 'explicit' } else { 'positional' }
    $lastId = ''; $lastSub = ''
    $top = 0; $subN = 0; $topIndent = -1; $subIndent = -1
    foreach ($ln in $section) {
        if (-not $ln.Trim()) { continue }
        if ($explicit) {
            $m = [regex]::Match($ln, '^\s*-\s*\*\*(KE\d+)\*\*\s*(.*)$')
            if ($m.Success) {
                $lastId = $m.Groups[1].Value; $lastSub = ''
                $points.Add([pscustomobject]@{ Id = $lastId; Parent = $lastId; Level = 0; Text = ($m.Groups[2].Value -replace '[*:]+$', '').Trim() })
                continue
            }
            $m = [regex]::Match($ln, '^\s*-\s*(KE\d+[a-z]+)\s+(.*)$')
            if ($m.Success) {
                $lastSub = $m.Groups[1].Value
                $parent = [regex]::Match($lastSub, '^KE\d+').Value
                $points.Add([pscustomobject]@{ Id = $lastSub; Parent = $parent; Level = 1; Text = ($m.Groups[2].Value -replace '[*:]+$', '').Trim() })
                continue
            }
            $m = [regex]::Match($ln, '^\s*-\s+(.*)$')
            if ($m.Success -and $lastId) {
                $t = ($m.Groups[1].Value -replace '[*:]+$', '').Trim()
                $owner = if ($lastSub) { $lastSub } else { $lastId }
                $parent = [regex]::Match($owner, '^KE\d+').Value
                $points.Add([pscustomobject]@{ Id = ("{0}/{1}" -f $owner, ((ConvertTo-GateNormal $t) -replace ' ', '-')); Parent = $parent; Level = 2; Text = $t })
                continue
            }
            $frame.Add($ln.Trim())
            continue
        }
        # positional: indentation decides the level; the first bullet sets the top level
        $m = [regex]::Match($ln, '^(\s*)-\s+(.*)$')
        if ($m.Success) {
            $indent = $m.Groups[1].Value.Length
            $t = ($m.Groups[2].Value -replace '[*:]+$', '').Trim()
            if ($topIndent -lt 0) { $topIndent = $indent }
            if ($indent -le $topIndent) {
                $top++; $subN = 0; $lastId = "KE$top"; $lastSub = ''
                $points.Add([pscustomobject]@{ Id = $lastId; Parent = $lastId; Level = 0; Text = $t })
            }
            elseif ($subIndent -lt 0 -or $indent -le $subIndent) {
                if ($subIndent -lt 0) { $subIndent = $indent }
                $subN++
                $letter = if ($subN -le 26) { [string][char](96 + $subN) } else { 'z' + $subN }
                $lastSub = "KE{0}{1}" -f $top, $letter
                $points.Add([pscustomobject]@{ Id = $lastSub; Parent = $lastId; Level = 1; Text = $t })
            }
            else {
                $owner = if ($lastSub) { $lastSub } else { $lastId }
                $points.Add([pscustomobject]@{ Id = ("{0}/{1}" -f $owner, ((ConvertTo-GateNormal $t) -replace ' ', '-')); Parent = $lastId; Level = 2; Text = $t })
            }
            continue
        }
        $frame.Add($ln.Trim())
    }
    return [pscustomobject]@{ Points = $points.ToArray(); Frame = $frame.ToArray(); Form = $form }
}

function Compare-RcKeSets {
    <#  Does contract.json keMap name the same point set the extract yields, at
        the keMap's OWN granularity? A parent named in the keMap counts once
        and its sub-points are folded under it; a parent NOT named counts each
        of its sub-points, every one of which must be named. Nested slugs are
        never keMap ids. Returns Expected (the count the keMap should have),
        Missing (extract points the keMap does not name) and Unknown (keMap
        ids no extract point carries).  #>
    param($Points, [hashtable] $KeIds)
    $expected = 0
    $missing = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    $parents = @($Points | Where-Object { $_.Level -eq 0 })
    foreach ($p in $parents) {
        $pn = Get-RcKeNorm $p.Id
        $subs = @($Points | Where-Object { $_.Level -eq 1 -and $_.Parent -eq $p.Id })
        if ($KeIds.ContainsKey($pn)) {
            #  the parent is named; a sub-point named beside it is a second,
            #  finer entry for the same point and is counted as one
            $expected++; $seen[$pn] = $true
            foreach ($s in $subs) { $sn = Get-RcKeNorm $s.Id; if ($KeIds.ContainsKey($sn)) { $expected++; $seen[$sn] = $true } }
            continue
        }
        if ($subs.Count -eq 0) { $expected++; $missing.Add($p.Id); continue }
        foreach ($s in $subs) {
            $expected++
            $sn = Get-RcKeNorm $s.Id
            if ($KeIds.ContainsKey($sn)) { $seen[$sn] = $true } else { $missing.Add($s.Id) }
        }
    }
    $unknown = @($KeIds.Keys | Where-Object { -not $seen.ContainsKey($_) } | ForEach-Object { $KeIds[$_] } | Sort-Object)
    return [pscustomobject]@{ Expected = $expected; Missing = $missing.ToArray(); Unknown = $unknown }
}

# ---------------------------------------------------------------------------
# SELF-TEST. Synthetic build in the temp directory; every string invented.
# Each plant is read back from the fixture before its verdict is trusted.
# Ends SELF-TEST PASS (exit 0) or SELF-TEST FAIL (exit 4).
# ---------------------------------------------------------------------------
if ($SelfTest) {
    Write-Host ''
    Write-Host ("  {0} SELF-TEST - a clean result is not believed until the gate has failed on a planted defect" -f $GATE) -ForegroundColor Cyan
    $script:RcSelfTestFailed = 0
    $self = $MyInvocation.MyCommand.Path
    $fx = Join-Path ([System.IO.Path]::GetTempPath()) ('rc-selftest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path (Join-Path $fx 'spine') | Out-Null

    function Test-RcSelf { param([bool] $Ok, [string] $What) if ($Ok) { Write-Host ("    ok   {0}" -f $What) -ForegroundColor Green } else { Write-Host ("    X    {0}" -f $What) -ForegroundColor Red; $script:RcSelfTestFailed++ } }
    function Write-RcFixture { param([string] $Path, $Object) [System.IO.File]::WriteAllText($Path, ($Object | ConvertTo-Json -Depth 14), (New-Object System.Text.UTF8Encoding($true))) }
    function Write-RcText { param([string] $Path, [string[]] $Lines) [System.IO.File]::WriteAllText($Path, ($Lines -join "`r`n"), (New-Object System.Text.UTF8Encoding($true))) }
    function Invoke-RcSelf {
        param([hashtable] $Arguments)
        $text = ''; $rc = -1
        try { $lines = @(& $self @Arguments *>&1 | ForEach-Object { "$_" }); $rc = $LASTEXITCODE; $text = ($lines -join "`n") }
        catch { $text = "EXCEPTION: " + $_.Exception.Message; $rc = -1 }
        return [pscustomobject]@{ Rc = $rc; Text = $text }
    }
    function Read-RcReport { param([string] $Path) if (Test-Path -LiteralPath $Path) { return (Get-GateJson -Path $Path) } return $null }

    try {
        Write-RcFixture -Path (Join-Path $fx 'withhold-register.json') -Object @{
            subSections = @{ '1.1' = @{ subSection = '1.1'; refs = @('Task 1(a)'); tasks = @(
                @{ ref = 'Task 1(a)'; id = 'TEST_Tool Task 1(a)'; document = 'TEST_Tool'; kind = 'labelled'
                   headers = @('Widget', 'Purpose', 'Care'); assessedHeaders = @(1, 2)
                   items = @('Widget A', 'Widget B', 'Widget C'); aliases = @{ 'Widget A' = @(); 'Widget B' = @(); 'Widget C' = @() }
                   subjectClass = 'widget'; subjects = @(); unassessedSubjects = @('Widget D'); allowance = 1
                   shape = @{ rows = 3; assessedColumns = 2; bulletsPerCell = @{ min = 1; max = 2 }; wordGuide = @{ min = 10; max = 20 }; benchmarkMinimum = 1 } } ); freeText = @() } }
        }
        Write-RcFixture -Path (Join-Path $fx 'assessor-cells.json') -Object @{
            _WARNING = 'GATE-ONLY synthetic cells for the self-test'
            wordPipeline = @{ stopwords = 176; stem = 'crude suffix strip: ing, ed, es, s'; stripLearnerWords = 'headers and items'; dfCeiling = 0.25 }
            grids = @(@{ ref = 'Task 1(a)'; id = 'TEST_Tool Task 1(a)'; subSection = '1.1'; kind = 'labelled'; document = 'TEST_Tool'
                         headers = @('Widget', 'Purpose', 'Care'); assessedHeaders = @(1, 2)
                         rows = @(
                            @{ item = 'Widget A'; assessed = $true; cells = @(
                                @{ col = 1; header = 'Purpose'; state = 'answered'; bullets = @(@{ text = 'turns the main spindle'; words = @('turn', 'main', 'spindle') }) },
                                @{ col = 2; header = 'Care'; state = 'answered'; bullets = @(@{ text = 'oil the bearing weekly'; words = @('oil', 'bear', 'weekly') }) }) },
                            @{ item = 'Widget B'; assessed = $true; cells = @(
                                @{ col = 1; header = 'Purpose'; state = 'answered'; bullets = @(@{ text = 'feeds the hopper evenly'; words = @('feed', 'hopper', 'evenly') }) },
                                @{ col = 2; header = 'Care'; state = 'answered'; bullets = @(@{ text = 'clear the chute after every run'; words = @('clear', 'chute', 'run') }) }) },
                            @{ item = 'Widget C'; assessed = $true; cells = @(
                                @{ col = 1; header = 'Purpose'; state = 'answered'; bullets = @(@{ text = 'holds the jig square'; words = @('hold', 'jig', 'square') }) },
                                @{ col = 2; header = 'Care'; state = 'answered'; bullets = @(@{ text = 'inspect the clamp face'; words = @('inspect', 'clamp', 'face') }) }) }
                         ) })
            freeText = @(); taskLevel = @()
        }
        $contractPath = Join-Path $fx 'contract.json'
        $extractPath  = Join-Path $fx 'unit_extract.md'
        $spinePath    = Join-Path $fx 'spine\t1_1.1.json'
        $reportPath   = Join-Path $fx 'row-coverage-report.json'
        function Set-RcContract { param($KeMap) Write-RcFixture -Path $contractPath -Object @{ unit = @{ code = 'TEST001' }; questionMap = @{ '1.1' = @('Task 1(a)') }; keMap = $KeMap } }
        Set-RcContract -KeMap ([ordered]@{ _comment = 'synthetic'; KE1 = @{ assessedIn = 'Task 1'; taughtAt = '1.1' }; KE2 = @{ assessedIn = 'Task 1'; taughtAt = '1.1' }; KE3 = @{ assessedIn = 'Task 1'; taughtAt = '1.1' } })
        Write-RcText -Path $extractPath -Lines @(
            '# TEST001 - unit extract', '', '## Knowledge evidence (verbatim)', '',
            'Demonstrated knowledge required to complete the tasks:', '',
            '- **KE1** widget drive gearing', '- **KE2** hopper material rate:', '  - KE2a chute blockage', '- **KE3** belt tensioner', '',
            '## Assessment conditions', '', 'None.')
        #  two rows taught, Widget C never mentioned; KE1 and KE2 taught, KE3 (belt tensioner) never
        Write-RcFixture -Path $spinePath -Object @{
            ref = '1.1'; title = 'Widgets'
            underpinningKnowledge = @(
                'Widget A is the drive unit with the main gearing. Widget A needs watching in humid weather. Widget A is serviced by the fitter, not by you.',
                'Widget B sets the rate at which material reaches the hopper. A chute blockage stops Widget B. Widget B is serviced by the fitter as well.')
        }
        $planted = Get-GateFileText -Path $spinePath
        Test-RcSelf -Ok ($planted.IndexOf('Widget A is the drive unit', [System.StringComparison]::Ordinal) -ge 0 -and $planted -notmatch 'Widget C' -and $planted -notmatch 'tensioner') -What 'plant 1 landed: Widget C and the belt tensioner are never mentioned'

        # ---- 1. -Whole BLOCKS on the untaught row and the uncovered KE point; the report is stamped; the roster prints
        $r1 = Invoke-RcSelf -Arguments @{ BuildDir = $fx; Whole = $true; Quiet = $true }
        $rep1 = Read-RcReport -Path $reportPath
        Test-RcSelf -Ok ($r1.Rc -eq 1) -What ("-Whole exits 1 on an untaught row and an uncovered KE point (rc={0})" -f $r1.Rc)
        $fpNow = Get-SpineFingerprint -BuildDir $fx -Quiet
        $stamp = if ($null -ne $rep1) { [string](Get-GateProp -Object $rep1 -Names @('spineFingerprint') -Default '') } else { '' }
        Test-RcSelf -Ok ($stamp -like 'v2:*' -and $stamp -eq $fpNow) -What ("report stamps spineFingerprint v2 equal to the current spine ({0})" -f $stamp)
        $gen = if ($null -ne $rep1) { [string](Get-GateProp -Object $rep1 -Names @('generated') -Default '') } else { '' }
        $genOk = $false
        try { $dto = [System.DateTimeOffset]::Parse($gen, [System.Globalization.CultureInfo]::InvariantCulture); $genOk = ($gen -match 'Z$' -and ([System.DateTimeOffset]::UtcNow - $dto).TotalMinutes -lt 10) } catch { $genOk = $false }
        Test-RcSelf -Ok $genOk -What ("report stamps generated as UTC round-trip time ({0})" -f $gen)
        Test-RcSelf -Ok ($null -ne $rep1 -and [string](Get-GateProp -Object $rep1 -Names @('mode') -Default '') -eq 'whole' -and @(Get-GateProp -Object $rep1 -Names @('spineFiles') -Default @()) -contains 't1_1.1.json') -What 'report stamps mode whole and the spine file list'
        Test-RcSelf -Ok ($r1.Text -match '(?m)^ARMS: .*row-floor\|true\|ran\|3\|1' -and $r1.Text -match 'ke-coverage\|true\|ran\|4\|1' -and $r1.Text -match 'spine-files\|true\|ran\|1\|0') -What 'the ARMS: roster prints row-floor (3 rows, 1 finding), ke-coverage (4 points, 1 finding) and spine-files ran'
        $ke3 = @(); $ke1 = @()
        if ($null -ne $rep1) { $ke3 = @($rep1.ke.points | Where-Object { $_.Id -eq 'KE3' }); $ke1 = @($rep1.ke.points | Where-Object { $_.Id -eq 'KE1' }) }
        Test-RcSelf -Ok ($ke3.Count -eq 1 -and -not $ke3[0].Covered -and $ke1.Count -eq 1 -and $ke1[0].Covered -and $rep1.ke.keMap.count -eq 3 -and $rep1.ke.keMap.expected -eq 3 -and $rep1.ke.form -eq 'explicit') -What 'KE ids come from the keMap (3 = 3 expected, explicit extract): KE1 covered, KE3 uncovered with its missing terms'

        # ---- 2. an EMPTY keMap is a refusal naming the input
        Set-RcContract -KeMap ([ordered]@{ _comment = 'no points' })
        $ct = Get-GateFileText -Path $contractPath
        Test-RcSelf -Ok ($ct -match '"keMap"' -and $ct -notmatch '"KE\s?\d') -What 'plant 2 landed: contract.json keMap carries no KE key'
        $r2 = Invoke-RcSelf -Arguments @{ BuildDir = $fx; Whole = $true; Quiet = $true }
        Test-RcSelf -Ok ($r2.Rc -eq 2 -and $r2.Text -match 'contract\.json keMap') -What ("an empty keMap exits 2 naming contract.json keMap (rc={0})" -f $r2.Rc)

        # ---- 3. a keMap that DISAGREES with the extract's point set is a refusal naming both counts
        Set-RcContract -KeMap ([ordered]@{ KE1 = @{ taughtAt = '1.1' }; KE2 = @{ taughtAt = '1.1' } })
        $r3 = Invoke-RcSelf -Arguments @{ BuildDir = $fx; Whole = $true; Quiet = $true }
        Test-RcSelf -Ok ($r3.Rc -eq 2 -and $r3.Text -match 'contract\.json keMap' -and $r3.Text -match 'KE3' -and $r3.Text -match '\b2\b' -and $r3.Text -match '\b3\b') -What ("a keMap of 2 against an extract of 3 exits 2 naming keMap, both counts and the unnamed point (rc={0})" -f $r3.Rc)

        # ---- 4. the POSITIONAL extract form (no ids) with 'KE 1a'-style keMap keys parses and agrees; fewer than 4 points still evaluate
        Write-RcText -Path $extractPath -Lines @(
            '# TEST001 - unit extract', '', '## Knowledge evidence', '',
            'Demonstrated knowledge required to complete the tasks:', '',
            '- widget families and their drive arrangements:', '  - main gearing of the drive unit', '  - hopper material rate and chute blockage', '- belt tensioner care.', '',
            '## Assessment conditions', '', 'None.')
        Set-RcContract -KeMap ([ordered]@{ 'KE 1a' = @{ taughtAt = '1.1' }; 'KE 1b' = @{ taughtAt = '1.1' }; 'KE 2' = @{ taughtAt = '1.1' } })
        $et = Get-GateFileText -Path $extractPath
        Test-RcSelf -Ok ($et -notmatch 'KE\d' -and $et -match 'belt tensioner care') -What 'plant 4 landed: the extract carries no KE id at all'
        $r4 = Invoke-RcSelf -Arguments @{ BuildDir = $fx; Whole = $true; Quiet = $true }
        $rep4 = Read-RcReport -Path $reportPath
        $ids4 = @(); if ($null -ne $rep4) { $ids4 = @($rep4.ke.points | ForEach-Object { $_.Id }) }
        Test-RcSelf -Ok ($r4.Rc -eq 1 -and $null -ne $rep4 -and $rep4.ke.form -eq 'positional' -and $rep4.ke.keMap.count -eq 3 -and $rep4.ke.keMap.expected -eq 3 -and $ids4.Count -eq 3 -and ($ids4 -contains 'KE1a') -and ($ids4 -contains 'KE1b') -and ($ids4 -contains 'KE2') -and ($ids4 -notcontains 'KE1')) -What ("positional form: KE1a, KE1b, KE2 evaluated (3 points, no <4 skip), the group header KE1 is not a point, keMap 3 = 3 (rc={0})" -f $r4.Rc)
        $ke2 = @(); if ($null -ne $rep4) { $ke2 = @($rep4.ke.points | Where-Object { $_.Id -eq 'KE2' }) }
        Test-RcSelf -Ok ($ke2.Count -eq 1 -and -not $ke2[0].Covered -and $r4.Text -match 'KE 2') -What 'the untaught positional point (KE 2, belt tensioner) is reported under the keMap''s own key'

        # ---- 5. no unit extract is a refusal naming it
        Move-Item -LiteralPath $extractPath -Destination ($extractPath + '.off') -Force
        Test-RcSelf -Ok (-not (Test-Path -LiteralPath $extractPath)) -What 'plant 5 landed: unit_extract.md is absent'
        $r5 = Invoke-RcSelf -Arguments @{ BuildDir = $fx; Whole = $true; Quiet = $true }
        Test-RcSelf -Ok ($r5.Rc -eq 2 -and $r5.Text -match 'unit_extract\.md') -What ("-Whole with no unit extract exits 2 naming unit_extract.md (rc={0})" -f $r5.Rc)
        Move-Item -LiteralPath ($extractPath + '.off') -Destination $extractPath -Force

        # ---- 6. an empty spine file is a NAMED finding
        $emptyPath = Join-Path $fx 'spine\t1_1.2.json'
        [System.IO.File]::WriteAllText($emptyPath, "`r`n  ", (New-Object System.Text.UTF8Encoding($true)))
        Test-RcSelf -Ok ((Test-Path -LiteralPath $emptyPath) -and -not (Get-GateFileText -Path $emptyPath).Trim()) -What 'plant 6 landed: t1_1.2.json exists and is whitespace-only'
        $r6 = Invoke-RcSelf -Arguments @{ BuildDir = $fx; Whole = $true; Quiet = $true }
        $rep6 = Read-RcReport -Path $reportPath
        $emptyRep = if ($null -ne $rep6) { @(Get-GateProp -Object $rep6 -Names @('emptyFiles') -Default @()) } else { @() }
        Test-RcSelf -Ok ($r6.Rc -eq 1 -and $r6.Text -match 't1_1\.2\.json' -and $r6.Text -match '(?i)empty' -and @($emptyRep | Where-Object { $_ -match 't1_1\.2\.json' }).Count -eq 1 -and $r6.Text -match 'spine-files\|true\|ran\|1\|1') -What ("an empty spine file is named on the console, listed in the report and counted by the spine-files arm (rc={0})" -f $r6.Rc)
        Remove-Item -LiteralPath $emptyPath -Force

        # ---- 7. file mode reports, stamps mode file, and exits 0
        $r7 = Invoke-RcSelf -Arguments @{ BuildDir = $fx; SpineFile = $spinePath; Quiet = $true }
        $rep7 = Read-RcReport -Path $reportPath
        Test-RcSelf -Ok ($r7.Rc -eq 0 -and $null -ne $rep7 -and [string](Get-GateProp -Object $rep7 -Names @('mode') -Default '') -eq 'file' -and $r7.Text -match 'REPORT ONLY' -and $r7.Text -match '(?m)^ARMS: .*row-floor\|false\|ran\|') -What ("file mode exits 0, stamps mode file and prints its roster with row-floor advisory (rc={0})" -f $r7.Rc)

        # ---- 8. -Produces beside a different -ReportPath is refused naming both
        $r8 = Invoke-RcSelf -Arguments @{ BuildDir = $fx; Whole = $true; Produces = (Join-Path $fx 'produced.json'); ReportPath = (Join-Path $fx 'other.json'); Quiet = $true }
        Test-RcSelf -Ok ($r8.Rc -eq 2 -and $r8.Text -match 'produced\.json' -and $r8.Text -match 'other\.json') -What ("-Produces beside a different -ReportPath is refused naming both (rc={0})" -f $r8.Rc)
    }
    finally {
        try { Remove-Item -LiteralPath $fx -Recurse -Force -ErrorAction SilentlyContinue } catch { }
    }

    Write-Host ''
    if ($script:RcSelfTestFailed -gt 0) {
        Write-Host ("  SELF-TEST FAIL: {0} check(s) failed - no result from this gate may be believed until they pass" -f $script:RcSelfTestFailed) -ForegroundColor Red
        exit 4
    }
    Write-Host '  SELF-TEST PASS: the gate refused every starved input by name, failed on every planted defect, stamped its report and printed its roster' -ForegroundColor Green
    exit 0
}

try {

if ($Produces) {
    if (-not $ReportPath) { $ReportPath = $Produces }
    elseif ([System.IO.Path]::GetFullPath($ReportPath).ToLowerInvariant() -ne [System.IO.Path]::GetFullPath($Produces).ToLowerInvariant()) {
        Write-Host ("  X {0}: -Produces {1} names a different file from -ReportPath {2}. A runner that reads one path while the gate writes another is reading a stale report; pass one path." -f $GATE, $Produces, $ReportPath) -ForegroundColor Red
        exit 2
    }
}

try { $in = Get-SmInputs -BuildDir $BuildDir -SpineFile $SpineFile -SpineDir $SpineDir -Register $Register -Cells $Cells -Gate $GATE }
catch { Write-Host ("  X {0}" -f $_.Exception.Message) -ForegroundColor Red; exit 2 }

$set = Get-SmGridSet -RegisterDoc $in.Register -CellsDoc $in.Cells -DfCeiling $DfCeiling -MinHitWords $MinHitWords
$grids = @($set.Grids)
#  mode: 'whole' only for a whole-spine -Whole run. -Whole over one -SpineFile
#  still blocks, but its floor is not the whole-spine one, and the report says
#  so, so Test-GridDisposition will not dispose a grid on it.
$mode = if ($Whole -and -not $SpineFile) { 'whole' } else { 'file' }
if ($Whole -and $SpineFile) { Write-Host ("  ! {0}: -Whole with -SpineFile blocks over ONE file; the report is stamped mode 'file' and cannot feed the disposition" -f $GATE) -ForegroundColor Yellow }
$skip = Get-GateUnrenderedFields -BuildDir $BuildDir -ForSweep
$skipTable = @{}
foreach ($k in $skip.Keys) { $skipTable[$k] = $true }
if (-not $ReportPath) { $ReportPath = Join-Path $BuildDir 'row-coverage-report.json' }
$blanks = Get-GateBlankTokens -BuildDir $BuildDir

if (-not $Quiet) {
    Write-Host ''
    Write-Host ("ROW COVERAGE - is every assessed row taught?  ({0} mode)" -f $mode) -ForegroundColor Cyan
}
#  BLOCKING: a cells file with no grid is an empty check-set - a refusal
#  (exit 2 through the catch at the foot of this file), never a pass.
Write-GateCheckSet -What 'assessed grids' -Count $grids.Count -DerivedFrom ("{0} with cells from {1}" -f (Split-Path $in.RegisterPath -Leaf), (Split-Path $in.CellsPath -Leaf)) -Blocking -Input 'assessor-cells.json grids'

#  Every arm, declared before any runs. The two floors and the KE arm BLOCK in
#  -Whole and report in file mode; spine-files blocks in both; hollow
#  relocation reports.
Register-GateArm -Name 'spine-files' -Blocking
Register-GateArm -Name 'row-floor' -Blocking:$Whole
Register-GateArm -Name 'ke-coverage' -Blocking:$Whole
Register-GateArm -Name 'hollow-relocation'

if (-not $Quiet) {
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
$emptyFiles = New-Object System.Collections.Generic.List[string]
$filesRead = 0
$hollowCellsExamined = 0

foreach ($f in $in.Files) {
    #  A FILE THE FLOOR CANNOT READ IS A FINDING, NOT A SKIP. An empty,
    #  whitespace-only or unparseable spine file used to fall through in
    #  silence; every row it should have taught then read as taught elsewhere
    #  or not at all, and nothing named the file.
    $json = $null; $readError = ''
    try { $json = Get-GateJson -Path $f.FullName } catch { $readError = $_.Exception.Message }
    if ($null -eq $json) {
        $why = if ($readError) { 'unparseable (' + $readError + ')' } else { 'empty or whitespace-only' }
        $emptyFiles.Add(("{0}: {1}" -f $f.Name, $why))
        Write-Host ("  X {0}: spine file {1} is {2} - a file the floor cannot read is a finding, not a skip" -f $GATE, $f.Name, $why) -ForegroundColor Red
        continue
    }
    $filesRead++
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
        $tRowsList = Get-RcList -Value $t.Rows
        $tRowCount = $tRowsList.Count
        $tHeads = @(@($t.Headers) | ForEach-Object { ConvertTo-GateNormal ([string]$_) } | Where-Object { $_ })
        if ($tHeads.Count -lt 2) { continue }
        foreach ($g in $own) {
            if ($g.WordGuideMin -le 0) { continue }
            $gHeads = @(@($g.Headers) | ForEach-Object { ConvertTo-GateNormal $_ } | Where-Object { $_ })
            $shared = @($tHeads | Where-Object { $gHeads -contains $_ })
            if ($shared.Count -lt 2) { continue }
            $need = [int][math]::Ceiling($HollowShare * $g.WordGuideMin)
            for ($r = $t.Skip; $r -lt $tRowCount; $r++) {
                #  NOT $cells. PowerShell variables are case-insensitive and this script
                #  has a [string] $Cells PARAMETER, so "$cells = <row>" converted every
                #  row to its first string and the hollow check reported nothing on a
                #  table it had walked correctly. Cost most of an afternoon.
                $rowCells = Get-RcList -Value $tRowsList[$r]
                $cellCount = $rowCells.Count
                if ($cellCount -lt 2) { continue }
                $label = [string]$rowCells[0]
                $labelN = ConvertTo-GateNormal $label
                if (-not $labelN -or $tHeads -contains $labelN) { continue }
                $isAssessed = $false
                foreach ($row in $g.Rows) { foreach ($a in $row.Anchors) { if ($a.IsLabel -and $a.Stem -and (' ' + (@(Get-SmTokens $label) -join ' ') + ' ') -eq $a.Stem) { $isAssessed = $true } } }
                if ($isAssessed) { continue }   # an assessed row is the mirror's business, not a relocation
                if ($label -match $WithheldRx) { continue }
                for ($c = 1; $c -lt $cellCount; $c++) {
                    $txt = [string]$rowCells[$c]
                    if ($txt -match $WithheldRx) { continue }
                    if (-not (Test-GateCellFilled -Text $txt -BlankTokens $blanks)) { continue }
                    $hollowCellsExamined++
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

    foreach ($go in $gridsOut) { $fileReportRows += @($go.Rows | Where-Object { $_.Below }).Count }
    if (-not $Quiet -and $gridsOut.Count -gt 0) {
        Write-Host ''
        Write-Host ("  {0}  (sub-section {1}; {2} sentences)" -f $f.Name, $sub, $sentences.Count) -ForegroundColor Cyan
        foreach ($am in $scan.Ambient) { Write-Host ("    ambient alias not used as an anchor in this file: {0}" -f $am) -ForegroundColor DarkGray }
        foreach ($go in $gridsOut) {
            $below = @($go.Rows | Where-Object { $_.Below })
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

#  THE KE IDS ARE THE keMap's KEYS - the register Invoke-Render renders the
#  mapping matrix from. Keys beginning '_' are commentary. Normalised once
#  so "KE 1a" in the contract and KE1a from the extract are one point.
$keIds = @{}            # normalised id -> the contract's own key
$keIdOrder = New-Object System.Collections.Generic.List[string]
if ($null -ne $keMap -and $keMap -isnot [string] -and $keMap -isnot [ValueType]) {
    foreach ($kp in $keMap.PSObject.Properties) {
        if ($kp.Name -like '_*') { continue }
        $n = Get-RcKeNorm $kp.Name
        if (-not $n) { continue }
        if (-not $keIds.ContainsKey($n)) { $keIds[$n] = $kp.Name; $keIdOrder.Add($n) }
    }
}
$keMapSource = if ($ContractPath) { (Split-Path $ContractPath -Leaf) + ' keMap' } else { 'contract.json keMap' }

$ke = $null
if (Test-Path -LiteralPath $UnitExtract) { $ke = Get-RcKePoints -Text (Get-GateFileText -Path $UnitExtract) }
$points = @(); $keForm = 'none'
if ($null -ne $ke) { $points = @($ke.Points); $keForm = [string]$ke.Form }

Write-Host ''
Write-Host ("  KE CONCEPT COVERAGE ({0})" -f $(if ($Whole) { 'block' } else { 'report - points assigned to the file(s) in hand' })) -ForegroundColor Cyan
#  The three refusals of a -Whole run, each naming its input: no keMap ids, no
#  extract points, or a keMap that describes a different point set from the
#  extract. In file mode the same absences are printed and the arm reports.
Write-GateCheckSet -What 'KE points' -Count $keIds.Count -DerivedFrom ("{0} keys (the register the mapping matrix is rendered from)" -f $keMapSource) -Blocking:$Whole -Input $keMapSource
Write-GateCheckSet -What ("KE points parsed from the unit extract ({0} form)" -f $keForm) -Count $points.Count -DerivedFrom (Split-Path $UnitExtract -Leaf) -Blocking:$Whole -Input (Split-Path $UnitExtract -Leaf)
if ($keIds.Count -eq 0) { $keMissingInput.Add(("{0} carries no KE point" -f $keMapSource)) }
if ($points.Count -eq 0) { $keMissingInput.Add(("unit extract yields no KE point ({0})" -f $UnitExtract)) }

$keAgree = $null
if ($keMissingInput.Count -eq 0) {
    $keAgree = Compare-RcKeSets -Points $points -KeIds $keIds
    $disagree = ($keAgree.Expected -ne $keIds.Count -or (Get-GateCount -Value $keAgree.Missing) -gt 0 -or (Get-GateCount -Value $keAgree.Unknown) -gt 0)
    $agreeLine = ("  keMap {0} point(s) against {1} expected from the extract's {2} point(s) at the keMap's granularity{3}{4}" -f $keIds.Count, $keAgree.Expected, $points.Count,
        $(if (@($keAgree.Missing).Count) { '; not named in the keMap: ' + (@($keAgree.Missing) -join ', ') } else { '' }),
        $(if (@($keAgree.Unknown).Count) { '; named in the keMap but not in the extract: ' + (@($keAgree.Unknown) -join ', ') } else { '' }))
    if ($disagree) {
        if ($Whole) {
            throw (New-Object System.InvalidOperationException (("CHECK-SET DISAGREES: {0} lists {1} KE point(s) but the unit extract ({2} form, {3} point(s)) yields {4} at the keMap's own granularity.{5}{6} A floor whose two inputs describe two different units has checked nothing; fix the keMap or the extract. Exit 2." -f $keMapSource, $keIds.Count, $keForm, $points.Count, $keAgree.Expected,
                $(if (@($keAgree.Missing).Count) { ' Not named in the keMap: ' + (@($keAgree.Missing) -join ', ') + '.' } else { '' }),
                $(if (@($keAgree.Unknown).Count) { ' Named in the keMap but not in the extract: ' + (@($keAgree.Unknown) -join ', ') + '.' } else { '' }))))
        }
        Write-Host ("  !" + $agreeLine.Substring(2) + ' - the two disagree; the whole-spine run at Stage 3c refuses on this') -ForegroundColor Yellow
    }
    else { Write-Host $agreeLine -ForegroundColor DarkGray }
}

$fileSubs = @{}
foreach ($fr in $fileReports) { if ($fr.SubSection) { $fileSubs[$fr.SubSection] = $true } }
$keBelow = 0
$keEvaluated = 0
if ($keMissingInput.Count -eq 0) {
    $frameWords = @{}
    foreach ($ln in $ke.Frame) { foreach ($w in (Get-SmWords $ln)) { $frameWords[$w] = $true } }
    #  A FRAME WORD OCCURS IN AT LEAST TWO POINTS AND IN MORE THAN THE CEILING
    #  SHARE OF THEM. The "at least two" was implicit while the ceiling only
    #  ran on four or more points (1 of 4 is under a quarter); stated, it lets
    #  the ceiling run on any point count without stripping every word of a
    #  three-point list. No skip on the count: the floor always runs.
    $df = @{}
    foreach ($p in $points) { foreach ($w in @(Get-SmWords $p.Text | Select-Object -Unique)) { if ($df.ContainsKey($w)) { $df[$w]++ } else { $df[$w] = 1 } } }
    foreach ($w in @($df.Keys)) { if ($df[$w] -ge 2 -and ($df[$w] / [double]$points.Count) -gt $KeFrameCeiling) { $frameWords[$w] = $true } }
    foreach ($p in $points) {
        #  WHICH keMap ENTRY OWNS THIS POINT: its own id; the owner of a nested
        #  slug; or its parent where the parent is named directly. A point
        #  none of those resolves is a group header the keMap addresses
        #  through its sub-points, and is not itself evaluated.
        $keyNorm = ''
        $cands = New-Object System.Collections.Generic.List[string]
        $cands.Add((Get-RcKeNorm $p.Id))
        if ($p.Id -match '^([^/]+)/') { $cands.Add((Get-RcKeNorm $Matches[1])) }
        $cands.Add((Get-RcKeNorm $p.Parent))
        foreach ($c in $cands) { if ($keIds.ContainsKey($c)) { $keyNorm = $c; break } }
        if (-not $keyNorm) { continue }
        $keKey = $keIds[$keyNorm]
        $entry = $keMap.$keKey
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
        $keEvaluated++
        $keOut.Add([pscustomobject]@{ Id = $p.Id; KeMapKey = $keKey; Text = $p.Text; AssignedTo = $assigned; Terms = $terms; Present = $present; Need = $needTerms; Missing = $missing.ToArray(); Covered = $ok })
    }
}

if ($keMissingInput.Count -gt 0) {
    foreach ($m in $keMissingInput) {
        #  In -Whole the blocking Write-GateCheckSet above has already thrown
        #  on a zero count; this branch is file mode, where the arm reports.
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
        $shown = if ($k.KeMapKey -and $k.KeMapKey -ne $k.Id) { "{0} ({1})" -f $k.KeMapKey, $k.Id } else { $k.Id }
        Write-Host ("  {0} {1} -> {2}: {3} of {4} term(s) present, missing {5}   [{6}]" -f $(if ($Whole) { 'X' } else { '~' }), $shown, $where, $k.Present, @($k.Terms).Count, ($k.Missing -join ', '), $(if ($k.Text.Length -gt 70) { $k.Text.Substring(0, 70) + '...' } else { $k.Text })) -ForegroundColor $c
    }
    foreach ($k in ($keOut | Where-Object { $_.Covered -and (Get-GateCount -Value $_.Missing) -gt 0 })) {
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

# ---- arms: what each examined and what it found; a blocking arm with an
#      empty check-set is a refusal through Assert-GateArmsComplete
Write-Host ''
if ($filesRead -gt 0) { Complete-GateArm -Name 'spine-files' -State ran -Size $filesRead -Findings $emptyFiles.Count } else { Complete-GateArm -Name 'spine-files' -State empty }
$rowsExamined = 0
if ($Whole) { foreach ($g in $grids) { $rowsExamined += $g.ItemCount } }
else { foreach ($fr in $fileReports) { foreach ($go in @($fr.Grids)) { $rowsExamined += @($go.Rows).Count } } }
$rowFindings = if ($Whole) { $belowWhole.Count } else { $fileReportRows }
if ($rowsExamined -gt 0) { Complete-GateArm -Name 'row-floor' -State ran -Size $rowsExamined -Findings $rowFindings } else { Complete-GateArm -Name 'row-floor' -State empty }
if ($keEvaluated -gt 0) { Complete-GateArm -Name 'ke-coverage' -State ran -Size $keEvaluated -Findings $keBelow } else { Complete-GateArm -Name 'ke-coverage' -State empty }
if ($hollowCellsExamined -gt 0) { Complete-GateArm -Name 'hollow-relocation' -State ran -Size $hollowCellsExamined -Findings $hollow.Count } else { Complete-GateArm -Name 'hollow-relocation' -State empty }
$roster = Write-GateArmRoster
Assert-GateArmsComplete

#  THE STAMP - what Test-GridDisposition checks before it believes a number.
$fingerprint = Get-SpineFingerprint -BuildDir $BuildDir -SpineDir $SpineDir -Quiet
$report = [pscustomobject]@{
    gate = $GATE
    generated = (Get-Date).ToUniversalTime().ToString('o')
    spineFingerprint = $fingerprint
    mode = $mode
    spineFiles = @($in.Files | ForEach-Object { $_.Name })
    buildDir = $BuildDir
    spineDir = $(if ($SpineDir) { $SpineDir } else { Join-Path $BuildDir 'spine' })
    floors = [pscustomobject]@{ minTeachFile = $MinTeachFile; minTeachWhole = $MinTeachWhole; hollowShare = $HollowShare; keFrameCeiling = $KeFrameCeiling; keTermShare = $KeTermShare }
    calibration = [pscustomobject]@{ anchorWindow = $AnchorWindow; minHitWords = $MinHitWords; minHitShare = $MinHitShare; dfCeiling = $DfCeiling; aliasAmbientCeiling = $AliasAmbientCeiling }
    emptyFiles = $emptyFiles.ToArray()
    arms = @($roster)
    files = $fileReports.ToArray()
    grids = $gridSummaries.ToArray()
    belowWhole = $belowWhole.ToArray()
    ke = [pscustomobject]@{
        form = $keForm
        keMap = [pscustomobject]@{
            source = $keMapSource; count = $keIds.Count
            ids = @($keIdOrder | ForEach-Object { $keIds[$_] })
            expected = $(if ($null -ne $keAgree) { $keAgree.Expected } else { 0 })
            missing = @($(if ($null -ne $keAgree) { $keAgree.Missing } else { @() }))
            unknown = @($(if ($null -ne $keAgree) { $keAgree.Unknown } else { @() }))
        }
        extractPoints = $points.Count
        missingInput = $keMissingInput.ToArray()
        points = $keOut.ToArray()
    }
    hollow = $hollow.ToArray()
    summary = [pscustomobject]@{ files = $in.Files.Count; filesRead = $filesRead; emptyFiles = $emptyFiles.Count; rowsBelowFile = $fileReportRows; rowsBelowWhole = $belowWhole.Count; kePointsEvaluated = $keEvaluated; kePointsBelow = $keBelow; hollowCells = $hollow.Count; block = $block }
}
Write-SmJson -Object $report -Path $ReportPath

Write-Host ''
if (-not $Quiet) { Write-Host ("  report written to {0}  (stamped {1}, mode {2})" -f $ReportPath, $fingerprint, $mode) -ForegroundColor DarkGray }
if ($emptyFiles.Count -gt 0) {
    Write-Host ("  X {0} spine file(s) could not be read - a finding, not a skip: {1}" -f $emptyFiles.Count, ($emptyFiles.ToArray() -join '; ')) -ForegroundColor Red
}
if ($Whole) {
    if ($block -eq 0 -and $emptyFiles.Count -eq 0) { Write-Host '  every assessed row is taught to the floor and every KE point is covered where the map says it is' -ForegroundColor Green; exit 0 }
    if ($block -gt 0) {
        Write-Host ("  {0} BLOCK finding(s): {1} row(s) under the whole-spine teaching floor, {2} KE point(s) uncovered{3}" -f $block, $belowWhole.Count, $keBelow, $(if ($keMissingInput.Count) { ', KE inputs missing' } else { '' })) -ForegroundColor Red
        Write-Host '  Teach the row as mechanism - what happens and why - in sentences that name it. A sentence that' -ForegroundColor Yellow
        Write-Host '  answers a model bullet does not count toward this floor, by design.' -ForegroundColor Yellow
    }
    exit 1
}
if ($fileReportRows -gt 0 -or $keBelow -gt 0) { Write-Host ("  REPORT ONLY: {0} row(s) under the per-file floor, {1} KE point(s) not yet covered here - the whole-spine run at Stage 3c decides" -f $fileReportRows, $keBelow) -ForegroundColor Yellow }
else { Write-Host '  every own row reaches the per-file floor' -ForegroundColor Green }
if ($emptyFiles.Count -gt 0) { exit 1 }
exit 0

}
catch {
    #  The typed refusals - an empty blocking check-set, a keMap that
    #  disagrees with the extract, or a blocking arm that never finished - are
    #  exit 2, with the roster printed so a runner can see which arm starved.
    #  Anything else is a gate defect and is re-thrown as one.
    $m = $_.Exception.Message
    if ($m -match '^(CHECK-SET EMPTY|CHECK-SET DISAGREES|ARMS INCOMPLETE)') {
        Write-Host ("  X {0}: {1}" -f $GATE, $m) -ForegroundColor Red
        try { [void](Write-GateArmRoster) } catch { }
        exit 2
    }
    throw
}
