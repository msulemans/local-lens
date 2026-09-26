# Release gates: one closed, three open

Four M009 release items were tracked. The owner selected MIT on 2026-09-26, so
the licence gate is closed by the root `LICENSE` file. The other three still
need external evidence. None may be marked met without its closing artifact.

## 1. Independent citation review

**Needs:** a person to judge the answers, not a model.

**Ready for them:**

- `docs/evidence/frozen/five-questions.json` — the frozen card.
- `docs/evidence/M008/review-packet-local-2026-09-26.json` — the packet the tool
  generated, with every claim's exact quote and source URL.
- `docs/evidence/M008/scorecard-local-2026-09-26.json` — the run to be scored.

**They do:** set `reviewer` to their own name, set `usefulness` (0-2) and a
`verdict` (`supported` / `partial` / `unsupported`) per citation, then run:

```sh
./.build/debug/LocalLensLive --mode review \
  --scorecard docs/evidence/M008/scorecard-local-2026-09-26.json \
  --review docs/evidence/M008/review-packet-local-2026-09-26.json \
  --out docs/evidence/M008/scorecard-reviewed.json
./.build/debug/LocalLensLive --mode calibrate \
  --scorecard docs/evidence/M008/scorecard-reviewed.json
```

**Closes:** the reviewer's name in the scorecard, and a calibration report over
at least `EvaluatorCalibration.minimumSamples` (20) labels. The labels currently
in the repository are provisional and were written by the assistant; the
calibration over them is 3 of 5 exact, mean error 0.40, and explicitly *not
calibrated*.

## 2. Second-machine reproduction

**Needs:** a different Mac, ideally not the one that built this.

**They do:**

```sh
git clone <repository> local-browser && cd local-browser
make reproduce
```

**Closes:** the command's output line
`clean-clone reproduction completed on <arch> <os version>`, recorded in
`docs/evidence/M009/`. The script refuses a dirty tree on purpose.

## 3. Notarized distribution

**Needs:** the owner's Apple account, which cannot be substituted.

**They do:**

1. Install a **Developer ID Application** certificate in the login keychain.
2. Store notary credentials once:
   `xcrun notarytool store-credentials locallens-notary --apple-id <id> --team-id <team> --password <app-specific-password>`
3. `NOTARY_PROFILE=locallens-notary make dist`

**Closes:** `dist/release/BUILD-INFO.json` with `"notarized": "yes"`, plus the
stapled bundle passing `xcrun stapler validate`. Without those two steps the
script signs with whatever identity exists and records the reason it did not
notarize; that is what the current artifact says.

## 4. Licence selection — closed

The owner authorized permissive reuse and selected MIT. The root `LICENSE`
file records the choice; `docs/LICENSING.md` inventories the shipped material.
This does not grant a licence to copy code from a separate sibling project.

## Also open, and not part of the release gate

- The M007 contradiction detector is verified by fixture only: no live run has
  produced a numeric contrast pair, and two looser variants were measured to
  produce citation-list noise and were rejected.
- The News syndication test is verified by fixture only: no observed live run
  contained a copy of another outlet's headline.
- Academic latency remains 12-123 s against a few seconds for the web baseline.
