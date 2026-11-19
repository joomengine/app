#!/usr/bin/env python3
"""Compare the tested local .snap to the public amd64 latest/stable revision."""
import hashlib
import json
import os
from pathlib import Path
import sys
from urllib.error import HTTPError
from urllib.request import Request, urlopen


def should_upload(release, filename, channels):
    stable = [
        entry for entry in channels
        if entry["channel"]["architecture"] == "amd64"
        and entry["channel"]["track"] == "latest"
        and entry["channel"]["risk"] == "stable"
        and not entry["channel"].get("branch")
    ]
    if not stable:
        return True
    current, = stable
    with filename.open("rb") as stream:
        if hashlib.file_digest(stream, "sha3_384").hexdigest() == current["download"]["sha3-384"]:
            return False
    # JoomEngine's VERSION and release tags use numeric MAJOR.MINOR.PATCH.
    if tuple(map(int, current["version"].split("."))) >= tuple(map(int, release.split("."))):
        raise ValueError(f"Refusing to replace stable {current['version']} with different bytes from {release}")
    return True


def main():
    request = Request("https://api.snapcraft.io/v2/snaps/info/joomengine?architecture=amd64",
                      headers={"Snap-Device-Series": "16"})
    try:
        with urlopen(request, timeout=45) as response:
            channels = json.load(response)["channel-map"]
    except HTTPError as exc:
        if exc.code != 404:
            raise
        channels = []  # A first release has no public Store revision.
    upload = should_upload(os.environ["GITHUB_REF_NAME"].removeprefix("v"), Path(sys.argv[1]), channels)
    if not upload:
        print("The identical Snap is already available on latest/stable.", file=sys.stderr)
    print(f"upload={'true' if upload else 'false'}")


if __name__ == "__main__":
    main()
