# Milestones and Gates

Only one milestone may be active. A gate is frozen before implementation and
is never weakened after its result is known.

## M000 - Product contract

Status: **complete**

Delivered product, architecture, evaluation, model, safety, learning, visual,
decision, and reference documents plus the canonical state file.

The 2026-09-22 correction adds the complete plan, code-reuse ledger,
Evidence-Native Generative Search thesis, recent enabling research, and hybrid
native/reused-core architecture.

Gate: see `LOCAL_BROWSER_STATE.md`.

## M001 - Reuse foundation and deterministic native vertical slice

Status: **complete** (gate audit `docs/evidence/M001/gate-audit.md`; declaration D015). Sibling extraction stays licence-gated (D011, task R1).

Learn:

- package extraction and cross-language boundaries;
- software licence and provenance discipline;
- Swift package and app structure;
- actors and cancellation;
- typed state machines;
- content addressing;
- dependency inversion; and
- why deterministic fixtures are instruments.

Build:

- resolve sibling ownership/licence/provenance;
- extract the sibling research seams into versioned `ResearchCore` boundaries;
- preserve the relevant existing deterministic tests;
- versioned authenticated local IPC plus event and Evidence UI schemas;
- native app and Swift presentation/core package;
- versioned entities/events;
- fake providers;
- frozen fixture corpus;
- full question-to-cited-answer slice;
- minimal Living Research Map screen; and
- unit plus UI verification.

Gate: recorded in `LOCAL_BROWSER_STATE.md`.

## M002 - Safe live acquisition

Status: **complete**, with the approved-live-corpus portion explicitly
unproven because no redistributable corpus approval was recorded. M002.1–M002.8
are complete. M003 is the sole active milestone. M003.1–M003.4 are completed;
M003.5 has a recorded live hosted slice; M003.6–M003.8 completed bounded
implementation/measurement tasks, but the Quick answer card remains below its
quality threshold. M003.9 and M003.10 are complete, and **M003 is complete with
every gate bullet recorded**: a trailing-slash redirect fix restored Apple and
Swift.org primary sources, the unchanged five-question card measured **7/10 with
13/13 exact citations** (Quick promoted from 2/10), peak app RSS was 140 MB, the
no-Docker app path was driven in the app, and the committed deterministic path
reproduces from a clean checkout. Q5 still abstains rather than correcting its
false premise, and the bundle is ad-hoc signed without second-Mac proof. The
next milestone is M004, which opens with an entry check and may be recorded
`not needed`. See
`project.json` and `LOCAL_BROWSER_STATE.md` for the current task and proof
boundary.

Learn:

- metasearch uncertainty;
- DNS and SSRF safety;
- HTTP semantics, robots, redirects, MIME and size limits;
- HTML extraction loss;
- PDF boundaries; and
- concurrency with polite per-host limits.

Build:

- SearXNG adapter;
- safe HTTP acquisition;
- HTML extraction;
- content snapshots;
- bounded parallel fetch;
- extraction diagnostics; and
- approved live corpus tests.

Gate:

- static HTML, redirects, PDF, duplicates, blocked paths, oversized content,
  invalid MIME, private addresses, timeouts, and extraction failures all produce
  expected typed outcomes;
- search snippets never become evidence;
- retries do not duplicate snapshots; and
- the deterministic M001 slice remains unchanged.

## M003 - First useful Quick release

Learn:

- local model capability boundaries;
- structured generation;
- streaming and cancellation;
- context and memory budgets;
- latency measurement; and
- packaging a native AI feature.

Build:

- FTS5/BM25 retrieval and deterministic source features;
- one approved local inference adapter;
- Quick mode end to end;
- citation compiler and inspector;
- history;
- global launcher;
- hardware-aware onboarding; and
- first packaged development build.

Gate:

- five frozen and five fresh representative searches complete;
- citation integrity is 100%;
- every failure has a typed reason;
- latency and peak resource use are recorded;
- no Docker or terminal is required for the app path; and
- a clean checkout reproduces the deterministic path.

This is the first usable product checkpoint.

## M004 - Living Research Map and four-mode product surface

Status: active (redefined by the owner directive of 2026-09-26; see D034).
The original conditional retrieval-treatment entry check is deferred and its
decision remains unrecorded.

Build:

- the Living Research Map as the primary surface: question, mode,
  local/hosted boundary, elapsed time, pause, and cancel in one toolbar;
- frozen per-mode execution policies (Quick, Deep, Academic, News) enforced in
  code, with deterministic query and dimension planning;
- a living brief per mode, an evidence map grouped by decision criteria, sparse
  provenance ribbons, exact-passage inspection, and a bounded
  `Research this gap`;
- research history and a global launcher;
- a no-Docker, no-terminal path for search (Tavily user key), scholarly
  discovery (OpenAlex), and the hosted answer provider.

Delivered in M004.1 (implemented, locally observed):

- the surface above, replacing the one-form Live Quick window;
- `ModePolicy`, `ResearchPlanner`, `ResearchRunner`, `OpenAlexSearchAdapter`,
  `NewsIndependence`, and `ResearchHistoryStore` in `LocalLensCore`;
- 261 deterministic tests, the M001 fixture and offline guards unchanged.

Delivered in M004.2 (implemented, locally observed):

- Academic now selects 22 passages from 6 opened sources (was 0), because
  OpenAlex prefers open-access landing pages and bounded general-web discovery
  fills the remaining fetch slots after the scholarly hits;
- News independence was observed on an answered local run with 6 distinct
  domains and an explicit uncovered dimension;
- the local answer boundary (`LocalAnswerProvider`) is live behind an explicit
  Connection toggle, labelled `local/<model>`;
- 264 deterministic tests pass.

Delivered in M004.3 (measured):

- the frozen card was run against the local model: 6/10 usefulness, 10/10
  exact citations, Q2 over the 60 s ceiling, Q5 failing correct-or-abstain;
- the local path is **not promoted** and stays an explicit, labelled
  alternative;
- M004 is complete; M005.1 is the sole active task.

Gate:

- Academic mode selects at least one usable passage set from a scholarly
  landing page, or records a typed abstention with a regression test;
- News independence is observed on one answered run or recorded as a view gap;
- `make gate` passes with the offline guards unchanged and the M001 fixture
  untouched; and
- no model, reranker, embedding, vector database, or external service is added
  without a filled `docs/MODEL_POLICY.md` record.

Explicitly not in M004.2: the M005-M009 feature scopes, local inference
selection, and notarized distribution.

## M005 - Academic mode

Build:

- OpenAlex, Crossref, Semantic Scholar, and arXiv boundaries;
- DOI/version reconciliation;
- PDF/page-aware evidence;
- paper comparison and limitations;
- citation-neighborhood expansion; and
- BibTeX/RIS export.

Gate:

- authoritative metadata is traceable;
- exact paper passages/pages support generated claims;
- duplicate versions are reconciled without losing provenance;
- unsupported questions abstain; and
- the academic held-out set beats generic web search on citation quality.

Delivered (M005.1-M005.4): arXiv and Crossref boundaries with DOI/versionless
arXiv reconciliation; a run-scoped scholarly budget that reserves fetch slots
for readable sources; page-aware PDF extraction through PDFKit; cited-only
BibTeX/RIS/Markdown export; a frozen held-out retrieval comparison that tied
(58% vs 54%) and is preserved; primary-source discovery ordering; and a held-out
answer card, run locally at US$0, that favours the shipped Academic policy 5/6
against 3/6 at 100% citation integrity. **Status: complete** with the
equal-budget confound recorded. 274 tests pass.

## M006 - News mode

Build:

- temporal queries;
- event and syndication clustering;
- source-independence scoring;
- current-event timelines;
- conflict treatment; and
- update timestamps.

Gate:

- stale pages do not masquerade as current reporting;
- syndicated copies do not count as independent confirmation;
- material claims have independent evidence or visible uncertainty; and
- a frozen snapshot set makes regression comparisons reproducible.

Delivered (M006.1): the frozen 14-day window is enforced at discovery (stale
and undated results are excluded and counted); syndicated headlines collapse to
one independent voice while short headings never merge; the timeline orders
voices newest first and never invents a date; and each cited claim carries how
many independent voices back its page, so a single-source answer is shown as
uncertain. **Status: complete**, with the live copy test recorded as not
demonstrated and news-page heading quality recorded as an open defect. 282 tests
pass.

## M007 - Deep mode

Build:

- editable dimension plan;
- bounded follow-up research;
- coverage and contradiction matrices;
- diminishing-evidence stop rule;
- pause/resume;
- `Research this gap`; and
- full Living Research Map provenance ribbons.

Gate:

- every loop terminates with a typed reason;
- repeated queries and sources cannot consume unlimited budget;
- injected failures resume without duplicated evidence;
- contradictions are not silently flattened; and
- controlled long-form benchmarks and manual review are reported separately.

Delivered (M007.1): the dimension plan is editable and validated against the
frozen per-mode caps with typed refusals; every round ends with one recorded
typed reason and the brief shows `STOP · <reason> — <explanation>`; an injected
transport failure in a later round keeps the earlier evidence, stores the page
once, and duplicates no passage; and secrets are read on demand rather than at
launch. Still open in M007: content-term coverage (measured weak), contradiction
matrix, diminishing-evidence stop rule, and full provenance ribbons.
**Status: partially complete, M007.2 active.** 287 tests pass.

Delivered (M007.2): coverage matches a dimension by label or by a fixed
in-code term list, which removed the false zeros that made Deep spend a
follow-up round on a gap that did not exist (`Overview 0/Evidence 0/Tradeoffs 0`
became `1/4/2` on the same question); a follow-up that adds half or less of the
previous round stops with `diminishing_returns`; and a strict numeric-contrast
detector pairs two pages that state different values for identical context
words, never averaging or resolving them. **M007 status: complete with one part
recorded as not demonstrated** — live numeric contradictions were not found, and
two looser detectors were measured to produce citation-list noise and rejected.
290 tests pass.

## M008 - Evaluation and learning studio

Build:

- benchmark runner and variant comparison;
- human citation-review workflow;
- corruption tests;
- per-mode scorecards;
- generated learning lessons; and
- explain-back exercises.

Gate:

- integrity target is 100%;
- semantic evaluator is calibrated against held-out human labels;
- answer and citation metrics are not collapsed into one score;
- local and hosted results remain separate; and
- intentional corruptions are detected.

Delivered (M008.1): a JSON benchmark card replays through a scorecard that
records citations, accepted and rejected claims, latency, opened sources, the
typed stop reason, and whether every citation resolved, with answer usefulness
left unscored until a human scores it; local and hosted runs are separate
documents; and four citation-boundary corruptions (altered quote, missing
passage, mismatched claim, unknown citation) are all refused. The five-question
card replayed against the local model at US$0 at **100% citation integrity** and
`usefulness unscored over 0/5 scored`. Still open in M008: human review labels,
the semantic evaluator and its calibration, generated lessons, and explain-back
exercises. **Status: partially complete, M008.2 active.** 294 tests pass.

## M009 - Public Mac release

Build:

- signed and notarized distribution;
- model/storage management;
- Keychain settings;
- accessibility and reduced-motion coverage;
- recovery and privacy-safe diagnostics;
- second-machine reproduction;
- demo and public benchmark card; and
- contributor onboarding.

Gate:

- a new user installs and completes a search from the release artifact;
- a contributor builds and verifies a clean clone using documented commands;
- no secret, private snapshot, or unlicensed benchmark body is present;
- the public README claims match reproduced evidence; and
- licence selection is complete.

Delivered (M008.2 and M008.3): a review packet is generated from a run with every
claim's exact quote and source URL; a reviewer fills it in and the tool applies it,
refusing an unknown question, an unknown verdict, or an out-of-range score while
leaving anything blank unscored. Answer usefulness and citation integrity stay in
separate fields, and local and hosted runs are separate documents. A
deterministic evaluator predicts usefulness from counted features and reports
itself uncalibrated below 20 labels; over the five provisional labels it agrees
3/5 with mean error 0.40. Learning cards are generated from the run itself —
exact quotes, typed rejected-claim reasons, coverage, and explain-back prompts —
and an abstention produces its own lesson. **Status: M008 complete except the
calibration target, which is blocked on independent labels.**

Delivered (M009.1): a release build that signs with the best identity available
and records in `BUILD-INFO.json` exactly why it did not notarize; nine automatic
release checks (identifier, signature, no credential, no weights, two public
fixtures only, no fetched page bodies, no key files); a Storage & privacy panel
with on-disk counts and a confirmed delete; a diagnostics bundle proven by test
to carry no question, answer, quote, or credential; a first-run card; reduced
motion; and `make demo` plus `make reproduce`, where reproduction refuses a dirty
tree. **Status: M009 partially complete.** Notarization is blocked (no Developer
ID), second-machine reproduction is unproven, and the licence is the owner's
choice; all four external dependencies are packaged in `docs/HANDOFF.md`.

## M009.2 - Hosted verification of all four modes

Eight hosted DeepSeek answer calls, four through the command-line tool and four
through the app, with the app observed through its accessibility tree. Quick 6
passages / 6.3 s, Deep 12 / 8.0 s with the comparison plan, Academic 13 / 25.2 s
with a paper matrix, News 3 / 15.9 s with the window, ten domains, and a dated
timeline. Three credential faults were found; the provider check ran before the
keychain read, so the first Ask after a launch always failed with "No answer
provider is configured", and a refused keychain read was reported as an empty
slot. Both are fixed, and the panel now explains that a rebuilt development
bundle loses its keychain grant because macOS ties the grant to the code
signature. The run measured three defects in the modes, recorded rather than
fixed here: News enforced recency but not relevance, a News answer reported ten
domains while every claim was single-source, and coverage counted keyword
coincidence. Evidence: `docs/evidence/M009/m0092-hosted-four-mode-ui.md`. D046.

## M009.3 - Three mode defects fixed and the workspace redesigned

Delivered: `NewsRelevance`, which filters News discovery against the question by
phrase, two content terms, or one distinctive word, refuses to starve a run, and
whose first version is preserved in a test as a measured failure because it kept
anything sharing one term and dropped nothing on a live run. `NewsClaimDepth`,
so a claim set no second voice carries is named instead of implied by a domain
count. Whole-word, tiered `DimensionLexicon` matching, so a year is not timeline
evidence and one "however" is not a gap. Two wiring bugs fixed: the contradiction
scan and the claim depth were computed and never passed to the report, so the
contrast panel could not have rendered for any run. A rebuilt workspace on
`DesignSystem.swift`, following `docs/design/local-lens-living-research-map.png`:
an adaptive question field that grows to six lines with a visible boundary, one
accent for evidence, sentence case throughout, a comparison table whose cells
are measured counts rather than the mockup's invented `Excellent / Good / Fair`
verdicts, a paper matrix, a confirmation panel, an evidence map in the side
column with a selected-passage inspector, and a narrow layout that moves the
evidence column into a sheet. All four modes re-verified in the app hosted:
Quick 5 / 9.0 s, Deep 11 / 6.8 s, Academic 13 / 20.2 s, News 7 / 9.9 s.
`swift test`: **315 tests, 0 failures**. Evidence:
`docs/evidence/M009/m0093-defects-and-redesign.md`. D047, D048.

**Status: M009 partially complete.** Notarization is blocked (no Developer ID),
second-machine reproduction is unproven, the licence is the owner's choice, and
calibration needs 20 human labels; all four external dependencies and their
close commands are in `docs/HANDOFF.md`. The remaining observation gaps - the
app's refusal path for an invalid plan, a live copy or syndication pair, a live
numeric contradiction, publisher refusals - are M009.4.

## M009.4 - Owner-directed Mac UI close-out (in progress)

The current-run, numbered visual audit is
`docs/evidence/M009/m0094-ui-closeout-audit.md`. It found and repaired stale
answers after question edits, a privacy count that did not load on opening,
misleading hosted-data and citation-verification copy, destructive history
deletion without confirmation, and an empty custom plan that silently fell
back to defaults. The old Quick-only prototype and synthetic fixture remain
internal regression scenes but have no normal Research-menu entry. The default
app is one four-mode workspace. These UI changes do not close the separate
answer-usefulness, live-observation, second-Mac, notarization, or human
calibration gates. The owner subsequently authorized permissive reuse: MIT in
the root `LICENSE` closes the repository-licence choice. Four unedited app
screenshots and draft X copy are in `docs/social/2026-09-26/`; the News image
is a mode preview, not a verified answer.
