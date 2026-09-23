# M003 Runtime and UI Check

Captured: 2026-09-23 (Australia/Sydney)

Scope: M003.1, M003.2, and M003.3 are core-only boundaries. Their forbidden
scope excluded UI work, so the running app does not yet call the lexical index,
the citation compiler, or the deterministic Quick pipeline. This check proves
the app still builds, launches, loads its persisted M001 run, and renders both
main views after the M003 core work. It does **not** claim that the M003
boundaries are exercised by the UI; that requires the M003.4 wiring task.

## Commands

```text
$ swift build
$ .build/debug/LocalLensApp                            # default Citations view
$ LOCAL_LENS_START_VIEW=map .build/debug/LocalLensApp  # Map view
$ swift /tmp/getwin.swift                              # CGWindowList -> window id
$ screencapture -l <window id> -o -x docs/evidence/M003/<name>.png
```

The agent process needed Screen Recording permission, which was granted for this
check; before the grant, `screencapture` failed with `could not create image
from display` and `System Events` failed with `not allowed assistive access`.

## Observed

- `app-m003-core-boundaries.png` (default Citations view): `Local Lens`,
  `Does cold brew contain less acid than hot drip coffee?`,
  `Quick · complete · 3 citations`, the fixture summary, the Citations/Map
  selector, the three claim rows (`Acidity`, `Taste`, `Chemistry`), and the
  inspector for the selected Acidity claim showing
  `Acidity in brewed coffee (synthetic test source)`,
  `Local Lens synthetic corpus · https://example.invalid/brew-review`,
  `Acidity measurements`, the exact passage text, and
  `Exact saved passage · text hash 4790bbd37344…`.
- `app-m003-map.png` (Map view, `LOCAL_LENS_START_VIEW=map`): the same three
  claims as map cards with `supports` badges and source rows, the
  colour-plus-text relation legend (`3 claims · 3 sources · relations shown as
  colour and text`), and the same exact-passage inspector.
- Both launches stayed alive with an empty stderr log, and the persisted run at
  `~/Library/Application Support/LocalLens/runs/fixture-run.json` decoded as
  `complete` with 3 citations, 4 passages, and 11 events.

## Blocker and disposition

The M003 core boundaries are now reachable from the app: M003.4 added the Quick
view (below). Screen Recording and Accessibility remain denied to automated
processes by default, so captures require an explicit grant; `screencapture`
failed with `could not create image from display` before the grant and succeeded
after.

## M003.4 Quick view captures

M003.4 wires the M003.3 pipeline into the app. `LOCAL_LENS_START_VIEW=quick`
runs `Fixtures/retrieval/quick-view.json` through a real `SnapshotStore` and
`LexicalIndex` and `QuickPipeline.run`, persists the run under `quick-run`, and
renders retrieval-backed citations and the evidence map through the same
exact-passage inspector as M001.

- `app-m003-quick-citations.png` (Quick, Citations): `What makes good
espresso?`, `Quick · complete · 3 citations`,
`Deterministic Quick run: 3 claims resolved to 3 sources.`, the claim rows
`Brewing`/`Water`/`Pressure`, and the inspector for the Brewing claim showing
`Espresso Brewing`, `Example Coffee · https://espresso.example.invalid/guide`,
the exact passage text, and `Exact saved passage · text hash 9ee19e726c5e…`.
- `app-m003-quick-map.png` (Quick, Map, `LOCAL_LENS_START_VIEW=quick-map`): the
same three claims as map cards with `supports` badges and source rows
(`Espresso Brewing`, `Water Quality`, `Pressure`), the colour-plus-text legend,
and the same inspector.
- `app-m003-m001-recheck.png` (M001 default view after the app refactor): the
original `Does cold brew contain less acid than hot drip coffee?` slice with
`Fixture synthesis: 3 claims resolved to 3 synthetic sources.` and text hash
`4790bbd37344…`, byte-for-byte layout unchanged. The refactor extracted the
shared scaffold without changing the M001 rendering.
- The persisted artifact at
`~/Library/Application Support/LocalLens/runs/quick-run.json` was written on the
first Quick launch and decoded as `complete` with 3 citations.
