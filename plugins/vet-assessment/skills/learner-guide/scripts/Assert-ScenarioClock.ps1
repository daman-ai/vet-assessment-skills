<#
    Assert-ScenarioClock.ps1 - can the scenario's own timeline actually happen?

    Implements the gate references\gates.md section 27 specifies. Runs at Stage
    3c as a member of the spine gate band (section 12). Re-runs unchanged
    before every Stage 7 re-render.

    WHAT IT IS FOR. Section 27 records a scenario that places production AFTER
    ITS OWN DELIVERY DEADLINE, with the pack's order form setting that delivery
    for noon on the day the guide has the food being cooked; and one item whose
    production date is given as three different dates across four sections,
    with an internal clash inside one of them. Until this file existed the
    check was performed by the Stage 5 personas and the Stage 6 auditor,
    reading scenario dates against the order form by eye.

    THE BLOCKING ARM IS DELIBERATELY NARROW AND MUST STAY THAT WAY. Attaching
    a free-text time to a subject is where a scenario gate produces noise, so
    only two things block, and both need the item named by its PACK
    IDENTIFIER, which is exact:

      two-production-dates   one pack-identified item carrying two different
                             production dates anywhere on the spine
      production-after-delivery
                             one pack-identified item produced after the
                             delivery time the pack's own order form sets

    EVERYTHING LOOSER REPORTS with its anchor: a date or a time sitting near an
    item without a production verb bound to it, an item whose production date
    falls outside the declared production run, and a stated interval that
    disagrees with a registry duration. Widening the blocking arm to those is
    how this gate stops being acted on.

    A PRODUCTION DATE IS A DATE BOUND TO A PRODUCTION VERB, not a date in the
    same sentence. "You are rostered on the Saturday order ... packed as 30
    individual meal packs" names a day and a production verb and states no
    production date at all; "packed on 11 March 2026" states one. The binding
    window is short and is printed. The production verbs come from the UNIT's
    own cookery methods as the spine records them, plus the general production
    vocabulary - one shared list, widened in one place.

    WHERE THE DELIVERY TIMES COME FROM, AND WHAT IS NEVER READ. The order-form
    schedule is derived from the build contract's scenario block, which the
    contract itself records as taken verbatim from the pack, and from the
    LEARNER-FACING pack documents in the canonical corpus. Assessor-only
    documents are held back by name as well as by the corpus classification,
    because a corpus whose classifier reads every document as learner-facing
    would otherwise pull an assessor guide into a gate. Nothing from any pack
    document is ever printed by this gate: only the derived triples - item,
    day, time - and the name of the document they came from.

    NOTHING HERE IS A LITERAL FROM ONE BUILD. Pack identifiers, delivery times,
    the production week, the cookery methods and the durations are all derived
    from the contract, the corpus, the spine and the figure registry. There is
    no unit code, RTO code, CRICOS code, provider number, hex, item number or
    date written into this file.

    PS 5.1. ASCII only in this file.
    Exit 0 clean, 1 a blocking impossibility, 2 a usage error or an empty
    check-set, 4 the self-test failed.
#>
# GATE: stages=3c; requires=BuildDir

[CmdletBinding()]
param(
    #  Refused by name below rather than declared Mandatory, so -SelfTest can
    #  synthesise its own build: a mandatory parameter made the self-test
    #  unrunnable without a build, and the self-test is the only evidence this
    #  gate discriminates.
    [string] $BuildDir,
    [string] $SpineDir,
    [string] $CorpusDir,
    [string] $RulesPath,
    [string] $ReportPath,
    #  How close a production verb has to sit to a date before the date counts
    #  as that item's PRODUCTION date. Printed on every run. Widening it widens
    #  the blocking arm, which section 27 says not to do without a reason.
    [int] $BindWindow = 24,
    [switch] $SelfTest,
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-GateCommon.ps1')

$GATE = 'Assert-ScenarioClock'

# ---------------------------------------------------------------------------
# THE ONE SHARED PRODUCTION VOCABULARY
# ---------------------------------------------------------------------------

#  Every arm that has to decide whether a sentence is about MAKING something
#  composes this list, and the unit's own cookery methods are appended to it at
#  run time from the spine. Widening it here widens every arm at once; a
#  per-arm list fixes one arm and leaves the rest, which is section 24's
#  documented failure and applies just as hard to this gate.
$script:PRODUCTION = @(
    'produced', 'produce', 'producing', 'production',
    'cooked', 'cook', 'cooking', 'made', 'make', 'making',
    'prepared', 'prepare', 'preparing', 'packed', 'pack', 'packing',
    'chilled', 'chill', 'chilling', 'frozen', 'freeze', 'freezing', 'blast chilled',
    'portioned', 'portion', 'labelled', 'label', 'batched', 'run', 'ran'
)

#  Day names in order, so a day can be compared with a day. English weekday
#  names are a calendar, not a build literal.
$script:DAYNAME = @('monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday')
$script:MONTHNAME = @('january', 'february', 'march', 'april', 'may', 'june', 'july',
                      'august', 'september', 'october', 'november', 'december')

# ---------------------------------------------------------------------------
# Findings
# ---------------------------------------------------------------------------

$script:Findings = New-Object System.Collections.Generic.List[object]
$script:RuleBook = New-Object System.Collections.Generic.List[object]
$script:Suppressed = @{}
$script:SuppressWhy = @{}

function Add-ClkRule {
    param([Parameter(Mandatory)][string] $Name, [Parameter(Mandatory)][string] $Level, [Parameter(Mandatory)][string] $Reason)
    $script:RuleBook.Add([pscustomobject]@{ Rule = $Name; Level = $Level; Reason = $Reason })
}

function Add-ClkFinding {
    param(
        [Parameter(Mandatory)][string] $Rule,
        [Parameter(Mandatory)][string] $Level,
        [Parameter(Mandatory)][string] $Detail,
        $Anchors,
        [string] $Item = '',
        [string] $Extra = ''
    )
    $items = $Anchors
    #  @() OVER A List[object] THROWS. Enumerate, never coerce.
    if ($null -ne $Anchors -and $Anchors -is [System.Collections.Generic.List[object]]) { $items = $Anchors.ToArray() }
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($a in $items) {
        if ($null -eq $a) { continue }
        $rows.Add([pscustomobject]@{
            File = [string]$a.File; Path = [string]$a.Path; Channel = [string]$a.Channel
            Slot = [string]$a.Slot; Surface = [string]$a.Surface; Sentence = [string]$a.Sentence
        })
    }
    $script:Findings.Add([pscustomobject]@{
        Rule = $Rule; Level = $Level; Item = $Item; Detail = $Detail; Extra = $Extra
        Locations = $rows.ToArray(); LocationCount = $rows.Count
    })
}

function Add-ClkSuppression {
    param([Parameter(Mandatory)][string] $Rule, [Parameter(Mandatory)][string] $Reason)
    if (-not $script:Suppressed.ContainsKey($Rule)) { $script:Suppressed[$Rule] = 0 }
    $script:Suppressed[$Rule] = $script:Suppressed[$Rule] + 1
    $script:SuppressWhy[$Rule] = $Reason
}

# ---------------------------------------------------------------------------
# Text and clock
# ---------------------------------------------------------------------------

$script:RxCache = @{}

function Get-ClkRx {
    param([Parameter(Mandatory)][string] $Pattern)
    if (-not $script:RxCache.ContainsKey($Pattern)) {
        $script:RxCache[$Pattern] = New-Object System.Text.RegularExpressions.Regex($Pattern, ([System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Compiled))
    }
    return $script:RxCache[$Pattern]
}

function Get-ClkWordRx {
    <# An unanchored substring match is not a check: an item number sits inside
       a longer number, and "grilling" sits inside "chargrilling". #>
    param([Parameter(Mandatory)][string] $Term)
    $t = $Term.Trim()
    $core = [regex]::Escape($t)
    $lead = ''
    $tail = ''
    if ($t -match '^\w') { $lead = '(?<![\w-])' }
    if ($t -match '\w$') { $tail = '(?![\w-])' }
    return ($lead + $core + $tail)
}

function Split-ClkSentence {
    param([string] $Text)
    if (-not $Text) { return @() }
    $t = ($Text -replace '\s+', ' ').Trim()
    return @([regex]::Split($t, '(?<=[\.\!\?;])\s+(?=[A-Z0-9"''(])') | Where-Object { "$_".Trim().Length -gt 0 })
}

$script:DATE_RX = '(?<abs>(?<dd>\d{1,2})\s+(?<mon>january|february|march|april|may|june|july|august|september|october|november|december)(?:\s+(?<yy>\d{4}))?)|(?<dayname>(?<![\w-])(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)(?![\w-]))'
$script:TIME_RX = '(?<t12>(?<h>\d{1,2})(?::(?<mi>\d{2}))?\s*(?<ap>am|pm))|(?<noon>(?<![\w-])(?:12\s*noon|noon|midday)(?![\w-]))|(?<midnight>(?<![\w-])midnight(?![\w-]))'

function Get-ClkMinutes {
    <# A clock time in minutes past midnight, or -1 when the string has none. #>
    param([string] $Text)
    if (-not $Text) { return -1 }
    $m = (Get-ClkRx -Pattern $script:TIME_RX).Match($Text)
    if (-not $m.Success) { return -1 }
    if ($m.Groups['noon'].Success) { return 720 }
    if ($m.Groups['midnight'].Success) { return 0 }
    $h = [int]$m.Groups['h'].Value
    $mi = 0
    if ($m.Groups['mi'].Success) { $mi = [int]$m.Groups['mi'].Value }
    $ap = $m.Groups['ap'].Value.ToLowerInvariant()
    if ($ap -eq 'pm' -and $h -lt 12) { $h += 12 }
    if ($ap -eq 'am' -and $h -eq 12) { $h = 0 }
    if ($h -gt 23 -or $mi -gt 59) { return -1 }
    return ($h * 60) + $mi
}

function Get-ClkDate {
    <#  A date as a comparable point: a weekday index, and the calendar date
        where the text gives one. A day name alone is still comparable, because
        the whole scenario sits inside one declared production week.  #>
    param([string] $Text, [int] $DefaultYear = 0)
    $m = (Get-ClkRx -Pattern $script:DATE_RX).Match("$Text")
    if (-not $m.Success) { return $null }
    if ($m.Groups['dayname'].Success) {
        $d = $m.Groups['dayname'].Value.ToLowerInvariant()
        return [pscustomobject]@{ Kind = 'day'; DayIndex = ($script:DAYNAME.IndexOf($d) + 1); Iso = ''; Text = $m.Value }
    }
    $dd = [int]$m.Groups['dd'].Value
    $mon = $script:MONTHNAME.IndexOf($m.Groups['mon'].Value.ToLowerInvariant()) + 1
    $yy = $DefaultYear
    if ($m.Groups['yy'].Success) { $yy = [int]$m.Groups['yy'].Value }
    if ($yy -le 0 -or $mon -le 0 -or $dd -le 0 -or $dd -gt 31) { return $null }
    $dt = $null
    try { $dt = New-Object System.DateTime($yy, $mon, $dd) } catch { return $null }
    $wd = [int]$dt.DayOfWeek
    if ($wd -eq 0) { $wd = 7 }
    return [pscustomobject]@{ Kind = 'date'; DayIndex = $wd; Iso = $dt.ToString('yyyy-MM-dd'); Text = $m.Value }
}

function Get-ClkStamp {
    <# The comparable key for a production date: the calendar date where one is
       given, otherwise the weekday inside the declared production week. #>
    param($D)
    if ($null -eq $D) { return '' }
    if ($D.Iso) { return $D.Iso }
    if ($D.DayIndex -ge 1) { return ('weekday-' + $D.DayIndex) }
    return ''
}

# ---------------------------------------------------------------------------
# The scan
# ---------------------------------------------------------------------------

function Complete-ClkArm {
    <#  ran when the arm examined something, empty when it did not. The
        library refuses 'ran' at size 0; an advisory arm may end empty.  #>
    param([Parameter(Mandatory)][string] $Name, [int] $Size, [int] $Findings = 0)
    if ($Size -gt 0) { Complete-GateArm -Name $Name -State ran -Size $Size -Findings $Findings }
    else { Complete-GateArm -Name $Name -State empty -Size 0 }
}

function Invoke-ClkScan {
    param(
        [Parameter(Mandatory)][string] $Build,
        [string] $Spine,
        $Contract,
        $Registry,
        $Deliveries,
        #  arm name -> the contract's written not-applicable reason, from
        #  Get-GateDeclaredNa. Keys read: deliveries, production-dates.
        [hashtable] $DeclaredNa,
        [int] $Window = 24,
        [switch] $Announce
    )

    $script:Findings = New-Object System.Collections.Generic.List[object]
    $script:RuleBook = New-Object System.Collections.Generic.List[object]
    $script:Suppressed = @{}
    $script:SuppressWhy = @{}

    #  THE ARM ROSTER. Every rule below is declared before it runs and ends
    #  ran (N > 0), empty (a refusal, exit 2) or declared-n-a (the contract's
    #  written reason). Reset first: the self-test drives this scan once on a
    #  planted fixture and the real run drives it again in the same process.
    Reset-GateArmRoster
    Register-GateArm -Name 'two-production-dates' -Blocking
    Register-GateArm -Name 'production-after-delivery' -Blocking
    Register-GateArm -Name 'loose-time-attachment'
    Register-GateArm -Name 'outside-production-run'
    Register-GateArm -Name 'interval-vs-registry'
    $na = @{}
    if ($null -ne $DeclaredNa) { foreach ($k in $DeclaredNa.Keys) { $na["$k"] = $DeclaredNa[$k] } }
    #  @($null).Count is 1. The delivery list is normalised once, here.
    $delivList = @()
    if ($null -ne $Deliveries) { $delivList = @($Deliveries | Where-Object { $null -ne $_ }) }

    Add-ClkRule -Name 'two-production-dates' -Level 'BLOCK' -Reason 'one pack-identified item carries two different production dates on the spine'
    Add-ClkRule -Name 'production-after-delivery' -Level 'BLOCK' -Reason 'one pack-identified item is produced after the delivery the pack''s own order form sets for it'
    Add-ClkRule -Name 'loose-time-attachment' -Level 'REPORT' -Reason 'a date or time sits with a pack identifier without a production verb bound to it - the looser attachment section 27 keeps out of the blocking arm'
    Add-ClkRule -Name 'outside-production-run' -Level 'REPORT' -Reason 'a production date falls outside the production week the contract declares'
    Add-ClkRule -Name 'interval-vs-registry' -Level 'REPORT' -Reason 'a stated interval disagrees with a duration the figure registry carries for the same figure'

    # -- pack identifiers, from the contract's own scenario -------------------
    $items = @{}
    if ($null -ne $Contract) {
        $sc = Get-GateProp -Object $Contract -Names @('scenario')
        foreach ($r in @(Get-GateProp -Object $sc -Names @('recipes', 'items', 'products') -Default @())) {
            if ($null -eq $r) { continue }
            $no = [string](Get-GateProp -Object $r -Names @('no', 'number', 'id', 'code') -Default '')
            $nm = [string](Get-GateProp -Object $r -Names @('name', 'title') -Default '')
            if ($no) { $items[$no] = $nm }
        }
    }

    # -- the production week -------------------------------------------------
    $runYear = 0
    $runEnd = $null
    $runStartIdx = 1
    if ($null -ne $Contract) {
        $sc = Get-GateProp -Object $Contract -Names @('scenario')
        $runText = [string](Get-GateProp -Object $sc -Names @('productionRun', 'run', 'week') -Default '')
        $d = Get-ClkDate -Text $runText
        if ($null -ne $d -and $d.Iso) {
            $runEnd = [datetime]::ParseExact($d.Iso, 'yyyy-MM-dd', $null)
            $runYear = $runEnd.Year
        }
    }

    # -- the unit's own cookery methods, appended to the shared list ---------
    $methodWords = New-Object System.Collections.Generic.List[string]
    foreach ($f in (Get-GateSpineFiles -BuildDir $Build -SpineDir $Spine -Exclude @('cover.json', 'deckframe.json'))) {
        $j = Get-GateJson -Path $f.FullName
        if ($null -eq $j) { continue }
        $ar = Get-GateProp -Object $j -Names @('assessmentRequirements')
        if ($null -eq $ar) { continue }
        foreach ($part in @('part1', 'part2')) {
            $p = Get-GateProp -Object $ar -Names @($part)
            if ($null -eq $p) { continue }
            foreach ($it in @(Get-GateProp -Object $p -Names @('items') -Default @())) {
                $t = [string](Get-GateProp -Object $it -Names @('text') -Default '')
                if ($t -and $t.Length -le 24 -and $t -cmatch '^[a-z][a-z\- ]+$') { $methodWords.Add($t.Trim()) }
            }
        }
    }
    $prodWords = @(@($script:PRODUCTION + $methodWords.ToArray()) | Sort-Object -Unique)
    $prodAlt = ($prodWords | ForEach-Object { [regex]::Escape($_) }) -join '|'

    # -- every sentence, with its anchor -------------------------------------
    $skip = @{}
    foreach ($k in (Get-GateUnrenderedFields -BuildDir $Build -ForSweep).Keys) { $skip[$k] = $true }
    $sentences = New-Object System.Collections.Generic.List[object]
    foreach ($f in (Get-GateSpineFiles -BuildDir $Build -SpineDir $Spine -Exclude @('cover.json', 'deckframe.json'))) {
        $j = Get-GateJson -Path $f.FullName
        if ($null -eq $j) { continue }
        foreach ($c in (Get-GateSpineCells -Node $j -File $f.Name -Path '' -Channel '' -Slot '' -Skip $skip)) {
            $surface = 'guide'
            if ([string]$c.Channel -eq 'slides') { $surface = 'deck' }
            foreach ($s in (Split-ClkSentence -Text ([string]$c.Text))) {
                $sentences.Add([pscustomobject]@{
                    File = $c.File; Path = $c.Path; Channel = $c.Channel; Slot = $c.Slot
                    Surface = $surface; Sentence = $s
                })
            }
        }
    }

    if ($Announce -and -not $Quiet) {
        Write-Host ''
        Write-Host 'SCENARIO CLOCK - can the timeline the scenario states actually happen?' -ForegroundColor Cyan
    }
    #  THE BLOCKING CHECK-SETS PRINT ON EVERY RUN, quiet or not, and an empty
    #  one throws CHECK-SET EMPTY naming its input, which the top-level catch
    #  maps to exit 2. Until this existed the pack-identifier case exited 2 by
    #  hand and the delivery case printed 'a gap in the inputs, not a pass' and
    #  then exited 0 - which every runner recorded as a pass.
    Write-GateCheckSet -What 'pack identifiers' -Count $items.Count -DerivedFrom 'the build contract''s own scenario block' -Blocking -Input 'contract.json scenario.items (or recipes / products), each carrying an id, no, number or code'
    Write-GateCheckSet -What 'production verbs' -Count $prodWords.Count -DerivedFrom ("the one shared list in this script plus " + $methodWords.Count + " cookery method(s) the spine records from the unit") -Blocking -Input 'the shared production vocabulary in this script'
    Write-GateCheckSet -What 'authored sentences' -Count $sentences.Count -DerivedFrom 'every string of every spine file' -Blocking -Input 'the spine (no authored string in any spine file)'
    #  The delivery arm: an empty schedule is a refusal UNLESS the contract
    #  declares the arm not applicable with a written reason, in which case the
    #  arm ends declared-n-a and the gate can still pass.
    $deliveriesApply = $true
    if ($delivList.Count -eq 0 -and $na.ContainsKey('deliveries') -and $na['deliveries']) {
        $deliveriesApply = $false
        Write-Host ("  check-set: 0 order-form deliveries - DECLARED NOT APPLICABLE by contract.json gateArms.Assert-ScenarioClock.deliveries: {0}" -f $na['deliveries']) -ForegroundColor Yellow
        Complete-GateArm -Name 'production-after-delivery' -State declared-n-a -Reason $na['deliveries']
    }
    else {
        Write-GateCheckSet -What 'order-form deliveries' -Count $delivList.Count -DerivedFrom 'the contract scenario and the LEARNER-FACING pack documents only' -Blocking -Input 'an item-bound delivery: a line in a LEARNER-FACING corpus document (or contract.json scenario.outlets) naming exactly one pack identifier with a day and a clock time - or contract.json gateArms.Assert-ScenarioClock.deliveries declared applicable:false with a written reason'
    }
    if ($Announce -and -not $Quiet) {
        if ($null -ne $runEnd) { Write-Host ("  production run: the week ending {0} (weekday index 1 = Monday)" -f $runEnd.ToString('yyyy-MM-dd')) -ForegroundColor DarkGray }
        else { Write-Host '  ! the contract declares no production run, so the outside-the-run report arm cannot run' -ForegroundColor Yellow }
        Write-Host ("  production-verb binding window: {0} characters between the verb and the date" -f $Window) -ForegroundColor DarkGray
        foreach ($d in $delivList) {
            Write-Host ("    delivery: item {0} -> day {1} at {2} (from {3})" -f $d.Item, $d.DayIndex, $d.Minutes, $d.Source) -ForegroundColor DarkGray
        }
    }

    # -- attach dates and times to pack-identified items ---------------------
    #  A PRODUCTION date is a date BOUND to a production verb. The binding is a
    #  short window with the verb first, so "packed on 11 March 2026" is a
    #  production date and "rostered on the Saturday order ... packed as 30
    #  individual meal packs" is not - the second names a day and a verb and
    #  states no production date at all. Without the binding this arm reports
    #  every scenario sentence that happens to mention a weekday.
    $bindRx = '(?<v>(?<![\w-])(?:' + $prodAlt + ')(?![\w-]))(?<gap>[^.;]{0,' + $Window + '}?)(?:' + $script:DATE_RX + ')'
    $explicitRx = '(?:production|packing|cooking|freezing|chilling)\s+date\s+(?:of|is|was|:)?\s*(?:' + $script:DATE_RX + ')'

    $prodDates = @{}
    $loose = New-Object System.Collections.Generic.List[object]
    $itemSentences = 0
    foreach ($s in $sentences) {
        $txt = [string]$s.Sentence
        $here = New-Object System.Collections.Generic.List[string]
        foreach ($id in $items.Keys) {
            if ((Get-ClkRx -Pattern (Get-ClkWordRx -Term $id)).IsMatch($txt)) { $here.Add($id) }
        }
        if ($here.Count -eq 0) { continue }
        $itemSentences++

        #  ONE SENTENCE, TWO ITEMS, ONE DATE BINDS TO NEITHER. "Thursday's
        #  curry, recipe A, and the ratatouille, recipe B, in the same session"
        #  states Thursday for one of them, and a gate that gives it to both
        #  has invented a production date. Attaching a free-text time to a
        #  subject is exactly where section 27 says the noise lives, so a
        #  multi-item sentence reports and never blocks.
        if ($here.Count -gt 1) {
            if ((Get-ClkRx -Pattern $script:DATE_RX).IsMatch($txt) -or (Get-ClkRx -Pattern $script:TIME_RX).IsMatch($txt)) {
                Add-ClkSuppression -Rule 'two-production-dates/multiple-items-in-sentence' -Reason 'the sentence names more than one pack item, so which item the date belongs to is not exact; the blocking arm needs the item named by its pack identifier AND the date bound to it, so this reports with its anchor instead'
                $loose.Add([pscustomobject]@{ At = $s; Items = $here.ToArray() })
            }
            continue
        }

        $bound = New-Object System.Collections.Generic.List[object]
        foreach ($rx in @($explicitRx, $bindRx)) {
            foreach ($m in (Get-ClkRx -Pattern $rx).Matches($txt)) {
                #  "the week ending <date>" NAMES THE RUN, NOT A PRODUCTION
                #  DAY. Every scenario sentence in a build like this one
                #  carries the run week, so without this the run's own end date
                #  becomes a second production date for every item in the pack.
                if ($m.Groups['gap'].Success -and $m.Groups['gap'].Value -match '(?i)week\s+(ending|commencing|beginning|starting|of)\s*$') {
                    Add-ClkSuppression -Rule 'two-production-dates/run-week-is-not-a-production-date' -Reason 'the date is the end of the production week the contract declares, named as the window the work sits in, not the day the item was made'
                    continue
                }
                $d = Get-ClkDate -Text $m.Value -DefaultYear $runYear
                if ($null -eq $d) { continue }
                $stamp = Get-ClkStamp -D $d
                if (-not $stamp) { continue }
                $already = $false
                foreach ($b in $bound) { if ($b.Stamp -eq $stamp) { $already = $true; break } }
                if (-not $already) { $bound.Add([pscustomobject]@{ Stamp = $stamp; Date = $d; Match = $m.Value; Minutes = (Get-ClkMinutes -Text $txt) }) }
            }
        }

        if ($bound.Count -eq 0) {
            #  A date or a time near an item with no production verb bound to
            #  it. Reported with its anchor, never blocked.
            if ((Get-ClkRx -Pattern $script:DATE_RX).IsMatch($txt) -or (Get-ClkRx -Pattern $script:TIME_RX).IsMatch($txt)) {
                $loose.Add([pscustomobject]@{ At = $s; Items = $here.ToArray() })
            }
            continue
        }

        foreach ($id in $here) {
            if (-not $prodDates.ContainsKey($id)) { $prodDates[$id] = New-Object System.Collections.Generic.List[object] }
            foreach ($b in $bound) {
                $prodDates[$id].Add([pscustomobject]@{ Stamp = $b.Stamp; Date = $b.Date; Minutes = $b.Minutes; At = $s; Match = $b.Match })
            }
        }
        if ($bound.Count -gt 1) {
            #  Section 27 records "an internal clash inside one of them" - two
            #  production dates inside a single sentence.
            $stamps = @($bound | ForEach-Object { $_.Stamp } | Sort-Object -Unique)
            if ($stamps.Count -gt 1) {
                Add-ClkFinding -Rule 'two-production-dates' -Level 'BLOCK' -Anchors @($s) -Item ($here -join ', ') `
                    -Detail ("one sentence gives {0} different production dates for {1}: {2}" -f $stamps.Count, ($here -join ', '), ($stamps -join ' vs ')) `
                    -Extra ((@($bound | ForEach-Object { $_.Match })) -join ' | ')
            }
        }
    }

    foreach ($l in $loose) {
        Add-ClkFinding -Rule 'loose-time-attachment' -Level 'REPORT' -Anchors @($l.At) -Item (($l.Items) -join ', ') `
            -Detail 'a date or a time sits beside a pack identifier with no production verb bound to it'
    }
    Complete-ClkArm -Name 'loose-time-attachment' -Size $itemSentences -Findings $loose.Count

    #  ITEMS CARRYING A BOUND PRODUCTION DATE are the check-set BLOCK 1 runs
    #  over. An empty one is a refusal naming the spine - never the green line
    #  this gate printed while zero items were being compared - unless the
    #  contract declares the arm not applicable with a written reason.
    $productionApply = $true
    $naProd = ''
    foreach ($k in @('production-dates', 'two-production-dates')) { if ($na.ContainsKey($k) -and $na[$k]) { $naProd = $na[$k]; break } }
    if ($prodDates.Count -eq 0 -and $naProd) {
        $productionApply = $false
        Write-Host ("  check-set: 0 pack items carrying a bound production date - DECLARED NOT APPLICABLE by contract.json gateArms.Assert-ScenarioClock.production-dates: {0}" -f $naProd) -ForegroundColor Yellow
        Complete-GateArm -Name 'two-production-dates' -State declared-n-a -Reason $naProd
    }
    else {
        Write-GateCheckSet -What 'pack items carrying a production date bound to a production verb' -Count $prodDates.Count -DerivedFrom ("{0} sentence(s) naming a pack identifier, a production verb within {1} characters of a date" -f $itemSentences, $Window) -Blocking -Input ('the spine: no sentence binds a production verb to a date within ' + $Window + ' characters of a pack identifier (' + $items.Count + ' identifier(s) declared, ' + $itemSentences + ' sentence(s) name one) - or contract.json gateArms.Assert-ScenarioClock.production-dates declared applicable:false with a written reason')
    }

    # -- BLOCK 1: two production dates for one item --------------------------
    if ($productionApply) {
    foreach ($id in ($prodDates.Keys | Sort-Object)) {
        $rows = $prodDates[$id]
        $stamps = @($rows | ForEach-Object { $_.Stamp } | Sort-Object -Unique)
        if ($stamps.Count -lt 2) { continue }
        #  A WEEKDAY AND A CALENDAR DATE THAT FALL ON THAT WEEKDAY ARE ONE
        #  DATE. "Thursday" and "12 March 2026" are the same production day
        #  written two ways when the twelfth is a Thursday, and blocking on
        #  that would fire on a guide that names the day and then dates it.
        $days = @{}
        foreach ($r in $rows) { $days[[string]$r.Date.DayIndex] = $true }
        if ($days.Count -lt 2) {
            Add-ClkSuppression -Rule 'two-production-dates/same-weekday' -Reason 'the differing stamps all fall on one weekday of the declared production run - a weekday named in one place and dated in another is one production day written two ways'
            continue
        }
        $anchors = @()
        foreach ($r in $rows) { $anchors += $r.At }
        Add-ClkFinding -Rule 'two-production-dates' -Level 'BLOCK' -Anchors $anchors -Item $id `
            -Detail ("pack item {0} carries {1} different production dates: {2}" -f $id, $stamps.Count, ($stamps -join ' vs ')) `
            -Extra ("item name: " + [string]$items[$id])
    }
    Complete-GateArm -Name 'two-production-dates' -State ran -Size $prodDates.Count `
        -Findings @($script:Findings | Where-Object { $_.Rule -eq 'two-production-dates' -and $_.Level -eq 'BLOCK' }).Count
    }

    # -- BLOCK 2: produced after the pack's own delivery ---------------------
    if ($deliveriesApply) {
    foreach ($d in $delivList) {
        if (-not $d.Item) { continue }
        if (-not $prodDates.ContainsKey($d.Item)) { continue }
        if ($d.DayIndex -lt 1) { continue }
        foreach ($r in $prodDates[$d.Item]) {
            if ($r.Date.DayIndex -lt 1) { continue }
            $prodKey = ($r.Date.DayIndex * 10000)
            $delKey = ($d.DayIndex * 10000)
            if ($r.Minutes -ge 0) { $prodKey += $r.Minutes }
            if ($d.Minutes -ge 0) { $delKey += $d.Minutes }
            if ($prodKey -le $delKey) { continue }
            #  SAME DAY WITH NO CLOCK TIME ON ONE SIDE IS NOT AN IMPOSSIBILITY.
            #  Food produced on the morning of the day it is delivered at noon
            #  is the normal case, and a comparison that has a time on only one
            #  side cannot tell the two apart.
            if ($r.Date.DayIndex -eq $d.DayIndex -and ($r.Minutes -lt 0 -or $d.Minutes -lt 0)) {
                Add-ClkSuppression -Rule 'production-after-delivery/no-clock-on-one-side' -Reason 'production and delivery fall on the same day and only one of them carries a clock time, so nothing here establishes that production came later'
                continue
            }
            Add-ClkFinding -Rule 'production-after-delivery' -Level 'BLOCK' -Anchors @($r.At) -Item $d.Item `
                -Detail ("pack item {0} is produced on day {1}{2} and the order form sets its delivery for day {3}{4}" -f `
                        $d.Item, $r.Date.DayIndex, $(if ($r.Minutes -ge 0) { " at minute $($r.Minutes)" } else { '' }), `
                        $d.DayIndex, $(if ($d.Minutes -ge 0) { " at minute $($d.Minutes)" } else { '' })) `
                -Extra ("delivery source: " + $d.Source + " | production phrase: " + $r.Match)
        }
    }
    Complete-GateArm -Name 'production-after-delivery' -State ran -Size $delivList.Count `
        -Findings @($script:Findings | Where-Object { $_.Rule -eq 'production-after-delivery' -and $_.Level -eq 'BLOCK' }).Count
    }

    # -- REPORT: outside the declared production run -------------------------
    $datedRows = 0
    if ($null -ne $runEnd) {
        $runStart = $runEnd.AddDays(-6)
        foreach ($id in ($prodDates.Keys | Sort-Object)) {
            foreach ($r in $prodDates[$id]) {
                if (-not $r.Date.Iso) { continue }
                $datedRows++
                $dt = [datetime]::ParseExact($r.Date.Iso, 'yyyy-MM-dd', $null)
                if ($dt -ge $runStart -and $dt -le $runEnd) { continue }
                Add-ClkFinding -Rule 'outside-production-run' -Level 'REPORT' -Anchors @($r.At) -Item $id `
                    -Detail ("pack item {0} is produced on {1}, outside the declared run week {2} to {3}" -f $id, $r.Date.Iso, $runStart.ToString('yyyy-MM-dd'), $runEnd.ToString('yyyy-MM-dd'))
            }
        }
    }
    Complete-ClkArm -Name 'outside-production-run' -Size $datedRows -Findings @($script:Findings | Where-Object { $_.Rule -eq 'outside-production-run' }).Count

    # -- REPORT: a stated interval against a registry duration ---------------
    $durations = New-Object System.Collections.Generic.List[object]
    if ($null -ne $Registry) {
        foreach ($f in @(Get-GateProp -Object $Registry -Names @('figures') -Default @())) {
            if ($null -eq $f) { continue }
            $name = [string](Get-GateProp -Object $f -Names @('name') -Default '')
            foreach ($rq in @(Get-GateProp -Object $f -Names @('require') -Default @())) {
                $v = "$rq"
                $m = [regex]::Match($v, '(?i)(?<lead>[a-z][a-z ]{0,24}?)?\s*(?<n>\d+(?:\.\d+)?)\s*(?<u>hours?|minutes?|days?|weeks?|months?)(?![\w-])')
                if (-not $m.Success) { continue }
                $lead = ''
                if ($m.Groups['lead'].Success) { $lead = $m.Groups['lead'].Value.Trim().ToLowerInvariant() }
                if (-not $lead) { continue }
                $durations.Add([pscustomobject]@{
                    Figure = $name; Lead = $lead; N = [double]$m.Groups['n'].Value
                    Unit = ($m.Groups['u'].Value.ToLowerInvariant() -replace 's$', '')
                    Require = $v
                })
            }
        }
    }
    if ($Announce -and -not $Quiet) {
        Write-GateCheckSet -What 'registry durations' -Count $durations.Count -DerivedFrom 'the figure registry''s own required values'
    }
    foreach ($du in $durations) {
        $rx = '(?<![\w-])' + [regex]::Escape($du.Lead) + '\s+(?<n>\d+(?:\.\d+)?)\s*' + [regex]::Escape($du.Unit) + 's?(?![\w-])'
        foreach ($s in $sentences) {
            foreach ($m in (Get-ClkRx -Pattern $rx).Matches([string]$s.Sentence)) {
                $n = [double]$m.Groups['n'].Value
                if ($n -eq $du.N) { continue }
                Add-ClkFinding -Rule 'interval-vs-registry' -Level 'REPORT' -Anchors @($s) `
                    -Detail ("this states '{0} {1} {2}' where the registry carries '{3}'" -f $du.Lead, $n, $du.Unit, $du.Require) `
                    -Extra ("registry figure: " + $du.Figure)
            }
        }
    }
    Complete-ClkArm -Name 'interval-vs-registry' -Size $durations.Count -Findings @($script:Findings | Where-Object { $_.Rule -eq 'interval-vs-registry' }).Count

    return [pscustomobject]@{
        Findings = $script:Findings.ToArray()
        Rules = $script:RuleBook.ToArray()
        Suppressed = $script:Suppressed
        SuppressWhy = $script:SuppressWhy
        CheckSets = [pscustomobject]@{
            items = $items.Count
            sentences = $sentences.Count
            deliveries = $delivList.Count
            itemSentences = $itemSentences
            productionVerbs = $prodWords.Count
            durations = $durations.Count
            itemsWithProductionDate = $prodDates.Count
            bindWindow = $Window
        }
    }
}

# ---------------------------------------------------------------------------
# The order-form schedule, from the pack - never from an assessor guide
# ---------------------------------------------------------------------------

function Get-ClkDeliveries {
    <#  Item, day and time, from the contract's scenario and from the
        LEARNER-FACING pack documents only.

        THE ASSESSOR GUARD IS DELIBERATE AND BELT-AND-BRACES. The shared
        corpus classifier falls back to a filename pattern, and a build whose
        assessor guides are named in some other convention has every document
        classified learner-facing. This gate never prints pack text at all -
        only the derived triple and the document's name - but a gate that
        could read an assessor guide is a gate that must be told not to.  #>
    param(
        [Parameter(Mandatory)][string] $Build,
        [string] $Corpus,
        $Contract,
        [hashtable] $Items
    )

    $out = New-Object System.Collections.Generic.List[object]
    $sources = New-Object System.Collections.Generic.List[string]
    $held = New-Object System.Collections.Generic.List[string]

    $year = 0
    $destinations = New-Object System.Collections.Generic.List[object]
    if ($null -ne $Contract) {
        $sc = Get-GateProp -Object $Contract -Names @('scenario')
        $d = Get-ClkDate -Text ([string](Get-GateProp -Object $sc -Names @('productionRun') -Default ''))
        if ($null -ne $d -and $d.Iso) { $year = ([datetime]::ParseExact($d.Iso, 'yyyy-MM-dd', $null)).Year }
        foreach ($o in @(Get-GateProp -Object $sc -Names @('outlets', 'destinations') -Default @())) {
            $t = "$o"
            if (-not $t.Trim()) { continue }
            $dd = Get-ClkDate -Text $t -DefaultYear $year
            $mm = Get-ClkMinutes -Text $t
            if ($null -eq $dd -and $mm -lt 0) { continue }
            $idx = -1
            if ($null -ne $dd) { $idx = $dd.DayIndex }
            $destinations.Add([pscustomobject]@{ Text = $t; DayIndex = $idx; Minutes = $mm })
        }
        if ($destinations.Count -gt 0) { $sources.Add('contract.json scenario') }
    }

    $corpusDir = ''
    try { $corpusDir = Get-GateCorpusDir -BuildDir $Build -CorpusDir $Corpus } catch { $corpusDir = '' }
    if ($corpusDir) {
        $docs = Get-GateCorpusDocs -CorpusDir $corpusDir -BuildDir $Build
        foreach ($doc in $docs.Documents) {
            $assessorish = ($doc.Audience -ne 'learner') -or ($doc.Name -match '(?i)(^|[_\-\. ])(ag|assessor|marking|benchmark|answers?)([_\-\. ]|$)')
            if ($assessorish) { $held.Add($doc.Name); continue }
            $sources.Add($doc.Name)
            foreach ($line in ($doc.Text -split "`r?`n")) {
                if (-not "$line".Trim()) { continue }
                $ids = New-Object System.Collections.Generic.List[string]
                foreach ($id in $Items.Keys) {
                    if ((Get-ClkRx -Pattern (Get-ClkWordRx -Term $id)).IsMatch($line)) { $ids.Add($id) }
                }
                if ($ids.Count -ne 1) { continue }
                $dd = Get-ClkDate -Text $line -DefaultYear $year
                $mm = Get-ClkMinutes -Text $line
                if ($null -eq $dd -or $mm -lt 0) { continue }
                $out.Add([pscustomobject]@{ Item = $ids[0]; DayIndex = $dd.DayIndex; Minutes = $mm; Source = $doc.Name })
            }
        }
    }

    #  A destination-level delivery with no item on it cannot bind to an item,
    #  so it is carried for the record rather than used to block.
    return [pscustomobject]@{
        Deliveries = $out.ToArray()
        Destinations = $destinations.ToArray()
        Sources = @($sources.ToArray() | Sort-Object -Unique)
        Held = @($held.ToArray() | Sort-Object -Unique)
        CorpusDir = $corpusDir
    }
}

# ---------------------------------------------------------------------------
# Inputs
# ---------------------------------------------------------------------------

function New-ClkSelfTestBuild {
    <#  A synthetic build the self-test can plant into when no -BuildDir is to
        hand: two pack-identified items, a production run, a spine that binds a
        production verb to a date, and a learner-facing order form that yields
        one item-bound delivery. Hoisted out of the self-test block so
        -SelfTest never needs a real build - a self-test that can only run
        where a build already exists is a self-test that does not run.  #>
    param([Parameter(Mandatory)][string] $Dir)
    $e = New-Object System.Text.UTF8Encoding($true)
    New-Item -ItemType Directory -Force -Path (Join-Path $Dir 'spine') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $Dir 'corpus') | Out-Null
    $contract = [ordered]@{
        build = [ordered]@{ brand = 'fixture'; tradingName = 'Fixture Venue' }
        unit = [ordered]@{ code = 'FIXTURE001' }
        topics = @([ordered]@{ id = 1; title = 'Fixture topic'; pcs = @('1.1', '1.2') })
        scenario = [ordered]@{
            productionRun = 'the week ending 13 March 2026'
            items = @(
                [ordered]@{ id = 'PA'; name = 'planted alpha batch' },
                [ordered]@{ id = 'PB'; name = 'planted beta batch' }
            )
        }
    }
    [System.IO.File]::WriteAllText((Join-Path $Dir 'contract.json'), ($contract | ConvertTo-Json -Depth 40), $e)
    $registry = [ordered]@{ _comment = 'fixture registry'; figures = @([ordered]@{ name = 'Fixture chill window'; authority = 'L'; require = @('2 hours') }) }
    [System.IO.File]::WriteAllText((Join-Path $Dir 'figures.json'), ($registry | ConvertTo-Json -Depth 40), $e)
    foreach ($pc in @('1.1', '1.2')) {
        $sub = [ordered]@{
            ref = ('PC ' + $pc); pc = $pc; topic = 1; title = ('Fixture sub-section ' + $pc)
            #  PA carries a production date, so the blocking arm has a set to
            #  run over. PB deliberately carries NONE: the self-test's own
            #  false-positive control plants one date for a second item, and a
            #  date already sitting here would make that control a real clash.
            underpinningKnowledge = @(
                'The planted batch of recipe PA is cooked on 10 March 2026 in the planted production run.',
                'Recipe PB is one of the planted items the store carries through the run.'
            )
        }
        [System.IO.File]::WriteAllText((Join-Path $Dir ('spine\t1_' + $pc + '.json')), ($sub | ConvertTo-Json -Depth 40), $e)
    }
    #  ONLY PA gets a delivery. PB is the item the self-test's own
    #  false-positive control writes its single correct date on, and an item
    #  carrying a delivery would let the production-after-delivery arm fire on
    #  that control - which would read as the gate blocking correct content.
    [System.IO.File]::WriteAllText((Join-Path $Dir 'corpus\Learner_Order_Form.txt'), "Order form`r`nPA planted alpha batch - deliver Thursday 11 am`r`n", $e)
    return $Dir
}

$clkSynthRoot = ''
if ($SelfTest -and -not $BuildDir) {
    $clkSynthRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('clk-synth-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $BuildDir = New-ClkSelfTestBuild -Dir $clkSynthRoot
    Write-Host ("  {0} -SelfTest with no -BuildDir: a synthetic build was written to {1}" -f $GATE, $clkSynthRoot) -ForegroundColor DarkGray
}
if (-not $BuildDir) {
    Write-Host ("  X {0}: -BuildDir is required (or run with -SelfTest, which synthesises its own build). A scenario clock with no build has no scenario to read." -f $GATE) -ForegroundColor Red
    exit 2
}
if (-not (Test-Path -LiteralPath $BuildDir)) { throw "$GATE`: no build directory at $BuildDir" }
$buildResolved = (Resolve-Path -LiteralPath $BuildDir).Path
$spineResolved = $SpineDir
if (-not $spineResolved) { $spineResolved = Join-Path $buildResolved 'spine' }

$contractJson = Get-GateContract -BuildDir $buildResolved
$registryJson = Get-GateRegistry -BuildDir $buildResolved -RulesPath $RulesPath

if ($null -eq $contractJson) {
    Write-Host ("  X {0}: no build contract, so there are no pack identifiers and no production run. A scenario clock with no identified item passes by having nothing to check." -f $GATE) -ForegroundColor Red
    exit 2
}

$itemMap = @{}
$scen = Get-GateProp -Object $contractJson -Names @('scenario')
foreach ($r in @(Get-GateProp -Object $scen -Names @('recipes', 'items', 'products') -Default @())) {
    if ($null -eq $r) { continue }
    $no = [string](Get-GateProp -Object $r -Names @('no', 'number', 'id', 'code') -Default '')
    if ($no) { $itemMap[$no] = [string](Get-GateProp -Object $r -Names @('name', 'title') -Default '') }
}

$sched = Get-ClkDeliveries -Build $buildResolved -Corpus $CorpusDir -Contract $contractJson -Items $itemMap

if (-not $Quiet) {
    Write-Host ''
    Write-Host ("  order-form sources read: {0}" -f $(if ($sched.Sources.Count) { ($sched.Sources -join ', ') } else { 'none' })) -ForegroundColor $(if ($sched.Sources.Count) { 'DarkGray' } else { 'Yellow' })
    if ($sched.Held.Count) { Write-Host ("  held back as assessor-only, never read: {0}" -f ($sched.Held -join ', ')) -ForegroundColor DarkGray }
    Write-Host ("  destination-level deliveries carried for the record (no item bound): {0}" -f $sched.Destinations.Count) -ForegroundColor DarkGray
}

#  Arms the contract declares NOT APPLICABLE, read through the library from
#  contract.json gateArms.Assert-ScenarioClock.<arm>. A declaration with no
#  written reason throws inside the library; that is a contract defect, named
#  and exited 2 here, never a silent pass.
$declaredNa = @{}
try {
    foreach ($arm in @('deliveries', 'production-dates', 'two-production-dates')) {
        $reason = Get-GateDeclaredNa -BuildDir $buildResolved -Gate $GATE -Arm $arm -Contract $contractJson
        if ($reason) { $declaredNa[$arm] = $reason }
    }
}
catch { Write-Host ("  X {0}: {1}" -f $GATE, $_.Exception.Message) -ForegroundColor Red; exit 2 }

function Write-ClkRefusalReport {
    <# The report a refused run leaves behind: the message, the roster, exit 2. #>
    param([string] $Path, [string] $Message, $Roster)
    $p = [pscustomobject]@{
        gate = $GATE; generatedUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        buildDir = $buildResolved; spineDir = $spineResolved
        refused = $Message; arms = @($Roster); blockingCount = 0; reportCount = 0; exitCode = 2
    }
    [System.IO.File]::WriteAllText($Path, ($p | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding($true)))
}

# ---------------------------------------------------------------------------
# Self-test - plant, VERIFY THE PLANT LANDED, then run the shipping gate
# ---------------------------------------------------------------------------

$selfTestFailed = 0

if ($SelfTest) {
    Write-Host ''
    Write-Host ("  {0} SELF-TEST - a clean result is not believed until the gate has failed on a planted defect" -f $GATE) -ForegroundColor Cyan

    $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("clk-selftest-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null
    try {
        foreach ($n in @('contract.json', 'figures.json')) {
            $src = Join-Path $buildResolved $n
            if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $tmpRoot $n) -Force }
        }
        $tmpSpine = Join-Path $tmpRoot 'spine'
        New-Item -ItemType Directory -Force -Path $tmpSpine | Out-Null
        #  -LiteralPath does NOT expand a wildcard: a copy written that way
        #  moves nothing and the plant lands in an empty fixture.
        foreach ($sf in (Get-ChildItem -LiteralPath $spineResolved -Filter '*.json' -File)) {
            Copy-Item -LiteralPath $sf.FullName -Destination (Join-Path $tmpSpine $sf.Name) -Force
        }

        function Test-ClkPlant {
            param([string] $File, [string] $Needle, [string] $What)
            $txt = Get-GateFileText -Path $File
            if ($txt.IndexOf($Needle, [System.StringComparison]::Ordinal) -ge 0) {
                Write-Host ("    plant landed: {0}" -f $What) -ForegroundColor DarkGray
                return $true
            }
            Write-Host ("    X plant did NOT land: {0} - this proves nothing" -f $What) -ForegroundColor Red
            return $false
        }

        function Set-ClkPlant {
            param([string] $File, [string] $Field, [string[]] $Values)
            $j = Get-GateJson -Path $File
            $cur = @(Get-GateProp -Object $j -Names @($Field) -Default @())
            $new = New-Object System.Collections.Generic.List[object]
            foreach ($x in $cur) { $new.Add($x) }
            foreach ($v in $Values) { $new.Add($v) }
            if (@($j.PSObject.Properties.Name) -contains $Field) { $j.$Field = $new.ToArray() }
            else { $j | Add-Member -NotePropertyName $Field -NotePropertyValue $new.ToArray() }
            [System.IO.File]::WriteAllText($File, ($j | ConvertTo-Json -Depth 40), (New-Object System.Text.UTF8Encoding($true)))
        }

        $subFiles = @(Get-ChildItem -LiteralPath $tmpSpine -Filter '*.json' -File |
                      Where-Object { $_.Name -ne 'front.json' -and $_.Name -ne 'cover.json' -and $_.Name -ne 'deckframe.json' } |
                      Sort-Object Name)
        if ($subFiles.Count -lt 2) { throw "$GATE`: the fixture spine is empty, so nothing could be planted." }
        $victimA = $subFiles[0].FullName
        $victimB = $subFiles[1].FullName
        $plants = New-Object System.Collections.Generic.List[object]

        #  The item, the run week and the delivery all come from the build - no
        #  identifier and no date is written into this file.
        $anItem = @($itemMap.Keys | Sort-Object)[0]
        $runD = Get-ClkDate -Text ([string](Get-GateProp -Object $scen -Names @('productionRun') -Default ''))
        $runEndDt = $null
        if ($null -ne $runD -and $runD.Iso) { $runEndDt = [datetime]::ParseExact($runD.Iso, 'yyyy-MM-dd', $null) }
        if ($null -eq $runEndDt) { $runEndDt = (Get-Date).Date }
        $dayOne = $runEndDt.AddDays(-5)
        $dayTwo = $runEndDt.AddDays(-3)

        #  1. TWO PRODUCTION DATES FOR ONE PACK-IDENTIFIED ITEM.
        $p1 = 'The planted batch of recipe ' + $anItem + ' is cooked on ' + $dayOne.ToString('d MMMM yyyy') + ' in the planted run.'
        $p2 = 'The planted batch of recipe ' + $anItem + ' is cooked on ' + $dayTwo.ToString('d MMMM yyyy') + ' in the planted run.'
        Set-ClkPlant -File $victimA -Field 'underpinningKnowledge' -Values @($p1)
        Set-ClkPlant -File $victimB -Field 'underpinningKnowledge' -Values @($p2)
        $ok1 = (Test-ClkPlant -File $victimA -Needle $p1 -What ('production date one for item ' + $anItem)) -and
               (Test-ClkPlant -File $victimB -Needle $p2 -What ('a different production date for the same item'))
        $plants.Add([pscustomobject]@{ Rule = 'two-production-dates'; Needle = 'planted batch of recipe'; What = 'two production dates for one pack-identified item'; Ok = $ok1 })

        #  2. PRODUCED AFTER THE ORDER FORM'S OWN DELIVERY. The delivery comes
        #     from the pack where the pack yields one. Where it does not, the
        #     fixture SUPPLIES one - noon on the first production day - so the
        #     arm is proved here rather than left UNPROVEN (a self-test that
        #     plants nothing for a blocking arm is the false green rule 4 of
        #     gates.md exists to prevent). The REAL run still refuses on the
        #     real inputs; nothing synthesised here reaches it.
        $delivery = $null
        foreach ($d in $sched.Deliveries) { if ($d.Item -eq $anItem) { $delivery = $d; break } }
        if ($null -eq $delivery -and $sched.Deliveries.Count -gt 0) { $delivery = $sched.Deliveries[0] }
        $probeDeliveries = @($sched.Deliveries)
        if ($null -eq $delivery) {
            $dayOneIdx = [int]((Get-ClkDate -Text $dayOne.ToString('dddd', [System.Globalization.CultureInfo]::InvariantCulture)).DayIndex)
            $delivery = [pscustomobject]@{ Item = $anItem; DayIndex = $dayOneIdx; Minutes = 720; Source = 'synthesised by the self-test: the pack yielded no item-bound delivery' }
            $probeDeliveries = @($delivery)
            Write-Host ("    fixture: the pack yields no item-bound delivery, so one is synthesised for item {0} (weekday {1}, noon) for the probe run only" -f $anItem, $dayOneIdx) -ForegroundColor DarkGray
        }
        $lateDay = $script:DAYNAME[[Math]::Min(6, [Math]::Max(0, $delivery.DayIndex - 1))]
        $lateNeedle = 'The planted late batch of recipe ' + $delivery.Item + ' is cooked on ' + (Get-Culture).TextInfo.ToTitleCase($lateDay) + ' at 11:59 pm, after the order form deadline.'
        Set-ClkPlant -File $victimA -Field 'underpinningKnowledge' -Values @($lateNeedle)
        $ok2 = Test-ClkPlant -File $victimA -Needle $lateNeedle -What ('production after the order form delivery for item ' + $delivery.Item)
        $plants.Add([pscustomobject]@{ Rule = 'production-after-delivery'; Needle = 'planted late batch of recipe'; What = 'an item produced after its own order-form delivery'; Ok = $ok2 })

        #  3. THE CORRECT CASE, which must NOT fire: one item, one production
        #     date, stated twice. It uses a DIFFERENT pack item from the two
        #     planted defects - planting the correct case on an item that is
        #     already carrying a planted contradiction would put the correct
        #     sentence among that finding's anchors and make the gate look as
        #     though it had fired on it.
        $cleanItem = @($itemMap.Keys | Sort-Object)[-1]
        if ($cleanItem -eq $anItem -or ($null -ne $delivery -and $cleanItem -eq $delivery.Item)) {
            foreach ($k in (@($itemMap.Keys | Sort-Object))) {
                if ($k -ne $anItem -and ($null -eq $delivery -or $k -ne $delivery.Item)) { $cleanItem = $k; break }
            }
        }
        $clean = 'The planted compliant batch of recipe ' + $cleanItem + ' is packed on ' + $dayOne.ToString('d MMMM yyyy') + ' and nowhere else.'
        Set-ClkPlant -File $victimA -Field 'underpinningKnowledge' -Values @($clean)
        Set-ClkPlant -File $victimB -Field 'underpinningKnowledge' -Values @($clean)
        [void](Test-ClkPlant -File $victimB -Needle $clean -What ('one item (' + $cleanItem + ') with ONE production date stated twice, which must not fire'))

        $bad = @($plants | Where-Object { -not $_.Ok })
        if ($bad.Count -gt 0) {
            Write-Host ("    X {0} plant(s) did not land. The self-test is void." -f $bad.Count) -ForegroundColor Red
            $selfTestFailed++
        }
        else {
            $probe = Invoke-ClkScan -Build $tmpRoot -Spine $tmpSpine -Contract $contractJson -Registry $registryJson -Deliveries $probeDeliveries -DeclaredNa @{} -Window $BindWindow
            foreach ($p in $plants) {
                $hit = @($probe.Findings | Where-Object {
                    $_.Rule -eq $p.Rule -and $_.Level -eq 'BLOCK' -and
                    @($_.Locations | Where-Object { ([string]$_.Sentence).IndexOf($p.Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 }).Count -gt 0
                })
                if ($hit.Count -gt 0) {
                    Write-Host ("    self-test: {0} -> {1} fired as BLOCKING on the planted timeline ({2} finding(s)). This arm can fail." -f $p.What, $p.Rule, $hit.Count) -ForegroundColor Green
                }
                else {
                    Write-Host ("    X self-test: {0} planted and {1} did NOT fire on it." -f $p.What, $p.Rule) -ForegroundColor Red
                    $selfTestFailed++
                }
            }
            $falsePos = @($probe.Findings | Where-Object {
                $_.Level -eq 'BLOCK' -and
                @($_.Locations | Where-Object { ([string]$_.Sentence).IndexOf('planted compliant batch', [System.StringComparison]::OrdinalIgnoreCase) -ge 0 }).Count -gt 0
            })
            if ($falsePos.Count -eq 0) {
                Write-Host '    self-test: one item with one production date stated twice did NOT fire. Repetition is not a clash.' -ForegroundColor Green
            }
            else {
                Write-Host '    X self-test: one production date stated twice fired as a clash. A gate that blocks on correct content gets switched off.' -ForegroundColor Red
                $selfTestFailed++
            }
        }

        #  REFUSAL PROBES. Each is a CHILD PROCESS on a synthetic fixture, so
        #  the exit code itself is proved and not only the message: a starved
        #  blocking arm exits 2 naming its input, and the declared-not-
        #  applicable path exits 0 printing the arm. Nothing here reads the
        #  build; the fixtures are shapes.
        function New-ClkProbeFixture {
            param([string] $Root, [switch] $NoItems, [switch] $DeclareDeliveriesNa, [switch] $WithDelivery, [switch] $NoProductionDate)
            New-Item -ItemType Directory -Force -Path (Join-Path $Root 'spine') | Out-Null
            $enc = New-Object System.Text.UTF8Encoding($true)
            $contract = [ordered]@{
                build = [ordered]@{ brand = '' }
                scenario = [ordered]@{
                    productionRun = ''
                    items = @(
                        [ordered]@{ id = 'PA'; name = 'planted alpha batch' },
                        [ordered]@{ id = 'PB'; name = 'planted beta batch' }
                    )
                }
            }
            if ($NoItems) { $contract.scenario.items = @() }
            if ($DeclareDeliveriesNa) {
                $contract['gateArms'] = [ordered]@{ 'Assert-ScenarioClock' = [ordered]@{ deliveries = [ordered]@{ applicable = $false; reason = 'This fixture has no timed delivery scenario, so the delivery arm has nothing to read.' } } }
            }
            [System.IO.File]::WriteAllText((Join-Path $Root 'contract.json'), ($contract | ConvertTo-Json -Depth 10), $enc)
            $sentence = 'The planted batch of recipe PA is cooked on Thursday in the planted run.'
            if ($NoProductionDate) { $sentence = 'Recipe PA is popular with the Thursday crowd in the planted run.' }
            $sub = [ordered]@{ ref = '1.1'; pc = '1.1'; topic = 1; title = 'Probe'; underpinningKnowledge = @($sentence) }
            [System.IO.File]::WriteAllText((Join-Path $Root 'spine\t1_1.1.json'), ($sub | ConvertTo-Json -Depth 10), $enc)
            if ($WithDelivery) {
                New-Item -ItemType Directory -Force -Path (Join-Path $Root 'corpus') | Out-Null
                [System.IO.File]::WriteAllText((Join-Path $Root 'corpus\Order_Form.txt'), "Order form`r`nPA planted alpha batch - deliver Thursday 11 am`r`n", $enc)
            }
        }
        function Invoke-ClkProbe {
            param([string] $Build, [int] $ExpectExit, [string[]] $ExpectText, [string] $What)
            $out = ''
            try { $out = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath -BuildDir $Build -Quiet 2>&1 | Out-String) } catch { $out = "$($_.Exception.Message)" }
            $code = $LASTEXITCODE
            $missing = @($ExpectText | Where-Object { $out.IndexOf($_, [System.StringComparison]::OrdinalIgnoreCase) -lt 0 })
            if ($code -eq $ExpectExit -and $missing.Count -eq 0) {
                Write-Host ("    self-test: {0} -> exit {1}, output names {2}" -f $What, $code, (($ExpectText | ForEach-Object { "'" + $_ + "'" }) -join ' and ')) -ForegroundColor Green
            }
            else {
                Write-Host ("    X self-test: {0} -> exit {1} (wanted {2}); not named: {3}" -f $What, $code, $ExpectExit, $(if ($missing.Count) { ($missing -join ' | ') } else { 'nothing' })) -ForegroundColor Red
                $tail = @(($out -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -Last 4)
                foreach ($ln in $tail) { Write-Host ("      | {0}" -f $ln) -ForegroundColor DarkGray }
                $script:selfTestFailed++
            }
        }
        $probeRoot = Join-Path $tmpRoot 'probes'
        $pA = Join-Path $probeRoot 'starved-deliveries'; New-ClkProbeFixture -Root $pA
        Invoke-ClkProbe -Build $pA -ExpectExit 2 -ExpectText @('CHECK-SET EMPTY', 'order-form deliveries', 'item-bound delivery') -What 'a fixture with production dates and no item-bound delivery REFUSES naming the delivery input'
        $pB = Join-Path $probeRoot 'declared-na'; New-ClkProbeFixture -Root $pB -DeclareDeliveriesNa
        Invoke-ClkProbe -Build $pB -ExpectExit 0 -ExpectText @('DECLARED NOT APPLICABLE', 'production-after-delivery|true|declared-n-a') -What 'the same fixture with gateArms.Assert-ScenarioClock.deliveries declared not applicable PASSES printing the arm as declared-n-a'
        $pC = Join-Path $probeRoot 'starved-production'; New-ClkProbeFixture -Root $pC -WithDelivery -NoProductionDate
        Invoke-ClkProbe -Build $pC -ExpectExit 2 -ExpectText @('CHECK-SET EMPTY', 'no sentence binds a production verb') -What 'a fixture with a delivery and no bound production date REFUSES naming the spine'
        $pD = Join-Path $probeRoot 'starved-items'; New-ClkProbeFixture -Root $pD -NoItems
        Invoke-ClkProbe -Build $pD -ExpectExit 2 -ExpectText @('CHECK-SET EMPTY', 'contract.json scenario.items') -What 'a fixture whose contract declares no pack identifier REFUSES naming the contract'

        #  THE CLEAN CONTROL, end to end. A synthesised build with items, a
        #  bound production date and an item-bound delivery must exit 0 with
        #  every blocking arm 'ran' - so the refusals above are shown to be
        #  discrimination and not this gate refusing everything.
        $ctl = Join-Path $probeRoot 'control'
        [void](New-ClkSelfTestBuild -Dir $ctl)
        Invoke-ClkProbe -Build $ctl -ExpectExit 0 -ExpectText @('ARMS: ', 'two-production-dates|true|ran', 'production-after-delivery|true|ran') -What 'a clean synthesised build passes with every blocking arm ran'
    }
    finally {
        if ($tmpRoot -and (Test-Path -LiteralPath $tmpRoot)) { Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue }
        if ($clkSynthRoot -and (Test-Path -LiteralPath $clkSynthRoot)) { Remove-Item -LiteralPath $clkSynthRoot -Recurse -Force -ErrorAction SilentlyContinue }
    }

    #  THE SELF-TEST EXITS ON ITS OWN RESULT. It used to fall through into the
    #  real run, so `-SelfTest` reported the BUILD's exit code: every case here
    #  could pass and the caller would read exit 2 (or 1) and believe the gate
    #  had failed its own self-test. It also wrote a report into the build
    #  under test on the way past.
    Write-Host ''
    if ($selfTestFailed -eq 0) {
        Write-Host '  SELF-TEST PASS - every plant landed and fired, every starved arm refused by name, and the clean control passed with a full roster' -ForegroundColor Green
        exit 0
    }
    Write-Host ("  SELF-TEST FAIL - {0} check(s)" -f $selfTestFailed) -ForegroundColor Red
    exit 4
}

# ---------------------------------------------------------------------------
# The real run
# ---------------------------------------------------------------------------

$result = $null
$roster = @()
try {
    $result = Invoke-ClkScan -Build $buildResolved -Spine $spineResolved -Contract $contractJson -Registry $registryJson -Deliveries $sched.Deliveries -DeclaredNa $declaredNa -Window $BindWindow -Announce
    Assert-GateArmsComplete
    $roster = @(Write-GateArmRoster)
}
catch {
    #  The library's two typed refusals - an empty blocking check-set, and a
    #  blocking arm never completed - are exit 2, printed, with the roster
    #  written into the report. Anything else is a real error and propagates.
    $msg = $_.Exception.Message
    if ($msg -like 'CHECK-SET EMPTY:*' -or $msg -like 'ARMS INCOMPLETE:*') {
        Write-Host ("  X {0}: {1}" -f $GATE, $msg) -ForegroundColor Red
        $roster = @(Write-GateArmRoster)
        $refPath = $ReportPath
        if (-not $refPath) { $refPath = Join-Path $buildResolved 'scenario-clock-report.json' }
        Write-ClkRefusalReport -Path $refPath -Message $msg -Roster $roster
        if ($selfTestFailed -gt 0) {
            Write-Host ("  X {0}: the self-test failed as well, so no result from this run may be believed." -f $GATE) -ForegroundColor Red
            exit 4
        }
        exit 2
    }
    throw
}

$blocking = @($result.Findings | Where-Object { $_.Level -eq 'BLOCK' })
$reported = @($result.Findings | Where-Object { $_.Level -ne 'BLOCK' })

$reportOut = $ReportPath
if (-not $reportOut) { $reportOut = Join-Path $buildResolved 'scenario-clock-report.json' }

$exitCode = 0
if ($selfTestFailed -gt 0) { $exitCode = 4 }
elseif ($blocking.Count -gt 0) { $exitCode = 1 }

$suppressRows = New-Object System.Collections.Generic.List[object]
foreach ($k in ($result.Suppressed.Keys | Sort-Object)) {
    $suppressRows.Add([pscustomobject]@{ Rule = $k; Count = $result.Suppressed[$k]; Reason = $result.SuppressWhy[$k] })
}

$payload = [pscustomobject]@{
    gate = $GATE
    generatedUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    buildDir = $buildResolved
    spineDir = $spineResolved
    spineFingerprint = (Get-SpineFingerprint -BuildDir $buildResolved -SpineDir $spineResolved)
    orderFormSources = $sched.Sources
    orderFormHeldBack = $sched.Held
    declaredNotApplicable = $declaredNa
    checkSets = $result.CheckSets
    arms = $roster
    rules = $result.Rules
    suppressions = $suppressRows.ToArray()
    blockingCount = $blocking.Count
    reportCount = $reported.Count
    blocking = $blocking
    report = $reported
    exitCode = $exitCode
}
[System.IO.File]::WriteAllText($reportOut, ($payload | ConvertTo-Json -Depth 12), (New-Object System.Text.UTF8Encoding($true)))

Write-Host ''
if ($suppressRows.Count -gt 0) {
    Write-Host '  named suppression rules that ran (never an allow-list of values):' -ForegroundColor DarkGray
    foreach ($s in $suppressRows) { Write-Host ("    {0} x{1}: {2}" -f $s.Rule, $s.Count, $s.Reason) -ForegroundColor DarkGray }
}
else { Write-Host '  no named suppression rule fired on this run' -ForegroundColor DarkGray }

if ($reported.Count -gt 0) {
    $byRule = @{}
    foreach ($f in $reported) {
        if (-not $byRule.ContainsKey($f.Rule)) { $byRule[$f.Rule] = 0 }
        $byRule[$f.Rule] = $byRule[$f.Rule] + 1
    }
    Write-Host ''
    Write-Host ("  REPORT ONLY - {0} finding(s), none of which changes the exit code:" -f $reported.Count) -ForegroundColor Yellow
    foreach ($k in ($byRule.Keys | Sort-Object)) { Write-Host ("    {0}: {1}" -f $k, $byRule[$k]) -ForegroundColor Yellow }
    $shown = 0
    foreach ($f in $reported) {
        $shown++
        if ($shown -gt 12) { break }
        $where = ''
        if ($f.LocationCount -gt 0) { $where = "[" + $f.Locations[0].File + "] " + $f.Locations[0].Path }
        Write-Host ("      {0} {1} - {2}" -f $f.Rule, $where, $f.Detail) -ForegroundColor DarkGray
    }
    if ($reported.Count -gt 12) { Write-Host ("      ... and {0} more, all of them in {1}" -f ($reported.Count - 12), $reportOut) -ForegroundColor DarkGray }
}

Write-Host ''
Write-Host ("  complete finding list written to {0}" -f $reportOut) -ForegroundColor DarkGray

if ($selfTestFailed -gt 0) {
    Write-Host ("  X {0}: the self-test failed, so no result from this run may be believed." -f $GATE) -ForegroundColor Red
    exit 4
}

if ($blocking.Count -eq 0) {
    Write-Host ("  no pack-identified item carries an impossible timeline ({0} report-level finding(s) recorded)" -f $reported.Count) -ForegroundColor Green
    exit 0
}

Write-Host ("  X {0} impossible timeline(s)" -f $blocking.Count) -ForegroundColor Red
$shown = 0
foreach ($f in $blocking) {
    $shown++
    if ($shown -gt 25) { break }
    Write-Host ("    {0}: {1}" -f $f.Rule, $f.Detail) -ForegroundColor Red
    if ($f.Extra) { Write-Host ("      {0}" -f $f.Extra) -ForegroundColor DarkGray }
    foreach ($l in @($f.Locations | Select-Object -First 6)) {
        Write-Host ("      [{0}] {1}  ({2})" -f $l.File, $l.Path, $l.Surface) -ForegroundColor Yellow
        Write-Host ("        {0}" -f $l.Sentence) -ForegroundColor DarkGray
    }
    if ($f.LocationCount -gt 6) { Write-Host ("      ... {0} more location(s) in the report" -f ($f.LocationCount - 6)) -ForegroundColor DarkGray }
}
if ($blocking.Count -gt 25) { Write-Host ("    ... and {0} more in {1}" -f ($blocking.Count - 25), $reportOut) -ForegroundColor DarkGray }
Write-Host ''
Write-Host '  Fix every location, not the one the finding named: section 27 records one item whose production' -ForegroundColor Yellow
Write-Host '  date was given as three different dates across four sections, and a round that fixes one leaves two.' -ForegroundColor Yellow
exit 1
