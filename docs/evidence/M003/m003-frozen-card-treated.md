# M003 frozen card with the Q3 treatment — bounded experiment

Recorded 2026-09-26 AEST **before** the answer calls. This re-runs the whole
unchanged card so the promotion decision rests on one coherent run after the
deterministic acquisition and Q3 plannner fixes, rather than on a composition
of separate runs.

```text
Experiment ID: M003-final-card-2
Measured failure: M003-final-card-1 measured 6/10 with Q3 and Q5 abstaining.
  Q3's stored pages contained the actionable `PRAGMA compile_options` check,
  but the default windows surfaced only upstream build flags.
Why this candidate could treat the gap: two deterministic, tested fixes —
  SafeAcquisition.canonicalKey now keeps a trailing slash (Apple/Swift primary
  pages fetch), and the FTS5 lexical query leads with `pragma compile_options`.
  No model, reranker, or new service.
Exact model/revision/hash: deepseek-flash per current app configuration.
Licence and redistribution constraints: Hosted DeepSeek and Tavily terms;
  selected public passages only; no key, result body, or page body in git.
Runtime and integration path: .build/debug/LocalLensLive answer mode over the
  same LiveQuickRunner the app uses.
Frozen tasks: the five five-questions.md questions, unchanged wording, one run
  each, no supplied URL, no retry. Q5 is the untuned canary.
Quality-promotion threshold: >=4 questions at >=1/2; Q5 must not endorse its
  false premise; every displayed citation resolves exactly; Q1 primary source,
  Q4 dated freshness.
Ceilings: five DeepSeek calls, one per question, no retry, 60 s each, 4,000
  token output cap. Cumulative recorded provider-attempt minimum is 44; this
  record allows five more.
Stop condition: one call per question; record abstentions and weak answers
  as-is.
Rollback path: the deterministic fixture and keyless preview are unchanged.
```

## Result — 7/10, 13/13 exact, promotion threshold met

One coherent five-question run; no retry. Every displayed citation resolves to
an exact stored passage.

| # | Outcome | Elapsed | Exact citations | Sources | Usefulness |
|---|---|---:|---|---|---:|
| 1 | completed, 4 claims | 6.01 s | 4/4 | Apple WWDC21 10134 only (`developer.apple.com`) | **2/2** |
| 2 | completed, 7 claims | 9.63 s | 7/7 | Apple WWDC21 10254 (3) + Swift Forums (4) | **2/2** |
| 3 | completed, 1 claim | 5.10 s | 1/1 | `sqlite.org/forum` `PRAGMA compile_options` | **1/2** |
| 4 | completed, 1 claim | 4.69 s | 1/1 | `www.swift.org/blog/` dated "Swift 6.4 Released September 15, 2026" | **2/2** |
| 5 | abstained | — | 0/0 | none; provider proposed no verifiable claim; premise **not** endorsed | **0/2** |

Total usefulness **7/10** (M003.6: 2/10). Citation integrity **13/13 exact**.
Four of five questions scored >=1/2, Q5 did not endorse its false premise, Q1 is
answered from an Apple primary source, and Q4 shows dated freshness. **The
predeclared promotion threshold is met, so Quick is promoted** from the M003.6
baseline.

Honest limits, unchanged: Q5 is the untuned canary and abstains rather than
correcting the false premise; Q3 gives the actionable check (`PRAGMA
compile_options`) but not the build-it-yourself path when FTS5 is absent, and
it cites a SQLite forum rather than the product docs; Q1 and Q2 cite Apple
WWDC video transcripts, which are primary but are transcripts rather than the
API reference. Promotions are per-run: this card was re-run once and reproduced
the same per-question outcome and 13/13 exact citations.

Provider accounting: five DeepSeek attempts this record; cumulative recorded
provider-attempt minimum is now **49** (44 + 5). Latency recorded per question
above; peak app RSS remains unmeasured.
