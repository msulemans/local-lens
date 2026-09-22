# Local Lens - Complete Product and Build Plan

Last revised: 2026-09-22

This is the single-page plan for what Local Lens is, what is reused, what is
new, what gets built, and how each claim is proved. Detailed contracts remain
in the linked documents; this page is the map a builder or reviewer should read
first.

## One-sentence product

**Local Lens is a Mac-native answer engine that generates the right evidence
view for a question and proves every factual cell with an exact saved passage.**

It combines a fast daily launcher, bounded research modes, a local research
memory, and an inspectable evidence map. It is not a generic chat window and it
is not a web app wrapped in a desktop shell.

## Product thesis: evidence-native generative search

Most answer engines generate prose and attach links afterward. Local Lens uses
the opposite order:

```text
question
  -> mode policy
  -> query plan
  -> discovered sources
  -> immutable snapshots and addressable passages
  -> atomic claims
  -> supporting, conflicting, and missing evidence
  -> a typed Evidence UI
  -> deterministic citation compilation and validation
```

The output is not Markdown first. It is a typed evidence graph rendered through
a finite SwiftUI component set. A comparison question can become an evidence
matrix, an event can become a timeline, and an academic question can become a
paper matrix. Every factual field carries claim and passage identifiers.

This is the promotable idea: **the interface adapts to the question, while the
proof contract stays fixed.** We call this **Evidence-Native Generative Search**.
It is our product thesis, not a claim that no one has explored adjacent ideas.

## Why this is timely

Three recent developments make this practical without betting the product on an
unstable research stack:

1. Apple's 2026 Foundation Models APIs expose a common `LanguageModel`
   protocol and Dynamic Profiles. Quick, Deep, Academic, and News can select
   different instructions, tools, reasoning levels, and model backends behind
   one native boundary while preserving a coherent session.
2. AG-UI and A2UI establish useful event and declarative-UI vocabulary for
   streaming agent applications. Local Lens adopts those shapes where useful,
   but renders only a strict, citation-bearing SwiftUI schema; it does not let a
   model execute UI code.
3. Contextual passage embeddings and long-context listwise rerankers are
   improving retrieval. They remain benchmark-gated challengers, not mandatory
   dependencies. They will be tested only when a labelled lexical-retrieval
   failure justifies them.

## The product experience

### Daily loop

1. Press a global shortcut.
2. Ask a question and choose `Quick`, `Deep`, `Academic`, or `News`.
3. Watch a compact, honest progress stream: queries, sources, passages, gaps.
4. Receive the best matching Evidence UI: brief, comparison, timeline, paper
   matrix, conflict view, or recommendation.
5. Select any citation to open the exact saved passage and source context.
6. Save the result into local Research Memory, export it, or research a visible
   gap.

### Mode contracts

| Mode | Promise | Default behavior | Stop condition |
|---|---|---|---|
| Quick | A useful cited answer fast | small query fan-out, few strong sources, lexical retrieval, concise brief | sufficient support or time budget |
| Deep | A bounded multi-angle investigation | editable dimensions, follow-up searches, contradiction and coverage map | coverage target, diminishing evidence, or hard budget |
| Academic | A paper-grounded synthesis | scholarly registries, DOI/version reconciliation, PDF/page passages, paper matrix | sufficient primary literature or explicit insufficiency |
| News | A current event view | temporal queries, event/syndication clustering, source independence, timeline | freshness and confirmation target or explicit uncertainty |

The mode changes the execution policy, not just the prompt label.

## What we reuse instead of rebuilding

The primary reusable foundation is the local sibling
`../deep-research-agent`. Direct inspection found typed research entities and
state, adapter protocols, a SearXNG adapter, safe acquisition, HTML/PDF
extraction, Playwright fallback, FTS5 retrieval, ranking and deduplication,
evidence/report compilation, integrity and semantic evaluation, fixtures, and
184 unit tests.

The first engineering job is to carve that engine into a versioned
`ResearchCore` package and put a small, authenticated local protocol in front
of it. The native SwiftUI application owns the experience; the proven Python
core initially owns web research. We port a component to Swift only when
packaging, performance, or maintenance evidence justifies the cost.

```text
Native SwiftUI app
  |  typed versioned events over authenticated local IPC
  v
Bundled ResearchCore sidecar
  |-- proven sibling search/acquisition/extraction/retrieval/evidence code
  |-- SearXNG or approved search providers
  |-- deterministic fixtures and evaluation
  v
SQLite/FTS5 + content-addressed private snapshots
```

Normal users will not install Python, Docker, Node, or model servers. During
development a contributor can run the core with its pinned Python environment;
release builds bundle and supervise it inside the signed app. SearXNG is a
replaceable baseline, not a required end-user service: release candidates must
either ship a no-Docker search path or configure an explicit optional endpoint.

The sibling currently has no licence file. Before copying code into a public,
forkable repository, M001 must record ownership, choose a compatible licence,
and preserve provenance. Until then, reuse is an approved architecture decision
but code transfer is blocked.

See [ADOPT_ADAPT_BUILD.md](ADOPT_ADAPT_BUILD.md) for the source-by-source
ledger.

The sibling's evidence contracts are reusable, but its sequential execution
schedule is not. [PERFORMANCE_PLAN.md](PERFORMANCE_PLAN.md) records the Quick
fast path, bounded parallelism, batched model work, cache keys, deadlines,
instrumentation, and provisional latency targets.

## What is uniquely ours

1. **Evidence graph with maturity states.** A source visibly moves through
   `discovered -> opened -> extracted -> cited -> independently confirmed`, or
   into `conflicted`, `stale`, or `rejected`.
2. **Evidence UI.** The model proposes only trusted components whose factual
   fields must name existing claim and passage IDs.
3. **Provenance ribbons.** Sparse visual links show which source passages
   support which answer cells without exposing chain-of-thought.
4. **Local Research Memory.** Saved snapshots and passages form a searchable
   personal evidence cache. Every reuse is labelled live, cached, or stale.
5. **Mode policy compiler.** The four modes compile to explicit budgets,
   providers, source rules, tools, and model profile—not magic prompts.
6. **Learn this run.** The user's real run becomes an explorable lesson in
   query rewriting, retrieval, evidence selection, and citation evaluation.
7. **Benchmark card generated from runs.** Marketing claims come from stored
   evaluation artifacts, with local and hosted configurations separated.

## Deliberate non-goals

- no unrestricted autonomous browsing;
- no model-generated Swift, HTML, or JavaScript;
- no multi-agent theatre before one bounded controller fails;
- no vector database before SQLite/FTS5 has a measured recall failure;
- no broad model bake-off;
- no fine-tuning before prompt, tool, retrieval, and evidence errors are
  separated;
- no Docker or terminal in the normal-user path; and
- no claim of being the first or best without a reproducible comparison.

## Architecture decisions

### Native product shell

SwiftUI owns windowing, keyboard flow, accessibility, evidence inspection,
history, settings, exports, Spotlight, App Intents, and application lifecycle.

### Reused research core

Python initially owns the already-proven search, acquisition, extraction,
retrieval, evidence, and evaluator modules. It emits versioned events and
versioned entities. The app treats the sidecar as untrusted input: schema
validation, allowed state transitions, artifact hashes, and citation IDs are
checked at the boundary.

### Model boundary

Use Apple's `LanguageModel` protocol as the native abstraction where the target
OS supports it. Dynamic Profiles express mode-specific context, tools, and
backend choice. A deterministic fake remains the default test adapter. One real
local candidate is selected only after hardware measurement and frozen-task
evaluation. Hosted models are optional and clearly labelled.

### Streaming and generative UI

Use an internal event protocol shaped by AG-UI lifecycle, activity snapshot,
delta, and error patterns. Evidence UI uses an A2UI-inspired stream of typed
surface and data updates. We do not take a runtime dependency on either spec in
the first release; the internal schema can later gain a compatibility adapter
without weakening citation or rendering rules.

## Build sequence and gates

### M000A - Planning correction (current)

Record the complete plan, reuse ledger, innovation thesis, source review,
hybrid architecture, and corrected gates. Mark the partially created Swift
foundation as unverified WIP. No implementation claim is made.

Gate: a reviewer can answer what is reused, what is new, why it is timely, what
is not being tested, and what must be true before coding resumes.

### M001 - Reuse foundation and deterministic native slice

- resolve licence/provenance for sibling reuse;
- freeze the ResearchCore extraction boundary;
- preserve and run the sibling's relevant deterministic tests;
- define the versioned IPC/event/Evidence UI schemas;
- build and bundle a deterministic sidecar fixture;
- connect the SwiftUI Living Research Map to one offline run; and
- add one-command build and verification paths.

Gate: a clean clone runs the same offline cited answer twice; citations open the
same passage; illegal events fail closed; cancellation is terminal; no network,
keys, Docker, or model weights are needed.

### M002 - Safe live Quick pipeline

- adapt the proven SearXNG/search boundary;
- reuse the safe fetch/extraction/snapshot path;
- add bounded parallel acquisition and progress events;
- add a release-appropriate search setup that does not require Docker; and
- prove typed outcomes for SSRF, robots, redirects, size/MIME limits, PDF, and
  extraction failure.

Gate: live Quick discovery reaches immutable passages safely while deterministic
tests remain unchanged.

### M003 - First useful Mac release

- implement FTS5/BM25/source-diversity retrieval from the reused baseline;
- select exactly one justified local model adapter;
- implement the brief/comparison Evidence UI, citation inspector, history,
  Research Memory, and global launcher;
- bundle the sidecar and model/setup flow; and
- record latency, peak memory, package size, answer quality, and citation
  quality on frozen and fresh questions.

Gate: a normal user can install and complete useful Quick searches without a
terminal; citation integrity is 100%; the public benchmark card is reproducible.

### M004 - Retrieval challenger, only if the baseline fails

Entry requires labelled recall errors on the frozen Quick set. The first
eligible challenger is contextual passage embeddings because they encode
document-wide context. A listwise reranker is eligible only if candidate recall
is already adequate and ordering is the measured failure.

Gate: the challenger meets a frozen downstream citation-quality improvement and
fits latency, memory, licence, and distribution budgets. Otherwise preserve the
negative result and ship the baseline.

### M005 - Academic

Add OpenAlex, Crossref, Semantic Scholar, and arXiv adapters; reconcile DOI and
versions; extract page-aware PDF evidence; render a paper matrix; export
BibTeX/RIS.

Gate: academic questions beat generic web search on held-out citation quality,
with unsupported questions abstaining.

### M006 - News

Add temporal query plans, event and syndication clusters, source-independence
scoring, freshness labels, and timeline Evidence UI.

Gate: stale and syndicated pages cannot masquerade as fresh independent
confirmation.

### M007 - Deep

Add editable dimensions, bounded follow-up rounds, contradiction and coverage
maps, pause/resume, and diminishing-evidence stopping.

Gate: every loop ends with a typed reason and injected failures resume without
duplicating evidence.

### M008 - Evaluation and learning studio

Add benchmark comparisons, human citation review, corruption tests, per-mode
scorecards, and Learn this run exercises.

Gate: integrity remains 100%; semantic judges are calibrated against held-out
human labels; answer and citation metrics stay separate.

### M009 - Public release

Sign and notarize the app, complete accessibility and recovery testing, verify
a second machine, select the public licence, publish the benchmark card, and
prove the clean-clone contributor path.

## Benchmark contract

Quality is a matrix, never one vanity score:

| Layer | Primary measures |
|---|---|
| Discovery | gold-source recall, primary-source rate, source independence |
| Retrieval | passage recall@k, duplicate rate, evidence diversity |
| Answer | correctness, completeness, usefulness, calibrated abstention |
| Citations | validity, entailment, completeness, exact-passage resolution |
| Product | time to first useful evidence, completion rate, cancellation, peak memory, package size |

Every candidate comparison freezes the question set, corpus or web snapshot,
budgets, machine, versions, prompts, and promotion threshold before execution.
Local and hosted results are separate. Integrity must be 100%; an answer with a
better style score cannot compensate for a broken citation.

## Model and retrieval selection

There will be no tournament of fashionable models.

1. Start with deterministic fake inference.
2. Measure the target Mac and select one viable local model based on structured
   output, citation discipline, latency, memory, licence, and bundle burden.
3. Keep Apple on-device/PCC and hosted providers behind the same boundary, but
   do not merge their benchmark results.
4. Test contextual embeddings only for a proven passage-recall problem.
5. Test a listwise reranker only for a proven ordering problem.
6. Promote a candidate only if it clears the frozen product threshold.

## Risks and exits

| Risk | Early proof | Exit |
|---|---|---|
| Bundled Python sidecar is too large or fragile | M001 clean-clone and bundle spike | retain schemas/tests and port only measured hotspots to Swift |
| SearXNG harms onboarding | M002 fresh-machine setup | ship another adapter or managed opt-in; keep SearXNG for development |
| Local model is too slow | M003 hardware matrix | use Apple system model where available; optional hosted path remains labelled |
| Generative UI becomes inconsistent | schema snapshots and accessibility tests | reduce the allowed component set |
| Research Memory becomes stale | freshness metadata and revalidation | disable silent reuse; require refresh for time-sensitive modes |
| New retrieval model has no downstream gain | frozen M004 treatment | do not ship it |

## Definition of proud-to-publish

The project is ready to promote only when a release artifact can be installed
on another supported Mac, complete a useful real search without a terminal,
open every citation to an exact passage, explain local versus hosted work,
reproduce its benchmark card, and guide a contributor through one clean build
path. Until then, promotional language describes the thesis and verified
milestones—not aspirational features as completed work.
