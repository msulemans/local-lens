# M003.9 frozen Q2 two-sided retrieval, provider-free

Recorded 2026-09-26 AEST. The unchanged Q2 asks how Swift structured
concurrency and Grand Central Dispatch differ for CPU-bound work. Its previous
default one-query retrieval returned variable, mostly third-party pages and
did not assure independent two-sided coverage (M003.8 diagnostic). A previous
two-query provider-free probe found Swift Forums and Apple dispatch docs in
the existing Quick two-query cap. That was the hypothesis, not a scored answer.

Treatment: only when the question explicitly contains Swift concurrency,
Grand Central Dispatch, and CPU-bound terms, web discovery uses one query per
side. The local lexical queries, source cap, provider prompt, citation
compiler, and frozen card remain unchanged. A deterministic test pins the
exact two queries, the one-query cap, and the unrelated-question fallback.

One post-treatment default CLI retrieval, no DeepSeek call:

```text
mode=retrieve elapsed_s=14.54
search_queries=2 opened_sources=4 passages=9
stored: two Swift Forums pages, one Apple WWDC Swift concurrency page,
        one Apple archived concurrency programming guide
refused: Apple Swift concurrency and Dispatch reference pages
         (extraction/no_readable_text)
selected: Swift Forums CPU-bound task/yield passage, Apple archived
          dispatch-queue passages, and some generic/noisy passages
```

This establishes that both sides were discovered and stored in this one live
run; it does **not** establish an answerable, adequately attributed comparison.
The selected Apple dispatch passages were mostly general queue descriptions,
and two Apple reference pages could not be extracted. The source-order and
quality gate therefore remain open. No answer-provider run, token spend,
frozen-card usefulness score, or promotion follows from this retrieval.
