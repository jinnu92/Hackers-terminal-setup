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

# ─── Version, State, Log, Manifest ───────────────────────────────────────────
HTS_VERSION="2.1.1"
HTS_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hts"
HTS_LOG="$HTS_STATE_DIR/install.log"
HTS_MANIFEST="$HTS_STATE_DIR/manifest.tsv"
HTS_BACKUP_ROOT="$HTS_STATE_DIR/backups"
HTS_RUN_TS="$(date +%Y%m%d_%H%M%S)"   # one timestamp per installer run
HTS_DRY_RUN=0
HTS_BACKED_UP=""                      # newline-separated paths already backed up this run

# Results table (parallel arrays; bash 3.2 safe — no associative arrays)
HTS_RES_STATUS=()
HTS_RES_LABEL=()
HTS_RES_NOTE=()

# Create state directory, log and manifest. Called once at the start of a real run.
hts_state_init() {
  [[ "${_HTS_STATE_READY:-0}" == "1" ]] && return 0
  mkdir -p "$HTS_STATE_DIR" "$HTS_BACKUP_ROOT" || return 1
  _HTS_STATE_READY=1
  touch "$HTS_LOG" "$HTS_MANIFEST" 2>/dev/null || true
  printf '\n===== Hackers Terminal Setup %s run %s =====\n' "$HTS_VERSION" "$HTS_RUN_TS" >> "$HTS_LOG" 2>/dev/null || true
  return 0
}

# hts_manifest_add <kind> <name> [detail]  — kinds: component, tool, file, backup
hts_manifest_add() {
  local kind=${1:-} name=${2:-} detail=${3:-}
  mkdir -p "$HTS_STATE_DIR" 2>/dev/null || return 0
  printf '%s\t%s\t%s\t%s\n' "$(date +%s)" "$kind" "$name" "$detail" >> "$HTS_MANIFEST" 2>/dev/null || true
  return 0
}

# hts_result <ok|fail|skip> <label> [note]
hts_result() {
  HTS_RES_STATUS[${#HTS_RES_STATUS[@]}]="$1"
  HTS_RES_LABEL[${#HTS_RES_LABEL[@]}]="$2"
  HTS_RES_NOTE[${#HTS_RES_NOTE[@]}]="${3:-}"
  return 0
}

# run_step <label> <command> [args...]
# Runs a function or program in the CURRENT shell (so PATH/exports persist), tees
# its output into $HTS_LOG, never aborts the script, records ok/fail, returns the
# command's exit status. errexit is suspended inside the step so one failing
# command cannot kill the whole run; steps signal failure by returning non-zero.
run_step() {
  local label=$1; shift
  local logf="$HTS_LOG" rc=0 start=$SECONDS fifo="" tpid=""
  [[ -d "$HTS_STATE_DIR" ]] || logf=/dev/null
  printf '\n--- [%s] %s ---\n' "$(date '+%H:%M:%S')" "$label" >> "$logf" 2>/dev/null || true

  fifo="$(mktemp -u "${TMPDIR:-/tmp}/hts-fifo.XXXXXX")"
  if mkfifo "$fifo" 2>/dev/null; then
    tee -a "$logf" < "$fifo" &
    tpid=$!
    set +e
    "$@" > "$fifo" 2>&1
    rc=$?
    set -e
    wait "$tpid" 2>/dev/null || true
    rm -f "$fifo"
  else
    set +e
    "$@"
    rc=$?
    set -e
  fi

  local dur=$((SECONDS - start))
  if [[ $rc -eq 0 ]]; then
    hts_result ok "$label" "${dur}s"
  else
    hts_result fail "$label" "exit $rc after ${dur}s"
  fi
  return "$rc"
}

# hts_verify_cmd <label> <binary>
hts_verify_cmd() {
  if command -v "$2" &>/dev/null; then
    hts_result ok "$1" "$2 found"
    return 0
  fi
  hts_result fail "$1" "not found after install"
  return 1
}

# _hts_manifest_has <kind> <name> — true when the manifest has such a line
_hts_manifest_has() {
  [[ -n "${HTS_MANIFEST:-}" && -f "$HTS_MANIFEST" ]] || return 1
  awk -F '\t' -v k="$1" -v n="$2" '$2 == k && $3 == n { found = 1 } END { exit !found }' "$HTS_MANIFEST"
}

# backup_file <path> — copy an existing file/symlink to the per-run backup dir.
# Once per run per path. Always returns 0.
backup_file() {
  local src=${1:-} rel dest
  [[ -n "$src" ]] || return 0
  if [[ ! -f "$src" && ! -L "$src" ]]; then
    return 0
  fi
  # A path the manifest records as created by this tool, with no earlier backup,
  # never belonged to the user: there is nothing of theirs to preserve.
  if _hts_manifest_has file "$src" && ! _hts_manifest_has backup "$src"; then
    return 0
  fi
  case "$HTS_BACKED_UP" in
    *$'\n'"$src"$'\n'*) return 0 ;;
  esac
  HTS_BACKED_UP="${HTS_BACKED_UP}"$'\n'"$src"$'\n'

  case "$src" in
    "$HOME"/*) rel="${src#"$HOME"/}" ;;
    *)         rel="${src#/}" ;;
  esac
  dest="$HTS_BACKUP_ROOT/$HTS_RUN_TS/$rel"
  if mkdir -p "$(dirname "$dest")" 2>/dev/null && cp -pP "$src" "$dest" 2>/dev/null; then
    hts_manifest_add backup "$src" "$dest"
    info "Backed up $src -> $dest"
  else
    warn "Could not back up $src (continuing)"
  fi
  return 0
}

# hts_track_file <path> — record a file the installer created or rewrote
hts_track_file() {
  hts_manifest_add file "${1:-}" ""
  return 0
}

# hts_fetch <url> <dest> — curl with retries and timeout; no partial file on failure
hts_fetch() {
  local url=$1 dest=$2 tmp
  tmp="${dest}.part.$$"
  if curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 300 -o "$tmp" "$url"; then
    mv -f "$tmp" "$dest" || { rm -f "$tmp"; return 1; }
    return 0
  fi
  rm -f "$tmp" 2>/dev/null
  return 1
}

# hts_sha256 <file> — print hex digest
hts_sha256() {
  if command -v sha256sum &>/dev/null; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum &>/dev/null; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    err "No sha256sum or shasum available"
    return 1
  fi
}

# hts_download_verify <url> <sha256> <dest>
hts_download_verify() {
  local url=$1 want actual dest=$3
  want="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"
  hts_fetch "$url" "$dest" || { err "Download failed: $url"; return 1; }
  actual="$(hts_sha256 "$dest")" || { rm -f "$dest"; return 1; }
  if [[ "$actual" != "$want" ]]; then
    rm -f "$dest"
    err "SHA-256 mismatch for $url (expected $want, got $actual)"
    return 1
  fi
  return 0
}

# hts_run_remote_script <url> <interpreter> [args...]
# Downloads first, fails loudly if the download fails or is empty, then runs
# "<interpreter> <tempfile> [args...]". The interpreter may be a quoted multi-word
# string such as "sudo bash" or "env RUNZSH=no CHSH=no sh".
hts_run_remote_script() {
  local url=$1 interp_str=$2; shift 2
  local tmp rc=0
  local -a interp
  read -r -a interp <<< "$interp_str"
  [[ ${#interp[@]} -gt 0 ]] || { err "hts_run_remote_script: no interpreter given"; return 1; }
  tmp="$(mktemp "${TMPDIR:-/tmp}/hts-remote.XXXXXX")" || return 1
  if ! hts_fetch "$url" "$tmp"; then
    rm -f "$tmp"; err "Download failed: $url"; return 1
  fi
  if [[ ! -s "$tmp" ]]; then
    rm -f "$tmp"; err "Downloaded script is empty: $url"; return 1
  fi
  chmod 644 "$tmp" 2>/dev/null || true
  "${interp[@]}" "$tmp" "$@" || rc=$?
  rm -f "$tmp"
  return "$rc"
}

# hts_print_summary — table of results; returns 1 if any row failed
hts_print_summary() {
  local i n=${#HTS_RES_STATUS[@]} nok=0 nfail=0 nskip=0 mark
  echo ""
  echo -e "${BOLD}${CYAN}━━━ Summary ━━━${RESET}"
  for ((i = 0; i < n; i++)); do
    case "${HTS_RES_STATUS[$i]}" in
      ok)   mark="${GREEN}OK  ${RESET}"; nok=$((nok + 1)) ;;
      fail) mark="${RED}FAIL${RESET}"; nfail=$((nfail + 1)) ;;
      *)    mark="${YELLOW}SKIP${RESET}"; nskip=$((nskip + 1)) ;;
    esac
    printf '  %b  %-44s %s\n' "$mark" "${HTS_RES_LABEL[$i]}" "${HTS_RES_NOTE[$i]}"
  done
  echo ""
  echo -e "  ${GREEN}ok: $nok${RESET}   ${RED}failed: $nfail${RESET}   ${YELLOW}skipped: $nskip${RESET}"
  [[ -d "$HTS_STATE_DIR" ]] && echo -e "  ${DIM}Log: $HTS_LOG${RESET}"
  [[ $nfail -eq 0 ]]
}

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
