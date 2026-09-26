# M008.1 - Benchmark runner, per-mode scorecard, corruption checks

Date: 2026-09-26 (Australia/Sydney)
Working tree: uncommitted. Nothing staged or committed.

## Treatments

1. **Benchmark card** (`BenchmarkCard`). A card is JSON data: named questions,
   each with the mode it must run in and human-authored check labels that are
   copied into the scorecard and never used to score anything automatically.
   Malformed cards are refused with a typed error rather than partially loaded.
2. **Scorecard** (`BenchmarkScorecard`). Per question it records citations,
   accepted and rejected claims, latency, opened sources, passages, the typed
   stop reason, and whether every citation resolved. Answer usefulness stays
   `nil` until a human scores it, and is reported only over the questions that
   were actually scored, so an unscored card can never look like a good one.
   Citation integrity, usefulness, and latency are separate fields and there is
   no combined number. The JSON has one `label` per document, so a local run and
   a hosted run are two documents, never one average.
3. **Corruption checks** (`CitationBoundaryCheck`). Takes a valid compilation,
   makes exactly one thing wrong, and reports whether the boundary refused it:
   an altered quote (one character), a link to a passage that was never stored,
   an evidence link naming a different claim than the citation, and a citation
   identifier that is not in the compilation.
4. **Runner** (`--mode benchmark --card <file> [--out <file>]`). Replays the card
   against one path, prints a per-question line, writes the scorecard JSON, and
   prints its summary.

## Measured

Frozen five-question card replayed against the **local** model at US$0
(`docs/evidence/frozen/five-questions.json`), scorecard preserved at
`docs/evidence/M008/scorecard-local-2026-09-26.json`:

| Question | Mode | Citations | Accepted | Rejected | Elapsed | Stop reason |
|---|---|---|---|---|---|---|
| Q1 retrieval practice | Academic | 1 | 1 | 1 | 70.67 s | evidence_saturated |
| Q2 LLM reasoning | Academic | 3 | 3 | 5 | 102.65 s | evidence_saturated |
| Q3 vocabulary spacing | Academic | 1 | 1 | 1 | 71.30 s | evidence_saturated |
| Q4 untested language | Deep | 0 | 0 | 0 | 42.00 s | abstained: the provider proposed no verifiable claim |
| Q5 false premise | Deep | 0 | 0 | 0 | 27.87 s | abstained: the provider proposed no verifiable claim |

- Citation integrity: **100%** (every citation resolved to an exact stored
  passage).
- Usefulness: **unscored** — this run has no human labels, and the card says so
  instead of inferring a score from citation counts.
- Median latency 70.7 s; total 314.5 s.
- Q4 abstaining is the wanted behaviour (the question asks about a language
  nobody has tested). Q5 abstaining means the false premise was not accepted.
  Both are recorded as abstentions, not as answers.
- Rejected claims are now visible in the scorecard (7 across the three answered
  questions), which the earlier card could not show.

## Gate status (M008)

- integrity target is 100% — **met** on this card, and integrity is a hard
  refusal in the compiler rather than a score;
- semantic evaluator calibrated against held-out human labels — **not started**;
- answer and citation metrics are not collapsed — **met** in the scorecard
  shape, and enforced by test;
- local and hosted results remain separate — **met**: the scorecard has one
  label per document;
- intentional corruptions are detected — **met** by
  `testValidCompilationResolvesAndEveryCorruptionIsDetected`, which requires all
  four corruptions to be refused.

## Proof boundary

Deterministically verified: 294 tests (290 before this milestone).
Locally measured: one full five-question replay against the local model at US$0.
Live-provider verified: Tavily discovery inside the replay.
No hosted answer call was made; the cumulative hosted minimum stays **39**.
