#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
CONFIGURATION="${CONFIGURATION:-release}"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_ROOT/dist}"
APP_DIR="$OUTPUT_DIR/MicTrigger.app"

cd "$PROJECT_ROOT"
swift build -c "$CONFIGURATION" --product MicTrigger
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
install -m 755 "$BIN_DIR/MicTrigger" "$APP_DIR/Contents/MacOS/MicTrigger"

/usr/libexec/PlistBuddy -c "Clear dict" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string MicTrigger" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.mictrigger.app" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleName string MicTrigger" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string MicTrigger" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 0.1.0" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 14.0" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :NSHumanReadableCopyright string 'MicTrigger contributors'" "$APP_DIR/Contents/Info.plist"

SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
  SIGNING_IDENTITY="$(security find-identity -v -p codesigning | awk -F\" '/Developer ID Application:/{print $2; exit}')"
fi
if [[ -z "$SIGNING_IDENTITY" ]]; then
  SIGNING_IDENTITY="$(security find-identity -v -p codesigning | awk -F\" '/Apple Development:/{print $2; exit}')"
fi

if [[ -n "$SIGNING_IDENTITY" ]]; then
  codesign --force --deep --options runtime --timestamp=none --sign "$SIGNING_IDENTITY" "$APP_DIR"
  echo "Signed with: $SIGNING_IDENTITY"
else
  codesign --force --deep --sign - "$APP_DIR"
  echo "Warning: no stable signing identity found; permissions may need approval after each rebuild."
fi

DESIGNATED_REQUIREMENT="$(codesign -d --requirements - "$APP_DIR" 2>&1)"
if [[ "$DESIGNATED_REQUIREMENT" == *"cdhash"* ]]; then
  echo "Warning: this bundle has a code-hash identity. Rebuilding it will reset macOS permissions."
fi
echo "$APP_DIR"
