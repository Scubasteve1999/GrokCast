#!/bin/sh
#
# Xcode Cloud runs this automatically after cloning, before resolving packages
# and building. `.github/workflows/ci.yml` invokes this same script, so there is
# one implementation rather than two copies to keep in sync.
#
# The real key files are gitignored by design, so a fresh clone does not have
# them and the build cannot resolve DeveloperAPIKey / OpenWeatherMapKeys.
#
# Two sources fill them, in order:
#
#   1. A secret environment variable holding the base64 of the real file. This is
#      what a TestFlight archive needs.
#   2. The committed template, which is correct for PR validation builds: those
#      only need to compile and run tests, and should not carry real secrets.
#
# Populate the secrets on the Xcode Cloud workflow with:
#   base64 -i GrokCast/Config/DeveloperAPIKey.swift | pbcopy
#   base64 -i GrokCast/Config/OpenWeatherMapKeys.swift | pbcopy
#
# A file that ends up holding placeholder values is fatal for an archive and
# fine for a PR build, so the outcome depends on CI_XCODEBUILD_ACTION rather
# than on a warning nobody reads: builds 104-110 shipped placeholder keys to
# TestFlight green, which is what this gate exists to make impossible.
#
# Config/Secrets.xcconfig deliberately has no stub: Config/Shared.xcconfig pulls
# it in with `#include?`, which tolerates the file being absent.

set -eu

# Xcode Cloud starts this script in ci_scripts/; everything below is addressed
# from the repo root.
cd "$(dirname "$0")/.."

# Xcode Cloud sets this to `archive` for the runs that upload to TestFlight.
# Absent on GitHub Actions and on local runs, which is the safe default: those
# are the builds that legitimately use placeholders.
is_archive_build() {
  [ "${CI_XCODEBUILD_ACTION:-}" = "archive" ]
}

# Xcode Cloud builds the committed project.pbxproj; GitHub Actions regenerates it
# with XcodeGen from project.yml, which globs the Config directory rather than
# naming files. So a file that is a hard build input on Xcode Cloud can be
# legitimately absent on GitHub Actions.
is_xcode_cloud() {
  [ -n "${CI_XCODE_CLOUD:-}${CI_XCODEBUILD_ACTION:-}${CI_WORKFLOW:-}" ]
}

# Files that came from a template, or from a secret that turned out to hold the
# template's own placeholder values. Space-separated; paths here never contain
# spaces.
placeholder_files=""

# Every variable is `_cfg_`-prefixed. POSIX sh has no `local`, so a plain name
# like `target` would be a global shared with any caller's loop variable.
#
# $1 target path, $2 env var name, $3 validator function, $4 required|optional
restore_config() {
  _cfg_target="$1"
  _cfg_var="$2"
  _cfg_validate="$3"
  _cfg_requirement="$4"
  _cfg_template="$_cfg_target.example"

  if [ -f "$_cfg_target" ]; then
    # Only reachable outside CI — the file is gitignored, so a fresh clone never
    # has it. Still validated: a stale local file is exactly how a placeholder
    # gets past everything else.
    echo "↷ $_cfg_target already present — leaving it alone"
  else
    _cfg_encoded=$(printenv "$_cfg_var" 2>/dev/null || true)

    if [ -n "$_cfg_encoded" ]; then
      # Guarded rather than bare: invalid base64 makes this pipeline exit
      # non-zero, and under `set -e` that would kill the script before the
      # diagnostic runs.
      if ! printf '%s' "$_cfg_encoded" | base64 --decode > "$_cfg_target" 2>/dev/null; then
        echo "❌ $_cfg_var is not valid base64" >&2
        echo "   encoded chars: ${#_cfg_encoded}" >&2
        echo "   A re-saved variable can come back as its own '**********' mask." >&2
        echo "   Re-add it: base64 -i $_cfg_target | pbcopy" >&2
        rm -f "$_cfg_target"
        exit 1
      fi

      if ! "$_cfg_validate" "$_cfg_target"; then
        echo "❌ $_cfg_var did not decode to a usable $_cfg_target" >&2
        echo "   encoded chars: ${#_cfg_encoded}" >&2
        echo "   decoded bytes: $(wc -c < "$_cfg_target" | tr -d ' ')" >&2
        echo "   Re-add it: base64 -i $_cfg_target | pbcopy" >&2
        rm -f "$_cfg_target"
        exit 1
      fi

      echo "✅ Created $_cfg_target from $_cfg_var"
    elif [ -f "$_cfg_template" ]; then
      cp "$_cfg_template" "$_cfg_target"
      echo "⚠️  Created $_cfg_target from $(basename "$_cfg_template") — PLACEHOLDER KEYS"
      placeholder_files="$placeholder_files $_cfg_target"
    elif [ "$_cfg_requirement" = "xcode-cloud" ] && ! is_xcode_cloud; then
      # Not a build input here, and there is no template to stub from. Say so
      # rather than failing: this is the normal GitHub Actions state.
      echo "↷ $_cfg_target absent and not required outside Xcode Cloud"
      return 0
    else
      echo "❌ $_cfg_target is missing: $_cfg_var is unset or empty, and" >&2
      echo "   $_cfg_template does not exist to stub from." >&2
      exit 1
    fi
  fi

  # A secret can decode to valid, correctly-named, fully-parsing Swift and still
  # be the placeholder template — that is how build 110 shipped with no
  # OpenWeatherMap key while the log showed a green checkmark. Compared here
  # rather than inside the validator so it also catches a stale local file.
  if [ -f "$_cfg_template" ] && cmp -s "$_cfg_target" "$_cfg_template"; then
    case " $placeholder_files " in
      *" $_cfg_target "*) ;;
      *)
        echo "⚠️  $_cfg_target is byte-identical to its template — PLACEHOLDER KEYS" >&2
        placeholder_files="$placeholder_files $_cfg_target"
        ;;
    esac
  fi

  if [ "$_cfg_requirement" = "required" ] && is_archive_build; then
    case " $placeholder_files " in
      *" $_cfg_target "*)
        echo "❌ $_cfg_target holds placeholder keys and this is an archive build." >&2
        echo "   Distributing it would ship no Mapbox token (Radar renders black)," >&2
        echo "   no Xweather credentials and no xAI key." >&2
        echo "   Set $_cfg_var on the workflow: base64 -i $_cfg_target | pbcopy" >&2
        exit 1
        ;;
    esac
  fi
}

# Truncation is the likeliest way a secret goes wrong, and it is invisible to a
# symbol grep: `enum DeveloperAPIKey` sits near the top of the file, so any
# prefix-truncated paste still matches. base64 does not help either — it decodes
# a truncated stream and exits 0. Parsing is what actually catches it.
validate_swift() {
  _v_target="$1"
  _v_symbol="enum $(basename "$_v_target" .swift)"

  if ! grep -q "$_v_symbol" "$_v_target"; then
    echo "   (does not declare $_v_symbol — wrong file?)" >&2
    return 1
  fi
  if ! xcrun swiftc -parse "$_v_target" >/dev/null 2>&1; then
    echo "   (does not parse as Swift — truncated paste?)" >&2
    return 1
  fi
}

# `plutil -lint` alone is not enough: a bare string is a valid OpenStep plist, so
# garbage that decodes to plain text passes it. BUNDLE_ID is checked too, because
# a plist from another Firebase project parses perfectly and then silently
# registers push against the wrong app.
validate_google_plist() {
  _v_target="$1"
  _v_expected_bundle="com.scubasteve1999.GrokCast"

  if ! plutil -extract GOOGLE_APP_ID raw -o - "$_v_target" >/dev/null 2>&1; then
    echo "   (no GOOGLE_APP_ID — not a Firebase plist)" >&2
    return 1
  fi

  _v_bundle=$(plutil -extract BUNDLE_ID raw -o - "$_v_target" 2>/dev/null || true)
  if [ "$_v_bundle" != "$_v_expected_bundle" ]; then
    echo "   (BUNDLE_ID is '$_v_bundle', expected '$_v_expected_bundle')" >&2
    return 1
  fi
}

# GoogleService-Info.plist is required because the committed project.pbxproj
# lists it as a bundled resource, so its absence is a hard build error. It has no
# template on purpose — a stub would ship broken Firebase Messaging rather than
# failing loudly — which `restore_config` reports as the missing-template case.
restore_config \
  GrokCast/Config/GoogleService-Info.plist \
  GOOGLE_SERVICE_INFO_PLIST_BASE64 \
  validate_google_plist \
  xcode-cloud

# Holds the Mapbox token, Xweather credentials and the xAI key: the file whose
# absence produced the black Radar map.
restore_config \
  GrokCast/Config/DeveloperAPIKey.swift \
  DEVELOPER_API_KEY_SWIFT_BASE64 \
  validate_swift \
  required

# Optional: no real OpenWeatherMap key exists yet, so the committed placeholder
# is the current state of the world rather than a misconfiguration. Promote this
# to `required` once a real key is issued.
restore_config \
  GrokCast/Config/OpenWeatherMapKeys.swift \
  OPENWEATHERMAP_KEYS_SWIFT_BASE64 \
  validate_swift \
  optional

if [ -n "$placeholder_files" ]; then
  echo "⚠️  Building with placeholder keys for:$placeholder_files" >&2
  if is_archive_build; then
    echo "   These are the optional ones; the required files are real." >&2
  else
    echo "   Expected for PR validation — this build is not being distributed." >&2
  fi
fi
