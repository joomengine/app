"""Check the exact release set, checksum format and GitHub upload verification."""
import hashlib
import json
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
ASSETS = runpy.run_path(str(ROOT / "scripts" / "release-assets.py"))
VERIFY = runpy.run_path(str(ROOT / "scripts" / "verify-release.py"))["verify"]


class ReleaseAssets(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.inputs = Path(self.temp.name) / "artifacts"
        self.output = Path(self.temp.name) / "downloads"
        self.version = (ROOT / "VERSION").read_text().strip()
        self.names = ASSETS["package_names"](self.version)
        for artifact, name in self.names.items():
            folder = self.inputs / artifact
            folder.mkdir(parents=True)
            (folder / name).write_bytes(name.encode())
        # Store submission, source and QA files have different audiences.
        store = self.inputs / "microsoft-store-submission"
        store.mkdir()
        (store / "submission.msixupload").write_bytes(b"store")

    def test_complete_set_and_uploaded_digests(self):
        subprocess.run([sys.executable, ROOT / "scripts/release-assets.py", self.inputs, self.output], check=True)
        manifest = self.output / "SHA256SUMS"
        expected = {}
        for line in manifest.read_text().splitlines():
            digest, name = line.split("  ")
            expected[name] = digest
        self.assertEqual(len(expected), len(self.names) + 1)  # Also includes upstream Qt source.
        for name in self.names.values():
            self.assertEqual(expected[name], hashlib.sha256(name.encode()).hexdigest())
        self.assertFalse((self.output / "submission.msixupload").exists())
        expected[manifest.name] = hashlib.sha256(manifest.read_bytes()).hexdigest()
        assets = [{"name": n, "digest": f"sha256:{d}", "state": "uploaded"} for n, d in expected.items()]
        with patch.object(subprocess, "check_output", return_value=json.dumps({"assets": assets})):
            VERIFY("local/project", "test", self.output)
        assets[0]["digest"] = "sha256:" + "0" * 64
        with patch.object(subprocess, "check_output", return_value=json.dumps({"assets": assets})):
            with self.assertRaisesRegex(ValueError, "expected bytes"):
                VERIFY("local/project", "test", self.output)

    def test_reject_an_extra_file_in_a_release_artifact(self):
        (self.inputs / "linux-archive" / "debug.tar.gz").touch()
        with self.assertRaisesRegex(ValueError, "Expected exactly"):
            ASSETS["collect"](self.inputs, self.output, self.version)

    def test_reject_a_missing_package(self):
        (self.inputs / "linux-archive" / self.names["linux-archive"]).unlink()
        with self.assertRaisesRegex(ValueError, "Expected exactly"):
            ASSETS["collect"](self.inputs, self.output, self.version)


if __name__ == "__main__":
    unittest.main()
