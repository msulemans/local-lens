# Evaluation Contract

Evaluation answers four different questions and never compresses them into one
flattering score:

1. Did the system find the needed information?
2. Is the answer correct and useful?
3. Do the citations support the exact claims?
4. Is the experience fast and affordable enough to use?

## Unit of evaluation

The primary unit is an atomic, externally verifiable claim paired with zero or
more cited passages. Paragraph-only grading hides partly supported answers and
is insufficient.

## Metric families

### Retrieval

- source recall@k;
- passage recall@k;
- reciprocal rank;
- useful-source yield;
- unique-domain and independent-origin counts;
- duplicate rate; and
- acquisition/extraction success by content type.

### Answer

- short-answer exactness where appropriate;
- claim factuality;
- requested-dimension coverage;
- usefulness and organization;
- calibrated uncertainty;
- contradiction handling; and
- appropriate refusal.

### Citation

- **validity:** marker resolves through claim, evidence link, passage, snapshot,
  and source with matching hashes;
- **entailment precision:** cited passage supports the claim with its scope,
  date, unit, and qualifiers;
- **completeness:** externally verifiable claims have sufficient citations;
- **placement:** marker is attached to the supported span;
- **source quality:** source is suitable for the claim type;
- **independence:** multiple citations are not mirrors of one origin; and
- **conflict integrity:** material disagreement remains visible.

### Product and resource

- time to useful partial output;
- time to completed answer;
- p50 and p95 latency per pipeline stage;
- peak resident memory;
- CPU and energy where measurable;
- downloaded bytes;
- model input/output tokens;
- monetary cost for optional providers;
- cancellation latency; and
- crash/recovery behavior.

## Initial hard targets

- citation validity: 100%;
- no dangling or invented citation IDs: 100%;
- no search snippet used as evidence: 100%;
- terminal reason present for every run: 100%;
- secrets in exported diagnostics: zero;
- benchmark results separated by mode and local/hosted path: 100%.

Semantic quality targets will be frozen only after the baseline data set and
human labels exist. They must not be chosen after seeing a candidate score.

## Evaluation ladder

### Tier A - Deterministic integrity

No model judge. Verify schemas, IDs, hashes, offsets, citation resolution,
state transitions, budgets, duplicate handling, artifact immutability, and
provenance completeness.

### Tier B - Frozen semantic labels

Create development and sealed claim/passage sets labelled:

- `supports`;
- `partially_supports`;
- `contradicts`; or
- `irrelevant`.

Include hard negatives:

- right topic, wrong version;
- right number, wrong unit;
- historical capability presented as current;
- recommendation presented as measured fact;
- snippet agrees but opened page does not;
- mirror sources presented as independent; and
- source supports only one half of a compound claim.

At least two human passes review the sealed subset. Preserve disagreements.
Calibrate any model judge against these labels before using it as an evaluator.

### Tier C - Controlled end to end

Use frozen, redistributable snapshots so system changes, not web drift, explain
score differences. Run each mode against the same fixed configuration and
record all artifacts.

### Tier D - Live utility

Use current public web content with exact run time, configuration, provider
state, and source snapshots. These runs demonstrate current utility but are not
reproducible benchmark comparisons.

### Tier E - External benchmarks

After internal integrity is mature, run bounded subsets or compatible tasks
from:

- ALCE for citation behavior;
- BrowseComp for difficult discovery;
- ResearchQA for paper-grounded questions; and
- DeepResearch Bench for long-form research.

Observe every benchmark's licence and contamination guidance. Do not publish
protected answers or copyrighted bodies.

## Planned local benchmark

Target: 80 questions, developed incrementally rather than all at project start.

| Mode | Count | Families |
|---|---:|---|
| Quick | 20 | fact, explanation, comparison, recommendation, fresh fact |
| Deep | 20 | multi-hop, broad comparison, contradiction, sparse evidence |
| Academic | 20 | lookup, comprehension, multi-paper, unsupported/refusal |
| News | 20 | event fact, timeline, changed fact, disagreement, correction |

Each mode receives a development split and a sealed split. Development tasks
may guide improvement. Sealed tasks are run once per frozen release candidate
and never used for tuning.

## Ablation ladder

Every major retrieval treatment is compared to the smallest working system:

```text
single query + one-shot answer
-> query rewriting
-> parallel acquisition
-> deduplication and source features
-> FTS5/BM25 passage retrieval
-> optional reranker
-> evidence ledger
-> bounded gap research
```

The report must show both gains and regressions. A more complex system is not
promoted when its improvement is within uncertainty or does not justify its
resource/distribution cost.

## Corruption tests

The evaluator must catch intentional defects:

1. swap two citation markers;
2. delete a snapshot;
3. alter one passage after hashing;
4. cite a topically related but non-supporting passage;
5. remove citations from one factual claim;
6. move a marker to an ambiguous paragraph ending;
7. count two syndicated articles as independent;
8. replace a current source with an obsolete version; and
9. label a hosted run as local.

## Human review record

Manual reviews record:

- reviewer;
- rubric version;
- run and configuration digest;
- claim-level labels;
- disagreements and resolution;
- elapsed review time; and
- whether the answer would be trusted for its stated use.

Human review is evidence, not an informal approval checkbox.
