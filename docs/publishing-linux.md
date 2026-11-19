# Publish JoomEngine for Linux

The desktop workflow publishes the tested Linux packages and their SHA-256 checksums on GitHub. Store registration is independent. Enable the channels you maintain after completing their setup. The publisher reads the files back from the completed, versioned GitHub Release and verifies their checksums. The AUR builds from that version's source tag. [GitHub Releases](https://github.com/joomengine/joomengine/releases) · [Linux publication workflow](../.github/workflows/linux-publish.yml)

Choose one route for entering the settings. The **browser route** below uses GitHub Settings and copy/paste. For the **command-line route**, complete [GitHub CLI setup](publishing.md#github-cli-setup) once, then jump to [Snap commands](#snap-store-from-the-command-line), [Debian and Fedora commands](#debian-and-fedora-from-the-command-line), or [Arch commands](#aur-from-the-command-line). Both routes use the same scopes and names in the table below.

## GitHub settings in the browser

Sign in to GitHub in your browser with access to manage this repository's settings. Each publisher uses the following two pages.

1. Open **Settings → Environments**, select **distribution**, or choose **New environment** and enter `distribution` if it does not yet exist. Under **Deployment branches and tags**, choose **Selected branches and tags** and add a **tag** rule for `v*`. [Open JoomEngine environments](https://github.com/joomengine/joomengine/settings/environments)
2. On the **distribution** page, under **Environment secrets**, click **Add secret**. Enter the exact **Name** from the table, paste its credential in **Value**, and click **Add secret**. To rotate an existing secret, use its edit button and replace its value. Under **Environment variables**, use **Add variable**, enter the **Name** and **Value**, then click **Add variable**. [Open JoomEngine environments](https://github.com/joomengine/joomengine/settings/environments)
3. For each switch, open **Settings → Secrets and variables → Actions → Variables**. Click **New repository variable**, enter the switch in **Name**, enter the lowercase text `true` in **Value**, and click **Add variable**. Enable the switch after its channel's credentials and settings are saved. GitHub evaluates these switches before attaching the environment. [Open JoomEngine repository variables](https://github.com/joomengine/joomengine/settings/variables/actions)

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

4. Open **snap-login.txt** in a local plain-text editor. Use **Select All → Copy**. The **entire exported file** is the secret value. Preserve its encoding and line breaks exactly as generated. In GitHub, open **Settings → Environments → distribution → Environment secrets → Add secret**. Enter `SNAPCRAFT_STORE_CREDENTIALS` in **Name**, paste into **Value**, and click **Add secret**. If replacing a stable-only credential, edit the existing secret and paste the newly exported contents. [Open JoomEngine environments](https://github.com/joomengine/joomengine/settings/environments)
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

Register the snap under the correct publisher and request its interface approvals as described in steps 1–2 above. Complete the [GitHub CLI setup](publishing.md#github-cli-setup) with an administrator account. It confirms your GitHub login and explains how to create the `distribution` environment exists while preserving existing deployment approvals and tag rules.

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

## Debian APT and Fedora RPM

Both jobs can use one public Cloudsmith repository. Cloudsmith hosts and signs the APT/RPM repository metadata and provides repository-specific installation instructions. The Debian job uploads the Debian 13 (trixie) amd64 build. The RPM job uploads the Fedora 44 x86-64 build.

1. Sign in to Cloudsmith, create or select a workspace, and create a **public** package repository. In that repository open **Push/Pull Packages**. Its upload destination identifies the workspace slug and repository slug. Keep duplicate-version replacement disabled to preserve existing releases. [Cloudsmith login](https://app.cloudsmith.com/login) · [Workspaces](https://app.cloudsmith.com/workspaces) · [Package upload](https://docs.cloudsmith.com/artifact-management/package-upload)
2. Open the workspace's **Accounts → Services**, create a release service account, and copy its API key when Cloudsmith displays it. Under the repository's **Settings → Access control**, grant this service **Write** access to the package repository. [Service accounts](https://docs.cloudsmith.com/accounts-and-teams/service-accounts) · [Repository privileges](https://docs.cloudsmith.com/repositories/repository-privileges)
3. Open GitHub **Settings → Environments → distribution**. Under **Environment secrets → Add secret**, enter `CLOUDSMITH_API_KEY` in **Name**, paste the complete service API key in **Value**, and save. Clear the clipboard. Under **Environment variables → Add variable**, add `CLOUDSMITH_NAMESPACE` with the workspace slug and `CLOUDSMITH_REPOSITORY` with the repository slug. Save each variable separately. Both package jobs use these same three entries. [Open JoomEngine environments](https://github.com/joomengine/joomengine/settings/environments)
4. Under **Actions → Variables → New repository variable**, add `DEBIAN_REPO_PUBLISH` with value `true` for APT, `RPM_REPO_PUBLISH` with value `true` for RPM, or both as separate entries. [Open JoomEngine repository variables](https://github.com/joomengine/joomengine/settings/variables/actions)
5. After a tagged release, open the Cloudsmith repository's **Packages** view and verify the package is synced in `debian/trixie` or `fedora/44`. Its Cloudsmith tag contains its GitHub release digest. A repeated upload recognizes an already synced package. You can inspect and resync a failed upload in this same view. [Cloudsmith package management](https://docs.cloudsmith.com/artifact-management/package-upload)
6. Open **Push/Pull Packages → Debian** or **RPM** in the repository. Copy its public setup URL and signing-key fingerprint into your announcement. On a clean system follow those signed-repository instructions, then use `sudo apt update && sudo apt install joomengine` on Debian or `sudo dnf install joomengine` on Fedora. [APT setup and signing](https://docs.cloudsmith.com/formats/debian-repository) · [RPM setup and signing](https://docs.cloudsmith.com/formats/redhat-repository)

### Debian and Fedora from the command line

Create the public Cloudsmith repository and grant its release service account **Write** as described in steps 1–2 above. Have its API key ready, and complete the [GitHub CLI setup](publishing.md#github-cli-setup). From an interactive Bash terminal, enter the two public slugs when prompted. When `gh secret set` prompts for the secret, paste the Cloudsmith service API key and press Enter. The value goes directly to the hidden secret prompt. Choose the formats you want to enable.

```bash
(
  set -euo pipefail
  repo=joomengine/joomengine
  gh api --silent "repos/$repo/environments/distribution"
  read -r -p 'Cloudsmith workspace slug: ' workspace
  read -r -p 'Cloudsmith public repository slug: ' packages
  [[ "$workspace" =~ ^[a-zA-Z0-9_-]+$ && "$packages" =~ ^[a-zA-Z0-9_-]+$ ]]
  read -r -p 'Enable which package feeds (deb, rpm, or both)? ' feeds
  case "$feeds" in deb|rpm|both) ;; *) echo "Choose deb, rpm, or both." >&2; exit 1 ;; esac
  gh secret set CLOUDSMITH_API_KEY --repo "$repo" --env distribution
  gh variable set CLOUDSMITH_NAMESPACE --repo "$repo" --env distribution --body "$workspace"
  gh variable set CLOUDSMITH_REPOSITORY --repo "$repo" --env distribution --body "$packages"
  if [[ "$feeds" == deb || "$feeds" == both ]]; then
    gh variable set DEBIAN_REPO_PUBLISH --repo "$repo" --body true
    gh api "repos/$repo/actions/variables/DEBIAN_REPO_PUBLISH" --jq .value
  fi
  if [[ "$feeds" == rpm || "$feeds" == both ]]; then
    gh variable set RPM_REPO_PUBLISH --repo "$repo" --body true
    gh api "repos/$repo/actions/variables/RPM_REPO_PUBLISH" --jq .value
  fi
  gh secret list --repo "$repo" --env distribution
  gh api "repos/$repo/environments/distribution/variables/CLOUDSMITH_NAMESPACE" --jq .value
  gh api "repos/$repo/environments/distribution/variables/CLOUDSMITH_REPOSITORY" --jq .value
)
```

Check the two returned slugs, the service key's name, and a `true` result for each selected feed. The other feed retains its previous setting. Confirm the synced package in Cloudsmith after the next tagged release. [Cloudsmith workspaces](https://app.cloudsmith.com/workspaces)

### Official distribution archives

Debian's archive accepts reviewed source packages. A Debian maintainer checks for an existing package or request, files an Intent To Package, prepares a Debian Policy-compliant source package for unstable, uploads it to mentors if sponsorship is needed and files a Request For Sponsorship. A sponsor submits it to the Debian NEW queue for archive review. No GitHub credential grants this admission. [Debian WNPP](https://www.debian.org/devel/wnpp/) · [Debian Mentors](https://mentors.debian.net/intro-maintainers/) · [Debian new package procedures](https://www.debian.org/doc/manuals/developers-reference/pkgs.en.html#new-packages)

Fedora's official repositories use a separate package review, sponsorship and Fedora build/submission process. Publishing the RPM to GitHub or Cloudsmith gives users immediate installation routes while a Fedora packager pursues inclusion. [Fedora package review](https://docs.fedoraproject.org/en-US/package-maintainers/Package_Review_Process/)

## Arch User Repository

GitHub hosts a ready-made pacman binary. The AUR publishes a source build recipe and its `.SRCINFO` metadata. The publishing job regenerates both for the exact version, pins the tag archive's SHA-256 and fast-forwards the AUR repository. Upgrading a community package into an official Arch repository is a separate Arch packaging-team decision. [AUR submission guidelines](https://wiki.archlinux.org/title/AUR_submission_guidelines)

1. Register an AUR maintainer account. Search for **joomengine** before the first upload. If someone already maintains the package, obtain co-maintainer access or follow the AUR adoption process. For an available name the first accepted push creates the package. [AUR registration](https://aur.archlinux.org/register) · [AUR search](https://aur.archlinux.org/packages?K=joomengine)
2. Generate a dedicated Ed25519 key in a private temporary directory on a Linux workstation. Collect the AUR server's public host key and display its fingerprint. The commands display public fingerprints and open the directory in your file manager. Compare the fingerprint with the current Ed25519 fingerprint on the AUR home page before using the collected host key. [AUR home and SSH fingerprints](https://aur.archlinux.org/)

   ```bash
   key_dir=$(mktemp -d)
   ssh-keygen -t ed25519 -N '' -C 'JoomEngine AUR releases' -f "$key_dir/aur"
   ssh-keyscan -t ed25519 aur.archlinux.org > "$key_dir/aur_known_hosts"
   ssh-keygen -lf "$key_dir/aur_known_hosts" -E sha256
   xdg-open "$key_dir"
   ```

3. Open **aur.pub** in a local plain-text editor, copy its single public key line, and add it in the AUR account under **My Account → SSH Public Key**. Save the account settings. The corresponding file named **aur** holds the private key used by GitHub. [AUR account](https://aur.archlinux.org/)
4. In the editor, open **aur**, select all and copy its complete contents, including the `BEGIN OPENSSH PRIVATE KEY` and `END OPENSSH PRIVATE KEY` lines and the original line breaks. In GitHub **Settings → Environments → distribution → Environment secrets → Add secret**, enter `AUR_SSH_PRIVATE_KEY` in **Name**, paste into **Value**, and save. Close the editor and clear the private key from the clipboard and clipboard history. [Open JoomEngine environments](https://github.com/joomengine/joomengine/settings/environments)
5. In **distribution → Environment variables → Add variable**, create `AUR_KNOWN_HOSTS`. Open **aur_known_hosts** in the editor and paste its verified full `aur.archlinux.org ssh-ed25519 …` host-key line into **Value**. Add a second environment variable named `AUR_MAINTAINER_EMAIL` with the public maintainer contact email you want displayed on AUR commits. [Open JoomEngine environments](https://github.com/joomengine/joomengine/settings/environments)
6. Verify that the private-key name appears under **Environment secrets** and the host key and email under **Environment variables**. After saving, remove the workstation's temporary files in the original terminal.

   ```bash
   rm -- "$key_dir/aur" "$key_dir/aur.pub" "$key_dir/aur_known_hosts"
   rmdir -- "$key_dir"
   ```

7. Under **Actions → Variables → New repository variable**, add `AUR_PUBLISH` with value `true`. After a tagged release check the version on the AUR package page. [Open JoomEngine repository variables](https://github.com/joomengine/joomengine/settings/variables/actions) · [AUR package records](https://aur.archlinux.org/packages?K=joomengine)

### AUR from the command line

Register or obtain co-maintainer access on the AUR and complete [GitHub CLI setup](publishing.md#github-cli-setup). Obtain the current **Ed25519** fingerprint from the AUR home page independently of the SSH connection. Run this block in an interactive Bash terminal. Enter the absolute path to the private key already authorized for the package, or press Enter to create a dedicated key. For a new key, the block prints its **public** line and pauses while you save it under the AUR account's **My Account → SSH Public Key**. [AUR registration](https://aur.archlinux.org/register) · [AUR host fingerprints](https://aur.archlinux.org/)

```bash
(
  set -euo pipefail
  umask 077
  repo=joomengine/joomengine
  gh api --silent "repos/$repo/environments/distribution"
  key_dir=$(mktemp -d)
  trap 'rm -rf -- "$key_dir"' EXIT
  read -r -p 'Existing AUR private key (absolute path, or Enter to generate): ' private_key
  if [[ -z "$private_key" ]]; then
    private_key="$key_dir/aur"
    ssh-keygen -q -t ed25519 -N '' -C 'JoomEngine AUR releases' -f "$private_key"
    cat "$private_key.pub"
    read -r -p 'Press Enter after adding this public key to the AUR account. ' _
  fi
  # A non-interactive CI login requires a private key usable without a passphrase.
  ssh-keygen -y -P '' -f "$private_key" > /dev/null
  read -r -p 'Verified Ed25519 SHA256 fingerprint from the AUR home page: ' approved
  ssh-keyscan -T 10 -t ed25519 aur.archlinux.org | sort -u > "$key_dir/known_hosts"
  fingerprint=$(ssh-keygen -lf "$key_dir/known_hosts" -E sha256 | awk '{print $2}' | sort -u)
  [[ -n "$approved" && "$fingerprint" == "$approved" ]] || { echo "AUR host key verification failed." >&2; exit 1; }
  read -r -p 'Public AUR Git maintainer email: ' maintainer
  [[ "$maintainer" == ?*@?* ]]
  gh secret set AUR_SSH_PRIVATE_KEY --repo "$repo" --env distribution < "$private_key"
  gh variable set AUR_KNOWN_HOSTS --repo "$repo" --env distribution < "$key_dir/known_hosts"
  gh variable set AUR_MAINTAINER_EMAIL --repo "$repo" --env distribution --body "$maintainer"
  gh variable set AUR_PUBLISH --repo "$repo" --body true
  gh secret list --repo "$repo" --env distribution
  gh api "repos/$repo/environments/distribution/variables/AUR_MAINTAINER_EMAIL" --jq .value
  gh api "repos/$repo/environments/distribution/variables/AUR_KNOWN_HOSTS" --jq .value | ssh-keygen -lf - -E sha256
  gh api "repos/$repo/actions/variables/AUR_PUBLISH" --jq .value
)
```

Check the saved key's **name**, public email, AUR host fingerprint and `true` switch. The temporary directory is removed at the end. An existing private key selected from elsewhere stays in its original location. The next tagged release sends the source recipe and its metadata to the AUR.

## Flatpak and Flathub

Tagged builds publish an installable Flatpak bundle to GitHub. Flathub hosts its own build and review infrastructure. For an official listing:

1. A project maintainer with a GitHub account and two-factor authentication must independently author the Flathub manifest. Flathub prohibits AI-assisted manifests and automated submission PRs. The GitHub bundle uses AI-assisted packaging. Disclose the affected application code, documentation and packaging and their approximate extent as required. Review Flathub's desktop integration and project-history criteria. Explain the native workspace windows, download and file handling, and saved Joomla projects. Acceptance is decided by Flathub. [Submission requirements](https://docs.flathub.org/docs/for-app-authors/requirements)
2. Use the project-controlled app ID `org.joomengine.app`. Test the human-authored manifest with the Flathub builder and linter. Fork the Flathub repository including the `new-pr` branch, branch from it, and open the submission against `flathub/flathub:new-pr`. The maintainer handles the submission and reviewer correspondence. After approval, accept the invitation to the app repository. [Flathub submission](https://docs.flathub.org/docs/for-app-authors/submission) · [Flathub repository](https://github.com/flathub/flathub/tree/new-pr)
3. In that app repository the maintainer can configure `x-checker-data` for stable JoomEngine release sources. Flathub's external data checker opens version updates. Review its test build and merge the update to trigger the official build and publication. This route uses Flathub's infrastructure and needs no Flathub token in the JoomEngine repository. [Flathub updates](https://docs.flathub.org/docs/for-app-authors/maintenance)
4. Sign into the Flathub developer dashboard and select the app to verify ownership. For the domain-file verification method, place the supplied token at `https://joomengine.org/.well-known/org.flathub.VerifiedApps.txt`. [Flathub developer dashboard](https://flathub.org/apps/mine) · [Verification](https://docs.flathub.org/docs/for-app-authors/verification)

## AppImageHub and the Linux archive

GitHub hosts both the AppImage and the Linux tar archive. Neither requires store credentials. Once the first public versioned release includes the AppImage, a maintainer may submit a one-line file named `data/JoomEngine` containing `https://github.com/joomengine/joomengine` to the AppImageHub catalog. Reviewers exercise the package on their baseline Linux image and decide inclusion. Using the repository URL lets the catalog discover subsequent AppImages through GitHub Releases. [Submit to AppImageHub](https://github.com/AppImage/appimage.github.io/new/master/data) · [Catalog requirements and update behavior](https://github.com/AppImage/appimage.github.io#how-to-submit-appimages-to-the-catalog)
