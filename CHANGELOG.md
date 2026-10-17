# B47ANCE'd Earthworks changelog

## [0.19.0] - Standalone dedicated test build

- Removed CAT and its CAT-only Knowledge & Wisdom hard dependency. Earthworks now loads standalone.
- Removed bundled vehicle provider registration, cargo/manual hooks and automatic machine validation. Consumer API advances to 3; old lookup/issuance entry points are inert. Generic explicitly registered server providers remain supported.
- Hid the unavailable machine-only concrete-road start action; retained saved route definitions, terrain state, schemas, sandbox IDs and issuance markers without conversion.
- Replaced the external dependency lock and builder arguments with a standalone dedicated kit. Added standalone load/no-adapter regression coverage; no server launch, install or upload.
- Dedicated is the first native target. Offline integrity can pass with no dependency blocker; native G7 and stable G8 remain BLOCKED / NOT TESTED.

## [0.18.0] - Dedicated-first reproducible diagnostics

- Added deterministic Earthworks test ZIP generation, content-locked external Knowledge & Wisdom/CAT dependencies, safe repeat builds, integrity/CRC/case checks and fail-closed preflight.
- Added a dedicated-server/two-client checklist and results template. SP is not a prerequisite; no gameplay authority guard or unsupported MP feature is enabled.
- Adopted the reviewed Earthworks feature overview and synchronized 20 version mirrors. Runtime changes are version strings only; schemas/IDs and existing settings are preserved.
- Test package contents are Earthworks only. CAT assets and knowledge source remain external; no upload/deployment/server launch occurs.
- Known blockers remain: Knowledge & Wisdom dedicated knowledge authority/storage; CAT canonical Git/version provenance. G7 and stable G8 remain BLOCKED. See dedicated testing and current validation docs.

## [0.17.0] - Canonical development onboarding

- Established root VERSION and synchronized all 16 declared mirrors, including source metadata/API, current docs, changelog, Workshop text and source provenance.
- Recorded the accumulated pre-1.0 public identity change, Lua-only renderer migration and corrected framework dependencies as a MINOR iteration; saved schema/API namespaces remain unchanged.
- Set up public GitHub history, source inventory, credential/artifact and version gates, and pinned read-only offline CI.
- Excluded local diagnostics, linked settings, historical packages/reports and retired Java binaries from public history while retaining them locally.
- Local offline validation passes; remote CI is checked after push. Native SP is NOT TESTED, dedicated G7 and stable G8 remain BLOCKED. No package/deploy/Workshop upload or stable tag.

## [0.16.1] - Initial Git import (development baseline)

This is the observed pre-onboarding source version, not a release or a relabeling of historical runtime evidence. User approved 0.17.0 as the next canonical development iteration.

- Imported the existing renamed Earthworks Lua source and tests without changing shared gameplay behavior.
- Current Mod ID is B47ANCEDEarthworks; dependency IDs are B47ANCEDKnowledgeAndWisdom and CATConstruction.
- Java visibility dependency is removed from active source; vanilla rendering is retained.
- Saved Lua/sandbox/persistence IDs, CAT qualifications, old books and issuance markers remain compatible by source/offline checks.
- Added repository governance, source inventory, version/public-tree gates and offline CI. No package, native runtime acceptance or stable release is claimed.

Earlier unversioned local notes and packages are retained in ignored local history. They are not current version mirrors.
