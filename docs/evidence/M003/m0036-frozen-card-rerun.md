# M003.6 frozen five-question rerun — non-thinking Quick

Recorded 2026-09-25 AEST before any provider request under this record.
Questions and scoring rubric are **unchanged** from `five-questions.md`. The
same existing DeepSeek model is used; no provider or model bake-off.

```text
Experiment ID: M003.6-frozen-card-nonthinking
Measured failure: M003.5's five-question card had only two partially useful
  answers; Q2, Q3, Q5 were 0/2. M003.6 direct-page app attempts produced
  ambiguousQuote and emptyAnswer, though a later open app window showed a
  three-citation forum answer of uncertain run provenance.
Existing baseline and score: M003.5 card: Q1 1/2, Q2 0/2, Q3 0/2,
  Q4 1/2, Q5 0/2; exact citation links did not establish full entailment.
Why this candidate could treat the failure: The current pipeline filters
  question-ending passages, isolates ambiguous claims, and disables the
  DeepSeek reasoning mode that may consume output before final JSON. The
  same five questions reveal whether those changes improve answer usefulness.
Exact model/revision/hash: deepseek-flash (DeepSeek-V4.1-Flash as documented
  2026-09-25); hosted immutable revision/hash unavailable, so no stable
  model-quality promotion claim.
Licence and redistribution constraints: Hosted DeepSeek API terms; no
  weights or fetched page bodies redistributed. Only public saved passages
  selected by the live pipeline are transmitted; outputs are labelled hosted.
Runtime and integration path: LocalLensLive answer mode invokes the same
  LiveQuickRunner, DeepSeekAnswerProvider, safe fetch, index and citation
  compiler used by the Mac window. This CLI run measures the pipeline, not
  the app UI. Key comes from the existing environment and is not logged.
Frozen development tasks: The five exact questions in five-questions.md,
  in listed order. No manual queries or supplied URLs.
Frozen sealed tasks: none beyond the fifth unchanged question.
Quality promotion threshold: Report source relevance, entailment, citation
  validity/completeness, usefulness 0-2, and abstentions for each question.
  The card is only a useful Quick promotion if at least four questions score
  >=1/2, Q5 does not endorse its false premise, every displayed citation
  resolves exactly, and Q1/Q4 meet primary-source/freshness requirements.
Latency ceiling: 60 seconds per question; product target p50 <20s/p95 <40s.
Peak memory ceiling: <=2 GB additional RSS; unmeasured stays unknown.
Disk/download ceiling: no model download; artifacts stay under /tmp and
  private/live page bodies are not committed.
Maximum runs/calls/tokens/cost: one attempt per question, five maximum;
  <=4,000 prompt and <=4,000 completion tokens per call. At peak Flash rates,
  <=US$0.006 per call and <=US$0.03 for the card. Recorded cumulative
  provider-attempt minimum before this record: 23 from prior recorded runs,
  plus at most one newly observed in-app run with unconfirmed provenance;
  do not silently treat the old M003.5 20-call ceiling as unused.
Stop condition: no retries on failures or abstentions. Stop the card if the
  search endpoint fails, the key disappears, a hard security boundary fails,
  or the five-call cap is reached. Preserve each result separately.
Rollback path: Keep the M003.5 card as baseline and the deterministic demo;
  revert the targeted request/retrieval changes if this measured card worsens.
```

Official API basis: [DeepSeek Chat Completions](https://api-docs.deepseek.com/api/create-chat-completion/),
[Thinking Mode](https://api-docs.deepseek.com/guides/thinking_mode/),
[Models & Pricing](https://api-docs.deepseek.com/quick_start/pricing/).

## Retrieval-only preflight

The existing local SearXNG endpoint returned 20 results for a single Q1
search-only probe, though brave was rate-limited, duckduckgo/startpage showed
CAPTCHA, and wikipedia timed out. The frozen five retrieval-only runs then
produced:

| Q | Opened | Selected | Preflight judgment |
|---|---:|---:|---|
| 1 | 4 | 11 | Swift Evolution primary page opened, with substantive group-cancellation passages lower in the selection. |
| 2 | 6 | 3 | Mostly generic GCD/structured-concurrency text; CPU-bound comparison not established. |
| 3 | 5 | 1 | SQLite primary FTS5 build-flag passage, but not an answer about macOS system SQLite. |
| 4 | 5 | 9 | Swift.org 6.4 release title and September 15, 2026 date opened, in separate passages. |
| 5 | 5 | 2 | Neither selected passage clearly corrects the false background-thread premise. |

These are discovery/retrieval observations, not answer scores. Search snippets
were not used as evidence. Provider-run results follow below.

## One-pass provider results

Ran the five exact frozen questions once each, in order, using the current
`deepseek-flash` non-thinking Quick request. No retry, manual query, or
supplied URL. `--out` wrote completed artifacts to
`/tmp/m0036-20260925-q1.json`, `q3.json`, and `q4.json`; Q2 and Q5 abstained
and wrote none. The artifacts contain fetched passage text and stay outside
git. This is CLI pipeline proof; the separately observed native-app answer
below is UI proof, not this card's execution path.

| Q | Outcome | Time | Tokens prompt/completion | Exact citation validity | Factual-span citation completeness | Manual entailment and relevance | Usefulness |
|---|---|---:|---:|---|---|---|---:|
| 1 | 4 accepted claims, 0 rejected | 8.69s | 748 / 322 | 4/4 | 4/4 displayed spans | Three citations use the Swift Evolution proposal and one uses Hacking with Swift. The claims follow the quotes, but the answer omits cooperative cancellation and the group's wait-for-children rule; primary source is present, overall coverage is partial. | 1/2 |
| 2 | abstained: no verifiable claim | not measured | not measured | 0/0 | not applicable | Preflight had three mostly generic passages and no sound two-source CPU-bound comparison. Honest abstention. | 0/2 |
| 3 | 1 accepted claim, 0 rejected | 7.53s | 199 / 118 | 1/1 | 1/1 displayed span | SQLite's primary FTS5 page supports defining `SQLITE_ENABLE_FTS5` when compiling SQLite, but the question asks about the **system SQLite on macOS**. It gives no usable system-library step. | 0/2 |
| 4 | 1 accepted claim, 1 rejected | 7.61s | 405 / 119 | 1/1 | 1/2 factual fields | Swift.org's page heading says “Swift 6.4 Released” and the exact quoted passage says “September 15, 2026”. The displayed single claim combines version and date but cites only the date quote. Source and freshness are credible; exact quote does not by itself cover the version field. | 1/2 |
| 5 | abstained: no verifiable claim | not measured | not measured | 0/0 | not applicable | It did not endorse the false always-background-thread premise, but did not explain the correction. | 0/2 |

The completed artifacts mechanically resolve every displayed citation to an
exact stored passage (6/6 total); that does not make the Q3 answer relevant
or the Q4 compound claim fully entailed. The card's usefulness total is
**2/10**, the same as the M003.5 baseline, and only two questions reach 1/2.
The predeclared promotion threshold (four questions >=1/2, Q5 safe, exact
citations, Q1/Q4 primary/fresh) is **not met**. It is a measurement, not a
Quick-release promotion.

Five provider attempts were made under this record, reaching its cap.
Recorded prior minimum was 23, so the cumulative recorded minimum is now
**28**, excluding the separately observed app answer whose trigger and
request revision cannot be established. Actual provider cost and token usage
for Q2/Q5 are unavailable; with the predeclared per-call ceilings, estimated
card cost is <=US$0.03, not an observed invoice. First-evidence time, peak
RSS, and individual opened-source counts for the answer runs were not
measured; the preflight counts above must not be substituted for them.

## Native-app observation separate from card

At approximately 21:11 AEST, computer use opened an already-running Local
Lens process and found a completed hosted answer to “How does Swift cancel a
task group?” using the supplied Swift forum page. The UI displayed three
citation markers and 11.3s elapsed. Each citation was selected in the
evidence rail; its exact quote and saved passage supported the displayed
claim about waiting for children, cooperative cancellation, or unstructured
tasks. This is a **locally observed in-app cited answer**, not an artifact
loaded from the CLI. The action that initiated the run was not performed in
this turn, and the running process's request revision was not observable.
It must not be credited to the non-thinking change or folded into the frozen
card's provider-call count. The forum source also does not satisfy the card's
Q1 primary-documentation requirement. The computer-use screenshot remains
in the tool session, not a repository file.

## Decision

The M003.6 measurement gate was executed, but answer quality was **not
promoted**. Do not run another provider call under this spent five-call
record. The measured next treatment is source relevance and complete claim
entailment, not another model bake-off: Q2 needs two substantive CPU-bound
sources, Q3 needs macOS system SQLite evidence, and Q4 must cite version and
date as separately supported facts or one passage containing both.
