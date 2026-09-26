# M006 - News mode: time window, syndication voices, timeline, claim support

Date: 2026-09-26 (Australia/Sydney)
Working tree: uncommitted. Nothing staged or committed.

## What the mode promised before this change

News declared "last 14 days, independent confirmation" in its frozen policy and
put a month stamp in the query text, but nothing filtered by date and nothing
detected syndicated copies. A stale page could be cited inside a News answer and
the independence count was a raw domain count.

## Treatments

1. **Discovery-time window** (`NewsRecency`, `WindowedSearchAdapter`). The
   provider's news index is asked for the mode's own window
   (`ModePolicy.policy(for: .news).timeWindowDays`, never a per-run choice) and
   the window is then enforced locally before any fetch is planned. A result
   outside it is dropped and counted; a result whose publication time the
   provider does not report is also dropped and counted, because an undated page
   cannot be shown to honour a bounded window. The ledger records what was left
   out, the observed span, and the dates keyed by URL.
2. **Syndication voices** (`NewsIndependence.voices`). Two domains whose stored
   headings reduce to the same four-or-more-word signature count as one
   independent voice. A heading that is missing or too short is never merged, so
   page furniture cannot silently collapse two unrelated reports.
3. **Timeline** (`NewsIndependence.timeline`). Voices ordered newest first,
   undated last, each carrying the provider-reported date of its page. No date
   is invented: an undated report is shown without a timestamp.
4. **Claim-level support** (`NewsIndependence.snapshotSupportMap`). Each cited
   passage carries how many independent voices back the page it came from, and
   the inspector says "Single source: no other independent voice carries this
   report." when the answer is one outlet's word.

## Live measurement (Tavily news window, EU AI Act question)

- 30 discovery results across the plan's five queries: **23 inside the 14-day
  window, 7 outside it**; the window ledger reports exactly that.
- 9-10 sources opened, 20-24 passages selected, 4.5-6.4 s per retrieval run.
- Timeline rendered newest first (`Sep 25, Sep 25, Sep 24, Sep 24, Sep 13`),
  with five undated reports shown as `—` / `no date` rather than given a date.
- 9 domains and 9 voices on the observed run: no syndicated copy was present, so
  the copy test did not merge anything. That is a null result, not a
  demonstration that copies are common.
- App run (local model, US$0): 3 exact passages, 1 round, 21.3 s,
  "9 independent domains, 9 independent voices", the `WINDOW ·` line, the
  timeline, the coverage strip, the evidence map, and the export row.

## Defects found by looking at the running app

- **RFC 1123 dates were unparsed.** The live news index reports
  `Mon, 21 Sep 2026 08:34:00 GMT`, not ISO-8601, so the first implementation
  dropped every dated result and the run abstained with
  `no openable search hits`. Fixed by accepting RFC 1123 alongside ISO-8601 and
  `yyyy-MM-dd`, with the observed real string kept as a fixture.
- **The date map was captured before the run.** `ResearchRunner.run` received a
  dictionary snapshot from the ledger that was still empty, so the app timeline
  showed "no date" for everything while the CLI (which read the ledger after the
  run) showed real dates. The runner no longer takes a date map; the
  presentation layer reads the ledger once discovery has finished.
- **Undated entries rendered as "Jan 1".** A `?? .distantPast` fallback printed
  a real-looking date. They now render `—`.
- **Headings are often page furniture.** The longest-heading heuristic improved
  the copy proxy ("GPAI Enforcement Is Also Live — But Do Not Panic") but still
  picked "My best business intelligence, in one easy email…" and a webinar
  banner as headlines. The extractor's heading quality on news pages is an open
  defect and the voice count is only as good as the heading it judges.

## Gate result: met, with one part recorded as not demonstrated

- stale pages do not masquerade as current reporting — **met**, 7 excluded live
  and covered by `testNewsWindowKeepsRecentHitsAndExcludesStaleAndUndated`;
- syndicated copies do not count as independent confirmation — **met** by
  `testSyndicatedHeadlineCountsAsOneVoice`, but **not demonstrated live**: the
  observed run contained no copy;
- material claims have independent evidence or visible uncertainty — **met**,
  the app shows "Single source: no other independent voice carries this report."
  for the observed answer, whose three claims all came from one outlet;
- a frozen snapshot set makes regression comparisons reproducible —
  **partially met**: the window, copy, timeline, and support logic are
  deterministically tested with fixtures, but no frozen live News snapshot set
  exists, so cross-run comparison still depends on the provider.

`swift test`: **282 tests, 0 failures** (280 before this milestone).

## Proof boundary

Deterministically verified: 282 tests, including the window, starvation,
copy-merge, short-heading, timeline-order, and claim-support cases.
Locally measured: six live News retrieval runs and two app runs at US$0.
Live-provider verified: Tavily news discovery including reported dates.
No hosted answer call was made; the cumulative hosted minimum stays **39**.
