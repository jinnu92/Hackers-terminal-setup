#!/usr/bin/env bash
# =============================================================================
#  lib/helpers.sh — Language and Package Runtimes (Go, Python, Node Prefix)
# =============================================================================

install_golang() {
  if command -v go &>/dev/null; then
    ok "Go already installed: $(go version)"
  else
    log "Installing Go programming language..."
    case "$PKG_MGR" in
      brew)   brew install go || warn "brew install go failed" ;;
      apt)    sudo apt-get install -y golang-go || warn "apt install golang-go failed" ;;
      dnf)    sudo dnf install -y golang || warn "dnf install golang failed" ;;
      yum)    sudo yum install -y golang || warn "yum install golang failed" ;;
      pacman) sudo pacman -S --noconfirm --needed go || warn "pacman install go failed" ;;
      zypper) sudo zypper install -y go || warn "zypper install go failed" ;;
    esac
  fi
  export GOPATH="$HOME/go"
  export PATH="$HOME/go/bin:$PATH"
}

pipx_install() {
  local pkg=$1
  export PATH="$HOME/.local/bin:$PATH"
  if pipx list 2>/dev/null | grep -q "^  $pkg"; then
    info "$pkg already installed via pipx"
  else
    log "Installing $pkg via pipx..."
    pipx install "$pkg" || warn "pipx install $pkg failed"
  fi
}

npm_global_install() {
  local pkg=$1
  mkdir -p "$HOME/.npm-global"
  npm config set prefix "$HOME/.npm-global" 2>/dev/null || true
  export PATH="$HOME/.npm-global/bin:$PATH"
  if npm list -g "$pkg" &>/dev/null 2>&1; then
    info "$pkg already installed via npm"
  else
    log "Installing $pkg via npm..."
    npm install -g "$pkg" || warn "npm install -g $pkg failed"
  fi
}

go_install() {
  local pkg=$1   # full go import path e.g. github.com/foo/bar@latest
  local name=$2  # binary name to check
  export GOPATH="$HOME/go"
  export PATH="$HOME/go/bin:$PATH"
  if command -v "$name" &>/dev/null; then
    info "$name already installed"
  else
    if ! command -v go &>/dev/null; then
      install_golang
    fi
    if command -v go &>/dev/null; then
      log "go install $pkg..."
      go install "$pkg" || warn "go install $pkg failed"
    else
      warn "go not found — cannot install $name. Install go first."
    fi
  fi
}
