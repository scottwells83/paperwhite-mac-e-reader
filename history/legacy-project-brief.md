# Paperwhite Reader

- Goal: Build a free, personal EPUB reader for Windows and macOS that makes reading comfortable, calm, and low-friction, centered on a warm paper-like page.
- Source material: The director's project description in chat and `~/AI-Workshop/AGENTS.md` with relevant linked engineering guidance.
- Audience: The director first; later, anyone who wants a simple, comfortable local reading experience.
- Constraints: Windows and macOS apps; local library and progress; no accounts, storefront, cloud sync, or monetization in the personal version.
- Confirmed: EPUB first. Imported books are copied to the app-managed library, leaving originals untouched. Reading position is currently saved per chapter.
- Data locations: macOS `~/Library/Application Support/Paperwhite Reader/`; Windows `%LOCALAPPDATA%\\Paperwhite Reader\\`.
- Distribution plan: Per-user Windows setup executable (Inno Setup) and macOS app disk image with an installer command. GitHub Actions builds the platform installers; public repository/license and macOS Developer ID signing remain decisions for release.
- Status: Cross-platform Avalonia prototype builds. Local Mac package and Windows installer workflow are being prepared.
