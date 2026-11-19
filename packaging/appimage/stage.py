#!/usr/bin/env python3
"""Deploy the Widgets host, its Qt WebEngine renderer, and native desktop plugins."""
from pathlib import Path
import re
import shutil
import subprocess
import sys

sdk, appdir = (Path(arg).resolve() for arg in sys.argv[1:])
usr = appdir / "usr"
package = Path(__file__).resolve().parent
notices = usr / "share/doc/joomengine/AppImage"
notices.mkdir(parents=True)
shutil.copy2(package / "AppRun", appdir)
shutil.copy2(package / "joomengine.apparmor", notices)
for name in ("ICU-LICENSE.txt", "Type2-runtime-LICENSE.txt"):
    shutil.copy2(package / name, notices)
# Qt Installer Framework kits are relocatable, including Chromium's helper.
for folder in ("resources", "translations/qtwebengine_locales"):
    shutil.copytree(sdk / folder, usr / folder)
for name in ("qtbase_*.qm", "qtwebengine_*.qm"):
    for translation in (sdk / "translations").glob(name):
        shutil.copy2(translation, usr / "translations")
helper = usr / "libexec/QtWebEngineProcess"
helper.parent.mkdir()
shutil.copy2(package / "install.sh", helper.parent / "install-appimage")
shutil.copy2(sdk / "libexec/QtWebEngineProcess", helper)
(usr / "bin/qt.conf").write_text("[Paths]\nPrefix=..\n")
pending = [usr / "bin/joomengine", helper]
# Deploy the X11 and Wayland backends, OpenSSL, input methods and portal dialogs.
plugins = ("platforms/libqxcb.so", "platforms/libqwayland.so", "platformthemes/libqxdgdesktopportal.so",
           "xcbglintegrations/*.so", "wayland-*-client/*.so", "wayland-shell-integration/*.so",
           "platforminputcontexts/*.so", "tls/*.so", "imageformats/*.so", "iconengines/*.so")
for pattern in plugins:
    matches = list((sdk / "plugins").glob(pattern))
    if not matches:
        raise RuntimeError(f"Missing native Qt plugin group {pattern}")
    for path in matches:
        dest = usr / path.relative_to(sdk)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dest)
        pending.append(dest)

# Keep Qt and ICU in the bundle, including libraries required only by a plugin.
# XCB utility libraries are frequently absent on a Wayland-first desktop.
# Leave the system's libc, GL drivers, fonts, NSS and display servers on the host.
libraries = usr / "lib"
libraries.mkdir()
ldconfig = subprocess.check_output(["ldconfig", "-p"], text=True)
system = dict(re.findall(r"^\s*(\S+) \(libc6,x86-64\) => (\S+)$", ldconfig, re.M))
packages = set()
while pending:
    binary = pending.pop()
    dynamic = subprocess.check_output(["readelf", "-d", binary], text=True)
    for name in re.findall(r"\(NEEDED\).*?\[([^]]+)\]", dynamic):
        target = libraries / name
        if target.exists():
            continue
        if name.startswith(("libQt6", "libicu")):
            origin = sdk / "lib" / name
        elif name.startswith(("libxcb-", "libxkbcommon-x11.")):
            origin = Path(system[name]).resolve()
            owner = subprocess.check_output(["dpkg-query", "-S", "*/" + origin.name], text=True)
            packages.add(owner.split(":")[0])
        else:
            continue
        shutil.copy2(origin, target)
        pending.append(target)
for name in sorted(packages):
    dest = notices / name
    dest.mkdir()
    shutil.copy2(Path("/usr/share/doc") / name / "copyright", dest)
