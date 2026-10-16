#!/usr/bin/env bash
# =============================================================================
#  lib/preflight.sh — Preflight System Checks & Environment Initialization
# =============================================================================

preflight() {
  step "Preflight checks"

  # ── 1. Xcode Command Line Tools (macOS only) ────────────────────────────
  if [[ "$OS" == "Darwin" ]]; then
    if xcode-select -p &>/dev/null; then
      ok "Xcode CLT already installed: $(xcode-select -p)"
    else
      warn "Xcode Command Line Tools not found — installing..."
      echo "  A dialog may appear — click 'Install' to continue."
      xcode-select --install 2>/dev/null || true
      echo -n "  Waiting for Xcode CLT"
      until xcode-select -p &>/dev/null; do
        echo -n "."
        sleep 5
      done
      echo ""
      ok "Xcode CLT installed"
    fi
  fi

  # ── 2. Homebrew (macOS only) ────────────────────────────────────────────
  if [[ "$OS" == "Darwin" ]]; then
    if command -v brew &>/dev/null; then
      ok "Homebrew found: $(brew --prefix)"
    else
      warn "Homebrew not found — installing..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        err "Homebrew install failed"; exit 1
      }
      [[ -f /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
      ok "Homebrew installed"
    fi
  fi

  # ── 3. zsh — install and set as default shell ───────────────────────────
  if ! command -v zsh &>/dev/null; then
    warn "zsh not found — installing..."
    case "$PKG_MGR" in
      apt)    sudo apt-get install -y zsh ;;
      dnf)    sudo dnf install -y zsh ;;
      yum)    sudo yum install -y zsh ;;
      pacman) sudo pacman -S --noconfirm zsh ;;
      zypper) sudo zypper install -y zsh ;;
    esac
    ok "zsh installed: $(zsh --version)"
  else
    ok "zsh found: $(zsh --version)"
  fi

  # Set zsh as default shell if it isn't already
  local zsh_path
  zsh_path=$(command -v zsh)
  if [[ "$SHELL" != "$zsh_path" ]]; then
    warn "Default shell is $SHELL — changing to zsh..."
    grep -qF "$zsh_path" /etc/shells || echo "$zsh_path" | sudo tee -a /etc/shells
    chsh -s "$zsh_path" || warn "chsh failed — run manually: chsh -s $zsh_path"
    ok "Default shell set to $zsh_path — takes effect on next login"
  else
    ok "Default shell is already zsh"
  fi

  # ── 4. Oh My Zsh ────────────────────────────────────────────────────────
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    ok "Oh My Zsh already installed"
  else
    warn "Oh My Zsh not found — installing..."
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || {
      err "Oh My Zsh install failed"; exit 1
    }
    ok "Oh My Zsh installed"
  fi

  # ── 5. Backup existing .zshrc ───────────────────────────────────────────
  if [[ -f "$HOME/.zshrc" ]]; then
    cp "$HOME/.zshrc" "$HOME/.zshrc.bak.$(date +%Y%m%d_%H%M%S)"
    ok "~/.zshrc backed up"
  fi

  # ── 6. Ensure ~/.ssh exists ─────────────────────────────────────────────
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  ok "~/.ssh ready"

  # ── 7. Prerequisites: Python3, pipx, and Go ─────────────────────────────
  if ! command -v pipx &>/dev/null; then
    log "Checking pipx..."
    pkg_install pipx python3-venv python3-pip
    pipx ensurepath 2>/dev/null || true
  fi

  if ! command -v go &>/dev/null; then
    install_golang
  fi

  export ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  export GOPATH="$HOME/go"
  export PATH="$HOME/.local/bin:$HOME/go/bin:$HOME/.npm-global/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"
}
