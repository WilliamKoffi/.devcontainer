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
    && ln -sf /usr/bin/batcat /usr/local/bin/bat \
    && ln -sf "$(which fdfind)" /usr/local/bin/fd \
    && git lfs install --system \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# 2. Install Bun + Codex + Antigravity for the Codespaces user
USER vscode

ENV BUN_INSTALL="/home/vscode/.bun"
ENV PATH="/home/vscode/.bun/bin:/home/vscode/.local/bin:${PATH}"

RUN curl -fsSL https://bun.sh/install | bash

RUN curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh

RUN curl -fsSL https://antigravity.google/cli/install.sh | bash

# 3. Keep vscode as default user
USER vscode