# Hackers Terminal Setup — Best-in-Class 2.0

A high-performance security testing, development, and agentic AI terminal environment for macOS and Linux.

Featuring modular architecture (`lib/`), an interactive visual simulator (`terminal_preview.html`), modern GPU terminal emulators (Ghostty, WezTerm, Kitty), encrypted SQLite shell history with secret scrubbing (Atuin), directory environment isolation (direnv), ultra-fast tool execution (Astral `uv`/`uvx`), preconfigured Model Context Protocol (MCP) servers for Claude Code, and complete offensive security & bug bounty pipelines.

---

## 🎨 Interactive Visual Terminal Preview

Before installing, you can explore the look, feel, prompt themes, GPU configs, and capabilities in your browser:

```bash
# Open in default browser
open terminal_preview.html        # macOS
xdg-open terminal_preview.html    # Linux
```

The interactive preview includes:
1. **Daily Dev Shell**: Live simulation of Starship/p10k, zsh-autosuggestions, zoxide smart cd, eza, and delta diffs.
2. **Claude Code & MCP Agent**: Anthropic agent session demonstrating safe filesystem tool execution and vulnerability remediation.
3. **GPU Terminal Matrix**: Side-by-side configurations and keybindings for Ghostty, WezTerm, and Kitty.
4. **Modern Rust Tools**: Interactive visualization of `btop` process monitor, `yazi` file manager, and `atuin` history search.
5. **Pentest & Recon Pipeline**: Full run output of `bbrecon`, `nuclei`, and secret scanning.
6. **Custom Profile Builder**: Interactive checklist to toggle tools according to your day-to-day usages and copy the tailored installer command.

---

## 🚀 Quick Start

### Interactive Menu
```bash
git clone https://github.com/jinnu92/Hackers-terminal-setup.git
cd Hackers-terminal-setup
chmod +x ter.sh
./ter.sh
```

Choose individual components by number (e.g. `1 2 3 4 5 6 7 8 14`), or type `A` to install everything.

### Command-Line Automation (CLI Flags)
Run `ter.sh` non-interactively with flags:

```bash
./ter.sh --all               # Install complete environment + tools + configs
./ter.sh --fonts             # Install all recommended Nerd Fonts
./ter.sh --dev               # Install Node.js LTS + Claude Code CLI + VS Code
./ter.sh --terminals         # Install Ghostty, WezTerm, Kitty & aesthetic configs
./ter.sh --shell-tools       # Install Atuin (SQLite history), direnv, uv, btop, yazi, Starship
./ter.sh --mcp               # Install preconfigured safe MCP Server Suite & sec-mcp CLI
./ter.sh --doctor            # Run environment audit & health check dashboard
./ter.sh --fonts --dev --mcp # Combine flags freely
./ter.sh --help              # Show help and all CLI options
```

---

## 📦 Modular Architecture (`lib/`) & Standalone Compiler

The project is structured with clean separation of concerns:

```
Hackers-terminal-setup/
├── ter.sh                # Universal entrypoint (dual-mode: sources lib/ or runs bundled)
├── bundle.sh             # Compiler: joins lib/*.sh into a standalone curl-pipeable script
├── terminal_preview.html # Interactive visual showcase and profile builder
└── lib/
    ├── common.sh         # Colors, logging, banners, OS detection
    ├── pkg_mgr.sh        # Brew, apt, dnf, pacman unified wrapper & resolution
    ├── helpers.sh        # Go, pipx, npm global prefix isolation
    ├── preflight.sh      # Dependency checks, disk space, Homebrew bootstrap
    ├── fonts.sh          # Modern Nerd Fonts multi-distro installer
    ├── dev.sh            # Node.js LTS, Claude Code CLI, VS Code editor
    ├── terminals.sh      # Ghostty, WezTerm, Kitty, Alacritty + aesthetic configs
    ├── shell_tools.sh    # Atuin, direnv, uv/uvx, btop, yazi, delta, Starship prompt
    ├── pentest.sh        # Core network & offensive security auditing suite
    ├── bugbounty.sh      # Web recon, OSINT & nuclei automation
    ├── cloud.sh          # Cloud, container & Kubernetes security testing
    ├── ai_mcp.sh         # Preconfigured safe MCP suite & Claude Desktop config
    ├── workflow.sh       # Core terminal, tmux, lazygit, aliases & helper functions
    ├── doctor.sh         # sec_doctor diagnostic audit suite
    ├── configs.sh        # Dotfile generators (.zshrc, .tmux.conf, configs)
    └── menu.sh           # Interactive ASCII dashboard & CLI argument handler
```

### Compiling Standalone Distribution
Whenever you make updates to `lib/*.sh`, run:
```bash
./bundle.sh
```
This generates a standalone, single-file `ter.sh` with zero external dependencies—ideal for `curl -fsSL https://.../ter.sh | bash`.

---

## 📋 Components Breakdown

| # | Component | Contents |
|---|-----------|----------|
| 1 | **Core terminal** | Oh My Zsh + plugins, Powerlevel10k, fzf, bat, eza, zoxide, git-delta, tmux, fd, ripgrep, tldr |
| 2 | **Hacker Fonts** | MesloLGS NF (p10k), JetBrains Mono NF, Fira Code NF, Hack NF, Caskaydia Cove NF |
| 3 | **Node.js & npm** | Modern Node.js LTS, npm, safe non-root global directory (`~/.npm-global`) |
| 4 | **Claude Code CLI** | `@anthropic-ai/claude-code` official agentic coding assistant CLI (`claude`, `cc`) |
| 5 | **VS Code & CLI** | Visual Studio Code editor, `code` CLI in PATH, aliases (`c`, `c.`) |
| 6 | **GPU Terminals** | Ghostty, WezTerm, Kitty, Alacritty + Catppuccin Mocha configs, ligatures, window blur |
| 7 | **Shell History & Secrets** | Atuin (encrypted SQLite history + secret scrubbing), direnv (.envrc isolation), Astral uv/uvx, btop, yazi, Starship prompt |
| 8 | **MCP Server Suite** | Scoped Filesystem MCP, GitHub MCP, Fetch MCP, Brave Search MCP, Memory MCP, `sec-mcp` CLI |
| 9 | **Pentest** | nmap, sqlmap, hydra, john, hashcat, gobuster, masscan, tcpdump, httpie, SecLists, impacket, pwntools, scapy |
| 10 | **Bug bounty** | subfinder, httpx, nuclei, katana, dnsx, interactsh, gau, hakrawler, waybackurls, amass, dalfox, ffuf, feroxbuster, nikto, mitmproxy, arjun, Burp Suite, Caido |
| 11 | **Active Directory & Pivoting** | Ligolo-ng (kernel TUN pivot routing), Chisel, NetExec (`nxc`), BloodHound-python, Certipy (AD CS), Responder |
| 12 | **Web & API Security** | Schemathesis (property fuzzer for OpenAPI/GraphQL), Kiterunner (`kr`), Caido CLI daemon, Arjun |
| 13 | **Cloud & DevSecOps** | Trivy (unified container/IaC scanner), Syft & Grype (SBOM creator & matcher), Checkov, Kube-hunter |
| 14 | **Mobile & Reverse Eng** | Jadx & Jadx-gui (DEX to Java decompiler), Apktool (APK resource decoding & rebuilding) |
| 15 | **Cloud security** | AWS CLI, Azure CLI, gcloud, prowler, pacu, cloudfox, gitleaks, trufflehog, s3scanner |
| 16 | **AI / LLM security** | garak, promptfoo, llm, jwt_tool, Ollama |
| 17 | **Workflow** | lazygit, jq, yq, gh, pandoc, xh, yazi, Obsidian |
| 18 | **Tactical Welcome Cockpit** | Fastfetch + sub-15ms terminal welcome banner with network, VPN/tunnel, proxy, and telemetry |
| 19 | **Config files** | `~/.zshrc`, `~/.tmux.conf`, `pentest.zsh`, `advanced_pentest.zsh`, `welcome.zsh`, `starship.toml`, `ghostty/config` |
| 20 | **System Doctor** | Diagnostic health audit command (`doctor` / `sec-doctor`) verifying all tools and configs |

---

## 🛠️ MCP Server Suite & Agentic AI

The preconfigured Model Context Protocol (MCP) suite provides seamless, safe tool execution for Claude Code and Claude Desktop:

- **Filesystem MCP**: Strictly sandboxed to `~/workspace` and `~/pentest` (never exposes `$HOME` or root, keeping SSH keys and tokens private).
- **GitHub MCP**: Search repositories, inspect pull requests, and review issues directly inside AI conversations.
- **Fetch MCP**: High-speed web page fetcher that converts HTML documentation into markdown.
- **Brave Search MCP**: Real-time web search capabilities for finding documentation and CVEs.
- **Memory MCP**: Graph-based persistent memory across sessions.
- **`sec-mcp` Management CLI**:
  - `sec-mcp list` — Show all active MCP servers and sandbox paths
  - `sec-mcp inspect` — Launch the visual MCP Inspector web UI
  - `sec-mcp setup` — Re-configure or update MCP servers

---

## ⚡ Modern CLI & Shell Ergonomics

### Atuin (Encrypted SQLite History)
- Replaces traditional `.zsh_history` with an encrypted local SQLite database.
- Press **Ctrl+R** for interactive fuzzy history search with timestamps, return codes, and directory context.
- **`secrets_filter = true`**: Automatically scrubs passwords, API keys, tokens, and authorization headers so sensitive data is never persisted.

### direnv (Directory-Specific Secret Isolation)
- Automatically loads environment variables when entering a directory with a `.envrc` file, and unloads them when leaving.
- Whitelist configuration pre-tuned to `~/pentest`, `~/workspace`, and `~/projects`.

### Astral uv & uvx
- 10-100x faster drop-in replacement for `pip`, `pipx`, and `virtualenv`.
- Run security tools ephemerally without installing them globally:
  ```bash
  uvx prowler aws --compliance cis_v3
  uvx semgrep --config=auto
  uvx mitmproxy
  ```

---

## 🩺 System Doctor (`doctor` / `sec-doctor`)

Run the built-in diagnostic audit anytime:
```bash
./ter.sh --doctor
# Or in an active shell:
doctor
```

It verifies:
- Shell & prompt health (Zsh, Starship, Powerlevel10k)
- Modern ergonomics (Atuin, direnv, uv, btop, yazi, delta)
- Terminal emulators (Ghostty, WezTerm, Kitty, Alacritty)
- Developer & AI stack (Node.js, Claude Code, VS Code, Go, Python, pipx, MCP)
- Offensive tools (nmap, nuclei, subfinder, httpx, katana, ffuf, sqlmap, hydra)
- Cloud & LLM audit tools (AWS CLI, Azure, gcloud, trufflehog, gitleaks, prowler, Ollama)
- Dotfile integrity (`.zshrc`, `.tmux.conf`, `pentest.zsh`, `starship.toml`, `ghostty/config`, etc.)

---

## 📜 Cheat Sheet Reference

In any terminal session, type:
```bash
cheat               # Full reference manual
?                   # Shortcut for cheat
cheat recon         # Filter for recon commands
cheat cloud         # Filter for cloud & credential tools
cheat dev           # Filter for developer & AI agent commands
tip                 # Show a random security/terminal productivity tip
```
