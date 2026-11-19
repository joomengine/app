#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
test "$(uname -sm)" = "Linux x86_64"
test -x dist/staged/joomengine
test -f dist/staged/resources/app/package.json
mkdir -p dist
build=$(mktemp -d dist/snap.XXXXXXXX)
trap 'rm -rf -- "$build"' EXIT
mkdir -p "$build/payload/opt"
cp -a --reflink=auto dist/staged "$build/payload/opt/joomengine"
chmod 0755 "$build/payload/opt/joomengine"
# The connected browser-sandbox interface enables the namespace sandbox.
rm -- "$build/payload/opt/joomengine/chrome-sandbox"
cp -a snap "$build/snap"
install -m 0644 assets/joomengine.png "$build/snap/gui/icon.png"
node -p 'require("./package.json").version' > "$build/VERSION"
rm -rf -- dist/snap-project
mv -- "$build" dist/snap-project
trap - EXIT
