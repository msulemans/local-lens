# M003.6 ambiguity-treatment verification: one-call limit

Recorded 2026-09-25 AEST before this verification attempt. This is a distinct
experiment following the diagnosed `ambiguousQuote` failure in
`m0036-provider-experiment.md`, not a retry under its spent allowance.

```text
Experiment ID: M003.6-ambiguous-claim-treatment-2
Measured failure: The native app's first direct-page hosted run produced an
  ambiguousQuote refusal between two duplicate stored forum passages; it
  showed no answer or citation.
Existing baseline and score: One failed in-app run, usefulness 0/2 and no
  citation; M003.5 frozen card unchanged and not passed.
Why this candidate could treat the failure: The same existing DeepSeek
  provider receives a cleaner selected set after question-ending passages
  are excluded. Each proposed claim is tested through the unchanged citation
  compiler; an ambiguous claim is isolated rather than aborting independent
  uniquely citable claims. Three focused deterministic regressions pass.
Exact model/revision/hash: deepseek-flash as served by the DeepSeek API on
  2026-09-25; immutable hosted revision/hash unavailable. No model-quality
  promotion may be inferred from this run.
Licence and redistribution constraints: DeepSeek hosted API terms; no
  weights or fetched page body redistributed. Selected public passages go
  to DeepSeek and the app labels hosted output distinctly from local preview.
Runtime and integration path: Existing native Mac app and
  DeepSeekAnswerProvider; development process receives DEEPSEEK_API_KEY from
  the environment. No key is logged, committed, or saved by this experiment.
Frozen development task: Same question and URL as the first direct-page
  experiment: "How does Swift cancel a task group?" and the public Swift
  forum page ending /75057. This does not satisfy benchmark Q1's primary
  documentation requirement.
Frozen sealed tasks: none; five-questions.md remains unchanged.
Quality promotion threshold: At least one displayed claim with a citation
  resolving to a unique exact stored passage; manual entailment and at least
  1/2 usefulness for this page. This proves the direct-page hosted path only.
Latency ceiling: 60 seconds Quick run.
Peak memory ceiling: 2 GB additional RSS; unmeasured means no promotion.
Disk/download ceiling: no model download; no fetched page body in git.
Maximum runs/calls/tokens/cost: Exactly zero or one provider attempt,
  <= 4,000 prompt and <= 4,000 completion tokens, estimated <= US$0.01.
  Recorded cumulative minimum before this experiment: 22 attempts.
Stop condition: Stop after this one attempt, success or failure. Do not
  issue a second call under this record.
Rollback path: The deterministic changes can be reverted without altering
  the M001 fixture, Keychain path, or offline guard; retain failed evidence.
```

## Result: failed; budget spent

The native Mac app received the same frozen question and supplied URL. It
entered its running state and then displayed `No supported answer yet —
provider failed: emptyAnswer`. The fetch and retrieval stages had previously
shown six answer-candidate passages from that page, but this run did not
expose its selected passage ids or provider token usage. The DeepSeek adapter
returned `QuickProviderError.emptyAnswer`, so **one provider attempt was
made**, bringing the recorded cumulative minimum to **23**. No displayed
answer or citation resulted. Usefulness is 0/2 for this attempt; citation
validity and completeness are not applicable. Exact elapsed time, prompt and
completion tokens, peak RSS, and observed cost are not measured. No raw
provider response or page body was committed. The one-call stop condition is
reached; do not retry under this record.

The ambiguity treatment was not exercised by this call because there was no
provider content to compile. The app's error copy has since been changed to
explain an empty provider result in plain language and say it will not retry
automatically. That copy change is deterministic/UI code only; no further
paid call was made. The direct-page in-app cited-answer gate and frozen
five-question quality card remain open.
