# Framework compatibility

Version: 0.18.0

Earthworks requires `B47ANCEDKnowledgeAndWisdom` and `CATConstruction`. Its Mod ID is `B47ANCEDEarthworks`; the retained Lua namespace is `groundWorks`. CAT's matching local adapter must detect the new activation IDs and import the canonical knowledge API. CAT is a separate editable project, not included here; installing an older CAT package may still leave stale activation/import checks.

CAT optionally orders after Knowledge & Wisdom, without a reverse load-after-Earthworks edge because Earthworks requires CAT. Manual registration/qualification, presets, machinery and recovery use existing boot/deferred paths. CAT remains standalone when either optional framework is absent.

New manuals use `B47ANCEDKnowledgeAndWisdom.CC_Manual_*`. Saved `experienceWorks.CAT.*` qualifications and `CAT-OPERATOR-*` document IDs stay stable. The framework's private compatibility index resolves old saved books; Earthworks recognizes both old/new glovebox books and issuance values, preventing replacement after removal. No second knowledge ledger or migration bypass is added.

Knowledge & Wisdom 0.16.0 deliberately blocks dedicated character knowledge reads/writes. With both dependencies and training enabled, dedicated CAT qualification remains blocked. The integration delegates to that guard, preserving server authority. These IDs being correct does not establish MP readiness.

Other optional consumers still depend on their declared precipitation/heavy-object contracts; this onboarding does not repair unrelated renamed optional mods. No third-party source/assets are imported. CAT author/license/redistribution rights remain UNKNOWN; the user authorized local adapter edits only. No CAT files or assets are redistributed here. Future external-mod PRs require clean-room provenance and reviewer signoff.

The dedicated test tool pins source-content digests, metadata versions, file counts and Git revisions where available. It compares the exact selected external snapshots before building or preflighting. It never substitutes a Workshop copy based on ID alone, executes dependency scripts, or includes CAT/knowledge source in the Earthworks ZIP. CAT's missing canonical VERSION/Git record is a provenance blocker, not permission to invent a version. The knowledge MP guard remains a known blocked workflow; diagnostic tests must not be reported as training acceptance.

## Dedicated dependency inventory and clean-room review

Purpose: reproduce the matching dependency snapshot and diagnose native dedicated boundaries. CAT Construction (Mod ID CATConstruction, Workshop item 3796455546, observed metadata version 0.3.0) is externally authored; verified author, license and redistribution permission remain UNKNOWN. The existing local adapter was previously authorized for local integration edits; this iteration makes no external-mod edits. Knowledge & Wisdom is pinned at canonical 0.16.0 with its Git revision in MP_TEST_DEPENDENCIES.json.

Observed facts are limited to identity/version, file inventory/digests, the existing integration contract and knowledge authority rejection. Neutral build contract: accept exact independently obtained source snapshots; hash them without executing them; reject drift; package only Earthworks; retain readiness blockers. The builder/tests/checklist are independently authored. Third-party code, assets, text and algorithms imported: NONE. No new third-party attribution obligation is asserted because nothing is redistributed; rights remain unresolved. This is a source/inventory review, not legal clearance or native MP evidence. The PR must retain the clean-room checklist and owner/reviewer signoff before merge; signoff does not grant redistribution rights or clear G7.
