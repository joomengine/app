#!/usr/bin/env bash
# Install the official, relocatable Linux SDK into a private prefix.
set -euo pipefail
sdk=${1:?Specify the SDK directory}
mkdir -p "$sdk"
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
while read -r digest archive; do
  name=${archive##*/}
  curl --fail --silent --show-error --location --retry 3 --retry-all-errors \
    "https://download.qt.io/online/qtsdkrepository/linux_x64/$archive" --output "$work/$name"
  (cd "$work" && printf '%s  %s\n' "$digest" "$name" | sha256sum --check)
  (cd "$sdk" && cmake -E tar xf "$work/$name")
  rm "$work/$name"
done < "$(dirname "$0")/qt-sdk.lock"
# Qt Installer Framework normally places the ICU archive under the kit's lib/.
mv "$sdk"/libicu*.so.* "$sdk/lib/"
printf '[Paths]\nPrefix=..\n' > "$sdk/bin/qt.conf"
test -x "$sdk/libexec/QtWebEngineProcess"
test -s "$sdk/lib/libQt6WebEngineCore.so.6.11.2"
