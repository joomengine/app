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
# Run both launches in a real user session so Qt WebEngine's Flatpak subprocess
# portal can create its sandboxed Chromium renderers.
systemd-run --user --wait --pipe --collect --quiet --working-directory="$PWD" \
  xvfb-run -a scripts/check-linux-window.sh "$work/run-release"
flatpak kill org.joomengine.app 2>/dev/null || true
systemd-run --user --wait --pipe --collect --quiet --working-directory="$PWD" \
  --setenv="TMPDIR=$qa_cache" xvfb-run -a python3 test/native_smoke.py "$work/run-qa"
