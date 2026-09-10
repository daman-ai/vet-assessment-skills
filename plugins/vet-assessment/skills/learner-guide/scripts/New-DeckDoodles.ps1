#requires -Version 5.1
<#
    New-DeckDoodles.ps1

    The scene illustrations that stand beside the copy on every deck slide that
    carries no guide photograph. One per slide, drawn to what THAT slide teaches.

    Why generated rather than sourced. The template's own elements are scenes -
    a person doing something - not single objects, and an icon set in the right
    style still says nothing about the slide it sits on. No stock library has a
    drawing of "four sauces competing for two burners", so matching the taught
    content and downloading from a library are mutually exclusive. The house
    style below is the template's own, so the generated set sits with it.

    SUBJECTS ARE DATA, not code. The caller writes a doodles.json - one entry
    per slide, each naming what that slide teaches - and this script draws it.
    Authoring those subjects is the judgement step and belongs to the content
    stage, which has read the spine; see references/deck-style.md for the shape
    of the file and how to write a subject that earns its place.

    The API key resolves from -ApiKey, $env:OPENAI_API_KEY, then
    %USERPROFILE%\.openai-key. It is never written to disk by this script.

    ASCII only in this file.
#>

[CmdletBinding()]
param(
    # [{ "slide": 21, "id": "process-fails", "subject": "Four shallow trays..." }]
    [Parameter(Mandatory = $true)][string] $SubjectsPath,
    [Parameter(Mandatory = $true)][string] $OutDir,

    # picture-plan.json. Given it, this script CHECKS that a subject exists for
    # every slide the plan says needs an illustration, and refuses otherwise.
    # Subjects authored against a hand-picked list instead of the published plan
    # come out one slide off, and the restyle then places nothing on the slides
    # that were missed - silently, because a slide with no picture is legal.
    [string] $PicturePlan,
    [string]   $ApiKey,
    [int[]]    $Only,
    [switch]   $Force,
    [switch]   $DryRun
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

function Resolve-Key {
    if ($ApiKey) { return $ApiKey }
    if ($env:OPENAI_API_KEY) { return $env:OPENAI_API_KEY }
    $f = Join-Path $env:USERPROFILE '.openai-key'
    if (Test-Path -LiteralPath $f) { return (Get-Content -LiteralPath $f -Raw).Trim() }
    throw 'No OpenAI API key found. Set $env:OPENAI_API_KEY or pass -ApiKey.'
}

# ---------------------------------------------------------------------------
#  The template's house style, verbatim on every prompt so the set reads as one
#  hand. The colours are the template's own, off its Resource Page.
# ---------------------------------------------------------------------------
$STYLE = @'
A single sticker-style cut-out illustration, floating alone on a completely
empty transparent background.

CUT-OUT, NOT A SCENE WITH A SETTING. Draw only the people and objects named in
the subject. Draw NOTHING else: no room, no wall, no floor, no ceiling, no
background panel, no ground line, no shadow, no frame, no border. Everything
that is not the named subject must be fully transparent. Leave an empty margin
of at least ten per cent on all four sides: no part of the drawing may touch or
run off any edge of the canvas.

STYLE. Flat vector illustration in a friendly modern hand-drawn style. Thick,
even, slightly wobbly black outlines on every shape, as if drawn with a brush
pen. Completely flat fills - no gradients, no shading, no highlights, no drop
shadows, no texture, no 3D, no photorealism.

COLOUR. Use only these flat colours, and nothing else:
  cornflower blue  #C3DBFD
  blush pink       #FACAD3
  warm orange      #FA984C
  soft green       #C4D682
  butter yellow    #F6EBA5
  cream            #FFFCEB
plus black #000000 for outlines and a light peach for skin.
Work clothing is cream #FFFCEB. Do NOT use brown, olive, khaki, taupe, beige,
grey, gold, navy or any muted or earthy colour anywhere.

PEOPLE. Simple and stylised, with small dot eyes and a friendly closed smile.
Simple, correctly formed hands. Show the whole figure or the figure from the
shoulders down; never a floating head.

NO TYPOGRAPHY. Absolutely no text, letters, numbers, words, labels, signage,
logos or watermarks anywhere in the image. Where a document, list or form
appears, show its lines as plain flat rules with no readable characters.
'@

$Scenes = @()
$Scenes += (Get-Content -LiteralPath $SubjectsPath -Raw -Encoding UTF8 | ConvertFrom-Json)
if ($Scenes.Count -lt 1) { throw "$SubjectsPath did not load as a list of subjects" }
foreach ($s in $Scenes) {
    if (-not $s.slide -or -not $s.id -or -not $s.subject) {
        throw "every subject needs slide, id and subject: $($s | ConvertTo-Json -Compress)"
    }
}
if ($PicturePlan) {
    $pp = @()
    $pp += (Get-Content -LiteralPath $PicturePlan -Raw -Encoding UTF8 | ConvertFrom-Json)
    $want = @($pp | Where-Object { [string]$_.kind -eq 'doodle' } | ForEach-Object { [int]$_.slide })
    $have = @($Scenes | ForEach-Object { [int]$_.slide })
    $missing = @($want | Where-Object { $have -notcontains $_ })
    $spare   = @($have | Where-Object { $want -notcontains $_ })
    if ($missing.Count -gt 0) {
        throw ("{0} needs a subject for slide(s) {1}, which picture-plan.json says take an illustration. Author them before generating." -f
               (Split-Path $SubjectsPath -Leaf), ($missing -join ', '))
    }
    if ($spare.Count -gt 0) {
        Write-Warning ("subject(s) for slide(s) {0} are not needed - the plan gives those slides a photograph or no picture" -f ($spare -join ', '))
    }
    Write-Host ("subjects cover all {0} slide(s) the plan asks for" -f $want.Count)
}

if ($Only) { $Scenes = @($Scenes | Where-Object { $Only -contains [int]$_.slide }) }

$key = if ($DryRun) { 'dry-run' } else { Resolve-Key }
$made = 0; $skipped = 0; $failed = @()

foreach ($s in $Scenes) {
    # The slide number lives in the file name: that is how Restyle-Deck puts the
    # drawing on the slide it was drawn for rather than handing them out in order.
    $name = 'DOODLE-{0:D2}-{1}' -f [int]$s.slide, $s.id
    $dest = Join-Path $OutDir ($name + '.png')
    if ((Test-Path $dest) -and -not $Force) { Write-Host ("SKIP  {0}" -f $name); $skipped++; continue }

    $prompt = ($STYLE.Trim() + "`n`nSubject:`n" + [string]$s.subject).Trim()
    if ($DryRun) { Write-Host ("DRY   {0}  ({1} chars)" -f $name, $prompt.Length); continue }

    $body = @{
        model         = 'gpt-image-1'
        prompt        = $prompt
        size          = '1024x1024'
        quality       = 'medium'
        n             = 1
        output_format = 'png'
        background    = 'transparent'
    } | ConvertTo-Json -Depth 4 -Compress

    $ok = $false
    for ($try = 1; $try -le 3 -and -not $ok; $try++) {
        #  Stamped BEFORE the attempt so the catch can tell a file THIS attempt
        #  wrote from one left behind by an earlier run under -Force.
        $attemptStart = (Get-Date).ToUniversalTime().AddSeconds(-2)
        try {
            $resp = Invoke-RestMethod -Method Post -Uri 'https://api.openai.com/v1/images/generations' `
                        -Headers @{ Authorization = "Bearer $key" } -ContentType 'application/json' `
                        -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 300
            $b64 = $resp.data[0].b64_json
            if (-not $b64) { throw 'response carried no b64_json' }
            [System.IO.File]::WriteAllBytes($dest, [Convert]::FromBase64String($b64))
            Write-Host ("OK    {0}  ({1:N0} KB)" -f $name, ((Get-Item $dest).Length / 1KB))
            $made++; $ok = $true
        } catch {
            $msg = $_.Exception.Message
            #  ASK THE FILESYSTEM BEFORE BELIEVING THE THROW. The bytes are
            #  written before anything else in the try block, so a throw raised
            #  after that line - the Get-Item, the console write, a transport
            #  object dying on its way out - says nothing about the drawing. The
            #  recorded incident is the same shape: Word finished a 383-page PDF
            #  and then died at COM teardown, and the caller reported FAILED over
            #  a correct file sitting on disk. So the verdict comes from the
            #  file: it must exist, carry bytes, have been written by THIS
            #  attempt, and be a well-formed PNG (signature and closing IEND
            #  chunk). The exception is reported beside it, never instead of it.
            $landedBytes = 0
            $landed = $false
            if (Test-Path -LiteralPath $dest) {
                $fi = Get-Item -LiteralPath $dest -ErrorAction SilentlyContinue
                if ($null -ne $fi -and $fi.Length -gt 67 -and $fi.LastWriteTimeUtc -ge $attemptStart) {
                    $raw = $null
                    try { $raw = [System.IO.File]::ReadAllBytes($dest) } catch { $raw = $null }
                    if ($null -ne $raw -and $raw.Length -gt 67 -and
                        $raw[0] -eq 137 -and $raw[1] -eq 80 -and $raw[2] -eq 78 -and $raw[3] -eq 71 -and
                        $raw[4] -eq 13 -and $raw[5] -eq 10 -and $raw[6] -eq 26 -and $raw[7] -eq 10 -and
                        [System.Text.Encoding]::ASCII.GetString($raw, $raw.Length - 8, 8).Contains('IEND')) {
                        $landed = $true
                        $landedBytes = $raw.Length
                    }
                }
            }
            if ($landed) {
                Write-Warning ("{0} threw AFTER the drawing landed - {1}" -f $name, $msg)
                Write-Host ("OK    {0}  ({1:N0} KB, read back from disk)" -f $name, ($landedBytes / 1KB))
                $made++; $ok = $true
                continue
            }
            if ($msg -match '\b(400|401|403)\b') { Write-Warning ("FAIL  {0} - {1}" -f $name, $msg); break }
            if ($try -lt 3) { Start-Sleep -Seconds (5 * $try) } else { Write-Warning ("FAIL  {0} - {1}" -f $name, $msg) }
        }
    }
    if (-not $ok -and -not $DryRun) { $failed += $name }
}

Write-Host ''
Write-Host ("generated {0}, skipped {1}, failed {2}" -f $made, $skipped, $failed.Count)
if ($failed.Count -gt 0) {
    Write-Host ("failed: {0}" -f ($failed -join ', ')) -ForegroundColor Yellow
    exit 1
}
