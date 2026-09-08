<#
    Finish-Documents.ps1 - Stage 8: build the Contents, export both PDFs, and
    believe the FILESYSTEM about what happened.

    Promoted from a build-directory copy. The Word work is unchanged in
    substance; what is added is a concurrent PowerPoint export in its own
    process, and a byte-level verification of both PDFs before either is
    reported as success.

    WHY THIS IS CAREFUL. On this machine a .docx carrying live PAGE and NUMPAGES
    footer fields together with a large number of drawing objects has hung Word
    COM on every serialising call - Save, SaveAs2 and ExportAsFixedFormat all
    spinning indefinitely at steady CPU. Read-only calls stayed fast throughout.
    A finished Learner Guide has well over a hundred placed drawings and live
    footer fields, so it sits in exactly that shape.

    So the order is: do the READ-ONLY work first and prove the document opens
    and measures; then the field update and the save under a WATCHDOG; and if
    Word will not serialise, kill it and say so plainly rather than leaving the
    run hung or a half-written file behind.

    ONLY THE TABLES OF CONTENTS ARE UPDATED - never a whole-document
    Fields.Update. That call walks every drawing and is what turns a slow save
    into a hang. TablesOfContents.Item(i).Update() is what populates the
    Contents, and it is all the Contents needs.

    A COM ERROR IS NOT PROOF THE WORK DID NOT HAPPEN. Word on this machine
    reliably completes the TOC update, the save and the export, and THEN dies at
    teardown with RPC_E_DISCONNECTED. The copy this replaces once believed the
    exception, reported FAILED, and a correct 383-page PDF was deleted and
    re-exported twice. So the verdict is read from the filesystem: the PDF must
    exist, must be newer than both the document and the moment this run began,
    must end in %%EOF, and must carry a page tree whose /Count agrees with what
    the application measured. A PDF that passes all of that is a success
    whatever the exception said; one that fails any of it is a failure whatever
    the application said.

    WORD IS UNRELIABLE AGAINST ONEDRIVE-SYNCED PATHS. Documents.Open silently
    remaps FullName to the SharePoint URL and Save then fails "read-only" - while
    PowerShell can take an exclusive handle on the same file and doc.ReadOnly
    reports False. This script warns before it starts when a path looks synced,
    and reports the remap if Word does it anyway. Run it on local temp copies
    and copy the verified files back.

    THE TWO EXPORTS RUN CONCURRENTLY. Word and PowerPoint are different
    applications with no shared state, and each is driven from its own
    Start-Job process, so the deck's PDF is being written while Word is still
    updating the Contents. The copy this replaces ran them serially.

    KILL RATHER THAN HANG. A job that overruns -TimeoutMinutes is stopped and
    the Office processes that started after this run began are killed. Only
    those: an operator's own open Word window predates the run and is left
    alone.

    TWO MODES, AND THE SPLIT IS THE WHOLE POINT.

    This script used to update the Contents and export both PDFs in one pass at
    Stage 8 - AFTER the last gate. Updating a table of contents SAVES the
    document: every delivered .docx was therefore rewritten after the gate that
    judged it, and on the reference build the deck was rewritten 92 seconds
    after the last gate too. Nothing downstream could tell a Contents rebuild
    from a content edit, because the evidence is the same - a newer file.

      -UpdateContents   Stage 7b, AFTER placement and BEFORE the 7c re-gate.
                        Opens the guide read-WRITE, updates only the tables of
                        contents, saves, closes. The last write to the .docx.
                        7c then gates the document as it will ship.

      -ExportPdfs       Stage 8. Opens both artefacts READ-ONLY, exports, and
                        verifies each PDF against what the application
                        measured. It cannot mutate either artefact, and it
                        refuses to export one whose bytes are not the bytes
                        7c judged (-ExtractDir, below).

    Exactly one mode per run. Running both in one pass is the arrangement this
    change exists to remove, so there is no default that does both.

    FRESHNESS IS PROVED, NOT ASSUMED. -ExportPdfs requires -ExtractDir: the
    directory holding the 7c text extracts, whose SOURCE line carries the
    sha256 of the package bytes the gate read. Export recomputes that hash and
    refuses by name when it differs. A missing -ExtractDir is a REFUSAL naming
    the parameter, never a silent skip - "the artefact I exported is the
    artefact the gate judged" is the claim Stage 8 exists to make.

    Usage
      Finish-Documents.ps1 -UpdateContents -Guide <path.docx> [-TimeoutMinutes 12]
      Finish-Documents.ps1 -ExportPdfs -Guide <path.docx> -Deck <path.pptx> -ExtractDir <dir>
      Finish-Documents.ps1 -SelfTest        no Office

    PS 5.1. ASCII only in this file. UTF-8 BOM required on disk.
    Exit 0 the mode's work is verified; 1 otherwise; 2 usage or refusal;
    4 self-test failed.
#>

[CmdletBinding()]
param(
    [string] $Guide,
    [string] $Deck,
    #  Stage 7b: Word updates the tables of contents and saves. Guide only.
    [switch] $UpdateContents,
    #  Stage 8: both artefacts opened READ-ONLY and exported.
    [switch] $ExportPdfs,
    #  Where the 7c extracts live. Their SOURCE line carries the sha256 of the
    #  package the gate read; -ExportPdfs refuses without it.
    [string] $ExtractDir,
    [int] $TimeoutMinutes = 12,
    [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# PDF verification - bytes, not beliefs
# ---------------------------------------------------------------------------

function Test-PdfFile {
    <#  Is this a complete PDF, and does its page tree say what it should?

        Reads the file as Latin-1 so every byte maps to one character and the
        regexes see the raw dictionaries. Word and PowerPoint on this machine
        write the page-tree root and the page objects as plain (uncompressed)
        objects even though they also use object streams, which is why /Count is
        reachable by pattern. Where a producer hides the page objects inside
        object streams the visible-page cross-check is a warning, not a failure;
        the root /Count is the number that must exist.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [int] $ExpectedPages = 0
    )
    $problems = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]
    $count = 0
    $visible = 0
    $bytes = 0

    if (-not (Test-Path -LiteralPath $Path)) {
        $problems.Add('the PDF does not exist')
        return [pscustomobject]@{ Ok = $false; Problems = @($problems); Warnings = @(); PageCount = 0; VisiblePages = 0; Bytes = 0 }
    }
    $raw = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path).Path)
    $bytes = $raw.Length
    if ($bytes -lt 64) {
        $problems.Add("the file is only $bytes byte(s)")
        return [pscustomobject]@{ Ok = $false; Problems = @($problems); Warnings = @(); PageCount = 0; VisiblePages = 0; Bytes = $bytes }
    }
    $s = [System.Text.Encoding]::GetEncoding(28591).GetString($raw)

    if (-not $s.StartsWith('%PDF-')) { $problems.Add('no %PDF- header') }

    $tail = $s.Substring([Math]::Max(0, $s.Length - 2048))
    if ($tail.TrimEnd() -notmatch '%%EOF\s*$') { $problems.Add('the file does not end in %%EOF - the writer did not finish, or the file is truncated') }

    #  The page tree root. Either key order occurs in the wild; take the largest
    #  /Count seen on a /Pages node, which is the root's.
    foreach ($m in [regex]::Matches($s, '/Type\s*/Pages\b[^>]*?/Count\s+(\d+)')) { $n = [int]$m.Groups[1].Value; if ($n -gt $count) { $count = $n } }
    foreach ($m in [regex]::Matches($s, '/Count\s+(\d+)[^>]*?/Type\s*/Pages\b')) { $n = [int]$m.Groups[1].Value; if ($n -gt $count) { $count = $n } }
    if ($count -le 0) { $problems.Add('no page-tree root (/Type /Pages with a /Count) is visible - the document structure was never written') }

    $visible = ([regex]::Matches($s, '/Type\s*/Page\b')).Count
    if ($count -gt 0 -and $visible -gt 0 -and $visible -ne $count) {
        $warnings.Add("page tree says $count page(s) but $visible page object(s) are visible - some may sit inside object streams")
    }
    if ($ExpectedPages -gt 0 -and $count -gt 0 -and $count -ne $ExpectedPages) {
        $problems.Add("the page tree carries $count page(s) but the application measured $ExpectedPages - this is not the export of the document as it now stands")
    }

    [pscustomobject]@{
        Ok           = ($problems.Count -eq 0)
        Problems     = @($problems)
        Warnings     = @($warnings)
        PageCount    = $count
        VisiblePages = $visible
        Bytes        = $bytes
    }
}

# ---------------------------------------------------------------------------
# Freshness - the artefact I am exporting IS the artefact the gate judged
# ---------------------------------------------------------------------------

function Get-ExtractSourceHash {
    <#  The sha256 Get-DocText stamped into an extract's SOURCE line:

            SOURCE: <file>  SHA256: <64 hex>  EXTRACTED: <ISO-8601 UTC>

        Returns the hash and the file it names, or a Problem saying which of
        the two is missing. An extract with no SOURCE line proves nothing and
        is reported as such rather than treated as agreement.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{ Ok = $false; Hash = ''; Source = ''; Problem = ("no extract at {0}" -f $Path) }
    }
    $txt = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path, [System.Text.Encoding]::UTF8)
    $m = [regex]::Match($txt, '(?im)^\s*SOURCE:\s*(?<f>.+?)\s\s+SHA256:\s*(?<h>[0-9a-fA-F]{64})\b')
    if (-not $m.Success) {
        return [pscustomobject]@{ Ok = $false; Hash = ''; Source = ''; Problem = ("the extract {0} carries no 'SOURCE: <file>  SHA256: <64 hex>' stamp, so it cannot say which bytes it describes" -f (Split-Path $Path -Leaf)) }
    }
    return [pscustomobject]@{ Ok = $true; Hash = $m.Groups['h'].Value.ToLower(); Source = $m.Groups['f'].Value.Trim(); Problem = '' }
}

function Find-ArtefactExtract {
    <#  The extract in -ExtractDir whose SOURCE line names this artefact.

        Matched on the file name the stamp itself carries, never on a naming
        convention: a convention is a second source of truth, and the stamp is
        the first one.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Artefact, [Parameter(Mandatory)][string] $Dir)
    $leaf = Split-Path $Artefact -Leaf
    $cands = @(Get-ChildItem -LiteralPath $Dir -Filter '*.txt' -File -ErrorAction SilentlyContinue)
    foreach ($c in $cands) {
        $s = Get-ExtractSourceHash -Path $c.FullName
        if ($s.Ok -and $s.Source -ieq $leaf) { return [pscustomobject]@{ Found = $true; Path = $c.FullName; Stamp = $s } }
    }
    return [pscustomobject]@{ Found = $false; Path = ''
        Stamp = [pscustomobject]@{ Ok = $false; Hash = ''; Source = ''
            Problem = ("no extract in {0} names {1} on its SOURCE line ({2} extract(s) read). Stage 8 cannot claim the artefact it is exporting is the one 7c judged." -f $Dir, $leaf, $cands.Count) } }
}

function Test-ArtefactFresh {
    <#  Does this artefact still carry the bytes the 7c extract describes?

        This is the anti-mutation rule stated as a hash rather than as a
        timestamp. A timestamp says a file was written; a hash says whether
        what was written differs, which is the question - a Contents rebuild
        and a content edit leave the same timestamp evidence, and that is
        precisely why the Contents rebuild moved to -UpdateContents, before
        the gate.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Artefact, [Parameter(Mandatory)][string] $Dir)
    $hit = Find-ArtefactExtract -Artefact $Artefact -Dir $Dir
    if (-not $hit.Found -or -not $hit.Stamp.Ok) {
        return [pscustomobject]@{ Ok = $false; Problem = $hit.Stamp.Problem; Expected = ''; Actual = ''; Extract = $hit.Path }
    }
    $actual = (Get-FileHash -LiteralPath $Artefact -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $hit.Stamp.Hash) {
        return [pscustomobject]@{ Ok = $false; Extract = $hit.Path; Expected = $hit.Stamp.Hash; Actual = $actual
            Problem = ("{0} has been rewritten since 7c read it: the extract {1} describes sha256 {2}, the file on disk is {3}. Stage 8 exports the artefact the gates judged, or it exports nothing." -f (Split-Path $Artefact -Leaf), (Split-Path $hit.Path -Leaf), $hit.Stamp.Hash.Substring(0, 12), $actual.Substring(0, 12)) }
    }
    return [pscustomobject]@{ Ok = $true; Problem = ''; Expected = $hit.Stamp.Hash; Actual = $actual; Extract = $hit.Path }
}

function Test-OoxmlPackage {
    <#  Is this still a readable OOXML package with its main part in it?

        No shared library, no Office: Stage 8 must be able to say a save
        landed without loading anything. A Word save that half-wrote the zip
        is the one failure mode a page count cannot see.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][string] $MainPart)
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        $z = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Path).Path)
        try {
            $names = @($z.Entries | ForEach-Object { $_.FullName })
            if ($names -notcontains $MainPart) { return [pscustomobject]@{ Ok = $false; Problem = ("the package has no {0}" -f $MainPart); Parts = $names.Count } }
            return [pscustomobject]@{ Ok = $true; Problem = ''; Parts = $names.Count }
        }
        finally { $z.Dispose() }
    }
    catch { return [pscustomobject]@{ Ok = $false; Problem = ("the package will not open as a zip: " + $_.Exception.Message); Parts = 0 } }
}

# ---------------------------------------------------------------------------
# The watchdog - one Office application per job, killed if it overruns
# ---------------------------------------------------------------------------

function Start-OfficeJob {
    param(
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][scriptblock] $Body,
        [object[]] $ArgumentList,
        [Parameter(Mandatory)][string] $ProcessName
    )
    $t0 = Get-Date
    $job = Start-Job -Name $Name -ScriptBlock $Body -ArgumentList $ArgumentList
    return [pscustomobject]@{ Name = $Name; Job = $job; Started = $t0; ProcessName = $ProcessName }
}

function Wait-OfficeJob {
    <#  Join a set of Office jobs under ONE deadline. A job still running at the
        deadline is stopped and the application processes that started after
        this run began are killed - never an instance the operator had open.
        Returns one result per job: the job's own object where it finished, or
        an Ok=$false result naming the timeout.  #>
    param(
        [Parameter(Mandatory)] $Handles,
        [Parameter(Mandatory)][int] $TimeoutSeconds
    )
    $jobs = @($Handles | ForEach-Object { $_.Job })
    $null = Wait-Job -Job $jobs -Timeout $TimeoutSeconds
    $out = @{}
    foreach ($h in $Handles) {
        $j = $h.Job
        if ($j.State -eq 'Completed') {
            $r = @(Receive-Job -Job $j -ErrorAction SilentlyContinue | Where-Object { $_ -and ($_.PSObject.Properties.Name -contains 'Ok') } | Select-Object -Last 1)
            if ($r.Count -eq 1) { $out[$h.Name] = $r[0] }
            else { $out[$h.Name] = [pscustomobject]@{ Ok = $false; Error = 'the job returned no result' } }
        }
        else {
            $state = $j.State
            if ($state -eq 'Running') { Stop-Job -Job $j -ErrorAction SilentlyContinue }
            $killed = 0
            foreach ($p in @(Get-Process -Name $h.ProcessName -ErrorAction SilentlyContinue)) {
                try { if ($p.StartTime -ge $h.Started.AddSeconds(-2)) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; $killed++ } } catch { }
            }
            $why = if ($state -eq 'Running') { "did not finish within $TimeoutSeconds s - job stopped, $killed $($h.ProcessName) process(es) started by this run killed" } else { "job ended in state $state" }
            $errText = ''
            try { $reason = $j.ChildJobs[0].JobStateInfo.Reason; if ($reason) { $errText = [string]$reason.Message } } catch { }
            if (-not $errText) { try { $null = Receive-Job -Job $j -ErrorAction Stop } catch { $errText = $_.Exception.Message } }
            if ($errText) { $why = $why + ' - ' + $errText }
            $out[$h.Name] = [pscustomobject]@{ Ok = $false; Error = $why; TimedOut = ($state -eq 'Running') }
        }
        Remove-Job -Job $j -Force -ErrorAction SilentlyContinue
    }
    return $out
}

# ---------------------------------------------------------------------------
# The two application bodies
# ---------------------------------------------------------------------------

#  STAGE 7b. The ONLY write to the .docx, and it happens BEFORE the 7c gate.
$script:WordContentsBody = {
    param($p)
    $w = $null
    try {
        $w = New-Object -ComObject Word.Application
        $w.Visible = $false
        $w.DisplayAlerts = 0
        $d = $w.Documents.Open($p, $false, $false)

        # READ-ONLY first: prove it opens and measures before anything writes.
        $remapped = ($d.FullName -ne $p)
        $words = $d.ComputeStatistics(0)

        # ONLY the tables of contents. A whole-document Fields.Update walks
        # every drawing and is what turns a slow save into a hang.
        $tocCount = $d.TablesOfContents.Count
        for ($i = 1; $i -le $tocCount; $i++) { $d.TablesOfContents.Item($i).Update() }

        # Pages AFTER the Contents is built - a grown Contents moves every page
        # after it, and this is the number 7c will judge and Stage 8 will match.
        $pages = $d.ComputeStatistics(2)

        $d.Save()
        $d.Close(0)
        [pscustomobject]@{ Ok = $true; Pages = $pages; Words = $words; Toc = $tocCount; Remapped = $remapped }
    }
    catch { [pscustomobject]@{ Ok = $false; Error = $_.Exception.Message } }
    finally { if ($w) { try { $w.Quit() } catch { } } }
}

#  STAGE 8. READ-ONLY. Documents.Open's third argument is ReadOnly; nothing
#  here saves, and the document is closed with 0 (do not save changes) even on
#  the error path. A Stage 8 that could write is a Stage 8 that can mutate
#  after the last gate.
$script:WordExportBody = {
    param($p)
    $w = $null
    try {
        $w = New-Object -ComObject Word.Application
        $w.Visible = $false
        $w.DisplayAlerts = 0
        $d = $w.Documents.Open($p, $false, $true)
        $remapped = ($d.FullName -ne $p)
        $words = $d.ComputeStatistics(0)
        $tocCount = $d.TablesOfContents.Count
        #  NOT updated here. If the Contents is stale at Stage 8 the 7b step
        #  did not run, and that is a finding, not something to fix silently.
        $pages = $d.ComputeStatistics(2)
        $pdf = [System.IO.Path]::ChangeExtension($p, '.pdf')
        $d.ExportAsFixedFormat($pdf, 17)
        $d.Close(0)
        [pscustomobject]@{ Ok = $true; Pages = $pages; Words = $words; Toc = $tocCount; Remapped = $remapped; Pdf = $pdf; ReadOnly = $true }
    }
    catch { [pscustomobject]@{ Ok = $false; Error = $_.Exception.Message } }
    finally { if ($w) { try { $w.Quit() } catch { } } }
}

$script:PowerPointBody = {
    param($p)
    $pp = $null
    try {
        $pp = New-Object -ComObject PowerPoint.Application
        # ReadOnly, not Untitled, no window. The deck is not modified here.
        $pr = $pp.Presentations.Open($p, $true, $false, $false)
        $slides = $pr.Slides.Count
        $pdf = [System.IO.Path]::ChangeExtension($p, '.pdf')
        $pr.SaveAs($pdf, 32)
        $pr.Close()
        [pscustomobject]@{ Ok = $true; Slides = $slides; Pdf = $pdf }
    }
    catch { [pscustomobject]@{ Ok = $false; Error = $_.Exception.Message } }
    finally { if ($pp) { try { $pp.Quit() } catch { } } }
}

# ---------------------------------------------------------------------------
# The verdict - from the filesystem
# ---------------------------------------------------------------------------

function Get-ExportVerdict {
    <#  Did the export land, whatever the application said? The PDF must exist,
        postdate both the run start and the source file, and pass Test-PdfFile
        against the page count the application measured where it gave one.  #>
    param(
        [Parameter(Mandatory)][string] $Source,
        [Parameter(Mandatory)][datetime] $Started,
        [int] $ExpectedPages = 0
    )
    $pdf  = [System.IO.Path]::ChangeExtension($Source, '.pdf')
    $srcF = Get-Item -LiteralPath $Source -ErrorAction SilentlyContinue
    $pdfF = Get-Item -LiteralPath $pdf -ErrorAction SilentlyContinue
    $problems = New-Object System.Collections.Generic.List[string]
    if (-not $pdfF) { $problems.Add('no PDF was written') }
    else {
        if ($pdfF.LastWriteTime -lt $Started.AddSeconds(-2)) { $problems.Add(("the PDF predates this run ({0}) - it is a stale file from an earlier export" -f $pdfF.LastWriteTime.ToString('HH:mm:ss'))) }
        if ($srcF -and $pdfF.LastWriteTime -lt $srcF.LastWriteTime) { $problems.Add(("the PDF ({0}) is OLDER than the document ({1}) - it is stale" -f $pdfF.LastWriteTime.ToString('HH:mm:ss'), $srcF.LastWriteTime.ToString('HH:mm:ss'))) }
    }
    $t = $null
    if ($pdfF) {
        $t = Test-PdfFile -Path $pdf -ExpectedPages $ExpectedPages
        foreach ($x in $t.Problems) { $problems.Add($x) }
    }
    [pscustomobject]@{
        Ok        = ($problems.Count -eq 0)
        Pdf       = $pdf
        Problems  = @($problems)
        Warnings  = $(if ($t) { @($t.Warnings) } else { @() })
        PageCount = $(if ($t) { $t.PageCount } else { 0 })
        Bytes     = $(if ($pdfF) { $pdfF.Length } else { 0 })
        Written   = $(if ($pdfF) { $pdfF.LastWriteTime } else { $null })
    }
}

function Test-SyncedPath {
    <# Does this path look OneDrive-synced? A warning, not a verdict. #>
    param([Parameter(Mandatory)][string] $Path)
    if ($Path -match '(?i)onedrive|sharepoint') { return $true }
    try {
        $attr = [int](Get-Item -LiteralPath $Path -ErrorAction Stop).Attributes
        # ReparsePoint 0x400, RecallOnOpen 0x40000, RecallOnDataAccess 0x400000
        if (($attr -band 0x400) -or ($attr -band 0x40000) -or ($attr -band 0x400000)) { return $true }
    } catch { }
    return $false
}

# ---------------------------------------------------------------------------
# Self-test - no Office
# ---------------------------------------------------------------------------

if ($SelfTest) {
    $pass = 0; $fail = 0
    function Ok  ($m) { $script:pass++; Write-Host "  PASS  $m" -ForegroundColor Green }
    function Bad ($m) { $script:fail++; Write-Host "  FAIL  $m" -ForegroundColor Red }
    Write-Host ''
    Write-Host 'Finish-Documents self-test' -ForegroundColor Cyan
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('fd_selftest_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        $latin1 = [System.Text.Encoding]::GetEncoding(28591)
        function New-MinimalPdf {
            param([int] $Count = 1, [int] $PageObjects = 1)
            $sb = New-Object System.Text.StringBuilder
            [void]$sb.Append("%PDF-1.4`n")
            [void]$sb.Append("1 0 obj`n<< /Type /Catalog /Pages 2 0 R >>`nendobj`n")
            $kids = @(); for ($i = 0; $i -lt $PageObjects; $i++) { $kids += ("{0} 0 R" -f (3 + $i)) }
            [void]$sb.Append(("2 0 obj`n<< /Type /Pages /Kids [{0}] /Count {1} >>`nendobj`n" -f ($kids -join ' '), $Count))
            for ($i = 0; $i -lt $PageObjects; $i++) {
                [void]$sb.Append(("{0} 0 obj`n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] >>`nendobj`n" -f (3 + $i)))
            }
            $xrefAt = $sb.Length
            $n = 3 + $PageObjects
            [void]$sb.Append("xref`n0 $n`n0000000000 65535 f `n")
            for ($i = 1; $i -lt $n; $i++) { [void]$sb.Append("0000000010 00000 n `n") }
            [void]$sb.Append("trailer`n<< /Size $n /Root 1 0 R >>`nstartxref`n$xrefAt`n%%EOF`n")
            return $sb.ToString()
        }
        $good = Join-Path $tmp 'good.pdf'
        [System.IO.File]::WriteAllBytes($good, $latin1.GetBytes((New-MinimalPdf -Count 1 -PageObjects 1)))
        $t = Test-PdfFile -Path $good -ExpectedPages 1
        if ($t.Ok -and $t.PageCount -eq 1) { Ok 'a minimal valid PDF is accepted, page tree /Count 1' } else { Bad ("good pdf rejected: " + ($t.Problems -join '; ')) }

        $noEof = Join-Path $tmp 'noeof.pdf'
        $txt = New-MinimalPdf -Count 1 -PageObjects 1
        $cut = $txt.Substring(0, $txt.IndexOf('%%EOF'))
        [System.IO.File]::WriteAllBytes($noEof, $latin1.GetBytes($cut))
        $t2 = Test-PdfFile -Path $noEof
        if (-not $t2.Ok -and ($t2.Problems -join ' ') -match '%%EOF') { Ok 'a file without %%EOF is rejected, naming %%EOF' } else { Bad ("truncated pdf: ok=$($t2.Ok) " + ($t2.Problems -join '; ')) }

        $wrong = Join-Path $tmp 'wrongcount.pdf'
        [System.IO.File]::WriteAllBytes($wrong, $latin1.GetBytes((New-MinimalPdf -Count 3 -PageObjects 1)))
        $t3 = Test-PdfFile -Path $wrong -ExpectedPages 1
        if (-not $t3.Ok -and ($t3.Problems -join ' ') -match 'measured 1') { Ok 'a page tree that disagrees with the application''s count is rejected' } else { Bad ("count mismatch: ok=$($t3.Ok) " + ($t3.Problems -join '; ')) }
        if (@($t3.Warnings).Count -eq 1) { Ok 'visible page objects against /Count is cross-checked (warning)' } else { Bad 'no visible-page warning' }

        $noPages = Join-Path $tmp 'nopages.pdf'
        [System.IO.File]::WriteAllBytes($noPages, $latin1.GetBytes("%PDF-1.4`n1 0 obj << /Type /Catalog >> endobj`n" + ('x' * 100) + "`ntrailer << /Size 2 >>`n%%EOF`n"))
        $t4 = Test-PdfFile -Path $noPages
        if (-not $t4.Ok -and ($t4.Problems -join ' ') -match 'page-tree root') { Ok 'a PDF with no page tree is rejected' } else { Bad ("no-pages: " + ($t4.Problems -join '; ')) }

        # ---- the real exports on this machine, if any are beside a delivered build: not touched here.

        # ---- the export verdict reads the filesystem: a PDF older than the run is stale
        $doc = Join-Path $tmp 'X.docx'
        [System.IO.File]::WriteAllText($doc, 'not really a docx')
        [System.IO.File]::Copy($good, (Join-Path $tmp 'X.pdf'), $true)
        (Get-Item (Join-Path $tmp 'X.pdf')).LastWriteTime = (Get-Date).AddHours(-1)
        $v = Get-ExportVerdict -Source $doc -Started (Get-Date) -ExpectedPages 1
        if (-not $v.Ok -and ($v.Problems -join ' ') -match 'predates this run') { Ok 'a PDF that predates the run is reported stale, however valid its bytes' } else { Bad ("stale verdict: ok=$($v.Ok) " + ($v.Problems -join '; ')) }
        (Get-Item (Join-Path $tmp 'X.pdf')).LastWriteTime = (Get-Date).AddSeconds(5)
        $v2 = Get-ExportVerdict -Source $doc -Started (Get-Date).AddSeconds(-1) -ExpectedPages 1
        if ($v2.Ok -and $v2.PageCount -eq 1) { Ok 'a fresh, valid PDF with the measured page count is a verified success' } else { Bad ("fresh verdict: " + ($v2.Problems -join '; ')) }

        # ---- the watchdog stops an overrunning job and kills nothing it did not start
        $quick = Start-OfficeJob -Name 'quick' -Body { param($x) [pscustomobject]@{ Ok = $true; Pages = $x } } -ArgumentList @(7) -ProcessName 'NoSuchProcess_FinishSelfTest'
        $slow  = Start-OfficeJob -Name 'slow'  -Body { param($x) Start-Sleep -Seconds 60; [pscustomobject]@{ Ok = $true } } -ArgumentList @(0) -ProcessName 'NoSuchProcess_FinishSelfTest'
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $res = Wait-OfficeJob -Handles @($quick, $slow) -TimeoutSeconds 4
        if ($res['quick'].Ok -and $res['quick'].Pages -eq 7) { Ok 'the watchdog returns a finished job''s own result' } else { Bad 'quick job result lost' }
        if (-not $res['slow'].Ok -and $res['slow'].TimedOut -and $sw.Elapsed.TotalSeconds -lt 30) { Ok ("the watchdog stops an overrunning job rather than hanging ({0:N1}s)" -f $sw.Elapsed.TotalSeconds) } else { Bad ("slow job: " + ($res['slow'] | Out-String)) }
        if (@(Get-Job -Name 'slow' -ErrorAction SilentlyContinue).Count -eq 0) { Ok 'the stopped job is removed' } else { Bad 'stopped job left behind'; Get-Job -Name 'slow' | Remove-Job -Force }

        # ---- FRESHNESS: the artefact exported IS the artefact 7c judged
        $ex = Join-Path $tmp 'extracts'
        New-Item -ItemType Directory -Force -Path $ex | Out-Null
        $art = Join-Path $tmp 'Guide.docx'
        [System.IO.File]::WriteAllText($art, 'the bytes 7c read')
        $h0 = (Get-FileHash -LiteralPath $art -Algorithm SHA256).Hash.ToLower()
        $stamp = "FIGURES: 3 placed drawings, 0 unresolved artwork prompt blocks`r`nCHANNELS: 1 tables`r`nSOURCE: Guide.docx  SHA256: $h0  EXTRACTED: 2026-09-08T00:00:00Z`r`n`r`nbody`r`n"
        [System.IO.File]::WriteAllText((Join-Path $ex 'guide.txt'), $stamp, (New-Object System.Text.UTF8Encoding($true)))
        $s = Get-ExtractSourceHash -Path (Join-Path $ex 'guide.txt')
        if ($s.Ok -and $s.Hash -eq $h0 -and $s.Source -eq 'Guide.docx') { Ok 'the 7c extract SOURCE stamp is read for its sha256 and the file it names' }
        else { Bad ("stamp read: " + ($s | Out-String)) }
        $f1 = Test-ArtefactFresh -Artefact $art -Dir $ex
        if ($f1.Ok) { Ok 'the clean control: an untouched artefact matches its extract hash' } else { Bad ("clean freshness: " + $f1.Problem) }

        #  PLANT: rewrite ONE byte of the artefact after the gate read it.
        [System.IO.File]::WriteAllText($art, 'the bytes 7c reaD')
        if ((Get-FileHash -LiteralPath $art -Algorithm SHA256).Hash.ToLower() -ne $h0) { Ok 'plant landed: the artefact differs from the bytes the extract describes' }
        else { Bad 'the one-byte plant did not change the hash' }
        $f2 = Test-ArtefactFresh -Artefact $art -Dir $ex
        if (-not $f2.Ok -and $f2.Problem -match 'Guide\.docx' -and $f2.Problem -match 'rewritten since 7c') { Ok 'and Test-ArtefactFresh REFUSES, naming the artefact and both hashes' }
        else { Bad ("planted freshness: ok=$($f2.Ok) " + $f2.Problem) }

        #  an extract with no SOURCE stamp proves nothing and says so
        [System.IO.File]::WriteAllText((Join-Path $ex 'nostamp.txt'), "FIGURES: 0`r`nbody`r`n", (New-Object System.Text.UTF8Encoding($true)))
        $s2 = Get-ExtractSourceHash -Path (Join-Path $ex 'nostamp.txt')
        if (-not $s2.Ok -and $s2.Problem -match 'SOURCE') { Ok 'an extract with no SOURCE stamp is reported as proving nothing, not treated as agreement' }
        else { Bad 'a stampless extract was accepted' }

        #  an artefact NO extract names is a refusal, never a pass
        $orphan = Join-Path $tmp 'Deck.pptx'
        [System.IO.File]::WriteAllText($orphan, 'deck bytes')
        $f3 = Test-ArtefactFresh -Artefact $orphan -Dir $ex
        if (-not $f3.Ok -and $f3.Problem -match 'Deck\.pptx') { Ok 'an artefact no extract names is REFUSED by name, never exported on trust' }
        else { Bad ("orphan artefact: ok=$($f3.Ok) " + $f3.Problem) }

        # ---- the package check a save has to survive
        $zipOk = Join-Path $tmp 'ok.docx'
        Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        #  Entry names are written EXPLICITLY with forward slashes. On .NET 4.x
        #  ZipFile.CreateFromDirectory writes the platform separator into the
        #  entry name, so a package built that way carries 'word\document.xml'
        #  and every OOXML reader - including this one - correctly says the
        #  main part is missing.
        $fs = [System.IO.File]::Open($zipOk, 'Create')
        try {
            $za = New-Object System.IO.Compression.ZipArchive($fs, 'Create')
            try {
                $en = $za.CreateEntry('word/document.xml')
                $sw = New-Object System.IO.StreamWriter($en.Open())
                $sw.Write('<w:document/>'); $sw.Flush(); $sw.Dispose()
            }
            finally { $za.Dispose() }
        }
        finally { $fs.Dispose() }
        $z1 = Test-OoxmlPackage -Path $zipOk -MainPart 'word/document.xml'
        if ($z1.Ok) { Ok 'a package carrying word/document.xml passes the post-save integrity check' } else { Bad ("zip ok: " + $z1.Problem) }
        $z2 = Test-OoxmlPackage -Path $zipOk -MainPart 'ppt/presentation.xml'
        if (-not $z2.Ok -and $z2.Problem -match 'ppt/presentation\.xml') { Ok 'and a package missing its main part FAILS naming the part' } else { Bad 'missing main part not detected' }
        $torn = Join-Path $tmp 'torn.docx'
        [System.IO.File]::WriteAllBytes($torn, ([System.IO.File]::ReadAllBytes($zipOk))[0..40])
        $z3 = Test-OoxmlPackage -Path $torn -MainPart 'word/document.xml'
        if (-not $z3.Ok) { Ok 'a half-written package FAILS rather than being reported saved' } else { Bad 'a truncated zip passed' }

        # ---- exactly one mode, and -ExportPdfs refuses without -ExtractDir
        $me = $PSCommandPath
        $null = & $me -Guide $zipOk -Deck $orphan 6>&1 2>&1
        if ($LASTEXITCODE -eq 2) { Ok 'no mode named: exit 2, and the banner says why there is no both-at-once mode' } else { Bad "no-mode exit $LASTEXITCODE" }
        $null = & $me -UpdateContents -ExportPdfs -Guide $zipOk -Deck $orphan -ExtractDir $ex 6>&1 2>&1
        if ($LASTEXITCODE -eq 2) { Ok 'both modes named: exit 2 - updating the Contents SAVES, and Stage 8 may not write' } else { Bad "both-modes exit $LASTEXITCODE" }
        $out = & $me -ExportPdfs -Guide $zipOk -Deck $orphan 6>&1 2>&1
        if ($LASTEXITCODE -eq 2 -and (($out | Out-String -Width 4096) -match 'ExtractDir')) { Ok '-ExportPdfs with no -ExtractDir REFUSES exit 2 and names the parameter' } else { Bad "no-extractdir exit $LASTEXITCODE" }
        $out = & $me -ExportPdfs -Guide $zipOk -Deck $orphan -ExtractDir $ex 6>&1 2>&1
        if ($LASTEXITCODE -eq 2 -and (($out | Out-String -Width 4096) -match 'STAGE 8 REFUSED')) { Ok 'and a stale artefact stops Stage 8 BEFORE Office is opened - nothing is exported' } else { Bad ("stale-refusal exit $LASTEXITCODE : " + (($out | Out-String -Width 4096).Trim())) }
    }
    finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host ''
    #  THE COM ARMS DID NOT RUN, AND THEY ARE NOT REPORTED AS PASSING.
    #  Word and PowerPoint automation cannot be exercised in this harness, so
    #  the two application bodies are covered by their callers' verdict logic
    #  (which IS tested above, from the filesystem) and by nothing else. A
    #  self-test that quietly counted them green would be the silent success
    #  this whole file argues against.
    $partial = @(
        'Word COM: $script:WordContentsBody - open read-write, TablesOfContents.Update, Save',
        'Word COM: $script:WordExportBody - open READ-ONLY, ExportAsFixedFormat',
        'PowerPoint COM: $script:PowerPointBody - open read-only, SaveAs 32'
    )
    Write-Host ("  {0} passed, {1} failed" -f $pass, $fail) -ForegroundColor $(if ($fail) { 'Red' } else { 'Green' })
    foreach ($x in $partial) { Write-Host ("  PARTIAL  not run in this harness: {0}" -f $x) -ForegroundColor Yellow }
    if ($fail) { exit 4 }
    Write-Host ("FINISH-DOCUMENTS SELF-TEST OK - PARTIAL, {0} check(s) not run" -f $partial.Count) -ForegroundColor Yellow
    exit 0
}

# ---------------------------------------------------------------------------
# The real thing - EXACTLY ONE MODE
# ---------------------------------------------------------------------------

$modes = @()
if ($UpdateContents) { $modes += 'UpdateContents' }
if ($ExportPdfs)     { $modes += 'ExportPdfs' }
if ($modes.Count -ne 1) {
    Write-Host ''
    Write-Host 'Finish-Documents: choose EXACTLY ONE of -UpdateContents or -ExportPdfs.' -ForegroundColor Red
    Write-Host '  -UpdateContents  Stage 7b, after placement and BEFORE the 7c re-gate. Word updates the' -ForegroundColor DarkGray
    Write-Host '                   tables of contents and saves. This is the last write to the .docx.' -ForegroundColor DarkGray
    Write-Host '  -ExportPdfs      Stage 8. Both artefacts opened READ-ONLY and exported, and refused if' -ForegroundColor DarkGray
    Write-Host '                   their bytes are not the bytes the 7c extracts describe.' -ForegroundColor DarkGray
    Write-Host '  There is deliberately no mode that does both: updating the Contents SAVES the document,' -ForegroundColor DarkGray
    Write-Host '  and doing that at Stage 8 rewrote every delivered artefact after the gate that judged it.' -ForegroundColor DarkGray
    exit 2
}
$mode = $modes[0]

$started = Get-Date
$timeout = $TimeoutMinutes * 60

function Test-FinishPath {
    param([string] $Path, [string] $What)
    if (-not $Path) { Write-Host ("Finish-Documents: -{0} is required for -{1}." -f $What, $mode) -ForegroundColor Red; return $false }
    if (-not (Test-Path -LiteralPath $Path)) { Write-Host ("Finish-Documents: not found: {0}" -f $Path) -ForegroundColor Red; return $false }
    return $true
}

# ---------------------------------------------------------------------------
# Stage 7b - the Contents, and the last write to the document
# ---------------------------------------------------------------------------

if ($mode -eq 'UpdateContents') {
    if (-not (Test-FinishPath -Path $Guide -What 'Guide')) { exit 2 }
    $Guide = (Resolve-Path -LiteralPath $Guide).Path
    if (Test-SyncedPath -Path $Guide) {
        Write-Host ("  WARNING: {0} looks OneDrive-synced. Word remaps a synced path to its SharePoint URL on open and Save then fails read-only. Finish local temp copies and copy the verified files back." -f (Split-Path $Guide -Leaf)) -ForegroundColor Yellow
    }
    $before = (Get-FileHash -LiteralPath $Guide -Algorithm SHA256).Hash.ToLower()

    Write-Host ''
    Write-Host ("UPDATE GUIDE CONTENTS - Stage 7b, before the 7c re-gate, {0} minute watchdog" -f $TimeoutMinutes) -ForegroundColor Cyan
    Write-Host ("  guide: {0}" -f $Guide) -ForegroundColor DarkGray
    Write-Host ("  sha256 in : {0}" -f $before) -ForegroundColor DarkGray

    $h = Start-OfficeJob -Name 'word' -Body $script:WordContentsBody -ArgumentList @($Guide) -ProcessName 'WINWORD'
    $res = Wait-OfficeJob -Handles @($h) -TimeoutSeconds $timeout
    $g = $res['word']

    if ($g.Ok) {
        Write-Host ("  Word: opened, {0} table(s) of contents updated, {1} pages, {2} words" -f $g.Toc, $g.Pages, $g.Words) -ForegroundColor Green
        if ($g.Remapped) { Write-Host '  NOTE: Word remapped the path on open - this is a synced folder; the Save may not have landed where you think' -ForegroundColor Yellow }
    }
    else {
        Write-Host ("  Word reported: {0}" -f $g.Error) -ForegroundColor DarkYellow
        Write-Host '  asking the filesystem rather than believing the exception' -ForegroundColor DarkGray
    }

    #  The verdict, from the file. A COM error is not proof the work did not
    #  happen, and a COM success is not proof it did.
    $problems = New-Object System.Collections.Generic.List[string]
    $after = (Get-FileHash -LiteralPath $Guide -Algorithm SHA256).Hash.ToLower()
    $fi = Get-Item -LiteralPath $Guide
    $pk = Test-OoxmlPackage -Path $Guide -MainPart 'word/document.xml'
    if (-not $pk.Ok) { $problems.Add('after the save, ' + $pk.Problem) }
    if ($after -eq $before) {
        if ($g.Ok -and [int]$g.Toc -eq 0) {
            Write-Host '  the document is byte-identical and Word found no table of contents in it - nothing to update' -ForegroundColor Yellow
        }
        else {
            $problems.Add("the document is byte-identical after the run (sha256 $before). Word reported $($g.Toc) table(s) of contents; a Contents update that changes nothing did not happen.")
        }
    }
    if ($fi.LastWriteTime -lt $started.AddSeconds(-2) -and $after -ne $before) { $problems.Add('the document changed but its LastWriteTime predates this run') }

    Write-Host ("  sha256 out: {0}" -f $after) -ForegroundColor DarkGray
    Write-Host ("  package   : {0} part(s)" -f $pk.Parts) -ForegroundColor DarkGray
    Write-Host ''
    if ($problems.Count -eq 0) {
        Write-Host ("CONTENTS UPDATED - re-run the 7c gate band against these bytes  ({0}s)" -f [int]((Get-Date) - $started).TotalSeconds) -ForegroundColor Green
        Write-Host '  Stage 8 will refuse to export any artefact whose sha256 differs from the one 7c stamps into its extract.' -ForegroundColor DarkGray
        exit 0
    }
    Write-Host '  FAILED - the Contents update is not a verified save:' -ForegroundColor Red
    foreach ($x in $problems) { Write-Host ("    X {0}" -f $x) -ForegroundColor Red }
    exit 1
}

# ---------------------------------------------------------------------------
# Stage 8 - export, READ-ONLY, and only what the gates judged
# ---------------------------------------------------------------------------

if (-not (Test-FinishPath -Path $Guide -What 'Guide')) { exit 2 }
if (-not (Test-FinishPath -Path $Deck  -What 'Deck'))  { exit 2 }
if (-not $ExtractDir) {
    Write-Host ''
    Write-Host 'Finish-Documents: -ExportPdfs REFUSES without -ExtractDir.' -ForegroundColor Red
    Write-Host '  It names the directory holding the 7c text extracts. Their SOURCE line carries the sha256' -ForegroundColor DarkGray
    Write-Host '  of the package bytes the gate read, and Stage 8 recomputes it before it exports anything.' -ForegroundColor DarkGray
    Write-Host '  Without it this script can export a PDF, but it cannot say the PDF is of the document the' -ForegroundColor DarkGray
    Write-Host '  gates passed - which is the only claim Stage 8 exists to make. Supply the directory.' -ForegroundColor DarkGray
    exit 2
}
if (-not (Test-Path -LiteralPath $ExtractDir)) {
    Write-Host ("Finish-Documents: -ExtractDir does not exist: {0}" -f $ExtractDir) -ForegroundColor Red
    exit 2
}
$Guide = (Resolve-Path -LiteralPath $Guide).Path
$Deck  = (Resolve-Path -LiteralPath $Deck).Path
$ExtractDir = (Resolve-Path -LiteralPath $ExtractDir).Path

#  Word cannot save to a path longer than 255 characters, and only the PDF
#  vanishes - the .docx was written by OOXML editing and is unaffected, which
#  reads as a content bug until the path is measured.
foreach ($p in @($Guide, $Deck)) {
    $pdfLen = ([System.IO.Path]::ChangeExtension($p, '.pdf')).Length
    if ($pdfLen -gt 255) { Write-Host ("  WARNING: the PDF path for {0} is {1} characters; Word fails silently past 255. Use a shorter working path." -f (Split-Path $p -Leaf), $pdfLen) -ForegroundColor Yellow }
}
foreach ($p in @($Guide, $Deck)) {
    if (Test-SyncedPath -Path $p) {
        Write-Host ("  WARNING: {0} looks OneDrive-synced. Word remaps a synced path to its SharePoint URL on open. Finish local temp copies and copy the verified files back." -f (Split-Path $p -Leaf)) -ForegroundColor Yellow
    }
}

Write-Host ''
Write-Host 'STAGE 8 FRESHNESS - the artefact exported is the artefact the gates judged' -ForegroundColor Cyan
$stale = New-Object System.Collections.Generic.List[string]
foreach ($p in @($Guide, $Deck)) {
    $fr = Test-ArtefactFresh -Artefact $p -Dir $ExtractDir
    if ($fr.Ok) { Write-Host ("  OK  {0}  sha256 {1} matches {2}" -f (Split-Path $p -Leaf), $fr.Actual.Substring(0, 12), (Split-Path $fr.Extract -Leaf)) -ForegroundColor Green }
    else { Write-Host ("  X   {0}" -f $fr.Problem) -ForegroundColor Red; $stale.Add($fr.Problem) }
}
if ($stale.Count -gt 0) {
    Write-Host ''
    Write-Host 'STAGE 8 REFUSED - nothing was exported. Re-run the 7c band against the bytes on disk, then export.' -ForegroundColor Red
    exit 2
}

Write-Host ''
Write-Host ("EXPORT PDFS - Word and PowerPoint READ-ONLY, in parallel, {0} minute watchdog" -f $TimeoutMinutes) -ForegroundColor Cyan
Write-Host ("  guide: {0}" -f $Guide) -ForegroundColor DarkGray
Write-Host ("  deck:  {0}" -f $Deck) -ForegroundColor DarkGray

$hw = Start-OfficeJob -Name 'word'       -Body $script:WordExportBody -ArgumentList @($Guide) -ProcessName 'WINWORD'
$hp = Start-OfficeJob -Name 'powerpoint' -Body $script:PowerPointBody -ArgumentList @($Deck)  -ProcessName 'POWERPNT'
$res = Wait-OfficeJob -Handles @($hw, $hp) -TimeoutSeconds $timeout

$rc = 0

# ---- guide
Write-Host ''
Write-Host 'LEARNER GUIDE - PDF' -ForegroundColor Cyan
$g = $res['word']
$expectedPages = 0
if ($g.Ok) {
    $expectedPages = [int]$g.Pages
    Write-Host ("  Word: opened READ-ONLY, {0} pages, {1} words, {2} table(s) of contents present" -f $g.Pages, $g.Words, $g.Toc) -ForegroundColor Green
    if ([int]$g.Toc -eq 0) { Write-Host '  NOTE: no table of contents in this document - if one is expected, -UpdateContents did not run at 7b' -ForegroundColor Yellow }
    if ($g.Remapped) { Write-Host '  NOTE: Word remapped the path on open - this is a synced folder' -ForegroundColor Yellow }
}
else {
    Write-Host ("  Word reported: {0}" -f $g.Error) -ForegroundColor DarkYellow
    Write-Host '  asking the filesystem rather than believing the exception' -ForegroundColor DarkGray
}
$gv = Get-ExportVerdict -Source $Guide -Started $started -ExpectedPages $expectedPages
if ($gv.Ok) {
    Write-Host ("  PDF verified: {0} page(s) in the page tree, {1} MB, %%EOF present, written {2}" -f $gv.PageCount, [math]::Round($gv.Bytes / 1MB, 2), $gv.Written.ToString('HH:mm:ss')) -ForegroundColor Green
    if (-not $g.Ok) { Write-Host '  treating as SUCCESS on the evidence of the file - Word died at teardown after the work was done' -ForegroundColor Green }
    if ($expectedPages -eq 0) { Write-Host '  NOTE: Word gave no page count before it died, so the page tree is checked for presence, not against a measurement' -ForegroundColor Yellow }
}
else {
    $rc = 1
    Write-Host '  FAILED - the guide PDF is not a verified export:' -ForegroundColor Red
    foreach ($x in $gv.Problems) { Write-Host ("    X {0}" -f $x) -ForegroundColor Red }
}
foreach ($x in $gv.Warnings) { Write-Host ("    ! {0}" -f $x) -ForegroundColor Yellow }

# ---- deck
Write-Host ''
Write-Host 'DELIVERY DECK - PDF' -ForegroundColor Cyan
$d = $res['powerpoint']
$expectedSlides = 0
if ($d.Ok) {
    $expectedSlides = [int]$d.Slides
    Write-Host ("  PowerPoint: opened read-only, {0} slides" -f $d.Slides) -ForegroundColor Green
}
else {
    Write-Host ("  PowerPoint reported: {0}" -f $d.Error) -ForegroundColor DarkYellow
    Write-Host '  asking the filesystem rather than believing the exception' -ForegroundColor DarkGray
}
$dv = Get-ExportVerdict -Source $Deck -Started $started -ExpectedPages $expectedSlides
if ($dv.Ok) {
    Write-Host ("  PDF verified: {0} page(s) in the page tree, {1} MB, %%EOF present, written {2}" -f $dv.PageCount, [math]::Round($dv.Bytes / 1MB, 2), $dv.Written.ToString('HH:mm:ss')) -ForegroundColor Green
    if (-not $d.Ok) { Write-Host '  treating as SUCCESS on the evidence of the file' -ForegroundColor Green }
    if ($expectedSlides -eq 0) { Write-Host '  NOTE: PowerPoint gave no slide count, so the page tree is checked for presence, not against a measurement' -ForegroundColor Yellow }
}
else {
    $rc = 1
    Write-Host '  FAILED - the deck PDF is not a verified export:' -ForegroundColor Red
    foreach ($x in $dv.Problems) { Write-Host ("    X {0}" -f $x) -ForegroundColor Red }
}
foreach ($x in $dv.Warnings) { Write-Host ("    ! {0}" -f $x) -ForegroundColor Yellow }

# ---- and nothing was mutated by exporting
Write-Host ''
$moved = New-Object System.Collections.Generic.List[string]
foreach ($p in @($Guide, $Deck)) {
    $fr = Test-ArtefactFresh -Artefact $p -Dir $ExtractDir
    if (-not $fr.Ok) { $moved.Add(("{0} changed DURING the export - the export path is supposed to be read-only" -f (Split-Path $p -Leaf))) }
}
if ($moved.Count -gt 0) {
    $rc = 1
    foreach ($x in $moved) { Write-Host ("  X {0}" -f $x) -ForegroundColor Red }
}
else { Write-Host '  both artefacts are byte-identical to the bytes the gates judged, after the export' -ForegroundColor Green }

Write-Host ''
if ($rc -eq 0) { Write-Host ("BOTH PDFS VERIFIED  ({0}s)" -f [int]((Get-Date) - $started).TotalSeconds) -ForegroundColor Green }
else           { Write-Host ("EXPORT FAILED - do not deliver  ({0}s)" -f [int]((Get-Date) - $started).TotalSeconds) -ForegroundColor Red }
exit $rc
