# Marking a class in parallel

Judging the evidence is the only slow stage of a marking run, and the only one
where the students are independent of one another: reading Daniel's workbook
tells you nothing about Mei's. So that stage — and only that stage — can be done
many at a time.

**Parallelism buys speed. It does not buy completeness**, and it makes two things
actively worse. Both are named below, with what to do about them.

## What runs in parallel, and what does not

| Stage | Parallel? | Why |
|---|---|---|
| Import the roll | **No** | One matrix, one read, for the whole class |
| Look up the prerequisite | **No** | One lookup per *unit*, cached. Twenty workers would ask training.gov.au the same question twenty times |
| **Judge the evidence, draft the feedback** | **Yes** | One student per worker. Nothing crosses between them |
| Draft observation comments | **Yes, then a single pass** | See *the convergence problem* below |
| Merge the fragments | **No** | It is the join |
| Resolve | **No** | Needs the whole class: duplicate IDs, tool consistency, every cross-student rule |
| Build | **No** | The marking record is class-wide by definition |
| Gate | **No** | Compares all the delivered files to each other |

Resolve → build → gate are also seconds of PowerShell with total data dependency
between them. There is nothing there to win.

## Keep it one skill

Split the pipeline into separate skills and each piece needs its own copy of the
ledger schema, the date rules, the two comma limits and the RTO profiles. That is
the *two copies drift* problem [onboarding-rto.md](onboarding-rto.md) already
warns about, reintroduced at a larger scale — and the drift would be between
workers marking the same class on the same day.

**Parallelise the work, not the definitions.**

## The fragment contract

A **fragment** is one entry of the ledger's `students[]` array, in its own file,
named for the student:

```
fragments/MVC00318.json
```
```jsonc
{
  "firstName": "Daniel",
  "surname": "Okafor",
  "studentId": "MVC00318",
  "comment": "Recipe workbook: 2 dishes not to standard",
  "results": [ /* one per tool, exactly as in ledger.md */ ]
}
```

The **base** is the same ledger with everything class-wide and **no students**:
`rto`, `unit`, `qualification`, `assessor`, `markingDate`, `location`,
`environment`, `tools`.

```bash
powershell -File scripts/Merge-LedgerFragments.ps1 -Base ledger.base.json -Fragments .\fragments -Roll roll.json -Out ledger.json
```

The merge checks **shapes**; the resolver then checks **meaning**. Neither
replaces the other, and both run.

## What the merge catches that nothing else can

**A worker that dies writes no fragment, and a missing fragment looks exactly
like a class that was always one smaller.** Every check downstream compares the
ledger to the documents built from it, so a student who never reached the ledger
is absent from both and the whole run reads as clean.

That is why `-Roll` matters more here than anywhere else:

> MVC00334 is REQUIRED TO SUBMIT but no fragment was written for them. A worker
> that failed leaves no file, and a missing file looks exactly like a smaller
> class.

The merge also catches the other thing only visible when the class is back
together — **a tool id that drifted in one worker**:

> MVC00312.json: result names tool 'knowledge', which is not one of the base
> ledger's tools (kq, rw).

And two fragments for one student, which is two judgements of the same work.

The resolver runs the same reconciliation again on the finished ledger, and the
gate reports it as `RollReconciled`. Three chances to notice one missing student,
because it is the failure with no other symptom.

## The convergence problem

**Observation comments get worse under naive parallelism, not better.**

The hardest rule in [observation-comments.md](observation-comments.md) is
cohort-wide: no two students share an opening sentence or a distinctive phrase.
Twenty workers drafting in isolation, from the same unit and the same checklist,
converge on near-identical phrasing — they cannot see each other. Fan-out makes
the exact failure `Test-ObservationComments.ps1` exists to catch *more* likely.

So the comments stage is **draft in parallel, then one pass over the whole
cohort**:

```bash
powershell -File scripts/Test-ObservationComments.ps1 -Path comments.json
```

Rewrite whatever it names, and run it again. The pass is not optional and it
cannot be parallelised — it is the only point at which every comment is visible
at once.

The same caution applies, more weakly, to the per-tool SAR feedback: workers
given the same unit will reach for the same sentences. Nothing checks that
today; read a sample across students before you sign.

## The other thing to watch

**Judgement drift.** Twenty workers applying
[marking-standard.md](marking-standard.md) will not draw the line in exactly the
same place, and the standard's own instruction — *where you are unsure, favour
Satisfactory* — is the kind of latitude that produces different answers from
different workers on the same borderline evidence.

Nothing in this skill can detect that, because each judgement is defensible on
its own. What helps is small and human: mark the borderline cases yourself, or
read every NYS across the class before signing. A class where one worker's
students are all NYS and another's are all S is worth a second look.

## Related

- [ledger.md](ledger.md) — the schema a fragment is one entry of
- [wisenet-roll.md](wisenet-roll.md) — where the roll comes from
- [observation-comments.md](observation-comments.md) — the cohort-wide rules
- [audit-checklist.md](audit-checklist.md) — what the gate proves at the end
