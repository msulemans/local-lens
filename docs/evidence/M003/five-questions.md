# M003.5 frozen five-question set

Frozen 2026-09-23 before the first live call. The fifth question is not used to
tune the first four; it is reported as-is, or `not run` when a budget or blocker
prevents it.

Each question is scored on the packet's rubric:

- answer usefulness: 0-2 with a one-sentence rationale;
- citation validity: valid / total citations that resolve to the exact stored
  passage;
- citation completeness: supported factual spans / total factual spans;
- abstention or correction when the premise is false.

| # | Kind | Question | What a good result must do |
|---|---|---|---|
| 1 | Factual, primary source | How does Swift's structured concurrency cancel a task group? | Answer from Apple or Swift documentation and quote the exact cancellation rule. |
| 2 | Comparison, >= 2 independent sources | How do Swift structured concurrency and Grand Central Dispatch differ for CPU-bound work? | Name at least two independent sources, cite each side, and keep the comparison attributed. |
| 3 | Practical Mac/developer task | How do I enable FTS5 in the system SQLite on macOS? | Give actionable steps grounded in a primary or authoritative source, with a quoted command or API. |
| 4 | Recent fact, freshness visible | What is the latest stable Swift release in 2026? | Show the freshness of the source and avoid claiming recency without a dated source. |
| 5 | Unsupported/misleading premise | Why does Swift `async`/`await` always run on a background thread? | Correct or abstain: the premise is false (a nonisolated async function runs on the caller's executor unless declared otherwise). |

## Recorded per-question fields

For each run record: exact question, date/time, provider/model, search queries,
opened URLs and outcome counts, selected passage ids, first-evidence time, final
answer time, peak observed memory, prompt/completion tokens,
estimated/observed cost, answer usefulness (0-2), citation validity
(valid/total), citation completeness (supported spans/total), abstention or
failure behavior, and snapshot hashes. Private page bodies are never committed.

## Status

**Attempted with failures** (2026-09-23 20:31). All five were run against the
live provider at least once; none is scored as a success beyond Q1's single
completed CLI run, and Q1 itself then failed twice. Cumulative provider
attempts: 11 of 20. Estimated spend: under US$0.01 of the US$1 ceiling. Fields
that were not measured are marked *not measured*, never invented.

| # | Kind | Provider outcome | Citation validity | Citation completeness | Usefulness (0-2) |
|---|---|---|---|---|---|
| 1 | Factual, primary source | one completed CLI answer (3 citations); two later attempts `emptyAnswer` | 3/3 on the completed run | pending manual review | pending manual review; source was a third-party blog, not Apple/Swift docs |
| 2 | Comparison, >= 2 sources | `no verifiable claim`; propose `emptyAnswer` | 0/0 | not measured | 0 (no answer) |
| 3 | Practical Mac task | `no verifiable claim`; propose returned an honest refusal because retrieval was generic | 0/0 | not measured | 0 (no answer) |
| 4 | Recent fact | not called: `no retrieved evidence` | 0/0 | not measured | 0 (no answer) |
| 5 | Unsupported premise | `no verifiable claim`; propose returned an honest refusal (passages raised but did not answer) | 0/0 | not measured | 0 (no answer) |

Raw outputs are preserved in `/tmp/m003-live/q1.txt` through `q5.txt` and
`/tmp/m003-live/propose-q2.txt`, `propose-q3.txt`, `propose-q5.txt`.

Unknown or unmeasured for every question: peak memory, time to first evidence
(as distinct from total elapsed), and provider cost per question. Total elapsed
for the completed Q1 CLI run was 5.24 s.

Manual entailment review remains required: an exact quote is a mechanical check,
not proof that the quote supports the claim or that every factual sentence in
the answer is cited. No question is reported as passing until that review is
done and the answer is assembled from accepted claims with visible citations.

## Targeted reruns 2026-09-23 20:40 (calls 14-19)

After the fixes (junk-passage guard, one any-term relaxation, output cap
1,000 -> 4,000, displayed answer assembled from accepted claims), the four
questions that had failed a specific fix were rerun. Each completed run also
wrote a `LiveAnswerArtifact`.

| # | Original attempt (calls 3-7) | Targeted rerun | Citation validity | Citation completeness | Usefulness (0-2) |
|---|---|---|---|---|---|
| 1 | `emptyAnswer` | completed: 4 citations, 0 rejected (call 14) | 4/4 | 4/4 spans cited, but two quotes are weakly entailing | 1/2 |
| 2 | no verifiable claim | abstained: no verifiable claim (call 15); propose (call 19) found one exact claim over a question-shaped passage | 0/0 | not measured | 0 |
| 3 | no verifiable claim | abstained: no verifiable claim (call 16) | 0/0 | not measured | 0 |
| 4 | no retrieved evidence | completed: 1 citation, 1 rejected (call 17) | 1/1 | 1/1 span cited, but the answer gives a date without the version | 1/2 |
| 5 | no verifiable claim | abstained: no verifiable claim (call 18) | 0/0 | not measured | 0 |

Manual review is what lowers the two completed answers to 1/2:

- Q1's first two claims come from a "Discarding Task Groups" passage and one
  contains "cancellation tokens", which is not established Swift terminology.
  The quotes are exact, but an exact quote is not proof of entailment.
- Q4 quotes "March 24, 2026" from a "Swift 6.3 Released" passage but never names
  the version, so it does not clearly answer "the latest stable release".

The fifth question was not tuned against: it was run once in the batch and once
in the rerun and abstained both times, which is the correct behaviour for a
false premise (it did not assert that `async`/`await` always runs on a
background thread). It is reported as-is.

Not measured, not invented: time to first evidence, peak memory, per-question
cost. Cumulative provider attempts: 19 of 20. Cumulative spend: under US$0.02.

## M003.6 unchanged-card rerun (2026-09-25 AEST)

The five questions and rubric above were not changed. The current
non-thinking `deepseek-flash` Quick pipeline ran each exactly once with
planner-derived queries and live search; no supplied URLs or retries. Full
source, citation, timing, token, and manual-quality notes are in
`m0036-frozen-card-rerun.md`. Provider attempts under this separate record:
5/5, now spent. This does not reset the historical M003.5 20-call budget.

| # | Outcome | Exact citations | Manual completeness/relevance | Usefulness |
|---|---|---|---|---:|
| 1 | completed, 4 claims | 4/4 | Primary Swift Evolution source present; answer omits cooperative/waiting behavior | 1/2 |
| 2 | abstained | 0/0 | no sound two-source CPU-bound comparison | 0/2 |
| 3 | completed, 1 claim | 1/1 | build flag cited, but not the macOS system-library answer | 0/2 |
| 4 | completed, 1 claim | 1/1 | date quoted; version appears in source heading but not the exact quote | 1/2 |
| 5 | abstained | 0/0 | false premise not endorsed, not corrected | 0/2 |

Total usefulness remains 2/10, unchanged from the targeted M003.5 baseline;
the predeclared quality-promotion threshold was not met. Exact quote validity
does not erase the Q3 relevance or Q4 entailment failure.
