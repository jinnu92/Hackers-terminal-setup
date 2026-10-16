#!/usr/bin/env bash
# =============================================================================
#  lib/pkg_mgr.sh — Package Manager Abstraction & Distro Resolvers
# =============================================================================

pkg_update() {
  case "$PKG_MGR" in
    brew)   brew update ;;
    apt)    sudo apt-get update -qq ;;
    dnf)    sudo dnf check-update -q || true ;;
    yum)    sudo yum check-update -q || true ;;
    pacman) sudo pacman -Sy --noconfirm ;;
    zypper) sudo zypper refresh -q ;;
  esac
}

pkg_install() {
  local pkg
  for pkg in "$@"; do
    local resolved
    resolved="$(resolve_pkg "$pkg")"
    [[ -z "$resolved" ]] && { warn "No package mapping for '$pkg' on $DISTRO — skipping"; continue; }

    case "$PKG_MGR" in
      brew)
        if brew list "$resolved" &>/dev/null; then
          info "$resolved already installed"
        else
          brew install "$resolved" || warn "brew install $resolved failed"
        fi ;;
      apt)
        if dpkg -s "$resolved" &>/dev/null 2>&1; then
          info "$resolved already installed"
        else
          sudo apt-get install -y "$resolved" || warn "apt install $resolved failed"
        fi ;;
      dnf)    sudo dnf install -y "$resolved" || warn "dnf install $resolved failed" ;;
      yum)    sudo yum install -y "$resolved" || warn "yum install $resolved failed" ;;
      pacman) sudo pacman -S --noconfirm --needed "$resolved" || warn "pacman install $resolved failed" ;;
      zypper) sudo zypper install -y "$resolved" || warn "zypper install $resolved failed" ;;
    esac
  done
}

pkg_install_cask() {
  local pkg=$1
  local linux_snap=${2:-}
  local linux_deb=${3:-}

  if [[ "$OS" == "Darwin" ]]; then
    if brew list --cask "$pkg" &>/dev/null; then
      info "$pkg (cask) already installed"
    else
      brew install --cask "$pkg" || warn "cask install $pkg failed"
    fi
  else
    if [[ -n "$linux_snap" ]] && command -v snap &>/dev/null; then
      sudo snap install "$linux_snap" --classic 2>/dev/null || warn "snap install $linux_snap failed"
    elif [[ -n "$linux_deb" ]]; then
      warn "$pkg: install manually from $linux_deb"
    else
      warn "$pkg: macOS cask only — no Linux equivalent configured"
    fi
  fi
}

resolve_pkg() {
  local pkg=$1
  case "$PKG_MGR" in
    brew)
      case "$pkg" in
        bat)          echo "bat" ;;
        fd)           echo "fd" ;;
        netcat)       echo "netcat" ;;
        node)         echo "node" ;;
        npm)          echo "node" ;;
        golang|go)    echo "go" ;;
        fontconfig)   echo "fontconfig" ;;
        xz)           echo "xz" ;;
        unzip)        echo "unzip" ;;
        tar)          echo "gnu-tar" ;;
        atuin)        echo "atuin" ;;
        direnv)       echo "direnv" ;;
        uv)           echo "uv" ;;
        btop)         echo "btop" ;;
        starship)     echo "starship" ;;
        fastfetch)    echo "fastfetch" ;;
        trivy)        echo "trivy" ;;
        jadx)         echo "jadx" ;;
        apktool)      echo "apktool" ;;
        syft)         echo "syft" ;;
        grype)        echo "grype" ;;
        chisel)       echo "chisel" ;;
        ligolo-ng)    echo "ligolo-ng" ;;
        *)            echo "$pkg" ;;
      esac ;;
    apt)
      case "$pkg" in
        bat)          echo "bat" ;;        # binary is 'batcat' on Ubuntu
        fd)           echo "fd-find" ;;   # binary is 'fdfind'
        eza)          echo "eza" ;;
        zoxide)       echo "zoxide" ;;
        netcat)       echo "netcat-openbsd" ;;
        httpie)       echo "httpie" ;;
        git-delta)    echo "git-delta" ;;
        tmux)         echo "tmux" ;;
        fzf)          echo "fzf" ;;
        ripgrep)      echo "ripgrep" ;;
        tldr)         echo "tldr" ;;
        jq)           echo "jq" ;;
        yq)           echo "" ;;
        lazygit)      echo "" ;;
        gh)           echo "gh" ;;
        pandoc)       echo "pandoc" ;;
        nmap)         echo "nmap" ;;
        hydra)        echo "hydra" ;;
        sqlmap)       echo "sqlmap" ;;
        masscan)      echo "masscan" ;;
        tcpdump)      echo "tcpdump" ;;
        openssl)      echo "openssl" ;;
        gpg)          echo "gnupg" ;;
        python3)      echo "python3" ;;
        pipx)         echo "pipx" ;;
        python3-venv) echo "python3-venv" ;;
        python3-pip)  echo "python3-pip" ;;
        wget)         echo "wget" ;;
        curl)         echo "curl" ;;
        mitmproxy)    echo "mitmproxy" ;;
        nikto)        echo "nikto" ;;
        gobuster)     echo "gobuster" ;;
        ffuf)         echo "" ;;
        nuclei)       echo "" ;;
        amass)        echo "" ;;
        subfinder)    echo "" ;;
        httpx)        echo "" ;;
        katana)       echo "" ;;
        dnsx)         echo "" ;;
        gau)          echo "" ;;
        dalfox)       echo "" ;;
        feroxbuster)  echo "feroxbuster" ;;
        semgrep)      echo "" ;;
        gitleaks)     echo "" ;;
        trufflehog)   echo "" ;;
        awscli)       echo "awscli" ;;
        node)         echo "nodejs" ;;
        npm)          echo "npm" ;;
        golang|go)    echo "golang-go" ;;
        fontconfig)   echo "fontconfig" ;;
        xz)           echo "xz-utils" ;;
        unzip)        echo "unzip" ;;
        tar)          echo "tar" ;;
        yazi)         echo "" ;;
        xh)           echo "" ;;
        john)         echo "john" ;;
        hashcat)      echo "hashcat" ;;
        wireshark-cli) echo "tshark" ;;
        seclists)     echo "" ;;
        btop)         echo "btop" ;;
        direnv)       echo "direnv" ;;
        atuin)        echo "" ;;          # installed via install script
        starship)     echo "" ;;          # installed via install script
        uv)           echo "" ;;          # installed via astral.sh script
        fastfetch)    echo "fastfetch" ;;
        trivy)        echo "trivy" ;;
        jadx)         echo "jadx" ;;
        apktool)      echo "apktool" ;;
        responder)    echo "responder" ;;
        chisel)       echo "chisel" ;;
        *)            echo "$pkg" ;;
      esac ;;
    dnf|yum)
      case "$pkg" in
        bat)          echo "bat" ;;
        fd)           echo "fd-find" ;;
        netcat)       echo "nmap-ncat" ;;
        gpg)          echo "gnupg2" ;;
        awscli)       echo "awscli" ;;
        node)         echo "nodejs" ;;
        npm)          echo "npm" ;;
        golang|go)    echo "golang" ;;
        fontconfig)   echo "fontconfig" ;;
        xz)           echo "xz" ;;
        unzip)        echo "unzip" ;;
        tar)          echo "tar" ;;
        btop)         echo "btop" ;;
        direnv)       echo "direnv" ;;
        starship)     echo "starship" ;;
        fastfetch)    echo "fastfetch" ;;
        trivy)        echo "trivy" ;;
        *)            echo "$pkg" ;;
      esac ;;
    pacman)
      case "$pkg" in
        netcat)       echo "openbsd-netcat" ;;
        gpg)          echo "gnupg" ;;
        awscli)       echo "aws-cli" ;;
        fd)           echo "fd" ;;
        node)         echo "nodejs" ;;
        npm)          echo "npm" ;;
        golang|go)    echo "go" ;;
        fontconfig)   echo "fontconfig" ;;
        xz)           echo "xz" ;;
        unzip)        echo "unzip" ;;
        tar)          echo "tar" ;;
        btop)         echo "btop" ;;
        yazi)         echo "yazi" ;;
        direnv)       echo "direnv" ;;
        atuin)        echo "atuin" ;;
        starship)     echo "starship" ;;
        uv)           echo "uv" ;;
        fastfetch)    echo "fastfetch" ;;
        trivy)        echo "trivy" ;;
        jadx)         echo "jadx" ;;
        apktool)      echo "android-apktool" ;;
        *)            echo "$pkg" ;;
      esac ;;
    zypper)
      case "$pkg" in
        golang|go)    echo "go" ;;
        node)         echo "nodejs" ;;
        npm)          echo "npm" ;;
        fontconfig)   echo "fontconfig" ;;
        xz)           echo "xz" ;;
        unzip)        echo "unzip" ;;
        tar)          echo "tar" ;;
        btop)         echo "btop" ;;
        direnv)       echo "direnv" ;;
        *)            echo "$pkg" ;;
      esac ;;
    *)            echo "$pkg" ;;
  esac
}

linux_fixups() {
  [[ "$OS" != "Linux" ]] && return
  if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
    ok "bat symlinked from batcat"
  fi
  if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    ok "fd symlinked from fdfind"
  fi
}
