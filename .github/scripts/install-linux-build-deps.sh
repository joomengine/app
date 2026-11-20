#!/usr/bin/env bash
# Use the runner’s signed distribution archives, including its security pocket.
set -euo pipefail
source /etc/os-release
if [[ $ID != ubuntu || ( $VERSION_CODENAME != noble && $VERSION_CODENAME != resolute ) ]]; then
  echo "The Linux CI dependency list targets Ubuntu 24.04 and 26.04." >&2
  exit 1
fi
sources=$(mktemp --suffix=.list)
trap 'rm -f -- "$sources"' EXIT
chmod 0644 "$sources"
apt_options=(
  -o "Dir::Etc::sourcelist=$sources" -o Dir::Etc::sourceparts=-
  -o Acquire::Languages=none -o Acquire::Retries=2
  -o Acquire::https::Timeout=25 -o APT::Update::Error-Mode=any
)
packages=(ca-certificates cmake g++ pkg-config xvfb xauth xdotool x11-utils "$@")
# The hosted image's proxy has returned HTTP 503 for package files even after
# retrieving signed indexes. All mirrors must serve the same signed Ubuntu
# release, including security updates, with Ubuntu's installed archive key.
for mirror in https://archive.ubuntu.com/ubuntu https://mirrors.edge.kernel.org/ubuntu https://mirrors.mit.edu/ubuntu; do
  echo "Installing Linux dependencies from $mirror"
  for suite in "$VERSION_CODENAME" "$VERSION_CODENAME-updates" "$VERSION_CODENAME-security"; do
    printf 'deb [signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] %s %s main universe\n' "$mirror" "$suite"
  done > "$sources"
  if ! sudo apt-get "${apt_options[@]}" update; then continue; fi
  if sudo apt-get "${apt_options[@]}" install -y --no-install-recommends "${packages[@]}"; then exit 0; fi
done
echo "Unable to install the native build dependencies from the Ubuntu archive mirrors." >&2
exit 1
