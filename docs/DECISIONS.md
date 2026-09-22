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
