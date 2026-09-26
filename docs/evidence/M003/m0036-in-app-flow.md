# M003.6 in-app ask-to-answer and targeted quality (in progress)

Scope: the D031 / `project.json` M003.6 task. Baseline: the frozen five-question
card in `docs/evidence/M003/five-questions.md` is preserved unchanged.

## What was built

1. **In-app ask-to-answer flow.** `LiveAnswerView` gained an ask field, visible
   only when `LOCAL_LENS_LIVE=1`. Submitting runs the real live pipeline in the
   app: `QuickQueryPlanner` -> search -> bounded safe fetch -> retrieval ->
   DeepSeek provider -> citation compilation -> assembled answer. The app writes
   the resulting `LiveAnswerArtifact` and renders it.
   - The network wiring lives in `LocalLensCore/LiveQuickComposition.swift`, not
     in the app target, so the repository offline guard (which forbids
     `URLSession`, `SystemHostResolver`, `SystemGetaddrinfo`, `SystemPolitenessClock`,
     and `Task.sleep` in `Sources/LocalLensApp`) stays satisfied. The guards pass.
   - `LOCAL_LENS_LIVE_QUESTION` runs the same code path on launch, so the flow is
     automatable without simulating keystrokes.
   - The provider key is read from `DEEPSEEK_API_KEY`, then the
     `locallens-deepseek` Keychain item. It is never logged, echoed, or persisted.
2. **`QuickQueryPlanner`.** Deterministic question -> 1-2 keyword queries
   (stopword removal, four-term windows).
3. **Entailment hygiene in `AnswerTrust`.** An exact quote of a *question* is
   rejected ("quote is a question, not an answer"), and a punctuation-only quote
   is rejected ("quote carries no readable content"). A question is not an answer
   even when it is an exact substring.

## Evidence

Genuine in-app runs (no artifact pre-loaded; the app ran the pipeline):

| Capture | State | Meaning |
|---|---|---|
| `/tmp/m003-live/app-inapp2.png` | `Abstained: the provider proposed no verifiable claim` | the app ran search+fetch+provider itself |
| `/tmp/m003-live/app-inapp-answer.png` | `Abstained: the provider proposed no verifiable claim` (Q1) | same, with the polished hint |
| `/tmp/m003-live/app-inapp-idle.png` | ask bar + recorded artifact | the opt-in UI |

No in-app run has **completed** with citations yet. The flow is proven (it runs
the pipeline and surfaces typed abstentions); a completed in-app answer is not
yet captured.

## Planner measurement (free `retrieve` runs, before the engines rate-limited)

For Q1, against the same question:

| Query | Passages | Quality |
|---|---|---|
| `swift structured concurrency cancel task group` (old 6-term planner) | 5 | low: "Status: Implemented (Swift 5.5)", "Example of making soup…" via the relaxation |
| `swift task group cancellation` | 2 | the exact passages the CLI answer used |
| `swift cancel task group` | 3 | "How to cancel a task group", the racing passage |

Finding: a long all-term query strict-matches nothing and falls into the
any-term relaxation, which returns chrome. The planner now caps each query at
four content terms (head window + tail window). This is the measurement-backed
part of the change; the live card re-run is pending.

## Blocker: the search endpoint rate-limited

At 2026-09-23 20:55 AEST every SearXNG engine was suspended
(`brave`, `duckduckgo`, `google cse`, `startpage`, `wikipedia`), so a
`--mode retrieve` run returned `no openable search hits`. Live re-measurement of
the card against the baseline is therefore blocked until the engines recover.
This is the existing dev-only search dependency, not a code failure.

Independent recovery check at 2026-09-23 21:10 AEST: one request to the
existing `127.0.0.1:8888` endpoint for `swift task group cancellation`
returned zero results. SearXNG reported `brave: too many requests`,
`duckduckgo: timeout`, `google cse: too many requests`, and
`startpage: Suspended: CAPTCHA`. This was a search-only probe; it made no
provider call and did not rerun or score the frozen card. Restarting the
container had already failed to clear the remote failures, so another restart
is not a demonstrated recovery path.

## Provider-call guard for the pending card

The M003.5 card records 19 of its 20 permitted provider attempts. The two
genuine M003.6 in-app abstentions above involved the provider, so the old
M003.5 experiment's remaining one-call allowance must not be treated as a
fresh five-call budget. Before a paid M003.6 card rerun, record a separate,
bounded M003.6 experiment and reconcile the cumulative attempt count. Do not
silently reset the M003.5 ceiling or spend another call merely to test search.

## Gate

`swift test`: 223 tests, 0 failures (was 215 at M003.5). Offline guards pass.
The M001 view is unchanged.

## Status

- In-app ask-to-answer flow: **implemented and locally demonstrated** (abstentions
  captured), not yet a completed cited answer.
- Targeted quality: **implemented and deterministically verified** (planner and
  entailment tests); **live measurement pending** on the search endpoint.
- M003.6 `done_when` is **not yet met**; the task stays open. No commit.

## Search-recovery attempt (2026-09-23 21:05-21:35 AEST)

- 21:05: all default engines suspended — `brave` and `google cse` "too many
  requests", `duckduckgo` timeout, `startpage` CAPTCHA.
- Per-engine probes: `bing`, `mojeek`, `wikipedia` returned zero results and no
  error (no usable engine), `qwant` CAPTCHA, `yahoo` HTTP protocol error.
- 21:12: restarted the project's own `locallens-searxng` container; the shared
  remote rate limits did not clear.
- 21:20: `/search` then hung (over 10 s) while `/` still returned HTTP 200, so
  the engine pool was stuck, not merely throttled.
- 21:35: container restarted to a clean state (`/` -> HTTP 200). Search was not
  re-probed, to avoid prolonging the rate limit.

No model, engine set, query language, or benchmark was changed. The
five-question card is unchanged and remains the baseline. Recovery depends on
the upstream engines' cooldown; it cannot be forced locally.

## Ready-to-run card rerun (when the engines recover)

The CLI now derives queries from `QuickQueryPlanner` when `--queries` is
omitted, so this measures the current pipeline (four-term windows plus the
question/punctuation quote filter) rather than the M003.5 hand-written queries.
One provider call per question, five total:

```bash
KEY="$(security find-generic-password -s locallens-deepseek -a deepseek -w)"
run() { DEEPSEEK_API_KEY="$KEY" .build/debug/LocalLensLive --question "$2" --mode answer --out "/tmp/m003-live/rerun-$1.json"; }
run q1 "How does Swift's structured concurrency cancel a task group?"
run q2 "How do Swift structured concurrency and Grand Central Dispatch differ for CPU-bound work?"
run q3 "How do I enable FTS5 in the system SQLite on macOS?"
run q4 "What is the latest stable Swift release in 2026?"
run q5 "Why does Swift async/await always run on a background thread?"
```

Then compare each outcome and citation set against the M003.5 baseline in
`docs/evidence/M003/five-questions.md`. A cheap `--mode retrieve` run (no
provider call) should be done first to confirm search has recovered.
