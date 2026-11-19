#!/usr/bin/env python3
"""Compare GitHub's computed SHA-256 for every uploaded asset to the local build."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys


def verify(repo, tag, directory):
    fields = subprocess.check_output(
        ["gh", "release", "view", tag, "-R", repo, "--json", "assets"], text=True
    )
    remote = {asset["name"]: asset for asset in json.loads(fields)["assets"]}
    manifest = directory / "SHA256SUMS"
    expected = {name: digest for digest, name in
                (line.split("  ", 1) for line in manifest.read_text().splitlines())}
    expected[manifest.name] = hashlib.sha256(manifest.read_bytes()).hexdigest()
    if remote.keys() != expected.keys():
        raise ValueError(f"Unexpected or missing assets: {sorted(remote.keys() ^ expected.keys())}")
    for name, digest in expected.items():
        asset = remote[name]
        if asset["state"] != "uploaded" or asset["digest"] != f"sha256:{digest}":
            raise ValueError(f"GitHub did not receive the expected bytes for {name}")
    print(f"Verified {len(expected)} assets on {tag}.")


if __name__ == "__main__":
    verify(sys.argv[1], sys.argv[2], Path(sys.argv[3]))
