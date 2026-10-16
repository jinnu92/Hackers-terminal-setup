#!/usr/bin/env bash
# =============================================================================
#  lib/cloud_devsec.sh — Cloud, Container & DevSecOps Assessment Suite
#  Includes: Trivy, Syft, Grype, Checkov, Kube-bench, Kube-hunter
# =============================================================================

install_cloud_devsec() {
  step "Cloud, Container & DevSecOps Assessment Suite"

  # 1. Trivy (Aqua Security unified vulnerability, container, and IaC scanner)
  if ! command -v trivy &>/dev/null; then
    log "Installing Trivy..."
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install trivy
    else
      curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b "$HOME/.local/bin" || warn "Trivy install script failed"
    fi
  else
    ok "Trivy already installed: $(trivy --version 2>/dev/null | head -1)"
  fi

  # 2. Syft (Anchore SBOM generator)
  if ! command -v syft &>/dev/null; then
    log "Installing Syft..."
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install syft
    else
      curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b "$HOME/.local/bin" || warn "Syft install script failed"
    fi
  else
    ok "Syft already installed: $(syft --version 2>/dev/null | head -1)"
  fi

  # 3. Grype (Anchore vulnerability matcher)
  if ! command -v grype &>/dev/null; then
    log "Installing Grype..."
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install grype
    else
      curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b "$HOME/.local/bin" || warn "Grype install script failed"
    fi
  else
    ok "Grype already installed: $(grype version 2>/dev/null | head -1)"
  fi

  # 4. Checkov (Infrastructure-as-Code SAST scanner)
  if ! command -v checkov &>/dev/null; then
    log "Installing Checkov..."
    if command -v uv &>/dev/null; then
      uv tool install checkov || pipx_install checkov
    else
      pipx_install checkov
    fi
  else
    ok "Checkov already installed: $(checkov --version 2>/dev/null || echo 'ready')"
  fi

  # 5. Kube-bench & Kube-hunter
  if ! command -v kube-hunter &>/dev/null; then
    log "Installing Kube-hunter..."
    if command -v uv &>/dev/null; then
      uv tool install kube-hunter || pipx_install kube-hunter
    else
      pipx_install kube-hunter
    fi
  fi

  ok "Cloud, Container & DevSecOps suite complete"
}
