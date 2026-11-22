#!/usr/bin/env bash
# =============================================================================
#  lib/menu.sh — Interactive Menu & CLI Argument Handler
# =============================================================================

show_menu() {
  clear 2>/dev/null || true
  echo ""
  echo -e "${BOLD}${CYAN}  ╔═══════════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${CYAN}  ║        SECURITY TERMINAL SETUP — BEST-IN-CLASS 2.0                ║${RESET}"
  echo -e "${BOLD}${CYAN}  ║        macOS / Linux — Unified Hacker & Developer Environment     ║${RESET}"
  echo -e "${BOLD}${CYAN}  ╠═══════════════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  Detected: ${BOLD}$DISTRO${RESET} ($ARCH) — pkg: ${BOLD}$PKG_MGR${RESET}"
  echo -e "${BOLD}${CYAN}  ╠═══════════════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${BOLD}Core & Developer Stack:${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}1${RESET}   Core terminal     ${DIM}OMZ plugins, p10k, fzf, bat, eza, tmux${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}2${RESET}   Hacker Fonts      ${DIM}MesloLGS, JetBrains Mono, Fira Code, Hack...${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}3${RESET}   Node.js & npm     ${DIM}Modern LTS Node.js + safe non-root npm prefix${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}4${RESET}   Claude Code CLI   ${DIM}Anthropic Claude Code agentic coding CLI tool${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}5${RESET}   VS Code & CLI     ${DIM}Visual Studio Code editor & 'code' CLI${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}6${RESET}   GPU Terminals     ${DIM}Ghostty, WezTerm, Kitty + aesthetic configs${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}7${RESET}   Shell History     ${DIM}Atuin SQLite history, direnv, uv, btop, yazi${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}8${RESET}   MCP Server Suite  ${DIM}Preconfigured Claude Code & Desktop MCP suite${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${BOLD}Security Assessment Suites:${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}9${RESET}   Pentest tools     ${DIM}nmap, sqlmap, hydra, john, gobuster, SecLists${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}10${RESET}  Bug bounty        ${DIM}subfinder, httpx, nuclei, amass, ffuf, katana${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}11${RESET}  Active Directory  ${DIM}Ligolo-ng, Chisel, NetExec, BloodHound, Certipy${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}12${RESET}  Web & API Sec     ${DIM}Schemathesis, Kiterunner, Caido, Arjun, FFUF${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}13${RESET}  Cloud & DevSecOps ${DIM}Trivy, Syft, Grype, Checkov, Kube-hunter, AWS${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}14${RESET}  Mobile & Reverse  ${DIM}Jadx, Apktool (DEX/APK decompilation & analysis)${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}15${RESET}  AI / LLM sec      ${DIM}garak, promptfoo, jwt_tool, ollama...${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}16${RESET}  Workflow tools    ${DIM}lazygit, jq, yq, gh, pandoc, obsidian...${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}17${RESET}  Tactical Cockpit  ${DIM}Fastfetch + Modern Welcome Terminal Cockpit${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}18${RESET}  Config files      ${DIM}.zshrc, pentest.zsh, welcome.zsh, .tmux.conf${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}19${RESET}  System Doctor     ${DIM}Audit and verify all installed tools${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${YELLOW}A${RESET} / ${YELLOW}Y${RESET}   Install everything (Recommended full assessment setup / unattended)"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${CYAN}D${RESET}       Run System Doctor only"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${RED}Q${RESET}       Quit"
  echo -e "${BOLD}${CYAN}  ║${RESET}"
  echo -e "${BOLD}${CYAN}  ╚═══════════════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "  ${DIM}Enter choices separated by spaces (e.g: 1 2 4 6 7 8 11 12 17 18), 'A' or 'y' for all [default: A]:${RESET}"
  echo -ne "  ${BOLD}> ${RESET}"
  if [[ "${_HTS_PIPED:-0}" == "1" ]]; then
    # Script text is arriving on stdin (curl | bash): read the answer from the terminal.
    if { exec 3</dev/tty; } 2>/dev/null; then
      read -r choices <&3 || choices=""
      exec 3<&-
    else
      echo "" >&2
      echo -e "  ${RED}[-] Cannot show the interactive menu: no terminal available (script is being piped).${RESET}" >&2
      echo "      Pass flags instead, e.g.: curl -fsSL <url>/ter.sh | bash -s -- --all" >&2
      echo "      See: curl -fsSL <url>/ter.sh | bash -s -- --help" >&2
      exit 1
    fi
  else
    read -r choices
  fi
  # Default to 'A' (all) if user presses Enter
  if [[ -z "$choices" ]]; then
    choices="A"
  fi
}


# ─── Component table ──────────────────────────────────────────────────────────
# Install order for --all (dev and seclists are covered by other components).
HTS_ALL_IDS="core fonts node claude code terminals shell-tools mcp pentest bugbounty ad-pivot web-api cloud mobile ai workflow dashboard config doctor"
# Full list for --list (includes the components that have no menu number).
HTS_LIST_IDS="core fonts node claude code dev terminals shell-tools mcp pentest seclists bugbounty ad-pivot web-api cloud mobile ai workflow dashboard config doctor"

# Install function for the combined Cloud & DevSecOps component.
hts_install_cloud_suite() {
  local rc=0
  install_cloud || rc=1
  install_cloud_devsec || rc=1
  return "$rc"
}

# Map one (lower-case) token to a component id. Prints the id; fails if unknown.
hts_resolve_token() {
  case "$1" in
    1|--core|core)                          echo core ;;
    2|--fonts)                              echo fonts ;;
    3|--node)                               echo node ;;
    4|--claude)                             echo claude ;;
    5|--code)                               echo code ;;
    dev|--dev)                              echo dev ;;
    6|--terminals|--gpu)                    echo terminals ;;
    7|--shell-tools|--history)              echo shell-tools ;;
    8|--mcp)                                echo mcp ;;
    9|--pentest)                            echo pentest ;;
    --seclists|--wordlists)                 echo seclists ;;
    10|--bugbounty)                         echo bugbounty ;;
    11|--ad-pivot|--ad|--pivoting)          echo ad-pivot ;;
    12|--web-api|--api-sec|--api)           echo web-api ;;
    13|--cloud|--devsecops|--cloud-sec)     echo cloud ;;
    14|--mobile|--reverse|--re)             echo mobile ;;
    15|--ai)                                echo ai ;;
    16|--workflow)                          echo workflow ;;
    17|--dashboard|--fastfetch)             echo dashboard ;;
    18|--config|--configs)                  echo config ;;
    19|d|doc|doctor|--doctor|-d)            echo doctor ;;
    *) return 1 ;;
  esac
}

# Fill HTS_C_* for a component id:
#   NUM FLAG NAME DESC CMD (function + args) INSTALLS WRITES
hts_comp_info() {
  HTS_C_NUM="-"; HTS_C_FLAG=""; HTS_C_NAME=""; HTS_C_DESC=""; HTS_C_CMD=""; HTS_C_INSTALLS=""; HTS_C_WRITES=""
  case "$1" in
    core)
      HTS_C_NUM=1; HTS_C_FLAG="--core"; HTS_C_NAME="Core terminal"; HTS_C_CMD="install_core"
      HTS_C_DESC="OMZ plugins, p10k, fzf, bat, eza, tmux"
      HTS_C_INSTALLS="fzf bat eza zoxide git-delta tmux fd ripgrep tldr; Meslo Nerd Font; zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions; Powerlevel10k; lazygit via Go on Linux"
      HTS_C_WRITES="~/.oh-my-zsh/custom/plugins/*, ~/.oh-my-zsh/custom/themes/powerlevel10k, font files" ;;
    fonts)
      HTS_C_NUM=2; HTS_C_FLAG="--fonts"; HTS_C_NAME="Hacker Fonts"; HTS_C_CMD="install_fonts all"
      HTS_C_DESC="MesloLGS, JetBrains Mono, Fira Code, Hack..."
      HTS_C_INSTALLS="Nerd Fonts: Meslo, JetBrains Mono, Fira Code, Hack and others"
      HTS_C_WRITES="font files (macOS casks / ~/Library/Fonts, Linux ~/.local/share/fonts/NerdFonts)" ;;
    node)
      HTS_C_NUM=3; HTS_C_FLAG="--node"; HTS_C_NAME="Node.js & npm"; HTS_C_CMD="install_node"
      HTS_C_DESC="Modern LTS Node.js + safe non-root npm prefix"
      HTS_C_INSTALLS="Node.js (18+) and npm via the system package manager"
      HTS_C_WRITES="npm global prefix ~/.npm-global (npm config), ~/.npm-global/bin" ;;
    claude)
      HTS_C_NUM=4; HTS_C_FLAG="--claude"; HTS_C_NAME="Claude Code CLI"; HTS_C_CMD="install_claude"
      HTS_C_DESC="Anthropic Claude Code agentic coding CLI tool"
      HTS_C_INSTALLS="Claude Code via the official native installer (stable channel); no Node.js needed"
      HTS_C_WRITES="~/.local/bin/claude and ~/.local/share/claude" ;;
    code)
      HTS_C_NUM=5; HTS_C_FLAG="--code"; HTS_C_NAME="VS Code & CLI"; HTS_C_CMD="install_code"
      HTS_C_DESC="Visual Studio Code editor & 'code' CLI"
      HTS_C_INSTALLS="Visual Studio Code (cask or distro package)"
      HTS_C_WRITES="~/.local/bin/code symlink" ;;
    dev)
      HTS_C_NUM="-"; HTS_C_FLAG="--dev"; HTS_C_NAME="Developer stack"; HTS_C_CMD="install_dev"
      HTS_C_DESC="Node.js + Claude Code + VS Code"
      HTS_C_INSTALLS="Node.js, @anthropic-ai/claude-code, Visual Studio Code"
      HTS_C_WRITES="~/.npm-global, ~/.local/bin/code symlink" ;;
    terminals)
      HTS_C_NUM=6; HTS_C_FLAG="--terminals"; HTS_C_NAME="GPU Terminals"; HTS_C_CMD="install_terminals"
      HTS_C_DESC="Ghostty, WezTerm, Kitty + aesthetic configs"
      HTS_C_INSTALLS="Ghostty (macOS) or Kitty/WezTerm/Ghostty depending on distro"
      HTS_C_WRITES="~/.config/ghostty/config and themes/catppuccin-mocha, ~/.config/wezterm/wezterm.lua, ~/.config/kitty/kitty.conf, ~/.config/alacritty/alacritty.toml" ;;
    shell-tools)
      HTS_C_NUM=7; HTS_C_FLAG="--shell-tools"; HTS_C_NAME="Shell History"; HTS_C_CMD="install_shell_tools"
      HTS_C_DESC="Atuin SQLite history, direnv, uv, btop, yazi, Starship"
      HTS_C_INSTALLS="atuin, direnv, uv, btop, yazi, git-delta, eza, zoxide, ripgrep, fzf, bat, fd, starship"
      HTS_C_WRITES="~/.config/atuin/config.toml, ~/.config/direnv/direnv.toml, ~/.config/starship.toml" ;;
    mcp)
      HTS_C_NUM=8; HTS_C_FLAG="--mcp"; HTS_C_NAME="MCP Server Suite"; HTS_C_CMD="setup_mcp_suite"
      HTS_C_DESC="Preconfigured Claude Code & Desktop MCP suite"
      HTS_C_INSTALLS="Node.js if missing; @modelcontextprotocol/inspector (npm); semgrep and detect-secrets (pipx)"
      HTS_C_WRITES="~/workspace and ~/pentest directories, Claude Desktop claude_desktop_config.json (macOS: ~/Library/Application Support/Claude, Linux: ~/.config/Claude), ~/pentest/.mcp.json, ~/.local/bin/sec-mcp" ;;
    pentest)
      HTS_C_NUM=9; HTS_C_FLAG="--pentest"; HTS_C_NAME="Pentest tools"; HTS_C_CMD="install_pentest"
      HTS_C_DESC="nmap, sqlmap, hydra, john, gobuster, SecLists"
      HTS_C_INSTALLS="nmap netcat wget curl httpie gobuster hydra sqlmap masscan tcpdump openssl gpg python3 pipx john hashcat (wireshark-cli on Linux); impacket, pwntools, scapy, netexec (pipx); SecLists"
      HTS_C_WRITES="~/pentest/wordlists/seclists" ;;
    seclists)
      HTS_C_NUM="-"; HTS_C_FLAG="--seclists"; HTS_C_NAME="SecLists"; HTS_C_CMD="install_seclists"
      HTS_C_DESC="Download SecLists wordlists from GitHub"
      HTS_C_INSTALLS="SecLists wordlist collection (git clone)"
      HTS_C_WRITES="~/pentest/wordlists/seclists" ;;
    bugbounty)
      HTS_C_NUM=10; HTS_C_FLAG="--bugbounty"; HTS_C_NAME="Bug bounty"; HTS_C_CMD="install_bugbounty"
      HTS_C_DESC="subfinder, httpx, nuclei, amass, ffuf, katana"
      HTS_C_INSTALLS="subfinder httpx nuclei katana dnsx interactsh-client gau hakrawler waybackurls amass dalfox (go install); Burp Suite and Caido (macOS casks); arjun (pipx)"
      HTS_C_WRITES="~/go/bin, nuclei templates" ;;
    ad-pivot)
      HTS_C_NUM=11; HTS_C_FLAG="--ad-pivot"; HTS_C_NAME="Active Directory"; HTS_C_CMD="install_ad_pivoting"
      HTS_C_DESC="Ligolo-ng, Chisel, NetExec, BloodHound, Certipy"
      HTS_C_INSTALLS="Ligolo-ng, Chisel (go install), NetExec, BloodHound, Certipy (uv or pipx)"
      HTS_C_WRITES="~/.local/bin, ~/go/bin" ;;
    web-api)
      HTS_C_NUM=12; HTS_C_FLAG="--web-api"; HTS_C_NAME="Web & API Sec"; HTS_C_CMD="install_web_api"
      HTS_C_DESC="Schemathesis, Kiterunner, Caido, Arjun, FFUF"
      HTS_C_INSTALLS="Schemathesis, Arjun (uv or pipx); Kiterunner (go install); Caido; ffuf, feroxbuster"
      HTS_C_WRITES="~/go/bin, ~/.local/bin" ;;
    cloud)
      HTS_C_NUM=13; HTS_C_FLAG="--cloud"; HTS_C_NAME="Cloud & DevSecOps"; HTS_C_CMD="hts_install_cloud_suite"
      HTS_C_DESC="AWS/Azure/gcloud CLIs, Trivy, Syft, Grype, Checkov, Kube-hunter, prowler"
      HTS_C_INSTALLS="awscli, azure-cli, google-cloud-sdk; cloudfox, gitleaks, trufflehog (go install); prowler, pacu, s3scanner, checkov, kube-hunter (pipx/uv); Trivy, Syft, Grype"
      HTS_C_WRITES="~/.local/bin, ~/go/bin" ;;
    mobile)
      HTS_C_NUM=14; HTS_C_FLAG="--mobile"; HTS_C_NAME="Mobile & Reverse"; HTS_C_CMD="install_mobile_re"
      HTS_C_DESC="Jadx, Apktool (DEX/APK decompilation & analysis)"
      HTS_C_INSTALLS="jadx, apktool"
      HTS_C_WRITES="~/.local/share/jadx and ~/.local/bin links (Linux fallback only)" ;;
    ai)
      HTS_C_NUM=15; HTS_C_FLAG="--ai"; HTS_C_NAME="AI / LLM sec"; HTS_C_CMD="install_ai_llm"
      HTS_C_DESC="garak, promptfoo, jwt_tool, ollama..."
      HTS_C_INSTALLS="garak, llm, jwt_tool (pipx); promptfoo (npm); Node.js if missing; Ollama"
      HTS_C_WRITES="~/.npm-global" ;;
    workflow)
      HTS_C_NUM=16; HTS_C_FLAG="--workflow"; HTS_C_NAME="Workflow tools"; HTS_C_CMD="install_workflow"
      HTS_C_DESC="lazygit, jq, yq, gh, pandoc, obsidian..."
      HTS_C_INSTALLS="jq gh pandoc yq lazygit xh yazi, Obsidian (macOS cask)"
      HTS_C_WRITES="git global config (delta pager settings in ~/.gitconfig), ~/.local/bin" ;;
    dashboard)
      HTS_C_NUM=17; HTS_C_FLAG="--dashboard"; HTS_C_NAME="Tactical Cockpit"; HTS_C_CMD="install_dashboard"
      HTS_C_DESC="Fastfetch + Modern Welcome Terminal Cockpit"
      HTS_C_INSTALLS="fastfetch"
      HTS_C_WRITES="~/.config/fastfetch/config.jsonc, ~/.oh-my-zsh/custom/welcome.zsh" ;;
    config)
      HTS_C_NUM=18; HTS_C_FLAG="--config"; HTS_C_NAME="Config files"; HTS_C_CMD="write_configs"
      HTS_C_DESC=".zshrc, pentest.zsh, welcome.zsh, .tmux.conf"
      HTS_C_INSTALLS="(nothing; writes configuration only)"
      HTS_C_WRITES="~/.zshrc (existing file is backed up first), ~/.oh-my-zsh/custom/pentest.zsh, advanced_pentest.zsh, welcome.zsh, ~/.tmux.conf" ;;
    doctor)
      HTS_C_NUM=19; HTS_C_FLAG="--doctor"; HTS_C_NAME="System Doctor"; HTS_C_CMD="sec_doctor"
      HTS_C_DESC="Audit and verify all installed tools"
      HTS_C_INSTALLS="(nothing; read-only audit)"
      HTS_C_WRITES="(nothing)" ;;
    *) return 1 ;;
  esac
}

# Prerequisites (ensure_* functions) a component needs, space separated, from:
# omz ssh pipx go. Derived by reading each install_* function.
hts_prereqs_for() {
  local os="${OS:-$(uname -s)}"
  case "$1" in
    core)      if [[ "$os" == "Linux" ]]; then echo "omz go"; else echo "omz"; fi ;;
    workflow)  if [[ "$os" == "Linux" ]]; then echo "go"; fi ;;
    mcp|pentest|ai)  echo "pipx" ;;
    bugbounty|ad-pivot|web-api|cloud) echo "pipx go" ;;
    dashboard) echo "omz" ;;
    config)    echo "omz ssh" ;;
    *)         : ;;   # fonts node claude code dev terminals shell-tools seclists mobile doctor
  esac
  return 0
}

# Parse tokens into: HTS_SEL (ids, ordered, unique), HTS_SEL_ALL, HTS_SEL_YES,
# HTS_SEL_QUIT, HTS_BAD (unknown tokens). Sets HTS_DRY_RUN for --dry-run / -n.
hts_parse_selection() {
  HTS_SEL=""; HTS_SEL_ALL=0; HTS_SEL_YES=0; HTS_SEL_QUIT=0; HTS_BAD=""
  local tok low id
  for tok in "$@"; do
    low="$(printf '%s' "$tok" | tr '[:upper:]' '[:lower:]')"
    case "$low" in
      "")                          continue ;;
      -y|--yes|y|yes)              HTS_SEL_YES=1; continue ;;
      a|all|-a|--all)              HTS_SEL_ALL=1; continue ;;
      q|quit|exit)                 HTS_SEL_QUIT=1; continue ;;
      -n|--dry-run|dry-run)        HTS_DRY_RUN=1; continue ;;
    esac
    if id="$(hts_resolve_token "$low")"; then
      case " $HTS_SEL " in
        *" $id "*) ;;
        *) HTS_SEL="${HTS_SEL:+$HTS_SEL }$id" ;;
      esac
    else
      HTS_BAD="${HTS_BAD:+$HTS_BAD }$tok"
    fi
  done
}

# Drop node/claude/code from a selection that already contains dev.
hts_dedupe_dev() {
  case " $1 " in
    *" dev "*)
      local out="" id
      for id in $1; do
        case "$id" in node|claude|code) continue ;; esac
        out="${out:+$out }$id"
      done
      echo "$out" ;;
    *) echo "$1" ;;
  esac
}

# --list: component table, touches nothing
hts_list_components() {
  local id
  echo ""
  echo -e "${BOLD}${CYAN}Hackers Terminal Setup $HTS_VERSION — components${RESET}"
  echo ""
  printf '  %-3s  %-14s  %-20s  %s\n' "No." "Flag" "Name" "Contents"
  printf '  %-3s  %-14s  %-20s  %s\n' "---" "--------------" "--------------------" "--------"
  for id in $HTS_LIST_IDS; do
    hts_comp_info "$id"
    printf '  %-3s  %-14s  %-20s  %s\n' "$HTS_C_NUM" "$HTS_C_FLAG" "$HTS_C_NAME" "$HTS_C_DESC"
  done
  echo ""
  echo "  --all installs every numbered component. Combine with --dry-run to preview."
  echo ""
}

# --dry-run: describe, change nothing
hts_dry_run_report() {
  local id pre p
  echo ""
  echo -e "${BOLD}${CYAN}Hackers Terminal Setup $HTS_VERSION — DRY RUN${RESET}"
  echo -e "${DIM}Nothing will be installed, written or changed.${RESET}"
  echo ""
  echo -e "  ${BOLD}Base preflight${RESET} (runs before any real install)"
  echo "    checks Xcode CLT / Homebrew (macOS) or the package manager, free disk space;"
  echo "    creates ~/.local/bin and the state dir (${HTS_STATE_DIR}); backs up ~/.zshrc"
  for id in $1; do
    hts_comp_info "$id" || continue
    echo ""
    echo -e "  ${BOLD}${GREEN}${HTS_C_NAME}${RESET} (${HTS_C_FLAG})"
    pre="$(hts_prereqs_for "$id")"
    if [[ -n "$pre" ]]; then
      echo -n "    prerequisites:"
      for p in $pre; do
        case "$p" in
          omz)  echo -n " zsh+Oh-My-Zsh" ;;
          ssh)  echo -n " ~/.ssh" ;;
          pipx) echo -n " pipx" ;;
          go)   echo -n " Go" ;;
        esac
      done
      echo ""
    fi
    echo "    would install: $HTS_C_INSTALLS"
    echo "    would write:   $HTS_C_WRITES"
  done
  echo ""
  echo -e "  ${BOLD}${YELLOW}Dry run complete — nothing was changed.${RESET}"
  echo ""
}

# Run one prerequisite through run_step
hts_run_prereq() {
  case "$1" in
    omz)  run_step "Prerequisite: zsh + Oh My Zsh" ensure_omz ;;
    ssh)  run_step "Prerequisite: ~/.ssh" ensure_ssh_dir ;;
    pipx) run_step "Prerequisite: pipx" ensure_pipx ;;
    go)   run_step "Prerequisite: Go" ensure_go ;;
  esac
}

# Run one component through run_step, record a manifest line on success
hts_run_component() {
  local id=$1 rc=0
  local -a cmd
  hts_comp_info "$id" || return 1
  read -r -a cmd <<< "$HTS_C_CMD"
  run_step "$HTS_C_NAME" "${cmd[@]}" || rc=$?
  if [[ $rc -eq 0 && "$id" != "doctor" ]]; then
    hts_manifest_add component "$HTS_C_FLAG" "$HTS_C_NAME"
  fi
  return "$rc"
}

# Final banner; reflects the result
hts_print_banner() {
  local rc=${1:-0}
  echo ""
  if [[ "$rc" -eq 0 ]]; then
    echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${GREEN}  Setup Complete!${RESET}"
    echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════════════════════${RESET}"
  else
    echo -e "${BOLD}${YELLOW}════════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${YELLOW}  Setup finished, but some steps failed — see the summary above${RESET}"
    echo -e "${BOLD}${YELLOW}  Details: ${HTS_LOG}${RESET}"
    echo -e "${BOLD}${YELLOW}════════════════════════════════════════════════════════════════════${RESET}"
  fi
  echo ""
  echo -e "  ${CYAN}Next steps:${RESET}"
  echo -e "  1. ${YELLOW}Set terminal font:${RESET}  'MesloLGS NF' (p10k) or 'JetBrainsMono Nerd Font'"
  echo -e "  2. ${YELLOW}Reload shell:${RESET}       ${BOLD}exec zsh${RESET}"
  echo -e "  3. ${YELLOW}Configure prompt:${RESET}   ${BOLD}p10k configure${RESET} (or Starship: ${BOLD}starship.toml${RESET})"
  echo -e "  4. ${YELLOW}Start Claude Code:${RESET}  ${BOLD}claude${RESET} (or ${BOLD}cc${RESET})"
  echo -e "  5. ${YELLOW}Manage MCP suite:${RESET}   ${BOLD}sec-mcp list${RESET} or ${BOLD}sec-mcp inspect${RESET}"
  echo -e "  6. ${YELLOW}Run Atuin history:${RESET}  ${BOLD}Ctrl+R${RESET} (scrubs tokens automatically)"
  echo -e "  7. ${YELLOW}Run System Doctor:${RESET}  ${BOLD}doctor${RESET} (or ${BOLD}sec-doctor${RESET})"
  echo -e "  8. ${YELLOW}Open cheat sheet:${RESET}   ${BOLD}cheat${RESET} or ${BOLD}?${RESET}"
  echo ""
}

# Resolve + validate the whole selection first, then act.
# Sets HTS_RUN_RC (exit status for the script) and HTS_SHOW_BANNER (0/1).
run_selections() {
  HTS_RUN_RC=0
  HTS_SHOW_BANNER=0
  local -a toks
  read -r -a toks <<< "$*"
  [[ ${#toks[@]} -gt 0 ]] || toks=(A)

  hts_parse_selection "${toks[@]}"

  if [[ "$HTS_SEL_QUIT" -eq 1 ]]; then
    echo "Exiting."; exit 0
  fi

  if [[ -n "$HTS_BAD" ]]; then
    local bad
    for bad in $HTS_BAD; do
      err "Unknown option: '$bad'"
    done
    err "Nothing was changed. Run with --help to see valid options, or --list for components."
    exit 2
  fi

  # Resolve the selection to a list of component ids
  local ids
  if [[ "$HTS_SEL_ALL" -eq 1 || -z "$HTS_SEL" ]]; then
    ids="$HTS_ALL_IDS"
  else
    ids="$(hts_dedupe_dev "$HTS_SEL")"
    # The doctor audit always runs last, wherever it was given
    case " $ids " in
      *" doctor "*)
        local _rest="" _i
        for _i in $ids; do
          [[ "$_i" == "doctor" ]] || _rest="${_rest:+$_rest }$_i"
        done
        ids="${_rest:+$_rest }doctor" ;;
    esac
  fi

  # Dry run is a hard short-circuit: no preflight, no install function, no state dir.
  if [[ "$HTS_DRY_RUN" -eq 1 ]]; then
    hts_dry_run_report "$ids"
    exit 0
  fi

  [[ -n "${OS:-}" ]] || detect_os

  local id pre p prereqs="" doctor_only=1
  for id in $ids; do
    [[ "$id" == "doctor" ]] || doctor_only=0
    for p in $(hts_prereqs_for "$id"); do
      case " $prereqs " in *" $p "*) ;; *) prereqs="${prereqs:+$prereqs }$p" ;; esac
    done
  done

  if [[ "$doctor_only" -eq 0 ]]; then
    hts_state_init
    if ! run_step "Preflight: base system" preflight_base; then
      err "Base preflight failed — cannot continue."
      hts_print_summary || true
      HTS_RUN_RC=1
      return 0
    fi
    # Canonical order, only what the selection needs
    for p in omz ssh pipx go; do
      case " $prereqs " in *" $p "*) hts_run_prereq "$p" || true ;; esac
    done
    hts_export_paths
    HTS_SHOW_BANNER=1
  fi

  for id in $ids; do
    hts_run_component "$id" || true
  done

  hts_print_summary || HTS_RUN_RC=1
  return 0
}
