#!/usr/bin/env bash
# =============================================================================
#  lib/doctor.sh — Security Terminal Doctor & Diagnostic Audit
#
#  READ-ONLY. Only `command -v`, `--version` style probes and reads of config
#  files happen here: no installs, no writes, no network calls. Tools whose
#  version probe is known to create files or phone home are presence-only
#  (see _DOC_NOPROBE), and the remaining probes run with telemetry and update
#  checks switched off.
#
#  Environment:  HTS_DOCTOR_FORMAT=json   print one JSON document, nothing else
#  Exit status:  0 when every required item of every installed component is
#                present (or when no manifest exists), 1 otherwise.
# =============================================================================

# Group ids in installer order, and their display titles.
_DOC_GROUPS="core fonts node claude code terminals shell-tools mcp pentest seclists bugbounty ad-pivot web-api cloud mobile ai workflow dashboard config"

_doc_gtitle() {
  case "$1" in
    core) echo "Core terminal" ;;            fonts) echo "Hacker Fonts" ;;
    node) echo "Node.js & npm" ;;            claude) echo "Claude Code CLI" ;;
    code) echo "VS Code & CLI" ;;            terminals) echo "GPU Terminals" ;;
    shell-tools) echo "Shell History" ;;     mcp) echo "MCP Server Suite" ;;
    pentest) echo "Pentest tools" ;;         seclists) echo "SecLists" ;;
    bugbounty) echo "Bug bounty" ;;          ad-pivot) echo "Active Directory" ;;
    web-api) echo "Web & API Sec" ;;         cloud) echo "Cloud & DevSecOps" ;;
    mobile) echo "Mobile & Reverse" ;;       ai) echo "AI / LLM sec" ;;
    workflow) echo "Workflow tools" ;;        dashboard) echo "Tactical Cockpit" ;;
    config) echo "Config files" ;;            *) echo "$1" ;;
  esac
}

# ─── Result store (parallel arrays, bash 3.2 safe) ────────────────────────────
_doc_reset() {
  _DI_G=(); _DI_OWN=(); _DI_NAME=(); _DI_ST=(); _DI_VER=(); _DI_NOTE=()
  _DH_ST=(); _DH_NAME=(); _DH_MSG=(); _DH_FIX=()
  _DOC_OS="$(uname -s)"
}

_doc_add() { # group+owners label status version note
  local own=$1 n=${#_DI_G[@]}
  _DI_G[$n]="${own%%+*}"
  _DI_OWN[$n]="${own//+/ }"
  _DI_NAME[$n]=$2; _DI_ST[$n]=$3; _DI_VER[$n]=${4:-}; _DI_NOTE[$n]=${5:-}
}

_doc_hyg() { # status name message fix
  local n=${#_DH_ST[@]}
  _DH_ST[$n]=$1; _DH_NAME[$n]=$2; _DH_MSG[$n]=${3:-}; _DH_FIX[$n]=${4:-}
}

# Evaluate platform flags. Prints: na | opt | req
_doc_flags() {
  local f=" $1 " mac=0
  [[ "$_DOC_OS" == "Darwin" ]] && mac=1
  case "$f" in *" mac "*) [[ $mac -eq 1 ]] || { echo na; return; } ;; esac
  case "$f" in *" lin "*) [[ $mac -eq 0 ]] || { echo na; return; } ;; esac
  case "$f" in *" opt "*) echo opt; return ;; esac
  case "$f" in *" optlinux "*) [[ $mac -eq 0 ]] && { echo opt; return; } ;; esac
  case "$f" in *" optmac "*) [[ $mac -eq 1 ]] && { echo opt; return; } ;; esac
  echo req
}

# Version probe: never evaluates strings, 5s cap when `timeout` exists.
_doc_ver() { # binary "args" -> prints a short version string
  local out="" tmo=""
  local -a va
  [[ -z "${2:-}" || "$2" == "-" ]] && return 0
  [[ -n "${_DOC_PROBE_HOME:-}" ]] || return 0   # no scratch HOME: presence only
  case "$_DOC_NOPROBE" in *" ${1##*/} "*) return 0 ;; esac
  read -r -a va <<< "$2"
  command -v timeout >/dev/null 2>&1 && tmo=timeout
  [[ -z "$tmo" ]] && command -v gtimeout >/dev/null 2>&1 && tmo=gtimeout
  if [[ -n "$tmo" ]]; then
    out="$(env "${_DOC_PROBE_ENV[@]}" \
      "$tmo" 5 "$1" "${va[@]}" 2>&1 </dev/null | head -n 20)"
  else
    out="$(env "${_DOC_PROBE_ENV[@]}" \
      "$1" "${va[@]}" 2>&1 </dev/null | head -n 20)"
  fi
  printf '%s\n' "$out" | grep -m1 -oE '[0-9]+\.[0-9]+(\.[0-9A-Za-z_+-]+)*' | head -n1 | cut -c1-13
}

# _b <group[+owner...]> <label> <bin|bin2|app:Name.app> <version-args|-> [flags]
_b() {
  local own=$1 label=$2 spec=$3 vargs=${4:--} kind alt found="" path="" ver=""
  local -a alts
  kind="$(_doc_flags "${5:-}")"
  if [[ "$kind" == "na" ]]; then _doc_add "$own" "$label" na "" "n/a"; return 0; fi
  IFS='|' read -r -a alts <<< "$spec"
  for alt in "${alts[@]}"; do
    case "$alt" in
      app:*)
        if [[ -d "/Applications/${alt#app:}" || -d "$HOME/Applications/${alt#app:}" ]]; then
          found=app; path="/Applications/${alt#app:}"; break
        fi ;;
      *)
        if command -v "$alt" >/dev/null 2>&1; then found=bin; path="$alt"; break; fi ;;
    esac
  done
  if [[ -z "$found" ]]; then
    if [[ "$kind" == "opt" ]]; then _doc_add "$own" "$label" not_installed "" "optional"
    else _doc_add "$own" "$label" missing "" "missing"; fi
    return 0
  fi
  [[ "$found" == "bin" ]] && ver="$(_doc_ver "$path" "$vargs")"
  [[ "$found" == "app" && -z "$ver" ]] && ver="(app)"
  _doc_add "$own" "$label" installed "$ver" ""
}

# _f <group[+owner...]> <label> <path> [flags] — file must exist and be non-empty
_f() {
  local kind
  kind="$(_doc_flags "${4:-}")"
  if [[ "$kind" == "na" ]]; then _doc_add "$1" "$2" na "" "n/a"; return 0; fi
  if [[ -s "$3" ]]; then _doc_add "$1" "$2" installed "" ""
  elif [[ -e "$3" ]]; then _doc_add "$1" "$2" missing "" "empty file"
  elif [[ "$kind" == "opt" ]]; then _doc_add "$1" "$2" not_installed "" "optional"
  else _doc_add "$1" "$2" missing "" "missing"; fi
}

# _d <group[+owner...]> <label> <dir> [dir...]  — any of the directories exists
_d() {
  local own=$1 label=$2 d; shift 2
  for d in "$@"; do
    if [[ -d "$d" ]]; then _doc_add "$own" "$label" installed "" ""; return 0; fi
  done
  _doc_add "$own" "$label" missing "" "missing"
}

# _t <group> <label> <font-name-glob> [flags] — font file present in a font dir
_t() {
  local kind d hit="" dirs
  kind="$(_doc_flags "${4:-}")"
  if [[ "$_DOC_OS" == "Darwin" ]]; then dirs="$HOME/Library/Fonts|/Library/Fonts"
  else dirs="$HOME/.local/share/fonts|/usr/share/fonts|/usr/local/share/fonts"; fi
  local -a da
  IFS='|' read -r -a da <<< "$dirs"
  for d in "${da[@]}"; do
    [[ -d "$d" ]] || continue
    hit="$(find "$d" -maxdepth 4 -iname "$3" 2>/dev/null | head -n1)"
    [[ -n "$hit" ]] && break
  done
  if [[ -n "$hit" ]]; then _doc_add "$1" "$2" installed "" ""
  elif [[ "$kind" == "opt" ]]; then _doc_add "$1" "$2" not_installed "" "optional"
  else _doc_add "$1" "$2" missing "" "missing"; fi
}

# ─── Coverage: every binary and file the installer writes ─────────────────────
_doc_collect_items() {
  local zc="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}" cfg="$HOME/.config" claude_cfg

  # 1 Core terminal (also pulled in by Shell History)
  _b core "Zsh" zsh "--version"
  _d core "Oh My Zsh" "$HOME/.oh-my-zsh"
  _d core "zsh-autosuggestions" "$zc/plugins/zsh-autosuggestions"
  _d core "zsh-syntax-hl" "$zc/plugins/zsh-syntax-highlighting"
  _d core "zsh-completions" "$zc/plugins/zsh-completions"
  _d core "Powerlevel10k" "$zc/themes/powerlevel10k"
  _b core+shell-tools "fzf" fzf "--version"
  _b core+shell-tools "bat" "bat|batcat" "--version"
  _b core+shell-tools "eza" eza "--version"
  _b core+shell-tools "zoxide" zoxide "--version"
  _b core+shell-tools "ripgrep (rg)" rg "--version"
  _b core+shell-tools "fd" "fd|fdfind" "--version"
  _b core+shell-tools "git-delta" delta "--version"
  _b core "tmux" tmux "-V"
  _b core "tldr" tldr "-"

  # 2 Fonts
  _t fonts "MesloLGS NF" "*Meslo*"
  _t fonts "JetBrains Mono" "*JetBrains*" opt
  _t fonts "Fira Code" "*Fira*Code*" opt
  _t fonts "Hack" "*Hack*" opt
  _t fonts "Caskaydia Cove" "*Caskaydia*" opt

  # 3-5 Developer stack (--dev installs node, claude and code)
  _b node "Node.js" node "-v"
  _b node "npm" npm "-v"
  _b claude "Claude Code CLI" claude "--version"
  _b code "VS Code (code)" "code|app:Visual Studio Code.app" "--version"

  # 6 GPU terminals
  _b terminals "Ghostty" "ghostty|app:Ghostty.app" "--version" optlinux
  _b terminals "WezTerm" "wezterm|app:WezTerm.app" "--version"
  _b terminals "Kitty" "kitty|app:kitty.app" "--version"
  _b terminals "Alacritty" "alacritty|app:Alacritty.app" "--version" opt
  _f terminals "ghostty/config" "$cfg/ghostty/config"
  _f terminals "wezterm.lua" "$cfg/wezterm/wezterm.lua"
  _f terminals "kitty.conf" "$cfg/kitty/kitty.conf"
  _f terminals "alacritty.toml" "$cfg/alacritty/alacritty.toml"

  # 7 Shell history & ergonomics
  _b shell-tools "Atuin" atuin "--version"
  _b shell-tools "direnv" direnv "--version"
  _b shell-tools "uv" uv "--version"
  _b shell-tools "uvx" uvx "--version" opt
  _b shell-tools "btop" btop "--version"
  _b shell-tools+workflow "yazi" yazi "-" optlinux
  _b shell-tools "Starship" starship "--version"
  _f shell-tools "atuin/config.toml" "$cfg/atuin/config.toml"
  _f shell-tools "direnv.toml" "$cfg/direnv/direnv.toml"
  _f shell-tools "starship.toml" "$cfg/starship.toml"

  # 8 MCP server suite
  if [[ "$_DOC_OS" == "Darwin" ]]; then claude_cfg="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
  else claude_cfg="$HOME/.config/Claude/claude_desktop_config.json"; fi
  _b mcp "sec-mcp" sec-mcp "-"
  _b mcp "github-mcp-server" github-mcp-server "-" opt
  _b mcp "MCP Inspector" mcp-inspector "-"
  _b mcp "detect-secrets" detect-secrets "--version"
  _b mcp "semgrep" semgrep "--version" opt
  _d mcp "~/workspace" "$HOME/workspace"
  _d mcp "~/pentest" "$HOME/pentest"
  _f mcp "claude_desktop" "$claude_cfg"
  _f mcp "pentest/.mcp.json" "$HOME/pentest/.mcp.json"

  # 9 Pentest tools
  _b pentest "nmap" nmap "--version"
  _b pentest "netcat" "nc|ncat|netcat" "-"
  _b pentest "wget" wget "--version"
  _b pentest "curl" curl "--version"
  _b pentest "httpie" "http|https" "--version"
  _b pentest "gobuster" gobuster "version"
  _b pentest "hydra" hydra "-h"
  _b pentest "sqlmap" sqlmap "--version"
  _b pentest "masscan" masscan "--version"
  _b pentest "tcpdump" tcpdump "--version"
  _b pentest "openssl" openssl "version"
  _b pentest "gpg" gpg "--version"
  _b pentest "python3" python3 "--version"
  _b pentest "pipx" pipx "--version"
  _b pentest "john" "john|john-the-ripper" "-"
  _b pentest "hashcat" hashcat "--version"
  _b pentest "tshark (wireshark)" tshark "--version" lin
  _b pentest "impacket" "impacket-secretsdump|secretsdump.py|secretsdump" "-"
  _b pentest "pwntools (pwn)" pwn "-"
  _b pentest "scapy" scapy "-"
  _d seclists+pentest "SecLists" "$HOME/pentest/wordlists/seclists/Discovery" /opt/seclists/Discovery \
    /usr/share/seclists/Discovery /opt/homebrew/share/seclists/Discovery

  # 10 Bug bounty
  _b bugbounty "mitmproxy" mitmproxy "--version"
  _b bugbounty "nikto" nikto "-"
  _b bugbounty "subfinder" subfinder "-"
  _b bugbounty "httpx" httpx "-"
  _b bugbounty "nuclei" nuclei "-"
  _b bugbounty "katana" katana "-"
  _b bugbounty "dnsx" dnsx "-"
  _b bugbounty "interactsh-client" interactsh-client "-"
  _b bugbounty "gau" gau "-"
  _b bugbounty "hakrawler" hakrawler "-"
  _b bugbounty "waybackurls" waybackurls "-"
  _b bugbounty "amass" amass "-"
  _b bugbounty "dalfox" dalfox "-"
  _b bugbounty "Burp Suite" "burpsuite|app:Burp Suite Community Edition.app|app:Burp Suite Professional.app" "-" mac
  _b bugbounty "bbot" bbot "--version" opt

  # 11 Active Directory & pivoting
  _b ad-pivot "Ligolo-ng" "ligolo-proxy|ligolo-ng|ligolo" "-" opt
  _b ad-pivot "Chisel" chisel "--version"
  _b ad-pivot+pentest "NetExec (nxc)" "nxc|netexec" "-"
  _b ad-pivot "BloodHound.py" bloodhound-python "-"
  _b ad-pivot "BH CE ingestor" bloodhound-ce-python "-"
  _b ad-pivot "BloodHound CLI" bloodhound-cli "-"
  _b ad-pivot "Certipy" certipy "-"
  _b ad-pivot "Responder" responder "-"

  # 12 Web & API (ffuf, feroxbuster, arjun, caido are shared with bug bounty)
  _b web-api "Schemathesis" "schemathesis|st" "--version"
  _b web-api "Kiterunner (kr)" kr "-"
  _b web-api+bugbounty "Caido" "caido-cli|caido|app:Caido.app" "-" optlinux
  _b web-api+bugbounty "Arjun" arjun "-"
  _b web-api+bugbounty "ffuf" ffuf "-V"
  _b web-api+bugbounty "feroxbuster" feroxbuster "-V"

  # 13 Cloud & DevSecOps
  _b cloud "AWS CLI" aws "--version"
  _b cloud "Azure CLI" az "-"
  _b cloud "gcloud" "gcloud|app:Google Cloud SDK" "-" optlinux
  _b cloud "cloudfox" cloudfox "-"
  _b cloud "gitleaks" gitleaks "version"
  _b cloud "trufflehog" trufflehog "--version"
  _b cloud "prowler" prowler "-"
  _b cloud "pacu" pacu "-"
  _b cloud "s3scanner" s3scanner "-"
  _b cloud "Trivy" trivy "--version"
  _b cloud "Syft" syft "--version"
  _b cloud "Grype" grype "version"
  _b cloud "Checkov" checkov "-"
  _b cloud "kubescape" kubescape "-" opt
  _b cloud "kube-bench" kube-bench "-" opt
  _b cloud "osv-scanner" osv-scanner "--version" opt

  # 14 Mobile & reverse engineering
  _b mobile "jadx" jadx "--version" opt
  _b mobile "apktool" apktool "--version" opt
  _b mobile "frida" frida "--version" opt
  _b mobile "objection" objection "-" opt

  # 15 AI / LLM security
  _b ai "garak" garak "-"
  _b ai "llm" llm "--version"
  _b ai "jwt_tool" "jwt_tool|jwt_tool.py" "-"
  _b ai "promptfoo" promptfoo "-"
  _b ai "Ollama" "ollama|app:Ollama.app" "--version"

  # 16 Workflow tools
  _b workflow "jq" jq "--version"
  _b workflow "GitHub CLI (gh)" gh "--version"
  _b workflow "pandoc" pandoc "--version"
  _b workflow "yq" yq "--version"
  _b workflow "lazygit" lazygit "--version"
  _b workflow "xh" xh "--version" optlinux
  _b workflow "Obsidian" "app:Obsidian.app" "-" mac
  _b workflow "hts command" hts "-" opt

  # 17 Tactical cockpit
  _b dashboard "fastfetch" fastfetch "--version"
  _f dashboard "fastfetch config" "$cfg/fastfetch/config.jsonc"
  _f dashboard "welcome.zsh" "$zc/welcome.zsh"

  # 18 Config files
  _f config ".zshrc" "$HOME/.zshrc"
  _f config ".tmux.conf" "$HOME/.tmux.conf"
  _f config "pentest.zsh" "$zc/pentest.zsh"
  _f config "advanced_pentest" "$zc/advanced_pentest.zsh"
}

_doc_jesc() {
  local s=$1
  s="$(printf '%s' "$s" | LC_ALL=C tr -d '\000-\010\013\014\016-\037')"
  s=${s//\\/\\\\}; s=${s//\"/\\\"}
  s=${s//$'\t'/\\t}; s=${s//$'\n'/\\n}; s=${s//$'\r'/\\r}
  printf '%s' "$s"
}

# ─── Rendering ────────────────────────────────────────────────────────────────
_doc_cell() { # index -> prints one fixed-width cell (no newline)
  local i=$1 mark txt
  case "${_DI_ST[$i]}" in
    installed)     mark="${GREEN}[✓]${RESET}"; txt="${_DI_VER[$i]}" ;;
    missing)
      if _doc_active "${_DI_OWN[$i]}"; then mark="${RED}[✗]${RESET}"; else mark="${DIM}[-]${RESET}"; fi
      txt="${_DI_NOTE[$i]}" ;;
    not_installed) mark="${DIM}[-]${RESET}"; txt="not installed" ;;
    *)             mark="${DIM}[~]${RESET}"; txt="n/a" ;;
  esac
  printf '%b %-17.17s %-13.13s' "$mark" "${_DI_NAME[$i]}" "$txt"
}

_doc_render_text() {
  local g i n=${#_DI_G[@]} col cnt inst miss opt na fail state
  echo ""
  echo -e "${BOLD}${CYAN}  ╔══════════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${CYAN}  ║           SECURITY TERMINAL ENVIRONMENT AUDIT                    ║${RESET}"
  echo -e "${BOLD}${CYAN}  ╚══════════════════════════════════════════════════════════════════╝${RESET}"
  echo -e "  ${DIM}v$HTS_VERSION  $_DOC_OS $(uname -m)   ${GREEN}[✓]${RESET}${DIM} ok  ${RED}[✗]${RESET}${DIM} missing  [-] not installed  [~] n/a${RESET}"
  [[ -n "$_DOC_MANI_NOTE" ]] && echo -e "  ${YELLOW}Note:${RESET} $_DOC_MANI_NOTE; reporting everything informationally."
  _T_INST=0; _T_MISS=0; _T_OPT=0; _T_NA=0; _T_FAIL=0
  for g in $_DOC_GROUPS; do
    inst=0; miss=0; opt=0; na=0; fail=0; cnt=0
    for ((i = 0; i < n; i++)); do
      [[ "${_DI_G[$i]}" == "$g" ]] || continue
      cnt=$((cnt + 1))
      case "${_DI_ST[$i]}" in
        installed) inst=$((inst + 1)) ;;
        missing) miss=$((miss + 1)); _doc_active "${_DI_OWN[$i]}" && fail=$((fail + 1)) ;;
        not_installed) opt=$((opt + 1)) ;;
        *) na=$((na + 1)) ;;
      esac
    done
    [[ $cnt -eq 0 ]] && continue
    _T_INST=$((_T_INST + inst)); _T_MISS=$((_T_MISS + miss)); _T_OPT=$((_T_OPT + opt))
    _T_NA=$((_T_NA + na)); _T_FAIL=$((_T_FAIL + fail))
    if [[ "$_DOC_MODE" != "known" ]]; then state="${DIM}informational${RESET}"
    elif _doc_active "$g"; then state="${CYAN}installed${RESET}"
    else state="${DIM}not selected${RESET}"; fi
    echo ""
    printf '%b  %-20s%b %b  %b%d ok, %d missing, %d optional, %d n/a%b\n' \
      "${BOLD}${YELLOW}" "$(_doc_gtitle "$g")" "${RESET}" "$state" "${DIM}" "$inst" "$miss" "$opt" "$na" "${RESET}"
    col=0
    for ((i = 0; i < n; i++)); do
      [[ "${_DI_G[$i]}" == "$g" ]] || continue
      if [[ $col -eq 0 ]]; then printf '  '; _doc_cell "$i"; col=1
      else printf '  '; _doc_cell "$i"; printf '\n'; col=0; fi
    done
    [[ $col -eq 1 ]] && printf '\n'
  done

  echo ""
  _doc_render_hygiene_text

  echo ""
  echo -e "${BOLD}${YELLOW}  State${RESET}"
  printf '  %-12s %s\n' "Version" "$HTS_VERSION"
  printf '  %-12s %s (%s entries)\n' "Manifest" "$HTS_MANIFEST" "$_DOC_MANI_N"
  printf '  %-12s %s\n' "Log" "$HTS_LOG"
  printf '  %-12s %s available\n' "Backups" "$_DOC_BACKUPS"

  echo ""
  echo -e "${BOLD}${CYAN}  ════════════════════════════════════════════════════════════════════${RESET}"
  printf '  Total: %d ok, %d missing, %d optional, %d n/a, %d warnings\n' \
    "$_T_INST" "$_T_MISS" "$_T_OPT" "$_T_NA" "$_DOC_WARNS"
  if [[ "$_DOC_MODE" != "known" ]]; then
    echo -e "  ${CYAN}Informational run:${RESET} nothing to verify against; exit status 0."
  elif [[ $_T_FAIL -eq 0 ]]; then
    echo -e "  ${GREEN}PASS${RESET} — everything belonging to installed components is present."
  else
    echo -e "  ${RED}FAIL${RESET} — $_T_FAIL required item(s) missing from installed components."
  fi
}

_doc_render_json() {
  local g i n=${#_DI_G[@]} gfirst=1 ifirst st
  local inst=0 miss=0 opt=0 na=0 fail=0 state
  printf '{"version":"%s","platform":{"os":"%s","arch":"%s"},"mode":"%s",' \
    "$(_doc_jesc "$HTS_VERSION")" "$(_doc_jesc "$_DOC_OS")" "$(_doc_jesc "$(uname -m)")" \
    "$([[ "$_DOC_MODE" == "known" ]] && echo manifest || echo informational)"
  printf '"components":{'
  for g in $_DOC_GROUPS; do
    ifirst=1
    [[ $gfirst -eq 0 ]] && printf ','
    gfirst=0
    printf '"%s":[' "$g"
    for ((i = 0; i < n; i++)); do
      [[ "${_DI_G[$i]}" == "$g" ]] || continue
      st="${_DI_ST[$i]}"
      case "$st" in
        installed) inst=$((inst + 1)) ;;
        missing) miss=$((miss + 1)); _doc_active "${_DI_OWN[$i]}" && fail=$((fail + 1)) ;;
        not_installed) opt=$((opt + 1)) ;;
        *) na=$((na + 1)) ;;
      esac
      [[ $ifirst -eq 0 ]] && printf ','
      ifirst=0
      printf '{"name":"%s","status":"%s"' "$(_doc_jesc "${_DI_NAME[$i]}")" "$st"
      [[ "$st" == "installed" && -n "${_DI_VER[$i]}" ]] && printf ',"version":"%s"' "$(_doc_jesc "${_DI_VER[$i]}")"
      printf '}'
    done
    printf ']'
  done
  printf '},"component_state":{'
  gfirst=1
  for g in $_DOC_GROUPS; do
    [[ $gfirst -eq 0 ]] && printf ','
    gfirst=0
    if [[ "$_DOC_MODE" != "known" ]]; then state=unknown
    elif _doc_active "$g"; then state=installed
    else state=not_selected; fi
    printf '"%s":"%s"' "$g" "$state"
  done
  _doc_render_hygiene_json
  printf '],"state":{"manifest":"%s","manifest_entries":%s,"log":"%s","backups":%s},' \
    "$(_doc_jesc "$HTS_MANIFEST")" "$_DOC_MANI_N" "$(_doc_jesc "$HTS_LOG")" "$_DOC_BACKUPS"
  printf '"totals":{"installed":%d,"missing":%d,"not_installed":%d,"na":%d,"warnings":%d,"failing":%d},' \
    "$inst" "$miss" "$opt" "$na" "$_DOC_WARNS" "$fail"
  printf '"ok":%s}\n' "$([[ $fail -eq 0 ]] && echo true || echo false)"
  _T_FAIL=$fail
}

_doc_main() {
  local json=0
  [[ "${HTS_DOCTOR_FORMAT:-}" == "json" ]] && json=1
  _doc_reset
  _doc_read_manifest
  _doc_probe_setup
  _doc_collect_items
  _doc_probe_cleanup

  _doc_run_hygiene
  _T_FAIL=0
  if [[ $json -eq 1 ]]; then _doc_render_json; else _doc_render_text; fi
  [[ ${_T_FAIL:-0} -eq 0 ]]
}

sec_doctor() {
  local old_path="$PATH" rc=0 d
  if ! declare -F _doc_run_hygiene >/dev/null; then
    err "lib/doctor_hygiene.sh is not loaded"; return 1
  fi
  for d in "$HOME/.local/bin" "$HOME/.npm-global/bin" "$HOME/go/bin" "$HOME/.cargo/bin" \
           /opt/homebrew/bin /usr/local/bin; do
    case ":$PATH:" in *":$d:"*) ;; *) [[ -d "$d" ]] && PATH="$PATH:$d" ;; esac
  done
  if [[ "${HTS_DOCTOR_FORMAT:-}" != "json" ]]; then
    step "Security Terminal Doctor & Diagnostic Audit"
  fi
  _doc_main || rc=$?
  PATH="$old_path"
  return "$rc"
}
