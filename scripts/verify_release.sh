#!/bin/sh
# Checks a release artifact against the release gate's mechanical parts.
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repository_root"

out="$repository_root/dist/release"
bundle="$out/Local Lens.app"
failures=0

check() {
  if [ "$2" = "1" ]; then
    printf 'ok   %s\n' "$1"
  else
    printf 'FAIL %s\n' "$1"
    failures=$((failures + 1))
  fi
}

[ -d "$bundle" ] && present=1 || present=0
check "release bundle exists" "$present"
[ -f "$out/BUILD-INFO.json" ] && info=1 || info=0
check "BUILD-INFO.json exists" "$info"

if [ "$present" = "1" ]; then
  identifier=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$bundle/Contents/Info.plist")
  [ "$identifier" = "dev.locallens.app" ] && id_ok=1 || id_ok=0
  check "bundle identifier is dev.locallens.app" "$id_ok"

  codesign --verify --deep --strict "$bundle" >/dev/null 2>&1 && signed=1 || signed=0
  check "code signature verifies" "$signed"

  # No secrets, no downloaded weights, no private snapshots.
  secrets=$(grep -rIl -E 'sk-[A-Za-z0-9]{16,}|tvly-[A-Za-z0-9]{16,}|BEGIN [A-Z ]*PRIVATE KEY' "$bundle" 2>/dev/null | wc -l | tr -d ' ')
  [ "$secrets" = "0" ] && clean=1 || clean=0
  check "no credential material in the bundle" "$clean"

  weights=$(find "$bundle" -type f \( -name '*.gguf' -o -name '*.safetensors' -o -name '*.bin' -o -name '*.onnx' \) | wc -l | tr -d ' ')
  [ "$weights" = "0" ] && noweights=1 || noweights=0
  check "no model weights in the bundle" "$noweights"

  fixtures=$(find "$bundle/Contents/Resources/Fixtures" -type f | wc -l | tr -d ' ')
  [ "$fixtures" = "2" ] && fx=1 || fx=0
  check "exactly the two public fixtures are bundled" "$fx"

  text=$(find "$bundle" -type f -name '*.html' -o -type f -name '*.pdf' | wc -l | tr -d ' ')
  [ "$text" = "0" ] && nodocs=1 || nodocs=0
  check "no fetched page or PDF bodies are bundled" "$nodocs"
fi

nodefaults=1
if [ -e "$repository_root/dist" ]; then
  leaked=$(find "$repository_root/dist" -maxdepth 2 -name '*.key' -o -maxdepth 2 -name '*.pem' | wc -l | tr -d ' ')
  [ "$leaked" = "0" ] || nodefaults=0
fi
check "no key or pem files under dist/" "$nodefaults"

if [ "$failures" -gt 0 ]; then
  printf '%d release check(s) failed\n' "$failures"
  exit 1
fi
printf 'release checks passed\n'
