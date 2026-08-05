#!/bin/bash

# increment_build.sh
# Increments the build number and optionally creates a git tag.
# Usage:
#   ./Scripts/increment_build.sh           # Just increment build
#   ./Scripts/increment_build.sh --tag     # Increment + create git tag
#
# The build number lives in project.yml (CURRENT_PROJECT_VERSION), which is the
# source of truth. This script previously used `agvtool`, which writes to
# DayCast.xcodeproj/project.pbxproj — a file xcodegen regenerates from
# project.yml, so the bump was silently reverted by the next `xcodegen generate`.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

PROJECT_YML="project.yml"
XCODEPROJ_PBX="DayCast.xcodeproj/project.pbxproj"
CREATE_TAG=false

if [[ "${1:-}" == "--tag" ]]; then
    CREATE_TAG=true
fi

[[ -f "$PROJECT_YML" ]] || { echo "❌ $PROJECT_YML not found"; exit 1; }

echo "📦 Incrementing build number for DayCast..."

CURRENT_BUILD=$(grep -E '^[[:space:]]*CURRENT_PROJECT_VERSION:' "$PROJECT_YML" \
    | head -1 | sed -E 's/.*"([0-9]+)".*/\1/')

if ! [[ "$CURRENT_BUILD" =~ ^[0-9]+$ ]]; then
    echo "❌ Could not parse CURRENT_PROJECT_VERSION from $PROJECT_YML"
    exit 1
fi

NEW_BUILD=$((CURRENT_BUILD + 1))

# Only the CURRENT_PROJECT_VERSION line, and only its quoted number.
sed -i '' -E "s/^([[:space:]]*CURRENT_PROJECT_VERSION:[[:space:]]*)\"${CURRENT_BUILD}\"/\1\"${NEW_BUILD}\"/" "$PROJECT_YML"

WROTE=$(grep -E '^[[:space:]]*CURRENT_PROJECT_VERSION:' "$PROJECT_YML" | head -1 | sed -E 's/.*"([0-9]+)".*/\1/')
if [[ "$WROTE" != "$NEW_BUILD" ]]; then
    echo "❌ Failed to write build $NEW_BUILD to $PROJECT_YML (still $WROTE)"
    exit 1
fi

echo "✅ Build number: $CURRENT_BUILD → $NEW_BUILD"

# Regenerate so DayCast.xcodeproj actually carries the new build — without this
# the bump exists only in project.yml and any archive still ships the old number.
if command -v xcodegen >/dev/null 2>&1; then
    echo "⚙️  Regenerating Xcode project..."
    xcodegen generate >/dev/null
    echo "✅ DayCast.xcodeproj regenerated"
else
    echo "⚠️  xcodegen not found — run 'xcodegen generate' before archiving,"
    echo "   or the build will still be $CURRENT_BUILD."
fi

if $CREATE_TAG; then
    VERSION=$(grep -E '^[[:space:]]*MARKETING_VERSION:' "$PROJECT_YML" \
        | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
    TAG="v${VERSION}-b${NEW_BUILD}"

    # Commit the bump before tagging — the bump is uncommitted by definition at
    # this point, so tagging HEAD would point at a commit without build
    # $NEW_BUILD. Only the two files this script touches are committed; anything
    # else in the working tree is left staged exactly as the user had it.
    # Only commit paths that are actually tracked — the pbxproj is generated and
    # may be gitignored or absent, and `git commit -- <path>` errors on unknown
    # pathspecs rather than skipping them.
    BUMP_PATHS=()
    for path in "$PROJECT_YML" "$XCODEPROJ_PBX"; do
        if git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
            BUMP_PATHS+=("$path")
        fi
    done

    if ! git diff --quiet -- "${BUMP_PATHS[@]}"; then
        echo "📝 Committing build bump..."
        git add -- "${BUMP_PATHS[@]}"
        git commit -q -m "Bump build to $NEW_BUILD" -- "${BUMP_PATHS[@]}"
        echo "✅ Committed build $NEW_BUILD"
    fi

    if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
        echo "⚠️  Tag $TAG already exists — leaving it alone."
    else
        echo "🏷️  Creating git tag: $TAG"
        git tag -a "$TAG" -m "Build $NEW_BUILD"
        echo "✅ Tag created: $TAG"
    fi
fi

echo "Done."
