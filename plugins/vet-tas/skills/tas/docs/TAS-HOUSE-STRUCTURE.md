# House TAS structure

The structure every Training and Assessment Strategy is rebuilt to. It is **derived from
the RTO's own eighteen documents**, not imported from a template: each section below is
one the RTO already uses, and the order is the median position that section occupies
across the eighteen.

Two institutes, one structure. Only the masthead, RTO code, CRICOS code, legal entity and
trading name differ — the same rule already applied to the courses themselves.

| | |
|---|---|
| Adelaide Construction Institute | RTO 45797 · CRICOS 03978F · Bush Tukka Pty Ltd |
| Adelaide Culinary Institute | RTO 45797 · CRICOS 03978F · Bush Tukka Pty Ltd |
| Meridian Vocational College | RTO 45039 · CRICOS 03551M · Golden Wattle Group Pty Ltd |

## Where each section's content comes from

- **REGISTRY** — generated from the curriculum registry. Regenerating the TAS regenerates
  these, so they cannot drift from what is actually taught.
- **CARRIED** — the RTO's own words, carried across from that course's existing TAS.
- **HOUSE** — identical across every course for an institute; write once, reuse.

## The naming problem this fixes

ACI and Meridian largely use **different names for the same section**. The merge below is
what makes one structure possible without losing anything:

| ACI writes | Meridian writes | Canonical |
|---|---|---|
| Target Learner: | Target learners | Target learner group |
| Assessment Method: | Assessment methods | Assessment methods |
| Training product: | Qualification / Qualification title | Training product |
| Trainer ratio: | Trainer ratio and rules for variation: | Trainer ratio |
| Mandatory work placement requirements: | Work placement | Work placement |

---

## Section order

### Part 1 — Identification

| # | Section | Source |
|---|---|---|
| 1.1 | RTO name, number, CRICOS code, legal entity | HOUSE |
| 1.2 | Training product — code, title, AQF level | REGISTRY |
| 1.3 | Training package — code, title, release | REGISTRY |
| 1.4 | National register currency — date checked, by whom | REGISTRY |
| 1.5 | TAS version, prepared by, approved by, next review date | CARRIED |
| 1.6 | Delivery period and delivery site(s) | CARRIED |

### Part 2 — The learner and the outcome

| # | Section | Source |
|---|---|---|
| 2.1 | Qualification description and job roles | REGISTRY |
| 2.2 | Target learner group — cohorts, employment status, reason for learning | CARRIED |
| 2.3 | Target learner group size, minimum and maximum | CARRIED |
| 2.4 | Training package entry requirements | REGISTRY |
| 2.5 | Pre-existing knowledge and skills / level of industry experience | REGISTRY |
| 2.6 | Qualification pathway — what it leads to, what it comes from | REGISTRY |
| 2.7 | Licensing, legislative or regulatory requirements | REGISTRY |
| 2.8 | Language, literacy and numeracy — communication, reading, writing, numeracy | HOUSE |

### Part 3 — What is taught, and in what order

**This part is generated in full. It is the part that was wrong in most documents.**

| # | Section | Source |
|---|---|---|
| 3.1 | Packaging rules and how this course meets them | REGISTRY |
| 3.2 | Unit structure — code, title, core or elective, delivered or credit transfer | REGISTRY |
| 3.3 | Delivery sequence — themes, week ranges, units in each | REGISTRY |
| 3.4 | Why this order — prerequisites, and topics taught before they are recalled | REGISTRY |
| 3.5 | Credit transfer from the qualification below, and the units it covers | REGISTRY |
| 3.6 | Superseded units and transition arrangements, with review dates | REGISTRY |
| 3.7 | Mode of delivery | CARRIED |
| 3.8 | Course duration | REGISTRY |
| 3.9 | Amount of training and volume of learning, against the AQF benchmark | CARRIED |
| 3.10 | Work placement — service periods, supervision, records | CARRIED |
| 3.11 | Training method | CARRIED |
| 3.12 | Possible delivery variation | HOUSE |

### Part 4 — Assessment

| # | Section | Source |
|---|---|---|
| 4.1 | Assessment methods — practical demonstration, portfolio, written report, project work, role play, presentation and observation | HOUSE |
| 4.2 | Assessment briefing requirements | HOUSE |
| 4.3 | Coordination requirements | CARRIED |
| 4.4 | Recording and reporting requirements | HOUSE |
| 4.5 | Reassessment guidance | HOUSE |
| 4.6 | Reasonable adjustment guidance | HOUSE |
| 4.7 | Industry benchmarks for assessment | CARRIED |
| 4.8 | Assessment validation — schedule, who, against what | CARRIED |
| 4.9 | Recognition of prior learning | HOUSE |

### Part 5 — Resources

| # | Section | Source |
|---|---|---|
| 5.1 | Learning resources | CARRIED |
| 5.2 | Assessment resources | CARRIED |
| 5.3 | **Trainers and assessors** — credentials, currency, competencies | CARRIED — **the only section that may differ between institutes on a shared qualification** |
| 5.4 | Trainer ratio | CARRIED |
| 5.5 | Facilities | CARRIED — harmonised |
| 5.6 | Equipment | CARRIED — harmonised |
| 5.7 | Consumables | CARRIED — harmonised |
| 5.8 | Provided by the learner | CARRIED — harmonised |
| 5.9 | Financial — fees, refunds, what is included | CARRIED |

### Part 6 — Review

| # | Section | Source |
|---|---|---|
| 6.1 | Industry consultation — who, when, what changed as a result | CARRIED |
| 6.2 | Collecting feedback from learners | HOUSE |
| 6.3 | Collecting feedback from trainers and assessors | HOUSE |
| 6.4 | Formal review requirements and next review date | HOUSE |
| 6.5 | Version control and change history | CARRIED |

---

## Rules the rebuild must hold

1. **Every section appears in every document**, in this order. A section with nothing to
   say says so explicitly — "Not applicable to this qualification, because …" — rather
   than being omitted, so an auditor can tell the difference between *considered and not
   applicable* and *forgotten*.
2. **Part 3 is never hand-edited.** It is generated from the registry. Editing a unit
   table by hand is how the documents drifted in the first place.
3. **A qualification delivered by both institutes gets identical Parts 2, 3, 4 and 5 —
   except trainers.** RTO decision of 8 September 2026: the kitchens, equipment and
   consumables are the same, so those sections are harmonised like the curriculum.
   **Section 5.3 Trainers and assessors is the only section that may legitimately differ
   between the two institutes**, because the people are different. Part 1 branding
   differs by definition.
4. **Nothing carried across is silently accepted.** Text moved from an old TAS that could
   not be matched to a section is marked `[CARRIED — CONFIRM]` in place.
5. **Every number that appears twice must reconcile.** Hours, weeks and unit counts are
   computed once and printed from the same source. Seven of the eighteen currently
   contradict themselves on hours; that is a symptom of the same figure being typed twice.

---

## Evidence for this structure

Derived on 8 September 2026 from all eighteen documents. Sections used in 12 or more of
the 18, with their median position, are the spine above. The full frequency and position
table is in `house-structure.csv` alongside this file.

Sections found in every one of the eighteen: mode of delivery, course duration, unit
structure, training method, possible delivery variation, learning resources, assessment
resources, consumables.
