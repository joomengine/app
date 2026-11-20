#!/usr/bin/env bash
# Verify the user-facing binary opens a visible native window on an X11 display.
set -euo pipefail
profile=${2:-"${XDG_DATA_HOME:-$HOME/.local/share}/JoomEngine/browser"}
"$1" &
child=$!
trap 'kill "$child" 2>/dev/null || true; wait "$child" 2>/dev/null || true' EXIT
for ((seconds = 0; seconds < 60; seconds++)); do
  if ! kill -0 "$child" 2>/dev/null; then
    status=0
    wait "$child" || status=$?
    trap - EXIT
    echo "JoomEngine exited before its window appeared (process status $status)." >&2
    if (( status == 0 )); then exit 1; fi
    exit "$status"
  fi
  if xdotool search --onlyvisible --name '^JoomEngine$' >/dev/null &&
     [[ -d "$profile" && -n "$(find "$profile" -type f -size +0c -print -quit)" ]]; then
    echo "The installed app opened its window and wrote its browser profile under $profile."
    exit 0
  fi
  sleep 1
done
echo "Timed out waiting for the installed JoomEngine window and its browser data under $profile." >&2
exit 1
