"""Offline Lua compilation and selected standalone regressions; no PZ runtime.

The full historical host suite needs its old positional-argument runner and
cross-project fixtures. This entry point does not claim that coverage.
"""
import json
from pathlib import Path
import sys

from lupa.lua51 import LuaRuntime


STANDALONE_TESTS = (
    "test_api.lua", "test_load.lua", "test_machine_projects.lua",
    "test_precipitation_cleaning.lua", "test_spoil_exchange.lua",
    "test_surface_presentation.lua", "test_wheelbarrow_bodies.lua",
    "test_worn_surface.lua", "test_visibility.lua",
)


def main():
    root = Path(__file__).resolve().parents[1]
    base = root / "src/B47ANCEDEarthworks/42/media/lua"
    failures = {}
    files = sorted(base.rglob("*.lua"))
    if not files:
        failures["source"] = "No source Lua files found"
    for path in files:
        try:
            LuaRuntime().execute("assert(loadstring(...))", path.read_text(encoding="utf-8-sig"), str(path))
        except Exception as error:
            failures[path.relative_to(root).as_posix()] = str(error)
    passed = []
    for name in STANDALONE_TESTS:
        lua = LuaRuntime()
        lua.globals().package.path = ";".join((base / side / "?.lua").as_posix() for side in ("shared", "server", "client")) + ";" + lua.globals().package.path
        lua.execute("print=function()end")
        try:
            lua.execute((root / "tests" / name).read_text(encoding="utf-8-sig"))
            passed.append(name)
        except Exception as error:
            failures[name] = str(error)
    print(json.dumps({
        "status": "FAIL" if failures else "PASS",
        "environment": "offline Lua 5.1 via lupa; no PZ runtime",
        "source_files_compiled": len(files) - sum(key.startswith("src/") for key in failures),
        "standalone_tests_passed": passed,
        "full_historical_suite": "NOT RUN",
        "failures": failures,
    }, indent=2))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
