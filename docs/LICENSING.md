# Licensing

## What this repository ships

Local Lens depends on no third-party code. The package has no external
dependencies, and the app links only Apple system frameworks: SwiftUI, AppKit,
Foundation, PDFKit, and Network (used solely by the core's transport, never by
the app target). No model weights, no corpus, and no copied source from another
project are included.

The two bundled fixtures (`Fixtures/deterministic/quick-coffee.json`,
`Fixtures/retrieval/quick-view.json`) are synthetic: they were written for this
repository and contain no copyrighted page text.

Benchmark material: `docs/evidence/frozen/five-questions.json` holds questions
written for this repository, and the scorecards hold counts, quotes from pages
the runs fetched, and human labels. Quotes are short extracts used as the
citation evidence itself and are attributed with their source URL in every
artifact.

## Repository licence

The owner authorized reuse for the public repository on 2026-09-26. The
repository is licensed under [MIT](../LICENSE), a permissive licence requiring
the copyright and permission notice to be kept with copies. This closes the
repository-licence choice, but does not resolve whether code from a separate
sibling project may be copied here.

`docs/REUSE_PROVENANCE.md` records the separate question of copying sibling code;
it is unrelated to this choice and remains a gate of its own.

`scripts/build_release.sh` copies the `LICENSE` file into the release bundle.
`make verify-release` checks the bundle for credential material, model weights,
and fetched page bodies. This is not a legal opinion about external material.
