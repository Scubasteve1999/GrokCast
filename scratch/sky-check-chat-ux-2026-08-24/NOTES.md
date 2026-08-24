# Sky Check chat keyboard, type, and tab-bar inset

**Repo:** `/Users/bigstevedev/Projects/GrokCast`  
**Base:** `0ceb9f1` (weather bot + smart pack) on radar, all local  
**Marketing / build:** **1.0.7 (143)** — not bumped  
**Commit:** `fix(grok): Sky Check chat keyboard, type, and tab-bar inset`  
**Slice:** composer vs CompactTabBar + keyboard + readable thread. No radar paint / prompts / bump / push / TF.

## What shipped

1. **Composer above CompactTabBar.** Compact Sky Check is the More-page `.grok` tab. Nested `safeAreaInset` (Grok composer) fought the parent CompactTabBar inset — NavigationStack resets bottom safe area to the home indicator, so the field sat on Radar/More. Composer inset now lives **outside** `NavigationStack`. Compact + unfocused pads `CompactTabBar.chromeHeight` (69pt) via `SkyCheckChatChrome.tabBarClearance`. That padding is empty (not a hit target), so Radar/More stay tappable.

2. **Keyboard.** Focus still sets `TabBarSuppressionPreferenceKey` so the bar hides. Clearance drops to 0 so the field rides the keyboard with no extra gap. `.scrollDismissesKeyboard(.interactively)` kept. Send, chips, and the photo well resign first responder so a stuck field cannot sit under the tab bar. Thread `scrollTo("thread-bottom")` on new messages, streaming, and focus.

3. **Readable thread.** Dropped the 280pt cap. Assistant bubbles use available width minus a 48pt gutter. User + assistant body is `Typography.body()`. Timestamps stay `micro` / tertiary. Empty pitch is secondary; hedge stays tertiary. Quiet leftover Imagine chrome on this tab (`Generating image…`, no ALL-CAPS tracking).

4. **Compact input bar.** Tray is `ultraThinMaterial` (was `.clear`). Elevated pill kept. Placeholder still **Ask about the weather…**. Send is always visible with palette contrast (accent fill, dark arrow).

## Live sim (iPhone 16, `8F4DFE67-9472-4C4C-9BC5-3BD68B7A399E`, iOS 26.5)

| File | What |
|------|------|
| `01-keyboard-down.jpg` | Field above CompactTabBar — Radar and More are clear and hittable. Elevated pill on material. |
| `02-keyboard-up.jpg` | Field on the software keyboard, last answer visible, tab bar gone, cursor in the field. |
| `03-thread.jpg` | Wide body-type bubbles on `WeatherBackgroundView`; last assistant line above the composer; composer above Radar/More. |

## Tests

`xcodebuild` DayCastTests on iPhone 16 `8F4DFE67-9472-4C4C-9BC5-3BD68B7A399E`: **506 passed** (was 503).

`SkyCheckChatLayoutTests`: compact unfocused clearance equals `CompactTabBar.chromeHeight`; focused and regular-width are 0.

`CriticalFlowsUITests.testSkyCheckComposerIsHittableAboveTabBar`: `daycast.grok.chatField` is hittable, `field.maxY` is above Radar/More, keyboard-up hides CompactTabBar.

Honesty suite (`StormSpotterHonestyTests`) unchanged and green. No prompt / grounding edits.

## Confirm

- Unfocused composer is not on the Radar tab hit target.
- Focused composer rides the keyboard; tab bar is gone; last bubble stays visible.
- Version: still **1.0.7 (143)**. No push, no TestFlight.

## Out of this slice

Radar paint / wet probe, prompts / grounding / daily pack, version bump, push, TestFlight, camera, 4.7, fifth tab, Ask Grok brand, AccuWeather chrome.
