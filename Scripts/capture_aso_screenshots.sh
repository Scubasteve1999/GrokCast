#!/bin/bash
# Captures App Store marketing screenshots from DEBUG marketing compositions.
# Requires a booted iOS Simulator and a successful simulator build.
#
# Usage: ./Scripts/capture_aso_screenshots.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

OUT_DIR="$PROJECT_DIR/Marketing/AppStore"
SCHEME="GrokCast"
BUNDLE_ID="com.scubasteve1999.GrokCast"
SIM_NAME="${SIM_NAME:-iPhone 17 Pro Max}"
DERIVED="$PROJECT_DIR/build/DerivedData"

mkdir -p "$OUT_DIR"

echo "📸 ASO screenshot capture → $OUT_DIR"

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate >/dev/null
else
  /opt/homebrew/bin/xcodegen generate >/dev/null
fi

echo "🔨 Building Debug for simulator..."
xcodebuild \
  -project GrokCast.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=$SIM_NAME" \
  -derivedDataPath "$DERIVED" \
  build >/dev/null

APP_PATH=$(find "$DERIVED/Build/Products" -name "GrokCast.app" -type d | head -n 1)
if [[ -z "$APP_PATH" ]]; then
  echo "❌ Could not find GrokCast.app in $DERIVED"
  exit 1
fi

SIM_UDID=$(xcrun simctl list devices available | grep "$SIM_NAME" | grep -oE '[A-F0-9-]{36}' | head -n 1)
if [[ -z "$SIM_UDID" ]]; then
  echo "❌ Simulator not found: $SIM_NAME"
  exit 1
fi

xcrun simctl boot "$SIM_UDID" 2>/dev/null || true
xcrun simctl bootstatus "$SIM_UDID" -b

xcrun simctl install "$SIM_UDID" "$APP_PATH"

capture() {
  local mode="$1"
  local outfile="$2"
  echo "   → $mode → $outfile"
  xcrun simctl terminate "$SIM_UDID" "$BUNDLE_ID" 2>/dev/null || true
  sleep 0.5
  xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID" -MarketingScreenshot "$mode" >/dev/null
  sleep 2
  xcrun simctl io "$SIM_UDID" screenshot "$OUT_DIR/$outfile"
}

capture today "01-today.png"
capture radar "02-radar.png"
capture grok "03-grok.png"

echo ""
echo "✅ Screenshots saved to Marketing/AppStore/"
echo "   Upload the 6.7\" set in App Store Connect when ready (see docs/App-Store-Connect.md)"
