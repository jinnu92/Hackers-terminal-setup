#!/usr/bin/env bash
# =============================================================================
#  lib/mobile_re.sh — Mobile & Binary Reverse Engineering Assessment Suite
#  Includes: Jadx, Apktool, frida-tools, objection
#  (uses the _sec_* helpers defined in lib/ad_pivoting.sh)
# =============================================================================

# Jadx: brew/apt/pacman package when it lands, otherwise the pinned release zip
# (platform independent, needs a Java runtime).
_sec_install_jadx() {
  if _sec_have jadx; then
    ok "Jadx already installed: $(jadx --version 2>/dev/null | head -1)"
    return 0
  fi
  log "Installing Jadx..."
  case "$PKG_MGR" in
    brew|apt|pacman)
      pkg_install jadx
      hash -r 2>/dev/null || true
      ;;
  esac
  _sec_have jadx && return 0

  info "Jadx: no usable $PKG_MGR package — using the pinned release zip v${JADX_VERSION}"
  local url="https://github.com/skylot/jadx/releases/download/v${JADX_VERSION}/jadx-${JADX_VERSION}.zip"
  local tmp dest="$HOME/.local/share/jadx"
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/hts-sec.XXXXXX")" || { warn "Jadx: could not create a temp directory"; return 1; }
  if ! _sec_download "Jadx" "$url" "$JADX_SHA256_ZIP" "$tmp/jadx.zip"; then
    rm -rf "$tmp"; return 1
  fi
  mkdir -p "$dest" "$HOME/.local/bin"
  if ! unzip -q -o "$tmp/jadx.zip" -d "$dest" || [[ ! -f "$dest/bin/jadx" ]]; then
    warn "Jadx: could not unpack the release zip into $dest"
    rm -rf "$tmp"; return 1
  fi
  rm -rf "$tmp"
  chmod +x "$dest/bin/jadx" "$dest/bin/jadx-gui" 2>/dev/null || true
  ln -sf "$dest/bin/jadx" "$HOME/.local/bin/jadx"
  ln -sf "$dest/bin/jadx-gui" "$HOME/.local/bin/jadx-gui"
  hts_track_file "$dest"
  hts_track_file "$HOME/.local/bin/jadx"
  hts_track_file "$HOME/.local/bin/jadx-gui"
  hts_manifest_add tool jadx "release-download v${JADX_VERSION}"
  _sec_bin_dir
  _sec_have java || warn "Jadx needs a Java runtime (JRE 11+) — install one (e.g. openjdk) before running it"
  ok "Jadx installed to ~/.local/bin/jadx"
  return 0
}

install_mobile_re() {
  step "Mobile & Binary Reverse Engineering Suite (Jadx, Apktool, Frida, objection)"
  local fail=0
  _sec_bin_dir

  # 1. Jadx (DEX to Java decompiler + GUI)
  _sec_install_jadx || fail=1

  # 2. Apktool (APK resource disassembler & patcher)
  if _sec_have apktool; then
    ok "Apktool already installed: $(apktool --version 2>/dev/null | head -1)"
  else
    log "Installing Apktool..."
    pkg_install apktool
    hash -r 2>/dev/null || true
    if ! _sec_have apktool; then
      warn "Apktool: no usable $PKG_MGR package. Install it manually: https://apktool.org/docs/install"
      fail=1
    fi
  fi

  # 3. Frida tooling and objection (runtime instrumentation; pipx, unpinned)
  _sec_py_tool frida-tools frida || fail=1
  _sec_py_tool objection objection || fail=1

  # MobSF is intentionally not installed: it needs Docker or a full Django/Python
  # stack plus Android SDK pieces, which is not a light scriptable install.

  _sec_verify "Jadx"        jadx    || fail=1
  _sec_verify "Apktool"     apktool || fail=1
  _sec_verify "Frida tools" frida   || fail=1
  _sec_verify "objection"   objection || fail=1

  if [[ $fail -ne 0 ]]; then
    warn "Mobile & Reverse Engineering suite finished with failures (see warnings above)"
    return 1
  fi
  ok "Mobile & Binary Reverse Engineering suite complete"
  return 0
}
