#!/usr/bin/env python3
"""Generate a download table that points to the assets of this exact release."""
import os
from pathlib import Path
import sys

from release_assets import package_names


def notes(version, tag, repo, commit, run):
    packages = package_names(version)
    base = f"https://github.com/{repo}"
    assets = f"{base}/releases/download/{tag}"
    docs = f"{base}/blob/{commit}/docs"

    def file(key, label):
        return f"[{label}]({assets}/{packages[key]})"

    options = (
        ("Windows 10/11 x64", file("windows-portable", "Portable ZIP") + " · " + file("windows-msix", "MSIX"), "install-windows.md"),
        ("Mac with Apple silicon", file("macos-dmg-arm64", "Apple silicon DMG"), "install-macos.md"),
        ("Mac with Intel", file("macos-dmg-x64", "Intel DMG"), "install-macos.md"),
        ("Debian 13", file("linux-deb", "Debian package"), "install-debian.md"),
        ("Arch Linux", file("linux-arch", "Package for pacman"), "install-arch.md"),
        ("Fedora 44", file("linux-rpm", "Fedora RPM"), "install-fedora.md"),
        ("Linux with Flatpak", file("linux-flatpak", "Flatpak bundle"), "install-flatpak.md"),
        ("Linux with snapd", file("linux-snap-installer", "One-file Snap installer"), "install-snap.md"),
        ("Linux AppImage", file("linux-appimage", "AppImage"), "install-appimage.md"),
        ("Ubuntu 26.04 native archive", file("linux-archive", "Linux archive"), "install-linux-archive.md"),
    )
    preview = tag.startswith("continuous-")
    kind = "Preview" if preview else "Stable release"
    source_ref = "refs/heads/main" if preview else f"refs/tags/{tag}"
    lines = [
        f"{kind} of JoomEngine {version}. Download your package and install it directly using the guide for your computer.",
        "", "| Your computer | Download | Installation guide |", "| --- | --- | --- |",
    ]
    for platform, link, guide in options:
        lines.append(f"| {platform} | {link} | [How to install]({docs}/{guide}) |")
    lines += [
        "", f"[SHA-256 checksums]({assets}/SHA256SUMS) · [How to verify a download]({docs}/install-verify.md) · [All guides]({docs}/README.md)",
        "", "To verify the GitHub build signature, download `SHA256SUMS` and run this command in its folder. "
        "Then check your installer against the verified manifest using the guide above.",
        "", "```sh",
        f"gh attestation verify SHA256SUMS --repo {repo} --signer-workflow {repo}/.github/workflows/desktop.yml "
        f"--source-ref {source_ref} --source-digest {commit}", "```",
        "", f"[Browse the signed attestations]({base}/attestations)",
        "", f"The {file('linux-snap', 'raw Snap')} and corresponding Qt source archives are also available under **Assets**.",
        "", f"[Source commit]({base}/commit/{commit}) · [Build and test results]({base}/actions/runs/{run})",
    ]
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    print(notes(Path("VERSION").read_text().strip(), sys.argv[1], os.environ["GITHUB_REPOSITORY"],
                os.environ["GITHUB_SHA"], os.environ["GITHUB_RUN_ID"]), end="")
