# B47ANCE'd Earthworks

Version: `0.19.0` - development MP test source, not a stable release.

Standalone Lua-only excavation, construction and surface wear for Project Zomboid Build 42. Dig/frame/deepen/climb/backfill trenches, moats and basements, move spoil and build gravel paths. Rendering is vanilla; fluid simulation, custom cutaways and retained underground surface views are unavailable. Experimental wheelbarrow pushing remains SP-only and unavailable in dedicated MP.

- Mod ID: `B47ANCEDEarthworks`; Workshop item: `3788591561`.
- No required external mods. Enable only Earthworks for the first dedicated baseline.
- Authoritative runtime: `src/B47ANCEDEarthworks/42`; root VERSION is canonical.
- Retained API/save/sandbox namespace: `groundWorks`; Consumer API: 3.

CAT integrations and the CAT-only Knowledge & Wisdom requirement are removed. No vehicle providers, machine cargo bridge or manual issuance is bundled. Existing terrain/job/route schemas and saved markers are preserved. Generic provider APIs still require explicit server-side registration and validation; there is no automatic vehicle fallback. The machine-only concrete-road definition is retained for saved metadata, with no manual start option or automatic conversion.

Dedicated server plus two clients is the first native target; SP acceptance is optional, never a prerequisite. Native dedicated NOT TESTED; G7 and stable G8 BLOCKED. A prepared ZIP or green CI is offline evidence only. The separate Knowledge & Wisdom storage repair is not required to load standalone Earthworks.

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

Python with `pip install -r requirements-dev.txt` supplies Lupa 2.6 / Lua 5.1. The source suite compiles runtime Lua, runs ten selected self-contained Lua regressions and mocked excavation/route contracts. It is not the full historical suite or native API proof. [Exact validation/evidence](docs/VALIDATION_CURRENT.md).

The [dedicated test kit](docs/DEDICATED_TESTING.md) contains a deterministic Earthworks-only ZIP, no-dependency lock, commit/source/archive manifest, checklist and blank results template. Build outputs stay in ignored dist; different existing output is preserved. Successful preflight exits 0 with READY_FOR_NATIVE_TEST, while native G7/G8 remain blocked. The tool does not install mods, edit server configuration, launch processes or upload anything.

[Public repository](https://github.com/B47ANCE/B47ANCEDEarthworks), [version policy](docs/VERSION_POLICY.md), [source inventory](docs/SOURCE_INVENTORY.json), [architecture](docs/ARCHITECTURE_CURRENT.md), [sandbox configuration](docs/CONFIGURATION.md), [compatibility](docs/COMPATIBILITY.md), [reviewed overview](docs/MOD_OVERVIEW.json). Historical packages/reports, retired Java evidence and previous dependency locks retain their original versions/hashes outside current inputs. Optional weather/heavy-object consumers retain their existing declared contracts and are not part of the minimal baseline.
