#!/usr/bin/env bash
# =============================================================================
#  lib/ad_pivoting.sh — Internal Network, Active Directory & Pivoting Tools
#  Includes: Ligolo-ng, Chisel, NetExec (nxc), BloodHound, Responder, Certipy
# =============================================================================

install_ad_pivoting() {
  step "Internal Network, Active Directory & Pivoting Suite"

  # 1. Ligolo-ng (Modern Layer 3 TUN-interface pivoting)
  if ! command -v ligolo-proxy &>/dev/null && ! command -v ligolo &>/dev/null; then
    log "Installing Ligolo-ng proxy..."
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install ligolo-ng 2>/dev/null || {
        local tmpdir
        tmpdir=$(mktemp -d)
        local arch="arm64"
        [[ "$ARCH" != "arm64" ]] && arch="amd64"
        curl -fsSL "https://github.com/nicocha30/ligolo-ng/releases/latest/download/ligolo-ng_proxy_0.6.2_darwin_${arch}.tar.gz" -o "$tmpdir/ligolo.tar.gz" 2>/dev/null || true
        if [[ -f "$tmpdir/ligolo.tar.gz" ]]; then
          tar -xzf "$tmpdir/ligolo.tar.gz" -C "$HOME/.local/bin" 2>/dev/null || true
          chmod +x "$HOME/.local/bin/proxy" 2>/dev/null || true
          ln -sf "$HOME/.local/bin/proxy" "$HOME/.local/bin/ligolo" 2>/dev/null || true
          ok "Ligolo-ng installed to ~/.local/bin/ligolo"
        fi
        rm -rf "$tmpdir"
      }
    else
      local tmpdir
      tmpdir=$(mktemp -d)
      local arch="amd64"
      [[ "$ARCH" == "aarch64" ]] && arch="arm64"
      curl -fsSL "https://github.com/nicocha30/ligolo-ng/releases/latest/download/ligolo-ng_proxy_0.6.2_linux_${arch}.tar.gz" -o "$tmpdir/ligolo.tar.gz" 2>/dev/null || true
      if [[ -f "$tmpdir/ligolo.tar.gz" ]]; then
        tar -xzf "$tmpdir/ligolo.tar.gz" -C "$HOME/.local/bin" 2>/dev/null || true
        chmod +x "$HOME/.local/bin/proxy" 2>/dev/null || true
        ln -sf "$HOME/.local/bin/proxy" "$HOME/.local/bin/ligolo" 2>/dev/null || true
        ok "Ligolo-ng installed to ~/.local/bin/ligolo"
      fi
      rm -rf "$tmpdir"
    fi
  else
    ok "Ligolo-ng already installed"
  fi

  # 2. Chisel (Fast TCP/UDP tunnel over HTTP/WebSockets)
  if ! command -v chisel &>/dev/null; then
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install chisel
    else
      go_install "github.com/jpillora/chisel@latest" chisel
    fi
  else
    ok "Chisel already installed: $(chisel --version 2>/dev/null || echo 'ready')"
  fi

  # 3. NetExec (nxc — modern CrackMapExec successor)
  if ! command -v nxc &>/dev/null && ! command -v netexec &>/dev/null; then
    log "Installing NetExec (nxc)..."
    if command -v uv &>/dev/null; then
      uv tool install netexec || pipx_install netexec
    else
      pipx_install netexec
    fi
  else
    ok "NetExec already installed"
  fi

  # 4. BloodHound Python & RustHound-CE
  if ! command -v bloodhound-python &>/dev/null; then
    log "Installing BloodHound-python..."
    if command -v uv &>/dev/null; then
      uv tool install bloodhound || pipx_install bloodhound
    else
      pipx_install bloodhound
    fi
  else
    ok "BloodHound-python already installed"
  fi

  # 5. Certipy (Active Directory Certificate Services AD CS auditing)
  if ! command -v certipy &>/dev/null; then
    log "Installing Certipy..."
    if command -v uv &>/dev/null; then
      uv tool install certipy-ad || pipx_install certipy-ad
    else
      pipx_install certipy-ad
    fi
  else
    ok "Certipy already installed"
  fi

  # 6. Responder (LLMNR/NBT-NS Poisoner)
  if [[ "$OS" == "Linux" ]]; then
    pkg_install responder
  else
    if [[ ! -d "$HOME/.local/share/Responder" ]]; then
      log "Cloning Responder to ~/.local/share/Responder..."
      git clone --depth=1 https://github.com/lgandx/Responder.git "$HOME/.local/share/Responder" 2>/dev/null || true
      cat > "$HOME/.local/bin/responder" << 'RESP_RUNNER'
#!/usr/bin/env bash
sudo python3 "$HOME/.local/share/Responder/Responder.py" "$@"
RESP_RUNNER
      chmod +x "$HOME/.local/bin/responder"
      ok "Responder runner installed to ~/.local/bin/responder"
    fi
  fi

  ok "Active Directory & Pivoting suite complete"
}
