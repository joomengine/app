# JoomEngine for Linux

The x86-64 application uses GTK 3 and the operating system's WebKitGTK 4.1 runtime. The release workflow builds and tests on Ubuntu 24.04. Install its runtime dependencies with the following command.

```sh
sudo apt install libgtk-3-0t64 libwebkit2gtk-4.1-0
```

## Portable archive

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
snap run joomengine
```

The local-file flag permits installing the GitHub Release package outside the Snap Store. The Snap runs under strict confinement and uses the GNOME platform's WebKitGTK engine and helper processes. Its desktop profile persists across package revisions.
