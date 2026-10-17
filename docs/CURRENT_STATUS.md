# Current development status

Version: 0.17.0

This source is Lua-only and uses the current Earthworks/Knowledge & Wisdom/CAT Mod IDs. Canonical version and public Git onboarding are now configured; see VERSION_POLICY.md. The observed 0.16.1 import is historical on main; approved canonical development version 0.17.0 uses the onboarding feature branch and PR workflow; push verification and current CI status are recorded in the PR and iteration report.

Offline evidence: source compiles under Lua 5.1; selected self-contained regressions and mocked route/excavation contracts are available. Cross-project CAT tests were run separately against local canonical sources, not bundled into this repository or CI. Current exact checks and results are in VALIDATION_CURRENT.md.

SP runtime: NOT TESTED for this snapshot. Dedicated G7: BLOCKED / NOT TESTED. Stable G8: BLOCKED. Knowledge & Wisdom 0.16.0 blocks dedicated knowledge operations pending safe persistence; CAT delegates to that API without bypassing it. No current package, deployment, Workshop upload or stable tag.

Known limits: vanilla rendering lacks custom cutaways/retained underground surface view; fluid flow/swimming is not implemented; wheelbarrow pushing is SP-only and remains experimental. Native geometry/collision/lighting, old saves, chunk streaming, inventory replication, join/reconnect and restart acceptance remain runtime gates.
