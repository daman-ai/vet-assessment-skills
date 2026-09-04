<#
    Assert-WithholdRegister.ps1 - no withheld value appears outside a
    POSED-QUESTION context, in ANY channel of EITHER artefact.

    Implements references\gates.md section 16, enforcement arm. Runs at Stage
    3c over the spine and again at 7c with the rendered extracts of both
    artefacts handed in on -DocText. The Stage 2 derivation step is
    scripts\New-WithholdRegister.ps1, which writes the register this gate
    reads; this script derives nothing about what is withheld and never
    guesses it.

    TWO RULES CARRY THIS GATE AND BOTH MATTER.

    1. WITHHOLDING IS A BUILD-WIDE FACT, NOT A PER-DOCUMENT ONE. The guide-facing
       and deck-facing channels are swept TOGETHER and the register's per-grid
       allowance is counted ONCE across both. So a row answered in the guide as
       the single permitted exemplar and repeated on a slide is one answered
       row, while a DIFFERENT row answered on a slide is a second answered row
       and blocks - which is the failure this section exists to catch: a deck
       slide filling the row the guide's own figure withholds as "Your turn".
       A corrected guide beside an uncorrected deck is worse than either alone,
       so the report also names every row answered in ONE artefact only.

    2. "POSED QUESTION" IS DECIDED STRUCTURALLY. A sentence that merely sounds
       like a question is not one. The exemption is the CONTAINING NODE TYPE,
       resolved in a printed order of precedence and never from prose sentiment:

         a. the compiled renderer contract, where the build carries one
            (contract.json spineContract.rendererContract.posedQuestionFields);
         b. contract.json spineContract.posedQuestionFields, each entry with a
            written reason, refused without one - the same discipline as an
            allow-list, because an exemption nobody can audit is a gate turned
            off;
         c. DERIVED FROM THE SPINE SCHEMA: a node that carries a companion
            field the build declares DELIBERATELY WITHHELD from the page is a
            node that poses questions, and its own list fields are the posed
            questions. On this schema that resolves selfCheck.questions through
            its answerGuide companion, without anything being typed here.

       No renderer exports Get-RendererContract yet (section 21), so arm (c)
       carries this today. Arm (c) is deliberately TIGHT: every other channel
       is swept, so a channel invented later is swept by default rather than
       exempt by default. A build that needs a wider exemption writes it in the
       contract with a reason, where an auditor can read it.

    THE SWEEP IS ENUMERATED FROM THE SPINE'S OWN NODE TYPES. The channel list
    is not typed here and not read from a list: it is every top-level field
    name found on the spine, so a channel added later cannot escape the sweep.
    The channel list swept is printed on every run, with the artefact each
    channel belongs to and how that was decided.

    HOW A HIT IS DECIDED - EXACT VALUE MATCHING AGAINST A DERIVED SET, which is
    section 16's own false-positive control. A spine string is answering a
    withheld row when it NAMES the row (the register's item label, subject or
    one of the aliases the register resolved, matched on normalised text) AND
    carries the COMPLETE content-word set of at least one model bullet of that
    row, read from the gate-only assessor cells through the word pipeline those
    cells declare. Naming a row is not a leak: the tools print their own row
    labels. Naming a row and stating everything one of its model bullets states
    is.

    THE THRESHOLD IS MEASURED, NOT GUESSED, and the measurement is why the rule
    is worded that way. A first cut required only two content words of the row
    in common with the string. On the reference build that fired on 817 cells,
    nearly all of them the guide legitimately TEACHING a row - which the
    coverage arm requires it to do - and a gate that fires on everything is a
    gate that is routed around within one build. Requiring the whole of one
    model bullet separates "teaches the subject" from "supplies the answer".
    -MinBulletWords is the floor on how big a bullet must be before it can be
    matched at all, so a two-word bullet that is really a recipe number cannot
    raise a finding on its own. A build that lowers it signs that decision in
    its runner, where it is printed.

    IT NEVER PRINTS AN ANSWER. The report names the file, the field path, the
    channel, the artefact, the task reference and the WITHHELD ITEM - never the
    model bullet, never the benchmark, and never the cell that answers it. A
    finding you can act on does not require the answer to be reprinted where
    the next reader will find it.

    TRUSTED ONLY AFTER FAILING ON A PLANTED DEFECT. -SelfTest builds a fixture,
    VERIFIES EACH PLANT LANDED in the exact channel the sweep reads before the
    sweep is run, and fails the gate if the sweep does not find it - or if it
    fires on the clean control or on the plant that sits inside a genuinely
    posed question. A plant that silently fails to apply makes a gate look
    proven when it is not.

    PS 5.1. ASCII only in this file. Nothing here names a unit, a brand or a path.
    Exit 1 a blocking hit, 2 a usage error or a missing blocking input, 4 the
    self-test failed.
#>

[CmdletBinding()]
param(
    [string] $BuildDir,
    #  Written by New-WithholdRegister.ps1 at Stage 2. Agent-safe: labels and
    #  shape, no model cell.
    [string] $Register,
    #  GATE-ONLY. The model bullets and their content-word sets. Read, never
    #  printed, never copied.
    [string] $AssessorCells,
    [string] $SpineDir,
    [string] $RulesPath,
    #  Rendered text extracts of BOTH artefacts, swept as further channels at
    #  7c. A spine that is clean and a document that is not is still a build
    #  that ships the leak.
    [string[]] $DocText,
    #  How the guide-facing and deck-facing channels are told apart. Globbed,
    #  never named, so a renamed or added renderer is still read.
    [string[]] $GuideRenderer,
    [string[]] $DeckRenderer,
    #  Left empty it resolves to the skill this script lives in. Not defaulted
    #  in the parameter block: a relative -File invocation leaves $PSScriptRoot
    #  empty in PS 5.1 and Split-Path then throws before the script begins.
    [string] $SkillDir,
    #  How many content words a model bullet must carry before a string that
    #  reproduces ALL of them counts as answering the row. Three is the measured
    #  value on the reference build; see the header.
    [int] $MinBulletWords = 3,
    [string] $OutPath,
    [switch] $SelfTest,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'

$script:WrScriptDir = $PSScriptRoot
if (-not $script:WrScriptDir) { $script:WrScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $script:WrScriptDir 'Lib-GateCommon.ps1')
if (-not $SkillDir) { $SkillDir = Split-Path -Parent $script:WrScriptDir }

$GATE = 'Assert-WithholdRegister'

function Write-WrLine {
    param([string] $Text, [string] $Colour = 'DarkGray')
    if (-not $script:WrQuiet) { Write-Host $Text -ForegroundColor $Colour }
}

function Stop-WrUsage {
    param([string] $Message)
    Write-Host ("  X {0}: {1}" -f $GATE, $Message) -ForegroundColor Red
    exit 2
}

# ---------------------------------------------------------------------------
# The word pipeline the assessor cells declare.
#
# The content-word sets in assessor-cells.json were produced by
# New-WithholdRegister's normalise / stem / stopword pipeline. A comparison is
# only meaningful if BOTH sides go through the same one, so this gate
# implements the declared pipeline and CHECKS the declaration at run time: if
# the cells declare a stem rule this does not implement, the gate refuses
# rather than comparing two different vocabularies and reporting clean.
# ---------------------------------------------------------------------------

$WR_STOPWORDS = @(
    'a','about','above','after','again','against','all','also','am','an','and','any','are','as','at',
    'be','because','been','before','being','below','between','both','but','by',
    'can','cannot','could','did','do','does','doing','down','during',
    'each','either','else','ever','every','few','for','from','further',
    'had','has','have','having','he','her','here','hers','him','his','how',
    'i','if','in','into','is','it','its','itself','just',
    'let','may','me','might','more','most','much','must','my','myself',
    'neither','never','no','nor','not','now','of','off','on','once','one','only','onto','or','other','ought','our','ours','out','over','own',
    'per','rather','same','shall','she','should','so','some','still','such',
    'than','that','the','their','theirs','them','then','there','these','they','this','those','through','to','too','toward','towards',
    'under','until','up','upon','us','use','used','using','very','via',
    'was','we','were','what','when','where','whether','which','while','who','whom','whose','why','will','with','within','without','would',
    'yes','yet','you','your','yours','yourself',
    'across','along','among','around','away','back','get','gets','got','give','given','go','goes','keep','make','makes','made','put','take','takes','taken'
)
$WR_STEM_RULE = 'crude suffix strip: ing, ed, es, s'

function Get-WrStem {
    param([string] $Word)
    $w = $Word
    if ($w.Length -gt 5 -and $w.EndsWith('ing')) { return $w.Substring(0, $w.Length - 3) }
    if ($w.Length -gt 4 -and $w.EndsWith('ed'))  { return $w.Substring(0, $w.Length - 2) }
    if ($w.Length -gt 4 -and $w -match '(ss|sh|ch|x|z)es$') { return $w.Substring(0, $w.Length - 2) }
    if ($w.Length -gt 3 -and $w.EndsWith('s') -and -not $w.EndsWith('ss')) { return $w.Substring(0, $w.Length - 1) }
    return $w
}

$script:WrStopSet = @{}
foreach ($sw in $WR_STOPWORDS) { $script:WrStopSet[(Get-WrStem $sw)] = $true; $script:WrStopSet[$sw] = $true }

function Get-WrWordSet {
    <# Normalised, stemmed, stopword-free tokens of a string, as a hash set. #>
    param([string] $Text, [switch] $KeepNumbers)
    $set = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    if (-not $Text) { return ,$set }
    foreach ($tok in ((ConvertTo-GateNormal $Text) -split ' ')) {
        if (-not $tok -or $tok.Length -lt 2) { continue }
        if (-not $KeepNumbers -and $tok -match '^\d+$') { continue }
        $s = Get-WrStem $tok
        if ($script:WrStopSet.ContainsKey($s) -or $script:WrStopSet.ContainsKey($tok)) { continue }
        [void]$set.Add($s)
    }
    return ,$set
}

# ---------------------------------------------------------------------------
# Row labels: the label itself plus the aliases the register already resolved
# ---------------------------------------------------------------------------

function Get-WrLabelForms {
    <#  Every normalised form of a row label the register knows about. The
        register resolved these from the pack's own vocabulary at Stage 2;
        nothing is invented here. A purely numeric label ("1", "2") is not a
        name and is dropped - on a numbered grid the NAME is the subject.  #>
    param([string] $Label, $AliasNode)

    $out = New-Object System.Collections.Generic.List[string]
    $n = ConvertTo-GateNormal $Label
    if ($n -and $n -notmatch '^[0-9 ]+$' -and $n.Length -ge 3) { $out.Add($n) }
    if ($null -ne $AliasNode) {
        foreach ($a in @($AliasNode)) {
            $an = ConvertTo-GateNormal ([string]$a)
            #  A two-letter or three-letter alias ("pie", "dish") names half the
            #  pack. Aliases shorter than four characters are dropped: the row
            #  label and the content-word overlap both still have to match, and
            #  an alias that matches everything only costs precision.
            if ($an -and $an.Length -ge 4 -and -not $out.Contains($an)) { $out.Add($an) }
        }
    }
    return $out.ToArray()
}

# ---------------------------------------------------------------------------
# The withheld rows: the register says WHAT is withheld, the gate-only
# assessor cells say what answering it looks like
# ---------------------------------------------------------------------------

function Get-WrWithheldRows {
    <#  One entry per (grid, withheld row): the forms that NAME the row, and
        the content words of that row's model answer.

        Labelled and lookup grids are keyed on the register's items. Numbered
        and records grids have no meaningful item label - the learner chooses
        the items - so the NAME is the subject, and the subject is mapped to
        its model row by finding the row whose own model text names it. That
        mapping reads model text and never emits it.  #>
    param($RegJson, $CellsJson, [int] $MinBulletWords = 3)

    $byRef = @{}
    foreach ($g in @(Get-GateProp -Object $CellsJson -Names @('grids') -Default @())) {
        if ($null -eq $g) { continue }
        $r = [string](Get-GateProp -Object $g -Names @('ref') -Default '')
        if ($r) { $byRef[$r] = $g }
    }

    $rows = New-Object System.Collections.Generic.List[object]
    $unmapped = New-Object System.Collections.Generic.List[string]
    $grids = New-Object System.Collections.Generic.List[object]

    $subs = Get-GateProp -Object $RegJson -Names @('subSections') -Default $null
    if ($null -eq $subs) { return [pscustomobject]@{ Rows = $rows.ToArray(); Grids = $grids.ToArray(); Unmapped = $unmapped.ToArray() } }

    foreach ($p in $subs.PSObject.Properties) {
        if ($p.Name -like '_*') { continue }
        foreach ($t in @(Get-GateProp -Object $p.Value -Names @('tasks', 'grids') -Default @())) {
            if ($null -eq $t) { continue }
            $ref  = [string](Get-GateProp -Object $t -Names @('ref') -Default '')
            $id   = [string](Get-GateProp -Object $t -Names @('id') -Default $ref)
            $kind = [string](Get-GateProp -Object $t -Names @('kind') -Default '')
            $allow = [int](Get-GateProp -Object $t -Names @('allowance') -Default 0)
            $items = @(Get-GateProp -Object $t -Names @('items') -Default @())
            $subjects = @(Get-GateProp -Object $t -Names @('subjects') -Default @())
            $prefilled = @(Get-GateProp -Object $t -Names @('prefilledItems') -Default @())
            $aliases = Get-GateProp -Object $t -Names @('aliases') -Default $null

            $cellGrid = $null
            if ($byRef.ContainsKey($ref)) { $cellGrid = $byRef[$ref] }

            #  Model rows, with their content words and their own model text,
            #  keyed by the item label the cells carry.
            $modelByItem = @{}
            $modelOrder = New-Object System.Collections.Generic.List[object]
            if ($null -ne $cellGrid) {
                foreach ($mr in @(Get-GateProp -Object $cellGrid -Names @('rows') -Default @())) {
                    if ($null -eq $mr) { continue }
                    $assessed = Get-GateProp -Object $mr -Names @('assessed') -Default $false
                    if (-not $assessed) { continue }
                    $words = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
                    $bullets = New-Object System.Collections.Generic.List[object]
                    $ownText = New-Object System.Text.StringBuilder
                    foreach ($c in @(Get-GateProp -Object $mr -Names @('cells') -Default @())) {
                        if ($null -eq $c) { continue }
                        foreach ($b in @(Get-GateProp -Object $c -Names @('bullets') -Default @())) {
                            if ($null -eq $b) { continue }
                            $bset = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
                            foreach ($w in @(Get-GateProp -Object $b -Names @('words') -Default @())) {
                                $ws = "$w"
                                if ($ws) { [void]$words.Add($ws); [void]$bset.Add($ws) }
                            }
                            if ($bset.Count -ge $MinBulletWords) { $bullets.Add($bset) }
                            [void]$ownText.Append(' ').Append([string](Get-GateProp -Object $b -Names @('text') -Default ''))
                        }
                    }
                    $entry = [pscustomobject]@{
                        Item    = [string](Get-GateProp -Object $mr -Names @('item') -Default '')
                        Words   = $words
                        Bullets = $bullets.ToArray()
                        Norm    = (ConvertTo-GateNormal $ownText.ToString())
                    }
                    $modelOrder.Add($entry)
                    if ($entry.Item -and -not $modelByItem.ContainsKey($entry.Item)) { $modelByItem[$entry.Item] = $entry }
                }
            }

            #  Which labels name the withheld rows of THIS grid.
            $labels = New-Object System.Collections.Generic.List[string]
            $useSubjects = ($subjects.Count -gt 0)
            if ($useSubjects) { foreach ($s in $subjects) { $labels.Add([string]$s) } }
            else { foreach ($i in $items) { if ($prefilled -notcontains $i) { $labels.Add([string]$i) } } }

            $gridRows = 0
            foreach ($lab in $labels) {
                if (-not "$lab".Trim()) { continue }
                $forms = Get-WrLabelForms -Label $lab -AliasNode $(if ($null -ne $aliases -and @($aliases.PSObject.Properties.Name) -contains $lab) { $aliases.$lab } else { $null })
                if ($forms.Count -eq 0) { continue }

                $model = $null
                if ($modelByItem.ContainsKey($lab)) { $model = $modelByItem[$lab] }
                elseif ($useSubjects) {
                    #  Map the subject to the model row that names it.
                    foreach ($m in $modelOrder) {
                        $found = $false
                        foreach ($f in $forms) {
                            if ($m.Norm -and $m.Norm.IndexOf($f, [System.StringComparison]::Ordinal) -ge 0) { $found = $true; break }
                        }
                        if ($found) { $model = $m; break }
                    }
                }
                if ($null -eq $model -or @($model.Bullets).Count -eq 0) {
                    $unmapped.Add(("{0} / {1}" -f $ref, $lab))
                    continue
                }
                $rows.Add([pscustomobject]@{
                    SubSection = $p.Name
                    Ref = $ref; Id = $id; Kind = $kind; Allowance = $allow
                    Item = [string]$lab
                    Forms = $forms
                    Words = $model.Words
                    Bullets = $model.Bullets
                })
                $gridRows++
            }
            $grids.Add([pscustomobject]@{ SubSection = $p.Name; Ref = $ref; Id = $id; Kind = $kind; Allowance = $allow; Rows = $gridRows })
        }
    }
    return [pscustomobject]@{ Rows = $rows.ToArray(); Grids = $grids.ToArray(); Unmapped = $unmapped.ToArray() }
}

# ---------------------------------------------------------------------------
# Posed-question node types - structural, total, printed
# ---------------------------------------------------------------------------

function Get-WrPosedFromSpine {
    <#  Arm (c): DERIVED FROM THE SPINE SCHEMA.

        A node that carries a companion field the build DECLARES deliberately
        withheld from the page is a node that poses questions to the learner;
        the sibling fields that carry text are the posed questions. The
        declaration comes from Lib-GateCommon's unrendered-field list, which
        the build extends in contract.json with a written reason per entry - so
        this resolves without a field name being typed into this gate.  #>
    param([string] $BuildDir, [string] $SpineDir, [hashtable] $WithheldFields)

    $found = @{}
    $walk = {
        param($Node, $NodeName, $Depth)
        if ($null -eq $Node -or $Depth -gt 12) { return }
        if ($Node -is [string] -or $Node -is [ValueType]) { return }
        if ($Node -is [System.Collections.IEnumerable]) {
            foreach ($it in $Node) { & $walk $it $NodeName ($Depth + 1) }
            return
        }
        $props = @($Node.PSObject.Properties.Name)
        if (-not $props) { return }
        $hasWithheld = $false
        foreach ($pn in $props) { if ($WithheldFields.ContainsKey($pn)) { $hasWithheld = $true; break } }
        if ($hasWithheld -and $NodeName) {
            foreach ($pn in $props) {
                if ($pn -like '_*') { continue }
                if ($WithheldFields.ContainsKey($pn)) { continue }
                $v = $Node.$pn
                if ($null -eq $v) { continue }
                $carriesText = $false
                if ($v -is [string]) { $carriesText = ("$v".Trim().Length -gt 0) }
                elseif ($v -is [System.Collections.IEnumerable]) {
                    foreach ($x in $v) { if ($x -is [string] -and "$x".Trim()) { $carriesText = $true; break } }
                }
                if ($carriesText) { $found[("{0}.{1}" -f $NodeName, $pn)] = ("the node carries '{0}', which the build declares deliberately withheld from the page - so this field is what the learner is ASKED" -f (@($props | Where-Object { $WithheldFields.ContainsKey($_) }) -join ', ')) }
            }
        }
        foreach ($pn in $props) {
            if ($pn -like '_*') { continue }
            & $walk $Node.$pn $pn ($Depth + 1)
        }
    }

    foreach ($f in (Get-GateSpineFiles -BuildDir $BuildDir -SpineDir $SpineDir)) {
        $j = Get-GateJson -Path $f.FullName
        if ($null -eq $j) { continue }
        & $walk $j '' 0
    }
    return $found
}

function Resolve-WrPosedFields {
    <# Total, in a printed order of precedence. Returns field path -> reason. #>
    param([string] $BuildDir, [string] $SpineDir, $Contract)

    $out = [ordered]@{}
    $sources = New-Object System.Collections.Generic.List[string]

    $sc = $null
    if ($null -ne $Contract) { $sc = Get-GateProp -Object $Contract -Names @('spineContract') -Default $null }

    # (a) a compiled renderer contract carried on the build
    if ($null -ne $sc) {
        $rc = Get-GateProp -Object $sc -Names @('rendererContract') -Default $null
        if ($null -ne $rc) {
            $n = 0
            foreach ($e in @(Get-GateProp -Object $rc -Names @('posedQuestionFields', 'posedQuestionNodes') -Default @())) {
                $fld = Get-GateProp -Object $e -Names @('field', 'name', 'path')
                if (-not $fld -and $e -is [string]) { $fld = "$e" }
                $why = Get-GateProp -Object $e -Names @('reason', 'why') -Default 'declared by the compiled renderer contract'
                if ($fld) { $out["$fld"] = "$why"; $n++ }
            }
            if ($n -gt 0) { $sources.Add(("compiled renderer contract ({0} field(s))" -f $n)) }
        }
    }

    # (b) declared on the build contract, with a written reason - refused without one
    if ($null -ne $sc) {
        $n = 0
        foreach ($e in @(Get-GateProp -Object $sc -Names @('posedQuestionFields') -Default @())) {
            $fld = Get-GateProp -Object $e -Names @('field', 'name', 'path')
            $why = Get-GateProp -Object $e -Names @('reason', 'why')
            if (-not $fld) {
                throw ("{0}: contract.json spineContract.posedQuestionFields carries an entry that names no field. An exemption that cannot be read is a gate turned off." -f $GATE)
            }
            if (-not $why -or "$why".Trim().Length -lt 20) {
                throw ("{0}: contract.json spineContract.posedQuestionFields entry '{1}' carries no written reason. Exempting a channel from the withhold sweep is weakening a blocking rule; record WHY, so the audit that is handed this list has something to read." -f $GATE, $fld)
            }
            $out["$fld"] = "$why"; $n++
        }
        if ($n -gt 0) { $sources.Add(("contract.json spineContract.posedQuestionFields ({0} field(s), each with a written reason)" -f $n)) }
    }

    # (c) derived from the spine schema
    $withheld = @{}
    foreach ($kv in (Get-GateUnrenderedFields -BuildDir $BuildDir).GetEnumerator()) {
        if ("$($kv.Value)" -match '(?i)\bwithheld\b') { $withheld[$kv.Key] = "$($kv.Value)" }
    }
    $derived = @{}
    if ($withheld.Count -gt 0) {
        $derived = Get-WrPosedFromSpine -BuildDir $BuildDir -SpineDir $SpineDir -WithheldFields $withheld
        foreach ($k in $derived.Keys) { if (-not $out.Contains($k)) { $out[$k] = $derived[$k] } }
        $sources.Add(("the spine schema ({0} field(s) derived from the declared-withheld companion field(s): {1})" -f $derived.Count, ((@($withheld.Keys) | Sort-Object) -join ', ')))
    }
    else {
        $sources.Add('the spine schema (no field is declared deliberately withheld, so nothing is derived)')
    }

    return [pscustomobject]@{ Fields = $out; Sources = $sources.ToArray(); WithheldCompanions = @($withheld.Keys) }
}

# ---------------------------------------------------------------------------
# Which artefact does a channel belong to
# ---------------------------------------------------------------------------

function Get-WrRendererFields {
    <# Every field name a set of renderer scripts actually reads, from the AST. #>
    param([string[]] $Patterns)

    $files = New-Object System.Collections.Generic.List[string]
    foreach ($p in @($Patterns | Where-Object { $_ })) {
        foreach ($f in @(Get-ChildItem -Path $p -File -ErrorAction SilentlyContinue)) { $files.Add($f.FullName) }
    }
    $files = @($files | Sort-Object -Unique)
    $set = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    foreach ($r in $files) {
        $errs = $null; $toks = $null
        $ast = $null
        try { $ast = [System.Management.Automation.Language.Parser]::ParseFile($r, [ref]$toks, [ref]$errs) } catch { $ast = $null }
        if ($null -eq $ast) { continue }
        if ($errs -and $errs.Count -gt 0) { continue }
        foreach ($m in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.MemberExpressionAst] }, $true)) {
            if ($m.Member -is [System.Management.Automation.Language.StringConstantExpressionAst]) { [void]$set.Add($m.Member.Value) }
        }
        foreach ($m in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true)) {
            $v = "$($m.Value)"
            if ($v -and $v.Length -le 40 -and $v -match '^[A-Za-z][A-Za-z0-9_]*$') { [void]$set.Add($v) }
        }
    }
    return [pscustomobject]@{ Files = $files; Fields = $set }
}

function Resolve-WrChannelArtefacts {
    <#  Channel -> guide | deck | both.

        Derived from the renderers themselves where they can be found: a
        channel only the deck renderers read is deck-facing, only the guide
        renderers read is guide-facing, both read is shared. A channel neither
        reads is attributed to BOTH artefacts, which is the safe direction: it
        is still swept, and no cross-artefact claim is made about it.

        A build may override with contract.json spineContract.deckChannels /
        guideChannels. Whatever decides it, the table is printed.  #>
    param([string[]] $Channels, $Contract, [string] $BuildDir, [string] $SkillDir, [string[]] $GuidePatterns, [string[]] $DeckPatterns)

    if (-not $GuidePatterns -or @($GuidePatterns).Count -eq 0) {
        $GuidePatterns = @((Join-Path $BuildDir 'Build-Guide*.ps1'), (Join-Path $SkillDir 'scripts\Build-Guide*.ps1'))
    }
    if (-not $DeckPatterns -or @($DeckPatterns).Count -eq 0) {
        $DeckPatterns = @((Join-Path $BuildDir 'Build-Deck*.ps1'), (Join-Path $SkillDir 'scripts\Build-Deck*.ps1'), (Join-Path $SkillDir 'scripts\Pptx-Blocks.ps1'))
    }

    $g = Get-WrRendererFields -Patterns $GuidePatterns
    $d = Get-WrRendererFields -Patterns $DeckPatterns

    $declaredDeck = @(); $declaredGuide = @()
    if ($null -ne $Contract) {
        $sc = Get-GateProp -Object $Contract -Names @('spineContract') -Default $null
        if ($null -ne $sc) {
            $declaredDeck  = @(Get-GateProp -Object $sc -Names @('deckChannels') -Default @()) | ForEach-Object { "$_" }
            $declaredGuide = @(Get-GateProp -Object $sc -Names @('guideChannels') -Default @()) | ForEach-Object { "$_" }
        }
    }

    $map = [ordered]@{}
    $how = [ordered]@{}
    foreach ($c in $Channels) {
        if ($declaredDeck -contains $c)  { $map[$c] = 'deck';  $how[$c] = 'contract'; continue }
        if ($declaredGuide -contains $c) { $map[$c] = 'guide'; $how[$c] = 'contract'; continue }
        $inG = $g.Fields.Contains($c)
        $inD = $d.Fields.Contains($c)
        if ($inG -and -not $inD) { $map[$c] = 'guide'; $how[$c] = 'renderer' }
        elseif ($inD -and -not $inG) { $map[$c] = 'deck'; $how[$c] = 'renderer' }
        elseif ($inG -and $inD) { $map[$c] = 'both'; $how[$c] = 'renderer' }
        else { $map[$c] = 'both'; $how[$c] = 'unread by any renderer found - attributed to both, which claims nothing' }
    }
    return [pscustomobject]@{
        Map = $map; How = $how
        GuideRenderers = $g.Files; DeckRenderers = $d.Files
        GuideFieldCount = $g.Fields.Count; DeckFieldCount = $d.Fields.Count
    }
}

# ---------------------------------------------------------------------------
# The sweep
# ---------------------------------------------------------------------------

function Invoke-WrSweep {
    <#  Sweep every channel of both artefacts for a string that answers a
        withheld row. Returns a result object; decides nothing about exit
        codes, so the self-test can call it exactly as the real run does.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [string] $Register,
        [string] $AssessorCells,
        [string] $SpineDir,
        [string] $RulesPath,
        [string[]] $DocText,
        [string[]] $GuideRenderer,
        [string[]] $DeckRenderer,
        [string] $SkillDir,
        [int] $MinBulletWords = 3
    )

    if (-not $Register)      { $Register      = Join-Path $BuildDir 'withhold-register.json' }
    if (-not $AssessorCells) { $AssessorCells = Join-Path $BuildDir 'assessor-cells.json' }

    if (-not (Test-Path -LiteralPath $Register)) {
        throw ("{0}: no withhold register at {1}. This is a BLOCKING rule and its input is absent, so it fails and names the input: run scripts\New-WithholdRegister.ps1 -BuildDir <build> at Stage 2. A sweep with no register has nothing to withhold and would pass by checking nothing." -f $GATE, $Register)
    }
    if (-not (Test-Path -LiteralPath $AssessorCells)) {
        throw ("{0}: no assessor cells at {1}. Without them the gate knows WHICH rows are withheld but not what answering one looks like, so every check would be vacuous. scripts\New-WithholdRegister.ps1 writes this file beside the register." -f $GATE, $AssessorCells)
    }

    $regJson = Get-GateJson -Path $Register
    if ($null -eq $regJson) { throw ("{0}: the withhold register at {1} is empty or unparseable." -f $GATE, $Register) }
    $cellsJson = Get-GateJson -Path $AssessorCells
    if ($null -eq $cellsJson) { throw ("{0}: the assessor cells at {1} are empty or unparseable." -f $GATE, $AssessorCells) }

    #  The declared word pipeline must be the one this gate implements.
    $wp = Get-GateProp -Object $cellsJson -Names @('wordPipeline') -Default $null
    $declaredStem = [string](Get-GateProp -Object $wp -Names @('stem') -Default '')
    $pipelineNote = 'the assessor cells declare no word pipeline; this gate applied its own normalise + stem + stopword rule'
    if ($declaredStem) {
        if ($declaredStem.Trim() -ne $WR_STEM_RULE) {
            throw ("{0}: the assessor cells declare the stem rule '{1}' and this gate implements '{2}'. Two different vocabularies compared against each other report clean over live hits, so the gate refuses rather than guessing." -f $GATE, $declaredStem, $WR_STEM_RULE)
        }
        $pipelineNote = ("pipeline confirmed against the assessor cells' own declaration: {0}" -f $declaredStem)
    }

    $withheld = Get-WrWithheldRows -RegJson $regJson -CellsJson $cellsJson -MinBulletWords $MinBulletWords
    if (@($withheld.Rows).Count -eq 0) {
        throw ("{0}: the register and assessor cells resolved NO withheld row. A sweep with an empty check-set passes by having nothing to check, which is the failure rule 1 of gates.md exists to stop." -f $GATE)
    }

    $contract = Get-GateContract -BuildDir $BuildDir

    # --- every string on the spine, in every channel, enumerated from the spine
    #
    #  Two kinds of field are passed over, and both are DECLARED, never
    #  inferred. Structural identifiers and build metadata carry no prose. And
    #  a field the build declares DELIBERATELY WITHHELD FROM THE PAGE is not
    #  swept by THIS gate, because this gate's question is "can a reader see
    #  the answer" and that field reaches no reader - the rule that keeps it
    #  off the page is the renderer contract, section 21, not this one. Both
    #  lists are printed with their reasons.
    $unrendered = Get-GateUnrenderedFields -BuildDir $BuildDir
    $withheldFields = @{}
    foreach ($kv in $unrendered.GetEnumerator()) {
        if ("$($kv.Value)" -match '(?i)\bwithheld\b') { $withheldFields[$kv.Key] = "$($kv.Value)" }
    }
    $skip = @{}
    foreach ($k in (Get-GateUnrenderedFields -BuildDir $BuildDir -ForSweep).Keys) { $skip[$k] = $true }
    $structuralSkipped = @($skip.Keys)
    foreach ($k in $withheldFields.Keys) { $skip[$k] = $true }

    $cells = New-Object System.Collections.Generic.List[object]
    $spineFiles = 0
    foreach ($f in (Get-GateSpineFiles -BuildDir $BuildDir -SpineDir $SpineDir)) {
        $j = Get-GateJson -Path $f.FullName
        if ($null -eq $j) { continue }
        $spineFiles++
        foreach ($c in (Get-GateSpineCells -Node $j -File $f.Name -Path '' -Channel '' -Slot '' -Skip $skip)) { $cells.Add($c) }
    }
    $spineCells = $cells.Count

    foreach ($d in @($DocText | Where-Object { $_ })) {
        if (-not (Test-Path -LiteralPath $d)) { throw ("{0}: -DocText does not exist: {1}" -f $GATE, $d) }
        $leaf = Split-Path $d -Leaf
        $i = 0
        foreach ($line in ((Get-GateFileText -Path $d) -split "`r?`n")) {
            $i++
            if ("$line".Trim()) {
                $cells.Add([pscustomobject]@{ File = $leaf; Path = ("line {0}" -f $i); Channel = 'rendered'; Slot = ''; Text = [string]$line })
            }
        }
    }

    $channels = @($cells | ForEach-Object { $_.Channel } | Sort-Object -Unique)
    $chan = Resolve-WrChannelArtefacts -Channels $channels -Contract $contract -BuildDir $BuildDir -SkillDir $SkillDir -GuidePatterns $GuideRenderer -DeckPatterns $DeckRenderer

    # --- posed-question exemption
    $posed = Resolve-WrPosedFields -BuildDir $BuildDir -SpineDir $SpineDir -Contract $contract
    $posedKeys = @($posed.Fields.Keys)

    # --- allow-list, beside the rule it weakens
    $registry = Get-GateRegistry -BuildDir $BuildDir -RulesPath $RulesPath
    $allow = Get-GateAllowList -Registry $registry -Key 'withholdAllow' -IdField @('id', 'key', 'anchor', 'row', 'grid') -GateName $GATE

    # --- sweep
    $hits = New-Object System.Collections.Generic.List[object]
    $exempt = 0
    foreach ($c in $cells) {
        $n = ConvertTo-GateNormal $c.Text
        if (-not $n) { continue }
        $fieldPath = ($c.Path -replace '\[\d+\]', '')
        $isPosed = $false
        $posedBy = ''
        foreach ($k in $posedKeys) {
            if ($fieldPath -eq $k -or $fieldPath.EndsWith('.' + $k) -or $fieldPath.StartsWith($k + '.')) { $isPosed = $true; $posedBy = $k; break }
        }

        $words = $null
        foreach ($row in $withheld.Rows) {
            $named = $false
            foreach ($form in $row.Forms) {
                if ($n.Length -ge $form.Length -and $n.IndexOf($form, [System.StringComparison]::Ordinal) -ge 0) { $named = $true; break }
            }
            if (-not $named) { continue }
            if ($null -eq $words) { $words = Get-WrWordSet -Text $c.Text -KeepNumbers }
            #  EXACT VALUE MATCHING, at model-bullet granularity: the string
            #  must carry EVERYTHING one model bullet of this row states, not
            #  merely some words in common with it. Overlap alone cannot
            #  separate a leak from the guide TEACHING the row, which the
            #  coverage arm requires it to do - measured on the reference
            #  build, a two-word overlap rule fired on 817 cells, nearly all of
            #  them legitimate teaching, and a gate that fires on everything is
            #  a gate that is routed around within one build.
            $matched = 0
            $bulletHit = $false
            foreach ($bset in $row.Bullets) {
                $all = $true
                foreach ($w in $bset) { if (-not $words.Contains($w)) { $all = $false; break } }
                if ($all) { $bulletHit = $true; if ($bset.Count -gt $matched) { $matched = $bset.Count } }
            }
            if (-not $bulletHit) { continue }
            $overlap = $matched

            if ($isPosed) { $exempt++; continue }

            $art = 'both'
            if ($chan.Map.Contains($c.Channel)) { $art = [string]$chan.Map[$c.Channel] }
            $hits.Add([pscustomobject]@{
                File = $c.File; Path = $c.Path; FieldPath = $fieldPath; Channel = $c.Channel
                Artefact = $art; Slot = $c.Slot
                SubSection = $row.SubSection; Ref = $row.Ref; Id = $row.Id; Kind = $row.Kind
                Item = $row.Item; Allowance = $row.Allowance; Overlap = $overlap
            })
        }
    }

    # --- allowance and clearance, counted ONCE across both artefacts
    $byGrid = @{}
    foreach ($h in $hits) {
        $k = "{0}|{1}" -f $h.SubSection, $h.Id
        if (-not $byGrid.ContainsKey($k)) { $byGrid[$k] = New-Object System.Collections.Generic.List[object] }
        $byGrid[$k].Add($h)
    }

    $blocking = New-Object System.Collections.Generic.List[object]
    $withinAllowance = New-Object System.Collections.Generic.List[object]
    $cleared = New-Object System.Collections.Generic.List[object]
    $rowArtefacts = @{}

    foreach ($k in (@($byGrid.Keys) | Sort-Object)) {
        $list = @($byGrid[$k] | Sort-Object File, Path)
        $allowance = 0
        if ($list.Count -gt 0) { $allowance = [int]$list[0].Allowance }
        $seenRows = New-Object System.Collections.Generic.List[string]
        foreach ($h in $list) {
            $rowKey = "{0}|{1}" -f $k, $h.Item
            if (-not $rowArtefacts.ContainsKey($rowKey)) { $rowArtefacts[$rowKey] = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal) }
            [void]$rowArtefacts[$rowKey].Add($h.Artefact)

            $anchor = "{0}|{1}" -f $h.File, $h.Path
            $why = ''
            foreach ($cand in @($anchor, $h.Id, ("{0}|{1}" -f $h.Id, $h.Item), ("{0}|{1}" -f $h.SubSection, $h.Id), $h.Ref)) {
                if ($cand -and $allow.ContainsKey($cand)) { $why = $allow[$cand]; break }
            }
            if ($why) { $cleared.Add([pscustomobject]@{ Hit = $h; Why = $why }); continue }

            if (-not $seenRows.Contains($h.Item)) { $seenRows.Add($h.Item) }
            $rank = $seenRows.IndexOf($h.Item)
            if ($rank -lt $allowance) { $withinAllowance.Add($h) } else { $blocking.Add($h) }
        }
    }

    #  Rows answered in ONE artefact only. This is the build-wide fact the
    #  section is named for: one artefact filling a row the other withholds.
    $divergent = New-Object System.Collections.Generic.List[object]
    foreach ($rk in (@($rowArtefacts.Keys) | Sort-Object)) {
        $set = @($rowArtefacts[$rk])
        if ($set.Count -eq 1 -and ($set[0] -eq 'guide' -or $set[0] -eq 'deck')) {
            $parts = $rk -split '\|'
            $divergent.Add([pscustomobject]@{
                SubSection = $parts[0]; Id = $(if ($parts.Count -gt 1) { $parts[1] } else { '' })
                Item = $(if ($parts.Count -gt 2) { $parts[2] } else { '' })
                AnsweredIn = $set[0]
                WithheldIn = $(if ($set[0] -eq 'guide') { 'deck' } else { 'guide' })
            })
        }
    }

    return [pscustomobject]@{
        BuildDir = $BuildDir
        Register = $Register
        AssessorCells = $AssessorCells
        PipelineNote = $pipelineNote
        SpineFiles = $spineFiles
        SpineCells = $spineCells
        StructuralSkipped = @($structuralSkipped | Sort-Object)
        WithheldFieldsSkipped = $withheldFields
        RenderedCells = ($cells.Count - $spineCells)
        Channels = $channels
        ChannelMap = $chan
        Posed = $posed
        WithheldRows = @($withheld.Rows).Count
        WithheldGrids = @($withheld.Grids).Count
        Unmapped = @($withheld.Unmapped)
        Allow = $allow
        Hits = $hits.ToArray()
        Blocking = $blocking.ToArray()
        WithinAllowance = $withinAllowance.ToArray()
        Cleared = $cleared.ToArray()
        Exempt = $exempt
        Divergent = $divergent.ToArray()
    }
}

# ---------------------------------------------------------------------------
# Self-test - plant, VERIFY THE PLANT LANDED, then require the gate to fire
# ---------------------------------------------------------------------------

function Write-WrJson {
    param([string] $Path, $Object)
    $json = $Object | ConvertTo-Json -Depth 12
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($true)))
}

function New-WrFixture {
    <#  A build directory with a register, gate-only assessor cells, a spine
        and two renderer stubs, so the channel classification, the posed-
        question derivation and the sweep are all exercised on real inputs.  #>
    param([string] $Root)

    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Root 'spine') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Root 'corpus') -Force | Out-Null

    [System.IO.File]::WriteAllText((Join-Path $Root 'corpus\fixture_tool.txt'), "Task 1 fixture learner tool", (New-Object System.Text.UTF8Encoding($true)))

    Write-WrJson -Path (Join-Path $Root 'contract.json') -Object ([ordered]@{
        build = [ordered]@{ brand = 'FIXTURE' }
        wordFloors = [ordered]@{ topic = 50; underpinningKnowledge = 20 }
    })

    #  Two renderer stubs. The field names each reads are what tells the gate
    #  which artefact a channel belongs to.
    [System.IO.File]::WriteAllText((Join-Path $Root 'Build-Guide-Fixture.ps1'), @'
param($node)
$null = $node.whatThisMeans
$null = $node.underpinningKnowledge
$null = $node.selfCheck.questions
$null = $node.selfCheck.answerGuide
$null = $node.title
$null = $node.ref
'@, (New-Object System.Text.UTF8Encoding($true)))
    [System.IO.File]::WriteAllText((Join-Path $Root 'Build-Deck-Fixture.ps1'), @'
param($node)
$null = $node.slides
foreach ($s in $node.slides) { $null = $s.headline; $null = $s.bullets; $null = $s.notes }
'@, (New-Object System.Text.UTF8Encoding($true)))

    #  The register: two grids, both allowance 0 (each has an unassessed
    #  subject of the same class), one labelled and one numbered.
    Write-WrJson -Path (Join-Path $Root 'withhold-register.json') -Object ([ordered]@{
        unit = 'FIXTURE'
        documents = [ordered]@{ Fixture_Tool = [ordered]@{ audience = 'learner'; referencePattern = 'Fixture Task {n}({part})' } }
        subSections = [ordered]@{
            '1.1' = [ordered]@{
                subSection = '1.1'
                refs = @('Fixture Task 1(a)', 'Fixture Task 2(a)')
                tasks = @(
                    [ordered]@{
                        ref = 'Fixture Task 1(a)'; id = 'Fixture_Tool Task 1(a)'; document = 'Fixture_Tool'
                        kind = 'labelled'
                        headers = @('Part', 'What it needs')
                        assessedHeaders = @(1)
                        items = @('Widget Alpha', 'Widget Beta')
                        prefilledItems = @()
                        aliases = [ordered]@{ 'Widget Alpha' = @(); 'Widget Beta' = @() }
                        subjectClass = 'widget'
                        subjects = @()
                        unassessedSubjects = @('Widget Gamma')
                        allowance = 0
                        permittedGround = 'Set every example on Widget Gamma, which this task does not assess.'
                        shape = [ordered]@{ rows = 2; assessedColumns = 1 }
                    },
                    [ordered]@{
                        ref = 'Fixture Task 2(a)'; id = 'Fixture_Tool Task 2(a)'; document = 'Fixture_Tool'
                        kind = 'numbered'
                        headers = @('Number', 'Record', 'What it shows')
                        assessedHeaders = @(1, 2)
                        items = @('1', '2')
                        prefilledItems = @()
                        aliases = [ordered]@{ '1' = @(); '2' = @() }
                        subjectClass = 'record'
                        subjects = @('Cooling Chart', 'Transfer Log')
                        unassessedSubjects = @('Spare Log')
                        allowance = 0
                        permittedGround = 'Set every example on the Spare Log, which this task does not assess.'
                        shape = [ordered]@{ rows = 2; assessedColumns = 2 }
                    }
                )
                freeText = @()
                observations = @()
            }
        }
        unclassified = @()
        unresolvedReferences = @()
    })

    #  The content words are COMPUTED from the fixture's own model text through
    #  the same pipeline the generator uses, never typed. A hand-typed stem is a
    #  second source of truth, and a fixture whose stems are wrong proves the
    #  gate cannot fire when the truth is that the fixture could not be matched.
    function Get-WrFixtureWords {
        param([string] $Text)
        $s = Get-WrWordSet -Text $Text -KeepNumbers
        $a = New-Object System.Collections.Generic.List[string]
        foreach ($w in $s) { $a.Add($w) }
        return @($a.ToArray() | Sort-Object)
    }

    $mAlpha1 = 'fitted with a sprocket before service'
    $mAlpha2 = 'the flange is torqued to the plate'
    $mBeta1  = 'a grommet seals the collar'
    $mBeta2  = 'the ratchet holds the arm'
    $mRec1   = 'every chill reading taken with a probe is recorded'
    $mRec2   = 'the vehicle the load and the temperature are noted'

    Write-WrJson -Path (Join-Path $Root 'assessor-cells.json') -Object ([ordered]@{
        _WARNING = 'GATE-ONLY fixture. Synthetic content; no real model answer appears here.'
        wordPipeline = [ordered]@{ normalise = 'lower case, letters digits and single spaces only'; stem = $WR_STEM_RULE; stopwords = 176 }
        grids = @(
            [ordered]@{
                ref = 'Fixture Task 1(a)'; id = 'Fixture_Tool Task 1(a)'; subSection = '1.1'; kind = 'labelled'
                document = 'Fixture_Tool'; headers = @('Part', 'What it needs'); assessedHeaders = @(1); rowSource = 'modelRows'
                rows = @(
                    [ordered]@{ item = 'Widget Alpha'; assessed = $true; cells = @([ordered]@{ col = 1; header = 'What it needs'; state = 'answered'; bullets = @(
                        [ordered]@{ text = $mAlpha1; words = (Get-WrFixtureWords $mAlpha1) },
                        [ordered]@{ text = $mAlpha2; words = (Get-WrFixtureWords $mAlpha2) }
                    ) }) },
                    [ordered]@{ item = 'Widget Beta'; assessed = $true; cells = @([ordered]@{ col = 1; header = 'What it needs'; state = 'answered'; bullets = @(
                        [ordered]@{ text = $mBeta1; words = (Get-WrFixtureWords $mBeta1) },
                        [ordered]@{ text = $mBeta2; words = (Get-WrFixtureWords $mBeta2) }
                    ) }) }
                )
                extraPoints = @()
            },
            [ordered]@{
                ref = 'Fixture Task 2(a)'; id = 'Fixture_Tool Task 2(a)'; subSection = '1.1'; kind = 'numbered'
                document = 'Fixture_Tool'; headers = @('Number', 'Record', 'What it shows'); assessedHeaders = @(1, 2); rowSource = 'modelRows'
                rows = @(
                    [ordered]@{ item = '1'; assessed = $true; cells = @([ordered]@{ col = 1; header = 'Record'; state = 'answered'; bullets = @(
                        [ordered]@{ text = 'the Cooling Chart'; words = @() },
                        [ordered]@{ text = $mRec1; words = (Get-WrFixtureWords $mRec1) }
                    ) }) },
                    [ordered]@{ item = '2'; assessed = $true; cells = @([ordered]@{ col = 1; header = 'Record'; state = 'answered'; bullets = @(
                        [ordered]@{ text = 'the Transfer Log'; words = @() },
                        [ordered]@{ text = $mRec2; words = (Get-WrFixtureWords $mRec2) }
                    ) }) }
                )
                extraPoints = @()
            }
        )
        freeText = @()
        taskLevel = @()
    })

    #  A clean spine. Nothing here answers a withheld row.
    $clean = [ordered]@{
        ref = '1.1'; pc = '1.1'; topic = 1; title = 'Fixture sub-section'
        whatThisMeans = @(
            'This sub-section explains why the fixture matters and what the worker does about it.',
            'A Widget Gamma is the example the pack does not assess, so it is the safe ground for a worked example.'
        )
        remember = 'Read the register before you write the example.'
        underpinningKnowledge = @(
            'The fixture teaches the mechanism rather than the answer, so a learner arrives able to reason.',
            'The Spare Log is the record this task does not assess, and it is where the examples are set.',
            'A record exists so that a decision made in the moment can be checked later by somebody else.',
            'Teaching a subject is not the same as filling in the row the assessment asks the learner to fill.'
        )
        regulatoryBasis = @('The fixture cites nothing, because it is a fixture.')
        howToDoIt = @(
            [ordered]@{ step = 'Read the task'; detail = 'Read the whole task before starting on any of it.' }
        )
        selfCheck = [ordered]@{
            questions = @(
                'What does a Widget Gamma need before service?',
                'Which record would you use to check a decision after the run?'
            )
            answerGuide = @(
                'Points to the teaching above rather than to a model answer.',
                'Points to the teaching above rather than to a model answer.'
            )
        }
        assessmentLink = [ordered]@{ refs = @('Fixture Task 1(a)', 'Fixture Task 2(a)'); wording = 'Prepares you for: Fixture Task 1(a) and Fixture Task 2(a).' }
        slides = @(
            [ordered]@{
                layout = 'single'; kind = 'teaching'; headline = 'The fixture slide'
                bullets = @('Set every example on the ground the task does not assess.')
                notes = 'Talk through the Spare Log as the example ground and leave the assessed records to the learner.'
            }
        )
        openQuestions = @()
        provenance = @()
    }
    Write-WrJson -Path (Join-Path $Root 'spine\t1_1.1.json') -Object $clean
    Write-WrJson -Path (Join-Path $Root 'spine\t1_topic.json') -Object ([ordered]@{
        number = 1; element = '1'; title = 'Fixture topic'; elementText = 'Fixture element'
        overview = 'The fixture topic exists so the sweep has more than one file to read.'
        outcomes = @('Understand the fixture.'); summary = @('The fixture is a fixture.')
        slides = @([ordered]@{ layout = 'single'; kind = 'title'; headline = 'Fixture topic'; bullets = @('Fixture'); notes = 'Open the topic.' })
        openQuestions = @(); provenance = @()
    })
    return $Root
}

function Invoke-WrSelfTest {
    param([string] $SkillDir, [int] $MinBulletWords)

    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('wrgate_' + [Guid]::NewGuid().ToString('N').Substring(0, 12))
    $failures = 0
    $records = New-Object System.Collections.Generic.List[object]

    function Record {
        param([string] $Name, [bool] $Ok, [string] $Detail)
        $script:WrSelfRecords.Add([pscustomobject]@{ test = $Name; ok = $Ok; detail = $Detail })
        if ($Ok) { Write-Host ("    ok   {0} - {1}" -f $Name, $Detail) -ForegroundColor Green }
        else { Write-Host ("    X    {0} - {1}" -f $Name, $Detail) -ForegroundColor Red }
    }
    $script:WrSelfRecords = $records

    try {
        Write-Host ''
        Write-Host '  SELF-TEST - each defect is planted, the plant is VERIFIED TO HAVE LANDED in the exact' -ForegroundColor Cyan
        Write-Host '  channel the sweep reads, and only then is the sweep required to fire on it.' -ForegroundColor Cyan

        New-WrFixture -Root $root | Out-Null

        #  ---- control: the clean fixture must NOT fire
        $r0 = Invoke-WrSweep -BuildDir $root -SkillDir $SkillDir -MinBulletWords $MinBulletWords
        Record 'control (clean fixture)' ($r0.Blocking.Count -eq 0) ("{0} withheld row(s) resolved across {1} grid(s), {2} channel(s) swept, {3} blocking hit(s)" -f $r0.WithheldRows, $r0.WithheldGrids, @($r0.Channels).Count, $r0.Blocking.Count)
        if ($r0.WithheldRows -lt 4) { Record 'control (check-set)' $false ('only {0} withheld row(s) resolved; the fixture defines four' -f $r0.WithheldRows) }
        else { Record 'control (check-set)' $true 'all four fixture rows resolved with their model content words' }

        $spineFile = Join-Path $root 'spine\t1_1.1.json'

        #  ---- the four plants, applied together to one spine file
        $j = Get-GateJson -Path $spineFile

        $plants = @(
            [pscustomobject]@{
                Name = 'withheld value answered in the GUIDE only'
                Channel = 'underpinningKnowledge'
                Text = 'Record every chill reading on the Cooling Chart with a probe thermometer as the run goes on.'
                Item = 'Cooling Chart'; MustFire = $true; Artefact = 'guide'
            },
            [pscustomobject]@{
                Name = 'the same defect in the DECK only'
                Channel = 'slides'
                Text = 'Transfer Log: note the vehicle, the load and the temperature before it leaves.'
                Item = 'Transfer Log'; MustFire = $true; Artefact = 'deck'
            },
            [pscustomobject]@{
                Name = 'withheld value inside a genuinely POSED QUESTION'
                Channel = 'selfCheck'
                Text = 'What does a Widget Alpha need before service - a sprocket, and a flange torqued to the plate?'
                Item = 'Widget Alpha'; MustFire = $false; Artefact = 'guide'
            },
            [pscustomobject]@{
                Name = 'reads like a question but sits in a BODY field'
                Channel = 'whatThisMeans'
                Text = 'What does a Widget Alpha need before service? A sprocket, and a flange torqued to the plate.'
                Item = 'Widget Alpha'; MustFire = $true; Artefact = 'guide'
            }
        )

        $j.underpinningKnowledge = @(@($j.underpinningKnowledge) + $plants[0].Text)
        $j.slides[0].notes = $plants[1].Text
        $j.selfCheck.questions = @(@($j.selfCheck.questions) + $plants[2].Text)
        $j.whatThisMeans = @(@($j.whatThisMeans) + $plants[3].Text)
        Write-WrJson -Path $spineFile -Object $j

        #  ---- VERIFY EVERY PLANT LANDED, in the exact channel the sweep reads
        $skip = @{}
        foreach ($k in (Get-GateUnrenderedFields -BuildDir $root -ForSweep).Keys) { $skip[$k] = $true }
        $back = Get-GateJson -Path $spineFile
        $landedCells = @(Get-GateSpineCells -Node $back -File 't1_1.1.json' -Path '' -Channel '' -Slot '' -Skip $skip)
        $allLanded = $true
        foreach ($p in $plants) {
            $m = @($landedCells | Where-Object { $_.Text -eq $p.Text -and $_.Channel -eq $p.Channel })
            if ($m.Count -eq 0) {
                Record ('plant landed: ' + $p.Name) $false ("the planted string is NOT in channel '{0}' of the file the sweep reads - this plant proves nothing" -f $p.Channel)
                $allLanded = $false
            }
            else {
                Record ('plant landed: ' + $p.Name) $true ("present at {0} in channel '{1}'" -f $m[0].Path, $p.Channel)
            }
        }
        if (-not $allLanded) { throw ("{0}: at least one self-test plant did not land. A gate proved against a plant that was a no-op is not proved." -f $GATE) }

        #  ---- now the sweep must fire on exactly the plants that must fire
        $r1 = Invoke-WrSweep -BuildDir $root -SkillDir $SkillDir -MinBulletWords $MinBulletWords

        foreach ($p in $plants) {
            $hit = @($r1.Blocking | Where-Object { $_.Channel -eq $p.Channel -and $_.Item -eq $p.Item })
            if ($p.MustFire) {
                if ($hit.Count -gt 0) { Record ('gate fires: ' + $p.Name) $true ("blocked on {0} {1} (channel {2}, artefact {3}, item '{4}')" -f $hit[0].File, $hit[0].Path, $hit[0].Channel, $hit[0].Artefact, $hit[0].Item) }
                else { Record ('gate fires: ' + $p.Name) $false ("the plant landed in channel '{0}' and the sweep did NOT find it" -f $p.Channel) }
            }
            else {
                if ($hit.Count -eq 0) { Record ('gate stays silent: ' + $p.Name) $true 'the posed-question node type exempted it, and the same sentence in a body field still fires' }
                else { Record ('gate stays silent: ' + $p.Name) $false 'a genuinely posed question was reported as a leak; the exemption is not structural' }
            }
        }

        #  ---- the artefact attribution and the build-wide claim
        $gOnly = @($r1.Divergent | Where-Object { $_.AnsweredIn -eq 'guide' })
        $dOnly = @($r1.Divergent | Where-Object { $_.AnsweredIn -eq 'deck' })
        Record 'build-wide: a row answered in the guide only is named' ($gOnly.Count -ge 1) ("{0} row(s) answered in the guide alone" -f $gOnly.Count)
        Record 'build-wide: a row answered in the deck only is named' ($dOnly.Count -ge 1) ("{0} row(s) answered in the deck alone" -f $dOnly.Count)

        $failures = @($records | Where-Object { -not $_.ok }).Count
        return [pscustomobject]@{ Failures = $failures; Records = $records.ToArray(); Fixture = $root }
    }
    finally {
        if ($root -and (Test-Path -LiteralPath $root) -and $root.Length -gt 20) {
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

$script:WrQuiet = [bool]$Quiet

if ($SelfTest -and -not $BuildDir) {
    $st = Invoke-WrSelfTest -SkillDir $SkillDir -MinBulletWords $MinBulletWords
    Write-Host ''
    if ($st.Failures -gt 0) {
        Write-Host ("  X {0}: self-test FAILED - {1} of {2} check(s) did not hold." -f $GATE, $st.Failures, @($st.Records).Count) -ForegroundColor Red
        exit 4
    }
    Write-Host ("  {0}: self-test passed - {1} check(s), every plant verified to have landed before the sweep was believed." -f $GATE, @($st.Records).Count) -ForegroundColor Green
    exit 0
}

if (-not $BuildDir) { Stop-WrUsage '-BuildDir is required (or run with -SelfTest alone to prove the gate on a fixture).' }
if (-not (Test-Path -LiteralPath $BuildDir)) { Stop-WrUsage ("build directory not found: {0}" -f $BuildDir) }
if (-not $OutPath) { $OutPath = Join-Path $BuildDir 'withhold-enforcement.json' }

$selfTestFailures = 0
$selfTestRecords = @()
if ($SelfTest) {
    $st = Invoke-WrSelfTest -SkillDir $SkillDir -MinBulletWords $MinBulletWords
    $selfTestFailures = $st.Failures
    $selfTestRecords = $st.Records
}

$result = $null
try {
    $result = Invoke-WrSweep -BuildDir $BuildDir -Register $Register -AssessorCells $AssessorCells `
        -SpineDir $SpineDir -RulesPath $RulesPath -DocText $DocText `
        -GuideRenderer $GuideRenderer -DeckRenderer $DeckRenderer -SkillDir $SkillDir `
        -MinBulletWords $MinBulletWords
}
catch {
    Stop-WrUsage $_.Exception.Message
}

if (-not $Quiet) {
    Write-Host ''
    Write-Host 'WITHHOLD REGISTER ENFORCEMENT - build-wide, every channel of both artefacts' -ForegroundColor Cyan
    Write-Host ("  register:       {0}" -f (Split-Path $result.Register -Leaf)) -ForegroundColor DarkGray
    Write-Host ("  assessor cells: {0}  (GATE-ONLY; read for content-word sets, never printed)" -f (Split-Path $result.AssessorCells -Leaf)) -ForegroundColor DarkGray
    Write-Host ("  word pipeline:  {0}" -f $result.PipelineNote) -ForegroundColor DarkGray
    Write-GateCheckSet -What 'withheld rows' -Count $result.WithheldRows -DerivedFrom ("the register's {0} assessed grid(s), matched to the gate-only assessor cells' model rows" -f $result.WithheldGrids)
    if (@($result.Unmapped).Count -gt 0) {
        Write-Host ("  ! {0} register row(s) have no model row in the assessor cells and are NOT checked:" -f @($result.Unmapped).Count) -ForegroundColor Yellow
        foreach ($u in ($result.Unmapped | Select-Object -First 12)) { Write-Host ("      {0}" -f $u) -ForegroundColor Yellow }
        if (@($result.Unmapped).Count -gt 12) { Write-Host ("      ... and {0} more" -f (@($result.Unmapped).Count - 12)) -ForegroundColor Yellow }
    }

    Write-Host ''
    Write-Host ("  channels swept: {0} - {1}" -f @($result.Channels).Count, (@($result.Channels) -join ', ')) -ForegroundColor DarkGray
    Write-Host ("  strings examined: {0} across {1} spine file(s), {2} in rendered extract(s)" -f $result.SpineCells, $result.SpineFiles, $result.RenderedCells) -ForegroundColor DarkGray
    Write-Host ("  fields passed over as structural or build metadata: {0}" -f (@($result.StructuralSkipped) -join ', ')) -ForegroundColor DarkGray
    foreach ($k in (@($result.WithheldFieldsSkipped.Keys) | Sort-Object)) {
        Write-Host ("  field passed over as declared withheld from the page: {0} - {1}" -f $k, $result.WithheldFieldsSkipped[$k]) -ForegroundColor DarkGray
    }
    $cm = $result.ChannelMap
    Write-Host ("  artefact per channel, derived from the renderers ({0} guide-side file(s) reading {1} field name(s); {2} deck-side file(s) reading {3}):" -f @($cm.GuideRenderers).Count, $cm.GuideFieldCount, @($cm.DeckRenderers).Count, $cm.DeckFieldCount) -ForegroundColor DarkGray
    foreach ($c in @($result.Channels)) {
        Write-Host ("      {0,-24} {1,-6} ({2})" -f $c, $cm.Map[$c], $cm.How[$c]) -ForegroundColor DarkGray
    }

    Write-Host ''
    Write-Host ("  posed-question node types - {0} field path(s), resolved from:" -f @($result.Posed.Fields.Keys).Count) -ForegroundColor DarkGray
    foreach ($s in $result.Posed.Sources) { Write-Host ("      {0}" -f $s) -ForegroundColor DarkGray }
    foreach ($k in @($result.Posed.Fields.Keys)) { Write-Host ("      exempt: {0} - {1}" -f $k, $result.Posed.Fields[$k]) -ForegroundColor DarkGray }
    Write-Host ("      {0} string(s) matched a withheld row inside one of those node types and were NOT reported." -f $result.Exempt) -ForegroundColor DarkGray
    Write-Host '      Every other channel is swept, so a channel invented later is swept by default.' -ForegroundColor DarkGray

    if ($result.Allow.Count -gt 0) {
        Write-Host ''
        Write-Host ("  allow-list, from figures.json withholdAllow - {0} entr(ies), surfaced to the audit as evidence:" -f $result.Allow.Count) -ForegroundColor DarkGray
        foreach ($k in ($result.Allow.Keys | Sort-Object)) { Write-Host ("      {0}: {1}" -f $k, $result.Allow[$k]) -ForegroundColor DarkGray }
    }
    else {
        Write-Host ''
        Write-Host '  allow-list, from figures.json withholdAllow: empty - nothing is cleared' -ForegroundColor DarkGray
    }
}

# --- report file
$out = [pscustomobject]@{
    gate = $GATE
    generated = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
    buildDir = $result.BuildDir
    rule = 'no withheld value appears outside a posed-question context, in any channel of either artefact; the register allowance is counted once across both artefacts, so a row answered in one and withheld in the other blocks'
    inputs = [pscustomobject]@{
        register = $result.Register
        assessorCells = $result.AssessorCells
        assessorCellsNote = 'GATE-ONLY. Read for content-word sets. No model bullet, benchmark or answering cell text appears in this report.'
        wordPipeline = $result.PipelineNote
        minContentWords = $MinBulletWords
        docText = @($DocText | Where-Object { $_ })
    }
    checkSet = [pscustomobject]@{ withheldRows = $result.WithheldRows; grids = $result.WithheldGrids; unmappedRows = $result.Unmapped }
    channels = [pscustomobject]@{
        swept = @($result.Channels)
        artefact = $result.ChannelMap.Map
        decidedBy = $result.ChannelMap.How
        guideRenderers = @($result.ChannelMap.GuideRenderers | ForEach-Object { Split-Path $_ -Leaf })
        deckRenderers = @($result.ChannelMap.DeckRenderers | ForEach-Object { Split-Path $_ -Leaf })
        spineFiles = $result.SpineFiles
        spineStrings = $result.SpineCells
        renderedStrings = $result.RenderedCells
        passedOverAsStructural = @($result.StructuralSkipped)
        passedOverAsDeclaredWithheldFromThePage = $result.WithheldFieldsSkipped
    }
    posedQuestionFields = [pscustomobject]@{
        fields = $result.Posed.Fields
        resolvedFrom = $result.Posed.Sources
        withheldCompanionFields = $result.Posed.WithheldCompanions
        exemptedStrings = $result.Exempt
    }
    blocking = $result.Blocking
    blockingByRow = @($result.Blocking | Group-Object { "{0}`t{1}`t{2}" -f $_.Ref, $_.Item, $_.Id } | ForEach-Object {
        $g0 = $_.Group[0]
        [pscustomobject]@{
            ref = $g0.Ref; item = $g0.Item; id = $g0.Id; kind = $g0.Kind; subSection = $g0.SubSection
            allowance = $g0.Allowance; anchors = $_.Count
            artefacts = @($_.Group | ForEach-Object { $_.Artefact } | Sort-Object -Unique)
            channels = @($_.Group | ForEach-Object { $_.Channel } | Sort-Object -Unique)
            allowKey = ("{0}|{1}" -f $g0.Id, $g0.Item)
        }
    })
    withinAllowance = $result.WithinAllowance
    cleared = @($result.Cleared | ForEach-Object { [pscustomobject]@{ hit = $_.Hit; reason = $_.Why } })
    answeredInOneArtefactOnly = $result.Divergent
    summary = [pscustomobject]@{
        hits = @($result.Hits).Count
        blocking = @($result.Blocking).Count
        withinAllowance = @($result.WithinAllowance).Count
        cleared = @($result.Cleared).Count
        exempt = $result.Exempt
        answeredInOneArtefactOnly = @($result.Divergent).Count
    }
    selfTest = [pscustomobject]@{ run = [bool]$SelfTest; failures = $selfTestFailures; checks = $selfTestRecords }
}
$json = $out | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($OutPath, $json, (New-Object System.Text.UTF8Encoding($true)))
Write-WrLine ("  written to {0}" -f $OutPath)

# --- verdict
Write-Host ''
foreach ($c in $result.Cleared) {
    Write-Host ("  ok [{0}] {1} - cleared on figures.json withholdAllow: {2}" -f $c.Hit.File, $c.Hit.Path, $c.Why) -ForegroundColor DarkGray
}
if (@($result.WithinAllowance).Count -gt 0) {
    Write-Host ("  {0} string(s) sit inside the register's own allowance (the permitted exemplar row), counted once across both artefacts:" -f @($result.WithinAllowance).Count) -ForegroundColor DarkGray
    $shownAllow = 0
    foreach ($h in $result.WithinAllowance) {
        if ($shownAllow -ge 10) { break }
        Write-Host ("      [{0}] {1}  channel {2} ({3})  {4} / item '{5}'" -f $h.File, $h.Path, $h.Channel, $h.Artefact, $h.Ref, $h.Item) -ForegroundColor DarkGray
        $shownAllow++
    }
    if (@($result.WithinAllowance).Count -gt $shownAllow) { Write-Host ("      ... and {0} more; the complete list is in the report file" -f (@($result.WithinAllowance).Count - $shownAllow)) -ForegroundColor DarkGray }
}

if (@($result.Divergent).Count -gt 0) {
    Write-Host ''
    Write-Host ("  BUILD-WIDE: {0} withheld row(s) are answered in ONE artefact only. A corrected guide beside an" -f @($result.Divergent).Count) -ForegroundColor Yellow
    Write-Host '  uncorrected deck is worse than either alone - fix both, or neither is fixed.' -ForegroundColor Yellow
    foreach ($d in $result.Divergent) {
        Write-Host ("      {0} / item '{1}': answered in the {2}, withheld in the {3}" -f $d.Id, $d.Item, $d.AnsweredIn, $d.WithheldIn) -ForegroundColor Yellow
    }
}

if ($selfTestFailures -gt 0) {
    Write-Host ''
    Write-Host ("  X {0}: self-test FAILED ({1} check(s)). No result from this gate is believable until it fails on a planted defect." -f $GATE, $selfTestFailures) -ForegroundColor Red
    exit 4
}

if (@($result.Blocking).Count -eq 0) {
    Write-Host ''
    Write-Host ("  no withheld value appears outside a posed-question context in any of the {0} channel(s) swept" -f @($result.Channels).Count) -ForegroundColor Green
    exit 0
}

#  ONE FINDING PER WITHHELD ROW, with every anchor under it. Thirty-eight
#  anchors on one row is one decision a reader has to make, not thirty-eight,
#  and a console that prints them as thirty-eight is a console nobody finishes
#  reading. The COMPLETE anchor list is always in the report file, because a
#  finding cannot be closed against a list nobody has.
$groups = @($result.Blocking | Group-Object { "{0}`t{1}`t{2}" -f $_.Ref, $_.Item, $_.Id } | Sort-Object { -$_.Count })
Write-Host ''
Write-Host ("  X {0} withheld row(s) are answered outside a posed-question context, in {1} string(s) across {2} channel(s)" -f $groups.Count, @($result.Blocking).Count, @($result.Blocking | Group-Object Channel).Count) -ForegroundColor Red
foreach ($g in $groups) {
    $first = $g.Group[0]
    $arts = @($g.Group | ForEach-Object { $_.Artefact } | Sort-Object -Unique)
    Write-Host ''
    Write-Host ("    {0}, {1} grid, withheld item '{2}' - allowance {3}, answered in {4} place(s) [{5}]" -f $first.Ref, $first.Kind, $first.Item, $first.Allowance, $g.Count, ($arts -join ' + ')) -ForegroundColor Red
    $shown = 0
    foreach ($h in ($g.Group | Sort-Object File, Path)) {
        if ($shown -ge 10) { break }
        Write-Host ("      [{0}] {1}{2}  channel {3} ({4}-facing)" -f $h.File, $h.Path, $(if ($h.Slot) { " slot $($h.Slot)" } else { '' }), $h.Channel, $h.Artefact) -ForegroundColor Yellow
        $shown++
    }
    if ($g.Count -gt $shown) { Write-Host ("      ... and {0} more anchor(s); the complete list is in the report file" -f ($g.Count - $shown)) -ForegroundColor DarkGray }
    Write-Host ("      allow key if cleared by reading the sources: {0}|{1}" -f $first.Id, $first.Item) -ForegroundColor DarkGray
}
Write-Host ''
Write-Host '  Fix on the spine and re-run. Withholding is a build-wide fact: the guide and the deck are swept' -ForegroundColor Yellow
Write-Host '  together and share one allowance, so moving the answer from one to the other is not a fix. A' -ForegroundColor Yellow
Write-Host '  legitimate single exemplar is cleared in figures.json "withholdAllow" with a written reason,' -ForegroundColor Yellow
Write-Host '  never by widening the posed-question exemption.' -ForegroundColor Yellow
exit 1
