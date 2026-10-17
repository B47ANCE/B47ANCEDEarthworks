# Current validation record

Version: 0.18.0

Environment: offline Windows host using Python and Lupa 2.6 / Lua 5.1; the route harness uses Lupa's default host runtime. GitHub Actions repeats portable offline checks on Linux/Python 3.12. Neither environment is PZ runtime or a Linux dedicated-server test.

Required commands (from repository root):

```sh
python scripts/check_versions.py
python scripts/check_public_tree.py --staged
python scripts/check_lua_only.py
python scripts/validate_source.py
python scripts/validate_lua_source.py
python tests/test_lua_only.py
python tests/test_versioning.py
python tests/test_mp_test_build.py
python tests/run_route_work.py
```

Local offline checks PASS: 20 version mirrors; 77-file Lua-only source gate; identity, exact-case imports, three English translation files, sandbox tooltips and Workshop mirrors; 68 Lua 5.1 compilations; 9/9 selected Lua regressions; 5/5 source-gate tests; 4/4 version-gate tests; 9/9 dedicated-build tests; 25 mocked excavation contracts plus route/material replay checks. Public staged-file audit is run separately before every commit/push. Remote CI results are reported after push, not inferred from these local results. Selected Lua regressions cover API isolation, load graph, machine projects, precipitation cleaning, spoil exchange, surface presentation, wheelbarrow bodies, worn surfaces and vanilla-only visibility. Other inherited positional-argument fixtures and removed historical trench modules are not silently counted as passes. The route harness runs 25 imported contracts plus route/material replay/machine-only exclusions using simulated engine adapters.

Dedicated kit [TESTED offline Windows]: repeated builds from identical inputs produce the same 76-member archive (75 Earthworks runtime files plus explicit common directory), SHA-256 `9553aba922266b4e928f09c74ae6740ca408533d6ff8e59ee1f0fbe83d9747f0`. Dependency lock SHA-256: `1f2146c2b412601d1fd3847d5cc17d31c6327337d43c1db71aaae12dc16620f1`. Earthworks normalized source digest: `35fd2c08317369f86848e98f34d981ee6f33939f9a75992937497b4e5a12c6e9`. Preflight verifies exact source, dependency and archive contents/bytes but returns readiness BLOCKED (native exit 3) for knowledge authority and CAT provenance. The final build's ignored manifest records its exact committed source revision/dirty state; the archive digest is independent of commit metadata. Dependency code/assets are not in the ZIP. Exact build/preflight commands and dedicated scenarios are in DEDICATED_TESTING.md; native results remain blank. No server was changed or launched.

Compatibility context: the separate local CAT adapter compiled 19 source Lua files and passed 10/10 host regression files during the preceding integration fix, including old book/issuance behavior and stable qualification IDs against Knowledge & Wisdom 0.16.0. Those are historical local cross-project results, not a claim that every installed CAT package is fixed. CAT source is not bundled here.

[RUNTIME GATE] Dedicated server/two clients is the first native target. SP: NOT TESTED and optional, never a prerequisite. Dedicated G7: BLOCKED / NOT TESTED. Stable G8: BLOCKED. Test disposable old/new saves, Java-free loading, visibility/depth, material accounting, excavation/route geometry, saved manual qualification and non-reissuance, two clients, join/rejoin, synchronization, persistence and dedicated restart. Knowledge & Wisdom's blocked MP authority/storage must be resolved before claiming dedicated manual qualification works; CAT canonical/Git provenance also remains unresolved.

`python scripts/check_versions.py --release` is expected to BLOCK G8; absence of current packages/runtime evidence must not be reported as a source-test failure or a release PASS. No game/server, local install or Workshop item is touched by these commands.

The initial 0.16.1 Git import passed GitHub's Linux offline workflow at commit `dceb259d9d40ad9deaf9ef0f716c7e10c562ecdc` ([baseline run](https://github.com/B47ANCE/B47ANCEDEarthworks/actions/runs/38994885200)). That is historical baseline CI, not evidence for this version's final commit; current branch/PR checks must pass independently.
