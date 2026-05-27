# vc-workspace

Container bootstrap for the **vibecrafted / loctree / aicx** stack.
Idempotent, single-script setup for Modal, GitHub Codespaces, devcontainers,
or any Debian / Ubuntu base.

## Quick start

### One-liner (pipe-to-bash)

```bash
curl -fsSL https://raw.githubusercontent.com/vetcoders/vc-workspace/main/bootstrap-modal.sh | bash
```

### Cloned / mounted

```bash
git clone https://github.com/vetcoders/vc-workspace
cd vc-workspace
bash bootstrap-modal.sh
```

### Minimal (Rust + Claude Code only, ~2 min)

```bash
bash bootstrap-modal.sh --minimal
```

## What it installs

| Stage | Tool | Source | Skippable |
|---|---|---|---|
| 1 | apt base deps (build-essential, cmake, openssl, fontconfig, freetype, xkbcommon, python3-dev) | apt | — |
| 2 | Rust toolchain (rustup stable) | sh.rustup.rs | — |
| 3 | Zig `0.13.0` | ziglang.org | — |
| 4 | Node 20 + Claude Code CLI (`@anthropic-ai/claude-code`) | nodesource + npm | — |
| 5 | Codex CLI (`@openai/codex`) + Gemini CLI (`@google/gemini-cli`) | npm | `--skip-agents` |
| 6 | `uv` (Python package manager) | astral.sh | — |
| 7 | `eza`, `bat`, `fd`, `rg`, `just`, `zoxide`, `tokei` | cargo | `--skip-rust-cli` |
| 8 | `loct` (Loctree CLI), `aicx` | local workspace if mounted | — |
| 9 | `microsandbox` (libkrun execution substrate) | local workspace if mounted | — |

## Flags

```bash
bash bootstrap-modal.sh                # full install
bash bootstrap-modal.sh --minimal      # rust + claude only
bash bootstrap-modal.sh --skip-agents  # no codex/gemini
bash bootstrap-modal.sh --skip-rust-cli  # no eza/bat/fd etc.
bash bootstrap-modal.sh --workspace=/data/myworkspace  # custom mount path
```

## Why the script exists

The npm package `claude` (no namespace) is **not** Claude Code — it's an
unrelated library. The official package is **`@anthropic-ai/claude-code`**,
and after install the binary may not be in `PATH` depending on the container
base. This script:

1. Installs the **right** npm package.
2. Symlinks the binary to `/usr/local/bin/claude` (fallback when `npm bin -g`
   doesn't land in `PATH`).
3. Verifies `claude --version` works before declaring success.

Plus the rest of the vc-runtime / vibecrafted stack so a fresh container is
useful in one command.

## Mounted workspace expectations

If `/workspace/` (or `$VC_WORKSPACE`) contains:

- `loctree-suite/` → `loct` is built from source (stage 8)
- `aicx/` → `aicx` is built from source (stage 8)
- `microsandbox/` → `microsandbox` is built and linked (stage 9)

Otherwise these stages emit warnings and continue — install upstream
manually if needed.

## Tested on

- Modal containers (`root@modal:/workspace#` Debian-based)
- Ubuntu 24.04 devcontainers
- Debian 11 / 12 (bookworm / bullseye)
- GitHub Codespaces (Ubuntu base)

## Caveats

- **microsandbox build requires libkrun + KVM access.** Modal containers
  generally don't expose `/dev/kvm`; stage 9 warns and continues. Run on a
  bare-metal host or a KVM-passthrough VM if you need sandbox execution.
- **`--dangerously-skip-permissions`** is a Claude Code flag — use only inside
  a real sandbox / disposable container, never on a host with sensitive data.
- The script is **idempotent**: re-running skips already-installed tools.
  Useful for partial-install recovery.

## Sister projects

- [`vibecrafted`](https://vibecrafted.io) — release engine for AI-built software
- [`loctree`](https://loctree.dev) — semantic-AST structural map for LLM agents

## License

MIT — see [LICENSE](./LICENSE).

---

_𝚅𝚒𝚋𝚎𝚌𝚛𝚊𝚏𝚝𝚎𝚍. with AI Agents by VetCoders (c)2024-2026 LibraxisAI_
