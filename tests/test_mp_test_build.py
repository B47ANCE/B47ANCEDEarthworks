"""Deterministic package, dependency drift, integrity and blocker regressions."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import warnings
import zipfile


script = Path(__file__).resolve().parents[1] / "scripts/mp_test_build.py"
spec = importlib.util.spec_from_file_location("earthworks_mp_build", script)
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)


class DedicatedBuildTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def test_zip_is_byte_reproducible_and_contains_only_runtime_layout(self):
        files = {"42/mod.info": b"id=B47ANCEDEarthworks\n", "42/media/example.lua": b"return true\n", "info.txt": b"authoring only\n"}
        first = build.zip_bytes(build.package_entries(files))
        second = build.zip_bytes(build.package_entries(dict(reversed(list(files.items())))))
        self.assertEqual(first, second)
        archive = self.root / "test.zip"
        archive.write_bytes(first)
        build.inspect_archive(archive, build.package_entries(files))
        with zipfile.ZipFile(archive) as packed:
            self.assertIn("mods/B47ANCEDEarthworks/common/", packed.namelist())
            self.assertNotIn("mods/B47ANCEDEarthworks/info.txt", packed.namelist())
            self.assertTrue(all(item.date_time == (1980, 1, 1, 0, 0, 0) for item in packed.infolist()))

    def test_custom_java_fails_source_scan(self):
        source = self.root / "source"
        source.mkdir()
        (source / "payload.jar").write_bytes(b"not executed")
        with self.assertRaises(ValueError):
            build.source_files(source)

    def test_empty_keep_marker_is_pinned_but_hidden_payload_is_rejected(self):
        source = self.root / "source"
        source.mkdir()
        (source / ".keep").write_bytes(b"\r\n")
        self.assertIn(".keep", build.source_files(source))
        (source / ".keep").write_bytes(b"payload")
        with self.assertRaises(ValueError):
            build.source_files(source)
        (source / ".keep").write_bytes(b"")
        (source / ".env").write_bytes(b"")
        with self.assertRaises(ValueError):
            build.source_files(source)

    def test_source_content_drift_is_detectable(self):
        project = self.root / "dependency"
        source = project / "src/B47ANCEDEarthworks/42"
        source.mkdir(parents=True)
        (source / "mod.info").write_text("id=B47ANCEDEarthworks\nmodversion=0.19.0\n")
        before, _ = build.snapshot(project, build.MOD)
        (source / "changed.lua").write_text("return 1\n")
        after, _ = build.snapshot(project, build.MOD)
        self.assertNotEqual(before["source_digest"], after["source_digest"])
        self.assertIsNone(before["canonical_version"])

    def test_preflight_rejects_reintroduced_runtime_dependency(self):
        project = self.root / build.MOD
        source = project / "src" / build.MOD / "42"
        source.mkdir(parents=True)
        info = source / "mod.info"
        info.write_text("id=B47ANCEDEarthworks\nmodversion=1.2.3\n")
        lock = {"earthworks_version": "1.2.3", "dependencies": {}}
        with patch.object(build, "ROOT", project):
            build.verify_sources(lock)
            info.write_text(info.read_text() + "require=UnexpectedExternalMod\n")
            with self.assertRaisesRegex(ValueError, "must not require external"):
                build.verify_sources(lock)

    def test_unsafe_archive_members_and_duplicates_are_rejected(self):
        expected = {"mods/B47ANCEDEarthworks/42/mod.info": b"id=B47ANCEDEarthworks\n"}
        for name in ("../outside.txt", "mods/B47ANCEDEarthworks/42/MOD.INFO", "unexpected.txt"):
            with self.subTest(name=name):
                path = self.root / "bad.zip"
                with zipfile.ZipFile(path, "w") as packed:
                    packed.writestr(name, b"bad")
                with self.assertRaises(ValueError):
                    build.inspect_archive(path, expected)

    def test_existing_artifact_is_never_overwritten(self):
        path = self.root / "retained.zip"
        build.write_once(path, b"original")
        build.write_once(path, b"original")
        with self.assertRaises(ValueError):
            build.write_once(path, b"replacement")
        self.assertEqual(path.read_bytes(), b"original")

    def test_duplicate_members_and_crc_damage_are_rejected(self):
        expected = {"mods/B47ANCEDEarthworks/42/mod.info": b"id=B47ANCEDEarthworks\n"}
        path = self.root / "duplicate.zip"
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            with zipfile.ZipFile(path, "w") as packed:
                for _ in range(2):
                    packed.writestr(next(iter(expected)), next(iter(expected.values())))
        with self.assertRaises(ValueError):
            build.inspect_archive(path, expected)
        raw = bytearray(build.zip_bytes(expected))
        raw[raw.index(b"id=B47ANCEDEarthworks")] ^= 1
        path.write_bytes(raw)
        with self.assertRaises(zipfile.BadZipFile):
            build.inspect_archive(path, expected)

    def test_standalone_lock_rejects_external_dependencies(self):
        import json
        path = self.root / "lock.json"
        lock = {"schema": 1, "target": "dedicated-multiplayer", "dependencies": {}}
        path.write_text(json.dumps(lock))
        self.assertEqual(build.load_lock(path)["dependencies"], {})
        lock["dependencies"]["UnexpectedExternalMod"] = {}
        path.write_text(json.dumps(lock))
        with self.assertRaises(ValueError):
            build.load_lock(path)


if __name__ == "__main__":
    unittest.main()
