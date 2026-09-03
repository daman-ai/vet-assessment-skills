<#
  Build-ExampleSubmissions.ps1 — regenerate the fictional submissions that
  examples/ledger.example.json marks.

  These are FIXTURES, not student work. They exist so that
  Test-Install.ps1 -Full can run the whole skill end to end on a fresh machine:
  resolve the worked ledger, build every document, and put the result through
  the gate. A skill that has only ever been proved on the machine it was written
  on is not proved.

  They are deliberately shaped like the real thing:

    * answers sit in RESPONSE BOXES, so the outcome lines have somewhere to land
      and MarkedCopyInAnswerSpace has something to check;
    * the practical workbooks carry a real OBSERVATION SHEET — labelled fields,
      a column of Yes/No pairs, a notes cell, a feedback line and a sufficiency
      box — so the observation-sheet fill is exercised rather than described;
    * Mei Tanaka's knowledge questions and practical workbook are ONE FILE, so
      the one-copy-per-file grouping is exercised too;
    * Sofia Marchetti's workbook has NO observation sheet, which is the case the
      ledger declares with "observationSheet": { "inSubmission": false }.

  Run it from anywhere; it writes into its own folder.
    .\Build-ExampleSubmissions.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$BOX  = [char]0x2610      # U+2610 BALLOT BOX
$EM   = [char]0x2014      # U+2014 EM DASH, as the ledger's anchors carry it

# ------------------------------------------------------------ XML helpers ---

function Esc { param([string]$t) [System.Security.SecurityElement]::Escape($t) }

function P {
    param([string]$Text = '')
    '<w:p><w:r><w:t xml:space="preserve">' + (Esc $Text) + '</w:t></w:r></w:p>'
}

function Cell { param([string]$Inner) '<w:tc><w:tcPr><w:tcW w:w="3000" w:type="dxa"/></w:tcPr>' + $Inner + '</w:tc>' }
function Row  { param([string]$Inner) '<w:tr>' + $Inner + '</w:tr>' }
function Tbl  {
    param([string]$Inner)
    '<w:tbl><w:tblPr><w:tblW w:w="9000" w:type="dxa"/><w:tblInd w:w="0" w:type="dxa"/>' +
    '<w:tblBorders><w:top w:val="single" w:sz="4" w:color="999999"/><w:left w:val="single" w:sz="4" w:color="999999"/>' +
    '<w:bottom w:val="single" w:sz="4" w:color="999999"/><w:right w:val="single" w:sz="4" w:color="999999"/>' +
    '<w:insideH w:val="single" w:sz="4" w:color="999999"/><w:insideV w:val="single" w:sz="4" w:color="999999"/></w:tblBorders></w:tblPr>' +
    '<w:tblGrid><w:gridCol w:w="3000"/><w:gridCol w:w="3000"/><w:gridCol w:w="3000"/></w:tblGrid>' + $Inner + '</w:tbl>'
}

function ResponseBox {
    # One question's answer, in the box the student wrote it in.
    param([string]$Answer)
    Tbl (Row (Cell (P $Answer)))
}

function KnowledgeQuestions {
    param([int]$Count = 12)
    $out = @()
    for ($i = 1; $i -le $Count; $i++) {
        $out += P ("Q{0}. Question text for question {0} goes here." -f $i)
        $out += ResponseBox ("My answer to question {0} is written here in my own words. I explain the method and the reason." -f $i)
        $out += P ''
    }
    $out
}

function RecipeCards {
    $out = @()
    $out += P 'Recipe card 1 - creme caramel'
    $out += ResponseBox 'Method recorded. Caramel cooked to amber. Set overnight under refrigeration. Setting time: 12 hours. Holding temperature: 3 degrees.'
    $out += P ''
    $out += P 'Recipe card 2 - chocolate mousse'
    $out += ResponseBox 'Method recorded. Folded aerated cream through melted couverture. Setting time: not recorded. Holding temperature: not recorded.'
    $out += P ''
    $out += P 'Recipe card 3 - poached pear'
    $out += ResponseBox 'Method recorded. Poached in spiced syrup until tender. Setting time: not applicable. Holding temperature: 3 degrees.'
    $out += P ''
    $out += P 'Service record'
    $out += ResponseBox 'Three desserts portioned and plated during the lunch service period. Mise en place completed before service. Wastage recorded on the daily sheet.'
    $out += P ''
    $out
}

function ObservationSheet {
    <#
      The instrument, blank, exactly as a student submits it. FOUR observable
      tasks, so four Yes/No pairs — which is what the ledger's 'outcomes' arrays
      declare. Change one and you must change the other, and the builder will
      say so rather than ticking the wrong box.

      The heading carries an EM DASH because the ledger's anchor does. An anchor
      that differs from the document by one character finds nothing, and the
      build stops rather than guessing which heading was meant.
    #>
    $tasks = @(
        'Mise en place completed before service.',
        'All three desserts produced within the service period.',
        'Recipe cards record setting time and holding temperature.',
        'Quality checks recorded and wastage logged.'
    )
    $taskCell  = Cell (($tasks | ForEach-Object { P $_ }) -join '')
    $boxCell   = Cell ((1..$tasks.Count | ForEach-Object { (P "$BOX Yes") + (P "$BOX No") }) -join '')
    $notesCell = Cell (P 'Observation notes')

    $rows = @()
    $rows += Row ((Cell (P 'Date'))        + (Cell (P '')))
    $rows += Row ((Cell (P 'Start time'))  + (Cell (P '')))
    $rows += Row ((Cell (P 'Finish time')) + (Cell (P '')))
    $rows += Row ($taskCell + $boxCell + $notesCell)
    $rows += Row ((Cell (P 'Feedback to Student')) + (Cell (P '')))
    $rows += Row ((Cell (P 'Sufficient')) + (Cell ((P "$BOX Yes") + (P "$BOX No"))))

    @(
        (P ("Observation of Direct Competency {0} Practical Demonstration" -f $EM)),
        (Tbl ($rows -join ''))
    )
}

# ------------------------------------------------------------- packaging ---

function Save-Submission {
    param([string]$Name, [string[]]$Body)

    $sect = '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>' +
            '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" w:header="709" w:footer="709" w:gutter="0"/></w:sectPr>'

    $documentXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>' +
        ($Body -join '') + $sect + '</w:body></w:document>'

    $contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
        '<Default Extension="xml" ContentType="application/xml"/>' +
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>' +
        '</Types>'

    $rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>' +
        '</Relationships>'

    $docRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>'

    $stage = Join-Path $env:TEMP ("submission_" + [System.IO.Path]::GetFileNameWithoutExtension($Name))
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
    New-Item -ItemType Directory -Force -Path (Join-Path $stage '_rels')      | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $stage 'word\_rels') | Out-Null

    # No BOM: Word writes its parts without one, and a fixture that differs from
    # a real submission in its bytes is testing the wrong document.
    $enc = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText((Join-Path $stage '[Content_Types].xml'),          $contentTypes, $enc)
    [System.IO.File]::WriteAllText((Join-Path $stage '_rels\.rels'),                  $rels,         $enc)
    [System.IO.File]::WriteAllText((Join-Path $stage 'word\document.xml'),            $documentXml,  $enc)
    [System.IO.File]::WriteAllText((Join-Path $stage 'word\_rels\document.xml.rels'), $docRels,      $enc)

    $out = Join-Path $here $Name
    if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Force }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($stage, $out)
    Remove-Item -LiteralPath $stage -Recurse -Force
    Write-Output ("  wrote {0}" -f $Name)
}

# ------------------------------------------------------------ the fixtures ---

Write-Output ''
Write-Output 'Rebuilding the worked example submissions...'

# Mei Tanaka — ONE FILE covering both tools. Part B is what her knowledge
# questions stop at, which is why the ledger gives it as questionsEndAnchor.
$mei = @()
$mei += P 'SITHPAT016 Produce desserts - Assessment Workbook'
$mei += P 'Student submission. Mei Tanaka, MVC00312.'
$mei += P ''
$mei += P 'Part A. Knowledge Questions'
$mei += KnowledgeQuestions
$mei += P 'Part B. Recipe Workbook and Practical Observation'
$mei += RecipeCards
$mei += ObservationSheet
$mei += P 'End of assessment.'
Save-Submission 'MVC00312_SITHPAT016_WORKBOOK.docx' $mei

# Daniel Okafor and Luca Bianchi — two files each, the ordinary shape.
foreach ($id in @('MVC00318', 'MVC00334')) {
    $kq = @()
    $kq += P 'SITHPAT016 Produce desserts - Knowledge Questions'
    $kq += P ("Student submission. {0}." -f $id)
    $kq += P ''
    $kq += KnowledgeQuestions
    $kq += P 'End of assessment.'
    Save-Submission ("{0}_SITHPAT016_KQ.docx" -f $id) $kq

    $rw = @()
    $rw += P 'SITHPAT016 Produce desserts - Recipe Workbook and Practical Observation'
    $rw += P ("Student submission. {0}." -f $id)
    $rw += P ''
    $rw += RecipeCards
    $rw += ObservationSheet
    $rw += P 'End of assessment.'
    Save-Submission ("{0}_SITHPAT016_RW.docx" -f $id) $rw
}

# Sofia Marchetti — second attempt at the knowledge questions, and a workbook
# that carries NO observation sheet. Her ledger entry declares that rather than
# leaving the builder to discover it.
$sofiaKq = @()
$sofiaKq += P 'SITHPAT016 Produce desserts - Knowledge Questions (second attempt)'
$sofiaKq += P 'Student submission. MVC00341.'
$sofiaKq += P ''
$sofiaKq += KnowledgeQuestions
$sofiaKq += P 'End of assessment.'
Save-Submission 'MVC00341_SITHPAT016_KQ_attempt2.docx' $sofiaKq

$sofiaRw = @()
$sofiaRw += P 'SITHPAT016 Produce desserts - Recipe Workbook and Practical Observation'
$sofiaRw += P 'Student submission. MVC00341. Printed and scanned; no observation sheet attached.'
$sofiaRw += P ''
$sofiaRw += RecipeCards
$sofiaRw += P 'End of assessment.'
Save-Submission 'MVC00341_SITHPAT016_RW.docx' $sofiaRw

# Mei's old two-file pair is superseded by the single workbook above.
foreach ($old in @('MVC00312_SITHPAT016_KQ.docx', 'MVC00312_SITHPAT016_RW.docx')) {
    $p = Join-Path $here $old
    if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force; Write-Output ("  removed {0} (superseded by the combined workbook)" -f $old) }
}

Write-Output ''
Write-Output 'Done. Run scripts\Test-Install.ps1 -Full to mark them.'
Write-Output ''
