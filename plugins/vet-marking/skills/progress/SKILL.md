---
name: progress
description: Review a Wisenet Report 0217 Unit Enrolment Outcome Matrix (every sheet/group) for discrepancies, prerequisite non-compliance, at-risk students and marking priorities, with an Excel report per group.
---

# Progress review: Wisenet Report 0217

Use this when the user provides a Wisenet **Report 0217 (Unit Enrolment Outcome Matrix)**, usually `rpt_WiseNET_0217_*.xls`, and wants student progress reviewed. The report is the source of truth. Findings are things to check and act on in Wisenet/eSkilled. Never present them as confirmed breaches beyond what the report's fields actually show.

Colleges: Adelaide Construction Institute and Adelaide Culinary Institute are two brands under one RTO (45797, CRICOS 03978F), so a construction course showing `Location: Adelaide Culinary Institute` is normal and is **not** a finding. Meridian Vocational College is separate.

**Output format is Excel** (see section 5): one `.xlsx` report per group plus one combined register `.xlsx`. Do not produce Docs or Word reports unless the user asks.

## 1. What the report looks like (verified against a real export)

- Legacy `.xls`, one **sheet per course offer = one group** (Sheet1, Sheet2...). Sheet order is not group order.
- Header block on each sheet (top ~17 rows), with a label in one cell and the value further right:
  - `Unit Enrolment Outcome Matrix` (title), plus the outcome-code legend cells (national and WA codes).
  - `Course Offer Code:` e.g. CPC31020
  - `Course Offer Desc:` e.g. `Certificate III in Solid Plastering - Group 3`. **The group name comes from here.**
  - `Location:` and `Offer Start Date:`
- **Units row**: a cell `Units`, then one header per unit to its right: `CODE\nDD/MM/YYYY - DD/MM/YYYY` (unit activity start/end dates). Some headers are **merged across two columns**, and the outcome can sit in either column of the merge. Columns between merges are blank spacers.
- **Learner header row**: `Learner Name | Reg Start / End Date | RefInternal (RefExternal) | Status | Workplace`. Reg start and end are in two separate cells. RefInternal is the Wisenet student ID (e.g. ADL3000284); RefExternal is in brackets, often empty.
- **One row per learner, one column per unit.** Each cell is one of three things:

  | Cell | Meaning | Use in this review |
  | --- | --- | --- |
  | **blacked out** (black fill; legend: "- Not Attached to Unit") | not enrolled in that unit | **exclude** from every count, check and queue |
  | **an outcome code** (20, 30, 40, 51, 53, 60, 70, 70AP, 81, 82, 85, 90) | result recorded | count it |
  | **blank, not blacked out** | enrolled, no result yet | "no outcome recorded" |

  Blank and blacked-out cells look identical in extracted text, so read the **fill colour** from the spreadsheet (the parser sets `attached=False` for black cells), never from a PDF. Codes 70, 85 and 90 also mean "enrolled, no result yet": treat them like blank cells for overdue and marking checks, and list them so staff can confirm. The same rule is used by the `marking` skill's `Import-WisenetMatrix.ps1`.
- **Identity is the student ID, never the name**: one learner can hold two enrolments and appear on two rows.
- Delivery patterns seen:
  - **Concurrent**: every unit has the same date range (e.g. 14/11/2025 to 08/11/2026).
  - **Timetabled**: each unit has its own consecutive date window. Overdue logic depends on which one applies, so detect it per sheet.

**Fields this report does NOT contain:** result dates, submission dates, trainer/assessor, USI, attendance, last activity, international/CoE flag, attempts. Checks that need them are reported as **not performed**, with the extra Wisenet/eSkilled report that would allow them (e.g. unit enrolment list with outcome dates, eSkilled submission/marking queue, CoE list, attendance report). If the user supplies any of those, merge on student ID and run the extra checks (result-order prerequisite check, submission-age marking queue, R4/R7/R8).

## 2. Load every sheet, with nothing skipped

`xlrd` is often not installable (pip may be offline), so convert with LibreOffice and parse with openpyxl. Keep the source untouched, put the conversion in its own folder, and run scripts with `python3 -I`. Use the bundled parser, which handles label search, merged unit headers and blank spacer columns:

```bash
python3 -I scripts/parse0217.py <report.xls|xlsx> <outdir>
# writes sheets.csv (inventory), learners.csv, outcomes.csv (one row per learner x unit), units.csv
```

Then:
- Produce the **sheet inventory** (every sheet: name, visible/hidden, group, course, location, offer start, learners, units, delivery pattern). Any sheet the parser marks "not an outcome matrix" is opened and reviewed by hand, never dropped.
- Group name = text after the last " - " in Course Offer Desc. If it is missing, use the sheet name.
- As-at date = today (the report has no run date). State it.
- Drop rows with `attached=False` before any analysis, and report how many were dropped per group on the Summary tab. Progress percentages use attached units only, not a fixed 20.
- Sanity check: learners per sheet and unit count match a visual look at the sheet. `conflict=True` (two different codes inside one merged unit) is finding D5.

## 3. Rules reference

- Look up the qualification on training.gov.au. The qualification PDF is at `https://training.gov.au/assets/<PKG>/<CODE>_R<n>.pdf` and unit PDFs at `.../<PKG>/<UNIT>_R1.pdf`. These are more reliable to fetch than the Details pages. Record packaging (core/elective counts and lists) and **each unit's prerequisites from the unit document**, not the qualification's asterisks.
- Competent for prerequisite purposes = 20, 51, 53, 60 (and 70AP where the SA academic pass applies).
- **Known reference: CPC31020 Certificate III in Solid Plastering, Release 2** (verified 15 Oct 2026; re-check the release each run): 20 units = 15 core + 5 elective. The following units each have the prerequisite **CPCCWHS2001**: CPCCSP2001, CPCCSP2002, CPCCSP2003, CPCCSP3001 (its unit document misprints this as "CPPWHS2001"), CPCCSP3002, CPCCSP3003, CPCCSP3004, CPCCOM2001, CPCCCM2008, CPCCCM2012, CPCCCO2013. CPCCWHS2001 itself has no prerequisite. CPCWHS1001 (White Card) is not on the elective list, so confirm it is being used as the one imported elective allowed by the packaging rules.
- Put the prerequisite reference (unit, release, prerequisite, source URL, lookup date) on each report's Notes & sources tab.

## 4. Checks

Every finding gets: group, student ID, learner, unit, check code, evidence (codes and dates from the report), action, owner (trainer / student services / admin-records / compliance).

### A. Discrepancies in the system records
- **D1 No result after the unit end date**: blank cell where the unit end date is before the as-at date. For a timetabled group this is per unit. If a whole unit is blank for the entire group after its end date, report it once as a **unit-level** finding. Note when gaps in early units belong to learners who started after the unit closed.
- **D1 (watch)**: an open unit with no outcome for anyone yet.
- **D2 NYC after the unit end date**: 30 recorded and the unit window has closed. This needs reassessment and an extended unit end date, or a decision.
- **D3 30 used for in-progress work**: many 30s on units still open suggests 30 is being used as an interim "not yet". Under AVETMISS, 30 is a final outcome and in-progress units should be 70. Flag this as a records practice for compliance to review, at group level.
- **D4 Credit transfer / RPL / RCC (60, 51, 53)**: list them for an evidence check (USI transcript or certified copy, RPL kit).
- **D5 Conflicting codes** in one merged unit cell, or the same student ID appearing twice in a sheet.
- **D6 Packaging**: units not in the qualification, superseded unit codes, elective count or rules not met, imported elective needing justification.
- **D7 Status conflicts**: Status ≠ Current with open/blank units, or Current with all units final competent, or Withdrawn/Cancelled with no 40 outcomes.
- **D8 Date alignment**:
  - **D8a**: unit start date before the learner's Reg Start, meaning unit activity is recorded before the learner commenced;
  - **D8b**: last unit end date before Reg End by more than 30 days, or after Reg End;
  - **D8c**: Reg Start before the Offer Start Date.
  Watch for a whole group whose learners enrolled months after the offer started but carry the offer's unit dates. Raise that as a group-level finding: re-date the unit enrolments or move the group to its own offer.
- **D9 Name quality**: learner name ending in " --" or a single name, inconsistent capitalisation, given name = family name.
- **D10 Possible duplicates**: the same student ID across sheets, or the same name with different IDs across sheets.
- **D11 Invalid code**: any cell value that is not a valid outcome code.

### B. Prerequisite compliance
The matrix has no result dates, so only state-based checks are possible:
- **P1 Non-compliant**: a dependent unit is competent (20/51/53/60) while its prerequisite is not competent. Action: compliance to review and hold the dependent result. Check that no certification relies on it.
- **P2 Order not verifiable**: where both are competent, say that the order could not be checked from Report 0217, and give a count of pairs.
- **P3 Blocked**: the prerequisite is not competent and the dependent units are open or NYC, so they cannot be signed off until it is competent. This also feeds R6.
- **P4 Site-safety policy check (not a training package breach)**: CPCWHS1001 (White Card) is not competent or is blank while practical CPCCSP units are competent.

### C. Students at risk
Competent % = competent units ÷ attached units for that learner. Elapsed % = (as-at − Reg Start) ÷ (Reg End − Reg Start).
- R1 5+ units NYC (30).
- R2 Closed units with no result for this learner (D1).
- R3 Progress gap: elapsed % − competent % greater than 25 points.
- R4 No activity: needs eSkilled data, otherwise not performed.
- R5 Reg End within 8 weeks with units not competent.
- R6 Blocked by a prerequisite (P3).
- R7 Attendance: needs an attendance report, otherwise not performed.
- R8 International unsatisfactory progress (National Code 2018, Standard 8). Needs the CoE/international list.

**Tiers:**
- **High**: R8; 0 competent with elapsed > 40%; any three indicators; or R5 with more than half the units not competent.
- **Medium**: two indicators.
- **Low**: one indicator.

Actions: High = trainer contact this week, written study plan, review unit and Reg End dates, review in 2 weeks. Medium = trainer contact, agree resubmission dates, review in 4 weeks. Low = monitor at the next check-in.

### D. Marking priority
There is no submission data, so state that the queue is built from outcomes and dates and should be checked against the eSkilled marking queue. Rank **by unit** within each group.

**Timetabled groups:**
1. Unit window closed with blanks (D1); most learners waiting first, then oldest end date.
2. Unit window closed with 30s only (D2).
3. Prerequisite units with blanks or 30s.
4. Open units ending within 4 weeks, then the remaining open units.

**Concurrent groups (one shared end date):**
- The prerequisite unit comes first.
- **Median weeks to Reg End ≤ 12**: units with no result for anyone next, then the rest by total learners waiting. Within each unit, learners with the earliest Reg End come first.
- **Median > 12 weeks**: the NYC backlog next, largest first. Units with no outcome for 90%+ of learners go last as "not yet delivered".

Within a unit, list High-risk learners first.

## 5. Outputs (Excel)

Read the xlsx skill before building. Use Arial, white header text on a dark blue header row, wrapped and left-aligned cells, frozen header rows, filters, landscape fit-to-width printing and no gridlines. Every findings table ends with a **Status** dropdown (Open / In progress / Resolved / No action needed) and a **Notes** column.

1. **One workbook per group**: `Progress Review – <Course code> – <Group> – <YYYY-MM-DD>.xlsx`, with these tabs:
   - **Summary**: headline, details table, top three actions.
   - **A Discrepancies**: closed units with open results, group-level findings, learner-records table with legend.
   - **B Prerequisites**: P1/P2 statement, then P1, P3 and P4 tables.
   - **C At risk**: every learner with coloured tier and figures, sorted High → Low.
   - **D Marking priority**: the ranked queue with learner names.
   - **Actions**: action, owner, suggested due date.
   - **Unit outcomes**: unit, start, end, window, competent, NYC, no outcome.
   - **Notes & sources**: packaging, prerequisite reference with links, checks not performed, assumptions.
2. **Combined register**: `Progress Review Register – <Course code> – <YYYY-MM-DD>.xlsx`, with these tabs:
   - **Overview**: per-group counts built with COUNTIFS over the Register tab.
   - **Register**: one row per finding, with a Status dropdown.
   - **At risk**, **Marking priority** and **Unit outcomes**: all groups.
   - **Sheet inventory**.
   - **Prerequisites**.

   Run the xlsx skill's recalc and fix any formula errors.

## 6. Verify before delivering
- Every sheet in the source workbook appears in the inventory with its group.
- Per group, learner count × unit count = outcome rows, and outcome totals match the Summary.
- The register's Overview counts match the group workbooks, and the marking order is identical in both.
- Spot-check five findings against the original sheet cells, including one in a merged unit column.
- Render one workbook to PDF/PNG and check the layout.
- Every prerequisite statement cites a training.gov.au unit document.

## Rules
- Never edit the source report; work on a copy.
- Keep student personal information inside the workbooks, not in file names.
- Use neutral wording, not blame.
- Don't guess fields the report lacks. Name the report that would supply them.
