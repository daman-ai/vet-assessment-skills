# Lib-Text.ps1 — sentence splitting and the two comma rules.
#
# THERE ARE TWO COMMA RULES IN THIS SKILL AND THEY ARE NOT THE SAME RULE.
# Someone will eventually try to merge them. Do not.
#
#   THE AUTHORSHIP FLAG        target: the STUDENT'S written response.
#                              limit:  more than 4 commas in one sentence.
#                              effect: flags the response as possibly not the
#                                      student's own work. An assessor confirms
#                                      or dismisses it; a confirmed flag makes
#                                      that tool NYS.
#
#   THE FEEDBACK STYLE RULE    target: what the ASSESSOR writes — SAR feedback,
#                              limit:  no more than 2 commas in one sentence.
#                              effect: blocks the build. Feedback a student
#                                      cannot parse on one reading has not been
#                                      given, whatever the record says.
#
# One reads a student's work to judge it. The other polices our own prose.
# Different targets, different limits, different consequences.

$ErrorActionPreference = 'Stop'

$script:AUTHORSHIP_MAX_COMMAS = 4    # student responses  — more than this flags
$script:FEEDBACK_MAX_COMMAS   = 2    # assessor feedback  — more than this fails

# The marking record comment for a withheld result. ONE definition, used by the
# resolver to write it and by the gate to check the delivered file still says
# it, exactly as 'No submission' is handled. Spaced hyphens throughout.
$script:WITHHELD_COMMENT = 'Result withheld - Prerequisite not completed - Continuing enrolment'
function Get-WithheldComment { $script:WITHHELD_COMMENT }

function Split-Sentences {
    <#
      Splits on . ! ? followed by whitespace, protecting the abbreviations and
      decimals that otherwise chop a sentence in half and hide its comma count.
    #>
    param([string]$Text)
    if (-not $Text) { return @() }

    $DOT = [string][char]0x0001            # sentinel: a dot that does not end a sentence
    $t = $Text -replace '\s+', ' '
    foreach ($abbr in @('e.g.','i.e.','etc.','Dr.','Mr.','Mrs.','Ms.','approx.','No.','vs.')) {
        $t = $t.Replace($abbr, $abbr.Replace('.', $DOT))
    }
    $t = [regex]::Replace($t, '(?<=\d)\.(?=\d)', $DOT)

    [regex]::Split($t, '(?<=[.!?])\s+') |
        ForEach-Object { $_.Replace($DOT, '.').Trim() } |
        Where-Object   { $_ -ne '' }
}

function Get-OverLongSentences {
    <#
      Returns every sentence in $Text carrying more than $MaxCommas commas,
      with its comma count. Used by both rules at their own limits.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][int]$MaxCommas
    )
    $hits = @()
    foreach ($sent in (Split-Sentences $Text)) {
        $n = ([regex]::Matches($sent, ',')).Count
        if ($n -gt $MaxCommas) { $hits += [pscustomobject]@{ commas = $n; sentence = $sent } }
    }
    @($hits)
}

function Test-FeedbackStyle {
    <#
      The feedback style rule. Returns the offending sentences in a piece of
      assessor-written text, or an empty array.

      $Where is a label used in the failure message — 'Daniel Okafor / Knowledge
      Questions feedback' tells the writer which of forty cells to rewrite.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [string]$Where = 'feedback'
    )
    $hits = @(Get-OverLongSentences -Text $Text -MaxCommas $script:FEEDBACK_MAX_COMMAS)
    @(@($hits) | ForEach-Object {
        [pscustomobject]@{
            where    = $Where
            commas   = $_.commas
            sentence = $_.sentence
            fix      = 'Split it. Two short sentences read better than one with three commas.'
        }
    })
}

# ------------------------------- the withheld-result notice ------------------
#
# APPROVED RTO WORDING. It goes on page one of an RW student's marked copy with
# every bracketed field filled from the ledger and the RTO profile.
#
# THE TWO-COMMA RULE DOES NOT APPLY TO IT. That rule polices assessor-written
# feedback, so that a student being asked to act can act on one reading. This is
# standing RTO text, not something an assessor wrote, and several of its
# sentences carry more than two commas. Test-NoticeExempt below is what stops
# someone "fixing" the notice to satisfy a check and changing approved wording in
# the process.
$script:WITHHELD_NOTICE = @'
ASSESSMENT OUTCOME: RESULT WITHHELD — PREREQUISITE NOT YET MET

Your submission for {UNIT} has been received and assessed. Your evidence has been marked and retained on file.

Your result cannot be finalised or recorded at this stage because {UNIT} has a mandatory prerequisite unit, {PREREQS}, and our records do not show {THISUNIT} as completed. This prerequisite is set by the training package and applies to all students; {PROVIDER} is not able to record, report or issue a result for this unit until it is met.

What you need to do — one of the following:

1. Complete {PREREQCODES} with {PROVIDER}. Contact {ADMINNAME} to arrange your enrolment and study plan.
2. If you have already completed {PREREQCODES} with another registered training organisation, apply for credit transfer and provide a copy of your Statement of Attainment, qualification testamur, or authenticated USI/VET transcript. We are not able to accept other forms of evidence.

What happens next: Once the prerequisite is recorded as achieved, your result for {UNITCODE} will be released using the evidence you have already submitted. You do not need to re-submit this assessment. Your work remains on file and no further attempt is required.

Please note this is not a "not yet competent" outcome and does not count as an assessment attempt.

If you would like to discuss this or believe our records are incorrect, contact {ADMINFULL}. You may also request a review under {PROVIDER}'s Complaints and Appeals Policy.

Assessor: {ASSESSOR} | Date: {DATE}
'@

function Get-WithheldNoticeTemplate { $script:WITHHELD_NOTICE }
function Get-WithheldNoticeHeading  { 'ASSESSMENT OUTCOME: RESULT WITHHELD' }

function Test-NoticeExempt {
    <#
      True where a line belongs to the approved withheld notice, and is
      therefore outside the two-comma rule. Matched against the notice's own
      skeleton so that editing the notice does not silently widen the exemption.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Line)
    $probe = (("$Line" -replace '\s+', ' ')).Trim()
    if (-not $probe) { return $false }
    foreach ($tl in ($script:WITHHELD_NOTICE -split "`r?`n")) {
        $t = ($tl -replace '\{[A-Z]+\}', '') -replace '\s+', ' '
        $t = $t.Trim()
        if ($t.Length -lt 25) { continue }
        # compare on the fixed half of the line, ignoring the filled fields
        $head = $t.Substring(0, [Math]::Min(25, $t.Length))
        if ($probe.StartsWith($head, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    $false
}

# ------------------------------- the observation comments standard -----------
#
# references/observation-comments.md is the standard; these are the parts of it a
# machine can hold. ONE definition, used by the resolver to block a build and by
# Test-ObservationComments.ps1 to check a cohort before it reaches a ledger.
#
# Revised by the RTO on 3 September 2026: TWENTY WORDS IS NOW A FLOOR, NOT A
# CEILING. An assessor comment is at least two paragraphs and each paragraph is
# at least twenty words. The old rule capped a paragraph at twenty words, which
# produced comments too thin to stand as a record of what the assessor saw —
# the complaint that prompted the change. The sentence cap rises to three so a
# twenty-word paragraph can be written naturally rather than as one long line,
# and an upper bound stays in place so the box does not become an essay.
#
# Every other part of the standard is unchanged: two commas to a sentence, no
# assessor filler, past tense, third person.

$script:OBS_MAX_SENTENCES_PER_PARA = 4
$script:OBS_MIN_WORDS_PER_PARA     = 20
$script:OBS_MAX_WORDS_PER_PARA     = 70
$script:OBS_PARAGRAPHS             = 2

# Named in the standard, plus the near neighbours of each.
$script:OBS_BANNED = @(
    'demonstrated a sound understanding', 'demonstrated a strong understanding',
    'sound understanding', 'showcased', 'effectively utilised', 'effectively utilized',
    'utilised', 'utilized', 'a high level of', 'in a timely manner', 'went above and beyond'
)
# These comments are a third-person record of what happened.
$script:OBS_PERSON = @('\bI\b', '\bwe\b', '\bour\b', '\byou\b', '\byour\b', '\bmy\b')

function Get-ObservationBannedPhrases { $script:OBS_BANNED }
function Get-ObservationLimits {
    [pscustomobject]@{
        SentencesPerParagraph = $script:OBS_MAX_SENTENCES_PER_PARA
        MinWordsPerParagraph  = $script:OBS_MIN_WORDS_PER_PARA
        MaxWordsPerParagraph  = $script:OBS_MAX_WORDS_PER_PARA
        MinParagraphs         = $script:OBS_PARAGRAPHS
    }
}

function Split-CommentParagraphs {
    param([string]$Body)
    if (-not $Body) { return @() }
    $blocks = [regex]::Split("$Body".Trim(), '(\r?\n)[ \t]*(\r?\n)+')
    $blocks = @($blocks | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' -and $_ -notmatch '^[\r\n]+$' })
    if ($blocks.Count -le 1) {
        $blocks = @("$Body" -split '\r?\n' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    }
    @($blocks)
}

function Test-ObservationCommentStyle {
    <#
      Returns a list of failure messages for one assessor comment, or an empty
      list. The cohort-wide uniqueness rules need every comment in the run at
      once and live in Test-ObservationComments.ps1.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [string]$Where = 'assessor comment'
    )
    $out = @()
    $paras = @(Split-CommentParagraphs $Text)
    if ($paras.Count -lt $script:OBS_PARAGRAPHS) {
        $out += "${Where}: $($paras.Count) paragraph(s); the standard is at least $($script:OBS_PARAGRAPHS)."
    }
    $i = 0
    foreach ($p in $paras) {
        $i++
        $sent = @(Split-Sentences $p)
        if ($sent.Count -gt $script:OBS_MAX_SENTENCES_PER_PARA) {
            $out += "${Where}: paragraph $i has $($sent.Count) sentences, limit is $($script:OBS_MAX_SENTENCES_PER_PARA)."
        }
        $wc = @($p -split '\s+' | Where-Object { $_ -ne '' }).Count
        if ($wc -lt $script:OBS_MIN_WORDS_PER_PARA) {
            $out += "${Where}: paragraph $i has $wc words; the standard is at least $($script:OBS_MIN_WORDS_PER_PARA)."
        }
        if ($wc -gt $script:OBS_MAX_WORDS_PER_PARA) {
            $out += "${Where}: paragraph $i has $wc words, limit is $($script:OBS_MAX_WORDS_PER_PARA)."
        }
        foreach ($h in @(Get-OverLongSentences -Text $p -MaxCommas $script:FEEDBACK_MAX_COMMAS)) {
            $out += "${Where}: paragraph ${i}: $($h.commas) commas in one sentence, limit is $($script:FEEDBACK_MAX_COMMAS)."
        }
    }
    $flat = (("$Text" -replace '[^\p{L}\p{Nd}\s]', ' ') -replace '\s+', ' ').Trim().ToLowerInvariant()
    foreach ($b in $script:OBS_BANNED) {
        $bn = (($b -replace '[^\p{L}\p{Nd}\s]', ' ') -replace '\s+', ' ').Trim().ToLowerInvariant()
        if ($flat -match [regex]::Escape($bn)) { $out += "${Where}: uses '$b' — say what the student did instead." }
    }
    foreach ($rx in $script:OBS_PERSON) {
        if ("$Text" -cmatch $rx) { $out += "${Where}: contains $rx — these comments are past tense and third person." }
    }
    @($out)
}

function Test-AssessorComment {
    <#
      The assessor's written comment on an assessment TOOL or on a TASK within
      one — the paragraphs a student reads on their feedback sheet and an
      auditor reads on the SAR.

      SAME SHAPE AS AN OBSERVATION COMMENT, DIFFERENT VOICE. The length rule is
      shared: at least two paragraphs, at least twenty words each, no more than
      three sentences to a paragraph, two commas to a sentence, and none of the
      filler phrases. What is NOT shared is the person rule. An observation
      comment is a third-person record of what happened — 'Tarnpreet examined
      the drawings'. This one is written TO the student — 'You answered all
      twelve questions' — so the ban on 'you' and 'your' would reject every
      correctly written comment in the skill.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [string]$Where = 'assessor comment'
    )
    $out   = @()
    $paras = @(Split-CommentParagraphs $Text)
    if ($paras.Count -lt $script:OBS_PARAGRAPHS) {
        $out += "${Where}: $($paras.Count) paragraph(s); the standard is at least $($script:OBS_PARAGRAPHS)."
    }
    $i = 0
    foreach ($p in $paras) {
        $i++
        $sent = @(Split-Sentences $p)
        if ($sent.Count -gt $script:OBS_MAX_SENTENCES_PER_PARA) {
            $out += "${Where}: paragraph $i has $($sent.Count) sentences, limit is $($script:OBS_MAX_SENTENCES_PER_PARA)."
        }
        $wc = @($p -split '\s+' | Where-Object { $_ -ne '' }).Count
        if ($wc -lt $script:OBS_MIN_WORDS_PER_PARA) {
            $out += "${Where}: paragraph $i has $wc words; the standard is at least $($script:OBS_MIN_WORDS_PER_PARA)."
        }
        if ($wc -gt $script:OBS_MAX_WORDS_PER_PARA) {
            $out += "${Where}: paragraph $i has $wc words, limit is $($script:OBS_MAX_WORDS_PER_PARA)."
        }
        foreach ($h in @(Get-OverLongSentences -Text $p -MaxCommas $script:FEEDBACK_MAX_COMMAS)) {
            $out += "${Where}: paragraph ${i}: $($h.commas) commas in one sentence, limit is $($script:FEEDBACK_MAX_COMMAS)."
        }
    }
    $flat = (("$Text" -replace '[^\p{L}\p{Nd}\s]', ' ') -replace '\s+', ' ').Trim().ToLowerInvariant()
    foreach ($b in $script:OBS_BANNED) {
        $bn = (($b -replace '[^\p{L}\p{Nd}\s]', ' ') -replace '\s+', ' ').Trim().ToLowerInvariant()
        if ($flat -match [regex]::Escape($bn)) { $out += "${Where}: uses '$b' — say what the student did instead." }
    }
    @($out)
}

$script:OBS_ROWNOTE_MAX_SENTENCES = 2
$script:OBS_ROWNOTE_MAX_WORDS     = 25

function Get-ObservationRowNoteLimits {
    [pscustomobject]@{
        Sentences = $script:OBS_ROWNOTE_MAX_SENTENCES
        Words     = $script:OBS_ROWNOTE_MAX_WORDS
    }
}

function Test-ObservationRowNoteStyle {
    <#
      The comments COLUMN of a column-style observation sheet — one narrow cell
      beside each criterion — takes a note, not the two-paragraph comment an
      'Assessor comments' box takes. A sheet with twenty-eight criteria carries
      twenty-eight of these cells, and holding each to the box standard produces
      a page of padded near-identical prose that says less than one line each
      would.

      So the note keeps every part of the standard that protects the record —
      third person, no assessor filler, the two-comma rule — and drops only the
      shape rule written for a box: one or two sentences, up to twenty-five
      words, no paragraph count.

      Returns a list of failure messages for one note, or an empty list.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [string]$Where = 'observation row note'
    )
    $out  = @()
    $body = "$Text".Trim()
    if (-not $body) { return @("${Where}: empty.") }

    $sent = @(Split-Sentences $body)
    if ($sent.Count -gt $script:OBS_ROWNOTE_MAX_SENTENCES) {
        $out += "${Where}: $($sent.Count) sentences, limit is $($script:OBS_ROWNOTE_MAX_SENTENCES)."
    }
    $wc = @($body -split '\s+' | Where-Object { $_ -ne '' }).Count
    if ($wc -gt $script:OBS_ROWNOTE_MAX_WORDS) {
        $out += "${Where}: $wc words, limit is $($script:OBS_ROWNOTE_MAX_WORDS)."
    }
    foreach ($h in @(Get-OverLongSentences -Text $body -MaxCommas $script:FEEDBACK_MAX_COMMAS)) {
        $out += "${Where}: $($h.commas) commas in one sentence, limit is $($script:FEEDBACK_MAX_COMMAS)."
    }
    $flat = (("$body" -replace '[^\p{L}\p{Nd}\s]', ' ') -replace '\s+', ' ').Trim().ToLowerInvariant()
    foreach ($b in $script:OBS_BANNED) {
        $bn = (($b -replace '[^\p{L}\p{Nd}\s]', ' ') -replace '\s+', ' ').Trim().ToLowerInvariant()
        if ($flat -match [regex]::Escape($bn)) { $out += "${Where}: uses '$b' — say what the student did instead." }
    }
    foreach ($rx in $script:OBS_PERSON) {
        if ("$body" -cmatch $rx) { $out += "${Where}: contains $rx — these notes are past tense and third person." }
    }
    @($out)
}

function Test-LearnerPronouns {
    <#
      The RTO's rule: an assessment record does not call a learner he or she.
      Everything written ABOUT a learner says 'the learner'. Returns the
      offending words, or an empty array.

      This applies to prose written about the learner — observation records,
      criterion comments, checklist comments and notes. It does NOT apply to
      feedback written TO them, which is second person and mentions no third
      party at all.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [string]$Where = 'assessor prose'
    )
    if (-not $Text) { return @() }
    $hits = @()
    foreach ($m in [regex]::Matches($Text, '\b(he|she|his|her|him|hers|himself|herself)\b', 'IgnoreCase')) {
        $from = [math]::Max(0, $m.Index - 40)
        $len  = [math]::Min($Text.Length - $from, 90)
        $hits += [pscustomobject]@{
            where = $Where
            word  = $m.Value
            near  = ($Text.Substring($from, $len) -replace '\s+', ' ')
            fix   = "Write 'the learner'. Name the learner once in the sentence and use plain articles after it."
        }
    }
    $hits
}

function Get-FeedbackMaxCommas { $script:FEEDBACK_MAX_COMMAS }
function Get-AuthorshipMaxCommas { $script:AUTHORSHIP_MAX_COMMAS }
