# M003.9 Tavily retrieval preflight for measured gaps

Frozen before these provider-free CLI runs on 2026-09-26 AEST. Run each of the
four questions below exactly once through current default planning and the
user-owned Tavily basic-search adapter, then safe fetch, extraction, snapshot
storage, and lexical selection. No DeepSeek call or frozen answer-card score is
authorized by this preflight. The search budget is at most two basic Tavily
queries per question (eight free-tier credits total). Do not retry a miss to
make the result look better.

| ID | Exact question | Retrieval readiness check |
|---|---|---|
| Q2 | How do Swift structured concurrency and Grand Central Dispatch differ for CPU-bound work? | Selected passages substantively describe CPU-bound behavior on both sides, from independent credible sources. |
| Q3 | How do I enable FTS5 in the system SQLite on macOS? | A selected authoritative passage names the macOS system-library path and an actionable flag, command, or API, not just upstream SQLite compilation. |
| F1 | What happens when a Python asyncio TaskGroup child raises an exception? | A selected Python documentation passage states the child-failure propagation/cancellation behavior. |
| F5 | Why does HTTPS encryption prevent a website from seeing my IP address? | A selected credible passage enables correction of the false premise by explaining that the destination still sees the connection IP. |

Record selected-source quality, typed refusals, and what remains missing. A
retrieval pass is not an answer/citation pass. If multiple checks fail, do not
spend a new hosted answer-card budget on unchanged tasks; preserve gaps.

## Results — four one-shot misses

All four commands exited 0 and called no answer provider. The search-query
counts were 2, 1, 1, and 1 respectively: at most five basic Tavily credits
according to the request contract; actual vendor usage was not observed.
The recorded cumulative DeepSeek-attempt minimum remains 37.

| ID | Elapsed | Opened / selected | Provider-free result |
|---|---:|---:|---|
| Q2 | 9.95 s | 2 / 3 | **Fail.** Swift Forums CPU-work passages selected; Apple Dispatch and WWDC pages were refused as `extraction/no_readable_text` or `acquisition/redirect_loop`. No substantive independent GCD passage selected. |
| Q3 | 8.66 s | 5 / 12 | **Fail.** SQLite's upstream FTS5 page selected `SQLITE_ENABLE_FTS5` and `--enable-fts5`, but no selected passage establishes the macOS system-library action. A draft mirror and unrelated forum/chrome consumed slots. |
| F1 | 5.54 s | 5 / 12 | **Fail.** `docs.python.org/3/library/asyncio-task.html` opened, but its selected passages were `Task groups` heading and generic Task-object cancellation text. The child-failure rule was not selected from official docs. |
| F5 | 3.87 s | 1 / 12 | **Fail.** Only Proton's HTTPS explainer was stored; Mozilla/APNIC redirected in a way the safe acquisition boundary refused, and Stack Exchange returned HTTP status failures. Selected text discussed server IP/traffic metadata and VPNs, not clearly the destination website seeing the client's IP. |

These are retrieval-readiness failures, **not** answer-quality scores. The
frozen answer card remains unchanged and will not be run against these
inputs. The typed redirect, HTTP-status, and extraction refusals are retained;
the guardrails must not be weakened to make the card look green. Next diagnose
query-to-passage matching and the source-selection trade-off before proposing
a bounded treatment.
