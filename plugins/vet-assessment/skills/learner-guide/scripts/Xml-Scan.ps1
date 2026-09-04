<#
    Xml-Scan.ps1

    Balanced-element scanning for raw OOXML text editing.

    Shared by the Word and PowerPoint builders because both edit packages as
    TEXT rather than through a namespace-aware parser - which is the house
    method, and the method the assessment skill's template-build reference
    requires. Text editing needs one thing a regex cannot give: the ability to
    find where an element actually ENDS.

    ASCII only in this file.
#>

# No Set-StrictMode - dot-sourced.

function Get-XmlFragment {
    <#  The first complete <Tag>...</Tag> (or <Tag/>) at or after -From.

        NOT a regex, deliberately. A non-greedy '<a:rPr\b.*?(?:/>|</a:rPr>)'
        looks right and is wrong: <a:rPr> routinely CONTAINS self-closing
        children - <a:solidFill><a:srgbClr val="234B8C"/></a:solidFill> - so the
        '.*?/>' arm matches the inner <a:srgbClr/> and returns a truncated,
        unbalanced fragment. Splicing that into a slide produces XML that passes
        a shape-level sanity check and makes PowerPoint refuse the whole file as
        "corrupted and unreadable". This scanner walks the start tag honouring
        quoted attributes, returns immediately on a self-closing tag, and
        otherwise counts nested opens against closes.

        Returns $null when the tag is absent or unbalanced.  #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Xml,
        [Parameter(Mandatory)][string] $Tag,
        [int] $From = 0
    )

    $m = [regex]::Match($Xml, "<$([regex]::Escape($Tag))(?=[\s/>])", 'None', [TimeSpan]::FromSeconds(5))
    if ($From -gt 0) { $m = [regex]::Match($Xml.Substring($From), "<$([regex]::Escape($Tag))(?=[\s/>])") ; if (-not $m.Success) { return $null } ; $start = $From + $m.Index }
    else { if (-not $m.Success) { return $null } ; $start = $m.Index }

    # Walk to the end of the start tag, ignoring '>' inside attribute values.
    $i = $start; $inQuote = $false; $quote = [char]0
    while ($i -lt $Xml.Length) {
        $c = $Xml[$i]
        if ($inQuote) { if ($c -eq $quote) { $inQuote = $false } }
        elseif ($c -eq '"' -or $c -eq "'") { $inQuote = $true; $quote = $c }
        elseif ($c -eq '>') {
            if ($Xml[$i - 1] -eq '/') { return $Xml.Substring($start, $i - $start + 1) }   # self-closing
            break
        }
        $i++
    }
    if ($i -ge $Xml.Length) { return $null }

    $open = "<$Tag"; $close = "</$Tag>"
    $depth = 1; $pos = $i + 1
    while ($depth -gt 0 -and $pos -lt $Xml.Length) {
        $no = $Xml.IndexOf($open, $pos)
        $nc = $Xml.IndexOf($close, $pos)
        if ($nc -lt 0) { return $null }
        if ($no -ge 0 -and $no -lt $nc) {
            $after = $Xml[$no + $open.Length]
            if ($after -eq ' ' -or $after -eq '>' -or $after -eq '/' -or $after -eq "`t" -or $after -eq "`r" -or $after -eq "`n") { $depth++ }
            $pos = $no + $open.Length
        }
        else { $depth--; $pos = $nc + $close.Length }
    }
    if ($depth -ne 0) { return $null }
    return $Xml.Substring($start, $pos - $start)
}
