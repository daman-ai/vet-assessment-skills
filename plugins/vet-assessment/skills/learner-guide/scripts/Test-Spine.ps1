<#
    Test-Spine.ps1 - validate the authored spine BEFORE either renderer runs,
    across the whole spine at Stage 3c, or ONE FILE AT A TIME while it is
    being written.

    The renderers do not invent content and do not repair it. Anything wrong
    here is wrong in both artefacts, so this runs first and blocks.

    WHY A PER-FILE MODE, AND WHY IT IS THE BASE EVERY IN-LOOP CHECK RUNS ON.
    The content-agent brief tells every author to run a sub-section test on
    each file before returning, and to paste its verdict into the report. The
    validator this replaces could only see the whole spine: it globbed the
    spine directory, parsed every file it found, and failed on the first one
    that was not valid JSON. Seven authors write in parallel, so at any moment
    a sibling is half-written and invalid, and a whole-spine run reported a
    false red on a file that was fine - or, more often, the author ran nothing
    and returned a file that was under the floor, claimed a reference its
    questionMap did not assign, or carried a curly quote that the ASCII-only
    build path turned into mojibake four hours later. So:

      -File <path>   validates ONE sub-section or topic file, reads NOTHING
                     else but the contract, and runs only the arms decidable
                     from that file plus the contract. The whole-spine arms
                     are SKIPPED and the output says which and why - never
                     silently, because a gate that quietly did not run is the
                     false green every gate in this skill was rewritten
                     against.

      -ResultPath    writes { file, sha256, mode, verdict, failures, warnings,
                     skippedArms } so a wrapper can prove, later, that the file
                     it accepted is the file that was validated: the hash is
                     computed from the SAME bytes the checks read, and an
                     author who edits after the check is caught by the hash
                     and not by trust.

    NOTHING ABOUT THE UNIT IS TYPED IN HERE. The validator this promotes had
    the unit's reference forms baked into its chip regex and read only its own
    build directory. Here the topics, the performance criteria, the question
    map and the reference pattern all come from contract.json; the floors come
    from the contract or the skill's documented defaults; the file names are
    derived from the contract's topics (t{T}_topic.json, t{T}_{PC}.json), so a
    missing file is named by the registry and not discovered by a glob.

    Checks:
      parse       the file is valid JSON
      charset     no character that cannot survive the ASCII-only build path,
                  as a literal OR as a \u escape (both reach the page), each
                  reported with its offset, line and column
      naming      the file name, the contract and the file's own pc/topic
                  fields agree on where this content belongs
      fields      every field the renderers read is present
      boxes       a callout node that exists but says nothing - it would render
                  as an empty titled box, which five of did ship on one build
                  because the renderer tested `if ($node)` and not its content
      floors      underpinning knowledge per sub-section (per-file); counted
                  prose per topic (whole-spine only)
      xref        this file's refs are exactly its questionMap entry, and it
                  carries the wording both renderers read (per-file); every
                  reference prepared exactly once, none nowhere (whole-spine)
      visuals     four per sub-section, right slots, Route B carries its spec,
                  Route A prompt inside the word band, caption and alt on all
      slides      notes where the deck gate demands them, shape text length,
                  chips resolve to real references (per-file); per-topic count,
                  figures and assessment-link slides (whole-spine only)
      topic       the topic wrapper's fields and key terms

    Exit 0 only when failures is empty. 1 failures, 2 a usage or validator
    error (the result file is still written, verdict ERROR), 4 the self-test
    failed.

    TRUSTED ONLY AFTER FAILING ON A PLANTED DEFECT. -SelfTest copies one real
    sub-section into a temp spine and proves: the clean copy passes and lists
    its skipped arms; a copy with underpinningKnowledge cut to 200 words fails
    naming the floor; a copy with a planted U+2019 fails naming the offset;
    the clean copy still passes with a deliberately invalid sibling beside it;
    and a whole-spine run on that same directory DOES see the sibling. Every
    plant is verified to have landed before the run it is meant to fail.
    Never touches the reference build.

    FRONT MATTER (P0-11). The whole-spine walk gains a front-matter arm set:
    front.json, cover.json and deckframe.json are enumerated with
    Get-GateSpineFiles -IncludeFrontMatter and swept for parse and charset like
    every other file, and each is checked against THE FIELDS THE RENDERERS READ
    FROM IT - derived at run time from the AST of Invoke-Render.ps1,
    Build-Guide.ps1 and Pptx-Blocks.ps1, following the variable each file is
    loaded into, never from a list typed in this gate. 56,737 bytes of front
    matter had been parse- and charset-checked by nobody, and deckframe.json's
    frame slides had never been text-gated at all.

    ARMS (Lib-GateCommon roster, whole-spine mode): spine-files,
    front-matter-files and front-matter-fields are BLOCKING, and an empty one
    is a typed refusal that this gate reports as REFUSED and exits 2 on.

    PS 5.1. ASCII only in this file.
#>

# GATE: stages=3c; requires=BuildDir

[CmdletBinding()]
param(
    #  Where the build lives. spine\ and contract.json are discovered under it.
    [string] $BuildDir,
    #  Override the spine directory (whole-spine mode only; -File never globs).
    [string] $SpineDir,
    #  Override the contract. In -File mode with neither this nor -BuildDir,
    #  the contract is looked for beside the file's parent directory.
    [string] $ContractPath,
    #  ONE sub-section or topic file to validate on its own.
    [string] $File,
    #  How the pack labels its assessed items. Default: the contract's
    #  referenceConvention.questionPattern, then the same fallback
    #  Test-GuideRules uses.
    [string] $QuestionPattern,
    #  Floors. Explicit value, else the contract, else the skill default.
    [int]    $TopicWordFloor,
    [int]    $SubjectWordFloor,
    [int]    $SlideFloor,
    #  Machine-readable verdict for a wrapper.
    [string] $ResultPath,
    [switch] $SelfTest,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

$GATE = 'Test-Spine'
$script:Self = $PSCommandPath
#  The skill root, for the renderer AST scan. $PSScriptRoot is populated here
#  (it is EMPTY inside a parameter default when the script is run as
#  `powershell -File`), with a guarded fallback for the scriptblock case.
$script:SkillDirForRenderers = ''
$__tsHere = $PSScriptRoot
if (-not $__tsHere -and $MyInvocation.MyCommand.Path) { $__tsHere = Split-Path -Parent $MyInvocation.MyCommand.Path }
if ($__tsHere) { $script:SkillDirForRenderers = Split-Path -Parent $__tsHere }

# ---------------------------------------------------------------------------
# The skill's documented defaults. Each is named with the reference that sets
# it, so a reader can see it is the skill's number and not this file's.
# ---------------------------------------------------------------------------

$DEFAULT_TOPIC_FLOOR   = 3000   # references\gates.md section 3
$DEFAULT_SUBJECT_FLOOR = 800    # references\gates.md section 3
$DEFAULT_SLIDE_FLOOR   = 15     # references\powerpoint.md, "at least 15 slides per Topic"
#  Same fallback as Test-GuideRules: the conventions actually in use across
#  packs. A pack that carries its own pattern in the contract wins.
$DEFAULT_QUESTION_PATTERN = '\b(?:Q|Question|Task|Item|Deliverable|Observation)\s?(\d+)\s?(\([a-z]\))?'

#  references\visuals.md: a Route A prompt is one paragraph of 90 to 160
#  words. The check tolerates to 175 before failing, as the build validator
#  did, because a prompt's closing exclusion clause pushes an honest 160 over.
$PROMPT_WORD_MIN       = 90
$PROMPT_WORD_MAX       = 160
$PROMPT_WORD_TOLERATED = 175
$VISUALS_PER_SUB       = 4

#  references\powerpoint.md: no text on any shape over 420 characters.
$SHAPE_CAP      = 420
$BULLET_CAP     = 220
$CHIP_CAP       = 190
$NOTE_MIN_WORDS = 25
$KEY_TERMS_MIN  = 6

#  The content model (references\content-model.md). These lists are the
#  fields the renderers read; Test-SpineRead.ps1 is the arm that checks them
#  against the renderers' own source, and until the renderer contract is
#  compiled into a schema they are declared here so a missing field is caught
#  at write time and not at placement.
$REQUIRED_SUB_FIELDS = @('ref', 'pc', 'title', 'whatThisMeans', 'remember', 'underpinningKnowledge',
                         'regulatoryBasis', 'howToDoIt', 'caseStudy', 'commonErrors', 'selfCheck',
                         'assessmentLink', 'visuals', 'slides')
#  THE TOPIC-LEVEL CONTENT MODEL, and it is this gate's own. No file on disk
#  carries it: the guide profile's callouts map is a list of BOX TYPES the
#  guide can render (remember, keyPoint, workedExample, ...), not the fields a
#  topic node must carry, and three of the ten below - overview, summary,
#  outcomes - appear in no profile at all. Test-SpineRead.ps1 is the arm that
#  holds these against the renderers' own source, which is the only other
#  place that knows. Recorded as a refutation against GH02 in
#  assets\gate-hygiene.reclassified.json.
$REQUIRED_TOPIC_FIELDS = @('overview', 'outcomes', 'keyTerms', 'readBeforeYouStart', 'summary',
                           'industryInsight', 'reflection', 'discussion', 'assessmentPrep', 'furtherReading')
#  $NOTES_REQUIRED_KINDS and $SHAPE_FIELDS are NOT declared here. Both are
#  properties of the deck the build renders, and the deck profile
#  (assets\deck-layouts.<brand>.json) is where the build, Invoke-Render and
#  Assert-DeckParity all read them from. They are derived from it inside the
#  main try below, where a profile that yields nothing is a typed CHECK-SET
#  EMPTY refusal rather than a rule that quietly checks less than it says.
#
#  The typed lists this replaces had already drifted: the notes list carried
#  six of the profile's eight kinds - not 'outcomes', not 'key-terms' - while
#  Assert-DeckParity, reading the same profile's notesNotRequiredOn, required
#  notes on both. Two gates, one deck, two answers.
#  The recap slide kind is the spine's own and no template layout carries it,
#  so it is unioned in where the set is derived, named and explained there.
#  A callout box and the fields that can carry its content.
$BOX_FIELDS = [ordered]@{
    rolePlay          = @('scenario', 'roles', 'steps', 'doneWell')
    workedExample     = @('intro', 'lines')
    practicalActivity = @('scenario', 'youWillNeed', 'steps', 'doneWell', 'pointsTo')
    caseStudy         = @('narrative', 'thinkItThrough')
    selfCheck         = @('questions')
}

# ---------------------------------------------------------------------------
# Collectors and small helpers
# ---------------------------------------------------------------------------

$script:fail = New-Object System.Collections.Generic.List[string]
$script:warn = New-Object System.Collections.Generic.List[string]
$script:info = New-Object System.Collections.Generic.List[string]
$script:ran  = New-Object System.Collections.Generic.List[string]
$script:skip = New-Object System.Collections.Generic.List[object]

function Add-Fail { param([string] $m) $script:fail.Add($m) }
function Add-Warn { param([string] $m) $script:warn.Add($m) }
function Add-Info { param([string] $m) $script:info.Add($m) }
function Add-Ran  { param([string] $arm) if ($script:ran -notcontains $arm) { $script:ran.Add($arm) } }
function Add-Skip {
    param([string] $arm, [string] $why)
    $script:skip.Add([pscustomobject]@{ arm = $arm; reason = $why })
}

#  @($null).Count is 1, not 0. Every "how many" goes through here.
function Get-Count { param($x) if ($null -eq $x) { return 0 } return @($x).Count }
function AsArr     { param($x) if ($null -eq $x) { return @() } return @($x) }

function Count-Words {
    #  The same token rule the build validator used, so per-topic counts match
    #  it to the word.
    param([string] $Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return 0 }
    return @([regex]::Matches($Text, '[A-Za-z0-9][A-Za-z0-9''\-\.]*')).Count
}

function Count-BlockWords {
    param($Block)
    $n = 0
    foreach ($p in (AsArr $Block)) { $n += Count-Words ([string]$p) }
    return $n
}

function Get-SpineDeckVocabulary {
    <#  WHAT A SLIDE CAN CARRY AND WHICH SLIDES MUST BE TAUGHT FROM, read off
        the deck profile that declares both.

        assets\deck-layouts.<brand>.json is the one file that holds the layout
        map: deckRules.notesRequiredOn says which slide kinds must carry
        speaker notes, and layouts.*.slots names every text slot a slide can
        fill. Invoke-Render renders from it, Assert-DeckParity gates against
        it, and until this function existed Test-Spine carried its own typed
        copies of both - which had already fallen behind the profile by two
        slide kinds.

        Two deliberate adjustments, each named on the check-set line:

          'recap' is a SPINE slide kind with no template layout of its own, so
          no deck profile can name it. It has always required notes here and
          still does, so it is unioned in.

          'bullets' is dropped from the shape-cap set. It is an ARRAY of
          bullet strings with its own per-bullet cap immediately below the
          shape cap, and measuring the joined array against the shape cap
          would report one failure twice under two different rules.

        Every deck profile on disk is read and the sets unioned: the spine is
        brand-neutral and a kind or a slot any RTO's deck declares is one this
        gate should measure.  #>
    [CmdletBinding()]
    param([string] $SkillDir)

    $roots = New-Object System.Collections.Generic.List[string]
    if ($SkillDir) { $roots.Add((Join-Path $SkillDir 'assets')) }
    $notes = New-Object System.Collections.Generic.List[string]
    $slots = New-Object System.Collections.Generic.List[string]
    $from  = New-Object System.Collections.Generic.List[string]

    foreach ($r in $roots) {
        if (-not "$r".Trim() -or -not (Test-Path -LiteralPath "$r")) { continue }
        foreach ($f in @(Get-ChildItem -LiteralPath "$r" -Filter 'deck-layouts.*.json' -File -ErrorAction SilentlyContinue)) {
            $j = Get-GateJson -Path $f.FullName
            if ($null -eq $j) { continue }
            $added = 0
            $rules = Get-GateProp -Object $j -Names @('deckRules')
            foreach ($k in (AsArr (Get-GateProp -Object $rules -Names @('notesRequiredOn')))) {
                $kv = "$k".Trim()
                if ($kv -and -not $notes.Contains($kv)) { $notes.Add($kv); $added++ }
            }
            $layouts = Get-GateProp -Object $j -Names @('layouts')
            if ($null -ne $layouts) {
                foreach ($lay in @($layouts.PSObject.Properties)) {
                    if ($lay.Name -like '_*') { continue }
                    $sl = Get-GateProp -Object $lay.Value -Names @('slots')
                    if ($null -eq $sl) { continue }
                    foreach ($p in @($sl.PSObject.Properties)) {
                        $sn = "$($p.Name)".Trim()
                        if (-not $sn -or $sn -like '_*') { continue }
                        if (-not $slots.Contains($sn)) { $slots.Add($sn); $added++ }
                    }
                }
            }
            if ($added -gt 0) { $from.Add($f.Name) }
        }
    }

    #  The spine-only kind, and the one slot that is measured by another rule.
    if ($notes.Count -gt 0 -and -not $notes.Contains('recap')) { $notes.Add('recap') }
    $shape = New-Object System.Collections.Generic.List[string]
    foreach ($s in $slots) { if ($s -ne 'bullets') { $shape.Add($s) } }

    return [pscustomobject]@{
        NotesRequiredKinds = $notes.ToArray()
        ShapeFields        = $shape.ToArray()
        Source             = @($from)
    }
}

function Read-SpineFile {
    <#  Read ONE file as bytes, once. The hash and the text both come from
        those bytes, so the sha256 in the result describes exactly what was
        validated even if the file is rewritten a second later. Never throws
        on bad JSON - the parse error is a finding, not an exception.  #>
    param([Parameter(Mandatory)][string] $Path)
    $full = (Resolve-Path -LiteralPath $Path).Path
    $bytes = [System.IO.File]::ReadAllBytes($full)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $hash = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '') }
    finally { $sha.Dispose() }
    $raw = [System.Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF)
    $json = $null
    $err = ''
    if (-not $raw.Trim()) { $err = 'the file is empty' }
    else {
        try { $json = $raw | ConvertFrom-Json }
        catch { $err = $_.Exception.Message }
        if ($null -eq $json -and -not $err) { $err = 'the file parsed to nothing' }
    }
    return [pscustomobject]@{
        Name = (Split-Path $full -Leaf); Path = $full; Sha256 = $hash
        Raw = $raw; Json = $json; ParseError = $err
    }
}

function Get-SpineFileIdentity {
    <# What a spine file name says it is: t{T}_topic.json or t{T}_{PC}.json. #>
    param([string] $Name)
    if ($Name -match '^t(\d+)_topic\.json$') {
        return [pscustomobject]@{ Kind = 'topic'; Topic = [int]$Matches[1]; Pc = '' }
    }
    if ($Name -match '^t(\d+)_(\d+\.\d+)\.json$') {
        return [pscustomobject]@{ Kind = 'sub'; Topic = [int]$Matches[1]; Pc = $Matches[2] }
    }
    return $null
}

# ---------------------------------------------------------------------------
# Per-file arms. Each is decidable from ONE file plus the contract.
# ---------------------------------------------------------------------------

function Test-Charset {
    <#  Two sweeps. The raw text, for literal non-ASCII, each hit located by
        offset, line and column so an author can go straight to it. Then, only
        if the raw text is clean, the DECODED strings: a backslash-u2019
        escape is ASCII on disk and a curly quote on the page, and the build
        path is ASCII-only end to end. Offsets are 0-based character indexes into the decoded
        text with any BOM removed.  #>
    param($Sf)
    Add-Ran 'charset'
    $bad = [regex]::Matches($Sf.Raw, '[^\x09\x0A\x0D\x20-\x7E]')
    if ($bad.Count -gt 0) {
        $samples = New-Object System.Collections.Generic.List[string]
        $shown = 0
        foreach ($m in $bad) {
            if ($shown -ge 6) { break }
            $before = $Sf.Raw.Substring(0, $m.Index)
            $line = ([regex]::Matches($before, "`n")).Count + 1
            $col = $m.Index - $before.LastIndexOf("`n")
            $samples.Add(('offset {0} (line {1}, col {2}) U+{3:X4}' -f $m.Index, $line, $col, [int][char]$m.Value))
            $shown++
        }
        $more = if ($bad.Count -gt 6) { '; ...' } else { '' }
        Add-Fail ('{0} carries {1} non-ASCII character(s): {2}{3} - replace them with plain ASCII' -f $Sf.Name, $bad.Count, ($samples -join '; '), $more)
        return
    }
    if ($null -eq $Sf.Json) { return }
    $hits = 0
    $first = ''
    foreach ($c in (Get-GateSpineCells -Node $Sf.Json -File $Sf.Name -Path '' -Channel '' -Slot '')) {
        $m = [regex]::Match($c.Text, '[^\x09\x0A\x0D\x20-\x7E]')
        if ($m.Success) {
            $hits++
            if (-not $first) { $first = ('{0} carries U+{1:X4} at character {2}' -f $c.Path, [int][char]$m.Value, $m.Index) }
        }
    }
    if ($hits -gt 0) {
        Add-Fail ('{0} decodes to {1} string(s) with non-ASCII content written as \u escapes (first: {2}) - an escape reaches the page exactly as a literal would' -f $Sf.Name, $hits, $first)
    }
}

function Test-Naming {
    <#  The name, the contract and the file's own fields must agree on where
        this content belongs: the visual slots, the topic word floor and the
        renderer's placement all key off it.  #>
    param($Sf, $Ident)
    Add-Ran 'naming'
    if ($Ident.Kind -eq 'topic') {
        if (-not $script:topicIndex.ContainsKey($Ident.Topic)) {
            Add-Fail ('{0} is a topic file for topic {1}, which the contract does not have' -f $Sf.Name, $Ident.Topic)
        }
        $num = Get-GateProp -Object $Sf.Json -Names @('number', 'n', 'topic')
        if ($num -and ([string]$num) -ne ([string]$Ident.Topic)) {
            Add-Fail ("{0} is named for topic {1} but its own number field says '{2}'" -f $Sf.Name, $Ident.Topic, $num)
        }
        return
    }
    $pc = $Ident.Pc
    if (-not $script:pcTopic.ContainsKey($pc)) {
        Add-Fail ('sub-section file for {0} is not a performance criterion of this unit' -f $pc)
    }
    elseif ($script:pcTopic[$pc] -ne $Ident.Topic) {
        Add-Fail ('{0} places {1} in topic {2} but the contract places it in topic {3}' -f $Sf.Name, $pc, $Ident.Topic, $script:pcTopic[$pc])
    }
    $own = Get-GateProp -Object $Sf.Json -Names @('pc', 'ref')
    if ($own -and ([string]$own) -ne $pc) {
        Add-Fail ("{0} is named for {1} but its own pc field says '{2}'" -f $Sf.Name, $pc, $own)
    }
    $t = Get-GateProp -Object $Sf.Json -Names @('topic')
    if ($t -and ([string]$t) -ne ([string]$Ident.Topic)) {
        Add-Fail ("{0} is named for topic {1} but its own topic field says '{2}'" -f $Sf.Name, $Ident.Topic, $t)
    }
}

function Test-SubFields {
    param([string] $Pc, $S)
    Add-Ran 'fields'
    $have = @($S.PSObject.Properties.Name)
    foreach ($fld in $REQUIRED_SUB_FIELDS) {
        if ($have -notcontains $fld) { Add-Fail ("{0} is missing field '{1}'" -f $Pc, $fld) }
    }
}

function Test-BoxContent {
    <#  A callout whose node exists and whose content is empty still renders:
        the box draws, the icon and the bold title print, and nothing follows
        them. Five of these shipped in one round - three completely blank Role
        play boxes, all in the safety-critical topic - because the renderer
        tested `if ($node)` rather than whether the node had anything in it. A
        presence sweep cannot see an absence, so the absence is checked here,
        on the source. Content is judged through the shared normaliser, so a
        box holding only punctuation or rules is still empty.  #>
    param([string] $Pc, [string] $Name, $Node, [string[]] $Fields)
    if ($null -eq $Node) { return }                      # absent by design is fine
    $n = 0
    $have = @($Node.PSObject.Properties.Name)
    foreach ($f in $Fields) {
        if ($have -notcontains $f) { continue }
        foreach ($v in (AsArr $Node.$f)) { if (ConvertTo-GateNormal ([string]$v)) { $n++ } }
    }
    if ($n -eq 0) { Add-Fail ("{0} has a '{1}' box that exists but carries no content - it would render as an empty titled box" -f $Pc, $Name) }
}

function Test-Boxes {
    param([string] $Pc, $S)
    Add-Ran 'boxes'
    foreach ($k in $BOX_FIELDS.Keys) { Test-BoxContent -Pc $Pc -Name $k -Node $S.$k -Fields $BOX_FIELDS[$k] }
}

function Measure-SubProse {
    <#  What a sub-section contributes to its topic's counted prose, and its
        own underpinning-knowledge count. The rule is the brief's: whatThisMeans
        + underpinningKnowledge + regulatoryBasis + howToDoIt; boxes do not
        count.  #>
    param($S)
    $uk = Count-BlockWords $S.underpinningKnowledge
    $n = $uk
    $n += Count-BlockWords $S.whatThisMeans
    $n += Count-BlockWords $S.regulatoryBasis
    foreach ($st in (AsArr $S.howToDoIt)) {
        $n += Count-Words ([string]$st.step)
        $n += Count-Words ([string]$st.detail)
    }
    return [pscustomobject]@{ Uk = $uk; Prose = $n }
}

function Test-SubjectFloor {
    param([string] $Pc, [int] $Uk)
    Add-Ran 'floor-subject'
    if ($Uk -lt $script:SubjectFloor) { Add-Fail ('{0} underpinning knowledge is {1} words, floor is {2}' -f $Pc, $Uk, $script:SubjectFloor) }
}

function Test-XrefFile {
    <#  This file's refs must be EXACTLY its questionMap entry: nothing
        invented, nothing dropped, nothing borrowed. A pc the map does not
        name is assigned nothing, so any ref it claims is invented. Returns the
        refs it claims, for the whole-spine once-only arm.  #>
    param([string] $Pc, $S)
    Add-Ran 'xref-file'
    $want = @()
    if ($script:refMap.ContainsKey($Pc)) { $want = @($script:refMap[$Pc]) }
    else { Add-Info ('{0} is not named in the question map, so it may prepare no reference' -f $Pc) }
    $link = $S.assessmentLink
    $got = @()
    if ($null -ne $link) { $got = @(AsArr $link.refs | ForEach-Object { [string]$_ }) }
    foreach ($r in $want) { if ($got -notcontains $r) { Add-Fail ("{0} does not prepare '{1}', which its question map assigns to it" -f $Pc, $r) } }
    $dup = @{}
    foreach ($r in $got) {
        if ($want -notcontains $r) { Add-Fail ("{0} claims '{1}', which its question map does not assign to it" -f $Pc, $r) }
        if ($dup.ContainsKey($r)) { Add-Fail ("{0} lists '{1}' twice in its own refs" -f $Pc, $r) } else { $dup[$r] = $true }
    }
    if ($null -eq $link -or -not $link.wording) { Add-Fail ('{0} has no assessmentLink.wording - the guide box and the deck chip both read it' -f $Pc) }
    return $got
}

function Test-Visuals {
    <#  Four per sub-section in the four slots. Slots .2 and .4 are Route B
        and must carry the spec the spec-writer copies by slot; .1 and .3 are
        Route A and must carry a prompt inside the word band. Returns the
        route counts.  #>
    param([string] $Pc, [int] $TopicN, $S)
    Add-Ran 'visuals'
    $routeA = 0
    $routeB = 0
    $v = AsArr $S.visuals
    if ((Get-Count $v) -ne $VISUALS_PER_SUB) { Add-Fail ('{0} has {1} visual(s); the standard is exactly {2}' -f $Pc, (Get-Count $v), $VISUALS_PER_SUB) }
    $slotBase = '{0}.{1}' -f $TopicN, (($Pc -split '\.')[1])
    $expectSlots = @(1..$VISUALS_PER_SUB | ForEach-Object { '{0}.{1}' -f $slotBase, $_ })
    $gotSlots = @($v | ForEach-Object { [string](Get-GateProp -Object $_ -Names @('slot', 'figure', 'number')) })
    foreach ($sl in $expectSlots) { if ($gotSlots -notcontains $sl) { Add-Fail ('{0} has no visual in slot {1}' -f $Pc, $sl) } }
    foreach ($vis in $v) {
        if ($null -eq $vis) { continue }
        $sl = [string](Get-GateProp -Object $vis -Names @('slot', 'figure', 'number'))
        $kind = [string](Get-GateProp -Object $vis -Names @('kind', 'type'))
        $caption = [string](Get-GateProp -Object $vis -Names @('caption'))
        $alt = [string](Get-GateProp -Object $vis -Names @('alt', 'altText'))
        $prompt = [string](Get-GateProp -Object $vis -Names @('prompt'))
        if (-not $caption -and $sl -ne '0.1') { Add-Fail ('visual {0} has no caption' -f $sl) }
        if (-not $alt)     { Add-Fail ('visual {0} has no alt text' -f $sl) }
        if (-not $prompt)  { Add-Fail ('visual {0} has no prompt' -f $sl); continue }
        $isB = ($sl -match '\.(2|4)$')
        if ($isB) {
            if ($kind -ne 'Diagram') { Add-Fail ("visual {0} is a Route B slot and must be kind Diagram, not '{1}'" -f $sl, $kind) }
            $spec = Get-GateProp -Object $vis -Names @('spec')
            if ($null -eq $spec) { Add-Fail ('visual {0} carries no spec - the spec-writer refuses a slot with no spine spec' -f $sl) }
            else {
                $lay = [string](Get-GateProp -Object $spec -Names @('layout'))
                if ($lay -eq 'table') {
                    if ((Get-Count $spec.rows) -lt 2) { Add-Fail ('visual {0} is a table spec with fewer than two rows' -f $sl) }
                }
                elseif ((Get-Count $spec.nodes) -lt 2) {
                    Add-Fail ('visual {0} is a diagram spec with fewer than two nodes' -f $sl)
                }
            }
            $routeB++
        }
        else {
            if ($kind -ne 'Image') { Add-Fail ("visual {0} is a Route A slot and must be kind Image, not '{1}'" -f $sl, $kind) }
            $w = Count-Words $prompt
            if ($w -lt $PROMPT_WORD_MIN -or $w -gt $PROMPT_WORD_TOLERATED) {
                Add-Fail ('visual {0} prompt is {1} words; the band is {2} to {3}' -f $sl, $w, $PROMPT_WORD_MIN, $PROMPT_WORD_MAX)
            }
            if ($prompt -match '#[0-9A-Fa-f]{6}') { Add-Fail ('visual {0} prompt carries a hex colour; generators ignore hex, name the colour in plain words' -f $sl) }
            if ($prompt -notmatch '(?i)\bno text\b') { Add-Warn ("visual {0} prompt has no exclusion clause naming 'no text'" -f $sl) }
            $routeA++
        }
    }
    return [pscustomobject]@{ A = $routeA; B = $routeB }
}

function Test-SlideFields {
    <#  The rules decidable slide by slide: notes where the deck demands them,
        shape text under the cap, chips that name a reference the pack
        actually contains. The per-topic count is a whole-spine arm.  #>
    param([int] $TopicN, $Slides)
    Add-Ran 'slides-fields'
    foreach ($s in (AsArr $Slides)) {
        if ($null -eq $s) { continue }
        $kind = [string]$s.kind
        $head = [string]$s.headline
        if (($NOTES_REQUIRED_KINDS -contains $kind) -and -not $s.notes) {
            Add-Fail ("topic {0} has a '{1}' slide with no speaker notes: {2}" -f $TopicN, $kind, $head)
        }
        if ($s.notes -and (Count-Words ([string]$s.notes)) -lt $NOTE_MIN_WORDS) {
            Add-Warn ("topic {0} slide '{1}' has a note of under {2} words - a note must say what the point is and name the assessment item" -f $TopicN, $head, $NOTE_MIN_WORDS)
        }
        foreach ($fld in $SHAPE_FIELDS) {
            $val = [string]$s.$fld
            if ($val -and $val.Length -gt $SHAPE_CAP) { Add-Fail ("topic {0} slide '{1}' field '{2}' is {3} characters; the shape cap is {4}" -f $TopicN, $head, $fld, $val.Length, $SHAPE_CAP) }
        }
        foreach ($b in (AsArr $s.bullets)) {
            if (([string]$b).Length -gt $BULLET_CAP) { Add-Warn ("topic {0} slide '{1}' has a bullet of {2} characters" -f $TopicN, $head, ([string]$b).Length) }
        }
        if ($s.chip) {
            $chip = [string]$s.chip
            $hits = @([regex]::Matches($chip, $script:QuestionPattern))
            if ($hits.Count -eq 0) { Add-Fail ("topic {0} slide '{1}' has a chip naming no assessment item: {2}" -f $TopicN, $head, $chip) }
            foreach ($h in $hits) {
                if ($script:expectedRefs -notcontains $h.Value.Trim()) { Add-Fail ("topic {0} slide chip cites '{1}', which the pack does not contain" -f $TopicN, $h.Value.Trim()) }
            }
            if ($chip.Length -gt $CHIP_CAP) { Add-Warn ("topic {0} slide '{1}' chip is {2} characters and will crowd the shape" -f $TopicN, $head, $chip.Length) }
        }
    }
}

function Test-TopicFields {
    param([int] $TopicN, $Tp)
    Add-Ran 'topic-fields'
    foreach ($fld in $REQUIRED_TOPIC_FIELDS) {
        if (-not $Tp.$fld) { Add-Fail ("topic {0} is missing field '{1}'" -f $TopicN, $fld) }
    }
    $kt = Get-Count $Tp.keyTerms
    if ($kt -lt $KEY_TERMS_MIN) { Add-Warn ('topic {0} has {1} key terms; 7 to 12 is the target and they feed the glossary' -f $TopicN, $kt) }
    foreach ($k in (AsArr $Tp.keyTerms)) {
        if ($null -eq $k -or -not $k.term -or -not $k.plain) { Add-Fail ('topic {0} has a key term with no term or no plain-English definition' -f $TopicN) }
    }
}

function Get-SpineFrontMatterReadField {
    <#  THE FIELDS THE RENDERERS READ FROM THE FRONT MATTER, DERIVED AT RUN
        TIME FROM THEIR OWN AST.

        Invoke-Render.ps1, Build-Guide.ps1 and Pptx-Blocks.ps1 are parsed and
        every member access whose base expression ends in `front`, `cover` or
        `deckframe` contributes its member name to that file's set. The AST is
        used rather than a text search for the reason Test-SpineRead states:
        comments do not exist in an AST, and a field named only in a comment is
        exactly how a lost field hides. Nothing here is typed - a list of field
        names written into this gate would be a second source of truth free to
        drift from the renderer it claims to describe.

        Returns Fields (file name -> string[]) and Sources (the scripts read).  #>
    param([string] $SkillDir)

    $map = @{ 'front' = 'front.json'; 'cover' = 'cover.json'; 'deckframe' = 'deckframe.json' }
    $fields = @{}
    foreach ($f in $map.Values) { $fields[$f] = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal) }
    $sources = New-Object System.Collections.Generic.List[string]

    $scripts = @('Invoke-Render.ps1', 'Build-Guide.ps1', 'Pptx-Blocks.ps1')
    foreach ($name in $scripts) {
        $p = Join-Path (Join-Path $SkillDir 'scripts') $name
        if (-not (Test-Path -LiteralPath $p)) { continue }
        $errs = $null; $toks = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path -LiteralPath $p).Path, [ref]$toks, [ref]$errs)
        if ($errs -and $errs.Count -gt 0) {
            throw ('{0}: {1} does not parse ({2}). A renderer that does not parse cannot be asked what it reads from the front matter.' -f $GATE, $name, $errs[0].Message)
        }
        $sources.Add($name)

        #  A renderer rarely reads '$deckframe.x'. It loads the file into a
        #  variable of its own choosing - $frame = Read-JsonFile ... deckframe.json
        #  - and reads THAT. So the aliases are derived first, from any
        #  assignment whose right-hand side names the file, and the member scan
        #  then follows them. Without this the deckframe arm had no field set
        #  at all while Invoke-Render was reading its keys.
        $alias = @{}
        foreach ($a in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true)) {
            if (-not ($a.Left -is [System.Management.Automation.Language.VariableExpressionAst])) { continue }
            $rhs = "$($a.Right.Extent.Text)"
            foreach ($k in @($map.Keys)) {
                #  The node name goes into a REGEX, so it is escaped: an
                #  unescaped value decides what the pattern means the moment
                #  one of them carries a metacharacter, and the alias scan
                #  would then follow the wrong variable or none at all.
                if ($rhs -match ("(?i)['`"]" + [regex]::Escape("$k") + "\.json['`"]")) { $alias[$a.Left.VariablePath.UserPath] = $map[$k] }
            }
        }

        foreach ($m in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.MemberExpressionAst] }, $true)) {
            if (-not ($m.Member -is [System.Management.Automation.Language.StringConstantExpressionAst])) { continue }
            #  '$front', '$fm.cover', '$spine.deckframe' all end in the node
            #  name; a variable called $frontMatter does not, which is why the
            #  match is anchored on the whole final segment.
            $baseText = "$($m.Expression.Extent.Text)"
            $file = ''
            $mm = [regex]::Match($baseText, '(?i)(?:^\$|\.)(front|cover|deckframe)$')
            if ($mm.Success) { $file = $map[$mm.Groups[1].Value.ToLowerInvariant()] }
            else {
                $am = [regex]::Match($baseText, '^\$([A-Za-z_][A-Za-z0-9_]*)$')
                if ($am.Success -and $alias.ContainsKey($am.Groups[1].Value)) { $file = $alias[$am.Groups[1].Value] }
            }
            if (-not $file) { continue }
            [void]$fields[$file].Add($m.Member.Value)
        }
    }
    $out = @{}
    foreach ($k in $fields.Keys) { $out[$k] = @($fields[$k] | Sort-Object) }
    return [pscustomobject]@{ Fields = $out; Sources = $sources.ToArray() }
}

function Test-OneFile {
    <#  Every per-file arm, in order, for one parsed spine file. Returns what
        the whole-spine arms need from it. Parse and charset run on any file;
        nothing else runs on a file that did not parse.  #>
    param($Sf, $Ident)
    Add-Ran 'parse'
    Test-Charset -Sf $Sf
    if ($Sf.ParseError) {
        Add-Fail ('{0} is not valid JSON: {1}' -f $Sf.Name, $Sf.ParseError)
        return $null
    }
    Test-Naming -Sf $Sf -Ident $Ident
    $topicN = $Ident.Topic
    if ($Ident.Kind -eq 'sub' -and $script:pcTopic.ContainsKey($Ident.Pc)) { $topicN = $script:pcTopic[$Ident.Pc] }

    if ($Ident.Kind -eq 'topic') {
        Test-TopicFields -TopicN $topicN -Tp $Sf.Json
        Test-SlideFields -TopicN $topicN -Slides $Sf.Json.slides
        return [pscustomobject]@{
            Kind = 'topic'; Topic = $topicN
            OverviewWords = (Count-BlockWords $Sf.Json.overview)
            Slides = @(AsArr $Sf.Json.slides)
        }
    }

    $pc = $Ident.Pc
    $s = $Sf.Json
    Test-SubFields -Pc $pc -S $s
    Test-Boxes -Pc $pc -S $s
    $m = Measure-SubProse -S $s
    Test-SubjectFloor -Pc $pc -Uk $m.Uk
    $refs = @(Test-XrefFile -Pc $pc -S $s)
    $routes = Test-Visuals -Pc $pc -TopicN $topicN -S $s
    Test-SlideFields -TopicN $topicN -Slides $s.slides
    return [pscustomobject]@{
        Kind = 'sub'; Topic = $topicN; Pc = $pc
        Uk = $m.Uk; Prose = $m.Prose; Refs = $refs
        RouteA = $routes.A; RouteB = $routes.B
        Slides = @(AsArr $s.slides)
    }
}

# ---------------------------------------------------------------------------
# Result and report
# ---------------------------------------------------------------------------

function Write-Result {
    param([string] $Path, [System.Collections.IDictionary] $Body)
    if (-not $Path) { return }
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $json = [pscustomobject]$Body | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding $false))
}

function Write-Report {
    param([string] $Title, [string] $Verdict)
    if ($Quiet) { return }
    Write-Host ''
    Write-Host $Title -ForegroundColor Cyan
    foreach ($i in $script:info) { Write-Host "  - $i" -ForegroundColor DarkGray }
    foreach ($w in $script:warn) { Write-Host "  ! $w" -ForegroundColor Yellow }
    foreach ($f in $script:fail) { Write-Host "  X $f" -ForegroundColor Red }
    if ($script:skip.Count -gt 0) {
        Write-Host '  skipped arms - NOT proven by this run:' -ForegroundColor Yellow
        foreach ($k in $script:skip) { Write-Host ('    ~ {0}: {1}' -f $k.arm, $k.reason) -ForegroundColor Yellow }
    }
    $tail = if ($script:skip.Count -gt 0) { ('; {0} arm(s) skipped, listed above' -f $script:skip.Count) } else { '' }
    if ($Verdict -eq 'PASS') { Write-Host ('PASS - {0} warning(s){1}' -f $script:warn.Count, $tail) -ForegroundColor Green }
    else { Write-Host ('{0} - {1} problem(s), {2} warning(s){3}' -f $Verdict, $script:fail.Count, $script:warn.Count, $tail) -ForegroundColor Red }
}

# ---------------------------------------------------------------------------
# Resolve inputs: the contract, the floors, the pattern
# ---------------------------------------------------------------------------

function Resolve-ContractPath {
    if ($ContractPath) { return $ContractPath }
    if ($BuildDir) { return (Join-Path $BuildDir 'contract.json') }
    if ($File -and (Test-Path -LiteralPath $File)) {
        $fileDir = Split-Path -Parent ((Resolve-Path -LiteralPath $File).Path)
        foreach ($c in @((Join-Path (Split-Path -Parent $fileDir) 'contract.json'), (Join-Path $fileDir 'contract.json'))) {
            if (Test-Path -LiteralPath $c) { return $c }
        }
        return (Join-Path (Split-Path -Parent $fileDir) 'contract.json')
    }
    if ($SpineDir) { return (Join-Path (Split-Path -Parent ((Resolve-Path -LiteralPath $SpineDir).Path)) 'contract.json') }
    return ''
}

function Resolve-Floor {
    param([bool] $Explicit, [int] $Value, $Node, [string[]] $Names, [int] $Default, [string] $Label)
    if ($Explicit) { return [pscustomobject]@{ Value = $Value; From = 'parameter' } }
    $v = Get-GateProp -Object $Node -Names $Names
    if ($v -and ([int]$v) -gt 0) { return [pscustomobject]@{ Value = [int]$v; From = ('contract {0}' -f $Label) } }
    return [pscustomobject]@{ Value = $Default; From = 'skill default' }
}

$mode = if ($SelfTest) { 'selftest' } elseif ($File) { 'file' } else { 'spine' }
$verdict = 'PASS'
$exitCode = 0
$resultFile = ''
$resultHash = ''
$fileHashes = New-Object System.Collections.Generic.List[object]
$contractUsed = ''
$floorsUsed = [ordered]@{}

try {
    if ($File) {
        #  Named first, so the result file always says which file the wrapper
        #  asked about - even when it was never there to hash.
        $resultFile = $File
        if (-not (Test-Path -LiteralPath $File)) { throw ('{0}: file not found: {1}' -f $GATE, $File) }
    }
    $contractUsed = Resolve-ContractPath
    if (-not $contractUsed) { throw ('{0}: nothing to read. Pass -BuildDir, or -File (with -BuildDir or -ContractPath if the contract is not beside the spine), or -SpineDir with -ContractPath.' -f $GATE) }
    $contract = Get-GateJson -Path $contractUsed
    if ($null -eq $contract) { throw ('{0}: no contract at {1}. Every check here is derived from contract.json - the topics, the performance criteria, the question map and the reference pattern - so without it there is nothing to validate against.' -f $GATE, $contractUsed) }
    $contractUsed = (Resolve-Path -LiteralPath $contractUsed).Path

    # --- the registry: topics, pcs, refs, all from the contract
    $expectTopics = @(AsArr $contract.topics)
    if ($expectTopics.Count -eq 0) { throw ('{0}: the contract at {1} names no topics.' -f $GATE, $contractUsed) }
    $script:topicIndex = @{}
    $script:pcTopic = @{}
    foreach ($t in $expectTopics) {
        $n = [int]$t.n
        $script:topicIndex[$n] = $t
        foreach ($pc in (AsArr $t.pcs)) { $script:pcTopic[[string]$pc] = $n }
    }
    $script:refMap = @{}
    $script:expectedRefs = New-Object System.Collections.Generic.List[string]
    $mapCount = 0
    if (@($contract.PSObject.Properties.Name) -contains 'questionMap' -and $null -ne $contract.questionMap) {
        foreach ($p in ($contract.questionMap.PSObject.Properties | Where-Object { $_.Name -notlike '_*' })) {
            $mapCount++
            $script:refMap[[string]$p.Name] = @(AsArr $p.Value | ForEach-Object { [string]$_ })
            foreach ($r in $script:refMap[[string]$p.Name]) { $script:expectedRefs.Add($r) }
        }
    }

    # --- floors and the pattern, with provenance
    $wf = Get-GateProp -Object $contract -Names @('wordFloors')
    $df = Get-GateProp -Object $contract -Names @('deckFloors')
    $tf = Resolve-Floor -Explicit $PSBoundParameters.ContainsKey('TopicWordFloor')   -Value $TopicWordFloor   -Node $wf -Names @('topic', 'topicWords')                       -Default $DEFAULT_TOPIC_FLOOR   -Label 'wordFloors.topic'
    $sf = Resolve-Floor -Explicit $PSBoundParameters.ContainsKey('SubjectWordFloor') -Value $SubjectWordFloor -Node $wf -Names @('underpinningKnowledge', 'subject', 'subjectWords') -Default $DEFAULT_SUBJECT_FLOOR -Label 'wordFloors.underpinningKnowledge'
    $lf = Resolve-Floor -Explicit $PSBoundParameters.ContainsKey('SlideFloor')       -Value $SlideFloor       -Node $df -Names @('slidesPerTopic', 'slides')                   -Default $DEFAULT_SLIDE_FLOOR   -Label 'deckFloors.slidesPerTopic'
    $script:TopicFloor = $tf.Value
    $script:SubjectFloor = $sf.Value
    $script:SlideFloorN = $lf.Value
    $floorsUsed = [ordered]@{ topic = $tf.Value; topicFrom = $tf.From; subject = $sf.Value; subjectFrom = $sf.From; slides = $lf.Value; slidesFrom = $lf.From }

    $patternFrom = 'parameter'
    if (-not $QuestionPattern) {
        $rc = Get-GateProp -Object $contract -Names @('referenceConvention')
        $QuestionPattern = [string](Get-GateProp -Object $rc -Names @('questionPattern', 'pattern'))
        $patternFrom = 'contract referenceConvention.questionPattern'
        if (-not $QuestionPattern) { $QuestionPattern = $DEFAULT_QUESTION_PATTERN; $patternFrom = 'skill default (the contract carries none)' }
    }
    $null = [regex]::new($QuestionPattern)   # a bad pattern is a usage error, not a silent zero-match
    $script:QuestionPattern = $QuestionPattern

    Add-Info ('contract: {0}' -f $contractUsed)
    Add-Info ('floors: underpinning knowledge {0} ({1}); topic prose {2} ({3}); slides per topic {4} ({5})' -f $sf.Value, $sf.From, $tf.Value, $tf.From, $lf.Value, $lf.From)
    Add-Info ('question pattern: {0} ({1})' -f $QuestionPattern, $patternFrom)
    Add-Info ('contract carries {0} assessment reference(s) across {1} sub-section(s)' -f $script:expectedRefs.Count, $mapCount)

    # --- the deck vocabulary, DERIVED from the deck profile the build renders
    #     from. Both sets are blocking: a slide-kind set with nothing in it
    #     asks no slide for notes, and a slot set with nothing in it measures
    #     no text against the shape cap - each would print green over a deck
    #     nobody checked.
    $deckVocab = Get-SpineDeckVocabulary -SkillDir $script:SkillDirForRenderers
    $NOTES_REQUIRED_KINDS = @($deckVocab.NotesRequiredKinds)
    $SHAPE_FIELDS = @($deckVocab.ShapeFields)
    $vocabFrom = @($deckVocab.Source | Where-Object { "$_".Trim() })
    $vocabWhere = if ($vocabFrom.Count -gt 0) { $vocabFrom -join ', ' } else { 'the deck profile(s)' }
    Write-GateCheckSet -What 'slide kind(s) that must carry speaker notes' -Count $NOTES_REQUIRED_KINDS.Count -DerivedFrom ("deckRules.notesRequiredOn in {0}, plus the spine-only 'recap' kind no template layout carries" -f $vocabWhere) -Blocking -Input ('assets\deck-layouts.<brand>.json deckRules.notesRequiredOn under ' + $script:SkillDirForRenderers + ' - no deck profile names a kind that needs notes, so no slide on the spine would ever be asked for any')
    Write-GateCheckSet -What 'slide text slot(s) measured against the shape cap' -Count $SHAPE_FIELDS.Count -DerivedFrom ('layouts.*.slots in ' + $vocabWhere) -Blocking -Input ('assets\deck-layouts.<brand>.json layouts.*.slots under ' + $script:SkillDirForRenderers + ' - no deck profile declares a text slot, so no slide text would be measured against the ' + $SHAPE_CAP + '-character cap') -Excluded @('bullets')

    # =======================================================================
    # SELF-TEST
    # =======================================================================
    if ($SelfTest) {
        $refPath = $File
        if (-not $refPath) {
            $sd = if ($SpineDir) { $SpineDir } elseif ($BuildDir) { Join-Path $BuildDir 'spine' } else { '' }
            if (-not $sd) { throw ('{0}: -SelfTest needs a real sub-section to copy. Pass -File, or -BuildDir / -SpineDir so one can be named from the contract.' -f $GATE) }
            $t0 = $expectTopics[0]
            $pc0 = [string](@(AsArr $t0.pcs)[0])
            $refPath = Join-Path $sd ('t{0}_{1}.json' -f [int]$t0.n, $pc0)
        }
        if (-not (Test-Path -LiteralPath $refPath)) { throw ('{0}: -SelfTest reference file not found: {1}' -f $GATE, $refPath) }
        $refPath = (Resolve-Path -LiteralPath $refPath).Path
        $refIdent = Get-SpineFileIdentity -Name (Split-Path $refPath -Leaf)
        if ($null -eq $refIdent -or $refIdent.Kind -ne 'sub') { throw ('{0}: -SelfTest needs a SUB-SECTION file (t{{T}}_{{PC}}.json); got {1}' -f $GATE, $refPath) }
        $refTopic = $script:pcTopic[$refIdent.Pc]

        $tmpBuild = Join-Path ([System.IO.Path]::GetTempPath()) ('spinetest_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
        #  Named in script scope so the catch at the tail can ASK THE
        #  FILESYSTEM what this run actually wrote before it threw, rather than
        #  taking the exception's word for it.
        $script:SelfTestBuild = $tmpBuild
        $tmpSpine = Join-Path $tmpBuild 'spine'
        New-Item -ItemType Directory -Force -Path $tmpSpine | Out-Null
        Copy-Item -LiteralPath $contractUsed -Destination (Join-Path $tmpBuild 'contract.json')
        $cleanName = Split-Path $refPath -Leaf
        $cleanPath = Join-Path $tmpSpine $cleanName
        Copy-Item -LiteralPath $refPath -Destination $cleanPath

        #  THE FRONT MATTER TRAVELS WITH THE FIXTURE. The whole-spine run has a
        #  BLOCKING front-matter arm, so a fixture spine with no front.json,
        #  cover.json or deckframe.json would be refused before any case below
        #  is reached - and a self-test that cannot run proves nothing. Copied
        #  from the source spine where it exists; written as a minimal shape
        #  carrying fields the RENDERERS name where it does not, so the fixture
        #  is never a shape this gate invented for itself.
        $srcSpine = Split-Path $refPath -Parent
        $fmForFixture = Get-SpineFrontMatterReadField -SkillDir $script:SkillDirForRenderers
        foreach ($fmName in @('front.json', 'cover.json', 'deckframe.json')) {
            $srcFm = Join-Path $srcSpine $fmName
            $dstFm = Join-Path $tmpSpine $fmName
            if (Test-Path -LiteralPath $srcFm) { Copy-Item -LiteralPath $srcFm -Destination $dstFm -Force; continue }
            $obj = [ordered]@{}
            foreach ($k in @(@($fmForFixture.Fields[$fmName]) | Select-Object -First 3)) { $obj[$k] = 'fixture' }
            if ($obj.Count -eq 0) { $obj['title'] = 'fixture' }
            [System.IO.File]::WriteAllText($dstFm, ($obj | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($true)))
        }

        $cases = New-Object System.Collections.Generic.List[object]
        function Invoke-Child {
            #  Hashtable splat, never an array: array elements bind by position,
            #  so a '-File' string would land in -BuildDir.
            param([hashtable] $Params)
            $r = Join-Path $tmpBuild ('result_' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.json')
            $global:LASTEXITCODE = 0
            & $script:Self @Params -ResultPath $r -Quiet | Out-Null
            $code = $LASTEXITCODE
            $body = $null
            if (Test-Path -LiteralPath $r) { $body = Get-GateJson -Path $r }
            return [pscustomobject]@{ Code = $code; Result = $body }
        }
        function Record {
            param([string] $Name, [bool] $Ok, [string] $Detail)
            $cases.Add([pscustomobject]@{ name = $Name; ok = $Ok; detail = $Detail })
            if (-not $Quiet) {
                if ($Ok) { Write-Host ('  PASS  {0}: {1}' -f $Name, $Detail) -ForegroundColor Green }
                else     { Write-Host ('  FAIL  {0}: {1}' -f $Name, $Detail) -ForegroundColor Red }
            }
        }

        if (-not $Quiet) {
            Write-Host ''
            Write-Host ('{0} SELF-TEST on a temp copy of {1}' -f $GATE, $cleanName) -ForegroundColor Cyan
            Write-Host ('  temp build: {0}' -f $tmpBuild) -ForegroundColor DarkGray
        }
        try {
            # (b) the clean copy passes and lists the whole-spine arms it skipped
            $c = Invoke-Child @{ File = $cleanPath; BuildDir = $tmpBuild }
            $skipped = @()
            if ($null -ne $c.Result) { $skipped = @(AsArr $c.Result.skippedArms | ForEach-Object { [string]$_.arm }) }
            $need = @('structure', 'floor-topic', 'xref-once', 'slides-topic')
            $missing = @($need | Where-Object { $skipped -notcontains $_ })
            $ok = ($c.Code -eq 0 -and $null -ne $c.Result -and $c.Result.verdict -eq 'PASS' -and $missing.Count -eq 0)
            Record 'clean copy' $ok ('exit {0}, verdict {1}, skipped arms [{2}]{3}' -f $c.Code, $(if ($c.Result) { $c.Result.verdict } else { 'no result' }), ($skipped -join ', '), $(if ($missing.Count) { ' - MISSING ' + ($missing -join ', ') } else { '' }))

            # (c) underpinningKnowledge cut to 200 words fails naming the floor
            $lowPath = Join-Path $tmpSpine ('low_' + $cleanName)
            $j = Get-GateJson -Path $cleanPath
            $words = @(((AsArr $j.underpinningKnowledge) -join ' ') -split '\s+' | Where-Object { $_ })
            $j.underpinningKnowledge = @(($words | Select-Object -First 200) -join ' ')
            [System.IO.File]::WriteAllText($lowPath, ($j | ConvertTo-Json -Depth 100), (New-Object System.Text.UTF8Encoding $false))
            #  the plant must be renamed to a legal spine name or naming fails first
            $lowSpine = Join-Path $tmpBuild 'spine_low'
            New-Item -ItemType Directory -Force -Path $lowSpine | Out-Null
            Move-Item -LiteralPath $lowPath -Destination (Join-Path $lowSpine $cleanName)
            $lowPath = Join-Path $lowSpine $cleanName
            $landed = (Count-BlockWords (Get-GateJson -Path $lowPath).underpinningKnowledge)
            if ($landed -gt 200) { Record 'floor plant' $false ('the plant did not land: underpinning knowledge still counts {0} words' -f $landed) }
            else {
                $c = Invoke-Child @{ File = $lowPath; ContractPath = (Join-Path $tmpBuild 'contract.json') }
                $rx = '(?i)underpinning knowledge is \d+ words, floor is {0}' -f $script:SubjectFloor
                $named = @(AsArr $c.Result.failures | Where-Object { $_ -match $rx })
                $ok = ($c.Code -eq 1 -and $named.Count -eq 1)
                Record 'floor plant' $ok ('cut to {0} words; exit {1}; {2}' -f $landed, $c.Code, $(if ($named.Count) { $named[0] } else { 'the floor was NOT named' }))
            }

            # (d) a planted non-ASCII character fails naming the offset
            $badSpine = Join-Path $tmpBuild 'spine_bad'
            New-Item -ItemType Directory -Force -Path $badSpine | Out-Null
            $badPath = Join-Path $badSpine $cleanName
            $raw = Get-GateFileText -Path $cleanPath
            $m = [regex]::Match($raw, '"title"\s*:\s*"')
            if (-not $m.Success) { $m = [regex]::Match($raw, '"[A-Za-z]+"\s*:\s*"') }
            $plantAt = $m.Index + $m.Length
            $planted = $raw.Substring(0, $plantAt) + [string][char]0x2019 + $raw.Substring($plantAt)
            [System.IO.File]::WriteAllText($badPath, $planted, (New-Object System.Text.UTF8Encoding $false))
            $check = Get-GateFileText -Path $badPath
            $hit = [regex]::Match($check, '[^\x09\x0A\x0D\x20-\x7E]')
            if (-not $hit.Success) { Record 'charset plant' $false 'the plant did not land: the written file is still pure ASCII' }
            else {
                $c = Invoke-Child @{ File = $badPath; ContractPath = (Join-Path $tmpBuild 'contract.json') }
                $rx = 'non-ASCII.*offset {0} \(line \d+, col \d+\) U\+2019' -f $hit.Index
                $named = @(AsArr $c.Result.failures | Where-Object { $_ -match $rx })
                $ok = ($c.Code -eq 1 -and $named.Count -eq 1)
                Record 'charset plant' $ok ('U+2019 planted at offset {0}; exit {1}; {2}' -f $hit.Index, $c.Code, $(if ($named.Count) { $named[0] } else { 'the offset was NOT named' }))
            }

            # (e) an invalid sibling in the same spine directory does not fail this file
            $sibPc = ''
            foreach ($pc in $script:pcTopic.Keys) { if ($pc -ne $refIdent.Pc) { $sibPc = $pc; break } }
            $sibName = 't{0}_{1}.json' -f $script:pcTopic[$sibPc], $sibPc
            $sibPath = Join-Path $tmpSpine $sibName
            [System.IO.File]::WriteAllText($sibPath, '{ "half": "written by another agent", ', (New-Object System.Text.UTF8Encoding $false))
            $sibInvalid = $false
            try { $null = (Get-GateFileText -Path $sibPath) | ConvertFrom-Json } catch { $sibInvalid = $true }
            if (-not $sibInvalid) { Record 'invalid sibling' $false 'the plant did not land: the sibling parsed' }
            else {
                $c = Invoke-Child @{ File = $cleanPath; BuildDir = $tmpBuild }
                $ok = ($c.Code -eq 0 -and $null -ne $c.Result -and $c.Result.verdict -eq 'PASS')
                Record 'invalid sibling' $ok ('{0} beside it is invalid JSON; -File on the clean copy: exit {1}, verdict {2}' -f $sibName, $c.Code, $(if ($c.Result) { $c.Result.verdict } else { 'no result' }))

                #  and the whole-spine run on the SAME directory must see it - otherwise
                #  the sibling is not invisible to -File, it is invisible full stop.
                $c2 = Invoke-Child @{ BuildDir = $tmpBuild }
                $seen = @(AsArr $c2.Result.failures | Where-Object { $_ -like ('{0} is not valid JSON*' -f $sibName) })
                $ok2 = ($c2.Code -eq 1 -and $seen.Count -eq 1)
                Record 'whole-spine sees sibling' $ok2 ('exit {0}; {1}' -f $c2.Code, $(if ($seen.Count) { $seen[0] } else { 'the invalid sibling was NOT reported' }))
                Remove-Item -LiteralPath $sibPath -Force -ErrorAction SilentlyContinue
            }

            # (f) FRONT MATTER (P0-11). deckframe.json had never been text-gated
            #     by anything. A non-ASCII byte planted in it must fail the
            #     whole-spine run and NAME THE FILE - a curly quote is invisible
            #     on the page and breaks the ASCII-only build path.
            $dfPath = Join-Path $tmpSpine 'deckframe.json'
            if (-not (Test-Path -LiteralPath $dfPath)) { Record 'deckframe charset plant' $false 'the fixture has no deckframe.json, so this case proves nothing' }
            else {
                $dfRaw = Get-GateFileText -Path $dfPath
                #  Planted INSIDE a JSON string value, so the file still parses
                #  and the charset sweep is the only thing that can catch it.
                #  ONE occurrence: the 4-argument [regex]::Replace STATIC takes
                #  RegexOptions, not a count, so passing 1 there means
                #  IgnoreCase and replaces every match (98 quotes, not one).
                #  The instance method is the one that counts.
                $dfRx = New-Object System.Text.RegularExpressions.Regex '"([A-Za-z][A-Za-z ]{3,})"'
                $dfBad = $dfRx.Replace($dfRaw, ('"$1' + [char]0x2019 + '"'), 1)
                [System.IO.File]::WriteAllText($dfPath, $dfBad, (New-Object System.Text.UTF8Encoding $false))
                $dfBack = Get-GateFileText -Path $dfPath
                $dfHit = [regex]::Match($dfBack, '[^\x09\x0A\x0D\x20-\x7E]')
                $dfParses = $true
                try { $null = $dfBack | ConvertFrom-Json } catch { $dfParses = $false }
                if (-not $dfHit.Success) { Record 'deckframe charset plant' $false 'the plant did not land: deckframe.json carries no non-ASCII character' }
                elseif (-not $dfParses) { Record 'deckframe charset plant' $false 'the plant broke the JSON, so a parse failure would mask the charset arm' }
                else {
                    $c3 = Invoke-Child @{ BuildDir = $tmpBuild }
                    $named = @(AsArr $c3.Result.failures | Where-Object { $_ -like 'deckframe.json*' -and $_ -match 'non-ASCII' })
                    $ok3 = ($c3.Code -eq 1 -and $named.Count -ge 1)
                    Record 'deckframe charset plant' $ok3 ('U+2019 planted in deckframe.json at offset {0}; exit {1}; {2}' -f $dfHit.Index, $c3.Code, $(if ($named.Count) { $named[0] } else { 'deckframe.json was NOT named' }))
                }
                #  Put it back, so the front-matter arm of any later case reads
                #  a clean file.
                [System.IO.File]::WriteAllText($dfPath, $dfRaw, (New-Object System.Text.UTF8Encoding $true))
            }
        }
        finally {
            if ($tmpBuild -and (Test-Path -LiteralPath $tmpBuild) -and $tmpBuild.Length -gt 12) {
                Remove-Item -LiteralPath $tmpBuild -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        $bad = @($cases.ToArray() | Where-Object { -not $_.ok })
        $verdict = if ($bad.Count -eq 0) { 'PASS' } else { 'FAIL' }
        $exitCode = if ($bad.Count -eq 0) { 0 } else { 4 }
        if (-not $Quiet) {
            if ($exitCode -eq 0) { Write-Host ('  self-test: {0} of {0} cases passed. This gate can fail.' -f $cases.Count) -ForegroundColor Green }
            else { Write-Host ('  X self-test: {0} of {1} cases FAILED. Do not trust a green from this gate until they pass.' -f $bad.Count, $cases.Count) -ForegroundColor Red }
        }
        $stBody = [ordered]@{}
        $stBody['file']        = [string]$refPath
        $stBody['sha256']      = ''
        $stBody['mode']        = 'selftest'
        $stBody['verdict']     = [string]$verdict
        $stBody['failures']    = @($bad | ForEach-Object { '{0}: {1}' -f $_.name, $_.detail })
        $stBody['warnings']    = @()
        $stBody['skippedArms'] = @()
        $stBody['cases']       = $cases.ToArray()   # never @() a List[object] of PSCustomObjects on PS 5.1
        $stBody['contract']    = [string]$contractUsed
        $stBody['checkedAt']   = (Get-Date).ToString('o')
        $stBody['exitCode']    = [int]$exitCode
        Write-Result -Path $ResultPath -Body $stBody
        exit $exitCode
    }

    # =======================================================================
    # FILE MODE - one file, nothing globbed
    # =======================================================================
    if ($File) {
        if (-not (Test-Path -LiteralPath $File)) { throw ('{0}: file not found: {1}' -f $GATE, $File) }
        $sf1 = Read-SpineFile -Path $File
        $resultFile = $sf1.Path
        $resultHash = $sf1.Sha256
        $fileHashes.Add([pscustomobject]@{ file = $sf1.Name; sha256 = $sf1.Sha256 })
        $ident = Get-SpineFileIdentity -Name $sf1.Name
        Add-Info ('file: {0} (sha256 {1})' -f $sf1.Path, $sf1.Sha256.Substring(0, 12).ToLower())

        if ($null -eq $ident) {
            Add-Ran 'parse'
            Test-Charset -Sf $sf1
            Add-Fail ('{0} does not match the spine file naming t{{T}}_topic.json or t{{T}}_{{PC}}.json, so nothing can be checked against the contract' -f $sf1.Name)
        }
        else {
            $r = Test-OneFile -Sf $sf1 -Ident $ident
            if ($null -ne $r) {
                if ($r.Kind -eq 'sub') {
                    Add-Info ('{0}: underpinning knowledge {1} words; contributes {2} words of counted prose to topic {3}' -f $r.Pc, $r.Uk, $r.Prose, $r.Topic)
                    Add-Info ('{0}: {1} reference(s) prepared; visuals {2} Route A (generated) and {3} Route B (built natively); {4} slide(s)' -f $r.Pc, $r.Refs.Count, $r.RouteA, $r.RouteB, $r.Slides.Count)
                }
                else {
                    Add-Info ('topic {0}: overview {1} words; {2} topic-level slide(s)' -f $r.Topic, $r.OverviewWords, $r.Slides.Count)
                }
            }
        }

        #  The arms this run did NOT prove, each with the reason. A wrapper or
        #  a reader must be able to see that a per-file PASS is a partial one.
        Add-Skip 'structure'    'needs every file the contract names; only this file was read'
        Add-Skip 'floor-topic'  ('the {0}-word topic floor sums this file with its sibling sub-sections and the topic overview; decided on the whole-spine run' -f $script:TopicFloor)
        Add-Skip 'xref-once'    'prepared-exactly-once and prepared-nowhere need every sub-section; this run proved only that this file''s refs equal its questionMap entry'
        Add-Skip 'slides-topic' ('the {0}-slide floor, the figures slide and the assessment-link slide are counted across the topic file and every sub-section of the topic' -f $script:SlideFloorN)
        if ($null -ne $ident -and $ident.Kind -eq 'topic') {
            foreach ($a in @('boxes', 'floor-subject', 'xref-file', 'visuals')) { Add-Skip $a 'not applicable to a topic file' }
        }
        elseif ($null -ne $ident) {
            Add-Skip 'topic-fields' 'not applicable to a sub-section file'
        }
    }

    # =======================================================================
    # WHOLE-SPINE MODE - enumerate from the contract, then look for strangers
    # =======================================================================
    else {
        if (-not $SpineDir) {
            if (-not $BuildDir) { throw ('{0}: pass -BuildDir (spine\ is discovered under it) or -SpineDir with -ContractPath.' -f $GATE) }
            $SpineDir = Join-Path $BuildDir 'spine'
        }
        if (-not (Test-Path -LiteralPath $SpineDir)) { throw ('{0}: no spine directory at {1}' -f $GATE, $SpineDir) }
        $SpineDir = (Resolve-Path -LiteralPath $SpineDir).Path
        $resultFile = $SpineDir

        $topics = @{}
        $subs = @{}
        $expectedNames = New-Object System.Collections.Generic.List[string]

        # --- the registry names every file; a missing one is named, not discovered
        Add-Ran 'structure'
        foreach ($t in $expectTopics) {
            $n = [int]$t.n
            $names = New-Object System.Collections.Generic.List[string]
            $names.Add(('t{0}_topic.json' -f $n))
            foreach ($pc in (AsArr $t.pcs)) { $names.Add(('t{0}_{1}.json' -f $n, $pc)) }
            foreach ($name in $names) {
                $expectedNames.Add($name)
                $p = Join-Path $SpineDir $name
                if (-not (Test-Path -LiteralPath $p)) {
                    if ($name -like '*_topic.json') { Add-Fail ('topic {0} has no {1}' -f $n, $name) }
                    else { Add-Fail ('PC {0} has no sub-section file ({1})' -f ($name -replace '^t\d+_(.+)\.json$', '$1'), $name) }
                    continue
                }
                $sfx = Read-SpineFile -Path $p
                $fileHashes.Add([pscustomobject]@{ file = $sfx.Name; sha256 = $sfx.Sha256 })
                $r = Test-OneFile -Sf $sfx -Ident (Get-SpineFileIdentity -Name $sfx.Name)
                if ($null -eq $r) { continue }
                if ($r.Kind -eq 'topic') { $topics[$n] = $r } else { $subs[$r.Pc] = $r }
            }
        }

        # --- strangers: spine files the contract did not name
        foreach ($f in (Get-ChildItem -LiteralPath $SpineDir -Filter 't*_*.json' -File | Sort-Object Name)) {
            if ($expectedNames -contains $f.Name) { continue }
            $sfx = Read-SpineFile -Path $f.FullName
            $fileHashes.Add([pscustomobject]@{ file = $sfx.Name; sha256 = $sfx.Sha256 })
            $id = Get-SpineFileIdentity -Name $f.Name
            if ($null -eq $id) { Add-Warn ('{0} does not match the expected spine file naming' -f $f.Name); continue }
            $r = Test-OneFile -Sf $sfx -Ident $id
            if ($null -eq $r) { continue }
            if ($r.Kind -eq 'sub' -and -not $subs.ContainsKey($r.Pc)) { $subs[$r.Pc] = $r }
        }
        Add-Info ('spine: {0} topic file(s), {1} sub-section file(s)' -f $topics.Count, $subs.Count)

        # --- topic word floor
        Add-Ran 'floor-topic'
        foreach ($t in $expectTopics) {
            $n = [int]$t.n
            $words = 0
            if ($topics.ContainsKey($n)) { $words += $topics[$n].OverviewWords }
            foreach ($pc in (AsArr $t.pcs)) { if ($subs.ContainsKey([string]$pc)) { $words += $subs[[string]$pc].Prose } }
            if ($words -lt $script:TopicFloor) { Add-Fail ('topic {0} counted prose is {1} words, floor is {2}' -f $n, $words, $script:TopicFloor) }
            else { Add-Info ('topic {0}: {1} words of counted prose' -f $n, $words) }
        }

        # --- every reference prepared exactly once, none nowhere
        Add-Ran 'xref-once'
        $seen = @{}
        foreach ($pc in ($subs.Keys | Sort-Object)) {
            foreach ($r in $subs[$pc].Refs) {
                if ($seen.ContainsKey($r)) { Add-Fail ("'{0}' is prepared in both {1} and {2} - a reference has exactly one home" -f $r, $seen[$r], $pc) }
                else { $seen[$r] = $pc }
            }
        }
        foreach ($r in $script:expectedRefs) { if (-not $seen.ContainsKey($r)) { Add-Fail ("'{0}' is prepared nowhere" -f $r) } }
        if ($seen.Count -eq $script:expectedRefs.Count -and -not @($script:fail | Where-Object { $_ -like '*prepared*' }).Count) {
            Add-Info 'every assessment reference is prepared exactly once'
        }

        $routeA = 0; $routeB = 0
        foreach ($pc in $subs.Keys) { $routeA += $subs[$pc].RouteA; $routeB += $subs[$pc].RouteB }
        Add-Info ('visuals: {0} Route A (generated) and {1} Route B (built natively)' -f $routeA, $routeB)

        # --- slides per topic
        Add-Ran 'slides-topic'
        $slideTotal = 0
        foreach ($t in $expectTopics) {
            $n = [int]$t.n
            $slides = New-Object System.Collections.Generic.List[object]
            if ($topics.ContainsKey($n)) { foreach ($s in $topics[$n].Slides) { $slides.Add($s) } }
            foreach ($pc in (AsArr $t.pcs)) { if ($subs.ContainsKey([string]$pc)) { foreach ($s in $subs[[string]$pc].Slides) { $slides.Add($s) } } }
            $slideTotal += $slides.Count
            if ($slides.Count -lt $script:SlideFloorN) { Add-Fail ('topic {0} has {1} slide(s); the floor is {2}' -f $n, $slides.Count, $script:SlideFloorN) }
            else { Add-Info ('topic {0}: {1} slides' -f $n, $slides.Count) }
            $hasFigures = $false; $hasLink = $false
            foreach ($s in $slides) {
                if ($null -eq $s) { continue }
                if ([string]$s.kind -eq 'figures') { $hasFigures = $true }
                if ([string]$s.kind -eq 'assessment-link') { $hasLink = $true }
            }
            if (-not $hasFigures) { Add-Warn ("topic {0} has no 'figures' layout slide carrying its key numbers" -f $n) }
            if (-not $hasLink)    { Add-Fail ('topic {0} has no assessment-link slide' -f $n) }
        }
        Add-Info ('slides authored on the spine: {0} (framing slides are additional)' -f $slideTotal)

        # ===================================================================
        # FRONT MATTER (P0-11)
        #
        # 56,737 bytes of front.json, cover.json and deckframe.json were never
        # parse- or charset-checked by anything, and deckframe.json's nine
        # frame slides had never been text-gated at all. The FILE SET comes
        # from Get-GateSpineFiles -IncludeFrontMatter; the FIELDS come from the
        # renderers themselves, AST-scanned at run time for front. / cover. /
        # deckframe. member accesses - never from a list typed here, which
        # would be a second source of truth free to drift from the renderer it
        # is meant to describe.
        # ===================================================================
        Add-Ran 'front-matter'
        #  The Lib-GateCommon roster, for the three arms this gate can size
        #  honestly. Test-Spine's own ranArms/skippedArms record stays: it is
        #  finer-grained and it is what the wrapper reads.
        Reset-GateArmRoster
        Register-GateArm -Name 'spine-files' -Blocking
        Register-GateArm -Name 'front-matter-files' -Blocking
        Register-GateArm -Name 'front-matter-fields' -Blocking
        Write-GateCheckSet -What 'contract-named spine file(s) read' -Count $fileHashes.Count -DerivedFrom 'the contract topics and their performance criteria' -Blocking -Input ($SpineDir + ' - the contract names topics and not one of their files could be read')
        Complete-GateArm -Name 'spine-files' -State 'ran' -Size $fileHashes.Count

        $fmBuild = if ($BuildDir) { $BuildDir } else { Split-Path -Parent $SpineDir }
        $fmAll = @(Get-GateSpineFiles -BuildDir $fmBuild -SpineDir $SpineDir -IncludeFrontMatter -Exclude @())
        #  Front matter is what the contract does NOT name: a file whose name
        #  carries no topic or PC identity.
        $fmFiles = @($fmAll | Where-Object { $null -eq (Get-SpineFileIdentity -Name $_.Name) })
        $fmRead = Get-SpineFrontMatterReadField -SkillDir $script:SkillDirForRenderers
        $fmFieldTotal = 0
        foreach ($k in @($fmRead.Fields.Keys)) { $fmFieldTotal += @($fmRead.Fields[$k]).Count }

        Write-GateCheckSet -What 'front-matter file(s) swept (parse, charset, and the fields the renderers read)' -Count $fmFiles.Count -DerivedFrom 'Get-GateSpineFiles -IncludeFrontMatter, less every file the contract names' -Blocking -Input ($SpineDir + " - not one front-matter file (front.json, cover.json, deckframe.json) is on the spine, so the guide's first page and the deck's frame slides are gated by nobody")
        Write-GateCheckSet -What 'front-matter field name(s) the renderers read' -Count $fmFieldTotal -DerivedFrom ('the AST of ' + ((@($fmRead.Sources)) -join ', ') + ', scanned for front. / cover. / deckframe. member accesses') -Blocking -Input ('the renderer scripts (' + ((@($fmRead.Sources)) -join ', ') + ") - not one front-matter field access could be read out of them, so the field arm would compare every file against nothing")
        Complete-GateArm -Name 'front-matter-files' -State 'ran' -Size $fmFiles.Count
        Complete-GateArm -Name 'front-matter-fields' -State 'ran' -Size $fmFieldTotal

        foreach ($fm in $fmFiles) {
            $sfm = Read-SpineFile -Path $fm.FullName
            $fileHashes.Add([pscustomobject]@{ file = $sfm.Name; sha256 = $sfm.Sha256 })
            #  Parse and charset, the same two sweeps every sub-section gets.
            Test-Charset -Sf $sfm
            if ($sfm.ParseError) { Add-Fail ('{0} is not valid JSON: {1}' -f $sfm.Name, $sfm.ParseError); continue }
            $want = @($fmRead.Fields[$sfm.Name])
            if ($want.Count -eq 0) { Add-Warn ('{0}: no renderer names a field on it, so nothing here can say what it must carry' -f $sfm.Name); continue }
            $have = @($sfm.Json.PSObject.Properties.Name)
            $present = @($want | Where-Object { $have -contains $_ })
            $absent = @($want | Where-Object { $have -notcontains $_ })
            if ($present.Count -eq 0) {
                Add-Fail ('{0} carries none of the {1} field(s) the renderers read from it ({2}); it is on the spine and nothing on the page can come from it' -f $sfm.Name, $want.Count, (($want | Select-Object -First 8) -join ', '))
            }
            else {
                Add-Info ('{0}: {1} of {2} renderer-read field(s) present' -f $sfm.Name, $present.Count, $want.Count)
                if ($absent.Count -gt 0) { Add-Warn ('{0}: {1} field(s) a renderer reads are absent ({2})' -f $sfm.Name, $absent.Count, (($absent | Select-Object -First 8) -join ', ')) }
            }
        }

        # --- one hash over everything that was read, name order, so a wrapper
        #     can tell whether the spine it acts on is the spine that passed
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $lines = @($fileHashes | Sort-Object file | ForEach-Object { '{0}:{1}' -f $_.file, $_.sha256 })
            $resultHash = [BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($lines -join "`n")))).Replace('-', '')
        }
        finally { $sha.Dispose() }
    }

    if (-not $File) {
        Assert-GateArmsComplete
        $script:armRoster = Write-GateArmRoster
    }

    if ($script:fail.Count -gt 0) { $verdict = 'FAIL'; $exitCode = 1 }
}
catch {
    #  The library's two typed refusals - an empty blocking check-set, and a
    #  blocking arm never completed - are named as refusals, not as generic
    #  validator errors, so a reader can tell an absent input from a broken one.
    $msg = $_.Exception.Message

    #  ASK THE FILESYSTEM BEFORE BELIEVING THE EXCEPTION. A throw that arrives
    #  after the work is done - a teardown, a temp directory another process
    #  still holds, a child run whose result file is already written - is not
    #  evidence that nothing was produced. Word finished an export and died at
    #  COM teardown, and the finisher reported FAILED while a correct 383-page
    #  PDF sat on disk. So every artefact this run writes is read back off disk
    #  here and reported beside the exception: whether it exists, how many
    #  bytes it carries and whether it still parses. The verdict below stays
    #  ERROR - a validator that threw did not finish its checks - but the
    #  reader is told which of the two they have, instead of being left to
    #  assume that a throw means nothing was written.
    $onDisk = New-Object System.Collections.Generic.List[string]
    foreach ($art in @([string]$ResultPath, [string]$script:SelfTestBuild)) {
        if (-not "$art".Trim()) { continue }
        if (-not (Test-Path -LiteralPath $art)) {
            $onDisk.Add(('{0} - not on disk, so nothing was written before the exception' -f $art))
            continue
        }
        $item = Get-Item -LiteralPath $art -ErrorAction SilentlyContinue
        if ($null -eq $item) { continue }
        if ($item.PSIsContainer) {
            $kids = @(Get-ChildItem -LiteralPath $art -Filter '*.json' -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 0 })
            $onDisk.Add(('{0} - {1} non-empty JSON file(s) written under it before the exception' -f $art, $kids.Count))
        }
        else {
            $parses = $null -ne (Get-GateJson -Path $art)
            $onDisk.Add(('{0} - {1} byte(s) on disk and it {2}' -f $art, $item.Length, $(if ($parses) { 'still parses as JSON' } else { 'does NOT parse' })))
        }
    }

    if ($msg -match '^(CHECK-SET EMPTY|ARMS INCOMPLETE)') { Add-Fail ('REFUSED - {0}' -f $msg) }
    else { Add-Fail ('validator error: {0}' -f $msg) }
    foreach ($d in $onDisk) { Add-Info ('after the exception, the filesystem says: {0}' -f $d) }
    $verdict = 'ERROR'
    $exitCode = 2
}

#  Built one key at a time into an ordered dictionary, and every List[object]
#  of PSCustomObjects goes through .ToArray(): in PS 5.1, @() over such a
#  list throws "Argument types do not match" - reproduced on this machine
#  with a one-element list - while List[string] and JSON arrays are fine.
$body = [ordered]@{}
$body['file']            = [string]$resultFile
$body['sha256']          = [string]$resultHash
$body['mode']            = [string]$mode
$body['verdict']         = [string]$verdict
$body['failures']        = @($script:fail)
$body['warnings']        = @($script:warn)
$body['skippedArms']     = $script:skip.ToArray()
$body['ranArms']         = @($script:ran)
$body['infos']           = @($script:info)
$body['files']           = $fileHashes.ToArray()
$body['arms']            = @($script:armRoster)
$body['contract']        = [string]$contractUsed
$body['questionPattern'] = [string]$script:QuestionPattern
$body['floors']          = $floorsUsed
$body['checkedAt']       = (Get-Date).ToString('o')
$body['exitCode']        = [int]$exitCode
Write-Result -Path $ResultPath -Body $body

$leaf = if ($resultFile) { [System.IO.Path]::GetFileName($resultFile) } else { '(no file)' }
$title = if ($mode -eq 'file') { ('SPINE VALIDATION - one file: {0}' -f $leaf) } else { 'SPINE VALIDATION - whole spine' }
Write-Report -Title $title -Verdict $verdict
exit $exitCode
