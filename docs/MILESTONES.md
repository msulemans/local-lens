# Milestones and Gates

Only one milestone may be active. A gate is frozen before implementation and
is never weakened after its result is known.

## M000 - Product contract

Status: **complete**

Delivered product, architecture, evaluation, model, safety, learning, visual,
decision, and reference documents plus the canonical state file.

The 2026-09-22 correction adds the complete plan, code-reuse ledger,
Evidence-Native Generative Search thesis, recent enabling research, and hybrid
native/reused-core architecture.

Gate: see `LOCAL_BROWSER_STATE.md`.

## M001 - Reuse foundation and deterministic native vertical slice

Status: **complete** (gate audit `docs/evidence/M001/gate-audit.md`; declaration D015). Sibling extraction stays licence-gated (D011, task R1).

Learn:

- package extraction and cross-language boundaries;
- software licence and provenance discipline;
- Swift package and app structure;
- actors and cancellation;
- typed state machines;
- content addressing;
- dependency inversion; and
- why deterministic fixtures are instruments.

Build:

- resolve sibling ownership/licence/provenance;
- extract the sibling research seams into versioned `ResearchCore` boundaries;
- preserve the relevant existing deterministic tests;
- versioned authenticated local IPC plus event and Evidence UI schemas;
- native app and Swift presentation/core package;
- versioned entities/events;
- fake providers;
- frozen fixture corpus;
- full question-to-cited-answer slice;
- minimal Living Research Map screen; and
- unit plus UI verification.

Gate: recorded in `LOCAL_BROWSER_STATE.md`.

## M002 - Safe live acquisition

Status: **active; M002.1 (search adapter boundary and SearXNG JSON adapter),
M002.2 (safe acquisition boundary), M002.3 (robots and politeness boundary),
M002.4 (HTML extraction boundary), M002.5 (content snapshots), and M002.6
(bounded parallel fetch), M002.7 (extraction diagnostics), and M002.8
(approved live corpus tests) are complete. Milestone 003 is the active
milestone; M003.1 (lexical retrieval boundary: FTS5/BM25 over stored passages)
is complete and M003.2 (retrieval-backed citation compilation) is defined in
`project.json`. No corpus is approved,
so no live page has been fetched: the live-corpus portion of the gate below is
recorded as an explicit blocker rather than claimed.**

Learn:

- metasearch uncertainty;
- DNS and SSRF safety;
- HTTP semantics, robots, redirects, MIME and size limits;
- HTML extraction loss;
- PDF boundaries; and
- concurrency with polite per-host limits.

Build:

- SearXNG adapter;
- safe HTTP acquisition;
- HTML extraction;
- content snapshots;
- bounded parallel fetch;
- extraction diagnostics; and
- approved live corpus tests.

Gate:

- static HTML, redirects, PDF, duplicates, blocked paths, oversized content,
  invalid MIME, private addresses, timeouts, and extraction failures all produce
  expected typed outcomes;
- search snippets never become evidence;
- retries do not duplicate snapshots; and
- the deterministic M001 slice remains unchanged.

## M003 - First useful Quick release

Learn:

- local model capability boundaries;
- structured generation;
- streaming and cancellation;
- context and memory budgets;
- latency measurement; and
- packaging a native AI feature.

Build:

- FTS5/BM25 retrieval and deterministic source features;
- one approved local inference adapter;
- Quick mode end to end;
- citation compiler and inspector;
- history;
- global launcher;
- hardware-aware onboarding; and
- first packaged development build.

Gate:

- five frozen and five fresh representative searches complete;
- citation integrity is 100%;
- every failure has a typed reason;
- latency and peak resource use are recorded;
- no Docker or terminal is required for the app path; and
- a clean checkout reproduces the deterministic path.

This is the first usable product checkpoint.

## M004 - Retrieval treatment, only if required

Status: conditional.

Entry criterion:

- M003 error analysis identifies a stable passage-retrieval failure that the
  lexical/source baseline cannot meet.

Build only the smallest justified challenger. Candidates are not pre-approved.
Follow `docs/MODEL_POLICY.md`.

Gate:

- held-out retrieval or downstream citation quality improves by the frozen
  threshold;
- latency, memory, licence, and distribution remain within budget; and
- negative and no-benefit results are preserved.

If the entry criterion is not met, record `not needed` and proceed.

## M005 - Academic mode

Build:

- OpenAlex, Crossref, Semantic Scholar, and arXiv boundaries;
- DOI/version reconciliation;
- PDF/page-aware evidence;
- paper comparison and limitations;
- citation-neighborhood expansion; and
- BibTeX/RIS export.

Gate:

- authoritative metadata is traceable;
- exact paper passages/pages support generated claims;
- duplicate versions are reconciled without losing provenance;
- unsupported questions abstain; and
- the academic held-out set beats generic web search on citation quality.

## M006 - News mode

Build:

- temporal queries;
- event and syndication clustering;
- source-independence scoring;
- current-event timelines;
- conflict treatment; and
- update timestamps.

Gate:

- stale pages do not masquerade as current reporting;
- syndicated copies do not count as independent confirmation;
- material claims have independent evidence or visible uncertainty; and
- a frozen snapshot set makes regression comparisons reproducible.

## M007 - Deep mode

Build:

- editable dimension plan;
- bounded follow-up research;
- coverage and contradiction matrices;
- diminishing-evidence stop rule;
- pause/resume;
- `Research this gap`; and
- full Living Research Map provenance ribbons.

Gate:

- every loop terminates with a typed reason;
- repeated queries and sources cannot consume unlimited budget;
- injected failures resume without duplicated evidence;
- contradictions are not silently flattened; and
- controlled long-form benchmarks and manual review are reported separately.

## M008 - Evaluation and learning studio

Build:

- benchmark runner and variant comparison;
- human citation-review workflow;
- corruption tests;
- per-mode scorecards;
- generated learning lessons; and
- explain-back exercises.

Gate:

- integrity target is 100%;
- semantic evaluator is calibrated against held-out human labels;
- answer and citation metrics are not collapsed into one score;
- local and hosted results remain separate; and
- intentional corruptions are detected.

## M009 - Public Mac release

Build:

- signed and notarized distribution;
- model/storage management;
- Keychain settings;
- accessibility and reduced-motion coverage;
- recovery and privacy-safe diagnostics;
- second-machine reproduction;
- demo and public benchmark card; and
- contributor onboarding.

Gate:

- a new user installs and completes a search from the release artifact;
- a contributor builds and verifies a clean clone using documented commands;
- no secret, private snapshot, or unlicensed benchmark body is present;
- the public README claims match reproduced evidence; and
- licence selection is complete.
