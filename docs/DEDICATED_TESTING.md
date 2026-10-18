# Standalone dedicated test checklist

Version: 0.19.1

Dedicated server plus two clients is the first native target. SP acceptance is optional, never a prerequisite. The baseline enables only Mod ID B47ANCEDEarthworks; no CAT, Knowledge & Wisdom or other required mod. Use an explicitly authorized disposable dedicated installation/save and preserve backups. Build commands do not install, launch, change a server or upload to Workshop.

```sh
python scripts/check_versions.py
python scripts/check_lua_only.py
python scripts/validate_source.py
python scripts/validate_lua_source.py
python tests/test_lua_only.py
python tests/test_versioning.py
python tests/test_mp_test_build.py
python tests/run_route_work.py
python scripts/mp_test_build.py build
python scripts/mp_test_build.py preflight --archive BUILT_ZIP
```

BUILT_ZIP is the archive path printed by build. Source/lock/version and exact archive integrity failures are nonzero. With the retired dependency gates removed, successful preflight exits 0 and prints READY_FOR_NATIVE_TEST; this means prepared inputs, never gameplay acceptance. G7 stays BLOCKED / NOT TESTED and stable G8 BLOCKED until actual required dedicated evidence exists. Historical 0.18.0 exit-3 dependency results remain tied to that old lock/build.

The kit contains only Earthworks in mods/B47ANCEDEarthworks/42 plus common, its clean-commit/dirty-state/source/archive manifest, empty dependency lock, this checklist and a blank results template. Text is normalized to LF; binary assets are exact. Sorted members, fixed timestamps and attributes produce identical ZIP bytes from identical source. Different existing outputs are preserved. Use the final clean committed build; verify the manifest/archive hash on the host and both clients. Do not enable a legacy duplicate Earthworks identity. Old packages/reports retain original version/hashes and are not current test evidence.

Record exact server/client PZ versions/builds, source commit/digest, archive and lock hashes, anonymous client labels A/B, fixture/map and authoritative sandbox values. Full running version/class provenance must be verified separately from the inspected packaged artifact or Steam manifest. Keep raw logs/saves/player identifiers private; use sanitized evidence references in results.

| ID | Dedicated scenario | Required observation |
| --- | --- | --- |
| D01 | Verify identical clean standalone package and enabled IDs on server/A/B | Only Earthworks baseline; no missing external dependencies or custom Java/JAR/bridge. |
| D02 | Headless load, A/B join | No import/identity/translation errors; both receive authoritative sandbox/state. |
| D03 | One shallow hand-excavation action in a disposable cell | Server validates/mutates once; both clients agree on geometry, collision and material totals. |
| D04 | Malformed, out-of-range, raw/replayed intents using a controlled fixture | Server rejects invalid/duplicate work without mutation, extra spoil or item loss; record the fixture/response. |
| D05 | Concurrent A/B work on the same cell | Server resolves conflict; no duplicate excavation, spoil, wear or rewards. |
| D06 | Spoil bag/return, capacity, interruption and cancellation | Material conservation and synchronized inventory; no duplicate requests/items. |
| D07 | Occupied-cell backfill rejection, then allowed backfill | Unsafe action rejected; allowed geometry/material mutation occurs once. |
| D08 | Depth/climb, visibility/collision and chunk streaming | Both clients agree after leaving/returning; vanilla rendering limits remain explicit. |
| D09 | Late join and disconnect/rejoin | New/rejoining client receives existing terrain/jobs/routes without replaying completed work. |
| D10 | Graceful dedicated save/restart/rejoin | Terrain, material and route state persists once; transient actions are not replayed. |
| D11 | Disposable previous-version terrain/route fixture | Immutable keys remain readable; retired machine-only jobs are preserved and not converted or deleted. Missing fixtures mean NOT_TESTED, not PASS. |
| D12 | Vanilla-only rendering and native UI/actions | No retired bridge requirement; headless server does not require client UI; views remain state-aware. |
| D13 | Retired vehicle paths | No bundled machine provider or automatic validator fallback/manual issuance; old saved markers stay unchanged. Generic external providers are outside the standalone baseline. |
| D14 | Wheelbarrow MP boundary | Unsupported experimental pushing remains unavailable/rejected; no client-owned shared gameplay. |
| D15 | Default/nondefault server sandbox, reconnect and restart | Both clients obey the same authoritative values; existing-save behavior is recorded. |

Every case starts NOT_TESTED. Record steps, expected/actual result and sanitized evidence for PASS/FAIL/BLOCKED/NOT_TESTED. Stop affected testing on a failure. Repeat relevant cases after source/game-build changes; never promote offline mocks or old-version results to native proof. SP evidence cannot clear dedicated G7. No stable release, install or Workshop publication is authorized by a successful kit build.
