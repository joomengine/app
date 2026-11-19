#!/usr/bin/env bash
# Verify the user-facing binary opens a visible native window on an X11 display.
set -euo pipefail
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
  if xdotool search --onlyvisible --name 'JoomEngine' >/dev/null; then
    echo "The installed JoomEngine application opened its native desktop window."
    exit 0
  fi
  sleep 1
done
echo "The installed JoomEngine window did not appear." >&2
exit 1
