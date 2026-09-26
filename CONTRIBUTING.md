# Contributing

Read `AGENTS.md`, `LOCAL_BROWSER_STATE.md`, and `project.json` before changing
anything. They are the working contract, the current handoff, and the
machine-readable state, and all three are updated together with any change.

## Setup

```sh
make bootstrap     # checks the toolchain
make gate          # manifest + protocol schemas + swift build + swift test
make app           # builds dist/Local Lens.app for local use
make dist          # builds and checks the release artifact
make reproduce     # refuses on a dirty tree: runs the whole gate from a clean clone
```

## The rules that are not negotiable

- Work on the one active milestone in `project.json`. Do not start a later one
  because it looks convenient.
- Never weaken a gate after seeing a result. Record the failure instead, in
  `docs/evidence/`, and say what it measured.
- An answer claim may cite only an exact stored passage. A search snippet, a
  metadata record, a summary, or a model's memory is never evidence.
- Keep local and hosted results visibly and analytically separate. They are
  never averaged into one number.
- `Tests` and `Sources/LocalLensApp` may not name `URLSession`,
  `SystemHostResolver`, `SystemPolitenessClock`, `getaddrinfo`, or
  `Task.sleep`; an offline guard test enforces it.
- No new dependency, model, reranker, embedding model, vector database, service,
  or copied sibling code without the recorded decision that `AGENTS.md`
  requires.
- Never commit secrets, downloaded weights, or benchmark bodies whose licence
  does not allow redistribution.

## Adding a mode, a provider, or a metric

1. Write down the measured failure being treated, in `docs/evidence/`, before
   building anything.
2. Prefer a deterministic change with a fixture test. A test that needs the
   network belongs in the live command-line tool, not the unit suite.
3. If a model is involved, fill in the record in `docs/MODEL_POLICY.md` first.
4. Update `docs/MILESTONES.md`, `LOCAL_BROWSER_STATE.md`, `project.json`, and the
   evidence file in the same change.
5. State the proof level honestly: planned, implemented, deterministically
   verified, locally measured, live-provider verified, or reproduced on a second
   machine. They are different claims.
