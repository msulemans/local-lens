# Adopt, Adapt, Build Ledger

This ledger prevents two bad outcomes: rebuilding mature infrastructure for no
reason, and assembling fashionable projects without a coherent product.

`Adopt` means reuse code or a supported API after licence and compatibility
checks. `Adapt` means borrow a bounded pattern or protocol shape while writing
our own contract. `Build` is reserved for Local Lens differentiation.

## Reuse matrix

| Source | Decision | What enters Local Lens | What does not | Gate |
|---|---|---|---|---|
| local `../deep-research-agent` | Adopt | domain/state, adapter protocols, SearXNG, safe acquisition, HTML/PDF extraction, FTS5 retrieval, ranking/dedup, artifacts, report/citation validation, evaluators, fixtures/tests | existing web UI and monolithic API/controller shape | ownership/licence recorded; extracted package tests pass unchanged |
| Apple Foundation Models 2026 | Adopt API | `LanguageModel` boundary, structured generation, Dynamic Profiles, Evaluations where useful | OS availability assumed for every Mac; one model forced on every mode | availability fallback and per-backend benchmark |
| MLX Swift LM | Adopt conditionally | custom local model adapter if measured hardware/model result passes | model bake-off or mandatory multi-GB download | M003 experiment record |
| SQLite/FTS5 | Adopt | local metadata, passages, lexical retrieval, Research Memory | external vector DB | measured M004 entry criterion |
| SearXNG | Adopt baseline | replaceable metasearch adapter and developer/live baseline | mandatory Docker for normal users | M002 no-Docker release path |
| Morphic | Adapt | streamed grounded results and finite adaptive answer concepts | Next.js product shell, Postgres/Redis deployment | Evidence UI schema tests |
| AG-UI | Adapt | lifecycle/activity/event vocabulary and compatibility direction | framework/runtime dependency in v1 | versioned internal event contract |
| A2UI | Adapt | streamed declarative surface/data separation | arbitrary components/actions or remote executable UI | finite trusted SwiftUI catalogue |
| SurfSense | Adapt | installer-led onboarding, hardware-aware model choice | broad connector scope before Quick works | fresh-machine usability proof |
| Starcat | Adapt | native conversation rail, citation inspector, execution trace | wholesale app/code copy | selected design and accessibility review |
| PaperLens | Adapt | progressive academic results, paper matrix, citation graph, exports | Academic features in the Quick milestone | M005 held-out set |
| lilbee | Adapt | exact citation/no-answer discipline and one-command contributor experience | CLI-first product surface | clean-clone gate |
| Perplexica | Adapt | focus/mode discovery and query expansion lessons | web clone and infrastructure-first onboarding | real mode policy tests |
| Local Deep Research | Study | deep research breadth and benchmark coverage | importing its full stack or provider complexity | M007 bounded-loop need |
| OpenDraft | Adapt | DOI existence/version cross-checking | treating metadata presence as claim evidence | M005 entailment tests |
| contextual embedding research | Conditional experiment | document-aware passage challenger | default embedding dependency | labelled M004 recall failure |
| listwise reranking research/Jina | Conditional experiment | ordering challenger | reranker by reputation | adequate recall plus measured rank failure |

## Sibling extraction boundary

The sibling package contains 184 discovered unit tests and the following useful
seams:

- `deep_research.domain`, `events`, and `state_machine`;
- `adapters.protocols` and deterministic fakes;
- `discovery.search`, `ranking`, `dedup`, and `retrieval`;
- `acquisition.safety`, `robots`, `fetcher`, `extraction`, `rendering`, and
  `safe`;
- `pipeline.report` for report/citation compilation and validation; and
- `evaluation.integrity`, `semantic`, `e2e`, and `systems`.

The current `pipeline.controller` and FastAPI module are references, not the
ideal public boundary. M001 extracts smaller services behind versioned command,
event, and entity schemas. The Mac app must not import Python internals or rely
on sibling-relative paths.

## Licence and provenance stop sign

No `LICENSE` file was present at the sibling root during the 2026-09-22 audit.
Because a forkable public repository is a product requirement, direct copying
is blocked until ownership is confirmed and a licence is applied deliberately.
The extraction commit must record source paths and the sibling revision
`1b1a698` observed during planning.

## Dependency acceptance record

Before a dependency becomes shipping code, record:

1. exact revision and licence;
2. user-facing capability it enables;
3. installed and runtime size;
4. supported architecture and OS floor;
5. privacy/network behavior;
6. deterministic verification command;
7. failure/fallback behavior; and
8. removal boundary.

Stars, X attention, or benchmark claims are discovery signals—not acceptance
criteria.
