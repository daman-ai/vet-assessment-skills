# The RTOs' approved templates

Each registered RTO needs three approved, **blank** Word documents here. They are
controlled documents: the builder fills their fields and never rebuilds them, and
the gate's `TemplateUntouched` check hashes every part except `word/document.xml`
and `docProps/` back against the file in this folder.

## What is here

All three registered RTOs are supplied and measured, and each has been built and
gated end to end.

| RTO | `sar` | `amrr` | `feedback` |
|---|---|---|---|
| `mvc` | `MVC_SAR_Template.docx` | `MVC_AMRR_Template.docx` | `MVC_Feedback_Template.docx` |
| `aci-culinary` | `ACI_Culinary_SAR_Template.docx` | `ACI_Culinary_AMRR_Template.docx` | `ACI_Culinary_Feedback_Template.docx` |
| `aci-construction` | `ACI_Construction_SAR_Template.docx` | `ACI_Construction_AMRR_Template.docx` | `ACI_Construction_Feedback_Template.docx` |

Measured 1 September 2026. Each measurement is recorded in its own
`../rto.<key>.json`.

## The three sets are not interchangeable

They look alike and they are not. Copying one profile's map onto another RTO
produces documents that pass most of the gate and are still wrong:

| | `mvc` | `aci-culinary` | `aci-construction` |
|---|---|---|---|
| SAR tables | 5 | 6 | 6 |
| SAR certification / admin | tables 4 and 5 | tables 5 and 6 | tables 5 and 6 |
| Feedback sheet tables | 2 | 3 | 3 |
| Feedback item rows live in | the details table | their own table | their own table |
| RTO row | pre-filled | pre-filled | `[ Insert RTO name and code ]` |
| Placeholder grey | `8E96A3` | `9AA3B2` | `8A939C` |

The placeholder grey is the one that fails quietly: `NoPlaceholderStyling` looks
for that exact value, so the wrong one leaves the gate blind to a field that was
never filled.

## Adding an RTO, or replacing a revised template

Follow [../../references/onboarding-rto.md](../../references/onboarding-rto.md).
In short: drop the file in, measure it, paste the measurement into
`assets/rto.<key>.json`, and only then delete that profile's `status` line.

```bash
powershell -File scripts/Measure-Template.ps1 -Path assets/templates/<file>.docx
```

**A revised template must be re-measured in the same change.** A stale map fills
the wrong cell, and the builder's structural throws are the only thing standing
between a revised template and a silently mis-filled record.
