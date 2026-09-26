# M007.2 - Content-term coverage, numeric contrasts, diminishing returns

Date: 2026-09-26 (Australia/Sydney)
Working tree: uncommitted. Nothing staged or committed.

## Treatment 1: coverage now reads content terms (shipped)

`DimensionLexicon` gives each scaffold dimension a fixed, in-code term list, and
`ResearchRunner.coverage` matches a dimension when either its label or one of its
terms appears. A user's own dimension falls back to its own content terms, so a
custom plan is not silently uncovered.

Measured on the same Deep question before and after:

| Run | Overview | Evidence | Tradeoffs | Gaps |
|---|---|---|---|---|
| before | 0 | 0 | 0 | 1 |
| after | 1 | 4 | 2 | 1 |

The earlier false zeros also caused a wasted follow-up round; the run now reaches
`gaps=[]` and stops after one round. Academic coverage likewise moved to
`Findings 18, Limitations 7, Method 9` on the retrieval-practice question where
`Limitations` had previously been near zero.

## Treatment 2: diminishing returns (shipped)

A follow-up round that adds half or less of what the previous round added (when
the previous round added at least four passages) stops the loop with the typed
reason `diminishing_returns`, which the brief explains. Covered by
`testDiminishingFollowUpStopsWithATypedReason`.

## Treatment 3: numeric contrasts (shipped strict, measured unusable when loose)

`ContradictionScan` extracts a number with the words it quantifies and pairs two
pages that state different values for the *same* context. Three variants were
implemented and measured against live pages:

1. **Strict** — identical context words (up to four before, three after), cross
   page, different value, citation-list years excluded. Found **no pair** on four
   live runs (SQLite Deep, retrieval practice Academic, vocabulary spacing
   Academic, and a repeat of the first). Verified by fixture:
   `400 write transactions per second` against `1200 write transactions per
   second` is one contrast, and a single passage restated is none.
2. **Shared sentence terms (≥3)** — produced citation-list noise:
   `2000, 2005, 2006, 2007, 2008` against `1978`, and
   `1999, 2005` against `1999`, with contexts like `bjork` and `after`.
3. **Shared unit word plus different measured values** — still produced
   contexts `after`, `first`, `memory`, and `bjork`, pairing unrelated numbers
   such as `2, 71` against `0, 18, 3, 7`.

Variants 2 and 3 assert a disagreement the evidence does not contain, so neither
ships. The strict variant ships and the surface stays empty when it has nothing
to show. This is a measured negative result: a deterministic numeric-contradiction
detector that is useful on real web pages was not achieved in this milestone.

## M007 gate status

- every loop terminates with a typed reason — **met** (M007.1);
- repeated queries and sources cannot consume unlimited budget — **met**;
- injected failures resume without duplicated evidence — **met** (M007.1 test);
- contradictions are not silently flattened — **partially met**: a strict,
  fixture-tested detector ships and nothing is averaged or resolved, but live
  detection was not demonstrated and two looser variants were measured unusable;
- controlled long-form benchmarks and manual review reported separately —
  **not started** (that is M008's studio).

`swift test`: **290 tests, 0 failures** (287 before this milestone).

## Proof boundary

Deterministically verified: 290 tests.
Locally measured: coverage before/after on one Deep question, four live strict
contrast runs, and the two rejected variants' output.
Live-provider verified: Tavily discovery.
No hosted answer call was made; the cumulative hosted minimum stays **39**.
