# Security and Privacy Contract

## Data classes

| Data | Default location | Network rule |
|---|---|---|
| questions and history | local SQLite | never sent except to explicitly selected search/model providers |
| source snapshots | local private artifacts | acquired only from selected public URLs |
| passages and indexes | local SQLite/artifacts | remain local unless user selects a hosted model that requires them |
| model weights | local application support | downloaded only after explicit model selection |
| API credentials | macOS Keychain | sent only to the matching provider |
| benchmark fixtures | repository when redistributable | deterministic, no secrets |
| diagnostics | local export | secret-redacted before sharing |

## Privacy UI requirements

Every run displays one of:

- `Local model`;
- `Apple on-device model`;
- `Hosted model: <provider>`; or
- `No generation model`.

Search egress is displayed separately from model egress. A local model does not
make live web search offline.

Before a hosted model is used for the first time, the app explains what text is
sent. Provider switching cannot happen silently.

## Web acquisition threats

The fetch layer must handle:

- SSRF and DNS rebinding;
- redirects to private or metadata addresses;
- oversized or decompression-bomb content;
- misleading content types;
- redirect loops;
- slow responses;
- hostile HTML and prompt injection inside pages;
- accidental authentication or cookie use;
- paywalls and CAPTCHAs; and
- untrusted filenames and document metadata.

Acquired text is untrusted evidence, never instructions. It cannot change
system policy, budgets, tools, destinations, or model configuration.

## Fetch policy

- HTTP/HTTPS only.
- Resolve and validate every destination before connection and after redirect.
- No ambient browser cookies or logged-in session reuse.
- No form submissions.
- No CAPTCHA solving or paywall bypass.
- Per-host rate limits and bounded concurrency.
- Explicit timeout, redirect, byte, decompressed-size, and extracted-character
  limits.
- Stable user agent and contact information before public release.
- Robots and site terms respected.

## Rendering and documents

JavaScript rendering is an exceptional fallback in a sandboxed process. The
renderer receives only the target public URL and no user credentials.

PDF and document parsers run with strict size/time limits. Embedded scripts,
attachments, and active content are ignored. Extracted text records its parser
and version.

## Local storage

- Private artifacts live under application support, not the repository.
- Completed snapshots are immutable within their run.
- Deletion and retention controls will be implemented before public release.
- Export bundles are explicit and previewable.
- Search history display has a privacy setting and clear-history path.

## Secrets

- Store provider keys in Keychain.
- Never write credentials to run events, logs, crash reports, benchmark files,
  screenshots, or provenance exports.
- `.env` is development-only and Git-ignored.
- Tests use fake values and scan fixtures/exports for secret-shaped strings.

## Model downloads

Before download, show model identity, revision, licence, approximate disk use,
and memory guidance. Verify available disk space and available hash/signature
metadata. Do not execute arbitrary post-install scripts.

## Update and release boundary

The public application must be code signed and notarized. Any updater requires
signed artifacts and a documented rollback path. This gate is deferred to M009.

## Security verification ladder

1. schema and state tests;
2. URL/IP policy tests;
3. hostile fixture tests;
4. local integration tests with a controlled HTTP server;
5. approved public-URL smoke tests;
6. privacy-safe diagnostics inspection; and
7. packaged-app verification.

Passing an earlier layer is not proof of a later one.
