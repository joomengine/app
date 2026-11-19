# Build and release JoomEngine

[Download a stable release](https://github.com/joomengine/joomengine/releases/latest) · [Browse main-branch previews](https://github.com/joomengine/joomengine/releases?q=continuous-&expanded=true) · [Desktop workflow runs](https://github.com/joomengine/joomengine/actions/workflows/desktop.yml)

| Successful build | Where to get the files | Customer-facing actions |
| --- | --- | --- |
| Pull request or manual build of a feature branch | Open the workflow run and expand **Artifacts**. Sign in to GitHub, download the package artifact and `download-checksums`, and extract each GitHub ZIP. | Review builds only. |
| Push to `main`, or **Run workflow** on `main` | A public GitHub prerelease tagged `continuous-<12-character commit>` | The commit has its own download URLs and checksum manifest. Previews leave the latest stable release in place. |
| Push a tag matching `v` followed by the exact contents of `VERSION` | A public versioned GitHub release | The workflow runs configured production signing, then enables the selected store jobs after publication. |

## Cut a stable release

1. Set the next unused semantic version in `VERSION` through a PR. New formats in this series begin with 0.2.0. If you use a store, complete the [publisher setup](publishing.md) before tagging.
2. Merge the reviewed PR, then check its preview on GitHub. Open the [desktop workflow](https://github.com/joomengine/joomengine/actions/workflows/desktop.yml) and confirm that its base commit and your intended release commit match.
3. From a clean checkout, run the commands below. They show the exact commit and reject an existing version tag. Pushing the tag starts a fresh packaging and signing run.

   ```sh
   git switch main
   git pull --ff-only origin main
   version=$(cat VERSION)
   git show -s --oneline HEAD
   git tag -a "v$version" -m "JoomEngine $version" &&
     git push origin "refs/tags/v$version"
   ```

4. Verify **Publish verified GitHub downloads** and review the release's **Assets**. A store can take longer to review an update. If its job fails after GitHub publication, fix its setup and use **Re-run failed jobs** on that run.

## Release contents and verification

The same run supplies the Windows x64 ZIP and MSIX, Apple silicon and Intel DMGs, and seven x86-64 Linux packages. Linux packages include a native archive, Snap, Debian package, Arch package, Fedora RPM, Flatpak and AppImage. Download dependencies and minimum OS versions are documented in the [installation guides](../README.md#download-and-install).

The release includes corresponding source archives for the bundled Qt runtime and the Flatpak WebEngine build. Users only need their chosen installer and `SHA256SUMS`. The one-file Snap installer includes the release Snap and configures its runtime on first install. The checksum job checks the expected filename and presence of each artifact and records the digest of its bytes. Before publication the workflow downloads the artifacts again, compares the manifest, verifies the corresponding Qt source, and compares every uploaded asset against GitHub's SHA-256 digest. [Verify an individual download](install-verify.md)

GitHub publication uses the temporary Actions token with `contents: write` only in the release job. Repository or organization policies must permit that write and creation of version and preview tags. Public downloads use GitHub Releases independently of store registrations. [Actions settings](https://github.com/joomengine/joomengine/settings/actions) · [Repository rules](https://github.com/joomengine/joomengine/settings/rules)

Publishing stages files in a draft. A retry can finish an interrupted draft. A completed release is accepted on retry only when its source commit and uploaded digests match. To distribute changed bytes after publication, assign a new version. GitHub's automatically generated source ZIP and tarball links are generated from the release commit and sit outside the uploaded asset manifest.
