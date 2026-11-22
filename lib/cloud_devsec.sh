#!/usr/bin/env bash
# =============================================================================
#  lib/cloud_devsec.sh — Cloud, Container & DevSecOps Assessment Suite
#  Includes: Trivy, Syft, Grype, Checkov, Kubescape, Kube-bench, OSV-Scanner
#  (kube-hunter was dropped: unmaintained upstream since 2024)
# =============================================================================

# _devsec_sha <TOOL_PREFIX> <amd64|arm64> — pinned SHA-256 from versions.sh
_devsec_sha() {
  local var="${1}_SHA256_LINUX_$(printf '%s' "$2" | tr '[:lower:]' '[:upper:]')"
  printf '%s' "${!var:-}"
}

# _devsec_installer <label> <bin> <script-url> <version> — Anchore/Aqua installer
# script, version pinned through the script's own version argument.
_devsec_installer() {
  local label=$1 bin=$2 url=$3 ver=$4
  mkdir -p "$HOME/.local/bin"
  if hts_run_remote_script "$url" "sh" -b "$HOME/.local/bin" "$ver"; then
    hts_track_file "$HOME/.local/bin/$bin"
    hts_manifest_add tool "$bin" "$ver"
    return 0
  fi
  warn "$label install script failed"
  return 1
}

_install_kube_bench_linux() {
  local arch tmpdir sha dest="$HOME/.local/share/kube-bench" rc=0
  arch="$(_hts_arch)" || { warn "kube-bench: unsupported architecture $(uname -m)"; return 1; }
  sha="$(_devsec_sha KUBE_BENCH "$arch")"
  [[ -n "$sha" ]] || { warn "kube-bench: no pinned digest for $arch"; return 1; }
  tmpdir="$(mktemp -d)" || return 1
  if hts_download_verify "https://github.com/aquasecurity/kube-bench/releases/download/v${KUBE_BENCH_VERSION}/kube-bench_${KUBE_BENCH_VERSION}_linux_${arch}.tar.gz" "$sha" "$tmpdir/kb.tar.gz" \
     && mkdir -p "$tmpdir/x" "$HOME/.local/bin" \
     && tar -xzf "$tmpdir/kb.tar.gz" -C "$tmpdir/x" \
     && rm -rf "$dest" && mkdir -p "$dest" \
     && mv "$tmpdir/x/kube-bench" "$tmpdir/x/cfg" "$dest/" \
     && ln -sf "$dest/kube-bench" "$HOME/.local/bin/kube-bench"; then
    hts_track_file "$dest"
    hts_track_file "$HOME/.local/bin/kube-bench"
    hts_manifest_add tool kube-bench "v${KUBE_BENCH_VERSION}"
    info "kube-bench: run with --config-dir $dest/cfg --config $dest/cfg/config.yaml"
  else
    warn "kube-bench install failed"
    rc=1
  fi
  rm -rf "$tmpdir"
  return $rc
}

install_cloud_devsec() {
  step "Cloud, Container & DevSecOps Assessment Suite"
  local rc=0 arch=""
  export PATH="$HOME/.local/bin:$PATH"
  [[ "$OS" == "Linux" ]] && arch="$(_hts_arch || true)"

  # 1. Trivy (Aqua Security unified vulnerability, container, and IaC scanner)
  if ! command -v trivy &>/dev/null; then
    log "Installing Trivy ${TRIVY_VERSION}..."
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install trivy || rc=1
    else
      _devsec_installer Trivy trivy \
        "https://raw.githubusercontent.com/aquasecurity/trivy/${TRIVY_VERSION}/contrib/install.sh" "$TRIVY_VERSION" || rc=1
    fi
  else
    ok "Trivy already installed: $(trivy --version 2>/dev/null | head -1)"
  fi

  # 2. Syft (Anchore SBOM generator)
  if ! command -v syft &>/dev/null; then
    log "Installing Syft ${SYFT_VERSION}..."
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install syft || rc=1
    else
      _devsec_installer Syft syft \
        "https://raw.githubusercontent.com/anchore/syft/${SYFT_VERSION}/install.sh" "$SYFT_VERSION" || rc=1
    fi
  else
    ok "Syft already installed: $(syft --version 2>/dev/null | head -1)"
  fi

  # 3. Grype (Anchore vulnerability matcher)
  if ! command -v grype &>/dev/null; then
    log "Installing Grype ${GRYPE_VERSION}..."
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install grype || rc=1
    else
      _devsec_installer Grype grype \
        "https://raw.githubusercontent.com/anchore/grype/${GRYPE_VERSION}/install.sh" "$GRYPE_VERSION" || rc=1
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

  # 5. Kubescape (Kubernetes posture scanner; replaces unmaintained kube-hunter)
  if ! command -v kubescape &>/dev/null; then
    log "Installing Kubescape ${KUBESCAPE_VERSION}..."
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install kubescape || rc=1
    elif [[ -n "$arch" ]]; then
      _install_release_bin kubescape \
        "https://github.com/kubescape/kubescape/releases/download/${KUBESCAPE_VERSION}/kubescape_${KUBESCAPE_VERSION#v}_linux_${arch}" \
        "$(_devsec_sha KUBESCAPE "$arch")" || rc=1
    else
      warn "Kubescape: unsupported architecture $(uname -m)"; rc=1
    fi
  fi

  # 6. kube-bench (CIS Kubernetes benchmark)
  if ! command -v kube-bench &>/dev/null; then
    log "Installing kube-bench v${KUBE_BENCH_VERSION}..."
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install kube-bench || rc=1
    else
      _install_kube_bench_linux || rc=1
    fi
  fi

  # 7. OSV-Scanner (Google; dependency vulnerability scanner)
  if ! command -v osv-scanner &>/dev/null; then
    log "Installing OSV-Scanner ${OSV_SCANNER_VERSION}..."
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install osv-scanner || rc=1
    elif [[ -n "$arch" ]]; then
      _install_release_bin osv-scanner \
        "https://github.com/google/osv-scanner/releases/download/${OSV_SCANNER_VERSION}/osv-scanner_linux_${arch}" \
        "$(_devsec_sha OSV_SCANNER "$arch")" || rc=1
    else
      warn "OSV-Scanner: unsupported architecture $(uname -m)"; rc=1
    fi
  fi

  local b
  for b in trivy syft grype checkov kubescape kube-bench osv-scanner; do
    hts_verify_cmd "devsec: $b" "$b" || rc=1
  done

  if [[ $rc -eq 0 ]]; then
    ok "Cloud, Container & DevSecOps suite complete"
  else
    warn "Cloud, Container & DevSecOps suite finished with errors"
  fi
  return $rc
}
