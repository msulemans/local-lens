# Local Lens - Canonical State

Last updated: 2026-09-23 (Australia/Sydney)

Status: **Milestone 001 is complete (gate audit: `docs/evidence/M001/`).
Milestone 002 (safe live acquisition) is complete: every gate bullet has
recorded evidence, with the live-corpus portion of bullet (a) recorded as an
explicit blocker rather than claimed. Milestone 003 (first useful Quick
release) is the sole active milestone; its first task, M003.1, delivered the
lexical retrieval boundary (FTS5/BM25 over stored passages), M003.2 delivered
retrieval-backed citation compilation, M003.3 delivered the deterministic Quick
pipeline, and M003.4 is the next task defined in `project.json`. M002.1
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
can reach the network. One hundred and eighty-eight deterministic tests pass and
clean checkouts pass `make gate`.**

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
  `make validate-manifest` pass. Commit `6d6e4a9`.
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
  `make validate-manifest` pass. Commit `080db9d`.
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

Gate result: `make gate` passed at commit `19a9d1f` with 81 tests and 0
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

Gate result: `make gate` passed at commit `dfff4a8` with 96 tests and 0 failures
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

Commit or working-tree state: implementation committed as `8879b63` (the
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

Commit or working-tree state: implementation committed as `8d0e9b7`; this
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
commit `0bc72fe`; this entry is the second commit of the pair.

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

Gate result: `make gate` passed at commit `0bc72fe` with 171 tests and 0
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

Commit or working-tree state: implementation commit `9ee4e93`; this entry is the
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

Gate result: `make gate` passed at commit `9ee4e93` with 179 tests and 0 failures
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

Commit or working-tree state: implementation commit `d16132b`; this entry is the
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

Gate result: `make gate` passed at commit `d16132b` with 188 tests and 0
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
