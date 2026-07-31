# Claude Code ↔ Cursor handoff

Tactical workflow for running both agents on GrokCast without stepping on each other.
Written 2026-07-31 after a session where the two defaults collided.

## The one conflict you must know about

`.cursor/rules/git-workflow.mdc` tells Cursor: **land finished work on `main` by default.**

Claude Code's built-in default is the opposite: **if you're on the default branch, branch first,**
then ask before merging. Neither is wrong, but unreconciled they cost a round trip on every commit.

**Resolution — state the landing intent in the prompt, every time:**

| You want | Say this |
|---|---|
| Straight to `main` | "commit to main" / "merge it to main" |
| Branch + PR | "branch and open a PR" |
| Branch, don't merge | "branch, don't merge yet" |

Claude Code will branch and ask if you say nothing. Cursor will merge to `main` if you say nothing.
That asymmetry is the thing to remember.

## Division of labor

Play to what each is actually good at here, not to preference.

**Cursor**
- Fast multi-file edits where you already know the change.
- Anything driven from an existing plan — it holds plan context well.
- Bugbot runs automatically on PRs (returned NEUTRAL on #5, so treat it as a low-signal baseline,
  not a safety net).

**Claude Code**
- Reviewing a plan *before* it's built — it reads actual call sites and finds cross-file coupling
  (e.g. a UI rename that silently degrades an LLM prompt three files away).
- Anything touching the device: build, sign, `devicectl` install, CI triage via `gh`.
- Git surgery and CI/workflow debugging.

**Neither**
- Verifying UI on a physical iPhone. Only you can tap it. Claude Code can install to the device
  (`xcrun devicectl device install app`) but cannot see or drive it.

## Handoff protocol

Whoever finishes leaves the repo in this state:

1. **Working tree clean.** `git status --short` empty. No stray temp edits — this session left a
   `padding(.bottom, 260)` experiment in `RadarView.swift` that had to be caught by hand.
2. **Say where the work lives.** Branch name, and whether `main` contains it.
3. **Name what's unverified.** Not "done" — "done except tip dismissal across relaunch."
4. **CI green, or say why not.** `gh run list --branch main --limit 1`.

Starting agent reads: `git log --oneline -5`, `git status`, then this file.

## Verification split

| Layer | Who | Notes |
|---|---|---|
| Compiles | either | `xcodebuild ... -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'` |
| Logic / state | either | Read the code; Radar state machine is subtle — see `RadarState.setProduct` |
| **Radar control panel taps** | **device only** | Synthetic taps do not reach the panel in the Simulator. This is a Simulator artifact, not a bug — pre-existing untouched controls fail the same way. Do not chase it. |
| Chase HUD / tab bar taps | simulator OK | These do receive synthetic taps |
| On-device | you | Install, then tap it yourself |

## Repo rules both agents must respect

- **Secrets:** `GrokCast/Config/DeveloperAPIKey.swift` and `OpenWeatherMapKeys.swift` are gitignored.
  When you add a property to the real file, **add it to the `.example` template in the same commit.**
  CI builds from the templates, so drift breaks CI *and* every fresh clone. This broke on 2026-07-31.
- **`~/Documents/GrokCast` is the only working tree.** `~/Desktop/GrokCast` is a dead leftover —
  no commits, no remote, just a stale `fastlane/` copy — so committing there goes nowhere, and
  building there hangs (iCloud). Confirmed and corrected in `agent-tooling.mdc` on 2026-07-31.
- `xcodegen generate` after touching `project.yml` or adding/removing files.
- Simulators installed: iPhone 17 Pro Max / 17 / 17e / Air. There is no "iPhone 17 Pro".

## CI is the shared gate

`.github/workflows/ci.yml` runs on PRs to `main` and pushes to `main`/`develop`. It stubs the
gitignored key files from `*.example` before XcodeGen, then builds for the simulator.

It was red for three commits before 2026-07-31 and nobody noticed. Check it after any push:

```bash
gh run list --branch main --limit 3
```

If CI is red, that is the handoff — fix it before starting new work.
