# Local Lens - Canonical State

Last updated: 2026-09-22 (Australia/Sydney)

Status: **Milestone 001 is complete (gate audit: `docs/evidence/M001/`).
Milestone 002 (safe live acquisition) is next; M002.1 (search adapter
boundary with a SearXNG JSON adapter and stub-transport tests) is the sole
next task. Twenty-five deterministic tests pass and clean checkouts pass
`make gate`.**

This is the canonical chronological record. Future work must read this file
before selecting a task. A milestone is complete only when its exact gate and
observed evidence are recorded here.

## Objective

Build and understand a native, local-first macOS answer engine that supports
fast everyday questions, bounded deep research, academic discovery, and
time-sensitive news while keeping every factual claim inspectable through an
exact saved passage.

The product must be genuinely useful before it becomes broad. Quick mode and
the deterministic citation path take priority over provider count, model count,
or agent complexity.

## Fixed decisions

1. The selected visual direction is **Living Research Map**, preserved at
   `docs/design/local-lens-living-research-map.png`.
2. The primary product surface is a native macOS application built with
   SwiftUI and Swift Concurrency.
3. SQLite/FTS5 is the initial local store and lexical retrieval baseline.
4. Search, acquisition, inference, and reranking are replaceable adapters.
5. A citation is a typed link from a report claim to an exact passage in an
   immutable snapshot. A URL alone is not a citation.
6. Search snippets are discovery hints and can never be report evidence.
7. Quick, Deep, Academic, and News are frozen execution policies, not prompt
   labels.
8. Normal users must not need Docker or a terminal.
9. The deterministic demo must run without network access or API keys.
10. The first useful release is Quick mode; the project will not wait for all
    modes before becoming usable.
11. No model, embedding model, or reranker is evaluated without a measured
    product failure, a written hypothesis, a frozen task set, and promotion
    criteria.
12. Multi-agent orchestration, fine-tuning, and a vector database are deferred
    until simpler measured baselines fail.
13. The proven sibling research engine is the initial research-core foundation;
    it will be extracted behind a versioned local boundary rather than rewritten
    wholesale in Swift.
14. The product thesis is Evidence-Native Generative Search: a typed adaptive
    interface in which every factual field resolves to accepted claim/passage
    evidence.
15. AG-UI and A2UI inform internal event and UI schemas, but are not mandatory
    runtime dependencies for the first release.
16. Reuse the sibling's evidence and safety contracts, but replace its
    sequential execution schedule. Quick mode retrieves and narrows before
    batched model work, parallelizes only independent safe operations, enforces
    a wall deadline, and streams useful evidence early.

## Current environment evidence

Observed on 2026-09-22:

- macOS 27.0, arm64;
- Xcode 27.0;
- Swift 6.4;
- Python 3.11.9;
- Node 26.8.1;
- npm 11.19.0; and
- Docker 29.7.2.

The hardware capacity and model-memory envelope must be measured again inside
M003 before real local inference is selected. Historical sibling-project
measurements are guidance, not proof for this repository.

## Milestone 000 - Product contract

Status: **complete**

Delivered:

- product promise and non-goals;
- four mode contracts;
- native architecture and trust boundaries;
- exact citation and source-snapshot contract;
- model and reranker promotion policy;
- benchmark and corruption-test plan;
- security and privacy boundary;
- learning path;
- project map and milestone gates;
- durable decision and reference logs; and
- selected visual target copied into the repository.

Gate result:

- evidence model is explicit: pass;
- modes have bounded policies: pass;
- model experimentation is hypothesis-gated: pass;
- normal-user and contributor setup targets are explicit: pass;
- non-goals are explicit: pass;
- one next milestone is unambiguous: pass.

No runtime, app target, network integration, model, or benchmark result exists
yet. M000 is documentation and design evidence only.

## Milestone focus

### Milestone 001 - Deterministic native vertical slice

Status: **complete** (declaration D015; audit in `docs/evidence/M001/gate-audit.md`)

Build only:

- resolve ownership/licence/provenance for sibling code before copying it;
- extract a versioned `ResearchCore` package from the proven sibling seams;
- define an authenticated local IPC and event contract;
- a Swift package and macOS app target;
- versioned domain entities and run events;
- a trusted state transition table;
- content-addressed run artifacts;
- fake search, fetch, extractor, ranker, and model adapters;
- one frozen fixture question and source corpus;
- one answer with claim-to-passage citations;
- a minimal implementation of the selected Living Research Map screen; and
- deterministic unit and UI tests for the complete vertical slice.

M001 gate:

- a clean checkout builds with one documented command;
- the fixture runs without network access, API keys, Docker, or model weights;
- two runs produce the same normalized evidence and citation graph;
- every citation opens the exact saved passage;
- unknown fields and illegal state transitions fail closed;
- cancelling reaches a terminal `cancelled` state;
- restarting the application preserves the completed run; and
- the observed commands and results are appended below before M002 begins.

Explicitly prohibited in M001:

- live SearXNG;
- real page crawling;
- Apple or MLX inference;
- embeddings or rerankers;
- Deep, Academic, or News implementation;
- authentication, cloud sync, sharing, or deployment; and
- model comparisons.

WIP inherited at the M000/M001 boundary:

- `Package.swift`, `Makefile`, and three `Sources/LocalLensCore/*.swift` files
  were created before the reuse plan was corrected;
- the package initially failed because the declared app and test targets were
  empty;
- a minimal SwiftUI shell and four deterministic core tests were added;
- the package now builds and those four tests pass; and
- the domain and protocol shapes must still be audited against the extracted
  sibling schemas before the full M001 gate can pass.

## Chronological evidence log

### 2026-09-22 - M000 planning baseline

- The project directory began empty and was not a Git repository.
- Git was initialized on branch `main`; no files were staged and no commit was
  created.
- Sibling learning labs were reviewed for canonical state, one-milestone gates,
  deterministic fixtures, preserved failures, and first-class learning
  material.
- Public GitHub, X, Reddit, official Apple documentation, and evaluation papers
  were reviewed; `docs/REFERENCES.md` records the sources and bounded lessons.
- Three visual directions were generated. The user selected the third,
  **Living Research Map**.
- M000 planning artifacts were added. No product implementation was started.

### 2026-09-22 - M000 planning correction

- The initial plan was rejected as too vague about concrete reuse and product
  novelty.
- The sibling `../deep-research-agent` was inspected at revision `1b1a698`.
  It contains reusable typed research, acquisition, retrieval, citation, and
  evaluation seams and 184 discovered unit tests.
- No sibling `LICENSE` file was present. Direct code transfer is therefore an
  explicit M001 blocker until ownership, licence, and provenance are recorded.
- Current Apple Foundation Models, AG-UI, A2UI, contextual embedding, open-source
  answer-engine, and public X sources were reviewed and separated into adopt,
  adapt, conditional experiment, and reject-for-now decisions.
- `docs/COMPLETE_PLAN.md`, `docs/ADOPT_ADAPT_BUILD.md`, and
  `docs/INNOVATION_THESIS.md` now define the corrected product and execution
  plan.
- `project.json`, its JSON schema, and `docs/AI_HANDOFF.md` provide a validated
  machine-readable handoff for another coding model or contributor without
  replacing this chronological evidence record.
- A few Swift foundation files created during the planning boundary are
  preserved as unverified WIP. No build, test, runtime, model, or integration
  result is claimed.
- A static performance audit found sequential query search, sequential source
  acquisition, per-passage model work, later uncapped assessment calls, and an
  unenforced wall-clock setting in the sibling. `docs/PERFORMANCE_PLAN.md`
  records the replacement Quick schedule and honest provisional targets.

M000 correction gate:

- explicit code reuse boundary: pass;
- licence/provenance risk visible: pass;
- promotable but honest product thesis: pass;
- recent enabling work separated from shipping dependencies: pass;
- no-bake-off model/retrieval policy preserved: pass;
- one next milestone and its proof gate are explicit: pass.

### 2026-09-22 - M001 baseline and first-commit preparation

- A static sibling performance audit found sequential search, acquisition, and
  evidence-assessment work plus excessive model calls. The replacement schedule
  and provisional targets are recorded in `docs/PERFORMANCE_PLAN.md`.
- `.gitignore` was expanded for macOS, Swift/Xcode, Python, optional JavaScript
  tooling, editors, agents, credentials, logs, databases, private research,
  downloaded models, packaging, crashes, and profiling output. Public fixtures,
  lockfiles, benchmark summaries, source models, and `.gitkeep` placeholders
  remain eligible for version control.
- The first sandboxed `make build` attempt could not write Swift's user module
  cache. A normal-environment retry reached the project and correctly failed
  because `LocalLensApp` was empty.
- Added a minimal native SwiftUI shell and deterministic tests for stable IDs,
  legal and illegal transitions, and terminal cancellation.
- `make build`: pass in the normal environment.
- `make verify`: pass; 4 tests, 0 failures.
- `make validate-manifest`: pass; JSON schema and handoff invariants conform.
- `make run`: pass; the app process launches and shuts down cleanly. GUI
  content and interaction were not manually inspected.
- All baseline files were committed as the first repository commit `d3af88a`
  on `main` (34 files); the working tree is clean afterwards.

Proof boundary: the package and four initial core behaviors are
deterministically verified. The minimal app shell launches (process smoke
test only), the selected visual direction has not been implemented,
ResearchCore has not been extracted, and no live search or model/provider
path has been tested. M001 remains active.

### 2026-09-22 - M001.1 reuse provenance and protocol boundary

- Sibling audit at revision `1b1a698579ea6840f328c7ea6b9a288a4f26c2d9`:
  89 commits, sole author `msulemans`, clean tree, no `LICENSE` file, and 184
  test functions across 18 files. Recorded in `docs/REUSE_PROVENANCE.md`;
  code transfer stays blocked until a sibling licence exists (D011).
- Extraction list, exclusions, protocol surface, test mapping, and Swift WIP
  audit frozen in `docs/RESEARCH_CORE_BOUNDARY.md` (D012).
- Protocol v1 schemas added under `schemas/protocol/v1/` with a standard
  library validator; `make validate-schemas` and `make gate` expose the new
  checks.
- Commands and observed results: `make validate-schemas` pass (run_status=15,
  research_mode=4, evidence_relation=3); `make verify` pass; commits `762cf55`
  and `2522780`.
- Next eligible task: M001.2 deterministic offline fixture slice.

### 2026-09-22 - M001.2 deterministic offline fixture slice

- Added `Fixtures/deterministic/quick-coffee.json`, a synthetic
  redistributable corpus with three sources and three anchored claims.
- `DeterministicPipeline` runs fake search, fetch, extractor, and model
  adapters with content-addressed snapshot, passage, claim, evidence, and
  citation identities; synthesis is template-based, not model-generated.
- `IntegrityError` and `DeterministicPipeline.validate` fail closed on
  dangling references and quotes that are not exact passage substrings;
  fixture, run-event, and persisted-run decoding reject unknown fields.
- `RunStore` persists and reloads a completed run unchanged.
- Commands and observed results: `make verify` pass; 11 tests, 0 failures
  (7 new). Commit `75f50cc`.
- Boundary note: this slice is clean-room Swift; sibling extraction remains
  gated by `docs/REUSE_PROVENANCE.md` and is not claimed here.
- Handoff correction: the first M001.3 manifest dropped the blocked-reuse
  licence prerequisite; `make validate-manifest` rejected it, the prerequisite
  was restored, and the gate then passed.
- Next eligible task: M001.3 protocol boundary enforcement and typed stop
  transitions.

### 2026-09-22 - M001.3 protocol boundary enforcement

- `ProtocolEnvelopes` decodes commands (`start_run`, `cancel_run`), event
  envelopes, and typed error envelopes strictly: unknown fields, commands,
  event kinds, error codes, and unsupported `schema_version` values fail
  closed; round-trip tests cover each family.
- `RunStateMachine` gains typed `fail`, `exhaustBudget`, and
  `requestUserInput` stops with recorded reasons; the generic transition path
  cannot reach those statuses.
- `scripts/validate_protocol_schemas.py` now checks `ErrorCode` parity across
  all Swift sources.
- D013 records newline-delimited JSON over stdio as the first local IPC
  transport.
- Commands and observed results: `make gate` pass; 21 tests, 0 failures
  (10 new). Commit `5ba762d`.
- Next eligible task: M001.4 native fixture slice in the app with
  clean-checkout verification.

### 2026-09-22 - M001.4 native fixture slice and clean-checkout proof

- `FixtureWorkspace` resolves each citation to its claim, exact passage, and
  source with typed failures; `FixtureWorkspaceTests` cover resolution and
  the unknown-citation path.
- The app renders the fixture brief, citation list, and passage inspector;
  selecting a citation shows the exact saved passage text and hash.
- The app persists the completed run under
  `~/Library/Application Support/LocalLens/runs/` and reloads it on later
  launches.
- Commands and observed results: `make gate` pass; 23 tests, 0 failures.
  Smoke run: process launched and persisted `fixture-run.json`, which decodes
  as status `complete` with 3 citations, 4 passages, and 11 events. Clean
  checkout: `git clone` into a temporary directory and `make gate` pass on
  revision `386aafd`.
- Proof boundary: GUI appearance and pointer interaction were not visually
  inspected; persistence, resolution, and gate behavior are covered by tests
  and the persisted artifact.
- Commit `386aafd`. Next eligible task: M001.5 Living Research Map minimal
  screen and M001 gate audit.

### 2026-09-22 - M001.5 living research map, visual evidence, and gate audit

- `FixtureWorkspace.evidenceMap` builds one node per citation (claim,
  relation, exact passage, source) and fails closed on dangling references;
  two new tests cover map construction and map-selection resolution.
- The app adds a Citations/Map segmented view over the same selection; the
  map renders provenance cards and selecting a node opens the exact passage.
- Window verification: the app window was captured and inspected
  (`docs/evidence/M001/app-first-run.png`), showing the header, the question,
  `Quick · complete · 3 citations`, the citation list, and the inspector with
  the exact saved passage, source, and text hash. Switching segments through
  accessibility scripting was not available; pointer interaction remains
  unautomated.
- Restart evidence: a second launch left the persisted run file untouched
  (same mtime `Sep 22 21:18:45`, same size 7497 bytes), proving the app loaded
  the completed run instead of rewriting it.
- Gate audit recorded in `docs/evidence/M001/gate-audit.md`: gate items 1-8
  pass with commands and results; open items are named (licence-blocked
  sibling extraction, UI-automation decision, full map design, interaction
  testing).
- Commands and observed results: `make gate` pass; 25 tests, 0 failures.
  Clean checkout: `git clone` plus `make gate` pass on revision `912b563`.
  Commit `912b563`.
- Next eligible task: M001.6 close-out (UI-verification decision and
  milestone declaration).

### 2026-09-22 - M001.6 close-out and M001 declaration

- UI verification decided (D014): view-model tests plus scripted window
  capture into `docs/evidence/<milestone>/`, with `LOCAL_LENS_START_VIEW`
  selecting the captured view; XCUITest is deferred to the packaged app.
- Map view upgraded to the design's evidence-map hierarchy: claim cards with
  relation badges, source rows, colour-plus-text relations, and selection
  into the passage inspector. Captured as `docs/evidence/M001/app-map-view.png`.
- M001 declared complete (D015) against gate items 1-8 with recorded
  evidence. Carry-over: licence-gated sibling reuse (R1), full map design
  (M003), UI automation (packaged app). Design conformance ladder recorded in
  `docs/design/CONFORMANCE.md`.
- Commands and observed results: `make gate` pass; 25 tests, 0 failures.
- Next eligible task: M002.1 search adapter boundary with a SearXNG JSON
  adapter and stub-transport tests.

## Evidence append template

Every completed milestone entry must include:

```text
Date:
Scope actually executed:
Commit or working-tree state:
Commands:
Observed outputs:
Gate result:
Failures preserved at:
Decision:
Next eligible milestone:
```
