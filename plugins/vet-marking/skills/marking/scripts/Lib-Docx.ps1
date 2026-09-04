# Lib-Docx.ps1 — OOXML helpers for filling supplied RTO marking templates.
#
# The templates are approved documents. We EDIT them: fill fields, tick boxes,
# clone and delete rows, insert a column. We never rebuild them. Headers,
# footers, styles, numbering and document properties are never touched.
#
# Everything works on the XML DOM, not on regex over document.xml. Row cloning
# and column insertion cannot be done safely with string surgery.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$script:W  = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
$script:BOX_EMPTY  = [char]0x2610   # U+2610 BALLOT BOX
$script:BOX_TICKED = [char]0x2612   # U+2612 BALLOT BOX WITH X

# ---------------------------------------------------------------- package ---

function Open-Docx {
    <#
      Expands a .docx into a working directory and returns a package handle.
      The handle carries the DOM for word/document.xml; save it with Save-Docx.
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$WorkRoot = $env:TEMP
    )
    if (-not (Test-Path -LiteralPath $Path)) { throw "Template not found: $Path" }

    $work = Join-Path $WorkRoot ("docx_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path -LiteralPath $Path).Path, $work)

    $docPath = Join-Path $work 'word\document.xml'
    if (-not (Test-Path -LiteralPath $docPath)) { throw "Not a Word document (no word/document.xml): $Path" }

    $xml = New-Object System.Xml.XmlDocument
    $xml.PreserveWhitespace = $true
    $xml.Load($docPath)

    $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $ns.AddNamespace('w', $script:W)

    [pscustomobject]@{
        Source   = (Resolve-Path -LiteralPath $Path).Path
        Work     = $work
        DocPath  = $docPath
        Xml      = $xml
        Ns       = $ns
        Body     = $xml.SelectSingleNode('//w:body', $ns)
    }
}

function Save-Docx {
    <#
      Writes the DOM back and rezips to $Destination. Any existing file at the
      destination is replaced. The working directory is removed unless -Keep.
    #>
    param(
        [Parameter(Mandatory)]$Package,
        [Parameter(Mandatory)][string]$Destination,
        [switch]$Keep
    )
    $Package.Xml.Save($Package.DocPath)

    $dir = Split-Path -Parent $Destination
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Force }

    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $Package.Work, $Destination,
        [System.IO.Compression.CompressionLevel]::Optimal, $false)

    if (-not $Keep) { Remove-Item -LiteralPath $Package.Work -Recurse -Force }
    $Destination
}

function Close-Docx {
    param([Parameter(Mandatory)]$Package)
    if (Test-Path -LiteralPath $Package.Work) { Remove-Item -LiteralPath $Package.Work -Recurse -Force }
}

# ------------------------------------------------------------------ runs ----

function Set-XmlSpacePreserve {
    <#
      Marks a w:t as whitespace-significant.

      This MUST use CreateAttribute with an explicit 'xml' prefix. The obvious
      call - SetAttribute('space', <the xml namespace>, 'preserve') - looks
      right and is not: XmlDocument invents a prefix for the reserved xml
      namespace and emits

          <w:t d8p1:space="preserve" xmlns:d8p1="http://www.w3.org/XML/1998/namespace">

      which is well-formed XML, passes every structural check, and makes Word
      refuse to open the document. Nothing short of opening the file in Word
      catches it.
    #>
    param($Node)
    $attr = $Node.OwnerDocument.CreateAttribute('xml', 'space', 'http://www.w3.org/XML/1998/namespace')
    $attr.Value = 'preserve'
    [void]$Node.Attributes.SetNamedItem($attr)
}

function Get-RunText {
    param($Node, $Ns)
    $sb = New-Object System.Text.StringBuilder
    foreach ($t in $Node.SelectNodes('.//w:t', $Ns)) { [void]$sb.Append($t.InnerText) }
    $sb.ToString()
}

function Set-RunAnswerStyle {
    <#
      A placeholder run is italic and grey. Filled content must not be: a
      finished record that still prints grey italic reads as an unfilled one.
      Drops i/iCs and forces the answer colour, leaving bold, size and font
      alone so the field keeps whatever weight the template gave it.
    #>
    param($Run, $Ns, [string]$Color = '000000')

    $rPr = $Run.SelectSingleNode('w:rPr', $Ns)
    if (-not $rPr) {
        $rPr = $Run.OwnerDocument.CreateElement('w', 'rPr', $script:W)
        [void]$Run.PrependChild($rPr)
    }
    foreach ($n in @($rPr.SelectNodes('w:i', $Ns)) + @($rPr.SelectNodes('w:iCs', $Ns))) {
        [void]$rPr.RemoveChild($n)
    }
    $col = $rPr.SelectSingleNode('w:color', $Ns)
    if (-not $col) {
        $col = $Run.OwnerDocument.CreateElement('w', 'color', $script:W)
        # w:color sits after the toggles in CT_RPr; appending is safe here because
        # the template's rPr carry only b/bCs/i/iCs/color/sz.
        [void]$rPr.AppendChild($col)
    }
    [void]$col.SetAttribute('val', $script:W, $Color)
}

function Set-TextInNode {
    <#
      Replaces $Find with $Replace across a subtree, at run level, preserving
      each run's formatting. Where a placeholder spans several runs (Word splits
      runs on spell-check and revision boundaries) the spanning runs in that
      paragraph are merged into the first before replacing.

      Returns the number of replacements made.
    #>
    param(
        [Parameter(Mandatory)]$Node,
        [Parameter(Mandatory)]$Ns,
        [Parameter(Mandatory)][string]$Find,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Replace,
        [switch]$AnswerStyle,
        [string]$Color = '000000',
        [int]$Limit = 0                     # 0 = replace every occurrence
    )
    $count = 0

    # './/w:p' selects DESCENDANT paragraphs, so handing this a w:p — the
    # natural thing to do when ticking one decision box out of a column of them
    # — matched nothing and replaced nothing, silently. A paragraph is its own
    # paragraph list.
    $targets = if ($Node.LocalName -eq 'p') { @($Node) } else { @($Node.SelectNodes('.//w:p', $Ns)) }

    foreach ($p in $targets) {
        if ($Limit -gt 0 -and $count -ge $Limit) { break }

        $full = Get-RunText $p $Ns
        if ($full.IndexOf($Find, [StringComparison]::Ordinal) -lt 0) { continue }

        $runs = @($p.SelectNodes('.//w:r[w:t]', $Ns))
        if ($runs.Count -eq 0) { continue }

        # Single run holding the whole placeholder — the common case.
        $hit = $null
        foreach ($r in $runs) {
            if ((Get-RunText $r $Ns).IndexOf($Find, [StringComparison]::Ordinal) -ge 0) { $hit = $r; break }
        }

        if ($hit) {
            $t = $hit.SelectSingleNode('.//w:t', $Ns)
            $txt = Get-RunText $hit $Ns
            # collapse a multi-w:t run into its first w:t
            foreach ($extra in @($hit.SelectNodes('.//w:t', $Ns))) {
                if (-not $extra.Equals($t)) { [void]$extra.ParentNode.RemoveChild($extra) }
            }
            if ($Limit -gt 0) {
                $i = $txt.IndexOf($Find, [StringComparison]::Ordinal)
                $new = $txt.Substring(0, $i) + $Replace + $txt.Substring($i + $Find.Length)
                $count++
            } else {
                $occ = ([regex]::Matches($txt, [regex]::Escape($Find))).Count
                $new = $txt.Replace($Find, $Replace)
                $count += $occ
            }
            $t.InnerText = $new
            Set-XmlSpacePreserve $t
            if ($AnswerStyle) { Set-RunAnswerStyle -Run $hit -Ns $Ns -Color $Color }
            continue
        }

        # Placeholder split across runs: merge the paragraph's runs into the first.
        $first = $runs[0]
        $ft = $first.SelectSingleNode('.//w:t', $Ns)
        if (-not $ft) { continue }
        foreach ($extra in @($first.SelectNodes('.//w:t', $Ns))) {
            if (-not $extra.Equals($ft)) { [void]$extra.ParentNode.RemoveChild($extra) }
        }
        $ft.InnerText = $full.Replace($Find, $Replace)
        Set-XmlSpacePreserve $ft
        for ($i = 1; $i -lt $runs.Count; $i++) { [void]$runs[$i].ParentNode.RemoveChild($runs[$i]) }
        $count += ([regex]::Matches($full, [regex]::Escape($Find))).Count
        if ($AnswerStyle) { Set-RunAnswerStyle -Run $first -Ns $Ns -Color $Color }
    }
    $count
}

function Set-Placeholder {
    <#
      Fills a bracketed field. $Name is the field name WITHOUT its brackets, e.g.
      'Insert student name'. Both '[ Insert student name ]' and
      '[Insert student name]' are matched, because a template author's spacing
      is not something a build should depend on.
    #>
    param(
        [Parameter(Mandatory)]$Node,
        [Parameter(Mandatory)]$Ns,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value,
        [string]$Color = '000000',
        [int]$Limit = 0
    )
    $n = 0
    foreach ($form in @("[ $Name ]", "[$Name]")) {
        $left = if ($Limit -gt 0) { $Limit - $n } else { 0 }
        if ($Limit -gt 0 -and $left -le 0) { break }
        $n += Set-TextInNode -Node $Node -Ns $Ns -Find $form -Replace $Value -AnswerStyle -Color $Color -Limit $left
    }
    $n
}

# ------------------------------------------------------------- checkboxes ---

function Set-BracketedBox {
    <#
      Turns the decision box '[ ☐ ]' into ☒ or ☐ and removes the brackets
      either way. Scope this to a single cell or row — the templates carry six
      of them and they are not interchangeable.
    #>
    param(
        [Parameter(Mandatory)]$Node,
        [Parameter(Mandatory)]$Ns,
        [Parameter(Mandatory)][bool]$Ticked,
        [int]$Limit = 0
    )
    $glyph = if ($Ticked) { $script:BOX_TICKED } else { $script:BOX_EMPTY }
    $n = 0
    foreach ($form in @("[ $($script:BOX_EMPTY) ]", "[$($script:BOX_EMPTY)]")) {
        $left = if ($Limit -gt 0) { $Limit - $n } else { 0 }
        if ($Limit -gt 0 -and $left -le 0) { break }
        $n += Set-TextInNode -Node $Node -Ns $Ns -Find $form -Replace "$glyph" -AnswerStyle -Limit $left
    }
    $n
}

function Set-LabelledBox {
    <#
      Flips a standing option line — '☐ Assessment completed' — to ☒, or back
      to ☐. The label is matched exactly, so 'Assessment completed' does not
      also hit 'Assessment not submitted'.
    #>
    param(
        [Parameter(Mandatory)]$Node,
        [Parameter(Mandatory)]$Ns,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][bool]$Ticked
    )
    $from = if ($Ticked) { $script:BOX_EMPTY } else { $script:BOX_TICKED }
    $to   = if ($Ticked) { $script:BOX_TICKED } else { $script:BOX_EMPTY }
    Set-TextInNode -Node $Node -Ns $Ns -Find "$from $Label" -Replace "$to $Label"
}

# ----------------------------------------------------------------- tables ---

function Get-Tables {
    param($Package)
    @($Package.Body.SelectNodes('.//w:tbl', $Package.Ns))
}

function Get-Rows {
    param($Table, $Ns)
    @($Table.SelectNodes('w:tr', $Ns))
}

function Get-Cells {
    param($Row, $Ns)
    @($Row.SelectNodes('w:tc', $Ns))
}

function Find-RowByText {
    <#
      Returns every row in $Table whose visible text contains all of $Contains.
      Row identity in these templates is text, not position — a template that
      gains a row must not silently shift a build's target.
    #>
    param($Table, $Ns, [string[]]$Contains)
    $out = @()
    foreach ($r in @(Get-Rows $Table $Ns)) {
        $txt = Get-RunText $r $Ns
        $ok = $true
        foreach ($c in $Contains) { if ($txt.IndexOf($c, [StringComparison]::Ordinal) -lt 0) { $ok = $false; break } }
        if ($ok) { $out += $r }
    }
    @($out)
}

function Copy-RowAfter {
    <#
      Deep-clones $Row and inserts the clone directly after it. Returns the clone.
      Used to grow a template's fixed row count to the real number of students,
      tools or feedback items.
    #>
    param($Row)
    $clone = $Row.CloneNode($true)
    [void]$Row.ParentNode.InsertAfter($clone, $Row)
    $clone
}

function Remove-Row {
    param($Row)
    [void]$Row.ParentNode.RemoveChild($Row)
}

function Set-RowCount {
    <#
      Makes a repeating block exactly $Count rows long by cloning or deleting
      from the end. $Rows must be the template's repeating rows, in order.
      Returns the final row list.
    #>
    param([object[]]$Rows, [int]$Count)
    if ($Rows.Count -eq 0) { throw 'Set-RowCount: no template rows supplied.' }
    if ($Count -lt 0) { throw "Set-RowCount: negative count ($Count)." }

    $list = [System.Collections.ArrayList]::new()
    foreach ($r in $Rows) { [void]$list.Add($r) }

    while ($list.Count -gt $Count) {
        $last = $list[$list.Count - 1]
        Remove-Row $last
        $list.RemoveAt($list.Count - 1)
    }
    while ($list.Count -lt $Count) {
        $clone = Copy-RowAfter $list[$list.Count - 1]
        [void]$list.Add($clone)
    }
    ,$list.ToArray()
}

function Add-TableColumn {
    <#
      Inserts a column into every row of $Table at index $At by cloning the cell
      already there, then rebalances the grid so the widths still sum to the
      table's declared width.

      Word re-flows a table whose column widths do not sum to its w:tblW, so the
      new column is paid for out of the columns it sits among, and the last
      column takes the rounding remainder.

      -WidenSpanRows names 1-based rows that must NOT receive a new cell: a
      grouped header row covers the new column with a gridSpan instead. Give
      such a row a cell of its own and the row ends up one cell wider than the
      grid, which is how a widened header grows a stray empty box.
    #>
    param($Table, $Ns, [int]$At, [int]$Width, [int[]]$WidenSpanRows = @())

    $grid = $Table.SelectSingleNode('w:tblGrid', $Ns)
    if (-not $grid) { throw 'Add-TableColumn: table has no w:tblGrid.' }
    $cols = @($grid.SelectNodes('w:gridCol', $Ns))
    if ($At -lt 0 -or $At -gt $cols.Count) { throw "Add-TableColumn: index $At out of range (0..$($cols.Count))." }

    $tblW = $Table.SelectSingleNode('w:tblPr/w:tblW', $Ns)
    $total = if ($tblW) { [int]$tblW.GetAttribute('w', $script:W) } else { 0 }
    if ($total -le 0) { $total = ($cols | ForEach-Object { [int]$_.GetAttribute('w', $script:W) } | Measure-Object -Sum).Sum }

    # new gridCol
    $newCol = $Table.OwnerDocument.CreateElement('w', 'gridCol', $script:W)
    [void]$newCol.SetAttribute('w', $script:W, "$Width")
    if ($At -eq $cols.Count) { [void]$grid.AppendChild($newCol) } else { [void]$grid.InsertBefore($newCol, $cols[$At]) }

    # rebalance: shrink the pre-existing columns proportionally to free $Width
    $cur = @($grid.SelectNodes('w:gridCol', $Ns))
    $others = @($cur | Where-Object { -not $_.Equals($newCol) })
    $othersTotal = ($others | ForEach-Object { [int]$_.GetAttribute('w', $script:W) } | Measure-Object -Sum).Sum
    $target = $total - $Width
    if ($target -le 0) { throw "Add-TableColumn: width $Width leaves no room in a $total table." }

    $running = 0
    for ($i = 0; $i -lt $others.Count; $i++) {
        if ($i -lt $others.Count - 1) {
            $w = [int][Math]::Floor(([double][int]$others[$i].GetAttribute('w', $script:W)) * $target / $othersTotal)
            if ($w -lt 200) { $w = 200 }
            $running += $w
        } else {
            $w = $target - $running        # last column absorbs the remainder
            if ($w -lt 200) { throw 'Add-TableColumn: rebalance left the last column too narrow.' }
        }
        [void]$others[$i].SetAttribute('w', $script:W, "$w")
    }

    # widen/insert cells row by row, mirroring the grid
    $widths = @($grid.SelectNodes('w:gridCol', $Ns)) | ForEach-Object { [int]$_.GetAttribute('w', $script:W) }
    $rowNo = 0
    foreach ($row in @(Get-Rows $Table $Ns)) {
        $rowNo++
        $cells = @(Get-Cells $row $Ns)
        if ($cells.Count -eq 0) { continue }

        if ($WidenSpanRows -contains $rowNo) {
            # Widen the cell that already covers column $At rather than inserting one.
            $col = 0
            foreach ($c in $cells) {
                $span = 1
                $gs = $c.SelectSingleNode('w:tcPr/w:gridSpan', $Ns)
                if ($gs) { $span = [int]$gs.GetAttribute('val', $script:W) }
                if ($At -ge $col -and $At -lt ($col + $span)) {
                    if (-not $gs) {
                        $tcPr = $c.SelectSingleNode('w:tcPr', $Ns)
                        $gs = $c.OwnerDocument.CreateElement('w', 'gridSpan', $script:W)
                        [void]$tcPr.AppendChild($gs)
                        $span = 1
                    }
                    [void]$gs.SetAttribute('val', $script:W, "$($span + 1)")
                    break
                }
                $col += $span
            }
        } else {
            $srcIdx = [Math]::Min($At, $cells.Count - 1)
            $clone  = $cells[$srcIdx].CloneNode($true)
            # blank the clone's text; the caller fills it
            foreach ($t in $clone.SelectNodes('.//w:t', $Ns)) { $t.InnerText = '' }
            if ($At -ge $cells.Count) { [void]$row.AppendChild($clone) } else { [void]$row.InsertBefore($clone, $cells[$At]) }
        }

        # re-stamp every cell width from the grid, honouring gridSpan
        $now = @(Get-Cells $row $Ns)
        $col = 0
        foreach ($c in $now) {
            $span = 1
            $gs = $c.SelectSingleNode('w:tcPr/w:gridSpan', $Ns)
            if ($gs) { $span = [int]$gs.GetAttribute('val', $script:W) }
            $w = 0
            for ($j = 0; $j -lt $span -and ($col + $j) -lt $widths.Count; $j++) { $w += $widths[$col + $j] }
            $tcW = $c.SelectSingleNode('w:tcPr/w:tcW', $Ns)
            if ($tcW -and $w -gt 0) {
                [void]$tcW.SetAttribute('w', $script:W, "$w")
                [void]$tcW.SetAttribute('type', $script:W, 'dxa')
            }
            $col += $span
        }
    }
    $newCol
}

function Set-CellText {
    <#
      Replaces a cell's entire visible text with $Value, keeping the first run's
      formatting and dropping the placeholder italic/grey.
    #>
    param($Cell, $Ns, [AllowEmptyString()][string]$Value, [string]$Color = '000000')

    $paras = @($Cell.SelectNodes('w:p', $Ns))
    if ($paras.Count -eq 0) { throw 'Set-CellText: cell has no paragraph.' }

    for ($i = 1; $i -lt $paras.Count; $i++) { [void]$Cell.RemoveChild($paras[$i]) }
    $p = $paras[0]

    $runs = @($p.SelectNodes('.//w:r', $Ns))
    if ($runs.Count -eq 0) {
        $r = $Cell.OwnerDocument.CreateElement('w', 'r', $script:W)
        $t = $Cell.OwnerDocument.CreateElement('w', 't', $script:W)
        [void]$r.AppendChild($t); [void]$p.AppendChild($r)
        $runs = @($r)
    }
    for ($i = 1; $i -lt $runs.Count; $i++) { [void]$runs[$i].ParentNode.RemoveChild($runs[$i]) }
    $run = $runs[0]

    $ts = @($run.SelectNodes('.//w:t', $Ns))
    if ($ts.Count -eq 0) {
        $t = $Cell.OwnerDocument.CreateElement('w', 't', $script:W)
        [void]$run.AppendChild($t)
        $ts = @($t)
    }
    for ($i = 1; $i -lt $ts.Count; $i++) { [void]$ts[$i].ParentNode.RemoveChild($ts[$i]) }

    $ts[0].InnerText = $Value
    Set-XmlSpacePreserve $ts[0]
    Set-RunAnswerStyle -Run $run -Ns $Ns -Color $Color
    $Cell
}

# ------------------------------------------------- marking a submission -----

function Get-BodyContentBox {
    <#
      Measures where the student's own content actually sits, so the front
      block we add lines up with it.

      WHY THIS EXISTS. A paragraph inserted at the top of the body sits at the
      section's text margin. The student's content is in tables, and a table
      sets its own left edge with w:tblInd — which is very often NOT the margin.
      One submission here outdents its tables 431 twips PAST the left margin;
      another, converted from a PDF, has a first section whose right margin is
      2.4 inches while its tables run almost to the page edge. In both the front
      block came out visibly misaligned with everything beneath it, inset on one
      document and hanging off to the left on the other.

      So: measure the first table's box and return the indents that put a
      body-level paragraph on exactly those edges. Both are twips relative to
      the text margin and either may be negative, which is legal and is the
      whole point.

      Returns $null when there is nothing to measure — no table, no page size,
      or a table sized in percent rather than twips. The caller then leaves the
      front block at the margin, which is the current behaviour and is never
      worse than a guess.

      -After takes a body-level node and measures the first table BELOW it.
      The builder needs no such thing: it measures before it inserts anything,
      so the first table in the body is the student's. A checker reading the
      FINISHED file does — by then the first table is the feedback sheet the
      builder just added, and measuring that would only ask whether the sheet
      agrees with itself. Passing the page break measures the student's own
      content, which is the thing the sheet is supposed to line up with.
    #>
    param([Parameter(Mandatory)]$Pkg, $After)

    $ns = $Pkg.Ns

    # The FIRST sectPr in document order governs the top of the body. A
    # multi-section document keeps later ones in a paragraph's pPr; taking the
    # body-level one would measure the wrong page.
    $sect = $Pkg.Body.SelectSingleNode('.//w:sectPr', $ns)
    if (-not $sect) { return $null }
    $pgSz  = $sect.SelectSingleNode('w:pgSz',  $ns)
    $pgMar = $sect.SelectSingleNode('w:pgMar', $ns)
    if (-not $pgSz -or -not $pgMar) { return $null }

    $pageW  = [int]$pgSz.GetAttribute('w', $script:W)
    $marL   = [int]$pgMar.GetAttribute('left',  $script:W)
    $marR   = [int]$pgMar.GetAttribute('right', $script:W)
    $textW  = $pageW - $marL - $marR
    if ($textW -le 0) { return $null }

    $tbl = $null
    if ($After) {
        $n = $After.NextSibling
        while ($n) {
            if ($n.LocalName -eq 'tbl' -and $n.NamespaceURI -eq $script:W) { $tbl = $n; break }
            # A content control (w:sdt) WRAPS its content, so the student's own
            # first table is very often not a body-level sibling at all. Walking
            # siblings alone steps straight over it and measures the next table
            # down — a different width — and the front block then reads as
            # misaligned against a table the reader never sees first.
            $inner = $n.SelectSingleNode('.//w:tbl', $ns)
            if ($inner) { $tbl = $inner; break }
            $n = $n.NextSibling
        }
    } else {
        $tbl = $Pkg.Body.SelectSingleNode('.//w:tbl', $ns)
    }
    if (-not $tbl) { return $null }

    $indNode = $tbl.SelectSingleNode('w:tblPr/w:tblInd', $ns)
    $left = 0
    if ($indNode -and $indNode.GetAttribute('type', $script:W) -eq 'dxa') {
        $left = [int]$indNode.GetAttribute('w', $script:W)
    }

    # The grid is the truth about how wide a table draws. w:tblW can be 'auto'
    # or a percentage; the gridCol widths are always twips.
    $tblW = 0
    $grid = $tbl.SelectSingleNode('w:tblGrid', $ns)
    if ($grid) {
        $tblW = (@($grid.SelectNodes('w:gridCol', $ns)) |
                    ForEach-Object { [int]$_.GetAttribute('w', $script:W) } |
                    Measure-Object -Sum).Sum
    }
    if ($tblW -le 0) {
        $wNode = $tbl.SelectSingleNode('w:tblPr/w:tblW', $ns)
        if ($wNode -and $wNode.GetAttribute('type', $script:W) -eq 'dxa') {
            $tblW = [int]$wNode.GetAttribute('w', $script:W)
        }
    }
    if ($tblW -le 0) { return $null }

    [pscustomobject]@{
        IndentLeft  = $left
        IndentRight = $textW - ($left + $tblW)
        TextWidth   = $textW
        TableWidth  = $tblW
    }
}

function New-TextParagraph {
    <#
      Builds a standalone w:p carrying one coloured run. Used to stamp an
      outcome under a student's answer and to head the marked copy.

      Children go into pPr in CT_PPr order — spacing, then ind, then jc —
      because a pPr with its children out of order is the one malformation that
      corrupts a document while passing every well-formedness check.

      IndentLeft and IndentRight are twips measured from the section's text
      margin, and BOTH MAY BE NEGATIVE. That is not a hack: a submission whose
      tables are outdented past the margin needs a front block outdented by the
      same amount, or the block sits visibly inset from every table below it.
      Get-BodyContentBox measures the amount.
    #>
    param(
        [Parameter(Mandatory)]$Doc,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [string]$Color = '000000',
        [switch]$Bold,
        [int]$SizeHalfPoints = 0,
        [int]$SpaceBefore = 60,
        [int]$SpaceAfter = 60,
        [string]$Align,
        [Nullable[int]]$IndentLeft,
        [Nullable[int]]$IndentRight
    )
    $p   = $Doc.CreateElement('w', 'p', $script:W)
    $pPr = $Doc.CreateElement('w', 'pPr', $script:W)
    [void]$p.AppendChild($pPr)

    $sp = $Doc.CreateElement('w', 'spacing', $script:W)
    [void]$sp.SetAttribute('before', $script:W, "$SpaceBefore")
    [void]$sp.SetAttribute('after',  $script:W, "$SpaceAfter")
    [void]$pPr.AppendChild($sp)

    if ($null -ne $IndentLeft -or $null -ne $IndentRight) {
        $ind = $Doc.CreateElement('w', 'ind', $script:W)
        if ($null -ne $IndentLeft)  { [void]$ind.SetAttribute('left',  $script:W, "$IndentLeft") }
        if ($null -ne $IndentRight) { [void]$ind.SetAttribute('right', $script:W, "$IndentRight") }
        [void]$pPr.AppendChild($ind)
    }

    if ($Align) {
        $jc = $Doc.CreateElement('w', 'jc', $script:W)
        [void]$jc.SetAttribute('val', $script:W, $Align)
        [void]$pPr.AppendChild($jc)
    }

    $r   = $Doc.CreateElement('w', 'r', $script:W)
    $rPr = $Doc.CreateElement('w', 'rPr', $script:W)
    [void]$r.AppendChild($rPr)
    if ($Bold) {
        [void]$rPr.AppendChild($Doc.CreateElement('w', 'b',   $script:W))
        [void]$rPr.AppendChild($Doc.CreateElement('w', 'bCs', $script:W))
    }
    $col = $Doc.CreateElement('w', 'color', $script:W)
    [void]$col.SetAttribute('val', $script:W, $Color)
    [void]$rPr.AppendChild($col)
    if ($SizeHalfPoints -gt 0) {
        $sz = $Doc.CreateElement('w', 'sz', $script:W)
        [void]$sz.SetAttribute('val', $script:W, "$SizeHalfPoints")
        [void]$rPr.AppendChild($sz)
        $szCs = $Doc.CreateElement('w', 'szCs', $script:W)
        [void]$szCs.SetAttribute('val', $script:W, "$SizeHalfPoints")
        [void]$rPr.AppendChild($szCs)
    }

    $t = $Doc.CreateElement('w', 't', $script:W)
    $t.InnerText = $Text
    Set-XmlSpacePreserve $t
    [void]$r.AppendChild($t)
    [void]$p.AppendChild($r)
    $p
}

function Add-ParagraphAfter {
    <#
      Inserts $NewParagraph directly after $Anchor, as a sibling in whatever
      container $Anchor sits in — the body, or a table cell.

      Inserting into the cell is the point: a student's answer usually lives in
      a response box, and the outcome belongs inside that box, under the answer,
      not adrift in the body after the table.
    #>
    param($Anchor, $NewParagraph)
    [void]$Anchor.ParentNode.InsertAfter($NewParagraph, $Anchor)
    $NewParagraph
}

function New-SheetTable {
    <#
      Builds an empty w:tbl laid out like the RTO's Student Feedback Sheet:
      hairline rules in the sheet's rule colour, cell margins that match the
      template's, and a grid of the caller's column widths in twips.

      WHY A TABLE AND NOT PARAGRAPHS. The standalone Student Feedback Sheet is
      a table — banner rows in the accent colour, label cells on a tint, one
      row per item across five columns. A marked copy whose feedback page was
      a run of indented paragraphs read as a different document from the sheet
      a non-submitting student in the same class received, which is exactly the
      second layout the declaration page exists to avoid. Same tables, same
      palette, one document to learn.

      Indent is twips from the section's text margin and MAY BE NEGATIVE — the
      student's own tables are often outdented past it, and the sheet has to
      sit on their edge, not the margin's. Get-BodyContentBox measures it.
    #>
    param(
        [Parameter(Mandatory)]$Doc,
        [Parameter(Mandatory)][int[]]$Widths,
        [int]$Indent = 0,
        [string]$RuleColor = 'C3CBDA'
    )
    $tbl   = $Doc.CreateElement('w', 'tbl',   $script:W)
    $tblPr = $Doc.CreateElement('w', 'tblPr', $script:W)
    [void]$tbl.AppendChild($tblPr)

    $total = ($Widths | Measure-Object -Sum).Sum
    $tblW  = $Doc.CreateElement('w', 'tblW', $script:W)
    [void]$tblW.SetAttribute('w',    $script:W, "$total")
    [void]$tblW.SetAttribute('type', $script:W, 'dxa')
    [void]$tblPr.AppendChild($tblW)

    # tblPr children go in CT_TblPrBase order: tblW, tblInd, tblBorders,
    # tblCellMar, tblLook. Out of order corrupts the document while still
    # passing every well-formedness check.
    if ($Indent -ne 0) {
        $ind = $Doc.CreateElement('w', 'tblInd', $script:W)
        [void]$ind.SetAttribute('w',    $script:W, "$Indent")
        [void]$ind.SetAttribute('type', $script:W, 'dxa')
        [void]$tblPr.AppendChild($ind)
    }

    $brd = $Doc.CreateElement('w', 'tblBorders', $script:W)
    foreach ($side in 'top', 'left', 'bottom', 'right', 'insideH', 'insideV') {
        $e = $Doc.CreateElement('w', $side, $script:W)
        [void]$e.SetAttribute('val',   $script:W, 'single')
        [void]$e.SetAttribute('sz',    $script:W, '4')
        [void]$e.SetAttribute('space', $script:W, '0')
        [void]$e.SetAttribute('color', $script:W, $RuleColor)
        [void]$brd.AppendChild($e)
    }
    [void]$tblPr.AppendChild($brd)

    $mar = $Doc.CreateElement('w', 'tblCellMar', $script:W)
    foreach ($side in 'left', 'right') {
        $e = $Doc.CreateElement('w', $side, $script:W)
        [void]$e.SetAttribute('w',    $script:W, '10')
        [void]$e.SetAttribute('type', $script:W, 'dxa')
        [void]$mar.AppendChild($e)
    }
    [void]$tblPr.AppendChild($mar)

    $look = $Doc.CreateElement('w', 'tblLook', $script:W)
    [void]$look.SetAttribute('val',         $script:W, '04A0')
    [void]$look.SetAttribute('firstRow',    $script:W, '1')
    [void]$look.SetAttribute('lastRow',     $script:W, '0')
    [void]$look.SetAttribute('firstColumn', $script:W, '1')
    [void]$look.SetAttribute('lastColumn',  $script:W, '0')
    [void]$look.SetAttribute('noHBand',     $script:W, '0')
    [void]$look.SetAttribute('noVBand',     $script:W, '1')
    [void]$tblPr.AppendChild($look)

    $grid = $Doc.CreateElement('w', 'tblGrid', $script:W)
    foreach ($w in $Widths) {
        $gc = $Doc.CreateElement('w', 'gridCol', $script:W)
        [void]$gc.SetAttribute('w', $script:W, "$w")
        [void]$grid.AppendChild($gc)
    }
    [void]$tbl.AppendChild($grid)
    $tbl
}

function Add-SheetRow {
    <#
      Appends one row to a table built by New-SheetTable.

      $Cells is an array of hashtables, one per cell:
        Width      twips the cell spans        (required)
        Span       grid columns it covers      (default 1)
        Fill       cell shading, hex, or none  (default none)
        Paragraphs one or more w:p elements    (required)

      A cell shaded in the accent colour gets WHITE rules rather than the
      sheet's grey, which is what makes a banner row read as a solid band
      instead of a boxed cell. That is the template's own treatment, measured.

      -Header marks the row w:tblHeader, so a long item table repeats its
      column headings on every page it runs onto. A student reading page two
      of their own feedback should not have to page back to learn which column
      is the issue and which is the fix.
    #>
    param(
        [Parameter(Mandatory)]$Doc,
        [Parameter(Mandatory)]$Table,
        [Parameter(Mandatory)][hashtable[]]$Cells,
        [int]$Height = 0,
        [switch]$Header,
        [string]$RuleColor = 'C3CBDA',
        [string]$AccentColor = '234B8C'
    )
    $tr   = $Doc.CreateElement('w', 'tr',   $script:W)
    $trPr = $Doc.CreateElement('w', 'trPr', $script:W)
    [void]$tr.AppendChild($trPr)
    [void]$trPr.AppendChild($Doc.CreateElement('w', 'cantSplit', $script:W))
    if ($Height -gt 0) {
        $h = $Doc.CreateElement('w', 'trHeight', $script:W)
        [void]$h.SetAttribute('val', $script:W, "$Height")
        [void]$trPr.AppendChild($h)
    }
    if ($Header) { [void]$trPr.AppendChild($Doc.CreateElement('w', 'tblHeader', $script:W)) }

    foreach ($c in $Cells) {
        $fill = if ($c.ContainsKey('Fill')) { "$($c.Fill)" } else { '' }
        $span = if ($c.ContainsKey('Span')) { [int]$c.Span } else { 1 }

        $tc   = $Doc.CreateElement('w', 'tc',   $script:W)
        $tcPr = $Doc.CreateElement('w', 'tcPr', $script:W)
        [void]$tc.AppendChild($tcPr)

        # CT_TcPrBase order: tcW, gridSpan, tcBorders, shd, tcMar, vAlign.
        $tcW = $Doc.CreateElement('w', 'tcW', $script:W)
        [void]$tcW.SetAttribute('w',    $script:W, "$([int]$c.Width)")
        [void]$tcW.SetAttribute('type', $script:W, 'dxa')
        [void]$tcPr.AppendChild($tcW)

        if ($span -gt 1) {
            $gs = $Doc.CreateElement('w', 'gridSpan', $script:W)
            [void]$gs.SetAttribute('val', $script:W, "$span")
            [void]$tcPr.AppendChild($gs)
        }

        $edge = if ($fill -eq $AccentColor) { 'FFFFFF' } else { $RuleColor }
        $brd  = $Doc.CreateElement('w', 'tcBorders', $script:W)
        foreach ($side in 'top', 'left', 'bottom', 'right') {
            $e = $Doc.CreateElement('w', $side, $script:W)
            [void]$e.SetAttribute('val',   $script:W, 'single')
            [void]$e.SetAttribute('sz',    $script:W, '4')
            [void]$e.SetAttribute('space', $script:W, '0')
            [void]$e.SetAttribute('color', $script:W, $edge)
            [void]$brd.AppendChild($e)
        }
        [void]$tcPr.AppendChild($brd)

        if ($fill) {
            $shd = $Doc.CreateElement('w', 'shd', $script:W)
            [void]$shd.SetAttribute('val',   $script:W, 'clear')
            [void]$shd.SetAttribute('color', $script:W, 'auto')
            [void]$shd.SetAttribute('fill',  $script:W, $fill)
            [void]$tcPr.AppendChild($shd)
        }

        $mar = $Doc.CreateElement('w', 'tcMar', $script:W)
        foreach ($pair in @(@('top', '50'), @('left', '90'), @('bottom', '50'), @('right', '90'))) {
            $e = $Doc.CreateElement('w', $pair[0], $script:W)
            [void]$e.SetAttribute('w',    $script:W, $pair[1])
            [void]$e.SetAttribute('type', $script:W, 'dxa')
            [void]$mar.AppendChild($e)
        }
        [void]$tcPr.AppendChild($mar)

        $va = $Doc.CreateElement('w', 'vAlign', $script:W)
        [void]$va.SetAttribute('val', $script:W, 'center')
        [void]$tcPr.AppendChild($va)

        # A w:tc with no w:p in it is the one table malformation Word refuses
        # to open, so an empty cell still gets an empty paragraph.
        $paras = @($c.Paragraphs | Where-Object { $_ })
        if ($paras.Count -eq 0) { $paras = @($Doc.CreateElement('w', 'p', $script:W)) }
        foreach ($p in $paras) { [void]$tc.AppendChild($p) }

        [void]$tr.AppendChild($tc)
    }
    [void]$Table.AppendChild($tr)
    $tr
}

function New-SheetParagraph {
    <#
      A paragraph sized and spaced for a feedback-sheet cell: the template's
      tight line rule, and Arial by name.

      THE FONT IS EXPLICIT ON PURPOSE. The standalone sheet's document default
      is Arial 9pt; a student's own assessment is usually a themed 11pt. The
      same runs dropped into their document without an rFonts would come out in
      their theme font, and the sheet would read as a near-miss of itself
      rather than the same sheet. Naming the face is what makes the two
      documents match.
    #>
    param(
        [Parameter(Mandatory)]$Doc,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [string]$Color = '000000',
        [switch]$Bold,
        [switch]$Italic,
        [int]$SizeHalfPoints = 18,
        [string]$Align,
        [string]$Font = 'Arial'
    )
    $p   = $Doc.CreateElement('w', 'p',   $script:W)
    $pPr = $Doc.CreateElement('w', 'pPr', $script:W)
    [void]$p.AppendChild($pPr)

    $sp = $Doc.CreateElement('w', 'spacing', $script:W)
    [void]$sp.SetAttribute('before',   $script:W, '20')
    [void]$sp.SetAttribute('after',    $script:W, '20')
    [void]$sp.SetAttribute('line',     $script:W, '230')
    [void]$sp.SetAttribute('lineRule', $script:W, 'auto')
    [void]$pPr.AppendChild($sp)

    if ($Align) {
        $jc = $Doc.CreateElement('w', 'jc', $script:W)
        [void]$jc.SetAttribute('val', $script:W, $Align)
        [void]$pPr.AppendChild($jc)
    }

    $r   = $Doc.CreateElement('w', 'r',   $script:W)
    $rPr = $Doc.CreateElement('w', 'rPr', $script:W)
    [void]$r.AppendChild($rPr)

    # CT_RPr order: rFonts, b, bCs, i, iCs, color, sz, szCs.
    $rf = $Doc.CreateElement('w', 'rFonts', $script:W)
    foreach ($a in 'ascii', 'eastAsia', 'hAnsi', 'cs') { [void]$rf.SetAttribute($a, $script:W, $Font) }
    [void]$rPr.AppendChild($rf)
    if ($Bold) {
        [void]$rPr.AppendChild($Doc.CreateElement('w', 'b',   $script:W))
        [void]$rPr.AppendChild($Doc.CreateElement('w', 'bCs', $script:W))
    }
    if ($Italic) {
        [void]$rPr.AppendChild($Doc.CreateElement('w', 'i',   $script:W))
        [void]$rPr.AppendChild($Doc.CreateElement('w', 'iCs', $script:W))
    }
    $col = $Doc.CreateElement('w', 'color', $script:W)
    [void]$col.SetAttribute('val', $script:W, $Color)
    [void]$rPr.AppendChild($col)
    $sz = $Doc.CreateElement('w', 'sz', $script:W)
    [void]$sz.SetAttribute('val', $script:W, "$SizeHalfPoints")
    [void]$rPr.AppendChild($sz)
    $szCs = $Doc.CreateElement('w', 'szCs', $script:W)
    [void]$szCs.SetAttribute('val', $script:W, "$SizeHalfPoints")
    [void]$rPr.AppendChild($szCs)

    $t = $Doc.CreateElement('w', 't', $script:W)
    $t.InnerText = $Text
    Set-XmlSpacePreserve $t
    [void]$r.AppendChild($t)
    [void]$p.AppendChild($r)
    $p
}

function Get-ScaledGrid {
    <#
      Scales a set of proportional column widths onto a real table width, with
      the rounding error absorbed by the widest column so the parts still sum
      to the whole. A grid whose columns do not add up to w:tblW draws at a
      width nobody chose.
    #>
    param(
        [Parameter(Mandatory)][int[]]$Proportions,
        [Parameter(Mandatory)][int]$TotalWidth
    )
    $sum = ($Proportions | Measure-Object -Sum).Sum
    if ($sum -le 0 -or $TotalWidth -le 0) { return $Proportions }
    $out = @($Proportions | ForEach-Object { [int][Math]::Round($_ * $TotalWidth / $sum) })
    $drift = $TotalWidth - ($out | Measure-Object -Sum).Sum
    if ($drift -ne 0) {
        $widest = 0
        for ($i = 1; $i -lt $out.Count; $i++) { if ($out[$i] -gt $out[$widest]) { $widest = $i } }
        $out[$widest] += $drift
    }
    $out
}

function New-PageBreakParagraph {
    <#
      A paragraph carrying nothing but a page break.

      The marked copy opens on a declaration page of its own, and this is what
      ends it. Putting the result on its own page rather than squeezing it above
      the student's cover sheet keeps the student's first page exactly as they
      submitted it, and gives the declaration room to name the qualification,
      the unit, the tools and the resubmission date.
    #>
    param([Parameter(Mandatory)]$Doc)
    $p   = $Doc.CreateElement('w', 'p', $script:W)
    $pPr = $Doc.CreateElement('w', 'pPr', $script:W)
    [void]$p.AppendChild($pPr)
    $sp = $Doc.CreateElement('w', 'spacing', $script:W)
    [void]$sp.SetAttribute('before', $script:W, '0')
    [void]$sp.SetAttribute('after',  $script:W, '0')
    [void]$pPr.AppendChild($sp)

    $r  = $Doc.CreateElement('w', 'r', $script:W)
    $br = $Doc.CreateElement('w', 'br', $script:W)
    [void]$br.SetAttribute('type', $script:W, 'page')
    [void]$r.AppendChild($br)
    [void]$p.AppendChild($r)
    $p
}

function Test-ParagraphIsPageBreak {
    <# True where a paragraph's only content is a page break. #>
    param($Paragraph, $Ns)
    $null -ne $Paragraph.SelectSingleNode('.//w:br[@w:type="page"]', $Ns)
}

function Get-ParagraphCell {
    <# The w:tc a paragraph sits in, or $null where it sits in the body flow. #>
    param($Paragraph)
    $n = $Paragraph.ParentNode
    while ($n -and $n.Name -ne 'w:body') {
        if ($n.LocalName -eq 'tc') { return $n }
        $n = $n.ParentNode
    }
    $null
}

function Get-ParagraphTable {
    <#
      The w:tbl a paragraph sits in, or $null where it sits in the body flow.
      The builder uses it to keep an outcome line out of the heading rows of the
      next question's table; the gate uses it to find the table an anchor names.
      It lives here because both read it off the same file and must agree.
    #>
    param($Paragraph)
    $n = $Paragraph.ParentNode
    while ($n -and $n.Name -ne 'w:body') {
        if ($n.LocalName -eq 'tbl') { return $n }
        $n = $n.ParentNode
    }
    $null
}

function Get-NextCellInRow {
    <#
      The cell to the right of $Cell in its own row, or $null at the end of it.

      Observation sheets are label/value tables: 'Date' in one cell, the date in
      the next. Writing the value by naming the label is the only addressing
      that survives a sheet being re-laid-out.
    #>
    param($Cell, $Ns)
    $row = $Cell.ParentNode
    if (-not $row -or $row.LocalName -ne 'tr') { return $null }
    $cells = @(Get-Cells $row $Ns)
    for ($i = 0; $i -lt $cells.Count; $i++) {
        if ($cells[$i].Equals($Cell)) {
            if ($i + 1 -lt $cells.Count) { return $cells[$i + 1] }
            return $null
        }
    }
    $null
}

function Get-BodyParagraphs {
    <# Every w:p in the body, in document order, table cells included. #>
    param($Package)
    @($Package.Body.SelectNodes('.//w:p', $Package.Ns))
}

function Find-ParagraphIndex {
    <#
      Finds the paragraphs whose text contains $Text, returning their indices in
      the document-order list. Returns every match: the caller decides whether
      ambiguity is acceptable, because silently taking the first match is how an
      outcome lands under the wrong answer.
    #>
    param([object[]]$Paragraphs, $Ns, [string]$Text)
    $hits = @()
    for ($i = 0; $i -lt $Paragraphs.Count; $i++) {
        if ((Get-RunText $Paragraphs[$i] $Ns).IndexOf($Text, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $hits += $i }
    }
    @($hits)
}

function Add-CellLine {
    <#
      Appends a further paragraph to a cell, cloning the last one so it keeps the
      cell's spacing and alignment. Used where feedback runs to more than a line.
    #>
    param($Cell, $Ns, [string]$Value, [string]$Color = '000000')
    $paras = @($Cell.SelectNodes('w:p', $Ns))
    $p = $paras[$paras.Count - 1].CloneNode($true)
    [void]$Cell.AppendChild($p)

    $runs = @($p.SelectNodes('.//w:r', $Ns))
    for ($i = 1; $i -lt $runs.Count; $i++) { [void]$runs[$i].ParentNode.RemoveChild($runs[$i]) }
    # THE LAST PARAGRAPH IN A CELL IS OFTEN EMPTY. Cloning it gives a paragraph
    # with no run to put the text in, and returning here appended a blank line
    # and threw the value away â€” silently, and the build still reported the line
    # as written. A cell that already carried text lost every comment appended
    # to it. Make the run instead.
    if ($runs.Count -eq 0) {
        $r = $Cell.OwnerDocument.CreateElement('w', 'r', $script:W)
        [void]$p.AppendChild($r)
        $runs = @($r)
    }
    $ts = @($runs[0].SelectNodes('.//w:t', $Ns))
    for ($i = 1; $i -lt $ts.Count; $i++) { [void]$ts[$i].ParentNode.RemoveChild($ts[$i]) }
    if ($ts.Count -eq 0) {
        $t = $Cell.OwnerDocument.CreateElement('w', 't', $script:W); [void]$runs[0].AppendChild($t); $ts = @($t)
    }
    $ts[0].InnerText = $Value
    Set-XmlSpacePreserve $ts[0]
    Set-RunAnswerStyle -Run $runs[0] -Ns $Ns -Color $Color
    $p
}

# ---------------------------------------------------------------- reading ---

function Get-DocxText {
    <#
      Visible text of a finished document, with table structure kept so the gate
      can tell a row apart from a paragraph. Reads the file, not the DOM, so it
      can be pointed at delivered output.
    #>
    param([Parameter(Mandatory)][string]$Path, [string]$WorkRoot = $env:TEMP)

    $pkg = Open-Docx -Path $Path -WorkRoot $WorkRoot
    try {
        $sb = New-Object System.Text.StringBuilder
        foreach ($node in $pkg.Body.SelectNodes('.//w:tbl | .//w:p', $pkg.Ns)) {
            if ($node.LocalName -eq 'tbl') { continue }
            [void]$sb.AppendLine((Get-RunText $node $pkg.Ns))
        }
        $sb.ToString()
    } finally { Close-Docx $pkg }
}

function Get-DocxRowText {
    <# Every table row in the file, as 'cell | cell | cell' lines. #>
    param([Parameter(Mandatory)][string]$Path, [string]$WorkRoot = $env:TEMP)

    $pkg = Open-Docx -Path $Path -WorkRoot $WorkRoot
    try {
        $out = @()
        foreach ($tbl in @(Get-Tables $pkg)) {
            foreach ($r in @(Get-Rows $tbl $pkg.Ns)) {
                $cells = @()
                foreach ($c in @(Get-Cells $r $pkg.Ns)) { $cells += (Get-RunText $c $pkg.Ns).Trim() }
                $out += ($cells -join ' | ')
            }
        }
        @($out)
    } finally { Close-Docx $pkg }
}
