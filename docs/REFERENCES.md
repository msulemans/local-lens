# Planning References

Reviewed on 2026-09-22. These sources informed M000 product and architecture
choices. They are planning inputs, not frozen evidence for generated answers,
current dependency approval, or proof that Local Lens has implemented a feature.

Recheck versions, licences, pricing, APIs, and project health immediately before
integration.

## Apple and native inference

- [Apple Human Interface Guidelines - Searching](https://developer.apple.com/design/human-interface-guidelines/searching)
  - one clearly identified search location, visible scope, suggestions, and
    privacy-aware history are appropriate defaults.
- [Apple Foundation Models](https://developer.apple.com/documentation/FoundationModels)
  - native structured generation and tool boundaries are relevant to the model
    adapter, subject to capability testing on supported Macs.
- [WWDC26 machine-learning guide](https://developer.apple.com/wwdc26/guides/machine-learning/)
  - introduces the common `LanguageModel` protocol and Dynamic Profiles for
    changing model, tools, and instructions in a continuous session.
- [What's new in Foundation Models](https://developer.apple.com/videos/play/wwdc2026/241/)
  - documents Dynamic Profiles, the Evaluations framework, and Apple's
    CoreAILanguageModel/MLXLanguageModel direction.
- [Bring an LLM provider to Foundation Models](https://developer.apple.com/videos/play/wwdc2026/339/)
  - supports keeping system, PCC, Core AI, MLX, and provider-backed models
    behind one native protocol.
- [MLX Swift LM](https://github.com/ml-explore/mlx-swift-lm)
  - plausible native path for custom local models, guided generation, and model
    abstraction on Apple Silicon.
- [MLX Chat Example](https://github.com/ml-explore/mlx-swift-examples/tree/main/Applications/MLXChatExample)
  - reference for streaming, cancellation, model lifecycle, and SwiftUI/MLX
    separation; not a production architecture to copy wholesale.

## Open-source answer and research products

- [Perplexica](https://github.com/haddadrm/Perplexica)
  - demonstrates SearXNG, local models, query expansion, and focus modes.
  - product lesson: avoid making infrastructure configuration the first user
    experience.
- [Morphic](https://github.com/miurla/morphic)
  - demonstrates streamed grounded answers, multiple search/model providers,
    and schema-driven generative UI.
  - product lesson: adaptive answer blocks are useful when the renderer remains
    trusted and bounded.
- [Local Deep Research](https://github.com/LearningCircuit/local-deep-research)
  - demonstrates deep-research breadth, citations, configurable providers, and
    benchmark work.
  - product lesson: Docker networking, ports, model memory, and configuration
    are real onboarding costs that the normal Mac path should absorb.
- [SurfSense](https://github.com/MODSetter/SurfSense)
  - demonstrates local indexing, installer-led onboarding, model-size choices,
    citations, and desktop access.
- [Starcat](https://github.com/starcat-app/Starcat)
  - demonstrates a native Mac knowledge workspace with FTS5, evidence chunks,
    a citation inspector, and an execution timeline.
- [lilbee](https://github.com/tobocop2/lilbee)
  - demonstrates the value of one executable, multiple interfaces, exact-line
    citations, explicit no-answer behavior, and cross-platform CI.
- [PaperLens](https://github.com/vanthree31/PaperLens)
  - demonstrates progressive multi-source academic results, structured paper
    analysis, comparison, citation graphs, and reference-manager exports.
- [OpenDraft](https://github.com/federicodeponte/opendraft)
  - demonstrates DOI verification across multiple scholarly registries.
  - caution: record existence is not evidence that a paper entails a claim.
- [web-researcher-mcp](https://github.com/zoharbabin/web-researcher-mcp)
  - useful reference for typed web, news, academic, full-text, and bibliography
    audit capabilities.

## Search and retrieval

- [SearXNG documentation](https://docs.searxng.org/)
- [SearXNG Search API](https://github.com/searxng/searxng/blob/master/docs/dev/search_api.rst)
  - establishes the initial replaceable metasearch boundary. SearXNG aggregates
    external services; it is not a local copy of the web.
- [Exa Search reference](https://github.com/exa-labs/agent-skills/blob/main/skills/build-with-exa/references/search.md)
  - optional later comparison for semantic discovery and extracted highlights.
- [Jina Reranker](https://jina.ai/reranker/)
  - a possible listwise reranking challenger only after the lexical baseline
    produces labelled failures.
- [Diffusion-Pretrained Dense and Contextual Embeddings](https://arxiv.org/abs/2602.11151)
  - introduces standard and document-context-aware retrieval models; the latter
    is a plausible treatment for chunks whose meaning depends on the full
    document, subject to Local Lens M004 evidence.
- [ConTEB](https://arxiv.org/abs/2505.24782)
  - provides a benchmark framing for retrieval that needs document-wide
    context; it does not replace downstream Local Lens evaluation.

## Agent and generative UI protocols

- [AG-UI introduction](https://github.com/ag-ui-protocol/ag-ui/blob/main/docs/introduction.mdx)
  - open event-based agent-to-frontend protocol with run lifecycle, streaming,
    state, activity, tools, and human-interaction concepts.
- [AG-UI events](https://github.com/ag-ui-protocol/ag-ui/blob/main/docs/concepts/events.mdx)
  - snapshot/delta and start/content/end patterns inform the internal event
    schema and replay model.
- [A2UI v1 candidate protocol](https://github.com/a2ui-project/a2ui/blob/main/specification/v1_0/docs/a2ui_protocol.md)
  - streamed declarative UI with separate component structure and data updates;
    Local Lens adopts only a smaller citation-bearing SwiftUI subset.
- [Ask Jev](https://www.askjev.ai/)
  - judgment/classification system considered only for a measured routing or
    evidence-decision failure, not as the product foundation.
- [jev-search](https://github.com/larguesa/jev-search)
  - experimental evidence warns that semantic search must beat lexical search
    plus context on the actual task rather than being assumed superior.

## Evaluation research

- [ALCE: Enabling Large Language Models to Generate Text with Citations](https://arxiv.org/abs/2305.14627)
  - citation correctness and completeness must be measured separately.
- [BrowseComp](https://openai.com/index/browsecomp/)
  - useful for persistent, hard-to-find discovery but not a complete proxy for
    everyday answer usefulness.
- [ResearchQA](https://arxiv.org/abs/2607.11074)
  - paper-grounded citation evaluation and supported refusal are relevant to
    Academic mode.
- [DeepResearch Bench](https://arxiv.org/abs/2506.11763)
  - potential bounded long-form and citation-quality evaluation after the core
    citation system is mature.
- [FutureSearch Deep Research Bench](https://arxiv.org/abs/2506.06287)
  - frozen web snapshots are valuable for separating system changes from web
    drift.

## Public X signals

These are product signals and anecdotes, not authoritative technical evidence.

- [Exa and Fireworks research-assistant example](https://x.com/ExaAILabs/status/2002082033661849837)
  - supports keeping search and inference as separable, replaceable roles.
- [Simple routing and parallel workflow patterns](https://x.com/Aurimas_Gr/status/2024493100362563776)
  - reinforces bounded routing and parallel query work before a complex agent
    topology.
- [Generative UI discussion](https://x.com/rauchg/status/2041883605711122488)
  - supports exploring adaptive presentation, while Local Lens keeps a finite
    trusted renderer rather than executable model-generated UI.
- [Open-weight retrieval model discussion](https://x.com/antoine_chaffin/status/2027398554042380590)
  - retrieval models are evolving quickly; pin and measure exact revisions
    rather than choosing from reputation.
- [Large-scale AI citation source discussion](https://x.com/sengineland/status/2039372817850867937)
  - reinforces that citation frequency is not source appropriateness or
    independence.

Live X browser access was unavailable during planning. Only publicly indexed
posts were reviewed, so this is not a complete survey of the current timeline.

## Sibling repository lessons

The local sibling `../deep-research-agent` was inspected directly. Reusable
concepts include:

- typed research state;
- safe acquisition;
- immutable snapshots;
- claim/evidence relationships;
- citation compilation;
- deterministic integrity evaluation;
- separate local and hosted results; and
- canonical milestone evidence.

Direct inspection found 184 unit tests and concrete reusable modules for domain
entities, state, adapters, acquisition, extraction, FTS5 retrieval, ranking,
deduplication, report/citation validation, and evaluation. Local Lens will
extract these into a versioned research core rather than reimplement them.

The sibling revision observed during planning was `1b1a698`. No root licence
file was present, so direct code transfer is gated on ownership, licensing, and
provenance resolution.
