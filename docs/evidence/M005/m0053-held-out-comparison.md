# M005.3 - Held-out academic comparison (M005 gate)

Date: 2026-09-26 (Australia/Sydney)
Working tree: uncommitted on top of `40c7ec3`. Nothing staged or committed.

## Frozen held-out questions

Frozen before either baseline was run. None was used to tune the planner, and
none overlaps the five frozen M003 questions.

1. What is the measured effect of retrieval practice on long-term retention?
2. How well do large language models perform on multi-step reasoning benchmarks?
3. What do randomized trials show about the spacing effect in vocabulary learning?

## Method

Provider-free retrieval only, so no answer model can be blamed for a retrieval
result. The scholarly path is `--mode research --plan academic` (OpenAlex +
arXiv + Crossref, reconciled, with a bounded general-web fallback). The baseline
is `--mode research --plan quick` with `--tavily` (generic web only, no
scholarly providers). Each path keeps its own frozen policy budget, so the
comparison is of precision and coverage, not of raw counts.

## Observed results

| Question | Path | Elapsed | Sources | Passages | Scholarly sources | Coverage |
|---|---|---|---|---|---|---|
| 1 retrieval practice | Academic | 31.96 s | 9 | 24 | 4 (arXiv ×2, PubMed, Bjork lab PDF) | Findings 5, Method 3, Limitations 0 |
| 1 retrieval practice | Web | 3.92 s | 5 | 6 | 1 (PubMed) | Answer 0 |
| 2 LLM reasoning | Academic | 89.76 s | 11 | 24 | 5 (arXiv ×4, ACL DOI) | Findings 8, Method 4, Limitations 2 |
| 2 LLM reasoning | Web | 2.08 s | 5 | 12 | 2 (arXiv ×2) | Answer 1 |
| 3 vocabulary spacing | Academic | 28.43 s | 11 | 24 | 9 (arXiv ×2, DOI ×2, ResearchGate ×2, ERIC PDF, Frontiers, PMC) | Findings 14, Method 3, Limitations 1 |
| 3 vocabulary spacing | Web | 2.76 s | 4 | 9 | 4 (ResearchGate ×2, ERIC PDF, Frontiers) | Answer 0 |

Scholarly-source share: Academic 18/31 = 58%, Web about 7.5/14 = 54%.

Every selected passage was a stored, exact passage in both paths; the ERIC PDF
produced page-headed passages (`Page 6`, `Page 8`) through the M005.2 PDF path,
including in the web baseline.

## Gate decision: **not met**

The M005 gate requires the academic held-out set to beat generic web search on
citation quality. On this frozen set the scholarly-first path produced more
primary sources and a three-dimension coverage scaffold (Findings, Method,
Limitations) instead of one `Answer` bucket, but the scholarly-source share is a
near tie (58% vs 54%), the web baseline surfaced the same key papers on question
3, and Academic cost 7-43× the latency. That is not a clear citation-quality
win, so **M005's gate is recorded as not met** and the negative result is
preserved rather than reframed.

## Measured defects worth treating next

- Academic opened aggregator and non-paper pages (ResearchGate, Medium, a
  `lacuna.tiptreesystems.com` survey mirror) that outranked primary sources in
  its own list.
- Latency is dominated by three providers per query across up to five queries;
  question 2 took 89.76 s.
- `Limitations` coverage was 0, 2, and 1, so the scaffold exists but the
  evidence does not fill it evenly.

## Preserved failures

- The no-clear-benefit result above.
- Publisher refusals (`http_status`, `no_readable_text`, `published_rule`).
- Academic treats a DOI resolver as the identity anchor and follows the
  redirect; a bot-walled publisher still yields no passage.
- No OCR, and no academic card with an answer model; this is retrieval only.

## Proof boundary

Deterministically verified: 273 tests (unchanged).
Locally measured: the six retrieval runs above, provider-free.
Live-provider verified: Tavily, OpenAlex, arXiv, Crossref.
The M005 gate is not met; M005 stays open with M005.4 as the next treatment.
