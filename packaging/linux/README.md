# JoomEngine for Linux

JoomEngine uses Qt 6 WebEngine Widgets to run the hosted Playground. Both Linux packages target x86-64. The archive links against Ubuntu 26.04's Qt 6.10 libraries. The core24 Snap brings KDE's shared Qt runtime to Ubuntu 24.04 and other snapd systems.

## Native archive

Install the runtime packages on Ubuntu 26.04. They supply the shared libraries, Qt platform plugins and Chromium helper process.

```sh
sudo apt install libqt6webenginewidgets6 libqt6webenginecore6-bin qt6-qpa-plugins
```

Extract the archive and run `./joomengine`. Run `./install.sh` from the extracted directory to add an applications-menu entry for your account. The installer needs Python 3 and writes the executable to `~/.local/bin`. Close JoomEngine and run the installer from a newer archive to update.

These commands remove the installed files and retain saved workspaces.

```sh
share="${XDG_DATA_HOME:-$HOME/.local/share}"
rm -f "$HOME/.local/bin/joomengine" "$share/applications/org.joomengine.app.desktop" \
    "$share/icons/hicolor/512x512/apps/joomengine.png"
rm -rf "$share/joomengine/licenses"
```

## Snap

Install the release Snap from its download directory and open JoomEngine.

```sh
sudo snap install --dangerous ./joomengine_*_amd64.snap
sudo snap connect joomengine:kde-qt6-core24 kde-qt6-core24:kde-qt6-core24
sudo snap connect joomengine:browser-support
snap run joomengine
```

The local-file flag permits installing the GitHub Release package outside the Snap Store. The KDE content connection supplies Qt WebEngine and its Chromium helper. The browser-support connection allows the helper to set up its process sandbox inside strict Snap confinement. The desktop profile persists across package revisions. The Snap Store reviews browser-support requests that enable the browser's own sandbox.
