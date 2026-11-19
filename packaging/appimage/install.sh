#!/usr/bin/env bash
# Install the running AppImage at a stable path that Ubuntu can name in AppArmor.
set -euo pipefail
appdir=${APPDIR:?Run the downloaded AppImage with --install}
image=${APPIMAGE:?Run the downloaded AppImage with --install}
destination=/opt/joomengine
installed=$destination/JoomEngine.AppImage
launcher=/usr/local/share/applications/org.joomengine.app.AppImage.desktop
restricted=/proc/sys/kernel/apparmor_restrict_unprivileged_userns
stage=$(mktemp -d)
candidate=
cleanup() {
  rm -rf -- "$stage"
  if [[ -n $candidate ]]; then sudo rm -f -- "$candidate"; fi
}
trap cleanup EXIT
# Perform menu editing and argument handling as the invoking user. Only writes
# to root-owned paths and loading the application-specific profile need sudo.
exec_line="Exec=$installed"
if [[ ! -r /dev/fuse || ! -w /dev/fuse ]] || { ! command -v fusermount3 >/dev/null && ! command -v fusermount >/dev/null; }; then
  exec_line+=' --appimage-extract-and-run'
fi
sed -e "s|^Exec=joomengine$|$exec_line|" -e "s|^Icon=org.joomengine.app$|Icon=$destination/joomengine.png|" \
  "$appdir/org.joomengine.app.desktop" > "$stage/launcher.desktop"
echo "Installing JoomEngine at $installed and adding it to the applications menu."
sudo install -d -m 0755 "$destination"
candidate=$(sudo mktemp "$destination/.JoomEngine.XXXXXXXX")
sudo install -m0755 -- "$image" "$candidate"
if [[ -r $restricted && $(cat "$restricted") == 1 ]]; then
  profile=/etc/apparmor.d/joomengine-appimage
  sudo install -m0644 -- "$appdir/usr/share/doc/joomengine/AppImage/joomengine.apparmor" "$profile"
  sudo apparmor_parser --replace "$profile"
fi
sudo install -m0644 -- "$appdir/org.joomengine.app.png" "$destination/joomengine.png"
sudo mv -fT -- "$candidate" "$installed"
candidate=
sudo install -Dm0644 -- "$stage/launcher.desktop" "$launcher"
echo "Installed. Open JoomEngine from the applications menu."
