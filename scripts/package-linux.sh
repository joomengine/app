#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
version=$(node -p 'require("./package.json").version')
name="JoomEngine-${version}-linux-x64"
test "$(uname -sm)" = "Linux x86_64"
test -x dist/staged/joomengine
test -f dist/staged/resources/app/package.json
mkdir -p dist/packages
build=$(mktemp -d dist/archive.XXXXXXXX)
trap 'rm -rf -- "$build"' EXIT
mkdir -p "$build/$name"
cp -a --reflink=auto dist/staged "$build/$name/app"
chmod 0755 "$build/$name/app"
# Chromium uses user namespaces. A user-extractable archive never needs to
# grant a runtime helper setuid privileges.
chmod a-s "$build/$name/app/chrome-sandbox"
install -m 0755 packaging/linux/install.sh "$build/$name/install.sh"
install -m 0644 packaging/linux/joomengine.{desktop,apparmor} assets/joomengine.png "$build/$name/"
tar -C "$build" --owner=0 --group=0 --numeric-owner -czf "$build/$name.tar.gz" "$name"
mv -- "$build/$name.tar.gz" dist/packages/
