# Agent tooling handoff — build, run, screenshot, upload

For any coding agent (Cursor, Claude Code, etc.) working on DayCast. Everything below is already installed and configured on this Mac (set up 2026-07-11, tooling re-verified 2026-07-30).

State as of 2026-07-30: **v1.0.5 build 75** on `main`, compiles clean, PostHog product analytics shipped in code. Outstanding before submission — App Privacy labels applied in the App Store Connect UI (`docs/App-Privacy-1.0.5.md`), archive + upload of build 75, and PostHog Live event verification from a real device or TestFlight build.

> Version numbers go stale in this doc faster than anything else. `project.yml` (`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`) is the only source of truth — trust it over this line.

## Working tree

Same path as `AGENTS.md` / `CLAUDE.md`. Do not invent a second clone.

| Path | Use for |
|------|---------|
| `~/Projects/GrokCast` | **Everything** — edits, commits, builds, simulator runs, archiving, fastlane |
| `~/Documents/GrokCast` | Nothing — iCloud-synced mirror; git and xcodebuild can hang |
| `~/Desktop/DayCast` / `~/Documents/DayCast` | Nothing — dead leftovers. Not canonical. |

Workflow: edit, commit, and build in `~/Projects/GrokCast` on `main`. Never build or archive from an iCloud-backed tree.

## XcodeBuildMCP (build / run / drive the app)

- Installed globally: `/opt/homebrew/bin/xcodebuildmcp` (v2.6.2, Node via Homebrew).
- Registered in `~/.cursor/mcp.json` and Claude Code (`~/.claude.json`) with env `XCODEBUILDMCP_ENABLED_WORKFLOWS=simulator,simulator-management,ui-automation,debugging,project-discovery` (52 tools: build_run_sim, screenshot, snapshot_ui, tap/swipe/type_text, LLDB attach/breakpoints).
- Set session defaults first: projectPath `~/Projects/GrokCast/DayCast.xcodeproj`, scheme `DayCast`, simulator iPhone 17 Pro Max (UDID `39C3B630-9A6E-4F5F-BE26-2A5A84FF76DE`; iPad Pro 13" M5 is `EACF8950-D3C0-4D22-B2C8-46163C736E2C`). Then `build_run_sim` with empty args.
  - UDIDs verified 2026-07-30 (iOS 26.5 runtime). **They are not stable** — Xcode/runtime updates delete and recreate simulators with fresh UDIDs, so a "No booted simulator named X" error usually means the UDID rotated, not that the device is gone. Re-derive rather than trusting this line:
    ```bash
    xcrun simctl list devices available | grep -i "iphone 17 pro max\|ipad pro 13"
    ```
- Every tool also works one-shot from the CLI, e.g.:
  ```bash
  xcodebuildmcp ui-automation snapshot-ui --simulator-id <udid> --output json
  xcodebuildmcp ui-automation tap --simulator-id <udid> --element-ref e42
  ```
- **UI-automation gotchas:** element refs go stale after every navigation — re-run snapshot-ui before each tap. On iPad the tab bar lists each tab twice (hidden sidebar entry + visible tab); tap the LAST ref of the pair or nothing happens.

## API keys (never commit)

`DayCast/Config/DeveloperAPIKey.swift` — gitignored, exists in the working tree, currently has real xai / mapbox / xweather values. Without it: Grok features show "Add key" empty states and the Radar Mapbox map renders black. Values must be quoted Swift strings.

## App Store screenshots

1. Boot sim, set marketing status bar:
   `xcrun simctl status_bar <udid> override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3`
2. Drive the app to each screen (Today, Forecast, Radar — allow ~10 s for tiles, Alerts, AI).
3. Capture **full-res** with `xcrun simctl io <udid> screenshot <file>.png` (MCP screenshot tool downscales — App Store rejects it).
4. Required sizes: iPhone 17 Pro Max → 1320×2868 (6.9" slot), iPad Pro 13" → 2064×2752.
5. Files live in `fastlane/screenshots/en-US/` — `01–05_*.png` iPhone, `06–10_ipad_*.png` iPad. Filename order = App Store display order.

## fastlane (upload screenshots / metadata)

- Auth: `fastlane/asc_api_key.json` (gitignored) — embeds the .p8 content inline (this fastlane version rejects `key_filepath`). Key ID `ZCMMSMJLQD`, key file `fastlane/AuthKey_ZCMMSMJLQD.p8`. Recreate via `fastlane/README-KEY.md`.
- Always run with `LC_ALL=en_US.UTF-8` from `~/Projects/GrokCast`.
- Upload screenshots (Deliverfile defaults are screenshot-only + overwrite):
  ```bash
  cd ~/Projects/GrokCast && LC_ALL=en_US.UTF-8 fastlane deliver
  ```
  ⚠️ `overwrite_screenshots` deletes ALL device sets first — the folder must contain BOTH iPhone and iPad sets or the missing one is wiped from the listing.
- Upload metadata (description/URLs/review notes live in `fastlane/metadata/`):
  ```bash
  LC_ALL=en_US.UTF-8 fastlane deliver --skip_metadata false --skip_screenshots true --force
  ```
- Check build processing state: see `scratch` script pattern — spaceship via fastlane's gems:
  ```bash
  GEM_HOME=/opt/homebrew/Cellar/fastlane/2.237.0/libexec GEM_PATH=$GEM_HOME \
  LC_ALL=en_US.UTF-8 /opt/homebrew/opt/ruby/bin/ruby -r spaceship -e '
  Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.from_json_file("fastlane/asc_api_key.json")
  Spaceship::ConnectAPI::App.find("com.scubasteve1999.DayCast")
    .get_builds(sort: "-uploadedDate", limit: 3).each { |b| puts "#{b.version}: #{b.processing_state}" }'
  ```

## Version bump + archive

- Build number lives in `project.yml` → `CURRENT_PROJECT_VERSION` (currently "50"). **Do not use agvtool** — `xcodegen generate` regenerates the project from project.yml and wipes agvtool bumps. Bump `project.yml` in `~/Projects/GrokCast`, run `xcodegen generate`, commit both files.
- Archive: `cd ~/Projects/GrokCast && ./Scripts/archive_for_testflight.sh` — but codesign needs keychain access, which **fails from agent shells** (`errSecInternalComponent`). Have Stephen run it in his own Terminal or archive from Xcode GUI (Product → Archive → Distribute).

## Branding rule

App displays as **DayCast**; internal identifiers stay DayCast (bundle id `com.scubasteve1999.DayCast`, type names, widget kinds, `X-DayCast-Subscription-Id` header). When touching UI, grep string literals for "DayCast" and rebrand only user-visible text.
