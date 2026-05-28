#!/usr/bin/env bash
# vc-workspace devcontainer post-create
# Runs once after container is built. Brings up vibecrafted runtime + agent
# CLIs that need network/account auth (skipped at image build time).
set -uo pipefail

USER_HOME="${HOME:-/home/vc}"
WORKSPACE="${VC_WORKSPACE:-/workspace}"
VIBECRAFTED_HOME="${VIBECRAFTED_HOME:-$USER_HOME/.vibecrafted}"
LOG="$USER_HOME/.post-create.log"

# ── Colors ────────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'; N='\033[0m'
else G=''; Y=''; B=''; N=''; fi
log()  { printf "${B}[%s]${N} %s\n" "$(date +%H:%M:%S)" "$*"; }
ok()   { printf "${G}  ✓${N} %s\n" "$*"; }
warn() { printf "${Y}  ⚠${N} %s\n" "$*"; }

exec > >(tee -a "$LOG") 2>&1

log "── vc-workspace post-create ──"
log "User: $(whoami) (uid=$(id -u))"
log "Workspace: $WORKSPACE"
log "Vibecrafted home: $VIBECRAFTED_HOME"

# ── Stage 1: ssh config sanity ────────────────────────────────────────────
log "Stage 1: SSH config validation"
if [ -f "$USER_HOME/.ssh/config" ]; then
  hosts=$(grep -c '^Host ' "$USER_HOME/.ssh/config" 2>/dev/null || echo 0)
  ok "sshconfig mounted: $hosts host entries"
  ok "sample hosts: $(grep '^Host ' $USER_HOME/.ssh/config | awk '{print $2}' | head -5 | tr '\n' ' ')"
else
  warn "no ~/.ssh/config — tailnet hosts unavailable. Mount host's ~/.ssh/ via devcontainer.json"
fi

# Test tailnet reachability (best-effort, non-blocking)
if command -v tailscale >/dev/null 2>&1; then
  ts_status=$(tailscale status --json 2>/dev/null | head -c 100)
  [ -n "$ts_status" ] && ok "tailscale CLI present" || warn "tailscale CLI present but daemon unreachable"
else
  log "tailscale CLI not installed in container (host networking should still work)"
fi

# ── Stage 2: vibecrafted runtime install ──────────────────────────────────
log "Stage 2: vibecrafted runtime install"
if [ -d "$WORKSPACE/vibecrafted/.git" ]; then
  log "  vibecrafted mounted in workspace — installing from there"
  (cd "$WORKSPACE/vibecrafted" && make install 2>&1 | tail -5) || warn "vibecrafted local install failed"
elif [ -d "$USER_HOME/vibecrafted/.git" ]; then
  log "  vibecrafted in home — updating"
  (cd "$USER_HOME/vibecrafted" && git pull --ff-only 2>&1 | tail -3) || true
  (cd "$USER_HOME/vibecrafted" && make install 2>&1 | tail -5) || warn "vibecrafted home install failed"
else
  log "  cloning vibecrafted from public mirror"
  git clone --depth 1 https://github.com/vetcoders/vibecrafted.git "$USER_HOME/vibecrafted" \
    && (cd "$USER_HOME/vibecrafted" && make install 2>&1 | tail -5) \
    || warn "vibecrafted clone/install failed"
fi
command -v vibecrafted >/dev/null 2>&1 && ok "vibecrafted: $(vibecrafted --version 2>&1 | head -1)" \
  || warn "vibecrafted CLI not in PATH"

# ── Stage 3: loctree (loct) binary ────────────────────────────────────────
log "Stage 3: loct CLI (official installer: loct.io)"
if command -v loct >/dev/null 2>&1; then
  ok "loct already present"
else
  curl -fsSL https://loct.io/install.sh | sh 2>&1 | tail -3 || warn "loct curl install failed"
  if ! command -v loct >/dev/null 2>&1 && [ -f "$WORKSPACE/loctree-suite/Cargo.toml" ]; then
    log "  fallback: building from $WORKSPACE/loctree-suite"
    (cd "$WORKSPACE/loctree-suite" && cargo install --path crates/loct --locked 2>&1 | tail -3) \
      || warn "loct fallback build failed"
  fi
  command -v loct >/dev/null && ok "loct: $(loct --version 2>&1 | head -1)" \
    || warn "loct not in PATH after install"
fi

# ── Stage 4: aicx CLI (MANDATORY) ─────────────────────────────────────────
log "Stage 4: aicx CLI (cargo install aicx)"
if command -v aicx >/dev/null 2>&1; then
  ok "aicx already present: $(aicx --version 2>&1 | head -1)"
else
  cargo install --locked aicx 2>&1 | tail -3 || warn "cargo install aicx failed"
  if ! command -v aicx >/dev/null 2>&1 && [ -f "$WORKSPACE/aicx/Cargo.toml" ]; then
    log "  fallback: building from $WORKSPACE/aicx"
    (cd "$WORKSPACE/aicx" && cargo install --path . --locked 2>&1 | tail -3) \
      || warn "aicx fallback build failed"
  fi
  command -v aicx >/dev/null && ok "aicx: $(aicx --version 2>&1 | head -1)" \
    || warn "aicx not in PATH after install — MANDATORY install failed"
fi

# ── Stage 5: TypeScript/React global tools ────────────────────────────────
log "Stage 5: TypeScript + React global tools"
npm install -g \
  typescript ts-node tsx \
  vite \
  create-vite create-next-app \
  @astrojs/upgrade \
  prettier eslint \
  2>&1 | tail -3 || warn "npm global tools install had warnings"
ok "ts: $(tsc --version 2>&1)  vite: $(vite --version 2>&1)"

# ── Stage 6: Python dev tools ─────────────────────────────────────────────
log "Stage 6: Python dev tools (via uv)"
uv tool install ruff 2>&1 | tail -2 || true
uv tool install mypy 2>&1 | tail -2 || true
uv tool install pytest 2>&1 | tail -2 || true
uv tool install ipython 2>&1 | tail -2 || true
ok "uv tools: $(uv tool list 2>&1 | head -5 | tr '\n' ' ')"

# ── Stage 7: Agent CLI sanity ─────────────────────────────────────────────
log "Stage 7: Agent CLI sanity check"
for agent in claude codex gemini; do
  if command -v "$agent" >/dev/null 2>&1; then
    ver=$("$agent" --version 2>&1 | head -1 | head -c 50)
    ok "$agent — $ver"
  else
    warn "$agent — not in PATH (re-install: npm install -g <package>)"
  fi
done

# Cline + Antigravity are VS Code extensions — installed via devcontainer.json
log "  Cline (saoudrizwan.claude-dev) installed via VS Code extensions"
log "  Google Antigravity (geminicodeassist) installed via VS Code extensions"
log "  Junie — JetBrains plugin; no CLI surface in container"

# ── Stage 8: GitHub CLI auth check ────────────────────────────────────────
log "Stage 8: gh CLI auth"
if gh auth status >/dev/null 2>&1; then
  ok "gh authenticated as $(gh api user --jq .login 2>/dev/null || echo '?')"
else
  warn "gh not authenticated — run: gh auth login (uses host's ~/.config/gh if mounted)"
fi

# ── Stage 9: Final report ─────────────────────────────────────────────────
log ""
log "── Final verification ──"
for tool in rustc cargo zig node npm pnpm yarn python3 uv \
            claude codex gemini vibecrafted loct aicx gh git tmux eza bat fd rg jq; do
  if command -v "$tool" >/dev/null 2>&1; then
    ver=$("$tool" --version 2>&1 | head -1 | head -c 60)
    ok "$tool — $ver"
  else
    warn "$tool — missing"
  fi
done

log ""
log "── SSH tailnet sanity ──"
if [ -f "$USER_HOME/.ssh/config" ]; then
  echo "Available hosts:"
  grep '^Host ' "$USER_HOME/.ssh/config" | awk '{print "  "$2}' | head -10
else
  warn "No sshconfig — mount host's ~/.ssh/ via devcontainer.json"
fi

log ""
ok "vc-workspace devcontainer ready."
log "Try:  vibecrafted start"
log "Try:  claude --dangerously-skip-permissions --verbose"
log "Try:  loct repo-view"
log ""
log "𝚅𝚒𝚋𝚎𝚌𝚛𝚊𝚏𝚝𝚎𝚍. with AI Agents by VetCoders (c)2024-2026 LibraxisAI"
