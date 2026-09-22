# Product Contract

## Product statement

Local Lens is a native macOS answer engine for people who want current,
inspectable answers without surrendering their research history or operating a
private cloud stack.

It optimizes for three jobs:

1. answer an everyday question quickly;
2. compare options without losing the evidence behind each judgment; and
3. turn a completed search into an understandable lesson.

## Primary user

A technically curious Mac user who researches software, products, papers, and
current events. They value privacy and local models but do not want to manage
containers, ports, databases, and prompts before asking a question.

Contributors are the secondary user. They must be able to fork the repository,
run a deterministic demo, understand the pipeline, and replace adapters without
rewriting the application.

## Product principles

### Useful before broad

Quick mode must become a daily tool before Deep mode becomes an impressive
demo. Provider count and model count are not success metrics.

### Evidence is a first-class object

An answer is not complete because it contains links. A factual claim must map
to the exact passage the system read, with the source and snapshot preserved.

### Local-first, not falsely offline

Run state, history, cached sources, retrieval, and supported inference stay on
the Mac. Live web research necessarily contacts configured search services and
public websites. The UI must show those boundaries plainly.

### Fast path and research path

Common questions should not pay the latency of an agent loop. Quick mode is a
bounded pipeline. Deep mode earns additional steps only when the selected mode
and observed evidence justify them.

### Learning is part of the product

`Learn this run` explains the actual query rewrites, selected passages,
ranking, evidence gaps, and termination decision. It is not a separate static
tutorial that drifts away from the implementation.

## Mode contracts

### Quick

Purpose: reach a concise, supported answer with minimal waiting.

- one primary query and at most one alternate rewrite;
- five to eight search hits;
- three to five opened sources;
- one acquisition pass;
- no autonomous follow-up research loop;
- answer first, supporting detail second; and
- initial product target: useful partial output quickly and a complete answer
  around ten seconds on the reference machine, subject to measured provider and
  model limits.

### Deep

Purpose: compare, investigate, and expose evidence gaps.

- explicit decomposition into answer dimensions;
- four to eight queries;
- ten to twenty opened sources;
- at most two follow-up rounds;
- stop on coverage, diminishing evidence gain, cancellation, or hard budget;
- preserve contradictions and unresolved questions; and
- show the Living Research Map.

### Academic

Purpose: search and synthesize scholarly work without treating generic web
results as papers.

- scholarly metadata providers before general web search;
- primary studies prioritized for claims about their own results;
- DOI and version reconciliation;
- PDF/page-aware evidence where legally accessible;
- paper comparison, methods, limitations, and citation graph expansion; and
- BibTeX/RIS export.

### News

Purpose: explain a current event with explicit time and source independence.

- query time window included in the run contract;
- publication and meaningful-update timestamps retained;
- syndication and copied reports clustered;
- material claims require independent confirmation or visible uncertainty;
- disagreement and developing facts remain visible; and
- every answer displays its last research time.

## Primary experience

The selected Living Research Map layout contains:

- a toolbar with the question, mode, local/hosted boundary, elapsed time, pause,
  and cancel;
- a living brief that can render prose, comparisons, timelines, or paper
  matrices;
- an evidence map grouped by the decision criteria in the question;
- sparse provenance ribbons between an answer element and supporting evidence;
- exact-passage inspection; and
- a bounded `Research this gap` action.

## Release surfaces

### Normal user

- signed and notarized macOS application;
- hardware-aware onboarding;
- no terminal and no Docker;
- bundled deterministic demonstration;
- supported local model download or an explicit compatible endpoint; and
- Keychain-backed optional provider credentials.

### Contributor

Target interface:

```bash
git clone <repository>
cd local-browser
make bootstrap
make verify
make run
```

These commands do not exist yet. M001 must implement and verify them before the
README presents them as usable.

## First usable release

Quick mode with live web retrieval, a supported local model, exact citations,
history, cancellation, and the global launcher. Deep, Academic, and News are
subsequent measured additions.

## Non-goals for the first usable release

- browser automation or acting inside websites;
- replacing Safari or another full browser;
- multi-agent swarms;
- model training or fine-tuning;
- distributed crawling or queues;
- team accounts or cloud synchronization;
- mobile applications;
- an extension marketplace;
- a vector database without a retrieval failure that justifies one; and
- support for every inference or search provider.

## Honest public claims

The public project may eventually claim only what its artifacts prove:

- `local-first` when data boundaries are documented and tested;
- `one-install` after a signed release is reproduced on another Mac;
- `exact citations` after integrity and corruption tests pass;
- `fast` only with published p50/p95 measurements;
- `better` only against a named baseline on a frozen task set; and
- `forkable` only after a clean-checkout reproduction.
