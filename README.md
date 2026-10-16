# Hackers Terminal Setup — Enhanced Edition

A single self-contained Bash installer that turns a fresh macOS or Linux box into a
high-performance security-testing, developer, and agentic AI terminal: shell, prompt, tooling, aliases, and config files.

Everything lives in one script — `ter.sh`. It detects your OS and package manager,
installs only the components you select (or everything with `--all`), and writes the dotfiles
(`.zshrc`, `pentest.zsh`, `welcome.zsh`, `.tmux.conf`) from embedded templates.

---

## Quick start

### Interactive Menu
```bash
git clone https://github.com/jinnu92/Hackers-terminal-setup.git
cd Hackers-terminal-setup
chmod +x ter.sh
./ter.sh
```

You'll get an interactive menu — enter the numbers you want (e.g. `1 2 3 4 5 12`), or `A` for everything.

### Command-Line Automation (CLI Flags)
You can also run `ter.sh` non-interactively with CLI flags:

```bash
./ter.sh --all               # Install complete hacker terminal + tools + configs
./ter.sh --fonts             # Install all recommended Nerd Fonts
./ter.sh --dev               # Install Node.js LTS + Claude Code CLI + VS Code
./ter.sh --doctor            # Run environment audit & health check dashboard
./ter.sh --fonts --dev 1 12  # Combine flags and numbers freely
./ter.sh --help              # Show help and all CLI options
```

---

## Post-Installation Steps

1. Set your terminal font to **MesloLGS NF** (for Powerlevel10k icons) or **JetBrainsMono Nerd Font**
2. Reload shell: `exec zsh`
3. Configure prompt: `p10k configure`
4. Start Claude Code: `claude` (or `cc`)
5. Run System Doctor: `doctor` (or `sec-doctor`)
6. Open cheat sheet: `cheat` (or `?`)

---

## What it installs

| # | Component | Contents |
|---|-----------|----------|
| 1 | **Core terminal** | Oh My Zsh + plugins, Powerlevel10k, fzf, bat, eza, zoxide, git-delta, tmux, fd, ripgrep, tldr |
| 2 | **Hacker Fonts** | MesloLGS NF (p10k), JetBrains Mono NF, Fira Code NF, Hack NF, Caskaydia Cove NF |
| 3 | **Node.js & npm** | Modern Node.js LTS, npm, safe non-root global directory (`~/.npm-global`) |
| 4 | **Claude Code CLI** | `@anthropic-ai/claude-code` official agentic coding assistant CLI (`claude`, `cc`) |
| 5 | **VS Code & CLI** | Visual Studio Code editor, `code` CLI in PATH, aliases (`c`, `c.`) |
| 6 | **Pentest** | nmap, sqlmap, hydra, john, hashcat, gobuster, masscan, tcpdump, httpie, SecLists, netexec, impacket, pwntools, scapy |
| 7 | **Bug bounty** | subfinder, httpx, nuclei, katana, dnsx, interactsh, gau, hakrawler, waybackurls, amass, dalfox, ffuf, feroxbuster, nikto, mitmproxy, arjun, Burp Suite, Caido |
| 8 | **Cloud security** | AWS CLI, Azure CLI, gcloud, prowler, pacu, cloudfox, gitleaks, trufflehog, s3scanner |
| 9 | **AI / LLM security** | garak, promptfoo, llm, jwt_tool, Ollama |
| 10 | **MCP / agent security** | @modelcontextprotocol/inspector, semgrep, detect-secrets |
| 11 | **Workflow** | lazygit, jq, yq, gh, pandoc, xh, yazi, Obsidian |
| 12 | **Config files** | `~/.zshrc`, `~/.oh-my-zsh/custom/pentest.zsh`, `~/.oh-my-zsh/custom/welcome.zsh`, `~/.tmux.conf`, `~/pentest/` workspace layout |
| 13 | **System Doctor** | Diagnostic health audit command (`doctor` / `sec-doctor`) verifying all tools and configs |

Components are independent — you can re-run the script anytime and install only what you need.

---

## Platform support

| Platform | Package manager | Node & Dev Stack | Fonts |
|----------|-----------------|------------------|-------|
| macOS (Intel + Apple Silicon) | Homebrew | brew + Homebrew Cask | Homebrew Cask + `~/Library/Fonts` |
| Debian / Ubuntu / Kali | apt | NodeSource LTS + MS apt repo | Nerd Fonts tar.xz + `fc-cache` |
| Fedora | dnf | NodeSource LTS + MS rpm repo | Nerd Fonts tar.xz + `fc-cache` |
| RHEL / CentOS | yum | NodeSource LTS + MS rpm repo | Nerd Fonts tar.xz + `fc-cache` |
| Arch | pacman | native repos | Nerd Fonts tar.xz + `fc-cache` |
| openSUSE | zypper | native repos + MS repo | Nerd Fonts tar.xz + `fc-cache` |

Package names that differ between distros are resolved through an internal mapping table. Tools missing from distro repos are installed via `go install`, `pipx`, or `npm -g` (without sudo permissions conflicts).

---

## What you get in the shell

The generated configs provide a comprehensive set of aliases and functions:

### Developer & Agentic AI
```bash
claude / cc             Launch Claude Code agentic coding CLI
claude-yolo             Run Claude Code with auto-approved permissions
code <path> / c.        Open VS Code in directory/file
doctor / sec-doctor     Run full system environment audit & tool checker
nr / ni                 npm run / npm install
node -v / npm -v        Check Node.js and npm versions
mcpinspect              Launch MCP Inspector tool via npx
```

### Recon & scanning
```bash
nmap_quick <host>       Top-1000 TCP, service detection
nmap_full <host>        All 65,535 ports
nmap_vuln <host>        NSE vulnerability scripts
quickrecon <domain>     Whois → DNS → HTTP headers
bbrecon <domain>        Automated pipeline: subdomains → alive hosts → URLs → nuclei
portcheck <host> <p>    Single-port netcat check
```

### Web security
```bash
probehttp               httpx probe from stdin
crawl <url>             katana crawler
geturls <domain>        gau + waybackurls
dirscan <url>           feroxbuster directory brute-force
xssscan <url>           dalfox XSS scanner
webfuzz <url>           ffuf fuzzing automatically using SecLists
proxyon / proxyoff      Toggle Burp Suite / Caido proxy (:8080)
mitm / mitmw            mitmproxy / mitmweb
```

### Cloud & secrets
```bash
awswho / gcpwho / azwho Current cloud identity
awscheck                Identity + attached IAM policies
s3ls / s3pub            S3 bucket listing and public ACL verification
secrets_scan <repo>     TruffleHog git scan
secrets_scan_local      TruffleHog scan current directory
leaks                   Gitleaks scan on cwd
```

### AI / LLM & MCP security
```bash
llmscan <target>        garak LLM vulnerability probe
llmchat                 Local Ollama / LLM chat
llm_fuzz                Prompt-injection & jailbreak fuzzing
mcpinspect              MCP inspector
mcp_audit <path>        Static audit of MCP server configurations
agentscan <dir>         Semgrep + secret audit over agent code
jwtinspect <token>      Instant offline JWT header & payload decoder
jwtdecode <token>       jwt_tool analysis
```

### Shells & utilities
```bash
revshell <ip> <port>    Generate reverse shell one-liners
upgradeshell            TTY upgrade cheat sheet
rlisten <port>          Netcat listener
serve [port]            HTTP server in cwd showing your IP:port
myip / localip          Public IP / local network IP
b64enc / b64dec         Base64 encode / decode
urlencode / urldecode   URL encoding
genreport [name]        Scaffold an engagement report in markdown
cheat (or ?)            Interactive searchable command reference
tip                     Display a random security or workflow tip
```

### tmux
Prefix is `Ctrl+A`:
- `|` : Vertical split
- `-` : Horizontal split
- `h, j, k, l` : Vim-style pane navigation
- `r` : Reload tmux configuration

---

## Workspace layout

Option 12 creates:

```text
~/pentest/
├── bb/          Bug bounty recon & targets
├── cloud/       Cloud assessments & audit logs
├── ai_sec/      LLM & agent testing
├── mcp_sec/     MCP server testing
├── reports/     Deliverables & markdown reports
├── tools/       Custom & scratch tooling
└── wordlists/   Symlinked to SecLists
```

---

## Notes

- **Sudo Usage:** System package managers on Linux require `sudo`.
- **Safe Global npm:** The script configures `~/.npm-global` prefix so `npm install -g` runs smoothly without `sudo` or permission errors.
- **Go Binaries:** Go-based tools land in `~/go/bin`, pipx tools in `~/.local/bin`, and npm tools in `~/.npm-global/bin` — all are automatically added to `PATH` in `.zshrc`.
- **Idempotence & Safety:** Components can be re-run safely at any time. Existing `.zshrc` files are timestamped and backed up before writing.

---

## Legal

These tools are for authorised security testing, research, and educational purposes only. Always obtain written authorization before scanning or testing any targets.

## License

MIT — see [LICENSE](LICENSE).
