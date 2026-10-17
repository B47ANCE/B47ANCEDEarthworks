# Current architecture and invariants

Version: 0.19.0

Lua-only authoritative runtime: src/B47ANCEDEarthworks/42. Mod ID B47ANCEDEarthworks; retained groundWorks Lua/save/sandbox namespace and schemas. Vanilla owns rendering. No custom Java/JAR dependency, external required mod or bundled vehicle adapter.

Clients submit bounded action intent; server validates actor, reach, tools/materials, permissions, replay identity and current state before mutating/persisting shared terrain/jobs/inventory. Existing vanilla/custom synchronization paths remain; native join/reconnect, persistence, geometry and inventory behavior require dedicated evidence. No client-authority fallback is introduced.

Consumer API 3 removes automatic vehicle mappings, cargo/manual issuance and default machine validation. Old query/issuance entry points are inert; generic provider registration and explicit server validators remain. Saved machine-only project/route records are retained and never converted to manual work. No new gameplay tuning is introduced; existing server sandbox settings remain authoritative.

Dedicated is the first native target; SP is optional. Development Python builds a deterministic standalone 42/common ZIP and reports source/lock/archive fingerprints. The no-dependency lock is not a runtime PASS. G7 and stable G8 remain blocked pending actual dedicated evidence. No install, process launch, server change or upload is automated.
