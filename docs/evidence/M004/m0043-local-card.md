# M004.3 - Local answer card and promotion decision

Date: 2026-09-26 (Australia/Sydney)
Working tree: uncommitted on top of `40c7ec3`. Nothing staged or committed.

Candidate: `qwen2.5-coder:14b-instruct-q4_K_M` through the loopback
OpenAI-compatible endpoint (`docs/MODEL_POLICY.md`, experiment
`M004.2-LOCAL-OPENAI-001`). No hosted call was made. Cost US$0.

## Command

```text
$ TAVILY_API_KEY=... ./.build/debug/LocalLensLive --tavily --local \
    --mode answer --question "<each frozen question>"
```

Retrieval was the unchanged provider-free Tavily path. The provider was the
local endpoint. The artifact label was `local`.

## Per-question results

Scores use the frozen five-question rubric: answer usefulness 0-2, citation
validity (resolving exact stored passages / total citations), citation
completeness (supported factual spans / total factual spans), and
abstention-or-correction for Q5.

| # | Elapsed | Citations | Accepted / rejected | Usefulness | Validity | Completeness | Note |
|---|---|---|---|---|---|---|---|
| 1 | 28.70 s | 2 | 2 / 0 | 2/2 | 2/2 | 2/2 | `cancelAll` plus task-tree propagation; relevant and correctly attributed |
| 2 | 82.69 s | 4 | 4 / 1 | 2/2 | 4/4 | 3/4 | both sides covered (thread-count aim, continuations vs thread explosion); **over the 60 s Quick ceiling** |
| 3 | 30.38 s | 1 | 1 / 1 | 1/2 | 1/1 | 1/2 | upstream `--enable-fts5` configure step, not the macOS system-library action |
| 4 | not measured | 0 | 0 / 0 | 0/2 | 0/0 | 0/0 | `answer_abstained: the provider proposed no verifiable claim` |
| 5 | 24.85 s | 3 | 3 / 0 | 0/2 | 3/3 | 0/2 | **did not correct or abstain**: the leading claim ("a detached task ... will always run on a background thread") can read as endorsing the false premise; the other two claims address blocking, not background execution |

Total usefulness: **6/10**. Citation integrity: **10/10 exact** (every emitted
citation resolved through the unchanged compiler). Latency: Q2 exceeded the
experiment's 60 s Quick ceiling.

## Decision

**The local path is not promoted.** The pre-recorded threshold requires at
least four of five questions at >=1/2 with 100% citation integrity. Q5 fails
the frozen "correct or abstain" requirement because it answered adjacent
claims that can read as confirming a false premise, so only three questions
reach >=1/2. Q2 also breached the 60 s latency ceiling.

Consequences:

- `LOCAL · <model>` stays an explicit alternative selected in Connection; it is
  never a silent fallback and never the default.
- The wrong-sense "Swift" answer from M004.2 and this card are preserved as the
  measured local quality record.
- No prompt or planner change was made in response, because tuning against the
  observed questions would be fitting to the sample.
- The threshold and result are recorded together; the threshold is not weakened
  after seeing the result.

## Preserved failures

- Q5 false-premise non-correction (the requirement was correct or abstain).
- Q2 latency 82.69 s against a 60 s ceiling.
- Q3 partial: build-system step instead of the loaded library's compile options.
- Q4 abstention with no scored answer.
- Raw outputs for this card are in `/tmp/m0043-local/card.txt`; private page
  bodies are not committed.

## Proof boundary

Deterministically verified: the unchanged 264-test suite.
Locally measured: this five-question card against the local endpoint.
Live-provider verified: Tavily retrieval and the local endpoint.
Not promoted; not a second-Mac or notarized result.
