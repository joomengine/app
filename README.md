# JoomEngine

JoomEngine opens [JoomEngine Playground](https://playground.joomengine.org/) in a dedicated desktop window for Joomla Component Builder. The C++ application embeds Qt WebEngine on Linux and macOS. On Windows it uses Win32 and Microsoft Edge WebView2.

Playground delivers Joomla, JCB, its editor, PHP and MariaDB to the embedded browser. The installer contains the desktop shell. On launch the site fetches the assets needed for the selected deployment. Playground handles HTTP requests to external repositories, extension packages and APIs through its normal browser networking. The desktop shell supplies native windows, file dialogs, downloads and navigation. Each platform's web engine handles HTTPS, service workers, and the origin policies used by the site.

## Reload and resume

**View → Reload** refreshes the current browser window. Use **Ctrl+R** on Windows and Linux or **Cmd+R** on macOS. JoomEngine uses persistent webview storage. Closing and reopening the app or refreshing the page reuses the same profile, so Playground can resume the last saved files and database. Its **Saved locally** indicator confirms when completed changes have reached storage. Playground’s **Download** and **Upload** actions can transfer a complete site between installations.

## Install

Tagged builds are distributed through [GitHub Releases](https://github.com/joomengine/app/releases). Pull request builds appear under [GitHub Actions](https://github.com/joomengine/app/actions/workflows/desktop.yml) after platform checks pass.

| Platform | Package | Browser engine |
| --- | --- | --- |
| Linux x86-64 | Archive with desktop installer, or strict Snap | The archive uses the distribution's Qt WebEngine. The Snap uses KDE's shared Qt runtime. See the [Linux installation instructions](packaging/linux/README.md). |
| Windows x64 | MSIX | Microsoft Edge WebView2 Evergreen Runtime. MSIX installation requires a trusted signature. |
| macOS Apple silicon and Intel | Native DMG for each architecture | The app bundle includes Qt WebEngine. Drag JoomEngine to Applications. |

## Build

Use CMake 3.24 or newer and a C++17 compiler. Linux and macOS require Qt 6.8 or newer with Widgets, Network and WebEngineWidgets. The Linux archive build uses Ubuntu 26.04. On macOS, install the Qt SDK and run its `qt-cmake` in place of `cmake` for the first command below. Windows uses Visual Studio's x64 C++ desktop tools and the Windows SDK. Its first configuration downloads checksum-pinned CHOC and WebView2 development files.

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
```

On Windows configure with `-A x64`. Run `build/joomengine` on Linux, `build/Release/JoomEngine.exe` on Windows, or `open build/JoomEngine.app` on macOS.

## Releases

Update `VERSION` and tag the corresponding commit with `vMAJOR.MINOR.PATCH`. The release workflow publishes the five tested installers, the corresponding Qt source for the Mac builds, and SHA-256 checksums. The Qt source archive is a separate developer download.

Windows publisher signing uses the repository variable `WINDOWS_PUBLISHER` and secrets `WINDOWS_PFX_BASE64` and `WINDOWS_PFX_PASSWORD`. macOS Developer ID signing uses `APPLE_CERTIFICATE_BASE64`, `APPLE_CERTIFICATE_PASSWORD` and `APPLE_SIGNING_IDENTITY`. Supply `APPLE_ID`, `APPLE_TEAM_ID` and `APPLE_APP_SPECIFIC_PASSWORD` for notarization. Development builds use ad hoc signing on macOS and a temporary test certificate for verification of unsigned MSIX packages on CI. To also publish the Snap to its registered listing, set `SNAP_STORE_PUBLISH` to `true` and supply `SNAPCRAFT_STORE_CREDENTIALS`.

## Credits and license

[GetBible Desktop](https://github.com/getbible/desktop) established the C++ native-webview approach and multi-platform release model used here. JoomEngine is independently implemented and dedicated to [JoomEngine Playground](https://github.com/joomengine/playground). Its desktop source is licensed under [Apache-2.0](LICENSE). The pearl rocket is JoomEngine project artwork. Third-party attributions are listed in [NOTICE](NOTICE).
