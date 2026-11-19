#!/usr/bin/env python3
"""Plan a candidate upload or reuse the same public Snap on a publication retry."""
import hashlib
import json
import os
from pathlib import Path
import sys
from urllib.error import HTTPError
from urllib.request import Request, urlopen


def publication_steps(version, digest, channels):
    latest = {
        entry["channel"]["risk"]: entry for entry in channels
        if entry["channel"]["architecture"] == "amd64"
        and entry["channel"]["track"] == "latest" and not entry["channel"].get("branch")
    }
    stable = latest.get("stable")
    if stable:
        if digest == stable["download"]["sha3-384"]:
            return False, False
        if tuple(map(int, stable["version"].split("."))) >= tuple(map(int, version.split("."))):
            raise ValueError(f"Refusing to replace stable {stable['version']} with different bytes from {version}")
    candidate = latest.get("candidate")
    return not candidate or digest != candidate["download"]["sha3-384"], True


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
    with Path(sys.argv[1]).open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha3_384").hexdigest()
    upload, promote = publication_steps(os.environ["GITHUB_REF_NAME"].removeprefix("v"), digest, channels)
    if not promote:
        print("The identical Snap is already available on latest/stable.", file=sys.stderr)
    print(f"upload={'true' if upload else 'false'}")
    print(f"promote={'true' if promote else 'false'}")


if __name__ == "__main__":
    main()
