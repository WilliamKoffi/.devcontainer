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

  mkdir -p ./.devcontainer/.agents
  rm -rf ./.devcontainer/.agents/skills
  cp -r ./.dotfiles/skills ./.devcontainer/.agents/skills
  rm -rf ./.dotfiles

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    EXCLUDE="./.git/info/exclude"
    for pattern in ".devcontainer" ".agents"; do
      if ! grep -qxF "$pattern" "$EXCLUDE" 2>/dev/null; then
        echo "$pattern" >> "$EXCLUDE"
      fi
    done

    if [ -d ./.devcontainer/.git ]; then
      log "Detaching nested .devcontainer/.git"
      rm -rf ./.devcontainer/.git
    fi
  fi

  echo "Skills synced into .devcontainer/.agents/skills."
}

case "$TASK" in
  all)
    dotfiles
    keybindings
    base
    sync_skills
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
  *)
    echo "Unknown setup task: $TASK"
    echo "Available tasks: all, dotfiles, keybindings, base, skills"
    exit 1
    ;;
esac
