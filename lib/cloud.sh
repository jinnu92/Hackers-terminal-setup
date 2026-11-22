#!/usr/bin/env bash
# =============================================================================
#  lib/cloud.sh — Cloud, Container & Infrastructure Security Tools
# =============================================================================

# _cloud_arch <aws|gcloud> — print the vendor's architecture token for Linux.
_cloud_arch() {
  local m
  m="$(uname -m)"
  case "$1:$m" in
    aws:x86_64|aws:amd64)        echo "x86_64" ;;
    aws:aarch64|aws:arm64)       echo "aarch64" ;;
    gcloud:x86_64|gcloud:amd64)  echo "x86_64" ;;
    gcloud:aarch64|gcloud:arm64) echo "arm" ;;
    *) return 1 ;;
  esac
}

# AWS CLI v2 into ~/.local (no sudo needed), right archive for the CPU.
_install_awscli_linux() {
  local arch tmpdir rc=0
  if ! arch="$(_cloud_arch aws)"; then
    warn "AWS CLI: unsupported architecture $(uname -m)"
    return 1
  fi
  command -v unzip &>/dev/null || pkg_install unzip || true
  if ! command -v unzip &>/dev/null; then
    warn "AWS CLI: unzip is required and could not be installed"
    return 1
  fi
  log "Installing AWS CLI v2 ($arch)..."
  tmpdir="$(mktemp -d)" || return 1
  if hts_fetch "https://awscli.amazonaws.com/awscli-exe-linux-${arch}.zip" "$tmpdir/awscliv2.zip" \
     && unzip -q "$tmpdir/awscliv2.zip" -d "$tmpdir" \
     && mkdir -p "$HOME/.local/bin" \
     && "$tmpdir/aws/install" --update -i "$HOME/.local/aws-cli" -b "$HOME/.local/bin"; then
    hts_track_file "$HOME/.local/bin/aws"
    hts_track_file "$HOME/.local/aws-cli"
    hts_manifest_add tool aws-cli "official-installer"
  else
    warn "AWS CLI install failed"
    rc=1
  fi
  rm -rf "$tmpdir"
  return $rc
}

# Azure CLI: Microsoft's script supports Debian/Ubuntu only; elsewhere use pipx.
_install_azcli_linux() {
  local interp
  if [[ "$PKG_MGR" == "apt" ]]; then
    log "Installing Azure CLI (Microsoft apt repository script)..."
    interp="$(_sudo_interp)" || return 1
    if hts_run_remote_script "https://aka.ms/InstallAzureCLIDeb" "$interp"; then
      hts_manifest_add tool azure-cli "InstallAzureCLIDeb"
      return 0
    fi
    warn "Azure CLI install failed — see https://learn.microsoft.com/cli/azure/install-azure-cli-linux"
    return 1
  fi
  warn "Azure CLI: no scripted repository install for $PKG_MGR — using pipx"
  pkg_install pipx || true
  command -v pipx &>/dev/null || { warn "Azure CLI: pipx unavailable"; return 1; }
  pipx_install azure-cli
  export PATH="$HOME/.local/bin:$PATH"
  command -v az &>/dev/null
}

# gcloud: Google's official archive, installed non-interactively under ~/.local.
_install_gcloud_linux() {
  local arch tmpdir dest="$HOME/.local/share/google-cloud-sdk" rc=0
  if ! arch="$(_cloud_arch gcloud)"; then
    warn "gcloud: unsupported architecture $(uname -m) — see cloud.google.com/sdk/docs/install"
    return 1
  fi
  command -v tar &>/dev/null || pkg_install tar || true
  command -v python3 &>/dev/null || info "gcloud bundles its own Python; system python3 not required"
  log "Installing Google Cloud CLI ($arch) from the official archive..."
  tmpdir="$(mktemp -d)" || return 1
  if hts_fetch "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-${arch}.tar.gz" "$tmpdir/gcloud.tar.gz" \
     && tar -xzf "$tmpdir/gcloud.tar.gz" -C "$tmpdir" \
     && rm -rf "$dest" \
     && mkdir -p "$(dirname "$dest")" "$HOME/.local/bin" \
     && mv "$tmpdir/google-cloud-sdk" "$dest" \
     && "$dest/install.sh" --quiet --usage-reporting=false --path-update=false \
          --command-completion=false --rc-path=/dev/null \
     && ln -sf "$dest/bin/gcloud" "$HOME/.local/bin/gcloud"; then
    hts_track_file "$dest"
    hts_track_file "$HOME/.local/bin/gcloud"
    hts_manifest_add tool google-cloud-cli "official-archive"
  else
    warn "gcloud install failed — see cloud.google.com/sdk/docs/install"
    rc=1
  fi
  rm -rf "$tmpdir"
  return $rc
}

install_cloud() {
  step "Cloud security tools"
  local rc=0
  export PATH="$HOME/.local/bin:$PATH"

  if [[ "$OS" == "Darwin" ]]; then
    pkg_install awscli || rc=1
    pkg_install_cask google-cloud-sdk || rc=1
    pkg_install azure-cli || rc=1
  else
    if ! command -v aws &>/dev/null; then
      _install_awscli_linux || rc=1
    else
      info "AWS CLI already installed"
    fi
    if ! command -v az &>/dev/null; then
      _install_azcli_linux || rc=1
    else
      info "Azure CLI already installed"
    fi
    if ! command -v gcloud &>/dev/null; then
      _install_gcloud_linux || rc=1
    else
      info "gcloud already installed"
    fi
  fi

  # Go-based cloud tools
  go_install "github.com/BishopFox/cloudfox@latest"                     cloudfox
  go_install "github.com/gitleaks/gitleaks/v8@latest"                   gitleaks
  go_install "github.com/trufflesecurity/trufflehog/v3@latest"          trufflehog

  # Python cloud tools
  pipx_install prowler
  pipx_install pacu
  pipx_install s3scanner

  local b
  for b in aws gcloud az cloudfox gitleaks trufflehog prowler pacu s3scanner; do
    hts_verify_cmd "cloud: $b" "$b" || rc=1
  done

  if [[ $rc -eq 0 ]]; then
    ok "Cloud security done"
  else
    warn "Cloud security finished with errors"
  fi
  return $rc
}
