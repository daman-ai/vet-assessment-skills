# Derives the RTO's own house TAS structure from the eighteen documents: which sections
# they actually use, how many of the eighteen carry each one, and where each sits on
# average. The canonical order is the median position, so the house format is what the
# RTO already does most often rather than anything imported.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-DocXml($path) {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($path)
    try {
        $e = $zip.Entries | Where-Object { $_.FullName -eq 'word/document.xml' } | Select-Object -First 1
        $sr = New-Object System.IO.StreamReader($e.Open()); $x = $sr.ReadToEnd(); $sr.Close()
    } finally { $zip.Dispose() }
    return $x
}
function Clean($s) { (([System.Net.WebUtility]::HtmlDecode((($s -replace '<[^>]+>','') -replace '\s+',' ')))).Trim() }
function Key($s) {
    $k = $s.ToLower().Trim() -replace '[:–—\-\.\*]+$','' -replace '\s+',' '
    $k = $k -replace '^\d+(\.\d+)*\s*[a-z]?\)?\s*',''      # strip 1.2 b) style numbering
    return $k.Trim()
}
$UNIT = '^[A-Z]{3}[A-Z]{0,4}\d{3,5}'

$src = Join-Path $env:USERPROFILE 'TAS-source\original'
$stat = @{}
$docs = @(Get-ChildItem $src -Filter '*.docx' | Sort-Object Name)

foreach ($f in $docs) {
    $id = $f.BaseName
    $x  = Get-DocXml $f.FullName
    $seen = @{}
    $ordinal = 0

    $items = @()
    foreach ($m in [regex]::Matches($x, '<w:p\b(?:(?!</w:p>).)*?<w:pStyle w:val="(Heading\d|Title|Subtitle)"(?:(?!</w:p>).)*?</w:p>')) {
        $items += @{ pos = $m.Index; text = (Clean $m.Value) }
    }
    foreach ($tr in [regex]::Matches($x, '<w:tr\b(?:(?!</w:tr>).)*?</w:tr>')) {
        $cells = [regex]::Matches($tr.Value, '<w:tc\b(?:(?!</w:tc>).)*?</w:tc>')
        if ($cells.Count -eq 2) { $items += @{ pos = $tr.Index; text = (Clean $cells[0].Value) } }
    }
    foreach ($it in ($items | Sort-Object { $_.pos })) {
        $t = $it.text
        if (-not $t -or $t.Length -lt 4 -or $t.Length -gt 70) { continue }
        if ($t -match $UNIT) { continue }                   # unit rows, not sections
        if ($t -match '^\d+$') { continue }
        $k = Key $t
        if ($k.Length -lt 4 -or $seen[$k]) { continue }
        $seen[$k] = $true
        $ordinal++
        if (-not $stat.ContainsKey($k)) { $stat[$k] = @{ docs = @(); positions = @(); example = $t } }
        $stat[$k].docs += $id
        $stat[$k].positions += $ordinal
    }
}

$rows = foreach ($k in $stat.Keys) {
    $p = @($stat[$k].positions | Sort-Object)
    [pscustomobject]@{
        section = $stat[$k].example
        inDocs  = @($stat[$k].docs | Select-Object -Unique).Count
        median  = $p[[int]($p.Count/2)]
    }
}

"SECTIONS IN 12 OR MORE OF THE 18 DOCUMENTS, IN HOUSE ORDER"
""
"{0,-6} {1,-7} {2}" -f 'IN','MEDIAN','SECTION'
foreach ($r in ($rows | Where-Object { $_.inDocs -ge 12 } | Sort-Object median)) {
    "{0,-6} {1,-7} {2}" -f "$($r.inDocs)/18", $r.median, $r.section
}
""
"sections in 6 to 11 documents (used, but not house-wide):"
foreach ($r in ($rows | Where-Object { $_.inDocs -ge 6 -and $_.inDocs -lt 12 } | Sort-Object median)) {
    "   {0,-6} {1}" -f "$($r.inDocs)/18", $r.section
}
$rows | Sort-Object median | Export-Csv (Join-Path $PSScriptRoot 'house-structure.csv') -NoTypeInformation -Encoding UTF8
