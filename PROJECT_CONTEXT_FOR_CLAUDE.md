# GrokCast - Complete Project Context

**Project**: GrokCast (SwiftUI iOS weather app)
**Path**: /Users/stephenmoore/Desktop/GrokCast
**Main Focus Right Now**: Radar tab - rich panel + real Xweather fradar for FUTURE mode

## 1. Project Structure (Source Files Only)

.grok/skills/grokcast/SKILL.md
.grok/skills/SKILL.md
AGENTS.md
CLAUDE_RADAR_CONTEXT.md
CLAUDE.md
DesignSystem.md
docs/TestFlight-Radar-Widget-Validation-Checklist.md
grok-impl-summary-dynamicbg-forecast-polish.md
grok-impl-summary-radar-decomposition.md
grok-impl-summary-radar-deeper-cleanup.md
grok-impl-summary-weathercondition-radar.md
GrokCast/App/AppDelegate.swift
GrokCast/App/GrokCastApp.swift
GrokCast/Config/DeveloperAPIKey.swift
GrokCast/Config/GrokCastUtilitiesDeveloperAPIKey.swift
GrokCast/Config/OpenWeatherMapKeys.swift
GrokCast/ContentView.swift
GrokCast/Features/Alerts/AlertDetailView.swift
GrokCast/Features/Alerts/AlertsView.swift
GrokCast/Features/Alerts/NWSAlertStyle.swift
GrokCast/Features/Forecast/DailyRow.swift
GrokCast/Features/Forecast/DailyRowSkeleton.swift
GrokCast/Features/Forecast/ForecastView.swift
GrokCast/Features/Forecast/HourlyRow.swift
GrokCast/Features/Forecast/HourlyRowSkeleton.swift
GrokCast/Features/Forecast/OpenWeatherMapForecastChip.swift
GrokCast/Features/GrokAI/GrokAIResponseView.swift
GrokCast/Features/GrokAI/GrokAIView.swift
GrokCast/Features/GrokAI/GrokAIViewModel.swift
GrokCast/Features/GrokAI/GrokErrorView.swift
GrokCast/Features/GrokAI/GrokInputBar.swift
GrokCast/Features/GrokAI/GrokQuickPromptButton.swift
GrokCast/Features/GrokAI/GrokStormSpotterButton.swift
GrokCast/Features/GrokAI/GrokThinkingIndicator.swift
GrokCast/Features/Locations/LocationsView.swift
GrokCast/Features/Radar/DebugFlags.swift
GrokCast/Features/Radar/NWSRadarProduct.swift
GrokCast/Features/Radar/RadarControlPanel.swift
GrokCast/Features/Radar/RadarDataset.swift
GrokCast/Features/Radar/RadarLoader.swift
GrokCast/Features/Radar/RadarMapboxRepresentable.swift
GrokCast/Features/Radar/RadarModeTransition.swift
GrokCast/Features/Radar/RadarPlayback.swift
GrokCast/Features/Radar/RadarPlaybackControls.swift
GrokCast/Features/Radar/RadarState.swift
GrokCast/Features/Radar/RadarTimeline.swift
GrokCast/Features/Radar/RadarTimelineConfig.swift
GrokCast/Features/Radar/RadarTimelineScrubber.swift
GrokCast/Features/Radar/RadarView.swift
GrokCast/Features/Radar/RainViewerRadarService.swift
GrokCast/Features/Radar/Services/IEMRadarService.swift
GrokCast/Features/Radar/Services/OpenWeatherMapRadarService.swift
GrokCast/Features/Radar/Services/RadarFrame.swift
GrokCast/Features/Radar/Services/RadarTileProvider.swift
GrokCast/Features/Radar/Services/XweatherRadarLayer.swift
GrokCast/Features/Radar/Services/XweatherRadarService.swift
GrokCast/Features/Settings/SettingsView.swift
GrokCast/Features/Today/DynamicBackgroundView.swift
GrokCast/Features/Today/DynamicWeatherBackground.swift
GrokCast/Features/Today/GrokImagineResultView.swift
GrokCast/Features/Today/LocationPermissionView.swift
GrokCast/Features/Today/TodayView.swift
GrokCast/Shared/Components/CustomTabBar.swift
GrokCast/Shared/Components/Haptic.swift
GrokCast/Shared/Components/ReadableContentWidth.swift
GrokCast/Shared/Components/Shimmer.swift
GrokCast/Shared/Components/StreamingText.swift
GrokCast/Shared/Components/Tab.swift
GrokCast/Shared/Components/TacticalCard.swift
GrokCast/Shared/Configuration/GrokAPIConfiguration.swift
GrokCast/Shared/Design/DesignTokens.swift
GrokCast/Shared/Grok/GrokPrompts.swift
GrokCast/Shared/Models/ChatMessageEntity.swift
GrokCast/Shared/Models/Location.swift
GrokCast/Shared/Models/NWSModels.swift
GrokCast/Shared/Models/OpenMeteoModels.swift
GrokCast/Shared/Models/OpenWeatherMapModels.swift
GrokCast/Shared/Models/WeatherCondition.swift
GrokCast/Shared/Models/WeatherModels.swift
GrokCast/Shared/Services/AlertHistoryStore.swift
GrokCast/Shared/Services/AlertNotificationService.swift
GrokCast/Shared/Services/BackgroundAlertRefreshService.swift
GrokCast/Shared/Services/GrokAIConversationStore.swift
GrokCast/Shared/Services/GrokAIService.swift
GrokCast/Shared/Services/GrokBuildService.swift
GrokCast/Shared/Services/KeychainService.swift
GrokCast/Shared/Services/LocationService.swift
GrokCast/Shared/Services/NWSService.swift
GrokCast/Shared/Services/OpenMeteoService.swift
GrokCast/Shared/Services/OpenWeatherMapService.swift
GrokCast/Shared/Services/WeatherService.swift
GrokCast/Shared/Services/WeatherStore.swift
GrokCast/Shared/Services/XAIService.swift
GrokCast/Shared/Views/WeatherBackgroundView.swift
GrokCast/Shared/Widget/GrokCastDeepLinks.swift
GrokCast/Shared/Widget/WidgetAlertSummary.swift
GrokCast/Shared/Widget/WidgetAppGroup.swift
GrokCast/Shared/Widget/WidgetDataStore.swift
GrokCast/Shared/Widget/WidgetTimelineReloader.swift
GrokCast/Shared/Widget/WidgetWeatherSnapshot.swift
GrokCastWidgets/Configuration/WidgetLocationIntent.swift
GrokCastWidgets/GrokCastWidgets.swift
GrokCastWidgets/Providers/WeatherTimelineProvider.swift
GrokCastWidgets/Views/LockScreenWeatherWidgetView.swift
GrokCastWidgets/Views/MediumWeatherWidgetView.swift
GrokCastWidgets/Views/SmallWeatherWidgetView.swift
GrokCastWidgets/Views/WidgetAlertStyle.swift
GrokCastWidgets/Views/WidgetBackground.swift
GrokCastWidgets/Views/WidgetDeepLink.swift
GrokCastWidgets/Views/WidgetEmptyStateView.swift
GrokCastWidgets/Views/WidgetRelativeTime.swift
GrokCastWidgets/Views/WidgetStyle.swift
GrokCastWidgets/Views/WidgetUpdatedFooter.swift
PROJECT_CONTEXT_FOR_CLAUDE.md
project.yml
RadarSmokeTest.md
README.md
rereview-forecast-dynamic-bg-round1.md
review-forecast-dynamic-bg-round1.md
review-radar-decomposition.md
review-radar-deeper-cleanup.md
review-weathercondition-radar-centralization.md
TestFlight-Prep.md
TO_CLAUDE.md

## 2. Key Architecture Rules

- SwiftUI + @Observable
- Central WeatherStore
- Radar uses multiple providers (RainViewer for live, Xweather for forecast)
- FUTURE mode = forecast precipitation using Xweather fradar
- Rich panel style with product selection (Reflectivity, Velocity, SRV), color schemes, etc.

## 3. Recent Work (Very Important)

- Restored the full rich radar panel the user likes (see their screenshots).
- Added "Live" / "Forecast" segmented control as the future tab.
- Completely disabled synthetic mode.
- Switched FUTURE to real Xweather fradar.
- Fixed fradar offset format (was using invalid "now+0h", now using "current" and "+1h" style).
- Xweather is preferred for FUTURE.

See files in GrokCast/Features/Radar/ for the current implementation.

## 4. Most Important Files Right Now

- GrokCast/Features/Radar/RadarControlPanel.swift
- GrokCast/Features/Radar/RadarLoader.swift
- GrokCast/Features/Radar/Services/XweatherRadarService.swift
- GrokCast/Features/Radar/RadarMapboxRepresentable.swift
- GrokCast/Features/Radar/RadarState.swift
- GrokCast/Features/Radar/DebugFlags.swift
- GrokCast/Config/DeveloperAPIKey.swift (Xweather key)

## 5. Commands

```bash
./grok-build regenerate
./grok-build clean --derived-data
xcodebuild ... build
```

