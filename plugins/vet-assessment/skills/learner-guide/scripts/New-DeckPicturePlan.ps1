#requires -Version 5.1
<#
    New-DeckPicturePlan.ps1

    Decides, for every slide in the rendered deck, whether it carries a guide
    photograph, a scene illustration, or nothing - and writes that decision to
    picture-plan.json for the two stages that need it:

      New-DeckDoodles  reads it to know WHICH slides need a subject authored
      Restyle-Deck     reads it to know what to place where

    WHY THIS IS ITS OWN STEP

    Whether a slide can hold a picture at all depends on how many cards the
    renderer put on it, and that is only knowable by reading the slide XML.
    Deciding from deckplan.json alone assigns photographs to slides that turn
    out to be full, and the restyle then drops them silently - eleven of
    twenty-two on the reference build, with nothing reported. Counting the
    cards first is the only way the promise "every photograph is used exactly
    once, and every one is used" can actually hold.

    THE RULE

      - A slide with two or more cards takes nothing. The cards fill it.
      - Slides whose LAYOUT declares takesPicture=false in
        assets\deck-layouts.mvc.json take nothing. That set is derived from the
        map and printed with its size; it is not typed into this script.
      - Every guide photograph is used EXACTLY ONCE and every one is used.
        First choice is a card-free slide of the section the guide drew that
        photograph for, so the picture teaches its own material; anything left
        over goes to a card-free slide of the same topic, then to any card-free
        slide at all, so none is wasted.
      - Every other card-free slide gets a scene illustration.

    ASCII only in this file.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $Deck,        # the deck Invoke-Render wrote
    [Parameter(Mandatory = $true)][string] $PlanJson,    # deckplan.json
    [Parameter(Mandatory = $true)][string] $Out,         # picture-plan.json
    [string] $GuideImgDir                                # build\images (photos + manifest)
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$NS = @{
    p = 'http://schemas.openxmlformats.org/presentationml/2006/main'
    a = 'http://schemas.openxmlformats.org/drawingml/2006/main'
}
$SLIDE_W = 12192000

$plan = @()
$plan += (Get-Content -LiteralPath $PlanJson -Raw -Encoding UTF8 | ConvertFrom-Json)
if ($plan.Count -lt 2) { throw "$PlanJson did not load as a list" }

# ---------------------------------------------------------------------------
#  How many cards each slide carries - the same test the restyle uses, so the
#  two cannot disagree about what "full" means.
# ---------------------------------------------------------------------------
$work = Join-Path ([System.IO.Path]::GetTempPath()) ('picplan_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
[System.IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path $Deck).Path, $work)
try {
    $cards = @{}
    $files = @(Get-ChildItem (Join-Path $work 'ppt\slides') -Filter 'slide*.xml' |
               Sort-Object { [int]([regex]::Match($_.BaseName, '\d+').Value) })
    for ($i = 0; $i -lt $files.Count; $i++) {
        [xml]$x = [System.IO.File]::ReadAllText($files[$i].FullName)
        $m = New-Object System.Xml.XmlNamespaceManager($x.NameTable)
        foreach ($k in $NS.Keys) { $m.AddNamespace($k, $NS[$k]) }
        $n = 0
        foreach ($sp in $x.SelectNodes('//p:spTree/p:sp', $m)) {
            if (-not $sp.SelectSingleNode('./p:spPr/a:solidFill', $m)) { continue }
            $t = @($sp.SelectNodes('.//a:t', $m) | ForEach-Object { $_.InnerText }) -join ''
            if ($t.Trim() -ne '') { continue }              # holds words: not a bare card
            $e = $sp.SelectSingleNode('.//a:ext', $m)
            if (-not $e) { continue }
            $cx = [int64]$e.GetAttribute('cx'); $cy = [int64]$e.GetAttribute('cy')
            if ($cy -le 200000 -or $cx -le 400000 -or $cx -ge ($SLIDE_W - 1)) { continue }  # stripes and bars
            if ($cx -lt 1100000) { continue }               # too small to be a card
            $n++
        }
        $cards[$i + 1] = $n
    }
} finally { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }

# ---------------------------------------------------------------------------
#  Which photograph belongs to which guide section
# ---------------------------------------------------------------------------
$photoOfSection = @{}
$allPhotos = @()
if ($GuideImgDir -and (Test-Path -LiteralPath $GuideImgDir)) {
    $sectionOfId = @{}
    $mf = Join-Path $GuideImgDir 'manifest.json'
    if (Test-Path -LiteralPath $mf) {
        $mj = Get-Content -LiteralPath $mf -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($ph in $mj.placeholders) {
            if ([string]$ph.kind -ne 'illustration') { continue }
            $sec = [regex]::Match([string]$ph.caption, 'Figure\s+(\d+\.\d+)').Groups[1].Value
            if ($sec) { $sectionOfId[[string]$ph.id] = $sec }
        }
    }
    # The manifest numbers every placeholder, diagrams included, while only the
    # illustrations were rendered to disk - and renumbered from 001 as they
    # were. Walk both in order and pair them off; the ids do NOT line up.
    $files = @(Get-ChildItem $GuideImgDir -Filter 'IMG-*.jpg' -ErrorAction SilentlyContinue |
               Sort-Object Name | ForEach-Object { ($_.BaseName -split '_')[0] })
    $ids = @($sectionOfId.Keys | Sort-Object)
    for ($i = 0; $i -lt $files.Count; $i++) {
        $sec = if ($i -lt $ids.Count) { $sectionOfId[$ids[$i]] } else { '' }
        $allPhotos += [pscustomobject]@{ File = $files[$i]; Section = $sec }
        if (-not $sec) { continue }
        if (-not $photoOfSection.ContainsKey($sec)) { $photoOfSection[$sec] = New-Object System.Collections.Queue }
        [void]$photoOfSection[$sec].Enqueue($files[$i])
    }
}

# ---------------------------------------------------------------------------
#  Which layouts take no picture - DERIVED from the layout map, not typed here
#
#  These four names used to be an array literal in this file, which made this
#  script a SECOND source of truth about the template: a layout renamed or
#  added in deck-layouts.mvc.json would keep matching nothing here, and the
#  plan would quietly hand a photograph to a slide that is already full. The
#  map now declares takesPicture beside each layout and the set is read from
#  it, with its size and its source printed.
# ---------------------------------------------------------------------------
$layoutsPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\deck-layouts.mvc.json'
if (-not (Test-Path -LiteralPath $layoutsPath)) {
    throw ("CHECK-SET EMPTY: {0} is not there, so which layouts take no picture cannot be derived. Refusing rather than treating every slide as picture-capable." -f $layoutsPath)
}
$layoutMap = Get-Content -LiteralPath $layoutsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$noPicture = @()
$layoutsSeen = 0
foreach ($lp in $layoutMap.layouts.PSObject.Properties) {
    $layoutsSeen++
    #  A layout that does not declare the field is picture-capable, which is
    #  what every layout without it meant before this field existed.
    if (@($lp.Value.PSObject.Properties.Name) -notcontains 'takesPicture') { continue }
    if (-not [bool]$lp.Value.takesPicture) { $noPicture += [string]$lp.Name }
}
if ($noPicture.Count -eq 0) {
    throw ("CHECK-SET EMPTY: {0} declares {1} layout(s) and not one of them sets takesPicture=false. Refusing rather than planning a picture onto the agenda, the table and the figure wells." -f $layoutsPath, $layoutsSeen)
}
Write-Host ("picture policy: {0} of {1} layout(s) take no picture ({2}), derived from {3}" -f $noPicture.Count, $layoutsSeen, ($noPicture -join ', '), $layoutsPath)

# ---------------------------------------------------------------------------
#  Slides that can hold a picture, in deck order
# ---------------------------------------------------------------------------
$open = @()
for ($q = 1; $q -le $plan.Count; $q++) {
    $kind = [string]$plan[$q - 1].Kind
    if ($noPicture -contains $kind) { continue }
    if (($cards[$q]) -ge 2) { continue }
    $open += [pscustomobject]@{
        Slide   = $q
        Kind    = $kind
        Topic   = [string]$plan[$q - 1].Topic
        Section = [regex]::Match([string]$plan[$q - 1].Tag, '^(\d+\.\d+)').Groups[1].Value
    }
}

$assigned = @{}
$used     = @{}

# 1. a section's photographs to that section's own open slides
foreach ($e in $open) {
    if (-not $e.Section -or -not $photoOfSection.ContainsKey($e.Section)) { continue }
    if ($photoOfSection[$e.Section].Count -eq 0) { continue }
    $pick = [string]$photoOfSection[$e.Section].Dequeue()
    $assigned[$e.Slide] = $pick; $used[$pick] = $true
}
# 2. leftovers to an open slide of the same topic, then to any open slide, so
#    every photograph is used
foreach ($pass in 1, 2) {
    foreach ($p in $allPhotos) {
        if ($used.ContainsKey($p.File) -or -not $p.Section) { continue }
        $topic = $p.Section.Substring(0, 1)
        foreach ($e in $open) {
            if ($assigned.ContainsKey($e.Slide)) { continue }
            if ($pass -eq 1 -and $e.Topic -ne $topic) { continue }
            $assigned[$e.Slide] = $p.File; $used[$p.File] = $true
            break
        }
    }
}

$rows = @()
foreach ($e in $open) {
    if ($assigned.ContainsKey($e.Slide)) {
        $rows += [pscustomobject]@{ slide = $e.Slide; kind = 'photo'; file = $assigned[$e.Slide]; section = $e.Section }
    } else {
        $rows += [pscustomobject]@{ slide = $e.Slide; kind = 'doodle'; file = ''; section = $e.Section }
    }
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Out) | Out-Null
$rows | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $Out -Encoding UTF8

$nPhoto  = @($rows | Where-Object { $_.kind -eq 'photo' }).Count
$nDoodle = @($rows | Where-Object { $_.kind -eq 'doodle' }).Count
$unused  = @($allPhotos | Where-Object { -not $used.ContainsKey($_.File) })
Write-Host ("slides that can hold a picture: {0} of {1}" -f $open.Count, $plan.Count)
Write-Host ("photographs placed: {0} of {1}" -f $nPhoto, $allPhotos.Count)
Write-Host ("illustrations to author: {0}" -f $nDoodle)
Write-Host ("wrote {0}" -f $Out)
if ($unused.Count -gt 0) {
    # Every guide photograph is meant to appear. One left over means the deck
    # has fewer open slides than the guide has figures - say so rather than
    # dropping it quietly.
    Write-Warning ("{0} photograph(s) had nowhere to go: {1}" -f $unused.Count, (($unused | ForEach-Object { $_.File }) -join ', '))
}
