#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != Darwin ]]; then
  echo "The DMG must be built on macOS." >&2
  exit 1
fi
app="$PWD/dist/staged/JoomEngine.app"
[[ -d "$app" ]] || { echo "Stage JoomEngine with npm run stage first." >&2; exit 1; }

temp_dir="$(mktemp -d)"
keychain=""
cleanup() {
  if [[ -n "$keychain" ]]; then security delete-keychain "$keychain" || true; fi
  rm -rf "$temp_dir"
}
trap cleanup EXIT

# CI supplies an exported Developer ID certificate. Local developers may
# instead select an identity already in their login keychain.
if [[ -n "${APPLE_CERTIFICATE_BASE64:-}${APPLE_CERTIFICATE_PASSWORD:-}" ]]; then
  : "${APPLE_CERTIFICATE_BASE64:?Missing exported Apple certificate}"
  : "${APPLE_CERTIFICATE_PASSWORD:?Missing Apple certificate password}"
  : "${APPLE_SIGNING_IDENTITY:?Missing Developer ID Application identity}"
  keychain="$temp_dir/build.keychain-db"
  password="$(openssl rand -hex 24)"
  umask 077
  printf '%s' "$APPLE_CERTIFICATE_BASE64" | base64 -D > "$temp_dir/certificate.p12"
  security create-keychain -p "$password" "$keychain"
  security set-keychain-settings -lut 3600 "$keychain"
  security unlock-keychain -p "$password" "$keychain"
  security import "$temp_dir/certificate.p12" -k "$keychain" \
    -P "$APPLE_CERTIFICATE_PASSWORD" -T /usr/bin/codesign
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$keychain" >/dev/null
  rm "$temp_dir/certificate.p12"
  export APPLE_SIGNING_KEYCHAIN="$keychain"
  umask 022
fi
if [[ -n "${APPLE_ID:-}${APPLE_TEAM_ID:-}${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
  : "${APPLE_SIGNING_IDENTITY:?Notarization requires a Developer ID Application identity}"
  : "${APPLE_ID:?Missing Apple account ID}"
  : "${APPLE_TEAM_ID:?Missing Apple team ID}"
  : "${APPLE_APP_SPECIFIC_PASSWORD:?Missing Apple app-specific password}"
fi

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
arch="$(node -p 'process.arch')"
case "$arch" in x64|arm64) ;; *) echo "Unsupported macOS architecture: $arch" >&2; exit 1 ;; esac
# Keep Electron's and Chromium's distribution notices with the installed copy.
for notice in dist/staged/LICENSE*; do
  if [[ -f "$notice" ]]; then
    mkdir -p "$app/Contents/Resources/licenses"
    cp "$notice" "$app/Contents/Resources/licenses/"
  fi
done
node packaging/macos/sign.mjs "$app"
mkdir -p "$temp_dir/image" dist/packages
ditto "$app" "$temp_dir/image/JoomEngine.app"
ln -s /Applications "$temp_dir/image/Applications"
name="JoomEngine-$version-macos-$arch.dmg"
dmg="$temp_dir/$name"
hdiutil create -volname JoomEngine -fs HFS+ -srcfolder "$temp_dir/image" -format UDZO "$dmg"
if [[ -n "${APPLE_SIGNING_IDENTITY:-}" ]]; then
  if [[ -n "${APPLE_SIGNING_KEYCHAIN:-}" ]]; then
    codesign --sign "$APPLE_SIGNING_IDENTITY" --keychain "$APPLE_SIGNING_KEYCHAIN" --timestamp "$dmg"
  else
    codesign --sign "$APPLE_SIGNING_IDENTITY" --timestamp "$dmg"
  fi
fi
if [[ -n "${APPLE_ID:-}" ]]; then
  xcrun notarytool submit "$dmg" --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" --wait --timeout 30m --output-format json > "$temp_dir/notary.json"
  result="$(plutil -extract status raw -o - "$temp_dir/notary.json")"
  if [[ "$result" != Accepted ]]; then
    cat "$temp_dir/notary.json" >&2
    exit 1
  fi
  xcrun stapler staple "$dmg"
  xcrun stapler validate "$dmg"
fi
hdiutil verify "$dmg"
mv -f "$dmg" "dist/packages/$name"
printf 'Created %s\n' "dist/packages/$name"
