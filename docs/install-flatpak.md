# Install JoomEngine with Flatpak

1. Download the `.flatpak` file from the [JoomEngine releases](https://github.com/joomengine/joomengine/releases).
2. Double-click the file in your Flatpak-enabled software center and select **Install**. If you prefer the terminal, run this in the download folder.

   ```sh
   flatpak install --user ./JoomEngine-*-x86_64.flatpak
   ```

3. Open **JoomEngine** from the applications menu or run `flatpak run org.joomengine.app`.

The bundle can offer to download its shared runtime on first install. If your system needs Flatpak, use the [setup guide for your distribution](https://flatpak.org/setup/). You can also install the app from [Flathub](https://flathub.org/apps/search?q=JoomEngine) when the project listing is available.

[Check the download](install-verify.md#linux) · [Update a local bundle](troubleshooting.md#updating-a-flatpak-bundle) · [All installation guides](README.md)
