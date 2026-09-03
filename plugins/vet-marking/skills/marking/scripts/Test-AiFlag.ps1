<#
  Test-AiFlag.ps1 — apply the RTO's suspected-AI rule to written responses.

  THE RULE, AS THE RTO WROTE IT: a single sentence containing more than four
  commas flags that response as AI generated. A flagged response is marked NYS,
  listed for redo with the issue 'Response does not appear to be your own work
  — rewrite in your own words', and noted in the SAR feedback and the marking
  record comment.

  The rule is applied to the INDIVIDUAL RESPONSE, never to the whole submission.
  A flag on question 4 does not flag questions 1 to 3.

  A WORD ON WHAT THIS RULE DOES AND DOES NOT MEASURE. Comma count is a proxy
  for sentence complexity, not for authorship. It will flag a student who
  writes a long list — 'I checked the eggs, the flour, the sugar, the butter,
  the milk and the vanilla' is six commas and plainly the student's own work —
  and it will miss generated text written in short sentences. This script
  therefore reports every hit WITH THE SENTENCE THAT TRIGGERED IT, so the
  assessor sees what they are signing rather than a bare verdict. Every flag is
  an assessor decision to confirm or dismiss before it reaches a ledger.
  Confirmed flags go into the ledger's aiFlagged array; dismissed ones do not.

  Usage:
    .\Test-AiFlag.ps1 -Text "<response>" -Label "Q4"
    .\Test-AiFlag.ps1 -Path responses.json          # [{label, text}, ...]
    .\Test-AiFlag.ps1 -DocxPath submission.docx     # every paragraph, numbered
#>
[CmdletBinding()]
param(
    [string]$Text,
    [string]$Label = 'response',
    [string]$Path,
    [string]$DocxPath,
    [int]$MaxCommas = 4,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-Text.ps1')

function Test-Response {
    param([string]$Label, [string]$Text, [int]$MaxCommas)
    $hits = @()
    foreach ($sent in (Split-Sentences $Text)) {
        $n = ([regex]::Matches($sent, ',')).Count
        if ($n -gt $MaxCommas) {
            $hits += [pscustomobject]@{ commas = $n; sentence = $sent }
        }
    }
    [pscustomobject]@{
        label     = $Label
        flagged   = ($hits.Count -gt 0)
        sentences = @($hits)
        issue     = "Response does not appear to be your own work — rewrite in your own words."
    }
}

$responses = @()

if ($Text)     { $responses += [pscustomobject]@{ label = $Label; text = $Text } }
elseif ($Path) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "Not found: $Path" }
    $responses += @(Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json)
}
elseif ($DocxPath) {
    . (Join-Path $PSScriptRoot 'Lib-Docx.ps1')
    $pkg = Open-Docx -Path $DocxPath
    try {
        $i = 0
        foreach ($p in $pkg.Body.SelectNodes('.//w:p', $pkg.Ns)) {
            $t = (Get-RunText $p $pkg.Ns).Trim()
            if ($t.Length -lt 40) { continue }        # headings and labels are not responses
            $i++
            $responses += [pscustomobject]@{ label = "para $i"; text = $t }
        }
    } finally { Close-Docx $pkg }
}
else { throw 'Supply -Text, -Path or -DocxPath.' }

$results = @()
foreach ($r in $responses) { $results += (Test-Response -Label $r.label -Text $r.text -MaxCommas $MaxCommas) }
$flagged = @($results | Where-Object { $_.flagged })

if ($Json) { ,$flagged | ConvertTo-Json -Depth 6; return }

Write-Output ("Checked {0} response(s) at more than {1} commas in one sentence." -f $results.Count, $MaxCommas)
if ($flagged.Count -eq 0) { Write-Output 'No responses flagged.'; return }

Write-Output ''
Write-Output ("{0} response(s) FLAGGED — each needs an assessor decision before it reaches the ledger:" -f $flagged.Count)
foreach ($f in $flagged) {
    Write-Output ''
    Write-Output ("  {0}" -f $f.label)
    foreach ($s in $f.sentences) {
        $q = $s.sentence; if ($q.Length -gt 220) { $q = $q.Substring(0, 220) + '…' }
        Write-Output ("    {0} commas: {1}" -f $s.commas, $q)
    }
}
Write-Output ''
Write-Output 'Confirm or dismiss each one. A confirmed flag makes its tool NYS and is listed'
Write-Output 'for redo; a long list of ingredients in one sentence is not generated text.'
