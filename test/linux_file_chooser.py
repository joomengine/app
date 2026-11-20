"""Drive the production upload dialog on the native smoke test's private Xvfb display."""

import re
import subprocess
import time


def xdotool(*args):
    return subprocess.check_output(['xdotool', *args], text=True, timeout=10).strip()


def visible_windows():
    # Qt may pass an empty caption to the GTK portal. Match empty titles too.
    result = subprocess.run(['xdotool', 'search', '--onlyvisible', '--name', '.*'],
                            capture_output=True, text=True, timeout=10)
    if result.returncode and (result.returncode != 1 or result.stderr):
        raise RuntimeError(f'Cannot enumerate the test display: {result.stderr.strip()}')
    return set(result.stdout.splitlines())


def select_archive(bundle, process):
    """Find the mapped Qt or portal file chooser after the native Upload keypress."""
    if not bundle.is_file():
        raise FileNotFoundError(bundle)
    owners = xdotool('search', '--onlyvisible', '--name', '^JoomEngine$').splitlines()
    if len(owners) != 1:
        raise RuntimeError(f'Expected one JoomEngine owner window, found {len(owners)}.')
    owner = owners[0]
    deadline = time.monotonic() + 45
    observed = set()
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError(f'JoomEngine exited with status {process.returncode} while opening Upload.')
        # The native keypress can map the chooser before Python reads the log.
        for window in visible_windows() - {owner}:
            result = subprocess.run(['xprop', '-id', window, 'WM_TRANSIENT_FOR', '_NET_WM_WINDOW_TYPE',
                                     'WM_CLASS', 'WM_WINDOW_ROLE'], capture_output=True, text=True, timeout=10)
            if result.returncode:
                continue  # The window went away between enumeration and inspection.
            props = result.stdout
            facts = [line[:180] for line in props.splitlines() if ' = ' in line or '# 0x' in line]
            if facts:
                observed.add(', '.join(facts))
            transient = re.search(r'WM_TRANSIENT_FOR.*# (0x[\da-f]+)', props, re.I)
            # GTK's portal creates a hidden intermediary parent. A portal-owned
            # toplevel can also carry NORMAL rather than DIALOG on a bare display.
            gtk_portal = any('xdg-desktop-portal-gtk' in line.lower() for line in facts if line.startswith('WM_CLASS('))
            if ((transient and int(transient[1], 16) == int(owner))
                    or '_NET_WM_WINDOW_TYPE_DIALOG' in props
                    or (gtk_portal and (transient or '_NET_WM_WINDOW_TYPE_NORMAL' in props))):
                print('Found the native Upload dialog', ', '.join(facts), flush=True)
                xdotool('windowfocus', '--sync', window)
                xdotool('key', '--clearmodifiers', 'ctrl+l')
                xdotool('type', '--clearmodifiers', '--', str(bundle))
                xdotool('key', '--clearmodifiers', 'Return')
                print('Submitted the exported site ZIP through the native Upload dialog.', flush=True)
                return
        time.sleep(0.2)
    # Titles may contain paths. Only report window relationships, classes and roles.
    raise TimeoutError('Upload did not open an identifiable file chooser on the test display within 45 seconds. '
                       f'Observed window properties: {sorted(observed)}')
