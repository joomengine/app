# Publish JoomEngine

GitHub Releases is the project's download page. Each successful main build publishes a preview. Each successful version-tag build publishes the verified installers and their SHA-256 checksums. This includes the Debian, Fedora, Arch, Flatpak, Snap, AppImage and Linux archive downloads. [Create a release](releases.md) · [Install JoomEngine](README.md#install-on-your-computer)

## Official Linux archives and Flathub

| Destination | How a stable version gets there |
| --- | --- |
| [Debian archive](publishing-linux.md#debian-archive) | A Debian maintainer prepares a source package for unstable and arranges a sponsored upload if needed. Debian reviews new packages for archive admission. |
| [Fedora Linux](publishing-linux.md#fedora-linux) | Submit the spec and source RPM for Fedora package review. After approval, the Fedora maintainer builds it in Koji and submits updates for supported Fedora releases. |
| [Arch Linux extra](publishing-linux.md#arch-linux-extra) | An Arch Package Maintainer must agree to maintain the package and bring it into the official repository. The guide links to the package search, maintainer list and inclusion criteria. |
| [Flathub](publishing-linux.md#flatpak-and-flathub) | Submit the Flatpak app to Flathub for review. After acceptance, its app repository controls builds and publication. |

These routes use the destination's own review and publishing infrastructure. There are no GitHub Actions secrets or switches to configure for them in this repository.

## Channels configured in GitHub

The website and authenticated CLI instructions set the same values. Complete the provider enrollment steps in the channel guide first. [GitHub website setup](#github-website-setup) · [GitHub CLI setup](#github-cli-setup)

| Channel | GitHub website | Authenticated terminal | Release outcome |
| --- | --- | --- | --- |
| GitHub Releases | [Start a release in Actions](releases.md#from-the-github-website) | [Start a release with `gh`](releases.md#from-an-authenticated-terminal) | Publishes all downloads with signed build provenance. [Release signing](releases.md#signatures-for-github-downloads) · [Immutable release signatures](releases.md#github-signatures-for-the-release-itself) |
| Canonical Snap Store | [Export and paste the credential](publishing-linux.md#snap-store) | [Send the credential with `gh`](publishing-linux.md#snap-store-from-the-command-line) | Installs and tests the Store candidate on a clean system before promoting it to stable. |
| Apple Developer ID | [Enter signing and notarization settings](publishing-apple.md#configure-github-actions-in-the-browser) | [Configure Apple signing with `gh`](publishing-apple.md#configure-github-actions-with-the-cli) | Signs and notarizes the Intel and Apple silicon DMGs for direct download. [Mac App Store eligibility](publishing-apple.md#mac-app-store-eligibility) |
| Microsoft Store | [Set up Partner Center](publishing-microsoft.md#reserve-the-microsoft-store-identity) | [Configure Store updates with PowerShell and `gh`](publishing-microsoft.md#prepare-the-first-microsoft-store-submission) | Submits updates to an existing Store listing for certification. The GitHub ZIP and MSIX have their own [browser](publishing-microsoft.md#sign-github-downloads-for-windows) and [PowerShell](publishing-microsoft.md#sign-the-direct-downloads) signing instructions. |

## GitHub website setup

1. For channel flags and public Store identity metadata, open [Settings → Secrets and variables → Actions → Variables](https://github.com/joomengine/joomengine/settings/variables/actions) and choose **New repository variable**. Set the channel's flag to the literal `true` after completing its setup.
2. For Snap Store and Microsoft Store credentials, open [Settings → Environments](https://github.com/joomengine/joomengine/settings/environments), create the environment named `distribution`, then open it. Add each credential under **Environment secrets** using the exact name from its channel guide. Deployment branch and tag rules must permit your stable `v*` tags.
3. Direct-download Windows signing and Apple signing/notarization use the existing [repository Actions secrets](https://github.com/joomengine/joomengine/settings/secrets/actions). The platform guides explain where to obtain each value, its encoding and where it goes.

## GitHub CLI setup

Use this path when you have the [GitHub CLI](https://cli.github.com/) and an account with access to manage this repository's settings. The commands below work in Bash and PowerShell. Confirm the account and list existing environments.

```sh
gh auth status --hostname github.com
gh api --paginate 'repos/joomengine/joomengine/environments?per_page=100' --jq '.environments[].name'
```

For Snap Store or Microsoft Store publishing, if `distribution` is absent from a successful listing, create it and allow stable version tags. For an existing environment, keep its current approval and deployment rules. If it uses selected deployment tags, check that the intended version is allowed.

```sh
echo '{"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}' | gh api --method PUT repos/joomengine/joomengine/environments/distribution --input - --silent
gh api --method POST repos/joomengine/joomengine/environments/distribution/deployment-branch-policies -f 'name=v*' -f type=tag --silent
```

Next, use the **GitHub CLI** steps in the appropriate channel guide. Those commands set the actual secret and variable names for that publisher. You can check which names have been saved without displaying their secret values.

```sh
gh secret list --repo joomengine/joomengine --env distribution
gh secret list --repo joomengine/joomengine
gh variable list --repo joomengine/joomengine --json name --jq '.[].name'
```

## Check a skipped publisher

A skipped Snap Store job is expected on a PR or preview. On a stable tag it also requires a successful GitHub release and the repository variable `SNAP_STORE_PUBLISH=true`. The publisher reads `SNAPCRAFT_STORE_CREDENTIALS` from `distribution`. A GitHub Release download can be installed before the Store listing goes live. [Snap Store setup and commands](publishing-linux.md#snap-store)

[All JoomEngine guides](README.md)
