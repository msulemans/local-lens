#!/bin/sh
# Builds the distributable app and, when credentials exist, signs and notarizes.
#
# The script never guesses about signing. Without a Developer ID identity and a
# notary profile it produces the artifact with the best signature available and
# prints exactly what is missing, so a release cannot quietly ship unnotarized
# while claiming otherwise.
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repository_root"

version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/LocalLens-Info.plist)
build=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' Resources/LocalLens-Info.plist)
out="$repository_root/dist/release"
bundle="$out/Local Lens.app"

rm -rf "$out"
mkdir -p "$out"

swift build -c release --product LocalLensApp

mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources/Fixtures/deterministic" "$bundle/Contents/Resources/Fixtures/retrieval"
ditto "$repository_root/.build/release/LocalLensApp" "$bundle/Contents/MacOS/LocalLensApp"
ditto "$repository_root/Resources/LocalLens-Info.plist" "$bundle/Contents/Info.plist"
ditto "$repository_root/Fixtures/deterministic/quick-coffee.json" "$bundle/Contents/Resources/Fixtures/deterministic/quick-coffee.json"
ditto "$repository_root/Fixtures/retrieval/quick-view.json" "$bundle/Contents/Resources/Fixtures/retrieval/quick-view.json"
if [ -f LICENSE ]; then
  ditto "$repository_root/LICENSE" "$bundle/Contents/Resources/LICENSE"
fi

# Signing: prefer a Developer ID, then an Apple Development identity, then ad hoc.
developer_id=$(security find-identity -v -p codesigning 2>/dev/null | grep -c 'Developer ID Application' || true)
apple_dev=$(security find-identity -v -p codesigning 2>/dev/null | grep -c 'Apple Development' || true)
signature="adhoc"
if [ "$developer_id" -gt 0 ]; then
  identity=$(security find-identity -v -p codesigning | grep 'Developer ID Application' | head -1 | sed 's/.*"\(.*\)"/\1/')
  signature="developer-id"
  codesign --force --options runtime --timestamp --sign "$identity" "$bundle"
elif [ "$apple_dev" -gt 0 ]; then
  identity=$(security find-identity -v -p codesigning | grep 'Apple Development' | head -1 | sed 's/.*"\(.*\)"/\1/')
  signature="apple-development"
  codesign --force --sign "$identity" "$bundle"
else
  codesign --force --sign - "$bundle"
fi

notarized="no"
notarize_note="no Developer ID Application identity is installed, so notarization is impossible on this machine"
if [ "$signature" = "developer-id" ] && [ -n "${NOTARY_PROFILE:-}" ]; then
  zip_for_notary="$out/LocalLens-notary.zip"
  ditto -c -k --keepParent "$bundle" "$zip_for_notary"
  if xcrun notarytool submit "$zip_for_notary" --keychain-profile "$NOTARY_PROFILE" --wait; then
    xcrun stapler staple "$bundle"
    notarized="yes"
    notarize_note="notarized with profile $NOTARY_PROFILE"
  else
    notarize_note="notarytool refused the submission; the artifact is NOT notarized"
  fi
  rm -f "$zip_for_notary"
elif [ "$signature" = "developer-id" ]; then
  notarize_note="a Developer ID identity is installed but NOTARY_PROFILE is unset, so notarization was skipped"
fi

artifact="$out/LocalLens-$version.zip"
ditto -c -k --keepParent "$bundle" "$artifact"
shasum -a 256 "$artifact" | awk '{print $1}' > "$artifact.sha256"

cat > "$out/BUILD-INFO.json" <<INFO
{
  "name": "Local Lens",
  "version": "$version",
  "build": "$build",
  "bundle_identifier": "dev.locallens.app",
  "signature": "$signature",
  "notarized": "$notarized",
  "notarization_note": "$notarize_note",
  "artifact": "$(basename "$artifact")",
  "sha256": "$(cat "$artifact.sha256")",
  "built_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "machine": "$(uname -m) $(sw_vers -productVersion)"
}
INFO

printf 'Release artifact: %s\n' "$artifact"
printf 'Signature: %s · notarized: %s\n' "$signature" "$notarized"
printf 'Note: %s\n' "$notarize_note"
