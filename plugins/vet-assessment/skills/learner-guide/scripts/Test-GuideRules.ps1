<#
    Test-GuideRules.ps1

    THE GUIDE GATE. Runs on a built Learner Guide (.docx or its unpacked working
    directory) and reports what the spec, the template and the delivered
    reference guide between them actually require.

    Each rule earned its place:

      CONTENT WIDTH    Derived from the page's OWN margins, then compared with
                       every full-width table. The delivered SITHPAT018 guide
                       lays 361 tables at 9617 DXA on a page whose margins give
                       9026, so every table in it overhangs the right margin by
                       591 DXA. Blocking.
      NUMBERING        Every separate numbered list needs its own numId with a
                       startOverride, or Word runs them on continuously and the
                       second Self-Check set starts at 5. The reference guide
                       carries 164 distinct numIds for exactly this reason.
      TOPIC WORD FLOOR 3,000 words of counted body prose per Topic, excluding
                       table and callout cells - which is where the readability
                       boxes live, so the exclusion falls out of the structure.
      SUBJECT DETAIL   800 words minimum per PC sub-section's Underpinning
                       Knowledge block - the deepest teaching block, and the one
                       most often thinned to hit a deadline.
      PAGE BREAKS      Each Topic and each PC sub-section starts on a new page.
      DOCUMENT CONTROL Explicitly forbidden in this document type: no doc
                       number, revision, approval or date fields anywhere.
                       Document control is applied later, in novacore.cloud.
      QUESTION XREF    Every assessment question referenced by the guide must
                       exist in the assessment pack, and every question in the
                       pack must be reachable from a topic. This is the whole
                       point of the guide, so both directions are checked.

    Requires Lib-Resolve.ps1 dot-sourced first.

    ASCII only in this file.
#>

# No Set-StrictMode - dot-sourced.

function Get-GuideBodyBlock {
    <#  The document body as an ordered list of top-level blocks.

        Tables are skipped WHOLE with a balanced scan rather than stripped with
        a regex, because a callout is a table and a table can nest. Everything
        the word floor excludes - table cells, callout bodies, sign-off blocks,
        answer space - is inside a <w:tbl>, so "paragraphs not inside a table"
        is exactly the counted-prose rule in SECTION 4.1 and needs no separate
        list of box names.

        Returns objects with Kind (para|table), Style, Text and Xml.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $DocumentXml)

    $body = $DocumentXml
    $bs = $body.IndexOf('<w:body>')
    if ($bs -ge 0) { $body = $body.Substring($bs + 8) }

    $out = New-Object System.Collections.Generic.List[object]
    $pos = 0
    while ($pos -lt $body.Length) {
        $np = $body.IndexOf('<w:p', $pos)
        $nt = $body.IndexOf('<w:tbl', $pos)

        # '<w:p' also prefixes '<w:pPr' and '<w:pict'; require a real element.
        while ($np -ge 0 -and $body[$np + 4] -notmatch '[\s/>]') { $np = $body.IndexOf('<w:p', $np + 4) }
        while ($nt -ge 0 -and $body[$nt + 6] -notmatch '[\s/>]') { $nt = $body.IndexOf('<w:tbl', $nt + 6) }

        if ($np -lt 0 -and $nt -lt 0) { break }

        if ($nt -ge 0 -and ($np -lt 0 -or $nt -lt $np)) {
            $frag = Get-XmlFragment -Xml $body -Tag 'w:tbl' -From $nt
            if (-not $frag) { break }
            $out.Add([pscustomobject]@{ Kind = 'table'; Style = ''; Text = ''; Xml = $frag })
            $pos = $nt + $frag.Length
            continue
        }

        $frag = Get-XmlFragment -Xml $body -Tag 'w:p' -From $np
        if (-not $frag) { break }
        $style = if ($frag -match '<w:pStyle w:val="([^"]+)"') { $Matches[1] } else { '' }
        $text  = -join ([regex]::Matches($frag, '<w:t[^>]*>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value })
        $out.Add([pscustomobject]@{ Kind = 'para'; Style = $style; Text = $text; Xml = $frag })
        $pos = $np + $frag.Length
    }
    return $out
}

function Measure-GuideWord {
    param([string] $Text)
    if (-not $Text) { return 0 }
    return @($Text -split '\s+' | Where-Object { $_ -match '\w' }).Count
}

function Test-GuideRules {
    <#  Gate a built Learner Guide.

        -QuestionsInPack is the list of question references the ASSESSMENT PACK
        actually contains, e.g. @('Q1','Q2','Q9(a)'). Supply it and the
        cross-reference is checked both ways; omit it and that rule is skipped
        and said to be.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [string[]] $QuestionsInPack,
        [int]      $TopicWordFloor    = 3000,
        [int]      $SubjectWordFloor  = 800,
        [switch]   $AllowDocumentControl,
        [switch]   $AfterArtwork,
        [string]   $QuestionPattern
    )

    # How the PACK labels its assessed items, which is not a constant. The
    # SITHPAT018 knowledge tool numbers questions Q1..Qn; the SITHKOP013
    # combined UAT numbers them Task 1..Task 11 with Observation 1..n
    # alongside, and carries no "Q" anywhere. A gate hard-coded to Q\d+ reports
    # zero citations on that pack and then fails every question as uncovered -
    # a false negative that looks like a coverage disaster. So the default
    # recognises the conventions actually in use, and -QuestionPattern overrides
    # it for a pack that does something else again.
    if (-not $QuestionPattern) {
        $QuestionPattern = '\b(?:Q|Question|Task|Item|Deliverable|Observation)\s?(\d+)\s?(\([a-z]\))?'
    }

    $wd = if ((Get-Item -LiteralPath $Path).PSIsContainer) { $Path } else { Expand-Docx -Path $Path }

    $fail = New-Object System.Collections.Generic.List[string]
    $warn = New-Object System.Collections.Generic.List[string]
    $info = New-Object System.Collections.Generic.List[string]

    $doc = Get-DocxPart -WorkDir $wd -Part 'word/document.xml'

    # ------------------------------------------------------- table well-formed
    #
    # An empty <w:tblGrid/> or an empty width attribute is schema-invalid, and
    # it is what a width-splitter returns when its parameters do not bind: the
    # column count comes through as zero, the widths array is empty, and the
    # table renders with no grid and w:w="". The document still passes the
    # package check, the namespace check and every content rule, and Word then
    # refuses the whole file without naming a part or an element.
    $emptyGrid = ([regex]::Matches($doc, '<w:tblGrid>\s*</w:tblGrid>')).Count
    if ($emptyGrid) { $fail.Add("$emptyGrid table(s) have an empty <w:tblGrid> - a width array came through empty. Word will refuse the file.") }

    $emptyW = ([regex]::Matches($doc, '<w:(?:tcW|tblW|gridCol) w:w=""')).Count
    if ($emptyW) { $fail.Add("$emptyW table width attribute(s) are empty. Word will refuse the file.") }

    if (-not $emptyGrid -and -not $emptyW) {
        $grids = ([regex]::Matches($doc, '<w:tblGrid>')).Count
        $info.Add("tables: $grids grid(s), every column width populated")
    }

    # ----------------------------------------------------- pPr child ordering
    #
    # CT_PPr is a SEQUENCE, not a choice: its children must appear in schema
    # order. Word does not tolerate a wrong order and does not explain it - it
    # refuses the whole file with "Word experienced an error trying to open the
    # file" and suggests the Text Recovery converter, while the package check,
    # the namespace check and every readability rule still pass, because the XML
    # is perfectly well formed.
    #
    # This gate exists because a build shipped with pageBreakBefore emitted
    # ahead of keepNext, and nothing caught it until Word did.
    $ppOrder = @('pStyle', 'keepNext', 'keepLines', 'pageBreakBefore', 'framePr', 'widowControl',
                 'numPr', 'suppressLineNumbers', 'pBdr', 'shd', 'tabs', 'suppressAutoHyphens',
                 'kinsoku', 'wordWrap', 'overflowPunct', 'topLinePunct', 'autoSpaceDE',
                 'autoSpaceDN', 'bidi', 'adjustRightInd', 'snapToGrid', 'spacing', 'ind',
                 'contextualSpacing', 'mirrorIndents', 'suppressOverlap', 'jc', 'textDirection',
                 'textAlignment', 'textboxTightWrap', 'outlineLvl', 'divId', 'cnfStyle', 'rPr',
                 'sectPr', 'pPrChange')
    $rank = @{}; for ($i = 0; $i -lt $ppOrder.Count; $i++) { $rank[$ppOrder[$i]] = $i }

    $badOrder = New-Object System.Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($doc, '<w:pPr>(.*?)</w:pPr>', 'Singleline')) {
        # DIRECT children only. <w:rPr> is a legal child of w:pPr - it carries
        # the paragraph mark's own run properties - and its descendants include
        # elements whose names collide with pPr's own, notably <w:spacing>.
        # Scanning them as if they were pPr children reports every correct
        # document as "rPr before spacing".
        $inner = [regex]::Replace($m.Groups[1].Value, '(?s)<w:rPr>.*?</w:rPr>', '<w:rPr/>')
        $kids = @([regex]::Matches($inner, '<w:([a-zA-Z]+)[ />]') | ForEach-Object { $_.Groups[1].Value })
        $last = -1; $lastName = ''
        foreach ($k in $kids) {
            if (-not $rank.ContainsKey($k)) { continue }
            if ($rank[$k] -lt $last) {
                $sig = "$lastName before $k"
                if (-not $badOrder.Contains($sig)) { $badOrder.Add($sig) }
                break
            }
            $last = $rank[$k]; $lastName = $k
        }
    }
    if ($badOrder.Count) {
        $fail.Add("paragraph properties are out of schema order ($($badOrder -join '; ')). CT_PPr is a sequence - Word will refuse the file without saying why.")
    }
    else { $info.Add('paragraph property ordering: schema-valid throughout') }

    # ------------------------------------------------------------- namespaces
    #
    # Every prefix used in the body must be declared on the <w:document> root.
    # This is NOT covered by the package check, which verifies the XML is well
    # formed - and it is: it simply uses prefixes nothing declares. Word's only
    # response is "Word experienced an error trying to open the file", naming
    # neither the prefix nor the part, so without this rule the failure surfaces
    # at delivery with nothing to go on.
    #
    # It bites after artwork: the Learner Guide template declares no DrawingML
    # namespaces, because its body ships with no drawings, and every placed
    # figure uses 'a' and 'pic'.
    $rootM = [regex]::Match($doc, '<w:document\b[^>]*>')
    if ($rootM.Success) {
        # Declared ANYWHERE in the part, not only on the root. A namespace may
        # legitimately be declared on the element that uses it, and Word does
        # exactly that: once it re-saves a document it moves the DrawingML
        # declarations off the root and onto each <w:drawing>. Checking only the
        # root then reports a document Word itself wrote - and opens happily -
        # as broken.
        $declared = @([regex]::Matches($doc, 'xmlns:([a-zA-Z0-9]+)=') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        $usedPfx  = @([regex]::Matches($doc, '<([a-zA-Z0-9]+):') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        $missing  = @($usedPfx | Where-Object { $declared -notcontains $_ })
        if ($missing.Count) {
            $fail.Add("word/document.xml uses XML prefix(es) nothing declares: $($missing -join ', '). Word will refuse to open this file and will not say why.")
        }
        else { $info.Add("namespaces: $($usedPfx.Count) prefix(es) used, all declared") }
    }

    # ---------------------------------------------------------------- geometry
    $pageW = 0; $cw = 0
    if ($doc -match '<w:pgSz w:w="(\d+)"') { $pageW = [int]$Matches[1] }
    $mm = [regex]::Match($doc, '<w:pgMar\b[^>]*/>')
    if ($pageW -and $mm.Success) {
        $l = [int]([regex]::Match($mm.Value, 'w:left="(\d+)"').Groups[1].Value)
        $r = [int]([regex]::Match($mm.Value, 'w:right="(\d+)"').Groups[1].Value)
        $cw = $pageW - $l - $r
        $info.Add("content width: $cw DXA (page $pageW, margins $l / $r)")

        # Full-width tables must equal CW exactly. A table WIDER than the text
        # column overhangs the margin; narrower is a deliberate inset and only
        # warned about when it is close enough to have been meant as full width.
        $widths = @([regex]::Matches($doc, '<w:tblW w:w="(\d+)" w:type="dxa"') | ForEach-Object { [int]$_.Groups[1].Value })
        $over  = @($widths | Where-Object { $_ -gt $cw })
        $near  = @($widths | Where-Object { $_ -lt $cw -and $_ -ge ($cw - 800) })
        if ($over.Count) {
            $worst = ($over | Measure-Object -Maximum).Maximum
            $fail.Add("$($over.Count) table(s) are wider than the content width - widest $worst DXA against CW $cw, overhanging the right margin by $($worst - $cw) DXA")
        }
        if ($near.Count) {
            $warn.Add("$($near.Count) table(s) sit just inside CW (narrowest $(($near | Measure-Object -Minimum).Minimum) vs $cw) - check they were meant to be full width")
        }
        if (-not $over.Count -and $widths.Count) {
            $info.Add("full-width tables: $(@($widths | Where-Object { $_ -eq $cw }).Count) of $($widths.Count) exactly $cw DXA")
        }
    }
    else { $warn.Add('could not read page geometry - content-width rule skipped') }

    # -------------------------------------------------------------- numbering
    $numIds = @([regex]::Matches($doc, '<w:numId w:val="(\d+)"') | ForEach-Object { $_.Groups[1].Value })
    $distinct = @($numIds | Sort-Object -Unique)
    $info.Add("numbering: $($numIds.Count) list references across $($distinct.Count) distinct numId(s)")

    if (Test-Path -LiteralPath (Join-Path $wd 'word\numbering.xml')) {
        $num = Get-DocxPart -WorkDir $wd -Part 'word/numbering.xml'
        $withOverride = @([regex]::Matches($num, '(?s)<w:num\s+w:numId="(\d+)".*?</w:num>') |
                          Where-Object { $_.Value -match 'startOverride' } |
                          ForEach-Object { $_.Groups[1].Value })
        $info.Add("numbering.xml: $(@([regex]::Matches($num,'<w:num\s+w:numId=')).Count) num definitions, $($withOverride.Count) with a startOverride")

        # Decimal lists that share a numId run on continuously in Word.
        if ($distinct.Count -lt 20 -and $numIds.Count -gt 60) {
            $warn.Add("only $($distinct.Count) distinct numIds for $($numIds.Count) list references - separate numbered lists will run on rather than restarting at 1")
        }
    }

    # ------------------------------------------------------- structural blocks
    $blocks = Get-GuideBodyBlock -DocumentXml $doc

    $topicWords = @{}; $topicOrder = New-Object System.Collections.Generic.List[string]
    $subjWords  = @{}; $subjOrder  = New-Object System.Collections.Generic.List[string]
    $curTopic = $null; $curSubj = $null

    $topicHeadNoBreak = New-Object System.Collections.Generic.List[string]
    $pcHeadNoBreak    = New-Object System.Collections.Generic.List[string]

    foreach ($b in $blocks) {
        if ($b.Kind -eq 'table') { continue }         # excluded from the word floor
        $t = $b.Text.Trim()

        if ($b.Style -eq 'Heading1') {
            $curSubj = $null
            if ($t -match '^Topic\s+(\d+)') {
                $curTopic = "Topic $($Matches[1])"
                if (-not $topicWords.ContainsKey($curTopic)) { $topicWords[$curTopic] = 0; $topicOrder.Add($curTopic) }
                if ($b.Xml -notmatch 'pageBreakBefore') { $topicHeadNoBreak.Add($t) }
            }
            else { $curTopic = $null }
            continue
        }

        if ($b.Style -eq 'Heading3' -and $t -match '^\d+\.\d+') {
            $curSubj = $t
            if ($b.Xml -notmatch 'pageBreakBefore') { $pcHeadNoBreak.Add($t) }
            continue
        }

        if ($b.Style -eq 'Heading4') {
            # 'Underpinning knowledge' opens the deepest teaching block; any
            # other H4 closes it.
            if ($t -match 'Underpinning\s+[Kk]nowledge') {
                $curSubj = if ($curSubj) { $curSubj } else { 'unknown sub-section' }
                $key = "$curSubj"
                if (-not $subjWords.ContainsKey($key)) { $subjWords[$key] = 0; $subjOrder.Add($key) }
                $script:inSubject = $true
            }
            else { $script:inSubject = $false }
            continue
        }

        $w = Measure-GuideWord $t
        if ($curTopic) { $topicWords[$curTopic] += $w }
        if ($script:inSubject -and $curSubj -and $subjWords.ContainsKey("$curSubj")) { $subjWords["$curSubj"] += $w }
    }

    foreach ($t in $topicOrder) {
        $w = $topicWords[$t]
        if ($w -lt $TopicWordFloor) { $fail.Add("$t carries $w words of counted body prose, floor is $TopicWordFloor") }
        else { $info.Add("${t}: $w words") }
    }
    if (-not $topicOrder.Count) { $warn.Add('no "Topic N" Heading1 found - topic word floor not checked') }

    $thin = @($subjOrder | Where-Object { $subjWords[$_] -lt $SubjectWordFloor })
    if ($thin.Count) {
        foreach ($s in ($thin | Select-Object -First 8)) {
            $fail.Add("Underpinning knowledge under '$s' is $($subjWords[$s]) words, floor is $SubjectWordFloor")
        }
        if ($thin.Count -gt 8) { $fail.Add("...and $($thin.Count - 8) further Underpinning knowledge blocks under $SubjectWordFloor words") }
    }
    elseif ($subjOrder.Count) { $info.Add("Underpinning knowledge blocks: $($subjOrder.Count), all >= $SubjectWordFloor words") }

    if ($topicHeadNoBreak.Count) { $fail.Add("$($topicHeadNoBreak.Count) Topic heading(s) do not start a new page: $(($topicHeadNoBreak | Select-Object -First 3) -join '; ')") }
    if ($pcHeadNoBreak.Count)    { $fail.Add("$($pcHeadNoBreak.Count) PC sub-section heading(s) do not start a new page: $(($pcHeadNoBreak | Select-Object -First 3) -join '; ')") }

    # -------------------------------------------------- document control ban
    #
    # The spec forbids a document-control TABLE or approval/date FIELDS in the
    # guide body. It does not forbid the words, and in this house style a
    # CALLOUT IS A TABLE - so both a keyword sweep and a naive "table contains
    # two control labels" test report the reference guide's Note box, which
    # merely explains that document control is applied later, as a defect.
    #
    # The discriminator is structure, not vocabulary: a real control table is a
    # grid of many short label/value cells. A callout is one cell of prose. So
    # require several cells AND the labels to appear as SHORT CELL VALUES rather
    # than as words inside a paragraph.
    if (-not $AllowDocumentControl) {
        $labels = @('Document Control', 'Doc #', 'Doc#', 'Revision:', 'Ver#', 'Approved Date',
                    'Next Review', 'Approved by', 'Revision Date')

        foreach ($b in $blocks) {
            if ($b.Kind -ne 'table') { continue }
            $cells = [regex]::Matches($b.Xml, '<w:tc\b.*?</w:tc>', 'Singleline')
            if ($cells.Count -lt 4) { continue }        # a callout is one cell

            $labelCells = New-Object System.Collections.Generic.List[string]
            foreach ($m in $cells) {
                $ct = (-join ([regex]::Matches($m.Value, '<w:t[^>]*>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value })).Trim()
                if ($ct.Length -eq 0 -or $ct.Length -gt 40) { continue }   # prose, not a label
                foreach ($l in $labels) { if ($ct -match [regex]::Escape($l)) { $labelCells.Add($ct); break } }
            }
            if ($labelCells.Count -ge 2) {
                $fail.Add("a document-control table is present in the guide body (label cells: $(($labelCells | Select-Object -Unique) -join ', ')) - document control is applied later, in novacore.cloud, not here")
            }
        }

        if ($doc -match 'DOCPROPERTY') {
            $fail.Add('the guide body carries DOCPROPERTY field(s) - version and approval metadata must not be embedded in this document type')
        }
    }

    # Footers are reported, never failed. The spec says not to build one; the
    # delivered reference guide ships a full document-control footer. Where the
    # RTO's own artefact and the spec disagree, the artefact is the authority
    # and the divergence is recorded for the RTO to settle.
    foreach ($p in (Get-DocxParts -WorkDir $wd | Where-Object { $_ -match 'footer\d*\.xml$' })) {
        $fx = Get-DocxPart -WorkDir $wd -Part $p
        $ft = -join ([regex]::Matches($fx, '<w:t[^>]*>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value })
        if ($ft -match 'Doc\s?#|Next Review|Revision') {
            $info.Add("$p carries document-control metadata - divergence from the spec's no-footer rule; confirm with the RTO which stands")
        }
    }

    # ------------------------------------------------------------- artwork
    #
    # Before Stage 7b the guide SHOULD carry prompt blocks - they are how the
    # artwork gets briefed, and a guide with none has simply skipped visual
    # planning. After Stage 7b it must carry NONE: a prompt that survives
    # artwork is a prompt an auditor reads.
    $prompts = @()
    foreach ($b in $blocks) {
        if ($b.Kind -ne 'para') { continue }
        $m = [regex]::Match($b.Text.Trim(), '^\[\s*(IMAGE|DIAGRAM|ILLUSTRATION|PHOTO|FIGURE|PICTURE)\s*[:\-]')
        if ($m.Success) { $prompts += $m.Groups[1].Value.ToUpper() }
    }
    $pics = @([regex]::Matches($doc, '<(?:w|wp):(?:drawing|inline|anchor)\b')).Count

    if ($AfterArtwork) {
        if ($prompts.Count) {
            $fail.Add("$($prompts.Count) artwork prompt block(s) survived the artwork stage - these print as bracketed instructions on the page")
        }
        else { $info.Add("artwork: no prompt blocks remain; $pics placed drawing object(s)") }
    }
    else {
        $byKind = ($prompts | Group-Object | ForEach-Object { "$($_.Count) $($_.Name)" }) -join ', '
        if ($prompts.Count) { $info.Add("artwork: $($prompts.Count) prompt block(s) awaiting Stage 7b ($byKind)") }
        else { $warn.Add('no artwork prompt blocks found - the guide has no planned visuals; confirm this is intended before delivering') }
    }

    # ------------------------------------------------------- question x-ref
    #
    # Text is extracted PARAGRAPH BY PARAGRAPH, not by concatenating every
    # <w:t> in the part. Runs inside one paragraph do join directly - a word can
    # be split across runs by spell-check - but paragraphs must not, or the last
    # word of one runs into the first of the next. That created a real false
    # positive: a cell ending "Observation 1" abutting a heading starting "1.1"
    # was read as a citation of "Observation 11", an item no pack contains.
    $paraTexts = New-Object System.Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($doc, '<w:p\b.*?</w:p>', 'Singleline')) {
        $paraTexts.Add((-join ([regex]::Matches($m.Value, '<w:t[^>]*>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value })))
    }
    $textAll = $paraTexts -join "`n"
    # Normalise a citation to "<Label> <n><subpart>" so 'Q5', 'Q 5' and 'Task 10(b)'
    # all compare cleanly against whatever the pack calls them.
    $cited = @([regex]::Matches($textAll, $QuestionPattern) | ForEach-Object {
                   $label = ($_.Value -replace '\s*\d.*$', '').Trim()
                   "$label $($_.Groups[1].Value)$($_.Groups[2].Value)"
               } | Sort-Object -Unique)
    $info.Add("assessment items cited in the guide: $($cited.Count)")

    if ($QuestionsInPack -and $QuestionsInPack.Count) {
        # Compare on a key with ALL whitespace removed, so 'Q5', 'Q 5', 'q5' and
        # 'Task 10(b)' / 'Task10(b)' each collapse to one item. Merely
        # collapsing runs of spaces is not enough: the citation side rebuilds
        # the label and number with a space between them, so 'Q5' in the pack
        # would never match 'Q 5' from the document.
        function script:NormRef ([string] $s) { ($s -replace '\s+', '').ToLower() }
        $packSet  = @($QuestionsInPack | ForEach-Object { $_.Trim() } | Sort-Object -Unique)
        $packKeys = @($packSet | ForEach-Object { script:NormRef $_ })
        $citeKeys = @($cited   | ForEach-Object { script:NormRef $_ })

        $invented = @($cited | Where-Object {
            $k = script:NormRef $_
            ($packKeys -notcontains $k) -and ($packKeys -notcontains ($k -replace '\(.*\)$', '').Trim())
        })
        if ($invented.Count) { $fail.Add("the guide cites assessment item(s) the pack does not contain: $($invented -join ', ')") }

        $uncited = @($packSet | Where-Object {
            $k = script:NormRef $_
            ($citeKeys -notcontains $k) -and -not (@($citeKeys) -match ('^' + [regex]::Escape($k) + '\('))
        })
        if ($uncited.Count) { $fail.Add("assessment item(s) no topic prepares: $($uncited -join ', ')") }

        if (-not $invented.Count -and -not $uncited.Count) { $info.Add('assessment cross-reference reconciles in both directions') }
    }
    else { $info.Add('assessment cross-reference skipped - no -QuestionsInPack given') }

    return [pscustomobject]@{
        Ok            = ($fail.Count -eq 0)
        Failures      = $fail
        Warnings      = $warn
        Info          = $info
        ContentWidth  = $cw
        TopicWords    = $topicWords
        SubjectWords  = $subjWords
        CitedQuestions = $cited
    }
}

function Write-GuideRuleReport {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)] $Result)
    process {
        Write-Host ''
        Write-Host 'GUIDE GATE' -ForegroundColor Cyan
        foreach ($i in $Result.Info)     { Write-Host "  .  $i" -ForegroundColor DarkGray }
        foreach ($w in $Result.Warnings) { Write-Host "  ~  $w" -ForegroundColor Yellow }
        foreach ($f in $Result.Failures) { Write-Host "  X  $f" -ForegroundColor Red }
        if ($Result.Ok) { Write-Host '  PASS' -ForegroundColor Green }
        else            { Write-Host "  FAIL - $($Result.Failures.Count) blocking" -ForegroundColor Red }
        Write-Host ''
    }
}
