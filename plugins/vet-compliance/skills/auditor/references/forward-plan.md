# Phase 5 — Forward plan

## Risk register, per entity

Risk · cause · current control · control effectiveness · treatment · owner ·
review date.

**Control effectiveness is rated on evidence, not on the control's existence.**
The four ratings are `effective`, `partially effective`, `ineffective`,
`untested`. Most controls in a first engagement are `untested`, and that is the
honest answer — it means the control exists and nobody has checked whether it
works. Writing `effective` because a policy describes the control is the same
error as rating maturity 3 from a document.

Include strategic risks, not only compliance ones. The ones that actually end
RTOs:

- **Source-country concentration.** A cohort drawn overwhelmingly from one
  country is one visa-policy change from an enrolment cliff. It is also the
  pattern that draws integrity scrutiny.
- **Key-person dependency.** One trainer holding the only current industry
  currency for a qualification means that qualification stops when they leave —
  and stopping delivery has consequences beyond the timetable for a CRICOS
  provider.
- **Agent dependency.** A large share of enrolments through one agent transfers
  the provider's recruitment integrity to a party it does not control, while
  leaving the provider responsible under National Code Standard 4.
- **Scope growth under the CRICOS freeze.** No new CRICOS course can be added
  before 19 May 2027. Any growth plan assuming one is not deliverable, and the
  application work has to be complete before the window opens.
- **Dormant CRICOS courses.** A course on scope at a location nobody has taught
  at drives the 12-month automatic-cancellation clock. Providers routinely do not
  know they have one.
- **Shared services across the two entities.** Efficient, and correlated: a
  single failure is a failure at both providers on the same day.

## The 12-month roadmap

Sequenced by risk and by dependency, not by ease. Every treatment carries an
owner, a due date, an effort estimate and the finding ids it closes.

Dependency sequencing is what makes a roadmap usable. Validation cannot start
before the validation schedule exists; the schedule cannot be built before the
scope is confirmed; trainer currency evidence has to exist before validators can
be shown to be appropriately credentialled under Standard 1.5. Put those in the
wrong order and the first three months produce nothing.

Front-load anything that must be true before the **next likely regulatory
touchpoint** — a registration renewal window, an annual declaration date, a
CRICOS delivery clock running out. Say what that touchpoint is and when.

Be honest about effort. A roadmap costing four times the available capacity gets
abandoned in month two, and the abandonment reads as a governance failure at the
next audit. If the work does not fit, say so, and put the surplus in a
second-year list with the risk of deferral stated.

## Horizon scan

Changes already legislated or announced that bite within 24 months, what each
entity must do, and by when. Verify each against primary sources and record the
date checked — this section ages faster than any other and a stale horizon scan
is actively misleading.

As at 4 September 2026 the live items are the automatic CRICOS cancellation
measurement running from 1 January 2026, and the CRICOS application freeze
running to 19 May 2027. Both are in `assets/sources.json`. Re-check for anything
newer before writing this section.

## Three scenario tests

The scenarios are the most-read part of the deliverable, because they convert an
abstract gap list into a morning the client can picture.

**(a) ASQA commences a performance assessment next month.** Name the evidence
that would be requested, requirement by requirement, and say whether it exists
today. Not "we would need validation records" — *"the assessor will ask for
validation records for the three qualifications with the most completions;
none exist for any product since 2023; the response would be an admission."*

**(b) A complaint escalates to the Overseas Students Ombudsman.** The Ombudsman
asks for the complaints register, the written outcome given to the student, the
dates against the internal timeframes, and the policy that was published at the
time. Say which of those exists and whether the dates would survive inspection.

**(c) A key trainer leaves with no notice.** Which products stop, whether a
credentialled and currency-holding replacement exists, what happens to
in-progress assessments, and — for a CRICOS provider — whether stopping delivery
starts a clock that matters.

Each scenario ends with the two or three treatments that would change the answer.
Those are the roadmap's first quarter, and they are almost never the ones chosen
by working down the gap analysis in priority order.

## Decisions, not decided

Anything requiring PEO or CEO judgement, board approval, legal advice or a
commercial decision goes into `decisions` in the ledger, with who decides, why it
matters, and which treatments it blocks. Do not decide it. Do not bury it in a
recommendation.

The commonest ones: whether to keep a dormant CRICOS course on scope; whether to
terminate an underperforming agent; whether to stop delivering a product the RTO
cannot resource properly; whether to notify the regulator of something the
organisation has just discovered about itself.

That last one is a legal question and it is urgent whenever it arises. Surface it
as a decision item, note that `CS-16` runs to 10 business days from the event,
and recommend legal advice rather than giving it.
