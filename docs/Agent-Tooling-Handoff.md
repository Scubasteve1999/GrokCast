# Agent tooling handoff — build, run, screenshot, upload

For any coding agent (Cursor, Claude Code, etc.) working on SpotterCast. Everything below is already installed and configured on this Mac (set up 2026-07-11). State at handoff: **v1.0.1 build 50 uploaded and VALID in App Store Connect**, screenshots + metadata uploaded, awaiting "Add for Review".

## Two clones — critical

| Tree | Use for | Notes |
|------|---------|-------|
| `~/Desktop/GrokCast` | Editing, git commits, pushes | On iCloud Drive — `xcodebuild` **hangs** here; never build/archive from this tree |
| `~/Documents/GrokCast` | All Xcode builds, simulator runs, archiving | Keep synced with `git pull` after pushing from Desktop |

Workflow: edit + commit on Desktop `main` → push → `git pull` in Documents → build there. Both must stay on `main` (see `.cursor/rules/git-workflow.mdc`).

## XcodeBuildMCP (build / run / drive the app)

- Installed globally: `/opt/homebrew/bin/xcodebuildmcp` (v2.6.2, Node via Homebrew).
- Registered in `~/.cursor/mcp.json` and Claude Code (`~/.claude.json`) with env `XCODEBUILDMCP_ENABLED_WORKFLOWS=simulator,simulator-management,ui-automation,debugging,project-discovery` (52 tools: build_run_sim, screenshot, snapshot_ui, tap/swipe/type_text, LLDB attach/breakpoints).
- Set session defaults first: projectPath `~/Documents/GrokCast/GrokCast.xcodeproj`, scheme `GrokCast`, simulator iPhone 17 Pro Max (UDID `B7357E35-6345-44BA-AF5A-6D0E54203106`; iPad Pro 13" M5 is `AE4D58F8-6CE9-4446-B581-581C36BA00EF`). Then `build_run_sim` with empty args.
- Every tool also works one-shot from the CLI, e.g.:
  ```bash
  xcodebuildmcp ui-automation snapshot-ui --simulator-id <udid> --output json
  xcodebuildmcp ui-automation tap --simulator-id <udid> --element-ref e42
  ```
- **UI-automation gotchas:** element refs go stale after every navigation — re-run snapshot-ui before each tap. On iPad the tab bar lists each tab twice (hidden sidebar entry + visible tab); tap the LAST ref of the pair or nothing happens.

## API keys (never commit)

`GrokCast/Config/DeveloperAPIKey.swift` — gitignored, exists in BOTH clones, currently has real xai / mapbox / xweather values. Without it: Grok features show "Add key" empty states and the Radar Mapbox map renders black. Values must be quoted Swift strings.

## App Store screenshots

1. Boot sim, set marketing status bar:
   `xcrun simctl status_bar <udid> override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3`
2. Drive the app to each screen (Today, Forecast, Radar — allow ~10 s for tiles, Alerts, AI).
3. Capture **full-res** with `xcrun simctl io <udid> screenshot <file>.png` (MCP screenshot tool downscales — App Store rejects it).
4. Required sizes: iPhone 17 Pro Max → 1320×2868 (6.9" slot), iPad Pro 13" → 2064×2752.
5. Files live in `fastlane/screenshots/en-US/` — `01–05_*.png` iPhone, `06–10_ipad_*.png` iPad. Filename order = App Store display order.

## fastlane (upload screenshots / metadata)

- Auth: `fastlane/asc_api_key.json` (gitignored) — embeds the .p8 content inline (this fastlane version rejects `key_filepath`). Key ID `ZCMMSMJLQD`, key file `fastlane/AuthKey_ZCMMSMJLQD.p8`. Recreate via `fastlane/README-KEY.md`.
- Always run with `LC_ALL=en_US.UTF-8` from the **Desktop** repo root.
- Upload screenshots (Deliverfile defaults are screenshot-only + overwrite):
  ```bash
  cd ~/Desktop/GrokCast && LC_ALL=en_US.UTF-8 fastlane deliver
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
  Spaceship::ConnectAPI::App.find("com.scubasteve1999.GrokCast")
    .get_builds(sort: "-uploadedDate", limit: 3).each { |b| puts "#{b.version}: #{b.processing_state}" }'
  ```

## Version bump + archive

- Build number lives in `project.yml` → `CURRENT_PROJECT_VERSION` (currently "50"). **Do not use agvtool** — `xcodegen generate` regenerates the project from project.yml and wipes agvtool bumps. Bump project.yml in both clones, run `xcodegen generate`, commit both files.
- Archive: `cd ~/Documents/GrokCast && ./Scripts/archive_for_testflight.sh` — but codesign needs keychain access, which **fails from agent shells** (`errSecInternalComponent`). Have Stephen run it in his own Terminal or archive from Xcode GUI (Product → Archive → Distribute).

## Branding rule

App displays as **SpotterCast**; internal identifiers stay GrokCast (bundle id `com.scubasteve1999.GrokCast`, type names, widget kinds, `X-GrokCast-Subscription-Id` header). When touching UI, grep string literals for "GrokCast" and rebrand only user-visible text.
