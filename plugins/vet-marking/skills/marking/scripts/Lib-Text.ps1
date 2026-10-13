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

# ------------------------------- the assessor's own voice --------------------
#
# SETTLED BY THE RTO ON 30 SEPTEMBER 2026. Everything the ledger carries in
# prose — tool feedback, task comments, feedback items, observation points, row
# notes, the marking record comment — is written BY the trainer/assessor who
# signs the record. So it never talks about that trainer from the outside:
# "Your trainer confirmed that you completed the practical" is the assessor
# describing themselves in the third person, and reads as if someone else had
# vouched for the observation.
#
# Write as the trainer is writing: "You completed the four practical activities
# under my supervision", "I observed you isolate the sander", or, in a
# third-person record, "Observed under supervision on the day".
#
# The patterns catch the trainer or assessor as the one confirming, observing or
# noting, and 'your trainer' / 'your assessor' anywhere. They leave alone a
# student reporting TO the trainer ("reported the leads to the trainer"), which
# is something the student did.
$script:ASSESSOR_ASIDE = @(
    '(?i)\b(your|the|a|his|her|their)\s+(trainer\s*/\s*assessor|trainer\s+or\s+assessor|trainer\s+and\s+assessor|trainer|assessor)\s+(has\s+|had\s+|have\s+)?(confirmed|confirms|observed|observes|watched|noted|notes|saw|verified|checked|agreed|recorded|reported|advised|witnessed|signed)\b',
    '(?i)\b(confirmed|observed|witnessed|verified|noted|recorded|watched|signed\s+off)\s+by\s+(your|the|a)\s+(trainer\s*/\s*assessor|trainer|assessor)\b',
    '(?i)\byour\s+(trainer\s*/\s*assessor|trainer|assessor)\b',
    "(?i)\bthe\s+(trainer|assessor)'s\s+(confirmation|observation|record)\b"
)

function Test-AssessorVoice {
    <#
      Returns a failure message for every place where assessor-written text
      refers to the trainer or assessor in the third person, or an empty array.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [string]$Where = 'assessor text'
    )
    $out = @()
    $seen = @()    # spans already reported; 'Your trainer confirmed' is one fault, not two
    foreach ($rx in $script:ASSESSOR_ASIDE) {
        foreach ($m in [regex]::Matches("$Text", $rx)) {
            if (@($seen | Where-Object { $m.Index -lt $_[1] -and ($m.Index + $m.Length) -gt $_[0] }).Count -gt 0) { continue }
            $seen += ,@($m.Index, ($m.Index + $m.Length))
            $out += "${Where}: '$($m.Value)' — the trainer is the one writing this. Write as the trainer ('under my supervision', 'I observed you', 'Observed on the day'), never about the trainer in the third person."
        }
    }
    @($out)
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

# THE SAME NOTICE FOR A STUDENT WHO SUBMITTED NOTHING. The wording above says
# the submission has been received, marked and retained, and that no further
# attempt is required. Sent to a student who submitted nothing, every one of
# those sentences is false, and the student is told they need do nothing while
# their assessment is still outstanding. This variant withholds the result for
# the same reason and still asks for the work.
$script:WITHHELD_NOTICE_NOSUB = @'
ASSESSMENT OUTCOME: RESULT WITHHELD — PREREQUISITE NOT YET MET

No assessment has been received from you for {UNIT}, so there is no evidence to mark. The items above tell you what to submit and by when.

Your result also cannot be finalised or recorded at this stage because {UNIT} has a mandatory prerequisite unit, {PREREQS}, and our records do not show {THISUNIT} as completed. This prerequisite is set by the training package and applies to all students; {PROVIDER} is not able to record, report or issue a result for this unit until it is met.

What you need to do — both of the following:

1. Submit your completed assessment for {UNITCODE} by the resubmission date shown above.
2. Complete {PREREQCODES} with {PROVIDER}, or apply for credit transfer where you have already completed {PREREQCODES} with another registered training organisation. Credit transfer needs a Statement of Attainment, qualification testamur, or authenticated USI/VET transcript. We are not able to accept other forms of evidence. Contact {ADMINNAME} to arrange either.

What happens next: Once your assessment has been submitted and marked, and the prerequisite is recorded as achieved, your result for {UNITCODE} will be released.

Please note the withheld outcome is not a "not yet competent" outcome. It records that we cannot yet release a result, whatever your evidence shows.

If you would like to discuss this or believe our records are incorrect, contact {ADMINFULL}. You may also request a review under {PROVIDER}'s Complaints and Appeals Policy.

Assessor: {ASSESSOR} | Date: {DATE}
'@

function Get-WithheldNoticeTemplate {
    # -NoSubmission picks the variant that does not claim work was received.
    param([switch]$NoSubmission)
    if ($NoSubmission) { $script:WITHHELD_NOTICE_NOSUB } else { $script:WITHHELD_NOTICE }
}
function Get-WithheldNoticeHeading  { 'ASSESSMENT OUTCOME: RESULT WITHHELD' }

function Build-WithheldNotice {
    <#
      The approved notice with its fields filled, as one string of lines.

      IT IS BUILT IN ONE PLACE because it goes to a student in two: page one of
      a marked copy where work comes back, and the standalone Student Feedback
      Sheet where none does. A student whose result is withheld and who
      submitted nothing would otherwise read the letters RW and no reason for
      them, which is the one thing on the page they could act on.
    #>
    param(
        [Parameter(Mandatory)]$Student,
        [Parameter(Mandatory)]$Ledger,
        [Parameter(Mandatory)]$Rto
    )
    $notMet = @($Student.prerequisitesNotMet)
    if ($notMet.Count -eq 0) {
        throw "$($Student.fullName): overall is RW but no unmet prerequisite is recorded, so the withheld notice cannot name one."
    }
    $contact = $Rto.studentAdminContact
    if (-not $contact -or -not $contact.name) {
        throw "RTO profile declares no studentAdminContact. The withheld notice names it twice and a student must have someone to ask."
    }

    $unitFull    = "{0} – {1}" -f $Ledger.unit.code, $Ledger.unit.title
    $prereqFull  = (@($notMet | ForEach-Object { "{0} – {1}" -f $_.code, $_.title }) -join ', ')
    $prereqCodes = (@($notMet | ForEach-Object { $_.code }) -join ' and ')
    $thisUnit    = if ($notMet.Count -eq 1) { 'this unit' } else { 'these units' }
    # Join only the parts that exist. An RTO that supplies no phone number
    # should not have the notice print a comma hanging off the end of it.
    $adminFull   = (@($contact.name, $contact.email, $contact.phone) |
                    Where-Object { "$_".Trim() -ne '' }) -join ', '

    # Which wording depends on whether anything was actually submitted. A
    # student who submitted nothing must not be told their work is on file and
    # that no further attempt is required.
    $submitted = @($Student.results | Where-Object { $_.submitted -ne $false }).Count
    $notice = Get-WithheldNoticeTemplate -NoSubmission:($submitted -eq 0)
    $notice = $notice.Replace('{UNITCODE}',   $Ledger.unit.code).
                      Replace('{UNIT}',       $unitFull).
                      Replace('{PREREQCODES}',$prereqCodes).
                      Replace('{PREREQS}',    $prereqFull).
                      Replace('{THISUNIT}',   $thisUnit).
                      Replace('{PROVIDER}',   $Rto.rto.tradingName).
                      Replace('{ADMINNAME}',  $contact.name).
                      Replace('{ADMINFULL}',  $adminFull).
                      Replace('{ASSESSOR}',   $Ledger.assessor).
                      Replace('{DATE}',       $Ledger.dates.markingDateText)
    if ($notice -match '\{[A-Z]+\}') {
        throw "$($Student.fullName): the withheld notice still carries an unfilled field."
    }
    $notice
}

function Test-NoticeExempt {
    <#
      True where a line belongs to the approved withheld notice, and is
      therefore outside the two-comma rule. Matched against the notice's own
      skeleton so that editing the notice does not silently widen the exemption.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Line)
    $probe = (("$Line" -replace '\s+', ' ')).Trim()
    if (-not $probe) { return $false }
    $skeleton = ($script:WITHHELD_NOTICE + "`n" + $script:WITHHELD_NOTICE_NOSUB)
    foreach ($tl in ($skeleton -split "`r?`n")) {
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
    $out += @(Test-AssessorVoice -Text $Text -Where $Where)
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
    $out += @(Test-AssessorVoice -Text $Text -Where $Where)
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
    $out += @(Test-AssessorVoice -Text $body -Where $Where)
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

function Get-Ordinal([int]$n) {
    $suffix = if (($n % 100) -in 11, 12, 13) { 'th' } else { switch ($n % 10) { 1 { 'st' } 2 { 'nd' } 3 { 'rd' } default { 'th' } } }
    "$n$suffix"
}

function Build-AttemptChargeNotice {
    <#
      The marking-charge line for a chargeable attempt. RTO ruling, 13 October
      2026: attempt 1 is the first marking and attempts 2 and 3 (Resubmissions
      1 and 2) are free; attempt 4 (Resubmission 3) and every attempt after it
      carries a $150 marking charge. The student is told in red on their
      feedback - page one of the marked copy and the standalone feedback sheet,
      built here so both read the same words. Returns '' where no charge applies.
      The amount and the first chargeable attempt can be set in the RTO profile
      as charges.markingFee and charges.fromAttempt.
    #>
    param([Parameter(Mandatory)]$Student, $Rto)
    $from = 4; $fee = '$150'
    if ($Rto -and $Rto.PSObject.Properties.Name -contains 'charges' -and $Rto.charges) {
        if ($Rto.charges.PSObject.Properties.Name -contains 'fromAttempt' -and $Rto.charges.fromAttempt) { $from = [int]$Rto.charges.fromAttempt }
        if ($Rto.charges.PSObject.Properties.Name -contains 'markingFee' -and $Rto.charges.markingFee) { $fee = "$($Rto.charges.markingFee)" }
    }
    $attempt = 1
    if ($Student.PSObject.Properties.Name -contains 'attempt' -and $Student.attempt) { $attempt = [int]$Student.attempt }
    # One charge only (RTO ruling, 13 Oct 2026: the maximum is $150) - the chargeable attempt and no other.
    if ($attempt -ne $from) { return '' }
    # nothing submitted, nothing marked, nothing charged
    if ($Student.PSObject.Properties.Name -contains 'results' -and @($Student.results).Count -and -not @($Student.results | Where-Object { $_.submitted }).Count) { return '' }
    "A charge of $fee will be applicable for assessment marking of this $(Get-Ordinal $attempt) attempt of assessment."
}