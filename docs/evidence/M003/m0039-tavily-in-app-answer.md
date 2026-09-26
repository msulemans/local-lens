# M003.9 Tavily-to-DeepSeek in-app smoke — one call

Recorded 2026-09-26 AEST **before** the hosted answer action. This is a
bounded product-integration check, not a new model comparison or a frozen-card
promotion run. The historical cumulative recorded provider-attempt minimum is
36; this record allows at most one additional attempt.

```text
Experiment ID: M003.9-tavily-app-smoke-1
Measured failure: No completed answer has been observed from the normal-user
  no-Docker Tavily discovery path in the Mac app.
Existing baseline and score: The app's Tavily no-AI run for the task below
  opened six sources and selected 12 passages, including two substantive
  passages from sqlite.org/wal.html, but displayed no answer or citations.
  Prior SearXNG frozen card was below Quick promotion threshold.
Why this candidate could treat the gap: Existing DeepSeek answer composition
  is already app-proven for a supplied page. This one run checks that Tavily
  discovery plus safe fetched pages reach the same accepted-claim and
  citation path without Docker.
Exact model/revision/hash: deepseek-flash per current app configuration;
  hosted immutable revision/hash unavailable to this client.
Licence and redistribution constraints: Hosted DeepSeek API terms and Tavily
  search terms; selected public passages are sent to DeepSeek. No raw API
  result, fetched page body, or key will enter git.
Runtime and integration path: Current ad-hoc-signed Mac app; Tavily and
  DeepSeek keys stored in macOS Keychain with owner approval. Native Ask
  action, LiveQuickRunner, citation compiler, and evidence rail.
Frozen development task: "How does SQLite WAL mode handle readers and
  writers?" using default Tavily search, no supplied source URL.
Frozen sealed tasks: none. The unchanged five-question card is not scored.
Quality promotion threshold: One app-rendered answer with at least one exact
  saved-passage citation and fetched URL; manually assess entailment and
  source authority. Passing proves only this integration path, not Quick
  release quality. An honest abstention is recorded as a failed smoke.
Latency ceiling: 60 seconds, the existing Quick run limit.
Peak memory ceiling: 2 GB additional RSS; if not measured, report unknown.
Disk/download ceiling: no model download; no private page or result body in git.
Maximum runs/calls/tokens/cost: one DeepSeek provider attempt, no retry;
  current app caps output at 4,000 tokens, with up to 12 selected passages.
  Prompt tokens and actual cost are provider-reported/unknown until observed;
  conservative planning ceiling US$0.02 for this one small request.
Stop condition: One Ask action only. Stop earlier if Keychain access fails or
  if no relevant official passage survives; no automatic provider retry.
Rollback path: Keep deterministic fixture and keyless evidence preview; do
  not weaken citation validation to force a completion.
```

## Result — integration passed, quality not promoted

One native Ask action on 2026-09-26 AEST completed in the app in **6.0 s**.
The Tavily query used the default no-Docker path, with no supplied page URL.
The app displayed four accepted, numbered claims and four clickable citations:

| Marker | Displayed claim | Fetched source | Manual quote/entailment check |
|---|---|---|---|
| 1 | WAL lets readers and writers proceed concurrently without blocking each other. | `https://www.sqlite.org/wal.html` | Exact saved passage directly supports it. |
| 2 | Readers use a snapshot; writers block each other. | `https://sqlite.org/forum/info/b4e8b29ae409cd198652c6b7e70b53b702f269e67e1d2573d627feeba37bbf85` | Exact saved SQLite-forum reply directly supports it; a forum reply is not the same authority as product documentation. |
| 3 | WAL can still return `SQLITE_BUSY` in obscure cases. | `https://www.sqlite.org/wal.html` | Exact saved passage directly supports it. |
| 4 | WAL theoretically supports one writer and many readers simultaneously. | `https://forum.xojo.com/t/sqlite-with-wal-multiuser-mode-behavior-that-disappoints-me/29211` | Exact saved quote supports the sentence, but this is a weaker third-party forum and largely repeats claim 1. |

Citation validity observed through the app rail: **4/4 exact quotes, 4/4
fetched-source links**. The displayed factual sentences were each cited and
the quoted text entails them. This passed the predeclared one-call integration
threshold; it did not test the frozen five-question card, and it does not
promote Quick. The weak/redundant fourth citation is a measured source and
answer-selection gap, not a reason to count the run as release-ready.

The run was visibly labelled `HOSTED · DEEPSEEK`. The keys were masked in the
app and not copied into this record. The no-AI Tavily preflight selected 12
passages from six opened sources; the answer view does not expose its own
opened-source count, exact token usage, cost, or peak RSS, so those remain
**unmeasured**. The single call is spent. The cumulative recorded provider
attempt minimum is now **37**; no retry was made.
