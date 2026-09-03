# The marking standard — how to judge an answer

This is the RTO's standard, not a general one. Read it before you judge anything.

## Assess the substance, not the English

**Do not mark a student down for spelling, grammar, punctuation, sentence
structure, word choice or written expression.** Many students are working in a
second language. Language quality is not a requirement of the unit and is not
being assessed.

This is not a courtesy. It is a statement about what the evidence is. An answer
that demonstrates the required knowledge in imperfect English *is* evidence of
that knowledge. Marking it down substitutes a requirement the unit does not
have for one it does.

## If the answer is reasonable, accept it

The test is whether the student has demonstrated the required knowledge or
skill — not whether they expressed it the way a model answer does. Accept an
answer that:

- covers the substance of what the question asks, even if it is brief;
- uses different words, a different order or a different example than the model
  answer;
- is written informally, in dot points, or in imperfect English;
- is partially incomplete on detail that is not itself a requirement of the unit.

## Mark NYS only where the requirement is genuinely not demonstrated

That means the answer is **absent**, **factually wrong**, **addresses a
different question**, or **misses a requirement the unit explicitly calls for**.

A borderline answer that shows the student understands is Satisfactory.

**Where you are unsure, favour Satisfactory** and note the reasoning in the
assessor comments rather than sending the student to a resubmission.

## Never invent evidence

Every judgement traces to a document you have actually read. If you cannot find
a student's submission for a tool, that is a **non-submission** — not a fail on
quality grounds, and not an assumption that it exists.

Record the path of the evidence you read in the ledger's `evidence` field. It is
the audit trail for the judgement, and it is what makes "I read it" checkable.

## Suspected AI-generated responses

**The rule, as the RTO wrote it:** check each written response for sentence
length and construction. If any single sentence contains more than four commas,
flag that response as AI generated.

A flagged response is treated as not the student's own work:

- the question is marked **NYS**;
- it is listed on the Student Feedback Sheet for redo, with the issue recorded
  as **"Response does not appear to be your own work — rewrite in your own
  words."**;
- the flag is noted in the SAR feedback and in the marking record Comments column.

Apply the flag to the **individual response**, not automatically to the whole
submission — but if a response is flagged, the tool containing it is NYS, and
the overall result follows the rules in [result-rules.md](result-rules.md).

### What the rule measures, and what it does not

Comma count is a proxy for sentence complexity, not for authorship. Understand
its two failure directions before you act on a flag:

- **False positives.** "I checked the eggs, the flour, the sugar, the butter,
  the milk and the vanilla" is six commas and plainly the student's own work.
  Lists, and any sentence with several parenthetical asides, trip the rule.
- **False negatives.** Generated text written in short sentences passes.

`scripts/Test-AiFlag.ps1` therefore reports every hit **with the sentence that
triggered it**, and every flag is an assessor decision to confirm or dismiss
before it reaches a ledger. Confirmed flags go into the ledger's `aiFlagged`
array; dismissed ones do not. A flag put into the ledger is a finding the
assessor is signing for, so look at the sentence.

Marking a student NYS for authorship is a serious call with consequences for
their enrolment. Where the sentence that tripped the rule is plainly a list or
plainly the student's own voice, dismiss the flag and say so in the assessor
comments.

## Related

- [result-rules.md](result-rules.md) — what a judgement turns into
- [feedback-writing.md](feedback-writing.md) — how to write it up
