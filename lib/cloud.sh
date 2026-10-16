#!/usr/bin/env bash
# =============================================================================
#  lib/cloud.sh — Cloud, Container & Infrastructure Security Tools
# =============================================================================

install_cloud() {
  step "Cloud security tools"

  if [[ "$OS" == "Darwin" ]]; then
    pkg_install awscli
    pkg_install_cask google-cloud-sdk
    pkg_install azure-cli
  else
    if ! command -v aws &>/dev/null; then
      log "Installing AWS CLI v2..."
      local tmpdir
      tmpdir=$(mktemp -d)
      curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$tmpdir/awscliv2.zip"
      unzip -q "$tmpdir/awscliv2.zip" -d "$tmpdir"
      sudo "$tmpdir/aws/install" || warn "AWS CLI install failed"
      rm -rf "$tmpdir"
    else
      info "AWS CLI already installed"
    fi
    if ! command -v az &>/dev/null; then
      curl -fsSL https://aka.ms/InstallAzureCLIDeb | sudo bash 2>/dev/null || \
        warn "Azure CLI install failed — install manually"
    fi
    warn "gcloud: install from cloud.google.com/sdk/docs/install"
  fi

  # Go-based cloud tools
  go_install "github.com/BishopFox/cloudfox@latest"                     cloudfox
  go_install "github.com/zricethezav/gitleaks/v8@latest"                gitleaks
  go_install "github.com/trufflesecurity/trufflehog/v3@latest"          trufflehog

  # Python cloud tools
  pipx_install prowler
  pipx_install pacu
  pipx_install s3scanner

  ok "Cloud security done"
}
