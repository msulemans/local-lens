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

## D027 - The native app renders the deterministic Quick pipeline

Context: M003.1 through M003.3 are core-only. The app still rendered only the
M001 deterministic fixture, so UI verification could not exercise the new
retrieval and citation boundaries at all. M003.4 has to surface them without
changing the M001 view or introducing a model.

Decision: the app selects its view from `LOCAL_LENS_START_VIEW`. The default is
the unchanged M001 `FixtureRunView`; `map` is its map view; `quick` is a new
`QuickRunView`; `quick-map` is the Quick map view.

Rules:

- `QuickRunView` loads `Fixtures/retrieval/quick-view.json` through the new
  `QuickCorpus` loader, builds a real `SnapshotStore` and `LexicalIndex` from its
  documents through the M002.4, M002.5, and M003.1 boundaries, runs
  `QuickPipeline.run`, persists the result under `quick-run`, and renders
  citations, the evidence map, and the exact-passage inspector.
- The shared rendering lives in `RunScaffold` and `RunDetailView`.
  `FixtureRunView`'s fixture, persisted run id, loading path, and rendered
  output are unchanged, and a post-refactor capture proves it.
- `QuickCorpus` is strict-decoded core data. Loading it reads one JSON file and
  nothing else, and `makeIndexedStore()` is the only way it produces evidence.
- The Quick view is a deterministic demo: no model, network, DNS, Docker, or
  real clock.

Consequences:

- The app now exercises the M003 boundaries end to end, so a window capture is
  evidence about retrieval and citation rendering rather than only a launch
  check.
- The app refactor is covered by a re-captured M001 view and by the unchanged
  core tests.
- A model-backed Quick mode, history, the global launcher, onboarding, and
  packaging remain later M003 tasks.

## D028 - Freeze infrastructure and ship the live Quick slice

Context: a product review found that the foundations are real and tested (192
deterministic tests, `make gate` green, safe acquisition through retrieval,
citation compilation, and a native Quick view) but that no real cited answer has
been produced, and that the sibling licence has been blocked since M001 while a
parallel native Swift core was rebuilt.

Decision: freeze new infrastructure. No new protocol, refusal family, agent
framework, reranker, vector store, or abstraction is added unless the live slice
cannot be built without it. The sole next task is the live Quick vertical slice:

```text
one real question
  -> at most 2 searches
  -> at most 6 safe parallel fetches
  -> at most 12 retrieved passages
  -> one selected provider
  -> a concise answer
  -> exact citations
  -> the native Quick UI
```

It is evaluated on five representative questions with time to first evidence,
total latency, answer usefulness, citation validity, citation completeness, peak
memory, provider cost, and failure behavior. It closes with one explicit
architecture decision: resolve the sibling licence and extract its remaining
useful pieces, or formally choose the native Swift core and stop describing the
sibling as the planned foundation.

Rules:

- The live slice is a separate binary. No default or gated test run may reach
  the network, and the offline guards and frozen M001 evidence remain unchanged.
- A provider may be called only after its `docs/MODEL_POLICY.md` experiment
  record is filled. No candidate is currently eligible.
- No silent hosted fallback: the provider is chosen, labelled, and recorded.

Blocker, recorded rather than worked around: this environment has no search
endpoint (no SearXNG or search API listening) and no answer provider (no API key,
no local model, and no filled experiment record), so no real cited answer can be
produced until the owner chooses a search endpoint and exactly one provider, or
approves a specific local model path.
