#!/usr/bin/env bash
# =============================================================================
#  lib/web_api.sh — Modern Web & API Security Assessment Suite
#  Includes: Schemathesis, Kiterunner, Caido CLI, Arjun, FFUF, Feroxbuster
# =============================================================================

install_web_api() {
  step "Modern Web Application & API Security Assessment Suite"

  # 1. Schemathesis (Property-based API Testing for OpenAPI/Swagger/GraphQL)
  if ! command -v schemathesis &>/dev/null && ! command -v st &>/dev/null; then
    log "Installing Schemathesis..."
    if [[ "$OS" == "Darwin" ]] && brew list schemathesis &>/dev/null; then
      ok "Schemathesis already installed via brew"
    else
      if command -v uv &>/dev/null; then
        uv tool install schemathesis || pipx_install schemathesis
      else
        pipx_install schemathesis
      fi
    fi
  else
    ok "Schemathesis already installed: $(schemathesis --version 2>/dev/null || echo 'ready')"
  fi

  # 2. Kiterunner (Assetnote API route and endpoint discovery)
  if ! command -v kr &>/dev/null; then
    log "Installing Kiterunner (kr)..."
    go_install "github.com/assetnote/kiterunner/cmd/kr@latest" kr
  else
    ok "Kiterunner already installed: $(kr version 2>/dev/null || echo 'ready')"
  fi

  # 3. Caido CLI / Daemon (Modern Rust Web Security Interception Proxy)
  if ! command -v caido-cli &>/dev/null && ! command -v caido &>/dev/null; then
    log "Installing Caido CLI..."
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install_cask caido
    elif command -v cargo &>/dev/null; then
      cargo install caido-cli 2>/dev/null || true
    fi
  else
    ok "Caido already installed"
  fi

  # 4. Arjun (HTTP Parameter Discovery)
  if ! command -v arjun &>/dev/null; then
    log "Installing Arjun..."
    if command -v uv &>/dev/null; then
      uv tool install arjun || pipx_install arjun
    else
      pipx_install arjun
    fi
  else
    ok "Arjun already installed"
  fi

  # 5. FFUF & Feroxbuster
  pkg_install ffuf feroxbuster

  ok "Web & API Security Assessment suite complete"
}
