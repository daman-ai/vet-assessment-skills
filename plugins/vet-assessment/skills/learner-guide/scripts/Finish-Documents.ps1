<#
    Finish-Documents.ps1 - Stage 7b builds the Contents; Stage 8 proves the
    delivered artefacts are the ones the gates judged, and believes the
    FILESYSTEM about what happened.

    The deliverables are the .docx and the .pptx. Nothing here writes any other
    rendition of them.

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
    reliably completes the TOC update and the save, and THEN dies at teardown
    with RPC_E_DISCONNECTED. An earlier copy of this script believed the
    exception and reported FAILED twice over work that had in fact completed -
    a correct 383-page result was thrown away on the strength of it. So the
    verdict is read from the filesystem: the artefact must still hash to what
    the 7c extract stamps, must still open as an OOXML package carrying its
    main part, and any number reported must be one the application actually
    returned. An artefact that passes all of that is a success whatever the
    exception said; one that fails any of it is a failure whatever the
    application said.

    WORD IS UNRELIABLE AGAINST ONEDRIVE-SYNCED PATHS. Documents.Open silently
    remaps FullName to the SharePoint URL and Save then fails "read-only" - while
    PowerShell can take an exclusive handle on the same file and doc.ReadOnly
    reports False. This script warns before it starts when a path looks synced,
    and reports the remap if Word does it anyway. Run it on local temp copies
    and copy the verified files back.

    THE TWO READS RUN CONCURRENTLY. Word and PowerPoint are different
    applications with no shared state, and each is driven from its own
    Start-Job process, so the deck is being measured while Word is still
    measuring the guide. The copy this replaces ran them serially.

    KILL RATHER THAN HANG. A job that overruns -TimeoutMinutes is stopped and
    the Office processes that started after this run began are killed. Only
    those: an operator's own open Word window predates the run and is left
    alone.

    TWO MODES, AND THE SPLIT IS THE WHOLE POINT.

    This script used to update the Contents at Stage 8 - AFTER the last gate.
    Updating a table of contents SAVES the document: every delivered .docx was
    therefore rewritten after the gate that judged it, and on the reference
    build the deck was rewritten 92 seconds after the last gate too. Nothing
    downstream could tell a Contents rebuild from a content edit, because the
    evidence is the same - a newer file.

      -UpdateContents   Stage 7b, AFTER placement and BEFORE the 7c re-gate.
                        Opens the guide read-WRITE, updates only the tables of
                        contents, saves, closes. The last write to the .docx.
                        7c then gates the document as it will ship.

      -VerifyDelivery   Stage 8. Opens both artefacts READ-ONLY, measures each,
                        and reports pages, words, tables of contents and slides
                        as the application returned them. It cannot mutate
                        either artefact, and it refuses to deliver one whose
                        bytes are not the bytes 7c judged (-ExtractDir, below).

    Exactly one mode per run. Running both in one pass is the arrangement this
    change exists to remove, so there is no default that does both.

    FRESHNESS IS PROVED, NOT ASSUMED. -VerifyDelivery requires -ExtractDir: the
    directory holding the 7c text extracts, whose SOURCE line carries the
    sha256 of the package bytes the gate read. Stage 8 recomputes that hash,
    before the open and again after it, and refuses by name when it differs. A
    missing -ExtractDir is a REFUSAL naming the parameter, never a silent skip -
    "the artefact I am delivering is the artefact the gate judged" is the claim
    Stage 8 exists to make.

    Usage
      Finish-Documents.ps1 -UpdateContents -Guide <path.docx> [-TimeoutMinutes 12]
      Finish-Documents.ps1 -VerifyDelivery -Guide <path.docx> -Deck <path.pptx> -ExtractDir <dir>
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
    #  Stage 8: both artefacts opened READ-ONLY, measured, and proved fresh.
    [switch] $VerifyDelivery,
    #  Where the 7c extracts live. Their SOURCE line carries the sha256 of the
    #  package the gate read; -VerifyDelivery refuses without it.
    [string] $ExtractDir,
    [int] $TimeoutMinutes = 12,
    [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Freshness - the artefact I am delivering IS the artefact the gate judged
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
            Problem = ("no extract in {0} names {1} on its SOURCE line ({2} extract(s) read). Stage 8 cannot claim the artefact it is delivering is the one 7c judged." -f $Dir, $leaf, $cands.Count) } }
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
            Problem = ("{0} has been rewritten since 7c read it: the extract {1} describes sha256 {2}, the file on disk is {3}. Stage 8 delivers the artefact the gates judged, or it delivers nothing." -f (Split-Path $Artefact -Leaf), (Split-Path $hit.Path -Leaf), $hit.Stamp.Hash.Substring(0, 12), $actual.Substring(0, 12)) }
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
$script:WordReadBody = {
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
        $d.Close(0)
        [pscustomobject]@{ Ok = $true; Pages = $pages; Words = $words; Toc = $tocCount; Remapped = $remapped; ReadOnly = $true }
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
        $pr.Close()
        [pscustomobject]@{ Ok = $true; Slides = $slides }
    }
    catch { [pscustomobject]@{ Ok = $false; Error = $_.Exception.Message } }
    finally { if ($pp) { try { $pp.Quit() } catch { } } }
}

# ---------------------------------------------------------------------------
# The verdict - from the filesystem
# ---------------------------------------------------------------------------

function Get-DeliveryVerdict {
    <#  Is this a deliverable artefact, whatever the application said?

        It must exist, carry bytes, and still open as an OOXML package with its
        main part present - which is what catches a half-written or torn file
        that every other check would report as delivered.

        Deliberately NOT a freshness rule. Stage 8 writes nothing, so a
        delivered artefact SHOULD predate this run; freshness is proved by
        sha256 against the 7c extract, not by a modification time, exactly as
        Test-ArtefactFresh argues.  #>
    param(
        [Parameter(Mandatory)][string] $Source,
        [Parameter(Mandatory)][string] $MainPart
    )
    $problems = New-Object System.Collections.Generic.List[string]
    $fi = Get-Item -LiteralPath $Source -ErrorAction SilentlyContinue
    $parts = 0
    if (-not $fi) { $problems.Add('the artefact does not exist') }
    else {
        if ($fi.Length -le 0) { $problems.Add('the artefact is zero bytes') }
        else {
            $pk = Test-OoxmlPackage -Path $Source -MainPart $MainPart
            if (-not $pk.Ok) { $problems.Add($pk.Problem) } else { $parts = $pk.Parts }
        }
    }
    [pscustomobject]@{
        Ok       = ($problems.Count -eq 0)
        Problems = @($problems)
        Parts    = $parts
        Bytes    = $(if ($fi) { $fi.Length } else { 0 })
        Written  = $(if ($fi) { $fi.LastWriteTime } else { $null })
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
        # ---- the delivery verdict reads the FILESYSTEM, not the application
        Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue
        function New-TinyPackage {
            param([string] $Path, [string] $Part = 'word/document.xml')
            $fs = [System.IO.File]::Open($Path, 'Create')
            try {
                $za = New-Object System.IO.Compression.ZipArchive($fs, 'Create')
                try {
                    $en = $za.CreateEntry($Part)
                    $sw = New-Object System.IO.StreamWriter($en.Open())
                    $sw.Write('<w:document/>'); $sw.Flush(); $sw.Dispose()
                }
                finally { $za.Dispose() }
            }
            finally { $fs.Dispose() }
        }
        $art = Join-Path $tmp 'artefact.docx'
        New-TinyPackage -Path $art
        $v = Get-DeliveryVerdict -Source $art -MainPart 'word/document.xml'
        if ($v.Ok -and $v.Bytes -gt 0 -and $v.Written) { Ok 'a delivered package is verified from the file: bytes, write time and main part' } else { Bad ("delivery verdict: " + ($v.Problems -join '; ')) }

        $v2 = Get-DeliveryVerdict -Source $art -MainPart 'ppt/presentation.xml'
        if (-not $v2.Ok -and ($v2.Problems -join ' ') -match 'ppt/presentation\.xml') { Ok 'and a package missing its main part FAILS, naming the part' } else { Bad 'wrong main part not detected' }

        $gone = Join-Path $tmp 'missing.docx'
        $v3 = Get-DeliveryVerdict -Source $gone -MainPart 'word/document.xml'
        if (-not $v3.Ok -and ($v3.Problems -join ' ') -match 'does not exist') { Ok 'an artefact that is not on disk FAILS rather than being reported delivered' } else { Bad 'missing artefact not detected' }

        $tornArt = Join-Path $tmp 'torn.docx'
        [System.IO.File]::WriteAllBytes($tornArt, ([System.IO.File]::ReadAllBytes($art))[0..40])
        $v4 = Get-DeliveryVerdict -Source $tornArt -MainPart 'word/document.xml'
        if (-not $v4.Ok) { Ok 'a half-written package FAILS rather than being reported delivered' } else { Bad 'a truncated package passed' }

        # ---- the watchdog stops an overrunning job and kills nothing it did not start
        $quick = Start-OfficeJob -Name 'quick' -Body { param($x) [pscustomobject]@{ Ok = $true; Pages = $x } } -ArgumentList @(7) -ProcessName 'NoSuchProcess_FinishSelfTest'
        $slow  = Start-OfficeJob -Name 'slow'  -Body { param($x) Start-Sleep -Seconds 60; [pscustomobject]@{ Ok = $true } } -ArgumentList @(0) -ProcessName 'NoSuchProcess_FinishSelfTest'
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $res = Wait-OfficeJob -Handles @($quick, $slow) -TimeoutSeconds 4
        if ($res['quick'].Ok -and $res['quick'].Pages -eq 7) { Ok 'the watchdog returns a finished job''s own result' } else { Bad 'quick job result lost' }
        if (-not $res['slow'].Ok -and $res['slow'].TimedOut -and $sw.Elapsed.TotalSeconds -lt 30) { Ok ("the watchdog stops an overrunning job rather than hanging ({0:N1}s)" -f $sw.Elapsed.TotalSeconds) } else { Bad ("slow job: " + ($res['slow'] | Out-String)) }
        if (@(Get-Job -Name 'slow' -ErrorAction SilentlyContinue).Count -eq 0) { Ok 'the stopped job is removed' } else { Bad 'stopped job left behind'; Get-Job -Name 'slow' | Remove-Job -Force }

        # ---- FRESHNESS: the artefact delivered IS the artefact 7c judged
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
        if (-not $f3.Ok -and $f3.Problem -match 'Deck\.pptx') { Ok 'an artefact no extract names is REFUSED by name, never delivered on trust' }
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

        # ---- exactly one mode, and -VerifyDelivery refuses without -ExtractDir
        $me = $PSCommandPath
        $null = & $me -Guide $zipOk -Deck $orphan 6>&1 2>&1
        if ($LASTEXITCODE -eq 2) { Ok 'no mode named: exit 2, and the banner says why there is no both-at-once mode' } else { Bad "no-mode exit $LASTEXITCODE" }
        $null = & $me -UpdateContents -VerifyDelivery -Guide $zipOk -Deck $orphan -ExtractDir $ex 6>&1 2>&1
        if ($LASTEXITCODE -eq 2) { Ok 'both modes named: exit 2 - updating the Contents SAVES, and Stage 8 may not write' } else { Bad "both-modes exit $LASTEXITCODE" }
        $out = & $me -VerifyDelivery -Guide $zipOk -Deck $orphan 6>&1 2>&1
        if ($LASTEXITCODE -eq 2 -and (($out | Out-String -Width 4096) -match 'ExtractDir')) { Ok '-VerifyDelivery with no -ExtractDir REFUSES exit 2 and names the parameter' } else { Bad "no-extractdir exit $LASTEXITCODE" }
        $out = & $me -VerifyDelivery -Guide $zipOk -Deck $orphan -ExtractDir $ex 6>&1 2>&1
        if ($LASTEXITCODE -eq 2 -and (($out | Out-String -Width 4096) -match 'STAGE 8 REFUSED')) { Ok 'and a stale artefact stops Stage 8 BEFORE Office is opened - nothing is opened' } else { Bad ("stale-refusal exit $LASTEXITCODE : " + (($out | Out-String -Width 4096).Trim())) }
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
        'Word COM: $script:WordReadBody - open READ-ONLY, ComputeStatistics, TablesOfContents.Count',
        'PowerPoint COM: $script:PowerPointBody - open READ-ONLY, Slides.Count'
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
if ($VerifyDelivery) { $modes += 'VerifyDelivery' }
if ($modes.Count -ne 1) {
    Write-Host ''
    Write-Host 'Finish-Documents: choose EXACTLY ONE of -UpdateContents or -VerifyDelivery.' -ForegroundColor Red
    Write-Host '  -UpdateContents  Stage 7b, after placement and BEFORE the 7c re-gate. Word updates the' -ForegroundColor DarkGray
    Write-Host '                   tables of contents and saves. This is the last write to the .docx.' -ForegroundColor DarkGray
    Write-Host '  -VerifyDelivery  Stage 8. Both artefacts opened READ-ONLY and measured, and refused if' -ForegroundColor DarkGray
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
        Write-Host '  Stage 8 will refuse any artefact whose sha256 differs from the one 7c stamps into its extract.' -ForegroundColor DarkGray
        exit 0
    }
    Write-Host '  FAILED - the Contents update is not a verified save:' -ForegroundColor Red
    foreach ($x in $problems) { Write-Host ("    X {0}" -f $x) -ForegroundColor Red }
    exit 1
}

# ---------------------------------------------------------------------------
# Stage 8 - READ-ONLY, and only what the gates judged
# ---------------------------------------------------------------------------

if (-not (Test-FinishPath -Path $Guide -What 'Guide')) { exit 2 }
if (-not (Test-FinishPath -Path $Deck  -What 'Deck'))  { exit 2 }
if (-not $ExtractDir) {
    Write-Host ''
    Write-Host 'Finish-Documents: -VerifyDelivery REFUSES without -ExtractDir.' -ForegroundColor Red
    Write-Host '  It names the directory holding the 7c text extracts. Their SOURCE line carries the sha256' -ForegroundColor DarkGray
    Write-Host '  of the package bytes the gate read, and Stage 8 recomputes it before it opens anything.' -ForegroundColor DarkGray
    Write-Host '  Without it this script can measure the files, but it cannot say the files it measured are' -ForegroundColor DarkGray
    Write-Host '  the documents the gates passed - which is the only claim Stage 8 exists to make.' -ForegroundColor DarkGray
    exit 2
}
if (-not (Test-Path -LiteralPath $ExtractDir)) {
    Write-Host ("Finish-Documents: -ExtractDir does not exist: {0}" -f $ExtractDir) -ForegroundColor Red
    exit 2
}
$Guide = (Resolve-Path -LiteralPath $Guide).Path
$Deck  = (Resolve-Path -LiteralPath $Deck).Path
$ExtractDir = (Resolve-Path -LiteralPath $ExtractDir).Path

foreach ($p in @($Guide, $Deck)) {
    if (Test-SyncedPath -Path $p) {
        Write-Host ("  WARNING: {0} looks OneDrive-synced. Word remaps a synced path to its SharePoint URL on open. Finish local temp copies and copy the verified files back." -f (Split-Path $p -Leaf)) -ForegroundColor Yellow
    }
}

Write-Host ''
Write-Host 'STAGE 8 FRESHNESS - the artefact delivered is the artefact the gates judged' -ForegroundColor Cyan
$stale = New-Object System.Collections.Generic.List[string]
foreach ($p in @($Guide, $Deck)) {
    $fr = Test-ArtefactFresh -Artefact $p -Dir $ExtractDir
    if ($fr.Ok) { Write-Host ("  OK  {0}  sha256 {1} matches {2}" -f (Split-Path $p -Leaf), $fr.Actual.Substring(0, 12), (Split-Path $fr.Extract -Leaf)) -ForegroundColor Green }
    else { Write-Host ("  X   {0}" -f $fr.Problem) -ForegroundColor Red; $stale.Add($fr.Problem) }
}
if ($stale.Count -gt 0) {
    Write-Host ''
    Write-Host 'STAGE 8 REFUSED - nothing was opened. Re-run the 7c band against the bytes on disk, then verify.' -ForegroundColor Red
    exit 2
}

Write-Host ''
Write-Host ("VERIFY DELIVERY - Word and PowerPoint READ-ONLY, in parallel, {0} minute watchdog" -f $TimeoutMinutes) -ForegroundColor Cyan
Write-Host ("  guide: {0}" -f $Guide) -ForegroundColor DarkGray
Write-Host ("  deck:  {0}" -f $Deck) -ForegroundColor DarkGray

$hw = Start-OfficeJob -Name 'word'       -Body $script:WordReadBody   -ArgumentList @($Guide) -ProcessName 'WINWORD'
$hp = Start-OfficeJob -Name 'powerpoint' -Body $script:PowerPointBody -ArgumentList @($Deck)  -ProcessName 'POWERPNT'
$res = Wait-OfficeJob -Handles @($hw, $hp) -TimeoutSeconds $timeout

$rc = 0

# ---- guide
Write-Host ''
Write-Host 'LEARNER GUIDE' -ForegroundColor Cyan
$g = $res['word']
if ($g.Ok) {
    Write-Host ("  Word: opened READ-ONLY, {0} pages, {1} words, {2} table(s) of contents present" -f $g.Pages, $g.Words, $g.Toc) -ForegroundColor Green
    if ([int]$g.Toc -eq 0) { Write-Host '  NOTE: no table of contents in this document - if one is expected, -UpdateContents did not run at 7b' -ForegroundColor Yellow }
    if ($g.Remapped) { Write-Host '  NOTE: Word remapped the path on open - this is a synced folder' -ForegroundColor Yellow }
}
else {
    Write-Host ("  Word reported: {0}" -f $g.Error) -ForegroundColor DarkYellow
    Write-Host '  asking the filesystem rather than believing the exception' -ForegroundColor DarkGray
}
$gv = Get-DeliveryVerdict -Source $Guide -MainPart 'word/document.xml'
if ($gv.Ok) {
    Write-Host ("  artefact verified: {0} MB, package intact ({1} parts), written {2}" -f [math]::Round($gv.Bytes / 1MB, 2), $gv.Parts, $gv.Written.ToString('HH:mm:ss')) -ForegroundColor Green
    if (-not $g.Ok) { Write-Host '  treating as SUCCESS on the evidence of the file - Word died at teardown after the work was done' -ForegroundColor Green }
    if (-not $g.Ok -or [int]$g.Pages -eq 0) { Write-Host '  NOTE: Word gave no page count, so the numbers above are the file, not the application' -ForegroundColor Yellow }
}
else {
    $rc = 1
    Write-Host '  FAILED - the guide is not a verified delivery artefact:' -ForegroundColor Red
    foreach ($x in $gv.Problems) { Write-Host ("    X {0}" -f $x) -ForegroundColor Red }
}

# ---- deck
Write-Host ''
Write-Host 'DELIVERY DECK' -ForegroundColor Cyan
$d = $res['powerpoint']
if ($d.Ok) {
    Write-Host ("  PowerPoint: opened READ-ONLY, {0} slides" -f $d.Slides) -ForegroundColor Green
}
else {
    Write-Host ("  PowerPoint reported: {0}" -f $d.Error) -ForegroundColor DarkYellow
    Write-Host '  asking the filesystem rather than believing the exception' -ForegroundColor DarkGray
}
$dv = Get-DeliveryVerdict -Source $Deck -MainPart 'ppt/presentation.xml'
if ($dv.Ok) {
    Write-Host ("  artefact verified: {0} MB, package intact ({1} parts), written {2}" -f [math]::Round($dv.Bytes / 1MB, 2), $dv.Parts, $dv.Written.ToString('HH:mm:ss')) -ForegroundColor Green
    if (-not $d.Ok) { Write-Host '  treating as SUCCESS on the evidence of the file' -ForegroundColor Green }
    if (-not $d.Ok -or [int]$d.Slides -eq 0) { Write-Host '  NOTE: PowerPoint gave no slide count, so the numbers above are the file, not the application' -ForegroundColor Yellow }
}
else {
    $rc = 1
    Write-Host '  FAILED - the deck is not a verified delivery artefact:' -ForegroundColor Red
    foreach ($x in $dv.Problems) { Write-Host ("    X {0}" -f $x) -ForegroundColor Red }
}

# ---- and nothing was mutated by reading
Write-Host ''
$moved = New-Object System.Collections.Generic.List[string]
foreach ($p in @($Guide, $Deck)) {
    $fr = Test-ArtefactFresh -Artefact $p -Dir $ExtractDir
    if (-not $fr.Ok) { $moved.Add(("{0} changed DURING the read - this path is supposed to be read-only" -f (Split-Path $p -Leaf))) }
}
if ($moved.Count -gt 0) {
    $rc = 1
    foreach ($x in $moved) { Write-Host ("  X {0}" -f $x) -ForegroundColor Red }
}
else { Write-Host '  both artefacts are byte-identical to the bytes the gates judged, after the read' -ForegroundColor Green }

Write-Host ''
if ($rc -eq 0) { Write-Host ("DELIVERY VERIFIED - both artefacts measured and byte-identical to the bytes the gates judged  ({0}s)" -f [int]((Get-Date) - $started).TotalSeconds) -ForegroundColor Green }
else           { Write-Host ("DELIVERY VERIFICATION FAILED - do not deliver  ({0}s)" -f [int]((Get-Date) - $started).TotalSeconds) -ForegroundColor Red }
exit $rc
