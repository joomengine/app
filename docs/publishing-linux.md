# Publish JoomEngine for Linux

GitHub Releases provides JoomEngine’s tested Linux packages and SHA-256 checksums. To get a listing in a distribution or store, follow its own admission process below. [Project downloads](https://github.com/joomengine/joomengine/releases) · [Release procedure](releases.md)

| Destination | Who publishes the package | Settings in this GitHub repository |
| --- | --- | --- |
| [Snap Store](#snap-store) | The release workflow tests a Store candidate and promotes it to stable. | Repository variable `SNAP_STORE_PUBLISH=true` and environment secret `distribution` → `SNAPCRAFT_STORE_CREDENTIALS`. [Browser setup](#snap-store) · [CLI setup](#snap-store-from-the-command-line) |
| [Debian archive](#debian-archive) | A Debian uploader or sponsor submits the package for archive review. | None |
| [Fedora Linux](#fedora-linux) | An approved Fedora packager builds in Koji and submits release updates in Bodhi. | None |
| [Arch Linux extra](#arch-linux-extra) | An Arch packager admits and maintains the package. | None |
| [Flathub](#flatpak-and-flathub) | A project maintainer submits the manifest to Flathub. Flathub builds and publishes it after acceptance. | None |
| [JoomEngine downloads](#project-downloads) | GitHub Actions publishes direct downloads, including the AppImage and Linux archive. | Built-in Actions token |

## Snap Store

1. Sign in to Ubuntu One, register the public snap name **joomengine**, and complete its listing under your publisher account. An existing owner can add the uploader as a collaborator. [Ubuntu One](https://login.ubuntu.com/) · [Register a snap](https://snapcraft.io/account/register-snap) · [Publisher dashboard](https://snapcraft.io/snaps)
2. Request Store review for the `browser-support` plug with `allow-sandbox: true` and automatic connection of this plug and `hardware-observe`. Explain that Chromium starts its own renderer sandbox and Qt reads PCI graphics-device information during startup. Supply the snap name, manifest and strict-confinement test from this repository. Canonical controls declaration approval and automatic connections. [Privileged interfaces request form and category](https://forum.snapcraft.io/c/store-requests/privileged-interfaces/27) · [Snap manifest](../snap/snapcraft.yaml)
3. On an Ubuntu workstation, generate the publisher credential. Run these commands in one terminal. Snapcraft prompts for the Ubuntu One publisher login. The export writes the credential into a private temporary directory, scopes it to `joomengine` on `latest/candidate` and `latest/stable`, and sets expiry to 90 days. The final command opens the directory in the Linux file manager. [Snapcraft export-login](https://documentation.ubuntu.com/snapcraft/stable/reference/commands/export-login/) · [Publisher permissions](https://github.com/snapcore/action-publish#store-login)

   ```bash
   sudo snap install snapcraft --classic
   snapcraft login
   credential_dir=$(mktemp -d)
   (
     umask 077
     snapcraft export-login --snaps=joomengine --channels=latest/candidate,latest/stable \
       --acls=package_access,package_push,package_update,package_release \
       --expires="$(date -u -d '+90 days' +%Y-%m-%dT%H:%M:%SZ)" "$credential_dir/snap-login.txt"
   )
   xdg-open "$credential_dir"
   ```

4. Open GitHub **Settings → Environments** and select `distribution`. If needed, create that environment. If deployment rules restrict tags, allow your stable `v*` tags. Open **snap-login.txt** in a local plain-text editor. Use **Select All → Copy**. The **entire exported file** is the secret value. Preserve its encoding and line breaks exactly as generated. In GitHub, open **Settings → Environments → distribution → Environment secrets → Add secret**. Enter `SNAPCRAFT_STORE_CREDENTIALS` in **Name**, paste into **Value**, and click **Add secret**. If replacing a stable-only credential, edit the existing secret and paste the newly exported contents. [Open JoomEngine environments](https://github.com/joomengine/joomengine/settings/environments)
5. Check that `SNAPCRAFT_STORE_CREDENTIALS` appears under **Environment secrets**. GitHub shows the name and update time and conceals the saved value. Close the editor, clear the clipboard and any clipboard-history entry, and remove the temporary file from the same terminal. This procedure leaves the credential out of shell history and terminal output.

   ```bash
   rm -- "$credential_dir/snap-login.txt"
   rmdir -- "$credential_dir"
   ```

6. Under **Actions → Variables → New repository variable** set **Name** to `SNAP_STORE_PUBLISH` and **Value** to `true`. Confirm it appears under **Repository variables**. Renew the environment credential before expiry. [Open JoomEngine repository variables](https://github.com/joomengine/joomengine/settings/variables/actions)
7. The tagged job uploads the verified GitHub file to **latest/candidate**. On a fresh runner it performs a normal Store install, compares the installed Snap bytes with GitHub, checks the automatic Qt, graphics and browser connections, and opens the app. It promotes that exact revision to **latest/stable** after the checks pass. In the publisher dashboard, check that the revision and version are on the stable channel. Users can then choose **Install** on the listing. [Publisher dashboard](https://snapcraft.io/snaps) · [JoomEngine Store listing](https://snapcraft.io/joomengine)
8. If Store review holds the first upload, complete Canonical's review in the dashboard and release the approved revision to **latest/candidate**. In GitHub Actions, open the tagged run and choose **Re-run jobs → Re-run failed jobs**. The job recognizes the identical candidate, tests its automatic connections and promotes it. Users can continue using the GitHub installer while the publisher resolves a Store issue. [JoomEngine Actions](https://github.com/joomengine/joomengine/actions) · [Manage Snap revisions and releases](https://documentation.ubuntu.com/snapcraft/stable/how-to/publishing/manage-revisions-and-releases/)

A skipped Store job is expected for a pull request, a main build, a disabled switch, or an unsuccessful prerequisite release. Store review can hold a revision after upload. Use the tagged workflow and the dashboard to distinguish those cases. The separate local message `joomengine 0.1.0 installed` confirms installation. Run `snap warnings` to read the actual snapd warning and `snap connections joomengine` to see which interfaces are connected.

### Snap Store from the command line

Register the snap under the correct publisher and request its interface approvals as described in steps 1–2 above. Complete the [GitHub CLI setup](publishing.md#github-cli-setup) with an administrator account. It verifies the active GitHub account and shows how to create `distribution` if needed.

Run this independent block in Bash on Ubuntu. It creates a new Snapcraft credential, sends the entire file to GitHub over standard input, and enables the repository switch only after saving the environment secret. It also works when replacing an older stable-only credential. Its temporary file is removed after the block finishes.

```bash
(
  set -euo pipefail
  umask 077
  repo=joomengine/joomengine
  gh api --silent "repos/$repo/environments/distribution"
  sudo snap install snapcraft --classic
  snapcraft login
  credential_dir=$(mktemp -d)
  trap 'rm -rf -- "$credential_dir"' EXIT
  snapcraft export-login --snaps=joomengine --channels=latest/candidate,latest/stable \
    --acls=package_access,package_push,package_update,package_release \
    --expires="$(date -u -d '+90 days' +%Y-%m-%dT%H:%M:%SZ)" "$credential_dir/snap-login"
  gh secret set SNAPCRAFT_STORE_CREDENTIALS --repo "$repo" --env distribution < "$credential_dir/snap-login"
  gh variable set SNAP_STORE_PUBLISH --repo "$repo" --body true
  gh secret list --repo "$repo" --env distribution
  gh api "repos/$repo/actions/variables/SNAP_STORE_PUBLISH" --jq .value
)
```

Confirm that the secret name is listed and the switch reads `true`. Renew the token before its 90-day expiry by repeating this block. After a tagged release, `snapcraft status joomengine` shows the candidate and stable revisions. If the first upload needs Canonical review, complete that review with the publisher before retrying the failed job. [Snap Store registration](https://snapcraft.io/account/register-snap) · [Snap Store publisher dashboard](https://snapcraft.io/snaps)

## Debian archive

1. Search the archive and the list of prospective packages for **joomengine**. Coordinate with the existing maintainer if there is already a package or an open request. Otherwise run `reportbug wnpp`, choose **ITP**, and provide the project URL, Apache-2.0 license and a short description. Debian also accepts a plain-text ITP by email using the WNPP instructions. Keep the assigned bug number. [Package search](https://packages.debian.org/) · [WNPP and ITP instructions](https://www.debian.org/devel/wnpp/)
2. From a tagged JoomEngine source release, prepare a Debian source package for **unstable**. Start with the project's Debian packaging, use a monitored maintainer address, and record the ITP bug number in the first changelog entry. The CI changelog template targets Debian 13 (`trixie`) for the downloadable binary. Set the archive submission's suite, version and changelog explicitly. Build from the source package in a clean unstable environment and check it with Lintian. [JoomEngine packaging](../packaging/debian/) · [Debian Maintainer Guide](https://www.debian.org/doc/manuals/debmake-doc/) · [New package procedure](https://www.debian.org/doc/manuals/developers-reference/pkgs.en.html#new-packages)
3. If you need a sponsor, register a **Maintainer** account on Debian Mentors and add your public OpenPGP key. Sign the source upload locally and send its `_source.changes` using the Mentors `dput` configuration. On the uploaded package's page, select **Needs a sponsor** and send the generated request to the `sponsorship-requests` bug tracker. A sponsor reviews it with you. [Register on Mentors](https://mentors.debian.net/accounts/register/) · [Signing, upload and sponsorship instructions](https://mentors.debian.net/intro-maintainers/)
4. The authorized uploader submits the initial source **and matching binaries** for Debian’s NEW review. Track it in the NEW queue, then on the Debian Package Tracker. Later versions normally use source-only uploads to unstable and follow Debian's testing migration rules. Getting an update into an existing stable release follows Debian's stable-update or backports policies. The signing key stays with the Debian uploader. [Upload rules](https://www.debian.org/doc/manuals/developers-reference/pkgs.en.html#source-and-binary-uploads) · [NEW queue](https://ftp-master.debian.org/new.html) · [Debian Package Tracker](https://tracker.debian.org/) · [Backports](https://backports.debian.org/Contribute/)

## Fedora Linux

1. Search Fedora Packages and existing Package Review tickets for **joomengine**. Register a Fedora account, complete the contributor agreement, and follow the packager onboarding instructions. Use the same email address for Fedora and Red Hat Bugzilla. A first-time packager needs an approved sponsor. [Package search](https://packages.fedoraproject.org/) · [Fedora Accounts](https://accounts.fedoraproject.org/) · [Join the package maintainers](https://docs.fedoraproject.org/en-US/package-maintainers/Joining_the_Package_Maintainers/)
2. Prepare a standalone spec and source RPM (SRPM) for the tagged JoomEngine release. CI supplies `project_version` to the project's spec on the command line. For Fedora review, ensure the spec resolves the real version and tagged sources on its own. Test a clean Rawhide rebuild with Mock. Open a **Package Review** in Bugzilla and provide publicly downloadable links to both the spec and SRPM. Request sponsorship in the ticket if needed. [JoomEngine spec](../packaging/rpm/joomengine.spec) · [Review request form](https://bugzilla.redhat.com/enter_bug.cgi?product=Fedora&format=fedora-review) · [Fedora review procedure](https://docs.fedoraproject.org/en-US/package-maintainers/Package_Review_Process/)
3. After approval and sponsorship, use the current `fedpkg request-repo` with the package name and review ID to request the official dist-git repository. Request the supported release branches you will maintain. Import the reviewed packaging and source into Fedora's repository, then use `fedpkg build` to start its Koji build. [New-package process](https://docs.fedoraproject.org/en-US/package-maintainers/New_Package_Process_for_New_Contributors/) · [Koji build status](https://koji.fedoraproject.org/koji/)
4. For released Fedora branches, submit the successful build in Bodhi using its web interface or `fedpkg update`. Follow testing and gating until it reaches stable. For subsequent upstream versions, the Fedora maintainer updates dist-git, rebuilds in Koji, and submits the relevant updates. The maintainer authenticates to Fedora with their own account. [Bodhi](https://bodhi.fedoraproject.org/) · [Package update guide](https://docs.fedoraproject.org/en-US/package-maintainers/Package_Update_Guide/)

## Arch Linux extra

1. Search the official package database for **joomengine**. If it is already packaged, send new-release information to the listed maintainer. For a new package, an Arch packager must be willing to maintain it and assess admission to `extra` under Arch's eligibility and popularity rules. The team decides whether to take it on. [Official package search](https://archlinux.org/packages/?q=joomengine) · [Package maintainer guidelines](https://wiki.archlinux.org/title/Package_Maintainer_guidelines) · [Arch package maintainers](https://archlinux.org/people/package-maintainers/)
2. Provide the release tag, source tarball, its checksum, the Qt dependencies, the upstream test procedure and the project's PKGBUILD template. A participating Arch packager prepares the official recipe, builds it in a clean chroot, signs it and releases it through Arch's packaging infrastructure. Subsequent releases go through the same downstream maintainer. Users can see the repository, packager and package version in Arch's official database once accepted. [PKGBUILD template](../packaging/arch/PKGBUILD.in) · [Upstream tests](contributing.md) · [Arch packaging tools](https://man.archlinux.org/man/pkgctl.1.en)

## Flatpak and Flathub

Tagged builds publish an installable Flatpak bundle to GitHub. Flathub hosts its own build and review infrastructure. A Flathub application maintainer follows these steps.

1. A project maintainer with a GitHub account and two-factor authentication must independently author the Flathub manifest. The maintainer personally writes the submission, commit messages, and review replies under Flathub’s AI policy. The GitHub bundle uses AI-assisted packaging. Disclose the affected application code, documentation and packaging and their approximate extent as required. Check Flathub’s minimum project-history and desktop-integration criteria for applications that embed a website. Explain the native workspace windows, download and file handling, and saved Joomla projects. Acceptance is decided by Flathub. [Submission requirements](https://docs.flathub.org/docs/for-app-authors/requirements)
2. Use the project-controlled app ID `org.joomengine.app`. Test the human-authored manifest with the Flathub builder and linter. Fork the Flathub repository including the `new-pr` branch, branch from it, and open the submission against `flathub/flathub:new-pr`. The maintainer handles the submission and reviewer correspondence. After approval, accept the invitation to the app repository. [Flathub submission](https://docs.flathub.org/docs/for-app-authors/submission) · [Flathub repository](https://github.com/flathub/flathub/tree/new-pr)
3. In that app repository the maintainer can configure `x-checker-data` for stable JoomEngine release sources. Flathub's external data checker opens version updates. Review its test build and merge the update to trigger the official build and publication. This route uses Flathub's infrastructure and needs no Flathub token in the JoomEngine repository. [Flathub updates](https://docs.flathub.org/docs/for-app-authors/maintenance)
4. Sign into the Flathub developer dashboard and select the app to verify ownership. For the domain-file verification method, place the supplied token at `https://joomengine.org/.well-known/org.flathub.VerifiedApps.txt`. [Flathub developer dashboard](https://flathub.org/apps/mine) · [Verification](https://docs.flathub.org/docs/for-app-authors/verification)

## Project downloads

AppImage and the Linux archive are published with `SHA256SUMS` on JoomEngine's GitHub Releases. Each release also provides direct Debian, Arch, Fedora, Snap and Flatpak downloads independently of store or archive admission. Users can install their chosen package directly. [Downloads](https://github.com/joomengine/joomengine/releases) · [Linux installation guides](install-linux.md) · [Checksum verification](install-verify.md)

[All publishing channels](publishing.md)
