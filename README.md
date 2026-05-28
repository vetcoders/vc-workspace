# vc-workspace

**Full vibecrafted runtime + multi-agent surface** for Modal, GitHub Codespaces,
local devcontainers, and any Debian-based host. Tailnet-aware via host
sshconfig mount.

Two ways to use it:

1. **Bootstrap script** — `bash bootstrap-modal.sh` on any Debian/Ubuntu/Modal
   container (quick, no IDE integration).
2. **Devcontainer** — open this folder in VS Code → "Reopen in Container".
   Full Debian Trixie image with vibecrafted runtime, multi-agent surface,
   tailnet sshconfig, Rust+TS+Python toolchains, pre-staged VS Code extensions.

## Quick start

### A. Bootstrap script (any container)

```bash
curl -fsSL https://raw.githubusercontent.com/vetcoders/vc-workspace/main/bootstrap-modal.sh | bash
# or minimal:
curl -fsSL https://raw.githubusercontent.com/vetcoders/vc-workspace/main/bootstrap-modal.sh | bash -s -- --minimal
```

### B. Devcontainer (VS Code, Codespaces)

```bash
git clone https://github.com/vetcoders/vc-workspace
cd vc-workspace
code .
# → "Reopen in Container"
```

### C. Standalone installers

```bash
bash install-vibecrafted.sh    # clone + install vibecrafted runtime only
bash install-agents.sh         # claude + codex + gemini + antigravity-sdk
```

## Multi-agent surface

| Agent | CLI | Install | IDE |
|---|---|---|---|
| **Claude Code** | `claude` | `@anthropic-ai/claude-code` (npm) | `anthropic.claude-code` |
| **OpenAI Codex** | `codex` | `@openai/codex` (npm) | — |
| **Google Gemini CLI** | `gemini` | `@google/gemini-cli` (npm) | `google.geminicodeassist` |
| **Google Antigravity** | (Python SDK) | `antigravity-sdk` (pip/uv) | VS Code ext |
| **Cline** | — (IDE only) | — | `saoudrizwan.claude-dev` |
| **Continue** | — (IDE only) | — | `continue.continue` |
| **Junie** | — (IDE only) | — | JetBrains plugin |
| **Aider** | `aider` | `aider-chat` (uv/pipx) | — |
| **GitHub Copilot** | — (IDE only) | — | `github.copilot` |

CLIs are installed by `bootstrap-modal.sh` and `install-agents.sh`.
IDE extensions are pre-listed in `.devcontainer/devcontainer.json` and
auto-install when the devcontainer opens in VS Code.

## Toolchains

The Debian Trixie devcontainer image ships with:

- **Rust** (stable + rust-analyzer + rust-src + clippy + rustfmt)
- **Node.js 20** (npm + pnpm + yarn) + TypeScript + Vite + create-vite/next/astro
- **Python 3.12** (system) + `uv` (Astral) + ruff + mypy + pytest + ipython
- **Zig** 0.13.0

### Framework contract — mandatory binaries

These are **required** parts of the vibecrafted framework install. If either
fails during image build / bootstrap, the install errors out:

- **`loct`** — Loctree semantic-AST CLI · `curl -fsSL https://loct.io/install.sh | sh`
- **`aicx`** — Vibecrafted continuity runtime · `cargo install aicx` ([crates.io](https://crates.io/crates/aicx) · [Loctree/aicx](https://github.com/Loctree/aicx))
- **`vibecrafted`** — full skill ecosystem (`vc-init`, `vc-operator`, `vc-marbles`, ...) · [vetcoders/vibecrafted](https://github.com/vetcoders/vibecrafted)

See [vibecrafted.io/aicx](https://vibecrafted.io/aicx) for the AICX
representation layer (use cases, comparison vs `aictx`, what becomes visible).

## Tailnet / sshconfig integration

The devcontainer mounts the host's `~/.ssh/` **read-only** at `/home/vc/.ssh/`.
Any tailnet host defined in your sshconfig is reachable from inside the
container:

```bash
# Inside the devcontainer:
ssh <your-tailnet-host>
# Any Host entry from your ~/.ssh/config is reachable
```

The container uses `--network=host` so tailscale interface, DNS, and routing
from the host work transparently. No tailscale daemon needed inside the
container.

For Codespaces / Modal / other remote runtimes that don't expose tailnet:
mount your sshconfig as a workspace file or use a tailnet sidecar.

## Devcontainer mounts

| Mount | Purpose |
|---|---|
| `~/.ssh` → `/home/vc/.ssh` (RO) | tailnet sshconfig + identity |
| `~/.cargo` → `/home/vc/.cargo` | Rust state persistence |
| `~/.rustup` → `/home/vc/.rustup` | Rust toolchain persistence |
| `~/.vibecrafted` → `/home/vc/.vibecrafted` | vibecrafted state |
| `~/.aicx` → `/home/vc/.aicx` | aicx session index |
| `~/.claude` → `/home/vc/.claude` | Claude Code config |
| `~/.codex` → `/home/vc/.codex` | Codex config |
| `~/.config/gh` → `/home/vc/.config/gh` | gh CLI auth |

## Bootstrap-script stages (full)

| Stage | Tool | Source | Skippable |
|---|---|---|---|
| 1 | apt base deps | apt | — |
| 2 | Rust toolchain | sh.rustup.rs | — |
| 3 | Zig 0.13.0 | ziglang.org | — |
| 4 | Node 20 + Claude Code | nodesource + npm | — |
| 5 | Codex + Gemini CLI | npm | `--skip-agents` |
| 6 | `uv` | astral.sh | — |
| 7 | `eza`/`bat`/`fd`/`rg`/`just`/`zoxide`/`tokei` | cargo | `--skip-rust-cli` |
| **8** | **`loct` (loct.io installer), `aicx` (`cargo install aicx`)** | **curl + crates.io** | **MANDATORY** |
| 9 | `microsandbox` | local workspace if mounted | — |

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

Plus the rest of the vibecrafted stack so a fresh container is useful in one
command.

## Mounted workspace expectations

If `/workspace/` (or `$VC_WORKSPACE`) contains:

- `loctree-suite/` → `loct` is built from source
- `aicx/` → `aicx` is built from source
- `microsandbox/` → `microsandbox` is built and linked
- `vibecrafted/` → vibecrafted runtime installed from there

Otherwise these stages clone from public mirrors where available, else warn
and continue.

## Tested on

- Modal containers (`root@modal:/workspace#` Debian-based)
- Debian 13 Trixie devcontainers (this image)
- Debian 11 / 12 (bookworm / bullseye)
- Ubuntu 24.04 devcontainers
- GitHub Codespaces (Ubuntu base)

## Caveats

- **microsandbox build requires libkrun + KVM access.** Modal containers
  generally don't expose `/dev/kvm`; stage 9 warns and continues. Run on a
  bare-metal host or a KVM-passthrough VM for sandbox execution.
- **`--dangerously-skip-permissions`** is a Claude Code flag — use only inside
  a real sandbox / disposable container, never on a host with sensitive data.
- **`--network=host`** in the devcontainer is required for tailnet access.
  If you don't want host networking, drop the `runArgs` entry and lose tailnet
  reachability.
- The script is **idempotent**: re-running skips already-installed tools.

## Sister projects

- [`vibecrafted`](https://github.com/vetcoders/vibecrafted) — release engine for AI-built software
- [`loctree`](https://loct.io) — semantic-AST structural map for LLM agents
- [`aicx`](https://vibecrafted.io/aicx) — Vibecrafted continuity runtime (intention memory)

## License

MIT — see [LICENSE](./LICENSE).

---

_𝚅𝚒𝚋𝚎𝚌𝚛𝚊𝚏𝚝𝚎𝚍. with AI Agents by VetCoders (c)2024-2026 LibraxisAI_
