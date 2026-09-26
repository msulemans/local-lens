# DeepSeek experiment record (M003.5, exploratory)

Filled 2026-09-23 before the first provider request. This session made no
provider request because `DEEPSEEK_API_KEY` is absent, so the record is frozen
but the candidate is not promoted and no claim of eligibility is made.

```text
Experiment ID: M003.5-deepseek-flash-exploratory
Measured failure: none measured. The deterministic Quick pipeline's prose is
  template based, and real answer quality has not been measured. This session
  is an exploratory measurement run, not a promotion.
Existing baseline and score: M003.3 deterministic Quick output over the frozen
  fixture; no quality score exists, only citation-integrity tests.
Why this candidate could treat that failure: a hosted general model can
  synthesise prose from a bounded evidence set. Whether it improves usefulness
  is unproven until the five frozen questions run.
Exact model/revision/hash: provider model id `deepseek-flash`
  (DeepSeek-V4.1-Flash), base URL https://api.deepseek.com, endpoint
  POST /chat/completions, OpenAI-format JSON output. Measured live 2026-09-23:
  the model also emits `reasoning_content`, so it is a reasoning model and the
  reasoning tokens count against `max_tokens` (first ping: reasoning 642
  characters; a realistic six-passage prompt: reasoning 4,660 characters,
  `finish_reason=length`, completion 1,000/1,000).
  No local weights and no local hash. NOTE: the packet assumed
  `deepseek-v4-flash`; the official changelog and API reference now list
  `deepseek-flash` and `deepseek-v4-pro`, and state the previous-generation
  `deepseek-v4-flash` has been retired. Verified 2026-09-23 from
  https://api-docs.deepseek.com/updates/ and
  https://api-docs.deepseek.com/api/create-chat-completion/.
Licence and redistribution constraints: hosted API under DeepSeek terms. No
  weights redistributed. Passage text leaves the machine, so every run is
  labelled `hosted` and local/hosted results are never merged.
Runtime and integration path: Swift `DeepSeekAnswerProvider` over the existing
  `SearchTransport`; the key is read from `DEEPSEEK_API_KEY` at run time and
  never logged, echoed, committed, or persisted.
Frozen development tasks: the five questions in
  docs/evidence/M003/five-questions.md.
Frozen sealed tasks, if applicable: none for this exploratory run.
Quality promotion threshold: none. No promotion decision is made here.
Latency ceiling: 60 s per question hard deadline for the slice; the product
  target for a fresh-web cited answer is p50 < 20 s, p95 < 40 s.
Peak memory ceiling: <= 2 GB additional RSS for the runner (no local weights).
Disk/download ceiling: none (hosted provider, no local weights).
Maximum runs/calls/tokens/cost: <= 20 provider calls and <= US$1.00 total.
  Per call: <= 4,000 prompt tokens and <= 4,000 completion tokens. The
  completion ceiling was raised from 1,000 to 4,000 on 2026-09-23 after the
  measured truncation above; reasoning tokens count toward it. At
  deepseek-flash peak pricing (input cache miss $0.30 / 1M, output $1.20 / 1M)
  that is <= $0.006 per call and <= $0.12 for 20 calls.
Stop condition: any packet hard stop. As of 2026-09-23 the key is available
  and the fetch transport refuses redirects; the remaining recorded risk is the
  DNS-rebinding TOCTOU window.
Rollback path: remove the DeepSeek wiring; the deterministic pipeline and the
  offline tests remain the default.
```

## Official pricing observed (per 1M tokens, 2026-09-23)

| Model | Input cache hit (off-peak/peak) | Input cache miss (off-peak/peak) | Output (off-peak/peak) |
|---|---|---|---|
| `deepseek-flash` | $0.003 / $0.006 | $0.15 / $0.30 | $0.60 / $1.20 |
| `deepseek-v4-pro` | $0.022 / $0.044 | $0.66 / $1.32 | $1.98 / $3.96 |

Source: <https://api-docs.deepseek.com/quick_start/pricing/>.

## Revision 2026-09-23 (after the first live calls)

The first live calls are recorded in `docs/evidence/M003/live-quick-session.md`.
They changed one operative fact in this record and nothing else:

- `deepseek-flash` is a reasoning model. A local `--mode ping` captured
  `reasoning_content_present=true`; with a realistic six-passage prompt the
  response returned `finish_reason=length`, `completion_tokens=1000` (the old
  cap) and `reasoning_content` of 4,660 characters, and the JSON proposal was
  truncated, which `DeepSeekAnswerProvider.decode` correctly refused as
  `malformedResponse`/`emptyAnswer`.
- The completion ceiling is therefore 4,000, not 1,000. Prompt, latency,
  memory, and cost ceilings are unchanged except for the recomputed per-call
  cost above.

No call budget, token budget, or pricing was otherwise revised downward or
reset. Cumulative provider attempts at this revision: 13 of 20.
