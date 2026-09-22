# Performance Plan

## Verdict

The sibling research engine is slow mainly because independent work is
scheduled sequentially and model calls happen too early and too often. Its
recorded live run took roughly 20 minutes. The sibling notes that eight sources
produced 2,637 passages, claim extraction used approximately one model call per
passage before a 40-call cap was added, later evidence-assessment calls were not
covered by that cap, and the configured 900-second wall limit was not enforced.

Local Lens will reuse the sibling's safety, evidence, citation, and evaluation
contracts. It will replace the execution schedule.

## Fast-path principle

**Retrieve cheaply, narrow aggressively, call a model in batches, and show
useful evidence before synthesis finishes.**

Quick mode is not a shortened Deep run. It is a separate bounded path:

```text
question
  -> deterministic intent/routing when possible
  -> at most 2 parallel search queries
  -> rank/deduplicate hits before opening them
  -> at most 6 bounded parallel source fetches
  -> static extraction first; browser rendering only on a selected failure
  -> FTS5/BM25 over extracted passages
  -> at most 12 diverse passages
  -> one batched evidence proposal
  -> trusted quote/ID validation
  -> one concise synthesis
  -> deterministic citation compilation
```

No follow-up round, exhaustive contradiction sweep, per-passage model loop, or
browser fallback belongs in the default Quick path.

## Work removed from the critical path

| Current sibling behavior | Local Lens treatment |
|---|---|
| search queries run one after another | bounded parallel search with provider-level limits |
| selected sources fetch one after another | bounded task group with per-host politeness |
| extraction waits for all acquisition | stream each completed extraction into retrieval |
| every passage can trigger a model call | lexical retrieval and diversity reduce to a small evidence set first |
| support is judged claim by claim | deterministic quote checks plus one batched semantic review when required |
| contradiction work can grow by claim pairs | cheap candidate generation first; model reviews only plausible conflicts |
| browser renderer is a general fallback | static HTML/PDF first; render only high-ranked extraction failures |
| configured wall budget is advisory | controller deadline checked before and after every phase and retry |
| report appears at the end | source cards, passages, and provisional Evidence UI stream progressively |

## Concurrency without losing safety

- Search queries may run concurrently up to the mode's global search limit.
- Fetches may run concurrently across hosts while retaining per-host delay,
  robots checks, redirect validation, byte limits, and cancellation.
- CPU extraction runs in a bounded worker pool so it cannot starve the UI.
- Model calls are not fanned out blindly. A single local model often serializes
  internally and parallel requests increase memory pressure rather than speed.
- Events remain ordered by a controller-assigned sequence even when work
  completes out of order.

## Cache and Research Memory

Cache only objects whose identity and freshness are explicit:

- canonical search query plus provider and short expiry;
- robots policy per host with expiry;
- raw snapshot by content hash;
- extraction result by raw hash plus extractor version;
- passage index by extracted hash plus chunker version;
- evidence result by passage hashes, question, mode policy, and model revision;
- completed research memory with live, cached, or stale presentation state.

News never silently uses stale evidence. Academic material can have a longer
metadata cache while still checking versions and retractions where supported.

## Provisional performance budgets

These are product targets to test on the reference Mac, not achieved results:

| Measure | Quick target | Deep behavior |
|---|---:|---|
| first visible search activity | under 500 ms | same |
| first useful source/evidence card | under 3 s when a provider responds | same, then continues |
| warm-cache cited answer p50 | under 5 s | not a Deep objective |
| fresh-web cited answer p50 | under 20 s | progressive; bounded by selected budget |
| fresh-web cited answer p95 | under 40 s | explicit deadline and partial result |
| opened sources | at most 6 | mode policy, initially at most 20 per round |
| evidence passages sent to synthesis | at most 12 | batched by dimension with a hard token budget |
| follow-up rounds | 0 | initially at most 2 |

All timings must name the Mac, provider, network condition, cache state, model,
and revision. Time to first evidence and time to final answer are separate.

## Provider routing

The evidence pipeline is provider-neutral. A provider such as DeepSeek may be
used as an optional hosted planner or synthesizer, but it does not perform web
fetching, assign trusted IDs, or validate its own citations.

- Quick selects one measured low-latency backend.
- Deep may select a stronger backend under a larger explicit budget.
- Local, Apple on-device/PCC, and hosted results remain separately labelled.
- Provider fallback is opt-in where it changes privacy or cost.
- No provider is adopted until structured-output reliability, latency, cost,
  privacy, licence/terms, and citation behavior pass the frozen evaluation.

## Instrumentation required before optimization

Every run records monotonic durations and counts for:

- rewrite;
- each search query;
- queue wait, robots, connection, download, extraction, and rendering fallback;
- retrieved and selected passage counts;
- every model role, input/output tokens, retries, and cancellation;
- evidence validation and citation compilation;
- time to first activity, source, passage, draft block, and final answer; and
- cache hits, misses, age, and invalidations.

Optimization is promoted only when the same frozen quality gates still pass.
A faster unsupported answer is a regression.

## Implementation order

1. Preserve current deterministic behavior behind the extracted ResearchCore
   boundary.
2. Add phase timing and enforce one monotonic wall deadline.
3. Parallelize search and cross-host fetching under existing safety limits.
4. Stream extraction and evidence events to the native UI.
5. Insert retrieval before any claim extraction and batch the selected evidence.
6. Add cache layers with versioned keys and freshness tests.
7. Compare the Quick schedule with the preserved sibling schedule on identical
   fixtures, then on an approved fresh-web set.

The first optimization target is fewer model calls, not a different model.
