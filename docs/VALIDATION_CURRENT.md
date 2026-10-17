# Current validation record

Version: 0.16.1

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
python tests/run_route_work.py
```

Local offline checks PASS: 16 version mirrors; 77-file Lua-only source gate; identity, exact-case imports, three English translation files, sandbox tooltips and Workshop mirrors; 68 Lua 5.1 compilations; 9/9 selected Lua regressions; 5/5 source-gate tests; 4/4 version-gate tests; 25 mocked excavation contracts plus route/material replay checks. Public staged-file audit is run separately before every commit/push. Remote CI results are reported after push, not inferred from these local results. Selected Lua regressions cover API isolation, load graph, machine projects, precipitation cleaning, spoil exchange, surface presentation, wheelbarrow bodies, worn surfaces and vanilla-only visibility. Other inherited positional-argument fixtures and removed historical trench modules are not silently counted as passes. The route harness runs 25 imported contracts plus route/material replay/machine-only exclusions using simulated engine adapters.

Compatibility context: the separate local CAT adapter compiled 19 source Lua files and passed 10/10 host regression files during the preceding integration fix, including old book/issuance behavior and stable qualification IDs against Knowledge & Wisdom 0.16.0. Those are historical local cross-project results, not a claim that every installed CAT package is fixed. CAT source is not bundled here.

[RUNTIME GATE] SP: NOT TESTED for this snapshot. Dedicated G7: BLOCKED / NOT TESTED. Stable G8: BLOCKED. Test disposable old/new saves, Java-free loading, visibility/depth, material accounting, excavation/route geometry, saved manual qualification and non-reissuance, two clients, join/rejoin, synchronization, persistence and dedicated restart. Knowledge & Wisdom's blocked MP authority/storage must be resolved before claiming dedicated manual qualification works.

`python scripts/check_versions.py --release` is expected to BLOCK G8; absence of current packages/runtime evidence must not be reported as a source-test failure or a release PASS. No game/server, local install or Workshop item is touched by these commands.
