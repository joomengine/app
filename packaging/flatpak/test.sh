#!/usr/bin/env bash
set -euo pipefail
work=${RUNNER_TEMP:?}/joomengine-flatpak
sudo loginctl enable-linger "$(id -un)"
sudo systemctl start "user@$(id -u).service"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
systemctl --user start dbus.socket
# Flatpak gives each app a private /tmp. Keep the QA exchange under the
# application's own persistent cache, visible from both sides of its sandbox.
qa_cache="$HOME/.var/app/org.joomengine.app/cache"
mkdir -p "$qa_cache"
cat > "$work/run-release" <<'SCRIPT'
#!/bin/sh
exec flatpak run --user org.joomengine.app//stable
SCRIPT
cat > "$work/run-qa" <<'SCRIPT'
#!/bin/sh
exec flatpak run --user org.joomengine.app//qa
SCRIPT
chmod +x "$work/run-release" "$work/run-qa"
# A headless runner has no desktop session that selects a file chooser backend.
# Give this test desktop its GTK backend and one display for both app launches.
portal_config="${XDG_CONFIG_HOME:-$HOME/.config}/xdg-desktop-portal/joomengine-qa-portals.conf"
mkdir -p "$(dirname "$portal_config")"
printf '[preferred]\ndefault=gtk\n' > "$portal_config"
trap 'rm -f "$portal_config"' EXIT
systemd-run --user --wait --pipe --collect --quiet --working-directory="$PWD" \
  --setenv="TMPDIR=$qa_cache" --setenv=XDG_CURRENT_DESKTOP=JoomEngine-QA --setenv=XDG_SESSION_TYPE=x11 \
  xvfb-run -a bash -euc '
    dbus-update-activation-environment --systemd DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
    systemctl --user restart xdg-desktop-portal-gtk.service
    systemctl --user restart xdg-desktop-portal.service
    for interface in Settings FileChooser; do
      if ! busctl --user get-property org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop \
          "org.freedesktop.portal.$interface" version; then
        journalctl --user --no-pager -b -u xdg-desktop-portal -u xdg-desktop-portal-gtk -n 80
        exit 1
      fi
    done
    scripts/check-linux-window.sh "$1/run-release" "$HOME/.var/app/org.joomengine.app/data/JoomEngine/browser"
    flatpak kill org.joomengine.app 2>/dev/null || true
    if python3 test/native_smoke.py --native-file-chooser "$1/run-qa"; then
      exit 0
    fi
    journalctl --user --no-pager -b -u xdg-desktop-portal -u xdg-desktop-portal-gtk -n 80
    exit 1
  ' _ "$work"
