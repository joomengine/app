#!/usr/bin/env bash
# Append a SquashFS AppDir to the official static Type 2 ELF runtime.
set -euo pipefail
runtime=${1:?Specify the AppImage runtime}
appdir=${2:?Specify the prepared AppDir}
output=${3:?Specify the output AppImage}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
printf '%s  %s\n' 2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d "$runtime" | sha256sum -c
[[ $("$runtime" --appimage-offset) == $(stat -c %s "$runtime") ]]
mksquashfs "$appdir" "$work/root.squashfs" -noappend -all-root -no-xattrs -comp zstd -no-progress
cat "$runtime" "$work/root.squashfs" > "$output"
chmod 0755 "$output"
