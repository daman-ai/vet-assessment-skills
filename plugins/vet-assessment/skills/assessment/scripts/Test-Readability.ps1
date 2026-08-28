<#
    Test-Readability.ps1

    THE READABILITY GATE. Runs on the unpacked package, after Test-HouseRules and
    before repacking, so a defect is caught before a file exists to mislead anyone.

    It measures what can be measured:

      ParagraphLength        no body paragraph, bullet or stem over 300 characters
      StackedShortParagraphs four or more consecutive short paragraphs with no bullets
      OrphanLeadIn           a colon lead-in that can separate from the list it introduces
      RunOnList            no hyphen run or comma enumeration doing a list's job
      BulletSpacing        body bullets carry space between them
      ListParagraphIsList  a ListParagraph paragraph actually carries numbering

    It FINDS defects. It does not fix them - an automatic split cuts a sentence in
    the wrong place. The readability agent in references/readability.md rewrites.

    Rules and thresholds: references/readability.md.

    Requires Build-FromTemplate.ps1 dot-sourced first (Get-DocxPart).

    ASCII only in this file.
#>

# No Set-StrictMode - dot-sourced.

# THE PROFILE IS THE AUTHORITY for every figure below - house-profile.<brand>.json
# -> readability. A figure that lives in more than one place goes out of step with
# the check that reads it; that is the house standard's own warning and it has
# already cost this codebase once. The fallbacks exist only so the gate still runs
# against a profile written before the readability block was added.
function Get-ReadabilitySettings {
    param([string] $Brand = 'MVC')
    $r = $null
    if (Get-Command Get-HouseProfile -ErrorAction SilentlyContinue) {
        try { $r = (Get-HouseProfile -Brand $Brand).readability } catch { $r = $null }
    }
    if ($null -eq $r) {
        Write-Warning "Test-Readability: house profile not loaded for brand '$Brand' - gating against built-in defaults, NOT the profile. Dot-source Test-HouseRules.ps1 first."
    }
    function Pick($o, $n, $d) {
        if ($o -and ($o.PSObject.Properties.Name -contains $n) -and $null -ne $o.$n) { return $o.$n }
        return $d
    }
    $sp = Pick $r 'spacing' $null
    [pscustomobject]@{
        CharsPerLine   = [int](Pick $r 'charsPerRenderedLine' 100)
        MaxLines       = [int](Pick $r 'paragraphMaxLines' 3)
        MaxChars       = [int](Pick $r 'paragraphMaxChars' 300)
        StackRun       = [int](Pick $r 'stackedShortParagraphRun' 4)
        StackChars     = [int](Pick $r 'stackedShortParagraphChars' 110)
        LongSentChars  = [int](Pick $r 'longSentenceChars' 150)
        LongSentClause = [int](Pick $r 'longSentenceClauses' 5)
        BulletAfter    = [int](Pick $sp 'bulletAfter' 80)
    }
}

# Fallbacks only - Get-ReadabilitySettings overrides these from the profile.
$script:RD_CHARS_PER_LINE = 100
$script:RD_MAX_CHARS      = 300

# The cover sheet AND the title page are approved RTO front matter. Neither is
# authored here and neither may be reflowed - the title page's RTO name, address,
# phone and email are six short paragraphs that would otherwise read as a list
# without dots and fail a correct document.
#
# The anchors come from the house profile (formatting.bodyStartsAfter), the SAME
# place Test-HouseRules takes them from. They were hardcoded to MVC's until
# 26 August 2026, which meant an ACI build - whose identity swap rewrites the
# MVC email the anchor named - silently lost its anchor and threw. A gate that
# carries its own private copy of a profile value is a gate that drifts.
$script:RD_BODY_ANCHOR_FALLBACK = @('Info@mvc.edu.au', 'info@mvc.edu.au', 'ASSESSMENT', 'Contents')

# Generic anchors are single common words that also occur deep in the body, so a
# match on one is only believable near the front. A specific anchor - an email or
# a domain - cannot match by coincidence and is trusted wherever it lands. The
# distinction matters because the old proportional bound was a fraction of the
# WHOLE document, so the same front matter passed in a 72-page pack and failed in
# a short one. Where the gate looks must not depend on how much body follows.
$script:RD_BODY_ANCHOR_GENERIC = @('ASSESSMENT', 'Contents')

function Get-ReadabilityBody {
    <# The generated body only. Scoping to it is what stops the gate failing a
       correct document on the RTO's own front matter. #>
    param(
        [Parameter(Mandatory)][string] $Xml,
        [string] $Brand = 'MVC'
    )
    $anchors = $null
    if (Get-Command Get-HouseProfile -ErrorAction SilentlyContinue) {
        try {
            $f = (Get-HouseProfile -Brand $Brand).formatting
            if ($f -and ($f.PSObject.Properties.Name -contains 'bodyStartsAfter')) {
                $anchors = @($f.bodyStartsAfter)
            }
        } catch { $anchors = $null }
    }
    if (-not $anchors -or $anchors.Count -eq 0) {
        Write-Warning "Test-Readability: no formatting.bodyStartsAfter in the house profile for brand '$Brand' - falling back to built-in anchors. Dot-source Test-HouseRules.ps1 first."
        $anchors = $script:RD_BODY_ANCHOR_FALLBACK
    }

    # A generic anchor must land in the front matter. The allowance is absolute,
    # not a share of the document, so it measures the template rather than the
    # build: MVC's title page ends around 32 KB into document.xml.
    $bound = [Math]::Max(60000, [int]($Xml.Length * 0.25))
    foreach ($a in $anchors) {
        $i = $Xml.LastIndexOf("<w:t>$a</w:t>")
        if ($i -lt 0) { $i = $Xml.LastIndexOf($a) }
        if ($i -le 0) { continue }
        if (($script:RD_BODY_ANCHOR_GENERIC -contains $a) -and $i -gt $bound) { continue }
        $pEnd = $Xml.IndexOf('</w:p>', $i)
        if ($pEnd -ge 0) { return $Xml.Substring($pEnd + 6) }
    }
    # Refuse to gate a body we could not scope. Silence here is the failure mode.
    throw "Test-Readability: no body anchor resolved for brand '$Brand'. Refusing to gate a partial body - check house-profile formatting.bodyStartsAfter against this template. Tried: $($anchors -join ', ')"
}

function Get-ParagraphRecord {
    <# Every w:p in the body, with its text, whether it sits in a table cell, and
       its pPr. Cells are exempt from the character cap; everything else is not. #>
    param([Parameter(Mandatory)][string] $Xml)

    $out = New-Object System.Collections.Generic.List[object]

    # Mark the character ranges that are NOT body prose, so a paragraph can be
    # told apart from body prose without parsing the tree.
    #
    # Two kinds:
    #   <w:tc>      a table cell - laid out by the template, not by us
    #   <w:drawing> a drawing canvas - the text inside a native diagram's shapes
    #
    # The drawing case was added after the artwork step started building
    # flowcharts as native Word shapes. A flowchart's nodes are short lines one
    # after another, so every placed diagram was reported as four to eight
    # "consecutive short paragraphs that should be bullets". They already ARE a
    # list; it is drawn rather than bulleted, and the readability rules have no
    # jurisdiction inside a diagram.
    $cellRanges = New-Object System.Collections.Generic.List[object]
    foreach ($pat in @('<w:tc(?:\s[^>]*)?>.*?</w:tc>', '<w:drawing(?:\s[^>]*)?>.*?</w:drawing>')) {
        foreach ($m in [regex]::Matches($Xml, $pat, 'Singleline')) {
            $cellRanges.Add(@{ Start = $m.Index; End = $m.Index + $m.Length })
        }
    }
    # ONE SORTED WALK, not a scan of every range per paragraph. Paragraph
    # matches arrive in ascending index order, so keep a cursor into the
    # Start-sorted ranges and a running maximum End over the ranges opened so
    # far: a paragraph at $idx sits inside a cell or drawing exactly when that
    # maximum exceeds $idx. Same verdicts as the nested loop - a range covers
    # $idx iff Start <= $idx < End - at O(n+m) instead of O(n*m), which on a
    # long document was millions of interpreted iterations per gate run.
    $sorted  = @($cellRanges | Sort-Object { $_.Start })
    $ri      = 0
    $openEnd = -1

    foreach ($m in [regex]::Matches($Xml, '<w:p(?:\s[^>]*)?>.*?</w:p>', 'Singleline')) {
        $p = $m.Value
        $text = -join ([regex]::Matches($p, '<w:t[^>]*>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value })
        $text = ($text -replace '\s+', ' ').Trim()
        if (-not $text) { continue }

        while ($ri -lt $sorted.Count -and $sorted[$ri].Start -le $m.Index) {
            if ($sorted[$ri].End -gt $openEnd) { $openEnd = $sorted[$ri].End }
            $ri++
        }
        $inCell = ($openEnd -gt $m.Index)

        $ppr = ''
        $pm = [regex]::Match($p, '<w:pPr>.*?</w:pPr>', 'Singleline')
        if ($pm.Success) { $ppr = $pm.Value }

        $isToc = ($ppr -match 'w:val="TOC') -or ($p -match 'PAGEREF') -or ($p -match 'instrText[^>]*>\s*TOC')

        $out.Add([pscustomobject]@{
            Text     = $text
            IsToc    = $isToc
            Chars    = $text.Length
            Lines    = [math]::Ceiling($text.Length / $script:RD_CHARS_PER_LINE)
            # True inside a table cell OR inside a drawing canvas. Either way the
            # paragraph is not body prose and the body rules do not apply to it.
            InCell   = $inCell
            Ppr      = $ppr
            IsList   = ($ppr -match 'ListParagraph')
            HasNumPr = ($ppr -match '<w:numPr>')
            # HNumStep renders a numbered method step as a literal bold number,
            # a tab and a 460/460 hanging indent - the documented house form for
            # numbered steps (Docx-Blocks-House.ps1). It IS a real list on the
            # page, but carries no numPr and no ListParagraph style, so the
            # stacked-paragraph check read every short method as a list that
            # lost its dots. Recognised here so the gate stops false-failing
            # the skill's own step builder. Added 28 August 2026 (SITHCCC036 -
            # short imperative steps; SITHCCC035's longer steps never tripped it).
            IsNumStep = (($ppr -match 'w:hanging="460"') -and ($text -match '^\d+\.'))
            After    = $(if ($ppr -match 'w:after="(\d+)"') { [int]$Matches[1] } else { 0 })
        })
    }
    return $out
}

function Test-Readability {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $WorkDir,
        [string] $Part = 'word/document.xml',
        [int]    $MaxChars = 0,
        [int]    $MinBulletAfter = 0,
        [ValidateSet('MVC','ACI')][string] $Brand = 'MVC'
    )

    $cfg = Get-ReadabilitySettings -Brand $Brand
    $script:RD_CHARS_PER_LINE = $cfg.CharsPerLine
    if ($MaxChars -le 0)       { $MaxChars = $cfg.MaxChars }
    if ($MinBulletAfter -le 0) { $MinBulletAfter = $cfg.BulletAfter }

    $xml  = Get-DocxPart -WorkDir $WorkDir -Part $Part
    $body = Get-ReadabilityBody -Xml $xml -Brand $Brand
    $paras = Get-ParagraphRecord -Xml $body

    $failures = New-Object System.Collections.Generic.List[object]
    $warnings = New-Object System.Collections.Generic.List[object]
    $passes   = New-Object System.Collections.Generic.List[string]

    function RFail($check, $detail) { $failures.Add([pscustomobject]@{ Check = $check; Detail = $detail }) }
    function RWarn($check, $detail) { $warnings.Add([pscustomobject]@{ Check = $check; Detail = $detail }) }
    function RPass($check) { $passes.Add($check) }

    # ---- 1. ParagraphLength ------------------------------------------------
    # A table cell is a bounded column with a row height; the cap is for prose.
    $long = @($paras | Where-Object { -not $_.InCell -and -not $_.IsToc -and $_.Chars -gt $MaxChars })
    if ($long.Count) {
        foreach ($p in ($long | Sort-Object Chars -Descending | Select-Object -First 10)) {
            RFail 'ParagraphLength' ("{0} chars (~{1} lines, cap {2}): {3}..." -f $p.Chars, $p.Lines, $MaxChars, $p.Text.Substring(0, [Math]::Min(70, $p.Text.Length)))
        }
        if ($long.Count -gt 10) { RFail 'ParagraphLength' ("... and {0} more" -f ($long.Count - 10)) }
    } else { RPass 'ParagraphLength' }

    # ---- 2. RunOnList ------------------------------------------------------
    # A list someone wrote as a sentence. Two shapes, both observed in real builds.
    $runon = New-Object System.Collections.Generic.List[object]
    foreach ($p in $paras) {
        if ($p.InCell -or $p.IsToc) { continue }
        # a) a hyphen run: two or more " - " separators inside one paragraph
        $hyphens = ([regex]::Matches($p.Text, '\s-\s')).Count
        if ($hyphens -ge 2) { $runon.Add(@{ P = $p; Why = "$hyphens hyphen separators"; Soft = $false }); continue }
        # b) a SINGLE SENTENCE carrying five or more separated clauses.
        #
        # Measured per sentence, not per paragraph. A correct three-line
        # paragraph of three sentences naturally carries four or more commas
        # across the whole block - counting them together flagged legitimate
        # prose, which is how a gate teaches people to ignore it. A run-on list
        # is commas inside ONE long sentence, not commas across several.
        foreach ($sent in ($p.Text -split '(?<=[.!?])\s+')) {
            if ($sent.Length -le $cfg.LongSentChars) { continue }
            $seps = ([regex]::Matches($sent, '[;,]\s')).Count
            if ($seps -ge $cfg.LongSentClause) { $runon.Add(@{ P = $p; Why = "$seps clauses in one $($sent.Length)-char sentence"; Soft = $true }) }
        }
    }
    $hard = @($runon | Where-Object { -not $_.Soft })
    $soft = @($runon | Where-Object { $_.Soft })
    if ($hard.Count) {
        foreach ($r in ($hard | Select-Object -First 10)) {
            RFail 'RunOnList' ("{0}: {1}..." -f $r.Why, $r.P.Text.Substring(0, [Math]::Min(70, $r.P.Text.Length)))
        }
        if ($hard.Count -gt 10) { RFail 'RunOnList' ("... and {0} more" -f ($hard.Count - 10)) }
    } else { RPass 'RunOnList' }
    foreach ($r in ($soft | Select-Object -First 5)) {
        RWarn 'LongSentenceClauses' ("{0}: {1}..." -f $r.Why, $r.P.Text.Substring(0, [Math]::Min(70, $r.P.Text.Length)))
    }

    # ---- 2b. StackedShortParagraphs ----------------------------------------
    # THE DEFECT A READER ACTUALLY NOTICES. Four or more consecutive short
    # paragraphs, none of them bulleted, read as a list that has lost its dots.
    # It happens when prose is split one sentence per line and rendered one
    # paragraph per line. Either they ARE a list, and want real bullets, or they
    # are prose, and want joining back into a paragraph inside the three-line cap.
    $stack = New-Object System.Collections.Generic.List[object]
    $run = 0; $runStart = $null
    foreach ($p in $paras) {
        # Whitespace-tolerant on purpose. A document that has been through the
        # docx-images artwork step is re-serialised by XmlDocument, which writes
        # <w:keepNext /> with a space. Matching the tight form only, this stopped
        # recognising every heading in a placed document and reported the
        # paragraphs after each one as an unbulleted stack.
        $isHeading    = ($p.Ppr -match '<w:keepNext\s*/>')
        $isShortProse = (-not $p.InCell) -and (-not $p.IsToc) -and (-not $p.IsList) -and (-not $p.IsNumStep) -and (-not $isHeading) -and $p.Chars -le $cfg.StackChars
        if ($isShortProse) {
            if ($run -eq 0) { $runStart = $p }
            $run++
        } else {
            if ($run -ge $cfg.StackRun) { $stack.Add(@{ N = $run; First = $runStart }) }
            $run = 0
        }
    }
    if ($run -ge $cfg.StackRun) { $stack.Add(@{ N = $run; First = $runStart }) }
    if ($stack.Count) {
        foreach ($s in ($stack | Select-Object -First 8)) {
            RFail 'StackedShortParagraphs' ("{0} consecutive short paragraphs with no bullets - reads as a list without dots. From: {1}..." -f $s.N, $s.First.Text.Substring(0, [Math]::Min(60, $s.First.Text.Length)))
        }
        if ($stack.Count -gt 8) { RFail 'StackedShortParagraphs' ("... and {0} more run(s)" -f ($stack.Count - 8)) }
    } else { RPass 'StackedShortParagraphs' }

    # ---- 2c. OrphanLeadIn ---------------------------------------------------
    # A HEADING MUST NEVER SEPARATE FROM ITS CONTENT. A paragraph ending in a
    # colon introduces what follows, so without keepNext it can strand at the
    # foot of a page while its list starts the next one. Observed in the wild:
    # "Wastage allowance to apply:" closed page 41 and its three bullets opened
    # page 42.
    #
    # Cells are excluded - the cover sheet's "Student Name:" fields are approved
    # front matter and are laid out by the template, not by us.
    $orphan = @($paras | Where-Object {
        -not $_.InCell -and -not $_.IsToc -and $_.Text.EndsWith(':') -and ($_.Ppr -notmatch '<w:keepNext\s*/>')
    })
    if ($orphan.Count) {
        foreach ($o in ($orphan | Select-Object -First 10)) {
            RFail 'OrphanLeadIn' ("lead-in has no keepNext and can strand at a page foot: {0}" -f $o.Text.Substring(0, [Math]::Min(75, $o.Text.Length)))
        }
        if ($orphan.Count -gt 10) { RFail 'OrphanLeadIn' ("... and {0} more" -f ($orphan.Count - 10)) }
    } else { RPass 'OrphanLeadIn' }

    # ---- 3. BulletSpacing --------------------------------------------------
    # Bullets flush against each other are unreadable. Body bullets only - a panel
    # bullet is deliberately tighter because it sits inside a bounded cell.
    $tight = @($paras | Where-Object { -not $_.InCell -and -not $_.IsToc -and $_.IsList -and $_.After -lt $MinBulletAfter })
    if ($tight.Count) {
        RFail 'BulletSpacing' ("{0} body bullet(s) carry after<{1}. First: {2}..." -f $tight.Count, $MinBulletAfter, $tight[0].Text.Substring(0, [Math]::Min(60, $tight[0].Text.Length)))
    } else { RPass 'BulletSpacing' }

    # ---- 4. ListParagraphIsList --------------------------------------------
    # A ListParagraph with no numbering renders as an indented paragraph that
    # looks like a list item and is not one.
    $fakeList = @($paras | Where-Object { $_.IsList -and -not $_.IsToc -and -not $_.HasNumPr })
    if ($fakeList.Count) {
        RFail 'ListParagraphIsList' ("{0} paragraph(s) styled ListParagraph carry no numPr. First: {1}..." -f $fakeList.Count, $fakeList[0].Text.Substring(0, [Math]::Min(60, $fakeList[0].Text.Length)))
    } else { RPass 'ListParagraphIsList' }

    # A literal bullet glyph in BODY prose is the cell/panel exception leaking out.
    $bul = [char]0x2022
    $strayGlyph = @($paras | Where-Object { -not $_.InCell -and -not $_.IsToc -and $_.Text.StartsWith($bul) })
    if ($strayGlyph.Count) {
        RWarn 'LiteralBulletInBody' ("{0} body paragraph(s) open with a literal bullet glyph. Body prose uses real Word numbering." -f $strayGlyph.Count)
    }

    $prose = @($paras | Where-Object { -not $_.InCell -and -not $_.IsToc })
    $longest = $prose | Sort-Object Chars -Descending | Select-Object -First 1

    [pscustomobject]@{
        Ok              = ($failures.Count -eq 0)
        Failures        = $failures.ToArray()
        Warnings        = $warnings.ToArray()
        Passed          = $passes.ToArray()
        ParagraphCount  = $prose.Count
        ListItemCount   = @($paras | Where-Object { $_.IsList -and $_.HasNumPr }).Count
        OverCapCount    = $long.Count
        RunOnCount      = @($runon | Where-Object { -not $_.Soft }).Count
        LongestChars    = $(if ($longest) { $longest.Chars } else { 0 })
        LongestLines    = $(if ($longest) { $longest.Lines } else { 0 })
        LongestText     = $(if ($longest) { $longest.Text } else { '' })
    }
}

function Write-ReadabilityReport {
    <# Print a readability result. Returns $true when the build may proceed. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Result, [string] $Label = '')

    $tag = if ($Label) { " $Label" } else { '' }
    Write-Host ("Readability{0}: {1} prose paragraph(s), {2} real list item(s). Longest paragraph {3} chars (~{4} lines)." -f `
                $tag, $Result.ParagraphCount, $Result.ListItemCount, $Result.LongestChars, $Result.LongestLines)

    foreach ($w in $Result.Warnings) { Write-Host ("  WARN [{0}] {1}" -f $w.Check, $w.Detail) }

    if ($Result.Ok) {
        Write-Host ("  PASS: {0}" -f ($Result.Passed -join ', '))
        return $true
    }
    Write-Host ("  FAILED{0}:" -f $tag)
    foreach ($f in $Result.Failures) { Write-Host ("    [{0}] {1}" -f $f.Check, $f.Detail) }
    return $false
}

Write-Verbose 'Test-Readability.ps1 loaded.'
