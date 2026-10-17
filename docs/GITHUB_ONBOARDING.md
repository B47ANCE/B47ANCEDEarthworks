# GitHub and version onboarding provenance

User approval on 2026-10-16 (America/Phoenix): create PUBLIC `B47ANCE/B47ANCEDEarthworks` and establish canonical development version **0.17.0**. Authenticated GitHub login was verified as B47ANCE; the repository name returned 404 before creation. No owner, Mod ID, Workshop ID or version was guessed.

Pre-onboarding source metadata/API/info/Workshop mirrors all reported **0.16.1**, while old Contents reported 0.13.2 and older reports described 0.16.0 or earlier. The initial Git main import records the observed 0.16.1 source as an explicitly unverified development baseline. Approved 0.17.0 is a pre-1.0 MINOR iteration on `chore/repository-onboarding-0.17.0`, with PR review before shared-main merge. No native evidence is relabeled and no stable release/tag is created.

Ten edited pre-Git metadata/source/doc files and exact hashes were preserved in ignored `docs/local-history/pre-git-0.16.1`; older reports, Contents, dist, historical Java and upload/checksum records remain unchanged and local. This is conservative retention, not cleanup. The public inventory contains authoritative source, tests, one inherited mock-contract fixture, portable current docs and offline CI. Local links, settings, diagnostics, packages and binary Java evidence are excluded. There is no current release artifact.

Source provenance uses SHA-256 with canonical LF for text and exact PNG bytes, matching Git attributes. Every current source path must be selected and fingerprinted; staged bytes are checked before pushes. Public-tree scanning is a bounded credential/artifact heuristic plus manual review, not a guarantee that arbitrary future private data is safe.

Freshness before onboarding: no Git repository existed, so HEAD/upstream/default-branch ancestry was unavailable. The user explicitly authorized repository creation and target version. After the initial main push, normal freshness checks apply before the version iteration and every subsequent commit/push. Verify local/remote SHAs; record actual PR/CI status separately, never self-reference an unknowable final commit in its own contents.

The first GitHub upload backs up Earthworks only. The separately modified CAT workspace is not made part of this repository. Knowledge & Wisdom was consumed read-only at its existing version. GitHub public visibility and branch SHA must be verified after push; until then no backup success is claimed.

CI has contents:read permissions, pinned upstream-verified action SHAs, disabled persisted checkout credentials and no Steam/SFTP/game access. It performs no deployment, publication, package creation, cleanup or server connection. A workflow does not itself configure branch protection. Main merges require the project's explicit merge authorization and applicable green checks.

Initial main source backup was verified: local and remote SHA `dceb259d9d40ad9deaf9ef0f716c7e10c562ecdc` matched. Public visibility was verified through the GitHub API. The feature branch tracks verified origin/main until its first explicit feature-branch push establishes its own upstream.
