# Earthworks project instructions

Current version: 0.16.1. Canonical version is root VERSION.

Read the user's current global AGENTS.md through USERPROFILE/.codex/AGENTS.md when available. Team skills live in USERPROFILE/.agents/skills; preserve unrelated settings.

- Identity: B47ANCE'd Earthworks; Mod ID B47ANCEDEarthworks; Workshop item 3788591561.
- Authoritative runtime: src/B47ANCEDEarthworks/42. Parent info.txt/thumbnail and preview.png are authoring metadata/artwork. Contents/dist and ignored old docs are historical.
- Lua-only runtime. Preserve vanilla rendering; never restore the Java companion or retired enhanced-visibility setting. Historical Java evidence remains local, outside source and Git.
- Preserve groundWorks Lua paths/global, sandbox IDs, save keys, protocols and schema versions. Clients submit intent; server validates, mutates and persists shared state. Never bypass Knowledge & Wisdom's MP guard.
- Dependencies: B47ANCEDKnowledgeAndWisdom and CATConstruction. New manual types use the knowledge module; saved experienceWorks.CAT.* qualifications, CAT-OPERATOR-* documents and legacy manual/issuance compatibility remain stable.
- Follow docs/VERSION_POLICY.md, SOURCE_INVENTORY.json and VERSION_MIRRORS.json. Classify/record target SemVer before edits; run scripts/check_versions.py before/after and --release before release consideration.
- Public repository: B47ANCE/B47ANCEDEarthworks. Use named branches and PRs before shared-main merges; do not merge without an explicit merge request. Preserve user work, inspect freshness and audit staged public files before every push.
- Run the commands in README and docs/VALIDATION_CURRENT.md. Offline/static, native SP and dedicated evidence are separate. Dedicated G7 and stable G8 remain BLOCKED.
- No automatic packaging, deployment, game/server launch, Workshop upload, Steam restart or artifact cleanup. Preserve originals and historical provenance.
