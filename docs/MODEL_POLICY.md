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
