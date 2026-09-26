# M009.2 - All four modes verified in the app with hosted DeepSeek

Date: 2026-09-26 (Australia/Sydney)
Working tree: uncommitted. Nothing staged or committed.

## Why this run exists

Every mode after M004.1 had been answered only by the local model or not at all
through the app: the records showed **two hosted Quick answers**, no hosted Deep,
Academic, or News answer, and no mode had been driven through the interface with
the hosted provider since the Living Research Map was built. This closes that gap
in both the command line and the app.

## Command line, hosted DeepSeek (`--mode research-answer --tavily`)

| Mode | Question | Citations | Accepted | Answer path | Elapsed |
|---|---|---|---|---|---|
| Quick | SQLite WAL readers and writers | 7 | 7 | saturated | 13.55 s |
| Deep | WAL vs the rollback journal | 11 | 11 | dimensions covered | 9.36 s |
| Academic | retrieval practice and retention | 6 | 6 | saturated | 33.13 s |
| News | EU AI Act enforcement | 3 | 3 | dimensions covered | 21.59 s |

## The app, hosted DeepSeek, observed through the accessibility tree

| Mode | Brief | Result in the window |
|---|---|---|
| **Quick** | `QUICK BRIEF`, `6 exact passages · 5 sources · 1 round(s) · 6.3s` | `STOP · evidence saturated`; coverage `Answer · 6`; 6 claim rows chipped to their domains; `LEARN · 1`; EXPORT with Learning card |
| **Deep** | `DEEP BRIEF`, `12 exact passages · 4 sources · 1 round(s) · 8.0s` | PLAN strip showed the comparison plan (`SQLite WAL mode · the default rollback journal for a small app · Tradeoffs · Gaps`); `DECISION CRITERIA` with both sides (21 and 17 passages matched); coverage `21 / 17 / Tradeoffs 1 / Gaps 2`; `STOP · dimensions covered`; `LEARN · 2` |
| **Academic** | `ACADEMIC BRIEF`, `13 exact passages · 11 sources · 1 round(s) · 25.2s` | `PAPER MATRIX` with 13 claim-to-passage rows including PDF headings (`Page 6`); coverage `Findings 25 · Method 8 · Limitations 7`; `STOP · evidence saturated`; `LEARN · 1` |
| **News** | `NEWS BRIEF`, `3 exact passages · 15 sources · 2 round(s) · 15.9s` | `WINDOW · 29 dated results inside the window, 4 outside it`; `10 independent domains, 10 independent voices`; `TIMELINE · NEWEST FIRST` with dates from Sep 26 down to Sep 13 and two undated rows shown as `—`; coverage `What happened 5 · Timeline 16 · Independent confirmation 1`; `LEARN · 1` |

## Why the saved keys were not prefilled

Three faults, all found here:

1. **The provider check ran before the keychain read.** `start(useProvider:)`
   asked "is a provider configured?" and returned early, and only then did the
   lazy keychain load run. On a fresh launch the first **Ask** therefore always
   failed with `No answer provider is configured.` even with the key saved.
   The read now happens first.
2. **A refused read was reported as an empty slot.** `SecretKeyStore.load`
   collapsed every non-success status into `nil`, so `errSecAuthFailed` — the
   keychain refusing this binary permission to read an item that exists — was
   displayed as "no key configured", which is false and sends a user to re-enter
   a key they already saved. The read now returns `.found`, `.absent`, or
   `.denied`, and the Connection panel says which, with a **Grant access**
   button that triggers the prompt deliberately instead of mid-run.
3. **Inherent, and now explained in the app:** macOS ties that grant to the
   code signature, and every `make app` rebuilds and re-signs the development
   bundle ad hoc, so the grant is lost on each rebuild. The panel says so.

After the fix the first **Ask** on a fresh launch used the keychain item
directly: all four runs above were started with one press.

## Defects this run measured (not fixed here)

- **News relevance.** The news index returns loosely related recent articles:
  the timeline and citations included `fintechfutures.com` (stablecoin approval),
  `osborneclarke.com` (biodiversity net gain), `foodnavigator.com` (deforestation
  rules), `automotiveworld.com` (commercial vehicle brief). The window is
  enforced, but topical relevance is not.
- **`Independent confirmation · 1`.** Only one of the three News claims landed on
  the independence dimension, so the answer rests on a thin claim set even though
  10 domains were opened.
- **Deep stopped at `dimensions covered` with `Gaps · 2`** because two coverage
  keywords matched, not because the gap was genuinely addressed.
- **Academic cited one blog** (`educationalneuroscience.org.uk`) and one
  education site (`teachertoolkit.co.uk`) inside the `Other evidence` group.
- The app opens with the Connection panel expanded after a refusal, which is
  helpful once and noisy afterwards.

## Provider accounting

Eight hosted DeepSeek answer calls: four from the command line and four from the
app. The cumulative recorded minimum moves from **39 to 47**. Discovery for all
eight was live Tavily; no local model was called in this verification.

## Proof boundary

Live-provider verified: hosted DeepSeek answers in all four modes, both through
the command-line tool and through the app, with the accessibility tree as the
observation method for the interface.
Locally measured: the four command-line runs above.
Not proven: answer quality. These runs establish that the four modes route
through the hosted provider and the citation boundary, not that the answers are
good; usefulness remains unscored except where a review packet was applied.
