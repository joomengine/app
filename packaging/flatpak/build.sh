#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
root=$(git rev-parse --show-toplevel)
work=${RUNNER_TEMP:?}/joomengine-flatpak
app=org.joomengine.app
base=io.qt.qtwebengine.BaseApp
branch=6.11
arch=x86_64
flathub=https://dl.flathub.org/repo/flathub.flatpakrepo
mkdir -p "$work/source" "$root/dist/packages" "$root/dist/flatpak-source"
# The manifest's local source is the exact commit being tested. Build outputs,
# SDK caches and developer files stay outside the application source tree.
git -C "$root" archive HEAD | tar -x -C "$work/source"
cd "$work"
manifest="$work/source/packaging/flatpak/$app.json"
# The compiler and base app go into a separate installation. Launch tests
# below use the ordinary user's installation, as on a new desktop.
export FLATPAK_USER_DIR
FLATPAK_USER_DIR=$(mktemp -d "$work/sdk-installation.XXXXXX")
flatpak remote-add --user --if-not-exists flathub "$flathub"
flatpak install --user --noninteractive --assumeyes flathub \
  "org.kde.Platform//$branch" "org.kde.Sdk//$branch" "$base//$branch"
flatpak install --user --noninteractive --assumeyes --no-deps --no-related flathub \
  "$base.Sources//$branch"

# Flathub records the upstream Git revision in the subject of both OSTree
# commits. A mirror update between downloads must never pair unrelated builds.
repo="$FLATPAK_USER_DIR/repo"
base_commit=$(flatpak info --user --show-commit "$base//$branch")
source_commit=$(flatpak info --user --show-commit "$base.Sources//$branch")
revision() {
  ostree show --repo="$repo" "$1" | sed -nE 's/^.*\(([a-f0-9]{12,40})\)$/\1/p'
}
base_git=$(revision "$base_commit")
source_git=$(revision "$source_commit")
if [[ ! "$base_git" =~ ^[a-f0-9]{12,40}$ || "$source_git" != "$base_git" ]]; then
  echo "Qt WebEngine and source extension have different upstream revisions: $base_git / $source_git" >&2
  exit 1
fi
base_files=$(flatpak info --user --show-location "$base//$branch")/files
source_files=$(flatpak info --user --show-location "$base.Sources//$branch")/files
test -s "$base_files/manifest.json"
for section in downloads git manifest; do test -d "$source_files/$section"; done
cat > "$work/source/packaging/flatpak/source-revision.txt" <<TEXT
Upstream base manifest and patches: https://github.com/flathub/$base/tree/$base_git
Base app: app/$base/$arch/$branch $base_commit
Corresponding sources: runtime/$base.Sources/$arch/$branch $source_commit
TEXT
tar -C "$source_files" -cf - . | gzip -1 > "$root/dist/flatpak-source/QtWebEngine-Flatpak-$branch-${arch}-Sources.tar.gz"
# Copy the base's fully resolved manifest before flatpak-builder writes the app manifest.
cp "$base_files/manifest.json" "$work/source/packaging/flatpak/base-manifest.json"
jq '.branch = "qa" | .modules[0]."config-opts" += ["-DJOOMENGINE_NATIVE_QA=ON"]' \
  "$manifest" > "$work/source/packaging/flatpak/qa.json"
build() {
  flatpak-builder --user --force-clean --disable-rofiles-fuse --repo="$work/repo" "$work/builddir" "$1"
}
build "$manifest"
version=$(cat "$root/VERSION")
flatpak build-bundle --arch="$arch" --runtime-repo="$flathub" "$work/repo" \
  "$root/dist/packages/JoomEngine-$version-$arch.flatpak" "$app" stable
# Only the production bundle goes into dist. The instrumented build uses
# the same sandbox, runtime, finish arguments and source revision.
build "$work/source/packaging/flatpak/qa.json"
# All deliverables now live outside this disposable SDK installation. Free
# space before Flatpak provisions the end user's runtime from the bundle.
rm -rf -- "$FLATPAK_USER_DIR"
unset FLATPAK_USER_DIR
# A single command must discover Flathub, install the KDE runtime and put
# JoomEngine in the app menu. There is no manual remote-add for this install.
if [[ -n $(flatpak remotes --user --columns=name) ]] || flatpak info "org.kde.Platform//$branch" >/dev/null 2>&1; then
  echo "The clean-install check needs a user with no Flatpak remotes or installed KDE runtime." >&2
  exit 1
fi
flatpak install --user --noninteractive --assumeyes "$root/dist/packages/JoomEngine-$version-$arch.flatpak"
flatpak info --user "org.kde.Platform//$branch"
flatpak info --user "$app//stable"
flatpak remote-add --user --if-not-exists --no-gpg-verify joomengine-ci "$work/repo"
flatpak install --user --noninteractive --assumeyes joomengine-ci "$app//qa"
