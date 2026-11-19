#!/usr/bin/env bash
# Damage only the payload. Hash/decode rejection must precede snapd or sudo.
set -euo pipefail
installer=${1:?Pass the complete downloadable installer}
test -s "$installer"
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/bin"
for tool in snap sudo; do
    printf '#!/bin/sh\ntouch "$INSTALLER_TEST_SYSTEM_ACCESS"\nexit 1\n' > "$work/bin/$tool"
    chmod +x "$work/bin/$tool"
done
export INSTALLER_TEST_SYSTEM_ACCESS="$work/attempted"
export PATH="$work/bin:$PATH"
# Removing a whole encoded data line exercises truncation. Flipping a valid
# base64 letter keeps the payload decodable and specifically tests its digest.
sed '$d' "$installer" > "$work/truncated.sh"
awk 'change { $0=(substr($0,1,1)=="A" ? "B" : "A") substr($0,2); change=0 }
     {print} $0=="# JOOMENGINE EMBEDDED SNAP" {change=1}' "$installer" > "$work/altered.sh"
for broken in "$work/truncated.sh" "$work/altered.sh"; do
    if bash "$broken" > "$work/log" 2>&1; then
        echo "A damaged installer was accepted." >&2
        exit 1
    fi
    grep -Eq 'package checksum differs|embedded Snap is damaged' "$work/log"
    test ! -e "$INSTALLER_TEST_SYSTEM_ACCESS"
done
