<#
    Test-Finding.ps1 - Stage 6b finding arbitration. Test the PREMISE of every
    audit finding mechanically, before any finding becomes a work order.

    Implements the gate references\gates.md section 19 calls
    Assert-FindingProvenance. Runs at Stage 6b: after the review band, before
    any remediation edit, and over the audit's own output before its verdict is
    accepted.

    WHY IT EXISTS - two false HIGH findings on one build, and one was acted on.
    Round 3 declared that the guide had FABRICATED "about 3840 Gms raw" for a
    recipe card, and that the card carried no raw batch weight. The card prints
    exactly that figure, in the LEARNER workbook and in the assessor guide, and
    both extracts were in the clean-room pack the auditor was handed. Nothing
    sat between that finding and a work order: remediation stripped the correct
    figure, wrote a false statement in its place, and the registry was taught to
    forbid the weight and every figure derived from it - poisoning every future
    build of the same content. Round 4 then declared that a food-standard scope
    read "two years or less" when every occurrence already read "less than two
    years". Both findings were refutable with one grep each. Nobody grepped.

    WHAT IT DOES. For each finding it tests the premise the finding rests on,
    by class, and reports the anchor:

      fabricated / unsourced / misattributed
          variant-expand the value (digits and word forms, unit spellings such
          as Gms/g/grams and degrees C/deg C, the hyphen/space/comma family)
          and grep the ENTIRE corpus - every learner tool, every assessor
          guide, the unit extract, any recipe or appendix text. A hit is
          REFUTED-CANDIDATE, with doc:line:text. None is UNREFUTED.
      wrong-value / wrong-clause
          grep the SPINE for the string the finding calls wrong. Absent is
          STALE - the page already reads otherwise. Present: grep the sources
          for the string the finding calls right; absent is DOUBTFUL.
      leak
          run Check-FigureMirror.ps1 scoped to the named sub-section file and
          report its count; UNCHECKED when that gate is not beside this script.
      missing-target
          resolve the target against the spine's slots, captions, sub-section
          refs and headings; a hit is REFUTED-CANDIDATE.
      not-taught
          grep the spine for the value; a hit is REFUTED-CANDIDATE.
      any proposedForbid literal found in ANY source document
          FORBID-REJECTED. A build must never forbid a value its own sources
          carry.

    THE ARBITER NEVER CLEARS A FINDING. It is a string search. It cannot know
    that a hit means what the finding denies, and it cannot know that silence
    means the finding is true. All it can do is DEMOTE a finding to
    needs-re-read and print the line the reader must look at - and refuse to
    let a remediation round start while such a finding stands unread. Every
    verdict is a reader's, recorded at Stage 6b with its reason. UNREFUTED is
    not "confirmed"; it means the search found nothing against the premise.

    INPUT. A findings sidecar, JSON, an array (or { findings: [...] }) of
      { id, risk, class, claim, value, where:{artefact, locator},
        source:{doc, locator}|null, proposedForbid:[], expected? }
    class is one of: fabricated | unsourced | misattributed | wrong-value |
    wrong-clause | leak | not-taught | missing-target.
    A markdown audit report is accepted as a FALLBACK: rows shaped
    "| **H-n** | title | risk | claim | where |" are parsed, the class is
    inferred from the wording and the value from the first quoted or bolded
    string in the claim. That parse is BEST-EFFORT and the run says so; write
    the sidecar for anything that matters.

    OUTPUT. findings_arbitrated.json beside the input (or -OutPath), plus a
    table on the console.

    Generic across RTOs, brands and units: every path comes from the build.
    PS 5.1. ASCII only in this file.
    Exit 0 nothing demoted; 1 at least one finding is REFUTED-CANDIDATE, STALE
    or FORBID-REJECTED, so the round may not start until it is re-read;
    2 a usage error; 4 the self-test failed.
#>

[CmdletBinding()]
param(
    [string] $Findings,
    [string] $BuildDir,
    #  Extra source text beyond the canonical corpus - the assessment build's
    #  own recipe cards or appendix extracts, for instance. Every .txt and .md
    #  beneath it is a source document.
    [string] $PackDir,
    [string] $CorpusDir,
    [string] $SpineDir,
    [string] $OutPath,
    [switch] $SelfTest,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

$GATE = 'Test-Finding'
$script:Classes  = @('fabricated', 'unsourced', 'misattributed', 'wrong-value', 'wrong-clause', 'leak', 'not-taught', 'missing-target')
$script:Blocking = @('REFUTED-CANDIDATE', 'STALE', 'FORBID-REJECTED')
$script:MaxHits  = 5

#  Unit spellings that mean the same thing. A finding that says "3840 Gms" must
#  hit a source that says "3,840 g" or "three thousand eight hundred and forty
#  grams": a literal-string sweep is not an enumerating check.
$script:UnitFamilies = @(
    'g|gm|gms|gram|grams|gramme|grammes',
    'kg|kgs|kilo|kilos|kilogram|kilograms',
    'l|ltr|ltrs|litre|litres|liter|liters',
    'ml|mls|millilitre|millilitres|milliliter|milliliters',
    'h|hr|hrs|hour|hours',
    'min|mins|minute|minutes',
    'sec|secs|second|seconds',
    'mm|millimetre|millimetres|millimeter|millimeters',
    'cm|centimetre|centimetres|centimeter|centimeters',
    'day|days', 'week|weeks', 'month|months', 'year|years',
    'portion|portions', 'serve|serves|serving|servings'
)

$script:NumberWords = @{
    'zero' = 0; 'one' = 1; 'two' = 2; 'three' = 3; 'four' = 4; 'five' = 5; 'six' = 6; 'seven' = 7;
    'eight' = 8; 'nine' = 9; 'ten' = 10; 'eleven' = 11; 'twelve' = 12; 'thirteen' = 13; 'fourteen' = 14;
    'fifteen' = 15; 'sixteen' = 16; 'seventeen' = 17; 'eighteen' = 18; 'nineteen' = 19; 'twenty' = 20;
    'thirty' = 30; 'forty' = 40; 'fifty' = 50; 'sixty' = 60; 'seventy' = 70; 'eighty' = 80; 'ninety' = 90
}

# ---------------------------------------------------------------------------
# 1. Variant expansion - digits, words, units, separators
# ---------------------------------------------------------------------------

function ConvertTo-EnglishNumber {
    param([long] $N)
    $ones = @('zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten',
              'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen')
    $tens = @('', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety')
    if ($N -lt 0) { return ('minus ' + (ConvertTo-EnglishNumber (-$N))) }
    if ($N -lt 20) { return $ones[[int]$N] }
    if ($N -lt 100) {
        $t = $tens[[int][math]::Floor($N / 10)]
        $r = $N % 10
        if ($r -gt 0) { return ($t + ' ' + $ones[[int]$r]) }
        return $t
    }
    if ($N -lt 1000) {
        $h = $ones[[int][math]::Floor($N / 100)] + ' hundred'
        $r = $N % 100
        if ($r -gt 0) { return ($h + ' and ' + (ConvertTo-EnglishNumber $r)) }
        return $h
    }
    foreach ($sc in @(@(1000000000, 'billion'), @(1000000, 'million'), @(1000, 'thousand'))) {
        if ($N -ge $sc[0]) {
            $head = (ConvertTo-EnglishNumber ([long][math]::Floor($N / $sc[0]))) + ' ' + $sc[1]
            $r = $N % $sc[0]
            if ($r -eq 0) { return $head }
            if ($r -lt 100) { return ($head + ' and ' + (ConvertTo-EnglishNumber $r)) }
            return ($head + ' ' + (ConvertTo-EnglishNumber $r))
        }
    }
    return "$N"
}

function ConvertTo-WordRegex {
    <# "three thousand eight hundred and forty" -> a regex that also takes hyphens and an optional "and". #>
    param([string] $Words)
    $parts = @($Words -split '\s+' | Where-Object { $_ })
    $s = ''
    for ($i = 0; $i -lt $parts.Count; $i++) {
        $tk = $parts[$i]
        if ($tk -eq 'and') { $s += '(?:and[\s-]*)?'; continue }
        $s += $tk
        if ($i -lt $parts.Count - 1) { $s += '[\s-]*' }
    }
    return ('\b' + $s + '\b')
}

function Get-NumberRegex {
    <# Every way a number is written: 3840, 3,840, 3 840, and its word form. #>
    param([string] $Tok)
    $alts = New-Object System.Collections.Generic.List[string]
    $t = $Tok -replace ',', ''
    if ($t -match '^(\d+)\.(\d+)$') {
        $ip = $Matches[1]; $fp = $Matches[2]
        $alts.Add(([regex]::Escape($ip) + '[.,]' + [regex]::Escape($fp)))
        $wf = @($fp.ToCharArray() | ForEach-Object { ConvertTo-EnglishNumber ([long][string]$_) }) -join ' '
        $alts.Add((ConvertTo-WordRegex ((ConvertTo-EnglishNumber ([long]$ip)) + ' point ' + $wf)))
    }
    elseif ($t -match '^\d+$') {
        $sb = ''
        for ($i = 0; $i -lt $t.Length; $i++) {
            $sb += $t[$i]
            $remaining = $t.Length - $i - 1
            if ($remaining -gt 0 -and ($remaining % 3) -eq 0) { $sb += '[,\s]?' }
        }
        $alts.Add($sb)
        if ($t.Length -le 9) { $alts.Add((ConvertTo-WordRegex (ConvertTo-EnglishNumber ([long]$t)))) }
    }
    else {
        $alts.Add([regex]::Escape($Tok))
    }
    return ('(?<![\d.,])(?:' + ($alts -join '|') + ')(?!\d)')
}

function Get-ValueVariantRegex {
    <#  One regex that matches the value in every spelling this toolchain has
        seen a source use. Returns $null when the value has no tokens.  #>
    param([string] $Value)
    $v = "$Value"
    #  Curly apostrophe and the degree sign are written as \u escapes: this
    #  file is ASCII, and PS 5.1 decodes a BOM-less .ps1 as ANSI.
    $v = [regex]::Replace($v, "(?i)(?:'|\u2019)s\b", '')
    $v = [regex]::Replace($v, '(?i)\b(?:degrees?|deg\.?)\s*(?:c|celsius|centigrade)\b|\u00B0\s*c\b', ' __degc__ ')
    $v = [regex]::Replace($v, '(?i)%|\bper\s*cent\b|\bpercent\b', ' __pct__ ')

    $toks = @([regex]::Matches($v, '\d+(?:[.,]\d+)*|__[a-z]+__|[A-Za-z]+') | ForEach-Object { $_.Value })
    $parts = New-Object System.Collections.Generic.List[string]
    $i = 0
    while ($i -lt $toks.Count) {
        $tok = $toks[$i]
        $low = $tok.ToLowerInvariant()
        $i++
        if ($tok -match '^\d') { $parts.Add((Get-NumberRegex $tok)); continue }
        if ($low -eq '__degc__') { $parts.Add('(?:(?:degrees?|deg\.?|\u00B0)\s*(?:c|celsius|centigrade)\b|\bcelsius\b|\bcentigrade\b|\bdegrees?\b)'); continue }
        if ($low -eq '__pct__')  { $parts.Add('(?:%|\bper\s*cent\b|\bpercent\b|\bpct\b)'); continue }
        if ($script:NumberWords.ContainsKey($low)) {
            $n = [long]$script:NumberWords[$low]
            if ($n -ge 20 -and $i -lt $toks.Count) {
                $nxt = $toks[$i].ToLowerInvariant()
                if ($script:NumberWords.ContainsKey($nxt) -and $script:NumberWords[$nxt] -ge 1 -and $script:NumberWords[$nxt] -le 9) {
                    $n += [long]$script:NumberWords[$nxt]; $i++
                }
            }
            $parts.Add((Get-NumberRegex "$n")); continue
        }
        $fam = $null
        foreach ($f in $script:UnitFamilies) { if ($low -match ('^(?:' + $f + ')$')) { $fam = $f; break } }
        if ($fam) { $parts.Add(('\b(?:' + $fam + ')\b')) }
        else      { $parts.Add(('\b' + [regex]::Escape($low) + '\b')) }
    }
    if ($parts.Count -eq 0) { return $null }
    return ($parts -join '\W*')
}

function Get-FigureCandidates {
    <# Every number-with-unit token in a string: "3840 Gms", "3.6 kg", "75 degrees C", "5 per cent". #>
    param([string] $Text)
    $t = "$Text"
    $t = [regex]::Replace($t, '(?i)\b(?:degrees?|deg\.?)\s*(?:c|celsius|centigrade)\b|\u00B0\s*c\b', ' degrees C ')
    $t = [regex]::Replace($t, '(?i)%|\bper\s*cent\b|\bpercent\b', ' per cent ')
    $rx = '(?i)\d[\d,]*(?:\.\d+)?\s*(?:degrees C|per cent|' + ($script:UnitFamilies -join '|') + ')\b'
    return @([regex]::Matches($t, $rx) | ForEach-Object { ($_.Value -replace '\s+', ' ').Trim() } | Select-Object -Unique)
}

function Get-Snippet {
    param([string] $Text)
    $s = ("$Text" -replace '\s+', ' ').Trim()
    if ($s.Length -gt 180) { return ($s.Substring(0, 177) + '...') }
    return $s
}

# ---------------------------------------------------------------------------
# 2. The search itself - two arms, so a punctuation variant cannot hide a hit
# ---------------------------------------------------------------------------

function New-ArbiterDoc {
    param([string] $Name, [string[]] $Lines, [string[]] $Paths, [string] $Audience = '')
    $norm = New-Object System.Collections.Generic.List[string]
    foreach ($l in @($Lines)) { $norm.Add((ConvertTo-GateNormal $l)) }
    return [pscustomobject]@{ Name = $Name; Audience = $Audience; Lines = @($Lines); Norm = $norm.ToArray(); Paths = $Paths }
}

function Find-ValueInDocs {
    <#  Arm 1: the variant regex. Arm 2: the normalised value as a substring of
        the normalised line. Reports up to -Max hits with doc, line (or spine
        path), arm and text.  #>
    param([string] $Value, $Docs, [int] $Max = 5)
    $hits = New-Object System.Collections.Generic.List[object]
    if (-not "$Value".Trim()) { return $hits }
    $rx = Get-ValueVariantRegex -Value $Value
    $norm = ConvertTo-GateNormal $Value
    foreach ($d in @($Docs)) {
        for ($i = 0; $i -lt $d.Lines.Count; $i++) {
            $line = $d.Lines[$i]
            if (-not $line) { continue }
            $arm = $null
            if ($rx -and [regex]::IsMatch($line, $rx, 'IgnoreCase')) { $arm = 'variant' }
            elseif ($norm -and $norm.Length -ge 3 -and $d.Norm[$i].Contains($norm)) { $arm = 'normalised' }
            if (-not $arm) { continue }
            $where = if ($null -ne $d.Paths) { $d.Paths[$i] } else { "line $($i + 1)" }
            $hits.Add([pscustomobject]@{ Candidate = $Value; Doc = $d.Name; Where = $where; Arm = $arm; Text = (Get-Snippet $line) })
            if ($hits.Count -ge $Max) { return $hits }
        }
    }
    return $hits
}

# ---------------------------------------------------------------------------
# 3. The sources - the whole corpus, the unit extract, anything under -PackDir
# ---------------------------------------------------------------------------

function Get-ArbiterSources {
    param([string] $BuildDir, [string] $CorpusDir, [string] $PackDir)
    $docs = New-Object System.Collections.Generic.List[object]
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $corpusDirResolved = $null
    try { $corpusDirResolved = Get-GateCorpusDir -BuildDir $BuildDir -CorpusDir $CorpusDir }
    catch { if (-not $PackDir) { throw } }

    if ($corpusDirResolved) {
        $corpus = Get-GateCorpusDocs -CorpusDir $corpusDirResolved -BuildDir $BuildDir
        foreach ($d in @($corpus.Documents)) {
            if ($seen.Add($d.Path)) { $docs.Add((New-ArbiterDoc -Name $d.Name -Lines @($d.Text -split "`r?`n") -Audience $d.Audience)) }
        }
    }
    foreach ($dir in @($BuildDir, $corpusDirResolved)) {
        if (-not $dir -or -not (Test-Path -LiteralPath $dir)) { continue }
        foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter 'unit_extract*.md' -File -ErrorAction SilentlyContinue)) {
            if ($seen.Add($f.FullName)) { $docs.Add((New-ArbiterDoc -Name $f.BaseName -Lines @((Get-GateFileText -Path $f.FullName) -split "`r?`n") -Audience 'unit')) }
        }
    }
    if ($PackDir) {
        if (-not (Test-Path -LiteralPath $PackDir)) { throw "$GATE`: -PackDir does not exist: $PackDir" }
        foreach ($f in @(Get-ChildItem -LiteralPath $PackDir -Recurse -File | Where-Object { $_.Extension -in @('.txt', '.md') })) {
            if ($seen.Add($f.FullName)) { $docs.Add((New-ArbiterDoc -Name $f.BaseName -Lines @((Get-GateFileText -Path $f.FullName) -split "`r?`n") -Audience 'pack')) }
        }
    }
    return [pscustomobject]@{ Docs = $docs.ToArray(); CorpusDir = $corpusDirResolved }
}

function Get-ArbiterSpine {
    <#  Every spine file - front matter and cover included, because a wrong
        clause can sit in the further-reading block as easily as in a
        sub-section - as one pseudo-document per file, where each "line" is a
        cell and its anchor is the field path.  #>
    param([string] $BuildDir, [string] $SpineDir)
    $docs = New-Object System.Collections.Generic.List[object]
    $files = @()
    try { $files = @(Get-GateSpineFiles -BuildDir $BuildDir -SpineDir $SpineDir -Exclude @()) } catch { $files = @() }
    foreach ($f in $files) {
        $j = Get-GateJson -Path $f.FullName
        if ($null -eq $j) { continue }
        $cells = @(Get-GateSpineCells -Node $j -File $f.Name)
        $lines = @($cells | ForEach-Object { $_.Text })
        $paths = @($cells | ForEach-Object { $_.Path })
        $doc = New-ArbiterDoc -Name $f.Name -Lines $lines -Paths $paths -Audience 'spine'
        $doc | Add-Member -NotePropertyName Json -NotePropertyValue $j
        $doc | Add-Member -NotePropertyName FullName -NotePropertyValue $f.FullName
        $docs.Add($doc)
    }
    return $docs.ToArray()
}

# ---------------------------------------------------------------------------
# 4. Reading findings - the sidecar, or a markdown report best-effort
# ---------------------------------------------------------------------------

function Get-InferredClass {
    param([string] $Title, [string] $Claim)
    $t = ("$Title $Claim").ToLowerInvariant()
    if ($t -match 'fabricat') { return 'fabricated' }
    if ($t -match 'unsourced|no source|not in the pack|nowhere in the pack|appears nowhere') { return 'unsourced' }
    if ($t -match 'misattribut|false(?:ly)? attribut|wrong(?:ly)? attribut') { return 'misattributed' }
    if ($t -match 'leak|model answer|answer grid|answer set|answers? (?:the|an) assess|open book|assessor[- ]only|marking benchmark|benchmark') { return 'leak' }
    if ($t -match 'wrong clause|clause \d|scope wording|legal (?:scope )?wording|described as applying') { return 'wrong-clause' }
    if ($t -match 'wrong (?:figure|value|number|weight|temperature)|incorrect (?:figure|value)|should read|misstate|off by') { return 'wrong-value' }
    if ($t -match 'not taught|never taught|no teaching|untaught|does not teach|is not covered|not covered anywhere') { return 'not-taught' }
    if ($t -match 'does not exist|no such (?:figure|section|appendix|table)|points at nothing|dangling|refers to a (?:figure|section|appendix) that') { return 'missing-target' }
    return 'unclassified'
}

function Get-ArtefactFromText {
    param([string] $Text)
    $t = "$Text".ToLowerInvariant()
    $a = @()
    if ($t -match 'guide') { $a += 'guide' }
    if ($t -match 'deck|slide') { $a += 'deck' }
    if ($a.Count -eq 0) { return '' }
    return ($a -join '+')
}

function ConvertFrom-AuditMarkdown {
    <#  BEST-EFFORT. Rows shaped | **H-n** | title | risk | claim | where |.
        Class is inferred from the wording; value is the first quoted string in
        the claim, else the first bolded one; later quoted and bolded strings are
        carried as alternates. Every field is a guess the reader must check.  #>
    param([string] $Text)
    $out = New-Object System.Collections.Generic.List[object]
    $seen = @{}
    foreach ($line in @($Text -split "`r?`n")) {
        $m = [regex]::Match($line, '^\|\s*\*\*([A-Z]{1,2}-\d+[a-z]?)\*\*\s*\|(.*)$')
        if (-not $m.Success) { continue }
        $id = $m.Groups[1].Value
        $cells = @($m.Groups[2].Value -split '\|' | ForEach-Object { $_.Trim() })
        if ($cells.Count -ge 2 -and -not $cells[$cells.Count - 1]) { $cells = @($cells[0..($cells.Count - 2)]) }
        $title = ''; $risk = ''; $claim = ''; $where = ''
        if ($cells.Count -ge 4)     { $title = $cells[0]; $risk = $cells[1]; $claim = $cells[2]; $where = $cells[3] }
        elseif ($cells.Count -eq 3) { $risk = $cells[0]; $claim = $cells[1]; $where = $cells[2] }
        elseif ($cells.Count -eq 2) { $claim = $cells[0]; $where = $cells[1] }
        else                        { $claim = ($cells -join ' ') }

        if ($seen.ContainsKey($id)) { $seen[$id]++; $id = ('{0}#{1}' -f $id, $seen[$id]) } else { $seen[$id] = 1 }

        $quoted = @([regex]::Matches($claim, '["\u201C]([^"\u201D]{3,200})["\u201D]') | ForEach-Object { $_.Groups[1].Value })
        $bold   = @([regex]::Matches($claim, '\*\*([^*]{3,160})\*\*') | ForEach-Object { $_.Groups[1].Value })
        $value = ''
        if ($quoted.Count -gt 0) { $value = $quoted[0] } elseif ($bold.Count -gt 0) { $value = $bold[0] }
        $alts = @(@($quoted | Select-Object -Skip 1) + $bold)
        $clean = { param($s) (("$s" -replace '\*\*', '') -replace '`', '').Trim() }
        $value = & $clean $value

        $out.Add([pscustomobject]@{
            id             = $id
            risk           = (& $clean $risk)
            class          = (Get-InferredClass -Title $title -Claim $claim)
            title          = (& $clean $title)
            claim          = (& $clean $claim)
            value          = $value
            alternates     = @($alts | ForEach-Object { & $clean $_ } | Where-Object { $_ -and $_ -ne $value } | Select-Object -Unique)
            where          = [pscustomobject]@{ artefact = (Get-ArtefactFromText $where); locator = (& $clean $where) }
            source         = $null
            proposedForbid = @()
            parsedFrom     = 'markdown best-effort: class inferred from wording, value from the first quoted/bolded string'
        })
    }
    return $out.ToArray()
}

function Read-FindingsFile {
    param([string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "$GATE`: findings file not found: $Path" }
    $text = Get-GateFileText -Path $Path
    if ($Path -match '(?i)\.json$') {
        $j = $text | ConvertFrom-Json
        if ($null -ne $j -and $j -isnot [System.Collections.IEnumerable] -and @($j.PSObject.Properties.Name) -contains 'findings') { $j = $j.findings }
        return [pscustomobject]@{ Findings = @($j | Where-Object { $null -ne $_ }); Mode = 'json' }
    }
    return [pscustomobject]@{ Findings = @(ConvertFrom-AuditMarkdown -Text $text); Mode = 'markdown' }
}

# ---------------------------------------------------------------------------
# 5. Per-class tests
# ---------------------------------------------------------------------------

function Get-ExpectedStrings {
    <# What the finding says the page SHOULD read. Declared field first; then best-effort from the claim. #>
    param($F, [string] $Value)
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($n in @('expected', 'correct', 'shouldBe', 'shouldRead', 'right')) {
        $v = Get-GateProp -Object $F -Names @($n)
        if ($v) { foreach ($x in @($v)) { $out.Add("$x") } }
    }
    $claim = "" + (Get-GateProp -Object $F -Names @('claim') -Default '')
    foreach ($m in [regex]::Matches($claim, '(?i)should (?:read|be|say)\s*["\u201C]([^"\u201D]{2,120})["\u201D]')) { $out.Add($m.Groups[1].Value) }
    foreach ($m in [regex]::Matches($claim, '\*\*([^*]{2,120})\*\*')) { $out.Add($m.Groups[1].Value) }
    $alts = Get-GateProp -Object $F -Names @('alternates')
    if ($alts) { foreach ($a in @($alts)) { $out.Add("$a") } }
    return @($out | ForEach-Object { "$_".Trim() } | Where-Object { $_ -and $_ -ne $Value } | Select-Object -Unique)
}

function Resolve-SubSectionFiles {
    <# The spine files a locator names, by figure slot (1.1.4 -> 1.1), sub-section ref or file name. #>
    param([string] $Locator, $Spine)
    $refs = New-Object System.Collections.Generic.List[string]
    foreach ($m in [regex]::Matches("$Locator", '\b(\d+\.\d+)(?:\.\d+)?\b')) { if (-not $refs.Contains($m.Groups[1].Value)) { $refs.Add($m.Groups[1].Value) } }
    $files = New-Object System.Collections.Generic.List[object]
    foreach ($d in @($Spine)) {
        $ref = "" + (Get-GateProp -Object $d.Json -Names @('ref', 'pc') -Default '')
        $hit = $false
        if ($ref -and $refs.Contains($ref)) { $hit = $true }
        elseif ("$Locator" -match [regex]::Escape($d.Name)) { $hit = $true }
        else { foreach ($r in $refs) { if ($d.Name -match ('_' + [regex]::Escape($r) + '\.json$')) { $hit = $true } } }
        if ($hit) { $files.Add($d) }
    }
    return $files.ToArray()
}

function Invoke-MirrorScoped {
    <# Check-FigureMirror.ps1 over ONE sub-section's spine file(s), in a throwaway spine directory. #>
    param([string] $BuildDir, [string] $CorpusDir, $Files)
    $gate = Join-Path $PSScriptRoot 'Check-FigureMirror.ps1'
    if (-not (Test-Path -LiteralPath $gate)) { return $null }
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('tf_mirror_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        foreach ($f in @($Files)) { Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $tmp $f.Name) }
        $args = @{ BuildDir = $BuildDir; SpineDir = $tmp; Quiet = $true }
        if ($CorpusDir) { $args.CorpusDir = $CorpusDir }
        $text = ''
        $code = 0
        try {
            #  *>&1, not 2>&1: the gate reports through Write-Host, which PS 5.1
            #  puts on the information stream. A 2>&1 capture read an empty
            #  string, counted zero hits, and let the gate's real X lines spill
            #  past this script onto the console - a silent success.
            $text = (& $gate @args *>&1 | Out-String)
            $code = $LASTEXITCODE
        }
        catch { $text = $_.Exception.Message; $code = 2 }
        $count = ([regex]::Matches($text, '(?m)^\s*X ')).Count
        if ($count -eq 0 -and $code -eq 1) { $count = 1 }
        return [pscustomobject]@{ Count = $count; Exit = $code; Files = @($Files | ForEach-Object { $_.Name }); Output = $text }
    }
    finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

function Resolve-SpineTarget {
    <# Figure slots, sub-section refs, appendix letters, then any caption/title/heading cell. #>
    param([string] $Target, $Spine)
    $hits = New-Object System.Collections.Generic.List[object]
    $t = "$Target".Trim()
    if (-not $t) { return $hits }

    if ($t -match '(?i)\bfig(?:ure|\.)?\s*(\d+(?:\.\d+)+)') {
        $slot = $Matches[1]
        foreach ($d in @($Spine)) {
            #  Direct property access: Get-GateProp reads an ARRAY of objects as
            #  empty ("$v" of an Object[] of PSCustomObjects is '' in PS 5.1),
            #  so every visuals list would resolve to nothing.
            $vp = $d.Json.PSObject.Properties['visuals']
            if ($null -eq $vp) { continue }
            foreach ($v in @($vp.Value)) {
                if ($null -eq $v) { continue }
                if ("" + (Get-GateProp -Object $v -Names @('slot', 'figure', 'number')) -eq $slot) {
                    $hits.Add([pscustomobject]@{ Candidate = "Figure $slot"; Doc = $d.Name; Where = "visuals slot $slot"; Arm = 'slot'; Text = (Get-Snippet ("" + (Get-GateProp -Object $v -Names @('caption') -Default ''))) })
                }
            }
        }
    }
    if ($t -match '(?i)\b(?:sub-?section|section|topic|pc|criterion)\s*(\d+(?:\.\d+)*)\b') {
        $ref = $Matches[1]
        foreach ($d in @($Spine)) {
            foreach ($n in @('ref', 'pc', 'number')) {
                $v = Get-GateProp -Object $d.Json -Names @($n)
                if ($null -ne $v -and "$v" -eq $ref) {
                    $hits.Add([pscustomobject]@{ Candidate = $t; Doc = $d.Name; Where = $n; Arm = 'ref'; Text = (Get-Snippet ("" + (Get-GateProp -Object $d.Json -Names @('title') -Default ''))) })
                    break
                }
            }
        }
    }
    if ($t -match '(?i)\bappendix\s*([A-Z0-9])\b') {
        $ap = ConvertTo-GateNormal ('appendix ' + $Matches[1])
        foreach ($d in @($Spine)) {
            for ($i = 0; $i -lt $d.Norm.Count -and $hits.Count -lt $script:MaxHits; $i++) {
                if ([regex]::IsMatch($d.Norm[$i], ('(?<![a-z0-9])' + [regex]::Escape($ap) + '(?![a-z0-9])'))) {
                    $hits.Add([pscustomobject]@{ Candidate = $t; Doc = $d.Name; Where = $d.Paths[$i]; Arm = 'appendix'; Text = (Get-Snippet $d.Lines[$i]) })
                }
            }
        }
    }
    if ($hits.Count -eq 0) {
        $norm = ConvertTo-GateNormal $t
        if ($norm.Length -ge 4) {
            foreach ($d in @($Spine)) {
                for ($i = 0; $i -lt $d.Norm.Count -and $hits.Count -lt $script:MaxHits; $i++) {
                    if ($d.Paths[$i] -notmatch '(?i)(^|\.)(caption|title|heading|name|label)(\[|$)') { continue }
                    if ($d.Norm[$i].Contains($norm)) {
                        $hits.Add([pscustomobject]@{ Candidate = $t; Doc = $d.Name; Where = $d.Paths[$i]; Arm = 'heading'; Text = (Get-Snippet $d.Lines[$i]) })
                    }
                }
            }
        }
    }
    return $hits
}

function Test-OneFinding {
    param($F, $Sources, $Spine, [string] $BuildDir, [string] $CorpusDir)

    $id     = "" + (Get-GateProp -Object $F -Names @('id', 'ref', 'name') -Default '?')
    $class  = ("" + (Get-GateProp -Object $F -Names @('class', 'type', 'kind') -Default '')).Trim().ToLowerInvariant()
    $value  = ("" + (Get-GateProp -Object $F -Names @('value', 'figure', 'string') -Default '')).Trim()
    $claim  = "" + (Get-GateProp -Object $F -Names @('claim', 'finding', 'text') -Default '')
    $where  = Get-GateProp -Object $F -Names @('where')
    $locator = ''
    if ($null -ne $where) {
        if ($where -is [string]) { $locator = $where }
        else { $locator = "" + (Get-GateProp -Object $where -Names @('locator', 'at', 'line') -Default '') }
    }
    $forbidLits = @()
    $pf = Get-GateProp -Object $F -Names @('proposedForbid', 'forbid')
    if ($pf) { $forbidLits = @($pf | ForEach-Object { "$_".Trim() } | Where-Object { $_ }) }

    $r = [ordered]@{
        id = $id
        risk = "" + (Get-GateProp -Object $F -Names @('risk', 'severity') -Default '')
        class = $class
        claim = $claim
        value = $value
        where = $where
        source = (Get-GateProp -Object $F -Names @('source'))
        proposedForbid = $forbidLits
        status = 'UNCHECKED'
        test = ''
        note = ''
        evidence = @()
        forbid = @()
        blocking = $false
    }
    if ($F.PSObject.Properties.Name -contains 'parsedFrom') { $r.parsedFrom = "" + $F.parsedFrom }

    $ev = New-Object System.Collections.Generic.List[object]
    $evSeen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    #  One evidence line per source location: two candidates hitting the same
    #  line ("about 3840 Gms raw" and its own "3840 Gms") are one anchor.
    $addEv = { param($h) if ($evSeen.Add(("{0}|{1}" -f $h.Doc, $h.Where))) { $ev.Add($h) } }

    if ($script:Classes -notcontains $class) {
        $r.note = ("class '{0}' is not in the closed list ({1}); nothing mechanical can be said. Classify it and re-run." -f $class, ($script:Classes -join ' | '))
    }
    elseif ($class -in @('fabricated', 'unsourced', 'misattributed')) {
        $r.test = 'value and every number-with-unit in it, variant-expanded, against every source document'
        $cands = New-Object System.Collections.Generic.List[string]
        if ($value) { $cands.Add($value) }
        foreach ($c in (Get-FigureCandidates -Text $value)) { if (-not $cands.Contains($c)) { $cands.Add($c) } }
        $alts = Get-GateProp -Object $F -Names @('alternates')
        foreach ($a in @($alts)) { if ($a -and -not $cands.Contains("$a")) { $cands.Add("$a") } }
        if ($cands.Count -eq 0) {
            $r.note = 'no value to test - the finding names no figure or string'
        }
        else {
            foreach ($c in $cands) { foreach ($h in (Find-ValueInDocs -Value $c -Docs $Sources.Docs -Max $script:MaxHits)) { & $addEv $h } }
            if ($ev.Count -gt 0) {
                $r.status = 'REFUTED-CANDIDATE'
                $r.note = ("'{0}' occurs in a source the finding says does not carry it. RE-READ the hit line against the finding before any edit." -f $ev[0].Candidate)
            }
            else {
                $r.status = 'UNREFUTED'
                $r.note = ("no variant of {0} candidate string(s) in {1} source document(s). Not a confirmation - the search found nothing against the premise." -f $cands.Count, @($Sources.Docs).Count)
            }
        }
    }
    elseif ($class -in @('wrong-value', 'wrong-clause')) {
        $r.test = 'the string called wrong, against the spine; then the string called right, against the sources'
        if (-not $value) { $r.note = 'no value to test - the finding does not quote the string it calls wrong' }
        elseif (@($Spine).Count -eq 0) { $r.note = 'no spine to test against' }
        else {
            #  @() at every call site: a function returning a List with ONE item
            #  hands back the bare item, whose .Count is null, so "-gt 0" is
            #  false and a single hit vanishes without error.
            $onSpine = @(Find-ValueInDocs -Value $value -Docs $Spine -Max $script:MaxHits)
            if ($onSpine.Count -eq 0) {
                $r.status = 'STALE'
                $r.note = ("'{0}' is not on the spine in any variant. The page already reads otherwise; the finding describes a document that no longer exists (or never did)." -f $value)
            }
            else {
                foreach ($h in $onSpine) { $ev.Add($h) }
                $expected = @(Get-ExpectedStrings -F $F -Value $value)
                if ($expected.Count -eq 0) {
                    $r.status = 'UNREFUTED'
                    $r.note = ("'{0}' is on the spine at {1} {2}; the finding names no replacement string to test." -f $value, $onSpine[0].Doc, $onSpine[0].Where)
                }
                else {
                    $found = New-Object System.Collections.Generic.List[object]
                    foreach ($e in $expected) { foreach ($h in (Find-ValueInDocs -Value $e -Docs $Sources.Docs -Max 2)) { $found.Add($h) } }
                    if ($found.Count -gt 0) {
                        foreach ($h in $found) { $ev.Add($h) }
                        $r.status = 'UNREFUTED'
                        $r.note = ("'{0}' is on the spine at {1} {2}, and the replacement '{3}' occurs in {4}." -f $value, $onSpine[0].Doc, $onSpine[0].Where, $found[0].Candidate, $found[0].Doc)
                    }
                    else {
                        $r.status = 'DOUBTFUL'
                        $r.note = ("'{0}' is on the spine at {1} {2}, but no source carries the replacement the finding proposes ({3}). Check the finding's authority before editing." -f $value, $onSpine[0].Doc, $onSpine[0].Where, ($expected -join ' / '))
                    }
                }
            }
        }
    }
    elseif ($class -eq 'leak') {
        $r.test = 'Check-FigureMirror.ps1 scoped to the named sub-section'
        $files = @(Resolve-SubSectionFiles -Locator ($locator + ' ' + $value) -Spine $Spine)
        if ($files.Count -eq 0) {
            $r.note = ("no sub-section resolvable from the locator '{0}'; name a figure slot (n.n.n), a sub-section ref (n.n) or a spine file" -f $locator)
        }
        else {
            $mir = Invoke-MirrorScoped -BuildDir $BuildDir -CorpusDir $CorpusDir -Files $files
            if ($null -eq $mir) {
                $r.note = 'Check-FigureMirror.ps1 is not beside this script; the mirror count could not be taken'
            }
            else {
                $r.status = 'UNREFUTED'
                $r.mirrorHits = $mir.Count
                $r.mirrorExit = $mir.Exit
                if ($mir.Exit -eq 2) { $r.note = ("mirror gate could not run over {0}: {1}" -f ($mir.Files -join ', '), (Get-Snippet $mir.Output)) }
                elseif ($mir.Count -gt 0) { $r.note = ("mirror gate agrees: {0} grid hit(s) in {1}" -f $mir.Count, ($mir.Files -join ', ')) }
                else { $r.note = ("mirror gate finds 0 grid hits in {0}. A prose leak is outside that gate's sight - read the passage; this is not a clearance." -f ($mir.Files -join ', ')) }
            }
        }
    }
    elseif ($class -eq 'missing-target') {
        $r.test = 'target resolved against spine slots, captions, refs and headings'
        $target = if ($value) { $value } else { $locator }
        $hits = @(Resolve-SpineTarget -Target $target -Spine $Spine)
        if ($hits.Count -gt 0) {
            foreach ($h in $hits) { $ev.Add($h) }
            $r.status = 'REFUTED-CANDIDATE'
            $r.note = ("'{0}' resolves on the spine at {1} {2}. RE-READ before acting." -f $target, $hits[0].Doc, $hits[0].Where)
        }
        else {
            $r.status = 'UNREFUTED'
            $r.note = ("'{0}' resolves to no slot, ref, appendix or heading on the spine" -f $target)
        }
    }
    elseif ($class -eq 'not-taught') {
        $r.test = 'value, variant-expanded, against every spine cell'
        if (-not $value) { $r.note = 'no value to test' }
        else {
            $hits = @(Find-ValueInDocs -Value $value -Docs $Spine -Max $script:MaxHits)
            if ($hits.Count -gt 0) {
                foreach ($h in $hits) { $ev.Add($h) }
                $r.status = 'REFUTED-CANDIDATE'
                $r.note = ("'{0}' is on the spine at {1} {2}. RE-READ: is it taught there, or only mentioned?" -f $value, $hits[0].Doc, $hits[0].Where)
            }
            else {
                $r.status = 'UNREFUTED'
                $r.note = ("no variant of '{0}' on the spine" -f $value)
            }
        }
    }

    # proposedForbid - a build must never forbid a value its own sources carry
    $fv = New-Object System.Collections.Generic.List[object]
    foreach ($lit in $forbidLits) {
        $hits = @(Find-ValueInDocs -Value $lit -Docs $Sources.Docs -Max 2)
        if ($hits.Count -gt 0) {
            $fv.Add([pscustomobject]@{ literal = $lit; verdict = 'FORBID-REJECTED'; doc = $hits[0].Doc; where = $hits[0].Where; text = $hits[0].Text })
        }
        else {
            $fv.Add([pscustomobject]@{ literal = $lit; verdict = 'forbid-ok'; doc = ''; where = ''; text = '' })
        }
    }
    $r.forbid = $fv.ToArray()
    $r.evidence = $ev.ToArray()
    $rejected = @($fv | Where-Object { $_.verdict -eq 'FORBID-REJECTED' })
    $r.blocking = ($script:Blocking -contains $r.status) -or ($rejected.Count -gt 0)
    return [pscustomobject]$r
}

# ---------------------------------------------------------------------------
# 6. Reporting
# ---------------------------------------------------------------------------

function Write-ArbiterTable {
    param($Results, [string] $Mode)
    Write-Host ''
    Write-Host ("  {0,-8} {1,-6} {2,-14} {3,-18} {4}" -f 'ID', 'RISK', 'CLASS', 'STATUS', 'ANCHOR / NOTE') -ForegroundColor DarkGray
    foreach ($r in @($Results)) {
        $col = 'Gray'
        switch ($r.status) {
            'REFUTED-CANDIDATE' { $col = 'Red' }
            'STALE'             { $col = 'Red' }
            'DOUBTFUL'          { $col = 'Yellow' }
            'UNREFUTED'         { $col = 'White' }
            'UNCHECKED'         { $col = 'DarkGray' }
        }
        $anchor = ''
        if (@($r.evidence).Count -gt 0) {
            $e = @($r.evidence)[0]
            $anchor = ("{0}:{1} [{2}] {3}" -f $e.Doc, $e.Where, $e.Arm, $e.Text)
        }
        else { $anchor = $r.note }
        $risk = "$($r.risk)"
        if ($risk.Length -gt 6) { $risk = $risk.Substring(0, 6) }
        Write-Host ("  {0,-8} {1,-6} {2,-14} {3,-18} {4}" -f $r.id, $risk, $r.class, $r.status, $anchor) -ForegroundColor $col
        if (@($r.evidence).Count -gt 1) {
            foreach ($e in @(@($r.evidence) | Select-Object -Skip 1 -First 4)) {
                Write-Host ("  {0,-49} {1}:{2} [{3}] {4}" -f '', $e.Doc, $e.Where, $e.Arm, $e.Text) -ForegroundColor DarkGray
            }
        }
        if (@($r.evidence).Count -gt 0 -and $r.note) {
            Write-Host ("  {0,-49} {1}" -f '', $r.note) -ForegroundColor DarkGray
        }
        foreach ($fb in @($r.forbid)) {
            if ($fb.verdict -eq 'FORBID-REJECTED') {
                Write-Host ("  {0,-49} X FORBID-REJECTED '{1}' - carried by {2}:{3} {4}" -f '', $fb.literal, $fb.doc, $fb.where, $fb.text) -ForegroundColor Red
            }
            else {
                Write-Host ("  {0,-49} forbid '{1}': in no source" -f '', $fb.literal) -ForegroundColor DarkGray
            }
        }
    }
}

function Invoke-Arbitration {
    param($FindingList, [string] $BuildDir, [string] $CorpusDir, [string] $SpineDir, [string] $PackDir, [switch] $Quiet, [string] $Mode = 'json')

    $sources = Get-ArbiterSources -BuildDir $BuildDir -CorpusDir $CorpusDir -PackDir $PackDir
    $spine = @(Get-ArbiterSpine -BuildDir $BuildDir -SpineDir $SpineDir)

    if (-not $Quiet) {
        Write-Host ''
        Write-Host 'FINDING ARBITRATION - test the premise before the work order' -ForegroundColor Cyan
        Write-Host '  The arbiter never clears a finding. It demotes a finding to needs-re-read and prints the line.' -ForegroundColor DarkGray
        Write-GateCheckSet -What 'source document(s)' -Count @($sources.Docs).Count -DerivedFrom (('the canonical corpus' + $(if ($sources.CorpusDir) { " at " + (Split-Path $sources.CorpusDir -Leaf) } else { '' })) + ', unit_extract*.md' + $(if ($PackDir) { ', and -PackDir' } else { '' }))
        foreach ($d in @($sources.Docs)) { Write-Host ("    {0,-9} {1} ({2} lines)" -f $d.Audience, $d.Name, $d.Lines.Count) -ForegroundColor DarkGray }
        Write-GateCheckSet -What 'spine file(s)' -Count $spine.Count -DerivedFrom 'the build spine directory, front matter included'
        if ($Mode -eq 'markdown') {
            Write-Host ''
            Write-Host '  ! MARKDOWN INPUT - BEST-EFFORT PARSE. Class and value below are INFERRED from prose.' -ForegroundColor Yellow
            Write-Host '    Check the CLASS and the quoted value on every row before believing its status.' -ForegroundColor Yellow
            Write-Host '    Write a findings.json sidecar for anything that matters.' -ForegroundColor Yellow
        }
    }
    if (@($sources.Docs).Count -eq 0) {
        throw "$GATE`: no source documents. A finding cannot be arbitrated against nothing."
    }

    $results = New-Object System.Collections.Generic.List[object]
    foreach ($f in @($FindingList)) {
        if ($null -eq $f) { continue }
        $results.Add((Test-OneFinding -F $f -Sources $sources -Spine $spine -BuildDir $BuildDir -CorpusDir $sources.CorpusDir))
    }
    return [pscustomobject]@{ Results = $results.ToArray(); Sources = @($sources.Docs | ForEach-Object { $_.Name }); SpineFiles = $spine.Count }
}

function Write-ArbiterJson {
    param($Run, [string] $Path, [string] $Input, [string] $Mode)
    $out = [ordered]@{
        arbiter = [ordered]@{
            script     = $GATE
            ranAt      = (Get-Date -Format 'o')
            input      = $Input
            mode       = $Mode
            sources    = @($Run.Sources)
            spineFiles = $Run.SpineFiles
            rule       = 'The arbiter never clears a finding. REFUTED-CANDIDATE, STALE and FORBID-REJECTED mean re-read the hit line before any edit; UNREFUTED means the search found nothing against the premise, not that the finding is confirmed.'
        }
        findings = @($Run.Results)
    }
    $json = $out | ConvertTo-Json -Depth 14
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

# ---------------------------------------------------------------------------
# 7. Self-test - the two historic false findings and one true one
# ---------------------------------------------------------------------------

function New-SelfTestFixture {
    <#  A throwaway build carrying the two historic false-finding premises: a
        recipe line that DOES state a raw batch weight, and a spine that ALREADY
        reads "less than two years". The plant is read back before the test.  #>
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('tf_selftest_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path (Join-Path $root 'corpus') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $root 'spine') | Out-Null
    $card = @(
        'Recipe card. Chickpea and potato curry.',
        '350 Gms of curry per portion, packed 10 portions to a 3.5 L bucket. The batch weighs about 3840 Gms raw and finishes at about 3.6 kg, so the bucket fills with a working margin.',
        'Standard 1.2.5 of the same Code sets the date marking rules for use-by and best-before dates.'
    )
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText((Join-Path $root 'corpus\Recipe_Workbook.txt'), ($card -join "`r`n"), $enc)
    [System.IO.File]::WriteAllText((Join-Path $root 'corpus\Assessor_Guide_Recipe_Workbook.txt'), (($card + @('Benchmark: the batch weight is read from the card.')) -join "`r`n"), $enc)
    $spine = [ordered]@{
        ref = '1.3'; pc = '1.3'; topic = 1; title = 'Date marking and rotation'
        underpinningKnowledge = @('A packaged food with a shelf life of less than two years must carry a use-by date where one is needed for health or safety reasons, and a best-before date otherwise.')
        visuals = @([ordered]@{ slot = '1.3.1'; kind = 'Image'; prompt = 'Close view of gloved hands turning a labelled container.'; caption = 'Reading the date mark' })
    }
    [System.IO.File]::WriteAllText((Join-Path $root 'spine\t1_1.3.json'), ($spine | ConvertTo-Json -Depth 6), $enc)
    return $root
}

function Get-SelfTestFindings {
    return @(
        [pscustomobject]@{
            id = 'H-3'; risk = 'High'; class = 'fabricated'
            claim = 'The guide asserts "The card states the batch weighs about 3840 Gms raw". The recipe card carries no raw batch weight; it states only "reduces to about 3.6 kg".'
            value = 'about 3840 Gms raw'
            where = [pscustomobject]@{ artefact = 'guide'; locator = 'Figure 3.4.4' }
            source = [pscustomobject]@{ doc = 'recipe card'; locator = 'method step 4' }
            proposedForbid = @('3840 Gms', '3648 Gms')
        },
        [pscustomobject]@{
            id = 'L-1'; risk = 'Low'; class = 'wrong-clause'
            claim = 'Standard 1.2.5 is described as applying to food with a shelf life of "two years or less"; the requirement bites on less than two years.'
            value = 'two years or less'
            expected = 'less than two years'
            where = [pscustomobject]@{ artefact = 'guide'; locator = 'l.1245' }
            source = $null
            proposedForbid = @()
        },
        [pscustomobject]@{
            id = 'T-1'; risk = 'High'; class = 'fabricated'
            claim = 'The guide asserts the batch weighs about 9137 Gms raw; no source carries that figure.'
            value = 'about 9137 Gms raw'
            where = [pscustomobject]@{ artefact = 'guide'; locator = 'l.2836' }
            source = [pscustomobject]@{ doc = 'recipe card'; locator = $null }
            proposedForbid = @('9137')
        },
        [pscustomobject]@{
            id = 'M-T'; risk = 'Medium'; class = 'missing-target'
            claim = 'Section 1.3 cross-refers to Figure 1.3.1, which does not exist.'
            value = 'Figure 1.3.1'
            where = [pscustomobject]@{ artefact = 'guide'; locator = 'section 1.3' }
            source = $null
            proposedForbid = @()
        }
    )
}

function Invoke-SelfTest {
    param([string] $RealBuildDir, [string] $CorpusDir, [string] $SpineDir, [string] $PackDir)
    $pass = 0; $fail = 0
    $ok  = { param($m) $script:stPass++; Write-Host "  PASS  $m" -ForegroundColor Green }
    $bad = { param($m) $script:stFail++; Write-Host "  FAIL  $m" -ForegroundColor Red }
    $script:stPass = 0; $script:stFail = 0

    Write-Host ''
    Write-Host "$GATE self-test" -ForegroundColor Cyan

    $expect = @{ 'H-3' = 'REFUTED-CANDIDATE'; 'L-1' = 'STALE'; 'T-1' = 'UNREFUTED'; 'M-T' = 'REFUTED-CANDIDATE' }
    $findings = Get-SelfTestFindings

    $targets = New-Object System.Collections.Generic.List[object]
    $fixture = New-SelfTestFixture
    try {
        # the plant must be verified to have landed before the gate is believed
        $corpusText = Get-GateFileText -Path (Join-Path $fixture 'corpus\Recipe_Workbook.txt')
        $spineText  = Get-GateFileText -Path (Join-Path $fixture 'spine\t1_1.3.json')
        if ($corpusText -match '3840 Gms') { & $ok 'fixture plant landed: the corpus states the raw batch weight' } else { & $bad 'fixture plant did NOT land in the corpus' }
        if ($spineText -match 'less than two years' -and $spineText -notmatch 'two years or less') { & $ok 'fixture plant landed: the spine already reads "less than two years"' } else { & $bad 'fixture plant did NOT land on the spine' }
        $targets.Add([pscustomobject]@{ Name = 'synthetic fixture'; BuildDir = $fixture; CorpusDir = ''; SpineDir = ''; PackDir = '' })
        if ($RealBuildDir) { $targets.Add([pscustomobject]@{ Name = 'reference build ' + (Split-Path $RealBuildDir -Leaf); BuildDir = $RealBuildDir; CorpusDir = $CorpusDir; SpineDir = $SpineDir; PackDir = $PackDir }) }

        foreach ($t in $targets) {
            Write-Host ("  against the {0}" -f $t.Name) -ForegroundColor Cyan
            $run = Invoke-Arbitration -FindingList $findings -BuildDir $t.BuildDir -CorpusDir $t.CorpusDir -SpineDir $t.SpineDir -PackDir $t.PackDir -Quiet
            Write-ArbiterTable -Results $run.Results -Mode 'json'
            foreach ($r in $run.Results) {
                $want = $expect[$r.id]
                if ($r.status -eq $want) { & $ok ("{0} -> {1}" -f $r.id, $want) } else { & $bad ("{0} -> {1}, wanted {2}: {3}" -f $r.id, $r.status, $want, $r.note) }
            }
            $h3 = @($run.Results | Where-Object { $_.id -eq 'H-3' })[0]
            $rej = @($h3.forbid | Where-Object { $_.verdict -eq 'FORBID-REJECTED' } | ForEach-Object { $_.literal })
            if ($rej -contains '3840 Gms') { & $ok "H-3 proposedForbid '3840 Gms' is FORBID-REJECTED (a source carries it)" } else { & $bad "H-3 proposedForbid '3840 Gms' was not rejected" }
            if ($rej -notcontains '3648 Gms') { & $ok "H-3 proposedForbid '3648 Gms' is not rejected (no source carries it)" } else { & $bad "H-3 proposedForbid '3648 Gms' was rejected but no source carries it" }
            $blocking = @($run.Results | Where-Object { $_.blocking }).Count
            if ($blocking -eq 3) { & $ok 'three findings block the round (H-3, L-1, M-T); T-1 does not' } else { & $bad ("{0} finding(s) block, wanted 3" -f $blocking) }
        }
    }
    finally { Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue }

    Write-Host ''
    Write-Host ("  self-test: {0} passed, {1} failed" -f $script:stPass, $script:stFail) -ForegroundColor $(if ($script:stFail) { 'Red' } else { 'Green' })
    return $script:stFail
}

# ---------------------------------------------------------------------------
# Entry
# ---------------------------------------------------------------------------

if ($SelfTest) {
    $failed = Invoke-SelfTest -RealBuildDir $BuildDir -CorpusDir $CorpusDir -SpineDir $SpineDir -PackDir $PackDir
    if ($failed -gt 0) { exit 4 }
    exit 0
}

if (-not $Findings -or -not $BuildDir) {
    Write-Host "  X $GATE`: -Findings <findings.json | audit.md> and -BuildDir <build> are both required." -ForegroundColor Red
    exit 2
}
if (-not (Test-Path -LiteralPath $BuildDir)) {
    Write-Host "  X $GATE`: -BuildDir does not exist: $BuildDir" -ForegroundColor Red
    exit 2
}

$read = Read-FindingsFile -Path $Findings
if (@($read.Findings).Count -eq 0) {
    Write-Host ("  X {0}: no findings could be read from {1}{2}" -f $GATE, $Findings, $(if ($read.Mode -eq 'markdown') { ' (looked for rows shaped | **H-n** | ... |)' } else { '' })) -ForegroundColor Red
    exit 2
}

$run = Invoke-Arbitration -FindingList $read.Findings -BuildDir $BuildDir -CorpusDir $CorpusDir -SpineDir $SpineDir -PackDir $PackDir -Quiet:$Quiet -Mode $read.Mode
Write-ArbiterTable -Results $run.Results -Mode $read.Mode

if (-not $OutPath) { $OutPath = Join-Path (Split-Path -Parent (Resolve-Path -LiteralPath $Findings).Path) 'findings_arbitrated.json' }
Write-ArbiterJson -Run $run -Path $OutPath -Input (Resolve-Path -LiteralPath $Findings).Path -Mode $read.Mode

$byStatus = @($run.Results | Group-Object status | ForEach-Object { '{0} {1}' -f $_.Count, $_.Name })
$blocking = @($run.Results | Where-Object { $_.blocking })
Write-Host ''
Write-Host ("  {0} finding(s): {1}" -f @($run.Results).Count, ($byStatus -join ', ')) -ForegroundColor DarkGray
Write-Host ("  written: {0}" -f $OutPath) -ForegroundColor DarkGray
if ($blocking.Count -gt 0) {
    Write-Host ("  X {0} finding(s) must be RE-READ against the printed line before this round can start: {1}" -f $blocking.Count, (($blocking | ForEach-Object { $_.id }) -join ', ')) -ForegroundColor Red
    Write-Host '  The arbiter has not cleared them and has not condemned them. Read the source line, decide, record the reason at 6b.' -ForegroundColor Yellow
    exit 1
}
Write-Host '  nothing demoted. Every finding stands as raised; none is confirmed by this script.' -ForegroundColor Green
exit 0
