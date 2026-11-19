# Install JoomEngine on Fedora

1. On Fedora 44 x86-64, download the file ending in `.fc44.x86_64.rpm` from the [JoomEngine releases](https://github.com/joomengine/joomengine/releases).
2. In the download folder, install the package. DNF will fetch its dependencies.

   ```sh
   sudo dnf install ./joomengine-*.fc44.x86_64.rpm
   ```

3. Open **JoomEngine** from the applications menu or run `joomengine`.

To update, close the app and repeat the command with the new package.

[Check the download](install-verify.md#linux) · [All installation guides](README.md)
