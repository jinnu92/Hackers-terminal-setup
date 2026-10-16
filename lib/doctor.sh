#!/usr/bin/env bash
# =============================================================================
#  lib/doctor.sh — Security Terminal Doctor & Diagnostic Audit
# =============================================================================

sec_doctor() {
  step "Security Terminal Doctor & Diagnostic Audit"
  echo ""
  echo -e "${BOLD}${CYAN}  ╔══════════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${CYAN}  ║           SECURITY TERMINAL ENVIRONMENT AUDIT                    ║${RESET}"
  echo -e "${BOLD}${CYAN}  ╚══════════════════════════════════════════════════════════════════╝${RESET}"
  echo ""

  _doc_item() {
    local name=$1
    local cmd=$2
    local ver_cmd=${3:-}
    if command -v "$cmd" &>/dev/null; then
      local ver=""
      [[ -n "$ver_cmd" ]] && ver=$(eval "$ver_cmd" 2>/dev/null | head -1)
      printf "  ${GREEN}[✓]${RESET} %-26s ${DIM}%s${RESET}\n" "$name" "$ver"
    else
      printf "  ${RED}[✗]${RESET} %-26s ${YELLOW}not installed${RESET}\n" "$name"
    fi
  }

  echo -e "${BOLD}${YELLOW}Core Shell & Terminal Ergonomics:${RESET}"
  _doc_item "Zsh Shell" "zsh" "zsh --version"
  _doc_item "Starship Prompt" "starship" "starship --version"
  _doc_item "Atuin (SQLite History)" "atuin" "atuin --version"
  _doc_item "direnv (Env Isolation)" "direnv" "direnv --version"
  _doc_item "Astral uv / uvx" "uv" "uv --version"
  _doc_item "btop (Resource Monitor)" "btop" "btop --version"
  _doc_item "tmux" "tmux" "tmux -V"
  _doc_item "fzf (Fuzzy Finder)" "fzf" "fzf --version"
  _doc_item "bat (Cat with wings)" "bat" "bat --version"
  _doc_item "eza (Modern ls)" "eza" "eza --version"
  _doc_item "zoxide (Smart cd)" "zoxide" "zoxide --version"
  _doc_item "ripgrep (rg)" "rg" "rg --version"
  _doc_item "fd (Modern find)" "fd" "fd --version"
  _doc_item "git-delta (Git diff)" "delta" "delta --version"
  _doc_item "yazi (File Manager)" "yazi" "yazi --version"

  echo -e "\n${BOLD}${YELLOW}GPU Terminal Emulators:${RESET}"
  _doc_item "Ghostty" "ghostty" "ghostty --version"
  _doc_item "WezTerm" "wezterm" "wezterm --version"
  _doc_item "Kitty" "kitty" "kitty --version"
  _doc_item "Alacritty" "alacritty" "alacritty --version"

  echo -e "\n${BOLD}${YELLOW}Developer & Agentic AI Stack:${RESET}"
  _doc_item "Node.js" "node" "node -v"
  _doc_item "npm" "npm" "npm -v"
  _doc_item "Claude Code CLI" "claude" "claude --version"
  _doc_item "Visual Studio Code" "code" "code --version"
  _doc_item "Go (Golang)" "go" "go version"
  _doc_item "Python 3" "python3" "python3 --version"
  _doc_item "pipx" "pipx" "pipx --version"
  _doc_item "sec-mcp (MCP Manager)" "sec-mcp" "echo 'ready'"
  _doc_item "MCP Inspector" "npx" "command -v npx &>/dev/null && echo 'ready via npx' || false"

  echo -e "\n${BOLD}${YELLOW}Offensive Security & Bug Bounty:${RESET}"
  _doc_item "nmap" "nmap" "nmap --version"
  _doc_item "nuclei" "nuclei" "nuclei -version"
  _doc_item "subfinder" "subfinder" "subfinder -version"
  _doc_item "httpx" "httpx" "httpx -version"
  _doc_item "katana" "katana" "katana -version"
  _doc_item "dnsx" "dnsx" "dnsx -version"
  _doc_item "ffuf" "ffuf" "ffuf -V"
  _doc_item "sqlmap" "sqlmap" "sqlmap --version"
  _doc_item "hydra" "hydra" "hydra -h 2>&1 | head -1"
  _doc_item "gobuster" "gobuster" "gobuster version"
  _doc_item "mitmproxy" "mitmproxy" "mitmproxy --version"

  echo -e "\n${BOLD}${YELLOW}Cloud & AI Security:${RESET}"
  _doc_item "AWS CLI" "aws" "aws --version"
  _doc_item "Azure CLI" "az" "az --version"
  _doc_item "Google Cloud SDK" "gcloud" "gcloud --version"
  _doc_item "trufflehog" "trufflehog" "trufflehog --version"
  _doc_item "gitleaks" "gitleaks" "gitleaks version"
  _doc_item "prowler" "prowler" "prowler -v"
  _doc_item "Ollama" "ollama" "ollama --version"
  _doc_item "Promptfoo" "promptfoo" "promptfoo --version"

  echo -e "\n${BOLD}${YELLOW}Workflow & Config Files:${RESET}"
  _doc_item "lazygit" "lazygit" "lazygit --version"
  _doc_item "jq" "jq" "jq --version"
  _doc_item "yq" "yq" "yq --version"
  _doc_item "GitHub CLI (gh)" "gh" "gh --version"

  # Dotfiles audit
  echo ""
  local dotfiles=(
    "$HOME/.zshrc"
    "$HOME/.tmux.conf"
    "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/pentest.zsh"
    "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/advanced_pentest.zsh"
    "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/welcome.zsh"
    "$HOME/.config/starship.toml"
    "$HOME/.config/atuin/config.toml"
    "$HOME/.config/ghostty/config"
    "$HOME/.config/wezterm/wezterm.lua"
  )
  for cfg in "${dotfiles[@]}"; do
    if [[ -f "$cfg" ]]; then
      printf "  ${GREEN}[✓]${RESET} %-26s ${DIM}found (${cfg})${RESET}\n" "$(basename "$cfg")"
    else
      printf "  ${RED}[✗]${RESET} %-26s ${YELLOW}missing${RESET}\n" "$(basename "$cfg")"
    fi
  done

  echo ""
  echo -e "${BOLD}${CYAN}  ════════════════════════════════════════════════════════════════════${RESET}"
}
