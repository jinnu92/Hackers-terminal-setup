#!/usr/bin/env bash
# =============================================================================
#  lib/shell_tools.sh — Shell Ergonomics, Secret Isolation & Modern CLI Suite
#  Includes: Atuin (SQLite history + secrets scrub), direnv, Astral uv,
#            btop, yazi, delta, and Starship prompt
# =============================================================================

install_atuin() {
  step "Atuin (SQLite Shell History & Secrets Scrubbing)"

  if command -v atuin &>/dev/null; then
    ok "Atuin already installed: $(atuin --version)"
  else
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install atuin
    else
      log "Installing Atuin via official install script..."
      curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh || warn "Atuin install script failed"
    fi
  fi

  # Deploy security-focused Atuin config
  local cfg_dir="$HOME/.config/atuin"
  mkdir -p "$cfg_dir"
  log "Writing Atuin privacy configuration ($cfg_dir/config.toml)..."
  cat > "$cfg_dir/config.toml" << 'ATUIN_CFG'
# =============================================================================
# Atuin Shell History — Security & Privacy Configuration
# =============================================================================
auto_sync = false
update_check = false
style = "compact"
inline_height = 20
show_preview = true
enter_accept = false

# Security: Scrub sensitive credentials from SQLite history
secrets_filter = true

# Regex filter for tokens, passwords, and API keys
history_filter = [
  "^export .*KEY=.*",
  "^export .*SECRET=.*",
  "^export .*TOKEN=.*",
  "^export .*PASSWORD=.*",
  "^aws configure set .*",
  "^gh auth login --with-token.*",
  "^curl .*Authorization: Bearer.*",
]
ATUIN_CFG
  ok "Atuin configured with secrets_filter = true"
}

install_direnv() {
  step "direnv (Per-Directory Environment & Secret Isolation)"

  if command -v direnv &>/dev/null; then
    ok "direnv already installed: $(direnv --version)"
  else
    pkg_install direnv
  fi

  # Deploy whitelist and security config
  local cfg_dir="$HOME/.config/direnv"
  mkdir -p "$cfg_dir"
  cat > "$cfg_dir/direnv.toml" << 'DIRENV_CFG'
[global]
bash_path = "bash"
disable_stdin = true
warn_timeout = "5s"
[whitelist]
prefix = [ "~/pentest", "~/workspace", "~/projects" ]
DIRENV_CFG
  ok "direnv configured"
}

install_uv() {
  step "Astral uv & uvx (Ultra-Fast Python Runner & Ephemeral Tool Sandbox)"

  if command -v uv &>/dev/null; then
    ok "uv already installed: $(uv --version)"
  else
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install uv
    fi
    if ! command -v uv &>/dev/null; then
      log "Installing uv via official installer..."
      curl -LsSf https://astral.sh/uv/install.sh | sh || warn "uv installer failed"
      export PATH="$HOME/.cargo/bin:$PATH"
    fi
  fi

  if command -v uv &>/dev/null; then
    ok "Astral uv ready: $(uv --version)"
    info "Run ephemeral tools instantly without installing: e.g. 'uvx prowler', 'uvx semgrep', 'uvx mitmproxy'"
  fi
}

install_modern_cli() {
  step "Modern Rust & Go CLI Power-Ups (btop, yazi, delta, eza, zoxide)"

  # btop
  if ! command -v btop &>/dev/null; then
    pkg_install btop
  else
    ok "btop already installed"
  fi

  # yazi (terminal file manager)
  if ! command -v yazi &>/dev/null; then
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install yazi
    elif command -v cargo &>/dev/null; then
      cargo install --locked yazi-fm yazi-cli 2>/dev/null || true
    fi
  fi

  # delta (git pager)
  if ! command -v delta &>/dev/null; then
    pkg_install git-delta
  fi

  # eza, zoxide, ripgrep, fzf
  pkg_install eza zoxide ripgrep fzf bat fd
  linux_fixups
  ok "Modern CLI power-ups installed"
}

install_starship() {
  step "Starship Prompt (Ultra-Fast Cross-Shell Prompt)"

  if command -v starship &>/dev/null; then
    ok "Starship prompt already installed: $(starship --version | head -1)"
  else
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install starship
    else
      log "Installing Starship prompt..."
      curl -sS https://starship.rs/install.sh | sh -s -- -y 2>/dev/null || warn "Starship install failed"
    fi
  fi

  # Write sleek minimal Starship config
  local cfg_file="$HOME/.config/starship.toml"
  mkdir -p "$HOME/.config"
  log "Writing Starship configuration ($cfg_file)..."
  cat > "$cfg_file" << 'STARSHIP_CFG'
# =============================================================================
# Starship Prompt Configuration — Minimal & Sub-Millisecond Latency
# =============================================================================
add_newline = true
scan_timeout = 10

format = """
$username\
$hostname\
$directory\
$git_branch\
$git_status\
$nodejs\
$golang\
$python\
$aws\
$cmd_duration\
$line_break\
$character"""

[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"

[directory]
style = "bold blue"
truncation_length = 3
truncate_to_repo = true

[git_branch]
symbol = " "
style = "bold purple"

[git_status]
style = "bold red"
format = '([$all_status$ahead_behind]($style) )'

[nodejs]
symbol = "⬢ "
style = "bold green"

[golang]
symbol = " "
style = "bold cyan"

[python]
symbol = "🐍 "
style = "yellow"

[aws]
symbol = "☁️  "
style = "bold orange"
format = 'on [$symbol($profile)]($style) '

[cmd_duration]
min_time = 2_000
style = "dimmed yellow"
format = "took [$duration]($style) "
STARSHIP_CFG
  ok "Starship configuration deployed to ~/.config/starship.toml"
}

install_shell_tools() {
  step "Shell History, Secret Isolation & Modern CLI Suite"
  install_atuin
  install_direnv
  install_uv
  install_modern_cli
  install_starship
  ok "Shell tools & secret isolation suite complete"
}
