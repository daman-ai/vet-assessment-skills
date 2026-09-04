<#
  Test-ObservationComments.ps1 — check assessor comments for an observation
  sheet against the house standard in references/observation-comments.md.

  It checks the countable rules on every comment, and the UNIQUENESS rules
  across the whole cohort at once — which is the point. A comment reads fine on
  its own and still fails the standard because the comment above it opens the
  same way, and no amount of reading them one at a time will show that.

  WHAT IT CANNOT CHECK. Whether the three specifics are really this student's,
  whether the order described is the order that happened, whether the tone is a
  working assessor's. Those stay with the person signing. What this script does
  is take the mechanical rules off their plate so their attention goes to the
  ones that matter.

  Input — a JSON array, one entry per comments area:

    [ { "student": "Amara Nwosu", "box": "Occasion 1", "text": "…" },
      { "student": "Tomas Ruiz",  "box": "Occasion 1", "text": "…" } ]

  Usage:
    .\Test-ObservationComments.ps1 -Path comments.json
    .\Test-ObservationComments.ps1 -Text "<comment>" -Student "Amara Nwosu" -Box "Occasion 1"
    .\Test-ObservationComments.ps1 -Path comments.json -Json
#>
[CmdletBinding()]
param(
    [string]$Path,
    [string]$Text,
    [string]$Student = 'student',
    [string]$Box = 'comment',
    [int]$MaxSentencesPerParagraph = 2,
    [int]$MaxWordsPerParagraph = 20,
    [int]$MinParagraphs = 2,
    [int]$MaxParagraphs = 2,
    [int]$PhraseWords = 5,
    [switch]$Json,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-Text.ps1')

# Phrases the standard names outright, plus the near neighbours of each. They
# are the ones that turn a record of what happened into a school report.
$BANNED = @(
    'demonstrated a sound understanding',
    'demonstrated a strong understanding',
    'sound understanding',
    'showcased',
    'effectively utilised',
    'effectively utilized',
    'utilised',
    'utilized',
    'a high level of',
    'in a timely manner',
    'went above and beyond'
)

# First and second person. These comments are a third-person record.
$PERSON = @('\bI\b', '\bwe\b', '\bour\b', '\byou\b', '\byour\b', '\bmy\b')

function Split-Paragraphs {
    <#
      Blank-line separated blocks where the writer used them, single lines
      otherwise. A comment pasted out of Word arrives one way; a comment typed
      into a JSON string arrives the other.
    #>
    param([string]$Body)
    if (-not $Body) { return @() }
    $blocks = [regex]::Split($Body.Trim(), '(\r?\n)[ \t]*(\r?\n)+')
    $blocks = @($blocks | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' -and $_ -notmatch '^[\r\n]+$' })
    if ($blocks.Count -le 1) {
        $blocks = @($Body -split '\r?\n' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    }
    @($blocks)
}

function Get-Words {
    param([string]$s)
    @($s -split '\s+' | Where-Object { $_ -ne '' })
}

function Get-Normalised {
    <# lower case, punctuation stripped, whitespace collapsed — for comparing. #>
    param([string]$s)
    (($s -replace "[^\p{L}\p{Nd}\s]", ' ') -replace '\s+', ' ').Trim().ToLowerInvariant()
}

function Get-Phrases {
    <# every $n-word sequence in $s, normalised. #>
    param([string]$s, [int]$n)
    $w = Get-Words (Get-Normalised $s)
    $out = @()
    if ($w.Count -lt $n) { return $out }
    for ($i = 0; $i -le $w.Count - $n; $i++) { $out += ($w[$i..($i + $n - 1)] -join ' ') }
    $out
}

# ------------------------------------------------------------------ input ----

$comments = @()
if ($Text) {
    $comments += [pscustomobject]@{ student = $Student; box = $Box; text = $Text }
} elseif ($Path) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "Not found: $Path" }
    # ConvertFrom-Json hands a JSON array down the pipeline as ONE item in
    # PowerShell 5.1, so piping it straight into @() wraps the array instead of
    # flattening it — and a whole cohort silently becomes one comment whose
    # student is every name joined together. Assign first, then flatten.
    $parsed = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
    foreach ($item in @($parsed)) { $comments += $item }
} else {
    throw 'Supply -Path (a JSON array of comments) or -Text with -Student and -Box.'
}

$comments = @($comments | ForEach-Object {
    [pscustomobject]@{
        student = $(if ($_.student) { "$($_.student)" } else { 'student' })
        box     = $(if ($_.box)     { "$($_.box)" }     else { 'comment' })
        text    = "$($_.text)"
    }
})
if ($comments.Count -eq 0) { throw 'No comments to check.' }

# ------------------------------------------------- per-comment rule checks ----

$findings = @()
function Add-Finding {
    param([string]$Who, [string]$Rule, [string]$Detail, [string]$Severity = 'FAIL')
    $script:findings += [pscustomobject]@{ where = $Who; rule = $Rule; severity = $Severity; detail = $Detail }
}

foreach ($c in $comments) {
    $who = "$($c.student) / $($c.box)"

    if (-not $c.text.Trim()) { Add-Finding $who 'Empty' 'no comment text'; continue }

    $paras = Split-Paragraphs $c.text
    if ($paras.Count -lt $MinParagraphs -or $paras.Count -gt $MaxParagraphs) {
        Add-Finding $who 'ParagraphCount' "$($paras.Count) paragraph(s); the standard is $MinParagraphs to $MaxParagraphs"
    }

    $pi = 0
    foreach ($p in $paras) {
        $pi++
        $sentences = @(Split-Sentences $p)
        if ($sentences.Count -gt $MaxSentencesPerParagraph) {
            Add-Finding $who 'SentencesPerParagraph' "paragraph ${pi}: $($sentences.Count) sentences, limit is $MaxSentencesPerParagraph"
        }
        $wc = (Get-Words $p).Count
        if ($wc -gt $MaxWordsPerParagraph) {
            Add-Finding $who 'WordsPerParagraph' "paragraph ${pi}: $wc words, limit is $MaxWordsPerParagraph"
        }
        foreach ($h in @(Get-OverLongSentences -Text $p -MaxCommas (Get-FeedbackMaxCommas))) {
            Add-Finding $who 'CommasPerSentence' "paragraph ${pi}: $($h.commas) commas in one sentence, limit is $(Get-FeedbackMaxCommas) — `"$($h.sentence)`""
        }
    }

    $flat = Get-Normalised $c.text
    foreach ($b in $BANNED) {
        if ($flat -match [regex]::Escape((Get-Normalised $b))) {
            Add-Finding $who 'BannedPhrase' "uses '$b' — say what the student did instead"
        }
    }
    foreach ($rx in $PERSON) {
        if ($c.text -cmatch $rx) {
            Add-Finding $who 'Person' "contains $rx — these comments are past tense and third person"
        }
    }

    # Opening words repeated inside one comment. The standard asks for varied
    # openings; the surname opening every sentence is the named failure.
    $allSentences = @()
    foreach ($p in $paras) { $allSentences += @(Split-Sentences $p) }
    $openers = @($allSentences | ForEach-Object { (Get-Words (Get-Normalised $_))[0] } | Where-Object { $_ })
    $dupOpen = @($openers | Group-Object | Where-Object { $_.Count -gt 1 })
    foreach ($g in $dupOpen) {
        Add-Finding $who 'RepeatedOpening' "$($g.Count) sentences open with '$($g.Name)'" 'CHECK'
    }

    $surname = @(Get-Words $c.student)[-1]
    if ($surname) {
        $sn = (Get-Normalised $surname)
        $snOpens = @($openers | Where-Object { $_ -eq $sn }).Count
        if ($snOpens -gt 1) {
            Add-Finding $who 'SurnameOpening' "$snOpens sentences open with the surname"
        }
    }

    # Identifiability, advisory. A comment carrying no number, measurement or
    # name other than the student's own is the shape a generic comment takes.
    $specifics = 0
    if ($c.text -match '\d') { $specifics++ }
    $caps = @([regex]::Matches($c.text, '(?<![.!?]\s)(?<!^)\b[A-Z][a-z]{2,}\b') | ForEach-Object { $_.Value }) |
            Where-Object { $_ -ne $surname -and (Get-Words $c.student) -notcontains $_ }
    $specifics += @($caps | Select-Object -Unique).Count
    if ($specifics -lt 2) {
        Add-Finding $who 'Identifiability' 'few concrete details — cover the name and check this still reads as this student' 'CHECK'
    }
}

# --------------------------------------------------- cohort uniqueness -------

# Opening sentences must differ across every comment.
$openMap = @{}
foreach ($c in $comments) {
    $first = @(Split-Sentences (@(Split-Paragraphs $c.text)[0]))[0]
    if (-not $first) { continue }
    $k = Get-Normalised $first
    if (-not $openMap.ContainsKey($k)) { $openMap[$k] = @() }
    $openMap[$k] += "$($c.student) / $($c.box)"
}
foreach ($k in $openMap.Keys) {
    if ($openMap[$k].Count -gt 1) {
        Add-Finding ($openMap[$k] -join ' + ') 'SharedOpeningSentence' "these comments open with the same sentence: `"$k`""
    }
}

# Any distinctive phrase may appear once across the whole cohort.
#
# Reported as MAXIMAL shared runs, not as every n-gram inside them. One shared
# sentence contains a dozen overlapping five-word windows, and printing all of
# them buries the finding it is trying to report: there is one repeated phrase
# here, not thirteen.
function Get-SharedRuns {
    param([string[]]$A, [string[]]$B, [int]$Min)
    $runs = @()
    if ($A.Count -eq 0 -or $B.Count -eq 0) { return $runs }
    $prev = New-Object 'int[]' ($B.Count + 1)
    $cur  = New-Object 'int[]' ($B.Count + 1)
    for ($i = 1; $i -le $A.Count; $i++) {
        for ($j = 1; $j -le $B.Count; $j++) {
            if ($A[$i - 1] -eq $B[$j - 1]) { $cur[$j] = $prev[$j - 1] + 1 } else { $cur[$j] = 0 }
        }
        # a run is maximal where it cannot be extended one word further right
        for ($j = 1; $j -le $B.Count; $j++) {
            $len = $cur[$j]
            if ($len -ge $Min) {
                $extendable = ($i -lt $A.Count -and $j -lt $B.Count -and $A[$i] -eq $B[$j])
                if (-not $extendable) { $runs += ($A[($i - $len)..($i - 1)] -join ' ') }
            }
        }
        for ($j = 0; $j -le $B.Count; $j++) { $prev[$j] = $cur[$j]; $cur[$j] = 0 }
    }
    @($runs | Select-Object -Unique)
}

$wordsOf = @{}
foreach ($c in $comments) { $wordsOf["$($c.student)|$($c.box)"] = @(Get-Words (Get-Normalised $c.text)) }

$runOwners = @{}
for ($x = 0; $x -lt $comments.Count; $x++) {
    for ($y = $x + 1; $y -lt $comments.Count; $y++) {
        $a = $comments[$x]; $b = $comments[$y]
        $runs = Get-SharedRuns $wordsOf["$($a.student)|$($a.box)"] $wordsOf["$($b.student)|$($b.box)"] $PhraseWords
        foreach ($r in $runs) {
            if (-not $runOwners.ContainsKey($r)) { $runOwners[$r] = @() }
            foreach ($n in @("$($a.student) / $($a.box)", "$($b.student) / $($b.box)")) {
                if ($runOwners[$r] -notcontains $n) { $runOwners[$r] += $n }
            }
        }
    }
}
# drop any run wholly contained in a longer reported one
$allRuns = @($runOwners.Keys | Sort-Object { $_.Length } -Descending)
$kept = @()
foreach ($r in $allRuns) {
    $inside = $false
    foreach ($k in $kept) { if ($k.Contains($r)) { $inside = $true; break } }
    if (-not $inside) { $kept += $r }
}
foreach ($r in $kept) {
    Add-Finding ($runOwners[$r] -join ' + ') 'RepeatedPhrase' "share the phrase `"$r`""
}

# ----------------------------------------------------------------- report ----

$fails  = @($findings | Where-Object { $_.severity -eq 'FAIL' })
$checks = @($findings | Where-Object { $_.severity -eq 'CHECK' })

if ($Json) { ,$findings | ConvertTo-Json -Depth 6; if ($fails.Count) { exit 1 }; return }

if (-not $Quiet) {
    Write-Output ''
    Write-Output ("OBSERVATION COMMENTS — {0} comment(s) for {1} student(s)" -f $comments.Count, (@($comments | Select-Object -ExpandProperty student -Unique).Count))
    Write-Output ''
    if ($findings.Count -eq 0) {
        Write-Output '  every countable rule in the standard passes, and no two comments share an opening or a phrase.'
    } else {
        foreach ($f in $findings) {
            Write-Output ("  {0,-5} {1,-22} {2}" -f $f.severity, $f.rule, $f.where)
            Write-Output ("        {0}" -f $f.detail)
        }
    }
    Write-Output ''
    Write-Output 'Still yours to judge: whether the specifics are really this student''s, whether'
    Write-Output 'the order described is the order that happened, and whether it reads like an'
    Write-Output 'assessor wrote it on the day.'
    Write-Output ''
    if ($fails.Count) {
        Write-Output ("FAILED — {0} rule breach(es), {1} to check by eye." -f $fails.Count, $checks.Count)
    } else {
        Write-Output ("PASSED — 0 rule breaches, {0} to check by eye." -f $checks.Count)
    }
    Write-Output ''
}

if ($fails.Count) { exit 1 }
