#!/usr/bin/env bash
# =============================================================================
#  lib/workflow.sh — Workflow, Productivity, and Core Shell Tools
# =============================================================================

# _clone_repo <label> <url> <dest> — clone, or fast-forward an existing clone.
# A network failure is reported and returned, never fatal to the run.
_clone_repo() {
  local name=$1 url=$2 dest=$3
  if ! command -v git &>/dev/null; then
    warn "git not found — cannot fetch $name"
    return 1
  fi
  if [[ -d "$dest/.git" || -d "$dest" ]]; then
    info "'$name' exists — updating"
    git -C "$dest" pull --ff-only -q 2>/dev/null || warn "Could not update $name (offline or diverged); keeping current copy"
    return 0
  fi
  log "Cloning $name..."
  mkdir -p "$(dirname "$dest")" || return 1
  if git clone --depth=1 "$url" "$dest"; then
    hts_track_file "$dest"
    hts_manifest_add component "$name" "$url"
    return 0
  fi
  rm -rf "$dest"
  warn "Failed to clone $name from $url"
  return 1
}

# _install_lazygit — package manager first, then pinned release binary, then go.
_install_lazygit() {
  command -v lazygit &>/dev/null && return 0
  local arch sha tmpdir rc=1
  export PATH="$HOME/.local/bin:$HOME/go/bin:$PATH"

  if pkg_install lazygit && command -v lazygit &>/dev/null; then
    return 0
  fi

  if [[ "$OS" == "Linux" ]] && arch="$(uname -m)"; then
    case "$arch" in
      x86_64|amd64)  arch="x86_64"; sha="$LAZYGIT_SHA256_LINUX_AMD64" ;;
      aarch64|arm64) arch="arm64";  sha="$LAZYGIT_SHA256_LINUX_ARM64" ;;
      *)             arch="";       sha="" ;;
    esac
    if [[ -n "$arch" ]]; then
      log "Installing lazygit v${LAZYGIT_VERSION} release binary..."
      tmpdir="$(mktemp -d)" || return 1
      if hts_download_verify "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_linux_${arch}.tar.gz" "$sha" "$tmpdir/lazygit.tar.gz" \
         && tar -xzf "$tmpdir/lazygit.tar.gz" -C "$tmpdir" lazygit \
         && mkdir -p "$HOME/.local/bin" \
         && install -m 755 "$tmpdir/lazygit" "$HOME/.local/bin/lazygit"; then
        hts_track_file "$HOME/.local/bin/lazygit"
        hts_manifest_add tool lazygit "v${LAZYGIT_VERSION}"
        rc=0
      else
        warn "lazygit release binary install failed — falling back to go install"
      fi
      rm -rf "$tmpdir"
      [[ $rc -eq 0 ]] && return 0
    fi
  fi

  go_install "github.com/jesseduffield/lazygit@v${LAZYGIT_VERSION}" lazygit
  command -v lazygit &>/dev/null
}

# _install_yq — pinned, digest-verified release binary on Linux.
_install_yq() {
  command -v yq &>/dev/null && return 0
  if [[ "$OS" == "Darwin" ]]; then
    pkg_install yq
    return $?
  fi
  local arch sha
  arch="$(_hts_arch)" || { warn "yq: unsupported architecture $(uname -m)"; return 1; }
  if [[ "$arch" == "amd64" ]]; then sha="$YQ_SHA256_LINUX_AMD64"; else sha="$YQ_SHA256_LINUX_ARM64"; fi
  log "Installing yq ${YQ_VERSION}..."
  if _install_release_bin yq \
       "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${arch}" "$sha"; then
    ok "yq ${YQ_VERSION} installed"
    return 0
  fi
  warn "yq install failed"
  return 1
}

# _install_xh — package on macOS; pinned musl release tarball on Linux.
_install_xh() {
  command -v xh &>/dev/null && return 0
  if [[ "$OS" == "Darwin" ]]; then
    pkg_install xh
    return $?
  fi
  local arch sha target tmpdir rc=1
  arch="$(_hts_arch)" || { warn "xh: unsupported architecture $(uname -m)"; return 1; }
  if [[ "$arch" == "amd64" ]]; then
    target="x86_64-unknown-linux-musl"; sha="$XH_SHA256_LINUX_AMD64"
  else
    target="aarch64-unknown-linux-musl"; sha="$XH_SHA256_LINUX_ARM64"
  fi
  log "Installing xh ${XH_VERSION}..."
  tmpdir="$(mktemp -d)" || return 1
  if hts_download_verify "https://github.com/ducaale/xh/releases/download/${XH_VERSION}/xh-${XH_VERSION}-${target}.tar.gz" "$sha" "$tmpdir/xh.tar.gz" \
     && tar -xzf "$tmpdir/xh.tar.gz" -C "$tmpdir" \
     && mkdir -p "$HOME/.local/bin" \
     && install -m 755 "$tmpdir/xh-${XH_VERSION}-${target}/xh" "$HOME/.local/bin/xh"; then
    hts_track_file "$HOME/.local/bin/xh"
    hts_manifest_add tool xh "$XH_VERSION"
    rc=0
  else
    warn "xh install failed — install via cargo: cargo install xh"
  fi
  rm -rf "$tmpdir"
  return $rc
}

install_core() {
  step "Core terminal tools"
  local rc=0 pkg prc
  export PATH="$HOME/.local/bin:$PATH"
  pkg_update

  # QoL tools. Unmapped packages (status 3) were already warned about.
  for pkg in fzf bat eza zoxide git-delta tmux fd ripgrep tldr; do
    prc=0
    pkg_install "$pkg" || prc=$?
    [[ $prc -eq 1 ]] && rc=1
  done

  # lazygit: package manager, pinned release binary, then go install
  _install_lazygit || rc=1

  linux_fixups

  # Ensure Meslo Nerd Font is installed (required for Powerlevel10k)
  install_fonts "meslo" || warn "Nerd Font install had problems"

  # External OMZ plugins
  local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  _clone_repo zsh-autosuggestions     https://github.com/zsh-users/zsh-autosuggestions     "$zsh_custom/plugins/zsh-autosuggestions" || rc=1
  _clone_repo zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting "$zsh_custom/plugins/zsh-syntax-highlighting" || rc=1
  _clone_repo zsh-completions         https://github.com/zsh-users/zsh-completions         "$zsh_custom/plugins/zsh-completions" || rc=1

  # Powerlevel10k
  _clone_repo powerlevel10k https://github.com/romkatv/powerlevel10k.git "$zsh_custom/themes/powerlevel10k" || rc=1

  # Verify what this step is supposed to provide
  local b
  for b in fzf bat eza zoxide delta tmux fd rg lazygit; do
    hts_verify_cmd "core: $b" "$b" || rc=1
  done

  if [[ $rc -eq 0 ]]; then
    ok "Core terminal done"
  else
    warn "Core terminal finished with errors (see warnings above)"
  fi
  return $rc
}

install_workflow() {
  step "Workflow tools"
  local rc=0 pkg prc
  export PATH="$HOME/.local/bin:$HOME/go/bin:$PATH"

  for pkg in jq gh pandoc; do
    prc=0
    pkg_install "$pkg" || prc=$?
    [[ $prc -eq 1 ]] && rc=1
  done

  _install_yq || rc=1
  _install_lazygit || rc=1
  _install_xh || rc=1

  # yazi — terminal file manager
  if ! command -v yazi &>/dev/null; then
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install yazi || rc=1
    elif pkg_install yazi 2>/dev/null; then
      :
    else
      warn "yazi: install via cargo: cargo install yazi-fm"
    fi
  fi

  # obsidian — note-taking
  if [[ "$OS" == "Darwin" ]]; then
    pkg_install_cask obsidian || rc=1
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

  local b
  for b in jq gh pandoc yq lazygit xh; do
    hts_verify_cmd "workflow: $b" "$b" || rc=1
  done

  if [[ $rc -eq 0 ]]; then
    ok "Workflow tools done"
  else
    warn "Workflow tools finished with errors (see warnings above)"
  fi
  return $rc
}
