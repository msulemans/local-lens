# DeepSeek work packet: M003.5 live Quick slice

Prepared 2026-09-23. This packet is for one unattended coding session of up to
two hours. The operator can paste the prompt below into DeepSeek from the
repository root. The packet gives defaults and stop rules so routine choices do
not require another conversation.

## Paste this into the coding agent

```text
You are implementing only M003.5 in this repository. Work autonomously for up
to 120 minutes, with a checkpoint every 15-20 minutes. Do not end your turn
after merely reading the plan, reporting an obstacle, or writing another plan.
Keep making the smallest safe in-scope change until the gate is met or a hard
stop below applies.

First read completely: AGENTS.md, LOCAL_BROWSER_STATE.md, project.json,
docs/COMPLETE_PLAN.md, docs/MODEL_POLICY.md, docs/PERFORMANCE_PLAN.md,
docs/REUSE_PROVENANCE.md, and this packet. Inspect git status and the existing
Swift boundaries before editing. Existing user changes are yours to preserve.
The source of truth is LOCAL_BROWSER_STATE.md, then project.json. If the active
task is no longer M003.5, stop and report the changed state.

Deliver one live Quick product slice: real question -> no more than two search
queries -> no more than six safe fetches -> no more than twelve stored and
retrieved passages -> one explicitly labelled answer provider -> concise answer
-> exact passage citations -> native Quick view. Run five representative
questions and record honest latency, quality, citation, memory, cost, and
failure results. Keep default tests offline.

Default choices for this run:
- Search: local SearXNG in Docker, development only, bound to 127.0.0.1. Reuse
  the existing SearXNGSearchAdapter. First check whether an instance already
  exists. Create only a project-scoped setup if one is needed; do not alter
  unrelated containers. Enable SearXNG's JSON output explicitly.
- Answer provider: DeepSeek hosted API, using the existing DEEPSEEK_API_KEY
  environment variable if it is available to your process. Use the currently
  documented DeepSeek Flash API model after verifying the official model ID.
  Never print, log, commit, or echo the key. Never silently use another
  provider. Label all resulting runs as hosted.
- Model admission: fill the complete experiment record in
  docs/evidence/M003/deepseek-experiment.md before the first provider request.
  Use the deterministic Quick output as the baseline; state that its prose is
  template based and that real answer quality has not yet been measured.
- Cost guard: at most 20 answer-provider calls and US$1.00 total estimated or
  observed API spend for this session, whichever limit is reached first. If
  current pricing cannot be verified, use a conservative token ceiling and
  stop before the first charge rather than guessing a cost. One smoke call,
  then at most five evaluation questions and bounded fixes.
- Time guard: stop after 120 minutes. A partially working, clearly documented
  slice is preferable to an unbounded debug loop.

Execution loop:
1. Inspect and name the next smallest missing connection in the live path.
2. Implement it using the existing types and boundaries.
3. Run its focused deterministic check, then make gate at a checkpoint.
4. Record observed output and any failure in docs/evidence/M003/.
5. If the same approach fails twice, diagnose the cause and choose one
   different in-scope treatment. Never weaken a gate or repeat the same call
   indefinitely.
6. Continue to the next missing connection while time and budgets remain.

Keep a short checkpoint log in docs/evidence/M003/live-quick-session.md. Include
elapsed time, changed files, tests, live calls and estimated cost, result, and
next action. Update LOCAL_BROWSER_STATE.md and project.json together when
their current task, proof level, blocker, or next task changes. Run
make validate-manifest after changing project.json.

Do not commit unless the user separately asks for a commit. Do not publish or
deploy. At the end, report what a user can actually do in the Mac app, exact
commands and test results, five-question results, live/provider proof, blockers,
cost, changed files, and the single next eligible task. Do not claim M003.5
complete unless every done_when item in project.json has observed evidence.
```

## What exists already

The latest recorded state is M003.5 active, M003.4 complete, and a clean work
tree at commit `5e79633`. The existing package has a native deterministic
Quick view, SearXNG JSON adapter, bounded safe fetch scheduler, HTML extraction,
content addressed snapshot store, FTS5 index, Quick pipeline, citation compiler,
and exact passage inspector. At preparation time `make gate` last passed with
192 tests. These are starting facts to verify, not proof of a live flow.

Relevant entry points:

| Job | Existing file |
|---|---|
| Native view | `Sources/LocalLensApp/LocalLensApp.swift` |
| Search | `Sources/LocalLensCore/SearchAdapter.swift` |
| Safe parallel fetch | `Sources/LocalLensCore/BoundedFetch.swift` |
| URL/redirect safety | `Sources/LocalLensCore/SafeAcquisition.swift` |
| Extraction | `Sources/LocalLensCore/HTMLExtraction.swift` |
| Stored evidence | `Sources/LocalLensCore/SnapshotStore.swift` |
| Retrieval | `Sources/LocalLensCore/LexicalIndex.swift` |
| Citation checks | `Sources/LocalLensCore/CitationCompiler.swift` |
| Offline composition | `Sources/LocalLensCore/QuickPipeline.swift` |
| Current task contract | `project.json` |

`QuickPipeline` currently consumes a frozen plan with proposed claims and
quotes. For live work, provider output must be treated as untrusted proposals.
The exact quote must occur in a selected stored passage, and a user visible
factual span needs a citation that resolves through the existing compiler and
inspector. If the provider cannot supply a verifiable claim, omit it or show
uncertainty. Do not let the provider fabricate URL, snapshot, passage, claim,
evidence, or citation IDs.

## Work order

### Phase 0: preflight and frozen record, 10-15 minutes

1. Read the required files and inspect `git status --short`, recent commits,
   the package targets, and relevant source entry points.
2. Verify Docker daemon access, whether SearXNG is already running, and whether
   `DEEPSEEK_API_KEY` is set. Check only presence of the variable; do not print
   its value or include it in diagnostic output.
3. Verify the current DeepSeek API model ID, endpoint, response format, and
   pricing from official documentation. The current official changelog names
   `deepseek-v4-flash` and `deepseek-v4-pro`; use Flash for this bounded slice
   only if still current. Record the exact provider identity and docs link.
4. Freeze the five questions and evaluation rubric before the first live call.
   Fill every field in the experiment template in `docs/MODEL_POLICY.md`,
   including the baseline, quality threshold, latency, memory, disk, call,
   token, cost, stop, and rollback rules.
5. Decide a session start time and end time, no more than two hours apart.

If the provider key is absent, Docker is unavailable, an API charge cannot be
bounded, or licensing/terms block the intended use, do all offline integration
and tests that remain in scope, then stop with the exact unresolved dependency.
Do not substitute a random public SearXNG instance or an unapproved provider.

### Phase 1: search endpoint, 10-20 minutes

Use the existing adapter. Keep the development SearXNG container bound to
loopback and isolated from unrelated Docker projects. Configure JSON output;
the [SearXNG API](https://docs.searxng.org/dev/search_api) returns 403 if JSON
is not enabled. Verify one query produces JSON with at least one usable hit.
Record image tag/digest, local endpoint, command, response status, result count,
and any engine errors. Do not store response bodies containing private content
in Git.

Docker is permitted for the development search service. The final Mac user
must not need Docker; this slice does not claim that packaging goal.

### Phase 2: live runner, 25-40 minutes

Add the smallest separate live executable or explicitly opted in app path that
composes the existing search, safe fetch, extraction, snapshot, retrieval, and
citation components. An executable is required because the default app and
`make gate` must stay offline. Keep the implementation close to existing code;
do not create a generic orchestration framework.

Enforce in code, then test with fakes:

- at most 2 search queries per question;
- at most 6 opened sources, with existing per-host politeness and redirect
  safety retained;
- at most 12 passages supplied to the provider;
- one end to end deadline and terminal reason;
- zero provider calls when no safe, extracted evidence is available;
- explicit cancellation and typed failure paths;
- no snippet promoted to passage evidence;
- no secret in requests logged or persisted; and
- local or hosted label on the result.

The existing `URLSessionSearchTransport` sends search requests, but inspect the
safe fetch path carefully before using it on the open web. Tests with an
injected resolver do not prove a production resolver is safe. If the production
fetch transport cannot enforce the existing DNS and redirect policy, stop live
page fetching and record that exact blocker. Do not bypass it with raw
`URLSession` calls.

### Phase 3: provider and citation path, 20-30 minutes

Send only the selected, bounded, attributed passages to DeepSeek. Request a
concise structured answer with atomic claims and supporting passage IDs/quotes.
Validate structure and exact quotes in trusted code. Feed accepted proposals
through the current citation compiler and integrity validator, then render the
answer and citations through the existing Quick view/inspector. A model answer
that is pleasant but ungrounded is a failed run, not a successful demo.

Count every attempt, retry, token, elapsed duration, and estimated cost. If the
provider supports usage fields, prefer observed usage; otherwise mark the cost
as an estimate. No silent retry storms.

### Phase 4: five-question product check, 20-30 minutes

Freeze five questions before execution, covering:

1. a concise factual question with an authoritative primary source;
2. a comparison that needs at least two independent sources;
3. a practical Mac or developer task with actionable steps;
4. a recent fact where freshness must be visible; and
5. an unsupported or misleading premise that should abstain or correct it.

Do not tune on the fifth question and then report the same five as held out.
If any question cannot be run within cost/time, report `not run`, not a score.

For each question record: exact question, date/time, provider/model, search
queries, opened URLs and outcome counts, selected passage IDs, first evidence
time, final answer time, maximum observed memory, tokens, estimated/observed
cost, answer usefulness (0-2 with a one sentence rationale), citation validity
(valid/total), citation completeness (supported factual spans/total factual
spans), abstention/failure behavior, and snapshot hashes. Keep private page
bodies out of Git. Report medians only when at least three comparable runs
complete; keep failed runs in the denominator for completion rate.

### Phase 5: closeout, 10 minutes

1. Run `make gate` in an environment where SwiftPM can access its module cache.
2. Verify the default app and all gated tests remain offline.
3. Inspect `git diff --check`, `git status --short`, and the changed file list.
4. Update the canonical state and manifest together. Record observed evidence,
   not anticipated results.
5. Record the architecture decision required by M003.5: either resolve the
   sibling licence and extract remaining useful parts, or formally choose the
   native Swift core. A recommendation can be recorded now; a claim that the
   architecture is proven needs the live slice evidence.
6. Leave one next eligible task. If M003.5 is incomplete, keep it active with
   the smallest concrete blocker and the successful partial proof.

## Loop discipline and hard stops

At each 15-20 minute checkpoint, write a short evidence entry and choose the
next action. If a command fails because of sandbox permissions, retry once
with the normal approval mechanism. If the same technical approach fails twice,
diagnose before changing code. If three consecutive checkpoints make no
meaningful progress, stop and report the blocking dependency.

Stop immediately for any of these:

- 120 minutes elapsed;
- estimated or observed hosted spend reaches US$1.00;
- 20 provider calls attempted;
- a secret appears in output or a tracked file;
- DNS/redirect safety cannot be enforced by the production fetch path;
- the only path forward requires changing frozen entities/protocols or copying
  sibling code without licence clearance;
- search or provider access is unavailable after one bounded setup attempt;
- user input overrides this task.

Do not delete user data, rewrite unrelated files, publish, deploy, or commit.
Do not mark a gate passed when only a fixture or direct provider call worked.

## Minimal final report format

```text
M003.5 outcome: complete / partial / blocked
Elapsed time:
What runs in the Mac app:
Live question and exact citation proof:
Five-question card: completed/5, failures, answer usefulness,
  citation validity, citation completeness, p50/p95 latency if eligible,
  peak memory, total provider cost
Offline gate: command, test count, result
Changed files:
Architecture decision or pending reason:
Exact remaining blocker and sole next task:
Commit: none (unless the owner separately requested one)
```

Official references: [DeepSeek API updates](https://api-docs.deepseek.com/updates/),
[DeepSeek Chat Completions API](https://api-docs.deepseek.com/api/create-chat-completion/),
[SearXNG container installation](https://docs.searxng.org/admin/installation-docker),
[SearXNG Search API](https://docs.searxng.org/dev/search_api).
