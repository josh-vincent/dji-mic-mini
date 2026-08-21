#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
SOURCE_ICON="$PROJECT_ROOT/Assets/AppIcon.png"
ICNS_PATH="${1:-$PROJECT_ROOT/dist/AppIcon.icns}"
ICONSET_DIR="${2:-$PROJECT_ROOT/dist/AppIcon.iconset}"

if [[ ! -f "$SOURCE_ICON" ]]; then
  echo "Missing source icon: $SOURCE_ICON" >&2
  exit 1
fi

mkdir -p "$ICONSET_DIR" "${ICNS_PATH:h}"
rm -f "$ICONSET_DIR"/icon_*.png(N)

function make_icon() {
  local size="$1"
  local filename="$2"
  sips --resampleHeightWidth "$size" "$size" "$SOURCE_ICON" --out "$ICONSET_DIR/$filename" >/dev/null
}

make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
make_icon 1024 icon_512x512@2x.png

iconutil --convert icns "$ICONSET_DIR" --output "$ICNS_PATH"
echo "$ICNS_PATH"
