# PaperLike prototype notes

PaperLike is a shared Avalonia/.NET desktop app for macOS and Windows.

## Reviewed on macOS

- The paper-style reading view fills the available page area with comfortable margins and legible type.
- Paper, Ivory, and Night themes work; text size, theme, and font preference are saved.
- EPUB import copies the source into the app library without moving the original.
- Chapter headings populate a chapter picker. Chapter navigation, last-read chapter, and per-chapter scroll offset restore after relaunch.
- The empty-library welcome screen and the import flow were visually reviewed.

## Current limits

The parser shows text from EPUB chapters, but not book images or rich inline styling. Bookmarks, search, PDF, and sync are not implemented. The Windows executable was cross-published and identified as x64 PE, but it has not been launched on a Windows machine. The source license and GitHub destination are not yet selected. Mac preview packages are ad-hoc signed and not notarized.
