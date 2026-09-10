#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASK="${1:-all}"

log() {
  echo ""
  echo "==> $1"
}

keybindings() {
  log "Installing VS Code keybindings"

  SRC="$ROOT/setup/keybindings/keybindings.json"

  TARGETS=(
    "$HOME/.vscode-remote/data/User/keybindings.json"
    "$HOME/.vscode-server/data/User/keybindings.json"
  )

  if [ ! -f "$SRC" ]; then
    echo "Missing keybindings file: $SRC"
    exit 1
  fi

  for TARGET in "${TARGETS[@]}"; do
    DIR="$(dirname "$TARGET")"
    mkdir -p "$DIR"

    if [ -f "$TARGET" ]; then
      cp "$TARGET" "$TARGET.backup"
    fi

    cp "$SRC" "$TARGET"
  done

  echo "Keybindings copied."
}

dotfiles() {
  log "Installing dotfiles"

  DOTFILES="$HOME/.dotfiles"
  REPO="${DOTFILES_REPO:-https://github.com/WilliamKoffi/.dotfiles.git}"

  if [ ! -d "$DOTFILES" ]; then
    git clone "$REPO" "$DOTFILES"
  else
    git -C "$DOTFILES" pull --ff-only || true
  fi

  cd "$DOTFILES"

  if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
    mv "$HOME/.zshrc" "$HOME/.zshrc.backup"
  fi

  stow zsh

  if command -v zsh >/dev/null 2>&1; then
    sudo chsh -s "$(command -v zsh)" vscode || true
  fi

  echo "Dotfiles installed."
}
base() {
  log "Installing project dependencies"

  if [ -f "package-lock.json" ]; then
    rm -f package-lock.json
  fi

  if command -v bun >/dev/null 2>&1 && [ -f "package.json" ]; then
    bun install
  else
    echo "No package.json found or bun is not installed. Skipping."
  fi
}

sync_skills() {
  log "Syncing skills from dotfiles (sparse checkout)"

  REPO="${DOTFILES_REPO:-https://github.com/WilliamKoffi/.dotfiles.git}"

  rm -rf ./.dotfiles
  git clone --filter=blob:none --sparse "$REPO" ./.dotfiles
  (cd ./.dotfiles && git sparse-checkout add skills)

  mkdir -p ./.agents
  rm -rf ./.agents/skills
  cp -r ./.dotfiles/skills ./.agents/skills
  rm -rf ./.dotfiles

  echo "Skills synced into .agents/skills."
}

agents() {
  log "Hiding agent artifacts from the host repository"

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not inside a git work tree. Skipping."
    return
  fi

  PATHS=(
    ".devcontainer"
    ".agents"
    ".claude"
    ".gemini"
    ".mcp.json"
    ".playwright-mcp"
    "opencode.json"
    "graphify-out"
    "trash"
  )

  EXCLUDE=".git/info/exclude"

  for path in "${PATHS[@]}"; do
    if ! grep -qxF "/$path" "$EXCLUDE" 2>/dev/null &&
       ! grep -qxF "$path" "$EXCLUDE" 2>/dev/null; then
      echo "/$path" >> "$EXCLUDE"
    fi

    # an exclude never applies to a file git already tracks
    if [ -n "$(git ls-files -- "$path")" ]; then
      git rm -r --cached --quiet -- "$path"
      echo "Untracked $path"
    fi
  done

  if [ -d ".devcontainer/.git" ]; then
    log "Detaching nested .devcontainer/.git"
    rm -rf ".devcontainer/.git"
  fi

  echo "Agent artifacts excluded."
}

case "$TASK" in
  all)
    dotfiles
    base
    sync_skills
    agents
    ;;
  dotfiles)
    dotfiles
    ;;
  keybindings)
    keybindings
    ;;
  base)
    base
    ;;
  skills)
    sync_skills
    ;;
  agents)
    agents
    ;;
  *)
    echo "Unknown setup task: $TASK"
    echo "Available tasks: all, dotfiles, keybindings, base, skills, agents"
    exit 1
    ;;
esac
