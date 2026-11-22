#!/usr/bin/env bash
# =============================================================================
#  lib/fonts.sh — Hacker & Developer Nerd Fonts Installer
# =============================================================================

# _install_meslo_ttfs <dest-dir> — pinned, digest-verified MesloLGS NF TTFs.
# Returns non-zero when any file could not be fetched or verified.
_install_meslo_ttfs() {
  local dest=$1 f want rc=0 base
  base="https://github.com/romkatv/powerlevel10k-media/raw/${MESLO_MEDIA_COMMIT}"
  mkdir -p "$dest" || return 1
  for f in "MesloLGS NF Regular.ttf" "MesloLGS NF Bold.ttf" \
           "MesloLGS NF Italic.ttf" "MesloLGS NF Bold Italic.ttf"; do
    case "$f" in
      *"Bold Italic"*) want="$MESLO_SHA256_BOLD_ITALIC" ;;
      *Bold*)          want="$MESLO_SHA256_BOLD" ;;
      *Italic*)        want="$MESLO_SHA256_ITALIC" ;;
      *)               want="$MESLO_SHA256_REGULAR" ;;
    esac
    if hts_download_verify "$base/${f// /%20}" "$want" "$dest/$f"; then
      hts_track_file "$dest/$f"
    else
      warn "Could not install $f"
      rc=1
    fi
  done
  return $rc
}

# _download_nf_archive <label> <archive> <font-dir> — pinned Nerd Fonts release
_download_nf_archive() {
  local name=$1 archive_name=$2 font_dir=$3
  local sha_var want tmpdir url rc=0
  sha_var="NERDFONTS_SHA256_$(printf '%s' "$archive_name" | tr '[:lower:]' '[:upper:]')"
  want="${!sha_var:-}"
  if [[ -z "$want" ]]; then
    warn "No pinned digest for $archive_name — skipping $name"
    return 1
  fi
  if ! command -v tar &>/dev/null || ! command -v xz &>/dev/null; then
    pkg_install tar xz || true
  fi
  log "Downloading $name Nerd Font ${NERDFONTS_VERSION}..."
  tmpdir="$(mktemp -d)" || return 1
  url="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERDFONTS_VERSION}/${archive_name}.tar.xz"
  if hts_download_verify "$url" "$want" "$tmpdir/${archive_name}.tar.xz" \
     && tar -xf "$tmpdir/${archive_name}.tar.xz" -C "$font_dir"; then
    hts_track_file "$font_dir"
    hts_manifest_add tool "nerd-font-$archive_name" "$NERDFONTS_VERSION"
    ok "$name Nerd Font installed"
  else
    warn "Could not install $name Nerd Font archive"
    rc=1
  fi
  rm -rf "$tmpdir"
  return $rc
}

install_fonts() {
  local target_font="${1:-all}"
  local rc=0
  step "Hacker & Developer Nerd Fonts ($target_font)"

  if [[ "$OS" == "Darwin" ]]; then
    log "Installing Nerd Fonts on macOS..."
    pkg_install_cask "font-meslo-lg-nerd-font" || rc=1

    if [[ "$target_font" == "all" || "$target_font" == *"jetbrains"* ]]; then
      pkg_install_cask "font-jetbrains-mono-nerd-font" || rc=1
    fi
    if [[ "$target_font" == "all" || "$target_font" == *"fira"* ]]; then
      pkg_install_cask "font-fira-code-nerd-font" || rc=1
    fi
    if [[ "$target_font" == "all" || "$target_font" == *"hack"* ]]; then
      pkg_install_cask "font-hack-nerd-font" || rc=1
    fi
    if [[ "$target_font" == "all" || "$target_font" == *"cascadia"* ]]; then
      pkg_install_cask "font-caskaydia-cove-nerd-font" || rc=1
    fi

    # Fallback: copy romkatv MesloLGS NF TTFs directly to ~/Library/Fonts
    local mac_font_dir="$HOME/Library/Fonts"
    mkdir -p "$mac_font_dir"
    if [[ ! -f "$mac_font_dir/MesloLGS NF Regular.ttf" ]]; then
      log "Ensuring MesloLGS NF TTFs in ~/Library/Fonts..."
      _install_meslo_ttfs "$mac_font_dir" || rc=1
    fi
  else
    # Linux installation into ~/.local/share/fonts/NerdFonts
    local font_dir="$HOME/.local/share/fonts/NerdFonts"
    mkdir -p "$font_dir"

    if ! command -v fc-cache &>/dev/null; then
      pkg_install fontconfig || warn "fontconfig not installed — font cache will not be refreshed"
    fi

    # 1. MesloLGS NF (P10k recommended)
    log "Downloading MesloLGS NF..."
    _install_meslo_ttfs "$font_dir" || rc=1

    if [[ "$target_font" == "all" || "$target_font" == *"jetbrains"* ]]; then
      _download_nf_archive "JetBrains Mono" "JetBrainsMono" "$font_dir" || rc=1
    fi
    if [[ "$target_font" == "all" || "$target_font" == *"fira"* ]]; then
      _download_nf_archive "Fira Code" "FiraCode" "$font_dir" || rc=1
    fi
    if [[ "$target_font" == "all" || "$target_font" == *"hack"* ]]; then
      _download_nf_archive "Hack" "Hack" "$font_dir" || rc=1
    fi
    if [[ "$target_font" == "all" || "$target_font" == *"cascadia"* ]]; then
      _download_nf_archive "Cascadia Code" "CascadiaCode" "$font_dir" || rc=1
    fi

    if command -v fc-cache &>/dev/null; then
      fc-cache -f "$HOME/.local/share/fonts" 2>/dev/null && ok "Linux font cache updated (~/.local/share/fonts)"
    else
      warn "fc-cache not available — restart your terminal or run fc-cache manually"
    fi
  fi

  if [[ $rc -eq 0 ]]; then
    ok "Nerd Fonts ready"
  else
    warn "Some fonts could not be installed (see warnings above)"
  fi
  info "Available terminal fonts: 'MesloLGS NF', 'JetBrainsMono Nerd Font', 'FiraCode Nerd Font', 'Hack Nerd Font'"
  return $rc
}
