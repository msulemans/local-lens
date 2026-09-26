# M003.9 search backend decision, before implementation

Recorded 2026-09-26 AEST before adding another search adapter. This is a
product-portability treatment, **not** an answer-quality promotion or a model
experiment. The existing frozen answer card remains below threshold.

## Measured need and comparison baseline

The Mac app currently opens the offline fixture by default. Its live open-web
path requires a separately managed Docker SearXNG endpoint; the current five
fresh retrieval runs took 8.58-11.94 seconds end-to-end and were mixed in
source relevance. The M003.7 full frozen answer pass scored 1/10, with a
targeted Q1/Q5 treatment projecting 3/10, still below promotion. A user-pasted
public URL works without SearXNG, but researches only that page. No current
normal-user open-web path meets the no-Docker gate.

| Path | Normal-user setup | Search baseline | Product decision |
|---|---|---|---|
| Pinned SearXNG | Docker and a manually managed local endpoint | Existing measured development baseline; engines have suspended and results vary | Keep for contributors and comparison; not the default Mac release path. |
| Supplied public page | Paste one URL, no search service | One-page in-app cited answer already observed | Keep as the zero-search fallback; do not call it open-web search. |
| Tavily Search, basic | User obtains free-tier API key; no card, Docker, or local server | No live key or quality measurement yet; cannot claim speed or relevance improvement | Default no-card open-web option; add replaceable adapter and Keychain field, then measure separately. |
| Brave Search API Web Search | User obtains an API key and supplies a card to Brave; app needs no Docker or local server | No live key or quality measurement yet; cannot claim speed or relevance improvement | Keep optional for users who already have a key; not the default. |
| Exa Search | Free $10 monthly credits, no payment method; per-request pricing and a different API contract | No measured advantage over Tavily here | Reserve as a replacement candidate if Tavily fails a bounded live comparison, not another unmeasured integration. |

The owner has no Brave key and explicitly asked for a no-card alternative.
[Tavily's current pricing page](https://www.tavily.com/pricing) states that
the Researcher tier includes 1,000 API credits per month with no card and
stops requests when the free credits run out. Its [Search API
contract](https://docs.tavily.com/documentation/api-reference/endpoint/search)
specifies an authenticated `POST https://api.tavily.com/search`, `basic`
search at one credit, and bounded `results` with title, URL, and content.
We request no Tavily-generated answer or raw page body: both would bypass
our own fetch/citation trust boundary. Tavily `content` remains discovery
metadata, even though the vendor extracts it from pages. The [Exa
plan](https://exa.ai/pricing) also currently offers no-card recurring credits,
but adding both now would multiply integrations without a measured need.

Brave is an established, sanctioned web-search API, not a scraper or a model.
Its [current Web Search documentation](https://api-dashboard.search.brave.com/app/documentation/web-search)
specifies `GET /res/v1/web/search`, `q`, bounded `count`, and `web.results`.
[Authentication documentation](https://api-dashboard.search.brave.com/documentation/guides/authentication)
requires `X-Subscription-Token`. The [current plan page](https://brave.com/search/api/)
lists $5 per 1,000 Search requests with $5 monthly credits and states that a
card is required to activate a plan. These are vendor terms, not an app cost
promise; users provide their own key. The same page says API result storage
rights require a plan that grants them. This app therefore converts the
response to transient URL/title/snippet **discovery metadata**, never persists
the raw API payload, and still fetches public pages through its existing
robots, address, redirect, and snapshot boundaries. Third-party page rights
remain separate from the search API.

## Bounded implementation and proof

- Keep `SearchAdapter` and `SearchHit` unchanged. Add Tavily and optional Brave
  adapters over the already-injected transport, bounded at 10 results, with typed HTTP,
  transport, malformed-payload, and empty outcomes. No new dependency.
- Pin the production endpoint; tests inject a transport and synthetic JSON.
  Never print, persist, or place the key in URL/artifacts. Search snippets stay
  discovery metadata and cannot become citations.
- In the Mac app, default to a free Tavily key with explicit Keychain saving;
  retain optional Brave and self-hosted SearXNG for users who have them. A
  supplied URL bypasses all three.
  The app must explain which network/hosted services a run uses.
- Do not make a live search call without a user key. Adapter tests and app build
  prove integration shape only. Re-run the frozen card under a separately
  recorded call cap if and when the key exists; do not infer quality from API
  marketing.

Stop/rollback: if a hosted search API contract or terms are incompatible, keep the
SearXNG and supplied-page paths; neither the citation boundary nor offline
fixture may be weakened to make the adapter pass.
