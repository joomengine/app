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
elif [[ $GITHUB_REF == "refs/tags/v$version" ]]; then
  tag="v$version"
  title="JoomEngine $version"
  create_options=(--verify-tag)
  edit_options=()
else
  echo "Unsupported release ref: $GITHUB_REF" >&2
  exit 1
fi

dir=$(realpath "$1")
notes=$(mktemp)
existing=$(mktemp)
trap 'rm -f "$notes" "$existing"' EXIT
python3 scripts/release_notes.py "$tag" > "$notes"

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
