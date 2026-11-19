#!/usr/bin/env bash
# Install or update the native desktop app for this account.
set -euo pipefail
cd -- "$(dirname -- "$0")"
bin="$HOME/.local/bin"
share="${XDG_DATA_HOME:-$HOME/.local/share}"
install -d "$bin" "$share/applications" "$share/icons/hicolor/512x512/apps" "$share/joomengine/licenses/LICENSES"
# Atomically switch binaries so a failed copy leaves the current release usable.
candidate=$(mktemp "$bin/.joomengine.XXXXXXXX")
trap 'rm -f -- "$candidate"' EXIT
install -m 0755 joomengine "$candidate"
install -m 0644 joomengine.png "$share/icons/hicolor/512x512/apps/joomengine.png"
install -m 0644 LICENSE NOTICE "$share/joomengine/licenses/"
install -m 0644 LICENSES/* "$share/joomengine/licenses/LICENSES/"
mv -fT -- "$candidate" "$bin/joomengine"
# A graphical login may not include ~/.local/bin in PATH. Quote the executable
# according to the desktop-entry Exec grammar, including reserved percent signs.
python3 - "$bin/joomengine" "$share/applications/org.joomengine.app.desktop" <<'PY'
from pathlib import Path
import os
import sys
import tempfile
executable, destination = sys.argv[1:]
arg = ''.join(('\\' + c if c in '\\"$`' else '%%' if c == '%' else c) for c in executable)
arg = arg.replace('\\', '\\\\')
text = Path('joomengine.desktop').read_text().replace('Exec=joomengine\n', f'Exec="{arg}"\n')
with tempfile.NamedTemporaryFile(mode='w', dir=Path(destination).parent, delete=False) as f:
    f.write(text)
os.chmod(f.name, 0o644)
os.replace(f.name, destination)
PY
echo "Installed JoomEngine in $bin. Open it from the applications menu."
