<#
    Test-SpineRead.ps1 - find spine content that NO renderer reads, and nodes
    that will render as an empty box.

    Implements the write-time arm of the gate the design calls
    Assert-RendererContract / New-SpineWriter. Run it at Stage 3 on every write
    and again across the whole spine at Stage 3c, before any render.

    WHY IT EXISTS. Five role-play boxes shipped empty or near-empty, three of
    them completely blank and all three in the topic the guide itself calls
    safety-critical. They were not empty on the spine: they carried a scenario,
    roles and phrases, written against field names the renderer does not look
    at. The renderer read its own field names, found nothing, and drew the box
    anyway. Seven parallel authors had written one shape and one renderer read
    another. The content was authored, reviewed and gated, and it never reached
    the page - found by a persona, half an hour after the render, by a human
    noticing an empty box.

    A word-count gate cannot see this: the words are in the file. A rendered-text
    gate cannot see it either: it knows only what did appear, never what should
    have. So the check compares the SHAPE of the spine against the fields the
    renderers actually reference.

    IT REPORTS TWO THINGS, AND THE SECOND ONE USED TO BE MISSING FROM THE
    DETECTOR ITSELF. The shipped version declared a $missing list and never
    added anything to it, so the failure it advertised could not occur.

      UNREAD   a FIELD carrying content that no renderer reads.
      MISSING  a NODE whose entire content is unread - a titled empty box.

    THREE THINGS CHANGED WHEN THIS WAS PROMOTED, and each was a live hole:

    1. THE RENDERERS ARE PARSED, NOT GREPPED. The shipped detector searched the
       renderer source as TEXT, so a field name that appeared only in a COMMENT
       counted as rendered - the exact way a lost field hides. This walks the
       PowerShell AST, where comments do not exist, and collects real property
       and index accesses.
    2. THE DEPTH CAP IS GONE. The shipped detector stopped at depth 2, so
       anything nested deeper than a sub-section's own second level was never
       examined at all.
    3. THE RENDERERS ARE GLOBBED, NOT NAMED. Naming two build scripts by hand
       means a third renderer, or a renamed one, is silently not checked.

    The deliberately-unrendered list is DECLARED WITH REASONS, in the build
    contract, and printed - because a field the build withholds on purpose and
    a field the build loses by accident look identical to a walker.

    PS 5.1. ASCII only in this file.
    Exit 11 unread fields, 12 empty-rendering nodes, 13 both, 2 a usage error.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $BuildDir,
    [string] $SpineDir,
    [string] $SkillDir,
    #  Every script that turns spine JSON into a page. Globbed, not named.
    [string[]] $RendererPath,
    [string[]] $DeckProfile,
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

$GATE = 'Test-SpineRead'

# ---------------------------------------------------------------------------
# 1. The renderers, and every field name they actually read
# ---------------------------------------------------------------------------

$renderers = New-Object System.Collections.Generic.List[string]
if ($RendererPath) {
    foreach ($r in @($RendererPath | Where-Object { $_ })) {
        foreach ($f in @(Get-ChildItem -Path $r -File -ErrorAction SilentlyContinue)) { $renderers.Add($f.FullName) }
    }
}
else {
    foreach ($pattern in @(
        (Join-Path $BuildDir 'Build-*.ps1'),
        (Join-Path $BuildDir 'Render-*.ps1'),
        #  Invoke-Render.ps1 IS the spine reader - it holds both the guide
        #  renderer and the deck renderer and reads every content-model field.
        #  Build-Guide.ps1 and Pptx-Blocks.ps1 are the low-level BLOCK
        #  libraries it calls; between them they name almost none of the spine
        #  field names. Omitting Invoke-Render from this list derived the
        #  read-set from the block libraries alone, so the gate reported EVERY
        #  authored field as UNREAD and every container as MISSING - 36 lines
        #  on a correct file - which is the "gate that fires on everything" the
        #  throw below exists to prevent, arriving by a different route.
        #  Found on the SITXINV007 build, 4 September 2026, by the pilot agent:
        #  verified by grepping all 23 content-model field names against the
        #  three scripts before this line was changed.
        (Join-Path $SkillDir 'scripts\Invoke-Render.ps1'),
        (Join-Path $SkillDir 'scripts\Build-Guide.ps1'),
        (Join-Path $SkillDir 'scripts\Build-Deck*.ps1'),
        (Join-Path $SkillDir 'scripts\Pptx-Blocks.ps1')
    )) {
        foreach ($f in @(Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue)) { $renderers.Add($f.FullName) }
    }
}
$renderers = @($renderers | Sort-Object -Unique)
if ($renderers.Count -eq 0) {
    throw "$GATE`: no renderer found. Pass -RendererPath. A read-set derived from nothing would report every authored field as unread, and a gate that fires on everything is a gate that is switched off within one build."
}

$strong = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
$weak   = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)

foreach ($r in $renderers) {
    $errs = $null; $toks = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($r, [ref]$toks, [ref]$errs)
    if ($errs -and $errs.Count -gt 0) {
        throw ("{0}: {1} does not parse ({2}). A renderer that does not parse cannot be asked what it reads." -f $GATE, (Split-Path $r -Leaf), $errs[0].Message)
    }

    # $node.field  and  $node.field()
    foreach ($m in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.MemberExpressionAst] }, $true)) {
        if ($m.Member -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
            [void]$strong.Add($m.Member.Value)
        }
    }
    # $node['field']
    foreach ($m in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.IndexExpressionAst] }, $true)) {
        if ($m.Index -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
            [void]$weak.Add($m.Index.Value)
        }
    }
    #  Every string literal in the CODE - a renderer that tests
    #  "-contains 'scenario'" reads scenario, and a slot map keyed by name reads
    #  every key. Comments are not in the AST, which is the point: the shipped
    #  detector counted a field named in a comment as rendered.
    foreach ($m in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true)) {
        if ($m.Value -and $m.Value.Length -lt 60) { [void]$weak.Add($m.Value) }
    }
}

# Deck slot names are resolved DYNAMICALLY through the layout profile, not by
# literal name in the renderer, so the profile's own slot names count as read.
# A literal-name search reports every slot as unread otherwise, which is exactly
# the kind of false positive that trains a reader to ignore a gate.
$deckSlots = New-Object System.Collections.Generic.List[string]
$profiles = New-Object System.Collections.Generic.List[string]
if (-not $DeckProfile) { $DeckProfile = @((Join-Path $SkillDir 'assets\deck-layouts*.json')) }
foreach ($pattern in @($DeckProfile | Where-Object { $_ })) {
    foreach ($f in @(Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue)) {
        $profiles.Add($f.Name)
        $prof = Get-GateJson -Path $f.FullName
        if ($null -eq $prof -or -not $prof.layouts) { continue }
        foreach ($lay in $prof.layouts.PSObject.Properties) {
            if ($lay.Value.slots) {
                foreach ($sl in $lay.Value.slots.PSObject.Properties) { $deckSlots.Add($sl.Name) }
            }
        }
    }
}
foreach ($s in $deckSlots) { [void]$weak.Add($s) }

$unrendered = Get-GateUnrenderedFields -BuildDir $BuildDir

function Test-FieldRead {
    param([string] $Name)
    return ($strong.Contains($Name) -or $weak.Contains($Name))
}

if (-not $Quiet) {
    Write-Host ''
    Write-Host 'SPINE READABILITY - is every authored field actually rendered?' -ForegroundColor Cyan
    Write-Host ("  renderers parsed: {0} - {1}" -f $renderers.Count, (($renderers | ForEach-Object { Split-Path $_ -Leaf }) -join ', ')) -ForegroundColor DarkGray
    Write-GateCheckSet -What 'field names read by a renderer' -Count ($strong.Count + $weak.Count) -DerivedFrom 'parsed property and index accesses plus string literals in the renderer AST (comments excluded by construction)'
    if ($profiles.Count) {
        Write-Host ("  layout profiles: {0} - {1} dynamic slot name(s) count as read" -f (($profiles) -join ', '), @($deckSlots | Sort-Object -Unique).Count) -ForegroundColor DarkGray
    }
    Write-Host ("  declared unrendered fields: {0}" -f $unrendered.Count) -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# 2. Walk the spine. No depth cap.
# ---------------------------------------------------------------------------

$unread  = New-Object System.Collections.Generic.List[string]
#  Every content-bearing field the walker examined, read or not. The denominator
#  for the incomplete-renderer-set guard below - derived from the same walk that
#  produces the findings, so the two can never disagree.
$script:contentFieldsSeen = 0
$missing = New-Object System.Collections.Generic.List[string]

function Test-HasContent {
    param($Value)
    if ($null -eq $Value) { return $false }
    if ($Value -is [string]) { return [bool]("$Value".Trim()) }
    if ($Value -is [ValueType]) { return $true }
    if ($Value -is [System.Collections.IEnumerable]) {
        foreach ($v in $Value) { if (Test-HasContent -Value $v) { return $true } }
        return $false
    }
    foreach ($p in $Value.PSObject.Properties) { if (Test-HasContent -Value $p.Value) { return $true } }
    return $false
}

function Test-NodeReaches {
    <#  Does ANY field anywhere beneath this node reach the page?

        Node-level, because that is the shape of the defect: five fields under
        one container, every one of them carrying content, not one of them read,
        and a titled empty box on the page.  #>
    param($Node, [int] $Depth = 0)

    if ($null -eq $Node -or $Depth -gt 24) { return $false }
    if ($Node -is [string] -or $Node -is [ValueType]) { return $false }
    if ($Node -is [System.Collections.IEnumerable]) {
        foreach ($v in $Node) { if (Test-NodeReaches -Node $v -Depth ($Depth + 1)) { return $true } }
        return $false
    }
    foreach ($p in $Node.PSObject.Properties) {
        if ($p.Name -like '_*') { continue }
        if (-not (Test-HasContent -Value $p.Value)) { continue }
        if (Test-FieldRead -Name $p.Name) { return $true }
        if (Test-NodeReaches -Node $p.Value -Depth ($Depth + 1)) { return $true }
    }
    return $false
}

function Test-NodeAllDeclared {
    <# Is everything under this node a field the build declared unrendered? #>
    param($Node, [int] $Depth = 0)

    if ($null -eq $Node -or $Depth -gt 24) { return $true }
    if ($Node -is [string] -or $Node -is [ValueType]) { return $true }
    if ($Node -is [System.Collections.IEnumerable]) {
        foreach ($v in $Node) { if (-not (Test-NodeAllDeclared -Node $v -Depth ($Depth + 1))) { return $false } }
        return $true
    }
    foreach ($p in $Node.PSObject.Properties) {
        if ($p.Name -like '_*') { continue }
        if (-not (Test-HasContent -Value $p.Value)) { continue }
        if ($unrendered.Contains($p.Name)) { continue }
        return $false
    }
    return $true
}

function Walk-Spine {
    param($Node, [string] $Path, [string] $File, [int] $Depth = 0)

    if ($null -eq $Node -or $Depth -gt 24) { return }
    if ($Node -is [string] -or $Node -is [ValueType]) { return }
    if ($Node -is [System.Collections.IEnumerable]) {
        $i = 0
        foreach ($x in $Node) { Walk-Spine -Node $x -Path ("{0}[{1}]" -f $Path, $i) -File $File -Depth ($Depth + 1); $i++ }
        return
    }
    if (@($Node.PSObject.Properties).Count -eq 0) { return }

    foreach ($p in $Node.PSObject.Properties) {
        $name = $p.Name
        if ($name -like '_*') { continue }
        if ($unrendered.Contains($name)) { continue }
        if (-not (Test-HasContent -Value $p.Value)) { continue }

        $childPath = if ($Path) { "$Path.$name" } else { $name }

        $script:contentFieldsSeen++
        if (-not (Test-FieldRead -Name $name)) {
            $unread.Add("$File -> $childPath  (carries content, no renderer reads this field name)")
        }

        #  MISSING: a container none of whose content reaches the page. Reported
        #  at the SHALLOWEST such node and not descended into, so one lost box
        #  is one finding rather than five.
        if ($p.Value -isnot [string] -and $p.Value -isnot [ValueType]) {
            if (-not (Test-NodeReaches -Node $p.Value) -and -not (Test-NodeAllDeclared -Node $p.Value)) {
                $fields = @()
                $probe = $p.Value
                if ($probe -is [System.Collections.IEnumerable] -and $probe -isnot [string]) { $probe = @($probe)[0] }
                if ($null -ne $probe -and $probe.PSObject) { $fields = @($probe.PSObject.Properties.Name | Where-Object { $_ -notlike '_*' }) }
                $missing.Add(("{0} -> {1}  (nothing under this node reaches the page; it carries {2})" -f $File, $childPath, $(if ($fields.Count) { $fields -join ', ' } else { 'content in unread fields' })))
                continue
            }
        }

        Walk-Spine -Node $p.Value -Path $childPath -File $File -Depth ($Depth + 1)
    }
}

#  Enumerated ONCE into a variable: the incomplete-renderer-set guard below
#  needs the file COUNT, and re-enumerating would let the two disagree.
$spineFileList = @(Get-GateSpineFiles -BuildDir $BuildDir -SpineDir $SpineDir)
foreach ($f in $spineFileList) {
    $j = Get-GateJson -Path $f.FullName
    if ($null -eq $j) { continue }
    Walk-Spine -Node $j -Path '' -File $f.Name
}

# ---------------------------------------------------------------------------
# 3. Report
# ---------------------------------------------------------------------------

$u = @($unread | Sort-Object -Unique)
$m = @($missing | Sort-Object -Unique)

if (-not $Quiet) {
    Write-Host ''
    if ($u.Count -eq 0) { Write-Host '  UNREAD:  every authored field on the spine is read by a renderer' -ForegroundColor Green }
    else {
        foreach ($x in $u) { Write-Host "  X UNREAD  $x" -ForegroundColor Red }
        Write-Host ("  {0} field path(s) carry content that will never reach the page" -f $u.Count) -ForegroundColor Red
    }

    Write-Host ''
    if ($m.Count -eq 0) { Write-Host '  MISSING: every container on the spine puts something on the page' -ForegroundColor Green }
    else {
        foreach ($x in $m) { Write-Host "  X MISSING $x" -ForegroundColor Red }
        Write-Host ("  {0} node(s) will render as an empty or titled-but-blank box" -f $m.Count) -ForegroundColor Red
    }

    if ($u.Count -or $m.Count) {
        Write-Host ''
        Write-Host '  Fix the SPINE to the field names the renderer reads, or teach the renderer the field.' -ForegroundColor Yellow
        Write-Host '  A field that is deliberately not rendered is declared in contract.json under' -ForegroundColor Yellow
        Write-Host '  spineContract.unrenderedFields, with a written reason, so the next reader knows.' -ForegroundColor Yellow
    }
}

#  AN INCOMPLETE RENDERER SET LOOKS EXACTLY LIKE A BROKEN SPINE, and the
#  difference is SHAPE, not volume. A real unread-field defect is LOCAL: an
#  author mistypes a field name in one file. When the SAME field name is
#  unread in nearly every spine file, nothing was mistyped - the renderer that
#  reads it was not found. This build keeps two of its four renderers in the
#  BUILD directory; a run that cannot see them parsed 2 instead of 4 and
#  reported 911 of 2063 content fields unread, none of it real. A share
#  threshold was tried first and rejected: 44 per cent looks unremarkable, and
#  the tell was never the proportion.
$fileCount = $spineFileList.Count
if ($u.Count -gt 0 -and $fileCount -ge 4) {
    $byName = @{}
    foreach ($entry in @($unread)) {
        $mm = [regex]::Match([string]$entry, '^(?<f>\S+)\s*->\s*(?<p>[^\s(]+)')
        if (-not $mm.Success) { continue }
        #  The TOP-level name only: slides[3].notes and slides[0].notes are one
        #  field name, or every indexed path would count as its own defect.
        $nm = ($mm.Groups['p'].Value -split '[.\[]')[0]
        if (-not $byName.ContainsKey($nm)) { $byName[$nm] = New-Object 'System.Collections.Generic.HashSet[string]' }
        [void]$byName[$nm].Add($mm.Groups['f'].Value)
    }
    $universal = @($byName.Keys | Where-Object { $byName[$_].Count -ge [int][Math]::Ceiling($fileCount * 0.8) } | Sort-Object)
    if ($universal.Count -ge 5) {
        Write-Host ''
        Write-Host ("  X RENDERER SET LOOKS INCOMPLETE - not a spine defect: {0} field name(s) are unread in at least 80% of the {1} spine files." -f $universal.Count, $fileCount) -ForegroundColor Red
        Write-Host ("    {0}" -f ($universal -join ', ')) -ForegroundColor Yellow
        Write-Host ("    {0} renderer(s) were parsed: {1}" -f $renderers.Count, (($renderers | ForEach-Object { Split-Path $_ -Leaf }) -join ', ')) -ForegroundColor Yellow
        Write-Host '    A spine does not go wrong the same way in every file at once. Check that every' -ForegroundColor Yellow
        Write-Host '    renderer this build uses is visible - build-specific renderers live in the BUILD' -ForegroundColor Yellow
        Write-Host '    directory, not the skill - and pass -RendererPath if they are elsewhere.' -ForegroundColor Yellow
        Write-Host '    This is still a FAILURE. It is a differently-caused one, and the field list above' -ForegroundColor Yellow
        Write-Host '    is the diagnosis rather than a work order.' -ForegroundColor Yellow
        exit 14
    }
}

if ($u.Count -and $m.Count) { exit 13 }
if ($u.Count) { exit 11 }
if ($m.Count) { exit 12 }
exit 0
