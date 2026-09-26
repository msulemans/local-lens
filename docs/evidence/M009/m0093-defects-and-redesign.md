# M009.3 - Three measured mode defects fixed, and the workspace redesigned

Date: 2026-09-26 (Australia/Sydney)
Working tree: uncommitted. Nothing staged or committed.

Everything here follows from the four-mode hosted run recorded in
`m0092-hosted-four-mode-ui.md`, which measured the defects rather than guessing
at them. Two of those defects were mine, introduced in this session.

## 1. News enforced recency but not topical relevance

The run for "What changed in the EU AI Act enforcement this month?" returned a
stablecoin approval, a biodiversity brief, an anti-deforestation story, and a
commercial-vehicle brief, and some of them reached the timeline and citations.

`NewsRelevance` (new, `Sources/LocalLensCore/NewsRelevance.swift`) filters
discovery results against the question before any fetch is planned:

- a result is kept when it shares an adjacent two-word phrase from the question,
  or two of the question's content terms, or one term that is distinctive
  (five characters or more and not in a fixed list of headline filler);
- matching is whole-word, so `EUDR` is not a match for `EU`;
- the frozen 14-day window runs first, and relevance only refines what it kept;
- if the filter would drop every result it keeps them all and says so, because
  the window already starved one query once (D041).

The first version of the rule kept anything sharing a single term. That version
measured **zero** drops on a live run, because the question contains `month` and
`act`, and "Content of the Month" matched on the first while a piece about "the
AI space" matched on the second. The rule above is the correction; a test states
that measured failure by name.

Measured after the correction, same question and same mode:

| | before the rule | after the correction |
|---|---|---|
| window summary | `29 dated results inside the window, 4 outside it` | `22 dated results inside the window, 7 outside it, 4 off topic for this question` |
| timeline contents | included stablecoin, biodiversity, deforestation, commercial-vehicle stories | EU AI Act stories only |

The counts move between runs because the news index changes; the rule does not.

## 2. A News answer can rest on one voice, and nothing said so

The same run reported `10 independent domains, 10 independent voices` while its
three claims were all single-source. Domain breadth was being reported as if it
were claim depth.

`NewsClaimDepth` counts, per accepted claim, how many independent voices carry
the page it came from, and the surface now leads the News brief with it. A run
that opens ten domains and confirms nothing says exactly that:

> Thin claim set: none of the 7 claims is carried by a second independent voice,
> so the answer is single-source throughout.

with `7 domains · 7 independent voices · 7 claims · 0 confirmed` beside it.

## 3. Coverage counted keyword coincidence as evidence

`Gaps · 2` was reported for a gap nothing had addressed, because a single
`however` matched; `Timeline · 16` counted any passage containing a year,
because `20` was in the term list and matching was by substring.

`DimensionLexicon` now matches whole words only, separates strong terms from
weak ones, and requires one strong term or two distinct weak terms. `20`,
`however`, `remains`, and `may` no longer carry a dimension alone. The same
question that reported `Gaps · 2` now reports `Gaps · 0` unless a passage really
discusses an open question.

## 4. Two fields were computed and then dropped

Found while fixing the above, and both are visible-surface bugs:

- `ResearchRunner` built the contradiction scan and **never passed it to the
  report**, so the contrast panel could not render for any run. The M007.2 note
  that "the panel stays empty" was true for the wrong reason: it was not only
  that no live pair had been found.
- `newsClaimDepth` was computed and likewise not passed, so the panel above
  never appeared. The first live run after the fix showed it immediately.

Both are one-line wiring errors and both are now covered by a test plus a live
run. This is the argument for looking at the running app rather than at
green tests.

## 5. The workspace was redesigned against the product's own mockup

`docs/design/local-lens-living-research-map.png` is the layout PRODUCT.md
selects. The shipped surface had drifted from it into a scaffold: tracked-out
all-caps labels on every section, `·`-joined counters, monospaced micro-text,
and a single-line question field that lost its edges in a crowded row, so a
typed question appeared cut off at both ends with no sign the text was still
there.

Guidance used: the `frontend-design` skill from `anthropics/skills`
(Apache-2.0), installed as a skill for this session, not vendored into this
repository. It named the tells that the previous surface had, which is why the
redesign removes them rather than restyling them.

What changed:

- **A question field that grows**, from one to six lines, with a visible
  boundary, a clear button, and its own placeholder sentence. The mode and
  status controls moved to their own row so neither can squeeze the other.
- **A design system** (`Sources/LocalLensApp/DesignSystem.swift`): semantic
  system surfaces so light and dark appearance both work, one accent for
  evidence, two semantic flags, sentence case everywhere, monospaced digits
  only where numbers align, and one card radius with hairline borders.
- **The mockup's structure**: a summary that is the largest text on the screen,
  a comparison table for Deep, a paper matrix for Academic, a confirmation
  panel and dated timeline for News, an evidence map in the side column, and a
  selected-passage inspector beneath it.
- **Honest verdicts, not invented ones.** The mockup shows `Excellent / Good /
  Fair` per option. This product has no basis for those judgements, so a cell
  reports what was measured: how many stored passages match the criterion on
  that side. The first implementation of that table was wrong - it counted a
  passage whenever it matched the criterion, producing `211 matches` for a side
  it never checked - and the numbers now come from a stated rule:
  passages matching the criterion *and* mentioning the side.
- **Adaptive**: below 1080 points the evidence column becomes a sheet, the
  window opens at a size the layout is designed for, and the two-column layout
  collapses instead of clipping.
- **An inconsistent claim removed**: the idle screen asserted "Add a DeepSeek
  key" although the keychain is only read when a run starts or the panel is
  opened, so the app did not know that. It now states what an answer needs
  rather than what this Mac is believed to have.

Screenshots, before and after, are in this directory.

## 6. Verified in the app, all four modes, hosted DeepSeek, after every change

| Mode | Result in the window |
|---|---|
| Quick | `5 passages · 5 sources · 1 round · 9.0 seconds`; summary with inline citations; coverage `Answer 5 passages`; study card; export; `this run` with its stop reason |
| Deep | `11 passages · 4 sources · 1 round · 6.8 seconds`; comparison table `Tradeoffs 21/13 passages`, `Gaps 1/none`; 11 claim rows grouped under `SQLite WAL mode` |
| Academic | `13 passages · 12 sources · 2 rounds · 20.2 seconds`; paper matrix; map grouped `Method 5`, `Limitations 2` |
| News | `7 passages · 7 sources · 1 round · 9.9 seconds`; `Thin claim set: none of the 7 claims is carried by a second independent voice`; `22 inside the window, 7 outside it, 4 off topic for this question`; dated timeline |

Narrow layout verified separately at 880x700: the evidence column collapses to
a sheet button and the field keeps its width.

## Provider accounting

Eight further hosted DeepSeek answer calls: two from the command line, six in
the app. Cumulative recorded minimum moves from **47 to 55**. Discovery was live
Tavily throughout. No local model was called.

## Proof boundary

- Locally measured: the relevance counts, the coverage change, and every test.
- Live-provider verified: the four modes above, in the app, after the changes.
- Deterministically verified: 36 new tests (15 relevance, 3 precision, 6 claim
  depth and coverage, 6 count as the modified suite). `swift test` reports
  **315 tests, 0 failures**.
- Not proven: that the redesigned surface is better for a person using it. That
  is a human judgement and no measurement here claims it.
- Still open from M009.2, unchanged: the app's own refusal path for an invalid
  plan has not been observed through the accessibility tree; the News copy and
  syndication rule is fixture-verified only; the contrast panel has no live pair
  yet; news headline quality (a newsletter blurb as a headline) remains poor.
