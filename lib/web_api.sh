#!/usr/bin/env bash
# =============================================================================
#  lib/web_api.sh — Modern Web & API Security Assessment Suite
#  Includes: Schemathesis, Kiterunner, Caido CLI, Arjun, FFUF, Feroxbuster
#  (uses the _sec_* helpers defined in lib/ad_pivoting.sh)
# =============================================================================

# Kiterunner (Assetnote API route discovery): pinned release asset, go install fallback.
_sec_install_kiterunner() {
  if _sec_have kr; then
    ok "Kiterunner already installed: $(kr version 2>/dev/null || echo 'ready')"
    return 0
  fi
  log "Installing Kiterunner (kr) v${KITERUNNER_VERSION}..."
  if _sec_platform && [[ -n "$(_sec_pin KITERUNNER)" ]]; then
    local url="https://github.com/assetnote/kiterunner/releases/download/v${KITERUNNER_VERSION}/kiterunner_${KITERUNNER_VERSION}_${_SEC_OS_LC}_${_SEC_ARCH_LC}.tar.gz"
    if _sec_install_bin "Kiterunner" KITERUNNER "$url" tgz kr kr; then
      ok "Kiterunner installed to ~/.local/bin/kr"
      return 0
    fi
  else
    warn "Kiterunner: upstream publishes no build for $OS/$ARCH"
  fi
  # The main package is cmd/kiterunner (binary 'kiterunner'); the release archives name it 'kr'.
  info "Kiterunner: building from source with go install"
  go_install "github.com/assetnote/kiterunner/cmd/kiterunner@v${KITERUNNER_VERSION}" kiterunner
  if _sec_have kiterunner && ! _sec_have kr; then
    _sec_bin_dir
    ln -sf "$(command -v kiterunner)" "$HOME/.local/bin/kr" && hts_track_file "$HOME/.local/bin/kr"
  fi
  hash -r 2>/dev/null || true
  if ! _sec_have kr; then warn "Kiterunner could not be installed"; return 1; fi
  return 0
}

# Caido CLI (Rust proxy daemon). It is not on crates.io; upstream publishes
# caido-cli archives at caido.download (the same list api.caido.io/releases/latest serves).
install_caido_cli() {
  if _sec_have caido-cli; then
    ok "Caido CLI already installed"
    return 0
  fi
  if ! _sec_platform; then warn "Caido CLI: unsupported platform $OS/$ARCH"; return 1; fi
  log "Installing Caido CLI v${CAIDO_VERSION}..."
  local plat kind
  case "$_SEC_OS" in
    DARWIN) kind=zip; plat="mac" ;;
    *)      kind=tgz; plat="linux" ;;
  esac
  case "$_SEC_ARCH" in
    AMD64) plat="${plat}-x86_64" ;;
    *)     plat="${plat}-aarch64" ;;
  esac
  local ext="tar.gz"
  [[ "$kind" == "zip" ]] && ext="zip"
  local url="https://caido.download/releases/v${CAIDO_VERSION}/caido-cli-v${CAIDO_VERSION}-${plat}.${ext}"
  _sec_install_bin "Caido CLI" CAIDO "$url" "$kind" caido-cli caido-cli || return 1
  ok "Caido CLI installed to ~/.local/bin/caido-cli (see: caido-cli --help)"
  return 0
}

# Feroxbuster: brew/distro package when available, otherwise the pinned Linux release binary.
_sec_install_feroxbuster() {
  if _sec_have feroxbuster; then ok "feroxbuster already installed"; return 0; fi
  if [[ -n "$(resolve_pkg feroxbuster)" ]]; then
    pkg_install feroxbuster
    hash -r 2>/dev/null || true
    _sec_have feroxbuster && return 0
  fi
  if [[ "$OS" == "Linux" ]] && _sec_platform; then
    info "feroxbuster: no usable $PKG_MGR package — using the pinned release binary"
    local base="https://github.com/epi052/feroxbuster/releases/download/v${FEROXBUSTER_VERSION}"
    if [[ "$_SEC_ARCH" == "AMD64" ]]; then
      _sec_install_bin "feroxbuster" FEROXBUSTER "$base/x86_64-linux-feroxbuster.tar.gz" tgz feroxbuster feroxbuster || return 1
    else
      _sec_install_bin "feroxbuster" FEROXBUSTER "$base/aarch64-linux-feroxbuster.zip" zip feroxbuster feroxbuster || return 1
    fi
    return 0
  fi
  warn "feroxbuster could not be installed on $OS/$ARCH"
  return 1
}

install_web_api() {
  step "Modern Web Application & API Security Assessment Suite"
  local fail=0
  _sec_bin_dir

  # 1. Schemathesis (property-based API testing for OpenAPI/Swagger/GraphQL)
  _sec_py_tool schemathesis schemathesis st || fail=1

  # 2. Kiterunner (Assetnote API route and endpoint discovery)
  _sec_install_kiterunner || fail=1

  # 3. Caido CLI (Rust interception proxy, headless daemon; the desktop app is a GUI and is not installed here)
  install_caido_cli || fail=1

  # 4. Arjun (HTTP parameter discovery). Upstream is quiet: last release 2.2.7 (Nov 2024),
  #    last push Feb 2025. It still resolves from PyPI (sdist only), so it is kept.
  _sec_py_tool arjun arjun || fail=1

  # 5. FFUF & Feroxbuster (no apt package for ffuf, so go install is the fallback)
  _sec_pkg_or_go ffuf ffuf "github.com/ffuf/ffuf/v2@v${FFUF_VERSION}" || fail=1
  _sec_install_feroxbuster || fail=1

  _sec_verify "Schemathesis" schemathesis st || fail=1
  _sec_verify "Kiterunner"   kr              || fail=1
  _sec_verify "Caido CLI"    caido-cli       || fail=1
  _sec_verify "Arjun"        arjun           || fail=1
  _sec_verify "ffuf"         ffuf            || fail=1
  _sec_verify "feroxbuster"  feroxbuster     || fail=1

  if [[ $fail -ne 0 ]]; then
    warn "Web & API Security suite finished with failures (see warnings above)"
    return 1
  fi
  ok "Web & API Security Assessment suite complete"
  return 0
}
