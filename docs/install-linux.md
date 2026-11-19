# Install JoomEngine on Linux

The Linux downloads target Intel and AMD 64-bit desktops. `uname -m` reports `x86_64` on these machines. Download one package and `SHA256SUMS` from the same [GitHub release](https://github.com/joomengine/joomengine/releases) into an empty directory. The expanded package set first appears in builds for 0.2.0. While the stable release is still 0.1.0, use a [main-branch preview](https://github.com/joomengine/joomengine/releases?q=continuous-&expanded=true) for the new formats. [Verify the package](install-verify.md#linux), then open a terminal there. The commands below assume one downloaded version. In JoomEngine, **Ctrl+Shift+M** shows or hides the desktop menu bar, and **Ctrl+R** reloads the active window.

## Native packages

Your package manager installs the matching Qt WebEngine and other dependencies from your configured distribution repositories. Choose the build for your distribution.

| Package | Installation | Run |
| --- | --- | --- |
| Debian 13 (Trixie), amd64 | `sudo apt update` then `sudo apt install ./joomengine_*_amd64.deb` | Open **JoomEngine** in the app menu or run `joomengine`. |
| Arch Linux, x86-64 | On an up-to-date system, run `sudo pacman -U ./joomengine-*-x86_64.pkg.tar.zst`. Arch users can bring the whole system up to date with `sudo pacman -Syu`. | Open **JoomEngine** or run `joomengine`. |
| Fedora 44, x86-64 | Download the RPM whose filename includes `.fc44`. Run `sudo dnf install ./joomengine-*.x86_64.rpm`. | Open **JoomEngine** or run `joomengine`. |

To install a newer version from GitHub, close JoomEngine and repeat the package command with the new download. Distribution derivatives must supply compatible Qt and other shared libraries. If your package manager reports an unsatisfied dependency, use the Flatpak or Snap route below.

## Flatpak

Use this on desktops with Flatpak installed. The first installation can download the shared KDE runtime. For distribution-specific Flatpak setup, see the [Flatpak setup guide](https://flatpak.org/setup/).

```sh
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user --bundle ./JoomEngine-*-x86_64.flatpak
flatpak run org.joomengine.app
```

You can also launch **JoomEngine** from the app menu. To replace a previously installed GitHub bundle, use `flatpak install --user --reinstall --bundle ./JoomEngine-*-x86_64.flatpak` in the new download directory. `flatpak update --user` updates your runtimes. [Flatpak single-file bundles](https://docs.flatpak.org/en/latest/single-file-bundles.html)

## AppImage

Run these commands from the folder containing the verified AppImage, then open **JoomEngine** from your applications menu.

```sh
chmod +x ./JoomEngine-*-x86_64.AppImage
./JoomEngine-*-x86_64.AppImage --appimage-extract-and-run --install
```

The installer requests administrator access to copy the app to `/opt/joomengine/JoomEngine.AppImage` and add its icon and launcher. On Ubuntu systems that restrict unprivileged user namespaces, it also installs the app-specific AppArmor profile Chromium needs to run its sandbox. The application itself runs as your regular user. To update, quit the app and repeat the same commands with the new download.

For portable use on a system that permits Chromium user namespaces, make the file executable and double-click it, or run `./JoomEngine-*-x86_64.AppImage`. If FUSE is unavailable, run it with `--appimage-extract-and-run`. [AppImage FUSE troubleshooting](https://docs.appimage.org/user-guide/troubleshooting/fuse.html)

## Snap

With [snapd installed](https://snapcraft.io/docs/installing-snapd), download the single file **joomengine-install-snap.sh** from the [GitHub release](https://github.com/joomengine/joomengine/releases). It contains the complete JoomEngine Snap. Run it as your ordinary user from your download directory:

```sh
bash ./joomengine-install-snap.sh
```

Enter your administrator password if prompted. The installer checks the embedded package's SHA-256, obtains the shared Qt and graphics runtimes from the Snap Store, and configures the required interfaces. Open **JoomEngine** from the applications menu or run `snap run joomengine`. To update a GitHub installation, quit JoomEngine and run the newer self-contained installer. Existing saved work stays in the same Snap profile.

The helper ships with version 0.2.0 and newer and can upgrade an existing 0.1.0 installation. GitHub also provides the raw `.snap` for system administrators and `SHA256SUMS` for anyone who wants to [independently verify the downloaded installer](install-verify.md#linux).

**Snap Store.** Once the approved stable listing is public, choose **Install** on the [JoomEngine Snap Store page](https://snapcraft.io/joomengine) or run `sudo snap install joomengine`. The Store installation configures the connections and updates automatically. [Store setup and availability](publishing-linux.md#snap-store)

### An installation succeeded and snapd reports a warning

`joomengine 0.1.0 installed` confirms installation. The line `WARNING: There is 1 new warning. See 'snap warnings'.` reports that snapd has a pending message. Read its full text to identify the cause. You can also check the installed revision and the connections used by JoomEngine.

```sh
snap warnings
snap list joomengine
snap connections joomengine
```

If you report a startup problem, include the warning text, the connections, your distribution and the terminal output of `snap run joomengine`. [Desktop troubleshooting](troubleshooting.md) · [JoomEngine issues](https://github.com/joomengine/joomengine/issues)

## Ubuntu 26.04 native archive

Use the `-linux-x64.tar.gz` build if you want to install the executable in your home directory on Ubuntu 26.04. It uses Ubuntu's Qt WebEngine packages. [Archive installation and removal](install-linux-archive.md)

## Saved work

Wait for Playground's **Saved locally** indicator before closing. Profiles for different packaging systems can live in different directories. To switch formats, use Playground's **Download** action in the current app, then **Upload** in the new installation. Keep this site export before removing a package or its user data.
