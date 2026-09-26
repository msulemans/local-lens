# M003.6 Mac product surface — implementation checkpoint

Date: 2026-09-25 AEST. Scope: the existing M003 live Quick flow, not a new
mode, model, search provider, or retrieval architecture.

The Mac app now has a **Research → New live question** command
(Shift-Command-N). Its live window accepts a question and runs the existing
planner → SearXNG search → bounded safe fetch → stored-passage retrieval →
hosted DeepSeek proposal → citation compilation path. `LOCAL_LENS_START_VIEW=live`
is an alternate development entry point; the default launch still shows the
offline fixture. Merely opening the window makes no network or provider call.

The surface distinguishes a running search, a supported answer, and an
abstention/failure. It labels the result HOSTED and renders only claims accepted
by the existing trust and citation boundaries. Selecting a numbered citation
shows the full saved passage, the exact cited quote, passage id, snapshot id, and a link to the fetched
source URL. The connection panel
exposes the SearXNG endpoint and lets a person save the DeepSeek key explicitly
in macOS Keychain; the key is not written into answer artifacts or defaults.

As a no-search-server path, the user may paste one source URL. It produces only
a discovery hit with an empty snippet, then uses the same bounded safe fetch,
storage, retrieval, and citation path. It is useful for researching a known
page, not a replacement for multi-source web search; source independence is not
claimed. The URL must be HTTP(S) without embedded credentials. The safe-fetch
policy still rejects private or otherwise forbidden destinations.
The same supplied-page path has an **Inspect page without AI** action. It
opens and displays matching stored passages in the Mac workspace without a
provider key or model call. The result is explicitly a source preview, not a
generated answer or a compiled citation.

Design direction: an editor-like evidence workspace, with a restrained paper,
ink, and sea-glass palette. The single visual signature is the persistent
evidence rail beside the answer; it encodes the product's proof contract rather
than decorating a generic chat pane.

## Verification and proof boundary

```text
swift build -> exit 0
make gate   -> exit 0; 229 tests, 0 failures; offline guards unchanged
make app    -> exit 0; development .app built and ad-hoc signed
codesign --verify --deep --strict "dist/Local Lens.app" -> exit 0
plutil -lint "dist/Local Lens.app/Contents/Info.plist" -> exit 0
```

Three new deterministic tests cover the direct-page hit contract, invalid URL
rejection, and an end-to-end fake-page answer whose citation resolves to the
stored passage and fetched URL. The bundled app was opened and visually inspected
with computer use: the default M001 fixture rendered from bundle resources;
Research → New live question opened the two-column live workspace; Connection
exposed the endpoint, one-page URL, Keychain field, and hosted disclosure. The
ask interaction produced a missing-key state without a provider call. A malformed
page URL was rejected before key checking. These are UI interaction proofs, not
a successful network answer. The inspection has no persisted screenshot file;
see `m0036-dev-app-qa.md` for the exact observations and retrieval diagnostics.
No provider call, live cited answer, or frozen five-question comparison was made
in this checkpoint. The earlier
M003.5 card remains the baseline. Current SearXNG recovery is unknown. A new
bounded M003.6 provider experiment must be recorded before paid reruns; the
M003.5 20-call ceiling must not be silently reused. A later distinct one-call
experiment was recorded and spent on an in-app attempt that failed with an
ambiguous citation; see `m0036-provider-experiment.md`. The subsequent
deterministic treatment was followed by a second, separately budgeted call,
which stopped at provider `emptyAnswer` before citation compilation; see
`m0036-provider-verification-2.md`. Neither call produced an in-app cited
answer, and both one-call budgets are spent.

Normal-user gaps remain: a distributable/notarized `.app` reproduced on another
Mac, no-Docker *general web search* path, history, and successful live quality proof. This
checkpoint does not call Quick finished.
