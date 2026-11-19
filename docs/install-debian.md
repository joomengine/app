# Install JoomEngine on Debian

1. On Debian 13 (Trixie), download the file ending in `_amd64.deb` from the [JoomEngine releases](https://github.com/joomengine/joomengine/releases).
2. In the download folder, install the package. APT will fetch its dependencies.

   ```sh
   sudo apt install ./joomengine_*_amd64.deb
   ```

3. Open **JoomEngine** from the applications menu or run `joomengine`.

To update, close the app and run the same command with the new package. If APT needs refreshed package lists, run `sudo apt update`.

[Check the download](install-verify.md#linux) · [All installation guides](README.md)
