# Build and release JoomEngine

[Download a stable release](https://github.com/joomengine/joomengine/releases/latest) · [Browse main-branch previews](https://github.com/joomengine/joomengine/releases?q=continuous-&expanded=true) · [Desktop workflow runs](https://github.com/joomengine/joomengine/actions/workflows/desktop.yml)

| Successful build | Where to get the files | Customer-facing actions |
| --- | --- | --- |
| Pull request or manual build of a feature branch | Open the workflow run and expand **Artifacts**. Sign in to GitHub, download the package artifact and `download-checksums`, and extract each GitHub ZIP. | Review builds only. |
| Push to `main`, or **Run workflow** on `main` | A public GitHub prerelease tagged `continuous-<12-character commit>` | The commit has its own download URLs and checksum manifest. Previews leave the latest stable release in place. |
| Start stable release from main, or push a tag matching `v` followed by the exact contents of `VERSION` | A public versioned GitHub release | The workflow runs configured production signing, then enables the selected store jobs after publication. |

## Cut a stable release

Set the next unused version in `VERSION` through a pull request. Merge the reviewed change and check the [main-branch preview](https://github.com/joomengine/joomengine/releases?q=continuous-&expanded=true). Optional stores and production signing use the credentials in [publisher setup](publishing.md).

### From the GitHub website

1. Open [Actions → Start stable release](https://github.com/joomengine/joomengine/actions/workflows/start-release.yml).
2. Choose **Run workflow**, select **main**, and enter the exact number in `VERSION`, such as `0.2.0`, without a leading `v`.
3. Click **Run workflow**. GitHub creates the version tag at the selected commit and starts [JoomEngine desktop](https://github.com/joomengine/joomengine/actions/workflows/desktop.yml) on that tag. Follow **Publish verified GitHub downloads** for the public release.

### From an authenticated terminal

You can start the same workflow with GitHub CLI. Read the current version in GitHub or from your checkout, then supply it to the command. For version 0.2.0:

```sh
gh workflow run start-release.yml --repo joomengine/joomengine --ref main -f version=0.2.0
gh run list --repo joomengine/joomengine --workflow desktop.yml --limit 5
```

If your release process already pushes Git tags from a checkout, it can keep doing so. From a clean checkout run:

```sh
git switch main
git pull --ff-only origin main
version=$(cat VERSION)
git show -s --oneline HEAD
git tag -a "v$version" -m "JoomEngine $version" &&
  git push origin "refs/tags/v$version"
```

After the GitHub release appears, the enabled Snap Store and Microsoft Store jobs can submit that version. If a store job fails, correct its setup and use **Re-run failed jobs** on the original desktop workflow run.

To bring a release into Debian, Fedora, Arch Linux or Flathub, follow the [official submission process for that channel](publishing.md#official-linux-archives-and-flathub).

## Release contents and verification

The same run supplies the Windows x64 ZIP and MSIX, Apple silicon and Intel DMGs, and seven x86-64 Linux packages. Linux packages include a native archive, Snap, Debian package, Arch package, Fedora RPM, Flatpak and AppImage. Download dependencies and minimum OS versions are documented in the [installation guides](README.md#install-on-your-computer).

The release includes corresponding source archives for the bundled Qt runtime and the Flatpak WebEngine build. All installers are available directly from **Assets**, including when every store publisher is disabled. Users can download just their chosen installer and `SHA256SUMS` in a browser. The one-file Snap installer includes the release Snap and configures its runtime on first install. The checksum job checks the expected filename and presence of each artifact and records the digest of its bytes. Before publication the workflow downloads the artifacts again, compares the manifest, verifies the corresponding Qt source, and compares every uploaded asset against GitHub's SHA-256 digest. [Verify an individual download](install-verify.md)

GitHub publication uses the temporary Actions token with write access in the publication job. The optional release starter uses `contents: write` to create the tag and `actions: write` to start its build. Repository or organization policies must permit that write and creation of version and preview tags. Public downloads use GitHub Releases independently of store registrations. [Actions settings](https://github.com/joomengine/joomengine/settings/actions) · [Repository rules](https://github.com/joomengine/joomengine/settings/rules)

Publishing stages files in a draft. A retry can finish an interrupted draft. Running the same main commit again verifies and keeps its existing public preview. Newly generated review or Store inputs appear in that run’s artifacts. A stable release is accepted on retry only when its source commit and uploaded digests match. To distribute changed bytes after publication, assign a new version. GitHub's automatically generated source ZIP and tarball links are generated from the release commit and sit outside the uploaded asset manifest.

## Signatures for GitHub downloads

Before a new release becomes public, the release job uses its short-lived GitHub Actions identity to sign a provenance statement covering the final installers, both corresponding Qt source archives and `SHA256SUMS`. The statement records the repository, workflow, source ref and commit. The public repository needs no signing key or additional secret for this step. The release job needs `id-token: write` and `attestations: write`. Apple Developer ID and Windows code-signing certificates continue to provide the signatures that those operating systems recognize. [Verify a download](install-verify.md) · [GitHub artifact attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations)

## GitHub signatures for the release itself

A repository administrator can also enable **release immutability** before publishing. GitHub then signs a release record containing the version tag, commit and asset digests. The setting applies to future published releases, including main-branch previews. Once published, their tags and assets are locked. To correct a published installer, issue a new version. [GitHub immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases)

- **In the browser**, open the repository's **Settings → General → Releases** and select **Enable release immutability**. [Repository settings](https://github.com/joomengine/joomengine/settings) · [GitHub instructions](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/establish-provenance-and-integrity/prevent-release-changes)
- **From an authenticated terminal**, an administrator can enable the same setting and read back its status.

```sh
gh api --method PUT repos/joomengine/joomengine/immutable-releases --silent
gh api repos/joomengine/joomengine/immutable-releases
```

After publishing an immutable release, verify the release record by tag. For example, for version 0.2.0:

```sh
gh release verify v0.2.0 --repo joomengine/joomengine
```

[All JoomEngine guides](README.md)
