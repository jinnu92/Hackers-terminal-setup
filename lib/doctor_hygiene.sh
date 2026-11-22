#!/usr/bin/env bash
# =============================================================================
#  lib/doctor_hygiene.sh — Doctor: config & hygiene checks (read-only)
#
#  Sourced after lib/doctor.sh (uses _doc_hyg). Reads config files and runs
#  read-only probes only: no installs, no writes.
# =============================================================================

_DOC_SECRET_RE='^(ghp_|gho_|ghu_|ghs_|ghr_|github_pat_|BSA|sk-|xox[abp]-|AKIA)[A-Za-z0-9_./+=-]{16,}$'

_doc_mcp_pkg() { # file label package-token  (npm or uvx package argument)
  local f=$1 lbl=$2 t=$3 base
  base=$t
  [[ "${t:1}" == *@* ]] && base="${t%@*}"
  case "$base" in
    @modelcontextprotocol/server-github)
      _doc_hyg warn "$lbl" "uses server-github, which is deprecated and archived" \
        "switch to GitHub's official github-mcp-server" ;;
    @modelcontextprotocol/server-brave-search)
      _doc_hyg warn "$lbl" "uses server-brave-search, which is deprecated and archived" \
        "switch to Brave's maintained MCP server (@brave/brave-search-mcp-server)" ;;
    @modelcontextprotocol/server-fetch)
      _doc_hyg warn "$lbl" "server-fetch does not exist on npm" \
        "use the Python mcp-server-fetch via uvx with a pinned version" ;;
  esac
  return 0
}

_doc_mcp_pin() { # label kind(npx|uvx) package
  local lbl=$1 kind=$2 p=$3 ver=""
  [[ "${p:1}" == *@* ]] && ver="${p##*@}"
  [[ "$kind" == "uvx" && "$p" == *==* ]] && ver="${p##*==}"
  if [[ -z "$ver" || "$ver" == "latest" ]]; then
    _doc_hyg warn "$lbl" "$kind launches $p unpinned" "pin a version, e.g. ${p%%@latest}@<version>"
  fi
  return 0
}

_doc_mcp_path() { # label path
  local lbl=$1 p=$2 h="${HOME%/}"
  case "$p" in
    /|"~"|"~/"|'$HOME'|'$HOME/'|'${HOME}'|'${HOME}/')
      _doc_hyg warn "$lbl" "filesystem server is allowed the whole home or root ($p)" \
        "list only project directories such as ~/workspace" ;;
    *)
      if [[ "${p%/}" == "$h" ]]; then
        _doc_hyg warn "$lbl" "filesystem server is allowed your entire home directory" \
          "list only project directories such as ~/workspace"
      fi ;;
  esac
  return 0
}

_doc_scan_mcp() { # file label
  local f=$1 lbl=$2 t mode="" before pair key val n0 n1
  local keyre='(KEY|TOKEN|SECRET|PASSW|AUTH)'
  if [[ ! -f "$f" ]]; then _doc_hyg skip "$lbl" "not present" ""; return 0; fi
  n0=${#_DH_ST[@]}
  while IFS= read -r t; do
    t="${t#\"}"; t="${t%\"}"
    case "$mode" in
      npx|uvx)
        case "$t" in
          args) continue ;;
          --from) mode="${mode}from"; continue ;;
          -*) continue ;;
        esac
        _doc_mcp_pkg "$f" "$lbl" "$t"; _doc_mcp_pin "$lbl" "$mode" "$t"
        case "$t" in *server-filesystem*) mode=fs ;; *) mode="" ;; esac
        continue ;;
      npxfrom|uvxfrom)
        _doc_mcp_pkg "$f" "$lbl" "$t"; _doc_mcp_pin "$lbl" "${mode%from}" "$t"; mode=""; continue ;;
      fs)
        case "$t" in
          /*|"~"*|'$'*) _doc_mcp_path "$lbl" "$t"; continue ;;
        esac
        mode="" ;;
    esac
    case "$t" in
      npx|*/npx) mode=npx ;;
      uvx|*/uvx) mode=uvx ;;
    esac
  done < <(grep -oE '"([^"\\]|\\.)*"' "$f" 2>/dev/null)

  while IFS= read -r pair; do
    key="${pair#\"}"; key="${key%%\"*}"
    val="${pair#*:}"; val="${val#"${val%%[![:space:]]*}"}"; val="${val#\"}"; val="${val%\"}"
    [[ -z "$val" || "$val" == *'$'* ]] && continue
    if [[ "$val" =~ $_DOC_SECRET_RE ]] || { [[ "$key" =~ $keyre ]] \
        && [[ "$val" =~ ^[A-Za-z0-9_+=-]{24,}$ ]]; }; then
      _doc_hyg warn "$lbl" "plaintext secret stored under key $key" \
        "keep it out of the file: set it in your environment or secret manager"
    fi
  done < <(grep -oE '"[^"\\]+"[[:space:]]*:[[:space:]]*"[^"\\]{8,}"' "$f" 2>/dev/null)

  n1=${#_DH_ST[@]}
  [[ $n1 -eq $n0 ]] && _doc_hyg ok "$lbl" "no issues found" ""
  return 0
}

_doc_scan_misc() {
  local f content q1='"' q2="'" re
  # direnv: [whitelist] prefix = [...] trusts whole directory trees
  f="$HOME/.config/direnv/direnv.toml"
  if [[ -f "$f" ]]; then
    content="$(tr '\n' ' ' < "$f" 2>/dev/null)"
    re='\[whitelist\][^[]*prefix[[:space:]]*=[[:space:]]*\[[^]]*['"$q1$q2"']'
    if [[ "$content" =~ $re ]]; then
      _doc_hyg warn "direnv" "[whitelist] auto-trusts whole directory prefixes" \
        "remove the prefix list and run 'direnv allow' per project"
    else
      _doc_hyg ok "direnv" "no auto-trusted prefixes" ""
    fi
  else
    _doc_hyg skip "direnv" "not present" ""
  fi
  # Atuin: secrets_filter must not be disabled
  f="$HOME/.config/atuin/config.toml"
  if [[ -f "$f" ]]; then
    if grep -qE '^[[:space:]]*secrets_filter[[:space:]]*=[[:space:]]*false' "$f" 2>/dev/null; then
      _doc_hyg warn "atuin" "secrets_filter is disabled" "set secrets_filter = true in $f"
    else
      _doc_hyg ok "atuin" "secrets_filter enabled" ""
    fi
  else
    _doc_hyg skip "atuin" "not present" ""
  fi
}


# Disk encryption (read-only, no sudo). The Atuin history database is not
# encrypted by Atuin itself, so disk encryption is what protects it at rest.
_DOC_ENC_WHY="Atuin's history database is not encrypted; disk encryption protects it at rest"

_doc_check_disk_encryption() {
  local nm="Disk encryption" out="" src="" fst="" types=""
  if [[ "$_DOC_OS" == "Darwin" ]]; then
    if ! command -v fdesetup >/dev/null 2>&1; then
      _doc_hyg unknown "$nm" "unknown: fdesetup is not available. $_DOC_ENC_WHY" ""; return 0
    fi
    out="$(fdesetup status 2>&1 </dev/null)" || out=""
    case "$out" in
      *"FileVault is On"*)  _doc_hyg ok "$nm" "FileVault is on. $_DOC_ENC_WHY" "" ;;
      *"FileVault is Off"*) _doc_hyg warn "$nm" "FileVault is off. $_DOC_ENC_WHY" \
                              "System Settings → Privacy & Security → FileVault" ;;
      *) _doc_hyg unknown "$nm" "unknown: could not read FileVault status. $_DOC_ENC_WHY" "" ;;
    esac
    return 0
  fi
  if ! command -v findmnt >/dev/null 2>&1; then
    _doc_hyg unknown "$nm" "unknown: findmnt is not available. $_DOC_ENC_WHY" ""; return 0
  fi
  src="$(findmnt -n -o SOURCE --target "$HOME" 2>/dev/null </dev/null | head -n1)" || src=""
  fst="$(findmnt -n -o FSTYPE --target "$HOME" 2>/dev/null </dev/null | head -n1)" || fst=""
  case "$fst" in
    ecryptfs|fuse.ecryptfs|fuse.gocryptfs|fuse.encfs)
      _doc_hyg ok "$nm" "$HOME is on $fst. $_DOC_ENC_WHY" ""; return 0 ;;
  esac
  src="${src%%\[*}"
  case "$src" in
    /dev/*) ;;
    *) _doc_hyg unknown "$nm" "unknown: home is not on a block device (${src:-no source}). $_DOC_ENC_WHY" ""
       return 0 ;;
  esac
  if ! command -v lsblk >/dev/null 2>&1; then
    _doc_hyg unknown "$nm" "unknown: lsblk is not available. $_DOC_ENC_WHY" ""; return 0
  fi
  types="$(lsblk -s -n -o TYPE "$src" 2>/dev/null </dev/null)" || types=""
  case "$types" in
    *crypt*) _doc_hyg ok "$nm" "home is on an encrypted (dm-crypt/LUKS) device. $_DOC_ENC_WHY" "" ;;
    "")      _doc_hyg unknown "$nm" "unknown: lsblk gave no data for $src. $_DOC_ENC_WHY" "" ;;
    *)       _doc_hyg warn "$nm" "home is not on an encrypted device. $_DOC_ENC_WHY" \
               "enable LUKS/dm-crypt full-disk encryption (needs reinstall or a new encrypted volume for ~)" ;;
  esac
  return 0
}

# ─── Manifest: which components did the user install? ─────────────────────────
# Sets _DOC_MODE (known|info), _DOC_INST (space-padded list of group ids).
_doc_read_manifest() {
  local c
  _DOC_MODE=info; _DOC_INST=" "; _DOC_MANI_NOTE="no manifest — the installer has not run in install mode"
  [[ -f "$HTS_MANIFEST" ]] || return 0
  while IFS= read -r c; do
    c="${c#--}"; c="$(printf '%s' "$c" | tr '[:upper:]_' '[:lower:]-')"
    case "$c" in
      dev) _DOC_INST="$_DOC_INST""node claude code " ;;
      cloud|cloud-devsec|devsecops) _DOC_INST="$_DOC_INST""cloud " ;;
      ad-pivoting|pivoting|ad) _DOC_INST="$_DOC_INST""ad-pivot " ;;
      configs) _DOC_INST="$_DOC_INST""config " ;;
      doctor|"") ;;
      *) _DOC_INST="$_DOC_INST$c " ;;
    esac
  done < <(awk -F'\t' '$2=="component"{print $3}' "$HTS_MANIFEST" 2>/dev/null)
  if [[ "$_DOC_INST" == " " ]]; then
    _DOC_MANI_NOTE="manifest has no component records"
  else
    _DOC_MODE=known; _DOC_MANI_NOTE=""
  fi
  return 0
}

_doc_active() { # owners -> 0 when any owner is an installed component
  local o
  [[ "$_DOC_MODE" == "known" ]] || return 1
  for o in $1; do
    case "$_DOC_INST" in *" $o "*) return 0 ;; esac
  done
  return 1
}

# Prints the hygiene section of the text report.
_doc_render_hygiene_text() {
  local i nh=${#_DH_ST[@]}
  echo -e "${BOLD}${YELLOW}  Config & hygiene${RESET}"
  for ((i = 0; i < nh; i++)); do
    case "${_DH_ST[$i]}" in
      ok)   printf '  %b %-23.23s %b%s%b\n' "${GREEN}[✓]${RESET}" "${_DH_NAME[$i]}" "$DIM" "${_DH_MSG[$i]}" "$RESET" ;;
      warn) printf '  %b %-23.23s %s\n' "${YELLOW}[!]${RESET}" "${_DH_NAME[$i]}" "${_DH_MSG[$i]}"
            printf '      %bfix: %s%b\n' "$DIM" "${_DH_FIX[$i]}" "$RESET" ;;
      *)    printf '  %b %-23.23s %b%s%b\n' "${DIM}[~]${RESET}" "${_DH_NAME[$i]}" "$DIM" "${_DH_MSG[$i]}" "$RESET" ;;
    esac
  done
}

# Prints '},"hygiene":[' and the entries (the caller closes the array).
_doc_render_hygiene_json() {
  local j first=1 nh=${#_DH_ST[@]}
  printf '},"hygiene":['
  for ((j = 0; j < nh; j++)); do
    [[ $first -eq 0 ]] && printf ','
    first=0
    printf '{"name":"%s","status":"%s","detail":"%s","fix":"%s"}' "$(_doc_jesc "${_DH_NAME[$j]}")" \
      "${_DH_ST[$j]}" "$(_doc_jesc "${_DH_MSG[$j]}")" "$(_doc_jesc "${_DH_FIX[$j]}")"
  done
}

# Runs every hygiene scan, counts warnings and gathers state facts.
_doc_run_hygiene() {
  local i
  if [[ "$_DOC_OS" == "Darwin" ]]; then
    _doc_scan_mcp "$HOME/Library/Application Support/Claude/claude_desktop_config.json" "MCP: Claude Desktop"
  else
    _doc_scan_mcp "$HOME/.config/Claude/claude_desktop_config.json" "MCP: Claude Desktop"
  fi
  _doc_scan_mcp "$HOME/pentest/.mcp.json" "MCP: pentest/.mcp.json"
  _doc_scan_misc
  _doc_check_disk_encryption

  _DOC_WARNS=0
  for ((i = 0; i < ${#_DH_ST[@]}; i++)); do
    [[ "${_DH_ST[$i]}" == "warn" ]] && _DOC_WARNS=$((_DOC_WARNS + 1))
  done
  _DOC_MANI_N=0
  [[ -f "$HTS_MANIFEST" ]] && _DOC_MANI_N="$(wc -l < "$HTS_MANIFEST" 2>/dev/null | tr -d ' ')"
  _DOC_BACKUPS=0
  [[ -d "$HTS_BACKUP_ROOT" ]] && _DOC_BACKUPS="$(find "$HTS_BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
}

# ─── Read-only probe isolation (used by _doc_ver in doctor.sh) ──────────────────
# Tools whose --version creates state under $HOME or contacts the network.
_DOC_NOPROBE=" semgrep gh az gcloud aws claude llm garak promptfoo ollama atuin frida objection bbot checkov prowler pacu nuclei subfinder httpx katana trufflehog gitleaks "

# Probes run in a throwaway HOME so tools that create cache/config files on
# --version (starship, ffuf, ghostty, ...) cannot touch the real home directory.
_doc_probe_setup() {
  _DOC_PROBE_HOME="$(mktemp -d "${TMPDIR:-/tmp}/hts-doctor.XXXXXX" 2>/dev/null)" || { _DOC_PROBE_HOME=""; return 0; }
  _DOC_PROBE_ENV=(HOME="$_DOC_PROBE_HOME" XDG_CONFIG_HOME="$_DOC_PROBE_HOME/.config"
    XDG_CACHE_HOME="$_DOC_PROBE_HOME/.cache" XDG_DATA_HOME="$_DOC_PROBE_HOME/.local/share"
    XDG_STATE_HOME="$_DOC_PROBE_HOME/.local/state" TMPDIR="$_DOC_PROBE_HOME"
    DO_NOT_TRACK=1 NO_UPDATE_NOTIFIER=1 SEMGREP_ENABLE_VERSION_CHECK=0 HOMEBREW_NO_AUTO_UPDATE=1)
}

_doc_probe_cleanup() {
  [[ -n "${_DOC_PROBE_HOME:-}" && -d "$_DOC_PROBE_HOME" ]] && rm -rf "$_DOC_PROBE_HOME"
  _DOC_PROBE_HOME=""
}
