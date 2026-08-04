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
