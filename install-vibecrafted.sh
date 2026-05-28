#!/usr/bin/env bash
# install-vibecrafted.sh — standalone vibecrafted runtime installer
# Clones vetcoders/vibecrafted, runs make install. Idempotent.
set -euo pipefail

USER_HOME="${HOME:-$(getent passwd "$(id -u)" | cut -d: -f6)}"
VIBECRAFTED_DIR="${VIBECRAFTED_DIR:-$USER_HOME/vibecrafted}"
BRANCH="${VIBECRAFTED_BRANCH:-main}"

if [ -t 1 ]; then G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; N='\033[0m'; else G=''; Y=''; R=''; N=''; fi
ok()   { printf "${G}✓${N} %s\n" "$*"; }
warn() { printf "${Y}⚠${N} %s\n" "$*"; }
err()  { printf "${R}✗${N} %s\n" "$*" >&2; }

# ── Prereqs ──
for tool in git make bash; do
  command -v "$tool" >/dev/null 2>&1 || { err "missing prereq: $tool"; exit 1; }
done

# ── Clone or update ──
if [ -d "$VIBECRAFTED_DIR/.git" ]; then
  echo "Updating $VIBECRAFTED_DIR (branch: $BRANCH)"
  (cd "$VIBECRAFTED_DIR" && git fetch origin "$BRANCH" && git checkout "$BRANCH" && git pull --ff-only)
else
  echo "Cloning vibecrafted from vetcoders/vibecrafted into $VIBECRAFTED_DIR"
  git clone --depth 1 --branch "$BRANCH" https://github.com/vetcoders/vibecrafted.git "$VIBECRAFTED_DIR"
fi

# ── Install ──
cd "$VIBECRAFTED_DIR"
if [ -f Makefile ] && grep -q '^install:' Makefile; then
  make install
else
  warn "no make install target — running bin/vibecrafted in-place"
  echo "Add to PATH: $VIBECRAFTED_DIR/bin"
fi

# ── Verify ──
if command -v vibecrafted >/dev/null 2>&1; then
  ok "vibecrafted: $(vibecrafted --version 2>&1 | head -1)"
elif [ -x "$VIBECRAFTED_DIR/bin/vibecrafted" ]; then
  ok "binary at $VIBECRAFTED_DIR/bin/vibecrafted (not in PATH yet)"
  echo "Add to PATH: export PATH=\"$VIBECRAFTED_DIR/bin:\$PATH\""
else
  err "vibecrafted binary not found after install"
  exit 1
fi

echo ""
echo "Next: vibecrafted start"
