# M003.6 source-relevance treatment — web search vs lexical retrieval

Recorded 2026-09-25 AEST. Deterministic source-relevance fix against the frozen
card's recorded failures. One milestone task (M003.6) only; no model change, no
search service added, no question changed.

## Measured failure

The M003.6 frozen-card rerun scored 2/10. The completed answers cited exact
passages, but source relevance failed:

- Q2 (structured concurrency vs GCD for CPU-bound work) abstained: retrieval
  found mostly generic text, no sound two-source comparison.
- Q3 (enable FTS5 in the **system** SQLite on macOS) answered from the generic
  `SQLITE_ENABLE_FTS5` build flag; it never reached a macOS system-library
  source.
- Q5 (false `async`/`await` background-thread premise) abstained; the
  correction source was never opened.

## Root cause (measured, free)

`QuickQueryPlanner` fed the **same** four-term keyword windows to both the
SearXNG web search and the FTS5 lexical index. A 2026-09-25 search probe of the
exact frozen questions showed the windows were actively harmful for search:

| Query sent to search | Top sources returned |
| --- | --- |
| `swift structured concurrency grand` (planner head window for Q2) | no useful primary/comparison source |
| `How do Swift structured concurrency and Grand Central Dispatch differ for CPU-bound work?` (natural question) | `dhiwise.com` comparison, `forums.swift.org` "heavy CPU work", Apple WWDC 2016 GCD |
| `Why does Swift async/await always run on a background thread?` | `forums.swift.org/t/do-async-operations-always-run-on-a-background-thread/80484` — the exact Q5 correction thread |

Search engines handle the natural-language question; the keyword windows split
"Grand Central Dispatch" into `...concurrency grand` and drop the phrase the
answer hinges on. The index, by contrast, wants short strict windows because a
long all-term FTS5 match hits nothing and falls back to chrome.

## Treatment (deterministic)

1. `QuickQueryPlanner.webQueries(question:)` returns the natural-language
   question; `plan(question:)` still returns the keyword windows for the index.
2. `LiveQuickRunner.retrieve`/`run` take an optional `retrievalQueries` list,
   defaulting to the search queries so existing callers and tests are unchanged.
   Search uses `queries`; FTS5 uses `retrievalQueries`.
3. The Mac app and `LocalLensLive` pass `webQueries` for search and `plan` for
   retrieval.
4. Retrieval now runs the ranked any-term pass to **fill remaining synthesis
   budget** rather than only when the strict pass is empty. Strict hits stay
   first; the fill is still `EvidenceText`-filtered, so a two-source question
   can receive more than one fragment.

`make gate` passes at 231 tests, 0 failures (added: `webQueries` planner test
and `testWebSearchQueryIsSeparateFromRetrievalQuery`, which fails if the runner
reuses one query list for both paths). Offline guards are unchanged.

## Live retrieval observation (free; no provider call)

Before (planner windows for both): Q2 opened 3 generic sources with 3
passages; Q3 opened 5 sources but answered from the generic FTS5 page; Q5
abstained.

After (question to search, windows to index), during the window when engines
answered:

| Q | Opened | Selected | Retrieved headings |
| --- | ---: | ---: | --- |
| 1 | 4 | 6 | WWDC21 "Beyond the basics of structured concurrency", "Task Cancellation in Swift Concurrency" |
| 2 | 6 | 12 | "Cooperative Thread Pool, Work Stealing, Structured Concurrency", "Async / Await", "Rules of Structured Concurrency", "Grand Central Dispatch (GCD)", "Avoiding CPU-hogging Tasks", "Choosing the Right Tool" |
| 3 | 5 | 8 | FTS5 "Building FTS5 as part of SQLite", `sqlite.org/compile.html`, "SQLite configuration", "Extensions" |
| 4 | 4 | 8 | "What Is Swift 6.3?", Swift Evolution, "What's new in Swift: July 2026" |
| 5 | — | — | blocked: all SearXNG engines suspended mid-preflight (`brave`, `google cse`: too many requests; `duckduckgo`: access denied; `startpage`: CAPTCHA; `wikipedia`: timeout) |

The Q2 and Q3 retrieval sets now clearly contain the two-sided comparison and
the macOS SQLite configuration material the card needed. This is a retrieval
observation, not a provider answer score.

## Deterministic in-app proof that shares the treatment

The current-build app ran the provided-page path through the same
`LiveQuickRunner` and produced a two-citation hosted answer whose exact-quoted
passages are the group-waits-for-children rule and the cooperative-cancellation
rule. See `m0036-current-app-proof.md`. That proves the composition and the
improved selection, but it is not the frozen card and not a quality promotion.

## Proof boundary

- **Deterministically verified:** the query decoupling, the fallback default,
  the ranked fill, and the existing citation integrity (231 tests).
- **Locally measured:** the live retrieval sets above, while the engines
  answered.
- **Not verified:** the improved retrieval's effect on frozen-card usefulness.
  Provider calls were deliberately not spent while every search engine was
  suspended; measuring the card then would have measured the outage, not the
  pipeline. The card re-measure remains owed once the approved engines recover.
- No model, embedding model, reranker, vector store, or search service was
  added. No question, gate, or offline guard was changed.
