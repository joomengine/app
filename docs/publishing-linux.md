# Publish JoomEngine for Linux

The desktop workflow publishes the tested Linux packages and their SHA-256 checksums on GitHub. Store registration is independent. Enable the channels you maintain after completing their setup. The publisher reads the files back from the completed, versioned GitHub Release and verifies their checksums. The AUR builds from that version's source tag. [GitHub Releases](https://github.com/joomengine/joomengine/releases) · [Linux publication workflow](../.github/workflows/linux-publish.yml)

## GitHub settings

1. Create an environment named **distribution**. Under **Deployment branches and tags**, select **Selected branches and tags** and add a **tag** rule for `v*`. [Environments](https://github.com/joomengine/joomengine/settings/environments)
2. In **distribution**, use **Environment secrets → Add environment secret** and **Environment variables → Add environment variable** for the values below. Each job looks up credentials when the environment is attached. [Environment settings](https://github.com/joomengine/joomengine/settings/environments)
3. Set each desired switch under **Repository variables**. The value must be the lowercase text `true`. GitHub evaluates the job condition before it attaches an environment, so switches belong at repository level. [Actions repository variables](https://github.com/joomengine/joomengine/settings/variables/actions)

| Channel | Repository switch | Variables in `distribution` | Secrets in `distribution` |
| --- | --- | --- | --- |
| Snap Store, latest/candidate → latest/stable | `SNAP_STORE_PUBLISH` | None | `SNAPCRAFT_STORE_CREDENTIALS` |
| Debian 13 APT | `DEBIAN_REPO_PUBLISH` | `CLOUDSMITH_NAMESPACE`, `CLOUDSMITH_REPOSITORY` | `CLOUDSMITH_API_KEY` |
| Fedora 44 RPM | `RPM_REPO_PUBLISH` | Same two Cloudsmith variables | Same Cloudsmith key |
| Arch User Repository | `AUR_PUBLISH` | `AUR_MAINTAINER_EMAIL`, `AUR_KNOWN_HOSTS` | `AUR_SSH_PRIVATE_KEY` |
| GitHub AppImage, Flatpak bundle, Linux archive and other binaries | Automatic for release builds | None | None |
| Flathub and AppImageHub | External catalog setup below | None | None |

## Snap Store

1. Sign into Ubuntu One, register the public snap name **joomengine**, and complete its listing under your publisher account. An existing owner can add the uploader as a collaborator. [Ubuntu One](https://login.ubuntu.com/) · [Register a snap](https://snapcraft.io/account/register-snap) · [Publisher dashboard](https://snapcraft.io/snaps)
2. Request Store review for the `browser-support` plug with `allow-sandbox: true` and automatic connection of this plug and `hardware-observe`. Explain that Chromium starts its own renderer sandbox and Qt reads PCI graphics-device information during startup. Supply the snap name, manifest and strict-confinement test from this repository. Canonical controls declaration approval and automatic connections. [Privileged interfaces request form and category](https://forum.snapcraft.io/c/store-requests/privileged-interfaces/27) · [Snap manifest](../snap/snapcraft.yaml)
3. On an Ubuntu workstation install Snapcraft, log in as the publisher, and export an upload credential restricted to this snap and its candidate and stable channels. The final command reads the credential file directly into the GitHub environment secret. It requires a signed-in GitHub CLI account with permission to manage the environment. [Snapcraft export-login](https://documentation.ubuntu.com/snapcraft/stable/reference/commands/export-login/) · [Publisher action permissions](https://github.com/snapcore/action-publish#store-login)

   ```bash
   sudo snap install snapcraft --classic
   snapcraft login
   (
     umask 077
     credential_dir=$(mktemp -d)
     trap 'rm -rf -- "$credential_dir"' EXIT
     snapcraft export-login --snaps=joomengine --channels=latest/candidate,latest/stable \
       --acls=package_access,package_push,package_update,package_release \
       --expires="$(date -u -d '+90 days' +%Y-%m-%dT%H:%M:%SZ)" "$credential_dir/snap-login"
     gh secret set SNAPCRAFT_STORE_CREDENTIALS --env distribution \
       --repo joomengine/joomengine < "$credential_dir/snap-login"
   )
   gh variable set SNAP_STORE_PUBLISH --body true --repo joomengine/joomengine
   ```

4. If you previously configured a stable-only token, generate a new one with both channels and save it in the **distribution** environment. Renew the credential before its expiry. The tagged job uploads the verified GitHub file to **latest/candidate**. On a fresh runner it performs a normal Store install, compares the installed Snap bytes with GitHub, checks the automatic Qt, graphics and browser connections, and opens the app. Only then does it promote that exact revision to **latest/stable**. Check the result with `snapcraft status joomengine`. Once the stable listing is public, users can choose **Install** on the [Snap Store page](https://snapcraft.io/joomengine) or run `sudo snap install joomengine`. No post-install setup is needed.
5. If Store review holds the first upload, complete Canonical's review in the dashboard and release the approved revision to **latest/candidate**. Re-run the failed GitHub job. It recognizes the identical candidate, tests its actual automatic connections, and promotes it. If Canonical declines an auto-connection or the clean install fails, users can continue using the verified GitHub installer while the publisher resolves the issue. [Manage Snap revisions and releases](https://documentation.ubuntu.com/snapcraft/stable/how-to/publishing/manage-revisions-and-releases/)

A skipped Store job is expected for a pull request, a main build, a disabled switch, or an unsuccessful prerequisite release. Store review can hold a revision after upload. Use the tagged workflow and the dashboard to distinguish those cases. The separate local message `joomengine 0.1.0 installed` confirms installation. Run `snap warnings` to read the actual snapd warning and `snap connections joomengine` to see which interfaces are connected.

## Debian APT and Fedora RPM

Both jobs can use one public Cloudsmith repository. Cloudsmith hosts and signs the APT/RPM repository metadata and provides repository-specific installation instructions. The Debian job uploads the Debian 13 (trixie) amd64 build. The RPM job uploads the Fedora 44 x86-64 build.

1. Sign in, create or select a workspace, and create a **public** package repository. Use the workspace slug as `CLOUDSMITH_NAMESPACE` and the repository slug as `CLOUDSMITH_REPOSITORY`. Slugs appear in the upload command under **Push/Pull Packages**. Keep duplicate-version replacement disabled, so existing releases retain their contents. [Cloudsmith login](https://app.cloudsmith.com/login) · [Workspaces](https://app.cloudsmith.com/workspaces) · [Package upload](https://docs.cloudsmith.com/artifact-management/package-upload)
2. Open the workspace's **Accounts → Services**, create a release service account and copy its API key when displayed. Under the repository's **Settings → Access control**, grant the service **Write** on this repository. Save the key as `CLOUDSMITH_API_KEY` in the GitHub environment. An administrator can rotate a lost key from the same Services page and replace the GitHub secret. [Service accounts](https://docs.cloudsmith.com/accounts-and-teams/service-accounts) · [Repository privileges](https://docs.cloudsmith.com/repositories/repository-privileges)
3. Enable `DEBIAN_REPO_PUBLISH`, `RPM_REPO_PUBLISH`, or both. After the release, open **Packages** and verify the new package is synced in `debian/trixie` or `fedora/44`. Each package carries its GitHub release digest as a Cloudsmith tag. A repeated upload recognizes an already synced copy. A failed sync can be inspected and retried in the repository. [Cloudsmith package management](https://docs.cloudsmith.com/artifact-management/package-upload)
4. Open **Push/Pull Packages → Debian** or **RPM** in that repository. Copy its **public setup** URL and signing-key fingerprint into your announcement. On a clean test system follow those signed-repository instructions, then run `sudo apt update && sudo apt install joomengine` on Debian or `sudo dnf install joomengine` on Fedora. [APT setup and signing](https://docs.cloudsmith.com/formats/debian-repository) · [RPM setup and signing](https://docs.cloudsmith.com/formats/redhat-repository)

### Official distribution archives

Debian's archive accepts reviewed source packages. A Debian maintainer checks for an existing package or request, files an Intent To Package, prepares a Debian Policy-compliant source package for unstable, uploads it to mentors if sponsorship is needed and files a Request For Sponsorship. A sponsor submits it to the Debian NEW queue for archive review. No GitHub credential grants this admission. [Debian WNPP](https://www.debian.org/devel/wnpp/) · [Debian Mentors](https://mentors.debian.net/intro-maintainers/) · [Debian new package procedures](https://www.debian.org/doc/manuals/developers-reference/pkgs.en.html#new-packages)

Fedora's official repositories use a separate package review, sponsorship and Fedora build/submission process. Publishing the RPM to GitHub or Cloudsmith gives users immediate installation routes while a Fedora packager pursues inclusion. [Fedora package review](https://docs.fedoraproject.org/en-US/package-maintainers/Package_Review_Process/)

## Arch User Repository

GitHub hosts a ready-made pacman binary. The AUR publishes a source build recipe and its `.SRCINFO` metadata. The publishing job regenerates both for the exact version, pins the tag archive's SHA-256 and fast-forwards the AUR repository. Upgrading a community package into an official Arch repository is a separate Arch packaging-team decision. [AUR submission guidelines](https://wiki.archlinux.org/title/AUR_submission_guidelines)

1. Register an AUR maintainer account. Search for **joomengine** before the first upload. If someone already maintains the package, obtain co-maintainer access or follow the AUR adoption process. For an available name the first accepted push creates the package. [AUR registration](https://aur.archlinux.org/register) · [AUR search](https://aur.archlinux.org/packages?K=joomengine)
2. Generate a dedicated Ed25519 key on your workstation. In the AUR account, open **My Account → SSH Public Key** and add the single line from the `.pub` file. Store the private key as the GitHub environment secret, including the header, footer, and line breaks. The command below creates a new key in a new private directory and prints only its public half.

   ```bash
   key_dir=$(mktemp -d)
   ssh-keygen -t ed25519 -N '' -C 'JoomEngine AUR releases' -f "$key_dir/aur"
   cat "$key_dir/aur.pub"
   gh secret set AUR_SSH_PRIVATE_KEY --env distribution \
     --repo joomengine/joomengine < "$key_dir/aur"
   ```

3. Acquire the **server's** public Ed25519 host key and verify its fingerprint against the current Ed25519 fingerprint advertised by the AUR over HTTPS. After a match, save the complete host-key line as the environment **variable** `AUR_KNOWN_HOSTS`. This is separate from your account's public key. [AUR home and SSH fingerprints](https://aur.archlinux.org/)

   ```bash
   ssh-keyscan -t ed25519 aur.archlinux.org > "$key_dir/aur_known_hosts"
   ssh-keygen -lf "$key_dir/aur_known_hosts" -E sha256
   # After checking the displayed SHA256 fingerprint on the AUR website:
   gh variable set AUR_KNOWN_HOSTS --env distribution \
     --repo joomengine/joomengine < "$key_dir/aur_known_hosts"
   ```

4. Set the environment variable `AUR_MAINTAINER_EMAIL` to the public maintainer contact you want displayed on AUR Git commits. Securely store or remove the workstation's temporary key directory after setup. Enable `AUR_PUBLISH` at repository level. After the release, check that the package shows the released version and run `makepkg -si` as a regular user in a fresh AUR checkout. [AUR package records](https://aur.archlinux.org/packages?K=joomengine)

## Flatpak and Flathub

Tagged builds publish an installable Flatpak bundle to GitHub. Flathub hosts its own build and review infrastructure. For an official listing:

1. A project maintainer with a GitHub account and two-factor authentication must independently author the Flathub manifest. Flathub prohibits AI-assisted manifests and automated submission PRs. The GitHub bundle uses AI-assisted packaging. Disclose the affected application code, documentation and packaging and their approximate extent as required. Review Flathub's desktop integration and project-history criteria. Explain the native workspace windows, download and file handling, and saved Joomla projects. Acceptance is decided by Flathub. [Submission requirements](https://docs.flathub.org/docs/for-app-authors/requirements)
2. Use the project-controlled app ID `org.joomengine.app`. Test the human-authored manifest with the Flathub builder and linter. Fork the Flathub repository including the `new-pr` branch, branch from it, and open the submission against `flathub/flathub:new-pr`. The maintainer handles the submission and reviewer correspondence. After approval, accept the invitation to the app repository. [Flathub submission](https://docs.flathub.org/docs/for-app-authors/submission) · [Flathub repository](https://github.com/flathub/flathub/tree/new-pr)
3. In that app repository the maintainer can configure `x-checker-data` for stable JoomEngine release sources. Flathub's external data checker opens version updates. Review its test build and merge the update to trigger the official build and publication. This route uses Flathub's infrastructure and needs no Flathub token in the JoomEngine repository. [Flathub updates](https://docs.flathub.org/docs/for-app-authors/maintenance)
4. Sign into the Flathub developer dashboard and select the app to verify ownership. For the domain-file verification method, place the supplied token at `https://joomengine.org/.well-known/org.flathub.VerifiedApps.txt`. [Flathub developer dashboard](https://flathub.org/apps/mine) · [Verification](https://docs.flathub.org/docs/for-app-authors/verification)

## AppImageHub and the Linux archive

GitHub hosts both the AppImage and the Linux tar archive. Neither requires store credentials. Once the first public versioned release includes the AppImage, a maintainer may submit a one-line file named `data/JoomEngine` containing `https://github.com/joomengine/joomengine` to the AppImageHub catalog. Reviewers exercise the package on their baseline Linux image and decide inclusion. Using the repository URL lets the catalog discover subsequent AppImages through GitHub Releases. [Submit to AppImageHub](https://github.com/AppImage/appimage.github.io/new/master/data) · [Catalog requirements and update behavior](https://github.com/AppImage/appimage.github.io#how-to-submit-appimages-to-the-catalog)
