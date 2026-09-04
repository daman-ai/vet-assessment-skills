<#
  New-DocumentRegister.ps1 - Phase 1. Walk a working folder, register every
  document, and scan each one for references to superseded instruments.

  The scan gets FILE facts right and DOCUMENT facts wrong. It cannot reliably
  tell a policy from a procedure, it reads a version out of a filename that may
  be a lie, and it has no idea which entity a document covers. So those three
  fields are guessed once and then never touched again: re-running the scan
  MERGES, keeping every value a human has corrected in the ledger. A rescan that
  overwrote hand corrections would make the register worse each time it ran.

  Usage:
    .\New-DocumentRegister.ps1 -Path <working folder> -Ledger assurance.json
    .\New-DocumentRegister.ps1 -Path <folder> -Ledger assurance.json -UseOffice
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Ledger,
    # Read .pdf, .doc and .xls through Word/Excel COM. Slow. Without it those
    # files are registered with textRead=false rather than scanned as empty.
    [switch]$UseOffice,
    [string]$Markdown,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lib-DocText.ps1')

if (-not (Test-Path -LiteralPath $Path)) { throw "Folder not found: $Path" }
$root = (Resolve-Path -LiteralPath $Path).Path

function Get-RelativePath {
    <#
      Not string arithmetic on $root.Length. A working folder given in 8.3 form
      (ACI-AD~1) resolves short while Get-ChildItem returns children long, the
      prefixes differ in length, and every relative path comes out with a stray
      leading character - which then becomes the document's identity in the
      ledger. Resolve-Path -Relative gets it right from either form.
    #>
    param([string]$Full, [string]$Base)
    Push-Location -LiteralPath $Base
    try { return ((Resolve-Path -LiteralPath $Full -Relative) -replace '^\.[\\/]', '') }
    finally { Pop-Location }
}

$INCLUDE = @('.docx','.docm','.dotx','.doc','.pdf','.rtf','.xlsx','.xlsm','.xls','.pptx','.md','.txt','.csv','.html','.htm')
$SKIPDIR = @('.git','node_modules','deliverables','~$')

# ---------------------------------------------------------------- existing ---

$ledgerObj = $null
if (Test-Path -LiteralPath $Ledger) {
    $ledgerObj = Get-Content -LiteralPath $Ledger -Raw -Encoding UTF8 | ConvertFrom-Json
}
if ($null -eq $ledgerObj) {
    $ledgerObj = [pscustomobject]@{
        engagement = [pscustomobject]@{ name = 'UNNAMED'; runDate = (Get-Date -Format 'yyyy-MM-dd'); phase = 1; preparedBy = 'TODO'; notARegulatoryDetermination = $true }
        entities   = @()
        documents  = @()
        findings   = @()
        treatments = @()
        indicators = @()
        risks      = @()
        decisions  = @()
        assumptions = @()
    }
}
foreach ($k in 'entities','documents','findings','treatments','indicators','risks','decisions','assumptions') {
    if (-not $ledgerObj.PSObject.Properties[$k]) { $ledgerObj | Add-Member -NotePropertyName $k -NotePropertyValue @() }
}

# Index the documents already registered, by relative path.
$existing = @{}
foreach ($d in @($ledgerObj.documents)) { if ($d.file) { $existing[[string]$d.file] = $d } }

# ------------------------------------------------------------------ guesses ---

function Guess-Type {
    param([string]$Name, [string]$Text)
    $n = $Name.ToLowerInvariant()
    if ($n -match 'procedure')                     { return 'procedure' }
    if ($n -match 'policy')                        { return 'policy' }
    if ($n -match 'register|matrix|log\b')         { return 'register' }
    if ($n -match 'template')                      { return 'template' }
    if ($n -match '\bform\b|application|checklist'){ return 'form' }
    if ($n -match 'strategy|plan\b|taps?\b')       { return 'strategy' }
    if ($n -match 'record|minute|report')          { return 'record' }
    if ($Text -match '(?im)^\s*(purpose|scope)\b' -and $Text -match '(?i)responsib') { return 'policy' }
    return 'UNKNOWN'
}

function Guess-Version {
    param([string]$Name, [string]$Text)
    if ($Name -match '(?i)\bv(?:ersion)?\s*([0-9]+(?:\.[0-9]+)?)') { return $Matches[1] }
    if ($Text -match '(?i)\bversion\s*:?\s*([0-9]+(?:\.[0-9]+)?)') { return $Matches[1] }
    return 'UNKNOWN'
}

function Guess-ReviewDue {
    param([string]$Text)
    if ($Text -match '(?i)review\s*(date|due|by)?\s*:?\s*([0-3]?\d[\/\-\s](?:[A-Za-z]{3,9}|[01]?\d)[\/\-\s]20\d\d)') { return $Matches[2].Trim() }
    return ''
}

function Get-Sha256 {
    param([string]$File)
    return (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLowerInvariant()
}

# -------------------------------------------------------------------- walk ---

$files = Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object {
    $INCLUDE -contains $_.Extension.ToLowerInvariant() -and -not ($_.Name -like '~$*')
} | Where-Object {
    # Directory exclusions are done in their own pass: inside a nested
    # Where-Object, $_ is the inner pipeline's item, not the file.
    $parts = (Get-RelativePath -Full $_.FullName -Base $root) -split '[\\/]'
    $bad = $false
    foreach ($s in $SKIPDIR) { if ($s -ne '~$' -and $parts -contains $s) { $bad = $true } }
    -not $bad
}

if (-not $Quiet) { Write-Host "Scanning $($files.Count) file(s) under $root" }

$docs   = @()
$nextId = 1
foreach ($d in @($ledgerObj.documents)) {
    if ($d.id -match '^D(\d+)$') { $n = [int]$Matches[1]; if ($n -ge $nextId) { $nextId = $n + 1 } }
}

foreach ($f in $files) {
    $rel = Get-RelativePath -Full $f.FullName -Base $root
    $prev = $existing[$rel]

    $x = Get-DocumentText -Path $f.FullName -UseOffice:$UseOffice
    $hits = Find-SupersededText -Text $x.Text

    if ($prev) {
        $doc = $prev
    } else {
        $doc = [pscustomobject]@{
            id = ('D{0:d3}' -f $nextId); file = $rel; title = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
            type = ''; version = ''; dated = ''; owner = 'UNKNOWN'; entities = @(); reviewDue = ''
            supersededRefs = @(); textRead = $false; sha256 = ''; sizeBytes = 0; modified = ''
        }
        $nextId++
    }
    foreach ($k in 'type','version','dated','owner','entities','reviewDue','supersededRefs','textRead','sha256','sizeBytes','modified','title','file','id') {
        if (-not $doc.PSObject.Properties[$k]) { $doc | Add-Member -NotePropertyName $k -NotePropertyValue '' }
    }

    # Scan-derived facts: always refreshed.
    $doc.file      = $rel
    $doc.sha256    = Get-Sha256 -File $f.FullName
    $doc.sizeBytes = $f.Length
    $doc.modified  = $f.LastWriteTime.ToString('yyyy-MM-dd')
    $doc.textRead  = $x.Read
    $doc.supersededRefs = @($hits | ForEach-Object {
        [pscustomobject]@{ id = $_.Id; why = $_.Why; count = $_.Count; excerpt = ($_.Excerpts | Select-Object -First 1) }
    })
    if (-not $x.Read -and $x.Note) {
        if (-not $doc.PSObject.Properties['textNote']) { $doc | Add-Member -NotePropertyName textNote -NotePropertyValue '' }
        $doc.textNote = $x.Note
    }

    # Guessed facts: filled only where a human has not already set them.
    if ([string]::IsNullOrWhiteSpace([string]$doc.type) -or $doc.type -eq 'UNKNOWN')       { $doc.type = Guess-Type -Name $f.Name -Text $x.Text }
    if ([string]::IsNullOrWhiteSpace([string]$doc.version) -or $doc.version -eq 'UNKNOWN') { $doc.version = Guess-Version -Name $f.Name -Text $x.Text }
    if ([string]::IsNullOrWhiteSpace([string]$doc.reviewDue))                              { $doc.reviewDue = Guess-ReviewDue -Text $x.Text }

    $docs += $doc
    if (-not $Quiet) {
        $flag = if ($hits.Count) { "  [{0} superseded flag(s)]" -f $hits.Count } else { '' }
        $unread = if (-not $x.Read) { '  [TEXT NOT READ]' } else { '' }
        Write-Host ("  {0}  {1}{2}{3}" -f $doc.id, $rel, $flag, $unread)
    }
}

# Documents in the ledger whose file has gone are kept and marked, never
# dropped: a finding may already cite them.
foreach ($d in @($ledgerObj.documents)) {
    if ($d.file -and -not ($docs | Where-Object { $_.file -eq $d.file })) {
        if (-not $d.PSObject.Properties['missing']) { $d | Add-Member -NotePropertyName missing -NotePropertyValue $true }
        else { $d.missing = $true }
        $docs += $d
        if (-not $Quiet) { Write-Warning "In ledger, not on disk: $($d.file)" }
    }
}

$ledgerObj.documents = @($docs | Sort-Object id)
$ledgerObj | ConvertTo-Json -Depth 12 | Out-File -LiteralPath $Ledger -Encoding utf8

# ------------------------------------------------------------------ report ---

if (-not $Markdown) { $Markdown = Join-Path (Split-Path -Parent (Resolve-Path -LiteralPath $Ledger)) '00-document-register.md' }

$today   = Get-Date -Format 'yyyy-MM-dd'
$flagged = @($docs | Where-Object { $_.supersededRefs -and @($_.supersededRefs).Count -gt 0 })
$unread  = @($docs | Where-Object { -not $_.textRead })

$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine('# 00 - Document register')
[void]$md.AppendLine()
[void]$md.AppendLine("Scanned $($docs.Count) document(s) under ``$root`` on $today.")
[void]$md.AppendLine()
[void]$md.AppendLine('This is Phase 1. Nothing here is a finding. Type, version, owner and entity')
[void]$md.AppendLine('are scan guesses and must be corrected in the ledger before Phase 2.')
[void]$md.AppendLine()
[void]$md.AppendLine('| Id | Document | Type | Version | Owner | Entities | Review due | Superseded flags | Text |')
[void]$md.AppendLine('|---|---|---|---|---|---|---|---|---|')
foreach ($d in $docs) {
    $ents = if (@($d.entities).Count) { (@($d.entities) -join ', ') } else { 'UNKNOWN' }
    $sf   = @($d.supersededRefs).Count
    $tx   = if ($d.textRead) { 'read' } else { '**not read**' }
    $miss = if ($d.PSObject.Properties['missing'] -and $d.missing) { ' *(missing from disk)*' } else { '' }
    [void]$md.AppendLine("| $($d.id) | $($d.file)$miss | $($d.type) | $($d.version) | $($d.owner) | $ents | $($d.reviewDue) | $sf | $tx |")
}

if ($flagged.Count) {
    [void]$md.AppendLine()
    [void]$md.AppendLine('## References to superseded instruments')
    [void]$md.AppendLine()
    [void]$md.AppendLine('A hit is a flag, not a finding. Read the context: a document control table')
    [void]$md.AppendLine('recording what a version replaced is a correct use of the phrase.')
    foreach ($d in $flagged) {
        [void]$md.AppendLine()
        [void]$md.AppendLine("### $($d.id) - $($d.file)")
        [void]$md.AppendLine()
        foreach ($h in @($d.supersededRefs)) {
            [void]$md.AppendLine("- **$($h.id)** ($($h.count)x) - $($h.why)")
            if ($h.excerpt) { [void]$md.AppendLine("  > ...$($h.excerpt)...") }
        }
    }
}

if ($unread.Count) {
    [void]$md.AppendLine()
    [void]$md.AppendLine('## Text not read')
    [void]$md.AppendLine()
    [void]$md.AppendLine('These were registered but not scanned, so their superseded-reference count is')
    [void]$md.AppendLine('**unknown, not zero**. Re-run with `-UseOffice`, or read them by hand.')
    [void]$md.AppendLine()
    foreach ($d in $unread) {
        $note = if ($d.PSObject.Properties['textNote']) { " - $($d.textNote)" } else { '' }
        [void]$md.AppendLine("- $($d.id) ``$($d.file)``$note")
    }
}

[void]$md.AppendLine()
[void]$md.AppendLine('## Next')
[void]$md.AppendLine()
[void]$md.AppendLine('1. Correct type, version, owner and entities in the ledger.')
[void]$md.AppendLine('2. List what is missing against the framework - see `references/inventory.md`.')
[void]$md.AppendLine('3. Batch the Phase 1 questions and stop for direction.')
[void]$md.AppendLine()
[void]$md.AppendLine('*Internal working material. Not a regulatory determination and not legal advice.*')

$md.ToString() | Out-File -LiteralPath $Markdown -Encoding utf8

if (-not $Quiet) {
    Write-Host ''
    Write-Host "Ledger:   $Ledger"
    Write-Host "Register: $Markdown"
    Write-Host ("Documents {0}   superseded-flagged {1}   text not read {2}" -f $docs.Count, $flagged.Count, $unread.Count)
}
