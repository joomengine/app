#!/usr/bin/env bash
# Qt's online installer publishes universal, relocatable macOS SDK archives.
set -euo pipefail
sdk=${1:?Expected the Qt SDK destination}
repository=$(cd -- "$(dirname "$0")/../.." && pwd)
mkdir -p "$sdk"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
while read -r digest archive; do
  filename=${archive##*/}
  curl --fail --location --silent --show-error --retry 3 --retry-all-errors --connect-timeout 20 \
    "https://download.qt.io/online/qtsdkrepository/mac_x64/$archive" -o "$work/$filename"
  (cd "$work" && printf '%s  %s\n' "$digest" "$filename" | shasum -a 256 --check --status)
  (cd "$sdk" && cmake -E tar xf "$work/$filename")
  rm "$work/$filename"
done < "$repository/packaging/macos/qt-sdk.lock"
# Relocate the SDK's own command line tools. macdeployqt writes a separate
# bundle-relative qt.conf for the installed application.
printf '[Paths]\nPrefix=..\n' > "$sdk/bin/qt.conf"
test -x "$sdk/bin/macdeployqt"
test -f "$sdk/lib/cmake/Qt6WebEngineWidgets/Qt6WebEngineWidgetsConfig.cmake"
