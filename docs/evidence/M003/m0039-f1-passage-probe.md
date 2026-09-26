# M003.9 F1 official-page passage diagnosis

Recorded before the targeted provider-free probe, 2026-09-26 AEST. The Tavily
F1 preflight opened Python's official `asyncio-task.html` but selected a
`Task groups` heading and generic cancellation passages, not the child-failure
rule. The [official Python documentation](https://docs.python.org/3/library/asyncio-task.html)
does contain the rule: when a task in the group fails with a non-cancellation
exception, remaining tasks are cancelled and failures are grouped. Thus the
immediate measured failure is local query-to-passage selection, not absence of
the rule from the fetched source.

One diagnostic only: supply that same public page directly and ask the
unchanged F1 question, but use the side-specific lexical query
`task fails exception remaining tasks cancelled`. Keep fetch, extraction,
index, and caps unchanged. If it selects the official passage, consider a
deterministic planner treatment with regression coverage; otherwise preserve
the extraction/chunking gap. No provider call or benchmark score.

## Result

The one direct-page retrieval completed in **1.04 s**, opened one official
Python page, and selected 12 passages. Its first passage was the exact
child-failure rule from `docs.python.org`: a non-`CancelledError` failure
cancels remaining tasks. Another selected passage covered exceptions raised
by the task-group body. This supports a narrow lexical-query treatment; it
does not yet show that the default multi-source Tavily path selects the rule.

The narrow planner treatment was then added for Python asyncio TaskGroup
exception questions, leaving web discovery unchanged. A deterministic
regression pins the lexical expression and unrelated-question fallback. One
default Tavily provider-free recheck completed in **2.95 s**, opened five
sources, and selected eight passages. Its first passage was the official
Python child-failure/cancellation rule; another official Python passage
covered special base-exception cases. F1's specified **retrieval** check is
now met on this run. No DeepSeek answer/citation quality has been measured
for F1.
