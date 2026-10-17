# B47ANCE'd Earthworks

Version: `0.16.1` - development source, not a stable release.

Lua-only excavation, construction and surface wear for Project Zomboid Build 42. Dig and frame trenches, moats and basements; deepen, climb, move spoil and backfill; build routes and integrate CAT machinery. Water remains stored visual fill, not fluid flow. Wheelbarrow pushing is experimental and SP-only.

- Mod ID: `B47ANCEDEarthworks`; Workshop item: `3788591561`.
- Required Mod IDs: `B47ANCEDKnowledgeAndWisdom` and `CATConstruction`.
- Canonical version: root [VERSION](VERSION). Active runtime: `src/B47ANCEDEarthworks/42`.
- Retained API/save/sandbox namespace: `groundWorks`. Enable one package identity only.
- Rendering: vanilla; custom cutaways and retained underground surface views are unavailable.

[Public repository](https://github.com/B47ANCE/B47ANCEDEarthworks). The observed 0.16.1 source is the initial Git import; approved 0.17.0 onboarding belongs on a named branch and PR. No stable tags are created from unverified work.

## Current limitations

SP runtime is NOT TESTED for this source snapshot. Dedicated G7 is BLOCKED / NOT TESTED; stable G8 is BLOCKED. Knowledge & Wisdom 0.16.0 deliberately blocks dedicated knowledge reads/writes; CAT qualification preserves that guard. A public push or green CI is offline evidence, not gameplay certification.

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
python tests/run_route_work.py
python scripts/check_public_tree.py --staged
```

The self-contained suite compiles source Lua, runs nine selected Lua regressions, validates source structure/translations and executes mocked excavation/route contracts. It does not run every inherited fixture or test real PZ APIs. Cross-project CAT tests are separate. [Validation and runtime gates](docs/VALIDATION_CURRENT.md) lists the exact scope.

[Version policy](docs/VERSION_POLICY.md), [source inventory](docs/SOURCE_INVENTORY.json), [architecture](docs/ARCHITECTURE_CURRENT.md), [sandbox configuration](docs/CONFIGURATION.md), and [onboarding provenance](docs/GITHUB_ONBOARDING.md).

Historical packages, reports, Java evidence, developer links and diagnostics remain local and are excluded from the public tree. No current package exists; use authoritative source for a separately authorized future build. CI never deploys, uploads or connects to a game/server.
