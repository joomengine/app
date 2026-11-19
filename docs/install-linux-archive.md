# Install the JoomEngine archive on Ubuntu 26.04

1. Download the file ending in `-linux-x64.tar.gz` from the [JoomEngine releases](https://github.com/joomengine/joomengine/releases).
2. On the first installation on Ubuntu 26.04, install the system runtime packages. APT will keep those already installed.

   ```sh
   sudo apt update && sudo apt install libqt6webenginewidgets6 libqt6webenginecore6-bin qt6-qpa-plugins python3
   ```

3. Extract the archive, open a terminal in the directory containing `install.sh` and run the installer.

   ```sh
   ./install.sh
   ```

4. Open **JoomEngine** from the applications menu or run `~/.local/bin/joomengine`.

This package uses Ubuntu 26.04's Qt WebEngine and Python 3. It installs in your user account. To update, quit the app and repeat the installation with the new archive.

[Runtime packages and removal](https://github.com/joomengine/joomengine/blob/main/docs/troubleshooting.md#ubuntu-archive-runtime-and-removal) · [Check the download](https://github.com/joomengine/joomengine/blob/main/docs/install-verify.md#linux) · [All installation guides](https://github.com/joomengine/joomengine/blob/main/docs/README.md)
