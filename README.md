# Hackers Terminal Setup

A single self-contained Bash installer that turns a fresh macOS or Linux box into a
working security-testing terminal: shell, prompt, tooling, aliases and config files.

Everything lives in one script — `ter.sh`. It detects your OS and package manager,
installs only the components you pick from a menu, and writes the dotfiles
(`.zshrc`, `pentest.zsh`, `welcome.zsh`, `.tmux.conf`) from embedded templates.

---

## Quick start

```bash
git clone https://github.com/jinnu92/Hackers-terminal-setup.git
cd Hackers-terminal-setup
chmod +x ter.sh
./ter.sh
```

You'll get a menu — enter the numbers you want (`1 2 8`), or `A` for everything.

After it finishes:

1. Set your terminal font to **MesloLGS NF**
2. `exec zsh`
3. `p10k configure`
4. `cheat` (or `?`) to open the cheat sheet

---

## What it installs

| # | Component | Contents |
|---|-----------|----------|
| 1 | **Core terminal** | Oh My Zsh + plugins, Powerlevel10k, fzf, bat, eza, zoxide, git-delta, tmux, fd, ripgrep, tldr, Meslo Nerd Font |
| 2 | **Pentest** | nmap, sqlmap, hydra, john, hashcat, gobuster, masscan, tcpdump, httpie, SecLists, netexec |
| 3 | **Bug bounty** | subfinder, httpx, nuclei, katana, dnsx, interactsh, gau, hakrawler, waybackurls, amass, dalfox, ffuf, feroxbuster, nikto, mitmproxy, arjun, Burp Suite, Caido |
| 4 | **Cloud security** | AWS CLI, Azure CLI, gcloud, prowler, pacu, cloudfox, gitleaks, trufflehog, s3scanner |
| 5 | **AI / LLM security** | garak, promptfoo, llm, jwt_tool, Ollama |
| 6 | **MCP / agent security** | @modelcontextprotocol/inspector, semgrep, detect-secrets |
| 7 | **Workflow** | lazygit, jq, yq, gh, pandoc, xh, yazi, Obsidian |
| 8 | **Config files** | `~/.zshrc`, `~/.config/zsh/pentest.zsh`, `~/.config/zsh/welcome.zsh`, `~/.tmux.conf`, `~/pentest/` workspace |

Components are independent — you can re-run the script later and add only what you skipped.

---

## Platform support

| Platform | Package manager |
|----------|-----------------|
| macOS (Intel + Apple Silicon) | Homebrew |
| Debian / Ubuntu / Kali | apt |
| Fedora | dnf |
| RHEL / CentOS | yum |
| Arch | pacman |
| openSUSE | zypper |

Package names that differ between distros are resolved through an internal mapping table,
and tools missing from distro repos are installed via `go install`, `pipx`, or `npm -g`.

---

## What you get in the shell

The config files add a large set of aliases and functions. A sample:

**Recon & scanning**

```
nmap_quick <host>     top-1000 TCP, service detection
nmap_full <host>      all 65535 ports
nmap_vuln <host>      NSE vuln scripts
quickrecon <domain>   subdomains → live hosts → nuclei
bbrecon <domain>      full bug-bounty recon chain
portcheck <host> <p>  single-port check
```

**Web**

```
probehttp             httpx probe from stdin
crawl <url>           katana crawl
geturls <domain>      gau + waybackurls
dirscan <url>         feroxbuster
xssscan <url>         dalfox
webfuzz <url>         ffuf with SecLists
mitm / mitmw          mitmproxy / mitmweb
```

**Cloud & secrets**

```
awswho / gcpwho / azwho   current identity
awscheck                  prowler run
s3ls / s3pub              bucket listing
secrets_scan <repo>       trufflehog
leaks                     gitleaks on cwd
```

**AI / LLM & MCP**

```
llmscan <target>      garak probe
llmchat               local Ollama chat
llm_fuzz              prompt-injection fuzzing
mcpinspect            MCP inspector
mcp_audit <path>      static audit of an MCP server
agentscan             semgrep + detect-secrets over agent code
jwtinspect <token>    jwt_tool
```

**Shells & utilities**

```
revshell <ip> <port>  generate reverse shells
upgradeshell          TTY upgrade cheat sheet
rlisten <port>        netcat listener
serve [port]          HTTP server in cwd
myip / ports          public IP / listening ports
b64enc / b64dec       base64
urlencode / urldecode
genreport             scaffold an engagement report
cheat  (or ?)         full cheat sheet
tip                   random tip
```

**tmux** — prefix is `Ctrl+A`, `|` and `-` split, `hjkl` to move panes, `r` reloads.

---

## Workspace layout

Option 8 creates:

```
~/pentest/
├── bb/          bug bounty
├── cloud/       cloud assessments
├── ai_sec/      LLM testing
├── mcp_sec/     MCP / agent testing
├── reports/     deliverables
├── tools/       scratch tooling
└── wordlists/   symlinked to SecLists
```

---

## Notes

- The script uses `sudo` for system package installs on Linux. Read it before running it —
  that's true of any installer you pipe into a shell.
- Homebrew casks (Burp Suite, Caido, Obsidian, Ollama) are macOS-only; on Linux the script
  prints the manual download URL instead.
- Go-based tools land in `~/go/bin`, pipx tools in `~/.local/bin` — both are added to `PATH`
  by the generated `.zshrc`.
- Failures are non-fatal: a package that won't install prints a warning and the run continues.

---

## Legal

These tools are for authorised security testing only — your own systems, engagements with a
signed scope, or bug bounty programs whose rules you're following. Unauthorised scanning and
exploitation is illegal in most jurisdictions. You're responsible for how you use this.

## License

MIT — see [LICENSE](LICENSE).
