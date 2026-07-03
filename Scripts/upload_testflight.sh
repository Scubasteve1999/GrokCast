#!/bin/bash
# Exports an existing archive and uploads to TestFlight (optional automation).
# Requires Xcode 16+ and valid codesigning. Run AFTER archive_for_testflight.sh.
#
# Usage:
#   ./Scripts/upload_testflight.sh
#
# For API key upload, set:
#   APP_STORE_CONNECT_API_KEY_ID
#   APP_STORE_CONNECT_ISSUER_ID
#   APP_STORE_CONNECT_API_KEY_PATH  (AuthKey_XXXX.p8)

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE_PATH="$PROJECT_DIR/build/GrokCast.xcarchive"
EXPORT_DIR="$PROJECT_DIR/build/export"
EXPORT_OPTIONS="$PROJECT_DIR/Scripts/ExportOptions.plist"

if [[ ! -d "$ARCHIVE_PATH" ]]; then
  echo "❌ Missing archive. Run ./Scripts/archive_for_testflight.sh first."
  exit 1
fi

mkdir -p "$EXPORT_DIR"

echo "📤 Exporting IPA for App Store Connect..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

IPA=$(find "$EXPORT_DIR" -name "*.ipa" | head -n 1)
if [[ -z "$IPA" ]]; then
  echo "❌ Export failed — no IPA found in $EXPORT_DIR"
  exit 1
fi

echo "   IPA: $IPA"

if [[ -n "${APP_STORE_CONNECT_API_KEY_ID:-}" && -n "${APP_STORE_CONNECT_ISSUER_ID:-}" && -n "${APP_STORE_CONNECT_API_KEY_PATH:-}" ]]; then
  echo "🚀 Uploading via App Store Connect API..."
  xcrun altool --upload-app \
    --type ios \
    --file "$IPA" \
    --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
    --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"
  echo "✅ Upload submitted. Check App Store Connect → TestFlight for processing."
else
  echo ""
  echo "ℹ️  API keys not set. Upload manually:"
  echo "   Xcode → Organizer → Distribute App → App Store Connect"
  echo ""
  echo "Or export API key env vars and re-run this script."
fi
