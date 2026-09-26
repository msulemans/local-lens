# Reproducing this repository

Two different claims live here, and they are not the same:

- **Verified on this machine**: the gate passes and the artifacts build here.
- **Reproduced on a second machine**: someone else ran the documented commands on
  a different Mac and got the same results. That has not happened yet; it is
  recorded as unproven in `LOCAL_BROWSER_STATE.md`.

## From a clean clone

```sh
git clone <repository> local-browser
cd local-browser
make bootstrap
make reproduce
```

`make reproduce` refuses to run in a dirty tree on purpose: uncommitted edits
are not a reproduction. It runs the gate, both validators, the release build and
its checks, and the demo.

## What the gate proves

| Command | Proves |
|---|---|
| `make validate-manifest` | `project.json` conforms and its handoff invariants hold |
| `make validate-schemas` | protocol v1 schemas and the Swift types agree |
| `swift build` | every target compiles |
| `swift test` | the offline suite passes, including the offline guards |
| `make dist` + `make verify-release` | the bundle is signed as far as this machine allows, and contains no secret, weight, or fetched page |
| `make demo` | mode plans, the edited plan, the typed refusal, and the corruption test |

## What needs credentials, and what they cost

- **Discovery** needs a search key (`TAVILY_API_KEY`, a free tier is enough) or a
  local SearXNG. OpenAlex, arXiv, and Crossref are keyless.
- **A written answer** needs either a hosted key (`DEEPSEEK_API_KEY`) or a local
  OpenAI-compatible endpoint (`--local --local-model <name>`), which costs
  nothing and keeps every request on the machine. Artifacts are labelled
  `local` or `hosted` and are never merged.
- Nothing in the offline test suite makes a network call.

## Reproducing a benchmark number

```sh
export TAVILY_API_KEY=...
swift build
./.build/debug/LocalLensLive --tavily --local --mode benchmark \
  --card docs/evidence/frozen/five-questions.json \
  --out /tmp/scorecard.json --review-out /tmp/review.json --lessons-out /tmp/lessons
./.build/debug/LocalLensLive --mode review --scorecard /tmp/scorecard.json \
  --review /tmp/review.json --out /tmp/scored.json
./.build/debug/LocalLensLive --mode calibrate --scorecard /tmp/scored.json
```

The card is frozen: do not retune a question or a threshold after seeing a
result. A run with no human labels reports `usefulness unscored`, and the
evaluator reports itself uncalibrated until it has at least
`EvaluatorCalibration.minimumSamples` labels.

## Known limits on a fresh machine

- Notarization needs a **Developer ID Application** identity and a notary
  profile; without them `make dist` signs with whatever identity exists and says
  so in `dist/release/BUILD-INFO.json`.
- The first live run on a rebuilt bundle asks for keychain access, because macOS
  ties that grant to the signature.
- The local model is whatever the machine's own server has; the app does not
  download weights.
