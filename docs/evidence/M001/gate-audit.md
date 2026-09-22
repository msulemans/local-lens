# M001 Gate Audit

Captured: 2026-09-22 (Australia/Sydney)

Scope: the Milestone 001 gate from `LOCAL_BROWSER_STATE.md`, each item with the
command and observed result that supports it.

Rule: an item is PASS only with recorded evidence. Anything else is OPEN (with
a named next action) or BLOCKED (with a named reason).

| # | Gate item | Recorded evidence | Status |
|---|-----------|-------------------|--------|
| 1 | A clean checkout builds with one documented command | `git clone` into a temporary directory, then `make gate`: passes on `386aafd` and again on the M001.5 revision `912b563` (manifest, schema parity, build, 25 tests) | PASS |
| 2 | The fixture runs without network, API keys, Docker, or model weights | `make verify`: the fixture tests read only `Fixtures/deterministic/quick-coffee.json` and perform no network or model I/O | PASS |
| 3 | Two runs produce the same normalized evidence and citation graph | `testFixtureRunsOfflineTwiceWithIdenticalEvidenceAndCitationGraph`: byte-identical sorted JSON plus equal `citationGraphSignature` | PASS |
| 4 | Every citation opens the exact saved passage | `testEveryCitationResolvesToExactPassageAndQuote`, `testInspectionsResolveEveryCitationToPassageAndSource`, `testMapNodeSelectionResolvesToTheSamePassageAsInspection`; window screenshots `app-first-run.png` and `app-map-view.png` show the default-selected citation's exact passage, source, and text hash in both views | PASS (unit, view-model, and visual for the default selection in both views; pointer interaction not automated) |
| 5 | Unknown fields and illegal state transitions fail closed | `testUnknownFixtureFieldFailsClosed`, `testPersistedRunRejectsUnknownFields`, `testCommandUnknownFieldFailsClosed`, `testUnsupportedVersionFailsClosed`, `testUnknownCommandFailsClosed`, `testIllegalTransitionFailsClosed`, `testGenericTransitionCannotReachStopStates` | PASS |
| 6 | Cancelling reaches a terminal `cancelled` state | `testCancellationIsTerminal` | PASS |
| 7 | Restarting the application preserves the completed run | Store round-trip test; smoke run persisted `fixture-run.json` (status `complete`, 3 citations, 4 passages, 11 events); a second launch left mtime and size unchanged (`Sep 22 21:18:45`, 7497 bytes), proving the app loaded the run instead of rewriting it | PASS at store/smoke level; in-window GUI state not visually inspected |
| 8 | Observed commands and results are appended to the canonical record | `LOCAL_BROWSER_STATE.md` entries for M001.1 through M001.5 | PASS |

## Carry-over items (not blocking the M001 declaration)

| Item | Status | Disposition |
|------|--------|-------------|
| Sibling `ResearchCore` extraction | BLOCKED | Licence gate D011; tracked as licence-gated reuse task R1. Not product-blocking: the deterministic slice is clean-room Swift (D015). |
| UI automation tests | DECIDED | Screenshot capture plus view-model tests now; XCUITest deferred to the packaged app (D014). |
| Full Living Research Map design | SCHEDULED | Minimal hierarchy implemented and captured; comparison blocks, provenance ribbons, and recommendation/open-question blocks land in M003 (`docs/design/CONFORMANCE.md`). |
| Pointer interaction testing | PARTIAL | Default selection verified visually in both views; clicking rows and switching views by automation remain manual checks (D014). |

## Declaration

M001 is **declared complete** (D015): gate items 1-8 pass with recorded
evidence, the window render is visually verified in both views, and the
carry-over items above are tracked with named dispositions rather than left
implicit.
