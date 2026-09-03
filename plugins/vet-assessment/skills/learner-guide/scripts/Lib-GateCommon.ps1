<#
    Lib-GateCommon.ps1 - the pieces every spine gate shares, in ONE place.

    DOT-SOURCE THIS FILE:

        . "$PSScriptRoot\Lib-GateCommon.ps1"

    WHY IT EXISTS. The gates promoted beside it all have to answer the same four
    questions: where is the canonical corpus, which of its documents are
    learner-facing and which are assessor-only, what does the spine actually
    say, and what has a human deliberately allowed. Every build that answered
    those questions inside its own gate script answered them slightly
    differently, and the difference was where the defects lived: one gate read
    a hand-typed list of two document names and missed the two documents nobody
    had extracted; another hand-listed three of nine palette hexes and printed
    "no crossover" over 766 live ones. A hand-copied list is a second source of
    truth, and a second source of truth is free to drift. So the shared answers
    live here and are DERIVED, once.

    NOTHING IN THIS FILE DECIDES ANYTHING. It locates, parses, normalises and
    enumerates. Every verdict belongs to the gate that calls it, so that a gate
    can be read on its own and its failure condition understood without reading
    this file.

    PS 5.1. ASCII only in this file.
#>

# ---------------------------------------------------------------------------
# Reading files the way this toolchain has to read them
# ---------------------------------------------------------------------------

function Get-GateFileText {
    <#  Read a text file as EXPLICIT UTF-8 and drop a leading BOM.

        Windows PowerShell 5.1 decodes a BOM-less UTF-8 file as ANSI, which
        turns every non-ASCII character in a pack extract into mojibake and
        makes a verbatim-phrase sweep silently miss the phrase it was written
        to find. A BOM left on the front of a JSON string makes ConvertFrom-Json
        throw on a file that is perfectly valid.  #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    $full = (Resolve-Path -LiteralPath $Path).Path
    $t = [System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8)
    return $t.TrimStart([char]0xFEFF)
}

function Get-GateJson {
    <# Parse a JSON file, or return $null if it is absent or empty. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)

    $t = Get-GateFileText -Path $Path
    if (-not $t.Trim()) { return $null }
    return ($t | ConvertFrom-Json)
}

function Get-GateProp {
    <#  Read a property under EVERY name it is known by.

        This is not defensive padding. A single-name lookup is exactly the
        defect that left 766 of another brand's fills in a delivered set: the
        palette role is called lightFill on a branding file's own palette and
        Fill on the object the swap actually passes, so the lookup fell through
        to its default, the role mapped to itself, the apply loop skipped a
        pair that maps to itself, nothing was written and nothing errored.

        Where a lookup MUST resolve, pass -Required: an unresolved role is an
        error, never a silent no-op.  #>
    [CmdletBinding()]
    param(
        $Object,
        [Parameter(Mandatory)][string[]] $Names,
        $Default,
        [switch] $Required,
        [string] $What = 'property'
    )

    if ($null -ne $Object) {
        $have = @($Object.PSObject.Properties.Name)
        foreach ($n in $Names) {
            if ($have -contains $n) {
                $v = $Object.$n
                # PRESENT means non-null and, for a string, non-empty. Do NOT test
                # "$v" -ne '' on everything: in PS 5.1 an array of objects
                # stringifies to '' so data:[...] and visuals:[...] read as ABSENT,
                # fell through to the default, and a caller wasted a paid probe
                # image before it was traced. Collections count by Count.
                if ($null -eq $v) { continue }
                if ($v -is [string]) { if ($v -ne '') { return $v } else { continue } }
                if ($v -is [System.Collections.ICollection]) { if ($v.Count -gt 0) { return $v } else { continue } }
                return $v
            }
        }
    }
    if ($Required) {
        throw ("Unresolved {0}: none of [{1}] is present and non-empty on the supplied object. Resolution is total - a lookup that can silently return its own default is how a role maps to itself and a whole swap is skipped without error." -f $What, ($Names -join ', '))
    }
    return $Default
}

function Get-GateContract {
    <# The build contract, or $null. Gates degrade to documented defaults without it. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $BuildDir)
    return (Get-GateJson -Path (Join-Path $BuildDir 'contract.json'))
}

function Get-GateRegistry {
    <#  The figure registry, which is also where every allow-list lives.

        AN ALLOW-LIST BELONGS BESIDE THE RULE IT WEAKENS, IN A VERSIONED FILE.
        A previous build held the mirror gate's allow-list as a script
        PARAMETER DEFAULT with its reasons in a separate in-file hashtable, so
        the thing that turned a compliance check off for one figure was
        invisible to the audit that trusted the check.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [string] $RulesPath
    )
    if (-not $RulesPath) { $RulesPath = Join-Path $BuildDir 'figures.json' }
    return (Get-GateJson -Path $RulesPath)
}

function Get-GateAllowList {
    <#  Read an allow-list out of the registry as id -> written reason.

        REFUSES an entry with no reason. An allow-list entry that does not say
        why is not an allow-list entry, it is a gate quietly switched off, and
        the audit that is handed this list as evidence has nothing to read.  #>
    [CmdletBinding()]
    param(
        $Registry,
        [Parameter(Mandatory)][string] $Key,
        [Parameter(Mandatory)][string[]] $IdField,
        [string[]] $ReasonField = @('reason', 'why', 'note'),
        [string] $GateName = 'this gate'
    )

    $out = @{}
    if ($null -eq $Registry) { return $out }
    if (@($Registry.PSObject.Properties.Name) -notcontains $Key) { return $out }

    foreach ($e in @($Registry.$Key)) {
        if ($null -eq $e) { continue }
        if ($e -is [string]) {
            throw ("{0}: allow-list '{1}' carries a bare string '{2}'. Every entry must be an object with an id and a written reason, because an allow-list nobody can audit is a way of turning a gate off." -f $GateName, $Key, $e)
        }
        $id = Get-GateProp -Object $e -Names $IdField
        $why = Get-GateProp -Object $e -Names $ReasonField
        if (-not $id) {
            throw ("{0}: an entry in allow-list '{1}' names no {2}." -f $GateName, $Key, ($IdField -join '/'))
        }
        if (-not $why -or "$why".Trim().Length -lt 20) {
            throw ("{0}: allow-list '{1}' entry '{2}' carries no written reason (or one too short to be one). Record WHY the hit was cleared, by reading the source, so the audit can weigh it." -f $GateName, $Key, $id)
        }
        $out["$id"] = "$why"
    }
    return $out
}

# ---------------------------------------------------------------------------
# The canonical corpus
# ---------------------------------------------------------------------------

function Get-GateCorpusDir {
    <#  Where the ONE canonical extraction of the pack lives.

        Order: an explicit -CorpusDir, then the build's corpus directory, then
        the older locations a pre-corpus build wrote to. Every gate resolves it
        the same way so two gates can never read two different extractions of
        the same pack - which happened: one directory held two documents the
        other did not, the leak the final audit found was in one of the two
        missing documents, and no gate could see it because no gate read it.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [string] $CorpusDir
    )

    $tried = New-Object System.Collections.Generic.List[string]
    $cands = New-Object System.Collections.Generic.List[string]
    if ($CorpusDir) { $cands.Add($CorpusDir) }
    $cands.Add((Join-Path $BuildDir 'corpus'))
    $cands.Add((Join-Path $BuildDir 'cleanroom\pack'))
    $cands.Add((Join-Path $BuildDir 'packtext'))

    foreach ($c in $cands) {
        $tried.Add($c)
        if ((Test-Path -LiteralPath $c) -and @(Get-ChildItem -LiteralPath $c -Filter '*.txt' -File -ErrorAction SilentlyContinue).Count -gt 0) {
            return (Resolve-Path -LiteralPath $c).Path
        }
    }

    throw ("No corpus of pack text found. Looked in:`n{0}`nStage 1 extracts EVERY pack document - learner-facing and assessor-only - exactly once into one canonical directory. A gate cannot sweep a document nobody extracted." -f (($tried | ForEach-Object { "  $_" }) -join "`n"))
}

function Get-GateCorpusDocs {
    <#  Every corpus document, classified learner-facing or assessor-only.

        The classification is DERIVED, in this order, and the gate prints which
        source it used so a reader can see what the sweep believed:
          1. the corpus manifest Stage 1 writes (documents[].audience)
          2. the build contract's corpus.documents list
          3. the filename, against a declared pattern

        Never a list of document names typed into a gate. A gate that names its
        two learner documents by hand cannot notice the two nobody extracted.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $CorpusDir,
        [string] $BuildDir,
        [string] $AssessorRx = '(?i)(assessor|marking[_ -]?guide|benchmark|model[_ -]?answer|answer[_ -]?key|marker)'
    )

    $map = @{}
    $src = 'filename pattern'

    $manifest = Get-GateJson -Path (Join-Path $CorpusDir 'manifest.json')
    if ($null -eq $manifest -and $BuildDir) {
        $contract = Get-GateContract -BuildDir $BuildDir
        if ($null -ne $contract -and @($contract.PSObject.Properties.Name) -contains 'corpus') { $manifest = $contract.corpus }
    }
    if ($null -ne $manifest -and @($manifest.PSObject.Properties.Name) -contains 'documents') {
        foreach ($d in @($manifest.documents)) {
            $f = Get-GateProp -Object $d -Names @('file', 'name', 'document')
            $a = Get-GateProp -Object $d -Names @('audience', 'class', 'facing')
            if ($f -and $a) { $map[[System.IO.Path]::GetFileNameWithoutExtension("$f")] = "$a".ToLowerInvariant() }
        }
        if ($map.Count -gt 0) { $src = 'corpus manifest' }
    }

    $docs = New-Object System.Collections.Generic.List[object]
    foreach ($f in (Get-ChildItem -LiteralPath $CorpusDir -Filter '*.txt' -File | Sort-Object Name)) {
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
        $aud = $null
        if ($map.ContainsKey($stem)) { $aud = $map[$stem] }
        if (-not $aud) { $aud = if ($f.Name -match $AssessorRx) { 'assessor' } else { 'learner' } }
        if ($aud -notmatch '^(learner|assessor)$') { $aud = 'learner' }
        $docs.Add([pscustomobject]@{
            Name     = $stem
            Path     = $f.FullName
            Audience = $aud
            Text     = (Get-GateFileText -Path $f.FullName)
        })
    }

    return [pscustomobject]@{
        Dir              = $CorpusDir
        Documents        = $docs.ToArray()
        Learner          = @($docs | Where-Object { $_.Audience -eq 'learner' })
        Assessor         = @($docs | Where-Object { $_.Audience -eq 'assessor' })
        ClassifiedFrom   = $src
    }
}

# ---------------------------------------------------------------------------
# Text
# ---------------------------------------------------------------------------

function ConvertTo-GateNormal {
    <#  One normalisation for every gate: lower case, curly quotes folded,
        everything but letters, digits and single spaces removed.

        Structural matching on normalised labels rather than on wording is the
        point - handing an assessed grid over in the author's own words is the
        same leak as handing it over verbatim, and a wording-sensitive sweep
        cannot see it.  #>
    [CmdletBinding()]
    param([string] $Text)

    if ($null -eq $Text) { return '' }
    #  Curly quotes and the dash family are written as \u escapes, not as the
    #  characters themselves: this file is ASCII, and PS 5.1 decodes a BOM-less
    #  .ps1 as ANSI, which would silently corrupt any literal it carried.
    $t = "$Text".ToLowerInvariant()
    $t = $t -replace '[\u2018\u2019\u02BC]', "'"
    $t = $t -replace '[\u201C\u201D]', '"'
    $t = $t -replace '[\u2010-\u2015]', '-'
    $t = $t -replace '[^a-z0-9 ]', ' '
    $t = $t -replace '\s+', ' '
    return $t.Trim()
}

function Get-GateBlankTokens {
    <#  The vocabulary a learner-facing tool uses to say "you write here".

        DERIVED where the build declares it (contract assessment.blankTokens,
        which Stage 1's typed parse fills from the tools themselves), with the
        common house forms as the documented fallback.  #>
    [CmdletBinding()]
    param([string] $BuildDir)

    $defaults = @(
        'write here', 'write your answer here', 'your turn', 'you write this',
        'your answer', 'answer here', 'type here', 'insert here', 'student response',
        'learner response', 'to be completed', 'complete this', 'fill this in', 'n a', 'tbc'
    )
    if (-not $BuildDir) { return $defaults }
    $c = Get-GateContract -BuildDir $BuildDir
    if ($null -eq $c) { return $defaults }
    $declared = @()
    if (@($c.PSObject.Properties.Name) -contains 'assessment') {
        $declared = @(Get-GateProp -Object $c.assessment -Names @('blankTokens', 'blankAnswerTokens', 'unfilledTokens') -Default @())
    }
    if ($declared.Count -eq 0) { return $defaults }
    return @($declared + $defaults | ForEach-Object { (ConvertTo-GateNormal $_) } | Where-Object { $_ } | Select-Object -Unique)
}

function Test-GateCellFilled {
    <#  Is this cell ANSWERED, or is it the tool's own "you write here"?

        THIS REPLACES A CHARACTER-COUNT HEURISTIC AND THAT IS THE WHOLE FIX.
        The shipped mirror gate called a cell unfilled when it held 20
        characters or fewer, so "75 degrees C", "2 hours", "Yes" and "4 degrees
        C by 4 hours" - the exact values an assessed grid asks a learner to
        supply, and the exact values worth copying - all read as blank and the
        row was scored as withheld. BREVITY MUST NEVER BE MISTAKEN FOR ABSENCE.

        The test is now non-empty against an EXPLICIT unfilled vocabulary:
        strip the tool's own blank tokens and every rule, dot leader and dash,
        and if anything a learner could copy survives, the cell is filled.  #>
    [CmdletBinding()]
    param(
        [string] $Text,
        [string[]] $BlankTokens
    )

    if ($null -eq $Text) { return $false }
    $n = ConvertTo-GateNormal $Text
    if (-not $n) { return $false }
    foreach ($b in @($BlankTokens)) {
        $bn = ConvertTo-GateNormal $b
        if ($bn) { $n = $n.Replace($bn, ' ') }
    }
    $n = ($n -replace '\s+', ' ').Trim()
    return ($n -match '[a-z0-9]')
}

# ---------------------------------------------------------------------------
# The spine
# ---------------------------------------------------------------------------

function Get-GateUnrenderedFields {
    <#  Fields that are deliberately NOT put on the page, each with its reason.

        Declared, versioned and printed - never inferred. A field the build
        withholds on purpose and a field the build loses by accident look
        identical to a walker, and only a written reason separates them.

        Extend per build in contract.json:
          "spineContract": { "unrenderedFields": [ { "field": "...", "reason": "..." } ] }

        Pass -ForSweep for the narrower list a TEXT SWEEP may skip; see the note
        at the foot of this function, which is the difference between a field no
        renderer reads and a field no reader can ever see.  #>
    [CmdletBinding()]
    param(
        [string] $BuildDir,
        [switch] $ForSweep
    )

    $out = [ordered]@{
        'provenance'    = 'build metadata - which source each claim came from. Carried for the audit, not for the learner.'
        'openQuestions' = 'build metadata - unresolved questions for the author, never rendered.'
        'ref'           = 'structural identifier for the sub-section.'
        'pc'            = 'structural identifier - the performance criterion this sub-section maps to.'
        'topic'         = 'structural identifier - the topic number.'
        'number'        = 'structural identifier.'
        'element'       = 'structural identifier - the unit element.'
        'elementText'   = 'structural identifier - the element wording, used for mapping not for prose.'
        'slot'          = 'structural identifier - the figure slot artwork is keyed by.'
        'kind'          = 'structural - which renderer draws this visual.'
        'aspect'        = 'structural - the generation aspect ratio.'
        'layout'        = 'structural - which layout a slide or spec uses.'
        'tag'           = 'structural.'
        'fit'           = 'structural - placement sizing.'
        'figureSlot'    = 'structural - the slot a cross-reference points at.'
        'headerRow'     = 'structural flag on a table spec - whether row one is a header.'
        'spec'          = 'the visual specification. Consumed BY SLOT by the artwork sub-skill at placement, not by the document renderer, so a renderer that never names it is behaving correctly. Its rows are still swept by the mirror and leakage gates, which read the spine directly.'
        'answerGuide'   = 'DELIBERATELY WITHHELD, and the reason is recorded here so a later reader does not helpfully render it back in. Where the assessment is open book and expressly permits this guide, printing a self-check answer key puts a marking guide on the learner desk during the assessment. The topic points at the teaching instead.'
    }

    if ($BuildDir) {
        $c = Get-GateContract -BuildDir $BuildDir
        if ($null -ne $c -and @($c.PSObject.Properties.Name) -contains 'spineContract') {
            foreach ($e in @(Get-GateProp -Object $c.spineContract -Names @('unrenderedFields') -Default @())) {
                $f = Get-GateProp -Object $e -Names @('field', 'name')
                $r = Get-GateProp -Object $e -Names @('reason', 'why')
                if (-not $f) { continue }
                if (-not $r -or "$r".Trim().Length -lt 20) {
                    throw ("contract.json spineContract.unrenderedFields: '{0}' carries no written reason. A field declared unrendered without a reason is indistinguishable from content the build lost." -f $f)
                }
                $out["$f"] = "$r"
            }
        }
    }

    #  -ForSweep NARROWS THIS LIST TO WHAT A TEXT SWEEP MAY SKIP, and the two
    #  questions are not the same one. "Does the document renderer read this
    #  field" decides whether authored content is lost. "Can a reader ever see
    #  this text" decides whether a leakage or terminology sweep may pass over
    #  it. A visual spec is read by no document renderer and is still printed on
    #  the page by the artwork pass; skipping it in a leakage sweep would blind
    #  the sweep to the exact channel it was written for. So a sweep skips only
    #  identifiers and build metadata - never anything that carries prose.
    if ($ForSweep) {
        $safe = @('provenance', 'openQuestions', 'ref', 'pc', 'topic', 'number', 'element',
                  'elementText', 'slot', 'kind', 'aspect', 'layout', 'tag', 'fit',
                  'figureSlot', 'headerRow')
        $narrow = [ordered]@{}
        foreach ($k in $out.Keys) { if ($safe -contains $k) { $narrow[$k] = $out[$k] } }
        return $narrow
    }
    return $out
}

function Get-GateSpineFiles {
    <# The authored sub-section files. Front matter and cover are structural.
       A sub-section's own gate result (<file>.gate.json, written beside it by
       Test-SubSection) is NOT a spine file. Matching *.json alone fed those
       results back into every whole-spine gate: Test-SpineRead exited 13 on one
       (every field UNREAD), the leakage sweep read it as a channel, and
       Test-Spine warned it as a stranger. Sidecars are excluded by suffix. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [string] $SpineDir,
        [string] $Filter = '*.json',
        [string[]] $Exclude = @('front.json', 'cover.json', 'deckframe.json')
    )

    if (-not $SpineDir) { $SpineDir = Join-Path $BuildDir 'spine' }
    if (-not (Test-Path -LiteralPath $SpineDir)) {
        throw ("No spine at {0}. These gates read the SPINE, not the rendered document: the content they check is machine-readable JSON hours before a picture exists, and every one of them was written after a defect was found four hours late in a .docx." -f $SpineDir)
    }
    return @(Get-ChildItem -LiteralPath $SpineDir -Filter $Filter -File |
             Where-Object { $Exclude -notcontains $_.Name } |
             Where-Object { $_.Name -notmatch '\.gate\.json$' -and $_.Name -notmatch '\.result\.json$' } |
             Sort-Object Name)
}

function Get-SpineFingerprint {
    <#  One hash over the WHOLE spine, so a derived artefact can prove it still
        describes the spine it was generated from.

        WHY A HASH AND NOT A TIMESTAMP. The figure sheet is generated once at
        Stage 3d and then travels with every later review pack, and it is what
        makes a review record count as having read the figures. Stage 7 edits
        the spine. A sheet nobody regenerated then hands every downstream
        reviewer figure content the document no longer has - while the ledger
        records that the figures were read. An mtime comparison catches the
        common case and is defeated by any copy, so the sheet carries the
        fingerprint of the spine it was cut from and the check recomputes it.

        Deterministic: file name plus content hash, in name order. Content only -
        nothing here reads a timestamp, so re-saving an unchanged spine does not
        invalidate a sheet that is still correct.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [string] $SpineDir
    )

    if (-not $SpineDir) { $SpineDir = Join-Path $BuildDir 'spine' }
    if (-not (Test-Path -LiteralPath $SpineDir)) { return '' }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $parts = New-Object System.Collections.Generic.List[string]
        foreach ($f in (Get-ChildItem -LiteralPath $SpineDir -Filter '*.json' -File | Sort-Object Name)) {
            $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
            $parts.Add(("{0}:{1}" -f $f.Name, [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '')))
        }
        if (-not $parts.Count) { return '' }
        $all = [System.Text.Encoding]::UTF8.GetBytes(($parts -join "`n"))
        return [BitConverter]::ToString($sha.ComputeHash($all)).Replace('-', '').Substring(0, 32).ToLower()
    }
    finally { $sha.Dispose() }
}

function Get-GateSpineCells {
    <#  EVERY string the spine will put in front of a reader, with its anchor.

        Walks the whole tree and reports File, Path, Channel and Slot for each
        string, so a finding is a work order and not an observation. The channel
        is the top-level field the string hangs under - body prose, worked
        example, role play, self check, visuals, slides - because a defect class
        has to be swept over EVERY channel of BOTH artefacts, and a remediation
        that lands on the figures and misses the tables, the chips and the
        closing notes is the shape of an entire wasted round.  #>
    [CmdletBinding()]
    param(
        $Node,
        [string] $File = '',
        [string] $Path = '',
        [string] $Channel = '',
        [string] $Slot = '',
        [hashtable] $Skip = $null,
        [int] $Depth = 0
    )

    if ($null -eq $Node -or $Depth -gt 24) { return }

    if ($Node -is [string]) {
        if ("$Node".Trim()) {
            [pscustomobject]@{ File = $File; Path = $Path; Channel = $Channel; Slot = $Slot; Text = [string]$Node }
        }
        return
    }
    if ($Node -is [ValueType]) { return }

    if ($Node -is [System.Collections.IEnumerable]) {
        $i = 0
        foreach ($item in $Node) {
            Get-GateSpineCells -Node $item -File $File -Path ("{0}[{1}]" -f $Path, $i) -Channel $Channel -Slot $Slot -Skip $Skip -Depth ($Depth + 1)
            $i++
        }
        return
    }

    $props = @($Node.PSObject.Properties.Name)
    if (-not $props) { return }

    $mySlot = $Slot
    if ($props -contains 'slot' -and $Node.slot) { $mySlot = [string]$Node.slot }

    foreach ($p in $props) {
        if ($p -like '_*') { continue }
        if ($null -ne $Skip -and $Skip.ContainsKey($p)) { continue }
        $childPath = if ($Path) { "$Path.$p" } else { $p }
        $childChan = if ($Channel) { $Channel } else { $p }
        Get-GateSpineCells -Node $Node.$p -File $File -Path $childPath -Channel $childChan -Slot $mySlot -Skip $Skip -Depth ($Depth + 1)
    }
}

function Get-GateSpineTables {
    <#  EVERY table anywhere on the spine, whatever the property is called.

        WHY IT WALKS THE WHOLE TREE, WHICH IS THE WHOLE POINT. The first mirror
        gate scanned only the captioned figures' spec.rows. A remediation round
        withheld rows in exactly those, the gate went green, and the next audit
        found the same grids printed in full a hundred lines earlier in the same
        sub-sections, inside a worked example and a practical activity. The leak
        had been moved, not removed, and the gate could not see it because it
        was looking at one property name instead of at the document.

        So a TABLE is anything with rows of cells, wherever it lives and
        whatever it is called - and a structure nobody has invented yet is
        still caught. Node- and item-shaped specs are folded in as tables too:
        a flow node labelled "Bench 1: 21 degrees C" is a filled answer row
        with an arrow drawn round it.  #>
    [CmdletBinding()]
    param(
        $Node,
        [string] $File = '',
        [string] $Path = '',
        [string] $Slot = '',
        [int] $Depth = 0
    )

    if ($null -eq $Node -or $Depth -gt 24) { return }
    if ($Node -is [string] -or $Node -is [ValueType]) { return }

    if ($Node -is [System.Collections.IEnumerable]) {
        $i = 0
        foreach ($item in $Node) {
            Get-GateSpineTables -Node $item -File $File -Path ("{0}[{1}]" -f $Path, $i) -Slot $Slot -Depth ($Depth + 1)
            $i++
        }
        return
    }

    $props = @($Node.PSObject.Properties.Name)
    if (-not $props) { return }

    $mySlot = $Slot
    if ($props -contains 'slot' -and $Node.slot) { $mySlot = [string]$Node.slot }
    elseif ($props -contains 'caption' -and $Node.caption -and ([string]$Node.caption) -match 'Figure\s+(\d+(?:\.\d+)+)') { $mySlot = $Matches[1] }

    # rows of cells - a table however it is named
    if ($props -contains 'rows' -and $Node.rows) {
        $rows = @($Node.rows)
        $isTable = $rows.Count -gt 0 -and ($rows[0] -is [System.Collections.IEnumerable]) -and ($rows[0] -isnot [string])
        if ($isTable) {
            $headers = @()
            $skip = 0
            if ($props -contains 'headers' -and $Node.headers) { $headers = @($Node.headers) }
            if ($headers.Count -eq 0 -and $props -contains 'headerRow' -and $Node.headerRow) { $skip = 1; $headers = @($rows[0]) }
            [pscustomobject]@{
                File = $File; Path = $Path; Slot = $mySlot; Shape = 'rows'
                Rows = $rows; Skip = $skip; Headers = $headers
            }
        }
    }

    # nodes and items - a one-column list, split on its own label/value separator
    foreach ($listName in @('nodes', 'items', 'steps', 'bullets')) {
        if ($props -notcontains $listName -or -not $Node.$listName) { continue }
        $flat = New-Object System.Collections.Generic.List[object]
        foreach ($n in @($Node.$listName)) {
            $s = ''
            if ($n -is [string]) { $s = $n }
            elseif ($null -ne $n -and $n.PSObject) {
                $lab = Get-GateProp -Object $n -Names @('label', 'text', 'title', 'name')
                $val = Get-GateProp -Object $n -Names @('value', 'detail', 'note', 'then')
                $s = if ($val) { "{0}: {1}" -f $lab, $val } else { [string]$lab }
            }
            if (-not "$s".Trim()) { continue }
            $m = [regex]::Match("$s", '^(.{2,70}?)\s*[:\u2013\u2014-]\s+(.+)$')
            if ($m.Success) { $flat.Add(@($m.Groups[1].Value, $m.Groups[2].Value)) }
            else { $flat.Add(@("$s")) }
        }
        if ($flat.Count -gt 0) {
            [pscustomobject]@{
                File = $File; Path = ("{0}.{1}" -f $Path, $listName); Slot = $mySlot; Shape = $listName
                Rows = $flat.ToArray(); Skip = 0; Headers = @()
            }
        }
    }

    foreach ($p in $props) {
        if ($p -like '_*') { continue }
        if ($p -eq 'rows') { continue }
        $childPath = if ($Path) { "$Path.$p" } else { $p }
        Get-GateSpineTables -Node $Node.$p -File $File -Path $childPath -Slot $mySlot -Depth ($Depth + 1)
    }
}

function Get-GateSpineVisuals {
    <# Every planned visual on the spine, with its slot, caption, alt and spec. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [string] $SpineDir
    )

    $out = New-Object System.Collections.Generic.List[object]
    foreach ($f in (Get-GateSpineFiles -BuildDir $BuildDir -SpineDir $SpineDir)) {
        $j = Get-GateJson -Path $f.FullName
        if ($null -eq $j) { continue }
        if (@($j.PSObject.Properties.Name) -notcontains 'visuals') { continue }
        foreach ($v in @($j.visuals)) {
            if ($null -eq $v) { continue }
            $out.Add([pscustomobject]@{
                File    = $f.Name
                Slot    = [string](Get-GateProp -Object $v -Names @('slot', 'figure', 'number'))
                Kind    = [string](Get-GateProp -Object $v -Names @('kind', 'type'))
                Caption = [string](Get-GateProp -Object $v -Names @('caption'))
                Alt     = [string](Get-GateProp -Object $v -Names @('alt', 'altText'))
                Prompt  = [string](Get-GateProp -Object $v -Names @('prompt'))
                Spec    = (Get-GateProp -Object $v -Names @('spec'))
                Node    = $v
            })
        }
    }
    return $out.ToArray()
}

function Write-GateCheckSet {
    <#  Every gate says how big its check-set is and where it was derived from.

        A gate that checks a hand-picked subset of what it claims to check is
        worse than no gate, because it is believed: one sweep hand-listed three
        of nine palette hexes and printed "no crossover" over 766 live
        occurrences of the ones it had never been told about.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $What,
        [Parameter(Mandatory)][int] $Count,
        [Parameter(Mandatory)][string] $DerivedFrom
    )
    Write-Host ("  check-set: {0} {1}, derived from {2}" -f $Count, $What, $DerivedFrom) -ForegroundColor DarkGray
}
