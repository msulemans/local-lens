# M003.6 development app and retrieval QA

Date: 2026-09-25 AEST. Scope: M003.6 Mac product surface and a bounded,
retrieval-only diagnostic. No paid provider request or five-question card rerun.

## Development bundle

`make app` built `dist/Local Lens.app` from the release product, copied the
two bundled fixtures, and ad-hoc signed it. `codesign --verify --deep --strict`
and `plutil -lint` both exited 0. The ignored bundle was about 2.9 MB. This
proves a local development launch artifact, **not** notarization, distribution,
or reproduction on a second machine.

The app was selected in computer use from its `dist` path. The default window
rendered the offline M001 fixture from bundle resources. The Research menu
showed **New live question**, which opened the live Quick window. Visual
inspection showed the question field, hosted badge, answer area, persistent
evidence rail, and Connection disclosure. Opening Connection showed the search
endpoint, one-source URL field, secure key field, and explicit Keychain save
button. Submitting a question with no key displayed the missing-key state;
entering `not-a-url` displayed the HTTP(S) URL validation state before key
checking. Neither interaction issued a provider request. Computer-use images
were inspected during the session but not saved as repository artifacts, so
this is an interaction report, not a reproducible screenshot comparison.

## Retrieval-only failures preserved

The diagnostic command used `LocalLensLive --mode retrieve --source-url URL`
with the question `How does Swift cancel a task group?`. This path bypasses
SearXNG discovery but still applies the normal bounded fetch, extraction,
stored-passage retrieval, and citation eligibility rules. It does not call the
hosted provider.

| Page | Observed result | Diagnosis limit |
| --- | --- | --- |
| `https://docs.swift.org/latest/documentation/swift/taskgroup/` | `retrieve_stopped: abstained(reason: "no readable evidence")`, exit 1 | HTTP response was a small HTML shell with a JavaScript entry point; the current HTML extractor did not obtain documentation text. |
| `https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html` | `opened_sources=1`, `passages=0`, exit 0; dump contained only “This content has moved; redirecting to the new location.” | The fetched page used an HTML meta refresh, not an HTTP redirect. The fetched text was not answer evidence. |
| `https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/TaskGroup.swift` | `opened_sources=1`, `passages=0`, exit 0 | No passage matched this question. Cause was not isolated; do not infer that GitHub source is unreadable. |

These failures were observed before any further treatment. They do not justify
claiming that the app can answer this question, and search-result snippets were
not substituted as evidence. No source page body is committed. A future
treatment needs its own diagnosis and the frozen benchmark must stay unchanged.

## Proof boundary and next action

Local UI launch and two error interactions: verified. Development bundle:
verified locally. Supported in-app answer, five-question quality comparison,
SearXNG recovery, general no-Docker search, distribution, and second-machine
reproduction: unverified. Before any paid rerun, reconcile prior calls and
record a distinct bounded M003.6 experiment. Then perform a controlled in-app
cited-answer run and the unchanged benchmark if search and readable sources
are available.

## Later same-day treatment and one-call result

The frozen direct-page question was re-run in retrieval-only mode against a
readable Swift forum page. It first selected one question-shaped passage.
Allowing up to twelve passages from a single opened source brought an
answer-bearing reply into the selected set; excluding paragraphs that end in
a question reduced the selected set to six, still including the cooperative
cancellation explanation. No search snippet was used.

A distinct one-call M003.6 experiment was recorded in
`m0036-provider-experiment.md` before a native-app run. The app reached the
provider, but the compiler refused an ambiguous quote duplicated in two
stored forum passages. It showed no answer. The single call is spent. The
runner now isolates ambiguous claims and can preserve independently cited
claims; its regression test passes. The new treatment has **not** been verified
with a further provider call.

## Provider-free Mac page inspection

The live Quick window gained **Inspect page without AI** when a question and
one page URL are entered. It calls the same bounded fetch, storage, and
lexical retrieval path but never constructs an answer request or calls
DeepSeek. It labels the result as saved passages, not citations or an answer,
and shows the full selected passage and fetched-page link in the evidence
rail. A supplied page now works even if the search endpoint field is invalid,
because no search endpoint is needed on that path.

Visual and interaction QA on the rebuilt development bundle: with no key in
the secure field, the public Swift forum URL produced **6 matching passages
from 1 opened page**. The list contained the cooperative-cancellation reply;
the rail displayed the selected saved text and an **Open fetched page** link.
The layout was visually inspected in computer use. Its first saved passage
was a low-relevance documentation suggestion, so passage ordering is still
not a useful-answer quality proof. The screenshot was not persisted. The
header badge was then corrected from the misleading hosted label to
**LOCAL · NO AI** in preview state. A fresh computer-use visual check confirmed
the local badge, six saved passages, and evidence rail. The image remains in
the tool session only; no screenshot file was persisted in the repository.

The subsequent separately budgeted post-fix hosted verification reached the
provider but stopped with `emptyAnswer`, not a citation result. Its one-call
budget is also spent; see `m0036-provider-verification-2.md`. No third paid
attempt was made. This does not change the six-passage no-AI inspection proof.
