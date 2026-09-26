# Demo

`make demo` runs the parts that need no account and cost nothing.

1. **One mode plan, every fetch outcome.** A Deep retrieval run prints each fetch
   target and its outcome, so a zero-passage result can be attributed to
   discovery, fetch, or selection rather than guessed at.
2. **An edited dimension plan.** The same question with
   `--dimensions "Cost, Concurrency"` prints the dimensions it used and the
   coverage it computed against them.
3. **A typed refusal.** `--plan quick --dimensions "Cost,Risk"` is refused with
   `Quick mode allows at most 1 dimensions; 2 were given.` and exit code 2. The
   plan is never silently trimmed.
4. **The corruption check.** One test mutates a valid citation compilation four
   ways — an altered quote, a missing passage, a mismatched claim, and an unknown
   citation — and requires all four to be refused.

For the guided walkthrough in the app: launch `dist/Local Lens.app`, pick a mode,
press **Find evidence** for source text with no AI at all, then **Ask** for an
answer whose every claim resolves to an exact stored passage. The first-run card
in the window says the same three steps.

Set `TAVILY_API_KEY` to enable the live discovery steps of `make demo`. Nothing
in the demo calls a hosted model.
