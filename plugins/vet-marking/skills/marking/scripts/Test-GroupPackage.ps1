<#
  Test-GroupPackage.ps1 — the blocking gate for a consolidated group package.
  Nothing is handed over until this passes.

  It reads the DELIVERED FOLDERS and the zip, not the build's log. What it is
  looking for is the small number of ways a package can be wrong in a way that
  matters to a person:

    GroupFolderPerLedger    one folder per group ledger, and no folder that no
                            ledger accounts for
    RecordInEveryGroup      each group folder holds its own marking record
    RecordListsItsGroup     that record names every student of the group and
                            nobody else — a record listing a learner from
                            another offer is filed against the wrong course
    StudentFolderPerRow     one folder per student on the ledger, named for them
    StudentInOneGroupOnly   no student ID appears under two group folders
    NoDuplicateDocument     no document appears twice in the package
    SarAndMarkedPresent     every student folder holds that student's SAR, and
                            their marked copy where the run produced one
    FeedbackWhereIssued     a standalone feedback sheet where the run issued one
    EveryDocumentAccounted  nothing in the package that the ledgers do not name
    DocumentsOpen           every .docx in the package opens
    ZipMatchesFolders       the zip holds exactly what the folders hold

  Usage:
    .\Test-GroupPackage.ps1 -GroupLedgerDir .\groups -Dir .\package
    .\Test-GroupPackage.ps1 -GroupLedgerDir .\groups -Dir .\package -Zip out.zip
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GroupLedgerDir,
    [Parameter(Mandatory)][string]$Dir,
    [string]$Zip
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-Docx.ps1')

$dirFull = (Resolve-Path -LiteralPath $Dir).Path
$checks  = New-Object System.Collections.ArrayList
function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Detail)
    [void]$checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; detail = $Detail })
}

$ledgers = @(Get-ChildItem -LiteralPath $GroupLedgerDir -Filter 'group_*.json' | Sort-Object Name)
if ($ledgers.Count -eq 0) { throw "No group_*.json in $GroupLedgerDir." }

$expected = @{}        # group label -> ledger
foreach ($lf in $ledgers) {
    $L = Get-Content -Raw -Encoding UTF8 -LiteralPath $lf.FullName | ConvertFrom-Json
    $label = $L.group.name
    if ($label -match '(?i)^(.*?)\s*-\s*(group\s*[0-9A-Za-z]+)\s*$') {
        $label = "{0} - {1}" -f (Get-Culture).TextInfo.ToTitleCase($Matches[2].ToLower()), $Matches[1]
    }
    $label = ($label -replace '[\\/:*?"<>|]', '-').Trim()
    $expected[$label] = $L
}

$onDisk = @(Get-ChildItem -LiteralPath $dirFull -Directory | ForEach-Object { $_.Name })

# ------------------------------------------------- 1. the group folders -----
$probs = @()
foreach ($k in $expected.Keys) { if ($onDisk -notcontains $k) { $probs += "missing group folder '$k'" } }
foreach ($d in $onDisk)        { if (-not $expected.ContainsKey($d)) { $probs += "folder '$d' matches no group ledger" } }
Add-Check 'GroupFolderPerLedger' ($probs.Count -eq 0) `
    $(if ($probs.Count) { ($probs | Select-Object -First 4) -join ' · ' } else { "$($expected.Count) group folder(s), one per ledger" })

# ------------------------------- 2-8. per group, per student ----------------
$recProbs = @(); $listProbs = @(); $folderProbs = @(); $sarProbs = @(); $fbProbs = @(); $extraProbs = @()
$seenStudent = @{}; $crossProbs = @()
$fileCount = @{}
$studentFolders = 0

foreach ($label in ($expected.Keys | Sort-Object)) {
    $L = $expected[$label]
    $gDir = Join-Path $dirFull $label
    if (-not (Test-Path -LiteralPath $gDir)) { continue }

    # ---- the record ------------------------------------------------------
    $rec = Join-Path $gDir $L.amrrFile
    if (-not (Test-Path -LiteralPath $rec)) {
        $recProbs += "$label : $($L.amrrFile) missing"
    } else {
        $fileCount[$L.amrrFile] = 1 + ($(if ($fileCount.ContainsKey($L.amrrFile)) { $fileCount[$L.amrrFile] } else { 0 }))
        # the record must name this group's students and nobody else
        $txt = (Get-DocxText -Path $rec) -replace '\s+', ' '
        foreach ($s in @($L.students)) {
            if ($txt -notmatch [regex]::Escape($s.studentId)) { $listProbs += "$label : record does not list $($s.studentId) $($s.fullName)" }
        }
        foreach ($other in ($expected.Keys | Where-Object { $_ -ne $label })) {
            foreach ($os in @($expected[$other].students)) {
                if ($txt -match [regex]::Escape($os.studentId)) { $listProbs += "$label : record lists $($os.studentId), who is in '$other'" }
            }
        }
    }

    # ---- the student folders ---------------------------------------------
    $subs = @(Get-ChildItem -LiteralPath $gDir -Directory | ForEach-Object { $_.Name })
    foreach ($s in @($L.students)) {
        $safeName = ($s.fullName -replace '[\\/:*?"<>|]', ' ') -replace '\s+', ' '
        $want = "{0:00} {1} ({2})" -f [int]$s.serial, $safeName.Trim(), $s.studentId
        if ($subs -notcontains $want) { $folderProbs += "$label : no folder '$want'"; continue }
        $studentFolders++

        if ($seenStudent.ContainsKey($s.studentId)) {
            $crossProbs += "$($s.studentId) is under '$label' and under '$($seenStudent[$s.studentId])'"
        }
        $seenStudent[$s.studentId] = $label

        $sDir  = Join-Path $gDir $want
        $files = @(Get-ChildItem -LiteralPath $sDir -File | ForEach-Object { $_.Name })
        foreach ($f in $files) { $fileCount[$f] = 1 + ($(if ($fileCount.ContainsKey($f)) { $fileCount[$f] } else { 0 })) }

        if ($files -notcontains $s.sarFile) { $sarProbs += "$($s.studentId): SAR $($s.sarFile) not in their folder" }
        foreach ($mc in @($s.markedCopyFiles)) {
            if ($mc -and ($files -notcontains $mc)) { $sarProbs += "$($s.studentId): marked copy $mc not in their folder" }
        }
        if ($s.needsFeedbackSheet -and ($files -notcontains $s.feedbackFile)) {
            $fbProbs += "$($s.studentId): feedback sheet $($s.feedbackFile) not in their folder"
        }

        # every file in the folder is one this student's ledger row names
        $named = @($s.sarFile) + @($s.markedCopyFiles)
        if ($s.needsFeedbackSheet) { $named += $s.feedbackFile; $named += ($s.feedbackFile -replace '\.docx$', '.pdf') }
        foreach ($f in $files) {
            if ($named -notcontains $f) { $extraProbs += "$($s.studentId): '$f' is not a document this student's record names" }
        }
    }
    foreach ($sub in $subs) {
        $known = @($L.students | ForEach-Object { "{0:00} {1} ({2})" -f [int]$_.serial, ((($_.fullName -replace '[\\/:*?"<>|]', ' ') -replace '\s+',' ').Trim()), $_.studentId })
        if ($known -notcontains $sub) { $extraProbs += "$label : folder '$sub' matches no student on the ledger" }
    }
}

Add-Check 'RecordInEveryGroup'   ($recProbs.Count    -eq 0) $(if ($recProbs.Count)    { ($recProbs    | Select-Object -First 4) -join ' · ' } else { 'every group folder holds its own marking record' })
Add-Check 'RecordListsItsGroup'  ($listProbs.Count   -eq 0) $(if ($listProbs.Count)   { ($listProbs   | Select-Object -First 4) -join ' · ' } else { 'each record names every student of its group and nobody else' })
Add-Check 'StudentFolderPerRow'  ($folderProbs.Count -eq 0) $(if ($folderProbs.Count) { ($folderProbs | Select-Object -First 4) -join ' · ' } else { "$studentFolders student folder(s), one per ledger row" })
Add-Check 'StudentInOneGroupOnly' ($crossProbs.Count -eq 0) $(if ($crossProbs.Count)  { ($crossProbs  | Select-Object -First 4) -join ' · ' } else { "$($seenStudent.Count) student(s), each under exactly one group" })
Add-Check 'SarAndMarkedPresent'  ($sarProbs.Count    -eq 0) $(if ($sarProbs.Count)    { ($sarProbs    | Select-Object -First 4) -join ' · ' } else { 'every student folder holds the SAR and the marked copy of the student it is named for' })
Add-Check 'FeedbackWhereIssued'  ($fbProbs.Count     -eq 0) $(if ($fbProbs.Count)     { ($fbProbs     | Select-Object -First 4) -join ' · ' } else { 'a standalone feedback sheet wherever the run issued one' })
Add-Check 'EveryDocumentAccounted' ($extraProbs.Count -eq 0) $(if ($extraProbs.Count) { ($extraProbs  | Select-Object -First 4) -join ' · ' } else { 'nothing in the package that the group ledgers do not name' })

# --------------------------------------------- 9. no document copied twice --
$dupes = @($fileCount.Keys | Where-Object { $fileCount[$_] -gt 1 })
Add-Check 'NoDuplicateDocument' ($dupes.Count -eq 0) `
    $(if ($dupes.Count) { "appears more than once: " + (($dupes | Select-Object -First 4) -join ', ') } else { "$($fileCount.Count) document(s), each filed once" })

# ------------------------------------------------------ 10. they open ------
$openProbs = @()
foreach ($f in (Get-ChildItem -LiteralPath $dirFull -Recurse -File -Filter '*.docx')) {
    try { $p = Open-Docx -Path $f.FullName; Close-Docx $p } catch { $openProbs += "$($f.Name): $($_.Exception.Message)" }
}
$docxCount = @(Get-ChildItem -LiteralPath $dirFull -Recurse -File -Filter '*.docx').Count
Add-Check 'DocumentsOpen' ($openProbs.Count -eq 0) `
    $(if ($openProbs.Count) { ($openProbs | Select-Object -First 3) -join ' · ' } else { "all $docxCount document(s) open" })

# --------------------------------------------------------- 11. the zip -----
if ($Zip) {
    $zipProbs = @()
    if (-not (Test-Path -LiteralPath $Zip)) {
        $zipProbs += "$Zip does not exist"
    } else {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $za = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Zip).Path)
        try {
            $inZip = @($za.Entries | Where-Object { $_.Name -ne '' } | ForEach-Object { $_.FullName.Replace('\', '/') })
            # Same string on both sides — see Build-GroupPackage.ps1. Enumerating
            # with Get-ChildItem (long form) and stripping $dirFull (possibly 8.3
            # short form) leaves the tail of the package directory's own name on
            # every expected path, and the comparison then agrees with a zip that
            # is wrong in exactly the same way. GetFiles keeps both sides in the
            # form the root was given in.
            $relRoot = $dirFull.TrimEnd('\')
            $onDiskRel = @([System.IO.Directory]::GetFiles(
                    $relRoot, '*', [System.IO.SearchOption]::AllDirectories) |
                ForEach-Object { $_.Substring($relRoot.Length).TrimStart('\', '/').Replace('\', '/') })
            foreach ($f in $onDiskRel) { if ($inZip -notcontains $f) { $zipProbs += "not in the zip: $f" } }
            foreach ($f in $inZip)     { if ($onDiskRel -notcontains $f) { $zipProbs += "in the zip but not in the folders: $f" } }
            # OPC and the ZIP spec both require forward slashes; a backslash
            # entry opens in Word and nowhere else.
            $back = @($za.Entries | Where-Object { $_.FullName.Contains('\') }).Count
            if ($back -gt 0) { $zipProbs += "$back zip entry name(s) use a backslash separator" }
        } finally { $za.Dispose() }
    }
    Add-Check 'ZipMatchesFolders' ($zipProbs.Count -eq 0) `
        $(if ($zipProbs.Count) { ($zipProbs | Select-Object -First 4) -join ' · ' } else { "the zip holds exactly the $($onDiskRel.Count) file(s) in the folders" })
}

# ------------------------------------------------------------- report -------
Write-Output ''
Write-Output ("GROUP PACKAGE GATE — {0}" -f $dirFull)
Write-Output ''
foreach ($c in $checks) {
    $tag = if ($c.ok) { 'PASS' } else { 'FAIL' }
    Write-Output ("  {0} {1,-24} {2}" -f $tag, $c.name, $c.detail)
}
$failed = @($checks | Where-Object { -not $_.ok })
Write-Output ''
if ($failed.Count) {
    Write-Output ("GATE FAILED — {0} of {1} check(s) failed. Nothing here is deliverable." -f $failed.Count, $checks.Count)
    exit 1
}
Write-Output ("GATE PASSED — {0} check(s). This package is ready to hand over." -f $checks.Count)
