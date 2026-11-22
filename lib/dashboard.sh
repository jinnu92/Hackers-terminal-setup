#!/usr/bin/env bash
# =============================================================================
#  lib/dashboard.sh — Modern Terminal Welcome Cockpit & Fastfetch Dashboard
# =============================================================================

install_dashboard() {
  step "Modern Terminal Welcome Dashboard & Fastfetch"

  # 1. Install fastfetch (high-speed modern C replacement for neofetch)
  if ! command -v fastfetch &>/dev/null; then
    log "Installing fastfetch..."
    case "$PKG_MGR" in
      brew)   pkg_install fastfetch ;;
      apt)
        # Official distro package first (Debian 13+/Ubuntu 24.10+); the PPA is only a fallback.
        if apt-cache show fastfetch >/dev/null 2>&1; then
          sudo apt-get install -y fastfetch && hts_manifest_add tool fastfetch "apt" || warn "apt install fastfetch failed"
        elif command -v add-apt-repository &>/dev/null && grep -qi ubuntu /etc/os-release 2>/dev/null; then
          warn "fastfetch has no package in this release's official repositories"
          warn "Adding third-party PPA ppa:zhangsongcui3371/fastfetch (maintained by the community, not Ubuntu)"
          if sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch && \
             sudo apt-get update -qq && sudo apt-get install -y fastfetch; then
            hts_manifest_add tool fastfetch "apt (ppa:zhangsongcui3371/fastfetch)"
          else
            warn "fastfetch ppa install failed"
          fi
        else
          warn "fastfetch: not packaged for this apt distro and no PPA applies — skipping (see github.com/fastfetch-cli/fastfetch)"
        fi
        ;;
      dnf)    sudo dnf install -y fastfetch && hts_manifest_add tool fastfetch "dnf" || warn "dnf install fastfetch failed" ;;
      pacman) sudo pacman -S --noconfirm --needed fastfetch && hts_manifest_add tool fastfetch "pacman" || warn "pacman install fastfetch failed" ;;
      *)      warn "fastfetch: install from github.com/fastfetch-cli/fastfetch" ;;
    esac
  else
    ok "fastfetch already installed: $(fastfetch --version 2>/dev/null | head -1)"
  fi

  # 2. Deploy minimal aesthetic fastfetch config
  local ff_dir="$HOME/.config/fastfetch"
  mkdir -p "$ff_dir"
  log "Writing Fastfetch configuration ($ff_dir/config.jsonc)..."
  backup_file "$ff_dir/config.jsonc"
  cat > "$ff_dir/config.jsonc" << 'FF_CFG'
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "type": "small",
    "padding": {
      "top": 1,
      "left": 2,
      "right": 3
    }
  },
  "display": {
    "separator": " ❯ "
  },
  "modules": [
    { "type": "title", "color": { "user": "cyan", "at": "dim", "host": "blue" } },
    { "type": "os", "key": "OS", "keyColor": "blue" },
    { "type": "kernel", "key": "Kernel", "keyColor": "blue" },
    { "type": "uptime", "key": "Uptime", "keyColor": "green" },
    { "type": "packages", "key": "Packages", "keyColor": "green" },
    { "type": "shell", "key": "Shell", "keyColor": "yellow" },
    { "type": "memory", "key": "RAM", "keyColor": "magenta" },
    { "type": "disk", "key": "Disk", "keyColor": "cyan" },
    { "type": "colors", "symbol": "circle" }
  ]
}
FF_CFG
  hts_track_file "$ff_dir/config.jsonc"
  ok "Fastfetch configuration deployed"

  # 3. Settings file + `hts` command (the welcome script reads ~/.config/hts/config)
  install_hts_cli || warn "hts command install had problems (see above)"

  # 4. Deploy modern welcome.zsh script
  write_modern_welcome
  ok "Tactical Security Welcome Cockpit deployed to ~/.oh-my-zsh/custom/welcome.zsh"
}

write_modern_welcome() {
  local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  mkdir -p "$ZSH_CUSTOM"

  log "Deploying modernized Tactical Security Cockpit to welcome.zsh..."
  backup_file "$ZSH_CUSTOM/welcome.zsh"
  cat > "$ZSH_CUSTOM/welcome.zsh" << 'WELCOME_SCRIPT'
# =============================================================================
# Modern Tactical Security Cockpit — High Performance (<15ms), Zero-Lag Welcome
# =============================================================================

# Settings: welcome=full|compact|off  welcome_ip=show|hide  tips=on|off
# Read line by line from ~/.config/hts/config; never sourced or eval'd. Only exact
# known key=value pairs are accepted, anything else keeps the default.
# Change with: hts config <key> <value>
_W_MODE=full; _W_IPMODE=show; _W_TIPS=on
if [[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/hts/config" ]]; then
  while IFS= read -r _hts_l || [[ -n $_hts_l ]]; do
    case $_hts_l in
      welcome=full|welcome=compact|welcome=off) _W_MODE=${_hts_l#welcome=} ;;
      welcome_ip=show|welcome_ip=hide)          _W_IPMODE=${_hts_l#welcome_ip=} ;;
      tips=on|tips=off)                         _W_TIPS=${_hts_l#tips=} ;;
    esac
  done < "${XDG_CONFIG_HOME:-$HOME/.config}/hts/config"
  unset _hts_l
fi
[[ $_W_MODE == off ]] && return 0

_W_RED='\033[38;5;203m';    _W_GREEN='\033[38;5;120m';  _W_YELLOW='\033[38;5;221m'
_W_CYAN='\033[38;5;117m';   _W_BLUE='\033[38;5;111m';   _W_MAGENTA='\033[38;5;183m'
_W_PURPLE='\033[38;5;141m'; _W_BOLD='\033[1m';          _W_DIM='\033[2m'; _W_RESET='\033[0m'

_PENTEST_TIPS=(
  "Prefix any command with SPACE to keep it out of shell history."
  "Use 'proxyon' before testing — routes traffic through Burp/Caido on :8080."
  "Run 'mkeng' to scaffold today's engagement directory hierarchy."
  "Use 'bbrecon <domain>' for a full automated recon pipeline."
  "Run 'mcp_audit' to check all MCP configs for dangerous permission flags."
  "Use 'agentscan .' to find prompt injection and hardcoded secrets in agent code."
  "Run 'upgradeshell' for a pty upgrade cheat sheet."
  "Use 'revshell <ip> <port>' to generate multi-language reverse shells."
  "Run 'llm_fuzz <endpoint>' to fire adversarial prompts at an LLM API."
  "Use 'jwtinspect <token>' to decode a JWT without transmitting to third-party sites."
  "Run 'scan <target>' for a full nmap scan saved into ./scans/."
  "Use 'secrets_scan_local' to scan current dir with TruffleHog."
  "Run 'awscheck' to inspect active AWS identity and attached IAM policies."
  "Ctrl+R opens Atuin history search; commands containing secrets are not recorded."
  "Run 'schematest <spec.json>' to property-fuzz APIs with Schemathesis."
  "Run 'nxc smb <subnet> -u user -p pass' for high-speed AD credential auditing."
  "Use 'ligolo_start' to scaffold kernel TUN pivoting instead of proxychains."
  "Run 'trivy fs .' to audit container, filesystem, and IaC vulnerabilities."
  "Run 'sbom_audit <image>' to generate Syft SBOM and cross-scan with Grype."
  "Run 'claude' (or 'ccode') to start Claude Code for terminal agentic coding."
  "Run 'doctor' for a quick tool check ('./ter.sh --doctor' runs the full audit)."
  "Use 'yazi' for lightning-fast async terminal file management with image previews."
  "Use 'btop' for real-time CPU, GPU, memory, and process telemetry."
  "Run 'cheat <keyword>' or '?' to search the built-in tactical reference manual."
  "Run 'hts config' to switch the welcome screen (full/compact/off) or the prompt."
)

_random_tip() {
  local idx=$(( RANDOM % ${#_PENTEST_TIPS[@]} ))
  echo "${_PENTEST_TIPS[$idx]}"
}

_get_local_ip() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "127.0.0.1"
  else
    hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1"
  fi
}

_get_vpn_info() {
  local ifaces=("ligolo" "tun0" "tun1" "utun1" "utun2" "utun3" "utun4" "wg0" "wg1" "ppp0")
  for iface in "${ifaces[@]}"; do
    if ifconfig "$iface" 2>/dev/null | grep -q "inet "; then
      local vpn_ip
      vpn_ip=$(ifconfig "$iface" 2>/dev/null | grep "inet " | awk '{print $2}' | head -1)
      [[ $_W_IPMODE == hide ]] && vpn_ip="x.x.x.x"
      echo -e "${_W_GREEN}● ACTIVE${_W_RESET} ${_W_DIM}(${iface}: ${vpn_ip})${_W_RESET}"
      return
    fi
  done
  echo -e "${_W_YELLOW}○ INACTIVE${_W_RESET}"
}

_get_proxy_info() {
  if [[ -n "$http_proxy" || -n "$HTTP_PROXY" ]]; then
    echo -e "${_W_GREEN}● ON${_W_RESET} ${_W_DIM}(${http_proxy:-$HTTP_PROXY})${_W_RESET}"
  elif lsof -nP -iTCP:8080 -sTCP:LISTEN &>/dev/null; then
    echo -e "${_W_CYAN}● LISTENER READY${_W_RESET} ${_W_DIM}(127.0.0.1:8080)${_W_RESET}"
  else
    echo -e "${_W_DIM}○ OFF (use 'proxyon')${_W_RESET}"
  fi
}

_get_ram_info() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    local page_size mem_used mem_total
    page_size=$(vm_stat 2>/dev/null | grep "page size of" | awk '{print $8}')
    [[ -z "$page_size" ]] && page_size=16384
    local pages_active pages_wired
    pages_active=$(vm_stat 2>/dev/null | grep "Pages active:" | awk '{print $3}' | tr -d '.')
    pages_wired=$(vm_stat 2>/dev/null | grep "Pages wired down:" | awk '{print $4}' | tr -d '.')
    mem_used=$(( (pages_active + pages_wired) * page_size / 1073741824 ))
    mem_total=$(( $(sysctl -n hw.memsize 2>/dev/null) / 1073741824 ))
    echo "${mem_used}G / ${mem_total}G"
  else
    free -h 2>/dev/null | awk '/^Mem:/ {print $3 " / " $2}' || echo "N/A"
  fi
}

_get_uptime_clean() {
  uptime 2>/dev/null | sed -E 's/^.+up +([^,]+), .*/\1/' || echo "N/A"
}

_show_welcome() {
  [[ $- != *i* ]] && return
  [[ -n "$VSCODE_INJECTION" ]] && return

  setopt localoptions extendedglob
  local local_ip vpn_info proxy_info ram_info uptime_str the_date tip_text os_label arch_label
  if [[ $_W_IPMODE == hide ]]; then
    local_ip="x.x.x.x"
  else
    local_ip=$(_get_local_ip)
  fi
  vpn_info=$(_get_vpn_info)
  proxy_info=$(_get_proxy_info)
  if [[ $_W_IPMODE == hide ]]; then   # mask any IPv4 address (tunnel, proxy URL)
    vpn_info=${vpn_info//[0-9]##.[0-9]##.[0-9]##.[0-9]##/x.x.x.x}
    proxy_info=${proxy_info//[0-9]##.[0-9]##.[0-9]##.[0-9]##/x.x.x.x}
  fi
  if [[ $_W_MODE == compact ]]; then
    local c_tip=""
    [[ $_W_TIPS == on ]] && c_tip=$(_random_tip)
    echo -e "${_W_BOLD}${_W_PURPLE}⚡ HTS${_W_RESET} ${_W_DIM}IP${_W_RESET} ${local_ip} ${_W_DIM}• Tunnel${_W_RESET} ${vpn_info} ${_W_DIM}• Proxy${_W_RESET} ${proxy_info}"
    [[ -n $c_tip ]] && echo -e "${_W_MAGENTA}💡${_W_RESET} ${_W_YELLOW}${c_tip}${_W_RESET}"
    return 0
  fi
  ram_info=$(_get_ram_info)
  uptime_str=$(_get_uptime_clean)
  the_date=$(date "+%a %d %b %H:%M")
  [[ $_W_TIPS == on ]] && tip_text=$(_random_tip)
  os_label="$(uname -s)"
  arch_label="$(uname -m)"

  echo ""
  echo -e "${_W_BOLD}${_W_CYAN}╭─────────────────────────────────────────────────────────────────────────────╮${_W_RESET}"
  echo -e "${_W_BOLD}${_W_CYAN}│${_W_RESET}  ${_W_BOLD}${_W_PURPLE}⚡ HACKER TERMINAL COCKPIT 2.0${_W_RESET}            ${_W_DIM}[${os_label} • ${arch_label} • ${the_date}]${_W_RESET}  ${_W_BOLD}${_W_CYAN}│${_W_RESET}"
  echo -e "${_W_BOLD}${_W_CYAN}├─────────────────────────────────────────────────────────────────────────────┤${_W_RESET}"
  printf "  ${_W_BOLD}%-35s${_W_RESET}  ${_W_BOLD}%-35s${_W_RESET}\n" "NETWORK & TUNNELS" "SYSTEM & TELEMETRY"
  printf "  ${_W_DIM}├─ Local IP :${_W_RESET} %-23s  ${_W_DIM}├─ Uptime :${_W_RESET} %-23s\n" "$local_ip" "$uptime_str"
  printf "  ${_W_DIM}├─ Tunnel   :${_W_RESET} %-34b  ${_W_DIM}├─ Memory :${_W_RESET} %-23s\n" "$vpn_info" "$ram_info"
  printf "  ${_W_DIM}└─ Proxy    :${_W_RESET} %-34b  ${_W_DIM}└─ Shell  :${_W_RESET} %-23s\n" "$proxy_info" "zsh ${ZSH_VERSION:-5.9}"
  echo -e "${_W_BOLD}${_W_CYAN}├─────────────────────────────────────────────────────────────────────────────┤${_W_RESET}"
  printf "  ${_W_BOLD}%-73s${_W_RESET}\n" "SECURITY & AGENTIC WORKSPACE"
  printf "  ${_W_DIM}├─ Active Dir :${_W_RESET} %-59s\n" "${PWD/#$HOME/~}"
  printf "  ${_W_DIM}├─ AI Tools   :${_W_RESET} ${_W_GREEN}Claude Code CLI${_W_RESET} ${_W_DIM}(ccode)${_W_RESET} • ${_W_CYAN}5 Sandboxed MCPs${_W_RESET} ${_W_DIM}(sec-mcp)${_W_RESET}\n"
  printf "  ${_W_DIM}└─ Quick Ref  :${_W_RESET} ${_W_YELLOW}cheat${_W_RESET} ${_W_DIM}(or ?)${_W_RESET} • ${_W_YELLOW}doctor${_W_RESET} • ${_W_YELLOW}bbrecon${_W_RESET} • ${_W_YELLOW}schematest${_W_RESET} • ${_W_YELLOW}hts config${_W_RESET}\n"
  if [[ $_W_TIPS == on ]]; then
    echo -e "${_W_BOLD}${_W_CYAN}├─────────────────────────────────────────────────────────────────────────────┤${_W_RESET}"

    local tip_wrapped
    tip_wrapped=$(echo "$tip_text" | fold -s -w 67)
    local first=1
    while IFS= read -r line; do
      if [[ $first -eq 1 ]]; then
        printf "  ${_W_MAGENTA}${_W_BOLD}💡 TIP:${_W_RESET} ${_W_YELLOW}%-67s${_W_RESET}\n" "$line"
        first=0
      else
        printf "         ${_W_YELLOW}%-67s${_W_RESET}\n" "$line"
      fi
    done <<< "$tip_wrapped"
  fi

  echo -e "${_W_BOLD}${_W_CYAN}╰─────────────────────────────────────────────────────────────────────────────╯${_W_RESET}"
  echo ""
}

_WELCOME_SHOWN=0
_welcome_once() {
  if [[ $_WELCOME_SHOWN -eq 0 ]]; then
    _WELCOME_SHOWN=1
    _show_welcome
    add-zsh-hook -d precmd _welcome_once
  fi
}
add-zsh-hook precmd _welcome_once
WELCOME_SCRIPT
  hts_track_file "$ZSH_CUSTOM/welcome.zsh"
}
