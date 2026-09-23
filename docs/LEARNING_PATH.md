# Learning Path

The learning surface is part of the product and must evolve with each
milestone. Static explanations that do not reflect current code are failures.

## Learning loop

Every milestone follows:

```text
mental model
  -> prediction
  -> smallest implementation
  -> exact verification command
  -> observed evidence
  -> explain-back
  -> gate decision
  -> canonical state update
```

## M001 - Trustworthy state

Learn:

- why prompts cannot own application state;
- value types, actors, cancellation, and explicit terminal states;
- stable serialization, IDs, and content hashes;
- protocols and fake adapters; and
- why a deterministic fixture is a scientific control.

Explain back:

1. Why can the model not choose a citation ID?
2. What makes a run reproducible?
3. Why is cancellation a state transition rather than a UI detail?
4. What does the deterministic fixture prove, and what does it not prove?

## M002 - The hostile web

Learn:

- metasearch versus a web index;
- DNS/IP safety and SSRF;
- HTTP redirects, MIME, compression, and timeouts;
- robots and ethical acquisition;
- extraction loss; and
- why snippets are not evidence.

Explain back:

1. Why must every redirect destination be validated?
2. Why can a search result be relevant but unusable as evidence?
3. When should browser rendering be permitted?
4. What information must a snapshot preserve?

Practised in M002.1:

- why a search adapter must not own a socket, and what injecting the transport
  buys a test suite;
- which provider conditions are faults (transport, status, malformed payload)
  and which is an honest outcome (`.noResults`);
- why hit identity is content-derived rather than positional; and
- why provider payloads are decoded tolerantly at the edges but validated
  strictly wherever the adapter actually consumes a field.

Practised in M002.2:

- SSRF: why a *name* is not a destination and why the address it resolves to is
  the thing that must be approved;
- why every redirect hop is re-validated, and why following redirects inside
  the HTTP client would make that impossible;
- why "partially private" must be read as private: one private answer among
  several public ones is still a private destination;
- why equivalent address encodings (`127.1`, `2130706433`, `0x7f.0.0.1`,
  `0177.0.0.1`, `::ffff:127.0.0.1`, NAT64 and 6to4 forms) have to be normalized
  before classification, because a blocklist that only matches text is a
  blocklist that can be spelled around;
- why refusals are typed per class rather than one "unsafe URL" error; and
- why a frozen JSON decision table beats scattered assertions for a security
  matrix.

Practised in M002.3:

- why "we could not read the policy" is not the same as "there is no policy",
  and why only one of those may be treated as permission;
- why robots group selection is a longest-prefix match on the product token
  while path matching is a longest-match wildcard match, and why `Allow` wins an
  equal-length tie;
- why politeness belongs on a per-host gate rather than a global limiter, and
  why the interval is measured between request *starts* (what the origin sees)
  rather than completions;
- why a politeness gate must be released on throw and on cancellation, or one
  failed request wedges a host forever;
- why a nested acquisition of the same gate deadlocks, which is why the robots
  fetch itself is not gated;
- why the clock is injected: a test that sleeps to prove a delay is a slow,
  flaky test, while a test that records requested intervals is fast and exact;
  and
- why a cache keyed by origin rather than by user agent is the correct key,
  because the agent chooses a group inside the file.

Practised in M002.4:

- why a refusal family is a set of facts rather than one error, and why the
  order in which those facts are established is part of the contract (a PDF over
  the ceiling is still a PDF);
- why extraction is a pure function of already-approved bytes, and how a guard
  test turns "no I/O" from an intention into a property;
- why content-addressed identity has to reuse the existing part ordering
  instead of inventing a second scheme: two identity schemes for the same
  snapshot is how citations start lying;
- why the transport's declared character set outranks the document's own
  declaration, and why `charset` must be matched as a token so `charsetless`
  cannot decide an encoding;
- why entity resolution must happen before whitespace collapse, so `&nbsp;`
  becomes a space while `&amp;nbsp;` stays the text a reader sees;
- why heading context is attribution carried forward rather than decoration,
  and why an empty heading is not a heading change; and
- why a known loss (whitespace inside `<pre>`) belongs in the fixture table as a
  recorded case instead of a footnote.

Practised in M002.5:

- why deduplication keys on content hash rather than on URL, so redirect
  chains, aliases, and retry order cannot create two snapshots of one page;
- why a duplicate updates counters but never rewrites an identity that has
  already been cited, and what would break if it did;
- why every offer is counted even when it stores nothing, so a redirect loop
  or a shared CDN body is visible in the record instead of invisible;
- why the store re-derives snapshot and passage identity from source id,
  content hash, ordinals, and text digests rather than trusting the caller;
- why a hit resolves only through URLs that were actually acquired, making
  "a snippet is never evidence" a property of the code rather than a promise;
  and
- why an actor is the right shape here: bounded parallel fetch will offer
  pages at the same time, and the concurrency test requires that simultaneous
  offers of the same bytes store exactly one snapshot.

Practised in M002.6:

- why the returned order is re-sorted by the caller's index instead of by
  completion, and what two runs of the same batch would otherwise disagree on;
- why a concurrency bound belongs inside the scheduler rather than in the
  caller's loop, and why the limiter resumes waiters in arrival order;
- why "at most one request per host at a time" is enforced by the host gate
  rather than by a number the caller supplies, and why a number that cannot
  bind must still be proven not to loosen politeness;
- why the robots check and the request it governs share one turn of the gate,
  and how a separately-taken gate would defeat a published `crawl-delay`;
- why only `timeout` and `transport_failure` are retried, and why a status
  code, a refused address, a robots rule, and an unreadable document are
  answers rather than faults;
- why an attempt number travels into the store, so a retry produces one
  snapshot whose record names the attempt that actually produced the bytes;
- why parallelism has to be *measured* rather than inferred from timing, and
  how a stub transport can hold requests until N are in flight together; and
- why the one thing a parallel batch cannot decide deterministically - which
  of two identical offers stores the bytes - is recorded as such in the fixture
  rather than asserted positionally.

Practised in M002.7:

- why a diagnostic must be *derived* from the run rather than written next to
  it, and how one `switch` over a single pipeline makes "the reason you were
  given" and "the error that was thrown" the same fact;
- why an exhaustive switch over a refusal family is a design constraint rather
  than a formality: a new refusal case cannot compile until someone decides
  which boundary owns it;
- why a run that never decoded must report `undecided` for the encoding it
  asked for, and why the requested encoding belongs in the reason instead;
- why `runs_dropped` counts a run that began inside a prose element and not the
  newline between two block tags, and what a counter that tracks indentation
  would be measuring instead;
- why a fingerprint taken only over counts identifies a document's shape rather
  than the document, and why the digest of the decoded characters is the
  smallest fact that closes that gap;
- why a fact that is always false - a truncation flag on a boundary that
  refuses instead of truncating - is decoration rather than evidence;
- why a frozen serialized order with the fingerprint last lets a reader verify
  a record without trusting the writer; and
- why three red runs were fixed by making the implementation stronger (a
  prose-depth rule, a content digest, a single undecided gate) rather than by
  relaxing the assertion that caught them.

Practised in M002.8:

- why the honest answer to "prove this on real pages" was a gate rather than a
  fetch, and why an offline test that reached the network once would be worse
  than no test at all;
- why an unapproved entry refuses the whole manifest instead of being skipped,
  and what a skip would let a run report: a pass over a corpus it never ran;
- why an empty manifest is a valid document and a refused plan - the difference
  between "this is not a corpus" and "no corpus is approved yet";
- why an approval needs both a name and a record, and why half an approval is
  not an approval;
- why the expectation vocabulary is borrowed from the frozen `FetchStage`
  rather than duplicated, so an expectation and an observation cannot disagree
  about what a boundary is called;
- why a mismatch reason names both shapes in the vocabulary's own terms, so a
  failure is greppable rather than prose; and
- why a blocker recorded in the artifact and the state file is a result, while
  a claimed pass over a corpus that does not exist is not.

## M003 - Retrieval and local generation

Learn:

- BM25 and term saturation;
- source-quality features versus truth;
- context budgeting;
- structured generation and streaming;
- Apple Silicon memory behavior; and
- latency decomposition.

Explain back:

1. When can BM25 beat embeddings?
2. Why is time to first useful output different from completion latency?
3. What work belongs in deterministic code instead of a model?
4. What evidence justifies changing the default model?

## M004 - Measured reranking

This lesson exists only if M004 entry criteria are met.

Learn:

- bi-encoder, cross-encoder, late-interaction, and listwise ranking;
- recall versus precision at a context cutoff;
- calibration and domain drift; and
- when added model complexity harms the product.

Explain back:

1. Which observed retrieval errors triggered the experiment?
2. What is the baseline?
3. Did the reranker improve the downstream answer or only its own metric?
4. What latency and packaging cost did it add?

## M005 - Scholarly evidence

Learn:

- DOI identity and versioning;
- preprint, accepted manuscript, and version of record;
- citation graphs versus relevance;
- primary and secondary evidence; and
- PDF structure and extraction limits.

## M006 - Temporal evidence

Learn:

- publication time versus event time;
- syndication and source independence;
- breaking-news uncertainty;
- corrections and meaningful updates; and
- time-aware claims.

## M007 - Bounded research

Learn:

- question decomposition;
- coverage matrices;
- contradiction versus qualifier mismatch;
- evidence-gain stopping rules;
- pause/resume and idempotency; and
- why more searches can make an answer worse.

## M008 - Evaluation

Learn:

- validity versus entailment;
- citation precision versus completeness;
- human disagreement;
- evaluator calibration;
- sealed tests and contamination;
- corruption testing; and
- why one aggregate score is misleading.

## In-product `Learn this run`

For a completed run, learning mode shows:

1. original question and mode policy;
2. query rewrites and their intended coverage;
3. search hits versus opened evidence;
4. extraction failures and duplicates;
5. retrieved passages and ranking rationale;
6. claims and evidence relationships;
7. rejected unsupported draft content;
8. termination reason; and
9. one explain-back prompt based on that run.

The view consumes the same typed events as the application. It does not invent
a parallel story about what happened.
