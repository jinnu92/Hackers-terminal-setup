#!/usr/bin/env bash
# =============================================================================
#  lib/common.sh — Colors, Logging, and OS Detection
# =============================================================================

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m';     GREEN='\033[0;32m';    YELLOW='\033[1;33m'
CYAN='\033[0;36m';    BLUE='\033[0;34m';     MAGENTA='\033[0;35m'
PURPLE='\033[0;35m';  BOLD='\033[1m';        DIM='\033[2m'; RESET='\033[0m'

log()  { echo -e "${GREEN}[+]${RESET} $1"; }
info() { echo -e "${CYAN}[*]${RESET} $1"; }
warn() { echo -e "${YELLOW}[!]${RESET} $1"; }
err()  { echo -e "${RED}[-]${RESET} $1"; }
step() { echo -e "\n${BOLD}${CYAN}━━━ $1 ━━━${RESET}"; }
ok()   { echo -e "${GREEN}✓${RESET} $1"; }

# ─── Unattended & Non-Interactive Defaults ─────────────────────────────────────
# Prevent apt, Homebrew, npx, and scripts from halting for [y/n] or Enter prompts
export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"
export NONINTERACTIVE="${NONINTERACTIVE:-1}"
export HOMEBREW_NO_ENV_HINTS="${HOMEBREW_NO_ENV_HINTS:-1}"
export HOMEBREW_NO_AUTO_UPDATE="${HOMEBREW_NO_AUTO_UPDATE:-1}"
export CI="${CI:-true}"

# ─── OS Detection ─────────────────────────────────────────────────────────────
detect_os() {
  OS="$(uname -s)"
  ARCH="$(uname -m)"
  DISTRO=""
  PKG_MGR=""

  case "$OS" in
    Darwin)
      DISTRO="macOS"
      PKG_MGR="brew"
      ;;
    Linux)
      if   command -v apt-get &>/dev/null; then PKG_MGR="apt";    DISTRO="debian"
      elif command -v dnf     &>/dev/null; then PKG_MGR="dnf";    DISTRO="fedora"
      elif command -v yum     &>/dev/null; then PKG_MGR="yum";    DISTRO="rhel"
      elif command -v pacman  &>/dev/null; then PKG_MGR="pacman"; DISTRO="arch"
      elif command -v zypper  &>/dev/null; then PKG_MGR="zypper"; DISTRO="suse"
      else err "Unsupported Linux distro — no known package manager found"; exit 1
      fi
      ;;
    *)
      err "Unsupported OS: $OS"; exit 1 ;;
  esac

  echo -e "  ${CYAN}OS:${RESET}     $OS ($DISTRO)"
  echo -e "  ${CYAN}Arch:${RESET}   $ARCH"
  echo -e "  ${CYAN}PkgMgr:${RESET} $PKG_MGR"
}
