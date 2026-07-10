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
  # Assuming 'log' is a custom function defined elsewhere in your script. 
  # If not, change this to 'echo'.
  log "Installing project dependencies"

  # 1. Install dependencies if bun is available and package.json exists
  if command -v bun >/dev/null 2>&1 && [ -f "package.json" ]; then
    bun install
  else
    echo "No package.json found or bun is not installed. Skipping."
  fi

  # 2. Execute the post-create logic directly in Bash
  if [ -d "./.devcontainer/.agents" ]; then 
    mkdir -p ./trash 
    mv ./.devcontainer/.agents ./trash/agents/
    rm -r ./.devcontainer/.agents
  fi
  
  # 3. Add trash directory to .gitignore if it isn't already there
  if ! grep -qxF "trash/" .gitignore; then
    echo "trash/" >> .gitignore
  fi
}

case "$TASK" in
  all)
    dotfiles
    keybindings
    base
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
  *)
    echo "Unknown setup task: $TASK"
    echo "Available tasks: all, dotfiles, keybindings, base"
    exit 1
    ;;
esac
