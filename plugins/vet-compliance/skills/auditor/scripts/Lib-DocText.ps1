# Lib-DocText.ps1 - text extraction for the document register and the
# superseded-reference scan.
#
# Three tiers, because the cost differs by two orders of magnitude:
#
#   .docx .xlsx .pptx   read the OOXML directly out of the zip. No Office, fast.
#   .md .txt .csv .json read the bytes.
#   .pdf .doc .xls      Word or Excel COM. Slow, needs Office, and is the only
#                       way to read a legacy binary or a PDF here.
#
# COM is opt-in via -UseOffice. A register scan over a folder of PDFs without it
# records the file and marks the text as unread rather than silently returning
# an empty string - an unread document that looks like an empty one produces a
# clean superseded-reference scan and a false all-clear.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

# ------------------------------------------------------------------ OOXML ---

function Get-OoxmlText {
    <#
      Pulls the text out of an Office Open XML package without opening Office.
      Reads every part matching $PartPattern, strips markup, and joins the runs
      with spaces so words either side of a formatting boundary do not fuse.
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$PartPattern = '^word/(document|header\d*|footer\d*)\.xml$'
    )

    $zip = $null
    $sb  = New-Object System.Text.StringBuilder
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Path).Path)
        foreach ($entry in $zip.Entries) {
            if ($entry.FullName -notmatch $PartPattern) { continue }
            $reader = New-Object System.IO.StreamReader($entry.Open())
            try   { $xml = $reader.ReadToEnd() }
            finally { $reader.Dispose() }

            # Paragraph and row ends become newlines before tags are stripped,
            # so "clause 6.1" cannot be manufactured by two adjacent cells.
            $xml = $xml -replace '</w:p>', "`n"
            $xml = $xml -replace '</a:p>', "`n"
            $xml = $xml -replace '</w:tr>', "`n"
            $xml = $xml -replace '<w:br[^>]*/>', "`n"
            $xml = $xml -replace '<[^>]+>', ' '
            [void]$sb.AppendLine($xml)
        }
    }
    finally {
        if ($zip) { $zip.Dispose() }
    }

    $text = $sb.ToString()
    $text = [System.Net.WebUtility]::HtmlDecode($text)
    # Collapse runs of spaces and tabs; keep newlines.
    $text = $text -replace '[ \t]+', ' '
    $text = $text -replace '(\r?\n)[ \t]+', "`n"
    $text = $text -replace '(\r?\n){3,}', "`n`n"
    return $text.Trim()
}

function Get-XlsxText {
    <#
      Shared strings plus every cell's inline text. Enough to find a superseded
      reference inside a register or a matrix; not a spreadsheet reader.
    #>
    param([Parameter(Mandatory)][string]$Path)
    return Get-OoxmlText -Path $Path -PartPattern '^xl/(sharedStrings\.xml|worksheets/sheet\d+\.xml)$'
}

# -------------------------------------------------------------------- COM ---

function Get-OfficeText {
    <#
      Word COM for .pdf, .doc and .rtf. Opens read-only and invisible, and
      always closes - an orphaned WINWORD.EXE holds the file and the next run
      blocks on it.
    #>
    param([Parameter(Mandatory)][string]$Path)

    $word = $null; $doc = $null
    try {
        $word = New-Object -ComObject Word.Application
        $word.Visible = $false
        $word.DisplayAlerts = 0
        $full = (Resolve-Path -LiteralPath $Path).Path
        # ConfirmConversions:$false stops the PDF-import prompt.
        $doc = $word.Documents.Open($full, $false, $true, $false)
        return $doc.Content.Text
    }
    finally {
        if ($doc)  { try { $doc.Close([ref]$false) } catch { } }
        if ($word) { try { $word.Quit() } catch { } ; [void][Runtime.InteropServices.Marshal]::ReleaseComObject($word) }
        [GC]::Collect(); [GC]::WaitForPendingFinalizers()
    }
}

function Get-LegacyXlsText {
    param([Parameter(Mandatory)][string]$Path)

    $excel = $null; $wb = $null
    $sb = New-Object System.Text.StringBuilder
    try {
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        $wb = $excel.Workbooks.Open((Resolve-Path -LiteralPath $Path).Path, 0, $true)
        foreach ($ws in $wb.Worksheets) {
            $used = $ws.UsedRange
            if ($null -eq $used) { continue }
            $vals = $used.Value2
            if ($null -eq $vals) { continue }
            if ($vals -is [object[,]]) {
                for ($r = 1; $r -le $vals.GetLength(0); $r++) {
                    $row = @()
                    for ($c = 1; $c -le $vals.GetLength(1); $c++) { $row += [string]$vals[$r, $c] }
                    [void]$sb.AppendLine(($row -join ' '))
                }
            } else {
                [void]$sb.AppendLine([string]$vals)
            }
        }
        return $sb.ToString()
    }
    finally {
        if ($wb)    { try { $wb.Close($false) } catch { } }
        if ($excel) { try { $excel.Quit() } catch { } ; [void][Runtime.InteropServices.Marshal]::ReleaseComObject($excel) }
        [GC]::Collect(); [GC]::WaitForPendingFinalizers()
    }
}

# ------------------------------------------------------------- dispatcher ---

function Get-DocumentText {
    <#
      Returns a result object rather than a string, because "no text" and "text
      not read" are different facts and only one of them is a clean scan.

        Text     the extracted text, or ''
        Read     $true only where the content was genuinely read
        Method   how
        Note     why not, where Read is $false
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$UseOffice
    )

    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    $res = [pscustomobject]@{ Text = ''; Read = $false; Method = 'none'; Note = '' }

    try {
        switch ($ext) {
            '.docx' { $res.Text = Get-OoxmlText -Path $Path; $res.Read = $true; $res.Method = 'ooxml' }
            '.dotx' { $res.Text = Get-OoxmlText -Path $Path; $res.Read = $true; $res.Method = 'ooxml' }
            '.docm' { $res.Text = Get-OoxmlText -Path $Path; $res.Read = $true; $res.Method = 'ooxml' }
            '.xlsx' { $res.Text = Get-XlsxText  -Path $Path; $res.Read = $true; $res.Method = 'ooxml' }
            '.xlsm' { $res.Text = Get-XlsxText  -Path $Path; $res.Read = $true; $res.Method = 'ooxml' }
            '.pptx' { $res.Text = Get-OoxmlText -Path $Path -PartPattern '^ppt/slides/slide\d+\.xml$'; $res.Read = $true; $res.Method = 'ooxml' }
            { $_ -in '.md', '.txt', '.csv', '.json', '.html', '.htm', '.xml' } {
                $res.Text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
                if ($ext -in '.html', '.htm', '.xml') { $res.Text = $res.Text -replace '<[^>]+>', ' ' }
                $res.Read = $true; $res.Method = 'text'
            }
            { $_ -in '.pdf', '.doc', '.rtf' } {
                if ($UseOffice) { $res.Text = Get-OfficeText -Path $Path; $res.Read = $true; $res.Method = 'word-com' }
                else { $res.Note = "$ext needs -UseOffice; text not read" }
            }
            '.xls' {
                if ($UseOffice) { $res.Text = Get-LegacyXlsText -Path $Path; $res.Read = $true; $res.Method = 'excel-com' }
                else { $res.Note = '.xls needs -UseOffice; text not read' }
            }
            default { $res.Note = "unsupported extension $ext" }
        }
    } catch {
        $res.Read = $false
        $res.Note = "extraction failed: $($_.Exception.Message)"
    }

    if ($null -eq $res.Text) { $res.Text = '' }
    return $res
}

# ----------------------------------------------------- superseded scanning ---

# Each pattern is a flag, not a finding. A document control table that records
# "replaces the 2015 Standards version" is a correct use of the phrase.
# references/inventory.md says what each one means.
$script:SupersededPatterns = @(
    @{ Id = 'SRTO2015-named';  Pattern = '(?i)standards\s+for\s+(registered\s+training\s+organisations|rtos)[^\.\n]{0,40}2015'; Why = 'Names an instrument repealed in full by Schedule 3 of F2025L00355' }
    @{ Id = 'SRTO2015-short';  Pattern = '(?i)\bSRTOs?\s*2015\b'; Why = 'Names the repealed 2015 Standards' }
    @{ Id = 'NVR2012';         Pattern = '(?i)standards\s+for\s+NVR\s+registered\s+training\s+organisations\s+2012'; Why = 'Three generations superseded' }
    @{ Id = 'clause-ref';      Pattern = '(?i)\bclause\s+\d+\.\d+'; Why = 'The 2015 Standards used clauses; the 2025 Outcome Standards use Standards' }
    @{ Id = 'schedule-5-6';    Pattern = '(?i)\bschedule\s+[56]\b'; Why = '2015 Standards schedules. No equivalent in the 2025 instruments' }
    @{ Id = 'aqtf';            Pattern = '(?i)\bAQTF\b'; Why = 'Superseded by the 2015 Standards, themselves now repealed' }
    @{ Id = 'vqf';             Pattern = '(?i)VET\s+Quality\s+Framework'; Why = 'Check whether it is used as a defined term with a 2015 meaning' }
    @{ Id = 'nc2007';          Pattern = '(?i)national\s+code[^\.\n]{0,20}2007'; Why = 'Superseded by the National Code 2018' }
    @{ Id = 'tae-legacy';      Pattern = '(?i)\bTAE401(10|16)\b'; Why = 'Still acceptable credentials. Flag for checking, not a defect' }
    @{ Id = 'esos-preamend';   Pattern = '(?i)ESOS\s+Act\s+2000[^\.\n]{0,60}(2019|2020|2021|2022|2023)'; Why = 'Check against the 2025 integrity amendments' }
)

function Find-SupersededText {
    <#
      Returns one row per distinct pattern hit, with up to three excerpts each.
      Distinct, not per-occurrence: a policy citing forty 2015 clauses is one
      finding, and forty rows would bury the document that cites one.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    $hits = @()
    if ([string]::IsNullOrWhiteSpace($Text)) { return $hits }

    foreach ($p in $script:SupersededPatterns) {
        $matches = [regex]::Matches($Text, $p.Pattern)
        if ($matches.Count -eq 0) { continue }

        $excerpts = @()
        foreach ($m in ($matches | Select-Object -First 3)) {
            $start = [Math]::Max(0, $m.Index - 45)
            $len   = [Math]::Min($Text.Length - $start, $m.Length + 90)
            $excerpts += (($Text.Substring($start, $len) -replace '\s+', ' ').Trim())
        }

        $hits += [pscustomobject]@{
            Id       = $p.Id
            Why      = $p.Why
            Count    = $matches.Count
            Excerpts = $excerpts
        }
    }
    return $hits
}
