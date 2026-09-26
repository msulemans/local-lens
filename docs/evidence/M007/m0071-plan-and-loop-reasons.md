# M007.1 - Editable dimension plan, typed loop termination, resume without duplication

Date: 2026-09-26 (Australia/Sydney)
Working tree: uncommitted. Nothing staged or committed.

## Treatments

1. **Editable dimension plan** (`ResearchPlanner.validatedDimensions`,
   `maximumDimensions(for:)`, `splitDimensions`, and a
   `plan(_:mode:now:dimensions:)` overload). A plan is validated against the
   mode's cap before anything runs: empty, oversized, duplicated
   (case-insensitively), or over-long labels are refused with a typed
   `ResearchPlanError`. Whitespace is collapsed because that does not change
   meaning; nothing is silently dropped, merged, or truncated.
2. **Typed loop termination** (`ResearchLoopReason`, `ResearchRoundRecord`).
   Every round now ends on exactly one recorded reason — `follow_up_scheduled`,
   `evidence_saturated`, `no_new_evidence`, `dimensions_covered`,
   `follow_up_budget_exhausted`, `queries_exhausted`, `deadline_reached`,
   `no_evidence`, `cancelled` — and the report carries the whole round log plus
   the terminal reason. The brief shows
   `STOP · <reason> — <explanation>`.
3. **Resume without duplication.** The failure path was re-checked: a later
   round that stores nothing is `no_new_evidence`, not `no_evidence`; the round
   log and the evidence survive an injected transport failure; and the stored
   page is present once.

## Verified behaviour

Command-line, offline-capable plan validation (exit code 2, typed messages):

- `--plan quick --dimensions "Cost,Risk"` →
  `Quick mode allows at most 1 dimensions; 2 were given.`
- `--plan deep --dimensions "a,b,c,d,e,f,g"` →
  `Deep mode allows at most 6 dimensions; 7 were given.`
- `--plan deep --dimensions "Cost,cost"` →
  `The dimension "cost" appears more than once.`

A valid edited plan drives a real run (live Tavily discovery, no AI):

- `--plan deep --dimensions "Cost, Concurrency"` →
  `dimensions=Cost, Concurrency`, 6 sources, 21 passages, 3.33 s,
  `coverage=["Concurrency": 5, "Cost": 4]`.

Deterministic tests (287 total, 0 failures; 282 before this milestone):

- plan validation: normalisation, case-insensitive duplicate, empty, oversized,
  over-long, and that an edited plan still carries the frozen policy;
- `evidence_saturated` stop with its single round record;
- `no_new_evidence` stop after one bounded follow-up that rediscovers the same
  page, with `rounds <= followUpRounds + 1` and no duplicated passage id;
- injected fetch failure: the run keeps round 0, records
  `follow_up_scheduled` then `no_new_evidence`, stores the page once, and every
  citation still resolves to its exact passage.

## Defects found while observing the running app

- **`DisclosureGroup` content reported an unusable hit target.** The dimension
  editor's toggle sat at an AX rect of 91x9 and a press did not flip it, and the
  identifier intended for the group landed on its first child instead. The strip
  was restructured as plain controls (a chevron button plus a conditional
  editor), after which the effective-plan line renders in the toolbar
  (`Answer` for Quick, `Overview · Evidence · Tradeoffs · Gaps` for Deep) and
  the toggle enables the field.
- **Launch-time keychain reads.** The app read three keychain items at launch,
  so every rebuilt development bundle asked for permission before the user had
  asked for anything. Secrets are now read on demand — when the Connection panel
  opens or a run starts — and an empty field is the only thing filled.
- **Not verified:** the app's *refusal* path for an invalid plan was not
  confirmed through the accessibility tree. The automation raced with the
  re-rendering window (`state is stale`), so the refusal is proven at the core
  and through the CLI, and the app path is wired to the same call
  (`makePlan` → `start` → `.stopped`). This is recorded as an open verification
  gap, not as a demonstrated behaviour.

## M007 status

Met for M007.1: the plan is editable and validated against the frozen caps; every
loop terminates with a typed reason; repeated work cannot duplicate evidence.

Still open in M007: coverage and contradiction matrices (the measured
`coverage` term-matching weakness — Deep reports `Evidence · 0` and
`Tradeoffs · 0` for passages that plainly discuss both, because coverage looks
for the dimension label rather than its content terms), a diminishing-evidence
stop rule, and full provenance ribbons. These become M007.2.

## Proof boundary

Deterministically verified: 287 tests.
Locally measured: three refused plans, one valid edited plan end to end, and the
app plan strip rendering.
Live-provider verified: Tavily discovery on the edited-plan run.
No hosted answer call was made in this milestone; the cumulative hosted minimum
stays **39**. Two app runs were the no-AI `Find evidence` path, which is
labelled `SAVED PASSAGES · NO AI USED`.
