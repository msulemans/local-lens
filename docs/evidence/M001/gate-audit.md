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
| 4 | Every citation opens the exact saved passage | `testEveryCitationResolvesToExactPassageAndQuote`, `testInspectionsResolveEveryCitationToPassageAndSource`, `testMapNodeSelectionResolvesToTheSamePassageAsInspection`; window screenshot `app-first-run.png` shows the default-selected citation's exact passage, source, and text hash | PASS (unit, view-model, and visual for the default selection; pointer interaction not automated) |
| 5 | Unknown fields and illegal state transitions fail closed | `testUnknownFixtureFieldFailsClosed`, `testPersistedRunRejectsUnknownFields`, `testCommandUnknownFieldFailsClosed`, `testUnsupportedVersionFailsClosed`, `testUnknownCommandFailsClosed`, `testIllegalTransitionFailsClosed`, `testGenericTransitionCannotReachStopStates` | PASS |
| 6 | Cancelling reaches a terminal `cancelled` state | `testCancellationIsTerminal` | PASS |
| 7 | Restarting the application preserves the completed run | Store round-trip test; smoke run persisted `fixture-run.json` (status `complete`, 3 citations, 4 passages, 11 events); a second launch left mtime and size unchanged (`Sep 22 21:18:45`, 7497 bytes), proving the app loaded the run instead of rewriting it | PASS at store/smoke level; in-window GUI state not visually inspected |
| 8 | Observed commands and results are appended to the canonical record | `LOCAL_BROWSER_STATE.md` entries for M001.1 through M001.5 | PASS |

## Open items before M001 can be declared complete

| Item | Status | Reason and next action |
|------|--------|------------------------|
| Sibling `ResearchCore` extraction | BLOCKED | No licence file in the sibling (D011). The clean-room native slice exists; extraction resumes only after the licence gate clears. |
| UI automation tests | OPEN | No UI test target exists; choosing XCUITest versus a documented alternative is a tooling decision (M001.6). |
| Full Living Research Map design | PARTIAL | M001.5 delivers the minimal map (claim nodes, relation badges, source attribution, selection into the passage inspector); the full design concept remains later-milestone scope. |
| GUI visual and interaction verification | PARTIAL | The initial window render and default citation selection are visually verified (`docs/evidence/M001/app-first-run.png`): question, mode and status line, citation list, and the exact-passage inspector all render. Clicking other rows, switching to the Map segment, and other interactions are not automated. |

## Declaration

M001 is **not yet declared complete**. Gate items 1-8 pass with recorded
evidence. The named open items require the M001.6 close-out decisions before
any completion claim is made.
