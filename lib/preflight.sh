#!/usr/bin/env bash
# =============================================================================
#  lib/preflight.sh — Base Preflight + On-Demand Prerequisites
#
#  preflight_base   always runs for a real install (OS, state, package manager,
#                   ~/.local/bin, disk check, .zshrc backup)
#  ensure_zsh / ensure_omz / ensure_pipx / ensure_go / ensure_ssh_dir
#                   run only when a selected component needs them (see
#                   prereqs_for_component in menu.sh). All are idempotent.
#  preflight        legacy: base + every prerequisite (used for --all)
# =============================================================================

HTS_XCODE_TIMEOUT="${HTS_XCODE_TIMEOUT:-1800}"   # seconds to wait for Xcode CLT
HTS_MIN_DISK_MB="${HTS_MIN_DISK_MB:-5120}"       # warn below this much free space

hts_export_paths() {
  export ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  export GOPATH="$HOME/go"
  export PATH="$HOME/.local/bin:$HOME/go/bin:$HOME/.npm-global/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"
}

hts_check_disk_space() {
  local avail_kb avail_mb
  avail_kb="$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')"
  if [[ -z "$avail_kb" || ! "$avail_kb" =~ ^[0-9]+$ ]]; then
    warn "Could not determine free disk space — skipping check"
    return 0
  fi
  avail_mb=$((avail_kb / 1024))
  if [[ "$avail_mb" -lt "$HTS_MIN_DISK_MB" ]]; then
    warn "Only ${avail_mb} MB free on the volume holding \$HOME (a full install wants about ${HTS_MIN_DISK_MB} MB) — continuing anyway"
  else
    ok "Disk space: ${avail_mb} MB free"
  fi
  return 0
}

# Minimal base step. Returns non-zero only when the system cannot install anything.
preflight_base() {
  step "Preflight checks (base)"
  hts_state_init || { err "Cannot create state directory $HTS_STATE_DIR"; return 1; }

  # ── Xcode Command Line Tools (macOS) ────────────────────────────────────
  if [[ "$OS" == "Darwin" ]]; then
    if xcode-select -p &>/dev/null; then
      ok "Xcode CLT already installed: $(xcode-select -p)"
    else
      warn "Xcode Command Line Tools not found — installing..."
      echo "  A dialog may appear — click 'Install' to continue."
      xcode-select --install 2>/dev/null || true
      echo -n "  Waiting for Xcode CLT"
      local waited=0
      until xcode-select -p &>/dev/null; do
        if [[ "$waited" -ge "$HTS_XCODE_TIMEOUT" ]]; then
          echo ""
          err "Timed out after ${HTS_XCODE_TIMEOUT}s waiting for Xcode Command Line Tools."
          err "Finish the install dialog (or run: xcode-select --install) and re-run this script."
          return 1
        fi
        echo -n "."
        sleep 5
        waited=$((waited + 5))
      done
      echo ""
      ok "Xcode CLT installed"
    fi

    # ── Homebrew ──────────────────────────────────────────────────────────
    [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
    [[ -x /usr/local/bin/brew && -z "$(command -v brew)" ]] && eval "$(/usr/local/bin/brew shellenv)"
    if command -v brew &>/dev/null; then
      ok "Homebrew found: $(brew --prefix)"
    else
      warn "Homebrew not found — installing..."
      if ! hts_run_remote_script "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" /bin/bash; then
        err "Homebrew install failed"
        return 1
      fi
      [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
      [[ -x /usr/local/bin/brew ]] && eval "$(/usr/local/bin/brew shellenv)"
      command -v brew &>/dev/null || { err "Homebrew installed but 'brew' not found in PATH"; return 1; }
      ok "Homebrew installed"
    fi
  else
    ok "Package manager: $PKG_MGR"
  fi

  mkdir -p "$HOME/.local/bin"
  hts_export_paths
  hts_check_disk_space

  # Back up the user's own ~/.zshrc before anything (e.g. Oh My Zsh) touches it
  backup_file "$HOME/.zshrc"
  return 0
}

# ── Prerequisites (on demand) ────────────────────────────────────────────────

ensure_zsh() {
  [[ "${_HTS_DID_ZSH:-0}" == "1" ]] && return 0
  if ! command -v zsh &>/dev/null; then
    warn "zsh not found — installing..."
    case "$PKG_MGR" in
      brew)   brew install zsh ;;
      apt)    sudo apt-get install -y zsh ;;
      dnf)    sudo dnf install -y zsh ;;
      yum)    sudo yum install -y zsh ;;
      pacman) sudo pacman -S --noconfirm zsh ;;
      zypper) sudo zypper install -y zsh ;;
    esac
    command -v zsh &>/dev/null || { err "zsh install failed"; return 1; }
    ok "zsh installed: $(zsh --version)"
  else
    ok "zsh found: $(zsh --version)"
  fi

  local zsh_path
  zsh_path=$(command -v zsh)
  if [[ "${SHELL:-}" != "$zsh_path" ]]; then
    warn "Default shell is ${SHELL:-unknown} — changing to zsh..."
    grep -qF "$zsh_path" /etc/shells || echo "$zsh_path" | sudo tee -a /etc/shells
    chsh -s "$zsh_path" || warn "chsh failed — run manually: chsh -s $zsh_path"
    ok "Default shell set to $zsh_path — takes effect on next login"
  else
    ok "Default shell is already zsh"
  fi
  _HTS_DID_ZSH=1
  return 0
}

ensure_omz() {
  [[ "${_HTS_DID_OMZ:-0}" == "1" ]] && return 0
  ensure_zsh || return 1
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    ok "Oh My Zsh already installed"
  else
    warn "Oh My Zsh not found — installing..."
    # Preserve the user's own .zshrc before the OMZ installer swaps in its template
    backup_file "$HOME/.zshrc"
    if ! hts_run_remote_script "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh" "env RUNZSH=no CHSH=no sh"; then
      err "Oh My Zsh install failed"
      return 1
    fi
    ok "Oh My Zsh installed"
  fi
  export ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  _HTS_DID_OMZ=1
  return 0
}

ensure_pipx() {
  [[ "${_HTS_DID_PIPX:-0}" == "1" ]] && return 0
  if ! command -v pipx &>/dev/null; then
    log "Checking pipx..."
    pkg_install pipx python3-venv python3-pip
    pipx ensurepath 2>/dev/null || true
  fi
  export PATH="$HOME/.local/bin:$PATH"
  if command -v pipx &>/dev/null; then
    ok "pipx ready"
    _HTS_DID_PIPX=1
    return 0
  fi
  err "pipx not available after install attempt"
  return 1
}

ensure_go() {
  [[ "${_HTS_DID_GO:-0}" == "1" ]] && return 0
  if ! command -v go &>/dev/null; then
    install_golang
  fi
  export GOPATH="$HOME/go"
  export PATH="$HOME/go/bin:$PATH"
  if command -v go &>/dev/null; then
    _HTS_DID_GO=1
    return 0
  fi
  err "Go not available after install attempt"
  return 1
}

ensure_ssh_dir() {
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  ok "~/.ssh ready"
}

# Legacy full preflight: base plus every prerequisite.
preflight() {
  preflight_base || return 1
  ensure_omz
  ensure_ssh_dir
  ensure_pipx
  ensure_go
  hts_export_paths
}
