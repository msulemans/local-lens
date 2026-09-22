# AI and Contributor Handoff

`project.json` is the compact machine-readable handoff for another model or
contributor. It does not replace the chronological evidence in
`LOCAL_BROWSER_STATE.md` or the rationale in the planning documents.

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
