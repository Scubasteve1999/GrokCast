#!/bin/sh
#
# Xcode Cloud runs this automatically after cloning, before resolving packages
# and building. It is the Xcode Cloud counterpart to the "Stub gitignored config
# files from templates" step in .github/workflows/ci.yml — keep the two in sync.
#
# The real key files are gitignored by design, so a fresh clone does not have
# them and the build cannot resolve DeveloperAPIKey / OpenWeatherMapKeys. The
# committed templates carry nil/placeholder values, so this never puts a real
# secret on a build machine.
#
# Config/Secrets.xcconfig deliberately has no stub: Config/Shared.xcconfig pulls
# it in with `#include?`, which tolerates the file being absent.

set -eu

# Xcode Cloud starts this script in ci_scripts/; the templates are addressed
# from the repo root.
cd "$(dirname "$0")/.."

for template in GrokCast/Config/*.example; do
  [ -e "$template" ] || continue
  target="${template%.example}"
  if [ -f "$target" ]; then
    echo "↷ $target already present — leaving it alone"
  else
    cp "$template" "$target"
    echo "✅ Created $target from $(basename "$template")"
  fi
done

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
