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

M001, M002, and M003 are complete: the offline citation path, safe acquisition,
lexical retrieval, deterministic Quick view, and the live no-Docker Tavily app
path are built, and the unchanged five-question card measured **7/10 with 13/13
exact citations** (`docs/evidence/M003/m003-frozen-card-treated.md`).
The live Mac workspace opens by default, accepts a question, labels hosted generation, and
lets a reader inspect the exact saved passage and fetched source behind a
citation. Its normal no-Docker search choice is Tavily's no-card free tier;
Brave Search and a contributor-managed SearXNG remain optional. The old
Quick-only and synthetic fixture windows are internal regression views, not
additional product interfaces. Citation linkage is not independent fact-checking.
A user-supplied
public URL skips search altogether. Search results are discovery metadata only;
pages still pass through the same safe-fetch and citation checks.
**Find evidence without AI** searches and opens matching passages without a
DeepSeek key; with a supplied URL it becomes **Inspect page without AI** and
needs no key at all. This is a source preview, not a generated answer or a
verified citation.

The current working tree passes `make gate` (**315 tests, 0 failures**). All four
modes have been driven through the Mac app with hosted answers, and the
development bundle runs locally. [The four-mode evidence](docs/evidence/M009/m0093-defects-and-redesign.md)
and [UI close-out audit](docs/evidence/M009/m0094-ui-closeout-audit.md) distinguish
application flow from answer usefulness; a citation is not a fact-check.

Live search now runs against a curated development SearXNG baseline
(`scripts/run_searxng.sh`, engines pinned in `scripts/searxng/settings.yml`),
because the stock engine set suspended under repeated use. Source discovery
also prefers official documentation/forum hosts over blogs
(`Sources/LocalLensCore/SourceAuthority.swift`). These changes are measured in
`docs/evidence/M003/m0037-frozen-card-improved.md`: the frozen card re-measured
1/10 with a false-premise endorsement, and a targeted two-call verification of
the source-authority ordering projected 3/10 with that endorsement removed.

Tavily's no-Docker path runs in the Mac app: a no-AI search opens public sources
and the app displays exact saved passages, and one pre-recorded hosted Ask
returned four clickable exact-passage citations in 6.0 seconds. A trailing-slash
redirect bug that was refusing Apple and `swift.org` primary pages as
`redirect_loop` was fixed with a deterministic, tested change
([close-out](docs/evidence/M003/m003-gate-closeout.md)), and the unchanged
five-question card then measured **7/10 with 13/13 exact citations**
([card](docs/evidence/M003/m003-frozen-card-treated.md)), promoting Quick from
the 2/10 baseline. Peak app RSS was 140 MB and the committed deterministic path
reproduces from a clean checkout. Still unverified: second-machine reproduction
and notarized distribution. Q5 abstains rather than correcting its false
premise, and Q3 gives only the actionable check step. The
frozen five-question benchmark and honest failures are in
`docs/evidence/M003/five-questions.md`.

### Try the current Mac workspace from source

On macOS with Xcode installed, run `make app` to build the ad-hoc-signed
development bundle at `dist/Local Lens.app`, or run `swift run LocalLensApp`
from this directory. The bundle is not notarized or tested on another Mac.
The app opens to the **Living Research Map**, not a single Quick form. The
toolbar carries the question, the mode (Quick, Deep, Academic, News), that
mode's frozen budget, the elapsed time, pause, and cancel. In **Connection**,
choose the default Tavily option and
[get a Tavily API key](https://app.tavily.com/home) (check the vendor's current
terms and pricing); paste it in the app and optionally save
it to macOS Keychain. Select **Find evidence** to inspect fetched passages with
no AI key at all. For a generated answer, enter a separate DeepSeek API key;
that hosted service may cost money. Answers appear as a brief whose every
claim is a provenance ribbon into the evidence map; selecting a claim opens
its exact saved passage in the inspector, and an uncovered dimension offers a
bounded **Research this gap**. **History** replays completed runs from local
disk with no network call, and the **Global launcher** (Command-Shift-Space)
starts a run from anywhere. Academic mode reconciles OpenAlex, arXiv, and
Crossref by DOI/versionless-arXiv identity, orders primary papers before
aggregators, and extracts page-numbered passages from an open-access PDF
through the same acquisition boundary. Completed answers export as Markdown,
BibTeX, or RIS. A local answer model can be selected in Connection (a loopback
OpenAI-compatible endpoint such as Ollama); it was measured at 6/10 on the
frozen card and is therefore an explicit alternative, not the default. Hosted mode sends selected saved passages to
DeepSeek. Do not enter private pages or credentials. An answer may abstain when
the fetched pages do not support a claim.

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

Local Lens is available under the [MIT License](LICENSE). The licence applies
to this repository, not to code in a separate sibling project.

## Building and running

```sh
make bootstrap     # toolchain check
make gate          # manifest, protocol schemas, build, tests
make app           # dist/Local Lens.app
make demo          # mode plan, edited plan, typed refusal, corruption check (US$0)
make dist          # release artifact plus nine automatic checks
make reproduce     # clean-clone gate; refuses a dirty tree
```

Everything above runs without a hosted model. Discovery needs a search key or a
local SearXNG; a written answer needs either a hosted key or a local endpoint.

Three release gates remain open — an independent reviewer, a second Mac, and a
Developer ID. The owner has closed the fourth, licence selection, with MIT.
Each remaining gate and its exact close command is in `docs/HANDOFF.md`.
