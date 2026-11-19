#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
version=$(cat VERSION)
name="JoomEngine-${version}-linux-x64"
test "$(uname -sm)" = "Linux x86_64"
test -x build/joomengine
mkdir -p dist/packages
build=$(mktemp -d dist/archive.XXXXXXXX)
trap 'rm -rf -- "$build"' EXIT
mkdir -p "$build/$name"
install -m 0755 build/joomengine packaging/linux/install.sh "$build/$name/"
install -m 0644 docs/install-linux-archive.md "$build/$name/README.md"
install -m 0644 packaging/linux/joomengine.desktop assets/joomengine.png \
  LICENSE NOTICE "$build/$name/"
cp -R LICENSES "$build/$name/LICENSES"
tar -C "$build" --owner=0 --group=0 --numeric-owner -czf "$build/$name.tar.gz" "$name"
mv -- "$build/$name.tar.gz" dist/packages/
