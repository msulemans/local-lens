# M003 gate close-out — resources, app path, and clean-checkout repro

Recorded 2026-09-26 AEST. This closes the remaining "First useful Quick
release" gate bullets after the frozen card reached 7/10
(`m003-frozen-card-treated.md`).

## The fix that unblocked the card

`SafeAcquisition.canonicalKey` built its loop key from `URL.path`, which drops
a trailing slash, so a server's ordinary redirect from `/page` to `/page/` was
refused as `redirect_loop`. Measured live: `developer.apple.com/videos/.../10134`
→ `/10134/` → 200, `swift.org/blog` → `www.swift.org/blog/` → 200, and a
personal blog `/post` → `/post/` → 200 were all refused. The key now uses
`URLComponents.percentEncodedPath`, which keeps the slash, so only a genuinely
repeated URL is a loop and `maxRedirects` still bounds a ping-pong. Regression:
`SafeAcquisitionTests.testTrailingSlashRedirectIsFollowedRatherThanTreatedAsALoop`.

This one deterministic change is why Q1 now cites Apple WWDC21 10134 (40 → 5
opened sources on rerate), Q2 gains the two-sided Apple/Swift-Forums
comparison, and Q4 reaches the dated `swift.org/blog` release note.

## Peak resource use (recorded)

| Path | Measurement | Observed | Ceiling |
|---|---|---|---|
| CLI retrieval (`--mode retrieve`, Q1) | `/usr/bin/time -l` maximum RSS | **30.8 MB** | — |
| Mac app live run (`Live Quick`, Q1 no-AI) | sampled `ps -o rss` at 5 Hz, 73 samples | **140 MB peak**, 128 MB steady | 2 GB |
| App idle baseline | `ps -o rss` after launch | **83 MB** | — |

Latency recorded per question in the treated card: 6.01, 9.63, 5.10, 4.69 s
plus Q5's abstention. The app's no-AI Q1 run completed in ~7 s and the answer
card's answer-mode runs were each under the 60 s Quick deadline.

## No Docker, no terminal, app path

The current ad-hoc development bundle `dist/Local Lens.app` was rebuilt
(`make app`), relaunched, and driven through its own controls. With only a
user-owned Tavily key in macOS Keychain, a question typed into the field and
**Find evidence without AI** opened five public sources, stored twelve
passages, and displayed **Passage 1 "Explore structured concurrency in Swift"**
(Apple WWDC21 10134) plus the exact WWDC21 cancellation rule. No Docker
container, SearXNG endpoint, or terminal command was involved in that app run.

## Clean-checkout reproduction

```text
$ git clone -q . /tmp/locallens-clean && cd /tmp/locallens-clean
HEAD: 5e79633 Freeze infrastructure and open M003.5 (live Quick vertical slice)
dirty files: 0
$ swift build   -> Build complete!
$ swift test    -> Executed 192 tests, with 0 failures (0 unexpected)
```

The committed deterministic path reproduces from a clean checkout. The working
tree's 246 tests include the uncommitted M003.6–M003.10 work and are green.

## Gate checklist

- five frozen searches complete: **yes** — treated card, 7/10, 13/13 exact;
- five fresh representative searches: **yes** — recorded in
  `m0038-fresh-searches.md`;
- citation integrity 100%: **yes** — 13/13 exact on the card, 4/4 on the app
  integration smoke, and abstentions rather than uncited claims;
- every failure has a typed reason: **yes** — Q5 `no verifiable claim`;
- latency and peak resource use recorded: **yes** — table above;
- no Docker or terminal for the app path: **yes** — verified above;
- clean checkout reproduces the deterministic path: **yes** — 192 tests green.

Remaining honest limits: Q5 abstains rather than correcting its false premise;
Q3 cites a SQLite forum and gives the check step, not the build-it-yourself
step; Apple WWDC citations are primary transcripts, not API reference; the
bundle is ad-hoc signed and has not run on a second Mac.
