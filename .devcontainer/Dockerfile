# vc-workspace devcontainer — Debian 13 Trixie base
# Full vibecrafted runtime with multi-agent CLI surface
# Designed for tailnet hosts: dev container can be pulled from any tailnet
# node, host's ~/.ssh/ is mounted for cross-host operations.

FROM debian:trixie-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG USER=vc
ARG UID=1000
ARG GID=1000
ARG TZ=Europe/Warsaw

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=${TZ} \
    SHELL=/bin/zsh

# ── Base layer: developer tools, build deps ───────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl wget gnupg2 lsb-release \
      git git-lfs git-extras \
      openssh-client sshpass \
      sudo zsh bash tmux \
      vim neovim nano \
      htop btop iotop \
      jq yq ripgrep fd-find bat eza tree \
      rsync \
      build-essential pkg-config \
      libssl-dev libudev-dev libfontconfig1-dev libfreetype6-dev libxkbcommon-dev libgl-dev \
      cmake ninja-build \
      python3 python3-pip python3-venv python3-dev pipx \
      libsqlite3-dev libpq-dev \
      tzdata locales \
      direnv just \
    && rm -rf /var/lib/apt/lists/*

# ── Symlinks for Debian-renamed binaries ──────────────────────────────────
RUN ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && ln -sf /usr/bin/batcat /usr/local/bin/bat 2>/dev/null || true

# ── Locale + timezone ─────────────────────────────────────────────────────
RUN echo "${TZ}" > /etc/timezone \
    && ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && sed -i 's/# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen \
    && sed -i 's/# pl_PL.UTF-8/pl_PL.UTF-8/' /etc/locale.gen \
    && locale-gen

# ── Node.js 20 LTS ────────────────────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g npm@latest yarn pnpm \
    && rm -rf /var/lib/apt/lists/*

# ── GitHub CLI ────────────────────────────────────────────────────────────
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# ── uv (Python package manager) ───────────────────────────────────────────
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

# ── Zig 0.13.0 ────────────────────────────────────────────────────────────
ARG ZIG_VER=0.13.0
RUN ARCH=$(uname -m) \
    && case "$ARCH" in x86_64) ZA=x86_64 ;; aarch64) ZA=aarch64 ;; *) echo "unsupported"; exit 1 ;; esac \
    && curl -fsSL "https://ziglang.org/download/${ZIG_VER}/zig-linux-${ZA}-${ZIG_VER}.tar.xz" \
      | tar -xJ -C /opt/ \
    && ln -sf "/opt/zig-linux-${ZA}-${ZIG_VER}/zig" /usr/local/bin/zig

# ── Create non-root user with sudo ────────────────────────────────────────
RUN groupadd --gid ${GID} ${USER} \
    && useradd --uid ${UID} --gid ${GID} -m -s /bin/zsh ${USER} \
    && echo "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${USER} \
    && chmod 0440 /etc/sudoers.d/${USER} \
    && mkdir -p /home/${USER}/.ssh /home/${USER}/.cargo /home/${USER}/.rustup \
                /home/${USER}/.vibecrafted /home/${USER}/.aicx /home/${USER}/.config \
    && chown -R ${USER}:${USER} /home/${USER}

# ── Switch to non-root for toolchain installs ─────────────────────────────
USER ${USER}
WORKDIR /home/${USER}

# ── Rust toolchain (stable, full profile) ─────────────────────────────────
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --default-toolchain stable --profile default \
                   -c rust-analyzer -c rust-src -c clippy -c rustfmt \
                   --no-modify-path
ENV PATH="/home/${USER}/.cargo/bin:${PATH}" \
    CARGO_HOME="/home/${USER}/.cargo" \
    RUSTUP_HOME="/home/${USER}/.rustup"

# ── Cargo CLI niceties ────────────────────────────────────────────────────
RUN cargo install --locked \
      cargo-watch cargo-edit cargo-expand cargo-outdated cargo-audit \
    && rm -rf /home/${USER}/.cargo/registry/cache

# ── ssh config bridge: predefine mount points ─────────────────────────────
# Host's ~/.ssh/ will be bind-mounted at runtime (read-only) for cross-host
# tailnet operations (ssh <host> for any Host in ~/.ssh/config).
RUN chmod 700 /home/${USER}/.ssh

# ── Switch back to root for system-wide installs of agent CLIs ────────────
USER root
WORKDIR /workspace

# ── AI agent CLIs (npm global) ────────────────────────────────────────────
# Claude Code: official Anthropic CLI (NOT npm 'claude' — that's wrong pkg)
RUN npm install -g @anthropic-ai/claude-code \
    && ln -sf "$(npm root -g)/@anthropic-ai/claude-code/cli.js" /usr/local/bin/claude \
    && chmod +x /usr/local/bin/claude \
    && claude --version

# OpenAI Codex CLI
RUN npm install -g @openai/codex \
    && (codex --version || echo "codex installed but version check failed")

# Google Gemini CLI
RUN npm install -g @google/gemini-cli \
    && (gemini --version || echo "gemini installed but version check failed")

# Antigravity Python SDK (Google's agent framework — Python install via uv)
RUN pipx install antigravity-sdk 2>/dev/null \
    || pip install --break-system-packages antigravity-sdk 2>/dev/null \
    || echo "antigravity-sdk pip install deferred — install in post-create"

# ── Default shell setup for vc user ───────────────────────────────────────
USER ${USER}
WORKDIR /home/${USER}
RUN ( \
    echo 'export PATH="$HOME/.cargo/bin:$HOME/.local/bin:/usr/local/bin:$PATH"' ; \
    echo 'export CARGO_HOME="$HOME/.cargo"' ; \
    echo 'export RUSTUP_HOME="$HOME/.rustup"' ; \
    echo 'export EDITOR="vim"' ; \
    echo 'export VIBECRAFTED_HOME="$HOME/.vibecrafted"' ; \
    echo 'eval "$(direnv hook zsh 2>/dev/null || true)"' ; \
    echo 'alias ls="eza"' ; \
    echo 'alias ll="eza -l"' ; \
    echo 'alias la="eza -la"' ; \
    echo 'alias cat="bat -p"' ; \
    ) > /home/${USER}/.zshrc

# Bash fallback
RUN cp /home/${USER}/.zshrc /home/${USER}/.bashrc 2>/dev/null || true

# ── Healthcheck ───────────────────────────────────────────────────────────
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD zsh -c 'true' || exit 1

WORKDIR /workspace
CMD ["zsh", "-l"]
