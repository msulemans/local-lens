# Decision Log

Decisions are append-only. Superseding a decision adds a new entry that names
the earlier decision and evidence; it does not rewrite history.

## D001 - Native macOS product

Date: 2026-09-22

Decision: Build the primary product with SwiftUI and Swift Concurrency.

Why: the intended product is a daily Mac utility with native windowing,
keyboard access, cancellation, Keychain, Spotlight, App Intents, packaging,
and accessibility. A browser UI remains useful for references and tests but is
not the product shell.

Trade-off: Swift narrows the initial platform and requires implementing or
bridging some mature Python extraction/research components.

Review trigger: a concrete core capability cannot be delivered or distributed
reasonably through the native boundary.

## D002 - Living Research Map visual direction

Date: 2026-09-22

Decision: Use the third generated concept as the canonical visual target.

Why: it makes evidence relationships, comparison criteria, uncertainty, and
learning visible without turning the product into a generic chat interface.

Artifact: `docs/design/local-lens-living-research-map.png`.

Constraint: provenance ribbons remain sparse and functional. Normal Quick
answers should not be forced into a complex map.

## D003 - Quick mode before breadth

Date: 2026-09-22

Decision: The first useful release is Quick mode. Academic, News, and Deep are
subsequent milestones.

Why: daily utility, latency, installation, and citation reliability need proof
before adding research breadth.

## D004 - Exact-passage citations

Date: 2026-09-22

Decision: A citation must resolve to a passage in an immutable snapshot.

Why: URL-only citations can be irrelevant, changed, ambiguous, or invented and
cannot support mechanical integrity checks.

## D005 - FTS5/BM25 baseline

Date: 2026-09-22

Decision: Begin retrieval with SQLite FTS5/BM25 plus deterministic source and
diversity features.

Why: it is local, inspectable, distributable, and establishes whether an
embedding or reranking treatment is needed.

Review trigger: labelled passage-recall errors meet M004 entry criteria.

## D006 - Hypothesis-gated model work

Date: 2026-09-22

Decision: No broad model bake-off. Test a candidate only against a measured
failure under the experiment record in `docs/MODEL_POLICY.md`.

Why: the project must avoid weeks of infrastructure and benchmark activity that
does not improve a runnable product.

## D007 - No Docker for normal users

Date: 2026-09-22

Decision: Docker may support development or optional self-hosted services but
cannot be required by the signed application path.

Why: installation and networking complexity are major barriers in comparable
open-source research products.

## D008 - Safe adaptive UI schema

Date: 2026-09-22

Decision: The model may select from trusted SwiftUI answer-block schemas but
cannot generate executable UI code or arbitrary markup.

Why: adaptive comparisons and timelines add product value while unrestricted
generative UI would weaken safety, accessibility, stability, and testing.

## D009 - Licence unresolved until public-release planning

Date: 2026-09-22

Decision: Do not invent a licence during M000. Resolve repository and model
licensing before M009 publication.

Why: the intended distribution and dependency/model licences must be reviewed
together.

## D010 - Reuse the sibling research core

Date: 2026-09-22

Decision: Extract the proven seams from `../deep-research-agent` behind a
versioned local protocol instead of rewriting search, safe acquisition,
extraction, retrieval, citation compilation, and evaluation in Swift.

Why: direct inspection found the needed modules and 184 unit tests. Reuse puts
effort into the native product and Evidence UI while retaining known behavior.

Constraint: the sibling has no observed `LICENSE` file. Code copying is blocked
until ownership, licensing, and provenance are explicitly resolved.

## D011 - Sibling transfer gate

Date: 2026-09-22

Decision: Sibling code transfer stays blocked until `../deep-research-agent`
carries a licence file that permits redistribution. The owner applies the
licence; M001 clean-room work (schemas, fakes, fixtures, tests) proceeds
without it.

Why: audit of revision `1b1a698` found 89 commits by the sole owner and no
`LICENSE` file. Ownership is attributable, but redistribution permission is
not yet granted in writing.

Evidence: `docs/REUSE_PROVENANCE.md` records the audit, the decision, and the
checks required before the first extraction commit.

Review trigger: a sibling `LICENSE` file appears, or the sibling revision
changes.

## D012 - Frozen ResearchCore boundary and protocol v1

Date: 2026-09-22

Decision: Freeze the extraction boundary, exclusions, and the versioned
protocol surface `v1` for commands, events, entities, and errors. Retain the
existing Swift WIP; its audit and the sibling test mapping are recorded in
`docs/RESEARCH_CORE_BOUNDARY.md`.

Why: M001.1 requires an explicit reuse boundary and versioned schemas before
extraction or implementation can be reviewed. Frozen wire enums must match the
Swift core and are enforced by `scripts/validate_protocol_schemas.py`.

Review trigger: any boundary change; it requires a new decision entry and a
protocol version bump.

## D013 - Local IPC transport

Date: 2026-09-22

Decision: The first local transport is newline-delimited JSON over stdio to a
single child process supervised by the app, carrying only the frozen protocol
v1 envelopes (commands, events, errors).

Why: parent-child stdio needs no network ports, discovery, or shared
filesystem service, and the operating system already authenticates process
parentage. The wire schemas stay unchanged if the transport is later replaced
by a Unix domain socket or XPC.

Alternatives considered: Unix domain socket with a per-launch token (better
for a separately installed service; more setup); HTTP on loopback (rejected:
unnecessary network surface and port management).

Review trigger: packaging constraints, or a second local consumer needs
direct access to the research core.

## D014 - UI verification approach

Date: 2026-09-22

Decision: Verify UI behavior with three layers now: (1) view-model and core
tests; (2) scripted window capture with `screencapture` at defined
checkpoints, stored under `docs/evidence/<milestone>/`; and (3) a manual
interaction list for states automation cannot reach. XCUITest is deferred to
the packaged application (M003/M009).

Why: the SwiftPM-only workflow has no UI test target, and window capture plus
view-model tests give repeatable visual evidence today without introducing an
Xcode project early. `LOCAL_LENS_START_VIEW=map` makes either main view state
capturable deterministically.

Review trigger: packaging work begins, or a UI regression escapes capture.

## D015 - M001 declaration and sibling-extraction disposition

Date: 2026-09-22

Decision: Declare M001 complete against its eight recorded gate items, all
passing (`docs/evidence/M001/gate-audit.md`). The sibling `ResearchCore`
extraction item stays BLOCKED by the licence gate (D011) and is tracked as the
licence-gated reuse task R1; it is not a product-facing requirement of the
deterministic slice, which is clean-room Swift and fully tested.

Why: every gate item has recorded evidence on a clean checkout; the licence
block is an owner action that implementation work cannot complete, and the
plan explicitly anticipates porting instead of extraction when direct reuse is
not possible.

Carry-over items: R1 sibling reuse (blocked on licence); full Living Research
Map design (M003, see `docs/design/CONFORMANCE.md`); UI automation (packaged
app).

This supersedes D009 only for the timing of sibling-code licensing: that issue
must be resolved in M001. Selection of this repository's final public licence
may still occur during public-release planning.

Review trigger: the bundled sidecar cannot meet the frozen packaging,
reliability, or performance gates.

## D011 - Evidence-Native Generative Search

Date: 2026-09-22

Decision: The differentiating product contract is a typed evidence graph that
renders a safe adaptive Evidence UI. Every factual field names claims and exact
saved passages.

Why: this makes comparisons, timelines, papers, conflicts, and gaps more useful
than chat-only prose without letting generated UI bypass citation validation.

## D012 - Protocol alignment without premature dependency

Date: 2026-09-22

Decision: Shape internal run events after AG-UI lifecycle/activity patterns and
Evidence UI after A2UI's declarative surface/data split. Do not depend on either
runtime in the first release.

Why: modern protocol alignment preserves an interoperability path, while a
smaller native schema is safer and easier to test.

## D013 - Recent retrieval work is conditional treatment

Date: 2026-09-22

Decision: Contextual passage embeddings are the first eligible challenger for
a demonstrated document-context recall failure. Listwise reranking is eligible
only for a demonstrated ordering failure after recall is adequate.

Why: recent results are promising, but adopting them before diagnosis would
add model weight and complexity without proving product value.

## D014 - Reuse contracts, replace the execution schedule

Date: 2026-09-22

Decision: Preserve the sibling's safety, evidence, citation, and evaluator
contracts while replacing its sequential search, fetch, per-passage inference,
and uncapped assessment schedule with a mode-specific fast path.

Why: the sibling recorded a roughly 20-minute live run and identified thousands
of passages, sequential model calls, and an unenforced wall-clock limit. Quick
mode needs early narrowing, bounded cross-host concurrency, batched inference,
progressive evidence, cache reuse, and an enforced deadline.

Constraint: performance changes cannot weaken citation integrity, acquisition
safety, or typed stop reasons.

## D016 - Search adapter boundary and hit identity

Date: 2026-09-22

Decision: Live search enters through one narrow boundary. A `SearchAdapter`
exchanges a query for a typed `SearchOutcome` (`.hits` or `.noResults`), and
every adapter reaches the network only through an injected `SearchTransport`.
The first implementation is a SearXNG JSON adapter; the production transport is
a thin `URLSession` edge with no retry, redirect, or payload policy, because
those decisions belong to the adapter and to the acquisition policy that M002
adds next.

Why: metasearch providers are unreliable and replaceable, so provider quirks
must be decodable and testable without a socket. Injecting the transport lets
the frozen fixture prove decoding, ordering, identity, and every failure path
deterministically, and keeps the "no test performs network access" rule
enforceable by inspection rather than by convention.

Consequences:

- `SearchError` is the typed failure family: `invalidEndpoint`, `emptyQuery`,
  `transportFailure`, `httpStatus`, and `malformedPayload`. An empty but
  successful response is the typed empty outcome `.noResults`, never a silent
  success, and cancellation stays `CancellationError` for the state machine.
- Hit identity is derived from the query, the fragment-free URL, and the
  provider rank, so one search observation is reproducible across runs and
  machines. The M001 deterministic fixture slice keeps its own two-part hit
  identity so M001 evidence stays byte-identical; unifying the two schemes is a
  deferred cleanup, not a silent edit.
- SearXNG payloads are third-party metadata, not our frozen wire schema:
  unread provider fields are ignored, consumed fields are validated strictly,
  and only the first `maxResults` entries are parsed so trailing junk cannot
  fail a usable search.

## D017 - Policy-checked acquisition with a frozen refusal matrix

Date: 2026-09-22

Decision: Live retrieval goes through `SafeAcquisition.fetch`, which approves a
URL with `AcquisitionPolicy.validate` before any request and re-approves every
redirect hop before it is requested. Redirects are followed by our code, not by
the HTTP client, so no hop can bypass the check. Name resolution is an injected
`HostResolver`; the production `SystemHostResolver` is the only implementation
that performs a real lookup and no test uses it.

Why: the M002.1 search boundary proves we can talk to a provider, but nothing
yet stopped a result URL, a redirect, or a rebound DNS answer from pointing the
app at the user's own machine, a private network, or a cloud metadata service.
A search tool that can be steered onto `169.254.169.254` is a credential
exfiltration tool, so this had to land before any live fetch.

Consequences:

- `AcquisitionPolicy.validate` is fail-closed and address-based, not
  name-based: it refuses reserved host suffixes by name, then resolves and
  requires *every* answer to be publicly routable. Partially private is
  private, which is the DNS-rebinding case.
- `IPAddress` normalizes the encodings a resolver honours but a naive
  string check does not (`127.1`, `2130706433`, `0x7f.0.0.1`, `0177.0.0.1`)
  and classifies the IPv4 address embedded in IPv4-mapped, NAT64, and 6to4
  IPv6 forms. The narrower rule wins where ranges overlap: the IPv6 metadata
  endpoint is also inside `fc00::/7` and is reported as metadata, not private.
- `AcquisitionError` keeps destination refusal, request-shape refusal,
  resolution failure, and response refusal as distinct cases, each with a
  stable `kind` label, because each becomes a different user-visible stop
  reason. `SafeAcquisition` returns both the requested and the final URL so
  leaving the origin stays visible.
- The refusal matrix is frozen as data in
  `Fixtures/acquisition/safe-fetch-scenarios.json` (43 blocked destinations, 9
  resolution cases, 20 fetch scenarios), so a security rule can be reviewed and
  extended without reading test code. The fixture contains only reserved
  documentation/internal names and reserved address ranges; a guard test
  enforces that.
- Cancellation stays `CancellationError`; a timeout is `AcquisitionError.timeout`
  even when the transport has already collapsed the `URLError` into a string,
  because a timeout must remain distinguishable from a connection failure.
- Robots policy, per-host concurrency, and politeness delay are explicitly NOT
  in this decision; they are the next task in M002 and the acquisition boundary
  is shaped so they can be added as a gate on the same validated URL.

## D018 - Robots is fail-closed, politeness is per host

Date: 2026-09-22

Decision: an origin's robots.txt is read through `SafeAcquisition.fetch`, its
rules are applied by `RobotsPolicy`, and requests to one host are serialized by
a per-host `HostRequestGate` with a minimum spacing measured between request
starts. An unreadable policy refuses the request.

Why: M002.1 could talk to a provider and M002.2 could refuse a private
destination, but nothing yet respected what an origin had published, and
nothing stopped the pipeline from hammering one host. Politeness is part of the
product claim, not an afterthought: this tool is meant to be pointed at the open
web, and being a well-behaved client is a precondition for that.

Consequences:

- The fallback table is explicit and deliberately not "assume allowed when
  unsure": 200 with rules and 200 with an *empty* body are `.rules`; 4xx is
  `.missing` (an absent policy, no restriction); 5xx, an unparseable body, a
  transport failure, a timeout, and a destination refused by
  `AcquisitionPolicy` are all refused. An unreadable policy is not permission.
- An empty published body is a valid policy with no rules, while a non-empty
  body with no directives is `.unparseable`. Those are different facts about the
  origin and are reported differently.
- `RobotsRefusal` separates a rule the origin published (`published_rule`) from
  a refusal we imposed (`fail_closed`), because a user asked to stop by the
  site's own rules is in a different position from a user blocked by our
  caution.
- `RobotsLoader.load` does not take the host gate. Politeness has to wrap the
  robots check and the request that follows it as one unit, and a nested
  acquisition of the same gate would deadlock against the caller that holds it.
- The gate is per normalized host, never global. Politeness must not become a
  global throughput ceiling, and one slow origin must not stall an unrelated
  one.
- Spacing is measured between request *starts*, which is what the origin
  observes, rather than between completions. The gate is released on throw and
  on cancellation so a failing request cannot wedge a host.
- `PolitenessClock` is injected. Production uses `SystemPolitenessClock`; tests
  advance virtual time and record the requested intervals, so no test sleeps and
  no test touches a real clock.
- The cache is keyed by scheme, host, and port and deliberately excludes the
  user agent: the agent selects a group *inside* the file, it does not select
  the file. Entries do not expire in-process; time-based revalidation is a later
  concern and is recorded as unverified rather than implied.
- The decision table is frozen as data in
  `Fixtures/robots/robots-scenarios.json` (8 group-selection cases, 15 path
  decisions, 3 parse failures, 12 fetch scenarios), with a guard test that keeps
  every host name reserved and every address either the documented example.com
  address or a deliberately refused loopback literal.

## D019 - HTML extraction is a typed, content-addressed boundary

Date: 2026-09-23

Status: accepted

Context: acquisition can now approve and fetch an HTML document, but the
pipeline still had nothing it could cite. The extraction step is where a hostile
web actually bites: a page can be empty, served with the wrong declared type,
encoded in something we cannot decode, larger than any ceiling we are willing to
hold, or malformed in a way that silently swallows the rest of the document. If
extraction returns "the text" in those cases, every later citation is built on a
guess. `Sources/LocalLensCore/HTMLExtraction.swift` is therefore a boundary, not
a helper: it either produces text a passage can be built from, or it refuses
with a typed fact.

Decision:

- Extraction is a pure function of the bytes acquisition already approved. It
  takes an `AcquisitionResult` and a policy, and it performs no I/O: no socket,
  no DNS, no file read, no clock. A guard test scans the source for those
  capabilities, so the property cannot regress silently.
- Every refusal is a distinct fact, not a generic failure. The frozen family is
  `unsupported_content_type`, `document_too_large`, `empty_document`,
  `unsupported_charset`, `malformed_markup`, `no_readable_text`,
  `missing_source_identifier`, and `invalid_policy`. A caller can tell an
  origin that published nothing from a document we refused to guess at.
- Refusal order is fixed and observable: source identifier, then media type,
  then size, then character set, then markup, then readability. A PDF over the
  ceiling is still a PDF; an oversized document is refused for its size before
  its encoding is considered.
- Identity is content-derived and reuses the M001 part ordering, so a live
  snapshot and a fixture snapshot describe themselves the same way:
  `StableIdentity.make("snapshot", sourceID, contentHash)` and
  `StableIdentity.make("passage", snapshot.id, String(ordinal), digest(text))`.
  The extractor does not invent a second identity scheme.
- `ExtractionPolicy` follows the same checked/unchecked pattern as
  `AcquisitionPolicy`: a private unchecked initializer for the default and a
  throwing public initializer that rejects a non-positive ceiling or a blank
  extractor version. The extraction ceiling is separate from the acquisition
  ceiling because holding a document to parse it is a different cost from
  streaming it.
- Headings are attribution, not decoration: the heading a reader last saw is
  carried on every block that follows it, and a heading is also emitted as its
  own block so a document that is nothing but headings is still readable. An
  empty heading is not a heading change.
- The header is the transport's statement about the bytes and `<meta>` is the
  document's statement about itself, so the header wins and `<meta>` is believed
  only when the header said nothing. `charset` is matched as a token of its own,
  so `charsetless` cannot decide an encoding. This is a scan, not a parser, and
  is recorded as such.
- Text is normalized once: character references are resolved *before*
  whitespace is collapsed, so `&nbsp;` becomes an ordinary space while
  `&amp;nbsp;` stays the literal text a reader sees. Unknown or malformed
  references are text, not markup failures.

Consequences:

- The scenario table is frozen as data in
  `Fixtures/html/extraction-scenarios.json`: 7 extraction cases and 17 refusals,
  each with a `why`. Every host stays on a non-resolvable `.invalid` name and
  the fixture declares itself synthetic and redistributable, so no captured page
  enters Git.
- A body that cannot be read is refused rather than truncated or lossily
  decoded: a NUL byte, invalid UTF-8, an unclosed comment, an unclosed `<script>`
  or `<title>` that would swallow the document, and a body with no markup at all
  are all `malformed_markup` with a reason that names the specific failure.
- Known losses are recorded as fixture cases rather than folklore: whitespace
  inside `<pre>` is collapsed (`preformatted-whitespace-is-lost`), there is no
  DOM, no attribute or `<base>` handling, and no full HTML5 named-entity table.
- PDF extraction, rendering, and JavaScript execution are explicitly out of
  scope: a PDF is refused as `unsupported_content_type` even though acquisition
  allows the type.
- The first run of the new suite was red with 5 failures and the failures were
  diagnosed rather than accommodated: the `<title>` open tag jumped past the
  title's characters, so no title was ever captured; `mediaType(of:)` dropped an
  empty leading component, so `"; charset=utf-8"` reported the parameter as the
  media type; and the `<meta>` scan matched `charset` inside `charsetless`. All
  three are fixed in the source, not in the assertions.

## D020 - The snapshot store deduplicates content without rewriting identity

Decision: acquisition and extraction produce `ExtractedPage` values; the
`SnapshotStore` actor turns them into evidence records. Deduplication is keyed
by the extracted page's `contentHash` alone, so the same bytes reached by a
different URL, a different attempt, or a different source are one snapshot.

Rules:

- The first stored snapshot keeps the identity it was first given. A later
  duplicate updates that record's attempt counters and URL lists but never
  rewrites `snapshot.id`, `passages`, or `extractedText`. An identity that has
  been cited must not change meaning because the same page was fetched again.
- Every offer is counted, not just the ones that stored bytes:
  `totalAttempts` counts offers of that content, `duplicateAttempts` counts the
  ones that did not store. `attempt` records the attempt number that actually
  produced the bytes, not the last offer to arrive.
- The store re-derives snapshot and passage identity from the source id,
  content hash, ordinals, and text digests before storing. A caller that hands
  in a hand-built snapshot with a mismatched id or passage set is refused with
  `inconsistent_page` rather than trusted.
- `record(forHit:)` resolves a hit only through the URLs actually requested for
  a snapshot or its final URL. A hit whose URL was never acquired is refused
  with `hit_is_not_evidence`; the snippet is never consulted. This is the
  mechanical form of "search snippets never become evidence".
- The store is an actor because bounded parallel fetch will offer pages
  concurrently; the concurrency test requires that simultaneous offers of the
  same bytes store exactly one snapshot and count the rest as duplicates.

Consequences:

- Duplicate detection is content-addressed, so it is independent of URL
  aliasing, redirect chains, and retry order.
- Three duplicate reasons are distinguished - `repeated_attempt`,
  `same_content_from_another_url`, `same_bytes_from_another_source` - because
  they are different facts about the run, and collapsing them would hide a
  redirect loop or a shared CDN body.
- The store is pure: no socket, no name resolution, no filesystem, no clock.
  A guard test asserts that property over the source text.
- The first run of the new suite was red with 3 failures, all in the tests
  themselves: an assertion compared five attempt ids against two stored
  records, and a duplicate-counter assertion read a stale value copy instead of
  re-reading the record the store had updated in place. Both are fixed in the
  assertions; no production behaviour was weakened.

## D021 - A batch is bounded and polite by schedule, not by caller discipline

Decision: `BoundedFetcher.fetch(_:)` takes a list of `FetchTarget` values and
returns one `FetchResult` per target, in the order the targets were given. The
schedule is described by `FetchLimits` and enforced inside the scheduler.

Rules:

- One `TaskGroup` child per target. Results are re-sorted by the caller's index
  before returning, so the returned order never depends on completion order.
  A batch that reported arrival order would describe itself differently on two
  runs over the same targets.
- The batch-wide ceiling (`maxInFlight`) is enforced by a `FetchLimiter` actor
  that admits waiters in arrival order, so the bound is fair as well as strict.
- Per-host concurrency is one request at a time, enforced by the host's
  `HostRequestGate`. `maxInFlightPerHost` cannot raise that: the gate is
  stricter than any number above one. Its real effect is on queueing - with a
  value of one, targets that share a host cannot occupy the whole batch budget
  while they wait their turn. The fixture therefore asserts the stronger fact
  (no host ever sees two requests at once, whatever the number says) and one
  case exists specifically to prove that a looser number does not loosen
  politeness.
- The robots check and the request that follows it run inside one turn of the
  host gate. Taking the gate separately around each would let two requests
  leave back to back and would defeat a published `crawl-delay`.
- A retry is a new attempt of the same target, not a new target. The attempt
  number is passed to `SnapshotStore.store(_:attempt:)`, so a fetch that
  succeeded on its second attempt stores one snapshot whose record names
  attempt 2, and the first attempt is counted rather than forgotten.
- Only `CancellationError` is thrown out of `fetch`. Every other outcome is a
  value: `stored`, `duplicate`, or `refused` with a `FetchStage` and a kind.
  One source failing is a result of a research run, not a reason to discard the
  sources that succeeded.
- Retries are limited to `timeout` and `transport_failure`. A status code, a
  refused address, a robots rule, and an unreadable document are answers;
  asking again would only repeat them.
- The refusal is flattened to `(stage, kind, reason)` so that one batch can
  report four different boundaries without the caller switching over four error
  types. `FetchStage` is a closed set of four, and the fixture's refusal table
  is asserted to enumerate exactly those four.

Consequences:

- Parallelism is measured, not inferred. The stub transport holds each document
  request until the case's declared number of requests are in flight together
  (a bounded yield loop, no wall clock). A serial schedule cannot satisfy that,
  so "the batch is parallel" is a measurement rather than a hope, and the
  measured peak is then exactly bounded above by the ceiling.
- Two targets offering identical bytes in the same batch are race-decided in
  the one respect that cannot be otherwise: which offer stores the bytes. The
  fixture marks that case and asserts the multiset of outcomes plus the stored
  record, because the contract is "one snapshot, both identities, both URLs,
  one duplicate", not "target 0 stores and target 1 duplicates".
- A ceiling that a caller can raise without a politeness effect is a ceiling
  that must be proven not to have one, so a case sets the per-host ceiling to
  two and asserts the observed per-host overlap is still one.
- The first run of the new suite was red with 5 failures. Two were real
  defects in the tests (a record read from a result captured before the merge,
  and peak-overlap expectations that assumed the limiter rather than the gate
  was the binding per-host constraint). Three were the same defect in
  miniature: overlap measured by yield counting is not deterministic, so the
  measurement was replaced by the barrier. No production behaviour was
  weakened; the per-host expectation was tightened from two to one.

## D022 - A diagnostic is derived from the run, never authored beside it

Decision: `HTMLExtraction.diagnose(_:sourceID:policy:)` returns an
`ExtractionOutcome` carrying either the page or the refusal, each with exactly
one `ExtractionDiagnostic`. `HTMLExtraction.extract` is implemented as a
`switch` over `diagnose`, so the throwing entry point and the reporting entry
point execute one pipeline and cannot disagree about what happened.

Rules:

- The stage comes from `ExtractionError.stage`, an exhaustive switch over the
  refusal family. A new refusal case cannot compile without deciding which
  boundary owns it, so the stage mapping is total by construction and all seven
  stages are reachable. No new refusal kind is introduced.
- Every fact is a count or a digest over bytes already in hand. Nothing is
  fetched, resolved, timed, or estimated: the diagnostic reports what the run
  measured, not what it might have done.
- A run that never decoded reports `charset=undecided`, `charset_source=
  undecided`, and `decoded_digest=undecided`. The requested encoding belongs in
  the refusal's reason, not in a fact about what was used. This is enforced in
  one place - the metrics builder - so no caller can bypass it.
- `decoded_digest` is the digest of the decoded characters, so two bodies that
  differ by one character cannot produce the same record. Without it the
  fingerprint would identify the shape of a run rather than the run.
- `runs_dropped` counts a text run that held characters, produced no readable
  text, and *began inside a prose element* (`p`, `li`, `dt`, `dd`,
  `blockquote`, `figcaption`, `td`, `th`, `pre`, and the headings). Whitespace
  between structural elements is layout; counting it would make the number a
  measure of a document's indentation. The depth is recorded when a run's first
  character arrives, so a closing tag cannot retroactively decide whether the
  run was inside it.
- Nothing is reported that is always false. Extraction refuses an oversized
  document rather than truncating it, so there is no `truncated` or
  `bytes_dropped` field: the byte ceiling and the byte count are reported, and
  a fact that could never vary would be decoration.

Consequences:

- The record is frozen at twenty-three serialized keys in a fixed order, with
  the fingerprint last, taken over exactly the preceding lines. A reader can
  strip the last line and hash the rest to check the record itself.
- Three red runs shaped the design rather than being worked around: the first
  run reported `runs_dropped=2` because inter-element newlines were counted
  (fixed by the prose-depth rule); the second let a one-character change
  produce an identical fingerprint (fixed by `decoded_digest`, which
  strengthened the property instead of weakening the assertion); the third
  reported the requested `shift_jis` as a used encoding on a run that never
  decoded (fixed by the single undecided gate). A mistyped digest literal in
  the frozen field-order test was corrected against the measured value, and
  the test now cross-checks the digest against the fixture body so the literal
  cannot drift from the characters it claims to identify.

## D023 - The live corpus is gated by a recorded approval, and the harness holds no transport

Context: M002 has to show that the boundaries produce the expected typed
outcomes on *real* pages, but no page's licence has been recorded and no owner
approval exists for any page (see `docs/REUSE_PROVENANCE.md`). A test that
quietly fetches a live page would also break the repository's offline
guarantee.

Decision: an opt-in corpus harness, `LiveCorpus`, that can *plan* and *judge* a
live run but cannot perform one.

- The module imports `Foundation` only and holds no transport, no session, no
  resolver, and no clock. A live run is a separate, later binary that produces
  `CorpusObservation` values; nothing in this module can produce one, so no
  default or gated test run can reach the network through it.
- `Fixtures/corpus/live-corpus.json` records, per entry, an identifier, an
  https URL, a licence, a reference to that licence's text, a frozen expected
  typed outcome, and an approval naming who recorded it and where. An entry
  that omits any of these is a typed refusal at decode time, not a default.
- An unapproved entry refuses the *whole* manifest. A run that silently
  skipped an entry would report a pass over a corpus it did not run.
- An empty manifest is valid - "no corpus is approved yet" is a real state -
  and it decodes; it is the run gate (`noEntries`), not the decoder, that
  refuses it. The shipped fixture is empty and records why.
- Expectations reuse the frozen `FetchStage` vocabulary
  (`acquisition`/`robots`/`extraction`/`store`) rather than inventing a second
  one, so an expectation and an observation cannot disagree about names.

Consequences:

- The ten manifest refusal kinds and the two run refusal kinds are frozen and
  enumerated by a test, so a new kind cannot be added silently.
- The verdict reason names both shapes in the vocabulary's own terms
  (`expected refused(extraction/no_readable_text) and observed
  extracted(html-extractor-1)`), so a mismatch is greppable rather than prose.
- Because no licence and no approval is recorded, M002.8 ships the gate and the
  harness with the blocker recorded in the fixture and in the state file. The
  live-corpus portion of the M002 gate is therefore explicitly *unproven*
  rather than claimed, and no non-redistributable body is committed.

## D024 - Lexical retrieval is a derived FTS5 index over stored passages

Context: D005 selects SQLite FTS5/BM25 as the first retrieval baseline, and
D020 makes the snapshot store the source of truth for immutable evidence. M003.1
has to turn that store into a measurable lexical baseline before any model,
reranker, or vector store is considered.

Decision: `LexicalIndex` is an actor that owns one SQLite connection and one
FTS5 virtual table, `passage_index`. The snapshot store stays the source of
truth; the index is a derived artifact that can be rebuilt from it.

Rules:

- An FTS5 probe (`CREATE VIRTUAL TABLE ... USING fts5`) runs against the system
  SQLite before the boundary is trusted. On this machine the probe succeeded
  and returned a bm25 score, so FTS5 is compiled in and no fallback is written.
  The index creation is also the runtime probe: if FTS5 is missing, the index
  fails closed with `unavailable` rather than falling back to a scan.
- The only unit that can be ingested or retrieved is a stored `Passage`. The
  `passage_index` table indexes exactly two columns, `heading` and `text`; every
  identity column (`passage_id`, `snapshot_id`, `source_id`, `ordinal`,
  `text_hash`) is `UNINDEXED`, so the `bm25()` weight list lines up with the two
  indexed columns in declaration order.
- Ranking is `bm25(passage_index, headingWeight, bodyWeight)` - more relevant is
  more negative, so ascending score is best-first - with `headingWeight` 3.0 and
  `bodyWeight` 1.0 in the shipped policy. Ties are broken by ascending ordinal,
  then ascending passage id, in SQL and again in the selection pass, so the
  result never depends on SQLite's row order.
- The one source feature is diversity: `maximumPassagesPerSource` caps how many
  passages from one source may appear, applied deterministically over the ranked
  candidates. Source-type and recency features need metadata the snapshot record
  does not carry yet and are deferred, not implied.
- Ingest and query fail closed with typed outcomes. Ingest returns `indexed` or
  `duplicate`; query and resolve throw a `LexicalIndexError` whose nine kinds
  are frozen by a test: `unavailable`, `invalid_policy`, `invalid_snapshot`,
  `invalid_passage`, `empty_query`, `invalid_limit`, `limit_exceeds_policy`, and
  `unknown_passage`, plus `inconsistent_row` for a stored row that no longer
  describes itself. A query with no alphanumeric term is refused; each term is
  quoted so a query is data and never FTS5 syntax.
- Identity is re-derived on ingest and on resolve. A record whose snapshot id,
  passage ids, ordinals, or text digests do not follow from its own source id
  and content hash is refused, exactly as the snapshot store refuses it.
- `IndexedHit` deliberately has no snippet field. The only path from the index
  to evidence is `resolve(_:)`, which returns the exact stored passage and its
  source and re-validates the stored row.
- `maximumResults` is the hard result cap, not only a default. A caller may
  lower it per query but not raise it; a limit above the policy maximum is
  refused with `limit_exceeds_policy` instead of being silently capped by
  `maximumCandidates`. The candidate ceiling is bound to SQL with
  `sqlite3_bind_int64`, so a value at the top of `Int` binds exactly rather than
  trapping in a narrowing conversion or becoming SQLite's `LIMIT -1`.

Consequences:

- The fixture `Fixtures/retrieval/lexical-scenarios.json` is hand-authored and
  synthetic: six documents on reserved `.invalid` hosts, four frozen ranked
  queries that make each ordering explainable, and six refusals covering the
  empty query, a zero limit, a limit above the policy maximum, and an unknown
  passage. Bodies are extracted through the M002.4 boundary into the M002.5
  store before they are indexed, so the index is fed what the pipeline would
  hand it, never fixture rows authored to look like passages.
- Deterministic ranking is asserted across repeated queries and a second,
  separately built index. A durable index is asserted to survive reopening and
  to keep retrieving its stored passages.
- The first run of the new suite was green; no gate was weakened. The two
  repairs above (the result-cap refusal and the Int64 bind) were found by
  reviewing the untracked draft against the milestone contract, not by a red
  test. They are recorded because they changed the draft, not because a gate
  failed.
- A reranker remains an adapter added only through `docs/MODEL_POLICY.md`, and
  the controller must remain functional when no reranker is configured.

## D025 - Citation compilation binds a claim to exactly one retrieved passage

Context: M003.1 gives the run a ranked lexical retrieval over stored passages.
M003.2 has to connect that retrieval to the claim, evidence, and citation graph
so the deterministic Quick path can produce inspectable citations before any
model is asked to draft prose.

Decision: `CitationCompiler` is a pure function from `[ClaimCandidate]` and a
`LexicalIndex` to a `CitationCompilation`. A candidate carries a claim, the
query that retrieves its support, the exact quote the supporting passage must
contain, and an optional expected snapshot id.

Rules:

- The compiler re-derives the claim id from the claim's dimension and text
  before it trusts it; a forged id is refused with `invalid_claim`.
- For each candidate it retrieves ranked passages with the M003.1 index. A
  query with no term is `empty_query`; any other index refusal is wrapped as
  `retrieval_failed`; an empty result is `no_results`.
- Exactly one distinct retrieved passage must contain the exact quote. None is
  `quote_not_retrieved`; more than one is `ambiguous_quote`; a blank or
  whitespace-only quote is `empty_quote`, because an empty string is a
  substring of every passage and can never be evidence.
- A candidate that names an expected snapshot must be supported by that
  snapshot or is refused with `wrong_snapshot`.
- Evidence and citation identity are content-derived with the M001 part
  ordering: `StableIdentity.make("evidence", claimID, passageID, quote)` and
  `StableIdentity.make("citation", claimID)`. The same claim cannot be bound
  twice (`duplicate_binding`).
- `CitationCompilation` is a plain value. Both `validate()` and `resolve(_:)`
  re-check every citation's claim, every evidence link, every passage, and
  every exact quote before returning anything, so a hand-built or altered
  compilation fails closed with `unknown_citation`, `empty_citation`,
  `unknown_claim`, `unknown_evidence`, `unknown_passage`, `quote_not_exact`, or
  `inconsistent_citation`. Every link is checked, not only the returned one, so
  a dangling later link cannot hide behind a valid first one.
- The compiler has no URL or snippet field and imports `Foundation` only: it
  opens no socket, resolves no name, reads no file, and consults no clock.

Consequences:

- The fixture `Fixtures/retrieval/citation-scenarios.json` is hand-authored,
  synthetic, and on reserved `.invalid` hosts; its documents are extracted and
  stored through the M002.4 and M002.5 boundaries before indexing, so a green
  test proves the composition and not a mock.
- Sixteen refusal kinds are frozen and enumerated by a test that also ties the
  fixture vocabulary to the same set, so a new kind cannot be added silently:
  nine compile refusals (`invalid_claim`, `empty_query`, `retrieval_failed`,
  `no_results`, `quote_not_retrieved`, `empty_quote`, `wrong_snapshot`,
  `ambiguous_quote`, `duplicate_binding`) and seven resolve refusals
  (`unknown_citation`, `empty_citation`, `unknown_claim`, `unknown_evidence`,
  `unknown_passage`, `quote_not_exact`, `inconsistent_citation`).
- The first run of the new suite was green. The empty-quote guard and the
  all-links validation were added while reviewing the new boundary before
  commit; they are recorded because they changed the draft, not because a gate
  failed.

## D026 - The deterministic Quick pipeline composes retrieval, compilation, and the run state machine

Context: M003.1 gives a ranked lexical index, M003.2 binds claims to retrieved
passages with typed refusals, and M001 already freezes the Quick phase order in
`RunStateMachine`. M003.3 has to compose them into one offline run before any
model is attached.

Decision: `QuickPipeline.run` takes a `QuickRunPlan` (question, frozen
`ClaimCandidate`s, and source metadata), a `SnapshotStore`, and a
`LexicalIndex`, and returns a `PersistedRun` whose run always ends in a terminal
status.

Rules:

- The pipeline drives the existing `RunStateMachine` through scoped, rewriting,
  searching, acquiring, extracting, retrieving, building_evidence, drafting,
  validating, and complete. It does not change the transition table.
- Retrieval and citation compilation are the M003.1 and M003.2 boundaries,
  composed unchanged.
- A `CitationCompilerError` is caught and turned into a `.failed` terminal
  status whose stop reason names the refusal kind
  (`citation_compile_failed: <kind>: <reason>`). The pipeline never completes
  with an empty citation when a claim failed to bind.
- The result contains only the snapshots, sources, and passages the compilation
  cites. A cited snapshot the store does not contain is `missing_snapshot`; a
  cited source the plan does not describe is `missing_source`; both fail the
  run rather than producing an unattributable citation.
- `QuickRunPlan` validation refuses an empty question and duplicate source
  identities before a run starts.
- The pipeline imports `Foundation` only: no socket, DNS, file, clock, model, or
  provider.

Consequences:

- The fixture `Fixtures/retrieval/quick-scenarios.json` holds four synthetic
  `.invalid` documents, four source records, and four frozen questions: three
  complete and one (`q-mercury`) whose query retrieves nothing and therefore
  must fail with `no_results`.
- Every completed run is re-validated through `FixtureWorkspace.inspections`,
  the same resolver the UI uses, and two runs produce identical `PersistedRun`
  values.
- The first build was red because a local `payload` value shadowed the helper
  method of the same name; the helper was renamed to `makePayload` and no
  assertion or guard was weakened. The `missing_snapshot` guard was added while
  reviewing the boundary before commit.

## D027 - Web search and lexical retrieval take different query shapes

Context: M003.6 fed the same four-term keyword windows to both SearXNG web
search and the FTS5 lexical index. Measured on 2026-09-25, that split "Grand
Central Dispatch" into `swift structured concurrency grand` and returned no
independent comparison source for Q2, no macOS system-SQLite source for Q3,
and no correction thread for Q5, while the natural-language question surfaced
all three.

Decision: the two consumers get different queries. `QuickQueryPlanner.webQueries`
returns the trimmed natural-language question for web search;
`QuickQueryPlanner.plan` returns the keyword windows for the lexical index.
`LiveQuickRunner.retrieve` and `run` take an optional `retrievalQueries` list
that defaults to the search queries, so existing callers and deterministic
tests are unchanged and the two lists can diverge only where a caller chooses
to.

Rules:

- Search is handed the question; the index is handed short strict windows.
- A long all-term FTS5 query still strict-matches nothing; the runner's
  ranked any-term pass now fills remaining synthesis budget instead of running
  only when the strict pass is empty, so a two-source question can receive more
  than one fragment. Strict hits stay first and the fill is still
  `EvidenceText`-filtered.
- Both lists remain capped by the frozen Quick `searchQueries` limit.
- Neither change touches ranking identity, citation identity, the offline
  guards, or the M001 fixture slice.

Consequences:

- `testWebSearchQueryIsSeparateFromRetrievalQuery` fails if the runner reuses
  one query list for both paths, and a planner test pins `webQueries` against
  `plan`.
- Live retrieval observations while the engines answered are recorded in
  `docs/evidence/M003/m0036-source-relevance.md`; Q2 and Q3 now open the
  comparison and system-SQLite material the card needed.
- This is a deterministic source-relevance fix, not a model, embedding, or
  reranker change. The frozen-card usefulness effect is unmeasured because the
  SearXNG engines suspended before a provider re-run; that re-measure stays
  owed and must not be reported as a promotion.

## D028 - Source authority orders discovery, it does not certify claims

Context: the M003.7 card measured 1/10 and, worse, answered the false-premise
question Q5 entirely from one Medium post that states the misconception, while
Q1 answered a Swift question from two personal blogs. Search returned both
official and non-official pages; the runner opened them in the metasearch
gine's order, so a blog could supply the citation.

Decision: `SourceAuthority` assigns a discovery tier to each search hit -
`0` for conventional official documentation or project-forum hosts (`docs.*`,
`developer.*`, `forums.*`, or a known official registrable domain) and `1`
otherwise - and `LiveQuickRunner.prepare` opens tier-0 hits before tier-1 hits
with a stable sort that preserves the search engine's order inside each tier.

Rules:

- This is a source-type discovery feature, not a reranker and not a citation
  rule. It changes which pages are fetched, never which claims are accepted.
- The snippet-never-evidence rule, exact-quote validation, and the citation
  boundary are unchanged. A non-authoritative page is still opened when it is
  all that was found, and its passages can still be cited if exact.
- It adds no model, embedding, vector store, or network call, and it is
  deterministic and unit-tested.

Consequences:

- Targeted two-call verification: Q1 gained an Apple WWDC23 citation and scored
  2/2 (was 1/2); Q5 stopped endorsing the false premise and scored 1/2 (was
  0/2 with a hard false-premise failure). Projected card 3/10, still below the
  four-question promotion threshold, so Quick is **not** promoted.
- Source authority is not correctness: Q1 still cites two personal blogs beside
  the Apple source, and Q5's correction is blog-sourced. An exact quote can
  still be a misconception, so exactness stays distinct from entailment.
- Q2 and Q4 still abstain for recall, which this treatment does not address.

The generic `docs.*`/`developer.*` part of this rule was later narrowed by
D029 after a spoofable-prefix review; this entry preserves the original
M003.7 decision and measurement.

## D029 - Disambiguate measured search intent and do not equate a docs prefix with authority

Context: M003.8's provider-free Q4 run searched the word `Swift` and opened
financial-SWIFT standards material. A disambiguated search surfaced an
official dated programming-language release passage. Q2 and the five fresh
searches showed that readable passages can still be irrelevant. The M003.7
generic source-authority rule also promoted any `docs.`/`developer.` prefix,
even on an unrelated domain.

Decision: the narrow `latest stable Swift release` web query includes
`programming language`; the local lexical plan and Quick cap are unchanged.
Body text identical to its heading is refused as answer evidence. Tier-0
source discovery requires a known official domain or the existing Swift GitHub
path, not a documentation-looking subdomain on an arbitrary host.

Consequences: Q4 default retrieval selected a Swift.org passage containing
both the version and release date, but no hosted answer was re-run. Q2 remains
unstable; no frozen-card quality promotion is claimed. Five fresh retrieval
outcomes, CLI latency/RSS, and misses are recorded in `docs/evidence/M003/`.
`make gate` passed with 234 tests. The next task is M003.9, not a model
comparison or packaging declaration.

## D030 - Default Quick web discovery to a no-card free tier

Context: the owner has no Brave Search key. The Mac product cannot require a
Docker SearXNG endpoint for normal open-web use. The measured SearXNG baseline
and vendor comparison are in
`docs/evidence/M003/m0039-search-backend-decision.md`.

Decision: use Tavily basic search as the default, user-owned free-tier web
discovery adapter; keep Brave optional and SearXNG for contributors. Keep a
keyless supplied-page path. Expose **Find evidence without AI** so a search
key alone can deliver fetched, inspectable passages. Explicit Keychain saving
and network/hosted disclosure remain in the Mac app. No Tavily answer or raw
page body bypasses our own safe fetch, snapshot, and exact-passage citation
boundary.

Consequences: the adapter and app build are deterministic/local proof only;
the supplied-page Mac path was observed without keys, but Tavily live API
behavior and relevance await a user key. DeepSeek remains a separate hosted
answer provider and may cost money. M003.9 and the unchanged card stay open;
there is no Quick-quality promotion or packaged second-machine proof.

## D031 - Live Tavily proof does not waive retrieval preflight

Context: the owner's Tavily key made normal-user no-Docker search testable. A
pre-recorded single Mac Ask produced four exact citations in 6.0 seconds, but
one was a redundant claim from a weaker third-party forum. A separate
provider-free Tavily preflight found Q2/Q3/F1/F5 retrieval misses before any
new frozen answer-card spend.

Decision: record the app run as live integration proof, not Quick-quality
promotion. Preserve Q2/Q3/F5 misses and typed safe-fetch refusals. Treat F1's
measured query-to-passage mismatch with a narrow deterministic lexical query
using the official page's failure wording; leave its natural-language web
search and the citation boundary unchanged. A counterclaim search for F5 did
not recover direct evidence, so no speculative F5 rule is adopted. Close
Connection on a valid app run to give the evidence rail space, while keeping
it expanded for configuration errors.

Consequences: F1's official child-failure rule became the first selected
passage on a default Tavily recheck; no F1 answer quality was measured. The
current ad-hoc app then reproduced the F1 selection through its own no-AI path
under driven UI, with the Connection disclosure collapsed
(`docs/evidence/M003/m0039-f1-app-check.md`). The one-call app smoke is spent
(cumulative recorded provider-attempt minimum 37). A full unchanged card
remains ineligible until retrieval preflight is stronger; no model, reranker,
new service, or later milestone was added.

## D032 - Redirect identity must keep the trailing slash

Context: Q1 and Q4 could not reach Apple or Swift.org primary pages. The
provider-free retrieval opened only two sources for Q1 and refused
`developer.apple.com/videos/play/wwdc2021/10134`, `swift.org/blog`, and a
personal blog post as `acquisition/redirect_loop`. Instrumentation showed each
of those servers redirects `/page` to `/page/` and then returns 200, so the
refusals were false.

Cause: `SafeAcquisition.canonicalKey` built the loop-detection key from
`URL.path`. Foundation's `URL.path` drops a trailing slash, so the redirect
target `/page/` produced the same key as the URL just visited and the
legitimate hop was rejected as a loop.

Decision: build the key's path from
`URLComponents(url:resolvingAgainstBaseURL:false)?.percentEncodedPath`, which
preserves the trailing slash and percent-encoding. A URL that differs only by
a trailing slash is a distinct resource; `maxRedirects` still bounds a
pathological ping-pong, and a genuinely repeated URL is still a loop.

Consequences:

- Deterministic and unit-tested
  (`testTrailingSlashRedirectIsFollowedRatherThanTreatedAsALoop`). No safety
  rule was relaxed: every hop is still validated before it is requested.
- Measured: Q1 opened 5 sources instead of 2 and gained Apple WWDC21 10134 and
  WWDC23 10170; Q2 gained the two-sided Apple/Swift-Forums comparison; Q4
  reached the dated `swift.org/blog` release note.
- Extraction, not acquisition, is now the Apple limiter:
  `developer.apple.com/documentation/...` still refuses as
  `no_readable_text` because the page is JavaScript-rendered.

## D033 - Quick is promoted on the treated card; the fifth question stays a canary

Context: the unchanged card measured 2/10 (M003.6), 1/10 (M003.7 first pass),
projected 3/10 (M003.7 targeted), and 6/10 with only the acquisition fix
applied (Q3/Q5 abstaining). A targeted Q3 rerun then scored 1/2 with an exact
`PRAGMA compile_options` citation.

Decision: promote Quick on one coherent re-run of the unchanged card that
scored **7/10 with 13/13 exact citations**, four of five questions at >=1/2,
Q5 abstaining without endorsing its false premise, Q1 citing an Apple primary
source, and Q4 showing dated freshness. The Q3 treatment is deterministic and
regression-tested. The fifth question is the project's untuned canary and is
**not** given a targeted treatment, even though it is the last below-threshold
question.

Consequences:

- Promotion is a per-run card result, not a claim that every question is
  answerable. Q5 abstains rather than correcting the false premise, and Q3
  gives the check step but not the build-it-yourself step.
- The card threshold no longer fails, so the M004 entry criterion (a stable
  retrieval failure the lexical/source baseline cannot meet) is not obviously
  satisfied; M004 opens with an entry check and may be recorded `not needed`.
- No model, reranker, vector store, or external service was added to reach this
  result; the only changes were the redirect fix and one planner query order.

## D034 - The owner redefines M004 as the four-mode product surface

Context: the shipped development app was one Quick-only live form. The owner
stated that the agreed product was a complete four-mode application and that
the visible surface was different and missing features. The repository record
agrees: `docs/PRODUCT.md` specifies a mode toolbar, a living brief, an evidence
map with provenance ribbons, exact-passage inspection, and a bounded gap action,
and `docs/MILESTONES.md` lists history, a global launcher, onboarding, and a
packaged build inside M003 while the M003 gate does not test them. The
milestone-gated approach had delivered a strong Quick retrieval/citation engine
and almost none of the agreed surface.

Decision: treat the owner directive as authoritative and redefine **M004** as
the Living Research Map and four-mode product surface. M004.1 (surface, frozen
mode policies, planner, multi-round runner, history, launcher, pause/cancel,
OpenAlex discovery, News independence clustering) is implemented and locally
observed. M004.2 closes the measured gaps: Academic discovers scholarly landing
pages but selects 0 usable passages, and News independence is unobserved on an
answered run. M005-M009 keep their original scopes. The original M004
retrieval-treatment entry check is deferred and remains unanswered.

Consequences:

- Modes remain frozen execution policies, not prompt labels: Quick 2/6/12/60s,
  Deep 6/16/24 with 2 follow-up rounds/180s, Academic scholarly-first
  5/14/24/180s, News 14-day window 5/14/20/120s. The runner refuses a plan that
  does not match its policy.
- Every mode still reaches citations only through the unchanged
  provider-to-verification-to-compilation boundary; the surface cannot promote
  a snippet to evidence.
- The surface is implemented and locally measured, not proven complete:
  Academic evidence, News independence answer verification, local inference,
  notarized packaging, and second-Mac reproduction remain open.
- No model, reranker, embedding, vector database, or external service was added.

## D035 - The local answer boundary is explicit and never a silent fallback

Context: M004.1 had no local answer path; every answer left the machine through
hosted DeepSeek. The first live local run produced a useful Quick answer with
four exact citations in 34.1 s at US$0, and the same endpoint then produced an
irrelevant answer on "what changed in the latest Swift release", choosing the
financial-messaging sense of SWIFT and citing clearstream.com while apple.com
and swift.org programming passages were stored.

Decision: keep `LocalAnswerProvider` as an explicit, labelled boundary selected
by the user in Connection, record its candidate per `docs/MODEL_POLICY.md`, and
**not** promote it to default until the frozen card is scored. A local failure
never falls back to a hosted provider; it abstains or shows the failure. The
`AnswerPrompt` function owns the provider instruction so hosted and local
cannot drift, and every artifact carries `local/<model>` or the hosted model
name.

Consequences:

- Local and hosted results stay visibly and analytically separate; the toolbar
  shows `LOCAL · <model>` or `HOSTED · DEEPSEEK`.
- The trust boundary does not weaken for a local model: `AnswerTrust` still
  verifies every quote against a stored passage, so a local model can only
  propose fewer accepted claims, never a weaker citation.
- The wrong-sense answer is preserved as a measured local quality failure; the
  query planner is not tuned against a single observed question.
- The local runtime is the user's own installed server; the repository does not
  download, install, or manage model weights.

## D036 - The local model is measured, useful in part, and not promoted

Context: the local boundary from D035 had produced one useful Quick answer and
one wrong-sense "Swift" answer. The pre-recorded experiment threshold in
`docs/MODEL_POLICY.md` required at least four of five frozen questions at
>=1/2 with 100% citation integrity before the local path could become default.

Decision: run the frozen card and record **6/10 usefulness with 10/10 exact
citations**. Q1 and Q2 scored 2/2, Q3 1/2, Q4 abstained, and Q5 answered
adjacent claims that can read as endorsing its false premise instead of
correcting or abstaining, so only three questions reached >=1/2. Q2 also took
82.69 s against a 60 s ceiling. The local path is **not promoted**.

Consequences:

- `LOCAL · <model>` stays an explicit Connection choice and never a silent
  fallback; hosted remains the default.
- The threshold was applied as written and was not weakened after the result.
- No prompt or planner change was made in response to the card, because that
  would be tuning against the observed sample.
- The failure set (Q5 non-correction, Q2 latency, Q3 partial, Q4 abstention,
  and M004.2's wrong-sense answer) is the local quality record a future
  treatment must move against.

## D037 - Scholarly discovery is multi-provider, and fallback slots are reserved

Context: M004's Academic path used one OpenAlex adapter. M005.1 added arXiv and
Crossref with DOI/arXiv identity reconciliation. The first three-provider run
was a measured regression: scholarly targets filled all 14 fetch slots, the
readable general-web fallback never opened, and only 3 passages were selected
against 22 before the change.

Decision: keep the three boundaries, reconcile duplicates by DOI and
versionless arXiv identity, and reserve fetch budget for the web fallback with a
run-scoped scholarly cap of 8 targets split 3/2/2 across OpenAlex, arXiv, and
Crossref. Crossref emits the canonical DOI resolver because that URL carries
the identity, and the bounded fetch follows the redirect to the publisher.

Consequences:

- Academic measured 24 passages from 9 opened sources in 17.8 s with arXiv,
  DOI, and web sources all present.
- A provider cannot starve the fallback, and one work cannot occupy three
  fetch slots.
- PDF/page-aware evidence and BibTeX/RIS export remain open; a paper claim
  still requires an HTML page.
- The 8 and 3/2/2 constants are measured, not proven optimal.

## D038 - PDFKit for page-aware paper evidence, and a deliberate refusal change

Context: M005.1 could reach an open-access paper only when an HTML landing page
existed. DOI resolvers often land on a PDF or a bot-walled publisher page, so a
paper claim frequently had no readable target.

Decision: use **PDFKit**, the macOS system framework, for page-aware PDF text.
It adds no package dependency, downloads nothing, needs no model, and exposes
text per page, which is what a page citation requires. A passage keeps the exact
page text and carries `Page N` in its heading, because the frozen `Passage`
entity has no page field and must not change. An alternative in-repository PDF
parser was rejected as larger and less reliable for no licensing benefit.

The same change turns the fixture target that declares `application/pdf` with a
deliberately malformed body from `unsupported_content_type` into
`malformed_markup`. The fixture, the frozen-matrix text, and the test were
updated together with a comment. This is a deliberate expectation change on a
now-supported media type, not a weakened gate: the target still refuses with a
typed reason on the same stage.

Consequences:

- A live arXiv PDF extracted 12 page-headed passages through the unchanged
  acquisition boundary in 0.63 s.
- Scanned or image-only PDFs refuse as `no_readable_text`; there is no OCR and
  none is planned without a measured need and a model-policy record.
- BibTeX, RIS, and Markdown export now ship in `CitationExport`, with an EXPORT
  row in the app's completed brief and history replay.
- The M005 gate still needs its held-out academic comparison; M005.3 owns it.

## D039 - The academic held-out comparison is a no-benefit result and is kept

Context: the M005 gate requires the academic held-out set to beat generic web
search on citation quality. M005.1-M005.2 built multi-provider scholarly
discovery, DOI/version reconciliation, page-aware PDF evidence, and export. The
M005.3 held-out comparison then measured scholarly-first discovery against a
generic-web-only baseline, provider-free, on three frozen questions.

Result: scholarly-source share was 58% for the scholarly path against 54% for
the generic web, the web baseline surfaced the same key papers on the third
question, and the scholarly path cost 7-43x the latency (up to 89.76 s). That is
not a clear citation-quality win.

Decision: record the M005 gate as **not met** and preserve the no-benefit
result. Do not reframe the scaffold (Findings/Method/Limitations) as a win, and
do not weaken the gate. Treat the measured defects instead: aggregator pages
outranked primary sources inside the scholarly list, and three providers were
called per query across up to five queries.

Consequences:

- M005 stays open with M005.4 as the next treatment: primary-source ordering
  for discovery and a conditional Crossref call, re-measured on the same frozen
  set.
- Academic remains available to users; the mode's discovery is not disabled.
- The negative result is the baseline M005.4 must move against.

## D040 - Academic discovery is primary-first, and the M005 gate is met on the held-out answer card

Context: M005.3 recorded a no-benefit retrieval result (58% vs 54% scholarly
share, 7-43x latency). M005.4 then ordered primary paper targets before
aggregators and called Crossref only when OpenAlex and arXiv left fewer than six
scholarly candidates.

Decision: keep both treatments and record the M005 gate as **met on the
answer-level measurement**. On the same frozen held-out set the shipped Academic
policy produced 5/6 usefulness against the generic-web policy's 3/6, at 100%
citation integrity on both paths. Latency fell 19% on retrieval (120.98 s
against 150.15 s) and `Limitations` coverage became non-zero on all three
questions.

Consequences:

- The confound is explicit and preserved: the two paths ran their own frozen
  budgets (Academic 14 sources/24 passages, Quick 6/12), so this compares the
  shipped modes, not scholarly discovery at equal budget. The M005.3
  retrieval-share tie stands as a negative result.
- Aggregators still appear after primary sources, and publisher refusals remain.
- Academic latency remains far above the web baseline; that is documented, not
  hidden.
- News mode's unenforced time window is the next measured defect and M006.1 owns
  it.

## D041 - News enforces its window at discovery and counts independent voices

Context: News mode's frozen policy declares a 14-day window and independent
confirmation, but only the query text carried the month: nothing filtered by
date and the independence count was a raw domain count.

Decision: enforce the window at discovery, before any fetch is planned, and drop
both stale and undated results while counting each. Treat two domains that
published the same headline as one independent voice, and mark every cited claim
with the number of voices behind its page so a single-source answer is shown as
uncertain rather than confirmed.

Consequences:

- Live measurement: 7 of 30 discovery results were outside the window and were
  excluded; the surface shows `WINDOW · 23 dated results inside the window, 7
  outside it`.
- An undated page is excluded rather than assumed fresh. This is the strict
  reading and it can starve a query; the ledger reports that instead of hiding
  it.
- The copy test is verified by fixture only: no observed live run contained a
  syndicated copy, so that gate part is recorded as not demonstrated.
- News headings are frequently navigation text, so the voice count is only as
  good as the stored heading. This is recorded as an open defect.

## D042 - The dimension plan is editable, and every loop states why it stopped

Context: Deep mode ran bounded follow-up rounds but its dimension plan was fixed
and a stop was inferable only from the round count.

Decision: make the plan editable and validate it against the frozen per-mode caps
(empty, oversized, duplicated case-insensitively, and over-long labels are
refused with typed errors; whitespace collapses, nothing is dropped or merged),
and record exactly one typed reason per round plus a terminal reason in the
report.

Consequences:

- `STOP · <reason> — <explanation>` is shown in the brief, so "it stopped
  because the evidence saturated" is visible rather than guessed.
- A later round that stores nothing is `no_new_evidence`, not `no_evidence`: the
  distinction is meaningful to a reader.
- Coverage still matches the dimension *label*, which is measured as wrong for
  Deep's generic scaffold (Evidence 0 and Tradeoffs 0 for passages that discuss
  both). M007.2 owns that, along with contradictions and a diminishing-evidence
  stop rule.
- The app's invalid-plan refusal is wired to the proven core call but was not
  observable through the accessibility tree; recorded as an open verification
  gap rather than claimed.

## D043 - Coverage reads content terms, and the loose contradiction detectors are rejected

Context: M007.1 measured that coverage matched the dimension's own label, so
Deep reported `Evidence 0` and `Tradeoffs 0` for passages that plainly discuss
both, and spent a follow-up round on a gap that did not exist. M007.2 also
attempted a deterministic numeric-contradiction detector.

Decision: ship `DimensionLexicon` so coverage matches a dimension by label or by
a fixed, in-code term list (a custom dimension falls back to its own content
terms), and ship the strict numeric-contrast rule that requires identical context
words across two pages. Reject the two looser rules that were implemented and
measured.

Consequences:

- The same Deep question moved from `Overview 0, Evidence 0, Tradeoffs 0, Gaps 1`
  to `Overview 1, Evidence 4, Tradeoffs 2, Gaps 1`, and the run no longer spends a
  follow-up round on a false gap.
- A follow-up round that adds half or less of the previous round stops with
  `diminishing_returns`.
- The rejected rules are preserved as measured failures: shared sentence terms
  paired citation-list years (`2000, 2005, 2006` against `1978`), and a shared
  unit word still joined unrelated numbers under contexts like "after" and
  "memory". Neither ships, because both would assert a disagreement the evidence
  does not contain.
- The M007 gate item "contradictions are not silently flattened" is recorded as
  only partially met: nothing is averaged or resolved and a strict detector
  exists and is tested, but live detection was not demonstrated.

## D044 - The scorecard keeps usefulness, integrity, and latency apart, and the card says when it is unscored

Context: earlier milestones recorded usefulness by hand in prose, in a way that
could drift from the run it described, and there was no deterministic proof that
the citation boundary refuses a corrupted compilation.

Decision: add a JSON benchmark card, a scorecard that stores one row per question
with separate citation-integrity, human-usefulness, and latency fields, and four
corruption checks that must all be refused. Usefulness is `nil` until a human
scores it and is reported only over scored questions.

Consequences:

- The five-question replay against the local model reports 100% citation
  integrity and `usefulness unscored over 0/5 scored`; it does not invent a
  number from citation counts.
- A local run and a hosted run are two documents, each with one label.
- Intentional corruptions are detected: an altered quote, a missing passage, a
  mismatched claim, and an unknown citation are all refused.
- There are still no human usefulness labels, so the semantic-evaluator part of
  the M008 gate is not started; M008.2 owns the review workflow.

## D045 - A review packet is data, a scorecard is two documents, and the release script refuses to imply notarization

Context: usefulness had been recorded in prose, the release path was a
development bundle signed ad hoc, and there was no way for a user to hand over a
failure without handing over their research.

Decision: generate a review packet from a run so a person can judge each claim
against its exact quote and source URL in a file; keep answer usefulness and
citation integrity in separate fields of a scorecard, with one label per
document so a local run and a hosted run are never averaged; generate learning
cards from the run itself; ship a diagnostics bundle that carries counts,
versions, and typed reasons only; and have the release build sign with the best
identity it has while stating in `BUILD-INFO.json` exactly why it did not
notarize.

Consequences:

- The reviewed run reports 100% citation integrity, mean usefulness 1.40 over
  5/5 scored, and 5 supported plus 1 partial citation. The labels are
  provisional and were written by the assistant.
- The deterministic evaluator agrees with 3 of 5 provisional labels (mean error
  0.40) and reports itself **not calibrated**, because five labels cannot
  calibrate anything against the 20-label minimum.
- `dist/release/BUILD-INFO.json` records `signature: apple-development` and
  `notarized: no` with the reason: no Developer ID Application identity is
  installed.
- A licence has not been selected. `docs/LICENSING.md` records that the
  repository bundles no third-party code and names the one file that closes the
  gate; the choice is the owner's, and M009.2 exists so the other three external
  dependencies (independent review, second machine, Developer ID) are not lost.

## D046 - The four modes are verified with the hosted provider, and three mode defects are recorded from that run

Context: the record showed two hosted Quick answers from M004.1 and nothing else.
Deep, Academic, and News had only ever been answered by the local model, and no
mode had been driven through the interface with the hosted provider since the
Living Research Map was built. Separately, the app's saved keys were not
prefilling, which made every first Ask fail.

Decision: verify all four modes through both the command-line tool and the app
with hosted DeepSeek, fix the credential path, and record what the runs measured
about the modes.

Consequences:

- Quick 6 passages/6.3 s, Deep 12/8.0 s with the comparison plan and decision
  criteria, Academic 13/25.2 s with a paper matrix, News 3/15.9 s with the
  14-day window, 10 domains, and a dated timeline. Eight hosted calls; the
  cumulative minimum moves from 39 to 47.
- Two credential faults are fixed: the provider check ran before the keychain
  read, so the first Ask always failed; and a refused read was reported as an
  empty slot, which is false. A rebuilt development bundle loses its keychain
  grant because macOS ties the grant to the code signature; the panel now says
  so and offers a deliberate Grant access action.
- Three mode defects are measured and left open, owned by M009.3: News enforces
  recency but not topical relevance (a stablecoin approval and a biodiversity
  brief reached the citations), a News answer rested on three claims with
  `Independent confirmation · 1`, and Deep stopped on `dimensions_covered` with
  `Gaps · 2` because two dimensions matched by keyword rather than being
  addressed.
- These runs prove routing and the citation boundary. They do not prove answer
  quality, and that is stated rather than implied.

## D047 - The three mode defects measured by the four-mode run are treated, and two wiring bugs are recorded

Context: the hosted four-mode run (M009.2) measured three defects in the modes
themselves, not in the plumbing: News enforced its 14-day window but not topical
relevance, so a stablecoin approval and a biodiversity brief reached the
citations; a News answer reported ten domains and ten voices while every claim
rested on one; and coverage counted keyword coincidence, so `Gaps · 2` was
reported for a gap nothing had addressed and `Timeline · 16` counted any passage
containing a year.

Decision: treat each with a deterministic, testable rule, and preserve the first
attempt at the relevance rule as a measured failure rather than quietly
replacing it.

Consequences:

- `NewsRelevance` keeps a result only when it shares an adjacent phrase from the
  question, two of its content terms, or one distinctive term, and refuses to
  starve a run: if it would drop everything it keeps everything and says so. The
  first version kept anything sharing a single term and measured **zero** drops
  on a live run, because the question contains `month` and `act`. Both the rule
  and its failed predecessor are in the tests.
- `NewsClaimDepth` reports how many accepted claims a second independent voice
  carries, and the News brief leads with it. The honest sentence is "Thin claim
  set: none of the 7 claims is carried by a second independent voice", not the
  domain count that used to imply confirmation.
- `DimensionLexicon` matches whole words, separates strong from weak terms, and
  requires one strong term or two weak ones. A year is not timeline evidence and
  one "however" is not a gap.
- Two fields were computed and then dropped on the way into the report: the
  contradiction scan, and the claim depth. The contrast panel therefore could
  not have rendered for any run, and the M007.2 note that it "stays empty" was
  true for the wrong reason. Both are passed now, with a test for the pair the
  fixture produces and a live run for the render.
- `swift test`: **315 tests, 0 failures**. Evidence:
  `docs/evidence/M009/m0093-defects-and-redesign.md`.

## D048 - The workspace is rebuilt against the product's own mockup, with no invented verdicts

Context: `docs/design/local-lens-living-research-map.png` is the layout
PRODUCT.md selects, and the shipped surface had drifted from it into a scaffold:
tracked-out all-caps labels on every section, `·`-joined counters, monospaced
micro-text, and a single-line question field that lost its edges in a crowded
row so a long question appeared cut off at both ends.

Decision: rebuild the surface on a small design system, follow the mockup's
structure, and refuse the one thing the mockup shows that this product cannot
honestly produce.

Consequences:

- `Sources/LocalLensApp/DesignSystem.swift` holds the tokens: semantic system
  surfaces (so light and dark both work), one accent for evidence, two semantic
  flags, sentence case, monospaced digits only where numbers align, one card
  radius with hairline borders.
- The question field grows from one to six lines with a visible boundary and its
  own clear button; the mode and status controls moved to a second row so
  neither can squeeze the other.
- The mockup's `Excellent / Good / Fair` verdicts are **not** reproduced: the
  product has no basis for them, so a comparison cell reports the measured
  count of stored passages that satisfy the criterion and mention that side. The
  first implementation of that table counted a passage whenever it matched the
  criterion and produced `211 matches` for a side it never checked; the rule is
  now stated in the view and tested by the numbers it renders.
- The surface adapts: below 1080 points the evidence column becomes a sheet, and
  the window opens at a size the layout is designed for.
- The idle screen no longer claims a key is missing. The keychain is read only
  when a run starts or the panel is opened, so the old sentence asserted a state
  the app had not checked.
- Not proven: that the redesign is better for a person using it. That is a human
  judgement, and no measurement here claims it.

## D049 - Present one product workspace and label evidence honestly

Context: an every-screen Mac audit found two additional Research-menu windows:
an old Quick-only live prototype and a synthetic offline fixture. Their
presence made it look like Local Lens had three competing interfaces. The audit
also found stale answer state, unconfirmed bulk history deletion, privacy copy
that hid hosted passage sharing, and a citation seal that implied factual
verification.

Decision: the default four-mode Living Research Map is the sole normal product
window. Remove both historical windows from the Research menu, retaining their
internal scenes and the unchanged M001 fixture for deterministic regression
evidence. Reset visible answers when the question changes, confirm destructive
history deletion, refuse an empty custom plan, and describe a citation as a
link to stored source text rather than independent truth verification. Preserve
the saved answer bytes while improving display-only paragraph breaks.

Consequence: UI confusion is reduced without claiming improved answer quality.
The News single-source allegation observed in a saved replay remains unverified;
it is not a suitable verified-news demo. Evidence and limits:
`docs/evidence/M009/m0094-ui-closeout-audit.md`.
