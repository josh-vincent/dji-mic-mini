#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_ROOT/dist}"
VERSION="${VERSION:-0.1.0}"
APP_NAME="MicTrigger"
VOLUME_NAME="MicTrigger"
DMG_PATH="$OUTPUT_DIR/$APP_NAME-$VERSION.dmg"
BACKGROUND_SOURCE="$PROJECT_ROOT/Assets/DMGBackground.png"

mkdir -p "$OUTPUT_DIR"
TEMP_DIR="$(mktemp -d "$OUTPUT_DIR/.dmg-build.XXXXXX")"
MOUNT_POINT=""
DEVICE=""

function cleanup() {
  if [[ -n "$DEVICE" ]]; then
    hdiutil detach "$DEVICE" -quiet || true
  fi
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

OUTPUT_DIR="$OUTPUT_DIR" "$PROJECT_ROOT/scripts/build-app.sh"

STAGING_DIR="$TEMP_DIR/staging"
BACKGROUND_DIR="$STAGING_DIR/.background"
mkdir -p "$STAGING_DIR" "$BACKGROUND_DIR"
ditto "$OUTPUT_DIR/$APP_NAME.app" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"
cp "$OUTPUT_DIR/$APP_NAME.app/Contents/Resources/AppIcon.icns" "$STAGING_DIR/.VolumeIcon.icns"

# Crop the generated 3:2 artwork to a 16:10 installer window without stretching it.
sips --cropToHeightWidth 960 1536 "$BACKGROUND_SOURCE" --out "$TEMP_DIR/background-cropped.png" >/dev/null
sips --resampleHeightWidth 400 640 "$TEMP_DIR/background-cropped.png" --out "$BACKGROUND_DIR/background.png" >/dev/null

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -fs HFS+ \
  -format UDRW \
  -ov \
  "$TEMP_DIR/read-write.dmg" >/dev/null

ATTACH_OUTPUT="$(hdiutil attach "$TEMP_DIR/read-write.dmg" -readwrite -noverify -noautoopen -nobrowse)"
DEVICE="$(print -r -- "$ATTACH_OUTPUT" | awk '/Apple_HFS/ {print $1; exit}')"
MOUNT_POINT="$(print -r -- "$ATTACH_OUTPUT" | awk '/Apple_HFS/ {print $3; exit}')"
if [[ -z "$DEVICE" || -z "$MOUNT_POINT" ]]; then
  echo "Could not determine mounted DMG device." >&2
  exit 1
fi

SetFile -a C "$MOUNT_POINT"
SetFile -a V "$MOUNT_POINT/.background" "$MOUNT_POINT/.VolumeIcon.icns"

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOLUME_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set pathbar visible of container window to false
    set bounds of container window to {120, 120, 760, 520}
    set viewOptions to icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 112
    set text size of viewOptions to 13
    set label position of viewOptions to bottom
    set background picture of viewOptions to file ".background:background.png"
    set position of item "$APP_NAME.app" of container window to {165, 205}
    set position of item "Applications" of container window to {475, 205}
    close
    open
    update without registering applications
    delay 2
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$DEVICE" -quiet
DEVICE=""

rm -f "$DMG_PATH"
hdiutil convert "$TEMP_DIR/read-write.dmg" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  -o "$DMG_PATH" >/dev/null

if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  codesign --force --timestamp=none --sign "$SIGNING_IDENTITY" "$DMG_PATH"
fi

hdiutil verify "$DMG_PATH" >/dev/null
echo "$DMG_PATH"
