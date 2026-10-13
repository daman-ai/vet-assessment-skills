<#
  Test-SubmissionBlanks.ps1 - find what a student left blank.

  THE RTO'S RULE, 8 September 2026: a task left unanswered, a record left
  without its date, a signature line left empty - each is a requirement not
  demonstrated, and the tool is Not Yet Satisfactory for it. This script finds
  them, so the judgement is made against the document rather than against
  whatever the reader happened to notice while scrolling.

  Three things are reported.

  1. UNANSWERED QUESTIONS. A workbook prints the same stem in every copy, so
     template text is what several copies share. Pass every submission in the
     cohort at once and the shared text is subtracted: what is left inside a
     question block is the student's own answer, and a block with nothing left
     is unanswered. The key file's third column is anchorAfter, and it is
     honoured here for the reason the builder honours it - a key naming a
     section heading also matches that heading in the table of contents.

  2. BLANK SIGNATURE AND DATE LINES. 'EMPLOYEE Signed ______ DATE ______' is a
     record the student completes in the role play. Each label is read with the
     rule of underscores that follows it, and a rule carrying no letters or
     digits is blank.

  3. EMPTY CELLS ABOVE THE FLOOR. A cell empty in every copy is the workbook's
     own layout. Each question's count is compared with the lowest count any
     copy has for that question, and what is above that floor is what this
     student left out.

  A line opening with the assessor's or trainer's label ('Assessor name: ___
  Signature: ___ Date: ___') is the assessor's sign-off, not the student's, and
  is not reported as a blank line.

  Nothing here decides anything. It reports; the assessor marks.

  The key file is one question per line, ref<TAB>anchor[<TAB>anchorAfter] -
  '|' is accepted in place of the tab. -EndAnchor is the ledger's
  questionsEndAnchor and closes the last question's block.

  Usage:
    .\Test-SubmissionBlanks.ps1 -Docx a.docx,b.docx -KeyFile keys.tsv -EndAnchor 'Observation Checklist' -Json blanks.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string[]]$Docx,
    [string]$KeyFile,
    [string]$Json,
    [int]$SharedCopies = 2,
    # Where the last answer stops - the ledger's questionsEndAnchor. Without
    # it the last question's block runs to the end of the document and takes
    # in whatever follows it, such as an assessor's observation checklist.
    [string]$EndAnchor
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'

function Get-Paragraphs {
    param([string]$Path)
    $work = Join-Path $env:TEMP ('blanks_' + [guid]::NewGuid().ToString('N'))
    [System.IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path -LiteralPath $Path).Path, $work)
    try {
        $xml = New-Object System.Xml.XmlDocument
        $xml.PreserveWhitespace = $true
        $xml.Load((Join-Path $work 'word/document.xml'))
        $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
        $ns.AddNamespace('w', $W)
        $out = @()
        foreach ($p in $xml.SelectNodes('//w:p', $ns)) {
            $txt = ($p.SelectNodes('.//w:t', $ns) | ForEach-Object { $_.InnerText }) -join ''
            $parent = $p.ParentNode
            $inCell = ($parent -and $parent.LocalName -eq 'tc')
            $out += ,([pscustomobject]@{ text = $txt; inCell = $inCell })
        }
        # RETURN @($out), NEVER ,$out. The comma idiom wrapped by @() at the
        # call site is ONE element holding an array, and every copy then reads
        # as a one-paragraph document with nothing in it.
        @($out)
    } finally { [System.IO.Directory]::Delete($work, $true) }
}

function Norm([string]$s) {
    $apos = '[' + [char]0x2018 + [char]0x2019 + ']'
    $dash = '[' + [char]0x2010 + [char]0x2011 + [char]0x2012 + [char]0x2013 + [char]0x2014 + ']'
    $s = $s -replace $apos, "'"
    $s = $s -replace $dash, '-'
    ($s -replace '\s+', ' ').Trim().ToLowerInvariant()
}

$copies = @{}
foreach ($d in $Docx) {
    if (-not (Test-Path -LiteralPath $d)) { throw "Submission not found: $d" }
    $copies[$d] = @(Get-Paragraphs -Path $d)
}

$seen = @{}
foreach ($d in $Docx) {
    $these = @{}
    foreach ($p in $copies[$d]) {
        $n = Norm $p.text
        if ($n.Length -eq 0) { continue }
        $these[$n] = $true
    }
    foreach ($k in $these.Keys) { if ($seen.ContainsKey($k)) { $seen[$k]++ } else { $seen[$k] = 1 } }
}
# SHORT TEXT IS TEMPLATE TOO. Paragraphs under twelve characters used to be
# left out of the count altogether, so a table's own labels - 'Maps to',
# 'Item', 'Surface', 'Sand' - were never recognised as shared and read as the
# student's answer in every block that held one: the blank pack itself came
# out fully answered. A short line is template where at least half the copies
# carry it, so two students who both wrote 'Yes' do not erase each other.
$shortShared = [Math]::Max($SharedCopies, [int][Math]::Ceiling($Docx.Count / 2))
$isTemplate = @{}
foreach ($k in $seen.Keys) {
    $need = if ($k.Length -lt 12) { $shortShared } else { $SharedCopies }
    if ($seen[$k] -ge $need) { $isTemplate[$k] = $true }
}
# A RESPONSE PROMPT IS NOT A RESPONSE. 'Write your response to (a) here…' is
# printed in the blank and replaced in most copies, so it is not shared widely
# enough to subtract - and a student who left it in place answered nothing.
$promptRx = '^(write|record|type|enter|insert)\b.*\bhere\W*$'

$keys = @()
if ($KeyFile) {
    foreach ($line in @(Get-Content -LiteralPath $KeyFile -Encoding UTF8)) {
        if (-not $line.Trim() -or $line.StartsWith('#')) { continue }
        # ref<TAB>anchor[<TAB>anchorAfter], or the same with '|'. Splitting a
        # tab-separated file on '|' alone left every key EMPTY, and an empty
        # key is contained in every paragraph: all 43 questions were placed on
        # paragraph 0 and every copy reported every question unanswered.
        $parts = if ($line.Contains("`t")) { $line -split "`t" } else { $line -split '\|' }
        if ($parts.Count -lt 2 -or -not "$($parts[1])".Trim()) {
            throw "Key file line has no anchor (expected ref<TAB>anchor or ref|anchor): '$line'"
        }
        $after = if ($parts.Count -ge 3 -and $parts[2].Trim()) { Norm $parts[2] } else { $null }
        $keys += [pscustomobject]@{ ref = $parts[0].Trim(); key = Norm $parts[1]; after = $after }
    }
}
$endKey = if ($EndAnchor) { Norm $EndAnchor } else { $null }

$report = @()
foreach ($d in $Docx) {
    $paras = $copies[$d]
    $marks = @()
    foreach ($k in $keys) {
        $from = 0
        if ($k.after) {
            for ($i = 0; $i -lt $paras.Count; $i++) {
                if ((Norm $paras[$i].text).Contains($k.after)) { $from = $i + 1; break }
            }
        }
        for ($i = $from; $i -lt $paras.Count; $i++) {
            if ((Norm $paras[$i].text).Contains($k.key)) { $marks += [pscustomobject]@{ ref = $k.ref; at = $i }; break }
        }
    }
    # A key that is not in this copy is REPORTED. Dropping it silently left
    # the question out of the unanswered list, which reads as answered.
    $notFound = @($keys | Where-Object { $kr = $_.ref; -not @($marks | Where-Object { $_.ref -eq $kr }).Count } | ForEach-Object { $_.ref })
    $marks = @($marks | Sort-Object at)

    $endAt = $paras.Count
    if ($endKey -and $marks.Count) {
        for ($i = $marks[$marks.Count - 1].at + 1; $i -lt $paras.Count; $i++) {
            if ((Norm $paras[$i].text).Contains($endKey)) { $endAt = $i; break }
        }
    }

    $unanswered = @()
    for ($m = 0; $m -lt $marks.Count; $m++) {
        $from = $marks[$m].at
        $to   = if ($m -lt $marks.Count - 1) { $marks[$m + 1].at } else { $endAt }
        $own  = 0
        for ($i = $from + 1; $i -lt $to; $i++) {
            $tx = $paras[$i].text.Trim()
            if ($tx.Length -lt 3) { continue }
            $n = Norm $tx
            if ($isTemplate.ContainsKey($n)) { continue }
            if ($n -match $promptRx) { continue }
            if ($n -match '^[_\s\-\.]*$') { continue }
            $own++
        }
        if ($own -eq 0) { $unanswered += $marks[$m].ref }
    }

    $blankLines = @()
    $emptyCells = @()
    for ($i = 0; $i -lt $paras.Count; $i++) {
        $ref = 'before the first question'
        foreach ($mk in $marks) { if ($mk.at -le $i) { $ref = $mk.ref } else { break } }
        if ($i -ge $endAt) { $ref = 'after the last question' }

        $tx = $paras[$i].text
        # A line that opens with the ASSESSOR's or trainer's label is the
        # assessor's sign-off - 'Assessor name: ___ Signature: ___ Date: ___'
        # under an observation checklist - and the builder fills it. It is
        # not a record the student left blank, so it is not reported here.
        $assessorOwned = ((Norm $tx) -match '^(trainer\s*/\s*)?(assessor|trainer)\b')
        if (-not $assessorOwned -and $tx -match '_{3,}' -and $tx -match '(?i)(sign|date)') {
            $ms = [regex]::Matches($tx, '(?i)(authorised signed|signature|signed|date)\s*:?\s*')
            for ($k = 0; $k -lt $ms.Count; $k++) {
                $start = $ms[$k].Index + $ms[$k].Length
                $end   = if ($k -lt $ms.Count - 1) { $ms[$k + 1].Index } else { $tx.Length }
                if ($start -ge $tx.Length) { continue }
                if ($end -gt $tx.Length) { $end = $tx.Length }
                if ($end -le $start) { continue }
                $seg = $tx.Substring($start, $end - $start)
                if ($seg -notmatch '_{2,}') { continue }
                if ($seg -match '[A-Za-z0-9]') { continue }
                $blankLines += [pscustomobject]@{ label = $ms[$k].Value.Trim(); under = $ref; line = ($tx -replace '\s+', ' ').Trim() }
            }
        }
        if ($paras[$i].inCell -and -not $paras[$i].text.Trim()) { $emptyCells += $ref }
    }

    $emptyByRef = @()
    foreach ($g in ($emptyCells | Group-Object)) { $emptyByRef += [pscustomobject]@{ under = $g.Name; cells = $g.Count } }

    $report += [pscustomobject]@{
        submission      = (Split-Path -Leaf $d)
        unanswered      = @($unanswered)
        keysNotFound    = @($notFound)
        blankLines      = @($blankLines)
        emptyCellsByRef = @($emptyByRef)
        emptyExtra      = @()
    }
}

$floors = @{}
foreach ($r in $report) {
    foreach ($e in $r.emptyCellsByRef) {
        if (-not $floors.ContainsKey($e.under) -or $e.cells -lt $floors[$e.under]) { $floors[$e.under] = $e.cells }
    }
}
foreach ($r in $report) {
    $extra = @()
    foreach ($e in $r.emptyCellsByRef) {
        $floor = $floors[$e.under]
        if ($e.cells -gt $floor) { $extra += [pscustomobject]@{ under = $e.under; extra = ($e.cells - $floor); floor = $floor } }
    }
    $r.emptyExtra = @($extra | Sort-Object extra -Descending)
}

foreach ($r in $report) {
    Write-Output ''
    Write-Output "SUBMISSION  $($r.submission)"
    if ($r.unanswered.Count) {
        Write-Output "  UNANSWERED - no text of the student's own inside these question blocks:"
        foreach ($u in $r.unanswered) { Write-Output "      $u" }
    } else { Write-Output '  UNANSWERED - none' }
    if ($r.keysNotFound.Count) {
        Write-Output "  KEY NOT FOUND - these anchors are not in this copy, so their blocks were not read:"
        foreach ($u in $r.keysNotFound) { Write-Output "      $u" }
    }
    if ($r.blankLines.Count) {
        Write-Output "  BLANK SIGNATURE / DATE LINES - $($r.blankLines.Count):"
        foreach ($b in $r.blankLines) { Write-Output "      [$($b.under)] $($b.label) -> $($b.line)" }
    } else { Write-Output '  BLANK SIGNATURE / DATE LINES - none' }
    if ($r.emptyExtra.Count) {
        Write-Output '  EMPTY CELLS ABOVE THE FLOOR - blank here, filled in another copy:'
        foreach ($e in $r.emptyExtra) { Write-Output "      $($e.under): $($e.extra) above the $($e.floor) the layout leaves" }
    } else { Write-Output '  EMPTY CELLS - none above what the layout leaves in every copy' }
}
Write-Output ''
Write-Output 'Nothing above is a judgement. Mark the tool NYS where a requirement is not'
Write-Output 'demonstrated, and write the item that tells the student what to complete.'
if ($Json) { $report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Json -Encoding UTF8; Write-Output "Written: $Json" }