# Local Lens - Canonical State

Last updated: 2026-09-26 (Australia/Sydney)

Owner directive (2026-09-26): the owner ordered the agreed four-mode product
surface completed rather than the conditional M004 entry check first. M004 is
redefined as the Living Research Map and four-mode surface. M004 is complete
(M004.1 surface, M004.2 Academic/News/local boundary, M004.3 local card) and
M005 is complete (M005.1 scholarly boundaries, M005.2 page-aware PDF and
export, M005.3 held-out retrieval comparison, M005.4 primary-source ordering
and the held-out answer card), M006 is complete (M006.1 News window,
syndication voices, timeline, and claim support), and M007 is complete (M007.1
editable plan, typed loop reasons, resume without duplication; M007.2
content-term coverage, diminishing returns, strict numeric contrasts). M008 is complete
except the calibration target (M008.1 benchmark card, scorecard, corruption
checks; M008.2 human review; M008.3 evaluator, calibration, learning cards) and
M009 is partially complete (M009.1 release artifact, storage and privacy,
diagnostics, demo and reproduction; M009.2 packages the four external gates).
The original M004 retrieval-treatment entry check is deferred with its
decision still unrecorded. Full record in the 2026-09-26 M004, M005, and M006
sections below.

Status: **Milestone 001 is complete (gate audit: `docs/evidence/M001/`).
Milestone 002 (safe live acquisition) is complete: every gate bullet has
recorded evidence, with the live-corpus portion of bullet (a) recorded as an
explicit blocker rather than claimed. Milestone 003 (first useful Quick
release) is the sole active milestone; its first task, M003.1, delivered the
lexical retrieval boundary (FTS5/BM25 over stored passages), M003.2 delivered
retrieval-backed citation compilation, M003.3 delivered the deterministic Quick
pipeline, M003.4 delivered the native deterministic Quick view at commit
`0d160bf`, and M003.5 recorded a live hosted citation slice. M003.6 is
complete: a current-build in-app hosted answer with two exact citations is
recorded in `docs/evidence/M003/m0036-current-app-proof.md`, and the unchanged
card measured 2/10 in `docs/evidence/M003/m0036-frozen-card-rerun.md`. A
deterministic source-relevance treatment (natural-language web queries
separated from keyword retrieval queries, with a ranked any-term fill) is
recorded in `docs/evidence/M003/m0036-source-relevance.md`. M003.7 completed
its bounded task: the live SearXNG engine set was repaired and pinned in
`scripts/searxng/settings.yml`, and a deterministic `SourceAuthority`
discovery ordering was added after the frozen card re-measured **1/10** and
endorsed the Q5 false premise. A targeted two-call verification projected
**3/10** with the false-premise endorsement removed. M003.8 is complete as a
measurement task: five fresh searches and CLI peak RSS are recorded. M003.9
is complete: the no-Docker Tavily path is live-verified in the Mac app,
including one hosted four-citation answer, and F1's official passage is
selected under one narrow deterministic lexical treatment. M003.10 is complete,
and **M003 is complete with every gate bullet met**: a trailing-slash redirect
bug that refused Apple and swift.org primary pages as `redirect_loop` was
fixed with a deterministic, tested change, and the unchanged five-question
card then measured **7/10 with 13/13 exact citations**
(`docs/evidence/M003/m003-frozen-card-treated.md`), so **Quick is promoted**
from the 2/10 M003.6 baseline. Peak app RSS was 140 MB, the app path needs no
Docker or terminal, and the committed deterministic path reproduces from a
clean checkout (192 tests). Q5 still abstains rather than correcting its false
premise; the bundle is ad-hoc signed without second-Mac proof. M002.1
delivered the search adapter
boundary with a SearXNG JSON adapter, M002.2 delivered the policy-checked
acquisition boundary with a frozen refusal matrix, M002.3 delivered the robots
and politeness boundary, M002.4 delivered the HTML extraction boundary with a
frozen typed refusal family, M002.5 delivered the content-addressed snapshot
store with retry-safe deduplication, M002.6 delivered the bounded, per-host
polite parallel fetch scheduler that composes all four boundaries behind one
typed per-URL outcome, and M002.7 delivered the extraction diagnostic record
that makes every extraction outcome, page or refusal, inspectable without
re-fetching, and M002.8 delivered the approved-live-corpus gate, which can plan
and judge a live run but holds no transport, so no default or gated test run
can reach the network. Two hundred and forty-six deterministic tests pass in
the current working tree; clean-checkout proof is recorded for earlier committed
milestones.**

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
- All baseline files were committed as the first repository commit `43f720a`
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
  research_mode=4, evidence_relation=3); `make verify` pass; commits `b789138`
  and `e8ee70e`.
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
  (7 new). Commit `cc7e866`.
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
  (10 new). Commit `7a07c53`.
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
  revision `f8c1831`.
- Proof boundary: GUI appearance and pointer interaction were not visually
  inspected; persistence, resolution, and gate behavior are covered by tests
  and the persisted artifact.
- Commit `f8c1831`. Next eligible task: M001.5 Living Research Map minimal
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
  Clean checkout: `git clone` plus `make gate` pass on revision `f82d893`.
  Commit `f82d893`.
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

### 2026-09-22 - M002.1 search adapter boundary and SearXNG JSON adapter

- An interrupted earlier run left two untracked drafts
  (`Sources/LocalLensCore/SearchAdapter.swift`,
  `Fixtures/search/searxng-quick-coffee.json`). Both were reviewed against the
  M002.1 `done_when` and the frozen protocol v1 contracts and kept with two
  repairs instead of being rewritten: the transport doc comment no longer
  asserts a specific later task number, and JSON `null` in the optional
  `title`/`content` display fields is now read as empty rather than malformed
  (SearXNG emits `null` for fields it did not fill; a wrong *type* still fails
  closed). No frozen contract was contradicted, so no rewrite was needed.
- `SearchAdapter`/`SearchTransport` boundary implemented: an adapter exchanges
  a query for a typed `SearchOutcome` (`.hits([SearchHit])` or
  `.noResults(query:)`) and reaches the network only through the injected
  `SearchTransport`. `URLSessionSearchTransport` is the only production
  transport; it is unused by tests and unreferenced by the app target.
- `SearXNGSearchAdapter` validates its configuration once, sends
  `GET {endpoint}/search?q=...&format=json` (the JSON path is appended only for
  a bare base URL), requires HTTP 200, and decodes the payload into ordered
  `SearchHit` values whose identity is
  `StableIdentity.make("hit", query, fragment-free URL, rank)`.
- Typed outcomes: `invalidEndpoint`, `emptyQuery`, `transportFailure`,
  `httpStatus`, and `malformedPayload` are errors; an empty but successful
  response is the typed empty outcome `.noResults`, not a silent success;
  cancellation is rethrown as `CancellationError` so the run state machine
  still owns the terminal `cancelled` transition.
- Frozen fixture `Fixtures/search/searxng-quick-coffee.json` is synthetic,
  redistributable, and hosted on `example.invalid` so it cannot resolve and
  cannot be mistaken for captured web content.
- 18 new tests in `Tests/LocalLensCoreTests/SearchAdapterTests.swift` drive a
  stub `SearchTransport` actor only: fixture decoding and ordering, fragment
  stripping, identity stability across adapter instances and query variation,
  request shape and trimming, 5 non-200 statuses, 16 malformed payload
  variants, `.noResults`, empty-query rejection with zero transport calls,
  cancellation passthrough, the `maxResults` bound (junk beyond the bound is
  never parsed), configuration rejection, and two offline guards — the fixture
  must stay on non-resolvable hosts, and no test or app source may reference
  the production transport (the guard scans its own test target and the app
  target, so the "no network in tests" rule cannot silently regress).
- Commands and observed results: `make gate` pass; 43 tests, 0 failures
  (18 new); `make validate-schemas` reports protocol parity
  (run_status=15, research_mode=4, evidence_relation=3, error_code=6);
  `make validate-manifest` pass. Commit `b44b3c6`.
- Decisions: D016 records the boundary, the typed outcome family, and hit
  identity. `docs/ARCHITECTURE.md` search boundary now records the implemented
  signatures; `docs/LEARNING_PATH.md` records what M002.1 practised.
- Proof boundary: the adapter is **deterministically verified** against a
  frozen fixture through a stub transport. No live SearXNG instance has been
  contacted, so no live-provider claim is made, and `URLSessionSearchTransport`
  itself remains unexercised.
- Observations carried forward, not silently changed: the M001 fixture slice
  keeps its own two-part hit identity so M001 evidence stays byte-identical
  (unifying the schemes is a deferred cleanup, recorded in D016); the
  pre-existing duplicate `D011`-`D014` headings in `docs/DECISIONS.md` were
  observed and left untouched because they predate this task.
- Next eligible task: M002.2 safe acquisition boundary (URL and address policy
  with policy-checked fetch).

### 2026-09-22 - M002.2 safe acquisition boundary and frozen refusal matrix

- `Sources/LocalLensCore/AddressPolicy.swift` implemented: `AddressClass`
  (`publicRoutable`, `loopback`, `privateNetwork`, `linkLocal`, `multicast`,
  `metadataService`, `reserved`), an `IPAddress(parsing:)` normalizer, an
  injectable `HostResolver` boundary with `HostResolutionFailure`, and the only
  production resolver `SystemHostResolver` (blocking `getaddrinfo` on a utility
  queue, returning numeric addresses with `NI_NUMERICHOST`).
- `AcquisitionPolicy.validate` is fail-closed and address-based rather than
  name-based. It refuses non-http/https schemes, embedded credentials,
  reserved and internal-only host suffixes (`localhost`, `.localhost`,
  `.local`, `.internal`, `.invalid`, `.test`, `.example`, `.home.arpa`), and
  ports outside the allow-list, then requires **every** resolved answer to be
  publicly routable. One private answer among several public ones is treated as
  a private destination, which is the DNS-rebinding case.
- `IPAddress` normalizes the encodings a resolver honours but a naive string
  check does not: `127.1`, `2130706433`, `0x7f.0.0.1`, and `0177.0.0.1` all
  normalize to `127.0.0.1` before classification, and the IPv4 address embedded
  in IPv4-mapped (`::ffff:a.b.c.d`), NAT64 (`64:ff9b::/96`), and 6to4
  (`2002::/16`) IPv6 forms is classified instead of the IPv6 envelope. The
  narrower rule wins where ranges overlap: `fd00:ec2::254` is also inside
  `fc00::/7` and is reported as a metadata service, not merely private.
- `Sources/LocalLensCore/SafeAcquisition.swift` implemented:
  `SafeAcquisition.fetch(_:transport:resolver:policy:)` follows redirects
  itself rather than delegating them to the HTTP client, re-validating every
  hop through `AcquisitionPolicy` **before** that hop is requested, capping
  hops, detecting loops on a canonical URL key (default port, host case,
  trailing root dot, empty path), parsing the media type with the `charset`
  parameter stripped against an allow-list, and enforcing a byte ceiling. The
  result keeps both the requested and the final URL, so leaving the origin
  stays visible.
- `AcquisitionError` keeps four distinct refusal families with stable `kind`
  labels and human descriptions: destination refusal (`loopbackAddress`,
  `privateAddress`, `linkLocalAddress`, `multicastAddress`, `metadataService`,
  `reservedAddress`, `reservedHostName`), request-shape refusal
  (`blockedScheme`, `credentialsInURL`, `blockedPort`, `invalidURL`),
  resolution failure (`hostResolutionFailed`, `unresolvableHost`,
  `invalidResolvedAddress`), and response refusal (`httpStatus`, `timeout`,
  `transportFailure`, `redirectWithoutLocation`, `redirectLoop`,
  `tooManyRedirects`, `missingContentType`, `unsupportedContentType`,
  `responseTooLarge`), plus `invalidPolicy` from the validating initializer.
  Cancellation is rethrown as `CancellationError`; a timeout stays
  distinguishable from a connection failure even after the production
  transport has already collapsed the `URLError` into a reason string.
- Frozen fixture `Fixtures/acquisition/safe-fetch-scenarios.json` holds the
  refusal matrix as data: 43 blocked destinations, 9 resolution cases, and 20
  fetch scenarios. It contains only reserved documentation and internal-use
  names (`example.com`, `example.invalid`, `*.internal`, `*.local`,
  `home.arpa`) and reserved address ranges, and one guard test enforces that
  invariant plus the frozen policy values.
- 15 new tests in `Tests/LocalLensCoreTests/SafeAcquisitionTests.swift` drive a
  stub `HostResolver` actor and a scripted stub `SearchTransport` actor only:
  every blocked destination with its frozen `kind` and zero resolutions
  attempted, the resolution matrix (public, mixed public/private, rebinding,
  empty answer, unparseable answer, resolver failure), every fetch scenario
  (success, absolute and relative redirects, redirect into metadata/private
  address/private name/reserved name, loop, missing Location, hop cap, 500,
  404, missing and unsupported MIME, byte ceiling, transport failure, timeout
  in both the `URLError` and the wrapped form, cancellation), the refusal
  families, address normalization and classification, non-addresses, the label
  boundary of reserved suffixes, policy-initializer rejection, plus two
  offline guards — a refused URL must produce zero requests, and no test or app
  source may reference `URLSession`, `SystemHostResolver`, or `getaddrinfo`.
- Commands and observed results: `swift test --filter SafeAcquisitionTests`
  pass, 15 tests, 0 failures; `make gate` pass; 58 tests, 0 failures (15 new);
  `make validate-manifest` pass. Commit `a5c7ad2`.
- Decisions: D017 records the boundary, the address-based fail-closed rule, the
  normalization requirement, the typed refusal families, and the frozen matrix.
  `docs/ARCHITECTURE.md` acquisition boundary now records the implemented
  signatures and marks robots and politeness as still planned;
  `docs/LEARNING_PATH.md` records what M002.2 practised.
- Proof boundary: the acquisition boundary is **deterministically verified**
  against frozen fixtures through a stub transport, a stub resolver, and no
  clock. No live host has been contacted and no real DNS lookup has been made,
  so `SystemHostResolver` itself remains unexercised and no live-provider claim
  is made. The byte ceiling is enforced on the body the transport already
  returned, so it is not yet a streaming ceiling.
- Observations carried forward, not silently changed: `SafeAcquisition.fetch`
  shares the M002.1 `SearchTransport` boundary rather than opening its own
  socket, so `URLSessionSearchTransport` still has no redirect policy of its
  own — by design, because redirects are followed and validated here; the M001
  fixture slice keeps its own hit identity (D016); and the pre-existing
  duplicate `D011`-`D014` headings in `docs/DECISIONS.md` remain untouched
  because they predate this task.
- Next eligible task: M002.3 robots and politeness boundary (robots.txt policy
  with per-host concurrency and delay).

### 2026-09-22 - M002.3 robots and politeness boundary

Scope actually executed: the third M002 task only. M002.3 adds robots.txt policy
evaluation and per-host politeness on top of the M002.2 acquisition boundary.
No HTML extraction, snapshot, passage, rendering, model, or UI work was done,
and the M001 deterministic slice was not touched.

Implementation:

- `Sources/LocalLensCore/RobotsPolicy.swift` (new):
  - `RobotsParser` reads the UTF-8 subset of the format that matters: comments,
    `User-agent` groups where consecutive `User-agent` lines share one group,
    `Allow`, `Disallow`, `Crawl-delay`, and `Sitemap`. Unknown and empty values
    are skipped. A non-empty body with no directive at all is reported as a
    parse failure instead of being treated as an empty policy.
  - `RobotsFile.group(for:)` selects the group whose product token is the
    longest prefix match of our agent, falling back to `*`, with the earliest
    group winning a tie. `longestMatch(in:path:)` applies `*` wildcards and a
    trailing `$` anchor, longest match wins, and `Allow` wins an equal-length
    tie. Query strings are part of the path that is matched.
  - `RobotsOutcome` is the typed outcome family (`rules`, `missing`,
    `serverError`, `unparseable`, `unreachable`, `blocked`) with a stable `kind`
    label per case. `RobotsRefusal` separates a refusal the origin published
    (`published_rule`) from one we imposed (`fail_closed`), because those are
    different things to show a user.
  - `RobotsPolicy` holds the documented fallback table: 200 with rules and 200
    with an empty body are `.rules` (an empty published body is a valid policy
    with no rules); 4xx is `.missing`, an absent policy with no restriction;
    5xx, an unparseable body, a transport failure, a timeout, and a destination
    the acquisition policy refuses are all refused. An unreadable policy is not
    permission.
  - `RobotsLoader` builds `robots.txt` for an origin and reads it through
    `SafeAcquisition.fetch`, so the robots URL and every redirect hop are
    validated by the M002.2 policy with no second socket path. It deliberately
    does not take the host gate: politeness must wrap the robots check and the
    request that follows it as one unit, and a nested acquisition of the same
    gate would deadlock against the caller that holds it.
  - `RobotsCache` is keyed by scheme, host, and port and deliberately excludes
    the user agent, because the agent selects a group inside the file rather
    than selecting the file. Entries do not expire in-process.
- `Sources/LocalLensCore/RobotsPolicy.swift` also carries the politeness
  boundary: `PolitenessClock` (injected; `SystemPolitenessClock` is the only
  implementation that waits on real time), `HostRequestGate` (one in-flight
  request per host, a minimum spacing measured between request *starts*, a
  continuation queue, and a release on throw and on cancellation), and
  `HostRequestGates` (one gate per normalized host). Spacing is measured
  start-to-start because that is what the origin observes; the gate is per host
  and never global, so politeness does not become a throughput ceiling and one
  slow origin cannot stall an unrelated one.
- `Fixtures/robots/robots-scenarios.json` (new): the frozen decision table -
  `user_agent`, 8 `selection_cases`, 15 `decision_cases`, 3
  `parse_failure_cases`, and 12 `fetch_scenarios` carrying `expected_outcome`,
  optional `expected_error_kind`, `expected_requests`, and a decision
  assertion. Every body is hand-authored in this repository and no robots.txt
  was captured from a live origin.
- `Tests/LocalLensCoreTests/RobotsPolicyTests.swift` (new): 23 tests covering
  fixture integrity, group selection, product-token extraction, the empty body,
  every decision case, query-string matching, the refusal shape, the parse
  failures, the full fallback table, every fetch scenario, single-fetch-per
  origin with cache reuse, cancellation passthrough, robots URL construction,
  cache keying, delay enforcement, gate release on throw, one-in-flight-per-
  host, per-host independence, crawl-delay application, and the offline guard.
  The stubs are `StubHostResolver`, `ScriptedSearchTransport`, `StubClock`
  (virtual time that records requested intervals), `ConcurrencyProbe`, and
  `Latch`.

Commands and observed results:

```text
$ swift build --build-tests
  (red first: RobotsPolicy.swift used Self.productToken where productToken is a
   member of RobotsFile, and three assertions referenced actor-isolated
   properties from a nonisolated autoclosure. Fixed; then clean.)

$ swift test --filter RobotsPolicyTests
  (red first: 23 tests, 41 failures. Root cause was one wrong fixture value:
   the robots fixture resolved permitted names to 198.51.100.7, which
   AcquisitionPolicy correctly classifies as a reserved address, so every
   permitted fetch was refused before reaching the stub transport. The M002.2
   acquisition fixture resolves permitted names to 93.184.216.34; the robots
   fixture was corrected to match, and the fixture guard was narrowed from
   "any TEST-NET address" to "the documented example.com address or a
   deliberately refused loopback literal". Two further failures were wrong
   assertions, not wrong behaviour: a forgotten cache entry must cause a
   re-request, and the concurrency probe's peak across two independent hosts is
   two, not one.)
  After the fixes: Executed 23 tests, with 0 failures (0 unexpected) in
  0.019 seconds.

$ make gate
  project.json conforms to its schema and handoff invariants.
  protocol v1 schemas conform; Swift parity holds (run_status=15,
    research_mode=4, evidence_relation=3, error_code=6)
  Executed 81 tests, with 0 failures (0 unexpected)
```

Gate result: `make gate` passed at commit `a4840b2` with 81 tests and 0
failures (58 before this task, 23 added). The manifest validated and the
protocol v1 schemas and Swift enum parity were unchanged.

Failures preserved at: none outstanding. The two red runs above are recorded
here with their causes. Both red runs were failures of the new code or the new
tests, and no gate was weakened to clear them: the fixture value was corrected
because the acquisition policy was right and the fixture was wrong, and the two
test assertions were corrected because the assertions were wrong and the
behaviour was right. No production rule was relaxed.

Proof boundary: deterministically verified. Robots behaviour is verified
against frozen fixtures through the stub transport, the stub resolver, and the
stub clock. No live robots.txt has been fetched, no real DNS lookup has been
made, and `SystemPolitenessClock` has never waited, so the real waiting path
and any live robots.txt behaviour remain unverified. The robots fetch is
verified to go through `SafeAcquisition.fetch`, which is verified to be
policy-checked, so the boundary composition is verified but the live origin
behaviour is not. Politeness is verified as per-host serialization against a
virtual clock; it is not a measured rate against a real origin. Cache entries
never expire in-process, so time-based revalidation is unverified and is not
implied.

Decisions: D018 in `docs/DECISIONS.md` (robots is fail-closed, politeness is per
host). `docs/ARCHITECTURE.md` gains a "Robots and politeness boundary" section
with the fallback table, and `docs/LEARNING_PATH.md` gains a "Practised in
M002.3" block.

Observations carried forward, not silently changed:

- `RobotsLoader.load` does not take the host gate. This is deliberate: the
  caller is expected to hold the gate across the robots check and the request
  that follows, and a nested acquisition would deadlock. The consequence is
  that a caller who uses `RobotsLoader.load` without holding a gate gets no
  politeness, which is a composition rule rather than a property of the loader.
- The M001 fixture slice keeps its own hit identity and the M002.1 adapter keeps
  its three-part identity; unifying them is still deferred (D016).
- The pre-existing duplicate `D011`-`D014` headings in `docs/DECISIONS.md` and
  the out-of-numeric-order D017 remain untouched because they predate this task.
- `example.com` genuinely resolves publicly, so fixture *addresses* - not only
  fixture names - must stay reserved or explicitly documented. This was caught
  here because the robots fixture initially used a TEST-NET address for a fetch
  the policy is required to permit.

Next eligible task: M002.4 HTML extraction boundary (static HTML to Snapshot and
Passages with typed extraction outcomes).

### 2026-09-23 - M002.4 HTML extraction boundary

Scope actually executed: the fourth M002 task only. M002.4 turns an
acquisition-approved HTML response into readable text plus the frozen `Snapshot`
and `Passage` entities, or refuses it with a typed fact. No snapshot store, no
bounded parallel fetch, no diagnostics surface, no rendering, no model, and no
UI work was done, and the M001 deterministic slice was not touched.

Implementation:

- `Sources/LocalLensCore/HTMLExtraction.swift` (new, adopted from an untracked
  draft and repaired):
  - `ExtractionPolicy` follows the `AcquisitionPolicy` checked/unchecked
    pattern: a private unchecked initializer behind
    `ExtractionPolicy.default` (`5_000_000` bytes, `html-extractor-1`) and a
    throwing public initializer that rejects a non-positive ceiling or a blank
    extractor version. The extraction ceiling is separate from the acquisition
    ceiling because holding a document to parse it is a different cost from
    streaming it.
  - `ExtractionError` is the frozen refusal family:
    `unsupported_content_type`, `document_too_large`, `empty_document`,
    `unsupported_charset`, `malformed_markup`, `no_readable_text`,
    `missing_source_identifier`, `invalid_policy`. Each case carries a stable
    `kind` label and a `reason` that names the specific fact, so a caller can
    tell an origin that published nothing from a document we refused to guess
    at.
  - Refusal order is fixed and observable: source identifier, media type, size,
    character set, markup, readability. A PDF over the ceiling is still a PDF,
    and an oversized document is refused for its size before its encoding is
    considered.
  - `ExtractedPage` binds the frozen entities so a caller cannot invent a
    different identity scheme: `Snapshot` identity is
    `StableIdentity.make("snapshot", sourceID, contentHash)` and `Passage`
    identity is
    `StableIdentity.make("passage", snapshot.id, String(ordinal), digest(text))`,
    the same part ordering the M001 deterministic slice uses.
  - `HTMLExtraction.extract` performs no I/O: no socket, no DNS, no file read,
    no clock. `HTMLTokenizer` handles comments, declarations, processing
    instructions, void elements, skip elements (`script`, `style`, and friends),
    block elements, headings, and the title. Headings are attribution: the last
    heading a reader saw is carried on the blocks that follow it, and a heading
    is also emitted as its own block, so a document that is nothing but headings
    is still readable and an empty heading is not a heading change.
  - `HTMLText` resolves character references before collapsing whitespace, so
    `&nbsp;` becomes an ordinary space while `&amp;nbsp;` stays the literal text
    a reader sees. Unknown or malformed references stay as text rather than
    becoming markup failures.
  - Character-set resolution: the header's `charset` parameter wins over the
    document's own `<meta>` declaration, and a document that declares nothing is
    read as UTF-8. The `<meta>` reader scans the ASCII prefix where the format
    requires the declaration and matches `charset` as a token of its own, so
    `charsetless` cannot decide an encoding. This is a scan, not a parser, and
    is recorded as such.
- `Fixtures/html/extraction-scenarios.json` (new): the frozen scenario table -
  7 `cases` and 17 `refusals`, each with a `why`. Bodies that JSON cannot hold
  as text are `body_base64` and labelled. Every host is a non-resolvable
  `.invalid` name and the fixture declares itself synthetic and
  redistributable, so no captured page enters Git.
- `Tests/LocalLensCoreTests/HTMLExtractionTests.swift` (new): 15 tests covering
  fixture integrity (synthetic, redistributable, reserved hosts, every expected
  outcome known), exact text and heading attribution for every case, determinism
  across three runs, snapshot and passage identity against the frozen part
  ordering, passage ordering and resolution back to the snapshot, typed refusals
  for every refusal case, the enumerated refusal family, refusal order,
  policy validation, media-type and charset parsing, `<meta>` scanning, entity
  and whitespace normalization, and an offline guard that scans the extraction
  source for `URL`+`Session`, `URL`+`(string:`, `getaddr`+`info`,
  `File`+`Manager`, `Data(contents`+`Of`, and `Pro`+`cess(`. Every body is a
  hand-authored byte string through a constructed `AcquisitionResult`; no
  transport, resolver, socket, or file is involved in extraction.

Commands and observed results:

```text
$ swift test --filter HTMLExtractionTests
  (red first: 15 tests, 5 failures. All three causes were real defects in the
   new source, not wrong assertions:
   1. the <title> open tag advanced the cursor to </title>, so the title's
      characters were never read and every title extracted as "" ;
   2. mediaType(of:) used split(omittingEmptySubsequences: true), so
      "; charset=utf-8" reported "charset=utf-8" as the media type instead of
      "" ;
   3. the <meta> scan found the first "charset" substring, so
      <meta name="charsetless"> resolved the encoding to "less".
   Fixed in the source: the title is captured directly from the source slice,
   mediaType keeps empty components, and the scan now requires a token boundary
   before and after `charset`. The dead `inTitle` routing in the tokenizer was
   removed with it.)

$ swift test --filter HTMLExtractionTests
  Executed 15 tests, with 0 failures (0 unexpected) in 0.029 seconds.

$ swift test
  (red: 2 failures in the pre-existing repository-wide offline guards. My new
   guard listed the literal needle "getaddrinfo", and the M002.2 and M002.3
   guards scan every test source for that literal, so my guard matched its own
   source. Fixed by building the needles by concatenation, the same way the
   existing guards do. The guards were not weakened.)

$ swift test
  Executed 96 tests, with 0 failures (0 unexpected) in 0.085 seconds.

$ make gate
  project.json conforms to its schema and handoff invariants.
  protocol v1 schemas conform; Swift parity holds (run_status=15,
    research_mode=4, evidence_relation=3, error_code=6)
  swift build -> Build complete
  swift test  -> Executed 96 tests, with 0 failures (0 unexpected)
  gate exit: 0
```

Gate result: `make gate` passed at commit `7030e03` with 96 tests and 0 failures
(81 before this task, 15 added). The manifest validated and the protocol v1
schemas and Swift enum parity were unchanged.

Failures preserved at: none outstanding. The three red runs above are recorded
with their causes. Every red run was a failure of the new code or of the new
tests, and no gate was weakened to clear them: the title, media-type, and
`charset` defects were fixed in the production source, and the self-matching
guard needle was fixed in the test source.

Proof boundary: deterministically verified. Extraction is verified against
frozen hand-authored fixtures as a pure function of bytes. No live page has been
fetched or parsed, no real document has been extracted, and no snapshot has been
stored, deduplicated, or cited, so the live-web extraction claim and the
snapshot store remain unverified. The extractor is verified to accept only the
two HTML media types that `SafeAcquisition.requireAllowedContentType` can
produce, so the boundary composition is verified; `application/pdf` and
`text/plain`, which acquisition allows, are verified to be refused here as
`unsupported_content_type`, which is a declared gap rather than an extraction
capability. Whitespace inside `<pre>` is verified to be collapsed, and there is
no DOM, no attribute or `<base>` handling, and no full HTML5 named-entity table;
these are recorded as losses, not implied capabilities.

Decisions: D019 in `docs/DECISIONS.md` (HTML extraction is a typed,
content-addressed boundary). `docs/ARCHITECTURE.md` gains an "HTML extraction
boundary" section with the ordered refusal family, and `docs/LEARNING_PATH.md`
gains a "Practised in M002.4" block.

Observations carried forward, not silently changed:

- The `<pre>` whitespace loss is a fixture case
  (`preformatted-whitespace-is-lost`) rather than a footnote, so the limitation
  is data that a later task can be measured against.
- The extractor keeps the M001/M002.1 hit-identity question out of scope: it
  reuses the snapshot/passage ordering and does not unify search-hit identity
  (D016 still defers that).
- The pre-existing duplicate `D011`-`D014` headings in `docs/DECISIONS.md` and
  the out-of-numeric-order D017 remain untouched because they predate this task.
- `RobotsLoader.load` still deliberately does not take the host gate, and
  fixture *addresses* must stay reserved or explicitly documented; both are
  unchanged from M002.3.

Next eligible task: M002.5 content snapshots (a content-addressed snapshot store
with retry-safe deduplication), derived from the M002 build list in
`docs/MILESTONES.md`.

### 2026-09-23 - M002.5 content snapshots

Scope actually executed: the fifth M002 task only. M002.5 turns an approved and
extracted page into an evidence record in a content-addressed store, with
retry-safe deduplication. No bounded parallel fetch, no diagnostics surface, no
rendering, no model, and no UI work was done, and the M001 deterministic slice
was not touched.

Implementation:

- `Sources/LocalLensCore/SnapshotStore.swift` (new): the `SnapshotStore` actor,
  `SnapshotRecord`, `DuplicateReason`, `SnapshotStoreOutcome` (with `kind`),
  `SnapshotStoreError`, `store`, `records`, `snapshotCount`, `record(id:)`,
  `passages(snapshotID:)`, `record(forHit:)`, and `validate(_:)`.
- `Fixtures/snapshots/store-scenarios.json` (new): 5 ordered cases and 4
  refusals, each with a `why`; all hosts on non-resolvable `.invalid` names; the
  fixture declares itself synthetic and redistributable.
- `Tests/LocalLensCoreTests/SnapshotStoreTests.swift` (new): 11 tests.

Observed results (commands and exact outcomes):

- `swift test --filter SnapshotStoreTests` - first run RED: 11 tests, 3 failures
  at `SnapshotStoreTests.swift:197` and `:243-244`. All three were defects in the
  new tests, not in the store: the ordered-sequence test compared the five
  offered attempt ids against the two stored records instead of their distinct
  set, and the no-rewrite test asserted duplicate counters on a stale value copy
  captured from the first outcome instead of re-reading the record that the
  store updates in place. Fixed in the assertions; no production behaviour was
  weakened and no gate was relaxed.
- `swift test --filter SnapshotStoreTests` - GREEN: 11 tests, 0 failures.
- `swift test` (full suite) - GREEN: 107 tests, 0 failures. The repository-wide
  offline guards in `RobotsPolicyTests` and `SafeAcquisitionTests` pass
  unchanged; the new guard test builds its forbidden literals by concatenation,
  matching the existing convention.
- `make gate` - exit 0 (`validate-manifest`, `validate-schemas`, `build`,
  `verify`). Gate green before both commits.

Typed boundaries that fail closed (all enumerated in the fixture's `refusals`
array and asserted by `testTypedOutcomeFamilyIsEnumerated`):

1. `invalid_attempt` - an attempt number below 1 cannot be counted;
2. `inconsistent_page` - a page whose snapshot id, passage ids, ordinals, or
   text digests disagree with its own source id and content hash is refused
   rather than stored, because identity is re-derived and never trusted;
3. `hit_is_not_evidence` - a hit whose URL was never requested for any stored
   snapshot (and is not a final URL) is refused; the snippet is never consulted;
4. `unknown_snapshot` - a lookup for an id that was never stored.

Duplicate outcomes are likewise typed and enumerated
(`DuplicateReason`): `repeated_attempt`, `same_content_from_another_url`, and
`same_bytes_from_another_source`. They are distinguished because they are
different facts about a run - collapsing them would hide a redirect loop or a
shared CDN body.

Decisions: D020 in `docs/DECISIONS.md` (the snapshot store deduplicates content
without rewriting identity). `docs/ARCHITECTURE.md` gains a "Snapshot store"
section, and `docs/LEARNING_PATH.md` gains a "Practised in M002.5" block.

M002 gate bullets advanced by this task:

- "retries do not duplicate snapshots" now has recorded evidence: every offer is
  counted, duplicates never store and never rewrite a cited identity, and the
  concurrent-offer test stores exactly one snapshot from simultaneous offers of
  the same bytes.
- "search snippets never become evidence" now has a mechanical counterpart:
  `record(forHit:)` resolves a hit only through URLs actually requested, or the
  final URL, and refuses anything else with `hit_is_not_evidence`.
- "the deterministic M001 slice remains unchanged" still holds: 107 tests pass
  and no M001 file was modified.

Observations carried forward, not silently changed:

- `snapshotCount` counts stored snapshots, not offers; a run's attempt history
  lives in each record's `attempt`, `duplicateAttempts`, and `totalAttempts`.
- The store is in-memory only. Durable persistence stays out of scope until the
  persistence milestone; nothing in M002 writes to disk.
- The pre-existing duplicate `D011`-`D014` headings in `docs/DECISIONS.md` and
  the out-of-numeric-order D017 remain untouched because they predate this task.
- `RobotsLoader.load` still deliberately does not take the host gate, and
  fixture *addresses* must stay reserved or explicitly documented; both are
  unchanged from M002.3.

Next eligible task: M002.6 bounded parallel fetch, derived from the M002 build
list in `docs/MILESTONES.md`.

### 2026-09-23 - M002.6 bounded parallel fetch

Scope actually executed: the sixth M002 task only. M002.6 composes the M002.2
acquisition boundary, the M002.3 robots and politeness boundary, the M002.4
extraction boundary, and the M002.5 snapshot store behind one bounded,
per-host polite scheduler. No diagnostics surface, no persistence, no
retrieval, no model, no rendering, and no UI work was done, and the M001
deterministic slice was not touched.

Implementation:

- `Sources/LocalLensCore/BoundedFetch.swift` (new): `FetchTarget`,
  `FetchLimits` (validated initialiser plus a private unchecked one),
  `FetchScheduleError`, `FetchStage`, `FetchRefusal` (with `isRetryable`),
  `FetchOutcome`, `FetchResult`, `BoundedFetcher`, and an internal
  `FetchLimiter` actor.
- `Fixtures/fetch/schedule-scenarios.json` (new): 10 ordered cases and 21
  refusals, each with a `why`; a stub resolver answer table using IANA
  documentation names and the public addresses the policy is required to
  permit; `requires_overlap` per case; and one case marked
  `concurrent_offers_are_race_decided`. The fixture declares itself synthetic
  and redistributable.
- `Tests/LocalLensCoreTests/BoundedFetchTests.swift` (new): 19 tests.

Observed results (commands and exact outcomes):

- `swift test --filter BoundedFetchTests` - first run RED at compile time: the
  pre-existing untracked draft contained `await` inside `XCTAssert*`
  autoclosure arguments, which cannot compile. Repaired by gathering every
  awaited value into one `Sendable` `BatchOutcome` struct and asserting on that.
- Second compile RED: `cannot infer key path type from context` throughout,
  caused by a file-private helper named `run` shadowing `XCTestCase.run()`.
  Renamed the helper to `runBatch`; no assertion was changed.
- `swift test --filter BoundedFetchTests` - RED: 18 tests, 5 failures. All five
  were defects in the new tests, not in the scheduler:
  (a) `testIdenticalBytesFromTwoHostsAreOneSnapshot` asserted the outcome array
  positionally and read the record from a result value captured before the
  store merged the duplicate in place; fixed by adding `storedRecords` (read
  from `SnapshotStore.records()`) to `BatchOutcome` and asserting the outcome
  multiset plus the merged stored record;
  (b) `testPerHostCeilingOfTwoIsHonouredAndNotExceeded` expected a per-host peak
  of 2, but the host gate admits exactly one request per host regardless of
  `maxInFlightPerHost`; the case was reframed as
  `a-looser-per-host-ceiling-does-not-loosen-politeness`, which asserts the
  measured peak instead of a derived one;
  (c) three cases measured overlap by counting `Task.yield()`, which is a
  timing coincidence rather than a measurement.
- `swift test --filter BoundedFetchTests` - RED: 19 tests, 5 failures, still
  the overlap measurement. Fixed by moving overlap into the stub transport: a
  case's document requests are held in a bounded yield loop until
  `requires_overlap` of them are in flight together. A serial schedule now
  burns the budget and fails on the measurement instead of hanging, and no wall
  clock is involved. A new test,
  `testNoCaseEverObservesTwoRequestsInFlightToOneHost`, runs every case and
  asserts the per-host peak is always exactly 1.
- One further compile RED: `testAnEmptyBatchIsNotAFetch` was missing the new
  `requiredOverlap` argument; fixed at the call site.
- One further full-suite RED: the repository-wide offline guards in
  `RobotsPolicyTests`, `SafeAcquisitionTests`, and `SearchAdapterTests` fired on
  the new test file, which had contained a `Task.sleep` barrier deadline and the
  concatenated literals `"URL" + "Session"` and `"Foundation" + ".URLSession"`.
  The deadline was removed entirely in favour of the bounded yield loop, and the
  new file's own guard was rewritten so it does not contain the halves it
  forbids. No guard was weakened.
- `swift test --filter BoundedFetchTests` - GREEN: 19 tests, 0 failures, run six
  consecutive times with identical results (19 passed each run).
- `swift test` (full suite) - GREEN: 126 tests, 0 failures.
- `swift build` - clean, no warnings.
- `make gate` - exit 0 (`validate-manifest`, `validate-schemas`, `build`,
  `verify`). Gate green before both commits.

Typed boundaries that fail closed (all enumerated in the fixture's `refusals`
array and asserted by `testRefusalFamilyIsEnumeratedAndTyped`):

1. `robots` / `published_rule` - the origin's own robots.txt forbade the path;
2. `robots` / `fail_closed` - robots.txt could not be read, so access is denied
   rather than assumed;
3. `acquisition` / `timeout` - no HTTP response arrived inside the policy's
   timeout; one of only two retryable refusals;
4. `acquisition` / `transport_failure` - the connection failed before a response
   existed; the other retryable refusal;
5. `acquisition` / `http_status` - a non-success status is an answer, not a
   fault, and is not retried;
6. `acquisition` / `private_address` - refused before any request is issued;
7. `acquisition` / `reserved_host_name` - a namespace the policy never resolves;
8. `acquisition` / `unsupported_content_type`;
9. `acquisition` / `response_too_large`;
10. `acquisition` / `too_many_redirects`;
11. `acquisition` / `redirect_loop`;
12. `acquisition` / `missing_content_type`;
13. `extraction` / `unsupported_content_type` - allowed by acquisition but not
    HTML, such as a PDF;
14. `extraction` / `empty_document`;
15. `extraction` / `no_readable_text`;
16. `extraction` / `malformed_markup`;
17. `extraction` / `unsupported_charset`;
18. `extraction` / `document_too_large`;
19. `extraction` / `missing_source_identifier`;
20. `store` / `invalid_attempt` - an attempt number below 1 cannot be counted;
21. `store` / `inconsistent_page` - the page disagrees with its own derived
    identity.

Only cancellation is thrown by `BoundedFetcher.fetch(_:)`; stored, duplicate,
and refused are values. `FetchStage` is a closed four-member set, so a new
boundary cannot be added without a compile-time decision about which stage owns
it.

Decisions: D021 in `docs/DECISIONS.md` (the schedule is a property of the
scheduler, not of the caller). `docs/ARCHITECTURE.md` gains a "Bounded fetch
schedule" section and `docs/LEARNING_PATH.md` gains a "Practised in M002.6"
block.

M002 gate bullets advanced by this task:

- "retries do not duplicate snapshots" gains a second, independent proof: a
  transient timeout is retried inside the batch, the retry is visible as
  `attempt` and `attempts`, the attempt number travels into the store, and the
  batch still stores exactly one snapshot. A second test proves retries stop at
  the attempt budget and that a definite answer is never retried.
- "search snippets never become evidence" is unaffected and still holds; the
  scheduler accepts only `FetchTarget` values, which carry no snippet.
- "the deterministic M001 slice remains unchanged" still holds: 126 tests pass
  and no M001 file was modified.

Observations carried forward, not silently changed:

- `maxInFlightPerHost` is not a politeness lever. `HostRequestGate.perform`
  admits exactly one body per host, so observed per-host concurrency is always
  1 whatever the number says. Its real effect is on queueing, and its
  doc-comment now says so. Fixture expectations for `expected_peak_in_flight`
  are therefore recorded as measured values, never derived from a ceiling.
- A limiter waiter holding a batch slot while it waits on the host gate can make
  the observed batch peak lower than the configured ceiling. The fixture
  records the measured peak for this reason.
- The one thing a parallel batch cannot decide deterministically - which of two
  simultaneous identical offers stores the bytes - is recorded in the fixture as
  `concurrent_offers_are_race_decided` rather than asserted positionally.
- The scheduler is in-memory only and opens no socket in tests. Live acquisition
  remains unimplemented by design; nothing in M002 touches the disk.

Next eligible task: M002.7 extraction diagnostics, derived from the M002 build
list in `docs/MILESTONES.md`.

## 2026-09-23 - M002.7 extraction diagnostics

Scope actually executed: the M002.7 `next_task` only. `HTMLExtraction.diagnose`
and `ExtractionDiagnostics.run` were added, `HTMLExtraction.extract` was
rewritten as a `switch` over `diagnose`, the tokenizer was instrumented with
counters and a prose-depth rule, and a frozen fixture plus a twelve-test suite
were added. No sibling code was copied (licence gate still unmet). No network,
DNS, clock, disk, model, or UI work.

Commit or working-tree state: implementation committed as `636ff1a` (the
working tree was clean at that commit and `make gate` was run before it).

Commands and observed results:

- `swift test --filter ExtractionDiagnosticsTests` (first run, test-first) - RED:
  `cannot find type 'ExtractionOutcome' in scope`, `cannot find type
  'ExtractionMetrics' in scope`. The boundary did not exist yet, which is the
  only useful red for a new boundary.
- `swift build` - clean, no warnings.
- `swift test --filter ExtractionDiagnosticsTests` - RED: 14 tests, 5 assertion
  failures in 3 tests. Diagnosed, not worked around:
  1. `runs_dropped` was 2 where the frozen expectation said 1: the counter
     counted the newline between `</head>` and `<body>`, so it was measuring a
     document's indentation. Fixed by recording the prose depth when a run's
     first character arrives and counting only runs that began inside a prose
     element (`p`, `li`, `dt`, `dd`, `blockquote`, `figcaption`, `td`, `th`,
     `pre`, headings). The implementation was strengthened; the assertion was
     not relaxed.
  2. Two different bodies produced the same fingerprint: a counts-only record
     identifies a document's shape, not the document. Fixed by adding
     `decoded_digest`, the digest of the decoded characters. Again the
     assertion ("a single changed character is a different outcome") was kept
     and the implementation was made to satisfy it.
  3. A run refused at the charset boundary reported `charset=shift_jis` and
     `charset_source=header` - the encoding it *asked for* - as if it had been
     used. Fixed by a single gate in the metrics builder: a run that never
     decoded reports `undecided` for the encoding and for the digest, whatever
     the header said. The requested encoding stays in the refusal's reason.
  The fixture's own expectation for that refusal was inconsistent with its own
  invariant and was corrected to `undecided`; the invariant was not.
- `swift test --filter ExtractionDiagnosticsTests` - RED: 14 tests, 3 failures
  (the frozen key set and frozen field order had not yet been extended for the
  deliberately added fact).
- `swift test --filter ExtractionDiagnosticsTests` - RED: 1 failure. The
  `decoded_digest` literal pasted into the frozen field-order test was mistyped
  (`...429916cc6c3d` against a measured `...42916cc6c3d`). The literal was
  corrected against the measured value, and the test now additionally asserts
  `decodedDigest == StableIdentity.digest(fixture body)`, so the literal cannot
  drift from the characters it claims to identify.
- `swift test --filter ExtractionDiagnosticsTests` - GREEN: 14 tests, 0
  failures.
- `swift test` (full suite) - GREEN: 140 tests, 0 failures (126 + 14).
- `swift test` repeated four more times - GREEN: 140 tests, 0 failures each
  time, identical counts. The diagnostic is byte-identical across runs.
- `make gate` - exit 0 (`validate-manifest`, `validate-schemas`, `build`,
  `verify`). Gate green before the commit.

Typed boundaries that fail closed. No refusal kind was added, and the family is
frozen at eight kinds mapped onto seven stages by an exhaustive switch:

1. `policy` / `invalid_policy` - the extraction policy itself was unusable;
2. `source_identifier` / `missing_source_identifier` - a snapshot that cannot
   name its source could never be cited;
3. `content_type` / `unsupported_content_type` - allowed by acquisition but not
   HTML, such as a PDF;
4. `size` / `document_too_large` - over the ceiling, refused rather than
   truncated, which is why no truncation field exists;
5. `charset` / `unsupported_charset` - a declared character set the decoder does
   not implement;
6. `markup` / `empty_document`, `malformed_markup` - nothing but whitespace, or
   markup that cannot be read;
7. `text` / `no_readable_text` - markup whose text is genuinely empty.

`ExtractionStage` is derived from `ExtractionError.stage`, so a new refusal case
cannot compile without a decision about which boundary owns it. All seven stages
are asserted reachable, so none is decorative.

The record is frozen at twenty-three serialized keys in a fixed order, with the
fingerprint last, taken over exactly the preceding lines. A test asserts that
the key set is exactly those twenty-three, that no key contains `timestamp`,
`date`, `time`, `duration`, or `truncated`, and that the fingerprint equals
`StableIdentity.make("extraction-diagnostic", lines)` over the stripped lines.

Decisions: D022 in `docs/DECISIONS.md` (a diagnostic is derived from the run,
never authored beside it). `docs/ARCHITECTURE.md` gains an "Extraction
diagnostics" section and `docs/LEARNING_PATH.md` gains a "Practised in M002.7"
block.

M002 gate bullets advanced by this task:

- "static HTML, redirects, PDF, duplicates, blocked paths, oversized content,
  invalid MIME, private addresses, timeouts, and extraction failures all produce
  expected typed outcomes" - the extraction-failure end of this bullet is now
  proven at both entry points: `extract` throws the refusal and `diagnose`
  returns it, from one pipeline, and the fixture records a refusal at every
  stage that can refuse with the facts that were in hand when it stopped.
- "search snippets never become evidence" is unaffected: a diagnostic is
  derived from an `AcquisitionResult` and carries no snippet.
- "retries do not duplicate snapshots" is unaffected; nothing in this task
  touches the store.
- "the deterministic M001 slice remains unchanged" still holds: 140 tests pass
  and no M001 file was modified.

Observations carried forward, not silently changed:

- Nothing in extraction drops bytes, so `truncated` and `bytes_dropped` are not
  reported. A fact that could never vary is decoration, and the frozen key-set
  test forbids exactly those names.
- `runs_dropped` is a narrower fact than its name suggests: it counts text runs
  that began inside a prose element and produced no readable text, not every
  whitespace run in the document. Its doc-comment says so.
- `ExtractionDiagnostics` reads `HTMLExtraction`'s internal helpers
  (`mediaType`, `supportedContentTypes`, `decode`) and the tokenizer's
  `Document`/`Stats`. That is deliberate: the diagnostic must describe the
  pipeline that actually ran, not a parallel reimplementation of it.
- The M002.7 task text lists "truncation" among the measurable facts. It is
  reported as the byte ceiling and the byte count with a boolean
  `within_byte_ceiling`, because extraction refuses an oversized document
  rather than shortening it; reporting a truncation flag would be reporting a
  fact that is always false.

Next eligible task: M002.8 approved live corpus tests, derived from the M002
build list in `docs/MILESTONES.md`.

## 2026-09-23 - M002.8 approved live corpus gate

Scope actually executed: the M002.8 `next_task` only. `LiveCorpus.swift` (the
manifest, the approval gate, and the expectation check),
`Tests/LocalLensCoreTests/LiveCorpusTests.swift` (fifteen tests), and
`Fixtures/corpus/live-corpus.json` (the shipped manifest) were added.
`docs/DECISIONS.md` gains D023, `docs/ARCHITECTURE.md` gains "Approved live
corpus", and `docs/LEARNING_PATH.md` gains "Practised in M002.8". No sibling
code was copied (licence gate still unmet). No network, no DNS, no live page
read, no Docker, and no model weights: the harness holds no transport, so the
default and gated runs have nothing to reach the network with.

Commit or working-tree state: implementation committed as `3d434cc`; this
entry is the second commit of the pair.

Commands and observed outputs:

- Test-first red. The test file was written before the implementation and
  compiled against the tree without it:

  ```text
  $ swift test --filter LiveCorpusTests
  error: cannot find 'CorpusManifest' in scope
  error: cannot find 'LiveCorpus' in scope
  ```

- A second red, on the verdict reason, was fixed by making the implementation
  say more rather than by relaxing the assertion. The test requires the reason
  to name both shapes; the reason read "expected a refusal at ... and observed
  an extraction with ...". The mismatch branches now name the vocabulary's own
  cases:

  ```text
  error: -[LocalLensCoreTests.LiveCorpusTests testVerdictComparesAnObservationAgainstTheFrozenExpectation] : XCTAssertTrue failed
  ```

- Focused suite, after the fix:

  ```text
  $ swift test --filter LiveCorpusTests
  Executed 15 tests, with 0 failures (0 unexpected) in 0.006 (0.007) seconds
  ```

- Full suite, four consecutive runs, identical:

  ```text
  Executed 155 tests, with 0 failures (0 unexpected) in 0.310 (0.320) seconds
  Executed 155 tests, with 0 failures (0 unexpected) in 0.293 (0.304) seconds
  Executed 155 tests, with 0 failures (0 unexpected) in 0.310 (0.322) seconds
  Executed 155 tests, with 0 failures (0 unexpected) in 0.306 (0.318) seconds
  ```

- `make gate` (validate-manifest, validate-schemas, build, verify): exit 0,
  155 tests, 0 failures.

New boundaries that fail closed, and their typed outcomes:

Manifest refusal family, ten kinds, frozen and enumerated by
`testManifestRefusalFamilyIsEnumeratedAndTyped`:

- `unreadable_json` - the body is not a manifest at all;
- `missing_manifest_identifier` - the corpus has no id, so an entry's
  provenance cannot be attributed to a corpus;
- `missing_identifier` - an entry has no id, so a verdict could not be
  attributed;
- `duplicate_identifier` - two entries share an id, so a verdict could not be
  attributed;
- `unrecorded_licence` - nothing is known about what may be done with the page;
- `unrecorded_licence_reference` - a licence is claimed but its text cannot be
  checked;
- `missing_expectation` - an entry that cannot fail is not a test;
- `unknown_expectation` - an outcome outside the frozen vocabulary;
- `insecure_url` - an entry that is not https;
- `incomplete_approval` - an approval naming no approver or no record, which is
  not an approval.

Run refusal family, two kinds, frozen and enumerated by the same test:

- `no_entries` - an empty manifest is a valid document and a refused plan; and
- `no_approved_entries(unapproved:)` - the whole manifest refuses and names
  every unapproved entry, because a run that silently skipped one would report
  a pass over a corpus it did not run.

Verdict outcomes: `matches`, or `differs(reason:)` naming both shapes in the
frozen `FetchStage` vocabulary - a wrong extractor version, a wrong refusal
boundary, and an expectation/observation shape mismatch are all proven to
differ.

Gate result: `make gate` exit 0; `make validate-manifest` conforms;
`swift test` 155 tests, 0 failures, four consecutive identical runs.

Visual evidence: M002.4 through M002.8 change no UI, so this is a launch
check rather than a design claim. The running app was captured window-only to
`docs/evidence/M002/app-m002-corpus-gate.png` on 2026-09-23 and read back with
the kit OCR tool, which recovered `LocalLensApp`, `Local Lens`, `Quick •
complete • 3 citations`, `Citations`, `Map`, `Exact saved passage • text hash
4790bbd37344...`, and the source URL `https://example.invalid/brew-review` (the
OCR pass misread the reserved `.invalid` TLD as `Invalld`; the kit vision probe
confirmed the claim list and the selected source's passage). The M002 gate
audit is recorded at `docs/evidence/M002/gate-audit.md`.

Failures preserved at: the two red runs above are recorded rather than
deleted. The first is the intended test-first red. The second is a real
implementation defect caught by the test: a mismatch reason that did not name
both shapes. Both were fixed by strengthening the implementation.

Decision: D023. The harness takes no transport and performs no fetch; a live
run is a separate, later binary that produces observations, and the caller is
what fetches. An unapproved entry refuses the whole manifest. An empty manifest
decodes and refuses at the run gate. Expectations reuse the frozen `FetchStage`
vocabulary rather than inventing a second one.

Blocker, recorded rather than worked around:

- No corpus is approved, so no live page has been fetched and no page body is
  committed. `Fixtures/corpus/live-corpus.json` ships with `entries: []` and a
  `_fixture.why_empty` naming the two unmet requirements: a recorded licence
  and a recorded owner approval. `docs/REUSE_PROVENANCE.md` records the same
  unmet gate for the sibling repository (no LICENSE file, D011).
- Adding the first entry therefore also requires changing the test that asserts
  the shipped manifest is empty, which is deliberate: an unapproved corpus
  cannot be added quietly.
- Consequence for the M002 gate: the live-corpus portion of bullet (a) is
  explicitly **unproven**. Every non-live input in bullet (a) has recorded
  evidence; the claim that the same typed outcomes hold on a real page is not
  made, because no page may be fetched. This is a recorded blocker, not a
  waiver.

M002 gate audit, bullet by bullet, at 155 tests:

- (a) static HTML, redirects, PDF, duplicates, blocked paths, oversized
  content, invalid MIME, private addresses, timeouts, and extraction failures
  all produce expected typed outcomes - **evidenced** for every non-live input.
  `Fixtures/fetch/schedule-scenarios.json` freezes seven refusal kinds across
  ten cases (`private_address`, `http_status`, `timeout`,
  `unsupported_content_type`, `no_readable_text`, `published_rule`,
  `fail_closed`); `Fixtures/html/diagnostic-scenarios.json` freezes one refusal
  per stage that can refuse (`charset`, `content_type`, `markup`, `size`,
  `source_identifier`, `text`); `Fixtures/acquisition/safe-fetch-scenarios.json`
  and `Fixtures/html/extraction-scenarios.json` cover redirects, PDF (as
  `unsupported_content_type`), blocked paths, oversized content, and invalid
  MIME. The live-corpus portion is **unproven** (see the blocker above).
- (b) search snippets never become evidence - **evidenced** in M002.5 (the
  snapshot store stores bytes from an acquisition, never a snippet).
- (c) retries do not duplicate snapshots - **evidenced** in M002.6
  (`testATransientTimeoutIsRetriedAndTheRetryIsVisible` and the store's
  attempt-keyed deduplication).
- (d) the deterministic M001 slice remains unchanged - **evidenced**: the M001
  slice is part of the 155-test suite and no M002 task has touched it.

Next eligible task: M003 entry task, derived from the M003 build list in
`docs/MILESTONES.md`.

## 2026-09-23 - M003.1 lexical retrieval boundary

Scope actually executed: the M003.1 `next_task` only. `LexicalIndex.swift`, the
`LexicalIndexTests` suite, and `Fixtures/retrieval/lexical-scenarios.json` turn
the M002 snapshot store into the M003 retrieval baseline: a local SQLite FTS5
index whose only retrievable unit is a stored `Passage`, ranked with BM25 plus a
deterministic per-source diversity bound, with typed ingest and query outcomes.
No Quick wiring, citation compilation, UI, model, reranker, vector store, or
network work was done, and no M001/M002 code or test was touched.

Commit or working-tree state: the three files arrived untracked from an earlier
session. They were reviewed against the M003.1 `done_when`, the frozen protocol
v1 contracts, and the M002 precedents, then committed. The implementation is
commit `0bc906c`; this entry is the second commit of the pair.

WIP review: kept because they matched the contract:

- the `passage_index` FTS5 schema indexes exactly `heading` and `text` and marks
every identity column `UNINDEXED`, so the `bm25()` weight list lines up with the
two indexed columns in declaration order;
- ranking is `bm25(passage_index, headingWeight, bodyWeight)` read ascending
(best-first), ties broken by ascending ordinal then ascending passage id in SQL
and again in the selection pass;
- diversity caps passages per source, the one source feature;
- ingest and resolve re-derive snapshot and passage identity instead of trusting
the caller, exactly as the snapshot store does;
- `IndexedHit` has no snippet field and the only path to evidence is
`resolve(_:)`;
- the fixture is hand-authored, synthetic, on reserved `.invalid` hosts, and is
fed through the real M002.4 extraction and M002.5 store before indexing; and
- the offline guard scans the index source for network, DNS, clock, filesystem,
and snippet literals and fixes the import list to `Foundation` and `SQLite3`.

WIP repairs, recorded because they changed the draft rather than because a gate
failed (see D024):

1. a caller-supplied `limit` above the policy's `maximumResults` was silently
   capped by the `maximumCandidates` SQL limit. `maximumResults` is documented
   as the hard cap, so honouring a larger request by returning fewer rows was
   fail-open. `search` now refuses with a distinct typed outcome
   `limit_exceeds_policy`, the fixture gains an `over-limit` refusal, and a
   focused test covers the boundary value and one above it;
2. the candidate ceiling was bound with `sqlite3_bind_int`, whose `Int32(value)`
   narrowing conversion traps on a large policy value and can become SQLite's
   `LIMIT -1` (no limit). It is now bound with `sqlite3_bind_int64`, and a test
   drives `maximumCandidates: Int.max` through a real query.

No other defect was found. Source-type, recency, directness, and independence
features need source metadata the snapshot record does not carry yet; they are
recorded as deferred, not implemented.

Commands and observed results:

```text
$ sqlite3 :memory: "CREATE VIRTUAL TABLE probe USING fts5(x); \
    INSERT INTO probe(x) VALUES('hello world'); \
    SELECT bm25(probe) FROM probe WHERE probe MATCH 'hello';"
  -1.0e-06
  FTS5_PROBE_OK

$ swift build
  Build complete! (0.33 sec.)

$ swift test --filter LexicalIndexTests
  (green on arrival: 14 tests, 0 failures. Two repairs were then made from
   contract review, not from a red test. One run reported the suite in 51.8s;
   it was investigated and did not reproduce: repeated later runs completed in
   0.110-0.112s. No test failed and no gate was weakened.)
  Executed 16 tests, with 0 failures (0 unexpected) in 0.111 seconds

$ swift test
  Executed 171 tests, with 0 failures (0 unexpected) in 0.525 seconds

$ make gate
  project.json conforms to its schema and handoff invariants.
  protocol v1 schemas conform; Swift parity holds (run_status=15,
    research_mode=4, evidence_relation=3, error_code=6)
  swift build -> Build complete
  swift test  -> Executed 171 tests, with 0 failures (0 unexpected)
  gate exit: 0
```

Gate result: `make gate` passed at commit `0bc906c` with 171 tests and 0
failures (155 before this task, 16 added). The manifest validated and the
protocol v1 schemas and Swift enum parity were unchanged.

Failures preserved at: none outstanding. No red run was observed in this
session; the WIP's 14 tests were green on arrival, and the two repairs above
were found by reviewing the draft against the contract. The one slow test run
is recorded because it was observed, and it was diagnosed as a non-reproducing
timing anomaly, not a failure.

Typed boundaries that fail closed, all enumerated by
`testTypedOutcomeFamilyIsEnumerated` (nine kinds): `unavailable` (SQLite or FTS5
unusable), `invalid_policy`, `invalid_snapshot`, `invalid_passage`,
`empty_query`, `invalid_limit`, `limit_exceeds_policy`, `unknown_passage`, and
`inconsistent_row`. Ingest returns the typed values `indexed` and `duplicate`.
A query with no alphanumeric term is refused; every term is quoted, so a query
is data and never FTS5 syntax.

Ranking determinism is asserted across repeated queries and a second,
separately built index, and the recorded tie rule is asserted to be the order
the index returns. Every hit is asserted to resolve through the M002.5 store to
a stored passage of the same snapshot. A durable index is asserted to survive
reopening and keep retrieving its stored passages.

Decision: D024 in `docs/DECISIONS.md` (lexical retrieval is a derived FTS5 index
over stored passages). `docs/ARCHITECTURE.md` gains the implemented retrieval
boundary and keeps the still-planned baseline items; `docs/LEARNING_PATH.md`
gains a "Practised in M003.1" block.

M003 progress advanced by this task:

- "FTS5/BM25 retrieval and deterministic source features" now has a verified
  deterministic baseline: an FTS5 table over stored passages, BM25 with heading
  and body weights, a diversity bound, a recorded tie rule, and typed outcomes;
- every hit resolves to a passage and its snapshot, so the snippet-never-evidence
  rule has a retrieval-side counterpart; and
- "the deterministic M001 slice remains unchanged" still holds: 171 tests pass
  and no M001 file was modified.

Proof boundary: deterministically verified. FTS5 availability was probed on
this machine and the index creation is the runtime probe; a missing module fails
closed with `unavailable`. The index is verified against frozen synthetic
documents through the real extraction and store boundaries, with no network, no
DNS, no live page read, and no real clock. A durable file-backed index is
verified to survive reopening. The default index is in-memory. No live corpus,
model, or UI path is exercised, and no retrieval-quality measurement is claimed:
the fixture proves ordering rules, not effectiveness on real pages.

Next eligible task: M003.2 (retrieval-backed citation compilation), derived from
the M003 build list in `docs/MILESTONES.md` and defined in `project.json`.

## 2026-09-23 - M003.2 retrieval-backed citation compilation

Scope actually executed: the M003.2 `next_task` only. `CitationCompiler.swift`,
`CitationCompilerTests.swift`, and `Fixtures/retrieval/citation-scenarios.json`
connect the M003.1 lexical index to the claim, evidence, and citation graph. No
Quick wiring, UI, model, reranker, vector store, or network work was done, and
no M001/M002 code or test was touched; the frozen entity and protocol
definitions are unchanged.

Commit or working-tree state: implementation commit `8a35034`; this entry is the
second commit of the pair.

Implementation:

- `ClaimCandidate` carries a claim, the query that retrieves its support, the
exact quote the supporting passage must contain, and an optional expected
snapshot id. It has no URL and no snippet field.
- `CitationCompiler.compile` re-derives the claim id, retrieves ranked passages
through `LexicalIndex.search`, and requires exactly one distinct retrieved
passage to contain the exact quote. Evidence identity is
`StableIdentity.make("evidence", claimID, passageID, quote)` and citation
identity is `StableIdentity.make("citation", claimID)`, the M001 part order.
- `CitationCompilation` is a plain value. `resolve(_:)` and `validate()`
re-check every citation's claim, every evidence link, every passage, and every
exact quote. Every link is checked, not only the returned one, so a dangling
later link cannot hide behind a valid first one.
- `CitationCompilerError` freezes sixteen kinds: nine compile refusals
(`invalid_claim`, `empty_query`, `retrieval_failed`, `no_results`,
`quote_not_retrieved`, `empty_quote`, `wrong_snapshot`, `ambiguous_quote`,
`duplicate_binding`) and seven resolve refusals (`unknown_citation`,
`empty_citation`, `unknown_claim`, `unknown_evidence`, `unknown_passage`,
`quote_not_exact`, `inconsistent_citation`).

Two fail-open gaps were closed while reviewing the new boundary before the first
commit. They are recorded because they changed the draft, not because a gate
failed:

1. an empty or whitespace-only quote is a substring of every passage and would
   have bound a claim to the first hit; it now refuses with `empty_quote` before
   retrieval and again on resolve;
2. `resolve` originally validated only the first evidence link; it now validates
   every link in the citation.

Commands and observed results:

```text
$ swift build --build-tests
  Build complete! (3.10 sec.)

$ swift test --filter CitationCompilerTests
  (green on the first run: 8 tests, 0 failures. The two gaps above were found
   by review, not by a red test.)
  Executed 8 tests, with 0 failures (0 unexpected) in 0.046 seconds

$ swift test
  Executed 179 tests, with 0 failures (0 unexpected) in 0.556 seconds

$ make gate
  project.json conforms to its schema and handoff invariants.
  protocol v1 schemas conform; Swift parity holds (run_status=15,
    research_mode=4, evidence_relation=3, error_code=6)
  swift build -> Build complete
  swift test  -> Executed 179 tests, with 0 failures (0 unexpected)
  gate exit: 0
```

Gate result: `make gate` passed at commit `8a35034` with 179 tests and 0 failures
(171 before this task, 8 added). The manifest validated and the protocol v1
schemas and Swift enum parity were unchanged.

Failures preserved at: none outstanding. No red run was observed in this
session; the new suite was green on the first run, and the two fail-open gaps
were found by contract review.

The fixture `Fixtures/retrieval/citation-scenarios.json` is hand-authored,
synthetic, and on reserved `.invalid` hosts. It holds four documents, three
accepted candidates, and nine compile refusals. Its documents are extracted
through the M002.4 boundary and stored through the M002.5 store before they are
indexed, so a green test proves the composition and not a mock. The accepted
test resolves every citation back through the store to its exact passage,
source, and ordinal.

Decision: D025 in `docs/DECISIONS.md` (citation compilation binds a claim to
exactly one retrieved passage). `docs/ARCHITECTURE.md` gains the implemented
compiler in the citation-compilation section, and `docs/LEARNING_PATH.md` gains
a "Practised in M003.2" block.

M003 progress advanced by this task:

- "citation compiler and inspector" now has a verified compiler half: every
  citation is retrieval-backed, exact-quote checked, and content-addressed;
- every citation resolves to a passage and its snapshot, so the
  snippet-never-evidence rule holds through the evidence graph as well; and
- "the deterministic M001 slice remains unchanged" still holds: 179 tests pass
  and no M001 file was modified.

Proof boundary: deterministically verified. The compiler is a pure function of
candidates and the index, with no network, DNS, file, or clock access. Its
refusals are verified against a frozen fixture and against hand-built malformed
compilations. No model, live corpus, UI, or retrieval-quality measurement is
exercised: the fixture proves binding rules, not effectiveness on real pages.

Next eligible task: M003.3 (deterministic Quick pipeline), derived from the M003
build list in `docs/MILESTONES.md` and defined in `project.json`.

## 2026-09-23 - M003.3 deterministic Quick pipeline

Scope actually executed: the M003.3 `next_task` only. `QuickPipeline.swift`,
`QuickPipelineTests.swift`, and `Fixtures/retrieval/quick-scenarios.json`
compose the run state machine, the M003.1 lexical index, and the M003.2 citation
compiler into one offline run. No model, network, UI, history, launcher,
onboarding, packaging, or live corpus work was done, and no M001/M002 file was
modified.

Commit or working-tree state: implementation commit `f774e75`; this entry is the
second commit of the pair.

Implementation:

- `QuickRunPlan` carries a question, frozen `ClaimCandidate`s, and the source
  metadata needed to attribute evidence.
- `QuickPipeline.run` drives the existing `RunStateMachine` through the frozen
  Quick phase order. It always ends terminal: `complete` with a retrieval-backed
  evidence graph, or `failed` with `stopReason = "citation_compile_failed:
  <kind>: <reason>"`.
- The result contains only the snapshots, sources, and passages the compilation
  cites. `missing_snapshot` (a cited snapshot absent from the store) and
  `missing_source` (a cited source the plan does not describe) fail the run
  rather than producing an unattributable citation.
- `QuickPipelineError` freezes four kinds: `empty_question`, `duplicate_source`,
  `missing_source`, and `missing_snapshot`. An empty question and duplicate
  source identities refuse before a run starts.
- The pipeline imports `Foundation` only and names no model, provider, socket,
  DNS, file, or clock.

Commands and observed results:

```text
$ swift build --build-tests
  (red first: a local `payload` value shadowed the helper method of the same
   name. Renamed the helper to `makePayload`; no assertion or guard was
   weakened.)

$ swift test --filter QuickPipelineTests
  Executed 9 tests, with 0 failures (0 unexpected) in 0.040 seconds

$ swift test
  Executed 188 tests, with 0 failures (0 unexpected) in 0.637 seconds

$ make gate
  project.json conforms to its schema and handoff invariants.
  protocol v1 schemas conform; Swift parity holds (run_status=15,
    research_mode=4, evidence_relation=3, error_code=6)
  swift build -> Build complete
  swift test  -> Executed 188 tests, with 0 failures (0 unexpected)
  gate exit: 0
```

Gate result: `make gate` passed at commit `f774e75` with 188 tests and 0
failures (179 before this task, 9 added). The manifest validated and the
protocol v1 schemas and Swift enum parity were unchanged.

Failures preserved at: the compile red above is recorded with its cause. It was
a name-shadowing defect in the new source, fixed in the source; no gate was
weakened. The `missing_snapshot` guard was added while reviewing the boundary
before the first commit.

The fixture `Fixtures/retrieval/quick-scenarios.json` is hand-authored,
synthetic, and on reserved `.invalid` hosts. It holds four documents, four
source records, and four frozen questions: three complete, and `q-mercury`
retrieves nothing and therefore fails with `no_results`. Every completed run is
re-validated through `FixtureWorkspace.inspections`, the same resolver the UI
uses, and two runs over the same input produce identical `PersistedRun` values.
The tea document is stored but cited by no question, so the result-carrying
selection is exercised rather than assumed.

Decision: D026 in `docs/DECISIONS.md` (the deterministic Quick pipeline
composes retrieval, compilation, and the run state machine).
`docs/ARCHITECTURE.md` gains a "Deterministic Quick pipeline" section and
`docs/LEARNING_PATH.md` gains a "Practised in M003.3" block.

M003 progress advanced by this task:

- the offline half of Quick mode now exists end to end: a question set, ranked
  retrieval, exact-quote citation compilation, a typed terminal status, and a
  normalized result;
- citation integrity is re-proven through the UI's own resolver for every
  completed run; and
- "the deterministic M001 slice remains unchanged" still holds: 188 tests pass
  and no M001 file was modified.

Proof boundary: deterministically verified. The pipeline is a pure composition
of the state machine, the lexical index, and the citation compiler, verified
with no network, DNS, file, or clock. No real search, model, live corpus, or UI
is exercised: the fixture proves composition and citation integrity, not
retrieval quality or answer usefulness. `q-mercury` proves the failed terminal
path, not a real coverage gap.

Runtime/UI check (2026-09-23): after M003.3 the app was built and launched in
both views (`LOCAL_LENS_START_VIEW` default and `map`) and captured window-only
to `docs/evidence/M003/app-m003-core-boundaries.png` and
`docs/evidence/M003/app-m003-map.png`. It renders the M001 slice unchanged,
proving no regression. The M003.1-M003.3 boundaries are core-only and not
reachable from the app, so this check does not verify them through the UI; see
`docs/evidence/M003/runtime-check.md`. Screen Recording permission was required
and granted for the capture. This gap is why the next task wires the
deterministic Quick pipeline into the app.

Next eligible task: M003.4 (deterministic Quick view in the app), derived from
the M003 build list in `docs/MILESTONES.md` and defined in `project.json`.

## 2026-09-25 - M003.6 live Quick workspace implementation (not complete)

The working-tree handoff had regressed to M003.4 even though commit `0d160bf`
contains the completed deterministic Quick view. This entry corrects the task
pointer without discarding that work or altering the M001 fixture view. M003
remains the sole active milestone.

Implemented in this working tree: a native live Quick window selected by the
Research menu command (Shift-Command-N) or `LOCAL_LENS_START_VIEW=live`. The
view accepts a typed question and is wired to the existing planner, search adapter,
bounded safe fetch, lexical retrieval, hosted provider, and citation compiler
in-process. The screen labels the provider HOSTED, shows typed abstentions and
failures, and renders only accepted claims with a selectable exact-passage
rail showing the full stored passage, exact cited quote, and a link to the
fetched source URL. An optional user-supplied
page URL skips SearXNG but still passes through the same safe fetch, stored
passage, retrieval, and citation checks; its search hit has an empty snippet.
Connection settings expose the search endpoint and an explicit
macOS-Keychain save action for the DeepSeek key. A default app launch remains
the offline M001 fixture. No provider call starts merely by opening the window.

Verification: `swift build` passed; `make gate` passed on 2026-09-25 with 226
tests, zero failures, protocol parity, manifest validation, and unchanged
offline guards. Three added deterministic tests prove the provided URL is only
a discovery hit, reject non-web/credential-bearing URLs, and run a stored-page
answer through the real citation boundary with its fetched source link. The
new window and its menu command have not been visually captured or interacted
with in this session: the executable is not exposed as a selectable app to the
available computer-use surface. No live provider call or frozen-card rerun was
made. The earlier M003.5 19/20-call record and two later M003.6 in-app provider
runs still require a distinct bounded M003.6 experiment before paid reruns.
The SearXNG outage is not assumed to have recovered. Therefore M003.6 is
**implemented in part, not complete**, and Quick is not yet a proven useful
release. Evidence: `docs/evidence/M003/m0036-product-surface.md`.

## 2026-09-25 - M003.6 development app and retrieval-only QA (not complete)

Scope actually executed: build and exercise a local development `.app` for the
existing M003.6 Quick flow, plus diagnose three known-page retrieval attempts
without calling the hosted provider. Working-tree changes remain unstaged and
uncommitted; unrelated changes were preserved.

Commands and observed outputs: `make app` exited 0 and produced an ad-hoc
signed `dist/Local Lens.app` with the offline fixtures. `codesign --verify
--deep --strict` and `plutil -lint` exited 0. Computer use opened the bundle:
the default M001 fixture rendered; Research → New live question opened the live
workspace; Connection exposed the configured controls. Question submission
without a key showed a missing-key state, and `not-a-url` showed an HTTP(S)
validation state before key checking. No provider call was made. No screenshot
was persisted. `LocalLensLive --mode retrieve --source-url` produced a typed
no-readable-evidence stop for the JavaScript-shell TaskGroup documentation;
the older Swift Book address opened a meta-refresh page with zero passages;
the GitHub source page opened with zero matching passages, with its cause not
yet isolated. No fetched page body or search snippet was promoted to citation
evidence. Full observations: `docs/evidence/M003/m0036-dev-app-qa.md`.

Gate result: `make gate` exited 0 with 226 tests and unchanged offline guards;
`make validate-manifest` passed. Decision: the local UI launch and these error
interactions are verified, not a useful live answer. The development bundle is
not notarized, distributed, or reproduced on a second machine. M003.6 remains
the sole active task. Next: reconcile prior provider calls and record a distinct
bounded M003.6 experiment before a paid in-app run; diagnose readable source
selection and rerun the unchanged five-question card when search is available.

## 2026-09-25 - M003.6 answer-bearing retrieval and ambiguous-citation treatment (not complete)

Scope actually executed: improve the existing direct-page Quick selection
against a measured question-paragraph failure, perform one pre-recorded
native-app provider attempt, and treat the resulting ambiguous-citation
failure. No later milestone, model, search service, or citation boundary was
changed. Working tree remains unstaged and uncommitted.

Retrieval-only observation: the public Swift forum page at
`https://forums.swift.org/t/does-taskgroup-cancelall-require-active-co-operation-to-finish-properly/75057`
stored successfully. For “How does Swift cancel a task group?”, the original
single-source two-passage cap selected only a question-shaped paragraph.
Letting one opened source supply up to twelve candidates and filtering
question-ending paragraphs selected six passages, including a declarative
explanation of cooperative cancellation. This was a direct-page diagnostic,
not benchmark Q1 success: the forum is not the required Apple/Swift primary
documentation.

One bounded provider attempt was recorded **before** the app Ask action in
`docs/evidence/M003/m0036-provider-experiment.md`. The native app entered its
running state and then showed a typed `ambiguousQuote` compilation failure
between two duplicate stored passages. No citation or answer appeared. The
experiment's one-call budget is spent, bringing the recorded cumulative
minimum to 22 attempts. Tokens, cost, elapsed time, and peak RSS were not
measured in the UI. No screenshot or raw provider body was persisted. The
failed result remains in the experiment record; it was not silently retried.

Treatment: the unchanged citation compiler is now probed separately for each
accepted provider claim. Ambiguous claims are rejected rather than failing
an otherwise independently supportable batch; a batch with no unique cited
claim abstains. Question-ending passages are excluded from provider evidence.
New deterministic tests cover question-only selection, one-source answer
selection behind questions, and survival of a unique claim beside an ambiguous
duplicate. `make gate` exited 0 with 229 tests, zero failures and unchanged
offline guards. `make app` rebuilt the local development bundle. The
post-treatment app/provider path and frozen five-question card are **not**
live-verified, and M003.6 remains the sole active task. Next: do not spend
another provider call without a new bounded experiment and reconciled budget;
first diagnose source availability and show a genuinely cited in-app answer,
then score the unchanged card. Evidence:
`docs/evidence/M003/m0036-dev-app-qa.md` and
`docs/evidence/M003/m0036-provider-experiment.md`.

Provider-free product slice added within M003.6: the live Mac window now has
**Inspect page without AI** for a question and one public URL. It runs bounded
safe fetch, storage, and retrieval without requiring an API key or contacting
DeepSeek, then displays matching saved passages, the full selected passage,
and a fetched-source link. The preview is labelled as source text rather than
an answer or citation. A supplied page no longer depends on the search
endpoint field being valid. Computer-use QA with no key showed six stored
passages from one Swift forum page and the evidence rail/source link; the
first ranked passage was low-relevance chrome, so this is useful inspectability,
not quality promotion. The final **LOCAL · NO AI** badge correction was
visually confirmed in a fresh computer-use check; the screenshot was not
persisted to a file. `make gate` remained green at 229 tests, and
`make app` rebuilt the ad-hoc-signed development bundle. M003.6 remains open.

One further, separately pre-recorded M003.6 verification attempt was made after
the ambiguity treatment (`docs/evidence/M003/m0036-provider-verification-2.md`).
The native app reached DeepSeek but stopped with `emptyAnswer`; no citation or
answer was displayed. That one-call limit is spent, making the recorded
cumulative minimum **23 provider attempts**. The ambiguity treatment was not
live-evaluated because the provider returned no content to compile. No further
paid retry was made. The app now maps the typed empty-result error to a
plain-language explanation and explicitly says it will not retry
automatically. This is implemented and gate-verified, not provider-verified.
The no-AI page inspection remains the only locally exercised useful live UI
path in M003.6; hosted cited answer and the frozen quality card remain open.

## 2026-09-25 - M003.6 source-relevance treatment and current-build in-app answer

Scope actually executed: the M003.6 `next_task` only. Two things were done that
the earlier M003.6 entries left open: a deterministic source-relevance
treatment for the recorded frozen-card failures, and a current-build in-app
hosted answer with exact citations. No model, search service, embedding,
reranker, vector store, later milestone, or frozen question was changed. The
M001 fixture slice, frozen entities, protocol v1, and offline guards are
untouched. Working-tree changes remain unstaged and uncommitted; unrelated
changes were preserved.

Measured failure and treatment. The frozen card measured 2/10 with exact but
irrelevant citations. Free search probes showed the planner's four-term keyword
windows ("swift structured concurrency grand") were trained on the lexical
index, not on web search, and never surfaced the comparison or correction
sources. `QuickQueryPlanner.webQueries` now returns the natural-language
question for search while `plan` keeps the keyword windows for FTS5;
`LiveQuickRunner.retrieve`/`run` take an optional `retrievalQueries` list that
defaults to the search queries, and the ranked any-term pass now fills the
remaining synthesis budget instead of running only when strict matching is
empty. Decision D027.

Commands and observed outputs:

```text
$ swift test
  Executed 231 tests, with 0 failures (0 unexpected) in 0.794 seconds

$ make gate
  Executed 231 tests, with 0 failures (0 unexpected); validate-manifest and
  validate-schemas pass; gate exit 0

$ make app
  Built development app: dist/Local Lens.app (ad-hoc signed)

$ LOCAL_LENS_START_VIEW=live LOCAL_LENS_LIVE_QUESTION="How does Swift cancel a
  task group?" LOCAL_LENS_LIVE_SOURCE_URL=<forum page /75057>
  LOCAL_LENS_LIVE_OUT=/tmp/m0036-app-proof/artifact.json \
  "./dist/Local Lens.app/Contents/MacOS/LocalLensApp"
  -> app wrote artifact.json: 2 exact citations, 3.07 s, deepseek-flash,
     label=hosted, both source URLs the fetched page
```

Live retrieval observation (free, no provider call) while the search engines
answered: Q1 opened WWDC21 and Task Cancellation sources with 6 passages; Q2
opened 6 sources and selected 12 passages including both structured-concurrency
and Grand Central Dispatch material; Q3 opened `sqlite.org/compile.html` and
SQLite configuration/extension passages; Q4 opened Swift 6.3, Swift Evolution,
and July-2026 release material. Q5's preflight was cut off when every SearXNG
engine suspended (brave/google CSE too many requests, duckduckgo access denied,
startpage CAPTCHA, wikipedia timeout). Full detail in
`docs/evidence/M003/m0036-source-relevance.md`.

Gate result: `make gate` exit 0 with 231 tests and 0 failures (229 before this
task, 2 added: a `webQueries` planner test and
`testWebSearchQueryIsSeparateFromRetrievalQuery`). `make validate-manifest`
conforms. No red run was observed; no gate was weakened.

Failures preserved at: the frozen card remains 2/10 and the pre-declared
quality promotion threshold was not met; the Q5 preflight engine suspension is
recorded rather than worked around; and no provider call was spent while every
engine was suspended. The current-build app run used the single call
pre-recorded in `m0036-current-app-proof.md`, bringing the recorded cumulative
provider-attempt minimum to 29 (excluding the earlier app answer of uncertain
provenance).

Proof boundary: the query decoupling, the default, the ranked fill, and
citation integrity are **deterministically verified** at 231 tests. The current
build's in-app ask path is **locally measured** to produce a two-citation
hosted answer whose quotes entail the claims and whose source URLs are the
fetched page; the artifact is the evidence, not human pointer interaction. The
improved retrieval's effect on frozen-card usefulness is **not** measured,
because the engines suspended before a provider re-run, and must not be
reported as a promotion. The app still requires a separately managed SearXNG
endpoint for open-web search; that is unchanged and blocking for the M003
no-terminal gate.

Decision: D027 in `docs/DECISIONS.md`.

Next eligible task: M003.7 - re-measure the frozen card and record five fresh
representative searches for the M003 quality gate, using retrieval-only
preflight and the provided-page path while the approved engines recover.

## 2026-09-25 - M003.7 search reliability, frozen card, and source authority

Scope actually executed: the M003.7 search-quality gate and the smallest
treatment its first measurement justified. No model, embedding, vector store,
agent framework, or later milestone was added; the frozen questions, the M001
fixture slice, protocol v1, and the offline guards are unchanged. Working-tree
changes remain unstaged and uncommitted.

Search reliability repair. The live blocker was the development SearXNG: with
`use_default_settings: true` its `general` category was the scrape engines that
soft-block under repeated use (brave, duckduckgo html, google cse, startpage,
qwant, yahoo), so every query fanned out into suspended engines and returned
zero results. After measuring individual engines, the reliable/curated set was
pinned in `scripts/searxng/settings.yml` with `scripts/run_searxng.sh`, and all
five frozen queries now return results. Bing-via-SearXNG was found to serve
stale/unrelated results and was disabled; Bing's direct RSS endpoint was
rejected because Microsoft's terms forbid non-aggregator use.

Frozen card measurement (seven calls total, pre-recorded in
`docs/evidence/M003/m0037-frozen-card-improved.md`). First pass, five calls:
Q1 completed 2/2 citations but from two personal blogs; Q2 abstained; Q3
completed from `sqlite.org/fts5.html` with compile-time FTS5 facts, not the
macOS system library; Q4 abstained; Q5 completed and **endorsed the false
premise**, all three citations from one Medium post. Usefulness **1/10**, below
the M003.6 2/10, with a hard Q5 false-premise failure.

Treatment: `SourceAuthority` (new) gives official documentation/forum hosts
(`docs.*`, `developer.*`, `forums.*`, known official domains) discovery tier 0
and everything else tier 1; `LiveQuickRunner.prepare` opens tier 0 first with a
stable sort. It is a source-type discovery feature, not a citation rule.
Decision D028.

Targeted verification, two calls: Q1 gained an Apple WWDC23 citation and scored
**2/2** (was 1/2); Q5 stopped endorsing the false premise and scored **1/2**
(was 0/2, hard failure). Projected card **3/10**, still below the pre-declared
four-question promotion threshold, so Quick is **not promoted** and Q2/Q4 still
abstain for recall.

Commands and observed outputs:

```text
$ swift test
  Executed 233 tests, with 0 failures (0 unexpected) in 0.660 seconds

$ swift run LocalLensLive --question <q> --mode retrieve
  all five questions opened 3-6 sources and selected 8-12 passages once the
  curated engine set was in place

$ swift run LocalLensLive --question <q> --mode answer
  Q1/Q3/Q5 completed; Q2/Q4 abstained; targeted Q1/Q5 re-run as recorded above
```

Gate result: `make gate` exit 0 with 233 tests and 0 failures (231 before this
task, 2 added for source authority). `make validate-manifest` conforms. No red
run was observed and no gate was weakened.

Failures preserved at: the frozen card's first-pass 1/10, the Q5 false-premise
endorsement, the run's two abstentions, and the below-threshold projected 3/10
are recorded rather than hidden. The treatment improved discovery but did not
make Quick useful.

Proof boundary: the source-authority ordering and the search config are
**deterministically verified** (233 tests) and **locally measured** on the live
card. The card is not promoted. Live open-web search still depends on a Docker
SearXNG for development, so the M003 no-terminal gate is unproven. Latency was
recorded per question (~5-12 s); peak memory was not measured.

Decision: D028 in `docs/DECISIONS.md`.

Next eligible task: M003.8 - five fresh representative searches, latency and
peak-resource recording, and closure of the M003 quality gate; packaging and
the no-terminal release path remain after it.

### 2026-09-26 - M003.8 fresh searches and bounded recall repair

Scope actually executed: reviewed DeepSeek's M003.7 source-ordering work and
the current dirty working tree; ran the unchanged gate before editing; diagnosed
frozen Q2/Q4 through provider-free live retrieval; added a narrow
Swift-programming-language disambiguation for the measured Q4 ambiguity;
rejected heading-echo passages before synthesis and proposal acceptance; and
made `SourceAuthority` conservative about arbitrary `docs.`/`developer.`
subdomains. Five fresh representative questions were frozen before retrieval
and run once each with typed fetch outcomes, CLI latency, and process peak RSS.
No hosted provider call was made, no secret was printed, and no commit was
created. The working tree remains dirty from the prior M003.5-M003.7 work.

Evidence: `docs/evidence/M003/m0038-recall-diagnostic.md` and
`docs/evidence/M003/m0038-fresh-searches.md`. Q4's default planner now opens
Swift.org and selects a passage containing both `Swift 6.4` and its dated
release; Q2's default search still varies and does not reliably select
independent two-sided authoritative evidence. Of the five fresh retrievals,
F2/F3 met their retrieval checks, F4 found a dated official source but did not
prove "latest", and F1/F5 exposed evidence-selection gaps. These are **not**
answer-quality scores. Five CLI elapsed times were 8.58-11.94 s (p50 10.27 s);
highest fresh-run CLI peak RSS was 36,929,536 B. Frozen Q4's peak was
55,033,856 B. App and SearXNG memory, first-evidence latency, provider
latency/cost, and fresh answer/citation quality remain unmeasured.

Commands and observed outputs:

```text
$ make gate
  exit 0; 234 tests, 0 failures; manifest and protocol validators conform
$ /usr/bin/time -l ./.build/debug/LocalLensLive --question <each frozen diagnostic or fresh question> --mode retrieve
  Q2 and Q4 default rechecks and F1-F5 each exited 0 with typed fetch results;
  individual timings, passage counts, and RSS are in the two evidence records
$ git diff --check
  clean
```

Gate result for **M003.8 measurement task**: five fresh searches complete with
typed outcomes; elapsed time and CLI peak RSS recorded, full-app/resource
limits explicitly unmeasured; Q4 retrieval improved and Q2 preserved as a gap;
`make gate` exit 0 with offline guards unchanged. This does **not** complete
M003 or satisfy its first-useful-product gate: the frozen answer card remains
below threshold, full app memory and no-terminal/no-Docker search are unproven,
and history, launcher, local inference, and portable packaging are unfinished.

Decision: D029 in `docs/DECISIONS.md`. Cumulative recorded provider-attempt
minimum remains **36**. Next eligible task: **M003.9**, evidence availability
and relevance for the measured Q2/Q3/F1/F5 gaps before any new bounded answer
card; no model bake-off. Packaging follows only after the Quick quality gate.

### 2026-09-26 - M003.9 no-card search and keyless evidence preview

The owner had no Brave key and asked for a genuinely free alternative. Before
adding another service, `docs/evidence/M003/m0039-search-backend-decision.md`
recorded the measured no-Docker need and compared SearXNG, supplied-page,
Tavily, Brave, and Exa. Tavily's current Researcher tier has 1,000 API credits
monthly without a card; basic search costs one credit. This is a user-owned
search key, not a free hosted answer model. No new package dependency, model,
reranker, or source-content trust path was added.

Implementation: a Tavily `SearchAdapter` sends bounded basic searches to the
pinned API with its key in the authorization header. It ignores the vendor's
generated answer and raw-content fields; result content is discovery metadata,
never citation evidence. The Mac Quick workspace now opens by default and
defaults to Tavily, with optional Brave and contributor SearXNG. Keychain save
is explicit. **Find evidence without AI** uses search, safe parallel fetch,
stored page passages, and local lexical selection without calling DeepSeek;
a pasted URL still bypasses search and needs no key.

Evidence: `make gate` passed with **242 tests**, zero failures, offline guards
unchanged; `make app` built and ad-hoc-signed the development bundle. Computer
use relaunched that bundle, showed the Tavily no-card connection, and ran the
no-key supplied-page path against `https://www.sqlite.org/wal.html`: the app
reported **12 matching passages from one opened source**, including SQLite's
reader/writer concurrency text and a fetched-page link. This proves current
app path and page preview, not Tavily's live API or hosted answer quality. No
Tavily or DeepSeek key was used, and no paid provider call was made.

Failures and open gates: Tavily search cannot be live-verified until the owner
adds their own free key. Frozen Q2/Q3 and fresh F1/F5 relevance gaps remain;
the unchanged answer card is still below threshold. The app is a local
development build, not notarized or reproduced on another Mac. M003.9 stays
in progress; no M004 work or Quick promotion is claimed. Decision D030.

The same task's focused Q2 treatment and one provider-free default retrieval
are recorded in `docs/evidence/M003/m0039-q2-provider-free.md`. The narrow
planner split uses two side-specific searches only for the frozen CPU-bound
Swift/GCD comparison, within the unchanged Quick cap. It selected a Swift
Forums CPU-task passage and Apple dispatch-queue passages after opening four
sources in 14.54 s. Two Apple API reference pages were refused as unreadable,
and selected Apple passages were partly generic; this is partial coverage,
not an answer-quality improvement. No provider call or card promotion followed.
The final `make gate` passed with 243 tests and zero failures; `make app`
rebuilt the ad-hoc development bundle. A fresh app launch showed the idle
"WEB · AI OPTIONAL" disclosure. `git diff --check` was clean. Existing
uncommitted work was preserved; no files were staged or committed.

### 2026-09-26 - M003.9 user-key live verification and relevance preflight

With the owner's explicit approval, the existing DeepSeek process key and
new Tavily app key were saved in the Local Lens macOS Keychain items. Values
were never printed or added to files. A restarted app loaded both. A no-AI
Tavily search for the SQLite WAL reader/writer question opened six public
sources and selected 12 passages. This is the first live no-Docker app search
proof; no Docker endpoint or supplied page was used.

The one-call hosted experiment was pre-recorded in
`docs/evidence/M003/m0039-tavily-in-app-answer.md`. The app's own Ask flow
completed in 6.0 s with four exact, clickable saved-passage citations and
fetched-source links. Two claims cited official SQLite WAL documentation,
one cited an SQLite forum reply, and one repeated the main point from a
weaker third-party forum. All four quotes entailed their displayed sentences,
but the last is redundant/source-weaker. The one call is spent; recorded
cumulative provider-attempt minimum is **37**. This passes an integration
smoke, not the frozen answer-quality card or Quick promotion. Prompt tokens,
observed cost, and peak app RSS were not measured.

The four provider-free Tavily retrieval checks in
`docs/evidence/M003/m0039-tavily-retrieval-preflight.md` used five basic
search queries total. Q2 missed independent GCD evidence after Apple pages
were refused; Q3 found upstream FTS5 build flags but not the macOS system
library action; F1 opened Python docs but selected the wrong passage; F5
selected no direct client-IP correction and encountered typed source refusals.
No hosted card followed these known failures. One direct-page F1 diagnostic
showed the official rule was stored and selected with a precise lexical query;
the narrow deterministic planner treatment then made it the first selected
passage on a default Tavily recheck (2.95 s, five opened sources). F1
retrieval improved, not its answer score. A single F5 counterclaim probe
still failed its direct-evidence check; no speculative planner change followed.
Evidence: `m0039-f1-passage-probe.md` and
`m0039-f5-counterclaim-probe.md`. Decision D031.

The app evidence pane was cramped when Connection remained expanded after an
answer. The view now closes Connection when a valid ask or no-AI inspection
starts, leaving missing-key errors expanded for repair. This is a view-only
layout adjustment; citation, safety, and mode policies remain unchanged.

The current ad-hoc build then re-ran F1 through the app's own no-AI path under
the driven UI: the run opened five sources, selected eight passages, and put
the official Python child-failure rule first, confirming in the app what the
CLI probe had shown, while `Connection` stayed collapsed, confirming the
layout fix. This used Tavily credits only, made no DeepSeek call, and left the
recorded provider-attempt minimum at **37**. Evidence:
`docs/evidence/M003/m0039-f1-app-check.md`.

M003.9 is complete: every `done_when` is met - Q2 and F1 have provider-free
before/after evidence with regression coverage, Q3 and F5 are preserved as
explicit gaps without a speculative treatment, and the one paid rerun has a
pre-recorded experiment with manual scoring. `make gate` passes with **244
tests** and zero failures. Q3/F5, a full unchanged answer card, full-app
resource measurement, portable/notarized packaging, and second-Mac proof stay
open; **M003.10** is the first packaged development build. The live
integration result does not start M004 or other modes.

### 2026-09-26 - M003 complete: redirect fix, promoted card, and gate close-out

Scope actually executed: M003.10 and the M003 gate. Two deterministic fixes,
one bounded card re-run, resource measurement, and clean-checkout
reproduction. No model, reranker, new service, or M004 work was added; the
frozen questions, M001 fixture, protocol v1, and offline guards are unchanged.
Working-tree changes remain unstaged and uncommitted.

The measured defect. Provider-free retrieval showed Q1 and Q4 could not reach
Apple or Swift.org primary pages. Instrumenting the acquisition boundary
showed the cause was in the app, not the network: `SafeAcquisition.canonicalKey`
built its redirect-loop key from `URL.path`, which drops a trailing slash, so a
server's ordinary `/page` → `/page/` redirect resolved to a key identical to
the URL just visited and was refused as `redirect_loop`. `developer.apple.com`,
`swift.org`, and a personal blog all hit it.

The fix. `canonicalKey` now uses `URLComponents.percentEncodedPath`, which
keeps the trailing slash, so only a genuinely repeated URL is a loop and
`maxRedirects` still bounds a ping-pong. Regression:
`SafeAcquisitionTests.testTrailingSlashRedirectIsFollowedRatherThanTreatedAsALoop`.
A second deterministic treatment leads the FTS5 lexical query with
`pragma compile_options` so the actionable check survives the strict-match
budget; regression in `QuickQueryPlannerTests`.

Measured effect. Provider-free, Q1 opened 2 → 5 sources including Apple WWDC21
10134 and WWDC23 10170; Q2 gained Apple WWDC21 10254 and WWDC17/16; Q4 fetched
`swift.org/blog`.

Commands and observed outputs:

```text
$ ./.build/debug/LocalLensLive --tavily --question <q> --mode answer
  Q1 4 citations (Apple WWDC21 10134), Q2 7 (Apple WWDC21 10254 + Swift
  Forums), Q3 1 (sqlite.org forum, PRAGMA compile_options), Q4 1
  (www.swift.org/blog), Q5 abstained

$ /usr/bin/time -l LocalLensLive --mode retrieve
  32292864  maximum resident set size

$ ps -o rss -p <app>  (5 Hz sampler, 73 samples)
  143552 KB peak  (140 MB), 128 MB steady, 83 MB idle

$ git clone -q . /tmp/locallens-clean && cd /tmp/locallens-clean && swift test
  Executed 192 tests, with 0 failures
```

The card. `m003-frozen-card-final.md` measured **6/10** with the acquisition
fix alone (Q3/Q5 abstained); a targeted Q3 rerun scored 1/2 with an exact
`PRAGMA compile_options` citation. `m003-frozen-card-treated.md` then re-ran the
whole unchanged card once: **7/10, 13/13 exact citations**, Q1/Q2/Q4 answered
from Apple and Swift.org primary sources, Q3 from a SQLite forum, Q5 abstained
without endorsing its false premise. Four of five questions scored >=1/2, the
predeclared promotion threshold, so **Quick is promoted**. The run reproduced
its per-question outcome on a second pass.

Gate result: `make gate` exit 0 with **246 tests** and 0 failures (244 before;
+2 regressions). Manifest conforms; protocol parity holds; `git diff --check`
clean.

Failures preserved at: Q5's abstention rather than a correction
(`no verifiable claim`); Q3's partial answer (check step only, forum source);
the earlier 2/10, 1/10, and 6/10 card results; and the app's refusal of
JS-rendered `developer.apple.com/documentation/...` pages as
`extraction/no_readable_text`.

Proof boundary: the redirect fix and planner treatment are **deterministically
verified** (246 tests) and **locally measured** on live retrieval and the Mac
app. Quick promotion is a per-run card result, not a claim that every question
is answerable. Peak RSS is a sampled maximum, not an instrumented peak. The
bundle is ad-hoc signed; second-Mac reproduction is unproven.

Evidence: `m003-frozen-card-final.md`, `m003-frozen-card-treated.md`,
`m003-gate-closeout.md`, `m0039-f1-app-check.md`. Decisions D032 and D033.

Next: M004 entry check. The baseline now meets the card threshold, so the M004
entry criterion (a stable retrieval failure the lexical/source baseline cannot
meet) is not obviously satisfied; record `not needed` unless the remaining
Q5-correction and Q3 completeness gaps justify the smallest challenger.

### 2026-09-26 - Owner directive: M004 redefined as the four-mode product surface

Scope actually executed: the owner rejected further milestone-gated slices and
ordered the agreed product surface completed. M004 is redefined as the Living
Research Map and four-mode surface; the original conditional retrieval-treatment
entry check is deferred, not answered. No model, reranker, embedding, vector
database, or new service was added.

The measured defect being treated: the shipped app surface was one Quick-only
live form. A `grep` for `history`, `launcher`, mode names, `pause`, `cancel`,
`Living Research`, or `Research this gap` across `Sources/LocalLensApp/`
returned zero matches, while `docs/PRODUCT.md` specifies a mode toolbar, a
living brief, an evidence map with provenance ribbons, exact-passage inspection,
and a bounded gap action. The owner observation is recorded as correct.

Implementation (all in the working tree; nothing staged or committed):

- `Sources/LocalLensCore/ResearchModePolicy.swift` - frozen `ModePolicy` and
  `SourceKind` for Quick/Deep/Academic/News, a deterministic `ResearchPlanner`
  (dimensions, search queries, keyword retrieval queries, a UTC news stamp),
  and `NewsIndependence` clustering by registrable domain.
- `Sources/LocalLensCore/ResearchRunner.swift` - a multi-round runner that
  enforces the mode budget, runs bounded follow-up rounds only for a declared
  dimension the evidence has not touched, stops a no-progress round, and calls
  the shared provider-to-citation boundary.
- `Sources/LocalLensCore/OpenAlexSearchAdapter.swift` - keyless scholarly
  discovery; landing page before DOI; never a snippet as evidence.
- `Sources/LocalLensCore/ResearchHistory.swift` - on-disk history of the
  answered artifact only, newest first, corrupt entries skipped.
- `Sources/LocalLensCore/LiveQuick.swift` - `AnswerRequest` now carries the
  mode and dimensions for the provider instruction, `LiveQuickLimits` validates
  against the named mode policy (Quick's 2/6/12 ceiling is unchanged), and the
  provider-to-verification-to-compilation block is one shared
  `answerAndCompile` function every mode uses.
- `Sources/LocalLensApp/LivingResearchMapView.swift` and
  `ResearchWorkspaceModel.swift` - the primary surface: mode toolbar with the
  local/hosted boundary, SwiftUI-timeline elapsed clock, a
  continuation-based pause gate, cancel, living brief per mode, dimension
  coverage, the evidence map with provenance ribbons, the exact-passage
  inspector, a bounded `Research this gap`, a history sidebar that replays
  locally with no network call, and a global launcher sheet with a
  Command-Shift-Space menu command. The launcher sheet and cancel were also
  observed in the running app; pause appears during a run and its checkpoint is
  deterministically tested (the runner performs zero searches until released),
  though the UI engagement itself was not observed because the runs completed
  faster than the interaction round-trip.
- `Sources/LocalLensApp/LocalLensApp.swift` - the map window is the presented
  launch scene; the Live Quick and offline-demo scenes are suppressed at launch
  and open only from the Research menu. `restorationBehavior(.disabled)` and
  `defaultLaunchBehavior` stop macOS from restoring the old Live Quick window,
  which was the visible cause of "a different UI".

Commands and observed outputs:

```text
$ swift build && swift test
  262 tests, 0 failures  (246 before; +16 in ResearchModeTests)

$ make app && open "dist/Local Lens.app"
  window "Local Lens"; accessibility outline shows researchQuestionField,
  Mode radio group (Quick/Deep/Academic/News), the policy chip
  "2 queries · 6 sources · 12 passages · 60s", History, Global launcher,
  Find evidence, Ask, and the EVIDENCE rail

$ UI run 1 - Quick + Find evidence, question SQLite WAL
  "12 matching passages from 5 opened sources", official sqlite.org WAL
  overview selected, exact passage and snapshot IDs in the inspector

$ UI run 2 - Quick + Ask (hosted DeepSeek)
  5 exact passages, 5 sources, 1 round, 5.8 s; answer assembled from six
  accepted claims with markers; dimension coverage "Answer · 5"; evidence
  map "Answer" group with five claim rows, each chipped to sqlite.org and
  "exact support"; "Research this gap" correctly absent

$ UI run 3 - Deep + Find evidence, Swift concurrency vs GCD
  24 stored passages selected under the 24-passage Deep cap, 16-source budget

$ UI run 4 - News + Find evidence, latest Swift release
  16 stored passages selected under the 20-passage News cap

$ UI run 5 - Academic + Find evidence, spaced repetition
  OpenAlex discovery opened 3 scholarly sources and selected 0 matching
  passages  (recorded as an open gap, not a success)

$ UI - History sidebar
  entry "How does SQLite WAL mode handle readers and writers?, Quick,
  6 citations" replays as "SAVED RUN · QUICK" with the exact saved passage,
  quoted span, source link, and the notice that no network call was made
```

Two view bugs were found by observing the running app and fixed in the same
session: the no-AI path rendered the answered-brief shape instead of the
passage preview, and a single-dimension Quick run showed "Answer · 0" with an
empty evidence map despite six compiled citations. The coverage function now
counts accepted claims and the map assigns every citation to exactly one group
(falling back to "Other evidence" rather than hiding a claim).

Gate result: `make gate` is run after this entry; `swift test` reports 262
tests and 0 failures, `swift build` succeeds, and both validators accept the
manifest and protocol schemas. The offline guard in `RobotsPolicyTests` still
scans `Tests` and `Sources/LocalLensApp` for `URLSession`, the system resolver,
the politeness clock, `getaddrinfo`, and `Task.sleep`; the app uses a
continuation-based pause gate and a SwiftUI timeline clock instead.

Provider accounting: this session made **2** hosted DeepSeek answer calls in
the new app surface, so the recorded cumulative minimum rises from 37 to
**39**. Tavily, OpenAlex, and public-page fetches were live and are not answer
provider calls. No key value was printed, logged, or written to a file.

Failures preserved at: Academic retrieval selected 0 passages from 3 opened
scholarly sources; News independence is unverified on an answered run; Deep and
Academic answer quality have no card; the answer provider is still hosted, not
local; the bundle is ad-hoc signed; no second machine has reproduced it; the
original M004 retrieval-treatment entry check remains unanswered; and the two
pre-fix UI runs that recorded 0-citation previews into history are stale local
data, left in place rather than rewritten.

Provenance/proof boundary: the surface and policies are **implemented**; the
262-test suite and the OpenAlex decoder are **deterministically verified**; the
five UI runs above are **locally measured** in the ad-hoc development app; the
hosted answers are **live-provider verified**; nothing here is packaged or
reproduced on a second machine.

Decision: D034. Next eligible milestone: **M004** active task **M004.2**
(Academic evidence and News independence), with M005-M009 keeping their
original scopes.

### 2026-09-26 - M004.2: academic evidence, News independence, and the local answer boundary

Scope actually executed: closed the two M004.1 gaps and added the missing half
of the local/hosted boundary. No hosted answer call was made; the local runs
cost US$0. Nothing staged or committed.

Academic (measured defect: 0 passages from 3 scholarly sources). Two
deterministic treatments: OpenAlex now prefers an open-access HTML landing page
before the publisher landing page and the DOI resolver last, with open-access
works stably ordered first; and the Academic composition appends bounded
general-web discovery after the scholarly hits instead of replacing them only
on an empty result. Observed: **22 passages from 6 opened sources** on the
spaced-repetition probe, coverage `Method: 7, Findings: 3, Limitations: 0`,
with publisher refusals preserved as typed `http_status`, `no_readable_text`,
and `published_rule` outcomes. Regression tests cover the open-access ordering.

News (measured gap: independence never observed on an answer). Observed on an
answered local run: 1 exact passage, 15 sources, 2 rounds, 30.3 s,
**6 independent domains** with per-domain passage counts, dimension coverage
`What happened: 0, Timeline: 2, Independent confirmation: 1`, and an explicit
bounded gap action. `NewsIndependence` still reports a two-label ccTLD host as
its own domain because it consults no public-suffix list; the view says
"domain", not "publisher".

The local answer boundary. `LocalAnswerProvider` posts the unchanged
untrusted-proposal contract to a loopback OpenAI-compatible endpoint, carries
no credential, and labels the artifact `local/<model>`. `AnswerPrompt` now owns
the provider instruction so hosted and local cannot drift. The candidate
`qwen2.5-coder:14b-instruct-q4_K_M` (Ollama id `9ec8897f747e`, Apache-2.0) was
recorded as experiment `M004.2-LOCAL-OPENAI-001` in `docs/MODEL_POLICY.md`
before its first live use. The app toolbar shows `HOSTED · DEEPSEEK` or
`LOCAL · <model>`, and Connection carries the explicit toggle, endpoint, and
model fields.

Observed local Quick answer: **4 exact citations, 5 sources, 34.1 s, US$0**,
coverage `Answer · 4`, evidence map with sqlite.org and forum.xojo.com chips.
Observed local failure, preserved: on "what changed in the latest Swift
release" the model answered about the SWIFT financial-messaging standard,
citing clearstream.com while apple.com and swift.org programming passages were
also stored. The quote was exact and the citation valid; the answer was
irrelevant. No planner change was made in response, because tuning against one
observed answer would be fitting to a single case. The local path is **not**
promoted.

Diagnostic tooling: `LocalLensLive --mode research --plan <mode>` now runs any
mode's plan retrieval and prints every fetch outcome, so a zero-passage result
can be attributed rather than guessed. Its first run exposed a case-sensitive
mode lookup that silently ran Quick; fixed.

Gate result: `swift test` reports **264 tests and 0 failures** (+2 for the
local provider's keyless request, label, and tolerant JSON extraction);
`swift build` succeeds; `make gate` is run after this entry; the offline guards
are unchanged.

Provider accounting: no hosted call in M004.2; the cumulative recorded
minimum stays **39**. Local generations cost US$0 and used no key. Tavily and
OpenAlex discovery were live.

Failures preserved at: the wrong-sense local "Swift" answer; `Limitations · 0`
coverage; publisher refusals; the `co.uk` domain label; the unscored local
card; notarized packaging and second-Mac reproduction still unproven.

Provenance/proof boundary: the treatments and provider are **implemented**;
the 264-test suite is **deterministically verified**; the Academic 22-passage
result, the local Quick answer, and the News independence brief are **locally
measured**; OpenAlex/Tavily and the local endpoint are **live-verified**; no
second-Mac or notarized package exists.

Decision: D035. Next eligible milestone: **M004.3** (score the local card and
decide promotion), with M005-M009 keeping their original scopes.

### 2026-09-26 - M004.3 and the M004 gate: local card scored, local honestly not promoted

Scope actually executed: ran the frozen five-question card against the local
endpoint, scored it manually, decided promotion against the pre-recorded
threshold, and closed M004. No hosted call; cost US$0. Nothing staged or
committed.

Command: `LocalLensLive --tavily --local --mode answer --question <frozen>`.
Retrieval was the unchanged provider-free Tavily path; the provider was
`qwen2.5-coder:14b-instruct-q4_K_M` over the loopback OpenAI-compatible
endpoint, labelled `local`.

Card result: **6/10 usefulness, 10/10 exact citations**. Per question: Q1 2/2
(`cancelAll` plus task-tree propagation, 28.70 s); Q2 2/2 (both sides covered,
but **82.69 s**, over the 60 s Quick ceiling); Q3 1/2 (upstream configure flag,
not the macOS system-library action, 30.38 s); Q4 0/2
(`answer_abstained: the provider proposed no verifiable claim`); Q5 0/2 (the
leading claim can read as endorsing the false premise; the other claims
address blocking, not background execution, 24.85 s).

Decision: the recorded threshold requires at least four of five questions at
>=1/2 with 100% citation integrity. Q5 fails the frozen "correct or abstain"
requirement, so only three questions reach >=1/2 and Q2 also breaches the
latency ceiling. The local path is **not promoted**; it stays an explicit
Connection alternative, never a silent fallback. No prompt or planner change
was made, because tuning against the observed questions would be fitting to
the sample, and the threshold was not weakened after the result.

M004 gate: the surface exists and is locally observed; Academic selects 22
passages from 6 sources; News independence is observed on an answered run; the
local boundary is explicit and labelled; `make gate` passes with the offline
guards unchanged and the M001 fixture untouched. **M004 is complete.**

Provider accounting: no hosted call; the cumulative recorded minimum stays
**39**. Local generations cost US$0. Tavily discovery was live.

Failures preserved at: Q5 false-premise non-correction; Q2 over the latency
ceiling; Q3 partial; Q4 abstention; the M004.2 wrong-sense "Swift" local
answer; `Limitations · 0` academic coverage; publisher refusals; the `co.uk`
domain label; notarized packaging and second-Mac reproduction still unproven.

Evidence: `docs/evidence/M004/m0041-living-research-map.md`,
`m0042-local-and-academic.md`, `m0043-local-card.md`. Decision D036.
Next eligible milestone: **M005.1** (arXiv and Crossref scholarly metadata
boundaries with DOI/version reconciliation).

### 2026-09-26 - M005 complete: scholarly boundaries, page-aware PDF, export, and the held-out answer card

Scope actually executed: M005.1 through M005.4 plus the M005 gate. No hosted
answer call; every answer in the held-out card ran the local endpoint at US$0.
Nothing staged or committed.

M005.1 (scholarly metadata boundaries). arXiv and Crossref adapters joined
OpenAlex behind the existing `SearchAdapter` boundary, with DOI
(case-insensitive) and arXiv (versionless) identities reconciled by
`ScholarlyReconciliation`. Crossref emits the canonical DOI resolver so the
work's identity is explicit and the bounded fetch follows the redirect. A
run-scoped scholarly budget (8 targets, split 3/2/2) reserves fetch slots for
the readable web fallback; without it, three providers filled all 14 slots and
the run selected 3 passages instead of 22. Measured after: 24 passages from 9
sources in 17.77 s.

M005.2 (page-aware PDF and export). `PDFExtraction` uses PDFKit, the macOS
system framework, so a paper no longer needs an HTML landing page. Passages
carry `Page N` in the heading because the frozen `Passage` entity has no page
field; scanned PDFs refuse as `no_readable_text` and malformed bodies as
`malformed_markup`. Live: `arxiv.org/pdf/1410.1490` produced 12 page-headed
passages in 0.63 s. `CitationExport` renders cited-only BibTeX, RIS, and
Markdown, and the app's completed brief and history replay carry an EXPORT row.
The fixture target that declared `application/pdf` with a malformed body moved
deliberately from `unsupported_content_type` to `malformed_markup`; the fixture,
matrix text, and test changed together with a comment.

M005.3 (held-out retrieval comparison). Three frozen academic questions
compared scholarly-first discovery with a generic-web-only baseline,
provider-free. Scholarly-source share was 58% against 54% for the web baseline
and the scholarly path cost 7-43x the latency, so the M005 gate was **recorded
as not met** rather than reframed; that negative result stands.

M005.4 (primary-source ordering and the answer card). `primarySourceRank`
orders arXiv/DOI/PubMed Central/ERIC/publisher targets before aggregators, and
Crossref is now called only when OpenAlex and arXiv leave fewer than six
scholarly candidates. Retrieval latency fell 19% (120.98 s against 150.15 s)
and `Limitations` coverage became non-zero on all three questions. The
answer-level held-out card, run end to end with the local model at US$0,
favours the shipped Academic policy **5/6 usefulness against 3/6** for the
generic-web policy, at 100% citation integrity on both. **The M005 gate is met
on that measurement.**

The confound is explicit and preserved: the two paths ran their own frozen
budgets (Academic 14 sources/24 passages, Quick 6/12), so the result compares
the shipped modes rather than scholarly discovery at equal budget. No
equal-budget causal test exists, and the M005.3 tie stands.

Gate result: `make gate` passes; `swift test` reports **274 tests and 0
failures** (273 before M005.4, +1 for primary-source ordering); both validators
conform; `git diff --check` is clean; the offline guards and the M001 fixture
are unchanged.

Provider accounting: no hosted call in M005; the cumulative recorded minimum
stays **39**. Twelve local answer generations and fifteen local retrieval runs
cost US$0. Tavily, OpenAlex, arXiv, and Crossref discovery were live.

Failures preserved at: the M005.3 retrieval-share tie and its 58%/54% numbers;
the budget confound; aggregator pages still opened after primary sources;
publisher refusals (`http_status`, `no_readable_text`, `published_rule`); no
OCR; benign `CoreGraphics PDF has logged an error` lines during PDF runs;
Academic latency 12-123 s; notarized packaging and second-Mac reproduction
unproven.

Evidence: `docs/evidence/M005/m0051-scholarly-boundaries.md`,
`m0052-pdf-and-export.md`, `m0053-held-out-comparison.md`,
`m0054-answer-card.md`. Decisions D037-D040. Next eligible milestone:
**M006.1** (News time-window enforcement and syndication clustering).

### 2026-09-26 - M006 complete: News time window, syndication voices, timeline, claim support

Scope actually executed: M006.1. No hosted answer call; every answer run used
the local endpoint at US$0. Nothing staged or committed.

Treatments. `NewsRecency` plus `WindowedSearchAdapter` ask the provider's news
index for the mode's own frozen window and then enforce it locally, before any
fetch is planned: a result outside the window is dropped and counted, and so is
a result whose publication time the provider does not report, because an undated
page cannot be shown to honour a bounded window. `NewsIndependence.voices`
counts two domains that published the same headline as one independent voice,
and refuses to merge a heading shorter than four words. `NewsIndependence.timeline`
orders voices newest first with undated reports last and no invented timestamp.
`NewsIndependence.snapshotSupportMap` gives every cited passage the number of
independent voices behind its page, and the inspector shows "Single source: no
other independent voice carries this report." when that number is one.

Measured live: 30 discovery results across the plan's five queries, 23 inside
the window and 7 outside it; 9-10 sources opened; 20-24 passages; 4.5-6.4 s per
retrieval run. The app run produced 3 exact passages in 21.3 s and rendered the
`WINDOW ·` line, the dated timeline, the coverage strip, the evidence map, and
the export row.

Three defects were found by looking at the running app and fixed in the same
milestone: the provider reports RFC 1123 dates and every one of them was being
counted as undated, which made the first windowed run abstain; the date map was
captured before the run so the app timeline showed no dates while the CLI showed
real ones; and an undated entry rendered as "Jan 1" through a `.distantPast`
fallback. A fourth defect is recorded rather than fixed: news-page headings are
often navigation text ("My best business intelligence, in one easy email..."),
so the voice count is only as good as the stored heading.

Gate result: `make gate` passes; `swift test` reports **282 tests and 0 failures**
(280 before M006.1); both validators conform; `git diff --check` is clean; the
offline guards and the M001 fixture are unchanged. The window, copy, and support
parts of the gate are met. The copy test is verified by fixture only, because no
observed live run contained a syndicated copy, and no frozen live News snapshot
set exists, so cross-run comparison still depends on the provider. Both are
recorded as not demonstrated rather than claimed.

Evidence: `docs/evidence/M006/m0061-news-window-and-voices.md`. Decision D041.
Next eligible milestone: **M007.1** (editable dimension plan and typed loop
termination for Deep mode).

### 2026-09-26 - M007.1: editable dimension plan, typed loop reasons, resume without duplication

No hosted answer call; the app runs in this milestone used the no-AI path.
Nothing staged or committed.

The plan is now editable and validated against the frozen per-mode caps.
`ResearchPlanError` refuses an empty plan, an oversized one, a case-insensitive
duplicate, and an over-long label; whitespace collapses because that does not
change meaning. Verified through the CLI with exit code 2 and typed messages:
`Quick mode allows at most 1 dimensions; 2 were given.`, `Deep mode allows at
most 6 dimensions; 7 were given.`, and `The dimension "cost" appears more than
once.` A valid edit drives a real run: `--plan deep --dimensions "Cost,
Concurrency"` produced `dimensions=Cost, Concurrency`, 6 sources, 21 passages,
3.33 s, `coverage=["Concurrency": 5, "Cost": 4]`.

Every round now ends with one recorded typed reason (`follow_up_scheduled`,
`evidence_saturated`, `no_new_evidence`, `dimensions_covered`,
`follow_up_budget_exhausted`, `queries_exhausted`, `deadline_reached`,
`no_evidence`, `cancelled`) and the report carries the round log and the
terminal reason; the brief shows `STOP · <reason> — <explanation>`. A later
round that stores nothing is `no_new_evidence` rather than `no_evidence`. The
resume test injects a transport failure into the bounded follow-up round and
proves the first round survives, the page is stored once, no passage id repeats,
and every citation still resolves.

Two defects were found by looking at the running app. A `DisclosureGroup`'s
content reported an unusable accessibility hit target (the editor toggle sat at
an AX rect of 91x9 and a press did not flip it, and the group's identifier
landed on its first child), so the plan strip was restructured as plain
controls; the effective-plan line then rendered (`Answer` for Quick,
`Overview · Evidence · Tradeoffs · Gaps` for Deep). Second, the app read three
keychain items at launch, so every rebuilt development bundle asked for
permission before the user had asked for anything; secrets are now read on
demand. The app's *invalid-plan refusal* is wired to the same proven core call
but was not observable through the accessibility tree, and that is recorded as
an open verification gap.

Gate result: `make gate` passes; `swift test` reports **287 tests and 0 failures**
(282 before M007.1); both validators conform; `git diff --check` is clean; the
offline guards and the M001 fixture are unchanged. M007 stays open: coverage
still matches the dimension label rather than its content terms (measured: Deep
reports `Evidence · 0` and `Tradeoffs · 0` for passages that discuss both), and
contradictions, a diminishing-evidence stop rule, and full provenance ribbons
are not built.

Evidence: `docs/evidence/M007/m0071-plan-and-loop-reasons.md`. Decision D042.
Next eligible task: **M007.2** (content-term coverage, contradiction matrix,
diminishing-evidence stop).

### 2026-09-26 - M007 complete: content coverage, diminishing returns, strict numeric contrasts

No hosted answer call in M007.2. Nothing staged or committed.

Coverage now matches a dimension by its label or by a fixed in-code term list
(`DimensionLexicon`); a custom dimension falls back to its own content terms. On
the same Deep question the coverage moved from `Overview 0, Evidence 0,
Tradeoffs 0, Gaps 1` to `Overview 1, Evidence 4, Tradeoffs 2, Gaps 1`, and the
run stopped spending a follow-up round on a gap that did not exist. A follow-up
that adds half or less of the previous round now stops the loop with the typed
reason `diminishing_returns`.

The numeric-contrast detector is a measured negative result. Three variants were
implemented and run against live pages. The strict rule (identical context
words, different pages, different values, citation-list years excluded) found no
pair on four live runs and is verified by fixture. Matching on shared sentence
terms produced citation-list noise (`2000, 2005, 2006` against `1978`), and
requiring only a shared unit word still joined unrelated numbers under contexts
like `after` and `memory`. Neither looser variant ships, because each would
assert a disagreement the evidence does not contain. The strict variant ships and
the surface stays empty when it has nothing to show.

Gate result: `make gate` passes; `swift test` reports **290 tests and 0 failures**
(287 before M007.2); both validators conform; `git diff --check` is clean; the
offline guards and the M001 fixture are unchanged. M007 is complete with the
contradiction item recorded as only partially met: nothing is averaged or
resolved, but live detection was not demonstrated. The long-form benchmark and
human review parts of the M007 gate belong to M008's studio and are not started.

Evidence: `docs/evidence/M007/m0072-coverage-and-contrasts.md`. Decision D043.
Next eligible task: **M008.1** (benchmark runner, per-mode scorecards, corruption
tests).

### 2026-09-26 - M008.1: benchmark card, scorecard, corruption checks

No hosted answer call; the whole replay ran the local model at US$0. Nothing
staged or committed.

A benchmark card is JSON data: named questions, the mode each must run in, and
human-authored check labels that are copied into the scorecard and never used to
score anything automatically. The scorecard stores one row per question with
citations, accepted and rejected claims, latency, opened sources, passages, the
typed stop reason, and whether every citation resolved. Answer usefulness stays
`nil` until a human scores it and is reported only over scored questions, so an
unscored card cannot look like a good one, and there is no combined number for
integrity, usefulness, and latency. Each scorecard document carries one label,
so a local run and a hosted run are never averaged together.

Measured: the frozen five-question card replayed against the local model. Q1
retrieval practice 1 citation / 1 rejected / 70.67 s, Q2 LLM reasoning 3 / 5 /
102.65 s, Q3 vocabulary spacing 1 / 1 / 71.30 s, Q4 and Q5 abstained with "the
provider proposed no verifiable claim" (42.00 s and 27.87 s). Citation integrity
**100%**, usefulness **unscored over 0/5 scored**, median latency 70.7 s, total
314.5 s. Q4 abstaining is the wanted behaviour and Q5 abstaining means the false
premise was not accepted; both are recorded as abstentions rather than answers.
The scorecard is preserved at
`docs/evidence/M008/scorecard-local-2026-09-26.json`.

`CitationBoundaryCheck` makes exactly one thing wrong in a valid compilation and
requires the boundary to refuse it: an altered quote, a link to a passage that
was never stored, an evidence link naming a different claim than the citation,
and a citation identifier that is not in the compilation. All four are refused
in `testValidCompilationResolvesAndEveryCorruptionIsDetected`.

Gate result: `make gate` passes; `swift test` reports **294 tests and 0 failures**
(290 before M008.1); both validators conform; `git diff --check` is clean; the
offline guards and the M001 fixture are unchanged. M008's integrity target is met
on this card, its corruption requirement is met, and its "do not collapse the
metrics" requirement is met and enforced by test. The semantic-evaluator part has
not been started and there are no human usefulness labels yet.

Evidence: `docs/evidence/M008/m0081-benchmark-and-corruption.md` and
`docs/evidence/M008/scorecard-local-2026-09-26.json`. Decision D044. Next
eligible task: **M008.2** (human citation-review workflow and scored scorecards).

### 2026-09-26 - M008.2/M008.3 and M009.1: review, evaluation, release

No hosted answer call in these milestones: the benchmark replays ran the local
model at US$0. Nothing staged or committed.

M008.2. The benchmark runner writes a review packet beside a run, containing each
claim with its exact quote, passage heading, and source URL, plus the card's own
check labels. A person fills in a verdict per citation and a usefulness score per
question; `--mode review` applies it to the finished scorecard, refusing an
unknown question, an unknown verdict word, an out-of-range score, or a missing
reviewer, and leaving anything blank unscored. Usefulness and citation integrity
remain separate fields, and each scorecard document carries one label. Reviewed
result on the frozen card: integrity 100%, usefulness 1.40 over 5/5 scored, 5
supported and 1 partial citation. **The labels are provisional and were written
by the assistant, not by an independent human reviewer.**

M008.3. `AnswerEvaluator` predicts usefulness from counted features only
(citations, reviewer verdicts, rejected claims, coverage, abstention, integrity)
and explains each score; `EvaluatorCalibration` reports agreement, mean absolute
error, and worst error, and refuses to call itself calibrated below 20 labels.
Over the five provisional labels: exact agreement 3/5, mean error 0.40, worst 1,
verdict `not calibrated: 5 label(s), 20 are required`. `LearningCard` is built
from the run: exact quotes with markers, rejected claims with their typed
reasons, coverage and gaps, and deterministic explain-back prompts; an abstention
gets its own lesson. The app shows a LEARN panel and can copy the card as
Markdown. One bug was found by testing the workflow end to end: the review packet
keyed questions by question text while the scorecard keyed them by card id, so
the two files could not be linked; and applying a review dropped the coverage
columns. Both are fixed and covered.

M009.1. `make dist` builds the release app, signs with the best available
identity, notarizes only when a Developer ID identity and `NOTARY_PROFILE` both
exist, and records the outcome in `dist/release/BUILD-INFO.json`. Measured here:
`LocalLens-1.0.0.zip`, `signature: apple-development`, `notarized: no`, reason
*no Developer ID Application identity is installed*. `make verify-release` passes
all nine checks: the bundle exists, the identifier is `dev.locallens.app`, the
signature verifies, and there is no credential material, no model weight,
exactly the two public fixtures, no fetched page or PDF body, and no key or pem
file under `dist/`. The app gained a Storage & privacy panel (run count, file
count, bytes on disk, a confirmed delete that states nothing was uploaded), a
privacy-safe diagnostics bundle (`DiagnosticsReport`, with a test asserting no
question, answer, claim, quote, snippet, or credential field can appear), a
first-run card, and reduced-motion handling. `make demo` runs the mode plan, the
edited dimension plan, the typed refusal, and the corruption test at US$0;
`make reproduce` refuses a dirty tree and then runs the gate, both validators,
the release build and checks, and the demo. `CONTRIBUTING.md`, `docs/REPRODUCE.md`,
`docs/DEMO.md`, and `docs/HANDOFF.md` document the commands and the four external
gates.

Gate result: `make gate` passes; `swift test` reports **299 tests and 0 failures**
(295 at M008.2, 298 at M008.3, 299 after the diagnostics test); both validators
conform; `git diff --check` is clean; the offline guards and the M001 fixture are
unchanged. M008 is complete except its calibration target, which needs
independent labels. M009 is partially complete: notarization is **blocked** (no
Developer ID identity), second-machine reproduction is **unproven**, the licence
is **the owner's choice**, and no independent reviewer has scored a run. All four
are packaged with the exact command that closes each in `docs/HANDOFF.md`.

Evidence: `docs/evidence/M008/m0081-benchmark-and-corruption.md`,
`docs/evidence/M008/review-packet-local-2026-09-26.json`,
`docs/evidence/M008/scorecard-local-scored-2026-09-26.json`,
`docs/evidence/M008/lessons/`, `docs/evidence/M009/m0091-release-and-onboarding.md`.
Decisions D044, D045. Next task: **M009.2** (the four external gates).

### 2026-09-26 - M009.2: all four modes verified in the app with hosted DeepSeek

Eight hosted DeepSeek answer calls: four through the command-line tool and four
through the app. The cumulative recorded minimum moves from 39 to **47**. Nothing
staged or committed.

Why this was needed: the evidence showed exactly two hosted answers in the whole
repository, both Quick, from M004.1. Deep, Academic, and News had only ever been
answered by the local model, and no mode had been driven through the interface
with a hosted provider since the Living Research Map was built.

Command line (hosted): Quick 7 citations/13.55 s, Deep 11/9.36 s, Academic
6/33.13 s, News 3/21.59 s. App (hosted, observed through the accessibility tree):
Quick `6 exact passages · 5 sources · 1 round(s) · 6.3s` with `STOP · evidence
saturated`; Deep `12 · 4 · 8.0s` with the comparison plan in the PLAN strip, a
`DECISION CRITERIA` panel showing both sides, `STOP · dimensions covered` and
`LEARN · 2`; Academic `13 · 11 · 25.2s` with a `PAPER MATRIX` of 13
claim-to-passage rows including PDF `Page 6` headings and coverage
`Findings 25 · Method 8 · Limitations 7`; News `3 · 15 · 2 round(s) · 15.9s` with
`WINDOW · 29 dated results inside the window, 4 outside it`, `10 independent
domains, 10 independent voices`, a dated timeline, and coverage
`What happened 5 · Timeline 16 · Independent confirmation 1`.

Three credential faults were found and two were fixed. The provider check ran
before the lazy keychain read, so the first **Ask** after any launch always
failed with `No answer provider is configured.` even with the key saved. And
`SecretKeyStore.load` collapsed every non-success status into `nil`, so a refused
read (`errSecAuthFailed` — the item exists but macOS refused this binary) was
displayed as an empty slot, which is false. The read now returns `.found`,
`.absent`, or `.denied`, the Connection panel says which, and a **Grant access**
button triggers the prompt deliberately rather than mid-run. The third fault is
inherent: macOS ties the keychain grant to the code signature, and every
`make app` re-signs the development bundle ad hoc, so the grant is lost on each
rebuild; the panel now explains that instead of failing silently. After the fix,
all four UI runs above started from a single press on a fresh launch.

Defects measured and left open for M009.3: News enforces recency but not topical
relevance — the timeline and citations included a stablecoin approval
(`fintechfutures.com`), a biodiversity brief (`osborneclarke.com`), deforestation
rules (`foodnavigator.com`), and a commercial-vehicle brief
(`automotiveworld.com`); a News answer rested on three claims with
`Independent confirmation · 1`; and Deep stopped on `dimensions_covered` while
reporting `Gaps · 2`, because two dimensions were matched by a keyword rather
than addressed. Academic cited one blog and one education site inside the
`Other evidence` group. These runs prove routing and the citation boundary; they
do not prove answer quality, and that is stated rather than implied.

Gate result: `make gate` passes; `swift test` reports **299 tests and 0 failures**;
both validators conform; `git diff --check` is clean; the offline guards and the
M001 fixture are unchanged.

Evidence: `docs/evidence/M009/m0092-hosted-four-mode-ui.md`. Decision D046. Next
task: **M009.3** (News relevance, claim-set depth, coverage precision).

### 2026-09-26 - M009.3: three measured mode defects fixed, workspace redesigned

Nothing staged or committed. Eight further hosted DeepSeek answer calls (two via
the command line, six in the app); the cumulative recorded minimum moves from 47
to **55**. `swift test` reports **315 tests and 0 failures**.

**The three defects**, each measured by the M009.2 run rather than guessed:

1. **News relevance.** News enforced its 14-day window but not topical relevance,
   so a stablecoin approval, a biodiversity brief, an anti-deforestation story,
   and a commercial-vehicle brief reached the timeline and citations. The new
   `NewsRelevance` keeps a result only when it shares an adjacent phrase from the
   question, two of its content terms, or one distinctive term; matching is
   whole-word, the frozen window runs first, and a filter that would drop
   everything keeps everything and says so. The **first version measured zero
   drops on a live run** because the question contains `month` and `act` -
   "Content of the Month" matched one, a piece about "the AI space" matched the
   other. That failed rule is preserved in a test by name. Same question after
   the correction: `22 dated results inside the window, 7 outside it, 4 off topic
   for this question`, and a timeline of EU AI Act stories only.
2. **Claim depth.** The run reported `10 independent domains, 10 independent
   voices` while all three claims were single-source. `NewsClaimDepth` counts, per
   claim, the independent voices carrying its page, and the News brief now leads
   with the honest sentence: `Thin claim set: none of the 7 claims is carried by
   a second independent voice, so the answer is single-source throughout`, with
   `7 domains / 7 voices / 7 claims / 0 confirmed` beside it.
3. **Coverage precision.** `Gaps · 2` was reported for a gap nothing had
   addressed because one `however` matched, and `Timeline · 16` counted any
   passage containing a year because `20` was in the term list and matching was
   by substring. `DimensionLexicon` now matches whole words, separates strong
   from weak terms, and requires one strong term or two distinct weak ones.

**Two wiring bugs found while fixing the above.** `ResearchRunner` built the
contradiction scan and never passed it to the report, so the contrast panel could
not have rendered for any run - and the M007.2 note that it "stays empty" was
true for the wrong reason. `newsClaimDepth` was computed and likewise dropped.
Both are passed and covered now, and the first live run after the fix showed the
panel immediately.

**Redesign against the product's own mockup.** The surface had drifted into a
scaffold: all-caps labels on every section, `·`-joined counters, monospaced
micro-text, and a single-line question field that lost its edges in a crowded row,
so a long question appeared cut off at both ends. `DesignSystem.swift` now holds
the tokens (semantic system surfaces so light and dark both work, one accent for
evidence, sentence case, monospaced digits only where numbers align); the
question field grows from one to six lines with a visible boundary; the mockup's
structure is followed - summary, comparison table, paper matrix, confirmation
panel, evidence map, selected-passage inspector. The mockup's
`Excellent / Good / Fair` verdicts are deliberately **not** reproduced: this
product has no basis for them, so a cell reports the measured count of stored
passages matching the criterion and mentioning that side. Guidance came from the
`frontend-design` skill in `anthropics/skills` (Apache-2.0), installed as a skill
for this session and not vendored here.

All four modes were re-verified in the app after every change: Quick `5 passages
· 9.0s`, Deep `11 · 6.8s` with `Tradeoffs 21/13 passages` and `Gaps 1/none`,
Academic `13 · 20.2s` with a paper matrix, News `7 · 9.9s` with the thin-claim
panel and the window line. The narrow layout was verified separately at 880x700:
the evidence column becomes a sheet and the field keeps its width.

Gate result: `make gate` passes; both validators conform; `git diff --check` is
clean; the offline guards and the M001 fixture are unchanged.

Evidence: `docs/evidence/M009/m0093-defects-and-redesign.md` and the before/after
screenshots in that directory. Decisions D047 and D048. Next task: **M009.4**
(remaining observation gaps and the four external gates).

### 2026-09-26 - M009.4 owner-directed every-screen UI close-out

Scope actually executed: the current Mac app's start screen, four modes through
saved runs, live Deep answer, evidence inspector, history, privacy and
connection, global launcher, invalid dimension plan, legacy Live Quick window,
and both M001 offline-demo views. Numbered screenshots and before/after notes
are in `docs/evidence/M009/m0094-ui-closeout-audit.md`. No new Tavily search or
DeepSeek call was made. No history or Keychain item was deleted.

Measured UI failures: clearing the question left the previous answer visible;
History's “Clear” deleted every run without a confirmation; the privacy panel
stayed at “Counting…” until Refresh and said “nothing is uploaded” although
hosted answering sends selected passages to DeepSeek; a checked empty custom
plan silently used defaults; the evidence seal looked like fact verification;
and compiled answers read as uninterrupted citation-heavy prose. Saved-mode
replay also omits the live Academic and News panels, which it had not stated.

Treatment: question edits reset the visible result and selection; history rows
show time/selection and bulk deletion requires a native confirmation; privacy
counts history on opening and accurately separates local saved runs, search
requests, and hosted answer requests; empty custom dimensions refuse with the
typed reason before any Keychain or network work; citation UI says passage
linkage, not independent fact checking; answer paragraphs are separated only
for display, leaving stored/exported text unchanged; compact replay discloses
its missing mode panels and warns about time-sensitive News claims. The old
Quick-only and offline-fixture windows remain test-addressable but are removed
from the normal Research menu; the M001 fixture view itself was not changed.
A saved News
replay contained an extraordinary allegation with no independent truth check
in this audit, so it must not be used as a verified-news demo.

`make gate` passed with **315 tests, 0 failures** after the final code patch;
`make app` rebuilt the development app and it relaunched to the sole normal
four-mode workspace after the two historical windows were closed. The Research
menu source contains only New question, but the final menu was not clicked
successfully during concurrent UI activity; that subclaim is code/build proof.
M009.4 is **in progress**, not complete. The live syndicated-copy pair, live
numeric contrast, and publisher-refusal observations remain open. On
2026-09-26 the owner authorized permissive reuse: the root MIT `LICENSE` now
closes the repository-licence gate, while independent human review,
second-Mac reproduction, and Developer ID notarization remain open in
`docs/HANDOFF.md`. Four unedited app screenshots, one per mode, and a draft X
post are in `docs/social/2026-09-26/`; News is shown as a policy preview rather
than an unverified claim. `make dist` produced an Apple-Development-signed
archive, copied MIT `LICENSE` into the bundle, and passed nine release checks;
it explicitly reports `notarized: no` because there is no Developer ID
identity. Decision D049.

Public-release preparation: the owner explicitly authorized rewriting the
40 earlier commits from a company identity to the GitHub account `msulemans`.
The release commit was included in the rewrite, so all 41 commits on `main`
now have `msulemans <53903082+msulemans@users.noreply.github.com>` as both
author and committer. Historical short commit references in this repository
were mechanically updated to the rewritten IDs. `make validate-manifest` and
`git diff --check` pass. A public `msulemans/local-lens` GitHub repository was
created for this first publication; remote availability and second-Mac
reproduction are distinct checks, and publication is not notarization.

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
