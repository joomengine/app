"""Drive the production upload dialog on the native smoke test's private Xvfb display."""

import re
import subprocess
import time


def xdotool(*args):
    return subprocess.check_output(['xdotool', *args], text=True, timeout=10).strip()


def visible_windows():
    # With no matching windows xdotool search returns 1 and empty stdout.
    result = subprocess.run(['xdotool', 'search', '--onlyvisible', '--name', '.'],
                            capture_output=True, text=True, timeout=10)
    if result.returncode and (result.returncode != 1 or result.stderr):
        raise RuntimeError(f'Cannot enumerate the test display: {result.stderr.strip()}')
    return set(result.stdout.splitlines())


def select_archive(bundle, process):
    """JS has focused Upload. A real keypress must open a native or portal picker."""
    if not bundle.is_file():
        raise FileNotFoundError(bundle)
    owners = xdotool('search', '--onlyvisible', '--name', '^JoomEngine$').splitlines()
    if len(owners) != 1:
        raise RuntimeError(f'Expected one JoomEngine owner window, found {len(owners)}.')
    owner = owners[0]
    previous = visible_windows()
    xdotool('windowfocus', '--sync', owner)
    xdotool('key', '--clearmodifiers', 'space')
    deadline = time.monotonic() + 45
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError(f'JoomEngine exited with status {process.returncode} while opening Upload.')
        for window in visible_windows() - previous:
            # A desktop portal can host the dialog in its own process. Use X11
            # properties instead of Qt class names, process IDs or translated titles.
            result = subprocess.run(['xprop', '-id', window, 'WM_TRANSIENT_FOR', '_NET_WM_WINDOW_TYPE'],
                                    capture_output=True, text=True, timeout=10)
            parent = re.search(r'WM_TRANSIENT_FOR.*# (0x[\da-f]+)', result.stdout, re.I)
            if ((parent and int(parent[1], 16) == int(owner))
                    or '_NET_WM_WINDOW_TYPE_DIALOG' in result.stdout):
                xdotool('windowfocus', '--sync', window)
                xdotool('key', '--clearmodifiers', 'ctrl+l')
                xdotool('type', '--clearmodifiers', '--', str(bundle))
                xdotool('key', '--clearmodifiers', 'Return')
                print('Selected the exported site ZIP through the native Upload dialog.', flush=True)
                return
        time.sleep(0.2)
    raise TimeoutError('Upload did not open a native file chooser on the test display within 45 seconds.')
