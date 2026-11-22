#!/usr/bin/env bash
# =============================================================================
#  lib/helpers.sh — Language and Package Runtimes (Go, Python, Node Prefix)
# =============================================================================

# Oldest Go release the installer accepts before replacing it. Modern security
# tools (ProjectDiscovery, ligolo-ng, ...) need a recent toolchain, and distro
# packages are often years behind.
HTS_GO_MIN_MINOR=25

# _hts_go_minor — prints the minor version of the Go on PATH (e.g. 27 for go1.27.4)
_hts_go_minor() {
  go version 2>/dev/null | sed -n 's/.*go1\.\([0-9][0-9]*\).*/\1/p' | head -1
}

# _install_go_official — pinned official Go toolchain into ~/.local/share/go
# (no sudo), verified against the digest published on go.dev.
_install_go_official() {
  local os arch sha
  case "$(uname -s)" in
    Linux)  os="linux" ;;
    Darwin) os="darwin" ;;
    *) warn "No official Go build is configured for $(uname -s)"; return 1 ;;
  esac
  case "$(uname -m)" in
    x86_64|amd64)  arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) warn "No official Go build is configured for $(uname -m)"; return 1 ;;
  esac
  case "${os}_${arch}" in
    linux_amd64)  sha="$GO_SHA256_LINUX_AMD64" ;;
    linux_arm64)  sha="$GO_SHA256_LINUX_ARM64" ;;
    darwin_amd64) sha="$GO_SHA256_DARWIN_AMD64" ;;
    darwin_arm64) sha="$GO_SHA256_DARWIN_ARM64" ;;
  esac

  local share="$HOME/.local/share" tmp
  tmp="$(mktemp -d)" || return 1
  log "Installing Go ${GO_VERSION} (official build, checksum verified) to ~/.local/share/go..."
  if ! hts_download_verify "https://go.dev/dl/go${GO_VERSION}.${os}-${arch}.tar.gz" "$sha" "$tmp/go.tar.gz"; then
    rm -rf "$tmp"
    return 1
  fi
  mkdir -p "$share" "$HOME/.local/bin"
  if ! tar -xzf "$tmp/go.tar.gz" -C "$tmp"; then
    rm -rf "$tmp"
    warn "Could not unpack the Go archive"
    return 1
  fi
  if [[ -d "$share/go" ]]; then
    rm -rf "$share/go"
  fi
  mv "$tmp/go" "$share/go"
  rm -rf "$tmp"
  ln -sf "$share/go/bin/go" "$HOME/.local/bin/go"
  ln -sf "$share/go/bin/gofmt" "$HOME/.local/bin/gofmt"
  hts_track_file "$share/go"
  hts_track_file "$HOME/.local/bin/go"
  hts_track_file "$HOME/.local/bin/gofmt"
  hts_manifest_add tool "go" "direct"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
  esac
  hash -r 2>/dev/null || true
}

install_golang() {
  local rc=0 minor
  minor="$(_hts_go_minor)"
  if [[ -n "$minor" && "$minor" -ge "$HTS_GO_MIN_MINOR" ]]; then
    ok "Go already installed: $(go version)"
  else
    if [[ -n "$minor" ]]; then
      warn "Go 1.${minor} is older than 1.${HTS_GO_MIN_MINOR}; installing the current release alongside it"
    fi
    if [[ "$PKG_MGR" == "brew" ]]; then
      # Homebrew tracks the current Go release
      log "Installing Go with Homebrew..."
      if [[ -n "$minor" ]]; then
        brew upgrade go || brew install go || rc=1
      else
        brew install go || rc=1
      fi
      [[ "$rc" -eq 0 ]] && hts_manifest_add tool "go" "brew"
    else
      # Distro packages lag far behind, so Linux gets the official toolchain
      _install_go_official || rc=1
    fi
    [[ "$rc" -eq 0 ]] || warn "Go installation failed"
  fi
  export GOPATH="$HOME/go"
  export PATH="$HOME/go/bin:$PATH"
  return "$rc"
}

pipx_install() {
  local pkg=$1
  export PATH="$HOME/.local/bin:$PATH"
  if pipx list 2>/dev/null | grep -q "^  $pkg"; then
    info "$pkg already installed via pipx"
  else
    log "Installing $pkg via pipx..."
    if pipx install "$pkg"; then
      hts_manifest_add tool "$pkg" "pipx"
    else
      warn "pipx install $pkg failed"
      return 1
    fi
  fi
  return 0
}

# hts_node_managed — succeeds (and prints the manager name) when nvm, fnm or Volta
# is managing Node, in which case the npm global prefix must not be overridden.
hts_node_managed() {
  local node_path=""
  node_path="$(command -v node 2>/dev/null || true)"
  case "$node_path" in
    */.nvm/*|*/nvm/*)       echo "nvm";   return 0 ;;
    */fnm/*|*/.fnm/*|*/fnm_multishells/*) echo "fnm"; return 0 ;;
    */.volta/*|*/volta/*)   echo "Volta"; return 0 ;;
  esac
  if [[ -n "${NVM_BIN:-}" ]]; then echo "nvm"; return 0; fi
  if [[ -n "${FNM_MULTISHELL_PATH:-}" ]]; then echo "fnm"; return 0; fi
  if [[ -n "${VOLTA_HOME:-}" && -d "${VOLTA_HOME}" && -n "$node_path" ]]; then echo "Volta"; return 0; fi
  return 1
}

npm_global_install() {
  local pkg=$1 mgr=""
  if mgr="$(hts_node_managed)"; then
    warn "Node is managed by $mgr — not overriding the npm global prefix"
  else
    mkdir -p "$HOME/.npm-global"
    npm config set prefix "$HOME/.npm-global" 2>/dev/null || true
    export PATH="$HOME/.npm-global/bin:$PATH"
  fi
  if npm list -g "$pkg" &>/dev/null 2>&1; then
    info "$pkg already installed via npm"
  else
    log "Installing $pkg via npm..."
    if npm install -g "$pkg"; then
      hts_manifest_add tool "$pkg" "npm"
    else
      warn "npm install -g $pkg failed"
      return 1
    fi
  fi
  return 0
}

go_install() {
  local pkg=$1   # full go import path e.g. github.com/foo/bar@latest
  local name=$2  # binary name to check
  export GOPATH="$HOME/go"
  export PATH="$HOME/go/bin:$PATH"
  if command -v "$name" &>/dev/null; then
    info "$name already installed"
  else
    if ! command -v go &>/dev/null; then
      install_golang
    fi
    if command -v go &>/dev/null; then
      log "go install $pkg..."
      if go install "$pkg"; then
        # detail records the module path so --update can run "go install <path>@latest"
        hts_manifest_add tool "$name" "go:${pkg%@*}"
      else
        warn "go install $pkg failed"
        return 1
      fi
    else
      warn "go not found — cannot install $name. Install go first."
      return 1
    fi
  fi
  return 0
}
