# Current validation record

Version: 0.19.0

Environment: offline Windows / Python / Lupa 2.6 Lua 5.1. GitHub CI repeats portable offline checks on Linux/Python 3.12; neither is native PZ or dedicated proof. The route harness uses Lupa's default runtime. Full historical suite is NOT RUN.

Exact commands from repository root:

```sh
python scripts/check_versions.py
python scripts/check_lua_only.py
python scripts/validate_source.py
python scripts/validate_lua_source.py
python tests/test_lua_only.py
python tests/test_versioning.py
python tests/test_mp_test_build.py
python tests/run_route_work.py
python scripts/check_public_tree.py --staged
python scripts/mp_test_build.py build
python scripts/mp_test_build.py preflight --archive BUILT_ZIP
```

[TESTED offline Windows] PASS: 20 current mirrors; 77-file Lua-only source; exact-case/identity/English fallback/sandbox/Workshop checks; 68 source Lua compilations and ten selected Lua regressions; five source-gate, four version-gate and nine package tests; 25 mocked excavation contracts plus route/replay checks. The standalone regression rejects dependency imports, bundled machine providers, vehicle lookup/issuance and unavailable road-start entries while preserving saved markers. Generic explicitly validated provider tests remain. The public staged audit runs before push; remote SHA/CI are verified with the PR.

[TESTED offline Windows] Repeated builds produce identical ZIP bytes. Source digest `b53a49c1bca0e588c6d208df86d2679b36b1cf11003765f632453ad685db2965`, archive SHA-256 `c1937d96886edc68d8fdb47010718912f97fded9997fb5da3f783bd376a1e6f1`; 76 archive members (75 runtime files plus explicit common). Lock SHA-256 `fa9e74b0254ee7ff9722a7fc4eba0ca55023926e9f83aa68ef2ac9bc192e0f1a`. Preflight passes exact archive/source integrity and exits 0, with READY_FOR_NATIVE_TEST and no dependency blockers. The final ignored manifest binds its actual clean source commit/dirty state; no native PASS is implied.

Retired 0.18.0 dependency guard/provenance results and older CAT cross-project tests are historical, never current proof. Standalone Earthworks has no dependency blocker and no external runtime inputs. Native dedicated G7 BLOCKED / NOT_TESTED, stable G8 BLOCKED. SP is optional and NOT TESTED. Geometry/collision, concurrent work, inventory/spoil synchronization, privacy/trust boundaries, late join/reconnect and dedicated restart require actual evidence from the checklist. No install, server launch/change or upload was performed.
