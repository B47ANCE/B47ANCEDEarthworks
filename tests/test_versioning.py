"""Black-box checks for the canonical version gate's failure behavior."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


class VersionGateTests(unittest.TestCase):
    def setUp(self):
        self.fixture = tempfile.TemporaryDirectory()
        self.addCleanup(self.fixture.cleanup)
        self.root = Path(self.fixture.name)
        (self.root / "scripts").mkdir()
        (self.root / "docs").mkdir()
        source = Path(__file__).resolve().parents[1] / "scripts/check_versions.py"
        shutil.copy2(source, self.root / "scripts/check_versions.py")
        (self.root / "docs/VERSION_MIRRORS.json").write_text(json.dumps([
            {"path": "README.md", "pattern": "^Version: (.+)$"}
        ]), encoding="utf-8")

    def run_gate(self, canonical, mirror=None, *args):
        (self.root / "VERSION").write_text(canonical + "\n", encoding="utf-8")
        (self.root / "README.md").write_text("Version: " + (canonical if mirror is None else mirror) + "\n", encoding="utf-8")
        return subprocess.run([sys.executable, str(self.root / "scripts/check_versions.py"), *args], capture_output=True, text=True)

    def test_valid_semver_and_matching_mirror(self):
        for version in ("0.17.0", "0.17.0-dev.1", "1.0.0+build.2"):
            with self.subTest(version=version):
                self.assertEqual(self.run_gate(version).returncode, 0)

    def test_invalid_or_ambiguous_version_is_rejected(self):
        for version in ("01.17.0", "0.17", "0.17.0-01", "0.17.0\n0.18.0"):
            with self.subTest(version=version):
                self.assertNotEqual(self.run_gate(version).returncode, 0)

    def test_stale_mirror_blocks_iteration(self):
        self.assertNotEqual(self.run_gate("0.17.0", "0.16.1").returncode, 0)

    def test_source_pass_cannot_be_used_as_release_pass(self):
        result = self.run_gate("0.17.0", None, "--release")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("G8 BLOCKED", result.stderr)


if __name__ == "__main__":
    unittest.main()
