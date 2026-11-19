#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 2 || ! $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || ! $2 =~ ^[0-9a-f]{64}$ ]]; then
    echo "Usage: $0 MAJOR.MINOR.PATCH lower-case-source-SHA256" >&2
    exit 2
fi
sed -e "s/@VERSION@/$1/g" -e "s/@SHA256@/$2/g" "$(dirname "$0")/PKGBUILD.in"
