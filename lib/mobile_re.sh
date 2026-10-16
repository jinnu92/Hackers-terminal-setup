#!/usr/bin/env bash
# =============================================================================
#  lib/mobile_re.sh — Mobile & Binary Reverse Engineering Assessment Suite
#  Includes: Jadx, Apktool
# =============================================================================

install_mobile_re() {
  step "Mobile & Binary Reverse Engineering Suite (Jadx, Apktool)"

  # 1. Jadx (DEX to Java decompiler + GUI)
  if ! command -v jadx &>/dev/null; then
    log "Installing Jadx..."
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install jadx
    else
      case "$PKG_MGR" in
        apt)    pkg_install jadx ;;
        pacman) pkg_install jadx ;;
        *)
          local tmpdir
          tmpdir=$(mktemp -d)
          curl -fsSL "https://github.com/skylot/jadx/releases/latest/download/jadx-1.5.0.zip" -o "$tmpdir/jadx.zip" 2>/dev/null || true
          if [[ -f "$tmpdir/jadx.zip" ]]; then
            mkdir -p "$HOME/.local/share/jadx"
            unzip -q "$tmpdir/jadx.zip" -d "$HOME/.local/share/jadx" 2>/dev/null || true
            ln -sf "$HOME/.local/share/jadx/bin/jadx" "$HOME/.local/bin/jadx"
            ln -sf "$HOME/.local/share/jadx/bin/jadx-gui" "$HOME/.local/bin/jadx-gui"
            ok "Jadx installed to ~/.local/bin/jadx"
          fi
          rm -rf "$tmpdir"
          ;;
      esac
    fi
  else
    ok "Jadx already installed: $(jadx --version 2>/dev/null | head -1)"
  fi

  # 2. Apktool (APK resource disassembler & patcher)
  if ! command -v apktool &>/dev/null; then
    log "Installing Apktool..."
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install apktool
    else
      pkg_install apktool
    fi
  else
    ok "Apktool already installed: $(apktool --version 2>/dev/null | head -1)"
  fi

  ok "Mobile & Binary Reverse Engineering suite complete"
}
