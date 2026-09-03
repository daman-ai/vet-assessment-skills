<#
    Get-DocText.ps1  -  dump a .docx or .pptx to plain text for review, and
    STAMP the extract with what it does and does not contain.

    The fast path for Stage 5 personas, the Stage 6 clean-room audit and the
    figure-consistency gate: reviewers read a text extract in seconds instead
    of driving Word COM for minutes, and the same extract feeds
    Test-FigureConsistency -DocText so the gate covers the RENDERED documents,
    not only their sources.

      .\Get-DocText.ps1 -Path guide.docx -OutPath guide.txt
      .\Get-DocText.ps1 -Path deck.pptx  -OutPath deck.txt

    A .pptx extracts one block per slide with its speaker notes. A .docx also
    appends every drawing's alt text - a diagram's labels live there, so a
    review that skips alt text has not read the figures.

    THE STAMP, AND WHY EVERY EXTRACT CARRIES ONE. Every extract opens with a
    provenance header, then ONE blank line, then the text:

      FIGURES: <n> placed drawings, <m> unresolved artwork prompt blocks
      CHANNELS: <k> tables, <s> slides, <c> captions, <a> alt texts, <p> speaker notes
      SOURCE: <file>  SHA256: <hash of the package bytes>  EXTRACTED: <ISO-8601 UTC>

    Only the channel counts that apply to the artefact type are written, and
    0 is a real count. Where m > 0 a fourth line follows the SOURCE line:
    FIGURE CONTENT NOT PRESENT IN THIS EXTRACT.

    On one build the round-1 audit was handed a guide whose every figure was
    still a prompt block. It reported every figure missing, the report was set
    aside as expected, and nobody drew the consequence: the figures had never
    been read by anyone, and the ledger said they had. A reviewer cannot
    notice what an extract does not contain, so the extract now says it
    before its first line of prose. The SOURCE line ties the extract to the
    exact package bytes it was cut from, so two extracts of one document and
    extracts of two documents can be told apart without opening either.

    THE TEXT AFTER THE BLANK LINE IS NOT CHANGED BY ONE BYTE. Reviewers and
    gates compare extracts, and Assert-RenderDelta hashes them per topic. The
    stamp is prepended, never mixed in; a consumer that wants the bare text
    takes everything after the first blank line.

    THE COUNTS COME FROM THE PARTS THIS SCRIPT READS, BY THE TESTS THE GATES
    USE. A drawing is a wp:docPr in document.xml or any header or footer (on a
    deck, a picture-class p:cNvPr in a slide or its notes) - the Check-Figures
    test. A prompt block is a paragraph whose text starts with [IMAGE: or
    [DIAGRAM: in the parts the text is cut from. A caption is a paragraph that
    starts with the figure number AND declares itself one by style, centring
    or italic - again the Check-Figures test, so an in-prose cross-reference
    cannot count. A speaker note is real prose, twenty characters once the
    slide-number field is discounted - the Test-DeckRules test. Two counts of
    the same thing by two rules is a disagreement waiting to be found.

    THE HASH IS WRITTEN AS BYTE PAIRS (7F-3A-...), which is the .NET rendering
    of a hash, and not as one 64-character run. The figure registry sweeps
    every extract for stale numeric literals with no word boundary, so a bare
    four- or five-digit forbid has roughly a one-in-a-thousand chance of
    occurring inside any 64-hex string, and a gate that fails one build in a
    hundred on its own stamp is a gate people learn to re-run. With no digit
    run longer than two, no registry literal of three or more digits can match
    inside the stamp, and a one- or two-digit forbid would already fail on the
    body's own page numbers long before it reached the header.

    ASCII only in this file.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $Path,
    [Parameter(Mandatory)][string] $OutPath
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$full = (Resolve-Path -LiteralPath $Path).Path
$tmp = Join-Path $env:TEMP ("dt_" + [Guid]::NewGuid().ToString('N').Substring(0,8))
[System.IO.Compression.ZipFile]::ExtractToDirectory($full, $tmp)

function Strip ([string] $xml, [string] $tag) {
    # Paragraph breaks first, then drop every tag - without the newline step
    # adjacent paragraphs run together into sentences nobody wrote.
    $t = [regex]::Replace($xml, "</$tag>", "`n")
    $t = $t -replace '<[^>]+>', ''
    return [System.Net.WebUtility]::HtmlDecode($t)
}

function Measure-PromptBlocks ([string] $paragraphText) {
    # One paragraph per line, exactly as Strip lays them out.
    $n = 0
    foreach ($ln in ($paragraphText -split "`n")) {
        if ($ln.TrimStart() -match '^\[(IMAGE|DIAGRAM):') { $n++ }
    }
    return $n
}

function Measure-Drawings ([string[]] $parts, [string] $prTag, [bool] $pictureClassOnly) {
    # Returns drawings and non-empty alt texts, by the Check-Figures test.
    $drawn = 0
    $alt = 0
    foreach ($xml in $parts) {
        foreach ($m in [regex]::Matches($xml, $prTag)) {
            if ($pictureClassOnly -and $m.Value -notmatch '(?i)name="(picture|image|graphic|chart|diagram)') { continue }
            $drawn++
            $descr = [regex]::Match($m.Value, 'descr="([^"]*)"').Groups[1].Value
            if ([System.Net.WebUtility]::HtmlDecode($descr).Trim()) { $alt++ }
        }
    }
    return @($drawn, $alt)
}

function Measure-Captions ([string] $xml) {
    # A caption paragraph starts with the figure number and declares itself a
    # caption by style, centring or italic - the Check-Figures test, so that a
    # paragraph beginning "Figure 2.3.4 shows ..." is not counted.
    $n = 0
    $capRx = '^\s*Figure\s+(\d+(?:\.\d+)+)'
    foreach ($pm in [regex]::Matches($xml, '<w:p\b[^>]*>.*?</w:p>', 'Singleline')) {
        $p = $pm.Value
        $text = -join ([regex]::Matches($p, '<w:t[^>]*>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value })
        $text = [System.Net.WebUtility]::HtmlDecode($text)
        if ($text -notmatch $capRx) { continue }
        $style = [regex]::Match($p, '<w:pStyle w:val="([^"]*)"').Groups[1].Value
        if ($style -and $style -match '(?i)caption') { $n++; continue }
        if ($p -match '<w:jc w:val="center"\s*/>') { $n++; continue }
        if ($p -match '<w:i\s*/>' -and $text.Trim().StartsWith('Figure')) { $n++; continue }
    }
    return $n
}

$sb = New-Object System.Text.StringBuilder
$placed  = 0
$prompts = 0
$channels = New-Object System.Collections.Generic.List[string]

if ($Path -match '\.pptx$') {
    $slides = Get-ChildItem (Join-Path $tmp 'ppt\slides') -Filter 'slide*.xml' |
              Sort-Object { [int]([regex]::Match($_.Name, '\d+').Value) }
    $tables = 0
    $notesWithProse = 0
    $drawingParts = New-Object System.Collections.Generic.List[string]
    foreach ($s in $slides) {
        $n = [int]([regex]::Match($s.Name, '\d+').Value)
        $sx = Get-Content $s.FullName -Raw -Encoding UTF8
        $drawingParts.Add($sx)
        $tables += ([regex]::Matches($sx, '<a:tbl>')).Count
        $slideText = (Strip $sx 'a:p').Trim()
        $prompts += Measure-PromptBlocks $slideText
        [void]$sb.AppendLine("=== SLIDE $n ===")
        [void]$sb.AppendLine($slideText)
        $notes = Join-Path $tmp "ppt\notesSlides\notesSlide$n.xml"
        if (Test-Path -LiteralPath $notes) {
            $nx = Get-Content $notes -Raw -Encoding UTF8
            $drawingParts.Add($nx)
            $notesText = (Strip $nx 'a:p').Trim()
            $prompts += Measure-PromptBlocks $notesText
            # the slide-number field also emits an <a:t>; require real prose
            $body = -join ([regex]::Matches($nx, '<a:t>([^<]*)</a:t>') | ForEach-Object { $_.Groups[1].Value })
            if (($body -replace '\d', '').Trim().Length -ge 20) { $notesWithProse++ }
            [void]$sb.AppendLine("--- notes ---")
            [void]$sb.AppendLine($notesText)
        }
        [void]$sb.AppendLine()
    }
    $counts = Measure-Drawings -parts $drawingParts.ToArray() -prTag '<p:cNvPr\b[^>]*>' -pictureClassOnly $true
    $placed = [int]$counts[0]
    $channels.Add(("{0} tables" -f $tables))
    $channels.Add(("{0} slides" -f @($slides).Count))
    $channels.Add(("{0} speaker notes" -f $notesWithProse))
} else {
    $doc = Join-Path $tmp 'word\document.xml'
    $xml = Get-Content $doc -Raw -Encoding UTF8
    $bodyText = Strip $xml 'w:p'
    [void]$sb.AppendLine($bodyText)
    $alts = [regex]::Matches($xml, 'descr="([^"]{20,})"')
    if ($alts.Count) {
        [void]$sb.AppendLine("`n=== FIGURE ALT TEXT ===")
        foreach ($a in $alts) { [void]$sb.AppendLine('* ' + [System.Net.WebUtility]::HtmlDecode($a.Groups[1].Value)) }
    }
    # Drawings live in the body AND in the running head and foot (the mark
    # is a picture), so every header and footer part is counted with it.
    $drawingParts = New-Object System.Collections.Generic.List[string]
    $drawingParts.Add($xml)
    foreach ($hf in (Get-ChildItem (Join-Path $tmp 'word') -File | Where-Object { $_.Name -match '^(header|footer)\d*\.xml$' } | Sort-Object Name)) {
        $drawingParts.Add((Get-Content $hf.FullName -Raw -Encoding UTF8))
    }
    $counts = Measure-Drawings -parts $drawingParts.ToArray() -prTag '<wp:docPr\b[^>]*>' -pictureClassOnly $false
    $placed  = [int]$counts[0]
    $prompts = Measure-PromptBlocks $bodyText
    $channels.Add(("{0} tables" -f ([regex]::Matches($xml, '<w:tbl>')).Count))
    $channels.Add(("{0} captions" -f (Measure-Captions $xml)))
    $channels.Add(("{0} alt texts" -f [int]$counts[1]))
}

$text = ($sb.ToString() -split "`n" | ForEach-Object { $_.TrimEnd() }) -join "`n"
$text = [regex]::Replace($text, "(`n\s*){3,}", "`n`n")

# ---- the stamp. Byte pairs for the hash: see the header.
$sha = [System.Security.Cryptography.SHA256]::Create()
try   { $hash = [BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes($full))) }
finally { $sha.Dispose() }
$stampLines = New-Object System.Collections.Generic.List[string]
$stampLines.Add(("FIGURES: {0} placed drawings, {1} unresolved artwork prompt blocks" -f $placed, $prompts))
$stampLines.Add(("CHANNELS: {0}" -f ($channels -join ', ')))
$stampLines.Add(("SOURCE: {0}  SHA256: {1}  EXTRACTED: {2}" -f (Split-Path $full -Leaf), $hash, (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')))
if ($prompts -gt 0) { $stampLines.Add('FIGURE CONTENT NOT PRESENT IN THIS EXTRACT') }
$stamp = $stampLines -join "`n"

Set-Content -LiteralPath $OutPath -Value ($stamp + "`n`n" + $text) -Encoding UTF8
Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ("{0} -> {1} ({2:N0} chars)" -f (Split-Path $Path -Leaf), $OutPath, $text.Length)
foreach ($l in $stampLines) { Write-Host ("  " + $l) -ForegroundColor DarkGray }
