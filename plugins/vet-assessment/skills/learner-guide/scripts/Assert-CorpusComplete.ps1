<#
    Assert-CorpusComplete.ps1 - every document in the source pack is extracted
    EXACTLY ONCE into the canonical corpus, nothing in the corpus came from
    outside the pack, and every extraction is proved FAITHFUL and not merely
    present.

    Implements the Stage 1 gate gates.md section 20 calls Assert-CorpusComplete.
    Runs before authoring opens. Blocks.

        .\Assert-CorpusComplete.ps1 -BuildDir $out -PackDir $pack

    WHY THIS GATE EXISTS AT ALL. Every gate downstream of Stage 1 - every
    provenance check, every leakage sweep, every "the pack wins" adjudication -
    reads the corpus and nothing else. A pack document that was never extracted
    is a document no later gate has ever seen, and each of them reports clean
    about it. In one build the assessor guide and the workbook were extracted
    TWICE, byte-identically, four hours apart, while the two knowledge-task
    documents had no early extraction at all; the open-book leak found at round
    three was against precisely the document nobody had extracted. You cannot
    sweep a corpus you have not extracted, and a duplicate silently doubles
    every count while hiding a divergence between the two copies.

    PRESENCE IS NOT FIDELITY, AND THAT IS THE HALF THAT GETS MISSED. A count
    of files against a count of documents passes an extraction that produced a
    cover sheet and no body - and that extraction lets every downstream gate
    report clean, because the text it would have failed on is not in the file.
    So each pair is compared on a cheap content signature cut from the pack
    document itself:

      paragraphs   non-empty body paragraphs of the pack document
      characters   the joined body text length, against the corpus file's, as
                   a ratio inside a declared band
      coverage     what fraction of the pack document's distinct substantive
                   paragraphs appear as lines of the corpus file
      head / tail  how much of the FIRST and LAST window of substantive
                   paragraphs survived into the corpus

    The head and tail windows are what catch truncation specifically: an
    extraction that kept its header and lost its body scores a full head and an
    empty tail. A single first-line and last-line equality is reported too,
    because the specification asks for it and it is useful evidence, but it is
    NOT what the verdict rests on: real extractors legitimately drop a running
    footer and legitimately append drawing alt text after the last body
    paragraph, and a gate that failed on that would be re-run until it was
    ignored. The window test survives both and still fails a truncation.

    NOTHING HERE IS HAND-LISTED. The document set is enumerated from the pack
    directory the build was given (or read from a pack manifest where one
    exists), the corpus is located by Lib-GateCommon's shared locator so this
    gate can never read a different extraction from the gates that follow it,
    and the pack directory itself is resolved from the build contract or the
    corpus's own generated-by record rather than typed. The gate prints the
    size of every set it checked and the source it derived it from.

    RENDITIONS ARE NOT DOCUMENTS. A pack commonly ships each document as both
    a .docx and a .pdf, and sometimes keeps a working copy beside the delivered
    one. Files are therefore grouped into logical documents by stem, and one
    rendition per document supplies the signature - the extractable one by
    preference. Two renditions of one document is not a duplicate extraction.
    Two CORPUS files for one document is.

    WHAT IT REFUSES TO PRINT. An assessor guide's text is not echoed by this
    gate. For a corpus document classified assessor-only the signature lines
    are reported as a length and a short hash rather than as text, because a
    first or last line of a marking guide can be a model answer and a gate's
    own console output is not a safe place to find that out. The verdict is
    unaffected: every comparison is made on normalised text this script never
    prints.

    TRUSTED ONLY AFTER FAILING ON A PLANTED DEFECT. -SelfTest builds a small
    pack and its corpus from scratch in a temp directory - it never touches a
    real build - and plants, one at a time: a missing extraction, a doubled
    extraction under a second name, a truncation that keeps its header, and a
    corpus file with no pack ancestor. EVERY PLANT IS READ BACK AND VERIFIED TO
    HAVE LANDED before the gate is run against it, because a plant that lands
    where the defect cannot occur proves nothing and passes, and that has
    already been recorded once on this project as evidence a gate worked.

    PS 5.1. ASCII only in this file. Nothing here names a unit, a brand, an
    RTO or a build path.

    THE HASH IS COMPARED, NOT MERELY RECORDED. The corpus manifest Stage 1
    writes (corpus\manifest.json) records the sha256 of the SOURCE rendition
    each extract was cut from. This gate recomputes the sha256 of that pack
    file and FAILS naming both values when they differ: an extract cut from a
    file the pack no longer holds is an extract of a different document,
    however faithful it looks against the pack that was there at the time. The
    sha256 of every extract is recorded into corpus-complete.json so a later
    stage can prove the corpus it read is the corpus this gate passed; where
    the manifest also records an extract hash (extractSha256) it is compared
    the same way. A manifest that records no source hash at all is a refusal
    naming it - the comparison cannot run, and a comparison that cannot run is
    not a pass.

    Exit 0 complete and faithful, 1 a reconciliation or fidelity failure,
    2 a usage error, 4 the self-test failed, 5 complete but at least one
    extraction's fidelity could not be proved at all.
#>

# GATE: stages=1; requires=BuildDir,PackDir

[CmdletBinding()]
param(
    #  The build directory. The corpus and the contract are found under it.
    [string] $BuildDir,
    #  The source pack. Default: the contract's build.packDir, then the
    #  packDir recorded by whatever generated the corpus, then the ledger.
    [string] $PackDir,
    #  Override the canonical corpus directory. Resolved by Lib-GateCommon
    #  otherwise, so that this gate and every later gate read one extraction.
    [string] $CorpusDir,
    #  An explicit pack manifest. Default: manifest.json / pack-manifest.json
    #  in the pack directory, then the contract's corpus block.
    [string] $ManifestPath,
    #  Enumerate the pack directory recursively. Off by default: a pack
    #  directory that is really a build tree carries templates, staging copies
    #  and working files that are not pack documents, and quietly counting them
    #  as unextracted would make this gate impossible to pass honestly.
    [switch] $Recurse,
    #  What counts as a document. A format list, not an allow-list of names.
    [string[]] $DocumentExtension = @('.docx', '.doc', '.pdf', '.pptx', '.ppt', '.xlsx', '.xls', '.rtf', '.odt'),
    #  Fidelity thresholds. Explicit value, else the contract's corpus.fidelity
    #  block, else the documented default.
    [double] $CoverageFloor,
    [double] $CharRatioLow,
    [double] $CharRatioHigh,
    [int]    $EdgeWindow,
    [double] $EdgeFloor,
    [double] $DuplicateCoverage,
    #  Where to write the machine-readable reconciliation.
    [string] $ResultPath,
    [switch] $SelfTest,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

$GATE = 'Assert-CorpusComplete'
$script:Self = $PSCommandPath

$DEFAULT_COVERAGE_FLOOR = 0.85
$DEFAULT_CHAR_LOW       = 0.60
$DEFAULT_CHAR_HIGH      = 1.75
$DEFAULT_EDGE_WINDOW    = 10
$DEFAULT_EDGE_FLOOR     = 0.50
$DEFAULT_DUP_COVERAGE   = 0.98
$MIN_SUBSTANTIVE        = 12    # normalised characters before a line is evidence

function Fail-Usage {
    param([string] $Message)
    Write-Host ("  X {0}: {1}" -f $GATE, $Message) -ForegroundColor Red
    exit 2
}

# ---------------------------------------------------------------------------
# Private helpers. Defined here rather than in Lib-GateCommon because nothing
# else in the gate set reads a pack document's bytes; the shared library
# locates and classifies the corpus and this gate does the reconciling.
# ---------------------------------------------------------------------------

function Get-FileSha256 {
    param([Parameter(Mandatory)][string] $Path)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $fs = [System.IO.File]::OpenRead($Path)
        try { return (([BitConverter]::ToString($sha.ComputeHash($fs))) -replace '-', '').ToLowerInvariant() }
        finally { $fs.Dispose() }
    }
    finally { $sha.Dispose() }
}

function Get-OpenXmlParts {
    <#  The body parts whose text is the document, per package type. Headers,
        footers and the table of contents are deliberately NOT read: an
        extractor legitimately drops a running footer, and counting one as
        missing body would make every honest extraction look truncated.  #>
    param([Parameter(Mandatory)][string] $Extension)
    switch ($Extension.ToLowerInvariant()) {
        '.docx' { return '^word/document\.xml$' }
        '.pptx' { return '^ppt/(slides|notesSlides)/[^/]+\.xml$' }
        default { return $null }
    }
}

function Get-PackDocumentText {
    <#  The non-empty body paragraphs of an Open XML package, in order.

        Read straight out of the zip. Word COM is minutes per document on this
        toolchain and is not needed to count paragraphs and characters, and a
        gate nobody can afford to run is a gate that does not run.  #>
    param([Parameter(Mandatory)][string] $Path)

    $ext = [System.IO.Path]::GetExtension($Path)
    $rx = Get-OpenXmlParts -Extension $ext
    if (-not $rx) { return $null }

    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue | Out-Null
    $lines = New-Object System.Collections.Generic.List[string]
    $zip = $null
    try { $zip = [System.IO.Compression.ZipFile]::OpenRead($Path) } catch { return $null }
    try {
        $entries = @($zip.Entries | Where-Object { $_.FullName -match $rx } | Sort-Object FullName)
        if ($entries.Count -eq 0) { return $null }
        foreach ($e in $entries) {
            $sr = New-Object System.IO.StreamReader($e.Open(), [System.Text.Encoding]::UTF8)
            try { $xml = $sr.ReadToEnd() } finally { $sr.Dispose() }
            #  Field instructions carry PAGEREF and TOC switches, which are not
            #  text anybody wrote and are not in any extract.
            $xml = $xml -replace '(?s)<w:instrText.*?</w:instrText>', ''
            $xml = $xml -replace '<w:br[^>]*/>', "`n"
            $xml = $xml -replace '<w:tab[^>]*/>', ' '
            $xml = $xml -replace '</w:p>', "`n"
            $xml = $xml -replace '</w:tc>', "`n"
            $xml = $xml -replace '</a:p>', "`n"
            $t = [regex]::Replace($xml, '<[^>]+>', '')
            $t = [System.Net.WebUtility]::HtmlDecode($t)
            foreach ($ln in ($t -split "`n")) {
                $s = $ln.Trim()
                if ($s) { $lines.Add($s) }
            }
        }
    }
    finally { $zip.Dispose() }
    if ($lines.Count -eq 0) { return $null }
    return $lines.ToArray()
}

function Get-NormalLines {
    param([string[]] $Lines)
    $out = New-Object System.Collections.Generic.List[string]
    if ($null -eq $Lines) { return $out.ToArray() }
    foreach ($l in $Lines) {
        if ($null -eq $l) { continue }
        $n = ConvertTo-GateNormal $l
        if ($n.Length -ge $MIN_SUBSTANTIVE) { $out.Add($n) }
    }
    return $out.ToArray()
}

function New-NormalSet {
    param([string[]] $Normal)
    $set = New-Object 'System.Collections.Generic.HashSet[string]'
    if ($null -eq $Normal) { return $set }
    foreach ($n in $Normal) { [void]$set.Add($n) }
    return $set
}

function Measure-Coverage {
    <# What fraction of $Needle (distinct normalised lines) is in $HaySet. #>
    param($Needle, $HaySet)
    $tot = 0
    $hit = 0
    if ($null -ne $Needle) {
        foreach ($n in $Needle) {
            $tot++
            if ($HaySet.Contains($n)) { $hit++ }
        }
    }
    $ratio = 0.0
    if ($tot -gt 0) { $ratio = [double]$hit / [double]$tot }
    return [pscustomobject]@{ Ratio = $ratio; Hit = $hit; Total = $tot }
}

function Get-TextLines {
    param([string] $Text)
    $out = New-Object System.Collections.Generic.List[string]
    if ($null -eq $Text) { return $out.ToArray() }
    foreach ($ln in ($Text -split "`r?`n")) {
        $s = $ln.Trim()
        if ($s) { $out.Add($s) }
    }
    return $out.ToArray()
}

function Get-StemKey {
    <# Two renditions of one document share a stem; compare stems normalised. #>
    param([string] $Name)
    $s = [System.IO.Path]::GetFileNameWithoutExtension($Name)
    return (ConvertTo-GateNormal $s)
}

function Get-ShortHash {
    param([string] $Text)
    if (-not $Text) { return '00000000' }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $b = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text))
        return ((([BitConverter]::ToString($b)) -replace '-', '').ToLowerInvariant()).Substring(0, 8)
    }
    finally { $sha.Dispose() }
}

function Show-Edge {
    <#  A signature line, shown as text for a learner-facing document and as a
        length and short hash for an assessor-only one. A marking guide's last
        line can be a model answer, and a gate's console is not where anyone
        should discover that.  #>
    param([string] $Text, [string] $Audience)
    if ($null -eq $Text) { $Text = '' }
    if ($Audience -eq 'assessor') {
        return ('[assessor-only, withheld: {0} chars, sha8 {1}]' -f $Text.Length, (Get-ShortHash $Text))
    }
    $t = $Text -replace '\s+', ' '
    if ($t.Length -gt 70) { $t = $t.Substring(0, 67) + '...' }
    return $t
}

function Resolve-Number {
    param([bool] $Explicit, [double] $Value, $Node, [string[]] $Names, [double] $Default, [string] $Label)
    if ($Explicit) { return [pscustomobject]@{ Value = $Value; From = 'parameter' } }
    if ($null -ne $Node) {
        $v = Get-GateProp -Object $Node -Names $Names
        if ($null -ne $v) { return [pscustomobject]@{ Value = [double]$v; From = ('contract corpus.fidelity.' + $Label) } }
    }
    return [pscustomobject]@{ Value = $Default; From = 'skill default' }
}

function Write-Result {
    param([string] $Path, [System.Collections.IDictionary] $Body)
    if (-not $Path) { return }
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $json = [pscustomobject]$Body | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($true)))
}

# ---------------------------------------------------------------------------
# SELF-TEST - a pack and a corpus built from nothing, with verified plants
# ---------------------------------------------------------------------------

function New-FixtureDocx {
    <#  The smallest package this gate's reader accepts: content types, the
        root relationships and a body. Never opened by Word, only by the zip
        reader above, so nothing else is needed.  #>
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][string[]] $Paragraph)

    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue | Out-Null
    Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue | Out-Null

    $body = New-Object System.Text.StringBuilder
    [void]$body.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    [void]$body.Append('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>')
    foreach ($p in $Paragraph) {
        $esc = [System.Security.SecurityElement]::Escape($p)
        [void]$body.Append('<w:p><w:r><w:t xml:space="preserve">')
        [void]$body.Append($esc)
        [void]$body.Append('</w:t></w:r></w:p>')
    }
    [void]$body.Append('</w:body></w:document>')

    $ct = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>'
    $rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>'

    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Force }
    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::CreateNew)
    try {
        $zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($pair in @(
                @{ n = '[Content_Types].xml'; t = $ct },
                @{ n = '_rels/.rels';         t = $rels },
                @{ n = 'word/document.xml';   t = $body.ToString() })) {
                $e = $zip.CreateEntry($pair.n)
                $sw = New-Object System.IO.StreamWriter($e.Open(), (New-Object System.Text.UTF8Encoding($false)))
                try { $sw.Write($pair.t) } finally { $sw.Dispose() }
            }
        }
        finally { $zip.Dispose() }
    }
    finally { $fs.Dispose() }
}

function New-FixtureParagraphs {
    <# Enough distinct substantive paragraphs that coverage is meaningful. #>
    param([Parameter(Mandatory)][string] $Tag, [int] $Count = 60)
    $out = New-Object System.Collections.Generic.List[string]
    $out.Add('ASSESSMENT COVER SHEET')
    $out.Add(('Document tag for this fixture is {0} and it is unique to it.' -f $Tag))
    for ($i = 1; $i -le $Count; $i++) {
        $out.Add(('{0} paragraph {1}: a sentence long enough to be substantive evidence of extraction fidelity.' -f $Tag, $i))
    }
    $out.Add(('{0} closing statement, the last body paragraph of this fixture document.' -f $Tag))
    return $out.ToArray()
}

if ($SelfTest) {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('corpuscomplete_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $fxPack = Join-Path $tmp 'pack'
    $fxBuild = Join-Path $tmp 'build'
    $fxCorpus = Join-Path $fxBuild 'corpus'
    $cases = New-Object System.Collections.Generic.List[object]

    function Record {
        param([string] $Name, [bool] $Ok, [string] $Detail)
        $cases.Add([pscustomobject]@{ name = $Name; ok = $Ok; detail = $Detail })
        if (-not $Quiet) {
            if ($Ok) { Write-Host ('  PASS  {0}: {1}' -f $Name, $Detail) -ForegroundColor Green }
            else     { Write-Host ('  FAIL  {0}: {1}' -f $Name, $Detail) -ForegroundColor Red }
        }
    }
    function Invoke-Child {
        #  Hashtable splat, never an array: array elements bind by position, so
        #  a '-PackDir' string would land in -BuildDir.
        param([hashtable] $Params)
        $r = Join-Path $tmp ('result_' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.json')
        $global:LASTEXITCODE = 0
        #  *>&1: a refusal (exit 2) writes no result file and speaks through
        #  Write-Host, so the console is the only place its name can be read.
        $text = & $script:Self @Params -ResultPath $r -Quiet *>&1 | Out-String -Width 8192
        $code = $LASTEXITCODE
        $body = $null
        if (Test-Path -LiteralPath $r) { $body = Get-GateJson -Path $r }
        return [pscustomobject]@{ Code = $code; Result = $body; Text = $text }
    }
    function Reset-Fixture {
        #  The corpus, plus the manifest Stage 1's extractor writes beside it:
        #  file, source, audience, the sha256 of the source rendition and of
        #  the extract. -NoHash writes the manifest without either hash, for
        #  the refusal plant.
        param([switch] $NoHash)
        if (Test-Path -LiteralPath $fxCorpus) { Remove-Item -LiteralPath $fxCorpus -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $fxCorpus | Out-Null
        $docs = New-Object System.Collections.Generic.List[object]
        foreach ($k in @('Alpha_Tool', 'Beta_Tool', 'Assessor_Guide_Alpha_Tool')) {
            $paras = New-FixtureParagraphs -Tag $k
            $txt = Join-Path $fxCorpus ($k + '.txt')
            [System.IO.File]::WriteAllText($txt, (($paras -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
            $d = [ordered]@{ file = ($k + '.txt'); source = ($k + '.docx'); audience = $(if ($k -like 'Assessor_*') { 'assessor' } else { 'learner' }) }
            if (-not $NoHash) {
                $d['sha256'] = (Get-FileSha256 -Path (Join-Path $fxPack ($k + '.docx'))).ToUpperInvariant()
                $d['extractSha256'] = (Get-FileSha256 -Path $txt)
            }
            $docs.Add([pscustomobject]$d)
        }
        $man = [ordered]@{ generatedBy = 'self-test fixture'; documents = $docs.ToArray() }
        [System.IO.File]::WriteAllText((Join-Path $fxCorpus 'manifest.json'), ($man | ConvertTo-Json -Depth 5), (New-Object System.Text.UTF8Encoding($true)))
    }
    function Get-Failures {
        param($Res)
        if ($null -eq $Res) { return @() }
        $f = Get-GateProp -Object $Res -Names @('failures') -Default @()
        return @($f | ForEach-Object { [string]$_ })
    }

    try {
        New-Item -ItemType Directory -Force -Path $fxPack | Out-Null
        New-Item -ItemType Directory -Force -Path $fxCorpus | Out-Null
        foreach ($k in @('Alpha_Tool', 'Beta_Tool', 'Assessor_Guide_Alpha_Tool')) {
            New-FixtureDocx -Path (Join-Path $fxPack ($k + '.docx')) -Paragraph (New-FixtureParagraphs -Tag $k)
        }
        $base = @{ BuildDir = $fxBuild; PackDir = $fxPack }

        if (-not $Quiet) {
            Write-Host ''
            Write-Host ('{0} SELF-TEST on a fixture pack and corpus built from nothing' -f $GATE) -ForegroundColor Cyan
            Write-Host ('  fixture: {0}' -f $tmp) -ForegroundColor DarkGray
            Write-Host ''
        }

        # (a) control - a complete, faithful corpus passes
        Reset-Fixture
        $planted = @(Get-ChildItem -LiteralPath $fxCorpus -Filter '*.txt' -File).Count
        if ($planted -ne 3) { Record 'control' $false ('the fixture did not build: {0} corpus files, expected 3' -f $planted) }
        else {
            $c = Invoke-Child $base
            Record 'control' ($c.Code -eq 0) ('a complete faithful corpus of 3 documents; exit {0}' -f $c.Code)
        }

        # (b) a missing extraction
        Reset-Fixture
        $victim = Join-Path $fxCorpus 'Beta_Tool.txt'
        Remove-Item -LiteralPath $victim -Force
        if (Test-Path -LiteralPath $victim) { Record 'missing extraction' $false 'the plant did not land: the file is still on disk' }
        else {
            $c = Invoke-Child $base
            $named = @(Get-Failures $c.Result | Where-Object { $_ -match 'Beta_Tool' -and $_ -match '(?i)not extracted|missing' })
            Record 'missing extraction' (($c.Code -eq 1) -and ($named.Count -ge 1)) ('deleted Beta_Tool.txt; exit {0}; {1}' -f $c.Code, $(if ($named.Count) { $named[0] } else { 'the missing document was NOT named' }))
        }

        # (c) a doubled extraction under a second name
        Reset-Fixture
        $src = Join-Path $fxCorpus 'Alpha_Tool.txt'
        $dup = Join-Path $fxCorpus 'Alpha_Tool_copy.txt'
        Copy-Item -LiteralPath $src -Destination $dup -Force
        $hSrc = Get-FileSha256 -Path $src
        $hDup = Get-FileSha256 -Path $dup
        if ($hSrc -ne $hDup) { Record 'doubled extraction' $false 'the plant did not land: the two corpus files do not hash alike' }
        else {
            $c = Invoke-Child $base
            $named = @(Get-Failures $c.Result | Where-Object { $_ -match '(?i)twice|doubled|duplicate' -and $_ -match 'Alpha_Tool' })
            Record 'doubled extraction' (($c.Code -eq 1) -and ($named.Count -ge 1)) ('Alpha_Tool extracted under two names, identical sha256 {0}; exit {1}; {2}' -f $hSrc.Substring(0, 8), $c.Code, $(if ($named.Count) { $named[0] } else { 'the duplicate was NOT named' }))
        }

        # (d) a truncation that keeps its header
        Reset-Fixture
        $trunc = Join-Path $fxCorpus 'Beta_Tool.txt'
        $keep = @(Get-TextLines -Text (Get-GateFileText -Path $trunc) | Select-Object -First 3)
        [System.IO.File]::WriteAllText($trunc, (($keep -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
        $back = @(Get-TextLines -Text (Get-GateFileText -Path $trunc))
        $headKept = ($back.Count -gt 0 -and $back[0] -eq 'ASSESSMENT COVER SHEET')
        if (-not ($back.Count -eq 3 -and $headKept)) { Record 'truncated extraction' $false ('the plant did not land: {0} line(s) survived, header kept = {1}' -f $back.Count, $headKept) }
        else {
            $c = Invoke-Child $base
            $named = @(Get-Failures $c.Result | Where-Object { $_ -match 'Beta_Tool' -and $_ -match '(?i)truncat|coverage|tail' })
            Record 'truncated extraction' (($c.Code -eq 1) -and ($named.Count -ge 1)) ('Beta_Tool cut to its header, 3 lines; exit {0}; {1}' -f $c.Code, $(if ($named.Count) { $named[0] } else { 'the truncation was NOT named' }))
        }

        # (e) a corpus file with no pack ancestor
        Reset-Fixture
        $alien = Join-Path $fxCorpus 'Gamma_Handout.txt'
        $alienText = ((New-FixtureParagraphs -Tag 'Gamma_Handout') -join "`r`n") + "`r`n"
        [System.IO.File]::WriteAllText($alien, $alienText, (New-Object System.Text.UTF8Encoding($true)))
        $alienBack = Get-GateFileText -Path $alien
        $packStems = @(Get-ChildItem -LiteralPath $fxPack -Filter '*.docx' -File | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) })
        $collides = @($packStems | Where-Object { $_ -eq 'Gamma_Handout' })
        if (-not $alienBack -or $collides.Count -gt 0) { Record 'unknown provenance' $false 'the plant did not land: the file is empty, or its stem collides with a pack document' }
        else {
            $c = Invoke-Child $base
            $named = @(Get-Failures $c.Result | Where-Object { $_ -match 'Gamma_Handout' -and $_ -match '(?i)provenance|no pack' })
            Record 'unknown provenance' (($c.Code -eq 1) -and ($named.Count -ge 1)) ('Gamma_Handout.txt has no pack ancestor; exit {0}; {1}' -f $c.Code, $(if ($named.Count) { $named[0] } else { 'the stranger was NOT named' }))
        }

        # (g) one altered byte in a SOURCE rendition: the pack file no longer
        #     hashes to what the manifest recorded when the extract was cut.
        #     The fidelity arms cannot see it (61 of 62 paragraphs still match);
        #     only the hash comparison can, and it must name both values.
        Reset-Fixture
        $betaDocx = Join-Path $fxPack 'Beta_Tool.docx'
        $recordedBeta = (Get-FileSha256 -Path $betaDocx)
        $altered = New-FixtureParagraphs -Tag 'Beta_Tool'
        $altered[5] = $altered[5] + '.'
        New-FixtureDocx -Path $betaDocx -Paragraph $altered
        $nowBeta = (Get-FileSha256 -Path $betaDocx)
        if ($nowBeta -eq $recordedBeta) { Record 'source hash mismatch' $false 'the plant did not land: the rebuilt source hashes the same' }
        else {
            $c = Invoke-Child $base
            $named = @(Get-Failures $c.Result | Where-Object { $_ -match 'Beta_Tool' -and $_ -match 'SOURCE HASH MISMATCH' -and $_ -match $nowBeta -and $_ -match $recordedBeta })
            Record 'source hash mismatch' (($c.Code -eq 1) -and ($named.Count -ge 1)) ('Beta_Tool.docx rebuilt with one extra byte, sha256 {0} against recorded {1}; exit {2}; {3}' -f $nowBeta.Substring(0, 8), $recordedBeta.Substring(0, 8), $c.Code, $(if ($named.Count) { 'named with both values' } else { 'the mismatch was NOT named with both values' }))
        }
        New-FixtureDocx -Path $betaDocx -Paragraph (New-FixtureParagraphs -Tag 'Beta_Tool')

        # (h) one altered byte in an EXTRACT, with the manifest recording the
        #     extract hash: below every fidelity threshold, caught by the hash.
        Reset-Fixture
        $betaTxt = Join-Path $fxCorpus 'Beta_Tool.txt'
        $recordedTxt = (Get-FileSha256 -Path $betaTxt)
        $t = Get-GateFileText -Path $betaTxt
        $t = $t.Replace('paragraph 3:', 'paragraph 3;')
        [System.IO.File]::WriteAllText($betaTxt, $t, (New-Object System.Text.UTF8Encoding($true)))
        $nowTxt = (Get-FileSha256 -Path $betaTxt)
        if ($nowTxt -eq $recordedTxt) { Record 'extract hash mismatch' $false 'the plant did not land: the extract hashes the same' }
        else {
            $c = Invoke-Child $base
            $named = @(Get-Failures $c.Result | Where-Object { $_ -match 'Beta_Tool' -and $_ -match 'EXTRACT HASH MISMATCH' -and $_ -match $nowTxt -and $_ -match $recordedTxt })
            $fid = @(Get-Failures $c.Result | Where-Object { $_ -match 'Beta_Tool' -and $_ -match '(?i)coverage|truncat' })
            Record 'extract hash mismatch' (($c.Code -eq 1) -and ($named.Count -ge 1) -and ($fid.Count -eq 0)) ('one byte of Beta_Tool.txt changed; exit {0}; {1}; fidelity arms {2}' -f $c.Code, $(if ($named.Count) { 'named with both values' } else { 'the mismatch was NOT named with both values' }), $(if ($fid.Count) { 'ALSO fired, so the hash arm proved nothing on its own' } else { 'silent, so the hash arm is what caught it' }))
        }

        # (i) a manifest that records no source hash at all is a refusal
        #     naming it - the comparison cannot run, and that is not a pass.
        Reset-Fixture -NoHash
        $mj = Get-GateJson -Path (Join-Path $fxCorpus 'manifest.json')
        $anyHash = @(@($mj.documents) | Where-Object { $_.PSObject.Properties.Name -contains 'sha256' }).Count
        if ($anyHash -gt 0) { Record 'no recorded hash refuses' $false 'the plant did not land: the manifest still records a hash' }
        else {
            $c = Invoke-Child $base
            Record 'no recorded hash refuses' (($c.Code -eq 2) -and ($c.Text -match 'CHECK-SET EMPTY') -and ($c.Text -match 'manifest\.json')) ('manifest with no sha256; exit {0}; {1}' -f $c.Code, $(if ($c.Text -match 'manifest\.json') { 'the refusal names manifest.json' } else { 'the refusal did NOT name the manifest' }))
        }

        # (j) the roster: every arm complete on the clean fixture, and the
        #     extract hashes recorded in the result for every document.
        Reset-Fixture
        $c = Invoke-Child $base
        $armsOk = ($c.Text -match 'ARMS: ' -and $c.Text -match 'source-hash\|true\|ran\|3\|0' -and $c.Text -match 'fidelity\|true\|ran\|3\|0')
        $recorded = @(@($c.Result.documents) | Where-Object { $_.extractSha256 -match '^[0-9a-f]{64}$' }).Count
        Record 'roster and recorded hashes' (($c.Code -eq 0) -and $armsOk -and ($recorded -eq 3)) ('exit {0}; roster line {1}; {2} of 3 rows carry a 64-hex extractSha256' -f $c.Code, $(if ($armsOk) { 'shows source-hash and fidelity ran over 3' } else { 'MISSING or wrong' }), $recorded)

        # (k) the control again, after every plant, so a fixture left dirty by
        #     an earlier case cannot make a later green mean nothing.
        Reset-Fixture
        $c = Invoke-Child $base
        Record 'control after plants' ($c.Code -eq 0) ('the fixture restores clean; exit {0}' -f $c.Code)
    }
    finally {
        if ($tmp -and (Test-Path -LiteralPath $tmp) -and $tmp.Length -gt 12) {
            Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $bad = @($cases.ToArray() | Where-Object { -not $_.ok })
    $stCode = 0
    if ($bad.Count -gt 0) { $stCode = 4 }
    if (-not $Quiet) {
        Write-Host ''
        if ($stCode -eq 0) { Write-Host ('  self-test: {0} of {0} cases passed. This gate can fail.' -f $cases.Count) -ForegroundColor Green }
        else { Write-Host ('  X self-test: {0} of {1} cases FAILED. Do not trust a green from this gate until they pass.' -f $bad.Count, $cases.Count) -ForegroundColor Red }
    }
    $stBody = [ordered]@{}
    $stBody['gate']      = $GATE
    $stBody['mode']      = 'selftest'
    $stBody['verdict']   = $(if ($stCode -eq 0) { 'PASS' } else { 'FAIL' })
    $stBody['failures']  = @($bad | ForEach-Object { '{0}: {1}' -f $_.name, $_.detail })
    $stBody['cases']     = $cases.ToArray()
    $stBody['checkedAt'] = (Get-Date).ToUniversalTime().ToString('o')
    $stBody['exitCode']  = [int]$stCode
    Write-Result -Path $ResultPath -Body $stBody
    exit $stCode
}

# ---------------------------------------------------------------------------
# 1. Locate the corpus, the contract and the pack - each with its provenance
# ---------------------------------------------------------------------------

if (-not $BuildDir -and -not $CorpusDir) { Fail-Usage 'pass -BuildDir (the corpus and the contract are found under it), or -CorpusDir.' }
if ($BuildDir -and -not (Test-Path -LiteralPath $BuildDir)) { Fail-Usage ('build directory not found: {0}' -f $BuildDir) }

$corpusPath = $null
try { $corpusPath = Get-GateCorpusDir -BuildDir $(if ($BuildDir) { $BuildDir } else { (Split-Path -Parent $CorpusDir) }) -CorpusDir $CorpusDir }
catch { Fail-Usage $_.Exception.Message }

$contract = $null
if ($BuildDir) { $contract = Get-GateContract -BuildDir $BuildDir }

$packFrom = 'parameter'
if (-not $PackDir) {
    if ($null -ne $contract) {
        $PackDir = [string](Get-GateProp -Object $contract.build -Names @('packDir', 'packDirectory', 'sourcePack') -Default '')
        if ($PackDir) { $packFrom = 'contract build.packDir' }
    }
}
if (-not $PackDir) {
    #  Whatever generated the typed pack data records the pack it read. This is
    #  the corpus stating its own provenance, which is exactly what is wanted.
    foreach ($cand in @('grids.json', 'manifest.json')) {
        $g = Get-GateJson -Path (Join-Path $corpusPath $cand)
        if ($null -eq $g) { continue }
        $gen = Get-GateProp -Object $g -Names @('generated', 'generatedBy', 'provenance')
        $p = [string](Get-GateProp -Object $gen -Names @('packDir', 'packDirectory') -Default '')
        if ($p) { $PackDir = $p; $packFrom = ('{0} generated.packDir, in the corpus' -f $cand); break }
    }
}
if (-not $PackDir -and $BuildDir) {
    $led = Get-GateJson -Path (Join-Path $BuildDir 'stage-ledger.json')
    if ($null -ne $led) {
        $p = [string](Get-GateProp -Object $led -Names @('packDir', 'packDirectory') -Default '')
        if ($p) { $PackDir = $p; $packFrom = 'stage-ledger.json' }
    }
}
if (-not $PackDir) {
    Fail-Usage 'no pack directory. Pass -PackDir, or give a build whose contract records build.packDir. A completeness gate with no pack to reconcile against would count the corpus against itself and always pass.'
}
if (-not (Test-Path -LiteralPath $PackDir)) { Fail-Usage ('pack directory not found ({0}): {1}' -f $packFrom, $PackDir) }
$packPath = (Resolve-Path -LiteralPath $PackDir).Path

$fidNode = $null
if ($null -ne $contract) {
    $cnode = Get-GateProp -Object $contract -Names @('corpus')
    if ($null -ne $cnode) { $fidNode = Get-GateProp -Object $cnode -Names @('fidelity', 'signature') }
}
$rCov  = Resolve-Number -Explicit $PSBoundParameters.ContainsKey('CoverageFloor')     -Value $CoverageFloor     -Node $fidNode -Names @('coverageFloor', 'coverage')       -Default $DEFAULT_COVERAGE_FLOOR -Label 'coverageFloor'
$rLow  = Resolve-Number -Explicit $PSBoundParameters.ContainsKey('CharRatioLow')      -Value $CharRatioLow      -Node $fidNode -Names @('charRatioLow', 'charLow')          -Default $DEFAULT_CHAR_LOW       -Label 'charRatioLow'
$rHigh = Resolve-Number -Explicit $PSBoundParameters.ContainsKey('CharRatioHigh')     -Value $CharRatioHigh     -Node $fidNode -Names @('charRatioHigh', 'charHigh')        -Default $DEFAULT_CHAR_HIGH      -Label 'charRatioHigh'
$rWin  = Resolve-Number -Explicit $PSBoundParameters.ContainsKey('EdgeWindow')        -Value $EdgeWindow        -Node $fidNode -Names @('edgeWindow', 'window')             -Default $DEFAULT_EDGE_WINDOW    -Label 'edgeWindow'
$rEdge = Resolve-Number -Explicit $PSBoundParameters.ContainsKey('EdgeFloor')         -Value $EdgeFloor         -Node $fidNode -Names @('edgeFloor')                        -Default $DEFAULT_EDGE_FLOOR     -Label 'edgeFloor'
$rDup  = Resolve-Number -Explicit $PSBoundParameters.ContainsKey('DuplicateCoverage') -Value $DuplicateCoverage -Node $fidNode -Names @('duplicateCoverage', 'duplicate')   -Default $DEFAULT_DUP_COVERAGE   -Label 'duplicateCoverage'
$covFloor = $rCov.Value
$charLow  = $rLow.Value
$charHigh = $rHigh.Value
$edgeWin  = [int]$rWin.Value
$edgeMin  = $rEdge.Value
$dupCov   = $rDup.Value

if (-not $ResultPath -and $BuildDir) { $ResultPath = Join-Path $BuildDir 'corpus-complete.json' }

#  The arm roster (Lib-GateCommon). Every arm ends ran / empty / declared-n-a;
#  a blocking arm with an empty check-set is a refusal, exit 2, never a pass.
Reset-GateArmRoster
Register-GateArm -Name 'pack-documents' -Blocking
Register-GateArm -Name 'corpus-extracts' -Blocking
Register-GateArm -Name 'fidelity' -Blocking
Register-GateArm -Name 'source-hash' -Blocking
Register-GateArm -Name 'extract-hash'
function Stop-OnRefusal {
    <# The library's typed refusals reach exit 2 through here. #>
    param($Err)
    $m = $Err.Exception.Message
    if ($m -match '^(CHECK-SET EMPTY|ARMS INCOMPLETE):') { Fail-Usage $m }
    Fail-Usage ("the gate could not run - {0}" -f $m)
}

# ---------------------------------------------------------------------------
# 2. The pack: files enumerated, grouped into logical documents
# ---------------------------------------------------------------------------

$extSet = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($e in @($DocumentExtension)) { if ($e) { [void]$extSet.Add(("$e").ToLowerInvariant()) } }

$gciArgs = @{ LiteralPath = $packPath; File = $true; ErrorAction = 'SilentlyContinue' }
if ($Recurse) { $gciArgs['Recurse'] = $true }
$packFiles = @(Get-ChildItem @gciArgs | Where-Object {
    $extSet.Contains($_.Extension.ToLowerInvariant()) -and
    -not $_.FullName.StartsWith($corpusPath, [System.StringComparison]::OrdinalIgnoreCase)
})

if ($packFiles.Count -eq 0) {
    $hint = ''
    $subs = @(Get-ChildItem -LiteralPath $packPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $n = @(Get-ChildItem -LiteralPath $_.FullName -File -ErrorAction SilentlyContinue | Where-Object { $extSet.Contains($_.Extension.ToLowerInvariant()) }).Count
        if ($n -gt 0) { '    {0}  ({1} document file(s))' -f $_.Name, $n }
    } | Where-Object { $_ })
    if ($subs.Count -gt 0) { $hint = "`n  Subdirectories that DO hold documents:`n" + ($subs -join "`n") + "`n  Point -PackDir at the one that holds the assessment pack, or pass -Recurse if every one of them is pack." }
    Fail-Usage ("no document files under {0} ({1}), searching {2}.{3}" -f $packPath, $packFrom, $(if ($Recurse) { 'recursively' } else { 'that directory only' }), $hint)
}

$packDocs = New-Object System.Collections.Generic.List[object]
$byStem = @{}
foreach ($f in ($packFiles | Sort-Object FullName)) {
    $k = Get-StemKey -Name $f.Name
    if (-not $byStem.ContainsKey($k)) {
        $byStem[$k] = [pscustomobject]@{
            Key        = $k
            Name       = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
            Renditions = (New-Object System.Collections.Generic.List[object])
        }
        $packDocs.Add($byStem[$k])
    }
    $byStem[$k].Renditions.Add($f)
}

#  A manifest, where the pack or the contract carries one, is the authority on
#  what the pack CONTAINS; the enumeration is then reconciled against it rather
#  than trusted as the list. Without one the enumeration is the list, and the
#  gate says so, because a reader must know which claim was checked.
$manifestFrom = 'no manifest - the enumeration of the pack directory is the document list'
$manifestNames = $null
#  Candidates, in order: a manifest in the pack directory, then the CORPUS
#  manifest Stage 1's extractor writes beside the extracts (corpus\manifest.json
#  - file, source, audience, sha256 of the source rendition, chars), then the
#  contract's corpus block. The corpus manifest is the one that records
#  hashes; on the reference build it is the only one that exists.
$manifestCandidates = New-Object System.Collections.Generic.List[string]
if ($ManifestPath) { $manifestCandidates.Add($ManifestPath) }
else {
    foreach ($cand in @('pack-manifest.json', 'manifest.json')) {
        $p = Join-Path $packPath $cand
        if (Test-Path -LiteralPath $p) { $manifestCandidates.Add($p) }
    }
    $cm = Join-Path $corpusPath 'manifest.json'
    if (Test-Path -LiteralPath $cm) { $manifestCandidates.Add($cm) }
}
$manifest = $null
#  Hash records are gathered from EVERY manifest found, keyed by document stem,
#  whichever one supplies the document list.
$hashRecords = @{}
$hashFrom = New-Object System.Collections.Generic.List[string]
foreach ($mp in $manifestCandidates) {
    if (-not (Test-Path -LiteralPath $mp)) { continue }
    $mj = Get-GateJson -Path $mp
    if ($null -eq $mj) { continue }
    if ($null -eq $manifest) {
        $manifest = $mj
        $ManifestPath = $mp
        $manifestFrom = ('{0} manifest {1}' -f $(if ($mp.StartsWith($corpusPath, [System.StringComparison]::OrdinalIgnoreCase)) { 'corpus' } else { 'pack' }), (Split-Path $mp -Leaf))
    }
    $label = ('{0}\{1}' -f (Split-Path (Split-Path $mp -Parent) -Leaf), (Split-Path $mp -Leaf))
    foreach ($d in @(Get-GateProp -Object $mj -Names @('documents', 'files') -Default @())) {
        if ($null -eq $d -or $d -is [string]) { continue }
        $nm = [string](Get-GateProp -Object $d -Names @('file', 'name', 'document') -Default '')
        if (-not $nm) { continue }
        $k = Get-StemKey -Name $nm
        if ($hashRecords.ContainsKey($k)) { continue }
        $hashRecords[$k] = [pscustomobject]@{
            SourceName    = [string](Get-GateProp -Object $d -Names @('source', 'sourceFile', 'from') -Default '')
            Sha256        = ([string](Get-GateProp -Object $d -Names @('sha256', 'sourceSha256', 'hash') -Default '')).Trim().ToLowerInvariant()
            ExtractSha256 = ([string](Get-GateProp -Object $d -Names @('extractSha256', 'textSha256', 'corpusSha256') -Default '')).Trim().ToLowerInvariant()
            From          = $label
        }
        if (-not $hashFrom.Contains($label)) { $hashFrom.Add($label) }
    }
}
if ($null -eq $manifest -and $null -ne $contract) {
    $cnode = Get-GateProp -Object $contract -Names @('corpus')
    if ($null -ne $cnode -and $null -ne (Get-GateProp -Object $cnode -Names @('documents'))) {
        $manifest = $cnode
        $manifestFrom = 'contract corpus.documents'
    }
}
$manifestDocs = @{}
if ($null -ne $manifest) {
    foreach ($d in @(Get-GateProp -Object $manifest -Names @('documents', 'files') -Default @())) {
        if ($null -eq $d) { continue }
        $nm = [string](Get-GateProp -Object $d -Names @('file', 'name', 'document') -Default '')
        if (-not $nm) { if ($d -is [string]) { $nm = [string]$d } }
        if (-not $nm) { continue }
        $manifestDocs[(Get-StemKey -Name $nm)] = $d
    }
    if ($manifestDocs.Count -eq 0) { $manifestFrom += ' (it lists no documents; the enumeration stands)' ; $manifest = $null }
}

# --- the signature of every pack document
foreach ($d in $packDocs) {
    $prim = $null
    foreach ($r in $d.Renditions) {
        if (Get-OpenXmlParts -Extension $r.Extension) { $prim = $r; break }
    }
    if ($null -eq $prim) { $prim = @($d.Renditions | Sort-Object Length -Descending)[0] }
    $lines = Get-PackDocumentText -Path $prim.FullName
    $sigFrom = 'the pack document body'
    if ($null -eq $lines -and $null -ne $manifest -and $manifestDocs.ContainsKey($d.Key)) {
        #  A pack that ships only formats this reader cannot open may record the
        #  signature in its manifest. Recorded is weaker than measured, and the
        #  report says which was used.
        $md = $manifestDocs[$d.Key]
        $mc = Get-GateProp -Object $md -Names @('chars', 'characters')
        if ($null -ne $mc) {
            $lines = @()
            $d | Add-Member -NotePropertyName ManifestChars -NotePropertyValue ([int]$mc) -Force
            $sigFrom = 'the manifest''s recorded signature'
        }
    }
    $norm = Get-NormalLines -Lines $lines
    $chars = 0
    if ($null -ne $lines -and $lines.Count -gt 0) { $chars = (($lines -join "`n")).Length }
    if ($d.PSObject.Properties.Name -contains 'ManifestChars') { $chars = [int]$d.ManifestChars }
    $d | Add-Member -NotePropertyName Primary     -NotePropertyValue $prim -Force
    $d | Add-Member -NotePropertyName Extractable -NotePropertyValue ($null -ne $lines -and $norm.Count -gt 0) -Force
    $d | Add-Member -NotePropertyName SigFrom     -NotePropertyValue $sigFrom -Force
    $d | Add-Member -NotePropertyName Paragraphs  -NotePropertyValue $(if ($null -eq $lines) { 0 } else { $lines.Count }) -Force
    $d | Add-Member -NotePropertyName Chars       -NotePropertyValue $chars -Force
    $d | Add-Member -NotePropertyName FirstLine   -NotePropertyValue $(if ($null -ne $lines -and $lines.Count -gt 0) { $lines[0] } else { '' }) -Force
    $d | Add-Member -NotePropertyName LastLine    -NotePropertyValue $(if ($null -ne $lines -and $lines.Count -gt 0) { $lines[$lines.Count - 1] } else { '' }) -Force
    $d | Add-Member -NotePropertyName Normal      -NotePropertyValue $norm -Force
    $d | Add-Member -NotePropertyName NormalSet   -NotePropertyValue (New-NormalSet -Normal $norm) -Force
    $d | Add-Member -NotePropertyName Head        -NotePropertyValue @($norm | Select-Object -First $edgeWin) -Force
    $d | Add-Member -NotePropertyName Tail        -NotePropertyValue @($norm | Select-Object -Last $edgeWin) -Force
    $d | Add-Member -NotePropertyName Corpus      -NotePropertyValue (New-Object System.Collections.Generic.List[object]) -Force

    #  THE SOURCE HASH. The rendition the manifest names as the source (or the
    #  primary rendition when it names none) is hashed NOW and compared to the
    #  hash the manifest recorded when the extract was cut.
    $hashRec = $null
    if ($hashRecords.ContainsKey($d.Key)) { $hashRec = $hashRecords[$d.Key] }
    $hashRend = $prim
    if ($null -ne $hashRec -and $hashRec.SourceName) {
        foreach ($r in $d.Renditions) { if ($r.Name -ieq $hashRec.SourceName) { $hashRend = $r; break } }
    }
    $measured = Get-FileSha256 -Path $hashRend.FullName
    $recorded = ''
    $recordedExtract = ''
    $recFrom = ''
    if ($null -ne $hashRec) { $recorded = $hashRec.Sha256; $recordedExtract = $hashRec.ExtractSha256; $recFrom = $hashRec.From }
    $d | Add-Member -NotePropertyName HashRendition   -NotePropertyValue $hashRend.Name -Force
    $d | Add-Member -NotePropertyName PackSha256      -NotePropertyValue $measured -Force
    $d | Add-Member -NotePropertyName ManifestSha256  -NotePropertyValue $recorded -Force
    $d | Add-Member -NotePropertyName ManifestExtract -NotePropertyValue $recordedExtract -Force
    $d | Add-Member -NotePropertyName HashFrom        -NotePropertyValue $recFrom -Force
    $d | Add-Member -NotePropertyName HashVerdict     -NotePropertyValue $(if ($recorded) { $(if ($recorded -eq $measured) { 'MATCH' } else { 'MISMATCH' }) } else { 'NOT RECORDED' }) -Force
}

# ---------------------------------------------------------------------------
# 3. The corpus, as the gates downstream will read it
# ---------------------------------------------------------------------------

$corpus = Get-GateCorpusDocs -CorpusDir $corpusPath -BuildDir $BuildDir
$corpusDocs = New-Object System.Collections.Generic.List[object]
foreach ($cd in @($corpus.Documents)) {
    $lines = Get-TextLines -Text $cd.Text
    $norm = Get-NormalLines -Lines $lines
    $corpusDocs.Add([pscustomobject]@{
        Name      = $cd.Name
        Path      = $cd.Path
        Audience  = $cd.Audience
        Sha256    = (Get-FileSha256 -Path $cd.Path)
        Chars     = ("$($cd.Text)").TrimStart([char]0xFEFF).Length
        Lines     = $lines.Count
        FirstLine = $(if ($lines.Count -gt 0) { $lines[0] } else { '' })
        LastLine  = $(if ($lines.Count -gt 0) { $lines[$lines.Count - 1] } else { '' })
        Normal    = $norm
        NormalSet = (New-NormalSet -Normal $norm)
        Pack      = $null
        MatchedBy = ''
    })
}
if ($corpusDocs.Count -eq 0) { Fail-Usage ('the corpus at {0} holds no text files.' -f $corpusPath) }

# ---------------------------------------------------------------------------
# 4. Reconcile - name to name first, then by content
# ---------------------------------------------------------------------------

$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]
$rows = New-Object System.Collections.Generic.List[object]

# --- the source hash, compared. A manifest that recorded NO hash for any pack
#     document is a refusal naming the manifest: the comparison cannot run.
$hashChecked = @($packDocs.ToArray() | Where-Object { $_.ManifestSha256 })
$hashMismatch = New-Object System.Collections.Generic.List[object]
try {
    Write-GateCheckSet -What 'pack document(s) with a recorded source sha256' -Count $hashChecked.Count -DerivedFrom $(if ($hashFrom.Count) { ($hashFrom -join ' + ') + ' documents[].sha256' } else { 'no manifest recorded a hash' }) -Blocking -Input ((Join-Path (Split-Path $corpusPath -Leaf) 'manifest.json') + ' documents[].sha256 (the hash of the source rendition each extract was cut from)')
}
catch { Stop-OnRefusal $_ }
foreach ($p in $hashChecked) {
    if ($p.HashVerdict -eq 'MISMATCH') {
        $hashMismatch.Add($p)
        $failures.Add(('{0}: SOURCE HASH MISMATCH. The pack file {1} hashes to {2} now, and {3} recorded {4} when the corpus was cut. The extract was cut from a different file than the pack holds; re-extract, or restore the file the manifest describes.' -f $p.Name, $p.HashRendition, $p.PackSha256, $p.HashFrom, $p.ManifestSha256))
    }
}
Complete-GateArm -Name 'source-hash' -State $(if ($hashChecked.Count -gt 0) { 'ran' } else { 'empty' }) -Size $hashChecked.Count -Findings $hashMismatch.Count

foreach ($c in $corpusDocs) {
    $k = Get-StemKey -Name $c.Name
    $hit = @($packDocs.ToArray() | Where-Object { $_.Key -eq $k })
    if ($hit.Count -eq 1) {
        $c.Pack = $hit[0]
        $c.MatchedBy = 'name'
        $hit[0].Corpus.Add($c)
        continue
    }
    #  No name match. An extraction renamed on the way in is still an
    #  extraction, so ask the content before calling it a stranger - and an
    #  extraction that matches a pack document already extracted is exactly the
    #  doubled extraction this gate exists to catch.
    $best = $null
    $bestRatio = 0.0
    foreach ($p in $packDocs.ToArray()) {
        if (-not $p.Extractable) { continue }
        $m = Measure-Coverage -Needle $p.Normal -HaySet $c.NormalSet
        if ($m.Ratio -gt $bestRatio) { $bestRatio = $m.Ratio; $best = $p }
    }
    if ($null -ne $best -and $bestRatio -ge $covFloor) {
        $c.Pack = $best
        $c.MatchedBy = ('content, {0:P1} of the pack document''s paragraphs' -f $bestRatio)
        $best.Corpus.Add($c)
    }
    else {
        $c.MatchedBy = ('no match; best content overlap {0:P1}' -f $bestRatio)
    }
}

# --- identical corpus files, whatever they are named
$byHash = @{}
foreach ($c in $corpusDocs) {
    if (-not $byHash.ContainsKey($c.Sha256)) { $byHash[$c.Sha256] = New-Object System.Collections.Generic.List[object] }
    $byHash[$c.Sha256].Add($c)
}
foreach ($h in $byHash.Keys) {
    $grp = $byHash[$h]
    if ($grp.Count -gt 1) {
        $failures.Add(('{0} corpus files are byte-identical (sha256 {1}): {2}. One document extracted twice doubles every count downstream and hides any divergence between the copies.' -f $grp.Count, $h.Substring(0, 12), ((@($grp.ToArray() | ForEach-Object { $_.Name })) -join ', ')))
    }
}

# --- near-identical corpus files under two names, symmetric so a superset
#     (an assessor guide over its learner tool) is not called a duplicate
$arr = $corpusDocs.ToArray()
for ($i = 0; $i -lt $arr.Count; $i++) {
    for ($j = $i + 1; $j -lt $arr.Count; $j++) {
        if ($arr[$i].Sha256 -eq $arr[$j].Sha256) { continue }   # already reported
        $ab = (Measure-Coverage -Needle $arr[$i].Normal -HaySet $arr[$j].NormalSet).Ratio
        $ba = (Measure-Coverage -Needle $arr[$j].Normal -HaySet $arr[$i].NormalSet).Ratio
        $mn = [Math]::Min($ab, $ba)
        if ($mn -ge $dupCov) {
            $failures.Add(('{0} and {1} are the same extraction under two names ({2:P1} of each is in the other, and they are not byte-identical - so they have also DIVERGED). A duplicate doubles every downstream count.' -f $arr[$i].Name, $arr[$j].Name, $mn))
        }
    }
}

# --- per pack document
$unproven = 0
$fidelityPairs = 0
$extractHashChecked = 0
$extractHashMismatch = 0
function New-HashFields {
    <# The hash columns every row carries, so corpus-complete.json records what was compared. #>
    param($P, $C)
    $o = [ordered]@{ packFile = ''; packSha256 = ''; manifestSha256 = ''; hashVerdict = 'NOT RECORDED'; extractSha256 = ''; manifestExtractSha256 = ''; extractHashVerdict = 'NOT RECORDED' }
    if ($null -ne $P) {
        $o['packFile'] = [string]$P.HashRendition; $o['packSha256'] = [string]$P.PackSha256
        $o['manifestSha256'] = [string]$P.ManifestSha256; $o['hashVerdict'] = [string]$P.HashVerdict
        $o['manifestExtractSha256'] = [string]$P.ManifestExtract
    }
    if ($null -ne $C) {
        $o['extractSha256'] = [string]$C.Sha256
        if ($null -ne $P -and $P.ManifestExtract) { $o['extractHashVerdict'] = $(if ($P.ManifestExtract -eq $C.Sha256) { 'MATCH' } else { 'MISMATCH' }) }
    }
    return $o
}
function New-Row {
    param([hashtable] $Base, $P, $C)
    $h = New-HashFields -P $P -C $C
    foreach ($k in $h.Keys) { $Base[$k] = $h[$k] }
    return [pscustomobject]$Base
}
foreach ($p in ($packDocs.ToArray() | Sort-Object Name)) {
    $n = $p.Corpus.Count
    $rend = ((@($p.Renditions.ToArray() | ForEach-Object { $_.Extension })) -join '+')

    if ($n -eq 0) {
        $failures.Add(('{0} is in the pack ({1}) and was NOT extracted into the corpus. No gate downstream of Stage 1 can see one word of it.' -f $p.Name, $rend))
        $rows.Add((New-Row -P $p -C $null -Base @{ pack = $p.Name; renditions = $rend; corpus = ''; packParagraphs = $p.Paragraphs; packChars = $p.Chars; corpusLines = 0; corpusChars = 0; coverage = 0.0; head = 0.0; tail = 0.0; charRatio = 0.0; firstLineExact = $false; lastLineExact = $false; verdict = 'NOT EXTRACTED' }))
        continue
    }
    if ($n -gt 1) {
        $failures.Add(('{0} was extracted twice, as {1}. A duplicate silently doubles every count and hides a divergence between the copies.' -f $p.Name, ((@($p.Corpus.ToArray() | ForEach-Object { $_.Name })) -join ' and ')))
    }

    foreach ($c in $p.Corpus.ToArray()) {
        $fidelityPairs++
        #  THE EXTRACT HASH, where the manifest recorded one. One altered byte
        #  in an extract is below every fidelity threshold and above none of
        #  the gates that read it; only the hash sees it.
        if ($p.ManifestExtract) {
            $extractHashChecked++
            if ($p.ManifestExtract -ne $c.Sha256) {
                $extractHashMismatch++
                $failures.Add(('{0} -> {1}: EXTRACT HASH MISMATCH. The extract hashes to {2} now, and {3} recorded {4} when it was cut. The corpus has been edited since Stage 1 extracted it; re-extract, or account for the edit.' -f $p.Name, $c.Name, $c.Sha256, $p.HashFrom, $p.ManifestExtract))
            }
        }
        if (-not $p.Extractable) {
            $unproven++
            $warnings.Add(('{0}: fidelity UNPROVEN. The pack ships it as {1}, which this gate cannot read for text, and no manifest records its signature. Presence was checked; truncation was not, and cannot be.' -f $p.Name, $rend))
            $rows.Add((New-Row -P $p -C $c -Base @{ pack = $p.Name; renditions = $rend; corpus = $c.Name; packParagraphs = 0; packChars = 0; corpusLines = $c.Lines; corpusChars = $c.Chars; coverage = -1.0; head = -1.0; tail = -1.0; charRatio = -1.0; firstLineExact = $false; lastLineExact = $false; verdict = 'UNPROVEN' }))
            continue
        }

        $cov = (Measure-Coverage -Needle $p.Normal -HaySet $c.NormalSet)
        $head = (Measure-Coverage -Needle $p.Head -HaySet $c.NormalSet)
        $tail = (Measure-Coverage -Needle $p.Tail -HaySet $c.NormalSet)
        $ratio = 0.0
        if ($p.Chars -gt 0) { $ratio = [double]$c.Chars / [double]$p.Chars }
        $firstExact = ((ConvertTo-GateNormal $p.FirstLine) -eq (ConvertTo-GateNormal $c.FirstLine))
        $lastExact  = ((ConvertTo-GateNormal $p.LastLine) -eq (ConvertTo-GateNormal $c.LastLine))

        $bad = New-Object System.Collections.Generic.List[string]
        if ($cov.Ratio -lt $covFloor)  { $bad.Add(('coverage {0:P1} is below the {1:P0} floor - {2} of the pack document''s {3} substantive paragraphs are not in the extract' -f $cov.Ratio, $covFloor, ($cov.Total - $cov.Hit), $cov.Total)) }
        if ($tail.Ratio -lt $edgeMin)  { $bad.Add(('TRUNCATED: only {0} of the pack document''s last {1} substantive paragraphs survived into the extract' -f $tail.Hit, $tail.Total)) }
        if ($head.Ratio -lt $edgeMin)  { $bad.Add(('the extract is missing the opening: only {0} of the pack document''s first {1} substantive paragraphs are in it' -f $head.Hit, $head.Total)) }
        if ($ratio -lt $charLow)       { $bad.Add(('character count {0} is {1:P0} of the pack document''s {2}, below the {3:P0} floor' -f $c.Chars, $ratio, $p.Chars, $charLow)) }
        if ($ratio -gt $charHigh)      { $bad.Add(('character count {0} is {1:P0} of the pack document''s {2}, above the {3:P0} ceiling - the extract carries text this document does not' -f $c.Chars, $ratio, $p.Chars, $charHigh)) }

        $verdict = 'OK'
        if ($bad.Count -gt 0) {
            $verdict = 'FIDELITY'
            foreach ($b in $bad.ToArray()) { $failures.Add(('{0} -> {1}: {2}' -f $p.Name, $c.Name, $b)) }
        }
        if ($n -gt 1) { $verdict = 'DOUBLED' }
        if ($p.HashVerdict -eq 'MISMATCH' -or ($p.ManifestExtract -and $p.ManifestExtract -ne $c.Sha256)) { $verdict = 'HASH MISMATCH' }

        $rows.Add((New-Row -P $p -C $c -Base @{
            pack = $p.Name; renditions = $rend; corpus = $c.Name
            packParagraphs = $p.Paragraphs; packChars = $p.Chars
            corpusLines = $c.Lines; corpusChars = $c.Chars
            coverage = [Math]::Round($cov.Ratio, 4); head = [Math]::Round($head.Ratio, 4); tail = [Math]::Round($tail.Ratio, 4)
            charRatio = [Math]::Round($ratio, 4)
            firstLineExact = $firstExact; lastLineExact = $lastExact
            verdict = $verdict
        }))
    }
}
Complete-GateArm -Name 'fidelity' -State $(if ($fidelityPairs -gt 0) { 'ran' } else { 'empty' }) -Size $fidelityPairs -Findings @($rows | Where-Object { $_.verdict -eq 'FIDELITY' }).Count
Complete-GateArm -Name 'extract-hash' -State $(if ($extractHashChecked -gt 0) { 'ran' } else { 'empty' }) -Size $extractHashChecked -Findings $extractHashMismatch

# --- corpus files with no pack ancestor
foreach ($c in $corpusDocs) {
    if ($null -ne $c.Pack) { continue }
    $failures.Add(('{0} is in the corpus and has no pack ancestor - UNKNOWN PROVENANCE ({1}). Everything downstream treats the corpus as the pack; a file that is not from the pack would be adjudicated as if the pack had said it.' -f $c.Name, $c.MatchedBy))
    $rows.Add((New-Row -P $null -C $c -Base @{ pack = ''; renditions = ''; corpus = $c.Name; packParagraphs = 0; packChars = 0; corpusLines = $c.Lines; corpusChars = $c.Chars; coverage = 0.0; head = 0.0; tail = 0.0; charRatio = 0.0; firstLineExact = $false; lastLineExact = $false; verdict = 'UNKNOWN PROVENANCE' }))
}

# --- a manifest disagreeing with the directory
$manifestMissing = New-Object System.Collections.Generic.List[string]
if ($null -ne $manifest -and $manifestDocs.Count -gt 0) {
    foreach ($k in $manifestDocs.Keys) {
        $onDisk = @($packDocs.ToArray() | Where-Object { $_.Key -eq $k })
        if ($onDisk.Count -eq 0) {
            $nm = [string](Get-GateProp -Object $manifestDocs[$k] -Names @('file', 'name', 'document') -Default $k)
            $manifestMissing.Add($nm)
            $failures.Add(('{0} is listed in {1} and is not in the pack directory. The manifest and the pack disagree about what the pack is.' -f $nm, $manifestFrom))
        }
    }
    foreach ($p in $packDocs.ToArray()) {
        if (-not $manifestDocs.ContainsKey($p.Key)) {
            $warnings.Add(('{0} is in the pack directory and is not listed in {1}.' -f $p.Name, $manifestFrom))
        }
    }
}

# --- a second extraction elsewhere in the build. This mirrors the locator
#     order in Lib-GateCommon: those are the places a build has actually put
#     an extraction, and two of them holding two different extractions of one
#     pack is the failure section 20 records.
$rivals = New-Object System.Collections.Generic.List[object]
if ($BuildDir) {
    foreach ($alt in @('corpus', 'cleanroom\pack', 'packtext')) {
        $ap = Join-Path $BuildDir $alt
        if (-not (Test-Path -LiteralPath $ap)) { continue }
        if ((Resolve-Path -LiteralPath $ap).Path -eq $corpusPath) { continue }
        $txt = @(Get-ChildItem -LiteralPath $ap -Filter '*.txt' -File -ErrorAction SilentlyContinue)
        if ($txt.Count -eq 0) { continue }
        $matched = New-Object System.Collections.Generic.List[string]
        foreach ($t in $txt) {
            $tn = New-NormalSet -Normal (Get-NormalLines -Lines (Get-TextLines -Text (Get-GateFileText -Path $t.FullName)))
            foreach ($p in $packDocs.ToArray()) {
                if (-not $p.Extractable) { continue }
                if ((Measure-Coverage -Needle $p.Normal -HaySet $tn).Ratio -ge $covFloor) { $matched.Add(('{0} <- {1}' -f $t.Name, $p.Name)); break }
            }
        }
        if ($matched.Count -gt 0) {
            $rivals.Add([pscustomobject]@{ dir = (Resolve-Path -LiteralPath $ap).Path; files = $matched.ToArray() })
            $warnings.Add(('a SECOND extraction of {0} pack document(s) sits in {1}, outside the canonical corpus: {2}. Every gate reads the canonical corpus only; a copy that drifts from it is a defect nobody will see.' -f $matched.Count, $ap, ($matched.ToArray() -join '; ')))
        }
    }
}

# ---------------------------------------------------------------------------
# 5. Report
# ---------------------------------------------------------------------------

Complete-GateArm -Name 'pack-documents' -State $(if ($packDocs.Count -gt 0) { 'ran' } else { 'empty' }) -Size $packDocs.Count -Findings @($rows | Where-Object { $_.verdict -eq 'NOT EXTRACTED' -or $_.verdict -eq 'DOUBLED' }).Count
Complete-GateArm -Name 'corpus-extracts' -State $(if ($corpusDocs.Count -gt 0) { 'ran' } else { 'empty' }) -Size $corpusDocs.Count -Findings @($rows | Where-Object { $_.verdict -eq 'UNKNOWN PROVENANCE' }).Count
$roster = @()
try {
    Assert-GateArmsComplete
    $roster = @(Write-GateArmRoster)
}
catch { Stop-OnRefusal $_ }

$exitCode = 0
if ($failures.Count -gt 0) { $exitCode = 1 }
elseif ($unproven -gt 0)   { $exitCode = 5 }
$verdictText = 'PASS'
if ($exitCode -eq 1) { $verdictText = 'FAIL' }
elseif ($exitCode -eq 5) { $verdictText = 'UNPROVEN' }

if (-not $Quiet) {
    Write-Host ''
    Write-Host 'CORPUS COMPLETENESS - every pack document extracted exactly once, and faithfully' -ForegroundColor Cyan
    Write-Host ("  pack   : {0}  ({1}, {2})" -f $packPath, $packFrom, $(if ($Recurse) { 'recursive' } else { 'that directory only' })) -ForegroundColor DarkGray
    Write-Host ("  corpus : {0}  (classified from {1})" -f $corpusPath, $corpus.ClassifiedFrom) -ForegroundColor DarkGray
    Write-GateCheckSet -What 'pack documents' -Count $packDocs.Count -DerivedFrom $manifestFrom
    Write-GateCheckSet -What 'corpus extracts' -Count $corpusDocs.Count -DerivedFrom 'Lib-GateCommon Get-GateCorpusDocs'
    Write-Host ("  thresholds: coverage {0:P0} ({1}); characters {2:P0}-{3:P0} ({4}); edge window {5} at {6:P0} ({7}); duplicate {8:P0}" -f $covFloor, $rCov.From, $charLow, $charHigh, $rLow.From, $edgeWin, $edgeMin, $rEdge.From, $dupCov) -ForegroundColor DarkGray
    Write-Host ''
    Write-Host ("  source hash: {0} of {1} pack document(s) carry a recorded sha256 ({2}); {3} mismatch. extract hash: {4} recorded, {5} mismatch." -f $hashChecked.Count, $packDocs.Count, $(if ($hashFrom.Count) { $hashFrom -join ' + ' } else { 'none' }), $hashMismatch.Count, $extractHashChecked, $extractHashMismatch) -ForegroundColor $(if ($hashMismatch.Count -or $extractHashMismatch) { 'Red' } else { 'DarkGray' })
    Write-Host ("  {0,-42} {1,-42} {2,6} {3,6} {4,6} {5,6} {6,6}  verdict" -f 'pack document', 'corpus extract', 'paras', 'lines', 'cov', 'tail', 'chars') -ForegroundColor DarkGray
    foreach ($r in $rows.ToArray()) {
        $col = 'Green'
        if ($r.verdict -ne 'OK') { $col = 'Red' }
        if ($r.verdict -eq 'UNPROVEN') { $col = 'Yellow' }
        $fmt = '{0,-42} {1,-42} {2,6} {3,6} {4,6} {5,6} {6,6}  {7}'
        $cv = '  n/a'
        $tl = '  n/a'
        $ch = '  n/a'
        if ($r.coverage -ge 0) { $cv = ('{0,5:P0}' -f $r.coverage) }
        if ($r.tail -ge 0)     { $tl = ('{0,5:P0}' -f $r.tail) }
        if ($r.charRatio -ge 0){ $ch = ('{0,5:P0}' -f $r.charRatio) }
        Write-Host ('  ' + ($fmt -f $r.pack, $r.corpus, $r.packParagraphs, $r.corpusLines, $cv, $tl, $ch, $r.verdict)) -ForegroundColor $col
    }

    Write-Host ''
    Write-Host '  signature, per extraction (an assessor-only extract''s lines are withheld - a marking guide''s last line can be a model answer):' -ForegroundColor DarkGray
    foreach ($c in $corpusDocs) {
        $tag = 'no pack ancestor'
        if ($null -ne $c.Pack) { $tag = ('from {0} by {1}' -f $c.Pack.Name, $c.MatchedBy) }
        Write-Host ("    {0} [{1}]  {2} line(s), {3} chars, sha256 {4}  ({5})" -f $c.Name, $c.Audience, $c.Lines, $c.Chars, $c.Sha256.Substring(0, 12), $tag) -ForegroundColor DarkGray
        Write-Host ("      first: {0}" -f (Show-Edge -Text $c.FirstLine -Audience $c.Audience)) -ForegroundColor DarkGray
        Write-Host ("      last : {0}" -f (Show-Edge -Text $c.LastLine -Audience $c.Audience)) -ForegroundColor DarkGray
    }

    if ($warnings.Count -gt 0) {
        Write-Host ''
        foreach ($w in $warnings.ToArray()) { Write-Host ("  ! {0}" -f $w) -ForegroundColor Yellow }
    }
    if ($failures.Count -gt 0) {
        Write-Host ''
        foreach ($f in $failures.ToArray()) { Write-Host ("  X {0}" -f $f) -ForegroundColor Red }
    }

    Write-Host ''
    if ($exitCode -eq 0) {
        Write-Host ("  {0} pack document(s), {1} extract(s), one each, every signature within tolerance." -f $packDocs.Count, $corpusDocs.Count) -ForegroundColor Green
    }
    elseif ($exitCode -eq 5) {
        Write-Host ("  X the corpus is COMPLETE but {0} extraction(s) could not be proved faithful. Presence is not fidelity: an extraction that kept its header and lost its body would pass a count and let every later gate report clean." -f $unproven) -ForegroundColor Yellow
    }
    else {
        Write-Host ("  X {0} corpus completeness failure(s). Authoring must not open on this corpus." -f $failures.Count) -ForegroundColor Red
    }
}

$body = [ordered]@{}
$body['gate']            = $GATE
$body['mode']            = 'reconcile'
$body['verdict']         = $verdictText
$body['packDir']         = $packPath
$body['packDirFrom']     = $packFrom
$body['corpusDir']       = $corpusPath
$body['corpusClassifiedFrom'] = $corpus.ClassifiedFrom
$body['documentList']    = $manifestFrom
$body['recursive']       = [bool]$Recurse
$body['packDocuments']   = $packDocs.Count
$body['corpusExtracts']  = $corpusDocs.Count
$body['thresholds']      = [ordered]@{ coverageFloor = $covFloor; coverageFrom = $rCov.From; charRatioLow = $charLow; charRatioHigh = $charHigh; edgeWindow = $edgeWin; edgeFloor = $edgeMin; duplicateCoverage = $dupCov }
$body['documents']       = $rows.ToArray()
$body['sourceHash']      = [ordered]@{ recordedFrom = @($hashFrom); checked = $hashChecked.Count; mismatches = @($hashMismatch | ForEach-Object { [ordered]@{ pack = $_.Name; file = $_.HashRendition; measured = $_.PackSha256; recorded = $_.ManifestSha256; recordedIn = $_.HashFrom } }) }
$body['extractHash']     = [ordered]@{ checked = $extractHashChecked; mismatches = $extractHashMismatch; note = 'every extract sha256 is in documents[].extractSha256; a manifest extractSha256 is compared where recorded' }
$body['arms']            = @($roster)
$body['manifestMissing'] = $manifestMissing.ToArray()
$body['rivalExtractions']= $rivals.ToArray()
$body['failures']        = $failures.ToArray()
$body['warnings']        = $warnings.ToArray()
$body['unprovenFidelity']= $unproven
$body['checkedAt']       = (Get-Date).ToUniversalTime().ToString('o')
$body['exitCode']        = [int]$exitCode
Write-Result -Path $ResultPath -Body $body
if (-not $Quiet -and $ResultPath) { Write-Host ("  reconciliation written to {0}" -f $ResultPath) -ForegroundColor DarkGray }

exit $exitCode
