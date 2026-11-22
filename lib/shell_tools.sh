#!/usr/bin/env bash
# =============================================================================
#  lib/shell_tools.sh — Shell Ergonomics, Secret Isolation & Modern CLI Suite
#  Includes: Atuin (SQLite history + secrets scrub), direnv, Astral uv,
#            btop, yazi, delta, and Starship prompt
# =============================================================================

# Pinned installer versions (override with HTS_ATUIN_VERSION / HTS_UV_VERSION).
HTS_ATUIN_VERSION_DEFAULT="18.25.1"
HTS_UV_VERSION_DEFAULT="0.13.9"

# _hts_url_exists <url> — HEAD request; succeeds on a 2xx after redirects
_hts_url_exists() {
  curl -fsSLI --connect-timeout 10 --max-time 30 -o /dev/null "$1" 2>/dev/null
}

# _hts_prompt_choice — print the validated prompt choice (p10k|starship)
_hts_prompt_choice() {
  case "${HTS_PROMPT:-p10k}" in
    starship) echo "starship" ;;
    p10k|"")  echo "p10k" ;;
    *) warn "HTS_PROMPT='${HTS_PROMPT}' is not 'starship' or 'p10k' — using p10k" >&2; echo "p10k" ;;
  esac
}

install_atuin() {
  step "Atuin (SQLite Shell History & Secrets Scrubbing)"

  if command -v atuin &>/dev/null; then
    ok "Atuin already installed: $(atuin --version)"
  else
    if [[ "$OS" == "Darwin" ]]; then
      pkg_install atuin
    else
      local av="${HTS_ATUIN_VERSION:-$HTS_ATUIN_VERSION_DEFAULT}"
      local aurl="https://github.com/atuinsh/atuin/releases/download/v${av}/atuin-installer.sh"
      if _hts_url_exists "$aurl"; then
        log "Installing Atuin v${av} via its pinned release installer ($aurl)..."
        if hts_run_remote_script "$aurl" "sh"; then
          export PATH="$HOME/.cargo/bin:$HOME/.atuin/bin:$PATH"
          hts_manifest_add tool atuin "release-installer v${av}"
        else
          warn "Atuin installer failed"
        fi
      else
        warn "Atuin installer for v${av} not reachable ($aurl) — skipping Atuin install"
      fi
    fi
  fi

  # Deploy security-focused Atuin config
  local cfg_dir="$HOME/.config/atuin"
  mkdir -p "$cfg_dir"
  log "Writing Atuin privacy configuration ($cfg_dir/config.toml)..."
  backup_file "$cfg_dir/config.toml"
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

# Security: do not record commands that contain recognised secrets (cloud keys,
# GitHub/Slack tokens, ...). NOTE: the local history database itself is plain
# SQLite and is NOT encrypted at rest; only optional sync is end-to-end
# encrypted (and sync is disabled above).
secrets_filter = true

# Commands matching these regexes are never saved to history
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
  hts_track_file "$cfg_dir/config.toml"
  ok "Atuin configured with secrets_filter = true (local history DB is not encrypted at rest)"
}

install_direnv() {
  step "direnv (Per-Directory Environment & Secret Isolation)"

  if command -v direnv &>/dev/null; then
    ok "direnv already installed: $(direnv --version)"
  else
    pkg_install direnv
  fi

  # Deploy security config (no blanket trust of any directory)
  local cfg_dir="$HOME/.config/direnv"
  mkdir -p "$cfg_dir"
  backup_file "$cfg_dir/direnv.toml"
  cat > "$cfg_dir/direnv.toml" << 'DIRENV_CFG'
[global]
bash_path = "bash"
disable_stdin = true
warn_timeout = "5s"
DIRENV_CFG
  hts_track_file "$cfg_dir/direnv.toml"
  ok "direnv configured"
  info "direnv trusts no directory automatically: review a .envrc, then run 'direnv allow' in that directory."
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
      local uvv="${HTS_UV_VERSION:-$HTS_UV_VERSION_DEFAULT}"
      local uvurl="https://astral.sh/uv/${uvv}/install.sh"
      if _hts_url_exists "$uvurl"; then
        log "Installing uv ${uvv} via its pinned installer ($uvurl)..."
        if hts_run_remote_script "$uvurl" "sh"; then
          export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
          hts_manifest_add tool uv "release-installer ${uvv}"
        else
          warn "uv installer failed"
        fi
      else
        warn "uv installer for ${uvv} not reachable ($uvurl) — skipping uv install"
      fi
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
      if cargo install --locked yazi-fm yazi-cli 2>/dev/null; then
        hts_manifest_add tool yazi "cargo"
      fi
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
      log "Installing Starship prompt (upstream installer into ~/.local/bin; no pinned URL exists)..."
      mkdir -p "$HOME/.local/bin"
      if hts_run_remote_script "https://starship.rs/install.sh" "sh" -y -b "$HOME/.local/bin"; then
        hts_manifest_add tool starship "upstream-installer"
      else
        warn "Starship install failed"
      fi
    fi
  fi

  # Write sleek minimal Starship config
  local cfg_file="$HOME/.config/starship.toml"
  mkdir -p "$HOME/.config"
  log "Writing Starship configuration ($cfg_file)..."
  backup_file "$cfg_file"
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
  hts_track_file "$cfg_file"
  if [[ "$(_hts_prompt_choice)" == "starship" ]]; then
    ok "Starship configuration deployed; HTS_PROMPT=starship will activate it in ~/.zshrc"
  else
    ok "Starship configuration deployed (inactive: prompt is p10k; rerun with HTS_PROMPT=starship to switch)"
  fi
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
