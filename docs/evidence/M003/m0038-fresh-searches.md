# M003.8 five fresh representative searches

Frozen 2026-09-26 AEST before running any of these questions. They do not
replace the five-question answer-quality card in `five-questions.md`, and were
not used to choose the M003.8 Q4 treatment. Run each once through the current
`LocalLensLive --mode retrieve` path with default web and lexical queries:
search → bounded safe fetch → extraction → stored snapshots → FTS5 retrieval.
No provider call or answer-quality score is authorized by this record.

| # | Kind | Fresh question | Retrieval check |
|---|---|---|
| F1 | Factual | What happens when a Python asyncio TaskGroup child raises an exception? | A Python documentation passage about group failure is selected, or a typed absence is reported. |
| F2 | Comparison | How do SQLite WAL and rollback journal modes differ for concurrent readers? | Passage coverage from authoritative SQLite documentation for both journal modes, or the gap is reported. |
| F3 | Practical Mac task | How can I show hidden files in macOS Finder using a keyboard shortcut? | A readable actionable shortcut passage is selected, or the gap is reported. |
| F4 | Recent fact | What is the latest stable Rust release as of September 26, 2026? | A dated official Rust release source is selected, or freshness is unverified. |
| F5 | False premise | Why does HTTPS encryption prevent a website from seeing my IP address? | Sources should permit correction; retrieval alone cannot prove the app would correct it. |

For each, record the typed fetch outcomes, opened and selected counts, CLI
elapsed time, and `/usr/bin/time -l` maximum resident set size. Peak RSS is for
the short-lived CLI process, **not** the macOS app nor the Docker SearXNG
container, and cannot be reported as full-system peak resource use. No live
page body or private snapshot will be committed. The five one-shot outcomes
follow below.

## One-shot results

All five retrieval commands exited 0. `opened` counts records, including an
identical-content duplicate on F2; it is not a count of distinct documents.
The selected passages remain untrusted until a separate answer/citation run.

| # | CLI elapsed | Peak CLI RSS | Opened / selected | Typed fetch outcomes | Retrieval check |
|---|---:|---:|---:|---|---|
| F1 | 10.27 s | 36,929,536 B | 5 / 11 | 5 stored; 1 `robots/fail_closed` | **Gap:** Python docs opened, but selected Python-doc passages were generic TaskGroup/cancellation fragments. The direct failure rule was selected from a third-party page, not Python documentation. |
| F2 | 11.94 s | 35,586,048 B | 6 / 12 | 5 stored; 1 duplicate | **Met for retrieval:** SQLite's own WAL page supplied passages about rollback journal, WAL operation, and their tradeoffs. No generated comparison was tested. |
| F3 | 11.92 s | 35,241,984 B | 4 / 11 | 4 stored; 2 `acquisition/http_status` | **Met for retrieval:** one selected page gives a Finder keyboard shortcut. This was not Apple documentation and the answer UI was not tested. |
| F4 | 9.82 s | 24,182,784 B | 5 / 12 | 5 stored; 1 `robots/fail_closed` | **Partial:** official Rust blog passages include version 1.98.1 and a Sept. 3, 2026 date. Retrieval alone does not prove it was the latest stable version on Sept. 26. |
| F5 | 8.58 s | 33,751,040 B | 4 / 10 | 4 stored; 1 `extraction/no_readable_text`; 1 `acquisition/http_status` | **Gap:** selected passages discuss what an ISP can see, not clearly what the destination website sees. The false premise was not tested with an answer provider. |

CLI elapsed p50 **10.27 s**, highest **11.94 s**; observed CLI peak RSS
highest **36,929,536 B** (~35.2 MiB). The sample is only five runs, so no
population p95 claim is made. Time to first evidence, full Mac-app RSS, Docker
RSS, provider latency/cost, and answer/citation quality were **not measured**.
Zero provider calls were made; the cumulative recorded minimum stays **36**.
