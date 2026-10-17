# B47ANCE'd Earthworks

Version: `0.18.0` - development source, not a stable release.

Lua-only excavation, construction and surface wear for Project Zomboid Build 42. Dig and frame trenches, moats and basements; deepen, climb, move spoil and backfill; build routes and integrate CAT machinery. Water remains stored visual fill, not fluid flow. Wheelbarrow pushing is experimental and SP-only.

- Mod ID: `B47ANCEDEarthworks`; Workshop item: `3788591561`.
- Required Mod IDs: `B47ANCEDKnowledgeAndWisdom` and `CATConstruction`.
- Canonical version: root [VERSION](VERSION). Active runtime: `src/B47ANCEDEarthworks/42`.
- Retained API/save/sandbox namespace: `groundWorks`. Enable one package identity only.
- Rendering: vanilla; custom cutaways and retained underground surface views are unavailable.

[Public repository](https://github.com/B47ANCE/B47ANCEDEarthworks). The observed 0.16.1 source is preserved as the initial main baseline; 0.17.0 onboarding is merged on main; 0.18.0 dedicated test tooling is developed on its named feature branch with a PR before merge. No stable tags are created from unverified work.

## Current limitations

Dedicated-server/two-client testing is the first native target; SP acceptance is not a prerequisite. Native runtime is NOT TESTED for this source snapshot. Dedicated G7 is BLOCKED / NOT TESTED; stable G8 is BLOCKED. Knowledge & Wisdom 0.16.0 deliberately blocks dedicated knowledge reads/writes; CAT qualification preserves that guard. A public push or green CI is offline evidence, not gameplay certification.

CAT's matching local adapter has been updated to the new Mod IDs/imports, but its source is a separate project and is not bundled in this repository. Installed/subscribed CAT may still need that update. See [compatibility](docs/COMPATIBILITY.md) and [current status](docs/CURRENT_STATUS.md).

## Development checks

Python with `pip install -r requirements-dev.txt` supplies Lupa 2.6 and Lua 5.1. From the repository root:

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
```

The self-contained suite compiles source Lua, runs nine selected Lua regressions, validates source structure/translations and executes mocked excavation/route contracts. It does not run every inherited fixture or test real PZ APIs. Cross-project CAT tests are separate. [Validation and runtime gates](docs/VALIDATION_CURRENT.md) lists the exact scope.

[Version policy](docs/VERSION_POLICY.md), [source inventory](docs/SOURCE_INVENTORY.json), [architecture](docs/ARCHITECTURE_CURRENT.md), [sandbox configuration](docs/CONFIGURATION.md), and [onboarding provenance](docs/GITHUB_ONBOARDING.md).

Historical packages, reports, Java evidence, developer links and diagnostics remain local and are excluded from the public tree. Current diagnostic packages are generated from authoritative source using the dedicated kit below and remain outside Git. CI never deploys, uploads or connects to a game/server.

## Dedicated MP diagnostic kit

[Dedicated checklist and gates](docs/DEDICATED_TESTING.md). The reviewed [dependency lock](docs/MP_TEST_DEPENDENCIES.json) pins exact external source content; [feature overview](docs/MOD_OVERVIEW.json) separates source, foundation and blocked work.

```sh
python tests/test_mp_test_build.py
python scripts/mp_test_build.py build --knowledge-root KNOWLEDGE_PROJECT --cat-root CAT_PROJECT
python scripts/mp_test_build.py preflight --knowledge-root KNOWLEDGE_PROJECT --cat-root CAT_PROJECT --archive BUILT_ZIP
```

Builds stay inside this checkout's ignored dist directory. Each kit contains a deterministic Earthworks-only ZIP, dependency lock, provenance, dedicated checklist and blank results template. Dependencies are verified externally; CAT assets are not redistributed. Rebuilding identical inputs yields identical ZIP bytes and never overwrites different output.

A successful ZIP is not dedicated gameplay readiness: current preflight returns exit **3** with verified source/archive integrity but blocked Knowledge & Wisdom authority and unresolved CAT provenance. The kit supports dedicated diagnostic planning and blocker reproduction, not a qualified CAT acceptance or stable release claim. No server/config/mod install, process launch, upload or sandbox bypass is performed.
