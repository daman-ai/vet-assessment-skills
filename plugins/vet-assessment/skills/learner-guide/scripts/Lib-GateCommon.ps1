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

    NOTHING IN THIS FILE DECIDES ANYTHING ABOUT CONTENT. It locates, parses,
    normalises and enumerates. Every verdict on what a document says belongs
    to the gate that calls it, so that a gate can be read on its own and its
    failure condition understood without reading this file.

    IT DOES REFUSE, BY NAME, ON ABSENCE. Six gates once exited 0 with a
    blocking arm that had examined nothing, because an empty check-set printed
    the same green line as a full one. So the two refusals every gate shares
    live here and are typed: Write-GateCheckSet -Blocking throws CHECK-SET
    EMPTY naming the input that yielded nothing, and Assert-GateArmsComplete
    throws naming any blocking arm that was declared and never finished. A
    gate's top-level catch maps either to exit 2. Nothing here can weaken a
    check; everything here can only make an absent input loud.

    SELF-TEST:  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Lib-GateCommon.ps1 -SelfTest
    Dot-sourcing never runs it (see the parameter note below).

    PS 5.1. ASCII only in this file.
#>

param(
    #  The library's own self-test switch. It is NAMED GateCommonSelfTest and
    #  reached as -SelfTest through the alias, and the difference is not
    #  cosmetic: a dot-sourced script binds its parameters as variables in the
    #  CALLER's scope, so a parameter called $SelfTest here would set every
    #  gate's own -SelfTest switch to $false the moment the gate dot-sourced
    #  this file (verified on PS 5.1: True became False). The alias keeps the
    #  documented command line; the odd name keeps every caller's variables.
    [Alias('SelfTest')]
    [switch] $GateCommonSelfTest
)

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
        #  Abbreviations matter as much as words here. A corpus extracted as
        #  out_AG.txt / staging_AG.txt classified as LEARNER-FACING under the
        #  word-only pattern, so any gate trusting this would have swept an
        #  assessor guide as a learner document - the leak direction. AG, MG
        #  and AS are the abbreviations these packs actually use, matched only
        #  as whole tokens so a learner file named "storage" is untouched.
        [string] $AssessorRx = '(?i)((^|[^a-z])(assessor|marker|benchmark)|marking[_ -]?guide|model[_ -]?answer|answer[_ -]?key|(^|[_\-. ])(ag|mg|as)([_\-. ]|$))'
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
        #  An audience value the manifest supplies but this code does not
        #  recognise is UNKNOWN, and unknown is treated as assessor. Defaulting
        #  an unrecognised value to learner is the same fail-open as above: it
        #  puts unclassified text into every learner-facing sweep.
        if ($aud -notmatch '^(learner|assessor)$') {
            Write-Host ('  ! Get-GateCorpusDocs: {0} declares audience ''{1}'', which is neither learner nor assessor. Treating it as ASSESSOR.' -f $f.Name, $aud) -ForegroundColor Yellow
            $aud = 'assessor'
        }
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
       Test-Spine warned it as a stranger. Sidecars (*.gate.json, *.result.json)
       are ALWAYS excluded, by suffix, whatever -Exclude says.

       -IncludeFrontMatter lifts the DEFAULT exclusion of front.json, cover.json
       and deckframe.json. An -Exclude the caller passes explicitly is honoured
       as given, so -IncludeFrontMatter -Exclude @('cover.json') means "front
       matter in, except the cover", and -IncludeFrontMatter -Exclude @() means
       "every authored file". #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [string] $SpineDir,
        [string] $Filter = '*.json',
        [string[]] $Exclude = @('front.json', 'cover.json', 'deckframe.json'),
        [switch] $IncludeFrontMatter
    )

    if (-not $SpineDir) { $SpineDir = Join-Path $BuildDir 'spine' }
    if (-not (Test-Path -LiteralPath $SpineDir)) {
        throw ("No spine at {0}. These gates read the SPINE, not the rendered document: the content they check is machine-readable JSON hours before a picture exists, and every one of them was written after a defect was found four hours late in a .docx." -f $SpineDir)
    }
    $effective = @($Exclude | Where-Object { $null -ne $_ -and "$_" -ne '' })
    if ($IncludeFrontMatter -and -not $PSBoundParameters.ContainsKey('Exclude')) {
        $frontMatter = @('front.json', 'cover.json', 'deckframe.json')
        $effective = @($effective | Where-Object { $frontMatter -notcontains $_ })
    }
    return @(Get-ChildItem -LiteralPath $SpineDir -Filter $Filter -File |
             Where-Object { $effective -notcontains $_.Name } |
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
        invalidate a sheet that is still correct.

        VERSION 2, AND WHY THE SET CHANGED. v1 hashed every *.json in the spine
        directory: a gate's own <file>.gate.json sidecar, written in the loop,
        moved the fingerprint and made every current figure sheet look stale;
        and cover.json, front.json and deckframe.json, which the renderer reads,
        were in the hash only by accident of the glob. v2 hashes exactly the
        gate spine set - Get-GateSpineFiles -IncludeFrontMatter -Exclude @() -
        so front matter, cover and deck frame are in and sidecars are out, and
        every band member enumerates the same files it hashes. The value is
        prefixed 'v2:' so a comparer can tell "the fingerprint format changed,
        re-cut" from "the spine moved" (Test-GateFingerprintVersion). The file
        count is printed so every member of a band can be seen to hash the
        same set.

        Returns '' when there is no spine directory or no file to hash.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [string] $SpineDir,
        [switch] $Quiet
    )

    if (-not $SpineDir) { $SpineDir = Join-Path $BuildDir 'spine' }
    if (-not (Test-Path -LiteralPath $SpineDir)) { return '' }

    $files = @(Get-GateSpineFiles -BuildDir $BuildDir -SpineDir $SpineDir -IncludeFrontMatter -Exclude @())
    if (-not $Quiet) {
        Write-Host ("  spine fingerprint v2: {0} file(s) hashed from {1} (front matter in; *.gate.json and *.result.json sidecars out)" -f $files.Count, $SpineDir) -ForegroundColor DarkGray
    }
    if ($files.Count -eq 0) { return '' }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $parts = New-Object System.Collections.Generic.List[string]
        foreach ($f in $files) {
            $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
            $parts.Add(("{0}:{1}" -f $f.Name, [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '')))
        }
        $all = [System.Text.Encoding]::UTF8.GetBytes(($parts -join "`n"))
        return ('v2:' + [BitConverter]::ToString($sha.ComputeHash($all)).Replace('-', '').Substring(0, 32).ToLower())
    }
    finally { $sha.Dispose() }
}

function Test-GateFingerprintVersion {
    <#  Compare a STAMPED fingerprint with the CURRENT one and say which of three
        things is true, because two of them used to look identical:

          match            same version, same hash - the artefact is current
          spine-moved      same version, different hash - the spine was edited
          version-changed  the fingerprint format differs (a bare v1 hex against
                           a 'v2:' value, or v2 against a later vN) - the
                           artefact must be re-cut, and NOTHING can be said
                           about whether the spine moved

        An unprefixed value is v1. Whitespace is trimmed and the hash compared
        case-insensitively. An EMPTY -Stamp or -Current throws naming which one:
        a comparer handed nothing cannot answer 'match', and returning
        'spine-moved' for a missing stamp would hide the missing stamp.  #>
    [CmdletBinding()]
    param(
        [AllowNull()][AllowEmptyString()][string] $Stamp,
        [AllowNull()][AllowEmptyString()][string] $Current
    )

    $s = "$Stamp".Trim()
    $c = "$Current".Trim()
    if (-not $s) { throw (New-Object System.ArgumentException ('Test-GateFingerprintVersion: -Stamp is empty. The artefact carries no fingerprint, so nothing can say whether it is current; that is a refusal to be named by the caller, not a comparison.')) }
    if (-not $c) { throw (New-Object System.ArgumentException ('Test-GateFingerprintVersion: -Current is empty. Get-SpineFingerprint returns an empty string when there is no spine directory or no spine file; name that, do not compare it.')) }

    $sv = 'v1'; $sh = $s
    if ($s -match '^v(\d+):(.*)$') { $sv = 'v' + $Matches[1]; $sh = $Matches[2] }
    $cv = 'v1'; $ch = $c
    if ($c -match '^v(\d+):(.*)$') { $cv = 'v' + $Matches[1]; $ch = $Matches[2] }

    if ($sv -ne $cv) { return 'version-changed' }
    if ($sh.ToLowerInvariant() -eq $ch.ToLowerInvariant()) { return 'match' }
    return 'spine-moved'
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
    <#  Every planned visual on the spine, with its slot, caption, alt and spec.

        A file's top-level 'visuals' list is walked, AND a singular top-level
        'visual' node is folded in as a one-element list. cover.json plans the
        guide's first image under the singular name, and because every visuals
        gate read only the plural, the cover was gated by nobody. Source says
        which shape each entry came from.

        The default file set is the sub-sections. Pass -IncludeFrontMatter to
        see the cover (and -Exclude to narrow it, passed straight through).  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [string] $SpineDir,
        [switch] $IncludeFrontMatter,
        [string[]] $Exclude
    )

    $fileArgs = @{ BuildDir = $BuildDir; SpineDir = $SpineDir; IncludeFrontMatter = $IncludeFrontMatter }
    if ($PSBoundParameters.ContainsKey('Exclude')) { $fileArgs['Exclude'] = @($Exclude) }

    $out = New-Object System.Collections.Generic.List[object]
    foreach ($f in (Get-GateSpineFiles @fileArgs)) {
        $j = Get-GateJson -Path $f.FullName
        if ($null -eq $j) { continue }
        $props = @($j.PSObject.Properties.Name)
        $nodes = New-Object System.Collections.Generic.List[object]
        if ($props -contains 'visuals') {
            foreach ($v in @($j.visuals)) { if ($null -ne $v) { $nodes.Add(@{ Node = $v; Source = 'visuals' }) } }
        }
        if ($props -contains 'visual') {
            foreach ($v in @($j.visual)) { if ($null -ne $v) { $nodes.Add(@{ Node = $v; Source = 'visual' }) } }
        }
        foreach ($entry in $nodes) {
            $v = $entry.Node
            $out.Add([pscustomobject]@{
                File    = $f.Name
                Slot    = [string](Get-GateProp -Object $v -Names @('slot', 'figure', 'number'))
                Kind    = [string](Get-GateProp -Object $v -Names @('kind', 'type'))
                Caption = [string](Get-GateProp -Object $v -Names @('caption'))
                Alt     = [string](Get-GateProp -Object $v -Names @('alt', 'altText'))
                Prompt  = [string](Get-GateProp -Object $v -Names @('prompt'))
                Spec    = (Get-GateProp -Object $v -Names @('spec'))
                Source  = [string]$entry.Source
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
        occurrences of the ones it had never been told about.

        -Blocking: THE CHECK-SET MAY NOT BE EMPTY. With -Count 0 this throws a
        [System.InvalidOperationException] whose message begins 'CHECK-SET
        EMPTY: ' and names -Input, the thing that yielded nothing. Six gates
        once printed a green line over an arm that had examined nothing; the
        gate's top-level catch maps this refusal to exit 2, which is the only
        honest exit for a blocking rule with an absent input. An advisory arm
        with an empty set prints EMPTY in yellow and continues.

        -Input names the input the set was cut from (a file, a contract key, a
        parameter) so the refusal is a work order. The parameter is reached as
        -Input through an alias: $Input is a PowerShell automatic variable and
        a parameter of that name never binds.

        -Excluded prints the excluded names beside the count, so a reader can
        see what a gate chose not to sweep without opening the gate.

        The line keeps the shape 'check-set: <count> <what>' at its front:
        Test-SubSection parses it by that shape.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $What,
        [Parameter(Mandatory)][int] $Count,
        [Parameter(Mandatory)][string] $DerivedFrom,
        [switch] $Blocking,
        [Alias('Input')][string] $InputName,
        [string[]] $Excluded
    )

    if ($Count -lt 0) {
        throw (New-Object System.ArgumentException (("Write-GateCheckSet: -Count {0} for '{1}' is negative. A check-set size is a count of things examined." -f $Count, $What)))
    }
    $tail = ''
    if ($InputName) { $tail += (' [input: {0}]' -f $InputName) }
    if ($PSBoundParameters.ContainsKey('Excluded')) {
        $ex = @($Excluded | Where-Object { $null -ne $_ -and "$_" -ne '' })
        if ($ex.Count -gt 0) { $tail += ('; excluded {0}: {1}' -f $ex.Count, ($ex -join ', ')) }
        else { $tail += '; excluded: none' }
    }
    if ($Blocking) { $tail += ' [blocking]' }

    if ($Count -eq 0) {
        if ($Blocking) {
            Write-Host ("  check-set: 0 {0}, derived from {1}{2} - EMPTY" -f $What, $DerivedFrom, $tail) -ForegroundColor Red
            $named = if ($InputName) { $InputName } else { ("the input for '{0}' (no -Input was named; derived from {1})" -f $What, $DerivedFrom) }
            throw (New-Object System.InvalidOperationException (("CHECK-SET EMPTY: {0} yielded nothing - the blocking check-set '{1}' has 0 members, derived from {2}{3}. A blocking rule with an absent input cannot pass. Supply the input, or declare the arm not applicable in contract.json gateArms.<gate>.<arm> with a written reason. Exit 2." -f $named, $What, $DerivedFrom, $tail)))
        }
        Write-Host ("  check-set: 0 {0}, derived from {1}{2} - EMPTY (advisory arm: nothing was examined)" -f $What, $DerivedFrom, $tail) -ForegroundColor Yellow
        return
    }
    Write-Host ("  check-set: {0} {1}, derived from {2}{3}" -f $Count, $What, $DerivedFrom, $tail) -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# The arm roster
#
# A gate is a set of ARMS - one per rule it enforces. Every arm a gate declares
# must END in one of three states, and the roster is how a runner can tell:
#
#   ran            it examined N > 0 things (Size) and found F things (Findings)
#   empty          its check-set was empty - a refusal, exit 2, never a pass
#   declared-n-a   contract.json says it does not apply here, with a reason
#
# An arm that is registered and never completed is 'not-run'. A blocking arm
# left not-run is a gate that skipped one of its own rules, and until this
# roster existed nothing consumed an arm's ran flag: the gate exited 0 and the
# runner recorded PASS. Write-GateArmRoster prints ONE line both runners parse:
#
#   ARMS: name|blocking|state|size|findings;name|blocking|state|size|findings
#
# (blocking is true/false; 'ARMS: none' when nothing was registered). The
# roster is kept in the calling gate's script scope, created on first use, so
# a gate that dot-sources this library twice does not lose it.
# ---------------------------------------------------------------------------

function Get-GateArmStore {
    <# The roster list for the calling script, created on first touch. Private. #>
    [CmdletBinding()]
    param()
    $v = Get-Variable -Name GateArmRoster -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $v -or $null -eq $v.Value) {
        Set-Variable -Name GateArmRoster -Scope Script -Value (New-Object System.Collections.Generic.List[object])
        $v = Get-Variable -Name GateArmRoster -Scope Script
    }
    #  The comma is load-bearing: a List returned bare is ENUMERATED on the way
    #  out, so an empty roster came back as $null and a full one as a fixed
    #  array with no Add. Wrapping it returns the List itself.
    return , $v.Value
}

function Reset-GateArmRoster {
    <# Empty the roster. For self-tests and runners that drive a gate more than once in one process. #>
    [CmdletBinding()]
    param()
    Set-Variable -Name GateArmRoster -Scope Script -Value (New-Object System.Collections.Generic.List[object])
}

function Register-GateArm {
    <#  Declare an arm before it runs. -Blocking says a refusal or an unrun arm
        fails the gate. Names may not contain '|' or ';' (the roster line's
        separators). Registering a name twice throws: a gate that declares the
        same arm twice is a gate whose second result would hide its first.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Name,
        [switch] $Blocking
    )
    if (-not $Name.Trim() -or $Name -match '[|;]') {
        throw (New-Object System.ArgumentException (("Register-GateArm: '{0}' is not a usable arm name - it must be non-empty and contain neither '|' nor ';', which separate the roster line." -f $Name)))
    }
    $store = Get-GateArmStore
    foreach ($a in $store) {
        if ($a.Name -eq $Name) {
            throw (New-Object System.InvalidOperationException (("Register-GateArm: arm '{0}' is already registered ({1}). Declare each arm once; a second declaration would let a second result hide the first." -f $Name, $a.State)))
        }
    }
    $store.Add([pscustomobject]@{
        Name         = $Name
        Blocking     = [bool]$Blocking
        State        = 'not-run'
        Size         = 0
        Findings     = 0
        Reason       = ''
        RegisteredUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        CompletedUtc = ''
    })
}

function Complete-GateArm {
    <#  Record how a registered arm ended.

          ran           requires -Size >= 1. 'ran' with a size of 0 is an empty
                        check-set wearing a pass; complete it as 'empty' instead.
          empty         the check-set was empty; -Size must be 0. This is a
                        refusal - Write-GateCheckSet -Blocking has usually
                        already thrown, and the gate records it on the way to
                        exit 2.
          declared-n-a  contract.json gateArms says the arm does not apply;
                        -Reason (the contract's, via Get-GateDeclaredNa) must be
                        at least 20 characters, the same bar an allow-list
                        reason has to clear.

        Completing an unregistered arm throws naming the registered set;
        completing an arm twice throws.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][ValidateSet('ran', 'empty', 'declared-n-a')][string] $State,
        [int] $Size = 0,
        [int] $Findings = 0,
        [string] $Reason = ''
    )
    $store = Get-GateArmStore
    $arm = $null
    foreach ($a in $store) { if ($a.Name -eq $Name) { $arm = $a; break } }
    if ($null -eq $arm) {
        $known = @($store | ForEach-Object { $_.Name })
        $knownText = if ($known.Count -gt 0) { ($known -join ', ') } else { '(none)' }
        throw (New-Object System.InvalidOperationException (("Complete-GateArm: arm '{0}' was never registered. Registered arms: {1}. Register-GateArm before the arm runs, so an arm that never ran can be seen." -f $Name, $knownText)))
    }
    if ($arm.State -ne 'not-run') {
        throw (New-Object System.InvalidOperationException (("Complete-GateArm: arm '{0}' already completed as '{1}'. An arm ends once." -f $Name, $arm.State)))
    }
    if ($State -eq 'ran' -and $Size -lt 1) {
        throw (New-Object System.InvalidOperationException (("CHECK-SET EMPTY: arm '{0}' reports 'ran' with a size of {1}. An arm that examined nothing did not run - complete it as 'empty' (a refusal) or 'declared-n-a' with the contract's reason." -f $Name, $Size)))
    }
    if ($State -eq 'empty' -and $Size -ne 0) {
        throw (New-Object System.ArgumentException (("Complete-GateArm: arm '{0}' reports 'empty' with a size of {1}. Empty means nothing was examined." -f $Name, $Size)))
    }
    if ($State -eq 'declared-n-a' -and "$Reason".Trim().Length -lt 20) {
        throw (New-Object System.InvalidOperationException (("Complete-GateArm: arm '{0}' is declared not applicable with no written reason (or one too short to be one). Read it from contract.json gateArms via Get-GateDeclaredNa; an arm switched off without a reason is a gate switched off." -f $Name)))
    }
    if ($Findings -lt 0) {
        throw (New-Object System.ArgumentException (("Complete-GateArm: arm '{0}' reports {1} findings; a finding count is not negative." -f $Name, $Findings)))
    }
    $arm.State        = $State
    $arm.Size         = $Size
    $arm.Findings     = $Findings
    $arm.Reason       = "$Reason"
    $arm.CompletedUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
}

function Get-GateArmRoster {
    <# The roster objects (Name, Blocking, State, Size, Findings, Reason, RegisteredUtc, CompletedUtc), in registration order. Wrap in @(). #>
    [CmdletBinding()]
    param()
    return (Get-GateArmStore).ToArray()
}

function Write-GateArmRoster {
    <#  Print the ONE line the runners parse and return the roster for the
        gate's report JSON (lower-case keys). Capture the return value -
        $roster = Write-GateArmRoster - or it lands in the gate's output
        stream as text. Prints 'ARMS: none' when nothing was registered.  #>
    [CmdletBinding()]
    param()
    $store = Get-GateArmStore
    $cells = New-Object System.Collections.Generic.List[string]
    $report = New-Object System.Collections.Generic.List[object]
    foreach ($a in $store) {
        $b = if ($a.Blocking) { 'true' } else { 'false' }
        $cells.Add(('{0}|{1}|{2}|{3}|{4}' -f $a.Name, $b, $a.State, $a.Size, $a.Findings))
        $report.Add([pscustomobject]@{
            name = $a.Name; blocking = [bool]$a.Blocking; state = $a.State
            size = [int]$a.Size; findings = [int]$a.Findings; reason = [string]$a.Reason
            registeredUtc = [string]$a.RegisteredUtc; completedUtc = [string]$a.CompletedUtc
        })
    }
    $line = if ($cells.Count -gt 0) { 'ARMS: ' + ($cells.ToArray() -join ';') } else { 'ARMS: none' }
    Write-Host $line
    return $report.ToArray()
}

function Assert-GateArmsComplete {
    <#  Throws, naming them, when any registered BLOCKING arm is still not-run,
        or ended 'empty'. The first is a gate that skipped its own rule; the
        second is a refusal that must reach exit 2, never a pass. Both messages
        carry the prefix a gate's top-level catch maps to exit 2 ('ARMS
        INCOMPLETE: ' and 'CHECK-SET EMPTY: '). Advisory arms left not-run are
        printed in yellow and do not throw. Call it before deciding PASS.  #>
    [CmdletBinding()]
    param()
    $store = Get-GateArmStore
    $notRun = New-Object System.Collections.Generic.List[string]
    $empty = New-Object System.Collections.Generic.List[string]
    $advisory = New-Object System.Collections.Generic.List[string]
    $blockingCount = 0
    foreach ($a in $store) {
        if ($a.Blocking) {
            $blockingCount++
            if ($a.State -eq 'not-run') { $notRun.Add($a.Name) }
            elseif ($a.State -eq 'empty') { $empty.Add($a.Name) }
        }
        elseif ($a.State -eq 'not-run') { $advisory.Add($a.Name) }
    }
    if ($advisory.Count -gt 0) {
        Write-Host ("  ! advisory arm(s) registered and never completed: {0}" -f ($advisory.ToArray() -join ', ')) -ForegroundColor Yellow
    }
    if ($notRun.Count -gt 0) {
        $also = if ($empty.Count -gt 0) { (' Blocking arm(s) that ended EMPTY: {0}.' -f ($empty.ToArray() -join ', ')) } else { '' }
        throw (New-Object System.InvalidOperationException (("ARMS INCOMPLETE: blocking arm(s) registered and never completed: {0}. Every declared arm ends ran (size > 0), empty (a refusal) or declared-n-a (with the contract's reason); a gate that leaves one not-run has skipped its own rule and cannot pass.{1}" -f ($notRun.ToArray() -join ', '), $also)))
    }
    if ($empty.Count -gt 0) {
        throw (New-Object System.InvalidOperationException (("CHECK-SET EMPTY: blocking arm(s) ended with an empty check-set: {0}. An empty blocking arm is a refusal (exit 2), never a pass." -f ($empty.ToArray() -join ', '))))
    }
    Write-Host ("  arms: {0} registered, {1} blocking, all complete" -f $store.Count, $blockingCount) -ForegroundColor DarkGray
}

function Get-GateArmNode {
    <#  Find a child of a contract node by key: exact, then case-insensitive,
        then with the gate verb (Assert-/Check-/Test-) stripped from both
        sides, so 'Assert-ScenarioClock' finds 'ScenarioClock'. Private.  #>
    [CmdletBinding()]
    param($Node, [Parameter(Mandatory)][string] $Key)
    if ($null -eq $Node -or $Node -is [string] -or $Node -is [ValueType]) { return $null }
    $names = @($Node.PSObject.Properties.Name)
    if ($names.Count -eq 0) { return $null }
    if ($names -ccontains $Key) { return $Node.$Key }
    $ci = @($names | Where-Object { $_ -ieq $Key })
    if ($ci.Count -eq 1) { return $Node.($ci[0]) }
    $verb = '^(?i)(Assert|Check|Test|Get|New)-'
    $bare = $Key -replace $verb, ''
    $m = @($names | Where-Object { ($_ -replace $verb, '') -ieq $bare })
    if ($m.Count -eq 1) { return $Node.($m[0]) }
    return $null
}

function Get-GateDeclaredNa {
    <#  The written reason an arm is declared NOT APPLICABLE for this build, or
        $null when it is not declared so. Read from contract.json through the
        same loader every other contract lookup uses (Get-GateContract):

          "gateArms": {
            "Assert-ScenarioClock": {
              "deliveries": { "applicable": false, "reason": "..." }
            }
          }

        Returns the reason ONLY when applicable is false AND a reason of at
        least 20 characters is written. applicable:false with no reason THROWS:
        an arm switched off without a reason is a gate switched off, and the
        audit handed this contract as evidence would have nothing to read.
        Absent contract, key, gate or arm, or applicable anything but false:
        $null - the arm applies. Pass -Contract to reuse a parsed contract.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $BuildDir,
        [Parameter(Mandatory)][string] $Gate,
        [Parameter(Mandatory)][string] $Arm,
        $Contract
    )
    if ($null -eq $Contract) { $Contract = Get-GateContract -BuildDir $BuildDir }
    if ($null -eq $Contract) { return $null }
    $arms = Get-GateArmNode -Node $Contract -Key 'gateArms'
    if ($null -eq $arms) { return $null }
    $gateNode = Get-GateArmNode -Node $arms -Key $Gate
    if ($null -eq $gateNode) { return $null }
    $armNode = Get-GateArmNode -Node $gateNode -Key $Arm
    if ($null -eq $armNode -or $armNode -is [string] -or $armNode -is [ValueType]) { return $null }
    $app = Get-GateProp -Object $armNode -Names @('applicable', 'applies', 'enabled')
    if ($null -eq $app) { return $null }
    if ("$app" -notmatch '^(?i)(false|no|0)$') { return $null }
    $reason = Get-GateProp -Object $armNode -Names @('reason', 'why', 'note')
    if (-not $reason -or "$reason".Trim().Length -lt 20) {
        throw (New-Object System.InvalidOperationException (("contract.json gateArms.{0}.{1} declares applicable:false with no written reason (or one too short to be one). Record WHY the arm does not apply to this build, so the audit can weigh it; an arm switched off without a reason is a gate switched off." -f $Gate, $Arm)))
    }
    return "$reason".Trim()
}

# ---------------------------------------------------------------------------
# Artwork: the ONE shape prefix, the ONE prompt-marker vocabulary, the ONE
# drawing count and the ONE caption predicate
#
# Three prompt vocabularies used to exist - the builder's, the extractor's and
# the placement gate's - and the narrowest one decided whether a reviewer was
# warned that a figure was still a prompt. The deck alt-text arm filtered
# picture shapes by a name list nothing in the builder wrote, examined zero
# drawings and printed green. Declared once here, read everywhere.
# ---------------------------------------------------------------------------

function Get-GateShapePrefix {
    <# The prefix every shape this skill draws is named with ('LG '). Pptx-Blocks reads it from here. #>
    [CmdletBinding()]
    param()
    return 'LG '
}

function Get-GatePromptVocabulary {
    <# The prompt-block kinds the guide builder emits and the trailer lines that follow a prompt body. Private; declared once. #>
    [CmdletBinding()]
    param()
    return [pscustomobject]@{
        Kinds    = @('IMAGE', 'DIAGRAM', 'ILLUSTRATION', 'PHOTO', 'FIGURE', 'PICTURE')
        Trailers = @('CAPTION', 'ALT', 'ASPECT', 'QUALITY', 'PROMPT')
    }
}

function Get-GatePromptMarkerTokens {
    <#  The literal marker tokens, for a sweep that searches text rather than
        paragraphs: '[IMAGE', '[DIAGRAM', ... then 'CAPTION:', 'ALT:', ...
        Derived from the same vocabulary as the regexes.  #>
    [CmdletBinding()]
    param()
    $v = Get-GatePromptVocabulary
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($k in $v.Kinds) { $out.Add('[' + $k) }
    foreach ($t in $v.Trailers) { $out.Add($t + ':') }
    return $out.ToArray()
}

function Get-GatePromptMarkerRegex {
    <#  A regex for one part of a prompt block, as the guide builder writes it:

          opener   a paragraph beginning '[' KIND ':' or '[' KIND '-'
                   e.g. [IMAGE: ...   [DIAGRAM - ...     group 1 = the kind
          closer   '[/' KIND ']'      e.g. [/IMAGE]        group 1 = the kind
          trailer  a paragraph beginning KIND ':' for CAPTION, ALT, ASPECT,
                   QUALITY, PROMPT                          group 1 = the kind
          any      the three alternated, for a presence test (groups unstable)

        CASE-SENSITIVE BY CONSTRUCTION - the regex carries (?-i), so -match,
        [regex] and Select-String all agree. The builder emits upper case, and
        a learner guide about purchasing has body paragraphs that begin
        'Quality: ...'; matching those would fail a clean document, which is a
        different check, not a stronger one.

        Anchored at the start of the paragraph (leading whitespace allowed);
        -Unanchored drops the anchor for a sweep over raw text.  #>
    [CmdletBinding()]
    param(
        [ValidateSet('opener', 'closer', 'trailer', 'any')][string] $Part = 'any',
        [switch] $Unanchored
    )
    $v = Get-GatePromptVocabulary
    $kinds = ($v.Kinds -join '|')
    $trailers = ($v.Trailers -join '|')
    $anchor = if ($Unanchored) { '' } else { '^\s*' }
    $opener  = $anchor + '\[\s*(' + $kinds + ')\s*[:\-]'
    $closer  = $anchor + '\[\s*/\s*(' + $kinds + ')\s*\]'
    $trailer = $anchor + '(' + $trailers + ')\s*:'
    switch ($Part) {
        'opener'  { return '(?-i)' + $opener }
        'closer'  { return '(?-i)' + $closer }
        'trailer' { return '(?-i)' + $trailer }
        default   { return '(?-i)(?:' + $opener + ')|(?:' + $closer + ')|(?:' + $trailer + ')' }
    }
}

function Get-GateDrawingCounts {
    <#  Count the drawings THIS SKILL PLACED in a rendered package, by the one
        rule the builder and the gates share: on a deck a p:pic whose cNvPr
        name starts with the shape prefix; on a guide a w:drawing whose docPr
        name starts with it. Every slide, notes slide, body, header and footer
        part is read.

        Returns an object with
          drawn       drawings carrying the prefix
          withAlt     of those, with non-empty descr or title (alt text)
          mediaParts  files under word/media or ppt/media
          total       every p:pic / w:drawing regardless of name
          unprefixed  total - drawn
          names       up to eight distinct names with counts, most common first
          parts       how many XML parts were read
          prefix, kind, filter (the rule, in words, for a failure message)

        The consumer decides: drawn = 0 while mediaParts > 0 is a filter that
        matched nothing on a package that carries pictures, and it names
        'filter'. -PackageDir is the expanded package root (the directory
        holding word\ or ppt\); a .docx/.pptx path is expanded to a temporary
        directory and removed afterwards. A package without its primary part
        throws naming the part.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $PackageDir,
        [Parameter(Mandatory)][ValidateSet('guide', 'deck')][string] $Kind,
        [string] $Prefix
    )
    if (-not $PSBoundParameters.ContainsKey('Prefix')) { $Prefix = Get-GateShapePrefix }
    if (-not "$Prefix") {
        throw (New-Object System.ArgumentException ('Get-GateDrawingCounts: -Prefix is empty. A drawing count with no name rule would count 0 of everything and look like a filter that matched nothing; omit -Prefix to use Get-GateShapePrefix.'))
    }
    if (-not (Test-Path -LiteralPath $PackageDir)) {
        throw (New-Object System.IO.FileNotFoundException (("Get-GateDrawingCounts: nothing at {0}. A drawing count over a package that is not there is not a count." -f $PackageDir)))
    }
    $root = (Resolve-Path -LiteralPath $PackageDir).Path
    $tmp = ''
    try {
        if (-not (Get-Item -LiteralPath $root).PSIsContainer) {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $tmp = Join-Path $env:TEMP ('gatedraw_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
            [System.IO.Compression.ZipFile]::ExtractToDirectory($root, $tmp)
            $root = $tmp
        }

        $partFiles = New-Object System.Collections.Generic.List[string]
        if ($Kind -eq 'guide') {
            $wordDir = Join-Path $root 'word'
            $primary = Join-Path $wordDir 'document.xml'
            if (-not (Test-Path -LiteralPath $primary)) {
                throw (New-Object System.IO.FileNotFoundException (("Get-GateDrawingCounts: {0} has no word\document.xml - not a Word package, or not expanded." -f $PackageDir)))
            }
            $partFiles.Add($primary)
            foreach ($hf in (Get-ChildItem -LiteralPath $wordDir -File | Where-Object { $_.Name -match '^(header|footer)\d*\.xml$' } | Sort-Object Name)) { $partFiles.Add($hf.FullName) }
            $mediaDir = Join-Path $wordDir 'media'
            $elementRx = '<w:drawing\b.*?</w:drawing>'
            $prRx = '<wp:docPr\b[^>]*>'
            $filter = ("w:drawing whose wp:docPr name starts with '{0}' (word/document.xml plus every header and footer part)" -f $Prefix)
        }
        else {
            $slideDir = Join-Path $root 'ppt\slides'
            $slides = @()
            if (Test-Path -LiteralPath $slideDir) {
                $slides = @(Get-ChildItem -LiteralPath $slideDir -File | Where-Object { $_.Name -match '^slide\d+\.xml$' } | Sort-Object { [int]([regex]::Match($_.Name, '\d+').Value) })
            }
            if ($slides.Count -eq 0) {
                throw (New-Object System.IO.FileNotFoundException (("Get-GateDrawingCounts: {0} has no ppt\slides\slideN.xml - not a PowerPoint package, or not expanded." -f $PackageDir)))
            }
            foreach ($s in $slides) { $partFiles.Add($s.FullName) }
            $notesDir = Join-Path $root 'ppt\notesSlides'
            if (Test-Path -LiteralPath $notesDir) {
                foreach ($n in (Get-ChildItem -LiteralPath $notesDir -File | Where-Object { $_.Name -match '^notesSlide\d+\.xml$' } | Sort-Object Name)) { $partFiles.Add($n.FullName) }
            }
            $mediaDir = Join-Path $root 'ppt\media'
            $elementRx = '<p:pic\b.*?</p:pic>'
            $prRx = '<p:cNvPr\b[^>]*>'
            $filter = ("p:pic whose p:cNvPr name starts with '{0}' (every ppt/slides and ppt/notesSlides part)" -f $Prefix)
        }

        $drawn = 0; $withAlt = 0; $total = 0
        $names = @{}
        foreach ($pf in $partFiles) {
            $xml = [System.IO.File]::ReadAllText($pf, [System.Text.Encoding]::UTF8)
            foreach ($em in [regex]::Matches($xml, $elementRx, 'Singleline')) {
                $total++
                $pr = [regex]::Match($em.Value, $prRx)
                $name = ''; $descr = ''; $title = ''
                if ($pr.Success) {
                    $name  = [System.Net.WebUtility]::HtmlDecode([regex]::Match($pr.Value, '\sname="([^"]*)"').Groups[1].Value)
                    $descr = [System.Net.WebUtility]::HtmlDecode([regex]::Match($pr.Value, '\sdescr="([^"]*)"').Groups[1].Value)
                    $title = [System.Net.WebUtility]::HtmlDecode([regex]::Match($pr.Value, '\stitle="([^"]*)"').Groups[1].Value)
                }
                if ($names.ContainsKey($name)) { $names[$name]++ } else { $names[$name] = 1 }
                if ($Prefix -and $name.StartsWith($Prefix, [System.StringComparison]::Ordinal)) {
                    $drawn++
                    if ($descr.Trim() -or $title.Trim()) { $withAlt++ }
                }
            }
        }
        $mediaParts = 0
        if (Test-Path -LiteralPath $mediaDir) { $mediaParts = @(Get-ChildItem -LiteralPath $mediaDir -File).Count }
        $nameList = @($names.GetEnumerator() | Sort-Object -Property @{ Expression = 'Value'; Descending = $true }, @{ Expression = 'Key'; Descending = $false } |
                     Select-Object -First 8 | ForEach-Object { ("'{0}' x{1}" -f $_.Key, $_.Value) })

        #  THE PLACED-FIGURE RULE THE CONSUMERS USE. A guide's figures are placed
        #  by the artwork sub-skill and carry ITS names ('IMG-012 illustration'),
        #  never this skill's prefix, and the template's own mark lives in the
        #  header - so on a guide the placed figures are every w:drawing in the
        #  BODY of word/document.xml, whatever it is called, headers and footers
        #  excluded. On a deck this skill places the pictures itself through
        #  Set-SlidePicture, which names them with the prefix, while the
        #  template's media ('Image 0..4') sits on every slide before any figure
        #  exists - so on a deck the placed figures are the prefixed p:pic only.
        #  bodyDrawings / bodyWithAlt carry that rule for both kinds so
        #  Check-Figures and Get-DocText count by one test.
        $bodyDrawings = $drawn
        $bodyWithAlt  = $withAlt
        if ($Kind -eq 'guide') {
            $bodyDrawings = 0; $bodyWithAlt = 0
            $docXml = [System.IO.File]::ReadAllText($primary, [System.Text.Encoding]::UTF8)
            $bs = $docXml.IndexOf('<w:body>')
            $bodyXml = if ($bs -ge 0) { $docXml.Substring($bs) } else { $docXml }
            foreach ($em in [regex]::Matches($bodyXml, $elementRx, 'Singleline')) {
                $bodyDrawings++
                $pr = [regex]::Match($em.Value, $prRx)
                if ($pr.Success) {
                    $d = [System.Net.WebUtility]::HtmlDecode([regex]::Match($pr.Value, '\sdescr="([^"]*)"').Groups[1].Value)
                    $t = [System.Net.WebUtility]::HtmlDecode([regex]::Match($pr.Value, '\stitle="([^"]*)"').Groups[1].Value)
                    if ($d.Trim() -or $t.Trim()) { $bodyWithAlt++ }
                }
            }
            $filter = "every w:drawing in the body of word/document.xml, whatever its name (headers and footers excluded; the sub-skill names what it places)"
        }

        return [pscustomobject]@{
            kind         = $Kind
            prefix       = $Prefix
            drawn        = $drawn
            withAlt      = $withAlt
            bodyDrawings = $bodyDrawings
            bodyWithAlt  = $bodyWithAlt
            mediaParts   = $mediaParts
            total        = $total
            unprefixed   = ($total - $drawn)
            names        = $nameList
            parts        = $partFiles.Count
            filter       = $filter
        }
    }
    finally {
        if ($tmp -and (Test-Path -LiteralPath $tmp)) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Test-GateCaptionParagraph {
    <#  Is this <w:p> a caption paragraph? True when the paragraph's joined w:t
        text starts with -CaptionPrefix as a whole word (so 'Figure 1.1.1 - x'
        is one and 'Figures arrive ...' is not), OR its w:pStyle matches
        -CaptionStyleRx. The prefix test is case-sensitive - a caption word is
        a house word with its case; the style regex is as supplied.

        Throws when both discriminators are empty: a predicate with nothing to
        test is vacuous and would count every paragraph.  #>
    [CmdletBinding()]
    param(
        [AllowEmptyString()][string] $ParagraphXml,
        [string] $CaptionPrefix = 'Figure',
        [string] $CaptionStyleRx = '(?i)caption'
    )
    if (-not $CaptionPrefix -and -not $CaptionStyleRx) {
        throw (New-Object System.ArgumentException ('Test-GateCaptionParagraph: both -CaptionPrefix and -CaptionStyleRx are empty, so nothing distinguishes a caption from prose.'))
    }
    if (-not $ParagraphXml) { return $false }
    if ($CaptionPrefix) {
        $text = -join ([regex]::Matches($ParagraphXml, '<w:t(?:\s[^>]*)?>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value })
        $text = [System.Net.WebUtility]::HtmlDecode($text).Trim()
        $rx = '^' + [regex]::Escape($CaptionPrefix) + '(?![A-Za-z])'
        if ($text -cmatch $rx) { return $true }
    }
    if ($CaptionStyleRx) {
        $style = [regex]::Match($ParagraphXml, '<w:pStyle\s+w:val="([^"]*)"').Groups[1].Value
        if ($style -and $style -match $CaptionStyleRx) { return $true }
    }
    return $false
}

# ---------------------------------------------------------------------------
# The anchored-finding contract: a finding that cannot be re-found is a defect
# in the GATE, and must never be remediated as a defect in the document
#
# Every blocking finding this toolchain raises names four things - the Rule it
# breaks, the File it lives in, the Field inside that file, and the Quote the
# harvester actually read. New-GateFinding builds one and refuses a finding
# missing any of them.
#
# Test-GateFindingAnchor then RE-OPENS the named file and re-finds the quote AT
# THE HARVESTER'S DECLARED TOKEN BOUNDARY - never as a bare substring. '7.5 L'
# is not in '17.5 L', and a gate that says it is has found a tokeniser artefact
# and called it a defect in the pack. On the reference build every traceable
# blocking finding was manufactured that way and nothing in the toolchain could
# say so; three remediation rounds were spent editing a document that was
# right.
#
# AN 'X IS NOT IN S' FINDING CARRIES S. "Observation 1 item is not among the
# pack's references" is a finding only when 'Observation 1 item' is what the
# spine says AND every member of the reference set can be re-found where the
# finding says the set lives. The pack's cell reads 'Observation 1, items 9 to
# 11'; the quote cannot be re-found; the gate is broken, not the pack. So a
# finding that names a set may not be raised without the set's locator.
#
# A finding whose anchor cannot be re-found is kind 'anchor-unresolved' and the
# gate exits 4 - GATE-DEFECT, the toolchain's this-gate-is-broken code.
# Run-SpineGates maps exit 4 to the GATE-DEFECT verdict, lists the member in
# defective[] APART FROM failed[], and refuses to record a band PASS or cut the
# figure sheet while it is non-empty; Test-StageLedger refuses to record such a
# member as a content failure or as a partial. That separation is the point: it
# has to be mechanical, or a gate defect gets laundered into partial[] and the
# band goes green over a gate that examined a defect it invented.
# ---------------------------------------------------------------------------

function Get-GateBoundaryRegexCache {
    <#  The memo table for the calling script, created on first touch. Private.

        The comma is load-bearing for the same reason as Get-GateArmStore's: a
        Dictionary returned bare is ENUMERATED on the way out and the caller
        gets KeyValuePairs instead of the table.  #>
    [CmdletBinding()]
    param()
    $v = Get-Variable -Name GateBoundaryRegexCache -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $v -or $null -eq $v.Value) {
        Set-Variable -Name GateBoundaryRegexCache -Scope Script -Value (New-Object 'System.Collections.Generic.Dictionary[string,string]')
        $v = Get-Variable -Name GateBoundaryRegexCache -Scope Script
    }
    return , $v.Value
}

function Get-GateValueBoundaryRegex {
    <#  THE ONE ANCHORED-BOUNDARY BUILDER. Every gate that asks "does this value
        appear in that document" builds its pattern here, so no two gates can
        answer the same question with two different definitions of a boundary.

            (?<![\d.\w]) <value> (?![\d.\w])

        The lookarounds exclude a digit, a dot and any word character on either
        side, which is what makes '7.5 L' absent from '17.5 L' and '10 per cent'
        absent from '110 per cent'. A bare substring test dispositioned both as
        PRESENT on the reference build; two of the three variant dispositions it
        printed were wrong.

        -FlexibleWhitespace matches any run of whitespace where the value has
        one, so a quote harvested from a cell still anchors when the file wraps
        it across a line. It never relaxes the boundary itself.

        -Raw takes -Value as a regex fragment already (the caller composed the
        alternation) and only wraps it in the boundary.

        THE DOT IS EXCLUDED ON BOTH SIDES, and that is deliberate: it is what
        keeps '7.5' out of '17.5' and out of '7.5.1'. The cost is that a value
        ending in a digit is not re-found immediately before a full stop
        ('... 9 to 11.'), so a caller quotes the value as its document
        punctuates it. Erring that way makes a value read ABSENT rather than
        PRESENT, which is the safe direction for every reader of this helper.

        -AllowPlural admits an English plural suffix INSIDE the boundary
        ('(?:es|s)?'), and -IgnoreCase prefixes '(?i)'. Both are OFF by default
        and both are opt-in for one reason: the coverage and figure-consistency
        gates need them (a bare boundary would stop '20 gastronorm' matching
        '20 gastronorms' and NARROW their stale-value and leakage arms - a fix
        that quietly removes a check is not a fix), while the anchored-finding
        contract must not have them (a quote re-found only as a plural, or only
        with case folded, is not what the file says). Composed with -Raw they
        reproduce the coverage gate's pattern exactly, so ONE definition of a
        boundary can serve every caller and the private copies can go.

        An empty -Value THROWS. A boundary around nothing matches at every
        position in the document, which is exactly how a gate prints PRESENT
        over a file that never carried the value.

        Memoised per calling script, keyed by value and switches.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string] $Value,
        [switch] $FlexibleWhitespace,
        [switch] $Raw,
        [switch] $AllowPlural,
        [switch] $IgnoreCase
    )
    if ($null -eq $Value -or "$Value".Trim() -eq '') {
        throw (New-Object System.ArgumentException ('Get-GateValueBoundaryRegex: -Value is empty. A boundary regex around nothing matches at every position in the document, so the caller would disposition PRESENT over a file that never carried the value.'))
    }
    $key = ('{0}|{1}|{2}|{3}|{4}' -f [int][bool]$FlexibleWhitespace, [int][bool]$Raw, [int][bool]$AllowPlural, [int][bool]$IgnoreCase, $Value)
    $cache = Get-GateBoundaryRegexCache
    if ($cache.ContainsKey($key)) { return $cache[$key] }

    $inner = ''
    if ($Raw) { $inner = "$Value" }
    elseif ($FlexibleWhitespace) {
        #  Split FIRST and escape the pieces: [regex]::Escape turns a space into
        #  '\ ', and patching that back up afterwards is a second rule about
        #  whitespace that can disagree with this one.
        $parts = @("$Value" -split '\s+' | Where-Object { $_ -ne '' })
        $inner = (($parts | ForEach-Object { [regex]::Escape($_) }) -join '\s+')
    }
    else { $inner = [regex]::Escape("$Value") }

    $rx = $(if ($IgnoreCase) { '(?i)' } else { '' }) + '(?<![\d.\w])' + $inner + $(if ($AllowPlural) { '(?:es|s)?' } else { '' }) + '(?![\d.\w])'
    $cache[$key] = $rx
    return $rx
}

function New-GateFinding {
    <#  Build ONE blocking finding, with everything needed to re-find it.

        Rule    the rule broken, as the gate names it
        File    the file the quote was read from (rooted, or relative to the
                build directory the anchor test is given)
        Field   the field inside that file - a spine path, a column, a cell
        Quote   the text the harvester actually read, verbatim
        Locator optional: where in the file, for a reader
        Detail  optional: free text for the report

        For an 'X is not in S' finding:
        SetMembers  every member of S
        SetLocator  the file S was read from - MANDATORY once SetMembers is
                    non-empty, because a set nobody can re-open is a set the
                    gate is believed about, and that is how "Observation 1 item
                    is not in the pack's references" survived over a pack whose
                    cell reads "Observation 1, items 9 to 11"
        SetName     optional: what S is called in the report

        Any of the four required fields blank THROWS. A finding that cannot say
        what it read cannot be tested, and an untestable finding is exactly the
        one that costs a remediation round.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Rule,
        [Parameter(Mandatory)][string] $File,
        [Parameter(Mandatory)][string] $Field,
        [Parameter(Mandatory)][string] $Quote,
        [string] $Locator = '',
        [string] $Detail = '',
        [string[]] $SetMembers = @(),
        [string] $SetLocator = '',
        [string] $SetName = ''
    )
    foreach ($p in @(, @('Rule', $Rule)) + @(, @('File', $File)) + @(, @('Field', $Field)) + @(, @('Quote', $Quote))) {
        if (-not "$($p[1])".Trim()) {
            throw (New-Object System.ArgumentException (("New-GateFinding: -{0} is empty. Every blocking finding names the Rule it breaks, the File and Field it was read from and the Quote the harvester read; a finding whose quote cannot be re-found is a defect in the gate, and nothing can say so unless the quote travels with the finding." -f $p[0])))
        }
    }
    $members = @($SetMembers | Where-Object { $null -ne $_ -and "$_".Trim() } | ForEach-Object { "$_" })
    if ($members.Count -gt 0 -and -not "$SetLocator".Trim()) {
        throw (New-Object System.ArgumentException (("New-GateFinding: rule '{0}' names a set of {1} member(s) with no -SetLocator. An 'X is not in S' finding is a finding only when every member of S can be re-found where the finding says S lives; with no locator the set is believed on the gate's word." -f $Rule, $members.Count)))
    }
    return [pscustomobject]@{
        #  FindingKind, NOT Kind. PowerShell property lookup is CASE-INSENSITIVE,
        #  and several gates key their own report rows on a lower-case 'kind'
        #  holding the RULE NAME. A gate that merged this object into such a row
        #  would have had its rule name silently replaced by the literal string
        #  'finding', and the corrupted finding would still print normally -
        #  the exact silent-success shape this phase exists to remove. The name
        #  is unambiguous so the collision cannot happen by accident.
        FindingKind = 'finding'
        Rule       = "$Rule"
        File       = "$File"
        Field      = "$Field"
        Quote      = "$Quote"
        Locator    = "$Locator"
        Detail     = "$Detail"
        SetName    = "$SetName"
        SetMembers = $members
        SetLocator = "$SetLocator"
        RaisedUtc  = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    }
}

function Test-GateFindingAnchor {
    <#  RE-OPEN the file a finding names and RE-FIND its quote at the token
        boundary. For a finding that names a set, re-find every member of the
        set at its own locator too.

        Returns the finding's fields plus:
          Verdict        'anchored' or 'anchor-unresolved'
          FindingKind    'finding' or 'anchor-unresolved'
          Resolved       [bool]
          Reason         why it could not be re-found, naming what failed
          FailedMember   the first member of S that could not be re-found
          MembersChecked / MembersTotal
          Path / SetPath the files actually opened
          Pattern        the boundary regex used
          SubstringOnly  the quote IS in the file, but not at a boundary

        The quote is matched CASE-SENSITIVELY. A verbatim quote that differs in
        case is not what the file says, and the honest answer is that the gate
        cannot re-find it - which costs a GATE-DEFECT, never a content finding.

        A finding whose file is not on disk is anchor-unresolved naming the
        path: a gate that cites a file the build does not have has not examined
        the build.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Finding,
        [string] $BaseDir = ''
    )
    $f = $Finding
    if ($f -is [System.Collections.IDictionary]) { $f = [pscustomobject]$f }

    $rule       = [string](Get-GateProp -Object $f -Names @('Rule', 'rule') -Default '')
    $file       = [string](Get-GateProp -Object $f -Names @('File', 'file') -Default '')
    $field      = [string](Get-GateProp -Object $f -Names @('Field', 'field') -Default '')
    $quote      = [string](Get-GateProp -Object $f -Names @('Quote', 'quote') -Default '')
    $locator    = [string](Get-GateProp -Object $f -Names @('Locator', 'locator') -Default '')
    $detail     = [string](Get-GateProp -Object $f -Names @('Detail', 'detail') -Default '')
    $setName    = [string](Get-GateProp -Object $f -Names @('SetName', 'setName') -Default '')
    $setLocator = [string](Get-GateProp -Object $f -Names @('SetLocator', 'setLocator') -Default '')
    $members    = @(Get-GateProp -Object $f -Names @('SetMembers', 'setMembers') -Default @() | Where-Object { $null -ne $_ -and "$_".Trim() } | ForEach-Object { "$_" })

    $out = [ordered]@{
        FindingKind = 'finding'; Rule = $rule; File = $file; Field = $field; Quote = $quote
        Locator = $locator; Detail = $detail; SetName = $setName; SetLocator = $setLocator
        SetMembers = $members
        Verdict = 'anchored'; Resolved = $true; Reason = ''
        FailedMember = ''; MembersChecked = 0; MembersTotal = $members.Count
        Path = ''; SetPath = ''; Pattern = ''; SubstringOnly = $false; PunctuationOnly = $false
    }
    function Resolve-Anchor { param([string] $Why) $out['Verdict'] = 'anchor-unresolved'; $out['FindingKind'] = 'anchor-unresolved'; $out['Resolved'] = $false; $out['Reason'] = $Why; return ([pscustomobject]$out) }

    if (-not $rule.Trim() -or -not $file.Trim() -or -not $field.Trim() -or -not $quote.Trim()) {
        return (Resolve-Anchor ("the finding is incomplete (Rule='{0}', File='{1}', Field='{2}', Quote='{3}') - a finding that cannot say what it read cannot be re-found, so it is a gate defect and never a content failure." -f $rule, $file, $field, $quote))
    }

    $path = $file
    if (-not [System.IO.Path]::IsPathRooted($path) -and $BaseDir) { $path = Join-Path $BaseDir $file }
    if (-not (Test-Path -LiteralPath $path)) {
        return (Resolve-Anchor ("rule '{0}' cites file '{1}' (looked at {2}), which is not there. A gate that cites a file the build does not have has not examined the build." -f $rule, $file, $path))
    }
    $out['Path'] = (Resolve-Path -LiteralPath $path).Path
    $text = Get-GateFileText -Path $out['Path']

    $rx = Get-GateValueBoundaryRegex -Value $quote -FlexibleWhitespace
    $out['Pattern'] = $rx
    if (-not [regex]::IsMatch($text, $rx)) {
        #  The diagnostics are ordered so the first true one is the most
        #  specific: a quote sitting against a full stop would otherwise be
        #  reported as a bare substring, which is a different defect with a
        #  different fix. NONE OF THEM CHANGES THE VERDICT - the boundary is the
        #  one shared builder's, and a quote that does not meet it is
        #  unresolved. They only say which way it missed.
        $why = 'it does not occur in the file at all'
        $inner = $rx -replace '^\(\?<!\[\\d\.\\w\]\)', '' -replace '\(\?!\[\\d\.\\w\]\)$', ''
        if ([regex]::IsMatch($text, ('(?<!\w|\d\.)' + $inner + '(?!\w|\.\d)'))) {
            $out['PunctuationOnly'] = $true
            $why = "it is re-found only when a neighbouring '.' is read as punctuation - the shared token boundary treats a dot beside the value as a decimal continuation, which is what keeps '7.5 L' out of '17.5 L'. Quote the value as the file punctuates it"
        }
        elseif ($text.IndexOf($quote, [System.StringComparison]::Ordinal) -ge 0) {
            $out['SubstringOnly'] = $true
            $why = 'it occurs only INSIDE a longer token - a bare substring, not a value the document states'
        }
        elseif ([regex]::IsMatch($text, $rx, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            $why = 'it is re-found only when case is ignored, so it is not what the file says'
        }
        return (Resolve-Anchor ("rule '{0}': the quote '{1}' cannot be re-found at a token boundary in {2} (field {3}) - {4}. The gate did not find a defect in the content; the gate is broken." -f $rule, $quote, $file, $field, $why))
    }

    if ($members.Count -gt 0) {
        if (-not $setLocator.Trim()) {
            return (Resolve-Anchor ("rule '{0}' names a set of {1} member(s) with no locator, so the set cannot be re-opened and the claim that '{2}' is not in it rests on the gate's word." -f $rule, $members.Count, $quote))
        }
        $sp = $setLocator
        if (-not [System.IO.Path]::IsPathRooted($sp) -and $BaseDir) { $sp = Join-Path $BaseDir $setLocator }
        if (-not (Test-Path -LiteralPath $sp)) {
            return (Resolve-Anchor ("rule '{0}': the set{1} is declared to live at '{2}' (looked at {3}), which is not there, so no member of it can be re-found." -f $rule, $(if ($setName) { " '$setName'" } else { '' }), $setLocator, $sp))
        }
        $out['SetPath'] = (Resolve-Path -LiteralPath $sp).Path
        $setText = Get-GateFileText -Path $out['SetPath']
        foreach ($m in $members) {
            $mrx = Get-GateValueBoundaryRegex -Value $m -FlexibleWhitespace
            if (-not [regex]::IsMatch($setText, $mrx)) {
                $out['FailedMember'] = $m
                return (Resolve-Anchor ("rule '{0}': member '{1}' of the set{2} cannot be re-found at a token boundary in {3}. Every member of S is re-found before 'X is not in S' is a finding; one that cannot be is a defect in the harvester that built S." -f $rule, $m, $(if ($setName) { " '$setName'" } else { '' }), $setLocator))
            }
            $out['MembersChecked'] = [int]$out['MembersChecked'] + 1
        }
    }

    return ([pscustomobject]$out)
}

function Assert-GateFindingAnchors {
    <#  THE HELPER A GATE CALLS BEFORE IT EXITS. Test every blocking finding's
        anchor, print what could not be re-found, and return the exit code:

          4  one or more findings are anchor-unresolved - GATE-DEFECT, this
             gate is broken and its findings are not evidence about the content
          1  every finding re-anchored: they are real findings
          0  there were no findings

        The gate does  exit $r.ExitCode  (4 dominates: a gate that cannot
        re-find one of its own anchors cannot be trusted about the others
        either, so its content findings are reported and not counted).

        Prints one machine-readable line, 'ANCHORS: tested N, anchored A,
        unresolved U', and one 'GATE-DEFECT:' line per unresolved finding.  #>
    [CmdletBinding()]
    param(
        $Findings,
        [string] $BaseDir = '',
        [string] $GateName = 'this gate',
        [switch] $Quiet
    )
    $list = @($Findings | Where-Object { $null -ne $_ })
    $results = New-Object System.Collections.Generic.List[object]
    foreach ($fnd in $list) { $results.Add((Test-GateFindingAnchor -Finding $fnd -BaseDir $BaseDir)) }
    $unresolved = @($results | Where-Object { $_.Verdict -eq 'anchor-unresolved' })
    $anchored   = @($results | Where-Object { $_.Verdict -eq 'anchored' })

    $code = 0
    if ($unresolved.Count -gt 0) { $code = 4 }
    elseif ($anchored.Count -gt 0) { $code = 1 }

    if (-not $Quiet) {
        foreach ($u in $unresolved) {
            Write-Host ("  X GATE-DEFECT: {0}: {1}" -f $GateName, $u.Reason) -ForegroundColor Red
        }
        Write-Host ("ANCHORS: tested {0}, anchored {1}, unresolved {2}" -f $results.Count, $anchored.Count, $unresolved.Count) -ForegroundColor $(if ($unresolved.Count) { 'Red' } elseif ($anchored.Count) { 'Yellow' } else { 'DarkGray' })
        if ($unresolved.Count -gt 0) {
            Write-Host ("  {0} exits 4 (GATE-DEFECT): a finding whose quote cannot be re-found at its token boundary is a defect in the CHECK-SET, not in the document. Fix the harvester; do not edit the pack against these {1} finding(s)." -f $GateName, $unresolved.Count) -ForegroundColor Red
        }
    }
    return [pscustomobject]@{
        GateName = $GateName; Tested = $results.Count
        Anchored = $anchored; Unresolved = $unresolved; Results = $results.ToArray()
        ExitCode = $code
        Line = ("ANCHORS: tested {0}, anchored {1}, unresolved {2}" -f $results.Count, $anchored.Count, $unresolved.Count)
    }
}

# ---------------------------------------------------------------------------
# Self-test. Runs ONLY as  -File Lib-GateCommon.ps1 -SelfTest ; never on
# dot-source. Under Set-StrictMode Latest so every helper is proved clean for
# the strict-mode callers too.
# ---------------------------------------------------------------------------

function Invoke-GateCommonSelfTest {
    [CmdletBinding()]
    param()
    Set-StrictMode -Version Latest
    $st = @{ Pass = 0; Fail = 0 }
    function Ok  { param([string] $m) $st.Pass++; Write-Host ("  ok   {0}" -f $m) -ForegroundColor Green }
    function Bad { param([string] $m) $st.Fail++; Write-Host ("  FAIL {0}" -f $m) -ForegroundColor Red }
    function Check { param([bool] $cond, [string] $m) if ($cond) { Ok $m } else { Bad $m } }
    function Unwrap { param($ex) $e = $ex; while ($null -ne $e -and $e -is [System.Management.Automation.RuntimeException] -and $null -ne $e.InnerException -and $e.GetType().FullName -eq 'System.Management.Automation.RuntimeException') { $e = $e.InnerException }; return $e }
    function Throws {
        param([scriptblock] $Block, [type] $Type, [string] $Prefix, [string] $Names, [string] $Label)
        try { $null = & $Block; Bad ("{0} - did not throw" -f $Label); return }
        catch {
            $e = Unwrap $_.Exception
            $msg = "$($e.Message)"
            if ($null -ne $Type -and -not ($e -is $Type)) { Bad ("{0} - threw {1}, expected {2}: {3}" -f $Label, $e.GetType().Name, $Type.Name, $msg); return }
            if ($Prefix -and -not $msg.StartsWith($Prefix)) { Bad ("{0} - message does not begin '{1}': {2}" -f $Label, $Prefix, $msg); return }
            if ($Names -and -not $msg.Contains($Names)) { Bad ("{0} - message does not name '{1}': {2}" -f $Label, $Names, $msg); return }
            Ok $Label
        }
    }
    function Lines { param($stream) return @(@($stream) | Where-Object { $_ -is [System.Management.Automation.InformationRecord] } | ForEach-Object { [string]$_.MessageData }) }
    function Values { param($stream) return @(@($stream) | Where-Object { $_ -isnot [System.Management.Automation.InformationRecord] }) }

    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $tmp = Join-Path $env:TEMP ('gatecommon_selftest_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $build = Join-Path $tmp 'build'
    $spine = Join-Path $build 'spine'
    New-Item -ItemType Directory -Force -Path $spine | Out-Null
    Write-Host ''
    Write-Host 'Lib-GateCommon self-test' -ForegroundColor Cyan
    try {
        # ---------------------------------------------------------- fixtures
        [System.IO.File]::WriteAllText((Join-Path $spine 't1_1.1.json'), '{"ref":"1.1","visuals":[{"slot":"1.1.1","kind":"Image","caption":"Figure 1.1.1 - A","alt":"alt a"},{"slot":"1.1.2","kind":"Diagram","caption":"Figure 1.1.2 - B","alt":"alt b","spec":{"rows":[["a","b"]]}}]}', $utf8)
        [System.IO.File]::WriteAllText((Join-Path $spine 't1_topic.json'), '{"topic":1}', $utf8)
        [System.IO.File]::WriteAllText((Join-Path $spine 'cover.json'), '{"visual":{"slot":"cover","kind":"Image","caption":"Cover caption","alt":"cover alt","prompt":"cover prompt"}}', $utf8)
        [System.IO.File]::WriteAllText((Join-Path $spine 'front.json'), '{"unitOverview":{"aboutThisUnit":["x"]}}', $utf8)
        [System.IO.File]::WriteAllText((Join-Path $spine 'deckframe.json'), '{"title":{"layout":"title"}}', $utf8)
        [System.IO.File]::WriteAllText((Join-Path $build 'contract.json'), '{"gateArms":{"Assert-ScenarioClock":{"deliveries":{"applicable":false,"reason":"This unit has no timed delivery scenario, so the clock arm has nothing to read."}},"Terminology":{"register":{"applicable":true,"reason":"applies"}},"Assert-Provenance":{"bare":{"applicable":false}}}}', $utf8)

        # ------------------------------------------------ 1. spine file set
        $default = @(Get-GateSpineFiles -BuildDir $build | ForEach-Object { $_.Name })
        Check (($default -join ',') -eq 't1_1.1.json,t1_topic.json') ("Get-GateSpineFiles default is the sub-sections only: {0}" -f ($default -join ','))
        $withFm = @(Get-GateSpineFiles -BuildDir $build -IncludeFrontMatter | ForEach-Object { $_.Name })
        Check (($withFm -join ',') -eq 'cover.json,deckframe.json,front.json,t1_1.1.json,t1_topic.json') ("-IncludeFrontMatter adds cover, deckframe and front: {0}" -f ($withFm -join ','))
        $fmNoCover = @(Get-GateSpineFiles -BuildDir $build -IncludeFrontMatter -Exclude @('cover.json') | ForEach-Object { $_.Name })
        Check (($fmNoCover -notcontains 'cover.json') -and ($fmNoCover -contains 'front.json')) '-IncludeFrontMatter honours an explicit -Exclude as given'
        [System.IO.File]::WriteAllText((Join-Path $spine 't1_1.1.gate.json'), '{"ok":true}', $utf8)
        [System.IO.File]::WriteAllText((Join-Path $spine 'band.result.json'), '{"ok":true}', $utf8)
        $all = @(Get-GateSpineFiles -BuildDir $build -IncludeFrontMatter -Exclude @() | ForEach-Object { $_.Name })
        Check (($all.Count -eq 5) -and ($all -notcontains 't1_1.1.gate.json') -and ($all -notcontains 'band.result.json')) ("sidecars *.gate.json and *.result.json are never spine files, even with -Exclude @(): {0}" -f ($all -join ','))
        Throws { Get-GateSpineFiles -BuildDir (Join-Path $tmp 'nowhere') } $null 'No spine at' '' 'a missing spine directory throws naming it'

        # ------------------------------------------------- 2. fingerprint v2
        $s1 = @(Get-SpineFingerprint -BuildDir $build 6>&1)
        $fpVals = @(Values $s1)
        $fp1 = [string]$fpVals[0]
        $printed = @(Lines $s1)
        Check (($fpVals.Count -eq 1) -and ($fp1 -match '^v2:[0-9a-f]{32}$')) ("Get-SpineFingerprint returns 'v2:' + 32 hex: {0}" -f $fp1)
        Check (@($printed | Where-Object { $_ -match 'spine fingerprint v2: 5 file\(s\)' }).Count -eq 1) ("the file count is printed and is the gate spine set (5): {0}" -f (($printed -join ' | ')))
        $q = @(Get-SpineFingerprint -BuildDir $build -Quiet 6>&1)
        $qVals = @(Values $q)
        Check ((@(Lines $q).Count -eq 0) -and ($qVals.Count -eq 1) -and ([string]$qVals[0] -eq $fp1)) '-Quiet prints nothing and returns the same value'
        [System.IO.File]::WriteAllText((Join-Path $spine 't1_1.1.gate.json'), '{"ok":false,"changed":true}', $utf8)
        [System.IO.File]::WriteAllText((Join-Path $spine 'other.result.json'), '{"x":1}', $utf8)
        $fp2 = Get-SpineFingerprint -BuildDir $build -Quiet
        Check ($fp2 -eq $fp1) 'a sidecar write leaves the fingerprint unchanged'
        [System.IO.File]::WriteAllText((Join-Path $spine 'deckframe.json'), '{"title":{"layout":"title","edited":true}}', $utf8)
        $fp3 = Get-SpineFingerprint -BuildDir $build -Quiet
        Check ($fp3 -ne $fp1) 'a deckframe.json edit changes the fingerprint'
        [System.IO.File]::WriteAllText((Join-Path $spine 'front.json'), '{"unitOverview":{"aboutThisUnit":["x","y"]}}', $utf8)
        $fp4 = Get-SpineFingerprint -BuildDir $build -Quiet
        Check ($fp4 -ne $fp3) 'a front.json edit changes the fingerprint'
        [System.IO.File]::WriteAllText((Join-Path $spine 'cover.json'), '{"visual":{"slot":"cover","kind":"Image","caption":"Cover caption 2","alt":"cover alt","prompt":"cover prompt"}}', $utf8)
        $fp5 = Get-SpineFingerprint -BuildDir $build -Quiet
        Check ($fp5 -ne $fp4) 'a cover.json edit changes the fingerprint'
        [System.IO.File]::WriteAllText((Join-Path $spine 't1_topic.json'), '{"topic":1,"edited":true}', $utf8)
        $fp6 = Get-SpineFingerprint -BuildDir $build -Quiet
        Check ($fp6 -ne $fp5) 'a sub-section edit changes the fingerprint'
        Check ((Get-SpineFingerprint -BuildDir $build -Quiet) -eq $fp6) 'the fingerprint is deterministic across calls'
        Check ((Get-SpineFingerprint -BuildDir (Join-Path $tmp 'nowhere') -Quiet) -eq '') 'no spine directory returns an empty string, not a throw'

        # --------------------------------------- 3. fingerprint version test
        Check ((Test-GateFingerprintVersion -Stamp 'v2:abc' -Current 'v2:abc') -eq 'match') 'same version, same hash: match'
        Check ((Test-GateFingerprintVersion -Stamp ' v2:ABC ' -Current 'v2:abc') -eq 'match') 'whitespace trimmed and hash case-folded: match'
        Check ((Test-GateFingerprintVersion -Stamp 'v2:abc' -Current 'v2:def') -eq 'spine-moved') 'same version, different hash: spine-moved'
        Check ((Test-GateFingerprintVersion -Stamp 'abc' -Current 'v2:abc') -eq 'version-changed') 'a bare v1 stamp against a v2 current: version-changed'
        Check ((Test-GateFingerprintVersion -Stamp 'v2:abc' -Current 'v3:abc') -eq 'version-changed') 'v2 against v3: version-changed'
        Check ((Test-GateFingerprintVersion -Stamp 'abc' -Current 'abc') -eq 'match') 'two bare v1 values still compare'
        Throws { Test-GateFingerprintVersion -Stamp '' -Current 'v2:abc' } ([System.ArgumentException]) '' '-Stamp' 'an empty -Stamp throws naming it'
        Throws { Test-GateFingerprintVersion -Stamp 'v2:abc' -Current '' } ([System.ArgumentException]) '' '-Current' 'an empty -Current throws naming it'

        # ---------------------------------------------- 4. visuals and cover
        $vis = @(Get-GateSpineVisuals -BuildDir $build)
        Check (($vis.Count -eq 2) -and (@($vis | Where-Object { $_.Source -eq 'visual' }).Count -eq 0)) ("default visuals are the sub-sections' plural lists: {0}" -f $vis.Count)
        $visFm = @(Get-GateSpineVisuals -BuildDir $build -IncludeFrontMatter)
        $cover = @($visFm | Where-Object { $_.File -eq 'cover.json' })
        Check (($visFm.Count -eq 3) -and ($cover.Count -eq 1) -and ($cover[0].Slot -eq 'cover') -and ($cover[0].Source -eq 'visual') -and ($cover[0].Caption -eq 'Cover caption 2')) '-IncludeFrontMatter folds the singular cover visual into the list, slot and caption read'
        $visEx = @(Get-GateSpineVisuals -BuildDir $build -IncludeFrontMatter -Exclude @('cover.json'))
        Check ($visEx.Count -eq 2) '-Exclude passes through to the file set'

        # ------------------------------------------------- 5. check-set line
        $l = @(Lines (Write-GateCheckSet -What 'spine files' -Count 3 -DerivedFrom 'the spine' -Excluded @('cover.json', 'deckframe.json') 6>&1))
        Check (($l.Count -eq 1) -and ($l[0] -match '^\s*check-set: 3 spine files, derived from the spine; excluded 2: cover\.json, deckframe\.json$')) ("-Excluded prints the names beside the count: {0}" -f $l[0])
        $l = @(Lines (Write-GateCheckSet -What 'terms' -Count 2 -DerivedFrom 'x' -Input 'contract.json terminology' -Blocking 6>&1))
        Check (($l.Count -eq 1) -and ($l[0] -match '^\s*check-set: 2 terms, derived from x \[input: contract\.json terminology\] \[blocking\]$')) ("-Input and -Blocking annotate after the parsed shape: {0}" -f $l[0])
        $l = @(Lines (Write-GateCheckSet -What 'terms' -Count 0 -DerivedFrom 'x' 6>&1))
        Check (($l.Count -eq 1) -and ($l[0] -match 'EMPTY \(advisory')) 'an advisory arm with an empty set prints EMPTY and does not throw'
        $l = @(Lines (Write-GateCheckSet -What 'terms' -Count 0 -DerivedFrom 'x' -Excluded @() 6>&1))
        Check (($l.Count -eq 1) -and ($l[0] -match 'excluded: none')) '-Excluded @() prints excluded: none'
        Throws { Write-GateCheckSet -What 'locked terms' -Count 0 -DerivedFrom 'contract.json' -Blocking -Input 'contract.json terminology.locked' 6>$null } ([System.InvalidOperationException]) 'CHECK-SET EMPTY: ' 'contract.json terminology.locked' '-Blocking -Count 0 throws InvalidOperationException beginning CHECK-SET EMPTY: and naming -Input'
        Throws { Write-GateCheckSet -What 'locked terms' -Count 0 -DerivedFrom 'contract.json' -Blocking 6>$null } ([System.InvalidOperationException]) 'CHECK-SET EMPTY: ' 'no -Input was named' '-Blocking -Count 0 with no -Input still throws, and says the input was not named'
        Throws { Write-GateCheckSet -What 'x' -Count -1 -DerivedFrom 'y' } ([System.ArgumentException]) '' 'negative' 'a negative count throws'
        $l = @(Lines (Write-GateCheckSet -What 'terms' -Count 4 -DerivedFrom 'x' -Blocking 6>&1))
        Check ($l.Count -eq 1) '-Blocking with a non-empty set prints and does not throw'

        # --------------------------------------------------- 6. arm roster
        Reset-GateArmRoster
        Check (@(Get-GateArmRoster).Count -eq 0) 'the roster starts empty'
        $l = @(Lines (Write-GateArmRoster 6>&1))
        Check (($l.Count -eq 1) -and ($l[0] -eq 'ARMS: none')) 'an empty roster prints ARMS: none'
        Register-GateArm -Name 'alpha' -Blocking
        Register-GateArm -Name 'beta'
        Register-GateArm -Name 'gamma' -Blocking
        Throws { Register-GateArm -Name 'alpha' } ([System.InvalidOperationException]) '' 'alpha' 'registering an arm twice throws naming it'
        Throws { Register-GateArm -Name 'a|b' } ([System.ArgumentException]) '' 'a|b' 'an arm name with a separator throws'
        Throws { Complete-GateArm -Name 'delta' -State ran -Size 1 } ([System.InvalidOperationException]) '' 'alpha, beta, gamma' 'completing an unregistered arm throws naming the registered set'
        Throws { Complete-GateArm -Name 'alpha' -State ran -Size 0 } ([System.InvalidOperationException]) 'CHECK-SET EMPTY: ' 'alpha' "ran with size 0 throws CHECK-SET EMPTY naming the arm"
        Throws { Complete-GateArm -Name 'gamma' -State declared-n-a -Reason 'short' } ([System.InvalidOperationException]) '' 'gamma' 'declared-n-a without a written reason throws'
        Throws { Complete-GateArm -Name 'gamma' -State empty -Size 2 } ([System.ArgumentException]) '' 'gamma' 'empty with a non-zero size throws'
        Throws { Assert-GateArmsComplete 6>$null } ([System.InvalidOperationException]) 'ARMS INCOMPLETE: ' 'alpha, gamma' 'Assert-GateArmsComplete throws naming every blocking arm not run'
        Complete-GateArm -Name 'alpha' -State ran -Size 3 -Findings 1
        Throws { Complete-GateArm -Name 'alpha' -State ran -Size 3 } ([System.InvalidOperationException]) '' 'alpha' 'completing an arm twice throws'
        Throws { Assert-GateArmsComplete 6>$null } ([System.InvalidOperationException]) 'ARMS INCOMPLETE: ' 'gamma' 'with alpha ran, only gamma is named'
        $naReason = Get-GateDeclaredNa -BuildDir $build -Gate 'Assert-ScenarioClock' -Arm 'deliveries'
        Complete-GateArm -Name 'gamma' -State declared-n-a -Reason $naReason
        $s = @(Write-GateArmRoster 6>&1)
        $line = @(Lines $s)
        $roster = @(Values $s)
        Check (($line.Count -eq 1) -and ($line[0] -eq 'ARMS: alpha|true|ran|3|1;beta|false|not-run|0|0;gamma|true|declared-n-a|0|0')) ("Write-GateArmRoster prints the one parsed line: {0}" -f $line[0])
        Check (($roster.Count -eq 3) -and ($roster[2].state -eq 'declared-n-a') -and ($roster[2].reason -eq $naReason) -and ($roster[0].findings -eq 1)) 'Write-GateArmRoster returns the roster for the report'
        $l = @(Lines (Assert-GateArmsComplete 6>&1))
        Check ((@($l | Where-Object { $_ -match 'advisory arm\(s\).*beta' }).Count -eq 1) -and (@($l | Where-Object { $_ -match 'all complete' }).Count -eq 1)) 'an advisory arm left not-run is printed, not thrown'
        Reset-GateArmRoster
        Register-GateArm -Name 'solo' -Blocking
        Complete-GateArm -Name 'solo' -State empty -Size 0
        Throws { Assert-GateArmsComplete 6>$null } ([System.InvalidOperationException]) 'CHECK-SET EMPTY: ' 'solo' 'a blocking arm that ended empty makes Assert-GateArmsComplete throw CHECK-SET EMPTY'
        Reset-GateArmRoster
        Check ((@(Get-GateArmRoster).Count -eq 0)) 'Reset-GateArmRoster empties it'

        # ------------------------------------------------ 7. declared N/A
        Check ($naReason -eq 'This unit has no timed delivery scenario, so the clock arm has nothing to read.') ("Get-GateDeclaredNa returns the contract reason: {0}" -f $naReason)
        Check ((Get-GateDeclaredNa -BuildDir $build -Gate 'ScenarioClock' -Arm 'deliveries') -eq $naReason) 'the gate key resolves with the verb stripped'
        Check ((Get-GateDeclaredNa -BuildDir $build -Gate 'assert-scenarioclock' -Arm 'DELIVERIES') -eq $naReason) 'gate and arm keys resolve case-insensitively'
        Check ($null -eq (Get-GateDeclaredNa -BuildDir $build -Gate 'Terminology' -Arm 'register')) 'applicable:true returns null'
        Check ($null -eq (Get-GateDeclaredNa -BuildDir $build -Gate 'Terminology' -Arm 'absent')) 'an undeclared arm returns null'
        Check ($null -eq (Get-GateDeclaredNa -BuildDir $build -Gate 'Nobody' -Arm 'x')) 'an undeclared gate returns null'
        Check ($null -eq (Get-GateDeclaredNa -BuildDir (Join-Path $tmp 'nocontract') -Gate 'X' -Arm 'y')) 'no contract returns null'
        Throws { Get-GateDeclaredNa -BuildDir $build -Gate 'Assert-Provenance' -Arm 'bare' } ([System.InvalidOperationException]) '' 'Assert-Provenance.bare' 'applicable:false with no reason throws naming gate and arm'
        $c = Get-GateContract -BuildDir $build
        Check ((Get-GateDeclaredNa -BuildDir $build -Gate 'Assert-ScenarioClock' -Arm 'deliveries' -Contract $c) -eq $naReason) '-Contract reuses a parsed contract'

        # -------------------------------------- 8. prefix and prompt markers
        Check ((Get-GateShapePrefix) -eq 'LG ') "Get-GateShapePrefix is 'LG '"
        $op = Get-GatePromptMarkerRegex -Part opener
        $cl = Get-GatePromptMarkerRegex -Part closer
        $tr = Get-GatePromptMarkerRegex -Part trailer
        $any = Get-GatePromptMarkerRegex
        Check (('[IMAGE: a bench' -match $op) -and ($Matches[1] -eq 'IMAGE')) 'opener matches [IMAGE: and captures the kind'
        Check (('  [DIAGRAM - flow' -match $op) -and ($Matches[1] -eq 'DIAGRAM')) 'opener matches [DIAGRAM - with leading space'
        Check ((-not ('see [Figure 1.1.1]' -match $op)) -and (-not ('[image: x' -match $op)) -and (-not ('[IMAGERY: x' -match $op))) 'opener rejects an in-prose bracket, lower case and a longer word'
        foreach ($k in @('IMAGE', 'DIAGRAM', 'ILLUSTRATION', 'PHOTO', 'FIGURE', 'PICTURE')) { if (-not (('[' + $k + ': x') -match $op)) { Bad ("opener misses kind {0}" -f $k) } }
        Check (('[/IMAGE]' -match $cl) -and ($Matches[1] -eq 'IMAGE') -and ('[/ DIAGRAM ]' -match $cl)) 'closer matches [/KIND]'
        Check ((-not ('[/IMAGE' -match $cl)) -and (-not ('[/image]' -match $cl))) 'closer rejects an unclosed or lower-case marker'
        Check (('CAPTION: Figure 1.1.1 - x' -match $tr) -and ($Matches[1] -eq 'CAPTION') -and ('PROMPT: y' -match $tr) -and ('ASPECT : 4:3' -match $tr)) 'trailer matches CAPTION:, PROMPT:, ASPECT :'
        Check ((-not ('Quality: the goods must match' -match $tr)) -and (-not ('CAPTION - x' -match $tr)) -and (-not ('The CAPTION: x' -match $tr))) 'trailer rejects sentence case, a dash and a mid-paragraph token'
        foreach ($t in @('CAPTION', 'ALT', 'ASPECT', 'QUALITY', 'PROMPT')) { if (-not (($t + ': x') -match $tr)) { Bad ("trailer misses {0}" -f $t) } }
        Check (('[PHOTO: x' -match $any) -and ('[/PHOTO]' -match $any) -and ('ALT: x' -match $any) -and (-not ('plain prose' -match $any))) "'any' is the union"
        Check (('prose then [IMAGE: x' -match (Get-GatePromptMarkerRegex -Part opener -Unanchored)) -and (-not ('prose then [IMAGE: x' -match $op))) '-Unanchored drops the paragraph anchor'
        $toks = @(Get-GatePromptMarkerTokens)
        Check (($toks.Count -eq 11) -and ($toks[0] -eq '[IMAGE') -and ($toks[5] -eq '[PICTURE') -and ($toks[6] -eq 'CAPTION:') -and ($toks[10] -eq 'PROMPT:')) ("the literal token list is derived from the same vocabulary: {0}" -f ($toks -join ' '))

        # --------------------------------------------- 9. drawing counts
        $guide = Join-Path $tmp 'guide'
        New-Item -ItemType Directory -Force -Path (Join-Path $guide 'word\media') | Out-Null
        $gdoc = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"><w:body>' +
                '<w:p><w:r><w:drawing><wp:inline><wp:docPr id="1" name="LG Figure 1.1.1" descr="A described figure"/></wp:inline></w:drawing></w:r></w:p>' +
                '<w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:i/></w:rPr><w:t>Figure 1.1.1 - A</w:t></w:r></w:p>' +
                '<w:p><w:r><w:drawing><wp:anchor><wp:docPr id="2" name="LG Figure 1.1.2"/></wp:anchor></w:drawing></w:r></w:p>' +
                '<w:p><w:r><w:drawing><wp:inline><wp:docPr id="3" name="Picture 1" descr="template mark"/></wp:inline></w:drawing></w:r></w:p>' +
                '</w:body></w:document>'
        [System.IO.File]::WriteAllText((Join-Path $guide 'word\document.xml'), $gdoc, $utf8)
        [System.IO.File]::WriteAllText((Join-Path $guide 'word\header1.xml'), '<w:hdr xmlns:w="x" xmlns:wp="y"><w:p><w:r><w:drawing><wp:inline><wp:docPr id="9" name="LG Mark" title="brand mark"/></wp:inline></w:drawing></w:r></w:p></w:hdr>', $utf8)
        foreach ($i in 1..3) { [System.IO.File]::WriteAllBytes((Join-Path $guide ('word\media\image{0}.png' -f $i)), [byte[]]@(1, 2, 3)) }
        $g = Get-GateDrawingCounts -PackageDir $guide -Kind guide
        Check (($g.drawn -eq 3) -and ($g.withAlt -eq 2) -and ($g.mediaParts -eq 3) -and ($g.total -eq 4) -and ($g.unprefixed -eq 1) -and ($g.parts -eq 2)) ("guide: drawn {0}, withAlt {1}, mediaParts {2}, total {3}, parts {4}" -f $g.drawn, $g.withAlt, $g.mediaParts, $g.total, $g.parts)
        Check (($g.filter -match 'w:drawing') -and ($g.filter -match 'body of word/document.xml') -and (@($g.names).Count -eq 4) -and ($g.bodyDrawings -eq 3) -and ($g.bodyWithAlt -eq 2)) ("guide: the placed-figure rule is named, the names are listed and the body counts are carried: bodyDrawings {0}, bodyWithAlt {1}, names {2}" -f $g.bodyDrawings, $g.bodyWithAlt, (@($g.names) -join ', '))
        $g2 = Get-GateDrawingCounts -PackageDir $guide -Kind guide -Prefix 'IMG-'
        Check (($g2.drawn -eq 0) -and ($g2.total -eq 4) -and ($g2.mediaParts -eq 3)) 'guide: a prefix nothing carries counts drawn 0 while media parts and total stay - the consumer names the filter'
        Throws { Get-GateDrawingCounts -PackageDir $guide -Kind guide -Prefix '' } ([System.ArgumentException]) '' '-Prefix' 'an empty -Prefix throws rather than counting 0 of everything'

        $deck = Join-Path $tmp 'deck'
        New-Item -ItemType Directory -Force -Path (Join-Path $deck 'ppt\slides') | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $deck 'ppt\notesSlides') | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $deck 'ppt\media') | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $deck 'ppt\slides\slide1.xml'), '<p:sld xmlns:p="x"><p:cSld><p:spTree><p:sp><p:nvSpPr><p:cNvPr id="2" name="LG Title"/></p:nvSpPr></p:sp><p:pic><p:nvPicPr><p:cNvPr id="3" name="LG Figure 1" descr="alt one"/></p:nvPicPr></p:pic><p:pic><p:nvPicPr><p:cNvPr id="4" name="Image 0"/></p:nvPicPr></p:pic></p:spTree></p:cSld></p:sld>', $utf8)
        [System.IO.File]::WriteAllText((Join-Path $deck 'ppt\slides\slide2.xml'), '<p:sld xmlns:p="x"><p:cSld><p:spTree><p:pic><p:nvPicPr><p:cNvPr id="3" name="LG Figure 2"/></p:nvPicPr></p:pic></p:spTree></p:cSld></p:sld>', $utf8)
        [System.IO.File]::WriteAllText((Join-Path $deck 'ppt\notesSlides\notesSlide1.xml'), '<p:notes xmlns:p="x"><p:cSld><p:spTree><p:sp><p:nvSpPr><p:cNvPr id="2" name="Notes Placeholder 2"/></p:nvSpPr></p:sp></p:spTree></p:cSld></p:notes>', $utf8)
        foreach ($i in 1..2) { [System.IO.File]::WriteAllBytes((Join-Path $deck ('ppt\media\image{0}.png' -f $i)), [byte[]]@(1, 2, 3)) }
        $d = Get-GateDrawingCounts -PackageDir $deck -Kind deck
        Check (($d.drawn -eq 2) -and ($d.withAlt -eq 1) -and ($d.mediaParts -eq 2) -and ($d.total -eq 3) -and ($d.parts -eq 3)) ("deck: drawn {0}, withAlt {1}, mediaParts {2}, total {3}, parts {4} - a p:sp named with the prefix does not count" -f $d.drawn, $d.withAlt, $d.mediaParts, $d.total, $d.parts)
        Throws { Get-GateDrawingCounts -PackageDir $guide -Kind deck } ([System.IO.FileNotFoundException]) '' 'ppt\slides' 'a guide package asked for as a deck throws naming the missing part'
        Throws { Get-GateDrawingCounts -PackageDir $deck -Kind guide } ([System.IO.FileNotFoundException]) '' 'word\document.xml' 'a deck package asked for as a guide throws naming the missing part'
        Throws { Get-GateDrawingCounts -PackageDir (Join-Path $tmp 'nopkg') -Kind guide } ([System.IO.FileNotFoundException]) '' 'nopkg' 'a missing package throws naming it'
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zipPath = Join-Path $tmp 'fixture.docx'
        [System.IO.Compression.ZipFile]::CreateFromDirectory($guide, $zipPath)
        $gz = Get-GateDrawingCounts -PackageDir $zipPath -Kind guide
        Check (($gz.drawn -eq 3) -and ($gz.mediaParts -eq 3)) 'a .docx path is expanded and counted the same as its directory'

        # ------------------------------------------ 10. caption predicate
        $capP = '<w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:i/></w:rPr><w:t>Figure 1.1.1 - A</w:t></w:r></w:p>'
        Check ((Test-GateCaptionParagraph -ParagraphXml $capP -CaptionPrefix 'Figure' -CaptionStyleRx '(?i)caption')) 'a paragraph starting Figure N is a caption'
        Check ((Test-GateCaptionParagraph -ParagraphXml '<w:p><w:r><w:t xml:space="preserve">Figure </w:t></w:r><w:r><w:t>2.1.3</w:t></w:r></w:p>' -CaptionPrefix 'Figure' -CaptionStyleRx '')) 'runs are joined before the prefix test'
        Check (-not (Test-GateCaptionParagraph -ParagraphXml '<w:p><w:r><w:t>Figures arrive with the delivery docket.</w:t></w:r></w:p>' -CaptionPrefix 'Figure' -CaptionStyleRx '(?i)caption')) 'Figures... is prose, not a caption'
        Check (-not (Test-GateCaptionParagraph -ParagraphXml '<w:p><w:r><w:t>see Figure 1.1.1 for the layout</w:t></w:r></w:p>' -CaptionPrefix 'Figure' -CaptionStyleRx '(?i)caption')) 'an in-prose cross-reference is not a caption'
        Check (-not (Test-GateCaptionParagraph -ParagraphXml '<w:p><w:r><w:t>figure 1.1.1</w:t></w:r></w:p>' -CaptionPrefix 'Figure' -CaptionStyleRx '')) 'the prefix test is case-sensitive'
        Check ((Test-GateCaptionParagraph -ParagraphXml '<w:p><w:pPr><w:pStyle w:val="Caption"/></w:pPr><w:r><w:t>Table 1 - x</w:t></w:r></w:p>' -CaptionPrefix 'Figure' -CaptionStyleRx '(?i)caption')) 'a Caption-styled paragraph is a caption whatever it starts with'
        Check (-not (Test-GateCaptionParagraph -ParagraphXml '<w:p><w:pPr><w:pStyle w:val="Heading4"/></w:pPr><w:r><w:t>Table 1 - x</w:t></w:r></w:p>' -CaptionPrefix 'Figure' -CaptionStyleRx '(?i)caption')) 'a differently styled paragraph is not'
        Check (-not (Test-GateCaptionParagraph -ParagraphXml '' -CaptionPrefix 'Figure')) 'an empty paragraph is false'
        Throws { Test-GateCaptionParagraph -ParagraphXml $capP -CaptionPrefix '' -CaptionStyleRx '' } ([System.ArgumentException]) '' 'CaptionPrefix' 'both discriminators empty throws'

        # ------------------------------------------- 11. -Input alias binds
        $l = @(Lines (Write-GateCheckSet -What 'w' -Count 1 -DerivedFrom 'd' -Input 'bound-through-alias' 6>&1))
        Check (($l.Count -eq 1) -and ($l[0] -match 'bound-through-alias')) '-Input reaches the parameter through its alias (a parameter literally named Input never binds)'

        # ---------------------------- 12. the anchored boundary, one builder
        $rx75 = Get-GateValueBoundaryRegex -Value '7.5 L'
        Check ($rx75 -eq '(?<![\d.\w])7\.5\ L(?![\d.\w])') ("Get-GateValueBoundaryRegex wraps the escaped value in the one anchor: {0}" -f $rx75)
        Check (-not [regex]::IsMatch('the drum holds 17.5 L of stock', $rx75)) "PLANT '7.5 L' does not match inside '17.5 L' (the lookbehind excludes a digit)"
        Check ([regex]::IsMatch('decant 7.5 L into the pot', $rx75)) "CONTROL '7.5 L' matches where the document states it"
        Check (-not [regex]::IsMatch('7.5 Litres', $rx75)) "PLANT '7.5 L' does not match inside '7.5 Litres' (the lookahead excludes a word character)"
        $rxPc = Get-GateValueBoundaryRegex -Value '10 per cent'
        Check ((-not [regex]::IsMatch('allow 110 per cent of the par', $rxPc)) -and ([regex]::IsMatch('allow 10 per cent over', $rxPc))) "PLANT '10 per cent' is absent from '110 per cent' and present where it is stated"
        $rxFlex = Get-GateValueBoundaryRegex -Value '2000 g of flour' -FlexibleWhitespace
        Check (([regex]::IsMatch("weigh 2000 g`r`n   of flour now", $rxFlex)) -and (-not [regex]::IsMatch('weigh 12000 g of flour', $rxFlex))) '-FlexibleWhitespace matches across a wrapped line and still holds the boundary'
        Check ((Get-GateValueBoundaryRegex -Value '7.5 L') -eq $rx75) 'the builder is memoised and returns the same pattern for the same value'
        $rxRaw = Get-GateValueBoundaryRegex -Value '(?:4|four) carton' -Raw
        Check ($rxRaw -eq '(?<![\d.\w])(?:4|four) carton(?![\d.\w])') '-Raw wraps a caller-composed alternation without escaping it'
        #  The coverage and figure-consistency gates need a plural suffix and a
        #  case fold inside the boundary; the anchored-finding contract must not
        #  have them. Both are opt-in, and composed they are the coverage gate's
        #  own pattern to the character - so one boundary definition serves both.
        $rxCvg = Get-GateValueBoundaryRegex -Value '20\ gastronorm' -Raw -AllowPlural -IgnoreCase
        Check ($rxCvg -eq '(?i)(?<![\d.\w])20\ gastronorm(?:es|s)?(?![\d.\w])') ("-Raw -AllowPlural -IgnoreCase composes the coverage gate's pattern exactly: {0}" -f $rxCvg)
        $rxPl = Get-GateValueBoundaryRegex -Value '20 gastronorm' -AllowPlural
        Check (([regex]::IsMatch('20 gastronorms per rack', $rxPl)) -and ([regex]::IsMatch('20 gastronorm per rack', $rxPl)) -and (-not [regex]::IsMatch('120 gastronorms', $rxPl))) '-AllowPlural admits the English plural inside the boundary and nothing else'
        Check ((-not [regex]::IsMatch('20 gastronorms', (Get-GateValueBoundaryRegex -Value '20 gastronorm'))) -and (-not [regex]::IsMatch('FIFO stock', (Get-GateValueBoundaryRegex -Value 'fifo')))) 'CONTROL the default admits neither a plural nor a case fold - the anchored-finding contract keeps the strict boundary'
        Throws { Get-GateValueBoundaryRegex -Value '   ' } ([System.ArgumentException]) '' '-Value is empty' 'an empty -Value throws rather than matching everywhere'

        # ------------------------------- 13. New-GateFinding refuses on absence
        $fnd = New-GateFinding -Rule 'reference-in-pack' -File 'corpus\uat.txt' -Field 'cells[3].text' -Quote 'Task 9(c)' -Detail 'cited by the spine'
        Check (($fnd.FindingKind -eq 'finding') -and ($fnd.Rule -eq 'reference-in-pack') -and ($fnd.Quote -eq 'Task 9(c)') -and (@($fnd.SetMembers).Count -eq 0) -and ($fnd.RaisedUtc -match '^\d{4}-')) 'New-GateFinding carries Rule, File, Field, Quote and a raised stamp'
        Throws { New-GateFinding -Rule '   ' -File 'a.txt' -Field 'f' -Quote 'q' } ([System.ArgumentException]) '' '-Rule is empty' 'a blank Rule throws naming the field'
        Throws { New-GateFinding -Rule 'r' -File 'a.txt' -Field 'f' -Quote '  ' } ([System.ArgumentException]) '' '-Quote is empty' 'a blank Quote throws naming the field'
        Throws { New-GateFinding -Rule 'ref-not-in-set' -File 'a.txt' -Field 'f' -Quote 'q' -SetMembers @('x', 'y') } ([System.ArgumentException]) '' '-SetLocator' "an 'X is not in S' finding with no set locator throws naming the rule"

        # --------------------- 14. the anchor test, with its planted defects
        $anch = Join-Path $tmp 'anchor'
        New-Item -ItemType Directory -Force -Path $anch | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $anch 'uat.txt'), "Observation 1, items 9 to 11 are completed by your assessor while you work.`r`nTask 9 (a) asks for the par level.", $utf8)
        [System.IO.File]::WriteAllText((Join-Path $anch 't1_1.1.json'), '{"ref":"1.1","body":["Answer Task 9(c) in your workbook.","Bench 1 holds 7.5 L of stock."]}', $utf8)
        [System.IO.File]::WriteAllText((Join-Path $anch 'drum.txt'), '17.5 L', $utf8)
        [System.IO.File]::WriteAllText((Join-Path $anch 'refs.txt'), "Task 1(a); Task 9 (a); Observation 1, items 9 to 11 are assessor-completed", $utf8)
        [System.IO.File]::WriteAllText((Join-Path $anch 'stop.txt'), 'The assessor completes items 9 to 11.', $utf8)

        #  PROOF: a direction-two finding holding the collapsed quote the
        #  observation formatter produced, against the cell that actually reads
        #  'Observation 1, items 9 to 11'.
        $bad = New-GateFinding -Rule 'spine-ref-not-in-pack' -File 'uat.txt' -Field 'cells[12]' -Quote 'Observation 1 item'
        $badR = Test-GateFindingAnchor -Finding $bad -BaseDir $anch
        Check (($badR.Verdict -eq 'anchor-unresolved') -and ($badR.FindingKind -eq 'anchor-unresolved') -and (-not $badR.Resolved) -and ($badR.Reason -match 'Observation 1 item') -and ($badR.Reason -match 'uat\.txt') -and ($badR.Reason -match 'the gate is broken')) ("PLANT 'Observation 1 item' against a cell reading 'Observation 1, items 9 to 11' is anchor-unresolved naming quote and file: " + $badR.Reason)
        $badExit = Assert-GateFindingAnchors -Findings @($bad) -BaseDir $anch -GateName 'Assert-SpineCounts' -Quiet
        Check (($badExit.ExitCode -eq 4) -and (@($badExit.Unresolved).Count -eq 1) -and ($badExit.Line -eq 'ANCHORS: tested 1, anchored 0, unresolved 1')) ("and the gate exits 4 (GATE-DEFECT): " + $badExit.Line)
        $badLines = @(Lines (Assert-GateFindingAnchors -Findings @($bad) -BaseDir $anch -GateName 'Assert-SpineCounts' 6>&1))
        Check ((@($badLines | Where-Object { $_ -match 'GATE-DEFECT' }).Count -ge 1) -and (@($badLines | Where-Object { $_ -match '^ANCHORS: ' }).Count -eq 1)) 'it prints a GATE-DEFECT line per unresolved finding and one parsed ANCHORS line'

        #  CONTROL: the quote the pack actually carries re-anchors, and the
        #  gate exits 1 - a real finding must still be a finding.
        $good = New-GateFinding -Rule 'spine-ref-not-in-pack' -File 'uat.txt' -Field 'cells[12]' -Quote 'Observation 1, items 9 to 11'
        $goodR = Test-GateFindingAnchor -Finding $good -BaseDir $anch
        Check (($goodR.Verdict -eq 'anchored') -and $goodR.Resolved -and (-not $goodR.Reason)) 'CONTROL the quote the cell actually carries re-anchors'

        #  PROOF: a 'Task 9(c)' the pack genuinely lacks exits 1, with the quote
        #  re-found in the file that CITES it.
        $missing = New-GateFinding -Rule 'spine-cites-a-question-the-pack-lacks' -File 't1_1.1.json' -Field 'body[0]' -Quote 'Task 9(c)' -Detail 'no Task 9(c) anywhere in the pack'
        $missingR = Test-GateFindingAnchor -Finding $missing -BaseDir $anch
        $missingExit = Assert-GateFindingAnchors -Findings @($missing) -BaseDir $anch -GateName 'Assert-SpineCounts' -Quiet
        Check (($missingR.Verdict -eq 'anchored') -and ($missingExit.ExitCode -eq 1) -and (@($missingExit.Anchored).Count -eq 1)) "PROOF a cited 'Task 9(c)' the pack lacks exits 1 with its quote re-found in the file that cites it"

        #  PROOF: '7.5 L' does not re-find in a file whose only text is '17.5 L'.
        $sub = New-GateFinding -Rule 'figure-not-in-corpus' -File 'drum.txt' -Field 'line 1' -Quote '7.5 L'
        $subR = Test-GateFindingAnchor -Finding $sub -BaseDir $anch
        Check (($subR.Verdict -eq 'anchor-unresolved') -and $subR.SubstringOnly -and ($subR.Reason -match 'INSIDE a longer token')) ("PLANT '7.5 L' does not re-find in a file whose only text is '17.5 L', and the reason says it is a substring: " + $subR.Reason)
        $subOk = Test-GateFindingAnchor -Finding (New-GateFinding -Rule 'figure-not-in-corpus' -File 't1_1.1.json' -Field 'body[1]' -Quote '7.5 L') -BaseDir $anch
        Check (($subOk.Verdict -eq 'anchored') -and (-not $subOk.SubstringOnly)) "CONTROL '7.5 L' re-anchors in the file that states it"

        #  PROOF: an X-not-in-S finding one of whose set members cannot be
        #  re-found is anchor-unresolved NAMING that member.
        $setBad = New-GateFinding -Rule 'ref-not-in-reference-set' -File 't1_1.1.json' -Field 'body[0]' -Quote 'Task 9(c)' -SetName 'pack reference set' -SetLocator 'refs.txt' -SetMembers @('Task 1(a)', 'Observation 1 item', 'Task 9 (a)')
        $setBadR = Test-GateFindingAnchor -Finding $setBad -BaseDir $anch
        Check (($setBadR.Verdict -eq 'anchor-unresolved') -and ($setBadR.FailedMember -eq 'Observation 1 item') -and ($setBadR.Reason -match 'Observation 1 item') -and ($setBadR.Reason -match 'refs\.txt')) ("PLANT one member of S that cannot be re-found makes the finding anchor-unresolved naming the member: " + $setBadR.Reason)
        $setOk = New-GateFinding -Rule 'ref-not-in-reference-set' -File 't1_1.1.json' -Field 'body[0]' -Quote 'Task 9(c)' -SetName 'pack reference set' -SetLocator 'refs.txt' -SetMembers @('Task 1(a)', 'Observation 1, items 9 to 11', 'Task 9 (a)')
        $setOkR = Test-GateFindingAnchor -Finding $setOk -BaseDir $anch
        Check (($setOkR.Verdict -eq 'anchored') -and ($setOkR.MembersChecked -eq 3) -and ($setOkR.MembersTotal -eq 3)) 'CONTROL every member of S re-found leaves the finding anchored, with the members counted'
        $setGone = Test-GateFindingAnchor -Finding (New-GateFinding -Rule 'r' -File 't1_1.1.json' -Field 'body[0]' -Quote 'Task 9(c)' -SetLocator 'nowhere.txt' -SetMembers @('Task 1(a)')) -BaseDir $anch
        Check (($setGone.Verdict -eq 'anchor-unresolved') -and ($setGone.Reason -match 'nowhere\.txt')) "PLANT a set locator that is not on disk is anchor-unresolved naming it"

        $stopR = Test-GateFindingAnchor -Finding (New-GateFinding -Rule 'r' -File 'stop.txt' -Field 'f' -Quote 'items 9 to 11') -BaseDir $anch
        Check (($stopR.Verdict -eq 'anchor-unresolved') -and $stopR.PunctuationOnly -and (-not $stopR.SubstringOnly) -and ($stopR.Reason -match 'read as punctuation')) ("a value ending in a digit against a full stop is unresolved and SAYS it was the punctuation, not a substring: " + $stopR.Reason)

        $noFile = Test-GateFindingAnchor -Finding (New-GateFinding -Rule 'r' -File 'not-extracted.txt' -Field 'f' -Quote 'q') -BaseDir $anch
        Check (($noFile.Verdict -eq 'anchor-unresolved') -and ($noFile.Reason -match 'not-extracted\.txt') -and ($noFile.Reason -match 'has not examined the build')) 'PLANT a finding citing a file the build does not have is anchor-unresolved naming the path'
        [System.IO.File]::WriteAllText((Join-Path $anch 'case.txt'), 'the fifo rule applies', $utf8)
        $caseR = Test-GateFindingAnchor -Finding (New-GateFinding -Rule 'r' -File 'case.txt' -Field 'f' -Quote 'FIFO') -BaseDir $anch
        Check (($caseR.Verdict -eq 'anchor-unresolved') -and ($caseR.Reason -match 'case is ignored')) 'PLANT a quote that only matches with case ignored is anchor-unresolved and says so'
        $none = Assert-GateFindingAnchors -Findings @() -BaseDir $anch -GateName 'Assert-SpineCounts' -Quiet
        Check (($none.ExitCode -eq 0) -and ($none.Tested -eq 0)) 'CONTROL a gate with no findings exits 0'
        $mix = Assert-GateFindingAnchors -Findings @($missing, $bad) -BaseDir $anch -GateName 'Assert-SpineCounts' -Quiet
        Check (($mix.ExitCode -eq 4) -and (@($mix.Anchored).Count -eq 1) -and (@($mix.Unresolved).Count -eq 1)) 'one unresolved anchor beside one real finding still exits 4 - a gate that cannot re-find one anchor is not evidence about the others'
        $hash = Test-GateFindingAnchor -Finding @{ Rule = 'r'; File = 'uat.txt'; Field = 'f'; Quote = 'Task 9 (a)' } -BaseDir $anch
        Check ($hash.Verdict -eq 'anchored') 'a finding handed in as a hashtable is read the same way'
        $bare = Test-GateFindingAnchor -Finding ([pscustomobject]@{ Rule = 'r'; File = 'uat.txt'; Field = ''; Quote = 'Task 9 (a)' }) -BaseDir $anch
        Check (($bare.Verdict -eq 'anchor-unresolved') -and ($bare.Reason -match 'incomplete')) 'a finding missing one of the four required fields is anchor-unresolved, never a content failure'
    }
    finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host ''
    if ($st.Fail -eq 0) {
        Write-Host ("  Lib-GateCommon self-test: {0} passed, 0 failed" -f $st.Pass) -ForegroundColor Green
        return 0
    }
    Write-Host ("  Lib-GateCommon self-test: {0} passed, {1} FAILED" -f $st.Pass, $st.Fail) -ForegroundColor Red
    return 1
}

#  Runs only when this file is the script being executed with -SelfTest. A
#  dot-source has InvocationName '.', and its $GateCommonSelfTest is $false
#  besides, so a gate loading this library can never trip it.
if ($GateCommonSelfTest -and $MyInvocation.InvocationName -ne '.') {
    exit (Invoke-GateCommonSelfTest)
}
