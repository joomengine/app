#!/usr/bin/env bash
# Deploy the framework dependencies and their native renderer for a single Mac CPU.
set -euo pipefail
source_app=${1:?Expected the CMake-built .app}
output_app=${2:?Expected the destination .app}
repository=$(cd -- "$(dirname "$0")/.." && pwd)
arch=$(uname -m)
[[ "$arch" == x86_64 || "$arch" == arm64 ]]
test -d "$source_app"
test ! -e "$output_app"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
ditto "$source_app" "$work/JoomEngine.app"
macdeployqt "$work/JoomEngine.app" -no-codesign -always-overwrite
plist="$work/JoomEngine.app/Contents/Frameworks/QtCore.framework/Resources/Info.plist"
if [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")" != 6.11.2 ]]; then
  echo "The published Qt sources and notices for this DMG require Qt 6.11.2." >&2
  exit 1
fi
python3 "$repository/scripts/package-qt-notices.py" "$work/JoomEngine.app/Contents/Resources"
# Qt's published macOS SDK contains both CPU slices. Keep each disk image
# usable independently without making its users download the other slice.
ditto --arch "$arch" "$work/JoomEngine.app" "$output_app"

framework="$output_app/Contents/Frameworks/QtWebEngineCore.framework"
helper="$framework/Helpers/QtWebEngineProcess.app"
entitlements="$helper/Contents/Resources/QtWebEngineProcess.entitlements"
test -s "$entitlements"
lipo "$framework/QtWebEngineCore" -verify_arch "$arch"
lipo "$helper/Contents/MacOS/QtWebEngineProcess" -verify_arch "$arch"
test -s "$framework/Resources/qtwebengine_resources.pak"

signature=(--force --sign "${APPLE_SIGNING_IDENTITY:--}")
if [[ -n "${APPLE_SIGNING_IDENTITY:-}" ]]; then
  signature+=(--options runtime --timestamp)
  if [[ -n "${APPLE_SIGNING_KEYCHAIN:-}" ]]; then signature+=(--keychain "$APPLE_SIGNING_KEYCHAIN"); fi
else
  signature+=(--timestamp=none)
fi

# Seal components from the inside out after thinning. The renderer has its
# own hardened-runtime JIT entitlements supplied by the Qt SDK.
while IFS= read -r -d '' file; do
  if [[ "$(file -b "$file")" == *Mach-O* ]]; then codesign "${signature[@]}" "$file"; fi
done < <(find "$output_app/Contents" -type f \( -perm -111 -o -name '*.dylib' \) -print0)
while IFS= read -r -d '' bundle; do
  if [[ "$bundle" == */QtWebEngineProcess.app ]]; then
    codesign "${signature[@]}" --entitlements "$entitlements" "$bundle"
  else
    codesign "${signature[@]}" "$bundle"
  fi
done < <(find "$output_app/Contents" -depth -type d \( -name '*.app' -o -name '*.framework' \) -print0)
codesign "${signature[@]}" "$output_app"
codesign --verify --strict --deep "$output_app"
