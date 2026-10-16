#!/usr/bin/env bash
# =============================================================================
#  lib/bugbounty.sh — Web Recon, OSINT, and Bug Bounty Automation
# =============================================================================

install_bugbounty() {
  step "Bug bounty tools"

  # Brew/apt installable
  for pkg in ffuf mitmproxy nikto feroxbuster; do
    pkg_install "$pkg"
  done

  # Go-based ProjectDiscovery & community tools
  go_install "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"       subfinder
  go_install "github.com/projectdiscovery/httpx/cmd/httpx@latest"                  httpx
  go_install "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"             nuclei
  go_install "github.com/projectdiscovery/katana/cmd/katana@latest"                katana
  go_install "github.com/projectdiscovery/dnsx/cmd/dnsx@latest"                    dnsx
  go_install "github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest" interactsh-client
  go_install "github.com/lc/gau/v2/cmd/gau@latest"                                 gau
  go_install "github.com/hakluke/hakrawler@latest"                                 hakrawler
  go_install "github.com/tomnomnom/waybackurls@latest"                             waybackurls
  go_install "github.com/owasp-amass/amass/v4/...@latest"                          amass
  go_install "github.com/hahwul/dalfox/v2@latest"                                 dalfox

  # macOS cask tools
  if [[ "$OS" == "Darwin" ]]; then
    pkg_install_cask burp-suite
    pkg_install_cask caido "" "https://caido.io"
  else
    warn "Burp Suite: download .sh installer from portswigger.net/burp/releases"
    warn "caido: download AppImage from caido.io"
  fi

  # Python tools
  pipx_install arjun

  # Update nuclei templates
  command -v nuclei &>/dev/null && {
    log "Updating nuclei templates..."
    nuclei -update-templates -silent 2>/dev/null || true
  }

  ok "Bug bounty tools done"
}
