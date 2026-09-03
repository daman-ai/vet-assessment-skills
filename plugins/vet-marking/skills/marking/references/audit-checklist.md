# The closing checklist, and the gate that proves it

The RTO's marking instruction closes with an eighteen-point checklist. Every point is
a machine check in `Test-MarkingRecords.ps1`, run against the **delivered files**
rather than the build's own log.

**Nothing is delivered until the gate passes.** A build that reports success
while shipping a leftover field, a double tick, or a SAR that disagrees with
its row in the marking record is exactly the failure this exists to catch — so
every check reads bytes off disk.

## The mapping

| Checklist point | Gate check |
|---|---|
| No `[ … ]` bracketed field remains anywhere | `NoUnfilledField` |
| Every `[ ☐ ]` became ☐ or ☒, brackets removed | `NoBracketedBox` |
| *(implied)* no field still prints as unfilled | `NoPlaceholderStyling` |
| One SAR per student, named `SAR_<ID>_<UNIT>_<RESULT>.docx` | `SarPerStudent` |
| Marking record named `AMLC_<UNIT>_<DDMMYYYY>.docx` | `MarkingRecordName` |
| One row per student, no unused rows | `NoUnusedRows`, `CrossDocumentAgreement` |
| One feedback sheet per NYS student, named correctly, one page | `FeedbackSheetPerNyc`, `FeedbackSheetOnePage` |
| Tool names identical across every document | `ToolNamesIdentical` |
| Each tool row has exactly one of S / NYS ticked | `OneTickPerToolRow` |
| *(implied)* exactly one feedback option per tool row | `OneFeedbackOptionPerRow` |
| Any NYS → NYC; all S → C | `OverallResultRule` |
| No student marked down for spelling, grammar or expression | **not machine-checkable** — see below |
| Every AI-flagged response marked NYS and listed for redo | enforced at the resolver |
| Every NYS student has a Resubmission Due 5 business days out | `DateRules` |
| Every Competent student has N/A in Resubmission Due | `DateRules` |
| Feedback Given equals the marking date on every record | `DateRules`, `CrossDocumentAgreement` |
| Date of assessment is the same on every record | `DateRules` |
| Invoice Raised ticked only where NYC after the second attempt | `InvoiceRule` |
| Every non-submission carries the comment `No submission` | `NoSubmissionComment` |
| SAR, marking record row and feedback sheet agree on every value | `CrossDocumentAgreement` |
| Headers, footers and document numbering untouched | `TemplateUntouched` |
| *(added)* no reserved namespace bound to an invented prefix | `NoInventedNamespacePrefix` |
| *(added)* the files actually open | `OpensInWord` |
| *(added)* one coloured outcome per question, front page matches the SAR | `MarkedCopyOutcomes` |
| *(added)* the overall result sits top right, in the right colour | `MarkedCopyOutcomes` |
| *(added)* every observation tool carries its point-form record | `MarkedCopyOutcomes` |
| *(added)* every outcome sits in the answer box it judges | `MarkedCopyInAnswerSpace` |
| *(added)* the result declaration is a page of its own | `MarkedCopyDeclarationPage` |
| *(added)* the observation sheet is filled in, boxes and all | `MarkedCopyObservationSheet` |
| *(added)* the RTO's banned word appears nowhere | `NoBannedWord` |
| *(added)* no double-encoded characters | `NoMojibake` |

## The one point no gate can prove

**"No student was marked down for spelling, grammar or expression."**

No check can read a judgement's reasoning. What the gate can do is confirm the
feedback does not *comment* on language; what it cannot do is confirm the
result was not influenced by it.

That point stays a human responsibility. Before signing, re-read every NYS
judgement and ask whether the requirement genuinely was not demonstrated, or
whether the answer was merely hard to read. See
[marking-standard.md](marking-standard.md).

## The two checks that were added after a failure

`OpensInWord` and `NoInventedNamespacePrefix` are not on the RTO's list. They
were added because a build passed all sixteen structural checks and produced ten
documents **Word refused to open** — well-formed XML, correct content, every
value agreeing with every other value, and unreadable.

The lesson generalises: a gate made only of checks you thought to write will
pass the failure you did not think of. Where a cheap proxy and a definitive test
both exist, run both — the proxy so it still works on a machine without Word,
the definitive one because the proxy only covers the failure already known.

## Running it

```bash
powershell -File scripts/Test-MarkingRecords.ps1 -Ledger resolved.json -Dir out
```

`-SkipRender` turns off the Word check. On a machine without Word the check
degrades to a **WARN**, not a pass, and says so — the structural checks are
weaker and one file should be opened by hand before the records are issued.

The script exits non-zero on any failure.

## Proving the gate still bites

A gate that has only ever passed proves nothing. These mutations must each fail
it — run them after any change to the checks:

| Mutation | Must fail |
|---|---|
| Flip one tool result in the marking record only | `CrossDocumentAgreement` |
| Restore one `[ Insert … ]` field in a SAR | `NoUnfilledField` |
| Restore one `[ ☐ ]` | `NoBracketedBox`, `OneTickPerToolRow` |
| Delete one feedback sheet | `SarPerStudent` |
| Add a paragraph to a footer | `TemplateUntouched` |
| Bind the xml namespace to a made-up prefix | `NoInventedNamespacePrefix`, `OpensInWord` |
| Recolour one red outcome line green on a marked copy | `MarkedCopyOutcomes` |
| Left-align the overall result on a marked copy | `MarkedCopyOutcomes` |
| Delete one observation point from a marked copy | `MarkedCopyOutcomes` |
| Move one outcome line out of its answer box onto the spacer below | `MarkedCopyInAnswerSpace` |
| Remove the page break so the declaration runs into the cover sheet | `MarkedCopyDeclarationPage`, `MarkedCopyFrontBlockAligned` |
| Leave an observation sheet's boxes empty, or tick one against the wrong task | `MarkedCopyObservationSheet` |
| Change a start time on the sheet without changing the ledger | `MarkedCopyObservationSheet` |
| Type the banned word into any document | `NoBannedWord` |
| Inject a double-encoded character | `NoMojibake` |

Each has been run against this gate and each failed it.

The observation-sheet mutations earn their place. `Set-LabelledBox` handed a
paragraph ticked **nothing**, silently, and a full build shipped a sheet whose
every box was still empty beneath a signed record and a completion date. The
gate passed it, because at that point the gate only counted the record's own
paragraphs. A check that reads the boxes off the delivered file is the only
thing that would have caught it.
