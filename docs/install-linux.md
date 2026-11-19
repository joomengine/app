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

Keep the downloaded AppImage in a directory where you can run executables, then make it executable and start it as your own user.

```sh
chmod +x ./JoomEngine-*-x86_64.AppImage
./JoomEngine-*-x86_64.AppImage
```

If the launcher reports a FUSE error, follow the [AppImage FUSE instructions for your distribution](https://docs.appimage.org/user-guide/troubleshooting/fuse.html). Where FUSE is unavailable, run the file with `--appimage-extract-and-run`. To update, quit the app and replace the file with a newly verified AppImage.

### Ubuntu AppArmor and the Chromium sandbox

If the AppImage reports a sandbox or user-namespace startup error on Ubuntu with restricted unprivileged user namespaces, install the verified file in the fixed location covered by its bundled AppArmor profile. The following commands run the app as your regular user. Only the system-wide file and profile installation need administrator access.

```sh
sudo install -D -m 0755 ./JoomEngine-*-x86_64.AppImage /opt/joomengine/JoomEngine.AppImage
profile_path=usr/share/doc/joomengine/AppImage/joomengine.apparmor
work=$(mktemp -d)
(
    cd "$work" &&
    /opt/joomengine/JoomEngine.AppImage --appimage-extract "$profile_path" &&
    sudo install -m 0644 "squashfs-root/$profile_path" /etc/apparmor.d/joomengine-appimage &&
    sudo apparmor_parser --replace /etc/apparmor.d/joomengine-appimage
) && /opt/joomengine/JoomEngine.AppImage
```

This profile allows the app at that root-owned path to create its Chromium sandbox. To update, replace the file at the same path. If you want a per-user installation on this system, the Flatpak option is available above.

## Snap

Use this on a distribution with [snapd installed](https://snapcraft.io/docs/installing-snapd). Install the verified local Snap and connect its runtime and interfaces.

```sh
sudo snap install kde-qt6-core24
sudo snap install --dangerous ./joomengine_*_amd64.snap
sudo snap connect joomengine:kde-qt6-core24 kde-qt6-core24:kde-qt6-core24
sudo snap connect joomengine:browser-support
sudo snap connect joomengine:hardware-observe
snap run joomengine
```

The local file from GitHub has no Snap Store assertion, which is why the install command uses `--dangerous`. The app still runs under strict confinement. KDE supplies the shared Qt runtime, `browser-support` enables Chromium's own process sandbox, and `hardware-observe` allows Qt to identify graphics devices. When installing a newer file from GitHub, use `sudo snap install --dangerous ./joomengine_*_amd64.snap` from the new download directory. [Installing local snaps](https://forum.snapcraft.io/t/download-snaps-and-install-offline/15713)

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
