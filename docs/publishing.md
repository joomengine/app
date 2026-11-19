# Publish JoomEngine to distribution channels

Every successful main build and version-tag build publishes its downloads to GitHub Releases. People can install them directly without a store account. To make stable updates available through a store or a package manager, choose a channel below, configure its credentials, then start a stable release from the website or terminal. [Release procedure](releases.md) · [Manual installation](README.md#install-on-your-computer)

Choose one way to enter your settings. **[GitHub website](#github-website-setup)** uses your existing browser login. **[GitHub CLI](#github-cli-setup)** sets the same names from an authenticated terminal. The channel guides give separate instructions for both. Provider enrollment and approval apply whichever method you choose.

| Channel | GitHub website | Authenticated terminal | What gets published |
| --- | --- | --- | --- |
| GitHub Releases | [Start a release in Actions](releases.md#from-the-github-website) | [Start a release with `gh`](releases.md#from-an-authenticated-terminal) | All verified packages and SHA-256 checksums, using the built-in Actions token. |
| Snap Store | [Export and paste the Snap credential](publishing-linux.md#snap-store) | [Send the Snap credential with `gh`](publishing-linux.md#snap-store-from-the-command-line) | A candidate is installed and tested on a clean system before promotion to stable. |
| Debian APT and Fedora DNF | [Enter the Cloudsmith settings](publishing-linux.md#debian-apt-and-fedora-rpm) | [Set up APT and RPM with `gh`](publishing-linux.md#debian-and-fedora-from-the-command-line) | The GitHub binaries go to your signed package repository. [Official distribution archives](publishing-linux.md#official-distribution-archives) have their own admission process. |
| Arch User Repository | [Enter the AUR settings](publishing-linux.md#arch-user-repository) | [Configure AUR with `gh`](publishing-linux.md#aur-from-the-command-line) | The source recipe and package metadata go to AUR. Users can also download the binary from GitHub. |
| macOS | [Enter signing and notarization settings](publishing-apple.md#configure-github-actions-in-the-browser) | [Configure Apple signing with `gh`](publishing-apple.md#configure-github-actions-with-the-cli) | Signed, notarized DMGs for Apple silicon and Intel when configured. [Mac App Store eligibility](publishing-apple.md#mac-app-store-eligibility) |
| Windows and Microsoft Store | [Set up Partner Center](publishing-microsoft.md#reserve-the-microsoft-store-identity) · [Sign direct downloads](publishing-microsoft.md#sign-github-downloads-for-windows) | [Configure signing and Store updates with PowerShell and `gh`](publishing-microsoft.md#configure-github-actions-from-powershell) | Portable ZIP and MSIX on GitHub, plus optional updates to a published Microsoft Store listing. |

The standalone Flatpak bundle, AppImage and Linux archive are included in GitHub Releases automatically. For an external listing, follow the provider's submission process. [Flathub](publishing-linux.md#flatpak-and-flathub) · [AppImageHub](publishing-linux.md#appimagehub-and-the-linux-archive)

## GitHub website setup

1. For channel flags and public Store identity metadata, open [Settings → Secrets and variables → Actions → Variables](https://github.com/joomengine/joomengine/settings/variables/actions) and choose **New repository variable**. Set the channel's flag to the literal `true` after completing its setup.
2. For Linux and Microsoft publisher credentials, open [Settings → Environments](https://github.com/joomengine/joomengine/settings/environments), create the environment named `distribution`, then open it. Use **Environment secrets** or **Environment variables** exactly as the channel guide specifies. Deployment branch and tag rules must permit your stable `v*` tags.
3. Direct-download Windows signing and Apple signing/notarization use the existing [repository Actions secrets](https://github.com/joomengine/joomengine/settings/secrets/actions). The platform guides explain where to obtain each value, its encoding and where it goes.

## GitHub CLI setup

Use this path when you have the [GitHub CLI](https://cli.github.com/) and an account with access to manage this repository's settings. The commands below work in Bash and PowerShell. Confirm the account and list existing environments.

```sh
gh auth status --hostname github.com
gh api --paginate 'repos/joomengine/joomengine/environments?per_page=100' --jq '.environments[].name'
```

If `distribution` is absent from a successful listing, create it and allow stable version tags. For an existing environment, keep its current approval and deployment rules. If it uses selected deployment tags, check that the intended version is allowed.

```sh
echo '{"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}' | gh api --method PUT repos/joomengine/joomengine/environments/distribution --input - --silent
gh api --method POST repos/joomengine/joomengine/environments/distribution/deployment-branch-policies -f 'name=v*' -f type=tag --silent
```

Next, use the **GitHub CLI** steps in the appropriate channel guide. Those commands set the actual secret and variable names for that publisher. You can check which names have been saved without displaying their secret values.

```sh
gh secret list --repo joomengine/joomengine --env distribution
gh variable list --repo joomengine/joomengine --env distribution --json name --jq '.[].name'
gh secret list --repo joomengine/joomengine
gh variable list --repo joomengine/joomengine --json name --jq '.[].name'
```

## Check a skipped publisher

A skipped Snap Store job is expected on a PR or preview. On a stable tag it also requires a successful GitHub release and the repository variable `SNAP_STORE_PUBLISH=true`. The publisher reads `SNAPCRAFT_STORE_CREDENTIALS` from `distribution`. A GitHub Release download can be installed before the Store listing goes live. [Snap Store setup and commands](publishing-linux.md#snap-store)

[All JoomEngine guides](README.md)
