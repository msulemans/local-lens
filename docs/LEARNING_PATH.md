# Learning Path

The learning surface is part of the product and must evolve with each
milestone. Static explanations that do not reflect current code are failures.

## Learning loop

Every milestone follows:

```text
mental model
  -> prediction
  -> smallest implementation
  -> exact verification command
  -> observed evidence
  -> explain-back
  -> gate decision
  -> canonical state update
```

## M001 - Trustworthy state

Learn:

- why prompts cannot own application state;
- value types, actors, cancellation, and explicit terminal states;
- stable serialization, IDs, and content hashes;
- protocols and fake adapters; and
- why a deterministic fixture is a scientific control.

Explain back:

1. Why can the model not choose a citation ID?
2. What makes a run reproducible?
3. Why is cancellation a state transition rather than a UI detail?
4. What does the deterministic fixture prove, and what does it not prove?

## M002 - The hostile web

Learn:

- metasearch versus a web index;
- DNS/IP safety and SSRF;
- HTTP redirects, MIME, compression, and timeouts;
- robots and ethical acquisition;
- extraction loss; and
- why snippets are not evidence.

Explain back:

1. Why must every redirect destination be validated?
2. Why can a search result be relevant but unusable as evidence?
3. When should browser rendering be permitted?
4. What information must a snapshot preserve?

## M003 - Retrieval and local generation

Learn:

- BM25 and term saturation;
- source-quality features versus truth;
- context budgeting;
- structured generation and streaming;
- Apple Silicon memory behavior; and
- latency decomposition.

Explain back:

1. When can BM25 beat embeddings?
2. Why is time to first useful output different from completion latency?
3. What work belongs in deterministic code instead of a model?
4. What evidence justifies changing the default model?

## M004 - Measured reranking

This lesson exists only if M004 entry criteria are met.

Learn:

- bi-encoder, cross-encoder, late-interaction, and listwise ranking;
- recall versus precision at a context cutoff;
- calibration and domain drift; and
- when added model complexity harms the product.

Explain back:

1. Which observed retrieval errors triggered the experiment?
2. What is the baseline?
3. Did the reranker improve the downstream answer or only its own metric?
4. What latency and packaging cost did it add?

## M005 - Scholarly evidence

Learn:

- DOI identity and versioning;
- preprint, accepted manuscript, and version of record;
- citation graphs versus relevance;
- primary and secondary evidence; and
- PDF structure and extraction limits.

## M006 - Temporal evidence

Learn:

- publication time versus event time;
- syndication and source independence;
- breaking-news uncertainty;
- corrections and meaningful updates; and
- time-aware claims.

## M007 - Bounded research

Learn:

- question decomposition;
- coverage matrices;
- contradiction versus qualifier mismatch;
- evidence-gain stopping rules;
- pause/resume and idempotency; and
- why more searches can make an answer worse.

## M008 - Evaluation

Learn:

- validity versus entailment;
- citation precision versus completeness;
- human disagreement;
- evaluator calibration;
- sealed tests and contamination;
- corruption testing; and
- why one aggregate score is misleading.

## In-product `Learn this run`

For a completed run, learning mode shows:

1. original question and mode policy;
2. query rewrites and their intended coverage;
3. search hits versus opened evidence;
4. extraction failures and duplicates;
5. retrieved passages and ranking rationale;
6. claims and evidence relationships;
7. rejected unsupported draft content;
8. termination reason; and
9. one explain-back prompt based on that run.

The view consumes the same typed events as the application. It does not invent
a parallel story about what happened.
