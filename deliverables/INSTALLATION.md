# Installing PaperLike

## macOS

Use the package for your processor: Apple Silicon or Intel. Open the disk image and run **Install PaperLike.command**. It installs `~/Applications/PaperLike.app`. Books and progress stay under `~/Library/Application Support/PaperLike/`.

These preview packages are ad-hoc signed and not notarized. macOS may show a security warning. A public release should be signed and notarized with an Apple Developer ID.

## Windows

For the current preview, download `PaperLike-Windows-x64-Portable.zip`, extract the complete folder, and run `PaperLike.exe`. This portable build does not create a Start Menu entry. The per-user setup installer (`PaperLike-Setup-x64.exe`) is configured to be built and attached to a GitHub Release after the source is pushed to the chosen repository. It installs without administrator access. Books and progress are saved under `%LOCALAPPDATA%\PaperLike\`.

## Your books

Importing an EPUB copies it into the app-managed Books folder and leaves the original in place. Use **Folder** in the app to view the saved copies. Uninstalling the app does not automatically delete books or progress.
