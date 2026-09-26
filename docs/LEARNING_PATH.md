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

Practised in M003.1:

- why a retrieval index is a *derived* artifact and the snapshot store stays the
  source of truth, so the index can be rebuilt without redefining any cited
  identity;
- why `bm25()` is best-first when ascending and why the heading and body weights
  are policy data rather than constants in the query text;
- why a tie must be broken by a recorded rule applied in both SQL and the
  selection pass, instead of trusting SQLite's row order;
- why diversity is a source feature and a bound at once, and why a per-source cap
  changes which passages survive without changing the ranking;
- why "no readable snippet field" is a type-level guarantee that a search hit
  can never become evidence, and why `resolve(_:)` re-derives the stored row;
- why a result limit above the policy maximum is a refusal rather than a silent
  cap, and why the candidate ceiling is bound as a 64-bit integer;
- why the fixture feeds real extraction and storage output into the index rather
  than hand-authored rows, so a green test proves the composition and not a
  mock; and
- why an FTS5 probe is a prerequisite: a missing module must produce
  `unavailable`, not a scan that was never measured.

Practised in M003.2:

- why a citation compiler is a *composition* boundary: it owns the retrieval
  call, the exact-quote test, and the identity derivation, but it opens no
  socket and reads no page, so the only evidence it can produce is a passage the
  index already stored;
- why the claim id is re-derived from the claim's own dimension and text instead
  of trusted, and why a forged id is a refusal rather than a repair;
- why "exactly one distinct passage contains the quote" is the right rule: none
  is missing evidence and more than one is an ambiguous binding that must not be
  chosen silently;
- why an empty quote is refused before retrieval, because the empty string is a
  substring of every passage and would otherwise bind every claim to the first
  hit;
- why a later dangling evidence link must not be allowed to hide behind a valid
  first one, so `resolve(_:)` validates every link, not just the one it returns;
- why a plain `CitationCompilation` value is safer than an opaque object: the
  same `resolve(_:)` path re-checks a hand-built or altered compilation and
  fails closed; and
- why a fixture that feeds real extraction and storage output into a real index
  makes a green test prove the whole deterministic path rather than a mock.

Practised in M003.3:

- why a pipeline is a *composition* boundary: it owns the run state machine's
  phase order and the wiring of retrieval to compilation, but neither boundary
  becomes less strict inside it;
- why a refusal must become a terminal `.failed` status with the refusal kind in
  the stop reason, rather than a completed run with an empty citation;
- why the result should contain only the evidence the compilation cites: a
  citation that cannot resolve to a stored snapshot and a described source is a
  failure, not a silently omitted row;
- why an offline fixture can hold both a completing question and a failing one,
  so the pipeline's two terminal paths are both exercised by data;
- why the same run re-validated through the UI's own resolver and repeated twice
  is stronger evidence than a compiler-only unit test; and
- why the model remains a later, separately gated task: the deterministic half
  of Quick mode can be finished and measured without pretending a model ran.

Practised in M003.4:

- why a core boundary is not verified until a user-facing surface exercises it,
  and why the honest response to "the tests pass" is to load the app and look;
- why view selection belongs in one environment switch (`LOCAL_LENS_START_VIEW`)
  so each rendered state is capturable deterministically;
- why extracting a shared scaffold from a working view should be proved by
  re-capturing the original view, not assumed because the code still compiles;
- why a fixture loader is a boundary too: strict decoding, a single file read,
  and a `makeIndexedStore()` that produces evidence only through the real
  extraction, storage, and lexical paths;
- why the app persists the Quick run under its own id, so the demo is
  reproducible without re-running the pipeline; and
- why a capture that requires an OS permission is still evidence, but the
  permission dependency belongs in the record rather than in an implicit
  assumption.

Practised in M003.6:

- A search result or a user-pasted URL is a discovery target. Neither its
  snippet nor its title is citation evidence; only a safely fetched, stored
  passage can support a claim.
- A known-page path can make the Mac app useful while a metasearch engine is
  unavailable, but one page cannot establish source independence or answer a
  broad web question.
- An exact substring proves a quotation matches stored bytes. It does not
  prove the claim is entailed by the quote. The frozen five-question card must
  still be judged for source relevance and answer usefulness.
- A compiled app screen and offline tests are not an observed live interaction
  or answer-quality result; record these proof levels separately.
- A fetch that returns HTTP 200 is not necessarily readable research content:
  a JavaScript documentation shell or an HTML meta-refresh page can yield no
  answer-bearing stored passages. Diagnose extraction and passage counts before
  spending a provider call; do not fill the gap with search snippets.
- An ad-hoc-signed development `.app` proves a local launch path, not a
  distributable, notarized app or a second-machine reproduction. Likewise,
  exercising a key/URL error state is UI proof, not a cited-answer run.
- A provider can name an exact stored quote that appears in two passages.
  The compiler must refuse that ambiguity; isolate the affected claim so an
  independently unique, cited claim can survive without weakening the
  citation rule. A deterministic regression is not a live quality score.
- A source preview can be useful before synthesis: show the fetched, stored
  passage and URL without implying that it is already an answer or citation.
  This lets someone inspect a public page without an API key while keeping
  the local and hosted paths visibly separate.
- The same query string is not equally good for two consumers. A metasearch
  engine ranks a natural-language question well; an FTS5 index needs short
  strict windows because a long all-term match falls back to chrome. Feeding
  one keyword list to both silently traded away web-search relevance for the
  index's convenience. Measured before changing: search for the natural
  question surfaced the primary/comparison sources, while the four-term window
  split "Grand Central Dispatch" and returned nothing useful.
- A narrow strict retrieval pass that returns one passage is not a two-source
  answer. A ranked any-term fill, appended after the strict hits and filtered
  by the same readability rule, gives the provider a real choice without
  lowering the precision floor.
- A current-build proof is worth more than a loaded artifact: the app's own
  ask path wrote the completed citations. Use an explicit, off-by-default
  environment hook to reproduce it rather than faking keystrokes or capturing
  the user's whole desktop.

Practised in M003.7:

- A free metasearch baseline is an infrastructure dependency with its own
  failure modes. SearXNG's stock `general` engines were all scrape engines that
  soft-block under repeated use, so the fix was not in the app: measure each
  engine, pin a curated set, and record why the rest are off.
- A search engine can serve *stale or unrelated* results while reporting HTTP
  200. Bing-via-SearXNG returned veterinary and StackOverflow-cache pages for a
  SQLite query. An engine returning bytes is not an engine returning answers.
- A licence can rule out an otherwise working endpoint: Bing's RSS output is
  trivially parseable but Microsoft's terms forbid non-aggregator use, so it is
  not a product backend.
- Exact quotes are not truth. The card's false-premise question was answered
  with three exact quotes from one blog that stated the misconception. The
  pipeline endorsed a falsehood with perfect citation integrity.
- Source *type* is a real, deterministic retrieval feature that needs no model:
  opening conventional documentation/forum hosts before personal blogs moved Q1
  to a primary Apple source and removed the Q5 endorsement. It is discovery
  ordering, not a citation rule, and it is not a correctness guarantee.
- Measure the treatment on exactly the cases it can affect. When the full card
  could not reach its threshold anyway, a two-call re-run of the two affected
  questions tested the hypothesis at a fraction of the cost, and the result was
  reported as a projection, not a full card score.

Practised in M003.8:

- Query ambiguity is a retrieval failure, not a model failure: `Swift` meant a
  programming language in Q4 but also matched financial-SWIFT release pages.
  A measured, narrow disambiguation exposed an official dated passage without
  changing the model or the local FTS5 query.
- A source-looking hostname is not ownership proof. `docs.untrusted.net` can
  be a blog; only known project/vendor domains receive the official discovery
  tier now. Even that tier is a preference, not a truth guarantee.
- Readability is weaker than relevance. A body that simply repeats its heading
  must not use a synthesis slot, and a passage about what an ISP can see does
  not answer what a destination website sees. The five fresh retrieval runs
  preserve these misses instead of giving them answer-quality credit.
- Process peak RSS from `/usr/bin/time -l` is useful but only covers that
  short-lived CLI. It is not Mac-app or SearXNG peak memory. Record measured
  scope beside the number and leave first-evidence time unknown until it is
  instrumented.

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

### M003.9 - A free search key is not a free answer, or a citation

Try the current Mac app with a pasted public URL and **Inspect page without
AI**; no key is needed. Then add a free Tavily search key and choose **Find
evidence without AI**. Compare the URL/title/content returned by search with
the text actually fetched and stored from a page. Only the latter may support
an answer citation. A DeepSeek key is separate, and selecting Ask may incur a
hosted inference charge. The Tavily adapter has now run in the Mac app, and
one DeepSeek answer displayed four exact citations; this is not a full
answer-quality benchmark. This exercise should record search credits,
opened-source refusals, selected passages, and any missing evidence before
considering a paid answer-card rerun. Verify the app by driving its own
controls too: the F1 check was re-run through **Find evidence without AI**
under driven UI and reproduced the official first passage
([app check](evidence/M003/m0039-f1-app-check.md)).

The frozen Swift/GCD CPU-work comparison demonstrates that two independent
search queries can find sources on both sides while still selecting generic
passages. Compare the [provider-free Q2 run](evidence/M003/m0039-q2-provider-free.md)
with the older one-query baseline: source discovery, passage relevance, and
answer entailment are separate gates. Do not score retrieval as a good answer.
In the [F1 passage probe](evidence/M003/m0039-f1-passage-probe.md), the
official Python page was fetched on both runs, but only a lexical query using
the source's actual failure wording selected the answer-bearing paragraph.
The [F5 counterclaim probe](evidence/M003/m0039-f5-counterclaim-probe.md)
shows the opposite limit: better query wording cannot create a direct saved
passage when most candidate pages refuse safe acquisition.

### M003 close-out - The refusal was in our code, not the web

- Two questions could not reach Apple or Swift.org primary pages. The refusals
  looked like network or rate-limit problems; instrumenting the acquisition
  boundary showed the app was normalising a trailing slash away and calling an
  ordinary `/page` -> `/page/` redirect a loop. Read the typed refusal before
  blaming the network.
- One identity fix took the unchanged card from 2/10 to 6/10, and reordering
  one lexical query took it to 7/10. Acquisition and query shape dominate
  retrieval quality; a bigger model would not have fixed either.
- A false refusal hides real work: after the redirect fix, extraction (not
  acquisition) became the Apple limiter, because the API reference pages are
  JavaScript-rendered. Fixing one boundary just moves the frontier.
- Keep a canary question untuned. The fifth question was the last
  below-threshold one, but tuning it would have destroyed the only measurement
  that is not fitted to the benchmark. A promotion that needs a tuned canary is
  not a promotion.
- Measure the ceiling that matters: 140 MB peak RSS for the app and 30.8 MB for
  the CLI retrieval path are recorded numbers, not adjectives.

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

### UI trust lesson from M009.4

The live research workspace, legacy Quick prototype, and M001 fixture were all
exposed as app windows. The normal Research menu now exposes only the four-mode
workspace; the other scenes stay internal for deterministic regression. A
citation proves linkage to a saved passage, not that the publisher is correct.
An empty custom plan must stop before search, and editing a question must clear
the answer that belonged to the previous question. See the before/after
screenshots and unresolved answer-quality boundary in
`docs/evidence/M009/m0094-ui-closeout-audit.md`.
