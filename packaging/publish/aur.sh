#!/usr/bin/env bash
# Advance the source recipe on the authorized AUR package's master branch.
set -euo pipefail
: "${GITHUB_REF_NAME:?}" "${RUNNER_TEMP:?}" "${AUR_MAINTAINER_EMAIL:?}"
: "${AUR_SSH_PRIVATE_KEY:?}" "${AUR_KNOWN_HOSTS:?}"
version=${GITHUB_REF_NAME#v}
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "v$version" == "$GITHUB_REF_NAME" ]]
directory=$(mktemp -d "$RUNNER_TEMP/joomengine-aur.XXXXXXXX")
trap 'rm -rf -- "$directory"' EXIT
recipe="$directory/recipe"
mkdir -m 0755 "$recipe"
source_url="https://github.com/joomengine/joomengine/archive/refs/tags/v$version.tar.gz"
curl --fail --silent --show-error --location --retry 3 "$source_url" --output "$directory/source.tar.gz"
digest=$(sha256sum "$directory/source.tar.gz")
packaging/arch/render-pkgbuild.sh "$version" "${digest%% *}" > "$recipe/PKGBUILD"
docker run --rm --volume "$recipe:/recipe:ro" archlinux:base-devel bash -euc '
  install -d -m 0755 -o nobody /tmp/aur-build
  cp /recipe/PKGBUILD /tmp/aur-build
  cd /tmp/aur-build
  runuser -u nobody -- env HOME=/tmp/aur-build makepkg --printsrcinfo
' > "$recipe/.SRCINFO"

umask 077
printf '%s\n' "$AUR_SSH_PRIVATE_KEY" > "$directory/key"
printf '%s\n' "$AUR_KNOWN_HOSTS" > "$directory/known_hosts"
unset AUR_SSH_PRIVATE_KEY
export GIT_SSH_COMMAND="ssh -i '$directory/key' -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile='$directory/known_hosts'"
git -c init.defaultBranch=master clone ssh://aur@aur.archlinux.org/joomengine.git "$directory/aur"
if [[ -s "$directory/aur/.SRCINFO" ]]; then
    old_version=$(awk '$1=="pkgver" {print $3; exit}' "$directory/aur/.SRCINFO")
    if [[ -z "$old_version" ]] || dpkg --compare-versions "$old_version" gt "$version"; then
        echo "Cannot replace AUR version '$old_version' with '$version'." >&2
        exit 1
    fi
fi
install -m 0644 "$recipe/PKGBUILD" "$recipe/.SRCINFO" "$directory/aur/"
install -m 0644 LICENSE "$directory/aur/LICENSE"
git -C "$directory/aur" add PKGBUILD .SRCINFO LICENSE
if git -C "$directory/aur" diff --cached --quiet; then
    echo "AUR already contains the recipe for $version."
    exit 0
fi
if [[ "${old_version:-}" == "$version" ]]; then
    echo "An existing recipe for $version differs. Resolve the package revision with its maintainer." >&2
    exit 1
fi
git -C "$directory/aur" -c user.name='JoomEngine maintainers' -c user.email="$AUR_MAINTAINER_EMAIL" \
    commit -m "Package JoomEngine $version"
git -C "$directory/aur" push origin HEAD:master
