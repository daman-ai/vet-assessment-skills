<#
    Assert-IdentifierNamespace.ps1 - the identifiers the GUIDE invents must not
    collide with the identifiers the PACK already owns, and every internal
    cross-reference must resolve to exactly one target.

    Implements references\gates.md section 28. Runs at Stage 2 for the namespace
    assertion, and at Stage 3c and Stage 4 for dangling-reference resolution.

        scripts\Assert-IdentifierNamespace.ps1 -BuildDir $out

    WHY IT EXISTS. A guide "Task 4" that is not the pack's Task 4 sends a
    learner to the wrong document, and it does it silently: the reference is
    well-formed, it resolves, and it resolves into the wrong namespace. Two
    measured failures:

      1. One guide's appendix letters collided with the pack's across 151
         references. The renumbering that followed left a stale reference
         pointing at nothing, which was found a round later.
      2. An auditor reported a whole section as non-existent and the false
         finding had to be refuted by hand search. Supplying the RESOLVED
         CROSS-REFERENCE INDEX to the audit pre-refutes that direction, which
         is why this gate writes the whole index into its report whether it
         blocks or not.

    THE TWO NAMESPACES ARE DERIVED, NEVER TYPED.

      PACK-OWNED   the contract's referenceConvention patterns and the withhold
                   register's documents[].referencePattern give the LABELS; the
                   contract's questionMap, the register's own task and
                   observation references and the assessor-cells grid
                   references give the VALUES each label occupies; the
                   register's vocabulary gives the pack's document identifiers
                   (appendix letters and the like) and its recipe codes.
      GUIDE-INVENTED   the caption prefix the docx-images config declares plus
                   every visual `slot` on the spine gives the figure numbering;
                   the contract's topics give the topic and sub-section
                   numbering; and any spine string shaped like a DEFINITION -
                   a label, an ordinal and a separator, at the head of the
                   string - gives everything else the guide names for itself.

    A SHARED BARE LABEL IS DERIVED TOO. Where two pack schemes end in the same
    word - "Knowledge Task" and "Workbook Task" both end in "Task" - that word
    is AMBIGUOUS and the qualifiers are the words in front of it. Nothing here
    types "Task"; the ambiguity falls out of the label set.

    THE NAMED RULES.

      NS-COLLISION        blocking. A guide-invented identifier whose label is a
                          pack label and whose value the pack already occupies.
                          Set intersection over the two schemes - no allow-list,
                          no judgement.
      NS-BARE-REFERENCE   blocking. A cross-reference using an ambiguous bare
                          label with none of its qualifiers in front of it. This
                          is the "Task 5" defect, and the contract's own
                          referenceConvention says in writing why it is one.
      NS-XREF-DANGLING    blocking. A reference into a declared scheme at a
                          value that scheme does not occupy.
      NS-XREF-AMBIGUOUS   blocking. A reference whose label is owned by more
                          than one scheme AND whose value both of them occupy,
                          so it resolves two ways.
      NS-INDEX            REPORT. The whole resolved index - every reference,
                          the namespace it resolved into, the target and the
                          anchor - written to the report as audit evidence, in
                          BOTH directions: guide identifiers referenced by the
                          build, and pack identifiers referenced by the build.

    FALSE-POSITIVE CONTROL is the one section 28 specifies - set intersection
    over identifier schemes, and reference resolution against a target list -
    plus four NAMED narrowings, every one of them found by running this gate on
    a real build, and every one printing its suppression count:

      by VALUE, not by label   two schemes sharing a label but no value resolve
                          without ambiguity. The reference build numbers its own
                          appendices 1 to 7 precisely so they cannot be confused
                          with the pack's Appendix A and B, and says so in its
                          own front matter; a label-only test called all seven
                          of them ambiguous.
      NAMING FIELDS ONLY  a definition-shaped string counts as a DEFINITION only
                          where it sits in a field whose job is to name
                          something. A slide bullet "Observation 7: the assessor
                          watches you pre-chill" has the shape and is a signpost
                          to the pack's own item; read as a definition it
                          produced a false collision AND a phantom guide scheme
                          that then made all fifteen real Observation references
                          ambiguous.
      MENTIONED           a bare reference inside quotation marks is being
                          mentioned rather than used - which is what the guide's
                          own orientation slide does when it warns the room that
                          'Task 5' on its own is ambiguous.
      QUALIFIED NEARBY /  the same label at the same value is qualified
      CONVENTION CHANNEL  elsewhere in the same string, so the reader has the
                          qualifier in front of them; or the string sits in the
                          guide's own written statement of the convention, whose
                          channel name is READ off the contract.

    Where a scheme's value set cannot be derived, this gate says so and does NOT
    resolve against it, because resolving against an empty target list would
    report every correct reference as dangling. Findings are keyed per LOCATION
    rather than per identifier, so the fix is enumerated and not sampled.

    NEVER PRINTS A MODEL ANSWER OR A BENCHMARK ROW. Labels, ordinals, file
    names and paths only.

    PROVED BY PLANTING. -SelfTest builds a synthetic build directory, plants
    four defects, VERIFIES EACH PLANT LANDED by reading the file back out of
    the exact channel the gate scans, and fails if any planted defect is not
    caught or if the clean fixture fires.

    PS 5.1. ASCII only in this file.
    Exit 0 clean, 1 blocking finding(s), 2 usage or input error, 4 self-test failed.
#>

[CmdletBinding()]
param(
    [string] $BuildDir,
    [string] $SpineDir,
    [string] $ContractPath,
    #  The withhold register - pack reference patterns, task and observation
    #  references and the pack's own document vocabulary.
    [string] $RegisterPath,
    #  assessor-cells.json - the grid references, used for VALUES only.
    [string] $AssessorCellsPath,
    #  The docx-images sub-skill config, for the declared caption prefix.
    [string] $ImagesConfig,
    [string] $SkillDir,
    [string] $ReportPath,
    [switch] $SelfTest,
    [switch] $Quiet
)

#  $PSScriptRoot is EMPTY inside a PARAMETER DEFAULT when the script is run as
#  `powershell -File`, so a default that called Split-Path on it threw inside
#  the parameter block: the script exited 1 having never run a single check -
#  the same exit code it uses for a real finding, which is why nobody noticed.
#  Resolved here instead, where the automatic variable is populated, with a
#  guarded fallback for the scriptblock case.
if (-not $SkillDir) {
    $__here = $PSScriptRoot
    if (-not $__here -and $MyInvocation.MyCommand.Path) { $__here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if ($__here) { $SkillDir = Split-Path -Parent $__here }
}

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

$GATE = 'Assert-IdentifierNamespace'

# ---------------------------------------------------------------------------
# Private helpers, named Ns* so nothing here can shadow a shared one
# ---------------------------------------------------------------------------

function Get-NsArray {
    <# @($null).Count is 1, not 0. #>
    param($Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) { return @($Value) }
    if ($Value -is [System.Collections.IEnumerable]) {
        $acc = New-Object System.Collections.Generic.List[object]
        foreach ($v in $Value) { if ($null -ne $v) { $acc.Add($v) } }
        return $acc.ToArray()
    }
    return @($Value)
}

function Write-NsJson {
    param([Parameter(Mandatory)] $Object, [Parameter(Mandatory)][string] $Path)
    $json = $Object | ConvertTo-Json -Depth 14
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($true)))
}

function Get-NsCaptionPrefix {
    <#  The label the guide gives its own figures. DECLARED by the docx-images
        sub-skill config as placement.captionPrefix, because that is the string
        the placement pass actually writes onto the page. Falls back to nothing
        rather than to a typed word: a gate that invents the label it checks
        would be checking its own invention.  #>
    param([string] $Given, [string] $Skill)
    $path = ''
    if ($Given -and (Test-Path -LiteralPath $Given)) { $path = (Resolve-Path -LiteralPath $Given).Path }
    else {
        $root = Split-Path -Parent $Skill
        foreach ($c in @((Join-Path $root 'docx-images\config\defaults.json'), (Join-Path $Skill 'config\defaults.json'))) {
            if (Test-Path -LiteralPath $c) { $path = (Resolve-Path -LiteralPath $c).Path; break }
        }
    }
    if (-not $path) { return [pscustomobject]@{ Prefix = ''; Path = '' } }
    $cfg = Get-GateJson -Path $path
    $place = Get-GateProp -Object $cfg -Names @('placement')
    $p = ('' + (Get-GateProp -Object $place -Names @('captionPrefix') -Default '')).Trim()
    return [pscustomobject]@{ Prefix = $p; Path = $path }
}

# ---------------------------------------------------------------------------
# Scheme construction
# ---------------------------------------------------------------------------

function New-NsScheme {
    param([string] $Label, [string] $Owner, [string] $Source)
    return [pscustomobject]@{
        Label   = $Label
        Owner   = $Owner              # 'pack' or 'guide'
        Values  = (New-Object System.Collections.Generic.HashSet[string])
        Sources = (New-Object System.Collections.Generic.List[string])
        Anchors = @{}                 # value -> where it was defined
    }
}

function Add-NsValue {
    param($Scheme, [string] $Value, [string] $Where)
    if (-not $Value) { return }
    [void]$Scheme.Values.Add($Value)
    if ($Where -and -not $Scheme.Anchors.ContainsKey($Value)) { $Scheme.Anchors[$Value] = $Where }
}

function Get-NsLabelFromPattern {
    <#  'Knowledge Task {n}({part})' -> 'Knowledge Task'. The label is whatever
        stands in front of the first placeholder, trimmed of punctuation.

        A PATTERN AND A SENTENCE ABOUT A PATTERN ARE NOT THE SAME FIELD, and
        this gate's first run on the reference build proved it. Beside every
        real pattern the contract carries a prose gloss - "Task {n} in
        <file>.docx", "Observation checklist {n} in the Recipe Workbook
        assessor guide, completed by ..." - and reading those as patterns
        invented two pack schemes that own nothing: a bare "Task" scheme and an
        "Observation checklist" scheme, each with an empty value set. The
        discriminator is structural, not a field-name list: a REFERENCE PATTERN
        ends at its placeholders, so anything after the last '}' must be
        punctuation. A gloss runs on into a sentence and is rejected.  #>
    param([string] $Pattern)
    if (-not $Pattern) { return '' }
    $i = $Pattern.IndexOf('{')
    if ($i -lt 0) { return '' }
    $j = $Pattern.LastIndexOf('}')
    if ($j -ge 0) {
        $tail = $Pattern.Substring($j + 1)
        if ($tail -match '[A-Za-z]' -or $tail.Length -gt 3) { return '' }
    }
    $head = $Pattern.Substring(0, $i)
    return ((($head -replace '[^A-Za-z ]', ' ').Trim()) -replace '\s+', ' ')
}

function Get-NsPackSchemes {
    <#  Every identifier scheme the SOURCE PACK owns, with the values it
        occupies. Labels from the declared reference patterns; values from the
        contract's questionMap, the register's own references and the assessor
        cells' grid references; document identifiers and recipe codes from the
        register's vocabulary.  #>
    param($Contract, $Register, $Cells)

    $schemes = @{}
    $add = {
        param([string] $lab, [string] $src)
        $k = $lab.ToLowerInvariant()
        if (-not $schemes.ContainsKey($k)) { $schemes[$k] = New-NsScheme -Label $lab -Owner 'pack' -Source $src }
        if (-not $schemes[$k].Sources.Contains($src)) { $schemes[$k].Sources.Add($src) }
        return $schemes[$k]
    }

    # ---- labels from the declared reference patterns
    $rc = Get-GateProp -Object $Contract -Names @('referenceConvention')
    if ($null -ne $rc) {
        foreach ($p in @($rc.PSObject.Properties.Name)) {
            if ($p -like '_*') { continue }
            $v = '' + $rc.$p
            if ($v -notmatch '\{') { continue }
            $lab = Get-NsLabelFromPattern -Pattern $v
            if ($lab) { [void](& $add $lab 'contract referenceConvention') }
        }
    }
    $docs = Get-GateProp -Object $Register -Names @('documents')
    if ($null -ne $docs) {
        foreach ($d in @($docs.PSObject.Properties.Name)) {
            $lab = Get-NsLabelFromPattern -Pattern ('' + (Get-GateProp -Object $docs.$d -Names @('referencePattern') -Default ''))
            if ($lab) { [void](& $add $lab 'withhold-register documents[].referencePattern') }
        }
    }

    # ---- values, from every place the pack's own references are enumerated
    $refTexts = New-Object System.Collections.Generic.List[object]
    $qm = Get-GateProp -Object $Contract -Names @('questionMap')
    if ($null -ne $qm) {
        foreach ($p in @($qm.PSObject.Properties.Name)) {
            if ($p -like '_*') { continue }
            foreach ($r in (Get-NsArray $qm.$p)) { $refTexts.Add([pscustomobject]@{ Text = "$r"; Where = 'contract questionMap' }) }
        }
    }
    $subs = Get-GateProp -Object $Register -Names @('subSections')
    if ($null -ne $subs) {
        foreach ($rn in @($subs.PSObject.Properties.Name)) {
            if ($rn -like '_*') { continue }
            $ss = $subs.$rn
            foreach ($r in (Get-NsArray (Get-GateProp -Object $ss -Names @('refs')))) { $refTexts.Add([pscustomobject]@{ Text = "$r"; Where = 'withhold-register refs' }) }
            foreach ($t in (Get-NsArray (Get-GateProp -Object $ss -Names @('tasks')))) {
                $refTexts.Add([pscustomobject]@{ Text = ('' + (Get-GateProp -Object $t -Names @('ref') -Default '')); Where = 'withhold-register tasks[].ref' })
            }
            foreach ($o in (Get-NsArray (Get-GateProp -Object $ss -Names @('observations')))) {
                $refTexts.Add([pscustomobject]@{ Text = ('' + (Get-GateProp -Object $o -Names @('ref') -Default '')); Where = 'withhold-register observations[].ref' })
            }
        }
    }
    foreach ($g in (Get-NsArray (Get-GateProp -Object $Cells -Names @('grids')))) {
        $refTexts.Add([pscustomobject]@{ Text = ('' + (Get-GateProp -Object $g -Names @('ref') -Default '')); Where = 'assessor-cells grids[].ref' })
    }

    #  Match each enumerated reference against the LONGEST label that starts it,
    #  so "Workbook Task 2(a)" lands in the Workbook Task scheme and not in a
    #  shorter one that happens to overlap.
    $labelsByLength = @($schemes.Keys | Sort-Object { $schemes[$_].Label.Length } -Descending)
    foreach ($rt in $refTexts) {
        $s = ('' + $rt.Text).Trim()
        if (-not $s) { continue }
        foreach ($k in $labelsByLength) {
            $lab = $schemes[$k].Label
            if ($s.Length -le $lab.Length) { continue }
            if ($s.Substring(0, $lab.Length) -ine $lab) { continue }
            $rest = $s.Substring($lab.Length).Trim()
            if ($rest -match '^(\d+(?:\.\d+)*)') { Add-NsValue -Scheme $schemes[$k] -Value $Matches[1] -Where $rt.Where }
            break
        }
    }

    # ---- the pack's own document identifiers, from the register vocabulary
    $vocab = Get-GateProp -Object $Register -Names @('vocabulary')
    foreach ($d in (Get-NsArray (Get-GateProp -Object $vocab -Names @('document')))) {
        foreach ($m in [regex]::Matches("$d", '\b(?<lab>[A-Z][a-z]{2,})\s+(?<val>[A-Z]\b|\d+(?:\.\d+)*)')) {
            $sc = & $add $m.Groups['lab'].Value 'withhold-register vocabulary.document'
            Add-NsValue -Scheme $sc -Value $m.Groups['val'].Value -Where 'withhold-register vocabulary.document'
        }
    }
    #  Recipe codes are a bare-numeric namespace of their own. Kept for the
    #  report; no label precedes them, so no reference can resolve into them by
    #  label and nothing blocks on them.
    $recipeCodes = New-Object System.Collections.Generic.List[string]
    foreach ($r in (Get-NsArray (Get-GateProp -Object $vocab -Names @('recipe')))) {
        foreach ($m in [regex]::Matches("$r", '\b(\d{3,5})\b')) { if (-not $recipeCodes.Contains($m.Groups[1].Value)) { $recipeCodes.Add($m.Groups[1].Value) } }
    }

    return [pscustomobject]@{ Schemes = $schemes; RecipeCodes = $recipeCodes.ToArray() }
}

function Get-NsAmbiguousBare {
    <#  Where two or more pack labels end in the same word, that word is an
        AMBIGUOUS BARE LABEL and the words in front of it are its qualifiers.
        Derived from the label set; nothing is typed.  #>
    param($Schemes)
    $byTail = @{}
    foreach ($k in $Schemes.Keys) {
        $lab = $Schemes[$k].Label
        $parts = @($lab -split '\s+' | Where-Object { $_ })
        if ($parts.Count -lt 2) { continue }
        $tail = $parts[-1]
        $qual = ($parts[0..($parts.Count - 2)] -join ' ')
        $tk = $tail.ToLowerInvariant()
        if (-not $byTail.ContainsKey($tk)) { $byTail[$tk] = [pscustomobject]@{ Tail = $tail; Qualifiers = (New-Object System.Collections.Generic.List[string]); Owners = (New-Object System.Collections.Generic.List[string]) } }
        if (-not $byTail[$tk].Qualifiers.Contains($qual)) { $byTail[$tk].Qualifiers.Add($qual) }
        if (-not $byTail[$tk].Owners.Contains($lab)) { $byTail[$tk].Owners.Add($lab) }
    }
    $out = @{}
    foreach ($k in $byTail.Keys) { if ($byTail[$k].Owners.Count -ge 2) { $out[$k] = $byTail[$k] } }
    return $out
}

# ---------------------------------------------------------------------------
# The spine, split by surface, and the guide's own definitions
# ---------------------------------------------------------------------------

function Get-NsCells {
    <#  Every string on the spine, tagged guide-facing or deck-facing by the
        same derived rule the parity gate uses: a node carrying a `layout` is a
        slide, unless it sits under `visuals` or a `spec`, where `layout` names
        a diagram renderer instead.  #>
    param($Node, [string] $File = '', [string] $Path = '', [string] $Surface = 'guide', [switch] $InVisual, [int] $Depth = 0)

    if ($null -eq $Node -or $Depth -gt 24) { return }
    if ($Node -is [string]) {
        if ("$Node".Trim()) { [pscustomobject]@{ File = $File; Path = $Path; Surface = $Surface; Text = [string]$Node } }
        return
    }
    if ($Node -is [ValueType]) { return }
    if ($Node -is [System.Collections.IEnumerable]) {
        $i = 0
        foreach ($item in $Node) {
            Get-NsCells -Node $item -File $File -Path ("{0}[{1}]" -f $Path, $i) -Surface $Surface -InVisual:$InVisual -Depth ($Depth + 1)
            $i++
        }
        return
    }
    $props = @($Node.PSObject.Properties.Name)
    if (-not $props) { return }
    $mine = $Surface
    if (-not $InVisual -and $props -contains 'layout' -and $Node.layout) { $mine = 'deck' }
    foreach ($p in $props) {
        if ($p -like '_*') { continue }
        if ($p -eq 'provenance' -or $p -eq 'openQuestions') { continue }
        $cv = ($InVisual -or $p -eq 'visuals' -or $p -eq 'spec')
        $cs = if ($p -eq 'slides' -and -not $cv) { 'deck' } else { $mine }
        Get-NsCells -Node $Node.$p -File $File -Path $(if ($Path) { "$Path.$p" } else { $p }) -Surface $cs -InVisual:$cv -Depth ($Depth + 1)
    }
}

#  A DEFINITION is a label, an ordinal and a separator at the head of a string:
#  "Appendix C - Equipment list", "Table 2: Cooling times", "Activity 3 -
#  Sizing the batch". A mere mention is not a definition, which is what keeps
#  this from firing on every legitimate reference to the pack's own documents.
#  The dash family is written as \u escapes, not as the characters themselves:
#  this file is ASCII, and PS 5.1 decodes a BOM-less .ps1 as ANSI, which would
#  silently corrupt any literal it carried.
$script:NsDefinitionRx = '^\s*(?<lab>[A-Z][A-Za-z]{2,15})\s+(?<val>\d+(?:\.\d+)*|[A-Z])\s*[-:\u2013\u2014]\s+\S'

#  AND THE SHAPE ALONE IS NOT ENOUGH, which the reference build proved on the
#  first run. A slide bullet reading "Observation 7: the assessor watches you
#  pre-chill, load and deliver" has exactly the definition shape and is a
#  SIGNPOST to the pack's own Observation 7, not the guide inventing a second
#  one - and read as a definition it produced a false collision AND a phantom
#  guide scheme that then made all fifteen real Observation references
#  ambiguous. So a definition is only counted where it sits in a field whose
#  JOB is to name something. This is a list of FIELD NAMES, not of values: it
#  narrows where the rule looks, never which identifiers it will accept.
$script:NsNamingFields = @('title', 'caption', 'heading', 'name', 'label', 'subtitle', 'term')

function Get-NsGuideDefinitions {
    <#  Every identifier the GUIDE invents for itself, with where it invented
        it. Three derived sources: the declared caption prefix over the spine's
        own visual slots, the contract's topics, and definition-shaped strings
        anywhere on the spine.  #>
    param($Cells, $Contract, [string] $CaptionPrefix, $SpineDocs)

    $defs = New-Object System.Collections.Generic.List[object]

    if ($CaptionPrefix) {
        foreach ($d in $SpineDocs) {
            foreach ($v in (Get-NsArray (Get-GateProp -Object $d.Json -Names @('visuals')))) {
                $slot = '' + (Get-GateProp -Object $v -Names @('slot', 'figure', 'number') -Default '')
                if ($slot) { $defs.Add([pscustomobject]@{ Label = $CaptionPrefix; Value = $slot; Where = ("{0} visuals slot" -f $d.Name) }) }
            }
        }
    }

    foreach ($t in (Get-NsArray (Get-GateProp -Object $Contract -Names @('topics')))) {
        $n = '' + (Get-GateProp -Object $t -Names @('n', 'number') -Default '')
        if ($n) { $defs.Add([pscustomobject]@{ Label = 'Topic'; Value = $n; Where = 'contract topics' }) }
        foreach ($pc in (Get-NsArray (Get-GateProp -Object $t -Names @('pcs')))) {
            $defs.Add([pscustomobject]@{ Label = 'Topic'; Value = "$pc"; Where = 'contract topics[].pcs' })
        }
    }

    $skipped = 0
    foreach ($c in $Cells) {
        $m = [regex]::Match($c.Text, $script:NsDefinitionRx)
        if (-not $m.Success) { continue }
        #  The last field name on the path, with any array indexers stripped.
        $leaf = ($c.Path -replace '\[\d+\]', '')
        $dot = $leaf.LastIndexOf('.')
        if ($dot -ge 0) { $leaf = $leaf.Substring($dot + 1) }
        if ($script:NsNamingFields -notcontains $leaf.ToLowerInvariant()) { $skipped++; continue }
        $defs.Add([pscustomobject]@{ Label = $m.Groups['lab'].Value; Value = $m.Groups['val'].Value; Where = ("{0}:{1}" -f $c.File, $c.Path) })
    }
    return [pscustomobject]@{ Definitions = $defs.ToArray(); SkippedNotNamingField = $skipped }
}

# ---------------------------------------------------------------------------
# THE GATE
# ---------------------------------------------------------------------------

function Invoke-IdentifierNamespace {
    param(
        [Parameter(Mandatory)][string] $Build,
        [string] $Spine,
        [string] $Contract,
        [string] $Register,
        [string] $Cells,
        [string] $CaptionPrefix,
        [string] $CaptionFrom
    )

    $findings = New-Object System.Collections.Generic.List[object]
    $notes = New-Object System.Collections.Generic.List[object]

    if (-not $Spine)    { $Spine = Join-Path $Build 'spine' }
    if (-not $Register) { $Register = Join-Path $Build 'withhold-register.json' }
    if (-not $Cells)    { $Cells = Join-Path $Build 'assessor-cells.json' }

    $contractDoc = if ($Contract) { Get-GateJson -Path $Contract } else { Get-GateContract -BuildDir $Build }
    if ($null -eq $contractDoc) {
        throw ("$GATE`: no contract at {0}. The pack's reference patterns and the guide's own topic numbering are both DECLARED there; with no contract this gate would have to type both schemes, which is the drift it exists to end." -f (Join-Path $Build 'contract.json'))
    }
    $registerDoc = Get-GateJson -Path $Register
    $cellsDoc    = Get-GateJson -Path $Cells

    $spineFiles = @(Get-ChildItem -LiteralPath $Spine -Filter '*.json' -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -notmatch '\.gate\.json$' -and $_.Name -notmatch '\.result\.json$' } |
                    Sort-Object Name)
    if ($spineFiles.Count -eq 0) { throw ("$GATE`: no spine JSON under {0}." -f $Spine) }

    $cellList = New-Object System.Collections.Generic.List[object]
    $spineDocs = New-Object System.Collections.Generic.List[object]
    foreach ($f in $spineFiles) {
        $j = Get-GateJson -Path $f.FullName
        if ($null -eq $j) { continue }
        $spineDocs.Add([pscustomobject]@{ Name = $f.Name; Json = $j })
        foreach ($c in (Get-NsCells -Node $j -File $f.Name)) { $cellList.Add($c) }
    }

    #  The channel the guide states its reference convention in. DERIVED:
    #  the contract block that declares the patterns is itself a named field,
    #  and a spine path segment of that name is the guide restating it.
    $ConventionChannel = ''
    foreach ($pn in @($contractDoc.PSObject.Properties.Name)) {
        if ($pn -like '_*') { continue }
        if ($pn -imatch 'referenceConvention') { $ConventionChannel = $pn }
    }

    # ---- the two namespaces
    $pack = Get-NsPackSchemes -Contract $contractDoc -Register $registerDoc -Cells $cellsDoc
    $packSchemes = $pack.Schemes
    $ambiguous = Get-NsAmbiguousBare -Schemes $packSchemes
    $guideDefsOut = Get-NsGuideDefinitions -Cells $cellList.ToArray() -Contract $contractDoc -CaptionPrefix $CaptionPrefix -SpineDocs $spineDocs.ToArray()
    $guideDefs = $guideDefsOut.Definitions
    $defsSkipped = $guideDefsOut.SkippedNotNamingField

    #  The guide's own schemes, folded from its definitions, so a reference to a
    #  guide identifier can be resolved the same way a pack one is.
    $guideSchemes = @{}
    foreach ($d in $guideDefs) {
        $k = $d.Label.ToLowerInvariant()
        if (-not $guideSchemes.ContainsKey($k)) { $guideSchemes[$k] = New-NsScheme -Label $d.Label -Owner 'guide' -Source 'spine definitions' }
        Add-NsValue -Scheme $guideSchemes[$k] -Value $d.Value -Where $d.Where
    }

    # -----------------------------------------------------------------------
    # NS-COLLISION - set intersection over the two schemes
    # -----------------------------------------------------------------------
    #  THE INTERSECTION IS TAKEN OVER THE BARE LABEL TOO, and this gate's own
    #  self-test is why. The pack's labels are "Knowledge Task" and "Workbook
    #  Task"; a guide that names something "Task 4" matches NEITHER of them as a
    #  string and would have walked through a collision test keyed on the full
    #  labels alone. The ambiguous bare tail is already derived from the label
    #  set, so the check-set is the full labels PLUS every shared tail, with the
    #  tail's values being the union of the schemes that own it.
    $packByLabel = @{}
    foreach ($k in $packSchemes.Keys) {
        $packByLabel[$k] = [pscustomobject]@{
            Label = $packSchemes[$k].Label; Values = $packSchemes[$k].Values
            Sources = @($packSchemes[$k].Sources); Anchors = $packSchemes[$k].Anchors
        }
    }
    foreach ($tk in $ambiguous.Keys) {
        $amb = $ambiguous[$tk]
        $vals = New-Object System.Collections.Generic.HashSet[string]
        $anch = @{}
        $srcs = New-Object System.Collections.Generic.List[string]
        foreach ($ownerLabel in $amb.Owners) {
            $ok = $ownerLabel.ToLowerInvariant()
            if (-not $packSchemes.ContainsKey($ok)) { continue }
            foreach ($v in $packSchemes[$ok].Values) { [void]$vals.Add($v); if (-not $anch.ContainsKey($v)) { $anch[$v] = ("{0} {1}" -f $ownerLabel, $v) } }
            foreach ($s in $packSchemes[$ok].Sources) { if (-not $srcs.Contains($s)) { $srcs.Add($s) } }
        }
        if ($vals.Count -eq 0) { continue }
        $packByLabel[$tk] = [pscustomobject]@{
            Label = $amb.Tail; Values = $vals; Anchors = $anch
            Sources = @(('the shared bare label of ' + ($amb.Owners -join ' and ')) + '; ' + ($srcs -join ' + '))
        }
    }

    $collisionsChecked = 0
    $seenCollision = @{}
    foreach ($d in $guideDefs) {
        $k = $d.Label.ToLowerInvariant()
        if (-not $packByLabel.ContainsKey($k)) { continue }
        $collisionsChecked++
        if (-not $packByLabel[$k].Values.Contains($d.Value)) { continue }
        $key = "{0}|{1}" -f $k, $d.Value
        if ($seenCollision.ContainsKey($key)) { continue }
        $seenCollision[$key] = $true
        $findings.Add([pscustomobject]@{
            Rule = 'NS-COLLISION'; Level = 'BLOCK'; Label = $d.Label; Value = $d.Value
            Detail = ("the guide defines '{0} {1}' at {2}, and the source pack already owns '{3} {1}' (scheme derived from {4}; the pack's copy is enumerated at {5}). A qualified convention has to go into the build contract BEFORE anything is authored - one guide's appendix letters collided across 151 references and the renumbering left a stale reference behind." -f `
                $d.Label, $d.Value, $d.Where, $packByLabel[$k].Label, ($packByLabel[$k].Sources -join ' + '), $packByLabel[$k].Anchors[$d.Value])
        })
    }

    # -----------------------------------------------------------------------
    # Cross-reference resolution, both directions
    # -----------------------------------------------------------------------
    #  One regex per declared label, longest label first, so "Workbook Task 2"
    #  is consumed by the Workbook Task scheme before the bare "Task" rule ever
    #  sees it. Every label here came out of a declared file.
    $allLabels = New-Object System.Collections.Generic.List[object]
    foreach ($k in $packSchemes.Keys)  { $allLabels.Add([pscustomobject]@{ Key = $k; Label = $packSchemes[$k].Label;  Owner = 'pack';  Scheme = $packSchemes[$k] }) }
    foreach ($k in $guideSchemes.Keys) { $allLabels.Add([pscustomobject]@{ Key = $k; Label = $guideSchemes[$k].Label; Owner = 'guide'; Scheme = $guideSchemes[$k] }) }
    $ordered = @($allLabels | Sort-Object { $_.Label.Length } -Descending)

    $index = New-Object System.Collections.Generic.List[object]
    $dangling = @{}; $ambig = @{}; $bare = @{}
    $mentioned = 0; $qualifiedNearby = 0; $conventionChannelHits = 0
    $refCount = 0

    foreach ($c in $cellList) {
        $text = $c.Text
        if ($text.Length -lt 4) { continue }
        #  Consumed spans, so a longer label's match cannot be re-counted by a
        #  shorter one that sits inside it.
        $taken = New-Object System.Collections.Generic.List[object]
        foreach ($L in $ordered) {
            $rx = '(?<!\w)' + [regex]::Escape($L.Label) + '\s+(?<val>\d+(?:\.\d+)*)'
            foreach ($m in [regex]::Matches($text, $rx, 'IgnoreCase')) {
                $overlap = $false
                foreach ($t in $taken) { if ($m.Index -lt ($t.S + $t.L) -and ($m.Index + $m.Length) -gt $t.S) { $overlap = $true; break } }
                if ($overlap) { continue }
                $taken.Add([pscustomobject]@{ S = $m.Index; L = $m.Length })
                $refCount++
                $val = $m.Groups['val'].Value
                #  AMBIGUITY IS BY VALUE, NOT BY LABEL, and the reference build
                #  is why. Its guide numbers its own appendices 1 to 7 precisely
                #  so they cannot be confused with the pack's Appendix A and B -
                #  it says so in its own front matter - and a label-only test
                #  called all seven of them ambiguous. Two schemes sharing a
                #  label but no value resolve without ambiguity; the reference
                #  is ambiguous only where both schemes occupy the value.
                #  AMBIGUITY IS BY VALUE, NOT BY LABEL, and the reference build
                #  is why. Its guide numbers its own appendices 1 to 7 precisely
                #  so they cannot be confused with the pack's Appendix A and B -
                #  and it says so in its own front matter - yet a label-only
                #  test called all seven of them ambiguous. Two schemes sharing
                #  a label but no value resolve without ambiguity; a reference
                #  is ambiguous only where more than one of them OCCUPIES the
                #  value.
                $owners = @($ordered | Where-Object { ($_.Label -ieq $L.Label) -and $_.Scheme.Values.Contains($val) })
                #  $into is where the reference actually lands. The loop
                #  variable is never reassigned - a foreach variable rewritten
                #  inside its own body stays rewritten for every later match in
                #  the same cell.
                $into = $L
                if ($owners.Count -eq 1) { $into = $owners[0] }
                $resolved = ($owners.Count -ge 1)

                $index.Add([pscustomobject]@{
                    Reference = ("{0} {1}" -f $into.Label, $val); Label = $into.Label; Value = $val
                    Namespace = $into.Owner; Resolved = $resolved
                    Target = $(if ($resolved) { '' + $into.Scheme.Anchors[$val] } else { '' })
                    Surface = $c.Surface; File = $c.File; Path = $c.Path
                })
                if ($owners.Count -gt 1) {
                    $key = "{0} {1}|{2}|{3}" -f $into.Label, $val, $c.File, $c.Path
                    if (-not $ambig.ContainsKey($key)) {
                        $ambig[$key] = $true
                        $findings.Add([pscustomobject]@{
                            Rule = 'NS-XREF-AMBIGUOUS'; Level = 'BLOCK'; Label = $into.Label; Value = $val
                            Detail = ("'{0} {1}' at {2}:{3} resolves into {4} namespaces at once ({5}), because both of them occupy that value. A reference that resolves two ways resolves silently into one of them." -f `
                                $into.Label, $val, $c.File, $c.Path, $owners.Count, (($owners | ForEach-Object { $_.Owner }) -join ' and '))
                        })
                    }
                }
                elseif (-not $resolved) {
                    $sameLabel = @($ordered | Where-Object { $_.Label -ieq $L.Label })
                    $totalValues = 0
                    foreach ($sl in $sameLabel) { $totalValues += $sl.Scheme.Values.Count }
                    if ($totalValues -eq 0) {
                        $key = 'novalues|' + $L.Label
                        if (-not $dangling.ContainsKey($key)) {
                            $dangling[$key] = $true
                            $notes.Add([pscustomobject]@{
                                Rule = 'NS-XREF-DANGLING'; Level = 'REPORT'; Label = $L.Label; Value = ''
                                Detail = ("scheme '{0}' has an EMPTY value set, so no reference into it was resolved. Resolving against an empty target list would report every correct reference as dangling, so this arm did not run for that scheme and says so here rather than passing." -f $L.Label)
                            })
                        }
                    }
                    else {
                        $key = "{0} {1}|{2}|{3}" -f $L.Label, $val, $c.File, $c.Path
                        if (-not $dangling.ContainsKey($key)) {
                            $dangling[$key] = $true
                            $findings.Add([pscustomobject]@{
                                Rule = 'NS-XREF-DANGLING'; Level = 'BLOCK'; Label = $L.Label; Value = $val
                                Detail = ("'{0} {1}' at {2}:{3} ({4}-facing) resolves into no namespace at all. The {5} scheme(s) carrying that label occupy {6} value(s) between them and none of them is {7}." -f `
                                    $L.Label, $val, $c.File, $c.Path, $c.Surface, $sameLabel.Count, $totalValues, $val)
                            })
                        }
                    }
                }
            }
        }

        # ---- NS-BARE-REFERENCE, over the spans no qualified label consumed
        foreach ($tk in $ambiguous.Keys) {
            $amb = $ambiguous[$tk]
            $rx = '(?<!\w)(?<q>[A-Za-z]+\s+)?' + [regex]::Escape($amb.Tail) + '\s+(?<val>\d+(?:\.\d+)*)'
            foreach ($m in [regex]::Matches($text, $rx, 'IgnoreCase')) {
                $overlap = $false
                foreach ($t in $taken) { if ($m.Index -lt ($t.S + $t.L) -and ($m.Index + $m.Length) -gt $t.S) { $overlap = $true; break } }
                if ($overlap) { continue }
                $q = ('' + $m.Groups['q'].Value).Trim()
                $qualified = $false
                foreach ($qq in $amb.Qualifiers) { if ($q -ieq $qq) { $qualified = $true } }
                if ($qualified) { continue }
                $val2 = $m.Groups['val'].Value

                #  NS-BARE-MENTIONED. The reference is inside quotation marks,
                #  so it is being MENTIONED rather than used as a pointer -
                #  which is what the guide's own orientation slide does when it
                #  warns the room that 'Task 5' on its own is ambiguous. Failing
                #  a document for saying the thing this rule says is the
                #  crying-wolf gate gates.md forbids.
                $qc = @([char]39, [char]34, [char]0x2018, [char]0x2019, [char]0x201C, [char]0x201D)
                $bIx = $m.Index + $m.Groups['q'].Length
                $bCh = if ($bIx -gt 0) { $text[$bIx - 1] } else { [char]0 }
                $aIx = $m.Index + $m.Length
                $aCh = if ($aIx -lt $text.Length) { $text[$aIx] } else { [char]0 }
                if (($qc -contains $bCh) -and ($qc -contains $aCh)) { $mentioned++; continue }

                #  NS-BARE-QUALIFIED-NEARBY. The SAME label at the SAME value
                #  appears qualified elsewhere in this same string, so the
                #  reader has the qualifier in front of them: "Workbook Task
                #  4(b) asks for the adjustment ... Task 4(d) asks for three
                #  documented requests". The elision resolves; a first,
                #  unqualified use would not, and still fails.
                $near = $false
                foreach ($qq in $amb.Qualifiers) {
                    $nrx = '(?<!\w)' + [regex]::Escape($qq) + '\s+' + [regex]::Escape($amb.Tail) + '\s+' + [regex]::Escape($val2) + '(?!\d)'
                    if ([regex]::IsMatch($text, $nrx, 'IgnoreCase')) { $near = $true; break }
                }
                if ($near) { $qualifiedNearby++; continue }

                #  NS-BARE-CONVENTION-CHANNEL. The cell IS the guide's own
                #  written statement OF the reference convention: its path
                #  carries a segment named after the contract's own
                #  referenceConvention block. The bare form there is the thing
                #  being explained - "both documents number their items Task 1,
                #  Task 2 and so on, so this guide names them apart" - and
                #  failing a document for stating the rule this gate enforces is
                #  the crying-wolf gate gates.md forbids. The channel name is
                #  READ off the contract, never typed here.
                if ($ConventionChannel) {
                    $segs = @(($c.Path -replace '\[\d+\]', '') -split '\.')
                    $inChannel = $false
                    foreach ($sg in $segs) { if ($sg -ieq $ConventionChannel) { $inChannel = $true } }
                    if ($inChannel) { $conventionChannelHits++; continue }
                }

                $key = "{0} {1}|{2}|{3}" -f $amb.Tail, $val2, $c.File, $c.Path
                if ($bare.ContainsKey($key)) { continue }
                $bare[$key] = $true
                $findings.Add([pscustomobject]@{
                    Rule = 'NS-BARE-REFERENCE'; Level = 'BLOCK'; Label = $amb.Tail; Value = $val2
                    Detail = ("'{0} {1}' at {2}:{3} ({4}-facing) carries no qualifier, and the pack numbers {0} from one in {5} separate documents ({6}). The contract's own referenceConvention says why that is ambiguous; the qualifiers are {7}." -f `
                        $amb.Tail, $val2, $c.File, $c.Path, $c.Surface, $amb.Owners.Count, ($amb.Owners -join ', '), ($amb.Qualifiers -join ' / '))
                })
            }
        }
    }

    return [pscustomobject]@{
        Findings = $findings.ToArray()
        Notes    = $notes.ToArray()
        Index    = $index.ToArray()
        PackSchemes  = $packSchemes
        GuideSchemes = $guideSchemes
        Ambiguous    = $ambiguous
        RecipeCodes  = $pack.RecipeCodes
        Stats    = [pscustomobject]@{
            spineFiles = $spineFiles.Count
            cells = $cellList.Count
            packSchemes = $packSchemes.Count
            packValues = (($packSchemes.Keys | ForEach-Object { $packSchemes[$_].Values.Count }) | Measure-Object -Sum).Sum
            guideSchemes = $guideSchemes.Count
            guideDefinitions = @($guideDefs).Count
            definitionShapedNotInNamingField = $defsSkipped
            ambiguousBareLabels = $ambiguous.Count
            bareSuppressedMentionedInQuotes = $mentioned
            bareSuppressedQualifiedNearby = $qualifiedNearby
            bareSuppressedConventionChannel = $conventionChannelHits
            conventionChannel = $ConventionChannel
            collisionCandidates = $collisionsChecked
            crossReferences = $refCount
            resolved = @($index | Where-Object { $_.Resolved }).Count
            recipeCodes = @($pack.RecipeCodes).Count
            captionPrefix = $CaptionPrefix
            captionFrom = $CaptionFrom
        }
    }
}

# ---------------------------------------------------------------------------
# SELF-TEST
# ---------------------------------------------------------------------------

function New-NsFixture {
    param([Parameter(Mandatory)][string] $Root)

    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Root 'spine') -Force | Out-Null

    Write-NsJson -Path (Join-Path $Root 'contract.json') -Object ([ordered]@{
        build = [ordered]@{ brand = '' }
        topics = @([ordered]@{ n = 1; pcs = @('1.1') })
        referenceConvention = [ordered]@{
            knowledge   = 'Knowledge Task {n}({part})'
            workbook    = 'Workbook Task {n}({part})'
            observation = 'Observation {n}'
        }
        questionMap = [ordered]@{
            '1.1' = @('Knowledge Task 4(a)', 'Workbook Task 1(a)', 'Observation 1')
        }
        visuals = [ordered]@{ perSubSection = 1 }
    })

    Write-NsJson -Path (Join-Path $Root 'withhold-register.json') -Object ([ordered]@{
        documents = [ordered]@{
            FixtureWorkbook = [ordered]@{ audience = 'learner'; referencePattern = 'Workbook Task {n}({part})' }
            FixtureKnowledge = [ordered]@{ audience = 'learner'; referencePattern = 'Knowledge Task {n}({part})' }
        }
        vocabulary = [ordered]@{
            document = @('Fixture Order Form (Appendix A)')
            equipment = @()
            recipe = @('2091 Fixture item')
        }
        subSections = [ordered]@{
            '1.1' = [ordered]@{
                subSection = '1.1'
                refs = @('Knowledge Task 4(a)', 'Workbook Task 1(a)', 'Observation 1')
                tasks = @([ordered]@{ ref = 'Workbook Task 1(a)' }, [ordered]@{ ref = 'Knowledge Task 4(a)' })
                observations = @([ordered]@{ ref = 'Observation 1'; number = 1 })
            }
        }
    })

    Write-NsJson -Path (Join-Path $Root 'spine\t1_1.1.json') -Object ([ordered]@{
        ref = '1.1'; pc = '1.1'; topic = '1'; title = 'Shape one'
        whatThisMeans = 'Body prose. It prepares you for Workbook Task 1(a) and Knowledge Task 4(a), and the assessor completes Observation 1.'
        visuals = @([ordered]@{ slot = '1.1.1'; kind = 'Diagram'; caption = 'A short caption'; alt = 'Alt text.' })
        slides = @([ordered]@{
            layout = 'single'; kind = 'teaching'; kicker = 'ONE'; headline = 'Shape one'
            chip = 'Prepares you for: Workbook Task 1(a)'
            notes = 'Speaker notes naming Knowledge Task 4(a) and Observation 1 in full.'
        })
    })
    return $Root
}

function Invoke-NsSelfTest {
    param([string] $Skill, [string] $ConfigGiven)

    $script:NsOk = 0; $script:NsBad = 0
    function Ok  { param([string] $M) Write-Host ("    ok   {0}" -f $M) -ForegroundColor Green; $script:NsOk++ }
    function Bad { param([string] $M) Write-Host ("    X    {0}" -f $M) -ForegroundColor Red;   $script:NsBad++ }

    $cap = Get-NsCaptionPrefix -Given $ConfigGiven -Skill $Skill
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('ns-selftest-' + [Guid]::NewGuid().ToString('N').Substring(0, 12))

    function Test-NsPlantLanded {
        param([string] $Path, [scriptblock] $Probe, [string] $What)
        $j = Get-GateJson -Path $Path
        $landed = $false
        try { $landed = [bool](& $Probe $j) } catch { $landed = $false }
        if ($landed) { Write-Host ("    plant landed: {0}" -f $What) -ForegroundColor DarkGray; return $true }
        Write-Host ("    X plant did NOT land: {0} - this proves nothing." -f $What) -ForegroundColor Red
        return $false
    }

    function Test-NsFires {
        param([string] $Build, [string] $Rule, [string] $What, [switch] $Expect)
        $r = $null
        try { $r = Invoke-IdentifierNamespace -Build $Build -CaptionPrefix $cap.Prefix -CaptionFrom $cap.Path }
        catch { Bad ("{0}: the gate threw - {1}" -f $What, $_.Exception.Message); return }
        $hit = @($r.Findings | Where-Object { $_.Rule -eq $Rule })
        if ($Expect) {
            if ($hit.Count -gt 0) { Ok ("{0}: {1} fired ({2})" -f $What, $Rule, $hit[0].Detail) }
            else { Bad ("{0}: {1} did NOT fire. Findings: {2}" -f $What, $Rule, (@($r.Findings | ForEach-Object { $_.Rule }) -join ', ')) }
        }
        else {
            if ($hit.Count -eq 0) { Ok ("{0}: {1} correctly silent" -f $What, $Rule) }
            else { Bad ("{0}: {1} fired on a correct fixture - {2}" -f $What, $Rule, $hit[0].Detail) }
        }
    }

    try {
        Write-Host ''
        Write-Host ("  SELF-TEST (caption prefix '{0}' from {1})" -f $cap.Prefix, $(if ($cap.Path) { Split-Path -Leaf $cap.Path } else { 'nowhere - not declared' })) -ForegroundColor Cyan

        # ---- CASE 0: clean
        $c0 = Join-Path $root 'clean'
        New-NsFixture -Root $c0 | Out-Null
        $r0 = $null
        try { $r0 = Invoke-IdentifierNamespace -Build $c0 -CaptionPrefix $cap.Prefix -CaptionFrom $cap.Path }
        catch { Bad ("clean fixture: the gate threw - {0}" -f $_.Exception.Message) }
        if ($null -ne $r0) {
            if (@($r0.Findings).Count -eq 0) { Ok ("clean fixture: no collision, every one of its {0} cross-reference(s) resolved into exactly one namespace" -f $r0.Stats.crossReferences) }
            else { Bad ("clean fixture fired {0}: {1}" -f @($r0.Findings).Count, (@($r0.Findings | ForEach-Object { $_.Rule + ' / ' + $_.Detail }) -join ' | ')) }
        }

        # ---- CASE 1: a guide figure identifier landing in the pack's task namespace
        $c1 = Join-Path $root 'p1'
        New-NsFixture -Root $c1 | Out-Null
        $p = Join-Path $c1 'spine\t1_1.1.json'
        $j = Get-GateJson -Path $p
        $j.visuals[0].caption = 'Task 4 - how the sequence runs'
        Write-NsJson -Object $j -Path $p
        if (Test-NsPlantLanded -Path $p -What "a guide figure caption now DEFINES the identifier 'Task 4', which is a pack task number" -Probe {
                param($d) ('' + $d.visuals[0].caption) -match '^Task 4 -'
            }) {
            Test-NsFires -Build $c1 -Rule 'NS-COLLISION' -What 'guide figure identifier colliding with a pack task number' -Expect
        } else { Bad 'plant 1 did not land' }

        # ---- CASE 2: an unqualified bare reference
        $c2 = Join-Path $root 'p2'
        New-NsFixture -Root $c2 | Out-Null
        $p = Join-Path $c2 'spine\t1_1.1.json'
        $j = Get-GateJson -Path $p
        $j.slides[0].notes = 'Speaker notes telling the room to go and do Task 4 before the next session.'
        Write-NsJson -Object $j -Path $p
        if (Test-NsPlantLanded -Path $p -What "speaker notes now say 'Task 4' with no Knowledge or Workbook qualifier" -Probe {
                param($d) (('' + $d.slides[0].notes) -match '(?<!\w)Task 4') -and (('' + $d.slides[0].notes) -notmatch '(Knowledge|Workbook) Task 4')
            }) {
            Test-NsFires -Build $c2 -Rule 'NS-BARE-REFERENCE' -What 'unqualified bare reference into a shared pack label' -Expect
        } else { Bad 'plant 2 did not land' }

        # ---- CASE 3: a reference into a real scheme at a value it does not occupy
        $c3 = Join-Path $root 'p3'
        New-NsFixture -Root $c3 | Out-Null
        $p = Join-Path $c3 'spine\t1_1.1.json'
        $j = Get-GateJson -Path $p
        $j.whatThisMeans = 'Body prose. It prepares you for Workbook Task 9, which the pack does not have.'
        Write-NsJson -Object $j -Path $p
        if (Test-NsPlantLanded -Path $p -What "prose now references 'Workbook Task 9' and the pack's Workbook Task scheme occupies only 1" -Probe {
                param($d) ('' + $d.whatThisMeans) -match 'Workbook Task 9'
            }) {
            Test-NsFires -Build $c3 -Rule 'NS-XREF-DANGLING' -What 'cross-reference into a pack scheme at an unoccupied value' -Expect
        } else { Bad 'plant 3 did not land' }

        # ---- CASE 4: a guide appendix letter over the pack's own
        $c4 = Join-Path $root 'p4'
        New-NsFixture -Root $c4 | Out-Null
        $p = Join-Path $c4 'spine\t1_1.1.json'
        $j = Get-GateJson -Path $p
        $j | Add-Member -NotePropertyName 'appendices' -NotePropertyValue @([pscustomobject]@{ title = 'Appendix A - the guide''s own glossary of terms' }) -Force
        Write-NsJson -Object $j -Path $p
        if (Test-NsPlantLanded -Path $p -What "the guide now DEFINES 'Appendix A' in a title field, a letter the pack's own document vocabulary already owns" -Probe {
                param($d) ('' + $d.appendices[0].title) -match '^Appendix A -'
            }) {
            Test-NsFires -Build $c4 -Rule 'NS-COLLISION' -What "guide appendix letter colliding with the pack's" -Expect
        } else { Bad 'plant 4 did not land' }

        # ---- CASE 5: the qualified form of the same reference must NOT fire
        $c5 = Join-Path $root 'p5'
        New-NsFixture -Root $c5 | Out-Null
        Test-NsFires -Build $c5 -Rule 'NS-BARE-REFERENCE' -What "every reference in the clean fixture is qualified"
        Test-NsFires -Build $c5 -Rule 'NS-XREF-DANGLING' -What "every qualified reference in the clean fixture resolves"
    }
    finally {
        if ((Test-Path -LiteralPath $root) -and $root.Length -gt 12) {
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host ''
    if ($script:NsBad -gt 0) { Write-Host ("  SELF-TEST FAILED - {0} of {1} check(s) failed" -f $script:NsBad, ($script:NsOk + $script:NsBad)) -ForegroundColor Red }
    else                     { Write-Host ("  SELF-TEST PASSED - {0} check(s), every planted defect verified to have landed and then caught" -f $script:NsOk) -ForegroundColor Green }
    return $script:NsBad
}

# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------

if ($SelfTest) {
    try { $bad = Invoke-NsSelfTest -Skill $SkillDir -ConfigGiven $ImagesConfig }
    catch { Write-Host ("  X {0}: self-test could not run - {1}" -f $GATE, $_.Exception.Message) -ForegroundColor Red; exit 4 }
    if ($bad -gt 0) { exit 4 }
    if (-not $BuildDir) { exit 0 }
}

if (-not $BuildDir) {
    Write-Host ("  X {0}: -BuildDir is required (or -SelfTest on its own)." -f $GATE) -ForegroundColor Red
    exit 2
}
if (-not (Test-Path -LiteralPath $BuildDir)) {
    Write-Host ("  X {0}: -BuildDir not found: {1}" -f $GATE, $BuildDir) -ForegroundColor Red
    exit 2
}

$cap = Get-NsCaptionPrefix -Given $ImagesConfig -Skill $SkillDir
try {
    $result = Invoke-IdentifierNamespace -Build $BuildDir -Spine $SpineDir -Contract $ContractPath `
                                         -Register $RegisterPath -Cells $AssessorCellsPath `
                                         -CaptionPrefix $cap.Prefix -CaptionFrom $cap.Path
}
catch { Write-Host ("  X {0}: {1}" -f $GATE, $_.Exception.Message) -ForegroundColor Red; exit 2 }

$st = $result.Stats
$blocking = @($result.Findings)
$reports  = @($result.Notes)

if (-not $Quiet) {
    Write-Host ''
    Write-Host 'IDENTIFIER NAMESPACE - does anything the guide invents collide with the pack?' -ForegroundColor Cyan
    Write-GateCheckSet -What 'pack identifier scheme(s)' -Count $st.packSchemes -DerivedFrom 'contract referenceConvention + withhold-register documents/refs + assessor-cells grid refs + register vocabulary'
    Write-GateCheckSet -What 'guide identifier scheme(s)' -Count $st.guideSchemes -DerivedFrom ("the declared caption prefix '{0}', contract topics, and definition-shaped strings on the spine" -f $st.captionPrefix)
    foreach ($k in ($result.PackSchemes.Keys | Sort-Object)) {
        $s = $result.PackSchemes[$k]
        Write-Host ("    pack  {0,-18} {1,4} value(s)   from {2}" -f $s.Label, $s.Values.Count, ($s.Sources -join ' + ')) -ForegroundColor DarkGray
    }
    foreach ($k in ($result.GuideSchemes.Keys | Sort-Object)) {
        $s = $result.GuideSchemes[$k]
        Write-Host ("    guide {0,-18} {1,4} value(s)" -f $s.Label, $s.Values.Count) -ForegroundColor DarkGray
    }
    Write-Host ("  {0} spine file(s), {1} cell(s); {2} guide definition(s), {3} of them on a label the pack also owns; {4} ambiguous bare label(s) derived from the pack's own label set; {5} recipe code(s) recorded" -f `
        $st.spineFiles, $st.cells, $st.guideDefinitions, $st.collisionCandidates, $st.ambiguousBareLabels, $st.recipeCodes) -ForegroundColor DarkGray
    Write-Host ("  suppression: {0} definition-shaped string(s) NOT counted as definitions because they sit outside a naming field ({1}) - a slide bullet reading 'Observation 7: the assessor watches you' is a signpost to the pack's item, not the guide inventing a second one" -f `
        $st.definitionShapedNotInNamingField, ($script:NsNamingFields -join ', ')) -ForegroundColor DarkGray
    Write-Host ("  suppression: {0} bare reference(s) suppressed as MENTIONED (inside quotation marks - the guide warning the room that a bare form is ambiguous is not itself a bare form); {1} as QUALIFIED NEARBY (the same label at the same value is qualified elsewhere in the same string); {2} in the guide's own statement of the convention (path segment '{3}', read off the contract)" -f $st.bareSuppressedMentionedInQuotes, $st.bareSuppressedQualifiedNearby, $st.bareSuppressedConventionChannel, $st.conventionChannel) -ForegroundColor DarkGray
    Write-Host ("  {0} cross-reference(s) resolved, {1} of them onto a target; the whole index is in the report as audit evidence" -f $st.crossReferences, $st.resolved) -ForegroundColor DarkGray

    Write-Host ''
    if ($blocking.Count -eq 0) { Write-Host '  no namespace collision, and every cross-reference resolves into exactly one namespace' -ForegroundColor Green }
    foreach ($g in ($blocking | Group-Object Rule | Sort-Object Name)) {
        Write-Host ("  {0}: {1} blocking" -f $g.Name, $g.Count) -ForegroundColor Red
        foreach ($f in ($g.Group | Select-Object -First 25)) { Write-Host ("    X {0}" -f $f.Detail) -ForegroundColor Red }
        if ($g.Count -gt 25) { Write-Host ("    ... {0} more in the report file" -f ($g.Count - 25)) -ForegroundColor DarkGray }
    }
    foreach ($g in ($reports | Group-Object Rule | Sort-Object Name)) {
        Write-Host ("  {0}: {1} REPORT (never changes the exit code)" -f $g.Name, $g.Count) -ForegroundColor Yellow
        foreach ($f in ($g.Group | Select-Object -First 15)) { Write-Host ("    ! {0}" -f $f.Detail) -ForegroundColor Yellow }
    }
}

if (-not $ReportPath) { $ReportPath = Join-Path $BuildDir 'identifier-namespace-report.json' }

$packOut = New-Object System.Collections.Generic.List[object]
foreach ($k in ($result.PackSchemes.Keys | Sort-Object)) {
    $s = $result.PackSchemes[$k]
    $packOut.Add([pscustomobject]@{ label = $s.Label; owner = 'pack'; values = @($s.Values | Sort-Object); sources = @($s.Sources) })
}
$guideOut = New-Object System.Collections.Generic.List[object]
foreach ($k in ($result.GuideSchemes.Keys | Sort-Object)) {
    $s = $result.GuideSchemes[$k]
    $guideOut.Add([pscustomobject]@{ label = $s.Label; owner = 'guide'; values = @($s.Values | Sort-Object) })
}
$ambOut = New-Object System.Collections.Generic.List[object]
foreach ($k in ($result.Ambiguous.Keys | Sort-Object)) {
    $a = $result.Ambiguous[$k]
    $ambOut.Add([pscustomobject]@{ bareLabel = $a.Tail; qualifiers = @($a.Qualifiers); ownedBy = @($a.Owners) })
}

$report = [pscustomobject]@{
    gate      = $GATE
    generated = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
    buildDir  = $BuildDir
    spineFingerprint = (Get-SpineFingerprint -BuildDir $BuildDir -SpineDir $SpineDir)
    captionPrefix = [pscustomobject]@{ prefix = $st.captionPrefix; declaredIn = $st.captionFrom }
    packSchemes  = $packOut.ToArray()
    guideSchemes = $guideOut.ToArray()
    ambiguousBareLabels = $ambOut.ToArray()
    recipeCodes  = $result.RecipeCodes
    stats     = $st
    blocking  = $blocking
    report    = $reports
    #  THE RESOLVED CROSS-REFERENCE INDEX, in both directions, supplied to the
    #  audit as evidence. An auditor once reported a whole section as
    #  non-existent and the false finding had to be refuted by hand search.
    resolvedIndex = $result.Index
    verdict   = $(if ($blocking.Count) { 'FAIL' } else { 'PASS' })
}
Write-NsJson -Object $report -Path $ReportPath
if (-not $Quiet) { Write-Host ("  report written to {0} (carrying the resolved cross-reference index for the audit)" -f $ReportPath) -ForegroundColor DarkGray }

if ($blocking.Count) {
    if (-not $Quiet) { Write-Host ("FAIL - {0} namespace or resolution defect(s)" -f $blocking.Count) -ForegroundColor Red }
    exit 1
}
if (-not $Quiet) { Write-Host 'PASS' -ForegroundColor Green }
exit 0
