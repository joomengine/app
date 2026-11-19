#!/usr/bin/env bash
# This clean container resolves dependencies from the actual binary package.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
case "$1" in
    debian)
        apt-get -o Acquire::Retries=3 update
        apt-get -o Acquire::Retries=3 install -y --no-install-recommends \
            /out/packages/*.deb dbus-daemon xvfb xauth xdotool fonts-dejavu-core python3
        dpkg-query -W -f='Installed ${binary:Package} ${Version}\n' joomengine
        ;;
    arch)
        pacman -Syu --noconfirm --needed dbus xorg-server-xvfb xorg-xauth xdotool ttf-dejavu python
        pacman -U --noconfirm /out/packages/*.pkg.tar.zst
        pacman -Qkk joomengine
        ;;
    fedora)
        dnf install -y /out/packages/*.rpm python3 dbus-daemon dbus-tools xorg-x11-server-Xvfb \
            xorg-x11-xauth xdotool dejavu-sans-fonts shadow-utils util-linux
        rpm -V joomengine
        ;;
    *) exit 2 ;;
esac

test -x /usr/bin/joomengine
test -f /usr/share/applications/org.joomengine.app.desktop
test -f /usr/share/icons/hicolor/512x512/apps/org.joomengine.app.png
test -f /usr/share/metainfo/org.joomengine.app.metainfo.xml
dbus-uuidgen --ensure=/etc/machine-id
useradd --create-home desktop
install -d -m 0700 -o desktop -g desktop /tmp/desktop-runtime
cd /tmp
runuser -u desktop -- env HOME=/home/desktop XDG_RUNTIME_DIR=/tmp/desktop-runtime \
    dbus-run-session -- xvfb-run -a /checkout/scripts/check-linux-window.sh /usr/bin/joomengine
runuser -u desktop -- env HOME=/home/desktop XDG_RUNTIME_DIR=/tmp/desktop-runtime \
    dbus-run-session -- xvfb-run -a python3 /checkout/test/native_smoke.py /out/qa/joomengine
