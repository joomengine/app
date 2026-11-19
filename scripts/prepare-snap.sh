#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
test "$(uname -sm)" = "Linux x86_64"
test -x build/joomengine
mkdir -p dist
build=$(mktemp -d dist/snap.XXXXXXXX)
trap 'rm -rf -- "$build"' EXIT
mkdir -p "$build/payload/usr/bin" "$build/payload/usr/share/doc/joomengine"
install -m 0755 build/joomengine "$build/payload/usr/bin/joomengine"
install -m 0755 packaging/linux/launch-snap.sh "$build/payload/usr/bin/launch-joomengine"
cp -R LICENSE NOTICE LICENSES "$build/payload/usr/share/doc/joomengine/"
cp -R snap "$build/snap"
install -m 0644 assets/joomengine.png "$build/snap/gui/icon.png"
cp VERSION "$build/"
rm -rf -- dist/snap-project
mv -- "$build" dist/snap-project
trap - EXIT
