# Framework compatibility

Version: 0.16.1

Earthworks requires `B47ANCEDKnowledgeAndWisdom` and `CATConstruction`. Its Mod ID is `B47ANCEDEarthworks`; the retained Lua namespace is `groundWorks`. CAT's matching local adapter must detect the new activation IDs and import the canonical knowledge API. CAT is a separate editable project, not included here; installing an older CAT package may still leave stale activation/import checks.

CAT optionally orders after Knowledge & Wisdom, without a reverse load-after-Earthworks edge because Earthworks requires CAT. Manual registration/qualification, presets, machinery and recovery use existing boot/deferred paths. CAT remains standalone when either optional framework is absent.

New manuals use `B47ANCEDKnowledgeAndWisdom.CC_Manual_*`. Saved `experienceWorks.CAT.*` qualifications and `CAT-OPERATOR-*` document IDs stay stable. The framework's private compatibility index resolves old saved books; Earthworks recognizes both old/new glovebox books and issuance values, preventing replacement after removal. No second knowledge ledger or migration bypass is added.

Knowledge & Wisdom 0.16.0 deliberately blocks dedicated character knowledge reads/writes. With both dependencies and training enabled, dedicated CAT qualification remains blocked. The integration delegates to that guard, preserving server authority. These IDs being correct does not establish MP readiness.

Other optional consumers still depend on their declared precipitation/heavy-object contracts; this onboarding does not repair unrelated renamed optional mods. No third-party source/assets are imported. CAT author/license/redistribution rights remain UNKNOWN; the user authorized local adapter edits only. No CAT files or assets are redistributed here. Future external-mod PRs require clean-room provenance and reviewer signoff.
