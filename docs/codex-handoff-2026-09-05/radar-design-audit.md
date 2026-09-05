# DayCast radar design audit

Reviewed September 5, 2026: installed DayCast on iPhone 17 Pro Max / iOS 26.5, Live radar around Olive Branch, the Layers sheet, and the 24-hr entry point. Compared the rendered UI with current SwiftUI source. This was an audit only; no source changes or purchases were made.

## Overall judgment

A good map-first foundation, but the controls and situation summary are compressed too far. The map gets generous space, the floating control panel is coherent, and the pale blue accent consistently identifies controls. Readability and interaction deserve the next design pass before adding features.

## Prioritized findings

| Priority | Finding and evidence | Suggested change |
|---|---|---|
| High | The compact timeline is a custom drag gesture with a 24-point-high interaction region. It exposes no adjustable accessibility action; the runtime snapshot did not offer it as a slider target. Play and Recenter have 28-point frames. | Keep the slim visual track but provide a 44-point interaction region. Expose a named adjustable timeline with current time and increment/decrement actions. Expand the button hit areas. |
| High | The top-right information panel uses the same fixed 12-point type for scan age, location, product, alert, and outlook. In the capture, red “IN Heat Advisory” is difficult to read and has little hierarchy. | Promote location and frame freshness, give the alert an icon and its own clearly readable row, and use scalable text styles. Keep secondary outlook information quieter. |
| Medium | The light basemap appears washed out: roads and town labels are faint. Dark floating cards stand out more strongly than geographic orientation. | Tune the basemap label/road contrast while keeping precipitation dominant. Check a dense-rain scene and a sparse-rain scene before choosing opacity. |
| Medium | “24-hr” looks like an ordinary mode segment but opens the Pro paywall in this installation. The segment does not indicate that access requirement. | Label it “Forecast · Pro” or add a clear lock/Pro indicator for users without access. This is a presentation recommendation; entitlement logic was not changed. |
| Medium | “Layers” opens a sheet titled “Display.” Its initial half-height view gives the first rows to auto-resume and Map only, followed by products; opacity, map choices, and legend are lower down. | Use one title, “Layers & display,” and lead with product/layer selection and opacity. Group playback preferences separately. |

## What works

- Large uninterrupted map area and a compact bottom control panel.
- Visible frame time and a separate scan-age indicator.
- Persistent reflectivity colorbar; consistent color stops are shared in source.
- Clear spoken names for Live radar, Layers, playback speeds, and Recenter to selected location.
- Products are named Rain, Detail rain, and Storm winds instead of exposing provider names.

## Source evidence

- `DayCast/Features/Radar/RadarControlPanel.swift:103` and `:126`: Play/Recenter frames.
- `DayCast/Features/Radar/RadarTimelineScrubber.swift:36`: custom compact timeline; gesture region at line 100.
- `DayCast/Features/Radar/ChaseRadarHUD.swift:185`: equal-size information rows.
- `DayCast/Shared/Design/DesignTokens.swift:101`: fixed 12-point micro font.
- `DayCast/Features/Radar/RadarControlPanel.swift:196`: Live/24-hr segments; line 464 begins the display sheet.

## Scope and limitations

Screenshots are tool-generated 368×800 previews of the simulator, so no numerical contrast compliance claim is made. Large Dynamic Type, VoiceOver interaction, smaller phones, iPad, landscape, severe-warning scenes, and the authenticated forecast view were not exercised. The source also imposes a 400-point minimum map width, which merits a smaller-device check; clipping was not established in this audit. Current source was inspected, but this pass did not rebuild the installed app.

The forecast entry opened a paywall, which was dismissed without purchase. Live radar was restored and the Layers sheet closed. No AI chat request was sent.

## Recommended first slice

Improve radar readability and control accessibility: larger invisible hit regions, adjustable timeline semantics, scalable scan/alert text, and clearer location/alert hierarchy. Keep map behavior and subscription logic unchanged. Validate that slice on a smaller phone and with large Dynamic Type before moving to visual polish.
