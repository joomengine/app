# Use JoomEngine

Open **JoomEngine** from your desktop while connected to the internet. Playground downloads Joomla, Joomla Component Builder, PHP and MariaDB for the deployment you choose. It can fetch extensions and call external repositories and APIs. Tools such as Adminer can open in their own windows.

## Keep your workspace

Wait for Playground's **Saved locally** indicator before quitting. Open JoomEngine again to resume the saved files and database. **Ctrl+R** on Windows and Linux or **Cmd+R** on macOS reloads the active window.

## Download and restore a complete site

1. In the main Playground window, choose **Download**, select **Complete site** and click **Download**. Keep the ZIP in your Downloads folder or another folder you choose. It contains the Joomla files and database and can contain site credentials.
2. To restore, open **Upload** in the destination's main Playground window and select the ZIP itself. If Playground asks about replacing an existing site, you can back it up or download it first.
3. When the restored site opens, check a familiar page or database record and wait for **Saved locally**. The next time you open the app, it resumes from the saved workspace.

Choose **Backups → Back up current site** to keep an additional copy inside this installation. The **Backups** panel shows disk usage and the browser's estimated storage quota. A displayed allowance of 10 GiB is an estimate, and writes also require free space on the drive holding your profile. The hosted Playground currently accepts complete site ZIPs up to 512 MiB compressed and 768 MiB expanded per import. [Playground import limits](https://github.com/joomengine/playground/blob/main/src/site-import.mjs)

Keep a complete ZIP outside the app before switching package formats, moving to another computer or removing application data. [Find your saved workspace](troubleshooting.md#where-the-desktop-app-keeps-your-workspace)

## Show the desktop menu

On Windows and Linux, press **Ctrl+Shift+M** or right-click and choose **Show Menu Bar** to show or hide **File**, **Edit** and **View** for the active window. macOS uses its system menu bar.

[Installation guides](README.md) · [Troubleshooting](troubleshooting.md)
