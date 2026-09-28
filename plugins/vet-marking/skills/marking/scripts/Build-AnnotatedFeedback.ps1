<#
  Build-AnnotatedFeedback.ps1 - the annotated feedback map.

  A fifth document type, and the only one that puts the feedback NEXT TO the
  work it judges. Each page of the student's marked assessment is reproduced at
  a reduced scale down the left of the page; each thing to fix is written in the
  right-hand column; and a hand-drawn arrow runs from the note to the exact
  place on the page it refers to.

  WHY IT PHOTOGRAPHS THE PAGE RATHER THAN RESHAPING IT
  The obvious build is to widen the marked copy's right margin and drop the
  notes into the space. It cannot be done safely: changing the margin reflows
  the student's own document, moves every page break, and pushes any table
  wider than the new text width off the page. This builder never opens the
  student's work for writing. It renders each page as a picture and annotates
  the picture, so the returned assessment and this map cannot disagree, and the
  student's submission is altered in no way at all.

  WHY IT CANNOT DRIFT FROM THE FEEDBACK SHEET
  Both render from the same ledger items. The note beside the arrow is the same
  'issue' and 'action' the Student Feedback Sheet prints, taken from the same
  row - not a second description of the same fault written by hand. Nothing
  here is authored; the map adds placement, never content.

  WHAT IT DOES NOT REPLACE
  The Student Feedback Sheet stays. It is the RTO's record of the feedback
  issued and it is a template document; this map is a reading aid that travels
  with it. Delivering the map alone would drop a required record.

  Usage:
    .\Build-AnnotatedFeedback.ps1 -Ledger run\resolved.json -MarkedDir run -OutDir run
    .\Build-AnnotatedFeedback.ps1 -Ledger run\resolved.json -MarkedDir run -Orientation Landscape
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Ledger,
    [Parameter(Mandatory)][string]$MarkedDir,
    [string]$OutDir,
    [ValidateSet('Portrait','Landscape')][string]$Orientation = 'Portrait',
    [ValidateRange(0.4,0.9)][double]$PageScale = 0.75,
    [ValidateRange(96,300)][int]$Dpi = 150,
    # THE WHOLE ASSESSMENT IS THE DEFAULT. The map is what the student reads
    # end to end - their own work with the outcomes in place - so an extract
    # that stops at the annotated pages sends them back to the marked copy to
    # see what came before and after. -NotedPagesOnly gives that extract where
    # a short handout is what is wanted.
    [switch]$NotedPagesOnly,
    [switch]$Timing,
    [switch]$KeepAspect,
    [switch]$KeepPages
)
$ErrorActionPreference = 'Stop'

$EMU_PER_PT = 12700
$EMU_PER_CM = 360000

# ------------------------------------------------------------------ helpers

function ConvertTo-XmlText {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    $t = $Text -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;'
    # A control character in a ledger string makes an unopenable document, and
    # Word repairs it silently rather than refusing it.
    return ($t -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', ' ')
}

function Get-Jitter {
    <#
      Deterministic wobble. A rebuild must produce the same file, or the gate's
      read-back compares a document against a different one; so the hand-drawn
      look is seeded from the item's own text, never from Get-Random.
    #>
    param([string]$Seed, [int]$Index)
    # 0xFFFFFFFF alone parses as Int32 -1 here, and a mask of -1 changes nothing:
    # the product then overflows the uint32 cast. The L suffix makes it Int64.
    [long]$h = 2166136261
    foreach ($c in ([char[]]("$Seed|$Index"))) {
        $h = [uint32](($h -bxor [int]$c) * 16777619 -band 0xFFFFFFFFL)
    }
    # -1.0 .. 1.0
    return ((($h % 2000) / 1000.0) - 1.0)
}

function Get-EstimatedLines {
    param([string]$Text, [double]$BoxWidthPt, [double]$FontPt)
    if (-not $Text) { return 0 }
    $perLine = [Math]::Max(8, [int]($BoxWidthPt / ($FontPt * 0.50)))
    $lines = 0
    foreach ($para in ($Text -split "`n")) {
        $lines += [Math]::Max(1, [int][Math]::Ceiling($para.Length / [double]$perLine))
    }
    return $lines
}

# --------------------------------------------------- Word: where each anchor is

function Get-AnchorGeometry {
    <#
      Opens the marked copy read-only and asks Word - not a second renderer -
      where each anchor sits on the page. Word reports the position of a range
      in points from the top-left of the physical page, which is the same
      coordinate space the exported PDF is rendered in, so the two line up
      without a calibration step.

      Returns the page size, the page count, a page/x/y for every anchor named,
      a page/x/y for each question's OUTCOME LINE where one can be found, and
      the path of the exported PDF.

      The outcome line is the better target and it is why $Targets exists. A
      point half way between one anchor and the next lands in the middle of the
      question's BLOCK - which, where the stem runs to a paragraph, is the stem
      rather than the answer, and the arrow then appears to be remarking on the
      wording of the question. The marked copy has already written a coloured
      outcome line at the end of the response, which is exactly where the
      judgement belongs; searching for it INSIDE the span between this anchor
      and the next finds this question's line and no other, even though every
      NYS question in the document carries the same words.
    #>
    param([string]$DocPath, [string[]]$Anchors, [object[]]$Targets, [string]$PdfPath)

    $wdActiveEndPageNumber = 3
    $wdHorizontalPositionRelativeToPage = 5
    $wdVerticalPositionRelativeToPage = 6
    $wdExportFormatPDF = 17
    $wdStatisticPages = 2
    $wdWithInTable = 12

    $found = @{}
    $outcomes = @{}
    $boxes = @{}
    $ambiguous = @()
    $missing = @()
    $word = $null
    $doc = $null
    try {
        $word = New-Object -ComObject Word.Application
        $word.Visible = $false
        $word.DisplayAlerts = 0
        $doc = $word.Documents.Open([string]$DocPath, $false, $true)

        # Repaginate before asking for any position. Word returns stale
        # coordinates on a document it has not laid out, and the arrows then
        # point at the right place on the wrong page.
        $doc.Repaginate()

        $pageCount = [int]$doc.ComputeStatistics($wdStatisticPages)
        $pageWidthPt = [double]$doc.PageSetup.PageWidth
        $pageHeightPt = [double]$doc.PageSetup.PageHeight
        $docEnd = $doc.Content.End

        foreach ($anchor in $Anchors) {
            if ($found.ContainsKey($anchor)) { continue }
            $hits = @()
            $rng = $doc.Content
            $f = $rng.Find
            $f.ClearFormatting()
            $f.Text = $anchor
            $f.Forward = $true
            $f.Wrap = 0            # wdFindStop - never wrap, or the loop never ends
            $f.MatchCase = $true
            $f.MatchWildcards = $false
            while ($f.Execute()) {
                $hits += [pscustomobject]@{
                    Page  = [int]$rng.Information($wdActiveEndPageNumber)
                    X     = [double]$rng.Information($wdHorizontalPositionRelativeToPage)
                    Y     = [double]$rng.Information($wdVerticalPositionRelativeToPage)
                    Start = [int]$rng.Start
                    End   = [int]$rng.End
                }
                if ($rng.End -ge $docEnd) { break }
                $rng.SetRange($rng.End, $docEnd)
                $f = $rng.Find
                $f.ClearFormatting()
                $f.Text = $anchor
                $f.Forward = $true
                $f.Wrap = 0
                $f.MatchCase = $true
                $f.MatchWildcards = $false
            }

            if ($hits.Count -eq 0) { $missing += $anchor; continue }
            # An anchor matching twice is the ambiguity the marked copy already
            # refuses. Refuse it here too rather than pointing at the first.
            if ($hits.Count -gt 1) { $ambiguous += $anchor; continue }
            $found[$anchor] = $hits[0]
        }

        # The outcome line for each question, searched for only between that
        # question's anchor and the next one. "Not yet Satisfactory" is the
        # stable part of the line: RTO profiles end it differently - "refer to
        # the feedback sheet", "refer to the feedback page" - and matching the
        # whole sentence would find nothing on half the documents this runs on.
        foreach ($t in @($Targets)) {
            if (-not $t) { continue }
            if (-not $found.ContainsKey($t.Anchor)) { continue }
            $from = [int]$found[$t.Anchor].End
            $to = $docEnd
            if ($t.Next -and $found.ContainsKey($t.Next)) { $to = [int]$found[$t.Next].Start }
            if ($to -le $from) { continue }

            # The ledger already says which verdict this question carries, so
            # search for that one. Searching for "Satisfactory" blind would
            # match the tail of "Not yet Satisfactory" and report a pass on a
            # question that failed.
            $wantText = if ("$($t.Outcome)" -eq 'NYS') { 'Not yet Satisfactory' } else { 'Satisfactory' }
            $span = $doc.Range($from, $to)
            $sf = $span.Find
            $sf.ClearFormatting()
            $sf.Text = $wantText
            $sf.Forward = $true
            $sf.Wrap = 0
            $sf.MatchCase = $false
            $sf.MatchWildcards = $false
            while ($sf.Execute()) {
                # Word redefines the range in place on a hit, so re-read the
                # bounds and confirm the line really is inside this question -
                # a Find that ran past the span would put this question's arrow
                # on the next question's verdict.
                if ($span.Start -lt $from -or $span.End -gt $to) { break }

                # "Satisfactory" is the tail of "Not yet Satisfactory". Without
                # this the stray NYS line that strands itself in a NEIGHBOURING
                # question's block - which happens, and this skill reports it -
                # would be read as that question's pass.
                $isTail = $false
                if ($wantText -eq 'Satisfactory' -and $span.Start -ge 8) {
                    $before = "$($doc.Range($span.Start - 8, $span.Start).Text)"
                    if ($before -match '(?i)not\s+yet\s*$') { $isTail = $true }
                }
                if (-not $isTail) {
                    $outcomes[$t.Anchor] = [pscustomobject]@{
                        Page = [int]$span.Information($wdActiveEndPageNumber)
                        X    = [double]$span.Information($wdHorizontalPositionRelativeToPage)
                        Y    = [double]$span.Information($wdVerticalPositionRelativeToPage)
                        # Whether the verdict is INSIDE the response box. These
                        # instruments put every student response in a bordered
                        # table, and the skill's own rule is that the outcome
                        # lands in that box under the student's words. A verdict
                        # that is not in a table has escaped into body text -
                        # which is what a walk-back that overshot looks like.
                        InTable = [bool]$span.Information($wdWithInTable)
                        Pos     = [int]$span.Start
                    }
                    break
                }
                if ($span.End -ge $to) { break }
                $span.SetRange($span.End, $to)
                $sf = $span.Find
                $sf.ClearFormatting()
                $sf.Text = $wantText
                $sf.Forward = $true
                $sf.Wrap = 0
                $sf.MatchCase = $false
                $sf.MatchWildcards = $false
            }

            # THE RESPONSE BOX ITSELF, so the note can sit level with the middle
            # of the answer rather than level with the verdict at the foot of
            # it. On a long answer those are most of a page apart, and a note
            # pinned to the foot reads as a remark about the last sentence.
            #
            # The box is a table in every instrument measured. Where the verdict
            # was found inside one, THAT table is the answer box and there is no
            # guessing to do; otherwise the first table after the question's
            # anchor is taken, which is what the box is on every template here.
            $tbl = $null
            try {
                if ($outcomes.ContainsKey($t.Anchor) -and $outcomes[$t.Anchor].InTable) {
                    $vr = $doc.Range($outcomes[$t.Anchor].Pos, $outcomes[$t.Anchor].Pos)
                    if ($vr.Tables.Count -ge 1) { $tbl = $vr.Tables.Item(1) }
                }
                if (-not $tbl) {
                    $sp2 = $doc.Range($from, $to)
                    if ($sp2.Tables.Count -ge 1) { $tbl = $sp2.Tables.Item(1) }
                }
            } catch { $tbl = $null }

            # CENTRE ON THE WRITING, NOT ON THE BOX.
            #
            # A response box is sized for the longest answer the writers
            # expected, so a student who answered in six lines leaves two thirds
            # of it blank. The box's geometric centre then falls in that blank,
            # and the note floats in the middle of an empty page with the answer
            # sitting well above it.
            #
            # Measuring the paragraphs that actually carry text also disposes of
            # a second fault: a table's Range.End sits just PAST the table, which
            # is often on the following page, so a box wholly on one page looked
            # like a box broken across two and took the page-break fallback.
            if ($tbl) {
                try {
                    # ONLY THE FIRST AND LAST LINES OF WRITING ARE MEASURED, and
                    # they are found by reading text before any geometry is
                    # asked for.
                    #
                    # Information() forces Word to lay the page out, so calling
                    # it once per paragraph costs a repagination per paragraph.
                    # On a table-heavy cookery instrument - SITHPAT020 carries
                    # ingredient tables running to dozens of rows - that took
                    # Word past 1.2 GB and a quarter of an hour for ONE student,
                    # which is unusable for a class of twenty. Reading
                    # Range.Text needs no layout, so the scan is cheap and only
                    # two positions are ever measured.
                    # AND THE SCAN IS BOUNDED AT BOTH ENDS.
                    #
                    # `$paras.Item($k).Range` hands back a fresh COM object on
                    # every call and nothing releases it, so an unbounded walk
                    # over a big table leaks Ranges: on SITHPAT020's ingredient
                    # tables Word climbed past 1.2 GB and each call got slower
                    # than the last, turning one student into a quarter of an
                    # hour. A response box is a cell or two, so eight paragraphs
                    # in from each end always finds the writing; on a long data
                    # table it finds the first and last rows, which is still the
                    # right place to point.
                    $paras = $tbl.Range.Paragraphs
                    $pn = [int]$paras.Count
                    $probe = [Math]::Min(8, $pn)
                    $firstIdx = -1; $lastIdx = -1
                    for ($k = 1; $k -le $probe; $k++) {
                        $ptxt = "$($paras.Item($k).Range.Text)" -replace "[`r`n`a`f]", ''
                        if (-not [string]::IsNullOrWhiteSpace($ptxt)) { $firstIdx = $k; break }
                    }
                    for ($k = $pn; $k -gt ($pn - $probe); $k--) {
                        $ptxt = "$($paras.Item($k).Range.Text)" -replace "[`r`n`a`f]", ''
                        if (-not [string]::IsNullOrWhiteSpace($ptxt)) { $lastIdx = $k; break }
                    }
                    if ($firstIdx -lt 1) { $firstIdx = 1 }
                    if ($lastIdx -lt $firstIdx) { $lastIdx = $firstIdx }

                    $firstY = $null; $firstPage = 0; $lastY = 0.0; $lastPage = 0; $bx = 0.0
                    if ($firstIdx -ge 1 -and $lastIdx -ge $firstIdx) {
                        $fs2 = $paras.Item($firstIdx).Range.Start
                        $ls2 = $paras.Item($lastIdx).Range.Start
                        $c = $doc.Range($fs2, $fs2)
                        $firstPage = [int]$c.Information($wdActiveEndPageNumber)
                        $firstY = [double]$c.Information($wdVerticalPositionRelativeToPage)
                        $bx = [double]$c.Information($wdHorizontalPositionRelativeToPage)
                        $c2 = $doc.Range($ls2, $ls2)
                        $lastPage = [int]$c2.Information($wdActiveEndPageNumber)
                        $lastY = [double]$c2.Information($wdVerticalPositionRelativeToPage)
                    }
                    if ($null -ne $firstY) {
                        if ($lastPage -eq $firstPage) {
                            $cy = ($firstY + $lastY) / 2.0
                        } else {
                            # Writing that genuinely runs over a page break has no
                            # single centre. Half way down the part on its FIRST
                            # page keeps the note beside where the answer starts,
                            # which is where the student looks; the alternative
                            # puts it on a page the answer merely spills onto.
                            $cy = ($firstY + $pageHeightPt - 56.0) / 2.0
                        }
                        $boxes[$t.Anchor] = [pscustomobject]@{ Page = $firstPage; Y = $cy; X = $bx }
                    }
                } catch { }
            }
        }

        $doc.ExportAsFixedFormat([string]$PdfPath, $wdExportFormatPDF)
    } finally {
        if ($doc)  { $doc.Close([ref]$false); [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($doc) }
        if ($word) { $word.Quit(); [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) }
        [GC]::Collect(); [GC]::WaitForPendingFinalizers()
    }

    return [pscustomobject]@{
        PageCount    = $pageCount
        PageWidthPt  = $pageWidthPt
        PageHeightPt = $pageHeightPt
        Anchors      = $found
        Outcomes     = $outcomes
        Boxes        = $boxes
        Ambiguous    = $ambiguous
        Missing      = $missing
        Pdf          = $PdfPath
    }
}

# ------------------------------------------------- PDF pages -> page pictures

function Export-PdfPageImages {
    <#
      Windows.Data.Pdf is the only PDF renderer on this machine, and it is
      reached from PowerShell through the WinRT interop shim. Two await shapes
      are needed, not one: LoadFromFileAsync returns an IAsyncOperation and
      RenderToStreamAsync returns an IAsyncAction, and the generic AsTask that
      handles the first does not accept the second.
    #>
    param([string]$PdfPath, [string]$OutFolder, [int]$WidthPx)

    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $methods = [System.WindowsRuntimeSystemExtensions].GetMethods()
    $asTaskOp = ($methods | Where-Object {
        $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
        $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
    $asTaskAct = ($methods | Where-Object {
        $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
        $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' })[0]

    $awaitOp = {
        param($op, $type)
        $t = $asTaskOp.MakeGenericMethod($type).Invoke($null, @($op))
        [void]$t.Wait(-1)
        $t.Result
    }.GetNewClosure()
    $awaitAct = {
        param($action)
        $t = $asTaskAct.Invoke($null, @($action))
        [void]$t.Wait(-1)
    }.GetNewClosure()

    [void][Windows.Data.Pdf.PdfDocument, Windows.Data.Pdf, ContentType = WindowsRuntime]
    [void][Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]

    $sf = & $awaitOp ([Windows.Storage.StorageFile]::GetFileFromPathAsync($PdfPath)) ([Windows.Storage.StorageFile])
    $pdf = & $awaitOp ([Windows.Data.Pdf.PdfDocument]::LoadFromFileAsync($sf)) ([Windows.Data.Pdf.PdfDocument])
    $folder = & $awaitOp ([Windows.Storage.StorageFolder]::GetFolderFromPathAsync($OutFolder)) ([Windows.Storage.StorageFolder])

    $paths = @()
    for ($i = 0; $i -lt $pdf.PageCount; $i++) {
        $page = $pdf.GetPage($i)
        $name = 'page{0:d3}.png' -f ($i + 1)
        $file = & $awaitOp ($folder.CreateFileAsync($name, 1)) ([Windows.Storage.StorageFile])
        $stream = & $awaitOp ($file.OpenAsync(1)) ([Windows.Storage.Streams.IRandomAccessStream])
        $opts = New-Object Windows.Data.Pdf.PdfPageRenderOptions
        $opts.DestinationWidth = [uint32]$WidthPx
        & $awaitAct ($page.RenderToStreamAsync($stream, $opts))
        $stream.Dispose()
        $page.Dispose()
        $paths += (Join-Path $OutFolder $name)
    }
    return $paths
}

# ------------------------------------------------------------- drawing pieces

function New-PagePictureXml {
    param([int]$Id, [string]$RelId, [int]$X, [int]$Y, [int]$Cx, [int]$Cy)
    return @"
<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
  <pic:nvPicPr><pic:cNvPr id="$Id" name="Assessment page $Id"/><pic:cNvPicPr/></pic:nvPicPr>
  <pic:blipFill><a:blip r:embed="$RelId"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
  <pic:spPr>
    <a:xfrm><a:off x="$X" y="$Y"/><a:ext cx="$Cx" cy="$Cy"/></a:xfrm>
    <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
    <a:ln w="6350"><a:solidFill><a:srgbClr val="BFBFBF"/></a:solidFill></a:ln>
  </pic:spPr>
</pic:pic>
"@
}

function New-ScribbleArrowXml {
    <#
      The arrow. A preset connector draws a ruled line, which reads as a
      machine annotation; what a marker actually leaves on a page is a slightly
      uneven curve. This builds a custom geometry - four cubic segments, each
      control point pushed off the straight line by a seeded wobble - so the
      stroke bends the way a hand bends it and still lands on the exact point.

      The wobble is proportional to the arrow's length, so a short arrow does
      not look like a scrawl and a long one does not look ruled.
    #>
    param(
        [int]$Id, [int]$X1, [int]$Y1, [int]$X2, [int]$Y2,
        [string]$Colour = 'C00000', [string]$Seed = '', [int]$Width = 19050
    )
    $minX = [Math]::Min($X1, $X2); $minY = [Math]::Min($Y1, $Y2)
    $w = [Math]::Max(9525, [Math]::Abs($X2 - $X1))
    $h = [Math]::Max(9525, [Math]::Abs($Y2 - $Y1))
    # Pad the box so wobble that strays outside the straight line is not clipped.
    $pad = [int]([Math]::Max($w, $h) * 0.18) + 9525
    $ox = $minX - $pad; $oy = $minY - $pad
    $bw = $w + 2 * $pad; $bh = $h + 2 * $pad

    $sx = $X1 - $ox; $sy = $Y1 - $oy
    $ex = $X2 - $ox; $ey = $Y2 - $oy

    $dx = $ex - $sx; $dy = $ey - $sy
    $len = [Math]::Sqrt([double]($dx * $dx + $dy * $dy))
    if ($len -lt 1) { $len = 1 }
    # Unit normal to the line - wobble is applied across the direction of travel.
    $nx = -$dy / $len; $ny = $dx / $len
    $amp = $len * 0.10

    $pts = @()
    for ($i = 0; $i -le 12; $i++) {
        $t = $i / 12.0
        # Taper the wobble to nothing at both ends: the tail leaves the note
        # cleanly and the head lands exactly on the target.
        $taper = [Math]::Sin([Math]::PI * $t)
        # A held bow plus a small per-point tremor, which is what a drawn line has.
        $bow = 0.55 * (Get-Jitter -Seed $Seed -Index 0)
        $off = ($bow + 0.45 * (Get-Jitter -Seed $Seed -Index ($i + 1))) * $amp * $taper
        $pts += @{
            X = [int]($sx + $dx * $t + $nx * $off)
            Y = [int]($sy + $dy * $t + $ny * $off)
        }
    }

    $path = New-Object System.Text.StringBuilder
    [void]$path.Append(('<a:moveTo><a:pt x="{0}" y="{1}"/></a:moveTo>' -f $pts[0].X, $pts[0].Y))
    for ($i = 1; $i -le 10; $i += 3) {
        [void]$path.Append(('<a:cubicBezTo><a:pt x="{0}" y="{1}"/><a:pt x="{2}" y="{3}"/><a:pt x="{4}" y="{5}"/></a:cubicBezTo>' -f `
            $pts[$i].X, $pts[$i].Y, $pts[$i + 1].X, $pts[$i + 1].Y, $pts[$i + 2].X, $pts[$i + 2].Y))
    }

    return @"
<wps:wsp>
  <wps:cNvPr id="$Id" name="Arrow $Id"/>
  <wps:cNvSpPr/>
  <wps:spPr>
    <a:xfrm><a:off x="$ox" y="$oy"/><a:ext cx="$bw" cy="$bh"/></a:xfrm>
    <a:custGeom>
      <a:avLst/><a:gdLst/><a:ahLst/><a:cxnLst/>
      <a:rect l="0" t="0" r="$bw" b="$bh"/>
      <a:pathLst><a:path w="$bw" h="$bh">$($path.ToString())</a:path></a:pathLst>
    </a:custGeom>
    <a:noFill/>
    <a:ln w="$Width" cap="rnd">
      <a:solidFill><a:srgbClr val="$Colour"/></a:solidFill>
      <a:round/>
      <a:tailEnd type="triangle" w="med" len="med"/>
    </a:ln>
  </wps:spPr>
  <wps:bodyPr/>
</wps:wsp>
"@
}

function New-MarkerXml {
    <#
      A numbered ring at the point the arrow lands, matching the number on the
      note. Where two arrows cross - and on a dense page they will - the number
      is what resolves which note belongs to which spot. The arrow alone is not
      enough, and a student should never have to guess.
    #>
    param([int]$Id, [int]$Cx, [int]$Cy, [int]$Size, [string]$Label, [string]$Colour = 'C00000')
    $x = $Cx - [int]($Size / 2); $y = $Cy - [int]($Size / 2)
    $half = [Math]::Max(14, [int]($Size / $EMU_PER_PT))
    $t = ConvertTo-XmlText $Label
    return @"
<wps:wsp>
  <wps:cNvPr id="$Id" name="Marker $Id"/>
  <wps:cNvSpPr/>
  <wps:spPr>
    <a:xfrm><a:off x="$x" y="$y"/><a:ext cx="$Size" cy="$Size"/></a:xfrm>
    <a:prstGeom prst="ellipse"><a:avLst/></a:prstGeom>
    <a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill>
    <a:ln w="19050"><a:solidFill><a:srgbClr val="$Colour"/></a:solidFill></a:ln>
  </wps:spPr>
  <wps:txbx><w:txbxContent>
    <w:p><w:pPr><w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/><w:jc w:val="center"/></w:pPr>
      <w:r><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:b/><w:color w:val="$Colour"/><w:sz w:val="$half"/><w:szCs w:val="$half"/></w:rPr>
      <w:t xml:space="preserve">$t</w:t></w:r></w:p>
  </w:txbxContent></wps:txbx>
  <wps:bodyPr rot="0" wrap="none" lIns="0" tIns="0" rIns="0" bIns="0" anchor="ctr" anchorCtr="1"><a:noAutofit/></wps:bodyPr>
</wps:wsp>
"@
}

function New-OutcomeChipXml {
    <#
      The outcome, in the right-hand column, level with the answer it judges.

      NOT YET SATISFACTORY IS A SOLID BLUE PANEL WITH WHITE TYPE. The page it
      sits beside is already carrying red and green - the marked copy's own
      outcome lines, the instrument's headings - so a red panel competes with
      what is underneath it and a green one reads as a pass at a glance. Blue
      appears nowhere else in these documents, which is the whole point: the
      student finds every panel to act on by colour alone, without reading.

      Satisfactory is deliberately quiet: an outline, no fill, green type. It
      confirms the part was looked at and passed, and it must not draw the eye
      away from the panels that need work.
    #>
    param(
        [int]$Id, [int]$X, [int]$Y, [int]$Cx, [int]$Cy,
        [string]$Label, [string]$Issue, [string]$Action, [string]$Number,
        [bool]$IsNys
    )
    if ($IsNys) {
        $fill = '1F4E79'; $line = '14395B'; $headColour = 'FFFFFF'
        $bodyColour = 'FFFFFF'; $noteColour = 'DCE9F5'
        $heading = 'Not yet Satisfactory'
    } else {
        $fill = 'FFFFFF'; $line = 'A9C7A9'; $headColour = '1E7B34'
        $bodyColour = '1A1A1A'; $noteColour = '404040'
        $heading = 'Satisfactory'
    }
    $tag = if ($Number) { "$Number.  $Label" } else { "$Label" }
    $head = ConvertTo-XmlText $tag
    $verdict = ConvertTo-XmlText $heading

    $body = New-Object System.Text.StringBuilder
    [void]$body.Append(@"
<w:p><w:pPr><w:spacing w:before="0" w:after="20" w:line="240" w:lineRule="auto"/></w:pPr>
<w:r><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:b/><w:color w:val="$headColour"/><w:sz w:val="16"/><w:szCs w:val="16"/></w:rPr>
<w:t xml:space="preserve">$head</w:t></w:r></w:p>
<w:p><w:pPr><w:spacing w:before="0" w:after="40" w:line="240" w:lineRule="auto"/></w:pPr>
<w:r><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:b/><w:color w:val="$headColour"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>
<w:t xml:space="preserve">$verdict</w:t></w:r></w:p>
"@)
    foreach ($line2 in @(
        @{ T = $Issue;  I = $false; C = $bodyColour },
        @{ T = $Action; I = $true;  C = $noteColour })) {
        if (-not $line2.T) { continue }
        $it = if ($line2.I) { '<w:i/>' } else { '' }
        $tx = ConvertTo-XmlText $line2.T
        [void]$body.Append(@"
<w:p><w:pPr><w:spacing w:before="0" w:after="40" w:line="240" w:lineRule="auto"/></w:pPr>
<w:r><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/>$it<w:color w:val="$($line2.C)"/><w:sz w:val="15"/><w:szCs w:val="15"/></w:rPr>
<w:t xml:space="preserve">$tx</w:t></w:r></w:p>
"@)
    }
    return @"
<wps:wsp>
  <wps:cNvPr id="$Id" name="Note $Id"/>
  <wps:cNvSpPr/>
  <wps:spPr>
    <a:xfrm><a:off x="$X" y="$Y"/><a:ext cx="$Cx" cy="$Cy"/></a:xfrm>
    <a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 8000"/></a:avLst></a:prstGeom>
    <a:solidFill><a:srgbClr val="$fill"/></a:solidFill>
    <a:ln w="12700"><a:solidFill><a:srgbClr val="$line"/></a:solidFill></a:ln>
  </wps:spPr>
  <wps:txbx><w:txbxContent>$($body.ToString())</w:txbxContent></wps:txbx>
  <wps:bodyPr rot="0" wrap="square" lIns="63000" tIns="36000" rIns="63000" bIns="36000" anchor="t"><a:normAutofit/></wps:bodyPr>
</wps:wsp>
"@
}

function New-CalloutXml {
    <#
      The note itself: the number, the label the feedback sheet uses for this
      row, the issue and the action. The wording is the ledger's, unchanged -
      this is the same row the Student Feedback Sheet prints.
    #>
    param(
        [int]$Id, [int]$X, [int]$Y, [int]$Cx, [int]$Cy,
        [string]$Label, [string]$Issue, [string]$Action, [string]$Number,
        [string]$Colour = 'C00000'
    )
    $head = ConvertTo-XmlText ("{0}.  {1}" -f $Number, $Label)
    $body = New-Object System.Text.StringBuilder
    [void]$body.Append(@"
<w:p><w:pPr><w:spacing w:before="0" w:after="40" w:line="240" w:lineRule="auto"/></w:pPr>
<w:r><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:b/><w:color w:val="$Colour"/><w:sz w:val="17"/><w:szCs w:val="17"/></w:rPr>
<w:t xml:space="preserve">$head</w:t></w:r></w:p>
"@)
    foreach ($line in @(
        @{ T = $Issue;  I = $false; C = '1A1A1A' },
        @{ T = $Action; I = $true;  C = '404040' })) {
        if (-not $line.T) { continue }
        $it = if ($line.I) { '<w:i/>' } else { '' }
        $tx = ConvertTo-XmlText $line.T
        [void]$body.Append(@"
<w:p><w:pPr><w:spacing w:before="0" w:after="40" w:line="240" w:lineRule="auto"/></w:pPr>
<w:r><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/>$it<w:color w:val="$($line.C)"/><w:sz w:val="16"/><w:szCs w:val="16"/></w:rPr>
<w:t xml:space="preserve">$tx</w:t></w:r></w:p>
"@)
    }
    return @"
<wps:wsp>
  <wps:cNvPr id="$Id" name="Note $Id"/>
  <wps:cNvSpPr/>
  <wps:spPr>
    <a:xfrm><a:off x="$X" y="$Y"/><a:ext cx="$Cx" cy="$Cy"/></a:xfrm>
    <a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 6000"/></a:avLst></a:prstGeom>
    <a:solidFill><a:srgbClr val="FFF6F6"/></a:solidFill>
    <a:ln w="12700"><a:solidFill><a:srgbClr val="$Colour"/></a:solidFill></a:ln>
  </wps:spPr>
  <wps:txbx><w:txbxContent>$($body.ToString())</w:txbxContent></wps:txbx>
  <wps:bodyPr rot="0" wrap="square" lIns="72000" tIns="45000" rIns="72000" bIns="45000" anchor="t"><a:normAutofit/></wps:bodyPr>
</wps:wsp>
"@
}

function New-PageCanvasParagraph {
    <#
      One source page becomes one canvas: the page picture on the left, the
      notes down the right, arrows between them. Everything lives in a single
      drawing so the note, the arrow and the point it lands on are placed in
      one coordinate space and cannot be re-flowed apart from each other.
    #>
    param($Page, [int]$StartId, [string]$RelId, [int]$CanvasW, [int]$CanvasH,
          [int]$ImgW, [int]$ImgH, [int]$GutterW)

    $id = $StartId
    $canvasId = $id; $id++
    $shapes = New-Object System.Text.StringBuilder

    [void]$shapes.Append((New-PagePictureXml -Id $id -RelId $RelId -X 0 -Y 0 -Cx $ImgW -Cy $ImgH)); $id++

    $colX = $ImgW + $GutterW
    $colW = $CanvasW - $colX
    $markerSize = [int](0.62 * $EMU_PER_CM)

    # Arrows first so the panels and the markers sit on top of their tails. A
    # pass gets a thin grey leader; a fail gets the blue arrow, weighted to
    # match its panel so the eye follows one to the other.
    foreach ($c in $Page.Callouts) {
        $isNys = ($c.Outcome -eq 'NYS')
        [void]$shapes.Append((New-ScribbleArrowXml -Id $id `
            -X1 ($colX + 45000) -Y1 ([int]($c.BoxY + $c.BoxH / 2)) `
            -X2 ([int]$c.TargetX) -Y2 ([int]$c.TargetY) `
            -Colour $(if ($isNys) { '1F4E79' } else { 'A6A6A6' }) `
            -Width $(if ($isNys) { 19050 } else { 9525 }) `
            -Seed $c.Seed)); $id++
    }
    foreach ($c in $Page.Callouts) {
        $isNys = ($c.Outcome -eq 'NYS')
        # Only a numbered fail gets a ring. Ringing every pass would put a
        # circle beside every answer on the page and leave the student hunting
        # for the ones that matter.
        if ($isNys -and $c.Number) {
            [void]$shapes.Append((New-MarkerXml -Id $id -Cx ([int]$c.TargetX) -Cy ([int]$c.TargetY) `
                -Size $markerSize -Label $c.Number -Colour '1F4E79')); $id++
        }
        [void]$shapes.Append((New-OutcomeChipXml -Id $id -X $colX -Y ([int]$c.BoxY) -Cx $colW -Cy ([int]$c.BoxH) `
            -Label $c.Label -Issue $c.Issue -Action $c.Action -Number $c.Number -IsNys $isNys)); $id++
    }

    $xml = @"
<w:p>
  <w:pPr><w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/><w:jc w:val="left"/></w:pPr>
  <w:r>
    <w:drawing>
      <wp:inline distT="0" distB="0" distL="0" distR="0">
        <wp:extent cx="$CanvasW" cy="$CanvasH"/>
        <wp:effectExtent l="0" t="0" r="0" b="0"/>
        <wp:docPr id="$canvasId" name="Annotated page $canvasId" descr="Page $($Page.Number) of the marked assessment with assessor notes"/>
        <wp:cNvGraphicFramePr/>
        <a:graphic>
          <a:graphicData uri="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas">
            <wpc:wpc><wpc:bg/><wpc:whole/>$($shapes.ToString())</wpc:wpc>
          </a:graphicData>
        </a:graphic>
      </wp:inline>
    </w:drawing>
  </w:r>
</w:p>
"@
    return @{ Xml = $xml; NextId = $id }
}

# ------------------------------------------------------------- the docx parts

function New-AnnotatedDocx {
    <#
      Assembles the parts and hands the zipping to Lib-Docx's Save-Docx, which
      is the one place in this skill that knows an OPC entry name takes a
      forward slash. Rewriting that here would reintroduce a bug that has
      already cost a delivered batch.
    #>
    param([string]$Destination, [string]$Title, [string[]]$PageImages, [string[]]$PageXml,
          [string]$Orientation, [string]$WorkRoot)

    $work = Join-Path $WorkRoot ('pkg_' + [Guid]::NewGuid().ToString('N'))
    [void](New-Item -ItemType Directory -Path $work)
    [void](New-Item -ItemType Directory -Path (Join-Path $work '_rels'))
    [void](New-Item -ItemType Directory -Path (Join-Path $work 'word'))
    [void](New-Item -ItemType Directory -Path (Join-Path $work 'word\_rels'))
    [void](New-Item -ItemType Directory -Path (Join-Path $work 'word\media'))

    $enc = New-Object System.Text.UTF8Encoding($false)

    $ct = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="png" ContentType="image/png"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>
'@
    [System.IO.File]::WriteAllText((Join-Path $work '[Content_Types].xml'), $ct, $enc)

    $rels = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
'@
    [System.IO.File]::WriteAllText((Join-Path $work '_rels\.rels'), $rels, $enc)

    $docRels = New-Object System.Text.StringBuilder
    [void]$docRels.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' + "`r`n")
    [void]$docRels.Append('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">')
    for ($i = 0; $i -lt $PageImages.Count; $i++) {
        $name = 'page{0:d3}.png' -f ($i + 1)
        Copy-Item -LiteralPath $PageImages[$i] -Destination (Join-Path $work ('word\media\' + $name)) -Force
        [void]$docRels.Append(('<Relationship Id="rIdImg{0}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/{1}"/>' -f ($i + 1), $name))
    }
    [void]$docRels.Append('</Relationships>')
    [System.IO.File]::WriteAllText((Join-Path $work 'word\_rels\document.xml.rels'), $docRels.ToString(), $enc)

    if ($Orientation -eq 'Landscape') { $pgW = 16838; $pgH = 11906; $orientAttr = ' w:orient="landscape"' }
    else                              { $pgW = 11906; $pgH = 16838; $orientAttr = '' }
    $mar = 680   # 1.2 cm in twips

    $titleX = ConvertTo-XmlText $Title
    $body = New-Object System.Text.StringBuilder
    [void]$body.Append(@"
<w:p><w:pPr><w:spacing w:before="0" w:after="120" w:line="240" w:lineRule="auto"/></w:pPr>
<w:r><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:b/><w:color w:val="1A1A1A"/><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr>
<w:t xml:space="preserve">$titleX</w:t></w:r></w:p>
"@)
    for ($i = 0; $i -lt $PageXml.Count; $i++) {
        [void]$body.Append($PageXml[$i])
        if ($i -lt $PageXml.Count - 1) {
            [void]$body.Append('<w:p><w:pPr><w:spacing w:before="0" w:after="0"/></w:pPr><w:r><w:br w:type="page"/></w:r></w:p>')
        }
    }
    [void]$body.Append(@"
<w:sectPr>
  <w:pgSz w:w="$pgW" w:h="$pgH"$orientAttr/>
  <w:pgMar w:top="$mar" w:right="$mar" w:bottom="$mar" w:left="$mar" w:header="0" w:footer="0" w:gutter="0"/>
</w:sectPr>
"@)

    $doc = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document
  xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"
  xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
  xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape">
  <w:body>$($body.ToString())</w:body>
</w:document>
"@
    $docPath = Join-Path $work 'word\document.xml'
    [System.IO.File]::WriteAllText($docPath, $doc, $enc)

    $xml = New-Object System.Xml.XmlDocument
    $xml.PreserveWhitespace = $true
    $xml.Load($docPath)

    return (Save-Docx -Package ([pscustomobject]@{ Xml = $xml; DocPath = $docPath; Work = $work }) -Destination $Destination)
}

# --------------------------------------------------------------------- main

# Lib-Docx asks for System.IO.Compression.FileSystem, which carries ZipFile but
# not ZipArchiveMode. Save-Docx uses ZipArchive directly, so the core compression
# assembly has to be named too, or the save dies at the last step of a build that
# has already done all its work.
Add-Type -AssemblyName System.IO.Compression
. (Join-Path $PSScriptRoot 'Lib-Docx.ps1')

$ledgerPath = (Resolve-Path -LiteralPath $Ledger).Path
$L = Get-Content -LiteralPath $ledgerPath -Raw -Encoding UTF8 | ConvertFrom-Json
$markedRoot = (Resolve-Path -LiteralPath $MarkedDir).Path
$dst = if ($OutDir) { $OutDir } else { $markedRoot }
if (-not (Test-Path -LiteralPath $dst)) { [void](New-Item -ItemType Directory -Path $dst -Force) }
$dst = (Resolve-Path -LiteralPath $dst).Path

$copies = @($L.markedCopies)
if ($copies.Count -eq 0) {
    Write-Output 'No markedCopies in the ledger, so there is nothing to annotate.'
    return
}

$workRoot = Join-Path $env:TEMP ('annfb_' + [Guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $workRoot)

$built = @()
$skipped = @()
$unplacedTotal = 0
$strayOutcomes = @()
$outcomeFacts = @()
$copyIndex = 0
try {
foreach ($copy in $copies) {
    $markedPath = Join-Path $markedRoot $copy.file
    if (-not (Test-Path -LiteralPath $markedPath)) {
        $skipped += ('{0}: no marked copy at {1}' -f $copy.studentId, $copy.file)
        continue
    }
    $student = @($L.students | Where-Object { $_.studentId -eq $copy.studentId })[0]
    if (-not $student) { $skipped += ('{0}: not in the ledger' -f $copy.studentId); continue }

    # EVERY question gets an entry, not only the ones with something to fix. A
    # column showing only failures tells the student where they went wrong and
    # nothing about the rest, so a page with no note on it is ambiguous - was it
    # right, or was it not looked at? Showing both outcomes answers that on
    # every page, and it is the same judgement the marked copy already carries.
    $wanted = @()
    $anchorsNeeded = @()
    $orphanItems = @()
    foreach ($toolId in @($copy.toolIds)) {
        $res = @($student.results | Where-Object { $_.toolId -eq $toolId })[0]
        if (-not $res) { continue }
        $questions = @($res.questions)
        $items = @($res.items)

        # Which item, if any, speaks for each question.
        $claimed = @{}
        foreach ($q in $questions) {
            $match = $null
            foreach ($item in $items) {
                $refs = @()
                if ($item.PSObject.Properties.Name -contains 'questionNos' -and $item.questionNos) {
                    $refs = @($item.questionNos)
                } else {
                    $refs = @("$($item.questionNo)")
                }
                if ($refs -contains "$($q.ref)") { $match = $item; break }
            }
            # ONE ITEM CAN COVER A RUN OF QUESTIONS. Its words go on the first
            # question it covers; the rest carry the outcome alone. Repeating a
            # paragraph down ten chips would bury the page it is printed beside.
            $key = if ($match) { "$($match.questionNo)" } else { $null }
            $first = $false
            if ($key -and -not $claimed.ContainsKey($key)) { $claimed[$key] = $true; $first = $true }
            $wanted += [pscustomobject]@{
                Ref     = "$($q.ref)"
                Outcome = "$($q.outcome)"
                Label   = if ($match -and $first) { "$($match.questionNo)" } else { "$($q.ref)" }
                Issue   = if ($match -and $first) { "$($match.issue)" }  else { '' }
                Action  = if ($match -and $first) { "$($match.action)" } else { '' }
                Anchor  = "$($q.anchor)"
                Next    = $null
            }
        }
        for ($i = 0; $i -lt $questions.Count; $i++) {
            $anchorsNeeded += $questions[$i].anchor
            if ($i + 1 -lt $questions.Count) {
                $wanted[$wanted.Count - $questions.Count + $i].Next = "$($questions[$i + 1].anchor)"
            }
        }
        if ($res.PSObject.Properties.Name -contains 'questionsEndAnchor' -and $res.questionsEndAnchor) {
            $anchorsNeeded += "$($res.questionsEndAnchor)"
            if ($questions.Count -gt 0) {
                $wanted[$wanted.Count - 1].Next = "$($res.questionsEndAnchor)"
            }
        }

        # An item that names no question in this tool - a recipe card, an
        # observation item - has nothing to sit beside. It is printed at the end
        # rather than dropped.
        foreach ($item in $items) {
            if (-not $claimed.ContainsKey("$($item.questionNo)")) {
                $orphanItems += [pscustomobject]@{
                    Label = "$($item.questionNo)"; Issue = "$($item.issue)"; Action = "$($item.action)"
                }
            }
        }
    }

    if ($wanted.Count -eq 0 -and $orphanItems.Count -eq 0) {
        # Nothing judged question by question, so there is nothing to place.
        continue
    }

    # SCRATCH PATHS ARE PER COPY, NOT PER STUDENT. A student whose tools arrived
    # as separate files has several marked copies under one studentId, and
    # naming the working directory after the student made the second copy
    # collide with the first.
    $copyIndex++
    $stem = '{0}_{1:d3}' -f $copy.studentId, $copyIndex
    $pdfPath = Join-Path $workRoot ($stem + '.pdf')
    $targets = @($wanted | Where-Object { $_.Anchor } |
        ForEach-Object { [pscustomobject]@{ Anchor = $_.Anchor; Next = $_.Next; Outcome = $_.Outcome } })
    # -Timing prints how long each stage took. Word COM and the PDF renderer are
    # both slow enough, and variable enough between instruments, that "it is
    # taking a while" is not a diagnosis; this says which stage to look at.
    $stageWatch = [Diagnostics.Stopwatch]::StartNew()
    function Write-Stage { param([string]$Name)
        if ($Timing) { Write-Output ("  [t] {0,-16} {1,6:n1}s" -f $Name, $stageWatch.Elapsed.TotalSeconds) }
        $stageWatch.Restart()
    }

    $geo = Get-AnchorGeometry -DocPath $markedPath -Anchors (@($anchorsNeeded | Sort-Object -Unique)) `
        -Targets $targets -PdfPath $pdfPath

    Write-Stage 'geometry+pdf'
    $pageDir = Join-Path $workRoot ($stem + '_pages')
    [void](New-Item -ItemType Directory -Path $pageDir -Force)
    $imgWidthPx = [int](($geo.PageWidthPt / 72.0) * $Dpi)
    $images = @(Export-PdfPageImages -PdfPath $pdfPath -OutFolder $pageDir -WidthPx $imgWidthPx)

    Write-Stage 'render pages'
    # ---- geometry of one output page
    $marginCm = 1.2
    if ($Orientation -eq 'Landscape') { $pgWcm = 29.7; $pgHcm = 21.0 } else { $pgWcm = 21.0; $pgHcm = 29.7 }
    $textW = [int](($pgWcm - 2 * $marginCm) * $EMU_PER_CM)
    $textH = [int](($pgHcm - 2 * $marginCm) * $EMU_PER_CM) - [int](1.5 * $EMU_PER_CM)   # less the title line, which can wrap to two
    $ratio = $geo.PageHeightPt / $geo.PageWidthPt
    $gutter = [int](0.35 * $EMU_PER_CM)

    # THE PAGE IS NARROWED, NOT SHRUNK. Scaling both dimensions to 75% keeps the
    # proportions but costs a third of the page height, so the student's work
    # ends half way down and the foot of every sheet is blank. Here the height
    # is left at the full text height and only the WIDTH is taken to $PageScale,
    # which opens the column on the right without giving up any of the page.
    #
    # The type is therefore about a quarter narrower than it was printed. It
    # stays legible - this is the same squeeze a condensed face applies - but it
    # is not a facsimile, which is why -KeepAspect is here for anyone who needs
    # the returned work to measure true.
    if ($Orientation -eq 'Landscape') {
        $imgH = $textH
        $imgW = [int]($imgH / $ratio)
    } elseif ($KeepAspect) {
        $imgW = [int]($textW * $PageScale)
        $imgH = [int]($imgW * $ratio)
        if ($imgH -gt $textH) { $imgH = $textH; $imgW = [int]($imgH / $ratio) }
    } else {
        $imgW = [int]($textW * $PageScale)
        $imgH = $textH
    }
    $canvasW = $textW
    $canvasH = $imgH
    $colW = $canvasW - ($imgW + $gutter)

    # ---- place every note on the page its target falls on
    $pages = @{}
    $unplaced = @()
    $n = 0
    foreach ($w in $wanted) {
        # Only a fail that carries feedback is numbered. The numbers pair a
        # panel with its ring, and a student told to "fix items 1 to 4" should
        # be able to count four rings - not find twenty-eight because every
        # pass was numbered too.
        $number = ''
        if ($w.Outcome -eq 'NYS' -and $w.Issue) { $n++; $number = "$n" }
        $hit = if ($w.Anchor -and $geo.Anchors.ContainsKey($w.Anchor)) { $geo.Anchors[$w.Anchor] } else { $null }
        if (-not $hit) {
            # A pass with no findable anchor is simply not shown; a FAIL that
            # cannot be placed still has to reach the student, so it goes to the
            # closing block.
            if ($w.Outcome -eq 'NYS' -and $w.Issue) {
                $unplaced += [pscustomobject]@{ Number = $number; Item = $w }
            }
            continue
        }
        $nextHit = if ($w.Next -and $geo.Anchors.ContainsKey($w.Next)) { $geo.Anchors[$w.Next] } else { $null }

        # THE NOTE SITS LEVEL WITH THE MIDDLE OF THE ANSWER.
        #
        # Three candidates, in order. The centre of the response box is the one
        # that matters: it is the middle of what the student wrote, so the note
        # lands beside the answer rather than beside an edge of it. The verdict
        # line is the fallback - it sits at the FOOT of the response, which on a
        # long answer is most of a page below where the student was writing, and
        # a note pinned there reads as a remark about the last sentence. Half
        # way to the next anchor is the last resort, and on a question whose
        # stem runs to a paragraph that is still inside the stem.
        $outcomeHit = if ($w.Anchor -and $geo.Outcomes.ContainsKey($w.Anchor)) { $geo.Outcomes[$w.Anchor] } else { $null }
        $boxHit = if ($w.Anchor -and $geo.Boxes.ContainsKey($w.Anchor)) { $geo.Boxes[$w.Anchor] } else { $null }
        if ($outcomeHit) {
            # Collected now, judged once the whole document has been read. A
            # page-distance test cannot do this job: a long answer legitimately
            # runs its verdict onto the next page, so distance flags correct
            # work and misses the case where the verdict sits one page on, in
            # the next task's heading block. Whether it is INSIDE the response
            # box is the question, and that is answered structurally.
            $outcomeFacts += [pscustomobject]@{
                Student = $copy.studentId; Label = $w.Label
                InTable = [bool]$outcomeHit.InTable
                Page    = [int]$outcomeHit.Page; QPage = [int]$hit.Page
            }
        }
        if ($boxHit) {
            $hit = $boxHit
            $targetYpt = $boxHit.Y
        } elseif ($outcomeHit) {
            $hit = $outcomeHit
            $targetYpt = $outcomeHit.Y
        } elseif ($nextHit -and $nextHit.Page -eq $hit.Page -and $nextHit.Y -gt $hit.Y) {
            $targetYpt = ($hit.Y + $nextHit.Y) / 2.0
        } else {
            $targetYpt = $hit.Y + 34.0
        }
        if ($targetYpt -gt ($geo.PageHeightPt - 24)) { $targetYpt = $geo.PageHeightPt - 24 }
        # Land at the RIGHT edge of the text column, not in the middle of it. The
        # middle is where the student actually wrote their answer, so a marker there
        # sits on top of their words - and the note it belongs to is off to the
        # right anyway, which makes this the shorter arrow as well.
        $targetXpt = $geo.PageWidthPt - $hit.X - 10.0

        $pageNo = [int]$hit.Page
        if (-not $pages.ContainsKey($pageNo)) { $pages[$pageNo] = @() }
        $pages[$pageNo] += [pscustomobject]@{
            Number  = $number
            Outcome = $w.Outcome
            Label   = $w.Label
            Issue   = $w.Issue
            Action  = $w.Action
            Seed    = ($copy.studentId + '|' + $w.Ref + '|' + $w.Label)
            TargetX = [int](($targetXpt / $geo.PageWidthPt) * $imgW)
            TargetY = [int](($targetYpt / $geo.PageHeightPt) * $imgH)
            BoxY    = 0
            BoxH    = 0
        }
    }
    # ---- stack the notes so none overlaps another
    $colWpt = $colW / [double]$EMU_PER_PT
    $gap = [int](0.20 * $EMU_PER_CM)
    foreach ($pageNo in @($pages.Keys)) {
        $list = @($pages[$pageNo] | Sort-Object TargetY)
        foreach ($c in $list) {
            # Two lines before any feedback: the question's label, then the
            # verdict itself.
            $lines = 2 + (Get-EstimatedLines -Text $c.Issue -BoxWidthPt $colWpt -FontPt 7.5) +
                         (Get-EstimatedLines -Text $c.Action -BoxWidthPt $colWpt -FontPt 7.5)
            $c.BoxH = [int](($lines * 11.0 + 14.0) * $EMU_PER_PT)
        }
        # Down pass: each note wants to sit beside its target, and gives way to
        # the note above it.
        $cursor = 0
        foreach ($c in $list) {
            $want = [int]($c.TargetY - $c.BoxH / 2)
            $c.BoxY = [Math]::Max($want, $cursor)
            $cursor = $c.BoxY + $c.BoxH + $gap
        }
        # Up pass: if the stack ran off the bottom, push it back inside. Notes
        # that no longer sit beside their target still carry a numbered marker,
        # so the pairing survives the move.
        $overflow = $cursor - $gap - $canvasH
        if ($overflow -gt 0) {
            $shift = $overflow
            for ($i = $list.Count - 1; $i -ge 0; $i--) {
                $list[$i].BoxY = $list[$i].BoxY - $shift
                if ($list[$i].BoxY -lt 0) { $list[$i].BoxY = 0 }
                if ($i -gt 0) {
                    $room = $list[$i].BoxY - ($list[$i - 1].BoxY + $list[$i - 1].BoxH + $gap)
                    if ($room -ge 0) { $shift = 0 } else { $shift = -$room }
                }
            }
        }
        $pages[$pageNo] = $list
    }

    # The WHOLE assessment by default, not only the pages carrying an outcome,
    # so the student reads one document end to end - their work, with the
    # remarks where the remarks belong - instead of an extract that makes them
    # fetch the marked copy to see what came before and after.
    if (-not $NotedPagesOnly) {
        for ($p = 1; $p -le $images.Count; $p++) {
            if (-not $pages.ContainsKey($p)) { $pages[$p] = @() }
        }
    }

    # ---- one canvas per source page that carries a note
    $pageXml = @()
    $id = 1000
    $noted = @($pages.Keys | Sort-Object)
    foreach ($pageNo in $noted) {
        if ($pageNo -lt 1 -or $pageNo -gt $images.Count) { continue }
        $built1 = New-PageCanvasParagraph -Page ([pscustomobject]@{ Number = $pageNo; Callouts = $pages[$pageNo] }) `
            -StartId $id -RelId ('rIdImg' + $pageNo) -CanvasW $canvasW -CanvasH $canvasH `
            -ImgW $imgW -ImgH $imgH -GutterW $gutter
        $pageXml += $built1.Xml
        $id = $built1.NextId
    }

    # A map with no arrow on it is the feedback sheet again, behind a picture of
    # the cover page. It tells the student nothing they were not already given,
    # so it is not built - and the reason is reported, rather than left to be
    # noticed later as a file that never appeared.
    #
    # Counted from the outcomes actually placed, not from $pages.Keys: under
    # by default every page of the document has an entry, and most of them are
    # empty, so a key count would call a map of nothing a map of something.
    $placedCount = 0
    foreach ($k in $pages.Keys) { $placedCount += @($pages[$k]).Count }
    if ($placedCount -eq 0) {
        $skipped += ('{0}: no outcome could be anchored to a question, so no map was built' -f $copy.studentId)
        continue
    }

    # Counted only now that a map is certainly being built. Counting earlier
    # reported notes as "listed at the end of the map" for a student whose map
    # was then skipped, which is a summary describing a document that does not
    # exist.
    # Items that named no question at all join the ones whose anchor could not
    # be found: both are feedback the student must still receive.
    foreach ($o in $orphanItems) {
        $n++
        $unplaced += [pscustomobject]@{ Number = "$n"; Item = $o }
    }
    $unplacedTotal += $unplaced.Count

    # ---- anything that could not be placed is still printed, never dropped
    if ($unplaced.Count -gt 0) {
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.Append('<w:p><w:pPr><w:spacing w:before="200" w:after="80"/></w:pPr><w:r><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:b/><w:color w:val="C00000"/><w:sz w:val="18"/></w:rPr><w:t xml:space="preserve">Also on your feedback sheet</w:t></w:r></w:p>')
        foreach ($u in $unplaced) {
            $h = ConvertTo-XmlText ("{0}.  {1}" -f $u.Number, $u.Item.Label)
            $iss = ConvertTo-XmlText $u.Item.Issue
            $act = ConvertTo-XmlText $u.Item.Action
            [void]$sb.Append("<w:p><w:pPr><w:spacing w:before='80' w:after='20'/></w:pPr><w:r><w:rPr><w:rFonts w:ascii='Arial' w:hAnsi='Arial'/><w:b/><w:color w:val='C00000'/><w:sz w:val='17'/></w:rPr><w:t xml:space='preserve'>$h</w:t></w:r></w:p>")
            [void]$sb.Append("<w:p><w:pPr><w:spacing w:before='0' w:after='20'/></w:pPr><w:r><w:rPr><w:rFonts w:ascii='Arial' w:hAnsi='Arial'/><w:color w:val='1A1A1A'/><w:sz w:val='16'/></w:rPr><w:t xml:space='preserve'>$iss</w:t></w:r></w:p>")
            [void]$sb.Append("<w:p><w:pPr><w:spacing w:before='0' w:after='60'/></w:pPr><w:r><w:rPr><w:rFonts w:ascii='Arial' w:hAnsi='Arial'/><w:i/><w:color w:val='404040'/><w:sz w:val='16'/></w:rPr><w:t xml:space='preserve'>$act</w:t></w:r></w:p>")
        }
        $pageXml += $sb.ToString()
    }

    if ($pageXml.Count -eq 0) { $skipped += ('{0}: nothing could be placed' -f $copy.studentId); continue }

    $name = $copy.file -replace '^MARKED_', 'ANNOTATED_'
    if ($name -eq $copy.file) { $name = 'ANNOTATED_' + $copy.file }
    $target = Join-Path $dst $name
    $title = '{0} - {1}. Your result on each part. Read this with your feedback sheet.' -f `
        $copy.student, $L.unit.code
    Write-Stage 'layout'
    [void](New-AnnotatedDocx -Destination $target -Title $title -PageImages $images -PageXml $pageXml `
        -Orientation $Orientation -WorkRoot $workRoot)
    Write-Stage 'write docx'
    $built += [pscustomobject]@{ File = $name; Notes = $wanted.Count; Placed = ($wanted.Count - $unplaced.Count); Pages = $noted.Count }
}
} finally {
    if (-not $KeepPages -and (Test-Path -LiteralPath $workRoot)) {
        Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Output ''
Write-Output ('Annotated feedback maps: {0}' -f $built.Count)
foreach ($b in $built) {
    Write-Output ('  {0}  -  {1} of {2} note(s) placed, {3} page(s) in the map' -f $b.File, $b.Placed, $b.Notes, $b.Pages)
}
if ($unplacedTotal -gt 0) {
    Write-Output ''
    Write-Output ("CHECK  {0} note(s) had no question anchor to point at and were listed at the end of the map instead." -f $unplacedTotal)
    Write-Output '       An item whose questionNo is a label rather than a question ref - a recipe card, an'
    Write-Output '       observation item - has nothing in the document to find. Give it a questionNos entry'
    Write-Output '       naming the question it belongs to if you want an arrow drawn to it.'
}
# ---- which verdicts never made it into a response box
#
# SELF-CALIBRATING, because not every instrument puts its responses in tables.
# Where most of this run's verdicts landed in a box, the handful that did not
# are the anomalies and are worth naming. Where hardly any did, the instrument
# simply does not work that way and the test says nothing rather than flagging
# every question in the document.
$withOutcome = @($outcomeFacts)
if ($withOutcome.Count -ge 5) {
    $inBox = @($withOutcome | Where-Object { $_.InTable })
    if ($inBox.Count -ge [int]($withOutcome.Count * 0.6)) {
        foreach ($o in @($withOutcome | Where-Object { -not $_.InTable })) {
            $strayOutcomes += ('{0} / {1}: verdict is on page {2}, outside any response box (question is on page {3})' -f `
                $o.Student, $o.Label, $o.Page, $o.QPage)
        }
    }
}

if ($strayOutcomes.Count -gt 0) {
    Write-Output ""
    Write-Output "CHECK  A verdict was found OUTSIDE the student's response box."
    Write-Output "       Most of this document's verdicts sit inside the box, under the answer they judge."
    Write-Output "       These did not: the walk-back overshot and left them in the NEXT task's heading"
    Write-Output "       block, so that response box comes back to the student empty. Fix the MARKED COPY."
    $strayOutcomes | ForEach-Object { Write-Output "         $_" }
}

if ($skipped.Count -gt 0) {
    Write-Output ''
    Write-Output 'NOT BUILT:'
    $skipped | ForEach-Object { Write-Output "  $_" }
}
if ($built.Count -eq 0) { throw 'No annotated feedback map was produced.' }
