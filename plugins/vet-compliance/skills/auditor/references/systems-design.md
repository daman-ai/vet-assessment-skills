# Phase 4 — Systems that demonstrate outcomes

This is the phase that matters. Phases 1–3 describe and repair documents; a
document has never made an outcome happen. Phase 4 designs the operating system
that produces the outcome, and produces its evidence while doing it.

## Evidence as exhaust

For every requirement, name the artefact that proves it, where it lives, who
generates it, and how often.

Then apply the test: **is this artefact produced by doing the work, or by
remembering to produce it?**

- A validation that writes a dated record naming the validators, the sample and
  the actions — exhaust. The record exists because the validation happened.
- A "validation register" someone updates monthly from memory — homework. It
  will be current in the month before an audit and stale for the other eleven.

Where evidence is homework, redesign the work rather than adding a reminder. The
usual move is to make the record the mechanism: the validation is not complete
until the record is signed, the intervention is not recorded as done until the
student contact is logged, the certificate is not issued until the USI check is
stamped. Anything relying on memory, email or one person's initiative gets
flagged in the evidence architecture with that word — **fragile** — and a
proposed replacement.

## Leading indicators

A lagging indicator tells you the finding already exists. A leading indicator
tells you it is coming.

| Requirement | Leading indicator | Not this |
|---|---|---|
| OS-1.5 | Products validated to date / products scheduled to date | Validations completed last year |
| OS-3.2 | Days of runway to the next credential or currency expiry, per trainer per product | Trainers with expired credentials |
| OS-1.2 | Training products with no industry engagement record in the last 12 months | Industry consultations held |
| OS-2.7, NC-10 | Open complaints past their internal timeframe, by age | Complaints closed |
| NC-8 | Days from at-risk identification to documented intervention | Students reported for unsatisfactory progress |
| CS-9 | 90th-percentile days from final assessment to certificate issue | Certificates issued |
| CS-14 | Days remaining on the transition clock, per superseded product with live enrolments | Products transitioned |
| CS-17 | Third-party arrangements live in the SMS with no notification recorded | Third party agreements on file |
| ESOS-AUTOCANCEL | **Days since last overseas-student delivery, per course, per location** | Courses delivered this year |
| NC-4 | Per-agent visa refusal rate, first-semester withdrawal rate, complaint count | Agents under agreement |

Each indicator carries: source system, formula, frequency, threshold and
escalation path. An indicator with no threshold is a number on a page. An
indicator with a threshold and no named escalation is a number someone worries
about privately.

Design for the data that exists. An indicator requiring a field nobody captures
is a system change, not an indicator — put it in the roadmap as a treatment and
mark the indicator as pending.

## The self-assurance cycle

What is checked monthly, quarterly and annually; by whom; reported to whom; and
what triggers escalation.

The 2025 Standards expect systematic monitoring (Standard 4.4). The evidence that
it happens is not a policy describing a governance forum — it is the forum's
minutes, showing indicators presented, exceptions discussed, and decisions taken
with owners and dates. So design the **agenda template and the minute
structure**, because that is the artefact an assessor reads, and a minute
recording "compliance report noted" proves nothing happened.

A workable shape:

- **Monthly pulse** — exceptions only, one page. See `references/modes.md`.
- **Quarterly self-assurance report** — indicators with trend, exceptions, the
  risk register's control-effectiveness changes, and three actions. To the
  governing body, minuted.
- **Annual** — full internal review against all four Quality Areas and, where
  applicable, the National Code; feeds the annual declaration on compliance
  (`CS-15`). The declaration is signed on the basis of this review, and the
  minute should say so. Signing an annual declaration with no internal review
  behind it is the governance failure that makes every other finding worse.

## Compliance calendar

Built from `assets/obligations.calendar.json`, per entity. Two kinds of row and
they behave differently:

- **Clocks** are event-driven with a verified duration — 30 days to issue a
  certificate, 10 business days to notify a material change, 12 months of
  non-delivery to automatic cancellation. These are monitored continuously, not
  scheduled.
- **Recurring** obligations fall due on a date. Every seeded recurring row is
  marked `verifyLocally: true` because the date varies by provider, regulator
  notice or funding contract. **Verify each one before it goes into the
  deliverable.** A calendar with a confidently wrong date is worse than a blank
  and a question, because it gets trusted.

Every row carries an owner and an evidence output. A calendar entry with no
evidence output is a reminder, not a control.

## RACI

Across both entities, for every compliance function. The purpose is not tidiness
— it is to make the single points of failure visible.

Where one person is Accountable for the same function at both providers, that is
a concentration risk and it goes to the risk register. Shared services between
two RTOs look like efficiency and behave like correlated failure: when the
compliance manager leaves, both providers lose their compliance function on the
same day, and both are mid-registration-period.

Look specifically for: a function with no A; a function where A and R are the
same person and nobody is C; and a function whose A is a role that does not exist
in the org chart.

## Registers and templates

Build the ones that are missing. Each with the fields, an example row, and the
procedure step that populates it:

validation record · industry engagement record · trainer profile and currency
matrix · complaints and appeals register · continuous improvement register · risk
register · student-at-risk intervention record · agent performance review ·
third-party arrangement register · notifications register (for `CS-16` and
`CS-17`) · CRICOS delivery log (for `ESOS-AUTOCANCEL`).

The example row matters more than the field list. A blank register gets filled in
inconsistently by five people; a register with a well-written example row gets
filled in like the example.

Keep them narrow. A register with forty columns gets abandoned inside a quarter,
and an abandoned register is evidence against the RTO rather than for it.
