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
  read -r choices
  # Default to 'A' (all) if user presses Enter
  if [[ -z "$choices" ]]; then
    choices="A"
  fi
}

run_selections() {
  local input="$*"
  if [[ -z "$input" ]]; then
    input="A"
  fi

  local upper
  upper=$(echo "$input" | tr '[:lower:]' '[:upper:]')

  for token in $upper; do
    if [[ "$token" == "Q" || "$token" == "QUIT" || "$token" == "EXIT" ]]; then
      echo "Exiting."; exit 0
    fi
  done

  for token in $upper; do
    if [[ "$token" == "D" || "$token" == "DOC" || "$token" == "DOCTOR" || "$token" == "--DOCTOR" ]]; then
      sec_doctor
      exit 0
    fi
  done

  # Check if user asked for ALL or entered 'y' / 'yes' / '-y' / '--yes'
  local has_all=0
  local has_yes=0
  local has_other_components=0

  for token in $upper; do
    if [[ "$token" == "A" || "$token" == "ALL" || "$token" == "--ALL" || "$token" == "-A" ]]; then
      has_all=1
    elif [[ "$token" == "Y" || "$token" == "YES" || "$token" == "-Y" || "$token" == "--YES" ]]; then
      has_yes=1
    else
      has_other_components=1
    fi
  done

  # If "all" was chosen, OR if "yes/-y" was given without specifying individual component numbers:
  if [[ "$has_all" -eq 1 ]] || [[ "$has_yes" -eq 1 && "$has_other_components" -eq 0 ]]; then
    preflight
    install_core
    install_fonts "all"
    install_node
    install_claude
    install_code
    install_terminals
    install_shell_tools
    setup_mcp_suite
    install_pentest
    install_bugbounty
    install_ad_pivoting
    install_web_api
    install_cloud
    install_cloud_devsec
    install_mobile_re
    install_ai_llm
    install_workflow
    install_dashboard
    write_configs
    sec_doctor
    return
  fi

  preflight

  # Process individual items
  for item in $input; do
    case "$item" in
      -y|--yes|y|Y|yes|YES)              ;; # Unattended flag handled, ignore in loop
      1|--core)                          install_core ;;
      2|--fonts)                         install_fonts "all" ;;
      3|--node)                          install_node ;;
      4|--claude)                        install_claude ;;
      5|--code)                          install_code ;;
      dev|--dev)                         install_dev ;;
      6|--terminals|--gpu)               install_terminals ;;
      7|--shell-tools|--history)         install_shell_tools ;;
      8|--mcp)                           setup_mcp_suite ;;
      9|--pentest)                       install_pentest ;;
      10|--bugbounty)                    install_bugbounty ;;
      11|--ad-pivot|--ad|--pivoting)     install_ad_pivoting ;;
      12|--web-api|--api-sec|--api)      install_web_api ;;
      13|--cloud|--devsecops|--cloud-sec)
        install_cloud
        install_cloud_devsec
        ;;
      14|--mobile|--reverse|--re)        install_mobile_re ;;
      15|--ai)                           install_ai_llm ;;
      16|--workflow)                     install_workflow ;;
      17|--dashboard|--fastfetch)        install_dashboard ;;
      18|--config|--configs)             write_configs ;;
      19|d|D|--doctor)                   sec_doctor ;;
      *) warn "Unknown option: '$item' — skipping" ;;
    esac
  done
}
