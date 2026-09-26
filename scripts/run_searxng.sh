#!/usr/bin/env bash
# Start the development SearXNG that the live Quick path uses.
#
# The stock SearXNG default `general` engines are all scrape-based and
# soft-block under repeated use (brave, duckduckgo html, google cse, startpage,
# qwant, yahoo). `scripts/searxng/settings.yml` keeps the engines measured on
# 2026-09-25 to return relevant results and disables the rest, so a query is
# not a fan-out into suspended engines. This is a development baseline only:
# a normal-user release must not require Docker (docs/COMPLETE_PLAN.md), and
# production search should use a licensed search API.
set -euo pipefail

NAME="locallens-searxng"
PORT="${LOCALLENS_SEARXNG_PORT:-8888}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" \
  -p "127.0.0.1:${PORT}:8080" \
  -v "$ROOT/scripts/searxng:/etc/searxng" \
  --restart unless-stopped \
  searxng/searxng >/dev/null

echo "SearXNG dev baseline started at http://127.0.0.1:${PORT}"
echo "Verify: curl -s 'http://127.0.0.1:${PORT}/search?q=swift&format=json' | head -c 200"
