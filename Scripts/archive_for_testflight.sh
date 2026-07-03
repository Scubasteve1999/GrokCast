#!/bin/bash
# Creates a Release .xcarchive for TestFlight upload via Xcode Organizer.
# Usage:
#   ./Scripts/archive_for_testflight.sh           # archive only
#   ./Scripts/archive_for_testflight.sh --increment   # bump build then archive

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

INCREMENT=false
if [[ "${1:-}" == "--increment" ]]; then
  INCREMENT=true
fi

echo "📦 GrokCast TestFlight archive prep"
echo "   Project: $PROJECT_DIR"

if $INCREMENT; then
  echo "🔢 Incrementing build number..."
  xcrun agvtool next-version -all
fi

NEW_BUILD=$(xcrun agvtool what-version | tail -n 1 | xargs)
MARKETING=$(xcrun agvtool what-marketing-version | tail -n 1 | xargs)
echo "   Version: $MARKETING ($NEW_BUILD)"

echo "🔄 Regenerating Xcode project..."
if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
else
  /opt/homebrew/bin/xcodegen generate
fi

ARCHIVE_PATH="$PROJECT_DIR/build/GrokCast.xcarchive"
mkdir -p "$PROJECT_DIR/build"

echo "🔨 Archiving (Release, generic iOS)..."
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

echo ""
echo "✅ Archive ready:"
echo "   $ARCHIVE_PATH"
echo ""
echo "Next steps (no App Store submit required tonight):"
echo "  1. Open Xcode → Window → Organizer"
echo "  2. Select GrokCast $MARKETING ($NEW_BUILD) → Distribute App → App Store Connect → Upload"
echo "  3. In App Store Connect → TestFlight → add testers and run device QA"
echo ""
echo "See docs/App-Store-Connect.md and docs/TestFlight-Radar-Widget-Validation-Checklist.md"
