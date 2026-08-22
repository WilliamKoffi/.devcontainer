FROM mcr.microsoft.com/devcontainers/base:ubuntu

# 1. Install system tools as root
USER root

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive && \
    apt-get -y install --no-install-recommends \
    curl \
    ca-certificates \
    git \
    git-lfs \
    ripgrep \
    fd-find \
    python3 \
    python3-pip \
    python3-venv \
    python-is-python3 \
    bat \
    zsh \
    stow \
    gpg \
    zoxide \
    && ln -sf /usr/bin/batcat /usr/local/bin/bat \
    && ln -sf "$(which fdfind)" /usr/local/bin/fd \
    && git lfs install --system \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# eza (apt repo from the eza maintainers)
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
    | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg \
    && chmod 644 /etc/apt/keyrings/gierens.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
    > /etc/apt/sources.list.d/gierens.list \
    && apt-get update \
    && apt-get -y install --no-install-recommends eza \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Node.js + npm (NodeSource LTS), pnpm via corepack
ARG NODE_MAJOR=22
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
    && apt-get -y install --no-install-recommends nodejs \
    && corepack enable \
    && corepack prepare pnpm@latest --activate \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# 2. Install Bun + Codex + Antigravity + agent tooling for the Codespaces user
USER vscode

ENV BUN_INSTALL="/home/vscode/.bun"
ENV NPM_CONFIG_PREFIX="/home/vscode/.npm-global"
ENV PNPM_HOME="/home/vscode/.local/share/pnpm"
ENV PATH="/home/vscode/.bun/bin:/home/vscode/.npm-global/bin:/home/vscode/.local/share/pnpm:/home/vscode/.local/bin:${PATH}"

RUN mkdir -p "$NPM_CONFIG_PREFIX/bin" "$PNPM_HOME"

RUN curl -fsSL https://bun.sh/install | bash

RUN curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh

RUN curl -fsSL https://antigravity.google/cli/install.sh | bash

# uv (Astral) - shims land in /home/vscode/.local/bin, already on PATH
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Coding agents / tooling from npm
RUN npm install -g freebuff @nanonets/graft

# Graphify - https://github.com/Graphify-Labs/graphify
RUN uv tool install graphifyy

# 3. Keep vscode as default user
USER vscode