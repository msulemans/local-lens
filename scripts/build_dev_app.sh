#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repository_root"

swift build -c release --product LocalLensApp

bundle="$repository_root/dist/Local Lens.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources/Fixtures/deterministic" "$bundle/Contents/Resources/Fixtures/retrieval"
ditto "$repository_root/.build/release/LocalLensApp" "$bundle/Contents/MacOS/LocalLensApp"
ditto "$repository_root/Resources/LocalLens-Info.plist" "$bundle/Contents/Info.plist"
ditto "$repository_root/Fixtures/deterministic/quick-coffee.json" "$bundle/Contents/Resources/Fixtures/deterministic/quick-coffee.json"
ditto "$repository_root/Fixtures/retrieval/quick-view.json" "$bundle/Contents/Resources/Fixtures/retrieval/quick-view.json"
codesign --force --sign - "$bundle"

printf 'Built development app: %s\n' "$bundle"
