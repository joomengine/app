# JoomEngine archive for Ubuntu 26.04

This x86-64 build runs against Ubuntu 26.04's system Qt WebEngine. Download the file ending in `-linux-x64.tar.gz` and `SHA256SUMS` from the same [JoomEngine release](https://github.com/joomengine/joomengine/releases). [Verify the package](https://github.com/joomengine/joomengine/blob/main/docs/install-verify.md#linux).

Install the runtime and installer dependencies, extract the archive and install the desktop launcher for your user account.

```sh
sudo apt update
sudo apt install libqt6webenginewidgets6 libqt6webenginecore6-bin qt6-qpa-plugins python3
tar -xzf JoomEngine-*-linux-x64.tar.gz
cd JoomEngine-*-linux-x64
./install.sh
```

Launch **JoomEngine** from your application menu or run `~/.local/bin/joomengine`. You can also run `./joomengine` directly from the extracted directory. Connect to the internet to load Playground.

To update, close JoomEngine and repeat these steps with the new archive. To remove the launcher, executable, icon and license files while keeping your local Playground profile, run the following.

```sh
share="${XDG_DATA_HOME:-$HOME/.local/share}"
rm -f "$HOME/.local/bin/joomengine" "$share/applications/org.joomengine.app.desktop" \
    "$share/icons/hicolor/512x512/apps/joomengine.png"
rm -rf "$share/joomengine/licenses"
```
