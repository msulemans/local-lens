# M004.2 - Academic evidence, News independence, and the local answer boundary

Date: 2026-09-26 (Australia/Sydney)
Working tree: uncommitted on top of `5e79633`. Nothing staged or committed.

## 1. Academic evidence (was 0 passages)

Measured defect: M004.1's Academic run opened 3 scholarly sources and selected
0 usable passages, because OpenAlex discovery offered publisher landing pages
and DOI resolvers that a paywall, a bot rule, or a JavaScript renderer refuses.
The general-web fallback only ran when OpenAlex returned no hits at all, so a
scholarly hit list that fetched nothing produced a useless run.

Treatments (deterministic, tested):

- OpenAlex now prefers an open-access HTML landing page (`best_oa_location`)
  before the publisher landing page, and the DOI resolver last. Open-access
  works are stably ordered first within the same relevance order.
- The Academic composition appends general-web hits after the scholarly hits
  instead of replacing them only on an empty result. Primary studies keep the
  first fetch slots inside the same opened-source budget; the fallback is
  discovery only and cannot bypass the citation boundary.

Commands and observed output:

```text
$ TAVILY_API_KEY=... ./.build/debug/LocalLensLive --mode research --plan academic \
    --question "spaced repetition for long-term recall"
mode=research plan=Academic elapsed_s=32.47
dimensions=Findings, Method, Limitations
opened_sources=6 passages=22
fetch stored kind=stored url=https://doi.org/10.32614/r.manuals
fetch stored kind=stored url=https://doi.org/10.1017/s0140525x01003922
fetch stored kind=stored url=https://doi.org/10.18653/v1/p16-1174
fetch refused kind=http_status url=https://doi.org/10.1037/0033-2909.132.3.354
fetch refused kind=no_readable_text url=https://doi.org/10.1016/j.clinph.2019.11.002
fetch refused kind=published_rule url=https://www.sciencedirect.com/science/article/abs/pii/S187712972500231X
fetch refused kind=http_status url=https://www.researchgate.net/...
fetch stored kind=stored url=https://en.wikipedia.org/wiki/Spaced_repetition
coverage=Method: 7, Findings: 3, Limitations: 0
```

Academic now selects 22 passages from 6 opened sources. The refusals stay
typed and preserved; `Limitations` remains uncovered, so the map shows that
dimension as a gap rather than inventing it.

Regression coverage: `testOpenAlexDecodePrefersOpenAccessThenLandingPageThenDOI`
and the existing malformed-payload and keyless-request tests.

Diagnostic note: the CLI's new `--mode research --plan <mode>` path was added
for this diagnosis, and the first run exposed a case-sensitive mode lookup that
silently ran Quick; it is fixed (`--plan academic` now prints `plan=Academic`).

## 2. News independence on an answered run

The M004.1 gap was that the independence panel had never been observed on an
answer. It now has been, using the local model so the run cost US$0.

```text
NEWS BRIEF
1 exact passage · 15 sources · 2 round(s) · 30.3s
answer: "SR2026 CBPR+ payments package has been postponed to SR2027 or later [1]"
"6 independent domains back this evidence."
SOURCES IN ORDER: apple.com (3), clearstream.com (1), co.uk (2),
  projectivegroup.com (3), surecomp.com (2), swift.org (9)
DIMENSION COVERAGE: What happened · 0, Timeline · 2, Independent confirmation · 1
EVIDENCE MAP: "Independent confirmation" -> Claim 1 from clearstream.com
Research this gap: What happened
```

The independence treatment rendered correctly: distinct registrable domains,
passage counts per domain, and an explicit uncovered dimension. One limitation
is visible in the same output: `co.uk` is reported as a domain because
`NewsIndependence` deliberately does not consult a public-suffix list. The view
labels the unit "domain", not "publisher", and this is recorded rather than
hidden.

## 3. The local answer boundary (first live local answer)

Motivation: M004.1 had no local answer path; every answer left the machine.
`LocalAnswerProvider` posts the unchanged untrusted-proposal contract to a
loopback OpenAI-compatible endpoint, carries no credential, and is labelled
`local/<model>` on the artifact. `AnswerPrompt` now owns the provider
instruction so hosted and local cannot drift.

The candidate is recorded in `docs/MODEL_POLICY.md` as
`M004.2-LOCAL-OPENAI-001` before its first live use.

Quick, hosted-free, observed in the app:

```text
boundary: LOCAL · qwen2.5-coder:14b-instruct-q4_K_M
4 exact passages · 5 sources · 1 round(s) · 34.1s
answer: four accepted claims with markers [1]-[4]
DIMENSION COVERAGE: Answer · 4
EVIDENCE MAP: 3 claims chipped to sqlite.org, 1 to forum.xojo.com, "exact support"
```

That meets the experiment's 60 s Quick ceiling and its citation-integrity
expectation with zero hosted calls.

The **same** experiment also produced a real failure, preserved here:

```text
News, local, question "what changed in the latest Swift release"
the model answered about the SWIFT financial-messaging standard
("SR2026 CBPR+ payments package ... postponed to SR2027"), citing
clearstream.com, while the retrieved evidence also held apple.com and
swift.org passages about the Swift programming language.
```

The quote was exact and the citation valid; the answer was irrelevant because
the model chose the wrong sense of "Swift". No deterministic planner change was
made in response, because tuning the query planner against one observed answer
would be fitting to a single case. The failure is recorded as a local-model
quality result, and the local path is **not** promoted to default.

## Verification

```text
$ swift build && swift test
Executed 264 tests, with 0 failures
  (+2 in Tests/LocalLensCoreTests/ResearchModeTests.swift for the local
  provider's keyless request, label, and tolerant JSON extraction)
$ make gate
validators conform; build succeeds; offline guards unchanged
```

App bundle: `make app` rebuilt the ad-hoc development bundle. The accessibility
outline shows the toolbar boundary chip (`HOSTED · DEEPSEEK` / `LOCAL · <model>`),
the Connection local toggle with endpoint and model fields, the local Quick
answer and its evidence map, and the News independence brief.

## Provider and cost accounting

No hosted DeepSeek call was made in this task; the two M004.1 hosted calls keep
the cumulative recorded minimum at **39**. The local runs cost **US$0** and
used no API key. Tavily and OpenAlex discovery were used (Tavily credits only).

## Preserved failures and open gates

- the local model's wrong-sense "Swift" answer, above;
- `co.uk` treated as a domain because no public-suffix list is consulted;
- Academic `Limitations` coverage is 0 on the probe;
- the publisher refusals (`http_status`, `no_readable_text`, `published_rule`)
  are typed but unresolved;
- the local card is not scored, so the local path stays an explicit
  alternative and never a silent fallback;
- notarized packaging and second-Mac reproduction remain unproven.

## Proof boundary

Deterministically verified: 264 tests.
Locally measured: Academic 22 passages at the CLI; local Quick 4 citations;
News independence on an answered local run.
Live-provider verified: OpenAlex and Tavily retrieval; the local endpoint.
Hosted-provider verified: unchanged from M004.1 (two calls, minimum 39).
Not packaged on a second machine.
