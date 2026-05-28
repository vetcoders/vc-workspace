#!/usr/bin/env bash
# install-aicx.sh — standalone aicx installer
# Priority: 1. GitHub releases (Loctree/aicx)
#           2. loct.io bundle (once aicx is folded into the loct installer)
#           3. local source build (if $WORKSPACE/aicx exists)
set -uo pipefail

WORKSPACE="${VC_WORKSPACE:-/workspace}"
REPO="Loctree/aicx"
GH_API="https://api.github.com/repos/${REPO}/releases/latest"
GH_DL="https://github.com/${REPO}/releases/download"

if [ -t 1 ]; then G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; N='\033[0m'; else G=''; Y=''; R=''; N=''; fi
ok()   { printf "${G}✓${N} %s\n" "$*"; }
warn() { printf "${Y}⚠${N} %s\n" "$*"; }
err()  { printf "${R}✗${N} %s\n" "$*" >&2; }
log()  { printf "[aicx] %s\n" "$*"; }

if command -v aicx >/dev/null 2>&1; then
  ok "aicx already present: $(aicx --version 2>&1 | head -1)"
  exit 0
fi

# Determine target triple
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "${OS}-${ARCH}" in
  linux-x86_64)  TARGET="x86_64-unknown-linux-gnu" ;;
  linux-aarch64|linux-arm64) TARGET="aarch64-unknown-linux-gnu" ;;
  darwin-arm64|darwin-aarch64) TARGET="aarch64-apple-darwin" ;;
  darwin-x86_64) TARGET="x86_64-apple-darwin" ;;
  *) TARGET="" ;;
esac

install_binary() {
  local src="$1"
  if [ "$(id -u)" -eq 0 ]; then
    install -m 755 "$src" /usr/local/bin/aicx
  elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    sudo install -m 755 "$src" /usr/local/bin/aicx
  else
    mkdir -p "$HOME/.local/bin"
    install -m 755 "$src" "$HOME/.local/bin/aicx"
    case ":$PATH:" in *":$HOME/.local/bin:"*) ;;
      *) warn "$HOME/.local/bin not in PATH — add it for aicx to be discoverable" ;;
    esac
  fi
}

# ── Priority 1: GitHub releases ─────────────────────────────────────────
log "trying GitHub releases at github.com/${REPO}"
if [ -n "$TARGET" ]; then
  TAG=$(curl -fsSL "$GH_API" 2>/dev/null | grep -m1 '"tag_name"' | cut -d'"' -f4 || true)
  if [ -n "$TAG" ]; then
    ASSET="aicx-${TAG}-${TARGET}-slim-unsigned.tar.gz"
    URL="${GH_DL}/${TAG}/${ASSET}"
    log "downloading $ASSET"
    TMPDIR=$(mktemp -d)
    if curl -fsSL "$URL" 2>/dev/null | tar -xz -C "$TMPDIR" 2>/dev/null; then
      BIN=$(find "$TMPDIR" -type f -name 'aicx' 2>/dev/null | head -1)
      if [ -n "$BIN" ] && [ -f "$BIN" ]; then
        chmod +x "$BIN"
        install_binary "$BIN"
        rm -rf "$TMPDIR"
        if command -v aicx >/dev/null 2>&1; then
          ok "aicx installed from GitHub release ${TAG}: $(aicx --version 2>&1 | head -1)"
          exit 0
        fi
      fi
    fi
    rm -rf "$TMPDIR"
    warn "GH release fetch/extract failed (tag=$TAG asset=$ASSET)"
  else
    warn "could not query latest release tag"
  fi
else
  warn "unsupported platform: ${OS}-${ARCH}"
fi

# ── Priority 2: loct.io bundle ──────────────────────────────────────────
log "GH path failed — trying loct.io installer bundle"
curl -fsSL https://loct.io/install.sh | sh 2>&1 | tail -3 || true
if command -v aicx >/dev/null 2>&1; then
  ok "aicx installed from loct.io bundle: $(aicx --version 2>&1 | head -1)"
  exit 0
fi

# ── Priority 3: local source build ──────────────────────────────────────
if [ -f "$WORKSPACE/aicx/Cargo.toml" ] && command -v cargo >/dev/null 2>&1; then
  log "loct.io path didn't yield aicx — building from $WORKSPACE/aicx"
  (cd "$WORKSPACE/aicx" && cargo install --path . --locked 2>&1 | tail -3) || true
  if command -v aicx >/dev/null 2>&1; then
    ok "aicx built from local source: $(aicx --version 2>&1 | head -1)"
    exit 0
  fi
fi

err "aicx install FAILED via all paths (GH release, loct.io, local build)"
err "Hint: download from https://github.com/${REPO}/releases manually"
exit 1
