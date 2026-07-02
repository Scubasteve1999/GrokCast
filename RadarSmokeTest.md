# Radar Tab – Quick Smoke Test (Post-Refactor)

Short daily verification (top ~10 checks) after `RadarPresentation` changes.

**Prerequisites**: Fresh build, iPhone 17 Pro Max sim, Console.app filtering `[RADAR]`.

## 1. Launch & Baseline
- Radar tab open, panel expanded.
- Primary provider: **IEM (NWS/NEXRAD via IEM RIDGE)** chosen as better (official, higher fidelity for US, aligns with NWS alerts/obs). Falls back to RainViewer.
- Animation running (or last state). Default product reflectivity / USCOMP mosaic.

## 2. Live IEM (preferred)
- Default should log "[RadarState] IEM (preferred provider) loaded".
- Tiles from mesonet.agron.iastate.edu ridge layers.
- Expect smooth playback of recent ~2h frames.

## 3. Fallback (RainViewer)
- If IEM fails (rare), falls back; logs mention RainViewer (fallback).

## 4. Back to Reflectivity (White)
- Switch to **Base Reflectivity**.
- Expect: instant white `LIVE • NQA`, RainViewer tiles, no IEM logs.

## 5. Product Roundtrip
- Velocity → Reflectivity → Velocity.
- Expect: pill state restores correctly, no index jumps, smooth anim.

## 6. Site Change
- On Velocity: open site picker, switch NQA → JAN.
- Expect: pill updates to `... JAN`, new frames load, logs show site in call.

## 7. Scrub + Playback
- In any IEM state: play, scrub, speed change, let it loop.
- Expect: smooth, oldest→newest, no glitches.

## 8. Background / Timer
- Leave running 60s+.
- Background 10s, foreground.
- Expect: reload via `loadFramesAndPresentation`, state preserved.

## 9. Offline Edges
- Offline + Velocity → orange fallback.
- Offline + Reflectivity → white LIVE (still works).

## 10. Rapid Switching
- Hammer product chips + site picker.
- Expect: no crash, stable pill, logs show transitions.

**Pass criteria**: All 4 presentations reachable, pill text/color correct, no regressions in animation/scrubber, clean logs.

**Debug**: Look for `[RADAR] Presentation updated → ...` and tile decisions.

---

Temporary diagnostics (prints) were added for this testing. Remove them after validation via search for `[RADAR]` in Radar files.
