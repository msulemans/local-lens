# Local Lens

Local Lens is a local-first answer engine for macOS. It turns a question into
an inspectable, citation-grounded answer while teaching the user how search,
retrieval, reranking, evidence selection, and generation work.

**Product thesis:** Local Lens is an evidence-native Mac search engine that
generates the right research view for a question and proves every factual cell
with an exact saved passage.

This is not intended to be another web-only Perplexity clone. The product goal
is a native Mac application that a normal user can install and use without
Docker, while a contributor can fork and run from source through one documented
path.

## Product promise

A completed search must let a user:

1. choose `Quick`, `Deep`, `Academic`, or `News` and receive behavior that is
   genuinely different for that mode;
2. see useful partial progress while sources are being acquired;
3. open every citation at the exact passage used by the answer;
4. distinguish local processing from optional network or hosted processing;
5. inspect conflicts, missing evidence, and the reason a run stopped;
6. export the answer with machine-readable provenance; and
7. open **Learn this run** to understand the pipeline using their real search.

## System shape

```text
question
  -> mode policy
  -> query rewriting
  -> search adapters
  -> bounded parallel fetch
  -> extraction + immutable snapshots
  -> chunking + retrieval
  -> measured reranking, when justified
  -> claim/evidence ledger
  -> evidence-constrained generation
  -> citation compiler + validator
  -> answer + evidence map + evaluation trace
```

The controller owns budgets, state transitions, source identities, citation
identifiers, and validation. Models may propose structured work; they cannot
declare their own unsupported output verified.

## Start here

- [Canonical project state](LOCAL_BROWSER_STATE.md)
- [Machine-readable project handoff](project.json)
- [AI and contributor handoff](docs/AI_HANDOFF.md)
- [Complete product and build plan](docs/COMPLETE_PLAN.md)
- [Reuse provenance and licence gate](docs/REUSE_PROVENANCE.md)
- [ResearchCore extraction boundary](docs/RESEARCH_CORE_BOUNDARY.md)
- [Adopt, adapt, build ledger](docs/ADOPT_ADAPT_BUILD.md)
- [Innovation thesis](docs/INNOVATION_THESIS.md)
- [Project map](docs/PROJECT_MAP.md)
- [Product contract](docs/PRODUCT.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Performance plan](docs/PERFORMANCE_PLAN.md)
- [Milestones and gates](docs/MILESTONES.md)
- [Evaluation contract](docs/EVALUATION.md)
- [Model policy](docs/MODEL_POLICY.md)
- [Security and privacy](docs/SECURITY_AND_PRIVACY.md)
- [Learning path](docs/LEARNING_PATH.md)
- [Decision log](docs/DECISIONS.md)
- [Research references](docs/REFERENCES.md)
- [Selected visual direction](docs/design/README.md)

## Current status

Milestone 000 and its planning correction are complete. The plan now records
the exact GitHub/research/X inputs, the code-reuse boundary, and the
Evidence-Native Generative Search thesis.

Milestone 001 is active. Its package baseline builds, four initial core tests
pass, and the app shell launches (`make run`, smoke test only). Reuse
provenance and the ResearchCore boundary are frozen, and protocol v1 schemas
are validated against the Swift core. The next task is the deterministic
offline fixture slice. Research-core extraction, live providers, models, and
packaged distribution are not claimed yet.

## Working rules

- One active milestone at a time.
- Never weaken a gate after seeing a result.
- Preserve failed experiments and explain what they taught.
- Keep local and hosted results separate.
- Start from deterministic fixtures before live providers.
- Do not benchmark a model or reranker without a recorded failure hypothesis.
- Update code, tests, state, documentation, benchmark evidence, and learning
  material together.

## Visual direction

The selected direction is **Living Research Map**: a native, comparison-first
workspace with sparse provenance ribbons connecting answer claims to an
inspectable evidence map. See
[docs/design/local-lens-living-research-map.png](docs/design/local-lens-living-research-map.png).

## License

No public license has been selected yet. This must be resolved before the first
public release.
