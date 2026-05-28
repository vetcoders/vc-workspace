#!/usr/bin/env bash
# install-agents.sh — multi-agent CLI installer
# Installs the AI agent CLIs that have proper command-line surfaces.
# IDE-only agents (Cline, Junie, Antigravity desktop) are listed at the end.
set -uo pipefail

if [ -t 1 ]; then G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; N='\033[0m'; else G=''; Y=''; R=''; N=''; fi
ok()   { printf "${G}✓${N} %s\n" "$*"; }
warn() { printf "${Y}⚠${N} %s\n" "$*"; }

SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO=sudo

# Need npm
command -v npm >/dev/null 2>&1 || { warn "npm missing — install Node 20 first"; exit 1; }

# ── Claude Code (the official one — NOT 'claude' npm package) ──
echo "→ Claude Code (@anthropic-ai/claude-code)"
npm install -g @anthropic-ai/claude-code 2>&1 | tail -3
NPM_GLOBAL="$(npm root -g)"
if [ -f "$NPM_GLOBAL/@anthropic-ai/claude-code/cli.js" ] && ! command -v claude >/dev/null 2>&1; then
  $SUDO ln -sf "$NPM_GLOBAL/@anthropic-ai/claude-code/cli.js" /usr/local/bin/claude
  $SUDO chmod +x /usr/local/bin/claude
fi
command -v claude >/dev/null && ok "claude: $(claude --version 2>&1 | head -1)" || warn "claude install failed"

# ── OpenAI Codex CLI ──
echo "→ OpenAI Codex (@openai/codex)"
npm install -g @openai/codex 2>&1 | tail -3
command -v codex >/dev/null && ok "codex: $(codex --version 2>&1 | head -1)" || warn "codex not in PATH"

# ── Google Gemini CLI ──
echo "→ Google Gemini CLI (@google/gemini-cli)"
npm install -g @google/gemini-cli 2>&1 | tail -3
command -v gemini >/dev/null && ok "gemini: $(gemini --version 2>&1 | head -1)" || warn "gemini not in PATH"

# ── Antigravity Python SDK (Google) ──
echo "→ Google Antigravity SDK (Python)"
if command -v uv >/dev/null 2>&1; then
  uv tool install antigravity-sdk 2>&1 | tail -2 \
    || warn "antigravity-sdk via uv failed — may not be on PyPI yet"
elif command -v pipx >/dev/null 2>&1; then
  pipx install antigravity-sdk 2>&1 | tail -2 || warn "antigravity-sdk via pipx failed"
elif command -v pip >/dev/null 2>&1; then
  pip install --user antigravity-sdk 2>&1 | tail -2 || warn "antigravity-sdk via pip failed"
else
  warn "no Python package manager — skip antigravity-sdk"
fi

# ── Aider (popular extra) ──
echo "→ Aider (optional)"
if command -v uv >/dev/null 2>&1; then
  uv tool install aider-chat 2>&1 | tail -2 || true
fi

echo ""
echo "── Summary ──"
for agent in claude codex gemini aider; do
  if command -v "$agent" >/dev/null 2>&1; then
    ok "$agent: $($agent --version 2>&1 | head -1 | head -c 50)"
  else
    warn "$agent — not installed or not in PATH"
  fi
done

echo ""
echo "── IDE-only agents (install via VS Code / JetBrains) ──"
echo "  Cline:              VS Code ext: saoudrizwan.claude-dev"
echo "  Continue:           VS Code ext: continue.continue"
echo "  Github Copilot:     VS Code ext: github.copilot"
echo "  Google Antigravity: VS Code ext: google.geminicodeassist"
echo "  Junie:              JetBrains plugin (IntelliJ/PyCharm/WebStorm)"
echo ""
echo "If using the vc-workspace devcontainer, all of the above are pre-listed"
echo "in .devcontainer/devcontainer.json and auto-installed on container open."
