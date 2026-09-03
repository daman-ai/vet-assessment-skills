# docx-toolkit.ps1 - dot-source this, then call the functions.
#   . .\scripts\docx-toolkit.ps1
#
# ASCII-only on purpose: a .ps1 saved as UTF-8 without BOM can be read as ANSI by
# PowerShell 5.1, which mangles em dashes and curly quotes. Pass non-ASCII text in
# from a separate UTF-8 file, or use the ~EM~ / ~MD~ / ~AP~ tokens below.

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# ---------------------------------------------------------------- tokens ----

function Expand-DocxToken {
    param([string]$Text)
    $t = $Text -replace '~EM~', [char]0x2014     # em dash
    $t = $t    -replace '~EN~', [char]0x2013     # en dash
    $t = $t    -replace '~MD~', [char]0x00B7     # middle dot
    $t = $t    -replace '~AP~', [char]0x2019     # right single quote
    $t = $t    -replace '~BU~', [char]0x2022     # bullet
    return $t
}

# ------------------------------------------------------------ word lifecycle ----

# Only ever kills windowless instances. A Word process with a window belongs to the
# user and may hold unsaved work.
function Stop-HeadlessWord {
    Get-Process WINWORD -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -eq 0 } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    $tries = 0
    while ($tries -lt 20) {
        $left = (Get-Process WINWORD -ErrorAction SilentlyContinue |
                 Where-Object { $_.MainWindowHandle -eq 0 } | Measure-Object).Count
        if ($left -eq 0) { return }
        Start-Sleep -Milliseconds 250
        $tries++
    }
}

function New-WordApp {
    Stop-HeadlessWord
    $w = New-Object -ComObject Word.Application
    $w.Visible = $false
    $w.DisplayAlerts = 0
    return $w
}

function Close-WordApp {
    param($Word)
    if ($Word -ne $null) {
        try { $Word.Quit(0) } catch { }
        try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Word) | Out-Null } catch { }
    }
    Stop-HeadlessWord
}

# ------------------------------------------------------------------ editing ----

# Replaces in the main body only. Word's Find is run-aware, so it matches phrases that
# are split across runs and that raw XML grep would miss.
# Returns "ok <snippet>" or "MISS <snippet>" so a caller can log every edit.
#
# -Once replaces only the first match. Use it when two cells hold identical text but need
# different replacements: call it twice with the same Find, and the second call lands on
# what was the second occurrence. Replace-all cannot express that.
function Invoke-DocxReplace {
    param($Doc, [string]$Find, [string]$Replace, [switch]$Once)

    $f = Expand-DocxToken $Find
    $r = Expand-DocxToken $Replace

    if ($f.Length -gt 255) { return "  TOOLONG ($($f.Length)) $($f.Substring(0,40))" }
    if ($r.Length -gt 255) { return "  TOOLONG-REPL ($($r.Length)) $($f.Substring(0,40))" }

    # Name this anything but $find: PowerShell variable names are case-insensitive,
    # so $find would bind to the [string]$Find parameter and coerce the COM object
    # to a string, failing later with "does not contain a method named ClearFormatting".
    $finder = $Doc.Content.Find
    $finder.ClearFormatting()
    $finder.Replacement.ClearFormatting()
    $finder.Text = $f
    $finder.Replacement.Text = $r
    $finder.Forward = $true
    $finder.Wrap = 1                    # wdFindContinue
    $finder.MatchCase = $true
    $mode = 2                           # wdReplaceAll
    if ($Once) { $mode = 1 }            # wdReplaceOne
    $hit = $finder.Execute([ref]$f, [ref]$true, [ref]$false, [ref]$false, [ref]$false,
                           [ref]$false, [ref]$true, [ref]1, [ref]$false, [ref]$r, [ref]$mode)

    $tag = $f.Substring(0, [Math]::Min(50, $f.Length))
    if ($hit) { return "  ok   $tag" }
    return "  MISS $tag"
}

# Inserts a block of paragraphs immediately above the paragraph whose trimmed text
# equals $AnchorText, then copies formatting from $ModelText's paragraph.
#
# Inserting one paragraph at a time against the same anchor does NOT work:
# Range.InsertParagraphBefore() expands the range, so repeated calls land in reverse
# order and merge. Insert once, then format by index.
function Add-DocxParagraphsAbove {
    param($Doc, [string]$AnchorText, [string[]]$Lines, [string]$ModelText)

    $anchor = $null
    $model  = $null
    $a = Expand-DocxToken $AnchorText
    $m = Expand-DocxToken $ModelText
    $ls = @($Lines | ForEach-Object { Expand-DocxToken $_ })

    foreach ($p in $Doc.Paragraphs) {
        $t = $p.Range.Text.Trim()
        if ($anchor -eq $null -and $t -eq $a) { $anchor = $p }
        if ($model  -eq $null -and $t -eq $m) { $model  = $p }
    }
    if ($anchor -eq $null) { return "  ANCHOR-MISS $a" }
    if ($model  -eq $null) { return "  MODEL-MISS $m" }

    $mStyle  = $model.Style
    $mSize   = $model.Range.Font.Size
    $mFont   = $model.Range.Font.Name
    $mLeft   = $model.LeftIndent
    $mFirst  = $model.FirstLineIndent
    $mBefore = $model.SpaceBefore
    $mAfter  = $model.SpaceAfter

    $rng = $anchor.Range
    $rng.Collapse(1)                    # wdCollapseStart
    $rng.InsertBefore((($ls -join "`r") + "`r"))

    $start = -1
    for ($i = 1; $i -le $Doc.Paragraphs.Count; $i++) {
        if ($Doc.Paragraphs.Item($i).Range.Text.Trim() -eq $ls[0]) { $start = $i; break }
    }
    if ($start -lt 0) { return "  INSERT-VERIFY-MISS" }

    for ($j = 0; $j -lt $ls.Count; $j++) {
        $q = $Doc.Paragraphs.Item($start + $j)
        $q.Style = $mStyle
        $q.Range.Font.Size = $mSize
        $q.Range.Font.Name = $mFont
        $q.Range.Font.Bold = $false
        $q.Range.Font.Color = 0
        $q.LeftIndent = $mLeft
        $q.FirstLineIndent = $mFirst
        $q.SpaceBefore = $mBefore
        $q.SpaceAfter = $mAfter
    }
    return "  inserted $($ls.Count) para(s) above '$a'"
}

# Collapses runs of consecutive empty paragraphs outside tables, keeping one.
# Stacked spacer paragraphs after tables are the usual cause of a wholly blank page.
function Remove-DocxSpacerRuns {
    param($Doc)
    $empties = @()
    for ($i = 1; $i -le $Doc.Paragraphs.Count; $i++) {
        $p = $Doc.Paragraphs.Item($i)
        if ($p.Range.Text.Trim().Length -eq 0 -and -not $p.Range.Information(12)) { $empties += $i }
    }
    $kill = @()
    for ($k = 1; $k -lt $empties.Count; $k++) {
        if ($empties[$k] -eq $empties[$k - 1] + 1) { $kill += $empties[$k] }
    }
    $kill = $kill | Where-Object { $_ -lt $Doc.Paragraphs.Count }   # never the final mark
    [array]::Reverse($kill)
    foreach ($idx in $kill) { $Doc.Paragraphs.Item($idx).Range.Delete() | Out-Null }
    return "  collapsed $($kill.Count) spacer paragraph(s)"
}

# --------------------------------------------------------------- properties ----

# Custom document properties live in docProps/custom.xml. The COM API for these
# ($doc.CustomDocumentProperties via InvokeMember) returns null under PowerShell 5.1,
# so patch the XML directly. Word must not have the file open.
function Set-DocxProperties {
    param([string]$Path, [hashtable]$Properties)
    $out = @()
    $zip = [System.IO.Compression.ZipFile]::Open($Path, 'Update')
    try {
        $entry = $zip.Entries | Where-Object { $_.FullName -eq 'docProps/custom.xml' }
        if ($entry -eq $null) { return @("  no docProps/custom.xml") }
        $sr = New-Object System.IO.StreamReader($entry.Open(), [System.Text.Encoding]::UTF8)
        $xml = $sr.ReadToEnd(); $sr.Close()

        foreach ($k in $Properties.Keys) {
            $v = [System.Security.SecurityElement]::Escape((Expand-DocxToken $Properties[$k]))
            $pat = '(name="' + [regex]::Escape($k) + '">)<vt:lpwstr>[^<]*</vt:lpwstr>'
            if ($xml -match $pat) {
                $xml = [regex]::Replace($xml, $pat, ('${1}<vt:lpwstr>' + $v.Replace('$','$$') + '</vt:lpwstr>'))
                $out += "  set   $k"
            } else {
                $pids = [regex]::Matches($xml, 'pid="(\d+)"') | ForEach-Object { [int]$_.Groups[1].Value }
                $next = ($pids | Measure-Object -Maximum).Maximum + 1
                $add = '<property fmtid="{D5CDD505-2E9C-101B-9397-08002B2CF9AE}" pid="' + $next +
                       '" name="' + $k + '"><vt:lpwstr>' + $v + '</vt:lpwstr></property>'
                $xml = $xml -replace '</Properties>', ($add + '</Properties>')
                $out += "  added $k"
            }
        }
        $st = $entry.Open(); $st.SetLength(0)
        $sw = New-Object System.IO.StreamWriter($st, (New-Object System.Text.UTF8Encoding($false)))
        $sw.Write($xml); $sw.Flush(); $sw.Close()
    } finally { $zip.Dispose() }
    return $out
}

# DOCPROPERTY fields keep a cached result in the header/footer XML. Changing the
# property alone leaves the rendered footer stale until someone refreshes fields, so
# patch the cached text too. $Map is oldVisibleText -> newVisibleText.
function Update-DocxCachedText {
    param([string]$Path, [hashtable]$Map)
    $out = @()
    $zip = [System.IO.Compression.ZipFile]::Open($Path, 'Update')
    try {
        $parts = $zip.Entries | Where-Object { $_.FullName -match '^word/(header|footer)\d+\.xml$' }
        foreach ($part in $parts) {
            $sr = New-Object System.IO.StreamReader($part.Open(), [System.Text.Encoding]::UTF8)
            $x = $sr.ReadToEnd(); $sr.Close()
            $orig = $x
            foreach ($k in $Map.Keys) {
                $v = [System.Security.SecurityElement]::Escape((Expand-DocxToken $Map[$k]))
                $x = [regex]::Replace($x, '(<w:t[^>]*>)' + [regex]::Escape($k) + '(</w:t>)',
                                      ('${1}' + $v.Replace('$','$$') + '${2}'))
            }
            if ($x -ne $orig) {
                $st = $part.Open(); $st.SetLength(0)
                $sw = New-Object System.IO.StreamWriter($st, (New-Object System.Text.UTF8Encoding($false)))
                $sw.Write($x); $sw.Flush(); $sw.Close()
                $out += "  cached text patched in $($part.FullName)"
            }
        }
    } finally { $zip.Dispose() }
    return $out
}

# Adds <w:keepNext/> to every Heading1/2/3 paragraph. The heading styles in this set
# do not carry it, so headings strand at page feet in every document built from them.
# Schema order inside w:pPr puts keepNext straight after pStyle.
function Add-DocxHeadingKeepNext {
    param([string]$Path)
    $zip = [System.IO.Compression.ZipFile]::Open($Path, 'Update')
    try {
        $e = $zip.Entries | Where-Object { $_.FullName -eq 'word/document.xml' }
        $sr = New-Object System.IO.StreamReader($e.Open(), [System.Text.Encoding]::UTF8)
        $x = $sr.ReadToEnd(); $sr.Close()
        $x2 = [regex]::Replace($x, '(<w:pStyle w:val="Heading[123]"/>)(?!<w:keepNext/>)', '${1}<w:keepNext/>')
        $n = ([regex]::Matches($x2, '<w:keepNext/>')).Count

        $d = New-Object System.Xml.XmlDocument
        $d.LoadXml($x2)                      # refuse to write malformed XML

        $st = $e.Open(); $st.SetLength(0)
        $sw = New-Object System.IO.StreamWriter($st, (New-Object System.Text.UTF8Encoding($false)))
        $sw.Write($x2); $sw.Flush(); $sw.Close()
        return "  keepNext present on $n heading paragraph(s)"
    } finally { $zip.Dispose() }
}

# ------------------------------------------------------------- verification ----

# The quality gate from SKILL.md, as far as it can be automated.
function Test-Docx {
    param([string]$Path)
    $out = @("=== $(Split-Path $Path -Leaf) ===")

    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
        $names = $zip.Entries | ForEach-Object { $_.FullName }
        $e = $zip.Entries | Where-Object { $_.FullName -eq 'word/document.xml' }
        $sr = New-Object System.IO.StreamReader($e.Open(), [System.Text.Encoding]::UTF8)
        $xml = $sr.ReadToEnd(); $sr.Close(); $zip.Dispose()
        $out += "  zip: OK ($($names.Count) parts)"
        $d = New-Object System.Xml.XmlDocument
        $d.LoadXml($xml)
        $out += "  document.xml: well-formed"
    } catch {
        $out += "  FAIL: $($_.Exception.Message)"
        return $out
    }

    $word = New-WordApp
    $doc = $null
    try {
        $doc = $word.Documents.Open($Path, $false, $true)
        $pages = $doc.ComputeStatistics(2)
        $words = $doc.ComputeStatistics(0)
        $out += "  opens in Word: $pages pages, $words words, $($doc.Tables.Count) tables"

        $prev = ''; $prevPg = -1; $stranded = @(); $chars = @{}
        foreach ($p in $doc.Paragraphs) {
            # Both can come back null - an empty table cell yields a null Range.Text, and
            # Information(3) is null while Word is still repaginating. Guard or the whole
            # layout check dies on one cell and reports nothing.
            $pg = $p.Range.Information(3)
            if ($null -eq $pg) { $pg = $prevPg }
            $t = $p.Range.Text
            if ($null -eq $t) { $t = '' } else { $t = $t.Trim() }
            if ($chars.ContainsKey($pg)) { $chars[$pg] += $t.Length } else { $chars[$pg] = $t.Length }
            if ($prev -ne '' -and $pg -ne $prevPg -and $prev.Length -lt 90 -and
                $prev -match '^(PART [ABC]\b|[ABC]\.\d+\s+[A-Z]|\d+\s+[A-Z])') {
                $stranded += "p${prevPg}: $prev"
            }
            $prev = $t; $prevPg = $pg
        }
        if ($stranded.Count -eq 0) { $out += "  stranded headings: none" }
        else { $out += "  STRANDED HEADINGS:"; $stranded | ForEach-Object { $out += "    $_" } }

        $thin = $chars.GetEnumerator() | Where-Object { $_.Value -lt 200 } | Sort-Object Name
        if ($thin) { $out += "  thin/blank pages:"; $thin | ForEach-Object { $out += "    p$($_.Name): $($_.Value) chars" } }
        else { $out += "  thin/blank pages: none" }

        $doc.Close(0); $doc = $null
    } catch {
        $out += "  WORD FAIL: $($_.Exception.Message)"
        if ($doc -ne $null) { try { $doc.Close(0) } catch { } }
    } finally {
        Close-WordApp $word
    }
    return $out
}

# ------------------------------------------------------------- body builder ----

# Builds a document body from a simple line DSL and grafts it into a copy of an
# existing document, so header, logo, footer fields, styles, numbering and theme all
# carry over unchanged. Word is never involved, so nothing can crash mid-save.
#
# Content file lines are "TAG@@text". Table cells are separated by ||.
#   TITLE  SUB  STRAP  SEC  H2  H3  P  FILL  B  BANNER
#   TBL@@w1,w2,w3   TH@@a||b||c   TR@@a||b||c   ENDTBL@@
# Widths are twips; A4 with 1000-twip margins leaves about 9900 usable.
function New-DocxFromTemplate {
    param(
        [Parameter(Mandatory=$true)][string]$TemplateDocx,
        [Parameter(Mandatory=$true)][string]$ContentFile,
        [Parameter(Mandatory=$true)][string]$OutDocx,
        [string]$WorkDir = (Join-Path $env:TEMP ("docxbuild_" + [guid]::NewGuid().ToString('N')))
    )

    $NAVY='2A364E'; $BLUE='2490CC'; $ORANGE='F09018'; $GREY='7A8699'; $LINE='D5DAE2'

    function _esc([string]$s) {
        $s = $s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;'
        return (Expand-DocxToken $s)
    }
    function _para([string]$ppr, [string]$rpr, [string]$text) {
        $r = '<w:r>'
        if ($rpr -ne '') { $r += $rpr }
        $r += '<w:t xml:space="preserve">' + (_esc $text) + '</w:t></w:r>'
        return '<w:p>' + $ppr + $r + '</w:p>'
    }
    $PPR_BODY   = '<w:pPr><w:spacing w:after="160" w:line="276" w:lineRule="auto"/></w:pPr>'
    $PPR_BULLET = '<w:pPr><w:pStyle w:val="ListParagraph"/><w:numPr><w:ilvl w:val="0"/><w:numId w:val="2"/></w:numPr><w:spacing w:after="80" w:line="276" w:lineRule="auto"/></w:pPr>'
    $PPR_CELL   = '<w:pPr><w:spacing w:before="40" w:after="40" w:line="240" w:lineRule="auto"/></w:pPr>'

    function _cell([string]$text, [int]$w, [bool]$hdr) {
        $shd = ''
        $rpr = '<w:rPr><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>'
        if ($hdr) {
            $shd = '<w:shd w:val="clear" w:color="auto" w:fill="' + $NAVY + '"/>'
            $rpr = '<w:rPr><w:b/><w:bCs/><w:color w:val="FFFFFF"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>'
        }
        $tc  = '<w:tc><w:tcPr><w:tcW w:w="' + $w + '" w:type="dxa"/>' + $shd
        $tc += '<w:tcMar><w:top w:w="60" w:type="dxa"/><w:left w:w="90" w:type="dxa"/><w:bottom w:w="60" w:type="dxa"/><w:right w:w="90" w:type="dxa"/></w:tcMar></w:tcPr>'
        $tc += (_para $PPR_CELL $rpr $text) + '</w:tc>'
        return $tc
    }

    $lines = [System.IO.File]::ReadAllLines($ContentFile, [System.Text.Encoding]::UTF8)
    $sb = New-Object System.Text.StringBuilder
    $widths = @()
    $open = $false

    foreach ($line in $lines) {
        if ($line.Trim() -eq '') { continue }
        $parts = $line -split '@@', 2
        $tag = $parts[0]
        $a = ''
        if ($parts.Count -gt 1) { $a = $parts[1] }

        switch ($tag) {
            'TITLE'  { [void]$sb.Append((_para '<w:pPr><w:spacing w:after="60"/></w:pPr>' '<w:rPr><w:b/><w:bCs/><w:sz w:val="40"/><w:szCs w:val="40"/></w:rPr>' $a)) }
            'SUB'    { [void]$sb.Append((_para '<w:pPr><w:pStyle w:val="Heading1"/><w:keepNext/><w:spacing w:after="60"/></w:pPr>' ('<w:rPr><w:b/><w:color w:val="' + $NAVY + '"/></w:rPr>') $a)) }
            'STRAP'  { [void]$sb.Append((_para ('<w:pPr><w:pBdr><w:bottom w:val="single" w:sz="12" w:space="6" w:color="' + $ORANGE + '"/></w:pBdr><w:spacing w:after="280"/></w:pPr>') ('<w:rPr><w:color w:val="' + $GREY + '"/><w:sz w:val="19"/><w:szCs w:val="19"/></w:rPr>') $a)) }
            'SEC'    { [void]$sb.Append((_para ('<w:pPr><w:pStyle w:val="Heading1"/><w:keepNext/><w:pBdr><w:bottom w:val="single" w:color="' + $ORANGE + '" w:sz="8" w:space="6"/></w:pBdr><w:spacing w:after="160" w:before="360"/></w:pPr>') ('<w:rPr><w:b/><w:bCs/><w:color w:val="' + $NAVY + '"/><w:sz w:val="26"/><w:szCs w:val="26"/></w:rPr>') $a)) }
            'H2'     { [void]$sb.Append((_para '<w:pPr><w:pStyle w:val="Heading2"/><w:keepNext/><w:spacing w:before="240" w:after="100"/></w:pPr>' ('<w:rPr><w:b/><w:bCs/><w:color w:val="' + $BLUE + '"/><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr>') $a)) }
            'H3'     { [void]$sb.Append((_para '<w:pPr><w:pStyle w:val="Heading3"/><w:keepNext/><w:spacing w:before="180" w:after="80"/></w:pPr>' ('<w:rPr><w:b/><w:bCs/><w:color w:val="' + $NAVY + '"/><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr>') $a)) }
            'P'      { [void]$sb.Append((_para $PPR_BODY '<w:rPr><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr>' $a)) }
            'FILL'   { [void]$sb.Append((_para $PPR_BODY '<w:rPr><w:b/><w:bCs/><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr>' $a)) }
            'B'      { [void]$sb.Append((_para $PPR_BULLET '<w:rPr><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr>' $a)) }
            'BANNER' { [void]$sb.Append((_para ('<w:pPr><w:shd w:val="clear" w:color="auto" w:fill="' + $NAVY + '"/><w:spacing w:before="240" w:after="240"/></w:pPr>') '<w:rPr><w:b/><w:bCs/><w:color w:val="FFFFFF"/><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr>' $a)) }
            'TBL' {
                $widths = @($a -split ',' | ForEach-Object { [int]$_.Trim() })
                $total = ($widths | Measure-Object -Sum).Sum
                $t = '<w:tbl><w:tblPr><w:tblW w:w="' + $total + '" w:type="dxa"/><w:tblBorders>'
                foreach ($edge in @('top','left','bottom','right','insideH','insideV')) {
                    $t += '<w:' + $edge + ' w:val="single" w:sz="4" w:space="0" w:color="' + $LINE + '"/>'
                }
                $t += '</w:tblBorders><w:tblLayout w:type="fixed"/></w:tblPr><w:tblGrid>'
                foreach ($w in $widths) { $t += '<w:gridCol w:w="' + $w + '"/>' }
                [void]$sb.Append($t + '</w:tblGrid>')
                $open = $true
            }
            'TH' {
                $cells = $a -split [regex]::Escape('||')
                $tr = '<w:tr><w:trPr><w:cantSplit/><w:tblHeader/></w:trPr>'
                for ($i = 0; $i -lt $widths.Count; $i++) {
                    $v = ''; if ($i -lt $cells.Count) { $v = $cells[$i] }
                    $tr += (_cell $v $widths[$i] $true)
                }
                [void]$sb.Append($tr + '</w:tr>')
            }
            'TR' {
                $cells = $a -split [regex]::Escape('||')
                $tr = '<w:tr><w:trPr><w:cantSplit/></w:trPr>'
                for ($i = 0; $i -lt $widths.Count; $i++) {
                    $v = ''; if ($i -lt $cells.Count) { $v = $cells[$i] }
                    $tr += (_cell $v $widths[$i] $false)
                }
                [void]$sb.Append($tr + '</w:tr>')
            }
            'ENDTBL' {
                # Word requires a paragraph after a table, and between adjacent tables
                [void]$sb.Append('</w:tbl><w:p><w:pPr><w:spacing w:after="0" w:line="120" w:lineRule="auto"/></w:pPr></w:p>')
                $open = $false
            }
            default { throw "Unknown tag '$tag' in line: $line" }
        }
    }
    if ($open) { throw "table left open in $ContentFile" }

    if (Test-Path $WorkDir) { Remove-Item -Recurse -Force $WorkDir }
    New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path $TemplateDocx).Path, $WorkDir)

    $docPath = Join-Path $WorkDir 'word\document.xml'
    $xml = [System.IO.File]::ReadAllText($docPath, [System.Text.Encoding]::UTF8)
    $openIdx = $xml.IndexOf('<w:body>') + '<w:body>'.Length
    $sectIdx = $xml.IndexOf('<w:sectPr')
    if ($sectIdx -lt 0) { throw 'no <w:sectPr> in template' }
    $newXml = $xml.Substring(0, $openIdx) + $sb.ToString() + $xml.Substring($sectIdx)

    $d = New-Object System.Xml.XmlDocument
    $d.LoadXml($newXml)

    [System.IO.File]::WriteAllText($docPath, $newXml, (New-Object System.Text.UTF8Encoding($false)))

    if (Test-Path $OutDocx) { Remove-Item -Force $OutDocx }
    # Entry names must use forward slashes; CreateFromDirectory has emitted backslashes
    # in some framework versions, which Word will not open.
    $zip = [System.IO.Compression.ZipFile]::Open($OutDocx, 'Create')
    try {
        $root = (Resolve-Path $WorkDir).Path.TrimEnd('\') + '\'
        $files = Get-ChildItem -Path $WorkDir -Recurse -File
        $ordered = @()
        $ordered += ($files | Where-Object { $_.Name -eq '[Content_Types].xml' })
        $ordered += ($files | Where-Object { $_.Name -ne '[Content_Types].xml' })
        foreach ($f in $ordered) {
            $rel = $f.FullName.Substring($root.Length).Replace('\', '/')
            [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $zip, $f.FullName, $rel, [System.IO.Compression.CompressionLevel]::Optimal)
        }
    } finally { $zip.Dispose() }

    Remove-Item -Recurse -Force $WorkDir -ErrorAction SilentlyContinue
    return "built: $OutDocx ($((Get-Item $OutDocx).Length) bytes)"
}
