<#
    Assert-SpecRenderable.ps1 - can this visual spec actually be DRAWN?

    Implements references\gates.md section 22. The exact arm runs at Stage 3 at
    write time; this is the whole-spine arm and runs at Stage 3c inside the
    spine gate band.

        scripts\Assert-SpecRenderable.ps1 -BuildDir $out

    WHY IT EXISTS. Every fact this gate needs is on the spine the moment the
    spec is written, and today nobody reads it: the docx-images sub-skill
    discovers an over-length flow or a flattened decision when it BUILDS the
    figure at Stage 7b-ii, after generation has been paid for and after Stage 4,
    Stage 4b, Stage 5 and a full audit round have all passed. Three measured
    failures, all determinable from the spec alone:

      1. Nineteen flow diagrams over length. A nine-node flow lands at 21.6 cm
         and an eleven-node at 26.5 cm; the reference build's own conversion
         note records 26.6 cm against a 24.6 cm column.
      2. A decision figure silently flattened to a straight line, so one branch
         disappeared and the figure taught "you always report a mismatch" -
         the opposite of the rule.
      3. Four photographs re-detected as diagrams by KEYWORD, because the
         artwork manifest guessed `kind` from prompt text instead of reading
         the spine.

    AND THE FOURTH, WHICH IS WHY A MISSING SPEC IS A FAILURE RATHER THAN A
    SKIP. On one build the diagram specs were hand-typed inside a build script
    instead of living on the spine, and three rounds of spine corrections never
    reached them. A declared slot with no spine spec is a SPINE DEFECT, so this
    gate FAILS on it rather than passing over what it cannot see.

    EVERY CAP AND EVERY WIDTH IS READ, NEVER TYPED.

      the docx-images sub-skill config   diagram.maxNodes (the canvas box cap),
      config\defaults.json               diagram.renderer (which layout is drawn
                                         as a canvas and which as a real table),
                                         diagram.typography (font size, from
                                         which a line height is arithmetic),
                                         placement.widthFraction and
                                         placement.maxHeightCm
      the RTO profile pack ->            page height and margins, from which the
      the guide profile                  column height is arithmetic, and
                                         contentWidthDxa for the column width

    Three typographic estimators are NOT in either file and are therefore
    PARAMETERS, whose resolved values and sources are printed on every run:
    -CellPaddingCm, -NodeGapCm and -AvgCharEmShare. -NodeHeightCm overrides the
    derived per-node height outright. Nothing here names a unit, an RTO, a
    brand, a hex or a path.

    THE NAMED RULES.

      SR-NODE-CAP           blocking. A spec drawn on a CANVAS with more boxes
                            than diagram.maxNodes. The message names the table
                            fallback - the layouts the config's own renderer map
                            sends to a real Word table - because "too many
                            boxes" without the remedy is a finding nobody can
                            action.
      SR-HEIGHT-COLUMN      blocking. Projected height over the column height
                            derived from the page's own geometry. This is the
                            one that cannot be scaled away: it does not fit the
                            page.
      SR-HEIGHT-PLACEMENT   REPORT. Projected height over placement.maxHeightCm.
                            The placement pass scales to this, so it is a
                            legibility warning and not a blocker.
      SR-BRANCH-CAPABILITY  blocking. Branch or decision semantics on a spec
                            whose target renderer declares no branch capability.
                            Detected STRUCTURALLY - a declared branch field, the
                            toolchain's own '||' alternative separator, or a
                            node label that is a question - never from a
                            vocabulary of decision words. Names the table
                            fallback.
      SR-KIND-DECLARED      blocking. A visual with no explicit `kind` on the
                            spine. The manifest is seeded BY SLOT from the
                            spine; a visual that does not say what it is leaves
                            the sub-skill guessing from prompt text, which is
                            how four photographs became diagrams.
      SR-SLOT-NO-SPEC       blocking. A declared slot with no spine spec: an
                            expected slot with no visual at all, or a visual
                            that will be DRAWN and carries no spec.
      SR-SLOT-DANGLING      blocking. A cross-reference to a figure slot that no
                            visual on the spine defines.

    NEVER PRINTS A MODEL ANSWER OR A BENCHMARK ROW. Slots, kinds, layouts,
    counts, centimetres and paths only.

    PROVED BY PLANTING. -SelfTest builds a synthetic build directory, plants
    six defects, VERIFIES EACH PLANT LANDED by reading the file back out of the
    exact channel the gate scans, and fails if any planted defect is not caught
    or if the clean fixture fires.

    PS 5.1. ASCII only in this file.
    Exit 0 clean, 1 blocking finding(s), 2 usage or input error, 4 self-test failed.
#>

[CmdletBinding()]
param(
    [string] $BuildDir,
    [string] $SpineDir,
    [string] $ContractPath,
    #  The RTO profile pack. Resolved from the contract's brand when not given.
    [string] $Profile,
    #  The docx-images sub-skill config. Resolved as a sibling skill when not given.
    [string] $ImagesConfig,
    [string] $SkillDir,
    [string] $ReportPath,
    #  Typographic estimators. Not declared by the profile or the sub-skill
    #  config, so they live here as parameters and their values are PRINTED.
    [double] $CellPaddingCm  = 0.10,
    [double] $NodeGapCm      = 1.00,
    [double] $AvgCharEmShare = 0.50,
    #  Non-zero overrides the derived per-node height outright.
    [double] $NodeHeightCm   = 0,
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

$GATE = 'Assert-SpecRenderable'

# ---------------------------------------------------------------------------
# Private helpers, named Sr* so nothing here can shadow a shared one
# ---------------------------------------------------------------------------

function Get-SrArray {
    <# @($null).Count is 1, not 0. Everything that iterates a maybe-absent
       property goes through here. #>
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

function Write-SrJson {
    param([Parameter(Mandatory)] $Object, [Parameter(Mandatory)][string] $Path)
    $json = $Object | ConvertTo-Json -Depth 14
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($true)))
}

function Resolve-SrProfilePath {
    param([string] $ProfilePath, [string] $Build, [string] $Skill, [switch] $AnyForSelfTest)
    if ($ProfilePath) {
        if (-not (Test-Path -LiteralPath $ProfilePath)) { throw "$GATE`: -Profile not found: $ProfilePath" }
        return (Resolve-Path -LiteralPath $ProfilePath).Path
    }
    $assets = Join-Path $Skill 'assets'
    $brand = ''
    if ($Build) {
        $c = Get-GateContract -BuildDir $Build
        if ($null -ne $c -and @($c.PSObject.Properties.Name) -contains 'build') {
            $brand = '' + (Get-GateProp -Object $c.build -Names @('rto', 'brand') -Default '')
        }
    }
    $packs = @(Get-ChildItem -LiteralPath $assets -Filter 'rto-profile.*.json' -File -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -notmatch '(?i)schema' })
    if ($brand) {
        $cand = @($packs | Where-Object { $_.Name -ieq ('rto-profile.' + $brand + '.json') })
        if ($cand.Count -gt 0) { return $cand[0].FullName }
    }
    if ($AnyForSelfTest -and $packs.Count -gt 0) { return $packs[0].FullName }
    throw ("$GATE`: no RTO profile. Pass -Profile, or a -BuildDir whose contract.json names build.brand with a matching assets\rto-profile.<brand>.json. The column height is arithmetic over the page geometry the profile declares; a gate that types a column height is a second source of truth free to drift from the template.")
}

function Resolve-SrImagesConfig {
    <#  The docx-images sub-skill's own config. It is the source of truth for
        the box cap, the renderer map and the placement caps, so it is READ -
        looked for beside this skill, then under the skills root that contains
        this skill.  #>
    param([string] $Given, [string] $Skill)
    if ($Given) {
        if (-not (Test-Path -LiteralPath $Given)) { throw "$GATE`: -ImagesConfig not found: $Given" }
        return (Resolve-Path -LiteralPath $Given).Path
    }
    $root = Split-Path -Parent $Skill
    $cands = @(
        (Join-Path $root 'docx-images\config\defaults.json'),
        (Join-Path $Skill 'config\defaults.json')
    )
    foreach ($c in $cands) { if (Test-Path -LiteralPath $c) { return (Resolve-Path -LiteralPath $c).Path } }
    throw ("$GATE`: the docx-images config was not found. Looked in:`n{0}`nThe box cap, the renderer map and the placement caps are READ from it. Without it this gate would have to type the sub-skill's own numbers, and a typed cap is a cap free to drift from the renderer that enforces it." -f (($cands | ForEach-Object { "  $_" }) -join "`n"))
}

function Get-SrRenderCaps {
    <#  Everything the two declared files say about what can be drawn, in one
        object, with the file each number came from recorded beside it.  #>
    param([string] $ProfileFile, [string] $ConfigFile, [string] $Skill)

    $pack = Get-GateJson -Path $ProfileFile
    if ($null -eq $pack) { throw "$GATE`: RTO profile at $ProfileFile did not parse." }
    $gpRel = '' + (Get-GateProp -Object $pack -Names @('guideProfile') -Default '')
    $gpPath = ''
    if ($gpRel) {
        foreach ($c in @((Join-Path $Skill $gpRel), (Join-Path (Split-Path -Parent $ProfileFile) (Split-Path -Leaf $gpRel)))) {
            if (Test-Path -LiteralPath $c) { $gpPath = (Resolve-Path -LiteralPath $c).Path; break }
        }
    }
    if (-not $gpPath) {
        throw ("$GATE`: the RTO profile names guideProfile '{0}' and no such file is on disk. Page height, margins and content width live there and the column height is arithmetic over them." -f $gpRel)
    }
    $gp = Get-GateJson -Path $gpPath
    $page = Get-GateProp -Object $gp -Names @('page') -Required -What 'page geometry block in the guide profile'

    $hDxa   = [double](Get-GateProp -Object $page -Names @('heightDxa') -Required -What 'page.heightDxa')
    $mTop   = [double](Get-GateProp -Object $page -Names @('marginTop') -Required -What 'page.marginTop')
    $mBot   = [double](Get-GateProp -Object $page -Names @('marginBottom') -Required -What 'page.marginBottom')
    $cwDxa  = [double](Get-GateProp -Object $page -Names @('contentWidthDxa') -Required -What 'page.contentWidthDxa')

    #  1440 dxa to the inch, 2.54 cm to the inch. Arithmetic, not a constant
    #  about this build.
    $colHeightCm = (($hDxa - $mTop - $mBot) / 1440.0) * 2.54
    $colWidthCm  = ($cwDxa / 1440.0) * 2.54

    $cfg = Get-GateJson -Path $ConfigFile
    if ($null -eq $cfg) { throw "$GATE`: the docx-images config at $ConfigFile did not parse." }
    $dia = Get-GateProp -Object $cfg -Names @('diagram') -Required -What 'diagram block in the docx-images config'
    $maxNodes = [int](Get-GateProp -Object $dia -Names @('maxNodes') -Required -What 'diagram.maxNodes (the canvas box cap)')
    $rendMap  = Get-GateProp -Object $dia -Names @('renderer') -Required -What 'diagram.renderer (which layout is a canvas and which is a table)'
    $typo     = Get-GateProp -Object $dia -Names @('typography')
    $halfPt   = [double](Get-GateProp -Object $typo -Names @('tableHalfPt') -Default 20)

    $place    = Get-GateProp -Object $cfg -Names @('placement') -Required -What 'placement block in the docx-images config'
    $maxHCm   = [double](Get-GateProp -Object $place -Names @('maxHeightCm') -Required -What 'placement.maxHeightCm')
    $wf       = Get-GateProp -Object $place -Names @('widthFraction')
    $wfDiagram = [double](Get-GateProp -Object $wf -Names @('diagram') -Default 1.0)

    $renderers = @{}
    $tableLayouts = New-Object System.Collections.Generic.List[string]
    foreach ($p in @($rendMap.PSObject.Properties.Name)) {
        if ($p -like '_*') { continue }
        $r = ('' + $rendMap.$p).ToLowerInvariant()
        $renderers[$p.ToLowerInvariant()] = $r
        if ($r -eq 'table') { $tableLayouts.Add($p) }
    }
    if ($renderers.Count -eq 0) { throw "$GATE`: diagram.renderer in the docx-images config is empty. With no renderer map there is no declared capability to check a spec against." }

    #  Line height is arithmetic over the declared font size: half-points to
    #  points to inches to centimetres, at the house 1.15 list line spacing
    #  where the guide profile declares one.
    $fontPt = $halfPt / 2.0
    $lineSpacing = 1.15
    $typoG = Get-GateProp -Object $gp -Names @('typography')
    if ($null -ne $typoG) { $lineSpacing = [double](Get-GateProp -Object $typoG -Names @('listLineSpacing') -Default 1.15) }
    $lineCm = ($fontPt * $lineSpacing / 72.0) * 2.54

    return [pscustomobject]@{
        ProfilePath   = $ProfileFile
        GuideProfile  = $gpPath
        ConfigPath    = $ConfigFile
        ColHeightCm   = $colHeightCm
        ColWidthCm    = $colWidthCm
        MaxNodes      = $maxNodes
        Renderers     = $renderers
        TableLayouts  = $tableLayouts.ToArray()
        MaxHeightCm   = $maxHCm
        DiagramWidthFraction = $wfDiagram
        FontPt        = $fontPt
        LineSpacing   = $lineSpacing
        LineCm        = $lineCm
    }
}

# ---------------------------------------------------------------------------
# Reading a spec: shape, node count, branch semantics, projected height
# ---------------------------------------------------------------------------

#  THE BRANCH DETECTORS ARE STRUCTURAL, NOT A VOCABULARY. A word list would
#  fire on "decide", "check" and "if" in ordinary prose and would miss the
#  branch that says "otherwise". These three are shapes:
#    - a declared branch-bearing field on the spec or on a node;
#    - the toolchain's own '||' separator between alternative outcomes, which
#      is what a converted flow writes into its Then column;
#    - a node label that is a question, which is what a decision node IS.
$script:SrBranchFields = @('branches', 'branch', 'decision', 'decisions', 'yes', 'no', 'else', 'otherwise')
$script:SrAltSeparator = '||'

function Get-SrSpecShape {
    <#  Reduce a spec to the numbers this gate reasons about: its layout, its
        node or row count, its widest row, whether it carries branch semantics,
        and the longest cell in each column.  #>
    param($Spec)

    $layout = ('' + (Get-GateProp -Object $Spec -Names @('layout', 'kind', 'type') -Default '')).ToLowerInvariant()
    $rows = @()
    $shape = 'none'

    $r = Get-SrArray (Get-GateProp -Object $Spec -Names @('rows'))
    if ($r.Count -gt 0 -and ($r[0] -is [System.Collections.IEnumerable]) -and ($r[0] -isnot [string])) {
        $rows = $r; $shape = 'rows'
    }
    $nodeList = @()
    foreach ($ln in @('nodes', 'steps', 'items', 'stages', 'bands')) {
        $v = Get-SrArray (Get-GateProp -Object $Spec -Names @($ln))
        if ($v.Count -gt 0) { $nodeList = $v; if ($shape -eq 'none') { $shape = $ln }; break }
    }

    #  Node count. For a rows-shaped spec every row after the heading row is a
    #  box the canvas renderer would have to draw.
    $nodeCount = 0
    if ($nodeList.Count -gt 0) { $nodeCount = $nodeList.Count }
    elseif ($rows.Count -gt 0) {
        $hasHeader = [bool](Get-GateProp -Object $Spec -Names @('headerRow') -Default $false)
        $nodeCount = if ($hasHeader) { $rows.Count - 1 } else { $rows.Count }
    }

    #  Every cell, as text, with its column index - the raw material for both
    #  the height projection and the branch detectors.
    $cells = New-Object System.Collections.Generic.List[object]
    $rowIndex = 0
    foreach ($row in $rows) {
        $ci = 0
        foreach ($c in (Get-SrArray $row)) {
            $cells.Add([pscustomobject]@{ Row = $rowIndex; Col = $ci; Text = "$c" })
            $ci++
        }
        $rowIndex++
    }
    $ni = 0
    foreach ($nd in $nodeList) {
        $t = ''
        if ($nd -is [string]) { $t = $nd }
        elseif ($null -ne $nd -and $nd.PSObject) {
            $lab = Get-GateProp -Object $nd -Names @('label', 'text', 'title', 'name')
            $val = Get-GateProp -Object $nd -Names @('value', 'detail', 'note', 'then')
            $t = if ($val) { "{0}: {1}" -f $lab, $val } else { "$lab" }
        }
        $cells.Add([pscustomobject]@{ Row = $ni; Col = 0; Text = "$t" })
        $ni++
    }

    #  ---- branch semantics, structurally
    $branchWhy = New-Object System.Collections.Generic.List[string]
    $specProps = @()
    if ($null -ne $Spec) { $specProps = @($Spec.PSObject.Properties.Name) }
    foreach ($f in $script:SrBranchFields) {
        if ($specProps -contains $f -and $Spec.$f) { $branchWhy.Add(("the spec declares a '{0}' field" -f $f)) }
    }
    foreach ($nd in $nodeList) {
        if ($null -eq $nd -or $nd -is [string]) { continue }
        foreach ($f in $script:SrBranchFields) {
            if ((@($nd.PSObject.Properties.Name) -contains $f) -and $nd.$f) { $branchWhy.Add(("a node declares a '{0}' field" -f $f)) }
        }
    }
    $altCells = 0; $questionCells = 0
    foreach ($c in $cells) {
        if ($c.Text.Contains($script:SrAltSeparator)) { $altCells++ }
        if ($c.Text -match '\?\s*$') { $questionCells++ }
    }
    if ($altCells -gt 0)      { $branchWhy.Add(("{0} cell(s) carry the '{1}' alternative separator" -f $altCells, $script:SrAltSeparator)) }
    if ($questionCells -gt 0) { $branchWhy.Add(("{0} node label(s) are a question, which is what a decision node is" -f $questionCells)) }

    return [pscustomobject]@{
        Layout    = $layout
        Shape     = $shape
        Rows      = $rows.Count
        NodeCount = $nodeCount
        Cols      = $(if ($rows.Count -gt 0) { ($cells | Where-Object { $_.Row -eq 0 } | Measure-Object).Count } else { 1 })
        Cells     = $cells.ToArray()
        HasBranch = ($branchWhy.Count -gt 0)
        BranchWhy = @($branchWhy | Select-Object -Unique)
    }
}

function Get-SrProjectedHeight {
    <#  How tall will this be on the page?

        A TABLE: sum over rows of (the tallest cell in the row) where a cell's
        height is its wrapped line count times the derived line height, plus a
        cell padding top and bottom. Wrapping is character count against the
        column's own share of the content width, at the declared font size and
        an average character advance of -AvgCharEmShare em.

        A CANVAS: the box count times a per-node height, which is the tallest
        node label wrapped over the canvas width plus padding plus the
        connector gap - or -NodeHeightCm outright where one is given.

        Every input except the three estimators comes from the profile and the
        sub-skill config, and all of them are printed.  #>
    param($Shape, $Caps, [double] $PaddingCm, [double] $GapCm, [double] $CharEm, [double] $NodeOverrideCm)

    $usableCm = $Caps.ColWidthCm * $Caps.DiagramWidthFraction
    if ($usableCm -le 0) { $usableCm = $Caps.ColWidthCm }
    $charCm = ($Caps.FontPt * $CharEm / 72.0) * 2.54
    if ($charCm -le 0) { $charCm = 0.1 }

    if ($Shape.Rows -gt 0) {
        $cols = [Math]::Max(1, $Shape.Cols)
        $colCm = $usableCm / $cols
        $perLine = [Math]::Max(6, [int][Math]::Floor($colCm / $charCm))
        $total = 0.0
        for ($r = 0; $r -lt $Shape.Rows; $r++) {
            $maxLines = 1
            foreach ($c in $Shape.Cells) {
                if ($c.Row -ne $r) { continue }
                #  Ceiling, explicitly. [int] ROUNDS in PowerShell, it does not
                #  truncate, and a rounded line count under-projects the height
                #  of exactly the long cell that overflows.
                $lines = [int][Math]::Ceiling([double]$c.Text.Length / [double]$perLine)
                if ($lines -lt 1) { $lines = 1 }
                if ($lines -gt $maxLines) { $maxLines = $lines }
            }
            $total += ($maxLines * $Caps.LineCm) + (2.0 * $PaddingCm)
        }
        return [pscustomobject]@{ Cm = $total; Basis = ("{0} row(s), {1} column(s), {2} char(s) a line at {3:N1} pt" -f $Shape.Rows, $cols, $perLine, $Caps.FontPt) }
    }

    if ($Shape.NodeCount -gt 0) {
        $nodeCm = $NodeOverrideCm
        $basis = ''
        if ($nodeCm -gt 0) { $basis = ("-NodeHeightCm {0:N2} cm a node, given" -f $nodeCm) }
        else {
            $perLine = [Math]::Max(6, [int][Math]::Floor($usableCm / $charCm))
            $maxLines = 1
            foreach ($c in $Shape.Cells) {
                $lines = [int][Math]::Ceiling([double]$c.Text.Length / [double]$perLine)
                if ($lines -gt $maxLines) { $maxLines = $lines }
            }
            $nodeCm = ($maxLines * $Caps.LineCm) + (2.0 * $PaddingCm) + $GapCm
            $basis = ("{0:N2} cm a node: {1} label line(s) at {2:N1} pt, plus padding and a {3:N2} cm connector gap" -f $nodeCm, $maxLines, $Caps.FontPt, $GapCm)
        }
        return [pscustomobject]@{ Cm = ($Shape.NodeCount * $nodeCm); Basis = ("{0} box(es), {1}" -f $Shape.NodeCount, $basis) }
    }

    return [pscustomobject]@{ Cm = 0.0; Basis = 'no rows and no nodes - nothing to project' }
}

# ---------------------------------------------------------------------------
# Reading the spine
# ---------------------------------------------------------------------------

function Get-SrSpineText {
    <# Every string on the spine, so a figure cross-reference can be found. #>
    param($Node, [int] $Depth = 0)
    if ($null -eq $Node -or $Depth -gt 24) { return }
    if ($Node -is [string]) { if ("$Node".Trim()) { [string]$Node }; return }
    if ($Node -is [ValueType]) { return }
    if ($Node -is [System.Collections.IEnumerable]) {
        foreach ($i in $Node) { Get-SrSpineText -Node $i -Depth ($Depth + 1) }
        return
    }
    foreach ($p in @($Node.PSObject.Properties.Name)) {
        if ($p -like '_*') { continue }
        Get-SrSpineText -Node $Node.$p -Depth ($Depth + 1)
    }
}

function Invoke-SpecRenderable {
    param(
        [Parameter(Mandatory)][string] $Build,
        [string] $Spine,
        [string] $Contract,
        [Parameter(Mandatory)] $Caps,
        [double] $PaddingCm,
        [double] $GapCm,
        [double] $CharEm,
        [double] $NodeOverrideCm
    )

    $findings = New-Object System.Collections.Generic.List[object]
    $notes = New-Object System.Collections.Generic.List[object]

    if (-not $Spine) { $Spine = Join-Path $Build 'spine' }
    $contractDoc = if ($Contract) { Get-GateJson -Path $Contract } else { Get-GateContract -BuildDir $Build }

    $spineFiles = @(Get-ChildItem -LiteralPath $Spine -Filter '*.json' -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -notmatch '\.gate\.json$' -and $_.Name -notmatch '\.result\.json$' } |
                    Sort-Object Name)
    if ($spineFiles.Count -eq 0) {
        throw ("$GATE`: no spine JSON under {0}. A spec that is not on the spine cannot be gated, and a build that hand-types its specs inside a build script is the failure this gate exists for." -f $Spine)
    }

    #  ---- every visual, and every slot the spine defines
    $visuals = New-Object System.Collections.Generic.List[object]
    $definedSlots = @{}
    $refFiles = New-Object System.Collections.Generic.List[object]
    $allText = New-Object System.Text.StringBuilder

    foreach ($f in $spineFiles) {
        $j = Get-GateJson -Path $f.FullName
        if ($null -eq $j) { continue }
        foreach ($s in (Get-SrSpineText -Node $j)) { [void]$allText.Append(' ').Append($s) }
        $props = @($j.PSObject.Properties.Name)
        $ref = '' + (Get-GateProp -Object $j -Names @('ref') -Default '')
        if ($ref -and ($props -contains 'visuals')) { $refFiles.Add([pscustomobject]@{ File = $f.Name; Ref = $ref }) }
        if ($props -notcontains 'visuals') { continue }
        $vi = 0
        foreach ($v in (Get-SrArray $j.visuals)) {
            $slot = '' + (Get-GateProp -Object $v -Names @('slot', 'figure', 'number') -Default '')
            $visuals.Add([pscustomobject]@{
                File = $f.Name; Index = $vi; Ref = $ref; Slot = $slot
                Kind = '' + (Get-GateProp -Object $v -Names @('kind', 'type') -Default '')
                Spec = (Get-GateProp -Object $v -Names @('spec'))
                Node = $v
            })
            if ($slot) { $definedSlots[$slot] = $true }
            $vi++
        }
    }

    # -----------------------------------------------------------------------
    # SR-KIND-DECLARED, SR-SLOT-NO-SPEC (missing spec on a drawn visual)
    # -----------------------------------------------------------------------
    #  WHICH KINDS ARE DRAWN is derived, not typed: the docx-images config's
    #  renderer map names the layouts it can draw, and a visual is DRAWN when it
    #  carries a spec or when its kind matches a renderer-declared class. A
    #  visual with no kind at all is a failure before any of that: the manifest
    #  is seeded BY SLOT from the spine, and a visual that does not say what it
    #  is leaves the sub-skill guessing from prompt text.
    $drawnKinds = @{}
    foreach ($k in $Caps.Renderers.Keys) { $drawnKinds[$k] = $true }
    $drawnKinds['diagram'] = $true

    $specsChecked = 0; $imageVisuals = 0
    foreach ($v in $visuals) {
        $where = "{0}:visuals[{1}] slot '{2}'" -f $v.File, $v.Index, $(if ($v.Slot) { $v.Slot } else { '(none)' })
        if (-not ('' + $v.Kind).Trim()) {
            $findings.Add([pscustomobject]@{
                Rule = 'SR-KIND-DECLARED'; Level = 'BLOCK'; Slot = $v.Slot; File = $v.File
                Detail = ("{0}: no explicit kind on the spine. The artwork manifest is seeded BY SLOT from the spine; with no kind the sub-skill infers one from prompt text, which turned four photographs into diagrams on one build." -f $where)
            })
            continue
        }
        $kindN = ('' + $v.Kind).ToLowerInvariant()
        $isDrawn = ($null -ne $v.Spec) -or $drawnKinds.ContainsKey($kindN)
        if (-not $isDrawn) { $imageVisuals++; continue }
        if ($null -eq $v.Spec) {
            $findings.Add([pscustomobject]@{
                Rule = 'SR-SLOT-NO-SPEC'; Level = 'BLOCK'; Slot = $v.Slot; File = $v.File
                Detail = ("{0}: kind '{1}' will be DRAWN and the spine carries no spec for it. On one build the diagram specs were hand-typed inside a build script and three rounds of spine corrections never reached them." -f $where, $v.Kind)
            })
            continue
        }

        $specsChecked++
        $shape = Get-SrSpecShape -Spec $v.Spec
        $renderer = 'canvas'
        if ($shape.Layout -and $Caps.Renderers.ContainsKey($shape.Layout)) { $renderer = $Caps.Renderers[$shape.Layout] }
        elseif (-not $shape.Layout) { $renderer = 'canvas' }

        # ---- SR-NODE-CAP
        if ($renderer -ne 'table' -and $shape.NodeCount -gt $Caps.MaxNodes) {
            $findings.Add([pscustomobject]@{
                Rule = 'SR-NODE-CAP'; Level = 'BLOCK'; Slot = $v.Slot; File = $v.File
                Detail = ("{0}: layout '{1}' renders as a {2} and the spec has {3} box(es) against the declared cap of {4}. Split it, or set the layout to one the config's renderer map sends to a real Word table: {5}." -f $where, $shape.Layout, $renderer, $shape.NodeCount, $Caps.MaxNodes, ($Caps.TableLayouts -join ', '))
            })
        }

        # ---- SR-HEIGHT-COLUMN and SR-HEIGHT-PLACEMENT
        $proj = Get-SrProjectedHeight -Shape $shape -Caps $Caps -PaddingCm $PaddingCm -GapCm $GapCm -CharEm $CharEm -NodeOverrideCm $NodeOverrideCm
        if ($proj.Cm -gt $Caps.ColHeightCm) {
            $findings.Add([pscustomobject]@{
                Rule = 'SR-HEIGHT-COLUMN'; Level = 'BLOCK'; Slot = $v.Slot; File = $v.File
                Detail = ("{0}: projects to {1:N1} cm against a {2:N1} cm column derived from the page's own geometry ({3}). It does not fit the page and no placement scaling can make it." -f $where, $proj.Cm, $Caps.ColHeightCm, $proj.Basis)
            })
        }
        elseif ($proj.Cm -gt $Caps.MaxHeightCm) {
            $notes.Add([pscustomobject]@{
                Rule = 'SR-HEIGHT-PLACEMENT'; Level = 'REPORT'; Slot = $v.Slot; File = $v.File
                Detail = ("{0}: projects to {1:N1} cm against the {2:N1} cm placement cap ({3}). The placement pass scales to the cap, so this is legibility rather than fit." -f $where, $proj.Cm, $Caps.MaxHeightCm, $proj.Basis)
            })
        }

        # ---- SR-BRANCH-CAPABILITY
        if ($shape.HasBranch -and $renderer -ne 'table') {
            $findings.Add([pscustomobject]@{
                Rule = 'SR-BRANCH-CAPABILITY'; Level = 'BLOCK'; Slot = $v.Slot; File = $v.File
                Detail = ("{0}: carries branch or decision semantics ({1}) and layout '{2}' renders as a {3}, which the config declares no branch capability for. A branch drawn on a renderer that cannot carry one is flattened silently - one build lost a branch and the figure then taught the opposite of the rule. Use a table layout instead: {4}." -f $where, ($shape.BranchWhy -join '; '), $shape.Layout, $renderer, ($Caps.TableLayouts -join ', '))
            })
        }
    }

    # -----------------------------------------------------------------------
    # SR-SLOT-NO-SPEC (an expected slot with no visual at all)
    # -----------------------------------------------------------------------
    #  The per-sub-section visual count is DECLARED in the contract. Without it
    #  there is no declared slot set and this arm says so rather than passing.
    $perSub = 0
    if ($null -ne $contractDoc) {
        $vBlock = Get-GateProp -Object $contractDoc -Names @('visuals')
        if ($null -ne $vBlock) { $perSub = [int]('0' + ('' + (Get-GateProp -Object $vBlock -Names @('perSubSection') -Default 0))) }
    }
    $expectedSlots = 0
    if ($perSub -gt 0) {
        foreach ($rf in $refFiles) {
            for ($i = 1; $i -le $perSub; $i++) {
                $want = "{0}.{1}" -f $rf.Ref, $i
                $expectedSlots++
                if (-not $definedSlots.ContainsKey($want)) {
                    $findings.Add([pscustomobject]@{
                        Rule = 'SR-SLOT-NO-SPEC'; Level = 'BLOCK'; Slot = $want; File = $rf.File
                        Detail = ("{0}: the contract declares {1} visual(s) a sub-section and slot '{2}' has no visual on the spine at all." -f $rf.File, $perSub, $want)
                    })
                }
            }
        }
    }
    else {
        $notes.Add([pscustomobject]@{
            Rule = 'SR-SLOT-NO-SPEC'; Level = 'REPORT'; Slot = ''; File = 'contract.json'
            Detail = 'the contract declares no visuals.perSubSection, so the expected-slot arm had no declared slot set to check. It checked nothing, which is recorded here rather than counted as a pass.'
        })
    }

    # -----------------------------------------------------------------------
    # SR-SLOT-DANGLING
    # -----------------------------------------------------------------------
    #  A figure cross-reference the spine writes and no visual defines. The
    #  pattern is the sub-skill's own caption prefix followed by a dotted
    #  ordinal, which is the shape every slot on this spine takes.
    $xrefs = 0
    $seenDangling = @{}
    foreach ($m in [regex]::Matches($allText.ToString(), '(?i)\bfigure\s+(\d+(?:\.\d+)+)')) {
        $slot = $m.Groups[1].Value
        $xrefs++
        if ($definedSlots.ContainsKey($slot)) { continue }
        if ($seenDangling.ContainsKey($slot)) { continue }
        $seenDangling[$slot] = $true
        $findings.Add([pscustomobject]@{
            Rule = 'SR-SLOT-DANGLING'; Level = 'BLOCK'; Slot = $slot; File = '(spine text)'
            Detail = ("a cross-reference names Figure {0} and no visual on the spine defines that slot" -f $slot)
        })
    }

    return [pscustomobject]@{
        Findings = $findings.ToArray()
        Notes    = $notes.ToArray()
        Stats    = [pscustomobject]@{
            spineFiles = $spineFiles.Count
            visuals = $visuals.Count
            specsChecked = $specsChecked
            imageVisualsSkipped = $imageVisuals
            definedSlots = $definedSlots.Count
            expectedSlots = $expectedSlots
            perSubSectionDeclared = $perSub
            figureCrossReferences = $xrefs
        }
    }
}

# ---------------------------------------------------------------------------
# SELF-TEST
# ---------------------------------------------------------------------------

function New-SrFixture {
    <#  A synthetic build: a contract declaring one visual a sub-section, and a
        spine with one correct table spec. Nothing here names a unit, an RTO or
        a brand.  #>
    param([Parameter(Mandatory)][string] $Root)

    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Root 'spine') -Force | Out-Null

    Write-SrJson -Path (Join-Path $Root 'contract.json') -Object ([ordered]@{
        build = [ordered]@{ brand = '' }
        visuals = [ordered]@{ perSubSection = 1 }
    })

    Write-SrJson -Path (Join-Path $Root 'spine\t1_1.1.json') -Object ([ordered]@{
        ref = '1.1'; pc = '1.1'; topic = '1'; title = 'Shape one'
        whatThisMeans = 'Body prose that names Figure 1.1.1 and nothing else.'
        visuals = @(
            [ordered]@{
                slot = '1.1.1'; kind = 'Diagram'
                caption = 'A short caption'
                alt = 'A three row table.'
                spec = [ordered]@{
                    layout = 'table'; headerRow = $true
                    rows = @(
                        @('Step', 'What you do'),
                        @('1', 'Read the line'),
                        @('2', 'Set the tray out')
                    )
                }
            }
        )
    })
    return $Root
}

function Invoke-SrSelfTest {
    param([string] $Skill, [string] $ConfigGiven, [double] $PaddingCm, [double] $GapCm, [double] $CharEm, [double] $NodeOverrideCm)

    $script:SrOk = 0; $script:SrBad = 0
    function Ok  { param([string] $M) Write-Host ("    ok   {0}" -f $M) -ForegroundColor Green; $script:SrOk++ }
    function Bad { param([string] $M) Write-Host ("    X    {0}" -f $M) -ForegroundColor Red;   $script:SrBad++ }

    $prof = Resolve-SrProfilePath -ProfilePath '' -Build '' -Skill $Skill -AnyForSelfTest
    $cfg  = Resolve-SrImagesConfig -Given $ConfigGiven -Skill $Skill
    $caps = Get-SrRenderCaps -ProfileFile $prof -ConfigFile $cfg -Skill $Skill
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('sr-selftest-' + [Guid]::NewGuid().ToString('N').Substring(0, 12))

    function Test-SrPlantLanded {
        param([string] $Path, [scriptblock] $Probe, [string] $What)
        $j = Get-GateJson -Path $Path
        $landed = $false
        try { $landed = [bool](& $Probe $j) } catch { $landed = $false }
        if ($landed) { Write-Host ("    plant landed: {0}" -f $What) -ForegroundColor DarkGray; return $true }
        Write-Host ("    X plant did NOT land: {0} - this proves nothing." -f $What) -ForegroundColor Red
        return $false
    }

    function Test-SrFires {
        param([string] $Build, [string] $Rule, [string] $What, [switch] $Expect)
        $r = $null
        try { $r = Invoke-SpecRenderable -Build $Build -Caps $caps -PaddingCm $PaddingCm -GapCm $GapCm -CharEm $CharEm -NodeOverrideCm $NodeOverrideCm }
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
        Write-Host ("  SELF-TEST (profile {0}, config {1}; cap {2} boxes, column {3:N1} cm)" -f (Split-Path -Leaf $prof), (Split-Path -Leaf $cfg), $caps.MaxNodes, $caps.ColHeightCm) -ForegroundColor Cyan

        # ---- CASE 0: clean
        $c0 = Join-Path $root 'clean'
        New-SrFixture -Root $c0 | Out-Null
        $r0 = $null
        try { $r0 = Invoke-SpecRenderable -Build $c0 -Caps $caps -PaddingCm $PaddingCm -GapCm $GapCm -CharEm $CharEm -NodeOverrideCm $NodeOverrideCm }
        catch { Bad ("clean fixture: the gate threw - {0}" -f $_.Exception.Message) }
        if ($null -ne $r0) {
            if (@($r0.Findings).Count -eq 0) { Ok 'clean fixture: no blocking finding on a drawable spec' }
            else { Bad ("clean fixture fired {0}: {1}" -f @($r0.Findings).Count, (@($r0.Findings | ForEach-Object { $_.Rule + ' / ' + $_.Detail }) -join ' | ')) }
        }

        # ---- CASE 1: over the box cap on a canvas renderer
        $c1 = Join-Path $root 'p1'
        New-SrFixture -Root $c1 | Out-Null
        $p = Join-Path $c1 'spine\t1_1.1.json'
        $j = Get-GateJson -Path $p
        $over = $caps.MaxNodes + 3
        $nodes = @()
        for ($i = 1; $i -le $over; $i++) { $nodes += ("Step {0}" -f $i) }
        $j.visuals[0].spec = [pscustomobject]@{ layout = 'process'; nodes = $nodes }
        Write-SrJson -Object $j -Path $p
        if (Test-SrPlantLanded -Path $p -What ("a 'process' spec of {0} nodes against a cap of {1}" -f $over, $caps.MaxNodes) -Probe {
                param($d) (@($d.visuals[0].spec.nodes).Count -gt $caps.MaxNodes) -and ($d.visuals[0].spec.layout -eq 'process')
            }) {
            Test-SrFires -Build $c1 -Rule 'SR-NODE-CAP' -What 'spec exceeding the renderer box cap' -Expect
        } else { Bad 'plant 1 did not land' }

        # ---- CASE 2: projected height overflows the column
        $c2 = Join-Path $root 'p2'
        New-SrFixture -Root $c2 | Out-Null
        $p = Join-Path $c2 'spine\t1_1.1.json'
        $j = Get-GateJson -Path $p
        $rows = @(, @('Step', 'What you do'))
        for ($i = 1; $i -le 40; $i++) {
            $rows += , @([string]$i, ('A long instruction line that wraps over more than one line in its column and is repeated forty times over, entry ' + $i))
        }
        $j.visuals[0].spec = [pscustomobject]@{ layout = 'table'; headerRow = $true; rows = $rows }
        Write-SrJson -Object $j -Path $p
        if (Test-SrPlantLanded -Path $p -What 'a table spec of 41 rows of wrapping text' -Probe {
                param($d) @($d.visuals[0].spec.rows).Count -ge 41
            }) {
            Test-SrFires -Build $c2 -Rule 'SR-HEIGHT-COLUMN' -What 'spec whose projected height overflows the column' -Expect
        } else { Bad 'plant 2 did not land' }

        # ---- CASE 3: a declared slot with no spine spec
        $c3 = Join-Path $root 'p3'
        New-SrFixture -Root $c3 | Out-Null
        $p = Join-Path $c3 'spine\t1_1.1.json'
        $j = Get-GateJson -Path $p
        $j.visuals = @()
        Write-SrJson -Object $j -Path $p
        if (Test-SrPlantLanded -Path $p -What "slot 1.1.1 is declared by the contract and the spine now defines no visual for it" -Probe {
                param($d) @($d.visuals).Count -eq 0
            }) {
            Test-SrFires -Build $c3 -Rule 'SR-SLOT-NO-SPEC' -What 'declared slot with no spine spec' -Expect
        } else { Bad 'plant 3 did not land' }

        # ---- CASE 4: branch semantics on a renderer with no branch capability
        $c4 = Join-Path $root 'p4'
        New-SrFixture -Root $c4 | Out-Null
        $p = Join-Path $c4 'spine\t1_1.1.json'
        $j = Get-GateJson -Path $p
        $j.visuals[0].spec = [pscustomobject]@{
            layout = 'process'
            nodes = @('Read the line', 'Does one vessel hold the batch?', 'Set the tray out')
        }
        Write-SrJson -Object $j -Path $p
        if (Test-SrPlantLanded -Path $p -What "a 'process' (canvas) spec carrying a decision node" -Probe {
                param($d) ($d.visuals[0].spec.layout -eq 'process') -and ((@($d.visuals[0].spec.nodes) -join ' ') -match '\?')
            }) {
            Test-SrFires -Build $c4 -Rule 'SR-BRANCH-CAPABILITY' -What 'branch semantics on a renderer that declares none' -Expect
        } else { Bad 'plant 4 did not land' }

        # ---- CASE 5: a visual with no kind
        $c5 = Join-Path $root 'p5'
        New-SrFixture -Root $c5 | Out-Null
        $p = Join-Path $c5 'spine\t1_1.1.json'
        $j = Get-GateJson -Path $p
        $j.visuals[0].kind = ''
        Write-SrJson -Object $j -Path $p
        if (Test-SrPlantLanded -Path $p -What 'the visual now declares no kind' -Probe {
                param($d) -not ('' + $d.visuals[0].kind).Trim()
            }) {
            Test-SrFires -Build $c5 -Rule 'SR-KIND-DECLARED' -What 'visual with no explicit kind on the spine' -Expect
        } else { Bad 'plant 5 did not land' }

        # ---- CASE 6: a dangling figure cross-reference
        $c6 = Join-Path $root 'p6'
        New-SrFixture -Root $c6 | Out-Null
        $p = Join-Path $c6 'spine\t1_1.1.json'
        $j = Get-GateJson -Path $p
        $j.whatThisMeans = 'Body prose that names Figure 1.1.9, which nothing defines.'
        Write-SrJson -Object $j -Path $p
        if (Test-SrPlantLanded -Path $p -What 'prose references Figure 1.1.9 and no visual defines slot 1.1.9' -Probe {
                param($d) ('' + $d.whatThisMeans) -match 'Figure 1\.1\.9'
            }) {
            Test-SrFires -Build $c6 -Rule 'SR-SLOT-DANGLING' -What 'cross-reference to a slot no visual defines' -Expect
        } else { Bad 'plant 6 did not land' }

        # ---- CASE 7: the same branch semantics on a TABLE renderer must NOT fire
        $c7 = Join-Path $root 'p7'
        New-SrFixture -Root $c7 | Out-Null
        $p = Join-Path $c7 'spine\t1_1.1.json'
        $j = Get-GateJson -Path $p
        $j.visuals[0].spec = [pscustomobject]@{
            layout = 'table'; headerRow = $true
            rows = @(
                , @('Step', 'What you do', 'Then')
                , @('1', 'Read the line', 'Go to the check')
                , @('Decide', 'Does one vessel hold the batch?', 'Yes: set the tray out||No: split the batch')
            )
        }
        Write-SrJson -Object $j -Path $p
        Test-SrFires -Build $c7 -Rule 'SR-BRANCH-CAPABILITY' -What 'the same branch carried by a table layout, which the config declares as branch-capable'
    }
    finally {
        if ((Test-Path -LiteralPath $root) -and $root.Length -gt 12) {
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host ''
    if ($script:SrBad -gt 0) { Write-Host ("  SELF-TEST FAILED - {0} of {1} check(s) failed" -f $script:SrBad, ($script:SrOk + $script:SrBad)) -ForegroundColor Red }
    else                     { Write-Host ("  SELF-TEST PASSED - {0} check(s), every planted defect verified to have landed and then caught" -f $script:SrOk) -ForegroundColor Green }
    return $script:SrBad
}

# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------

if ($SelfTest) {
    try { $bad = Invoke-SrSelfTest -Skill $SkillDir -ConfigGiven $ImagesConfig -PaddingCm $CellPaddingCm -GapCm $NodeGapCm -CharEm $AvgCharEmShare -NodeOverrideCm $NodeHeightCm }
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

try {
    $profPath = Resolve-SrProfilePath -ProfilePath $Profile -Build $BuildDir -Skill $SkillDir
    $cfgPath  = Resolve-SrImagesConfig -Given $ImagesConfig -Skill $SkillDir
    $caps     = Get-SrRenderCaps -ProfileFile $profPath -ConfigFile $cfgPath -Skill $SkillDir
}
catch { Write-Host ("  X {0}" -f $_.Exception.Message) -ForegroundColor Red; exit 2 }

try {
    $result = Invoke-SpecRenderable -Build $BuildDir -Spine $SpineDir -Contract $ContractPath -Caps $caps `
                                    -PaddingCm $CellPaddingCm -GapCm $NodeGapCm -CharEm $AvgCharEmShare -NodeOverrideCm $NodeHeightCm
}
catch { Write-Host ("  X {0}: {1}" -f $GATE, $_.Exception.Message) -ForegroundColor Red; exit 2 }

$st = $result.Stats
$blocking = @($result.Findings)
$reports  = @($result.Notes)

if (-not $Quiet) {
    Write-Host ''
    Write-Host 'SPEC RENDERABILITY - can every planned visual actually be drawn?' -ForegroundColor Cyan
    Write-GateCheckSet -What 'visual spec(s) on the spine' -Count $st.specsChecked -DerivedFrom ("{0} spine file(s)" -f $st.spineFiles)
    Write-GateCheckSet -What 'declared renderer layout(s)' -Count $caps.Renderers.Count -DerivedFrom ((Split-Path -Leaf $caps.ConfigPath) + ' diagram.renderer')
    Write-Host ("  caps READ: box cap {0} (diagram.maxNodes); placement cap {1:N1} cm and diagram width fraction {2:N2} (placement); font {3:N1} pt at line spacing {4:N2} giving {5:N2} cm a line - all from {6}" -f `
        $caps.MaxNodes, $caps.MaxHeightCm, $caps.DiagramWidthFraction, $caps.FontPt, $caps.LineSpacing, $caps.LineCm, (Split-Path -Leaf $caps.ConfigPath)) -ForegroundColor DarkGray
    Write-Host ("  geometry READ: column {0:N2} cm tall x {1:N2} cm wide, arithmetic over the page geometry in {2} (via {3})" -f `
        $caps.ColHeightCm, $caps.ColWidthCm, (Split-Path -Leaf $caps.GuideProfile), (Split-Path -Leaf $caps.ProfilePath)) -ForegroundColor DarkGray
    Write-Host ("  estimators (parameters, not declared by either file): cell padding {0:N2} cm, connector gap {1:N2} cm, average character advance {2:N2} em, node height override {3}" -f `
        $CellPaddingCm, $NodeGapCm, $AvgCharEmShare, $(if ($NodeHeightCm -gt 0) { ('{0:N2} cm' -f $NodeHeightCm) } else { 'none - derived' })) -ForegroundColor DarkGray
    Write-Host ("  {0} visual(s): {1} spec(s) checked, {2} generated image(s) skipped (their prompts belong to Assert-PromptLint); {3} slot(s) defined against {4} declared by the contract at {5} a sub-section; {6} figure cross-reference(s) resolved" -f `
        $st.visuals, $st.specsChecked, $st.imageVisualsSkipped, $st.definedSlots, $st.expectedSlots, $st.perSubSectionDeclared, $st.figureCrossReferences) -ForegroundColor DarkGray

    Write-Host ''
    if ($blocking.Count -eq 0) { Write-Host '  every spec fits its column, sits inside the box cap, and asks its renderer for nothing the renderer cannot draw' -ForegroundColor Green }
    foreach ($g in ($blocking | Group-Object Rule | Sort-Object Name)) {
        Write-Host ("  {0}: {1} blocking" -f $g.Name, $g.Count) -ForegroundColor Red
        foreach ($f in ($g.Group | Select-Object -First 25)) { Write-Host ("    X {0}" -f $f.Detail) -ForegroundColor Red }
        if ($g.Count -gt 25) { Write-Host ("    ... {0} more in the report file" -f ($g.Count - 25)) -ForegroundColor DarkGray }
    }
    foreach ($g in ($reports | Group-Object Rule | Sort-Object Name)) {
        Write-Host ("  {0}: {1} REPORT (never changes the exit code)" -f $g.Name, $g.Count) -ForegroundColor Yellow
        foreach ($f in ($g.Group | Select-Object -First 15)) { Write-Host ("    ! {0}" -f $f.Detail) -ForegroundColor Yellow }
        if ($g.Count -gt 15) { Write-Host ("    ... {0} more in the report file" -f ($g.Count - 15)) -ForegroundColor DarkGray }
    }
}

if (-not $ReportPath) { $ReportPath = Join-Path $BuildDir 'spec-renderable-report.json' }
$report = [pscustomobject]@{
    gate      = $GATE
    generated = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
    buildDir  = $BuildDir
    spineFingerprint = (Get-SpineFingerprint -BuildDir $BuildDir -SpineDir $SpineDir)
    sources   = [pscustomobject]@{ profile = $caps.ProfilePath; guideProfile = $caps.GuideProfile; imagesConfig = $caps.ConfigPath }
    caps      = [pscustomobject]@{
        maxNodes = $caps.MaxNodes; columnHeightCm = $caps.ColHeightCm; columnWidthCm = $caps.ColWidthCm
        placementMaxHeightCm = $caps.MaxHeightCm; diagramWidthFraction = $caps.DiagramWidthFraction
        fontPt = $caps.FontPt; lineSpacing = $caps.LineSpacing; lineCm = $caps.LineCm
        renderers = $caps.Renderers; tableLayouts = $caps.TableLayouts
    }
    estimators = [pscustomobject]@{ cellPaddingCm = $CellPaddingCm; nodeGapCm = $NodeGapCm; avgCharEmShare = $AvgCharEmShare; nodeHeightCmOverride = $NodeHeightCm }
    stats     = $st
    blocking  = $blocking
    report    = $reports
    verdict   = $(if ($blocking.Count) { 'FAIL' } else { 'PASS' })
}
Write-SrJson -Object $report -Path $ReportPath
if (-not $Quiet) { Write-Host ("  report written to {0}" -f $ReportPath) -ForegroundColor DarkGray }

if ($blocking.Count) {
    if (-not $Quiet) { Write-Host ("FAIL - {0} spec(s) that cannot be drawn as written" -f $blocking.Count) -ForegroundColor Red }
    exit 1
}
if (-not $Quiet) { Write-Host 'PASS' -ForegroundColor Green }
exit 0
