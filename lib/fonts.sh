#!/usr/bin/env bash
# =============================================================================
#  lib/fonts.sh — Hacker & Developer Nerd Fonts Installer
# =============================================================================

install_fonts() {
  local target_font="${1:-all}"
  step "Hacker & Developer Nerd Fonts ($target_font)"

  if [[ "$OS" == "Darwin" ]]; then
    log "Installing Nerd Fonts on macOS..."
    pkg_install_cask "font-meslo-lg-nerd-font"

    if [[ "$target_font" == "all" || "$target_font" == *"jetbrains"* ]]; then
      pkg_install_cask "font-jetbrains-mono-nerd-font"
    fi
    if [[ "$target_font" == "all" || "$target_font" == *"fira"* ]]; then
      pkg_install_cask "font-fira-code-nerd-font"
    fi
    if [[ "$target_font" == "all" || "$target_font" == *"hack"* ]]; then
      pkg_install_cask "font-hack-nerd-font"
    fi
    if [[ "$target_font" == "all" || "$target_font" == *"cascadia"* ]]; then
      pkg_install_cask "font-caskaydia-cove-nerd-font"
    fi

    # Fallback: copy romkatv MesloLGS NF TTFs directly to ~/Library/Fonts
    local mac_font_dir="$HOME/Library/Fonts"
    mkdir -p "$mac_font_dir"
    if [[ ! -f "$mac_font_dir/MesloLGS NF Regular.ttf" ]]; then
      log "Ensuring MesloLGS NF TTFs in ~/Library/Fonts..."
      local base="https://github.com/romkatv/powerlevel10k-media/raw/master"
      for f in "MesloLGS NF Regular.ttf" "MesloLGS NF Bold.ttf" \
                "MesloLGS NF Italic.ttf" "MesloLGS NF Bold Italic.ttf"; do
        curl -fsSL "$base/${f// /%20}" -o "$mac_font_dir/$f" 2>/dev/null || true
      done
    fi
    ok "macOS Nerd Fonts installed"
  else
    # Linux installation into ~/.local/share/fonts/NerdFonts
    local font_dir="$HOME/.local/share/fonts/NerdFonts"
    mkdir -p "$font_dir"

    if ! command -v fc-cache &>/dev/null; then
      pkg_install fontconfig
    fi

    # 1. MesloLGS NF (P10k recommended)
    log "Downloading MesloLGS NF..."
    local base="https://github.com/romkatv/powerlevel10k-media/raw/master"
    for f in "MesloLGS NF Regular.ttf" "MesloLGS NF Bold.ttf" \
              "MesloLGS NF Italic.ttf" "MesloLGS NF Bold Italic.ttf"; do
      curl -fsSL "$base/${f// /%20}" -o "$font_dir/$f" 2>/dev/null || true
    done

    # Helper to download and extract tar.xz from official Nerd Fonts release
    _download_nf_archive() {
      local name=$1
      local archive_name=$2
      log "Downloading $name Nerd Font..."
      local tmp_archive="/tmp/${archive_name}.tar.xz"
      local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${archive_name}.tar.xz"
      if curl -fsSL "$url" -o "$tmp_archive" 2>/dev/null; then
        tar -xf "$tmp_archive" -C "$font_dir" 2>/dev/null || true
        rm -f "$tmp_archive"
        ok "$name Nerd Font installed"
      else
        warn "Could not download $name Nerd Font archive"
      fi
    }

    if [[ "$target_font" == "all" || "$target_font" == *"jetbrains"* ]]; then
      _download_nf_archive "JetBrains Mono" "JetBrainsMono"
    fi
    if [[ "$target_font" == "all" || "$target_font" == *"fira"* ]]; then
      _download_nf_archive "Fira Code" "FiraCode"
    fi
    if [[ "$target_font" == "all" || "$target_font" == *"hack"* ]]; then
      _download_nf_archive "Hack" "Hack"
    fi
    if [[ "$target_font" == "all" || "$target_font" == *"cascadia"* ]]; then
      _download_nf_archive "Cascadia Code" "CascadiaCode"
    fi

    fc-cache -f "$HOME/.local/share/fonts" 2>/dev/null || true
    ok "Linux font cache updated (~/.local/share/fonts)"
  fi

  ok "Nerd Fonts ready"
  info "Available terminal fonts: 'MesloLGS NF', 'JetBrainsMono Nerd Font', 'FiraCode Nerd Font', 'Hack Nerd Font'"
}
