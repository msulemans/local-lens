# M003.9 F1 provider-free check in the current Mac app

Recorded 2026-09-26 AEST on the running development bundle, after the narrow
Python asyncio planner treatment. This verifies the app path only; it calls no
answer provider and scores no card.

Setup: `dist/Local Lens.app` process started 2026-09-26 11:23:20 AEST
(binary mtime 11:23:00), the current ad-hoc build. The window was driven through
the app's own accessibility tree; no Docker endpoint, terminal command, or
supplied page URL was used.

Action: with the unchanged F1 question in the field —

> What happens when a Python asyncio TaskGroup child raises an exception?

— the **Find evidence without AI** control was pressed once. The pressed control
is the app's no-AI path: Tavily search, safe parallel fetch, snapshot store, and
local lexical selection. No DeepSeek call was made; the run is labelled
`WEB SOURCES · NO AI`.

Observed result (fresh run, reproduced once):

```text
8 matching passages from 5 opened sources
Passage 1 · Task groups¶ — "The first time any of the tasks belonging to the
  group fails with an exception other than asyncio.CancelledError, the
  remaining tasks in the group are cancelled. No further tasks can then be
  added to the group. ... The resulting asyncio.CancelledError will interrupt
  an await, but it will not bubble out of the containing async with statement."
```

The first selected passage is the official Python child-failure/cancellation
rule from the `Task groups` section (the `¶` marker is the Python
documentation anchor). This is exactly the rule that the earlier default
Tavily preflight failed to select, so the retrieval gap recorded in
`m0039-f1-passage-probe.md` is reproduced as fixed in the app, not only in the
CLI. Runs 2-8 included further official `Task groups` text plus third-party
pages; the app does not hide them, and they were not needed for the check.

Layout check: the previously cramped behavior was the `Connection` disclosure
staying expanded after a run. In the current build `Connection` is collapsed
when the no-AI inspection starts and remains collapsed once the evidence pane
renders, so the passage list and right-rail preview are not pushed off screen.
This is the view-only adjustment recorded in `LOCAL_BROWSER_STATE.md`.

Limits kept explicit:

- The evidence rail shows the selected passage text and an **Open fetched
  page** link, not the URL as text. The source is identified here by the
  official heading and rule text, matching the CLI probe that fetched
  `docs.python.org/3/library/asyncio-task.html` directly; the URL was not
  re-opened in a browser for this check.
- Tavily basic-search credits were spent (the free user-owned tier); no
  DeepSeek attempt was made, so the recorded cumulative provider-attempt
  minimum remains **37**.
- This proves F1 evidence selection and the pane layout. It does not score
  F1's answer/citation quality, does not re-run the unchanged card, and does
  not promote Quick. Q3 and F5 remain preserved retrieval gaps.

## Owner-run hosted F1 answer observed in the same app session

The owner then ran one **HOSTED · DEEPSEEK** Ask on the same F1 question in the
same current-app session (not part of this provider-free check and not the
M003.9 pre-recorded call, which was the SQLite WAL question). Verified by
driving the app's citation rail:

```text
ANSWER · 5 exact passages · 3.9s
[1] remaining tasks cancelled            -> passage b7cd29e0b4ea2a…
[2] no further tasks added to the group  -> passage b7cd29e0b4ea2a…
[3] async-with body task also cancelled  -> passage b7cd29e0b4ea2a…
[4] CancelledError does not bubble out   -> passage b7cd29e0b4ea2a…
[5] KeyboardInterrupt/SystemExit re-raised -> passage ed8cf81af8e156…
all five -> snapshot 11fd90e0ec3795… (Python docs, Task groups)
```

Each claim's cited quote is an exact substring of its saved passage, and the
quoted text entails the displayed sentence. Every citation resolves to one
primary source (the Python `asyncio-task` task-groups section), which is
appropriate for an API-behaviour question. This is the first observed F1
answer/citation quality sample and it is strong; it is a single owner-
initiated run, not a pre-recorded experiment, so it is recorded as an
observation and not as a scored card result.

Provider accounting: this was one additional hosted DeepSeek attempt, so the
recorded cumulative provider-attempt minimum becomes **38**. No retry was
made.
