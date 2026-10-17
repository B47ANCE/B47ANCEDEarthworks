# Current architecture and invariants

Version: 0.16.1

The runtime is Lua-only. The public Lua global/import namespace remains `groundWorks`; the active Mod ID is `B47ANCEDEarthworks`. Rendering stays with the vanilla engine. Visibility status returns detached vanilla-only state; no custom renderer, bytecode injection or Java loader is required.

Shared gameplay follows existing authority boundaries: clients submit action intent; server/SP handlers validate actor/location/tools, protected/occupied geometry, operation identity and inventory before mutation. Earthwork jobs, route transactions and spoil exchanges retain replay/uncertain-outcome handling. These source boundaries are not native MP proof.

`EarthworkStoreServer` attaches the shared `groundWorks.earthworks.v1` schema-1 job store through vanilla ModData; integrity validation rejects malformed/future states. Server transmission and client snapshot handling remain existing behavior. The store is shared world state, not private character knowledge. Surface wear uses the retained `groundWorks.surface.v1` state key. Schema/storage IDs and protocol names are not branding mirrors and must not be renamed without a separately reviewed migration.

Knowledge & Wisdom owns character knowledge, physical manual definitions and reading hooks. CAT owns machine training definitions and machinery authority; Earthworks owns earthwork/route state and once-per-vehicle manual issuance. New items use the canonical knowledge module, while saved qualification IDs and legacy book/issuance markers remain stable. The framework's deliberate dedicated knowledge guard is preserved.

Meaningful shared gameplay configuration remains in server sandbox options; this onboarding adds none. Internal queue/safety bounds, protocol internals and UI geometry stay internal. Native API availability, replication, join/reconnect, save/restart behavior, geometry and rendering remain explicit runtime gates. See CONFIGURATION.md, COMPATIBILITY.md and VALIDATION_CURRENT.md.
