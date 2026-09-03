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

function Get-FeedbackMaxCommas { $script:FEEDBACK_MAX_COMMAS }
function Get-AuthorshipMaxCommas { $script:AUTHORSHIP_MAX_COMMAS }
