# Current development status

Version: 0.19.0

Earthworks is standalone and Lua-only. CAT integration and its CAT-only knowledge dependency are removed. No external dependency provenance/storage gate remains for the Earthworks baseline. The independent Knowledge & Wisdom private-storage repair is separate and keeps its own scope/runtime limits.

Hand-tool excavation, spoil accounting and gravel routes remain server-authoritative. Vehicle provider mappings, machine cargo/manual hooks and default vehicle validation are retired; generic explicitly registered providers remain. Saved terrain/route/job schemas and markers are preserved. Existing machine-only projects do not become manually constructible or disappear.

Dedicated server/two clients is the first native target; SP is optional. Native G7 BLOCKED / NOT TESTED; stable G8 BLOCKED. Vanilla rendering, geometry/collision/lighting, concurrency, inventory synchronization, chunk streaming, late join, reconnect and restart require actual native evidence. Wheelbarrow pushing remains experimental/SP-only and unavailable in MP.

The reproducible standalone kit and no-dependency preflight support first dedicated tests; source/ZIP integrity is independent of native acceptance. No server/install/Workshop item was changed or launched. See DEDICATED_TESTING.md and VALIDATION_CURRENT.md.
