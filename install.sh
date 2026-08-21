#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="${0:A:h}"
TARGET_APP="/Applications/MicTrigger.app"

OUTPUT_DIR="$PROJECT_ROOT/dist" "$PROJECT_ROOT/scripts/build-app.sh"

if [[ -d "$TARGET_APP" ]]; then
  BACKUP_APP="$PROJECT_ROOT/dist/MicTrigger.previous.app"
  ditto "$TARGET_APP" "$BACKUP_APP"
fi

ditto "$PROJECT_ROOT/dist/MicTrigger.app" "$TARGET_APP"
open "$TARGET_APP"

echo "MicTrigger is installed. Click its microphone icon in the menu bar to finish permissions."
