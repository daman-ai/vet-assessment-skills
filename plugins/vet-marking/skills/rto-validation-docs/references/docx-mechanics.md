# Editing these .docx files without corrupting them

Read this before your first document edit in a session. Every trap below cost a rebuild
when it was first hit.

## Contents

- [Environment reality check](#environment-reality-check)
- [Choosing an approach](#choosing-an-approach)
- [Word COM: lifecycle and crashes](#word-com-lifecycle-and-crashes)
- [Word COM: editing traps](#word-com-editing-traps)
- [XML surgery](#xml-surgery)
- [Document properties and cached fields](#document-properties-and-cached-fields)
- [Matching the house style](#matching-the-house-style)
- [PowerShell 5.1 gotchas](#powershell-51-gotchas)

## Environment reality check

Check before planning, because the usual toolchain is mostly absent:

```bash
which python python3 pandoc soffice node zip unzip
```

Typically on this machine: **no node, no real python** (the Windows Store stub throws),
**no pandoc, no LibreOffice, no `zip` binary**. What you do have:

- `unzip` — for reading parts out of a .docx
- **Microsoft Word via COM** — check `HKLM:\SOFTWARE\Classes\Word.Application\CurVer`
- **.NET `System.IO.Compression`** — for writing zips, since `zip` is missing
- `perl`, `sed`, `grep` in Git Bash

A `.docx` is a ZIP of XML. `unzip -p file.docx word/document.xml` gets you the body.

## Choosing an approach

| Task | Approach |
|---|---|
| Read text | `unzip -p` + strip tags |
| Targeted text replacement | Word COM `Content.Find` — it matches across run boundaries |
| Add or reorder paragraphs / table rows | Word COM |
| Set document properties | Direct XML in `docProps/custom.xml` — the COM API is unreliable here |
| Build a whole new document | Reuse an existing document as template; swap the body XML |
| Bulk property-style change (e.g. `keepNext` on all headings) | Direct XML regex — faster and cannot crash Word |

**Why Word Find over raw XML for text:** Word splits a visible phrase across many `<w:r>`
runs for revision ids and spell-check state. A phrase you can see often does not exist as a
contiguous string in `document.xml`. Word's Find is run-aware; grep is not. Check contiguity
first if you plan to regex it:

```bash
unzip -p doc.docx word/document.xml | grep -c "the exact phrase"
```

## Word COM: lifecycle and crashes

**Always clean up headless instances, never visible ones.** A Word process the user has open
holds their unsaved work. Only kill instances with no window:

```powershell
Get-Process WINWORD -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -eq 0 } | Stop-Process -Force
```

`$word.Quit()` does not reliably release the file lock before the next statement runs. If the
next thing you do is open or delete that file, you get *"being used by another process"*.
Wait for the process to actually exit — `Kill-HeadlessWord` in the toolkit does this.

**`Fields.Update()` iterated over `StoryRanges` crashes Word on documents that carry footnote
or endnote parts.** It fails with `RPC_E_DISCONNECTED`, and because the crash happens before
`$doc.Save()`, **every edit made in that session is lost silently** — the script reports
success on the individual edits and the file on disk is unchanged.

Mitigations, in order of preference:

1. Don't refresh fields in script. Word re-evaluates `DOCPROPERTY`, `PAGE` and `NUMPAGES`
   fields on open and print anyway. Patch the cached text directly instead (below).
2. Save immediately after the edits, before anything else.
3. If you must refresh, do it in its own Word session on a file that is already saved.

**Never drive Word from parallel agents.** `Stop-HeadlessWord` cannot tell your abandoned
Word instance from another agent's live one — it kills every windowless WINWORD. Two agents
editing documents concurrently will destroy each other's sessions and lose unsaved work. If
you are fanning work out, either give exactly one agent the Word-based tasks, or restrict
the others to `unzip`-and-text analysis.

**Always verify the file on disk after a Word session**, not just the script's log:

```bash
unzip -p out.docx word/document.xml | sed -e 's|</w:p>|\n|g' -e 's/<[^>]*>//g' | sed -n '2p'
```

## Word COM: editing traps

**Find text is capped at 255 characters.** Longer find or replace strings silently fail. Split
the edit or anchor on a shorter unique substring.

**`Range.InsertParagraphBefore()` expands the range it is called on.** Calling it repeatedly
against the same anchor inserts in reverse order and merges the text into one paragraph. Insert
the whole block once, then format by index:

```powershell
$r = $anchor.Range
$r.Collapse(1)                       # wdCollapseStart
$r.InsertBefore(($lines -join "`r") + "`r")
# then locate $lines[0] by paragraph index and format the run of paragraphs
```

**`InsertParagraphAfter()` throws "not a valid action for the end of a row"** when the next
element is a table. Anchor on a paragraph that is not adjacent to one.

**Inserted paragraphs inherit the anchor's formatting.** Copy an explicit model paragraph's
style, font, size, indents and spacing rather than trusting inheritance.

**Table rows:** `$tbl.Rows.Add($tbl.Rows.Item($n))` inserts *before* row `$n`. Cell text is
`$tbl.Cell($r,$c).Range.Text`, and reading it needs trimming of `[char]13` and `[char]7`.

## XML surgery

Element order inside `<w:pPr>` is schema-enforced. The relevant prefix is:

```
pStyle, keepNext, keepLines, pageBreakBefore, framePr, widowControl,
numPr, suppressLineNumbers, pBdr, shd, tabs, spacing, ind, jc, outlineLvl
```

So `keepNext` goes immediately after `pStyle` when there is one, and immediately after
`<w:pPr>` when there is not.

**Always validate before writing:**

```powershell
$d = New-Object System.Xml.XmlDocument
$d.LoadXml($newXml)          # throws on malformed XML
```

**Write UTF-8 without BOM:**

```powershell
[System.IO.File]::WriteAllText($path, $xml, (New-Object System.Text.UTF8Encoding($false)))
```

**Replacing a part in place** (properties, one header/footer) — open the zip in `Update` mode,
`SetLength(0)` the entry stream before writing, or you leave trailing bytes from the old content.

**Repacking a whole directory** — `ZipFile.CreateFromDirectory` has written backslash entry
names in some framework versions, which produces a .docx Word cannot open. Build entries
explicitly with forward slashes instead. The toolkit does this.

## Document properties and cached fields

These documents drive their footers from custom document properties through `DOCPROPERTY`
fields — `RTOName`, `RTOnumber`, `CRICOSnumber`, `cmsDocNumber`, `cmsRevision`, `cmsDocName`.
That is good design: rebranding is a property change, not a text edit.

**Two places hold the value.** `docProps/custom.xml` holds the truth; the header/footer XML
holds the *cached result* Word last rendered. Patch both, or the footer shows stale values
until someone presses F9.

```powershell
# truth
(name="cmsDocNumber">)<vt:lpwstr>[^<]*</vt:lpwstr>   ->  ${1}<vt:lpwstr>4302</vt:lpwstr>
# cached render, inside word/footerN.xml
(<w:t[^>]*>)4455(</w:t>)                             ->  ${1}4302${2}
```

**The COM route does not work reliably.** `$doc.CustomDocumentProperties` accessed through
`InvokeMember` returns null in PowerShell 5.1. Go straight to the XML.

**Word normalises headers on save.** A document with unused `header2`/`header3` parts may come
back with only `header1`. That is Word tidying unused variants, not data loss — confirm the
active header still carries the logo and the active footer still carries the fields.

## Matching the house style

Before adding content, look at how the document already does it. Two specifics that bite:

**Bullets may be literal characters, not list formatting.** Several documents in this set use a
literal `•` plus two spaces in the paragraph text, with `ListParagraph` style and a hanging
indent — not Word numbering. Applying `ApplyBulletDefault()` there produces a second bullet
style in the same document. Detect it, then copy an existing bullet's `LeftIndent`,
`FirstLineIndent`, style, font and size.

**The palette:**

| Meaning | Colour |
|---|---|
| MET / SUPPORTED / MINOR / LOW | green `189C48` |
| PARTIAL / CANNOT BE DETERMINED / MAJOR / MEDIUM | orange `F09018` |
| NOT MET / NOT SUPPORTED / CRITICAL / HIGH | red `E43C30` |
| Headings, register reference shading | navy `2A364E` |
| Sub-headings | blue `2490CC` |
| Muted / strapline | grey `7A8699` |

Word's `Font.Color` takes **BGR**, not RGB. Navy `2A364E` is `0x4E362A` = `5124138`.

**Heading styles in this set carry no `keepNext`.** Every document built from these templates
will strand headings at page feet until you set it explicitly. Treat it as a template-level
defect worth reporting, not just fixing.

## PowerShell 5.1 gotchas

- No `&&`, no `||`, no ternary, no `?.`. Use `;` and `if`.
- **Argument-list concatenation does not work.** `Fn $doc "a " + $x + " b"` passes four
  arguments. Wrap in parentheses, or avoid non-ASCII in scripts entirely by using token
  placeholders (`~EM~`, `~MD~`, `~AP~`) expanded inside the function.
- **A `.ps1` written as UTF-8 without BOM may be read as ANSI**, mangling em dashes and curly
  quotes. Keep scripts ASCII-only and read content from a separate file with an explicit
  encoding: `[System.IO.File]::ReadAllLines($p, [System.Text.Encoding]::UTF8)`.
- `Set-Content`/`Add-Content` default to ANSI — pass `-Encoding utf8` or use .NET.
- `$PSScriptRoot` can be empty depending on how the script is invoked. Pass paths in.
