# Claude Code ↔ Cursor handoff

Keep both agents from colliding on DayCast. State landing intent in the prompt every time.

| You want | Say this |
|---|---|
| Straight to `main` | "commit to main" / "merge it to main" |
| Branch + PR | "branch and open a PR" |
| Branch, don't merge | "branch, don't merge yet" |

Claude Code branches and asks if you say nothing. Cursor merges to `main` if you say nothing.

## Division of labor

**Cursor** — fast multi-file edits against a known plan.

**Claude Code** — plan review against real call sites; device install, signing, `devicectl`, CI triage via `gh`.

**Neither** — verifying UI on a physical iPhone. Only Stephen can tap it.

## Handoff protocol

Whoever finishes leaves the repo in this state:

1. **Working tree clean.** `git status --short` empty. No stray temp edits.
2. **Say where the work lives.** Branch name, and whether `main` contains it.
3. **Name what's unverified.** Not "done" — "done except X."
4. **CI green, or say why not.** `gh run list --branch main --limit 1`.

Starting agent reads: `git log --oneline -5`, `git status`, then this file.

## Verification

| Layer | Who | Notes |
|---|---|---|
| Compiles | either | `xcodebuild` … `iPhone 17 Pro Max` (see `AGENTS.md`) |
| Logic / state | either | Read the code |
| Radar control panel taps | device only | Synthetic taps do not reach the panel in Simulator |
| Chase HUD / tab bar taps | simulator OK | These do receive synthetic taps |
| On-device | you | Install, then tap it yourself |

## Repo rules both agents must respect

- **Secrets:** `DayCast/Config/DeveloperAPIKey.swift` and `OpenWeatherMapKeys.swift` are gitignored. When you add a property to the real file, add it to the `.example` template in the same commit. CI builds from the templates.
- **`~/Projects/GrokCast` is the working tree.** `~/Documents/GrokCast` is an iCloud-synced mirror — git operations there hang. Do not work from Desktop leftovers.
- `xcodegen generate` after touching `project.yml` or adding/removing files.
- Simulators: iPhone 17 Pro Max / 17 Pro / 17 / 17e / Air. Commands and hard rules: `AGENTS.md`. Product IA: `.grok/skills/daycast/SKILL.md`.
- Hosted Pro Grok proxy: `server/grok-proxy/README.md`.

## CI is the shared gate

`.github/workflows/ci.yml` runs on PRs to `main` and pushes to `main`/`develop`. It stubs gitignored key files from `*.example` before XcodeGen, then **compiles** for the simulator. It does not run `xcodebuild test`.

```bash
gh run list --branch main --limit 3
```

If CI is red, that is the handoff — fix it before starting new work.
