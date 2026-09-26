# AI and Contributor Handoff

`project.json` is the compact machine-readable handoff for another model or
contributor. It does not replace the chronological evidence in
`LOCAL_BROWSER_STATE.md` or the rationale in the planning documents.

The current task is **M009.4** in `project.json`: close the recorded live
observation gaps without weakening a gate. The owner authorized a public MIT
release of this repository; the three external gates still open are independent
human review, second-Mac reproduction, and Developer ID notarization. Use
`docs/HANDOFF.md` for their exact close commands. The next paragraph is
historical M003 context, not a current task.

**M003 is complete** with every gate bullet met; the unchanged card measured 7/10 with
13/13 exact citations after a deterministic trailing-slash redirect fix, so
Quick is promoted ([card](evidence/M003/m003-frozen-card-treated.md),
[close-out](evidence/M003/m003-gate-closeout.md)). If a challenger is proposed,
`docs/MODEL_POLICY.md` needs a filled experiment record first. The owner
supplied a free Tavily key and approved saving it and the existing DeepSeek key
in the Local Lens Keychain item. The
current Mac app performed real Tavily no-AI search and one pre-recorded hosted
Ask with four exact clickable citations in 6.0 seconds
([result](evidence/M003/m0039-tavily-in-app-answer.md)). That is product-flow
proof, **not** a Quick release-quality promotion. A four-question Tavily
retrieval [preflight](evidence/M003/m0039-tavily-retrieval-preflight.md) found
Q2/Q3/F1/F5 gaps; one narrow lexical treatment then selected the official
Python F1 passage ([diagnostic](evidence/M003/m0039-f1-passage-probe.md)), and
the current app reproduced it through its own no-AI path under driven UI
([app check](evidence/M003/m0039-f1-app-check.md)). Q3/F5 and the
below-threshold unchanged answer card remain open. Do not spend another
DeepSeek call against the failed retrieval preflight. For
historical-card comparison, check the curated dev
SearXNG baseline; if absent, start it with `scripts/run_searxng.sh` (engines
are pinned in `scripts/searxng/settings.yml`). Do not require Docker for a
normal user's Tavily path. Read the [backend decision](evidence/M003/m0039-search-backend-decision.md),
the frozen
[`five-questions.md`](evidence/M003/five-questions.md), the M003.6
[`card rerun`](evidence/M003/m0036-frozen-card-rerun.md) and
[`source-relevance treatment`](evidence/M003/m0036-source-relevance.md), the
[`current-build in-app answer proof`](evidence/M003/m0036-current-app-proof.md),
the M003.7 [`card with source authority`](evidence/M003/m0037-frozen-card-improved.md),
and the M003.8 [`recall diagnostic`](evidence/M003/m0038-recall-diagnostic.md)
and [`fresh searches`](evidence/M003/m0038-fresh-searches.md).
The M003.9 one-call Tavily app smoke is spent and brings the recorded
cumulative provider-attempt minimum to 37; any further paid experiment needs
its own pre-recorded cap. Also read the spent one-call
[`M003.6 provider experiment`](evidence/M003/m0036-provider-experiment.md)
before any provider request. That experiment failed; the later current-build
in-app proof succeeded under its own separate one-call record.
The separate one-call [`post-treatment verification`](evidence/M003/m0036-provider-verification-2.md)
was also spent and stopped at `emptyAnswer`; do not interpret either record as
an allowance for another call. The current-build in-app proof used its own
pre-recorded single call, so a fresh bounded experiment is required before any
further paid card run.
The older [`M003.5 packet`](DEEPSEEK_M0035_WORK_PACKET.md) and
[`continuation`](DEEPSEEK_M0035_CONTINUATION.md) are historical evidence, not
a fresh provider-call allowance.

## Required read order

1. `AGENTS.md`
2. `LOCAL_BROWSER_STATE.md`
3. `project.json`
4. `docs/COMPLETE_PLAN.md`
5. the focused contract relevant to the current task

If those files disagree, stop implementation and reconcile them using the
authority order recorded in `project.json`.

## Safe handoff prompt

```text
Read AGENTS.md, LOCAL_BROWSER_STATE.md, project.json, and
docs/COMPLETE_PLAN.md completely. Inspect the working tree. State the current
proof level, the sole eligible next task, its prerequisites, forbidden scope,
and completion gate before editing. Do not interpret existing files as tested
or accepted unless the canonical evidence log records the command and result.
Update project.json and LOCAL_BROWSER_STATE.md together with any state change.
```

## Update rules

- Keep `schema_version` compatible with the JSON schema.
- Change state only after recording observed evidence.
- Keep exactly one `next_task`.
- Use the proof vocabulary in the manifest.
- Do not copy prose milestones into JSON unnecessarily; link to the detailed
  contract and record only the machine-relevant state and constraints.
- Validate after every change with `make validate-manifest`.

The validator uses only Python's standard library, checks the declared schema,
and enforces cross-field handoff invariants. It does not download packages.

## What the JSON prevents

- a new model restarting the application from scratch;
- accidental work on later modes;
- treating WIP files as verified implementation;
- casually introducing models, rerankers, databases, or agent frameworks;
- losing the sibling reuse and licensing constraint; and
- confusing documentation, local tests, live-provider proof, and packaged-app
  proof.
