# M009.1 - Release artifact, storage and privacy, diagnostics, demo, and reproduction

Date: 2026-09-26 (Australia/Sydney)
Working tree: uncommitted. Nothing staged or committed.

## Treatments

1. **Release build** (`scripts/build_release.sh`, `make dist`). Builds the
   release app, signs with the best available identity, notarizes only when a
   Developer ID identity *and* a `NOTARY_PROFILE` are present, writes
   `LocalLens-1.0.0.zip`, its SHA-256, and a `BUILD-INFO.json` that states the
   signature and the exact reason when notarization did not happen.
2. **Release checks** (`scripts/verify_release.sh`, `make verify-release`).
   Nine mechanical checks: the bundle exists, the identifier is
   `dev.locallens.app`, the signature verifies, no credential material is
   present, no model weight is present, exactly the two public fixtures are
   bundled, no fetched page or PDF body is bundled, and no key or pem file sits
   under `dist/`.
3. **Storage and privacy panel.** Shows how many runs are saved, how many files
   and how many bytes are on disk, and removes every saved run behind a
   confirmation that says nothing was ever uploaded.
4. **Privacy-safe diagnostics** (`DiagnosticsReport`). Versions, architecture,
   on-disk counts, settings that are not secret (with the local endpoint reduced
   to its host), keychain *presence* as booleans, and typed stop reasons. A test
   asserts that no question, answer, claim, quote, snippet, or credential field
   can appear in the bundle.
5. **First-run card.** Until this Mac has a saved run, the window states the
   three steps: pick a mode, look at Storage & privacy and Connection, then Ask
   or Find evidence.
6. **Reduced motion.** The toolbar reads `accessibilityReduceMotion` so the
   running indicator can drop its animation without losing its text.
7. **Demo and reproduction** (`make demo`, `make reproduce`, `docs/DEMO.md`,
   `docs/REPRODUCE.md`, `CONTRIBUTING.md`). The demo runs the plan, the edited
   plan, the typed refusal, and the corruption test at US$0. `make reproduce`
   refuses to run in a dirty tree, then runs the gate, both validators, the
   release build and checks, and the demo.

## Measured

- `make dist` produced `dist/release/LocalLens-1.0.0.zip` with
  `signature: apple-development`, `notarized: no`, and the recorded reason:
  *no Developer ID Application identity is installed, so notarization is
  impossible on this machine*.
- `make verify-release`: **all nine checks pass**.
- `make demo` with no `TAVILY_API_KEY`: says so, then proves the typed refusal
  (`Quick mode allows at most 1 dimensions; 2 were given.`) and the corruption
  test.
- `swift test`: **299 tests, 0 failures**.

## M009 gate status

| Gate item | Status |
|---|---|
| a new user installs and completes a search from the release artifact | **partially verified**: the artifact builds, verifies, and launches, and the app completes a local search (100% citation integrity on the frozen card); it has not been installed by anyone else |
| a contributor builds and verifies a clean clone using documented commands | **implemented, not demonstrated**: `make reproduce` exists and refuses a dirty tree; no second person has run it |
| no secret, private snapshot, or unlicensed benchmark body is present | **met**: the release checks scan for credentials, weights, and fetched bodies; the frozen card and fixtures are synthetic |
| the public README claims match reproduced evidence | **met in part**: every claim in `README.md` names its evidence file; the machine-checkable ones are checked by the gate |
| licence selection is complete | **blocked on the owner**: `docs/LICENSING.md` records the choice and the one file needed to close it; no licence has been applied |

Notarization is **blocked**, not skipped: only an Apple Development identity is
installed. Second-machine reproduction is **unproven**.

## Second pass, after the storage panel and release script were finished

- Rebuilt the release artifact from the current source:
  `LocalLens-1.0.0.zip`, `signature: apple-development`, `notarized: no`, with
  the same recorded reason. `make verify-release` passed all nine checks again.
- `make reproduce` was run on this tree and **refused**, exactly as designed:
  `refusing: the working tree has uncommitted changes, so a clean clone is not
  what this would test`. The refusal is the honest result here; this repository
  has never been committed, so a clean-clone run cannot be produced from it.
- The live app was observed with the new surfaces: the toolbar shows
  `PLAN · Answer`, and the `Storage & privacy` panel expands to the on-disk
  summary, the fetch-policy sentence, Refresh, Copy diagnostics, and
  Delete every saved run.
- Copy diagnostics pasted a 601-byte bundle from the running app. Its keys are
  `appBuild, appVersion, architecture, generatedAt, operatingSystem,
  protocolVersion, recentFailures, settings, storage`; settings are
  `hasHostedKey, hasSearchKey, localEndpointHost, localModel, mode,
  reasoningEffort, searchBackend, usesLocalProvider`. A scan for question,
  answer, claim, quote, snippet, key, authorization, bearer, secret, password,
  and token markers found **none**. Counts reported: 9 saved runs, 29
  snapshot/passage references, 0 bytes recorded for the historical entries.
