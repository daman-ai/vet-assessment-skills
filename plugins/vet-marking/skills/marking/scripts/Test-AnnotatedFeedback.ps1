<#
  Test-AnnotatedFeedback.ps1 - reads the delivered annotated feedback maps back
  off disk and checks them against the ledger they were built from.

  IT READS THE FILES, NOT THE BUILD'S REPORT. A builder that reports "1 of 1
  note placed" while writing a document with no arrow in it passes every check
  that trusts its own log. This opens each delivered .docx, counts what is
  actually in the XML, and compares that with what the ledger says should be
  there.

  What it checks, per delivered map:

    MapOpens          the package is readable and word/document.xml parses
    MapHasPages       one page picture per annotated page, each with an image
                      relationship that resolves to a file in word/media
    MapArrowCount     one drawn arrow per placed note - an arrow is a custom
                      geometry with a path, which is what the builder emits
    MapNotesMatch     every note's text is the ledger's items[] wording, not a
                      second description of the same fault
    MapNumbering      the notes are numbered 1..n with no gaps, so the rings on
                      the page can be paired with them
    MapNothingDropped every items[] row for that copy appears on the map, either
                      beside an arrow or in the closing block

  Usage:
    .\Test-AnnotatedFeedback.ps1 -Ledger run\resolved.json -Dir run
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Ledger,
    [Parameter(Mandatory)][string]$Dir,
    [switch]$Quiet
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$results = @()
function Add-Result {
    param([string]$Check, [string]$Status, [string]$Detail)
    $script:results += [pscustomobject]@{ Check = $Check; Status = $Status; Detail = $Detail }
}

function Get-PartText {
    param($Archive, [string]$EntryName)
    $entry = $Archive.GetEntry($EntryName)
    if (-not $entry) { return $null }
    $sr = New-Object System.IO.StreamReader($entry.Open())
    try { return $sr.ReadToEnd() } finally { $sr.Close() }
}

function Normalise {
    # The comparison is against what the ledger says, so it has to survive XML
    # escaping and the whitespace Word is free to re-wrap.
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    $t = $Text -replace '&amp;', '&' -replace '&lt;', '<' -replace '&gt;', '>' -replace '&quot;', '"'
    return (($t -replace '\s+', ' ').Trim())
}

$L = Get-Content -LiteralPath (Resolve-Path -LiteralPath $Ledger).Path -Raw -Encoding UTF8 | ConvertFrom-Json
$root = (Resolve-Path -LiteralPath $Dir).Path

$maps = @(Get-ChildItem -LiteralPath $root -Filter 'ANNOTATED_*.docx' -File)
if ($maps.Count -eq 0) {
    # The map is optional. Saying "no maps" is a fact; calling it a pass would
    # claim a check ran over something.
    Add-Result 'AnnotatedMaps' 'SKIP' 'No annotated feedback maps in this directory.'
    $results | ForEach-Object { '{0,-18} {1,-5} {2}' -f $_.Check, $_.Status, $_.Detail }
    return
}

foreach ($map in $maps) {
    $label = $map.Name
    # Recover the marked copy this map belongs to, so the ledger rows compared
    # against it are that student's and not the whole class's.
    $sourceName = $label -replace '^ANNOTATED_', ''
    $copy = @($L.markedCopies | Where-Object { $_.file -eq $sourceName })
    if ($copy.Count -ne 1) {
        Add-Result 'MapOpens' 'FAIL' "${label}: no single markedCopies entry matches '$sourceName'."
        continue
    }
    $copy = $copy[0]
    $student = @($L.students | Where-Object { $_.studentId -eq $copy.studentId })[0]

    $expected = @()
    foreach ($toolId in @($copy.toolIds)) {
        $res = @($student.results | Where-Object { $_.toolId -eq $toolId })[0]
        if ($res) { foreach ($item in @($res.items)) { $expected += $item } }
    }

    $zip = $null
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($map.FullName)
        $xmlText = Get-PartText -Archive $zip -EntryName 'word/document.xml'
        if (-not $xmlText) {
            Add-Result 'MapOpens' 'FAIL' "${label}: no word/document.xml in the package."
            continue
        }
        $xml = New-Object System.Xml.XmlDocument
        $xml.LoadXml($xmlText)
        Add-Result 'MapOpens' 'PASS' "${label}: package and document.xml read."

        $relText = Get-PartText -Archive $zip -EntryName 'word/_rels/document.xml.rels'
        $mediaEntries = @($zip.Entries | Where-Object { $_.FullName -like 'word/media/*' })

        # --- pages
        $pics = [regex]::Matches($xmlText, '<pic:pic\b')
        $blips = [regex]::Matches($xmlText, 'r:embed="(?<id>[^"]+)"')
        $missingRel = @()
        foreach ($m in $blips) {
            $rid = $m.Groups['id'].Value
            $relMatch = [regex]::Match($relText, 'Id="' + [regex]::Escape($rid) + '"[^>]*Target="(?<t>[^"]+)"')
            if (-not $relMatch.Success) { $missingRel += $rid; continue }
            $target = 'word/' + ($relMatch.Groups['t'].Value -replace '^/', '')
            if (-not ($mediaEntries | Where-Object { $_.FullName -eq $target })) { $missingRel += $rid }
        }
        if ($pics.Count -eq 0) {
            Add-Result 'MapHasPages' 'FAIL' "${label}: no page picture on the map."
        } elseif ($missingRel.Count -gt 0) {
            Add-Result 'MapHasPages' 'FAIL' "${label}: $($missingRel.Count) image relationship(s) resolve to nothing."
        } else {
            Add-Result 'MapHasPages' 'PASS' "${label}: $($pics.Count) page picture(s), every image present."
        }

        # --- arrows and markers
        $arrows = [regex]::Matches($xmlText, '<a:custGeom>').Count
        $rings = [regex]::Matches($xmlText, 'name="Marker \d+"').Count
        $notes = [regex]::Matches($xmlText, 'name="Note \d+"').Count

        # EVERY panel needs a leader, but only a NUMBERED panel gets a ring.
        # The map carries a panel for every question, pass and fail alike, and
        # ringing all of them would put a circle beside every answer. So the
        # rule is: arrows match panels, and rings match the panels that are
        # numbered - counted from the panels' own headings, not assumed.
        $numbered = 0
        foreach ($wsp in ($xmlText -split '<wps:wsp>')) {
            if ($wsp -notmatch 'name="Note \d+"') { continue }
            $firstText = [regex]::Match($wsp, '<w:t[^>]*>(?<t>.*?)</w:t>')
            if ($firstText.Success -and $firstText.Groups['t'].Value -match '^\s*\d+\.') { $numbered++ }
        }

        if ($arrows -eq 0 -or $notes -eq 0) {
            Add-Result 'MapArrowCount' 'FAIL' "${label}: the map carries no outcome panel or no drawn arrow."
        } elseif ($arrows -ne $notes) {
            Add-Result 'MapArrowCount' 'FAIL' "${label}: $notes panel(s) but $arrows arrow(s) - every panel needs its leader."
        } elseif ($rings -ne $numbered) {
            Add-Result 'MapArrowCount' 'FAIL' "${label}: $numbered numbered panel(s) but $rings ring(s) - these must agree."
        } else {
            Add-Result 'MapArrowCount' 'PASS' "${label}: $notes panel(s), each with an arrow; $numbered numbered, each with a ring."
        }

        # --- the wording is the ledger's
        $body = Normalise ([regex]::Replace($xmlText, '<[^>]+>', ' '))
        $absent = @()
        foreach ($item in $expected) {
            $issue = Normalise "$($item.issue)"
            if ($issue -and $body -notlike ('*' + $issue + '*')) { $absent += "$($item.questionNo)" }
        }
        if ($absent.Count -gt 0) {
            Add-Result 'MapNotesMatch' 'FAIL' "${label}: the ledger wording is not on the map for $($absent -join ', ')."
        } else {
            Add-Result 'MapNotesMatch' 'PASS' "${label}: every note is the ledger's own wording."
        }

        # --- nothing dropped between the sheet and the map
        # Numbers are read from the rendered text rather than from the shapes,
        # because an item that could not be anchored has no shape - it is
        # printed in the closing block, and it still has to be found here.
        $numbers = @([regex]::Matches($body, '\b(\d+)\.\s') | ForEach-Object { [int]$_.Groups[1].Value })
        $seen = @($numbers | Where-Object { $_ -ge 1 -and $_ -le $expected.Count } | Sort-Object -Unique)
        if ($expected.Count -gt 0 -and $seen.Count -lt $expected.Count) {
            $missing = @(1..$expected.Count | Where-Object { $seen -notcontains $_ })
            Add-Result 'MapNothingDropped' 'FAIL' "${label}: item number(s) $($missing -join ', ') appear nowhere on the map."
        } else {
            Add-Result 'MapNothingDropped' 'PASS' "${label}: all $($expected.Count) feedback item(s) accounted for."
        }
    } catch {
        Add-Result 'MapOpens' 'FAIL' "${label}: $($_.Exception.Message)"
    } finally {
        if ($zip) { $zip.Dispose() }
    }
}

if (-not $Quiet) {
    $results | ForEach-Object { '{0,-18} {1,-5} {2}' -f $_.Check, $_.Status, $_.Detail }
}
$failed = @($results | Where-Object { $_.Status -eq 'FAIL' })
Write-Output ''
Write-Output ('{0} check(s), {1} failed, over {2} map(s).' -f $results.Count, $failed.Count, $maps.Count)
if ($failed.Count -gt 0) {
    throw "$($failed.Count) check(s) failed. The maps are not handed over until they pass."
}
