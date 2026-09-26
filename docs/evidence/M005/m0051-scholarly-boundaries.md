# M005.1 - Scholarly metadata boundaries for Academic mode

Date: 2026-09-26 (Australia/Sydney)
Working tree: uncommitted on top of `5e79633`. Nothing staged or committed.

## What was built

| Boundary | File | Kind |
| --- | --- | --- |
| arXiv Atom discovery (versionless abs URL) | `Sources/LocalLensCore/ArxivSearchAdapter.swift` | new |
| Crossref DOI discovery (canonical resolver) | `Sources/LocalLensCore/CrossrefSearchAdapter.swift` | new |
| DOI/arXiv identity and deterministic reconciliation | `Sources/LocalLensCore/ScholarlyReconciliation.swift` | new |
| Three-provider Academic composition with a run-scoped scholarly budget | `Sources/LocalLensCore/LiveQuickComposition.swift` | edited |

No key is required by either provider. Neither adapter consumes an abstract,
summary, or author field: scholarly metadata is discovery only, and every
scholarly claim still requires an exact passage from a fetched snapshot.

Identity rules: a DOI is lowercased and stripped of `doi:`/resolver prefixes;
an arXiv identifier is versionless (`2401.12345v2` == `2401.12345v3`). Crossref
emits the canonical `https://doi.org/<doi>` target because that URL carries the
identity, and the bounded fetch then follows the resolver redirect and records
the publisher URL it actually landed on.

## Measured effect

```text
$ TAVILY_API_KEY=... ./.build/debug/LocalLensLive --mode research --plan academic \
    --question "spaced repetition for long-term recall"
mode=research plan=Academic elapsed_s=17.77
opened_sources=9 passages=24
coverage=Method: 9, Limitations: 0, Findings: 4
fetch stored  https://doi.org/10.32614/r.manuals
fetch stored  https://doi.org/10.1017/s0140525x01003922
fetch stored  https://arxiv.org/abs/1410.1490
fetch stored  https://arxiv.org/abs/cs/0408054
fetch stored  https://en.wikipedia.org/wiki/Spaced_repetition
fetch refused kind=http_status      https://doi.org/10.1037/0033-2909.132.3.354
fetch refused kind=no_readable_text https://doi.org/10.1016/j.lmot.2026.102310
fetch refused kind=published_rule   https://www.sciencedirect.com/science/article/abs/pii/S187712972500231X
```

A first attempt with all three providers and no reservation was a measured
regression: scholarly targets filled all 14 fetch slots, the readable
general-web fallback was never opened, and only **3** passages were selected.
The treatment is a run-scoped scholarly budget (at most 8 targets, split 3/2/2
across OpenAlex, arXiv, and Crossref) that leaves at least six opened-source
slots for the web fallback. The regression is preserved here because it is the
reason the reservation exists.

## Deterministic verification

- `testArxivDecodeBuildsVersionlessAbstractHitsAndRejectsNonAbstracts`
  (versionless URLs, listing page skipped, malformed XML fails closed);
- `testCrossrefDecodeNormalizesDOIAndUsesTheResolverAsIdentityAnchor`
  (DOI normalization, missing DOI skipped, malformed JSON fails closed);
- `testScholarlyIdentityIsCaseAndVersionInsensitive`;
- `testReconciliationCollapsesIdentityBearingDuplicatesDeterministically`
  (one DOI across providers is one work; two arXiv versions are one work; a
  publisher URL without identity is not merged).

`swift test`: **268 tests, 0 failures**.

## Preserved failures and open gates

- `Limitations` coverage is still 0 on the probe, and many publisher targets
  remain refused as `http_status`, `no_readable_text`, or `published_rule`.
- PDF/page-aware evidence, DOI-version reconciliation beyond arXiv's `vN`, and
  BibTeX/RIS export are **not** built; a paper's claim still needs an HTML page.
- The scholarly budget constants (8 total, 3/2/2) are measured, not proven
  optimal; no held-out academic card exists yet.

## Proof boundary

Implemented: the two adapters and reconciliation.
Deterministically verified: 268 tests.
Locally measured: the 24-passage, 9-source Academic run above.
Live-provider verified: arXiv, Crossref, OpenAlex, and Tavily.
Not packaged or reproduced on a second machine.
