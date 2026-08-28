<#
    Verify-Document.ps1

    The Word COM verification layer. Runs AFTER Build-FromTemplate.ps1 has
    produced a .docx.

    This file does not author content. It opens a finished document, updates its
    fields, exports a PDF, and reports on what Word actually put on the page.

    WHY IT IS SEPARATE. Everything in Build-FromTemplate.ps1 is deterministic XML
    editing that needs no Word installed. Everything here needs Word, and needs it
    for one reason: only Word knows where its own page breaks fall. A package can
    be perfectly valid XML and still print a blank page.

    A clean render is not proof on its own. Word measures table rows slightly
    taller than other renderers, so a table sized to exactly fit the page in
    LibreOffice gets pushed to the next page in Word. Leave headroom rather than
    sizing to the limit.

    ALWAYS call Close-Word, including on failure. An orphaned WINWORD.EXE holds a
    lock on the output file and the next build fails confusingly.
#>

# No Set-StrictMode - this file is dot-sourced and a strict mode set here leaks
# into the caller's whole session.

$script:Word = $null
$script:Doc  = $null

# Word enumeration constants used below.
$wdNumberOfPagesInDoc = 4
$wdGoToPage           = 1
$wdGoToAbsolute       = 1
$wdExportFormatPDF    = 17
$wdStatisticPages     = 2
$wdStatisticWords     = 0
$wdVerticalPositionRelativeToPage = 6
$wdDoNotSaveChanges   = 0

# ---------------------------------------------------------------------------
# Session
# ---------------------------------------------------------------------------

function Test-WordAvailable {
    <# Probe before deciding a build method. Do not assume Word is installed. #>
    $w = $null
    try {
        $w = New-Object -ComObject Word.Application
        $v = $w.Version
        return [pscustomobject]@{ Available = $true; Version = $v }
    }
    catch { return [pscustomobject]@{ Available = $false; Version = $null } }
    finally {
        if ($w) {
            try { $w.Quit() } catch { }
            [void][Runtime.InteropServices.Marshal]::ReleaseComObject($w)
            # Wait for it to actually go, or the NEXT New-Object attaches to the
            # dying instance and the session fails with an RPC error that reads
            # like corruption. See Wait-WordReleased.
            Wait-WordReleased
        }
    }
}

function Open-Document {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [switch] $ReadOnly
    )
    if (-not (Test-Path -LiteralPath $Path)) { throw "Not found: $Path" }
    $full = (Resolve-Path -LiteralPath $Path).Path

    # REUSE a live Word instance rather than paying a cold start per document.
    # Complete-Pack leans on this: one WINWORD for the whole pack, quit once in
    # its finally. A dead reference (Word quit or crashed since) throws on the
    # probe; discard it and start fresh.
    if ($null -ne $script:Word) {
        try { $null = $script:Word.Version }
        catch {
            try { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($script:Word) } catch { }
            $script:Word = $null
        }
    }
    if ($null -eq $script:Word) {
        $script:Word = New-Object -ComObject Word.Application
    }
    $script:Word.Visible      = $false
    $script:Word.DisplayAlerts = 0          # wdAlertsNone - never block on a dialog
    # ConfirmConversions=false. If Word needs to convert, the file is not a clean
    # .docx and we want the failure, not a silent repair.
    $script:Doc = $script:Word.Documents.Open($full, $false, [bool]$ReadOnly)
    return $script:Doc
}

function Wait-WordReleased {
    <#  Give a quitting Word instance time to actually go away.

        Test-WordAvailable used to Quit and release in the same breath. The next
        New-Object -ComObject Word.Application then attached to the dying instance
        and the whole session failed with 0x800706BE / 0x800706BA - "the remote
        procedure call failed", which reads exactly like document corruption and
        is not. Reproduced roughly one run in three.  #>
    [System.Runtime.InteropServices.Marshal]::CleanupUnusedObjectsInCurrentContext() 2>$null
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
    Start-Sleep -Milliseconds 400
}

function Close-Document {
    <#  Close the open document but KEEP WORD RUNNING, so the next document in a
        pack reuses the session instead of paying quit-then-cold-start - which
        is also the 0x800706BE race window Wait-WordReleased documents. #>
    [CmdletBinding()]
    param([switch] $SaveChanges)
    $mode = if ($SaveChanges) { -1 } else { $wdDoNotSaveChanges }
    try { if ($null -ne $script:Doc) { $script:Doc.Close($mode) } } catch { }
    if ($null -ne $script:Doc) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($script:Doc) }
    $script:Doc = $null
}

function Close-Word {
    [CmdletBinding()]
    param([switch] $SaveChanges)
    $mode = if ($SaveChanges) { -1 } else { $wdDoNotSaveChanges }   # -1 = wdSaveChanges
    try { if ($null -ne $script:Doc)  { $script:Doc.Close($mode) } } catch { }
    try { if ($null -ne $script:Word) { $script:Word.Quit() } } catch { }
    if ($null -ne $script:Doc)  { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($script:Doc) }
    $wasOpen = ($null -ne $script:Word)
    if ($null -ne $script:Word) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($script:Word) }
    $script:Doc  = $null
    $script:Word = $null
    # The FULL settle, not a single GC pass. Quit-then-New-Object without it is
    # the 0x800706BE race Wait-WordReleased documents - until 27 August 2026 the
    # fix lived only in Test-WordAvailable, so any caller that closed Word and
    # opened it again in the same breath still hit the race.
    if ($wasOpen) { Wait-WordReleased }
    else { [System.GC]::Collect(); [System.GC]::WaitForPendingFinalizers() }
}

# ---------------------------------------------------------------------------
# Fields and output
# ---------------------------------------------------------------------------

function Update-Fields {
    <#  Table of contents, page numbers and every DOCPROPERTY field.

        Build-FromTemplate.ps1 already refreshes the cached DOCPROPERTY results
        when it writes a property. This is the second half of the same belt-and-
        braces: a footer that disagrees with docProps/custom.xml is a document-
        control finding, and it is invisible until someone opens the file.  #>
    if ($null -eq $script:Doc) { throw 'No document open. Call Open-Document first.' }
    foreach ($toc in $script:Doc.TablesOfContents) { $toc.Update() }
    $script:Doc.Fields.Update() | Out-Null
    # Headers and footers are separate story ranges; Fields.Update does not reach them.
    foreach ($sec in $script:Doc.Sections) {
        foreach ($hf in @($sec.Headers, $sec.Footers)) {
            foreach ($item in $hf) { try { $item.Range.Fields.Update() | Out-Null } catch { } }
        }
    }
    $script:Doc.Repaginate()
}

function Export-DocumentPdf {
    [CmdletBinding()]
    param([string] $Path)
    if ($null -eq $script:Doc) { throw 'No document open.' }
    if (-not $Path) { $Path = [System.IO.Path]::ChangeExtension($script:Doc.FullName, '.pdf') }
    $script:Doc.ExportAsFixedFormat($Path, $wdExportFormatPDF)
    Write-Verbose "Exported PDF: $Path"
    return $Path
}

function Get-DocumentStats {
    if ($null -eq $script:Doc) { throw 'No document open.' }
    [pscustomobject]@{
        Path  = $script:Doc.FullName
        Pages = $script:Doc.ComputeStatistics($wdStatisticPages)
        Words = $script:Doc.ComputeStatistics($wdStatisticWords)
    }
}

# ---------------------------------------------------------------------------
# Page flow
# ---------------------------------------------------------------------------

function Test-PageFlow {
    <#  Blank and thin pages on the open document, using Word's own pagination.

        A thin page is fixed by DEEPENING THE WRITING ROWS above it, never by
        shrinking a response box. The writing room is the learner's working
        surface; spend the space there rather than pulling content up.

        The last page is exempt from the thin test - a section legitimately ends
        part-way down a page.  #>
    [CmdletBinding()]
    param(
        [int] $ThinLineThreshold = 5,          # retained for callers; no longer the fill measure
        [double] $FillFraction = 0.45,         # a page is "thin" only if content ends above this fraction of the text column
        [int] $MinLinesForFull = 20,           # a page with this many rendered lines is full, whatever the last character reports
        [switch] $SkipFieldUpdate              # caller has JUST run Update-Fields on an unchanged document - do not pay for it twice
    )

    if ($null -eq $script:Doc) { throw 'No document open.' }
    if (-not $SkipFieldUpdate) { Update-Fields }
    $pages    = $script:Doc.Content.Information($wdNumberOfPagesInDoc)
    $findings = New-Object System.Collections.Generic.List[object]

    # The predefined '\page' bookmark hangs off Selection, not off a Range
    # returned by Document.GoTo. Selection is the only reliable route to one page.
    $sel = $script:Word.Selection

    # Where the text column actually ends, in points.
    $ps        = $script:Doc.PageSetup
    $pageH     = $ps.PageHeight
    $contentBot = $pageH - $ps.BottomMargin
    $fullFrom  = $contentBot * $FillFraction

    for ($p = 1; $p -le $pages; $p++) {
        $sel.GoTo($wdGoToPage, $wdGoToAbsolute, $p) > $null
        $rng   = $sel.Bookmarks.Item('\page').Range
        $raw   = $rng.Text
        $text  = ($raw -replace '[\r\a\f\x07]', "`n")
        $lines = @($text -split "`n" | Where-Object { $_.Trim().Length -gt 0 })

        if ($lines.Count -eq 0) {
            $findings.Add([pscustomobject]@{ Page = $p; Issue = 'BLANK'; Lines = 0; BottomPt = 0 })
            continue
        }
        if ($p -eq $pages) { continue }        # the last page legitimately ends short

        # DO NOT USE A LINE COUNT AS A FILL MEASURE.
        #
        # A page holding one question part plus a page-filling response box reads
        # as three lines and a naive counter calls it thin. It is full. Deepening
        # a box that is already correct is the wrong fix, and this check used to
        # provoke exactly that.
        #
        # Measure where the content actually ENDS on the page instead: take the
        # last character's vertical position. A table, an answer box and a
        # paragraph all push it down honestly.
        $last = $rng.Characters.Last
        $bottom = 0
        try { $bottom = [double]$last.Information($wdVerticalPositionRelativeToPage) } catch { }

        # A tall table can report a negative or zero position; treat that as full
        # rather than guessing, so the check never fails a page it cannot measure.
        #
        # SAME PROBLEM, DIFFERENT SHAPE: where the last character sits inside a
        # table that CONTINUES onto the next page, the position reads near the top
        # of the page and a full page is reported thin. Observed on pages carrying
        # 34 and 38 rendered lines, both reported at BottomPt 77 - which is the top
        # margin, not the foot. A page with this many lines is full whatever the
        # last character says, so let the line count veto the measurement.
        if ($lines.Count -ge $MinLinesForFull) { continue }

        # THE MEASUREMENT IS BOGUS WHEN IT LANDS ON THE TOP MARGIN. Where the last
        # character sits in a table row that continues onto the next page, Word
        # reports its position as the START of that row - which resolves to the top
        # of the page. Content cannot honestly END at the top margin unless the page
        # holds a line or two, so a page reporting that while carrying several lines
        # is unmeasurable, not thin. Observed at BottomPt 77 on pages of 10 to 38
        # lines; treating those as thin produced findings nobody could act on.
        $topM = $ps.TopMargin
        # One line-height of tolerance: 11 pt on 1.5 spacing is about 20 pt, and the
        # reported figure carries a fraction the display rounds off (77.3 is shown
        # as 77, so a +5 window missed it).
        if ($bottom -gt 0 -and $bottom -le ($topM + 24) -and $lines.Count -ge 4) { continue }

        if ($bottom -gt 0 -and $bottom -lt $fullFrom) {
            $findings.Add([pscustomobject]@{
                Page     = $p
                Issue    = 'THIN'
                Lines    = $lines.Count
                BottomPt = [int]$bottom
            })
        }
    }

    Write-Host ("Page flow: {0} pages, {1} issue(s). Fill measured to {2}% of a {3}pt text column." -f `
                $pages, $findings.Count, [int]($FillFraction * 100), [int]$contentBot)
    if ($findings.Count -gt 0) { $findings | Format-Table -AutoSize | Out-String -Width 120 | Write-Host }

    [pscustomobject]@{
        Ok       = ($findings.Count -eq 0)
        Pages    = $pages
        Findings = $findings.ToArray()
    }
}

function Get-PageText {
    <# The rendered text of one page. Used to verify the cover sheet holds page 1. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][int] $Page)
    if ($null -eq $script:Doc) { throw 'No document open.' }
    $sel = $script:Word.Selection
    $sel.GoTo($wdGoToPage, $wdGoToAbsolute, $Page) > $null
    return $sel.Bookmarks.Item('\page').Range.Text
}

function Test-CoverSheet {
    <#  The cover sheet holds EXACTLY one page, with every approved clause on it.

        Verified by extracting the rendered page-1 text, never by eye. A dropped
        clause looks like nothing at all - there is no gap on the page where it
        used to be. Compression is the only permitted fix; no clause is ever cut,
        summarised or abridged to make the sheet fit.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Branding,
        [string[]] $RequiredClauses
    )

    if (-not $RequiredClauses) {
        $p = $Branding.policy
        $RequiredClauses = @(
            'ASSESSMENT COVER SHEET'
            $p.studentIdLabel
            $p.dueDateLabel
            'Qualification:'
            'Trainer / Assessor:'
            'Unit Code'
            'First submission'
            'Late Submission'
            "within $($p.lateSubmissionDays) days"
            'Re-sits'
            "`$$($p.theoryResitFee)"
            "`$$($p.practicalResitFee)"
            'Plagiarism'
            'Results'
            "within $($p.resultsWithinDays) days"
            'Appeals'
            "$($p.appealWorkingDays) working days"
            'Please confirm:'
            'Student Signature:'
        )
        if ($p.includeOnlineSubmissionCheckbox) { $RequiredClauses += 'Online' }
        if ($p.includeGapsParagraph)            { $RequiredClauses += 'Gaps are identified' }
    }

    $page1  = Get-PageText -Page 1
    $missing = @($RequiredClauses | Where-Object { -not $page1.Contains($_) })

    # A clause that slipped onto page 2 is a different failure from one that was
    # dropped, and it is worth naming which.
    $spilled = @()
    if ($missing.Count -gt 0 -and $script:Doc.ComputeStatistics($wdStatisticPages) -ge 2) {
        $page2   = Get-PageText -Page 2
        $spilled = @($missing | Where-Object { $page2.Contains($_) })
    }

    $result = [pscustomobject]@{
        Ok      = ($missing.Count -eq 0)
        Missing = @($missing | Where-Object { $spilled -notcontains $_ })
        Spilled = $spilled
    }

    if ($result.Ok) { Write-Host 'Cover sheet: one page, every clause present.' }
    else {
        if ($result.Spilled.Count) { Write-Host "Cover sheet SPILLED to page 2: $($result.Spilled -join '; ')" }
        if ($result.Missing.Count) { Write-Host "Cover sheet MISSING clauses: $($result.Missing -join '; ')" }
    }
    return $result
}

# ---------------------------------------------------------------------------
# Sweeps over the RENDERED text
# ---------------------------------------------------------------------------

function Invoke-RenderedSweeps {
    <#  The pre-delivery sweeps from house-style.md section F, run against what
        Word actually rendered.

        Build-FromTemplate.ps1 has a source-text equivalent that is faster and
        catches most of this earlier. This one is authoritative: a field, a
        content control or a table caption can put text on the page that never
        appears in a <w:t> in document.xml.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Branding,
        [switch] $AssessorVersion
    )

    if ($null -eq $script:Doc) { throw 'No document open.' }
    $raw      = $script:Doc.Range().Text
    $findings = New-Object System.Collections.Generic.List[object]
    function Add-F($sweep, $detail) { $findings.Add([pscustomobject]@{ Sweep = $sweep; Detail = $detail }) }

    # U+00BB GUILLEMET, built from its code point. A literal here is decoded as
    # ANSI by PowerShell 5.1 and silently matches nothing. See template-build.md.
    $G = [char]0x00BB

    foreach ($m in [regex]::Matches($raw, '\[[^\]\r\n]{1,80}\]'))  { Add-F 'Placeholder'     "Unresolved placeholder: $($m.Value)" }

    # ARTWORK PROMPTS NEED THEIR OWN SWEEP. The placeholder regex above caps at
    # 80 characters and forbids line breaks, so it cannot match an image prompt:
    # those run to several hundred characters and a recipe-card block spans
    # several paragraphs. SKILL.md called this sweep the net that stops a prompt
    # reaching an auditor, and it would have passed every one of them silently.
    # Matched on the OPENING MARKER, which is short, fixed and cannot be missed.
    foreach ($m in [regex]::Matches($raw, '(?i)\[\s*(IMAGE|ILLUSTRATION|DIAGRAM|PHOTO|FIGURE|PICTURE)\s*(PROMPT)?\s*[:\-]')) {
        Add-F 'ArtworkPrompt' "An unresolved artwork prompt is still on the page: '$($m.Value.Trim())...'. Stage 7b did not place this image."
    }
    foreach ($m in [regex]::Matches($raw, '(?m)^\s*PROMPT\s*[:\-]')) {
        Add-F 'ArtworkPrompt' "An unresolved artwork prompt is still on the page: '$($m.Value.Trim())'."
    }
    foreach ($m in [regex]::Matches($raw, "$G[^\r\n]{0,200}"))     { Add-F 'Guidance marker' "Template guidance line left in: $($m.Value.Trim())" }

    # Every sweep below runs on the text with guidance lines stripped out. Such
    # a line is already reported above and is deleted at build, so leaving it in
    # would double-report it - and the guidance itself says things like "No oral
    # questioning", which would then be flagged as an oral-questioning reference.
    # Split on Word's cell and row marks too, not just line breaks. Text inside a
    # table cell is delimited by \a, so splitting on [\r\n] alone leaves a
    # guidance line embedded mid-string and the "^guillemet" test never matches it.
    $text = ($raw -split '[\r\n\a\f\v\x07]' | Where-Object { $_ -notmatch "^\s*$G" }) -join "`n"

    # Find-ForbiddenToken lives in Build-FromTemplate.ps1 - dot-source both.
    foreach ($hit in (Find-ForbiddenToken -Text $text -Branding $Branding)) {
        Add-F 'Brand crossover' "'$($hit.Token)' appears $($hit.Count) time(s) - belongs to the other brand."
    }

    if (-not $AssessorVersion) {
        # Assessor-panel LABELS, not ordinary words. 'benchmark' on its own is
        # legitimate learner prose - "your assessor judges every learner against
        # the same benchmarks" explains reliability to a student and is not a
        # leak. What must never appear is the furniture of an assessor panel.
        $leaks = @(
            'ASSESSOR BENCHMARK'
            'What Satisfactory looks like'
            'Minimum acceptable response'
            'Critical error'
            'Model answer'
            'Assessor use only'
            'NOT FOR RELEASE'
            'Sample-marked'
            'Simulated-environment setup'
            'Staged cue'
            'Assessor-supplied trigger'
        )
        foreach ($tok in $leaks) {
            $n = ([regex]::Matches($text, [regex]::Escape($tok), [Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
            if ($n -gt 0) { Add-F 'Assessor-only leak' "'$tok' appears $n time(s) in a learner document." }
        }
    }

    # 'Oral communication' is a Foundation Skill name and must not match.
    $n = ([regex]::Matches($text, 'oral(ly)?\s+question|Oral Questioning Record', [Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
    if ($n -gt 0) { Add-F 'Fixed position' "Oral questioning referenced $n time(s). MVC position is no oral questioning anywhere." }

    Write-Host "Rendered sweeps: $($findings.Count) finding(s)."
    if ($findings.Count -gt 0) { $findings | Format-Table -AutoSize | Out-String -Width 160 | Write-Host }

    [pscustomobject]@{
        Ok       = ($findings.Count -eq 0)
        Findings = $findings.ToArray()
    }
}

function Get-LongSentence {
    <#  Learner-facing sentences over the word limit.

        Legislation titles, verbatim unit text and assessed terminology are
        excluded from the reading-level judgement, so this reports candidates for
        a human to read rather than a pass/fail. A 30-word sentence that is the
        verbatim title of an Act is not a defect.  #>
    [CmdletBinding()]
    param([int] $MaxWords = 0, $Profile)
    # Default comes from the profile so it cannot drift from the written rule.
    if ($MaxWords -le 0) {
        $MaxWords = 20
        if ($Profile -and $Profile.writing.maxSentenceWords) { $MaxWords = [int]$Profile.writing.maxSentenceWords }
    }

    if ($null -eq $script:Doc) { throw 'No document open.' }
    $text = $script:Doc.Range().Text -replace '[\r\a\f\x07]', ' '
    $long = New-Object System.Collections.Generic.List[object]

    foreach ($s in ($text -split '(?<=[.!?])\s+')) {
        $t = $s.Trim()
        if ($t.Length -eq 0) { continue }
        $wc = @($t -split '\s+' | Where-Object { $_ }).Count
        if ($wc -gt $MaxWords) { $long.Add([pscustomobject]@{ Words = $wc; Sentence = $t }) }
    }

    Write-Host "Sentences over $MaxWords words: $($long.Count) (review each - verbatim unit text and Act titles are exempt)."
    return $long.ToArray()
}

# ---------------------------------------------------------------------------
# One-call gate
# ---------------------------------------------------------------------------

function Invoke-DocumentVerification {
    <#  Open, update, export, and run every gate. Returns one result object.
        Always closes Word, including on failure.

        Use this as the delivery gate for each produced document.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)] $Branding,
        [switch] $AssessorVersion,
        [switch] $SkipCoverSheet,
        [switch] $NoPdf,
        [switch] $KeepWordOpen      # pack mode: leave WINWORD running for the next document; the caller owns the final Close-Word
    )

    $r = [ordered]@{
        Path       = $Path
        Stats      = $null
        PageFlow   = $null
        CoverSheet = $null
        Sweeps     = $null
        LongSentences = @()
        Pdf        = $null
        Ok         = $false
        Error      = $null
    }

    # The house profile feeds Get-LongSentence its word limit. Optional on
    # purpose: the check is advisory, and a session without Test-HouseRules.ps1
    # dot-sourced still verifies - it just falls back to the built-in 20.
    $prof = $null
    if (Get-Command Get-HouseProfile -ErrorAction SilentlyContinue) {
        try { $prof = Get-HouseProfile -Brand $Branding.brand } catch { $prof = $null }
    }

    $failed = $false
    try {
        Open-Document -Path $Path | Out-Null
        Update-Fields
        # Save so the updated field results persist, then verify what was saved.
        $script:Doc.Save()

        $r.Stats    = Get-DocumentStats
        # Fields were updated and saved four lines up on an unchanged document -
        # skip the second multi-second COM pass Test-PageFlow would otherwise run.
        $r.PageFlow = Test-PageFlow -SkipFieldUpdate
        if (-not $SkipCoverSheet) { $r.CoverSheet = Test-CoverSheet -Branding $Branding }
        $r.Sweeps        = Invoke-RenderedSweeps -Branding $Branding -AssessorVersion:$AssessorVersion
        $r.LongSentences = Get-LongSentence -Profile $prof
        if (-not $NoPdf) { $r.Pdf = Export-DocumentPdf }

        $r.Ok = $r.PageFlow.Ok -and $r.Sweeps.Ok -and ($SkipCoverSheet -or $r.CoverSheet.Ok)
    }
    catch { $r.Error = $_.Exception.Message; $r.Ok = $false; $failed = $true }
    finally {
        # A COM fault poisons the session - tear the whole thing down rather
        # than hand the next document a wounded Word. Otherwise honour pack
        # mode and keep Word for the next file.
        if ($failed -or -not $KeepWordOpen) { Close-Word } else { Close-Document }
    }

    # BRAND LOGO, RE-PROVEN ON THE SHIPPED BYTES. Write-PackDocument's gate runs
    # before repack, but the artwork pass and Word itself both write the file
    # AFTER that gate, and nothing re-checked the result - the third bypass the
    # adversarial review of 29 August 2026 named. Runs after the Word session:
    # expand the file as it will ship, resolve the variant from the unit code in
    # the file name, and hold the same line - headers carry the resolved mark,
    # no part carries any other. Failure is a verification failure, not a throw,
    # so a pack run reports every document rather than dying on the first.
    if ($Branding -and (Get-Command Assert-BrandLogo -ErrorAction SilentlyContinue)) {
        try {
            $wchk = Expand-Docx -Path $Path
            $logoDir = Join-Path $script:SkillRoot 'assets\logos'
            $assets = @(); if (Test-Path $logoDir) { $assets = @(Get-ChildItem -LiteralPath $logoDir -File | ForEach-Object { $_.FullName }) }
            $swaps = ($Branding.PSObject.Properties.Name -contains 'templates' -and $Branding.templates -and
                      $Branding.templates.PSObject.Properties.Name -contains 'swapLogo' -and $Branding.templates.swapLogo)
            if ($swaps) {
                $unitCode = ([System.IO.Path]::GetFileNameWithoutExtension($Path) -replace '^Assessor_Guide_', '') -split '_' | Select-Object -First 1
                $v = Resolve-BrandVariant -Branding $Branding -UnitCode $unitCode -Variant $null
                $expLogo = Join-Path $script:SkillRoot $Branding.variants.$v.logo.path
                $null = Assert-BrandLogo -WorkDir $wchk -ExpectedLogoPath $expLogo -ForbiddenLogoPaths $assets
                Write-Host ("Brand logo: headers carry {0} ({1})." -f (Split-Path $expLogo -Leaf), $v)
            } elseif ($assets.Count -gt 0) {
                $null = Assert-BrandLogo -WorkDir $wchk -ForbiddenLogoPaths $assets
            }
        } catch {
            $r.Error = "Brand logo verification: " + $_.Exception.Message
            $r.Ok = $false
            Write-Host ("  BRAND LOGO FAILED: " + $_.Exception.Message) -ForegroundColor Red
        }
    }

    $obj = [pscustomobject]$r
    Write-Host ("`nVERIFY {0}: {1}" -f ([System.IO.Path]::GetFileName($Path)), $(if ($obj.Ok) { 'PASS' } else { 'FAIL' }))
    if ($obj.Error) { Write-Host "  error: $($obj.Error)" }
    return $obj
}

Write-Verbose 'Verify-Document.ps1 loaded.'
