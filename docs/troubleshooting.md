# JoomEngine troubleshooting

## The Ubuntu Snap closes when I click Upload

If the terminal ends with `GLib-GIO-ERROR`, `No GSettings schemas are installed on the system` and `Trace/breakpoint trap`, the Snap's file chooser could not load its settings. This failure can happen before you select a ZIP. Keep your profile and your exported ZIP, then update the existing installation to a build containing the fix (0.2.1 or newer). [Snap update instructions](install-snap.md)

If Upload still fails, record the package version, whether you saw the file chooser, whether you selected a ZIP, its size and the first error after that action. For a failure after selection, also check free space on the drive holding your workspace and the storage estimate under **Backups**. The terminal excerpt and these details are sufficient for an initial report. [Gather a Linux report](#gather-a-linux-report)

## Where the desktop app keeps your workspace

The desktop browser profile contains Playground's saved sites and backups. For an ordinary update, quit JoomEngine and update the same package in place. Use **Download → Complete site** to take a copy you can restore independently of that profile.

| Installation | Usual profile location for the signed-in user |
| --- | --- |
| Windows portable ZIP | `%LOCALAPPDATA%\JoomEngine\WebView2`, including when the executable is run from a different folder |
| Windows MSIX | Windows resolves the same local app data path in the installed package's context. New files can be redirected into the package's private data under `%LOCALAPPDATA%\Packages`. |
| macOS DMG | `~/Library/Application Support/JoomEngine/browser` |
| Linux distribution packages, archive and AppImage | `$XDG_DATA_HOME/JoomEngine/browser`, usually `~/.local/share/JoomEngine/browser` |
| Flatpak | `~/.var/app/org.joomengine.app/data/JoomEngine/browser` |
| Snap | Under `~/snap/joomengine/`. The KDE runtime can use `current/.local/share/JoomEngine/browser` for the active revision. Snap carries revision data forward on refresh. |

An exported ZIP lives in the folder you used for the download. Leave the profile intact if you need to recover a workspace. [Qt data locations](https://doc.qt.io/qt-6/qstandardpaths.html) · [Windows package data](https://learn.microsoft.com/windows/msix/desktop/desktop-to-uwp-behind-the-scenes) · [Snap data locations](https://snapcraft.io/docs/reference/administration/data-locations/) · [Flatpak data locations](https://docs.flatpak.org/en/latest/sandbox-permissions.html#filesystem-access)

## A blank strip or a flickering page

First note whether the space is inside the Joomla page, at the bottom of the desktop window, or at the top where **File**, **Edit** and **View** appear. On Linux and Windows, **Ctrl+Shift+M** toggles that window's menu bar. In the Qt host the bottom status bar appears when the page fails to load or the browser process stops. If it shows a message, include its text in the report.

Try the same page and action in an ordinary browser at [JoomEngine Playground](https://playground.joomengine.org/). It has its own saved workspace. A reproduction in both environments helps identify which layout the maintainer should inspect. Note which section was open (JCB dashboard, code editor, Adminer or another Joomla view), whether the tool was detached, and whether you were scrolling, resizing or toggling a menu.

## Repeated messages in the Linux terminal

`ResizeObserver loop completed with undelivered notifications` means the web engine deferred some resize notifications to another rendering update. It can occur when page layout changes during a resize observation. Playground sizes the Joomla frame to the full document height to support scrolling the outer window. The editor and loaded Joomla extensions may also observe size changes. The message alone does not identify the responsible element. [Resize Observer specification](https://www.w3.org/TR/resize-observer/) · [Playground frame sizing](https://github.com/joomengine/playground/blob/main/src/frame-view.mjs)

`Attempt to read from an uninitialized SharedImage` is emitted by Chromium's graphics code when the compositor tries to read an image whose backing region has not been marked as initialized. The logged size is in image pixels and can exceed the visible window. A useful report says whether there was visible corruption, blank content, a crash, or only terminal output. These messages alone do not establish whether the two events share a cause. [Chromium's SharedImage read check](https://chromium.googlesource.com/chromium/src/+/5a6785d5aa40d7d332ef016f2007930cb448f91f/gpu/command_buffer/service/shared_image/shared_image_representation.cc)

## Gather a Linux report

1. Record the JoomEngine package format, version and release or preview tag. Note your distribution, screen resolution, display scaling, and whether the issue changes on another monitor. A screenshot of the whole desktop **window**, including the edges, can locate a blank strip. Remove private site content before sharing.
2. On the affected desktop, record the operating system and session.

   ```sh
   cat /etc/os-release
   uname -srmo
   printf 'Desktop session: %s\n' "$XDG_SESSION_TYPE"
   ```

   For Snap, also include the package and runtime revisions and the warning text.

   ```sh
   snap list joomengine kde-qt6-core24
   snap connections joomengine
   snap warnings
   ```

3. Fully quit JoomEngine so the new process captures its own log. For Snap, use the following command and reproduce the issue once. For a native distribution package, replace `snap run joomengine` with `joomengine`. Both commands preserve the usual renderer configuration.

   ```sh
   QT_LOGGING_RULES='qt.webenginecontext=true;qt.webengine.compositor=true' \
       snap run joomengine 2>&1 | tee joomengine-display.log
   ```

4. Include the Qt and Chromium graphics device/renderer lines, the first occurrence of the warning and the actions immediately preceding it. Review the excerpt for local paths, project names and private URLs. [Qt WebEngine graphics diagnostics](https://doc.qt.io/qt-6/qtwebengine-features.html#hardware-acceleration) · [Open a JoomEngine issue](https://github.com/joomengine/joomengine/issues)

## Snap installed with a warning

`joomengine 0.1.0 installed` confirms that installation succeeded. If snapd prints `WARNING: There is 1 new warning. See 'snap warnings'.`, run `snap warnings` to read the message. To check the installed revision, run `snap list joomengine`. For a startup problem, also collect [the Linux report](#gather-a-linux-report).

## Updating a Flatpak bundle

Quit JoomEngine. In the directory containing the new download, run `flatpak install --reinstall ./JoomEngine-*-x86_64.flatpak`. If you originally chose a per-user installation, add `--user`. Flatpak obtains the required runtime from the repository referenced by the bundle and may ask to add it. To configure Flathub for a distribution where it is unavailable, follow the [Flatpak setup guide](https://flatpak.org/setup/). [Flatpak single-file bundles](https://docs.flatpak.org/en/latest/single-file-bundles.html)

## AppImage portable use

On a desktop that permits Chromium user namespaces, make the downloaded AppImage executable and double-click it to run it without installing. If FUSE is unavailable, launch it with `--appimage-extract-and-run`. On Ubuntu with restricted user namespaces, use the [built-in installer](install-appimage.md). It copies the app to `/opt/joomengine/JoomEngine.AppImage`, creates the launcher, and loads an AppArmor profile scoped to that location. [AppImage FUSE troubleshooting](https://docs.appimage.org/user-guide/troubleshooting/fuse.html)

## Ubuntu archive runtime and removal

If the archive fails to launch because a Qt library or browser helper is missing, install its dependencies on Ubuntu 26.04.

```sh
sudo apt update
sudo apt install libqt6webenginewidgets6 libqt6webenginecore6-bin qt6-qpa-plugins python3
```

To remove the archive's launcher, executable, icon and license files while keeping your local Playground profile, run the following commands.

```sh
share="${XDG_DATA_HOME:-$HOME/.local/share}"
rm -f "$HOME/.local/bin/joomengine" "$share/applications/org.joomengine.app.desktop" \
    "$share/icons/hicolor/512x512/apps/joomengine.png"
rm -rf "$share/joomengine/licenses"
```

[All JoomEngine guides](README.md)
