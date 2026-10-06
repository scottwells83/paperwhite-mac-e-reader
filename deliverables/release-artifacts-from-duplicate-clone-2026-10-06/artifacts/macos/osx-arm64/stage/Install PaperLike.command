#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$HERE/PaperLike.app"
TARGET="$HOME/Applications/PaperLike.app"
mkdir -p "$HOME/Applications" "$HOME/Library/Application Support/PaperLike/Books"
if [[ -d "$TARGET" ]]; then
  BACKUP="$HOME/Applications/PaperLike backup $(date +%Y%m%d-%H%M%S).app"
  mv "$TARGET" "$BACKUP"
fi
cp -R "$SOURCE" "$TARGET"
open "$TARGET"
