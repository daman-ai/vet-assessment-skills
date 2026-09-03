<#
    Check-Figures.ps1 - the PLACED artwork, checked mechanically, on the
    finished file.

    Implements the placement arm of the gate the design calls
    Assert-FullRegateAfterMutation. Run it at Stage 7c, after placement, as part
    of the COMPLETE gate set - never on its own.

    WHY IT MATTERS THAT THIS RUNS AFTER PLACEMENT AND SO DOES EVERYTHING ELSE.
    Placement is the last mutation of both artefacts and on the pipeline this
    was promoted from it was followed by exactly one of five gates. The figure
    registry's variant-aware sweep therefore never once ran against a document
    that actually contained figure rows. Standing rule: any stage that changes
    what is on the page is followed by the whole gate set, never a subset.

    WHAT IT CHECKS, read-only, straight from the zip:

      - every drawing carries non-empty alt text (docPr/cNvPr descr or title);
        house rule is that everything placed is described
      - CAPTIONS ARE COUNTED PER NUMBER WITH NO DE-DUPLICATION. This is a fix,
        and it is the whole reason this script was rewritten. The version this
        replaces advertised a duplicate-caption failure and then de-duplicated
        the numbers BEFORE comparing them, which made that failure unreachable -
        in a script that was, on top of that, wired to no caller at all. A
        caption that repeats a number breaks every cross-reference to it.
      - a caption is matched on the CAPTION PARAGRAPH, not on any text run, so
        an in-prose cross-reference ("see Figure 2.3.4") cannot count as a
        caption. This house builds captions as a centred italic paragraph rather
        than with a named style, so the discriminator is the paragraph's own
        shape: the number at the START of the paragraph plus caption formatting.
        The discriminator used is printed, so a house that does use a named
        style can point -CaptionStyleRx at it and see that it took effect.
      - figure numbers run 1..N inside each sub-section with no gap
      - CAPTION-TO-SLOT RECONCILIATION against the spine: every planned visual
        slot has exactly one caption in the rendered document, and no caption
        exists for a slot the spine does not plan. The counts come from the
        spine, never from a literal.
      - no artwork prompt text survived placement, in the body or in any header
        or footer

    PS 5.1. ASCII only in this file.
    Exit 1 on any failure, 2 on a usage error.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string[]] $Path,
    #  Supply it and the caption count is reconciled against the planned slots.
    #  Without it the gate still runs, and says so.
    [string] $BuildDir,
    [string] $SpineDir,
    [string] $CaptionPrefix = 'Figure',
    [string] $CaptionStyleRx = '(?i)caption',
    #  The artwork sub-skill's own prompt markers. A prompt that survives
    #  placement is a prompt an auditor reads as content.
    [string[]] $PromptToken = @('[IMAGE', '[DIAGRAM', '[ILLUSTRATION', '[PHOTO', '[FIGURE', '[PICTURE', 'PROMPT:', 'ASPECT:', 'QUALITY:'),
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')
Add-Type -AssemblyName System.IO.Compression.FileSystem

$GATE = 'Check-Figures'
$failures = 0

# ---------------------------------------------------------------------------
# The planned slots, from the spine
# ---------------------------------------------------------------------------

$plannedSlots = @()
if ($BuildDir) {
    $plannedSlots = @(Get-GateSpineVisuals -BuildDir $BuildDir -SpineDir $SpineDir |
                      Where-Object { $_.Caption -and $_.Slot } |
                      ForEach-Object { $_.Slot } | Sort-Object -Unique)
}

function Get-ZipPart {
    param([Parameter(Mandatory)][string] $File, [Parameter(Mandatory)][string] $Match)
    $out = [ordered]@{}
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $File).Path)
    try {
        foreach ($e in $zip.Entries) {
            if ($e.FullName -notmatch $Match) { continue }
            $sr = New-Object System.IO.StreamReader($e.Open())
            $out[$e.FullName] = $sr.ReadToEnd()
            $sr.Dispose()
        }
        $out['__media__'] = @($zip.Entries | Where-Object { $_.FullName -match '(?i)^(word|ppt)/media/' }).Count
    }
    finally { $zip.Dispose() }
    return $out
}

foreach ($file in $Path) {
    if (-not (Test-Path -LiteralPath $file)) { throw "$GATE`: not found: $file" }
    $leaf = Split-Path $file -Leaf
    $isDeck = ($file -match '(?i)\.pptx$')

    $parts = Get-ZipPart -File $file -Match '(?i)^(word/(document|header\d+|footer\d+)\.xml|ppt/(slides|notesSlides)/[^/]+\.xml)$'
    $media = $parts['__media__']
    $body = ''
    foreach ($k in $parts.Keys) { if ($k -ne '__media__') { $body += $parts[$k] } }

    Write-Host ''
    Write-Host ("PLACED ARTWORK - {0}" -f $leaf) -ForegroundColor Cyan

    # --- 1. every drawing described
    $prTag = if ($isDeck) { '<p:cNvPr\b[^>]*>' } else { '<wp:docPr\b[^>]*>' }
    $prs = [regex]::Matches($body, $prTag)
    $noAlt = 0
    $drawn = 0
    foreach ($m in $prs) {
        #  On a deck every shape carries a cNvPr, so only the picture shapes are
        #  in scope; on a docx a wp:docPr belongs to a drawing by definition.
        if ($isDeck -and $m.Value -notmatch '(?i)name="(picture|image|graphic|chart|diagram)') { continue }
        $drawn++
        $descr = [regex]::Match($m.Value, 'descr="([^"]*)"').Groups[1].Value
        $title = [regex]::Match($m.Value, 'title="([^"]*)"').Groups[1].Value
        if (-not $descr.Trim() -and -not $title.Trim()) { $noAlt++ }
    }
    Write-Host ("  drawing objects: {0}   media parts: {1}" -f $drawn, $media) -ForegroundColor DarkGray
    if ($noAlt -eq 0) { Write-Host '  every drawing carries alt text' -ForegroundColor Green }
    else { Write-Host ("  X {0} drawing(s) with no alt text" -f $noAlt) -ForegroundColor Red; $failures++ }

    if ($isDeck) {
        # captions and figure numbering are a guide concern; the prompt sweep is not
        $leftover = 0
        foreach ($tok in $PromptToken) {
            $n = ([regex]::Matches($body, [regex]::Escape($tok))).Count
            if ($n -gt 0) { Write-Host ("  X prompt text survived: '{0}' x{1}" -f $tok, $n) -ForegroundColor Red; $leftover += $n }
        }
        if ($leftover -eq 0) { Write-Host '  no prompt text anywhere in the package' -ForegroundColor Green }
        else { $failures++ }
        continue
    }

    # --- 2. captions, per number, NO de-duplication
    $doc = $parts['word/document.xml']
    $capRx = '^\s*' + [regex]::Escape($CaptionPrefix) + '\s+(\d+(?:\.\d+)+)'
    $counts = @{}
    $byStyle = 0; $byCentre = 0; $byItalic = 0; $rejected = 0
    foreach ($pm in [regex]::Matches($doc, '<w:p\b[^>]*>.*?</w:p>', 'Singleline')) {
        $p = $pm.Value
        $text = -join ([regex]::Matches($p, '<w:t[^>]*>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value })
        $text = [System.Net.WebUtility]::HtmlDecode($text)
        $m = [regex]::Match($text, $capRx)
        if (-not $m.Success) { continue }

        #  STYLE-SCOPED, so an in-prose cross-reference cannot count. A caption
        #  paragraph declares itself one of three ways; whichever this house
        #  uses, the count below says which did the work.
        $style = [regex]::Match($p, '<w:pStyle w:val="([^"]*)"').Groups[1].Value
        $isCap = $false
        if ($style -and $style -match $CaptionStyleRx) { $isCap = $true; $byStyle++ }
        elseif ($p -match '<w:jc w:val="center"\s*/>') { $isCap = $true; $byCentre++ }
        elseif ($p -match '<w:i\s*/>' -and $text.Trim().StartsWith($CaptionPrefix)) { $isCap = $true; $byItalic++ }
        if (-not $isCap) { $rejected++; continue }

        $num = $m.Groups[1].Value
        if ($counts.ContainsKey($num)) { $counts[$num]++ } else { $counts[$num] = 1 }
    }
    Write-Host ("  caption paragraphs: {0} distinct number(s); matched by style {1}, centring {2}, italic {3}; {4} in-prose reference(s) correctly not counted" -f `
        $counts.Count, $byStyle, $byCentre, $byItalic, $rejected) -ForegroundColor DarkGray

    $dupes = @($counts.Keys | Where-Object { $counts[$_] -gt 1 } | Sort-Object)
    if ($dupes.Count -gt 0) {
        foreach ($d in $dupes) { Write-Host ("  X {0} {1} has {2} captions - every cross-reference to it is now ambiguous" -f $CaptionPrefix, $d, $counts[$d]) -ForegroundColor Red }
        $failures++
    }
    else { Write-Host '  no figure number carries more than one caption' -ForegroundColor Green }

    # --- 3. contiguous inside each sub-section
    $bySection = @{}
    foreach ($num in $counts.Keys) {
        $bits = $num -split '\.'
        $sec = ($bits[0..($bits.Count - 2)]) -join '.'
        $n = [int]$bits[-1]
        if (-not $bySection.ContainsKey($sec)) { $bySection[$sec] = New-Object System.Collections.Generic.List[int] }
        $bySection[$sec].Add($n)
    }
    $bad = 0
    foreach ($sec in ($bySection.Keys | Sort-Object)) {
        $ns = @($bySection[$sec] | Sort-Object)
        $gaps = @((1..$ns[-1]) | Where-Object { $ns -notcontains $_ })
        if ($gaps.Count -gt 0) {
            Write-Host ("  X sub-section {0}: figure number(s) {1} missing from 1..{2}" -f $sec, ($gaps -join ', '), $ns[-1]) -ForegroundColor Red
            $bad++
        }
    }
    if ($bad -eq 0) { Write-Host ("  figure numbering is contiguous in all {0} sub-section(s)" -f $bySection.Count) -ForegroundColor Green }
    else { $failures++ }

    # --- 4. caption-to-slot reconciliation, counts from the spine
    if ($plannedSlots.Count -gt 0) {
        $missingSlots = @($plannedSlots | Where-Object { -not $counts.ContainsKey($_) })
        $strays = @($counts.Keys | Where-Object { $plannedSlots -notcontains $_ } | Sort-Object)
        Write-Host ("  spine plans {0} captioned slot(s); the document carries {1}" -f $plannedSlots.Count, $counts.Count) -ForegroundColor DarkGray
        if ($missingSlots.Count -gt 0) {
            Write-Host ("  X planned slot(s) with no caption in the document: {0}" -f ($missingSlots -join ', ')) -ForegroundColor Red
            $failures++
        }
        if ($strays.Count -gt 0) {
            Write-Host ("  X caption(s) for slot(s) the spine does not plan: {0}" -f ($strays -join ', ')) -ForegroundColor Red
            $failures++
        }
        if ($missingSlots.Count -eq 0 -and $strays.Count -eq 0) {
            Write-Host '  every planned slot has exactly one caption, and no caption is unplanned' -ForegroundColor Green
        }
    }
    else {
        Write-Host '  caption-to-slot reconciliation NOT RUN - no -BuildDir supplied, so the counts have nothing' -ForegroundColor Yellow
        Write-Host '  to be checked against. At Stage 7c this must be supplied.' -ForegroundColor Yellow
    }

    # --- 5. nothing left of the prompts, body plus every header and footer
    $leftover = 0
    foreach ($tok in $PromptToken) {
        $n = ([regex]::Matches($body, [regex]::Escape($tok))).Count
        if ($n -gt 0) { Write-Host ("  X prompt text survived: '{0}' x{1}" -f $tok, $n) -ForegroundColor Red; $leftover += $n }
    }
    if ($leftover -eq 0) { Write-Host ("  no prompt text in the body or in any of the {0} part(s) swept" -f (@($parts.Keys).Count - 1)) -ForegroundColor Green }
    else { $failures++ }
}

Write-Host ''
if ($failures -eq 0) {
    Write-Host ("  placed artwork is sound across {0} artefact(s)" -f @($Path).Count) -ForegroundColor Green
    exit 0
}
Write-Host ("  X {0} placed-artwork failure(s)" -f $failures) -ForegroundColor Red
Write-Host '  Remediate, re-render, re-place, and re-run the WHOLE gate set - not this one.' -ForegroundColor Yellow
exit 1
