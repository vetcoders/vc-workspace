#!/usr/bin/env bash
# vc-workspace devcontainer post-start
# Runs on every container start. Quick health + status report.
set -uo pipefail

if [ -t 1 ]; then G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'; N='\033[0m'; else G=''; Y=''; B=''; N=''; fi

printf "${B}── vc-workspace ready ──${N}\n"
printf "  user:      %s (uid=%s)\n" "$(whoami)" "$(id -u)"
printf "  workspace: %s\n" "${VC_WORKSPACE:-/workspace}"
printf "  date:      %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# SSH config quick check
if [ -f "$HOME/.ssh/config" ]; then
  hosts=$(grep -c '^Host ' "$HOME/.ssh/config" 2>/dev/null || echo 0)
  printf "${G}  ✓${N} sshconfig: %s tailnet hosts\n" "$hosts"
else
  printf "${Y}  ⚠${N} sshconfig not mounted\n"
fi

# Agent surface
agents_ok=0
for agent in claude codex gemini vibecrafted loct aicx; do
  command -v "$agent" >/dev/null 2>&1 && agents_ok=$((agents_ok+1))
done
printf "${G}  ✓${N} agents+binaries: %s/6 in PATH\n" "$agents_ok"

# Quick toolchain ping
printf "${G}  ✓${N} rust:    %s\n" "$(rustc --version 2>&1 | head -1)"
printf "${G}  ✓${N} node:    %s  npm: %s\n" "$(node --version 2>&1)" "$(npm --version 2>&1)"
printf "${G}  ✓${N} python:  %s\n" "$(python3 --version 2>&1)"
printf "${G}  ✓${N} uv:      %s\n" "$(uv --version 2>&1)"

echo ""
echo "Quick start:"
echo "  vibecrafted start              # operator session"
echo "  claude                          # claude code"
echo "  loct repo-view .                # structural map"
echo "  ssh <host>                      # tailnet hop (any Host from ~/.ssh/config)"
