<#
    Build-FromTemplate.ps1
    Meridian Vocational College / Adelaide Culinary Institute assessment builder.

    Unpack an approved .docx template, edit its XML, repack it.

    DESIGN RULE - read this before changing anything in here.

    Every EDIT in this file is a raw-string operation on the XML text. Nothing is
    edited through a namespace-aware parser. That is deliberate: a namespace-aware
    parser silently drops the xmlns declarations for prefixes that appear only in
    mc:Ignorable (w15, wp14, w16se and others). The file still parses afterwards,
    and Word still refuses to open it. Editing as text cannot lose a declaration
    that it never resolved in the first place.

    XML parsing is used in ONE place only - Test-DocxPackage - and there it runs
    over a throwaway copy, purely to confirm every part is well formed. It never
    writes.

    Companion: Verify-Document.ps1 carries the Word COM verification layer
    (field update, PDF export, page-flow inspection). Nothing in this file
    needs Word to be installed.
#>

# No Set-StrictMode here. This file is dot-sourced, so a strict mode set at its
# top leaks into the caller's whole session and turns unrelated unset variables
# into terminating errors.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$script:SkillRoot = Split-Path -Parent $PSScriptRoot
$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# ---------------------------------------------------------------------------
# Branding
# ---------------------------------------------------------------------------

$script:BrandingCache = @{}

function Get-Branding {
    <#  Load a branding profile. MVC is the default.
        ALWAYS reads as explicit UTF-8. Windows PowerShell 5.1 reads a UTF-8 file
        without a BOM as ANSI, which turns the tagline's middot into mojibake and
        corrupts every non-ASCII character in the profile.

        CACHED, keyed on the file's write time, because a build calls this per
        document and per palette lookup - an edit to the profile mid-session
        invalidates the cache by itself. #>
    [CmdletBinding()]
    param(
        [ValidateSet('MVC', 'ACI')]
        [string] $Brand = 'MVC'
    )

    $path = Join-Path $script:SkillRoot "assets\branding.$($Brand.ToLower()).json"
    if (-not (Test-Path $path)) { throw "Branding profile not found: $path" }
    $stamp = (Get-Item -LiteralPath $path).LastWriteTimeUtc.Ticks
    $hit   = $script:BrandingCache[$Brand]
    if ($hit -and $hit.Stamp -eq $stamp) { return $hit.Value }

    $json = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    $b    = $json | ConvertFrom-Json

    if ($b.brand -ne $Brand) {
        throw "Profile at $path declares brand '$($b.brand)' but was requested as '$Brand'. Refusing to build with a mismatched profile."
    }

    # A profile that loads but cannot build is worse than one that refuses,
    # because the failure surfaces somewhere unrelated - Get-TemplatePath throws
    # about a missing template, or Set-DocControl computes a review date zero
    # months out. Say plainly what is missing and what to do about it.
    $missing = @()
    if (-not $b.templates)                  { $missing += 'templates (which .docx to build from)' }
    if (-not $b.docControl)                 { $missing += 'docControl (footer fields and review interval)' }
    if ($null -eq $b.policy.resultsWithinDays) { $missing += 'policy (cover-sheet day counts and labels)' }
    $houseProfile = Join-Path $script:SkillRoot "assets\house-profile.$($Brand.ToLower()).json"
    if (-not (Test-Path $houseProfile))     { $missing += "assets\house-profile.$($Brand.ToLower()).json (the measured house profile)" }
    # A HALF-SWAP IS THE WORST OUTCOME: recoloured and re-identified but still
    # carrying the source template's mark, it looks branded and is not - and
    # the logo gate's fallback branch structurally cannot catch the source
    # mark, because those bytes can never live in assets/logos. Refuse the
    # configuration outright. (Adversarial review of the logo gate, 29 Aug 2026.)
    if ($b.templates -and $b.templates.PSObject.Properties.Name -contains 'swapPalette' -and $b.templates.swapPalette) {
        if (-not ($b.templates.PSObject.Properties.Name -contains 'swapLogo' -and $b.templates.swapLogo)) {
            $missing += 'templates.swapLogo (swapPalette without swapLogo ships a recoloured document carrying the source template mark)'
        }
    }

    if ($missing.Count -gt 0) {
        throw ("Brand '$Brand' is not set up and cannot build. Stage 0 has not been run for this RTO.`n" +
               "Missing:`n  - " + ($missing -join "`n  - ") + "`n" +
               "Measure that RTO's own approved assessment documents first - see references/house-standard.md. " +
               "Do not fill these in from another RTO's profile.")
    }
    $b | Add-Member -NotePropertyName '_sourcePath' -NotePropertyValue $path -Force
    $script:BrandingCache[$Brand] = @{ Stamp = $stamp; Value = $b }
    return $b
}

function Get-TemplatePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Branding,
        [Parameter(Mandatory)][ValidateSet('uat', 'recipeWorkbook')] [string] $Kind
    )
    $rel = $Branding.templates.$Kind
    if (-not $rel) { throw "Branding profile '$($Branding.brand)' defines no template for kind '$Kind'." }
    $full = Join-Path $script:SkillRoot $rel
    if (-not (Test-Path $full)) { throw "Template missing: $full" }
    return $full
}

function Resolve-BrandVariant {
    <#  THE TRADING NAME FOLLOWS THE UNIT'S TRAINING PACKAGE, IN CODE.

        SKILL.md has always said it - SIT is Adelaide Culinary Institute, CPC is
        Adelaide Construction Institute, never guess - but until 29 August 2026
        the mapping lived only in prose: -Variant was a free string, an omitted
        one fell back to variants.default, and the logo gate then CERTIFIED the
        wrong mark as correct, because it can only check the variant it is told.
        Adversarial review called it the realistic bypass it is. Now:

        - The variant is DERIVED from the unit code's training-package prefix
          against each variant's declared trainingPackages.
        - A passed -Variant that CONTRADICTS the unit's package throws.
        - A unit whose package maps to no variant (BSB) throws unless -Variant
          is passed explicitly: that is a decision, never a default.

        Returns $null for a brand without variants.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Branding,
        [string] $UnitCode,
        [string] $Variant
    )

    if (-not ($Branding.PSObject.Properties.Name -contains 'variants' -and $Branding.variants)) { return $null }

    $pkg = $null
    if ($UnitCode -and $UnitCode -match '^([A-Za-z]{3})') { $pkg = $Matches[1].ToUpper() }

    $derived = $null
    foreach ($vn in $Branding.variants.PSObject.Properties.Name) {
        if ($vn -eq 'default' -or $vn -like '_*') { continue }
        $v = $Branding.variants.$vn
        $packs = @()
        if ($v.PSObject.Properties.Name -contains 'trainingPackages') { $packs = @($v.trainingPackages) }
        if ($pkg -and $packs -contains $pkg) { $derived = $vn; break }
    }

    if ($Variant) {
        if ($derived -and $Variant -ne $derived) {
            throw ("Unit $UnitCode is a $pkg unit, which maps to variant '$derived' of brand '$($Branding.brand)', " +
                   "but -Variant '$Variant' was passed. The trading name follows the unit's training package - " +
                   "refusing to put the $Variant mark on a $pkg document.")
        }
        return $Variant
    }
    if ($derived) { return $derived }

    throw ("Unit '$UnitCode' ($pkg) maps to no variant of brand '$($Branding.brand)'. " +
           "Pass -Variant explicitly - a $pkg unit takes the variant of the qualification it is built for, " +
           "and that is a decision, never a default. Never guess a trading name.")
}

# ---------------------------------------------------------------------------
# Unpack / repack
# ---------------------------------------------------------------------------

function Expand-Docx {
    <#  Unpack a .docx into a working directory and return that directory.
        Entry order is recorded so Compress-Docx can rebuild the package in the
        same order the template used. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [string] $Destination
    )

    if (-not (Test-Path $Path)) { throw "Not found: $Path" }
    if (-not $Destination) {
        $Destination = Join-Path ([System.IO.Path]::GetTempPath()) ("docx_" + [System.Guid]::NewGuid().ToString('N').Substring(0, 12))
    }
    if (Test-Path $Destination) { Remove-Item $Destination -Recurse -Force }
    # -WhatIf:$false on the temp working directory only. Unpacking to a scratch
    # folder is how a -WhatIf run READS the package to report what it would
    # change; without this, a caller run with -WhatIf skips the mkdir and
    # ExtractToFile fails with DirectoryNotFoundException. Writes back to the
    # real template stay guarded by the caller's own ShouldProcess.
    New-Item -ItemType Directory -Path $Destination -Force -WhatIf:$false | Out-Null

    # A document open in Word holds a read lock. Copy it aside and read the copy,
    # so verifying a pack the user happens to have open does not fail with an
    # IOException that reads like corruption.
    $readFrom = $Path
    $shadow   = $null
    try { [System.IO.File]::OpenRead($Path).Dispose() }
    catch {
        $shadow   = Join-Path ([System.IO.Path]::GetTempPath()) ("locked_" + [System.Guid]::NewGuid().ToString('N').Substring(0, 8) + '.docx')
        Copy-Item -LiteralPath $Path -Destination $shadow -Force
        $readFrom = $shadow
        Write-Verbose "Source locked (open in Word?) - reading a shadow copy."
    }

    $order = New-Object System.Collections.Generic.List[string]
    $zip   = [System.IO.Compression.ZipFile]::OpenRead($readFrom)
    try {
        foreach ($entry in $zip.Entries) {
            if ([string]::IsNullOrEmpty($entry.Name)) { continue }   # directory entry
            $order.Add($entry.FullName)
            $target = Join-Path $Destination ($entry.FullName -replace '/', '\')
            $dir    = Split-Path -Parent $target
            if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force -WhatIf:$false | Out-Null }
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
        }
    }
    finally {
        $zip.Dispose()
        if ($shadow -and (Test-Path -LiteralPath $shadow)) { Remove-Item -LiteralPath $shadow -Force -ErrorAction SilentlyContinue }
    }

    [System.IO.File]::WriteAllLines((Join-Path $Destination '.entryorder'), $order, $script:Utf8NoBom)
    Write-Verbose "Unpacked $([System.IO.Path]::GetFileName($Path)) -> $Destination ($($order.Count) parts)"
    return $Destination
}

function Compress-Docx {
    <#  Repack a working directory into a .docx.
        [Content_Types].xml goes first, then every other part in the template's
        original order, then anything new. Word tolerates other orders, but
        matching the template keeps binary diffs against it readable. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $WorkDir,
        [Parameter(Mandatory)][string] $Path
    )

    $orderFile = Join-Path $WorkDir '.entryorder'
    $order     = @()
    if (Test-Path -LiteralPath $orderFile) { $order = [System.IO.File]::ReadAllLines($orderFile, [System.Text.Encoding]::UTF8) }

    $all = Get-ChildItem -Path $WorkDir -Recurse -File |
           Where-Object { $_.Name -ne '.entryorder' } |
           ForEach-Object { $_.FullName.Substring($WorkDir.Length).TrimStart('\') -replace '\\', '/' }

    $seq  = New-Object System.Collections.Generic.List[string]
    $have = New-Object 'System.Collections.Generic.HashSet[string]'
    $inPkg = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($e in $all) { [void]$inPkg.Add($e) }
    if ($inPkg.Contains('[Content_Types].xml')) { $seq.Add('[Content_Types].xml'); [void]$have.Add('[Content_Types].xml') }
    foreach ($e in $order) { if ($inPkg.Contains($e) -and $have.Add($e)) { $seq.Add($e) } }
    foreach ($e in $all)   { if ($have.Add($e))                          { $seq.Add($e) } }

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Force }

    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::CreateNew)
    try {
        $zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($rel in $seq) {
                $src   = Join-Path $WorkDir ($rel -replace '/', '\')
                $entry = $zip.CreateEntry($rel, [System.IO.Compression.CompressionLevel]::Optimal)
                $out   = $entry.Open()
                try {
                    $bytes = [System.IO.File]::ReadAllBytes($src)
                    $out.Write($bytes, 0, $bytes.Length)
                }
                finally { $out.Dispose() }
            }
        }
        finally { $zip.Dispose() }
    }
    finally { $fs.Dispose() }

    Write-Verbose "Packed $($seq.Count) parts -> $Path"
    return $Path
}

# ---------------------------------------------------------------------------
# Part access - always UTF-8, no BOM, no parser
# ---------------------------------------------------------------------------

function Get-DocxPart {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $WorkDir,
        [Parameter(Mandatory)][string] $Part      # e.g. 'word/document.xml'
    )
    $p = Join-Path $WorkDir ($Part -replace '/', '\')
    if (-not (Test-Path -LiteralPath $p)) { throw "Part not present in package: $Part" }
    return [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
}

function Set-DocxPart {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $WorkDir,
        [Parameter(Mandatory)][string] $Part,
        [Parameter(Mandatory)][AllowEmptyString()][string] $Content
    )
    $p = Join-Path $WorkDir ($Part -replace '/', '\')
    $d = Split-Path -Parent $p
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $Content, $script:Utf8NoBom)
}

function Get-DocxParts {
    <# Every XML part in the package, as package-relative paths. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $WorkDir)
    Get-ChildItem -Path $WorkDir -Recurse -File -Filter *.xml |
        ForEach-Object { $_.FullName.Substring($WorkDir.Length).TrimStart('\') -replace '\\', '/' }
}

function Get-DocxHeaderFooterParts {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $WorkDir)
    Get-DocxParts -WorkDir $WorkDir | Where-Object { $_ -match '^word/(header|footer)\d+\.xml$' }
}

# ---------------------------------------------------------------------------
# Text editing
# ---------------------------------------------------------------------------

function ConvertTo-XmlText {
    <# Escape a literal string for use inside a <w:t> element. #>
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Text)
    $Text -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'
}

function Invoke-DocxTextReplace {
    <#  Literal find-and-replace inside <w:t> element bodies only.

        Confined to <w:t> bodies on purpose: a bare replace over the whole part
        can corrupt an attribute value, an rsid or a style id that happens to
        contain the same characters.

        -Expected asserts the number of replacements. A patch that silently
        matched nothing is the failure mode this catches - the build carries on
        and the defect surfaces at audit instead.

        Word may split a phrase across several runs, in which case the phrase is
        not present in any single <w:t> and nothing matches. Use
        Test-DocxTextPresent first, and -Expected always.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $WorkDir,
        [Parameter(Mandatory)][string] $Part,
        [Parameter(Mandatory)][string] $Find,
        [Parameter(Mandatory)][AllowEmptyString()][string] $Replace,
        [int] $Expected = -1
    )

    $xml     = Get-DocxPart -WorkDir $WorkDir -Part $Part
    $findX   = ConvertTo-XmlText $Find
    $replX   = ConvertTo-XmlText $Replace
    $count   = 0

    $evaluator = {
        param($m)
        $body = $m.Groups['body'].Value
        if ($body.Contains($findX)) {
            $script:__replCount += ([regex]::Matches($body, [regex]::Escape($findX))).Count
            $body = $body.Replace($findX, $replX)
        }
        $m.Groups['open'].Value + $body + '</w:t>'
    }

    $script:__replCount = 0
    $out   = [regex]::Replace($xml, '(?<open><w:t(?:\s[^>]*)?>)(?<body>[^<]*)</w:t>', $evaluator)
    $count = $script:__replCount
    Remove-Variable -Name __replCount -Scope Script -ErrorAction SilentlyContinue

    if ($Expected -ge 0 -and $count -ne $Expected) {
        throw "Replace in $Part expected $Expected match(es) for '$Find' but made $count. The template may have changed, or Word split the phrase across runs."
    }
    if ($count -gt 0) { Set-DocxPart -WorkDir $WorkDir -Part $Part -Content $out }
    Write-Verbose "  replaced $count x '$Find' -> '$Replace' in $Part"
    return $count
}

function Invoke-DocxTextReplaceMany {
    <#  Several literal find-and-replaces inside <w:t> bodies, in ONE pass.

        Same confinement as Invoke-DocxTextReplace - only <w:t> element bodies
        are touched - and the same within-body ordering a sequence of single
        calls would produce, but the part is read once, every <w:t> visited
        once, and the part written at most once. Write-PackDocument replaces
        six placeholders; six sequential calls cost twelve full passes over a
        multi-megabyte part.

        Returns a hashtable of find -> replacement count. No -Expected here:
        the caller checks the counts, or sweeps for leftovers afterwards.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $WorkDir,
        [Parameter(Mandatory)][string] $Part,
        [Parameter(Mandatory)] $Map          # [ordered]@{ find = replace }; order is the application order inside each <w:t>
    )

    $xml   = Get-DocxPart -WorkDir $WorkDir -Part $Part
    $pairs = @()
    $counts = @{}
    foreach ($k in @($Map.Keys)) {
        $pairs += ,@((ConvertTo-XmlText $k), (ConvertTo-XmlText ([string]$Map[$k])), [string]$k)
        $counts[[string]$k] = 0
    }

    $script:__replManyPairs  = $pairs
    $script:__replManyCounts = $counts
    $out = [regex]::Replace($xml, '(?<open><w:t(?:\s[^>]*)?>)(?<body>[^<]*)</w:t>', {
        param($m)
        $body = $m.Groups['body'].Value
        foreach ($p in $script:__replManyPairs) {
            if ($body.Contains($p[0])) {
                $script:__replManyCounts[$p[2]] += ([regex]::Matches($body, [regex]::Escape($p[0]))).Count
                $body = $body.Replace($p[0], $p[1])
            }
        }
        $m.Groups['open'].Value + $body + '</w:t>'
    })
    Remove-Variable -Name __replManyPairs, __replManyCounts -Scope Script -ErrorAction SilentlyContinue

    $total = 0
    foreach ($v in $counts.Values) { $total += $v }
    if ($total -gt 0) { Set-DocxPart -WorkDir $WorkDir -Part $Part -Content $out }
    Write-Verbose "  replaced $total occurrence(s) across $($pairs.Count) find(s) in $Part"
    return $counts
}

function Test-DocxTextPresent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $WorkDir,
        [Parameter(Mandatory)][string] $Part,
        [Parameter(Mandatory)][string] $Text
    )
    $xml = Get-DocxPart -WorkDir $WorkDir -Part $Part
    return ([regex]::Matches($xml, [regex]::Escape((ConvertTo-XmlText $Text)))).Count
}

function Get-DocxText {
    <#  Every <w:t> body in a part, concatenated per paragraph.
        This is the SOURCE text. It is fine for locating a string to patch, and
        it is NOT the rendered text - use Verify-Document.ps1 for the sweeps that
        must run against the render. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $WorkDir,
        [string] $Part = 'word/document.xml'
    )
    $xml   = Get-DocxPart -WorkDir $WorkDir -Part $Part
    $paras = [regex]::Matches($xml, '<w:p(?:\s[^>]*)?>.*?</w:p>', 'Singleline')
    $lines = foreach ($p in $paras) {
        $t = ([regex]::Matches($p.Value, '<w:t(?:\s[^>]*)?>([^<]*)</w:t>') |
              ForEach-Object { $_.Groups[1].Value }) -join ''
        $t -replace '&amp;', '&' -replace '&lt;', '<' -replace '&gt;', '>'
    }
    return $lines
}

function Remove-DocxParagraph {
    <#  Delete whole <w:p> elements whose text contains -Containing.

        Deletes the entire paragraph, not just its runs. A paragraph stripped of
        its runs still prints as an empty line, and an empty spacer in front of a
        keepNext-bound block is exactly what strands a blank page.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $WorkDir,
        [Parameter(Mandatory)][string] $Part,
        [Parameter(Mandatory)][string] $Containing,
        [int] $Expected = -1
    )

    $xml    = Get-DocxPart -WorkDir $WorkDir -Part $Part
    $needle = ConvertTo-XmlText $Containing
    $count  = 0

    # Reset explicitly. The old code relied on Remove-Variable plus implicit-zero
    # on ++, which throws on the SECOND call in a StrictMode session.
    $script:__delCount = 0
    $out = [regex]::Replace($xml, '<w:p(?:\s[^>]*)?>.*?</w:p>', {
        param($m)
        $text = ([regex]::Matches($m.Value, '<w:t(?:\s[^>]*)?>([^<]*)</w:t>') |
                 ForEach-Object { $_.Groups[1].Value }) -join ''
        if ($text.Contains($needle)) { $script:__delCount++; return '' }
        return $m.Value
    }, 'Singleline')

    $count = $script:__delCount
    Remove-Variable -Name __delCount -Scope Script -ErrorAction SilentlyContinue

    if ($Expected -ge 0 -and $count -ne $Expected) {
        throw "Paragraph delete in $Part expected $Expected match(es) for '$Containing' but removed $count."
    }
    if ($count -gt 0) { Set-DocxPart -WorkDir $WorkDir -Part $Part -Content $out }
    Write-Verbose "  removed $count paragraph(s) containing '$Containing' from $Part"
    return $count
}

# Initialise the counters the script-block evaluators above increment.
$script:__replCount = 0
$script:__delCount  = 0

# ---------------------------------------------------------------------------
# Document properties and DOCPROPERTY field caches
# ---------------------------------------------------------------------------

function Set-DocxProperties {
    <#  Set MANY custom document properties AND refresh the cached result of
        every DOCPROPERTY field that displays them - in ONE pass per part.

        Both halves are required. Word shows the CACHED result until the field is
        updated, so writing only docProps/custom.xml produces a file whose footer
        disagrees with its own properties - which is a document-control finding,
        not a cosmetic one. Verify-Document.ps1 runs Update-Fields as well, which
        is belt and braces on the same problem.

        Functionally identical to calling Set-DocxProperty once per name, but
        each part is read once and written at most once instead of once per
        property. Set-DocControl sets 15, and 15 full read/scan/write passes
        over document.xml and a megabyte header per document was the largest
        avoidable I/O cost in the assembler.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $WorkDir,
        [Parameter(Mandatory)] $Map          # [ordered]@{ name = value }; order sets pid allocation for new properties
    )

    $part = 'docProps/custom.xml'
    $xml  = Get-DocxPart -WorkDir $WorkDir -Part $part

    foreach ($name in @($Map.Keys)) {
        $esc = ConvertTo-XmlText ([string]$Map[$name])
        $pattern = '(<property\b[^>]*\bname="' + [regex]::Escape($name) + '"[^>]*>\s*<vt:lpwstr>)([^<]*)(</vt:lpwstr>)'
        if ($xml -match $pattern) {
            $xml = [regex]::Replace($xml, $pattern, { param($m) $m.Groups[1].Value + $esc + $m.Groups[3].Value })
        }
        else {
            $pids = [regex]::Matches($xml, '\bpid="(\d+)"') | ForEach-Object { [int]$_.Groups[1].Value }
            $next = 2
            if ($pids.Count -gt 0) { $next = (($pids | Measure-Object -Maximum).Maximum + 1) }
            $new  = '<property fmtid="{D5CDD505-2E9C-101B-9397-08002B2CF9AE}" pid="' + $next +
                    '" name="' + (ConvertTo-XmlText $name) + '"><vt:lpwstr>' + $esc + '</vt:lpwstr></property>'
            $xml  = $xml -replace '</Properties>', ($new + '</Properties>')
        }
    }
    Set-DocxPart -WorkDir $WorkDir -Part $part -Content $xml

    # Refresh the cached field results in document, headers and footers.
    $targets = @('word/document.xml') + (Get-DocxHeaderFooterParts -WorkDir $WorkDir)
    foreach ($t in $targets) {
        $body = Get-DocxPart -WorkDir $WorkDir -Part $t
        if ($body -notmatch 'DOCPROPERTY') { continue }
        $orig = $body
        foreach ($name in @($Map.Keys)) {
            $esc = ConvertTo-XmlText ([string]$Map[$name])
            # (?![\w]) BOUNDARY after the name. Without it 'cmsRevision' also
            # matches the 'cmsRevisionDate' field's instrText and overwrites the
            # date field's cached result with the revision string.
            $fld = '(<w:instrText[^>]*>[^<]*DOCPROPERTY\s+"?' + [regex]::Escape($name) +
                   '(?![\w])"?[^<]*</w:instrText>)(.*?)(<w:fldChar[^>]*w:fldCharType="end"\s*/>)'
            $body = [regex]::Replace($body, $fld, {
                param($m)
                $mid = [regex]::Replace($m.Groups[2].Value, '(<w:t(?:\s[^>]*)?>)[^<]*(</w:t>)', { param($n) $n.Groups[1].Value + $esc + $n.Groups[2].Value })
                $m.Groups[1].Value + $mid + $m.Groups[3].Value
            }, 'Singleline')
        }
        # Write only what changed - most parts carry no field for most names.
        if ($body -ne $orig) { Set-DocxPart -WorkDir $WorkDir -Part $t -Content $body }
    }
}

function Set-DocxProperty {
    <# One property. Thin wrapper over Set-DocxProperties - same semantics. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $WorkDir,
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][AllowEmptyString()][string] $Value
    )
    Set-DocxProperties -WorkDir $WorkDir -Map ([ordered]@{ $Name = $Value })
}

function Set-DocControl {
    <# Apply the whole document-control block from a branding profile. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $WorkDir,
        [Parameter(Mandatory)] $Branding,
        [Parameter(Mandatory)][string] $DocNumber,
        [Parameter(Mandatory)][string] $DocName,
        [string] $Revision      = '1.0',
        [string] $ApprovedDate,
        [string] $NextReviewDate,
        [string] $CreatedBy
    )

    if (-not $ApprovedDate)   { $ApprovedDate   = (Get-Date).ToString('dd-MM-yyyy') }
    if (-not $NextReviewDate) { $NextReviewDate = (Get-Date).AddMonths([int]$Branding.docControl.reviewIntervalMonths).ToString('dd-MM-yyyy') }
    if (-not $CreatedBy)      { $CreatedBy      = $Branding.docControl.approvedBy }

    $map = [ordered]@{
        cmsDocNumber       = $DocNumber
        cmsDocName         = $DocName
        cmsRevision        = $Revision
        cmsRevisionDate    = $ApprovedDate
        cmsApprovedDate    = $ApprovedDate
        cmsNextReviewDate  = $NextReviewDate
        cmsApprovedBy      = $Branding.docControl.approvedBy
        cmsDocCreatedBy    = $CreatedBy
        cmsDocLocation     = $Branding.docControl.docLocation
        RTOnumber          = $Branding.rto.rtoCode
        CRICOSnumber       = $Branding.rto.cricosCode
        AdminEmail         = $Branding.rto.email
        PhoneNumber        = $Branding.rto.phone
        State              = $Branding.jurisdiction
        AccreditationBody  = $Branding.rto.accreditationBody
    }
    Set-DocxProperties -WorkDir $WorkDir -Map $map
    Write-Verbose "Document control set: Doc #$DocNumber Rev $Revision, next review $NextReviewDate"
}

# ---------------------------------------------------------------------------
# Package validation
# ---------------------------------------------------------------------------

function Set-BrandIdentity {
    <#  Replace the template's RTO identity with the building brand's.

        The cover sheet and title page come across from MVC's approved template
        unchanged, carrying MVC's trading name, legal entity, RTO code, CRICOS
        code, website and ID label. The POLICY WORDING is what the RTO approved
        and is deliberately kept; the IDENTITY FIELDS are what differ per RTO and
        must move, or an ACI pack ships saying Meridian Vocational College.

        Longest match first, always. Replace 'MVC' before the legal-entity line
        and you destroy the line you were about to match.

        On an MVC build every replacement is identity and this is a no-op.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $WorkDir,
        [Parameter(Mandatory)] $Branding,
        [string] $Variant,
        [string[]] $Parts
    )

    $b = $Branding
    $rto = $b.rto
    $trading = $rto.tradingName
    # Root-level fallback first, so a future brand WITHOUT variants still swaps
    # its website - the email pairs below already fall back this way, and $null
    # here would silently keep www.mvc.edu.au.
    $site    = $(if ($rto.PSObject.Properties.Name -contains 'website' -and $rto.website) { $rto.website } else { $null })
    $tagline = $b.tagline

    if ($b.PSObject.Properties.Name -contains 'variants' -and $b.variants) {
        if (-not $Variant) { $Variant = $b.variants.default }
        $v = $b.variants.$Variant
        if (-not $v) { throw "Brand has no variant '$Variant'." }
        $trading = $v.tradingName
        $site    = $v.website
        $tagline = $v.tagline
    }

    $shortName = if ($rto.PSObject.Properties.Name -contains 'shortName' -and $rto.shortName) { $rto.shortName } else { $b.brand }

    # MVC template value -> this brand's value. Order is significant.
    $pairs = @(
        @('Golden Wattle Group Pty Ltd T/A Meridian Vocational College', "$($rto.legalEntity) T/A $trading"),
        @('Meridian Vocational College (MVC)',                           "$trading ($shortName)"),
        @('Meridian Vocational College',                                 $trading),
        @('www.mvc.edu.au',                                              $site),
        @('info@mvc.edu.au',                                             $(if ($b.PSObject.Properties.Name -contains 'variants') { $b.variants.$Variant.email } else { $rto.email })),
        @('Info@mvc.edu.au',                                             $(if ($b.PSObject.Properties.Name -contains 'variants') { $b.variants.$Variant.email } else { $rto.email })),
        @('mvc.edu.au',                                                  $site),
        # ADDRESS AND PHONE. These were missing, so an ACI document printed
        # MVC's street address and MVC's phone number on its own title page -
        # under an ACI logo, an ACI palette and the ACI trading name. The text
        # sweep did not catch it either, because neither string was a forbidden
        # token. A brand swap that moves the name but leaves the address is not
        # a brand swap.
        @('Level 2 West, 50 Grenfell Street, Adelaide SA 5000', $rto.address),
        @('Level 2 West, 50 Grenfell Street',                   ($rto.address -replace ', Adelaide SA 5000$','')),
        @('0432 421 482',                                       $rto.phone),
        @('Student MVC ID:',                                             $b.policy.studentIdLabel),
        @('45039',                                                       $rto.rtoCode),
        @('03551M',                                                      $rto.cricosCode),
        # THE SEPARATOR IS U+00B7 MIDDOT, NOT A FULL STOP. Written with ASCII
        # dots this pair matched nothing, so every ACI document shipped MVC's
        # tagline on its title page - and the crossover sweep missed it too,
        # because 'INNOVATION' is registered as a whole-word token and the
        # template letter-spaces it. Build the character from its code point:
        # this file is ASCII-only, per template-build.md.
        @(('I N N O V A T I O N   {0}   T R A D I T I O N   {0}   E D U C A T I O N' -f [char]0x00B7), $tagline),
        @('MVC',                                                          $shortName)
    )

    if (-not $Parts) {
        # docProps is in the list because a brand leak does not have to be
        # visible to be real. app.xml carries <Company> = the MVC legal entity,
        # which shows in Word's File > Properties and in any document register
        # built from metadata. An ACI pack whose properties say Meridian
        # Vocational College is still an ACI pack that names the wrong RTO.
        #
        # custom.xml is in the list because the template carries StreetAddress
        # as a custom property, and Set-DocControl's map does not set one - so
        # without this an ACI build kept MVC's street address in its own
        # properties, invisible to every sweep. The 'MVC' shortName pair also
        # touches cmsDocName here, harmlessly: Set-DocControl overwrites it
        # immediately after in Write-PackDocument.
        $Parts = @('word/document.xml') +
                 @(Get-DocxHeaderFooterParts -WorkDir $WorkDir) +
                 @('docProps/app.xml', 'docProps/core.xml', 'docProps/custom.xml')

        # RELATIONSHIP TARGETS TOO. A hyperlink's visible text lives in the
        # part; its TARGET lives in the .rels file. Swapping only the parts
        # left www.mvc.edu.au and mailto:Info@mvc.edu.au as live link targets
        # in every ACI document - invisible on the page, wrong on click.
        # Found 29 August 2026 in a delivered pack's document.xml.rels.
        $Parts += @('word/_rels/document.xml.rels')
        foreach ($hf in @(Get-DocxHeaderFooterParts -WorkDir $WorkDir)) {
            $hfRels = (Split-Path $hf -Parent) + '/_rels/' + (Split-Path $hf -Leaf) + '.rels'
            if (Test-Path (Join-Path $WorkDir ($hfRels -replace '/', '\'))) { $Parts += $hfRels }
        }
    }

    $counts = [ordered]@{}
    foreach ($part in $Parts) {
        $full = Join-Path $WorkDir ($part -replace '/', '\')
        if (-not (Test-Path $full)) { continue }
        $xml = Get-DocxPart -WorkDir $WorkDir -Part $part
        $changed = $false
        foreach ($pair in $pairs) {
            $from = $pair[0]; $to = $pair[1]
            if ($null -eq $to -or $to -eq '' -or $to -eq $from) { continue }
            if (-not $xml.Contains($from)) { continue }   # ordinal, far cheaper than the regex count below
            $n = ([regex]::Matches($xml, [regex]::Escape($from))).Count
            if ($n -gt 0) {
                $xml = $xml.Replace($from, [string]$to)
                if (-not $counts.Contains($from)) { $counts[$from] = 0 }
                $counts[$from] += $n
                $changed = $true
            }
        }
        if ($changed) { Set-DocxPart -WorkDir $WorkDir -Part $part -Content $xml }
    }

    [pscustomobject]@{ Variant = $Variant; TradingName = $trading; Replaced = $counts; Total = ($counts.Values | Measure-Object -Sum).Sum }
}
function Set-BrandPalette {
    <#  Recolour the parts of a document the builder did not author.

        WHY THIS EXISTS. ACI builds from MVC's approved templates, and the
        template's own COVER SHEET and TITLE PAGE come across unchanged - 121
        MVC colour references on a measured build. Set-HousePalette colours the
        generated body only, so without this a document is half ACI and half
        MVC: ACI banners under an MVC cover sheet.

        It remaps by ROLE, not by guesswork - MVC navy becomes the brand's dark,
        MVC light fill becomes the brand's light fill, and so on. On an MVC build
        every mapping is identity and the function is a no-op.

        Returns a count per colour so a build can report what moved.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $WorkDir,
        [Parameter(Mandatory)] $Palette,
        [string[]] $Parts
    )

    function P3 {
        param($o, [string[]]$names, $d)
        foreach ($n in $names) {
            if (($o.PSObject.Properties.Name -contains $n) -and $o.$n) { return [string]$o.$n }
        }
        return $d
    }

    # MVC hex -> the role it plays -> this brand's value for that role.
    $map = [ordered]@{
        '234B8C' = P3 $Palette @('dark','Dark')                 '234B8C'   # navy: banners, header rows, headings
        '2F60B4' = P3 $Palette @('accent','Accent')             '2F60B4'   # blue: rules, secondary emphasis, wordmark
        'F09C0C' = P3 $Palette @('rule','Rule')                 'F09C0C'   # orange: bullet glyphs, left rules, tagline
        'F5C800' = P3 $Palette @('rule','Rule')                 'F5C800'   # MVC logo yellow
        'E45418' = P3 $Palette @('accent','Accent')             'E45418'   # MVC logo deep orange
        '606060' = P3 $Palette @('grey','Grey')                 '606060'   # muted text, footer
        'F0F2F7' = P3 $Palette @('lightFill','Fill','LightFill') 'F0F2F7'   # panel fills, tinted cells
        'C9CFDD' = P3 $Palette @('border','Border')             'C9CFDD'   # table borders
        'E43C30' = P3 $Palette @('modelAnswer','ModelAnswer')   'E43C30'   # model answer red
    }

    if (-not $Parts) {
        # numbering.xml holds the bullet glyph colour and styles.xml the defaults.
        # Skip them and every body bullet in an ACI document stays MVC orange.
        $Parts = @('word/document.xml', 'word/numbering.xml', 'word/styles.xml') +
                 @(Get-DocxHeaderFooterParts -WorkDir $WorkDir)
    }

    $counts = [ordered]@{}
    foreach ($part in $Parts) {
        $full = Join-Path $WorkDir ($part -replace '/', '\')
        if (-not (Test-Path $full)) { continue }
        $xml = Get-DocxPart -WorkDir $WorkDir -Part $part
        $changed = $false
        foreach ($from in $map.Keys) {
            $to = $map[$from]
            if ($to -eq $from) { continue }
            # Hex colours are case-insensitive in OOXML and appear in w:fill,
            # w:color and w:themeColor attributes. Match the value, not a tag.
            $n = ([regex]::Matches($xml, $from, 'IgnoreCase')).Count
            if ($n -gt 0) {
                $xml = [regex]::Replace($xml, $from, $to, 'IgnoreCase')
                if (-not $counts.Contains($from)) { $counts[$from] = 0 }
                $counts[$from] += $n
                $changed = $true
            }
        }
        if ($changed) { Set-DocxPart -WorkDir $WorkDir -Part $part -Content $xml }
    }

    [pscustomobject]@{ Remapped = $counts; Total = ($counts.Values | Measure-Object -Sum).Sum }
}
function Set-BrandLogo {
    <#  Replace the template's embedded logo with the brand's own mark - in
        EVERY part that draws it.

        WHY THIS EXISTS. ACI builds from MVC's approved templates, so the MVC
        logo is sitting in word/media/ of every ACI build. The brand-crossover
        text sweep cannot see an image - it reads runs and fields - so without
        this the pack ships looking like MVC and nothing catches it.

        WHY IT SWEEPS EVERY PART, NOT THE FIRST PART THAT HAS AN IMAGE.
        29 August 2026: the UAT template carries the MVC mark THREE times -
        once in document.xml (the title page) and twice in header2 (the two
        header copies). The previous version took the first image-bearing part
        and stopped, so it swapped the title page and shipped the MVC mark in
        the header of every knowledge document. The recipe template only ever
        worked because its document.xml happens to reference no image at all.
        The logo is swapped wherever it is drawn, and Assert-BrandLogo below is
        the blocking gate that proves it.

        WHY IT RESIZES. The marks are different shapes. MVC's is 2.38:1, the ACI
        construction mark 2.46:1 and the ACI culinary mark 3.53:1. Swapping the
        bytes alone leaves the original wp:extent in place and Word stretches the
        new mark to the old box. Width is held; height is recomputed from the
        incoming aspect ratio, per part, so the mark is never distorted.

        Returns what it did, so a build can report it - including the SHA256 of
        every image it replaced, which Assert-BrandLogo uses as forbidden bytes. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $WorkDir,
        [Parameter(Mandatory)][string] $LogoPath,
        [string] $Part = 'word/document.xml'
    )

    if (-not (Test-Path $LogoPath)) { throw "Brand logo not found: $LogoPath" }

    $candidates = @($Part) + @(Get-DocxHeaderFooterParts -WorkDir $WorkDir | Where-Object { $_ -ne $Part })
    $newExt  = [System.IO.Path]::GetExtension($LogoPath)
    $newHash = (Get-FileHash -LiteralPath $LogoPath -Algorithm SHA256).Hash
    $utf8    = New-Object System.Text.UTF8Encoding($false)

    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    $ratio = $null
    try {
        $bmp = [System.Drawing.Image]::FromFile((Resolve-Path $LogoPath).Path)
        $ratio = $bmp.Width / $bmp.Height
        $bmp.Dispose()
    } catch { }

    $replaced = @(); $oldHashes = @(); $partsTouched = @(); $resizedParts = @()

    foreach ($cand in $candidates) {
        $rp = Join-Path $WorkDir ((Split-Path $cand -Parent) + '\_rels\' + (Split-Path $cand -Leaf) + '.rels')
        if (-not (Test-Path $rp)) { continue }
        $rl = [System.IO.File]::ReadAllText($rp, [System.Text.Encoding]::UTF8)
        # @() MATTERS. A single match collapses to a scalar string, and $img[0]
        # then returns its first CHARACTER rather than the filename.
        $hits = @([regex]::Matches($rl, 'Target="media/([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
        if ($hits.Count -eq 0) { continue }

        # SEVERAL RELATIONSHIPS CAN POINT AT THE SAME PICTURE. The headers
        # reference the logo twice as byte-identical files - one logo, all
        # replaced. Genuinely different images in one part still refuse,
        # because then it IS a guess.
        $uniq = @{}
        foreach ($h in $hits) {
            $hp = Join-Path $WorkDir ('word\media\' + $h)
            if (-not (Test-Path $hp)) { continue }
            $sha = (Get-FileHash -LiteralPath $hp -Algorithm SHA256).Hash
            if (-not $uniq.ContainsKey($sha)) { $uniq[$sha] = @() }
            $uniq[$sha] += $h
        }
        if ($uniq.Keys.Count -eq 0) { continue }
        if ($uniq.Keys.Count -gt 1) {
            throw "Expected one logo in $cand, found $($uniq.Keys.Count) different images: $($hits -join ', '). Refusing to guess which is the logo."
        }
        $oldSha = @($uniq.Keys)[0]
        if ($oldSha -ne $newHash) { $oldHashes += $oldSha }

        # A FORMAT CHANGE IS NORMAL AND MUST BE HANDLED, NOT REFUSED. The new
        # bytes go in under the logo's own extension: [Content_Types] learns
        # the extension, every relationship is repointed, the orphan removed.
        # A rename that lands on an existing file only ever collides with the
        # same logo already written by an earlier part - Copy-Item -Force is
        # correct there, never destructive.
        $renamed = @{}
        $imgs = @($hits | Select-Object -Unique)
        $oldExt = [System.IO.Path]::GetExtension($imgs[0])
        if ($oldExt -ne $newExt) {
            $ct  = Join-Path $WorkDir '[Content_Types].xml'
            $ctx = [System.IO.File]::ReadAllText($ct, [System.Text.Encoding]::UTF8)
            $ext = $newExt.TrimStart('.').ToLower()
            if ($ctx -notmatch ('Extension="' + [regex]::Escape($ext) + '"')) {
                $mime = switch ($ext) { 'png' { 'image/png' } 'jpeg' { 'image/jpeg' } 'jpg' { 'image/jpeg' } 'gif' { 'image/gif' } default { "image/$ext" } }
                $ctx = $ctx -replace '(<Types[^>]*>)', "`$1<Default Extension=`"$ext`" ContentType=`"$mime`"/>"
                [System.IO.File]::WriteAllText($ct, $ctx, $utf8)
            }
            foreach ($old in $imgs) {
                $new = [System.IO.Path]::GetFileNameWithoutExtension($old) + $newExt
                $renamed[$old] = $new
                $rl = $rl.Replace("media/$old", "media/$new")
                $op = Join-Path $WorkDir ('word\media\' + $old)
                if (Test-Path $op) { Remove-Item -LiteralPath $op -Force }
            }
            [System.IO.File]::WriteAllText($rp, $rl, $utf8)
        }

        # Write the mark to every copy this part references.
        foreach ($old in $imgs) {
            $name = $(if ($renamed.ContainsKey($old)) { $renamed[$old] } else { $old })
            Copy-Item -LiteralPath $LogoPath -Destination (Join-Path $WorkDir ('word\media\' + $name)) -Force
            if ($replaced -notcontains $name) { $replaced += $name }
        }

        # Hold width, recompute height from the incoming aspect ratio - in
        # THIS part. Safe at swap time: the template's only drawings are the
        # logo marks; the swap always runs before the body is spliced in.
        if ($ratio) {
            $xml = Get-DocxPart -WorkDir $WorkDir -Part $cand
            $m = [regex]::Match($xml, '<wp:extent cx="(\d+)" cy="(\d+)"/>')
            if ($m.Success) {
                $cx = [int]$m.Groups[1].Value
                $cy = [int][math]::Round($cx / $ratio)
                # Both wp:extent and a:ext must move together, or Word crops.
                $xml = $xml -replace '<wp:extent cx="\d+" cy="\d+"/>', "<wp:extent cx=""$cx"" cy=""$cy""/>"
                $xml = $xml -replace '<a:ext cx="\d+" cy="\d+"/>',      "<a:ext cx=""$cx"" cy=""$cy""/>"
                Set-DocxPart -WorkDir $WorkDir -Part $cand -Content $xml
                $resizedParts += $cand
            }
        }
        $partsTouched += $cand
    }

    if ($partsTouched.Count -eq 0) {
        throw "No image relationship in $Part or in any header or footer - nothing to replace."
    }

    [pscustomobject]@{
        Replaced  = ($replaced -join ', ')
        Parts     = $partsTouched
        From      = (Split-Path $LogoPath -Leaf)
        Ratio     = $(if ($ratio) { [math]::Round($ratio,2) } else { $null })
        Resized   = $resizedParts.Count
        OldHashes = @($oldHashes | Select-Object -Unique)
        NewHash   = $newHash
    }
}

function Assert-BrandLogo {
    <#  THE BLOCKING GATE THE TEXT SWEEP CANNOT BE. A logo is an image; the
        brand-crossover sweep reads runs and fields and reports clean while the
        wrong mark sits in the header of every page. 29 August 2026: every
        knowledge document of a delivered pack carried the MVC mark in its
        header, all gates green, and the RTO found it, not the build.

        Two checks, both on bytes, both cheap (a handful of small files):

        1. Every image referenced from any header or footer part IS the
           resolved brand mark - byte-identical to the logo asset.
        2. No media part anywhere in the package matches a FORBIDDEN mark -
           another brand's logo, the other trading-name variant's logo, or the
           bytes this build just replaced.

        Throws on any finding, before a file exists to mislead anyone.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $WorkDir,
        [string]   $ExpectedLogoPath,
        [string[]] $ForbiddenLogoPaths = @(),
        [string[]] $ForbiddenHashes    = @()
    )

    $expHash = $null
    if ($ExpectedLogoPath) {
        if (-not (Test-Path $ExpectedLogoPath)) { throw "Assert-BrandLogo: expected logo not found: $ExpectedLogoPath" }
        $expHash = (Get-FileHash -LiteralPath $ExpectedLogoPath -Algorithm SHA256).Hash
    }
    $forbidden = @{}
    foreach ($f in $ForbiddenLogoPaths) {
        if (-not (Test-Path $f)) { continue }
        $h = (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash
        if ($h -ne $expHash) { $forbidden[$h] = (Split-Path $f -Leaf) }
    }
    foreach ($h in $ForbiddenHashes) {
        if ($h -and $h -ne $expHash -and -not $forbidden.ContainsKey($h)) { $forbidden[$h] = 'replaced source-brand logo bytes' }
    }

    $bad = @()

    if ($expHash) {
        foreach ($cand in @(Get-DocxHeaderFooterParts -WorkDir $WorkDir)) {
            $rp = Join-Path $WorkDir ((Split-Path $cand -Parent) + '\_rels\' + (Split-Path $cand -Leaf) + '.rels')
            if (-not (Test-Path $rp)) { continue }
            $rl = [System.IO.File]::ReadAllText($rp, [System.Text.Encoding]::UTF8)
            foreach ($m in @([regex]::Matches($rl, 'Target="media/([^"]+)"'))) {
                $name = $m.Groups[1].Value
                $hp = Join-Path $WorkDir ('word\media\' + $name)
                if (-not (Test-Path $hp)) { $bad += "$cand references missing media/$name"; continue }
                $h = (Get-FileHash -LiteralPath $hp -Algorithm SHA256).Hash
                if ($h -ne $expHash) { $bad += "$cand draws media/$name, which is NOT the brand logo" }
            }
        }
    }

    $mediaDir = Join-Path $WorkDir 'word\media'
    if (Test-Path $mediaDir) {
        foreach ($mf in Get-ChildItem -LiteralPath $mediaDir -File) {
            $h = (Get-FileHash -LiteralPath $mf.FullName -Algorithm SHA256).Hash
            if ($forbidden.ContainsKey($h)) { $bad += "word/media/$($mf.Name) is the WRONG mark: $($forbidden[$h])" }
        }
    }

    if ($bad.Count -gt 0) {
        throw ("Brand logo gate FAILED - the package would ship with the wrong mark:`n  - " + ($bad -join "`n  - "))
    }
    [pscustomobject]@{ Ok = $true; Expected = $(if ($ExpectedLogoPath) { Split-Path $ExpectedLogoPath -Leaf } else { $null }); ForbiddenChecked = $forbidden.Count }
}
function Test-DocxPackage {
    <#  Structural check on an unpacked package. Returns a result object; does not
        throw, so a caller can report every problem at once rather than the first.

        This is the ONLY function here that parses XML, and it parses a copy it
        loaded itself. It never writes a part back.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $WorkDir)

    $problems = New-Object System.Collections.Generic.List[string]

    # 1. Every part is well-formed XML.
    foreach ($part in (Get-DocxParts -WorkDir $WorkDir)) {
        try {
            $doc = New-Object System.Xml.XmlDocument
            $doc.PreserveWhitespace = $true
            $doc.LoadXml((Get-DocxPart -WorkDir $WorkDir -Part $part))
        }
        catch { $problems.Add("Malformed XML in $part - $($_.Exception.Message)") }
    }

    # 2. Namespace declarations survived. This is the serialisation trap.
    $docXml = Get-DocxPart -WorkDir $WorkDir -Part 'word/document.xml'
    if ($docXml -match '<w:document\b[^>]*>') {
        $root = $Matches[0]
        if ($root -match 'mc:Ignorable="([^"]*)"') {
            foreach ($pfx in ($Matches[1] -split '\s+' | Where-Object { $_ })) {
                if ($root -notmatch ("xmlns:" + [regex]::Escape($pfx) + "=")) {
                    $problems.Add("word/document.xml declares mc:Ignorable prefix '$pfx' but carries no xmlns:$pfx declaration. Word will refuse to open this file. A namespace-aware parser has been used on it.")
                }
            }
        }
    }
    else { $problems.Add('word/document.xml has no <w:document> root element.') }

    # 3. Every extension used is declared in [Content_Types].xml.
    $ct = Get-DocxPart -WorkDir $WorkDir -Part '[Content_Types].xml'
    $declared = ([regex]::Matches($ct, 'Extension="([^"]+)"') | ForEach-Object { $_.Groups[1].Value.ToLower() })
    $used = Get-ChildItem -Path $WorkDir -Recurse -File |
            Where-Object { $_.Name -ne '.entryorder' } |
            ForEach-Object { $_.Extension.TrimStart('.').ToLower() } |
            Where-Object { $_ } | Sort-Object -Unique
    foreach ($e in $used) {
        if ($declared -notcontains $e -and $ct -notmatch "PartName=`"[^`"]+\.$e`"") {
            $problems.Add("Extension '.$e' is used in the package but not declared in [Content_Types].xml.")
        }
    }

    # 4. Every relationship target resolves.
    foreach ($relPart in (Get-DocxParts -WorkDir $WorkDir | Where-Object { $_ -match '_rels/[^/]*\.rels$' })) {
        $relXml = Get-DocxPart -WorkDir $WorkDir -Part $relPart
        $base   = Split-Path -Parent (Split-Path -Parent (Join-Path $WorkDir ($relPart -replace '/', '\')))
        foreach ($m in [regex]::Matches($relXml, '<Relationship\b[^>]*>')) {
            if ($m.Value -match 'TargetMode="External"') { continue }
            if ($m.Value -notmatch 'Target="([^"]+)"')   { continue }
            $t = $Matches[1]
            if ($t -match '^(https?|mailto|file):') { continue }
            $resolved = [System.IO.Path]::GetFullPath((Join-Path $base ($t -replace '/', '\')))
            if (-not (Test-Path -LiteralPath $resolved)) { $problems.Add("$relPart -> unresolved relationship target '$t'.") }
        }
    }

    # 5. numId values are declared and unique.
    if (Test-Path -LiteralPath (Join-Path $WorkDir 'word\numbering.xml')) {
        $num  = Get-DocxPart -WorkDir $WorkDir -Part 'word/numbering.xml'
        $decl = [regex]::Matches($num, '<w:num\b[^>]*w:numId="(\d+)"') | ForEach-Object { $_.Groups[1].Value }
        $dupes = $decl | Group-Object | Where-Object { $_.Count -gt 1 }
        foreach ($d in $dupes) { $problems.Add("word/numbering.xml declares numId $($d.Name) $($d.Count) times.") }
        foreach ($m in [regex]::Matches($docXml, '<w:numId\b[^>]*w:val="(\d+)"')) {
            $v = $m.Groups[1].Value
            if ($v -ne '0' -and $decl -notcontains $v) { $problems.Add("document.xml references numId $v which numbering.xml does not declare.") }
        }
    }

    # 6. No illegal control characters.
    foreach ($part in @('word/document.xml') + (Get-DocxHeaderFooterParts -WorkDir $WorkDir)) {
        $body = Get-DocxPart -WorkDir $WorkDir -Part $part
        if ($body -match '[\x00-\x08\x0B\x0C\x0E-\x1F]') { $problems.Add("$part contains an illegal XML control character.") }
    }

    [pscustomobject]@{
        Ok       = ($problems.Count -eq 0)
        Problems = $problems.ToArray()
        WorkDir  = $WorkDir
    }
}

function Assert-DocxPackage {
    <# Test-DocxPackage, but throws with every problem listed. Use before repacking. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $WorkDir)
    $r = Test-DocxPackage -WorkDir $WorkDir
    if (-not $r.Ok) { throw ("Package validation failed:`n  - " + ($r.Problems -join "`n  - ")) }
    Write-Verbose 'Package validation passed.'
    return $true
}

# ---------------------------------------------------------------------------
# Pre-delivery sweeps over the SOURCE text
# ---------------------------------------------------------------------------

function Find-ForbiddenToken {
    <#  Brand-crossover matcher, shared with Verify-Document.ps1.

        Each token in a branding profile declares its own match mode, because a
        single blanket rule produces false positives that train the reader to
        ignore the sweep:

          word-cs       whole word, case-sensitive   ACI, Gms
          word-ci       whole word, case-insensitive codes and hex colours
          substring-ci  anywhere, case-insensitive   multi-word names, domains

        'ACI' matched loosely as a case-insensitive substring hits 'facility' and
        'spacing'. 'Gms' matched loosely hits every correctly lower-cased 'gms'.
        Both were observed on the real templates.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string] $Text,
        [Parameter(Mandatory)] $Branding
    )

    $out = New-Object System.Collections.Generic.List[object]
    foreach ($entry in $Branding.forbiddenTokens.tokens) {
        # Tolerate the older plain-string form so an un-migrated profile still runs.
        if ($entry -is [string]) { $tok = $entry; $mode = 'substring-ci' }
        else                     { $tok = $entry.token; $mode = $entry.mode }
        if (-not $mode) { $mode = 'substring-ci' }

        $esc = [regex]::Escape($tok)
        switch ($mode) {
            'word-cs'      { $pattern = "(?<![\w])$esc(?![\w])"; $opts = [Text.RegularExpressions.RegexOptions]::None }
            'word-ci'      { $pattern = "(?<![\w])$esc(?![\w])"; $opts = [Text.RegularExpressions.RegexOptions]::IgnoreCase }
            default        { $pattern = $esc;                    $opts = [Text.RegularExpressions.RegexOptions]::IgnoreCase }
        }
        $n = ([regex]::Matches($Text, $pattern, $opts)).Count
        if ($n -gt 0) { $out.Add([pscustomobject]@{ Token = $tok; Mode = $mode; Count = $n }) }
    }
    return $out.ToArray()
}

function Test-DocxSweeps {
    <#  Placeholder, guidance-marker and brand-crossover sweeps.

        These run over the package's source text. They are a fast gate that
        catches the common failures before Word is opened at all. They do NOT
        replace the rendered-output sweeps in Verify-Document.ps1 - a field or a
        content control can put text on the page that is not in a <w:t> here.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $WorkDir,
        [Parameter(Mandatory)] $Branding,
        [switch] $AssessorVersion
    )

    $raw      = (Get-DocxText -WorkDir $WorkDir) -join "`n"
    $findings = New-Object System.Collections.Generic.List[object]

    function Add-Finding($sweep, $detail) { $findings.Add([pscustomobject]@{ Sweep = $sweep; Detail = $detail }) }

    # U+00BB GUILLEMET, built from its code point. A literal here is decoded as
    # ANSI by PowerShell 5.1 and silently matches nothing - which is how the
    # guidance-marker sweep came to report a clean result on a template full of
    # guidance lines. See template-build.md.
    $G = [char]0x00BB

    foreach ($m in [regex]::Matches($raw, '\[[^\]\r\n]{1,80}\]'))     { Add-Finding 'Placeholder'     "Unresolved placeholder: $($m.Value)" }
    foreach ($m in [regex]::Matches($raw, "(?m)^\s*$G.*$"))           { Add-Finding 'Guidance marker' "Template guidance line left in: $($m.Value.Trim())" }

    # Sweeps below run with guidance lines stripped. Such a line is reported
    # above and deleted at build; leaving it in double-reports it, and the
    # guidance itself says things like "No oral questioning", which would then
    # be flagged as an oral-questioning reference.
    $text = ($raw -split "`n" | Where-Object { $_ -notmatch "^\s*$G" }) -join "`n"

    foreach ($hit in (Find-ForbiddenToken -Text $text -Branding $Branding)) {
        Add-Finding 'Brand crossover' "'$($hit.Token)' appears $($hit.Count) time(s) - belongs to the other brand."
    }

    if (-not $AssessorVersion) {
        # Assessor-panel LABELS, not ordinary words. Keep in step with the same
        # list in Verify-Document.ps1. 'benchmark' alone is legitimate learner
        # prose explaining reliability and is deliberately not on this list.
        $leaks = @(
            'ASSESSOR BENCHMARK', 'What Satisfactory looks like', 'Minimum acceptable response',
            'Critical error', 'Model answer', 'Assessor use only', 'NOT FOR RELEASE',
            'Sample-marked', 'Simulated-environment setup', 'Staged cue', 'Assessor-supplied trigger'
        )
        foreach ($tok in $leaks) {
            $hits = [regex]::Matches($text, [regex]::Escape($tok), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($hits.Count -gt 0) { Add-Finding 'Assessor-only leak' "'$tok' appears $($hits.Count) time(s) in a learner document." }
        }
    }

    # Positions fixed by the combined template prompt section 7.
    # 'Oral communication' is a Foundation Skill name and must not match.
    $n = ([regex]::Matches($text, 'oral(ly)?\s+question|Oral Questioning Record', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
    if ($n -gt 0) { Add-Finding 'Fixed position' "Oral questioning referenced $n time(s). MVC position is no oral questioning anywhere." }
    if ($text -match '(?i)results within (\d+) days') {
        $d = [int]$Matches[1]
        if ($d -ne [int]$Branding.policy.resultsWithinDays) { Add-Finding 'Fixed position' "Results stated as $d days; branding profile says $($Branding.policy.resultsWithinDays)." }
    }

    [pscustomobject]@{
        Ok       = ($findings.Count -eq 0)
        Findings = $findings.ToArray()
    }
}

Write-Verbose 'Build-FromTemplate.ps1 loaded.'
