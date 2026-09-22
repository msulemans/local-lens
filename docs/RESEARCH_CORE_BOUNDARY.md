# ResearchCore Extraction Boundary (Frozen for M001)

Last revised: 2026-09-22 (Australia/Sydney)

Status: frozen for M001. Any change to the included modules, exclusions,
protocol version, or wire enums requires a new entry in `docs/DECISIONS.md`,
a protocol version bump, and an update to
`scripts/validate_protocol_schemas.py`.

## What ResearchCore is

The versioned local research engine behind the native shell. It owns research
state and budgets, query planning, search adapters, safe acquisition,
extraction, snapshot and passage identity, retrieval, ranking, deduplication,
the claim/evidence graph, and citation compilation/validation. The Swift app
never imports Python internals; it exchanges versioned JSON over authenticated
local IPC and revalidates schemas, IDs, hashes, and legal state transitions
before rendering.

## Frozen protocol surface v1

| Family | Artifact | Contents |
|---|---|---|
| Entities | `schemas/protocol/v1/entities.json` | `research_run`, `search_hit`, `source`, `snapshot`, `passage`, `claim`, `evidence_link`, `citation`, `comparison_value`, `comparison_row`, `research_result`, `run_event`, `persisted_run` |
| Enums | same file | `run_status` (15 values), `research_mode` (Quick/Deep/Academic/News), `evidence_relation` (supports/partially_supports/conflicts) |
| Commands | `schemas/protocol/v1/commands.json` | `start_run`, `cancel_run` |
| Events | `schemas/protocol/v1/events.json` | `run_event` envelope: `schema_version`, `run_id`, `sequence`, `status`, `message` |
| Errors | `schemas/protocol/v1/errors.json` | `illegal_transition`, `terminal_state`, `unknown_field`, `unsupported_schema_version`, `invalid_reference`, `integrity_failure` |

Determinism rules for v1:

- canonical entities contain no wall-clock timestamps;
- identities are content-derived (`StableIdentity`); message text is not part
  of identity;
- unknown fields are rejected at every boundary;
- illegal state transitions and terminal-state writes fail closed;
- search snippets are discovery hints and never evidence;
- citations resolve to a passage inside an immutable snapshot, and
  `ResearchResult.citationGraphSignature` is the normalized comparison key.

The Python wire enum values must equal the Swift raw values. This parity is
enforced by `scripts/validate_protocol_schemas.py`, wired to
`make validate-schemas`.

## Extraction list (included)

From sibling revision `1b1a698`, after the licence gate in
`docs/REUSE_PROVENANCE.md` is satisfied:

- `domain`, `events`, `state_machine` - typed research state and transitions;
- `adapters.protocols` plus deterministic fakes - replaceable boundaries;
- `discovery.search` (SearXNG boundary), `ranking`, `dedup`, `retrieval`;
- `acquisition.safety`, `robots`, `fetcher`, `extraction`, `rendering`,
  `safe`;
- artifact persistence;
- `pipeline.report` - report and citation compilation/validation;
- `evaluation.integrity`, `evaluation.e2e` (reference shape);
- fixtures and the test subset marked "required" below.

## Exclusions (do not enter this repository)

- the sibling web UI (`web/`);
- the FastAPI transport module and its tests;
- the monolithic `pipeline.controller` shape (its schedule is replaced);
- SearXNG deployment assets (SearXNG stays a replaceable adapter, installable
  outside the app);
- live-network tests and any test requiring third-party APIs;
- model weights, `runs/` artifacts, and private page bodies.

## Replaced sibling behavior (recorded in `docs/PERFORMANCE_PLAN.md`)

- sequential search and acquisition -> bounded parallelism;
- model call per passage -> retrieve, narrow, then batched evidence work;
- unenforced wall clock -> one monotonic phase and run deadline;
- FastAPI request/response -> authenticated local IPC with versioned events.

## Sibling test mapping (184 functions)

| Test file | Tests | Disposition |
|---|---:|---|
| `test_domain.py` | 4 | required - domain entity parity |
| `test_state_machine.py` | 5 | required - legal/illegal transitions, terminal states |
| `test_identifiers.py` | 4 | required - stable identity rules |
| `test_artifacts.py` | 5 | required - artifact persistence and hashing |
| `test_retrieval.py` | 8 | required - FTS5 retrieval, ranking, dedup |
| `test_quoting.py` | 15 | required - citation quoting and validation |
| `test_acquisition.py` | 27 | required - safety, robots, fetch limits |
| `test_dimensions.py` | 8 | required - query planning dimensions |
| `test_integrity_evaluation.py` | 10 | required - deterministic integrity checks |
| `test_vertical_slice.py` | 12 | required - vertical slice contract analogue |
| `test_roles.py` | 31 | reference - pipeline roles; schedule replaced |
| `test_inference.py` | 11 | reference - adapter shape; fake adapter only in M001 |
| `test_config.py` | 4 | reference - budget policy differs in Local Lens |
| `test_e2e_evaluation.py` | 8 | reference - evaluation shape |
| `test_semantic_evaluation.py` | 10 | deferred - requires a model; not in M001 |
| `test_system_comparison.py` | 3 | deferred - needs live baselines |
| `test_api.py` | 15 | excluded - FastAPI is not the boundary |
| `test_live_research.py` | 4 | excluded - live network is not deterministic |

## Swift WIP audit (M001.1)

| Path | Verdict | Reason and follow-up |
|---|---|---|
| `Sources/LocalLensCore/Domain.swift` | keep | entity set matches protocol v1; enums frozen as wire values; add schema-fixture round-trip tests in M001.2 |
| `Sources/LocalLensCore/RunStateMachine.swift` | keep | linear happy path plus cancel; `failed`, `budget_exhausted`, `needs_user_input` are defined but not yet reachable - deliberate; typed stop transitions arrive with their tests |
| `Sources/LocalLensCore/StableIdentity.swift` | keep, amend candidate | SHA-256 truncated to 10 bytes, hex; equality with sibling identifier rules must be re-checked at extraction, not assumed |
| `Sources/LocalLensApp/LocalLensApp.swift` | keep (WIP) | placeholder shell; the Living Research Map screen is still outstanding M001 scope |
| `Tests/LocalLensCoreTests/LocalLensCoreTests.swift` | keep | 4 tests; extend per M001.2 |
| `Package.swift`, `Makefile` | keep | build and verification entry points; new `validate-schemas` target added in M001.1 |

## Change control

1. Propose the boundary change with evidence in `docs/DECISIONS.md`.
2. Bump the protocol version directory (`schemas/protocol/v2/`) or add an
   explicitly compatible field set.
3. Update `scripts/validate_protocol_schemas.py`, the Swift core, and the
   sibling mapping together.
4. Re-run `make validate-schemas`, `make build`, and `make verify` before
   committing.
