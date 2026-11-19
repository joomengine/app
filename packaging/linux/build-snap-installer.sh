#!/usr/bin/env bash
# Append the exact Snap as base64 so the downloadable installer is a text script.
set -euo pipefail
[[ $# == 2 && -f $1 ]] || { echo "Usage: $0 JoomEngine.snap installer.sh" >&2; exit 1; }
filename=${1##*/}
[[ "$filename" =~ ^joomengine_[0-9]+\.[0-9]+\.[0-9]+_amd64\.snap$ ]]
sum=$(sha256sum < "$1")
temporary=$(mktemp -- "${2}.XXXXXXXX")
trap 'rm -f -- "$temporary"' EXIT
sed -e "s/@SNAP_FILENAME@/$filename/" -e "s/@SNAP_SHA256@/${sum%% *}/" \
    "$(dirname "$0")/install-snap.sh" > "$temporary"
printf '\n# JOOMENGINE EMBEDDED SNAP\n' >> "$temporary"
base64 --wrap=76 "$1" >> "$temporary"
chmod 0755 "$temporary"
mv -- "$temporary" "$2"
