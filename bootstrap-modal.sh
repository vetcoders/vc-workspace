#!/usr/bin/env bash
# ============================================================================
# bootstrap-modal.sh — bootstrap a Modal (or any Debian/Ubuntu) container
# do pracy z vc-runtime stackiem
#
# What this installs:
#   - Rust toolchain (rustup stable)
#   - Zig 0.13.0 (vc_, scratch*.zig)
#   - Claude Code CLI (@anthropic-ai/claude-code) + symlink
#   - Codex CLI (@openai/codex) [optional]
#   - Gemini CLI (@google/gemini-cli) [optional]
#   - uv (Python package manager)
#   - eza, bat, fd, rg, just, zoxide (CLI niceties via cargo)
#   - loct CLI (from loctree-suite if mounted; else cargo install)
#   - aicx CLI (from aicx if mounted; else cargo install)
#   - microsandbox (from workspace if present)
#
# Usage:
#   bash bootstrap-modal.sh                # full install
#   bash bootstrap-modal.sh --minimal      # rust + claude only
#   bash bootstrap-modal.sh --skip-agents  # no codex/gemini
#
# Tested on:
#   - Modal containers (root@modal:/workspace#)
#   - Ubuntu 24.04 devcontainer
#   - Debian 11/12 bookworm/bullseye
# ============================================================================

set -euo pipefail

# ── Parse args ────────────────────────────────────────────────────────────
MINIMAL=0
SKIP_AGENTS=0
SKIP_RUST_CLI=0
WORKSPACE="${VC_WORKSPACE:-/workspace}"
ZIG_VER="${ZIG_VER:-0.13.0}"

for arg in "$@"; do
  case "$arg" in
    --minimal)        MINIMAL=1 ;;
    --skip-agents)    SKIP_AGENTS=1 ;;
    --skip-rust-cli)  SKIP_RUST_CLI=1 ;;
    --workspace=*)    WORKSPACE="${arg#*=}" ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \?//' | head -30
      exit 0
      ;;
  esac
done

# ── Colors ────────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; BLUE=''; NC=''
fi

log()  { printf "${BLUE}[%s]${NC} %s\n" "$(date +%H:%M:%S)" "$*"; }
ok()   { printf "${GREEN}  ✓${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}  ⚠${NC} %s\n" "$*"; }
err()  { printf "${RED}  ✗${NC} %s\n" "$*" >&2; }

# ── Pre-flight ────────────────────────────────────────────────────────────
log "── vc-runtime Modal bootstrap ──"
log "Workspace: $WORKSPACE"
log "User: $(whoami) (uid=$(id -u))"
log "OS: $(. /etc/os-release && echo "$PRETTY_NAME")"

if [ "$(id -u)" -ne 0 ] && ! command -v sudo >/dev/null; then
  warn "Not root and no sudo — some installs may fail"
fi

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  SUDO=sudo
fi

# ── Stage 1: apt deps (build essentials + libs) ──────────────────────────
log "Stage 1/9: apt dependencies"
export DEBIAN_FRONTEND=noninteractive
$SUDO apt-get update -qq
$SUDO apt-get install -y --no-install-recommends \
  ca-certificates curl wget git git-lfs gnupg2 lsb-release \
  build-essential pkg-config libssl-dev cmake ninja-build \
  libudev-dev libfontconfig1-dev libfreetype6-dev libxkbcommon-dev \
  python3-dev python3-pip python3-venv \
  jq htop tmux unzip xz-utils \
  >/dev/null 2>&1 || warn "apt install had warnings (continuing)"
ok "base deps installed"

# ── Stage 2: Rust toolchain ──────────────────────────────────────────────
log "Stage 2/9: Rust toolchain"
if command -v rustc >/dev/null 2>&1; then
  ok "rust already present: $(rustc --version)"
else
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain stable --profile default --no-modify-path
  # Source for this script's remainder
  if [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
  fi
  # System-wide PATH (in case of root install)
  if [ "$(id -u)" -eq 0 ]; then
    echo 'export PATH="/root/.cargo/bin:$PATH"' >> /etc/profile.d/rust.sh
    echo 'export RUSTUP_HOME=/root/.rustup' >> /etc/profile.d/rust.sh
    chmod 644 /etc/profile.d/rust.sh
  fi
  ok "rust installed: $(rustc --version)"
fi

# ── Stage 3: Zig ──────────────────────────────────────────────────────────
log "Stage 3/9: Zig $ZIG_VER"
if command -v zig >/dev/null 2>&1; then
  ok "zig already present: $(zig version)"
else
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)   ZIG_ARCH=x86_64 ;;
    aarch64)  ZIG_ARCH=aarch64 ;;
    *)        err "unsupported arch for Zig: $ARCH"; ZIG_ARCH="" ;;
  esac
  if [ -n "$ZIG_ARCH" ]; then
    ZIG_DIR="/opt/zig-linux-${ZIG_ARCH}-${ZIG_VER}"
    if [ ! -d "$ZIG_DIR" ]; then
      curl -fsSL "https://ziglang.org/download/${ZIG_VER}/zig-linux-${ZIG_ARCH}-${ZIG_VER}.tar.xz" \
        | $SUDO tar -xJ -C /opt/
    fi
    $SUDO ln -sf "$ZIG_DIR/zig" /usr/local/bin/zig
    ok "zig installed: $(zig version)"
  fi
fi

# ── Stage 4: Node sanity + Claude Code ───────────────────────────────────
log "Stage 4/9: Node + Claude Code CLI"
if ! command -v node >/dev/null 2>&1; then
  warn "node not found — installing nodesource 20.x"
  curl -fsSL https://deb.nodesource.com/setup_20.x | $SUDO -E bash -
  $SUDO apt-get install -y nodejs >/dev/null
fi
ok "node: $(node --version)  npm: $(npm --version)"

# CRITICAL: 'npm install -g claude' to inny pakiet! Właściwy: @anthropic-ai/claude-code
if [ -L /usr/local/bin/claude ] || command -v claude >/dev/null 2>&1; then
  if claude --version >/dev/null 2>&1; then
    ok "claude already in PATH: $(claude --version 2>&1 | head -1)"
  else
    warn "claude command exists but broken — re-installing"
    $SUDO rm -f /usr/local/bin/claude 2>/dev/null || true
  fi
fi

if ! claude --version >/dev/null 2>&1; then
  npm install -g @anthropic-ai/claude-code 2>&1 | tail -3
  # Symlink to /usr/local/bin if not in PATH
  NPM_GLOBAL="$(npm root -g)"
  NPM_BIN="$(npm bin -g 2>/dev/null || echo "")"
  if [ -z "$NPM_BIN" ]; then
    NPM_BIN="$(npm config get prefix)/bin"
  fi
  if [ -x "$NPM_BIN/claude" ]; then
    $SUDO ln -sf "$NPM_BIN/claude" /usr/local/bin/claude
  elif [ -f "$NPM_GLOBAL/@anthropic-ai/claude-code/cli.js" ]; then
    $SUDO ln -sf "$NPM_GLOBAL/@anthropic-ai/claude-code/cli.js" /usr/local/bin/claude
    $SUDO chmod +x /usr/local/bin/claude
  fi
  if command -v claude >/dev/null 2>&1; then
    ok "claude installed: $(claude --version 2>&1 | head -1)"
  else
    err "claude install failed — check 'npm root -g' manually"
  fi
fi

[ "$MINIMAL" -eq 1 ] && { ok "minimal mode — stopping after Stage 4"; exit 0; }

# ── Stage 5: Codex + Gemini CLI (opcjonalne) ─────────────────────────────
if [ "$SKIP_AGENTS" -eq 0 ]; then
  log "Stage 5/9: Codex + Gemini CLI"
  npm install -g @openai/codex 2>&1 | tail -2 || warn "codex install failed"
  npm install -g @google/gemini-cli 2>&1 | tail -2 || warn "gemini install failed"
  command -v codex >/dev/null && ok "codex: $(codex --version 2>&1 | head -1)" || warn "codex not in PATH"
  command -v gemini >/dev/null && ok "gemini: $(gemini --version 2>&1 | head -1)" || warn "gemini not in PATH"
else
  log "Stage 5/9: skipped (--skip-agents)"
fi

# ── Stage 6: uv (Python) ─────────────────────────────────────────────────
log "Stage 6/9: uv (Python package manager)"
if command -v uv >/dev/null 2>&1; then
  ok "uv already present: $(uv --version)"
else
  curl -LsSf https://astral.sh/uv/install.sh | sh
  if [ -f "$HOME/.cargo/env" ]; then . "$HOME/.cargo/env"; fi
  # uv installer puts it in ~/.local/bin or ~/.cargo/bin
  if [ -x "$HOME/.local/bin/uv" ]; then
    $SUDO ln -sf "$HOME/.local/bin/uv" /usr/local/bin/uv
  fi
  command -v uv >/dev/null && ok "uv: $(uv --version)" || warn "uv install needs PATH refresh"
fi

# ── Stage 7: Rust CLI niceties (eza, bat, fd, rg, just, zoxide) ──────────
if [ "$SKIP_RUST_CLI" -eq 0 ]; then
  log "Stage 7/9: Rust CLI niceties via cargo"
  CARGO_TOOLS=(eza bat fd-find ripgrep just zoxide tokei)
  for tool in "${CARGO_TOOLS[@]}"; do
    bin_name="${tool/fd-find/fd}"  # fd-find ships as 'fd'
    if command -v "$bin_name" >/dev/null 2>&1; then
      ok "$bin_name already present"
    else
      log "  installing $tool"
      cargo install --locked --quiet "$tool" 2>&1 | tail -2 || warn "$tool install failed"
    fi
  done
else
  log "Stage 7/9: skipped (--skip-rust-cli)"
fi

# ── Stage 8: MANDATORY framework binaries (loct + aicx) ──────────────────
# loct (Loctree) and aicx (Vibecrafted continuity runtime) are required parts
# of the framework install contract. If either fails, this stage exits non-zero.
log "Stage 8/9: MANDATORY framework binaries (loct + aicx)"

vcf_install_fail=0

# loct — official installer at loct.io (primary); local source fallback
if command -v loct >/dev/null 2>&1; then
  ok "loct already present: $(loct --version 2>&1 | head -1)"
else
  log "  installing loct (curl -fsSL https://loct.io/install.sh | sh)"
  curl -fsSL https://loct.io/install.sh | sh 2>&1 | tail -3 || true
  if ! command -v loct >/dev/null 2>&1 && [ -f "$WORKSPACE/loctree-suite/Cargo.toml" ]; then
    log "  fallback: building loct from $WORKSPACE/loctree-suite"
    (cd "$WORKSPACE/loctree-suite" && cargo install --path crates/loct --locked 2>&1 | tail -3) || true
  fi
  if command -v loct >/dev/null 2>&1; then
    ok "loct: $(loct --version 2>&1 | head -1)"
  else
    err "loct install FAILED — framework contract violated"
    vcf_install_fail=1
  fi
fi

# aicx — GitHub releases primary, loct.io bundle fallback, local source fallback
if command -v aicx >/dev/null 2>&1; then
  ok "aicx already present: $(aicx --version 2>&1 | head -1)"
else
  log "  installing aicx (priority: GH releases → loct.io bundle → local build)"
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)
  case "${os}-${arch}" in
    linux-x86_64)   target="x86_64-unknown-linux-gnu" ;;
    linux-aarch64)  target="aarch64-unknown-linux-gnu" ;;
    darwin-arm64)   target="aarch64-apple-darwin" ;;
    darwin-x86_64)  target="x86_64-apple-darwin" ;;
    *)              target="" ;;
  esac
  if [ -n "$target" ]; then
    tag=$(curl -fsSL "https://api.github.com/repos/Loctree/aicx/releases/latest" 2>/dev/null \
          | grep -m1 '"tag_name"' | cut -d'"' -f4 || true)
    if [ -n "$tag" ]; then
      asset="aicx-${tag}-${target}-slim-unsigned.tar.gz"
      url="https://github.com/Loctree/aicx/releases/download/${tag}/${asset}"
      log "    GH release: $tag ($target)"
      tmpdir=$(mktemp -d)
      if curl -fsSL "$url" 2>/dev/null | tar -xz -C "$tmpdir" 2>/dev/null; then
        bin=$(find "$tmpdir" -type f -name 'aicx' 2>/dev/null | head -1)
        if [ -n "$bin" ]; then
          chmod +x "$bin"
          if [ "$(id -u)" -eq 0 ]; then
            install -m 755 "$bin" /usr/local/bin/aicx
          elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
            sudo install -m 755 "$bin" /usr/local/bin/aicx
          else
            mkdir -p "$HOME/.local/bin"
            install -m 755 "$bin" "$HOME/.local/bin/aicx"
          fi
        fi
      fi
      rm -rf "$tmpdir"
    fi
  fi
  if ! command -v aicx >/dev/null 2>&1; then
    log "    GH path failed — trying loct.io bundle"
    curl -fsSL https://loct.io/install.sh | sh 2>&1 | tail -3 || true
  fi
  if ! command -v aicx >/dev/null 2>&1 && [ -f "$WORKSPACE/aicx/Cargo.toml" ]; then
    log "    fallback: building from $WORKSPACE/aicx"
    (cd "$WORKSPACE/aicx" && cargo install --path . --locked 2>&1 | tail -3) || true
  fi
  if command -v aicx >/dev/null 2>&1; then
    ok "aicx: $(aicx --version 2>&1 | head -1)"
  else
    err "aicx install FAILED — framework contract violated"
    vcf_install_fail=1
  fi
fi

if [ "$vcf_install_fail" -ne 0 ]; then
  err "MANDATORY framework binaries failed to install — see above"
  err "Hint: check network access, or run 'cargo install aicx' / 'curl https://loct.io/install.sh | sh' manually"
  exit 1
fi

# ── Stage 9: microsandbox (libkrun substrate, if workspace mounted) ──────
log "Stage 9/9: microsandbox"
if command -v microsandbox >/dev/null 2>&1; then
  ok "microsandbox already present"
elif [ -f "$WORKSPACE/microsandbox/Cargo.toml" ]; then
  log "  building microsandbox from $WORKSPACE/microsandbox (release, ~5-10 min)"
  (cd "$WORKSPACE/microsandbox" && cargo build --release 2>&1 | tail -5) \
    || warn "microsandbox build failed (likely missing libkrun KVM access)"
  if [ -x "$WORKSPACE/microsandbox/target/release/microsandbox" ]; then
    $SUDO ln -sf "$WORKSPACE/microsandbox/target/release/microsandbox" /usr/local/bin/microsandbox
    ok "microsandbox linked"
  fi
else
  warn "microsandbox not mounted at $WORKSPACE/microsandbox — skipping"
fi

# ── Final report ─────────────────────────────────────────────────────────
log ""
log "── Verification ──"
for tool in rustc cargo zig node npm claude codex gemini uv loct aicx microsandbox eza bat fd rg just; do
  if command -v "$tool" >/dev/null 2>&1; then
    ver=$("$tool" --version 2>&1 | head -1 | head -c 60)
    ok "$tool — $ver"
  else
    warn "$tool — not available"
  fi
done

log ""
log "── PATH ──"
echo "$PATH" | tr ':' '\n' | sed 's/^/  /'

log ""
ok "vc-runtime bootstrap complete."
log "Next step: cd \$WORKSPACE && claude --dangerously-skip-permissions --verbose"
log ""
log "𝚅𝚒𝚋𝚎𝚌𝚛𝚊𝚏𝚝𝚎𝚍. with AI Agents by VetCoders (c)2024-2026 LibraxisAI"
