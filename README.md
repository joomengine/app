# JoomEngine

JoomEngine is a desktop development workspace for [JoomEngine Playground](https://playground.joomengine.org/). Launch Joomla Component Builder, edit a running site in JoomEngine Code, inspect its MariaDB database, and export your work from one app. The default site and available Joomla, PHP, and JCB versions come from Playground's current deployment.

The app opens Playground directly in a dedicated Chromium window. PHP and MariaDB run in Playground's browser workers. The desktop keeps its own persistent profile, lets the Code and database tools open detached windows, and uses the operating system's file dialogs for uploads and downloads. Opening the hosted workspace and fetching uncached assets requires a connection. See the [Playground guide](https://github.com/joomengine/playground#readme) for site persistence, backup and restoration.

## Install a desktop build

The [Releases page](https://github.com/joomengine/app/releases) hosts tagged builds. Pull request builds are available as artifacts on their [workflow run](https://github.com/joomengine/app/actions/workflows/desktop.yml) after the platform tests pass.

| System | File | Installation |
| --- | --- | --- |
| Linux x86-64 | `.tar.gz` | Extract the archive. Run its `install.sh` with sudo for an application-menu entry and Ubuntu sandbox integration. See the [Linux instructions](packaging/linux/README.md) for portable use and updates. |
| Linux x86-64 with snapd | `.snap` | Install the downloaded Snap and connect its browser sandbox as described in the [Linux instructions](packaging/linux/README.md#snap). |
| Windows x64 | `.msix` | Open a signed package in App Installer. An MSIX from a build without a publisher certificate needs signing with a certificate trusted by the machine before installation. |
| macOS Apple silicon or Intel | `.dmg` | Open the disk image for your processor and drag JoomEngine to Applications. Builds without Developer ID credentials use an ad hoc signature. Developer ID signing and notarization support normal Gatekeeper distribution. |

A site belongs to the profile of the installed app. Use Playground’s **Download → complete site** and **Upload** controls to move a project between installations or make a portable backup.

## Run from source

Install Node.js 24 and npm, then run these commands from this repository on your desktop.

```sh
npm ci
npm run stage
npm start
```

Staging downloads the pinned Electron release for the current OS and architecture. Run `npm run stage` again after changing the desktop source to refresh the staged app.

## Verify the desktop runtime

`npm test` checks navigation and permission decisions. The installed-app tests launch the actual binary with a disposable profile. The local HTTPS fixture exercises the service worker, shared WebAssembly memory, a detached window and its opener, exported file bytes, and browser storage across a restart. The live test launches the hosted JCB dashboard, writes and reopens a MariaDB row, detaches Adminer and downloads a complete site ZIP.

For example, after installing the Linux archive, run these commands in a desktop session:

```sh
node test/smoke.cjs /usr/local/bin/joomengine
node test/smoke.cjs /usr/local/bin/joomengine --live
```

The fixture test uses OpenSSL to create a temporary loopback certificate. The live test uses the real Playground origin and its normal TLS settings. Both leave the user's regular desktop profile alone.

## Releases

Set the numeric version in `package.json` and update the lockfile. A matching `vMAJOR.MINOR.PATCH` tag builds the packages, runs the installed-app tests and publishes the artifacts with SHA-256 checksums. Each installed package also runs the live JCB check. Pin updates to Electron in `config.electronVersion` so candidate runtimes go through the same tests.

For signed Windows releases, set the repository variable `WINDOWS_PUBLISHER` to the certificate subject, and set the secrets `WINDOWS_PFX_BASE64` and `WINDOWS_PFX_PASSWORD`. For signed macOS releases, set `APPLE_CERTIFICATE_BASE64`, `APPLE_CERTIFICATE_PASSWORD` and `APPLE_SIGNING_IDENTITY`. Add `APPLE_ID`, `APPLE_TEAM_ID` and `APPLE_APP_SPECIFIC_PASSWORD` for notarization. These signing credentials are used only for version tags. To also publish the tested Snap to a registered Snap Store listing, set `SNAP_STORE_PUBLISH` to `true` and supply `SNAPCRAFT_STORE_CREDENTIALS`. Store auto-connection of the browser sandbox requires approval for that interface.

## Credits and license

The [GetBible desktop app](https://github.com/getbible/desktop) inspired the focused desktop window and the multi-platform release approach. JoomEngine is an independent implementation built exclusively for [JoomEngine Playground](https://github.com/joomengine/playground). Its desktop source is licensed under [Apache-2.0](LICENSE). The Playground project supplied the pearl rocket artwork. Electron and Chromium retain their own distribution notices.
