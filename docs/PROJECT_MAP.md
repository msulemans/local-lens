# Project Map

## Current milestone

```text
M000 product + reuse plan    COMPLETE
  |
  v
M001 reuse foundation +      COMPLETE
     deterministic native
  |
  v
M002 safe live acquisition   NEXT
  |
  v
M003 useful Quick release
  |
  +--> M004 retrieval treatment, only if measured failure requires it
  |
  v
M005 Academic
  |
  v
M006 News
  |
  v
M007 Deep
  |
  v
M008 evaluation + learning
  |
  v
M009 public Mac release
```

## Authority hierarchy

When documents disagree:

1. `LOCAL_BROWSER_STATE.md` - current status and observed evidence;
2. `project.json` - machine-readable current state and handoff constraints;
3. `docs/COMPLETE_PLAN.md` - complete product and execution map;
4. `docs/DECISIONS.md` - durable product/architecture decisions;
5. `docs/MILESTONES.md` - frozen scope and gates;
6. focused contracts such as architecture, evaluation, model, and security;
7. `README.md` - concise public entry point; and
8. external references - inspiration, never current project proof.

## Planned repository layout

```text
LocalLensApp/          native app target, created in M001
Sources/
  LocalLensCore/       native policies, validated bridge and presentation state
  LocalLensApp/        SwiftUI product shell and Evidence UI renderer
ResearchCore/          extracted proven Python research package and local host
Tests/                 deterministic unit/integration tests
UITests/               selected primary-flow verification
Fixtures/              small redistributable frozen sources
benchmarks/            manifests, labels and public result summaries
docs/                  contracts, lessons, evidence and decisions
runs/                  generated run artifacts, Git-ignored
models/                downloaded weights, Git-ignored
```

This is planned, not implemented. M001 may refine module names while preserving
the boundaries.

## System ownership

| Concern | Authority |
|---|---|
| mode policy, native lifecycle, UI validation | trusted Swift core |
| research state, budgets, search and acquisition | versioned ResearchCore |
| extraction and passage identity | ResearchCore with versioned provenance |
| language proposals and synthesis | selected model adapter behind explicit boundary |
| citation compilation | ResearchCore; revalidated by the native boundary |
| citation rendering | trusted SwiftUI renderer |
| adaptive visual layout | trusted SwiftUI block renderer |
| benchmark scoring | versioned evaluators plus human labels |
| milestone truth | `LOCAL_BROWSER_STATE.md` |

## Evidence directories, when created

```text
docs/evidence/<milestone>/<run>/
benchmarks/manifests/
benchmarks/labels/
benchmarks/results/public/
runs/<run-id>/
```

Public evidence contains configurations, hashes, summaries, and redistributable
fixtures. Private page bodies and restricted benchmark material remain outside
Git.
