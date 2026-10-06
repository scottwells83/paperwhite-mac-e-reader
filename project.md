# PaperLike

- Goal: A free, personal EPUB reader for Windows and macOS with a calm paper-like reading surface and a low-friction local library.
- Audience: Scott first, and potentially other readers if the project is later published.
- Confirmed scope: EPUB first; local library; imported files are copied, never moved; chapter progress saved per book; paper, ivory, and night tones; adjustable text size.
- No accounts, cloud service, store, or monetization flow.
- Data paths: macOS `~/Library/Application Support/PaperLike/`; Windows `%LOCALAPPDATA%\\PaperLike\\`.
- Current implementation: shared Avalonia/.NET desktop app with macOS Apple Silicon/Intel bundles and a Windows x64 portable preview. A Windows per-user setup installer is defined in GitHub Actions.
- Open release choices: choose a source license and identify/authorize the GitHub repository before any upload. macOS Developer ID signing/notarization is needed for public distribution without Gatekeeper warnings.
- Status: source, package workflow, local install, sample EPUB import, theme switching, and chapter resume have been reviewed on macOS. Windows executable has been cross-published but cannot be launched on this Mac.


## Local agent delegation and Manager QA (2026-10-06)

Two suitable, bounded local jobs were recorded in `jobs.json`: `release-gate-inventory` (local-worker) and `release-notes-draft` (local-drafter). Both completed in two runs. The first run was reviewed; the Manager tightened the briefs after correcting a classification and platform-test wording issue. The second run's outputs were reviewed against their briefs and the project facts and accepted. The release inventory was lightly edited for clarity during integration. Latest execution details are in `run-report.json`; `run-history.jsonl` preserves both runs. Across both runs Ollama reported 1,671 prompt tokens and 786 response tokens for these two jobs. These are local-agent counts and do not represent ChatGPT Work/Codex usage.

## Repository continuity (2026-10-06)

- Canonical repository path: `../PAPERLIKE/` relative to this workspace.
- Origin: `https://github.com/scottwells83/PAPERLIKE.git`
- Verified branch and commit: `main`, `a07ea1da94f4e878d5cd92255a55e04c95c5214a`; working tree clean.
- A redundant second clone previously at `repository/` was removed on 2026-10-06 after release artifact preservation. All 678 files from its `artifacts/` directory were moved to `deliverables/release-artifacts-from-duplicate-clone-2026-10-06/artifacts/` and verified by relative path, file size, and SHA-256 against `MIGRATION-MANIFEST.json`.
- The duplicate clone's `.git`, `bin/`, and `obj/` caches were removed. The canonical `../PAPERLIKE/` checkout was not changed and remains clean at the commit above.
- Tests and installer checks were not run as part of this storage cleanup. See `REPOSITORY.md` for the final ownership and migration record.
