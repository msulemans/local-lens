# DeepSeek continuation: finish M003.5 from the current working tree

Prepared 2026-09-23 after the first live calls. Paste the block below into the
same coding-agent session, or a new session opened at this repository root.
This supersedes the earlier packet wherever its initial-state assumptions are
stale. Keep its two-hour, US$1, 20-call, offline-gate, and no-commit limits.

## Paste this into DeepSeek

```text
Continue M003.5 now from the current dirty worktree. Do not restart M003.5,
repeat setup, or ask the owner whether to continue. The owner has asked you to
continue autonomously within the existing M003.5 work packet and cost limits.
Spend up to 120 additional minutes on this continuation, with a short written
checkpoint every 15-20 minutes. Stop earlier only for a hard stop below.

Read AGENTS.md, LOCAL_BROWSER_STATE.md, project.json,
docs/DEEPSEEK_M0035_WORK_PACKET.md, this continuation, and the three current
M003 evidence files. Inspect git status and the existing live code before
editing. Preserve every uncommitted change; none has been committed.

Current state, to VERIFY:
- Branch main at 40c7ec3, with M003.5 uncommitted files. project.json still
  says M003.5 is active. Do not treat its older no-key blocker as current.
- SearXNG is already configured at 127.0.0.1:8888 and live search/fetch has
  worked. Check the existing container before touching Docker. Do not create a
  second instance or modify unrelated containers.
- The redirect-refusing URLSession transport is implemented in the dirty tree.
  Its loopback test and live redirect refusal were recorded. The separate
  DNS-resolution-to-connection TOCTOU risk remains recorded; do not claim it
  solved. Do not weaken the acquisition boundary.
- DeepSeek's actual current API model recorded here is `deepseek-flash`.
  Recheck the official API documentation only if the provider rejects it.
- The key was successfully read from Keychain in the earlier session, and
  DEEPSEEK_API_KEY is present in at least one current process environment.
  Check presence in YOUR process without printing its value. If absent, use
  the existing Keychain item `locallens-deepseek` (account `deepseek`) only if
  it is available to you. Never echo, log, persist, or commit the key. Do not
  hardcode it or request it in chat.
- Five frozen questions are in docs/evidence/M003/five-questions.md. The
  original batch outputs are in /tmp/m003-live/q1.txt through q5.txt.

Before any new API call, reconcile call accounting. The pasted transcript
describes at least 11 DeepSeek calls/attempts: an initial Q1, a Q1 rerun,
five-question batch, Q1 proposal run, and proposals for Q2/Q3/Q5. Inspect any
other local logs or provider usage visible to you. If the true count cannot
be established, assume 11 already used. That leaves at most 9 calls under
the ORIGINAL 20-call ceiling, not a fresh 20. Keep the original cumulative
US$1 ceiling. Record the count and cost estimate in the session log. Never
reset either budget just because a new agent turn starts.

The five batch outputs currently read:
Q1 provider failed: emptyAnswer.
Q2 no verifiable claim.
Q3 no verifiable claim.
Q4 no retrieved evidence.
Q5 no verifiable claim.
A separate Q1 `--mode propose` call returned two claims with exact quotes from
one passage. This is useful provider proof, but it is not a completed native
answer and does not prove the claims answer the question well. Q2 retrieval
included single-character punctuation, Q3 retrieved generic SQLite build
instructions rather than macOS system SQLite instructions, and Q5 retrieved
passages that raise the threading question without answering it. Preserve
these failures in the evaluation; do not call the batch 5/5 successful.

Work in this order:

1. Bring the evidence record up to date before changing behavior. Append the
   actual provider attempts, batch outcomes, and token/cost facts to
   docs/evidence/M003/live-quick-session.md. Update the five-question card's
   status from “not run” to “attempted with failures”, with unknown fields
   marked unknown. Do not record live-provider success in project.json until
   there is end-to-end proof. Keep the old failed outputs intact.

2. Diagnose tiny passages using the saved run output and the existing
   HTMLExtraction -> SnapshotStore -> LexicalIndex -> LiveQuickRunner path.
   Add a focused offline fixture that reproduces a punctuation-only block.
   Make the smallest production change at the selection boundary so empty,
   punctuation-only, navigation, and obviously fragmentary passages cannot
   consume the 12-passage budget. Preserve exact passage text and hashes;
   never fabricate or concatenate evidence. If a substantive page yields
   only junk, report an extraction failure/abstention. Do not tune a model or
   add a new parser, vector store, reranker, or agent framework.

3. Diagnose why Q4 got zero passages. Inspect whether SearXNG returned useful
   sources, fetch/extraction discarded them, or FTS5's all-term query missed
   relevant stored passages. Use one focused, deterministic query relaxation
   only if the stored evidence supports it. Do not treat a search snippet as
   evidence or make an unrelated M004 retrieval project.

4. Diagnose `emptyAnswer` without guessing. In a local diagnostic that does
   not print reasoning content or secrets, capture provider HTTP status,
   choice finish_reason, whether message.content is nil/empty, and reported
   token usage. Consult official DeepSeek documentation for the current
   response shape. If the output cap caused truncation, change the cap only
   after updating the frozen experiment record, cost estimate, and tests.
   If it was a transient empty response, allow at most one bounded retry
   for that question within the remaining call and cost budgets. Do not turn
   repeated empties into a retry loop.

5. Tighten the answer trust boundary before celebrating an exact quote. The
   current AnswerTrust checks passage ID and exact substring; it does not
   prove that the quote entails the proposed claim or that every factual
   sentence in proposal.answer is cited. Ensure the displayed answer is
   assembled from accepted claims with visible citations, or refuse prose
   spans without a checked claim. Add focused offline tests for unsupported
   prose, misleading exact quotes, unknown IDs, and a valid cited answer.
   Manual entailment review remains required for the five live questions.

6. Run the frozen questions again only where a specific fix predicts a better
   result, counting every new provider attempt. Prefer cheap `retrieve` runs
   to inspect the evidence before spending a provider call. Record all five
   original attempts and targeted reruns in the card. Keep the fifth question
   as a test of the false premise; do not tune against it and then present it
   as held out.

7. Wire the resulting live answer into the native Quick view, with an explicit
   hosted label and clickable exact-passage citations, if the earlier steps
   produce trustworthy accepted claims. The CLI `--mode propose` and
   `--mode answer` are diagnostic steps, not the M003.5 product gate. Verify
   the native window and passage inspector. Keep the M001 deterministic view
   and default tests offline.

8. Run make gate and git diff --check. Record the current test count, all
   live outcomes, time to first evidence, answer latency, source URLs/hashes,
   citation validity AND completeness, manual answer-usefulness judgments,
   observed/estimated tokens and cost, and peak memory where measured.
   Mark missing metrics “not measured”, never invented. Update
   LOCAL_BROWSER_STATE.md and project.json together if proof or blockers
   change; run make validate-manifest. Keep M003.5 active until its exact
   done_when list is met. Record the architecture decision only with evidence.

At every checkpoint: state elapsed time, cumulative provider attempts/cost,
last observed failure, the next smallest action, and make gate status.
Continue independently after a fix; do not ask “want me to keep going?”

Hard stop: 120 minutes for this continuation; 20 cumulative provider
attempts; US$1 cumulative spend; key unavailable after checking the existing
Keychain item; unsafe DNS/redirect behavior; a required change to a frozen
protocol/entity or an unlicensed sibling copy; or three consecutive
checkpoints without meaningful progress. Stop with a precise handoff, not a
claim of completion. Do not commit, publish, deploy, delete user data, or
modify unrelated containers.
```

## Why this continuation is narrower

The first packet started from no live answer. There is now a partial live path
and a specific quality failure. Another round of setup or architecture work
would spend time without improving the product. The immediate product proof is
one useful answer in the Mac window whose factual claims each resolve to a
relevant stored passage, followed by an honest five-question card.

The previous agent's “exact quote” output is a mechanical check only. A quote
may be exact yet irrelevant or misleading. The user facing answer needs both
an exact citation and a source that actually supports the claim.
