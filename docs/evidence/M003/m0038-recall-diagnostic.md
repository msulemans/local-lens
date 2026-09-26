# M003.8 recall diagnostic and bounded treatment

Recorded 2026-09-26 AEST. The frozen questions and scoring rules in
`five-questions.md` are unchanged. These are **retrieval-only** observations:
no answer-provider calls, answer scores, or quality promotion follow from them.
The recorded cumulative provider-attempt minimum remains 36.

## Before treatment

The current `make gate` passed: 233 tests, zero failures. The pinned development
SearXNG container was up; its root returned HTTP 200. A search needed about
8 seconds, so an 8-second diagnostic cap timed out, while a 25-second cap
returned HTTP 200. This is a measured latency concern, not an engine outage.

| Frozen question | Default retrieval | Observed failure |
|---|---|---|
| Q2, Swift concurrency vs GCD for CPU-bound work | 8.40 s; 1 search, 5 opened sources, 11 selected passages | Mostly blogs; useful comparison text existed, but the selector also spent slots on a repeated heading and fragments. No two-sided authoritative evidence was assured. |
| Q4, latest stable Swift release in 2026 | 11.66 s; 1 search, 4 opened sources, 7 selected passages | `Swift` was ambiguous: financial-SWIFT standards pages and generic iOS posts displaced the language's official release page. A Swift.org Windows install passage named 6.4.0, but no selected official dated release passage established freshness. |

## Provider-free candidate probes

Q4 search text `Swift programming language latest stable release 2026`
returned the Swift.org blog and `Swift 6.4 Released` among the first results.
The same runner with this search text, leaving its normal lexical queries
unchanged, opened 6 sources and selected 12 passages in 9.26 s. One selected
Swift.org blog passage read `Swift 6.4 Released September 15, 2026 Swift 6.4
is now available...`. This improves *evidence availability* only; no provider
answer was attempted.

For Q2, two side-specific search texts (`Swift structured concurrency CPU
bound work thread pool` and `Grand Central Dispatch CPU bound work concurrent
queues Apple documentation`) surfaced Swift Forums and Apple documentation.
With the existing lexical plan, the runner opened 4 sources and selected 11
passages in 14.20 s; several selected passages repeated their heading. With
side-specific lexical texts (`CPU bound tasks` and `dispatch queues concurrent
work`), it opened 4 and selected 12 in 12.45 s. Substantive passages from
Swift Forums described CPU-heavy task yielding, and Apple documentation
described concurrent dispatch queues. The query texts were diagnostic probes,
not an accepted general planner change; Q2 remains a gap until a reusable
query rule and live answer quality are measured.

## Treatment boundary

The bounded code change is a disambiguation for the measured `latest stable
Swift release` intent and a heading-echo filter for selected and cited
passages. It does not change the citation compiler, raise Quick caps, add an
engine, or call a model. The filter rejects a passage only when its body equals
its heading after case-insensitive whitespace trimming; it must preserve
normal short factual passages such as release dates.

## Default-planner recheck after treatment

The first post-treatment gate passed with 234 tests and zero failures. No
provider call was made.

| Frozen question | Default retrieval after treatment | Verdict |
|---|---|---|
| Q2 | 7.97 s; 4 opened, 5 selected; peak CLI RSS 44,744,704 B | Heading echoes stopped consuming slots, but metasearch returned different, mostly third-party pages from the first probe. It still lacks reliable two-sided authoritative coverage. **Explicit gap**, not an improvement claim. |
| Q4 | 8.24 s; 6 opened, 11 selected; peak CLI RSS 55,033,856 B | Swift.org's `Swift 6.4 Released` page and the blog index opened. A selected official passage contained `Swift 6.4 Released September 15, 2026 Swift 6.4 is now available`. **Retrieval recall improved**, but answer/citation quality was not re-measured. |

The CLI peak RSS figures exclude the app, SearXNG container, and external
network services. Time to first evidence was not instrumented. The live search
results varied between Q2 probes; this was not a deterministic replay.

## Source-authority correction

While checking source relevance, `SourceAuthority` still ranked any arbitrary
`docs.` or `developer.` subdomain as official. A hostile or merely unofficial
`docs.untrusted.example.com` could therefore outrank a real primary source.
The tier-0 rule now requires a known project/vendor domain (or the existing
Swift GitHub path), and tests cover misleading documentation prefixes plus
Python's real docs. This is discovery ordering only, not a certificate of
factual truth. The final gate result is recorded in canonical state.

Promotion is not claimed. Fresh-question and resource measurements are in
`m0038-fresh-searches.md`. Q2's comparison and Q4's dated-answer quality need
a separate pre-recorded provider experiment only after retrieval is strong
enough; no provider budget was spent here.
