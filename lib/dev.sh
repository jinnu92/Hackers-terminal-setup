#!/usr/bin/env bash
# =============================================================================
#  lib/dev.sh — Developer Stack: Node.js, Claude Code, and VS Code CLI
# =============================================================================

install_node() {
  step "Node.js & npm setup"
  local min_version="${NODE_MIN_MAJOR:-22}"
  local current_version=0

  if command -v node &>/dev/null; then
    current_version=$(node -v | sed 's/v//' | cut -d. -f1)
  fi

  if [[ "$current_version" -ge "$min_version" ]]; then
    ok "Node.js already installed: $(node -v) (npm $(npm -v 2>/dev/null || echo 'N/A'))"
  else
    log "Installing/upgrading Node.js LTS (>= v${min_version})..."
    local interp=""
    case "$PKG_MGR" in
      brew)
        if [[ "$current_version" -gt 0 ]] && brew list node &>/dev/null; then
          # pkg_install would skip a formula that is "already installed"
          brew upgrade node || warn "brew upgrade node failed"
        else
          pkg_install node || warn "brew install node failed"
        fi
        ;;
      apt)
        log "Setting up NodeSource LTS repository for Debian/Ubuntu..."
        interp="$(_sudo_interp)" && \
          hts_run_remote_script "https://deb.nodesource.com/setup_lts.x" "$interp" || warn "NodeSource setup failed"
        _sudo apt-get update -qq && _sudo apt-get install -y nodejs || warn "apt install nodejs failed"
        ;;
      dnf|yum)
        log "Setting up NodeSource LTS repository for $PKG_MGR..."
        interp="$(_sudo_interp)" && \
          hts_run_remote_script "https://rpm.nodesource.com/setup_lts.x" "$interp" || warn "NodeSource setup failed"
        _sudo "$PKG_MGR" install -y nodejs || warn "$PKG_MGR install nodejs failed"
        ;;
      pacman)
        pkg_install nodejs npm || warn "pacman install nodejs failed"
        ;;
      zypper)
        pkg_install nodejs npm || warn "zypper install nodejs failed"
        ;;
    esac
    hash -r 2>/dev/null || true
    if command -v node &>/dev/null; then
      current_version=$(node -v | sed 's/v//' | cut -d. -f1)
      [[ "$current_version" -ge "$min_version" ]] || \
        warn "Node.js $(node -v) on PATH is still below v${min_version} (another install or version manager may shadow it)"
    fi
  fi

  # Configure npm global directory without sudo
  if command -v npm &>/dev/null; then
    _set_npm_prefix
  fi

  hts_verify_cmd "Node.js" node || { warn "Node.js installation check failed"; return 1; }
  hts_verify_cmd "npm" npm || true
  ok "Node.js: $(node -v) | npm: $(npm -v 2>/dev/null || echo 'N/A')"
  return 0
}

# _set_npm_prefix — point the npm global prefix at ~/.npm-global unless a Node
# version manager (nvm/fnm/Volta) owns it, in which case changing it breaks them.
_set_npm_prefix() {
  local mgr=""
  if mgr="$(hts_node_managed)"; then
    warn "Node is managed by $mgr — leaving the npm global prefix unchanged (an override would break $mgr's global packages)"
    return 0
  fi
  mkdir -p "$HOME/.npm-global"
  npm config set prefix "$HOME/.npm-global" 2>/dev/null || true
  export PATH="$HOME/.npm-global/bin:$PATH"
  ok "Configured npm global prefix to ~/.npm-global (no sudo required for global npm packages)"
}

install_claude() {
  step "Claude Code CLI (native installer)"

  # Anthropic's documented install method is the native installer, which puts a
  # self-updating binary in ~/.local/bin and needs neither Node.js nor sudo.
  # (The npm package @anthropic-ai/claude-code still exists but needs Node 22+.)
  if command -v claude &>/dev/null; then
    ok "Claude Code is already installed: $(claude --version 2>/dev/null || echo 'installed')"
    info "Left as is. The native build updates itself; an npm install can be moved over with: ${BOLD}claude install${RESET}"
    hts_verify_cmd "Claude Code CLI" claude
    return 0
  fi

  log "Installing Claude Code with the official native installer (stable channel)..."
  if hts_run_remote_script "https://claude.ai/install.sh" bash stable; then
    hts_manifest_add tool "claude-code" "native"
  else
    warn "Claude Code native installer failed"
  fi

  # The installer targets ~/.local/bin, which may not be on PATH in this shell yet
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
  esac

  if hts_verify_cmd "Claude Code CLI" claude; then
    ok "Claude Code installed: $(claude --version 2>/dev/null || echo 'ready')"
    info "Run Claude Code with: ${BOLD}claude${RESET} (or shortcut ${BOLD}ccode${RESET})"
    info "Authentication: run ${BOLD}claude${RESET} to log in, or set ${BOLD}export ANTHROPIC_API_KEY='your-key'${RESET}"
    return 0
  fi
  warn "Claude Code was not found after install. Ensure ~/.local/bin is in PATH and re-run: ./ter.sh --claude"
  return 1
}

install_code() {
  step "Visual Studio Code & 'code' CLI"

  if command -v code &>/dev/null; then
    ok "VS Code ('code' CLI) is already installed: $(code --version 2>/dev/null | head -1)"
    hts_verify_cmd "VS Code CLI" code
    return 0
  fi

  case "$OS" in
    Darwin)
      if [[ -d "/Applications/Visual Studio Code.app" ]]; then
        info "Visual Studio Code.app detected in /Applications — linking 'code' CLI..."
        mkdir -p "$HOME/.local/bin"
        ln -sf "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" "$HOME/.local/bin/code"
        hts_track_file "$HOME/.local/bin/code"
        export PATH="$HOME/.local/bin:$PATH"
      else
        log "Installing Visual Studio Code via Homebrew Cask..."
        pkg_install_cask visual-studio-code
        if [[ -d "/Applications/Visual Studio Code.app" ]] && ! command -v code &>/dev/null; then
          mkdir -p "$HOME/.local/bin"
          ln -sf "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" "$HOME/.local/bin/code"
          hts_track_file "$HOME/.local/bin/code"
        hts_track_file "$HOME/.local/bin/code"
          export PATH="$HOME/.local/bin:$PATH"
        fi
      fi
      ;;
    Linux)
      case "$PKG_MGR" in
        apt)
          log "Installing Visual Studio Code via Microsoft APT repository..."
          pkg_install wget gpg apt-transport-https || true
          local key_url="https://packages.microsoft.com/keys/microsoft.asc"
          local key_tmp gpg_file
          key_tmp="$(mktemp)"; gpg_file="$(mktemp -u)"
          if hts_fetch "$key_url" "$key_tmp" && gpg --dearmor -o "$gpg_file" < "$key_tmp" 2>/dev/null && [[ -s "$gpg_file" ]]; then
            _sudo install -D -o root -g root -m 644 "$gpg_file" /etc/apt/keyrings/packages.microsoft.gpg || true
            echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
              | _sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
            hts_track_file /etc/apt/sources.list.d/vscode.list
            _HTS_PKG_REFRESHED=0
            _sudo apt-get update -qq && _sudo apt-get install -y code || warn "apt install code failed"
          else
            warn "Could not download Microsoft GPG key for VS Code"
          fi
          rm -f "$key_tmp" "$gpg_file"
          ;;
        dnf|yum)
          log "Installing Visual Studio Code via Microsoft RPM repository..."
          _sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>/dev/null || true
          printf '[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n' \
            | _sudo tee /etc/yum.repos.d/vscode.repo >/dev/null
          hts_track_file /etc/yum.repos.d/vscode.repo
          _sudo "$PKG_MGR" install -y code || warn "$PKG_MGR install code failed"
          ;;
        pacman)
          pkg_install code || warn "pacman install code failed"
          ;;
        zypper)
          _sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>/dev/null || true
          _sudo zypper --non-interactive addrepo https://packages.microsoft.com/yumrepos/vscode vscode 2>/dev/null || true
          _sudo zypper --non-interactive refresh -q && _sudo zypper --non-interactive install -y code || warn "zypper install code failed"
          ;;
      esac
      ;;
  esac

  if command -v code &>/dev/null; then
    ok "Visual Studio Code ready: $(code --version 2>/dev/null | head -1)"
    hts_verify_cmd "VS Code CLI" code
  else
    warn "VS Code installed, but 'code' binary not yet in PATH. Restart your shell."
    hts_verify_cmd "VS Code CLI" code
    return 1
  fi
}

install_dev() {
  step "Developer & Agentic AI Stack (Node.js + Claude Code + VS Code)"
  local rc=0
  install_node || rc=1
  install_claude || rc=1
  install_code || rc=1
  if [[ $rc -eq 0 ]]; then
    ok "Developer & Agentic AI stack complete"
  else
    warn "Developer & Agentic AI stack finished with errors"
  fi
  return $rc
}
