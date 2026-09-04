# Looking up a unit's prerequisites

Every unit this skill marks gets its **Pre-requisite unit** field read from
training.gov.au before any marking starts. Not only units someone suspects have
one. It is a standing step in the workflow, not an exception path.

```bash
powershell -File scripts/Get-UnitPrerequisites.ps1 -Unit SITHPAT016
```

## Why this is not a one-line fetch

training.gov.au is a client-rendered Nuxt application. A plain GET of the page a
human reads:

```
https://training.gov.au/training/details/CPCCOM1014/unitdetails
```

returns **HTTP 200 and about 3.3 KB of empty shell** — a viewport tag, a
stylesheet list, `<div id="__nuxt"></div>`, and nothing else. The string
`prerequisite` appears in it **zero times**.

That is the trap. The request succeeds. Nothing errors. A lookup written against
that page finds no Pre-requisite unit field, and an implementation that treats
"field not found" as "no prerequisite" concludes the unit has none — silently,
and for every unit it is ever asked about.

## What is actually used

The page's own JSON API, discovered by watching what the browser requests:

```
https://training.gov.au/api/training/<UNITCODE>?api-version=1.0&include=all
```

It returns, among much else:

```jsonc
"preRequisites": {
  "hasPreRequisites": true,
  "isPreRequisite": false,
  "preRequisites": [
    { "code": "SITXFSA005", "title": "Use hygienic practices for food safety" }
  ]
}
```

The endpoint was found from the site's own runtime configuration, which the
shell does carry:

```
window.__NUXT__.config.public.apiBaseUrl = "/api"
```

No key, no authentication, no scraping of rendered HTML. If the endpoint ever
moves, the way to find its replacement is the same: open the unit page in a
browser and read the network requests.

### Why not the other two options

- **The downloadable unit release file** is a `.docx` in a zip, one per release.
  Correct, but it means resolving the current release, downloading, unzipping and
  parsing prose to find a field the API already returns as data.
- **A headless browser render** works and is the heaviest option. It needs a
  browser on every machine that marks, which `INSTALL.md` currently does not
  require.

The API is used because it is the lightest thing that returns the field itself
rather than a rendering of it.

## Nil means Nil. Nothing else does.

| Outcome | Status |
|---|---|
| `hasPreRequisites` false **and** an empty list | `none` — the register says Nil |
| one or more units listed | `found` |
| empty response, failed request, timeout, redirect, unit not found, no `preRequisites` object, or `hasPreRequisites` true with nothing listed | **`unknown`** |

**`unknown` stops the run.** It does not default to `N/A`, it does not infer from
the unit's name or its training package, and it is never cached — a cached
unknown would look like an answer the next time someone ran it.

The script exits `2` on unknown and prints what to do: ask the assessor to
confirm the prerequisite from the unit of competency itself or the training
package companion volume, and record it in the ledger.

## The cache

Successful lookups are written to `assets/prerequisites.cache.json`, keyed by
unit code, each carrying the endpoint it came from and the date it was read:

```jsonc
"SITHPAT016": {
  "unit": "SITHPAT016",
  "status": "found",
  "prerequisites": [ { "code": "SITXFSA005", "title": "Use hygienic practices for food safety" } ],
  "source": "https://training.gov.au/api/training/SITHPAT016?api-version=1.0&include=all",
  "checkedOn": "2026-09-02"
}
```

A marking run is then reproducible, and an auditor can see when the check was
made. `-Refresh` bypasses the cache and re-reads the register.

## What the ledger carries

```jsonc
"unit": {
  "code": "SITHPAT016",
  "title": "Produce desserts",
  "coreElective": "Elective",
  "prerequisites": [
    { "code": "SITXFSA005", "title": "Use hygienic practices for food safety" }
  ],
  "prerequisiteSource": "training.gov.au",
  "prerequisiteCheckedOn": "2026-09-02"
}
```

An empty `prerequisites` array is accepted **only** alongside an explicit
`"prerequisitesConfirmedNone": true`. Without it the resolver refuses:

> `unit.prerequisites` is empty and `prerequisitesConfirmedNone` is not set.
> Confirm on training.gov.au whether SITHPAT016 has a prerequisite. A blank array
> is not a statement that there is none.

The retired free-text `"prerequisite": "N/A"` is accepted for one release with a
deprecation CHECK, then rejected. It is retired because `N/A` could not tell
*the register says Nil* apart from *nobody checked*.

**The shipped example ledger had exactly that error.** It read `"N/A"` for
SITHPAT016, which does have a prerequisite — SITXFSA005. The lookup found it on
the first run.

## Related

- [ledger.md](ledger.md) — where the answer is recorded
- [wisenet-roll.md](wisenet-roll.md) — confirming each student *holds* the prerequisite
- [result-rules.md](result-rules.md) — what a missing prerequisite does to the result
