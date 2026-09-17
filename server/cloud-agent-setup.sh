#!/usr/bin/env bash
# Cloud Agent environment bootstrap for the DayCast Cloudflare Worker backends.
#
# The iOS app builds only on macOS/Xcode, so on a Linux Cloud Agent the testable
# code is the two Node workers under server/. Both declare "engines": ">=24" and
# their suites rely on Node 24: grok-proxy uses built-in node:sqlite, and both run
# `node --test` (push-agent runs it directly on .ts via type stripping).
#
# Idempotent: safe to run repeatedly and on top of a warm snapshot.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- Node 24 via nvm --------------------------------------------------------
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"

node_lts="lts/krypton" # Node 24 LTS
nvm install "$node_lts" >/dev/null
nvm alias default "$node_lts" >/dev/null
nvm use default >/dev/null

node_bin="$(dirname "$(nvm which default)")"

# The exec-daemon ships its own Node (v22) ahead of nvm on PATH, so bare
# `node`/`npm` in agent shells would otherwise be too old for `node --test` on
# .ts files. Prepend the Node 24 bin dir for every future shell. Appended last so
# it wins over the exec-daemon entry; guarded so re-runs do not duplicate it.
marker="# daycast-cloud-node-path"
if ! grep -qsF "$marker" "$HOME/.bashrc"; then
  printf '\n%s\nexport PATH="%s:$PATH"\n' "$marker" "$node_bin" >>"$HOME/.bashrc"
fi
export PATH="$node_bin:$PATH"

echo "Using node $(node --version) (npm $(npm --version))"

# --- Worker dependencies ----------------------------------------------------
# grok-proxy ships no lockfile (dependency-free worker; wrangler is its only dev
# dep) and gitignores one, so install without writing package-lock.json.
# push-agent has a committed lockfile -> npm ci.
(cd "$repo_root/server/grok-proxy" && npm install --no-package-lock --no-audit --no-fund)
(cd "$repo_root/server/push-agent" && npm ci --no-audit --no-fund)

# --- grok-proxy test fixtures ----------------------------------------------
# Throwaway P-256/P-384 cert chain used by the StoreKit-JWS tests. Gitignored and
# regenerated on demand (needs openssl, present on the image).
(cd "$repo_root/server/grok-proxy" && npm run --silent fixtures)

echo "Cloud Agent setup complete."
