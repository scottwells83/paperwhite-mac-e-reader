# Canonical repository pointer

The canonical PaperLike source checkout is `../PAPERLIKE/`, the user-designated clone of `https://github.com/scottwells83/PAPERLIKE.git`.

At the 2026-10-06 Workshop structure review, that checkout and the nested `repository/` clone were both clean at commit `a07ea1da94f4e878d5cd92255a55e04c95c5214a`. Use only `../PAPERLIKE/` for source changes.

## Duplicate clone cleanup (2026-10-06)

After the owner authorized cleanup, the complete `artifacts/` directory from the redundant clone was moved to `deliverables/release-artifacts-from-duplicate-clone-2026-10-06/artifacts/`. All 678 files were verified against the sibling `MIGRATION-MANIFEST.json` by relative path, size, and SHA-256. Only after verification, the duplicate `repository/` directory—including its `.git`, `bin/`, and `obj/`—was removed. The canonical `../PAPERLIKE/` clone remains the source of truth; it was clean at the recorded commit after cleanup. No tests or installers were run for this file-management operation.
