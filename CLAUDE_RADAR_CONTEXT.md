# GrokCast Radar Context for Claude (Recommended to paste)

## Current Goal
Switch FUTURE radar to real Xweather fradar tiles and keep the rich panel style the user likes.

## Key Files (focus on these)
- Features/Radar/RadarControlPanel.swift (rich panel + Live/Forecast control)
- Features/Radar/RadarLoader.swift (decides which provider for live vs forecast)
- Features/Radar/Services/XweatherRadarService.swift (fradar tile building + offsets)
- Features/Radar/RadarMapboxRepresentable.swift (map rendering)
- Features/Radar/RadarState.swift
- Features/Radar/DebugFlags.swift
- Features/Radar/RadarView.swift

## What We Have Done Recently
- Restored rich panel: product chips (Reflectivity, Velocity, SRV), Vibrant/Balanced, good legend, auto-resume, badges.
- Added "Live" / "Forecast" segmented control (this is the future tab).
- Disabled all synthetic FUTURE code.
- Fixed Xweather fradar to use correct offsets: "current", "+1h", "+2h"...
- Xweather is now used for FUTURE forecast, RainViewer for live.
- Mode switching improved to reduce Mapbox warnings.

## Project Structure (main source)
GrokCast/
├── App/
├── Features/
│   ├── Radar/               ← Main focus right now
│   ├── Today/
│   ├── Forecast/
│   ├── GrokAI/
│   └── ...
├── Shared/
│   ├── Services/            ← WeatherStore, XweatherRadarService, etc.
│   └── Models/
└── Config/

Use the files under Features/Radar/ as the primary context.

## Current Behavior (from recent logs)
- Live = RainViewer
- Forecast = Xweather fradar (12 frames)
- When user taps "Forecast", it should load real tiles.

Paste this + the latest screenshot + latest console logs when talking to Claude.
