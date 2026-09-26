# M004.1 - Living Research Map and four-mode surface

Date: 2026-09-26 (Australia/Sydney)
Working tree: `main` at `40c7ec3` plus uncommitted M003.5-M003.10 work and this
session's changes. Nothing staged or committed.

## Measured defect

The development app shipped one Quick-only live form. `grep -rin` for
`history`, `launcher`, `onboarding`, `Academic`, `News mode`, `Deep mode`,
`pause`, `cancel`, `Research this gap`, or `Living Research` across
`Sources/LocalLensApp/` returned zero matches, while `docs/PRODUCT.md`
specifies a mode toolbar, a living brief, an evidence map with provenance
ribbons, exact-passage inspection, and a bounded gap action. The owner
observation that the surface was different and missing features is correct.

## What was built

| Boundary | File | Kind |
| --- | --- | --- |
| Frozen mode policies + planner + News independence | `Sources/LocalLensCore/ResearchModePolicy.swift` | new |
| Bounded multi-round runner using the shared citation boundary | `Sources/LocalLensCore/ResearchRunner.swift` | new |
| Keyless scholarly discovery (landing page, then DOI) | `Sources/LocalLensCore/OpenAlexSearchAdapter.swift` | new |
| Artifact-only on-disk history | `Sources/LocalLensCore/ResearchHistory.swift` | new |
| Mode/dimension-aware provider instruction and shared `answerAndCompile` | `Sources/LocalLensCore/LiveQuick.swift` | edited |
| Scholarly composition | `Sources/LocalLensCore/LiveQuickComposition.swift` | edited |
| Living Research Map, history sidebar, inspector, launcher | `Sources/LocalLensApp/LivingResearchMapView.swift` | new |
| Run lifecycle, pause gate, elapsed clock, history | `Sources/LocalLensApp/ResearchWorkspaceModel.swift` | new |
| Map as the presented launch scene | `Sources/LocalLensApp/LocalLensApp.swift` | edited |

## Deterministic verification

```text
$ swift build
Build complete

$ swift test
Executed 262 tests, with 0 failures
  (246 before this session; +16 in Tests/LocalLensCoreTests/ResearchModeTests.swift)
```

`ResearchModeTests` covers the frozen policies and per-mode limit validation,
the four planners (including deterministic News stamping), coverage with
accepted claims, News independence clustering, a full offline Quick runner
completion with exact citations, a Deep run that adds exactly one bounded
follow-up round, a mismatched-plan refusal, the runner's pause checkpoint
(which must block before any search until released), history round-trip with a
corrupt file skipped, and the OpenAlex decoder plus a keyless request
assertion.

The offline guard in `RobotsPolicyTests` still scans `Tests` and
`Sources/LocalLensApp` for `URLSession`, the system resolver, the politeness
clock, `getaddrinfo`, and `Task.sleep`. The app uses a continuation-based pause
gate and a SwiftUI `TimelineView` clock, so no wall-clock sleep exists in the
app target.

## Locally measured UI runs (ad-hoc dev bundle, accessibility outline)

| Run | Mode | Input | Observed |
| --- | --- | --- | --- |
| 1 | Quick | Find evidence, SQLite WAL | 12 matching passages from 5 opened sources; official sqlite.org WAL overview selected; exact passage and snapshot IDs in the inspector |
| 2 | Quick | Ask (hosted DeepSeek) | 5 exact passages, 5 sources, 1 round, 5.8 s; six accepted claims with markers; coverage `Answer · 5`; evidence map `Answer` group with 5 claim rows chipped to sqlite.org and "exact support"; no false gap action |
| 3 | Deep | Find evidence, Swift concurrency vs GCD | 24 stored passages under the 24-passage Deep cap and 16-source budget |
| 4 | News | Find evidence, latest Swift release | 16 stored passages under the 20-passage News cap |
| 5 | Academic | Find evidence, spaced repetition | OpenAlex discovery opened 3 scholarly sources and selected **0** matching passages |
| 6 | History | open a recorded 6-citation run | `SAVED RUN · QUICK`, exact saved passage, quoted span, source link, and "no network call was made" |
| 7 | any | Global launcher button | modal sheet with `GLOBAL LAUNCHER`, question field, mode picker, the mode's boundary chip, a Launch button, and `RECENT` entries from history |
| 8 | News, then Deep | Cancel during a running retrieval | run stops, controls revert to History/Launcher/Find evidence/Ask, and the brief shows the cancelled stop state |

Pause: the control appears during a run, and its checkpoint is deterministically
tested (the runner must reach the pause checkpoint and perform zero searches
until released). The UI engagement itself was not observed because the two
retrieval runs completed faster than the interaction round-trip.

Launch-scene evidence: the window accessibility outline shows
`researchQuestionField`, the `Mode` radio group with Quick/Deep/Academic/News,
the policy chip, `History`, `Global launcher`, `Find evidence`, `Ask`, the
`EVIDENCE` rail, and `Connection`. Before
`restorationBehavior(.disabled)` + `defaultLaunchBehavior`, macOS restored the
old `Live Quick` scene on launch, which is the literal "different UI".

Two view bugs were found by observing the running app and fixed in-session:

- the no-AI path rendered the answered-brief shape instead of the passage
  preview;
- a single-dimension Quick run showed `Answer · 0` and an empty evidence map
  despite six compiled citations. Coverage now counts accepted claims, and the
  map assigns every citation to exactly one group, falling back to
  "Other evidence" rather than hiding a claim.

## Provider accounting

Two hosted DeepSeek answer calls were made in the new app surface. The recorded
cumulative minimum rises from 37 to **39**. Tavily, OpenAlex, and public-page
fetches were live and are not answer-provider calls. No key value was printed,
logged, persisted outside Keychain, or committed.

## Preserved failures and open gates

- Academic selects 0 usable passages from scholarly landing pages; the
  scholarly evidence path is not yet useful.
- News independence is unverified on an answered run; the panel is only
  rendered for a completed answer.
- No local answer provider exists; every answer remains hosted DeepSeek.
- Deep and Academic answer quality have no scored card.
- The bundle is ad-hoc signed; no second Mac has reproduced it.
- The original M004 retrieval-treatment entry check is deferred and unanswered.
- The two pre-fix UI runs recorded 0-citation previews into local history; that
  stale local data was left in place rather than rewritten.

## Proof boundary

Implemented: the surface, mode policies, planner, runner, OpenAlex adapter,
history, launcher, pause/cancel.
Deterministically verified: 262 tests.
Locally measured: the six UI runs above in the ad-hoc development bundle.
Live-provider verified: two hosted Quick answers.
Not packaged or reproduced on a second machine.
