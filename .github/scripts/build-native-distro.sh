#!/usr/bin/env bash
# Runs as root in the selected distribution's disposable build container.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
version=$(cat /checkout/VERSION)
archive="joomengine-$version.tar.gz"
work=/tmp/joomengine-build
case "$1" in
    debian)
        apt-get -o Acquire::Retries=3 update
        apt-get -o Acquire::Retries=3 install -y --no-install-recommends \
            build-essential ca-certificates dpkg-dev debhelper cmake qt6-base-dev qt6-webengine-dev passwd
        ;;
    arch)
        pacman -Syu --noconfirm --needed base-devel cmake qt6-base qt6-webengine shadow
        ;;
    fedora)
        dnf install -y rpm-build redhat-rpm-config gcc-c++ make cmake ninja-build qt6-qtbase-devel \
            qt6-qtwebengine-devel desktop-file-utils shadow-utils util-linux
        ;;
    *) exit 2 ;;
esac
useradd --create-home builder
install -d -o builder -g builder "$work"
cp "/out/$archive" "$work/"
cd "$work"

case "$1" in
    debian)
        tar -xf "$archive"
        cd "joomengine-$version"
        cp -r packaging/debian debian
        sed -e "s/@VERSION@/$version/" -e "s/@DATE@/$(LC_ALL=C date -Ru -d "@$SOURCE_DATE_EPOCH")/" \
            debian/changelog.in > debian/changelog
        rm debian/changelog.in
        chown -R builder:builder "$work"
        runuser -u builder -- env DEB_BUILD_OPTIONS='noautodbgsym parallel=2' dpkg-buildpackage -b -us -uc
        pkg="../joomengine_${version}-1_amd64.deb"
        dpkg-deb --info "$pkg"
        install -m 0644 "$pkg" /out/packages/
        source_dir="$PWD"
        ;;
    arch)
        /checkout/packaging/arch/render-pkgbuild.sh "$version" "$(sha256sum "$archive" | cut -d' ' -f1)" > PKGBUILD
        chown -R builder:builder "$work"
        runuser -u builder -- makepkg --noconfirm --cleanbuild
        pkg="joomengine-$version-1-x86_64.pkg.tar.zst"
        pacman -Qip "$pkg"
        install -m 0644 "$pkg" /out/packages/
        source_dir="$work/src/joomengine-$version"
        ;;
    fedora)
        install -d -o builder -g builder "$work/rpmbuild"/{SOURCES,SPECS,BUILD,RPMS,SRPMS}
        install -m 0644 "$archive" "$work/rpmbuild/SOURCES/"
        runuser -u builder -- rpmbuild -bb --define "project_version $version" --define "_topdir $work/rpmbuild" \
            /checkout/packaging/rpm/joomengine.spec
        pkg="$work/rpmbuild/RPMS/x86_64/joomengine-$version-1.fc44.x86_64.rpm"
        rpm -qip "$pkg"
        install -m 0644 "$pkg" /out/packages/
        runuser -u builder -- tar -xf "$archive"
        source_dir="$work/joomengine-$version"
        ;;
esac

runuser -u builder -- cmake -S "$source_dir" -B "$work/build-qa" -DCMAKE_BUILD_TYPE=Release -DJOOMENGINE_NATIVE_QA=ON
runuser -u builder -- cmake --build "$work/build-qa" --parallel 2
install -m 0755 "$work/build-qa/joomengine" /out/qa/joomengine
