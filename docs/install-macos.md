# Install JoomEngine on macOS

The DMGs target macOS 13 Ventura and later. [Qt for macOS](https://doc.qt.io/qt-6.11/macos.html)

1. Open **Apple menu → About This Mac**. If the window lists an Apple **Chip** (such as M1, M2 or later), choose the DMG ending in `-macos-arm64.dmg`. If it lists an Intel **Processor**, choose `-macos-x64.dmg`.
2. In the [JoomEngine release assets](https://github.com/joomengine/joomengine/releases), download that DMG and `SHA256SUMS`. [Verify the DMG](install-verify.md#macos).
3. Double-click the DMG, drag **JoomEngine** to **Applications**, then eject the installer volume. Open **JoomEngine** from Applications while connected to the internet. The DMG includes the Qt browser runtime.

A release signed with Developer ID and notarized by Apple uses the normal macOS first-open confirmation. A build made without the publisher’s signing credentials uses an ad hoc signature, including when it comes from a version tag. If macOS reports that it cannot verify the developer of a copy you intentionally downloaded and verified, first try opening the app, then use **System Settings → Privacy & Security → Open Anyway** for JoomEngine. Your administrator may restrict this option. Apple's guidance distinguishes that message from an alert about malware or a damaged application. [Apple's guide to opening downloaded apps](https://support.apple.com/en-us/102445)

To update, quit JoomEngine and replace the copy in Applications with the one from the newer, verified DMG. Use Playground's **Download** action to make a portable backup before moving to another Mac.

[All JoomEngine guides](README.md)
