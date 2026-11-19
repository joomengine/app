#!/usr/bin/env bash
# Print the path of the single matching, checksum-verified public release asset.
set -euo pipefail
[[ $# == 1 && ${GITHUB_REF_NAME:?} =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
directory=$(mktemp -d "${RUNNER_TEMP:?}/joomengine-release.XXXXXXXX")
gh release download "$GITHUB_REF_NAME" --repo "${GITHUB_REPOSITORY:?}" --dir "$directory" \
    --pattern "$1" --pattern SHA256SUMS
cd "$directory"
mapfile -t files < <(find . -maxdepth 1 -type f -name "$1" -printf '%f\n')
if (( ${#files[@]} != 1 )); then
    echo "Expected one $1 asset in $GITHUB_REF_NAME; found ${#files[@]}." >&2
    exit 1
fi
sha256sum --check --ignore-missing --strict SHA256SUMS >&2
printf '%s/%s\n' "$directory" "${files[0]}"
