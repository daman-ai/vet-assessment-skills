# Result rules

Applied in order, per student. All of this is **derived** by
`Resolve-MarkingLedger.ps1` — none of it is hand-written into a ledger, and the
resolver rejects a ledger that states a derived value.

## Step 1 — judge each assessment tool

| Situation | Result |
|---|---|
| The submitted evidence meets the requirements of the tool | **S** (Satisfactory) |
| The evidence is submitted but does not meet the requirements | **NYS** (Not Yet Satisfactory) |
| A response confirmed as AI generated under the marking standard | **NYS** for that tool |
| No assessment document is attached or can be found | **NYS**, comment `No submission` |

Use the marking standard in [marking-standard.md](marking-standard.md) to make
this judgement. Do not be strict.

## Step 2 — determine the overall result

- Any tool assessed NYS → overall **NYC** (Not Yet Competent).
- All tools assessed S → overall **C** (Competent).

There is no third outcome and no partial result. A student with four
Satisfactory tools and one NYS is NYC.

## Step 3 — resit and invoicing

**Invoice Raised** is ticked (☒) only where the result is **NYC after the second
attempt**. In every other case it stays unticked (☐).

**Re-enrol in unit** is ticked only where the **second attempt of assessment is
not satisfactory**.

Both are computed from `attempt` and the overall result:

```
invoiceRaised = (overall == NYC) and (attempt >= 2)
reEnrol       = (overall == NYC) and (attempt >= 2)
```

A first-attempt NYC gets neither. This matters — a wrongly ticked invoice box
bills a student for a resit they have not had.

## The per-tool feedback option

Each tool row on the SAR ticks exactly one of three standing options. Which one
is derived, never chosen:

| Condition | Option ticked |
|---|---|
| Submitted and Satisfactory | ☒ Assessment completed |
| Nothing submitted | ☒ Assessment not submitted |
| Submitted and Not Yet Satisfactory | ☒ Please make corrections — resubmit both this and the corrected 2nd attempt |

Exactly one of S / NYS is ticked per tool row. Never both, never neither. The
gate check `OneTickPerToolRow` blocks on this.

## The resit row

Complete it **only where a re-assessment applies**. Then: tick ☒ Re-assessment,
mark the S / NYS boxes for the re-assessment outcome, tick the applicable
feedback option, and write feedback.

Where no resit applies: leave the row's boxes as ☐, remove the brackets, and
enter `N/A` in place of the feedback field. A blank cell is not the same
statement as N/A — one says "nothing to record", the other says "nobody
filled this in".

## The comment column

The marking record's Comments column takes a **short phrase, not a paragraph** —
enough to identify the issue at a glance. The SAR carries the full feedback.
The resolver rejects a comment over 120 characters.

Where nothing was submitted, the comment is **exactly** `No submission`. Not
"no submission", not "No submission received". The gate checks the string.

## Related

- [date-rules.md](date-rules.md) — the dates that follow from the result
- [ledger.md](ledger.md) — where each of these values lives
