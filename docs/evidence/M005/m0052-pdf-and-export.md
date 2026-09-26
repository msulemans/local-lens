# M005.2 - Page-aware PDF evidence and citation export

Date: 2026-09-26 (Australia/Sydney)
Working tree: uncommitted on top of `5e79633`. Nothing staged or committed.

## Page-aware PDF evidence

Product need: M005.1 could reach an open-access paper only when an HTML landing
page existed. DOI resolvers frequently land on a PDF or on a bot-walled
publisher page, so a paper claim had no readable target.

Choice: **PDFKit**, the macOS system framework. It is not a package dependency,
downloads nothing, needs no model, and exposes text per page, which is exactly
what a page citation needs. The comparison considered was an in-repository PDF
parser; PDFKit was selected because a hand-rolled parser would have been both
larger and less reliable, and it would have needed its own security review.
The decision is recorded as D038.

Implementation: `Sources/LocalLensCore/PDFExtraction.swift` and a
`DocumentExtraction` router that sends a policy-checked response to the
extractor for its declared media type. A passage keeps PDFKit's exact page text
and carries `Page N` in its heading, because the frozen `Passage` entity has no
page field and must not change. A scanned or textless PDF refuses as
`no_readable_text`; a malformed body refuses as `malformed_markup`.

Live run through the unchanged acquisition boundary:

```text
$ ./.build/debug/LocalLensLive --source-url https://arxiv.org/pdf/1410.1490 \
    --question "spaced repetition model memory" --queries "spaced repetition" \
    --retrieval-queries "spaced repetition model memory" --mode retrieve
mode=retrieve elapsed_s=0.63
opened_sources=1 passages=12
fetch stored url=https://arxiv.org/pdf/1410.1490
[0] heading=Page 3   "model to predict how much work a user would need to do..."
[1] heading=Page 1   "them [1]. A typical internet user has the complex task..."
[2] heading=Page 12  "Remark 2. Count participant as surviving if s/he always..."
[5] heading=Page 1   "arXiv:1410.1490v3 [cs.CR] 24 Jan 2020 Spaced Repetition..."
```

Deterministic verification: `Tests/LocalLensCoreTests/PDFExtractionTests.swift`
builds a small PDF in memory with Core Graphics/Core Text — no fixture binary is
committed — and asserts page headings, exact untouched text, bound snapshot and
passages, hash agreement, the router's HTML/PDF split, the textless refusal, the
malformed refusal, and whitespace-only paragraph normalization.

### Deliberate refusal-matrix change

`Fixtures/fetch/schedule-scenarios.json` had a target that declared
`application/pdf` with the body `"%PDF-1.4 synthetic"` and expected
`unsupported_content_type`. PDF is now a supported extraction type, so the
correct outcome is `malformed_markup`. The fixture, the frozen-matrix text, and
`BoundedFetchTests` were updated together, with a comment recording why. This is
a deliberate expectation change, not a weakened gate: the target still refuses
with a typed reason on the same stage.

## Citation export

`Sources/LocalLensCore/CitationExport.swift` renders a completed answer as
BibTeX, RIS, or Markdown. Only cited works are exported, entries dedupe by
source URL in marker order, keys are content-derived, braces are escaped, and no
author or year is invented — the available metadata is a title, a fetched URL,
and the exact-passage identity, which is recorded in the note field.

The app's completed brief and history replay now carry an **EXPORT** row
observed in the accessibility outline:

```text
EXPORT  [Answer + sources]  [BibTeX]  [RIS]
"Copied <label>" appears after a copy
```

Deterministic verification: `testCitationExportIsDeterministicDeduplicatedAndEscaped`.

## Gate result

```text
$ swift build && swift test
Executed 273 tests, with 0 failures
$ make gate
validators conform (run after this record); offline guards unchanged
```

The app bundle was rebuilt and observed with a local Quick answer:
4 exact passages, 5 sources, 34.3 s, `LOCAL · qwen2.5-coder:14b-instruct-q4_K_M`,
and the EXPORT row present. No hosted call; cost US$0.

## Preserved failures and open gates

- A scanned or image-only PDF refuses; there is no OCR and none is planned
  without a measured need and a model-policy record.
- PDF page mapping relies on PDFKit's per-page text; a PDF whose text layer is
  wrong is wrong here too.
- Academic `Limitations` coverage remains 0 and publisher refusals remain.
- Export metadata is minimal by design; BibTeX consumers that require author or
  year will see a generic entry.
- Notarized packaging and second-Mac reproduction remain unproven.

## Proof boundary

Implemented: page-aware PDF extraction and three export formats.
Deterministically verified: 273 tests.
Locally measured: the live arXiv PDF run and the in-app EXPORT row.
Live-provider verified: arXiv PDF fetch through the acquisition boundary.
Not packaged or reproduced on a second machine.
