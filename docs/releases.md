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

After the GitHub release appears, each enabled store handles its certification or publication. If one of those jobs fails, correct its setup and use **Re-run failed jobs** on the original desktop workflow run.

## Release contents and verification

The same run supplies the Windows x64 ZIP and MSIX, Apple silicon and Intel DMGs, and seven x86-64 Linux packages. Linux packages include a native archive, Snap, Debian package, Arch package, Fedora RPM, Flatpak and AppImage. Download dependencies and minimum OS versions are documented in the [installation guides](README.md#install-on-your-computer).

The release includes corresponding source archives for the bundled Qt runtime and the Flatpak WebEngine build. Users only need their chosen installer and `SHA256SUMS`. The one-file Snap installer includes the release Snap and configures its runtime on first install. The checksum job checks the expected filename and presence of each artifact and records the digest of its bytes. Before publication the workflow downloads the artifacts again, compares the manifest, verifies the corresponding Qt source, and compares every uploaded asset against GitHub's SHA-256 digest. [Verify an individual download](install-verify.md)

GitHub publication uses the temporary Actions token with write access in the publication job. The optional release starter uses `contents: write` to create the tag and `actions: write` to start its build. Repository or organization policies must permit that write and creation of version and preview tags. Public downloads use GitHub Releases independently of store registrations. [Actions settings](https://github.com/joomengine/joomengine/settings/actions) · [Repository rules](https://github.com/joomengine/joomengine/settings/rules)

Publishing stages files in a draft. A retry can finish an interrupted draft. Running the same main commit again verifies and keeps its existing public preview. Newly generated review or Store inputs appear in that run’s artifacts. A stable release is accepted on retry only when its source commit and uploaded digests match. To distribute changed bytes after publication, assign a new version. GitHub's automatically generated source ZIP and tarball links are generated from the release commit and sit outside the uploaded asset manifest.

[All JoomEngine guides](README.md)
