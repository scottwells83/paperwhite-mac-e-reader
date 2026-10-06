# Paperwhite Reader prototype

Native SwiftUI macOS prototype for EPUB-first reading.

## Build and run

From this directory:

```sh
swift run
```

Or build a packaged `.app` from the project root with `./build-app.sh`.

## Current scope

- Open one local EPUB at a time.
- Display chapter text in a calm reading surface with paper, ivory, and night tones.
- Adjust text size and move between chapters.
- Copy imported EPUBs into `~/Library/Application Support/Paperwhite Reader/Books`.
- Keep a multi-book library and remember each book's last-read chapter on this Mac.
- Open the saved EPUB folder from the toolbar or File menu.

Chapter rendering intentionally extracts text only. Images, inline styling, contents navigation, bookmarks, search, PDF, and synchronization are not implemented. The package is ad-hoc signed for local development and is not notarized or release-ready.
