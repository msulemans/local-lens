# Model and Reranker Policy

## Purpose

This project will not spend weeks cycling through fashionable models. Model
selection exists to solve measured product failures under a Mac distribution
and resource budget.

## Default rule

Use deterministic code for tasks that do not require generation:

- IDs, hashes, offsets, state transitions and budgets;
- URL and source normalization;
- citation rendering and integrity;
- duplicate detection baselines;
- time-range enforcement; and
- export/provenance assembly.

Use a language model only where language judgment or synthesis is actually
needed.

## Candidate admission gate

A candidate may be run only after this record is written and reviewed:

```text
Experiment ID:
Measured failure:
Existing baseline and score:
Why this candidate could treat that failure:
Exact model/revision/hash:
Licence and redistribution constraints:
Runtime and integration path:
Frozen development tasks:
Frozen sealed tasks, if applicable:
Quality promotion threshold:
Latency ceiling:
Peak memory ceiling:
Disk/download ceiling:
Maximum runs/calls/tokens/cost:
Stop condition:
Rollback path:
```

If any field is missing, the experiment is not eligible.

## Initial inference strategy

### M001

Only a deterministic fake model. No real weights and no provider calls.

### M003

Select one credible local candidate, not a tournament. The candidate must:

- run well on Apple Silicon through a supported Swift/native boundary;
- support the required structured answer-block schema;
- stream and cancel correctly;
- fit the measured memory budget with the rest of the app active;
- have a licence compatible with the intended distribution; and
- be documented well enough for a contributor to reproduce.

Apple Foundation Models is a capability-specific option, not an automatic
quality winner. MLX is the intended custom-model path. Hosted models are
optional labelled references, never silent fallbacks.

## Task routing

One model does not need to do everything. Routing is allowed only when it
reduces a measured cost or fixes a measured failure without making onboarding
fragile.

Potential roles:

- query rewriting;
- claim extraction;
- structured drafting; and
- semantic citation review.

Do not add a separate model for each role by default. Begin with one supported
local model and deterministic helpers.

## Reranker policy

FTS5/BM25 plus deterministic source features is the baseline.

A reranker experiment may start only when labelled retrieval errors show one
of these stable problems:

- relevant passages consistently fall below the context cutoff;
- lexical mismatch causes low passage recall;
- multi-document comparison needs cross-document ordering; or
- downstream citation completeness is limited by retrieval rather than writing.

Eligible candidate classes may include a compact local cross-encoder, a
listwise reranker, Jina, or another well-supported system. Jev is considered a
judgment/classification experiment, not a default reranker or generator.

Promotion requires a held-out improvement that clears the predeclared threshold
and stays inside latency, memory, licence, privacy, and packaging budgets.

## No silent fallbacks

If a local model is unavailable or lacks a requested capability, the app must:

- explain the missing capability;
- offer an explicitly configured alternative; or
- run a smaller supported mode.

It must not silently send content to a hosted provider.

## Result reporting

Every model result reports:

- exact candidate identity;
- hardware and OS;
- runtime and decoding configuration;
- task-set digest;
- success/failure counts;
- latency distribution;
- peak memory;
- token/cost data where applicable;
- all fallbacks; and
- promotion decision.

Negative results are retained. A sealed test set is never reused for prompt or
candidate selection.

## Experiment record: local OpenAI-compatible answer provider (M004.2)

```text
Experiment ID: M004.2-LOCAL-OPENAI-001
Measured failure: the M004.1 app had no local answer path at all; every
  answer left the machine through hosted DeepSeek, so the release contract's
  "supported local model or an explicit compatible endpoint" was unmet and the
  local/hosted boundary had only one side.
Existing baseline and score: hosted DeepSeek Quick measured 7/10 with 13/13
  exact citations on the promoted M003 card. The local path has no answer
  result yet (0 measured).
Why this candidate could treat that failure: an instruction-tuned local model
  served over a loopback OpenAI-compatible endpoint can emit the same strict
  JSON proposal contract. AnswerTrust still verifies every quote against a
  stored passage, so a weaker model cannot create a weaker citation; it can
  only abstain or propose fewer accepted claims.
Exact model/revision/hash: qwen2.5-coder:14b-instruct-q4_K_M, Ollama model id
  9ec8897f747e, 9.0 GB, as reported by `ollama list` on the reference Mac. No
  weight is downloaded or committed by this repository.
Licence and redistribution constraints: Apache-2.0 (Qwen2.5-Coder). Weights
  stay user-installed; the repository licence is still unselected (M009).
Runtime and integration path: Ollama at 127.0.0.1:11434, OpenAI-compatible
  POST /v1/chat/completions, temperature 0, max_tokens 2000, no streaming, no
  response_format, no credential. The app reaches it only through
  `LocalAnswerProvider`; the artifact is labelled `local/<model>`.
Frozen development tasks: the five frozen questions in
  docs/evidence/M003/five-questions.md, with provider-free retrieval unchanged.
Frozen sealed tasks, if applicable: the fresh F1-F5 set in
  docs/evidence/M003/m0038-fresh-searches.md, held out.
Quality promotion threshold: on the frozen card, at least four of five
  questions at >=1/2 with 100% citation integrity. Below that, the local path
  remains an explicitly labelled alternative and never becomes the default.
Latency ceiling: <= 60 s per Quick answer on the reference Mac, excluding
  retrieval; <= 180 s for Deep.
Peak memory ceiling: <= 12 GB resident for the model server and <= 200 MB for
  the app during a local answer.
Disk/download ceiling: <= 12 GB model file, already present; no repository
  download and no new dependency.
Maximum runs/calls/tokens/cost: US$0 (local); at most 10 local generations in
  this experiment.
Stop condition: two consecutive generations with unparseable JSON, or any
  generation that yields no verified citation after retrieval produced usable
  passages; record the failure and keep hosted as the default.
Rollback path: leave `useLocalProvider` off; the local path stays behind the
  explicit Connection toggle and is never a silent fallback for a hosted
  failure.
```

Result (recorded in `docs/evidence/M004/m0042-local-and-academic.md`):

- Live Quick answer on the reference Mac: 4 exact citations from 5 opened
  sources in 34.1 s at US$0, inside the 60 s ceiling.
- Live News answer on the same endpoint: 1 exact citation, 6 independent
  domains, 30.3 s, but the model answered the wrong sense of "Swift"
  (financial messaging rather than the programming language).
- Frozen card: **6/10 usefulness, 10/10 exact citations**. Q1 2/2, Q2 2/2
  (82.69 s, over the 60 s ceiling), Q3 1/2, Q4 abstained, Q5 0/2 (did not
  correct or abstain on a false premise).
- Final decision: **not promoted**. The pre-recorded threshold required four of
  five questions at >=1/2; only three reached it and Q2 breached the latency
  ceiling. The local path stays an explicitly labelled alternative and is never
  a silent fallback. Full card: docs/evidence/M004/m0043-local-card.md.
