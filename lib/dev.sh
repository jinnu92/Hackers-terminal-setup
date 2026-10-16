#!/usr/bin/env bash
# =============================================================================
#  lib/dev.sh — Developer Stack: Node.js, Claude Code, and VS Code CLI
# =============================================================================

install_node() {
  step "Node.js & npm setup"
  local min_version=18
  local current_version=0

  if command -v node &>/dev/null; then
    current_version=$(node -v | sed 's/v//' | cut -d. -f1)
  fi

  if [[ "$current_version" -ge "$min_version" ]]; then
    ok "Node.js already installed: $(node -v) (npm $(npm -v 2>/dev/null || echo 'N/A'))"
  else
    log "Installing/upgrading Node.js LTS (>= v${min_version})..."
    case "$PKG_MGR" in
      brew)
        brew install node || warn "brew install node failed"
        ;;
      apt)
        log "Setting up NodeSource LTS repository for Debian/Ubuntu..."
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - 2>/dev/null || warn "NodeSource setup failed"
        sudo apt-get update -qq && sudo apt-get install -y nodejs || warn "apt install nodejs failed"
        ;;
      dnf)
        log "Setting up NodeSource LTS repository for Fedora..."
        curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash - 2>/dev/null || warn "NodeSource setup failed"
        sudo dnf install -y nodejs || warn "dnf install nodejs failed"
        ;;
      yum)
        curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash - 2>/dev/null || warn "NodeSource setup failed"
        sudo yum install -y nodejs || warn "yum install nodejs failed"
        ;;
      pacman)
        sudo pacman -S --noconfirm --needed nodejs npm || warn "pacman install nodejs failed"
        ;;
      zypper)
        sudo zypper install -y nodejs npm || warn "zypper install nodejs failed"
        ;;
    esac
  fi

  # Configure npm global directory without sudo
  if command -v npm &>/dev/null; then
    mkdir -p "$HOME/.npm-global"
    npm config set prefix "$HOME/.npm-global" 2>/dev/null || true
    export PATH="$HOME/.npm-global/bin:$PATH"
    ok "Configured npm global prefix to ~/.npm-global (no sudo required for global npm packages)"
  fi

  if command -v node &>/dev/null; then
    ok "Node.js: $(node -v) | npm: $(npm -v 2>/dev/null || echo 'N/A')"
  else
    warn "Node.js installation check failed"
  fi
}

install_claude() {
  step "Claude Code CLI (@anthropic-ai/claude-code)"

  if ! command -v node &>/dev/null; then
    log "Node.js is required for Claude Code. Installing Node.js..."
    install_node || { err "Node.js installation failed; cannot install Claude Code"; return 1; }
  fi

  mkdir -p "$HOME/.npm-global"
  npm config set prefix "$HOME/.npm-global" 2>/dev/null || true
  export PATH="$HOME/.npm-global/bin:$PATH"

  if command -v claude &>/dev/null; then
    info "Claude Code is already installed: $(claude --version 2>/dev/null || echo 'installed')"
    log "Checking for Claude Code updates..."
    npm install -g @anthropic-ai/claude-code || warn "Failed to update @anthropic-ai/claude-code"
  else
    log "Installing @anthropic-ai/claude-code via npm..."
    npm install -g @anthropic-ai/claude-code || warn "Failed to install @anthropic-ai/claude-code"
  fi

  if command -v claude &>/dev/null; then
    ok "Claude Code installed: $(claude --version 2>/dev/null || echo 'ready')"
    info "Run Claude Code with: ${BOLD}claude${RESET} (or shortcut ${BOLD}cc${RESET})"
    info "Authentication: set ${BOLD}export ANTHROPIC_API_KEY='your-key'${RESET} or run ${BOLD}claude${RESET} to log in"
  else
    warn "Claude Code installed, but 'claude' command not found in PATH yet. Ensure ~/.npm-global/bin is in PATH."
  fi
}

install_code() {
  step "Visual Studio Code & 'code' CLI"

  if command -v code &>/dev/null; then
    ok "VS Code ('code' CLI) is already installed: $(code --version 2>/dev/null | head -1)"
    return 0
  fi

  case "$OS" in
    Darwin)
      if [[ -d "/Applications/Visual Studio Code.app" ]]; then
        info "Visual Studio Code.app detected in /Applications — linking 'code' CLI..."
        mkdir -p "$HOME/.local/bin"
        ln -sf "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" "$HOME/.local/bin/code"
        export PATH="$HOME/.local/bin:$PATH"
      else
        log "Installing Visual Studio Code via Homebrew Cask..."
        pkg_install_cask visual-studio-code
        if [[ -d "/Applications/Visual Studio Code.app" ]] && ! command -v code &>/dev/null; then
          mkdir -p "$HOME/.local/bin"
          ln -sf "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" "$HOME/.local/bin/code"
          export PATH="$HOME/.local/bin:$PATH"
        fi
      fi
      ;;
    Linux)
      case "$PKG_MGR" in
        apt)
          log "Installing Visual Studio Code via Microsoft APT repository..."
          sudo apt-get install -y wget gpg apt-transport-https 2>/dev/null || true
          local key_url="https://packages.microsoft.com/keys/microsoft.asc"
          local gpg_file="/tmp/packages.microsoft.gpg"
          curl -fsSL "$key_url" | gpg --dearmor -o "$gpg_file" 2>/dev/null || true
          if [[ -f "$gpg_file" ]]; then
            sudo install -D -o root -g root -m 644 "$gpg_file" /etc/apt/keyrings/packages.microsoft.gpg 2>/dev/null || true
            sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
            rm -f "$gpg_file"
            sudo apt-get update -qq && sudo apt-get install -y code || warn "apt install code failed"
          else
            warn "Could not download Microsoft GPG key for VS Code"
          fi
          ;;
        dnf|yum)
          log "Installing Visual Studio Code via Microsoft RPM repository..."
          sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>/dev/null || true
          sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
          if [[ "$PKG_MGR" == "dnf" ]]; then
            sudo dnf check-update -q || true
            sudo dnf install -y code || warn "dnf install code failed"
          else
            sudo yum check-update -q || true
            sudo yum install -y code || warn "yum install code failed"
          fi
          ;;
        pacman)
          sudo pacman -S --noconfirm --needed code || warn "pacman install code failed"
          ;;
        zypper)
          sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>/dev/null || true
          sudo zypper addrepo https://packages.microsoft.com/yumrepos/vscode vscode 2>/dev/null || true
          sudo zypper refresh -q && sudo zypper install -y code || warn "zypper install code failed"
          ;;
      esac
      ;;
  esac

  if command -v code &>/dev/null; then
    ok "Visual Studio Code ready: $(code --version 2>/dev/null | head -1)"
  else
    warn "VS Code installed, but 'code' binary not yet in PATH. Restart your shell."
  fi
}

install_dev() {
  step "Developer & Agentic AI Stack (Node.js + Claude Code + VS Code)"
  install_node
  install_claude
  install_code
  ok "Developer & Agentic AI stack complete"
}
