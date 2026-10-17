# Current development status

Version: 0.18.0

This source is Lua-only and uses the current Earthworks/Knowledge & Wisdom/CAT Mod IDs. Canonical version and public Git onboarding are configured; see VERSION_POLICY.md. The 0.16.1 import and merged 0.17.0 onboarding are historical; current 0.18.0 tooling uses a feature branch and PR. Push verification and current CI status are recorded in the PR and iteration report.

Offline evidence: source compiles under Lua 5.1; selected self-contained regressions and mocked route/excavation contracts are available. Cross-project CAT tests were run separately against local canonical sources, not bundled into this repository or CI. Current exact checks and results are in VALIDATION_CURRENT.md.

SP runtime: NOT TESTED for this snapshot; optional, never a dedicated prerequisite. Dedicated G7: BLOCKED / NOT TESTED. Stable G8: BLOCKED. Knowledge & Wisdom 0.16.0 blocks dedicated knowledge operations pending safe persistence; CAT delegates to that API without bypassing it. Local diagnostic packaging is authorized for this iteration; no deployment, Workshop upload or stable tag.

Known limits: vanilla rendering lacks custom cutaways/retained underground surface view; fluid flow/swimming is not implemented; wheelbarrow pushing is SP-only and remains experimental. Native geometry/collision/lighting, old saves, chunk streaming, inventory replication, join/reconnect and restart acceptance remain runtime gates.

Dedicated-first iteration: reproducible diagnostic kit and matching external dependency lock are implemented; SP is not a gate. Generated test packages are development diagnostics with readiness BLOCKED by dependency authority/provenance, independently of source/ZIP integrity. See DEDICATED_TESTING.md. No server was launched or modified.
