# Innovation Thesis: Evidence-Native Generative Search

## The idea

Local Lens does not ask a model to write a page and sprinkle links into it. It
constructs evidence first, then generates a constrained interface whose factual
cells point back to that evidence.

```text
Evidence Graph                  Trusted Evidence UI

question                        brief
  +-- claim A -- passage 7  ---> paragraph + citation
  +-- claim B -- passage 3  ---> comparison cell + citation
  |          \-- passage 9  ---> confirmation badge
  +-- claim C -- conflict   ---> conflict card
  +-- gap D                 ---> research-this-gap action
```

The UI can adapt. The provenance rules cannot.

## Why it is different enough to matter

The defensible combination is:

- native Mac speed and OS integration;
- a local, inspectable research memory;
- adaptive comparison/timeline/paper views rather than chat-only prose;
- exact snapshot-and-passage citations;
- visible evidence maturity, independence, freshness, and conflict;
- deterministic citation compilation after model generation; and
- a learning layer generated from the user's own run.

Individual pieces exist elsewhere. The product bet is that combining them
around an evidence graph creates a daily tool that is more useful and more
trustworthy than another configurable research-agent demo.

## Recent enabling work

### Unified native model profiles

Apple's 2026 Foundation Models update describes a common `LanguageModel`
protocol for system, Private Cloud Compute, Core ML, MLX, and provider-backed
models, plus Dynamic Profiles that can change model, instructions, and tools
within a session. Local Lens maps each explicit mode policy to a profile while
keeping evidence and evaluation outside the model.

This is useful because it removes provider plumbing from the product concept.
It does not prove that any particular model meets Local Lens quality targets.

### Streaming agent and UI protocols

AG-UI defines event patterns for run lifecycle, activity snapshots/deltas,
messages, tools, and errors. A2UI defines a streaming declarative UI model with
separate component structure and data updates. Local Lens uses these as modern
protocol vocabulary while enforcing a narrower native schema:

- only allowlisted SwiftUI components;
- no remote code, HTML, arbitrary actions, colors, or layout;
- factual values require claim IDs;
- claim IDs require accepted evidence links;
- updates are versioned and replayable; and
- accessibility descriptions are part of each component contract.

### Context-aware retrieval

Recent contextual embedding work represents a passage using information from
its full document, addressing the ambiguity created when a useful chunk omits
critical context. This is a credible M004 challenger for long reports and
papers. It is not installed until the lexical baseline exhibits that exact
failure on Local Lens questions.

Recent listwise rerankers and passage-compression research are a separate
treatment for ordering failures after recall is already sufficient. Keeping
these diagnoses separate prevents expensive model experiments from hiding a
bad query, extractor, or corpus.

## Honest promotional language

Use:

> Local Lens is an evidence-native Mac search engine: it generates the right
> research view for your question and proves every factual cell with the exact
> saved passage.

Also defensible after the relevant milestones pass:

- “Native on Mac, inspectable by design.”
- “Quick answers, deep evidence.”
- “Your research memory stays searchable on your Mac.”
- “Benchmarked for citation correctness, not just answer style.”

Do not use until independently demonstrated:

- “the first”;
- “hallucination-free”;
- “private” when a hosted provider is active;
- “fully local” when search/network acquisition is active;
- “better than Perplexity”; or
- any benchmark leadership claim.

## Falsifiable product bets

1. Evidence UI improves correct citation inspection versus prose-only output.
2. Local Research Memory improves repeat-task latency without increasing stale
   claims when freshness labels and revalidation rules are enforced.
3. Mode-specific policies improve user success more than one general deep
   agent with a depth slider.
4. The reused research core plus native shell reaches usefulness faster and
   with fewer regressions than a Swift rewrite.
5. Contextual embeddings improve downstream citation support only on questions
   where relevant chunks depend on document-level context.

Each bet gets an experiment only when its milestone is active.
