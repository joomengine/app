#!/usr/bin/env bash
# Install through the same Store route a desktop user will take and return only
# the exact signed revision whose installed bytes and automatic connections pass.
set -euo pipefail
export LC_ALL=C
release_snap=${1:?Pass the GitHub release Snap}
if snap list joomengine >/dev/null 2>&1; then
    echo "The Store check requires a clean runner." >&2
    exit 1
fi
# Allow a short propagation delay when a new Store revision has just gone live.
# Use a normal channel install so snapd obtains Store assertions and providers.
revision=
for attempt in {1..12}; do
    if snap list joomengine >/dev/null 2>&1; then
        sudo snap refresh joomengine --channel=latest/candidate
    else
        sudo snap install joomengine --channel=latest/candidate || echo "Candidate installation is not available yet."
    fi
    revision=$(snap list joomengine 2>/dev/null | awk '$1=="joomengine" {print $3}') || revision=
    if [[ "$revision" =~ ^[1-9][0-9]*$ ]] &&
        sudo cmp --silent "$release_snap" "/var/lib/snapd/snaps/joomengine_$revision.snap"; then
        break
    fi
    revision=
    if (( attempt < 12 )); then sleep 10; fi
done
if [[ -z "$revision" ]]; then
    echo "The exact GitHub release bytes were not served by latest/candidate. Check the Snap Store review and channel." >&2
    exit 1
fi

connections=$(snap connections joomengine)
for plug in kde-qt6-core24 gpu-2404 browser-support hardware-observe; do
    if ! awk -v plug="joomengine:$plug" '$2 == plug && $3 != "-" {found=1} END {exit !found}' <<<"$connections"; then
        echo "The Store did not auto-connect $plug. Check the Store declaration before promoting this revision." >&2
        echo "$connections" >&2
        exit 1
    fi
done
sudo loginctl enable-linger "$(id -un)"
sudo systemctl start "user@$(id -u).service"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
systemctl --user start dbus.socket
systemd-run --user --wait --pipe --collect --quiet --working-directory="$PWD" \
    xvfb-run -a scripts/check-linux-window.sh /snap/bin/joomengine "$HOME/snap/joomengine/current/.local/share/JoomEngine/browser"
echo "revision=$revision" >> "${GITHUB_OUTPUT:?}"
