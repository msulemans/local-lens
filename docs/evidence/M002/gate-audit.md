# M002 Gate Audit

Captured: 2026-09-23 (Australia/Sydney)

Scope: the Milestone 002 gate from `docs/MILESTONES.md`, each item with the
fixture and test that supports it. Rule: an item is PASS only with recorded
evidence; anything else is OPEN or BLOCKED with a named reason.

| # | Gate item | Recorded evidence | Status |
|---|-----------|-------------------|--------|
| 1 | Static HTML, redirects, PDF, duplicates, blocked paths, oversized content, invalid MIME, private addresses, timeouts, and extraction failures all produce expected typed outcomes | `Fixtures/fetch/schedule-scenarios.json` freezes seven refusal kinds across ten cases (`private_address`, `http_status`, `timeout`, `unsupported_content_type`, `no_readable_text`, `published_rule`, `fail_closed`); `Fixtures/html/diagnostic-scenarios.json` freezes one refusal per stage that can refuse (`charset`, `content_type`, `markup`, `size`, `source_identifier`, `text`); `Fixtures/acquisition/safe-fetch-scenarios.json` covers redirects, PDF as `unsupported_content_type`, blocked paths, oversized content, invalid MIME, private addresses and timeouts; `Fixtures/snapshots/store-scenarios.json` covers duplicates | PASS for every non-live input |
| 2 | Search snippets never become evidence | `SnapshotStore` stores bytes from an acquisition, never a snippet; hit resolution returns a stored snapshot | PASS |
| 3 | Retries do not duplicate snapshots | `testATransientTimeoutIsRetriedAndTheRetryIsVisible`, `testIdenticalBytesFromTwoHostsAreOneSnapshot`, and the store's attempt-keyed deduplication | PASS |
| 4 | The deterministic M001 slice remains unchanged | The M001 slice is part of the 155-test suite; no M002 task touched it | PASS |

## Blocked

| Item | Status | Disposition |
|------|--------|-------------|
| Live corpus execution (the live portion of item 1) | BLOCKED | No page licence and no owner approval is recorded, so no live page may be fetched. `Fixtures/corpus/live-corpus.json` ships empty and the harness refuses to run; the blocker is recorded in `LOCAL_BROWSER_STATE.md` and in `docs/REUSE_PROVENANCE.md` (D011, D023). The claim is not made rather than worked around. |

## Visual evidence

`app-m002-corpus-gate.png` is a window-only capture of the running app on
2026-09-23. M002.4 through M002.8 are backend-only and change no UI; the
capture exists to show the app still launches and renders after the milestone,
and it was read back with the kit OCR tool, which recovered `LocalLensApp`,
`Local Lens`, `Quick • complete • 3 citations`, `Citations`, `Map`,
`Exact saved passage • text hash 4790bbd37344...`, and the source URL
`https://example.invalid/brew-review` (the OCR pass misread the reserved
`.invalid` TLD as `Invalld`; the vision probe confirmed the layout, the claim
list, and the selected source's passage). No unverified visual claim is made:
M002 changed no pixels by design.
