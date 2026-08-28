# Self-test for the docx-images skill. Builds a .docx full of image prompts,
# runs the scan, stands in for the image API with a locally drawn PNG, builds
# the diagrams natively from specs, then re-opens the result and checks that
# the picture, the shapes and the table really are in it.
# No API calls, no cost. Run it after changing anything in this skill.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Drawing

$sand = Join-Path ([System.IO.Path]::GetTempPath()) 'docximages_selftest'
if (Test-Path $sand) { Remove-Item $sand -Recurse -Force }
New-Item -ItemType Directory -Path $sand -Force | Out-Null

$script:fails = 0
$assert = {
  param($cond, $msg)
  if (-not $cond) { Write-Host "  FAIL $msg" -ForegroundColor Red; $script:fails++ }
  else { Write-Host "  ok   $msg" -ForegroundColor Green }
}

# ---- build a small .docx by hand -------------------------------------------
$src = Join-Path $sand 'src'
New-Item -ItemType Directory -Path (Join-Path $src '_rels') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $src 'word\_rels') -Force | Out-Null

@'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>
'@ | Set-Content -LiteralPath (Join-Path $src '[Content_Types].xml') -Encoding UTF8

@'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
'@ | Set-Content -LiteralPath (Join-Path $src '_rels\.rels') -Encoding UTF8

@'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
</Relationships>
'@ | Set-Content -LiteralPath (Join-Path $src 'word\_rels\document.xml.rels') -Encoding UTF8

# Four prompts: a run-split illustration with inline fields, a multi-paragraph
# diagram with its own field lines, an IMAGE-marked prompt that is really a
# diagram, and a grid that should come out as a table.
@'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body>
<w:p><w:r><w:t>Task 1 - Receiving deliveries</w:t></w:r></w:p>
<w:p><w:r><w:t>Read the scenario below and answer in the space provided.</w:t></w:r></w:p>
<w:p><w:r><w:t xml:space="preserve">[ILLUSTRATION: A chef in clean whites </w:t></w:r><w:r><w:t>checking the core temperature of a delivered tray of raw chicken with a digital probe thermometer on a stainless steel bench. Caption: Probing a delivery on receipt. Alt: A chef probes raw chicken on a stainless bench.]</w:t></w:r></w:p>
<w:p><w:r><w:t>Question 1. State the maximum acceptable core temperature.</w:t></w:r></w:p>
<w:p><w:r><w:t>[DIAGRAM: A horizontal temperature danger zone bar running from minus 5 to 75 degrees.</w:t></w:r></w:p>
<w:p><w:r><w:t>Mark three bands with the labels Cold 5 and below, Danger zone 5 to 60, Hot 60 and above.</w:t></w:r></w:p>
<w:p><w:r><w:t>Caption: The temperature danger zone</w:t></w:r></w:p>
<w:p><w:r><w:t>Aspect: landscape]</w:t></w:r></w:p>
<w:p><w:r><w:t>Question 2. Explain why the middle band matters.</w:t></w:r></w:p>
<w:p><w:r><w:t>[IMAGE: A flowchart of the four steps for handling a rejected delivery, with arrows between each step. Caption: Rejected delivery workflow]</w:t></w:r></w:p>
<w:p><w:r><w:t>[DIAGRAM: A three column matrix of hazards, controls and who is responsible. Caption: Hazard control matrix]</w:t></w:r></w:p>
<w:p><w:r><w:t>End of Task 1.</w:t></w:r></w:p>
<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1080" w:bottom="1440" w:left="1080"/></w:sectPr>
</w:body>
</w:document>
'@ | Set-Content -LiteralPath (Join-Path $src 'word\document.xml') -Encoding UTF8

$testDoc = Join-Path $sand 'Test_UAT.docx'
[System.IO.Compression.ZipFile]::CreateFromDirectory($src, $testDoc, [System.IO.Compression.CompressionLevel]::Optimal, $false)
Write-Host "built $testDoc" -ForegroundColor Cyan

# ---- 1. find ----------------------------------------------------------------
Write-Host "`n--- STAGE 1: find ---" -ForegroundColor Cyan
$mf = Join-Path $sand 'images\manifest.json'
& (Join-Path $PSScriptRoot 'Find-DocxImagePrompts.ps1') -Path $testDoc -ManifestPath $mf
if ($LASTEXITCODE -eq 3) { throw 'finder found nothing' }

$m = Get-Content $mf -Raw | ConvertFrom-Json
& $assert ($m.placeholders.Count -eq 4) "found 4 prompts (got $($m.placeholders.Count))"
& $assert ($m.placeholders[0].kind -eq 'illustration') "first is an illustration"
& $assert ($m.placeholders[0].status -eq 'pending') "illustration waits on the API"
& $assert ($m.placeholders[0].caption -eq 'Probing a delivery on receipt.') "caption parsed from a run-split paragraph"
& $assert ($m.placeholders[0].prompt -notmatch 'Caption:') "caption stripped out of the prompt body"
& $assert ($m.placeholders[1].kind -eq 'diagram') "second is a diagram"
& $assert ($m.placeholders[1].status -eq 'needs-spec') "diagram waits on a spec, not on the API"
& $assert ($m.placeholders[1].paraEnd -eq 7) "multi-paragraph block closed at para 7 (got $($m.placeholders[1].paraEnd))"
& $assert ($m.placeholders[1].prompt -match 'Danger zone 5 to 60') "diagram labels kept in the prompt"
& $assert ($m.placeholders[2].kind -eq 'diagram') "IMAGE-marked flowchart re-typed as a diagram"

# ---- 2. stand in for the API, and author the specs --------------------------
Write-Host "`n--- STAGE 2: illustration from the API, diagrams from specs ---" -ForegroundColor Cyan
$imgDir = Join-Path $sand 'images'
foreach ($ph in $m.placeholders) {
  if ($ph.kind -eq 'diagram') { continue }
  $w, $h = $ph.size -split 'x'
  $bmp = New-Object System.Drawing.Bitmap([int]$w, [int]$h)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.Clear([System.Drawing.Color]::FromArgb(47,96,180))
  $f = New-Object System.Drawing.Font('Arial', 64)
  $g.DrawString($ph.id, $f, [System.Drawing.Brushes]::White, 60, 60)
  $g.Dispose()
  $p = Join-Path $imgDir ("{0}_{1}.png" -f $ph.id, $ph.kind)
  $bmp.Save($p, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  $ph.imageFile = $p
  $ph.status = 'generated'
  Write-Host "  drew $(Split-Path -Leaf $p) at ${w}x${h}"
}

$m.placeholders[1].spec = [pscustomobject]@{
  layout = 'bands'
  nodes = @(
    [pscustomobject]@{ text = 'Cold';        note = '5 and below';  fill = 'accent' }
    [pscustomobject]@{ text = 'Danger zone'; note = '5 to 60';      fill = 'orange' }
    [pscustomobject]@{ text = 'Hot';         note = '60 and above'; fill = 'navy'   })
}
$m.placeholders[1].status = 'spec-ready'

$m.placeholders[2].spec = [pscustomobject]@{
  layout = 'process'; orientation = 'horizontal'
  nodes = @(
    [pscustomobject]@{ text = 'Record the fault' }
    [pscustomobject]@{ text = 'Segregate the stock' }
    [pscustomobject]@{ text = 'Notify the supplier' }
    [pscustomobject]@{ text = 'Complete the credit'; fill = 'accent' })
  edges = @([pscustomobject]@{ from = 'n1'; to = 'n2'; label = 'on receipt' })
}
$m.placeholders[2].status = 'spec-ready'

$m.placeholders[3].spec = [pscustomobject]@{
  layout = 'table'; headerRow = $true
  rows = @(
    ,@('Hazard', 'Control', 'Responsible')
    ,@('Temperature abuse', 'Probe every delivery', 'Receiving chef')
    ,@('Cross contamination', 'Colour coded boards', 'All kitchen staff'))
}
$m.placeholders[3].status = 'spec-ready'
Write-Host "  authored 3 diagram specs (bands, process, table)"
$m | ConvertTo-Json -Depth 12 | Set-Content $mf -Encoding UTF8

# ---- 3. apply ---------------------------------------------------------------
Write-Host "`n--- STAGE 3: place into the docx ---" -ForegroundColor Cyan
$outDoc = Join-Path $sand 'out\Test_UAT.docx'
& (Join-Path $PSScriptRoot 'Set-DocxImages.ps1') -Path $testDoc -ManifestPath $mf -OutPath $outDoc

# ---- 4. verify the XML ------------------------------------------------------
Write-Host "`n--- STAGE 4: verify the result ---" -ForegroundColor Cyan
$chk = Join-Path $sand 'check'
[System.IO.Compression.ZipFile]::ExtractToDirectory($outDoc, $chk)
[xml]$outXml = Get-Content -LiteralPath (Join-Path $chk 'word\document.xml') -Raw
$body = $outXml.OuterXml

$media = @(Get-ChildItem (Join-Path $chk 'word\media') -ErrorAction SilentlyContinue)
& $assert ($media.Count -eq 1) "only the illustration became a file in word/media (got $($media.Count))"
& $assert (([regex]::Matches($body, '<wpc:wpc>')).Count -eq 2) "2 native drawing canvases"
& $assert (([regex]::Matches($body, '<w:tbl[ >]')).Count -eq 1) "1 native table"
& $assert (([regex]::Matches($body, '<pic:pic>')).Count -eq 1) "1 embedded picture, and only one"
& $assert ($body -notmatch '\[ILLUSTRATION:' -and $body -notmatch '\[DIAGRAM:' -and $body -notmatch '\[IMAGE:') "no prompt markers survive"
& $assert ($body -notmatch 'Danger zone 5 to 60') "the multi-paragraph prompt body is gone too"
& $assert ($body -match 'descr="A chef probes raw chicken') "alt text on the picture"
& $assert ($body -match 'Figure 1: Probing a delivery') "caption on the picture"
& $assert ($body -match 'Figure 2: The temperature danger zone') "caption on the first diagram"
& $assert ($body -match '>Danger zone<') "diagram label is live text in the document, not pixels"
& $assert ($body -match '>Colour coded boards<') "table cell is live text"
& $assert ($body -match 'Question 1\. State the maximum') "surrounding body text untouched"
& $assert ($body -match 'End of Task 1\.') "trailing text untouched"

# every drawing id must be unique or Word repairs the file
$ids = @([regex]::Matches($body, '<wps:cNvPr id="(\d+)"') | ForEach-Object { $_.Groups[1].Value })
$ids += @([regex]::Matches($body, '<wp:docPr id="(\d+)"') | ForEach-Object { $_.Groups[1].Value })
& $assert ((@($ids | Select-Object -Unique)).Count -eq $ids.Count) "every drawing id is unique ($($ids.Count) ids)"

$exts = [regex]::Matches($body, 'extent cx="(\d+)"')
$widest = ($exts | ForEach-Object { [int]$_.Groups[1].Value } | Measure-Object -Maximum).Maximum
& $assert ($widest -le 6188710 -and $widest -gt 0) "nothing exceeds the column width (widest $widest EMU)"

# ---- 5. does Word itself accept the file? -----------------------------------
Write-Host "`n--- STAGE 5: open it in Word ---" -ForegroundColor Cyan
try {
  $word = New-Object -ComObject Word.Application
  $word.Visible = $false
  $word.DisplayAlerts = 0
  $d = $word.Documents.Open($outDoc, $false, $true)
  $inline = $d.InlineShapes.Count
  $shapes = $d.Shapes.Count
  $tables = $d.Tables.Count
  & $assert ($inline -eq 1) "Word sees the 1 inline picture (got $inline)"
  & $assert ($shapes -eq 2) "Word sees 2 drawing canvases (got $shapes)"
  & $assert ($tables -eq 1) "Word sees 1 table (got $tables)"

  $items = 0; $editable = $false
  for ($i = 1; $i -le $shapes; $i++) {
    $sh = $d.Shapes.Item($i)
    try {
      $items += $sh.CanvasItems.Count
      for ($j = 1; $j -le $sh.CanvasItems.Count; $j++) {
        $it = $sh.CanvasItems.Item($j)
        try { if ($it.TextFrame.HasText -and $it.TextFrame.TextRange.Text -match 'Danger zone') { $editable = $true } } catch {}
      }
    } catch {}
  }
  & $assert ($items -ge 10) "canvases hold $items real shapes"
  & $assert $editable "a diagram label is live, editable text inside a shape"
  $d.Close($false)
  $word.Quit()
  [void][Runtime.InteropServices.Marshal]::ReleaseComObject($word)
}
catch {
  Write-Host "  FAIL Word could not open the document: $($_.Exception.Message)" -ForegroundColor Red
  $script:fails++
}

Write-Host ""
if ($script:fails -eq 0) { Write-Host "ALL CHECKS PASSED" -ForegroundColor Green; exit 0 }
else { Write-Host "$($script:fails) CHECK(S) FAILED" -ForegroundColor Red; exit 1 }
