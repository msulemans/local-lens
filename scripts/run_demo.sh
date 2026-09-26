#!/bin/sh
# Runs the three-question demo against whatever path the environment allows.
#
# A demo must never need a key to prove the parts that do not: the retrieval
# path runs without any AI at all. Set TAVILY_API_KEY for discovery.
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repository_root"

if [ ! -x ./.build/debug/LocalLensLive ]; then
  swift build >/dev/null
fi

question="${1:-Compare SQLite WAL mode and the default rollback journal for a small app}"

if [ -z "${TAVILY_API_KEY:-}" ]; then
  printf 'TAVILY_API_KEY is unset, so the live discovery demos are skipped.\n'
  printf 'Export it (a free Tavily key is enough) and run this script again for demos 1 and 2.\n\n'
else
  printf '== demo 1: one mode plan, every fetch outcome ==\n'
  ./.build/debug/LocalLensLive --tavily --mode research --plan deep --question "$question" | head -20

  printf '\n== demo 2: the same question with an edited dimension plan ==\n'
  ./.build/debug/LocalLensLive --tavily --mode research --plan deep --dimensions "Cost, Concurrency" \
    --question "$question" | grep -E '^dimensions=|^coverage=|^opened_sources='
fi

printf '\n== demo 3: an invalid plan is refused, not repaired ==\n'
if ./.build/debug/LocalLensLive --mode research --plan quick --dimensions "Cost,Risk" --question "$question"; then
  printf 'demo 3 FAILED: an invalid plan was accepted\n'
  exit 1
else
  printf 'demo 3: refused as expected\n'
fi

printf '\n== demo 4: the citation boundary refuses a corrupted compilation ==\n'
swift test --filter testValidCompilationResolvesAndEveryCorruptionIsDetected 2>&1 | tail -3

printf '\nEverything above runs at US$0 with no hosted model.\n'
