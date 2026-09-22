# Design Conformance: Living Research Map

Reference: `docs/design/local-lens-living-research-map.png` (selected 2026-09-22).

Rule from `docs/design/README.md`: implement the information hierarchy and
interaction model before decorative polish. Compare the coded screen and the
reference at the same viewport before claiming visual fidelity.

| Design element | Status | Where / next milestone |
|---|---|---|
| Window header with question, mode, status | Implemented (minimal) | App header shows the question, `mode · status · citation count` |
| Evidence map: decision factors with sources and relations | Implemented (minimal) | Map view: claim cards with relation badge, source row, colour plus text; captured in `docs/evidence/M001/app-map-view.png` |
| Exact-passage inspection | Implemented | Right-hand inspector: source, heading, passage text, text hash; captured in both M001 screenshots |
| Toolbar: elapsed time, local/hosted state, pause, cancel | Partial | Stop and cancel transition types exist in the core; the toolbar lands when live runs stream events (M002) |
| Comparison at a glance table | Not implemented | M003 (needs comparison rows in a run result) |
| Recommendation and open-question blocks with `Research this gap` | Not implemented | M003 |
| Sparse provenance ribbons | Not implemented | M003, after the comparison/Evidence UI hierarchy exists |
| Learning explanation toggle | Not implemented | M008 |
| Responsive behaviours (wide/medium/compact) | Not implemented | M003, reviewed at the reference viewport |
| Accessibility: keyboard, VoiceOver, colour-plus-text, contrast | Partial | Selection, labels, and colour-plus-text exist; the accessibility matrix review lands in M003/M009 |

## Fidelity ladder

1. **M001 (done):** minimal hierarchy — brief, citation list, factor cards,
   relation states, exact-passage inspection.
2. **M002:** live-run states feed the header/toolbar (progress, cancel, time).
3. **M003:** comparison-first workspace — comparison table, recommendation and
   open-question blocks, provenance ribbons, responsive layouts, look-alike
   review against the reference at the same viewport.

Update this table whenever a design element changes status; keep it in sync
with `docs/PROJECT_MAP.md`.
