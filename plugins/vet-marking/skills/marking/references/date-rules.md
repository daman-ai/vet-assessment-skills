# Date rules

Every date on every record derives from **one** input: the marking date, the day
you complete the records. `Lib-Dates.ps1` computes them once, the resolved
ledger carries them, and no document recomputes a date.

All dates print `dd / mm / yyyy`.

## The four derived dates

| Field | Rule |
|---|---|
| **Date of assessment** | Marking date **minus 14 calendar days**. If that lands on a weekend or public holiday, roll **back** to the nearest preceding working day. |
| **Feedback Given** | The marking date. |
| **Resubmission Due** | **5 business days** forward from the marking date, excluding weekends and public holidays. Recorded only where the student is NYS on one or more tools. Where the student is Competent, enter **N/A**. |
| **Date results entered** | The date the results are entered into the student management system. Defaults to the marking date; set `resultsEnteredDate` in the ledger where it differs. |

Signature dates are the marking date.

## Worked example — marking date Wednesday 2 September 2026

- **Date of assessment:** 2 September − 14 days = Wednesday 19 August 2026. A
  working day, so used as is.
- **Feedback Given:** 02 / 09 / 2026.
- **Resubmission Due:** Wednesday 9 September 2026 — Thu 3, Fri 4, Mon 7, Tue 8,
  Wed 9.

`Lib-Dates.ps1` reproduces this exactly; it is the regression case for the
module.

## Public holidays

Held in `assets/public-holidays.sa.json`, listing the days on which each holiday
is **observed** — where a holiday falls at a weekend and SA substitutes a
weekday, the substitute is listed and the original is not.

Christmas Eve and New Year's Eve are **part-day** holidays in SA, from 7pm. They
are not listed: a full working day runs to 7pm, so they count as working days.

### The table throws rather than guessing

`Get-WorkingDay` and `Add-BusinessDays` **throw** for a date outside the years
the table covers. They never fall back to a weekends-only calendar.

This is deliberate. A quietly skipped public holiday puts a resubmission
deadline one day early on a signed student record, and nothing downstream would
catch it — the date looks perfectly plausible. A loud failure asking for the
year to be added is the cheaper outcome.

**Verify the gazetted dates before marking any batch in a listed year.** Dates
move; a stale table is wrong in a way that reads as right.

## Why the date of assessment rolls backwards, not forwards

The date of assessment is a record of when the assessment *happened*. Rolling
forward would place it after the event. Rolling back lands on the last working
day the assessment could have been conducted.

`Get-MarkingDates` reports `assessmentRolledBack` and the reason, so the build
report can say "19 August, rolled back because Saturday 22 August is a weekend"
rather than presenting a date with no explanation.

## Related

- [result-rules.md](result-rules.md) — Resubmission Due is N/A for a Competent student
- [ledger.md](ledger.md) — `markingDate` is the only date you supply
