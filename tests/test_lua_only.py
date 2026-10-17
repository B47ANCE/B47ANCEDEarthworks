"""Exercise the source gate against forbidden dependency reintroduction."""
import importlib.util
from pathlib import Path
import tempfile
import unittest


module_path = Path(__file__).resolve().parents[1] / "scripts/check_lua_only.py"
spec = importlib.util.spec_from_file_location("earthworks_lua_only_gate", module_path)
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class LuaOnlyGateTests(unittest.TestCase):
    def setUp(self):
        self.fixture = tempfile.TemporaryDirectory()
        self.addCleanup(self.fixture.cleanup)
        self.source = Path(self.fixture.name)
        (self.source / "42").mkdir()
        (self.source / "42/mod.info").write_text("id=B47ANCEDEarthworks\nrequire=experienceWorks,CATConstruction\n", encoding="utf-8")

    def test_vanilla_engine_calls_and_assets_are_allowed(self):
        (self.source / "42/native.lua").write_text("square:RecalcAllWithNeighbours(true)\n", encoding="utf-8")
        (self.source / "icon.png").write_bytes(b"\x89PNG\r\n\x1a\n")
        self.assertEqual(gate.inspect_source(self.source)[0], [])

    def test_bridge_dependency_is_rejected(self):
        (self.source / "42/mod.info").write_text("id=B47ANCEDEarthworks\nrequire=FadedJavaLoaderBridge\n", encoding="utf-8")
        self.assertTrue(gate.inspect_source(self.source)[0])

    def test_jar_and_binding_are_rejected(self):
        (self.source / "42/companion.jar").write_bytes(b"PK\x03\x04")
        (self.source / "42/bridge.lua").write_text("luajava.bindClass('example.Companion')", encoding="utf-8")
        self.assertEqual(len(gate.inspect_source(self.source)[0]), 2)

    def test_disguised_class_or_archive_is_rejected(self):
        for signature in (b"\xca\xfe\xba\xbe", b"PK\x03\x04", b"MZ", b"\x7fELF"):
            with self.subTest(signature=signature):
                (self.source / "42/payload.png").write_bytes(signature)
                self.assertTrue(gate.inspect_source(self.source)[0])

    def test_missing_metadata_fails_closed(self):
        (self.source / "42/mod.info").unlink()
        self.assertTrue(gate.inspect_source(self.source)[0])


if __name__ == "__main__":
    unittest.main()
