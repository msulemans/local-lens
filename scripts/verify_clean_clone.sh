#!/bin/sh
# Reproduces the gate from a clean clone, using only documented commands.
#
# It refuses to run in a dirty tree, because "it worked on my machine" with
# uncommitted edits is not a reproduction.
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repository_root"

if [ -n "$(git status --porcelain)" ]; then
  printf 'refusing: the working tree has uncommitted changes, so a clean clone is not what this would test\n'
  git status --short | head -20
  exit 1
fi

printf '== toolchain ==\n'
swift --version

printf '\n== gate ==\n'
make gate

printf '\n== protocol and manifest parity ==\n'
python3 scripts/validate_project_manifest.py
python3 scripts/validate_protocol_schemas.py

printf '\n== bundle ==\n'
sh ./scripts/build_release.sh
sh ./scripts/verify_release.sh

printf '\n== demo (no hosted model) ==\n'
sh ./scripts/run_demo.sh | tail -6

printf '\nclean-clone reproduction completed on %s %s\n' "$(uname -m)" "$(sw_vers -productVersion)"
