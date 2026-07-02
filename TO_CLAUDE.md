# GrokCast - Full Project Context for Claude

This file is meant to be pasted (or the whole folder + this file) when talking to Claude.

## Project Overview
GrokCast is a premium-feeling native SwiftUI iOS weather app.
- Primary weather: Open-Meteo
- US alerts + observations: NWS
- Radar: Mix of RainViewer (live) + Xweather (future)
- AI: xAI Grok (via GrokBuildService streaming + XAIService)

## Directory Structure (Source Only)

## Key Files You Must Understand
- GrokCast/Features/Radar/ (currently the most active area)
  - RadarControlPanel.swift → Rich panel with products, legend, Live/Forecast segmented
  - RadarLoader.swift → Chooses RainViewer vs Xweather
  - RadarMapboxRepresentable.swift → Actual Mapbox rendering
  - Services/XweatherRadarService.swift → fradar tiles + offsets
  - RadarState.swift, RadarView.swift

- Shared/Services/WeatherStore.swift (central state)
- Shared/Services/LocationService.swift
- Config/DeveloperAPIKey.swift (Xweather key lives here for now)

## Recent Work (Very Important Context)
We just did a lot of work on the Radar tab:

1. Restored the rich panel style the user likes (Reflectivity/Velocity/SRV chips, Vibrant/Balanced, detailed legend, auto-resume, badges, etc.).
2. Added explicit "Live" / "Forecast" segmented control (this is the "future tab").
3. Fully disabled synthetic FUTURE mode.
4. Switched FUTURE to real Xweather `fradar` tiles.
5. Fixed the offset format bug (was using "now+0h" which gave 400 error → now correctly uses "current", "+1h", "+2h"...).
6. Made Xweather the primary for FUTURE forecast while keeping RainViewer for live.

Current desired behavior:
- Live mode → RainViewer (or fallback)
- Forecast / FUTURE mode → Real Xweather fradar (12 frames)
- Panel should show the rich controls the user showed in the screenshot.

## Current Status (from latest run)
- Panel looks close to the rich style in the image.
- "Forecast" mode exists as a segmented control.
- Xweather key is configured.
- Logs showed Xweather forecast frames being prepared.

## Instructions for Claude
- The user wants real Xweather fradar in FUTURE mode.
- Keep the panel looking like the screenshot they shared.
- Use the existing architecture (WeatherStore, RadarState, RadarLoader, etc.).
- Prefer minimal changes.
- Use ./grok-build regenerate when adding/removing files.

Read the actual files in Features/Radar/ and Shared/Services/ for the real implementation details.
