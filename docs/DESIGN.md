# Design

The workspace follows one reference: `docs/design/local-lens-living-research-map.png`.
That image is the layout PRODUCT.md selects, and the shipped surface is measured
against it rather than against taste.

## What the design is for

The product's subject is evidence: a claim, and the exact stored passage that
backs it. The screen exists to make that link visible and checkable. Everything
else stays quiet so a tinted or enlarged thing always means something.

## The system

`Sources/LocalLensApp/DesignSystem.swift` holds it.

**Surfaces** are semantic system colours - `windowBackgroundColor`,
`textBackgroundColor`, `underPageBackgroundColor`, `separatorColor` - so light
and dark appearance are both correct without a second palette.

**One accent** means one thing: `evidence`, a claim backed by an exact stored
passage. Two semantic flags follow: `caution` (single-source, undated, thin, or
not yet addressed) and `conflict` (two stored pages disagree, or a run refused to
answer). Nothing else is tinted.

**Type** is SF Pro with a deliberate scale: a display size for the question and
the answer, one section size, one reading size for prose, one body size, one
label size, one caption size, and a monospaced-digit size used *only* where
numbers must align in a column. Sentence case throughout.

**Structure** is information: a hairline border instead of a shadow, one card
radius, and section headings that say what the section is for rather than
labelling it.

## Rules that come from the product, not from the mockup

The mockup shows verdicts (`Excellent`, `Good`, `Fair`) against each option in a
comparison. This product cannot produce those, so it does not render them. A
comparison cell reports what was measured: how many stored passages satisfy the
criterion **and** mention that side. A News answer reports how many of its claims
a second independent voice carries. Coverage reports how many stored passages use
a criterion's vocabulary. The same rule applies to the selection panel: sources
are chipped `2+ sources` or `Single source`, which are counts, not ratings.

## Tells this design removes

The previous surface had the marks of generated scaffolding, and they are now
deliberately absent: tracked-out all-caps labels above every section, meta
strings joined with `·`, a monospace face used for prose labels, `→` appended to
button text, and a single-line text field that clipped a long question at both
ends. `docs/evidence/M009/` holds before and after screenshots.

## Adapting

The window opens at 1320x880, the size the two-column layout is designed for.
Below 1080 points the evidence column moves into a sheet, so the brief keeps a
readable measure instead of being squeezed; the question field grows from one to
six lines; and the mode and status controls sit on their own row so neither the
field nor the buttons can starve the other.

## What is not claimed

No measurement here says the surface is good, or better than what it replaced.
Nothing in this repository can measure that. It is a human judgement, and the
evidence files say so.
