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
    if pipx install "$pkg"; then
      hts_manifest_add tool "$pkg" "pipx"
    else
      warn "pipx install $pkg failed"
      return 1
    fi
  fi
  return 0
}

# hts_node_managed — succeeds (and prints the manager name) when nvm, fnm or Volta
# is managing Node, in which case the npm global prefix must not be overridden.
hts_node_managed() {
  local node_path=""
  node_path="$(command -v node 2>/dev/null || true)"
  case "$node_path" in
    */.nvm/*|*/nvm/*)       echo "nvm";   return 0 ;;
    */fnm/*|*/.fnm/*|*/fnm_multishells/*) echo "fnm"; return 0 ;;
    */.volta/*|*/volta/*)   echo "Volta"; return 0 ;;
  esac
  if [[ -n "${NVM_BIN:-}" ]]; then echo "nvm"; return 0; fi
  if [[ -n "${FNM_MULTISHELL_PATH:-}" ]]; then echo "fnm"; return 0; fi
  if [[ -n "${VOLTA_HOME:-}" && -d "${VOLTA_HOME}" && -n "$node_path" ]]; then echo "Volta"; return 0; fi
  return 1
}

npm_global_install() {
  local pkg=$1 mgr=""
  if mgr="$(hts_node_managed)"; then
    warn "Node is managed by $mgr — not overriding the npm global prefix"
  else
    mkdir -p "$HOME/.npm-global"
    npm config set prefix "$HOME/.npm-global" 2>/dev/null || true
    export PATH="$HOME/.npm-global/bin:$PATH"
  fi
  if npm list -g "$pkg" &>/dev/null 2>&1; then
    info "$pkg already installed via npm"
  else
    log "Installing $pkg via npm..."
    if npm install -g "$pkg"; then
      hts_manifest_add tool "$pkg" "npm"
    else
      warn "npm install -g $pkg failed"
      return 1
    fi
  fi
  return 0
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
      if go install "$pkg"; then
        # detail records the module path so --update can run "go install <path>@latest"
        hts_manifest_add tool "$name" "go:${pkg%@*}"
      else
        warn "go install $pkg failed"
        return 1
      fi
    else
      warn "go not found — cannot install $name. Install go first."
      return 1
    fi
  fi
  return 0
}
