#!/usr/bin/env bash
set -euo pipefail
if [[ $EUID != 0 ]]; then
  echo "Run sudo ./install.sh to install JoomEngine in /opt." >&2
  exit 1
fi
source_dir=$(cd -- "$(dirname -- "$0")" && pwd)
prefix=/opt/joomengine
install -d -m 0755 "$prefix/releases" /usr/local/bin /usr/local/share/applications /usr/local/share/icons/hicolor/512x512/apps
umask 022
exec 9>"$prefix/.install.lock"
flock -x 9
previous=$(readlink -- "$prefix/current" || true)
# Build privately, then switch the complete installation in one rename.
release=$(mktemp -d "$prefix/releases/build.XXXXXXXX")
cleanup() {
  rm -f -- "$release.link"
  if [[ $(readlink -- "$prefix/current" || true) != "$release" ]]; then
    rm -rf -- "$release"
  fi
}
trap cleanup EXIT
cp -R -- "$source_dir/app/." "$release/"
# The Linux distribution needs only regular files and directories. Reject
# links to resources in the user's extraction directory before granting this
# install access to Chromium's user-namespace sandbox.
if [[ -n $(find "$release" ! -type d ! -type f -print -quit) ]]; then
  echo "The Linux payload contains a link or special file." >&2
  exit 1
fi
chmod -R a-s,go-w "$release"
chmod 0755 "$release"
test -x "$release/joomengine"
if [[ -e /proc/sys/kernel/apparmor_restrict_unprivileged_userns ]]; then
  install -m 0644 "$source_dir/joomengine.apparmor" /etc/apparmor.d/joomengine
  apparmor_parser -r /etc/apparmor.d/joomengine
fi
install -m 0644 "$source_dir/joomengine.png" /usr/local/share/icons/hicolor/512x512/apps/joomengine.png
install -m 0644 "$source_dir/joomengine.desktop" /usr/local/share/applications/joomengine.desktop
ln -sfnT "$prefix/current/joomengine" /usr/local/bin/joomengine
ln -s "$release" "$release.link"
mv -Tf -- "$release.link" "$prefix/current"

# Keep the previous release available to processes finishing an upgrade.
for older in "$prefix"/releases/build.*; do
  if [[ -d $older && $older != "$release" && $older != "$previous" ]]; then
    rm -rf -- "$older"
  fi
done
echo "Installed JoomEngine. Start it from the applications menu or run joomengine."
