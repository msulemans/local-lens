# M003 final frozen-card measurement — bounded experiment

Recorded 2026-09-26 AEST **before** the answer calls. This scores the unchanged
five-question card against the current no-Docker Tavily pipeline after the
deterministic acquisition fix below. It is a measurement, not a new model
comparison.

```text
Experiment ID: M003-final-card-1
Measured failure: The unchanged card was below threshold (M003.6 measured
  2/10; M003.7 projected 3/10). Provider-free retrieval on 2026-09-26 showed
  the retrieval half was depressed by a real acquisition bug: legitimate
  trailing-slash redirects on developer.apple.com, swift.org, and other hosts
  were refused as `redirect_loop`, so Q1 and Q4 never opened Apple/Swift
  primary pages.
Why this candidate could treat the gap: A deterministic fix to
  SafeAcquisition.canonicalKey (use URLComponents.percentEncodedPath so a
  trailing slash survives) makes those primary pages fetchable. Provider-free
  re-retrieval after the fix opened Apple WWDC21 10134 and WWDC23 10170 for
  Q1, Apple WWDC21 10254/2017 706/2016 720 for Q2, and the exact-misconception
  Swift Forums thread for Q5. No model, reranker, or new service is involved.
Exact model/revision/hash: deepseek-flash per current app configuration;
  hosted immutable revision/hash unavailable to this client.
Licence and redistribution constraints: Hosted DeepSeek API terms and Tavily
  search terms; selected public passages are sent to DeepSeek. No raw API
  result, fetched page body, or key enters git.
Runtime and integration path: .build/debug/LocalLensLive answer mode over the
  same LiveQuickRunner the app uses; Tavily basic search; safe fetch; FTS5
  lexical selection; citation compiler.
Frozen tasks: the five `docs/evidence/M003/five-questions.md` questions,
  unchanged wording, one run each, no supplied URL, no retry.
Quality-promotion threshold (predeclared): at least four questions score >=1/2;
  Q5 must not endorse its false premise; every displayed citation resolves to
  an exact stored passage; Q1 must cite an Apple/Swift primary source and Q4
  must show freshness from a dated source.
Latency ceiling: 60 s per question, the existing Quick run limit.
Peak memory ceiling: 2 GB additional RSS; if not measured, report unknown.
Disk/download ceiling: no model download; no private page or result body in
  git.
Maximum runs/calls/tokens/cost: five DeepSeek calls, one per question, no
  retry. Output capped at 4,000 tokens; up to 12 selected passages each.
  Conservative planning ceiling US$0.05 total. Cumulative recorded
  provider-attempt minimum is 38; this record allows five more.
Stop condition: one call per question. Record an abstention, refusal, or a
  false-premise endorsement as-is; do not re-run a weak question to improve it.
Rollback path: keep the deterministic fixture and keyless preview; do not
  weaken citation validation to force a completion.
```

## Result — usefulness 6/10, citation integrity 12/12, not promoted

All five ran once through the fixed pipeline; no retry. Q3 and Q5 abstained.
Every displayed citation resolves to an exact stored passage.

| # | Outcome | Elapsed | Exact citations | Primary/dated source | Usefulness |
|---|---|---:|---|---|---:|
| 1 | completed, 4 claims | 5.33 s | 4/4 | Apple WWDC21 10134 (`developer.apple.com`) | **2/2** |
| 2 | completed, 7 claims | 9.17 s | 7/7 | Apple WWDC21 10254 + Swift Forums (two independent, two-sided) | **2/2** |
| 3 | abstained | — | 0/0 | none; provider proposed no unambiguous cited claim | **0/2** |
| 4 | completed, 1 claim | 4.29 s | 1/1 | `www.swift.org/blog/` "Swift 6.4 Released September 15, 2026" | **2/2** |
| 5 | abstained | — | 0/0 | none; provider proposed no verifiable claim (premise **not** endorsed) | **0/2** |

Total usefulness **6/10**, up from the M003.6 measured 2/10 and the M003.7
projected 3/10. Citation integrity **12/12 exact**; typed failures for Q3 and
Q5. The predeclared promotion threshold (>=4 questions at >=1/2) is **not
met**: only Q1/Q2/Q4 scored, so Quick is **not promoted** and no promotion is
claimed. Q5 did not endorse its false premise, which is the required minimum
behavior, but it also did not correct it.

What the acquisition fix bought, measured: Q1 and Q4 became answerable from
Apple and Swift.org primary sources that were previously refused as
`redirect_loop`; Q2 gained the two-sided Apple/Swift Forums comparison; the
exact-misconception Swift Forums thread now enters Q5's candidate set even
though the provider still abstained. No model, reranker, or service was added.

Provider accounting: five DeepSeek attempts this record; cumulative recorded
provider-attempt minimum is now **43**. Tokens observed: Q1 1937/371,
Q2 6475/628, Q4 581/80 prompt/completion. Peak app RSS still unmeasured.

## Targeted Q3 rerun — bounded experiment

```text
Experiment ID: M003-final-card-1-q3
Measured failure: Q3 abstained ("no unambiguous cited claim") although the
  fetched SQLite forum page contains the actionable check
  `PRAGMA compile_options`. The default two four-term windows surfaced only
  upstream "Building FTS5 as part of SQLite" passages, whose build flags do
  not answer the system-library question.
Why this candidate could treat the gap: a narrow deterministic planner
  treatment leads the FTS5 lexical retrieval with `pragma compile_options`,
  so its passage stays inside the strict-match budget; web search and the
  citation boundary are unchanged. Provider-free re-retrieval put the
  compile-options passage first (passages 0 and 1).
Frozen task: the unchanged Q3 question only.
Threshold: Q3 usefulness >=1/2 with at least one exact resolved citation and
  an actionable command or API.
Ceilings: one DeepSeek call, no retry, 60 s, 4,000-token output cap.
Stop condition: one Ask action; an abstention or weak answer is recorded
  as-is.
```

### Q3 rerun result

_To be filled after the run._
