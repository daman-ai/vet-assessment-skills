<#
  Build-InvoiceRequest.ps1 — the accounts invoice request for a marking run.

  RTO ruling, 13 October 2026: attempt 1 is the first marking and attempts 2 and
  3 (Resubmissions 1 and 2) are free. Attempt 4 (Resubmission 3) and every
  attempt after it carries a $150 marking charge, and the student is told so in
  red on their feedback (Build-AttemptChargeNotice in Lib-Text.ps1). This
  document tells ACCOUNTS who to invoice. It is laid out like the class record
  (AMLC) — the RTO's own AMRR template, its header and footer untouched — but it
  lists ONLY the students to be charged, with the unit details above them.

  WHO IS LISTED is decided by the same function that prints the red line on the
  student's feedback, so accounts can never be told to invoice a student who
  was not told about the charge, or the reverse. A withheld result (RW) on a
  chargeable attempt IS listed (RTO instruction, 13 October 2026): the work was
  still marked.

  ACCOUNTS RECEIVE A PDF ONLY (RTO instruction, 13 October 2026). The Word file
  is built in a temporary folder, printed to PDF through Word, and discarded.
  Serves every registered RTO profile - ACI Construction, ACI Culinary and MVC -
  from that RTO's own AMRR template and palette.

  Where no student in the ledgers is chargeable, nothing is written and the
  script says so — an empty invoice request is a document someone would file.

  Usage:
    .\Build-InvoiceRequest.ps1 -Ledger resolved.json -OutDir out
    .\Build-InvoiceRequest.ps1 -Ledger groups\group_Group_1.json,groups\group_Group_2.json -OutDir package
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string[]]$Ledger,
    [Parameter(Mandatory)][string]$OutDir,
    [string]$RtoProfile
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
. (Join-Path $PSScriptRoot 'Lib-Docx.ps1')
. (Join-Path $PSScriptRoot 'Lib-Text.ps1')
$AssetRoot = Join-Path $PSScriptRoot '..\assets'

# ------------------------------------------------------------ the ledgers ---
$ledgers = @()
foreach ($p in $Ledger) {
    foreach ($one in ($p -split ',')) {
        $one = $one.Trim(); if (-not $one) { continue }
        $L = Get-Content -Raw -Encoding UTF8 -LiteralPath $one | ConvertFrom-Json
        if (-not $L.dates) { throw "$one is not a resolved ledger. Run Resolve-MarkingLedger.ps1 first." }
        $ledgers += $L
    }
}
if (-not $ledgers.Count) { throw 'No ledger given.' }
$first = $ledgers[0]
foreach ($L in $ledgers) {
    if ($L.unit.code -ne $first.unit.code) { throw "The ledgers are for different units ($($first.unit.code), $($L.unit.code)). One invoice request covers one unit." }
    if ($L.rto -ne $first.rto) { throw "The ledgers are for different RTOs ($($first.rto), $($L.rto))." }
}

if (-not $RtoProfile) { $RtoProfile = Join-Path $AssetRoot ("rto.{0}.json" -f $first.rto) }
$Rto = Get-Content -Raw -Encoding UTF8 -LiteralPath $RtoProfile | ConvertFrom-Json

# ------------------------------------------------------- who is charged -----
$fee = '$150'
if ($Rto.PSObject.Properties.Name -contains 'charges' -and $Rto.charges -and $Rto.charges.PSObject.Properties.Name -contains 'markingFee' -and $Rto.charges.markingFee) { $fee = "$($Rto.charges.markingFee)" }
$feeNum = [decimal](($fee -replace '[^0-9.]', ''))

$rows = @(); $seen = @{}
foreach ($L in $ledgers) {
    $groupName = if ($L.PSObject.Properties.Name -contains 'group' -and $L.group) { "$($L.group.name)" } else { '' }
    foreach ($s in @($L.students)) {
        if (-not (Build-AttemptChargeNotice -Student $s -Rto $Rto)) { continue }
        if ($seen.ContainsKey($s.studentId)) { throw "$($s.studentId) $($s.fullName) appears in two ledgers. One student, one charge." }
        $seen[$s.studentId] = $true
        $fbDate = if ($s.PSObject.Properties.Name -contains 'markingDateText' -and $s.markingDateText) { $s.markingDateText } else { $L.dates.feedbackGivenText }
        $rows += [pscustomobject]@{
            name = $s.fullName; id = $s.studentId; group = $groupName
            attempt = [int]$s.attempt; resub = [int]$s.attempt - 1
            result = $(switch ("$($s.overall)") { 'C' { 'C' } 'RW' { 'RW' } default { 'NYC' } })
            marked = $fbDate; amount = $fee
        }
    }
}
if (-not $rows.Count) {
    Write-Output ("No student in these ledgers is on a chargeable attempt 4 (Resubmission 3) for {0}. No invoice request is needed." -f $first.unit.code)
    return
}
$rows = @($rows | Sort-Object group, name)

# ------------------------------------------------------------- document -----
$tpl = Join-Path $AssetRoot $Rto.templates.amrr.file
$pkg = Open-Docx -Path $tpl
try {
    $doc = $pkg.Xml; $ns = $pkg.Ns; $body = $pkg.Body
    # Keep the template's section (page size, orientation, header and footer
    # references); replace everything else in the body.
    $sect = $body.SelectSingleNode('w:sectPr', $ns)
    foreach ($n in @($body.ChildNodes)) { if ($n -ne $sect) { [void]$body.RemoveChild($n) } }
    $add = { param($node) [void]$body.InsertBefore($node, $sect) }

    $accent = '234B8C'; $tint = 'EAF0F8'
    if ($Rto.styling -and $Rto.styling.PSObject.Properties.Name -contains 'feedbackAccentColor' -and $Rto.styling.feedbackAccentColor) { $accent = "$($Rto.styling.feedbackAccentColor)" }
    $width = 14822
    if ($Rto.templates.amrr.PSObject.Properties.Name -contains 'tableWidthDxa' -and $Rto.templates.amrr.tableWidthDxa) { $width = [int]$Rto.templates.amrr.tableWidthDxa }
    $P = { param([string]$t, [switch]$B, [string]$C = '000000', [string]$A) $x = @{ Doc = $doc; Text = $t; Color = $C; SizeHalfPoints = 20; SpaceBefore = 20; SpaceAfter = 20 }; if ($B) { $x.Bold = $true }; if ($A) { $x.Align = $A }; New-TextParagraph @x }

    & $add (New-TextParagraph -Doc $doc -Text 'INVOICE REQUEST — RESUBMISSION MARKING CHARGE' -Color $accent -Bold -SizeHalfPoints 32 -SpaceBefore 0 -SpaceAfter 60)
    & $add (New-TextParagraph -Doc $doc -Text ("For Accounts: raise an invoice of {0} for each student listed below. Each is on attempt 4 (Resubmission 3) of this unit, which is chargeable." -f $fee) -SizeHalfPoints 22 -SpaceBefore 0 -SpaceAfter 160)

    # unit details
    $wL = 3600; $wV = $width - $wL
    $t1 = New-SheetTable -Doc $doc -Widths @($wL, $wV)
    $groups = @($rows | ForEach-Object { $_.group } | Where-Object { $_ } | Sort-Object -Unique)
    $detail = [ordered]@{
        'RTO'                     = ("{0} T/A {1} · RTO {2}" -f $Rto.rto.legalName, $Rto.rto.tradingName, $Rto.rto.rtoCode)
        'Qualification'           = ("{0} {1}" -f $first.qualification.code, $first.qualification.title)
        'Unit of competency'      = ("{0} {1}" -f $first.unit.code, $first.unit.title)
        'Course offer / group'    = $(if ($groups.Count) { $groups -join '; ' } else { 'As listed below' })
        'Trainer / assessor'      = "$($first.assessor)"
        'Marking date'            = "$($first.dates.markingDateText)"
        'Charge'                  = ("{0} per student, charged once, for assessment marking of attempt 4 (Resubmission 3). Later attempts are not charged again" -f $fee)
    }
    foreach ($k in $detail.Keys) {
        Add-SheetRow -Doc $doc -Table $t1 -Cells @(
            @{ Width = $wL; Fill = $tint; Paragraphs = @(& $P $k -B) },
            @{ Width = $wV; Paragraphs = @(& $P $detail[$k]) }
        ) | Out-Null
    }
    & $add $t1
    & $add (New-TextParagraph -Doc $doc -Text 'Students to be charged' -Color $accent -Bold -SizeHalfPoints 24 -SpaceBefore 200 -SpaceAfter 80)

    # students
    $cols = @(
        @{ h = 'No.';            w = 700 },
        @{ h = 'Student name';   w = 3300 },
        @{ h = 'Student ID';     w = 1700 },
        @{ h = 'Course offer / group'; w = 3200 },
        @{ h = 'Attempt';        w = 1000 },
        @{ h = 'Resubmission';   w = 1300 },
        @{ h = 'Result';         w = 900 },
        @{ h = 'Marked on';      w = 1700 },
        @{ h = 'Amount';         w = 1022 }
    )
    $sum = ($cols | ForEach-Object { $_.w } | Measure-Object -Sum).Sum
    if ($sum -ne $width) { $cols[3].w += ($width - $sum) }
    $t2 = New-SheetTable -Doc $doc -Widths @($cols | ForEach-Object { [int]$_.w })
    Add-SheetRow -Doc $doc -Table $t2 -Header -Cells @($cols | ForEach-Object { @{ Width = $_.w; Fill = $accent; Paragraphs = @(& $P $_.h -B -C 'FFFFFF') } }) | Out-Null
    $i = 0
    foreach ($r in $rows) {
        $i++
        $vals = @("$i", $r.name, $r.id, $(if ($r.group) { $r.group } else { '—' }), (Get-Ordinal $r.attempt), "$($r.resub)", $r.result, $r.marked, $r.amount)
        $cells = @(); for ($c = 0; $c -lt $cols.Count; $c++) { $cells += @{ Width = $cols[$c].w; Paragraphs = @(& $P $vals[$c]) } }
        Add-SheetRow -Doc $doc -Table $t2 -Cells $cells | Out-Null
    }
    $lead = ($cols[0..7] | ForEach-Object { $_.w } | Measure-Object -Sum).Sum
    $total = '$' + ('{0:N2}' -f ($feeNum * $rows.Count))
    Add-SheetRow -Doc $doc -Table $t2 -Cells @(
        @{ Width = $lead; Span = 8; Fill = $tint; Paragraphs = @(& $P ("Total to invoice — {0} student(s)" -f $rows.Count) -B -A 'right') },
        @{ Width = $cols[8].w; Fill = $tint; Paragraphs = @(& $P $total -B) }
    ) | Out-Null
    & $add $t2

    & $add (New-TextParagraph -Doc $doc -Text 'Attempt 1 is the first marking. Attempts 2 and 3 (Resubmissions 1 and 2) are not charged, and no student is charged more than once. Each student listed was told of the charge in red on their feedback. RW is a result withheld for a missing prerequisite: the work was still marked, so the charge applies.' -SizeHalfPoints 20 -SpaceBefore 160 -SpaceAfter 40)
    & $add (New-TextParagraph -Doc $doc -Text ("Prepared by {0}, trainer / assessor, on {1}." -f $first.assessor, $first.dates.markingDateText) -SizeHalfPoints 20 -SpaceBefore 40 -SpaceAfter 0)

    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    $stem = "INVOICE_{0}_{1}" -f $first.unit.code.ToUpper(), ($first.dates.markingDateText -replace '[^0-9]', '')
    # Beside the output, not under $env:TEMP: that arrives as an 8.3 short path
    # here (C:\Users\ACI-AD~1\...) and Word opening a file there can sit on an
    # invisible dialog for ever.
    $outFull = (Get-Item -LiteralPath $OutDir).FullName
    $tmpDir = Join-Path $outFull (".invoice_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
    $docx = Join-Path $tmpDir "$stem.docx"
    [void](Save-Docx -Package $pkg -Destination $docx)
} catch { Close-Docx $pkg; throw }

# ----------------------------------------------------------------- PDF ------
# Accounts receive the PDF alone. Word prints it, so the PDF is what the
# document actually looks like; the Word file never leaves the temp folder.
$name = "$stem.pdf"
$dest = Join-Path $outFull $name
$wd = New-Object -ComObject Word.Application; $wd.Visible = $false; $wd.DisplayAlerts = 0
try {
    # Join-Path returns a PSObject-wrapped string, and Word's late-bound calls
    # hang on one (see Convert-RecordsToPdf.ps1): cast, and export by value.
    $d = $wd.Documents.Open([string]$docx, $false, $true)
    try { $d.ExportAsFixedFormat([string]$dest, 17) } finally { $d.Close($false) }
} finally {
    $wd.Quit(); [void][Runtime.InteropServices.Marshal]::ReleaseComObject($wd)
    Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
if (-not (Test-Path -LiteralPath $dest)) { throw "Word did not write $dest." }

Write-Output ("INVOICE   {0}  ({1} student(s), {2})" -f $name, $rows.Count, $total)
foreach ($r in $rows) { Write-Output ("  {0,-34} {1}  attempt {2}  {3}" -f $r.name, $r.id, $r.attempt, $r.result) }
