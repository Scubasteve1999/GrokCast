#!/bin/bash
# Creates a Release .xcarchive for TestFlight upload via Xcode Organizer.
# Usage:
#   ./Scripts/archive_for_testflight.sh           # archive only
#   ./Scripts/archive_for_testflight.sh --increment   # bump build in project.yml then archive
#
# Build number lives in project.yml (CURRENT_PROJECT_VERSION). Do not rely on
# agvtool — xcodegen regenerate would wipe agvtool-only bumps.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

INCREMENT=false
if [[ "${1:-}" == "--increment" ]]; then
  INCREMENT=true
fi

echo "📦 GrokCast TestFlight archive prep"
echo "   Project: $PROJECT_DIR"

read_project_yml_value() {
  local key="$1"
  # Match `KEY: "value"` or `KEY: value` under project.yml settings.
  sed -nE "s/^[[:space:]]*${key}:[[:space:]]*\"?([^\"]+)\"?[[:space:]]*$/\\1/p" project.yml | head -n 1
}

bump_project_yml_build() {
  local current new
  current="$(read_project_yml_value CURRENT_PROJECT_VERSION)"
  if [[ -z "$current" || ! "$current" =~ ^[0-9]+$ ]]; then
    echo "❌ Could not read CURRENT_PROJECT_VERSION from project.yml"
    exit 1
  fi
  new=$((current + 1))
  # Portable in-place edit (macOS / BSD sed).
  sed -i '' -E "s/^([[:space:]]*CURRENT_PROJECT_VERSION:[[:space:]]*)\"?${current}\"?$/\\1\"${new}\"/" project.yml
  echo "   project.yml CURRENT_PROJECT_VERSION: $current → $new"
}

sync_pbxproj_versions() {
  local marketing build
  marketing="$(read_project_yml_value MARKETING_VERSION)"
  build="$(read_project_yml_value CURRENT_PROJECT_VERSION)"
  if [[ -z "$marketing" || -z "$build" ]]; then
    echo "❌ Could not read MARKETING_VERSION / CURRENT_PROJECT_VERSION from project.yml"
    exit 1
  fi
  # Keep checked-in pbxproj in sync when xcodegen isn't available.
  sed -i '' -E "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = ${build};/g" \
    GrokCast.xcodeproj/project.pbxproj
  sed -i '' -E "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = ${marketing};/g" \
    GrokCast.xcodeproj/project.pbxproj
}

resolve_xcodegen() {
  if command -v xcodegen >/dev/null 2>&1; then
    command -v xcodegen
    return 0
  fi
  for candidate in /opt/homebrew/bin/xcodegen /usr/local/bin/xcodegen; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

if $INCREMENT; then
  echo "🔢 Incrementing build number in project.yml..."
  bump_project_yml_build
fi

MARKETING="$(read_project_yml_value MARKETING_VERSION)"
NEW_BUILD="$(read_project_yml_value CURRENT_PROJECT_VERSION)"
echo "   Version: $MARKETING ($NEW_BUILD)"

if XCODEGEN_BIN="$(resolve_xcodegen)"; then
  echo "🔄 Regenerating Xcode project with $XCODEGEN_BIN..."
  "$XCODEGEN_BIN" generate --spec project.yml
else
  echo "⚠️  xcodegen not found — syncing versions into GrokCast.xcodeproj/project.pbxproj"
  echo "   (Install later with: brew install xcodegen)"
  sync_pbxproj_versions
fi

# Organizer only lists archives under ~/Library/Developer/Xcode/Archives/.
ARCHIVE_DAY="$(date +%Y-%m-%d)"
ARCHIVE_DIR="$HOME/Library/Developer/Xcode/Archives/$ARCHIVE_DAY"
ARCHIVE_PATH="$ARCHIVE_DIR/GrokCast $MARKETING ($NEW_BUILD).xcarchive"
mkdir -p "$ARCHIVE_DIR" "$PROJECT_DIR/build"

echo "🔨 Archiving (Release, generic iOS)..."
echo "   → $ARCHIVE_PATH"
set +e
xcodebuild \
  -project GrokCast.xcodeproj \
  -scheme GrokCast \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  archive 2>&1 | tee "$PROJECT_DIR/build/archive.log"
ARCHIVE_STATUS=${PIPESTATUS[0]}
set -e

if [[ "$ARCHIVE_STATUS" -ne 0 ]]; then
  echo ""
  echo "❌ Archive failed (often Watch App Group provisioning on first archive)."
  echo "   See docs/App-Store-Connect.md → TestFlight upload → Prerequisites"
  echo "   Log: build/archive.log"
  exit "$ARCHIVE_STATUS"
fi

# Keep a stable path copy for scripts / CI that expect build/GrokCast.xcarchive.
rm -rf "$PROJECT_DIR/build/GrokCast.xcarchive"
cp -R "$ARCHIVE_PATH" "$PROJECT_DIR/build/GrokCast.xcarchive"

echo ""
echo "✅ Archive ready (shows in Xcode Organizer):"
echo "   $ARCHIVE_PATH"
echo ""
echo "Next steps (no App Store submit required tonight):"
echo "  1. Open Xcode → Window → Organizer → Archives"
echo "  2. Select GrokCast $MARKETING ($NEW_BUILD) → Distribute App → App Store Connect → Upload"
echo "  3. In App Store Connect → TestFlight → add testers and run device QA"
echo ""
echo "See docs/App-Store-Connect.md and docs/TestFlight-Radar-Widget-Validation-Checklist.md"
