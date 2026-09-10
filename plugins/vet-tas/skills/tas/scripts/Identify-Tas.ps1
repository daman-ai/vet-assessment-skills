# Reads each downloaded TAS and says which RTO and qualification it is actually for,
# from the text inside the document rather than from its filename. Filenames in the
# Downloads folder have been reused across institutes, so they cannot be trusted.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-DocxText {
    param([string]$Path, [int]$Max = 60000)
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $e = $zip.Entries | Where-Object { $_.FullName -eq 'word/document.xml' } | Select-Object -First 1
        if (-not $e) { return '' }
        $sr = New-Object System.IO.StreamReader($e.Open())
        $xml = $sr.ReadToEnd(); $sr.Close()
    } finally { $zip.Dispose() }
    $t = $xml -replace '<w:p[ >]', "`n<w:p " -replace '<[^>]+>', ' '
    $t = [System.Net.WebUtility]::HtmlDecode($t) -replace '[ \t]+', ' '
    if ($t.Length -gt $Max) { $t = $t.Substring(0, $Max) }
    return $t
}

$dl = Join-Path $env:USERPROFILE 'Downloads'
$files = Get-ChildItem $dl -File -Filter '*.docx' |
         Where-Object { $_.Name -match '^(TAS|Training-and-Assessment)' -and $_.LastWriteTime -gt (Get-Date).Date } |
         Sort-Object LastWriteTime

"{0,-5} {1,-34} {2,-12} {3}" -f 'TIME','INSTITUTE (from inside)','QUAL','FILE'
foreach ($f in $files) {
    $t = ''
    try { $t = Get-DocxText $f.FullName } catch { "  could not read $($f.Name): $($_.Exception.Message)"; continue }

    $inst = @()
    if ($t -match 'Meridian Vocational College')      { $inst += 'Meridian Vocational College' }
    if ($t -match 'Adelaide Culinary Institute')      { $inst += 'Adelaide Culinary Institute' }
    if ($t -match 'Adelaide Construction Institute')  { $inst += 'Adelaide Construction Institute' }
    if ($t -match '45039') { $inst += 'RTO 45039' }
    if ($t -match '45797') { $inst += 'RTO 45797' }
    $instStr = if ($inst.Count) { ($inst | Select-Object -Unique) -join ' / ' } else { 'not stated in first pages' }

    $qual = ''
    foreach ($c in 'CPC20220','CPC31020','CPC40120','CPC50220','MSF30322','SIT20421','SIT30821','SIT31021','SIT40521','SIT50422','SITSS00069','SIT60322','BSB50420','BSB60420','BSB80120') {
        if ($t -match $c) { $qual = $c; break }
    }

    "{0,-5} {1,-34} {2,-12} {3}" -f $f.LastWriteTime.ToString('HH:mm'), $instStr, $qual, $f.Name
}
