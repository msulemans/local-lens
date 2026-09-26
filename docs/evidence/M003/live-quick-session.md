# M003.5 live Quick session log

Session: 2026-09-23, approximately 20:04-20:15 AEST (well inside the 120 minute
budget). No commit was made, per the packet. Two packet hard stops were hit, so
the live five-question run did not execute.

## Phase 0 - preflight (checkpoint 1)

Observed:

```text
DEEPSEEK_API_KEY: NOT set
docker: client/server 29.7.2 via /Applications/Docker.app/Contents/Resources/bin/docker (daemon up)
internet: https://api-docs.deepseek.com/updates/ HTTP 200, https://docs.searxng.org/... HTTP 200
searxng image: searxng/searxng:latest sha256:1808478ceb29... (369 MB, already local)
hardware: arm64, 32 GiB RAM, Swift 6.4
```

Provider identity verified from the official docs, not assumed:

- current API model id is `deepseek-flash` (DeepSeek-V4.1-Flash); the packet's
  assumed `deepseek-v4-flash` has been retired;
- base URL `https://api.deepseek.com`, endpoint `POST /chat/completions`;
- pricing at `https://api-docs.deepseek.com/quick_start/pricing/`.

The five questions and the experiment record were frozen before any call:
`docs/evidence/M003/five-questions.md`, `docs/evidence/M003/deepseek-experiment.md`.

## Phase 1 - search endpoint (checkpoint 2)

A project-scoped SearXNG container was started (no unrelated containers touched):

```text
docker run -d --name locallens-searxng -p 127.0.0.1:8888:8080 \
  -v /tmp/locallens-searxng:/etc/searxng searxng/searxng
```

Settings enabled JSON (`search.formats: [html, json]`) and disabled the limiter.
One live JSON query:

```text
GET http://127.0.0.1:8888/search?q=swift+structured+concurrency&format=json
-> HTTP 200, 20 results
   docs.swift.org, developer.apple.com/tutorials, avanderlee.com, ...
   unresponsive_engines: brave (too many requests), duckduckgo (CAPTCHA), startpage (CAPTCHA)
```

Search works. The endpoint is loopback-only and dev-only; the final Mac user
still does not need Docker.

## Phase 2 - live runner and the fetch-safety hard stop (checkpoint 3)

The packet says: if the production fetch transport cannot enforce the existing
DNS and redirect policy, stop live page fetching and record the blocker.

`URLSessionSearchTransport.send` uses `session.data(for:)` with no redirect
delegate, so `URLSession` follows redirects itself. `SafeAcquisition.fetch`
expects to see a 3xx status and validate each hop manually, so on the open web
it never sees the redirect and its per-hop check is bypassed. Demonstrated on
loopback with a local 302 (`/start` -> `/end`):

```text
async data(for:) final status: 200
async data(for:) final url: http://127.0.0.1:9111/end
async data(for:) body: END
```

Hard stop recorded: the production fetch transport is not redirect-safe, so no
live page was fetched. This was not bypassed with raw `URLSession` calls.

## Phase 3 - provider and citation path, offline (checkpoint 4)

The provider key is absent, so no provider request was made
(`docs/MODEL_POLICY.md` admits no candidate without a filled record and the key).

Offline integration completed instead:

- `SearchRequest` gained an optional `body`, so the existing transport can POST
  without a second transport abstraction; search still sends `nil`.
- `Sources/LocalLensCore/LiveQuick.swift`: the answer-provider boundary, the
  untrusted-proposal validator (`AnswerTrust`), the frozen `LiveQuickLimits`
  (2 / 6 / 12 / deadline), and `LiveQuickRunner`, which enforces the caps in
  code, calls no provider without stored evidence, and abstains on a deadline, a
  missing evidence set, or an unverifiable claim.
- `Sources/LocalLensCore/DeepSeekProvider.swift`: a hosted provider that posts
  only selected passage ids/text, reads the key from configuration, and never
  logs, echoes, or persists it. Request/response shape is unit-tested with a
  stub transport; the live HTTP call is **unverified**.
- Tests: `LiveQuickTests` (8) and `DeepSeekProviderTests` (7).

## Phase 4 - five-question product check

Not run. Both hard stop conditions block it: no provider key, and no
redirect-safe production fetch. The card is 0/5 executed, reported as
`not run`, not scored. Provider cost: **US$0.00**, calls: **0**.

## Phase 5 - closeout (checkpoint 5)

```text
swift test -> Executed 207 tests, with 0 failures
make gate  -> validate-manifest conforms; validate-schemas parity holds;
              build complete; 207 tests, 0 failures; exit 0
```

Default tests and the app remain offline. No secret was printed, logged, or
written to a tracked file. Working tree was not committed.

Changed files:

- modified: `Sources/LocalLensCore/SearchAdapter.swift` (additive `body` field)
- added: `Sources/LocalLensCore/LiveQuick.swift`,
  `Sources/LocalLensCore/DeepSeekProvider.swift`,
  `Tests/LocalLensCoreTests/LiveQuickTests.swift`,
  `Tests/LocalLensCoreTests/DeepSeekProviderTests.swift`,
  `docs/evidence/M003/deepseek-experiment.md`,
  `docs/evidence/M003/five-questions.md`, this file
- preserved untouched: the user's `README.md` and `docs/AI_HANDOFF.md` edits,
  `docs/DEEPSEEK_M0035_WORK_PACKET.md`

## Exact remaining blockers

1. `DEEPSEEK_API_KEY` is not set, so the provider path cannot be called.
2. The production fetch transport follows redirects internally, so
   `SafeAcquisition`'s per-hop DNS/redirect validation is bypassed on the open
   web. Smallest fix (not done, to respect the packet's stop rule and the
   infrastructure freeze): give `URLSessionSearchTransport` a task delegate that
   refuses redirects, so the 3xx reaches `SafeAcquisition`, and re-verify the
   address check against the connection peer.

## Retry: redirect-safety fix and live retrieval half

After the owner said "continue", the redirect hard stop was cleared and the live
retrieval half was run.

Fix (modified `Sources/LocalLensCore/SearchAdapter.swift`):
`URLSessionSearchTransport` now passes a `RedirectRefusingDelegate` to
`session.data(for:delegate:)`, so a 3xx is returned to `SafeAcquisition` instead
of being followed. Verified on loopback: before the fix `data(for:)` returned
final 200 at `/end`; after the fix it returns `302` with `Location: /end`. Live
proof: a real fetch to `https://shopflare.au/how-it-works` was refused at
`stage=acquisition kind=redirect_loop`, which is only possible if the transport
surfaced the 3xx.

Residual risk recorded, not hidden: the existing `AcquisitionPolicy` resolves
the host once and `URLSession` re-resolves at connect time, so a DNS-rebinding
TOCTOU window remains. It is a pre-existing property of the M002.2 policy, not
introduced here; the redirect bypass was the demonstrable one.

Live runner (`Sources/LocalLensLive/LocalLensLive.swift`, new executable
target): search via the existing SearXNG adapter, bounded fetch via the existing
`BoundedFetcher` (robots + per-host politeness + redirect validation +
extraction + store), then lexical retrieval. Run with
`swift run LocalLensLive --question "..." --queries "q1,q2" --mode retrieve`.
`--mode answer` requires `DEEPSEEK_API_KEY` and is untested live.

Two live retrieve runs (search, no provider):

| Question | Queries | Elapsed | Opened | Passages | Fetch outcomes |
|---|---|---:|---:|---:|---|
| How do I enable FTS5 in the system SQLite on macOS? | `sqlite fts5`, `enable fts5` | 4.61 s | 3 | 1 | 3 stored, 2 robots (1 published, 1 fail-closed), 1 acquisition redirect_loop |
| How does Swift structured concurrency cancel a task group? | `swift task group cancellation`, `structured concurrency swift cancellation` | 4.31 s | 4 | 0 | 4 stored, 1 extraction unsupported_content_type (PDF), 1 robots fail_closed |

Honest findings:

- The mechanism works: real search, safe bounded fetch, extraction, storage,
  indexing, and retrieval all run end to end in under 5 s.
- Search quality is the current bottleneck, not retrieval. The engine mix is
  unstable: the same class of query returned `docs.swift.org` and
  `developer.apple.com` in the Phase 1 probe but returned mostly unrelated
  `.au` domains in these runs, because brave/duckduckgo/startpage were
  rate-limited or CAPTCHA'd. A five-question card would be measuring the engine
  mix as much as the product.
- Retrieval returned 0 passages on the second question because the AND match
  requires every query term in one stored passage; the opened pages did not
  contain all of them. This is a retrieval-quality finding for M004, not a
  safety or correctness failure.

No provider call was made, so no answer or citation is claimed. The five
questions remain 0/5 on the answer half. Provider cost US$0.00.

## Updated blocker

Only the provider key remains: `DEEPSEEK_API_KEY` is not set. With it, `answer`
mode runs the full live slice. The redirect-safety blocker is cleared.

## Continuation 2026-09-23 20:31 — provider attempts and batch outcomes

The first live calls happened after the redirect fix and the Keychain handoff.
Cumulative provider attempts (each is one `POST /chat/completions`), reconciled
from this transcript, `/tmp/m003-live/q1..q5.txt`, `/tmp/m003-live/propose-q*.txt`
and the Keychain-backed runs:

| # | Call | Result |
|---|---|---|
| 1 | Q1 `--mode answer` | completed: 3/3 citations, 5.24 s |
| 2 | Q1 `--mode answer` (retry) | `provider failed: emptyAnswer` |
| 3 | batch Q1 | `provider failed: emptyAnswer` |
| 4 | batch Q2 | `provider proposed no verifiable claim` |
| 5 | batch Q3 | `provider proposed no verifiable claim` |
| 6 | batch Q4 | not called: `no retrieved evidence` (no provider request) |
| 7 | batch Q5 | `provider proposed no verifiable claim` |
| 8 | Q1 `--mode propose` | 2 claims, both bound and exact (prompt 247 / completion 652) |
| 9 | Q2 `--mode propose` | `provider_error=emptyAnswer` |
| 10 | Q3 `--mode propose` | `no verifiable claim` (prompt 440 / completion 317) |
| 11 | Q5 `--mode propose` | `no verifiable claim` (prompt 331 / completion 517) |

Call accounting: **11 used, at most 9 remain** under the original 20-call
ceiling. Cost: the three propose runs reported 1,018 prompt and 1,486 completion
tokens, about US$0.0021 at peak `deepseek-flash` rates (input cache-miss
US$0.30/1M, output US$1.20/1M). Assuming the eight calls without a recorded
usage were of similar size, the estimated cumulative spend is **under US$0.01**,
well inside the US$1 ceiling. Recheck usage on every further call.

Batch outcomes, verbatim, are preserved in `/tmp/m003-live/`:

```text
Q1 provider failed: emptyAnswer.
Q2 no verifiable claim.
Q3 no verifiable claim.
Q4 no retrieved evidence.
Q5 no verifiable claim.
```

The Q1 `--mode propose` call is mechanical proof that the provider returns
exact-quote claims from one passage. It is **not** a completed native answer and
does not prove the claims answer the question well. Q2 retrieval included
single-character punctuation blocks (`·`, `--`), Q3 retrieved generic SQLite
build instructions rather than macOS system-SQLite instructions, and Q5 retrieved
passages that raise the threading question without answering it. The batch is
therefore **attempted with failures**, not 5/5.

## Diagnosis: why junk passages were selected

`LexicalIndex` indexes a passage's heading and body in one FTS5 row, so a query
whose terms all appear in the **heading** matches the row even when the **body**
is only navigation chrome or a separator. `LiveQuickRunner.prepare` then appended
`hit.passage` unconditionally, so `·`, `--`, and `Using Swift` consumed slots in
the twelve-passage budget. This is a selection-boundary bug, not a provider bug.

## Continuation results (live calls 14-19 of 20)

Fixes applied before the rerun: junk-passage selection guard, one any-term
relaxation when the strict query finds nothing, the output cap raised 1,000 ->
4,000 for the reasoning model, and the displayed answer assembled from accepted
claims only. Each completed run also wrote a `LiveAnswerArtifact` under
`/tmp/m003-live/`.

| # | Call | Outcome | tokens (prompt/completion) | latency |
|---|---|---|---|---|
| 14 | Q1 `--mode answer --out` | completed, 4 citations, 0 rejected | 304 / 1334 | 9.19 s |
| 15 | Q2 `--mode answer` | abstained: no verifiable claim | not reported | - |
| 16 | Q3 `--mode answer` | abstained: no verifiable claim | not reported | - |
| 17 | Q4 `--mode answer --out` | completed, 1 citation, 1 rejected | 547 / 1752 | 11.83 s |
| 18 | Q5 `--mode answer` | abstained: no verifiable claim | not reported | - |
| 19 | Q2 `--mode propose` | 1 passage, 1 exact claim (but the passage is a question) | 298 / 1812 | - |

Counterfactual for call 19: it was spent to diagnose the recurring
`no verifiable claim`, and it showed the provider *can* propose an exact claim
for Q2. It did not produce an accepted answer, and the one passage retrieved for
Q2 is a forum question, not a fact. The last call (20) was deliberately not
spent: passing Q2 on a question-as-answer would be a misleading success.

### What the fixes changed

- The junk guard removed the punctuation-only and navigation bodies (`·`,
  `--`, `Using Swift`) that had consumed Q2's budget. Q2 dropped from 6 selected
  passages (5 junk) to 1 real passage.
- The any-term relaxation turned Q4 from 0 passages into a completed answer by
  finding the stored "Swift 6.3 Released" passage that the strict all-term query
  missed.
- The cap fix removed `emptyAnswer`/truncation: Q1 and Q4 both returned a
  decodable proposal at completion 1334 / 1752, under the 4,000 ceiling.

### Honest answer quality (manual review, not mechanical)

- Q1: 4/4 citations resolve exactly, but the first two claims come from a
  "Discarding Task Groups" passage and include "cancellation tokens", which is
  not established Swift terminology. The quote is exact and the claim is
  mechanically bound; whether it *entails* the claim is doubtful. Usefulness 1/2.
- Q4: 1/1 citation resolves exactly ("March 24, 2026" from "Swift 6.3
  Released"), but the answer gives only a date and never names the version, so
  it does not clearly answer "the latest stable release". Usefulness 1/2.
- Q2, Q3, Q5: no completed answer. The failure is honest abstention at the trust
  boundary, not a fabricated answer. Q5 (the false premise) abstained rather
  than asserting the false premise.
- Citation validity and completeness are reported separately from usefulness.
  Validity is mechanical (4/4 for Q1, 1/1 for Q4); completeness for the two
  completed answers is 4/4 and 1/1 factual spans, but both answers are weak in
  usefulness, so no question is scored as a pass.

### Budget and metrics

Cumulative provider attempts: **19 of 20**. Cumulative spend: the three
rerun calls with reported usage total 1,149 prompt and 4,898 completion tokens;
with the earlier two propose calls that is about US$0.008, and including the
untracked calls the estimate stays **under US$0.02**, inside the US$1 ceiling.

Not measured, and not invented: time to first evidence (separate from total
latency), peak memory, and per-question cost. Only total elapsed per completed
run and reported tokens are known.

### Native view

`Sources/LocalLensApp` gained `LiveAnswerView`, selected by
`LOCAL_LENS_START_VIEW=live`, reading a `LiveAnswerArtifact` from
`LOCAL_LENS_LIVE_ANSWER` (default `/tmp/m003-live/live-answer.json`). It shows
the explicit `HOSTED` label, `deepseek-flash · hosted`, the assembled answer,
and a clickable citation list whose inspector shows the exact saved passage.
Window captures: `/tmp/m003-live/app-live.png` (live) and
`/tmp/m003-live/app-m001-recheck.png` (M001 default, unchanged). The app performs
no network work: it reads one JSON file.
