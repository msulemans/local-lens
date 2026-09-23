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

- The M003 core boundaries are not reachable from the app, so a UI check cannot
  verify them yet. Wiring the deterministic Quick pipeline into a second app
  view is the next task (M003.4), after which the captures will show
  retrieval-backed citations rather than the M001 fixture slice.
- Screen Recording and Accessibility are denied to automated processes by
  default. Future UI captures must be run with an explicit grant or use a
  permission-free render path (`ImageRenderer` in a test target), which is not
  yet built.
