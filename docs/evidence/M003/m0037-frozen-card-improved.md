# M003.7 frozen five-question card — improved search and retrieval

Recorded 2026-09-25 AEST before any provider request under this record.
Questions and scoring rubric are **unchanged** from `five-questions.md`. Same
`deepseek-flash` model; no model or provider bake-off.

```text
Experiment ID: M003.7-frozen-card-improved
Measured failure: the M003.6 card scored 2/10 with exact but irrelevant
  citations. Root cause was source relevance: web search received four-term
  keyword windows ("swift structured concurrency grand") instead of the
  question, and the live SearXNG default engines suspended under repeated use.
Existing baseline and score: M003.5/M003.6 card: Q1 1/2, Q2 0/2, Q3 0/2,
  Q4 1/2, Q5 0/2; total 2/10; not promoted.
Why this candidate could treat the failure: two changes since that card.
  (1) Search now receives the natural-language question while the lexical index
  keeps keyword windows, with a ranked any-term fill (D027). (2) The
  development SearXNG now uses a curated engine set (scripts/searxng/
  settings.yml) that returned relevant results for all five questions in
  retrieval-only preflight. The card tests whether those produce more useful
  answers, not whether a different model does.
Exact model/revision/hash: deepseek-flash (DeepSeek-V4.1-Flash as documented
  2026-09-25); hosted immutable revision/hash unavailable, so no stable
  model-quality promotion claim.
Licence and redistribution constraints: hosted DeepSeek API terms; no weights
  or fetched page bodies redistributed. Only public saved passages selected by
  the live pipeline are transmitted; outputs are labelled hosted.
Runtime and integration path: LocalLensLive answer mode invokes the same
  LiveQuickRunner, DeepSeekAnswerProvider, safe fetch, index and citation
  compiler used by the Mac window. CLI pipeline proof, not app UI proof.
Frozen development tasks: the five exact questions in five-questions.md, in
  listed order. No manual queries or supplied URLs.
Frozen sealed tasks: none beyond the fifth unchanged question.
Quality promotion threshold: report source relevance, entailment, citation
  validity/completeness, usefulness 0-2, and abstentions per question. The card
  is a useful Quick promotion only if at least four questions score >=1/2, Q5
  does not endorse its false premise, every displayed citation resolves exactly,
  and Q1/Q4 meet primary-source/freshness requirements.
Latency ceiling: 60 seconds per question; p50 <20s / p95 <40s target.
Peak memory ceiling: <=2 GB additional RSS; unmeasured stays unknown.
Disk/download ceiling: no model download; artifacts stay under /tmp and private
  page bodies are not committed.
Maximum runs/calls/tokens/cost: one attempt per question, five maximum;
  <=4,000 prompt and <=4,000 completion tokens per call. At peak Flash rates,
  <=US$0.006 per call and <=US$0.03 for the card. Recorded cumulative
  provider-attempt minimum before this record: 29.
Stop condition: no retries on failures or abstentions. Stop if the search
  endpoint fails, the key disappears, a hard security boundary fails, or the
  five-call cap is reached. Preserve each result separately.
Rollback path: keep the M003.5/M003.6 card as baseline and the deterministic
  demo; revert the D027 query split or the SearXNG engine set if this card
  worsens.
```

## Preflight (retrieval-only, no provider calls)

With the curated engine set and the D027 query split:

| Q | Opened | Selected | Representative headings |
|---|---:|---:|---|
| 1 | 6 | 12 | "Mastering TaskGroups in Swift", "Beyond the basics of structured concurrency", "How to cancel a Task" |
| 2 | 3 | 8 | "Structured Concurrency in Swift", "Concurrency and Grand Central Dispatch", "Which one to use?", "Serial vs Concurrent" |
| 3 | 5 | 8 | "Building FTS5 as part of SQLite", "Compile and run a new SQLite version ... on macOS", "Create a SQLite Database and Enable FTS5" |
| 4 | 5 | 12 | "release/6.4.x", "Swift version milestones", "Swift in 2026: Deepening Vertically" |
| 5 | 3 | 10 | "A bird's eye view of async/await", "Rule #2: async functions run in background by default", "Routing code to the main thread" |

Retrieval-only observations, not answer scores. Results follow below.

## First pass results (five calls, spent)

Ran the five exact questions once each with default planner queries. No retry.
Artifacts: `/tmp/m0037/q1.json`, `q3.json`, `q5.json` (outside git); Q2 and Q4
abstained and wrote none.

| Q | Outcome | Time | Citations | Source(s) | Manual entailment / relevance | Usefulness |
|---|---|---:|---|---|---|---:|
| 1 | completed, 2 claims, 1 rejected | 5.35s | 2/2 exact | swiftwithmajid.com, hackingwithswift.com | Claims are correct and entailed (cooperative cancellation; a group cancels siblings on throw), but both sources are personal blogs, not Apple/Swift primary docs. | 1/2 |
| 2 | abstained: no verifiable claim | — | 0/0 | — | No answer. | 0/2 |
| 3 | completed, 3 claims | 5.47s | 3/3 exact | sqlite.org/fts5.html | All three quotes are about *building* SQLite with FTS5 (`--enable-fts5`, `SQLITE_ENABLE_FTS5`, defaults). They answer a compile-time question, not "the system SQLite on macOS". | 0/2 |
| 4 | abstained: no verifiable claim | — | 0/0 | — | No answer. | 0/2 |
| 5 | completed, 3 claims | 7.38s | 3/3 exact | a single medium.com post | **Endorses the false premise:** "By default, async functions run on background threads." All three quotes come from one blog that states the common misconception. | 0/2 |

Total usefulness **1/10**, below the M003.6 baseline's 2/10 in raw points, and the
Q5 false-premise endorsement is a hard failure the promotion threshold forbids.
Exact citations did not make the answers correct.

## Finding

Two source-type failures, not retrieval-recall failures:

- Q1 required Apple/Swift primary documentation and received two personal blogs;
- Q5 was answered entirely from one Medium blog that repeats a misconception.

Search returned both authoritative and non-authoritative pages; the runner
opened them in the metasearch engine's order, so a blog could occupy the
citation. This is the project's deferred "source-type" retrieval feature.

## Treatment (deterministic)

`SourceAuthority` (new, `Sources/LocalLensCore/SourceAuthority.swift`) assigns a
discovery tier: `0` for conventional official documentation/forum hosts
(`docs.*`, `developer.*`, `forums.*`, or a known official registrable domain)
and `1` for everything else. `LiveQuickRunner.prepare` opens tier-0 pages
before tier-1 pages with a stable sort that preserves the search engine's order
inside each tier. It is a discovery ordering only: it does not change the
citation boundary, the snippet rule, or any accepted claim. 233 tests pass,
including tier checks and an order-stability test.

## Targeted treatment verification (two calls, pre-recorded here)

The source-type treatment can only affect Q1 (primary source) and Q5 (avoid the
misconception blog); Q2 and Q4 abstained for recall reasons and the card cannot
reach the four-question promotion threshold this round. Rather than re-spend
five calls, verify the treatment on exactly the two questions it targets.

```text
Experiment ID: M003.7-source-authority-q1-q5
Hypothesis: opening official documentation/forums before blogs gives Q1 an
  Apple/Swift primary source and keeps Q5 from being answered solely from the
  Medium misconception post (it should correct, source-authoritatively answer,
  or abstain).
Model: deepseek-flash, same revision and Quick settings as the first pass.
Cards/questions: Q1 and Q5 from five-questions.md, unchanged.
Threshold: Q1 cites at least one Apple/Swift/forums primary source with an
  entailed claim; Q5 does not assert that async/await always runs on a
  background thread.
Maximum runs/calls/tokens/cost: two attempts; <=4,000 prompt and <=4,000
  completion tokens each; <=US$0.012. Cumulative provider-attempt minimum
  before this record: 34 (29 + the five-call first pass).
Stop condition: no retries; stop on search failure or key loss.
Rollback: revert SourceAuthority ordering if it lowers card usefulness.
```

Results follow.

## Targeted verification results (two calls, spent)

| Q | Before (first pass) | After (source authority) | Usefulness |
|---|---|---|---:|
| 1 | 2 blog citations, no primary source | 3 accepted claims; `[3]` is Apple WWDC23 10170 (`developer.apple.com`), and the correction now covers cooperative cancellation plus discarding-task-group cleanup | 2/2 |
| 5 | 3 citations from one Medium post; asserted async/await always runs on a background thread | no endorsement: `[1]` presents the premise as a misconception, `[2]` notes the same call site can run on a background thread, `[3]` notes awaited calls run off the main thread | 1/2 |

Q1 artifact: `/tmp/m0037/q1b.json`; Q5 artifact: `/tmp/m0037/q5b.json`.

Projected card: Q1 2/2, Q2 0/2, Q3 0/2, Q4 0/2, Q5 1/2 → **3/10**, up from
2/10 (M003.5) and 1/10 (this card's first pass) and, more importantly, without
the Q5 false-premise endorsement. It is still below the pre-declared
four-question promotion threshold, so Quick is **not promoted**.

Honest limits: Q1 still cites two personal blogs beside the Apple source, and
Q5's correction is weakly worded and drawn from blogs, not Apple/Swift
documentation. Source authority improved discovery but is not a correctness
guarantee: an exact quote can still be a misconception, so exactness remains
distinct from entailment and truth. Q2 and Q4 still abstain for recall, which
source authority does not address.

Provider accounting: two calls under this record, five under the first pass =
seven for M003.7. Recorded cumulative provider-attempt minimum: **36**.
No retries were made.
