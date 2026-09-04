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
| The assessment submitted is for another unit, or another unit's tool | **NYS**, comment `Incorrect assessment submitted` |

Use the marking standard in [marking-standard.md](marking-standard.md) to make
this judgement. Do not be strict.

### The wrong assessment is not a non-submission

A student who hands in another unit's work HAS submitted something. Filing it as
`No submission` tells them nothing about the file they know they sent, and they
resubmit the same thing. So the ledger says what happened:

```jsonc
{ "toolId": "uat1", "result": "NYS",
  "wrongAssessment": true,
  "submittedInstead": "an assessment for CPCCBC4001 Apply building codes and standards",
  "feedback": "The work submitted is an assessment for CPCCBC4001. …" }
```

The resolver forces NYS, writes the item that names what arrived and what to send
instead, and requires the class comment to read exactly `Incorrect assessment
submitted`. There is no marked copy — the file is not this unit's assessment — so
the student is issued a standalone Student Feedback Sheet.

## Step 2 — determine the overall result

- Any tool assessed NYS → overall **NYC** (Not Yet Competent).
- All tools assessed S → overall **C** (Competent).

There is no partial result. A student with four Satisfactory tools and one NYS
is NYC.

### Step 2b — RW overrides both

**Until 2 September 2026 this section read "There is no third outcome."** There
is now, and the sentence is rewritten rather than deleted so the history of the
rule stays legible.

- Any prerequisite the student does not hold → overall **RW** (Result Withheld),
  whatever the tool results say.

RW is applied **after** the S/NYS derivation and overrides it. It withholds a
result; it does not skip the assessment. Every tool is still judged, the work is
still marked, and the marked copy still carries a coloured outcome under every
answer.

| Derived value | Under RW |
|---|---|
| `overall` | `RW` |
| Marking record comment | exactly `Result withheld - Prerequisite not completed - Continuing enrolment` |
| Resubmission Due | **five working days from the marking date, always** — that is when the prerequisite question falls due, whether or not the student also has work to redo |
| Invoice Raised | ☐ never. RW is not an adverse outcome and does not use an attempt |
| Re-enrol in unit | ☐ never |
| WiseNet outcome code | **70 — Continuing Enrolment** |
| Per-tool S / NYS ticks | unchanged — judged normally |
| Colour | amber `B45F06`, against green `1E7B34` for C and red `C00000` for NYC |

Where the prerequisite is held at another RTO it cannot appear on the matrix.
The assessor records `confirmedExternally` with the evidence they saw — see
[wisenet-roll.md](wisenet-roll.md).

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
