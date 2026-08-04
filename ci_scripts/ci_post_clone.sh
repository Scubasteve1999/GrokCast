#!/bin/sh
#
# Xcode Cloud runs this automatically after cloning, before resolving packages
# and building. It is the Xcode Cloud counterpart to the "Stub gitignored config
# files from templates" step in .github/workflows/ci.yml — keep the two in sync.
#
# The real key files are gitignored by design, so a fresh clone does not have
# them and the build cannot resolve DeveloperAPIKey / OpenWeatherMapKeys.
#
# Two sources fill them, in order:
#
#   1. A secret environment variable holding the base64 of the real file. This is
#      what a TestFlight archive needs — the committed templates are all `nil`,
#      so a build stubbed from them compiles and ships with no Mapbox token, no
#      Xweather credentials and no xAI key. That failure is silent at build time
#      and only shows up on device (a black Radar map, AI features unavailable).
#   2. The committed template, which is correct for PR validation builds: those
#      only need to compile and run tests, and should not carry real secrets.
#
# Populate the secrets on the Xcode Cloud workflow with:
#   base64 -i GrokCast/Config/DeveloperAPIKey.swift | pbcopy
#   base64 -i GrokCast/Config/OpenWeatherMapKeys.swift | pbcopy
#
# Config/Secrets.xcconfig deliberately has no stub: Config/Shared.xcconfig pulls
# it in with `#include?`, which tolerates the file being absent.

set -eu

# Xcode Cloud starts this script in ci_scripts/; the templates are addressed
# from the repo root.
cd "$(dirname "$0")/.."

# Writes $2 (base64) to $1, then checks the result declares $3 so a truncated or
# mis-pasted secret fails here rather than as an opaque compile error later.
# The value is only ever piped, never echoed, so it stays out of the build log.
restore_swift_config() {
  target="$1"
  encoded="$2"
  expected_symbol="$3"

  printf '%s' "$encoded" | base64 --decode > "$target"
  if grep -q "$expected_symbol" "$target"; then
    echo "✅ Created $target from secret environment variable"
  else
    echo "❌ Secret for $target did not decode to Swift declaring $expected_symbol" >&2
    rm -f "$target"
    exit 1
  fi
}

if [ -f GrokCast/Config/DeveloperAPIKey.swift ]; then
  echo "↷ GrokCast/Config/DeveloperAPIKey.swift already present — leaving it alone"
elif [ -n "${DEVELOPER_API_KEY_SWIFT_BASE64:-}" ]; then
  restore_swift_config \
    GrokCast/Config/DeveloperAPIKey.swift \
    "$DEVELOPER_API_KEY_SWIFT_BASE64" \
    "enum DeveloperAPIKey"
fi

if [ -f GrokCast/Config/OpenWeatherMapKeys.swift ]; then
  echo "↷ GrokCast/Config/OpenWeatherMapKeys.swift already present — leaving it alone"
elif [ -n "${OPENWEATHERMAP_KEYS_SWIFT_BASE64:-}" ]; then
  restore_swift_config \
    GrokCast/Config/OpenWeatherMapKeys.swift \
    "$OPENWEATHERMAP_KEYS_SWIFT_BASE64" \
    "enum OpenWeatherMapKeys"
fi

# Anything still missing falls back to its template. Whether that is fine depends
# entirely on where the build is going, so say so loudly rather than silently.
stubbed_from_template=""
for template in GrokCast/Config/*.example; do
  [ -e "$template" ] || continue
  target="${template%.example}"
  if [ -f "$target" ]; then
    echo "↷ $target already present — leaving it alone"
  else
    cp "$template" "$target"
    stubbed_from_template="$stubbed_from_template $target"
    echo "⚠️  Created $target from $(basename "$template") — PLACEHOLDER KEYS"
  fi
done

if [ -n "$stubbed_from_template" ]; then
  echo "⚠️  Building with placeholder keys for:$stubbed_from_template" >&2
  echo "   Fine for PR validation. A build distributed to TestFlight this way has" >&2
  echo "   no Mapbox token (Radar renders black), no Xweather credentials and no" >&2
  echo "   xAI key. Set the secret environment variables above to ship real keys." >&2
fi

# GoogleService-Info.plist is gitignored but IS referenced by the committed
# project.pbxproj as a bundled resource, so its absence is a hard build error —
# this is what "Build input file cannot be found" was. It gets no placeholder
# template on purpose: this archive ships to TestFlight, and a stub plist would
# ship broken Firebase Messaging rather than failing loudly.
#
# Supply it as a secret Xcode Cloud environment variable holding the base64 of
# the real file:
#   base64 -i GrokCast/Config/GoogleService-Info.plist | pbcopy
GOOGLE_PLIST="GrokCast/Config/GoogleService-Info.plist"
if [ -f "$GOOGLE_PLIST" ]; then
  echo "↷ $GOOGLE_PLIST already present — leaving it alone"
elif [ -n "${GOOGLE_SERVICE_INFO_PLIST_BASE64:-}" ]; then
  printf '%s' "$GOOGLE_SERVICE_INFO_PLIST_BASE64" | base64 --decode > "$GOOGLE_PLIST"
  # A truncated or mis-pasted secret yields a file that is present but wrong,
  # which fails much later and far less clearly than a missing one. `plutil -lint`
  # alone is not enough: a bare string is a valid OpenStep plist, so garbage that
  # decodes to plain text passes it. Require a key Firebase actually reads.
  if plutil -extract GOOGLE_APP_ID raw -o - "$GOOGLE_PLIST" >/dev/null 2>&1; then
    echo "✅ Created $GOOGLE_PLIST from GOOGLE_SERVICE_INFO_PLIST_BASE64"
  else
    echo "❌ GOOGLE_SERVICE_INFO_PLIST_BASE64 did not decode to a valid plist" >&2
    rm -f "$GOOGLE_PLIST"
    exit 1
  fi
else
  echo "❌ $GOOGLE_PLIST is missing and GOOGLE_SERVICE_INFO_PLIST_BASE64 is not set." >&2
  echo "   Add it as a secret environment variable on the Xcode Cloud workflow:" >&2
  echo "   base64 -i $GOOGLE_PLIST | pbcopy" >&2
  exit 1
fi
