<#
  Build-GroupPackage.ps1 — lay the marking documents out the way they are
  filed and handed back: one folder per WiseNet course-offer group, the group's
  Assessment Marking and Results Record at the top of it, and inside that one
  folder per student holding everything that belongs to that student.

      <OutDir>/
        Group 1 - Certificate III in Solid Plastering/
          AMLC_CPCCWHS2001_Group_1_06092026.docx
          01 Mohammad Alam (ADL3000410)/
            SAR_Mohammad_ADL3000410_CPCCWHS2001_NYC.docx
            MARKED_Mohammad_ADL3000410_CPCCWHS2001_uat1-uat2_05092026.docx
          02 Md Sadat Amin Rahat (ADL3000361)/
            ...

  WHAT IT WILL NOT DO. It copies; it never renames a document and never edits
  one. Every file is named on the group ledger, so nothing is matched by
  pattern — a pattern that matched two students would file one learner's marked
  work in another learner's folder, and the folder is the thing a student is
  handed. A named file that is not on disk stops the build.

  A student lands in exactly one group folder, because the merge step has
  already refused any roster where that was not true.

  Usage:
    .\Build-GroupPackage.ps1 -GroupLedgerDir .\groups -RecordDir .\records -OutDir .\package
    .\Build-GroupPackage.ps1 -GroupLedgerDir .\groups -RecordDir .\records -OutDir .\package -Zip out.zip
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GroupLedgerDir,
    [Parameter(Mandatory)][string]$RecordDir,
    [Parameter(Mandatory)][string]$OutDir,
    [string[]]$SourceDir,
    [string]$Zip,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

$ledgers = @(Get-ChildItem -LiteralPath $GroupLedgerDir -Filter 'group_*.json' | Sort-Object Name)
if ($ledgers.Count -eq 0) { throw "No group_*.json in $GroupLedgerDir. Run Merge-MarkingLedgers.ps1 first." }

# Where the run outputs live. Each student carries the folder their own run was
# written to; -SourceDir adds any others (a folder that has since been moved).
$roots = New-Object System.Collections.ArrayList
foreach ($d in @($SourceDir)) { if ($d -and (Test-Path -LiteralPath $d)) { [void]$roots.Add((Resolve-Path -LiteralPath $d).Path) } }

function Find-Doc {
    param([string]$Name, [string[]]$Prefer)
    foreach ($r in (@($Prefer) + @($roots.ToArray()))) {
        if (-not $r) { continue }
        $p = Join-Path $r $Name
        if (Test-Path -LiteralPath $p) { return (Resolve-Path -LiteralPath $p).Path }
    }
    $null
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$outFull = (Resolve-Path -LiteralPath $OutDir).Path

# ---- MAX_PATH, checked before anything is copied ---------------------------
#
# Three nested names — the package root, 'Group 1 - Certificate III in Solid
# Plastering', '01 Mohammad Alam (ADL3000410)' — plus a document name that
# already carries the student, the unit and the date, and Windows' 260
# character limit is closer than it looks. Copy-Item reports it as 'Could not
# find a part of the path', which reads like a missing folder and sends you
# looking in the wrong place. So it is measured up front and named for what it
# is, while the fix is still just a shorter -OutDir.
$tooLong = @()
foreach ($lf in $ledgers) {
    $peek = Get-Content -Raw -Encoding UTF8 -LiteralPath $lf.FullName | ConvertFrom-Json
    $lbl = $peek.group.name
    if ($lbl -match '(?i)^(.*?)\s*-\s*(group\s*[0-9A-Za-z]+)\s*$') {
        $lbl = "{0} - {1}" -f (Get-Culture).TextInfo.ToTitleCase($Matches[2].ToLower()), $Matches[1]
    }
    $lbl = ($lbl -replace '[\\/:*?"<>|]', '-').Trim()
    foreach ($s in @($peek.students)) {
        $nm = (($s.fullName -replace '[\\/:*?"<>|]', ' ') -replace '\s+', ' ').Trim()
        $folder = "{0:00} {1} ({2})" -f [int]$s.serial, $nm, $s.studentId
        $docs = @($s.sarFile) + @($s.markedCopyFiles)
        if ($s.needsFeedbackSheet) { $docs += $s.feedbackFile }
        foreach ($d in $docs) {
            if (-not $d) { continue }
            $len = $outFull.Length + 1 + $lbl.Length + 1 + $folder.Length + 1 + $d.Length
            if ($len -gt 259) { $tooLong += ("{0} character(s): {1}\{2}\{3}" -f $len, $lbl, $folder, $d) }
        }
    }
}
if ($tooLong.Count) {
    Write-Output ''
    Write-Output "PACKAGE NOT BUILT — $($tooLong.Count) path(s) would exceed the 260 character Windows limit."
    Write-Output ("  package root is {0} character(s): {1}" -f $outFull.Length, $outFull)
    foreach ($t in ($tooLong | Select-Object -First 4)) { Write-Output "  * $t" }
    Write-Output ''
    throw 'Choose a shorter -OutDir. Nothing was copied.'
}

$missing  = New-Object System.Collections.ArrayList
$placed   = @{}          # studentId -> group folder, to prove nobody is filed twice
$manifest = New-Object System.Collections.ArrayList
$folders  = 0
$copies   = 0

foreach ($lf in $ledgers) {
    $L = Get-Content -Raw -Encoding UTF8 -LiteralPath $lf.FullName | ConvertFrom-Json

    # 'Certificate III in Solid Plastering - Group 2' reads better on a folder
    # as 'Group 2 - Certificate III in Solid Plastering': the part that tells
    # the groups apart comes first, and the folders sort in group order.
    $label = $L.group.name
    if ($label -match '(?i)^(.*?)\s*-\s*(group\s*[0-9A-Za-z]+)\s*$') {
        $label = "{0} - {1}" -f (Get-Culture).TextInfo.ToTitleCase($Matches[2].ToLower()), $Matches[1]
    }
    $label = ($label -replace '[\\/:*?"<>|]', '-').Trim()
    $groupDir = Join-Path $OutDir $label
    New-Item -ItemType Directory -Force -Path $groupDir | Out-Null
    $folders++

    # ---- the group's own record ------------------------------------------
    $rec = Join-Path $RecordDir $L.amrrFile
    if (-not (Test-Path -LiteralPath $rec)) {
        [void]$missing.Add("$($L.group.name): marking record $($L.amrrFile) is not in $RecordDir")
    } else {
        Copy-Item -LiteralPath $rec -Destination (Join-Path $groupDir $L.amrrFile) -Force
        $copies++
    }

    # ---- one folder per student ------------------------------------------
    foreach ($s in @($L.students)) {
        if ($placed.ContainsKey($s.studentId)) {
            [void]$missing.Add("$($s.studentId) $($s.fullName) would be filed in '$label' and is already in '$($placed[$s.studentId])'. A student belongs to one group.")
            continue
        }
        $placed[$s.studentId] = $label

        $safeName = ($s.fullName -replace '[\\/:*?"<>|]', ' ') -replace '\s+', ' '
        $stuDir = Join-Path $groupDir ("{0:00} {1} ({2})" -f [int]$s.serial, $safeName.Trim(), $s.studentId)
        New-Item -ItemType Directory -Force -Path $stuDir | Out-Null

        $prefer = @()
        if ($s.PSObject.Properties.Name -contains 'sourceDir' -and $s.sourceDir) { $prefer += $s.sourceDir }

        $want = New-Object System.Collections.ArrayList
        [void]$want.Add(@{ kind = 'SAR'; name = $s.sarFile; required = $true })
        foreach ($mc in @($s.markedCopyFiles)) {
            if ($mc) { [void]$want.Add(@{ kind = 'MARKED'; name = $mc; required = $true }) }
        }
        if ($s.needsFeedbackSheet) {
            [void]$want.Add(@{ kind = 'FEEDBACK'; name = $s.feedbackFile; required = $true })
            [void]$want.Add(@{ kind = 'FEEDBACK'; name = ($s.feedbackFile -replace '\.docx$', '.pdf'); required = $false })
        }

        foreach ($w in $want) {
            $src = Find-Doc -Name $w.name -Prefer $prefer
            if (-not $src) {
                if ($w.required) { [void]$missing.Add("$($s.studentId) $($s.fullName): $($w.kind) $($w.name) not found") }
                continue
            }
            Copy-Item -LiteralPath $src -Destination (Join-Path $stuDir $w.name) -Force
            $copies++
            [void]$manifest.Add([pscustomobject]@{
                group = $label; serial = [int]$s.serial; studentId = $s.studentId
                student = $s.fullName; overall = $s.overall; marked = $s.markingDateText
                kind = $w.kind; file = $w.name
            })
        }
    }

    if (-not $Quiet) {
        Write-Output ("  {0,-46} {1,2} student folder(s)" -f $label, @($L.students).Count)
    }
}

if ($missing.Count) {
    Write-Output ''
    Write-Output "PACKAGE INCOMPLETE — $($missing.Count) problem(s):"
    foreach ($m in $missing) { Write-Output "  * $m" }
    Write-Output ''
    throw 'The package is not deliverable. Nothing was zipped.'
}

# A manifest, so the package can be checked without opening a document.
$mf = Join-Path $OutDir '_manifest.csv'
$manifest | Sort-Object group, serial, kind | Export-Csv -LiteralPath $mf -NoTypeInformation -Encoding UTF8

if ($Zip) {
    # Written entry by entry rather than with CreateFromDirectory, which on
    # .NET Framework puts a BACKSLASH in every entry name. The ZIP spec
    # (APPNOTE 4.4.17.1) says forward slash, and a backslash archive unpacks as
    # one flat pile of files with the folder names glued on — which is exactly
    # the structure this script exists to produce. Windows Explorer hides the
    # problem; macOS, Linux and Python do not.
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path -LiteralPath $Zip) { Remove-Item -LiteralPath $Zip -Force }

    $fs = [System.IO.File]::Open($Zip, [System.IO.FileMode]::CreateNew)
    $za = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        # ENUMERATE AND STRIP WITH THE SAME STRING. $env:TEMP and anything under
        # it arrive in 8.3 short form when the account name is over eight
        # characters, while Get-ChildItem reports FullName in long form. The
        # substring then cuts one character short and the tail of the package
        # directory's own name becomes a folder inside the zip — every path
        # under 'e/' for a package built in '...\package'. GetFiles builds its
        # results from the root string it was handed, so both sides match.
        $zipRoot = $outFull.TrimEnd('\')
        foreach ($full in ([System.IO.Directory]::GetFiles(
                $zipRoot, '*', [System.IO.SearchOption]::AllDirectories) | Sort-Object)) {
            $rel = $full.Substring($zipRoot.Length).TrimStart('\', '/').Replace('\', '/')
            $entry = $za.CreateEntry($rel, [System.IO.Compression.CompressionLevel]::Optimal)
            $in  = [System.IO.File]::OpenRead($full)
            $out = $entry.Open()
            try { $in.CopyTo($out) } finally { $out.Close(); $in.Close() }
        }
    } finally { $za.Dispose(); $fs.Dispose() }
}

if (-not $Quiet) {
    Write-Output ''
    Write-Output ("{0} group folder(s), {1} student folder(s), {2} document(s) copied." -f $folders, $placed.Count, $copies)
    if ($Zip) { Write-Output ("Zipped: {0}" -f $Zip) }
    Write-Output 'Nothing is delivered until Test-GroupPackage.ps1 passes on this package.'
}
