# Earthworks project instructions

Current version: 0.19.0. Canonical version is root VERSION.

Read the user's current global AGENTS.md through USERPROFILE/.codex/AGENTS.md when available. Team skills live in USERPROFILE/.agents/skills; preserve unrelated settings.

- Identity: B47ANCE'd Earthworks; Mod ID B47ANCEDEarthworks; Workshop item 3788591561.
- Authoritative runtime: src/B47ANCEDEarthworks/42. Parent info.txt/thumbnail and preview.png are authoring metadata/artwork. Contents and ignored old docs are historical; versioned dist outputs are classified by their manifests.
- Lua-only runtime. Preserve vanilla rendering; never restore the Java companion or retired enhanced-visibility setting. Historical Java evidence remains local, outside source and Git.
- Preserve groundWorks Lua paths/global, sandbox IDs, save keys, protocols and schema versions. Clients submit intent; server validates, mutates and persists shared state. Never downgrade shared gameplay to client authority.
- No hard runtime dependencies. Vehicle adapters/manual issuance are retired; no automatic machine providers or validator fallback. Preserve saved namespaces, terrain and issuance markers without converting retired machine-only jobs.
- Follow docs/VERSION_POLICY.md, SOURCE_INVENTORY.json and VERSION_MIRRORS.json. Classify/record target SemVer before edits; run scripts/check_versions.py before/after and --release before release consideration.
- Public repository: B47ANCE/B47ANCEDEarthworks. Use named branches and PRs before shared-main merges; do not merge without an explicit merge request. Preserve user work, inspect freshness and audit staged public files before every push.
- Run the commands in README and docs/VALIDATION_CURRENT.md. Offline/static, native SP and dedicated evidence are separate. Dedicated G7 and stable G8 remain BLOCKED.
- No automatic packaging, deployment, game/server launch, Workshop upload, Steam restart or artifact cleanup. Preserve originals and historical provenance.

- Dedicated MP is the first native validation target from the first slice. SP acceptance is optional and is never a prerequisite for dedicated testing. Preserve historical SP-only feature limits; do not enable unsupported MP behavior.
- Dedicated test kit: scripts/mp_test_build.py, docs/MP_TEST_DEPENDENCIES.json and docs/DEDICATED_TESTING.md. Build/preflight integrity is separate from native G7; the current lock has no external dependencies.
- Maintain reviewed docs/MOD_OVERVIEW.json in the same branch with the current version/source digest. No external runtime files are bundled; a kit build does not authorize server changes/launch or upload.
