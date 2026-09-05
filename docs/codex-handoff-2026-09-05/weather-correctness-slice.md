# Weather correctness slice

Implemented in `/Users/bigstevedev/Projects/GrokCastLocal` on September 5, 2026.

## Changes

- City and temperature-unit changes synchronously invalidate displayed weather and supplemental NWS/OpenWeatherMap data. Coordinate changes are detected even when a saved location retains its ID.
- Primary, observation, OpenWeatherMap, and alert requests check selection revision and request generation before publishing. An older request cannot replace newer weather, clear newer observations, or turn off a newer request's loading state. Background completion paths also check selection ownership.
- Forecast values carry unit metadata through widget snapshot encoding and cold-launch hydration. The main app rejects snapshots with incompatible or unknown units. Legacy snapshots remain decodable; an untagged snapshot requires a fresh fetch rather than guessing its units.
- The unavailable state offers Retry for the selected city rather than switching to device location. Removing the selected saved location refreshes its replacement.
- Added injectable network boundaries and an isolated store mode for deterministic tests. Added 10 regressions covering offline unit changes, out-of-order completions, changes away and back, GPS movement with a stable ID, NWS/OWM failure and city changes, and snapshot compatibility.

## Verification

- Full iOS unit suite: **358 passed, 0 failed**, including all 10 new regressions.
- Full UI suite: **4 passed, 1 failed**. The sole failure is the previously reproduced radar selector mismatch (`CriticalFlowsUITests.swift:54`); no radar code or tests changed in this slice. Today, forecast/alerts deep links, paywall presentation, and Storm Spotter entry passed.
- Because of that existing radar failure, the overall Xcode test command exits with status 65. The unit-only run exits successfully.
- Release simulator build: **passed** for arm64 and x86_64.
- Manual Computer verification was unavailable: ScreenCaptureKit returned error -3811. Automated XCUITest operates in the simulator independently.

## Scope and behavior

Six source/test files changed. No entitlement, paywall, subscription, dependency, or backend changes were made. The existing radar smoke test still uses outdated labels and is outside this weather slice.

After a unit or city change, incompatible cached data is discarded. Offline users see an unavailable/retry state until a compatible forecast can be fetched. Existing widget wire keys are preserved; optional unit metadata is additive. This verifies simulator behavior, not a device archive or production deployment.

[Review the patch](/Users/bigstevedev/Documents/Codex/2026-09-05/build-x20/outputs/weather-correctness.patch). Original versions of the six files are retained in the task's work/weather-original directory because the supplied project has no Git metadata.

[Final Xcode test results](/Users/bigstevedev/Documents/Codex/2026-09-05/build-x20/outputs/DayCast-weather-tests.xcresult).
