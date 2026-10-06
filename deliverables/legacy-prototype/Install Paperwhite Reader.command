#!/bin/zsh
set -euo pipefail

PACKAGE_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_APP="$PACKAGE_DIR/Paperwhite Reader.app"
INSTALL_DIR="$HOME/Applications"
SUPPORT_DIR="$HOME/Library/Application Support/Paperwhite Reader"
DESTINATION="$INSTALL_DIR/Paperwhite Reader.app"

if [[ ! -d "$SOURCE_APP" ]]; then
  echo "Could not find Paperwhite Reader.app beside this installer."
  echo "Keep the app and installer together, then try again."
  echo "Press Return to close."
  read -r
  exit 1
fi

mkdir -p "$INSTALL_DIR" "$SUPPORT_DIR/Books"
if [[ -e "$DESTINATION" ]]; then
  echo "An installed copy already exists at:"
  echo "  $DESTINATION"
  printf "Replace it? The current copy will be kept as a dated backup. [y/N] "
  read -r answer
  if [[ ! "$answer" =~ '^[Yy]$' ]]; then
    echo "Installation cancelled."
    exit 0
  fi
  backup="$INSTALL_DIR/Paperwhite Reader backup $(date +%Y%m%d-%H%M%S).app"
  mv "$DESTINATION" "$backup"
  echo "Previous app saved at: $backup"
fi

ditto "$SOURCE_APP" "$DESTINATION"
echo
echo "Paperwhite Reader installed at:"
echo "  $DESTINATION"
echo "Your EPUB library will be stored at:"
echo "  $SUPPORT_DIR/Books"
echo "The library index and reading positions stay in that Paperwhite Reader folder."
open "$DESTINATION"
