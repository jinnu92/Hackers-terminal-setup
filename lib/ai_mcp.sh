#!/usr/bin/env bash
# =============================================================================
#  lib/ai_mcp.sh — Preconfigured Safe MCP Server Suite & AI Integrations
# =============================================================================

install_ai_llm() {
  step "AI / LLM security tools"

  # Python tools
  for tool in garak llm jwt_tool; do
    pipx_install "$tool"
  done

  # Node & npm tools
  command -v node &>/dev/null || install_node
  npm_global_install promptfoo

  # Ollama — local LLM runtime
  if ! command -v ollama &>/dev/null; then
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install_cask ollama "" "https://ollama.ai"
    else
      log "Installing Ollama..."
      curl -fsSL https://ollama.ai/install.sh | sh || warn "Ollama install failed"
    fi
  else
    info "Ollama already installed"
  fi

  ok "AI/LLM security done"
}

setup_mcp_suite() {
  step "Preconfigured Safe MCP Server Suite (Claude Code & Claude Desktop)"

  command -v node &>/dev/null || install_node
  npm_global_install @modelcontextprotocol/inspector

  pipx_install semgrep 2>/dev/null || pkg_install semgrep
  pipx_install detect-secrets

  # 1. Ensure sandboxed project directories exist (NEVER expose $HOME or /)
  local workspace_dir="$HOME/workspace"
  local pentest_dir="$HOME/pentest"
  mkdir -p "$workspace_dir" "$pentest_dir"

  # 2. Determine Claude Desktop config path
  local claude_cfg_file=""
  if [[ "$OS" == "Darwin" ]]; then
    local claude_dir="$HOME/Library/Application Support/Claude"
    mkdir -p "$claude_dir"
    claude_cfg_file="$claude_dir/claude_desktop_config.json"
  else
    local claude_dir="$HOME/.config/Claude"
    mkdir -p "$claude_dir"
    claude_cfg_file="$claude_dir/claude_desktop_config.json"
  fi

  # Backup existing config if present
  if [[ -f "$claude_cfg_file" ]]; then
    cp "$claude_cfg_file" "${claude_cfg_file}.bak.$(date +%Y%m%d_%H%M%S)"
    info "Backed up existing Claude Desktop config to ${claude_cfg_file}.bak"
  fi

  log "Deploying preconfigured MCP Server Suite to Claude Desktop..."
  cat > "$claude_cfg_file" << EOF
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "$workspace_dir",
        "$pentest_dir"
      ]
    },
    "github": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-github"
      ],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": ""
      }
    },
    "fetch": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-fetch"
      ]
    },
    "brave-search": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-brave-search"
      ],
      "env": {
        "BRAVE_API_KEY": ""
      }
    },
    "memory": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-memory"
      ]
    }
  }
}
EOF
  ok "Claude Desktop MCP configuration generated: $claude_cfg_file"

  # 3. Deploy project-level .mcp.json template
  local project_mcp="$pentest_dir/.mcp.json"
  cat > "$project_mcp" << EOF
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "$pentest_dir"]
    },
    "fetch": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-fetch"]
    },
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"]
    }
  }
}
EOF
  ok "Project MCP template deployed: $project_mcp"

  # 4. Install sec-mcp helper utility
  mkdir -p "$HOME/.local/bin"
  cat > "$HOME/.local/bin/sec-mcp" << 'SECMCP'
#!/usr/bin/env bash
# =============================================================================
# sec-mcp — Security MCP Suite Manager
# =============================================================================
case "$1" in
  list|ls)
    echo -e "\033[1;36mActive MCP Servers:\033[0m"
    echo -e "  \033[0;32m[✓]\033[0m filesystem   (Sandboxed to ~/workspace & ~/pentest)"
    echo -e "  \033[0;32m[✓]\033[0m github       (GitHub PR, Repo, Issue integration)"
    echo -e "  \033[0;32m[✓]\033[0m fetch        (Fast web document reader)"
    echo -e "  \033[0;32m[✓]\033[0m brave-search (Real-time web search)"
    echo -e "  \033[0;32m[✓]\033[0m memory       (Persistent graph memory across sessions)"
    ;;
  inspect)
    echo -e "\033[1;36mLaunching MCP Inspector UI...\033[0m"
    npx @modelcontextprotocol/inspector
    ;;
  setup)
    echo -e "\033[1;36mRe-running MCP Suite setup...\033[0m"
    if command -v setup_mcp_suite &>/dev/null; then
      setup_mcp_suite
    else
      echo "Run './ter.sh --mcp' to configure."
    fi
    ;;
  *)
    echo "Usage: sec-mcp {list|inspect|setup}"
    ;;
esac
SECMCP
  chmod +x "$HOME/.local/bin/sec-mcp"
  ok "sec-mcp management CLI installed to ~/.local/bin/sec-mcp"
}

install_mcp() {
  setup_mcp_suite
}
