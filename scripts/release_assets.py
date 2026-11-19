#!/usr/bin/env python3
"""Collect the tested downloads without accidentally releasing a QA or Store input."""
import argparse
import hashlib
from pathlib import Path
import re
import runpy
import shutil

ROOT = Path(__file__).resolve().parents[1]


def package_names(version):
    return {
        "linux-archive": f"JoomEngine-{version}-linux-x64.tar.gz",
        "linux-snap-installer": "joomengine-install-snap.sh",
        "linux-snap": f"joomengine_{version}_amd64.snap",
        "linux-deb": f"joomengine_{version}-1_amd64.deb",
        "linux-arch": f"joomengine-{version}-1-x86_64.pkg.tar.zst",
        "linux-rpm": f"joomengine-{version}-1.fc44.x86_64.rpm",
        "linux-flatpak": f"JoomEngine-{version}-x86_64.flatpak",
        "linux-appimage": f"JoomEngine-{version}-x86_64.AppImage",
        "windows-msix": f"JoomEngine-{version}-windows-x64.msix",
        "windows-portable": f"JoomEngine-{version}-windows-x64.zip",
        "macos-dmg-arm64": f"JoomEngine-{version}-macos-arm64.dmg",
        "macos-dmg-x64": f"JoomEngine-{version}-macos-x64.dmg",
        "linux-flatpak-source": "QtWebEngine-Flatpak-6.11-x86_64-Sources.tar.gz",
    }


def collect(artifacts, output, version):
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        raise ValueError(f"Output directory must be empty: {output}")
    ready = []
    for artifact, name in package_names(version).items():
        directory = artifacts / artifact
        if not directory.is_dir() or sorted(p.name for p in directory.iterdir()) != [name]:
            raise ValueError(f"Expected exactly {name} in artifact {artifact}")
        source = directory / name
        if source.is_symlink() or not source.is_file() or not source.stat().st_size:
            raise ValueError(f"Empty or invalid release asset: {source}")
        ready.append(source)
    # Validate the complete set before moving any large bundle.
    for source in ready:
        shutil.move(source, output / source.name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifacts", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    version = (ROOT / "VERSION").read_text().strip()
    if not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", version):
        parser.error("VERSION must be MAJOR.MINOR.PATCH")
    collect(args.artifacts, args.output, version)
    manifest = []
    for path in sorted(args.output.iterdir()):
        with path.open("rb") as stream:
            digest = hashlib.file_digest(stream, "sha256").hexdigest()
        manifest.append(f"{digest}  {path.name}\n")
    qt = runpy.run_path(str(ROOT / "scripts" / "package-qt-notices.py"))
    manifest.append(f"{qt['SHA256']}  {qt['SOURCE']}\n")
    (args.output / "SHA256SUMS").write_text("".join(manifest), encoding="ascii")


if __name__ == "__main__":
    main()
