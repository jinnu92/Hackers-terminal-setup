#!/usr/bin/env bash
# =============================================================================
#  lib/pkg_mgr.sh — Package Manager Abstraction & Distro Resolvers
# =============================================================================

# Exit status used by resolve_pkg/pkg_install when a tool has no package on the
# active package manager, so callers can fall back to a direct install.
HTS_PKG_UNMAPPED=3
_HTS_PKG_REFRESHED=0

# _sudo <command...> — run privileged: directly when already root, through sudo
# otherwise, and fail loudly when neither is possible.
_sudo() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  elif command -v sudo &>/dev/null; then
    sudo "$@"
  else
    err "Need root privileges to run '$1' but sudo is not installed (re-run as root)"
    return 1
  fi
}

# _sudo_interp — print the interpreter prefix for hts_run_remote_script when the
# script must run privileged: "bash" as root, "sudo -E bash" otherwise.
_sudo_interp() {
  if [[ "$(id -u)" -eq 0 ]]; then
    echo "bash"
  elif command -v sudo &>/dev/null; then
    echo "sudo -E bash"
  else
    err "Need root privileges but sudo is not installed (re-run as root)"
    return 1
  fi
}

# pkg_update — refresh the package index once per run (guarded). Safe to call
# from several places; only the first call does any work.
pkg_update() {
  [[ "$_HTS_PKG_REFRESHED" == "1" ]] && return 0
  _HTS_PKG_REFRESHED=1
  case "$PKG_MGR" in
    brew)   brew update || warn "brew update failed (continuing)" ;;
    apt)    _sudo apt-get update -qq || warn "apt-get update failed (continuing)" ;;
    dnf)    _sudo dnf makecache -q || warn "dnf makecache failed (continuing)" ;;
    yum)    _sudo yum makecache -q || warn "yum makecache failed (continuing)" ;;
    pacman)
      # -Sy alone leaves Arch in an unsupported partial-upgrade state; sync
      # and upgrade together so later installs resolve against a coherent set.
      warn "Arch: running a full system upgrade (pacman -Syu) so packages install safely"
      _sudo pacman -Syu --noconfirm || warn "pacman -Syu failed (continuing)" ;;
    zypper) _sudo zypper --non-interactive refresh -q || warn "zypper refresh failed (continuing)" ;;
  esac
  return 0
}

# Lazy refresh before the first install on any path.
pkg_refresh_once() { pkg_update; }

# _pkg_is_installed <resolved-name> — is it already present on this system?
_pkg_is_installed() {
  case "$PKG_MGR" in
    brew)             brew list "$1" &>/dev/null ;;
    apt)              dpkg -s "$1" &>/dev/null ;;
    dnf|yum|zypper)   rpm -q "$1" &>/dev/null ;;
    pacman)           pacman -Q "$1" &>/dev/null ;;
    *)                return 1 ;;
  esac
}

# _pkg_run_install <resolved-name>
_pkg_run_install() {
  case "$PKG_MGR" in
    brew)   brew install "$1" ;;
    apt)    _sudo apt-get install -y "$1" ;;
    dnf)    _sudo dnf install -y "$1" ;;
    yum)    _sudo yum install -y "$1" ;;
    pacman) _sudo pacman -S --noconfirm --needed "$1" ;;
    zypper) _sudo zypper --non-interactive install -y "$1" ;;
    *)      return 1 ;;
  esac
}

# pkg_install <tool...> — returns 0 when every tool is present afterwards,
# 1 when an install failed, 3 (HTS_PKG_UNMAPPED) when a tool has no package on
# this package manager and nothing else failed.
pkg_install() {
  local pkg resolved rc any_fail=0 any_unmapped=0
  for pkg in "$@"; do
    rc=0
    resolved="$(resolve_pkg "$pkg")" || rc=$?
    if [[ $rc -ne 0 || -z "$resolved" ]]; then
      any_unmapped=1
      continue
    fi

    if _pkg_is_installed "$resolved"; then
      info "$resolved already installed"
      continue
    fi

    pkg_refresh_once
    if _pkg_run_install "$resolved"; then
      hts_manifest_add tool "$resolved" "$PKG_MGR"
    else
      warn "$PKG_MGR install $resolved failed"
      any_fail=1
    fi
  done
  [[ $any_fail -eq 1 ]] && return 1
  [[ $any_unmapped -eq 1 ]] && return "$HTS_PKG_UNMAPPED"
  return 0
}

pkg_install_cask() {
  local pkg=$1
  local linux_snap=${2:-}
  local linux_deb=${3:-}

  if [[ "$OS" == "Darwin" ]]; then
    if brew list --cask "$pkg" &>/dev/null; then
      info "$pkg (cask) already installed"
    else
      pkg_refresh_once
      if brew install --cask "$pkg"; then
        hts_manifest_add tool "$pkg" "brew-cask"
      else
        warn "cask install $pkg failed"
        return 1
      fi
    fi
  else
    if [[ -n "$linux_snap" ]] && command -v snap &>/dev/null; then
      if _sudo snap install "$linux_snap" --classic 2>/dev/null; then
        hts_manifest_add tool "$linux_snap" "snap"
      else
        warn "snap install $linux_snap failed"
        return 1
      fi
    elif [[ -n "$linux_deb" ]]; then
      warn "$pkg: install manually from $linux_deb"
      return 1
    else
      warn "$pkg: macOS cask only — no Linux equivalent configured"
      return 1
    fi
  fi
  return 0
}

# resolve_pkg <tool> — print the package name for the active package manager.
# Prints nothing and returns HTS_PKG_UNMAPPED (3) when there is no package, so
# callers can fall back to a direct download. The warning goes to stderr so it
# is not captured by "$(resolve_pkg x)".
resolve_pkg() {
  local pkg=$1 name=""
  case "$PKG_MGR" in
    brew)
      case "$pkg" in
        tar)            name="gnu-tar" ;;
        npm|node)       name="node" ;;
        golang|go)      name="go" ;;
        gpg)            name="gnupg" ;;
        wireshark-cli)  name="wireshark" ;;
        python3-venv|python3-pip) name="python" ;;
        python3)        name="python" ;;
        *)              name="$pkg" ;;
      esac ;;
    apt)
      case "$pkg" in
        fd)             name="fd-find" ;;       # binary is 'fdfind'
        netcat)         name="netcat-openbsd" ;;
        gpg)            name="gnupg" ;;
        node)           name="nodejs" ;;
        golang|go)      name="golang-go" ;;
        xz)             name="xz-utils" ;;
        wireshark-cli)  name="tshark" ;;
        # Not in Debian/Ubuntu archives (or too old/wrong): callers fall back
        yq|lazygit|ffuf|nuclei|subfinder|httpx|katana|dnsx|gau|dalfox) name="" ;;
        semgrep|gitleaks|trufflehog|yazi|xh|seclists|atuin|starship|uv) name="" ;;
        trivy|feroxbuster|responder|ligolo-ng|kubescape|osv-scanner) name="" ;;
        *)              name="$pkg" ;;
      esac ;;
    dnf|yum)
      case "$pkg" in
        fd)             name="fd-find" ;;
        netcat)         name="nmap-ncat" ;;
        gpg)            name="gnupg2" ;;
        node)           name="nodejs" ;;
        golang|go)      name="golang" ;;
        wireshark-cli)  name="wireshark-cli" ;;
        python3-venv)   name="python3" ;;       # venv ships in python3 on RPM distros
        # Not in the stock Fedora/RHEL repos
        lazygit|ffuf|nuclei|subfinder|httpx|katana|dnsx|gau|dalfox) name="" ;;
        semgrep|gitleaks|trufflehog|yazi|xh|seclists|responder|chisel) name="" ;;
        trivy|feroxbuster|ligolo-ng|kubescape|osv-scanner)  name="" ;;
        *)              name="$pkg" ;;
      esac ;;
    pacman)
      case "$pkg" in
        netcat)         name="openbsd-netcat" ;;
        gpg)            name="gnupg" ;;
        awscli)         name="aws-cli" ;;
        node)           name="nodejs" ;;
        golang|go)      name="go" ;;
        apktool)        name="android-apktool" ;;
        python3)        name="python" ;;
        python3-pip)    name="python-pip" ;;
        python3-venv)   name="python" ;;        # venv is part of the python package
        pipx)           name="python-pipx" ;;
        git-delta)      name="git-delta" ;;
        httpx)          name="" ;;              # 'httpx' on Arch is the Python library
        *)              name="$pkg" ;;
      esac ;;
    zypper)
      case "$pkg" in
        golang|go)      name="go" ;;
        node)           name="nodejs" ;;
        netcat)         name="netcat-openbsd" ;;
        gpg)            name="gpg2" ;;
        awscli)         name="aws-cli" ;;
        wireshark-cli)  name="wireshark" ;;
        python3-venv)   name="python3-virtualenv" ;;
        python3-pip)    name="python3-pip" ;;
        pipx)           name="python3-pipx" ;;
        lazygit|ffuf|nuclei|subfinder|httpx|katana|dnsx|gau|dalfox) name="" ;;
        semgrep|gitleaks|trufflehog|yazi|xh|seclists|responder|chisel) name="" ;;
        trivy|feroxbuster|ligolo-ng|kubescape|osv-scanner)  name="" ;;
        *)              name="$pkg" ;;
      esac ;;
    *)                  name="$pkg" ;;
  esac

  if [[ -z "$name" ]]; then
    warn "no $PKG_MGR package for $pkg" >&2
    return "$HTS_PKG_UNMAPPED"
  fi
  echo "$name"
}

# _hts_arch — print amd64 or arm64 for the running CPU (empty + status 1 otherwise).
_hts_arch() {
  case "$(uname -m)" in
    x86_64|amd64)  echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *) return 1 ;;
  esac
}

# _install_release_bin <name> <url> <sha256> [dest-dir]
# Download a single pinned binary with digest verification into ~/.local/bin
# (or dest-dir), mark it executable, and record it. Non-zero on any failure.
_install_release_bin() {
  local name=$1 url=$2 sha=$3 dest_dir=${4:-$HOME/.local/bin}
  [[ -n "$sha" ]] || { warn "$name: no pinned digest for this platform"; return 1; }
  mkdir -p "$dest_dir" || return 1
  if hts_download_verify "$url" "$sha" "$dest_dir/$name" && chmod +x "$dest_dir/$name"; then
    hts_track_file "$dest_dir/$name"
    hts_manifest_add tool "$name" "release-binary"
    return 0
  fi
  rm -f "$dest_dir/$name"
  warn "$name install failed"
  return 1
}

linux_fixups() {
  [[ "$OS" != "Linux" ]] && return 0
  if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
    hts_track_file "$HOME/.local/bin/bat"
    ok "bat symlinked from batcat"
  fi
  if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    hts_track_file "$HOME/.local/bin/fd"
    ok "fd symlinked from fdfind"
  fi
  return 0
}
