#!/usr/bin/env bash
# =============================================================================
#  lib/bugbounty.sh — Web Recon, OSINT, and Bug Bounty Automation
#  (uses the _sec_* helpers defined in lib/ad_pivoting.sh and the Caido /
#  feroxbuster installers in lib/web_api.sh)
# =============================================================================

# Nikto: brew/distro package when available, otherwise a clone pinned to a release tag.
_sec_install_nikto() {
  local dir="$HOME/.local/share/nikto"
  if _sec_have nikto; then ok "nikto already installed"; return 0; fi
  if [[ -n "$(resolve_pkg nikto)" ]]; then
    pkg_install nikto
    hash -r 2>/dev/null || true
    _sec_have nikto && return 0
  fi
  info "nikto: no usable $PKG_MGR package — cloning sullo/nikto ($NIKTO_TAG)"
  _sec_git_clone_tag "nikto" "https://github.com/sullo/nikto.git" "$NIKTO_TAG" "$dir" || return 1
  _sec_write_wrapper nikto << 'NIKTO_RUNNER' || return 1
#!/usr/bin/env bash
exec perl "$HOME/.local/share/nikto/program/nikto.pl" "$@"
NIKTO_RUNNER
  _sec_have perl || warn "nikto needs perl, which was not found"
  hash -r 2>/dev/null || true
  _sec_have nikto
}

install_bugbounty() {
  step "Bug bounty tools"
  local fail=0
  _sec_bin_dir

  # Package-manager tools, each with a fallback where the package manager has no package
  _sec_pkg_or_go ffuf ffuf "github.com/ffuf/ffuf/v2@v${FFUF_VERSION}" || fail=1
  _sec_install_feroxbuster || fail=1
  _sec_install_nikto       || fail=1
  if _sec_have mitmproxy; then
    ok "mitmproxy already installed"
  else
    [[ -n "$(resolve_pkg mitmproxy)" ]] && pkg_install mitmproxy
    hash -r 2>/dev/null || true
    if ! _sec_have mitmproxy; then
      info "mitmproxy: no usable $PKG_MGR package — falling back to pipx"
      _sec_py_tool mitmproxy mitmproxy || fail=1
    fi
  fi

  # Go-based ProjectDiscovery & community tools, pinned in lib/versions.sh
  _sec_go_tool "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@v${SUBFINDER_VERSION}"          subfinder         || fail=1
  _sec_go_tool "github.com/projectdiscovery/httpx/cmd/httpx@v${HTTPX_VERSION}"                         httpx             || fail=1
  _sec_go_tool "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@v${NUCLEI_VERSION}"                   nuclei            || fail=1
  _sec_go_tool "github.com/projectdiscovery/katana/cmd/katana@v${KATANA_VERSION}"                      katana            || fail=1
  _sec_go_tool "github.com/projectdiscovery/dnsx/cmd/dnsx@v${DNSX_VERSION}"                            dnsx              || fail=1
  _sec_go_tool "github.com/projectdiscovery/interactsh/cmd/interactsh-client@v${INTERACTSH_VERSION}"   interactsh-client || fail=1
  _sec_go_tool "github.com/lc/gau/v2/cmd/gau@v${GAU_VERSION}"                                          gau               || fail=1
  _sec_go_tool "github.com/hakluke/hakrawler@v${HAKRAWLER_VERSION}"                                    hakrawler         || fail=1
  _sec_go_tool "github.com/tomnomnom/waybackurls@v${WAYBACKURLS_VERSION}"                              waybackurls       || fail=1
  _sec_go_tool "github.com/owasp-amass/amass/v5/cmd/amass@v${AMASS_VERSION}"                           amass             || fail=1
  # dalfox 3.x is a Rust rewrite published through brew; on Linux the last Go release (2.x) is installed
  _sec_pkg_or_go dalfox dalfox "github.com/hahwul/dalfox/v2@v${DALFOX_VERSION}"                                          || fail=1

  # Caido CLI (headless proxy) and Burp Suite
  install_caido_cli || fail=1
  if [[ "$OS" == "Darwin" ]]; then
    pkg_install_cask burp-suite
  else
    warn "Burp Suite: download the installer from portswigger.net/burp/releases (not scriptable)"
  fi

  # Python tools (unpinned, latest from PyPI)
  _sec_py_tool arjun arjun || fail=1   # upstream last pushed Feb 2025; still installs from PyPI
  _sec_py_tool bbot bbot   || fail=1   # BBOT recon framework

  # Update nuclei templates
  if _sec_have nuclei; then
    log "Updating nuclei templates..."
    nuclei -update-templates -silent 2>/dev/null || warn "nuclei template update failed (run 'nuclei -update-templates' later)"
  fi

  _sec_verify "ffuf"            ffuf || fail=1
  _sec_verify "feroxbuster"     feroxbuster || fail=1
  _sec_verify "nikto"           nikto || fail=1
  _sec_verify "mitmproxy"       mitmproxy || fail=1
  _sec_verify "subfinder"       subfinder || fail=1
  _sec_verify "httpx"           httpx || fail=1
  _sec_verify "nuclei"          nuclei || fail=1
  _sec_verify "katana"          katana || fail=1
  _sec_verify "dnsx"            dnsx || fail=1
  _sec_verify "interactsh"      interactsh-client || fail=1
  _sec_verify "gau"             gau || fail=1
  _sec_verify "hakrawler"       hakrawler || fail=1
  _sec_verify "waybackurls"     waybackurls || fail=1
  _sec_verify "amass"           amass || fail=1
  _sec_verify "dalfox"          dalfox || fail=1
  _sec_verify "Caido CLI"       caido-cli || fail=1
  _sec_verify "arjun"           arjun || fail=1
  _sec_verify "bbot"            bbot || fail=1

  if [[ $fail -ne 0 ]]; then
    warn "Bug bounty suite finished with failures (see warnings above)"
    return 1
  fi
  ok "Bug bounty tools done"
  return 0
}
