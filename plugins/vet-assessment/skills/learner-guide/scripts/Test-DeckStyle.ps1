#requires -Version 5.1
<#
    Test-DeckStyle.ps1

    Checks the restyled deck against the deck Invoke-Render wrote. The restyle
    redraws every container and changes z-order, so text is compared as a sorted
    multiset of runs per shape rather than in document order: that still catches
    a run dropped, duplicated or altered, without failing merely because a title
    now sits above its card instead of below it.

    This is the gate that makes the restyle safe to run on audited content. It
    must never be relaxed to make a build pass - if it fails, the restyle is
    wrong, not the check.
#>

[CmdletBinding()]
param(
    [string] $Source,
    [string] $Sample,
    # 0 = expect the same slide count as the SOURCE deck, which is the delivered
    # case; a number checks only that many, for a short review sample. Defaulting
    # this from the sample instead compared the sample against itself, so a
    # restyle that dropped the last slide passed cleanly and the dropped slide's
    # text, notes and typefaces were never compared either.
    [int] $Slides = 0,
    # The faces Restyle-Deck.ps1 sets. Anything else on a slide is a shape the
    # restyle missed, still carrying the rendered deck's typography.
    [string[]] $Faces = @('Sawarabi Mincho', 'Questrial'),
    # Lines the restyle was authorised to delete, matched whole and trimmed, and
    # exactly what was passed to its -DropCoverLines. They are stripped from the
    # SOURCE side before comparing, so the comparison stays exact - measured
    # against what was authorised rather than switched off. Anything else lost,
    # added or altered still fails.
    [string[]] $AllowRemoved = @(),
    # EMU of slack allowed at each slide edge before a shape is failed as
    # hanging off. 0 = the rule as the deck format states it. Raise it only with
    # a written reason, never to make a build pass.
    [int64] $EdgeTolerance = 0,
    [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.IO.Compression.FileSystem

$NS = @{
    p = 'http://schemas.openxmlformats.org/presentationml/2006/main'
    a = 'http://schemas.openxmlformats.org/drawingml/2006/main'
    r = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
}

function Expand ([string] $Path) {
    $d = Join-Path ([System.IO.Path]::GetTempPath()) ('fg_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    [System.IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path $Path).Path, $d)
    return $d
}

function Get-Runs ([string] $File) {
    <#  Compares at SHAPE level, not run level.

        Setting one typeface and one colour across a footer makes its runs
        identical, and PowerPoint then merges them on save: five runs reading
        "Meridian Vocational College", "   .   ", "RTO 45039" and so on become
        one. Not a character changes, but a run-level comparison reports the
        five as lost and the one as added, on every slide. Concatenating each
        shape's runs compares what a reader actually sees.  #>
    [xml]$d = [System.IO.File]::ReadAllText($File)
    $m = New-Object System.Xml.XmlNamespaceManager($d.NameTable)
    foreach ($k in $NS.Keys) { $m.AddNamespace($k, $NS[$k]) }
    $out = @()
    foreach ($holder in $d.SelectNodes('//p:sp | //p:graphicFrame', $m)) {
        $paras = @()
        foreach ($p in $holder.SelectNodes('.//a:p', $m)) {
            $runs = @()
            foreach ($t in $p.SelectNodes('.//a:t', $m)) { $runs += $t.InnerText }
            $line = ($runs -join '')
            if ($line.Trim() -ne '') { $paras += $line }
        }
        if ($paras.Count -gt 0) { $out += ($paras -join "`n") }
    }
    return ($out | Sort-Object)
}

function Remove-Declared ([string[]] $Entries, [string[]] $Drop) {
    <#  Applies the authorised deletions to the source side. A shape that loses
        one of its paragraphs keeps its remaining ones; a shape that loses all
        of them drops out entirely.  #>
    if (-not $Drop -or $Drop.Count -eq 0) { return $Entries }
    $out = @()
    foreach ($e in $Entries) {
        $lines = @($e -split "`n" | Where-Object { $Drop -notcontains $_.Trim() })
        if ($lines.Count -gt 0) { $out += ($lines -join "`n") }
    }
    return @($out | Sort-Object)
}

function Get-Slides ([string] $Root, [string] $Sub) {
    $dir = Join-Path $Root $Sub
    if (-not (Test-Path $dir)) { return @() }
    return @(Get-ChildItem $dir -Filter '*.xml' |
             Sort-Object { [int]([regex]::Match($_.BaseName, '\d+').Value) })
}

# ---------------------------------------------------------------------------
# Self-test - PLANT the defect before you believe the pass
#
# No Office, no template. Builds minimal .pptx packages in temp and re-invokes
# this script against them, so every rule it claims is shown to FAIL on a
# seeded defect. A gate whose clean result nobody has seen turn red is a gate
# nobody has checked: the slide-count rule compared the sample with itself, and
# nothing in this skill could tell.
# ---------------------------------------------------------------------------

function New-SlidePart {
    <#  One text shape, optionally with a named typeface, a geometry, or a
        table so the graphicFrame arm of the bounds scan has something to see. #>
    param(
        [string] $Text = 'The standard recipe is the recipe of record',
        [string] $Face = 'Questrial',
        [int64] $X = 685800, [int64] $Y = 685800,
        [int64] $CX = 3000000, [int64] $CY = 900000,
        [switch] $AsTable
    )
    $ns = 'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" ' +
          'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" ' +
          'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"'
    $body = '<p:txBody><a:bodyPr/><a:p><a:r><a:rPr lang="en-AU"><a:latin typeface="' + $Face +
            '"/></a:rPr><a:t>' + $Text + '</a:t></a:r></a:p></p:txBody>'
    $xfrm = '<a:off x="' + $X + '" y="' + $Y + '"/><a:ext cx="' + $CX + '" cy="' + $CY + '"/>'
    if ($AsTable) {
        $shape = '<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="9" name="Table 0"/></p:nvGraphicFramePr>' +
                 '<p:xfrm>' + $xfrm + '</p:xfrm><a:graphic><a:graphicData><a:tbl><a:tr><a:tc>' +
                 $body + '</a:tc></a:tr></a:tbl></a:graphicData></a:graphic></p:graphicFrame>'
    }
    else {
        $shape = '<p:sp><p:nvSpPr><p:cNvPr id="2" name="Card 01"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>' +
                 '<p:spPr><a:xfrm>' + $xfrm + '</a:xfrm></p:spPr>' + $body + '</p:sp>'
    }
    return '<?xml version="1.0"?><p:sld ' + $ns + '><p:cSld><p:spTree>' + $shape + '</p:spTree></p:cSld></p:sld>'
}

function New-DeckFixture {
    <#  Writes a .pptx carrying one slide per entry in $SlideXml and one notes
        part per entry in $NotesText. Every slide gets a _rels part, because the
        gate reads one per slide. Entry names are written with forward slashes
        explicitly: on .NET 4.x ZipFile writes the platform separator into the
        name, and every OOXML reader then correctly says the part is missing. #>
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string[]] $SlideXml,
        [string[]] $NotesText = @()
    )
    $emptyRels = '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>'
    $fs = [System.IO.File]::Open($Path, 'Create')
    try {
        $za = New-Object System.IO.Compression.ZipArchive($fs, 'Create')
        try {
            for ($i = 0; $i -lt $SlideXml.Count; $i++) {
                $en = $za.CreateEntry('ppt/slides/slide' + ($i + 1) + '.xml')
                $sw = New-Object System.IO.StreamWriter($en.Open())
                $sw.Write($SlideXml[$i]); $sw.Flush(); $sw.Dispose()

                $en = $za.CreateEntry('ppt/slides/_rels/slide' + ($i + 1) + '.xml.rels')
                $sw = New-Object System.IO.StreamWriter($en.Open())
                $sw.Write($emptyRels); $sw.Flush(); $sw.Dispose()
            }
            for ($i = 0; $i -lt $NotesText.Count; $i++) {
                $en = $za.CreateEntry('ppt/notesSlides/notesSlide' + ($i + 1) + '.xml')
                $sw = New-Object System.IO.StreamWriter($en.Open())
                $sw.Write((New-SlidePart -Text $NotesText[$i])); $sw.Flush(); $sw.Dispose()
            }
        }
        finally { $za.Dispose() }
    }
    finally { $fs.Dispose() }
}

if ($SelfTest) {
    $pass = 0; $bad = 0
    function Ok ($m) { $script:pass++; Write-Host "  PASS  $m" -ForegroundColor Green }
    function No ($m) { $script:bad++;  Write-Host "  FAIL  $m" -ForegroundColor Red }
    Write-Host ''
    Write-Host 'Test-DeckStyle self-test' -ForegroundColor Cyan
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('tds_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $me = $PSCommandPath
    try {
        $baseA = New-SlidePart -Text 'Confirm production requirements'
        $baseB = New-SlidePart -Text 'The standard recipe is the recipe of record'
        $notes = @('PC 1.1 note', 'PC 1.2 note')
        $src   = Join-Path $tmp 'source.pptx'
        New-DeckFixture -Path $src -SlideXml @($baseA, $baseB) -NotesText $notes

        # 1. CONTROL - an unchanged deck passes
        $clean = Join-Path $tmp 'clean.pptx'
        New-DeckFixture -Path $clean -SlideXml @($baseA, $baseB) -NotesText $notes
        $o = & $me -Source $src -Sample $clean 6>&1 2>&1; $c = $LASTEXITCODE
        if ($c -eq 0) { Ok 'CONTROL an unchanged deck passes' } else { No ('control failed: ' + (($o | Out-String -Width 4096).Trim())) }

        # 2. a changed run fails, naming what was lost
        $edit = Join-Path $tmp 'edit.pptx'
        New-DeckFixture -Path $edit -SlideXml @($baseA, (New-SlidePart -Text 'The standard recipe is a guide')) -NotesText $notes
        $o = & $me -Source $src -Sample $edit 6>&1 2>&1; $c = $LASTEXITCODE
        if ($c -eq 1 -and ($o | Out-String -Width 4096) -match 'text lost') { Ok 'a changed text run FAILS, naming what was lost' } else { No ('changed run: exit ' + $c) }

        # 3. a DROPPED SLIDE fails - the rule that used to compare the sample with itself
        $short = Join-Path $tmp 'short.pptx'
        New-DeckFixture -Path $short -SlideXml @($baseA) -NotesText $notes
        $o = & $me -Source $src -Sample $short 6>&1 2>&1; $c = $LASTEXITCODE
        if ($c -eq 1 -and ($o | Out-String -Width 4096) -match 'slides, source has 2') { Ok 'a DROPPED SLIDE fails against the SOURCE count' } else { No ('dropped slide: exit ' + $c) }

        # 4. dropped speaker notes fail rather than shrinking the loop
        $nonotes = Join-Path $tmp 'nonotes.pptx'
        New-DeckFixture -Path $nonotes -SlideXml @($baseA, $baseB) -NotesText @()
        $o = & $me -Source $src -Sample $nonotes 6>&1 2>&1; $c = $LASTEXITCODE
        if ($c -eq 1 -and ($o | Out-String -Width 4096) -match 'speaker notes lost') { Ok 'DROPPED SPEAKER NOTES fail rather than shrinking the loop' } else { No ('dropped notes: exit ' + $c) }

        # 5. a shape off the RIGHT edge fails - and it fails, it does not warn
        $offR = Join-Path $tmp 'offright.pptx'
        New-DeckFixture -Path $offR -SlideXml @($baseA, (New-SlidePart -X 11000000 -CX 3000000)) -NotesText $notes
        $o = & $me -Source $src -Sample $offR 6>&1 2>&1; $c = $LASTEXITCODE
        if ($c -eq 1 -and ($o | Out-String -Width 4096) -match 'runs past the slide edge') { Ok 'a shape off the RIGHT edge FAILS the gate' } else { No ('off right edge: exit ' + $c) }

        # 6. and off the TOP, which a right-and-bottom-only test cannot see
        $offT = Join-Path $tmp 'offtop.pptx'
        New-DeckFixture -Path $offT -SlideXml @($baseA, (New-SlidePart -Y -400000)) -NotesText $notes
        $o = & $me -Source $src -Sample $offT 6>&1 2>&1; $c = $LASTEXITCODE
        if ($c -eq 1 -and ($o | Out-String -Width 4096) -match 'runs past the slide edge') { Ok 'a shape off the TOP edge FAILS' } else { No ('off top edge: exit ' + $c) }

        # 7. a TABLE off the bottom fails - the shape class the scan used to skip
        $srcT = Join-Path $tmp 'source-table.pptx'
        New-DeckFixture -Path $srcT -SlideXml @((New-SlidePart -Text 'Criteria and options' -AsTable)) -NotesText @('table note')
        $offTbl = Join-Path $tmp 'offtable.pptx'
        New-DeckFixture -Path $offTbl -SlideXml @((New-SlidePart -Text 'Criteria and options' -AsTable -Y 6500000 -CY 900000)) -NotesText @('table note')
        $o = & $me -Source $srcT -Sample $offTbl 6>&1 2>&1; $c = $LASTEXITCODE
        if ($c -eq 1 -and ($o | Out-String -Width 4096) -match 'runs past the slide edge') { Ok 'a TABLE off the bottom edge FAILS' } else { No ('off-slide table: exit ' + $c) }

        # 8. a face the restyle does not set fails
        $face = Join-Path $tmp 'face.pptx'
        New-DeckFixture -Path $face -SlideXml @($baseA, (New-SlidePart -Face 'Calibri')) -NotesText $notes
        $o = & $me -Source $src -Sample $face 6>&1 2>&1; $c = $LASTEXITCODE
        if ($c -eq 1 -and ($o | Out-String -Width 4096) -match 'unexpected typeface') { Ok 'a face the restyle does not set FAILS' } else { No ('typeface: exit ' + $c) }

        # 9. -AllowRemoved passes exactly the line it names, and nothing else
        $drop = Join-Path $tmp 'drop.pptx'
        New-DeckFixture -Path $drop -SlideXml @($baseA, (New-SlidePart -Text ' ')) -NotesText $notes
        $o = & $me -Source $src -Sample $drop -AllowRemoved @('The standard recipe is the recipe of record') 6>&1 2>&1
        if ($LASTEXITCODE -eq 0) { Ok '-AllowRemoved passes exactly the line it names' } else { No ('allow-removed: exit ' + $LASTEXITCODE) }
        $o = & $me -Source $src -Sample $drop -AllowRemoved @('some other line') 6>&1 2>&1
        if ($LASTEXITCODE -eq 1) { Ok 'and a deletion nobody authorised still FAILS' } else { No 'allow-removed did not stay exact' }
    }
    finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host ''
    Write-Host ('  {0} passed, {1} failed' -f $pass, $bad) -ForegroundColor $(if ($bad) { 'Red' } else { 'Green' })
    if ($bad) { exit 4 }
    Write-Host 'TEST-DECKSTYLE SELF-TEST OK' -ForegroundColor Green
    exit 0
}

if (-not $Source -or -not $Sample) {
    Write-Host 'Test-DeckStyle: -Source and -Sample are both required (or -SelfTest).' -ForegroundColor Red
    Write-Host '  -Source  the untouched copy of what Invoke-Render wrote' -ForegroundColor DarkGray
    Write-Host '  -Sample  the restyled deck being judged' -ForegroundColor DarkGray
    exit 2
}
#  Named one at a time rather than swept in a loop: a loop over a list is how a
#  refusal quietly runs zero times and stops refusing anything.
if (-not (Test-Path -LiteralPath $Source)) {
    Write-Host ('Test-DeckStyle: -Source not found: {0}' -f $Source) -ForegroundColor Red
    exit 2
}
if (-not (Test-Path -LiteralPath $Sample)) {
    Write-Host ('Test-DeckStyle: -Sample not found: {0}' -f $Sample) -ForegroundColor Red
    exit 2
}

$fail = @(); $warn = @()
$sd = Expand $Source
$od = Expand $Sample

try {
    $src = @(Get-Slides $sd 'ppt\slides')
    $out = @(Get-Slides $od 'ppt\slides')

    # From the SOURCE, not the sample: a count taken from the sample is the
    # sample compared with itself, and can never differ.
    if ($Slides -le 0) { $Slides = $src.Count }
    if ($out.Count -ne $Slides) { $fail += "sample has $($out.Count) slides, source has $Slides" }
    Write-Host ("slides: {0} of {1}" -f $out.Count, $src.Count)
    foreach ($d in $AllowRemoved) { Write-Host ("authorised deletion: '{0}'" -f $d) -ForegroundColor DarkYellow }

    for ($i = 0; $i -lt [math]::Min($Slides, $out.Count); $i++) {
        $n = $i + 1
        $a = Remove-Declared (Get-Runs $src[$i].FullName) $AllowRemoved
        $b = Get-Runs $out[$i].FullName
        if (($a -join "`u{241F}") -ne ($b -join "`u{241F}")) {
            $missing = @($a | Where-Object { $b -notcontains $_ })
            $added   = @($b | Where-Object { $a -notcontains $_ })
            foreach ($mtxt in $missing) {
                $s = $mtxt; if ($s.Length -gt 60) { $s = $s.Substring(0, 60) + '...' }
                $fail += "slide ${n}: text lost - '$s'"
            }
            foreach ($atxt in $added) {
                $s = $atxt; if ($s.Length -gt 60) { $s = $s.Substring(0, 60) + '...' }
                $fail += "slide ${n}: text added - '$s'"
            }
            if ($missing.Count -eq 0 -and $added.Count -eq 0) {
                $warn += "slide ${n}: a run repeats a different number of times"
            }
        }

        # Every face on the slide must be one the build actually sets.
        #
        # This replaces a pair of checks for "Calibri survived" and "Arial
        # survived", which were standing in for "a shape was missed and still
        # carries the source deck's typography". Once the deck itself was set in
        # Arial the second of those became a check that fails the build for
        # doing the thing it was asked to do - and neither ever caught a shape
        # that had been missed while carrying some third face. Naming the faces
        # tests what those two were reaching for, and tests it on every shape.
        $raw = [System.IO.File]::ReadAllText($out[$i].FullName)
        foreach ($mm in [regex]::Matches($raw, '<a:latin[^>]*typeface="([^"]*)"')) {
            $tf = $mm.Groups[1].Value
            if ($tf -eq '' -or $tf.StartsWith('+')) { continue }   # theme reference
            if ($Faces -notcontains $tf) { $fail += "slide ${n}: unexpected typeface '$tf'" }
        }

        # every picture must resolve to a relationship that exists
        [xml]$d = [System.IO.File]::ReadAllText($out[$i].FullName)
        $m = New-Object System.Xml.XmlNamespaceManager($d.NameTable)
        foreach ($k in $NS.Keys) { $m.AddNamespace($k, $NS[$k]) }
        $relF = Join-Path (Join-Path $od 'ppt\slides\_rels') ($out[$i].Name + '.rels')
        [xml]$rr = [System.IO.File]::ReadAllText($relF)
        $ids = @($rr.Relationships.Relationship | ForEach-Object { $_.Id })
        foreach ($blip in $d.SelectNodes('//a:blip', $m)) {
            $id = $blip.GetAttribute('embed', $NS.r)
            if ($id -and ($ids -notcontains $id)) { $fail += "slide ${n}: image relationship $id missing" }
        }

        # Nothing may hang off the slide - and this FAILS, it does not warn.
        # Every other guarantee this gate makes is blocking; an advisory one is
        # a rule nobody has to satisfy, and it sat here while the docs claimed
        # the gate caught an overhang. p:graphicFrame is in the scan because
        # the restyle resizes tables, so a table pushed past the footer was the
        # one shape class the geometry check could not see. All four edges are
        # tested: a shape at negative x or y hangs off the left or the top.
        foreach ($sp in $d.SelectNodes('//p:spTree/p:sp | //p:spTree/p:pic | //p:spTree/p:graphicFrame', $m)) {
            $off = $sp.SelectSingleNode('.//a:off', $m); $ext = $sp.SelectSingleNode('.//a:ext', $m)
            if (-not $off -or -not $ext) { continue }
            $x  = [int64]$off.GetAttribute('x'); $y = [int64]$off.GetAttribute('y')
            $r  = $x + [int64]$ext.GetAttribute('cx')
            $bm = $y + [int64]$ext.GetAttribute('cy')
            if ($bm -gt (6858000 + $EdgeTolerance) -or $r -gt (12192000 + $EdgeTolerance) -or
                $x -lt (-$EdgeTolerance) -or $y -lt (-$EdgeTolerance)) {
                $cn = $sp.SelectSingleNode('.//p:cNvPr', $m)
                $nm = if ($cn) { $cn.GetAttribute('name') } else { '(unnamed)' }
                $fail += "slide ${n}: '$nm' runs past the slide edge"
            }
        }
    }

    $sn = @(Get-Slides $sd 'ppt\notesSlides')
    $on = @(Get-Slides $od 'ppt\notesSlides')
    Write-Host ("notes:  {0} kept of {1}" -f $on.Count, $sn.Count)
    # The disparity this line prints is a FAILURE, not a remark. Bounded by the
    # output's own count instead, a restyle that dropped every notesSlide ran
    # the loop zero times and the deck shipped with no speaker notes at all.
    if ($on.Count -ne $sn.Count) {
        $fail += "notes: $($on.Count) notesSlides kept of $($sn.Count) - speaker notes lost"
    }
    for ($i = 0; $i -lt [math]::Min($sn.Count, $on.Count); $i++) {
        $a = Get-Runs $sn[$i].FullName; $b = Get-Runs $on[$i].FullName
        if (($a -join '|') -ne ($b -join '|')) { $fail += "notes $($on[$i].BaseName): speaker notes changed" }
    }

} finally {
    Remove-Item $sd -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $od -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
foreach ($w in $warn) { Write-Host ("WARN  {0}" -f $w) -ForegroundColor Yellow }
if ($fail.Count -gt 0) {
    foreach ($f in $fail) { Write-Host ("FAIL  {0}" -f $f) -ForegroundColor Red }
    Write-Host ''
    Write-Host ("GATE FAILED - {0} problem(s)" -f $fail.Count) -ForegroundColor Red
    exit 1
}
Write-Host ("GATE PASSED - {0} warning(s)" -f $warn.Count) -ForegroundColor Green
exit 0
