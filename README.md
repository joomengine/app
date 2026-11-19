# JoomEngine

JoomEngine opens [JoomEngine Playground](https://playground.joomengine.org/) in a dedicated desktop app. Build Joomla extensions with Joomla Component Builder, open tools such as Adminer in their own windows, and save the complete site to your computer.

## Download and install

Open the [latest stable release](https://github.com/joomengine/joomengine/releases/latest), expand **Assets**, and download the file for your computer plus `SHA256SUMS`. For newer features or a package format first added after that release, choose the newest [main-branch preview](https://github.com/joomengine/joomengine/releases?q=continuous-&expanded=true). Each successful main build has its own preview and checksums. The packages install directly from GitHub.

| Your computer | Choose this download | How to start |
| --- | --- | --- |
| Windows 10 22H2 or Windows 11, x64 | Windows ZIP, or a publisher-signed MSIX | Extract the ZIP and open **JoomEngine.exe**, or open the signed MSIX and select **Install**. [Windows guide](docs/install-windows.md) |
| macOS on Apple silicon or Intel | DMG ending in `arm64.dmg` for Apple silicon or `x64.dmg` for Intel | Open the DMG and drag **JoomEngine** into **Applications**. [macOS guide](docs/install-macos.md) |
| Debian 13, Arch Linux, or Fedora 44, x86-64 | Debian `.deb`, Arch `.pkg.tar.zst`, or Fedora `.rpm` | Install the downloaded file with APT, pacman, or DNF. [Linux guide](docs/install-linux.md#native-packages) |
| Other Linux desktops, x86-64 | Flatpak, AppImage, or Snap | Choose the format your system runs. Ubuntu 26.04 also has a native archive. [Linux guide](docs/install-linux.md) |

[Verify the download](docs/install-verify.md) before opening it. Under **Assets**, the Qt source and GitHub's source-code archives are for developers.

## Open your workspace

Connect to the internet on first launch. Playground fetches Joomla, JCB, PHP and MariaDB for the deployment you choose. The app supports downloads and requests to external repositories and APIs.

Wait for **Saved locally** before closing. Opening JoomEngine again resumes the saved workspace. **Ctrl+R** on Windows and Linux or **Cmd+R** on macOS reloads the active window. On Windows and Linux the app opens with its menu bar hidden. Press **Ctrl+Shift+M** or right-click and choose **Show Menu Bar** to reveal **File**, **Edit** and **View** for that window. macOS uses its system menu bar. To move your work to another computer or package format, use Playground's **Download** action to export a site and **Upload** to restore it.

## Project

[Troubleshooting](docs/troubleshooting.md) · [Build, test and contribute](docs/contributing.md) · [Release process](docs/releases.md) · [Set up store publishing](docs/publishing.md) · [Report a problem](https://github.com/joomengine/joomengine/issues)

JoomEngine is an independent application dedicated to [JoomEngine Playground](https://github.com/joomengine/playground). Its C++ desktop approach was inspired by [GetBible Desktop](https://github.com/getbible/desktop). The desktop source is licensed under [Apache-2.0](LICENSE). Artwork and third-party credits are in [NOTICE](NOTICE).
