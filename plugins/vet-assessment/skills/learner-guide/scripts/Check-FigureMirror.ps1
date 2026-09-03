<#
    Check-FigureMirror.ps1 - does ANY table in the resource reproduce an
    assessed answer grid?

    Implements the gate the design calls Relocate-FigureGatesToSpine (mirror
    arm). Runs at Stage 3c on the spine, again before every Stage 7 re-render,
    and again at 7c against the PLACED document.

    THE DEFECT THIS LOOKS FOR. An assessment tool gives the learner a table
    with the first column already filled in and its own "write here" token in
    the rest, and asks them to complete it. A guide table that carries the SAME
    row labels with those columns filled in is the completed answer sheet - and
    where the assessment is open book and expressly permits the Learner Guide,
    the learner copies it over. That is not a styling defect. It destroys the
    assessment the resource was built to support.

    WHY IT RUNS ON THE SPINE, WHICH IS THE POINT OF THE WHOLE REDESIGN. On the
    build that produced this gate, six guide figures reproduced an assessed
    response table with the assessed columns filled in, two under the task's own
    column headings verbatim. It was found by the THIRD clean-room audit, four
    hours and twelve minutes after the content was written, because the guide
    carries artwork PROMPTS on the page until placement at the very end, so the
    two earlier audits read a document in which every figure was still a prompt
    block. Nobody had ever read the figures. The content, though, was
    machine-readable JSON on the spine from the moment it was authored. This
    script opens no .docx unless you hand it one: nothing was ever waiting on
    artwork.

    WHY IT WALKS THE WHOLE TREE. The first version scanned only the captioned
    figures' spec.rows. A remediation round withheld rows in exactly those, the
    gate went green, and the next audit found the same grids printed in full a
    hundred lines earlier in the same sub-sections, inside a worked example and
    a practical activity. The leak had been moved, not removed. Worse than the
    leak: the captioned figure said "Your turn" on rows the uncaptioned table
    beside it answered in full, so the honest signal was contradicted on the
    same page and the caption became false on its face. So every node of every
    spine file is walked and anything with rows of cells is a table, wherever
    it lives and whatever it is called - plus node- and item-shaped specs,
    because a flow node reading "Bench 1: 21 degrees C" is a filled answer row
    with an arrow drawn round it.

    IT MATCHES ON THE COLUMN HEADINGS AS WELL AS THE ROW LABELS, because row
    labels alone missed two whole classes of leak that were both found by hand
    after this gate had passed the document:
      - a grid whose rows are numbered 1, 2, 3. Labels that short are dropped
        as noise, so the task is invisible to a label match. That covered four
        workbook tasks on one build, one of which the guide answered in full.
      - a TRANSPOSED table, carrying the assessed commodity in the row label
        instead of the column. Same answers, no label match.
    A guide table printing two or more of the task's own answer-column
    headings is the answer sheet's shape whatever its rows are called, and
    when the match came from the headings every filled row counts, because the
    rows deliberately do not correspond - that is the point of a transposed or
    numbered grid.

    THE LEARNER-TEXT PARSE CLOSES A GRID PROPERLY, OR IT EATS THE REST OF THE
    DOCUMENT. The fallback parser's original terminators were only the next
    item header and the next part header. The last response grid in a workbook
    is followed by neither, so its extraction ran from line 829 to line 2800
    and collected 544 "labels" - the dietary table, the evidence matrices and
    every recipe card. Any guide table naming an ingredient then "matched" a
    transfer log, and two sub-sections were reported as leaking a task that
    asks nothing of the kind. A gate that cries wolf gets ignored, and this one
    nearly caused correct teaching to be deleted twice. So the parser closes a
    grid on a declared set of section terminators AND caps a grid at
    -MaxGridLabels: a response grid is a table, not a chapter, and a runaway
    collection is a parse failure, not a very large table.

    WITHHOLDING IS NOT SPELLED ONE WAY. The house pattern is "Your turn", but
    authors have also written "yours to complete", and some tables mark the
    withheld row in its LABEL rather than in the answer cells. Recognising only
    one spelling, or testing only the cells, made this gate report a table
    that was already correct - one worked row, two marked "yours to complete",
    and an intro that said so. And stripping the token from a cell that reads
    "Your turn: work this row from section 3.2" leaves a pointer to the
    teaching, not an answer, yet a token-strip test counted it as filled on six
    tables that were all correct. A row whose label or cells carry the
    withholding vocabulary is a withheld row. Every other cell is tested
    against the tool's own blank vocabulary, where BREVITY IS NEVER ABSENCE:
    "75 degrees C" is an answer.

    TWO COUNTING RULES FOR A HEADING MATCH, each named after the case that
    produced it, because a heading match on its own is blunt:

      Case 1 - a NUMBERED grid worked on an unassessed subject. Workbook Task
      3(b) gives the learner numbered rows and asks for the ingredients THEY
      prepared across the assessed run; the guide's worked example in 3.3 says
      outright that it is "deliberately worked on a different pair of dishes
      from the one Workbook Task 3(b) sets you" and takes celery and carrot
      across recipes the register lists as UNASSESSED for that task. That is
      the relocation rule working, not a leak - and the heading match counted
      both rows as answers. So for a numbered grid (the learner supplies the
      rows), a heading-matched row counts as an answered assessed row only when
      its SUBJECT CELLS - the label and the first non-blank content cell after
      it (one more when the guide table is itself numbered) - name one of the
      grid's "subjects" in withhold-register.json, the assessor's chosen items
      for the assessed run, folded the way the register folds them: the recipe
      number as a whole word, the name verbatim, the name's head before its
      garnish, or a 60 percent word overlap. Where the register lists no
      subjects for a numbered grid the gate falls back to counting every
      filled heading-matched row, and PRINTS that it did.

      Case 2 - a heading coincidence on the RENDERED arm. The delivered
      guide's glossary is a 72-row table headed "Term | What it means | Where
      you meet it"; Knowledge Task 5(c) is headed "Term | What it means | What
      goes wrong if you get it wrong" and assesses three terms, of which the
      glossary defines one - inside the one-exemplar allowance. Two shared
      headings made all 71 rows count. So on a rendered table a heading-only
      match must additionally have at least -MinHeadingRows rows whose label
      (or, for a numbered grid, subject cells) names one of the grid's items,
      their register aliases, or its subjects before it counts at all. Tables
      passed over under this rule are printed as heading coincidences, so the
      decision is visible.

    WHAT IS NOT A DEFECT. Sharing the row LABELS is fine - the task prints them
    itself, so the learner already has them. What makes a table the answer sheet
    is the assessed COLUMNS being filled in. One worked exemplar is allowed, and
    the allowance is counted ACROSS THE WHOLE SUB-SECTION, not per table,
    because two tables each showing "one" exemplar of the same grid is two
    answers.

    THIS GATE REPORTS THE ANCHOR AND DOES NOT DECIDE. It cannot know that a
    matched grid is a coincidence of vocabulary. A human adjudicates a hit at
    Stage 3d, on the spine, and clears it only by writing a reason into
    figures.json "mirrorAllow" beside the registry the clearance weakens - never
    by editing this script. An entry is keyed on the figure SLOT or on
    "file|grid", because the tables that caused the worst leak live at
    practicalActivity.workedExampleTable and carry no slot at all - a slot-only
    key cannot express a decision about them. The previous build held its
    allow-list as a PARAMETER DEFAULT with the reasons in a separate hashtable,
    where the audit that trusted the gate could not see it. The allow-list is
    printed on every run, so it is evidence and not a switch.

    Generic across RTOs, brands and units: every document name, every blank
    token and every allowance is read from the build, never typed here.

    PS 5.1. ASCII only in this file. Exit 1 on a hit, 2 on a usage error.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $BuildDir,
    [string] $CorpusDir,
    [string] $SpineDir,
    [string] $RulesPath,
    #  The withhold register (New-WithholdRegister.ps1): per assessed task, its
    #  kind, item aliases and - for numbered and records grids - the assessed
    #  SUBJECTS. Found beside the build when not passed. Without it the two
    #  heading-match rules fall back to counting every filled row, and say so.
    [string] $RegisterPath,
    #  Rendered artefacts to sweep as well as the spine. At 7c this is the
    #  PLACED document: placement is the last mutation of the page, and on the
    #  old pipeline it was followed by exactly one of five gates.
    [string[]] $DocxPath,
    [double] $MinOverlap = 0.6,
    [int] $MinLabels = 3,
    #  Two or more of a task's own column headings on one guide table is the
    #  heading match. One heading is a word; two is the task's shape.
    [int] $MinHeadings = 2,
    [int] $MaxWorkedPerGrid = 1,
    #  The smallest table the HEADING match examines, in data rows. The label
    #  match needs -MinLabels rows to trust a label overlap; the heading match
    #  gets its confidence from the headings, so it only needs a table that can
    #  exceed the exemplar allowance - two rows, when one exemplar is allowed.
    #  A two-row table under the task's own headings with both rows filled is
    #  two answers, and a three-row floor never looked at it.
    [int] $MinHeadingRows = 2,
    #  A response grid is a table, not a chapter. Nothing in a pack has more
    #  than a couple of dozen assessed rows, so a collection past this is a
    #  parse failure and the grid is closed rather than matched on noise.
    [int] $MaxGridLabels = 30,
    #  In the text parse, the lines between a response header and the first
    #  row label are the column headings. The first line followed by the tool's
    #  own blank token is the first row label and ends the window.
    [int] $MaxHeadingLines = 6,
    #  Section headings that END a response grid in a learner-facing text
    #  extract, whatever item or part comes next. Pack structure, not unit
    #  content: appendices, observation checklists, evidence matrices, recipe
    #  cards and the unit's own evidence headings. Extend per pack if a grid
    #  runs past its end; the -MaxGridLabels cap catches what this misses.
    [string] $GridTerminatorRx = '(?i)^(appendix\b|observation\s+\d+|assessor\b|knowledge evidence|performance evidence|foundation skills|assessment conditions|(product )?evidence matrix|dietary table|recipe cards?\b|(standard )?recipe\s+\d+|mapping\b|declaration\b|feedback\b)',
    #  The withholding vocabulary. A row whose LABEL or CELLS carry any of it
    #  is a withheld row, pointer text and all. Tested on the raw text.
    [string] $WithheldRx = '(?i)\b(your turn|yours to (complete|work|fill)|you write this|write here|left for you|complete this row|for you to complete|to be completed)\b',
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

$GATE = 'Check-FigureMirror'

function New-GridRecord {
    param([string] $Doc, [string] $Id, $Labels, $Headers, [string] $Kind)
    $lab = @($Labels | ForEach-Object { ConvertTo-GateNormal ([string]$_) } | Where-Object { $_ })
    $numbered = ($Kind -eq 'numbered') -or ($lab.Count -gt 0 -and @($lab | Where-Object { $_ -notmatch '^\d+$' }).Count -eq 0)
    return [pscustomobject]@{
        Doc = $Doc; Id = $Id; Kind = $Kind
        Labels  = $lab
        Headers = @($Headers | ForEach-Object { ConvertTo-GateNormal ([string]$_) } | Where-Object { $_ })
        Numbered    = $numbered
        Subjects    = @()      # folded subject forms from the register, numbered and records grids only
        ItemAliases = (New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal))
    }
}

#  THE REGISTER'S OWN FOLDING, kept in step with New-WithholdRegister.ps1's
#  Resolve-Subject: a recipe number is a whole-word key; the name and its head
#  (before "with ...") match verbatim; otherwise a 60 percent word overlap over
#  at least two content words. Stop words never carry a match on their own.
$script:SubjectStop = @{}
foreach ($w in @('and', 'the', 'with', 'for', 'of', 'or', 'a', 'an', 'in', 'on', 'to', 'its', 'it', 'is')) { $script:SubjectStop[$w] = $true }

function Get-SubjectWords {
    param([string] $Norm)
    return @($Norm -split ' ' | Where-Object { $_ -and $_.Length -ge 3 -and -not $script:SubjectStop.ContainsKey($_) })
}

function Get-SubjectForms {
    param([string] $Subject)
    $n = ConvertTo-GateNormal ($Subject -replace '\([^)]*\)', ' ')
    $key = ''; $name = $n
    if ($n -match '^(\d{2,6})\s+(.+)$') { $key = $Matches[1]; $name = $Matches[2] }
    $head = ($name -replace '\s+with\s+.*$', '').Trim()
    $forms = New-Object System.Collections.Generic.List[string]
    foreach ($f in @($n, $name, $head)) { $f = "$f".Trim(); if ($f -and $f.Length -ge 4 -and -not $forms.Contains($f)) { $forms.Add($f) } }
    if ($key) { foreach ($f in @("recipe $key", "standard recipe $key")) { if (-not $forms.Contains($f)) { $forms.Add($f) } } }
    return [pscustomobject]@{ Text = $Subject; Norm = $n; Key = $key; Forms = $forms.ToArray(); Words = @(Get-SubjectWords -Norm $head) }
}

function Test-SubjectMatch {
    param([string] $Text, $Subjects)
    $n = ConvertTo-GateNormal ($Text -replace '\([^)]*\)', ' ')
    if (-not $n) { return $false }
    $padded = ' ' + $n + ' '
    $words = @(Get-SubjectWords -Norm $n)
    foreach ($s in @($Subjects)) {
        if ($null -eq $s) { continue }
        if ($s.Key -and $n -match ('\b' + [regex]::Escape($s.Key) + '\b')) { return $true }
        foreach ($f in @($s.Forms)) { if ($padded.IndexOf((' ' + $f + ' '), [System.StringComparison]::Ordinal) -ge 0) { return $true } }
        if (@($s.Words).Count -ge 2 -and $words.Count -ge 2) {
            $common = @($words | Where-Object { $s.Words -contains $_ } | Select-Object -Unique)
            $minLen = [math]::Min($words.Count, @($s.Words).Count)
            if ($common.Count -ge 2 -and $common.Count -ge [math]::Ceiling(0.6 * $minLen)) { return $true }
        }
    }
    return $false
}

function Get-RowSubjectText {
    <#  The cells that say what a row is ABOUT: the label, and the first
        non-blank content cell after it - one more when the guide table is
        itself numbered, so "1 | <item> | <recipe number> ..." is read past its number.  #>
    param($Cells, [string[]] $BlankTokens)
    $c = @($Cells)
    $out = New-Object System.Collections.Generic.List[string]
    $label = [string]$c[0]
    $out.Add($label)
    $take = if ($label.Trim() -match '^\d+[.)]?$') { 2 } else { 1 }
    for ($i = 1; $i -lt $c.Count -and $take -gt 0; $i++) {
        $t = [string]$c[$i]
        if (-not (Test-GateCellFilled -Text $t -BlankTokens $BlankTokens)) { continue }
        $out.Add($t); $take--
    }
    return $out.ToArray()
}

# ---------------------------------------------------------------------------
# 1. The assessed answer grids, from the LEARNER-facing corpus
# ---------------------------------------------------------------------------

$corpusDirResolved = Get-GateCorpusDir -BuildDir $BuildDir -CorpusDir $CorpusDir
$corpus = Get-GateCorpusDocs -CorpusDir $corpusDirResolved -BuildDir $BuildDir
$blanks = Get-GateBlankTokens -BuildDir $BuildDir

if (@($corpus.Learner).Count -eq 0) {
    throw "$GATE`: the corpus at $corpusDirResolved contains no learner-facing document. Stage 1 extracts every pack document exactly once and classifies it; a mirror sweep with no learner-facing tool has nothing to mirror against and would pass by having nothing to do."
}

$grids = New-Object System.Collections.Generic.List[object]
$gridSource = 'structural parse of the learner-facing corpus'
$typedRecords = 0
$capped = New-Object System.Collections.Generic.List[string]

# Prefer Stage 1's typed parse where it exists - it identifies a response grid
# structurally (first column pre-filled, remaining cells carrying the tool's own
# blank-answer token) instead of inferring it from line shape here, and it
# carries the task's column headings, which the heading match needs.
foreach ($typedName in @('grids.json', 'assessment-data.json')) {
    $typedPath = Join-Path $corpusDirResolved $typedName
    $typed = Get-GateJson -Path $typedPath
    if ($null -eq $typed) { continue }
    $rows = @(Get-GateProp -Object $typed -Names @('grids', 'responseGrids') -Default @())
    $typedRecords = $rows.Count
    foreach ($g in $rows) {
        if ($null -eq $g) { continue }
        $labels = @(Get-GateProp -Object $g -Names @('labels', 'rowLabels') -Default @())
        $heads  = @(Get-GateProp -Object $g -Names @('headers', 'columnHeadings', 'columns', 'heads') -Default @())
        $rec = New-GridRecord -Doc ([string](Get-GateProp -Object $g -Names @('doc', 'document') -Default '')) `
                              -Id ([string](Get-GateProp -Object $g -Names @('id', 'ref', 'task') -Default 'grid')) `
                              -Labels $labels -Headers $heads `
                              -Kind ([string](Get-GateProp -Object $g -Names @('kind', 'shape') -Default ''))
        if ($rec.Labels.Count -lt $MinLabels) { continue }
        $grids.Add($rec)
    }
    if ($grids.Count -gt 0) { $gridSource = "Stage 1 typed parse ($typedName)"; break }
}

if ($grids.Count -eq 0) {
    # Fallback: parse the learner-facing text. The patterns are declared, not
    # unit-specific - an item header, a response header, a part header, and the
    # section terminators declared on -GridTerminatorRx.
    $itemRx     = '^(task|question|item|q)\s*(\d+)\b'
    $responseRx = '^(?:student|learner|candidate|your)?\s*(?:response|answer)\b'
    $partRx     = '^\(([a-z0-9]{1,3})\)\s'

    foreach ($doc in $corpus.Learner) {
        $lines = @($doc.Text -split "`r?`n")
        $curItem = ''; $curWord = 'item'; $inGrid = $false; $gridId = ''; $headRoom = 0
        $labels = New-Object System.Collections.Generic.List[string]
        $heads  = New-Object System.Collections.Generic.List[string]

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $ln = "$($lines[$i])".Trim()
            $low = $ln.ToLowerInvariant()

            #  The grid id carries the DOCUMENT'S OWN item word ("Task 5(e)"),
            #  so an allow key written against the typed parse clears the same
            #  grid when this fallback runs. A generic word here made the two
            #  parses name one grid two ways, and an anchor cleared under one
            #  name was live under the other.
            if ($ln -match ('(?i)' + $itemRx)) { $curWord = $Matches[1]; $curItem = $Matches[2] }

            #  A response header is a short structural line, not a sentence
            #  that happens to begin "Answer ...".
            if ($low -match $responseRx -and $ln.Length -le 60 -and $ln -notmatch '[.!?]$') {
                if ($inGrid -and $labels.Count -ge $MinLabels) { $grids.Add((New-GridRecord -Doc $doc.Name -Id $gridId -Labels $labels -Headers $heads -Kind 'parsed')) }
                $part = ''
                if ($ln -match '\(([a-z0-9]{1,3})\)') { $part = $Matches[1] }
                $inGrid = $true
                $gridId = if ($part) { "{0} {1} {2}({3})" -f $doc.Name, $curWord, $curItem, $part } else { "{0} {1} {2}" -f $doc.Name, $curWord, $curItem }
                $labels = New-Object System.Collections.Generic.List[string]
                $heads  = New-Object System.Collections.Generic.List[string]
                $headRoom = $MaxHeadingLines
                continue
            }

            if (-not $inGrid) { continue }

            #  CLOSE THE GRID PROPERLY - see the header. A section terminator,
            #  the cap, or the next item or part all end the grid.
            if ($ln -match $GridTerminatorRx) {
                if ($labels.Count -ge $MinLabels) { $grids.Add((New-GridRecord -Doc $doc.Name -Id $gridId -Labels $labels -Headers $heads -Kind 'parsed')) }
                $inGrid = $false
                continue
            }
            if ($labels.Count -ge $MaxGridLabels) {
                $grids.Add((New-GridRecord -Doc $doc.Name -Id $gridId -Labels $labels -Headers $heads -Kind 'parsed'))
                $capped.Add($gridId)
                $inGrid = $false
                continue
            }
            if ($low -match $itemRx -or $low -match $partRx) {
                if ($labels.Count -ge $MinLabels) { $grids.Add((New-GridRecord -Doc $doc.Name -Id $gridId -Labels $labels -Headers $heads -Kind 'parsed')) }
                $inGrid = $false
                continue
            }

            if (-not $ln) { continue }
            if (-not (Test-GateCellFilled -Text $ln -BlankTokens $blanks)) { continue }   # the tool's own blank token
            $n = ConvertTo-GateNormal $ln
            if (-not $n -or $n.Length -gt 90) { continue }

            #  The lines between the response header and the first row label
            #  are the column headings. A row label is the one followed by the
            #  tool's own blank token.
            $nextIsBlank = $false
            for ($k = $i + 1; $k -lt $lines.Count; $k++) {
                $nx = "$($lines[$k])".Trim()
                if (-not $nx) { continue }
                $nextIsBlank = -not (Test-GateCellFilled -Text $nx -BlankTokens $blanks)
                break
            }
            if ($headRoom -gt 0 -and -not $nextIsBlank) {
                if (-not $heads.Contains($n)) { $heads.Add($n) }
                $headRoom--
                continue
            }
            $headRoom = 0

            #  Row labels shorter than 3 characters are noise as a MATCH KEY -
            #  "1", "2", "3" would match every numbered table in the guide. They
            #  are kept out of the label set for that reason, and the heading
            #  match is what covers those grids instead.
            if ($n.Length -lt 3) { continue }
            if (-not $labels.Contains($n)) { $labels.Add($n) }
        }
        if ($inGrid -and $labels.Count -ge $MinLabels) { $grids.Add((New-GridRecord -Doc $doc.Name -Id $gridId -Labels $labels -Headers $heads -Kind 'parsed')) }
    }
}

# ---- the withhold register: item aliases, and the assessed SUBJECTS of every
#      numbered and records grid, keyed on the same grid id the corpus uses
if (-not $RegisterPath) {
    foreach ($cand in @((Join-Path $BuildDir 'withhold-register.json'), (Join-Path $corpusDirResolved 'withhold-register.json'))) {
        if (Test-Path -LiteralPath $cand) { $RegisterPath = $cand; break }
    }
}
$register = $null
if ($RegisterPath -and (Test-Path -LiteralPath $RegisterPath)) { $register = Get-GateJson -Path $RegisterPath }
$regTasks = @{}
if ($null -ne $register -and @($register.PSObject.Properties.Name) -contains 'subSections' -and $null -ne $register.subSections) {
    foreach ($ssp in $register.subSections.PSObject.Properties) {
        if ($ssp.Name -like '_*' -or $null -eq $ssp.Value) { continue }
        foreach ($tk in @(Get-GateProp -Object $ssp.Value -Names @('tasks') -Default @())) {
            if ($null -eq $tk) { continue }
            $id = [string](Get-GateProp -Object $tk -Names @('id') -Default '')
            if (-not $id) { continue }
            $aliasSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
            $al = Get-GateProp -Object $tk -Names @('aliases')
            if ($null -ne $al -and $al.PSObject) {
                foreach ($ap in $al.PSObject.Properties) { foreach ($a in @($ap.Value)) { $an = ConvertTo-GateNormal ([string]$a); if ($an) { [void]$aliasSet.Add($an) } } }
            }
            $regTasks[$id] = [pscustomobject]@{
                Kind        = [string](Get-GateProp -Object $tk -Names @('kind') -Default '')
                Subjects    = @(@(Get-GateProp -Object $tk -Names @('subjects') -Default @()) | Where-Object { "$_".Trim() } | ForEach-Object { Get-SubjectForms -Subject ([string]$_) })
                ItemAliases = $aliasSet
            }
        }
    }
}
$gridsWithSubjects = 0
foreach ($g in $grids) {
    if (-not $regTasks.ContainsKey($g.Id)) { continue }
    $rt = $regTasks[$g.Id]
    if ($rt.Kind -eq 'numbered') { $g.Numbered = $true }
    $g.Subjects = @($rt.Subjects)
    $g.ItemAliases = $rt.ItemAliases
    if (@($g.Subjects).Count -gt 0) { $gridsWithSubjects++ }
}

if (-not $Quiet) {
    Write-Host ''
    Write-Host 'TABLE / ANSWER-GRID MIRROR SWEEP' -ForegroundColor Cyan
    Write-Host ("  corpus: {0}  ({1} learner-facing, {2} assessor-only, classified from the {3})" -f `
        (Split-Path $corpusDirResolved -Leaf), @($corpus.Learner).Count, @($corpus.Assessor).Count, $corpus.ClassifiedFrom) -ForegroundColor DarkGray
    Write-GateCheckSet -What 'assessed answer grids' -Count $grids.Count -DerivedFrom $gridSource
    if ($typedRecords -gt 0) { Write-Host ("  typed records loaded one by one on their full id: {0}; {1} kept with at least {2} label(s)" -f $typedRecords, $grids.Count, $MinLabels) -ForegroundColor DarkGray }
    $withHeads = @($grids | Where-Object { @($_.Headers).Count -ge $MinHeadings }).Count
    Write-Host ("  of which {0} carry column headings for the heading match; largest grid {1} label(s), cap {2}" -f $withHeads, (@($grids | ForEach-Object { @($_.Labels).Count } | Measure-Object -Maximum).Maximum), $MaxGridLabels) -ForegroundColor DarkGray
    foreach ($c in $capped) { Write-Host ("  ! grid {0} hit the {1}-label cap and was closed there - its section terminator is not declared; check -GridTerminatorRx" -f $c, $MaxGridLabels) -ForegroundColor Yellow }
    $numberedCount = @($grids | Where-Object { $_.Numbered }).Count
    if ($regTasks.Count -gt 0) {
        Write-Host ("  register: {0} assessed task(s) from {1}; {2} numbered grid(s), {3} grid(s) carry assessed subjects for the heading-match rules" -f $regTasks.Count, (Split-Path $RegisterPath -Leaf), $numberedCount, $gridsWithSubjects) -ForegroundColor DarkGray
    }
    else {
        Write-Host ("  register: no withhold-register.json beside the build - {0} numbered grid(s) will be counted on every filled heading-matched row (no subjects to judge them by)" -f $numberedCount) -ForegroundColor Yellow
    }
}

if ($grids.Count -eq 0) {
    Write-Host ("  X {0}: no assessed response grid could be identified in the learner-facing corpus." -f $GATE) -ForegroundColor Red
    Write-Host '    A sweep with an empty check-set passes by having nothing to check, which is the failure mode this whole gate band exists to end.' -ForegroundColor Red
    exit 2
}

# ---------------------------------------------------------------------------
# 2. Every table, anywhere on the spine - and in any rendered file handed in
# ---------------------------------------------------------------------------

$tables = New-Object System.Collections.Generic.List[object]

foreach ($f in (Get-GateSpineFiles -BuildDir $BuildDir -SpineDir $SpineDir)) {
    $j = Get-GateJson -Path $f.FullName
    if ($null -eq $j) { continue }
    foreach ($t in (Get-GateSpineTables -Node $j -File $f.Name -Path '' -Slot '')) { $tables.Add($t) }
}
$spineTables = $tables.Count

function Get-DocxTable {
    <#  Tables out of a rendered .docx, straight from the zip, read-only.

        The 7c arm. A spine check and a rendered check are not redundant: they
        make different claims, and placement has been observed to change what
        is on the page with no spine change at all.

        The renderer puts a table's headings in its first row, so that row is
        offered to the heading match. It is still row 0 of the data (Skip = 0):
        the compare loop leaves it out of a heading-only count by recognising
        it as the table's own heading row, and a label match never counts it
        because a heading is not a row label.  #>
    param([Parameter(Mandatory)][string] $Path)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Path).Path)
    try {
        $entry = $zip.Entries | Where-Object { $_.FullName -eq 'word/document.xml' }
        if (-not $entry) { return }
        $sr = New-Object System.IO.StreamReader($entry.Open())
        $xml = $sr.ReadToEnd()
        $sr.Dispose()
    }
    finally { $zip.Dispose() }

    $leaf = Split-Path $Path -Leaf
    $i = 0
    foreach ($tbl in [regex]::Matches($xml, '<w:tbl>.*?</w:tbl>', 'Singleline')) {
        $i++
        $rows = New-Object System.Collections.Generic.List[object]
        foreach ($tr in [regex]::Matches($tbl.Value, '<w:tr\b.*?</w:tr>', 'Singleline')) {
            $cells = New-Object System.Collections.Generic.List[string]
            foreach ($tc in [regex]::Matches($tr.Value, '<w:tc>.*?</w:tc>', 'Singleline')) {
                $txt = -join ([regex]::Matches($tc.Value, '<w:t[^>]*>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value })
                $cells.Add([System.Net.WebUtility]::HtmlDecode($txt).Trim())
            }
            if ($cells.Count -gt 0) { $rows.Add($cells.ToArray()) }
        }
        if ($rows.Count -gt 0) {
            $headers = @()
            if ($rows.Count -ge 2) { $headers = @($rows[0]) }
            [pscustomobject]@{
                File = $leaf; Path = ("table[{0}]" -f $i); Slot = ''; Shape = 'rendered'
                Rows = $rows.ToArray(); Skip = 0; Headers = $headers
            }
        }
    }
}

foreach ($d in @($DocxPath)) {
    if (-not $d) { continue }
    if (-not (Test-Path -LiteralPath $d)) { throw "$GATE`: -DocxPath does not exist: $d" }
    foreach ($t in (Get-DocxTable -Path $d)) { $tables.Add($t) }
}

if (-not $Quiet) {
    Write-Host ("  tables examined: {0} on the spine" -f $spineTables) -ForegroundColor DarkGray
    $rendered = @($DocxPath | Where-Object { $_ })
    if ($rendered.Count -gt 0) {
        Write-Host ("                   {0} more in {1} rendered file(s): {2}" -f ($tables.Count - $spineTables), $rendered.Count, (($rendered | ForEach-Object { Split-Path $_ -Leaf }) -join ', ')) -ForegroundColor DarkGray
    }
}

# ---------------------------------------------------------------------------
# 3. Compare, accumulating answered rows per (file, grid)
# ---------------------------------------------------------------------------

$acc = @{}
$coincidences = New-Object System.Collections.Generic.List[string]   # rendered heading-only matches passed over under case 2
$subjectFallback = @{}                                                 # numbered grids counted on every row because the register names no subjects
foreach ($t in $tables) {
    $rows = @($t.Rows)
    #  this table's own column headings, for the heading match
    $myHeads = @(@($t.Headers) | ForEach-Object { ConvertTo-GateNormal ([string]$_) } | Where-Object { $_ })

    $figLabels = @()
    $dataRows = 0
    for ($r = $t.Skip; $r -lt $rows.Count; $r++) {
        $cells = @($rows[$r])
        $c = $cells[0]
        $labelN = if ($null -ne $c) { ConvertTo-GateNormal ([string]$c) } else { '' }
        #  A rendered table offers its first row as headings and keeps it as
        #  row 0; it is not a data row, and must not lift a two-row table over
        #  the heading floor on its own.
        if ($cells.Count -ge 2 -and -not ($myHeads -contains $labelN)) { $dataRows++ }
        if ($labelN) { $figLabels += $labelN }
    }
    $uniq = @($figLabels | Where-Object { $_ -and $_.Length -ge 3 } | Select-Object -Unique)

    $labelEligible = ($uniq.Count -ge $MinLabels)
    $headEligible  = ($myHeads.Count -ge $MinHeadings -and $dataRows -ge $MinHeadingRows)
    if (-not $labelEligible -and -not $headEligible) { continue }

    foreach ($g in $grids) {
        $byLabel = $false
        if ($labelEligible) {
            $hit = @($uniq | Where-Object { $g.Labels -contains $_ })
            if ($hit.Count -ge $MinLabels) {
                $ov = $hit.Count / [double]([math]::Min($uniq.Count, @($g.Labels).Count))
                $byLabel = ($ov -ge $MinOverlap)
            }
        }

        #  THE HEADING MATCH - see the header. Two or more of the task's own
        #  column headings reproduced on a guide table is the answer sheet's
        #  shape, whatever the rows are called.
        $byHead = $false
        if ($headEligible -and @($g.Headers).Count -ge $MinHeadings) {
            $headHit = @($myHeads | Where-Object { $g.Headers -contains $_ })
            $byHead = ($headHit.Count -ge $MinHeadings)
        }

        if (-not $byLabel -and -not $byHead) { continue }
        $headOnly = ($byHead -and -not $byLabel)

        #  CASE 2 - see the header. A heading-only match on a RENDERED table
        #  must name the grid's items (or aliases, or subjects) on at least
        #  -MinHeadingRows rows before it counts at all.
        if ($headOnly -and $t.Shape -eq 'rendered') {
            $named = 0
            for ($r = $t.Skip; $r -lt $rows.Count; $r++) {
                $cells = @($rows[$r])
                if ($cells.Count -lt 2) { continue }
                $ln0 = ConvertTo-GateNormal ([string]$cells[0])
                if (-not $ln0 -or ($myHeads -contains $ln0)) { continue }
                $names = ($g.Labels -contains $ln0) -or $g.ItemAliases.Contains($ln0)
                if (-not $names -and @($g.Subjects).Count -gt 0) {
                    foreach ($st in (Get-RowSubjectText -Cells $cells -BlankTokens $blanks)) { if (Test-SubjectMatch -Text $st -Subjects $g.Subjects) { $names = $true; break } }
                }
                if ($names) { $named++ }
            }
            if ($named -lt $MinHeadingRows) {
                $coincidences.Add(("{0} {1} shares {2} heading(s) with {3} but only {4} row(s) name its items or subjects (needs {5})" -f $t.File, $t.Path, @($myHeads | Where-Object { $g.Headers -contains $_ }).Count, $g.Id, $named, $MinHeadingRows))
                continue
            }
        }

        $filled = 0
        $unassessed = 0
        $sample = ''
        $sigs = New-Object System.Collections.Generic.List[string]   # each answered row, normalised, for the rendered-copy test
        for ($r = $t.Skip; $r -lt $rows.Count; $r++) {
            $cells = @($rows[$r])
            if ($cells.Count -lt 2) { continue }
            $label = [string]$cells[0]
            $labelN = ConvertTo-GateNormal $label
            #  When the match came from the ROW LABELS, only assessed rows
            #  count. When it came from the COLUMN HEADINGS the rows
            #  deliberately do not correspond, so every filled row counts -
            #  except the table's own heading row, which is not an answer.
            if ($byLabel) {
                if (-not ($g.Labels -contains $labelN)) { continue }
            }
            elseif ($myHeads -contains $labelN) { continue }
            #  WITHHOLDING IS NOT SPELLED ONE WAY - see the header. Label first,
            #  then the cells.
            if ($label -match $WithheldRx) { continue }
            $rest = ($cells[1..($cells.Count - 1)] -join ' ')
            if ($rest -match $WithheldRx) { continue }
            #  FILLED IS NON-EMPTY AGAINST THE TOOL'S OWN BLANK VOCABULARY, not a
            #  character count. The shipped gate treated 20 characters or fewer as
            #  blank, so "75 degrees C", "2 hours" and "Yes" - the exact answers
            #  worth copying - all read as withheld.
            if (-not (Test-GateCellFilled -Text $rest -BlankTokens $blanks)) { continue }
            #  CASE 1 - see the header. On a NUMBERED grid a heading-matched
            #  row is an answered assessed row only when its subject cells
            #  name one of the register's assessed subjects. No subjects in
            #  the register: every filled row counts, and that is printed.
            if ($headOnly -and $g.Numbered) {
                if (@($g.Subjects).Count -gt 0) {
                    $about = $false
                    foreach ($st in (Get-RowSubjectText -Cells $cells -BlankTokens $blanks)) { if (Test-SubjectMatch -Text $st -Subjects $g.Subjects) { $about = $true; break } }
                    if (-not $about) { $unassessed++; continue }
                }
                else { $subjectFallback[$g.Id] = $true }
            }
            $filled++
            $sigs.Add(("{0}|{1}" -f $labelN, (ConvertTo-GateNormal $rest)))
            if (-not $sample) { $sample = ("{0} -> {1}" -f $label, $rest) }
        }

        $key = "{0}|{1}" -f $t.File, $g.Id
        if (-not $acc.ContainsKey($key)) {
            $acc[$key] = [pscustomobject]@{
                File = $t.File; Grid = $g.Id; Filled = 0
                Rendered = ($t.Shape -eq 'rendered')
                Where  = New-Object System.Collections.Generic.List[string]
                Slots  = New-Object System.Collections.Generic.List[string]
                How    = New-Object System.Collections.Generic.List[string]
                Rows   = New-Object System.Collections.Generic.List[string]
                Sample = ''
            }
        }
        $acc[$key].Filled += $filled
        foreach ($s in $sigs) { $acc[$key].Rows.Add($s) }
        if ($filled -gt 0) {
            $anchor = if ($t.Path) { $t.Path } else { '<root>' }
            $how = if ($byLabel -and $byHead) { 'row labels and column headings' } elseif ($byLabel) { 'row labels' } else { 'column headings' }
            $unNote = if ($unassessed -gt 0) { "; {0} row(s) about unassessed subjects not counted" -f $unassessed } else { '' }
            $acc[$key].Where.Add(("{0} ({1} assessed row(s) answered; matched on {2}{3})" -f $anchor, $filled, $how, $unNote))
            if (-not $acc[$key].How.Contains($how)) { $acc[$key].How.Add($how) }
            if ($t.Slot -and -not $acc[$key].Slots.Contains([string]$t.Slot)) { $acc[$key].Slots.Add([string]$t.Slot) }
            if (-not $acc[$key].Sample) { $acc[$key].Sample = $sample }
        }
    }
}

# ---------------------------------------------------------------------------
# 4. Report the anchors. A human clears a hit at 3d, in figures.json.
# ---------------------------------------------------------------------------

$registry = Get-GateRegistry -BuildDir $BuildDir -RulesPath $RulesPath
$allow = Get-GateAllowList -Registry $registry -Key 'mirrorAllow' -IdField @('slot', 'id', 'key', 'figure', 'grid') -GateName $GATE

if (-not $Quiet) {
    Write-Host ''
    if ($allow.Count -gt 0) {
        Write-Host ("  allow-list, from figures.json mirrorAllow - {0} entr(ies), keyed on figure slot or file|grid, surfaced to the audit as evidence:" -f $allow.Count) -ForegroundColor DarkGray
        foreach ($k in ($allow.Keys | Sort-Object)) {
            Write-Host ("    {0}: {1}" -f $k, $allow[$k]) -ForegroundColor DarkGray
        }
    }
    else {
        Write-Host '  allow-list, from figures.json mirrorAllow: empty - nothing is cleared' -ForegroundColor DarkGray
    }
    if ($subjectFallback.Count -gt 0) {
        Write-Host ("  ! numbered grid(s) counted on every filled heading-matched row because the register names no subjects for them: {0}" -f (($subjectFallback.Keys | Sort-Object) -join '; ')) -ForegroundColor Yellow
    }
    if ($coincidences.Count -gt 0) {
        Write-Host ("  heading coincidences passed over on the rendered arm ({0}) - shared headings, but the rows do not name the grid's items or subjects:" -f $coincidences.Count) -ForegroundColor DarkGray
        foreach ($c in $coincidences) { Write-Host ("    - {0}" -f $c) -ForegroundColor DarkGray }
    }
}

$found = 0
#  Spine pairs are judged first, then rendered ones, because a RENDERED COPY
#  of a cleared spine table is the same table: when every answered row of the
#  rendered pair is an answered row of a cleared spine pair on the same grid,
#  the clearance carries, and says so. A rendered pair with a row the spine
#  never cleared stays live - that is the 7c claim, that placement changed the
#  page.
$clearedRows = @{}   # grid id -> hashset of answered-row signatures cleared on the spine, and the key that cleared them
$ordered = @($acc.Keys | Sort-Object | Where-Object { -not $acc[$_].Rendered }) + @($acc.Keys | Sort-Object | Where-Object { $acc[$_].Rendered })
foreach ($k in $ordered) {
    $a = $acc[$k]
    if ($a.Filled -le $MaxWorkedPerGrid) { continue }

    $cleared = $null; $clearedBy = ''
    foreach ($s in $a.Slots) { if ($allow.ContainsKey($s)) { $cleared = $allow[$s]; $clearedBy = "slot $s" } }
    $fileKey = "{0}|{1}" -f $a.File, $a.Grid
    if ($allow.ContainsKey($fileKey)) { $cleared = $allow[$fileKey]; $clearedBy = $fileKey }
    if ($null -eq $cleared -and $a.Rendered -and $clearedRows.ContainsKey($a.Grid) -and $a.Rows.Count -gt 0) {
        $set = $clearedRows[$a.Grid]
        $missing = @($a.Rows | Where-Object { -not $set.Rows.Contains($_) })
        if ($missing.Count -eq 0) { $cleared = $set.Why; $clearedBy = ("the rendered copy of {0}" -f $set.Key) }
    }
    if ($null -ne $cleared) {
        if (-not $a.Rendered) {
            if (-not $clearedRows.ContainsKey($a.Grid)) { $clearedRows[$a.Grid] = [pscustomobject]@{ Key = $clearedBy; Why = $cleared; Rows = (New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)) } }
            foreach ($s in $a.Rows) { [void]$clearedRows[$a.Grid].Rows.Add($s) }
        }
        if (-not $Quiet) {
            Write-Host ''
            Write-Host ("  ok {0} vs {1} - {2} assessed row(s) answered, cleared at Stage 3d on {3}: {4}" -f $a.File, $a.Grid, $a.Filled, $clearedBy, $cleared) -ForegroundColor DarkGray
        }
        continue
    }

    $found++
    Write-Host ''
    Write-Host ("  X {0}{1}" -f $a.File, $(if ($a.Rendered) { '  (rendered table - the placed document)' } else { '' })) -ForegroundColor Red
    Write-Host ("     reproduces {0}  (matched on {1})" -f $a.Grid, ($a.How -join '; ')) -ForegroundColor Yellow
    Write-Host ("     {0} assessed row(s) answered across this sub-section (limit {1}: one worked exemplar)" -f $a.Filled, $MaxWorkedPerGrid) -ForegroundColor Red
    foreach ($w in $a.Where) { Write-Host ("       at {0}" -f $w) -ForegroundColor DarkGray }
    if ($a.Sample) { Write-Host ("       for instance: {0}" -f $a.Sample) -ForegroundColor DarkGray }
    if ($a.Slots.Count) { Write-Host ("       figure slot(s): {0}" -f ($a.Slots -join ', ')) -ForegroundColor DarkGray }
    Write-Host ("       allow key if cleared by reading the task: {0}" -f $fileKey) -ForegroundColor DarkGray
}

Write-Host ''
if ($found -eq 0) {
    Write-Host '  no table reproduces an assessed answer grid beyond one worked exemplar' -ForegroundColor Green
    exit 0
}

Write-Host ("  {0} sub-section/grid pair(s) over the limit" -f $found) -ForegroundColor Red
Write-Host '  This gate reports the anchor and does not decide. Adjudicate each hit at Stage 3d by' -ForegroundColor Yellow
Write-Host '  reading the assessed task: either withhold the answered columns on the spine, or clear' -ForegroundColor Yellow
Write-Host '  the slot or the file|grid key in figures.json "mirrorAllow" with a written reason.' -ForegroundColor Yellow
Write-Host '  Never by editing this gate.' -ForegroundColor Yellow
exit 1
