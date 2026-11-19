#!/usr/bin/env python3
"""Stage the notices and matching open-source Qt release for the macOS DMGs."""

import argparse
import hashlib
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tarfile
import tempfile
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parents[1]
QT = "6.11.2"
SOURCE = f"qt-everywhere-src-{QT}.tar.xz"
URL = f"https://download.qt.io/archive/qt/6.11/{QT}/single/{SOURCE}"
# Published at the archive URL plus ".sha256".
SHA256 = "6dcfbca271d76a6502741a2c0dc6fc98ef7dd0b7b4cfd0abcebb285a86a26f33"
NOTICES = f"Qt-{QT}-notices.zip"
LEGAL_NAME = re.compile(r"(?:^|[._-])(?:licen[cs]es?|copying|copyrights?|notices?|attributions?|credits|authors|patents)(?:$|[._-])", re.I)
# Qt attribution JSON and Chromium's README.chromium also reference these
# filenames in this source release, in addition to the usual LICENSE files.
EXTRA_LICENSES = {
    "qt3d/examples/qt3d/exampleresources/assets/cubemaps/miramar/README.TXT",
    "qtbase/src/3rdparty/wayland/protocols/appmenu/LGPL-2.1-or-later.txt",
    "qtwayland/src/3rdparty/protocol/ivi/MIT.txt",
    "qtwebengine/src/3rdparty/chromium/third_party/freetype/src/docs/FTL.TXT",
    "qtwebengine/src/3rdparty/chromium/third_party/wtl/Ms-PL.txt",
}


def digest(path):
    with path.open("rb") as handle:
        result = hashlib.sha256()
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def get_source(directory, copy_override=False):
    directory.mkdir(parents=True, exist_ok=True)
    result = directory / SOURCE
    override = os.environ.get("QT_SOURCE_ARCHIVE")
    if override:
        provided = Path(override)
        if digest(provided) != SHA256:
            raise ValueError(f"{provided} does not match Qt's published source checksum")
        if copy_override and provided.resolve() != result.resolve():
            shutil.copyfile(provided, result)
            return result
        return provided
    if result.exists() and digest(result) == SHA256:
        return result
    with tempfile.TemporaryDirectory(dir=directory) as temporary:
        download = Path(temporary) / SOURCE
        subprocess.run(["curl", "--fail", "--location", "--retry", "3", "--connect-timeout",
                        "30", "--max-time", "900", "--output", str(download), URL], check=True)
        if digest(download) != SHA256:
            raise ValueError(f"Invalid SHA-256 for {SOURCE}")
        download.replace(result)
    return result


def is_notice(path):
    if str(path) in EXTRA_LICENSES:
        return True
    name = path.name.lower()
    if name in {"readme.chromium", "qt_attribution.json", "reuse.toml"}:
        return True
    return bool(LEGAL_NAME.search(name) or any(s.lower() == "licenses" for s in path.parts))


def write_notice_archive(source, output):
    # Read the official source once without expanding Chromium onto the runner's disk.
    # Preserve paths so identically named licenses from different projects stay distinct.
    with subprocess.Popen(["xz", "-dc", str(source)], stdout=subprocess.PIPE) as xz:
        with tarfile.open(fileobj=xz.stdout, mode="r|", bufsize=1024 * 1024) as package:
            with ZipFile(output, "w", compression=ZIP_DEFLATED) as archive:
                for member in package:
                    package.members.clear()
                    if not member.isfile():
                        continue
                    name = PurePosixPath(member.name).relative_to(f"qt-everywhere-src-{QT}")
                    if is_notice(name):
                        info = ZipInfo(str(name))
                        info.compress_type = ZIP_DEFLATED
                        info.external_attr = 0o644 << 16
                        archive.writestr(info, package.extractfile(member).read())
        # tarfile stops at the first end marker; xz must consume any tar padding.
        while xz.stdout.read(1024 * 1024):
            pass
        if xz.wait():
            raise RuntimeError(f"Could not decompress {source}")
    with ZipFile(output) as archive:
        for required in ("qtbase/LICENSES/LGPL-3.0-only.txt", "qtwebengine/LICENSE.Chromium",
                         "qtwebengine/src/3rdparty/chromium/LICENSE"):
            archive.getinfo(required)


def install(resources):
    target = resources / "LICENSES"
    target.mkdir(parents=True, exist_ok=True)
    for name in ("GPL-3.0.txt", "LGPL-3.0.txt", "CHOC-ISC.txt"):
        shutil.copyfile(ROOT / "LICENSES" / name, target / name)
    with tempfile.TemporaryDirectory() as temporary:
        cache = Path(os.environ.get("QT_NOTICE_CACHE", temporary))
        cache.mkdir(parents=True, exist_ok=True)
        # The source hash and selection logic uniquely identify the generated data.
        cached = cache / f"{digest(Path(__file__))[:16]}-{NOTICES}"
        if not cached.exists():
            source = get_source(Path(temporary))
            with tempfile.TemporaryDirectory(dir=cache) as staging:
                generated = Path(staging) / NOTICES
                write_notice_archive(source, generated)
                generated.replace(cached)
        shutil.copyfile(cached, target / NOTICES)
    version = (ROOT / "VERSION").read_text().strip()
    (target / "Qt-macOS.txt").write_text(
        f"""This JoomEngine app dynamically links Qt {QT} under LGPLv3.
The Qt frameworks include Chromium and other third-party components under
their respective licenses. {NOTICES} contains the license texts,
copyright notices and attribution records from the upstream source release,
including optional components. Their paths identify the upstream projects.

The complete, unmodified source archive, including Chromium, is available
beside this DMG in the tagged JoomEngine release and from Qt's archive.

https://github.com/joomengine/app/releases/download/v{version}/{SOURCE}
{URL}
SHA-256  {SHA256}

You may replace Qt with an interface-compatible modified build. To rebuild
and run JoomEngine against your Qt, obtain the application source at tag
v{version}, put the modified Qt SDK's bin directory first on PATH, and run

    qt-cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
    cmake --build build --config Release
    bash scripts/package-macos.sh

The packaging script uses a local ad hoc signature when Developer ID
credentials are absent. Open the resulting disk image and copy the modified
app to Applications. Debugging and reverse engineering library modifications
are permitted.
""", encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-only", action="store_true",
                        help="copy the checksum-verified source asset into DIRECTORY for publication")
    parser.add_argument("directory", type=Path, metavar="DIRECTORY",
                        help="macOS bundle Resources directory or release source destination")
    args = parser.parse_args()
    if args.source_only:
        get_source(args.directory, copy_override=True)
    else:
        install(args.directory)
