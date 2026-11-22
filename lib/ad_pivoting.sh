#!/usr/bin/env bash
# =============================================================================
#  lib/ad_pivoting.sh — Internal Network, Active Directory & Pivoting Tools
#  Includes: Ligolo-ng, Chisel, NetExec (nxc), BloodHound (python ingestors and
#  the BloodHound CE CLI), Responder, Certipy
#
#  This file also holds the _sec_* helpers shared by the other security suites
#  (web_api, mobile_re, pentest, bugbounty). They are only called at run time,
#  so module load order does not matter.
# =============================================================================

# ─── Shared helpers for the security suites ──────────────────────────────────

_sec_have() { command -v "$1" &>/dev/null; }

# Sets _SEC_OS / _SEC_ARCH (DARWIN|LINUX, AMD64|ARM64, used for the pinned digest
# variable names) and _SEC_OS_LC / _SEC_ARCH_LC (lower case, used in asset names).
_sec_platform() {
  case "$OS" in
    Darwin) _SEC_OS=DARWIN; _SEC_OS_LC=darwin ;;
    Linux)  _SEC_OS=LINUX;  _SEC_OS_LC=linux ;;
    *) return 1 ;;
  esac
  case "$ARCH" in
    x86_64|amd64)  _SEC_ARCH=AMD64; _SEC_ARCH_LC=amd64 ;;
    arm64|aarch64) _SEC_ARCH=ARM64; _SEC_ARCH_LC=arm64 ;;
    *) return 1 ;;
  esac
  return 0
}

# _sec_pin <TOOL> — print the pinned SHA-256 of <TOOL> for the current platform
_sec_pin() {
  local var="${1}_SHA256_${_SEC_OS}_${_SEC_ARCH}"
  printf '%s' "${!var:-}"
}

# Make sure ~/.local/bin exists and is on PATH for this run.
_sec_bin_dir() {
  mkdir -p "$HOME/.local/bin" 2>/dev/null || true
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
  esac
}

# _sec_download <label> <url> <sha256> <dest> — verified download; warns on failure
_sec_download() {
  local label=$1 url=$2 sha=$3 dest=$4
  if [[ -z "$sha" ]]; then
    warn "$label: no pinned SHA-256 for $OS/$ARCH — refusing an unverified download"
    return 1
  fi
  if ! hts_download_verify "$url" "$sha" "$dest"; then
    warn "$label: download or checksum verification failed ($url)"
    return 1
  fi
  return 0
}

# _sec_install_bin <label> <TOOLKEY> <url> <tgz|zip|gz> <member> <dest-name>
# Downloads a pinned release asset, verifies it, extracts <member> and installs
# it as ~/.local/bin/<dest-name>. Returns non-zero (after a warning) on failure.
_sec_install_bin() {
  local label=$1 key=$2 url=$3 kind=$4 member=$5 name=$6 tmp dest rc=0
  _sec_bin_dir
  dest="$HOME/.local/bin/$name"
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/hts-sec.XXXXXX")" || { warn "$label: could not create a temp directory"; return 1; }
  if ! _sec_download "$label" "$url" "$(_sec_pin "$key")" "$tmp/asset"; then
    rm -rf "$tmp"; return 1
  fi
  case "$kind" in
    tgz) tar -xzf "$tmp/asset" -C "$tmp" || rc=1 ;;
    zip) unzip -q -o "$tmp/asset" -d "$tmp" || rc=1 ;;
    gz)  gzip -dc "$tmp/asset" > "$tmp/$member" || rc=1 ;;
    *)   rc=1 ;;
  esac
  if [[ $rc -ne 0 || ! -f "$tmp/$member" ]]; then
    warn "$label: could not unpack the downloaded archive"
    rm -rf "$tmp"; return 1
  fi
  backup_file "$dest"
  if ! cp "$tmp/$member" "$dest" || ! chmod 0755 "$dest"; then
    warn "$label: could not write $dest"
    rm -rf "$tmp"; return 1
  fi
  rm -rf "$tmp"
  hts_track_file "$dest"
  hts_manifest_add tool "$name" "release-download"
  return 0
}

# _sec_write_wrapper <name> — write stdin to ~/.local/bin/<name> as an executable
_sec_write_wrapper() {
  local name=$1 dest
  _sec_bin_dir
  dest="$HOME/.local/bin/$name"
  backup_file "$dest"
  if cat > "$dest" && chmod 0755 "$dest"; then
    hts_track_file "$dest"
    hts_manifest_add tool "$name" "wrapper"
    return 0
  fi
  warn "Could not write $dest"
  return 1
}

# _sec_git_clone_tag <label> <repo-url> <tag> <dest-dir> [full]
# Shallow clone pinned to a release tag. Warns and returns 1 on any failure.
_sec_git_clone_tag() {
  local label=$1 url=$2 tag=$3 dest=$4
  if [[ -d "$dest/.git" ]]; then
    info "$label already cloned at $dest"
    return 0
  fi
  if [[ -d "$dest" && -n "$(ls -A "$dest" 2>/dev/null)" ]]; then
    warn "$label: $dest exists and is not a git clone — leaving it alone"
    return 1
  fi
  if ! _sec_have git; then
    warn "$label: git is not installed — cannot clone $url"
    return 1
  fi
  mkdir -p "$(dirname "$dest")" 2>/dev/null || true
  log "Cloning $label ($tag) to $dest..."
  if git clone --depth=1 --branch "$tag" "$url" "$dest"; then
    hts_track_file "$dest"
    hts_manifest_add tool "$label" "git-clone $tag"
    return 0
  fi
  warn "$label: git clone of $url ($tag) failed"
  return 1
}

# _sec_py_tool <pypi-package-or-pip-spec> <binary> [alt-binary]
# uv tool install, falling back to pipx. Unpinned (latest from PyPI).
_sec_py_tool() {
  local pkg=$1 bin=$2 alt=${3:-}
  if _sec_have "$bin" || { [[ -n "$alt" ]] && _sec_have "$alt"; }; then
    ok "$bin already installed"
    return 0
  fi
  _sec_bin_dir
  case "$pkg" in
    git+*) _sec_have git || { warn "$bin: git is required to install $pkg"; return 1; } ;;
  esac
  log "Installing $pkg..."
  if _sec_have uv && uv tool install "$pkg"; then
    hts_manifest_add tool "$pkg" "uv tool"
  elif _sec_have pipx; then
    pipx_install "$pkg"
  else
    warn "$pkg: neither uv nor pipx is available"
    return 1
  fi
  hash -r 2>/dev/null || true
  if ! _sec_have "$bin"; then
    warn "$bin not found after installing $pkg"
    return 1
  fi
  return 0
}

# _sec_pkg_or_go <package> <binary> <go-import-path@version>
# Distro/brew package when one is mapped, otherwise (or if it did not land) go install.
_sec_pkg_or_go() {
  local pkg=$1 bin=$2 gopkg=$3
  if _sec_have "$bin"; then ok "$bin already installed"; return 0; fi
  if [[ -n "$(resolve_pkg "$pkg")" ]]; then
    pkg_install "$pkg"
    hash -r 2>/dev/null || true
  fi
  if ! _sec_have "$bin"; then
    info "$bin: no usable $PKG_MGR package — falling back to go install"
    go_install "$gopkg" "$bin"
    hash -r 2>/dev/null || true
  fi
  if ! _sec_have "$bin"; then
    warn "$bin could not be installed"
    return 1
  fi
  return 0
}

# _sec_go_tool <go-import-path@version> <binary> — pinned go install, verified afterwards
_sec_go_tool() {
  local gopkg=$1 bin=$2
  if _sec_have "$bin"; then ok "$bin already installed"; return 0; fi
  go_install "$gopkg" "$bin"
  hash -r 2>/dev/null || true
  if ! _sec_have "$bin"; then
    warn "$bin could not be installed ($gopkg)"
    return 1
  fi
  return 0
}

# _sec_verify <label> <binary> [alt-binary...] — record a real result for the summary
_sec_verify() {
  local label=$1 first=$2 b
  shift
  for b in "$@"; do
    if _sec_have "$b"; then
      hts_verify_cmd "$label" "$b"
      return $?
    fi
  done
  hts_verify_cmd "$label" "$first"
}

# ─── Individual tools ────────────────────────────────────────────────────────

_sec_install_ligolo() {
  if _sec_have ligolo-proxy || _sec_have ligolo; then
    ok "Ligolo-ng already installed"
    return 0
  fi
  if ! _sec_platform; then warn "Ligolo-ng: unsupported platform $OS/$ARCH"; return 1; fi
  log "Installing Ligolo-ng proxy v${LIGOLO_VERSION}..."
  local url="https://github.com/nicocha30/ligolo-ng/releases/download/v${LIGOLO_VERSION}/ligolo-ng_proxy_${LIGOLO_VERSION}_${_SEC_OS_LC}_${_SEC_ARCH_LC}.tar.gz"
  _sec_install_bin "Ligolo-ng" LIGOLO "$url" tgz proxy ligolo-proxy || return 1
  ln -sf "$HOME/.local/bin/ligolo-proxy" "$HOME/.local/bin/ligolo" 2>/dev/null && hts_track_file "$HOME/.local/bin/ligolo"
  ok "Ligolo-ng installed to ~/.local/bin/ligolo-proxy (alias: ligolo)"
  return 0
}

_sec_install_chisel() {
  if _sec_have chisel; then
    ok "Chisel already installed: $(chisel --version 2>/dev/null || echo 'ready')"
    return 0
  fi
  log "Installing Chisel v${CHISEL_VERSION}..."
  if _sec_platform; then
    local url="https://github.com/jpillora/chisel/releases/download/v${CHISEL_VERSION}/chisel_${CHISEL_VERSION}_${_SEC_OS_LC}_${_SEC_ARCH_LC}.gz"
    if _sec_install_bin "Chisel" CHISEL "$url" gz chisel chisel; then
      ok "Chisel installed to ~/.local/bin/chisel"
      return 0
    fi
  else
    warn "Chisel: no prebuilt binary for $OS/$ARCH"
  fi
  # The Homebrew 'chisel' formula is an unrelated lldb helper, so only go install is used as a fallback.
  info "Chisel: falling back to go install"
  go_install "github.com/jpillora/chisel@v${CHISEL_VERSION}" chisel
  hash -r 2>/dev/null || true
  if ! _sec_have chisel; then warn "Chisel could not be installed"; return 1; fi
  return 0
}

_sec_install_responder() {
  local dir="$HOME/.local/share/Responder" rc=0
  if _sec_have responder; then
    ok "Responder already installed"
    return 0
  fi
  if [[ "$OS" == "Linux" && -n "$(resolve_pkg responder)" ]]; then
    pkg_install responder
    hash -r 2>/dev/null || true
    _sec_have responder && return 0
    info "Responder: no usable $PKG_MGR package — cloning lgandx/Responder instead"
  fi
  _sec_git_clone_tag "Responder" "https://github.com/lgandx/Responder.git" "$RESPONDER_TAG" "$dir" || return 1
  if [[ ! -x "$dir/.venv/bin/python" ]]; then
    if _sec_have python3 && python3 -m venv "$dir/.venv" \
       && "$dir/.venv/bin/pip" install -q -r "$dir/requirements.txt"; then
      :
    else
      warn "Responder: could not install its Python dependencies (aioquic, netifaces) into $dir/.venv"
      rc=1
    fi
  fi
  _sec_write_wrapper responder << 'RESP_RUNNER' || return 1
#!/usr/bin/env bash
d="$HOME/.local/share/Responder"
py=python3
[ -x "$d/.venv/bin/python" ] && py="$d/.venv/bin/python"
exec sudo "$py" "$d/Responder.py" "$@"
RESP_RUNNER
  ok "Responder runner installed to ~/.local/bin/responder"
  return $rc
}

# NetExec is not published on PyPI; upstream installs it from its git repository.
_sec_install_netexec() {
  _sec_py_tool "git+https://github.com/Pennyw0rth/NetExec@${NETEXEC_TAG}" nxc netexec
}

_sec_install_bloodhound_ce() {
  if _sec_have bloodhound-cli; then
    ok "BloodHound CE CLI already installed"
    return 0
  fi
  if ! _sec_platform; then warn "bloodhound-cli: unsupported platform $OS/$ARCH"; return 1; fi
  log "Installing BloodHound CE CLI v${BLOODHOUND_CLI_VERSION}..."
  local url="https://github.com/SpecterOps/bloodhound-cli/releases/download/v${BLOODHOUND_CLI_VERSION}/bloodhound-cli-${_SEC_OS_LC}-${_SEC_ARCH_LC}.tar.gz"
  _sec_install_bin "bloodhound-cli" BLOODHOUND_CLI "$url" tgz bloodhound-cli bloodhound-cli || return 1
  info "BloodHound CE itself runs in Docker and is not started by this installer."
  info "To start it (needs Docker + Docker Compose): bloodhound-cli install"
  return 0
}

install_ad_pivoting() {
  step "Internal Network, Active Directory & Pivoting Suite"
  local fail=0
  _sec_bin_dir

  _sec_install_ligolo        || fail=1   # 1. Ligolo-ng (Layer 3 TUN pivoting)
  _sec_install_chisel        || fail=1   # 2. Chisel (TCP/UDP tunnel over HTTP)
  _sec_install_netexec       || fail=1   # 3. NetExec (CrackMapExec successor)
  _sec_py_tool bloodhound bloodhound-python  || fail=1   # 4. BloodHound.py (legacy ingestor)
  _sec_py_tool bloodhound-ce bloodhound-ce-python || fail=1   # BloodHound CE ingestor
  _sec_install_bloodhound_ce || fail=1   # BloodHound CE CLI (launcher only)
  _sec_py_tool certipy-ad certipy            || fail=1   # 5. Certipy (AD CS auditing)
  _sec_install_responder     || fail=1   # 6. Responder (LLMNR/NBT-NS poisoner)

  _sec_verify "Ligolo-ng"            ligolo-proxy ligolo             || fail=1
  _sec_verify "Chisel"               chisel                           || fail=1
  _sec_verify "NetExec"              nxc netexec                      || fail=1
  _sec_verify "BloodHound.py"        bloodhound-python                || fail=1
  _sec_verify "BloodHound CE ingestor" bloodhound-ce-python           || fail=1
  _sec_verify "BloodHound CE CLI"    bloodhound-cli                   || fail=1
  _sec_verify "Certipy"              certipy                          || fail=1
  _sec_verify "Responder"            responder                        || fail=1

  if [[ $fail -ne 0 ]]; then
    warn "Active Directory & Pivoting suite finished with failures (see warnings above)"
    return 1
  fi
  ok "Active Directory & Pivoting suite complete"
  return 0
}
