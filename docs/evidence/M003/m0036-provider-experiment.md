# M003.6 single-call in-app proof experiment

Recorded 2026-09-25 AEST **before** any call under this record. This is a
separate development experiment, not a reset of the M003.5 ceiling or a
five-question promotion run.

```text
Experiment ID: M003.6-in-app-direct-page-1
Measured failure: Two earlier genuine in-app M003.6 provider runs abstained,
  and no completed in-app answer with inspectable citations exists. A
  retrieval-only run of a known public page found a question-shaped paragraph
  ahead of an answer-bearing reply.
Existing baseline and score: M003.5's frozen card is in five-questions.md:
  Q1 and Q4 usefulness 1/2; Q2, Q3, Q5 0/2. No in-app cited completion.
Why this candidate could treat that failure: The existing hosted DeepSeek
  adapter can propose atomic claims from selected, stored passages. The
  measured retrieval selection fix now supplies an answer-bearing passage.
Exact model/revision/hash: DeepSeek API model id deepseek-flash, as served on
  2026-09-25; hosted service exposes no immutable revision or weights hash to
  this client. This run cannot establish version-stable model quality.
Licence and redistribution constraints: Hosted DeepSeek API terms; no model
  weights or fetched page body are redistributed. Selected public-page
  passages leave the Mac, with the result visibly labelled hosted.
Runtime and integration path: The existing Swift DeepSeekAnswerProvider in
  the native app, using DEEPSEEK_API_KEY from the process for this development
  run; no key is logged, committed, or saved by the experiment.
Frozen development task: Ask "How does Swift cancel a task group?" with the
  supplied URL
  https://forums.swift.org/t/does-taskgroup-cancelall-require-active-co-operation-to-finish-properly/75057
  through the native app. This forum page is not substituted for the primary
  source requirement in benchmark Q1.
Frozen sealed tasks: none. The five-question card remains unchanged.
Quality promotion threshold: One completed in-app answer with at least one
  citation that resolves to an exact stored passage, manually judged to
  support the displayed claim and be at least 1/2 useful. Passing proves only
  this direct-page app path, not Quick quality or Q1 benchmark success.
Latency ceiling: 60 seconds for the Quick run.
Peak memory ceiling: 2 GB additional RSS; unmeasured means no promotion.
Disk/download ceiling: no model download; fetched page body stays outside git.
Maximum runs/calls/tokens/cost: One provider attempt, up to 4,000 prompt and
  4,000 completion tokens, estimated spend <= US$0.01. Prior recorded attempts:
  M003.5 19 plus M003.6 two in-app attempts = at least 21 cumulative; this
  record permits at most one additional attempt, never reuse of call 20.
Stop condition: Stop after this one attempt whether it succeeds or fails;
  also stop before provider if retrieval has no answer-bearing passage or
  the provider key is unavailable. Do not retry merely to get a green result.
Rollback path: Remove the development environment-key fallback; the Keychain
  path, deterministic Quick, and offline guards remain intact.
```

## Result: failed; budget spent

One native-app Ask action was made on 2026-09-25 AEST with the frozen question
and supplied forum URL. The app entered its running state, then displayed:

```text
No supported answer yet
citation compilation failed: ambiguousQuote(
  claimID: "5aac9fab1fb848005c63",
  passageIDs: ["4c5e1bdca1a0c11b05e8", "51e5bf6b8e75dc80db11"])
```

The two passage ids identify repeated question text in the stored forum page.
The compiler correctly refused to choose one silently. The action reached the
provider proposal stage; count it as one provider attempt, making the recorded
cumulative minimum **22** (M003.5 19, earlier M003.6 two, this one). No answer
or citation was shown, so usefulness is 0/2 for this experiment and citation
validity/completeness are not applicable. Provider token usage, exact elapsed
time, peak RSS, and observed cost were not exposed in the UI and are **not
measured**. No screenshot or raw provider response was persisted. The
one-call stop condition has been reached; do not retry under this record.

Treatment after the failure: the unchanged compiler is now applied to each
proposed claim before final batch compilation. Ambiguous claims are rejected
individually, allowing an independent unique citation to survive; a run with
no unambiguous claim abstains. Question-ending passages are filtered from the
provider selection, and the single-source retrieval cap no longer restricts
the page to two paragraphs before filtering. These changes have deterministic
tests and a retrieval-only live check, but **no second provider call** has
verified the treatment in the app. No quality promotion is claimed.
