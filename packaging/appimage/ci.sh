#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname "$0")/../.."
repo=$PWD
sdk="$RUNNER_TEMP/qt-linux-sdk"
export QT_NOTICE_CACHE="$RUNNER_TEMP/qt-notices"
.github/scripts/install-linux-build-deps.sh binutils dbus-x11 desktop-file-utils squashfs-tools \
  libegl-dev libgl-dev libopengl-dev libxkbcommon-dev libvulkan-dev libasound2t64 libgbm1 libnss3 \
  libx11-xcb1 libxcomposite1 libxdamage1 libxrandr2 libxtst6 libxkbfile1 libxkbcommon-x11-0 \
  libxcb-cursor0 libxcb-glx0 libxcb-icccm4 libxcb-keysyms1 libxcb-randr0 libxcb-shape0 \
  libxcb-sync1 libxcb-xfixes0 libxcb-xkb1 libwayland-client0 libwayland-cursor0 libwayland-egl1
if [[ ! -f "$sdk/lib/libQt6WebEngineCore.so.6.11.2" ]]; then
  bash packaging/appimage/install-sdk.sh "$sdk"
fi
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
for build in release qa; do
  flag=OFF
  if [[ $build == qa ]]; then flag=ON; fi
  cmake -S . -B "$work/build-$build" -DCMAKE_PREFIX_PATH="$sdk" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SKIP_RPATH=ON -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath-link,$sdk/lib" -DJOOMENGINE_NATIVE_QA="$flag"
  cmake --build "$work/build-$build" --parallel
done
appdir="$work/AppDir"
DESTDIR="$appdir" cmake --install "$work/build-release" --prefix /usr
python3 packaging/appimage/stage.py "$sdk" "$appdir"
# Keep the matching, relinkable Type 2 launcher sources and its patched
# filesystem dependencies with the binary (including upstream build scripts).
sources="$appdir/usr/share/doc/joomengine/AppImage/source"
mkdir -p "$sources"
while read -r digest name url; do
  curl --fail --silent --show-error --location --retry 3 --retry-all-errors "$url" --output "$sources/$name"
  (cd "$sources" && printf '%s  %s\n' "$digest" "$name" | sha256sum -c)
done < packaging/appimage/runtime-source.lock
python3 scripts/package-qt-notices.py --appimage "$appdir/usr/share/doc/joomengine"
ln -s usr/share/applications/org.joomengine.app.desktop "$appdir/org.joomengine.app.desktop"
ln -s usr/share/icons/hicolor/512x512/apps/org.joomengine.app.png "$appdir/org.joomengine.app.png"
ln -s org.joomengine.app.png "$appdir/.DirIcon"
test -s "$appdir/.DirIcon"
desktop-file-validate "$appdir/org.joomengine.app.desktop"

# A fresh runner must be able to resolve every packaged ELF without the SDK.
for file in "$appdir"/usr/bin/joomengine "$appdir"/usr/libexec/QtWebEngineProcess \
    "$appdir"/usr/plugins/*/*.so; do
  deps=$(LD_LIBRARY_PATH="$appdir/usr/lib" ldd "$file")
  if grep -E "not found|$sdk/" <<< "$deps"; then exit 1; fi
done
runtime="$work/runtime-x86_64"
curl --fail --silent --show-error --location --retry 3 --retry-all-errors \
  https://github.com/AppImage/type2-runtime/releases/download/20251108/runtime-x86_64 --output "$runtime"
chmod 0755 "$runtime"
version=$(cat VERSION)
image="$repo/dist/packages/JoomEngine-$version-x86_64.AppImage"
mkdir -p "$repo/dist/packages"
bash packaging/appimage/package.sh "$runtime" "$appdir" "$image"
install -m 0755 "$work/build-qa/joomengine" "$appdir/usr/bin/joomengine"
bash packaging/appimage/package.sh "$runtime" "$appdir" "$work/JoomEngine-QA.AppImage"

# Test the documented fixed-path launch on Ubuntu's restricted-userns desktops.
installed=/opt/joomengine/JoomEngine.AppImage
"$image" --appimage-extract-and-run --install
cmp "$image" "$installed"
desktop-file-validate /usr/local/share/applications/org.joomengine.app.AppImage.desktop
# Type 2's native extraction mode also works on systems without a FUSE device.
if [[ ! -r /dev/fuse || ! -w /dev/fuse ]]; then export APPIMAGE_EXTRACT_AND_RUN=1; fi
dbus-run-session -- xvfb-run -a scripts/check-linux-window.sh "$installed"
"$work/JoomEngine-QA.AppImage" --appimage-extract-and-run --install
cmp "$work/JoomEngine-QA.AppImage" "$installed"
dbus-run-session -- xvfb-run -a python3 test/native_smoke.py --native-file-chooser "$installed"
