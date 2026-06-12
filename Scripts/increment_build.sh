#!/bin/bash

# increment_build.sh
# Increments Xcode build number and optionally creates a git tag.
# Usage:
#   ./Scripts/increment_build.sh           # Just increment build
#   ./Scripts/increment_build.sh --tag     # Increment + create git tag

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

CREATE_TAG=false

# Parse arguments
if [[ "$1" == "--tag" ]]; then
    CREATE_TAG=true
fi

echo "📦 Incrementing build number for GrokCast..."

# Increment build number
xcrun agvtool next-version -all

NEW_BUILD=$(xcrun agvtool what-version | tail -n 1 | xargs)
echo "✅ New build number: $NEW_BUILD"

# Optional: Create git tag
if $CREATE_TAG; then
    VERSION=$(xcrun agvtool what-marketing-version | tail -n 1 | xargs)
    TAG="v${VERSION}-b${NEW_BUILD}"
    
    echo "🏷️  Creating git tag: $TAG"
    git tag -a "$TAG" -m "Build $NEW_BUILD"
    echo "✅ Tag created: $TAG"
fi

echo "Done."