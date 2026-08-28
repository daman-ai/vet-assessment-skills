<#
    Get-DocText.ps1  -  dump a .docx or .pptx to plain text for review.

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

    ASCII only in this file.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $Path,
    [Parameter(Mandatory)][string] $OutPath
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$tmp = Join-Path $env:TEMP ("dt_" + [Guid]::NewGuid().ToString('N').Substring(0,8))
[System.IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path -LiteralPath $Path).Path, $tmp)

function Strip ([string] $xml, [string] $tag) {
    # Paragraph breaks first, then drop every tag - without the newline step
    # adjacent paragraphs run together into sentences nobody wrote.
    $t = [regex]::Replace($xml, "</$tag>", "`n")
    $t = $t -replace '<[^>]+>', ''
    return [System.Net.WebUtility]::HtmlDecode($t)
}

$sb = New-Object System.Text.StringBuilder

if ($Path -match '\.pptx$') {
    $slides = Get-ChildItem (Join-Path $tmp 'ppt\slides') -Filter 'slide*.xml' |
              Sort-Object { [int]([regex]::Match($_.Name, '\d+').Value) }
    foreach ($s in $slides) {
        $n = [int]([regex]::Match($s.Name, '\d+').Value)
        [void]$sb.AppendLine("=== SLIDE $n ===")
        [void]$sb.AppendLine((Strip (Get-Content $s.FullName -Raw -Encoding UTF8) 'a:p').Trim())
        $notes = Join-Path $tmp "ppt\notesSlides\notesSlide$n.xml"
        if (Test-Path -LiteralPath $notes) {
            [void]$sb.AppendLine("--- notes ---")
            [void]$sb.AppendLine((Strip (Get-Content $notes -Raw -Encoding UTF8) 'a:p').Trim())
        }
        [void]$sb.AppendLine()
    }
} else {
    $doc = Join-Path $tmp 'word\document.xml'
    $xml = Get-Content $doc -Raw -Encoding UTF8
    [void]$sb.AppendLine((Strip $xml 'w:p'))
    $alts = [regex]::Matches($xml, 'descr="([^"]{20,})"')
    if ($alts.Count) {
        [void]$sb.AppendLine("`n=== FIGURE ALT TEXT ===")
        foreach ($a in $alts) { [void]$sb.AppendLine('* ' + [System.Net.WebUtility]::HtmlDecode($a.Groups[1].Value)) }
    }
}

$text = ($sb.ToString() -split "`n" | ForEach-Object { $_.TrimEnd() }) -join "`n"
$text = [regex]::Replace($text, "(`n\s*){3,}", "`n`n")
Set-Content -LiteralPath $OutPath -Value $text -Encoding UTF8
Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ("{0} -> {1} ({2:N0} chars)" -f (Split-Path $Path -Leaf), $OutPath, $text.Length)
