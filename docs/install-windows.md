# Install JoomEngine on Windows

Use a 64-bit Intel or AMD PC running Windows 10 22H2 (build 19045) or Windows 11. Both downloads run the hosted Playground through Microsoft Edge WebView2. If prompted for the runtime, install the **Evergreen Bootstrapper** from [Microsoft's WebView2 downloads](https://developer.microsoft.com/en-us/microsoft-edge/webview2/#download-section).

## Portable ZIP

1. Download the file ending in `-windows-x64.zip` and `SHA256SUMS` from the same [JoomEngine release](https://github.com/joomengine/joomengine/releases). [Check the SHA-256 hash](install-verify.md#windows).
2. Right-click the ZIP in File Explorer, choose **Extract All**, and select a folder in your user account where you want to keep the app.
3. Open the extracted folder and double-click **JoomEngine.exe**. You can create a shortcut to that file for the desktop. Internet access is needed to load Playground.

This option also works when the release's MSIX is unsigned. The portable ZIP is available beginning with builds for 0.2.0. If the stable release is still 0.1.0, select a [main-branch preview](https://github.com/joomengine/joomengine/releases?q=continuous-&expanded=true). It requires no Store account or package-signing certificate. Keep the files together. To update, close JoomEngine, verify the new ZIP and replace the extracted app files.

## MSIX installer

1. Download the file ending in `-windows-x64.msix` and verify it against the same release's `SHA256SUMS`.
2. Double-click the package to open **App Installer**. For a publisher-signed release, confirm the expected publisher and select **Install**.
3. Open **JoomEngine** from Start. To update, install a signed MSIX with the same package identity and a higher version. To try successive previews that share the same package version, use the portable ZIP.

Windows requires a publisher signature trusted by the computer for a normal MSIX installation. If the release includes an unsigned MSIX or App Installer reports an untrusted publisher, use the portable ZIP above. On a managed computer, application policies may apply to either download. [Microsoft's MSIX installation troubleshooting](https://learn.microsoft.com/windows/msix/app-installer/troubleshoot-appinstaller-issues)

Press **Ctrl+Shift+M** or right-click and choose **Show Menu Bar** to access File, Edit and View. **Ctrl+R** reloads the active window with the menu hidden or visible.

Before uninstalling or switching formats, use Playground's **Download** action to keep a copy of your site. You can restore it with **Upload**.
