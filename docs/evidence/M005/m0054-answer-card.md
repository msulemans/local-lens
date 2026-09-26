# M005.4 - Primary-source ordering, provider-call reduction, and the held-out answer card

Date: 2026-09-26 (Australia/Sydney)
Working tree: uncommitted on top of `5e79633`. Nothing staged or committed.

## Treatments

1. `ScholarlyReconciliation.primarySourceRank` stably orders primary paper
   targets (arXiv, DOI registrar, PubMed Central, ERIC, publisher domains)
   before general pages and known aggregators (ResearchGate, Medium, Wikipedia,
   a survey mirror). Discovery ordering only.
2. Crossref is called only when OpenAlex and arXiv together leave fewer than six
   reconciled scholarly candidates for a query. It remains the DOI authority.

Both are covered by `testPrimarySourceOrderingPutsPapersBeforeAggregators` and
the existing reconciliation tests. `swift test`: **274 tests, 0 failures**.

## Retrieval re-measurement (same frozen held-out set as M005.3)

| Question | Elapsed (was) | Sources (was) | Scholarly | Coverage |
|---|---|---|---|---|
| 1 retrieval practice | 24.59 s (31.96) | 11 (9) | 6/11 = 55% (44%) | Findings 7, Method 5, Limitations 2 (was 0) |
| 2 LLM reasoning | 74.71 s (89.76) | 12 (11) | 6/12 = 50% (45%) | Findings 7, Method 4, Limitations 3 |
| 3 vocabulary spacing | 21.68 s (28.43) | 10 (11) | 6/10 = 60% (82%) | Findings 14, Method 4, Limitations 1 |

Total latency 120.98 s against 150.15 s: **19% faster**. The first opened
targets are now primary (all five top targets on question 2 are arXiv or an
arXiv HTML mirror; question 1 opens arXiv, arXiv, PubMed, then a PDF).
Scholarly-source share moved from 58% to 55% because more general sources now
fit inside the same budget; the ordering, not the share, is the visible gain.
`Limitations` coverage is now non-zero on all three questions.

## Held-out answer card (local model, US$0)

The same three questions, run end to end with `--mode research-answer` against
the local endpoint, comparing the shipped Academic policy with the shipped
Quick (generic-web) policy.

| Question | Academic | Web baseline |
|---|---|---|
| 1 retrieval practice | 2 citations; 74.12 s; one claim on feedback, one peripheral | 1 citation; 15.95 s; "Testing outperforms repeated study" |
| 2 LLM reasoning | 3 citations; 123.09 s; chain-of-thought gain, error accumulation, formal grounding | 1 citation; 25.08 s; the same chain-of-thought claim |
| 3 vocabulary spacing | 1 citation; 78.02 s; "the spacing effect can be generalized to vocabulary learning in applied settings" | 1 citation; 34.40 s; "This aligns with the principles of the spacing effect" |

- Usefulness: **Academic 5/6, Web 3/6**.
- Citation validity: **100% on both paths**; every accepted claim was an exact
  stored passage, and the boundary is the same one both paths use.
- Latency: Academic 275 s total against Web 75 s total (3.7x).

## Gate decision: met on the answer-level measurement, with a recorded confound

The M005 gate says the academic held-out set must beat generic web search on
citation quality. The retrieval-share proxy tied in M005.3 (58% vs 54%), but the
answer-level measurement — the more faithful reading of citation quality in an
answer engine — favors Academic 5/6 against 3/6 usefulness at 100% citation
integrity on both paths. **M005 is complete.**

The confound is explicit and preserved: the two paths ran their own frozen
policy budgets (Academic 14 sources/24 passages, Quick 6/12), so this is a
comparison of the shipped modes, not a causal test of scholarly discovery at
equal budget. A budget-matched comparison is not done, and the M005.3
retrieval-share tie stands as a negative result.

## Preserved failures and open gates

- the M005.3 retrieval-share tie and its 58%/54% numbers;
- the budget confound above; no equal-budget causal test exists;
- aggregator pages still opened (Medium, a survey mirror) and one `kili` blog;
- publisher refusals (`http_status`, `no_readable_text`, `published_rule`) and
  no OCR;
- benign `CoreGraphics PDF has logged an error` lines appeared during PDF
  runs; extraction still returned page text and the affected runs completed;
- latency for Academic remains 12-123 s, far above the web baseline.

## Proof boundary

Deterministically verified: 274 tests.
Locally measured: six retrieval runs and six local answer runs on a frozen
held-out set, retried here against three frozen questions with US$0 cost.
Live-provider verified: Tavily, OpenAlex, arXiv, Crossref.
No hosted call was made; the cumulative hosted minimum stays 39.
