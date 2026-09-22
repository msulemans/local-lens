# Repository Working Contract

Read `LOCAL_BROWSER_STATE.md` and `project.json` before changing this
repository. For a fresh handoff, follow `docs/AI_HANDOFF.md`.

## Execution rules

- Work on the sole active milestone only.
- Do not start a later milestone because its implementation looks convenient.
- Do not weaken a gate after observing a failure.
- Preserve failed-run artifacts and diagnose them before proposing another
  treatment.
- Update the canonical state, relevant docs, tests, benchmark evidence, and
  learning material with every milestone.
- Treat search snippets as discovery metadata, never citation evidence.
- Keep local and hosted processing visibly and analytically separate.
- Do not add a dependency, model, reranker, vector database, agent framework,
  or external service without a recorded product need and comparison baseline.
- Never commit secrets, downloaded model weights, private source snapshots, or
  live benchmark bodies whose licences do not permit redistribution.
- Preserve unrelated user changes and do not commit unless explicitly asked.
- Keep `project.json` and `LOCAL_BROWSER_STATE.md` synchronized whenever the
  milestone, proof level, WIP list, blocker, or next task changes.
- Run `make validate-manifest` after changing the machine-readable handoff.

## Model policy

Do not run broad model bake-offs. A candidate is eligible only when
`docs/MODEL_POLICY.md` has a filled experiment record containing:

- the measured failure being treated;
- why the candidate is likely to treat it;
- exact revision and licence;
- frozen tasks and promotion threshold;
- memory, latency, quality, and portability ceilings; and
- a stop condition.

## Proof language

Always distinguish:

- planned;
- implemented;
- deterministically verified;
- locally measured;
- live-provider verified; and
- packaged/reproduced on a second machine.

Documentation checks do not prove runtime behavior. A direct provider test does
not prove the application flow.
