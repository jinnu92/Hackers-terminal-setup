#!/usr/bin/env bash
# =============================================================================
#  lib/menu.sh — Interactive Menu & CLI Argument Handler
# =============================================================================

show_menu() {
  clear
  echo ""
  echo -e "${BOLD}${CYAN}  ╔═══════════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${CYAN}  ║        SECURITY TERMINAL SETUP — BEST-IN-CLASS 2.0                ║${RESET}"
  echo -e "${BOLD}${CYAN}  ║        macOS / Linux — Unified Hacker & Developer Environment     ║${RESET}"
  echo -e "${BOLD}${CYAN}  ╠═══════════════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  Detected: ${BOLD}$DISTRO${RESET} ($ARCH) — pkg: ${BOLD}$PKG_MGR${RESET}"
  echo -e "${BOLD}${CYAN}  ╠═══════════════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${BOLD}Select components to install:${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}1${RESET}   Core terminal     ${DIM}OMZ plugins, p10k, fzf, bat, eza, tmux${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}2${RESET}   Hacker Fonts      ${DIM}MesloLGS, JetBrains Mono, Fira Code, Hack...${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}3${RESET}   Node.js & npm     ${DIM}Modern LTS Node.js + safe non-root npm prefix${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}4${RESET}   Claude Code CLI   ${DIM}Anthropic Claude Code agentic coding CLI tool${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}5${RESET}   VS Code & CLI     ${DIM}Visual Studio Code editor & 'code' CLI${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}6${RESET}   GPU Terminals     ${DIM}Ghostty, WezTerm, Kitty + aesthetic configs${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}7${RESET}   Shell History     ${DIM}Atuin SQLite history, direnv, uv, btop, yazi${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}8${RESET}   MCP Server Suite  ${DIM}Preconfigured Claude Code & Desktop MCP suite${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}9${RESET}   Pentest tools     ${DIM}nmap, sqlmap, hydra, john, gobuster, SecLists${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}10${RESET}  Bug bounty        ${DIM}subfinder, httpx, nuclei, amass, ffuf, katana${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}11${RESET}  Cloud security    ${DIM}awscli, azure, gcloud, prowler, gitleaks...${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}12${RESET}  AI / LLM sec      ${DIM}garak, promptfoo, jwt_tool, ollama...${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}13${RESET}  Workflow tools    ${DIM}lazygit, jq, yq, gh, pandoc, obsidian...${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}14${RESET}  Config files      ${DIM}.zshrc, pentest.zsh, welcome.zsh, .tmux.conf${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${GREEN}15${RESET}  System Doctor     ${DIM}Audit and verify all installed tools${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${YELLOW}A${RESET}   Install everything (Recommended for new setup)"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${CYAN}D${RESET}   Run System Doctor only"
  echo -e "${BOLD}${CYAN}  ║${RESET}  ${RED}Q${RESET}   Quit"
  echo -e "${BOLD}${CYAN}  ║${RESET}"
  echo -e "${BOLD}${CYAN}  ╚═══════════════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "  ${DIM}Enter choices separated by spaces (e.g: 1 2 3 4 5 6 7 8 14) or A for all:${RESET}"
  echo -ne "  ${BOLD}> ${RESET}"
  read -r choices
}

run_selections() {
  local input="$*"
  [[ -z "$input" ]] && { echo "No components selected. Exiting."; exit 0; }

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

  preflight

  for token in $upper; do
    if [[ "$token" == "A" || "$token" == "ALL" || "$token" == "--ALL" || "$token" == "-A" ]]; then
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
      install_cloud
      install_ai_llm
      install_workflow
      write_configs
      sec_doctor
      return
    fi
  done

  # Process individual items
  for item in $input; do
    case "$item" in
      1|--core)                  install_core ;;
      2|--fonts)                 install_fonts "all" ;;
      3|--node)                  install_node ;;
      4|--claude)                install_claude ;;
      5|--code)                  install_code ;;
      dev|--dev)                 install_dev ;;
      6|--terminals|--gpu)       install_terminals ;;
      7|--shell-tools|--history) install_shell_tools ;;
      8|--mcp)                   setup_mcp_suite ;;
      9|--pentest)               install_pentest ;;
      10|--bugbounty)            install_bugbounty ;;
      11|--cloud)                install_cloud ;;
      12|--ai)                   install_ai_llm ;;
      13|--workflow)             install_workflow ;;
      14|--config|--configs)     write_configs ;;
      15|d|D|--doctor)           sec_doctor ;;
      *) warn "Unknown option: '$item' — skipping" ;;
    esac
  done
}
