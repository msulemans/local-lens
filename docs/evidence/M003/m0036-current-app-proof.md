# M003.6 current-build Mac answer proof — one call

Recorded 2026-09-25 AEST before this call. This isolates the remaining proof
gap: a cited answer was observed in an already-running app of uncertain
request revision, while the current non-thinking code produced cited CLI
answers on the frozen card. It is not a new model comparison or card retry.

```text
Experiment ID: M003.6-current-app-nonthinking-1
Measured failure: No cited answer has yet been observed from a freshly
  launched current-build Mac app using thinking.type=disabled.
Existing baseline and score: An already-running app displayed a three-cited
  answer on the same forum page (11.3s), but its initiating action and request
  revision were not observed. Current CLI non-thinking card: 2/10 usefulness.
Why this candidate could treat the gap: The current app and CLI share the
  same LiveQuickRunner/DeepSeekAnswerProvider. A fresh app launch with one
  supplied public page directly tests the current user-facing composition.
Exact model/revision/hash: deepseek-flash / DeepSeek-V4.1-Flash documented
  2026-09-25; hosted immutable hash unavailable.
Licence and redistribution constraints: DeepSeek hosted API terms. No model
  weights or fetched page body redistributed. Selected public passages sent
  to DeepSeek; result visibly hosted.
Runtime and integration path: Rebuilt ad-hoc-signed dist/Local Lens.app,
  launched with existing DEEPSEEK_API_KEY in its development process; no key
  logged, saved, or committed. Native ask field and citation rail are used.
Frozen development task: "How does Swift cancel a task group?" with the
  supplied Swift forum page ending /75057. Not frozen-card Q1 primary proof.
Frozen sealed tasks: none; five-questions.md remains unchanged.
Quality promotion threshold: One completed current-app answer with at least
  one citation whose exact saved passage and fetched URL are visible; manual
  entailment >=1/2 usefulness for this page. No general Quick promotion.
Latency ceiling: 60 seconds.
Peak memory ceiling: <=2 GB additional RSS; unmeasured remains unknown.
Disk/download ceiling: no model download; page body stays outside git.
Maximum runs/calls/tokens/cost: one provider attempt; <=4,000 prompt and
  <=4,000 completion tokens; <=US$0.006 peak-price bound. Recorded card
  brought cumulative known attempts to at least 28, excluding the earlier
  app answer of uncertain provenance.
Stop condition: one Ask action only, no retry on failure.
Rollback path: deterministic demo and prior app bundle remain unaffected by
  the externally sourced result; revert thinking toggle if it regresses.
```

Result (2026-09-25 ~21:31 AEST): **passed the pre-declared threshold.** The
current-build development app ran the ask itself and wrote a completed
artifact to `/tmp/m0036-app-proof/artifact.json` (outside git). The question
was "How does Swift cancel a task group?" with the supplied forum page ending
`/75057`; `deepseek-flash` (hosted) returned in **3.07 s**. The displayed
answer was assembled only from accepted, exact-quoted claims:

> A task group waits for all child tasks to complete before returning, even
> cancelled tasks. [1] Cancellation is cooperative, so a task must explicitly
> check for cancellation and unwind before CancellationError can be thrown. [2]

Both citations resolved to exact stored passages on the fetched page:

- `[1]` passage `d0e0699186ca0d046105` → "A group waits for all of its child
  tasks to complete before it returns. Even cancelled tasks must run until
  completion before this function returns";
- `[2]` passage `4c008b9469f49caf95e2` → "Because cancellation is cooperative,
  i.e. a Task always requires whatever it is executing to explicitly check for
  cancellation, unwind its stack and return before CancellationError() can be
  thrown by the continuation."

Every citation carries the fetched document URL
`https://forums.swift.org/t/does-taskgroup-cancelall-require-active-co-operation-to-finish-properly/75057`,
not a search-result link. The answer claims are directly entailed by their
quotes; manual usefulness for this page is 2/2. This proves the app's own ask
path (view → `LiveQuickRunner` → hosted provider → citation compiler →
rendered artifact) with the current build, not a CLI artifact load.

How the run was triggered: the app exposes an evidence-only hook,
`LOCAL_LENS_LIVE_QUESTION` plus optional `LOCAL_LENS_LIVE_SOURCE_URL` and
`LOCAL_LENS_LIVE_OUT`, that feeds the same typed ask field and calls the same
`ask()` path. It is off unless the environment variable is set, mirroring the
`LOCAL_LENS_START_VIEW` capture precedent (D014). No keystrokes were faked. A
window screenshot was deliberately **not** used: the available full-screen
capture included the user's unrelated desktop, so the written artifact is the
recorded evidence instead of a screenshot.

Provider accounting: this is the single call the record pre-declared. It brings
the recorded cumulative provider-attempt minimum to **29** (28 before it,
excluding the earlier app answer whose trigger could not be established). No
retry was made. Tokens, cost, and peak RSS were not measured in the app and are
recorded as unknown, not invented.

Unknowns: the artifact proves the pipeline and its rendered content; it does
not prove human pointer interaction with the citation rail, which remains
unautomated. The supplied forum page is not the frozen card's Q1 primary
source, so this is in-app composition proof, not a card quality promotion.
