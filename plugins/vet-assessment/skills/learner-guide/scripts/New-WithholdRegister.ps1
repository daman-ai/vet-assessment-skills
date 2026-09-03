<#
    New-WithholdRegister.ps1 - derive what a content agent may be told about
    every assessed grid, and what it must never be told, from the pack's own
    typed task data. Runs at Stage 1, before any content agent exists.

    THE FAILURE THIS EXISTS TO END. On the build that produced this script,
    seven content agents were handed the assessor guides "for one purpose only,
    to gauge depth". Every one of them wrote the model answers into the Learner
    Guide - same items, same order, same words - and the guide is expressly
    permitted in an open-book assessment, so the completed answer sheet was on
    the learner's desk. Six clean-room audit rounds then found that leak one
    location at a time: the figures, then a worked example a hundred lines
    earlier, then a practical activity, then the deck, then the speaker notes.
    An answer that is read is an answer that gets written. The only fix that
    holds is upstream: the agent never holds the answer.

    WHAT AN AGENT RECEIVES INSTEAD, AND WHY EVERY FIELD IS A DERIVATION.
    Depth used to come from reading the model row. It now comes from the SHAPE
    of the assessed grid - rows, assessed columns, bullets per cell, word guide,
    benchmark minimum - every one a number computed from itemTable and the
    task's own word guide, never typed and never quoting a cell. Where an
    example must be worked, the agent is handed the pack's subject vocabulary
    for that grid's class MINUS the assessed subjects, so a worked example
    lands on a dish, machine or document the task does not ask about. A
    hand-typed version of any of this is a second source of truth, and a
    second source of truth is free to drift; so every list here is derived
    from files that already exist - the typed task JSON, the build contract's
    questionMap, the learner-facing corpus, the recipe cards, the unit extract.

    FOUR OUTPUTS, TWO AUDIENCES.
      corpus\grids.json          the assessed grids in the shape the existing
                                 mirror gate (Check-FigureMirror) already
                                 prefers over its regex fallback. Writing it
                                 upgrades that gate for free. It is written
                                 into the corpus directory the gates RESOLVE,
                                 because that is where the gate looks for it.
      withhold-register.json     agent-safe. Shapes, labels, aliases, subjects,
                                 permitted ground. No cell text from any model
                                 row appears in it, and the script proves that
                                 by sweeping the written file before it exits.
      assessor-cells.json        GATE-ONLY. The model bullets with precomputed
                                 content-word sets, so a leakage gate can match
                                 an answer written in the author's own words.
                                 Never given to a content agent.
      agent-pack\<sub-section>\  what an agent is handed: the contract, the
                                 learner-facing task text, its slice of the
                                 register, and a README saying what is absent
                                 and why. Nothing under agent-pack is assessor
                                 content, and the same sweep proves it.

    WHAT CANNOT BE DERIVED IS SAID, NOT GUESSED. A grid whose kind, columns or
    rows do not follow from the data goes to an "unclassified" list with the
    reason, for a human to adjudicate. A silent default here would be a guess
    dressed as a derivation.

    Generic across RTOs, brands and units: every document name, reference
    pattern, recipe, equipment item and workplace document is read from the
    build or the pack, never typed here.

    PS 5.1. ASCII only in this file. Exit 0 when the register is written and
    the sweeps pass, 1 when a sweep finds assessor text in an agent-facing file,
    2 on a usage error.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $BuildDir,
    #  The assessment pack build. Discovered from contract.json build.packDir
    #  when omitted.
    [string] $PackDir,
    #  Where the typed task files live. Default <PackDir>\content.
    [string] $ContentDir,
    #  The canonical corpus of pack text. Resolved exactly as every gate
    #  resolves it (Lib-GateCommon Get-GateCorpusDir) when omitted.
    [string] $CorpusDir,
    #  The verbatim unit extract, for the equipment vocabulary. Default
    #  <BuildDir>\unit_extract.md, then the first *unit_extract.md in the pack.
    [string] $UnitExtract,
    #  Document frequency above which a word is too common to identify an
    #  answer, as a fraction of all model bullets.
    [double] $DfCeiling = 0.25,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

$SCRIPT_NAME = 'New-WithholdRegister'

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

function Get-Count {
    <# @($null).Count is 1. Null-check first, always. #>
    param($x)
    if ($null -eq $x) { return 0 }
    if ($x -is [string]) { return 1 }
    if ($x -is [System.Collections.IEnumerable]) { return @($x).Count }
    return 1
}

function AsArr { param($x) if ($null -eq $x) { return @() } return @($x) }

function Get-PropList {
    <#  A list-valued property through the shared resolver, on ONE return
        convention: plain return here, @() at every call site. A single
        element unrolls and the call site re-wraps it; ,@() here plus @()
        there nests, and the nested array is the element nobody can read.
        (Lib-GateCommon's Get-GateProp once read an array of objects as
        absent; it now tests a collection by Count, so this is a convention
        wrapper, not a workaround.)  #>
    param($Object, [string[]] $Names)
    if ($null -eq $Object) { return @() }
    $v = Get-GateProp -Object $Object -Names $Names -Default $null
    if ($null -eq $v) { return @() }
    return @($v)
}

function Get-PropObj {
    <# An object-valued property through the shared resolver, or $null. #>
    param($Object, [string[]] $Names)
    if ($null -eq $Object) { return $null }
    return (Get-GateProp -Object $Object -Names $Names -Default $null)
}

function Say {
    param([string] $Text, [string] $Colour = 'Gray')
    if (-not $Quiet) { Write-Host $Text -ForegroundColor $Colour }
}

function Get-ScriptPath {
    <# Where this script lives, for provenance lines in the outputs. #>
    return $PSCommandPath
}

function ConvertTo-AsciiText {
    <#  Transliterate the handful of typographic characters a Word extract
        carries. The characters are written as code points because this file
        is ASCII and PS 5.1 reads a BOM-less .ps1 as ANSI.  #>
    param([string] $Text)
    if ($null -eq $Text) { return '' }
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $Text.ToCharArray()) {
        $code = [int]$ch
        if ($code -lt 128) { [void]$sb.Append($ch); continue }
        switch ($code) {
            0x2018 { [void]$sb.Append("'") }
            0x2019 { [void]$sb.Append("'") }
            0x02BC { [void]$sb.Append("'") }
            0x201C { [void]$sb.Append('"') }
            0x201D { [void]$sb.Append('"') }
            0x2026 { [void]$sb.Append('...') }
            0x00A0 { [void]$sb.Append(' ') }
            0x00D7 { [void]$sb.Append('x') }
            0x00B0 { [void]$sb.Append(' degrees ') }
            0x2022 { [void]$sb.Append('-') }
            0x00B7 { [void]$sb.Append('-') }
            0x2610 { [void]$sb.Append('[ ]') }
            0x2612 { [void]$sb.Append('[x]') }
            0x2611 { [void]$sb.Append('[x]') }
            0x25A1 { [void]$sb.Append('[ ]') }
            0x2264 { [void]$sb.Append('<=') }
            0x2265 { [void]$sb.Append('>=') }
            0x2192 { [void]$sb.Append('->') }
            0x00BD { [void]$sb.Append('1/2') }
            0x00BC { [void]$sb.Append('1/4') }
            0x00BE { [void]$sb.Append('3/4') }
            0x00B1 { [void]$sb.Append('+/-') }
            0x00E9 { [void]$sb.Append('e') }
            0x00E8 { [void]$sb.Append('e') }
            0x00EA { [void]$sb.Append('e') }
            0x00E0 { [void]$sb.Append('a') }
            0x00E2 { [void]$sb.Append('a') }
            0x00E7 { [void]$sb.Append('c') }
            0x00F1 { [void]$sb.Append('n') }
            0x00FC { [void]$sb.Append('u') }
            0x00F6 { [void]$sb.Append('o') }
            0x00E4 { [void]$sb.Append('a') }
            default {
                if ($code -ge 0x2010 -and $code -le 0x2015) { [void]$sb.Append('-') }
                else { [void]$sb.Append('?'); $script:asciiLossCount++ }
            }
        }
    }
    return $sb.ToString()
}
$script:asciiLossCount = 0

function Write-AsciiJson {
    <#  ASCII JSON, always. Every non-ASCII character is written as a \uXXXX
        escape, which every JSON reader accepts, so the file never depends on
        the encoding a later reader guesses.  #>
    param([Parameter(Mandatory)] $Object, [Parameter(Mandatory)][string] $Path)
    $json = ConvertTo-Json -InputObject $Object -Depth 30
    $json = [regex]::Replace($json, '[^\x00-\x7F]', [System.Text.RegularExpressions.MatchEvaluator]{
        param($m) ('\u{0:x4}' -f [int][char]$m.Value)
    })
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.Encoding]::ASCII)
}

function Write-AsciiText {
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Text, [Parameter(Mandatory)][string] $Path)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($Path, (ConvertTo-AsciiText $Text), [System.Text.Encoding]::ASCII)
}

function ConvertFrom-JsonEscape {
    <#  ConvertTo-Json writes an apostrophe as \u0027, so a swept JSON file
        must be unescaped before it is normalised, or "today's trays" hides
        behind "today\u0027s trays" and a sweep reports it absent.  #>
    param([string] $Text)
    if (-not $Text) { return '' }
    return [regex]::Replace($Text, '\\u([0-9a-fA-F]{4})', [System.Text.RegularExpressions.MatchEvaluator]{
        param($m) [string][char][Convert]::ToInt32($m.Groups[1].Value, 16)
    })
}

function Test-Verbatim {
    <# Whole-phrase, whole-word containment of one normalised string in another. #>
    param([string] $NeedleNorm, [string] $HayNorm)
    if (-not $NeedleNorm -or -not $HayNorm) { return $false }
    return (' ' + $HayNorm + ' ').Contains(' ' + $NeedleNorm + ' ')
}

# ---------------------------------------------------------------------------
# Words: stopwords, stemming, content-word sets
# ---------------------------------------------------------------------------

#  ~150 function words. Domain words are NOT here on purpose: a word that is
#  common in this pack is removed by the document-frequency ceiling, which is
#  derived from the bullets themselves, not typed.
$STOPWORDS = @(
    'a','about','above','after','again','against','all','also','am','an','and','any','are','as','at',
    'be','because','been','before','being','below','between','both','but','by',
    'can','cannot','could','did','do','does','doing','down','during',
    'each','either','else','ever','every','few','for','from','further',
    'had','has','have','having','he','her','here','hers','him','his','how',
    'i','if','in','into','is','it','its','itself','just',
    'let','may','me','might','more','most','much','must','my','myself',
    'neither','never','no','nor','not','now','of','off','on','once','one','only','onto','or','other','ought','our','ours','out','over','own',
    'per','rather','same','shall','she','should','so','some','still','such',
    'than','that','the','their','theirs','them','then','there','these','they','this','those','through','to','too','toward','towards',
    'under','until','up','upon','us','use','used','using','very','via',
    'was','we','were','what','when','where','whether','which','while','who','whom','whose','why','will','with','within','without','would',
    'yes','yet','you','your','yours','yourself',
    'across','along','among','around','away','back','get','gets','got','give','given','go','goes','keep','make','makes','made','put','take','takes','taken'
)

function Get-Stem {
    <# Crude suffix stem: trailing ing / ed / es / s. Applied to BOTH sides
       of every comparison, so it only has to be consistent, not correct. #>
    param([string] $Word)
    $w = $Word
    if ($w.Length -gt 5 -and $w.EndsWith('ing')) { return $w.Substring(0, $w.Length - 3) }
    if ($w.Length -gt 4 -and $w.EndsWith('ed'))  { return $w.Substring(0, $w.Length - 2) }
    if ($w.Length -gt 4 -and $w -match '(ss|sh|ch|x|z)es$') { return $w.Substring(0, $w.Length - 2) }
    if ($w.Length -gt 3 -and $w.EndsWith('s') -and -not $w.EndsWith('ss')) { return $w.Substring(0, $w.Length - 1) }
    return $w
}

$script:StopSet = @{}
foreach ($sw in $STOPWORDS) { $script:StopSet[(Get-Stem $sw)] = $true; $script:StopSet[$sw] = $true }

function Get-Words {
    <# Normalised, stemmed tokens of a string, stopwords removed. #>
    param([string] $Text, [switch] $KeepNumbers)
    $out = New-Object System.Collections.Generic.List[string]
    if (-not $Text) { return $out }
    foreach ($tok in ((ConvertTo-GateNormal $Text) -split ' ')) {
        if (-not $tok -or $tok.Length -lt 2) { continue }
        if (-not $KeepNumbers -and $tok -match '^\d+$') { continue }
        $s = Get-Stem $tok
        if ($script:StopSet.ContainsKey($s) -or $script:StopSet.ContainsKey($tok)) { continue }
        if (-not $out.Contains($s)) { $out.Add($s) }
    }
    return $out
}

function Get-Singular {
    param([string] $Word)
    if ($Word.Length -gt 4 -and $Word.EndsWith('ies')) { return $Word.Substring(0, $Word.Length - 3) + 'y' }
    if ($Word.Length -gt 4 -and $Word -match '(ss|sh|ch|x|z)es$') { return $Word.Substring(0, $Word.Length - 2) }
    if ($Word.Length -gt 3 -and $Word.EndsWith('s') -and -not $Word.EndsWith('ss')) { return $Word.Substring(0, $Word.Length - 1) }
    return $Word
}

function Get-LabelAliases {
    <# head noun / singular / and-split of a row label, normalised, minus the label itself. #>
    param([string] $Label)
    $out = New-Object System.Collections.Generic.List[string]
    $base = $Label -replace '\([^)]*\)', ' '
    $baseNorm = ConvertTo-GateNormal $base
    $labelNorm = ConvertTo-GateNormal $Label
    $pieces = New-Object System.Collections.Generic.List[string]
    foreach ($p in ($base -split '(?i)\s+(?:and|or)\s+|,|/|&')) {
        $pn = ConvertTo-GateNormal $p
        if ($pn) { $pieces.Add($pn) }
    }
    if ($pieces.Count -eq 0) { $pieces.Add($baseNorm) }
    foreach ($pn in $pieces) {
        $words = @($pn -split ' ' | Where-Object { $_ })
        if ($words.Count -eq 0) { continue }
        $cands = New-Object System.Collections.Generic.List[string]
        $cands.Add($pn)
        $sing = @($words | ForEach-Object { Get-Singular $_ }) -join ' '
        $cands.Add($sing)
        $head = $words[$words.Count - 1]
        $cands.Add($head)
        $cands.Add((Get-Singular $head))
        foreach ($c in $cands) {
            if ($c -and $c -ne $labelNorm -and $c.Length -ge 3 -and -not $out.Contains($c) -and -not $script:StopSet.ContainsKey($c)) { $out.Add($c) }
        }
    }
    return $out.ToArray()
}

# ---------------------------------------------------------------------------
# Typed task data
# ---------------------------------------------------------------------------

function Split-ModelRow {
    <# "label | cell~~cell | cell" -> array of cells, each an array of bullets. #>
    param([string] $Row)
    $cells = New-Object System.Collections.Generic.List[object]
    foreach ($cell in ($Row -split '\|')) {
        $bullets = @($cell -split '~~' | ForEach-Object { "$_".Trim() })
        $cells.Add(@($bullets))
    }
    return $cells.ToArray()
}

function Test-StubBullet {
    <#  A pre-printed field with nothing after its colon - "Mode:" or
        "Despatch - Temp:, Time:, Sign/initial:" - is where the learner writes.
        A structural test on the cell, not a word list.  #>
    param([string] $Bullet, [string[]] $BlankTokens)
    $b = "$Bullet".Trim()
    if (-not $b) { return $true }
    if ($b -match '^(?:[^:]{1,40}:\s*(?:,\s*)?)+$') { return $true }
    if (-not (Test-GateCellFilled -Text $b -BlankTokens $BlankTokens)) { return $true }
    return $false
}

$ORDINAL_WORDS = @('one','two','three','four','five','six','seven','eight','nine','ten','eleven','twelve','thirteen','fourteen','fifteen','sixteen','seventeen','eighteen','nineteen','twenty','first','second','third','fourth','fifth','sixth','seventh','eighth','ninth','tenth')
function Test-NumericLabel {
    param([string] $Label)
    $n = ConvertTo-GateNormal $Label
    if ($n -match '^\d+$') { return $true }
    if ($ORDINAL_WORDS -contains $n) { return $true }
    if ($n -match '^(no|item|row|step|order|dish|number)\s*\d+$') { return $true }
    return $false
}

function Get-WordRange {
    <# "20 to 30 words" -> @{min=20;max=30}; the first range found, or $null. #>
    param([string] $Text)
    if (-not $Text) { return $null }
    #  The dash family is written as \u escapes: this file is ASCII.
    $m = [regex]::Match($Text, '(\d+)\s*(?:to|-|\u2013|\u2014)\s*(\d+)\s*words?')
    if ($m.Success) { return [ordered]@{ min = [int]$m.Groups[1].Value; max = [int]$m.Groups[2].Value } }
    $m = [regex]::Match($Text, '(\d+)\s*words?')
    if ($m.Success) { return [ordered]@{ min = [int]$m.Groups[1].Value; max = [int]$m.Groups[1].Value } }
    return $null
}

$NUMBER_WORDS = @{ 'one' = 1; 'two' = 2; 'three' = 3; 'four' = 4; 'five' = 5; 'six' = 6; 'seven' = 7; 'eight' = 8; 'nine' = 9; 'ten' = 10 }
function ConvertTo-Number {
    param([string] $Word)
    $w = $Word.ToLowerInvariant()
    if ($w -match '^\d+$') { return [int]$w }
    if ($NUMBER_WORDS.ContainsKey($w)) { return [int]$NUMBER_WORDS[$w] }
    return $null
}

function Get-AtLeastNumber {
    <# The smallest "at least N" / "N correct point(s)" a text states, or $null. #>
    param([string[]] $Texts)
    $best = $null
    foreach ($t in @($Texts)) {
        if (-not $t) { continue }
        foreach ($m in [regex]::Matches($t, '(?i)\bat least (\w+)\b')) {
            $n = ConvertTo-Number $m.Groups[1].Value
            if ($null -ne $n -and ($null -eq $best -or $n -lt $best)) { $best = $n }
        }
        foreach ($m in [regex]::Matches($t, '(?i)\b(\w+)\s+(?:correct\s+)?(?:point|indicator|reason|method|example|control|detail|check|entry|action)s?\b')) {
            $n = ConvertTo-Number $m.Groups[1].Value
            if ($null -ne $n -and ($null -eq $best -or $n -lt $best)) { $best = $n }
        }
    }
    return $best
}

function Get-PartWordGuide {
    <#  The learner's word guide for one part: the part's own guide, else the
        segment of the task guide that names this part, else the sentence in
        the part text. Learner-facing in every case.  #>
    param($Task, $Part)
    $own = [string](Get-GateProp -Object $Part -Names @('wordGuide') -Default '')
    if ($own) { return $own }
    $taskGuide = [string](Get-GateProp -Object $Task -Names @('wordGuide') -Default '')
    $label = [string](Get-GateProp -Object $Part -Names @('label') -Default '')
    if ($taskGuide -and $label) {
        foreach ($seg in ($taskGuide -split ';')) {
            if ($seg -match ('\(' + [regex]::Escape($label) + '\)')) { return $seg.Trim() }
        }
        if ($taskGuide -match ('part\s*\(' + [regex]::Escape($label) + '\)')) { return $taskGuide }
    }
    $txt = [string](Get-GateProp -Object $Part -Names @('text') -Default '')
    $m = [regex]::Match($txt, '(?i)write\s+\d+\s*(?:to|-)\s*\d+\s*words[^.]*')
    if ($m.Success) { return $m.Value.Trim() }
    if ($taskGuide) { return $taskGuide }
    return ''
}

# ---------------------------------------------------------------------------
# 0. Resolve every location. Nothing below types a path.
# ---------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $BuildDir)) { Write-Host "${SCRIPT_NAME}: -BuildDir does not exist: $BuildDir" -ForegroundColor Red; exit 2 }
$BuildDir = (Resolve-Path -LiteralPath $BuildDir).Path

$contract = Get-GateContract -BuildDir $BuildDir
if ($null -eq $contract) { Write-Host "${SCRIPT_NAME}: no contract.json in $BuildDir. The question map is the only source of which sub-section prepares which task." -ForegroundColor Red; exit 2 }
if (@($contract.PSObject.Properties.Name) -notcontains 'questionMap') { Write-Host "${SCRIPT_NAME}: contract.json has no questionMap." -ForegroundColor Red; exit 2 }

if (-not $PackDir) {
    if (@($contract.PSObject.Properties.Name) -contains 'build') {
        $PackDir = [string](Get-GateProp -Object $contract.build -Names @('packDir', 'pack', 'assessmentPack') -Default '')
    }
}
if (-not $PackDir -or -not (Test-Path -LiteralPath $PackDir)) {
    Write-Host "${SCRIPT_NAME}: the assessment pack directory could not be found. Pass -PackDir, or record it in contract.json build.packDir. Looked for: '$PackDir'" -ForegroundColor Red; exit 2
}
$PackDir = (Resolve-Path -LiteralPath $PackDir).Path
if (-not $ContentDir) { $ContentDir = Join-Path $PackDir 'content' }
if (-not (Test-Path -LiteralPath $ContentDir)) { Write-Host "${SCRIPT_NAME}: no typed content directory at $ContentDir" -ForegroundColor Red; exit 2 }

$taskFiles = @(Get-ChildItem -LiteralPath $ContentDir -Filter '*_tasks_*.json' -File | Sort-Object Name)
if ($taskFiles.Count -eq 0) { Write-Host "${SCRIPT_NAME}: no *_tasks_*.json under $ContentDir - there is no typed grid data to derive from." -ForegroundColor Red; exit 2 }

$corpusDirResolved = Get-GateCorpusDir -BuildDir $BuildDir -CorpusDir $CorpusDir
$corpus = Get-GateCorpusDocs -CorpusDir $corpusDirResolved -BuildDir $BuildDir
if ((Get-Count $corpus.Learner) -eq 0) { Write-Host "${SCRIPT_NAME}: the corpus at $corpusDirResolved has no learner-facing document." -ForegroundColor Red; exit 2 }
$blanks = Get-GateBlankTokens -BuildDir $BuildDir

if (-not $UnitExtract) {
    $cand = Join-Path $BuildDir 'unit_extract.md'
    if (Test-Path -LiteralPath $cand) { $UnitExtract = $cand }
    else {
        $found = @(Get-ChildItem -LiteralPath $PackDir -Filter '*unit_extract.md' -File -ErrorAction SilentlyContinue)
        if ($found.Count -gt 0) { $UnitExtract = $found[0].FullName }
    }
}

$unitCode = ''
if (@($contract.PSObject.Properties.Name) -contains 'unit') { $unitCode = [string](Get-GateProp -Object $contract.unit -Names @('code') -Default '') }

Say ''
Say 'WITHHOLD REGISTER' 'Cyan'
Say ("  build:   {0}" -f $BuildDir) 'DarkGray'
Say ("  pack:    {0}" -f $PackDir) 'DarkGray'
Say ("  corpus:  {0}  ({1} learner-facing, {2} assessor-only, classified from the {3})" -f $corpusDirResolved, (Get-Count $corpus.Learner), (Get-Count $corpus.Assessor), $corpus.ClassifiedFrom) 'DarkGray'
Say ("  typed task files: {0}" -f (($taskFiles | ForEach-Object { $_.Name }) -join ', ')) 'DarkGray'

# ---------------------------------------------------------------------------
# 1. The learner-facing corpus, line by line, with its section boundaries
# ---------------------------------------------------------------------------

$learnerDocs = @{}
$learnerAllNormParts = New-Object System.Collections.Generic.List[string]
foreach ($doc in $corpus.Learner) {
    $lines = @($doc.Text -split "`r?`n")
    $norms = New-Object System.Collections.Generic.List[string]
    $tocNorms = @{}
    foreach ($ln in $lines) {
        $norms.Add((ConvertTo-GateNormal $ln))
        if ($ln -match 'PAGEREF') {
            $h = ConvertTo-GateNormal ($ln -replace '\s*PAGEREF.*$', '')
            if ($h) { $tocNorms[$h] = $true }
        }
    }
    $openBook = ''
    foreach ($ln in $lines) {
        if ($ln -match '(?i)\bopen[\s-]?book\b' -and $ln -match '(?i)\b(may use|permitted|allowed|can use)\b') { $openBook = $ln.Trim(); break }
    }
    if (-not $openBook) { foreach ($ln in $lines) { if ($ln -match '(?i)\bopen[\s-]?book\b') { $openBook = $ln.Trim(); break } } }
    $learnerDocs[$doc.Name] = [pscustomobject]@{
        Name       = $doc.Name
        Path       = $doc.Path
        Lines      = $lines
        Norms      = $norms.ToArray()
        TocNorms   = $tocNorms
        OpenBook   = $openBook
        Boundaries = @{}
    }
    $learnerAllNormParts.Add((ConvertTo-GateNormal $doc.Text))
}
$learnerAllNorm = ($learnerAllNormParts -join ' ')

# ---------------------------------------------------------------------------
# 2. The typed tasks, bound to the learner document that prints them
# ---------------------------------------------------------------------------

function Find-HeadingLine {
    <# The body line equal to a heading (not a TOC entry), preferring the
       occurrence that is followed by an answerable part. #>
    param($LDoc, [string] $HeadingNorm)
    if (-not $HeadingNorm) { return -1 }
    $hits = New-Object System.Collections.Generic.List[int]
    for ($i = 0; $i -lt $LDoc.Norms.Count; $i++) {
        if ($LDoc.Norms[$i] -eq $HeadingNorm -and $LDoc.Lines[$i] -notmatch 'PAGEREF') { $hits.Add($i) }
    }
    if ($hits.Count -eq 0) { return -1 }
    foreach ($h in $hits) {
        for ($j = $h + 1; $j -lt [math]::Min($LDoc.Lines.Count, $h + 80); $j++) {
            if ($LDoc.Lines[$j] -match '^\s*\([a-z0-9]{1,3}\)\s' -or $LDoc.Norms[$j] -match '^(student|learner|candidate|your)?\s*(response|answer)\b') { return $h }
        }
    }
    return $hits[0]
}

$tasks = New-Object System.Collections.Generic.List[object]
foreach ($tf in $taskFiles) {
    $j = Get-GateJson -Path $tf.FullName
    if ($null -eq $j) { continue }
    foreach ($item in @(Get-PropList $j @('items', 'tasks'))) {
        if ($null -eq $item) { continue }
        $heading = [string](Get-GateProp -Object $item -Names @('heading', 'title') -Default '')
        $id = [string](Get-GateProp -Object $item -Names @('id') -Default '')
        $num = $null
        if ($heading -match '(?i)^\s*task\s+(\d+)\b') { $num = [int]$Matches[1] }
        elseif ($id -match 'T(\d+)$') { $num = [int]$Matches[1] }
        if ($null -eq $num) { continue }
        $parts = @(Get-PropList $item @('parts'))
        if ($parts.Count -eq 0) { continue }

        $headingNorm = ConvertTo-GateNormal $heading
        $boundDoc = ''
        $headingLine = -1
        foreach ($dn in ($learnerDocs.Keys | Sort-Object)) {
            $li = Find-HeadingLine -LDoc $learnerDocs[$dn] -HeadingNorm $headingNorm
            if ($li -ge 0) { $boundDoc = $dn; $headingLine = $li; break }
        }
        $tasks.Add([pscustomobject]@{
            File        = $tf.Name
            Id          = $id
            Number      = $num
            Heading     = $heading
            HeadingNorm = $headingNorm
            Doc         = $boundDoc
            HeadingLine = $headingLine
            Item        = $item
            Parts       = $parts
            Section     = @()
            Preamble    = @()
            PartSlices  = @{}
        })
    }
}
if ($tasks.Count -eq 0) { Write-Host "${SCRIPT_NAME}: the typed task files carry no task with parts." -ForegroundColor Red; exit 2 }

# Section boundaries per document: every task heading it prints, every TOC heading.
foreach ($dn in $learnerDocs.Keys) {
    $b = @{}
    foreach ($k in $learnerDocs[$dn].TocNorms.Keys) { $b[$k] = $true }
    foreach ($tk in $tasks) { if ($tk.Doc -eq $dn -and $tk.HeadingNorm) { $b[$tk.HeadingNorm] = $true } }
    $learnerDocs[$dn].Boundaries = $b
}

function Get-SectionLines {
    <# Lines from a heading line to the next boundary heading (exclusive). #>
    param($LDoc, [int] $Start)
    if ($Start -lt 0) { return @() }
    $end = $LDoc.Lines.Count
    for ($i = $Start + 1; $i -lt $LDoc.Lines.Count; $i++) {
        $n = $LDoc.Norms[$i]
        if ($n -and $LDoc.Boundaries.ContainsKey($n) -and $LDoc.Lines[$i] -notmatch 'PAGEREF') { $end = $i; break }
    }
    return @($LDoc.Lines[$Start..($end - 1)])
}

function Split-SectionParts {
    <# A task section -> preamble lines + one slice per "(x)" part marker. #>
    param([string[]] $Lines)
    $markers = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^\s*\(([a-z0-9]{1,3})\)\s') { $markers.Add([pscustomobject]@{ Label = $Matches[1]; Index = $i }) }
    }
    $pre = if ($markers.Count -gt 0) { @($Lines[0..([math]::Max(0, $markers[0].Index - 1))]) } else { @($Lines) }
    $slices = @{}
    for ($k = 0; $k -lt $markers.Count; $k++) {
        $s = $markers[$k].Index
        $e = if ($k + 1 -lt $markers.Count) { $markers[$k + 1].Index } else { $Lines.Count }
        $slices[$markers[$k].Label] = @($Lines[$s..($e - 1)])
    }
    return [pscustomobject]@{ Preamble = $pre; Parts = $slices }
}

foreach ($tk in $tasks) {
    $section = @()
    $preamble = @()
    $partSlices = @{}
    if ($tk.Doc) {
        $section = Get-SectionLines -LDoc $learnerDocs[$tk.Doc] -Start $tk.HeadingLine
        $split = Split-SectionParts -Lines $section
        $preamble = $split.Preamble
        $partSlices = $split.Parts
    }
    $tk.Section    = @($section)
    $tk.Preamble   = @($preamble)
    $tk.PartSlices = $partSlices
}

$unbound = @($tasks | Where-Object { -not $_.Doc })
Say ("  typed tasks: {0}, bound to a learner document by heading: {1}" -f $tasks.Count, ($tasks.Count - $unbound.Count)) 'DarkGray'
foreach ($ub in $unbound) { Say ("    ! '{0}' ({1}) is not printed as a heading in any learner-facing document; its learner text falls back to the typed fields" -f $ub.Heading, $ub.File) 'Yellow' }

# ---------------------------------------------------------------------------
# 3. Reference patterns: how the question map names a task in each document
# ---------------------------------------------------------------------------

function ConvertTo-RefRegex {
    param([string] $Pattern)
    #  [regex]::Escape escapes '{' and '(' but not '}', so the placeholders
    #  arrive as \{n} and \(\{part}\); match either spelling of the brace.
    $rx = [regex]::Escape($Pattern)
    $rx = $rx -replace '\\\(\\\{part\\?\}\\\)', '(?:\((?<part>[a-z0-9]{1,3})\))?'
    $rx = $rx -replace '\\\{part\\?\}', '(?<part>[a-z0-9]{1,3})'
    $rx = $rx -replace '\\\{n\\?\}', '(?<n>\d+)'
    return ('^\s*' + $rx + '\s*$')
}

$docPatterns = @{}       # doc name -> pattern string
$obsPattern = 'Observation {n}'
$refConv = $null
if (@($contract.PSObject.Properties.Name) -contains 'referenceConvention') { $refConv = $contract.referenceConvention }
if ($null -ne $refConv) {
    foreach ($p in $refConv.PSObject.Properties) {
        if ($p.Name -like '_*' -or $p.Name -like '*Means' -or $p.Name -eq 'questionPattern') { continue }
        $val = [string]$p.Value
        if ($val -notmatch '\{n\}') { continue }
        $meansName = $p.Name + 'Means'
        $means = ''
        if (@($refConv.PSObject.Properties.Name) -contains $meansName) { $means = ConvertTo-GateNormal ([string]$refConv.$meansName) }
        if ($p.Name -match '(?i)observ') { $obsPattern = $val; continue }
        foreach ($dn in $learnerDocs.Keys) {
            $stemNorm = ConvertTo-GateNormal $dn
            if ($means -and $stemNorm -and $means.Contains($stemNorm)) { $docPatterns[$dn] = $val }
        }
    }
}
$fallbackPattern = 'Task {n}({part})'
foreach ($dn in $learnerDocs.Keys) { if (-not $docPatterns.ContainsKey($dn)) { $docPatterns[$dn] = $fallbackPattern } }
$obsRegex = ConvertTo-RefRegex $obsPattern

function Resolve-Reference {
    <# "Knowledge Task 11(a)" -> doc, task number, part label - or a reason. #>
    param([string] $Ref)
    $obsM = [regex]::Match($Ref, $obsRegex, 'IgnoreCase')
    if ($obsM.Success) { return [pscustomobject]@{ Kind = 'observation'; Number = [int]$obsM.Groups['n'].Value; Doc = ''; Part = ''; Task = $null; Reason = '' } }
    $cands = New-Object System.Collections.Generic.List[object]
    foreach ($dn in ($docPatterns.Keys | Sort-Object)) {
        $m = [regex]::Match($Ref, (ConvertTo-RefRegex $docPatterns[$dn]), 'IgnoreCase')
        if (-not $m.Success) { continue }
        $n = [int]$m.Groups['n'].Value
        $part = if ($m.Groups['part'].Success) { $m.Groups['part'].Value.ToLowerInvariant() } else { '' }
        $tk = @($tasks | Where-Object { $_.Doc -eq $dn -and $_.Number -eq $n })
        if ($tk.Count -eq 0 -and $docPatterns[$dn] -eq $fallbackPattern) {
            $tk = @($tasks | Where-Object { -not $_.Doc -and $_.Number -eq $n })
        }
        if ($tk.Count -eq 1) { $cands.Add([pscustomobject]@{ Kind = 'task'; Number = $n; Doc = $dn; Part = $part; Task = $tk[0]; Reason = '' }) }
        elseif ($tk.Count -gt 1) { $cands.Add([pscustomobject]@{ Kind = 'task'; Number = $n; Doc = $dn; Part = $part; Task = $null; Reason = ("more than one typed task numbered {0} binds to {1}" -f $n, $dn) }) }
        else { $cands.Add([pscustomobject]@{ Kind = 'task'; Number = $n; Doc = $dn; Part = $part; Task = $null; Reason = ("no typed task numbered {0} is bound to {1}" -f $n, $dn) }) }
    }
    $good = @($cands | Where-Object { $null -ne $_.Task })
    if ($good.Count -eq 1) { return $good[0] }
    if ($good.Count -gt 1) { return [pscustomobject]@{ Kind = 'task'; Number = 0; Doc = ''; Part = ''; Task = $null; Reason = ("ambiguous: the reference matches {0} documents ({1}); give contract.json a referenceConvention that names the document" -f $good.Count, (($good | ForEach-Object { $_.Doc }) -join ', ')) } }
    if ($cands.Count -gt 0) { return $cands[0] }
    return [pscustomobject]@{ Kind = 'task'; Number = 0; Doc = ''; Part = ''; Task = $null; Reason = 'matches no document reference pattern' }
}

# ---------------------------------------------------------------------------
# 4. Subject vocabulary: recipes, equipment, workplace documents - from the pack
# ---------------------------------------------------------------------------

$vocab = New-Object System.Collections.Generic.List[object]
function Add-VocabEntry {
    param([string] $Class, [string] $Name, [string] $Key = '', [string[]] $Aliases = @())
    $norm = ConvertTo-GateNormal ($Name -replace '\([^)]*\)', ' ')
    if (-not $norm) { return }
    foreach ($existing in $vocab) { if ($existing.Class -eq $Class -and $existing.Norm -eq $norm) { return } }
    $al = New-Object System.Collections.Generic.List[string]
    foreach ($a in $Aliases) { $an = ConvertTo-GateNormal $a; if ($an -and -not $al.Contains($an)) { $al.Add($an) } }
    $vocab.Add([pscustomobject]@{
        Class   = $Class
        Name    = $Name.Trim()
        Key     = $Key
        Norm    = $norm
        Words   = @(Get-Words $norm)
        Aliases = $al.ToArray()
    })
}

# recipes - the typed recipe cards, else the learner text's own recipe headings
$recipeFiles = @(Get-ChildItem -LiteralPath $ContentDir -Filter '*recipe*.json' -File -ErrorAction SilentlyContinue)
foreach ($rf in $recipeFiles) {
    $rj = Get-GateJson -Path $rf.FullName
    if ($null -eq $rj) { continue }
    foreach ($it in @(Get-PropList $rj @('items', 'recipes'))) {
        if ($null -eq $it) { continue }
        $rn = [string](Get-GateProp -Object $it -Names @('recipeNumber', 'number', 'no') -Default '')
        $name = [string](Get-GateProp -Object $it -Names @('name', 'title') -Default '')
        if (-not $rn -and -not $name) { continue }
        if (-not $rn -and @($it.PSObject.Properties.Name) -contains 'header') { $rn = [string](Get-GateProp -Object $it.header -Names @('recipeNumber') -Default '') }
        $display = if ($rn) { "$rn $name".Trim() } else { $name }
        #  The order form and the tasks use the short dish name; the card name
        #  carries the garnish ("... with steamed rice and chopped kale"). The
        #  head of the name is an alias so the short form still resolves.
        $headName = ($name -replace '(?i)\s+with\s+.*$', '').Trim()
        Add-VocabEntry -Class 'recipe' -Name $display -Key $rn -Aliases @($name, $headName, "recipe $rn", "standard recipe $rn")
    }
}
if (@($vocab | Where-Object { $_.Class -eq 'recipe' }).Count -eq 0) {
    foreach ($dn in $learnerDocs.Keys) {
        foreach ($ln in $learnerDocs[$dn].Lines) {
            if ($ln -match '^\s*Recipe\s+(\d{2,6})[.\s:-]+\s*(.+?)\s*$' -and $ln -notmatch 'PAGEREF') {
                Add-VocabEntry -Class 'recipe' -Name ("{0} {1}" -f $Matches[1], $Matches[2]) -Key $Matches[1] -Aliases @($Matches[2], ("recipe " + $Matches[1]))
            }
        }
    }
}

# equipment - the unit's assessment conditions, kept only where the pack names the item
$equipmentSource = ''
if ($UnitExtract -and (Test-Path -LiteralPath $UnitExtract)) {
    $equipmentSource = Split-Path $UnitExtract -Leaf
    $inCond = $false
    $group = ''
    foreach ($ln in (Get-GateFileText -Path $UnitExtract) -split "`r?`n") {
        if ($ln -match '(?i)^##\s+.*assessment conditions') { $inCond = $true; continue }
        if ($inCond -and ($ln -match '^##\s' -or $ln -match '(?i)^\*\*Assessor requirements')) { break }
        if (-not $inCond) { continue }
        if ($ln -notmatch '^(\s*)-\s+(.*)$') { continue }
        $indent = $Matches[1].Length
        $body = ($Matches[2] -replace '\*\*', '').Trim()
        if ($indent -eq 0) {
            if ($body -match '^(.+?):\s*(.*)$') { $group = $Matches[1].Trim(); $rest = $Matches[2].Trim() } else { $group = $body; $rest = '' }
            if ($group -match '(?i)equipment|fixtures' -and $group -notmatch '(?i)clean' -and $rest) {
                foreach ($e in ($rest -split ';')) { $en = ($e -replace '\([^)]*\)', '').Trim(); if ($en) { Add-VocabEntry -Class 'equipment' -Name $en } }
            }
            continue
        }
        if ($group -notmatch '(?i)equipment|fixtures' -or $group -match '(?i)clean') { continue }
        $head = $body; $rest = ''
        if ($body -match '^(.+?):\s*(.*)$') { $head = $Matches[1].Trim(); $rest = $Matches[2].Trim() }
        if ($rest) { foreach ($e in ($rest -split ';')) { $en = ($e -replace '\([^)]*\)', '').Trim(); if ($en) { Add-VocabEntry -Class 'equipment' -Name $en } } }
        else { $en = ($head -replace '\([^)]*\)', '').Trim(); if ($en) { Add-VocabEntry -Class 'equipment' -Name $en } }
    }
    # keep only equipment the learner-facing pack actually names
    $kept = New-Object System.Collections.Generic.List[object]
    foreach ($v in $vocab) {
        if ($v.Class -ne 'equipment') { $kept.Add($v); continue }
        $mentioned = Test-Verbatim -NeedleNorm $v.Norm -HayNorm $learnerAllNorm
        if (-not $mentioned) {
            #  "commercial oven with trays" is an oven: drop a trailing
            #  with/for clause, then ask whether the head noun is in the pack.
            $core = ($v.Norm -replace '\s+(with|for)\s+.*$', '').Trim()
            $ws = @($core -split ' ' | Where-Object { $_ })
            #  Head-noun fallback only for short names; a four-word unit
            #  phrase ("lifting and transporting equipment") must be in the
            #  pack whole or it is not something the pack names.
            if ($ws.Count -gt 0 -and $ws.Count -le 3) {
                $headWord = Get-Singular $ws[$ws.Count - 1]
                if ($headWord.Length -ge 4 -and ((Test-Verbatim -NeedleNorm $headWord -HayNorm $learnerAllNorm) -or (Test-Verbatim -NeedleNorm ($headWord + 's') -HayNorm $learnerAllNorm))) { $mentioned = $true }
            }
        }
        if ($mentioned) { $kept.Add($v) }
    }
    $vocab = $kept
}

# workplace documents - the build contract's scenario, else the pack contract's scenario card
$docNames = @()
if (@($contract.PSObject.Properties.Name) -contains 'scenario') { $docNames = @(Get-PropList $contract.scenario @('workplaceDocuments', 'documents')) }
if ($docNames.Count -eq 0) {
    $packContract = Get-GateJson -Path (Join-Path $PackDir 'contract.json')
    if ($null -ne $packContract -and @($packContract.PSObject.Properties.Name) -contains 'scenarioCard') { $docNames = @(Get-PropList $packContract.scenarioCard @('documents', 'workplaceDocuments')) }
}
foreach ($d in $docNames) {
    $dname = [string]$d
    if (-not $dname) { continue }
    $aliases = @()
    if ($dname -match '\((Appendix\s+[A-Z])\)') { $aliases += $Matches[1] }
    Add-VocabEntry -Class 'document' -Name ($dname -replace '^\s*the\s+', '') -Aliases $aliases
}
foreach ($dn in $learnerDocs.Keys) {
    foreach ($m in [regex]::Matches(($learnerDocs[$dn].Lines -join "`n"), '\bAppendix\s+([A-Z])\b')) { Add-VocabEntry -Class 'document' -Name ('Appendix ' + $m.Groups[1].Value) }
}

$vocabByClass = @{}
foreach ($v in $vocab) { if (-not $vocabByClass.ContainsKey($v.Class)) { $vocabByClass[$v.Class] = New-Object System.Collections.Generic.List[object] }; $vocabByClass[$v.Class].Add($v) }
Say ("  subject vocabulary: {0}" -f (($vocabByClass.Keys | Sort-Object | ForEach-Object { "{0} {1}" -f $vocabByClass[$_].Count, $_ }) -join ', ')) 'DarkGray'
if (-not $equipmentSource) { Say '    ! no unit extract found - the equipment class is empty and every equipment grid will carry allowance 1' 'Yellow' }

function Resolve-Subject {
    <#  The vocabulary entries a free-text subject names. Conservative: an
        ambiguous name matches every candidate, which withholds more.

        -Strict is for ROW LABELS: the label must essentially BE the entry
        ("Blast chiller", "Cool room and refrigerators"), so a word-overlap
        match also has to cover most of the label's own words. A subject CELL
        ("Chickpea and Potato Curry, 50 portions, 17.5 L, chilled") carries
        qualifiers and is matched without that condition.  #>
    param([string] $Text, [switch] $Strict)
    $hits = New-Object System.Collections.Generic.List[object]
    $n = ConvertTo-GateNormal ($Text -replace '\([^)]*\)', ' ')
    if (-not $n) { return $hits }
    $words = @(Get-Words $n)
    foreach ($v in $vocab) {
        $hit = $false
        if ($v.Key -and ($n -match ('\b' + [regex]::Escape($v.Key) + '\b'))) { $hit = $true }
        elseif (Test-Verbatim -NeedleNorm $v.Norm -HayNorm $n) { $hit = $true }
        elseif (Test-Verbatim -NeedleNorm $n -HayNorm $v.Norm) { $hit = $true }
        else {
            foreach ($a in $v.Aliases) { if ($a.Length -ge 4 -and (Test-Verbatim -NeedleNorm $a -HayNorm $n)) { $hit = $true; break } }
            if (-not $hit -and $words.Count -gt 0 -and $v.Words.Count -gt 0) {
                #  Word overlap against the name AND each multi-word alias, so
                #  a short dish name resolves against its own head, not the
                #  full card name with its garnish.
                $wordSets = New-Object System.Collections.Generic.List[object]
                $wordSets.Add(@($v.Words))
                #  Number-bearing aliases ("standard recipe 2091") are matched
                #  by their key only: stripped of the number they collapse to
                #  {standard, recipe} and would match every recipe there is.
                foreach ($a in $v.Aliases) {
                    if ($a -match '\d') { continue }
                    $aw = @(Get-Words $a); if ($aw.Count -ge 2) { $wordSets.Add($aw) }
                }
                foreach ($vw in $wordSets) {
                    $common = @($words | Where-Object { $vw -contains $_ })
                    $minLen = [math]::Min($words.Count, $vw.Count)
                    $need = [math]::Max(1, [math]::Ceiling(0.6 * $minLen))
                    $h = $false
                    if ($common.Count -ge $need) {
                        if ($minLen -ge 2 -and $common.Count -ge 2) { $h = $true }
                        elseif ($minLen -eq 1 -and $common[0].Length -ge 4) { $h = $true }
                    }
                    if ($h -and $Strict -and $common.Count -lt [math]::Ceiling(0.6 * $words.Count)) { $h = $false }
                    if ($h) { $hit = $true; break }
                }
            }
        }
        if ($hit) { $hits.Add($v) }
    }
    return $hits
}

# ---------------------------------------------------------------------------
# 5. Derive every assessed grid and free-text part the question map names
# ---------------------------------------------------------------------------

$questionMap = $contract.questionMap
$subSectionKeys = @($questionMap.PSObject.Properties | Where-Object { $_.Name -notlike '_*' } | ForEach-Object { $_.Name })
if ($subSectionKeys.Count -eq 0) { Write-Host "${SCRIPT_NAME}: questionMap assigns nothing." -ForegroundColor Red; exit 2 }

$gridsOut      = New-Object System.Collections.Generic.List[object]   # grids.json
$register      = [ordered]@{}                                          # sub-section -> entry
$assessorGrids = New-Object System.Collections.Generic.List[object]
$assessorFree  = New-Object System.Collections.Generic.List[object]
$assessorTaskLevel = New-Object System.Collections.Generic.List[object]
$unclassified  = New-Object System.Collections.Generic.List[object]
$unresolved    = New-Object System.Collections.Generic.List[object]
$summaryRows   = New-Object System.Collections.Generic.List[object]
$seenGridIds   = @{}
$seenTaskLevel = @{}
$forbidden     = New-Object System.Collections.Generic.List[string]    # normalised assessor-authored strings
$allBulletWordSets = New-Object System.Collections.Generic.List[object] # for document frequency

function Get-LearnerTextOfTask {
    <# Every learner-facing string of a task: the printed section where bound, plus the typed learner fields. #>
    param($Task, $Part)
    $parts = New-Object System.Collections.Generic.List[string]
    $parts.Add([string]$Task.Heading)
    foreach ($ln in $Task.Preamble) { $parts.Add([string]$ln) }
    $label = [string](Get-GateProp -Object $Part -Names @('label') -Default '')
    if ($label -and $Task.PartSlices.ContainsKey($label)) { foreach ($ln in $Task.PartSlices[$label]) { $parts.Add([string]$ln) } }
    foreach ($f in @('scenarioBox', 'stem', 'wordGuide', 'justification')) { $v = Get-GateProp -Object $Task.Item -Names @($f) -Default ''; if ($v) { $parts.Add([string]$v) } }
    foreach ($f in @('text', 'wordGuide')) { $v = Get-GateProp -Object $Part -Names @($f) -Default ''; if ($v) { $parts.Add([string]$v) } }
    if (@($Part.PSObject.Properties.Name) -contains 'itemTable' -and $null -ne $Part.itemTable) {
        foreach ($h in @(Get-PropList $Part.itemTable @('headers'))) { $parts.Add([string]$h) }
        foreach ($i in @(Get-PropList $Part.itemTable @('items'))) { $parts.Add([string]$i) }
    }
    return ($parts -join "`n")
}

function Get-PermittedGround {
    <# One line: what the learner holds during this task, and where examples may be set. #>
    param($Task, $Part, [string] $ClassName, [string[]] $Unassessed, [int] $Allowance, [switch] $Prose)
    $exemplar = if ($Prose) { 'one worked example is permitted in the sub-section' } else { 'one worked exemplar row is permitted in the sub-section, every other row carries the withhold token' }
    $learnerText = Get-LearnerTextOfTask -Task $Task -Part $Part
    $ln = ConvertTo-GateNormal $learnerText
    $held = New-Object System.Collections.Generic.List[string]
    foreach ($v in $vocab) {
        if ($v.Class -ne 'document') { continue }
        $hit = Test-Verbatim -NeedleNorm $v.Norm -HayNorm $ln
        if (-not $hit) { foreach ($a in $v.Aliases) { if (Test-Verbatim -NeedleNorm $a -HayNorm $ln) { $hit = $true; break } } }
        if (-not $hit -and $v.Words.Count -ge 2) {
            $common = @((Get-Words $ln) | Where-Object { $v.Words -contains $_ })
            if ($common.Count -ge [math]::Ceiling(0.75 * $v.Words.Count)) { $hit = $true }
        }
        if ($hit -and -not $held.Contains($v.Name)) { $held.Add($v.Name) }
    }
    if ($ln -match '\b(standard recipes?|recipe cards?)\b' -and -not ($held | Where-Object { $_ -match '(?i)recipe' })) { $held.Add('the standard recipe cards') }
    if ($ln -match '\b(sop|standard operating procedure)s?\b' -and -not ($held | Where-Object { $_ -match '(?i)operating procedure' })) { $held.Add('the standard operating procedures the task names') }
    $doc = if ($Task.Doc -and $learnerDocs.ContainsKey($Task.Doc)) { $learnerDocs[$Task.Doc] } else { $null }
    $open = if ($null -ne $doc -and $doc.OpenBook) { ' The tool states: ' + (ConvertTo-AsciiText $doc.OpenBook) } else { '' }
    $heldText = if ($held.Count -gt 0) { 'Learner-held during this task: ' + ($held -join '; ') + '.' } else { 'The task names no workplace document beyond the tool itself.' }
    $where = ''
    if ($Unassessed.Count -gt 0) { $where = (' Set every example on an unassessed {0}: {1}.' -f $ClassName, ($Unassessed -join '; ')) }
    elseif ($ClassName) { $where = (' Every {0} in the pack is assessed by this task; allowance {1} - {2}.' -f $ClassName, $Allowance, $exemplar) }
    else { $where = (' The task has no subject class in the pack vocabulary; allowance {0} - {1}.' -f $Allowance, $exemplar) }
    return ($heldText + $open + $where) -replace '\s+', ' '
}

function Add-BulletWords {
    param([string] $Text)
    $ws = @(Get-Words $Text -KeepNumbers)
    $allBulletWordSets.Add(@($ws))
    return $ws
}

#  The permitted ground for the leak sweep: everything the learner holds, plus
#  the unit's own wording and the pack vocabulary names. A string found in any
#  of these is not assessor-authored, whatever cell it sits in.
$unitExtractNorm = ''
if ($UnitExtract -and (Test-Path -LiteralPath $UnitExtract)) { $unitExtractNorm = ConvertTo-GateNormal (Get-GateFileText -Path $UnitExtract) }
$vocabNormSet = @{}
foreach ($v in $vocab) { $vocabNormSet[$v.Norm] = $true; foreach ($a in $v.Aliases) { $vocabNormSet[$a] = $true } }
function Add-Forbidden {
    <#  Decided PER STRING, never per cell: a learner-held figure sharing a
        cell with an assessor-authored reason is still learner-held, and
        sweeping it would flag the learner's own task text as a leak.  #>
    param([string] $Text, [int] $MinWords = 2)
    $n = ConvertTo-GateNormal $Text
    if (-not $n) { return }
    if (@($n -split ' ' | Where-Object { $_ }).Count -lt $MinWords) { return }
    if ($vocabNormSet.ContainsKey($n)) { return }
    if (Test-Verbatim -NeedleNorm $n -HayNorm $learnerAllNorm) { return }
    if ($unitExtractNorm -and (Test-Verbatim -NeedleNorm $n -HayNorm $unitExtractNorm)) { return }
    $forbidden.Add($n)
}

function New-GridDerivation {
    <# The whole derivation for one itemTable part. Returns a register entry
       or an unclassified reason, plus the gate-only cells. #>
    param($Task, $Part, [string] $Ref, [string] $GridId, [string] $Sub)

    $it = $Part.itemTable
    $headers = @(@(Get-PropList $it @('headers')) | ForEach-Object { [string]$_ })
    $items   = @(@(Get-PropList $it @('items')) | ForEach-Object { [string]$_ })
    $notes   = New-Object System.Collections.Generic.List[string]

    if ($headers.Count -lt 2) { return [pscustomobject]@{ Ok = $false; Reason = ("itemTable has {0} header(s); a response grid needs a label column and at least one assessed column" -f $headers.Count) } }
    if ($items.Count -eq 0)   { return [pscustomobject]@{ Ok = $false; Reason = 'itemTable has no items (row labels)' } }

    $rowSource = ''
    $rawRows = @()
    if (@(Get-PropList $it @('modelRows')).Count -gt 0) { $rowSource = 'modelRows'; $rawRows = @(Get-PropList $it @('modelRows')) }
    elseif (@(Get-PropList $it @('prefilledRows')).Count -gt 0) { $rowSource = 'prefilledRows'; $rawRows = @(Get-PropList $it @('prefilledRows')) }

    $rows = New-Object System.Collections.Generic.List[object]
    for ($r = 0; $r -lt $rawRows.Count; $r++) {
        $cells = @(Split-ModelRow ([string]$rawRows[$r]))
        if ($cells.Count -ne $headers.Count) {
            return [pscustomobject]@{ Ok = $false; Reason = ("{0}[{1}] has {2} cell(s) against {3} header(s); every model row must carry exactly one cell per header" -f $rowSource, $r, $cells.Count, $headers.Count) }
        }
        $labelNorm = ConvertTo-GateNormal ([string](@($cells[0]) -join ' '))
        $itemIdx = -1
        for ($i = 0; $i -lt $items.Count; $i++) { if ((ConvertTo-GateNormal $items[$i]) -eq $labelNorm) { $itemIdx = $i; break } }
        if ($itemIdx -lt 0 -and $r -lt $items.Count) {
            #  A model row that abbreviates its own item ("Name and recipe
            #  number" for "Name of the food and standard recipe number") is
            #  matched by position when every word of the label is in the item.
            $itemNormR  = ConvertTo-GateNormal $items[$r]
            $labelWords = @($labelNorm -split ' ' | Where-Object { $_ })
            $itemWords  = @($itemNormR -split ' ' | Where-Object { $_ })
            $subset = ($labelWords.Count -gt 0) -and (@($labelWords | Where-Object { $itemWords -notcontains $_ }).Count -eq 0)
            #  Or, row for row, when the label shares half its content words
            #  with the item in the same position ("Date produced and date
            #  code" for "Date produced and use-by or best-before date").
            $labelContent  = @(Get-Words $labelNorm)
            $itemContent   = @(Get-Words $itemNormR)
            $sharedContent = @($labelContent | Where-Object { $itemContent -contains $_ })
            $half = ($rawRows.Count -eq $items.Count) -and ($labelContent.Count -gt 0) -and ($sharedContent.Count -ge [math]::Ceiling(0.5 * $labelContent.Count))
            if ($itemNormR.StartsWith($labelNorm) -or $subset -or $half) {
                $itemIdx = $r
                $notes.Add(("{0}[{1}] label '{2}' differs from item '{3}'; matched by position" -f $rowSource, $r, [string](@($cells[0]) -join ' '), $items[$r]))
            }
        }
        if ($itemIdx -lt 0) { return [pscustomobject]@{ Ok = $false; Reason = ("{0}[{1}] label '{2}' matches no item" -f $rowSource, $r, [string](@($cells[0]) -join ' ')) } }
        $rows.Add([pscustomobject]@{ ItemIndex = $itemIdx; Item = $items[$itemIdx]; Cells = $cells })
    }

    # learner text scopes
    $taskLearner = Get-LearnerTextOfTask -Task $Task -Part $Part
    $taskLearnerNorm = ConvertTo-GateNormal $taskLearner
    $label = [string](Get-GateProp -Object $Part -Names @('label') -Default '')

    # rendered-grid cross-check: the learner's own document prints these headers and items
    $missingRender = New-Object System.Collections.Generic.List[string]
    if ($Task.Doc -and $Task.PartSlices.ContainsKey($label)) {
        $sliceNorm = ConvertTo-GateNormal ($Task.PartSlices[$label] -join "`n")
        foreach ($h in $headers) { if (-not (Test-Verbatim -NeedleNorm (ConvertTo-GateNormal $h) -HayNorm $sliceNorm)) { $missingRender.Add($h) } }
        foreach ($i in $items)   { if (-not (Test-Verbatim -NeedleNorm (ConvertTo-GateNormal $i) -HayNorm $sliceNorm)) { $missingRender.Add($i) } }
        if ($missingRender.Count -gt 0) { $notes.Add(("typed grid text not found in the learner document's rendering of part ({0}): {1}" -f $label, ($missingRender -join ' | '))) }
    }
    elseif (-not $Task.Doc) { $notes.Add('task is not bound to a learner document; learner text taken from the typed fields') }

    # example rows named by the learner text ("Row Example is filled in for you")
    $exampleLabels = @{}
    foreach ($m in [regex]::Matches($taskLearner, '(?i)\brow\s+(\w+)\s+is\s+(?:filled|completed|done)\s+in\s+for\s+you\b')) { $exampleLabels[(ConvertTo-GateNormal $m.Groups[1].Value)] = $true }
    foreach ($m in [regex]::Matches($taskLearner, '(?i)\b(\w+)\s+row\s+is\s+(?:filled|completed|done)\s+in\b')) { $exampleLabels[(ConvertTo-GateNormal $m.Groups[1].Value)] = $true }

    # cell states
    $state = @{}     # "r,c" -> prefilled | toComplete | lookup | answered
    foreach ($row in $rows) {
        for ($c = 1; $c -lt $headers.Count; $c++) {
            $bullets = @($row.Cells[$c] | Where-Object { "$_".Trim() })
            $key = "{0},{1}" -f $row.ItemIndex, $c
            if ($rowSource -eq 'prefilledRows') {
                $stub = $false
                foreach ($b in @($row.Cells[$c])) { if (Test-StubBullet -Bullet $b -BlankTokens $blanks) { $stub = $true } }
                if ($bullets.Count -eq 0) { $stub = $true }
                $state[$key] = if ($stub) { 'toComplete' } else { 'prefilled' }
            }
            else {
                if ($bullets.Count -eq 0) { $state[$key] = 'toComplete'; continue }
                $allVerbatim = $true
                foreach ($b in $bullets) { if (-not (Test-Verbatim -NeedleNorm (ConvertTo-GateNormal $b) -HayNorm $learnerAllNorm)) { $allVerbatim = $false; break } }
                $state[$key] = if ($allVerbatim) { 'lookup' } else { 'answered' }
            }
        }
    }

    # which rows are the learner's, which columns the learner writes
    $prefilledItems = New-Object System.Collections.Generic.List[string]
    $assessedItemIdx = New-Object System.Collections.Generic.List[int]
    for ($i = 0; $i -lt $items.Count; $i++) {
        $itemNorm = ConvertTo-GateNormal $items[$i]
        $row = @($rows | Where-Object { $_.ItemIndex -eq $i })
        $isExample = $exampleLabels.ContainsKey($itemNorm)
        if (-not $isExample -and $row.Count -gt 0 -and $rowSource -eq 'prefilledRows') {
            $allPre = $true
            for ($c = 1; $c -lt $headers.Count; $c++) { if ($state[("{0},{1}" -f $i, $c)] -ne 'prefilled') { $allPre = $false } }
            if ($allPre) { $isExample = $true }
        }
        if ($isExample) { $prefilledItems.Add($items[$i]) } else { $assessedItemIdx.Add($i) }
    }
    $assessedCols = New-Object System.Collections.Generic.List[int]
    if ($rows.Count -eq 0) { for ($c = 1; $c -lt $headers.Count; $c++) { $assessedCols.Add($c) } }
    else {
        for ($c = 1; $c -lt $headers.Count; $c++) {
            $any = $false
            foreach ($i in $assessedItemIdx) { $s = $state[("{0},{1}" -f $i, $c)]; if ($s -and $s -ne 'prefilled') { $any = $true } }
            if ($any) { $assessedCols.Add($c) }
        }
    }
    if ($assessedCols.Count -eq 0) { return [pscustomobject]@{ Ok = $false; Reason = 'no column is left for the learner to fill: every cell of every row is pre-printed' } }
    if ($assessedItemIdx.Count -eq 0) { return [pscustomobject]@{ Ok = $false; Reason = 'no row is left for the learner to fill: every row is a pre-printed example' } }

    # kind
    $heading = [string]$Task.Heading
    $recordScope = ConvertTo-GateNormal (($heading, ($Task.Preamble -join ' '), [string](Get-GateProp -Object $Task.Item -Names @('scenarioBox') -Default ''), [string](Get-GateProp -Object $Task.Item -Names @('stem') -Default ''), [string](Get-GateProp -Object $Part -Names @('text') -Default ''), (($Task.PartSlices[$label]) -join ' ')) -join ' ')
    $recordWord = $recordScope -match '\brecord'
    $recordCol = $false
    foreach ($h in ($headers + $items)) { if ((ConvertTo-GateNormal $h) -match '\b(time|reading|readings|initial|initials|signature|signatures|sign)\b') { $recordCol = $true } }
    $isRecordFlag = [bool](Get-GateProp -Object $Part -Names @('recordTable', 'isRecord') -Default $false)
    $allNumeric = $true
    foreach ($i in $assessedItemIdx) { if (-not (Test-NumericLabel $items[$i])) { $allNumeric = $false } }
    $allLookup = ($rows.Count -gt 0 -and $rowSource -eq 'modelRows')
    if ($allLookup) {
        foreach ($i in $assessedItemIdx) { foreach ($c in $assessedCols) { $s = $state[("{0},{1}" -f $i, $c)]; if ($s -ne 'lookup' -and $s -ne 'prefilled') { $allLookup = $false } } }
    }
    $kind = ''
    if ($recordWord -and $recordCol) { $kind = 'records' }
    elseif ($allNumeric) { $kind = 'numbered' }
    elseif ($allLookup) { $kind = 'lookup' }
    else { $kind = 'labelled' }
    if ($isRecordFlag -and $kind -ne 'records') { $notes.Add(("typed data flags this part recordTable but the derivation gives '{0}' (record word: {1}, record column: {2})" -f $kind, $recordWord, $recordCol)) }
    if ($rowSource -eq 'prefilledRows' -and $kind -ne 'records') { $notes.Add('rows come from prefilledRows (a pre-printed log) but the kind is not records - adjudicate') }

    $lookupCells = 0; $answeredCells = 0; $toCompleteCells = 0
    foreach ($i in $assessedItemIdx) { foreach ($c in $assessedCols) { switch ($state[("{0},{1}" -f $i, $c)]) { 'lookup' { $lookupCells++ } 'answered' { $answeredCells++ } 'toComplete' { $toCompleteCells++ } } } }

    # subjects
    $subjectEntries = New-Object System.Collections.Generic.List[object]
    $subjectCellsUnresolved = 0
    $subjectTexts = New-Object System.Collections.Generic.List[string]
    if ($kind -eq 'numbered' -and $rows.Count -gt 0) {
        $subjectCol = $assessedCols[0]
        foreach ($row in $rows) {
            if (-not $assessedItemIdx.Contains($row.ItemIndex)) { continue }
            $cellText = (@($row.Cells[$subjectCol]) -join ' ')
            $subjectTexts.Add($cellText)
        }
    }
    elseif ($kind -eq 'records' -and $rows.Count -gt 0) {
        foreach ($row in $rows) {
            if (-not $assessedItemIdx.Contains($row.ItemIndex)) { continue }
            for ($c = 1; $c -lt $headers.Count; $c++) { if ($state[("{0},{1}" -f $row.ItemIndex, $c)] -eq 'prefilled') { $subjectTexts.Add((@($row.Cells[$c]) -join ' ')) } }
        }
    }
    foreach ($st in $subjectTexts) {
        $hits = @(Resolve-Subject -Text $st)
        if ($hits.Count -eq 0) { $subjectCellsUnresolved++ }
        foreach ($h in $hits) { if (-not ($subjectEntries | Where-Object { $_.Class -eq $h.Class -and $_.Norm -eq $h.Norm })) { $subjectEntries.Add($h) } }
    }
    if ($kind -eq 'numbered' -and $subjectCellsUnresolved -gt 0) { $notes.Add(("{0} subject cell(s) are free text with no match in the pack vocabulary; they are answers, not subjects, and are withheld" -f $subjectCellsUnresolved)) }

    # class, from the items (labelled/lookup) or the subjects (numbered/records)
    $classCounts = @{}
    $matchedEntries = New-Object System.Collections.Generic.List[object]
    if ($kind -eq 'numbered' -or $kind -eq 'records') {
        foreach ($e in $subjectEntries) { $classCounts[$e.Class] = 1 + $(if ($classCounts.ContainsKey($e.Class)) { $classCounts[$e.Class] } else { 0 }); $matchedEntries.Add($e) }
        #  A records row names ONE subject across several pre-printed cells;
        #  count rows, or three orders in nine cells reads as a third.
        $denominator = if ($kind -eq 'records') { [math]::Max(1, $assessedItemIdx.Count) } else { [math]::Max(1, $subjectTexts.Count) }
    }
    else {
        $matchedItems = @{}
        foreach ($i in $assessedItemIdx) {
            foreach ($h in @(Resolve-Subject -Text $items[$i] -Strict)) {
                $matchedItems[$h.Class + '|' + $i] = $true
                if (-not ($matchedEntries | Where-Object { $_.Class -eq $h.Class -and $_.Norm -eq $h.Norm })) { $matchedEntries.Add($h) }
            }
        }
        foreach ($k in $matchedItems.Keys) { $cls = $k.Split('|')[0]; $classCounts[$cls] = 1 + $(if ($classCounts.ContainsKey($cls)) { $classCounts[$cls] } else { 0 }) }
        $denominator = [math]::Max(1, $assessedItemIdx.Count)
    }
    $className = ''
    $bestCount = 0
    foreach ($k in $classCounts.Keys) { if ($classCounts[$k] -gt $bestCount) { $bestCount = $classCounts[$k]; $className = $k } }
    if ($className -and $bestCount -lt [math]::Ceiling(0.5 * $denominator)) { $notes.Add(("only {0} of {1} subjects match the '{2}' class - class not assigned" -f $bestCount, $denominator, $className)); $className = '' }

    # aliases per label, and the unassessed remainder of the class
    $aliasesOut = [ordered]@{}
    $allAliasNorms = New-Object System.Collections.Generic.List[string]
    foreach ($i in $assessedItemIdx) {
        $al = @(Get-LabelAliases $items[$i])
        $aliasesOut[$items[$i]] = $al
        $allAliasNorms.Add((ConvertTo-GateNormal $items[$i]))
        foreach ($a in $al) { $allAliasNorms.Add($a) }
    }
    $unassessed = New-Object System.Collections.Generic.List[string]
    if ($className) {
        foreach ($v in $vocabByClass[$className]) {
            $isMatched = [bool]($matchedEntries | Where-Object { $_.Class -eq $v.Class -and $_.Norm -eq $v.Norm })
            if (-not $isMatched -and ($kind -eq 'labelled' -or $kind -eq 'lookup')) {
                foreach ($a in $allAliasNorms) {
                    if ($a.Length -ge 4 -and ((Test-Verbatim -NeedleNorm $a -HayNorm $v.Norm) -or (Test-Verbatim -NeedleNorm $v.Norm -HayNorm $a))) { $isMatched = $true; break }
                }
            }
            if (-not $isMatched) { $unassessed.Add($v.Name) }
        }
    }
    $subjectsOut = @($subjectEntries | Where-Object { $className -and $_.Class -eq $className } | ForEach-Object { $_.Name })
    $allowance = if ($unassessed.Count -eq 0) { 1 } else { 0 }

    # shape - numbers only
    $bMin = $null; $bMax = $null
    foreach ($row in $rows) {
        if (-not $assessedItemIdx.Contains($row.ItemIndex)) { continue }
        foreach ($c in $assessedCols) {
            $s = $state[("{0},{1}" -f $row.ItemIndex, $c)]
            if ($s -ne 'answered' -and $s -ne 'lookup') { continue }
            $n = @($row.Cells[$c] | Where-Object { "$_".Trim() }).Count
            if ($null -eq $bMin -or $n -lt $bMin) { $bMin = $n }
            if ($null -eq $bMax -or $n -gt $bMax) { $bMax = $n }
        }
    }
    if ($null -eq $bMin) { $bMin = 0; $bMax = 0; if ($kind -eq 'records') { $notes.Add('records grid: the learner supplies readings taken in production; no model cell exists, bulletsPerCell is 0') } }
    $wgText = Get-PartWordGuide -Task $Task.Item -Part $Part
    $wg = Get-WordRange $wgText
    $benchTexts = @([string](Get-GateProp -Object $Part -Names @('text') -Default ''))
    $benchMin = Get-AtLeastNumber -Texts $benchTexts
    $benchSource = if ($null -ne $benchMin) { 'learner part text' } else { '' }
    if ($null -eq $benchMin -and @($Task.Item.PSObject.Properties.Name) -contains 'assessor' -and $null -ne $Task.Item.assessor) {
        $bm = Get-PropObj $Task.Item.assessor @('benchmark')
        if ($null -ne $bm) {
            $minAcc = @(@(Get-PropList $bm @('minimumAcceptable', 'minimum')) | ForEach-Object { [string]$_ })
            $scoped = @($minAcc | Where-Object { $_ -match ('(?i)\(' + [regex]::Escape($label) + '\)') })
            if ($scoped.Count -eq 0) { $scoped = $minAcc }
            $benchMin = Get-AtLeastNumber -Texts $scoped
            if ($null -ne $benchMin) { $benchSource = 'assessor benchmark, number only' }
        }
    }
    if ($null -eq $benchMin) { $notes.Add('benchmarkMinimum not stated as a number by the part text or the benchmark; null, not guessed') }
    else { $notes.Add(('benchmarkMinimum derived from the ' + $benchSource)) }
    if ($null -eq $wg) { $notes.Add('no word guide found for this part; wordGuide is null') }

    $shape = [ordered]@{
        rows             = $assessedItemIdx.Count
        assessedColumns  = $assessedCols.Count
        bulletsPerCell   = [ordered]@{ min = $bMin; max = $bMax }
        wordGuide        = $wg
        benchmarkMinimum = $benchMin
    }

    $permitted = Get-PermittedGround -Task $Task -Part $Part -ClassName $className -Unassessed $unassessed.ToArray() -Allowance $allowance

    $entry = [ordered]@{
        ref              = $Ref
        id               = $GridId
        document         = $Task.Doc
        kind             = $kind
        headers          = $headers
        assessedHeaders  = $assessedCols.ToArray()
        items            = @($assessedItemIdx | ForEach-Object { $items[$_] })
        prefilledItems   = $prefilledItems.ToArray()
        aliases          = $aliasesOut
        subjectClass     = $className
        subjects         = $subjectsOut
        unassessedSubjects = $unassessed.ToArray()
        allowance        = $allowance
        permittedGround  = $permitted
        shape            = $shape
        cellSummary      = [ordered]@{ answered = $answeredCells; lookup = $lookupCells; toComplete = $toCompleteCells; rowSource = $rowSource }
        notes            = $notes.ToArray()
    }

    # gate-only cells
    $gateRows = New-Object System.Collections.Generic.List[object]
    foreach ($row in $rows) {
        $gateCells = New-Object System.Collections.Generic.List[object]
        for ($c = 1; $c -lt $headers.Count; $c++) {
            $s = $state[("{0},{1}" -f $row.ItemIndex, $c)]
            $bl = New-Object System.Collections.Generic.List[object]
            foreach ($b in @($row.Cells[$c] | Where-Object { "$_".Trim() })) {
                $bl.Add([ordered]@{ text = [string]$b; words = @(Add-BulletWords -Text ([string]$b)) })
                Add-Forbidden -Text ([string]$b) -MinWords 2
            }
            $gateCells.Add([ordered]@{ col = $c; header = $headers[$c]; state = $s; bullets = $bl.ToArray() })
        }
        $gateRows.Add([ordered]@{ item = $row.Item; assessed = $assessedItemIdx.Contains($row.ItemIndex); cells = $gateCells.ToArray() })
    }
    $extra = New-Object System.Collections.Generic.List[object]
    foreach ($p in @(Get-PropList $Part @('modelAnswerPoints'))) {
        $pt = [string]$p; if (-not $pt.Trim()) { continue }
        $extra.Add([ordered]@{ text = $pt; words = @(Add-BulletWords -Text $pt) })
        Add-Forbidden -Text $pt -MinWords 2
    }
    $gate = [ordered]@{
        ref = $Ref; id = $GridId; subSection = $Sub; kind = $kind; document = $Task.Doc
        headers = $headers; assessedHeaders = $assessedCols.ToArray(); rowSource = $rowSource
        rows = $gateRows.ToArray(); extraPoints = $extra.ToArray()
    }

    return [pscustomobject]@{ Ok = $true; Entry = $entry; Gate = $gate; Kind = $kind; Items = $assessedItemIdx.Count; Cols = $assessedCols.Count; Unassessed = $unassessed.Count; ClassName = $className; AllLabels = $items }
}

function New-FreeTextDerivation {
    <# A part with a response space and no grid: word budget, subjects the learner text names, permitted ground. #>
    param($Task, $Part, [string] $Ref, [string] $Sub)
    $label = [string](Get-GateProp -Object $Part -Names @('label') -Default '')
    $learner = Get-LearnerTextOfTask -Task $Task -Part $Part
    $partText = [string](Get-GateProp -Object $Part -Names @('text') -Default '')
    $sliceText = if ($Task.PartSlices.ContainsKey($label)) { ($Task.PartSlices[$label] -join ' ') } else { '' }
    #  A prose part is about what its task's scenario names: the orders, the
    #  dishes, the run. The scenario is learner-facing, so it is fair ground.
    $taskScope = [string](Get-GateProp -Object $Task.Item -Names @('scenarioBox') -Default '') + ' ' + [string](Get-GateProp -Object $Task.Item -Names @('stem') -Default '') + ' ' + ($Task.Preamble -join ' ')
    $subjectEntries = @(Resolve-Subject -Text ($partText + ' ' + $sliceText + ' ' + $taskScope))
    $classCounts = @{}
    foreach ($e in $subjectEntries) { $classCounts[$e.Class] = 1 + $(if ($classCounts.ContainsKey($e.Class)) { $classCounts[$e.Class] } else { 0 }) }
    $className = ''; $best = 0
    foreach ($k in $classCounts.Keys) { if ($classCounts[$k] -gt $best) { $best = $classCounts[$k]; $className = $k } }
    if ($className -eq 'document') { $className = '' }   # a prose part names documents as sources, not as its subjects
    $unassessed = New-Object System.Collections.Generic.List[string]
    if ($className) {
        foreach ($v in $vocabByClass[$className]) { if (-not ($subjectEntries | Where-Object { $_.Class -eq $v.Class -and $_.Norm -eq $v.Norm })) { $unassessed.Add($v.Name) } }
    }
    $allowance = if ($unassessed.Count -eq 0) { 1 } else { 0 }
    $points = @(@(Get-PropList $Part @('modelAnswerPoints')) | ForEach-Object { [string]$_ } | Where-Object { $_.Trim() })
    $wg = Get-WordRange (Get-PartWordGuide -Task $Task.Item -Part $Part)
    $benchMin = Get-AtLeastNumber -Texts @($partText)
    $lines = 0
    $rs = Get-PropObj $Part @('responseSpace')
    if ($null -ne $rs) { $lines = [int](Get-GateProp -Object $rs -Names @('lines') -Default 0) }
    $permitted = Get-PermittedGround -Task $Task -Part $Part -ClassName $className -Unassessed $unassessed.ToArray() -Allowance $allowance -Prose
    $entry = [ordered]@{
        ref = $Ref; document = $Task.Doc; kind = 'freeText'
        subjectClass = $className
        subjects = @($subjectEntries | Where-Object { $_.Class -eq $className } | ForEach-Object { $_.Name })
        unassessedSubjects = $unassessed.ToArray()
        allowance = $allowance
        permittedGround = $permitted
        shape = [ordered]@{ responseLines = $lines; modelPoints = $points.Count; wordGuide = $wg; benchmarkMinimum = $benchMin }
    }
    $bl = New-Object System.Collections.Generic.List[object]
    foreach ($p in $points) {
        $bl.Add([ordered]@{ text = $p; words = @(Add-BulletWords -Text $p) })
        Add-Forbidden -Text $p -MinWords 2
    }
    $gate = [ordered]@{ ref = $Ref; subSection = $Sub; document = $Task.Doc; bullets = $bl.ToArray() }
    return [pscustomobject]@{ Entry = $entry; Gate = $gate }
}

function Add-TaskLevelAssessor {
    <# Task-level model points and benchmark strings, gate-only, once per task. #>
    param($Task, [string] $Sub)
    $key = "{0}|{1}" -f $Task.Doc, $Task.Number
    if ($seenTaskLevel.ContainsKey($key)) { return }
    $seenTaskLevel[$key] = $true
    if (@($Task.Item.PSObject.Properties.Name) -notcontains 'assessor' -or $null -eq $Task.Item.assessor) { return }
    $asr = $Task.Item.assessor
    $strings = New-Object System.Collections.Generic.List[object]
    foreach ($p in @(Get-PropList $asr @('modelAnswerPoints'))) { $strings.Add([ordered]@{ field = 'modelAnswerPoints'; text = [string]$p }) }
    $bm = Get-PropObj $asr @('benchmark')
    if ($null -ne $bm) {
        foreach ($f in $bm.PSObject.Properties) {
            foreach ($v in (AsArr $f.Value)) { $vs = [string]$v; if ($vs.Trim()) { $strings.Add([ordered]@{ field = ('benchmark.' + $f.Name); text = $vs }) } }
        }
    }
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($s in $strings) {
        $out.Add([ordered]@{ field = $s.field; text = $s.text; words = @(Add-BulletWords -Text $s.text) })
        Add-Forbidden -Text $s.text -MinWords 3
    }
    $assessorTaskLevel.Add([ordered]@{ document = $Task.Doc; task = $Task.Number; heading = $Task.Heading; firstSubSection = $Sub; strings = $out.ToArray() })
}

# ---- walk the question map
foreach ($sub in $subSectionKeys) {
    $refs = @(AsArr $questionMap.$sub | ForEach-Object { [string]$_ } | Where-Object { $_.Trim() })
    $entry = [ordered]@{
        subSection   = $sub
        refs         = $refs
        tasks        = New-Object System.Collections.Generic.List[object]
        freeText     = New-Object System.Collections.Generic.List[object]
        observations = New-Object System.Collections.Generic.List[object]
        taskKeys     = New-Object System.Collections.Generic.List[string]   # doc|n|part, for tasks.md
    }
    foreach ($ref in $refs) {
        $res = Resolve-Reference -Ref $ref
        if ($res.Kind -eq 'observation') {
            $obsHeading = ''
            foreach ($dn in ($learnerDocs.Keys | Sort-Object)) {
                $ld = $learnerDocs[$dn]
                for ($i = 0; $i -lt $ld.Norms.Count; $i++) {
                    if ($ld.Norms[$i] -match ('^observation\s*' + $res.Number + '(?!\d)') -and $ld.Lines[$i] -notmatch 'PAGEREF') { $obsHeading = $ld.Lines[$i].Trim(); $entry.taskKeys.Add(("{0}|obs|{1}" -f $dn, $res.Number)); break }
                }
                if ($obsHeading) { break }
            }
            $entry.observations.Add([ordered]@{ ref = $ref; number = $res.Number; heading = (ConvertTo-AsciiText $obsHeading); note = 'assessor-completed checklist; the learner writes nothing on it; no answer grid' })
            continue
        }
        if ($null -eq $res.Task) {
            $unresolved.Add([ordered]@{ subSection = $sub; ref = $ref; reason = $res.Reason })
            $unclassified.Add([ordered]@{ subSection = $sub; ref = $ref; reason = ('reference not resolved: ' + $res.Reason) })
            continue
        }
        $tk = $res.Task
        $part = $null
        if ($res.Part) { $part = @($tk.Parts | Where-Object { ([string](Get-GateProp -Object $_ -Names @('label') -Default '')).ToLowerInvariant() -eq $res.Part }) | Select-Object -First 1 }
        if ($null -eq $part) {
            if (-not $res.Part -and $tk.Parts.Count -eq 1) { $part = $tk.Parts[0] }
            else {
                $unclassified.Add([ordered]@{ subSection = $sub; ref = $ref; reason = ("part '{0}' not found on typed task {1} in {2} (parts: {3})" -f $res.Part, $tk.Number, $tk.File, ((($tk.Parts | ForEach-Object { [string](Get-GateProp -Object $_ -Names @('label') -Default '?') })) -join ', ')) })
                continue
            }
        }
        $partLabel = [string](Get-GateProp -Object $part -Names @('label') -Default '')
        $entry.taskKeys.Add(("{0}|{1}|{2}" -f $tk.Doc, $tk.Number, $partLabel))
        Add-TaskLevelAssessor -Task $tk -Sub $sub

        $hasGrid = (@($part.PSObject.Properties.Name) -contains 'itemTable') -and ($null -ne $part.itemTable)
        if ($hasGrid) {
            $gridId = "{0} Task {1}({2})" -f $tk.Doc, $tk.Number, $partLabel
            if (-not $tk.Doc) { $gridId = "Task {0}({1})" -f $tk.Number, $partLabel }
            $d = New-GridDerivation -Task $tk -Part $part -Ref $ref -GridId $gridId -Sub $sub
            if (-not $d.Ok) {
                $unclassified.Add([ordered]@{ subSection = $sub; ref = $ref; reason = $d.Reason })
                $summaryRows.Add([pscustomobject]@{ Ref = $ref; Sub = $sub; Kind = 'UNCLASSIFIED'; Items = 0; Cols = 0; Unassessed = 0; Class = ''; Note = $d.Reason })
                # the gate can still use the labels
                $labels = @(@(Get-PropList $part.itemTable @('items')) | ForEach-Object { [string]$_ })
                if ($labels.Count -gt 0 -and -not $seenGridIds.ContainsKey($gridId)) {
                    $seenGridIds[$gridId] = $true
                    $gridsOut.Add([ordered]@{ doc = $tk.Doc; id = $gridId; ref = $ref; labels = $labels; headers = @(@(Get-PropList $part.itemTable @('headers')) | ForEach-Object { [string]$_ }); kind = 'unclassified' })
                }
                continue
            }
            $entry.tasks.Add($d.Entry)
            $assessorGrids.Add($d.Gate)
            $summaryRows.Add([pscustomobject]@{ Ref = $ref; Sub = $sub; Kind = $d.Kind; Items = $d.Items; Cols = $d.Cols; Unassessed = $d.Unassessed; Class = $d.ClassName; Note = '' })
            if (-not $seenGridIds.ContainsKey($gridId)) {
                $seenGridIds[$gridId] = $true
                $gridsOut.Add([ordered]@{ doc = $tk.Doc; id = $gridId; ref = $ref; labels = @($d.AllLabels); headers = @($d.Entry.headers); kind = $d.Kind })
            }
        }
        else {
            $f = New-FreeTextDerivation -Task $tk -Part $part -Ref $ref -Sub $sub
            $entry.freeText.Add($f.Entry)
            $assessorFree.Add($f.Gate)
        }
    }
    $register[$sub] = $entry
}

# ---------------------------------------------------------------------------
# 6. Content-word sets: strip the task's own learner words and the common words
# ---------------------------------------------------------------------------

$df = @{}
foreach ($set in $allBulletWordSets) { foreach ($w in @($set | Select-Object -Unique)) { $df[$w] = 1 + $(if ($df.ContainsKey($w)) { $df[$w] } else { 0 }) } }
$bulletTotal = [math]::Max(1, $allBulletWordSets.Count)
$common = @{}
foreach ($w in $df.Keys) { if (($df[$w] / [double]$bulletTotal) -gt $DfCeiling) { $common[$w] = $true } }

$learnerWordsByTask = @{}
function Get-TaskLearnerWordSet {
    param([string] $Doc, [int] $Number)
    $key = "{0}|{1}" -f $Doc, $Number
    if ($learnerWordsByTask.ContainsKey($key)) { return $learnerWordsByTask[$key] }
    $set = @{}
    foreach ($tk in $tasks) {
        if ($tk.Doc -ne $Doc -or $tk.Number -ne $Number) { continue }
        foreach ($p in $tk.Parts) { foreach ($w in (Get-Words (Get-LearnerTextOfTask -Task $tk -Part $p) -KeepNumbers)) { $set[$w] = $true } }
    }
    $learnerWordsByTask[$key] = $set
    return $set
}
function Select-ContentWords {
    param([string[]] $Words, [hashtable] $Exclude)
    return @($Words | Where-Object { $_ -and -not $Exclude.ContainsKey($_) -and -not $common.ContainsKey($_) })
}
foreach ($g in $assessorGrids) {
    $num = 0; if ($g.id -match 'Task (\d+)\(') { $num = [int]$Matches[1] }
    $ex = Get-TaskLearnerWordSet -Doc $g.document -Number $num
    foreach ($row in $g.rows) { foreach ($cell in $row.cells) { foreach ($b in $cell.bullets) { $b.words = Select-ContentWords -Words $b.words -Exclude $ex } } }
    foreach ($b in $g.extraPoints) { $b.words = Select-ContentWords -Words $b.words -Exclude $ex }
}
foreach ($f in $assessorFree) {
    $num = 0; if ($f.ref -match '(\d+)\s*\(') { $num = [int]$Matches[1] }
    $ex = Get-TaskLearnerWordSet -Doc $f.document -Number $num
    foreach ($b in $f.bullets) { $b.words = Select-ContentWords -Words $b.words -Exclude $ex }
}
foreach ($tl in $assessorTaskLevel) {
    $ex = Get-TaskLearnerWordSet -Doc $tl.document -Number $tl.task
    foreach ($s in $tl.strings) { $s.words = Select-ContentWords -Words $s.words -Exclude $ex }
}

# ---------------------------------------------------------------------------
# 7. Write the four outputs
# ---------------------------------------------------------------------------

$stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm')
$provenance = [ordered]@{
    generatedOn = $stamp
    generatedBy = (Split-Path (Get-ScriptPath) -Leaf)
    buildDir    = $BuildDir
    packDir     = $PackDir
    corpusDir   = $corpusDirResolved
    typedTaskFiles = @($taskFiles | ForEach-Object { $_.Name })
    unitExtract = $(if ($UnitExtract) { $UnitExtract } else { '' })
}

# A. grids.json - into the corpus directory the gates resolve
$gridsPath = Join-Path $corpusDirResolved 'grids.json'
Write-AsciiJson -Object ([ordered]@{
    _purpose = 'Assessed response grids, typed. Check-FigureMirror prefers this file over its regex parse of the learner text. Labels only - no model cells.'
    generated = $provenance
    grids = $gridsOut.ToArray()
}) -Path $gridsPath

# document facts for the register
$documentsOut = [ordered]@{}
foreach ($dn in ($learnerDocs.Keys | Sort-Object)) {
    $documentsOut[$dn] = [ordered]@{
        audience = 'learner'
        referencePattern = $docPatterns[$dn]
        openBook = [bool]($learnerDocs[$dn].OpenBook -and $learnerDocs[$dn].OpenBook -notmatch '(?i)\bnot\s+open[\s-]?book\b')
        openBookStatement = (ConvertTo-AsciiText $learnerDocs[$dn].OpenBook)
    }
}
$vocabOut = [ordered]@{}
foreach ($cls in ($vocabByClass.Keys | Sort-Object)) { $vocabOut[$cls] = @($vocabByClass[$cls] | ForEach-Object { $_.Name }) }

# B. withhold-register.json
$registerSubs = [ordered]@{}
foreach ($sub in $subSectionKeys) {
    $e = $register[$sub]
    $registerSubs[$sub] = [ordered]@{
        subSection   = $sub
        refs         = $e.refs
        tasks        = $e.tasks.ToArray()
        freeText     = $e.freeText.ToArray()
        observations = $e.observations.ToArray()
    }
}
$registerDoc = [ordered]@{
    _purpose = 'What a content agent may be told about every assessed task: the SHAPE of each grid, its labels and aliases, the subjects it assesses and the subjects of the same class it does not. No model cell, benchmark or marking text appears here; the generator sweeps this file for every model bullet before it exits.'
    _fields  = [ordered]@{
        kind = 'labelled (the task prints the row labels) | numbered (the learner chooses the items) | records (a log the learner completes in production) | lookup (every assessed cell is a value read from a learner-held document)'
        assessedHeaders = 'indices into headers of the columns the learner writes'
        subjects = 'numbered and records grids only: the pack-vocabulary names the model draws on, resolved to the learner-held vocabulary; never the cell text'
        unassessedSubjects = 'the subjects of the same class the task does NOT assess - the only subjects a worked example may be set on'
        allowance = '0 wherever unassessedSubjects is non-empty; 1 only where the task assesses every subject there is or has no subject class'
        permittedGround = 'one line: what the learner holds during the task, and where examples may be set'
        shape = 'numbers only: rows, assessedColumns, bulletsPerCell {min,max}, wordGuide {min,max}, benchmarkMinimum'
        freeText = 'parts answered in prose (no grid); the same subject and allowance rules apply to worked examples in prose'
    }
    generated    = $provenance
    unit         = $unitCode
    documents    = $documentsOut
    vocabulary   = $vocabOut
    subSections  = $registerSubs
    unclassified = $unclassified.ToArray()
    unresolvedReferences = $unresolved.ToArray()
}
$registerPath = Join-Path $BuildDir 'withhold-register.json'
Write-AsciiJson -Object $registerDoc -Path $registerPath

# C. assessor-cells.json - gate-only
$assessorDoc = [ordered]@{
    _WARNING = 'GATE-ONLY. This file carries the assessor model cells and benchmark strings for every assessed task. It must never be given to a content agent, never copied into agent-pack, and never opened by anyone writing content. An answer that is read is an answer that gets written: on the build that produced this file, agents handed the assessor guides to gauge depth wrote the model answers into an open-book guide. Gates read this file; authors do not.'
    generated = $provenance
    wordPipeline = [ordered]@{
        normalise = 'lower case, letters digits and single spaces only (Lib-GateCommon ConvertTo-GateNormal)'
        stem      = 'crude suffix strip: ing, ed, es, s'
        stopwords = $STOPWORDS.Count
        stripLearnerWords = 'every word in the learner-facing text of the same task: heading, scenario, stem, part text, headers, items, word guide'
        dfCeiling = $DfCeiling
        commonWordsRemoved = @($common.Keys | Sort-Object)
        bulletCount = $bulletTotal
    }
    grids     = $assessorGrids.ToArray()
    freeText  = $assessorFree.ToArray()
    taskLevel = $assessorTaskLevel.ToArray()
}
$assessorPath = Join-Path $BuildDir 'assessor-cells.json'
Write-AsciiJson -Object $assessorDoc -Path $assessorPath

# D. agent-pack\<sub-section>\
$packRoot = Join-Path $BuildDir 'agent-pack'
if (Test-Path -LiteralPath $packRoot) { Remove-Item -LiteralPath $packRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path $packRoot | Out-Null
$sharedDir = Join-Path $packRoot '_shared'
New-Item -ItemType Directory -Force -Path (Join-Path $sharedDir 'learner-docs') | Out-Null
foreach ($dn in $learnerDocs.Keys) {
    # learner-held ground, copied so no agent has a reason to browse the corpus directory beside the assessor guides
    Write-AsciiText -Text ($learnerDocs[$dn].Lines -join "`r`n") -Path (Join-Path (Join-Path $sharedDir 'learner-docs') ($dn + '.txt'))
}
if ($UnitExtract -and (Test-Path -LiteralPath $UnitExtract)) { Write-AsciiText -Text (Get-GateFileText -Path $UnitExtract) -Path (Join-Path $sharedDir (Split-Path $UnitExtract -Leaf)) }

$contractBytes = [System.IO.File]::ReadAllBytes((Join-Path $BuildDir 'contract.json'))
$learnerDocList = (($learnerDocs.Keys | Sort-Object | ForEach-Object { $_ + '.txt' }) -join ', ')
$assessorDocList = ((@($corpus.Assessor) | ForEach-Object { $_.Name + '.txt' }) -join ', ')

function Write-TasksMd {
    param([string] $Sub, $Entry, [string] $Path)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine(("# Sub-section {0} - the assessed tasks, learner-facing text only" -f $Sub))
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine(("Source: the learner-facing extraction of the assessment tools ({0}), sliced at the task and part the question map assigns. Nothing here comes from an assessor guide, a model row or a benchmark." -f $learnerDocList))
    [void]$sb.AppendLine(("References prepared here: {0}" -f ($Entry.refs -join '; ')))
    [void]$sb.AppendLine('')
    $doneTask = @{}
    foreach ($key in $Entry.taskKeys) {
        $bits = $key.Split('|')
        $dn = $bits[0]
        if ($bits[1] -eq 'obs') {
            $num = [int]$bits[2]
            $ld = $learnerDocs[$dn]
            $start = -1
            for ($i = 0; $i -lt $ld.Norms.Count; $i++) { if ($ld.Norms[$i] -match ('^observation\s*' + $num + '(?!\d)') -and $ld.Lines[$i] -notmatch 'PAGEREF') { $start = $i; break } }
            if ($start -lt 0) { continue }
            $end = $ld.Lines.Count
            for ($i = $start + 1; $i -lt $ld.Lines.Count; $i++) { if ($ld.Norms[$i] -match '^observation\s*\d+(?!\d)' -or ($ld.Boundaries.ContainsKey($ld.Norms[$i]) -and $ld.Norms[$i])) { $end = $i; break } }
            [void]$sb.AppendLine(("## Observation {0}  [{1}]" -f $num, $dn))
            [void]$sb.AppendLine('The assessor completes this sheet in the kitchen; the learner writes nothing on it. It is reproduced because it is printed in the learner-held workbook. It has no answer grid.')
            [void]$sb.AppendLine('')
            foreach ($ln in $ld.Lines[$start..($end - 1)]) { [void]$sb.AppendLine($ln) }
            [void]$sb.AppendLine('')
            continue
        }
        $num = [int]$bits[1]; $partLabel = $bits[2]
        $tk = @($tasks | Where-Object { $_.Doc -eq $dn -and $_.Number -eq $num }) | Select-Object -First 1
        if ($null -eq $tk) { continue }
        $tkey = "{0}|{1}" -f $dn, $num
        if (-not $doneTask.ContainsKey($tkey)) {
            $doneTask[$tkey] = $true
            [void]$sb.AppendLine(("## {0}  [{1}]" -f $tk.Heading, $(if ($dn) { $dn } else { $tk.File })))
            [void]$sb.AppendLine('')
            if ($tk.Preamble.Count -gt 0) { foreach ($ln in $tk.Preamble) { if ($ln -ne $tk.Preamble[0] -or $ln.Trim() -ne $tk.Heading.Trim()) { [void]$sb.AppendLine($ln) } } }
            else {
                foreach ($f in @('scenarioBox', 'stem', 'wordGuide')) { $v = [string](Get-GateProp -Object $tk.Item -Names @($f) -Default ''); if ($v) { [void]$sb.AppendLine($v) } }
            }
            [void]$sb.AppendLine('')
        }
        [void]$sb.AppendLine(("### Part ({0})" -f $partLabel))
        if ($tk.PartSlices.ContainsKey($partLabel)) { foreach ($ln in $tk.PartSlices[$partLabel]) { [void]$sb.AppendLine($ln) } }
        else {
            $part = @($tk.Parts | Where-Object { ([string](Get-GateProp -Object $_ -Names @('label') -Default '')) -eq $partLabel }) | Select-Object -First 1
            if ($null -ne $part) {
                [void]$sb.AppendLine('(typed learner fields - the printed part was not found in the learner document)')
                [void]$sb.AppendLine(("({0})  {1}" -f $partLabel, [string](Get-GateProp -Object $part -Names @('text') -Default '')))
                $wgt = Get-PartWordGuide -Task $tk.Item -Part $part
                if ($wgt) { [void]$sb.AppendLine('Word guide: ' + $wgt) }
                if (@($part.PSObject.Properties.Name) -contains 'itemTable' -and $null -ne $part.itemTable) {
                    [void]$sb.AppendLine('Columns: ' + ((AsArr $part.itemTable.headers) -join ' | '))
                    [void]$sb.AppendLine('Rows: ' + ((AsArr $part.itemTable.items) -join ' | '))
                }
            }
        }
        [void]$sb.AppendLine('')
    }
    Write-AsciiText -Text $sb.ToString() -Path $Path
}

function Write-ReadmeMd {
    param([string] $Sub, $Entry, [string] $Path)
    $gridRefs = @($Entry.tasks | ForEach-Object { "{0} ({1}, allowance {2})" -f $_.ref, $_.kind, $_.allowance })
    $freeRefs = @($Entry.freeText | ForEach-Object { "{0} (prose, allowance {1})" -f $_.ref, $_.allowance })
    $obsRefs  = @($Entry.observations | ForEach-Object { $_.ref })
    $t = @"
# Agent pack for sub-section $Sub - read this before you write a word

## What is in this directory

- contract.json - the build contract, verbatim. Your references are questionMap["$Sub"] and nothing else.
- tasks.md - the learner-facing text of every task this sub-section prepares: stem, scenario, column headers, row labels and word guide, sliced from the learner's own copy of the tool ($learnerDocList). Teach toward it; never restate it.
- withhold.json - one entry per assessed task under "tasks": kind, headers, assessedHeaders, items, subjects, unassessedSubjects, allowance, permittedGround and shape. Numbers and learner-held names only. Parts answered in prose are under "freeText" with the same subject and allowance fields.
- ..\_shared\learner-docs\ - the learner-held documents in full (the appendices, the recipe cards, the observation sheets as the learner sees them) and the unit extract. These are the only documents under agent-pack, and every one of them is on the learner's desk.

Tasks in this pack: $(if ($gridRefs.Count) { $gridRefs -join '; ' } else { 'none with a grid' })
Prose parts: $(if ($freeRefs.Count) { $freeRefs -join '; ' } else { 'none' })
Observations: $(if ($obsRefs.Count) { $obsRefs -join '; ' } else { 'none' })

## What is deliberately NOT here, and why

- The assessor guides ($(if ($assessorDocList) { $assessorDocList } else { 'the assessor-only extractions' })), the model rows, the model answer points, the benchmarks, the marking criteria and the worked keys. None of it is in this directory and nothing in the brief sends you to it. If a path to one is within your reach, do not open it.
- assessor-cells.json, which the build keeps for its gates. It is not an input to content.
- Why: on an earlier build of this family, the content agents were handed the assessor guides "for one purpose only, to gauge depth". Every agent wrote the model answers into the Learner Guide - same items, same order, same words - and the guide is expressly permitted in an open-book assessment, so the completed answer sheet sat on the learner's desk. Six audit rounds then found the leak one location at a time. An answer that is read is an answer that gets written. Depth now comes from shape; the answer is never within reach.
- No answer guide is expected from you. selfCheck.answerGuide is not authored: the guide is permitted in the open-book assessment, and an answer key on the learner's desk is a marking guide. Write selfCheck.questions only.

## How to read withhold.json

- shape tells you how deep to teach: rows x assessedColumns cells, bulletsPerCell points per cell, wordGuide words per cell, benchmarkMinimum points a Satisfactory cell must carry (null where the pack does not state it as a number). A cell needing 30 to 50 words and two points tells you the depth; the answer does not, and you have not seen it.
- unassessedSubjects is the ONLY set a worked example, activity table, figure table or slide table may be set on. allowance is 0 wherever that set is non-empty; where it is 1, exactly one assessed row may be worked in the whole sub-section and every other row carries the withhold token.
- For a numbered task, never pair any listed subject with the reasons the task asks for. For a records task, work the record on a run or date from permittedGround. For a lookup task, teach how to read the document the value lives in and never state the value.
- items are the row labels the task prints; aliases are their head nouns, singulars and and-splits, so a row label reworded is still the row label.

Generated $stamp by $(Split-Path (Get-ScriptPath) -Leaf). Every list above is derived from the typed task data, the build contract and the learner-facing corpus; none of it is typed by hand.
"@
    Write-AsciiText -Text $t -Path $Path
}

foreach ($sub in $subSectionKeys) {
    $dir = Join-Path $packRoot $sub
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    [System.IO.File]::WriteAllBytes((Join-Path $dir 'contract.json'), $contractBytes)
    $slice = [ordered]@{
        _purpose   = $registerDoc._purpose
        _fields    = $registerDoc._fields
        generated  = $provenance
        unit       = $unitCode
        documents  = $documentsOut
        vocabulary = $vocabOut
        subSection = $registerSubs[$sub]
        unclassifiedInThisSubSection = @($unclassified | Where-Object { $_.subSection -eq $sub })
    }
    Write-AsciiJson -Object $slice -Path (Join-Path $dir 'withhold.json')
    Write-TasksMd -Sub $sub -Entry $register[$sub] -Path (Join-Path $dir 'tasks.md')
    Write-ReadmeMd -Sub $sub -Entry $registerSubs[$sub] -Path (Join-Path $dir 'README.md')
}

# ---------------------------------------------------------------------------
# 8. Prove it: no assessor-authored string in any agent-facing file
# ---------------------------------------------------------------------------

$forbiddenSet = @($forbidden | Select-Object -Unique)
$leaks = New-Object System.Collections.Generic.List[string]
function Test-FileForLeaks {
    param([string] $Path, [string] $Label)
    $txt = ConvertTo-GateNormal (ConvertFrom-JsonEscape (Get-GateFileText -Path $Path))
    $n = 0
    foreach ($fb in $forbiddenSet) {
        if (Test-Verbatim -NeedleNorm $fb -HayNorm $txt) { $n++; if ($n -le 3) { $leaks.Add(("{0}: '{1}'" -f $Label, $fb)) } }
    }
    if ($n -gt 3) { $leaks.Add(("{0}: ... {1} more" -f $Label, ($n - 3))) }
    return $n
}
$leakCount = 0
$leakCount += Test-FileForLeaks -Path $registerPath -Label 'withhold-register.json'
$leakCount += Test-FileForLeaks -Path $gridsPath -Label 'grids.json'
foreach ($f in (Get-ChildItem -LiteralPath $packRoot -Recurse -File | Where-Object { $_.FullName -notlike ('*' + [System.IO.Path]::DirectorySeparatorChar + '_shared' + [System.IO.Path]::DirectorySeparatorChar + '*') })) {
    $rel = $f.FullName.Substring($packRoot.Length + 1)
    $leakCount += Test-FileForLeaks -Path $f.FullName -Label ('agent-pack\' + $rel)
}

# and the gate file must actually carry them, or a gate reading it checks nothing
$assessorTxt = ConvertTo-GateNormal (ConvertFrom-JsonEscape (Get-GateFileText -Path $assessorPath))
$missingFromGate = 0
foreach ($fb in $forbiddenSet) { if (-not (Test-Verbatim -NeedleNorm $fb -HayNorm $assessorTxt)) { $missingFromGate++ } }

# and the gate's own loader must see the grids
$reload = Get-GateJson -Path $gridsPath
$reloaded = @(Get-GateProp -Object $reload -Names @('grids', 'responseGrids') -Default @())
$loadable = 0
foreach ($g in $reloaded) {
    $labels = @(@(Get-GateProp -Object $g -Names @('labels', 'rowLabels') -Default @()) | ForEach-Object { ConvertTo-GateNormal $_ } | Where-Object { $_ })
    if ($labels.Count -gt 0) { $loadable++ }
}

# ---------------------------------------------------------------------------
# 9. Report
# ---------------------------------------------------------------------------

Say ''
Say 'ASSESSED GRIDS' 'Cyan'
Say ("  {0,-26} {1,-5} {2,-12} {3,5} {4,5} {5,10}  {6}" -f 'reference', 'sub', 'kind', 'items', 'cols', 'unassessed', 'class / note') 'DarkGray'
foreach ($r in $summaryRows) {
    $colour = if ($r.Kind -eq 'UNCLASSIFIED') { 'Yellow' } else { 'Gray' }
    $tail = if ($r.Note) { $r.Note } else { $r.Class }
    Say ("  {0,-26} {1,-5} {2,-12} {3,5} {4,5} {5,10}  {6}" -f $r.Ref, $r.Sub, $r.Kind, $r.Items, $r.Cols, $r.Unassessed, $tail) $colour
}
$kindCounts = @{}
foreach ($r in $summaryRows) { $kindCounts[$r.Kind] = 1 + $(if ($kindCounts.ContainsKey($r.Kind)) { $kindCounts[$r.Kind] } else { 0 }) }
Say ("  {0} grids: {1}; {2} prose parts; {3} observation references" -f $summaryRows.Count, (($kindCounts.Keys | Sort-Object | ForEach-Object { "{0} {1}" -f $kindCounts[$_], $_ }) -join ', '), $assessorFree.Count, (@($subSectionKeys | ForEach-Object { $register[$_].observations.Count } | Measure-Object -Sum).Sum)) 'DarkGray'

if ($unclassified.Count -gt 0) {
    Say ''
    Say ("  {0} reference(s) unclassified - for a human to adjudicate:" -f $unclassified.Count) 'Yellow'
    foreach ($u in $unclassified) { Say ("    {0}  {1}: {2}" -f $u.subSection, $u.ref, $u.reason) 'Yellow' }
}

Say ''
Say 'WRITTEN' 'Cyan'
Say ("  grids.json            {0}  ({1} grids, {2} loadable by the mirror gate)" -f $gridsPath, $gridsOut.Count, $loadable) 'Gray'
if ($corpusDirResolved -ne (Join-Path $BuildDir 'corpus')) {
    Say ("    note: the gates resolve the corpus to '{0}' because that is where the .txt extraction lives; Check-FigureMirror reads grids.json from the corpus it resolves, so that is where it is written." -f (Split-Path $corpusDirResolved -Leaf)) 'DarkGray'
}
Say ("  withhold-register.json {0}" -f $registerPath) 'Gray'
Say ("  assessor-cells.json    {0}  (GATE-ONLY; {1} forbidden strings, {2} common words stripped)" -f $assessorPath, $forbiddenSet.Count, $common.Count) 'Gray'
Say ("  agent-pack\            {0}  ({1} sub-sections + _shared)" -f $packRoot, $subSectionKeys.Count) 'Gray'
if ($script:asciiLossCount -gt 0) { Say ("  {0} non-ASCII character(s) with no transliteration were written as '?'" -f $script:asciiLossCount) 'DarkGray' }

Say ''
$rc = 0
if ($leakCount -gt 0) {
    Write-Host ("  X {0} assessor-authored string(s) found in agent-facing output:" -f $leakCount) -ForegroundColor Red
    foreach ($l in $leaks) { Write-Host ("     {0}" -f $l) -ForegroundColor Red }
    Write-Host '  The agent-pack is removed. Nothing half-safe is handed to an agent.' -ForegroundColor Red
    Remove-Item -LiteralPath $packRoot -Recurse -Force -ErrorAction SilentlyContinue
    $rc = 1
}
else { Say ("  ok  none of the {0} assessor-authored strings appears in the register, grids.json or any agent-pack file" -f $forbiddenSet.Count) 'Green' }
if ($missingFromGate -gt 0) {
    Write-Host ("  X {0} forbidden string(s) are missing from assessor-cells.json - a gate reading it would check less than it claims" -f $missingFromGate) -ForegroundColor Red
    $rc = 1
}
else { Say '  ok  assessor-cells.json carries every one of them' 'Green' }
if ($loadable -eq 0) {
    Write-Host '  X grids.json carries no grid the mirror gate could load' -ForegroundColor Red
    $rc = 1
}
if ($unresolved.Count -gt 0) { Say ("  !  {0} question-map reference(s) could not be resolved to a typed task; listed in the register under unresolvedReferences" -f $unresolved.Count) 'Yellow' }
exit $rc
