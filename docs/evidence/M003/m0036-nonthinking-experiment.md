# M003.6 non-thinking Quick verification

Recorded 2026-09-25 AEST before a provider request. This is one targeted
treatment of the second in-app `emptyAnswer`, not a model bake-off or a reset
of either spent M003.6 call limit.

```text
Experiment ID: M003.6-deepseek-flash-nonthinking-3
Measured failure: The post-ambiguity in-app run reached DeepSeek but returned
  emptyAnswer before it could propose any claim. The earlier M003.5 run had
  observed reasoning_content consume a 1,000-token output cap and leave no
  final content. The second M003.6 UI did not expose finish_reason or token
  counts, so reasoning exhaustion is a hypothesis, not a proven diagnosis.
Existing baseline and score: Two M003.6 direct-page in-app attempts: one
  ambiguousQuote, one emptyAnswer; 0 completed citations and 0/2 usefulness.
Why this candidate could treat the failure: DeepSeek's current Chat
  Completions documentation says deepseek-flash defaults to thinking and
  accepts thinking.type=disabled. Quick needs a short JSON proposal, so
  disabling reasoning reserves the same 4,000-token ceiling for final JSON.
Exact model/revision/hash: deepseek-flash, documented as
  DeepSeek-V4.1-Flash on 2026-09-25. Hosted immutable hash is unavailable;
  no version-stable quality claim is permitted.
Licence and redistribution constraints: Hosted DeepSeek API terms. No model
  weights or fetched page bodies are redistributed; selected public passages
  are transmitted to DeepSeek and the result remains labelled hosted.
Runtime and integration path: Existing DeepSeekAnswerProvider and native Mac
  Quick window; same model and JSON shape, with thinking.type=disabled added
  to the request. The existing process environment supplies the key; it is
  never logged, committed, or saved by this experiment.
Frozen development task: "How does Swift cancel a task group?" against
  https://forums.swift.org/t/does-taskgroup-cancelall-require-active-co-operation-to-finish-properly/75057
  via One source URL in the Mac app. This forum page does not meet the frozen
  benchmark Q1 requirement for Apple or Swift documentation.
Frozen sealed tasks: none. docs/evidence/M003/five-questions.md is unchanged.
Quality promotion threshold: At least one in-app claim with a citation to a
  uniquely resolved exact stored passage, manually judged to entail the
  claim and give >=1/2 usefulness. Passing proves this direct-page path only.
Latency ceiling: 60 seconds Quick deadline.
Peak memory ceiling: <=2 GB additional RSS; unmeasured is not a pass.
Disk/download ceiling: no model download; fetched body stays outside git.
Maximum runs/calls/tokens/cost: one provider attempt; <=4,000 prompt and
  <=4,000 completion tokens; peak-price ceiling <=US$0.006 using official
  2026-09-25 Flash rates ($0.30/M uncached input, $1.20/M output). Recorded
  cumulative minimum before this experiment: 23 provider attempts.
Stop condition: stop after this single provider attempt, success or failure;
  do not auto-retry or test another model under this record.
Rollback path: remove thinking.type=disabled to restore the prior request;
  no citation, fetch, fixture, or offline gate boundary was changed.
```

Official product/API basis: [Chat Completions](https://api-docs.deepseek.com/api/create-chat-completion/),
[Thinking Mode](https://api-docs.deepseek.com/guides/thinking_mode/), and
[Models & Pricing](https://api-docs.deepseek.com/quick_start/pricing/).

## Disposition: no call under this record

Before this planned call, computer-use inspection found a completed
three-citation answer already present in the open native app. This turn did
not trigger that run, and the running process's request configuration was not
observable, so the answer cannot be attributed to `thinking.type=disabled`.
The three exact stored passages were inspected in the UI; they support the
displayed claims on that one Swift forum page. No provider attempt was made
under this experiment. The planned one-call allowance is **unused and
closed**, not transferred to another experiment. The unchanged frozen card is
now the relevant comparison, under its own bounded record.
