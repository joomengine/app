#!/usr/bin/env bash
# Called only from the release job after exact-name, digest and platform checks.
set -euo pipefail
prepare=false
if [[ ${1:-} == --prepare-for-signing ]]; then
  prepare=true
  shift
fi
[[ $# == 1 ]] || { echo 'Usage: publish-release.sh [--prepare-for-signing] DIRECTORY' >&2; exit 2; }

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
existing=$(mktemp -d)
trap 'rm -f "$notes"; rm -rf -- "$existing"' EXIT
python3 scripts/release_notes.py "$tag" > "$notes"

if gh release view "$tag" -R "$repo" --json isDraft --jq .isDraft > "$existing/draft"; then
  if [[ $(cat "$existing/draft") == false ]]; then
    # A successful re-run reuses an identical published release. Existing public
    # binaries and their checksums must never be replaced behind the same URL.
    target=$(gh api "repos/$repo/commits/$tag" --jq .sha)
    [[ $target == "$commit" ]] || { echo "Tag $tag belongs to a different commit" >&2; exit 1; }
    if [[ $GITHUB_REF == refs/heads/main ]]; then
      # Re-running main can produce fresh build artifacts for a Store submission.
      # Keep the already published preview and verify its own public checksums.
      gh release download "$tag" -R "$repo" --pattern SHA256SUMS --dir "$existing"
      cmp <(awk '{print $2}' "$dir/SHA256SUMS" | sort) <(awk '{print $2}' "$existing/SHA256SUMS" | sort)
      python3 scripts/verify-release.py "$repo" "$tag" "$existing"
    else
      python3 scripts/verify-release.py "$repo" "$tag" "$dir"
    fi
    # A rebuilt preview can differ from the immutable public bytes. Its original
    # publication already signed those bytes. Never attest the new build as that release.
    if [[ $prepare == true ]]; then echo 'publish=false' >> "${GITHUB_OUTPUT:?}"; fi
    exit 0
  fi
else
  gh release create "$tag" -R "$repo" --draft --title "$title" --notes-file "$notes" "${create_options[@]}"
fi

if [[ $prepare == true ]]; then
  # The checked build can now be signed. A failed attestation leaves this release in draft.
  echo 'publish=true' >> "${GITHUB_OUTPUT:?}"
  exit 0
fi

# A retry can resume an interrupted draft. Upload all assets before opening it.
gh release upload "$tag" -R "$repo" "$dir"/* --clobber
python3 scripts/verify-release.py "$repo" "$tag" "$dir"
gh release edit "$tag" -R "$repo" --draft=false --title "$title" --notes-file "$notes" "${edit_options[@]}"
