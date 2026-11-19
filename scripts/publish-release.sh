#!/usr/bin/env bash
# Called only from the release job after exact-name, digest and platform checks.
set -euo pipefail
repo=${GITHUB_REPOSITORY:?}
commit=${GITHUB_SHA:?}
version=$(cat VERSION)
if [[ $GITHUB_REF == refs/heads/main ]]; then
  tag="continuous-${commit:0:12}"
  title="JoomEngine $version preview ($tag)"
  create_options=(--target "$commit" --prerelease --latest=false)
  edit_options=(--latest=false)
  channel="Preview from the main branch."
elif [[ $GITHUB_REF == "refs/tags/v$version" ]]; then
  tag="v$version"
  title="JoomEngine $version"
  create_options=(--verify-tag)
  edit_options=()
  channel="Stable release."
else
  echo "Unsupported release ref: $GITHUB_REF" >&2
  exit 1
fi

dir=$(realpath "$1")
notes=$(mktemp)
existing=$(mktemp)
trap 'rm -f "$notes" "$existing"' EXIT
cat > "$notes" <<NOTES
$channel Built from [commit ${commit:0:12}](https://github.com/$repo/commit/$commit).

Download one package for your platform and \`SHA256SUMS\` from **Assets**. The Qt source archives are separate downloads for developers.

| Platform | Package and installation |
| --- | --- |
| Linux x86-64 | [Debian 13, Arch, Fedora 44, AppImage, Flatpak, Snap or Ubuntu archive](https://github.com/$repo/blob/$commit/docs/install-linux.md) |
| Windows x64 | [Extract the portable ZIP and run JoomEngine.exe, or install a trusted signed MSIX](https://github.com/$repo/blob/$commit/docs/install-windows.md) |
| macOS | [Choose the Apple silicon or Intel DMG and drag JoomEngine to Applications](https://github.com/$repo/blob/$commit/docs/install-macos.md) |

[Verify your download](https://github.com/$repo/blob/$commit/docs/install-verify.md) · [Build and test results](https://github.com/$repo/actions/runs/$GITHUB_RUN_ID)
NOTES

if gh release view "$tag" -R "$repo" --json isDraft --jq .isDraft > "$existing"; then
  if [[ $(cat "$existing") == false ]]; then
    # A successful re-run reuses an identical published release. Existing public
    # binaries and their checksums must never be replaced behind the same URL.
    target=$(gh api "repos/$repo/commits/$tag" --jq .sha)
    [[ $target == "$commit" ]] || { echo "Tag $tag belongs to a different commit" >&2; exit 1; }
    python3 scripts/verify-release.py "$repo" "$tag" "$dir"
    exit 0
  fi
else
  gh release create "$tag" -R "$repo" --draft --title "$title" --notes-file "$notes" "${create_options[@]}"
fi

# A retry can resume an interrupted draft. Upload all assets before opening it.
gh release upload "$tag" -R "$repo" "$dir"/* --clobber
python3 scripts/verify-release.py "$repo" "$tag" "$dir"
gh release edit "$tag" -R "$repo" --draft=false --title "$title" --notes-file "$notes" "${edit_options[@]}"
