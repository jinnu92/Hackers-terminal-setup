#!/usr/bin/env bash
# =============================================================================
#  lib/workflow.sh — Workflow, Productivity, and Core Shell Tools
# =============================================================================

install_core() {
  step "Core terminal tools"
  pkg_update

  # QoL tools
  for pkg in fzf bat eza zoxide git-delta tmux fd ripgrep tldr; do
    pkg_install "$pkg"
  done

  # Linux: install go-based tools that aren't in distro repos
  if [[ "$OS" == "Linux" ]]; then
    go_install "github.com/jesseduffield/lazygit@latest" lazygit
  fi

  linux_fixups

  # Ensure Meslo Nerd Font is installed (required for Powerlevel10k)
  install_fonts "meslo"

  # External OMZ plugins
  _clone_plugin() {
    local name=$1 url=$2
    local dest="$ZSH_CUSTOM/plugins/$name"
    if [[ -d "$dest" ]]; then
      info "Plugin '$name' exists — updating"
      git -C "$dest" pull --ff-only -q 2>/dev/null || true
    else
      log "Cloning $name..."
      git clone --depth=1 "$url" "$dest"
    fi
  }
  _clone_plugin zsh-autosuggestions     https://github.com/zsh-users/zsh-autosuggestions
  _clone_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting
  _clone_plugin zsh-completions         https://github.com/zsh-users/zsh-completions

  # Powerlevel10k
  local p10k_dir="$ZSH_CUSTOM/themes/powerlevel10k"
  if [[ -d "$p10k_dir" ]]; then
    info "Powerlevel10k exists — updating"
    git -C "$p10k_dir" pull --ff-only -q 2>/dev/null || true
  else
    log "Cloning Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
  fi

  ok "Core terminal done"
}

install_workflow() {
  step "Workflow tools"

  for pkg in jq gh pandoc; do
    pkg_install "$pkg"
  done

  # yq — YAML processor
  if ! command -v yq &>/dev/null; then
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install yq
    else
      local yq_ver="v4.44.1"
      local yq_bin="yq_linux_amd64"
      [[ "$ARCH" == "aarch64" ]] && yq_bin="yq_linux_arm64"
      curl -fsSL "https://github.com/mikefarah/yq/releases/download/${yq_ver}/${yq_bin}" \
        -o "$HOME/.local/bin/yq" && chmod +x "$HOME/.local/bin/yq"
      ok "yq installed"
    fi
  else
    info "yq already installed"
  fi

  # lazygit
  if ! command -v lazygit &>/dev/null; then
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install lazygit
    else
      go_install "github.com/jesseduffield/lazygit@latest" lazygit
    fi
  fi

  # xh — fast HTTP client
  if ! command -v xh &>/dev/null; then
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install xh
    else
      curl -fsSL https://raw.githubusercontent.com/ducaale/xh/master/install.sh | bash || \
        warn "xh install failed — install via cargo: cargo install xh"
    fi
  fi

  # yazi — terminal file manager
  if ! command -v yazi &>/dev/null; then
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install yazi
    else
      warn "yazi: install via cargo: cargo install yazi-fm"
    fi
  fi

  # obsidian — note-taking
  if [[ "$OS" == "Darwin" ]]; then
    pkg_install_cask obsidian
  else
    warn "Obsidian: download AppImage from obsidian.md/download"
  fi

  # git-delta global config (runs once)
  if command -v delta &>/dev/null; then
    git config --global core.pager delta
    git config --global interactive.diffFilter "delta --color-only"
    git config --global delta.navigate true
    git config --global delta.side-by-side true
    git config --global delta.line-numbers true
    ok "git-delta configured in ~/.gitconfig"
  fi

  ok "Workflow tools done"
}
