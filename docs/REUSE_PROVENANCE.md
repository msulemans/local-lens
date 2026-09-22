# Reuse Provenance and Licence Record

Last audited: 2026-09-22 (Australia/Sydney)

Purpose: record why Local Lens may or may not copy code from the sibling
research engine, what evidence supports that decision, and what must be true
before the first extraction commit. This record is a gate, not a formality.

## Source under review

- Path: `../deep-research-agent` (private learning lab in the same workspace)
- Revision: `1b1a698579ea6840f328c7ea6b9a288a4f26c2d9` (`1b1a698`)
- Working tree at audit: clean
- History: 89 commits, sole author
  `msulemans <53903082+msulemans@users.noreply.github.com>`
- Licence file at the repository root: **absent**
- Test inventory: 18 files under `tests/unit`, 184 discovered test functions
  (mapping in `docs/RESEARCH_CORE_BOUNDARY.md`)

Observed audit commands and results:

```text
git -C ../deep-research-agent rev-parse HEAD
  -> 1b1a698579ea6840f328c7ea6b9a288a4f26c2d9
git -C ../deep-research-agent status --porcelain | wc -l
  -> 0
git -C ../deep-research-agent shortlog -sne
  -> 89  msulemans <53903082+msulemans@users.noreply.github.com>
ls ../deep-research-agent/LICENSE*
  -> no match (no licence file)
grep -rcE '^\s*(async )?def test_' ../deep-research-agent/tests --include='*.py'
  -> 18 files, 184 test functions in total
```

## Ownership assessment

- Every commit is authored by the same identity that owns this workspace.
  No third-party author appears in the sibling history.
- No vendored third-party source was observed in the audited seams. Python
  dependencies are declared in `pyproject.toml` / `requirements.lock` and are
  not copied by extraction.
- Ownership is therefore attributable to the repository owner, but a licence
  file granting redistribution does not yet exist.

## Decision (2026-09-22)

1. Code transfer remains **blocked** until a licence file exists in the
   sibling that permits redistribution inside Local Lens. Recommended
   shortlist: MIT or Apache-2.0, finalised together with the Local Lens
   distribution licence at M009.
2. Applying that licence is an owner action, not an implementation task. It
   gates only extraction of sibling source. It does not gate clean-room work
   in this repository (schemas, fakes, fixtures, tests).
3. Until then, M001 proceeds with versioned protocol schemas and deterministic
   fakes authored in this repository. Nothing in that work may be copied from
   the sibling; it re-authors the frozen contract.
4. The first extraction commit must record the sibling revision, every copied
   path, per-file content hashes, the licence text reference, and any local
   modifications. Extraction without that manifest is a gate failure.

## Required checks before the first extraction commit

- [ ] The sibling has a `LICENSE` file whose text permits redistribution.
- [ ] This document records the licence name and the revision it covers.
- [ ] The extraction manifest lists every copied path with a content hash.
- [ ] `docs/DECISIONS.md` contains an entry approving the extraction.
- [ ] No secrets, private snapshots, model weights, or restricted corpora are
      copied.

## Recheck triggers

- the sibling revision changes;
- a licence file appears or changes;
- file authorship or vendored content is discovered inside the sibling.
