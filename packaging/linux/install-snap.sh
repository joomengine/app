#!/usr/bin/env bash
# Install or update the verified GitHub Snap without requiring interface setup.
set -euo pipefail
export LC_ALL=C

fail() { echo "JoomEngine installation: $*" >&2; exit 1; }
filename='@SNAP_FILENAME@'
digest='@SNAP_SHA256@'
[[ "$digest" =~ ^[a-f0-9]{64}$ ]] || fail "Use the self-contained installer from GitHub Releases."
[[ $# -le 1 ]] || fail "Run bash joomengine-install-snap.sh. Optionally pass the matching local .snap file."
[[ $(uname -m) == x86_64 ]] || fail "This package requires an x86-64 Linux machine."
if (( $# == 0 )); then
    work=$(mktemp -d)
    trap 'rm -rf -- "$work"' EXIT
    snap_file="$work/$filename"
    self=${BASH_SOURCE[0]}
    first=$(awk '$0 == "# JOOMENGINE EMBEDDED SNAP" { print NR+1; exit }' "$self")
    [[ "$first" =~ ^[0-9]+$ ]] || fail "This installer is incomplete. Download it again."
    tail -n "+$first" -- "$self" | base64 --decode > "$snap_file" ||
        fail "The embedded Snap is damaged. Download the installer again."
else
    [[ -f $1 ]] || fail "The selected Snap file does not exist."
    snap_file=$(realpath -- "$1")
fi
actual=$(sha256sum < "$snap_file")
[[ "${actual%% *}" == "$digest" ]] ||
    fail "The package checksum differs from the embedded SHA-256. Download the installer again."

command -v snap >/dev/null || fail "Install snapd for your distribution first: https://snapcraft.io/docs/installing-snapd"
metadata=$(snap info --verbose "$snap_file") || fail "snapd could not read the downloaded package."
grep -Eq '^name:[[:space:]]+joomengine$' <<<"$metadata" &&
    grep -Eq '^[[:space:]]*confinement:[[:space:]]+strict$' <<<"$metadata" ||
    fail "This file must contain the strictly confined joomengine snap."
admin=()
if (( EUID != 0 )); then
    command -v sudo >/dev/null || fail "Run this installer as an administrator, or install sudo."
    admin=(sudo)
fi
"${admin[@]}" timeout 10m snap wait system seed.loaded || fail "Could not wait for snapd to finish seeding. Check systemctl status snapd and retry."

# Providing the dependencies first also supports an unsigned local installation
# on a distribution which does not automatically install local file providers.
for provider in kde-qt6-core24 mesa-2404; do
    if ! snap list "$provider" >/dev/null 2>&1; then
        "${admin[@]}" snap install "$provider" || fail "Could not install the $provider runtime from the Snap Store."
    fi
done
# A local file is installed with the same command on first install and update.
# snapd retains common data and carries the active revision's user data forward.
revision=$(snap list joomengine 2>/dev/null | awk '$1 == "joomengine" {print $3}') || revision=
if [[ "$revision" =~ ^x?[0-9]+$ ]] && "${admin[@]}" cmp --silent "$snap_file" "/var/lib/snapd/snaps/joomengine_$revision.snap"; then
    echo "This exact JoomEngine revision is already installed."
else
    "${admin[@]}" snap install --dangerous "$snap_file" || fail "snapd could not install or update $filename."
fi

connect_if_needed() {
    local plug=$1
    shift
    local connections
    connections=$(snap connections joomengine)
    if ! awk -v plug="joomengine:$plug" '$2 == plug && $3 != "-" {found=1} END {exit !found}' <<<"$connections"; then
        "${admin[@]}" snap connect "joomengine:$plug" "$@" ||
            fail "snapd could not configure $plug. See snap connections joomengine for details."
    fi
}
connect_if_needed kde-qt6-core24 kde-qt6-core24:kde-qt6-core24-slot
connect_if_needed gpu-2404 mesa-2404:gpu-2404
connect_if_needed browser-support
connect_if_needed hardware-observe

echo "JoomEngine is ready. Open JoomEngine from the applications menu or run: snap run joomengine"
exit 0  # The downloadable installer carries its encoded Snap below this point.
