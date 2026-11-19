# Publish JoomEngine to distribution channels

Every successful main build and version-tag build publishes its downloads to GitHub Releases. People can install them directly without a store account. To make stable updates available through a store or a package manager, set up the channel below and then push a new version tag. [Release procedure](releases.md) · [Manual installation](../README.md#download-and-install)

| Channel | Registration and deployment | What the release job does |
| --- | --- | --- |
| GitHub Releases | [Release procedure](releases.md) | Publishes all verified packages and SHA-256 checksums using the built-in Actions token. |
| Snap Store | [Register the snap, request interfaces and export a credential](publishing-linux.md#snap-store) | Uploads the tested Snap to the stable channel when enabled. |
| Debian APT and Fedora DNF | [Configure a signed Cloudsmith package repository](publishing-linux.md) | Uploads the same GitHub binaries into the configured APT and RPM repositories. Official distribution inclusion is a separate maintainer process. |
| Arch User Repository | [Register an AUR maintainer and package](publishing-linux.md) | Publishes the checked source recipe and generated package metadata to AUR. The binary package remains available on GitHub. |
| Flatpak and Flathub | [Distribute the bundle and request Flathub review](publishing-linux.md) | GitHub publishes the standalone bundle. Flathub has its own review, manifest requirements and build service. |
| AppImage and AppImageHub | [Direct download and directory submission](publishing-linux.md) | GitHub hosts the AppImage. A directory listing can point users to the release. |
| macOS | [Enroll, create a Developer ID certificate and configure notarization](publishing-apple.md) | Publishes signed, notarized Apple silicon and Intel DMGs when configured. The guide explains Qt WebEngine's Mac App Store limitation. |
| Windows and Microsoft Store | [Register in Partner Center and configure signing and submissions](publishing-microsoft.md) | Publishes the portable ZIP and MSIX on GitHub. Optionally submits an update to an existing Store listing for certification. |

## Where to enter settings

1. For channel flags and public Store identity metadata, open [Settings → Secrets and variables → Actions → Variables](https://github.com/joomengine/joomengine/settings/variables/actions) and choose **New repository variable**. Set the channel's flag to the literal `true` after completing its setup.
2. For Linux and Microsoft publisher credentials, open [Settings → Environments](https://github.com/joomengine/joomengine/settings/environments), create the environment named `distribution`, then open it. Use **Environment secrets** or **Environment variables** exactly as the channel guide specifies. Deployment branch and tag rules must permit your stable `v*` tags.
3. Direct-download Windows signing and Apple signing/notarization use the existing [repository Actions secrets](https://github.com/joomengine/joomengine/settings/secrets/actions). The platform guides explain where to obtain each value, its encoding and where it goes.

A skipped Snap Store job is expected on a PR or preview. On a stable tag it also requires a successful GitHub release and the repository variable `SNAP_STORE_PUBLISH=true`. The publisher reads `SNAPCRAFT_STORE_CREDENTIALS` from `distribution`. A GitHub Release download can be installed before the Store listing goes live. [Snap Store setup and commands](publishing-linux.md#snap-store)
