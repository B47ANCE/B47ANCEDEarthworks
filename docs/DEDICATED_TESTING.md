# Dedicated multiplayer test plan

Version: 0.18.0

Dedicated server plus two clients is the first native test target. SP acceptance is optional and is never a prerequisite. This plan uses disposable saves and records actual native evidence separately from offline checks. G7 is BLOCKED / NOT TESTED; stable G8 is BLOCKED.

## Reproduce the diagnostic kit

Use the repository's Python development environment and independently obtained, authorized dependency checkouts. `KNOWLEDGE_PROJECT` and `CAT_PROJECT` below are local project roots containing `src/<ModID>/42/mod.info`; `BUILT_ZIP` is the archive path printed by build. No absolute developer paths are stored in the portable lock.

```sh
python scripts/check_versions.py
python scripts/check_lua_only.py
python scripts/validate_source.py
python scripts/validate_lua_source.py
python tests/test_lua_only.py
python tests/test_versioning.py
python tests/run_route_work.py
python tests/test_mp_test_build.py
python scripts/mp_test_build.py build --knowledge-root KNOWLEDGE_PROJECT --cat-root CAT_PROJECT
python scripts/mp_test_build.py preflight --knowledge-root KNOWLEDGE_PROJECT --cat-root CAT_PROJECT --archive BUILT_ZIP
```

The reviewed `MP_TEST_DEPENDENCIES.json` pins Knowledge & Wisdom 0.16.0 and the matching local CAT 0.3.0 adapter by normalized content SHA-256 and file count, plus Git revision/canonical version when available. Text CRLF is normalized to LF; binary assets remain byte exact. A matching version label alone is insufficient. Changed dependency content or available Git revision fails verification; review a new lock explicitly after any dependency repair. The `lock` subcommand refuses to overwrite an existing lock.

Build exits 0 when the diagnostic artifacts pass integrity checks. Preflight exits **3** when source/archive integrity passes but known readiness blockers remain; other failures are nonzero with `FAIL`. An exit 3 is not acceptance. A kit contains only Earthworks runtime files in B42 `mods/B47ANCEDEarthworks/42` and `common` layout, a manifest, dependency lock, this checklist and a blank results template. Sorted ZIP members, fixed timestamps, normalized text and fixed attributes make identical source produce identical ZIP bytes. Existing different output is preserved. Each manifest binds source commit/dirty state, source digest, lock digest and archive SHA-256. Record and use the final clean-commit build, not an earlier dirty diagnostic build.

Dependencies stay external. CAT source/assets have unknown redistribution rights and are never bundled. CAT lacks root VERSION and Git provenance; its metadata version is an observation, not canonical version approval. Independently verify authorized installations against the lock on the dedicated host and both clients. Keep the same enabled Mod IDs and dependency content on all three: `B47ANCEDKnowledgeAndWisdom`, `CATConstruction`, `B47ANCEDEarthworks`. Never enable a second legacy Earthworks identity alongside this one. The lock is an exact local adapter snapshot, not a claim that current Workshop subscriptions match it.

The tool writes only ignored `dist` outputs. It does not install mods, edit server configuration, start processes, change upstream dependencies or upload to Workshop. Server installation/configuration/startup and Workshop distribution require their own authorization. A successful build grants none of those actions.

## Blockers and test boundaries

- [VERIFIED source] Knowledge & Wisdom 0.16.0 `AuthorityGuard.lua` rejects dedicated character knowledge reads/writes with `MULTIPLAYER_STORAGE_UNAVAILABLE`. Preserve this guard. Qualified CAT training/operation acceptance remains BLOCKED until a safe authoritative persistence implementation exists and new dependency pins are reviewed. An expected rejection demonstrates only fail-closed behavior; it never passes the qualified workflow.
- [VERIFIED local inventory] CAT has no canonical VERSION or Git history in the pinned snapshot. Provenance readiness remains BLOCKED until explicitly onboarded/reviewed in its own project. Do not invent those values here or redistribute CAT assets.
- [RUNTIME GATE] Earthworks world mutation, inventory/spoil synchronization, visibility/collision, reconnect and persistence require native dedicated evidence. Offline mocks are insufficient. If a required operation is rejected by a dependency guard, record BLOCKED and stop that scenario rather than bypassing it.
- [VERIFIED source limit] Experimental wheelbarrow pushing is SP-only and must remain unavailable in MP. Test rejection/absence in dedicated sessions; do not enable it to expand coverage. Fluid simulation and custom cutaways are outside implemented scope.

## Dedicated execution checklist

Before native execution, obtain the required server/test-install authorization, preserve a backup and use disposable new/old-save fixtures. Use the results template from the kit. Record exact PZ version/build for server and each client from their own evidence; do not infer the full game version from a Steam manifest number. Record archive/lock/source digests, commit, dependency versions/digests, sandbox settings, enabled IDs and map/fixture identifier. Use anonymous client labels A/B; retain raw logs privately, with only sanitized error excerpts in public reports.

| ID | Dedicated scenario | Required observation |
| --- | --- | --- |
| D01 | Verify server and both client pins before startup | Exact build/dependency content and IDs match; no custom Java/JAR/bridge; clean isolated logs. Readiness blockers remain explicit. |
| D02 | Headless dedicated load, then clients A and B join | No missing module/ID/translation errors; authoritative sandbox values reach both clients; record actual load errors. |
| D03 | Client A performs one supported shallow hand-excavation action in a disposable cell | Server validates intent and mutates once; client B sees the same geometry, item/spoil totals and collision. If a guard rejects it, record BLOCKED. |
| D04 | Malformed, out-of-range and replayed intent using a controlled diagnostic fixture | Server rejects invalid/duplicate work without mutation, extra spoil, item loss or a crash. Record fixture and observed server response; do not equate source inspection with runtime PASS. |
| D05 | A and B act on the same cell concurrently | Conflict is server resolved; no duplicate excavation, spoil, wear or rewards; both converge. |
| D06 | Spoil transfer, capacity boundary, cancellation and interrupted work | Material/inventory conservation across both clients and server; cancellation and repeated requests do not duplicate items. |
| D07 | Attempt backfill of an occupied cell, then allowed backfill | Unsafe/occupied backfill is rejected; allowed action synchronizes geometry and material accounting exactly once. |
| D08 | Depth/climb/visibility/collision and chunk streaming | Both clients agree after moving away/back; vanilla rendering limits are recorded; no claim of unsupported cutaways/fluid behavior. |
| D09 | Late join, disconnect/rejoin and repeated reload | New/rejoining client receives existing state; no repeated manual issuance, lost terrain or duplicate material. |
| D10 | Graceful dedicated save/restart and client rejoin | Persistent world/material/manual state is restored once; transient requests are not replayed. |
| D11 | Disposable old-save books and issuance markers | Legacy manual types, qualification IDs and issuance markers retain compatibility; no duplicate books. Knowledge-dependent assertions remain BLOCKED while the guard rejects them. |
| D12 | CAT manual knowledge access under current dependency guard | Expected fail-closed rejection is visible and safe. Record diagnostic result separately; qualified training/operation remains BLOCKED, never PASS. |
| D13 | CAT qualification, machinery work and machinery restart/reconnect | BLOCKED by current knowledge authority/provenance. After repairs, repin dependencies and run fully with two clients and restart; do not inherit a previous lock's results. |
| D14 | Wheelbarrow MP action boundary | Unsupported pushing stays unavailable/rejected; no client-owned shared gameplay or bypass. |
| D15 | Authoritative sandbox settings and existing-save behavior | Record defaults and a bounded nondefault server configuration; both clients obey the same values after reconnect/restart. |

Each scenario records PASS, FAIL, BLOCKED or NOT_TESTED, steps, expected/actual result and sanitized evidence references. Any regression stops affected coverage. Never upgrade offline/static results to runtime PASS. Repeat affected cases after a source/dependency/game-build change and retain prior evidence with its original inputs.

G7 can pass only after required dedicated authority, synchronization, persistence, two-client and restart coverage passes against exact pinned inputs, including repaired CAT qualification. Until then G7 stays BLOCKED / NOT TESTED and stable G8 stays BLOCKED. Workshop MP test distribution, when explicitly authorized, remains distribution evidence only and must say: **MP testing build - dedicated multiplayer NOT TESTED**.
